--!strict

local roblox = require("@lune/roblox")
local Vector3 = roblox.Vector3
local CFrame = roblox.CFrame

local function assertClose(actual: number, expected: number, epsilon: number, label: string)
	assert(math.abs(actual - expected) <= epsilon, string.format("%s: expected %.6f, got %.6f", label, expected, actual))
end

local function run(CombatMath: any)
	assert(CombatMath.IsFiniteVector(Vector3.new(1, 2, 3)), "finite vector should be accepted")
	assert(not CombatMath.IsFiniteVector(Vector3.new(0 / 0, 0, 0)), "NaN vector should be rejected")
	assert(not CombatMath.IsFiniteVector(Vector3.new(math.huge, 0, 0)), "infinite vector should be rejected")

	local stepped = CombatMath.StepDirection(Vector3.zAxis, Vector3.xAxis, math.rad(90), 0.5)
	local steppedDegrees = math.deg(math.acos(math.clamp(Vector3.zAxis:Dot(stepped), -1, 1)))
	assertClose(steppedDegrees, 45, 0.01, "angular step")

	local rest = CFrame.lookAt(Vector3.zero, Vector3.zAxis)
	local clamped = CombatMath.ClampDirection(rest, Vector3.xAxis, 30, 20)
	local clampedDegrees = math.deg(math.acos(math.clamp(rest.LookVector:Dot(clamped), -1, 1)))
	assert(clampedDegrees <= 30.01, "yaw clamp should respect configured arc")

	local spreadA = CombatMath.SpreadDirection(Vector3.zAxis, 3, 12345)
	local spreadB = CombatMath.SpreadDirection(Vector3.zAxis, 3, 12345)
	assert(spreadA == spreadB, "spread should be deterministic for a shot seed")

	assertClose(CombatMath.Falloff(0, 10), 1, 0.0001, "falloff at centre")
	assertClose(CombatMath.Falloff(5, 10), 0.5, 0.0001, "falloff halfway")
	assertClose(CombatMath.Falloff(10, 10), 0, 0.0001, "falloff at radius")
	assertClose(CombatMath.Falloff(15, 10), 0, 0.0001, "falloff outside radius")
end

return run
