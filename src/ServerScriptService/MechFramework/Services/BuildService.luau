--!nonstrict
-- Server-authoritative construction transactions and procedural graph realization.

local Players=game:GetService("Players")
local Workspace=game:GetService("Workspace")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local MechFramework=ReplicatedStorage:WaitForChild("MechFramework")
local Shared=MechFramework:WaitForChild("Shared")
local Remotes=MechFramework:WaitForChild("Remotes")
local BuildMath=require(Shared:WaitForChild("BuildMath"))
local PartRenderer=require(Shared:WaitForChild("PartRenderer"))

local Build={_history={},_future={},_mechs=nil,_parts=nil,_connections=nil,_inventory=nil,_physics=nil}
local ALLOWED_MATERIALS={Metal=true,SmoothPlastic=true,DiamondPlate=true,CorrodedMetal=true,Granite=true,Slate=true}
local MAX_BLUEPRINT_COMPONENTS=300
local MAX_BLUEPRINT_CONNECTIONS=900

local function clone(value)
	if type(value)~="table" then return value end
	local out={}; for key,item in pairs(value) do out[key]=clone(item) end; return out
end
local function stacks(self,userId)
	self._history[userId]=self._history[userId] or {}; self._future[userId]=self._future[userId] or {}
	return self._history[userId],self._future[userId]
end
local function nodeMap(component)
	local out={}
	for _,node in pairs(component and component.Metadata and component.Metadata.AttachmentNodes or {}) do if node and type(node.Name)=="string" then out[node.Name]=node end end
	return out
end
local function getAssemblyFolder()
	local folder=Workspace:FindFirstChild("MechAssemblies")
	if folder then if not folder:IsA("Folder") then error("[BuildService] Workspace.MechAssemblies exists but is not a Folder") end; return folder end
	folder=Instance.new("Folder"); folder.Name="MechAssemblies"; folder.Parent=Workspace; return folder
end
local function contains(list,value)
	for _,item in ipairs(list or {}) do if item==value then return true end end; return false
end
local function tableCount(value)
	local count=0; for _ in pairs(value or {}) do count+=1 end; return count
end
local function sortedKeys(map)
	local out={}; for key in pairs(map or {}) do table.insert(out,tostring(key)) end; table.sort(out); return out
end
local function conditionRatioFromReceipt(receipt)
	if type(receipt)~="table" or receipt.Kind~="Unique" or type(receipt.Item)~="table" then return 1 end
	local maximum=math.max(1,tonumber(receipt.Item.MaxDurability) or 1)
	return math.clamp((tonumber(receipt.Item.Durability) or maximum)/maximum,0,1)
end
local function applyReceiptCondition(component,receipt)
	local ratio=conditionRatioFromReceipt(receipt)
	component.Health=math.clamp(component.MaxHealth*ratio,0,component.MaxHealth)
	component.DamageState=if component.Health<=0 then "Destroyed" elseif ratio<=.25 then "Critical" elseif ratio<=.7 then "Damaged" else "Operational"
	component.Destroyed=component.Health<=0
	component.Metadata=component.Metadata or {}; component.Metadata.DamageState=component.DamageState; component.Metadata.Operational=not component.Destroyed
end
local function choosePrimaryId(mech,preferred)
	mech.Metadata=mech.Metadata or {}
	local current=mech.Metadata.PrimaryComponentId
	if type(current)=="string" then local component=mech.Components[current]; if component and not component.Destroyed then return current end end
	local candidates={}
	for _,id in ipairs(preferred or {}) do local component=mech.Components[id]; if component and not component.Destroyed then table.insert(candidates,id) end end
	if #candidates>0 then table.sort(candidates); return candidates[1] end
	local bestPilot,bestPriority=nil,-math.huge
	for id,component in pairs(mech.Components or {}) do
		if not component.Destroyed and component.Pilot then
			local priority=tonumber(component.Pilot.Priority) or 0
			if priority>bestPriority or (priority==bestPriority and (not bestPilot or id<bestPilot)) then bestPilot,bestPriority=id,priority end
		end
	end
	if bestPilot then return bestPilot end
	local ids={}; for id,component in pairs(mech.Components or {}) do if not component.Destroyed then table.insert(ids,id) end end
	table.sort(ids); return ids[1]
end

function Build:Init(container)
	print("[MechFramework] BuildService:Init()")
	self._mechs=container:Get("MechService"); self._parts=container:Get("PartRegistry"); self._connections=container:Get("ConnectionService")
	self._inventory=container:Get("InventoryService"); self._physics=container:Get("PhysicsService")
end

