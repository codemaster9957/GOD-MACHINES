--!strict
-- Additive, display-only GOD MACHINES experience polish.
-- Authoritative build, combat, trade, save and vehicle state remains server-owned.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local framework = ReplicatedStorage:WaitForChild("MechFramework")
local Catalog = require(framework:WaitForChild("Shared"):WaitForChild("PolishCatalog"))

local TELEMETRY_INTERVAL = 0.10
local MECH_RETRY_INTERVAL = 0.50
local BUILDER_SCAN_INTERVAL = 0.75
local MAX_NOTIFICATIONS = 6
local ONBOARDING_COOLDOWN = 5.0
local HIGH_SPEED_THRESHOLD = 120
local CRITICAL_RATIO = 0.25
local LOW_FUEL_RATIO = 0.18
local HIGH_HEAT_RATIO = 0.85
local DEFAULT_FOV_FOCUS = 8

if Catalog.MasterEnabled ~= true then
	return
end

local palette = {
	Panel = Color3.fromRGB(10, 14, 20),
	PanelRaised = Color3.fromRGB(20, 28, 38),
	Text = Color3.fromRGB(235, 241, 248),
	Muted = Color3.fromRGB(145, 160, 178),
	Accent = Color3.fromRGB(91, 205, 255),
	Good = Color3.fromRGB(99, 226, 151),
	Warn = Color3.fromRGB(255, 190, 71),
	Danger = Color3.fromRGB(255, 86, 99),
	Line = Color3.fromRGB(62, 78, 98),
}

local connections: {RBXScriptConnection} = {}
local function track(connection: RBXScriptConnection): RBXScriptConnection
	table.insert(connections, connection)
	return connection
end

local function prefBool(name: string, fallback: boolean): boolean
	local value = player:GetAttribute(name)
	if type(value) == "boolean" then return value end
	return fallback
end

local function prefNumber(name: string, fallback: number, low: number, high: number): number
	local value = tonumber(player:GetAttribute(name))
	if value == nil then return fallback end
	return math.clamp(value, low, high)
end

local function enabled(id: string): boolean
	return player:GetAttribute("PolishEnabled") ~= false and Catalog.IsEnabled(id)
end

