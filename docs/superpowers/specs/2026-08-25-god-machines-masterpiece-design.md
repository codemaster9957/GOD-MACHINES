# GOD MACHINES Masterpiece Builder V2 — Design

## Goal
Transform the working GOD MACHINES builder into a polished, data-driven machine-construction sandbox with 100 genuinely distinct build pieces, procedural multi-part visuals, painting, visible attachment nodes, live engineering stats, blueprint tools, and fully functional ground/air propulsion controlled from real seats/cockpits.

## Product principles
- **100 total build pieces**, including upgraded versions of StructuralFrame, SmallReactor, and Autocannon.
- No fake variety: every catalog entry must have a distinct silhouette and role, not merely a resized brick.
- No arbitrary hard part-count limit. Weight, power, heat, fuel, structural strength, drag, and available propulsion create the practical limits.
- Server authority remains canonical for inventory, component graphs, build transactions, painting, blueprint ownership, control authority, damage, power, and combat.
- Construction is approachable immediately: a seat + wheels + power source should drive with sensible defaults. Advanced players can remap component groups.
- Physics is believable arcade engineering, not a fragile full simulator.
- Build mode must remain safe and stable even when optional combat/AI systems degrade.

## Architecture

### Shared catalog
Create `ReplicatedStorage/MechFramework/Shared/PartCatalog.luau` as the single declarative source of all 100 component definitions. `PartRegistry` validates and clones this catalog server-side. The client may read public geometry/description data directly, but all placement/inventory behavior is still checked by the server.

Each definition contains:
- `Id`, `DisplayName`, `ShortName`, `Category`, `Description`
- `Size`, `Mass`, `MaxHealth`, structural properties
- attachment nodes and compatibility
- `Geometry` recipe made from Roblox primitives
- paint-region defaults
- optional `Power`, `Heat`, `Fuel`, `Mobility`, `Propulsion`, `Aerodynamics`, `Pilot`, `Combat`, and `Utility` data
- default automatic control actions

### Procedural component renderer
Create one renderer used by both server realization and client ghost previews. A component renders as a `Model` with:
- one canonical collision/root part carrying `MechId`, `ComponentId`, `PartType`, and attachment nodes;
- welded non-colliding decorative primitives for the unique visual recipe;
- behavior-specific attachments/constraints supplied through named geometry sockets;
- paint region attributes on render primitives.

Only canonical roots contribute component collision and configured mass unless a behavior specifically requires a physical moving member (wheel, suspension arm, propeller hub, etc.). This keeps complex-looking parts performant and prevents decorative geometry from multiplying collision cost.

Supported recipe shapes: block, wedge, corner wedge, cylinder, ball, seat, truss-like beam, plate, pipe/cylinder, glass panel, and repeated radial blades. Recipes use local CFrames, sizes, material, region, transparency, and optional behavior socket names.

### Core services
- `PartRegistry`: validates all 100 definitions and exposes catalog queries.
- `BuildService`: placement/remove/undo/redo/duplicate/mirror/paint transactions; does not own vehicle simulation.
- `PartRenderer`: realizes component models and previews.
- `BuilderStatsService`: computes mass, health, power, heat, propulsion and aerodynamic summary for HUD.
- `PilotService`: real seat occupancy, pilot authority, test-mode ownership, held-action shutdown.
- `VehicleService`: wheels, steering, suspension, drivetrain and brakes.
- `PropulsionService`: combustion/electric engines, jets, rockets, propellers, ducted/hover fans.
- `AerodynamicsService`: lift, drag and control surfaces.
- existing `PowerService`, `HeatService`, `CombatService`, `ControlService`, `SaveService`, `PhysicsService` remain authoritative and are extended rather than replaced.

### Build/Test states
A machine has explicit `Edit` and `Test` states.
- `Edit`: component roots anchored, active mechanisms disabled, build UI visible.
- `Test`: assembly released, constraints/forces enabled, build editing blocked, pilot controls enabled.
- Returning to `Edit` clears held controls, disables thrust, applies brakes, waits briefly for safe settling, then anchors roots.
- A `[ TEST MACHINE ]` control lets the player switch without leaving the session.

## The 100-part catalog