function Build:_model(mechId)
	local root=getAssemblyFolder(); local existing=root:FindFirstChild(mechId)
	if existing then if not existing:IsA("Model") then error("[BuildService] Mech assembly is not a Model: "..tostring(mechId)) end; return existing end
	local model=Instance.new("Model"); model.Name=mechId; model:SetAttribute("EditMode",true); model.Parent=root; return model
end
function Build:_componentModel(mechId,componentId)
	local model=self:_model(mechId); local componentModel=model:FindFirstChild(componentId)
	return if componentModel and componentModel:IsA("Model") then componentModel else nil
end
function Build:_destroyRealized(mechId)
	local folder=Workspace:FindFirstChild("MechAssemblies"); local model=folder and folder:FindFirstChild(mechId)
	if model then model:Destroy() end
end

function Build:_realize(mechId)
	local mech=self._mechs:Get(mechId); if not mech then return end
	local model=self:_model(mechId); local editMode=model:GetAttribute("EditMode")~=false
	local preserved={}
	for _,name in ipairs({"EditMode","BattleSpawn","BlueprintId","PilotUserId","AIControlled","MatchId","Team","IsAI"}) do preserved[name]=model:GetAttribute(name) end
	model:ClearAllChildren(); model:SetAttribute("OwnerUserId",mech.Owner); model:SetAttribute("Revision",mech.Revision)
	for name,value in pairs(preserved) do if value~=nil then model:SetAttribute(name,value) end end

	local primaryId=choosePrimaryId(mech)
	if primaryId then mech.Metadata.PrimaryComponentId=primaryId end
	local physical={}; local firstRoot=nil
	for id,component in pairs(mech.Components or {}) do
		local definition=self._parts:Get(component.PartType)
		if not definition or typeof(component.LocalTransform)~="CFrame" then warn("[BuildService] Cannot realize component",id,component.PartType); continue end
		component.Metadata=component.Metadata or {}
		local componentModel,root=PartRenderer.Render(definition,{
			Mode="Runtime",Name=tostring(id),CFrame=component.LocalTransform,Paint=component.Metadata.Paint,
			MirrorX=component.Metadata.MirrorX==true,Anchored=editMode,Parent=model,
			Attributes={MechId=tostring(mechId),ComponentId=tostring(id),PartType=tostring(definition.Id)},
		})
		componentModel:SetAttribute("ComponentId",tostring(id)); componentModel:SetAttribute("MechId",tostring(mechId))
		root:SetAttribute("Health",component.Health); root:SetAttribute("DamageState",component.DamageState or "Operational")
		physical[id]=root; firstRoot=firstRoot or root
	end
	for _,edge in pairs(mech.Connections or {}) do
		local a,b=physical[edge.A],physical[edge.B]
		if a and b then local weld=Instance.new("WeldConstraint"); weld.Name=tostring(edge.Id or "Connection"); weld:SetAttribute("ConnectionId",tostring(edge.Id or "")); weld.Part0=a; weld.Part1=b; weld.Parent=model end
	end
	local desired=primaryId and physical[primaryId] or nil
	if desired then model.PrimaryPart=desired elseif firstRoot then model.PrimaryPart=firstRoot end
	self._physics:MarkDirty(mechId)
end

function Build:_clearance(definition,transform,exclude)
	if not definition or typeof(definition.Size)~="Vector3" or typeof(transform)~="CFrame" then return false end
	local params=OverlapParams.new(); params.FilterType=Enum.RaycastFilterType.Exclude; params.FilterDescendantsInstances=exclude or {}
	local size=definition.Size; local querySize=Vector3.new(math.max(.01,size.X-.08),math.max(.01,size.Y-.08),math.max(.01,size.Z-.08))
	return #Workspace:GetPartBoundsInBox(transform,querySize,params)==0
end
function Build:_snapshot(mechId,userId)
	local mech=self._mechs:Get(mechId); if not mech then return nil end
	return clone({Components=mech.Components,Connections=mech.Connections,Adjacency=mech.Adjacency,Metadata=mech.Metadata,Inventory=self._inventory:Snapshot(userId)})
end
function Build:_restore(mechId,state,userId)
	local mech=self._mechs:Get(mechId); if not mech or not state then return end
	mech.Components=clone(state.Components or {}); mech.Connections=clone(state.Connections or {}); mech.Adjacency=clone(state.Adjacency or {}); mech.Metadata=clone(state.Metadata or mech.Metadata or {})
	self._inventory:Restore(userId,state.Inventory or {}); self._mechs:MarkChanged(mechId)
	if next(mech.Components)==nil then self:_destroyRealized(mechId) else self:_realize(mechId) end
end
function Build:_record(userId,mechId,before)
	local history,future=stacks(self,userId); table.insert(history,{MechId=mechId,Before=before,After=self:_snapshot(mechId,userId)})
	if #history>80 then table.remove(history,1) end; table.clear(future)
