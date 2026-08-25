--!strict
-- Server-owned battle lifecycle for PvP/PvE, objectives, rewards and saved-blueprint deployment.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")
local Definitions = require(game.ReplicatedStorage.MechFramework.Shared.BattleDefinitions)

local Match: any = { _matches={}, _mechToMatch={}, _events={} }
local ORDER={Preparing=1,Spawning=2,Active=3,Ending=4,Results=5}

local function copy(value:any):any
	if type(value)~="table" then return value end
	local out={}; for key,item in pairs(value) do out[key]=copy(item) end; return out
end
local function countSet(set:any):number local count=0; for _ in pairs(set) do count+=1 end; return count end
local function participantId(entry:any):string return tostring(entry.UserId or entry.Id or entry.Name) end
local function modelFor(mechId:string):Model?
	local root=Workspace:FindFirstChild("MechAssemblies"); local model=root and root:FindFirstChild(mechId)
	return if model and model:IsA("Model") then model else nil
end
local function pilotSeat(model:Model): Seat?
	for _,descendant in ipairs(model:GetDescendants()) do
		if (descendant:IsA("Seat") or descendant:IsA("VehicleSeat")) and descendant:GetAttribute("Role")=="PilotSeat" then return descendant end
	end
	return nil
end

function Match:Init(container:any)
	self._mechs=container:Get("MechService")
	self._build=container:Get("BuildService")
	self._save=container:Get("SaveService")
	self._progression=container:Get("ProgressionService")
	self._destruction=container:Get("DestructionService")
	self._control=container:Get("ControlService")
	for _,name in ipairs({"StateChanged","ObjectiveChanged","ParticipantSpawned","BattleEnded"}) do self._events[name]=Instance.new("BindableEvent") end
end

function Match:Start()
	local disabled=self._destruction:GetSignal("MechDisabled")
	if disabled then disabled:Connect(function(payload:any) self:EliminateMech(payload.MechId,"Disabled") end) end
	Players.PlayerRemoving:Connect(function(player) self:HandleDisconnect(player.UserId) end)
end
function Match:GetSignal(name:string):RBXScriptSignal? local event=self._events[name]; return event and event.Event or nil end
function Match:_emit(name:string,payload:any) local event=self._events[name]; if event then event:Fire(payload) end end
function Match:_setState(match:any,state:string)
	assert(Definitions.States[state],"Unknown battle state")
	local previous=match.State
	if previous and ORDER[state]<ORDER[previous] then return end
	match.State=state; match.StateChangedAt=os.clock(); self:_emit("StateChanged",{MatchId=match.Id,Previous=previous,State=state})
end

function Match:Create(modeName:string,options:any?):(boolean,any)
	local mode=Definitions.ResolveMode(modeName); if not mode then return false,"UnknownMode" end
	options=options or {}; local id=HttpService:GenerateGUID(false); local arena=copy(Definitions.Arenas[options.Arena or "AdaptiveOpenField"])
	self._matches[id]={Id=id,ModeName=modeName,Mode=mode,State="Preparing",CreatedAt=os.clock(),Participants={},Teams={},Alive={},Eliminated={},Mechs={},Objectives={},Arena=arena,Options=copy(options),Rewarded={},Hazards=copy(options.Hazards or arena.Hazards or {})}
	self:_emit("StateChanged",{MatchId=id,State="Preparing"}); return true,id
end

function Match:AddParticipant(matchId:string,entry:any):(boolean,string?)
	local match=self._matches[matchId]; if not match or match.State~="Preparing" then return false,"NotPreparing" end
	if type(entry)~="table" or type(entry.BlueprintId)~="string" then return false,"BlueprintRequired" end
	local id=participantId(entry); if match.Participants[id] then return false,"AlreadyJoined" end
	local participant=copy(entry); participant.Id=id; participant.Team=tonumber(entry.Team) or 1; participant.IsAI=entry.IsAI==true
	match.Participants[id]=participant; match.Teams[participant.Team]=match.Teams[participant.Team] or {}; match.Teams[participant.Team][id]=true
	return true,nil
end

function Match:_blueprint(participant:any):any?
	if participant.Blueprint then return copy(participant.Blueprint) end
	local owner=tonumber(participant.BlueprintOwnerId) or tonumber(participant.UserId); if not owner then return nil end
	return self._save:GetBlueprint(owner,participant.BlueprintId)
end

function Match:_footprint(blueprint:any):(Vector3,number)
	local minV=Vector3.new(math.huge,math.huge,math.huge); local maxV=Vector3.new(-math.huge,-math.huge,-math.huge)
	for _,component in pairs(blueprint.Components or {}) do
		local cf=component.LocalTransform
		if typeof(cf)=="CFrame" then minV=minV:Min(cf.Position); maxV=maxV:Max(cf.Position) end
	end
	if minV.X==math.huge then return Vector3.new(12,12,12),12 end
	local size=maxV-minV+Vector3.new(8,8,8); return size,math.max(size.X,size.Z)*.5
