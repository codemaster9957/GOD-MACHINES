--!strict
-- Pure construction geometry shared by preview and authoritative placement.
local BuildMath = {}

function BuildMath.Compatible(a: {[string]: any}, b: {[string]: any}): boolean
	local acceptsA = a.Accepts or {"*"}
	local acceptsB = b.Accepts or {"*"}
	local function has(list, value)
		for _, item in list do if item == "*" or item == value then return true end end
		return false
	end
	return has(acceptsA, b.Type) and has(acceptsB, a.Type)
end

function BuildMath.Snap(targetWorld: CFrame, targetNode: CFrame, sourceNode: CFrame, quarterTurns: number): CFrame
	local rotation = CFrame.Angles(0, 0, math.rad((quarterTurns % 4) * 90))
	return targetWorld * targetNode * CFrame.Angles(0, math.pi, 0) * rotation * sourceNode:Inverse()
end

function BuildMath.Nodes(definition: {[string]: any}): {[string]: any}
	local out = {}
	for _, node in definition.AttachmentNodes or {} do
		out[node.Name] = node
	end
	return out
end

return table.freeze(BuildMath)