end
function Build:_restoreReceipt(userId,receipt,partType)
	if receipt and self._inventory:RestorePartReceipt(userId,receipt) then return end
	self._inventory:Grant(userId,partType,1)
end
function Build:_rollbackAdded(mech,componentId,userId,partType,receipt)
	mech.Components[componentId]=nil; if mech.Adjacency then mech.Adjacency[componentId]=nil end
	if mech.Metadata and mech.Metadata.PrimaryComponentId==componentId then mech.Metadata.PrimaryComponentId=choosePrimaryId(mech) end
	self:_restoreReceipt(userId,receipt,partType); self._mechs:MarkChanged(mech.Id)
end

function Build:_place(player,request,appearance)
	local userId=player.UserId
	if type(request.PartType)~="string" then return false,"BadPartType" end
	local definition=self._parts:Get(request.PartType); if not definition then return false,"UnknownPartType" end
	local partType=definition.Id
	local mirrorX=if request.MirrorX~=nil then request.MirrorX==true else type(appearance)=="table" and appearance.MirrorX==true
	local paint=definition.PaintDefaults or {}; if type(appearance)=="table" and type(appearance.Paint)=="table" then paint=appearance.Paint end
	local mechId=request.MechId
	if mechId~=nil and type(mechId)~="string" then return false,"BadMechId" end
	if not mechId then mechId=self._mechs:Create(userId,{BuildOrigin=true}) end
	if not mechId or not self._mechs:IsOwner(userId,mechId) then return false,"NotAuthorized" end
	local mech=self._mechs:Get(mechId); if not mech then return false,"InvalidMech" end
	local model=self:_model(mechId); if model:GetAttribute("EditMode")==false then return false,"EnterEditModeFirst" end

	local transform=request.Transform; local target,targetNode,sourceNode=nil,nil,nil
	if request.TargetComponentId then
		if type(request.TargetComponentId)~="string" or type(request.TargetNode)~="string" or type(request.SourceNode)~="string" then return false,"BadNodeRequest" end
		target=mech.Components[request.TargetComponentId]; if not target then return false,"InvalidTarget" end
		targetNode=nodeMap(target)[request.TargetNode]; sourceNode=BuildMath.Nodes(definition,mirrorX)[request.SourceNode]
		if not targetNode or not sourceNode then return false,"InvalidNode" end
		if targetNode.OccupiedBy then return false,"NodeOccupied" end
		if not BuildMath.Compatible(targetNode,sourceNode) then return false,"IncompatibleNode" end
		transform=BuildMath.Snap(target.LocalTransform,targetNode.Transform,sourceNode.Transform,tonumber(request.Rotation) or 0)
	elseif next(mech.Components or {})~=nil then return false,"AttachmentRequired" end

	if typeof(transform)~="CFrame" then return false,"InvalidTransform" end
	if not self:_clearance(definition,transform) then return false,"Collision" end
	local before=self:_snapshot(mechId,userId)
	local consumed,receipt=self._inventory:ConsumeOne(userId,partType)
	if not consumed then return false,receipt or "InsufficientInventory" end
	if conditionRatioFromReceipt(receipt)<=0 then self:_restoreReceipt(userId,receipt,partType); return false,"PartNeedsRepair" end

	local nodes=BuildMath.AttachmentNodes(definition,mirrorX); for _,node in pairs(nodes) do node.OccupiedBy=nil end
	local added,componentId=self._mechs:AddComponent(mechId,userId,partType,transform,{
		AttachmentNodes=nodes,Paint=clone(paint),MirrorX=mirrorX,InventoryReceipt=clone(receipt),
	})
	if not added then self:_restoreReceipt(userId,receipt,partType); return false,componentId end
	local component=mech.Components[componentId]; if component then applyReceiptCondition(component,receipt) end

	if target then
		local actualTargetNode=nodeMap(target)[request.TargetNode]; local actualSourceNode=component and nodeMap(component)[request.SourceNode] or nil
		if not component or not actualTargetNode or not actualSourceNode or component.Destroyed then self:_rollbackAdded(mech,componentId,userId,partType,receipt); return false,"InvalidNodeState" end
		actualTargetNode.OccupiedBy=componentId; actualSourceNode.OccupiedBy=target.Id
		local targetStrength=target.PhysicalProperties and target.PhysicalProperties.StructuralStrength or 100
		local sourceStrength=component.PhysicalProperties and component.PhysicalProperties.StructuralStrength or 100
		local attached,edge=self._connections:Attach(mechId,userId,target.Id,componentId,{SocketA=request.TargetNode,SocketB=request.SourceNode,StructuralStrength=math.min(targetStrength,sourceStrength)})
		if not attached then actualTargetNode.OccupiedBy=nil; actualSourceNode.OccupiedBy=nil; self:_rollbackAdded(mech,componentId,userId,partType,receipt); return false,edge end
	end
	self:_record(userId,mechId,before); self:_realize(mechId)
	return true,{MechId=mechId,ComponentId=componentId,Revision=mech.Revision,MirrorX=mirrorX,Paint=clone(paint)}
