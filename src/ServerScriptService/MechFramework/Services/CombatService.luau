--!strict
-- Server-authoritative weapon validation, shared machine ammunition, power, heat, projectiles and recoil.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Definitions = require(ReplicatedStorage.MechFramework.Shared.WeaponDefinitions)

type NumberMap = {[string]: number}

local Combat: any = {
	_lastFire = {} :: NumberMap,
	_ammo = {} :: NumberMap, -- keyed by mech id; generic ammunition capacity is shared by ballistic weapons
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
	if current == nil then
		current = capacity
	elseif current > capacity then
		current = capacity
	end
	self._ammo[mechId] = math.max(0, current)
	return self._ammo[mechId]
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
	if requiredPower > 0 and not self._power:CanConsumePower(mechId, weaponId, requiredPower) then return false, "NoPower" end

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
	local direction = forward
	if type(aim) == "table" and typeof(aim.Direction) == "Vector3" and aim.Direction.Magnitude > .9 then
		local requested = aim.Direction.Unit
		local maxArc = math.rad(math.clamp(tonumber(config.TurnSpeed) or 0, 0, 180))
		if maxArc > 0 and math.acos(math.clamp(forward:Dot(requested), -1, 1)) <= maxArc then direction = requested end
	end
	local origin = part.Position + forward * (math.max(part.Size.Z, part.Size.X, part.Size.Y) * .5 + .2)

	local energyUsage = math.max(0, tonumber(config.EnergyUsage) or 0)
	if energyUsage > 0 then
		local supplied = tonumber(self._power:RequestPower(mechId, weaponId, energyUsage)) or 0
		if supplied < energyUsage then return false, "PowerRejected" end
	end

	local ammoUsage = math.max(0, tonumber(config.AmmoUsage) or 0)
	if ammoUsage > 0 then self._ammo[mechId] = math.max(0, self:_ammoState(mechId) - ammoUsage) end
	self._lastFire[weaponId] = os.clock()

	local heatGenerated = math.max(0, tonumber(config.HeatGenerated) or 0)
	if heatGenerated > 0 then self._heat:AddHeat(mechId, weaponId, heatGenerated) end

	local projectileSuccess = self._projectiles:Fire(origin, direction, config, {
		MechId=mechId, WeaponId=weaponId, UserId=userId, Ignore=model,
	})
	if projectileSuccess == false then return false, "ProjectileRejected" end

	local recoil = math.max(0, tonumber(config.Recoil) or 0)
	if recoil > 0 then
		local assembly = part.AssemblyRootPart or part
		if not assembly.Anchored then assembly:ApplyImpulseAtPosition(-direction * recoil, origin) end
	end
	return true, nil
end

function Combat:RecordFire(userId: number, mechId: string, weaponId: string): (boolean, string?)
	return self:Fire(userId, mechId, weaponId, nil)
end

function Combat:Reload(mechId: string, _weaponId: string, amount: number): boolean
	if amount <= 0 then return false end
	local capacity = self:_ammoCapacity(mechId)
	if capacity <= 0 then return false end
	self._ammo[mechId] = math.min(capacity, self:_ammoState(mechId) + amount)
	return true
end

function Combat:GetAmmo(mechId: string): (number, number)
	return self:_ammoState(mechId), self:_ammoCapacity(mechId)
end

function Combat:DebugWeapon(mechId: string, weaponId: string): any
	local weapon = self._mechs:GetComponent(mechId, weaponId)
	if not weapon or weapon.Combat == nil then return nil end
	local ammo, capacity = self:GetAmmo(mechId)
	return {
		Config=Definitions.Resolve(weapon.Combat),
		Ammo=ammo,
		AmmoCapacity=capacity,
		LastFire=self._lastFire[weaponId],
		Power=self._power:GetPowerState(mechId, weaponId),
		Temperature=self._heat:GetTemperature(mechId, weaponId),
	}
end

return Combat
