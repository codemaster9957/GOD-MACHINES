#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


catalog_path = "src/ReplicatedStorage/MechFramework/Shared/WeaponCatalog.luau"
binding_path = "src/ReplicatedStorage/MechFramework/Shared/ControlBindingPolicy.luau"
effects_path = "src/StarterPlayer/StarterPlayerScripts/WeaponEffects.client.luau"
gundam_parts_path = "src/ReplicatedStorage/MechFramework/Shared/PartDefinitions/GundamWeapons.luau"

for path in (catalog_path, binding_path, effects_path, gundam_parts_path):
    assert (ROOT / path).is_file(), f"missing required Gundam weapon-system file: {path}"

catalog = read(catalog_path)
expected_ids = (
    "Autocannon", "BeamRifle", "BeamSaber", "HeadVulcan",
    "ShoulderMissilePod", "ChestCannon", "ArmGatling", "RailCannon",
    "PlasmaShotgun", "RocketFist", "ShoulderBeamCannon",
)
for weapon_id in expected_ids:
    assert f'Id="{weapon_id}"' in catalog or f'Id = "{weapon_id}"' in catalog, f"catalog missing {weapon_id}"

binding = read(binding_path)
assert "function Policy.Derive" in binding or "function ControlBindingPolicy.Derive" in binding, "binding policy must derive default weapon groups"
assert '"Primary"' in binding and '"Secondary"' in binding, "binding policy must support both fire groups"

gundam_parts = read(gundam_parts_path)
assert "WeaponCatalog" in gundam_parts and "H.part" in gundam_parts, "Gundam weapon records must adapt into the current declarative part library"

part_catalog = read("src/ReplicatedStorage/MechFramework/Shared/PartCatalog.luau")
assert '"GundamWeapons"' in part_catalog, "PartCatalog must load the Gundam weapon module"
assert "#ordered >= 100" in part_catalog, "PartCatalog must be expansion-safe at 100+ parts"

part_registry = read("src/ServerScriptService/MechFramework/Services/PartRegistry.luau")
assert "self:Count() >= 100" in part_registry, "PartRegistry must accept the expanded catalogue"

control = read("src/ServerScriptService/MechFramework/Services/ControlService.luau")
assert "ReconcileBindings" in control, "ControlService must reconcile installed weapons"
assert "DefaultAction" in control, "default fire groups must honor weapon catalogue actions"

collection = read("src/ReplicatedStorage/MechFramework/Shared/CollectionDefinitions.luau")
assert "WeaponCatalog" in collection and "Definitions.Parts" in collection, "collection metadata must include the weapon catalogue"

projectiles = read("src/ServerScriptService/MechFramework/Services/ProjectileService.luau")
assert "CombatFeedback" in projectiles and 'Kind="Fired"' in projectiles and 'Kind="Impact"' in projectiles, "server projectiles must emit sanitized combat feedback"

print("PASS: Gundam weapon catalogue is adapted into the 100+ part architecture with default bindings, collection metadata, and server-owned feedback")