end

function Build:_remove(player,request)
	if type(request.MechId)~="string" or type(request.ComponentId)~="string" then return false,"BadRequest" end
	local mech=self._mechs:Get(request.MechId); if not mech or mech.Owner~=player.UserId then return false,"NotAuthorized" end
	if self:_model(request.MechId):GetAttribute("EditMode")==false then return false,"EnterEditModeFirst" end
	local component=mech.Components[request.ComponentId]; if not component then return false,"InvalidComponent" end
	local before=self:_snapshot(request.MechId,player.UserId)
	local wasPrimary=mech.Metadata and mech.Metadata.PrimaryComponentId==component.Id
	local preferred={}; if wasPrimary then for neighborId in pairs(mech.Adjacency[component.Id] or {}) do table.insert(preferred,neighborId) end end
	local edgeIds={}; for edgeId in pairs(component.Connections or {}) do table.insert(edgeIds,edgeId) end
	for _,edgeId in ipairs(edgeIds) do
		local edge=mech.Connections[edgeId]
		if edge then
			local otherId=if edge.A==component.Id then edge.B else edge.A; local other=mech.Components[otherId]
			if other then for _,node in pairs(other.Metadata and other.Metadata.AttachmentNodes or {}) do if node.OccupiedBy==component.Id then node.OccupiedBy=nil end end end
		end
		self._connections:Detach(request.MechId,player.UserId,edgeId)
	end
	mech.Components[component.Id]=nil; if mech.Adjacency then mech.Adjacency[component.Id]=nil end
	if wasPrimary then mech.Metadata.PrimaryComponentId=nil; mech.Metadata.PrimaryComponentId=choosePrimaryId(mech,preferred) end
	self._mechs:MarkChanged(request.MechId)
	local ratio=math.clamp((tonumber(component.Health) or 0)/math.max(1,tonumber(component.MaxHealth) or 1),0,1)
	if not self._inventory:ReturnBuiltPart(player.UserId,component.PartType,component.Metadata and component.Metadata.InventoryReceipt,ratio) then warn("[BuildService] Failed to return removed component inventory",component.Id) end
	self:_record(player.UserId,request.MechId,before)
	local empty=next(mech.Components)==nil
	if empty then self:_destroyRealized(request.MechId) else self:_realize(request.MechId) end
	return true,{MechId=request.MechId,Revision=mech.Revision,Empty=empty}
end

function Build:_move(player,request)
	if type(request.MechId)~="string" or type(request.ComponentId)~="string" or typeof(request.Transform)~="CFrame" then return false,"BadRequest" end
	local mech=self._mechs:Get(request.MechId); if not mech or mech.Owner~=player.UserId then return false,"NotAuthorized" end
	if self:_model(request.MechId):GetAttribute("EditMode")==false then return false,"EnterEditModeFirst" end
	local component=mech.Components[request.ComponentId]; if not component then return false,"InvalidComponent" end
	if next(component.Connections or {})~=nil then return false,"DetachBeforeMove" end
	local definition=self._parts:Get(component.PartType); if not definition then return false,"UnknownPartType" end
	local existing=self:_componentModel(request.MechId,component.Id); local exclusions=if existing then {existing} else {}
	if not self:_clearance(definition,request.Transform,exclusions) then return false,"Collision" end
	local before=self:_snapshot(request.MechId,player.UserId); component.LocalTransform=request.Transform
	self._mechs:MarkChanged(request.MechId); self:_record(player.UserId,request.MechId,before); self:_realize(request.MechId)
	return true,{MechId=request.MechId,Revision=mech.Revision}
end

