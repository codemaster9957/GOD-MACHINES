--!nonstrict
-- GOD MACHINES Builder V2: searchable catalog, engineering telemetry, paint, blueprints and control tools.

local BuildUI = {}
BuildUI.__index = BuildUI

local COLORS = {
	Background = Color3.fromRGB(9, 11, 14),
	Panel = Color3.fromRGB(17, 20, 24),
	Panel2 = Color3.fromRGB(25, 29, 34),
	Panel3 = Color3.fromRGB(34, 39, 45),
	Border = Color3.fromRGB(72, 80, 89),
	Text = Color3.fromRGB(238, 241, 243),
	Muted = Color3.fromRGB(145, 154, 163),
	Accent = Color3.fromRGB(255, 181, 54),
	AccentSoft = Color3.fromRGB(93, 72, 37),
	Good = Color3.fromRGB(77, 232, 139),
	Bad = Color3.fromRGB(255, 81, 81),
	Blue = Color3.fromRGB(89, 174, 255),
}

local MATERIALS = { "Metal", "SmoothPlastic", "DiamondPlate", "CorrodedMetal", "Granite", "Slate" }
local CONTROL_ACTIONS = {
	"ThrottleForward", "ThrottleReverse", "SteerLeft", "SteerRight", "Brake",
	"VerticalUp", "VerticalDown", "PitchUp", "PitchDown", "YawLeft", "YawRight",
	"RollLeft", "RollRight", "Primary", "Secondary", "Utility", "Reload", "Mechanism1", "Mechanism2",
}

local function corner(parent, radius)
	local item = Instance.new("UICorner")
	item.CornerRadius = UDim.new(0, radius or 6)
	item.Parent = parent
end

local function stroke(parent, transparency)
	local item = Instance.new("UIStroke")
	item.Color = COLORS.Border
	item.Transparency = transparency or 0.3
	item.Thickness = 1
	item.Parent = parent
	return item
end

local function pad(parent, amount)
	local item = Instance.new("UIPadding")
	item.PaddingLeft = UDim.new(0, amount)
	item.PaddingRight = UDim.new(0, amount)
	item.PaddingTop = UDim.new(0, amount)
	item.PaddingBottom = UDim.new(0, amount)
	item.Parent = parent
end

local function label(parent, text, size, bold)
	local item = Instance.new("TextLabel")
	item.BackgroundTransparency = 1
	item.Text = text
	item.TextColor3 = COLORS.Text
	item.TextSize = size or 13
	item.Font = if bold then Enum.Font.GothamBold else Enum.Font.GothamMedium
	item.TextXAlignment = Enum.TextXAlignment.Left
	item.Parent = parent
	return item
end

local function button(parent, text, width)
	local item = Instance.new("TextButton")
	item.Size = UDim2.fromOffset(width or 100, 32)
	item.BackgroundColor3 = COLORS.Panel3
	item.Text = text
	item.TextColor3 = COLORS.Text
	item.TextSize = 11
	item.Font = Enum.Font.GothamBold
	item.AutoButtonColor = false
	item.Parent = parent
	corner(item, 5)
	stroke(item, 0.45)
	item.MouseEnter:Connect(function()
		if item.Active then item.BackgroundColor3 = COLORS.AccentSoft end
	end)
	item.MouseLeave:Connect(function()
		if item.Active then item.BackgroundColor3 = COLORS.Panel3 end
	end)
	return item
end

local function textbox(parent, placeholder, height)
	local item = Instance.new("TextBox")
	item.Size = UDim2.new(1, 0, 0, height or 34)
	item.BackgroundColor3 = COLORS.Panel2
	item.PlaceholderText = placeholder
	item.PlaceholderColor3 = COLORS.Muted
	item.Text = ""
	item.TextColor3 = COLORS.Text
	item.TextSize = 12
	item.Font = Enum.Font.GothamMedium
	item.TextXAlignment = Enum.TextXAlignment.Left
	item.ClearTextOnFocus = false
	item.Parent = parent
	corner(item, 5)
	stroke(item, 0.45)
	local inset = Instance.new("UIPadding")
	inset.PaddingLeft = UDim.new(0, 10)
	inset.PaddingRight = UDim.new(0, 10)
	inset.Parent = item
	return item