local function rounded(parent: Instance, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = parent
end

local function outlined(parent: Instance, transparency: number?): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.Color = palette.Line
	stroke.Transparency = transparency or 0.25
	stroke.Thickness = 1
	stroke.Parent = parent
	return stroke
end

local function makeLabel(parent: Instance, name: string, size: UDim2, position: UDim2, anchor: Vector2, textSize: number): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.AnchorPoint = anchor
	label.Position = position
	label.Size = size
	label.BackgroundColor3 = palette.Panel
	label.BackgroundTransparency = 0.12
	label.BorderSizePixel = 0
	label.Font = Enum.Font.GothamMedium
	label.Text = ""
	label.TextColor3 = palette.Text
	label.TextSize = textSize
	label.TextWrapped = true
	label.Parent = parent
	rounded(label, 7)
	outlined(label, 0.35)
	return label
end

local function makeFrame(parent: Instance, name: string, size: UDim2, position: UDim2, anchor: Vector2): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.AnchorPoint = anchor
	frame.Position = position
	frame.Size = size
	frame.BackgroundColor3 = palette.Panel
	frame.BackgroundTransparency = 0.12
	frame.BorderSizePixel = 0
	frame.Parent = parent
	rounded(frame, 7)
	outlined(frame, 0.35)
	return frame
end

local gui = Instance.new("ScreenGui")
gui.Name = "GodMachinesPolishHUD"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.DisplayOrder = 17
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

local root = Instance.new("Frame")
root.Name = "Canvas"
root.BackgroundTransparency = 1
root.Size = UDim2.fromScale(1, 1)
root.Parent = gui

local uiScale = Instance.new("UIScale")
uiScale.Name = "ResponsiveScale"
uiScale.Scale = 1
uiScale.Parent = root

local modeChip = makeLabel(root, "ModeChip", UDim2.fromOffset(142, 30), UDim2.fromOffset(18, 18), Vector2.zero, 12)
modeChip.Font = Enum.Font.GothamBold
local machineChip = makeLabel(root, "MachineChip", UDim2.fromOffset(240, 30), UDim2.fromOffset(18, 54), Vector2.zero, 11)
local tradeChip = makeLabel(root, "TradeChip", UDim2.fromOffset(240, 30), UDim2.fromOffset(18, 90), Vector2.zero, 10)
tradeChip.Visible = false

local warningLabel = makeLabel(root, "PriorityWarning", UDim2.fromOffset(520, 42), UDim2.new(0.5, 0, 0, 22), Vector2.new(0.5, 0), 13)
warningLabel.Font = Enum.Font.GothamBold
warningLabel.BackgroundColor3 = palette.PanelRaised
warningLabel.Visible = false

local builderInfo = makeLabel(root, "BuilderInfo", UDim2.fromOffset(330, 70), UDim2.new(0, 18, 1, -128), Vector2.new(0, 1), 10)
builderInfo.TextXAlignment = Enum.TextXAlignment.Left
builderInfo.TextYAlignment = Enum.TextYAlignment.Center
builderInfo.Visible = false

local controlsLegend = makeLabel(root, "ControlsLegend", UDim2.fromOffset(430, 50), UDim2.new(1, -18, 1, -20), Vector2.new(1, 1), 9)
controlsLegend.TextXAlignment = Enum.TextXAlignment.Right
controlsLegend.TextColor3 = palette.Muted

local onboardingLabel = makeLabel(root, "NextStep", UDim2.fromOffset(390, 48), UDim2.new(0, 18, 1, -46), Vector2.new(0, 1), 10)
onboardingLabel.TextXAlignment = Enum.TextXAlignment.Left
onboardingLabel.Visible = false

local helpLabel = makeLabel(root, "HelpHint", UDim2.fromOffset(300, 28), UDim2.new(1, -18, 0, 18), Vector2.new(1, 0), 9)
helpLabel.Text = "F10 CINEMATIC HUD   •   H COMPACT"
helpLabel.TextColor3 = palette.Muted

local telemetry = makeFrame(root, "Telemetry", UDim2.fromOffset(510, 70), UDim2.new(0.5, 0, 1, -18), Vector2.new(0.5, 1))
local speedLabel = makeLabel(telemetry, "Speed", UDim2.fromOffset(122, 48), UDim2.fromOffset(8, 11), Vector2.zero, 18)
speedLabel.BackgroundTransparency = 1
speedLabel.Text = "0 s/s"
speedLabel.Font = Enum.Font.GothamBold
local verticalLabel = makeLabel(telemetry, "Vertical", UDim2.fromOffset(102, 48), UDim2.fromOffset(134, 11), Vector2.zero, 11)
verticalLabel.BackgroundTransparency = 1
local headingLabel = makeLabel(telemetry, "Heading", UDim2.fromOffset(82, 48), UDim2.fromOffset(240, 11), Vector2.zero, 11)
headingLabel.BackgroundTransparency = 1
local motionLabel = makeLabel(telemetry, "Motion", UDim2.fromOffset(172, 48), UDim2.fromOffset(326, 11), Vector2.zero, 10)
motionLabel.BackgroundTransparency = 1

local engineeringLabel = makeLabel(root, "Engineering", UDim2.fromOffset(510, 30), UDim2.new(0.5, 0, 1, -94), Vector2.new(0.5, 1), 9)
engineeringLabel.TextColor3 = palette.Muted

local slotLabel = makeLabel(root, "QuickSlots", UDim2.fromOffset(360, 28), UDim2.new(0.5, 0, 1, -130), Vector2.new(0.5, 1), 9)
slotLabel.Text = "Q1 —   Q2 —   Q3 —   •   V QUICK SWAP"
slotLabel.TextColor3 = palette.Muted

local reticle = Instance.new("Frame")
reticle.Name = "Reticle"
reticle.AnchorPoint = Vector2.new(0.5, 0.5)
reticle.Position = UDim2.fromScale(0.5, 0.5)
reticle.Size = UDim2.fromOffset(60, 60)
reticle.BackgroundTransparency = 1
reticle.Parent = root

local ring = Instance.new("Frame")
ring.Name = "BloomRing"
ring.AnchorPoint = Vector2.new(0.5, 0.5)
ring.Position = UDim2.fromScale(0.5, 0.5)
ring.Size = UDim2.fromOffset(28, 28)
ring.BackgroundTransparency = 1
ring.Parent = reticle
rounded(ring, 999)
local ringStroke = outlined(ring, 0.15)
ringStroke.Color = palette.Text
ringStroke.Thickness = 1.4

local crossLines: {Frame} = {}
for _, data in ipairs({
	{UDim2.fromOffset(2, 10), UDim2.new(0.5, -1, 0.5, -18)},
	{UDim2.fromOffset(2, 10), UDim2.new(0.5, -1, 0.5, 8)},
	{UDim2.fromOffset(10, 2), UDim2.new(0.5, -18, 0.5, -1)},
	{UDim2.fromOffset(10, 2), UDim2.new(0.5, 8, 0.5, -1)},
}) do
	local line = Instance.new("Frame")
	line.BorderSizePixel = 0
	line.BackgroundColor3 = palette.Text
	line.Size = data[1] :: UDim2
	line.Position = data[2] :: UDim2
	line.Parent = reticle
	table.insert(crossLines, line)
end

local hitMarker = makeLabel(reticle, "HitMarker", UDim2.fromOffset(28, 28), UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5), 22)
hitMarker.BackgroundTransparency = 1
hitMarker.Text = "×"
hitMarker.Visible = false

local flash = Instance.new("Frame")
flash.Name = "FeedbackFlash"
flash.Size = UDim2.fromScale(1, 1)
flash.BackgroundColor3 = palette.Text
flash.BackgroundTransparency = 1
flash.BorderSizePixel = 0
flash.ZIndex = 40
flash.Parent = root

local vignetteEdges: {Frame} = {}
for _, data in ipairs({
	{UDim2.new(1, 0, 0, 34), UDim2.fromScale(0, 0)},
	{UDim2.new(1, 0, 0, 34), UDim2.new(0, 0, 1, -34)},
	{UDim2.new(0, 34, 1, 0), UDim2.fromScale(0, 0)},
	{UDim2.new(0, 34, 1, 0), UDim2.new(1, -34, 0, 0)},
}) do
	local edge = Instance.new("Frame")
	edge.Size = data[1] :: UDim2
	edge.Position = data[2] :: UDim2
	edge.BorderSizePixel = 0
	edge.BackgroundColor3 = palette.Danger
	edge.BackgroundTransparency = 1
	edge.ZIndex = 35
	edge.Parent = root
	table.insert(vignetteEdges, edge)
end

local activeMechId: string? = nil
local activeMech: Model? = nil
local activeRoot: BasePart? = nil
local lastResolveAttempt = -math.huge
local lastBuilderScan = -math.huge
local componentCount = 0
local currentMass = 0
local lastAirborne = false
local currentAirborne = false
local currentHealthRatio: number? = nil
local cinematicHidden = false
local compactMode = false
local lastInputType = UserInputService:GetLastInputType()

