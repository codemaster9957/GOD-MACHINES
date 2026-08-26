--!strict
-- Unified keyboard/mouse adapter with continuous server aim refresh while firing.
-- Clients submit intent + canonical target IDs; the server resolves target motion and damage.

local Players = game:GetService("Players")
local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local remote = game.ReplicatedStorage.MechFramework.Remotes.Events.RequestControlAction
assert(remote:IsA("RemoteEvent"), "[GOD MACHINES] RequestControlAction must be RemoteEvent")

local sequence = 0
local heldActions: {[string]: boolean} = {}
local heldPhysical: {[string]: {string}} = {}
local lastAimRefresh = 0
local AIM_REFRESH_RATE = 1/30

local PHYSICAL_BINDINGS = {
	{ Name="Primary", Inputs={Enum.UserInputType.MouseButton1}, Actions={"Primary"} },
	{ Name="Secondary", Inputs={Enum.UserInputType.MouseButton2}, Actions={"Secondary"} },
	{ Name="Forward", Inputs={Enum.KeyCode.W}, Actions={"ThrottleForward"} },
	{ Name="Reverse", Inputs={Enum.KeyCode.S}, Actions={"ThrottleReverse"} },
	{ Name="Left", Inputs={Enum.KeyCode.A}, Actions={"SteerLeft","RollLeft","StrafeLeft"} },
	{ Name="Right", Inputs={Enum.KeyCode.D}, Actions={"SteerRight","RollRight","StrafeRight"} },
	{ Name="BrakeRise", Inputs={Enum.KeyCode.Space}, Actions={"Brake","VerticalUp"} },
	{ Name="Descend", Inputs={Enum.KeyCode.LeftControl}, Actions={"VerticalDown"} },
	{ Name="PitchUp", Inputs={Enum.KeyCode.Up}, Actions={"PitchUp"} },
	{ Name="PitchDown", Inputs={Enum.KeyCode.Down}, Actions={"PitchDown"} },
	{ Name="YawLeft", Inputs={Enum.KeyCode.Left}, Actions={"YawLeft"} },
	{ Name="YawRight", Inputs={Enum.KeyCode.Right}, Actions={"YawRight"} },
	{ Name="Utility", Inputs={Enum.KeyCode.Q,Enum.KeyCode.E}, Actions={"Utility"} },
	{ Name="Reload", Inputs={Enum.KeyCode.R}, Actions={"Reload"} },
	{ Name="Mechanism1", Inputs={Enum.KeyCode.One}, Actions={"Mechanism1"} },
	{ Name="Mechanism2", Inputs={Enum.KeyCode.Two}, Actions={"Mechanism2"} },
}

local function targetIds(instance: Instance?): (string?,string?)
	local current=instance
	while current do
		local mechId=current:GetAttribute("MechId")
		local componentId=current:GetAttribute("ComponentId")
		if type(mechId)=="string" and type(componentId)=="string" then return mechId,componentId end
		current=current.Parent
	end
	return nil,nil
end

local function aimPacket(): {[string]: any}
	local mouse = player:GetMouse()
	local camera = workspace.CurrentCamera
	local origin = if camera then camera.CFrame.Position else mouse.UnitRay.Origin
	local offset = mouse.Hit.Position - origin
	local direction: Vector3
	if offset.Magnitude > 0.001 then direction = offset.Unit
	elseif camera then direction = camera.CFrame.LookVector
	else direction = mouse.UnitRay.Direction.Unit end
	local targetMechId,targetComponentId=targetIds(mouse.Target)
	return {
		Origin=origin,
		Direction=direction,
		TargetMechId=targetMechId,
		TargetComponentId=targetComponentId,
	}
end

local function dispatch(action: string, active: boolean)
	local mechId = player:GetAttribute("ActiveMechId")
	if type(mechId) ~= "string" or mechId == "" then return end
	sequence += 1
	remote:FireServer({ MechId=mechId, Action=action, Active=active, Sequence=sequence, Aim=aimPacket() })
end

local function setAction(action: string, active: boolean)
	if active then
		if heldActions[action] then return end
		heldActions[action] = true
		dispatch(action,true)
	else
		if not heldActions[action] then return end
		heldActions[action] = nil
		dispatch(action,false)
	end
end

local function releaseHeldActions()
	local copy = {}
	for action in pairs(heldActions) do table.insert(copy,action) end
	for _,action in ipairs(copy) do setAction(action,false) end
	table.clear(heldPhysical)
end

player:GetAttributeChangedSignal("BuildMode"):Connect(function()
	if player:GetAttribute("BuildMode") == true then releaseHeldActions() end
end)
player:GetAttributeChangedSignal("ActiveMechId"):Connect(releaseHeldActions)

for _, binding in ipairs(PHYSICAL_BINDINGS) do
	local casName = "GM_Control_" .. binding.Name
	ContextActionService:BindAction(
		casName,
		function(_, state)
			if player:GetAttribute("BuildMode") == true then return Enum.ContextActionResult.Pass end
			local mechId = player:GetAttribute("ActiveMechId")
			if type(mechId) ~= "string" or mechId == "" then return Enum.ContextActionResult.Pass end
			if state == Enum.UserInputState.Begin then
				heldPhysical[binding.Name] = binding.Actions
				for _,action in ipairs(binding.Actions) do setAction(action,true) end
			elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
				heldPhysical[binding.Name] = nil
				for _,action in ipairs(binding.Actions) do
					local stillHeld = false
					for _,actions in pairs(heldPhysical) do if table.find(actions,action) then stillHeld=true; break end end
					if not stillHeld then setAction(action,false) end
				end
			end
			return Enum.ContextActionResult.Sink
		end,
		false,
		table.unpack(binding.Inputs)
	)
end

-- Primary/secondary are special: update the held server state as the cursor moves.
-- CanFire remains authoritative, so this cannot bypass weapon fire rates.
RunService.RenderStepped:Connect(function()
	local now=os.clock()
	if now-lastAimRefresh<AIM_REFRESH_RATE then return end
	lastAimRefresh=now
	if heldActions.Primary then dispatch("Primary",true) end
	if heldActions.Secondary then dispatch("Secondary",true) end
end)

script.Destroying:Connect(function()
	releaseHeldActions()
	for _, binding in ipairs(PHYSICAL_BINDINGS) do ContextActionService:UnbindAction("GM_Control_" .. binding.Name) end
end)
