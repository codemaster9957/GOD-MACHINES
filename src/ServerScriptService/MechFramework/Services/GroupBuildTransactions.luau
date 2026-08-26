--!nonstrict
-- Atomic Phase 2 group construction operations. Called only by BuildService's authoritative remote.

local ReplicatedStorage=game:GetService("ReplicatedStorage")
local BuildMath=require(ReplicatedStorage:WaitForChild("MechFramework"):WaitForChild("Shared"):WaitForChild("BuildMath"))

local Group={}
local MAX_GROUP_COMPONENTS=120
local MAX_GROUP_TRANSLATION=250

local function clone(value)
	if type(value)~="table" then return value end
	local out={}; for key,item in pairs(value) do out[key]=clone(item) end; return out
end

local function nodeMap(component)
	local out={}
	for _,node in pairs(component and component.Metadata and component.Metadata.AttachmentNodes or {}) do
		if type(node)=="table" and type(node.Name)=="string" then out[node.Name]=node end
	end
	return out
end

local function conditionRatio(receipt)
	if type(receipt)~="table" or receipt.Kind~="Unique" or type(receipt.Item)~="table" then return 1 end
	local maximum=math.max(1,tonumber(receipt.Item.MaxDurability) or 1)
	return math.clamp((tonumber(receipt.Item.Durability) or maximum)/maximum,0,1)
end

local function applyReceipt(component,receipt)
	local ratio=conditionRatio(receipt)
	component.Health=math.clamp(component.MaxHealth*ratio,0,component.MaxHealth)
	component.Destroyed=component.Health<=0
	component.DamageState=if component.Destroyed then "Destroyed" elseif ratio<=.25 then "Critical" elseif ratio<=.7 then "Damaged" else "Operational"
	component.Metadata=component.Metadata or {}
	component.Metadata.DamageState=component.DamageState
	component.Metadata.Operational=not component.Destroyed
end

local function copyMetadata(source,definition,receipt,mirrorOverride)
	local meta=clone(source.Metadata or {})
	local mirrorX=if mirrorOverride~=nil then mirrorOverride==true else meta.MirrorX==true
	meta.MirrorX=mirrorX
	meta.AttachmentNodes=BuildMath.AttachmentNodes(definition,mirrorX)
	for _,node in pairs(meta.AttachmentNodes) do node.OccupiedBy=nil end
	meta.Paint=clone(meta.Paint or definition.PaintDefaults or {})
	meta.InventoryReceipt=clone(receipt)
	meta.ControlState={}
	meta.PowerFraction=nil; meta.PowerState=nil; meta.FuelFraction=nil; meta.PropulsionFraction=0
	meta.Temperature=nil; meta.HeatEfficiency=nil; meta.Overheated=nil; meta.ThermalState=nil; meta.Jammed=nil
	meta.DamageState=nil; meta.LastDamage=nil; meta.Operational=true; meta.Detached=nil; meta.DestroyedAt=nil
	return meta
end

local function validateSelection(build,player,request)
	if type(request.MechId)~="string" or type(request.ComponentIds)~="table" then return nil,"BadGroupRequest" end
	if #request.ComponentIds<1 or #request.ComponentIds>MAX_GROUP_COMPONENTS then return nil,"InvalidGroupSize" end
	local mech=build._mechs:Get(request.MechId)
	if not mech or mech.Owner~=player.UserId then return nil,"NotAuthorized" end
	if build:_model(request.MechId):GetAttribute("EditMode")==false then return nil,"EnterEditModeFirst" end
	local selected={}; local ids={}
	for _,id in ipairs(request.ComponentIds) do
		if type(id)~="string" or selected[id] then return nil,"InvalidGroupComponent" end
		local component=mech.Components[id]
		if not component or component.Destroyed then return nil,"InvalidComponent" end
		selected[id]=true; table.insert(ids,id)
	end
	table.sort(ids)
	return {Mech=mech,Selected=selected,Ids=ids},nil
end

local function validDelta(value)
	if typeof(value)~="CFrame" then return false end
	return value.Position.Magnitude<=MAX_GROUP_TRANSLATION
end

local function restoreOnFailure(build,mechId,userId,before,reason)
	build:_restore(mechId,before,userId)
	return false,reason
end

