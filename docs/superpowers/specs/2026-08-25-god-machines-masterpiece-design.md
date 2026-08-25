# GOD MACHINES Masterpiece Builder V2 — Design

## Goal
Transform the working GOD MACHINES builder into a polished, data-driven machine-construction sandbox with **100 genuinely distinct build pieces**, procedural multi-part visuals, painting, visible attachment nodes, live engineering stats, blueprints, advanced controls, and fully functional ground/air propulsion controlled from real seats/cockpits.

## Product principles
- **100 total build pieces**, including upgraded StructuralFrame, SmallReactor, and Autocannon.
- No fake variety: each part has a distinct silhouette and gameplay role, not merely altered brick dimensions.
- No arbitrary hard part-count limit. Mass, power, heat, fuel, structural strength, drag and propulsion create practical limits.
- Server authority remains canonical for inventory, graph mutations, paint, blueprint ownership, control authority, physics behaviors, damage, power and combat.
- Beginners should be able to build seat + wheels + power and drive immediately; advanced players can remap controls.
- Physics is believable arcade engineering, not a fragile full simulator.
- Builder startup remains independent from optional combat/AI failures.

## Architecture

### Single shared PartCatalog
Create `src/ReplicatedStorage/MechFramework/Shared/PartCatalog.luau` as the single declarative source of truth for all 100 build pieces. Server `PartRegistry` validates/clones it. Clients may read public catalog/geometry data directly; that does not grant authority because every mutation remains server-validated.

Each definition includes:
- `Id`, `DisplayName`, `ShortName`, `Category`, `Description`
- `Size`, `Mass`, `MaxHealth`, structural properties
- attachment nodes + compatibility
- `Geometry` procedural recipe
- paint defaults/allowed regions
- optional `Power`, `Heat`, `Fuel`, `Mobility`, `Propulsion`, `Aerodynamics`, `Pilot`, `Combat`, `Utility`
- default automatic control tags

`CollectionDefinitions` remains responsible for materials/reward metadata, but it is **not allowed to be a second authoritative list of buildable PartTypes**. `InventoryService` gains `Init(container)` and validates/grants build pieces through `PartRegistry`, preventing a 100-part catalog from diverging from a separate inventory part table. Legacy collection metadata may map onto catalog IDs where needed.

### Shared procedural renderer
Create `src/ReplicatedStorage/MechFramework/Shared/PartRenderer.luau`. The same recipe renderer builds both:
- server runtime component visuals (`Mode = "Runtime"`), and
- client ghost previews (`Mode = "Preview"`).

A normal component renders as a `Model` containing:
- one canonical collision/root `BasePart` carrying `MechId`, `ComponentId`, `PartType`, paint/config attributes and attachment nodes;
- welded decorative primitives with `CanCollide=false`, `CanTouch=false`, `CanQuery=false` unless explicitly needed;
- decorative pieces `Massless=true` so only canonical physical members carry configured mass;
- named behavior sockets/attachments such as `Axle`, `SteerPivot`, `Thrust`, `Muzzle`, `SeatMount`, `AeroCenter`;
- moving physical members only for mechanisms that need them: wheels, steering pivots, suspension arms, rotors, seats, etc.

Supported recipe shapes: block, wedge, corner wedge, cylinder, ball, seat, layered plate, pipe, rail/truss segment, glass panel and radial-blade generator. Recipes use local CFrames, sizes, material, paint region, transparency and optional socket tags.

### Service boundaries
- `PartRegistry` — validates catalog and provides immutable definitions.
- `BuildService` — placement/remove/undo/redo/duplicate/mirror/paint/build-mode transactions only.
- `BuilderStatsService` — cached engineering summaries.
- `PilotService` — seats, occupancy, pilot authority, Edit/Test lifecycle and safety shutdown.
- `VehicleService` — wheels, steering, suspension, drivetrain and brakes.
- `PropulsionService` — engines, electric motors, jets, rockets, propellers, ducted/hover fans.
- `AerodynamicsService` — lift, drag and control surfaces.
- existing `PowerService`, `HeatService`, `CombatService`, `ControlService`, `SaveService`, `PhysicsService`, `MechService` stay authoritative within their current responsibilities.

