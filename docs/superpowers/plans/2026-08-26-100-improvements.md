# GOD MACHINES 100 Improvements Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a feature-flagged, exactly-100-item polish pack that improves builder clarity, piloting, combat feedback, trading/quick-swap guidance, onboarding, accessibility, performance, immersion, reliability, and HUD quality without replacing authoritative gameplay systems.

**Architecture:** Add a shared declarative `PolishCatalog`, an optional server `PolishService`, and a self-starting client `ExperiencePolish` controller. The server validates and advertises the pack; the client owns display-only behavior and consumes existing replicated attributes/remotes defensively. Existing services remain authoritative.

**Tech Stack:** Roblox Luau, Rojo filesystem mapping, Python 3.12 contract tests, GitHub Actions, official Luau compiler.

**Spec:** `docs/superpowers/specs/2026-08-26-100-improvements-design.md`

## Global Constraints
- Exactly 100 enabled improvements with stable unique IDs.
- No persistence schema migration.
- No external assets or dependencies.
- No new client authority over gameplay state.
- Missing optional remotes/attributes/models must degrade safely.
- Reduced-motion behavior disables nonessential animation.
- The whole pack is disableable through a master feature flag.
- `PolishService` remains optional in bootstrap.

---

### Task 1: Add the failing 100-improvement contract

**Files:**
- Create: `scripts/test_100_improvements_contract.py`

**Interfaces:**
- Consumes: repository text files.
- Produces: executable contract that exits nonzero if pack count, IDs, integration, safety hooks, or CI wiring are wrong.

- [ ] **Step 1: Write the failing test**

Create a Python script that reads repository files and asserts:

```python
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
CATALOG = ROOT / "src/ReplicatedStorage/MechFramework/Shared/PolishCatalog.luau"
SERVER = ROOT / "src/ServerScriptService/MechFramework/Services/PolishService.luau"
CLIENT = ROOT / "src/StarterPlayer/StarterPlayerScripts/ExperiencePolish.client.luau"
BOOTSTRAP = ROOT / "src/ServerScriptService/MechFramework/Bootstrap.server.luau"
WORKFLOW = ROOT / ".github/workflows/masterpiece-verify.yml"

assert CATALOG.exists()
text = CATALOG.read_text()
ids = re.findall(r'Id\s*=\s*"([A-Z]\d\d)"', text)
assert len(ids) == 100
assert len(set(ids)) == 100
expected = [f"{prefix}{n:02d}" for prefix in "BVCTOAPWRQ" for n in range(1, 11)]
assert ids == expected
```

Then assert server/client/bootstrap/workflow markers described in the spec.

- [ ] **Step 2: Run the contract and verify it fails**

Run: `python scripts/test_100_improvements_contract.py`
Expected: FAIL because `PolishCatalog.luau` does not exist yet.

- [ ] **Step 3: Commit the failing contract**

```bash
git add scripts/test_100_improvements_contract.py
git commit -m "test: define 100-improvement polish contract"
```

---

### Task 2: Create the exact 100-item shared catalog

**Files:**
- Create: `src/ReplicatedStorage/MechFramework/Shared/PolishCatalog.luau`

**Interfaces:**
- Consumes: nothing beyond Luau.
- Produces: `Catalog.Version: string`, `Catalog.MasterEnabled: boolean`, `Catalog.Defaults: table`, `Catalog.Items: {PolishItem}`, `Catalog.ById: {[string]: PolishItem}`, `Catalog.IsEnabled(id): boolean`.

- [ ] **Step 1: Implement the catalog**

Use strict Luau and a helper that rejects duplicate IDs while building `ById`:

```lua
--!strict
export type PolishItem = { Id: string, Group: string, Name: string, Description: string, Scope: string, Enabled: boolean }
local Catalog = { Version = "2026.08.26-100", MasterEnabled = true, Defaults = { ReducedMotion=false, CameraMotion=true, ScreenFlash=true, Vignette=true, CrosshairScale=1, TextScale=1 }, Items = {}, ById = {} }
local function add(id: string, group: string, name: string, description: string, scope: string)
    assert(Catalog.ById[id] == nil, "duplicate polish id " .. id)
    local item = { Id=id, Group=group, Name=name, Description=description, Scope=scope, Enabled=true }
    table.insert(Catalog.Items, item)
    Catalog.ById[id] = item
end
```

