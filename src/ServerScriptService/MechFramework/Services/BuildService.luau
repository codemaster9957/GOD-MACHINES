--!nonstrict
-- Server-authoritative construction transactions and physical graph realization.

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--------------------------------------------------
-- FRAMEWORK
--------------------------------------------------

local MechFramework = ReplicatedStorage:WaitForChild("MechFramework")
local Shared = MechFramework:WaitForChild("Shared")
local Remotes = MechFramework:WaitForChild("Remotes")

local BuildMath = require(Shared:WaitForChild("BuildMath"))

--------------------------------------------------
-- SERVICE
--------------------------------------------------

local Build = {
	_history = {},
	_future = {},

	_mechs = nil,
	_parts = nil,
	_connections = nil,
	_inventory = nil,
	_physics = nil,
}

--------------------------------------------------
-- DEEP CLONE
--------------------------------------------------

local function clone(value)
	if type(value) ~= "table" then
		return value
	end

	local out = {}

	for key, item in pairs(value) do
		out[key] = clone(item)
	end

	return out
end

local function applyVisual(part, definition)
	local visual = definition.Visual
	if type(visual) ~= "table" then
		part.Material = Enum.Material.Metal
		part.Color = Color3.fromRGB(92, 99, 106)
		return
	end

	local material = Enum.Material[tostring(visual.Material or "Metal")]
	if material then
		part.Material = material
	end

	local shape = Enum.PartType[tostring(visual.Shape or "Block")]
	if shape then
		part.Shape = shape
	end

	if typeof(visual.BaseColor) == "Color3" then
		part.Color = visual.BaseColor
	end
end

local function addWeaponDetails(part, definition)
	local visual = definition.Visual
	if type(visual) ~= "table" or type(definition.Combat) ~= "table" then
		return
	end

	local accent = Instance.new("Part")
	accent.Name = "WeaponAccent"
	accent.Size = Vector3.new(
		math.max(0.18, part.Size.X * 0.72),
		math.max(0.12, part.Size.Y * 0.14),
		math.max(0.25, part.Size.Z * 0.72)
	)
	accent.CFrame = part.CFrame * CFrame.new(0, part.Size.Y * 0.3, 0)
	accent.Material = Enum.Material.Neon
	accent.Color = if typeof(visual.AccentColor) == "Color3" then visual.AccentColor else Color3.fromRGB(255, 181, 54)
	accent.Anchored = part.Anchored
	accent.CanCollide = false
	accent.CanQuery = false
	accent.CanTouch = false
	accent.Massless = true
	accent.Parent = part

	local weld = Instance.new("WeldConstraint")
	weld.Name = "AccentWeld"
	weld.Part0 = part
	weld.Part1 = accent
	weld.Parent = accent

	local muzzle = Instance.new("Attachment")
	muzzle.Name = "Muzzle"
	muzzle.CFrame = CFrame.new(0, 0, -part.Size.Z / 2)
	muzzle:SetAttribute("EffectColor", if typeof(visual.MuzzleColor) == "Color3" then visual.MuzzleColor else accent.Color)
	muzzle.Parent = part
end

--------------------------------------------------
-- HISTORY STACKS
--------------------------------------------------

local function stacks(self, userId)
	if not self._history[userId] then
		self._history[userId] = {}
	end

	if not self._future[userId] then
		self._future[userId] = {}
	end

	return self._history[userId], self._future[userId]
end

--------------------------------------------------
-- NODE MAP
--------------------------------------------------

local function nodeMap(component)
	local out = {}

	if not component then
		return out
	end

	local metadata = component.Metadata

	if not metadata then
		return out
	end

	local nodes = metadata.AttachmentNodes

	if type(nodes) ~= "table" then
		return out
	end

	for _, node in pairs(nodes) do
		if node and type(node.Name) == "string" then
			out[node.Name] = node
		end
	end

	return out
end

--------------------------------------------------
-- INIT
--------------------------------------------------

