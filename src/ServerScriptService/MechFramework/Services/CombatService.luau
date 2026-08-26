--!strict
-- Server-authoritative weapon validation, focused aiming, bloom, ammunition, power, heat, projectiles and recoil.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Definitions = require(ReplicatedStorage.MechFramework.Shared.WeaponDefinitions)
local CombatMath = require(ReplicatedStorage.MechFramework.Shared.CombatMath)

type NumberMap = {[string]: number}

local Combat: any = {
	_lastFire = {} :: NumberMap,
	_ammo = {} :: NumberMap,
	_bloom = {} :: NumberMap,
	_shotSequence = {} :: NumberMap,
	_mechs = nil,
	_heat = nil,
	_power = nil,
	_projectiles = nil,
}

function Combat:Init(container: any)
	self._mechs = container:Get("MechService")
	self._heat = container:Get("HeatService")
	self._power = container:Get("PowerService")
	self._projectiles = container:Get("ProjectileService")
end

local function assemblyModel(mechId: string): Model?
	local root = Workspace:FindFirstChild("MechAssemblies")
	local model = root and root:FindFirstChild(mechId)
	return if model and model:IsA("Model") then model else nil
end

function Combat:_part(mechId: string, componentId: string): BasePart?
	local model = assemblyModel(mechId)
	if not model then return nil end
	local component = model:FindFirstChild(componentId)
	if not component or not component:IsA("Model") then return nil end
	local root = component.PrimaryPart or component:FindFirstChild("Root")
	return if root and root:IsA("BasePart") and root:GetAttribute("ComponentRoot") == true then root else nil
end

function Combat:_ammoCapacity(mechId: string): number
	local mech = self._mechs:Get(mechId)
	if not mech then return 0 end
	local capacity = 0
	for _, component in pairs(mech.Components) do
		if not component.Destroyed and component.Utility and component.Utility.Kind == "AmmoStorage" then
			capacity += math.max(0, tonumber(component.Utility.Capacity) or 0)
		end
	end
	return capacity
end

function Combat:_ammoState(mechId: string): number
	local current = self._ammo[mechId]
	local capacity = self:_ammoCapacity(mechId)
	if current == nil then current = capacity elseif current > capacity then current = capacity end
	self._ammo[mechId] = math.max(0, current)
	return self._ammo[mechId]
end

function Combat:_targetMotion(aim: any): (Vector3?, Vector3?)
	if type(aim) ~= "table" or type(aim.TargetMechId) ~= "string" or type(aim.TargetComponentId) ~= "string" then return nil,nil end
	local target = self:_part(aim.TargetMechId,aim.TargetComponentId)
	if not target then return nil,nil end
	return target.Position,target.AssemblyLinearVelocity
end

function Combat:_bloomFor(weaponId: string, config: any, now: number): number
	local current = math.max(0,tonumber(self._bloom[weaponId]) or 0)
	local last = self._lastFire[weaponId]
	if last then current = math.max(0,current-math.max(0,tonumber(config.BloomRecovery) or 0)*(now-last)) end
	return math.min(math.max(0,tonumber(config.MaxBloom) or 0),current)
end

function Combat:CanFire(userId: number, mechId: string, weaponId: string): (boolean, string?)
	local mech = self._mechs:Get(mechId)
	if not mech or mech.Owner ~= userId then return false, "NotAuthorized" end
	local weapon = mech.Components and mech.Components[weaponId]
	if not weapon or weapon.Destroyed == true or weapon.Combat == nil then return false, "InvalidWeapon" end
	local config = Definitions.Resolve(weapon.Combat)
	local metadata = weapon.Metadata or {}
	local state = metadata.WeaponState or "Ready"
	if state ~= "Ready" then return false, tostring(state) end
	if metadata.Overheated == true or metadata.Jammed == true then return false, "WeaponDisabled" end
	local fireRate = math.max(tonumber(config.FireRate) or 1, .01)
	if os.clock() - (self._lastFire[weaponId] or -math.huge) < 1 / fireRate then return false, "Cooldown" end

	local requiredPower = math.max(0, tonumber(config.RequiredPower) or 0)
	if requiredPower > 0 then
		local standbyDemand = math.max(0, tonumber(weapon.Power and weapon.Power.Demand) or 0)
		if standbyDemand > 0 then
			local standbyState = self._power:GetPowerState(mechId, weaponId)
			if not standbyState or (tonumber(standbyState.Fraction) or 0) < .999 then return false, "NoPower" end
		end
		local extraRequired = math.max(0, requiredPower - standbyDemand)
		if extraRequired > 0 and not self._power:CanConsumePower(mechId, weaponId, extraRequired) then return false, "NoPower" end
	end

	local ammoUsage = math.max(0, tonumber(config.AmmoUsage) or 0)
	if ammoUsage > 0 and self:_ammoState(mechId) < ammoUsage then return false, "NoAmmoStorage" end
	return true, nil
