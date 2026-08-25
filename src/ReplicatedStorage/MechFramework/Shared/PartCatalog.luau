--!strict
-- Public, data-only build catalog. State-changing authority remains on the server.
-- The catalog validates aggressively at require-time so one malformed recipe cannot poison runtime physics.

local folder = script.Parent:WaitForChild("PartDefinitions")
local WeaponDefinitions = require(script.Parent:WaitForChild("WeaponDefinitions"))

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

local VALID_GEOMETRY_KINDS = table.freeze({
	Block=true, Wedge=true, CornerWedge=true, Cylinder=true, Ball=true, Seat=true, VehicleSeat=true,
})
local VALID_RARITIES = table.freeze({ Common=true, Uncommon=true, Rare=true, Experimental=true })

local function clone(value: any): any
	if type(value) ~= "table" then return value end
	local out: {[any]: any} = {}
	for key, item in pairs(value) do out[key] = clone(item) end
	return out
end

local function finite(value: any): boolean
	return type(value)=="number" and value==value and value~=math.huge and value~=-math.huge
end

local function nonNegative(value: any): boolean
	return finite(value) and value >= 0
end

local definitions: {[string]: any} = {}
local ordered = {}
local categoryRank = {}
for index, category in ipairs(CATEGORY_ORDER) do categoryRank[category] = index end

local function validateNumericFields(partId: string, blockName: string, block: any, fields: {string})
	if block == nil then return end
	assert(type(block)=="table", partId.." "..blockName.." must be a table")
	for _, field in ipairs(fields) do
		local value = block[field]
		if value ~= nil then assert(nonNegative(value), partId.." "..blockName.."."..field.." must be finite and non-negative") end
	end
end