function Build:Init(container)
	print("[MechFramework] BuildService:Init()")
	self._mechs = container:Get("MechService")
	self._parts = container:Get("PartRegistry")
	self._connections = container:Get("ConnectionService")
	self._inventory = container:Get("InventoryService")
	self._physics = container:Get("PhysicsService")
end

--------------------------------------------------
-- GET / CREATE MECH ASSEMBLY FOLDER
--------------------------------------------------

local function getAssemblyFolder()
	local folder = Workspace:FindFirstChild("MechAssemblies")

	if folder then
		if not folder:IsA("Folder") then
			error(
				"[BuildService] Workspace.MechAssemblies exists but is not a Folder"
			)
		end

		return folder
	end

	folder = Instance.new("Folder")
	folder.Name = "MechAssemblies"
	folder.Parent = Workspace

	return folder
end

--------------------------------------------------
-- GET / CREATE MECH MODEL
--------------------------------------------------

function Build:_model(mechId)
	local root = getAssemblyFolder()

	local existing = root:FindFirstChild(mechId)

	if existing then
		if not existing:IsA("Model") then
			error(
				"[BuildService] Mech assembly '" ..
					tostring(mechId) ..
					"' is not a Model"
			)
		end

		return existing
	end

	local model = Instance.new("Model")
	model.Name = mechId
	model.Parent = root

	return model
end

--------------------------------------------------
-- REALIZE MECH
--------------------------------------------------

function Build:_realize(mechId)
	local mech = self._mechs:Get(mechId)

	if not mech then
		return
	end

	local model = self:_model(mechId)

	model:ClearAllChildren()

	local physical = {}

	--------------------------------------------------
	-- COMPONENTS
	--------------------------------------------------

	for id, component in pairs(mech.Components or {}) do
		local definition = self._parts:Get(component.PartType)

		if not definition then
			warn(
				string.format(
					"[BuildService] Unknown PartType '%s' in mech '%s'",
					tostring(component.PartType),
					tostring(mechId)
				)
			)

			continue
		end

		if typeof(definition.Size) ~= "Vector3" then
			warn(
				"[BuildService] Invalid Size for part:",
				component.PartType
			)

			continue
		end

		if typeof(component.LocalTransform) ~= "CFrame" then
			warn(
				"[BuildService] Invalid LocalTransform for component:",
				id
			)

			continue
		end

		local part = Instance.new("Part")

		part.Name = tostring(id)
		part.Size = definition.Size
		part.CFrame = component.LocalTransform

		part.Anchored = true
		part.CanCollide = true
		applyVisual(part, definition)

		part:SetAttribute(
			"MechId",
			tostring(mechId)
		)

		part:SetAttribute(
			"ComponentId",
			tostring(id)
		)

		part:SetAttribute(
			"PartType",
			tostring(component.PartType)
		)

		part.Parent = model
		addWeaponDetails(part, definition)

		physical[id] = part

		--------------------------------------------------
		-- ATTACHMENT NODES
		--------------------------------------------------

		local metadata = component.Metadata

		if metadata then
			local nodes = metadata.AttachmentNodes

			if type(nodes) == "table" then
				for _, node in pairs(nodes) do
					if not node then
						continue
					end

					if typeof(node.Transform) ~= "CFrame" then
						continue
					end

					local attachment =
						Instance.new("Attachment")

					attachment.Name =
						tostring(
							node.Name or "Node"
						)

					attachment.CFrame =
						node.Transform

					attachment:SetAttribute(
						"NodeType",
						tostring(
							node.Type or ""
						)
					)

					local compatibility = {}

					if type(node.CompatibleWith) == "table" then
						for _, compatibleType in pairs(
							node.CompatibleWith
						) do
							table.insert(
								compatibility,
								tostring(
									compatibleType
								)
							)
						end
					end

					attachment:SetAttribute(
						"Compatibility",
						table.concat(
							compatibility,
							","
						)
					)

					attachment:SetAttribute(
						"Occupied",
						node.OccupiedBy ~= nil
					)

					attachment:SetAttribute(
						"OccupiedBy",
						node.OccupiedBy
							and tostring(
								node.OccupiedBy
							)
							or ""
					)

					attachment.Parent =
						part
				end
			end
		end
	end

	--------------------------------------------------
	-- CONNECTIONS
	--------------------------------------------------

	for _, edge in pairs(mech.Connections or {}) do
		local partA = physical[edge.A]
		local partB = physical[edge.B]

		if partA and partB then
			local weld =
				Instance.new(
					"WeldConstraint"
				)

			weld.Name =
				tostring(
					edge.Id or "Connection"
				)

			weld.Part0 = partA
			weld.Part1 = partB

			weld.Parent = model
		end
	end

	--------------------------------------------------
	-- PHYSICS UPDATE
	--------------------------------------------------

	self._physics:MarkDirty(mechId)