function Build:_paint(player,request)
	if type(request.MechId)~="string" or type(request.ComponentId)~="string" or type(request.Region)~="string" or typeof(request.Color)~="Color3" then return false,"BadPaintRequest" end
	local mech=self._mechs:Get(request.MechId); if not mech or mech.Owner~=player.UserId then return false,"NotAuthorized" end
	if self:_model(request.MechId):GetAttribute("EditMode")==false then return false,"EnterEditModeFirst" end
	local component=mech.Components[request.ComponentId]; if not component then return false,"InvalidComponent" end
	local definition=self._parts:Get(component.PartType); if not definition then return false,"UnknownPartType" end
	if request.Region~="All" and not contains(definition.PaintRegions,request.Region) then return false,"InvalidPaintRegion" end
	if request.Material~=nil and (type(request.Material)~="string" or not ALLOWED_MATERIALS[request.Material]) then return false,"InvalidMaterial" end
	local before=self:_snapshot(request.MechId,player.UserId); component.Metadata=component.Metadata or {}; component.Metadata.Paint=component.Metadata.Paint or clone(definition.PaintDefaults or {})
	if request.Region=="All" then for _,region in ipairs(definition.PaintRegions or {}) do if region~="Glass" then component.Metadata.Paint[region]=request.Color end end
	else component.Metadata.Paint[request.Region]=request.Color end
	if request.Material then component.Metadata.Paint.Material=request.Material end
	self._mechs:MarkChanged(request.MechId); self:_record(player.UserId,request.MechId,before); self:_realize(request.MechId)
	return true,{Paint=clone(component.Metadata.Paint),Revision=mech.Revision}
end

function Build:_appearance(player,request)
	if type(request.MechId)~="string" or type(request.ComponentId)~="string" then return false,"BadAppearanceRequest" end
	local mech=self._mechs:Get(request.MechId); if not mech or mech.Owner~=player.UserId then return false,"NotAuthorized" end
	local source=mech.Components[request.ComponentId]; if not source or source.Destroyed then return false,"InvalidComponent" end
	local definition=self._parts:Get(source.PartType); if not definition then return false,"UnknownPartType" end
	return true,{PartType=definition.Id,Paint=clone(source.Metadata and source.Metadata.Paint or definition.PaintDefaults or {}),MirrorX=source.Metadata and source.Metadata.MirrorX==true}
end

function Build:_duplicate(player,request)
	if type(request.MechId)~="string" or type(request.ComponentId)~="string" then return false,"BadDuplicateRequest" end
	local mech=self._mechs:Get(request.MechId); if not mech or mech.Owner~=player.UserId then return false,"NotAuthorized" end
	local source=mech.Components[request.ComponentId]; if not source or source.Destroyed then return false,"InvalidComponent" end
	local definition=self._parts:Get(source.PartType); if not definition then return false,"UnknownPartType" end
	request.PartType=definition.Id
	local appearance={Paint=clone(source.Metadata and source.Metadata.Paint or definition.PaintDefaults or {}),MirrorX=source.Metadata and source.Metadata.MirrorX==true}
	return self:_place(player,request,appearance)
end

function Build:_summary(player,request)
	if type(request.MechId)~="string" then return false,"BadMechId" end
	local mech=self._mechs:Get(request.MechId); if not mech or mech.Owner~=player.UserId then return false,"NotAuthorized" end
	local summary={Mass=0,PartCount=0,PowerGeneration=0,PowerDemand=0,PowerStorage=0,HeatGeneration=0,Cooling=0,LiftArea=0,DriveTorque=0,Thrust=0,FuelCapacity=0,Seats=0,Weapons=0}
	for _,component in pairs(mech.Components) do if not component.Destroyed then
		summary.PartCount+=1; summary.Mass+=tonumber(component.Mass) or 0
		if component.Power then summary.PowerGeneration+=tonumber(component.Power.Generation) or 0; summary.PowerDemand+=tonumber(component.Power.Demand) or 0; summary.PowerStorage+=tonumber(component.Power.StorageCapacity) or tonumber(component.Power.Capacity) or 0 end
		if component.Heat then summary.HeatGeneration+=tonumber(component.Heat.Generation) or 0; summary.Cooling+=tonumber(component.Heat.Cooling) or tonumber(component.Heat.Dissipation) or 0 end
		if component.Aerodynamics then summary.LiftArea+=tonumber(component.Aerodynamics.Area) or 0 end
		if component.Mobility then summary.DriveTorque+=tonumber(component.Mobility.DriveTorque) or 0 end
		if component.Propulsion then summary.Thrust+=tonumber(component.Propulsion.Force) or 0 end
		if component.Fuel then summary.FuelCapacity+=tonumber(component.Fuel.Capacity) or 0 end
		if component.Pilot then summary.Seats+=1 end; if component.Combat then summary.Weapons+=1 end
	end end
	return true,summary
end

function Build:_inventoryCounts(player)
	local counts={}
	for _,definition in ipairs(self._parts:GetList()) do
		local getBuildable=self._inventory.GetBuildableCount
		counts[definition.Id]=if getBuildable then self._inventory:GetBuildableCount(player.UserId,definition.Id) else self._inventory:GetCount(player.UserId,definition.Id)
	end
	return true,counts
end

