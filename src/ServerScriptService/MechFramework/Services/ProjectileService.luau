--!strict
-- One server-owned resolver handles every data-driven delivery mode.

--------------------------------------------------
-- SERVICES
--------------------------------------------------

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

--------------------------------------------------
-- TYPES
--------------------------------------------------

type ProjectileData = {
	Position: Vector3,
	Velocity: Vector3,
	Life: number,
	Config: any,
	Context: any,
}

type ProjectileMap = {
	[number]: ProjectileData,
}

--------------------------------------------------
-- SERVICE
--------------------------------------------------

local Projectile: any = {
	_active = {} :: ProjectileMap,
	_nextId = 0,

	_damage = nil,
}

--------------------------------------------------
-- INIT
--------------------------------------------------

function Projectile:Init(container: any)
	self._damage =
		container:Get("DamageService")
end

--------------------------------------------------
-- FIND COMPONENT FROM INSTANCE
--------------------------------------------------

local function componentFrom(
	part: Instance?
): (string?, string?)

	local current: Instance? = part

	while current do
		local mechId =
			current:GetAttribute("MechId")

		local componentId =
			current:GetAttribute("ComponentId")

		if
			type(mechId) == "string"
			and type(componentId) == "string"
		then
			return mechId, componentId
		end

		current = current.Parent
	end

	return nil, nil
end

--------------------------------------------------
-- BUILD IGNORE LIST
--------------------------------------------------

local function getIgnoreList(
	context: any
): {Instance}

	local ignoreList: {Instance} = {}

	if
		context
		and typeof(context.Ignore) == "Instance"
	then
		table.insert(
			ignoreList,
			context.Ignore
		)
	end

	return ignoreList
end

--------------------------------------------------
-- APPLY HIT
--------------------------------------------------

function Projectile:_apply(
	hit: RaycastResult,
	config: any,
	context: any
)

	local mechId, componentId =
		componentFrom(
			hit.Instance
		)

	local damage =
		tonumber(config.Damage) or 0

	--------------------------------------------------
	-- DIRECT DAMAGE
	--------------------------------------------------

	if
		mechId
		and componentId
		and mechId ~= context.MechId
	then

		self._damage:Apply(
			mechId,
			componentId,
			damage,
			{
				Source =
					context.WeaponId,

				Owner =
					context.UserId,

				Position =
					hit.Position,
			}
		)
	end

	--------------------------------------------------
	-- EXPLOSION
	--------------------------------------------------

	local radius =
		tonumber(
			config.ExplosionRadius
		) or 0

	if radius <= 0 then
		return
	end

	local overlap =
		OverlapParams.new()

	overlap.FilterType =
		Enum.RaycastFilterType.Exclude

	overlap.FilterDescendantsInstances =
		getIgnoreList(context)

	--------------------------------------------------
	-- PREVENT DUPLICATE COMPONENT DAMAGE
	--------------------------------------------------

	local seen: {[string]: boolean} = {}

	local nearbyParts =
		Workspace:GetPartBoundsInRadius(
			hit.Position,
			radius,
			overlap
		)

	for _, part in ipairs(nearbyParts) do

		local targetMech, targetComponent =
			componentFrom(part)

		if
			not targetMech
			or not targetComponent
		then
			continue
		end

		if targetMech == context.MechId then
			continue
		end

		local key =
			targetMech
			.. ":"
			.. targetComponent

		if seen[key] then
			continue
		end

		seen[key] = true

		--------------------------------------------------
		-- DISTANCE FALLOFF
		--------------------------------------------------

		local distance =
			(
				part.Position
				- hit.Position
			).Magnitude

		local falloff =
			1
		- math.clamp(
			distance / radius,
			0,
			1
		)

		local explosionDamage =
			damage * falloff

		if explosionDamage <= 0 then
			continue
		end

		self._damage:Apply(
			targetMech,
			targetComponent,
			explosionDamage,
			{
				Source =
					context.WeaponId,

				Owner =
					context.UserId,

				Explosion =
					true,

				Position =
					hit.Position,
			}
		)
	end
end

--------------------------------------------------
-- RAYCAST / PENETRATION
--------------------------------------------------

function Projectile:_cast(
	origin: Vector3,
	direction: Vector3,
	distance: number,
	config: any,
	context: any
): boolean

	if distance <= 0 then
		return false
	end

	if direction.Magnitude <= 0.0001 then
		return false
	end

	local unitDirection =
		direction.Unit

	local params =
		RaycastParams.new()

	params.FilterType =
		Enum.RaycastFilterType.Exclude

	params.FilterDescendantsInstances =
		getIgnoreList(context)

	--------------------------------------------------
	-- PENETRATION STATE
	--------------------------------------------------

	local remaining =
		distance

	local start =
		origin

	local penetration =
		math.max(
			0,
			tonumber(config.Penetration) or 0
		)

	while remaining > 0.001 do

		local hit =
			Workspace:Raycast(
				start,
				unitDirection * remaining,
				params
			)

		if not hit then
			return false
		end

		--------------------------------------------------
		-- APPLY HIT
		--------------------------------------------------

		self:_apply(
			hit,
			config,
			context
		)

		--------------------------------------------------
		-- CALCULATE RESISTANCE
		--------------------------------------------------

		local resistance = 1

		if hit.Instance:IsA("BasePart") then
			resistance =
				math.max(
					1,
					hit.Instance.Size.Magnitude
				)
		end

		--------------------------------------------------
		-- STOP IF PENETRATION IS TOO LOW
		--------------------------------------------------

		if penetration < resistance then
			return true
		end

		penetration -= resistance

		--------------------------------------------------
		-- CONTINUE BEYOND HIT
		--------------------------------------------------

		local travelled =
			(
				hit.Position
				- start
			).Magnitude

		remaining -=
			travelled + 0.05

		start =
			hit.Position
			+ unitDirection * 0.05
	end

	return true
