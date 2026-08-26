# Builder Integrity Pass Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make preview validity and server placement clearance agree, while allowing blocked snap candidates to fall through to another compatible node.

**Architecture:** Put clearance query sizing in shared `BuildMath`. Let `BuildPreview` predict clearance with client-only exclusions and search compatible target sockets until it finds a clear snap. Keep `BuildService` authoritative and use the same shared query size while excluding only the requesting player's character.

**Tech Stack:** Roblox Luau, Rojo source layout, Python 3 source-contract regression tests, GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-08-26-builder-integrity-pass-design.md`

## Global Constraints

- Preserve the public 100-part catalogue.
- Preserve server-authoritative mutations.
- Preserve node compatibility, mirroring, rotation, undo/redo, duplicate, inventory, and blueprint behavior.
- Do not weaken collision checks against machine/world geometry.
- Do not modify combat, piloting, trading, or camera behavior.

---

### Task 1: Lock down preview/server clearance parity

**Files:**
- Create: `tests/builder_integrity_source_spec.py`
- Modify: `.github/workflows/masterpiece-verify.yml`

**Interfaces:**
- Consumes current `BuildMath`, `BuildPreview`, `BuildService`, and `BuildController` source.
- Produces a regression contract for shared clearance sizing, client prediction, blocked-node fallthrough, avatar exclusion, and blocked UI messaging.

- [ ] **Step 1: Write the failing source-contract test**

Require these source-level behaviors:

```python
checks = {
    "shared clearance sizing": ("src/ReplicatedStorage/MechFramework/Shared/BuildMath.luau", "function BuildMath.ClearanceSize"),
    "preview predicts clearance": ("src/StarterPlayer/StarterPlayerScripts/GodMachinesBuilder/BuildPreview.luau", "function BuildPreview:_hasClearance"),
    "preview exposes blocked state": ("src/StarterPlayer/StarterPlayerScripts/GodMachinesBuilder/BuildPreview.luau", 'self.LastState="BLOCKED"'),
    "server uses shared clearance sizing": ("src/ServerScriptService/MechFramework/Services/BuildService.luau", "BuildMath.ClearanceSize"),
    "controller explains blocked placement": ("src/StarterPlayer/StarterPlayerScripts/GodMachinesBuilder/BuildController.client.luau", 'state=="BLOCKED"'),
}
```

Also assert the preview does not immediately return a compatible pair before checking `_hasClearance(snapped)`, and assert the placement path supplies `player.Character` to `_clearance`.

- [ ] **Step 2: Run the test and verify RED**

Run: `python tests/builder_integrity_source_spec.py`
Expected: FAIL because the new shared helper and preview blocked state do not exist yet.

- [ ] **Step 3: Add the test to CI**

Add `python tests/builder_integrity_source_spec.py` to the repository-invariants job in `.github/workflows/masterpiece-verify.yml`.

---

### Task 2: Share clearance geometry and make preview truthful

**Files:**
- Modify: `src/ReplicatedStorage/MechFramework/Shared/BuildMath.luau`
- Modify: `src/StarterPlayer/StarterPlayerScripts/GodMachinesBuilder/BuildPreview.luau`

**Interfaces:**
- Produces `BuildMath.ClearanceSize(size: Vector3, inset: number?) -> Vector3`.
- Produces `BuildPreview:_hasClearance(transform: CFrame) -> boolean`.
- Changes `_findCompatiblePair` to return `(attachment, sourceNode, snappedTransform)` only for a clear snap.

- [ ] **Step 1: Implement shared query sizing**

```luau
function BuildMath.ClearanceSize(size: Vector3, inset: number?): Vector3
    local amount=math.max(0,tonumber(inset) or 0.08)
    return Vector3.new(
        math.max(0.01,size.X-amount),
        math.max(0.01,size.Y-amount),
        math.max(0.01,size.Z-amount)
    )
end
```

- [ ] **Step 2: Add preview exclusions and clearance helper**

Use `OverlapParams` excluding `self.Ghost`, `Players.LocalPlayer.Character`, and `workspace.GodMachinesNodeMarkers` when present. Query with `self.BuildMath.ClearanceSize(self.Definition.Size)`.

- [ ] **Step 3: Make snap search skip blocked candidates**

For each target socket in pointer-distance order, compute `snapped = BuildMath.Snap(...)`; only return the pair when `_hasClearance(snapped)` is true. Otherwise continue to the next compatible socket.

- [ ] **Step 4: Reject blocked free placement locally**

When there is no target component and no active mech, call `_hasClearance(self.PreviewCFrame)`. Set `LastState="BLOCKED"` when false; only use `FREE` when true.

- [ ] **Step 5: Run the integrity test**

Run: `python tests/builder_integrity_source_spec.py`
Expected: preview/shared assertions pass; server/controller assertions remain RED until Tasks 3-4.

---

### Task 3: Match authoritative clearance behavior

**Files:**
- Modify: `src/ServerScriptService/MechFramework/Services/BuildService.luau`

**Interfaces:**
- Consumes `BuildMath.ClearanceSize`.
- `_place` calls `_clearance(definition, transform, exclusions)` where exclusions contains the requesting player's character when present.

- [ ] **Step 1: Replace duplicated query sizing**

Use `BuildMath.ClearanceSize(definition.Size)` inside `_clearance`.

- [ ] **Step 2: Exclude the requesting avatar on placement**

Before authoritative clearance, build:

```luau
local exclusions={}
if player.Character then table.insert(exclusions,player.Character) end
```

Then call `_clearance(definition,transform,exclusions)`.

- [ ] **Step 3: Run the integrity test**

Run: `python tests/builder_integrity_source_spec.py`
Expected: all assertions except controller feedback pass.

---

### Task 4: Surface blocked placement clearly

**Files:**
- Modify: `src/StarterPlayer/StarterPlayerScripts/GodMachinesBuilder/BuildController.client.luau`

**Interfaces:**
- Consumes preview state `BLOCKED`.

- [ ] **Step 1: Map blocked placement in click feedback**

Add `BLOCKED="PLACEMENT BLOCKED"` to the readable reason table.

- [ ] **Step 2: Map blocked placement in live HUD feedback**

Add `elseif state=="BLOCKED" then ui:SetStatus("PLACEMENT BLOCKED", "bad")` to the RenderStepped status chain.

- [ ] **Step 3: Run the integrity test**

Run: `python tests/builder_integrity_source_spec.py`
Expected: PASS.

---

### Task 5: Full verification

**Files:**
- No production files unless verification exposes a reproducible regression.

**Interfaces:**
- Confirms builder changes preserve repository invariants.

- [ ] **Step 1: Run builder regression contracts**

Run: `python tests/builder_snap_source_spec.py && python tests/builder_integrity_source_spec.py`
Expected: PASS.

- [ ] **Step 2: Run repository invariants**

Run: `python scripts/verify_masterpiece.py && python tests/structural_category_source_spec.py && python scripts/test_100_improvements_contract.py && python scripts/test_combat_polish_contract.py`
Expected: PASS.

- [ ] **Step 3: Run CI / Luau compile verification**

Push the branch and verify `Masterpiece Verification` is green before merging.