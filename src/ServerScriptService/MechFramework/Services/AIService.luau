--!strict
-- Shared-component mech AI. AI obeys the same control groups, drivetrain, propulsion, power and aero rules as players.

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Definitions = require(game.ReplicatedStorage.MechFramework.Shared.WeaponDefinitions)

local AI: any = { _agents = {}, _accumulator = 0 }

local MOVEMENT_ACTIONS = {
	"ThrottleForward","ThrottleReverse","SteerLeft","SteerRight",
	"VerticalUp","VerticalDown","PitchUp","PitchDown","YawLeft","YawRight","RollLeft","RollRight","Brake",
}

local function modelFor(mechId: string): Model?
	local root = Workspace:FindFirstChild("MechAssemblies")
	local model = root and root:FindFirstChild(mechId)
	return if model and model:IsA("Model") then model else nil
end

local function center(mechId: string): Vector3?
	local model = modelFor(mechId)
	if not model then return nil end
	local cf = model:GetBoundingBox()
	return cf.Position
end

function AI:Init(container: any)
	self._matches = container:Get("MatchService")
	self._mechs = container:Get("MechService")
	self._combat = container:Get("CombatService")
	self._control = container:Get("ControlService")
end

function AI:Start()
	local spawned = self._matches:GetSignal("ParticipantSpawned")
	if spawned then
		spawned:Connect(function(payload: any)
			if payload.IsAI then self:Register(payload.MechId) end
		end)
	end
	local ended = self._matches:GetSignal("BattleEnded")
	if ended then
		ended:Connect(function(payload: any)
			local match = self._matches:Get(payload.MatchId)
			if match then
				for mechId in pairs(match.Mechs or {}) do if self._agents[mechId] then self:Unregister(mechId) end end
			end
		end)
	end
	RunService.Heartbeat:Connect(function(dt: number)
		self._accumulator += dt
		if self._accumulator < 0.2 then return end
		local step = self._accumulator
		self._accumulator = 0
		self:Step(step)
	end)
end

function AI:Register(mechId: string, profile: any?)
	local mech = self._mechs:Get(mechId)
	if not mech then return end
	self._control:GenerateDefaultBindings(mech.Owner, mechId, true)
	self._agents[mechId] = { MechId=mechId, Profile=profile or {}, Target=nil, State="Acquire", LastThink=0 }
end

function AI:Unregister(mechId: string)
	self._control:ClearMech(mechId)
	self._agents[mechId] = nil
end

function AI:_target(agent: any): string?
	local match = self._matches:GetForMech(agent.MechId)
	local origin = center(agent.MechId)
	if not match or not origin then return nil end
	local best, bestScore = nil, math.huge
	for mechId in pairs(match.Mechs) do
		if self._matches:IsHostile(agent.MechId, mechId) then
			local position = center(mechId)
			local mech = self._mechs:Get(mechId)
			if position and mech and not mech.Metadata.CombatDisabled then
				local distance = (position-origin).Magnitude
				local exposed = tonumber(mech.Metadata.ThreatExposure) or 0
				local score = distance - exposed * 20
				if score < bestScore then best, bestScore = mechId, score end
			end
		end
	end
	return best
end

function AI:_weapons(mech: any): ({any}, number)
	local weapons, preferred = {}, 100
	for id, component in pairs(mech.Components) do
		if component.Combat and not component.Destroyed and not (component.Metadata and (component.Metadata.Detached or component.Metadata.Jammed)) then
			local config = Definitions.Resolve(component.Combat)
			if config then
				table.insert(weapons, {Id=id, Config=config})
				preferred = math.max(preferred, (tonumber(config.Range) or 200) * .65)
			end
		end
	end
	return weapons, preferred
end

function AI:_healthRatio(mech: any): number
	local health, maximum = 0, 0
	for _, component in pairs(mech.Components) do
		if not component.Destroyed then
			health += math.max(0, tonumber(component.Health) or 0)
			maximum += math.max(1, tonumber(component.MaxHealth) or 1)
		end
	end
	return if maximum > 0 then health / maximum else 0
end

function AI:_clearMovement(mechId: string)
	for _, action in ipairs(MOVEMENT_ACTIONS) do self._control:SetServerAction(mechId, action, false) end
