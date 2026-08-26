--!nonstrict
-- GOD MACHINES Workshop V3 client orchestration. Server remains authoritative for every mutation.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
if not player then error("[GOD MACHINES] LocalPlayer unavailable") end
local playerGui = player:WaitForChild("PlayerGui")
local mouse = player:GetMouse()

local BuildUI = require(script.Parent:WaitForChild("BuildUI"))
local BuildPreview = require(script.Parent:WaitForChild("BuildPreview"))
local BuildInput = require(script.Parent:WaitForChild("BuildInput"))
local NodeVisualizer = require(script.Parent:WaitForChild("NodeVisualizer"))
local WorkshopCamera = require(script.Parent:WaitForChild("WorkshopCamera"))
local WorkshopCameraBar = require(script.Parent:WaitForChild("WorkshopCameraBar"))

local framework = ReplicatedStorage:WaitForChild("MechFramework")
local Shared = framework:WaitForChild("Shared")
local Remotes = framework:WaitForChild("Remotes")
local Functions = Remotes:WaitForChild("Functions")
local BuildMath = require(Shared:WaitForChild("BuildMath"))
local PartCatalog = require(Shared:WaitForChild("PartCatalog"))
local buildRemote = Functions:WaitForChild("RequestBuildAction")
local machineRemote = Functions:WaitForChild("RequestMachineAction")

assert(buildRemote:IsA("RemoteFunction"), "RequestBuildAction must be RemoteFunction")
assert(machineRemote:IsA("RemoteFunction"), "RequestMachineAction must be RemoteFunction")

