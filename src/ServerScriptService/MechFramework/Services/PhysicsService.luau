--!strict
-- Maintains cached physical assembly data and keeps Roblox assembly mass aligned with canonical component mass.

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
	if type(mechId)=="string" and mechId~="" then self._dirty[mechId]=true end
end

local function applyConfiguredMass(part: BasePart, configuredMass: number)
	local volume=math.max(.001,part.Size.X*part.Size.Y*part.Size.Z)
	local density=math.clamp(configuredMass/volume,.01,100)
	local current=part.CurrentPhysicalProperties
	part.Massless=false
	part.CustomPhysicalProperties=PhysicalProperties.new(density,current.Friction,current.Elasticity,current.FrictionWeight,current.ElasticityWeight)
end

function PhysicsService:Recalculate(mechId: string): any?
	local mech=self._mechs:Get(mechId)
	if not mech then self._dirty[mechId]=nil; self._state[mechId]=nil; return nil end

	local configuredMass=0
	local componentCount=0
	for _,component in pairs(mech.Components) do
		if not component.Destroyed then configuredMass+=math.max(0,tonumber(component.Mass) or 0); componentCount+=1 end
	end

	local assemblyRoot=Workspace:FindFirstChild("MechAssemblies")
	local model=if assemblyRoot then assemblyRoot:FindFirstChild(mechId) else nil
	local physicalMass=0
	local rootCount=0
	local visualCount=0

	if model and model:IsA("Model") then
		local primary: BasePart?=model.PrimaryPart
		for _,descendant in ipairs(model:GetDescendants()) do
			if not descendant:IsA("BasePart") then continue end
			if descendant:GetAttribute("ComponentRoot")==true then
				local componentId=descendant:GetAttribute("ComponentId")
				local component=if type(componentId)=="string" then mech.Components[componentId] else nil
				if component and not component.Destroyed then
					applyConfiguredMass(descendant,math.max(.01,tonumber(component.Mass) or descendant:GetMass()))
					physicalMass+=descendant:GetMass()
					rootCount+=1
					if not primary then primary=descendant end
				end
			else
				-- Procedural detail never contributes a second copy of component mass.
				descendant.Massless=true
				visualCount+=1
			end
		end
		if primary and model.PrimaryPart~=primary then model.PrimaryPart=primary end
	end

	local state:any={
		MechId=mechId,
		Revision=mech.Revision,
		ConfiguredMass=configuredMass,
		PhysicalMass=physicalMass,
		MassError=physicalMass-configuredMass,
		ComponentCount=componentCount,
		RootPartCount=rootCount,
		VisualPartCount=visualCount,
		PartCount=rootCount+visualCount,
		UpdatedAt=os.clock(),
	}
	self._state[mechId]=state
	self._dirty[mechId]=nil
	return state
end

function PhysicsService:GetState(mechId: string): any?
	local mech=self._mechs:Get(mechId)
	local state=self._state[mechId]
	if self._dirty[mechId] or (mech and (not state or state.Revision~=mech.Revision)) then return self:Recalculate(mechId) end
	return state
end
function PhysicsService:GetDebugInfo(mechId: string): any? return self:GetState(mechId) end

function PhysicsService:Start()
	task.spawn(function()
		while true do
			task.wait(self._updateInterval)
			local pending={}
			for mechId in pairs(self._dirty) do table.insert(pending,mechId) end
			for _,mechId in ipairs(pending) do self:Recalculate(mechId) end
		end
	end)
end

return PhysicsService
