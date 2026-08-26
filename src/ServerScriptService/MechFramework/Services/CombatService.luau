--!strict
-- Server-authoritative ownership, cooldown, ammunition,
-- power, heat, state, aim, projectile firing, and physical recoil.

--------------------------------------------------
-- SERVICES
--------------------------------------------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

--------------------------------------------------
-- MODULES
--------------------------------------------------

local Definitions = require(
	ReplicatedStorage.MechFramework.Shared.WeaponDefinitions
)

--------------------------------------------------
-- TYPES
--------------------------------------------------

type NumberMap = {
	[string]: number,
}

type AimData = {
	Direction: Vector3?,
}

local function runtimeKey(mechId: string, weaponId: string): string
	return mechId .. ":" .. weaponId
end

local function finiteVector3(value: any): boolean
	if typeof(value) ~= "Vector3" then
		return false
	end
	local function finite(numberValue: number): boolean
		return numberValue == numberValue
			and numberValue ~= math.huge
			and numberValue ~= -math.huge
			and math.abs(numberValue) <= 1000000
	end
	return finite(value.X) and finite(value.Y) and finite(value.Z)
end

--------------------------------------------------
-- SERVICE
--------------------------------------------------

local Combat: any = {
	_lastFire = {} :: NumberMap,
	_ammo = {} :: NumberMap,

	_mechs = nil,
	_heat = nil,
	_power = nil,
	_projectiles = nil,
}

--------------------------------------------------
-- INIT
--------------------------------------------------

function Combat:Init(container: any)
	self._mechs =
		container:Get("MechService")

	self._heat =
		container:Get("HeatService")

	self._power =
		container:Get("PowerService")

	self._projectiles =
		container:Get("ProjectileService")

	self._feedback =
		ReplicatedStorage.MechFramework.Remotes.Events.CombatFeedback
end

--------------------------------------------------
-- GET PHYSICAL COMPONENT PART
--------------------------------------------------

function Combat:_part(
	mechId: string,
	componentId: string
): BasePart?

	local root =
		Workspace:FindFirstChild("MechAssemblies")

	if not root then
		return nil
	end

	local model =
		root:FindFirstChild(mechId)

	if not model then
		return nil
	end

	local instance =
		model:FindFirstChild(
			componentId,
			true
		)

	if
		instance
		and instance:IsA("BasePart")
	then
		return instance
	end

	return nil
end

--------------------------------------------------
-- CAN FIRE
--------------------------------------------------

function Combat:CanFire(
	userId: number,
	mechId: string,
	weaponId: string
): (boolean, string?)

	--------------------------------------------------
	-- MECH OWNERSHIP
	--------------------------------------------------

	local mech: any =
		self._mechs:Get(mechId)

	if
		not mech
		or mech.Owner ~= userId
	then
		return false, "NotAuthorized"
	end

	--------------------------------------------------
	-- WEAPON COMPONENT
	--------------------------------------------------

	local components: any =
		mech.Components

	if type(components) ~= "table" then
		return false, "InvalidMech"
	end

	local weapon: any =
		components[weaponId]

	if
		not weapon
		or weapon.Destroyed == true
		or weapon.Combat == nil
	then
		return false, "InvalidWeapon"
	end

	--------------------------------------------------
	-- WEAPON CONFIG
	--------------------------------------------------

	local config: any =
		Definitions.Resolve(
			weapon.Combat
		)

	if not config then
		return false, "InvalidWeaponConfig"
	end

	--------------------------------------------------
	-- METADATA / STATE
	--------------------------------------------------

	local metadata: any =
		weapon.Metadata or {}

	local state =
		metadata.WeaponState or "Ready"

	if state ~= "Ready" then
		return false, tostring(state)
	end

	if
		metadata.Overheated == true
		or metadata.Jammed == true
	then
		return false, "WeaponDisabled"
	end

	--------------------------------------------------
	-- COOLDOWN
	--------------------------------------------------

	local fireRate =
		math.max(
			tonumber(config.FireRate) or 1,
			0.01
		)

	local cooldown =
		1 / fireRate

	local lastFireMap: NumberMap =
		self._lastFire

	local stateKey = runtimeKey(mechId, weaponId)
	local lastFire =
		lastFireMap[stateKey]
		or -math.huge

	if
		os.clock() - lastFire
		< cooldown
	then
		return false, "Cooldown"
	end

	--------------------------------------------------
	-- POWER
	--------------------------------------------------

	local requiredPower =
		math.max(
			0,
			tonumber(config.RequiredPower) or 0
		)

	if requiredPower > 0 then
		local canConsume =
			self._power:CanConsumePower(
				mechId,
				weaponId,
				requiredPower
			)

		if not canConsume then
			return false, "NoPower"
		end
	end

	--------------------------------------------------
	-- AMMUNITION
	--------------------------------------------------

	local ammoUsage =
		math.max(
			0,
			tonumber(config.AmmoUsage) or 0
		)

	local ammoMap: NumberMap =
		self._ammo

	local ammo =
		ammoMap[stateKey]

	if ammo == nil then
		ammo =
			tonumber(metadata.Ammo)
			or tonumber(config.AmmoCapacity)
			or (if ammoUsage > 0 then 0 else math.huge)
	end

	if
		ammoUsage > 0
		and ammo < ammoUsage
	then
		return false, "NoAmmo"
	end

	return true, nil
