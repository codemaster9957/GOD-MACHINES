#!/usr/bin/env python3
"""Contract test for the GOD MACHINES exactly-100 improvement polish pack."""

from __future__ import annotations

from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
CATALOG = ROOT / "src/ReplicatedStorage/MechFramework/Shared/PolishCatalog.luau"
SERVER = ROOT / "src/ServerScriptService/MechFramework/Services/PolishService.luau"
CLIENT = ROOT / "src/StarterPlayer/StarterPlayerScripts/ExperiencePolish.client.luau"
BOOTSTRAP = ROOT / "src/ServerScriptService/MechFramework/Bootstrap.server.luau"
WORKFLOW = ROOT / ".github/workflows/masterpiece-verify.yml"
SPEC = ROOT / "docs/superpowers/specs/2026-08-26-100-improvements-design.md"


def read_required(path: Path) -> str:
    assert path.exists(), f"missing required polish file: {path.relative_to(ROOT)}"
    return path.read_text(encoding="utf-8")


def require(text: str, needle: str, context: str) -> None:
    assert needle in text, f"missing {context}: {needle!r}"


def main() -> None:
    catalog = read_required(CATALOG)
    server = read_required(SERVER)
    client = read_required(CLIENT)
    bootstrap = read_required(BOOTSTRAP)
    workflow = read_required(WORKFLOW)
    spec = read_required(SPEC)

    ids = re.findall(r'Id\s*=\s*"([A-Z]\d\d)"', catalog)
    expected = [f"{prefix}{n:02d}" for prefix in "BVCTOAPWRQ" for n in range(1, 11)]
    assert ids == expected, f"expected 100 ordered IDs, got {len(ids)}: {ids[:5]} ... {ids[-5:]}"
    assert len(ids) == 100, f"expected exactly 100 improvements, got {len(ids)}"
    assert len(set(ids)) == 100, "polish improvement IDs must be unique"

    for group in (
        "Builder & creation",
        "Vehicle & piloting",
        "Combat & aiming",
        "Trading & quick swap",
        "Session onboarding",
        "Accessibility & comfort",
        "Performance & efficiency",
        "World & immersion",
        "Reliability & fault tolerance",
        "HUD quality-of-life",
    ):
        require(spec, group, f"spec group {group}")

    require(catalog, 'Version = "2026.08.26-100"', "catalog version")
    require(catalog, "MasterEnabled = true", "master feature flag")
    require(catalog, "assert(#Catalog.Items == 100", "runtime exact-count validation")
    require(catalog, "function Catalog.IsEnabled", "per-improvement flag API")

    require(server, "PolishPackVersion", "server version attribute")
    require(server, "PolishPackReady", "server readiness attribute")
    require(server, "PolishEnabledCount", "server count attribute")
    require(server, "PolishReducedMotion", "reduced-motion preference")
    require(server, "PolishCameraMotion", "camera-motion preference")
    require(server, "PolishScreenFlash", "screen-flash preference")
    require(server, "PolishVignette", "vignette preference")
    require(server, "PolishCrosshairScale", "crosshair scale preference")
    require(server, "PolishTextScale", "text scale preference")
    require(server, "PolishSessionStartedAt", "session start attribute")

    optional_match = re.search(r"local OPTIONAL_ORDER = \{(.*?)\n\}", bootstrap, re.S)
    core_match = re.search(r"local CORE_ORDER = \{(.*?)\n\}", bootstrap, re.S)
    machine_match = re.search(r"local MACHINE_REQUIRED = \{(.*?)\n\}", bootstrap, re.S)
    assert optional_match and '"PolishService"' in optional_match.group(1), "PolishService must be optional"
    assert core_match and '"PolishService"' not in core_match.group(1), "PolishService must not be core"
    assert machine_match and '"PolishService"' not in machine_match.group(1), "PolishService must not gate machine readiness"

    for needle, context in (
        ("GodMachinesPolishHUD", "polish ScreenGui"),
        ("TELEMETRY_INTERVAL", "telemetry rate cap"),
        ("resolveActiveMech", "lazy active-mech resolution"),
        ("PolishReducedMotion", "reduced-motion consumption"),
        ("PolishCameraMotion", "camera-motion consumption"),
        ("PolishScreenFlash", "screen-flash consumption"),
        ("PolishVignette", "vignette consumption"),
        ("CombatFeedback", "optional combat feedback hook"),
        ("FindFirstChild", "defensive optional lookup"),
        ("Enum.KeyCode.F10", "cinematic HUD toggle"),
        ("Enum.KeyCode.H", "compact HUD toggle"),
        ("script.Destroying", "connection cleanup"),
        ("MAX_NOTIFICATIONS", "bounded notification queue"),
        ("CurrentCamera", "camera reacquisition"),
        ("ActiveMechId", "active mech binding"),
        ("BuildMode", "build-mode binding"),
        ("ViewportSize", "auto UI scaling"),
    ):
        require(client, needle, context)

    require(workflow, "Verify 100-improvement polish contract", "CI polish contract step")
    require(workflow, "python scripts/test_100_improvements_contract.py", "CI polish contract command")

    print("100-improvement polish contract: PASS")


if __name__ == "__main__":
    main()
