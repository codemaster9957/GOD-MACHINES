--!strict
-- Studio contract tests for the data-driven GOD MACHINES weapon system.
-- These run only in Studio debug sessions and never affect live servers.

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

if not RunService:IsStudio() then
	return
end

local shared = ReplicatedStorage:WaitForChild("MechFramework"):WaitForChild("Shared")
local config = require(shared:WaitForChild("FrameworkConfig"))

if not config.Debug then
	return
end

local catalogModule = shared:FindFirstChild("WeaponCatalog")
assert(catalogModule and catalogModule:IsA("ModuleScript"), "[WeaponSystemTests] WeaponCatalog is missing")

local bindingModule = shared:FindFirstChild("ControlBindingPolicy")
assert(bindingModule and bindingModule:IsA("ModuleScript"), "[WeaponSystemTests] ControlBindingPolicy is missing")

local WeaponCatalog = require(catalogModule)
local ControlBindingPolicy = require(bindingModule)

local expectedIds = {
	"Autocannon",
	"BeamRifle",
	"BeamSaber",
	"HeadVulcan",
	"ShoulderMissilePod",
	"ChestCannon",
	"ArmGatling",
	"RailCannon",
	"PlasmaShotgun",
	"RocketFist",
	"ShoulderBeamCannon",
}

assert(#WeaponCatalog.Ordered == #expectedIds, "[WeaponSystemTests] catalogue must contain eleven weapons")

local seen: {[string]: boolean} = {}
for index, expectedId in ipairs(expectedIds) do
	local weapon = WeaponCatalog.Ordered[index]
	assert(type(weapon) == "table", `[WeaponSystemTests] missing catalogue record {index}`)
	assert(weapon.Id == expectedId, `[WeaponSystemTests] expected {expectedId} at catalogue position {index}`)
	assert(WeaponCatalog.ById[weapon.Id] == weapon, `[WeaponSystemTests] ById mismatch for {weapon.Id}`)
	assert(not seen[weapon.Id], `[WeaponSystemTests] duplicate weapon id {weapon.Id}`)
	seen[weapon.Id] = true

	assert(typeof(weapon.Size) == "Vector3" and weapon.Size.Magnitude > 0, `[WeaponSystemTests] invalid size for {weapon.Id}`)
	assert(type(weapon.Mass) == "number" and weapon.Mass > 0, `[WeaponSystemTests] invalid mass for {weapon.Id}`)
	assert(type(weapon.MaxHealth) == "number" and weapon.MaxHealth > 0, `[WeaponSystemTests] invalid health for {weapon.Id}`)
	assert(weapon.DefaultAction == "Primary" or weapon.DefaultAction == "Secondary", `[WeaponSystemTests] invalid action for {weapon.Id}`)

	local combat = weapon.Combat
	assert(type(combat) == "table", `[WeaponSystemTests] missing combat config for {weapon.Id}`)
	assert(type(combat.Damage) == "number" and combat.Damage > 0, `[WeaponSystemTests] invalid damage for {weapon.Id}`)
	assert(type(combat.FireRate) == "number" and combat.FireRate > 0, `[WeaponSystemTests] invalid fire rate for {weapon.Id}`)
	assert(type(combat.Range) == "number" and combat.Range > 0, `[WeaponSystemTests] invalid range for {weapon.Id}`)
end

local groups = ControlBindingPolicy.Derive({
	a_autocannon = {
		Destroyed = false,
		Combat = { DefaultAction = "Primary" },
	},
	b_rail = {
		Destroyed = false,
		Combat = { DefaultAction = "Secondary" },
	},
	c_destroyed = {
		Destroyed = true,
		Combat = { DefaultAction = "Primary" },
	},
	d_frame = {
		Destroyed = false,
	},
	e_invalid_action = {
		Destroyed = false,
		Combat = { DefaultAction = "UtilityQ" },
	},
})

assert(#groups.Primary == 2, "[WeaponSystemTests] Primary must contain default and invalid-action weapons")
assert(groups.Primary[1] == "a_autocannon", "[WeaponSystemTests] Primary ordering is not deterministic")
assert(groups.Primary[2] == "e_invalid_action", "[WeaponSystemTests] invalid actions must safely default to Primary")
assert(#groups.Secondary == 1 and groups.Secondary[1] == "b_rail", "[WeaponSystemTests] Secondary binding incorrect")

print("[WeaponSystemTests] catalogue and control binding contracts passed")