local function attachInternalEdges(build,player,mech,selected,idMap)
	local seen={}
	for _,sourceId in ipairs(idMap.__order or {}) do
		local source=mech.Components[sourceId]
		if source then
			for edgeId in pairs(source.Connections or {}) do
				if not seen[edgeId] then
					seen[edgeId]=true
					local edge=mech.Connections[edgeId]
					if edge and selected[edge.A] and selected[edge.B] then
						local a,b=idMap[edge.A],idMap[edge.B]
						if a and b and a~=b and (a~=edge.A or b~=edge.B) then
							local componentA,componentB=mech.Components[a],mech.Components[b]
							local nodesA,nodesB=nodeMap(componentA),nodeMap(componentB)
							local socketA,socketB=edge.SocketA,edge.SocketB
							if socketA and socketB and nodesA[socketA] and nodesB[socketB] and not nodesA[socketA].OccupiedBy and not nodesB[socketB].OccupiedBy then
								local ok,result=build._connections:Attach(mech.Id,player.UserId,a,b,{SocketA=socketA,SocketB=socketB,StructuralStrength=edge.StructuralStrength})
								if not ok then return false,result or "GroupAttachFailed" end
								nodesA[socketA].OccupiedBy=b; nodesB[socketB].OccupiedBy=a
							end
						end
					end
				end
			end
		end
	end
	return true
end