function Build:_undoRedo(player,redo)
	local history,future=stacks(self,player.UserId); local source,destination=if redo then future else history,if redo then history else future
	local entry=table.remove(source); if not entry or not self._mechs:IsOwner(player.UserId,entry.MechId) then return false,"NothingToApply" end
	self:_restore(entry.MechId,if redo then entry.After else entry.Before,player.UserId); table.insert(destination,entry)
	local mech=self._mechs:Get(entry.MechId); return true,{MechId=entry.MechId,Empty=not mech or next(mech.Components)==nil}
end

function Build:Start()
	print("[MechFramework] BuildService:Start()")
	local remote=Remotes:WaitForChild("Functions"):WaitForChild("RequestBuildAction"); if not remote:IsA("RemoteFunction") then error("[BuildService] RequestBuildAction must be a RemoteFunction") end
	remote.OnServerInvoke=function(player,request)
		local action=type(request)=="table" and request.Action or nil; if type(request)~="table" or type(action)~="string" then return false,"BadRequest" end
		if action=="Definition" then if type(request.PartType)~="string" then return false,"BadPartType" end; local definition=self._parts:Get(request.PartType); return definition~=nil,definition
		elseif action=="Appearance" then return self:_appearance(player,request)
		elseif action=="Inventory" then return self:_inventoryCounts(player)
		elseif action=="Place" then return self:_place(player,request)
		elseif action=="Remove" then return self:_remove(player,request)
		elseif action=="Move" then return self:_move(player,request)
		elseif action=="Paint" then return self:_paint(player,request)
		elseif action=="Duplicate" then return self:_duplicate(player,request)
		elseif action=="Summary" then return self:_summary(player,request)
		elseif action=="Undo" then return self:_undoRedo(player,false)
		elseif action=="Redo" then return self:_undoRedo(player,true)
		elseif action=="Rebuild" then if type(request.MechId)~="string" or not self._mechs:IsOwner(player.UserId,request.MechId) then return false,"NotAuthorized" end; self:_realize(request.MechId); return true,{} end
		return false,"UnknownAction"
	end
	Players.PlayerRemoving:Connect(function(player) self._history[player.UserId]=nil; self._future[player.UserId]=nil end)
	print("[MechFramework] BuildService owns RequestBuildAction")
end

local function blueprintTransform(value)
	if typeof(value)=="CFrame" then return value end
	if type(value)=="table" then
		local components=value.Components or value
		if type(components)=="table" and #components==12 then local ok,result=pcall(function() return CFrame.new(table.unpack(components)) end); if ok then return result end end
		if tonumber(value.X) and tonumber(value.Y) and tonumber(value.Z) then return CFrame.new(tonumber(value.X),tonumber(value.Y),tonumber(value.Z)) end
	end
	return nil
end

local function sanitizedMetadata(sourceMetadata,definition)
	local meta=clone(sourceMetadata or {})
	local mirrorX=meta.MirrorX==true
	meta.AttachmentNodes=BuildMath.AttachmentNodes(definition,mirrorX); for _,node in pairs(meta.AttachmentNodes) do node.OccupiedBy=nil end
	meta.Paint=clone(meta.Paint or definition.PaintDefaults or {})
	meta.ControlState={}; meta.PowerFraction=nil; meta.PowerState=nil; meta.FuelFraction=nil; meta.PropulsionFraction=0
	meta.Temperature=nil; meta.HeatEfficiency=nil; meta.Overheated=nil; meta.ThermalState=nil; meta.Jammed=nil
	meta.DamageState=nil; meta.LastDamage=nil; meta.Operational=true; meta.Detached=nil; meta.DestroyedAt=nil; meta.InventoryReceipt=nil
	return meta
end

