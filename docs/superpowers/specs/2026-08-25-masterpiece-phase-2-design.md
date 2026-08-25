# GOD MACHINES — Masterpiece Phase 2 Design

## Status
Design for the post-Workshop-V3 expansion. This branch is based on `feat/masterpiece-builder-v2` and intentionally stays separate from PR #4 until Phase 2 is independently verified.

## Goal
Make construction, inspection, piloting and destruction feel like a purpose-built machine game rather than a Roblox character carrying a builder UI. Phase 2 implements the approved 100-item improvement board: workshop camera, better snapping, structural building primitives, symmetry/group tools, wheel/propulsion remasters, mechanisms, engineering overlays, new utility/weapons, damage presentation and audio/polish.

## Non-negotiable principles
1. **Machine-first camera.** The avatar is not the visual centre of construction mode.
2. **No arbitrary part cap.** Limits remain emergent from mass, power, fuel, heat, structure, aero and server performance safeguards.
3. **One canonical component model.** Preview, catalog thumbnail, runtime and blueprint use the same PartCatalog + PartRenderer definition.
4. **Server authority for mutations and combat.** Camera/UI are client-side; construction graph changes, inventory, mechanisms that affect physics, damage and weapons remain server-authoritative.
5. **Existing content gets remastered, not protected.** Old wheels, engines, wings, weapons and reactors are allowed to change visual recipes when their current geometry is poor.
6. **Build mode is edit-safe.** Build mutations cannot run on an active Test/Battle mech.
7. **Quality over fake simulation.** Use bounded arcade-physical models where Roblox constraints become unstable; never advertise exact real-world engineering values when the game only estimates them.
8. **Workspace remains Studio-owned.** No Rojo Workspace mapping.
9. **Every new feature gets a static invariant and a Studio acceptance test.**

## Decomposition
Phase 2 is executed as six subprojects in this order:

### P2-A — Workshop Camera & Build Navigation
- Detached machine-centred construction camera.
- Orbit, free-fly, pan, zoom, precision and boost movement.
- Frame entire machine, focus selected component, orthographic-like engineering views.
- Smooth enter/exit transitions and camera-state restoration.
- Camera collision/near clipping safeguards.

### P2-B — Build Geometry, Nodes, Selection & Symmetry
- Stud Block family and other simple structural primitives.
- Multi-node large surfaces.
- Outward node orientation audit and node direction arrows.
- Smart nearest-node snap, snap cycling and XYZ rotation.
- Multi-select, group duplicate/move/mirror and symmetry mode.
- Group operations remain inventory-transactional and undoable.

### P2-C — Mobility, Mechanisms & Part Remaster
- Complete wheel visual remaster; no axle rod protruding through outer sidewall.
- Recessed inner hub, outer hubcap, tyre tread variants, brake details and steering knuckles.
- Better suspension representation and caster behaviour.
- Tracks V1 visual belt over sprocket/bogie systems.
- Hinge, servo, piston, rotator and turret-bearing mechanisms.
- Engine/propeller/reactor visual remaster.

### P2-D — Propulsion, Aerodynamics & Engineering Overlays
- Gearbox/differential/turbo/afterburner/variable-pitch/contra-rotating propulsion options.
- Jet intake obstruction and exhaust danger.
- Rocket gimbal.
- Airfoil wing remaster; root/mid/tip sections, flaps and animated control surfaces.
- Centre of mass, centre of lift, thrust vectors, asymmetry, power/fuel/heat overlays.
- Estimated acceleration and speed class.

### P2-E — Utility, Weapons, Damage & Presentation
- Functional headlights/brake/nav lights, camera block and rangefinder.
- Turret/recoil/reload visual remaster.
- Ammo families, bomb rack and guided bomb.
- Damage stages, fire, sparks, smoke and volatile-part presentation.
- Mechanical audio layering and workshop presentation mode.

### P2-F — Hardening & Bug Sweep
- Runtime error sweep across all services.
- Save/blueprint migrations for new component settings and mechanisms.
- Performance budgets and adaptive visual detail.
- CI/static checks for all new module contracts.
- Full Studio acceptance checklist before merge.

---

# A. Workshop Camera Design

## Ownership
Create `src/StarterPlayer/StarterPlayerScripts/GodMachinesBuilder/WorkshopCamera.luau` as a client-only module. `BuildController.client.luau` owns when the camera activates; `WorkshopCamera` owns camera state while active.

## State model
`Inactive -> Entering -> Orbit/FreeFly -> Exiting -> Inactive`