### Build remote contract
Existing `RequestBuildAction` remains the construction command boundary and gains validated actions:
- `Place`, `Remove`, `Undo`, `Redo`, `Definition` (compatibility)
- `Paint`, `Duplicate`, `Mirror`
- `Stats`
- `EnterTest`, `ReturnToEdit`
- `BlueprintSave`, `BlueprintLoad`, `BlueprintRename`, `BlueprintDelete`, `BlueprintList`
- `ControlBindingsGet`, `ControlBindingsSet`

Catalog display data does not require a remote because it is shared. Remote handlers never trust client-supplied stats, inventory counts, geometry or ownership.

## Build/Test state model
Every mech has explicit state:
- **Edit** — canonical roots anchored, mechanisms disabled, thrust zero, builder enabled.
- **Test** — editing blocked, assembly released, mechanisms/forces active, pilot controls enabled.

Entering Edit always clears held controls, zeroes propulsion, applies braking, safely settles then anchors the assembly. Entering Test realizes current constraints, unanchors required members and enables simulation. Repeated state requests are idempotent.

A `[ TEST MACHINE ]` / `[ RETURN TO EDIT ]` button provides rapid iteration without leaving the session.

# 100-part catalog

## Structural — 18
1. **StructuralFrame** — square industrial chassis cell with inset plate, corner ribs and exposed bosses.
2. **CompactFrame** — low-profile cross-member with recessed center and short side lugs.
3. **HeavyFrame** — thick boxed chassis with double rails and gusseted corners.
4. **LatticeFrame** — open cage with rails and diagonal truss members.
5. **CrossBrace** — paired crossing braces around a bolted center hub.
6. **TriBrace** — triangular support frame with open center and three feet.
7. **XBrace** — thin broad X reinforcement panel.
8. **OctaHub** — octagonal junction with radial attachment bosses.
9. **TetraHub** — compact four-direction pyramidal junction.
10. **SpineBeam** — long I-beam silhouette with web and end caps.
11. **CurvedBrace** — segmented arch-like structural member.
12. **CornerGusset** — L-corner wedge cluster for ninety-degree reinforcement.
13. **SuspensionMount** — boxed fork mount with lower ears and shock tower.
14. **HingeMount** — clevis pivot block with cylindrical pin housing.
15. **TurretRing** — broad circular bearing ring with raised inner race.
16. **Bulkhead** — tall reinforced wall frame with recessed center.
17. **RollCageArc** — overhead protective hoop with reinforced feet.
18. **ModularDeck** — wide platform with edge rails and underside ribs.

## Armour — 12
19. **FlatArmor** — broad armor plate with layered edge strips.
20. **SlopedArmor** — wedge plate with raised center ridge.
21. **WedgeNose** — pointed two-slope nose for ramming/aero builds.
22. **RoundedArmor** — curved shell impression made from layered angled segments.
23. **CornerArmor** — wraparound L-shaped protective corner.
24. **LayeredArmor** — three offset plates on visible standoffs.
25. **ReactivePanel** — raised armor cells on a backing plate.
26. **BellyPlate** — shallow armored tray with beveled perimeter.
27. **RoofPlate** — low segmented roof shell with channel ribs.
28. **ShieldBumper** — thick forward bumper with angled crash horns.
29. **ArmoredSkirt** — hanging side plates under a hinge-like top rail.
30. **BlastShield** — tall narrow shield with reinforcement spine.

## Mobility — 14
31. **CasterWheel** — tiny free-swivel caster with fork and narrow wheel.
32. **SmallWheel** — compact road wheel with hubcap and tire sidewall.
33. **StandardWheel** — medium five-spoke general wheel.
34. **HeavyWheel** — thick six-spoke industrial wheel and reinforced hub.
35. **MonsterWheel** — oversized deep-tread wheel with chunky radial tread blocks.
36. **ArmoredWheel** — protected wheel with partial side shield and hub armor.
37. **SteerableWheel** — wheel, steering knuckle and yaw servo mount.
38. **PoweredWheel** — wheel with integrated motor housing and cooling fins.
39. **OffroadWheel** — wide wheel with staggered tread and raised hub.
40. **OmniWheel** — hub with perimeter roller segments and intentionally low lateral grip.
41. **SuspensionWheel** — wheel on trailing arm with spring/damper assembly.
42. **TrackSprocket** — toothed-looking high-torque drive wheel.
43. **TrackBogie** — paired road wheels on rocking suspension beam; track propulsion approximation.
44. **LandingGear** — long shock strut with compact wheel and fork.