function Build:_validateBlueprint(blueprint)
	if type(blueprint)~="table" or type(blueprint.Components)~="table" then return false,"InvalidBlueprint" end
	local count=tableCount(blueprint.Components); if count<1 then return false,"BlueprintEmpty" end
	if count>MAX_BLUEPRINT_COMPONENTS then return false,"BlueprintTooLarge" end
	if type(blueprint.Connections)~="table" then return false,"InvalidBlueprintConnections" end
	if tableCount(blueprint.Connections)>MAX_BLUEPRINT_CONNECTIONS then return false,"BlueprintTooConnected" end
	local components={}
	for sourceId,source in pairs(blueprint.Components) do
		if type(source)~="table" or type(source.PartType)~="string" then return false,"InvalidBlueprintComponent" end
		local definition=self._parts:Get(source.PartType); if not definition then return false,"UnknownBlueprintPart:"..tostring(source.PartType) end
		local transform=blueprintTransform(source.LocalTransform or source.Transform); if not transform then return false,"InvalidBlueprintTransform" end
		local key=tostring(source.Id or sourceId); if components[key] then return false,"DuplicateBlueprintComponent" end
		components[key]={Source=source,Definition=definition,Transform=transform}
	end
	local seenEdges={}
	for _,edge in pairs(blueprint.Connections) do
		if type(edge)~="table" then return false,"InvalidBlueprintConnection" end
		local a,b=tostring(edge.A or ""),tostring(edge.B or "")
		if a=="" or b=="" or a==b or not components[a] or not components[b] then return false,"InvalidBlueprintConnection" end
		local pair=if a<b then a.."|"..b else b.."|"..a; if seenEdges[pair] then return false,"DuplicateBlueprintConnection" end; seenEdges[pair]=true
		if edge.SocketA~=nil and type(edge.SocketA)~="string" then return false,"InvalidBlueprintSocket" end
		if edge.SocketB~=nil and type(edge.SocketB)~="string" then return false,"InvalidBlueprintSocket" end
	end
	return true,components
end

function Build:_reserveBlueprintInventory(userId,validated)
	local requirements={}
	for _,entry in pairs(validated) do local id=entry.Definition.Id; requirements[id]=(requirements[id] or 0)+1 end
	for _,partType in ipairs(sortedKeys(requirements)) do
		local available=if self._inventory.GetBuildableCount then self._inventory:GetBuildableCount(userId,partType) else self._inventory:GetCount(userId,partType)
		if available<requirements[partType] then return false,"MissingInventory:"..partType..":"..tostring(requirements[partType]-available) end
	end
	local receipts={}; local consumedOrder={}
	for _,sourceKey in ipairs(sortedKeys(validated)) do
		local entry=validated[sourceKey]
		local ok,receipt=self._inventory:ConsumeOne(userId,entry.Definition.Id)
		if not ok or conditionRatioFromReceipt(receipt)<=0 then
			if ok then self:_restoreReceipt(userId,receipt,entry.Definition.Id) end
			for index=#consumedOrder,1,-1 do local key=consumedOrder[index]; local previous=receipts[key]; self:_restoreReceipt(userId,previous,previous.PartType) end
			return false,if ok then "PartNeedsRepair:"..entry.Definition.Id else receipt or "InsufficientInventory"
		end
		receipts[sourceKey]=receipt; table.insert(consumedOrder,sourceKey)
	end
	return true,receipts
end
function Build:_refundBlueprintInventory(userId,receipts)
	for _,sourceKey in ipairs(sortedKeys(receipts)) do local receipt=receipts[sourceKey]; self:_restoreReceipt(userId,receipt,receipt.PartType) end
end
function Build:_rollbackBlueprint(mechId)
	self:_destroyRealized(mechId); self._mechs:Destroy(mechId); self._physics:MarkDirty(mechId)
end

