# GOD MACHINES Masterpiece Builder V2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the current three-part builder into a polished 100-part machine construction sandbox with shared procedural visuals, painting, engineering stats, blueprints, seats, wheels, propulsion, flight surfaces, and automatic/custom controls.

**Architecture:** A single shared `PartCatalog` owns public part definitions and recipes. A shared `PartRenderer` creates identical runtime and preview visuals. Server services remain authoritative for inventory, build transactions, painting, physics behavior, piloting, controls, power/heat and blueprints. Existing services are extended only where they already own that responsibility; vehicle-specific behavior lives in focused new services.

**Tech Stack:** Roblox Luau, Rojo, Roblox constraints/forces, GitHub branch workflow.

**Spec:** `docs/superpowers/specs/2026-08-25-god-machines-masterpiece-design.md`

## Global Constraints
- 100 total build pieces, including upgraded StructuralFrame, SmallReactor and Autocannon.
- Each catalog entry must have a distinct procedural silhouette and gameplay role.
- No arbitrary hard part-count limit.
- Server authority for all state-changing actions.
- Existing working builder must remain usable throughout the migration.
- Workspace is not Rojo-managed; all generated machine content stays runtime-only under `Workspace.MechAssemblies`.
- Build mode and Studio test inventory must remain independent from optional service failures.

---

### Task 1: Shared catalog and renderer foundation

**Files:**
- Create: `src/ReplicatedStorage/MechFramework/Shared/PartCatalog.luau`
- Create: `src/ReplicatedStorage/MechFramework/Shared/PartRenderer.luau`
- Modify: `src/ServerScriptService/MechFramework/Services/PartRegistry.luau`

**Interfaces:**
- `PartCatalog.Get(id) -> definition?`
- `PartCatalog.GetAll() -> {[string]: definition}`
- `PartCatalog.GetList() -> {definition}`
- `PartRenderer.Render(definition, options) -> Model, BasePart`
- `PartRenderer.ApplyPaint(model, paint)`

- [ ] Define and validate a 100-entry catalog grouped across Structural, Armour, Mobility, Propulsion, Aerodynamics, PowerCooling, Control, Weapons and Utility.
- [ ] Ensure every entry has unique `Id`, display metadata, bounds, mass, health, six-or-purposeful attachment nodes, geometry recipe and paint regions.
- [ ] Implement deterministic primitive recipe rendering for block, wedge, corner wedge, cylinder, ball, seat, glass, blade/radial and repeated details.
- [ ] Make preview/runtime modes share the same recipe and differ only in collision/transparency/query behavior.
- [ ] Replace hardcoded `PartRegistry:Init()` definitions with catalog registration and validation.
- [ ] Verify registry count is exactly 100 and reject malformed nodes/recipes at startup.

### Task 2: Inventory/catalog unification and Studio development stock

**Files:**
- Modify: `src/ServerScriptService/MechFramework/Services/InventoryService.luau`
- Modify: `src/ReplicatedStorage/MechFramework/Shared/CollectionDefinitions.luau`
- Modify: `src/ServerScriptService/MechFramework/Services/ProgressionService.luau` only if required by catalog-backed grants.

**Interfaces:**
- `Inventory:Init(container)` obtains `PartRegistry`.
- `Inventory:GetPartMetadata(partType)` provides rarity/stack/durability defaults without duplicating the buildable-ID allowlist.
- Studio debug seed grants every catalog part in a finite but generous quantity.

- [ ] Remove `CollectionDefinitions.Parts` as the authoritative buildable allowlist while preserving collection rarity/crafting metadata.
- [ ] Make grant/restore/consume transactions validate part IDs against PartRegistry.
- [ ] Make `Consume` transactional: preflight total availability before mutating stacks or unique items.
- [ ] Seed all 100 parts in Studio debug sessions before BuilderServerReady.
- [ ] Verify production save paths never auto-grant catalog parts.

### Task 3: Build realization, painting and snapshots

**Files:**
- Modify: `src/ServerScriptService/MechFramework/Services/MechService.luau`
- Modify: `src/ServerScriptService/MechFramework/Services/BuildService.luau`
- Modify: `src/StarterPlayer/StarterPlayerScripts/GodMachinesBuilder/BuildPreview.luau`

**Interfaces:**
- component metadata includes `Paint = {Primary, Secondary, Accent, Material?}`.
- Build action `Paint` accepts `MechId`, `ComponentId`, `Region`, `Color` and optional `Material`.
- Build action `Duplicate` clones a selected component through a normal inventory-checked placement path.
- `PartRenderer.Render` replaces rectangular runtime and preview placeholders.

- [ ] Render each server component with shared PartRenderer and put identity/attachments on the canonical root.
- [ ] Render ghosts with the same shared recipe and highlight valid/invalid states without destroying per-region color distinction.
- [ ] Persist paint in snapshots, undo/redo and blueprint spawn.
- [ ] Add server-authoritative paint validation (owner, component, allowed region, Color3, material allowlist).
- [ ] Make clearance ignore decorative recipe geometry and operate on canonical bounds.
- [ ] Preserve configured component mass on canonical roots only.

### Task 4: Catalog-driven builder UI and tools

**Files:**
- Modify: `src/StarterPlayer/StarterPlayerScripts/GodMachinesBuilder/BuildController.client.luau`
- Modify: `src/StarterPlayer/StarterPlayerScripts/GodMachinesBuilder/BuildInput.luau`
- Replace/refactor: `src/StarterPlayer/StarterPlayerScripts/GodMachinesBuilder/BuildUI.luau`