end
function Match:_spawnCFrame(match:any,index:number,total:number,blueprint:any):CFrame
	local size,footprint=self:_footprint(blueprint)
	local radius=math.clamp(math.max(match.Arena.MinRadius,footprint*total+match.Arena.Padding),match.Arena.MinRadius,match.Arena.MaxRadius)
	local angle=((index-1)/math.max(1,total))*math.pi*2; local center=match.Arena.Center
	local position=center+Vector3.new(math.cos(angle)*radius,size.Y*.5+5,math.sin(angle)*radius)
	return CFrame.lookAt(position,Vector3.new(center.X,position.Y,center.Z))
end

function Match:_activateBattlePhysics(mechId:string)
	local model=modelFor(mechId); if not model then return end
	model:SetAttribute("EditMode",false); model:SetAttribute("BattleSpawn",true)
	local primary:BasePart?=model.PrimaryPart
	for _,descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			if descendant:GetAttribute("ComponentRoot")==true then
				descendant.Anchored=false; descendant.AssemblyLinearVelocity=Vector3.zero; descendant.AssemblyAngularVelocity=Vector3.zero
				pcall(function() descendant:SetNetworkOwner(nil) end)
				primary=primary or descendant
			else
				descendant.Anchored=false
			end
		end
	end
	if primary then model.PrimaryPart=primary end
end

function Match:_hasRemoteControl(mechId:string):boolean
	local mech=self._mechs:Get(mechId); if not mech then return false end
	for _,component in pairs(mech.Components) do if not component.Destroyed and component.Pilot and component.Pilot.Remote==true then return true end end
	return false
end

function Match:_bindParticipantControls(participant:any,mechId:string,blueprint:any)
	if participant.IsAI then return end
	local userId=tonumber(participant.UserId); if not userId then return end
	if type(blueprint.Controls)=="table" then self._control:SetBindings(userId,mechId,blueprint.Controls,true)
	else self._control:GenerateDefaultBindings(userId,mechId,true) end
	local player=Players:GetPlayerByUserId(userId); local model=modelFor(mechId)
	if not player or not model then return end
	player:SetAttribute("ActiveMechId",mechId); player:SetAttribute("BuildMode",false)
	local seat=pilotSeat(model); local character=player.Character; local humanoid=character and character:FindFirstChildOfClass("Humanoid")
	if seat and humanoid then
		model:SetAttribute("PilotUserId",userId)
		task.defer(function() if seat.Parent and humanoid.Parent then seat:Sit(humanoid) end end)
	elseif self:_hasRemoteControl(mechId) then
		model:SetAttribute("PilotUserId",userId)
	else
		model:SetAttribute("PilotUserId",nil)
	end
end