On activation:
- Save CameraType, CameraSubject, CFrame, FieldOfView, mouse behaviour and mouse icon state.
- Set CurrentCamera to Scriptable.
- Compute active mech bounds from `workspace.MechAssemblies[MechId]`.
- Use bounding-box centre as focus, never character HRP.
- Fit distance from bounds radius + FOV.
- Ease into build camera over ~0.18–0.25 seconds.

On deactivation:
- Clear held movement state.
- Restore mouse behaviour.
- Restore previous CameraType/Subject/FOV cleanly.
- When entering Test, prefer Roblox/player pilot camera path rather than restoring a stale pre-build transform.

## Default controls
- RMB drag: orbit around focus.
- Mouse wheel: dolly/zoom.
- MMB drag: pan focus.
- WASD: fly focus/camera in view plane.
- Q/E: down/up.
- Shift: movement boost.
- Ctrl: precision speed.
- F: frame complete machine.
- Double-click component: focus that component.
- Numpad/toolbar: Front, Rear, Left, Right, Top, Bottom views.
- Home: reset to machine-centred orbit.

## Movement rules
- Base movement speed scales with machine bounding radius, clamped to sensible min/max.
- Precision is 0.2x base; boost is 3x base.
- Orbit pitch clamped to avoid singular upside-down controls unless the user intentionally enters FreeFly.
- Zoom cannot enter component geometry closer than a small near-distance bound.
- FreeFly has a generous radius limit around the active machine to prevent losing the workshop entirely; `F` always recovers.

## UX
- Workshop V3 gets a tiny camera mode pill, view buttons, and an `F FRAME` hint.
- Selecting a component does **not** forcibly move the camera.
- Double-click focus is explicit.
- Machine bounds changes update target radius lazily; do not jerk focus every placement.

---

# B. Build Geometry, Nodes & Symmetry Design

## Structural baseline additions
Add these general-purpose primitives to the Structural category, with unique procedural recipes:
1. StudBlock — 2x2x2 universal cube.
2. HalfStudBlock — 2x1x2.
3. LongStudBeam — 2x2x6 with intermediate node grid.
4. StructuralPlate — 4x0.5x4.
5. CornerBlock — L-shaped corner cell.
6. TriangularBlock — wedge/truss hybrid.
7. RoundStructuralCell — cylindrical structural hub.

The catalog is no longer constrained to exactly 100 entries. Phase 2 validation changes to **minimum 100 + expected unique required IDs + per-category minimums** so expansion is legal without weakening validation.

## Node system
`PartDefinitionHelpers` gains node-grid helpers for large faces. Nodes carry:
- Name
- Type
- Transform
- Accepts/CompatibleWith
- optional `Priority`
- optional `Role`
- optional `Surface`

Rules:
- Left/Right face normals always point outward.
- All six box face conventions receive static orientation tests.
- Large plates/beams may expose multiple node positions on a face.
- NodeVisualizer shows an outward arrow/normal in addition to a ball when hovered/near-selected.
- Green = free compatible, amber = occupied, grey = incompatible.

## Smart snapping
BuildPreview ranks candidates by:
1. compatibility,
2. cursor world distance,
3. facing alignment,
4. node priority.

Tab / mouse-wheel modifier cycles candidates without moving the cursor.

## Rotation
Replace single quarter-turn state with orientation state supporting local X/Y/Z quarter-turns. Default `R` rotates around current primary axis; X/Y/Z axis shortcuts or small UI axis selector change the active axis. Server receives normalized orientation, never arbitrary client CFrame without validation.

## Multi-select
Client `BuildSelection.luau` owns selection presentation. Server operations accept arrays only after validating:
- ownership,
- same mech,
- edit mode,
- maximum transaction payload,
- component existence,
- inventory consequences.

Selection methods:
- Shift-click add/remove.
- Box select in screen space.
- Ctrl+A limited to active mech.
- Escape clears.

## Group operations
- Group duplicate creates a transactional copy with fresh IDs and preserves internal graph edges, appearance, mirror state and settings.
- Group mirror reflects local transforms around a chosen machine-local X/Y/Z plane and rebuilds valid mirrored connections.
- Group move is restricted to selections whose external boundary connections are explicitly resolved; default behaviour moves free subassemblies, not arbitrary graph surgery.
- Undo/redo stores the entire transaction.

## Symmetry mode
Symmetry is an optional placement tool, initially mirror-across-machine-X.
- Placement previews both primary and mirrored copy.
- Inventory preflight requires both items unless the placement lies on symmetry plane.
- Both placements commit or neither commits.
- Removing/mirroring symmetry mates is optional, not permanently linked.