local function validateDefinition(definition: any)
	assert(type(definition) == "table", "Part definition must be a table")
	assert(type(definition.Id) == "string" and definition.Id ~= "", "Part requires Id")
	local id = definition.Id
	assert(#id <= 80, id .. " Id is too long")
	assert(type(definition.DisplayName) == "string" and definition.DisplayName ~= "", id .. " requires DisplayName")
	assert(type(definition.ShortName) == "string" and definition.ShortName ~= "", id .. " requires ShortName")
	assert(categoryRank[definition.Category] ~= nil, id .. " has invalid Category")
	assert(type(definition.Description) == "string" and #definition.Description >= 12, id .. " requires useful Description")
	assert(typeof(definition.Size) == "Vector3" and definition.Size.X > 0 and definition.Size.Y > 0 and definition.Size.Z > 0, id .. " requires positive Size")
	assert(finite(definition.Mass) and definition.Mass > 0, id .. " requires positive finite Mass")
	assert(finite(definition.MaxHealth) and definition.MaxHealth > 0, id .. " requires positive finite MaxHealth")
	assert(VALID_RARITIES[definition.Rarity or "Common"] == true, id .. " has invalid Rarity")
	assert(type(definition.Geometry) == "table" and #definition.Geometry >= 2, id .. " requires multi-primitive Geometry")
	assert(type(definition.AttachmentNodes) == "table" and #definition.AttachmentNodes >= 1, id .. " requires attachment nodes")
	assert(type(definition.PaintRegions) == "table" and #definition.PaintRegions >= 3, id .. " requires paint regions")
	assert(type(definition.PaintDefaults) == "table" and typeof(definition.PaintDefaults.Primary)=="Color3", id .. " requires PaintDefaults.Primary")

	local regions: {[string]: boolean} = {}
	for _, region in ipairs(definition.PaintRegions) do
		assert(type(region)=="string" and region~="", id.." has invalid paint region")
		assert(not regions[region], id.." duplicate paint region "..region)
		regions[region]=true
		local defaultColor=definition.PaintDefaults[region]
		if defaultColor~=nil then assert(typeof(defaultColor)=="Color3", id.." PaintDefaults."..region.." must be Color3") end
	end

	local nodeNames: {[string]: boolean} = {}
	for _, node in ipairs(definition.AttachmentNodes) do
		assert(type(node) == "table", id .. " node must be table")
		assert(type(node.Name) == "string" and node.Name ~= "", id .. " node requires Name")
		assert(not nodeNames[node.Name], id .. " duplicate node " .. node.Name)
		assert(type(node.Type) == "string" and node.Type ~= "", id .. " node requires Type")
		assert(typeof(node.Transform) == "CFrame", id .. " node requires Transform")
		assert(type(node.Accepts) == "table" and #node.Accepts > 0, id .. " node requires Accepts")
		for _, accepts in ipairs(node.Accepts) do assert(type(accepts)=="string" and accepts~="", id.." node has invalid compatibility") end
		nodeNames[node.Name] = true
	end

	local visualNames: {[string]: boolean} = {}
	for _, item in ipairs(definition.Geometry) do
		assert(type(item) == "table", id .. " geometry item must be table")
		assert(type(item.Name) == "string" and item.Name ~= "", id .. " geometry requires Name")
		assert(not visualNames[item.Name], id .. " duplicate geometry name " .. item.Name)
		assert(type(item.Kind) == "string" and VALID_GEOMETRY_KINDS[item.Kind] == true, id .. " geometry has unsupported Kind " .. tostring(item.Kind))
		assert(typeof(item.Size) == "Vector3" and item.Size.X>0 and item.Size.Y>0 and item.Size.Z>0, id .. " geometry requires positive Size")
		assert(typeof(item.CFrame) == "CFrame", id .. " geometry requires CFrame")
		assert(type(item.Region) == "string" and regions[item.Region] == true, id .. " geometry references undeclared paint Region " .. tostring(item.Region))
		if item.Transparency~=nil then assert(finite(item.Transparency) and item.Transparency>=0 and item.Transparency<=1, id.." geometry Transparency must be 0..1") end
		if item.Role~=nil then assert(type(item.Role)=="string" and #item.Role<=60, id.." geometry Role must be a short string") end
		visualNames[item.Name] = true
	end

	validateNumericFields(id,"Power",definition.Power,{"Generation","MaximumOutput","Demand","Priority","StorageCapacity","Capacity","Charge","StorageOutput","StorageInput"})
	validateNumericFields(id,"Heat",definition.Heat,{"Generation","Capacity","Dissipation","Cooling","DamagedGeneration","ShutdownTemperature","DamageTemperature","ExplosionTemperature","JamTemperature","OverheatDamage","Conductivity"})
	validateNumericFields(id,"Fuel",definition.Fuel,{"Capacity","Amount","Use"})
	validateNumericFields(id,"Mobility",definition.Mobility,{"Radius","SuspensionTravel","DriveTorque","Grip"})
	validateNumericFields(id,"Propulsion",definition.Propulsion,{"Force","MechanicalPower","MechanicalDemand","Torque","FuelUse","ThrottleResponse","GimbalDegrees"})
	validateNumericFields(id,"Aerodynamics",definition.Aerodynamics,{"Area","LiftCoefficient","DragCoefficient","ControlAuthority"})

	if definition.Mobility then assert(type(definition.Mobility.Kind)=="string" and definition.Mobility.Kind~="", id.." Mobility requires Kind") end
	if definition.Propulsion then
		assert(type(definition.Propulsion.Kind)=="string" and definition.Propulsion.Kind~="", id.." Propulsion requires Kind")
		if definition.Propulsion.Direction~=nil then assert(typeof(definition.Propulsion.Direction)=="Vector3" and definition.Propulsion.Direction.Magnitude>.001, id.." Propulsion.Direction must be non-zero Vector3") end
	end
	if definition.Aerodynamics then
		assert(type(definition.Aerodynamics.Kind)=="string" and definition.Aerodynamics.Kind~="", id.." Aerodynamics requires Kind")
		assert((tonumber(definition.Aerodynamics.Area) or 0)>0, id.." Aerodynamics requires positive Area")
	end
	if definition.Pilot then assert(type(definition.Pilot.Kind)=="string" and definition.Pilot.Kind~="", id.." Pilot requires Kind") end
	if definition.Combat then
		assert(type(definition.Combat)=="table", id.." Combat must be a table")
		local preset=definition.Combat.Preset
		if preset~=nil then assert(type(preset)=="string" and WeaponDefinitions.Presets[preset]~=nil, id.." references unknown weapon preset "..tostring(preset)) end
		local resolved=WeaponDefinitions.Resolve(definition.Combat)
		assert((tonumber(resolved.Damage) or 0)>=0 and (tonumber(resolved.Range) or 0)>0 and (tonumber(resolved.FireRate) or 0)>0, id.." has invalid resolved combat configuration")
	end
end

local displayNames: {[string]: string} = {}
local categoryCounts: {[string]: number} = {}

for _, moduleName in ipairs(MODULES) do
	local module = folder:WaitForChild(moduleName)
	assert(module:IsA("ModuleScript"), "PartDefinitions." .. moduleName .. " must be a ModuleScript")
	local list = require(module)
	assert(type(list) == "table" and #list > 0, moduleName .. " must return a non-empty table")
	for _, definition in ipairs(list) do
		validateDefinition(definition)
		assert(definitions[definition.Id] == nil, "Duplicate PartCatalog Id: " .. definition.Id)
		local displayKey=string.lower(definition.DisplayName)
		assert(displayNames[displayKey]==nil, "Duplicate PartCatalog DisplayName: "..definition.DisplayName)
		displayNames[displayKey]=definition.Id
		categoryCounts[definition.Category]=(categoryCounts[definition.Category] or 0)+1
		local stored = clone(definition)
		definitions[stored.Id] = stored
		table.insert(ordered, stored)
	end
end

assert(#ordered == 100, string.format("PartCatalog must contain exactly 100 parts; got %d", #ordered))
for _,category in ipairs(CATEGORY_ORDER) do assert((categoryCounts[category] or 0)>0,"PartCatalog category is empty: "..category) end

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
function Catalog.GetAll(): {[string]: any} return clone(definitions) end
function Catalog.GetList(): {any} return clone(ordered) end
function Catalog.GetCategories(): {string} return clone(CATEGORY_ORDER) end
function Catalog.GetCategoryCounts(): {[string]: number} return clone(categoryCounts) end
function Catalog.Count(): number return #ordered end
function Catalog.Validate(): (boolean, string)
	if #ordered ~= 100 then return false, "CatalogCountMismatch" end
	for id, definition in pairs(definitions) do
		local ok, reason = pcall(validateDefinition, definition)
		if not ok then return false, tostring(reason) end
		if id ~= definition.Id then return false, "CatalogKeyMismatch:" .. tostring(id) end
	end
	return true, "OK"
end

return table.freeze(Catalog)
