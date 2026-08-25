--!strict
-- Server-authoritative collection ledger. Buildable IDs come only from PartRegistry.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local Definitions = require(game.ReplicatedStorage.MechFramework.Shared.CollectionDefinitions)
local Config = require(game.ReplicatedStorage.MechFramework.Shared.FrameworkConfig)

local Inventory: any = { _players = {}, _parts = nil }
local STUDIO_STACK_AMOUNT = 50
local STUDIO_UNIQUE_AMOUNT = 12
local MAX_APPLIED_TRANSACTIONS = 512
local MAX_TRANSACTION_ID_LENGTH = 240

local function clone(value: any): any
	if type(value) ~= "table" then return value end
	local out = {}
	for key, item in pairs(value) do out[key] = clone(item) end
	return out
end

local function freshRecord(): any
	return { Stacks = {}, Unique = {}, Materials = {}, Revision = 0, AppliedTransactions = {} }
end

local function ledger(self: any, userId: number): any
	local record = self._players[userId]
	if not record then record = freshRecord(); self._players[userId] = record end
	return record
end

local function bump(record: any) record.Revision += 1 end

local function pruneTransactions(record: any)
	local entries = {}
	for id, timestamp in pairs(record.AppliedTransactions or {}) do table.insert(entries, {Id=id, Time=tonumber(timestamp) or 0}) end
	if #entries <= MAX_APPLIED_TRANSACTIONS then return end
	table.sort(entries, function(a,b) return if a.Time==b.Time then a.Id<b.Id else a.Time<b.Time end)
	for index=1,#entries-MAX_APPLIED_TRANSACTIONS do record.AppliedTransactions[entries[index].Id]=nil end
end

function Inventory:Init(container: any)
	self._parts = container:Get("PartRegistry")
end

function Inventory:GetPartMetadata(partType: string): any?
	if not self._parts then return nil end
	local definition = self._parts:Get(partType)
	if not definition then return nil end
	return {
		Id = definition.Id,
		Rarity = definition.Rarity or "Common",
		Stackable = definition.Stackable ~= false,
		MaxDurability = math.max(1, math.floor(tonumber(definition.MaxDurability) or tonumber(definition.MaxHealth) or 100)),
		Category = definition.Category,
	}
end

-- Total collection ownership, including broken unique components that may still be repaired/salvaged.
function Inventory:GetCount(userId: number, partType: string): number
	local metadata = self:GetPartMetadata(partType)
	if not metadata then return 0 end
	local canonical = metadata.Id
	local record = ledger(self, userId)
	local count = tonumber(record.Stacks[canonical]) or 0
	for _, item in pairs(record.Unique) do if item.PartType == canonical then count += 1 end end
	return count
end

-- Construction-ready ownership. Zero-durability unique items remain owned but cannot be installed.
function Inventory:GetBuildableCount(userId: number, partType: string): number
	local metadata = self:GetPartMetadata(partType)
	if not metadata then return 0 end
	local canonical = metadata.Id
	local record = ledger(self, userId)
	local count = math.max(0, tonumber(record.Stacks[canonical]) or 0)
	for _, item in pairs(record.Unique) do
		if item.PartType == canonical and (tonumber(item.Durability) or 0) > 0 then count += 1 end
	end
	return count
end

