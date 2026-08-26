# God Machines PvP Combat Polish Design

Date: 2026-08-26  
Branch: `codex/pvp-combat-polish`

## Purpose

Make vehicle combat responsive, readable, destructive, and secure while preserving the existing server-authoritative MechFramework. The player points at a world target; each constructed weapon must track that target within its own limits before it can fire accurately.

## Current Problems

- The client sends aim only when an input begins. Automatic fire reuses that stale direction until the button is released.
- `TurnSpeed` is currently interpreted as a permitted firing arc, not angular movement per second.
- Shots originate at the weapon part centre rather than a muzzle.
- Physical projectiles are simulated only on the server and have no replicated visual representation.
- Guided weapons use the normal projectile path and do not guide.
- Reload input has no complete server action or magazine state flow.
- Primary/secondary bindings can duplicate the same weapon.
- Combat has almost no client feedback for firing, impacts, denied shots, damage, critical hits, heat, ammo, or destruction.
- Projectile damage does not pass the weapon's damage type or penetration into component damage.
- Match hostility is not checked before applying projectile damage.

## Player Experience

### Aiming

- Mouse position produces a world-space target point using a camera ray.
- The client sends aim updates at a capped 20 Hz while a combat action is held and immediately when aim changes substantially.
- A centred combat reticle shows the requested target.
- Each weapon owns a server-side current aim direction. It turns toward the requested direction using `TraverseSpeed` degrees per second.
- `YawArc` and `PitchArc` limit movement relative to the component's rest orientation.
- Fixed weapons use zero traversal and fire along their mounted direction.
- A weapon fires only when its alignment error is within `FireTolerance`. The reticle communicates tracking, aligned, blocked, overheated, reloading, and empty states.
- Existing parts without authored aiming attachments use safe fallbacks and remain usable.

### Weapon Origin and Presentation

- A `Muzzle` Attachment is preferred. Otherwise the front face of the weapon part is used.
- Server-approved shots emit a compact `CombatFeedback` event containing weapon, origin, direction, seed, and delivery mode.
- Clients render tracers, beams, projectile shells, muzzle flashes, recoil kick, impact sparks, explosions, hitmarkers, critical-hit markers, and directional damage indicators.
- Gameplay damage remains server-only. Client visuals never decide a hit.

### Accuracy and Recoil

- Spread uses a server-provided deterministic shot seed.
- Sustained fire increases bloom up to `MaxBloom`; releasing fire recovers it using `BloomRecovery`.
- Recoil has physical impulse on the machine plus cosmetic camera/reticle feedback.
- Weapon presets define their own base spread, bloom, recoil, tracking, and feedback style.

### Ammunition, Reloading, Heat, and Power

- Magazine ammunition is stored per mech and weapon, not globally by component ID.
- Reload validates ownership, magazine capacity, reserve ammunition, destroyed state, heat, and reload state.
- Reload has a server timestamp and can be interrupted by destruction or vehicle removal.
- Combat feedback reports accepted/rejected actions using stable reason codes.
- The HUD shows magazine/reserve ammo, heat, reload progress, low power, jammed, destroyed, and weapon group status.

### Projectiles and Guidance

- Hitscan remains server raycast-based.
- Physical projectiles use fixed-step/sub-stepped server simulation to avoid tunnelling.
- Clients interpolate replicated projectile visuals from spawn and correction messages.
- Missile weapons can acquire only hostile targets inside lock range and lock angle.
- Guided projectiles turn using configured seeker strength and lose lock when the target is destroyed or invalid.
- Explosions use distance falloff and line-of-sight checks.

### Damage and PvP Rules

- Projectile context passes `DamageType`, `Penetration`, source weapon, owner, hit position, and explosion state.
- Damage is permitted only when `MatchService:IsHostile` returns true, unless an explicit mode enables friendly fire.
- Direct hits and splash hits cannot double-apply accidentally to the same component for one pellet.
- Damage feedback distinguishes armour blocked, normal, critical component, component destroyed, and machine eliminated.
- Kill and assist attribution uses recent server damage contribution with an expiry window.
- Destroyed reactors, cockpits, mobility components, and weapons produce different feedback without introducing a shared mech health bar.

## Architecture

### Shared

- Add `CombatMath.luau` for finite-vector validation, constrained aim, angular stepping, deterministic spread, falloff, and target checks.
- Extend `WeaponDefinitions.luau` with tracking, bloom, reload, damage type, lock-on, visual profile, and magazine fields.
- Extend remote payload contracts without trusting client origins or client hit results.

### Client

- Refactor `WeaponController.client.luau` into input state plus capped aim streaming.
- Add `CombatHUD.client.luau` for reticle, ammo, heat, reload, hitmarkers, and damage direction.
- Add `CombatEffects.client.luau` for pooled tracers, beams, projectiles, muzzle flashes, impacts, and explosions.
- Mobile/controller continue using the abstract action system.

### Server

- `ControlService` stores the latest validated aim separately from held action state and updates weapon tracking before firing.
- `CombatService` owns per-weapon runtime state: current aim, bloom, magazine, reserve, reload, cooldown, and shot sequence.
- `ProjectileService` owns authoritative hit resolution, fixed-step physical projectiles, guidance, hostility checks, and feedback emission.
- `DamageService` applies typed damage and returns structured results for feedback and attribution.
- `MatchService` remains the authority for hostility, friendly-fire rules, elimination, kills, and assists.

## Network and Security

- Reject non-finite vectors, oversized strings, invalid sequence numbers, stale aim timestamps, impossible target distances, and packets for unowned/inactive mechs.
- Never accept client-selected hit instances, damage, projectile speed, spread, or ammunition.
- Aim update and action rate limits are separate so automatic fire cannot exhaust unrelated network requests.
- The server derives muzzle origin and final fire direction.
- Feedback is sent only to relevant nearby players and the shooter/victim where appropriate.

## Compatibility and Migration

- Existing weapon configurations resolve through defaults.
- `TurnSpeed` is accepted as a legacy alias for `TraverseSpeed`.
- Missing `Muzzle` attachments fall back to the part front face.
- Missing turret motors fall back to logical tracking without breaking firing.
- Existing build, power, heat, destruction, save, AI, and match interfaces remain in place unless the implementation plan explicitly extends them.

## Testing and Acceptance

- Pure combat math tests cover angular limits, stepping, deterministic spread, falloff, finite values, and lock cones.
- Service tests cover ownership, hostile checks, stale packets, cooldown, continuous aim updates, reload interruption, ammo isolation, friendly-fire rejection, hit attribution, and duplicate splash prevention.
- Manual two-client Studio tests cover moving targets, sustained fire while sweeping the mouse, mixed fixed/turret weapons, latency, projectile visibility, heat/power denial, destruction, respawn, and match cleanup.
- Acceptance criteria:
  - Automatic fire follows the live target rather than the initial click.
  - Shots visibly leave the correct muzzle.
  - Server and client agree on shot direction and impact presentation.
  - Fixed and turret weapons behave differently and predictably.
  - Reload, ammo, heat, power, damage, and denial states are visible.
  - Friendly fire is blocked by default.
  - No client can submit a hit or damage value.
  - Existing legacy weapon parts still fire using fallbacks.

## Delivery Order

1. Combat math and weapon configuration.
2. Live aim streaming and server validation.
3. Runtime weapon state, traversal, firing, ammo, and reload.
4. Authoritative projectile/damage corrections and hostility.
5. Combat feedback protocol and client effects.
6. Combat HUD and reticle.
7. Guided missiles, attribution, balance pass, and regression testing.
