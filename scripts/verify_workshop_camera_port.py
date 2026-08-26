#!/usr/bin/env python3
"""Regression checks for the Workshop camera being shipped on current main."""
from pathlib import Path
import sys

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
    check(target.is_file(), f"missing required camera file: {path}")
    if not target.is_file():
        return ""
    return target.read_text(encoding="utf-8")


base = "src/StarterPlayer/StarterPlayerScripts/GodMachinesBuilder/"
camera = text(base + "WorkshopCamera.luau")
controller = text(base + "WorkshopCameraController.client.luau")
build_input = text(base + "BuildInput.luau")

check("Enum.CameraType.Scriptable" in camera, "camera must own CurrentCamera while Workshop is open")
check("function WorkshopCamera:Activate" in camera, "camera activation path missing")
check("function WorkshopCamera:Deactivate" in camera, "camera restoration path missing")
check("function WorkshopCamera:Update" in camera, "camera render-step update missing")
check("Raycast" in camera and "GetBoundingBox" in camera, "camera framing/obstruction logic missing")
check("BuildMode" in controller and "ActiveMechId" in controller, "controller must follow Workshop lifecycle and active machine")
check("workshopCamera:Activate" in controller and "workshopCamera:Deactivate" in controller, "controller must activate/deactivate camera")
check("workshopCamera:Update" in controller and "RenderStepped" in controller, "controller must tick camera every frame")
check("GMWorkshopCameraOwnsWheel" in controller, "controller must claim mouse wheel while camera is active")
check("GMWorkshopCameraOwnsWheel" in build_input, "build hotbar must not also consume camera zoom wheel")
check("KeypadOne" in controller and "KeypadThree" in controller and "KeypadSeven" in controller, "engineering view shortcuts missing")
check("Enum.KeyCode.F" in controller and "Enum.KeyCode.V" in controller and "Enum.KeyCode.Home" in controller, "frame/free-fly/home shortcuts missing")

if ERRORS:
    print(f"WORKSHOP CAMERA PORT FAILED: {len(ERRORS)} error(s) across {CHECKS} checks")
    for error in ERRORS:
        print("  -", error)
    sys.exit(1)

print(f"WORKSHOP CAMERA PORT PASSED: {CHECKS} checks")
