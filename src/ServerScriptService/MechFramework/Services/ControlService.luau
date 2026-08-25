--!strict
-- Abstract actions bind to component groups; clients submit intent, never forces or damage.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Control: any = {
	_groups = {},
	_custom = {},
	_held = {},
	_sequence = {},
	_lastDispatch = {},
}

local VALID_ACTIONS = table.freeze({
	ThrottleForward=true, ThrottleReverse=true,
	SteerLeft=true, SteerRight=true, Brake=true,
	VerticalUp=true, VerticalDown=true,
	PitchUp=true, PitchDown=true, YawLeft=true, YawRight=true, RollLeft=true, RollRight=true,
	Primary=true, Secondary=true, Utility=true, Reload=true, Mechanism1=true, Mechanism2=true,
})

local function ownerKey(userId: number, mechId: string): string return tostring(userId) .. ":" .. mechId end
local function heldKey(userId: number, mechId: string, action: string): string return ownerKey(userId, mechId) .. ":" .. action end
local function add(groups: any, action: string, componentId: string)
	groups[action] = groups[action] or {}
	for _, existing in ipairs(groups[action]) do if existing == componentId then return end end
	table.insert(groups[action], componentId)
end

local function pilotAuthorized(userId: number, mechId: string): boolean
	local assemblies = Workspace:FindFirstChild("MechAssemblies")
	local model = assemblies and assemblies:FindFirstChild(mechId)
	return model ~= nil and model:IsA("Model") and model:GetAttribute("EditMode") == false and model:GetAttribute("PilotUserId") == userId
end

function Control:Init(container: any)
	self._mechs = container:Get("MechService")
	self._combat = container:Get("CombatService")
	self._remote = game.ReplicatedStorage.MechFramework.Remotes.Events.RequestControlAction
end

function Control:SetBindings(userId: number, mechId: string, groups: {[string]: {string}}, custom: boolean?): boolean
	if not self._mechs:IsOwner(userId, mechId) then return false end
	local clean = {}
	for action, ids in pairs(groups) do
		if VALID_ACTIONS[action] and type(ids) == "table" then
			clean[action] = {}
			local seen = {}
			for _, id in ipairs(ids) do
				if type(id) == "string" and #id <= 80 and not seen[id] and self._mechs:GetComponent(mechId, id) then
					seen[id] = true
					table.insert(clean[action], id)
				end
			end
		end
	end
	self._groups[mechId] = clean
	if custom == true then self._custom[mechId] = true end
	return true
end

function Control:GenerateDefaultBindings(userId: number, mechId: string, force: boolean?): {[string]: {string}}?
	if not self._mechs:IsOwner(userId, mechId) then return nil end
	if self._custom[mechId] and force ~= true then return self._groups[mechId] end
	local mech = self._mechs:Get(mechId)
	if not mech then return nil end
	local groups: {[string]: {string}} = {}
	for componentId, component in pairs(mech.Components) do
		if component.Destroyed then continue end
		local mobility = component.Mobility
		if mobility then
			if mobility.Drive == true or mobility.Kind == "TrackDrive" or mobility.Kind == "Drivetrain" or mobility.Kind == "OmniWheel" then
				add(groups,"ThrottleForward",componentId); add(groups,"ThrottleReverse",componentId)
			end
			if mobility.Steer == true or mobility.Kind == "Caster" or mobility.Kind == "OmniWheel" then
				add(groups,"SteerLeft",componentId); add(groups,"SteerRight",componentId)
			end
			add(groups,"Brake",componentId)
		end
		local propulsion = component.Propulsion
		if propulsion then
			if propulsion.Kind == "LiftFan" then
				add(groups,"VerticalUp",componentId); add(groups,"VerticalDown",componentId)
			else
				add(groups,"ThrottleForward",componentId); add(groups,"ThrottleReverse",componentId)
			end
			if propulsion.Kind == "Vector" then
				add(groups,"PitchUp",componentId); add(groups,"PitchDown",componentId); add(groups,"YawLeft",componentId); add(groups,"YawRight",componentId)
			end
		end
		local aero = component.Aerodynamics
		if aero then
			local axis = aero.Axis
			if axis == "Pitch" then add(groups,"PitchUp",componentId); add(groups,"PitchDown",componentId)
			elseif axis == "Yaw" then add(groups,"YawLeft",componentId); add(groups,"YawRight",componentId)
			elseif axis == "Roll" then add(groups,"RollLeft",componentId); add(groups,"RollRight",componentId) end
			if aero.Kind == "Airbrake" then add(groups,"Brake",componentId) end
		end
		if component.Combat then
			local secondary = false
			for _, action in ipairs(component.Controls or {}) do if action == "Secondary" then secondary = true end end
			add(groups, if secondary then "Secondary" else "Primary", componentId)
		end
		for _, declared in ipairs(component.Controls or {}) do if declared == "Utility" then add(groups,"Utility",componentId) end end
	end
	self._groups[mechId] = groups
	return groups
