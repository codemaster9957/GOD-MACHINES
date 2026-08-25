--!nonstrict
-- Procedural build ghost. Smart snapping, XYZ orientation and true X mirroring share BuildMath with server placement.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PartRenderer = require(ReplicatedStorage.MechFramework.Shared.PartRenderer)

local BuildPreview={}
BuildPreview.__index=BuildPreview

local AXES={"X","Y","Z"}

local function splitCompatibility(value)
	local out={}
	if type(value)~="string" or value=="" then return out end
	for token in string.gmatch(value,"[^,]+") do table.insert(out,token) end
	return out
end

local function cloneOrientation(value)
	return {X=value.X or 0,Y=value.Y or 0,Z=value.Z or 0}
end

local function freeTransform(hitPosition,size,orientation,BuildMath)
	local rotation=BuildMath.OrientationCFrame(orientation)
	return CFrame.new(hitPosition+Vector3.new(0,size.Y/2,0))*rotation
end

local function componentRootFrom(instance)
	local current=instance
	while current and current~=workspace do
		if current:IsA("BasePart") and current:GetAttribute("ComponentRoot")==true and current:GetAttribute("ComponentId")~=nil then
			return current
		end
		if current:IsA("Model") and current:GetAttribute("ComponentId")~=nil then
			local root=current.PrimaryPart or current:FindFirstChild("Root")
			if root and root:IsA("BasePart") and root:GetAttribute("ComponentRoot")==true then return root end
		end
		current=current.Parent
	end
	return nil
end

function BuildPreview.new(mouse,BuildMath)
	local self=setmetatable({},BuildPreview)
	self.Mouse=mouse; self.BuildMath=BuildMath; self.Enabled=false; self.Definition=nil
	self.Ghost=nil; self.GhostRoot=nil; self.Orientation={X=0,Y=0,Z=0}; self.RotationAxis="Y"; self.MirrorX=false
	self.TargetPart=nil; self.TargetNode=nil; self.SourceNode=nil
	self.PreviewCFrame=CFrame.new(); self.RejectedUntil=0; self.LastState="OFF"; self.Paint=nil
	self.SnapCandidates={}; self.SnapCycle=0; self._snapContextPart=nil
	return self
end

function BuildPreview:_destroyGhost()
	if self.Ghost then self.Ghost:Destroy() end
	self.Ghost=nil; self.GhostRoot=nil
end

function BuildPreview:_createGhost()
	self:_destroyGhost()
	if not self.Definition or typeof(self.Definition.Size)~="Vector3" then return end
	local model,root=PartRenderer.Render(self.Definition,{
		Mode="Preview", Name="GodMachinesBuildGhost", CFrame=self.PreviewCFrame,
		Paint=self.Paint or self.Definition.PaintDefaults, MirrorX=self.MirrorX, Parent=workspace,
	})
	self.Ghost=model; self.GhostRoot=root
end

function BuildPreview:_setVisualState(state)
	if not self.Ghost then return end
	if state=="SNAP" then PartRenderer.SetPreviewState(self.Ghost,"SNAP")
	elseif state=="FREE" then PartRenderer.SetPreviewState(self.Ghost,"FREE")
	else PartRenderer.SetPreviewState(self.Ghost,"INVALID") end
end

function BuildPreview:SetEnabled(enabled)
	self.Enabled=enabled==true
	if self.Enabled then
		if self.Definition then self:_createGhost() end
	else
		self:_destroyGhost(); self.TargetPart,self.TargetNode,self.SourceNode=nil,nil,nil; self.LastState="OFF"
		self.SnapCandidates={}; self.SnapCycle=0; self._snapContextPart=nil
	end
end

function BuildPreview:SetDefinition(definition)
	if type(definition)~="table" or typeof(definition.Size)~="Vector3" or type(definition.Geometry)~="table" then
		self.Definition=nil; self:_destroyGhost(); return false
	end
	self.Definition=definition; self.Paint=definition.PaintDefaults; self.Orientation={X=0,Y=0,Z=0}; self.RotationAxis="Y"; self.MirrorX=false
	self.SnapCandidates={}; self.SnapCycle=0; self._snapContextPart=nil
	if self.Enabled then self:_createGhost() end
	return true
