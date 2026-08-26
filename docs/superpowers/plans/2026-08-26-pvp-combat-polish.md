# God Machines PvP Combat Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make God Machines PvP aiming responsive and live, make every shot server-authoritative and visibly readable, and complete weapon state, damage, projectile, reload, HUD, and guidance behaviour.

**Architecture:** Keep the existing MechFramework service boundaries. Add pure shared combat math, stream target intent through ControlService, keep authoritative per-weapon state in CombatService, resolve hostile hits in ProjectileService/DamageService, and use the existing CombatFeedback RemoteEvent for presentation-only client effects and HUD state.

**Tech Stack:** Roblox Luau strict mode, Rojo, Roblox services and RemoteEvents, existing MechFramework service container.

**Spec:** `docs/superpowers/specs/2026-08-26-pvp-combat-polish-design.md`

## Global Constraints

- Gameplay damage, ammunition, cooldowns, reloads, heat, power, spread, projectile motion, and target validity remain server-authoritative.
- Client packets never contain a hit Instance or a damage value.
- Aim updates are capped at 20 Hz.
- Friendly fire is disabled unless the active match explicitly enables it.
- Existing weapon configs remain valid through defaults and `TurnSpeed` remains a legacy alias for `TraverseSpeed`.
- Existing parts without `Muzzle` attachments or turret motors remain usable through fallbacks.
- Build, save, power, heat, destruction, AI, and match flows must continue to start when combat is degraded.
- Every modified Luau source retains `--!strict`.
- Run `rojo build default.project.json -o GOD-MACHINES-PvP.rbxlx` after every task.

---

## File Map

- `src/ReplicatedStorage/MechFramework/Shared/CombatMath.luau`: finite-vector checks, constrained/stepped aim, deterministic spread, falloff.
- `src/ReplicatedStorage/MechFramework/Shared/CombatProtocol.luau`: packet kind constants, stable rejection codes, payload validation helpers.
- `src/ReplicatedStorage/MechFramework/Shared/WeaponDefinitions.luau`: complete data-driven weapon defaults and presets.
- `src/ServerStorage/MechFrameworkTests/CombatMathTests.luau`: Studio-runnable pure math assertions.
- `src/StarterPlayer/StarterPlayerScripts/WeaponController.client.luau`: input state and 20 Hz live aim intent.
- `src/StarterPlayer/StarterPlayerScripts/CombatEffects.client.luau`: pooled muzzle, tracer, beam, projectile, impact, explosion, recoil, and hit feedback.
- `src/StarterPlayer/StarterPlayerScripts/CombatHUD.client.luau`: reticle and weapon-state HUD.
- `src/ServerScriptService/MechFramework/Services/ControlService.luau`: validate/store latest aim and held actions.
- `src/ServerScriptService/MechFramework/Services/CombatService.luau`: authoritative runtime state, tracking, bloom, ammo, reload, firing, feedback.
- `src/ServerScriptService/MechFramework/Services/ProjectileService.luau`: hostile hit resolution, fixed-step projectiles, guidance, explosion line of sight.
- `src/ServerScriptService/MechFramework/Services/DamageService.luau`: structured typed-damage results.
- `src/ServerScriptService/MechFramework/Services/MatchService.luau`: friendly-fire policy and damage attribution.
- `src/ReplicatedStorage/MechFramework/Shared/BattleDefinitions.luau`: explicit FriendlyFire mode option.

---

### Task 1: Pure combat math and weapon configuration

**Files:**
- Create: `src/ReplicatedStorage/MechFramework/Shared/CombatMath.luau`
- Modify: `src/ReplicatedStorage/MechFramework/Shared/WeaponDefinitions.luau`
- Create: `src/ServerStorage/MechFrameworkTests/CombatMathTests.luau`

**Interfaces:**
- Produces: `IsFiniteVector(Vector3): boolean`
- Produces: `StepDirection(current: Vector3, target: Vector3, radiansPerSecond: number, dt: number): Vector3`
- Produces: `ClampDirection(rest: CFrame, requested: Vector3, yawArcDegrees: number, pitchArcDegrees: number): Vector3`
- Produces: `SpreadDirection(direction: Vector3, spreadDegrees: number, seed: number): Vector3`
- Produces: `Falloff(distance: number, radius: number): number`

