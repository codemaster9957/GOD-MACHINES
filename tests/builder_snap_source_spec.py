#!/usr/bin/env python3
from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def source(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


checks = {
    "shared facing-aware source selector": (
        "src/ReplicatedStorage/MechFramework/Shared/BuildMath.luau",
        "function BuildMath.BestCompatibleSource",
    ),
    "preview uses shared source selector": (
        "src/StarterPlayer/StarterPlayerScripts/GodMachinesBuilder/BuildPreview.luau",
        "self.BuildMath.BestCompatibleSource",
    ),
    "server recomputes source selector authoritatively": (
        "src/ServerScriptService/MechFramework/Services/BuildService.luau",
        "BuildMath.BestCompatibleSource",
    ),
    "node visualizer evaluates the selected ghost": (
        "src/StarterPlayer/StarterPlayerScripts/GodMachinesBuilder/NodeVisualizer.luau",
        "GodMachinesBuildGhost",
    ),
    "node visualizer uses shared compatibility/source selection": (
        "src/StarterPlayer/StarterPlayerScripts/GodMachinesBuilder/NodeVisualizer.luau",
        "BuildMath.BestCompatibleSource",
    ),
    "node visualizer caches selected source nodes": (
        "src/StarterPlayer/StarterPlayerScripts/GodMachinesBuilder/NodeVisualizer.luau",
        "_sourceNodeCacheKey",
    ),
}

failures: list[str] = []
for label, (path, needle) in checks.items():
    text = source(path)
    if needle not in text:
        failures.append(f"{label}: missing {needle!r} in {path}")

preview = source("src/StarterPlayer/StarterPlayerScripts/GodMachinesBuilder/BuildPreview.luau")
if 'if ok and compatible then return attachment,source end' in preview:
    failures.append("preview still returns the first compatible source node instead of the best-facing source")

server = source("src/ServerScriptService/MechFramework/Services/BuildService.luau")
if 'sourceNode=BuildMath.Nodes(definition,mirrorX)[request.SourceNode]' in server:
    failures.append("server still trusts the client-selected source node directly")

if failures:
    print("FAIL: builder snapping regression contract is not satisfied")
    for failure in failures:
        print(f" - {failure}")
    sys.exit(1)

print("PASS: builder preview/server use deterministic facing-aware node selection and truthful cached node visualization")