## Propulsion — 12
45. **SmallCombustionEngine** — compact block engine, cylinder head, intake, exhaust and flywheel housing.
46. **HeavyDieselEngine** — long twin-bank engine with pipes and large fan housing.
47. **ElectricMotor** — cylindrical motor can with shaft boss and terminal box.
48. **HeavyElectricMotor** — large ribbed motor with twin end bells and cooling fins.
49. **MicroJet** — small intake, compressor fan and exhaust cone.
50. **TurboJet** — long nacelle, intake lip, fan, center body and nozzle.
51. **RocketThruster** — chamber, feed pipes and large bell nozzle.
52. **VectorThruster** — compact gimballed nozzle in pivot frame.
53. **SmallPropeller** — motor hub with three blades.
54. **HeavyPropeller** — reinforced hub with four broad blades.
55. **DuctedFan** — circular shroud, multi-blade fan and support vanes.
56. **HoverFan** — downward wide fan housing with grille and skirt lip.

## Aerodynamic — 10
57. **StraightWing** — tapered straight wing with spar ridge and tip cap.
58. **SweptWing** — swept-back wedge planform with reinforced root.
59. **DeltaWing** — broad triangular wing with thick central spar.
60. **Tailplane** — compact symmetrical horizontal stabilizer.
61. **VerticalFin** — tall tapered stabilizer with reinforced root.
62. **Rudder** — hinged vertical control surface with visible hinge line.
63. **Elevator** — hinged horizontal pitch surface.
64. **Aileron** — narrow wing-edge roll surface.
65. **Airbrake** — slotted deployable panel on pivot housing.
66. **Spoiler** — raised aerodynamic blade on twin pylons.

## Power & cooling — 10
67. **SmallReactor** — armored reactor with glowing core window, pipes and service cap.
68. **HeavyReactor** — large cylindrical core in protective cage with coolant manifolds.
69. **BatteryPack** — strapped cell bank with terminals and status strip.
70. **HeavyBattery** — dual armored cell banks in cradle.
71. **Generator** — alternator cylinder on mechanical housing.
72. **CapacitorBank** — row of tall capacitor cans and bus bars.
73. **Radiator** — finned panel with header tanks and pipe stubs.
74. **HeatSink** — dense vertical fin stack on conductive base.
75. **CoolantPump** — pump housing, motor and two pipe ports.
76. **PowerBus** — insulated distribution box with heavy conduits/status lights.

## Control — 6
77. **BasicSeat** — exposed real seat with simple backrest and floor mount.
78. **PilotSeat** — real seat with consoles, stick, pedals and instrument panel.
79. **ArmoredCockpit** — enclosed shell, transparent canopy, seat and console.
80. **CommandPod** — heavy capsule cockpit with armored frame, narrow glass and overhead equipment.
81. **RemoteCore** — antenna-equipped control computer with protected processor stack.
82. **AICore** — faceted processor housing with luminous logic core and cooling ribs.

## Weapons — 12
83. **Autocannon** — receiver, feed housing, recoil sleeve and long barrel.
84. **LightMachineGun** — slim receiver, perforated shroud and ammo box.
85. **HeavyMachineGun** — chunky receiver and heavy barrel assembly.
86. **RotaryCannon** — multi-barrel cluster around rotor/motor housing.
87. **BattleCannon** — large breech, recoil cylinders and thick barrel.
88. **Howitzer** — short wide barrel and massive recoil cradle.
89. **Railgun** — twin long rails, capacitor housings and luminous acceleration channel.
90. **MissileRack** — six individual launch tubes on angled support frame.
91. **RocketPod** — cylindrical pod with multiple visible launch openings.
92. **LaserEmitter** — focusing barrel, lens assembly and cooling fins.
93. **PlasmaCannon** — split coil housing around glowing chamber and emitter muzzle.
94. **RamBlade** — reinforced wedge blade with spine and dual mounting roots.