end

--------------------------------------------------
-- CLEARANCE CHECK
--------------------------------------------------

function Build:_clearance(
	definition,
	transform,
	exclude
)

	if not definition then
		return false
	end

	if typeof(definition.Size) ~= "Vector3" then
		return false
	end

	if typeof(transform) ~= "CFrame" then
		return false
	end

	local params = OverlapParams.new()

	params.FilterType =
		Enum.RaycastFilterType.Exclude

	params.FilterDescendantsInstances =
		exclude or {}

	local margin =
		Vector3.new(
			0.08,
			0.08,
			0.08
		)

	local size =
		definition.Size

	local querySize =
		Vector3.new(
			math.max(
				0.01,
				size.X - margin.X
			),

			math.max(
				0.01,
				size.Y - margin.Y
			),

			math.max(
				0.01,
				size.Z - margin.Z
			)
		)

	local results =
		Workspace:GetPartBoundsInBox(
			transform,
			querySize,
			params
		)

	return #results == 0
end

--------------------------------------------------
-- SNAPSHOT
--------------------------------------------------

function Build:_snapshot(
	mechId,
	userId
)

	local mech =
		self._mechs:Get(mechId)

	if not mech then
		return nil
	end

	return clone({
		Components =
			mech.Components,

		Connections =
			mech.Connections,

		Adjacency =
			mech.Adjacency,

		Inventory =
			self._inventory:Snapshot(
				userId
			),
	})
end

--------------------------------------------------
-- RESTORE SNAPSHOT
--------------------------------------------------

function Build:_restore(
	mechId,
	state,
	userId
)

	if not state then
		return
	end

	local mech =
		self._mechs:Get(mechId)

	if not mech then
		return
	end

	mech.Components =
		clone(
			state.Components or {}
		)

	mech.Connections =
		clone(
			state.Connections or {}
		)

	mech.Adjacency =
		clone(
			state.Adjacency or {}
		)

	self._inventory:Restore(
		userId,
		state.Inventory or {}
	)

	self._mechs:MarkChanged(
		mechId
	)

	self:_realize(
		mechId
	)
end

--------------------------------------------------
-- RECORD HISTORY
--------------------------------------------------

function Build:_record(
	userId,
	mechId,
	before
)

	local history, future =
		stacks(
			self,
			userId
		)

	table.insert(
		history,
		{
			MechId = mechId,

			Before = before,

			After =
				self:_snapshot(
					mechId,
					userId
				),
		}
	)

	table.clear(future)
end

--------------------------------------------------
-- PLACE COMPONENT
--------------------------------------------------

