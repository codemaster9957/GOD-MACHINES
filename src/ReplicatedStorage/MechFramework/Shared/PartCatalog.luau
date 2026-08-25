--!strict
-- Public, data-only build catalog. State-changing authority remains on the server.

local folder = script.Parent:WaitForChild("PartDefinitions")

local CATEGORY_ORDER = table.freeze({
	"Structural",
	"Armour",
	"Mobility",
	"Propulsion",
	"Aerodynamics",
	"PowerCooling",
	"Control",
	"Weapons",
	"Utility",
})

local MODULES = {
	"Structural",
	"Armour",
	"Mobility",
	"Propulsion",
	"Aerodynamics",
	"PowerCooling",
	"Control",
	"Weapons",
	"Utility",
}

local function clone(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local out: {[any]: any} = {}
	for key, item in pairs(value) do
		out[key] = clone(item)
	end
	return out
end

local definitions: {[string]: any} = {}
local ordered = {}
local categoryRank = {}
for index, category in ipairs(CATEGORY_ORDER) do
	categoryRank[category] = index
end

local function validateDefinition(definition: any)
	assert(type(definition) == "table", "Part definition must be a table")
	assert(type(definition.Id) == "string" and definition.Id ~= "", "Part requires Id")
	assert(type(definition.DisplayName) == "string" and definition.DisplayName ~= "", definition.Id .. " requires DisplayName")
	assert(type(definition.ShortName) == "string" and definition.ShortName ~= "", definition.Id .. " requires ShortName")
	assert(categoryRank[definition.Category] ~= nil, definition.Id .. " has invalid Category")
	assert(type(definition.Description) == "string" and #definition.Description >= 12, definition.Id .. " requires useful Description")
	assert(typeof(definition.Size) == "Vector3" and definition.Size.X > 0 and definition.Size.Y > 0 and definition.Size.Z > 0, definition.Id .. " requires positive Size")
	assert(type(definition.Mass) == "number" and definition.Mass > 0, definition.Id .. " requires positive Mass")
	assert(type(definition.MaxHealth) == "number" and definition.MaxHealth > 0, definition.Id .. " requires positive MaxHealth")
	assert(type(definition.Geometry) == "table" and #definition.Geometry >= 2, definition.Id .. " requires multi-primitive Geometry")
	assert(type(definition.AttachmentNodes) == "table" and #definition.AttachmentNodes >= 1, definition.Id .. " requires attachment nodes")
	assert(type(definition.PaintRegions) == "table" and #definition.PaintRegions >= 3, definition.Id .. " requires paint regions")

	local nodeNames: {[string]: boolean} = {}
	for _, node in ipairs(definition.AttachmentNodes) do
		assert(type(node) == "table", definition.Id .. " node must be table")
		assert(type(node.Name) == "string" and node.Name ~= "", definition.Id .. " node requires Name")
		assert(not nodeNames[node.Name], definition.Id .. " duplicate node " .. node.Name)
		assert(type(node.Type) == "string" and node.Type ~= "", definition.Id .. " node requires Type")
		assert(typeof(node.Transform) == "CFrame", definition.Id .. " node requires Transform")
		assert(type(node.Accepts) == "table" and #node.Accepts > 0, definition.Id .. " node requires Accepts")
		nodeNames[node.Name] = true
	end

	local visualNames: {[string]: boolean} = {}
	for _, item in ipairs(definition.Geometry) do
		assert(type(item) == "table", definition.Id .. " geometry item must be table")
		assert(type(item.Name) == "string" and item.Name ~= "", definition.Id .. " geometry requires Name")
		assert(not visualNames[item.Name], definition.Id .. " duplicate geometry name " .. item.Name)
		assert(type(item.Kind) == "string", definition.Id .. " geometry requires Kind")
		assert(typeof(item.Size) == "Vector3", definition.Id .. " geometry requires Size")
		assert(typeof(item.CFrame) == "CFrame", definition.Id .. " geometry requires CFrame")
		assert(type(item.Region) == "string" and item.Region ~= "", definition.Id .. " geometry requires paint Region")
		visualNames[item.Name] = true
	end
end

for _, moduleName in ipairs(MODULES) do
	local module = folder:WaitForChild(moduleName)
	assert(module:IsA("ModuleScript"), "PartDefinitions." .. moduleName .. " must be a ModuleScript")
	local list = require(module)
	assert(type(list) == "table", moduleName .. " must return a table")
	for _, definition in ipairs(list) do
		validateDefinition(definition)
		assert(definitions[definition.Id] == nil, "Duplicate PartCatalog Id: " .. definition.Id)
		local stored = clone(definition)
		definitions[stored.Id] = stored
		table.insert(ordered, stored)
	end
end

assert(#ordered == 100, string.format("PartCatalog must contain exactly 100 parts; got %d", #ordered))

table.sort(ordered, function(a, b)
	local ar = categoryRank[a.Category] or 999
	local br = categoryRank[b.Category] or 999
	if ar ~= br then
		return ar < br
	end
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
	return clone(CATEGORY_ORDER)
end

function Catalog.Count(): number
	return #ordered
end

function Catalog.Validate(): (boolean, string)
	if #ordered ~= 100 then
		return false, "CatalogCountMismatch"
	end
	for id, definition in pairs(definitions) do
		local ok, reason = pcall(validateDefinition, definition)
		if not ok then
			return false, tostring(reason)
		end
		if id ~= definition.Id then
			return false, "CatalogKeyMismatch:" .. tostring(id)
		end
	end
	return true, "OK"
end

return table.freeze(Catalog)
