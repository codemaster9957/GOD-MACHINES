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
}

failures: list[str] = []
for label, (path, needle) in checks.items():
    text = source(path)
    if needle not in text:
        failures.append(f"{label}: missing {needle!r} in {path}")

preview = source("src/StarterPlayer/StarterPlayerScripts/GodMachinesBuilder/BuildPreview.luau")
if "return attachment,source,snapped" not in preview:
    failures.append("preview does not return the clearance-validated snapped transform from candidate search")
if 'elseif type(activeMechId)=="string" then self.LastState="ATTACHMENT_REQUIRED"' not in preview:
    failures.append("preview state flow changed unexpectedly around attachment-required handling")

server = source("src/ServerScriptService/MechFramework/Services/BuildService.luau")
if "self:_clearance(definition,transform,exclusions)" not in server:
    failures.append("authoritative placement does not pass avatar exclusions into clearance")

controller = source("src/StarterPlayer/StarterPlayerScripts/GodMachinesBuilder/BuildController.client.luau")
if 'BLOCKED="PLACEMENT BLOCKED"' not in controller:
    failures.append("click feedback does not explain blocked placement")

if failures:
    print("FAIL: builder integrity regression contract is not satisfied")
    for failure in failures:
        print(f" - {failure}")
    sys.exit(1)

print("PASS: builder preview/server clearance parity and blocked-placement feedback are wired")
