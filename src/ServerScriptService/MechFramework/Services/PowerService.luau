--!strict
-- Connected, scheduled power simulation. Power is a rate; battery Charge is stored energy.
-- Read-only evaluations never mutate stored energy. Instant burst consumers drain real network storage.

local PowerService: any = {
	_cache = {},
	_topology = {},
	_active = {},
	_tickRate = 0.25,
}

-- StorageOutput is a power rating. Instant weapon draws may use at most one second of that
-- rating per transaction, which makes capacitors/high-output batteries meaningfully different.
local BURST_OUTPUT_WINDOW = 1

local function number(value: any, fallback: number): number
	local parsed = tonumber(value)
	return if parsed ~= nil and parsed == parsed and parsed ~= math.huge and parsed ~= -math.huge then parsed else fallback
end

local function metadata(component: any): any
	component.Metadata = component.Metadata or {}
	return component.Metadata
end

function PowerService:Init(container: any)
	self._mechs = container:Get("MechService")
end

function PowerService:Start()
	task.spawn(function()
		while true do
			task.wait(self._tickRate)
			for mechId in pairs(self._active) do self:Evaluate(mechId, self._tickRate) end
		end
	end)
end

function PowerService:Invalidate(mechId: string)
	self._topology[mechId] = nil
	self._cache[mechId] = nil
	self._active[mechId] = true
end

function PowerService:_buildTopology(mechId: string, mech: any): any
	local networks, membership, seen = {}, {}, {}
	local networkIndex = 0
	for componentId, component in pairs(mech.Components) do
		if component.Destroyed or seen[componentId] then continue end
		networkIndex += 1
		local networkId = string.format("%s:P%d", mechId, networkIndex)
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
	local topology = { Revision = mech.Revision, Networks = networks, Membership = membership }
	self._topology[mechId] = topology
	return topology
end

local function storageSnapshot(config: any, elapsed: number): any?
	local capacity = math.max(0, number(config.StorageCapacity, number(config.Capacity, 0)))
	if capacity <= 0 then return nil end
	config.Charge = math.clamp(number(config.Charge, capacity), 0, capacity)
	local maxOutput = math.max(0, number(config.StorageOutput, number(config.MaximumOutput, capacity)))
	local maxInput = math.max(0, number(config.StorageInput, maxOutput))
	local availableOutput = maxOutput
	if elapsed > 0 then availableOutput = math.min(maxOutput, config.Charge / elapsed)
	elseif config.Charge <= 0 then availableOutput = 0 end
	return { Config=config, Capacity=capacity, MaxOutput=maxOutput, MaxInput=maxInput, AvailableOutput=availableOutput }
end

