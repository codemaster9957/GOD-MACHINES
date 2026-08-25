--!strict
-- Connected, scheduled power simulation. Capacity and thermal cost balance scale; device counts are unrestricted.
local PowerService: any = {
	_cache = {},
	_topology = {},
	_active = {},
	_tickRate = 0.25,
}

local function number(value: any, fallback: number): number
	local parsed = tonumber(value)
	return if parsed ~= nil and parsed == parsed then parsed else fallback
end

function PowerService:Init(container)
	self._mechs = container:Get("MechService")
end

function PowerService:Start()
	task.spawn(function()
		while true do
			task.wait(self._tickRate)
			for mechId in self._active do
				self:Evaluate(mechId, self._tickRate)
			end
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
	for componentId, component in mech.Components do
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
			for neighborId in (mech.Adjacency[current] or {}) do
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

function PowerService:Evaluate(mechId: string, dt: number?): {[string]: any}?
	local mech = self._mechs:Get(mechId)
	if not mech then
		self._active[mechId] = nil
		self._cache[mechId] = nil
		return nil
	end
	self._active[mechId] = true
	local topology = self._topology[mechId]
	if not topology or topology.Revision ~= mech.Revision then
		topology = self:_buildTopology(mechId, mech)
	end

	local elapsed = math.max(0, number(dt, 0))
	local aggregate = {
		Production = 0, Demand = 0, BatteryCharge = 0, BatteryCapacity = 0,
		MaximumOutput = 0, Consumption = 0, Shortage = 0, OnlineFraction = 1,
		Revision = mech.Revision, Networks = {}, Components = {},
	}

	for networkId, memberIds in topology.Networks do
		local production, maximumOutput, demand = 0, 0, 0
		local consumers, batteries = {}, {}
		for _, componentId in memberIds do
			local component = mech.Components[componentId]
			local config = component.Power
			if config then
				local generation = math.max(0, number(config.Generation, 0))
				local output = math.max(0, number(config.MaximumOutput, generation))
				local efficiency = math.clamp(number(component.Metadata.PowerEfficiency, 1), 0, 1)
				production += math.min(generation, output) * efficiency
				maximumOutput += output
				local requested = math.max(0, number(config.Demand, 0))
				if requested > 0 then
					table.insert(consumers, { Id = componentId, Demand = requested, Priority = number(config.Priority, 100) })
					demand += requested
				end
				local capacity = math.max(0, number(config.StorageCapacity, number(config.Capacity, 0)))
				if capacity > 0 then
					config.Charge = math.clamp(number(config.Charge, capacity), 0, capacity)
					table.insert(batteries, { Config = config, Capacity = capacity, MaxOutput = math.max(0, number(config.StorageOutput, number(config.MaximumOutput, capacity))) })
				end
			end
		end
		table.sort(consumers, function(a, b) return if a.Priority == b.Priority then a.Id < b.Id else a.Priority < b.Priority end)

		local available = production
		local batteryDischarge = 0
		local deficit = math.max(0, demand - available)
		for _, battery in batteries do
			if deficit <= 0 then break end
			local timeLimit = if elapsed > 0 then battery.MaxOutput * elapsed else battery.MaxOutput
			local used = math.min(deficit, battery.Config.Charge, timeLimit)
			battery.Config.Charge -= used
			batteryDischarge += used
			deficit -= used
		end
		available += batteryDischarge

		local consumption = 0
		for _, consumer in consumers do
			local supplied = math.min(consumer.Demand, available)
			available -= supplied
			consumption += supplied
			local fraction = if consumer.Demand > 0 then supplied / consumer.Demand else 1
			local component = mech.Components[consumer.Id]
			component.Metadata.PowerFraction = fraction
			component.Metadata.PowerState = if fraction >= 0.999 then "Online" elseif fraction > 0 then "Reduced" else "Shutdown"
			aggregate.Components[consumer.Id] = { NetworkId = networkId, Demand = consumer.Demand, Consumption = supplied, Fraction = fraction, State = component.Metadata.PowerState, Priority = consumer.Priority }
		end

		local surplus = math.max(0, production - consumption)
		for _, battery in batteries do
			if surplus <= 0 then break end
			local room = battery.Capacity - battery.Config.Charge
			local inputLimit = math.max(0, number(battery.Config.StorageInput, battery.MaxOutput))
			local timeLimit = if elapsed > 0 then inputLimit * elapsed else inputLimit
			local stored = math.min(surplus, room, timeLimit)
			battery.Config.Charge += stored
			surplus -= stored
		end

		local charge, capacity = 0, 0
		for _, battery in batteries do charge += battery.Config.Charge; capacity += battery.Capacity end
		local shortage = math.max(0, demand - consumption)
		local networkState = {
			Id = networkId, Members = memberIds, Production = production, Demand = demand,
			BatteryCharge = charge, BatteryCapacity = capacity, BatteryDischarge = batteryDischarge,
			MaximumOutput = maximumOutput, Consumption = consumption, Shortage = shortage,
			OnlineFraction = if demand > 0 then consumption / demand else 1,
		}
		aggregate.Networks[networkId] = networkState
		aggregate.Production += production; aggregate.Demand += demand
		aggregate.BatteryCharge += charge; aggregate.BatteryCapacity += capacity
		aggregate.MaximumOutput += maximumOutput; aggregate.Consumption += consumption
		aggregate.Shortage += shortage
	end
	if aggregate.Demand > 0 then aggregate.OnlineFraction = aggregate.Consumption / aggregate.Demand end
	-- Compatibility aliases for existing callers.
	aggregate.Generation = aggregate.Production
	aggregate.Available = aggregate.Production - aggregate.Consumption
	self._cache[mechId] = aggregate
	return aggregate
end

function PowerService:GetPowerState(mechId: string, componentId: string?): any
	local state = self:Evaluate(mechId)
	if not state then return nil end
	return if componentId then state.Components[componentId] else state
end

function PowerService:CanConsumePower(mechId: string, componentId: string, amount: number?): boolean
	local state = self:GetPowerState(mechId, componentId)
	if not state then return false end
	local needed = math.max(0, number(amount, state.Demand or 0))
	local network = self._cache[mechId].Networks[state.NetworkId]
	return state.State ~= "Shutdown" and (network.Production + network.BatteryCharge - network.Consumption) >= needed
end

function PowerService:RequestPower(mechId: string, componentId: string, amount: number, allowPartial: boolean?): (number, string)
	if amount <= 0 or amount ~= amount then return 0, "InvalidAmount" end
	local componentState = self:GetPowerState(mechId, componentId)
	if not componentState then return 0, "NotPowered" end
	local network = self._cache[mechId].Networks[componentState.NetworkId]
	local supplied = math.min(amount, math.max(0, network.Production + network.BatteryCharge - network.Consumption))
	if supplied < amount and not allowPartial then return 0, "Shortage" end
	return supplied, if supplied >= amount then "Powered" elseif supplied > 0 then "Reduced" else "Shutdown"
end

function PowerService:SetPriority(mechId: string, ownerId: number, componentId: string, priority: number): (boolean, string)
	local mech = self._mechs:Get(mechId)
	if not mech or mech.Owner ~= ownerId then return false, "NotAuthorized" end
	local component = mech.Components[componentId]
	if not component or component.Destroyed or not component.Power then return false, "InvalidComponent" end
	if priority ~= priority then return false, "InvalidPriority" end
	component.Power.Priority = math.clamp(math.floor(priority), -1000000, 1000000)
	self._mechs:MarkChanged(mechId)
	self:Invalidate(mechId)
	return true, "PriorityUpdated"
end

function PowerService:SetEnabled(mechId: string, ownerId: number, componentId: string, enabled: boolean): (boolean, string)
	local mech = self._mechs:Get(mechId)
	if not mech or mech.Owner ~= ownerId then return false, "NotAuthorized" end
	local component = mech.Components[componentId]
	if not component or component.Destroyed or not component.Power then return false, "InvalidComponent" end
	component.Metadata.PowerEnabled = enabled
	self._mechs:MarkChanged(mechId)
	self:Invalidate(mechId)
	return true, if enabled then "Enabled" else "Shutdown"
end

function PowerService:GetCached(mechId: string): {[string]: any}? return self._cache[mechId] end
function PowerService:GetDebugInfo(mechId: string): any return self:Evaluate(mechId) end

return PowerService