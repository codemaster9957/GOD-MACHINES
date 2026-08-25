--!strict
-- Immutable GOD MACHINES part definitions.
-- Register new buildable parts here or from future content packs.

--------------------------------------------------
-- TYPES
--------------------------------------------------

type Definition = any

type DefinitionMap = {
	[string]: any,
}

--------------------------------------------------
-- REGISTRY
--------------------------------------------------

local Registry: any = {
	_definitions = {} :: DefinitionMap,
}

--------------------------------------------------
-- DEEP CLONE
--------------------------------------------------

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

--------------------------------------------------
-- REGISTER PART
--------------------------------------------------

function Registry:Register(
	partType: string,
	definition: Definition
)
	--------------------------------------------------
	-- BASIC VALIDATION
	--------------------------------------------------

	assert(
		type(partType) == "string"
			and partType ~= "",
		"Invalid PartType"
	)

	assert(
		self._definitions[partType] == nil,
		`PartType already registered: {partType}`
	)

	assert(
		type(definition) == "table",
		"Part definition must be a table"
	)

	assert(
		type(definition.Mass) == "number"
			and definition.Mass >= 0,
		"Mass must be nonnegative"
	)

	assert(
		type(definition.MaxHealth) == "number"
			and definition.MaxHealth > 0,
		"MaxHealth must be positive"
	)

	assert(
		typeof(definition.Size) == "Vector3",
		"Buildable parts require Size"
	)

	--------------------------------------------------
	-- ATTACHMENT NODE VALIDATION
	--------------------------------------------------

	local names: {[string]: boolean} = {}

	local nodes: any =
		definition.AttachmentNodes or {}

	assert(
		type(nodes) == "table",
		"AttachmentNodes must be a table"
	)

	for _, node: any in ipairs(nodes) do
		assert(
			type(node) == "table",
			"Attachment node must be a table"
		)

		assert(
			type(node.Name) == "string"
				and node.Name ~= "",
			"Attachment node requires a valid Name"
		)

		assert(
			names[node.Name] ~= true,
			`Duplicate attachment node: {node.Name}`
		)

		assert(
			type(node.Type) == "string"
				and node.Type ~= "",
			"Attachment node requires a Type"
		)

		assert(
			typeof(node.Transform) == "CFrame",
			"Attachment node requires a CFrame Transform"
		)

		assert(
			type(node.Accepts) == "table",
			"Attachment node requires an Accepts table"
		)

		--------------------------------------------------
		-- COMPATIBILITY ALIAS
		--------------------------------------------------

		-- Some framework systems use Accepts.
		-- Others currently use CompatibleWith.
		-- Supply both so they always agree.

		if node.CompatibleWith == nil then
			node.CompatibleWith =
				clone(node.Accepts)
		end

		names[node.Name] = true
	end

	--------------------------------------------------
	-- STORE DEFINITION
	--------------------------------------------------

	self._definitions[partType] =
		table.freeze(
			clone(definition)
		)
end

--------------------------------------------------
-- GET PART
--------------------------------------------------

function Registry:Get(
	partType: string
): Definition?

	local definition =
		self._definitions[partType]

	if definition == nil then
		return nil
	end

	-- Return a copy so consumers cannot alter
	-- the stored registry definition.

	return clone(definition)
end

--------------------------------------------------
-- CHECK PART
--------------------------------------------------

function Registry:Has(
	partType: string
): boolean

	return self._definitions[partType] ~= nil
end

--------------------------------------------------
-- INITIALIZE DEFAULT CONTENT
--------------------------------------------------

