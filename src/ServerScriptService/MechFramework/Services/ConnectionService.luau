--!strict
-- Mutates graph edges atomically. Socket/strength rules can expand without count caps.
local HttpService = game:GetService("HttpService")
local Connections = {}

function Connections:Init(container)
	self._mechs = container:Get("MechService")
end

function Connections:Attach(mechId: string, ownerId: number, aId: string, bId: string, options: {[string]: any}?): (boolean, string)
	if aId == bId then return false, "SelfConnection" end
	local mech = self._mechs:Get(mechId)
	if not mech or mech.Owner ~= ownerId then return false, "NotAuthorized" end
	local a, b = mech.Components[aId], mech.Components[bId]
	if not a or not b or a.Destroyed or b.Destroyed then return false, "InvalidComponent" end
	if mech.Adjacency[aId][bId] then return false, "AlreadyConnected" end
	options = options or {}
	local id = HttpService:GenerateGUID(false)
	mech.Connections[id] = { Id = id, A = aId, B = bId, SocketA = options.SocketA, SocketB = options.SocketB, StructuralStrength = math.max(0, tonumber(options.StructuralStrength) or 100) }
	mech.Adjacency[aId][bId] = id; mech.Adjacency[bId][aId] = id
	a.Connections[id] = true; b.Connections[id] = true
	self._mechs:MarkChanged(mechId)
	return true, id
end

function Connections:Detach(mechId: string, ownerId: number, connectionId: string): boolean
	local mech = self._mechs:Get(mechId)
	if not mech or mech.Owner ~= ownerId then return false end
	local edge = mech.Connections[connectionId]
	if not edge then return false end
	mech.Adjacency[edge.A][edge.B] = nil; mech.Adjacency[edge.B][edge.A] = nil
	mech.Components[edge.A].Connections[connectionId] = nil; mech.Components[edge.B].Connections[connectionId] = nil
	mech.Connections[connectionId] = nil
	self._mechs:MarkChanged(mechId)
	return true
end

function Connections:GetConnectedSet(mechId: string, rootId: string): {[string]: boolean}
	local mech = self._mechs:Get(mechId); if not mech or not mech.Components[rootId] then return {} end
	local seen, queue = {[rootId] = true}, {rootId}; local head = 1
	while queue[head] do
		local current = queue[head]; head += 1
		for neighbor in mech.Adjacency[current] do if not seen[neighbor] then seen[neighbor] = true; table.insert(queue, neighbor) end end
	end
	return seen
end

return Connections
