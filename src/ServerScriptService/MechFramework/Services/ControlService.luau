--!strict
-- Abstract actions bind to any number of physical components; clients only submit intent.
local Control: any = { _groups = {}, _held = {}, _sequence = {}, _lastDispatch = {} }
local Control = { _groups = {}, _held = {}, _sequence = {}, _lastDispatch = {} }

function Control:Init(container)
	self._mechs=container:Get("MechService"); self._combat=container:Get("CombatService")
	self._remote=game.ReplicatedStorage.MechFramework.Remotes.Events.RequestControlAction
end

function Control:SetBindings(userId: number, mechId: string, groups: {[string]: {string}}): boolean
	if not self._mechs:IsOwner(userId,mechId) then return false end
	local clean={}
	for action,ids in groups do
		if type(action)=="string" and #action<=40 and type(ids)=="table" then
			clean[action]={}
			for _,id in ids do if type(id)=="string" and #id<=80 and self._mechs:GetComponent(mechId,id) then table.insert(clean[action],id) end end
		end
	end
	self._groups[mechId]=clean; return true
end

function Control:_activate(userId: number, mechId: string, action: string, aim: any)
	for _,id in (self._groups[mechId] or {})[action] or {} do
		local component=self._mechs:GetComponent(mechId,id)
		if component and not component.Destroyed then
			if component.Combat then self._combat:Fire(userId,mechId,id,aim)
			else component.Metadata.ControlState=component.Metadata.ControlState or {}; component.Metadata.ControlState[action]=true end
		end
	end
end

function Control:Dispatch(player: Player, packet: any)
	if type(packet)~="table" or type(packet.MechId)~="string" or #packet.MechId>80 or type(packet.Action)~="string" or #packet.Action>40 or type(packet.Active)~="boolean" then return end
	if not self._mechs:IsOwner(player.UserId,packet.MechId) then return end
	local seq=tonumber(packet.Sequence) or 0; local ownerKey=tostring(player.UserId)..":"..packet.MechId
	if seq <= (self._sequence[ownerKey] or -1) then return end
	local now=os.clock(); if now-(self._lastDispatch[player.UserId] or 0)<1/120 then return end
	self._sequence[ownerKey]=seq; self._lastDispatch[player.UserId]=now
	local key=ownerKey..":"..packet.Action
	self._held[key]=packet.Active and {UserId=player.UserId,MechId=packet.MechId,Action=packet.Action,Aim=packet.Aim} or nil
	if packet.Active then self:_activate(player.UserId,packet.MechId,packet.Action,packet.Aim) end
end

function Control:Start()
	self._remote.OnServerEvent:Connect(function(player,packet) self:Dispatch(player,packet) end)
	RunService.Heartbeat:Connect(function()
		for _,state in self._held do if self._mechs:IsOwner(state.UserId,state.MechId) then self:_activate(state.UserId,state.MechId,state.Action,state.Aim) end end
	end)
end
function Control:DebugGroups(mechId: string) return self._groups[mechId] or {} end
return Control