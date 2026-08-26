--!nonstrict
-- GOD MACHINES Workshop V3
-- Industrial command-deck interface: procedural 3D catalog, tabbed tools, live engineering telemetry.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local PartRenderer = require(ReplicatedStorage:WaitForChild("MechFramework"):WaitForChild("Shared"):WaitForChild("PartRenderer"))

local BuildUI = {}
BuildUI.__index = BuildUI

local COLORS = {
	Void = Color3.fromRGB(7, 8, 10),
	Deck = Color3.fromRGB(12, 14, 17),
	Panel = Color3.fromRGB(18, 21, 25),
	PanelRaised = Color3.fromRGB(25, 29, 34),
	PanelHover = Color3.fromRGB(32, 36, 41),
	Border = Color3.fromRGB(66, 73, 80),
	BorderSoft = Color3.fromRGB(43, 48, 53),
	Text = Color3.fromRGB(238, 241, 243),
	Muted = Color3.fromRGB(137, 145, 153),
	Dim = Color3.fromRGB(87, 94, 101),
	Amber = Color3.fromRGB(255, 178, 48),
	AmberSoft = Color3.fromRGB(91, 67, 31),
	AmberDeep = Color3.fromRGB(52, 40, 22),
	Good = Color3.fromRGB(88, 227, 139),
	Bad = Color3.fromRGB(255, 80, 78),
	Blue = Color3.fromRGB(93, 173, 255),
	Purple = Color3.fromRGB(183, 117, 255),
}

local RARITY_COLORS = {
	Common = Color3.fromRGB(151, 158, 166),
	Uncommon = Color3.fromRGB(92, 206, 128),
	Rare = Color3.fromRGB(89, 154, 255),
	Epic = Color3.fromRGB(174, 99, 255),
	Legendary = Color3.fromRGB(255, 177, 55),
	Experimental = Color3.fromRGB(216, 103, 255),
}

local MATERIALS = {"Metal", "SmoothPlastic", "DiamondPlate", "CorrodedMetal", "Granite", "Slate"}
local CONTROL_ACTIONS = {
	"ThrottleForward", "ThrottleReverse", "SteerLeft", "SteerRight", "StrafeLeft", "StrafeRight", "Brake",
	"VerticalUp", "VerticalDown", "PitchUp", "PitchDown", "YawLeft", "YawRight", "RollLeft", "RollRight",
	"Primary", "Secondary", "Utility", "Reload", "Mechanism1", "Mechanism2",
}
local WORKSHOP_TABS = {"PART", "PAINT", "BLUEPRINTS", "CONTROLS"}

local CATEGORY_GLYPHS = {
	ALL = "ALL", Structural = "STR", Armour = "ARM", Mobility = "MOV", Propulsion = "THR",
	Aerodynamics = "AERO", ["Power & Cooling"] = "PWR", PowerCooling = "PWR",
	Control = "CTL", Weapons = "WPN", Utility = "UTL",
}

local function corner(parent, radius)
	local item = Instance.new("UICorner")
	item.CornerRadius = UDim.new(0, radius or 5)
	item.Parent = parent
	return item
end

local function stroke(parent, color, transparency, thickness)
	local item = Instance.new("UIStroke")
	item.Color = color or COLORS.Border
	item.Transparency = transparency or 0
	item.Thickness = thickness or 1
	item.Parent = parent
	return item
end

local function gradient(parent, topColor, bottomColor, rotation)
	local item = Instance.new("UIGradient")
	item.Color = ColorSequence.new(topColor, bottomColor)
	item.Rotation = rotation or 90
	item.Parent = parent
	return item
end

local function padding(parent, left, right, top, bottom)
	local item = Instance.new("UIPadding")
	item.PaddingLeft = UDim.new(0, left or 0)
	item.PaddingRight = UDim.new(0, right or 0)
	item.PaddingTop = UDim.new(0, top or 0)
	item.PaddingBottom = UDim.new(0, bottom or 0)
	item.Parent = parent
	return item
end

local function label(parent, text, size, bold)
	local item = Instance.new("TextLabel")
	item.BackgroundTransparency = 1
	item.Text = text or ""
	item.TextColor3 = COLORS.Text
	item.TextSize = size or 12
	item.Font = if bold then Enum.Font.GothamBold else Enum.Font.GothamMedium
	item.TextXAlignment = Enum.TextXAlignment.Left
	item.TextYAlignment = Enum.TextYAlignment.Center
	item.Parent = parent
	return item
end

