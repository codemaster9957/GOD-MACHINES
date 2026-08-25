--!nonstrict

local BuildInput = {}
BuildInput.__index = BuildInput

function BuildInput.new(
	UserInputService,
	callbacks
)
	local self =
		setmetatable(
			{},
			BuildInput
		)

	self.Active = false

	UserInputService.InputBegan:Connect(
		function(input, processed)

			--------------------------------------------------
			-- BUILD TOGGLE ALWAYS WORKS
			--------------------------------------------------

			if input.KeyCode == Enum.KeyCode.B then
				callbacks.Toggle()
				return
			end

			if processed then
				return
			end

			if not self.Active then
				return
			end

			--------------------------------------------------
			-- HOTBAR
			--------------------------------------------------

			if input.KeyCode == Enum.KeyCode.One then
				callbacks.SelectSlot(1)
				return
			end

			if input.KeyCode == Enum.KeyCode.Two then
				callbacks.SelectSlot(2)
				return
			end

			if input.KeyCode == Enum.KeyCode.Three then
				callbacks.SelectSlot(3)
				return
			end

			--------------------------------------------------
			-- ROTATE
			--------------------------------------------------

			if input.KeyCode == Enum.KeyCode.R then
				callbacks.Rotate()
				return
			end

			--------------------------------------------------
			-- DELETE
			--------------------------------------------------

			if input.KeyCode == Enum.KeyCode.X then
				callbacks.Remove()
				return
			end

			--------------------------------------------------
			-- UNDO
			--------------------------------------------------

			if input.KeyCode == Enum.KeyCode.Z then
				callbacks.Undo()
				return
			end

			--------------------------------------------------
			-- REDO
			--------------------------------------------------

			if input.KeyCode == Enum.KeyCode.Y then
				callbacks.Redo()
				return
			end

			--------------------------------------------------
			-- PLACE
			--------------------------------------------------

			if
				input.UserInputType
				== Enum.UserInputType.MouseButton1
			then
				callbacks.Place()
			end
		end
	)

	return self
end

function BuildInput:SetActive(active)
	self.Active = active
end

return BuildInput