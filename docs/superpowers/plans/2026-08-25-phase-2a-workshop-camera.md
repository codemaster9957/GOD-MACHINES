# Phase 2A Workshop Camera Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the avatar-centred Roblox build camera with a machine-centred workshop camera supporting orbit, free-fly, pan, zoom, framing, component focus and engineering views.

**Architecture:** `WorkshopCamera.luau` is a client-only stateful camera controller. `BuildController.client.luau` owns lifecycle and active mech identity, `BuildInput.luau` owns discrete workshop commands, and `BuildUI.luau` exposes a compact camera cluster. No camera code calls remotes or mutates machine state.

**Tech Stack:** Roblox Luau, `CurrentCamera`, `UserInputService`, `RunService`, raycasting, existing Workshop V3 UI and build controller.

**Spec:** `docs/superpowers/specs/2026-08-25-phase-2a-workshop-camera-design.md`

## Global Constraints

- Camera is client-only and never calls server remotes.
- Build mode uses `Enum.CameraType.Scriptable`; exit restores prior camera state.
- Focus is machine bounds, never character HRP.
- `Workspace` remains excluded from Rojo.
- Existing builder controls R/M/X/C/Z/Y/T/1–9 keep working.
- Entering Test mode must release Scriptable camera before pilot control.
- `F` must always recover the active machine.

---

### Task 1: Add regression invariants for workshop camera

**Files:**
- Modify: `scripts/verify_masterpiece.py`

**Interfaces:**
- Consumes: repository source text.
- Produces: checks requiring `WorkshopCamera.luau`, Scriptable mode, explicit restoration, controller lifecycle calls, and BuildInput camera commands.

- [ ] **Step 1: Write failing static checks**

Add checks for the file and tokens `CameraType = Enum.CameraType.Scriptable`, `function WorkshopCamera:Activate`, `function WorkshopCamera:Deactivate`, `FrameMachine`, `SetView`, `SetFreeFly`, `camera:Activate(mechId)`, `camera:Deactivate`, and `FrameCamera`/`ToggleFreeFly` callbacks in BuildInput.

- [ ] **Step 2: Run CI and confirm repository-invariants fails**

Run via the Phase 2 GitHub workflow.
Expected: repository-invariants fails because `WorkshopCamera.luau` does not exist.

- [ ] **Step 3: Commit test-only change**

Commit message: `test: require workshop camera architecture`.

### Task 2: Implement WorkshopCamera core

**Files:**
- Create: `src/StarterPlayer/StarterPlayerScripts/GodMachinesBuilder/WorkshopCamera.luau`

**Interfaces:**
- Produces: `WorkshopCamera.new(UserInputService, RunService)`, `Activate(mechId)`, `Deactivate(reason)`, `SetMech(mechId)`, `FrameMachine()`, `FocusComponent(instance)`, `SetView(viewName)`, `SetFreeFly(enabled)`, `Update(dt)`, `Destroy()`.

- [ ] **Step 1: Implement saved camera/input state**

Capture `CameraType`, `CameraSubject`, `CFrame`, `Focus`, `FieldOfView`, `MouseBehavior`, `MouseIconEnabled` on activation. Restore all on normal workshop exit; for `reason == "Test"`, restore player camera ownership without forcing the saved CFrame.

- [ ] **Step 2: Implement bounds/framing math**

Resolve `workspace.MechAssemblies[mechId]`, call `GetBoundingBox()`, derive radius and fit distance using camera FOV/aspect with 1.28 margin. Clamp distance to 2.5–1200 studs. Fallback focus uses current camera look point with radius 6 when no machine exists.

- [ ] **Step 3: Implement orbit/free-fly/pan/zoom input**

Track RMB/MMB drag, wheel delta and held WASD/Q/E/Shift/Ctrl. Orbit pitch clamps to ±85 degrees. Precision wins over boost. Mouse drag deltas are applied in `Update(dt)` rather than direct CFrame tween loops.

- [ ] **Step 4: Implement obstruction shortening**

Raycast from focus toward desired camera position, ignoring local character and active machine. Shorten camera distance to hit distance minus 0.6 studs with a minimum 1.5-stud clearance.

- [ ] **Step 5: Implement focus and engineering views**

`FocusComponent` resolves nearest component model/root and frames its bounds. `SetView` supports `Front`, `Rear`, `Left`, `Right`, `Top`, `Bottom`; each resets orbit/free-fly velocity and frames current radius.

- [ ] **Step 6: Commit camera core**

