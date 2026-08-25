# Phase 2C — Mobility, Mechanisms & Part Remaster Design

**Parent:** `2026-08-25-masterpiece-phase-2-design.md`

## Goal
Make moving machines look mechanically credible and remove obvious procedural-art defects, especially protruding wheel axles and generic box-like propulsion/power components.

## Files
Create:
- `ServerScriptService/MechFramework/Services/MechanismService.luau`
- optional shared `MechanismDefinitions.luau` if action metadata benefits from central validation

Modify:
- `PartDefinitions/Mobility.luau`
- `PartDefinitions/Propulsion.luau`
- `PartDefinitions/PowerCooling.luau`
- `PartDefinitionHelpers.luau`
- `PartRenderer.luau`
- `VehicleService.luau`
- `ControlService.luau`
- `PhysicsService.luau`
- `BuildService.luau`
- `PilotService.luau`
- `Bootstrap.server.luau`
- blueprint/save migration

## Wheel remaster standard
Every wheel recipe uses these roles:
- `WheelCollision` — canonical physical rotating member
- `WheelTyreVisual`
- `WheelRimVisual`
- `WheelHubInner`
- `WheelHubOuter`
- optional `BrakeDisc`
- optional `BrakeCaliper`
- optional `SteerKnuckle`

Rules:
- Wheel axis remains the local X-axis convention unless the current VehicleService proves another convention; one convention only.
- The chassis-side inner hub may visibly connect to suspension/axle.
- The exterior side gets a clean rim/hubcap; **no axle rod may protrude beyond the exterior sidewall**.
- Cosmetic members massless/non-collidable/non-queryable.
- Only physical wheel member participates in traction/contact.
- Renderer spinner groups rotate tyre/rim/hubcap together while non-rotating caliper/knuckle stays fixed.

## Existing wheel families
Remaster visuals and preserve IDs:
- CasterWheel
- SmallWheel
- StandardWheel
- HeavyWheel
- MonsterWheel
- ArmoredWheel
- SteerableWheel
- PoweredWheel
- OffroadWheel
- OmniWheel
- SuspensionWheel
- TrackSprocket
- TrackBogie
- LandingGear

## New mobility parts
- ScooterWheel — tiny/light, low load.
- RacingWheel — high grip, low profile, lower durability/offroad capability.
- SandTyre — broad paddle tread, higher drag, strong loose-terrain coefficient.
- TankRoadWheel — compact tracked-support wheel.

## Tread visuals
Standard/Offroad/Monster/Sand/Armored get distinct procedural tread arrays. Treads are visual only and rotate with tyre group.

## Brake detail
Higher-tier/racing/armored/steerable wheel recipes may show disc + caliper. Brake strength still controlled by VehicleService metadata; visual caliper does not create extra constraints.

## Suspension
SuspensionWheel geometry visibly includes:
- chassis mount
- control/trailing arm
- spring/damper
- wheel carrier

Physical strategy:
1. Prefer stable Roblox constraints when proven in Studio.
2. If large assemblies jitter/explode, use bounded server suspension force and animate visual spring/arm from measured wheel offset.

Never create independent mass for spring decoration.

## Caster
Caster has a free yaw swivel around vertical pivot and free wheel spin. It contributes support/rolling but no drive torque and no commanded steering.

## Tracks V1
New visual track belt system around TrackSprocket + TrackBogie group:
- physical contact remains driven sprocket/bogie approximation
- belt is generated procedural/cosmetic
- belt scroll/links animate according to tracked speed
- no dozens of physically chained tread parts

Tracked drive mode applies differential left/right drive for turning and gets its own traction profile.

## Mechanism parts
Required new component IDs:
- MechanicalHinge
- PoweredServo
- LinearPiston
- ContinuousRotator
- HeavyTurretBearing

Each definition includes a `Mechanism` block:
- Kind
- Axis
- Min/Max
- Speed
- Torque/Force
- PowerDemand where applicable
- DefaultPosition
- ControlActions

## MechanismService
Responsibilities:
- discover active mechanism components
- create/configure canonical constraints at realization/Test transition
- consume power via PowerService for powered devices
- apply ControlService command state
- clamp target/speed/force
- freeze/zero in Edit
- cleanup destroyed mechanisms
- expose safe replicated state for visual animation

Mechanism input does not directly trust client angles. Client sends abstract actions; server integrates targets.

## Hinge
Passive or low-power pivot. Can be unlocked/locked; user-controlled hinge may bind positive/negative actions.

## Servo
Angle-targeted, powered, bounded. Useful steering arms, claws, folding wings.

## Piston
Linear actuator, bounded extension; powered force scales with power fraction and load.

## Rotator
Continuous angular mechanism for radar, drills, decorative machinery or light turrets.

## Turret bearing
Heavy yaw-only bearing with high torque and lower speed. Weapons mounted above it remain separate components; bearing does not perform damage.

## Engine visual remaster
Combustion engines gain:
- block/cylinder bank silhouette
- intake
- exhaust manifold sockets
- flywheel/belt visual
- throttle-linked moving/heat elements where inexpensive

Add new utility/propulsion visual parts:
- ExhaustPipe
- Muffler
- ExhaustStack
- Turbocharger

Exhaust hardware is optional for operation at first, but engines expose an Exhaust socket and can route smoke to attached exhaust if present; otherwise exhaust exits engine default socket.

## Engine smoke
Combustion exhaust particle amount/colour scales with throttle, health and fuel quality abstraction. Never emit while in Edit.

## Propeller remaster
Small/Heavy propellers get:
- recessed shaft coupling on machine-facing side
- proper spinner cone/hub
- shaped blades
- no visible rod through spinner front

## Reactor remaster
Small/Heavy reactors get stronger silhouette, shielding, pipe collars and animated core elements. Entering Test has a short visual spin/glow-up driven from power state; this does not delay authoritative power availability beyond any explicit service startup rule.

## Acceptance
- exterior wheel faces look finished from both sides.
- no axle protrudes through outer sidewall.
- tyres/rims/hubcaps spin together.
- steering knuckle and brake caliper do not spin with tyre.
- caster swivels without self-driving.
- tracked machine turns differentially and belt remains stable.
- every mechanism freezes in Edit and resumes in Test.
- destroying a mechanism removes orphan constraints.
- engines visibly route exhaust and never smoke in Edit.
- reactor startup visuals cannot create fake power state.
