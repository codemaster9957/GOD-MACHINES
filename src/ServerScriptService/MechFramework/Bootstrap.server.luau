--!strict
-- Resilient composition root. Construction comes online first; optional simulation can degrade independently.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local root = script.Parent
local Container = require(root.ServiceContainer)
local services = root.Services
local framework = ReplicatedStorage:WaitForChild("MechFramework")
local remotes = framework:WaitForChild("Remotes")
local functions = remotes:WaitForChild("Functions")
local buildRemote = functions:WaitForChild("RequestBuildAction")
local machineRemote = functions:WaitForChild("RequestMachineAction")

assert(buildRemote:IsA("RemoteFunction"), "[MechFramework] RequestBuildAction must be a RemoteFunction")
assert(machineRemote:IsA("RemoteFunction"), "[MechFramework] RequestMachineAction must be a RemoteFunction")

framework:SetAttribute("ServerBootstrapState", "Starting")
framework:SetAttribute("ServerBootstrapError", "")
framework:SetAttribute("BuilderServerReady", false)
framework:SetAttribute("MachineServerReady", false)

buildRemote.OnServerInvoke = function() return false, "ServerStarting" end
machineRemote.OnServerInvoke = function() return false, "MachineServerStarting" end

local container = Container.new()
local loaded: {[string]: any} = {}
local initialized: {[string]: boolean} = {}
local started: {[string]: boolean} = {}

local CORE_ORDER = {
	"PartRegistry",
	"MechService",
	"ConnectionService",
	"PhysicsService",
	"InventoryService",
	"BuildService",
}

local OPTIONAL_ORDER = {
	"DestructionService",
	"DamageService",
	"FuelService",
	"PowerService",
	"HeatService",
	"SaveService",
	"ProgressionService",
	"ProjectileService",
	"CombatService",
	"ControlService",
	"PilotService",
	"VehicleService",
	"PropulsionService",
	"AerodynamicsService",
	"MatchService",
	"TradeService",
	"AIService",
	"NetworkService",
	"PolishService",
}

-- Test/battle machine mode is only advertised when every engineering layer that directly
-- affects movement and survivability is healthy. The core builder can still operate alone.
local MACHINE_REQUIRED = {
	"FuelService",
	"PowerService",
	"HeatService",
	"ControlService",
	"PilotService",
	"VehicleService",
	"PropulsionService",
	"AerodynamicsService",
}

local function recordFailure(stage: string, name: string, reason: any)
	local message = string.format("%s %s: %s", stage, name, tostring(reason))
	warn("[MechFramework] " .. message)
	framework:SetAttribute("ServerBootstrapState", "Degraded")
	framework:SetAttribute("ServerBootstrapError", message)
end

local function requireService(name: string, required: boolean): boolean
	local module = services:FindFirstChild(name)
	if not module or not module:IsA("ModuleScript") then
		local reason = "missing ModuleScript"
		if required then error(string.format("[MechFramework] CORE REQUIRE %s: %s", name, reason)) end
		recordFailure("REQUIRE", name, reason)
		return false
	end
	local ok, service = pcall(require, module)
	if not ok then
		if required then error(string.format("[MechFramework] CORE REQUIRE %s: %s", name, tostring(service))) end
		recordFailure("REQUIRE", name, service)
		return false
	end
	loaded[name] = service
	container:Register(name, service)
	print("[MechFramework] Registered", name)
	return true
end

for _, name in CORE_ORDER do requireService(name, true) end
for _, name in OPTIONAL_ORDER do requireService(name, false) end

local function initService(name: string, required: boolean): boolean
	local service = loaded[name]
	if not service then return false end
	print("[MechFramework] Init", name)
	local ok, reason = pcall(function() if service.Init then service:Init(container) end end)
	if not ok then
		if required then error(string.format("[MechFramework] CORE INIT %s: %s", name, tostring(reason))) end
		recordFailure("INIT", name, reason)
		return false
	end
	initialized[name] = true
	return true
end

local function startService(name: string, required: boolean): boolean
	local service = loaded[name]
	if not service or not initialized[name] then return false end
	print("[MechFramework] Start", name)
	local ok, reason = pcall(function() if service.Start then service:Start() end end)
	if not ok then
		if required then error(string.format("[MechFramework] CORE START %s: %s", name, tostring(reason))) end
		recordFailure("START", name, reason)
		return false
	end
	started[name] = true
	return true
end

for _, name in CORE_ORDER do initService(name, true) end
for _, name in CORE_ORDER do startService(name, true) end
framework:SetAttribute("BuilderServerReady", true)
print("[MechFramework] Core builder stack ready")

for _, name in OPTIONAL_ORDER do initService(name, false) end
for _, name in OPTIONAL_ORDER do startService(name, false) end

local machineHealthy = true
local missing = {}
for _, name in ipairs(MACHINE_REQUIRED) do
	if not started[name] then machineHealthy = false; table.insert(missing, name) end
end
framework:SetAttribute("MachineServerReady", machineHealthy)
if machineHealthy then
	print("[MechFramework] Machine simulation stack ready")
else
	local message = "Required machine services unavailable: " .. table.concat(missing, ", ")
	warn("[MechFramework] " .. message)
	framework:SetAttribute("ServerBootstrapState", "Degraded")
	if framework:GetAttribute("ServerBootstrapError") == "" then framework:SetAttribute("ServerBootstrapError", message) end
end

if framework:GetAttribute("ServerBootstrapState") ~= "Degraded" then framework:SetAttribute("ServerBootstrapState", "Ready") end
print("[MechFramework] Startup complete", framework:GetAttribute("ServerBootstrapState"))
