--!nonstrict
-- Build-mode input adapter. Machine driving owns these keys only outside construction mode.

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

function BuildInput.new(UserInputService, callbacks)
	local self = setmetatable({}, BuildInput)
	self.Active = false
	self._connection = UserInputService.InputBegan:Connect(function(input, processed)
		if processed then return end

		-- B always enters/leaves the workshop, including returning from Test Mode.
		if input.KeyCode == Enum.KeyCode.B then
			callbacks.Toggle()
			return
		end
		if not self.Active then return end

		local slot = NUMBER_KEYS[input.KeyCode]
		if slot then callbacks.SelectSlot(slot); return end
		if input.KeyCode == Enum.KeyCode.R then callbacks.Rotate(); return end
		if input.KeyCode == Enum.KeyCode.M then callbacks.Mirror(); return end
		if input.KeyCode == Enum.KeyCode.X or input.KeyCode == Enum.KeyCode.Delete then callbacks.Remove(); return end
		if input.KeyCode == Enum.KeyCode.C then callbacks.Duplicate(); return end
		if input.KeyCode == Enum.KeyCode.Z then callbacks.Undo(); return end
		if input.KeyCode == Enum.KeyCode.Y then callbacks.Redo(); return end
		if input.KeyCode == Enum.KeyCode.T then callbacks.TestMachine(); return end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then callbacks.Place(); return end
	end)
	return self
end

function BuildInput:SetActive(active)
	self.Active = active == true
end

function BuildInput:Destroy()
	if self._connection then self._connection:Disconnect(); self._connection = nil end
end

return BuildInput