end

local function section(parent, titleText, height)
	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(1, 0, 0, height)
	frame.BackgroundColor3 = COLORS.Panel
	frame.Parent = parent
	corner(frame, 7)
	stroke(frame, 0.38)
	local title = label(frame, titleText, 11, true)
	title.Position = UDim2.fromOffset(11, 8)
	title.Size = UDim2.new(1, -22, 0, 18)
	title.TextColor3 = COLORS.Muted
	return frame
end

local function colorToHex(color)
	return string.format("#%02X%02X%02X", math.floor(color.R * 255 + 0.5), math.floor(color.G * 255 + 0.5), math.floor(color.B * 255 + 0.5))
end

local function parseHex(text)
	if type(text) ~= "string" then return nil end
	local value = string.upper(text):gsub("#", ""):gsub("%s", "")
	if #value == 3 then
		value = value:sub(1,1):rep(2) .. value:sub(2,2):rep(2) .. value:sub(3,3):rep(2)
	end
	if #value ~= 6 or value:find("[^0-9A-F]") then return nil end
	local r = tonumber(value:sub(1,2), 16)
	local g = tonumber(value:sub(3,4), 16)
	local b = tonumber(value:sub(5,6), 16)
	if not r or not g or not b then return nil end
	return Color3.fromRGB(r, g, b)
end

local function clearGuiChildren(parent)
	for _, child in ipairs(parent:GetChildren()) do
		if child:IsA("GuiObject") then child:Destroy() end
	end
end