### Structural — 18
1. **StructuralFrame** — square industrial chassis cell with inset top plate, four corner ribs and exposed attachment bosses.
2. **CompactFrame** — dense low-profile cross-member with recessed center and short side lugs.
3. **HeavyFrame** — thick boxed frame with double side rails and reinforced corner gussets.
4. **LatticeFrame** — open cage using four rails plus diagonal truss members.
5. **CrossBrace** — X-shaped paired braces with a central bolted hub.
6. **TriBrace** — triangular support frame with open center and three mounting feet.
7. **XBrace** — thin broad X panel for light reinforcement.
8. **OctaHub** — octagonal central junction with radial attachment bosses.
9. **TetraHub** — compact four-direction pyramidal junction.
10. **SpineBeam** — long I-beam silhouette with web cutout styling and end caps.
11. **CurvedBrace** — arch-like structural member made from segmented angled plates.
12. **CornerGusset** — L-corner wedge cluster for reinforcing ninety-degree joints.
13. **SuspensionMount** — boxed mount with forked lower ears and shock tower.
14. **HingeMount** — clevis-shaped pivot block with cylindrical pin housing.
15. **TurretRing** — broad circular bearing ring with raised inner race.
16. **Bulkhead** — tall reinforced wall frame with central access recess.
17. **RollCageArc** — protective overhead hoop with two reinforced feet.
18. **ModularDeck** — wide floor platform with edge rails and underside ribs.

### Armour — 12
19. **FlatArmor** — broad plate with chamfer-like layered edge strips.
20. **SlopedArmor** — wedge plate with raised spine ridge.
21. **WedgeNose** — pointed two-slope nose section for ramming/aero builds.
22. **RoundedArmor** — curved-looking shell approximated with layered angled segments.
23. **CornerArmor** — wraparound L-shaped protective corner.
24. **LayeredArmor** — three offset plates with visible standoff spacers.
25. **ReactivePanel** — tiled raised armor cells on a backing plate.
26. **BellyPlate** — shallow armored tray with beveled perimeter.
27. **RoofPlate** — low curved-roof silhouette with rain-channel ribs.
28. **ShieldBumper** — thick forward bumper with angled crash horns.
29. **ArmoredSkirt** — hanging side plate row with hinge-like top rail.
30. **BlastShield** — narrow tall shield with central reinforcement spine.

### Mobility — 14
31. **CasterWheel** — tiny free-swivel caster with fork and narrow wheel.
32. **SmallWheel** — compact road wheel with hubcap and visible tire sidewall.
33. **StandardWheel** — medium five-spoke powered-capable wheel.
34. **HeavyWheel** — thick six-spoke industrial wheel with reinforced hub.
35. **MonsterWheel** — oversized deep-tread wheel with chunky radial tread blocks.
36. **ArmoredWheel** — protected wheel with partial side shield and hub armor.
37. **SteerableWheel** — wheel plus steering knuckle and yaw servo mount.
38. **PoweredWheel** — wheel with integrated motor housing and cooling fins.
39. **OffroadWheel** — wide tire with staggered tread blocks and raised hub.
40. **OmniWheel** — hub with decorative perimeter roller segments and low lateral grip model.
41. **SuspensionWheel** — wheel on trailing arm with spring/damper assembly.
42. **TrackSprocket** — toothed drive wheel visual with high torque output.
43. **TrackBogie** — paired road wheels on rocking suspension beam; track-like propulsion approximation.
44. **LandingGear** — retract-style strut silhouette with small wheel and shock body.

### Propulsion — 12
45. **SmallCombustionEngine** — compact block engine with cylinder head, intake, exhaust and flywheel housing.
46. **HeavyDieselEngine** — long heavy engine with twin banks, pipes and large radiator-facing fan.
47. **ElectricMotor** — cylindrical motor can with shaft boss and terminal box.
48. **HeavyElectricMotor** — large ribbed motor with twin end bells and cooling fins.
49. **MicroJet** — small cylindrical intake, compressor fan and hot exhaust cone.
50. **TurboJet** — long nacelle with intake lip, internal fan, center body and exhaust nozzle.
51. **RocketThruster** — chamber, feed pipes and large bell nozzle.
52. **VectorThruster** — gimballed-looking compact rocket/jet nozzle with pivot frame.
53. **SmallPropeller** — central motor hub with three visible blades.
54. **HeavyPropeller** — reinforced hub with four broad blades.
55. **DuctedFan** — circular shroud containing a multi-blade fan and support vanes.
56. **HoverFan** — downward-facing wide fan housing with protective grille and skirt lip.