function PowerService:Evaluate(mechId: string, dt: number?): {[string]: any}?
	local mech = self._mechs:Get(mechId)
	if not mech then
		self._active[mechId] = nil; self._cache[mechId] = nil; self._topology[mechId] = nil
		return nil
	end
	self._active[mechId] = true
	local topology = self._topology[mechId]
	if not topology or topology.Revision ~= mech.Revision then topology = self:_buildTopology(mechId, mech) end

	local elapsed = math.max(0, number(dt, 0))
	local mutateEnergy = elapsed > 0
	local aggregate = {
		Production=0, Demand=0, BatteryCharge=0, BatteryCapacity=0,
		BatteryAvailablePower=0, BatteryDischarge=0, BatteryChargeRate=0,
		MaximumOutput=0, Consumption=0, Shortage=0, AvailablePower=0,
		OnlineFraction=1, Revision=mech.Revision, Networks={}, Components={},
	}

	for networkId, memberIds in pairs(topology.Networks) do
		local production, maximumOutput, demand = 0, 0, 0
		local consumers, batteries = {}, {}

		for _, componentId in ipairs(memberIds) do
			local component = mech.Components[componentId]
			local config = component.Power
			local meta = metadata(component)
			local enabled = meta.PowerEnabled ~= false
			if config then
				local generation = if enabled then math.max(0, number(config.Generation, 0)) else 0
				local output = if enabled then math.max(0, number(config.MaximumOutput, generation)) else 0
				local efficiency = math.clamp(number(meta.PowerEfficiency, 1), 0, 1)
				production += math.min(generation, output) * efficiency
				maximumOutput += output

				local requested = if enabled then math.max(0, number(config.Demand, 0)) else 0
				if requested > 0 then
					table.insert(consumers, { Id=componentId, Demand=requested, Priority=number(config.Priority, 100) })
					demand += requested
				elseif not enabled then
					meta.PowerFraction = 0; meta.PowerState = "Shutdown"
					aggregate.Components[componentId] = { NetworkId=networkId, Demand=0, Consumption=0, Fraction=0, State="Shutdown", Priority=number(config.Priority,100) }
				end
				if enabled then local battery=storageSnapshot(config,elapsed); if battery then table.insert(batteries,battery) end end
			end
		end

		table.sort(consumers,function(a,b) return if a.Priority==b.Priority then a.Id<b.Id else a.Priority<b.Priority end)
		local batteryAvailablePower=0
		for _,battery in ipairs(batteries) do batteryAvailablePower+=battery.AvailableOutput end
		local totalAvailablePower=production+batteryAvailablePower
		local allocationRemaining=totalAvailablePower
		local consumption=0

		for _,consumer in ipairs(consumers) do
			local supplied=math.min(consumer.Demand,allocationRemaining)
			allocationRemaining-=supplied; consumption+=supplied
			local fraction=if consumer.Demand>0 then supplied/consumer.Demand else 1
			local component=mech.Components[consumer.Id]; local meta=metadata(component)
			meta.PowerFraction=fraction
			meta.PowerState=if fraction>=.999 then "Online" elseif fraction>0 then "Reduced" else "Shutdown"
			aggregate.Components[consumer.Id]={NetworkId=networkId,Demand=consumer.Demand,Consumption=supplied,Fraction=fraction,State=meta.PowerState,Priority=consumer.Priority}
		end

		local batteryPowerNeeded=math.max(0,consumption-production)
		local batteryDischargePower=0
		if mutateEnergy and batteryPowerNeeded>0 then
			for _,battery in ipairs(batteries) do
				if batteryPowerNeeded<=1e-6 then break end
				local power=math.min(batteryPowerNeeded,battery.MaxOutput,battery.Config.Charge/elapsed)
				if power>0 then battery.Config.Charge=math.max(0,battery.Config.Charge-power*elapsed); batteryPowerNeeded-=power; batteryDischargePower+=power end
			end
		else
			batteryDischargePower=math.min(math.max(0,consumption-production),batteryAvailablePower)
		end

		local surplusPower=math.max(0,production-consumption)
		local batteryChargeRate=0
		for _,battery in ipairs(batteries) do
			if surplusPower<=1e-6 then break end
			local room=battery.Capacity-battery.Config.Charge
			local roomPower=if elapsed>0 then room/elapsed else (if room>0 then battery.MaxInput else 0)
			local chargePower=math.min(surplusPower,battery.MaxInput,roomPower)
			if chargePower>0 then
				if mutateEnergy then battery.Config.Charge=math.min(battery.Capacity,battery.Config.Charge+chargePower*elapsed) end
				batteryChargeRate+=chargePower; surplusPower-=chargePower
			end
		end

		local charge,capacity=0,0
		for _,battery in ipairs(batteries) do charge+=battery.Config.Charge; capacity+=battery.Capacity end
		local shortage=math.max(0,demand-consumption)
		local availablePower=math.max(0,production+batteryAvailablePower-consumption)
		local networkState={
			Id=networkId,Members=memberIds,Production=production,Demand=demand,
			BatteryCharge=charge,BatteryCapacity=capacity,BatteryAvailablePower=batteryAvailablePower,
			BatteryDischarge=batteryDischargePower,BatteryChargeRate=batteryChargeRate,
			MaximumOutput=maximumOutput,Consumption=consumption,Shortage=shortage,AvailablePower=availablePower,
			OnlineFraction=if demand>0 then consumption/demand else 1,
		}
		aggregate.Networks[networkId]=networkState
		aggregate.Production+=production; aggregate.Demand+=demand
		aggregate.BatteryCharge+=charge; aggregate.BatteryCapacity+=capacity
		aggregate.BatteryAvailablePower+=batteryAvailablePower; aggregate.BatteryDischarge+=batteryDischargePower; aggregate.BatteryChargeRate+=batteryChargeRate
		aggregate.MaximumOutput+=maximumOutput; aggregate.Consumption+=consumption; aggregate.Shortage+=shortage; aggregate.AvailablePower+=availablePower
	end

	if aggregate.Demand>0 then aggregate.OnlineFraction=aggregate.Consumption/aggregate.Demand end
	aggregate.Generation=aggregate.Production; aggregate.Available=aggregate.AvailablePower
	self._cache[mechId]=aggregate
	return aggregate
end

function PowerService:_networkForComponent(mechId: string, componentId: string): (any?, any?, any?)
	local state=self:Evaluate(mechId)
	local topology=self._topology[mechId]
	if not state or not topology then return nil,nil,nil end
	local networkId=topology.Membership[componentId]
	if not networkId then return nil,nil,nil end
	return state.Networks[networkId],state,topology
end

