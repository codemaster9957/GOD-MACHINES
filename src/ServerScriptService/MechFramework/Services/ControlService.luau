--!strict
-- Abstract actions bind to physical components; clients only submit intent.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BindingPolicy = require(ReplicatedStorage.MechFramework.Shared.ControlBindingPolicy)

local Control: any = {
	_groups = {},
	_groupRevision = {},
	_explicitGroups = {},
	_held = {},
	_sequence = {},
	_lastDispatch = {},
}

local function ownerKey(userId: number, mechId: string): string
	return tostring(userId) .. ":" .. mechId
end

local function heldKey(userId: number, mechId: string, action: string): string
	return ownerKey(userId, mechId) .. ":" .. action
end

function Control:Init(container: any)
	self._mechs = container:Get("MechService")
	self._combat = container:Get("CombatService")
	self._remote = ReplicatedStorage.MechFramework.Remotes.Events.RequestControlAction
end

function Control:SetBindings(userId: number, mechId: string, groups: {[string]: {string}}): boolean
	if not self._mechs:IsOwner(userId, mechId) then
		return false
	end

	local clean: {[string]: {string}} = {
		Primary = {},
		Secondary = {},
	}
	for action, ids in pairs(groups) do
		if BindingPolicy.IsValidAction(action) and type(ids) == "table" then
			for _, id in ipairs(ids) do
				local component = if type(id) == "string" then self._mechs:GetComponent(mechId, id) else nil
				if component and component.Destroyed ~= true and component.Combat then
					table.insert(clean[action], id)
				end
			end
			table.sort(clean[action])
		end
	end

	local mech = self._mechs:Get(mechId)
	self._groups[mechId] = clean
	self._groupRevision[mechId] = mech and mech.Revision or 0
	self._explicitGroups[mechId] = true
	return true
end

function Control:ReconcileBindings(userId: number, mechId: string): boolean
	local mech = self._mechs:Get(mechId)
	if not mech or mech.Owner ~= userId then
		return false
	end

	if self._groupRevision[mechId] == mech.Revision and self._groups[mechId] then
		return true
	end

	local defaults = BindingPolicy.Derive(mech.Components)
	if self._explicitGroups[mechId] ~= true then
		self._groups[mechId] = defaults
		self._groupRevision[mechId] = mech.Revision
		return true
	end

	local reconciled: {[string]: {string}} = {
		Primary = {},
		Secondary = {},
	}
	local assigned: {[string]: boolean} = {}
	local existing = self._groups[mechId] or {}

	for _, action in ipairs({ "Primary", "Secondary" }) do
		for _, componentId in ipairs(existing[action] or {}) do
			local component = mech.Components[componentId]
			if component and component.Destroyed ~= true and component.Combat and not assigned[componentId] then
				table.insert(reconciled[action], componentId)
				assigned[componentId] = true
			end
		end
	end

	for _, action in ipairs({ "Primary", "Secondary" }) do
		for _, componentId in ipairs(defaults[action]) do
			if not assigned[componentId] then
				table.insert(reconciled[action], componentId)
				assigned[componentId] = true
			end
		end
		table.sort(reconciled[action])
	end

	self._groups[mechId] = reconciled
	self._groupRevision[mechId] = mech.Revision
	return true
end

function Control:_activate(userId: number, mechId: string, action: string, aim: any)
	if not BindingPolicy.IsValidAction(action) then
		return
	end
	if not self:ReconcileBindings(userId, mechId) then
		return
	end

	local group = (self._groups[mechId] or {})[action] or {}
	for _, id in ipairs(group) do
		local component = self._mechs:GetComponent(mechId, id)
		if component and not component.Destroyed and component.Combat then
			self._combat:Fire(userId, mechId, id, aim)
		end
	end
end

function Control:_deactivate(mechId: string, action: string)
	local group = (self._groups[mechId] or {})[action] or {}
	for _, id in ipairs(group) do
		local component = self._mechs:GetComponent(mechId, id)
		if component and component.Metadata and component.Metadata.ControlState then
			component.Metadata.ControlState[action] = false
		end
	end
end

function Control:Dispatch(player: Player, packet: any)
	if type(packet) ~= "table"
		or type(packet.MechId) ~= "string"
		or #packet.MechId > 80
		or type(packet.Action) ~= "string"
		or #packet.Action > 40
		or type(packet.Active) ~= "boolean"
	then
		return
	end

	if not BindingPolicy.IsValidAction(packet.Action) then
		return
	end
	if not self._mechs:IsOwner(player.UserId, packet.MechId) then
		return
	end

	local sequence = tonumber(packet.Sequence) or 0
	local key = ownerKey(player.UserId, packet.MechId)
	if sequence <= (self._sequence[key] or -1) then
		return
	end
	self._sequence[key] = sequence

	local now = os.clock()
	if packet.Active and now - (self._lastDispatch[player.UserId] or 0) < 1 / 120 then
		return
	end
	self._lastDispatch[player.UserId] = now

	local actionKey = heldKey(player.UserId, packet.MechId, packet.Action)
	if packet.Active then
		self._held[actionKey] = {
			UserId = player.UserId,
			MechId = packet.MechId,
			Action = packet.Action,
			Aim = packet.Aim,
		}
		self:_activate(player.UserId, packet.MechId, packet.Action, packet.Aim)
	else
		self._held[actionKey] = nil
		self:_deactivate(packet.MechId, packet.Action)
	end
end

function Control:_cleanupPlayer(userId: number)
	self._lastDispatch[userId] = nil
	local prefix = tostring(userId) .. ":"
	for key, state in pairs(self._held) do
		if string.sub(key, 1, #prefix) == prefix then
			self:_deactivate(state.MechId, state.Action)
			self._held[key] = nil
		end
	end
	for key in pairs(self._sequence) do
		if string.sub(key, 1, #prefix) == prefix then
			self._sequence[key] = nil
		end
	end
end

function Control:Start()
	self._remote.OnServerEvent:Connect(function(player, packet)
		self:Dispatch(player, packet)
	end)

	Players.PlayerRemoving:Connect(function(player)
		self:_cleanupPlayer(player.UserId)
	end)

	RunService.Heartbeat:Connect(function()
		for key, state in pairs(self._held) do
			if self._mechs:IsOwner(state.UserId, state.MechId) then
				self:_activate(state.UserId, state.MechId, state.Action, state.Aim)
			else
				self._held[key] = nil
			end
		end
	end)
end

function Control:DebugGroups(mechId: string)
	return self._groups[mechId] or {
		Primary = {},
		Secondary = {},
	}
end

return Control
