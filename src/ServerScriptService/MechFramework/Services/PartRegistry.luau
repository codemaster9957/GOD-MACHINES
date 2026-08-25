--!strict
-- Immutable GOD MACHINES build-part registry.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local WeaponCatalog = require(ReplicatedStorage.MechFramework.Shared.WeaponCatalog)

local Registry: any = {
	_definitions = {} :: {[string]: any},
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

local function compatibleTypes(): {string}
	return { "Structural", "Utility", "Weapon" }
end

local function node(name: string, nodeType: string, transform: CFrame): any
	return {
		Name = name,
		Type = nodeType,
		Transform = transform,
		Accepts = compatibleTypes(),
		CompatibleWith = compatibleTypes(),
	}
end

local function boxNodes(size: Vector3, nodeType: string?): {any}
	local kind = nodeType or "Structural"
	return {
		node("Top", kind, CFrame.new(0, size.Y / 2, 0) * CFrame.Angles(math.pi / 2, 0, 0)),
		node("Bottom", kind, CFrame.new(0, -size.Y / 2, 0) * CFrame.Angles(-math.pi / 2, 0, 0)),
		node("Left", kind, CFrame.new(-size.X / 2, 0, 0) * CFrame.Angles(0, -math.pi / 2, 0)),
		node("Right", kind, CFrame.new(size.X / 2, 0, 0) * CFrame.Angles(0, math.pi / 2, 0)),
		node("Front", kind, CFrame.new(0, 0, -size.Z / 2)),
		node("Back", kind, CFrame.new(0, 0, size.Z / 2) * CFrame.Angles(0, math.pi, 0)),
	}
end

function Registry:Register(partType: string, definition: any)
	assert(type(partType) == "string" and partType ~= "", "Invalid PartType")
	assert(self._definitions[partType] == nil, `PartType already registered: {partType}`)
	assert(type(definition) == "table", "Part definition must be a table")
	assert(type(definition.Mass) == "number" and definition.Mass >= 0, "Mass must be nonnegative")
	assert(type(definition.MaxHealth) == "number" and definition.MaxHealth > 0, "MaxHealth must be positive")
	assert(typeof(definition.Size) == "Vector3", "Buildable parts require Size")

	local names: {[string]: boolean} = {}
	local nodes = definition.AttachmentNodes or {}
	assert(type(nodes) == "table", "AttachmentNodes must be a table")
	for _, attachmentNode in ipairs(nodes) do
		assert(type(attachmentNode) == "table", "Attachment node must be a table")
		assert(type(attachmentNode.Name) == "string" and attachmentNode.Name ~= "", "Attachment node requires a valid Name")
		assert(not names[attachmentNode.Name], `Duplicate attachment node: {attachmentNode.Name}`)
		assert(type(attachmentNode.Type) == "string" and attachmentNode.Type ~= "", "Attachment node requires a Type")
		assert(typeof(attachmentNode.Transform) == "CFrame", "Attachment node requires a CFrame Transform")
		assert(type(attachmentNode.Accepts) == "table", "Attachment node requires an Accepts table")
		if attachmentNode.CompatibleWith == nil then
			attachmentNode.CompatibleWith = clone(attachmentNode.Accepts)
		end
		names[attachmentNode.Name] = true
	end

	self._definitions[partType] = table.freeze(clone(definition))
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

function Registry:Init()
	if next(self._definitions) ~= nil then
		return
	end

	local frameSize = Vector3.new(4, 2, 4)
	self:Register("StructuralFrame", {
		Size = frameSize,
		Mass = 20,
		MaxHealth = 250,
		AttachmentNodes = boxNodes(frameSize, "Structural"),
		PhysicalProperties = {
			Density = 1,
			StructuralStrength = 400,
		},
		Visual = {
			Shape = "Block",
			Material = "Metal",
			BaseColor = Color3.fromRGB(92, 99, 106),
			AccentColor = Color3.fromRGB(255, 181, 54),
		},
	})

	local reactorSize = Vector3.new(3, 3, 3)
	self:Register("SmallReactor", {
		Size = reactorSize,
		Mass = 80,
		MaxHealth = 180,
		AttachmentNodes = boxNodes(reactorSize, "Utility"),
		PhysicalProperties = {
			Density = 2,
			StructuralStrength = 250,
		},
		Power = {
			Generation = 100,
			Demand = 0,
		},
		Heat = {
			Generation = 8,
			Capacity = 200,
		},
		Visual = {
			Shape = "Ball",
			Material = "Neon",
			BaseColor = Color3.fromRGB(43, 214, 255),
			AccentColor = Color3.fromRGB(232, 240, 245),
		},
	})

	for _, weaponDefinition in ipairs(WeaponCatalog.Ordered) do
		local size = weaponDefinition.Size
		self:Register(weaponDefinition.Id, {
			Size = size,
			Mass = weaponDefinition.Mass,
			MaxHealth = weaponDefinition.MaxHealth,
			AttachmentNodes = boxNodes(size, "Weapon"),
			PhysicalProperties = {
				Density = math.clamp(weaponDefinition.Mass / math.max(1, size.X * size.Y * size.Z), 0.5, 5),
				StructuralStrength = math.max(100, weaponDefinition.MaxHealth),
			},
			Power = clone(weaponDefinition.Power),
			Heat = clone(weaponDefinition.Heat),
			Combat = clone(weaponDefinition.Combat),
			Visual = clone(weaponDefinition.Visual),
			MountRole = weaponDefinition.MountRole,
		})
	end
end

return Registry