function Inventory:GrantPart(userId: number, partType: string, amount: number, metadata: any?): any
	local definition = self:GetPartMetadata(partType)
	assert(definition ~= nil, "Unknown part definition: " .. tostring(partType))
	assert(amount > 0 and amount % 1 == 0, "Amount must be a positive integer")
	local canonical = definition.Id
	local record = ledger(self, userId)
	local created = {}
	if definition.Stackable then
		record.Stacks[canonical] = (record.Stacks[canonical] or 0) + amount
	else
		for _ = 1, amount do
			local id = HttpService:GenerateGUID(false)
			local ratio = math.clamp((metadata and metadata.Condition) or 1, 0, 1)
			local item = {
				UniqueId = id, PartType = canonical, OwnerUserId = userId,
				Rarity = definition.Rarity,
				Durability = math.floor(definition.MaxDurability * ratio + 0.5),
				MaxDurability = definition.MaxDurability,
				Modifiers = clone((metadata and metadata.Modifiers) or {}),
				Source = (metadata and metadata.Source) or "ServerGrant",
				Tradability = (metadata and metadata.Tradability) or "Tradable",
			}
			record.Unique[id] = item
			table.insert(created, clone(item))
		end
	end
	bump(record)
	return definition.Stackable and amount or created
end

function Inventory:Grant(userId: number, partType: string, amount: number)
	return self:GrantPart(userId, partType, amount, { Source = "LegacyGrant" })
end

function Inventory:EnsureStudioBuildInventory(userId: number)
	if not (RunService:IsStudio() and Config.Debug) then return end
	assert(self._parts ~= nil, "InventoryService must be initialized before Studio inventory seed")
	local grantedKinds = 0
	for _, definition in ipairs(self._parts:GetList()) do
		local desired = if definition.Stackable == false then STUDIO_UNIQUE_AMOUNT else STUDIO_STACK_AMOUNT
		local current = self:GetBuildableCount(userId, definition.Id)
		if current < desired then self:GrantPart(userId, definition.Id, desired - current, { Source = "StudioDebug" }) end
		grantedKinds += 1
	end
	print("[MechFramework] Studio build inventory ready", userId, grantedKinds, "part types")
end

function Inventory:Start()
	if not (RunService:IsStudio() and Config.Debug) then return end
	Players.PlayerAdded:Connect(function(player) self:EnsureStudioBuildInventory(player.UserId) end)
	for _, player in ipairs(Players:GetPlayers()) do self:EnsureStudioBuildInventory(player.UserId) end
end

-- Exact single-part receipt used by construction so non-stackable identity/modifiers survive a build round-trip.
function Inventory:ConsumeOne(userId: number, partType: string): (boolean, any)
	local metadata = self:GetPartMetadata(partType)
	if not metadata then return false,"UnknownPartType" end
	local canonical = metadata.Id
	local record = ledger(self,userId)
	local stacked = tonumber(record.Stacks[canonical]) or 0
	if stacked > 0 then
		record.Stacks[canonical]=stacked-1
		bump(record)
		return true,{Kind="Stack",PartType=canonical}
	end

	-- Prefer the most worn usable item so pristine rare copies are not consumed before damaged ones.
	local candidates={}
	for id,item in pairs(record.Unique) do
		local durability=tonumber(item.Durability) or 0
		if item.PartType==canonical and durability>0 then table.insert(candidates,{Id=id,Durability=durability}) end
	end
	table.sort(candidates,function(a,b) return if a.Durability==b.Durability then a.Id<b.Id else a.Durability<b.Durability end)
	local selected=candidates[1]
	if not selected then return false,"InsufficientInventory" end
	local item=record.Unique[selected.Id]
	record.Unique[selected.Id]=nil
	bump(record)
	return true,{Kind="Unique",PartType=canonical,Item=clone(item)}
end

function Inventory:RestorePartReceipt(userId: number, receipt: any): boolean
	if type(receipt)~="table" or type(receipt.PartType)~="string" then return false end
	local metadata=self:GetPartMetadata(receipt.PartType)
	if not metadata then return false end
	local canonical=metadata.Id
	local record=ledger(self,userId)
	if receipt.Kind=="Stack" then
		record.Stacks[canonical]=(record.Stacks[canonical] or 0)+1
		bump(record)
		return true
	end
	if receipt.Kind=="Unique" and type(receipt.Item)=="table" then
		local item=clone(receipt.Item)
		local id=tostring(item.UniqueId or "")
		if id=="" or record.Unique[id]~=nil then return false end
		item.UniqueId=id; item.PartType=canonical; item.OwnerUserId=userId
		item.MaxDurability=math.max(1,math.floor(tonumber(item.MaxDurability) or metadata.MaxDurability))
		item.Durability=math.clamp(math.floor(tonumber(item.Durability) or item.MaxDurability),0,item.MaxDurability)
		record.Unique[id]=item
		bump(record)
		return true
	end
	return false
