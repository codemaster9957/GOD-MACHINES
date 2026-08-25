--!strict
-- Maintains cached physical assembly data without scanning every mech every frame.
local Workspace = game:GetService("Workspace")

local PhysicsService = {
	_dirty = {} :: {[string]: boolean},
	_state = {} :: {[string]: any},
	_updateInterval = 0.25,
}

function PhysicsService:Init(container: any)
	self._mechs = container:Get("MechService")
end

function PhysicsService:MarkDirty(mechId: string)
	if type(mechId) == "string" and mechId ~= "" then
		self._dirty[mechId] = true
	end
end

function PhysicsService:Recalculate(mechId: string): any?
	local mech = self._mechs:Get(mechId)
	if not mech then
		self._dirty[mechId] = nil
		self._state[mechId] = nil
		return nil
	end

	local totalMass = 0
	local componentCount = 0
	for _, component in mech.Components do
		if not component.Destroyed then
			totalMass += math.max(0, tonumber(component.Mass) or 0)
			componentCount += 1
		end
	end

	local assemblyRoot = Workspace:FindFirstChild("MechAssemblies")
	local model = if assemblyRoot then assemblyRoot:FindFirstChild(mechId) else nil
	local physicalMass = 0
	local partCount = 0
	if model then
		for _, descendant in model:GetDescendants() do
			if descendant:IsA("BasePart") then
				physicalMass += descendant:GetMass()
				partCount += 1
			end
		end
	end

	local state: any = {
		MechId = mechId,
		Revision = mech.Revision,
		ConfiguredMass = totalMass,
		PhysicalMass = physicalMass,
		ComponentCount = componentCount,
		PartCount = partCount,
		UpdatedAt = os.clock(),
	}

	self._state[mechId] = state
	self._dirty[mechId] = nil

	return state
	end

function PhysicsService:GetState(mechId: string): any?
	local mech = self._mechs:Get(mechId)
	local state = self._state[mechId]
	if self._dirty[mechId] or (mech and (not state or state.Revision ~= mech.Revision)) then
		return self:Recalculate(mechId)
	end
	return state
end

function PhysicsService:GetDebugInfo(mechId: string): any?
	return self:GetState(mechId)
end

function PhysicsService:Start()
	task.spawn(function()
		while true do
			task.wait(self._updateInterval)
			local pending = {}
			for mechId in self._dirty do
				table.insert(pending, mechId)
			end
			for _, mechId in pending do
				self:Recalculate(mechId)
			end
		end
	end)
end

return PhysicsService
