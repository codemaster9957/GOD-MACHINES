# Gundam Mech Weapons Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Repair the empty weapon-control pipeline and ship eleven distinct, buildable humanoid-mech weapons with server-authoritative combat.

**Architecture:** A shared `WeaponCatalog` is the single source of truth for weapon part, collection, combat, mount and visual metadata. `PartRegistry`, `CollectionDefinitions`, inventory seeding and the builder consume that catalogue. `ControlBindingPolicy` derives safe default Primary/Secondary groups from live mech components, while `ControlService` reconciles those groups before dispatch.

**Tech Stack:** Roblox Luau, Rojo JSON project mapping, Roblox services/remotes.

**Spec:** `docs/superpowers/specs/2026-08-26-gundam-mech-weapons-design.md`

## Global Constraints

- Preserve server-authoritative damage, cooldown, ammunition, power, heat, ownership and aim validation.
- Preserve the existing Autocannon ID and behaviour compatibility.
- Do not copy protected Gundam character/model designs; use original GOD-MACHINES silhouettes.
- Keep weapon behaviour data-driven.
- Work only on `feat/gundam-weapon-system`.

---

### Task 1: Failing catalogue and binding specifications

**Files:**
- Create: `src/ServerScriptService/MechFramework/Tests/WeaponSystemTests.server.luau`

**Interfaces:**
- Consumes: future `Shared.WeaponCatalog` and `Shared.ControlBindingPolicy`.
- Produces: Studio assertions covering catalogue validity and default group derivation.

- [ ] **Step 1: Add failing Studio assertions**

Create assertions that require exactly eleven unique weapon IDs, require every resolved combat record to have positive damage/range/fire rate, require physical size/mass/health, and require a sample live component map to produce Autocannon in Primary, RailCannon in Secondary, and exclude destroyed/non-combat components.

- [ ] **Step 2: Verify the tests are red**

Run the synced place in Roblox Studio with `FrameworkConfig.Debug=true`. Expected before implementation: the test script fails while requiring missing `WeaponCatalog` or `ControlBindingPolicy`.

### Task 2: Shared weapon catalogue

**Files:**
- Create: `src/ReplicatedStorage/MechFramework/Shared/WeaponCatalog.luau`
- Modify: `src/ReplicatedStorage/MechFramework/Shared/WeaponDefinitions.luau`
- Modify: `src/ReplicatedStorage/MechFramework/Shared/CollectionDefinitions.luau`
- Modify: `src/ServerScriptService/MechFramework/Services/PartRegistry.luau`

**Interfaces:**
- Produces: `WeaponCatalog.Ordered`, `WeaponCatalog.ById`, and immutable records with `Id`, `DisplayName`, `ShortName`, `DefaultAction`, `MountRole`, `Size`, `Mass`, `MaxHealth`, `Power`, `Heat`, `Combat`, `Collection`, and `Visual`.
- Consumes: `WeaponDefinitions.Resolve(config)`.

- [ ] **Step 1: Implement eleven original weapon records**

Add Autocannon, BeamRifle, BeamSaber, HeadVulcan, ShoulderMissilePod, ChestCannon, ArmGatling, RailCannon, PlasmaShotgun, RocketFist and ShoulderBeamCannon with hand-balanced server statistics.

- [ ] **Step 2: Extend delivery presets only where needed**

Add BeamSaber and RocketFist-compatible presets/config fields without branching combat code by weapon ID.

- [ ] **Step 3: Register catalogue records**

Generate physical registry definitions from catalogue records and add matching collection definitions, preserving current structural parts and Autocannon compatibility.

- [ ] **Step 4: Re-run Studio assertions**

Expected: catalogue assertions pass; binding assertions still fail because the policy is not implemented.

### Task 3: Default binding policy and runtime reconciliation

**Files:**
- Create: `src/ReplicatedStorage/MechFramework/Shared/ControlBindingPolicy.luau`
- Modify: `src/ServerScriptService/MechFramework/Services/ControlService.luau`
- Modify: `src/ServerScriptService/MechFramework/Services/CombatService.luau`

