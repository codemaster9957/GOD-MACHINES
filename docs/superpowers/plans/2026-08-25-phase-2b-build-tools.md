# Phase 2B Build Tools Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Expand the builder beyond the original 100-part fixed catalog with simple structural primitives, multi-node faces, deterministic smart snapping, XYZ orientation and symmetry/group foundations.

**Architecture:** Shared helpers define canonical nodes/orientation. Preview and server consume the same BuildMath. Catalog validation becomes expansion-safe. Group/symmetry mutations remain BuildService-owned and transactional; client modules own visuals and selection state only.

**Tech Stack:** Roblox Luau, existing PartCatalog/PartRenderer/BuildMath/BuildService, client builder modules, Python static verifier.

**Spec:** `docs/superpowers/specs/2026-08-25-phase-2b-build-tools-design.md`

## Global Constraints
- Catalog has >=100 unique IDs; required legacy and Phase 2 IDs must exist.
- Workspace remains Studio-owned.
- Build mutations remain server-authoritative/edit-only.
- Side nodes must point outward.
- Group/symmetry inventory effects are atomic.
- Existing blueprints continue to load.

---

### Task 1: Add RED Phase 2B invariants
- [ ] Require seven new structural IDs, expansion-safe catalog validation, node-grid helper, orientation helper, snap cycling, selection/symmetry modules, and BuildService group/symmetry action tokens in `scripts/verify_phase2.py`.
- [ ] Observe Phase 2 verifier fail before implementation.

### Task 2: Expand node/orientation shared helpers
**Files:** `PartDefinitionHelpers.luau`, `BuildMath.luau`
- [ ] Add `H.faceGridNodes`, `H.mergeNodes`, fixed outward face transforms and deterministic names.
- [ ] Add normalized `{X,Y,Z}` quarter-turn orientation helpers and `BuildMath.OrientationCFrame`.
- [ ] Preserve legacy numeric `Rotation` compatibility by mapping to Y quarter-turns.

### Task 3: Add structural prototyping family and expansion-safe catalog
**Files:** `Structural.luau`, `PartCatalog.luau`, `BuildController.client.luau`, `BuildUI.luau` only where count is hard-coded.
- [ ] Add StudBlock, HalfStudBlock, LongStudBeam, StructuralPlate, CornerBlock, TriangularBlock, RoundStructuralCell.
- [ ] LongStudBeam/StructuralPlate use multiple face nodes.
- [ ] Change exact-100 assertions to >=100 + required IDs.
- [ ] UI catalog count is derived from actual list length.

### Task 4: Smart snap + XYZ orientation
**Files:** `BuildPreview.luau`, `BuildInput.luau`, `BuildController.client.luau`, `BuildService.luau`
- [ ] Rank compatible target/source node pairs by cursor distance, facing, priority and deterministic name.
- [ ] Add `CycleSnap(direction)` and Tab/Shift+Tab routing.
- [ ] Add active rotation axis X/Y/Z and normalized orientation payload.
- [ ] Server validates/reconstructs orientation through BuildMath rather than trusting arbitrary client transform.

### Task 5: Selection and symmetry client foundations
**Files:** create `BuildSelection.luau`, `SymmetryPreview.luau`; integrate controller/input.
- [ ] Selection stores active-mech component IDs and renders client Highlights.
- [ ] Explicit selection tool toggle prevents placement ambiguity.
- [ ] Symmetry preview reflects placement around active machine local X plane.

### Task 6: Transactional server group/symmetry actions
**Files:** `BuildService.luau`
- [ ] Add GroupRemove and GroupDuplicate first, validating every ID before mutation and recording one history record.
- [ ] Add SymmetryPlace with double inventory preflight and full rollback.
- [ ] Add GroupMirror/GroupMove only for safe selections according to boundary rules.

### Task 7: GREEN verification
- [ ] Phase 2 verifier passes.
- [ ] Existing masterpiece verifier passes.
- [ ] Official Luau compilation passes.
- [ ] Diff review confirms no Workspace mapping or alternate mutation owner.