local held = {
	Forward = false,
	Reverse = false,
	Brake = false,
	Primary = false,
	Secondary = false,
}
local bloom = 0
local firePulse = 0
local secondaryPulse = 0
local hitPulse = 0
local landingPulse = 0
local criticalPulseClock = 0
local aimBaseFov: number? = nil
local lastCamera: Camera? = nil

local quickSlots: {[number]: string} = {}
local activeQuickSlot: number? = nil
local tradeSession: any = nil
local tradeTestEndsAt: number? = nil
local previousTradeSignature = ""

local onboarding = {
	WelcomeShown = false,
	EnteredBuild = false,
	FirstPart = false,
	TenParts = false,
	Tested = false,
	Driven = false,
	Fired = false,
	ReturnedToEdit = false,
	LastHintAt = -math.huge,
}

export type Notice = {
	Key: string,
	Text: string,
	Priority: number,
	ExpiresAt: number,
	Critical: boolean,
}
local notices: {Notice} = {}

local function pushNotice(key: string, text: string, priority: number, duration: number, critical: boolean?)
	local now = os.clock()
	for _, notice in ipairs(notices) do
		if notice.Key == key then
			notice.Text = text
			notice.Priority = priority
			notice.ExpiresAt = now + duration
			notice.Critical = critical == true
			return
		end
	end
	table.insert(notices, {
		Key = key,
		Text = text,
		Priority = priority,
		ExpiresAt = now + duration,
		Critical = critical == true,
	})
	if #notices > MAX_NOTIFICATIONS then
		table.sort(notices, function(a, b)
			if a.Priority == b.Priority then return a.ExpiresAt < b.ExpiresAt end
			return a.Priority < b.Priority
		end)
		table.remove(notices, 1)
	end
end

local function renderNotice()
	local now = os.clock()
	for index = #notices, 1, -1 do
		if notices[index].ExpiresAt <= now then
			table.remove(notices, index)
		end
	end
	table.sort(notices, function(a, b)
		if a.Priority == b.Priority then return a.ExpiresAt < b.ExpiresAt end
		return a.Priority > b.Priority
	end)
	local top = notices[1]
	warningLabel.Visible = top ~= nil and (not cinematicHidden or (top and top.Critical))
	if top then
		warningLabel.Text = top.Text
		warningLabel.TextColor3 = if top.Critical then palette.Danger else if top.Priority >= 70 then palette.Warn else palette.Text
	end
end

local function firstAttribute(instance: Instance?, names: {string}): any
	if not instance then return nil end
	for _, name in ipairs(names) do
		local value = instance:GetAttribute(name)
		if value ~= nil then return value end
	end
	return nil
end

local function numberAttribute(primary: Instance?, secondary: Instance?, names: {string}): number?
	local value = firstAttribute(primary, names)
	if value == nil then value = firstAttribute(secondary, names) end
	local number = tonumber(value)
	return number
end

local function boolAttribute(primary: Instance?, secondary: Instance?, names: {string}): boolean?
	local value = firstAttribute(primary, names)
	if value == nil then value = firstAttribute(secondary, names) end
	return if type(value) == "boolean" then value else nil
end

local function normalizedAttribute(primary: Instance?, secondary: Instance?, ratioNames: {string}, currentNames: {string}, maxNames: {string}): number?
	local direct = numberAttribute(primary, secondary, ratioNames)
	if direct ~= nil then
		if direct > 1 and direct <= 100 then direct /= 100 end
		if direct >= 0 and direct <= 1 then return direct end
	end
	local current = numberAttribute(primary, secondary, currentNames)
	local maximum = numberAttribute(primary, secondary, maxNames)
	if current ~= nil and maximum ~= nil and maximum > 0 then
		return math.clamp(current / maximum, 0, 1)
	end
	return nil
end

local function findRoot(model: Model?): BasePart?
	if not model then return nil end
	if model.PrimaryPart then return model.PrimaryPart end
	for _, child in ipairs(model:GetChildren()) do
		if child:IsA("BasePart") then return child end
		if child:IsA("Model") then
			if child.PrimaryPart then return child.PrimaryPart end
			local rootPart = child:FindFirstChild("Root")
			if rootPart and rootPart:IsA("BasePart") then return rootPart end
		end
	end
	return nil
end

local function clearCombatPresentation()
	held.Primary = false
	held.Secondary = false
	bloom = 0
	firePulse = 0
	secondaryPulse = 0
	if aimBaseFov ~= nil and Workspace.CurrentCamera then
		Workspace.CurrentCamera.FieldOfView = aimBaseFov
	end
	aimBaseFov = nil
end

local function resolveActiveMech(force: boolean?)
	local now = os.clock()
	if not force and now - lastResolveAttempt < MECH_RETRY_INTERVAL then return end
	lastResolveAttempt = now
	local nextId = player:GetAttribute("ActiveMechId")
	if type(nextId) ~= "string" or nextId == "" then
		activeMechId = nil
		activeMech = nil
		activeRoot = nil
		clearCombatPresentation()
		return
	end
	activeMechId = nextId
	local assemblies = Workspace:FindFirstChild("MechAssemblies")
	local found = assemblies and assemblies:FindFirstChild(nextId)
	if found and found:IsA("Model") then
		activeMech = found
		activeRoot = findRoot(found)
	else
		activeMech = nil
		activeRoot = nil
	end