- [ ] **Step 1: Write failing math tests**

Create a ModuleScript returning `Run` and assert finite rejection, a 90°/s step, yaw/pitch clamping, deterministic spread, and falloff:

```luau
--!strict
local CombatMath = require(game.ReplicatedStorage.MechFramework.Shared.CombatMath)
local Tests = {}

function Tests.Run()
	assert(CombatMath.IsFiniteVector(Vector3.new(1, 2, 3)))
	assert(not CombatMath.IsFiniteVector(Vector3.new(0 / 0, 0, 0)))

	local stepped = CombatMath.StepDirection(Vector3.zAxis, Vector3.xAxis, math.rad(90), 0.5)
	assert(math.abs(math.deg(math.acos(math.clamp(Vector3.zAxis:Dot(stepped), -1, 1))) - 45) < 0.01)

	local rest = CFrame.lookAt(Vector3.zero, Vector3.zAxis)
	local clamped = CombatMath.ClampDirection(rest, Vector3.xAxis, 30, 20)
	assert(math.deg(math.acos(math.clamp(rest.LookVector:Dot(clamped), -1, 1))) <= 30.01)

	assert(CombatMath.SpreadDirection(Vector3.zAxis, 3, 12345) == CombatMath.SpreadDirection(Vector3.zAxis, 3, 12345))
	assert(CombatMath.Falloff(0, 10) == 1)
	assert(CombatMath.Falloff(5, 10) == 0.5)
	assert(CombatMath.Falloff(10, 10) == 0)
end

return Tests
```

- [ ] **Step 2: Verify the tests fail in Studio**

Run in Studio Server command bar after Rojo sync:

```luau
require(game.ServerStorage.MechFrameworkTests.CombatMathTests).Run()
```

Expected: failure because `CombatMath` does not exist.

- [ ] **Step 3: Implement CombatMath and extend defaults**

Implement each exported function without Roblox Instances other than `Vector3` and `CFrame`. Use `Random.new(seed)` for spread. Add exact defaults:

```luau
TraverseSpeed = 90,
YawArc = 180,
PitchArc = 90,
FireTolerance = 4,
MagazineSize = 30,
ReserveAmmo = 120,
ReloadTime = 2,
DamageType = "Kinetic",
MaxBloom = 4,
BloomPerShot = 0.15,
BloomRecovery = 5,
LockRange = 0,
LockAngle = 0,
SeekerStrength = 0,
VisualProfile = "Ballistic",
```

Set energy weapons to `DamageType = "Energy"`, explosive weapons to `"Explosive"`, melee to `"Melee"`, and resolve `TraverseSpeed` from `TurnSpeed` only when the new field is absent.

- [ ] **Step 4: Run tests and build**

Run the Studio assertion command. Expected: no error.  
Run: `rojo build default.project.json -o GOD-MACHINES-PvP.rbxlx`  
Expected: build succeeds.

- [ ] **Step 5: Commit**

```bash
git add src/ReplicatedStorage/MechFramework/Shared/CombatMath.luau src/ReplicatedStorage/MechFramework/Shared/WeaponDefinitions.luau src/ServerStorage/MechFrameworkTests/CombatMathTests.luau
git commit -m "feat: add deterministic combat aiming math"
```

---

### Task 2: Combat protocol and live client aim streaming

**Files:**
- Create: `src/ReplicatedStorage/MechFramework/Shared/CombatProtocol.luau`
- Modify: `src/StarterPlayer/StarterPlayerScripts/WeaponController.client.luau`
- Modify: `src/ServerScriptService/MechFramework/Services/ControlService.luau`

**Interfaces:**
- Consumes: `CombatMath.IsFiniteVector`
- Produces packets: `{ Kind = "Aim", MechId, Sequence, ClientTime, Aim = { Target, Direction } }`
- Produces: `Control:GetAim(userId: number, mechId: string): any?`
- Produces: `Control:ConsumeReload(userId: number, mechId: string): boolean`

- [ ] **Step 1: Add a failing Studio validation test**

