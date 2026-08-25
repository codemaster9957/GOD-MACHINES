--!strict
-- Immutable server registry backed by the shared 100-part public catalog.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PartCatalog = require(ReplicatedStorage.MechFramework.Shared.PartCatalog)

local Registry: any = {
	_definitions = {} :: {[string]: any},
	_ordered = {} :: {any},
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

function Registry:Register(partType: string, definition: any)
	assert(type(partType) == "string" and partType ~= "", "Invalid PartType")
	assert(self._definitions[partType] == nil, `PartType already registered: {partType}`)
	assert(type(definition) == "table", "Part definition must be a table")
	assert(definition.Id == partType, `Part Id mismatch: {partType}`)
	assert(type(definition.Mass) == "number" and definition.Mass > 0, "Mass must be positive")
	assert(type(definition.MaxHealth) == "number" and definition.MaxHealth > 0, "MaxHealth must be positive")
	assert(typeof(definition.Size) == "Vector3", "Buildable parts require Size")
	assert(type(definition.Geometry) == "table" and #definition.Geometry >= 2, "Buildable parts require multi-primitive Geometry")

	local names: {[string]: boolean} = {}
	local nodes = definition.AttachmentNodes or {}
	assert(type(nodes) == "table" and #nodes > 0, "AttachmentNodes must be a non-empty table")
	for _, attachmentNode in ipairs(nodes) do
		assert(type(attachmentNode) == "table", "Attachment node must be a table")
		assert(type(attachmentNode.Name) == "string" and attachmentNode.Name ~= "", "Attachment node requires a valid Name")
		assert(not names[attachmentNode.Name], `Duplicate attachment node: {attachmentNode.Name}`)
		assert(type(attachmentNode.Type) == "string" and attachmentNode.Type ~= "", "Attachment node requires a Type")
		assert(typeof(attachmentNode.Transform) == "CFrame", "Attachment node requires a CFrame Transform")
		assert(type(attachmentNode.Accepts) == "table" and #attachmentNode.Accepts > 0, "Attachment node requires Accepts")
		if attachmentNode.CompatibleWith == nil then
			attachmentNode.CompatibleWith = clone(attachmentNode.Accepts)
		end
		names[attachmentNode.Name] = true
	end

	local stored = clone(definition)
	self._definitions[partType] = table.freeze(stored)
	table.insert(self._ordered, stored)
end

function Registry:Get(partType: string): any?
	local definition = self._definitions[partType]
	return if definition then clone(definition) else nil
end

function Registry:Has(partType: string): boolean
	return self._definitions[partType] ~= nil
end

function Registry:GetAll(): {[string]: any}
	return clone(self._definitions)
end

function Registry:GetList(): {any}
	return clone(self._ordered)
end

function Registry:Count(): number
	return #self._ordered
end

function Registry:Init()
	if next(self._definitions) ~= nil then
		return
	end

	local valid, reason = PartCatalog.Validate()
	assert(valid, "[PartRegistry] Shared PartCatalog invalid: " .. tostring(reason))

	for _, definition in ipairs(PartCatalog.GetList()) do
		self:Register(definition.Id, definition)
	end

	assert(self:Count() == 100, string.format("[PartRegistry] Expected 100 registered parts, got %d", self:Count()))
	print("[MechFramework] PartRegistry loaded", self:Count(), "build pieces")
end

return Registry