---

# C. Mobility, Mechanisms & Remaster Design

## Wheel standard
All wheel definitions adopt a shared recipe convention:
- chassis side = inner face,
- exterior side = clean hubcap/rim,
- axle/constraint anchor stays on inner side and is hidden inside the wheel assembly,
- tyre visual rotates with hub,
- decorative tyre/rim geometry remains massless,
- canonical physical wheel member carries collision/constraint duties.

Existing wheel families get distinct tread/rim silhouettes. New wheels: Scooter, Racing, Sand/Paddle, TankRoadWheel.

## Suspension
SuspensionWheel and related mobility definitions expose `SuspensionMount` and `WheelAxis` sockets. Visual spring/damper tracks constraint motion where feasible. If direct spring constraints destabilize high-part builds, use bounded server-calculated suspension force while preserving the visual spring.

## Tracks V1
No chain of dozens of physical tread links. Use sprocket/bogie physical wheels plus a client/runtime visual belt generated between them. Belt is cosmetic; traction remains calculated through tracked mobility metadata.

## MechanismService
Create `MechanismService.luau` for controllable structural motion:
- Hinge: target angle or direct positive/negative action.
- Servo: bounded target angle with speed/torque.
- Piston: bounded extension.
- Rotator: continuous angular drive.
- TurretBearing: heavy yaw mechanism with mass/torque/power constraints.

Mechanism state is server-authoritative and integrates with ControlService groups `Mechanism1`, `Mechanism2`, plus advanced custom actions later.

Blueprint component settings persist mechanism limits/default directions, not current transient position unless explicitly saved in Edit mode.

## Engine/propeller/reactor remaster
Update geometry only through PartDefinitions/PartRenderer roles; behaviour IDs remain stable. Existing saves remain valid.

---

# D. Propulsion, Aero & Engineering Design

## Drivetrain additions
- Gearbox: configurable torque/speed ratio presets; no infinite CVT.
- Differential: improves driven-wheel distribution and is required only for advanced efficiency bonus, not basic movement.
- Turbocharger: boosts combustion torque, raises heat and fuel demand.

## Propeller additions
- VariablePitchPropeller: higher efficiency across speed range, power-actuated pitch abstraction.
- ContraRotatingPropeller: paired rotor role, reduced reaction torque, heavier/power hungry.

## Jets/rockets
- Intake obstruction uses one or a few server ray/box checks from intake socket; obstruction scales available thrust, not binary unless fully blocked.
- Jet exhaust applies short-range heat/damage behind nozzle while active, with owner-safe construction mode disabled.
- Afterburner is a control action/state that multiplies thrust with sharply increased fuel/heat.
- Rocket gimbal applies bounded thrust-vector angle from pitch/yaw control.

## Wings
Wing definitions use shaped procedural geometry. New root/mid/tip sections form a coherent family. Aero metadata includes Area, LiftCoefficient, DragCoefficient, StallAngle and ControlSurface type.

Control surfaces animate visually to match server control state.

## EngineeringOverlay
Create client-only `EngineeringOverlay.luau` fed by server summary data and replicated component attributes where safe.
Modes:
- COM marker.
- centre-of-lift marker.
- thrust vectors.
- power topology.
- fuel topology.
- thermal risk heatmap.
- structural warnings.

Overlay is non-queryable and client-only.

## Estimates
Show classes/ranges, not fake precision:
- Acceleration: Poor / Low / Medium / High / Extreme.
- Estimated Speed: Crawl / Utility / Fast / Very Fast / Extreme.
- Stability warnings use asymmetry and COM/support geometry.

---

# E. Utility, Weapons, Damage & Presentation Design

## Utility
- Headlight: controllable SpotLight + emissive lens.
- BrakeLight: automatic from Brake action with optional manual override.
- NavLights: paired red/green marker metadata.
- CameraBlock: client can switch pilot view to a mounted camera socket owned by current machine.
- Rangefinder: server ray result surfaced as distance; no wallhack target identity beyond line of sight.

## Weapons
Visual remaster standard:
- canonical mount/root,
- turret/bearing where applicable,
- recoil slide role,
- muzzle socket,
- breech/reload visual role,
- ammo/feed geometry.

New weapon families:
- BombRack — unguided gravity ordnance.
- GuidedBomb — server-guided limited steering after release.
- Ammo variants initially AP / HE / Incendiary where compatible.

