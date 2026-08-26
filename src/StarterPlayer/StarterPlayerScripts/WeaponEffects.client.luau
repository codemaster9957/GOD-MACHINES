--!strict
-- Client-only rendering for sanitized server combat feedback. Never applies damage.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local feedback = ReplicatedStorage
	:WaitForChild("MechFramework")
	:WaitForChild("Remotes")
	:WaitForChild("Events")
	:WaitForChild("CombatFeedback")

local effects = workspace:FindFirstChild("WeaponEffects")
if not effects then
	effects = Instance.new("Folder")
	effects.Name = "WeaponEffects"
	effects.Parent = workspace
end

local function finiteNumber(value: number): boolean
	return value == value
		and value ~= math.huge
		and value ~= -math.huge
		and math.abs(value) <= 1000000
end

local function finiteVector(value: any): boolean
	return typeof(value) == "Vector3"
		and finiteNumber(value.X)
		and finiteNumber(value.Y)
		and finiteNumber(value.Z)
end

local function safeColor(value: any): Color3
	return if typeof(value) == "Color3" then value else Color3.fromRGB(255, 181, 54)
end

local function fade(part: BasePart, lifetime: number)
	local tween = TweenService:Create(
		part,
		TweenInfo.new(lifetime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Transparency = 1 }
	)
	tween:Play()
	Debris:AddItem(part, lifetime + 0.05)
end

local function flash(position: Vector3, color: Color3, size: number, lifetime: number)
	local orb = Instance.new("Part")
	orb.Name = "WeaponFlash"
	orb.Shape = Enum.PartType.Ball
	orb.Size = Vector3.new(size, size, size)
	orb.CFrame = CFrame.new(position)
	orb.Anchored = true
	orb.CanCollide = false
	orb.CanQuery = false
	orb.CanTouch = false
	orb.Material = Enum.Material.Neon
	orb.Color = color
	orb.Transparency = 0.08
	orb.Parent = effects

	local light = Instance.new("PointLight")
	light.Color = color
	light.Brightness = math.clamp(size * 1.5, 1, 8)
	light.Range = math.clamp(size * 5, 6, 24)
	light.Parent = orb

	fade(orb, lifetime)
end

local function streak(origin: Vector3, direction: Vector3, length: number, color: Color3, thickness: number)
	if direction.Magnitude < 0.9 or length <= 0 then
		return
	end

	local unit = direction.Unit
	local beam = Instance.new("Part")
	beam.Name = "WeaponStreak"
	beam.Size = Vector3.new(thickness, thickness, length)
	beam.CFrame = CFrame.lookAt(origin + unit * (length / 2), origin + unit * length)
	beam.Anchored = true
	beam.CanCollide = false
	beam.CanQuery = false
	beam.CanTouch = false
	beam.Material = Enum.Material.Neon
	beam.Color = color
	beam.Transparency = 0.12
	beam.Parent = effects
	fade(beam, 0.12)
end

feedback.OnClientEvent:Connect(function(packet: any)
	if type(packet) ~= "table" or type(packet.Kind) ~= "string" then
		return
	end

	local color = safeColor(packet.Color)
	if packet.Kind == "Fired" then
		if not finiteVector(packet.Origin) or not finiteVector(packet.Direction) then
			return
		end

		local direction: Vector3 = packet.Direction
		if direction.Magnitude < 0.9 then
			return
		end

		local mode = tostring(packet.Mode or "Hitscan")
		local requestedRange = math.clamp(tonumber(packet.Range) or 0, 0, 5000)
		local visibleLength = if mode == "Hitscan" or mode == "Melee" or mode == "Stream"
			then math.min(requestedRange, 140)
			else math.min(requestedRange, 14)
		local thickness = if mode == "Melee" then 0.42 elseif mode == "Stream" then 0.3 else 0.16

		flash(packet.Origin, color, if mode == "Melee" then 1.2 else 0.65, 0.1)
		streak(packet.Origin, direction, visibleLength, color, thickness)
	elseif packet.Kind == "Impact" then
		if not finiteVector(packet.Position) then
			return
		end
		flash(packet.Position, color, if packet.Explosive == true then 2.8 else 0.8, if packet.Explosive == true then 0.3 else 0.16)
	end
end)
