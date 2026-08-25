--!strict
-- Deterministic procedural renderer shared by runtime machines and client previews.
-- Spinner roles form motorized rotor assemblies; MirrorX reflects geometry and build nodes from shared BuildMath.

local BuildMath = require(script.Parent:WaitForChild("BuildMath"))
local Renderer = {}

local PREVIEW_COLORS = {
	FREE=Color3.fromRGB(255,184,55), SNAP=Color3.fromRGB(65,255,130), INVALID=Color3.fromRGB(255,65,65),
}

local function safeMaterial(value: any, fallback: Enum.Material): Enum.Material
	if typeof(value)=="EnumItem" and value.EnumType==Enum.Material then return value end
	if type(value)=="string" then
		local ok,result=pcall(function() return (Enum.Material :: any)[value] end)
		if ok and typeof(result)=="EnumItem" then return result end
	end
	return fallback
end

local function regionColor(definition: any, paint: any, region: string): Color3
	if type(paint)=="table" and typeof(paint[region])=="Color3" then return paint[region] end
	local defaults=definition.PaintDefaults
	if type(defaults)=="table" and typeof(defaults[region])=="Color3" then return defaults[region] end
	if type(defaults)=="table" and typeof(defaults.Primary)=="Color3" then return defaults.Primary end
	return Color3.fromRGB(105,110,116)
end

local function makeVisual(kind: string): BasePart
	if kind=="Wedge" then return Instance.new("WedgePart")
	elseif kind=="CornerWedge" then return Instance.new("CornerWedgePart")
	elseif kind=="Seat" then return Instance.new("Seat")
	elseif kind=="VehicleSeat" then return Instance.new("VehicleSeat") end
	local part=Instance.new("Part")
	if kind=="Cylinder" then part.Shape=Enum.PartType.Cylinder elseif kind=="Ball" then part.Shape=Enum.PartType.Ball end
	return part
end

local function configureVehicleSeat(part: BasePart)
	if part:IsA("VehicleSeat") then part.MaxSpeed=0; part.Torque=0; part.TurnSpeed=0 end
end

local function applyIdentity(instance: Instance, attributes: any)
	for key,value in pairs(attributes or {}) do
		if type(key)=="string" then
			local kind=typeof(value)
			if kind=="string" or kind=="number" or kind=="boolean" or kind=="Color3" or kind=="Vector3" or kind=="CFrame" then instance:SetAttribute(key,value) end
		end
	end
end

local function resolvedRole(definition: any, item: any): string
	if type(item.Role)=="string" and item.Role~="" then return item.Role end
	local propulsion=definition.Propulsion
	if propulsion and (propulsion.Kind=="Propeller" or propulsion.Kind=="LiftFan") then
		local name=tostring(item.Name or "")
		if string.match(name,"^Blade") or string.match(name,"^Fan") or string.match(name,"^LiftBlade") then return "PropellerSpinner" end
	end
	return ""
end

local function weld(part0: BasePart, part1: BasePart, parent: Instance, name: string)
	local joint=Instance.new("WeldConstraint")
	joint.Name=name; joint.Part0=part0; joint.Part1=part1; joint.Parent=parent
end

local function localTransform(value: CFrame, mirrorX: boolean): CFrame
	return if mirrorX then BuildMath.MirrorX(value) else value
end

local function hasSeatGeometry(definition: any): boolean
	for _,item in ipairs(definition.Geometry or {}) do
		local kind=tostring(item.Kind or "")
		if kind=="Seat" or kind=="VehicleSeat" then return true end
	end
	return false
end

