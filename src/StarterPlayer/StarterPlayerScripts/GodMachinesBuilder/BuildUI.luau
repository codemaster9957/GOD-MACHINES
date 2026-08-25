--!nonstrict

local BuildUI = {}
BuildUI.__index = BuildUI

--------------------------------------------------
-- COLORS
--------------------------------------------------

local COLORS = {
	Background = Color3.fromRGB(12, 14, 17),
	Panel = Color3.fromRGB(20, 23, 27),
	Panel2 = Color3.fromRGB(27, 31, 36),

	Border = Color3.fromRGB(75, 82, 89),

	Text = Color3.fromRGB(235, 238, 240),
	Muted = Color3.fromRGB(145, 153, 160),

	Accent = Color3.fromRGB(255, 181, 54),
	Good = Color3.fromRGB(78, 230, 135),
	Bad = Color3.fromRGB(255, 76, 76),
}

--------------------------------------------------
-- HELPERS
--------------------------------------------------

local function corner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 6)
	c.Parent = parent
end

local function stroke(parent)
	local s = Instance.new("UIStroke")
	s.Color = COLORS.Border
	s.Transparency = 0.35
	s.Thickness = 1
	s.Parent = parent
end

local function label(parent, text, size)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Text = text
	l.TextColor3 = COLORS.Text
	l.TextSize = size or 14
	l.Font = Enum.Font.GothamMedium
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Parent = parent
	return l
end

--------------------------------------------------
-- CREATE
--------------------------------------------------