Damage remains server-side. Client only requests actions.

## Damage presentation
Component health bands:
- >70% normal,
- 40–70% scuffed/darkened,
- 15–40% sparks/smoke chance,
- <15% critical effects,
- destroyed: detach/break according to existing structural graph.

Fire is a timed server status sourced from severe heat/explosive/fuel damage. Fire adds heat/damage, can spread only through bounded connected-component checks, and has strict lifetime/spread caps.

## Audio
Create machine mix layers based on active installed systems, not one global engine sound:
- combustion RPM,
- electric whine,
- wheel/track rolling,
- suspension impacts,
- prop/turbine/jet,
- servos/mechanisms,
- weapon cycling/reload,
- damaged rattles/alarms.

Distance/voice limits prevent 100-component builds from spawning 100 simultaneous audio emitters.

## Presentation mode
Workshop UI toggle hides UI/nodes/overlays, frames machine and runs a slow orbit. Any input exits immediately. Intended for screenshots/showcase, not gameplay automation.

---

# F. Hardening, Performance & Verification

## Performance budgets
- Catalog ViewportFrames render lazily/pooled where practical; off-screen cards can pause or reuse thumbnails.
- Node markers are distance/visibility culled.
- Engineering overlays use pooled adornments and capped vector counts.
- Track belts are cosmetic and do not create physical tread chains.
- Mechanism update rate is bounded; inactive Edit mechs do not simulate.
- Fire spread and exhaust damage use fixed capped query counts.

## Save migration
Blueprint schema increments. New optional fields:
- component orientation state,
- mechanism settings,
- symmetry is not persisted as a permanent relationship,
- utility control settings,
- selected ammo/default control bindings.

Old blueprints load with defaults. Migration never mutates catalog definitions.

## Static verification additions
Verifier must check:
- required Phase 2 modules exist,
- catalog has >=100 unique parts and required baseline IDs,
- StudBlock family exists,
- all `boxNodes` outward orientation source invariants,
- camera module uses Scriptable mode and restores state,
- BuildInput exposes camera/build action separation,
- MechanismService registered in Bootstrap,
- group mutations remain BuildService-owned,
- no Workspace mapping,
- no duplicate build/machine remote ownership,
- new blueprint schema migration hooks exist.

## Studio acceptance
1. Enter Build Mode: camera smoothly frames machine, avatar no longer centres view.
2. Orbit/pan/zoom/free-fly/precision/boost all work and F recovers machine.
3. Front/side/top views frame current machine.
4. Stud Block family places and snaps correctly.
5. Every side node faces outward; wheels mount outside chassis.
6. Long beam/plate expose multiple useful attachment points.
7. Smart snap chooses cursor-nearest node; candidate cycling works.
8. XYZ rotation produces predictable snap orientation.
9. Multi-select/group duplicate preserves graph/paint/inventory/undo.
10. Symmetry mode places both sides transactionally.
11. Wheel outer faces have no axle rods protruding; hubs/treads rotate correctly.
12. Suspension/caster/omni/track builds remain stable in Test.
13. Hinge/servo/piston/rotator/turret bearing respond to controls and stop in Edit.
14. Engine/reactor/propeller visual remasters match runtime behaviour.
15. Gearbox/turbo/afterburner materially affect resource tradeoffs.
16. Jet intake obstruction and exhaust danger work without self-damaging in Edit.
17. Wing/control-surface animations correspond to aero controls.
18. COM/lift/thrust overlays align sensibly with simple known builds.
19. Power/fuel/thermal overlays update without consuming resources.
20. Lights/camera block/rangefinder work and cannot inspect through walls.
21. Recoil/reload/turret visuals follow authoritative weapons.
22. Bomb rack and guided bomb damage only through server resolver.
23. Damage stages/fire appear and terminate without runaway spread.
24. Machine audio scales by installed system without audio spam.
25. Presentation mode cleanly enters/exits.
26. Blueprint save/load round-trips new settings and old blueprints still load.
27. Destroyed mechanisms/components clean up constraints/forces/overlays.
28. Full Output contains no unexplained GOD MACHINES errors.
29. CI verifier and official Luau compile pass on exact final head.
30. Workspace remains untouched by Rojo.

## Delivery policy
Each subproject lands as a separate commit series on `feat/masterpiece-phase-2`. Do not merge Phase 2 into PR #4. After all six are green, open a Phase 2 PR whose base is the eventual merged masterpiece branch/main as appropriate. Runtime Studio evidence is required before merge.
