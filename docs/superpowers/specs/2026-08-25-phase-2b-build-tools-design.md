# Phase 2B — Build Geometry, Nodes, Selection & Symmetry Design

**Parent:** `2026-08-25-masterpiece-phase-2-design.md`

## Goal
Make construction fast, predictable and expressive enough for large machines without hiding engineering constraints.

## Files
Create:
- `GodMachinesBuilder/BuildSelection.luau`
- `GodMachinesBuilder/SymmetryPreview.luau`

Modify:
- `PartDefinitionHelpers.luau`
- `PartDefinitions/Structural.luau`
- `PartCatalog.luau`
- `BuildMath.luau`
- `BuildPreview.luau`
- `NodeVisualizer.luau`
- `BuildController.client.luau`
- `BuildInput.luau`
- `BuildUI.luau`
- `BuildService.luau`
- `scripts/verify_masterpiece.py`

## New structural parts
Required IDs:
- `StudBlock` — 2x2x2 simple cube, six face nodes, neutral starter visual.
- `HalfStudBlock` — 2x1x2.
- `LongStudBeam` — 2x2x6 with repeated face nodes.
- `StructuralPlate` — 4x0.5x4.
- `CornerBlock` — L-profile.
- `TriangularBlock` — wedge/truss hybrid.
- `RoundStructuralCell` — cylindrical hub.

These are intentionally simpler than showcase parts and exist to make prototyping easy.

## Catalog policy change
Old invariant `exactly 100 parts` becomes:
- at least 100 unique definitions,
- all legacy baseline IDs required,
- all Phase 2 required IDs required,
- category minimums enforced,
- duplicate IDs/display-name collisions rejected.

The UI must show the real catalog count, never hard-code “100 components”.

## Node helper API
Add helpers:
- `H.faceGridNodes(size, face, rows, columns, nodeType?, accepts?, prefix?)`
- `H.mergeNodes(...)`
- `H.offsetNode(...)` if useful

Face conventions are fixed:
- Top normal +Y
- Bottom normal -Y
- Left normal -X
- Right normal +X
- Front normal -Z
- Back normal +Z

Transforms must orient source local forward consistently so `BuildMath.Snap` produces outward placement.

## Node visualization
Marker states stay green/amber/grey but add a small directional stem/arrow for the currently nearest compatible node. Marker geometry is client-only and non-queryable.

Distance culling:
- only active mech
- only within a camera-scaled radius
- always show currently targeted node

## Snap ranking
Candidate score combines:
1. compatible pair required,
2. cursor-to-target-node distance,
3. camera-facing usefulness,
4. node `Priority`,
5. deterministic name tie-breaker.

Client exposes `CycleSnap(+1/-1)` while cursor remains in same neighborhood.

## Orientation model
Replace `Turns` with normalized orientation state:
- local quarter-turn X
- local quarter-turn Y
- local quarter-turn Z

`R` applies +90° around selected axis. Axis defaults to Y for compatibility. UI strip can switch X/Y/Z. BuildMath composes rotations deterministically and mirrors after/before orientation according to one documented order used by preview and server.

## Selection
`BuildSelection` stores selected component IDs only for active mech. Visuals use SelectionBox/Highlight client-side.

Input:
- Shift+LMB component = toggle selection
- drag from empty screen region = box select
- Escape = clear
- Ctrl+A = select active mech, capped by safe client display count

Normal LMB placement still takes precedence while a ghost is in valid placement state; selection uses an explicit selection tool state to avoid ambiguity.

## Group server actions
Add BuildService actions:
- `GroupDuplicate`
- `GroupMirror`
- `GroupRemove`
- `GroupMove` (restricted)

Every action:
- validates same owner/mech/edit state,
- validates all IDs before mutation,
- performs inventory preflight,
- applies or rolls back atomically,
- records one undo record,
- preserves paint/mirror/settings/internal connections.

## Group move rule
Phase 2 only moves a selection that forms a disconnected/free subassembly OR whose external boundary connections are explicitly severed by the operation. Do not silently stretch graph edges.

## Symmetry
Client symmetry plane defaults to machine-local X=0. Optional Y/Z later through UI.

Placement request includes a symmetry descriptor, but server computes mirrored transform itself from authoritative machine frame and validates both placements. Centre-plane pieces do not duplicate if mirrored transform is equivalent within epsilon.

Both inventory items and both clearances are required before any placement commits.

## Undo/redo
Group and symmetry actions are single transactions. Redo must revalidate inventory/space where needed or replay from stored authoritative snapshot according to current BuildService history model.

## Acceptance
- StudBlock appears, paints, duplicates, mirrors and blueprints correctly.
- side nodes face outward.
- wheel can attach to left and right faces without entering chassis.
- LongStudBeam has useful intermediate nodes.
- candidate cycling is deterministic.
- XYZ rotation matches preview/server.
- group duplicate preserves internal graph.
- symmetry uses two inventory items and rolls back both on failure.
- removing/undoing grouped pieces restores exact unique-item receipts.