local catalog = PartCatalog.GetList()
local definitions = PartCatalog.GetAll()
local categories = PartCatalog.GetCategories()
assert(#catalog >= 100, "[GOD MACHINES] Expected at least 100 public catalog parts")

local buildMode = false
local machineMode = "Edit"
local selectedPart = definitions.StructuralFrame and "StructuralFrame" or catalog[1].Id
local activeAttribute = player:GetAttribute("ActiveMechId")
local mechId = if type(activeAttribute) == "string" and activeAttribute ~= "" then activeAttribute else nil
local statusLockUntil = 0
local lastSummaryAt = 0
local summaryBusy = false
local inventoryBusy = false
local input = nil
local currentBindings = {}
local duplicateSourceId = nil

local ui = BuildUI.new(playerGui, {})
local preview = BuildPreview.new(mouse, BuildMath)
local nodes = NodeVisualizer.new()
local workshopCamera = WorkshopCamera.new(UserInputService, RunService)
local cameraCallbacks = {}
local cameraBar = WorkshopCameraBar.new(ui.Root, cameraCallbacks)

local function status(text, tone, duration)
	ui:SetStatus(text, tone)
	statusLockUntil = os.clock() + (duration or 0)
end

local function startupReason(fallback)
	local state = framework:GetAttribute("ServerBootstrapState")
	local reason = framework:GetAttribute("ServerBootstrapError")
	if type(reason) == "string" and reason ~= "" then return "SERVER " .. tostring(state or "ERROR") .. ": " .. reason end
	if type(state) == "string" and state ~= "" and state ~= "Ready" and state ~= "Degraded" then return "SERVER " .. state end
	return fallback
end

local function profileReady()
	return player:GetAttribute("GMProfileReady") == true
end

local function waitForReady(attributeName, timeoutSeconds)
	if framework:GetAttribute(attributeName) == true then return true, nil end
	local deadline = os.clock() + (timeoutSeconds or 8)
	while os.clock() < deadline do
		if framework:GetAttribute(attributeName) == true then return true, nil end
		task.wait(0.05)
	end
	return false, startupReason("SERVER NOT READY")
end

local function invokeRemote(remote, readyAttribute, request, timeoutSeconds)
	local ready, readyReason = waitForReady(readyAttribute, timeoutSeconds or 8)
	if not ready then return false, readyReason end
	local finished, callOk, first, second = false, false, nil, nil
	task.spawn(function()
		callOk, first, second = pcall(function() return remote:InvokeServer(request) end)
		finished = true
	end)
	local deadline = os.clock() + (timeoutSeconds or 7)
	while not finished and os.clock() < deadline do task.wait() end
	if not finished then return false, startupReason("REQUEST TIMEOUT") end
	if not callOk then return false, "SERVER ERROR: " .. tostring(first) end
	return first == true, second
end

local function buildInvoke(request, timeoutSeconds)
	return invokeRemote(buildRemote, "BuilderServerReady", request, timeoutSeconds)
end

local function machineInvoke(request, timeoutSeconds)
	return invokeRemote(machineRemote, "MachineServerReady", request, timeoutSeconds)
end

local function refreshInventory(silent)
	if inventoryBusy then return false end
	inventoryBusy=true
	local success,result=buildInvoke({Action="Inventory"},4)
	inventoryBusy=false
	if success and type(result)=="table" then
		ui:SetInventoryCounts(result)
		local definition=definitions[selectedPart]
		if definition then ui:SetInspector(selectedPart,definition) end
		return true
	end
	if not silent then status(result or "INVENTORY REFRESH FAILED","bad",.8) end
	return false
end

local function normalizeMechId(value)
	return if type(value) == "string" and value ~= "" then value else nil
end

local function setActiveMech(value, fromAttribute)
	local normalized = normalizeMechId(value)
	if normalized ~= mechId then duplicateSourceId = nil end
	mechId = normalized
	if fromAttribute ~= true and player:GetAttribute("ActiveMechId") ~= normalized then
		player:SetAttribute("ActiveMechId", normalized)
	end
	nodes:SetMech(normalized)
	workshopCamera:SetMech(normalized)
	if not normalized then
		ui:SetEngineeringSummary(nil)
		currentBindings = {}
	end
end

local function componentFromTarget()
	local target = mouse.Target
	if not target then return nil, nil, nil end
	local current = target
	while current and current ~= workspace do
		local componentId = current:GetAttribute("ComponentId")
		local targetMechId = current:GetAttribute("MechId")
		local partType = current:GetAttribute("PartType")
		if type(componentId) == "string" and type(targetMechId) == "string" then
			return targetMechId, componentId, if type(partType) == "string" then partType else nil
		end
		current = current.Parent
	end
	return nil, nil, nil
end

local function selectPart(partType, preserveDuplicate)
	local definition = definitions[partType]
	if not definition then status("PART UNAVAILABLE: " .. tostring(partType), "bad", 1.4); return false end
	if preserveDuplicate ~= true then duplicateSourceId = nil end
	if not preview:SetDefinition(definition) then status("INVALID PART DEFINITION", "bad", 1.2); return false end
	selectedPart = partType
	ui:SetSelectedPart(partType)
	ui:SetInspector(partType, definition)
	ui:SetMirrorState(false)
	status("SELECTED " .. tostring(definition.DisplayName or partType), "good", 0.35)
	return true
end

local function setBuildVisible(enabled, cameraReason)
	buildMode = enabled == true
	player:SetAttribute("BuildMode", buildMode)
	ui:SetBuildMode(buildMode)
	preview:SetEnabled(buildMode)
	nodes:SetEnabled(buildMode and ui.NodeVisible)
	cameraBar:SetVisible(buildMode)
	if input then input:SetActive(buildMode) end
	if buildMode then
		workshopCamera:Activate(mechId)
		cameraBar:SetCameraMode(workshopCamera.FreeFly and "Fly" or "Orbit")
		nodes:SetMech(mechId)
		selectPart(selectedPart)
		task.spawn(function() refreshInventory(true) end)
	else
		workshopCamera:Deactivate(cameraReason or "Close")
		statusLockUntil = 0
	end
end

local function enterEditMode()
	if not mechId then
		machineMode = "Edit"
		ui:SetMode("Edit")
		setBuildVisible(true)
		return
	end
	local success, result = machineInvoke({ Action="SetMode", MechId=mechId, Mode="Edit" }, 8)
	if not success then status(result or "COULD NOT ENTER EDIT MODE", "bad", 1.5); return end
	machineMode = "Edit"
	ui:SetMode("Edit")
	setBuildVisible(true)
	status("MACHINE STABILIZED FOR EDITING", "good", 0.7)
end

local function testMachine()
	if framework:GetAttribute("MachineServerReady") ~= true then
		status(startupReason("MACHINE SYSTEMS NOT READY"), "bad", 1.3)
		return
	end
	if not mechId then status("BUILD A MACHINE FIRST", "bad", 1.0); return end
	if machineMode == "Test" then enterEditMode(); return end

	-- Release Scriptable camera before pilot/test authority changes.
	workshopCamera:Deactivate("Test")
	local success, result = machineInvoke({ Action="SetMode", MechId=mechId, Mode="Test" }, 8)
	if not success then
		workshopCamera:Activate(mechId)
		cameraBar:SetCameraMode(workshopCamera.FreeFly and "Fly" or "Orbit")
		status(result or "TEST MODE UNAVAILABLE", "bad", 1.5)
		return
	end
	machineMode = "Test"
	ui:SetMode("Test")
	setBuildVisible(false, "Test")
	local remote = type(result)=="table" and result.RemoteControl == true
	status(if remote then "TEST MODE — REMOTE CONTROL ACTIVE" else "TEST MODE — SIT IN A PILOT SEAT", "blue", 1.2)
end

local function toggleBuildMode()
	if machineMode == "Test" then enterEditMode(); return end
	setBuildVisible(not buildMode)
end

local function placePart()
	if not buildMode then return end
	preview:Update(mechId)
	local data, previewReason = preview:GetPlacement(mechId)
	if not data then
		preview:Reject()
		local readable = {
			ATTACHMENT_REQUIRED="ATTACH TO A GREEN NODE",
			OTHER_MECH="THAT IS NOT YOUR ACTIVE MACHINE",
			NO_COMPATIBLE_NODE="NO COMPATIBLE ATTACHMENT",
			START_ON_GROUND="START A NEW MACHINE ON OPEN GROUND",
		}
		status(readable[previewReason] or previewReason or "INVALID PLACEMENT", "bad", .8)
		return
	end
	local duplicateActive = type(duplicateSourceId)=="string"
	local request = {
		Action=if duplicateActive then "Duplicate" else "Place",
		MechId=mechId, PartType=selectedPart, Transform=data.Transform,
		TargetComponentId=data.TargetComponentId, TargetNode=data.TargetNode, SourceNode=data.SourceNode,
		Rotation=data.Rotation, MirrorX=data.MirrorX == true,
	}
	if duplicateActive then request.ComponentId=duplicateSourceId end
	local success, result = buildInvoke(request, 8)
	if success then
		if type(result)=="table" and type(result.MechId)=="string" then setActiveMech(result.MechId) end
		task.spawn(function() refreshInventory(true) end)
		if duplicateActive then
			status("DUPLICATE INSTALLED — COPY TOOL STILL ARMED", "good", .75)
		else
			status("COMPONENT INSTALLED", "good", .55)
		end
		return
	end
	preview:Reject()
	if tostring(result):find("Inventory") or tostring(result):find("Repair") then task.spawn(function() refreshInventory(true) end) end
	if duplicateActive and tostring(result)=="InvalidComponent" then
		duplicateSourceId=nil
		selectPart(selectedPart)
		status("DUPLICATE SOURCE NO LONGER EXISTS — RE-ARM COPY TOOL", "bad", 1.3)
	else
		status(tostring(result or "PLACEMENT REJECTED"), "bad", 1.2)
	end
end

local function removePart()
	if not buildMode or not mechId then return end
	local targetMech, componentId = componentFromTarget()
	if targetMech ~= mechId or not componentId then status("AIM AT ONE OF YOUR COMPONENTS", "bad", .8); return end
	local success, result = buildInvoke({ Action="Remove", MechId=mechId, ComponentId=componentId }, 8)
	if success then
		if componentId==duplicateSourceId then duplicateSourceId=nil end
		if type(result)=="table" and result.Empty==true then
			setActiveMech(nil)
			status("MACHINE CLEARED — PLACE A NEW FOUNDATION", "good", .85)
		else
			status("COMPONENT REMOVED", "good", .55)
		end
		task.spawn(function() refreshInventory(true) end)
	else
		status(result or "REMOVE REJECTED", "bad", 1)
	end
end

local function duplicateTarget()
	if not buildMode or not mechId then return end
	local targetMech, componentId, partType = componentFromTarget()
	if targetMech ~= mechId or not componentId or not partType or not definitions[partType] then
		status("AIM AT A COMPONENT TO DUPLICATE", "bad", .8)
		return
	end
	local success, appearance = buildInvoke({Action="Appearance",MechId=mechId,ComponentId=componentId},6)
	if not success or type(appearance)~="table" then
		status(appearance or "COULD NOT READ COMPONENT APPEARANCE", "bad", 1)
		return
	end
	local copyPart=appearance.PartType or partType
	if not selectPart(copyPart,true) then return end
	preview:SetPaint(appearance.Paint)
	local mirrored=preview:SetMirror(appearance.MirrorX==true)
	ui:SetMirrorState(mirrored)
	duplicateSourceId=componentId
	status("DUPLICATE ARMED — PLACE REPEATED COPIES", "good", 1)
end

local function paintTarget(region, color, material)
	if not buildMode or not mechId then return end
	local targetMech, componentId = componentFromTarget()
	if targetMech ~= mechId or not componentId then status("AIM AT A COMPONENT TO PAINT", "bad", .8); return end
	local success, result = buildInvoke({ Action="Paint", MechId=mechId, ComponentId=componentId, Region=region, Color=color, Material=material }, 8)
	if success then
		if componentId==duplicateSourceId and type(result)=="table" and type(result.Paint)=="table" then preview:SetPaint(result.Paint) end
		status("PAINT APPLIED", "good", .55)
	else
		status(result or "PAINT REJECTED", "bad", 1)
	end
end

local function applyHistory(action)
	local success, result = buildInvoke({ Action=action }, 8)
	if success then
		duplicateSourceId=nil
		if type(result)=="table" then
			if result.Empty==true then setActiveMech(nil)
			elseif type(result.MechId)=="string" then setActiveMech(result.MechId) end
		end
		task.spawn(function() refreshInventory(true) end)
		status(action, "good", .45)
	else
		status(result or "NOTHING TO APPLY", "bad", .65)
	end
end

local function rotate()
	if not buildMode then return end
	preview:Rotate()
	preview:Update(mechId)
	status("ROTATED 90°", nil, .2)
end

local function mirror()
	if not buildMode then return preview.MirrorX == true end
	local mirrored = preview:Mirror()
	preview:Update(mechId)
	ui:SetMirrorState(mirrored)
	status(if mirrored then "MIRROR ENABLED" else "MIRROR DISABLED", nil, .25)
	return mirrored
end

local function selectSlot(slot)
	local partId = ui:GetHotbarPart(slot)
	if partId then selectPart(partId) end
end

local function frameCamera()
	if not buildMode then return end
	workshopCamera:FrameMachine()
	status("CAMERA FRAMED TO MACHINE", nil, .3)
end

local function setOrbitCamera()
	if not buildMode then return end
	workshopCamera:SetFreeFly(false)
	cameraBar:SetCameraMode("Orbit")
	status("CAMERA ORBIT MODE", nil, .25)
end

local function toggleFreeFly()
	if not buildMode then return false end
	local enabled = workshopCamera:SetFreeFly(not workshopCamera.FreeFly)
	cameraBar:SetCameraMode(if enabled then "Fly" else "Orbit")
	status(if enabled then "CAMERA FREE-FLY" else "CAMERA ORBIT MODE", nil, .3)
	return enabled
end

local function cameraView(viewName)
	if not buildMode then return end
	local ok = workshopCamera:SetView(viewName)
	if ok then
		cameraBar:SetCameraMode("Orbit")
		status("CAMERA " .. string.upper(tostring(viewName)), nil, .25)
	end
end

local function refreshBlueprints(silent)
	if not profileReady() then
		if not silent then status("PROFILE LOADING — BLUEPRINTS WILL APPEAR AUTOMATICALLY", "blue", 1.2) end
		return false
	end
	if framework:GetAttribute("MachineServerReady") ~= true then
		if not silent then status(startupReason("BLUEPRINT SYSTEM NOT READY"), "bad", 1) end
		return false
	end
	local success, result = machineInvoke({ Action="ListBlueprints" }, 6)
	if success and type(result)=="table" then
		ui:SetBlueprints(result)
		return true
	end
	if not silent then status(result or "BLUEPRINT REFRESH FAILED", "bad", 1) end
	return false
end

local function saveBlueprint(name)
	if not profileReady() then status("PROFILE LOADING — PLEASE WAIT", "blue", 1); return end
	if not mechId then status("NO ACTIVE MACHINE", "bad", .8); return end
	name = tostring(name or ""):match("^%s*(.-)%s*$")
	if name == "" then status("ENTER A BLUEPRINT NAME", "bad", .8); return end
	local success, result = machineInvoke({ Action="SaveBlueprint", MechId=mechId, Name=name }, 8)
	if success then
		status("BLUEPRINT SAVED: " .. name, "good", 1)
		refreshBlueprints(true)
	else
		status(result or "BLUEPRINT SAVE FAILED", "bad", 1.2)
	end
end

local function loadBlueprint(name)
	if not profileReady() then status("PROFILE LOADING — PLEASE WAIT", "blue", 1); return end
	name = tostring(name or ""):match("^%s*(.-)%s*$")
	if name == "" then status("SELECT OR ENTER A BLUEPRINT NAME", "bad", .8); return end
	local success, result = machineInvoke({ Action="LoadBlueprint", Name=name }, 8)
	if not success then
		if tostring(result):find("Inventory") or tostring(result):find("Repair") then task.spawn(function() refreshInventory(true) end) end
		status(result or "BLUEPRINT LOAD FAILED", "bad", 1.2)
		return
	end
	duplicateSourceId=nil
	if type(result)=="table" and type(result.MechId)=="string" then setActiveMech(result.MechId) end
	machineMode = "Edit"
	ui:SetMode("Edit")
	setBuildVisible(true)
	task.spawn(function() refreshInventory(true) end)
	status("BLUEPRINT DEPLOYED: " .. name, "good", 1)
end

local function deleteBlueprint(name)
	if not profileReady() then status("PROFILE LOADING — PLEASE WAIT", "blue", 1); return end
	name = tostring(name or ""):match("^%s*(.-)%s*$")
	if name == "" then status("SELECT A BLUEPRINT TO DELETE", "bad", .8); return end
	local success, result = machineInvoke({ Action="DeleteBlueprint", Name=name }, 6)
	if success then
		status("BLUEPRINT DELETED: " .. name, "good", .9)
		refreshBlueprints(true)
	else
		status(result or "BLUEPRINT DELETE FAILED", "bad", 1)
	end
end

local function refreshBindings()
	if not mechId then currentBindings = {}; return false end
	local success, result = machineInvoke({ Action="GetBindings", MechId=mechId }, 6)
	if success and type(result)=="table" then currentBindings=result; return true end
	return false
end

local function autoBindings()
	if not mechId then status("NO ACTIVE MACHINE", "bad", .8); return end
	local success, result = machineInvoke({ Action="AutoBindings", MechId=mechId }, 8)
	if success and type(result)=="table" then
		currentBindings=result
		status("AUTOMATIC CONTROLS GENERATED", "good", .9)
	else
		status(result or "AUTO BIND FAILED", "bad", 1)
	end
end

local function bindTarget(action)
	if not mechId then status("NO ACTIVE MACHINE", "bad", .8); return end
	local targetMech, componentId = componentFromTarget()
	if targetMech ~= mechId or not componentId then status("AIM AT A COMPONENT TO BIND", "bad", .8); return end
	refreshBindings()
	currentBindings[action] = currentBindings[action] or {}
	local existing = table.find(currentBindings[action], componentId)
	if existing then table.remove(currentBindings[action], existing) else table.insert(currentBindings[action], componentId) end
	local success, result = machineInvoke({ Action="SetBindings", MechId=mechId, Groups=currentBindings }, 8)
	if success then status((existing and "UNBOUND " or "BOUND ") .. action, "good", .8)
	else status(result or "BINDING UPDATE FAILED", "bad", 1) end
end

local function refreshSummary()
	if summaryBusy or not buildMode or not mechId then return end
	if os.clock() - lastSummaryAt < .5 then return end
	lastSummaryAt = os.clock()
	summaryBusy = true
	task.spawn(function()
		local success, result = buildInvoke({ Action="Summary", MechId=mechId }, 4)
		if success then ui:SetEngineeringSummary(result) end
		summaryBusy = false
	end)
end

local function updateMachineReady()
	local ready = framework:GetAttribute("MachineServerReady") == true
	ui:SetMachineReady(ready)
	if ready and profileReady() then refreshBlueprints(true) end
end

ui.Callbacks.SelectPart = selectPart
ui.Callbacks.TestMachine = testMachine
ui.Callbacks.PaintTarget = paintTarget
ui.Callbacks.Mirror = mirror
ui.Callbacks.DuplicateTarget = duplicateTarget
ui.Callbacks.ToggleNodes = function(enabled) nodes:SetEnabled(enabled and buildMode) end
ui.Callbacks.RemoveTarget = removePart
ui.Callbacks.Undo = function() applyHistory("Undo") end
ui.Callbacks.Redo = function() applyHistory("Redo") end
ui.Callbacks.SaveBlueprint = saveBlueprint
ui.Callbacks.LoadBlueprint = loadBlueprint
ui.Callbacks.RefreshBlueprints = function() refreshBlueprints(false) end
ui.Callbacks.DeleteBlueprint = deleteBlueprint
ui.Callbacks.BindTarget = bindTarget
ui.Callbacks.AutoBindings = autoBindings
ui:SetCatalog(catalog, categories)
ui:SetInventoryCounts({})
ui:SetMode("Edit")
ui:SetMachineReady(false)
ui:SetMirrorState(false)
ui:SetBlueprints({})

cameraCallbacks.FrameCamera = frameCamera
cameraCallbacks.ToggleFreeFly = toggleFreeFly
cameraCallbacks.CameraView = cameraView
cameraCallbacks.SetOrbit = setOrbitCamera

input = BuildInput.new(UserInputService, {
	Toggle=toggleBuildMode, Rotate=rotate, Mirror=mirror, Place=placePart, Remove=removePart,
	Duplicate=duplicateTarget, Undo=function() applyHistory("Undo") end, Redo=function() applyHistory("Redo") end,
	SelectSlot=selectSlot, TestMachine=testMachine,
	FrameCamera=frameCamera, ToggleFreeFly=toggleFreeFly, CameraView=cameraView,
})

player:SetAttribute("BuildMode", false)
ui:SetBuildMode(false)
preview:SetEnabled(false)
nodes:SetEnabled(false)
nodes:SetMech(mechId)
workshopCamera:SetMech(mechId)
cameraBar:SetVisible(false)

player:GetAttributeChangedSignal("ActiveMechId"):Connect(function()
	local value = normalizeMechId(player:GetAttribute("ActiveMechId"))
	if value ~= mechId then setActiveMech(value, true) end
end)

player:GetAttributeChangedSignal("GMProfileReady"):Connect(function()
	if profileReady() then
		task.spawn(function() refreshInventory(true) end)
		if framework:GetAttribute("MachineServerReady") == true then task.spawn(function() refreshBlueprints(true) end) end
		if buildMode then status("PROFILE READY — WORKSHOP INVENTORY LOADED", "good", .8) end
	else
		ui:SetBlueprints({})
	end
end)

framework:GetAttributeChangedSignal("MachineServerReady"):Connect(updateMachineReady)

task.spawn(function()
	local ready, reason = waitForReady("BuilderServerReady", 10)
	if ready then
		refreshInventory(true)
		selectPart(selectedPart)
	else
		warn("[GOD MACHINES] Builder unavailable:", reason)
		status(reason or "SERVER NOT READY", "bad", 2)
	end
end)

task.spawn(function()
	local ready = waitForReady("MachineServerReady", 12)
	updateMachineReady()
	if ready and profileReady() then refreshBlueprints(true) end
end)

local renderConnection = RunService.RenderStepped:Connect(function(dt)
	if buildMode then
		workshopCamera:Update(dt)
		local state = preview:Update(mechId)
		nodes:Update()
		refreshSummary()
		if os.clock() >= statusLockUntil then
			if state=="SNAP" then ui:SetStatus(if duplicateSourceId then "COPY READY" else "ATTACHMENT READY", "good")
			elseif state=="FREE" then ui:SetStatus(if duplicateSourceId then "COPY FREE PLACEMENT" else "FREE PLACEMENT", nil)
			elseif state=="ATTACHMENT_REQUIRED" then ui:SetStatus("ATTACH TO A GREEN NODE", "bad")
			elseif state=="OTHER_MECH" then ui:SetStatus("OTHER MACHINE", "bad")
			elseif state=="NO_COMPATIBLE_NODE" then ui:SetStatus("NO COMPATIBLE NODE", "bad")
			elseif state=="START_ON_GROUND" then ui:SetStatus("START ON OPEN GROUND", "bad")
			elseif state=="REJECTED" then ui:SetStatus("PLACEMENT REJECTED", "bad") end
		end
	end
end)

script.Destroying:Connect(function()
	player:SetAttribute("BuildMode", false)
	if input then input:Destroy() end
	workshopCamera:Destroy()
	cameraBar:Destroy()
	preview:Destroy()
	nodes:Destroy()
	ui:Destroy()
	if renderConnection then renderConnection:Disconnect() end
end)

print("[GOD MACHINES] Workshop V3 initialized with", #catalog, "parts")
