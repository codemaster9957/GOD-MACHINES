--!strict
-- One server-owned resolver handles every data-driven weapon delivery mode.
-- Hits carry real damage type/penetration context and guided projectiles home toward a server-acquired target.

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local CombatMath = require(game.ReplicatedStorage.MechFramework.Shared.CombatMath)

type ProjectileData = {
	Position: Vector3,
	Velocity: Vector3,
	Life: number,
	Config: any,
	Context: any,
	Target: BasePart?,
}

type ProjectileMap = {[number]: ProjectileData}

local Projectile: any = {
	_active = {} :: ProjectileMap,
	_nextId = 0,
	_damage = nil,
	_matches = nil,
}

function Projectile:Init(container: any)
	self._damage = container:Get("DamageService")
	self._matches = if container:Has("MatchService") then container:Get("MatchService") else nil
end

local function componentFrom(part: Instance?): (string?, string?)
	local current: Instance? = part
	while current do
		local mechId = current:GetAttribute("MechId")
		local componentId = current:GetAttribute("ComponentId")
		if type(mechId)=="string" and type(componentId)=="string" then return mechId,componentId end
		current=current.Parent
	end
	return nil,nil
end

local function getIgnoreList(context: any): {Instance}
	local out: {Instance} = {}
	if context and typeof(context.Ignore)=="Instance" then table.insert(out,context.Ignore) end
	return out
end

local function damageType(config: any): string
	if type(config.DamageType)=="string" and config.DamageType~="" then return config.DamageType end
	local category=tostring(config.Category or "")
	local mode=tostring(config.Mode or "")
	if mode=="Melee" then return "Melee" end
	if category=="Flamethrower" then return "Heat" end
	if category=="Laser" or category=="Plasma" then return "Energy" end
	if (tonumber(config.ExplosionRadius) or 0)>0 or category=="Missile" or category=="Rocket" then return "Explosive" end
	return "Kinetic"
end

function Projectile:_apply(hit: RaycastResult, config: any, context: any)
	local mechId,componentId=componentFrom(hit.Instance)
	local damage=math.max(0,tonumber(config.Damage) or 0)
	local kind=damageType(config)
	local penetration=math.max(0,tonumber(config.Penetration) or 0)
	local directKey: string? = nil

	if mechId and componentId and mechId~=context.MechId and damage>0 then
		directKey=mechId..":"..componentId
		self._damage:Apply(mechId,componentId,damage,{
			Source=context.WeaponId, Owner=context.UserId, Position=hit.Position,
			DamageType=kind, Penetration=penetration,
		})
	end

	local radius=math.max(0,tonumber(config.ExplosionRadius) or 0)
	if radius<=0 then return end
	local overlap=OverlapParams.new()
	overlap.FilterType=Enum.RaycastFilterType.Exclude
	overlap.FilterDescendantsInstances=getIgnoreList(context)
	local seen: {[string]: boolean} = {}
	if directKey then seen[directKey]=true end

	for _,part in ipairs(Workspace:GetPartBoundsInRadius(hit.Position,radius,overlap)) do
		local targetMech,targetComponent=componentFrom(part)
		if not targetMech or not targetComponent or targetMech==context.MechId then continue end
		local key=targetMech..":"..targetComponent
		if seen[key] then continue end
		seen[key]=true
		local distance=(part.Position-hit.Position).Magnitude
		local falloff=CombatMath.Falloff(distance,radius)
		local amount=damage*falloff
		if amount>0 then
			self._damage:Apply(targetMech,targetComponent,amount,{
				Source=context.WeaponId, Owner=context.UserId, Explosion=true, Position=hit.Position,
				DamageType="Explosive", Penetration=penetration*.35,
			})
		end
	end
end

function Projectile:_cast(origin: Vector3, direction: Vector3, distance: number, config: any, context: any): boolean
	if distance<=0 or direction.Magnitude<=.0001 then return false end
	local unit=direction.Unit
	local params=RaycastParams.new()
	params.FilterType=Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances=getIgnoreList(context)
	local remaining=distance
	local start=origin
	local penetration=math.max(0,tonumber(config.Penetration) or 0)

	while remaining>.001 do
		local hit=Workspace:Raycast(start,unit*remaining,params)
		if not hit then return false end
		self:_apply(hit,config,context)
		local resistance=1
		if hit.Instance:IsA("BasePart") then resistance=math.max(1,hit.Instance.Size.Magnitude) end
		if penetration<resistance then return true end
		penetration-=resistance
		local travelled=(hit.Position-start).Magnitude
		remaining-=travelled+.05
		start=hit.Position+unit*.05
	end
	return true