end

local function scanBuilderStats()
	if not activeMech then
		componentCount = 0
		currentMass = 0
		return
	end
	local count = tonumber(firstAttribute(activeMech, {"ComponentCount", "PartsCount"}))
	if count == nil then
		count = 0
		for _, child in ipairs(activeMech:GetChildren()) do
			if child:IsA("Model") or child:GetAttribute("ComponentId") ~= nil then count += 1 end
		end
	end
	componentCount = math.max(0, math.floor(count))
	currentMass = activeRoot and activeRoot.AssemblyMass or tonumber(firstAttribute(activeMech, {"Mass", "TotalMass"})) or 0
end

local function headingFromRoot(part: BasePart): (number, string)
	local look = part.CFrame.LookVector
	local degrees = math.deg(math.atan2(look.X, -look.Z))
	if degrees < 0 then degrees += 360 end
	local names = {"N", "NE", "E", "SE", "S", "SW", "W", "NW"}
	local index = math.floor((degrees + 22.5) / 45) % 8 + 1
	return degrees, names[index]
end

local function isAirborne(part: BasePart, model: Model): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {model}
	params.IgnoreWater = false
	local castDistance = math.max(4, part.Size.Y * 0.5 + 3)
	return Workspace:Raycast(part.Position, Vector3.new(0, -castDistance, 0), params) == nil
end

local function inputMode(): string
	if UserInputService.TouchEnabled and (lastInputType == Enum.UserInputType.Touch) then return "TOUCH" end
	if tostring(lastInputType):find("Gamepad") then return "GAMEPAD" end
	return "KEYBOARD"
end

local function buildLegend(): string
	if inputMode() == "TOUCH" then return "BUILD: USE ON-SCREEN TOOLS • TAP TO PLACE • TEST WHEN READY" end
	if inputMode() == "GAMEPAD" then return "BUILD: CONTROLLER INPUT ACTIVE • USE WORKSHOP UI FOR PART TOOLS" end
	return "B WORKSHOP • 1–9 PARTS • R ROTATE • M MIRROR • C DUPLICATE • X REMOVE • Z/Y UNDO/REDO • T TEST"
end

local function driveLegend(): string
	if inputMode() == "TOUCH" then return "PILOT: USE ON-SCREEN VEHICLE CONTROLS" end
	if inputMode() == "GAMEPAD" then return "PILOT: GAMEPAD ACTIVE • PRIMARY / SECONDARY TO FIRE"
	end
	return "W/S THROTTLE • A/D STEER/ROLL • SPACE BRAKE/RISE • CTRL DESCEND • M1/M2 FIRE • R RELOAD • V SWAP"
end

local function updateResponsiveScale()
	local camera = Workspace.CurrentCamera
	if not camera then return end
	local viewport = camera.ViewportSize
	local baseScale = math.clamp(math.min(viewport.X / 1280, viewport.Y / 720), 0.72, 1.08)
	local textScale = prefNumber("PolishTextScale", 1, 0.8, 1.3)
	uiScale.Scale = baseScale * textScale
	lastCamera = camera
end

local function updateQuickSlots()
	local parts = {}
	for slot = 1, 3 do
		local name = quickSlots[slot]
		local text = if name and name ~= "" then string.upper(name) else "—"
		if #text > 12 then text = text:sub(1, 11) .. "…" end
		local prefix = if activeQuickSlot == slot then "▶Q" else "Q"
		table.insert(parts, prefix .. tostring(slot) .. " " .. text)
	end
	slotLabel.Text = table.concat(parts, "   ") .. "   •   V QUICK SWAP"
end

local function tryBindQuickSwapBridge()
	local playerScripts = player:FindFirstChild("PlayerScripts")
	if not playerScripts then return end
	local bridge = playerScripts:FindFirstChild("GMQuickSwapSlotsChanged")
	if bridge and bridge:IsA("BindableEvent") and bridge:GetAttribute("PolishBound") ~= true then
		bridge:SetAttribute("PolishBound", true)
		track(bridge.Event:Connect(function(nextSlots: any)
			if type(nextSlots) ~= "table" then return end
			for slot = 1, 3 do
				local value = nextSlots[slot]
				quickSlots[slot] = if type(value) == "string" then value else nil
			end
			updateQuickSlots()
		end))
	end
end

local function renderBuilderPanel()
	local buildMode = player:GetAttribute("BuildMode") == true
	builderInfo.Visible = buildMode and not cinematicHidden and enabled("B03")
	if not buildMode or not activeMech then return end

	local powerMargin = numberAttribute(activeMech, player, {"PowerMargin", "PowerSurplus"})
	local thermalMargin = numberAttribute(activeMech, player, {"ThermalMargin", "HeatMargin"})
	local rotation = numberAttribute(activeMech, player, {"BuilderRotationStep", "RotationStep"})
	local placementValid = boolAttribute(activeMech, player, {"PlacementValid", "BuildPlacementValid"})
	local placementReason = firstAttribute(activeMech, {"PlacementReason", "BuildPlacementReason"}) or firstAttribute(player, {"PlacementReason", "BuildPlacementReason"})

	local fields = {}
	if enabled("B03") then table.insert(fields, string.format("PARTS %d", componentCount)) end
	if enabled("B04") then table.insert(fields, string.format("MASS %.0f", currentMass)) end
	if enabled("B05") and powerMargin ~= nil then table.insert(fields, string.format("POWER %+0.1f", powerMargin)) end
	if enabled("B06") and thermalMargin ~= nil then table.insert(fields, string.format("THERMAL %+0.1f", thermalMargin)) end
	if enabled("B08") and rotation ~= nil then table.insert(fields, string.format("ROT %.0f°", rotation)) end
	if enabled("B07") and placementValid ~= nil then
		table.insert(fields, if placementValid then "✓ PLACEMENT READY" else "! PLACEMENT BLOCKED")
		if not placementValid and type(placementReason) == "string" and placementReason ~= "" then
			pushNotice("placement", "! " .. string.upper(placementReason), 68, 1.1)
		end
	end
	builderInfo.Text = table.concat(fields, "   •   ")
