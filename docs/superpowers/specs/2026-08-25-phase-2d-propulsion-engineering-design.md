# Phase 2D — Propulsion, Aerodynamics & Engineering Overlays Design

**Parent:** `2026-08-25-masterpiece-phase-2-design.md`

## Goal
Deepen machine engineering without turning the game into a spreadsheet. Every advanced propulsion/aero part should create a visible, understandable tradeoff in thrust, torque, fuel, power, heat, lift or stability.

## Files
Create:
- `StarterPlayer/StarterPlayerScripts/GodMachinesBuilder/EngineeringOverlay.luau`

Modify:
- `PartDefinitions/Propulsion.luau`
- `PartDefinitions/Aerodynamics.luau`
- `PartDefinitions/PowerCooling.luau`
- `PartDefinitions/Utility.luau`
- `PropulsionService.luau`
- `VehicleService.luau`
- `AerodynamicsService.luau`
- `FuelService.luau`
- `PowerService.luau`
- `HeatService.luau`
- `BuildService.luau` summary action
- `ControlService.luau`
- Workshop V3 telemetry UI

## New propulsion parts
- Gearbox
- Differential
- Turbocharger
- VariablePitchPropeller
- ContraRotatingPropeller
- AfterburnerModule (or an Afterburner-capable jet setting if a separate module proves redundant)
- RocketGimbalMount if gimbal is not built into VectorThruster/Rocket metadata

## Gearbox
A Gearbox contributes a discrete ratio setting (e.g. Torque / Balanced / Speed). No continuously variable arbitrary user number in Phase 2.

Metadata:
- Ratio preset
- Efficiency
- MaxTorque
- Mass
- HeatGeneration

VehicleService evaluates connected drivetrain group and derives one effective ratio. Missing Gearbox keeps basic drivetrain functional; advanced part improves tuning rather than gating all vehicles.

## Differential
Differential provides efficiency/turning distribution improvements and becomes especially useful for four-wheel/track builds. It is not mandatory for basic wheeled motion.

## Turbocharger
Requires a combustion engine on same drivetrain/fuel topology. Boost increases torque/thrust multiplier while increasing:
- fuel consumption
- heat generation
- potential critical damage sensitivity at very high temperature

Turbo visual rotor speed follows engine load.

## Variable-pitch propeller
Pitch is server-computed from throttle + forward speed in automatic mode. Advanced controls may expose manual pitch later. It improves low/high-speed efficiency without multiplying thrust for free.

## Contra-rotating propeller
Two spinner roles counter-rotate. Benefits:
- higher peak thrust
- reduced reaction torque
Costs:
- higher mass
- higher power/engine demand
- more heat/maintenance abstraction

## Jet intake obstruction
Each jet has an `Intake` socket and a small capped obstruction probe. One or a few rays/boxcasts are enough. Obstruction factor scales available thrust smoothly.

Rules:
- ignore the jet's own component model
- machine geometry in front of intake can obstruct
- do not do dozens of rays per frame
- evaluate at bounded rate

## Jet exhaust hazard
Active jet exhaust projects a short server-authoritative heat/damage volume from `Thrust`/`Exhaust` socket.
- disabled in Edit
- owner is not globally immune in Test/Battle, but direct self-overlap can be ignored very close to nozzle to prevent numerical self-hit
- damage scales with throttle and distance
- query rate capped

## Afterburner
Separate abstract control action `Afterburner` where supported.
- large thrust multiplier
- much larger fuel multiplier
- large heat multiplier
- visual flame length/colour changes
- auto-disables on fuel starvation or thermal shutdown

## Rocket gimbal
Bounded pitch/yaw deflection from control state. Max angle intentionally small. Gimbal cannot turn a rocket 90 degrees; it corrects/steers.

## Aerodynamic remaster
Existing wings are rebuilt as shaped airfoil-like procedural assemblies. Required new parts:
- WingRoot
- WingMid
- WingTip
- Flap