end

function BuildPreview:SetPaint(paint)
	self.Paint=paint
	if self.Ghost and self.Definition then PartRenderer.ApplyPaint(self.Ghost,self.Definition,paint); self:_setVisualState(self.LastState) end
end

function BuildPreview:SetRotationAxis(axis)
	local upper=string.upper(tostring(axis or ""))
	if upper~="X" and upper~="Y" and upper~="Z" then return self.RotationAxis end
	self.RotationAxis=upper
	return self.RotationAxis
end

function BuildPreview:CycleRotationAxis(direction)
	local current=table.find(AXES,self.RotationAxis) or 2
	local delta=if tonumber(direction) and tonumber(direction)<0 then -1 else 1
	current=((current-1+delta)%#AXES)+1
	self.RotationAxis=AXES[current]
	return self.RotationAxis
end

function BuildPreview:Rotate(axis)
	local selected=self:SetRotationAxis(axis or self.RotationAxis)
	self.Orientation[selected]=((tonumber(self.Orientation[selected]) or 0)+1)%4
	return cloneOrientation(self.Orientation),selected
end

function BuildPreview:GetOrientation()
	return cloneOrientation(self.Orientation)
end

function BuildPreview:CycleSnap(direction)
	local delta=if tonumber(direction) and tonumber(direction)<0 then -1 else 1
	self.SnapCycle+=delta
	return self.SnapCycle
end

function BuildPreview:SetMirror(mirrored)
	local nextValue=mirrored==true
	if self.MirrorX==nextValue then return self.MirrorX end
	self.MirrorX=nextValue
	self.SnapCandidates={}; self.SnapCycle=0
	if self.Enabled and self.Definition then
		self:_createGhost()
		self:_moveGhost(self.PreviewCFrame)
		self:_setVisualState(self.LastState)
	end
	return self.MirrorX
end

function BuildPreview:Mirror()
	return self:SetMirror(not self.MirrorX)
end

function BuildPreview:_targetNodeData(attachment)
	local accepts=splitCompatibility(attachment:GetAttribute("Compatibility"))
	if #accepts==0 then accepts={"*"} end
	return {
		Name=attachment.Name,
		Type=tostring(attachment:GetAttribute("NodeType") or ""),
		Transform=attachment.CFrame,
		Accepts=accepts,
		CompatibleWith=accepts,
		Priority=tonumber(attachment:GetAttribute("Priority")) or 0,
	}
end

function BuildPreview:_rankCompatiblePairs(part,hitPosition)
	if not self.Definition or type(self.Definition.AttachmentNodes)~="table" then return {} end
	local targetAttachments={}
	for _,object in ipairs(part:GetChildren()) do
		if object:IsA("Attachment") and object:GetAttribute("BuildNode")==true and object:GetAttribute("Occupied")~=true then
			table.insert(targetAttachments,object)
		end
	end
	local sourceNodes=self.BuildMath.AttachmentNodes(self.Definition,self.MirrorX)
	local camera=workspace.CurrentCamera
	local pairs={}
	for _,attachment in ipairs(targetAttachments) do
		local targetData=self:_targetNodeData(attachment)
		local cursorDistance=(attachment.WorldPosition-hitPosition).Magnitude
		local facingPenalty=0
		if camera then
			local toCamera=camera.CFrame.Position-attachment.WorldPosition
			if toCamera.Magnitude>.001 then
				local facing=math.clamp(attachment.WorldCFrame.LookVector:Dot(toCamera.Unit),-1,1)
				facingPenalty=(1-facing)*.3
			end
		end
		for _,source in ipairs(sourceNodes) do
			if type(source)=="table" and type(source.Name)=="string" and typeof(source.Transform)=="CFrame" then
				local ok,compatible=pcall(self.BuildMath.Compatible,targetData,source)
				if ok and compatible then
					local priority=(tonumber(targetData.Priority) or 0)+(tonumber(source.Priority) or 0)
					local score=cursorDistance+facingPenalty-priority*.002
					table.insert(pairs,{
						Attachment=attachment,
						Source=source,
						Score=score,
						Key=attachment.Name.."|"..source.Name,
					})
				end
			end
		end
	end
	table.sort(pairs,function(a,b)
		if math.abs(a.Score-b.Score)>.0001 then return a.Score<b.Score end
		return a.Key<b.Key
	end)
	return pairs
end

function BuildPreview:_findCompatiblePair(part,hitPosition)
	local pairs=self:_rankCompatiblePairs(part,hitPosition)
	self.SnapCandidates=pairs
	if part~=self._snapContextPart then
		self._snapContextPart=part
		self.SnapCycle=0
	end
	if #pairs==0 then return nil,nil end
	local index=((self.SnapCycle%#pairs)+#pairs)%#pairs+1
	local chosen=pairs[index]
	return chosen.Attachment,chosen.Source
end

function BuildPreview:_moveGhost(transform)
	if self.Ghost then self.Ghost:PivotTo(transform) end
end

function BuildPreview:Update(activeMechId)
	if not self.Enabled or not self.Ghost or not self.Definition then self.LastState="OFF"; return self.LastState end
	self.TargetPart,self.TargetNode,self.SourceNode=nil,nil,nil
	local hitPosition=self.Mouse.Hit.Position
	local candidate=componentRootFrom(self.Mouse.Target)
	self.PreviewCFrame=freeTransform(hitPosition,self.Definition.Size,self.Orientation,self.BuildMath)

	if candidate then
		local candidateMechId=candidate:GetAttribute("MechId")
		if type(activeMechId)~="string" then self:_moveGhost(self.PreviewCFrame); self.LastState="START_ON_GROUND"; self:_setVisualState(self.LastState); return self.LastState end
		if candidateMechId~=activeMechId then self:_moveGhost(self.PreviewCFrame); self.LastState="OTHER_MECH"; self:_setVisualState(self.LastState); return self.LastState end
		local attachment,source=self:_findCompatiblePair(candidate,hitPosition)
		if attachment and source then
			local ok,snapped=pcall(self.BuildMath.Snap,candidate.CFrame,attachment.CFrame,source.Transform,self.Orientation)
			if ok and typeof(snapped)=="CFrame" then
				self.TargetPart=candidate; self.TargetNode=attachment.Name; self.SourceNode=source.Name; self.PreviewCFrame=snapped
				self:_moveGhost(snapped); self.LastState="SNAP"; self:_setVisualState(self.LastState); return self.LastState
			end
		end
		self:_moveGhost(self.PreviewCFrame); self.LastState="NO_COMPATIBLE_NODE"; self:_setVisualState(self.LastState); return self.LastState
	end

	self.SnapCandidates={}; self._snapContextPart=nil; self.SnapCycle=0
	self:_moveGhost(self.PreviewCFrame)
	if os.clock()<self.RejectedUntil then self.LastState="REJECTED"
	elseif type(activeMechId)=="string" then self.LastState="ATTACHMENT_REQUIRED"
	else self.LastState="FREE" end
	self:_setVisualState(self.LastState)
	return self.LastState
end

function BuildPreview:Reject() self.RejectedUntil=os.clock()+.35 end

function BuildPreview:GetPlacement(activeMechId)
	if type(activeMechId)=="string" then
		if self.LastState~="SNAP" or not self.TargetPart then return nil,self.LastState end
	elseif self.LastState~="FREE" then return nil,self.LastState end
	local targetComponentId,targetMechId=nil,nil
	if self.TargetPart then targetComponentId=self.TargetPart:GetAttribute("ComponentId"); targetMechId=self.TargetPart:GetAttribute("MechId") end
	return {
		Transform=self.PreviewCFrame,
		Orientation=cloneOrientation(self.Orientation),
		MirrorX=self.MirrorX,
		TargetComponentId=targetComponentId,
		TargetMechId=targetMechId,
		TargetNode=self.TargetNode,
		SourceNode=self.SourceNode,
	},nil
end

function BuildPreview:Destroy()
	self:_destroyGhost(); self.Enabled=false; self.LastState="OFF"
end

return BuildPreview