Commit message: `feat: add machine-centred workshop camera`.

### Task 3: Route workshop camera commands through BuildInput

**Files:**
- Modify: `src/StarterPlayer/StarterPlayerScripts/GodMachinesBuilder/BuildInput.luau`

**Interfaces:**
- Consumes callbacks: `FrameCamera()`, `ToggleFreeFly()`, `CameraView(viewName)`.
- Preserves callbacks: `Toggle`, `Rotate`, `Mirror`, `Place`, `Remove`, `Duplicate`, `Undo`, `Redo`, `SelectSlot`, `TestMachine`.

- [ ] **Step 1: Add F and Home commands**

`F` calls `FrameCamera`; `Home` calls `CameraView("Home")`.

- [ ] **Step 2: Add free-fly command**

`V` calls `ToggleFreeFly` to avoid stealing movement keys or existing builder commands.

- [ ] **Step 3: Add engineering view shortcuts**

Numpad 1/3/7 call Front/Right/Top; Shift variants are handled by UI instead of overloading keyboard parsing.

- [ ] **Step 4: Commit input routing**

Commit message: `feat: route workshop camera commands`.

### Task 4: Integrate camera lifecycle in BuildController

**Files:**
- Modify: `src/StarterPlayer/StarterPlayerScripts/GodMachinesBuilder/BuildController.client.luau`

**Interfaces:**
- Requires `WorkshopCamera` sibling module.
- Owns one `workshopCamera` instance.

- [ ] **Step 1: Construct camera controller**

Require module after other builder modules and instantiate with `UserInputService`, `RunService`.

- [ ] **Step 2: Synchronize active mech**

Call `workshopCamera:SetMech(normalized)` from `setActiveMech`.

- [ ] **Step 3: Activate/deactivate with build visibility**

When entering build mode, call `workshopCamera:Activate(mechId)` after UI activation. When leaving normal build mode, call `Deactivate("Close")`. Before Test transition, call `Deactivate("Test")` before server mode switch.

- [ ] **Step 4: Add focus-on-double-click without stealing placement**

Record left-click times and only focus when two clicks occur within 0.30 seconds on an existing component while no valid placement ghost is being committed; otherwise builder LMB remains place.

- [ ] **Step 5: Update camera every RenderStepped**

Call `workshopCamera:Update(dt)` whenever build mode is active.

- [ ] **Step 6: Wire BuildInput callbacks**

`FrameCamera`, `ToggleFreeFly`, `CameraView` delegate to WorkshopCamera.

- [ ] **Step 7: Destroy camera cleanly**

Call `workshopCamera:Destroy()` in `script.Destroying` before UI destruction.

- [ ] **Step 8: Commit controller integration**

Commit message: `feat: integrate workshop camera lifecycle`.

### Task 5: Add compact Workshop V3 camera controls

**Files:**
- Modify: `src/StarterPlayer/StarterPlayerScripts/GodMachinesBuilder/BuildUI.luau`

**Interfaces:**
- New callbacks: `FrameCamera`, `ToggleFreeFly`, `CameraView`.
- New method: `SetCameraMode(mode: string)`.

- [ ] **Step 1: Add compact camera cluster to command deck**

Add buttons `ORBIT`, `FLY`, `FRONT`, `SIDE`, `TOP`, `F FRAME` without creating a new large panel.

- [ ] **Step 2: Wire callbacks**

Buttons call existing controller callbacks only; UI never accesses CurrentCamera.

- [ ] **Step 3: Add mode feedback**

`SetCameraMode("Orbit" | "Fly")` highlights the active button.

- [ ] **Step 4: Commit UI controls**

Commit message: `feat: add workshop camera controls`.

### Task 6: Verify Phase 2A

**Files:**
- Verify: `.github/workflows/masterpiece-verify.yml`
- Verify: all changed `.luau` files

**Interfaces:**
- Produces: green static architecture + Luau compile gates.

- [ ] **Step 1: Run Phase 2 CI on exact head**

Expected: `Repository invariants` success and `Compile every Luau source` success.

- [ ] **Step 2: Review branch diff for camera-only scope**

Expected: no server mutation service changed by Phase 2A.

- [ ] **Step 3: Studio acceptance handoff**

Verify B opens machine-centred camera, RMB orbit, MMB pan, wheel zoom, WASD/Q/E flight, Shift/Ctrl speed modifiers, F frame, views, repeated B cycles, final-component deletion recovery, and Test mode camera restoration.