end

--------------------------------------------------
-- FIRE
--------------------------------------------------

function Combat:Fire(
	userId: number,
	mechId: string,
	weaponId: string,
	aim: any
): (boolean, string?)

	--------------------------------------------------
	-- VALIDATE FIRE
	--------------------------------------------------

	local canFire: boolean, reason: string? =
		self:CanFire(
			userId,
			mechId,
			weaponId
		)

	if not canFire then
		return false, reason
	end

	--------------------------------------------------
	-- GET WEAPON
	--------------------------------------------------

	local weapon: any =
		self._mechs:GetComponent(
			mechId,
			weaponId
		)

	if weapon == nil then
		return false, "InvalidWeapon"
	end

	if weapon.Combat == nil then
		return false, "InvalidWeapon"
	end

	local metadata: any =
		weapon.Metadata or {}

	local config: any =
		Definitions.Resolve(
			weapon.Combat
		)

	if config == nil then
		return false, "InvalidWeaponConfig"
	end

	--------------------------------------------------
	-- PHYSICAL WEAPON
	--------------------------------------------------

	local part: BasePart? =
		self:_part(
			mechId,
			weaponId
		)

	if part == nil then
		return false, "NoPhysicalWeapon"
	end

	--------------------------------------------------
	-- AIM
	--------------------------------------------------

	local muzzle = part:FindFirstChild("Muzzle")
	local origin: Vector3 =
		if muzzle and muzzle:IsA("Attachment") then muzzle.WorldPosition else part.Position

	local forward: Vector3 =
		part.CFrame.LookVector

	local direction: Vector3 =
		forward

	if type(aim) == "table" then
		local requestedDirection: any =
			aim.Direction

		if
			finiteVector3(requestedDirection)
			and requestedDirection.Magnitude > 0.9
		then
			local requested: Vector3 =
				requestedDirection.Unit

			local turnSpeed: number =
				tonumber(config.TurnSpeed) or 0

			local maxArcDegrees: number =
				math.clamp(
					turnSpeed,
					0,
					180
				)

			local maxArc: number =
				math.rad(maxArcDegrees)

			if maxArc > 0 then
				local dot: number =
					math.clamp(
						forward:Dot(requested),
						-1,
						1
					)

				local angle: number =
					math.acos(dot)

				if angle <= maxArc then
					direction = requested
				end
			end
		end
	end

	--------------------------------------------------
	-- ENERGY
	--------------------------------------------------

	local energyUsage: number =
		math.max(
			0,
			tonumber(config.EnergyUsage) or 0
		)

	if energyUsage > 0 then
		local suppliedResult: any =
			self._power:RequestPower(
				mechId,
				weaponId,
				energyUsage
			)

		local supplied: number =
			tonumber(suppliedResult) or 0

		if supplied < energyUsage then
			return false, "PowerRejected"
		end
	end

	--------------------------------------------------
	-- RECORD FIRE TIME
	--------------------------------------------------

	local lastFireMap =
		self._lastFire :: {[string]: number}

	local stateKey = runtimeKey(mechId, weaponId)
	lastFireMap[stateKey] =
		os.clock()

	--------------------------------------------------
	-- AMMO
	--------------------------------------------------

	local ammoUsage: number =
		math.max(
			0,
			tonumber(config.AmmoUsage) or 0
		)

	if ammoUsage > 0 then
		local ammoMap =
			self._ammo :: {[string]: number}

		local currentAmmo: number? =
			ammoMap[stateKey]

		if currentAmmo == nil then
			currentAmmo =
				tonumber(metadata.Ammo)
				or tonumber(config.AmmoCapacity)
				or 0
		end

		local resolvedAmmo: number = currentAmmo or 0

		ammoMap[stateKey] =
			math.max(
				0,
				resolvedAmmo - ammoUsage
			)
	end

	--------------------------------------------------
	-- HEAT
	--------------------------------------------------

	local heatGenerated: number =
		math.max(
			0,
			tonumber(config.HeatGenerated) or 0
		)

	if heatGenerated > 0 then
		self._heat:AddHeat(
			mechId,
			weaponId,
			heatGenerated
		)
	end

	--------------------------------------------------
	-- FIRE PROJECTILE
	--------------------------------------------------

	local effectColor =
		if muzzle and muzzle:IsA("Attachment") and typeof(muzzle:GetAttribute("EffectColor")) == "Color3"
		then muzzle:GetAttribute("EffectColor")
		else Color3.fromRGB(255, 181, 54)

	local projectileContext: any = {
		MechId = mechId,
		WeaponId = weaponId,
		UserId = userId,
		Ignore = part.Parent,
		DamageType = config.DamageType,
		Penetration = config.Penetration,
		EffectColor = effectColor,
	}

	local projectileSuccess: any =
		self._projectiles:Fire(
			origin,
			direction,
			config,
			projectileContext
		)

	if projectileSuccess == false then
		return false, "ProjectileRejected"
	end

	self._feedback:FireAllClients({
		Kind = "Fired",
		Origin = origin,
		Direction = direction,
		Range = math.clamp(tonumber(config.Range) or 1000, 0, 5000),
		Mode = tostring(config.Mode or "Hitscan"),
		Color = effectColor,
		WeaponId = weaponId,
	})

	--------------------------------------------------
	-- RECOIL
	--------------------------------------------------

	local recoil: number =
		math.max(
			0,
			tonumber(config.Recoil) or 0
		)

	if recoil > 0 then
		local assembly: BasePart =
			part.AssemblyRootPart or part

		if not assembly.Anchored then
			local impulse: Vector3 =
				-direction * recoil

			assembly:ApplyImpulseAtPosition(
				impulse,
				origin
			)
		end
	end

	return true, nil
