# Gundam-Inspired Mech Weapons Design

**Date:** 2026-08-26  
**Repository:** `codemaster9957/GOD-MACHINES`  
**Branch:** `feat/gundam-weapon-system`

## Goal

Make every installed mech weapon reliably usable and expand the builder with a varied set of humanoid-mech weapons suitable for Gundam-inspired suits.

## Existing Failure

The client dispatches `Primary` and `Secondary` actions, and `ControlService` only fires component IDs stored in its binding groups. No production path calls `ControlService:SetBindings`, so those groups remain empty and mouse input fires nothing. The existing Autocannon is the only registered buildable weapon even though `WeaponDefinitions` contains unused delivery presets.

## Architecture

### Weapon catalogue

A shared data-only catalogue defines each buildable weapon's physical size, combat configuration, resource requirements, default control group, visual profile, and collection metadata. `PartRegistry` registers weapon parts from this catalogue so runtime behaviour and builder content cannot drift apart.

Initial weapons:

1. Autocannon
2. Beam Rifle
3. Beam Saber
4. Head Vulcan
5. Shoulder Missile Pod
6. Chest Cannon
7. Arm Gatling
8. Rail Cannon
9. Plasma Shotgun
10. Rocket Fist
11. Shoulder Beam Cannon

The names describe original GOD-MACHINES parts and do not copy protected Gundam character or model designs.

### Control binding lifecycle

`ControlService` owns binding reconciliation. Whenever a mech gains or loses components, it rebuilds bindings from each weapon's configured `DefaultAction`. Weapons default to `Primary`; heavy or specialist weapons may default to `Secondary`. Explicit player bindings can override defaults later without changing combat code.

The build path calls reconciliation after successful placement, removal, undo, and redo. Dispatch remains server-authoritative and verifies mech ownership before invoking combat.

### Combat and feedback

`CombatService` continues to validate ownership, weapon state, fire rate, ammunition, power, heat, physical presence, aim arc, and recoil. Weapon state keys include both mech and component identity so two players' generated component IDs cannot share cooldown or ammunition state.

`ProjectileService` handles hitscan, melee, stream, projectile, guided, burst, and charged-style configurations through data. It emits `CombatFeedback` packets for accepted shots, rejected shots, impacts, and explosions. A client renderer creates short-lived tracers, beams, muzzle flashes and impact effects without trusting clients for damage.

### Attachment and appearance

Weapon definitions use the existing attachment-node system and identify intended mount roles such as hand, arm, head, chest, shoulder, or back. Runtime parts remain compatible with the general structural/utility/weapon node system, while visual metadata gives the physical builder distinct silhouettes and colours instead of identical blocks.

### Inventory and collection integration

Every weapon is added to `CollectionDefinitions.Parts`. Studio/debug inventories grant one of each weapon so the full pack can be tested immediately. Persistent inventories continue using existing save and item identity behaviour.

## Safety and validation

- The server never accepts client-supplied damage, cooldown, ammunition, power cost, heat, origin, or weapon statistics.
- A shot must originate from a live physical component owned by the requesting player's active mech.
- Aim direction is finite, normalized, range-limited and constrained by the weapon arc.
- Rate limits remain active at the remote boundary.
- Projectiles ignore the firing assembly.
- Explosions apply damage through `DamageService`, not Roblox client physics.

## Testing

Add focused Luau tests for:

- All catalogue weapons resolving to valid combat configurations.
- Every catalogue weapon registering as a buildable collection part.
- Default control groups including installed weapons and excluding destroyed/non-combat parts.
- Reconciliation after add/remove.
- Fire rejection for unauthorized, unbound, destroyed, overheated, underpowered, empty-ammo, invalid-aim and cooldown cases.
- Successful hitscan, pellet, melee, projectile and explosive dispatch.
- Independent cooldown/ammunition state across mechs.
- Existing Autocannon behaviour remaining compatible.

A Roblox Studio smoke test will build a simple powered mech, mount examples in both groups, leave build mode, and confirm LMB/RMB firing, damage, heat, power use, recoil and visible feedback.