### Aerodynamic — 10
57. **StraightWing** — rectangular tapered wing with spar ridge and tip cap.
58. **SweptWing** — swept-back wedge planform with reinforced root.
59. **DeltaWing** — broad triangular wing panel with thick central spar.
60. **Tailplane** — compact symmetrical horizontal stabilizer.
61. **VerticalFin** — tall tapered stabilizer with strong base fillet.
62. **Rudder** — hinged vertical control surface with visible hinge line.
63. **Elevator** — hinged horizontal control surface.
64. **Aileron** — narrow wing-edge roll control surface.
65. **Airbrake** — slotted deployable brake panel on pivot housing.
66. **Spoiler** — raised aerodynamic blade with two mounting pylons.

### Power & cooling — 10
67. **SmallReactor** — armored cube reactor with glowing core window, pipes and top service cap.
68. **HeavyReactor** — large cylindrical core within protective cage and multiple coolant manifolds.
69. **BatteryPack** — strapped rectangular cell bank with terminals and indicator strip.
70. **HeavyBattery** — dual cell banks in armored cradle.
71. **Generator** — alternator cylinder attached to small mechanical housing.
72. **CapacitorBank** — row of tall capacitor cans with bus bars.
73. **Radiator** — finned panel with header tanks and pipe stubs.
74. **HeatSink** — dense vertical fin stack on conductive base.
75. **CoolantPump** — pump volute silhouette with motor and two pipe ports.
76. **PowerBus** — insulated distribution box with heavy cable conduits and status lights.

### Control — 6
77. **BasicSeat** — exposed real seat with simple backrest and floor mount.
78. **PilotSeat** — real seat with side consoles, stick, pedals and instrument panel.
79. **ArmoredCockpit** — enclosed shell, transparent canopy, seat and control console.
80. **CommandPod** — heavy capsule cockpit with armored frame, narrow glass and overhead equipment.
81. **RemoteCore** — antenna-equipped control computer with protected processor stack.
82. **AICore** — faceted processor housing with luminous central logic core and cooling ribs.

### Weapons — 12
83. **Autocannon** — receiver body, feed housing, recoil sleeve and long barrel.
84. **LightMachineGun** — slim receiver, perforated barrel shroud and ammo box.
85. **HeavyMachineGun** — chunky receiver with dual grips/housing and heavy barrel.
86. **RotaryCannon** — multi-barrel cluster around central rotor with motor housing.
87. **BattleCannon** — large breech block, recoil cylinders and thick single barrel.
88. **Howitzer** — short wide barrel, massive recoil cradle and armored breech.
89. **Railgun** — twin long rails, capacitor housings and glowing central acceleration channel.
90. **MissileRack** — six individual launch tubes on angled support frame.
91. **RocketPod** — cylindrical pod face with multiple launch openings.
92. **LaserEmitter** — focusing barrel, lens assembly and heat-sink fins.
93. **PlasmaCannon** — split coil housing around glowing chamber and short emitter muzzle.
94. **RamBlade** — reinforced wedge blade with spine and two structural mounting roots.

### Utility — 6
95. **FuelTank** — rounded cylindrical tank with straps, cap and pipe outlet.
96. **AmmoCrate** — reinforced crate with latch details and hazard stripe region.
97. **BallastBlock** — dense compact weight with lifting eyes and embossed center plate.
98. **CargoPod** — large storage box with side ribs, doors and external handles.
99. **SensorMast** — telescoping mast silhouette with radar dish/sensor head.
100. **Spotlight** — articulated lamp housing with reflector/lens and mounting yoke.

## Painting
Every placed component owns cosmetic metadata:
```lua
Paint = {
    Primary = "#B8BDC3",
    Secondary = "#4C535A",
    Accent = "#FFB536",
    Glass = "#7FD8FF",
    Mechanical = "#33383E",
    Material = "Metal",
}
```

