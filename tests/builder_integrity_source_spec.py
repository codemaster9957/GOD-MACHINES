#!/usr/bin/env python3
from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def source(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


checks = {
    "shared clearance sizing": (
        "src/ReplicatedStorage/MechFramework/Shared/BuildMath.luau",
        "function BuildMath.ClearanceSize",
    ),
    "preview predicts clearance": (
        "src/StarterPlayer/StarterPlayerScripts/GodMachinesBuilder/BuildPreview.luau",
        "function BuildPreview:_hasClearance",
    ),
    "preview exposes blocked state": (
        "src/StarterPlayer/StarterPlayerScripts/GodMachinesBuilder/BuildPreview.luau",
        'self.LastState="BLOCKED"',
    ),
    "preview checks snapped clearance": (
        "src/StarterPlayer/StarterPlayerScripts/GodMachinesBuilder/BuildPreview.luau",
        "self:_hasClearance(snapped)",
    ),
    "preview rejects sky foundations": (
        "src/StarterPlayer/StarterPlayerScripts/GodMachinesBuilder/BuildPreview.luau",
        "function BuildPreview:_hasBuildSurface",
    ),
    "preview exposes missing surface state": (
        "src/StarterPlayer/StarterPlayerScripts/GodMachinesBuilder/BuildPreview.luau",
        'self.LastState="NO_BUILD_SURFACE"',
    ),
    "preview publishes state to node visualizer": (
        "src/StarterPlayer/StarterPlayerScripts/GodMachinesBuilder/BuildPreview.luau",
        'self.Ghost:SetAttribute("PreviewState",state)',
    ),
    "preview publishes target node to node visualizer": (
        "src/StarterPlayer/StarterPlayerScripts/GodMachinesBuilder/BuildPreview.luau",
        'self.Ghost:SetAttribute("TargetNode",self.TargetNode or "")',
    ),
    "node visualizer has blocked feedback": (
        "src/StarterPlayer/StarterPlayerScripts/GodMachinesBuilder/NodeVisualizer.luau",
        "local BLOCKED = Color3.fromRGB",
    ),
    "node visualizer reads preview state": (
        "src/StarterPlayer/StarterPlayerScripts/GodMachinesBuilder/NodeVisualizer.luau",
        'ghost:GetAttribute("PreviewState")',
    ),
    "server uses shared clearance sizing": (
        "src/ServerScriptService/MechFramework/Services/BuildService.luau",
        "BuildMath.ClearanceSize",
    ),
    "server placement can exclude builder avatar": (
        "src/ServerScriptService/MechFramework/Services/BuildService.luau",
        "player.Character",
    ),
    "controller explains blocked placement": (
        "src/StarterPlayer/StarterPlayerScripts/GodMachinesBuilder/BuildController.client.luau",
        'state=="BLOCKED"',
    ),
    "controller explains missing build surface": (
        "src/StarterPlayer/StarterPlayerScripts/GodMachinesBuilder/BuildController.client.luau",
        'state=="NO_BUILD_SURFACE"',
    ),
    "controller tracks placement request in flight": (
        "src/StarterPlayer/StarterPlayerScripts/GodMachinesBuilder/BuildController.client.luau",
        "local placementBusy = false",
    ),
    "controller refuses overlapping placements": (
        "src/StarterPlayer/StarterPlayerScripts/GodMachinesBuilder/BuildController.client.luau",
        "if not buildMode or placementBusy then return end",
    ),
}

failures: list[str] = []
for label, (path, needle) in checks.items():
    text = source(path)
    if needle not in text:
        failures.append(f"{label}: missing {needle!r} in {path}")

preview = source("src/StarterPlayer/StarterPlayerScripts/GodMachinesBuilder/BuildPreview.luau")
if "return attachment,source,snapped" not in preview:
    failures.append("preview does not return the clearance-validated snapped transform from candidate search")
if "return blockedAttachment,blockedSource,blockedTransform,true" not in preview:
    failures.append("preview does not retain the nearest blocked compatible snap for truthful red feedback")
if 'elseif type(activeMechId)=="string" then self.LastState="ATTACHMENT_REQUIRED"' not in preview:
    failures.append("preview state flow changed unexpectedly around attachment-required handling")
if "distance<995" not in preview:
    failures.append("preview does not distinguish real build surfaces from the 1000-stud sky fallback")

server = source("src/ServerScriptService/MechFramework/Services/BuildService.luau")
if "self:_clearance(definition,transform,exclusions)" not in server:
    failures.append("authoritative placement does not pass avatar exclusions into clearance")

controller = source("src/StarterPlayer/StarterPlayerScripts/GodMachinesBuilder/BuildController.client.luau")
if 'BLOCKED="PLACEMENT BLOCKED"' not in controller:
    failures.append("click feedback does not explain blocked placement")
if 'NO_BUILD_SURFACE="AIM AT A BUILD SURFACE"' not in controller:
    failures.append("click feedback does not explain sky/no-surface placement")
if "placementBusy=true" not in controller or "placementBusy=false" not in controller:
    failures.append("placement request lock is not acquired and released around the server call")
if 'status("INSTALLING COMPONENT", "blue", 30)' not in controller:
    failures.append("placement request does not expose a stable in-flight status")

visualizer = source("src/StarterPlayer/StarterPlayerScripts/GodMachinesBuilder/NodeVisualizer.luau")
if 'previewState=="BLOCKED"' not in visualizer:
    failures.append("selected blocked target socket is not rendered with blocked feedback")

if failures:
    print("FAIL: builder integrity regression contract is not satisfied")
    for failure in failures:
        print(f" - {failure}")
    sys.exit(1)

print("PASS: builder integrity, surface validation, truthful node feedback, and serialized placement are wired")
