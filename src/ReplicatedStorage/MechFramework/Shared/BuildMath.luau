--!strict
-- Pure construction geometry shared by preview, renderer and authoritative placement.
local BuildMath = {}

local function cloneArray(values: any): any
	if type(values)~="table" then return values end
	local out={}
	for key,value in pairs(values) do out[key]=value end
	return out
end

function BuildMath.Compatible(a: {[string]: any}, b: {[string]: any}): boolean
	local acceptsA=a.Accepts or {"*"}
	local acceptsB=b.Accepts or {"*"}
	local function has(list,value)
		for _,item in pairs(list) do if item=="*" or item==value then return true end end
		return false
	end
	return has(acceptsA,b.Type) and has(acceptsB,a.Type)
end

-- Reflect a local rigid transform across its X plane while returning a valid right-handed CFrame.
-- For rotation R this is M*R*M, M=diag(-1,1,1); translation is M*p.
function BuildMath.MirrorX(transform: CFrame): CFrame
	local x,y,z,r00,r01,r02,r10,r11,r12,r20,r21,r22=transform:GetComponents()
	return CFrame.new(
		-x,y,z,
		r00,-r01,-r02,
		-r10,r11,r12,
		-r20,r21,r22
	)
end

function BuildMath.Snap(targetWorld: CFrame, targetNode: CFrame, sourceNode: CFrame, quarterTurns: number): CFrame
	local rotation=CFrame.Angles(0,0,math.rad((quarterTurns%4)*90))
	return targetWorld*targetNode*CFrame.Angles(0,math.pi,0)*rotation*sourceNode:Inverse()
end

function BuildMath.AttachmentNodes(definition: {[string]: any}, mirrorX: boolean?): {any}
	local out={}
	for _,node in ipairs(definition.AttachmentNodes or {}) do
		local copy={}
		for key,value in pairs(node) do
			if key=="Accepts" or key=="CompatibleWith" then copy[key]=cloneArray(value) else copy[key]=value end
		end
		if mirrorX==true and typeof(copy.Transform)=="CFrame" then copy.Transform=BuildMath.MirrorX(copy.Transform) end
		table.insert(out,copy)
	end
	return out
end

function BuildMath.Nodes(definition: {[string]: any}, mirrorX: boolean?): {[string]: any}
	local out={}
	for _,node in ipairs(BuildMath.AttachmentNodes(definition,mirrorX)) do out[node.Name]=node end
	return out
end

return table.freeze(BuildMath)