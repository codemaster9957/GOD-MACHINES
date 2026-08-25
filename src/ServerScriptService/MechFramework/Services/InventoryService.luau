--!strict
-- Server-authoritative collection ledger with stackable parts, unique components, and materials.
-- Studio debug inventory is seeded here because InventoryService is part of the builder's core startup path.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local Shared = game.ReplicatedStorage.MechFramework.Shared
local Definitions = require(Shared.CollectionDefinitions)
local WeaponCatalog = require(Shared.WeaponCatalog)
local Config = require(Shared.FrameworkConfig)

local Inventory: any = { _players = {} }

local STUDIO_BUILD_PARTS = {
	"StructuralFrame",
	"SmallReactor",
}

for _, weapon in ipairs(WeaponCatalog.Ordered) do
	table.insert(STUDIO_BUILD_PARTS, weapon.Id)
end

local STUDIO_BUILD_AMOUNT = 25

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

local function bump(record: any)
	record.Revision += 1
end

function Inventory:GetCount(userId: number, partType: string): number
	local record = ledger(self, userId)
	local count = record.Stacks[partType] or 0
	for _, item in pairs(record.Unique) do if item.PartType == partType then count += 1 end end
	return count
end

function Inventory:GrantPart(userId: number, partType: string, amount: number, metadata: any?): any
	assert(type(partType) == "string" and Definitions.Parts[partType], "Unknown part definition")
	assert(amount > 0 and amount % 1 == 0, "Amount must be a positive integer")
	local record = ledger(self, userId)
	local definition = Definitions.Parts[partType]
	local created = {}
	if definition.Stackable then
		record.Stacks[partType] = (record.Stacks[partType] or 0) + amount
	else
		for _ = 1, amount do
			local id = HttpService:GenerateGUID(false)
			local ratio = math.clamp((metadata and metadata.Condition) or 1, 0, 1)
			local item = {
				UniqueId = id, PartType = partType, OwnerUserId = userId,
				Rarity = definition.Rarity, Durability = math.floor(definition.MaxDurability * ratio + 0.5),
				MaxDurability = definition.MaxDurability, Modifiers = clone((metadata and metadata.Modifiers) or {}),
				Source = (metadata and metadata.Source) or "ServerGrant", Tradability = (metadata and metadata.Tradability) or "Tradable",
			}
			record.Unique[id] = item; table.insert(created, clone(item))
		end
	end
	bump(record)
	return definition.Stackable and amount or created
end

-- Legacy build compatibility. Grants real collection parts, never client-authored definitions.
function Inventory:Grant(userId: number, partType: string, amount: number)
	return self:GrantPart(userId, partType, amount, { Source = "LegacyGrant" })
end

function Inventory:EnsureStudioBuildInventory(userId: number)
	if not (RunService:IsStudio() and Config.Debug) then
		return
	end

	for _, partType in ipairs(STUDIO_BUILD_PARTS) do
		if self:GetCount(userId, partType) == 0 then
			self:GrantPart(userId, partType, STUDIO_BUILD_AMOUNT, { Source = "StudioDebug" })
		end
	end

	print("[MechFramework] Studio build inventory ready", userId)
end

function Inventory:Start()
	if not (RunService:IsStudio() and Config.Debug) then
		return
	end

	Players.PlayerAdded:Connect(function(player)
		self:EnsureStudioBuildInventory(player.UserId)
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		self:EnsureStudioBuildInventory(player.UserId)
	end
end

function Inventory:Consume(userId: number, partType: string, amount: number): boolean
	if amount <= 0 or amount % 1 ~= 0 then return false end
	local record = ledger(self, userId)
	local stacked = record.Stacks[partType] or 0
	local needed = amount
	if stacked > 0 then
		local used = math.min(stacked, needed); record.Stacks[partType] = stacked - used; needed -= used
	end
	if needed > 0 then
		local ids = {}
		for id, item in pairs(record.Unique) do if item.PartType == partType then table.insert(ids, id) end end
		table.sort(ids)
		if #ids < needed then return false end
		for index = 1, needed do record.Unique[ids[index]] = nil end
	end
	bump(record); return true
end

function Inventory:GrantMaterial(userId: number, materialId: string, amount: number, _source: string?): boolean
	if not Definitions.Materials[materialId] or amount <= 0 or amount % 1 ~= 0 then return false end
	local record = ledger(self, userId); record.Materials[materialId] = (record.Materials[materialId] or 0) + amount; bump(record); return true
end

function Inventory:GrantMaterials(userId: number, materials: {[string]: number}, source: string?)
	for id, amount in pairs(materials) do self:GrantMaterial(userId, id, amount, source) end
end

function Inventory:ConsumeMaterials(userId: number, costs: {[string]: number}): boolean
	local record = ledger(self, userId)
	for id, amount in pairs(costs) do if not Definitions.Materials[id] or amount < 0 or (record.Materials[id] or 0) < amount then return false end end
	for id, amount in pairs(costs) do record.Materials[id] = (record.Materials[id] or 0) - amount end
	bump(record); return true
end

function Inventory:GetUnique(userId: number, uniqueId: string): any?
	local item = ledger(self, userId).Unique[uniqueId]
	return item and clone(item) or nil
end

function Inventory:RemoveUnique(userId: number, uniqueId: string): boolean
	local record = ledger(self, userId)
	if not record.Unique[uniqueId] then return false end
	record.Unique[uniqueId] = nil; bump(record); return true
end

function Inventory:SetCondition(userId: number, uniqueId: string, durability: number): (boolean, any)
	local record = ledger(self, userId); local item = record.Unique[uniqueId]
	if not item then return false, "ItemNotOwned" end
	item.Durability = math.clamp(math.floor(durability), 0, item.MaxDurability); bump(record); return true, clone(item)
end

function Inventory:ApplyTransactionOnce(userId: number, transactionId: string, callback: (any) -> ()): boolean
	local record = ledger(self, userId)
	if record.AppliedTransactions[transactionId] then return false end
	callback(record); record.AppliedTransactions[transactionId] = os.time(); bump(record); return true
end

function Inventory:Snapshot(userId: number): any return clone(ledger(self, userId)) end

function Inventory:Restore(userId: number, snapshot: any)
	-- Accept old {[partType]: count} snapshots as well as current records.
	if snapshot.Stacks or snapshot.Unique or snapshot.Materials then
		local restored = freshRecord()
		restored.Stacks = clone(snapshot.Stacks or {}); restored.Unique = clone(snapshot.Unique or {}); restored.Materials = clone(snapshot.Materials or {})
		restored.Revision = tonumber(snapshot.Revision) or 0; restored.AppliedTransactions = clone(snapshot.AppliedTransactions or {})
		self._players[userId] = restored
	else
		local restored = freshRecord()
		for partType, amount in pairs(snapshot) do if type(partType) == "string" and type(amount) == "number" and amount >= 0 and amount % 1 == 0 then restored.Stacks[partType] = amount end end
		self._players[userId] = restored
	end
end

function Inventory:RemovePlayer(userId: number) self._players[userId] = nil end
return Inventory