Add B01–B10, V01–V10, C01–C10, T01–T10, O01–O10, A01–A10, P01–P10, W01–W10, R01–R10, Q01–Q10 in that exact order using the names/descriptions from the spec. Finish with `assert(#Catalog.Items == 100)` and `Catalog.IsEnabled`.

- [ ] **Step 2: Run the contract**

Run: `python scripts/test_100_improvements_contract.py`
Expected: still FAIL because server/client integration is not present, but count/order assertions pass.

- [ ] **Step 3: Commit**

```bash
git add src/ReplicatedStorage/MechFramework/Shared/PolishCatalog.luau
git commit -m "feat: add exact 100-item polish catalog"
```

---

### Task 3: Add resilient server readiness and preferences

**Files:**
- Create: `src/ServerScriptService/MechFramework/Services/PolishService.luau`
- Modify: `src/ServerScriptService/MechFramework/Bootstrap.server.luau`

**Interfaces:**
- Consumes: `ReplicatedStorage.MechFramework.Shared.PolishCatalog`.
- Produces: framework attributes `PolishPackVersion`, `PolishPackReady`, `PolishEnabledCount`; player attributes `PolishReducedMotion`, `PolishCameraMotion`, `PolishScreenFlash`, `PolishVignette`, `PolishCrosshairScale`, `PolishTextScale`, `PolishSessionStartedAt`.

- [ ] **Step 1: Implement `PolishService` validation**

The service must validate exactly 100 items and unique IDs before advertising readiness:

```lua
function Polish:Init(_container: any)
    local seen = {}
    assert(#Catalog.Items == 100, "PolishCatalog must contain exactly 100 items")
    for _, item in ipairs(Catalog.Items) do
        assert(type(item.Id) == "string" and item.Id:match("^[A-Z]%d%d$") ~= nil)
        assert(not seen[item.Id], "duplicate polish id " .. item.Id)
        seen[item.Id] = true
    end
    framework:SetAttribute("PolishPackVersion", Catalog.Version)
    framework:SetAttribute("PolishEnabledCount", #Catalog.Items)
end
```

- [ ] **Step 2: Seed safe player defaults in `Start`**

Use `Players.PlayerAdded` plus existing players. Only set a preference if it is currently `nil`, preserving Studio/test overrides.

- [ ] **Step 3: Register service only in `OPTIONAL_ORDER`**

Add `"PolishService"` after `NetworkService` in the optional list. Do not add it to `CORE_ORDER` or `MACHINE_REQUIRED`.

- [ ] **Step 4: Re-run contract**

Run: `python scripts/test_100_improvements_contract.py`
Expected: catalog/server/bootstrap assertions pass; client/workflow assertions still fail.

- [ ] **Step 5: Commit**

```bash
git add src/ServerScriptService/MechFramework/Services/PolishService.luau src/ServerScriptService/MechFramework/Bootstrap.server.luau
git commit -m "feat: publish resilient polish readiness"
```

---

### Task 4: Implement the client 100-point polish controller

**Files:**
- Create: `src/StarterPlayer/StarterPlayerScripts/ExperiencePolish.client.luau`

**Interfaces:**
- Consumes: `PolishCatalog`, player attributes, `workspace.MechAssemblies`, optional `CombatFeedback`, viewport/camera/input state.
- Produces: local `GodMachinesPolishHUD` ScreenGui and display-only feedback. Writes no authoritative mech/gameplay state.

- [ ] **Step 1: Create reusable primitives once**

Build `ScreenGui`, top-left mode/name chips, top-center warning label, bottom-center telemetry row, center reticle, edge vignette, help label, slot row, and onboarding label. Set `ResetOnSpawn=false`, `IgnoreGuiInset=false`, and stable `DisplayOrder`.

- [ ] **Step 2: Add tracked connections and cleanup**

