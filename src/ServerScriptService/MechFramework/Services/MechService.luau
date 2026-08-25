--!strict
-- Owns canonical mech graphs. Models are views of this data, never the source of truth.

local HttpService = game:GetService("HttpService")

local MechService: any = {
	_mechs = {},
	_ownerIndex = {},
}

local function guid(): string
	return HttpService:GenerateGUID(false)
end

local function copy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local out: {[any]: any} = {}
	for key, item in value do
		out[key] = copy(item)
	end
	return out
end

function MechService:Init(container: any)
	self._parts = container:Get("PartRegistry")
end

function MechService:_removeIndex(ownerId: number, mechId: string)
	local owned = self._ownerIndex[ownerId]
	if not owned then
		return
	end
	owned[mechId] = nil
	if next(owned) == nil then
		self._ownerIndex[ownerId] = nil
	end
end

function MechService:Destroy(mechId: string): boolean
	local mech = self._mechs[mechId]
	if not mech then
		return false
	end
	self._mechs[mechId] = nil
	self:_removeIndex(mech.Owner, mechId)
	return true
end

function MechService:_pruneEmptyBuildOrigins(ownerId: number)
	local owned = self._ownerIndex[ownerId]
	if not owned then
		return
	end
	local remove = {}
	for mechId in owned do
		local mech = self._mechs[mechId]
		if mech and next(mech.Components) == nil and mech.Metadata and mech.Metadata.BuildOrigin == true then
			table.insert(remove, mechId)
		end
	end
	for _, mechId in remove do
		self:Destroy(mechId)
	end
end

function MechService:Create(ownerId: number, metadata: {[string]: any}?): string
	local meta = copy(metadata or {})
	if meta.BuildOrigin == true then
		-- Failed first placements previously leaked one empty mech every click.
		self:_pruneEmptyBuildOrigins(ownerId)
	end

	local id = guid()
	self._mechs[id] = {
		Id = id,
		Owner = ownerId,
		Components = {},
		Connections = {},
		Adjacency = {},
		Revision = 0,
		CreatedAt = os.time(),
		LastActiveAt = os.clock(),
		SimulationTier = "Active",
		Metadata = meta,
	}
	self._ownerIndex[ownerId] = self._ownerIndex[ownerId] or {}
	self._ownerIndex[ownerId][id] = true
	return id
end

function MechService:Get(mechId: string): any?
	return self._mechs[mechId]
end

function MechService:IsOwner(userId: number, mechId: string): boolean
	local mech = self._mechs[mechId]
	return mech ~= nil and mech.Owner == userId
end

function MechService:AddComponent(mechId: string, ownerId: number, partType: string, localTransform: CFrame, metadata: {[string]: any}?): (boolean, string)
	local mech = self._mechs[mechId]
	if not mech or mech.Owner ~= ownerId then
		return false, "NotAuthorized"
	end
	if typeof(localTransform) ~= "CFrame" then
		return false, "InvalidTransform"
	end

	local definition = self._parts:Get(partType)
	if not definition then
		return false, "UnknownPartType"
	end

	local id = guid()
	mech.Components[id] = {
		Id = id,
		PartType = partType,
		Mass = definition.Mass,
		Health = definition.MaxHealth,
		MaxHealth = definition.MaxHealth,
		Owner = ownerId,
		Connections = {},
		LocalTransform = localTransform,
		PhysicalProperties = copy(definition.PhysicalProperties or {}),
		Power = copy(definition.Power),
		Heat = copy(definition.Heat),
		Combat = copy(definition.Combat),
		Destroyed = false,
		DamageState = "Operational",
		Metadata = copy(metadata or {}),
	}
	mech.Adjacency[id] = {}
	mech.Revision += 1
	mech.LastActiveAt = os.clock()
	return true, id
end

function MechService:GetComponent(mechId: string, componentId: string): any?
	local mech = self._mechs[mechId]
	return mech and mech.Components[componentId] or nil
end

function MechService:MarkChanged(mechId: string)
	local mech = self._mechs[mechId]
	if mech then
		mech.Revision += 1
		mech.LastActiveAt = os.clock()
	end
end

function MechService:Snapshot(mechId: string, requesterId: number): any?
	local mech = self._mechs[mechId]
	if not mech or mech.Owner ~= requesterId then
		return nil
	end
	return copy(mech)
end

function MechService:DebugStats(): {[string]: number}
	local mechs, components, connections = 0, 0, 0
	for _, mech in self._mechs do
		mechs += 1
		for _ in mech.Components do
			components += 1
		end
		for _ in mech.Connections do
			connections += 1
		end
	end
	return {
		Mechs = mechs,
		Components = components,
		Connections = connections,
	}
end

return MechService
