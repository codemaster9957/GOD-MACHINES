--!nonstrict
-- Build-mode input adapter. Machine driving owns these keys only outside construction mode.
-- QoL aliases deliberately call the same callbacks as the original controls.

local BuildInput = {}
BuildInput.__index = BuildInput

local NUMBER_KEYS = {
	[Enum.KeyCode.One] = 1,
	[Enum.KeyCode.Two] = 2,
	[Enum.KeyCode.Three] = 3,
	[Enum.KeyCode.Four] = 4,
	[Enum.KeyCode.Five] = 5,
	[Enum.KeyCode.Six] = 6,
	[Enum.KeyCode.Seven] = 7,
	[Enum.KeyCode.Eight] = 8,
	[Enum.KeyCode.Nine] = 9,
}

local function keyHeld(UserInputService, left, right)
	return UserInputService:IsKeyDown(left) or UserInputService:IsKeyDown(right)
end

function BuildInput.new(UserInputService, callbacks)
	local self = setmetatable({}, BuildInput)
	self.Active = false
	self.CurrentSlot = 1

	local function ctrlHeld()
		return keyHeld(UserInputService, Enum.KeyCode.LeftControl, Enum.KeyCode.RightControl)
	end
	local function shiftHeld()
		return keyHeld(UserInputService, Enum.KeyCode.LeftShift, Enum.KeyCode.RightShift)
	end
	local function altHeld()
		return keyHeld(UserInputService, Enum.KeyCode.LeftAlt, Enum.KeyCode.RightAlt)
	end
	local function selectSlot(slot)
		self.CurrentSlot = math.clamp(slot, 1, 9)
		callbacks.SelectSlot(self.CurrentSlot)
	end

	self._connection = UserInputService.InputBegan:Connect(function(input, processed)
		if processed then return end
		if UserInputService:GetFocusedTextBox() then return end

		if input.KeyCode == Enum.KeyCode.B then
			callbacks.Toggle()
			return
		end
		if not self.Active then return end

		if input.KeyCode == Enum.KeyCode.Escape then callbacks.Toggle(); return end

		local slot = NUMBER_KEYS[input.KeyCode]
		if slot then
			if altHeld() or not ctrlHeld() then selectSlot(slot) end
			return
		end

		if ctrlHeld() then
			if input.KeyCode == Enum.KeyCode.Z then callbacks.Undo(); return end
			if input.KeyCode == Enum.KeyCode.Y then callbacks.Redo(); return end
			if input.KeyCode == Enum.KeyCode.D then callbacks.Duplicate(); return end
			if input.KeyCode == Enum.KeyCode.M then callbacks.Mirror(); return end
			if input.KeyCode == Enum.KeyCode.T then callbacks.TestMachine(); return end
		end

		if input.KeyCode == Enum.KeyCode.R then
			if shiftHeld() then
				callbacks.Rotate(); callbacks.Rotate(); callbacks.Rotate()
			else
				callbacks.Rotate()
			end
			return
		end
		if input.KeyCode == Enum.KeyCode.M then callbacks.Mirror(); return end
		if input.KeyCode == Enum.KeyCode.Backspace or input.KeyCode == Enum.KeyCode.X or input.KeyCode == Enum.KeyCode.Delete then callbacks.Remove(); return end
		if input.KeyCode == Enum.KeyCode.C then callbacks.Duplicate(); return end
		if input.KeyCode == Enum.KeyCode.Z then callbacks.Undo(); return end
		if input.KeyCode == Enum.KeyCode.Y then callbacks.Redo(); return end
		if input.KeyCode == Enum.KeyCode.T then callbacks.TestMachine(); return end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then callbacks.Place(); return end
	end)

	self._wheelConnection = UserInputService.InputChanged:Connect(function(input, processed)
		if processed or not self.Active or UserInputService:GetFocusedTextBox() then return end
		if input.UserInputType ~= Enum.UserInputType.MouseWheel then return end
		local direction = input.Position.Z
		if direction == 0 then return end
		local delta = if direction > 0 then -1 else 1
		local slot = ((self.CurrentSlot - 1 + delta) % 9) + 1
		selectSlot(slot)
	end)

	return self
end

function BuildInput:SetActive(active)
	self.Active = active == true
end

function BuildInput:Destroy()
	if self._connection then self._connection:Disconnect(); self._connection = nil end
	if self._wheelConnection then self._wheelConnection:Disconnect(); self._wheelConnection = nil end
end

return BuildInput