end

function AI:_moveIntent(agent: any, worldDirection: Vector3, moving: boolean, retreat: boolean)
	local model = modelFor(agent.MechId)
	local root = model and model.PrimaryPart
	if not model or not root or worldDirection.Magnitude < .001 then self:_clearMovement(agent.MechId); return end
	local direction = worldDirection.Unit
	local forward = root.CFrame.LookVector:Dot(direction)
	local right = root.CFrame.RightVector:Dot(direction)
	local vertical = direction.Y

	local useReverse = moving and forward < -0.35
	local useForward = moving and not useReverse
	local steerRight = right > .12
	local steerLeft = right < -.12

	self._control:SetServerAction(agent.MechId, "ThrottleForward", useForward)
	self._control:SetServerAction(agent.MechId, "ThrottleReverse", useReverse)
	self._control:SetServerAction(agent.MechId, "SteerRight", steerRight)
	self._control:SetServerAction(agent.MechId, "SteerLeft", steerLeft)
	self._control:SetServerAction(agent.MechId, "YawRight", steerRight)
	self._control:SetServerAction(agent.MechId, "YawLeft", steerLeft)
	self._control:SetServerAction(agent.MechId, "RollRight", steerRight)
	self._control:SetServerAction(agent.MechId, "RollLeft", steerLeft)
	self._control:SetServerAction(agent.MechId, "VerticalUp", moving and vertical > .28)
	self._control:SetServerAction(agent.MechId, "VerticalDown", moving and vertical < -.28)
	self._control:SetServerAction(agent.MechId, "PitchUp", vertical > .12)
	self._control:SetServerAction(agent.MechId, "PitchDown", vertical < -.12)
	self._control:SetServerAction(agent.MechId, "Brake", not moving)

	model:SetAttribute("AIState", if retreat then "Retreat" elseif moving then "Reposition" else "Aim")
	model:SetAttribute("MoveX", direction.X)
	model:SetAttribute("MoveZ", direction.Z)
end

function AI:_think(agent: any)
	local mech = self._mechs:Get(agent.MechId)
	local origin = center(agent.MechId)
	if not mech or not origin or mech.Metadata.CombatDisabled then self:Unregister(agent.MechId); return end

	if not agent.Target or not self._matches:IsHostile(agent.MechId, agent.Target) then agent.Target = self:_target(agent) end
	if not agent.Target then agent.State="Acquire"; self:_clearMovement(agent.MechId); return end
	local targetPosition = center(agent.Target)
	if not targetPosition then agent.Target=nil; self:_clearMovement(agent.MechId); return end

	local offset = targetPosition-origin
	local distance = offset.Magnitude
	if distance < .1 then self:_clearMovement(agent.MechId); return end
	local weapons, preferred = self:_weapons(mech)
	local health = self:_healthRatio(mech)
	local retreat = health < (tonumber(agent.Profile.RetreatHealth) or .3) or #weapons == 0

	if retreat then
		agent.State="Retreat"
		self:_moveIntent(agent, -offset.Unit, true, true)
	elseif distance > preferred then
		agent.State="CloseRange"
		self:_moveIntent(agent, offset.Unit, true, false)
	elseif distance < preferred*.35 then
		agent.State="CreateDistance"
		self:_moveIntent(agent, -offset.Unit, true, false)
	else
		agent.State="Engage"
		self:_moveIntent(agent, offset.Unit, false, false)
	end

	for _, weapon in ipairs(weapons) do
		local range = tonumber(weapon.Config.Range) or 500
		if distance <= range then self._combat:Fire(mech.Owner,agent.MechId,weapon.Id,{Direction=offset.Unit}) end
	end
	local model = modelFor(agent.MechId)
	if model then
		model:SetAttribute("AITarget",agent.Target)
		model:SetAttribute("AIState",agent.State)
		model:SetAttribute("SystemHealth",health)
	end
end

function AI:Step(_dt: number)
	local ids = {}
	for mechId in pairs(self._agents) do table.insert(ids, mechId) end
	for _, mechId in ipairs(ids) do
		local agent = self._agents[mechId]
		if agent then self:_think(agent) end
	end
end

return AI