end

--------------------------------------------------
-- SPREAD DIRECTION
--------------------------------------------------

local function spreadDirection(
	direction: Vector3,
	spreadRadians: number
): Vector3

	if spreadRadians <= 0 then
		return direction.Unit
	end

	local base =
		CFrame.lookAt(
			Vector3.zero,
			direction.Unit
		)

	local pitch =
		(math.random() - 0.5)
		* spreadRadians

	local yaw =
		(math.random() - 0.5)
		* spreadRadians

	return (
		base
			* CFrame.Angles(
				pitch,
				yaw,
				0
			)
	).LookVector
end

--------------------------------------------------
-- FIRE
--------------------------------------------------

function Projectile:Fire(
	origin: Vector3,
	direction: Vector3,
	config: any,
	context: any
): boolean

	--------------------------------------------------
	-- VALIDATE DIRECTION
	--------------------------------------------------

	if direction.Magnitude < 0.9 then
		return false
	end

	--------------------------------------------------
	-- WEAPON CONFIG
	--------------------------------------------------

	local pellets =
		math.clamp(
			math.floor(
				tonumber(config.Pellets)
				or 1
			),
			1,
			64
		)

	local spread =
		math.rad(
			tonumber(config.Spread)
			or 0
		)

	local range =
		math.max(
			0,
			tonumber(config.Range)
			or 1000
		)

	--------------------------------------------------
	-- FIRE PELLETS
	--------------------------------------------------

	for _ = 1, pellets do

		local dir =
			spreadDirection(
				direction,
				spread
			)

		--------------------------------------------------
		-- INSTANT DELIVERY MODES
		--------------------------------------------------

		if
			config.Mode == "Hitscan"
			or config.Mode == "Melee"
			or config.Mode == "Stream"
		then

			self:_cast(
				origin,
				dir,
				range,
				config,
				context
			)

			--------------------------------------------------
			-- PHYSICAL PROJECTILE
			--------------------------------------------------

		else
			local projectileSpeed =
				math.max(
					1,
					tonumber(
						config.ProjectileSpeed
					) or 500
				)

			local nextId: number = self._nextId
			nextId += 1
			self._nextId = nextId

			local projectileId =
				self._nextId

			local projectile: ProjectileData = {
				Position =
					origin,

				Velocity =
					dir * projectileSpeed,

				Life =
					range / projectileSpeed,

				Config =
					config,

				Context =
					context,
			}

			local active: ProjectileMap = self._active
			active[projectileId] = projectile
		end
	end

	return true
end

--------------------------------------------------
-- START PROJECTILE SIMULATION
--------------------------------------------------

function Projectile:Start()
	RunService.Heartbeat:Connect(function(dt: number)

		--------------------------------------------------
		-- PREVENT HUGE PHYSICS STEPS
		--------------------------------------------------

		dt = math.min(dt, 0.1)

		local active: ProjectileMap =
			self._active

		--------------------------------------------------
		-- UPDATE PROJECTILES
		--------------------------------------------------

		for id, projectile in pairs(active) do

			--------------------------------------------------
			-- LIFE
			--------------------------------------------------

			projectile.Life -= dt

			if projectile.Life <= 0 then
				active[id] = nil
				continue
			end

			--------------------------------------------------
			-- GRAVITY
			--------------------------------------------------

			local gravityScale =
				tonumber(
					projectile.Config.GravityScale
				) or 0

			local gravity =
				Vector3.new(
					0,
					-Workspace.Gravity * gravityScale,
					0
				)

			projectile.Velocity +=
				gravity * dt

			--------------------------------------------------
			-- MOVEMENT STEP
			--------------------------------------------------

			local step =
				projectile.Velocity * dt

			local stepDistance =
				step.Magnitude

			if stepDistance <= 0.0001 then
				continue
			end

			--------------------------------------------------
			-- COLLISION
			--------------------------------------------------

			local hit =
				self:_cast(
					projectile.Position,
					step,
					stepDistance,
					projectile.Config,
					projectile.Context
				)

			if hit then
				active[id] = nil
				continue
			end

			--------------------------------------------------
			-- ADVANCE
			--------------------------------------------------

			projectile.Position += step
		end
	end)
end

--------------------------------------------------
-- DEBUG STATE
--------------------------------------------------

function Projectile:DebugState(): {
	ActiveProjectiles: number,
	}
	local count = 0

	local active: ProjectileMap =
		self._active

	for _ in pairs(active) do
		count += 1
	end

	return {
		ActiveProjectiles = count,
	}
end

--------------------------------------------------
-- RETURN
--------------------------------------------------

return Projectile