function BuildUI.new(playerGui)
	local self = setmetatable({}, BuildUI)

	local gui = Instance.new("ScreenGui")
	gui.Name = "GodMachinesBuildUI"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = playerGui

	self.Gui = gui

	--------------------------------------------------
	-- CLOSED BUILD HINT
	--------------------------------------------------

	local hint = Instance.new("TextLabel")
	hint.AnchorPoint = Vector2.new(0.5, 1)
	hint.Position = UDim2.new(0.5, 0, 1, -22)
	hint.Size = UDim2.fromOffset(180, 36)

	hint.BackgroundColor3 = COLORS.Panel
	hint.Text = "[ B ]  BUILD MODE"
	hint.TextColor3 = COLORS.Accent
	hint.Font = Enum.Font.GothamBold
	hint.TextSize = 14

	hint.Parent = gui

	corner(hint, 6)
	stroke(hint)

	self.Hint = hint

	--------------------------------------------------
	-- BUILD ROOT
	--------------------------------------------------

	local root = Instance.new("Frame")
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundTransparency = 1
	root.Visible = false
	root.Parent = gui

	self.Root = root

	--------------------------------------------------
	-- TITLE
	--------------------------------------------------

	local title = label(
		root,
		"GOD MACHINES // CONSTRUCTION MODE",
		18
	)

	title.Position = UDim2.fromOffset(24, 20)
	title.Size = UDim2.fromOffset(420, 32)
	title.Font = Enum.Font.GothamBold
	title.TextColor3 = COLORS.Accent

	--------------------------------------------------
	-- STATUS
	--------------------------------------------------

	local status = Instance.new("TextLabel")

	status.AnchorPoint = Vector2.new(0.5, 0)
	status.Position = UDim2.new(0.5, 0, 0, 25)
	status.Size = UDim2.fromOffset(260, 34)

	status.BackgroundColor3 = COLORS.Panel
	status.Text = "FREE PLACEMENT"
	status.TextColor3 = COLORS.Accent

	status.TextSize = 13
	status.Font = Enum.Font.GothamBold

	status.Parent = root

	corner(status, 5)
	stroke(status)

	self.Status = status

	--------------------------------------------------
	-- LEFT INVENTORY
	--------------------------------------------------

	local inventory = Instance.new("Frame")

	inventory.Position = UDim2.fromOffset(22, 70)
	inventory.Size = UDim2.fromOffset(240, 330)

	inventory.BackgroundColor3 = COLORS.Background
	inventory.BackgroundTransparency = 0.08

	inventory.Parent = root

	corner(inventory, 8)
	stroke(inventory)

	local invTitle = label(
		inventory,
		"PART INVENTORY",
		15
	)

	invTitle.Position = UDim2.fromOffset(14, 12)
	invTitle.Size = UDim2.new(1, -28, 0, 24)
	invTitle.Font = Enum.Font.GothamBold

	local subtitle = label(
		inventory,
		"SELECT COMPONENT",
		11
	)

	subtitle.Position = UDim2.fromOffset(14, 37)
	subtitle.Size = UDim2.new(1, -28, 0, 18)
	subtitle.TextColor3 = COLORS.Muted

	local list = Instance.new("Frame")
	list.Position = UDim2.fromOffset(10, 64)
	list.Size = UDim2.new(1, -20, 1, -74)
	list.BackgroundTransparency = 1
	list.Parent = inventory

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 7)
	layout.Parent = list

	self.PartList = list

	--------------------------------------------------
	-- RIGHT INSPECTOR
	--------------------------------------------------

	local inspector = Instance.new("Frame")

	inspector.AnchorPoint = Vector2.new(1, 0)
	inspector.Position = UDim2.new(1, -22, 0, 70)
	inspector.Size = UDim2.fromOffset(260, 330)

	inspector.BackgroundColor3 = COLORS.Background
	inspector.BackgroundTransparency = 0.08

	inspector.Parent = root

	corner(inspector, 8)
	stroke(inspector)

	local inspectorTitle =
		label(
			inspector,
			"COMPONENT DATA",
			15
		)

	inspectorTitle.Position =
		UDim2.fromOffset(14, 12)

	inspectorTitle.Size =
		UDim2.new(1, -28, 0, 25)

	inspectorTitle.Font =
		Enum.Font.GothamBold

	local name =
		label(
			inspector,
			"NO COMPONENT",
			17
		)

	name.Position =
		UDim2.fromOffset(14, 46)

	name.Size =
		UDim2.new(1, -28, 0, 28)

	name.Font =
		Enum.Font.GothamBold

	name.TextColor3 =
		COLORS.Accent

	self.PartName = name

	local stats =
		label(
			inspector,
			"",
			13
		)

	stats.Position =
		UDim2.fromOffset(14, 84)

	stats.Size =
		UDim2.new(1, -28, 1, -96)

	stats.TextYAlignment =
		Enum.TextYAlignment.Top

	stats.TextWrapped = true

	self.Stats = stats

	--------------------------------------------------
	-- CONTROLS
	--------------------------------------------------

	local controls =
		Instance.new("TextLabel")

	controls.AnchorPoint =
		Vector2.new(1, 1)

	controls.Position =
		UDim2.new(1, -22, 1, -22)

	controls.Size =
		UDim2.fromOffset(300, 125)

	controls.BackgroundColor3 =
		COLORS.Background

	controls.BackgroundTransparency =
		0.08

	controls.TextColor3 =
		COLORS.Muted

	controls.Text =
		"[LMB] PLACE\n[R] ROTATE\n[X] REMOVE\n[Z] UNDO   [Y] REDO\n[B] EXIT BUILD MODE"

	controls.TextSize = 12
	controls.Font = Enum.Font.GothamMedium

	controls.TextXAlignment =
		Enum.TextXAlignment.Left

	controls.TextYAlignment =
		Enum.TextYAlignment.Top

	controls.Parent = root

	corner(controls, 8)
	stroke(controls)

	local pad =
		Instance.new("UIPadding")

	pad.PaddingTop =
		UDim.new(0, 12)

	pad.PaddingLeft =
		UDim.new(0, 14)

	pad.Parent = controls

	--------------------------------------------------
	-- HOTBAR
	--------------------------------------------------

	local hotbar =
		Instance.new("Frame")

	hotbar.AnchorPoint =
		Vector2.new(0.5, 1)

	hotbar.Position =
		UDim2.new(0.5, 0, 1, -25)

	hotbar.Size =
		UDim2.fromOffset(470, 74)

	hotbar.BackgroundColor3 =
		COLORS.Background

	hotbar.BackgroundTransparency =
		0.05

	hotbar.Parent = root

	corner(hotbar, 8)
	stroke(hotbar)

	local hotLayout =
		Instance.new("UIListLayout")

	hotLayout.FillDirection =
		Enum.FillDirection.Horizontal

	hotLayout.HorizontalAlignment =
		Enum.HorizontalAlignment.Center

	hotLayout.VerticalAlignment =
		Enum.VerticalAlignment.Center

	hotLayout.Padding =
		UDim.new(0, 8)

	hotLayout.Parent = hotbar

	self.Hotbar = hotbar
	self.InventoryButtons = {}
	self.HotbarButtons = {}

	return self
end

--------------------------------------------------
-- BUILD MODE
--------------------------------------------------

function BuildUI:SetBuildMode(enabled)
	self.Root.Visible = enabled
	self.Hint.Visible = not enabled
end

