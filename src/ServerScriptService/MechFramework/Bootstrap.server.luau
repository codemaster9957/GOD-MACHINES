--!strict
-- Composition root: register every service before the two-phase lifecycle.

local root = script.Parent
local Container = require(root.ServiceContainer)
local services = root.Services
local container = Container.new()

local order = {
	"PartRegistry",
	"MechService",
	"ConnectionService",
	"PhysicsService",
	"DestructionService",
	"DamageService",
	"PowerService",
	"HeatService",
	"InventoryService",
	"SaveService",
	"ProgressionService",
	"BuildService",
	"ProjectileService",
	"CombatService",
	"ControlService",
	"MatchService",
	"AIService",
	"NetworkService",
}

for _, name in ipairs(order) do
	local module = services:WaitForChild(name)
	assert(module:IsA("ModuleScript"), `[MechFramework] {name} must be a ModuleScript`)
	print("[MechFramework] Registering", name)
	container:Register(name, require(module))
end

print("[MechFramework] Initializing services")
container:Init()
print("[MechFramework] Starting services")
container:Start()
print("[MechFramework] Startup complete")
