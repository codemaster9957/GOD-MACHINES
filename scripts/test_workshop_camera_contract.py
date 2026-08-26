from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
CAMERA = ROOT / "src/StarterPlayer/StarterPlayerScripts/GodMachinesBuilder/WorkshopCamera.luau"
CONTROLLER = ROOT / "src/StarterPlayer/StarterPlayerScripts/GodMachinesBuilder/BuildController.client.luau"
INPUT = ROOT / "src/StarterPlayer/StarterPlayerScripts/GodMachinesBuilder/BuildInput.luau"
BAR = ROOT / "src/StarterPlayer/StarterPlayerScripts/GodMachinesBuilder/WorkshopCameraBar.luau"
PROJECT = ROOT / "default.project.json"

sources = {
    "camera": CAMERA.read_text(encoding="utf-8"),
    "controller": CONTROLLER.read_text(encoding="utf-8"),
    "input": INPUT.read_text(encoding="utf-8"),
    "bar": BAR.read_text(encoding="utf-8"),
    "project": PROJECT.read_text(encoding="utf-8"),
}

checks = []

def require(source, token, message):
    checks.append((token in sources[source], message))

# Core ownership/lifecycle.
require("camera", "function WorkshopCamera:Activate", "camera exposes Activate")
require("camera", "function WorkshopCamera:Deactivate", "camera exposes Deactivate")
require("camera", "CameraType = Enum.CameraType.Scriptable", "build camera takes Scriptable ownership")
require("camera", "function WorkshopCamera:FrameMachine", "camera can frame the active machine")
require("camera", "function WorkshopCamera:FocusComponent", "camera can focus a component")
require("camera", "function WorkshopCamera:SetView", "camera exposes engineering views")
require("camera", "function WorkshopCamera:SetFreeFly", "camera exposes free-fly")
require("controller", "workshopCamera:Activate(mechId)", "controller activates camera in workshop")
require("controller", "workshopCamera:Deactivate(\"Test\")", "controller releases camera before Test mode")
require("controller", "workshopCamera:Update(dt)", "controller updates camera on RenderStepped")
require("controller", "workshopCamera:Destroy()", "controller destroys camera cleanly")

# Recovery/input/UI contract.
require("input", "Enum.KeyCode.F", "F recovery shortcut exists")
require("input", "callbacks.FrameCamera()", "F routes to FrameCamera")
require("input", "Enum.KeyCode.V", "free-fly shortcut exists")
require("input", "callbacks.ToggleFreeFly()", "V routes to free-fly")
require("input", 'shiftDown(UserInputService) then "Rear" else "Front"', "Shift+Numpad1 exposes rear view")
require("input", 'shiftDown(UserInputService) then "Left" else "Right"', "Shift+Numpad3 exposes left view")
require("input", 'shiftDown(UserInputService) then "Bottom" else "Top"', "Shift+Numpad7 exposes bottom view")
require("bar", '"F FRAME"', "camera bar exposes frame control")
require("bar", '"ORBIT"', "camera bar exposes orbit mode")
require("bar", '"FLY [V]"', "camera bar exposes fly mode")

# Placement-safe double-click focus. WorkshopCamera owns continuous pointer camera gestures;
# the build controller still owns placement and never exposes server mutation to the camera.
require("camera", "DOUBLE_CLICK_WINDOW = 0.30", "double-click focus uses the approved 0.30s window")
require("camera", "self._lastPrimaryClickAt", "camera tracks primary-click timing")
require("camera", "function WorkshopCamera:_placementGhostValid", "camera can detect when a valid placement must win")
require("camera", "if isDoubleClick and not self:_placementGhostValid() then", "component focus never steals a valid placement")
require("camera", "self:FocusComponent(target)", "double-click routes the hovered component into FocusComponent")
require("camera", "if self.FreeFly then", "component focus preserves free-fly mode state")

# Workspace remains Studio-owned; CurrentCamera is not synced by Rojo.
require("project", '"syncCurrentCamera": false', "Rojo keeps CurrentCamera Studio-owned")
if '"Workspace"' in sources["project"]:
    checks.append((False, "Workspace must remain excluded from the Rojo tree"))

failures = [message for ok, message in checks if not ok]
if failures:
    print(f"WORKSHOP CAMERA CONTRACT FAILED: {len(failures)} error(s) across {len(checks)} checks")
    for failure in failures:
        print(f"  - {failure}")
    sys.exit(1)

print(f"WORKSHOP CAMERA CONTRACT PASSED: {len(checks)} checks")
