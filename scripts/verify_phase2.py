#!/usr/bin/env python3
"""Phase 2 architectural invariants for GOD MACHINES.

These checks intentionally fail before each Phase 2 subsystem exists, then become
permanent regression protection as the subsystem is implemented.
"""
from __future__ import annotations

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
    check(target.is_file(), f"missing required Phase 2 file: {path}")
    if not target.is_file():
        return ""
    return target.read_text(encoding="utf-8")


camera = text("src/StarterPlayer/StarterPlayerScripts/GodMachinesBuilder/WorkshopCamera.luau")
build_input = text("src/StarterPlayer/StarterPlayerScripts/GodMachinesBuilder/BuildInput.luau")
controller = text("src/StarterPlayer/StarterPlayerScripts/GodMachinesBuilder/BuildController.client.luau")
camera_bar = text("src/StarterPlayer/StarterPlayerScripts/GodMachinesBuilder/WorkshopCameraBar.luau")

# P2-A workshop camera contract.
check("Enum.CameraType.Scriptable" in camera, "WorkshopCamera must enter Scriptable camera mode")
check("function WorkshopCamera:Activate" in camera, "WorkshopCamera.Activate is missing")
check("function WorkshopCamera:Deactivate" in camera, "WorkshopCamera.Deactivate is missing")
check("function WorkshopCamera:FrameMachine" in camera, "WorkshopCamera.FrameMachine is missing")
check("function WorkshopCamera:FocusComponent" in camera, "WorkshopCamera.FocusComponent is missing")
check("function WorkshopCamera:SetView" in camera, "WorkshopCamera.SetView is missing")
check("function WorkshopCamera:SetFreeFly" in camera, "WorkshopCamera.SetFreeFly is missing")
check("function WorkshopCamera:Update" in camera, "WorkshopCamera.Update is missing")
check("CameraSubject" in camera and "MouseBehavior" in camera and "MouseIconEnabled" in camera, "WorkshopCamera must preserve camera/input state")
check("_restoreState" in camera or "restoreState" in camera, "WorkshopCamera needs an explicit restoration path")
check("Raycast" in camera and "RaycastParams" in camera, "WorkshopCamera must shorten against world obstruction")
check("GetBoundingBox" in camera, "WorkshopCamera framing must use machine/component bounds")

check("FrameCamera" in build_input, "BuildInput must expose FrameCamera")
check("ToggleFreeFly" in build_input, "BuildInput must expose ToggleFreeFly")
check("CameraView" in build_input, "BuildInput must expose CameraView")

check("WorkshopCamera" in controller, "BuildController must require WorkshopCamera")
check("workshopCamera:Activate" in controller, "BuildController must activate WorkshopCamera with build mode")
check("workshopCamera:Deactivate" in controller, "BuildController must deactivate WorkshopCamera")
check("workshopCamera:SetMech" in controller, "BuildController must keep camera mech identity synchronized")
check("workshopCamera:Update" in controller, "BuildController must tick WorkshopCamera on RenderStepped")

check("WorkshopCameraBar" in camera_bar, "WorkshopCameraBar module is missing")
check("SetCameraMode" in camera_bar, "WorkshopCameraBar must display workshop camera mode")
check("F FRAME" in camera_bar, "WorkshopCameraBar must expose F FRAME control")
check("CameraView" in camera_bar, "WorkshopCameraBar must expose engineering camera view callbacks")
check("WorkshopCameraBar" in controller, "BuildController must mount the compact camera bar")

if ERRORS:
    print(f"PHASE 2 VERIFICATION FAILED: {len(ERRORS)} error(s) across {CHECKS} checks")
    for error in ERRORS:
        print(f"  - {error}")
    sys.exit(1)

print(f"PHASE 2 VERIFICATION PASSED: {CHECKS} checks")
