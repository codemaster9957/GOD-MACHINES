--!nonstrict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
if not player then
	error("[GOD MACHINES] LocalPlayer unavailable")
end

local playerGui = player:WaitForChild("PlayerGui")
local mouse = player:GetMouse()

local BuildUI = require(script.Parent:WaitForChild("BuildUI"))
local BuildPreview = require(script.Parent:WaitForChild("BuildPreview"))
local BuildInput = require(script.Parent:WaitForChild("BuildInput"))

local framework = ReplicatedStorage:WaitForChild("MechFramework")
local Shared = framework:WaitForChild("Shared")
local Remotes = framework:WaitForChild("Remotes")
local Functions = Remotes:WaitForChild("Functions")
local BuildMath = require(Shared:WaitForChild("BuildMath"))
local WeaponCatalog = require(Shared:WaitForChild("WeaponCatalog"))
local remote = Functions:WaitForChild("RequestBuildAction")

if not remote:IsA("RemoteFunction") then
	error("[GOD MACHINES] RequestBuildAction must be a RemoteFunction")
end

local PARTS = {
	{ Id = "StructuralFrame", DisplayName = "STRUCTURAL FRAME", ShortName = "FRAME", Slot = 1 },
	{ Id = "SmallReactor", DisplayName = "SMALL REACTOR", ShortName = "REACTOR", Slot = 2 },
}

for index, weapon in ipairs(WeaponCatalog.Ordered) do
	table.insert(PARTS, {
		Id = weapon.Id,
		DisplayName = weapon.DisplayName,
		ShortName = weapon.ShortName,
		Slot = if index <= 7 then index + 2 else nil,
	})
end

local buildMode = false
local selectedPart = PARTS[1].Id
local activeAttribute = player:GetAttribute("ActiveMechId")
local mechId = if type(activeAttribute) == "string" then activeAttribute else nil
local definitions = {}
local loadingDefinitions = {}
local statusLockUntil = 0
local input = nil

local ui = BuildUI.new(playerGui)
local preview = BuildPreview.new(mouse, BuildMath)

local function status(text, tone, duration)
	ui:SetStatus(text, tone)
	statusLockUntil = os.clock() + (duration or 0)
end

local function startupReason(fallback)
	local state = framework:GetAttribute("ServerBootstrapState")
	local reason = framework:GetAttribute("ServerBootstrapError")
	if type(reason) == "string" and reason ~= "" then
		return "SERVER " .. tostring(state or "ERROR") .. ": " .. reason
	end
	if type(state) == "string" and state ~= "" and state ~= "Ready" then
		return "SERVER " .. state
	end
	return fallback
end

local function waitForBuilderReady(timeoutSeconds)
	if framework:GetAttribute("BuilderServerReady") == true then
		return true, nil
	end

	local deadline = os.clock() + (timeoutSeconds or 8)
	while os.clock() < deadline do
		if framework:GetAttribute("BuilderServerReady") == true then
			return true, nil
		end

		local state = framework:GetAttribute("ServerBootstrapState")
		if state == "Degraded" then
			local reason = framework:GetAttribute("ServerBootstrapError")
			if type(reason) == "string" and reason ~= "" then
				-- A degraded optional system does not necessarily mean the builder failed.
				-- Keep waiting for the explicit builder-ready flag until the deadline.
			end
		end

		task.wait(0.05)
	end

	return false, startupReason("SERVER NOT READY")
end

local function invoke(request, timeoutSeconds)
	local ready, readyReason = waitForBuilderReady(timeoutSeconds or 8)
	if not ready then
		return false, readyReason
	end

	local finished = false
	local callOk = false
	local success = false
	local result = nil

	task.spawn(function()
		local ok, first, second = pcall(function()
			return remote:InvokeServer(request)
		end)
		callOk = ok
		success = first
		result = second
		finished = true
	end)

	local deadline = os.clock() + (timeoutSeconds or 5)
	while not finished and os.clock() < deadline do
		task.wait()
	end

	if not finished then
		return false, startupReason("REQUEST TIMEOUT")
	end

	if not callOk then
		return false, "SERVER ERROR: " .. tostring(success)
	end

	return success == true, result
end

local function loadDefinition(partType)
	local cached = definitions[partType]
	if cached then
		return cached
	end

	if loadingDefinitions[partType] then
		local deadline = os.clock() + 6
		while loadingDefinitions[partType] and os.clock() < deadline do
			task.wait()
		end
		return definitions[partType], definitions[partType] and nil or "DEFINITION UNAVAILABLE"
	end

	loadingDefinitions[partType] = true
	local success, result = invoke({
		Action = "Definition",
		PartType = partType,
	}, 8)
	loadingDefinitions[partType] = nil

	if not success then
		warn("[GOD MACHINES] Definition request failed:", partType, result)
		return nil, result
	end

	if type(result) ~= "table" or typeof(result.Size) ~= "Vector3" then
		warn("[GOD MACHINES] Invalid definition returned for", partType)
		return nil, "INVALID DEFINITION"
	end

	definitions[partType] = result
	return result, nil
end

local function selectPart(partType)
	local definition, reason = loadDefinition(partType)
	if not definition then
		status(reason or "PART UNAVAILABLE", "bad", 1.5)
		return false
	end

	if not preview:SetDefinition(definition) then
		status("INVALID PART DEFINITION", "bad", 1.2)
		return false
	end

	selectedPart = partType
	ui:SetSelectedPart(partType)
	ui:SetInspector(partType, definition)
	status("SELECTED " .. partType, "good", 0.45)
	return true
end

