# Phase 2A — Workshop Camera & Navigation Design

**Parent:** `2026-08-25-masterpiece-phase-2-design.md`

## Goal
Make Build Mode visually and ergonomically machine-first. The player avatar is irrelevant while constructing; the active machine is the camera subject.

## Files
Create:
- `src/StarterPlayer/StarterPlayerScripts/GodMachinesBuilder/WorkshopCamera.luau`

Modify:
- `BuildController.client.luau`
- `BuildInput.luau`
- `BuildUI.luau`
- `scripts/verify_masterpiece.py`

## Interface
`WorkshopCamera.new(UserInputService, RunService)`

Methods:
- `Activate(mechId: string?)`
- `Deactivate(reason: string?)`
- `SetMech(mechId: string?)`
- `FrameMachine()`
- `FocusComponent(instance: Instance?)`
- `SetView(viewName: string)` — Front/Rear/Left/Right/Top/Bottom
- `SetFreeFly(enabled: boolean)`
- `Update(dt: number)`
- `Destroy()`

Callbacks supplied by controller may expose selection/focus only; camera never calls server remotes.

## Camera state
Save and restore:
- CameraType
- CameraSubject
- CFrame
- Focus
- FieldOfView
- MouseBehavior
- MouseIconEnabled

While active:
- `CameraType = Scriptable`
- camera focus defaults to active mech bounding-box centre
- no dependency on character Humanoid/HRP

## Input
- RMB drag = orbit
- Mouse wheel = dolly
- MMB drag = pan
- WASD = planar/free movement
- Q/E = down/up
- Shift = boost
- Ctrl = precision
- F = frame machine
- Home = reset machine orbit
- double LMB on a component = focus component only when click is not consumed by placement; implementation must avoid fighting builder placement input

BuildInput should route camera-specific held state without stealing existing R/M/X/C/Z/Y/T/number controls.

## Framing math
Compute bounding radius from model `GetBoundingBox()`. Fit distance from vertical FOV and viewport aspect. Add margin (~1.2–1.35x). Clamp near and far distance. For no current mech, use the current ghost/foundation point and a default radius.

## Movement
Base speed = clamp(radius * scalar, minimum, maximum).
- precision = 0.2x
- boost = 3x
- boost + precision resolves to precision to avoid accidental launches

Orbit stores yaw/pitch separately. Pitch clamp approximately ±85 degrees. FreeFly may roll only if explicitly added later; Phase 2A keeps horizon stable.

## Collision / recovery
Camera does not need full collision solving. It performs a ray from focus toward desired camera position and shortens distance when a solid world obstruction is encountered. Ignore active mech and local character for this obstruction test. `F` always recovers to a valid view.

## UI
Workshop V3 adds a compact camera cluster:
- `ORBIT / FLY`
- FRONT / SIDE / TOP quick views
- `F FRAME`
No giant camera panel.

## Transitions
Tween numeric camera state in module update, not TweenService on Camera CFrame every frame. Enter/exit ~0.2 s easing.

On entering Test Mode, `Deactivate("Test")` restores player camera control before the pilot system takes over. On leaving workshop without Test, restore the exact pre-workshop state.

## Tests / invariants
Static:
- WorkshopCamera module exists.
- uses Scriptable camera mode.
- contains explicit restoration path.
- BuildController activates/deactivates it with Build Mode.
- F/FreeFly bindings exposed by BuildInput.

Studio:
- avatar can be off-screen while machine remains centred.
- 2x2 block and huge machine both frame correctly.
- no camera drift after repeated B open/close cycles.
- entering Test does not leave Scriptable camera stuck.
- deleting final component still leaves recoverable workshop camera.