function Build:_place(
	player,
	request
)

	local userId =
		player.UserId

	--------------------------------------------------
	-- PART TYPE
	--------------------------------------------------

	if type(request.PartType) ~= "string" then
		return false,
			"BadPartType"
	end

	local definition =
		self._parts:Get(
			request.PartType
		)

	if not definition then
		return false,
			"UnknownPartType"
	end

	--------------------------------------------------
	-- MECH
	--------------------------------------------------

	local mechId =
		request.MechId

	if
		mechId ~= nil
		and type(mechId) ~= "string"
	then
		return false,
			"BadMechId"
	end

	if not mechId then
		mechId =
			self._mechs:Create(
				userId,
				{
					BuildOrigin = true,
				}
			)
	end

	if not mechId then
		return false,
			"MechCreationFailed"
	end

	if
		not self._mechs:IsOwner(
			userId,
			mechId
		)
	then
		return false,
			"NotAuthorized"
	end

	local mech =
		self._mechs:Get(mechId)

	if not mech then
		return false,
			"InvalidMech"
	end

	--------------------------------------------------
	-- PLACEMENT
	--------------------------------------------------

	local transform =
		request.Transform

	local target = nil
	local targetNode = nil
	local sourceNode = nil

	if request.TargetComponentId then

		--------------------------------------------------
		-- VALIDATE NODE NAMES
		--------------------------------------------------

		if type(request.TargetNode) ~= "string" then
			return false,
				"BadTargetNode"
		end

		if type(request.SourceNode) ~= "string" then
			return false,
				"BadSourceNode"
		end

		--------------------------------------------------
		-- TARGET COMPONENT
		--------------------------------------------------

		target =
			mech.Components[
				request.TargetComponentId
			]

		if not target then
			return false,
				"InvalidTarget"
		end

		targetNode =
			nodeMap(target)[
				request.TargetNode
			]

		local sourceNodes =
			BuildMath.Nodes(
				definition
			)

		sourceNode =
			sourceNodes[
				request.SourceNode
			]

		if
			not targetNode
			or not sourceNode
		then
			return false,
				"InvalidNode"
		end

		if targetNode.OccupiedBy then
			return false,
				"NodeOccupied"
		end

		if
			not BuildMath.Compatible(
				targetNode,
				sourceNode
			)
		then
			return false,
				"IncompatibleNode"
		end

		transform =
			BuildMath.Snap(
				target.LocalTransform,
				targetNode.Transform,
				sourceNode.Transform,
				tonumber(
					request.Rotation
				) or 0
			)

	elseif next(mech.Components or {}) ~= nil then

		return false,
			"AttachmentRequired"

	end

	--------------------------------------------------
	-- VALIDATE TRANSFORM
	--------------------------------------------------

	if typeof(transform) ~= "CFrame" then
		return false,
			"InvalidTransform"
	end

	--------------------------------------------------
	-- COLLISION
	--------------------------------------------------

	if
		not self:_clearance(
			definition,
			transform
		)
	then
		return false,
			"Collision"
	end

	--------------------------------------------------
	-- SNAPSHOT BEFORE CHANGE
	--------------------------------------------------

	local before =
		self:_snapshot(
			mechId,
			userId
		)

	--------------------------------------------------
	-- INVENTORY
	--------------------------------------------------

	if
		not self._inventory:Consume(
			userId,
			request.PartType,
			1
		)
	then
		return false,
			"InsufficientInventory"
	end

	--------------------------------------------------
	-- COPY NODES
	--------------------------------------------------

	local nodes =
		clone(
			definition.AttachmentNodes
				or {}
		)

	for _, node in pairs(nodes) do
		node.OccupiedBy = nil
	end

	--------------------------------------------------
	-- ADD COMPONENT
	--------------------------------------------------

	local added, componentId =
		self._mechs:AddComponent(
			mechId,
			userId,
			request.PartType,
			transform,
			{
				AttachmentNodes =
					nodes,
			}
		)

	if not added then

		self._inventory:Grant(
			userId,
			request.PartType,
			1
		)

		return false,
			componentId
	end

	--------------------------------------------------
	-- CONNECT TO TARGET
	--------------------------------------------------

	if target then
		local component =
			mech.Components[
				componentId
			]

		if not component then

			self._inventory:Grant(
				userId,
				request.PartType,
				1
			)

			return false,
				"ComponentCreationFailed"
		end

		local actualTargetNode =
			nodeMap(target)[
				request.TargetNode
			]

		local actualSourceNode =
			nodeMap(component)[
				request.SourceNode
			]

		if
			not actualTargetNode
			or not actualSourceNode
		then

			mech.Components[
				componentId
			] = nil

			if mech.Adjacency then
				mech.Adjacency[
					componentId
				] = nil
			end

			self._inventory:Grant(
				userId,
				request.PartType,
				1
			)

			self._mechs:MarkChanged(
				mechId
			)

			return false,
				"InvalidNodeState"
		end

		actualTargetNode.OccupiedBy =
			componentId

		actualSourceNode.OccupiedBy =
			target.Id

		--------------------------------------------------
		-- STRUCTURAL STRENGTH
		--------------------------------------------------

		local structuralStrength = 1

		if
			target.PhysicalProperties
			and target.PhysicalProperties.StructuralStrength
		then
			structuralStrength =
				target.PhysicalProperties.StructuralStrength
		end

		--------------------------------------------------
		-- CONNECTION
		--------------------------------------------------

		local attached, edge =
			self._connections:Attach(
				mechId,
				userId,
				target.Id,
				componentId,
				{
					SocketA =
						request.TargetNode,

					SocketB =
						request.SourceNode,

					StructuralStrength =
						structuralStrength,
				}
			)

		if not attached then

			actualTargetNode.OccupiedBy =
				nil

			actualSourceNode.OccupiedBy =
				nil

			mech.Components[
				componentId
			] = nil

			if mech.Adjacency then
				mech.Adjacency[
					componentId
				] = nil
			end

			self._inventory:Grant(
				userId,
				request.PartType,
				1
			)

			self._mechs:MarkChanged(
				mechId
			)

			return false,
				edge
		end
	end

	--------------------------------------------------
	-- HISTORY / REALIZE
	--------------------------------------------------

	self:_record(
		userId,
		mechId,
		before
	)

	self:_realize(
		mechId
	)

	return true, {
		MechId =
			mechId,

		ComponentId =
			componentId,

		Revision =
			mech.Revision,
	}