end

function Inventory:ReturnBuiltPart(userId: number, partType: string, receipt: any, conditionRatio: number?): boolean
	local metadata=self:GetPartMetadata(partType)
	if not metadata then return false end
	if type(receipt)=="table" and receipt.PartType==metadata.Id then
		local copyReceipt=clone(receipt)
		if copyReceipt.Kind=="Unique" and type(copyReceipt.Item)=="table" then
			local maxDurability=math.max(1,math.floor(tonumber(copyReceipt.Item.MaxDurability) or metadata.MaxDurability))
			local ratio=math.clamp(tonumber(conditionRatio) or 1,0,1)
			copyReceipt.Item.MaxDurability=maxDurability
			copyReceipt.Item.Durability=math.floor(maxDurability*ratio+.5)
		end
		return self:RestorePartReceipt(userId,copyReceipt)
	end
	self:GrantPart(userId,metadata.Id,1,{Source="BuildReturn",Condition=math.clamp(tonumber(conditionRatio) or 1,0,1)})
	return true
end

function Inventory:Consume(userId: number, partType: string, amount: number): boolean
	local metadata = self:GetPartMetadata(partType)
	if not metadata or amount <= 0 or amount % 1 ~= 0 then return false end
	local canonical = metadata.Id
	if self:GetBuildableCount(userId, canonical) < amount then return false end
	local record = ledger(self, userId)
	local stacked = tonumber(record.Stacks[canonical]) or 0
	local fromStack = math.min(stacked, amount)
	local neededUnique = amount - fromStack
	local candidates = {}
	if neededUnique > 0 then
		for id, item in pairs(record.Unique) do
			local durability=tonumber(item.Durability) or 0
			if item.PartType == canonical and durability>0 then table.insert(candidates,{Id=id,Durability=durability}) end
		end
		table.sort(candidates,function(a,b) return if a.Durability==b.Durability then a.Id<b.Id else a.Durability<b.Durability end)
		if #candidates < neededUnique then return false end
	end
	if fromStack > 0 then record.Stacks[canonical] = stacked - fromStack end
	for index = 1, neededUnique do record.Unique[candidates[index].Id] = nil end
	bump(record)
	return true
end

function Inventory:GrantMaterial(userId: number, materialId: string, amount: number, _source: string?): boolean
	if not Definitions.Materials[materialId] or amount <= 0 or amount % 1 ~= 0 then return false end
	local record = ledger(self, userId)
	record.Materials[materialId] = (record.Materials[materialId] or 0) + amount
	bump(record)
	return true
end

function Inventory:GrantMaterials(userId: number, materials: {[string]: number}, source: string?)
	for id, amount in pairs(materials) do self:GrantMaterial(userId, id, amount, source) end
end

function Inventory:ConsumeMaterials(userId: number, costs: {[string]: number}): boolean
	local record = ledger(self, userId)
	for id, amount in pairs(costs) do
		if not Definitions.Materials[id] or amount < 0 or amount % 1 ~= 0 or (record.Materials[id] or 0) < amount then return false end
	end
	for id, amount in pairs(costs) do record.Materials[id] = (record.Materials[id] or 0) - amount end
	bump(record)
	return true
end

function Inventory:GetUnique(userId: number, uniqueId: string): any?
	local item = ledger(self, userId).Unique[uniqueId]
	return item and clone(item) or nil
end