end

local function maybeOnboarding(buildMode: boolean)
	if not enabled("O01") then return end
	local now = os.clock()
	local text: string? = nil
	if not onboarding.WelcomeShown then
		onboarding.WelcomeShown = true
		text = "OBJECTIVE: BUILD A MACHINE, TEST IT, THEN TAKE IT INTO COMBAT."
	elseif not onboarding.EnteredBuild then
		text = if inputMode() == "KEYBOARD" then "NEXT: PRESS B TO OPEN THE WORKSHOP." else "NEXT: OPEN BUILD MODE FROM THE WORKSHOP CONTROL."
	elseif not onboarding.FirstPart then
		text = "NEXT: PLACE YOUR FIRST COMPONENT."
	elseif not onboarding.TenParts and componentCount < 10 then
		text = string.format("BUILD MILESTONE: %d/10 COMPONENTS.", componentCount)
	elseif not onboarding.Tested then
		text = if inputMode() == "KEYBOARD" then "NEXT: PRESS T TO TEST YOUR MACHINE." else "NEXT: START A MACHINE TEST."
	elseif not onboarding.Driven then
		text = "NEXT: PILOT THE MACHINE AND CHECK ITS HANDLING."
	elseif not onboarding.Fired then
		text = "NEXT: TRY YOUR PRIMARY WEAPON."
	elseif not onboarding.ReturnedToEdit and not buildMode then
		text = "TIP: RETURN TO EDIT MODE AND TUNE ANY WEAK POINTS."
	end

	if text and now - onboarding.LastHintAt >= ONBOARDING_COOLDOWN then
		onboarding.LastHintAt = now
		pushNotice("next-step", text, 26, 4.5)
	end
	onboardingLabel.Visible = text ~= nil and not cinematicHidden and not compactMode
	onboardingLabel.Text = text or ""
end

local function updateTradePresentation()
	if type(tradeSession) ~= "table" then
		tradeChip.Visible = false
		return
	end
	tradeChip.Visible = not cinematicHidden
	local state = tostring(tradeSession.State or "Selecting")
	local partner = tostring(tradeSession.PartnerName or "PLAYER")
	local accepted = tradeSession.YourAccepted == true
	tradeChip.Text = string.format("TRADE • %s • %s%s", string.upper(partner), string.upper(state), if accepted then " • ✓ READY" else "")

	if state == "Testing" then
		local remaining = math.max(0, (tradeTestEndsAt or os.clock()) - os.clock())
		local mins = math.floor(remaining / 60)
		local secs = math.floor(remaining % 60)
		pushNotice("trade-test", string.format("! TEST DRIVE %d:%02d • NO OWNERSHIP TRANSFER", mins, secs), 92, 0.7, true)
	elseif state == "Review" then
		pushNotice("trade-review", "TRADE TEST COMPLETE • REVIEW BOTH VEHICLES BEFORE ACCEPTING", 82, 2.0)
	elseif state == "Committed" then
		pushNotice("trade-commit", "✓ VEHICLE SWAP COMPLETE • SERVER VERIFIED", 96, 4.0)
	elseif state == "Cancelled" then
		pushNotice("trade-cancel", "! TRADE CANCELLED • " .. string.upper(tostring(tradeSession.CancelReason or "NO TRANSFER")), 90, 3.0)
	end
end

local function connectOptionalFeedback()
	local remotes = framework:FindFirstChild("Remotes")
	local events = remotes and remotes:FindFirstChild("Events")
	if not events then return end

	local CombatFeedback = events:FindFirstChild("CombatFeedback")
	if CombatFeedback and CombatFeedback:IsA("RemoteEvent") then
		track(CombatFeedback.OnClientEvent:Connect(function(payload: any)
			if type(payload) ~= "table" then return end
			local kind = type(payload.Kind) == "string" and payload.Kind or ""
			local message = type(payload.Message) == "string" and payload.Message or nil
			local reason = type(payload.Reason) == "string" and payload.Reason or nil
			if payload.Hit == true or kind == "Hit" then
				hitPulse = 1
				pushNotice("hit-confirm", "× HIT CONFIRMED", 62, 0.55)
			elseif reason or message then
				pushNotice("combat-feedback", "! " .. string.upper(reason or message or "COMBAT FEEDBACK"), 76, 1.5)
			end
		end))
	end

	local tradeState = events:FindFirstChild("VehicleTradeState")
	if tradeState and tradeState:IsA("RemoteEvent") then
		track(tradeState.OnClientEvent:Connect(function(session: any)
			if type(session) ~= "table" then return end
			local signature = tostring(session.YourOffer or "") .. "|" .. tostring(session.PartnerOffer or "")
			if previousTradeSignature ~= "" and signature ~= previousTradeSignature and tradeSession and tradeSession.YourAccepted == true then
				pushNotice("trade-offer-changed", "! TRADE OFFER CHANGED • ACCEPTANCE CLEARED • REVIEW AGAIN", 94, 3.5, true)
			end
			previousTradeSignature = signature
			tradeSession = session
			if session.State == "Testing" then
				tradeTestEndsAt = os.clock() + math.max(0, tonumber(session.TestRemaining) or 0)
			else
				tradeTestEndsAt = nil
			end
			updateTradePresentation()
		end))
	end