Add a `DebugValidatePacket(player, packet)` hook to the test expectation and verify a NaN vector and stale sequence reject while a valid Aim packet passes. Before implementation, this command must fail because the method is absent:

```luau
local control = require(game.ServerScriptService.MechFramework.Services.ControlService)
assert(control.DebugValidatePacket ~= nil)
```

- [ ] **Step 2: Create the protocol constants**

Define frozen `Kinds = { Action = "Action", Aim = "Aim" }`, frozen feedback kinds, rejection codes, `MAX_AIM_DISTANCE = 6000`, `AIM_HZ = 20`, and helpers that check finite vectors, positive integer sequences, string lengths, and timestamps no more than two seconds old or 0.25 seconds in the future.

- [ ] **Step 3: Stream live aim from the client**

Replace `player:GetMouse().Hit`-only dispatch with `camera:ViewportPointToRay(mouse.X, mouse.Y)`, raycast to 6000 studs excluding the local character and active mech, and send an immediate Aim packet on press plus capped updates from `RenderStepped` while Primary or Secondary is held. Action begin/end packets keep backward-compatible fields and use `Kind = "Action"`. Reload is a one-shot action, never held.

- [ ] **Step 4: Validate and store aim on the server**

In ControlService, keep `_aim[ownerKey]` separate from `_held`. Validate ownership, finite target/direction, distance limit, sequence, and timestamp before storage. Heartbeat uses the newest aim for every held fire action instead of the aim captured on button-down. Clear aim, sequence, held actions, and dispatch timing on player removal or mech loss.

- [ ] **Step 5: Verify and commit**

Use a two-client Studio test: hold LMB, sweep the cursor across two static targets, and inspect `Control:DebugAim` to confirm the direction changes without releasing. Build with Rojo, then:

```bash
git add src/ReplicatedStorage/MechFramework/Shared/CombatProtocol.luau src/StarterPlayer/StarterPlayerScripts/WeaponController.client.luau src/ServerScriptService/MechFramework/Services/ControlService.luau
git commit -m "feat: stream validated live weapon aim"
```

---

### Task 3: Authoritative weapon runtime, muzzle origin, ammo, reload, bloom, and traversal

**Files:**
- Modify: `src/ServerScriptService/MechFramework/Services/CombatService.luau`
- Modify: `src/ServerScriptService/MechFramework/Services/ControlService.luau`

**Interfaces:**
- Consumes: `CombatMath.ClampDirection`, `StepDirection`, `SpreadDirection`
- Produces: `Combat:UpdateAim(userId, mechId, weaponId, aim, dt): (boolean, string?)`
- Produces: `Combat:Reload(userId, mechId, weaponId): (boolean, string?)`
- Produces: `Combat:GetRuntimeState(mechId, weaponId): any?`
- Produces feedback packet kinds `Shot`, `WeaponState`, and `Rejected`

- [ ] **Step 1: Write runtime invariants as a Studio test ModuleScript**

Assert that runtime keys include both mech and weapon IDs, two mechs with the same component ID have isolated magazines, reload cannot exceed magazine capacity, and a requested 90° aim advances only by `TraverseSpeed * dt`.

- [ ] **Step 2: Replace global maps with one runtime table**

Key state by `mechId .. ":" .. weaponId`:

```luau
type WeaponRuntime = {
	CurrentDirection: Vector3?,
	RestCFrame: CFrame?,
	Magazine: number,
	Reserve: number,
	ReloadEndsAt: number?,
	Bloom: number,
	LastFire: number,
	ShotSequence: number,
}
```

Initialize from resolved weapon config and component metadata. Remove state when a mech/component no longer exists.

- [ ] **Step 3: Derive authoritative aim and muzzle**

Prefer `part:FindFirstChild("Muzzle")` when it is an Attachment. Otherwise use `part.CFrame * CFrame.new(0, 0, -part.Size.Z * 0.5)`. Clamp target direction against the stored rest CFrame, step toward it, and reject firing with `NotAligned` when error exceeds `FireTolerance`.

- [ ] **Step 4: Implement fire/reload state**