end

function Combat:Fire(userId: number, mechId: string, weaponId: string, aim: any): (boolean, string?)
	local canFire, reason = self:CanFire(userId, mechId, weaponId)
	if not canFire then return false, reason end
	local weapon = self._mechs:GetComponent(mechId, weaponId)
	if not weapon or not weapon.Combat then return false, "InvalidWeapon" end
	local config = Definitions.Resolve(weapon.Combat)
	local part = self:_part(mechId, weaponId)
	if not part then return false, "NoPhysicalWeapon" end
	local model = assemblyModel(mechId)
	if not model then return false, "NoPhysicalWeapon" end

	local forward = part.CFrame.LookVector
	local requested = forward
	if type(aim) == "table" and CombatMath.IsFiniteVector(aim.Direction) and aim.Direction.Magnitude > .9 then requested = aim.Direction.Unit end
	local origin = part.Position + forward * (math.max(part.Size.Z, part.Size.X, part.Size.Y) * .5 + .2)

	-- For slower physical projectiles, lead only a target the server can resolve from canonical mech/component IDs.
	local mode = tostring(config.Mode or "Projectile")
	if mode ~= "Hitscan" and mode ~= "Melee" and mode ~= "Stream" then
		local targetPosition,targetVelocity = self:_targetMotion(aim)
		if targetPosition and targetVelocity then
			local lead = CombatMath.InterceptDirection(origin,targetPosition,targetVelocity,math.max(1,tonumber(config.ProjectileSpeed) or 500))
			if lead then requested = lead end
		end
	end

	-- Yaw/pitch arcs focus fire toward the cursor while keeping fixed/limited mounts believable.
	local direction = CombatMath.ClampDirection(part.CFrame,requested,tonumber(config.YawArc) or 180,tonumber(config.PitchArc) or 90)
	local now = os.clock()
	local bloom = self:_bloomFor(weaponId,config,now)
	config.Spread = math.max(0,tonumber(config.Spread) or 0) + bloom

	local energyUsage = math.max(0, tonumber(config.EnergyUsage) or 0)
	if energyUsage > 0 then
		local supplied, powerReason = self._power:ConsumeEnergy(mechId, weaponId, energyUsage, false)
		if supplied + 1e-6 < energyUsage then return false, powerReason or "InsufficientStoredEnergy" end
	end

	local ammoUsage = math.max(0, tonumber(config.AmmoUsage) or 0)
	if ammoUsage > 0 then self._ammo[mechId] = math.max(0, self:_ammoState(mechId) - ammoUsage) end
	self._lastFire[weaponId] = now
	self._bloom[weaponId] = math.min(math.max(0,tonumber(config.MaxBloom) or 0),bloom+math.max(0,tonumber(config.BloomPerShot) or 0))
	self._shotSequence[weaponId] = (self._shotSequence[weaponId] or 0) + 1

	local heatGenerated = math.max(0, tonumber(config.HeatGenerated) or 0)
	if heatGenerated > 0 then self._heat:AddHeat(mechId, weaponId, heatGenerated) end
	local projectileSuccess = self._projectiles:Fire(origin, direction, config, {
		MechId=mechId, WeaponId=weaponId, UserId=userId, Ignore=model,
		ShotSeed=self._shotSequence[weaponId] + userId*7919,
	})
	if projectileSuccess == false then return false, "ProjectileRejected" end

	local recoil = math.max(0, tonumber(config.Recoil) or 0)
	if recoil > 0 then
		local assembly = part.AssemblyRootPart or part
		if not assembly.Anchored then assembly:ApplyImpulseAtPosition(-direction * recoil, origin) end
	end
	return true, nil
end

function Combat:RecordFire(userId: number, mechId: string, weaponId: string): (boolean, string?) return self:Fire(userId, mechId, weaponId, nil) end
function Combat:Reload(mechId: string, _weaponId: string, amount: number): boolean
	if amount <= 0 then return false end
	local capacity = self:_ammoCapacity(mechId)
	if capacity <= 0 then return false end
	self._ammo[mechId] = math.min(capacity, self:_ammoState(mechId) + amount)
	return true
end
function Combat:GetAmmo(mechId: string): (number, number) return self:_ammoState(mechId), self:_ammoCapacity(mechId) end
function Combat:DebugWeapon(mechId: string, weaponId: string): any
	local weapon = self._mechs:GetComponent(mechId, weaponId)
	if not weapon or weapon.Combat == nil then return nil end
	local ammo, capacity = self:GetAmmo(mechId)
	return {
		Config=Definitions.Resolve(weapon.Combat), Ammo=ammo, AmmoCapacity=capacity, Bloom=self._bloom[weaponId] or 0,
		LastFire=self._lastFire[weaponId], Power=self._power:GetPowerState(mechId, weaponId),
		Temperature=self._heat:GetTemperature(mechId, weaponId),
	}
end
return Combat
