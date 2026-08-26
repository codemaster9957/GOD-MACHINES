--!nonstrict
-- Compact Workshop V3 camera controls. Presentation only; no direct camera/server ownership.

local WorkshopCameraBar = {}
WorkshopCameraBar.__index = WorkshopCameraBar

local COLORS = {
	Panel = Color3.fromRGB(15, 18, 22),
	Raised = Color3.fromRGB(27, 31, 36),
	Hover = Color3.fromRGB(38, 43, 49),
	Border = Color3.fromRGB(72, 79, 86),
	Text = Color3.fromRGB(230, 234, 237),
	Muted = Color3.fromRGB(125, 134, 143),
	Amber = Color3.fromRGB(255, 178, 48),
	AmberDeep = Color3.fromRGB(61, 45, 24),
}

local function corner(parent, radius)
	local item = Instance.new("UICorner")
	item.CornerRadius = UDim.new(0, radius or 5)
	item.Parent = parent
end

local function stroke(parent, color, transparency)
	local item = Instance.new("UIStroke")
	item.Color = color or COLORS.Border
	item.Transparency = transparency or 0.2
	item.Thickness = 1
	item.Parent = parent
end

local function makeButton(parent, text, width)
	local button = Instance.new("TextButton")
	button.Size = UDim2.fromOffset(width or 62, 28)
	button.BackgroundColor3 = COLORS.Raised
	button.BorderSizePixel = 0
	button.AutoButtonColor = false
	button.Text = text
	button.TextColor3 = COLORS.Text
	button.TextSize = 8
	button.Font = Enum.Font.GothamBold
	button.Parent = parent
	corner(button, 4)
	stroke(button, COLORS.Border, 0.25)
	button.MouseEnter:Connect(function()
		if button:GetAttribute("Selected") ~= true then button.BackgroundColor3 = COLORS.Hover end
	end)
	button.MouseLeave:Connect(function()
		if button:GetAttribute("Selected") == true then
			button.BackgroundColor3 = COLORS.AmberDeep
			button.TextColor3 = COLORS.Amber
		else
			button.BackgroundColor3 = COLORS.Raised
			button.TextColor3 = COLORS.Text
		end
	end)
	return button
end

function WorkshopCameraBar.new(parent, callbacks)
	local self = setmetatable({}, WorkshopCameraBar)
	self.Callbacks = callbacks or {}
	self.Mode = "Orbit"

	local frame = Instance.new("Frame")
	frame.Name = "WorkshopCameraBar"
	frame.AnchorPoint = Vector2.new(0.5, 0)
	frame.Position = UDim2.new(0.5, 0, 0, 116)
	frame.Size = UDim2.fromOffset(506, 38)
	frame.BackgroundColor3 = COLORS.Panel
	frame.BackgroundTransparency = 0.04
	frame.BorderSizePixel = 0
	frame.Visible = false
	frame.ZIndex = 30
	frame.Parent = parent
	corner(frame, 7)
	stroke(frame, COLORS.Border, 0.12)
	self.Frame = frame

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 5)
	layout.Parent = frame

	local orbit = makeButton(frame, "ORBIT", 58)
	local fly = makeButton(frame, "FLY [V]", 62)
	local front = makeButton(frame, "FRONT", 58)
	local side = makeButton(frame, "SIDE", 56)
	local top = makeButton(frame, "TOP", 50)
	local frameMachine = makeButton(frame, "F FRAME", 70)
	local home = makeButton(frame, "HOME", 54)

	self.OrbitButton = orbit
	self.FlyButton = fly

	orbit.MouseButton1Click:Connect(function()
		if self.Callbacks.SetOrbit then self.Callbacks.SetOrbit() end
	end)
	fly.MouseButton1Click:Connect(function()
		if self.Callbacks.ToggleFreeFly then self.Callbacks.ToggleFreeFly() end
	end)
	front.MouseButton1Click:Connect(function()
		if self.Callbacks.CameraView then self.Callbacks.CameraView("Front") end
	end)
	side.MouseButton1Click:Connect(function()
		if self.Callbacks.CameraView then self.Callbacks.CameraView("Right") end
	end)
	top.MouseButton1Click:Connect(function()
		if self.Callbacks.CameraView then self.Callbacks.CameraView("Top") end
	end)
	frameMachine.MouseButton1Click:Connect(function()
		if self.Callbacks.FrameCamera then self.Callbacks.FrameCamera() end
	end)
	home.MouseButton1Click:Connect(function()
		if self.Callbacks.CameraView then self.Callbacks.CameraView("Home") end
	end)

	self:SetCameraMode("Orbit")
	return self
end

function WorkshopCameraBar:SetVisible(visible)
	self.Frame.Visible = visible == true
end

function WorkshopCameraBar:SetCameraMode(mode)
	self.Mode = if mode == "Fly" then "Fly" else "Orbit"
	local fly = self.Mode == "Fly"
	self.OrbitButton:SetAttribute("Selected", not fly)
	self.FlyButton:SetAttribute("Selected", fly)
	self.OrbitButton.BackgroundColor3 = if fly then COLORS.Raised else COLORS.AmberDeep
	self.OrbitButton.TextColor3 = if fly then COLORS.Text else COLORS.Amber
	self.FlyButton.BackgroundColor3 = if fly then COLORS.AmberDeep else COLORS.Raised
	self.FlyButton.TextColor3 = if fly then COLORS.Amber else COLORS.Text
end

function WorkshopCameraBar:Destroy()
	if self.Frame then self.Frame:Destroy() end
end

return WorkshopCameraBar