function BuildUI.new(playerGui, callbacks)
	local self = setmetatable({}, BuildUI)
	self.Callbacks = callbacks or {}
	self.Catalog = {}
	self.Categories = {}
	self.InventoryButtons = {}
	self.HotbarButtons = {}
	self.HotbarIds = {}
	self.Favorites = {}
	self.SelectedPart = nil
	self.SelectedCategory = "ALL"
	self.SearchText = ""
	self.PaintRegion = "All"
	self.PaintColor = Color3.fromRGB(214, 218, 222)
	self.MaterialIndex = 1
	self.BindingIndex = 1
	self.NodeVisible = true

	local gui = Instance.new("ScreenGui")
	gui.Name = "GodMachinesBuildUI"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 20
	gui.Parent = playerGui
	self.Gui = gui

	local hint = Instance.new("TextLabel")
	hint.AnchorPoint = Vector2.new(0.5, 1)
	hint.Position = UDim2.new(0.5, 0, 1, -20)
	hint.Size = UDim2.fromOffset(240, 38)
	hint.BackgroundColor3 = COLORS.Panel
	hint.BackgroundTransparency = 0.05
	hint.Text = "[ B ]  OPEN MACHINE WORKSHOP"
	hint.TextColor3 = COLORS.Accent
	hint.Font = Enum.Font.GothamBold
	hint.TextSize = 12
	hint.Parent = gui
	corner(hint, 7)
	stroke(hint, 0.28)
	self.Hint = hint

	local root = Instance.new("Frame")
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundTransparency = 1
	root.Visible = false
	root.Parent = gui
	self.Root = root

	local top = Instance.new("Frame")
	top.Position = UDim2.fromOffset(18, 16)
	top.Size = UDim2.new(1, -36, 0, 46)
	top.BackgroundColor3 = COLORS.Background
	top.BackgroundTransparency = 0.04
	top.Parent = root
	corner(top, 8)
	stroke(top, 0.28)

	local title = label(top, "GOD MACHINES  //  MACHINE WORKSHOP", 16, true)
	title.Position = UDim2.fromOffset(15, 7)
	title.Size = UDim2.fromOffset(390, 32)
	title.TextColor3 = COLORS.Accent

	local modeLabel = label(top, "EDIT", 11, true)
	modeLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	modeLabel.Position = UDim2.new(0.5, 0, 0.5, 0)
	modeLabel.Size = UDim2.fromOffset(100, 28)
	modeLabel.TextXAlignment = Enum.TextXAlignment.Center
	modeLabel.TextColor3 = COLORS.Good
	self.ModeLabel = modeLabel

	local testButton = button(top, "TEST MACHINE", 132)
	testButton.AnchorPoint = Vector2.new(1, 0.5)
	testButton.Position = UDim2.new(1, -12, 0.5, 0)
	testButton.MouseButton1Click:Connect(function()
		if self.Callbacks.TestMachine then self.Callbacks.TestMachine() end
	end)
	self.TestButton = testButton

	local status = Instance.new("TextLabel")
	status.AnchorPoint = Vector2.new(0.5, 0)
	status.Position = UDim2.new(0.5, 0, 0, 69)
	status.Size = UDim2.fromOffset(320, 30)
	status.BackgroundColor3 = COLORS.Panel
	status.BackgroundTransparency = 0.02
	status.Text = "WORKSHOP READY"
	status.TextColor3 = COLORS.Accent
	status.TextSize = 11
	status.Font = Enum.Font.GothamBold
	status.Parent = root
	corner(status, 5)
	stroke(status, 0.48)
	self.Status = status

	-- LEFT: catalog
	local catalogPanel = Instance.new("Frame")
	catalogPanel.Position = UDim2.fromOffset(18, 72)
	catalogPanel.Size = UDim2.new(0, 355, 1, -164)
	catalogPanel.BackgroundColor3 = COLORS.Background
	catalogPanel.BackgroundTransparency = 0.03
	catalogPanel.Parent = root
	corner(catalogPanel, 8)
	stroke(catalogPanel, 0.28)

	local catTitle = label(catalogPanel, "PART CATALOG  //  100 PIECES", 14, true)
	catTitle.Position = UDim2.fromOffset(13, 10)
	catTitle.Size = UDim2.new(1, -26, 0, 22)

	local search = textbox(catalogPanel, "Search parts, roles, descriptions...", 34)
	search.Position = UDim2.fromOffset(12, 40)
	search.Size = UDim2.new(1, -24, 0, 34)
	search:GetPropertyChangedSignal("Text"):Connect(function()
		self.SearchText = string.lower(search.Text)
		self:_refreshCatalog()
	end)
	self.Search = search

	local categories = Instance.new("ScrollingFrame")
	categories.Position = UDim2.fromOffset(12, 82)
	categories.Size = UDim2.new(1, -24, 0, 38)
	categories.BackgroundTransparency = 1
	categories.BorderSizePixel = 0
	categories.ScrollBarThickness = 2
	categories.ScrollingDirection = Enum.ScrollingDirection.X
	categories.CanvasSize = UDim2.fromOffset(0, 0)
	categories.AutomaticCanvasSize = Enum.AutomaticSize.X
	categories.Parent = catalogPanel
	local catLayout = Instance.new("UIListLayout")
	catLayout.FillDirection = Enum.FillDirection.Horizontal
	catLayout.Padding = UDim.new(0, 6)
	catLayout.Parent = categories
	self.CategoryList = categories

	local list = Instance.new("ScrollingFrame")
	list.Position = UDim2.fromOffset(10, 127)
	list.Size = UDim2.new(1, -20, 1, -138)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 4
	list.ScrollBarImageColor3 = COLORS.Border
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.fromOffset(0, 0)
	list.Parent = catalogPanel
	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, 6)
	listLayout.Parent = list
	self.PartList = list

	-- RIGHT: inspector / tools
	local right = Instance.new("ScrollingFrame")
	right.AnchorPoint = Vector2.new(1, 0)
	right.Position = UDim2.new(1, -18, 0, 72)
	right.Size = UDim2.new(0, 330, 1, -92)
	right.BackgroundTransparency = 1
	right.BorderSizePixel = 0
	right.ScrollBarThickness = 4
	right.ScrollBarImageColor3 = COLORS.Border
	right.AutomaticCanvasSize = Enum.AutomaticSize.Y
	right.CanvasSize = UDim2.fromOffset(0, 0)
	right.Parent = root
	local rightLayout = Instance.new("UIListLayout")
	rightLayout.Padding = UDim.new(0, 8)
	rightLayout.Parent = right
	self.RightPanel = right

	local inspector = section(right, "COMPONENT DATA", 238)
	local partName = label(inspector, "NO COMPONENT", 16, true)
	partName.Position = UDim2.fromOffset(11, 29)
	partName.Size = UDim2.new(1, -22, 0, 25)
	partName.TextColor3 = COLORS.Accent
	self.PartName = partName
	local description = label(inspector, "", 11, false)
	description.Position = UDim2.fromOffset(11, 54)
	description.Size = UDim2.new(1, -22, 0, 50)
	description.TextColor3 = COLORS.Muted
	description.TextWrapped = true
	description.TextYAlignment = Enum.TextYAlignment.Top
	self.Description = description
	local stats = label(inspector, "", 11, false)
	stats.Position = UDim2.fromOffset(11, 106)
	stats.Size = UDim2.new(1, -22, 1, -114)
	stats.TextYAlignment = Enum.TextYAlignment.Top
	stats.TextWrapped = true
	self.Stats = stats

	local engineering = section(right, "LIVE ENGINEERING", 145)
	local engineeringText = label(engineering, "BUILD A MACHINE TO SEE LIVE DATA", 11, false)
	engineeringText.Position = UDim2.fromOffset(11, 30)
	engineeringText.Size = UDim2.new(1, -22, 1, -38)
	engineeringText.TextYAlignment = Enum.TextYAlignment.Top
	engineeringText.TextColor3 = COLORS.Muted
	self.EngineeringText = engineeringText

	local paint = section(right, "PAINT SHOP", 196)
	local regionButton = button(paint, "REGION: ALL", 146)
	regionButton.Position = UDim2.fromOffset(11, 31)
	regionButton.MouseButton1Click:Connect(function()
		self:_cyclePaintRegion()
	end)
	self.RegionButton = regionButton

	local materialButton = button(paint, "METAL", 146)
	materialButton.Position = UDim2.new(1, -157, 0, 31)
	materialButton.MouseButton1Click:Connect(function()
		self.MaterialIndex = self.MaterialIndex % #MATERIALS + 1
		materialButton.Text = string.upper(MATERIALS[self.MaterialIndex])
	end)
	self.MaterialButton = materialButton

	local hex = textbox(paint, "#D6DADD", 34)
	hex.Position = UDim2.fromOffset(11, 72)
	hex.Size = UDim2.new(1, -72, 0, 34)
	hex.Text = colorToHex(self.PaintColor)
	hex.FocusLost:Connect(function()
		local parsed = parseHex(hex.Text)
		if parsed then
			self.PaintColor = parsed
			hex.Text = colorToHex(parsed)
			self.PaintSwatch.BackgroundColor3 = parsed
		else
			hex.Text = colorToHex(self.PaintColor)
		end
	end)
	self.HexBox = hex

	local swatch = Instance.new("Frame")
	swatch.AnchorPoint = Vector2.new(1, 0)
	swatch.Position = UDim2.new(1, -11, 0, 72)
	swatch.Size = UDim2.fromOffset(48, 34)
	swatch.BackgroundColor3 = self.PaintColor
	swatch.Parent = paint
	corner(swatch, 5)
	stroke(swatch, 0.2)
	self.PaintSwatch = swatch

	local palette = {
		Color3.fromRGB(215,218,222), Color3.fromRGB(52,57,63), Color3.fromRGB(14,16,19),
		Color3.fromRGB(255,181,54), Color3.fromRGB(214,58,58), Color3.fromRGB(52,116,210),
		Color3.fromRGB(73,169,108), Color3.fromRGB(131,81,184), Color3.fromRGB(236,236,225),
	}
	for index, color in ipairs(palette) do
		local sw = Instance.new("TextButton")
		sw.Text = ""
		sw.Size = UDim2.fromOffset(27, 25)
		sw.Position = UDim2.fromOffset(11 + (index - 1) * 33, 114)
		sw.BackgroundColor3 = color
		sw.Parent = paint
		corner(sw, 4)
		stroke(sw, 0.35)
		sw.MouseButton1Click:Connect(function()
			self.PaintColor = color
			hex.Text = colorToHex(color)
			swatch.BackgroundColor3 = color
		end)
	end

	local applyPaint = button(paint, "PAINT TARGET", 148)
	applyPaint.Position = UDim2.fromOffset(11, 151)
	applyPaint.BackgroundColor3 = COLORS.AccentSoft
	applyPaint.MouseButton1Click:Connect(function()
		if self.Callbacks.PaintTarget then self.Callbacks.PaintTarget(self.PaintRegion, self.PaintColor, MATERIALS[self.MaterialIndex]) end
	end)
	local paintAll = button(paint, "PAINT ALL REGIONS", 148)
	paintAll.Position = UDim2.new(1, -159, 0, 151)
	paintAll.MouseButton1Click:Connect(function()
		if self.Callbacks.PaintTarget then self.Callbacks.PaintTarget("All", self.PaintColor, MATERIALS[self.MaterialIndex]) end
	end)

	local tools = section(right, "BUILD TOOLS", 114)
	local mirror = button(tools, "MIRROR", 92)
	mirror.Position = UDim2.fromOffset(11, 31)
	mirror.MouseButton1Click:Connect(function() if self.Callbacks.Mirror then self.Callbacks.Mirror() end end)
	local duplicate = button(tools, "DUPLICATE TARGET", 124)
	duplicate.Position = UDim2.fromOffset(109, 31)
	duplicate.MouseButton1Click:Connect(function() if self.Callbacks.DuplicateTarget then self.Callbacks.DuplicateTarget() end end)
	local nodes = button(tools, "NODES: ON", 78)
	nodes.Position = UDim2.new(1, -89, 0, 31)
	nodes.MouseButton1Click:Connect(function()
		self.NodeVisible = not self.NodeVisible
		nodes.Text = if self.NodeVisible then "NODES: ON" else "NODES: OFF"
		if self.Callbacks.ToggleNodes then self.Callbacks.ToggleNodes(self.NodeVisible) end
	end)
	local remove = button(tools, "REMOVE TARGET", 142)
	remove.Position = UDim2.fromOffset(11, 70)
	remove.MouseButton1Click:Connect(function() if self.Callbacks.RemoveTarget then self.Callbacks.RemoveTarget() end end)
	local undo = button(tools, "UNDO", 68)
	undo.Position = UDim2.fromOffset(159, 70)
	undo.MouseButton1Click:Connect(function() if self.Callbacks.Undo then self.Callbacks.Undo() end end)
	local redo = button(tools, "REDO", 68)
	redo.Position = UDim2.new(1, -79, 0, 70)
	redo.MouseButton1Click:Connect(function() if self.Callbacks.Redo then self.Callbacks.Redo() end end)

	local blueprint = section(right, "BLUEPRINTS", 117)
	local blueprintName = textbox(blueprint, "Blueprint name", 32)
	blueprintName.Position = UDim2.fromOffset(11, 31)
	blueprintName.Size = UDim2.new(1, -22, 0, 32)
	self.BlueprintName = blueprintName
	local save = button(blueprint, "SAVE CURRENT", 144)
	save.Position = UDim2.fromOffset(11, 72)
	save.MouseButton1Click:Connect(function()
		if self.Callbacks.SaveBlueprint then self.Callbacks.SaveBlueprint(blueprintName.Text) end
	end)
	local load = button(blueprint, "LOAD / SPAWN", 144)
	load.Position = UDim2.new(1, -155, 0, 72)
	load.MouseButton1Click:Connect(function()
		if self.Callbacks.LoadBlueprint then self.Callbacks.LoadBlueprint(blueprintName.Text) end
	end)

	local controls = section(right, "ADVANCED CONTROLS", 116)
	local action = button(controls, "ACTION: " .. string.upper(CONTROL_ACTIONS[1]), 298)
	action.Position = UDim2.fromOffset(11, 31)
	action.MouseButton1Click:Connect(function()
		self.BindingIndex = self.BindingIndex % #CONTROL_ACTIONS + 1
		action.Text = "ACTION: " .. string.upper(CONTROL_ACTIONS[self.BindingIndex])
	end)
	self.BindingButton = action
	local bind = button(controls, "TOGGLE TARGET", 144)
	bind.Position = UDim2.fromOffset(11, 72)
	bind.MouseButton1Click:Connect(function()
		if self.Callbacks.BindTarget then self.Callbacks.BindTarget(CONTROL_ACTIONS[self.BindingIndex]) end
	end)
	local auto = button(controls, "AUTO BIND", 144)
	auto.Position = UDim2.new(1, -155, 0, 72)
	auto.MouseButton1Click:Connect(function() if self.Callbacks.AutoBindings then self.Callbacks.AutoBindings() end end)

	-- Bottom hotbar and control legend.
	local hotbar = Instance.new("Frame")
	hotbar.AnchorPoint = Vector2.new(0.5, 1)
	hotbar.Position = UDim2.new(0.5, 0, 1, -18)
	hotbar.Size = UDim2.fromOffset(720, 68)
	hotbar.BackgroundColor3 = COLORS.Background
	hotbar.BackgroundTransparency = 0.02
	hotbar.Parent = root
	corner(hotbar, 8)
	stroke(hotbar, 0.28)
	local hotLayout = Instance.new("UIListLayout")
	hotLayout.FillDirection = Enum.FillDirection.Horizontal
	hotLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	hotLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	hotLayout.Padding = UDim.new(0, 5)
	hotLayout.Parent = hotbar
	self.Hotbar = hotbar

	local legend = label(root, "LMB PLACE   •   R ROTATE   •   X REMOVE   •   Z/Y UNDO/REDO   •   B CLOSE/EDIT", 10, false)
	legend.AnchorPoint = Vector2.new(0.5, 1)
	legend.Position = UDim2.new(0.5, 0, 1, -91)
	legend.Size = UDim2.fromOffset(650, 20)
	legend.TextXAlignment = Enum.TextXAlignment.Center
	legend.TextColor3 = COLORS.Muted

	return self
