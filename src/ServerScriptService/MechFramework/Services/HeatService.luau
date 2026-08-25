--!strict
-- Connected thermal simulation. Active Test/Battle machines tick automatically; editor machines stay frozen.
-- Propulsion heat follows actual output, weapon heat comes from firing events, and read-only debug queries cause no damage.

local Workspace = game:GetService("Workspace")

local HeatService: any = {
	_temperature = {},
	_topology = {},
	_active = {},
	_tickRate = 0.5,
	_ambient = 20,
	_defaultConductivity = 0.12,
}

local function number(value: any, fallback: number): number
	local parsed = tonumber(value)
	return if parsed ~= nil and parsed == parsed then parsed else fallback
end

local function metadata(component: any): any
	component.Metadata = component.Metadata or {}
	return component.Metadata
end

function HeatService:Init(container: any)
	self._mechs = container:Get("MechService")
	self._power = if container:Has("PowerService") then container:Get("PowerService") else nil
	self._damage = if container:Has("DamageService") then container:Get("DamageService") else nil
end

function HeatService:Start()
	task.spawn(function()
		while true do
			task.wait(self._tickRate)
			local assemblies = Workspace:FindFirstChild("MechAssemblies")
			if not assemblies then continue end
			for _, model in ipairs(assemblies:GetChildren()) do
				if model:IsA("Model") and model:GetAttribute("EditMode") == false then
					self:Step(model.Name, self._tickRate)
				end
			end
		end
	end)
end

function HeatService:Invalidate(mechId: string)
	self._topology[mechId] = nil
	self._active[mechId] = true
end

function HeatService:_buildTopology(mechId: string, mech: any): any
	local membership, networks, seen = {}, {}, {}
	local index = 0
	for componentId, component in pairs(mech.Components) do
		if component.Destroyed or seen[componentId] then continue end
		index += 1
		local networkId = string.format("%s:H%d", mechId, index)
		local members, queue, head = {}, {componentId}, 1
		seen[componentId] = true
		while queue[head] do
			local current = queue[head]
			head += 1
			table.insert(members, current)
			membership[current] = networkId
			for neighborId in pairs(mech.Adjacency[current] or {}) do
				local neighbor = mech.Components[neighborId]
				if neighbor and not neighbor.Destroyed and not seen[neighborId] then
					seen[neighborId] = true
					table.insert(queue, neighborId)
				end
			end
		end
		networks[networkId] = members
	end
	local topology = { Revision=mech.Revision, Networks=networks, Membership=membership }
	self._topology[mechId] = topology
	return topology
end

function HeatService:AddHeat(mechId: string, componentId: string, amount: number): boolean
	if amount < 0 or amount ~= amount then return false end
	local component = self._mechs:GetComponent(mechId, componentId)
	if not component or component.Destroyed then return false end
	self._temperature[mechId] = self._temperature[mechId] or {}
	local temperatures = self._temperature[mechId]
	temperatures[componentId] = number(temperatures[componentId], self._ambient) + amount
	self._active[mechId] = true
	return true
end

function HeatService:Add(mechId: string, componentId: string, amount: number): boolean
	return self:AddHeat(mechId, componentId, amount)
end

function HeatService:GetTemperature(mechId: string, componentId: string): number
	local temperatures = self._temperature[mechId]
	return if temperatures then number(temperatures[componentId], self._ambient) else self._ambient
end

function HeatService:Get(mechId: string, componentId: string): number
	return self:GetTemperature(mechId, componentId)
end

local function generationActivity(component: any): number
	local meta = metadata(component)
	-- CombatService injects heat per successful shot. Static weapon Generation is a design ceiling,
	-- not an idle heater.
	if component.Combat then return 0 end
	if component.Propulsion then return math.clamp(number(meta.PropulsionFraction, 0), 0, 1) end
	if component.Power and number(component.Power.Generation, 0) > 0 then
		return if meta.PowerEnabled == false then 0 else math.clamp(number(meta.HeatEfficiency, 1), .1, 1)
	end
	return 1
end