function Renderer.Render(definition: any, options: any?): (Model, BasePart)
	assert(type(definition)=="table" and typeof(definition.Size)=="Vector3","PartRenderer requires a valid definition")
	options=options or {}
	local mode=if options.Mode=="Preview" then "Preview" else "Runtime"
	local transform=if typeof(options.CFrame)=="CFrame" then options.CFrame else CFrame.identity
	local paint=options.Paint
	local mirrorX=options.MirrorX==true
	local containsSeat=hasSeatGeometry(definition)

	local model=Instance.new("Model")
	model.Name=tostring(options.Name or definition.Id or "Component")
	model:SetAttribute("PartType",tostring(definition.Id or options.PartType or "Unknown"))
	model:SetAttribute("RenderMode",mode)
	model:SetAttribute("MirrorX",mirrorX)
	applyIdentity(model,options.Attributes)

	local root=Instance.new("Part")
	root.Name="Root"
	root.Size=definition.Size
	root.CFrame=transform
	root.Transparency=1
	root.Material=Enum.Material.SmoothPlastic
	root.CastShadow=false
	root.Anchored=mode=="Preview" or options.Anchored==true
	-- Seat-bearing cockpits need an open bounds collider so the avatar can physically reach the seat.
	-- Remote/AI control cores are still solid because they have Pilot metadata but no seat geometry.
	root.CanCollide=mode=="Runtime" and not containsSeat
	root.CanTouch=mode=="Runtime"
	root.CanQuery=mode=="Runtime"
	root.Massless=mode=="Preview"
	root:SetAttribute("ComponentRoot",true)
	root:SetAttribute("PartType",tostring(definition.Id or options.PartType or "Unknown"))
	root:SetAttribute("MirrorX",mirrorX)
	applyIdentity(root,options.Attributes)
	root.Parent=model
	model.PrimaryPart=root

	for _,node in ipairs(BuildMath.AttachmentNodes(definition,mirrorX)) do
		if type(node)=="table" and type(node.Name)=="string" and typeof(node.Transform)=="CFrame" then
			local attachment=Instance.new("Attachment")
			attachment.Name=node.Name; attachment.CFrame=node.Transform
			attachment:SetAttribute("BuildNode",true)
			attachment:SetAttribute("NodeType",tostring(node.Type or ""))
			local compatibility={}
			for _,compatible in ipairs(node.CompatibleWith or node.Accepts or {}) do table.insert(compatibility,tostring(compatible)) end
			attachment:SetAttribute("Compatibility",table.concat(compatibility,","))
			attachment:SetAttribute("Occupied",node.OccupiedBy~=nil)
			attachment:SetAttribute("OccupiedBy",if node.OccupiedBy~=nil then tostring(node.OccupiedBy) else "")
			attachment.Parent=root
		end
	end

	local visuals=Instance.new("Folder")
	visuals.Name="Visuals"; visuals.Parent=model
	local spinnerGroups: {[string]: {any}} = {}

	for _,item in ipairs(definition.Geometry or {}) do
		local visual=makeVisual(tostring(item.Kind or "Block"))
		local itemLocal=localTransform(item.CFrame,mirrorX)
		visual.Name=tostring(item.Name or "Visual")
		visual.Size=item.Size
		visual.CFrame=transform*itemLocal
		local region=tostring(item.Region or "Primary")
		local role=resolvedRole(definition,item)
		visual.Color=regionColor(definition,paint,region)
		local material=item.Material
		if mode=="Runtime" and type(paint)=="table" and paint.Material~=nil and region~="Glass" then material=paint.Material end
		visual.Material=safeMaterial(material,Enum.Material.Metal)
		visual.Transparency=tonumber(item.Transparency) or 0
		visual.CastShadow=mode=="Runtime" and visual.Transparency<.95
		local isSeat=visual:IsA("Seat") or visual:IsA("VehicleSeat")
		visual.CanCollide=mode=="Runtime" and isSeat
		visual.CanQuery=mode=="Runtime" and isSeat
		visual.CanTouch=mode=="Runtime" and isSeat
		visual.Massless=true
		visual.Anchored=mode=="Preview"
		visual:SetAttribute("GMVisual",true)
		visual:SetAttribute("PaintRegion",region)
		visual:SetAttribute("BaseColor",visual.Color)
		visual:SetAttribute("Role",role)
		visual:SetAttribute("MirrorX",mirrorX)
		applyIdentity(visual,options.Attributes)
		configureVehicleSeat(visual)
		visual.Parent=visuals

		if mode=="Runtime" then
			if role~="" and string.find(role,"Spinner") then
				spinnerGroups[role]=spinnerGroups[role] or {}
				table.insert(spinnerGroups[role],{Visual=visual,Item=item,LocalCFrame=itemLocal})
			else
				weld(root,visual,root,"VisualWeld_"..visual.Name)
			end
		else
			visual.Transparency=math.max(visual.Transparency,.35)
		end
	end

	if mode=="Runtime" then
		for role,records in pairs(spinnerGroups) do
			if #records==0 then continue end
			local pivotRecord=records[1]
			for _,record in ipairs(records) do
				local name=tostring(record.Item.Name or "")
				if string.find(name,"Hub") or string.find(name,"Rotor") or string.find(name,"Flywheel") or string.find(name,"Core") then pivotRecord=record; break end
			end
			local pivotLocal=pivotRecord.LocalCFrame
			local pivot=Instance.new("Part")
			pivot.Name=role.."Pivot"; pivot.Size=Vector3.new(.12,.12,.12); pivot.CFrame=transform*pivotLocal
			pivot.Transparency=1; pivot.CastShadow=false; pivot.CanCollide=false; pivot.CanQuery=false; pivot.CanTouch=false
			pivot.Massless=true; pivot.Anchored=false
			pivot:SetAttribute("SpinnerPivot",true); pivot:SetAttribute("Role",role); pivot.Parent=visuals

			local motor=Instance.new("Motor6D")
			motor.Name=role.."Motor"; motor.Part0=root; motor.Part1=pivot; motor.C0=pivotLocal; motor.C1=CFrame.identity
			motor:SetAttribute("Role",role); motor.Parent=root
			for _,record in ipairs(records) do weld(pivot,record.Visual,pivot,"RotorWeld_"..record.Visual.Name) end
		end
	end

	if typeof(options.Parent)=="Instance" then model.Parent=options.Parent end
	return model,root
end

function Renderer.ApplyPaint(model: Model, definition: any, paint: any)
	for _,descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant:GetAttribute("GMVisual")==true then
			local region=tostring(descendant:GetAttribute("PaintRegion") or "Primary")
			local color=regionColor(definition,paint,region)
			descendant.Color=color; descendant:SetAttribute("BaseColor",color)
			if type(paint)=="table" and paint.Material~=nil and region~="Glass" then descendant.Material=safeMaterial(paint.Material,descendant.Material) end
		end
	end
end

function Renderer.SetPreviewState(model: Model, state: string)
	local tint=PREVIEW_COLORS[state] or PREVIEW_COLORS.INVALID
	for _,descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant:GetAttribute("GMVisual")==true then
			local base=descendant:GetAttribute("BaseColor")
			if typeof(base)~="Color3" then base=descendant.Color end
			descendant.Color=(base :: Color3):Lerp(tint,.58)
			descendant.Transparency=math.max(descendant.Transparency,.38)
		end
	end
end

function Renderer.SetSpinner(model: Model, role: string, angle: number)
	for _,descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("Motor6D") and descendant:GetAttribute("Role")==role then descendant.Transform=CFrame.Angles(angle,0,0) end
	end
end

function Renderer.SetAllSpinners(model: Model, angle: number)
	for _,descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("Motor6D") and type(descendant:GetAttribute("Role"))=="string" then descendant.Transform=CFrame.Angles(angle,0,0) end
	end
end

return Renderer