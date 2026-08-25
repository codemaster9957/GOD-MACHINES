--!strict
-- Shared constructors used by the declarative GOD MACHINES part library.
-- H.part intentionally accepts both the canonical category argument and the compact
-- category-in-extra form used by the category modules; both normalize identically.

local H = {}

H.DefaultPaint = table.freeze({
	Primary = Color3.fromRGB(92, 98, 104),
	Secondary = Color3.fromRGB(44, 48, 53),
	Accent = Color3.fromRGB(255, 174, 52),
	Glass = Color3.fromRGB(74, 170, 205),
	Mechanical = Color3.fromRGB(32, 35, 39),
})

local ALL_TYPES = { "Structural", "Utility", "Weapon", "Mobility", "Aero", "Control" }
local VALID_CATEGORIES = table.freeze({
	Structural=true, Armour=true, Mobility=true, Propulsion=true, Aerodynamics=true,
	PowerCooling=true, Control=true, Weapons=true, Utility=true,
})
local VALID_FACES = table.freeze({ Top=true, Bottom=true, Left=true, Right=true, Front=true, Back=true })

local function copyArray(values: {string}?): {string}
	local out = {}
	for _, value in ipairs(values or ALL_TYPES) do table.insert(out, value) end
	return out
end

local function clone(value: any): any
	if type(value) ~= "table" then return value end
	local out = {}
	for key, item in pairs(value) do out[key] = clone(item) end
	return out
end

function H.node(name: string, nodeType: string, transform: CFrame, accepts: {string}?, metadata: any?): any
	local compatible = copyArray(accepts)
	local out: any = { Name=name, Type=nodeType, Transform=transform, Accepts=compatible, CompatibleWith=copyArray(compatible) }
	if type(metadata)=="table" then
		for key,value in pairs(metadata) do out[key]=clone(value) end
	end
	return out
end

local function faceTransform(size: Vector3, face: string, horizontal: number, vertical: number): CFrame
	if face=="Top" then
		return CFrame.new(horizontal,size.Y/2,vertical)*CFrame.Angles(math.pi/2,0,0)
	elseif face=="Bottom" then
		return CFrame.new(horizontal,-size.Y/2,vertical)*CFrame.Angles(-math.pi/2,0,0)
	elseif face=="Left" then
		return CFrame.new(-size.X/2,vertical,horizontal)*CFrame.Angles(0,math.pi/2,0)
	elseif face=="Right" then
		return CFrame.new(size.X/2,vertical,horizontal)*CFrame.Angles(0,-math.pi/2,0)
	elseif face=="Front" then
		return CFrame.new(horizontal,vertical,-size.Z/2)
	elseif face=="Back" then
		return CFrame.new(horizontal,vertical,size.Z/2)*CFrame.Angles(0,math.pi,0)
	end
	error("Unknown attachment face: "..tostring(face))
end

function H.boxNodes(size: Vector3, nodeType: string?, accepts: {string}?): {any}
	local kind = nodeType or "Structural"
	return {
		H.node("Top",kind,faceTransform(size,"Top",0,0),accepts,{Surface="Top",Priority=10}),
		H.node("Bottom",kind,faceTransform(size,"Bottom",0,0),accepts,{Surface="Bottom",Priority=10}),
		-- Side nodes face OUTWARD so wheel/armour/mobility parts mount outside the chassis.
		H.node("Left",kind,faceTransform(size,"Left",0,0),accepts,{Surface="Left",Priority=10}),
		H.node("Right",kind,faceTransform(size,"Right",0,0),accepts,{Surface="Right",Priority=10}),
		H.node("Front",kind,faceTransform(size,"Front",0,0),accepts,{Surface="Front",Priority=10}),
		H.node("Back",kind,faceTransform(size,"Back",0,0),accepts,{Surface="Back",Priority=10}),
	}
end

local function gridCoordinate(index: number, count: number, span: number): number
	if count<=1 then return 0 end
	local alpha=(index-1)/(count-1)
	return (alpha-.5)*span*.72
end

function H.faceGridNodes(size: Vector3, face: string, rows: number, columns: number, nodeType: string?, accepts: {string}?, prefix: string?): {any}
	assert(VALID_FACES[face]==true,"faceGridNodes requires valid face")
	rows=math.max(1,math.floor(rows))
	columns=math.max(1,math.floor(columns))
	local kind=nodeType or "Structural"
	local horizontalSpan: number
	local verticalSpan: number
	if face=="Top" or face=="Bottom" then
		horizontalSpan=size.X; verticalSpan=size.Z
	elseif face=="Left" or face=="Right" then
		horizontalSpan=size.Z; verticalSpan=size.Y
	else
		horizontalSpan=size.X; verticalSpan=size.Y
	end
	local nodes={}
	local stem=prefix or (face.."Grid")
	for row=1,rows do
		for column=1,columns do
			local horizontal=gridCoordinate(column,columns,horizontalSpan)
			local vertical=gridCoordinate(row,rows,verticalSpan)
			local name=string.format("%s_%02d_%02d",stem,row,column)
			table.insert(nodes,H.node(name,kind,faceTransform(size,face,horizontal,vertical),accepts,{
				Surface=face,
				Role="SurfaceGrid",
				Priority=20,
			}))
		end
	end
	return nodes
