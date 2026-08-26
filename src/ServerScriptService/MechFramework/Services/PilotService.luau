--!strict
-- Owns edit/test transitions, seat authority, remote-control authority and compact blueprint actions.

local Players=game:GetService("Players")
local Workspace=game:GetService("Workspace")
local RunService=game:GetService("RunService")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local PresetBlueprints=require(ReplicatedStorage.MechFramework.Shared.PresetBlueprints)
local Pilot:any={_seatPilots={},_lastScan=0}

local function clone(value:any):any
	if type(value)~="table" then return value end
	local out={}; for key,item in pairs(value) do out[key]=clone(item) end; return out
end
local function assemblyModel(mechId:string):Model?
	local root=Workspace:FindFirstChild("MechAssemblies"); local model=root and root:FindFirstChild(mechId)
	return if model and model:IsA("Model") then model else nil
end
local function rootParts(model:Model):{BasePart}
	local out={}; for _,descendant in ipairs(model:GetDescendants()) do if descendant:IsA("BasePart") and descendant:GetAttribute("ComponentRoot")==true then table.insert(out,descendant) end end; return out
end
local function componentCount(components:any):number local count=0; for _ in pairs(components or {}) do count+=1 end; return count end
local function neutralizeModel(model:Model,ejectSeats:boolean)
	for _,descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("VectorForce") then
			descendant.Force=Vector3.zero
		elseif descendant:IsA("LinearVelocity") then
			descendant.VectorVelocity=Vector3.zero
		elseif descendant:IsA("AngularVelocity") then
			descendant.AngularVelocity=Vector3.zero
		elseif ejectSeats and (descendant:IsA("Seat") or descendant:IsA("VehicleSeat")) and descendant.Occupant then
			descendant.Occupant.Sit=false
		end
	end
end

function Pilot:Init(container:any)
	self._mechs=container:Get("MechService")
	self._build=container:Get("BuildService")
	self._control=container:Get("ControlService")
	self._save=container:Get("SaveService")
	self._power=container:Get("PowerService")
	self._heat=container:Get("HeatService")
	self._remote=game.ReplicatedStorage.MechFramework.Remotes.Functions.RequestMachineAction
end
function Pilot:_profileReady(player:Player):boolean
	return self._save:IsReady(player.UserId) and player:GetAttribute("GMProfileReady")==true
end
function Pilot:_hasRemoteCore(mechId:string):boolean
	local mech=self._mechs:Get(mechId); if not mech then return false end
	for _,component in pairs(mech.Components) do if not component.Destroyed and component.Pilot and component.Pilot.Remote==true then return true end end; return false
end
function Pilot:_hasPilotSeat(mechId:string):boolean
	local mech=self._mechs:Get(mechId); if not mech then return false end
	for _,component in pairs(mech.Components) do if not component.Destroyed and component.Pilot and component.Pilot.Kind~="AI" and component.Pilot.Remote~=true then return true end end; return false
end

function Pilot:_setEditMode(player:Player,mechId:string,editMode:boolean):(boolean,any)
	if not self._mechs:IsOwner(player.UserId,mechId) then return false,"NotAuthorized" end
	local model=assemblyModel(mechId); if not model then return false,"MachineNotRealized" end
	self._control:ClearMech(mechId)
	-- Remove every stale actuator force before anchoring or unanchoring so previous throttle can never leak across modes.
	neutralizeModel(model,editMode)
	model:SetAttribute("EditMode",editMode)
	for _,root in ipairs(rootParts(model)) do
		root.AssemblyLinearVelocity=Vector3.zero
		root.AssemblyAngularVelocity=Vector3.zero
		root.Anchored=editMode
	end
	if editMode then
		player:SetAttribute("BuildMode",true)
		model:SetAttribute("PilotUserId",nil)
	else
		-- Prime topology/state without consuming time-based resources so electric machines respond immediately.
		self._power:Invalidate(mechId)
		self._power:Evaluate(mechId,0)
		self._heat:Invalidate(mechId)
		player:SetAttribute("ActiveMechId",mechId)
		player:SetAttribute("BuildMode",false)
		self._control:GenerateDefaultBindings(player.UserId,mechId,false)
		if self:_hasRemoteCore(mechId) then model:SetAttribute("PilotUserId",player.UserId) else model:SetAttribute("PilotUserId",nil) end
	end
	return true,{Mode=if editMode then "Edit" else "Test",MechId=mechId,RemoteControl=(not editMode) and self:_hasRemoteCore(mechId),SeatRequired=(not editMode) and not self:_hasRemoteCore(mechId)}
