--!strict
-- Maintains cached physical assembly data and keeps Roblox part mass aligned with canonical component mass.

local Workspace = game:GetService("Workspace")

local PhysicsService: any = {
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

local function applyConfiguredMass(part: BasePart, configuredMass: number)
	local volume = math.max(0.001, part.Size.X * part.Size.Y * part.Size.Z)
	local density = math.clamp(configuredMass / volume, 0.01, 100)
	local current = part.CurrentPhysicalProperties
	part.Massless = false
	part.CustomPhysicalProperties = PhysicalProperties.new(
		density,
		current.Friction,
		current.Elasticity,
		current.FrictionWeight,
		current.ElasticityWeight
	)
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

	if model and model:IsA("Model") then
		local primary: BasePart? = model.PrimaryPart
		for _, descendant in model:GetDescendants() do
			if descendant:IsA("BasePart") then
				local componentId = descendant:GetAttribute("ComponentId")
				local component = if type(componentId) == "string" then mech.Components[componentId] else nil
				if component and not component.Destroyed then
					applyConfiguredMass(descendant, math.max(0.01, tonumber(component.Mass) or descendant:GetMass()))
				end
				physicalMass += descendant:GetMass()
				partCount += 1
				if not primary then
					primary = descendant
				end
			end
		end
		if primary and model.PrimaryPart ~= primary then
			model.PrimaryPart = primary
		end
	end

	local state: any = {
		MechId = mechId,
		Revision = mech.Revision,
		ConfiguredMass = totalMass,
		PhysicalMass = physicalMass,
		MassError = physicalMass - totalMass,
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