end

function H.mergeNodes(...: {any}): {any}
	local out={}
	for _,list in ipairs({...}) do
		for _,node in ipairs(list or {}) do table.insert(out,node) end
	end
	return out
end

function H.offsetNode(node: any, name: string, offset: CFrame): any
	assert(type(node)=="table" and typeof(node.Transform)=="CFrame","offsetNode requires valid source node")
	local out=clone(node)
	out.Name=name
	out.Transform=node.Transform*offset
	return out
end

local function primitive(kind: string, name: string, size: Vector3, transform: CFrame?, region: string?, material: Enum.Material?, role: string?): any
	return {
		Kind=kind, Name=name, Size=size, CFrame=transform or CFrame.identity,
		Region=region or "Primary", Material=material or Enum.Material.Metal, Role=role,
	}
end

function H.block(name: string, size: Vector3, transform: CFrame?, region: string?, material: Enum.Material?, role: string?): any
	return primitive("Block",name,size,transform,region,material,role)
end
function H.wedge(name: string, size: Vector3, transform: CFrame?, region: string?, material: Enum.Material?): any
	return primitive("Wedge",name,size,transform,region,material,nil)
end
function H.cornerWedge(name: string, size: Vector3, transform: CFrame?, region: string?, material: Enum.Material?): any
	return primitive("CornerWedge",name,size,transform,region,material,nil)
end
function H.cylinder(name: string, size: Vector3, transform: CFrame?, region: string?, material: Enum.Material?, role: string?): any
	return primitive("Cylinder",name,size,transform,region,material,role)
end
function H.ball(name: string, size: Vector3, transform: CFrame?, region: string?, material: Enum.Material?): any
	return primitive("Ball",name,size,transform,region,material,nil)
end
function H.seat(name: string, size: Vector3, transform: CFrame?, region: string?, vehicle: boolean?): any
	return primitive(if vehicle then "VehicleSeat" else "Seat",name,size,transform,region,Enum.Material.Metal,"PilotSeat")
end
function H.glass(name: string, size: Vector3, transform: CFrame?, region: string?): any
	local out=primitive("Block",name,size,transform,region or "Glass",Enum.Material.Glass,nil)
	out.Transparency=.28
	return out
end

function H.radialBlades(prefix: string, count: number, radius: number, length: number, width: number, depth: number, center: CFrame?, region: string?): {any}
	local out = {}
	local base=center or CFrame.identity
	for index=1,count do
		local angle=((index-1)/count)*math.pi*2
		local transform=base*CFrame.Angles(angle,0,0)*CFrame.new(0,radius,0)
		table.insert(out,H.wedge(prefix..tostring(index),Vector3.new(depth,length,width),transform,region or "Accent",Enum.Material.Metal))
	end
	return out
end

function H.append(target: {any}, values: {any})
	for _, value in ipairs(values) do table.insert(target,value) end
end

-- Canonical:
-- H.part(id, display, short, category, description, size, mass, health, geometry, extra?)
-- Compact category-module form:
-- H.part(id, display, short, description, size, mass, health, geometry, {Category=...})
function H.part(id: string, displayName: string, shortName: string, a4: any, a5: any, a6: any, a7: any, a8: any, a9: any?, a10: any?): any
	local category: any
	local description: any
	local size: any
	local mass: any
	local health: any
	local geometry: any
	local extra: any

	if type(a4)=="string" and VALID_CATEGORIES[a4]==true then
		category=a4; description=a5; size=a6; mass=a7; health=a8; geometry=a9; extra=a10 or {}
	else
		description=a4; size=a5; mass=a6; health=a7; geometry=a8; extra=a9 or {}
		category=if type(extra)=="table" then (extra.Category or "Structural") else "Structural"
	end

	assert(type(id)=="string" and id~="","Part requires non-empty id")
	assert(type(displayName)=="string" and displayName~="",id.." requires display name")
	assert(type(shortName)=="string" and shortName~="",id.." requires short name")
	assert(type(category)=="string" and VALID_CATEGORIES[category]==true,id.." requires valid category")
	assert(type(description)=="string" and #description>=12,id.." requires useful description")
	assert(typeof(size)=="Vector3" and size.X>0 and size.Y>0 and size.Z>0,id.." requires positive size")
	assert(type(mass)=="number" and mass>0,id.." requires positive mass")
	assert(type(health)=="number" and health>0,id.." requires positive health")
	assert(type(geometry)=="table" and #geometry>=2,id.." requires multi-primitive geometry")
	assert(type(extra)=="table",id.." extra data must be a table")

	local definition: any = {
		Id=id,
		DisplayName=displayName,
		ShortName=shortName,
		Category=category,
		Description=description,
		Size=size,
		Mass=mass,
		MaxHealth=health,
		Rarity="Common",
		Stackable=true,
		PaintDefaults=clone(H.DefaultPaint),
		PaintRegions={"Primary","Secondary","Accent","Glass","Mechanical"},
		AttachmentNodes=H.boxNodes(size,"Structural"),
		PhysicalProperties={Density=1,StructuralStrength=health*1.45},
		Geometry=geometry,
	}
	for key,value in pairs(extra) do
		if key~="Category" then definition[key]=value end
	end
	return definition
end

return H
