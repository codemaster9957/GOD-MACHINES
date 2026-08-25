--!strict
-- Server-owned, component-level damage. A mech never receives a shared health pool.
local Damage: any = {}

local VALID_TYPES: {[string]: boolean} = {
	Kinetic = true, Explosive = true, Energy = true,
	Heat = true, Collision = true, Melee = true,
}

local function finitePositive(value: any): number?
	local numberValue = tonumber(value)
	if not numberValue or numberValue ~= numberValue or numberValue == math.huge or numberValue <= 0 then return nil end
	return numberValue
end

local function resistanceFor(component: any, damageType: string): (number, number)
	local metadata = component.Metadata or {}
	local resistances = metadata.Resistances or component.Resistances or {}
	local resistance = math.clamp(tonumber(resistances[damageType]) or 0, -1, 0.95)
	local armour = math.max(0, tonumber((metadata.Armour or {})[damageType]) or tonumber(metadata.Armour) or 0)
	return resistance, armour
end

function Damage:Init(container: any)
	self._mechs = container:Get("MechService")
	self._destruction = container:Get("DestructionService")
	self._destruction:SetDamageService(self)
end

function Damage:Apply(mechId: string, componentId: string, amount: number, context: {[string]: any}?): (boolean, number?)
	local requested = finitePositive(amount)
	if not requested then return false, nil end
	local component = self._mechs:GetComponent(mechId, componentId)
	if not component or component.Destroyed or component.DamageState == "Destroyed" then return false, nil end

	context = context or {}
	local damageType = if VALID_TYPES[context.DamageType] then context.DamageType else "Kinetic"
	local resistance, armour = resistanceFor(component, damageType)
	local penetration = math.max(0, tonumber(context.Penetration) or 0)
	local effectiveArmour = math.max(0, armour - penetration)
	local dealt = math.max(0, requested * (1 - resistance) - effectiveArmour)
	if dealt <= 0 then return false, component.Health end

	component.Health = math.max(0, component.Health - dealt)
	component.Metadata = component.Metadata or {}
	local ratio = component.Health / math.max(1, component.MaxHealth)
	component.DamageState = if component.Health <= 0 then "Destroyed" elseif ratio <= 0.25 then "Critical" elseif ratio <= 0.7 then "Damaged" else "Operational"
	component.Metadata.DamageState = component.DamageState
	component.Metadata.LastDamage = {
		Time = os.clock(), Source = context.Source or "Environment", DamageType = damageType,
		Requested = requested, Applied = dealt, Position = context.Position,
	}

	local destroyedNow = component.Health <= 0
	if destroyedNow then
		component.Destroyed = true
		component.Metadata.Operational = false
	end
	self._mechs:MarkChanged(mechId)
	self._destruction:OnComponentDamaged(mechId, componentId, dealt, context)
	if destroyedNow then self._destruction:HandleDestroyed(mechId, componentId, context) end
	return true, component.Health
end

function Damage:Repair(mechId: string, componentId: string, amount: number, authorized: boolean): boolean
	local repair = finitePositive(amount)
	if not authorized or not repair then return false end
	local component = self._mechs:GetComponent(mechId, componentId)
	if not component or component.Destroyed then return false end
	component.Health = math.min(component.MaxHealth, component.Health + repair)
	local ratio = component.Health / math.max(1, component.MaxHealth)
	component.DamageState = if ratio <= 0.25 then "Critical" elseif ratio <= 0.7 then "Damaged" else "Operational"
	component.Metadata = component.Metadata or {}; component.Metadata.DamageState = component.DamageState
	self._mechs:MarkChanged(mechId)
	return true
end

function Damage:IsDamageType(value: string): boolean
	return VALID_TYPES[value] == true
end

return Damage