Before a shot: validate ownership, destroyed/jammed/overheated state, reload, cooldown, magazine, power, and alignment. After acceptance: consume exactly one configured ammo usage, add heat, increase bloom, generate deterministic spread from the runtime shot sequence, fire the projectile, apply physical recoil, and emit `Shot` plus `WeaponState`. Reload transfers `min(MagazineSize - Magazine, Reserve)` only when `ReloadEndsAt` completes; firing cannot bypass it.

- [ ] **Step 5: Connect ControlService and verify**

Heartbeat supplies `dt`, updates each grouped weapon's aim, fires according to cooldown, and recovers bloom when not firing. Reload action reloads every non-duplicated weapon in Primary and Secondary groups. Run isolation, reload, traversal, and legacy-fallback tests, build, then commit:

```bash
git add src/ServerScriptService/MechFramework/Services/CombatService.luau src/ServerScriptService/MechFramework/Services/ControlService.luau
git commit -m "feat: complete authoritative weapon runtime"
```

---

### Task 4: Hostile-only typed damage and reliable projectile simulation

**Files:**
- Modify: `src/ServerScriptService/MechFramework/Services/ProjectileService.luau`
- Modify: `src/ServerScriptService/MechFramework/Services/DamageService.luau`
- Modify: `src/ServerScriptService/MechFramework/Services/MatchService.luau`
- Modify: `src/ReplicatedStorage/MechFramework/Shared/BattleDefinitions.luau`

**Interfaces:**
- Produces: `Match:CanDamage(sourceMechId, targetMechId): boolean`
- Produces: `Damage:Apply(...): (boolean, DamageResult?)`
- `DamageResult = { Applied, RemainingHealth, State, Destroyed, Blocked, Critical }`
- Produces feedback packet kinds `Impact`, `Hit`, `DamageTaken`, `ComponentDestroyed`, `Eliminated`

- [ ] **Step 1: Add failing hostility and structured-result tests**

Cover same-team blocked damage, enemy damage, explicit FriendlyFire mode, armour-blocked hits, penetration, critical threshold, and component destruction. Include a direct-plus-splash case and assert one component receives no duplicate damage from the same pellet.

- [ ] **Step 2: Add match damage policy**

Add `FriendlyFire = false` to battle mode defaults. Implement `CanDamage`: allow self/environment only when explicitly requested, require the same active match for PvP participants, return hostility for opposing teams/FFA, and respect `match.Options.FriendlyFire` or the mode default.

- [ ] **Step 3: Return structured typed damage results**

Keep the existing first boolean return for compatibility, replace the optional health number with `DamageResult`, and include `DamageType`, `Penetration`, armour block, critical state, applied amount, remaining health, and destroyed flag. Update internal callers expecting a number.

- [ ] **Step 4: Fix projectile resolution**

Pass `DamageType` and `Penetration` from config. Check `CanDamage` before direct or splash damage. Use one `seen` set spanning direct and explosion application for a pellet. Add explosion raycasts from blast centre to target component; world geometry blocks splash. Simulate physical projectiles with a 1/120-second accumulator capped at eight substeps per Heartbeat.

- [ ] **Step 5: Verify and commit**

Run a two-team Studio match: confirm allies take no damage, enemies do, armour/penetration alter results, and a cannon impact cannot damage one component twice. Build, then:

```bash
git add src/ServerScriptService/MechFramework/Services/ProjectileService.luau src/ServerScriptService/MechFramework/Services/DamageService.luau src/ServerScriptService/MechFramework/Services/MatchService.luau src/ReplicatedStorage/MechFramework/Shared/BattleDefinitions.luau
git commit -m "fix: enforce authoritative PvP damage rules"
```

---

### Task 5: Replicated combat effects

**Files:**
- Create: `src/StarterPlayer/StarterPlayerScripts/CombatEffects.client.luau`
- Modify: `src/ServerScriptService/MechFramework/Services/CombatService.luau`
- Modify: `src/ServerScriptService/MechFramework/Services/ProjectileService.luau`

**Interfaces:**
- Consumes existing `CombatFeedback` RemoteEvent.
- Consumes packet kinds `Shot`, `ProjectileSpawn`, `ProjectileCorrection`, `Impact`, `Hit`, `DamageTaken`, `ComponentDestroyed`, `Eliminated`.

