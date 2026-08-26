--!strict
-- Pure deterministic helpers shared by server combat and client presentation.

local CombatMath = {}

local EPSILON = 1e-6

local function finite(value: number): boolean
	return value == value and value > -math.huge and value < math.huge
end

function CombatMath.IsFiniteVector(value: any): boolean
	return typeof(value) == "Vector3"
		and finite(value.X)
		and finite(value.Y)
		and finite(value.Z)
end

local function safeUnit(direction: Vector3, fallback: Vector3): Vector3
	if CombatMath.IsFiniteVector(direction) and direction.Magnitude > EPSILON then
		return direction.Unit
	end
	return fallback.Unit
end

function CombatMath.StepDirection(
	current: Vector3,
	target: Vector3,
	radiansPerSecond: number,
	dt: number
): Vector3
	local from = safeUnit(current, Vector3.zAxis)
	local to = safeUnit(target, from)
	local angle = math.acos(math.clamp(from:Dot(to), -1, 1))
	local maxStep = math.max(0, radiansPerSecond) * math.max(0, dt)
	if angle <= EPSILON or angle <= maxStep then
		return to
	end

	local axis = from:Cross(to)
	if axis.Magnitude <= EPSILON then
		axis = from:Cross(Vector3.yAxis)
		if axis.Magnitude <= EPSILON then
			axis = from:Cross(Vector3.xAxis)
		end
	end

	return CFrame.fromAxisAngle(axis.Unit, maxStep):VectorToWorldSpace(from).Unit
end

function CombatMath.ClampDirection(
	rest: CFrame,
	requested: Vector3,
	yawArcDegrees: number,
	pitchArcDegrees: number
): Vector3
	local requestedUnit = safeUnit(requested, rest.LookVector)
	local localDirection = rest:VectorToObjectSpace(requestedUnit)
	local yaw = math.atan2(localDirection.X, -localDirection.Z)
	local pitch = math.asin(math.clamp(localDirection.Y, -1, 1))

	local yawLimit = math.rad(math.clamp(yawArcDegrees, 0, 180))
	local pitchLimit = math.rad(math.clamp(pitchArcDegrees, 0, 89.9))
	yaw = math.clamp(yaw, -yawLimit, yawLimit)
	pitch = math.clamp(pitch, -pitchLimit, pitchLimit)

	local cosPitch = math.cos(pitch)
	local localClamped = Vector3.new(
		math.sin(yaw) * cosPitch,
		math.sin(pitch),
		-math.cos(yaw) * cosPitch
	)
	return rest:VectorToWorldSpace(localClamped).Unit
end

function CombatMath.SpreadDirection(direction: Vector3, spreadDegrees: number, seed: number): Vector3
	local unit = safeUnit(direction, Vector3.zAxis)
	local spread = math.rad(math.max(0, spreadDegrees))
	if spread <= EPSILON then
		return unit
	end

	local state = math.max(1, math.abs(math.floor(seed)) % 2147483647)
	local function nextSigned(): number
		state = (state * 48271) % 2147483647
		return (state / 2147483647) * 2 - 1
	end
	local yaw = nextSigned() * spread
	local pitch = nextSigned() * spread
	local basis = CFrame.lookAt(Vector3.zero, unit)
	return (basis * CFrame.Angles(pitch, yaw, 0)).LookVector.Unit
end

function CombatMath.Falloff(distance: number, radius: number): number
	if radius <= 0 then
		return 0
	end
	return 1 - math.clamp(math.max(0, distance) / radius, 0, 1)
end

return table.freeze(CombatMath)