## Utility — 6
95. **FuelTank** — rounded cylindrical tank with straps, cap and outlet.
96. **AmmoCrate** — reinforced crate with latches and hazard-stripe region.
97. **BallastBlock** — compact dense weight with lifting eyes and embossed center plate.
98. **CargoPod** — large storage box with side ribs, doors and external handles.
99. **SensorMast** — telescoping mast silhouette with dish/sensor head.
100. **Spotlight** — articulated lamp housing, reflector/lens and mounting yoke.

# Painting
Every component persists cosmetic metadata:
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

Recipe primitives use one of `Primary`, `Secondary`, `Accent`, `Glass`, `Mechanical`. The client offers swatches, validated six-digit hex input, region picker, material picker and eyedropper. Server validates owner, component, region, value and material before mutation. Paint is free by default and is included in undo/redo, duplicate/mirror and blueprint persistence.

Initial materials: Metal, SmoothPlastic, Plastic, DiamondPlate; Accent may optionally use Neon. Glass region keeps Glass material/transparency rules.

# Builder UX
Rebuild the current fixed three-button UI into a scalable construction workstation:
- search field;
- category tabs: Structural, Armour, Mobility, Propulsion, Aero, Power, Control, Weapons, Utility;
- inventory count on every entry;
- favorites and 1–9 assignable hotbar;
- inspector with description/mass/health/power/heat/behavior stats;
- real-shape ghost preview using `PartRenderer`;
- compatible visible attachment-node markers near cursor;
- green/amber/red placement feedback;
- Paint tab with swatches/hex/regions/material/eyedropper;
- Duplicate, Mirror-X and Rotate tools;
- live machine stats panel;
- Test/Edit mode button;
- blueprint save/load/rename/delete panel;
- advanced control-group editor.

## Duplicate and mirror
Duplicate copies PartType + paint/config, consumes inventory and enters normal ghost placement. Mirror duplicates across local X with mirrored orientation; asymmetric definitions can provide a mirrored recipe/control sign or opt out with a clear UI reason.

## Node visualization
Node markers are client-only. Occupied nodes are hidden by default. Compatible free nodes glow green. Advanced node view may show incompatible nodes faint red. Markers never become canonical server gameplay objects.

# Engineering stats
`BuilderStatsService` caches by mech revision and returns:
- component count;
- total configured mass;
- current/maximum health;
- power generation/demand/battery/shortage;
- heat generation/dissipation/capacity/thermal margin;
- fuel capacity and full-throttle estimated burn;
- wheel/driven-wheel counts and estimated wheel torque;
- static thrust vector totals;
- wing area, representative-speed lift and center-of-lift offset;
- weapon count/aggregate demand;
- structural warning count.

Warnings inform rather than ban: `UNDERPOWERED`, `POWER DEFICIT`, `THERMAL RISK`, `NO PILOT CONTROL`, `ASYMMETRIC THRUST`, `LOW LIFT`, `HIGH MASS / LOW TORQUE`.

# Pilot and controls
Real Seat/VehicleSeat instances exist inside seat/cockpit recipes. `PilotService` maps Occupant Humanoid -> player -> component -> mech. Owner-only by default. Build target remains `ActiveMechId`; active driving uses separate `PilotedMechId`.

Leaving a seat, death, disconnect, entering Edit or mech destruction clears all held controls and propulsion.

## Hybrid automatic controls
Auto groups derive from behavior tags:
- ground: W/S throttle/reverse, A/D steering, Space brake;
- aircraft: W/S throttle, A/D roll, pointer/arrow pitch+yaw intent, Space airbrake;
- hover: W/S forward/back, A/D yaw, Space rise, Ctrl descend;
- Primary/Secondary preserve weapon groups.

Create a dedicated `PilotInput.client.luau` adapter rather than expanding weapon input into a giant script. Advanced binding overrides are stored per blueprint/mech.