end

local function compactComponent(id:string,component:any,origin:CFrame):any
	local meta=component.Metadata or {}
	return {Id=id,PartType=component.PartType,LocalTransform=origin:ToObjectSpace(component.LocalTransform),Metadata={Paint=clone(meta.Paint or {}),MirrorX=meta.MirrorX==true}}
end

local function compactConnections(connections:any):any
	local out={}
	for edgeId,edge in pairs(connections or {}) do out[edgeId]={Id=edgeId,A=edge.A,B=edge.B,SocketA=edge.SocketA,SocketB=edge.SocketB,StructuralStrength=tonumber(edge.StructuralStrength) or 100} end
	return out
end

function Pilot:_blueprint(player:Player,mechId:string,name:string):(boolean,any)
	if not self:_profileReady(player) then return false,"ProfileLoading" end
	if not self._mechs:IsOwner(player.UserId,mechId) then return false,"NotAuthorized" end
	if #name<1 or #name>40 then return false,"InvalidBlueprintName" end
	local snapshot=self._mechs:Snapshot(mechId,player.UserId); local model=assemblyModel(mechId)
	if not snapshot or not model or not model.PrimaryPart then return false,"MachineNotReady" end
	local origin=model.PrimaryPart.CFrame; local components={}
	for id,component in pairs(snapshot.Components) do components[id]=compactComponent(id,component,origin) end
	local primaryId=snapshot.Metadata and snapshot.Metadata.PrimaryComponentId
	if type(primaryId)~="string" or components[primaryId]==nil then primaryId=nil end
	local blueprint={Id=name,Name=name,Components=components,Connections=compactConnections(snapshot.Connections),Controls=self._control:GetBindings(mechId),PrimaryComponentId=primaryId,SavedAt=os.time()}
	local ok,reason=self._save:SetBlueprint(player.UserId,name,blueprint)
	return ok,if ok then {Name=name,PartCount=componentCount(components)} else reason
end

function Pilot:_spawnBlueprint(player:Player,name:string):(boolean,any)
	if not self:_profileReady(player) then return false,"ProfileLoading" end
	if #name<1 or #name>40 then return false,"InvalidBlueprintName" end
	local blueprint=PresetBlueprints.Get(name)
	local isFactory=blueprint~=nil and blueprint.FactoryPreset==true
	if not blueprint then blueprint=self._save:GetBlueprint(player.UserId,name) end
	if not blueprint then return false,"BlueprintNotFound" end
	local character=player.Character; local hrp=character and character:FindFirstChild("HumanoidRootPart")
	if not hrp or not hrp:IsA("BasePart") then return false,"CharacterNotReady" end
	local spawnDistance=if isFactory then -22 else -12
	local ok,result=self._build:SpawnBlueprint(player.UserId,blueprint,hrp.CFrame*CFrame.new(0,1,spawnDistance),{BuildOrigin=true,BattleSpawn=false,FactoryPreset=isFactory,ConsumeInventory=not isFactory})
	if not ok then return false,result end
	local mechId=result; player:SetAttribute("ActiveMechId",mechId)
	if type(blueprint.Controls)=="table" then self._control:SetBindings(player.UserId,mechId,blueprint.Controls,true) else self._control:GenerateDefaultBindings(player.UserId,mechId,true) end
	return true,{MechId=mechId,Name=name,DisplayName=blueprint.DisplayName or name,FactoryPreset=isFactory}
end

function Pilot:_listBlueprints(player:Player):{any}
	local result=PresetBlueprints.List()
	for _,entry in ipairs(self._save:ListBlueprints(player.UserId)) do table.insert(result,entry) end
	return result
end

