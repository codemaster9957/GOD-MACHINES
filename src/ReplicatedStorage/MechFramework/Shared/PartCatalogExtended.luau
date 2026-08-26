--!strict
-- Expansion-safe public catalogue: preserves the validated legacy 100-part catalogue and appends optional packs.

local Base = require(script.Parent:WaitForChild("PartCatalog"))
local GundamWeaponParts = require(script.Parent:WaitForChild("GundamWeaponParts"))
local WeaponDefinitions = require(script.Parent:WaitForChild("WeaponDefinitions"))

local categories = Base.GetCategories()
local categoryRank: {[string]: number} = {}
for index, category in ipairs(categories) do categoryRank[category] = index end

local function clone(value: any): any
	if type(value) ~= "table" then return value end
	local out: {[any]: any} = {}
	for key, item in pairs(value) do out[key] = clone(item) end
	return out
end

local function validateExpansion(definition: any)
	assert(type(definition) == "table", "Expansion part definition must be a table")
	assert(type(definition.Id) == "string" and definition.Id ~= "", "Expansion part requires Id")
	assert(type(definition.DisplayName) == "string" and definition.DisplayName ~= "", definition.Id .. " requires DisplayName")
	assert(type(definition.ShortName) == "string" and definition.ShortName ~= "", definition.Id .. " requires ShortName")
	assert(categoryRank[definition.Category] ~= nil, definition.Id .. " has invalid Category")
	assert(typeof(definition.Size) == "Vector3" and definition.Size.X > 0 and definition.Size.Y > 0 and definition.Size.Z > 0, definition.Id .. " requires positive Size")
	assert(type(definition.Mass) == "number" and definition.Mass > 0, definition.Id .. " requires positive Mass")
	assert(type(definition.MaxHealth) == "number" and definition.MaxHealth > 0, definition.Id .. " requires positive MaxHealth")
	assert(type(definition.Geometry) == "table" and #definition.Geometry >= 2, definition.Id .. " requires multi-primitive Geometry")
	assert(type(definition.AttachmentNodes) == "table" and #definition.AttachmentNodes > 0, definition.Id .. " requires attachment nodes")
	assert(type(definition.PaintRegions) == "table" and #definition.PaintRegions >= 3, definition.Id .. " requires paint regions")
	assert(type(definition.PaintDefaults) == "table" and typeof(definition.PaintDefaults.Primary) == "Color3", definition.Id .. " requires paint defaults")

	local names: {[string]: boolean} = {}
	for _, node in ipairs(definition.AttachmentNodes) do
		assert(type(node) == "table" and type(node.Name) == "string" and node.Name ~= "", definition.Id .. " has invalid attachment node")
		assert(not names[node.Name], definition.Id .. " has duplicate attachment node " .. node.Name)
		assert(type(node.Type) == "string" and node.Type ~= "", definition.Id .. " attachment node requires Type")
		assert(typeof(node.Transform) == "CFrame", definition.Id .. " attachment node requires Transform")
		assert(type(node.Accepts) == "table" and #node.Accepts > 0, definition.Id .. " attachment node requires compatibility")
		names[node.Name] = true
	end

	if definition.Combat then
		local preset = definition.Combat.Preset
		assert(preset == nil or (type(preset) == "string" and WeaponDefinitions.Presets[preset] ~= nil), definition.Id .. " references an unknown weapon preset")
		local resolved = WeaponDefinitions.Resolve(definition.Combat)
		assert((tonumber(resolved.Damage) or 0) > 0, definition.Id .. " requires positive weapon damage")
		assert((tonumber(resolved.FireRate) or 0) > 0, definition.Id .. " requires positive weapon fire rate")
		assert((tonumber(resolved.Range) or 0) > 0, definition.Id .. " requires positive weapon range")
	end
end

local definitions = Base.GetAll()
local ordered = Base.GetList()
local categoryCounts = Base.GetCategoryCounts()

for _, definition in ipairs(GundamWeaponParts) do
	validateExpansion(definition)
	assert(definitions[definition.Id] == nil, "Expansion duplicates existing PartCatalog Id: " .. definition.Id)
	local stored = clone(definition)
	definitions[stored.Id] = stored
	table.insert(ordered, stored)
	categoryCounts[stored.Category] = (categoryCounts[stored.Category] or 0) + 1
end

table.sort(ordered, function(a, b)
	local ar = categoryRank[a.Category] or 999
	local br = categoryRank[b.Category] or 999
	if ar ~= br then return ar < br end
	return a.DisplayName < b.DisplayName
end)

local Catalog = {}

function Catalog.Get(id: string): any?
	local definition = definitions[id]
	return if definition then clone(definition) else nil
end

function Catalog.GetAll(): {[string]: any}
	return clone(definitions)
end

function Catalog.GetList(): {any}
	return clone(ordered)
end

function Catalog.GetCategories(): {string}
	return clone(categories)
end

function Catalog.GetCategoryCounts(): {[string]: number}
	return clone(categoryCounts)
end

function Catalog.Count(): number
	return #ordered
end

function Catalog.Validate(): (boolean, string)
	local baseValid, baseReason = Base.Validate()
	if not baseValid then return false, "BaseCatalog:" .. tostring(baseReason) end
	if #ordered < 100 then return false, "CatalogCountBelowLegacyMinimum" end
	local seen: {[string]: boolean} = {}
	for _, definition in ipairs(ordered) do
		if seen[definition.Id] then return false, "DuplicateId:" .. tostring(definition.Id) end
		seen[definition.Id] = true
		if definitions[definition.Id] == nil then return false, "MissingDefinition:" .. tostring(definition.Id) end
		local ok, reason = pcall(validateExpansion, definition)
		if not ok and Base.Get(definition.Id) == nil then return false, tostring(reason) end
	end
	return true, "OK"
end

assert(#ordered >= 100, string.format("Extended PartCatalog must contain at least 100 parts; got %d", #ordered))

return table.freeze(Catalog)