end

function Control:GetBindings(mechId: string): {[string]: {string}}
	local source = self._groups[mechId] or {}
	local out = {}
	for action, ids in pairs(source) do out[action] = table.clone(ids) end
	return out
end

function Control:_activate(userId: number, mechId: string, action: string, aim: any)
	local group = (self._groups[mechId] or {})[action] or {}
	for _, id in ipairs(group) do
		local component = self._mechs:GetComponent(mechId,id)
		if component and not component.Destroyed then
			if component.Combat and (action=="Primary" or action=="Secondary") then
				self._combat:Fire(userId,mechId,id,aim)
			else
				component.Metadata = component.Metadata or {}
				component.Metadata.ControlState = component.Metadata.ControlState or {}
				component.Metadata.ControlState[action] = true
			end
		end
	end
end

function Control:_deactivate(mechId: string, action: string)
	local group = (self._groups[mechId] or {})[action] or {}
	for _, id in ipairs(group) do
		local component=self._mechs:GetComponent(mechId,id)
		if component and component.Metadata and component.Metadata.ControlState then component.Metadata.ControlState[action]=false end
	end
end

function Control:ClearMech(mechId: string)
	for key,state in pairs(self._held) do if state.MechId==mechId then self:_deactivate(mechId,state.Action); self._held[key]=nil end end
	local mech=self._mechs:Get(mechId)
	if mech then for _,component in pairs(mech.Components) do if component.Metadata then component.Metadata.ControlState={} end end end
end

function Control:Dispatch(player: Player, packet: any)
	if type(packet)~="table" or type(packet.MechId)~="string" or #packet.MechId>80 or type(packet.Action)~="string" or not VALID_ACTIONS[packet.Action] or type(packet.Active)~="boolean" then return end
	if not self._mechs:IsOwner(player.UserId,packet.MechId) then return end
	if player:GetAttribute("ActiveMechId")~=packet.MechId then return end
	if not pilotAuthorized(player.UserId,packet.MechId) then return end
	local sequence=tonumber(packet.Sequence) or 0
	local key=ownerKey(player.UserId,packet.MechId)
	if sequence <= (self._sequence[key] or -1) then return end
	self._sequence[key]=sequence
	local now=os.clock()
	if packet.Active and now-(self._lastDispatch[player.UserId] or 0)<1/180 then return end
	self._lastDispatch[player.UserId]=now
	local actionKey=heldKey(player.UserId,packet.MechId,packet.Action)
	if packet.Active then
		self._held[actionKey]={UserId=player.UserId,MechId=packet.MechId,Action=packet.Action,Aim=packet.Aim}
		self:_activate(player.UserId,packet.MechId,packet.Action,packet.Aim)
	else
		self._held[actionKey]=nil
		self:_deactivate(packet.MechId,packet.Action)
	end
end

function Control:_cleanupPlayer(userId: number)
	self._lastDispatch[userId]=nil
	local prefix=tostring(userId)..":"
	for key,state in pairs(self._held) do if string.sub(key,1,#prefix)==prefix then self:_deactivate(state.MechId,state.Action); self._held[key]=nil end end
	for key in pairs(self._sequence) do if string.sub(key,1,#prefix)==prefix then self._sequence[key]=nil end end
end

function Control:Start()
	self._remote.OnServerEvent:Connect(function(player,packet) self:Dispatch(player,packet) end)
	Players.PlayerRemoving:Connect(function(player) self:_cleanupPlayer(player.UserId) end)
	RunService.Heartbeat:Connect(function()
		for key,state in pairs(self._held) do
			if self._mechs:IsOwner(state.UserId,state.MechId) and pilotAuthorized(state.UserId,state.MechId) then self:_activate(state.UserId,state.MechId,state.Action,state.Aim)
			else self:_deactivate(state.MechId,state.Action); self._held[key]=nil end
		end
	end)
end

function Control:DebugGroups(mechId: string) return self._groups[mechId] or {} end
return Control