Allowed paint regions are recipe-driven: `Primary`, `Secondary`, `Accent`, `Glass`, `Mechanical`. A part need not use all regions. The client offers swatches plus validated six-digit hex input. The server validates owner, component, region, hex value, and allowed material before mutating metadata and re-rendering that component. Painting is free by default and survives undo/redo, blueprints and saves.

Materials exposed initially: Metal, SmoothPlastic, Plastic, DiamondPlate, CorrodedMetal-like color treatment using Metal, and Neon for Accent-only regions. Glass keeps Glass material/transparency rules and cannot be turned into opaque Neon through painting.

## Builder UX
Replace the fixed three-button list with a scalable construction workstation:
- searchable catalog;
- category tabs for Structural, Armour, Mobility, Propulsion, Aero, Power, Control, Weapons, Utility;
- inventory count per entry;
- favorites and 1–9 hotbar assignment;
- selected-part inspector with description, mass, health, power, heat and behavior stats;
- visual attachment-node markers that only show compatible free nodes near the cursor;
- real-shape ghost preview using the same renderer as placed parts;
- explicit green/amber/red placement feedback;
- paint mode with swatches, hex field, region picker, material picker and eyedropper;
- duplicate tool, mirror-X tool and rotate tool;
- live machine stats panel;
- `[ TEST MACHINE ]` / `[ RETURN TO EDIT ]` mode button;
- blueprint save/load/rename/delete panel;
- advanced control bindings panel.

### Duplicate and mirror
Duplicate copies PartType + paint/config, consumes inventory, and enters normal ghost placement. Mirror duplicates with local X reflection and mirrored orientation where safe; asymmetric behavior definitions may opt out or provide a mirrored recipe/control-surface sign.

### Visible nodes
Local-only node markers use adornment/sphere visuals and never create server gameplay objects. Occupied nodes are hidden by default. Compatible nodes glow green; incompatible candidates remain faint red only when the player enables advanced node view.

## Live engineering stats
`BuilderStatsService` computes from the canonical mech graph:
- component count;
- total configured mass;
- current/maximum health;
- power generation, demand, battery charge/capacity and shortage;
- heat generation, dissipation/capacity and predicted thermal margin;
- fuel capacity and estimated burn at full throttle;
- wheel count, driven wheel count, estimated wheel torque;
- total static thrust by axis;
- wing area, estimated lift at representative speed and center-of-lift offset;
- weapon count and aggregate power draw;
- structural warning count (weak/heavy connections).

The UI shows warnings, not arbitrary build bans: `UNDERPOWERED`, `POWER DEFICIT`, `THERMAL RISK`, `NO PILOT CONTROL`, `ASYMMETRIC THRUST`, `LOW LIFT`, `HIGH MASS / LOW TORQUE`.

## Pilot and controls
### Pilot authority
A real Seat/VehicleSeat exists inside seat/cockpit recipes. `PilotService` maps occupant Humanoid -> player -> component -> mech. Only the owner (or future explicitly authorized teammate) can pilot by default.

The player receives `PilotedMechId`; build editing uses `ActiveMechId`. Leaving the seat clears held actions and throttle immediately.

### Automatic bindings
When a machine enters Test mode, automatic groups are generated from behavior tags:
- ground vehicle: W/S throttle/reverse, A/D steering, Space brake;
- aircraft: W/S throttle, A/D roll, pointer/arrow pitch+yaw intent, Space airbrake;
- hover: W/S forward/back, A/D yaw, Space rise, Ctrl descend;
- Primary/Secondary weapons retain mouse action groups.

Advanced bindings can override groups per component without deleting auto defaults until the user explicitly customizes that group.

## Ground vehicle physics
- Wheels use HingeConstraint motor behavior where practical.
- Steerable wheels use a steering pivot/servo plus wheel axle.
- SuspensionWheel and TrackBogie use spring/damper travel.
- Track modules use physically driven bogie/sprocket approximation rather than hundreds of individual tread links.
- Drive torque is limited by engine/motor mechanical output, power fraction and component health.
- Brakes apply opposing motor torque instead of instantly freezing the assembly.
- Wheel grip varies by wheel type; OmniWheel intentionally has reduced lateral grip.

