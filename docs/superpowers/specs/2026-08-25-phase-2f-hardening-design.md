# Phase 2F — Hardening, Migration, Performance & Verification Design

**Parent:** `2026-08-25-masterpiece-phase-2-design.md`

## Goal
Make Phase 2 shippable rather than merely impressive in a test place. This workstream owns bug sweeps, migrations, performance limits, cleanup guarantees and verification evidence.

## Files
Modify broadly as bugs prove necessary, with expected focus on:
- `scripts/verify_masterpiece.py`
- `.github/workflows/masterpiece-verify.yml`
- `Bootstrap.server.luau`
- `BuildService.luau`
- `SaveService.luau`
- `PilotService.luau`
- `ControlService.luau`
- `MatchService.luau`
- `DestructionService.luau`
- client builder modules

Create optional diagnostic modules only when they reduce duplication; do not invent a generic abstraction during the bug sweep without evidence.

## Blueprint schema
Increment schema version. Phase 2 design persistence may include:
- normalized XYZ orientation state
- mirror state
- paint
- mechanism configuration
- utility defaults
- ammo selection
- custom bindings
- deterministic PrimaryComponentId/source mapping

Do not persist:
- velocity
- current throttle
- current heat unless current save design intentionally includes an edit-time static setting
- occupants
- transient fire/damage effects
- camera state
- selection state
- symmetry tool state
- Test-mode constraint runtime state

## Migration
Old schema defaults:
- old quarter-turn rotation maps to Y-axis orientation
- missing mechanism settings use catalog defaults
- missing utility settings default Off/Auto as appropriate
- missing ammo type uses preset default
- old component GUID mapping continues to remap bindings through blueprint source IDs

Decode/migration failure must release profile locks as current SaveService hardening requires.

## Runtime cleanup contracts
Every service that creates runtime objects registers cleanup by mech/component:
- constraints
- forces
- attachments created at runtime
- particles/lights/sounds
- overlays are client-owned and cleaned on workshop exit
- projectile guidance trackers
- fire states
- mechanism states

Destroying a mech must leave no service table entry that continues ticking it.

## Edit/Test boundary
Returning to Edit must:
- zero propulsion/vehicle/mechanism forces
- disable exhaust/fire hazards that are Test-only unless fire is intentionally a persisted damage state (workshop machines normally return repaired/static according to current mode policy)
- stop held control actions
- eject seats
- anchor/stabilize realization
- freeze resource simulation

Entering Test must:
- realize required constraints safely
- prime power/fuel/heat topology
- clear stale control state
- then unanchor/enable simulation

## Performance budgets
The game has no arbitrary design-piece cap, but client/server subsystems must degrade gracefully:

Catalog UI:
- avoid continuously animating 100+ ViewportFrames
- thumbnail render can be static after creation
- optional lazy render visible cards first

Nodes:
- cull distant markers
- cap simultaneous visible normals/arrows

Engineering overlays:
- cap thrust arrows/topology lines
- update at low frequency compared with render frame

Mechanisms:
- server update at bounded heartbeat interval or shared heartbeat with cheap per-component math
- inactive Edit mechs not simulated

Audio:
- aggregate/cap loop layers per machine

Damage/fire:
- capped per-mech spread/query checks

Exhaust/intake:
- bounded probing, not one expensive overlap/raycast per jet every render frame

Tracks:
- cosmetic belt, no physical chain-link explosion

## Security / authority sweep
Verify:
- all construction mutations owned by BuildService
- all pilot/machine mode actions owned by PilotService
- damage/weapon/projectile decisions server-side
- camera/rangefinder cannot request arbitrary foreign mech data
- group operations validate every component ID
- blueprint workshop deployment consumes inventory
- battle/PvE temporary deployment cannot refund temporary pieces into inventory
- symmetry/group duplicate cannot duplicate unique inventory receipts

## Static verifier expansion
Add explicit checks for:
- WorkshopCamera file and controller wiring
- required Phase 2 part IDs
- catalog >=100, not exact 100
- UI displays dynamic catalog count
- outward side-node rotations
- BuildMath orientation API
- BuildSelection/SymmetryPreview modules
- MechanismService registration
- required mechanism IDs
- required power/cooling IDs
- FireService registration if implemented as a service
- camera block/rangefinder definitions
- new blueprint schema/migration token
- no Workspace mapping
- no old `local PARTS` client catalog
- no duplicate RequestBuildAction/RequestMachineAction ownership

## CI
Keep two independent gates:
1. repository invariants
2. official Luau compiler over every `.luau`

Add additional pure-Python structural tests where possible, but do not claim they prove Roblox runtime physics.

## Bug-fix workflow
For every runtime error:
1. capture first/root Output error
2. trace cascade separately
3. patch smallest root boundary
4. add regression invariant if static-detectable
5. rerun CI
6. rerun Studio reproduction

## Studio acceptance matrix
Run at least these machine archetypes:
- tiny 4-wheel car
- heavy 4/6-wheel vehicle
- omni vehicle
- tracked vehicle
- propeller aircraft
- jet aircraft
- rocket/hover craft
- articulated hinge/servo/piston machine
- turreted weapon platform
- power-starved machine
- fuel-starved machine
- heat-overloaded machine
- large mixed machine with damage/destruction

For each, inspect Output for client + server errors.

## Merge gate
Phase 2 may only merge when:
- exact final commit has green CI
- PR is mergeable
- Studio acceptance results have no unexplained framework errors
- camera restores correctly
- builder survives empty-machine/undo/blueprint edge cases
- no known inventory duplication exploit
- no known permanent simulation leak after Edit/destroy/player leave

Any known physics tuning imperfection may be documented only if it does not break core functionality, exploit economy/combat, or produce persistent errors.