end

function Projectile:_acquireGuidedTarget(origin: Vector3, direction: Vector3, range: number, context: any): BasePart?
	local params=RaycastParams.new()
	params.FilterType=Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances=getIgnoreList(context)
	local hit=Workspace:Raycast(origin,direction.Unit*range,params)
	if not hit or not hit.Instance:IsA("BasePart") then return nil end
	local mechId=select(1,componentFrom(hit.Instance))
	if not mechId or mechId==context.MechId then return nil end
	if self._matches and self._matches.GetForMech and self._matches:GetForMech(context.MechId) then
		if not self._matches:IsHostile(context.MechId,mechId) then return nil end
	end
	return hit.Instance
end

local function steerToward(current: Vector3, desired: Vector3, maxRadians: number): Vector3
	if current.Magnitude<.001 or desired.Magnitude<.001 then return current end
	local a=current.Unit
	local b=desired.Unit
	local dot=math.clamp(a:Dot(b),-1,1)
	local angle=math.acos(dot)
	if angle<=maxRadians or angle<1e-5 then return b*current.Magnitude end
	local alpha=math.clamp(maxRadians/angle,0,1)
	local blended=a:Lerp(b,alpha)
	if blended.Magnitude<.001 then return current end
	return blended.Unit*current.Magnitude
end

function Projectile:Fire(origin: Vector3, direction: Vector3, config: any, context: any): boolean
	if not CombatMath.IsFiniteVector(direction) or direction.Magnitude<.9 then return false end
	local pellets=math.clamp(math.floor(tonumber(config.Pellets) or 1),1,64)
	local spread=math.max(0,tonumber(config.Spread) or 0)
	local range=math.max(0,tonumber(config.Range) or 1000)
	if range<=0 then return false end
	local baseSeed=math.floor(tonumber(context and context.ShotSeed) or self._nextId+1)

	for pellet=1,pellets do
		local dir=CombatMath.SpreadDirection(direction,spread,baseSeed+pellet*104729)
		local mode=tostring(config.Mode or "Projectile")
		if mode=="Hitscan" or mode=="Melee" or mode=="Stream" then
			self:_cast(origin,dir,range,config,context)
		else
			local projectileSpeed=math.max(1,tonumber(config.ProjectileSpeed) or 500)
			self._nextId+=1
			local target: BasePart? = nil
			if mode=="Guided" then target=self:_acquireGuidedTarget(origin,dir,range,context) end
			self._active[self._nextId]={
				Position=origin, Velocity=dir*projectileSpeed, Life=range/projectileSpeed,
				Config=config, Context=context, Target=target,
			}
		end
	end
	return true
end

function Projectile:Start()
	RunService.Heartbeat:Connect(function(dt: number)
		dt=math.min(dt,.1)
		for id,projectile in pairs(self._active) do
			projectile.Life-=dt
			if projectile.Life<=0 then self._active[id]=nil; continue end

			if tostring(projectile.Config.Mode)=="Guided" and projectile.Target and projectile.Target.Parent then
				local desired=projectile.Target.Position-projectile.Position
				if desired.Magnitude>.2 then
					local degreesPerSecond=math.max(15,tonumber(projectile.Config.GuidedTurnRate) or tonumber(projectile.Config.SeekerStrength) or 135)
					projectile.Velocity=steerToward(projectile.Velocity,desired,math.rad(degreesPerSecond)*dt)
				end
			else
				projectile.Target=nil
			end

			local gravityScale=tonumber(projectile.Config.GravityScale) or 0
			projectile.Velocity+=Vector3.new(0,-Workspace.Gravity*gravityScale,0)*dt
			local step=projectile.Velocity*dt
			local distance=step.Magnitude
			if distance<=.0001 then continue end
			if self:_cast(projectile.Position,step,distance,projectile.Config,projectile.Context) then
				self._active[id]=nil
			else
				projectile.Position+=step
			end
		end
	end)
end

function Projectile:DebugState(): {ActiveProjectiles: number, GuidedProjectiles: number}
	local count,guided=0,0
	for _,projectile in pairs(self._active) do
		count+=1
		if tostring(projectile.Config.Mode)=="Guided" then guided+=1 end
	end
	return {ActiveProjectiles=count,GuidedProjectiles=guided}
end

return Projectile