Use `connections: {RBXScriptConnection}` plus a `track(connection)` helper. On `script.Destroying`, disconnect all connections, clear input state, and destroy the HUD.

- [ ] **Step 3: Add lazy active-mech resolution**

Resolve `player:GetAttribute("ActiveMechId")` only on attribute changes and a bounded retry interval. Find only `workspace.MechAssemblies/<id>`; never scan all descendants each frame.

- [ ] **Step 4: Add telemetry at a capped update rate**

At 10 Hz, read `AssemblyLinearVelocity` from `PrimaryPart`/first BasePart, calculate horizontal speed, vertical speed, heading, airborne raycast, motion state, and optional fuel/heat/health/power attributes. Update existing labels rather than creating instances.

- [ ] **Step 5: Add builder status and contextual legend**

Use `BuildMode`, active model attributes, and input type to populate B01–B10. Hide piloting telemetry while building except critical warnings.

- [ ] **Step 6: Add combat reticle behavior**

Bind mouse buttons/R locally for presentation only. Expand bloom ring on primary, distinct pulse on secondary, show reload label on R, smooth aim FOV only when `PolishCameraMotion` is true, and restore FOV on release/mech/mode cleanup.

- [ ] **Step 7: Add optional `CombatFeedback` hook**

Find the RemoteEvent with `FindFirstChild`. Validate payload type before reading fields. Handle display-only fields such as `Kind`, `Message`, `Hit`, and `Reason`; ignore unknown payloads.

- [ ] **Step 8: Add warning queue and onboarding state machine**

Use a maximum queue length of 6. Suppress duplicate text by refreshing expiry. Priority order: critical machine/trade/combat > engineering warning > onboarding > help. Session onboarding tracks first build/part/test/drive/fire in local booleans and never spams more often than the cooldown.

- [ ] **Step 9: Add accessibility/comfort controls**

Read player preference attributes for reduced motion, camera motion, screen flash, vignette, crosshair scale, and text scale. Clamp scales to safe ranges. Use text/symbols such as `!`, arrows, and state words so color is never the only signal.

- [ ] **Step 10: Add HUD QoL toggles**

F10 toggles cinematic hide. H toggles compact mode. Both must preserve critical warnings. Show a concise help hint describing these controls.

- [ ] **Step 11: Run syntax + contract checks**

Run:
```bash
luau-compile src/StarterPlayer/StarterPlayerScripts/ExperiencePolish.client.luau
python scripts/test_100_improvements_contract.py
```
Expected: client checks pass; workflow check may remain until Task 5.

- [ ] **Step 12: Commit**

```bash
git add src/StarterPlayer/StarterPlayerScripts/ExperiencePolish.client.luau
git commit -m "feat: add 100-point client polish controller"
```

---

### Task 5: Wire CI and verify the complete pack

**Files:**
- Modify: `.github/workflows/masterpiece-verify.yml`

**Interfaces:**
- Consumes: `scripts/test_100_improvements_contract.py`.
- Produces: pull-request CI gate for the 100-improvement pack.

- [ ] **Step 1: Add the contract step to `repository-invariants`**

Immediately after `Verify GOD MACHINES architecture`, add:

```yaml
      - name: Verify 100-improvement polish contract
        run: python scripts/test_100_improvements_contract.py
```

- [ ] **Step 2: Run repository verification**

Run:
```bash
python scripts/verify_masterpiece.py
python scripts/test_combat_polish_contract.py
python scripts/test_100_improvements_contract.py
```
Expected: all PASS.

- [ ] **Step 3: Compile all Luau**

Run the workflow-equivalent `find src tests -type f -name '*.luau'` loop through official `luau-compile`.
Expected: zero syntax failures.

- [ ] **Step 4: Run behavior specs**

Run:
```bash
luau tests/quick_swap_spec.luau
luau tests/vehicle_trade_spec.luau
```
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add .github/workflows/masterpiece-verify.yml
git commit -m "ci: verify 100-improvement polish pack"
```

- [ ] **Step 6: Open PR and inspect CI**

Open `feature/100-improvements` into `main`, inspect workflow runs, fix any red checks, and merge only after the branch is green.