Mechanical output is tracked separately from electrical generation. Combustion engines consume fuel; electric motors consume electrical power. Engines create heat. A machine with too much mass and too little drivetrain output simply accelerates poorly rather than being rejected.

## Propulsion physics
Propulsion components apply force at their own mounted location so asymmetric designs naturally create torque.
- jets: strong forward thrust, electrical/fuel demand by definition, heat, intake/exhaust visuals;
- rockets: extreme thrust, high fuel use/heat;
- vector thrusters: controlled gimbal direction within configured limits;
- propellers: thrust scales with throttle, local airspeed and available mechanical/electrical power;
- ducted fans: compact efficient thrust at low-to-medium speed;
- hover fans: primarily local-up lift with reduced lateral authority.

Propellers/fans visibly animate using their physical or decorative rotor members while the canonical force calculation stays server-authoritative.

## Aerodynamics
Each wing/control-surface definition provides area, lift coefficient, drag coefficient and stall angle. Every simulation tick uses local relative air velocity and part orientation to compute simplified lift/drag.

Requirements:
- lift grows with speed squared but is clamped for Roblox stability;
- excessive angle of attack reduces lift after stall threshold;
- damaged/destroyed surfaces lose effectiveness;
- forces apply at the mounted component location, allowing natural pitch/roll effects;
- Rudder/Elevator/Aileron deflection changes local aerodynamic force based on control input;
- Airbrake increases drag; Spoiler increases drag and reduces local lift.

## Power, heat and fuel integration
- Existing PowerService remains the electrical authority.
- Existing HeatService remains the thermal authority and gains definitions for all heat-producing/disposing components.
- Fuel is a lightweight server-side aggregate stored in fuel-tank component metadata. Combustion/rocket systems consume it only in Test/Active state.
- Power/heat invalidation occurs whenever build transactions alter topology or relevant component state.
- Propulsion and weapons scale or shut down using `PowerFraction`/thermal state rather than bypassing engineering systems.

## Combat integration
All weapon parts remain server-authoritative through CombatService. New weapon presets may reuse the current projectile/hitscan framework but must preserve per-weapon geometry sockets (`Muzzle`, optional `Eject`, optional `TurretPivot`).

RamBlade is collision/melee utility and must use server-validated relative-speed damage with a cooldown per target to prevent Heartbeat damage spam.

## Blueprint and persistence
Blueprints use existing SaveService ownership and persist:
- PartType;
- local transforms;
- graph connections and node names;
- paint metadata;
- user component settings;
- custom control bindings;
- blueprint name/version.

Do not persist live transient state such as current velocity, occupied seat, active throttle, temporary heat spikes, projectiles or current test-mode anchors.

Catalog definitions receive a schema/version identifier. Blueprint load validates every PartType; missing future/deprecated definitions produce a clear migration error rather than silently spawning blocks.

## Error handling and robustness
- Catalog validation is fail-fast for the core builder: duplicate IDs/nodes, invalid CFrames, illegal geometry sizes, missing paint regions, unsupported behavior fields and incompatible sockets produce explicit boot errors.
- Optional battle/AI systems remain isolated from builder startup.
- All client RemoteFunction calls have readiness and timeout handling.
- All server build mutations validate ownership and request types.
- Test/Edit transitions are idempotent and safe if called repeatedly.
- Player leaving, character death, seat exit and mech destruction all clear held controls and active forces.
- Renderer failures identify PartType + ComponentId and do not corrupt the canonical graph.

## Performance rules
- Decorative render primitives default to `CanCollide=false`, `CanTouch=false`, and are welded to a canonical root.
- Prefer 4–14 visible primitives per normal part; exceptional showcase components may use up to ~20.
- Collision complexity is based on canonical roots/mechanism members, not every decorative detail.
- No hard component count cap. HUD may warn at high complexity and telemetry may report component/primitive counts.
- Vehicle/aero services simulate only mechs in Test/Active state.
- Expensive stats are cached by mech revision and recomputed after canonical mutations.