end

--------------------------------------------------
-- REMOVE COMPONENT
--------------------------------------------------

function Build:_remove(
	player,
	request
)

	if type(request.MechId) ~= "string" then
		return false,
			"BadMechId"
	end

	if type(request.ComponentId) ~= "string" then
		return false,
			"BadComponentId"
	end

	local mech =
		self._mechs:Get(
			request.MechId
		)

	if
		not mech
		or mech.Owner ~= player.UserId
	then
		return false,
			"NotAuthorized"
	end

	local component =
		mech.Components[
			request.ComponentId
		]

	if not component then
		return false,
			"InvalidComponent"
	end

	local before =
		self:_snapshot(
			request.MechId,
			player.UserId
		)

	--------------------------------------------------
	-- COPY EDGE IDS
	--------------------------------------------------

	local edgeIds = {}

	for edgeId in pairs(
		component.Connections or {}
	) do
		table.insert(
			edgeIds,
			edgeId
		)
	end

	--------------------------------------------------
	-- DETACH
	--------------------------------------------------

	for _, edgeId in ipairs(edgeIds) do
		local edge =
			mech.Connections[
				edgeId
			]

		if edge then
			local otherId

			if edge.A == component.Id then
				otherId = edge.B
			else
				otherId = edge.A
			end

			local other =
				mech.Components[
					otherId
				]

			if other then
				for _, node in pairs(
					other.Metadata
					and other.Metadata.AttachmentNodes
					or {}
				) do
					if
						node.OccupiedBy
						== component.Id
					then
						node.OccupiedBy =
							nil
					end
				end
			end
		end

		self._connections:Detach(
			request.MechId,
			player.UserId,
			edgeId
		)
	end

	--------------------------------------------------
	-- REMOVE
	--------------------------------------------------

	mech.Components[
		component.Id
	] = nil

	if mech.Adjacency then
		mech.Adjacency[
			component.Id
		] = nil
	end

	self._mechs:MarkChanged(
		request.MechId
	)

	--------------------------------------------------
	-- RETURN PART
	--------------------------------------------------

	self._inventory:Grant(
		player.UserId,
		component.PartType,
		1
	)

	--------------------------------------------------
	-- HISTORY
	--------------------------------------------------

	self:_record(
		player.UserId,
		request.MechId,
		before
	)

	self:_realize(
		request.MechId
	)

	return true, {
		Revision =
			mech.Revision,
	}