function Group.Duplicate(build,player,request)
	local context,reason=validateSelection(build,player,request); if not context then return false,reason end
	local delta=request.Delta or CFrame.new(6,0,0); if not validDelta(delta) then return false,"InvalidGroupDelta" end
	local mech=context.Mech; local before=build:_snapshot(request.MechId,player.UserId)
	local transforms={}
	for _,id in ipairs(context.Ids) do
		local source=mech.Components[id]; local definition=build._parts:Get(source.PartType); if not definition then return false,"UnknownPartType" end
		local transform=delta*source.LocalTransform
		if not build:_clearance(definition,transform) then return false,"GroupCollision" end
		transforms[id]={Transform=transform,Definition=definition}
	end
	local idMap={__order=clone(context.Ids)}
	for _,id in ipairs(context.Ids) do
		local source=mech.Components[id]; local entry=transforms[id]
		local consumed,receipt=build._inventory:ConsumeOne(player.UserId,entry.Definition.Id)
		if not consumed or conditionRatio(receipt)<=0 then return restoreOnFailure(build,request.MechId,player.UserId,before,consumed and "PartNeedsRepair" or receipt or "InsufficientInventory") end
		local meta=copyMetadata(source,entry.Definition,receipt,nil)
		local added,newId=build._mechs:AddComponent(request.MechId,player.UserId,entry.Definition.Id,entry.Transform,meta)
		if not added then return restoreOnFailure(build,request.MechId,player.UserId,before,newId) end
		idMap[id]=newId; local component=mech.Components[newId]; if component then applyReceipt(component,receipt) end
	end
	local attached,attachReason=attachInternalEdges(build,player,mech,context.Selected,idMap)
	if not attached then return restoreOnFailure(build,request.MechId,player.UserId,before,attachReason) end
	build._mechs:MarkChanged(request.MechId); build:_record(player.UserId,request.MechId,before); build:_realize(request.MechId)
	local created={}; for _,id in ipairs(context.Ids) do table.insert(created,idMap[id]) end
	return true,{MechId=request.MechId,ComponentIds=created,Created=#created,Revision=mech.Revision}
end

function Group.Mirror(build,player,request)
	local context,reason=validateSelection(build,player,request); if not context then return false,reason end
	if request.Axis~=nil and request.Axis~="X" then return false,"UnsupportedMirrorAxis" end
	local mech=context.Mech; local model=build:_model(request.MechId)
	local pivot=if model.PrimaryPart then model.PrimaryPart.CFrame else model:GetPivot()
	local before=build:_snapshot(request.MechId,player.UserId)
	local idMap={__order=clone(context.Ids)}; local entries={}; local newIds={}
	for _,id in ipairs(context.Ids) do
		local source=mech.Components[id]; local definition=build._parts:Get(source.PartType); if not definition then return false,"UnknownPartType" end
		local transform=BuildMath.MirrorWorldAcrossLocalX(pivot,source.LocalTransform)
		local delta=source.LocalTransform:ToObjectSpace(transform); local _,angle=delta:ToAxisAngle()
		if delta.Position.Magnitude<.04 and math.abs(angle)<math.rad(1) then
			idMap[id]=id
		else
			if not build:_clearance(definition,transform) then return false,"GroupMirrorCollision" end
			entries[id]={Source=source,Definition=definition,Transform=transform,MirrorX=not (source.Metadata and source.Metadata.MirrorX==true)}
		end
	end
	for _,id in ipairs(context.Ids) do
		local entry=entries[id]
		if entry then
			local consumed,receipt=build._inventory:ConsumeOne(player.UserId,entry.Definition.Id)
			if not consumed or conditionRatio(receipt)<=0 then return restoreOnFailure(build,request.MechId,player.UserId,before,consumed and "PartNeedsRepair" or receipt or "InsufficientInventory") end
			local meta=copyMetadata(entry.Source,entry.Definition,receipt,entry.MirrorX); meta.GroupMirrored=true
			local added,newId=build._mechs:AddComponent(request.MechId,player.UserId,entry.Definition.Id,entry.Transform,meta)
			if not added then return restoreOnFailure(build,request.MechId,player.UserId,before,newId) end
			idMap[id]=newId; newIds[newId]=true; local component=mech.Components[newId]; if component then applyReceipt(component,receipt) end
		end
	end
	local attached,attachReason=attachInternalEdges(build,player,mech,context.Selected,idMap)
	if not attached then return restoreOnFailure(build,request.MechId,player.UserId,before,attachReason) end

	-- Rebuild mirrored boundary links geometrically. Off-plane source originals and new clones are never valid targets.
	local ignored={}; for id in pairs(context.Selected) do if idMap[id]~=id then ignored[id]=true end end; for id in pairs(newIds) do ignored[id]=true end
	for _,sourceId in ipairs(context.Ids) do
		local newId=idMap[sourceId]
		if newId and newId~=sourceId then
			local source=mech.Components[sourceId]; local cloneComponent=mech.Components[newId]; local boundaryCount=0
			for edgeId in pairs(source.Connections or {}) do
				local edge=mech.Connections[edgeId]
				if edge then local other=if edge.A==sourceId then edge.B else edge.A; if not context.Selected[other] or idMap[other]==other then boundaryCount+=1 end end
			end
			local definition=build._parts:Get(cloneComponent.PartType)
			for _=1,boundaryCount do
				local socket=build:_findSocketForTransform(mech,definition,cloneComponent.Metadata and cloneComponent.Metadata.MirrorX==true,cloneComponent.LocalTransform,ignored)
				if not socket then return restoreOnFailure(build,request.MechId,player.UserId,before,"GroupMirrorNoBoundarySocket") end
				local targetNode=nodeMap(socket.Target)[socket.TargetNode.Name]; local sourceNode=nodeMap(cloneComponent)[socket.SourceNode.Name]
				if not targetNode or not sourceNode or targetNode.OccupiedBy or sourceNode.OccupiedBy then return restoreOnFailure(build,request.MechId,player.UserId,before,"GroupMirrorNodeState") end
				local ok,result=build._connections:Attach(request.MechId,player.UserId,socket.Target.Id,newId,{SocketA=socket.TargetNode.Name,SocketB=socket.SourceNode.Name})
				if not ok then return restoreOnFailure(build,request.MechId,player.UserId,before,result or "GroupMirrorAttachFailed") end
				targetNode.OccupiedBy=newId; sourceNode.OccupiedBy=socket.Target.Id
			end
		end
	end
	build._mechs:MarkChanged(request.MechId); build:_record(player.UserId,request.MechId,before); build:_realize(request.MechId)
	local created={}; for _,id in ipairs(context.Ids) do if idMap[id]~=id then table.insert(created,idMap[id]) end end
	return true,{MechId=request.MechId,ComponentIds=created,Created=#created,Revision=mech.Revision}
end

function Group.Move(build,player,request)
	local context,reason=validateSelection(build,player,request); if not context then return false,reason end
	local delta=request.Delta; if not validDelta(delta) then return false,"InvalidGroupDelta" end
	local mech=context.Mech
	for _,id in ipairs(context.Ids) do
		local component=mech.Components[id]
		for edgeId in pairs(component.Connections or {}) do
			local edge=mech.Connections[edgeId]
			if edge then local other=if edge.A==id then edge.B else edge.A; if not context.Selected[other] then return false,"GroupHasExternalConnections" end end
		end
	end
	local exclusions={}
	for _,id in ipairs(context.Ids) do local model=build:_componentModel(request.MechId,id); if model then table.insert(exclusions,model) end end
	local transforms={}
	for _,id in ipairs(context.Ids) do
		local component=mech.Components[id]; local definition=build._parts:Get(component.PartType); if not definition then return false,"UnknownPartType" end
		local transform=delta*component.LocalTransform
		if not build:_clearance(definition,transform,exclusions) then return false,"GroupCollision" end
		transforms[id]=transform
	end
	local before=build:_snapshot(request.MechId,player.UserId)
	for _,id in ipairs(context.Ids) do mech.Components[id].LocalTransform=transforms[id] end
	build._mechs:MarkChanged(request.MechId); build:_record(player.UserId,request.MechId,before); build:_realize(request.MechId)
	return true,{MechId=request.MechId,Moved=#context.Ids,Revision=mech.Revision}
end

return Group