end

function BuildUI:SetBuildMode(enabled)
	self.Root.Visible = enabled == true
	self.Hint.Visible = enabled ~= true
end

function BuildUI:SetMode(mode)
	local text = string.upper(tostring(mode or "EDIT"))
	self.ModeLabel.Text = text
	if text == "TEST" then
		self.ModeLabel.TextColor3 = COLORS.Blue
		self.TestButton.Text = "RETURN TO EDIT"
	else
		self.ModeLabel.TextColor3 = COLORS.Good
		self.TestButton.Text = "TEST MACHINE"
	end
end

function BuildUI:SetStatus(text, tone)
	self.Status.Text = string.upper(tostring(text or ""))
	if tone == "good" then self.Status.TextColor3 = COLORS.Good
	elseif tone == "bad" then self.Status.TextColor3 = COLORS.Bad
	elseif tone == "blue" then self.Status.TextColor3 = COLORS.Blue
	else self.Status.TextColor3 = COLORS.Accent end
end

function BuildUI:_visiblePart(part)
	if self.SelectedCategory ~= "ALL" and part.Category ~= self.SelectedCategory then return false end
	local query = self.SearchText
	if query == "" then return true end
	local haystack = string.lower(table.concat({ part.DisplayName or "", part.ShortName or "", part.Category or "", part.Description or "", part.Id or "" }, " "))
	return string.find(haystack, query, 1, true) ~= nil