**Interfaces:**
- Produces: `ControlBindingPolicy.Derive(components) -> {[string]: {string}}`.
- Produces: `ControlService:ReconcileBindings(userId, mechId)`.
- Consumes: component `Combat.DefaultAction` and existing explicit groups.

- [ ] **Step 1: Implement deterministic derivation**

Sort component IDs, include only live components with combat data, and assign each to validated Primary/Secondary action names.

- [ ] **Step 2: Reconcile before activation**

Have `ControlService` derive groups when a mech has no explicit binding or its revision changed. Preserve validated explicit bindings.

- [ ] **Step 3: Isolate weapon runtime state**

Key cooldown and ammunition by `mechId .. ":" .. weaponId`; validate requested aim is finite and normalized before use.

- [ ] **Step 4: Re-run Studio assertions**

Expected: all catalogue and binding assertions pass.

### Task 4: Builder and inventory integration

**Files:**
- Modify: `src/ServerScriptService/MechFramework/Services/InventoryService.luau`
- Modify: `src/StarterPlayer/StarterPlayerScripts/GodMachinesBuilder/BuildController.client.luau`
- Modify: `src/StarterPlayer/StarterPlayerScripts/GodMachinesBuilder/BuildUI.luau`
- Modify: `src/ServerScriptService/MechFramework/Services/BuildService.luau`

**Interfaces:**
- Consumes: `WeaponCatalog.Ordered`.
- Produces: weapon entries in the part inventory and distinct realized visual profiles.

- [ ] **Step 1: Seed weapon inventory in Studio**

Derive debug weapon grants from the shared catalogue instead of maintaining a second hard-coded list.

- [ ] **Step 2: Build the client catalogue**

Append all shared weapon menu entries after StructuralFrame and SmallReactor. Keep number-key slots for the first nine entries and make every remaining weapon clickable in the scrolling inventory.

- [ ] **Step 3: Make the inventory scroll**

Use a `ScrollingFrame` with automatic canvas sizing; only create a hotbar button when a part has a numeric slot.

- [ ] **Step 4: Realize distinct weapon visuals**

Use registry `Visual` metadata for material, base colour, accent colour, shape and muzzle placement while retaining component attributes and attachment nodes.

### Task 5: Combat feedback and visible shots

**Files:**
- Modify: `src/ServerScriptService/MechFramework/Services/ProjectileService.luau`
- Modify: `src/ServerScriptService/MechFramework/Services/CombatService.luau`
- Create: `src/StarterPlayer/StarterPlayerScripts/WeaponEffects.client.luau`

**Interfaces:**
- Produces: server `CombatFeedback` packets with `Kind`, `Origin`, `Direction`, `Range`, `Mode`, `Color`, `WeaponId`, and optional `Position`.
- Consumes: the existing `CombatFeedback` RemoteEvent.

- [ ] **Step 1: Emit accepted-shot feedback**

After server validation and projectile acceptance, broadcast sanitized visual data only.

- [ ] **Step 2: Emit impact feedback**

Broadcast impact positions from server raycasts and projectile collisions.

- [ ] **Step 3: Render short-lived effects**

Create local neon tracers/beams, muzzle flashes and impact spheres with Debris cleanup. Never calculate or send damage from this script.

### Task 6: Verification and pull request

**Files:**
- Review all modified files.

- [ ] **Step 1: Static validation**

Verify every catalogue ID occurs in registry/collection/builder paths through shared iteration, inspect strict Luau types, and confirm all required remotes exist in `default.project.json`.

- [ ] **Step 2: Studio smoke test**

Build a powered mech, mount Primary and Secondary weapons, exit build mode, fire LMB/RMB, and verify damage, heat, power, ammunition, recoil and VFX. Record any runtime errors exactly.

- [ ] **Step 3: Regression check**

Confirm StructuralFrame, SmallReactor, Autocannon placement, undo/redo, removal and inventory refund still work.

- [ ] **Step 4: Open PR**

Open a PR from `feat/gundam-weapon-system` into `main` with test evidence and any remaining Studio-only verification note.
