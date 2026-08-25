# Phase 2E — Utility, Weapons, Damage & Presentation Design

**Parent:** `2026-08-25-masterpiece-phase-2-design.md`

## Goal
Make machines feel alive, dangerous and legible: useful mounted electronics/lights, weapons with mechanical presentation, visible damage progression, fire, and layered audio without turning large builds into effect spam.

## Files
Create as needed:
- `Services/FireService.luau`
- `StarterPlayer/.../MachinePresentation.luau`
- optional `Shared/AudioProfiles.luau`

Modify:
- `PartDefinitions/Utility.luau`
- `PartDefinitions/Weapons.luau`
- `PartRenderer.luau`
- `CombatService.luau`
- `ProjectileService.luau`
- `DamageService.luau`
- `DestructionService.luau`
- `ControlService.luau`
- `PilotInput.client.luau`
- `BuildUI.luau`
- `Bootstrap.server.luau`
- save/blueprint migration

## Utility parts
Required:
- Headlight
- BrakeLight
- NavigationLightPair
- CameraBlock
- Rangefinder

Existing Spotlight/SensorMast remain and are remastered or differentiated.

## Headlight
Real SpotLight/SurfaceLight as appropriate plus emissive lens geometry. Toggle through a utility control action. Server owns on/off attribute; client/runtime renders light. Enforce light count/per-machine caps or adaptive quality to avoid huge GPU cost.

## Brake light
Automatic state from active Brake action. Optional manual override is secondary. Brake lights are cosmetic and do not require server remote spam every frame; replicate brake/control state already owned by server.

## Navigation lights
Red/green aircraft-style paired lighting. Placement can be independent components if easier; definition presents a logical pair role or two variants. No gameplay buff.

## Camera block
Provides a local camera socket. Pilot may cycle owned machine camera blocks. Rules:
- only current controlled machine
- cannot view cameras on another player’s machine
- camera view is client-only
- destruction/removal automatically exits invalid camera
- camera does not reveal hidden information beyond normal rendered scene

## Rangefinder
Server performs line-of-sight ray from sensor socket on request/at bounded rate. Returns distance and optional coarse hit class; no through-wall target identity. UI shows range.

## Weapon visual standard
Every weapon definition should identify:
- Mount/Root
- Muzzle socket(s)
- Recoil member role if relevant
- Turret/bearing role if relevant
- Breech/feed/reload role
- rotating barrel role for rotary weapons

Visual animations consume replicated authoritative firing/reload state. They never determine damage.

## Weapon remaster
Audit all existing weapon recipes for:
- believable mounting
- non-floating barrel geometry
- recoil clearance
- correct muzzle position
- no rods/interior mechanisms protruding through finished outer faces
- distinct silhouette across 12 existing weapon families

## Recoil articulation
On authoritative shot event/state, recoil slide/barrel animates backward and returns. Heavy cannon/howitzer/railgun have stronger/slower recoil. Laser may have charging aperture rather than physical recoil.

## Reload presentation
- machine guns: feed/belt/bolt cycle abstraction
- cannons: breech/rammer movement
- missile/rocket racks: tube/pod state indication
- rotary: barrel spin-up/spin-down

No per-round expensive physics parts.

## Ammo variants
Initial compatible types:
- AP — higher penetration, lower splash
- HE — splash, lower penetration
- Incendiary — lower immediate damage, higher fire/heat chance

Ammo choice is stored as a component setting and validated against weapon preset. Ammo crates may carry a type or generic stock depending on current inventory model; do not duplicate-ammo exploit through blueprint load.

## Bomb Rack
Gravity-release server projectile/ordnance. Requires downward/clear release space to reduce immediate self-collision. Uses existing server damage resolver.

## Guided Bomb
Server-guided limited steering after release toward valid target/aim point. Guidance authority remains server-side and obeys LOS/turn-rate/range constraints. Not an instant homing missile clone; gravity remains relevant.

## Damage visual stages
Per component health fraction:
- Healthy > 0.70
- Worn 0.40–0.70
- Damaged 0.15–0.40
- Critical 0–0.15
- Destroyed

Presentation may add:
- darker/scuffed tint overlay
- sparks
- smoke
- intermittent electrical flicker
- rattling/critical alarm tags

Never permanently overwrite player paint data; use effects/highlights/temporary material overlays.

## FireService
Fire can start from:
- incendiary hit
- severe heat state
- fuel/power volatile damage
- explosion event

Fire state:
- server-owned duration/intensity
- adds bounded heat + damage over time
- can spread only to physically/logically adjacent connected components
- spread checks capped per tick
- global per-mech fire cap
- self-terminates after duration/fuel exhaustion/destruction

No infinite recursive spread.

## Volatile components
Fuel/ammo/reactor/battery reactions remain differentiated. Fire may precede explosion rather than every failure instantly exploding. Explosion chance/severity depends on component type and damage context.

## Mechanical audio
Create profile-based grouped emitters, not one Sound per decorative primitive.
Layers:
- combustion engine low/mid/high RPM
- electric motor whine
- wheel/track rolling
- suspension impacts
- propeller/turbine/jet
- servo/piston/mechanism
- weapon cycle/reload
- damage rattle/sparks/alarm

Machine audio manager selects a capped number of strongest relevant layers and scales pitch/volume by aggregate state.

## Workshop presentation mode
`MachinePresentation.luau` coordinates with WorkshopCamera:
- hide Workshop V3 panels, node markers and engineering overlays
- frame machine
- slow orbit around focus
- optional neutral lighting/DOF only if it does not mutate global Lighting for other players
- any movement/click/B exits immediately

No automated video recorder or background task.

## Acceptance
- mounted camera cycles and exits safely on destruction.
- rangefinder cannot identify targets through walls.
- brake lights correspond to brake state.
- large machine light count stays bounded.
- cannon/railgun recoil animation matches shot timing.
- reload visuals do not enable firing before server cooldown.
- AP/HE/incendiary produce differentiated server damage contexts.
- bombs cannot damage through client-only authority.
- health-stage effects preserve paint.
- fire terminates and never runs away across whole server.
- 100-part machine does not create 100 simultaneous looping sounds.
- presentation mode restores workshop exactly.