- [ ] **Step 1: Create a packet-shape test table**

For every feedback kind, define required fields and validate a representative packet through `CombatProtocol.ValidateFeedback`. The test rejects missing origin, direction, projectile ID, target mech, or finite position fields.

- [ ] **Step 2: Emit server-approved feedback**

CombatService fires `Shot` to all players for accepted shots. ProjectileService fires spawn/correction/impact packets; shooter gets `Hit`, victim gets `DamageTaken`, and all nearby clients get destruction/elimination presentation packets. Do not include server Instances in packets.

- [ ] **Step 3: Implement pooled client effects**

Create local folders under `workspace.CurrentCamera`. Pool Parts/Beams instead of allocating every frame. Use VisualProfile to select colour, width, lifetime, light, and impact style. Hitscan draws a short-lived tracer/beam; physical projectiles interpolate by ID; impacts create bounded particles and lights; elimination uses a larger but capped effect.

- [ ] **Step 4: Add hit and recoil presentation**

Shooter hitmarkers distinguish normal, armour blocked, critical, and destroyed. Apply small cosmetic camera recoil only for the local player's shot; never modify authoritative aim. Add cleanup on camera replacement, ActiveMechId removal, match ending, and player respawn.

- [ ] **Step 5: Verify and commit**

Stress-test machine guns for 60 seconds and confirm effect instance counts stabilise due to pooling. Test laser, cannon, shotgun, plasma, and missile profiles. Build, then:

```bash
git add src/StarterPlayer/StarterPlayerScripts/CombatEffects.client.luau src/ServerScriptService/MechFramework/Services/CombatService.luau src/ServerScriptService/MechFramework/Services/ProjectileService.luau src/ReplicatedStorage/MechFramework/Shared/CombatProtocol.luau
git commit -m "feat: add pooled mech combat effects"
```

---

### Task 6: Combat reticle and weapon-state HUD

**Files:**
- Create: `src/StarterPlayer/StarterPlayerScripts/CombatHUD.client.luau`
- Modify: `src/ServerScriptService/MechFramework/Services/CombatService.luau`

**Interfaces:**
- Consumes `WeaponState`, `Rejected`, `Hit`, and `DamageTaken` feedback.
- Reticle states: `Idle`, `Tracking`, `Aligned`, `Blocked`, `Reloading`, `Empty`, `Overheated`, `NoPower`, `Destroyed`.

- [ ] **Step 1: Write a HUD state reducer test**

Create a pure reducer inside CombatHUD's companion ModuleScript or CombatProtocol and assert `NotAligned -> Tracking`, `NoAmmo -> Empty`, `Reloading -> Reloading`, `NoPower -> NoPower`, and destroyed state has highest priority.

- [ ] **Step 2: Build the compact combat HUD**

Create one ScreenGui only while ActiveMechId exists. The centre reticle expands with bloom and changes colour/state. Bottom-right weapon group cards show name, magazine/reserve, heat, reload bar, and status. Directional damage arcs use the camera-space angle from DamageTaken.SourcePosition.

- [ ] **Step 3: Send bounded state snapshots**

CombatService sends WeaponState only after a state change or at 5 Hz while firing/reloading. Include weapon ID, group, magazine, reserve, heat ratio, bloom ratio, alignment, reload progress, and stable status code. Never send the full mech component table.

- [ ] **Step 4: Add responsive controls**

Mouse/controller use the same centred HUD. Touch receives Primary, Secondary, and Reload ContextAction buttons without creating duplicate buttons. Build mode and missing ActiveMechId hide the combat HUD and release held actions.

- [ ] **Step 5: Verify and commit**

Test 16:9, ultrawide, and mobile emulation; verify no overlap with the builder UI. Test every state and respawn cleanup. Build, then:

```bash
git add src/StarterPlayer/StarterPlayerScripts/CombatHUD.client.luau src/ServerScriptService/MechFramework/Services/CombatService.luau src/ReplicatedStorage/MechFramework/Shared/CombatProtocol.luau
git commit -m "feat: add responsive mech combat HUD"
```

---

### Task 7: Guided missiles, kills, assists, and cleanup