# Ground vehicle physics
- wheels use HingeConstraint motors where practical;
- steerable wheels use yaw servo/pivot + wheel axle;
- SuspensionWheel/TrackBogie use spring/damper travel;
- tracks are approximated with driven bogie/sprocket physics, not hundreds of tread links;
- wheel grip varies by type; OmniWheel has intentionally reduced lateral grip;
- drive torque is limited by mechanical output, power fraction and component health;
- brakes apply opposing torque rather than instantly freezing the machine.

Mechanical output is separate from electrical generation. Combustion engines consume fuel; electric motors consume existing electrical power. Both generate heat. Too much mass for available drivetrain output causes poor acceleration rather than a build rejection.

# Propulsion physics
Forces apply at each mounted component location so asymmetric thrust naturally creates torque.
- jets: strong forward thrust, heat, power/fuel requirements;
- rockets: extreme thrust and high fuel/heat cost;
- vector thrusters: limited gimbal direction;
- propellers: thrust scales with throttle, local airspeed and available mechanical/electrical output;
- ducted fans: efficient low/medium-speed thrust;
- hover fans: primarily local-up lift with reduced lateral authority.

Propeller/fan visuals animate with rotor members while force calculation remains authoritative.

# Aerodynamics
Wing/control definitions provide area, lift coefficient, drag coefficient and stall angle. Active simulation uses local relative air velocity and component orientation.
- lift scales approximately with speed squared but is stability-clamped;
- lift falls after stall threshold;
- damaged surfaces lose effectiveness;
- force applies at mounted location for natural pitch/roll effects;
- Rudder/Elevator/Aileron deflection changes local force;
- Airbrake raises drag; Spoiler raises drag/reduces local lift.

# Power, heat and fuel
- existing `PowerService` remains electrical authority;
- existing `HeatService` remains thermal authority;
- fuel lives in server-side fuel-tank component metadata and is consumed only in Test/Active state;
- topology/stats invalidate after canonical build mutations;
- propulsion/weapons respect `PowerFraction`, health and thermal state.

# Combat
Weapons remain server-authoritative through CombatService/ProjectileService and definitions use geometry sockets such as `Muzzle`, `Eject`, `TurretPivot`. New weapon presets must not bypass power/heat behavior.

RamBlade uses server-validated relative-speed collision damage with a per-target cooldown to prevent Heartbeat damage spam.

# Blueprint and persistence
Use existing SaveService blueprint ownership. Persist:
- PartType;
- local transforms;
- graph connections/node names;
- paint metadata;
- user component settings;
- custom control bindings;
- blueprint name + schema version.

Do not persist velocity, occupied seats, held controls, temporary heat spikes, projectiles or current anchor/test transient state.

Catalog has a version. Blueprint load validates all IDs and reports migration errors for missing/deprecated definitions instead of silently substituting blocks.

# Inventory integration
`InventoryService` becomes a core `PartRegistry` consumer. Buildable ID validity is checked through the registry; `CollectionDefinitions` no longer blocks a catalog ID simply because it lacks a duplicate entry. Production grants remain server authoritative.

In `RunService:IsStudio() and Config.Debug`, test inventory seeds **all 100 catalog parts** (25 each) so every component can be tested without manual grants. Production never receives this debug seed.

# Robustness
- catalog validation fails clearly for wrong total count, duplicate IDs/nodes, invalid CFrames/sizes, unsupported recipe shape, missing region, missing required behavior socket and invalid automatic control tag;
- optional battle/AI failures do not take builder startup down;
- all client RemoteFunction calls have builder-readiness/timeout handling;
- all build actions validate type/owner/state;
- renderer failures identify PartType + ComponentId and do not mutate canonical data;
- Edit/Test transitions are idempotent;
- disconnect/death/seat exit/destruction always clear control and force state.

# Performance
- decorative primitives are non-colliding/non-querying and `Massless=true`;
- normal recipes target 4–14 visible primitives; showcase pieces may use roughly 20;
- only roots/mechanism members participate in collision/mass;
- no hard component count cap;
- HUD may warn about high complexity;
- Vehicle/Propulsion/Aero simulate only Test/Active mechs;
- stats are revision-cached.

# Planned file boundaries