function Registry:Init()

	--------------------------------------------------
	-- BOX NODE GENERATOR
	--------------------------------------------------

	local function boxNodes(
		size: Vector3
	): {any}

		local function compatibility(): {string}
			return {
				"Structural",
				"Utility",
				"Weapon",
			}
		end

		return {

			--------------------------------------------------
			-- TOP
			--------------------------------------------------

			{
				Name = "Top",
				Type = "Structural",

				Transform =
					CFrame.new(
						0,
						size.Y / 2,
						0
					)
					* CFrame.Angles(
						math.pi / 2,
						0,
						0
					),

				Accepts = compatibility(),
				CompatibleWith = compatibility(),
			},

			--------------------------------------------------
			-- BOTTOM
			--------------------------------------------------

			{
				Name = "Bottom",
				Type = "Structural",

				Transform =
					CFrame.new(
						0,
						-size.Y / 2,
						0
					)
					* CFrame.Angles(
						-math.pi / 2,
						0,
						0
					),

				Accepts = compatibility(),
				CompatibleWith = compatibility(),
			},

			--------------------------------------------------
			-- LEFT
			--------------------------------------------------

			{
				Name = "Left",
				Type = "Structural",

				Transform =
					CFrame.new(
						-size.X / 2,
						0,
						0
					)
					* CFrame.Angles(
						0,
						-math.pi / 2,
						0
					),

				Accepts = compatibility(),
				CompatibleWith = compatibility(),
			},

			--------------------------------------------------
			-- RIGHT
			--------------------------------------------------

			{
				Name = "Right",
				Type = "Structural",

				Transform =
					CFrame.new(
						size.X / 2,
						0,
						0
					)
					* CFrame.Angles(
						0,
						math.pi / 2,
						0
					),

				Accepts = compatibility(),
				CompatibleWith = compatibility(),
			},

			--------------------------------------------------
			-- FRONT
			--------------------------------------------------

			{
				Name = "Front",
				Type = "Structural",

				Transform =
					CFrame.new(
						0,
						0,
						-size.Z / 2
					),

				Accepts = compatibility(),
				CompatibleWith = compatibility(),
			},

			--------------------------------------------------
			-- BACK
			--------------------------------------------------

			{
				Name = "Back",
				Type = "Structural",

				Transform =
					CFrame.new(
						0,
						0,
						size.Z / 2
					)
					* CFrame.Angles(
						0,
						math.pi,
						0
					),

				Accepts = compatibility(),
				CompatibleWith = compatibility(),
			},
		}
	end

	--------------------------------------------------
	-- STRUCTURAL FRAME
	--------------------------------------------------

	local frameSize =
		Vector3.new(
			4,
			2,
			4
		)

	self:Register(
		"StructuralFrame",
		{
			Size = frameSize,

			Mass = 20,

			MaxHealth = 250,

			AttachmentNodes =
				boxNodes(frameSize),

			PhysicalProperties = {
				Density = 1,

				StructuralStrength =
					400,
			},
		}
	)

	--------------------------------------------------
	-- SMALL REACTOR
	--------------------------------------------------

	local reactorSize =
		Vector3.new(
			3,
			3,
			3
		)

	local smallReactorDefinition: any = {
		Size = reactorSize,
		Mass = 80,
		MaxHealth = 180,

		AttachmentNodes = boxNodes(reactorSize),

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
	}

	self:Register(
		"SmallReactor",
		smallReactorDefinition
	)
	--------------------------------------------------
	-- AUTOCANNON
	--------------------------------------------------

	local gunSize =
		Vector3.new(
			2,
			2,
			5
		)

	local gunNodes =
		boxNodes(gunSize)

	--------------------------------------------------
	-- AUTOCANNON NODES
	--------------------------------------------------

	for _, node: any in ipairs(gunNodes) do
		node.Type = "Weapon"
	end

	self:Register(
		"Autocannon",
		{
			Size = gunSize,

			Mass = 55,

			MaxHealth = 120,

			AttachmentNodes =
				gunNodes,

			PhysicalProperties = {
				Density = 1.5,

				StructuralStrength =
					150,
			},

			Power = {
				Generation = 0,
				Demand = 15,
			},

			Heat = {
				Generation = 12,
				Capacity = 80,
			},

			Combat = {
				Damage = 20,

				Cooldown = 0.2,

				Range = 1200,
			},
		}
	)
end

--------------------------------------------------
-- RETURN
--------------------------------------------------

return Registry