## Planned file boundaries
### Shared
- `Shared/PartCatalog.luau` — all 100 definitions.
- `Shared/PartRecipe.luau` — recipe validation/helpers and safe cloning.
- `Shared/BuildMath.luau` — snapping/compatibility plus mirror helpers.

### Server
- modify `PartRegistry.luau` — validate/load shared catalog.
- create `PartRenderer.luau` — authoritative model realization.
- refactor `BuildService.luau` — transactions only; delegate rendering/mechanics.
- create `BuilderStatsService.luau`.
- create `PilotService.luau`.
- create `VehicleService.luau`.
- create `PropulsionService.luau`.
- create `AerodynamicsService.luau`.
- extend `MechService.luau`, `PhysicsService.luau`, `PowerService.luau`, `HeatService.luau`, `ControlService.luau`, `SaveService.luau`, `CombatService.luau` only where their existing responsibility requires it.
- update `Bootstrap.server.luau` with dependency-safe service order.

### Client
Split the current builder into focused modules:
- `BuildController.client.luau` — orchestration/state.
- `BuildCatalog.luau` — search/filter/favorites/hotbar state.
- `BuildPreview.luau` — real recipe ghost + snapping/node visuals.
- `BuildPaint.luau` — paint selection/eyedropper requests.
- `BuildStats.luau` — stats presentation.
- `BuildControls.luau` — advanced bindings UI/controller.
- `BuildBlueprints.luau` — save/load UI/controller.
- `BuildUI.luau` — shell/layout only.
- `BuildInput.luau` — input adapter.
- extend `WeaponController.client.luau` or introduce a dedicated pilot input adapter so build and pilot inputs never conflict.

## Verification strategy
There is no repository CI capable of executing Roblox Studio, so verification has two layers.

### Static/pure validation
- catalog validator asserts exactly 100 unique IDs and expected category counts;
- every part has unique non-empty geometry recipe, valid bounds and at least one usable attachment node where appropriate;
- every paint region referenced by geometry exists in defaults;
- every behavior socket referenced by Mobility/Propulsion/Aero/Pilot/Combat exists in its recipe;
- automatic control actions reference known actions;
- blueprint serialization round-trips pure tables without transient fields.

### Studio acceptance checklist
1. Builder starts without warnings/errors and catalog shows exactly 100 pieces.
2. Search/category/favorite/hotbar selection works.
3. At least one sample from every category previews as its real unique silhouette and places correctly.
4. Paint whole components and individual regions; undo/redo and blueprint reload preserve colors.
5. Duplicate/mirror maintain paint and consume inventory correctly.
6. Node markers show only valid free targets and snapping remains reliable on rotated parts.
7. Basic Seat/Pilot Seat/Cockpit seat the avatar correctly.
8. Four-wheel car with engine/power drives, steers, brakes and responds to mass changes.
9. Suspension visibly compresses over uneven ground.
10. Jet/rocket/propeller forces act at their mounted locations; asymmetric layouts rotate naturally.
11. Winged aircraft gains lift with speed, stalls at excessive angle and becomes asymmetric when a wing is destroyed.
12. Power shortage reduces/shuts down dependent devices; heat and fuel constraints visibly affect sustained use.
13. Test -> Edit transition shuts thrust off and stabilizes/anchors the machine.
14. Save/load blueprint reproduces graph, paint and controls.
15. Existing Autocannon combat still functions after renderer/refactor.
16. Full Output review contains no unexplained framework errors.

## Delivery decomposition
This master upgrade is implemented on one feature branch but reviewed in independently testable phases:
1. **Foundation:** PartCatalog + recipe validator + renderer + 100 visuals + dynamic catalog UI/ghosts.
2. **Builder tools:** node visualization, painting, duplicate/mirror, stats, inventory/hotbar/favorites.
3. **Ground machines:** seats/pilot authority, Test/Edit lifecycle, wheels, steering, suspension, drivetrain, fuel.
4. **Flight/propulsion:** jets, rockets, propellers, fans, wings and control surfaces.
5. **Persistence/combat/polish:** blueprints, bindings, weapon sockets/presets, full framework error audit and Studio acceptance pass.

Each phase must leave the branch in a playable state and receive its own verification before the next phase compounds complexity.
