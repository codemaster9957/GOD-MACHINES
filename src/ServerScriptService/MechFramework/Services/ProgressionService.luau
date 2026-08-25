--!strict
-- Server-authoritative crafting, salvage, loot, and repair transactions.
local HttpService = game:GetService("HttpService")
local Definitions = require(game.ReplicatedStorage.MechFramework.Shared.CollectionDefinitions)
local Progression: any = { _inventory = nil, _claimedRewards = {} }

local function weightedEntry(entries: {any}, rng: Random): any?
	local total = 0
	for _, entry in ipairs(entries) do total += math.max(0, entry.Weight or 0) end
	if total <= 0 then return nil end
	local choice = rng:NextNumber(0, total)
	for _, entry in ipairs(entries) do
		choice -= math.max(0, entry.Weight or 0)
		if choice <= 0 then return entry end
	end
	return entries[#entries]
end

function Progression:Init(container: any)
	self._inventory = container:Get("InventoryService")
end

function Progression:Craft(userId: number, recipeId: string): (boolean, any)
	local recipe = Definitions.Recipes[recipeId]
	if not recipe then return false, "UnknownRecipe" end
	if not self._inventory:ConsumeMaterials(userId, recipe.Costs) then return false, "InsufficientMaterials" end
	local output = recipe.Output
	local ok, result = pcall(function()
		if output.Kind == "Part" then
			return self._inventory:GrantPart(userId, output.Id, output.Amount, { Source = "Crafted:" .. recipeId })
		end
		return self._inventory:GrantMaterial(userId, output.Id, output.Amount, "Crafted:" .. recipeId)
	end)
	if not ok then
		self._inventory:GrantMaterials(userId, recipe.Costs, "CraftRollback")
		return false, "CraftFailed"
	end
	return true, result
end

function Progression:Repair(userId: number, uniqueId: string): (boolean, any)
	local item = self._inventory:GetUnique(userId, uniqueId)
	if not item then return false, "ItemNotOwned" end
	local missing = math.max(0, item.MaxDurability - item.Durability)
	if missing <= 0 then return false, "AlreadyRepaired" end
	local costs = { ScrapMetal = math.max(1, math.ceil(missing / 25)) }
	if not self._inventory:ConsumeMaterials(userId, costs) then return false, "InsufficientMaterials" end
	return self._inventory:SetCondition(userId, uniqueId, item.MaxDurability), costs
end

function Progression:SalvagePart(userId: number, uniqueId: string): (boolean, any)
	local item = self._inventory:GetUnique(userId, uniqueId)
	if not item then return false, "ItemNotOwned" end
	if item.Tradability == "Locked" then return false, "LockedItem" end
	local ratio = math.clamp(item.Durability / math.max(1, item.MaxDurability), 0, 1)
	local yield = { ScrapMetal = math.max(1, math.floor(3 + ratio * 7)) }
	if not self._inventory:RemoveUnique(userId, uniqueId) then return false, "TransactionConflict" end
	self._inventory:GrantMaterials(userId, yield, "Salvaged:" .. item.PartType)
	return true, yield
end

function Progression:AwardLoot(userId: number, tableId: string, rewardId: string, seed: number?): (boolean, any)
	-- rewardId must originate from a trusted server encounter/mission and is single-use.
	if type(rewardId) ~= "string" or #rewardId < 8 then return false, "InvalidReward" end
	local claimKey = tostring(userId) .. ":" .. rewardId
	if self._claimedRewards[claimKey] then return false, "AlreadyClaimed" end
	local loot = Definitions.LootTables[tableId]
	if not loot then return false, "UnknownLootTable" end
	self._claimedRewards[claimKey] = true
	local rng = Random.new(seed or math.floor(os.clock() * 100000) % 2147483647)
	local awarded = {}
	for _ = 1, loot.Rolls do
		local entry = weightedEntry(loot.Entries, rng)
		if entry then
			local amount = rng:NextInteger(entry.Min or 1, entry.Max or 1)
			if entry.Kind == "Material" then
				self._inventory:GrantMaterial(userId, entry.Id, amount, "Loot:" .. tableId)
			else
				local condition = entry.Condition and rng:NextNumber(entry.Condition[1], entry.Condition[2]) or 1
				self._inventory:GrantPart(userId, entry.Id, amount, { Source = "Loot:" .. tableId, Condition = condition })
			end
			table.insert(awarded, { Kind = entry.Kind, Id = entry.Id, Amount = amount })
		end
	end
	return true, awarded
end

function Progression:CreateSalvageToken(): string
	return HttpService:GenerateGUID(false)
end

return Progression