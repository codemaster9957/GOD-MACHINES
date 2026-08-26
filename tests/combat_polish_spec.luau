--!strict
-- Pure combat aiming contract: clamp turret aim, deterministic spread, ballistic lead.

local failures = {}
local function expect(condition: boolean, message: string)
	if not condition then table.insert(failures, message) end
end
local function approx(a: number, b: number, eps: number?): boolean
	return math.abs(a-b) <= (eps or 1e-4)
end

local loaded, CombatMath = pcall(require, "../src/ReplicatedStorage/MechFramework/Shared/CombatMath")
expect(loaded, "CombatMath must exist")

if loaded then
	local rest = CFrame.lookAt(Vector3.zero, Vector3.new(0,0,-1))
	local clamped = CombatMath.ClampDirection(rest, Vector3.new(1,0,0), 30, 20)
	local yaw = math.deg(math.atan2(clamped.X, -clamped.Z))
	expect(approx(yaw, 30, .05), "aim must clamp to configured yaw arc")

	local noSpread = CombatMath.SpreadDirection(Vector3.new(0,0,-1), 0, 123)
	expect((noSpread-Vector3.new(0,0,-1)).Magnitude < 1e-4, "zero spread must preserve aim")
	local spreadA = CombatMath.SpreadDirection(Vector3.new(0,0,-1), 2, 123)
	local spreadB = CombatMath.SpreadDirection(Vector3.new(0,0,-1), 2, 123)
	expect((spreadA-spreadB).Magnitude < 1e-6, "spread must be deterministic for server reconciliation")

	local lead = CombatMath.InterceptDirection(Vector3.zero, Vector3.new(0,0,-100), Vector3.new(10,0,0), 100)
	expect(lead ~= nil and lead.X > 0 and lead.Z < 0, "projectiles must lead moving targets")
	local impossible = CombatMath.InterceptDirection(Vector3.zero, Vector3.new(0,0,-100), Vector3.new(1000,0,0), 10)
	expect(impossible == nil, "impossible intercepts must safely fall back")
end

if #failures > 0 then
	error("COMBAT POLISH SPEC FAILED:\n  - " .. table.concat(failures, "\n  - "), 0)
end
print("COMBAT POLISH SPEC PASSED")
