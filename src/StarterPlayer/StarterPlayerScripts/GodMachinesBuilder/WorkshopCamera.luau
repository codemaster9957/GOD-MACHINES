--!nonstrict
-- Machine-first construction camera. Client-only: never mutates machine/server state.

local Players = game:GetService("Players")

local WorkshopCamera = {}
WorkshopCamera.__index = WorkshopCamera

local MIN_DISTANCE = 2.5
local MAX_DISTANCE = 1200
local DEFAULT_RADIUS = 6
local FRAME_MARGIN = 1.28
local ORBIT_SENSITIVITY = 0.005
local PAN_SENSITIVITY = 0.0025
local ZOOM_SENSITIVITY = 0.13
local MIN_PITCH = math.rad(-85)
local MAX_PITCH = math.rad(85)

local VIEW_DIRECTIONS = {
	Front = Vector3.new(0, 0, -1),
	Rear = Vector3.new(0, 0, 1),
	Left = Vector3.new(-1, 0, 0),
	Right = Vector3.new(1, 0, 0),
	Top = Vector3.new(0, 1, 0),
	Bottom = Vector3.new(0, -1, 0),
}

local function currentCamera()
	return workspace.CurrentCamera
end

local function clamp(value, minimum, maximum)
	return math.max(minimum, math.min(maximum, value))
end

local function lookFromAngles(yaw, pitch)
	local cp = math.cos(pitch)
	return Vector3.new(cp * math.sin(yaw), math.sin(pitch), -cp * math.cos(yaw)).Unit
end

local function anglesFromLook(look)
	local unit = if look.Magnitude > 0.001 then look.Unit else Vector3.new(0, 0, -1)
	return math.atan2(unit.X, -unit.Z), math.asin(clamp(unit.Y, -1, 1))
end

local function basisFromLook(look)
	local right = look:Cross(Vector3.yAxis)
	if right.Magnitude < 0.001 then right = Vector3.xAxis else right = right.Unit end
	local up = right:Cross(look)
	if up.Magnitude < 0.001 then up = Vector3.yAxis else up = up.Unit end
	return right, up
end

local function easeOutCubic(alpha)
	local x = clamp(alpha, 0, 1)
	return 1 - (1 - x) ^ 3
end

function WorkshopCamera.new(UserInputService, RunService)
	local self = setmetatable({}, WorkshopCamera)
	self.UserInputService = UserInputService
	self.RunService = RunService
	self.Player = Players.LocalPlayer
	self.Active = false
	self.FreeFly = false
	self.MechId = nil
	self.FocusPosition = Vector3.zero
	self.FreePosition = Vector3.zero
	self.Radius = DEFAULT_RADIUS
	self.Distance = 18
	self.Yaw = 0
	self.Pitch = math.rad(-18)
	self._saved = nil
	self._orbitHeld = false
	self._panHeld = false
	self._dragDelta = Vector2.zero
	self._panDelta = Vector2.zero
	self._zoomDelta = 0
	self._transitionStarted = 0
	self._transitionDuration = 0.2
	self._transitionFrom = nil
	self._transitioning = false
	self._connections = {}

	table.insert(self._connections, UserInputService.InputBegan:Connect(function(input, processed)
		if not self.Active or processed then return end
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			self._orbitHeld = true
			UserInputService.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
			UserInputService.MouseIconEnabled = false
		elseif input.UserInputType == Enum.UserInputType.MouseButton3 then
			self._panHeld = true
			UserInputService.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
			UserInputService.MouseIconEnabled = false
		end
	end))

	table.insert(self._connections, UserInputService.InputEnded:Connect(function(input)
		if not self.Active then return end
		if input.UserInputType == Enum.UserInputType.MouseButton2 then self._orbitHeld = false end
		if input.UserInputType == Enum.UserInputType.MouseButton3 then self._panHeld = false end
		if not self._orbitHeld and not self._panHeld then
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
			UserInputService.MouseIconEnabled = true
		end
	end))

	table.insert(self._connections, UserInputService.InputChanged:Connect(function(input)
		if not self.Active then return end
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			local delta = Vector2.new(input.Delta.X, input.Delta.Y)
			if self._orbitHeld then self._dragDelta += delta end
			if self._panHeld then self._panDelta += delta end
		elseif input.UserInputType == Enum.UserInputType.MouseWheel then
			self._zoomDelta += input.Position.Z
		end
	end))

	return self
end

function WorkshopCamera:_findMech()
	if type(self.MechId) ~= "string" or self.MechId == "" then return nil end
	local assemblies = workspace:FindFirstChild("MechAssemblies")
	local model = assemblies and assemblies:FindFirstChild(self.MechId)
	return if model and model:IsA("Model") then model else nil
end

function WorkshopCamera:_bounds(instance)
	if not instance then return nil end
	if instance:IsA("Model") then
		local ok, cf, size = pcall(function()
			local a, b = instance:GetBoundingBox()
			return a, b
		end)
		if ok and typeof(cf) == "CFrame" and typeof(size) == "Vector3" then return cf, size end
	elseif instance:IsA("BasePart") then
		return instance.CFrame, instance.Size
	end
	return nil