function Pilot:_scanSeats()
	local assemblies=Workspace:FindFirstChild("MechAssemblies"); if not assemblies then return end
	local seen={}
	for _,seat in ipairs(assemblies:GetDescendants()) do
		if not (seat:IsA("Seat") or seat:IsA("VehicleSeat")) or seat:GetAttribute("Role")~="PilotSeat" then continue end
		seen[seat]=true
		local occupant=seat.Occupant; local previous=self._seatPilots[seat]; local mechId=seat:GetAttribute("MechId"); local model=type(mechId)=="string" and assemblyModel(mechId) or nil
		if occupant and model and model:GetAttribute("EditMode")~=false then occupant.Sit=false; occupant=nil end
		if occupant then
			local character=occupant.Parent; local player=character and Players:GetPlayerFromCharacter(character)
			if player and type(mechId)=="string" and self._mechs:IsOwner(player.UserId,mechId) then
				if previous~=player.UserId then self._seatPilots[seat]=player.UserId; player:SetAttribute("ActiveMechId",mechId); if model then model:SetAttribute("PilotUserId",player.UserId) end; self._control:GenerateDefaultBindings(player.UserId,mechId,false) end
			elseif player then occupant.Sit=false end
		elseif previous then
			self._seatPilots[seat]=nil; local oldPlayer=Players:GetPlayerByUserId(previous)
			if type(mechId)=="string" then self._control:ClearMech(mechId); if model and not self:_hasRemoteCore(mechId) then model:SetAttribute("PilotUserId",nil) end end
			if oldPlayer then oldPlayer:SetAttribute("BuildMode",false) end
		end
	end
	for seat in pairs(self._seatPilots) do if not seen[seat] or seat.Parent==nil then self._seatPilots[seat]=nil end end
end

function Pilot:Start()
	if not self._remote:IsA("RemoteFunction") then error("[PilotService] RequestMachineAction must be RemoteFunction") end
	self._remote.OnServerInvoke=function(player,request)
		if type(request)~="table" or type(request.Action)~="string" then return false,"BadRequest" end
		local action=request.Action
		if action=="SetMode" then
			if type(request.MechId)~="string" or (request.Mode~="Edit" and request.Mode~="Test") then return false,"BadModeRequest" end; return self:_setEditMode(player,request.MechId,request.Mode=="Edit")
		elseif action=="SaveBlueprint" then
			if not self:_profileReady(player) then return false,"ProfileLoading" end
			if type(request.MechId)~="string" or type(request.Name)~="string" then return false,"BadBlueprintRequest" end; return self:_blueprint(player,request.MechId,request.Name)
		elseif action=="LoadBlueprint" then
			if not self:_profileReady(player) then return false,"ProfileLoading" end
			if type(request.Name)~="string" then return false,"BadBlueprintRequest" end; return self:_spawnBlueprint(player,request.Name)
		elseif action=="ListBlueprints" then
			if not self:_profileReady(player) then return false,"ProfileLoading" end
			return true,self:_listBlueprints(player)
		elseif action=="DeleteBlueprint" then
			if not self:_profileReady(player) then return false,"ProfileLoading" end
			if type(request.Name)~="string" then return false,"BadBlueprintRequest" end
			if PresetBlueprints.Get(request.Name) then return false,"FactoryPresetProtected" end
			local removed=self._save:DeleteBlueprint(player.UserId,request.Name); return removed,if removed then "Deleted" else "BlueprintNotFound"
		elseif action=="GetBindings" then
			if type(request.MechId)~="string" or not self._mechs:IsOwner(player.UserId,request.MechId) then return false,"NotAuthorized" end; return true,self._control:GetBindings(request.MechId)
		elseif action=="SetBindings" then
			if type(request.MechId)~="string" or type(request.Groups)~="table" then return false,"BadBindingRequest" end; local ok=self._control:SetBindings(player.UserId,request.MechId,request.Groups,true); return ok,if ok then "BindingsUpdated" else "NotAuthorized"
		elseif action=="AutoBindings" then
			if type(request.MechId)~="string" then return false,"BadBindingRequest" end; local groups=self._control:GenerateDefaultBindings(player.UserId,request.MechId,true); return groups~=nil,groups
		elseif action=="Authority" then
			if type(request.MechId)~="string" or not self._mechs:IsOwner(player.UserId,request.MechId) then return false,"NotAuthorized" end; local model=assemblyModel(request.MechId); return true,{PilotUserId=model and model:GetAttribute("PilotUserId") or nil,Remote=self:_hasRemoteCore(request.MechId),Seat=self:_hasPilotSeat(request.MechId)}
		end
		return false,"UnknownAction"
	end
	RunService.Heartbeat:Connect(function() local now=os.clock(); if now-self._lastScan<.2 then return end; self._lastScan=now; self:_scanSeats() end)
	Players.PlayerRemoving:Connect(function(player) for seat,userId in pairs(self._seatPilots) do if userId==player.UserId then self._seatPilots[seat]=nil end end end)
end

return Pilot