**Files:**
- Modify: `src/ServerScriptService/MechFramework/Services/ProjectileService.luau`
- Modify: `src/ServerScriptService/MechFramework/Services/MatchService.luau`
- Modify: `src/ServerScriptService/MechFramework/Services/CombatService.luau`

**Interfaces:**
- Produces: `Match:RecordDamage(sourceUserId, sourceMechId, targetMechId, amount, at): ()`
- Produces: `Match:ResolveAttribution(targetMechId, at): { KillerUserId: number?, Assists: {number} }`
- Guided projectile fields: `TargetMechId`, `SeekerStrength`, `LockExpiresAt`.

- [ ] **Step 1: Add failing guidance and attribution tests**

Assert a missile cannot lock an ally, cannot lock outside LockRange/LockAngle, turns no faster than SeekerStrength, loses a destroyed target, credits the largest recent contributor as killer, includes other qualifying contributors as assists, and ignores contributions older than ten seconds.

- [ ] **Step 2: Acquire and update hostile locks**

At missile fire time, find the closest hostile component inside the configured cone and range using MatchService. Store only mech/component IDs. Each fixed simulation step re-resolves the target position and rotates velocity through `CombatMath.StepDirection`. Continue unguided when the target becomes invalid.

- [ ] **Step 3: Record damage attribution**

On applied damage, store per-target contribution by user with amount and timestamp. On elimination, choose the highest non-expired contribution as killer and other contributors with at least 15% of recent damage as assists. Emit results and clear the target ledger.

- [ ] **Step 4: Clean all runtime state**

Clear weapon runtime, held actions, aim, projectiles, attribution, client effects, and HUD state on component destruction, mech elimination, match end, player removal, ActiveMechId change, and respawn. No state key may survive after its mech disappears.

- [ ] **Step 5: Verify and commit**

Run missile locks against enemy/ally pairs, eliminate targets with two attackers, end matches during active reloads/projectiles, and confirm debug counts return to zero. Build, then:

```bash
git add src/ServerScriptService/MechFramework/Services/ProjectileService.luau src/ServerScriptService/MechFramework/Services/MatchService.luau src/ServerScriptService/MechFramework/Services/CombatService.luau
git commit -m "feat: finish guided PvP combat attribution"
```

---

### Task 8: Full regression, balance, and handoff

**Files:**
- Modify only files revealed by regression failures.
- Update: `docs/superpowers/specs/2026-08-26-pvp-combat-polish-design.md` only if implemented behaviour must be clarified.

**Interfaces:**
- Consumes the complete PvP combat stack from Tasks 1-7.
- Produces one reviewable branch with no known startup, build, combat, or cleanup failures.

- [ ] **Step 1: Run automated and build verification**

Run every ModuleScript test from Studio Server command bar, then:

```bash
rojo build default.project.json -o GOD-MACHINES-PvP.rbxlx
git diff --check
```

Expected: all assertions pass, Rojo exits 0, and `git diff --check` prints nothing.

- [ ] **Step 2: Run the two-client combat matrix**

Test machine gun, cannon, autocannon, shotgun, railgun, laser, plasma, missile, rocket, flamethrower, melee blade, drill, and saw. For each, verify live aim, correct muzzle, damage type, cooldown, ammo/power/heat, feedback, destruction, and cleanup.

- [ ] **Step 3: Run adversarial network checks**

From a local exploit-style test script, submit NaN directions, huge vectors, stale timestamps, repeated sequences, unowned mech IDs, invalid actions, impossible target distances, and fake hit/damage fields. Expected: every packet is ignored/rejected and no server error occurs.

- [ ] **Step 4: Check performance and compatibility**

Sustain four automatic weapon groups across two clients for 60 seconds. Confirm projectile/effect pools stabilise, server projectile count returns to zero, packet rates remain bounded, legacy weapons without Muzzle still fire, and builder/save/power/heat/destruction/match systems remain ready.

- [ ] **Step 5: Commit final fixes and request review**

```bash
git add src docs
git commit -m "test: verify polished PvP combat stack"
git status --short
```

Expected: clean status. Then use the requesting-code-review skill before opening the pull request.
