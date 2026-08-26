#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


catalog_path = "src/ReplicatedStorage/MechFramework/Shared/WeaponCatalog.luau"
binding_path = "src/ReplicatedStorage/MechFramework/Shared/ControlBindingPolicy.luau"
effects_path = "src/StarterPlayer/StarterPlayerScripts/WeaponEffects.client.luau"

for path in (catalog_path, binding_path, effects_path):
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

part_registry = read("src/ServerScriptService/MechFramework/Services/PartRegistry.luau")
assert "WeaponCatalog" in part_registry, "PartRegistry must register the shared weapon catalogue"

control = read("src/ServerScriptService/MechFramework/Services/ControlService.luau")
assert "ReconcileBindings" in control, "ControlService must reconcile installed weapons"
assert 'packet.Action == "Reload"' in control, "ControlService must route reload input"

build = read("src/ServerScriptService/MechFramework/Services/BuildService.luau")
assert "ReconcileBindings" in build, "build mutations must refresh weapon bindings"

collection = read("src/ReplicatedStorage/MechFramework/Shared/CollectionDefinitions.luau")
for weapon_id in expected_ids:
    assert weapon_id in collection, f"collection definitions missing {weapon_id}"

print("PASS: Gundam weapon catalogue, bindings, reload routing, build reconciliation, collection integration, and feedback client are wired")