end

--------------------------------------------------
-- MOVE COMPONENT
--------------------------------------------------

function Build:_move(
	player,
	request
)

	if type(request.MechId) ~= "string" then
		return false,
			"BadMechId"
	end

	if type(request.ComponentId) ~= "string" then
		return false,
			"BadComponentId"
	end

	if typeof(request.Transform) ~= "CFrame" then
		return false,
			"InvalidMove"
	end

	local mech =
		self._mechs:Get(
			request.MechId
		)

	if
		not mech
		or mech.Owner ~= player.UserId
	then
		return false,
			"NotAuthorized"
	end

	local component =
		mech.Components[
			request.ComponentId
		]

	if not component then
		return false,
			"InvalidComponent"
	end

	--------------------------------------------------
	-- MUST BE DETACHED BEFORE MOVING
	--------------------------------------------------

	if
		next(
			component.Connections
				or {}
		) ~= nil
	then
		return false,
			"DetachBeforeMove"
	end

	local definition =
		self._parts:Get(
			component.PartType
		)

	if not definition then
		return false,
			"UnknownPartType"
	end

	local model =
		self:_model(
			request.MechId
		)

	local existing =
		model:FindFirstChild(
			component.Id
		)

	local exclusions = {}

	if existing then
		table.insert(
			exclusions,
			existing
		)
	end

	--------------------------------------------------
	-- COLLISION
	--------------------------------------------------

	if
		not self:_clearance(
			definition,
			request.Transform,
			exclusions
		)
	then
		return false,
			"Collision"
	end

	--------------------------------------------------
	-- SNAPSHOT
	--------------------------------------------------

	local before =
		self:_snapshot(
			request.MechId,
			player.UserId
		)

	--------------------------------------------------
	-- MOVE
	--------------------------------------------------

	component.LocalTransform =
		request.Transform

	self._mechs:MarkChanged(
		request.MechId
	)

	self:_record(
		player.UserId,
		request.MechId,
		before
	)

	self:_realize(
		request.MechId
	)

	return true, {
		Revision =
			mech.Revision,
	}
end

--------------------------------------------------
-- UNDO / REDO
--------------------------------------------------

function Build:_undoRedo(
	player,
	redo
)

	local history, future =
		stacks(
			self,
			player.UserId
		)

	local source
	local destination

	if redo then
		source = future
		destination = history
	else
		source = history
		destination = future
	end

	local entry =
		table.remove(source)

	if not entry then
		return false,
			"NothingToApply"
	end

	if
		not self._mechs:IsOwner(
			player.UserId,
			entry.MechId
		)
	then
		return false,
			"NothingToApply"
	end

	local state

	if redo then
		state =
			entry.After
	else
		state =
			entry.Before
	end

	self:_restore(
		entry.MechId,
		state,
		player.UserId
	)

	table.insert(
		destination,
		entry
	)

	return true, {
		MechId =
			entry.MechId,
	}
end