**Interfaces:**
- UI consumes `PartCatalog.GetList()` directly for public metadata.
- callbacks: SelectPart, Search, Category, Paint, TestMode, Duplicate, Remove, Undo, Redo, Rotate, Mirror, SaveBlueprint.

- [ ] Remove hardcoded three-part client catalog.
- [ ] Build searchable scrolling catalog with category tabs, favorites and 1-9 hotbar favorites.
- [ ] Add inspector with mass, health, power, heat, behavior and description.
- [ ] Add paint panel with primary/secondary/accent swatches plus validated hex input.
- [ ] Add visible attachment-node overlay and selected-node feedback.
- [ ] Add duplicate/mirror controls and clear keyboard hints.
- [ ] Add live engineering summary panel fed from server snapshots/attributes.
- [ ] Add Test Machine/Edit Machine mode button.

### Task 5: Pilot authority and automatic controls

**Files:**
- Create: `src/ServerScriptService/MechFramework/Services/PilotService.luau`
- Modify: `src/ServerScriptService/MechFramework/Services/ControlService.luau`
- Modify: `src/StarterPlayer/StarterPlayerScripts/WeaponController.client.luau`
- Modify: `src/ServerScriptService/MechFramework/Bootstrap.server.luau`

**Interfaces:**
- `PilotService:SetTestMode(player, mechId, enabled)` stabilizes/unanchors a machine and manages occupancy.
- `PilotService:GetPilot(mechId)`.
- `ControlService:GenerateDefaultBindings(userId, mechId)` maps catalog behavior tags into actions.

- [ ] Real seats/cockpits become usable only outside edit mode.
- [ ] Seat occupancy grants control only to the owner/authorized pilot.
- [ ] Exiting seat or edit/test transition clears every held action.
- [ ] Generate sensible car/aircraft/hover/weapon bindings automatically.
- [ ] Preserve custom binding groups over regenerated defaults where explicitly overridden.

### Task 6: Vehicle, propulsion and aerodynamic behavior

**Files:**
- Create: `src/ServerScriptService/MechFramework/Services/VehicleService.luau`
- Create: `src/ServerScriptService/MechFramework/Services/PropulsionService.luau`
- Create: `src/ServerScriptService/MechFramework/Services/AerodynamicsService.luau`
- Modify: `src/ServerScriptService/MechFramework/Bootstrap.server.luau`
- Modify: `src/ServerScriptService/MechFramework/Services/BuildService.luau` for behavior realization hooks.

**Interfaces:**
- services read canonical component behavior tables and `Metadata.ControlState`.
- services use model roots/behavior attachments created by PartRenderer.
- power-dependent devices respect `Metadata.PowerFraction`.

- [ ] Wheels use real hinge/steering constraints or force-based fallback with mass-aware torque.
- [ ] Suspension variants use spring/damping constraints.
- [ ] Engines/motors generate drivetrain output and heat; electric devices scale with available power.
- [ ] Jets/rockets/propellers/vector thrusters apply force at their mounted location and produce torque naturally.
- [ ] Propeller/turbine visuals animate from throttle.
- [ ] Wings generate bounded arcade lift/drag from relative air velocity and orientation.
- [ ] Elevators/rudders/ailerons/airbrakes alter pitch/yaw/roll/drag through control state.
- [ ] Test/Edit transitions safely anchor/unanchor and zero active thrust.

### Task 7: Stats, blueprints and persistence

**Files:**
- Modify: `src/ServerScriptService/MechFramework/Services/NetworkService.luau`
- Modify: `src/ServerScriptService/MechFramework/Services/SaveService.luau`
- Modify: `src/ServerScriptService/MechFramework/Services/PhysicsService.luau`
- Modify: `src/StarterPlayer/StarterPlayerScripts/GodMachinesBuilder/BuildController.client.luau`

**Interfaces:**
- mech snapshot includes computed engineering summary: Mass, PartCount, PowerGeneration, PowerDemand, HeatGeneration, LiftArea, DriveTorque, Thrust, Seats, Weapons.
- blueprint records include component paint and custom control bindings.

- [ ] Expose concise engineering stats without sending internal server-only state.
- [ ] Save/load named blueprints and paint metadata.
- [ ] Keep Studio local save behavior and production session-lock behavior intact.
- [ ] Add blueprint save/load UI hooks and friendly error states.

### Task 8: Full-framework hardening and release verification

**Files:** all changed Luau modules plus docs.

- [ ] Search for old hardcoded `StructuralFrame/SmallReactor/Autocannon` client assumptions and remove inappropriate ones.
- [ ] Search for duplicate part allowlists and obsolete rectangular-render assumptions.
- [ ] Verify bootstrap dependency order for PartRegistry -> Inventory -> Build plus new behavior services.
- [ ] Verify all RemoteFunction actions validate owner, types and bounds.
- [ ] Verify no optional service can overwrite `RequestBuildAction`.
- [ ] Verify feature branch is ahead of and not behind main before PR.
- [ ] Open PR with complete test checklist; do not merge until static verification passes.
- [ ] Runtime Studio acceptance: catalog opens, at least one part from every category renders/places/paints; undo/redo; seat; car drive; propeller craft; winged craft; weapons; save blueprint; re-enter edit mode safely.
