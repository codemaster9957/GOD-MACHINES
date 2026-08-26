--!nonstrict
-- Owns the Workshop construction camera without coupling it to the large build controller.
-- The server/build controller remains authoritative for machine state; this script only
-- follows BuildMode + ActiveMechId and restores Roblox camera ownership when Workshop closes.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
if not player then
	return
end

local playerGui = player:WaitForChild("PlayerGui")
local WorkshopCamera = require(script.Parent:WaitForChild("WorkshopCamera"))
local WorkshopCameraBar = require(script.Parent:WaitForChild("WorkshopCameraBar"))

local WHEEL_OWNER_ATTRIBUTE = "GMWorkshopCameraOwnsWheel"

local workshopCamera = WorkshopCamera.new(UserInputService, RunService)
local active = false
local destroyed = false

local cameraGui = Instance.new("ScreenGui")
cameraGui.Name = "GodMachinesWorkshopCamera"
cameraGui.ResetOnSpawn = false
cameraGui.IgnoreGuiInset = true
cameraGui.DisplayOrder = 120
cameraGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
cameraGui.Parent = playerGui

local callbacks = {}
local cameraBar = WorkshopCameraBar.new(cameraGui, callbacks)
cameraBar:SetVisible(false)

local function activeMechId()
	local value = player:GetAttribute("ActiveMechId")
	return if type(value) == "string" and value ~= "" then value else nil
end

local function shiftDown()
	return UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
		or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
end

local function controlDown()
	return UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)
		or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)
end

local function altDown()
	return UserInputService:IsKeyDown(Enum.KeyCode.LeftAlt)
		or UserInputService:IsKeyDown(Enum.KeyCode.RightAlt)
end

local function setModeLabel()
	cameraBar:SetCameraMode(if workshopCamera.FreeFly then "Fly" else "Orbit")
end

local function frameCamera()
	if not active then return end
	workshopCamera:FrameMachine()
end

local function setOrbit()
	if not active then return end
	workshopCamera:SetFreeFly(false)
	setModeLabel()
end

local function toggleFreeFly()
	if not active then return false end
	local enabled = workshopCamera:SetFreeFly(not workshopCamera.FreeFly)
	setModeLabel()
	return enabled
end

local function setView(viewName)
	if not active then return false end
	local changed = workshopCamera:SetView(viewName)
	if changed then setModeLabel() end
	return changed
end

callbacks.FrameCamera = frameCamera
callbacks.SetOrbit = setOrbit
callbacks.ToggleFreeFly = toggleFreeFly
callbacks.CameraView = setView

local function setCameraActive(enabled)
	if destroyed then return end
	local shouldEnable = enabled == true
	if shouldEnable == active then
		if active then workshopCamera:SetMech(activeMechId()) end
		return
	end

	if shouldEnable then
		workshopCamera:SetMech(activeMechId())
		if not workshopCamera:Activate(activeMechId()) then
			UserInputService:SetAttribute(WHEEL_OWNER_ATTRIBUTE, false)
			cameraBar:SetVisible(false)
			return
		end
		active = true
		UserInputService:SetAttribute(WHEEL_OWNER_ATTRIBUTE, true)
		cameraBar:SetVisible(true)
		setModeLabel()
	else
		active = false
		UserInputService:SetAttribute(WHEEL_OWNER_ATTRIBUTE, false)
		cameraBar:SetVisible(false)
		workshopCamera:Deactivate("Close")
	end
end

-- Explicitly clear stale client state before following BuildMode.
UserInputService:SetAttribute(WHEEL_OWNER_ATTRIBUTE, false)
setCameraActive(player:GetAttribute("BuildMode") == true)

local buildModeConnection = player:GetAttributeChangedSignal("BuildMode"):Connect(function()
	setCameraActive(player:GetAttribute("BuildMode") == true)
end)

local mechConnection = player:GetAttributeChangedSignal("ActiveMechId"):Connect(function()
	workshopCamera:SetMech(activeMechId())
end)

local inputConnection = UserInputService.InputBegan:Connect(function(input, processed)
	if processed or not active then return end
	if UserInputService:GetFocusedTextBox() then return end

	-- Plain F frames the machine. Modifier variants remain available to the newer
	-- Workshop search/favourites QoL shortcuts.
	if input.KeyCode == Enum.KeyCode.F then
		if not shiftDown() and not controlDown() and not altDown() then frameCamera() end
		return
	end
	if input.KeyCode == Enum.KeyCode.V then
		toggleFreeFly()
		return
	end
	if input.KeyCode == Enum.KeyCode.Home then
		setView("Home")
		return
	end
	if input.KeyCode == Enum.KeyCode.KeypadOne then
		setView(if shiftDown() then "Rear" else "Front")
		return
	end
	if input.KeyCode == Enum.KeyCode.KeypadThree then
		setView(if shiftDown() then "Left" else "Right")
		return
	end
	if input.KeyCode == Enum.KeyCode.KeypadSeven then
		setView(if shiftDown() then "Bottom" else "Top")
		return
	end
end)

local renderConnection = RunService.RenderStepped:Connect(function(dt)
	if not active then return end

	-- Do not let held WASDQE move the engineering camera while a UI text field owns input.
	-- Scriptable ownership is already established; resume updates as soon as focus leaves.
	if UserInputService:GetFocusedTextBox() then return end

	workshopCamera:Update(dt)
end)

script.Destroying:Connect(function()
	if destroyed then return end
	destroyed = true
	active = false
	UserInputService:SetAttribute(WHEEL_OWNER_ATTRIBUTE, false)

	if buildModeConnection then buildModeConnection:Disconnect() end
	if mechConnection then mechConnection:Disconnect() end
	if inputConnection then inputConnection:Disconnect() end
	if renderConnection then renderConnection:Disconnect() end

	workshopCamera:Destroy()
	cameraBar:Destroy()
	cameraGui:Destroy()
end)

print("[GOD MACHINES] Workshop engineering camera ready")