end
--------------------------------------------------
-- RECORD FIRE
--------------------------------------------------

function Combat:RecordFire(
	userId: number,
	mechId: string,
	weaponId: string
): (boolean, string?)

	return self:Fire(
		userId,
		mechId,
		weaponId,
		nil
	)
end

--------------------------------------------------
-- RELOAD
--------------------------------------------------

function Combat:Reload(
	userId: number,
	mechId: string,
	weaponId: string
): (boolean, string?)

	local mech = self._mechs:Get(mechId)
	if not mech or mech.Owner ~= userId then
		return false, "NotAuthorized"
	end

	local weapon = self._mechs:GetComponent(mechId, weaponId)
	if not weapon or weapon.Destroyed == true or type(weapon.Combat) ~= "table" then
		return false, "InvalidWeapon"
	end

	local config = Definitions.Resolve(weapon.Combat)
	local ammoUsage = math.max(0, tonumber(config.AmmoUsage) or 0)
	local capacity = math.max(0, tonumber(config.AmmoCapacity) or 0)
	if ammoUsage <= 0 or capacity <= 0 then
		return false, "NoMagazine"
	end

	local ammoMap: NumberMap = self._ammo
	ammoMap[runtimeKey(mechId, weaponId)] = capacity
	return true, nil
end

--------------------------------------------------
-- DEBUG WEAPON
--------------------------------------------------

function Combat:DebugWeapon(
	mechId: string,
	weaponId: string
): any

	local weapon: any =
		self._mechs:GetComponent(
			mechId,
			weaponId
		)

	if
		not weapon
		or weapon.Combat == nil
	then
		return nil
	end

	local ammoMap: NumberMap =
		self._ammo

	local lastFireMap: NumberMap =
		self._lastFire

	return {
		Config =
			Definitions.Resolve(
				weapon.Combat
			),

		Ammo =
			ammoMap[runtimeKey(mechId, weaponId)],

		LastFire =
			lastFireMap[runtimeKey(mechId, weaponId)],

		Power =
			self._power:GetPowerState(
				mechId,
				weaponId
			),

		Temperature =
			self._heat:GetTemperature(
				mechId,
				weaponId
			),
	}
end

--------------------------------------------------
-- RETURN
--------------------------------------------------

return Combat