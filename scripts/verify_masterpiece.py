#!/usr/bin/env python3
"""Repository-level invariants for GOD MACHINES Masterpiece Builder V2.

This deliberately avoids Roblox runtime assumptions. It catches structural regressions,
stale three-part architecture, remote ownership conflicts, catalog drift, profile/save
wiring mistakes, and client/server API mismatches before a Studio smoke test.
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ERRORS: list[str] = []
CHECKS = 0


def check(condition: bool, message: str) -> None:
    global CHECKS
    CHECKS += 1
    if not condition:
        ERRORS.append(message)


def text(path: str) -> str:
    target = ROOT / path
    check(target.is_file(), f"missing required file: {path}")
    if not target.is_file():
        return ""
    return target.read_text(encoding="utf-8")


def strip_luau_comments(source: str) -> str:
    source = re.sub(r"--\[\[.*?\]\]", "", source, flags=re.S)
    return re.sub(r"--[^\n]*", "", source)


PART_DIR = ROOT / "src/ReplicatedStorage/MechFramework/Shared/PartDefinitions"
EXPECTED_CATEGORIES = {
    "Structural.luau",
    "Armour.luau",
    "Mobility.luau",
    "Propulsion.luau",
    "Aerodynamics.luau",
    "PowerCooling.luau",
    "Control.luau",
    "Weapons.luau",
    "Utility.luau",
}

# Rojo safety: the authored world is intentionally Studio-owned.
project_path = ROOT / "default.project.json"
check(project_path.is_file(), "default.project.json is missing")
if project_path.is_file():
    try:
        project = json.loads(project_path.read_text(encoding="utf-8"))
        tree = project.get("tree", {})
        check("Workspace" not in tree, "Workspace must remain excluded from Rojo mapping")
        for service in ("ReplicatedStorage", "ServerScriptService", "ServerStorage", "StarterGui", "StarterPlayer"):
            check(service in tree, f"Rojo mapping lost required service: {service}")
    except Exception as exc:
        ERRORS.append(f"default.project.json could not be parsed: {exc}")

# Catalog source: exactly nine category modules and exactly 100 unique H.part definitions.
check(PART_DIR.is_dir(), "PartDefinitions directory is missing")
part_ids: list[str] = []
if PART_DIR.is_dir():
    module_names = {p.name for p in PART_DIR.glob("*.luau")}
    check(module_names == EXPECTED_CATEGORIES, f"PartDefinitions modules differ from expected set: {sorted(module_names)}")
    for filename in sorted(EXPECTED_CATEGORIES):
        source = strip_luau_comments((PART_DIR / filename).read_text(encoding="utf-8"))
        ids = re.findall(r'\bH\.part\s*\(\s*["\']([^"\']+)["\']', source)
        check(len(ids) > 0, f"{filename} contains no H.part definitions")
        part_ids.extend(ids)
check(len(part_ids) == 100, f"expected exactly 100 H.part definitions, found {len(part_ids)}")
check(len(set(part_ids)) == len(part_ids), "duplicate part IDs exist in category definitions")
for canonical in ("StructuralFrame", "SmallReactor", "Autocannon"):
    check(canonical in set(part_ids), f"canonical legacy part missing from 100-part catalog: {canonical}")

catalog = text("src/ReplicatedStorage/MechFramework/Shared/PartCatalog.luau")
helpers = text("src/ReplicatedStorage/MechFramework/Shared/PartDefinitionHelpers.luau")
renderer = text("src/ReplicatedStorage/MechFramework/Shared/PartRenderer.luau")
preview = text("src/StarterPlayer/StarterPlayerScripts/GodMachinesBuilder/BuildPreview.luau")
ui = text("src/StarterPlayer/StarterPlayerScripts/GodMachinesBuilder/BuildUI.luau")
controller = text("src/StarterPlayer/StarterPlayerScripts/GodMachinesBuilder/BuildController.client.luau")
weapon_client = text("src/StarterPlayer/StarterPlayerScripts/WeaponController.client.luau")

check("#ordered == 100" in catalog and "Catalog.Validate" in catalog, "PartCatalog lost exact-count/runtime validation")
check("VALID_GEOMETRY_KINDS" in catalog and "WeaponDefinitions" in catalog, "PartCatalog lost geometry/weapon validation")
check("function H.part" in helpers and "VALID_CATEGORIES" in helpers, "part constructor normalization is missing")
check("function Renderer.Render" in renderer and "BuildMath.AttachmentNodes" in renderer, "shared renderer is not using canonical nodes")
check("PartRenderer.Render" in preview and "function BuildPreview:SetMirror" in preview, "preview is not on shared renderer/true mirror path")
check("PartCatalog.GetList()" in controller and "assert(#catalog == 100" in controller, "client is not driven by the 100-part catalog")
check("local PARTS" not in controller, "old hardcoded client PARTS table returned")
check("SetInventoryCounts" in ui and 'Action="Inventory"' in controller, "live buildable inventory UI is not wired")

# Required services and remotes.
service_root = ROOT / "src/ServerScriptService/MechFramework/Services"
required_services = {
    "PartRegistry.luau", "MechService.luau", "ConnectionService.luau", "PhysicsService.luau",
    "InventoryService.luau", "BuildService.luau", "FuelService.luau", "PowerService.luau",
    "HeatService.luau", "SaveService.luau", "ProgressionService.luau", "ProjectileService.luau",
    "CombatService.luau", "ControlService.luau", "PilotService.luau", "VehicleService.luau",
    "PropulsionService.luau", "AerodynamicsService.luau", "DestructionService.luau",
    "MatchService.luau", "AIService.luau", "NetworkService.luau",
}
for filename in sorted(required_services):
    check((service_root / filename).is_file(), f"required service missing: {filename}")
check((ROOT / "src/ReplicatedStorage/MechFramework/Remotes/Functions/RequestMachineAction.model.json").is_file(), "RequestMachineAction remote model missing")

bootstrap = text("src/ServerScriptService/MechFramework/Bootstrap.server.luau")
build = text("src/ServerScriptService/MechFramework/Services/BuildService.luau")
network = text("src/ServerScriptService/MechFramework/Services/NetworkService.luau")
pilot = text("src/ServerScriptService/MechFramework/Services/PilotService.luau")
inventory = text("src/ServerScriptService/MechFramework/Services/InventoryService.luau")
save = text("src/ServerScriptService/MechFramework/Services/SaveService.luau")
control = text("src/ServerScriptService/MechFramework/Services/ControlService.luau")
power = text("src/ServerScriptService/MechFramework/Services/PowerService.luau")
fuel = text("src/ServerScriptService/MechFramework/Services/FuelService.luau")

for service in ("FuelService", "PowerService", "HeatService", "ControlService", "PilotService", "VehicleService", "PropulsionService", "AerodynamicsService"):
    check(f'"{service}"' in bootstrap, f"bootstrap does not register required machine service: {service}")
check('framework:SetAttribute("BuilderServerReady", true)' in bootstrap, "builder readiness boundary missing")
check('framework:SetAttribute("MachineServerReady", machineHealthy)' in bootstrap, "machine readiness health gate missing")
check("buildRemote.OnServerInvoke" in bootstrap, "bootstrap lost RequestBuildAction startup fallback")
check("machineRemote.OnServerInvoke" in bootstrap, "bootstrap lost RequestMachineAction startup fallback")
check("remote.OnServerInvoke" in build and "RequestBuildAction" in build, "BuildService no longer owns build mutations")
check("self._remote.OnServerInvoke" in pilot and "RequestMachineAction" in pilot, "PilotService no longer owns machine actions")
check("RequestBuildAction" not in strip_luau_comments(network), "NetworkService regained a RequestBuildAction path")

# Builder economy, blueprint security, and save/profile safety.
for token in ("GetBuildableCount", "ConsumeOne", "RestorePartReceipt", "ReturnBuiltPart", "MAX_APPLIED_TRANSACTIONS"):
    check(token in inventory, f"inventory hardening missing: {token}")
for token in ("ConsumeInventory", "_reserveBlueprintInventory", "InventoryReceipt", "BlueprintSourceId", "PrimaryComponentId"):
    check(token in build, f"BuildService blueprint/economy invariant missing: {token}")
check("ConsumeInventory=true" in pilot, "workshop blueprint spawning no longer consumes inventory")
check("PrimaryComponentId" in pilot, "blueprint save lost deterministic primary component")
check("BlueprintSourceId" in control, "saved control bindings cannot remap blueprint component IDs")
check("GMProfileReady" in save and "function Save:IsReady" in save, "per-player save readiness is missing")
check("ProfileLoading" in pilot and "_profileReady" in pilot, "blueprint actions are not gated on profile readiness")
check('GetAttributeChangedSignal("GMProfileReady")' in controller, "client does not refresh after profile load")
check("TYPE_KEY" in save and "CFrame" in save and "Color3" in save, "DataStore-safe blueprint serialization missing")
check("wrote=false" in save and "UpdateAsync" in save, "save write-ownership verification missing")

# Core engineering resource and control expectations.
for action in ("StrafeLeft", "StrafeRight", "ThrottleForward", "ThrottleReverse", "PitchUp", "PitchDown", "YawLeft", "YawRight", "RollLeft", "RollRight"):
    check(action in control, f"server control action missing: {action}")
    check(action in ui or action in weapon_client, f"no client surface/input for control action: {action}")
check("ConsumeEnergy" in power, "stored-energy burst consumption missing")
check("self._fuel:Consume" in power, "fuel generators are not consuming shared fuel")
check("function Fuel:Consume" in fuel and "function Fuel:GetState" in fuel, "canonical fuel ledger incomplete")

# UI callback references should have a matching controller assignment.
ui_callbacks = set(re.findall(r"self\.Callbacks\.([A-Za-z0-9_]+)", ui))
controller_callbacks = set(re.findall(r"ui\.Callbacks\.([A-Za-z0-9_]+)\s*=", controller))
missing_callbacks = sorted(ui_callbacks - controller_callbacks)
check(not missing_callbacks, f"BuildUI callbacks missing controller assignments: {missing_callbacks}")

# Catch accidental pasted/truncated tool output in source files.
for path in ROOT.rglob("*.luau"):
    source = path.read_text(encoding="utf-8")
    check("<truncated>" not in source and "Response output was truncated" not in source, f"tool truncation marker leaked into {path.relative_to(ROOT)}")

if ERRORS:
    print(f"MASTERPIECE VERIFICATION FAILED: {len(ERRORS)} error(s) across {CHECKS} checks")
    for error in ERRORS:
        print(f"  - {error}")
    sys.exit(1)

print(f"MASTERPIECE VERIFICATION PASSED: {CHECKS} checks")
print(f"Catalog definitions: {len(part_ids)} unique parts across {len(EXPECTED_CATEGORIES)} categories")