function Inventory:RemoveUnique(userId: number, uniqueId: string): boolean
	local record = ledger(self, userId)
	if not record.Unique[uniqueId] then return false end
	record.Unique[uniqueId] = nil
	bump(record)
	return true
end

function Inventory:SetCondition(userId: number, uniqueId: string, durability: number): (boolean, any)
	local record = ledger(self, userId)
	local item = record.Unique[uniqueId]
	if not item then return false, "ItemNotOwned" end
	item.Durability = math.clamp(math.floor(durability), 0, item.MaxDurability)
	bump(record)
	return true, clone(item)
end

function Inventory:ApplyTransactionOnce(userId: number, transactionId: string, callback: (any) -> ()): (boolean, string?)
	if type(transactionId)~="string" or transactionId=="" or #transactionId>MAX_TRANSACTION_ID_LENGTH then return false,"InvalidTransaction" end
	local record = ledger(self, userId)
	if record.AppliedTransactions[transactionId] then return false,"AlreadyApplied" end
	local before = clone(record)
	local ok, reason = pcall(callback, record)
	if not ok then
		self._players[userId] = before
		warn("[MechFramework] Inventory transaction rolled back", transactionId, reason)
		return false,"TransactionFailed"
	end
	record.AppliedTransactions[transactionId] = os.time()
	pruneTransactions(record)
	bump(record)
	return true,nil
end

function Inventory:Snapshot(userId: number): any return clone(ledger(self, userId)) end

function Inventory:Restore(userId: number, snapshot: any)
	local restored = freshRecord()
	if type(snapshot) ~= "table" then self._players[userId] = restored; return end

	if snapshot.Stacks or snapshot.Unique or snapshot.Materials then
		for partType, amount in pairs(snapshot.Stacks or {}) do
			local metadata = if type(partType) == "string" then self:GetPartMetadata(partType) else nil
			if metadata and type(amount) == "number" and amount >= 0 and amount % 1 == 0 then
				restored.Stacks[metadata.Id] = (restored.Stacks[metadata.Id] or 0) + amount
			end
		end
		for id, item in pairs(snapshot.Unique or {}) do
			local metadata = if type(id)=="string" and type(item) == "table" and type(item.PartType) == "string" then self:GetPartMetadata(item.PartType) else nil
			if metadata then
				local migrated = clone(item)
				migrated.UniqueId = id
				migrated.OwnerUserId = userId
				migrated.PartType = metadata.Id
				migrated.MaxDurability = math.max(1,math.floor(tonumber(migrated.MaxDurability) or metadata.MaxDurability))
				migrated.Durability = math.clamp(math.floor(tonumber(migrated.Durability) or migrated.MaxDurability), 0, migrated.MaxDurability)
				restored.Unique[id] = migrated
			end
		end
		for materialId, amount in pairs(snapshot.Materials or {}) do
			if type(materialId)=="string" and Definitions.Materials[materialId] and type(amount)=="number" and amount>=0 and amount%1==0 then restored.Materials[materialId]=amount end
		end
		restored.Revision = math.max(0,math.floor(tonumber(snapshot.Revision) or 0))
		for transactionId, timestamp in pairs(snapshot.AppliedTransactions or {}) do
			if type(transactionId)=="string" and transactionId~="" and #transactionId<=MAX_TRANSACTION_ID_LENGTH and type(timestamp)=="number" and timestamp>=0 then restored.AppliedTransactions[transactionId]=timestamp end
		end
		pruneTransactions(restored)
	else
		for partType, amount in pairs(snapshot) do
			local metadata = if type(partType) == "string" then self:GetPartMetadata(partType) else nil
			if metadata and type(amount) == "number" and amount >= 0 and amount % 1 == 0 then restored.Stacks[metadata.Id] = (restored.Stacks[metadata.Id] or 0) + amount end
		end
	end
	self._players[userId] = restored
end

function Inventory:RemovePlayer(userId: number) self._players[userId] = nil end
return Inventory