--------------------------------------------------
-- PART LIST
--------------------------------------------------

function BuildUI:SetParts(parts, callback)
	for _, part in ipairs(parts) do

		--------------------------------------------------
		-- INVENTORY BUTTON
		--------------------------------------------------

		local button =
			Instance.new("TextButton")

		button.Size =
			UDim2.new(1, 0, 0, 48)

		button.BackgroundColor3 =
			COLORS.Panel2

		button.AutoButtonColor = false

		button.Text =
			part.DisplayName

		button.TextColor3 =
			COLORS.Text

		button.TextSize = 13

		button.Font =
			Enum.Font.GothamBold

		button.Parent =
			self.PartList

		corner(button, 5)
		stroke(button)

		button.MouseButton1Click:Connect(function()
			callback(part.Id)
		end)

		self.InventoryButtons[part.Id] =
			button

		--------------------------------------------------
		-- HOTBAR BUTTON
		--------------------------------------------------

		local hot =
			Instance.new("TextButton")

		hot.Size =
			UDim2.fromOffset(138, 52)

		hot.BackgroundColor3 =
			COLORS.Panel2

		hot.Text =
			"[" ..
			tostring(part.Slot) ..
			"]  " ..
			part.ShortName

		hot.TextColor3 =
			COLORS.Text

		hot.TextSize = 12

		hot.Font =
			Enum.Font.GothamBold

		hot.Parent =
			self.Hotbar

		corner(hot, 5)
		stroke(hot)

		hot.MouseButton1Click:Connect(function()
			callback(part.Id)
		end)

		self.HotbarButtons[part.Id] =
			hot
	end
end

--------------------------------------------------
-- SELECTED PART
--------------------------------------------------

function BuildUI:SetSelectedPart(partType)
	for id, button in pairs(self.InventoryButtons) do
		button.BackgroundColor3 =
			id == partType
			and COLORS.Accent
			or COLORS.Panel2

		button.TextColor3 =
			id == partType
			and COLORS.Background
			or COLORS.Text
	end

	for id, button in pairs(self.HotbarButtons) do
		button.BackgroundColor3 =
			id == partType
			and COLORS.Accent
			or COLORS.Panel2

		button.TextColor3 =
			id == partType
			and COLORS.Background
			or COLORS.Text
	end
end

--------------------------------------------------
-- INSPECTOR
--------------------------------------------------

function BuildUI:SetInspector(name, definition)
	self.PartName.Text = name

	if not definition then
		self.Stats.Text = "NO DATA"
		return
	end

	local lines = {}

	table.insert(
		lines,
		"MASS       " ..
			tostring(definition.Mass or 0)
	)

	table.insert(
		lines,
		"HEALTH     " ..
			tostring(definition.MaxHealth or 0)
	)

	if definition.Size then
		table.insert(
			lines,
			string.format(
				"SIZE       %.1f × %.1f × %.1f",
				definition.Size.X,
				definition.Size.Y,
				definition.Size.Z
			)
		)
	end

	if definition.Power then
		table.insert(lines, "")
		table.insert(lines, "POWER")

		if definition.Power.Generation then
			table.insert(
				lines,
				"  GENERATION  +" ..
					tostring(
						definition.Power.Generation
					)
			)
		end

		if definition.Power.Demand then
			table.insert(
				lines,
				"  DEMAND      " ..
					tostring(
						definition.Power.Demand
					)
			)
		end
	end

	if definition.Heat then
		table.insert(lines, "")
		table.insert(lines, "HEAT")

		table.insert(
			lines,
			"  GENERATION  " ..
				tostring(
					definition.Heat.Generation or 0
				)
		)
	end

	if definition.Combat then
		table.insert(lines, "")
		table.insert(lines, "WEAPON")

		table.insert(
			lines,
			"  DAMAGE      " ..
				tostring(
					definition.Combat.Damage or 0
				)
		)

		table.insert(
			lines,
			"  RANGE       " ..
				tostring(
					definition.Combat.Range or 0
				)
		)
	end

	self.Stats.Text =
		table.concat(lines, "\n")
end

--------------------------------------------------
-- STATUS
--------------------------------------------------

function BuildUI:SetStatus(text, tone)
	self.Status.Text =
		string.upper(tostring(text))

	if tone == "good" then
		self.Status.TextColor3 =
			COLORS.Good

	elseif tone == "bad" then
		self.Status.TextColor3 =
			COLORS.Bad

	else
		self.Status.TextColor3 =
			COLORS.Accent
	end
end

return BuildUI