function PowerService:GetPowerState(mechId: string, componentId: string?): any
	local state=self:Evaluate(mechId)
	if not state then return nil end
	if not componentId then return state end
	local direct=state.Components[componentId]
	if direct then return direct end
	local topology=self._topology[mechId]; local networkId=topology and topology.Membership[componentId]
	if not networkId then return nil end
	return {NetworkId=networkId,Demand=0,Consumption=0,Fraction=1,State="Online",Priority=100}
end

function PowerService:CanConsumePower(mechId: string, componentId: string, amount: number?): boolean
	local network=self:_networkForComponent(mechId,componentId)
	if not network then return false end
	local needed=math.max(0,number(amount,0))
	return network.AvailablePower>=needed
end

-- Compatibility rate query. This does not consume stored energy; use ConsumeEnergy for finite burst work.
function PowerService:RequestPower(mechId: string, componentId: string, amount: number, allowPartial: boolean?): (number,string)
	if amount<=0 or amount~=amount or amount==math.huge then return 0,"InvalidAmount" end
	local network=self:_networkForComponent(mechId,componentId)
	if not network then return 0,"NotPowered" end
	local supplied=math.min(amount,math.max(0,number(network.AvailablePower,0)))
	if supplied<amount and not allowPartial then return 0,"Shortage" end
	return supplied,if supplied>=amount then "Powered" elseif supplied>0 then "Reduced" else "Shutdown"
end

-- Atomic finite-energy draw for railguns/lasers/plasma and future burst machinery.
-- Only storage can supply instant energy: generators recharge batteries/capacitors over time.
function PowerService:ConsumeEnergy(mechId: string, componentId: string, amount: number, allowPartial: boolean?): (number,string)
	if amount<=0 or amount~=amount or amount==math.huge then return 0,"InvalidAmount" end
	local mech=self._mechs:Get(mechId)
	local network,_,topology=self:_networkForComponent(mechId,componentId)
	if not mech or not network or not topology then return 0,"NotPowered" end
	local networkId=topology.Membership[componentId]
	local memberIds=networkId and topology.Networks[networkId]
	if not memberIds then return 0,"NotPowered" end

	local stores={}
	local totalAvailable=0
	for _,id in ipairs(memberIds) do
		local component=mech.Components[id]
		local config=component and component.Power
		local meta=component and metadata(component)
		if config and component and not component.Destroyed and meta.PowerEnabled~=false then
			local capacity=math.max(0,number(config.StorageCapacity,number(config.Capacity,0)))
			if capacity>0 then
				config.Charge=math.clamp(number(config.Charge,capacity),0,capacity)
				local output=math.max(0,number(config.StorageOutput,number(config.MaximumOutput,capacity)))
				local available=math.min(config.Charge,output*BURST_OUTPUT_WINDOW)
				if available>0 then table.insert(stores,{Config=config,Available=available}); totalAvailable+=available end
			end
		end
	end

	if totalAvailable<=0 then return 0,"NoEnergyStorage" end
	if totalAvailable+1e-6<amount and not allowPartial then return 0,"InsufficientStoredEnergy" end
	local supplied=math.min(amount,totalAvailable)
	local remaining=supplied
	for _,store in ipairs(stores) do
		if remaining<=1e-6 then break end
		local used=math.min(remaining,store.Available)
		store.Config.Charge=math.max(0,store.Config.Charge-used)
		remaining-=used
	end
	self._cache[mechId]=nil
	self._active[mechId]=true
	return supplied,if supplied+1e-6>=amount then "Powered" else "Reduced"
end

function PowerService:SetPriority(mechId: string, ownerId: number, componentId: string, priority: number): (boolean,string)
	local mech=self._mechs:Get(mechId)
	if not mech or mech.Owner~=ownerId then return false,"NotAuthorized" end
	local component=mech.Components[componentId]
	if not component or component.Destroyed or not component.Power then return false,"InvalidComponent" end
	if priority~=priority or priority==math.huge or priority==-math.huge then return false,"InvalidPriority" end
	component.Power.Priority=math.clamp(math.floor(priority),-1000000,1000000)
	self._mechs:MarkChanged(mechId); self:Invalidate(mechId)
	return true,"PriorityUpdated"
end

function PowerService:SetEnabled(mechId: string, ownerId: number, componentId: string, enabled: boolean): (boolean,string)
	local mech=self._mechs:Get(mechId)
	if not mech or mech.Owner~=ownerId then return false,"NotAuthorized" end
	local component=mech.Components[componentId]
	if not component or component.Destroyed or not component.Power then return false,"InvalidComponent" end
	metadata(component).PowerEnabled=enabled
	self._mechs:MarkChanged(mechId); self:Invalidate(mechId)
	return true,if enabled then "Enabled" else "Shutdown"
end

function PowerService:GetCached(mechId: string): {[string]: any}? return self._cache[mechId] end
function PowerService:GetDebugInfo(mechId: string): any return self:Evaluate(mechId) end

return PowerService