end

function WorkshopCamera:_machineBounds()
	return self:_bounds(self:_findMech())
end

function WorkshopCamera:_fitDistance(radius)
	local camera = currentCamera()
	if not camera then return clamp(radius * 2.8, MIN_DISTANCE, MAX_DISTANCE) end
	local viewport = camera.ViewportSize
	local aspect = if viewport.Y > 0 then math.max(viewport.X / viewport.Y, 0.2) else (16 / 9)
	local verticalHalf = math.rad(camera.FieldOfView * 0.5)
	local horizontalHalf = math.atan(math.tan(verticalHalf) * aspect)
	local limitingHalf = math.max(0.08, math.min(verticalHalf, horizontalHalf))
	return clamp((radius / math.tan(limitingHalf)) * FRAME_MARGIN, MIN_DISTANCE, MAX_DISTANCE)
end

function WorkshopCamera:_setFocusFromBounds(cf, size)
	self.FocusPosition = cf.Position
	self.Radius = math.max(size.X, size.Y, size.Z, 1) * 0.5
	self.Distance = self:_fitDistance(self.Radius)
end

function WorkshopCamera:_saveState()
	local camera = currentCamera()
	if not camera then return nil end
	return {
		CameraType = camera.CameraType,
		CameraSubject = camera.CameraSubject,
		CFrame = camera.CFrame,
		Focus = camera.Focus,
		FieldOfView = camera.FieldOfView,
		MouseBehavior = self.UserInputService.MouseBehavior,
		MouseIconEnabled = self.UserInputService.MouseIconEnabled,
	}
end

function WorkshopCamera:_restoreState(reason)
	local saved = self._saved
	local camera = currentCamera()
	if saved and camera then
		camera.CameraType = saved.CameraType or Enum.CameraType.Custom
		camera.CameraSubject = saved.CameraSubject
		camera.FieldOfView = saved.FieldOfView or 70
		if reason ~= "Test" then
			camera.CFrame = saved.CFrame
			camera.Focus = saved.Focus
		end
	elseif camera then
		camera.CameraType = Enum.CameraType.Custom
	end
	self.UserInputService.MouseBehavior = (saved and saved.MouseBehavior) or Enum.MouseBehavior.Default
	self.UserInputService.MouseIconEnabled = if saved then saved.MouseIconEnabled else true
end

function WorkshopCamera:_ignoreList()
	local list = {}
	local mech = self:_findMech()
	if mech then table.insert(list, mech) end
	local character = self.Player and self.Player.Character
	if character then table.insert(list, character) end
	return list
end

function WorkshopCamera:_obstructionAdjusted(focus, desired)
	local offset = desired - focus
	local magnitude = offset.Magnitude
	if magnitude <= 0.01 then return desired end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = self:_ignoreList()
	params.IgnoreWater = true
	local hit = workspace:Raycast(focus, offset, params)
	if not hit then return desired end
	local safe = math.max(1.5, hit.Distance - 0.6)
	return focus + offset.Unit * math.min(safe, magnitude)
end

function WorkshopCamera:SetMech(mechId)
	self.MechId = if type(mechId) == "string" and mechId ~= "" then mechId else nil
	if self.Active then self:FrameMachine() end
end

function WorkshopCamera:FrameMachine()
	local cf, size = self:_machineBounds()
	if cf and size then
		self:_setFocusFromBounds(cf, size)
	else
		local camera = currentCamera()
		self.Radius = DEFAULT_RADIUS
		if camera then
			self.FocusPosition = camera.CFrame.Position + camera.CFrame.LookVector * 12
			self.Yaw, self.Pitch = anglesFromLook(camera.CFrame.LookVector)
		else
			self.FocusPosition = Vector3.zero
		end
		self.Distance = self:_fitDistance(self.Radius)
	end
	if self.FreeFly then
		local look = lookFromAngles(self.Yaw, self.Pitch)
		self.FreePosition = self.FocusPosition - look * self.Distance
	end
	return self.FocusPosition
end

function WorkshopCamera:FocusComponent(instance)
	if not instance then return false end
	local current = instance
	local chosen = nil
	while current and current ~= workspace do
		if current:IsA("Model") and current:GetAttribute("ComponentId") ~= nil then chosen = current; break end
		if current:IsA("BasePart") and current:GetAttribute("ComponentRoot") == true then chosen = current; break end
		current = current.Parent
	end
	if not chosen then return false end
	local cf, size = self:_bounds(chosen)
	if not cf or not size then return false end
	self:_setFocusFromBounds(cf, size)
	if self.FreeFly then
		local look = lookFromAngles(self.Yaw, self.Pitch)
		self.FreePosition = self.FocusPosition - look * self.Distance
	end
	return true
end

function WorkshopCamera:SetView(viewName)
	if viewName == "Home" then
		self.FreeFly = false
		self:FrameMachine()
		return true
	end
	local direction = VIEW_DIRECTIONS[viewName]
	if not direction then return false end
	self.FreeFly = false
	self:FrameMachine()
	local towardFocus = -direction
	self.Yaw, self.Pitch = anglesFromLook(towardFocus)
	return true
end