--------------------------------------------------
-- START
--------------------------------------------------
function Build:Start()
	print("[MechFramework] BuildService:Start()")
	local functionsFolder = Remotes:WaitForChild("Functions")
	local remote = functionsFolder:WaitForChild("RequestBuildAction")

	if not remote:IsA("RemoteFunction") then
		error("[BuildService] RequestBuildAction must be a RemoteFunction")
	end

	remote.OnServerInvoke = function(player, request)
		local action = type(request) == "table" and request.Action or nil
		print("[MechFramework] RequestBuildAction OnServerInvoke", player.UserId, action or "BadRequest")

		if type(request) ~= "table" or type(action) ~= "string" then
			return false, "BadRequest"
		end

		if action == "Definition" then
			print("[MechFramework] BuildService Definition request", player.UserId, request.PartType)
			if type(request.PartType) ~= "string" then
				return false, "BadPartType"
			end
			local definition = self._parts:Get(request.PartType)
			return definition ~= nil, definition
		elseif action == "Place" then
			print("[MechFramework] BuildService Place request", player.UserId, request.PartType)
			return self:_place(player, request)
		elseif action == "Remove" then
			return self:_remove(player, request)
		elseif action == "Move" then
			return self:_move(player, request)
		elseif action == "Undo" then
			return self:_undoRedo(player, false)
		elseif action == "Redo" then
			return self:_undoRedo(player, true)
		elseif action == "Rebuild" then
			if type(request.MechId) ~= "string" then
				return false, "BadMechId"
			end
			if not self._mechs:IsOwner(player.UserId, request.MechId) then
				return false, "NotAuthorized"
			end
			self:_realize(request.MechId)
			return true, {}
		end

		return false, "UnknownAction"
	end

	print("[MechFramework] BuildService owns RequestBuildAction")
end

--------------------------------------------------
-- SAVED BLUEPRINT BATTLE DEPLOYMENT
--------------------------------------------------


local function blueprintTransform(value)
	if typeof(value) == "CFrame" then return value end
	if type(value) == "table" then
		local components = value.Components or value
		if type(components) == "table" and #components == 12 then
			return CFrame.new(table.unpack(components))
		end
		if tonumber(value.X) and tonumber(value.Y) and tonumber(value.Z) then
			return CFrame.new(tonumber(value.X), tonumber(value.Y), tonumber(value.Z))
		end
	end
	return CFrame.identity
end

function Build:SpawnBlueprint(ownerId, blueprint, spawnCFrame, metadata)
	if type(ownerId) ~= "number" or type(blueprint) ~= "table" or type(blueprint.Components) ~= "table" or typeof(spawnCFrame) ~= "CFrame" then
		return false, "InvalidBlueprint"
	end
	local mechId = self._mechs:Create(ownerId, clone(metadata or {}))
	local mech = self._mechs:Get(mechId)
	if not mech then return false, "MechCreationFailed" end
	mech.Metadata.BlueprintId = blueprint.Id or blueprint.Name
	mech.Metadata.SpawnedFromBlueprint = true
	local idMap = {}
	for sourceId, source in pairs(blueprint.Components) do
		if type(source) ~= "table" or type(source.PartType) ~= "string" or not self._parts:Get(source.PartType) then
			return false, "InvalidBlueprintComponent"
		end
		local localTransform = blueprintTransform(source.LocalTransform or source.Transform)
		local componentMetadata = clone(source.Metadata or {})
		local added, componentId = self._mechs:AddComponent(mechId, ownerId, source.PartType, spawnCFrame * localTransform, componentMetadata)
		if not added then return false, componentId end
		idMap[tostring(source.Id or sourceId)] = componentId
		local component = self._mechs:GetComponent(mechId, componentId)
		if component then
			component.Health = math.clamp(tonumber(source.Health) or component.MaxHealth, 1, component.MaxHealth)
			component.DamageState = "Operational"
		end
	end
	for _, edge in pairs(blueprint.Connections or {}) do
		local a = idMap[tostring(edge.A)]
		local b = idMap[tostring(edge.B)]
		if a and b then
			local attached = self._connections:Attach(mechId, ownerId, a, b, {
				SocketA = edge.SocketA,
				SocketB = edge.SocketB,
				StructuralStrength = edge.StructuralStrength,
			})
			if not attached then return false, "InvalidBlueprintConnection" end
		end
	end
	self:_realize(mechId)
	local model = self:_model(mechId)
	model:SetAttribute("BattleSpawn", true)
	model:SetAttribute("BlueprintId", tostring(blueprint.Id or blueprint.Name or "SavedBlueprint"))
	if metadata then
		for key, value in pairs(metadata) do
			if type(key) == "string" and (type(value) == "string" or type(value) == "number" or type(value) == "boolean") then model:SetAttribute(key, value) end
		end
	end
	return true, mechId
end

return Build