local function setActiveMech(value)
	mechId = if type(value) == "string" and value ~= "" then value else nil
	player:SetAttribute("ActiveMechId", mechId)
end

local function setBuildMode(enabled)
	buildMode = enabled == true
	player:SetAttribute("BuildMode", buildMode)
	ui:SetBuildMode(buildMode)
	preview:SetEnabled(buildMode)
	if input then
		input:SetActive(buildMode)
	end

	if buildMode then
		local ok = selectPart(selectedPart)
		if ok then
			status("BUILD MODE ONLINE", "good", 0.7)
		end
	else
		statusLockUntil = 0
	end
end

local function toggleBuildMode()
	setBuildMode(not buildMode)
end

local function placePart()
	if not buildMode then
		return
	end

	preview:Update(mechId)
	local data, previewReason = preview:GetPlacement(mechId)
	if not data then
		preview:Reject()
		local readable = {
			ATTACHMENT_REQUIRED = "ATTACH TO YOUR MECH",
			OTHER_MECH = "THAT IS NOT YOUR ACTIVE MECH",
			NO_COMPATIBLE_NODE = "NO COMPATIBLE ATTACHMENT",
			START_ON_GROUND = "START A NEW MECH ON OPEN GROUND",
		}
		status(readable[previewReason] or previewReason or "INVALID PLACEMENT", "bad", 0.9)
		return
	end

	local success, result = invoke({
		Action = "Place",
		MechId = mechId,
		PartType = selectedPart,
		Transform = data.Transform,
		TargetComponentId = data.TargetComponentId,
		TargetNode = data.TargetNode,
		SourceNode = data.SourceNode,
		Rotation = data.Rotation,
	}, 8)

	if success then
		if type(result) == "table" and type(result.MechId) == "string" then
			setActiveMech(result.MechId)
		end
		status("COMPONENT INSTALLED", "good", 0.65)
		return
	end

	preview:Reject()
	status(tostring(result or "PLACEMENT REJECTED"), "bad", 1.5)
end

local function removePart()
	if not buildMode then
		return
	end

	local target = mouse.Target
	if not target then
		status("NO COMPONENT SELECTED", "bad", 0.7)
		return
	end

	local targetMech = target:GetAttribute("MechId")
	local component = target:GetAttribute("ComponentId")
	if type(targetMech) ~= "string" or type(component) ~= "string" then
		status("NO COMPONENT SELECTED", "bad", 0.7)
		return
	end

	if type(mechId) ~= "string" or targetMech ~= mechId then
		status("THAT IS NOT YOUR ACTIVE MECH", "bad", 0.8)
		return
	end

	local success, result = invoke({
		Action = "Remove",
		MechId = targetMech,
		ComponentId = component,
	}, 8)

	if success then
		status("COMPONENT REMOVED", "good", 0.6)
	else
		status(tostring(result or "REMOVE REJECTED"), "bad", 1.2)
	end
end

local function applyHistory(action)
	local success, result = invoke({ Action = action }, 8)
	if success then
		if type(result) == "table" and type(result.MechId) == "string" then
			setActiveMech(result.MechId)
		end
		status(action, "good", 0.5)
	else
		status(tostring(result or "NOTHING TO APPLY"), "bad", 0.8)
	end
end

local function rotate()
	if not buildMode then
		return
	end
	preview:Rotate()
	preview:Update(mechId)
	status("ROTATED 90°", nil, 0.25)
end

local function selectSlot(slot)
	local part = PARTS[slot]
	if part then
		selectPart(part.Id)
	end
end

ui:SetParts(PARTS, selectPart)

input = BuildInput.new(UserInputService, {
	Toggle = toggleBuildMode,
	Rotate = rotate,
	Place = placePart,
	Remove = removePart,
	Undo = function()
		applyHistory("Undo")
	end,
	Redo = function()
		applyHistory("Redo")
	end,
	SelectSlot = selectSlot,
})

player:SetAttribute("BuildMode", false)
ui:SetBuildMode(false)
preview:SetEnabled(false)

task.spawn(function()
	local ready, reason = waitForBuilderReady(10)
	if ready then
		selectPart(selectedPart)
	else
		warn("[GOD MACHINES] Builder server unavailable:", reason)
		status(reason or "SERVER NOT READY", "bad", 2)
	end
end)

local renderConnection = RunService.RenderStepped:Connect(function()
	if not buildMode then
		return
	end

	local state = preview:Update(mechId)
	if os.clock() < statusLockUntil then
		return
	end

	if state == "SNAP" then
		ui:SetStatus("ATTACHMENT READY", "good")
	elseif state == "FREE" then
		ui:SetStatus("FREE PLACEMENT", nil)
	elseif state == "ATTACHMENT_REQUIRED" then
		ui:SetStatus("ATTACH TO YOUR MECH", "bad")
	elseif state == "OTHER_MECH" then
		ui:SetStatus("OTHER MECH", "bad")
	elseif state == "NO_COMPATIBLE_NODE" then
		ui:SetStatus("NO COMPATIBLE NODE", "bad")
	elseif state == "START_ON_GROUND" then
		ui:SetStatus("START ON OPEN GROUND", "bad")
	elseif state == "REJECTED" then
		ui:SetStatus("PLACEMENT REJECTED", "bad")
	end
end)

script.Destroying:Connect(function()
	player:SetAttribute("BuildMode", false)
	if input then
		input:Destroy()
	end
	preview:Destroy()
	if renderConnection then
		renderConnection:Disconnect()
	end
end)

print("[GOD MACHINES] Builder initialized")
