--!strict
-- Deterministic helpers shared by authoritative combat and aiming presentation.

local CombatMath = {}
local EPSILON = 1e-6

local function finite(value: number): boolean
	return value == value and value > -math.huge and value < math.huge
end

function CombatMath.IsFiniteVector(value: any): boolean
	return typeof(value) == "Vector3" and finite(value.X) and finite(value.Y) and finite(value.Z)
end

local function safeUnit(direction: Vector3, fallback: Vector3): Vector3
	if CombatMath.IsFiniteVector(direction) and direction.Magnitude > EPSILON then return direction.Unit end
	if fallback.Magnitude > EPSILON then return fallback.Unit end
	return Vector3.new(0,0,-1)
end

function CombatMath.StepDirection(current: Vector3, target: Vector3, radiansPerSecond: number, dt: number): Vector3
	local from = safeUnit(current, Vector3.new(0,0,-1))
	local to = safeUnit(target, from)
	local angle = math.acos(math.clamp(from:Dot(to), -1, 1))
	local maxStep = math.max(0, radiansPerSecond) * math.max(0, dt)
	if angle <= EPSILON or angle <= maxStep then return to end
	local axis = from:Cross(to)
	if axis.Magnitude <= EPSILON then
		axis = from:Cross(Vector3.yAxis)
		if axis.Magnitude <= EPSILON then axis = from:Cross(Vector3.xAxis) end
	end
	return CFrame.fromAxisAngle(axis.Unit, maxStep):VectorToWorldSpace(from).Unit
end

function CombatMath.ClampDirection(rest: CFrame, requested: Vector3, yawArcDegrees: number, pitchArcDegrees: number): Vector3
	local requestedUnit = safeUnit(requested, rest.LookVector)
	local localDirection = rest:VectorToObjectSpace(requestedUnit)
	local yaw = math.atan2(localDirection.X, -localDirection.Z)
	local pitch = math.asin(math.clamp(localDirection.Y, -1, 1))
	local yawLimit = math.rad(math.clamp(yawArcDegrees, 0, 180))
	local pitchLimit = math.rad(math.clamp(pitchArcDegrees, 0, 89.9))
	yaw = math.clamp(yaw, -yawLimit, yawLimit)
	pitch = math.clamp(pitch, -pitchLimit, pitchLimit)
	local cosPitch = math.cos(pitch)
	local localClamped = Vector3.new(math.sin(yaw)*cosPitch, math.sin(pitch), -math.cos(yaw)*cosPitch)
	return rest:VectorToWorldSpace(localClamped).Unit
end

function CombatMath.SpreadDirection(direction: Vector3, spreadDegrees: number, seed: number): Vector3
	local unit = safeUnit(direction, Vector3.new(0,0,-1))
	local spread = math.rad(math.max(0, spreadDegrees))
	if spread <= EPSILON then return unit end
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

-- Returns the firing direction required to meet a linearly moving target, or nil when no positive intercept exists.
function CombatMath.InterceptDirection(origin: Vector3, targetPosition: Vector3, targetVelocity: Vector3, projectileSpeed: number): Vector3?
	if not CombatMath.IsFiniteVector(origin) or not CombatMath.IsFiniteVector(targetPosition) or not CombatMath.IsFiniteVector(targetVelocity) then return nil end
	local speed = math.max(0, projectileSpeed)
	if speed <= EPSILON then return nil end
	local relative = targetPosition - origin
	local a = targetVelocity:Dot(targetVelocity) - speed*speed
	local b = 2 * relative:Dot(targetVelocity)
	local c = relative:Dot(relative)
	local time: number? = nil
	if math.abs(a) <= EPSILON then
		if math.abs(b) <= EPSILON then return safeUnit(relative, Vector3.new(0,0,-1)) end
		local t = -c / b
		if t > EPSILON then time = t end
	else
		local discriminant = b*b - 4*a*c
		if discriminant < 0 then return nil end
		local root = math.sqrt(discriminant)
		local t1 = (-b-root)/(2*a)
		local t2 = (-b+root)/(2*a)
		if t1 > EPSILON and t2 > EPSILON then time = math.min(t1,t2)
		elseif t1 > EPSILON then time = t1
		elseif t2 > EPSILON then time = t2 end
	end
	if not time then return nil end
	local intercept = relative + targetVelocity*time
	if intercept.Magnitude <= EPSILON then return nil end
	return intercept.Unit
end

function CombatMath.Falloff(distance: number, radius: number): number
	if radius <= 0 then return 0 end
	return 1 - math.clamp(math.max(0,distance)/radius, 0, 1)
end

return table.freeze(CombatMath)