end

function BuildUI:_refreshCategories()
	clearGuiChildren(self.CategoryList)
	local values = { "ALL" }
	for _, category in ipairs(self.Categories) do table.insert(values, category) end
	for _, category in ipairs(values) do
		local item = button(self.CategoryList, string.upper(category), math.max(62, #category * 7 + 18))
		item.Size = UDim2.fromOffset(math.max(62, #category * 7 + 18), 30)
		if category == self.SelectedCategory then item.BackgroundColor3 = COLORS.AccentSoft; item.TextColor3 = COLORS.Accent end
		item.MouseButton1Click:Connect(function()
			self.SelectedCategory = category
			self:_refreshCategories()
			self:_refreshCatalog()
		end)
	end
end

function BuildUI:_refreshHotbar()
	clearGuiChildren(self.Hotbar)
	self.HotbarButtons = {}
	for slot = 1, 9 do
		local partId = self.HotbarIds[slot]
		local part = nil
		if partId then for _, candidate in ipairs(self.Catalog) do if candidate.Id == partId then part = candidate; break end end end
		local text = "[" .. slot .. "]"
		if part then text ..= " " .. string.upper(part.ShortName or part.DisplayName or part.Id) end
		local item = button(self.Hotbar, text, 72)
		item.Size = UDim2.fromOffset(72, 48)
		item.TextSize = 9
		item.TextWrapped = true
		if part and part.Id == self.SelectedPart then item.BackgroundColor3 = COLORS.Accent; item.TextColor3 = COLORS.Background end
		if part then
			item.MouseButton1Click:Connect(function() if self.Callbacks.SelectPart then self.Callbacks.SelectPart(part.Id) end end)
			self.HotbarButtons[part.Id] = item
		end
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

function BuildUI:_refreshCatalog()
	clearGuiChildren(self.PartList)
	self.InventoryButtons = {}
	for _, part in ipairs(self.Catalog) do
		if not self:_visiblePart(part) then continue end
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, -5, 0, 62)
		row.BackgroundColor3 = if part.Id == self.SelectedPart then COLORS.AccentSoft else COLORS.Panel2
		row.Parent = self.PartList
		corner(row, 6)
		stroke(row, 0.5)

		local main = Instance.new("TextButton")
		main.Size = UDim2.new(1, -46, 1, 0)
		main.BackgroundTransparency = 1
		main.Text = ""
		main.Parent = row
		main.MouseButton1Click:Connect(function() if self.Callbacks.SelectPart then self.Callbacks.SelectPart(part.Id) end end)

		local name = label(row, string.upper(part.DisplayName), 11, true)
		name.Position = UDim2.fromOffset(10, 7)
		name.Size = UDim2.new(1, -58, 0, 18)
		name.TextColor3 = if part.Id == self.SelectedPart then COLORS.Accent else COLORS.Text
		local meta = label(row, string.upper(part.Category) .. "  •  " .. tostring(math.floor(part.Mass or 0)) .. " KG", 9, false)
		meta.Position = UDim2.fromOffset(10, 26)
		meta.Size = UDim2.new(1, -58, 0, 14)
		meta.TextColor3 = COLORS.Muted
		local desc = label(row, tostring(part.Description or ""), 9, false)
		desc.Position = UDim2.fromOffset(10, 42)
		desc.Size = UDim2.new(1, -58, 0, 13)
		desc.TextColor3 = COLORS.Muted
		desc.TextTruncate = Enum.TextTruncate.AtEnd

		local star = Instance.new("TextButton")
		star.AnchorPoint = Vector2.new(1, 0.5)
		star.Position = UDim2.new(1, -7, 0.5, 0)
		star.Size = UDim2.fromOffset(34, 34)
		star.BackgroundColor3 = COLORS.Panel3
		star.Text = if self.Favorites[part.Id] then "★" else "☆"
		star.TextColor3 = if self.Favorites[part.Id] then COLORS.Accent else COLORS.Muted
		star.TextSize = 18
		star.Font = Enum.Font.GothamBold
		star.Parent = row
		corner(star, 5)
		star.MouseButton1Click:Connect(function() self:_toggleFavorite(part.Id) end)
		self.InventoryButtons[part.Id] = row
	end
end

function BuildUI:SetCatalog(parts, categories)
	self.Catalog = parts or {}
	self.Categories = categories or {}
	self.HotbarIds = {}
	self.Favorites = {}
	-- Seed the hotbar with one representative from each category so a fresh player has useful variety.
	local usedCategory = {}
	for _, part in ipairs(self.Catalog) do
		if #self.HotbarIds >= 9 then break end
		if not usedCategory[part.Category] then
			usedCategory[part.Category] = true
			self.Favorites[part.Id] = true
			table.insert(self.HotbarIds, part.Id)
		end
	end
	self:_refreshCategories()
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

function BuildUI:SetInspector(name, definition)
	self.PartName.Text = definition and string.upper(definition.DisplayName or name) or string.upper(tostring(name or "NO COMPONENT"))
	if not definition then
		self.Description.Text = ""
		self.Stats.Text = "NO DATA"
		return
	end
	self.Description.Text = tostring(definition.Description or "")
	local lines = {
		string.format("CATEGORY   %s", string.upper(tostring(definition.Category or "?"))),
		string.format("MASS       %.0f kg", tonumber(definition.Mass) or 0),
		string.format("HEALTH     %.0f", tonumber(definition.MaxHealth) or 0),
	}
	if definition.Size then table.insert(lines, string.format("BOUNDS     %.1f × %.1f × %.1f", definition.Size.X, definition.Size.Y, definition.Size.Z)) end
	if definition.Power then
		table.insert(lines, string.format("POWER      +%.0f / -%.0f", tonumber(definition.Power.Generation) or 0, tonumber(definition.Power.Demand) or 0))
	end
	if definition.Heat then table.insert(lines, string.format("HEAT       %.1f/s", tonumber(definition.Heat.Generation) or 0)) end
	if definition.Mobility then table.insert(lines, "MOBILITY   " .. string.upper(tostring(definition.Mobility.Kind or "YES"))) end
	if definition.Propulsion then table.insert(lines, string.format("THRUST     %.0f", tonumber(definition.Propulsion.Force) or 0)) end
	if definition.Aerodynamics then table.insert(lines, string.format("AERO AREA  %.1f", tonumber(definition.Aerodynamics.Area) or 0)) end
	if definition.Pilot then table.insert(lines, "CONTROL    PILOT CAPABLE") end
	if definition.Combat then table.insert(lines, string.format("WEAPON     %s", string.upper(tostring(definition.Combat.Preset or definition.Combat.Category or "YES")))) end
	self.Stats.Text = table.concat(lines, "\n")
	self.PaintRegions = { "All" }
	for _, region in ipairs(definition.PaintRegions or {}) do table.insert(self.PaintRegions, region) end
	self.PaintRegion = "All"
	self.RegionButton.Text = "REGION: ALL"
end

function BuildUI:_cyclePaintRegion()
	local regions = self.PaintRegions or { "All" }
	local index = table.find(regions, self.PaintRegion) or 1
	index = index % #regions + 1
	self.PaintRegion = regions[index]
	self.RegionButton.Text = "REGION: " .. string.upper(self.PaintRegion)
end

function BuildUI:SetEngineeringSummary(summary)
	if type(summary) ~= "table" then
		self.EngineeringText.Text = "BUILD A MACHINE TO SEE LIVE DATA"
		self.EngineeringText.TextColor3 = COLORS.Muted
		return
	end
	local powerGeneration = tonumber(summary.PowerGeneration) or 0
	local powerDemand = tonumber(summary.PowerDemand) or 0
	local balance = powerGeneration - powerDemand
	local lines = {
		string.format("PARTS       %d", tonumber(summary.PartCount) or 0),
		string.format("MASS        %.0f kg", tonumber(summary.Mass) or 0),
		string.format("POWER       %.0f gen / %.0f use  (%+.0f)", powerGeneration, powerDemand, balance),
		string.format("HEAT        %.1f/s", tonumber(summary.HeatGeneration) or 0),
		string.format("DRIVE       %.0f torque", tonumber(summary.DriveTorque) or 0),
		string.format("THRUST      %.0f", tonumber(summary.Thrust) or 0),
		string.format("LIFT AREA   %.1f", tonumber(summary.LiftArea) or 0),
		string.format("SEATS %d    WEAPONS %d", tonumber(summary.Seats) or 0, tonumber(summary.Weapons) or 0),
	}
	self.EngineeringText.Text = table.concat(lines, "\n")
	self.EngineeringText.TextColor3 = if balance < 0 then COLORS.Bad else COLORS.Text
end

function BuildUI:Destroy()
	if self.Gui then self.Gui:Destroy() end
end

return BuildUI