function HeatService:Step(mechId: string, dt: number): any
	local mech = self._mechs:Get(mechId)
	if not mech then
		self._active[mechId] = nil
		self._temperature[mechId] = nil
		self._topology[mechId] = nil
		return nil
	end
	local topology = self._topology[mechId]
	if not topology or topology.Revision ~= mech.Revision then topology = self:_buildTopology(mechId, mech) end
	local temperatures = self._temperature[mechId] or {}
	self._temperature[mechId] = temperatures
	local elapsed = math.max(0, dt)
	local deltas = {}
	local powerState = if self._power then self._power:GetPowerState(mechId) else nil

	for componentId, component in pairs(mech.Components) do
		if component.Destroyed then continue end
		local config = component.Heat or {}
		local meta = metadata(component)
		local temperature = number(temperatures[componentId], self._ambient)
		temperatures[componentId] = temperature
		local powerFraction = if component.Power then math.clamp(number(meta.PowerFraction, if number(component.Power.Demand,0)>0 then 0 else 1),0,1) else 1
		local activity = generationActivity(component)
		local generated = math.max(0, number(config.Generation, 0)) * activity * powerFraction
		local healthFraction = if component.MaxHealth > 0 then component.Health / component.MaxHealth else 1
		generated += math.max(0, number(config.DamagedGeneration, 0)) * (1-healthFraction)
		local cooling = math.max(0, number(config.Cooling, number(config.Dissipation, 0))) * powerFraction
		deltas[componentId] = (generated-cooling)*elapsed
	end

	for _, edge in pairs(mech.Connections) do
		local a,b=mech.Components[edge.A],mech.Components[edge.B]
		if not a or not b or a.Destroyed or b.Destroyed then continue end
		local ta,tb=number(temperatures[edge.A],self._ambient),number(temperatures[edge.B],self._ambient)
		local ca=number(a.Heat and a.Heat.Conductivity,self._defaultConductivity)
		local cb=number(b.Heat and b.Heat.Conductivity,self._defaultConductivity)
		local transfer=(ta-tb)*math.max(0,math.min(ca,cb))*elapsed
		deltas[edge.A]=number(deltas[edge.A],0)-transfer
		deltas[edge.B]=number(deltas[edge.B],0)+transfer
	end

	local debugComponents={}
	for componentId,delta in pairs(deltas) do
		local component=mech.Components[componentId]
		local config=component.Heat or {}
		local meta=metadata(component)
		local temperature=math.max(self._ambient,number(temperatures[componentId],self._ambient)+delta)
		temperatures[componentId]=temperature
		local capacity=math.max(self._ambient+1,number(config.Capacity,100))
		local shutdownAt=number(config.ShutdownTemperature,capacity)
		local damageAt=number(config.DamageTemperature,capacity*1.2)
		local explodeAt=number(config.ExplosionTemperature,capacity*2)
		local ratio=math.max(0,(temperature-self._ambient)/(capacity-self._ambient))
		meta.Temperature=temperature
		meta.HeatEfficiency=math.clamp(1-math.max(0,ratio-.7),.1,1)
		meta.Overheated=temperature>=shutdownAt
		meta.ThermalState=if temperature>=explodeAt then "Critical" elseif temperature>=damageAt then "Damaging" elseif temperature>=shutdownAt then "Shutdown" elseif ratio>=.7 then "Hot" else "Nominal"
		meta.Jammed=temperature>=number(config.JamTemperature,shutdownAt)

		if elapsed>0 and temperature>=explodeAt and self._damage then
			self._damage:Apply(mechId,componentId,component.Health,{Source="ThermalExplosion",DamageType="Heat"})
		elseif elapsed>0 and temperature>=damageAt and self._damage then
			self._damage:Apply(mechId,componentId,math.max(0,number(config.OverheatDamage,5))*elapsed,{Source="Overheat",DamageType="Heat"})
		end
		debugComponents[componentId]={Temperature=temperature,NetworkId=topology.Membership[componentId],State=meta.ThermalState,Efficiency=meta.HeatEfficiency}
	end
	return {Revision=mech.Revision,Networks=topology.Networks,Components=debugComponents,Power=powerState}
end

function HeatService:Cool(mechId: string, dt: number, rate: number)
	local temperatures=self._temperature[mechId]
	if not temperatures then return end
	for componentId,value in pairs(temperatures) do temperatures[componentId]=math.max(self._ambient,value-math.max(0,rate)*math.max(0,dt)) end
end

function HeatService:GetDebugInfo(mechId: string): any return self:Step(mechId,0) end

return HeatService