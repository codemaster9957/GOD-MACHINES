--!strict
-- Keyboard/mouse is one adapter over abstract actions; controller/mobile can dispatch the same packets.

local Players = game:GetService("Players")
local ContextActionService = game:GetService("ContextActionService")

local player = Players.LocalPlayer
local remote = game.ReplicatedStorage.MechFramework.Remotes.Events.RequestControlAction

local sequence = 0
local held: {[string]: boolean} = {}

local bindings = {
	Primary = { Enum.UserInputType.MouseButton1 },
	Secondary = { Enum.UserInputType.MouseButton2 },
	UtilityQ = { Enum.KeyCode.Q },
	UtilityE = { Enum.KeyCode.E },
	Reload = { Enum.KeyCode.R },
	Mechanism1 = { Enum.KeyCode.One },
	Mechanism2 = { Enum.KeyCode.Two },
}

local function aimPacket(): {[string]: any}
	local mouse = player:GetMouse()
	local camera = workspace.CurrentCamera
	local origin = if camera then camera.CFrame.Position else mouse.UnitRay.Origin
	local offset = mouse.Hit.Position - origin
	local direction: Vector3
	if offset.Magnitude > 0.001 then
		direction = offset.Unit
	elseif camera then
		direction = camera.CFrame.LookVector
	else
		direction = mouse.UnitRay.Direction
	end
	return {
		Origin = origin,
		Direction = direction,
	}
end

local function dispatch(action: string, active: boolean)
	local mechId = player:GetAttribute("ActiveMechId")
	if type(mechId) ~= "string" or mechId == "" then
		return
	end

	sequence += 1
	remote:FireServer({
		MechId = mechId,
		Action = action,
		Active = active,
		Sequence = sequence,
		Aim = aimPacket(),
	})
end

local function releaseHeldActions()
	for action in held do
		dispatch(action, false)
		held[action] = nil
	end
end

player:GetAttributeChangedSignal("BuildMode"):Connect(function()
	if player:GetAttribute("BuildMode") == true then
		releaseHeldActions()
	end
end)

for action, inputs in bindings do
	ContextActionService:BindAction(
		"Mech_" .. action,
		function(_, state)
			-- Build mode owns LMB/R/1-9. Pass the input through instead of sinking it.
			if player:GetAttribute("BuildMode") == true then
				return Enum.ContextActionResult.Pass
			end

			if state == Enum.UserInputState.Begin then
				held[action] = true
				dispatch(action, true)
			elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
				held[action] = nil
				dispatch(action, false)
			end

			return Enum.ContextActionResult.Sink
		end,
		true,
		table.unpack(inputs)
	)
end
