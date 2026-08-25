--!strict
-- Canonical graph contracts shared for type checking and snapshot consumers.
export type ComponentId = string
export type MechId = string
export type ConnectionId = string

export type Component = {
	Id: ComponentId,
	PartType: string,
	Mass: number,
	Health: number,
	MaxHealth: number,
	Owner: number,
	Connections: {[ConnectionId]: boolean},
	LocalTransform: CFrame,
	PhysicalProperties: {[string]: any},
	Power: {[string]: any}?,
	Heat: {[string]: any}?,
	Combat: {[string]: any}?,
	Destroyed: boolean,
	Metadata: {[string]: any},
}

export type Connection = {
	Id: ConnectionId,
	A: ComponentId,
	B: ComponentId,
	SocketA: string?,
	SocketB: string?,
	StructuralStrength: number,
}

export type MechGraph = {
	Id: MechId,
	Owner: number,
	Components: {[ComponentId]: Component},
	Connections: {[ConnectionId]: Connection},
	Adjacency: {[ComponentId]: {[ComponentId]: ConnectionId}},
	Revision: number,
	CreatedAt: number,
	LastActiveAt: number,
	SimulationTier: string,
	Metadata: {[string]: any},
}

return table.freeze({ SchemaVersion = 1 })
