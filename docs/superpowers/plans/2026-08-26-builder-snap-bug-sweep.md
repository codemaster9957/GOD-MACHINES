# Builder Snap Bug Sweep Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix node snapping so parts attach outside the target machine, make the server enforce the same source-node choice, and remove closely related builder bugs found during the audit.

**Architecture:** Keep `BuildMath` as the single source of truth for node compatibility and source-node selection. The client preview and server placement both call the same deterministic selector, while the node visualizer uses the selected definition to show only genuinely compatible free sockets as green. Keep placement server-authoritative and add source-level regression tests that run in the existing GitHub Actions verification job.

**Tech Stack:** Roblox Luau, Rojo source layout, Python 3.12 source-contract tests, GitHub Actions.

**Spec:** User-reported reproduction: selecting a chassis node with a wheel selected places the wheel into the machine, then authoritative clearance rejects it as a collision.

## Global Constraints

- Preserve the 100-part public catalogue.
- Preserve server-authoritative build mutations.
- Preview and authoritative placement must use the same node-selection rule.
- Mirroring must remain supported.
- Existing blueprint connection socket names must remain readable.

---

### Task 1: Lock down the snapping regression

**Files:**
- Create: `tests/builder_snap_source_spec.py`
- Modify: `.github/workflows/masterpiece-verify.yml`

**Interfaces:**
- Consumes: current `BuildMath`, `BuildPreview`, `BuildService`, `NodeVisualizer` sources.
- Produces: CI checks that fail until deterministic facing-aware source selection is wired through client and server.

- [ ] **Step 1: Write the failing source-contract test**

Assert that `BuildMath` exports `BestCompatibleSource`, `BuildPreview` calls it instead of returning the first compatible source node, `BuildService` calls it authoritatively, and `NodeVisualizer` accepts the selected definition for compatibility tinting.

- [ ] **Step 2: Run it to verify RED**

Run: `python tests/builder_snap_source_spec.py`
Expected: FAIL because `BestCompatibleSource` and selected-definition visualization do not exist yet.

- [ ] **Step 3: Add the test to CI**

Add `python tests/builder_snap_source_spec.py` to the repository-invariants job.

---

### Task 2: Make source-node selection deterministic and facing-aware

**Files:**
- Modify: `src/ReplicatedStorage/MechFramework/Shared/BuildMath.luau`
- Modify: `src/StarterPlayer/StarterPlayerScripts/GodMachinesBuilder/BuildPreview.luau`

**Interfaces:**
- Produces: `BuildMath.BestCompatibleSource(targetNode, sourceNodes) -> node?`.

- [ ] **Step 1: Implement `BestCompatibleSource` minimally**

Filter by `BuildMath.Compatible`, prefer the candidate whose local outward `LookVector` most strongly opposes the target node `LookVector`, then use stable name ordering as a deterministic tie-break.

- [ ] **Step 2: Replace the preview first-match loop**

For each nearest target attachment, call `BestCompatibleSource`; return the first target attachment that has a compatible best source.

- [ ] **Step 3: Verify the regression test progresses**

Run: `python tests/builder_snap_source_spec.py`.
Expected: client-side source-selection assertions pass; server/visualizer assertions remain RED.

---

### Task 3: Enforce the same rule on the server and clean failed first-place mechs

**Files:**
- Modify: `src/ServerScriptService/MechFramework/Services/BuildService.luau`

**Interfaces:**
- Consumes: `BuildMath.BestCompatibleSource`.
- Produces: authoritative source-node selection; no leaked empty build-origin mech after a rejected first placement.

- [ ] **Step 1: Recompute the source socket on the server**

For targeted placement, find the best compatible source from `BuildMath.AttachmentNodes(definition, mirrorX)` and use it for `Snap` and connection metadata rather than trusting an arbitrary client source socket.

- [ ] **Step 2: Clean up a newly-created empty mech on failed placement**

Track whether `_place` created the mech; on transform, collision, inventory, or add/attach failure before a valid component remains, destroy the empty build-origin mech.

- [ ] **Step 3: Verify source contract**

Run: `python tests/builder_snap_source_spec.py`.
Expected: server assertions pass.

---

### Task 4: Make node markers truthful

**Files:**
- Modify: `src/StarterPlayer/StarterPlayerScripts/GodMachinesBuilder/NodeVisualizer.luau`
- Modify: `src/StarterPlayer/StarterPlayerScripts/GodMachinesBuilder/BuildController.client.luau`

**Interfaces:**
- Produces: `NodeVisualizer:SetDefinition(definition, mirrorX)`; free but incompatible sockets render grey instead of green.

- [ ] **Step 1: Store selected definition on the visualizer**

Build target-node data from attachment attributes and call shared compatibility/source selection against the selected definition.

- [ ] **Step 2: Wire selection and mirroring state from the controller**

Update the visualizer whenever the part selection or mirror state changes.

- [ ] **Step 3: Verify source contract**

Run: `python tests/builder_snap_source_spec.py`.
Expected: PASS.

---

### Task 5: Full verification and merge readiness

**Files:**
- No production files unless verification exposes another reproducible fault.

- [ ] **Step 1: Run repository invariant tests**

Run: `python scripts/verify_masterpiece.py && python tests/structural_category_source_spec.py && python tests/builder_snap_source_spec.py && python scripts/test_100_improvements_contract.py && python scripts/test_combat_polish_contract.py`.
Expected: PASS.

- [ ] **Step 2: Run GitHub Actions Luau compile/behavior suite**

Open/update the PR to `main` and wait for `Masterpiece Verification` to complete.
Expected: all jobs PASS.

- [ ] **Step 3: Review the final diff**

Confirm no catalogue count changes, no unrelated feature rewrites, and client/server snap logic both call the same shared selector.