Existing StraightWing/SweptWing/DeltaWing/Tailplane/VerticalFin/Rudder/Elevator/Aileron/Airbrake/Spoiler remain valid IDs and are visually upgraded where needed.

## Aero simulation
Continue arcade lift/drag, but add:
- local airflow velocity
- Angle of Attack estimate
- stall attenuation beyond StallAngle
- induced/parasite drag approximation
- control-surface coefficient contribution

No CFD. Coefficients are bounded and tuned for stable Roblox scale.

## Control-surface animation
Aileron/Elevator/Rudder/Flap/Airbrake/Spoiler visual members have animation roles driven by replicated control state. Server physics uses authoritative control input; client/runtime visual follows it.

## EngineeringOverlay module
Modes toggled from workshop UI:
- COM
- Centre of Lift
- Thrust vectors
- Power network
- Fuel network
- Thermal map
- Structural/asymmetry warnings

Overlay parts/adornments are client-only, non-queryable, pooled and cleaned when workshop closes.

## COM
Server BuildService summary returns machine-space centre of mass computed from configured component masses and transforms. Client renders a yellow marker.

## Centre of Lift
Server summary estimates weighted aero centre from wing/control-surface areas. Client renders blue marker.

## Thrust vectors
Server summary returns capped array of propulsion origins + normalized directions + representative magnitudes. Client scales arrows logarithmically/normalized so one rocket does not create a kilometer-long arrow.

## Power topology
PowerService exposes read-only topology summary without consuming energy. Overlay shows connected group relationships, not every frame update. Use sparse lines between logical roots or component centres.

## Fuel topology
FuelService exposes read-only connected supply groups and compatibility. Overlay highlights fuel consumers with no reachable supply.

## Thermal map
Build summary returns per-component predicted/current thermal risk category. Client tints via Highlight/adornment rather than mutating actual part colours.

## Structural warning overlay
Show:
- unsupported heavy branches
- asymmetric thrust
- COM far outside wheel/support footprint
- centre-of-lift imbalance
- underpowered drivetrain
- low lift/high mass

These are advisory, not build blockers.

## Estimates
Acceleration class derives from representative drive/thrust force divided by mass.
Speed class derives from wheel radius/drive speed or thrust/drag heuristic. Only show buckets:
- Crawl
- Utility
- Fast
- Very Fast
- Extreme

## Power & cooling expansion
Required new components:
- CircuitBreaker — controllable isolation/protection group metadata.
- PowerConduit — lightweight connection/topology utility visual.
- CoolingFan — electric active cooling.
- LiquidRadiator — high-capacity active/passive hybrid cooling with mass.
- HeatPipe — directional/passive heat-transfer helper.

Existing Radiator/HeatSink/CoolantPump/PowerBus get remastered recipes as needed.

## Circuit breaker
Breaker can disable downstream logical group according to simplified topology. It is not a full electrical graph simulator with cable-by-cable Kirchhoff equations. PowerService uses group isolation semantics.

## Cooling fan
Consumes power while active and scales cooling by power fraction + airflow factor.

## Liquid radiator
High cooling, heavier, stronger at speed/airflow. CoolantPump can improve it.

## Heat pipe
Moves a bounded amount of heat between connected components/groups, smoothing hotspots. It does not create negative heat or free cooling.

## Reactor startup presentation
Reactor core visuals animate on Test entry and power state changes. Power availability remains determined by PowerService, not by animation timing.

## Acceptance
- gearbox presets visibly change acceleration/top-speed balance.
- turbo raises torque and fuel/heat together.
- blocked jet loses thrust.
- afterburner drains fuel/raises heat dramatically.
- rocket gimbal produces bounded steering, not impossible pivots.
- wing stall is noticeable but recoverable.
- control surfaces visibly move with controls.
- COM/lift/thrust overlays line up on simple known builds.
- overlays do not alter physics/query targeting.
- cooling fan stops cooling when unpowered.
- heat pipe cannot generate net cooling.
- breaker isolation does not mutate unrelated machines.