## Shared
- create `Shared/PartCatalog.luau` — exactly 100 definitions.
- create `Shared/PartRecipe.luau` — recipe validation, paint/geometry helpers, safe cloning.
- create `Shared/PartRenderer.luau` — shared Preview/Runtime geometry builder.
- modify `Shared/BuildMath.luau` — mirror helpers and any generalized snap support.

## Server
- modify `PartRegistry.luau` — load/validate PartCatalog.
- refactor `BuildService.luau` — transactions, delegate rendering/mechanics.
- create `BuilderStatsService.luau`.
- create `PilotService.luau`.
- create `VehicleService.luau`.
- create `PropulsionService.luau`.
- create `AerodynamicsService.luau`.
- modify `InventoryService.luau` — registry-backed PartType validation and all-100 Studio seeding.
- extend `MechService.luau`, `PhysicsService.luau`, `PowerService.luau`, `HeatService.luau`, `ControlService.luau`, `SaveService.luau`, `CombatService.luau` only where required by existing responsibility.
- modify `Bootstrap.server.luau` for dependency-safe startup.

## Client
- `BuildController.client.luau` — orchestration/state only.
- create `BuildCatalog.luau` — search/filter/favorites/hotbar.
- `BuildPreview.luau` — shared real-shape ghost + node visualization.
- create `BuildPaint.luau` — region/material/eyedropper requests.
- create `BuildStats.luau` — stats presentation.
- create `BuildControls.luau` — control binding UI/controller.
- create `BuildBlueprints.luau` — blueprint UI/controller.
- `BuildUI.luau` — shell/layout only.
- `BuildInput.luau` — build input adapter.
- create `PilotInput.client.luau` — drive/fly input adapter.
- keep `WeaponController.client.luau` focused on combat input and conflict avoidance.

# Static validation
Pure catalog/serialization validation must assert:
- exactly 100 unique IDs;
- category counts = Structural 18, Armour 12, Mobility 14, Propulsion 12, Aerodynamic 10, Power 10, Control 6, Weapons 12, Utility 6;
- every recipe is non-empty and uses allowed shapes;
- every part has valid bounds and nodes where appropriate;
- every geometry paint region exists in defaults;
- every behavior-referenced socket exists;
- every automatic control tag is recognized;
- blueprint serialization round-trips without transient fields;
- Studio debug grant iterates the catalog and reaches every ID.

# Studio acceptance checklist
1. Builder starts without unexplained warnings/errors; catalog shows exactly 100 pieces.
2. Search/category/favorite/hotbar works.
3. Samples from every category preview/placement with unique real silhouettes.
4. Paint whole parts/regions; undo/redo and blueprint reload preserve it.
5. Duplicate/mirror preserve paint/config and consume inventory correctly.
6. Node markers show valid free targets and snapping works on rotated components.
7. BasicSeat/PilotSeat/Cockpit physically seat the avatar.
8. Four-wheel powered car drives, steers, brakes and responds to added mass.
9. Suspension compresses on uneven ground.
10. Jets/rockets/propellers apply mounted-location force; asymmetric thrust rotates the craft.
11. Aircraft gains lift, stalls, and reacts asymmetrically to wing loss.
12. Power shortage/heat/fuel constrain sustained operation.
13. Test -> Edit kills thrust, settles and anchors safely.
14. Blueprint save/load reproduces graph, paint and controls.
15. Autocannon and new weapons remain server-authoritative and functional.
16. Full Output review contains no unexplained framework errors.

# Delivery decomposition
The feature branch is delivered in independently reviewable phases so each stage stays playable:
1. **Foundation** — catalog, validation, shared renderer, 100 visuals, dynamic catalog/ghosts.
2. **Builder tools** — node visualization, paint, duplicate/mirror, stats, favorites/hotbar/inventory.
3. **Ground machines** — pilot authority, Test/Edit, seats, wheels, steering, suspension, drivetrain, fuel.
4. **Flight & propulsion** — jets, rockets, propellers, fans, wings/control surfaces.
5. **Persistence/combat/polish** — blueprints, bindings, weapon sockets/presets, framework error audit and final Studio acceptance pass.

Each phase must leave the branch in a playable state and be verified before compounding complexity.
