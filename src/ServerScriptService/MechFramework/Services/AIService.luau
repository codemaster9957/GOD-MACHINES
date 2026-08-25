--!strict
-- Shared-component mech AI: sensing, navigation intent, range selection, aiming, retreat, and damage response.
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Definitions = require(game.ReplicatedStorage.MechFramework.Shared.WeaponDefinitions)
local AI: any = {_agents = {}, _accumulator = 0}

local function modelFor(mechId: string): Model?
	local root = Workspace:FindFirstChild("MechAssemblies"); local model = root and root:FindFirstChild(mechId)
	return if model and model:IsA("Model") then model else nil
end
local function center(mechId: string): Vector3?
	local model = modelFor(mechId); if not model then return nil end
	local cf = model:GetBoundingBox(); return cf.Position
end

function AI:Init(container: any)
	self._matches = container:Get("MatchService"); self._mechs = container:Get("MechService"); self._combat = container:Get("CombatService")
end

function AI:Start()
	local spawned = self._matches:GetSignal("ParticipantSpawned")
	if spawned then spawned:Connect(function(payload: any) if payload.IsAI then self:Register(payload.MechId) end end) end
	RunService.Heartbeat:Connect(function(dt: number) self._accumulator += dt; if self._accumulator >= 0.2 then local step = self._accumulator; self._accumulator = 0; self:Step(step) end end)
end

function AI:Register(mechId: string, profile: any?)
	self._agents[mechId] = {MechId = mechId, Profile = profile or {}, Target = nil, State = "Acquire", LastThink = 0}
end
function AI:Unregister(mechId: string) self._agents[mechId] = nil end

function AI:_target(agent: any): string?
	local match = self._matches:GetForMech(agent.MechId); local origin = center(agent.MechId); if not match or not origin then return nil end
	local best, bestScore = nil, math.huge
	for mechId in match.Mechs do
		if self._matches:IsHostile(agent.MechId, mechId) then
			local p = center(mechId); local mech = self._mechs:Get(mechId)
			if p and mech and not mech.Metadata.CombatDisabled then
				local distance = (p - origin).Magnitude; local exposed = tonumber(mech.Metadata.ThreatExposure) or 0
				local score = distance - exposed * 20
				if score < bestScore then best, bestScore = mechId, score end
			end
		end
	end
	return best
end

function AI:_weapons(mech: any): ({any}, number)
	local weapons, preferred = {}, 100
	for id, component in mech.Components do
		if component.Combat and not component.Destroyed and not (component.Metadata and (component.Metadata.Detached or component.Metadata.Jammed)) then
			local config = Definitions.Resolve(component.Combat)
			if config then table.insert(weapons, {Id = id, Config = config}); preferred = math.max(preferred, (tonumber(config.Range) or 200) * 0.65) end
		end
	end
	return weapons, preferred
end

function AI:_healthRatio(mech: any): number
	local health, maximum = 0, 0
	for _, c in mech.Components do if not c.Destroyed then health += math.max(0, tonumber(c.Health) or 0); maximum += math.max(1, tonumber(c.MaxHealth) or 1) end end
	return if maximum > 0 then health / maximum else 0
end

function AI:_moveIntent(agent: any, direction: Vector3, retreat: boolean)
	local model = modelFor(agent.MechId); if not model then return end
	model:SetAttribute("AIState", if retreat then "Retreat" else "Reposition")
	model:SetAttribute("MoveX", direction.X); model:SetAttribute("MoveZ", direction.Z)
	-- Mobility controllers consume this intent; a small assembly force keeps generic physics mechs responsive.
	local root = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
	if root and not root.Anchored then root:ApplyImpulse(direction * root.AssemblyMass * (retreat and 10 or 5)) end
end

function AI:_think(agent: any)
	local mech = self._mechs:Get(agent.MechId); local origin = center(agent.MechId)
	if not mech or not origin or mech.Metadata.CombatDisabled then self:Unregister(agent.MechId); return end
	if not agent.Target or not self._matches:IsHostile(agent.MechId, agent.Target) then agent.Target = self:_target(agent) end
	if not agent.Target then agent.State = "Acquire"; return end
	local targetPosition = center(agent.Target); if not targetPosition then agent.Target = nil; return end
	local offset = targetPosition - origin; local distance = offset.Magnitude; if distance < 0.1 then return end
	local weapons, preferred = self:_weapons(mech); local health = self:_healthRatio(mech)
	local retreat = health < (tonumber(agent.Profile.RetreatHealth) or 0.3) or #weapons == 0
	if retreat then agent.State = "Retreat"; self:_moveIntent(agent, -offset.Unit, true)
	elseif distance > preferred then agent.State = "CloseRange"; self:_moveIntent(agent, offset.Unit, false)
	elseif distance < preferred * 0.35 then agent.State = "CreateDistance"; self:_moveIntent(agent, -offset.Unit, false)
	else agent.State = "Engage" end
	for _, weapon in weapons do
		local range = tonumber(weapon.Config.Range) or 500
		if distance <= range then self._combat:Fire(mech.Owner, agent.MechId, weapon.Id, {Direction = offset.Unit}) end
	end
	local model = modelFor(agent.MechId); if model then model:SetAttribute("AITarget", agent.Target); model:SetAttribute("AIState", agent.State); model:SetAttribute("SystemHealth", health) end
end

function AI:Step(_dt: number)
	for _, agent in self._agents do self:_think(agent) end
end

return AI