function WorkshopCamera:SetFreeFly(enabled)
	local nextValue = enabled == true
	if nextValue == self.FreeFly then return self.FreeFly end
	local camera = currentCamera()
	self.FreeFly = nextValue
	if camera then
		self.Yaw, self.Pitch = anglesFromLook(camera.CFrame.LookVector)
		if nextValue then
			self.FreePosition = camera.CFrame.Position
		else
			self.FocusPosition = camera.CFrame.Position + camera.CFrame.LookVector * self.Distance
		end
	end
	return self.FreeFly
end

function WorkshopCamera:Activate(mechId)
	local camera = currentCamera()
	if not camera then return false end
	if not self.Active then
		self._saved = self:_saveState()
		self._transitionFrom = camera.CFrame
	end
	self.Active = true
	self.MechId = if type(mechId) == "string" and mechId ~= "" then mechId else self.MechId
	camera.CameraType = Enum.CameraType.Scriptable
	self.Yaw, self.Pitch = anglesFromLook(camera.CFrame.LookVector)
	self:FrameMachine()
	self._transitionStarted = os.clock()
	self._transitioning = true
	return true
end

function WorkshopCamera:Deactivate(reason)
	if not self.Active then return end
	self.Active = false
	self.FreeFly = false
	self._orbitHeld = false
	self._panHeld = false
	self._dragDelta = Vector2.zero
	self._panDelta = Vector2.zero
	self._zoomDelta = 0
	self:_restoreState(reason)
	self._saved = nil
	self._transitioning = false
end

function WorkshopCamera:_movementSpeed()
	local base = clamp(self.Radius * 1.6, 8, 180)
	local precision = self.UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or self.UserInputService:IsKeyDown(Enum.KeyCode.RightControl)
	local boost = self.UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or self.UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
	if precision then return base * 0.2 end
	if boost then return base * 3 end
	return base
end

function WorkshopCamera:Update(dt)
	if not self.Active then return end
	local camera = currentCamera()
	if not camera then return end
	camera.CameraType = Enum.CameraType.Scriptable

	if self._dragDelta.Magnitude > 0 then
		self.Yaw -= self._dragDelta.X * ORBIT_SENSITIVITY
		self.Pitch = clamp(self.Pitch - self._dragDelta.Y * ORBIT_SENSITIVITY, MIN_PITCH, MAX_PITCH)
		self._dragDelta = Vector2.zero
	end

	if self._zoomDelta ~= 0 then
		self.Distance = clamp(self.Distance * math.exp(-self._zoomDelta * ZOOM_SENSITIVITY), MIN_DISTANCE, MAX_DISTANCE)
		self._zoomDelta = 0
	end

	local look = lookFromAngles(self.Yaw, self.Pitch)
	local right, up = basisFromLook(look)

	if self._panDelta.Magnitude > 0 and not self.FreeFly then
		local scale = self.Distance * PAN_SENSITIVITY
		self.FocusPosition += (-self._panDelta.X * right + self._panDelta.Y * up) * scale
		self._panDelta = Vector2.zero
	else
		self._panDelta = Vector2.zero
	end

	local move = Vector3.zero
	if self.UserInputService:IsKeyDown(Enum.KeyCode.W) then move += look end
	if self.UserInputService:IsKeyDown(Enum.KeyCode.S) then move -= look end
	if self.UserInputService:IsKeyDown(Enum.KeyCode.D) then move += right end
	if self.UserInputService:IsKeyDown(Enum.KeyCode.A) then move -= right end
	if self.UserInputService:IsKeyDown(Enum.KeyCode.E) then move += Vector3.yAxis end
	if self.UserInputService:IsKeyDown(Enum.KeyCode.Q) then move -= Vector3.yAxis end
	if move.Magnitude > 0 then
		local delta = move.Unit * self:_movementSpeed() * math.min(dt, 0.05)
		if self.FreeFly then self.FreePosition += delta else self.FocusPosition += delta end
	end

	local targetCFrame
	if self.FreeFly then
		targetCFrame = CFrame.lookAt(self.FreePosition, self.FreePosition + look, up)
		self.FocusPosition = self.FreePosition + look * math.max(self.Distance, self.Radius * 1.5)
	else
		local desired = self.FocusPosition - look * self.Distance
		local adjusted = self:_obstructionAdjusted(self.FocusPosition, desired)
		targetCFrame = CFrame.lookAt(adjusted, self.FocusPosition, up)
	end

	if self._transitioning and self._transitionFrom then
		local alpha = (os.clock() - self._transitionStarted) / self._transitionDuration
		if alpha >= 1 then
			self._transitioning = false
			camera.CFrame = targetCFrame
		else
			camera.CFrame = self._transitionFrom:Lerp(targetCFrame, easeOutCubic(alpha))
		end
	else
		camera.CFrame = targetCFrame
	end
	camera.Focus = CFrame.new(self.FocusPosition)
end

function WorkshopCamera:Destroy()
	if self.Active then self:Deactivate("Destroy") end
	for _, connection in ipairs(self._connections) do
		connection:Disconnect()
	end
	table.clear(self._connections)
end

return WorkshopCamera