end

local function bindCharacter(character: Model)
	local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 5)
	if humanoid and humanoid:IsA("Humanoid") then
		track(humanoid.HealthChanged:Connect(function(health)
			if currentHealthRatio == nil and humanoid.MaxHealth > 0 then
				local ratio = health / humanoid.MaxHealth
				if ratio <= CRITICAL_RATIO then
					pushNotice("player-critical", "! PILOT HEALTH CRITICAL", 98, 1.0, true)
				end
			end
		end))
	end
end

local function setInputState(input: InputObject, active: boolean)
	if input.KeyCode == Enum.KeyCode.W then held.Forward = active end
	if input.KeyCode == Enum.KeyCode.S then held.Reverse = active end
	if input.KeyCode == Enum.KeyCode.Space then held.Brake = active end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		held.Primary = active
		if active and activeMech and player:GetAttribute("BuildMode") ~= true then
			bloom = math.min(1, bloom + 0.45)
			firePulse = 1
			onboarding.Fired = true
			if enabled("C03") and prefBool("PolishScreenFlash", true) then flash.BackgroundTransparency = 0.92 end
		end
	end
	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		held.Secondary = active
		if active then secondaryPulse = 1 end
	end
end

local function refreshVisibility()
	local polishEnabled = player:GetAttribute("PolishEnabled") ~= false
	local buildMode = player:GetAttribute("BuildMode") == true
	local hasMech = activeMechId ~= nil
	root.Visible = polishEnabled
	if not polishEnabled then return end

	modeChip.Visible = not cinematicHidden
	machineChip.Visible = not cinematicHidden and hasMech
	helpLabel.Visible = not cinematicHidden and not compactMode and not held.Secondary
	controlsLegend.Visible = not cinematicHidden and not compactMode and not held.Secondary
	controlsLegend.Text = if buildMode then buildLegend() else driveLegend()
	telemetry.Visible = hasMech and not buildMode and not cinematicHidden and not compactMode
	engineeringLabel.Visible = hasMech and not cinematicHidden and not compactMode
	slotLabel.Visible = hasMech and not buildMode and not cinematicHidden and not compactMode
	reticle.Visible = hasMech and not buildMode and not cinematicHidden

	if buildMode then
		modeChip.Text = "▣ BUILD MODE"
		modeChip.TextColor3 = palette.Accent
	elseif hasMech then
		modeChip.Text = "▶ TEST / PILOT"
		modeChip.TextColor3 = palette.Good
	else
		modeChip.Text = "GOD MACHINES"
		modeChip.TextColor3 = palette.Text
	end
end