function Match:Spawn(matchId:string):(boolean,string?)
	local match=self._matches[matchId]; if not match or match.State~="Preparing" then return false,"NotPreparing" end
	self:_setState(match,"Spawning"); local list={}; for _,participant in pairs(match.Participants) do table.insert(list,participant) end
	if #list==0 then self:_setState(match,"Ending"); return false,"NoParticipants" end
	for index,participant in ipairs(list) do
		local blueprint=self:_blueprint(participant); if not blueprint then self:_setState(match,"Ending"); return false,"MissingBlueprint" end
		local ownerId=tonumber(participant.UserId) or -(index+100000); if participant.IsAI then ownerId=-(math.abs(ownerId)+100000) end
		local ok,mechId=self._build:SpawnBlueprint(ownerId,blueprint,self:_spawnCFrame(match,index,#list,blueprint),{MatchId=matchId,Team=participant.Team,IsAI=participant.IsAI,BattleSpawn=true})
		if not ok then self:_setState(match,"Ending"); return false,tostring(mechId) end
		participant.MechId=mechId; match.Mechs[mechId]=participant.Id; match.Alive[participant.Id]=true; self._mechToMatch[mechId]=matchId
		self:_activateBattlePhysics(mechId); self:_bindParticipantControls(participant,mechId,blueprint)
		self:_emit("ParticipantSpawned",{MatchId=matchId,ParticipantId=participant.Id,MechId=mechId,Team=participant.Team,IsAI=participant.IsAI})
	end
	match.Objectives.Primary={Type=match.Mode.Objective,Progress=0,Complete=false}; self:_setState(match,"Active"); return true,nil
end

function Match:Get(matchId:string):any? return self._matches[matchId] end
function Match:GetForMech(mechId:string):any? local id=self._mechToMatch[mechId]; return id and self._matches[id] or nil end
function Match:IsHostile(aMechId:string,bMechId:string):boolean
	local match=self:GetForMech(aMechId)
	if not match or match~=self:GetForMech(bMechId) or match.State~="Active" then return false end
	local a=match.Participants[match.Mechs[aMechId]]; local b=match.Participants[match.Mechs[bMechId]]
	return a~=nil and b~=nil and (match.ModeName=="FreeForAll" or a.Team~=b.Team)
end

function Match:EliminateMech(mechId:string,reason:string)
	local match=self:GetForMech(mechId); if not match or match.State~="Active" then return end
	local id=match.Mechs[mechId]; if not id or not match.Alive[id] then return end
	match.Alive[id]=nil; match.Eliminated[id]={Reason=reason,At=os.clock()}
	local aliveTeams={}; for aliveId in pairs(match.Alive) do local participant=match.Participants[aliveId]; aliveTeams[participant.Team]=true end
	local complete=countSet(match.Alive)<=1 or (match.Mode.Kind~="PvE" and countSet(aliveTeams)<=1)
	if match.Mode.Kind=="PvE" then
		local hostileAlive,playerAlive=false,false
		for aliveId in pairs(match.Alive) do local participant=match.Participants[aliveId]; if participant.IsAI then hostileAlive=true else playerAlive=true end end
		complete=not hostileAlive or not playerAlive
	end
	if complete then self:End(match.Id,"ObjectiveResolved") end
end

function Match:SetObjectiveProgress(matchId:string,objectiveId:string,progress:number,complete:boolean?)
	local match=self._matches[matchId]; if not match or match.State~="Active" then return false end
	local objective=match.Objectives[objectiveId] or {Type=objectiveId}; objective.Progress=progress; objective.Complete=complete==true; match.Objectives[objectiveId]=objective
	self:_emit("ObjectiveChanged",{MatchId=matchId,ObjectiveId=objectiveId,Progress=progress,Complete=objective.Complete})
	if objective.Complete then self:End(matchId,"ObjectiveCompleted") end; return true
end

function Match:_reward(match:any,participant:any)
	if participant.IsAI or match.Rewarded[participant.Id] then return end
	local userId=tonumber(participant.UserId); if not userId then return end
	match.Rewarded[participant.Id]=true; local reward=match.Mode.Reward or {}
	if reward.LootTable then self._progression:AwardLoot(userId,reward.LootTable,match.Id..":"..participant.Id) end
end
function Match:_clearParticipantControl(participant:any)
	if participant.IsAI then return end
	local userId=tonumber(participant.UserId); if not userId then return end
	if participant.MechId then self._control:ClearMech(participant.MechId); local model=modelFor(participant.MechId); if model then model:SetAttribute("PilotUserId",nil) end end
	local player=Players:GetPlayerByUserId(userId); if player and player:GetAttribute("ActiveMechId")==participant.MechId then player:SetAttribute("ActiveMechId",nil) end
end
function Match:End(matchId:string,reason:string):boolean
	local match=self._matches[matchId]; if not match or match.State=="Results" or match.State=="Ending" then return false end
	self:_setState(match,"Ending"); match.EndReason=reason; match.EndedAt=os.clock()
	for _,participant in pairs(match.Participants) do self:_reward(match,participant); self:_clearParticipantControl(participant) end
	self:_setState(match,"Results"); self:_emit("BattleEnded",{MatchId=matchId,Reason=reason,Objectives=copy(match.Objectives)}); return true
end
function Match:HandleDisconnect(userId:number)
	for _,match in pairs(self._matches) do for _,participant in pairs(match.Participants) do if participant.UserId==userId and participant.MechId then self:EliminateMech(participant.MechId,"Disconnected") end end end
end
function Match:CreatePvPExample(playerA:Player,blueprintA:string,playerB:Player,blueprintB:string):(boolean,any)
	local ok,id=self:Create("Duel"); if not ok then return false,id end
	self:AddParticipant(id,{UserId=playerA.UserId,BlueprintId=blueprintA,Team=1}); self:AddParticipant(id,{UserId=playerB.UserId,BlueprintId=blueprintB,Team=2}); return self:Spawn(id)
end
function Match:CreatePvEExample(player:Player,playerBlueprintId:string,enemyBlueprint:any):(boolean,any)
	local ok,id=self:Create("PvEMission"); if not ok then return false,id end
	self:AddParticipant(id,{UserId=player.UserId,BlueprintId=playerBlueprintId,Team=1})
	self:AddParticipant(id,{Id="Enemy-1",BlueprintId="RuntimeEnemy",Blueprint=enemyBlueprint,Team=2,IsAI=true}); return self:Spawn(id)
end

return Match