local function tween(instance, properties, duration)
	local info = TweenInfo.new(duration or 0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local animation = TweenService:Create(instance, info, properties)
	animation:Play()
	return animation
end

local function panel(parent, name)
	local frame = Instance.new("Frame")
	frame.Name = name or "Panel"
	frame.BackgroundColor3 = COLORS.Panel
	frame.BorderSizePixel = 0
	frame.Parent = parent
	corner(frame, 8)
	stroke(frame, COLORS.BorderSoft, 0.18, 1)
	gradient(frame, COLORS.PanelRaised, COLORS.Panel, 90)
	return frame
end

local function applyButtonVisual(item)
	if item:GetAttribute("Disabled") == true then
		item.BackgroundColor3 = COLORS.Panel
		item.TextColor3 = COLORS.Dim
	elseif item:GetAttribute("Selected") == true then
		item.BackgroundColor3 = COLORS.AmberDeep
		item.TextColor3 = COLORS.Amber
	else
		item.BackgroundColor3 = COLORS.PanelRaised
		item.TextColor3 = COLORS.Text
	end
end

local function button(parent, text, width, height)
	local item = Instance.new("TextButton")
	item.Size = UDim2.fromOffset(width or 100, height or 32)
	item.BackgroundColor3 = COLORS.PanelRaised
	item.BorderSizePixel = 0
	item.Text = text or ""
	item.TextSize = 10
	item.Font = Enum.Font.GothamBold
	item.TextColor3 = COLORS.Text
	item.AutoButtonColor = false
	item.Parent = parent
	item:SetAttribute("Disabled", false)
	item:SetAttribute("Selected", false)
	corner(item, 5)
	stroke(item, COLORS.BorderSoft, 0.1, 1)
	item.MouseEnter:Connect(function()
		if item:GetAttribute("Disabled") ~= true and item:GetAttribute("Selected") ~= true then
			tween(item, {BackgroundColor3 = COLORS.PanelHover}, 0.1)
		end
	end)
	item.MouseLeave:Connect(function()
		applyButtonVisual(item)
	end)
	return item
end

local function textbox(parent, placeholder, height)
	local item = Instance.new("TextBox")
	item.Size = UDim2.new(1, 0, 0, height or 34)
	item.BackgroundColor3 = COLORS.Void
	item.BackgroundTransparency = 0.08
	item.BorderSizePixel = 0
	item.PlaceholderText = placeholder or ""
	item.PlaceholderColor3 = COLORS.Dim
	item.Text = ""
	item.TextColor3 = COLORS.Text
	item.TextSize = 11
	item.Font = Enum.Font.GothamMedium
	item.TextXAlignment = Enum.TextXAlignment.Left
	item.ClearTextOnFocus = false
	item.Parent = parent
	corner(item, 5)
	stroke(item, COLORS.BorderSoft, 0.15, 1)
	padding(item, 10, 10, 0, 0)
	return item
end

local function colorToHex(color)
	return string.format("#%02X%02X%02X", math.floor(color.R * 255 + 0.5), math.floor(color.G * 255 + 0.5), math.floor(color.B * 255 + 0.5))
end

local function parseHex(text)
	if type(text) ~= "string" then return nil end
	local value = string.upper(text):gsub("#", ""):gsub("%s", "")
	if #value == 3 then value = value:sub(1, 1):rep(2) .. value:sub(2, 2):rep(2) .. value:sub(3, 3):rep(2) end
	if #value ~= 6 or value:find("[^0-9A-F]") then return nil end
	local r, g, b = tonumber(value:sub(1, 2), 16), tonumber(value:sub(3, 4), 16), tonumber(value:sub(5, 6), 16)
	if not r or not g or not b then return nil end
	return Color3.fromRGB(r, g, b)
end

local function clearGuiChildren(parent)
	for _, child in ipairs(parent:GetChildren()) do
		if child:IsA("GuiObject") then child:Destroy() end
	end
end

local function prettyDate(timestamp)
	local value = tonumber(timestamp) or 0
	if value <= 0 then return "UNSAVED" end
	local ok, result = pcall(function() return os.date("%d %b %Y  %H:%M", value) end)
	return if ok then string.upper(result) else "SAVED"
end

local function makeViewport(parent, name)
	local viewport = Instance.new("ViewportFrame")
	viewport.Name = name or "PartViewport"
	viewport.BackgroundColor3 = COLORS.Void
	viewport.BackgroundTransparency = 0.12
	viewport.BorderSizePixel = 0
	viewport.Ambient = Color3.fromRGB(120, 124, 128)
	viewport.LightColor = Color3.fromRGB(255, 224, 174)
	viewport.LightDirection = Vector3.new(-0.7, -1, -0.5)
	viewport.Parent = parent
	corner(viewport, 6)
	stroke(viewport, COLORS.BorderSoft, 0.25, 1)
	return viewport
end

local function renderDefinition(viewport, definition, mirrored)
	viewport:ClearAllChildren()
	corner(viewport, 6)
	stroke(viewport, COLORS.BorderSoft, 0.25, 1)
	if type(definition) ~= "table" then return end

	local world = Instance.new("WorldModel")
	world.Name = "PreviewWorld"
	world.Parent = viewport
	local model = PartRenderer.Render(definition, {
		Mode = "Preview",
		CFrame = CFrame.identity,
		MirrorX = mirrored == true,
		Name = "CatalogPreview",
	})
	model.Parent = world

	local camera = Instance.new("Camera")
	camera.Name = "PreviewCamera"
	camera.FieldOfView = 34
	camera.Parent = viewport
	viewport.CurrentCamera = camera

	local boundsCFrame, boundsSize = model:GetBoundingBox()
	local radius = math.max(boundsSize.X, boundsSize.Y, boundsSize.Z, 1)
	local target = boundsCFrame.Position
	local offset = Vector3.new(radius * 0.9, radius * 0.62, radius * 1.45)
	camera.CFrame = CFrame.lookAt(target + offset, target)
end

local function addHeaderAccent(frame)
	local accent = Instance.new("Frame")
	accent.Name = "AmberRail"
	accent.Size = UDim2.new(0, 5, 1, -12)
	accent.Position = UDim2.fromOffset(6, 6)
	accent.BackgroundColor3 = COLORS.Amber
	accent.BorderSizePixel = 0
	accent.Parent = frame
	corner(accent, 3)
end

function BuildUI.new(playerGui, callbacks)
	local self = setmetatable({}, BuildUI)
	self.Callbacks = callbacks or {}
	self.Catalog = {}
	self.Categories = {}
	self.InventoryCounts = {}
	self.InventoryButtons = {}
	self.HotbarButtons = {}
	self.HotbarIds = {}
	self.Favorites = {}
	self.Blueprints = {}
	self.CatalogCards = {}
	self.CategoryButtons = {}
	self.PaintRegionButtons = {}
	self.TabPages = {}
	self.TabButtons = {}
	self.SelectedPart = nil
	self.SelectedCategory = "ALL"
	self.SearchText = ""
	self.PaintRegion = "All"
	self.PaintRegions = {"All"}
	self.PaintColor = Color3.fromRGB(214, 218, 222)
	self.MaterialIndex = 1
	self.BindingIndex = 1
	self.NodeVisible = true
	self.Mirrored = false
	self.ActiveTab = "PART"

	local gui = Instance.new("ScreenGui")
	gui.Name = "GodMachinesBuildUI"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 20
	gui.Parent = playerGui
	self.Gui = gui

	local hint = panel(gui, "WorkshopHint")
	hint.AnchorPoint = Vector2.new(0.5, 1)
	hint.Position = UDim2.new(0.5, 0, 1, -18)
	hint.Size = UDim2.fromOffset(292, 42)
	local hintText = label(hint, "[ B ]   OPEN MACHINE WORKSHOP", 11, true)
	hintText.Size = UDim2.fromScale(1, 1)
	hintText.TextXAlignment = Enum.TextXAlignment.Center
	hintText.TextColor3 = COLORS.Amber
	self.Hint = hint

	local root = Instance.new("CanvasGroup")
	root.Name = "WorkshopRoot"
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundTransparency = 1
	root.Visible = false
	root.Parent = gui
	self.Root = root

	-- COMMAND DECK
	local commandDeck = panel(root, "CommandDeck")
	commandDeck.Position = UDim2.fromOffset(16, 14)
	commandDeck.Size = UDim2.new(1, -32, 0, 64)
	addHeaderAccent(commandDeck)
	self.CommandDeck = commandDeck

	local title = label(commandDeck, "GOD MACHINES", 17, true)
	title.Position = UDim2.fromOffset(23, 8)
	title.Size = UDim2.fromOffset(220, 23)
	title.TextColor3 = COLORS.Amber
	local subtitle = label(commandDeck, "COMMAND DECK  /  WORKSHOP V3", 9, true)
	subtitle.Position = UDim2.fromOffset(24, 31)
	subtitle.Size = UDim2.fromOffset(250, 18)
	subtitle.TextColor3 = COLORS.Muted

	local modeLabel = label(commandDeck, "EDIT", 10, true)
	modeLabel.Position = UDim2.fromOffset(268, 17)
	modeLabel.Size = UDim2.fromOffset(72, 30)
	modeLabel.BackgroundTransparency = 0
	modeLabel.BackgroundColor3 = Color3.fromRGB(23, 55, 39)
	modeLabel.TextColor3 = COLORS.Good
	modeLabel.TextXAlignment = Enum.TextXAlignment.Center
	corner(modeLabel, 5)
	stroke(modeLabel, COLORS.Good, 0.55, 1)
	self.ModeLabel = modeLabel

	local EngineeringStrip = Instance.new("Frame")
	EngineeringStrip.Name = "EngineeringStrip"
	EngineeringStrip.Position = UDim2.new(0, 358, 0, 8)
	EngineeringStrip.Size = UDim2.new(1, -520, 1, -16)
	EngineeringStrip.BackgroundTransparency = 1
	EngineeringStrip.Parent = commandDeck
	self.EngineeringStrip = EngineeringStrip

	local engineeringLayout = Instance.new("UIListLayout")
	engineeringLayout.FillDirection = Enum.FillDirection.Horizontal
	engineeringLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	engineeringLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	engineeringLayout.Padding = UDim.new(0, 6)
	engineeringLayout.Parent = EngineeringStrip

	self.EngineeringCards = {}
	local telemetryNames = {"MASS", "POWER", "THERMAL", "FUEL"}
	for _, name in ipairs(telemetryNames) do
		local card = Instance.new("Frame")
		card.Name = name
		card.Size = UDim2.new(0.24, -5, 1, 0)
		card.BackgroundColor3 = COLORS.Void
		card.BackgroundTransparency = 0.2
		card.BorderSizePixel = 0
		card.Parent = EngineeringStrip
		corner(card, 5)
		stroke(card, COLORS.BorderSoft, 0.3, 1)
		local cap = label(card, name, 8, true)
		cap.Position = UDim2.fromOffset(8, 3)
		cap.Size = UDim2.new(1, -16, 0, 14)
		cap.TextColor3 = COLORS.Dim
		local value = label(card, "--", 11, true)
		value.Position = UDim2.fromOffset(8, 17)
		value.Size = UDim2.new(1, -16, 0, 18)
		local sub = label(card, "", 7, false)
		sub.Position = UDim2.fromOffset(8, 34)
		sub.Size = UDim2.new(1, -16, 0, 12)
		sub.TextColor3 = COLORS.Muted
		self.EngineeringCards[name] = {Frame = card, Value = value, Sub = sub}
	end

	local testButton = button(commandDeck, "TEST MACHINE", 140, 36)
	testButton.AnchorPoint = Vector2.new(1, 0.5)
	testButton.Position = UDim2.new(1, -12, 0.5, 0)
	testButton.TextColor3 = COLORS.Amber
	testButton.MouseButton1Click:Connect(function()
		if testButton:GetAttribute("Disabled") ~= true and self.Callbacks.TestMachine then self.Callbacks.TestMachine() end
	end)
	self.TestButton = testButton

	local status = panel(root, "WorkshopStatus")
	status.AnchorPoint = Vector2.new(0.5, 0)
	status.Position = UDim2.new(0.5, 0, 0, 84)
	status.Size = UDim2.fromOffset(330, 26)
	local statusText = label(status, "WORKSHOP READY", 9, true)
	statusText.Size = UDim2.fromScale(1, 1)
	statusText.TextXAlignment = Enum.TextXAlignment.Center
	statusText.TextColor3 = COLORS.Amber
	self.StatusFrame = status
	self.Status = statusText

	-- LEFT: catalog rail + visual cards
	local catalogPanel = panel(root, "CatalogDeck")
	catalogPanel.Position = UDim2.fromOffset(16, 88)
	catalogPanel.Size = UDim2.new(0.31, 0, 1, -184)
	local catalogConstraint = Instance.new("UISizeConstraint")
	catalogConstraint.MinSize = Vector2.new(340, 420)
	catalogConstraint.MaxSize = Vector2.new(500, 900)
	catalogConstraint.Parent = catalogPanel
	addHeaderAccent(catalogPanel)
	self.CatalogPanel = catalogPanel

	local catalogTitle = label(catalogPanel, "PART CATALOG", 13, true)
	catalogTitle.Position = UDim2.fromOffset(20, 9)
	catalogTitle.Size = UDim2.new(1, -32, 0, 20)
	local catalogCount = label(catalogPanel, "100 COMPONENTS", 8, true)
	catalogCount.AnchorPoint = Vector2.new(1, 0)
	catalogCount.Position = UDim2.new(1, -12, 0, 11)
	catalogCount.Size = UDim2.fromOffset(110, 18)
	catalogCount.TextXAlignment = Enum.TextXAlignment.Right
	catalogCount.TextColor3 = COLORS.Dim

	local categoryRail = Instance.new("ScrollingFrame")
	categoryRail.Name = "CategoryRail"
	categoryRail.Position = UDim2.fromOffset(10, 38)
	categoryRail.Size = UDim2.new(0, 54, 1, -48)
	categoryRail.BackgroundColor3 = COLORS.Void
	categoryRail.BackgroundTransparency = 0.28
	categoryRail.BorderSizePixel = 0
	categoryRail.ScrollBarThickness = 0
	categoryRail.AutomaticCanvasSize = Enum.AutomaticSize.Y
	categoryRail.CanvasSize = UDim2.fromOffset(0, 0)
	categoryRail.Parent = catalogPanel
	corner(categoryRail, 5)
	local railLayout = Instance.new("UIListLayout")
	railLayout.Padding = UDim.new(0, 5)
	railLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	railLayout.Parent = categoryRail
	padding(categoryRail, 0, 0, 6, 6)
	self.CategoryList = categoryRail

	local search = textbox(catalogPanel, "SEARCH COMPONENTS...", 32)
	search.Position = UDim2.fromOffset(72, 38)
	search.Size = UDim2.new(1, -82, 0, 32)
	search:GetPropertyChangedSignal("Text"):Connect(function()
		self.SearchText = string.lower(search.Text)
		self:_refreshCatalog()
	end)
	self.Search = search

	local cardList = Instance.new("ScrollingFrame")
	cardList.Name = "CatalogCardGrid"
	cardList.Position = UDim2.fromOffset(72, 78)
	cardList.Size = UDim2.new(1, -82, 1, -88)
	cardList.BackgroundTransparency = 1
	cardList.BorderSizePixel = 0
	cardList.ScrollBarThickness = 3
	cardList.ScrollBarImageColor3 = COLORS.Border
	cardList.AutomaticCanvasSize = Enum.AutomaticSize.Y
	cardList.CanvasSize = UDim2.fromOffset(0, 0)
	cardList.Parent = catalogPanel
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.new(0.5, -5, 0, 154)
	grid.CellPadding = UDim2.fromOffset(7, 7)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = cardList
	self.PartList = cardList
	self.CatalogGrid = grid

	-- RIGHT: one context deck with tabs, never a permanent stack of giant sections.
	local inspectorPanel = panel(root, "ContextDeck")
	inspectorPanel.AnchorPoint = Vector2.new(1, 0)
	inspectorPanel.Position = UDim2.new(1, -16, 0, 88)
	inspectorPanel.Size = UDim2.new(0.255, 0, 1, -184)
	local inspectorConstraint = Instance.new("UISizeConstraint")
	inspectorConstraint.MinSize = Vector2.new(320, 420)
	inspectorConstraint.MaxSize = Vector2.new(390, 900)
	inspectorConstraint.Parent = inspectorPanel
	addHeaderAccent(inspectorPanel)
	self.ContextPanel = inspectorPanel

	local tabBar = Instance.new("Frame")
	tabBar.Name = "WorkshopTabs"
	tabBar.Position = UDim2.fromOffset(16, 9)
	tabBar.Size = UDim2.new(1, -26, 0, 32)
	tabBar.BackgroundTransparency = 1
	tabBar.Parent = inspectorPanel
	local tabLayout = Instance.new("UIListLayout")
	tabLayout.FillDirection = Enum.FillDirection.Horizontal
	tabLayout.Padding = UDim.new(0, 4)
	tabLayout.Parent = tabBar

	local pageHost = Instance.new("Frame")
	pageHost.Name = "PageHost"
	pageHost.Position = UDim2.fromOffset(12, 49)
	pageHost.Size = UDim2.new(1, -24, 1, -61)
	pageHost.BackgroundTransparency = 1
	pageHost.Parent = inspectorPanel

	for _, tabName in ipairs(WORKSHOP_TABS) do
		local tabButton = button(tabBar, tabName, 78, 28)
		tabButton.Size = UDim2.new(0.25, -3, 1, 0)
		tabButton.TextSize = 8
		self.TabButtons[tabName] = tabButton
		local page = Instance.new("Frame")
		page.Name = tabName .. "Page"
		page.Size = UDim2.fromScale(1, 1)
		page.BackgroundTransparency = 1
		page.Visible = tabName == "PART"
		page.Parent = pageHost
		self.TabPages[tabName] = page
		tabButton.MouseButton1Click:Connect(function() self:_setTab(tabName) end)
	end

	-- PART tab
	local partPage = self.TabPages.PART
	local InspectorViewport = makeViewport(partPage, "InspectorViewport")
	InspectorViewport.Size = UDim2.new(1, 0, 0, 156)
	self.InspectorViewport = InspectorViewport
	local previewTag = label(partPage, "LIVE PROCEDURAL MODEL", 8, true)
	previewTag.Position = UDim2.fromOffset(9, 8)
	previewTag.Size = UDim2.fromOffset(180, 18)
	previewTag.TextColor3 = COLORS.Amber
	previewTag.ZIndex = 3
	local partName = label(partPage, "NO COMPONENT", 16, true)
	partName.Position = UDim2.fromOffset(2, 168)
	partName.Size = UDim2.new(1, -4, 0, 24)
	partName.TextColor3 = COLORS.Amber
	self.PartName = partName
	local description = label(partPage, "SELECT A COMPONENT", 10, false)
	description.Position = UDim2.fromOffset(2, 194)
	description.Size = UDim2.new(1, -4, 0, 50)
	description.TextColor3 = COLORS.Muted
	description.TextWrapped = true
	description.TextYAlignment = Enum.TextYAlignment.Top
	self.Description = description
	local divider = Instance.new("Frame")
	divider.Position = UDim2.fromOffset(0, 249)
	divider.Size = UDim2.new(1, 0, 0, 1)
	divider.BackgroundColor3 = COLORS.BorderSoft
	divider.BorderSizePixel = 0
	divider.Parent = partPage
	local stats = label(partPage, "NO DATA", 10, false)
	stats.Position = UDim2.fromOffset(2, 258)
	stats.Size = UDim2.new(1, -4, 1, -262)
	stats.TextYAlignment = Enum.TextYAlignment.Top
	stats.TextWrapped = true
	self.Stats = stats

	-- PAINT tab
	local paintPage = self.TabPages.PAINT
	local paintTitle = label(paintPage, "SURFACE FINISH", 14, true)
	paintTitle.Size = UDim2.new(1, 0, 0, 24)
	paintTitle.TextColor3 = COLORS.Amber
	local regionCaption = label(paintPage, "PAINT REGION", 8, true)
	regionCaption.Position = UDim2.fromOffset(0, 34)
	regionCaption.Size = UDim2.new(1, 0, 0, 16)
	regionCaption.TextColor3 = COLORS.Dim
	local regionButton = button(paintPage, "REGION: ALL", 150, 31)
	regionButton.Position = UDim2.fromOffset(0, 54)
	regionButton.MouseButton1Click:Connect(function() self:_cyclePaintRegion() end)
	self.RegionButton = regionButton
	local regionTray = Instance.new("Frame")
	regionTray.Position = UDim2.fromOffset(0, 92)
	regionTray.Size = UDim2.new(1, 0, 0, 66)
	regionTray.BackgroundTransparency = 1
	regionTray.Parent = paintPage
	local regionGrid = Instance.new("UIGridLayout")
	regionGrid.CellSize = UDim2.new(0.33, -4, 0, 28)
	regionGrid.CellPadding = UDim2.fromOffset(5, 5)
	regionGrid.Parent = regionTray
	self.RegionTray = regionTray

	local colorCaption = label(paintPage, "COLOUR / HEX", 8, true)
	colorCaption.Position = UDim2.fromOffset(0, 168)
	colorCaption.Size = UDim2.new(1, 0, 0, 16)
	colorCaption.TextColor3 = COLORS.Dim
	local hex = textbox(paintPage, "#D6DADD", 34)
	hex.Position = UDim2.fromOffset(0, 188)
	hex.Size = UDim2.new(1, -50, 0, 34)
	hex.Text = colorToHex(self.PaintColor)
	self.HexBox = hex
	local swatch = Instance.new("Frame")
	swatch.AnchorPoint = Vector2.new(1, 0)
	swatch.Position = UDim2.new(1, 0, 0, 188)
	swatch.Size = UDim2.fromOffset(42, 34)
	swatch.BackgroundColor3 = self.PaintColor
	swatch.BorderSizePixel = 0
	swatch.Parent = paintPage
	corner(swatch, 5)
	stroke(swatch, COLORS.Border, 0.1, 1)
	self.PaintSwatch = swatch
	hex.FocusLost:Connect(function()
		local parsed = parseHex(hex.Text)
		if parsed then
			self.PaintColor = parsed
			hex.Text = colorToHex(parsed)
			swatch.BackgroundColor3 = parsed
		else
			hex.Text = colorToHex(self.PaintColor)
		end
	end)

	local palette = {
		Color3.fromRGB(215, 218, 222), Color3.fromRGB(52, 57, 63), Color3.fromRGB(14, 16, 19),
		Color3.fromRGB(255, 181, 54), Color3.fromRGB(214, 58, 58), Color3.fromRGB(52, 116, 210),
		Color3.fromRGB(73, 169, 108), Color3.fromRGB(131, 81, 184), Color3.fromRGB(236, 236, 225),
	}
	local paletteTray = Instance.new("Frame")
	paletteTray.Position = UDim2.fromOffset(0, 230)
	paletteTray.Size = UDim2.new(1, 0, 0, 62)
	paletteTray.BackgroundTransparency = 1
	paletteTray.Parent = paintPage
	local paletteGrid = Instance.new("UIGridLayout")
	paletteGrid.CellSize = UDim2.new(0.111, -4, 0, 28)
	paletteGrid.CellPadding = UDim2.fromOffset(4, 4)
	paletteGrid.Parent = paletteTray
	for _, color in ipairs(palette) do
		local colorButton = Instance.new("TextButton")
		colorButton.Text = ""
		colorButton.BackgroundColor3 = color
		colorButton.BorderSizePixel = 0
		colorButton.Parent = paletteTray
		corner(colorButton, 4)
		stroke(colorButton, COLORS.Border, 0.2, 1)
		colorButton.MouseButton1Click:Connect(function()
			self.PaintColor = color
			hex.Text = colorToHex(color)
			swatch.BackgroundColor3 = color
		end)
	end

	local materialCaption = label(paintPage, "MATERIAL", 8, true)
	materialCaption.Position = UDim2.fromOffset(0, 303)
	materialCaption.Size = UDim2.new(1, 0, 0, 16)
	materialCaption.TextColor3 = COLORS.Dim
	local materialButton = button(paintPage, "METAL", 150, 30)
	materialButton.Position = UDim2.fromOffset(0, 323)
	materialButton.MouseButton1Click:Connect(function()
		self.MaterialIndex = self.MaterialIndex % #MATERIALS + 1
		materialButton.Text = string.upper(MATERIALS[self.MaterialIndex])
	end)
	self.MaterialButton = materialButton
	local applyPaint = button(paintPage, "APPLY TO TARGET", 150, 34)
	applyPaint.Position = UDim2.fromOffset(0, 366)
	applyPaint:SetAttribute("Selected", true)
	applyButtonVisual(applyPaint)
	applyPaint.MouseButton1Click:Connect(function()
		if self.Callbacks.PaintTarget then self.Callbacks.PaintTarget(self.PaintRegion, self.PaintColor, MATERIALS[self.MaterialIndex]) end
	end)
	local paintAll = button(paintPage, "ALL REGIONS", 130, 34)
	paintAll.AnchorPoint = Vector2.new(1, 0)
	paintAll.Position = UDim2.new(1, 0, 0, 366)
	paintAll.MouseButton1Click:Connect(function()
		if self.Callbacks.PaintTarget then self.Callbacks.PaintTarget("All", self.PaintColor, MATERIALS[self.MaterialIndex]) end
	end)

	-- BLUEPRINTS tab
	local blueprintPage = self.TabPages.BLUEPRINTS
	local blueprintTitle = label(blueprintPage, "BLUEPRINT ARCHIVE", 14, true)
	blueprintTitle.Size = UDim2.new(1, 0, 0, 24)
	blueprintTitle.TextColor3 = COLORS.Amber
	local blueprintName = textbox(blueprintPage, "BLUEPRINT NAME", 34)
	blueprintName.Position = UDim2.fromOffset(0, 34)
	self.BlueprintName = blueprintName
	local saveBlueprint = button(blueprintPage, "SAVE / OVERWRITE", 142, 32)
	saveBlueprint.Position = UDim2.fromOffset(0, 76)
	saveBlueprint.MouseButton1Click:Connect(function()
		if self.Callbacks.SaveBlueprint then self.Callbacks.SaveBlueprint(blueprintName.Text) end
	end)
	local loadBlueprint = button(blueprintPage, "LOAD / SPAWN", 132, 32)
	loadBlueprint.AnchorPoint = Vector2.new(1, 0)
	loadBlueprint.Position = UDim2.new(1, 0, 0, 76)
	loadBlueprint.MouseButton1Click:Connect(function()
		if self.Callbacks.LoadBlueprint then self.Callbacks.LoadBlueprint(blueprintName.Text) end
	end)
	local refreshBlueprints = button(blueprintPage, "REFRESH", 86, 30)
	refreshBlueprints.Position = UDim2.fromOffset(0, 116)
	refreshBlueprints.MouseButton1Click:Connect(function()
		if self.Callbacks.RefreshBlueprints then self.Callbacks.RefreshBlueprints() end
	end)
	local deleteBlueprint = button(blueprintPage, "DELETE", 86, 30)
	deleteBlueprint.AnchorPoint = Vector2.new(1, 0)
	deleteBlueprint.Position = UDim2.new(1, 0, 0, 116)
	deleteBlueprint.TextColor3 = COLORS.Bad
	deleteBlueprint.MouseButton1Click:Connect(function()
		if self.Callbacks.DeleteBlueprint then self.Callbacks.DeleteBlueprint(blueprintName.Text) end
	end)
	local quickCaption = label(blueprintPage, "ASSIGN SELECTED VEHICLE TO QUICK SLOT", 7, true)
	quickCaption.Position = UDim2.fromOffset(0, 151)
	quickCaption.Size = UDim2.new(1, 0, 0, 14)
	quickCaption.TextColor3 = COLORS.Dim
	self.QuickSwapButtons = {}
	for slot=1,3 do
		local quickButton = button(blueprintPage, "Q"..slot.."  EMPTY", 90, 26)
		quickButton.Position = UDim2.new((slot-1)/3, if slot==1 then 0 elseif slot==2 then 3 else 6, 0, 168)
		quickButton.Size = UDim2.new(1/3, -6, 0, 26)
		quickButton.MouseButton1Click:Connect(function()
			if self.Callbacks.AssignQuickSlot then self.Callbacks.AssignQuickSlot(slot, blueprintName.Text) end
		end)
		self.QuickSwapButtons[slot]=quickButton
	end
	local blueprintList = Instance.new("ScrollingFrame")
	blueprintList.Position = UDim2.fromOffset(0, 201)
	blueprintList.Size = UDim2.new(1, 0, 1, -201)
	blueprintList.BackgroundColor3 = COLORS.Void
	blueprintList.BackgroundTransparency = 0.3
	blueprintList.BorderSizePixel = 0
	blueprintList.ScrollBarThickness = 3
	blueprintList.ScrollBarImageColor3 = COLORS.Border
	blueprintList.AutomaticCanvasSize = Enum.AutomaticSize.Y
	blueprintList.CanvasSize = UDim2.fromOffset(0, 0)
	blueprintList.Parent = blueprintPage
	corner(blueprintList, 5)
	local blueprintLayout = Instance.new("UIListLayout")
	blueprintLayout.Padding = UDim.new(0, 5)
	blueprintLayout.Parent = blueprintList
	padding(blueprintList, 5, 5, 5, 5)
	self.BlueprintList = blueprintList

	-- CONTROLS tab
	local controlsPage = self.TabPages.CONTROLS
	local controlsTitle = label(controlsPage, "CONTROL BUS", 14, true)
	controlsTitle.Size = UDim2.new(1, 0, 0, 24)
	controlsTitle.TextColor3 = COLORS.Amber
	local help = label(controlsPage, "Aim at a component, choose an action, then toggle the binding. Auto Bind restores the recommended hybrid layout.", 10, false)
	help.Position = UDim2.fromOffset(0, 34)
	help.Size = UDim2.new(1, 0, 0, 68)
	help.TextColor3 = COLORS.Muted
	help.TextWrapped = true
	help.TextYAlignment = Enum.TextYAlignment.Top
	local actionButton = button(controlsPage, "ACTION: " .. string.upper(CONTROL_ACTIONS[1]), 260, 36)
	actionButton.Position = UDim2.fromOffset(0, 113)
	actionButton.Size = UDim2.new(1, 0, 0, 36)
	actionButton.MouseButton1Click:Connect(function()
		self.BindingIndex = self.BindingIndex % #CONTROL_ACTIONS + 1
		actionButton.Text = "ACTION: " .. string.upper(CONTROL_ACTIONS[self.BindingIndex])
	end)
	self.BindingButton = actionButton
	local bindTarget = button(controlsPage, "TOGGLE TARGET", 132, 34)
	bindTarget.Position = UDim2.fromOffset(0, 161)
	bindTarget.MouseButton1Click:Connect(function()
		if self.Callbacks.BindTarget then self.Callbacks.BindTarget(CONTROL_ACTIONS[self.BindingIndex]) end
	end)
	local autoBind = button(controlsPage, "AUTO BIND", 118, 34)
	autoBind.AnchorPoint = Vector2.new(1, 0)
	autoBind.Position = UDim2.new(1, 0, 0, 161)
	autoBind.MouseButton1Click:Connect(function()
		if self.Callbacks.AutoBindings then self.Callbacks.AutoBindings() end
	end)
	local controlLegend = label(controlsPage, "GROUND  W/S THROTTLE  •  A/D STEER\nOMNI    A/D STRAFE + STEER\nFLIGHT  PITCH / YAW / ROLL / VERTICAL\nWEAPONS PRIMARY / SECONDARY / UTILITY", 9, true)
	controlLegend.Position = UDim2.fromOffset(0, 214)
	controlLegend.Size = UDim2.new(1, 0, 0, 94)
	controlLegend.TextColor3 = COLORS.Dim
	controlLegend.TextYAlignment = Enum.TextYAlignment.Top

	-- Compact contextual tool strip, separate from the inspector pages.
	local toolStrip = panel(root, "ToolStrip")
	toolStrip.AnchorPoint = Vector2.new(0.5, 1)
	toolStrip.Position = UDim2.new(0.5, 0, 1, -102)
	toolStrip.Size = UDim2.fromOffset(600, 38)
	self.ToolStrip = toolStrip
	local toolLayout = Instance.new("UIListLayout")
	toolLayout.FillDirection = Enum.FillDirection.Horizontal
	toolLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	toolLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	toolLayout.Padding = UDim.new(0, 5)
	toolLayout.Parent = toolStrip
	local mirrorButton = button(toolStrip, "MIRROR: OFF", 88, 28)
	mirrorButton.MouseButton1Click:Connect(function()
		if self.Callbacks.Mirror then
			local state = self.Callbacks.Mirror()
			if type(state) == "boolean" then self:SetMirrorState(state) end
		end
	end)
	self.MirrorButton = mirrorButton
	local duplicateButton = button(toolStrip, "DUPLICATE", 86, 28)
	duplicateButton.MouseButton1Click:Connect(function() if self.Callbacks.DuplicateTarget then self.Callbacks.DuplicateTarget() end end)
	local nodeButton = button(toolStrip, "NODES: ON", 78, 28)
	nodeButton.MouseButton1Click:Connect(function()
		self.NodeVisible = not self.NodeVisible
		nodeButton.Text = if self.NodeVisible then "NODES: ON" else "NODES: OFF"
		if self.Callbacks.ToggleNodes then self.Callbacks.ToggleNodes(self.NodeVisible) end
	end)
	local removeButton = button(toolStrip, "REMOVE", 72, 28)
	removeButton.MouseButton1Click:Connect(function() if self.Callbacks.RemoveTarget then self.Callbacks.RemoveTarget() end end)
	local undoButton = button(toolStrip, "UNDO", 60, 28)
	undoButton.MouseButton1Click:Connect(function() if self.Callbacks.Undo then self.Callbacks.Undo() end end)
	local redoButton = button(toolStrip, "REDO", 60, 28)
	redoButton.MouseButton1Click:Connect(function() if self.Callbacks.Redo then self.Callbacks.Redo() end end)

	-- Bottom quick-build belt.
	local hotbar = panel(root, "QuickBuildBelt")
	hotbar.AnchorPoint = Vector2.new(0.5, 1)
	hotbar.Position = UDim2.new(0.5, 0, 1, -18)
	hotbar.Size = UDim2.fromOffset(760, 72)
	self.Hotbar = hotbar
	local hotLayout = Instance.new("UIListLayout")
	hotLayout.FillDirection = Enum.FillDirection.Horizontal
	hotLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	hotLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	hotLayout.Padding = UDim.new(0, 5)
	hotLayout.Parent = hotbar
	local legend = label(root, "LMB PLACE   •   R ROTATE   •   M MIRROR   •   X REMOVE   •   Z/Y UNDO/REDO   •   B CLOSE", 9, true)
	legend.AnchorPoint = Vector2.new(0.5, 1)
	legend.Position = UDim2.new(0.5, 0, 1, -93)
	legend.Size = UDim2.fromOffset(720, 18)
	legend.TextXAlignment = Enum.TextXAlignment.Center
	legend.TextColor3 = COLORS.Dim
	self.Legend = legend

	self:_setTab("PART")
	self:_refreshPaintRegions()
	return self
end

function BuildUI:_setTab(tabName)
	if not self.TabPages[tabName] then return end
	self.ActiveTab = tabName
	for name, page in pairs(self.TabPages) do page.Visible = name == tabName end
	for name, tabButton in pairs(self.TabButtons) do
		tabButton:SetAttribute("Selected", name == tabName)
		applyButtonVisual(tabButton)
	end
end

function BuildUI:SetBuildMode(enabled)
	local active = enabled == true
	self.Root.Visible = active
	self.Hint.Visible = not active
	if active then
		self.Root.Position = UDim2.fromOffset(0, 8)
		self.Root.GroupTransparency = 0.08
		tween(self.Root, {Position = UDim2.fromOffset(0, 0), GroupTransparency = 0}, 0.16)
	end
end

function BuildUI:SetMode(mode)
	local text = string.upper(tostring(mode or "EDIT"))
	self.ModeLabel.Text = text
	if text == "TEST" then
		self.ModeLabel.TextColor3 = COLORS.Blue
		self.ModeLabel.BackgroundColor3 = Color3.fromRGB(22, 39, 62)
		self.TestButton.Text = "RETURN TO EDIT"
	else
		self.ModeLabel.TextColor3 = COLORS.Good
		self.ModeLabel.BackgroundColor3 = Color3.fromRGB(23, 55, 39)
		self.TestButton.Text = "TEST MACHINE"
	end
end

function BuildUI:SetMachineReady(ready)
	self.TestButton:SetAttribute("Disabled", ready ~= true)
	self.TestButton.Active = ready == true
	applyButtonVisual(self.TestButton)
	if ready == true then self.TestButton.TextColor3 = COLORS.Amber end
end

function BuildUI:SetMirrorState(mirrored)
	self.Mirrored = mirrored == true
	self.MirrorButton.Text = if self.Mirrored then "MIRROR: ON" else "MIRROR: OFF"
	self.MirrorButton:SetAttribute("Selected", self.Mirrored)
	applyButtonVisual(self.MirrorButton)
	if self.SelectedPart then
		local definition = nil
		for _, part in ipairs(self.Catalog) do if part.Id == self.SelectedPart then definition = part break end end
		if definition then renderDefinition(self.InspectorViewport, definition, self.Mirrored) end
	end
end

function BuildUI:SetStatus(text, tone)
	self.Status.Text = string.upper(tostring(text or ""))
	local color = COLORS.Amber
	if tone == "good" then color = COLORS.Good elseif tone == "bad" then color = COLORS.Bad elseif tone == "blue" then color = COLORS.Blue end
	self.Status.TextColor3 = color
	tween(self.StatusFrame, {BackgroundColor3 = if tone == "bad" then Color3.fromRGB(49, 22, 22) elseif tone == "good" then Color3.fromRGB(19, 42, 30) else COLORS.Panel}, 0.12)
end

function BuildUI:_visiblePart(part)
	if self.SelectedCategory ~= "ALL" and part.Category ~= self.SelectedCategory then return false end
	if self.SearchText == "" then return true end
	local haystack = string.lower(table.concat({part.DisplayName or "", part.ShortName or "", part.Category or "", part.Description or "", part.Id or ""}, " "))
	return string.find(haystack, self.SearchText, 1, true) ~= nil
end

function BuildUI:_refreshCategories()
	clearGuiChildren(self.CategoryList)
	self.CategoryButtons = {}
	local values = {"ALL"}
	for _, category in ipairs(self.Categories) do table.insert(values, category) end
	for _, category in ipairs(values) do
		local glyph = CATEGORY_GLYPHS[category] or string.upper(string.sub(category, 1, 3))
		local item = button(self.CategoryList, glyph, 44, 34)
		item.Name = "Category_" .. tostring(category)
		item.TextSize = 8
		item:SetAttribute("Selected", category == self.SelectedCategory)
		applyButtonVisual(item)
		item.MouseButton1Click:Connect(function()
			self.SelectedCategory = category
			self:_refreshCategories()
			self:_refreshCatalog()
		end)
		self.CategoryButtons[category] = item
	end
end

function BuildUI:_cardVisual(cardData)
	local part, card, border = cardData.Part, cardData.Card, cardData.Border
	local selected = part.Id == self.SelectedPart
	local ready = math.max(0, math.floor(tonumber(self.InventoryCounts[part.Id]) or 0))
	cardData.Ready.Text = tostring(ready) .. " READY"
	cardData.Ready.TextColor3 = if ready > 0 then COLORS.Good else COLORS.Bad
	cardData.StockShade.Visible = ready <= 0
	border.Color = if selected then COLORS.Amber else (RARITY_COLORS[tostring(part.Rarity or "Common")] or COLORS.BorderSoft)
	border.Transparency = if selected then 0.05 else 0.48
	border.Thickness = if selected then 2 else 1
	card.BackgroundColor3 = if selected then COLORS.AmberDeep else COLORS.PanelRaised
	cardData.Name.TextColor3 = if selected then COLORS.Amber else COLORS.Text
end

function BuildUI:_createCatalogCard(part, order)
	local card = Instance.new("Frame")
	card.Name = "Card_" .. tostring(part.Id)
	card.LayoutOrder = order
	card.BackgroundColor3 = COLORS.PanelRaised
	card.BorderSizePixel = 0
	card.Parent = self.PartList
	corner(card, 7)
	local border = stroke(card, COLORS.BorderSoft, 0.45, 1)

	local viewport = makeViewport(card, "Thumbnail")
	viewport.Position = UDim2.fromOffset(6, 6)
	viewport.Size = UDim2.new(1, -12, 0, 91)
	renderDefinition(viewport, part, false)

	local ready = label(card, "0 READY", 7, true)
	ready.Position = UDim2.fromOffset(10, 9)
	ready.Size = UDim2.fromOffset(76, 18)
	ready.TextColor3 = COLORS.Bad
	ready.ZIndex = 4
	local favorite = Instance.new("TextButton")
	favorite.AnchorPoint = Vector2.new(1, 0)
	favorite.Position = UDim2.new(1, -9, 0, 8)
	favorite.Size = UDim2.fromOffset(25, 25)
	favorite.BackgroundColor3 = COLORS.Void
	favorite.BackgroundTransparency = 0.18
	favorite.BorderSizePixel = 0
	favorite.Text = "☆"
	favorite.TextColor3 = COLORS.Muted
	favorite.TextSize = 15
	favorite.Font = Enum.Font.GothamBold
	favorite.ZIndex = 5
	favorite.Parent = card
	corner(favorite, 4)

	local partName = label(card, string.upper(tostring(part.DisplayName or part.Id)), 9, true)
	partName.Position = UDim2.fromOffset(7, 101)
	partName.Size = UDim2.new(1, -14, 0, 18)
	partName.TextTruncate = Enum.TextTruncate.AtEnd
	local meta = label(card, string.upper(tostring(part.Category or "?")) .. "  /  " .. tostring(math.floor(tonumber(part.Mass) or 0)) .. " KG", 7, true)
	meta.Position = UDim2.fromOffset(7, 120)
	meta.Size = UDim2.new(1, -14, 0, 14)
	meta.TextColor3 = RARITY_COLORS[tostring(part.Rarity or "Common")] or COLORS.Dim
	local id = label(card, tostring(part.ShortName or part.Id), 7, false)
	id.Position = UDim2.fromOffset(7, 136)
	id.Size = UDim2.new(1, -14, 0, 12)
	id.TextColor3 = COLORS.Dim
	id.TextTruncate = Enum.TextTruncate.AtEnd

	local stockShade = Instance.new("Frame")
	stockShade.Name = "OutOfStockShade"
	stockShade.Position = UDim2.fromOffset(6, 6)
	stockShade.Size = UDim2.new(1, -12, 0, 91)
	stockShade.BackgroundColor3 = COLORS.Bad
	stockShade.BackgroundTransparency = 0.91
	stockShade.BorderSizePixel = 0
	stockShade.Visible = false
	stockShade.ZIndex = 3
	stockShade.Parent = card
	corner(stockShade, 6)

	local click = Instance.new("TextButton")
	click.Size = UDim2.fromScale(1, 1)
	click.BackgroundTransparency = 1
	click.Text = ""
	click.ZIndex = 2
	click.Parent = card
	click.MouseButton1Click:Connect(function()
		if self.Callbacks.SelectPart then self.Callbacks.SelectPart(part.Id) end
	end)
	click.MouseEnter:Connect(function()
		if part.Id ~= self.SelectedPart then tween(card, {BackgroundColor3 = COLORS.PanelHover}, 0.1) end
	end)
	click.MouseLeave:Connect(function()
		self:_cardVisual(self.CatalogCards[part.Id])
	end)
	favorite.MouseButton1Click:Connect(function() self:_toggleFavorite(part.Id) end)

	local data = {Part = part, Card = card, Border = border, Ready = ready, Name = partName, Meta = meta, Favorite = favorite, StockShade = stockShade, Viewport = viewport}
	self.CatalogCards[part.Id] = data
	self.InventoryButtons[part.Id] = card
	return data
end

function BuildUI:_refreshCatalog()
	for _, cardData in pairs(self.CatalogCards) do
		cardData.Card.Visible = self:_visiblePart(cardData.Part)
		cardData.Favorite.Text = if self.Favorites[cardData.Part.Id] then "★" else "☆"
		cardData.Favorite.TextColor3 = if self.Favorites[cardData.Part.Id] then COLORS.Amber else COLORS.Muted
		self:_cardVisual(cardData)
	end
end

function BuildUI:_refreshHotbar()
	clearGuiChildren(self.Hotbar)
	self.HotbarButtons = {}
	for slot = 1, 9 do
		local partId = self.HotbarIds[slot]
		local part = nil
		if partId then
			for _, candidate in ipairs(self.Catalog) do if candidate.Id == partId then part = candidate break end end
		end
		local selected = part and part.Id == self.SelectedPart
		local item = button(self.Hotbar, tostring(slot), if selected then 82 else 72, if selected then 56 else 48)
		item.Name = "QuickSlot" .. tostring(slot)
		item.TextSize = 8
		item.TextWrapped = true
		item:SetAttribute("Selected", selected == true)
		if part then
			local ready = math.max(0, math.floor(tonumber(self.InventoryCounts[part.Id]) or 0))
			item.Text = string.format("[%d]  %s\n%d READY", slot, string.upper(tostring(part.ShortName or part.DisplayName or part.Id)), ready)
			item.TextColor3 = if ready > 0 then (if selected then COLORS.Amber else COLORS.Text) else COLORS.Bad
			item.MouseButton1Click:Connect(function() if self.Callbacks.SelectPart then self.Callbacks.SelectPart(part.Id) end end)
			self.HotbarButtons[part.Id] = item
		else
			item.Text = "[" .. tostring(slot) .. "]\nEMPTY"
			item.TextColor3 = COLORS.Dim
		end
		applyButtonVisual(item)
	end
end

function BuildUI:_toggleFavorite(partId)
	if self.Favorites[partId] then
		self.Favorites[partId] = nil
		for index = #self.HotbarIds, 1, -1 do if self.HotbarIds[index] == partId then table.remove(self.HotbarIds, index) end end
	else
		self.Favorites[partId] = true
		if #self.HotbarIds < 9 then table.insert(self.HotbarIds, partId) else self.HotbarIds[9] = partId end
	end
	self:_refreshCatalog()
	self:_refreshHotbar()
end

function BuildUI:SetCatalog(parts, categories)
	self.Catalog = parts or {}
	self.Categories = categories or {}
	self.HotbarIds = {}
	self.Favorites = {}
	self.CatalogCards = {}
	self.InventoryButtons = {}
	clearGuiChildren(self.PartList)
	local usedCategory = {}
	for index, part in ipairs(self.Catalog) do
		if #self.HotbarIds < 9 and not usedCategory[part.Category] then
			usedCategory[part.Category] = true
			self.Favorites[part.Id] = true
			table.insert(self.HotbarIds, part.Id)
		end
		self:_createCatalogCard(part, index)
	end
	self:_refreshCategories()
	self:_refreshCatalog()
	self:_refreshHotbar()
end

function BuildUI:SetInventoryCounts(counts)
	self.InventoryCounts = type(counts) == "table" and counts or {}
	self:_refreshCatalog()
	self:_refreshHotbar()
end

function BuildUI:GetHotbarPart(slot)
	return self.HotbarIds[slot]
end

function BuildUI:SetSelectedPart(partType)
	self.SelectedPart = partType
	self:_refreshCatalog()
	self:_refreshHotbar()
end

function BuildUI:_refreshPaintRegions()
	clearGuiChildren(self.RegionTray)
	self.PaintRegionButtons = {}
	local regions = self.PaintRegions or {"All"}
	for _, region in ipairs(regions) do
		local regionName = tostring(region)
		local item = button(self.RegionTray, string.upper(regionName), 82, 27)
		item.TextSize = 7
		item:SetAttribute("Selected", regionName == self.PaintRegion)
		applyButtonVisual(item)
		item.MouseButton1Click:Connect(function()
			self.PaintRegion = regionName
			self.RegionButton.Text = "REGION: " .. string.upper(regionName)
			self:_refreshPaintRegions()
		end)
		self.PaintRegionButtons[regionName] = item
	end
end

function BuildUI:SetInspector(name, definition)
	self.PartName.Text = definition and string.upper(definition.DisplayName or name) or string.upper(tostring(name or "NO COMPONENT"))
	if not definition then
		self.Description.Text = "SELECT A COMPONENT"
		self.Stats.Text = "NO DATA"
		return
	end
	self.Description.Text = tostring(definition.Description or "")
	renderDefinition(self.InspectorViewport, definition, self.Mirrored)
	local ready = math.max(0, math.floor(tonumber(self.InventoryCounts[definition.Id]) or 0))
	local lines = {
		string.format("READY STOCK     %d", ready),
		string.format("CATEGORY        %s", string.upper(tostring(definition.Category or "?"))),
		string.format("RARITY          %s", string.upper(tostring(definition.Rarity or "COMMON"))),
		string.format("MASS            %.0f KG", tonumber(definition.Mass) or 0),
		string.format("STRUCTURE       %.0f HP", tonumber(definition.MaxHealth) or 0),
	}
	if definition.Size then table.insert(lines, string.format("BOUNDS          %.1f × %.1f × %.1f", definition.Size.X, definition.Size.Y, definition.Size.Z)) end
	if definition.Power then
		table.insert(lines, string.format("POWER           +%.0f / -%.0f", tonumber(definition.Power.Generation) or 0, tonumber(definition.Power.Demand) or 0))
		local storage = tonumber(definition.Power.StorageCapacity) or 0
		if storage > 0 then table.insert(lines, string.format("ENERGY STORAGE  %.0f", storage)) end
	end
	if definition.Heat then table.insert(lines, string.format("THERMAL         +%.1f HEAT/S", tonumber(definition.Heat.Generation) or 0)) end
	if definition.Mobility then table.insert(lines, "MOBILITY        " .. string.upper(tostring(definition.Mobility.Kind or "YES"))) end
	if definition.Propulsion then
		local force, torque = tonumber(definition.Propulsion.Force) or 0, tonumber(definition.Propulsion.Torque) or 0
		if force > 0 then table.insert(lines, string.format("THRUST          %.0f", force)) end
		if torque > 0 then table.insert(lines, string.format("TORQUE          %.0f", torque)) end
	end
	if definition.Aerodynamics then table.insert(lines, string.format("AERO AREA       %.1f", tonumber(definition.Aerodynamics.Area) or 0)) end
	if definition.Pilot then table.insert(lines, "CONTROL         PILOT CAPABLE") end
	if definition.Combat then table.insert(lines, "WEAPON          " .. string.upper(tostring(definition.Combat.Preset or definition.Combat.Category or "YES"))) end
	self.Stats.Text = table.concat(lines, "\n")
	self.PaintRegions = {"All"}
	for _, region in ipairs(definition.PaintRegions or {}) do table.insert(self.PaintRegions, region) end
	self.PaintRegion = "All"
	self.RegionButton.Text = "REGION: ALL"
	self:_refreshPaintRegions()
end

function BuildUI:_cyclePaintRegion()
	local regions = self.PaintRegions or {"All"}
	local index = table.find(regions, self.PaintRegion) or 1
	index = index % #regions + 1
	self.PaintRegion = regions[index]
	self.RegionButton.Text = "REGION: " .. string.upper(self.PaintRegion)
	self:_refreshPaintRegions()
end

local function setTelemetry(card, value, sub, tone)
	card.Value.Text = value
	card.Sub.Text = sub or ""
	local color = COLORS.Text
	if tone == "good" then color = COLORS.Good elseif tone == "bad" then color = COLORS.Bad elseif tone == "warn" then color = COLORS.Amber elseif tone == "blue" then color = COLORS.Blue end
	card.Value.TextColor3 = color
	local target = if tone == "bad" then Color3.fromRGB(48, 22, 22) elseif tone == "warn" then Color3.fromRGB(48, 37, 20) elseif tone == "good" then Color3.fromRGB(18, 42, 29) else COLORS.Void
	tween(card.Frame, {BackgroundColor3 = target}, 0.14)
end

function BuildUI:SetEngineeringSummary(summary)
	if type(summary) ~= "table" then
		for _, card in pairs(self.EngineeringCards) do setTelemetry(card, "--", "NO MACHINE", nil) end
		return
	end
	local parts = tonumber(summary.PartCount) or 0
	local mass = tonumber(summary.Mass) or 0
	local generation = tonumber(summary.PowerGeneration) or 0
	local demand = tonumber(summary.PowerDemand) or 0
	local balance = generation - demand
	local heat = tonumber(summary.HeatGeneration) or 0
	local cooling = tonumber(summary.Cooling) or 0
	local fuel = tonumber(summary.FuelCapacity) or 0
	local thrust = tonumber(summary.Thrust) or 0
	setTelemetry(self.EngineeringCards.MASS, string.format("%.0f KG", mass), string.format("%d PARTS", parts), nil)
	setTelemetry(self.EngineeringCards.POWER, string.format("%+.0f", balance), string.format("%.0f GEN / %.0f USE", generation, demand), if balance < 0 then "bad" elseif demand > 0 then "good" else nil)
	setTelemetry(self.EngineeringCards.THERMAL, string.format("%.1f / %.1f", heat, cooling), "HEAT / COOL", if heat > cooling and heat > 0 then "warn" elseif cooling > 0 then "good" else nil)
	local fuelTone = if thrust > 0 and fuel <= 0 then "bad" elseif fuel > 0 then "blue" else nil
	setTelemetry(self.EngineeringCards.FUEL, string.format("%.0f", fuel), if thrust > 0 then string.format("THRUST %.0f", thrust) else "NO FUEL LOAD", fuelTone)
end

function BuildUI:SetQuickSwapSlots(slots)
	self.QuickSwapSlots=slots or {}
	for slot=1,3 do
		local name=self.QuickSwapSlots[slot]
		local display=if type(name)=="string" and name~="" then string.upper(name) else "EMPTY"
		if #display>10 then display=display:sub(1,9).."…" end
		local button=self.QuickSwapButtons and self.QuickSwapButtons[slot]
		if button then button.Text="Q"..slot.."  "..display; button:SetAttribute("Selected",name~=nil); applyButtonVisual(button) end
	end
end

function BuildUI:SetBlueprints(entries)
	self.Blueprints = entries or {}
	clearGuiChildren(self.BlueprintList)
	if #self.Blueprints == 0 then
		local empty = label(self.BlueprintList, "NO SAVED BLUEPRINTS", 9, true)
		empty.Size = UDim2.new(1, -8, 0, 34)
		empty.TextColor3 = COLORS.Dim
		empty.TextXAlignment = Enum.TextXAlignment.Center
		return
	end
	for _, entry in ipairs(self.Blueprints) do
		local row = Instance.new("TextButton")
		row.Size = UDim2.new(1, -4, 0, 48)
		row.BackgroundColor3 = COLORS.PanelRaised
		row.BorderSizePixel = 0
		row.Text = ""
		row.AutoButtonColor = false
		row.Parent = self.BlueprintList
		corner(row, 5)
		stroke(row, COLORS.BorderSoft, 0.25, 1)
		local name = label(row, string.upper(tostring(entry.Name or "BLUEPRINT")), 9, true)
		name.Position = UDim2.fromOffset(8, 5)
		name.Size = UDim2.new(1, -16, 0, 16)
		local meta = label(row, string.format("%d PARTS  /  %s", tonumber(entry.PartCount) or 0, prettyDate(entry.SavedAt)), 7, false)
		meta.Position = UDim2.fromOffset(8, 24)
		meta.Size = UDim2.new(1, -16, 0, 14)
		meta.TextColor3 = COLORS.Muted
		row.MouseEnter:Connect(function() tween(row, {BackgroundColor3 = COLORS.PanelHover}, 0.1) end)
		row.MouseLeave:Connect(function() tween(row, {BackgroundColor3 = COLORS.PanelRaised}, 0.1) end)
		row.MouseButton1Click:Connect(function() self.BlueprintName.Text = tostring(entry.Name or "") end)
	end
end

function BuildUI:Destroy()
	if self.Gui then self.Gui:Destroy() end
end

return BuildUI