local function updateTelemetry()
	if activeMech and activeMech.Parent == nil then
		activeMech = nil
		activeRoot = nil
	end
	if activeMechId and (not activeMech or not activeRoot) then resolveActiveMech(false) end
	if not activeMech or not activeRoot then
		machineChip.Text = if activeMechId then "MACHINE • SYNCING…" else ""
		refreshVisibility()
		return
	end

	if os.clock() - lastBuilderScan >= BUILDER_SCAN_INTERVAL then
		lastBuilderScan = os.clock()
		scanBuilderStats()
	end

	local buildMode = player:GetAttribute("BuildMode") == true
	local velocity = activeRoot.AssemblyLinearVelocity
	local horizontal = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	local vertical = velocity.Y
	currentAirborne = isAirborne(activeRoot, activeMech)
	local degrees, cardinal = headingFromRoot(activeRoot)

	if enabled("V01") then speedLabel.Text = string.format("%.0f s/s", horizontal) end
	if enabled("V02") then
		local arrow = if vertical > 2 then "↑" else if vertical < -2 then "↓" else "•"
		verticalLabel.Text = string.format("%s %.0f V/S", arrow, math.abs(vertical))
	end
	if enabled("W01") then headingLabel.Text = string.format("%s  %03.0f°", cardinal, degrees) end

	local motion = "PARKED"
	if currentAirborne then motion = "AIRBORNE"
	elseif horizontal >= HIGH_SPEED_THRESHOLD then motion = "FAST"
	elseif horizontal > 3 then motion = "ROLLING" end
	local intent = if held.Brake then " ■ BRAKE" else if held.Reverse then " ◀ REVERSE" else if held.Forward then " ▶ THROTTLE" else ""
	motionLabel.Text = motion .. intent
	motionLabel.TextColor3 = if motion == "FAST" then palette.Warn else if motion == "AIRBORNE" then palette.Accent else palette.Text

	if enabled("W03") and lastAirborne and not currentAirborne then
		landingPulse = 1
		if not prefBool("PolishReducedMotion", false) then pushNotice("landing", "↓ CONTACT • LANDING STABLE", 34, 0.7) end
	end
	lastAirborne = currentAirborne
	if not buildMode and horizontal > 4 then onboarding.Driven = true end

	local displayName = tostring(firstAttribute(activeMech, {"DisplayName", "MachineName", "BlueprintName"}) or activeMech.Name)
	local ownership = firstAttribute(activeMech, {"OwnershipState", "TradeState"})
	local ownerUserId = numberAttribute(activeMech, nil, {"OwnerUserId", "Owner"})
	local ownerTag = ""
	if type(ownership) == "string" and ownership ~= "" then
		ownerTag = " • " .. string.upper(ownership)
	elseif ownerUserId ~= nil then
		ownerTag = if ownerUserId == player.UserId then " • YOUR MACHINE" else " • FOREIGN"
	end
	machineChip.Text = "MACHINE • " .. string.upper(displayName) .. ownerTag

	local fuel = normalizedAttribute(activeMech, player, {"FuelPercent", "FuelRatio", "FuelNormalized"}, {"Fuel", "CurrentFuel"}, {"FuelCapacity", "MaxFuel"})
	local heat = normalizedAttribute(activeMech, player, {"HeatPercent", "HeatRatio", "HeatNormalized"}, {"Heat", "CurrentHeat"}, {"HeatCapacity", "MaxHeat"})
	local health = normalizedAttribute(activeMech, player, {"HealthPercent", "HealthRatio", "HealthNormalized"}, {"Health", "CurrentHealth"}, {"MaxHealth", "HealthCapacity"})
	local powerMargin = numberAttribute(activeMech, player, {"PowerMargin", "PowerSurplus"})
	local deficit = boolAttribute(activeMech, player, {"PowerDeficit", "Underpowered"}) == true or (powerMargin ~= nil and powerMargin < 0)
	currentHealthRatio = health

	local engineering = {}
	if fuel ~= nil then table.insert(engineering, string.format("FUEL %d%%", math.floor(fuel * 100 + 0.5))) end
	if heat ~= nil then table.insert(engineering, string.format("HEAT %d%%", math.floor(heat * 100 + 0.5))) end
	if health ~= nil then table.insert(engineering, string.format("HP %d%%", math.floor(health * 100 + 0.5))) end
	if powerMargin ~= nil then table.insert(engineering, string.format("POWER %+0.1f", powerMargin)) end
	engineeringLabel.Text = #engineering > 0 and table.concat(engineering, "   •   ") or "ENGINEERING TELEMETRY • LIVE WHEN MACHINE SERVICES EXPOSE DATA"

	if enabled("V07") and fuel ~= nil and fuel <= LOW_FUEL_RATIO then pushNotice("low-fuel", "! LOW FUEL • RETURN OR REDUCE THROTTLE", 88, 0.8, true) end
	if enabled("V08") and heat ~= nil and heat >= HIGH_HEAT_RATIO then pushNotice("high-heat", "! THERMAL LIMIT • COOL THE MACHINE", 96, 0.8, true) end
	if enabled("V09") and deficit then pushNotice("power-deficit", "! POWER DEFICIT • SYSTEMS MAY THROTTLE", 91, 0.8, true) end
	if enabled("V10") and health ~= nil and health <= CRITICAL_RATIO then pushNotice("machine-critical", "! MACHINE DAMAGE CRITICAL", 100, 0.8, true) end

	local quickSlot = numberAttribute(player, activeMech, {"QuickSwapActiveSlot", "ActiveVehicleSlot"})
	if quickSlot ~= nil then activeQuickSlot = math.clamp(math.floor(quickSlot), 1, 3); updateQuickSlots() end
	local cooldown = numberAttribute(player, activeMech, {"QuickSwapCooldown", "QuickSwapRemaining"})
	if enabled("T06") and cooldown and cooldown > 0 then pushNotice("swap-cooldown", string.format("QUICK SWAP COOLDOWN %.1fs", cooldown), 58, 0.6) end
	local swapBlocked = firstAttribute(player, {"QuickSwapBlockedReason", "SwapBlockedReason"})
	if enabled("T09") and type(swapBlocked) == "string" and swapBlocked ~= "" then pushNotice("swap-blocked", "! SWAP BLOCKED • " .. string.upper(swapBlocked), 86, 1.0) end

	if buildMode then
		onboarding.EnteredBuild = true
		if componentCount > 0 then onboarding.FirstPart = true end
		if componentCount >= 10 then onboarding.TenParts = true end
		if onboarding.Tested then onboarding.ReturnedToEdit = true end
	else
		if onboarding.EnteredBuild and onboarding.FirstPart then onboarding.Tested = true end
	end

	renderBuilderPanel()
	maybeOnboarding(buildMode)
	updateTradePresentation()
	refreshVisibility()
end

local function beginAim()
	local camera = Workspace.CurrentCamera
	if camera and aimBaseFov == nil then aimBaseFov = camera.FieldOfView end
end

local function endAim()
	local camera = Workspace.CurrentCamera
	if camera and aimBaseFov ~= nil and (not prefBool("PolishCameraMotion", true) or prefBool("PolishReducedMotion", false)) then
		camera.FieldOfView = aimBaseFov
	end
end

track(player:GetAttributeChangedSignal("ActiveMechId"):Connect(function()
	resolveActiveMech(true)
	clearCombatPresentation()
	refreshVisibility()
end))
track(player:GetAttributeChangedSignal("BuildMode"):Connect(function()
	if player:GetAttribute("BuildMode") == true then clearCombatPresentation() end
	refreshVisibility()
end))
for _, attribute in ipairs({"PolishEnabled", "PolishReducedMotion", "PolishCameraMotion", "PolishScreenFlash", "PolishVignette", "PolishHighContrast", "PolishCrosshairScale", "PolishTextScale"}) do
	track(player:GetAttributeChangedSignal(attribute):Connect(function()
		updateResponsiveScale()
		refreshVisibility()
	end))
end

track(UserInputService.LastInputTypeChanged:Connect(function(nextType)
	lastInputType = nextType
	refreshVisibility()
end))