function Build:SpawnBlueprint(ownerId,blueprint,spawnCFrame,metadata)
	if type(ownerId)~="number" or typeof(spawnCFrame)~="CFrame" then return false,"InvalidBlueprint" end
	local valid,validated=self:_validateBlueprint(blueprint); if not valid then return false,validated end
	local consumeInventory=metadata and metadata.ConsumeInventory==true
	local receipts=nil
	if consumeInventory then local reserved,result=self:_reserveBlueprintInventory(ownerId,validated); if not reserved then return false,result end; receipts=result end
	local mechId=self._mechs:Create(ownerId,clone(metadata or {})); local mech=self._mechs:Get(mechId)
	if not mech then if receipts then self:_refundBlueprintInventory(ownerId,receipts) end; return false,"MechCreationFailed" end
	mech.Metadata.BlueprintId=blueprint.Id or blueprint.Name; mech.Metadata.SpawnedFromBlueprint=true
	local idMap={}; local sourceKeys=sortedKeys(validated)
	local function fail(reason)
		self:_rollbackBlueprint(mechId); if receipts then self:_refundBlueprintInventory(ownerId,receipts) end; return false,reason
	end

	for _,sourceKey in ipairs(sourceKeys) do
		local entry=validated[sourceKey]; local source,definition=entry.Source,entry.Definition; local meta=sanitizedMetadata(source.Metadata,definition)
		meta.BlueprintSourceId=sourceKey
		local receipt=receipts and receipts[sourceKey] or nil; if receipt then meta.InventoryReceipt=clone(receipt) end
		local added,componentId=self._mechs:AddComponent(mechId,ownerId,definition.Id,spawnCFrame*entry.Transform,meta)
		if not added then return fail(componentId) end
		idMap[sourceKey]=componentId
		local component=self._mechs:GetComponent(mechId,componentId)
		if component then
			if receipt then applyReceiptCondition(component,receipt) else component.Health=component.MaxHealth; component.Destroyed=false; component.DamageState="Operational" end
		end
	end

	local savedPrimary=type(blueprint.PrimaryComponentId)=="string" and idMap[blueprint.PrimaryComponentId] or nil
	mech.Metadata.PrimaryComponentId=savedPrimary or idMap[sourceKeys[1]] or choosePrimaryId(mech)

	for _,edge in pairs(blueprint.Connections or {}) do
		local a,b=idMap[tostring(edge.A)],idMap[tostring(edge.B)]
		if not a or not b then return fail("InvalidBlueprintConnection") end
		local componentA,componentB=mech.Components[a],mech.Components[b]; local nodesA,nodesB=nodeMap(componentA),nodeMap(componentB)
		local socketA,socketB=edge.SocketA,edge.SocketB
		if socketA and not nodesA[socketA] then return fail("InvalidBlueprintSocket") end
		if socketB and not nodesB[socketB] then return fail("InvalidBlueprintSocket") end
		if socketA and nodesA[socketA].OccupiedBy then return fail("BlueprintSocketOccupied") end
		if socketB and nodesB[socketB].OccupiedBy then return fail("BlueprintSocketOccupied") end
		if socketA and socketB and not BuildMath.Compatible(nodesA[socketA],nodesB[socketB]) then return fail("IncompatibleBlueprintSocket") end
		local attached,result=self._connections:Attach(mechId,ownerId,a,b,{SocketA=socketA,SocketB=socketB,StructuralStrength=edge.StructuralStrength})
		if not attached then return fail(result or "InvalidBlueprintConnection") end
		if socketA then nodesA[socketA].OccupiedBy=b end; if socketB then nodesB[socketB].OccupiedBy=a end
	end

	local model=self:_model(mechId); model:SetAttribute("BattleSpawn",metadata and metadata.BattleSpawn==true or false); model:SetAttribute("EditMode",not (metadata and (metadata.BattleSpawn==true or metadata.Playing==true)))
	model:SetAttribute("BlueprintId",tostring(blueprint.Id or blueprint.Name or "SavedBlueprint")); self:_realize(mechId)
	if metadata then for key,value in pairs(metadata) do if key~="ConsumeInventory" and type(key)=="string" and (type(value)=="string" or type(value)=="number" or type(value)=="boolean") then model:SetAttribute(key,value) end end end
	return true,mechId
end

function Build:ReplaceBlueprint(ownerId,currentMechId,blueprint,spawnCFrame,metadata)
	if type(ownerId)~="number" or type(currentMechId)~="string" or typeof(spawnCFrame)~="CFrame" then return false,"InvalidQuickSwap" end
	if not self._mechs:IsOwner(ownerId,currentMechId) then return false,"NotAuthorized" end
	local mech=self._mechs:Get(currentMechId); local oldModel=Workspace:FindFirstChild("MechAssemblies")
	oldModel=oldModel and oldModel:FindFirstChild(currentMechId)
	if not mech or not oldModel or not oldModel:IsA("Model") then return false,"MachineNotReady" end
	local before=self:_snapshot(currentMechId,ownerId); if not before then return false,"MachineNotReady" end
	local attributes=oldModel:GetAttributes()

	-- Return the live machine first, then reserve the target from that combined inventory.
	-- Any failure restores the exact inventory snapshot and re-realizes the original graph.
	for _,componentId in ipairs(sortedKeys(mech.Components)) do
		local component=mech.Components[componentId]
		local maxHealth=math.max(1,tonumber(component.MaxHealth) or 1)
		local condition=math.clamp((tonumber(component.Health) or maxHealth)/maxHealth,0,1)
		local receipt=component.Metadata and component.Metadata.InventoryReceipt
		if not self._inventory:ReturnBuiltPart(ownerId,component.PartType,receipt,condition) then
			self._inventory:Restore(ownerId,before.Inventory or {})
			return false,"InventoryReturnFailed"
		end
	end

	self:_destroyRealized(currentMechId)
	local spawnMetadata=clone(metadata or {})
	spawnMetadata.ConsumeInventory=true
	spawnMetadata.Playing=true
	local ok,result=self:SpawnBlueprint(ownerId,blueprint,spawnCFrame,spawnMetadata)
	if not ok then
		self._inventory:Restore(ownerId,before.Inventory or {})
		local restored=self:_model(currentMechId)
		for name,value in pairs(attributes) do restored:SetAttribute(name,value) end
		self:_restore(currentMechId,before,ownerId)
		return false,result
	end

	self._mechs:Destroy(currentMechId)
	self._physics:MarkDirty(currentMechId)
	return true,result
end

return Build