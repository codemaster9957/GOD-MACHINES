--!strict
-- Data-only collection content. Rarity describes scarcity/specialisation, not power.
local WeaponCatalog = require(script.Parent.WeaponCatalog)\n\nlocal Definitions = {}

Definitions.Rarities = table.freeze({
	Common = { Scarcity = 1, TradeLabel = "Industrial" },
	Uncommon = { Scarcity = 2, TradeLabel = "Specialised" },
	Rare = { Scarcity = 3, TradeLabel = "Restricted" },
	Experimental = { Scarcity = 4, TradeLabel = "Prototype" },
})

Definitions.Categories = table.freeze({
	"StructuralFrames", "Armour", "Wheels", "Tracks", "LegComponents", "Engines",
	"Thrusters", "Generators", "Batteries", "Cooling", "Sensors", "Weapons", "Ammo",
	"MechanicalJoints", "UtilitySystems", "ExperimentalParts",
})

Definitions.Materials = table.freeze({
	ScrapMetal = { Name = "Scrap Metal", Tradable = true },
	Steel = { Name = "Steel", Tradable = true },
	Titanium = { Name = "Titanium", Tradable = true },
	Electronics = { Name = "Electronics", Tradable = true },
	EnergyCells = { Name = "Energy Cells", Tradable = true },
	CompositeArmour = { Name = "Composite Armour", Tradable = true },
	RareReactorMaterials = { Name = "Rare Reactor Materials", Tradable = true },
})

-- Stackable=false means each acquired part receives its own identity and condition.
local parts = {
	StructuralFrame = { Category = "StructuralFrames", Rarity = "Common", Stackable = true, MaxDurability = 250 },
	SmallReactor = { Category = "Generators", Rarity = "Uncommon", Stackable = false, MaxDurability = 180 },
	LightweightEngine = { Category = "Engines", Rarity = "Common", Stackable = false, MaxDurability = 140, Tags = { "Lightweight", "Efficient" } },
	CompositePlate = { Category = "Armour", Rarity = "Rare", Stackable = false, MaxDurability = 320 },
	PrototypeThruster = { Category = "ExperimentalParts", Rarity = "Experimental", Stackable = false, MaxDurability = 90 },
}

for _, weapon in ipairs(WeaponCatalog.Ordered) do
	parts[weapon.Id] = {
		Category = "Weapons",
		Rarity = weapon.Collection.Rarity,
		Stackable = false,
		MaxDurability = weapon.Collection.MaxDurability,
		Tags = { weapon.MountRole, weapon.Combat.Category },
	}
end

Definitions.Parts = table.freeze(parts)

Definitions.Recipes = table.freeze({
	StructuralFrame = { Output = { Kind = "Part", Id = "StructuralFrame", Amount = 1 }, Costs = { ScrapMetal = 12, Steel = 6 } },
	LightweightEngine = { Output = { Kind = "Part", Id = "LightweightEngine", Amount = 1 }, Costs = { Steel = 8, Electronics = 5, EnergyCells = 2 } },
	CompositePlate = { Output = { Kind = "Part", Id = "CompositePlate", Amount = 1 }, Costs = { Steel = 4, Titanium = 3, CompositeArmour = 5 } },
})

Definitions.LootTables = table.freeze({
	Enemy = { Rolls = 2, Entries = {
		{ Kind = "Material", Id = "ScrapMetal", Min = 3, Max = 9, Weight = 60 },
		{ Kind = "Material", Id = "Electronics", Min = 1, Max = 3, Weight = 25 },
		{ Kind = "Part", Id = "StructuralFrame", Min = 1, Max = 1, Weight = 15, Condition = { 0.25, 0.8 } },
	} },
	Boss = { Rolls = 4, Entries = {
		{ Kind = "Material", Id = "Titanium", Min = 2, Max = 6, Weight = 35 },
		{ Kind = "Material", Id = "RareReactorMaterials", Min = 1, Max = 2, Weight = 10 },
		{ Kind = "Part", Id = "SmallReactor", Min = 1, Max = 1, Weight = 30, Condition = { 0.2, 0.65 } },
		{ Kind = "Part", Id = "PrototypeThruster", Min = 1, Max = 1, Weight = 5, Condition = { 0.15, 0.5 } },
	} },
	Mission = { Rolls = 2, Entries = { { Kind = "Material", Id = "Steel", Min = 5, Max = 12, Weight = 1 } } },
	Crate = { Rolls = 1, Entries = { { Kind = "Material", Id = "EnergyCells", Min = 2, Max = 5, Weight = 1 } } },
	Salvage = { Rolls = 2, Entries = { { Kind = "Material", Id = "ScrapMetal", Min = 2, Max = 8, Weight = 1 } } },
})

return table.freeze(Definitions)