track(UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
	if UserInputService:GetFocusedTextBox() then return end
	if not processed and input.KeyCode == Enum.KeyCode.F10 then
		cinematicHidden = not cinematicHidden
		refreshVisibility()
		return
	elseif not processed and input.KeyCode == Enum.KeyCode.H then
		compactMode = not compactMode
		refreshVisibility()
		return
	end
	if player:GetAttribute("BuildMode") == true or not activeMechId then return end
	setInputState(input, true)
	if input.UserInputType == Enum.UserInputType.MouseButton2 then beginAim() end
	if input.KeyCode == Enum.KeyCode.R and enabled("C07") then pushNotice("reload", "↻ RELOAD REQUESTED", 48, 0.8) end
end))

track(UserInputService.InputEnded:Connect(function(input: InputObject)
	setInputState(input, false)
	if input.UserInputType == Enum.UserInputType.MouseButton2 then endAim() end
end))

track(player.CharacterAdded:Connect(bindCharacter))
if player.Character then task.defer(bindCharacter, player.Character) end

track(Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	if lastCamera and aimBaseFov ~= nil then aimBaseFov = nil end
	lastCamera = Workspace.CurrentCamera
	updateResponsiveScale()
end))

local elapsedTelemetry = 0
local bridgeRetry = 0
track(RunService.Heartbeat:Connect(function(dt)
	elapsedTelemetry += dt
	bridgeRetry += dt
	if elapsedTelemetry >= TELEMETRY_INTERVAL then
		elapsedTelemetry %= TELEMETRY_INTERVAL
		updateTelemetry()
		renderNotice()
	end
	if bridgeRetry >= 1 then
		bridgeRetry = 0
		tryBindQuickSwapBridge()
	end
end))

track(RunService.RenderStepped:Connect(function(dt)
	local reducedMotion = prefBool("PolishReducedMotion", false)
	local crosshairScale = prefNumber("PolishCrosshairScale", 1, 0.65, 1.6)
	bloom = math.max(0, bloom - dt * 1.8)
	firePulse = math.max(0, firePulse - dt * 5)
	secondaryPulse = math.max(0, secondaryPulse - dt * 4)
	hitPulse = math.max(0, hitPulse - dt * 6)
	landingPulse = math.max(0, landingPulse - dt * 3)
	criticalPulseClock += dt

	if held.Primary then bloom = math.min(1, bloom + dt * 0.55) end
	local ringSize = (28 + bloom * 20 + firePulse * 8 + secondaryPulse * 4) * crosshairScale
	ring.Size = UDim2.fromOffset(ringSize, ringSize)
	ringStroke.Color = if hitPulse > 0 then palette.Good else if firePulse > 0 then palette.Warn else palette.Text
	hitMarker.Visible = hitPulse > 0
	hitMarker.TextTransparency = 1 - hitPulse

	local highContrast = prefBool("PolishHighContrast", false)
	ringStroke.Thickness = if highContrast then 2.3 else 1.4
	for _, line in ipairs(crossLines) do
		line.BackgroundColor3 = if highContrast then Color3.new(1, 1, 1) else palette.Text
	end

	if prefBool("PolishScreenFlash", true) then
		flash.BackgroundTransparency = math.min(1, flash.BackgroundTransparency + dt * 4)
	else
		flash.BackgroundTransparency = 1
	end

	local critical = currentHealthRatio ~= nil and currentHealthRatio <= CRITICAL_RATIO
	local vignetteAllowed = prefBool("PolishVignette", true) and enabled("C09")
	local pulse = if critical and vignetteAllowed then (if reducedMotion then 0.80 else 0.78 + math.sin(criticalPulseClock * 5) * 0.07) else 1
	for _, edge in ipairs(vignetteEdges) do edge.BackgroundTransparency = pulse end

	local camera = Workspace.CurrentCamera
	if camera then
		if camera ~= lastCamera then lastCamera = camera; updateResponsiveScale() end
		if held.Secondary and enabled("C08") and prefBool("PolishCameraMotion", true) then
			if aimBaseFov == nil then aimBaseFov = camera.FieldOfView end
			local target = math.max(40, (aimBaseFov or camera.FieldOfView) - DEFAULT_FOV_FOCUS)
			if reducedMotion then camera.FieldOfView = target
			else camera.FieldOfView += (target - camera.FieldOfView) * math.min(1, dt * 12) end
		elseif aimBaseFov ~= nil then
			if reducedMotion or not prefBool("PolishCameraMotion", true) then
				camera.FieldOfView = aimBaseFov
				aimBaseFov = nil
			else
				camera.FieldOfView += (aimBaseFov - camera.FieldOfView) * math.min(1, dt * 10)
				if math.abs(camera.FieldOfView - aimBaseFov) < 0.05 then camera.FieldOfView = aimBaseFov; aimBaseFov = nil end
			end
		end
	end

	if warningLabel.Visible and notices[1] and notices[1].Critical and not reducedMotion then
		warningLabel.BackgroundTransparency = 0.08 + math.sin(criticalPulseClock * 5) * 0.04
	else
		warningLabel.BackgroundTransparency = 0.12
	end
end))

connectOptionalFeedback()
tryBindQuickSwapBridge()
resolveActiveMech(true)
updateResponsiveScale()
updateQuickSlots()
refreshVisibility()
pushNotice("welcome-safety", "BUILD • TEST • FIGHT • TRADE SAFELY", 20, 3.0)

script.Destroying:Connect(function()
	clearCombatPresentation()
	for _, connection in ipairs(connections) do
		if connection.Connected then connection:Disconnect() end
	end
	table.clear(connections)
	if gui.Parent then gui:Destroy() end
end)
