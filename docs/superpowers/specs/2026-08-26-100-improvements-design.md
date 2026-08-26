# GOD MACHINES — 100 Improvements Polish Pack Design

## Goal
Add exactly 100 distinct, low-risk improvements to GOD MACHINES without replacing the current builder, vehicle, PvP, trade, quick-swap, save, or simulation systems.

## Decision
Use an additive polish layer rather than editing every mature subsystem. A shared catalog declares all 100 improvements, an optional server service publishes pack state and safe defaults, and a client controller turns the improvements into live HUD, feedback, accessibility, onboarding, piloting, combat, performance, and reliability behavior. Existing systems remain authoritative.

## Constraints
- Exactly 100 enabled improvements, with stable unique IDs.
- No persistence schema migration.
- No new paid assets or external dependencies.
- No client authority over damage, inventory, trading, build mutations, movement simulation, or saves.
- Missing optional remotes/attributes/models must degrade safely rather than error.
- Reduced-motion behavior must disable nonessential animation.
- The polish layer must be independently disableable with a master feature flag.
- Existing `main` behavior remains recoverable because work ships through a dedicated branch and PR.

## Architecture

### `PolishCatalog.luau`
Single shared source of truth for the pack. It contains pack version, defaults, and exactly 100 records with `Id`, `Group`, `Name`, `Description`, `Scope`, and `Enabled`.

### `PolishService.luau`
Optional server service registered by the existing resilient bootstrap. It validates the catalog at startup, publishes `PolishPackVersion`, `PolishPackReady`, and `PolishEnabledCount` on `ReplicatedStorage.MechFramework`, and seeds non-authoritative player preference/session attributes. A failure here may degrade polish but must never prevent the builder or machine simulation from booting.

### `ExperiencePolish.client.luau`
Self-contained StarterPlayerScript. It creates a lightweight ScreenGui and implements the 100-point pack through reusable primitives: status chips, warning queue, onboarding prompts, crosshair feedback, aim focus, vehicle telemetry, safe-area layout, accessibility preferences, and lifecycle cleanup. It resolves the active mech lazily from `workspace.MechAssemblies` and never trusts client values for game authority.

### Tests
A Python contract test verifies exactly 100 unique catalog items, all ten groups, server bootstrap integration, client script presence, safety hooks, and CI wiring. Existing Luau compilation in GitHub Actions syntax-checks all new Luau.

## The 100 improvements

### Builder & creation — B01–B10
1. **B01 Build Mode Badge** — persistent, compact indication when construction input is active.
2. **B02 Test/Edit Badge** — shows whether the active machine is being edited or tested.
3. **B03 Live Component Count** — displays component count when the active assembly exposes it.
4. **B04 Live Mass Readout** — surfaces machine mass when available.
5. **B05 Power Margin Readout** — surfaces power health/margin without opening a deep inspector.
6. **B06 Thermal Margin Readout** — surfaces heat risk/margin without opening a deep inspector.
7. **B07 Placement State Feedback** — turns placement-validity attributes into a clear good/warn/bad chip.
8. **B08 Rotation Step Feedback** — exposes the current builder rotation step when available.
9. **B09 Builder Warning Queue** — prioritizes invalid-placement and engineering warnings instead of stacking text.
10. **B10 Contextual Build Controls** — concise build-mode controls legend that disappears outside build mode.

### Vehicle & piloting — V01–V10
11. **V01 Speedometer** — live assembly speed in studs/second.
12. **V02 Vertical Speed** — climb/descent rate for aircraft and hover builds.
13. **V03 Throttle Indicator** — keyboard/gamepad/touch intent reflected as forward/reverse state.
14. **V04 Brake Indicator** — visible brake state while Space is held.
15. **V05 Reverse Indicator** — dedicated reverse state instead of relying on speed sign.
16. **V06 Airborne Indicator** — raycast-based airborne status for active machines.
17. **V07 Low Fuel Warning** — reads normalized fuel/fuel-percent attributes when provided.
18. **V08 Critical Heat Warning** — reads normalized heat/heat-percent attributes when provided.
19. **V09 Power Deficit Warning** — reads machine power-deficit/underpowered attributes when provided.
20. **V10 Critical Damage Warning** — reads machine health ratio/health attributes when provided.

### Combat & aiming — C01–C10
21. **C01 Precision Crosshair** — clean center reticle while piloting and out of build mode.
22. **C02 Dynamic Bloom Ring** — reticle expands while firing then recovers.
23. **C03 Primary Fire Pulse** — immediate visual feedback on primary fire intent.
24. **C04 Secondary Fire Pulse** — distinct visual feedback on secondary fire intent.
25. **C05 Hit Confirmation Hook** — consumes `CombatFeedback` safely when the server emits hit data.
26. **C06 Damage/Failure Warning Hook** — surfaces server combat rejection/failure messages when present.
27. **C07 Reload Feedback** — shows reload intent when R is pressed.
28. **C08 Aim Focus FOV** — smooth, bounded FOV focus while secondary aim is held.
29. **C09 Low-Health Combat Vignette** — warns at critical machine/player health without obscuring play.
30. **C10 Fire-State Cleanup** — automatically clears reticle firing state on mode/mech/lifecycle changes.

### Trading & quick swap — T01–T10
31. **T01 Trade Safety Hint** — concise reminder that test-drive does not transfer ownership.
32. **T02 Trade Countdown Hook** — display-ready countdown support via trade/session attributes.
33. **T03 Test-Drive Banner Hook** — dedicated temporary-vehicle state banner.
34. **T04 Acceptance State Hook** — ready/not-ready status support when exposed by trade controller.
35. **T05 Offer-Changed Warning Hook** — warning path for readiness invalidation.
36. **T06 Swap Cooldown Hook** — reusable cooldown status chip.
37. **T07 Quick-Swap Slot Labels** — keyboard slot hint row for 1/2/3 machine slots.
38. **T08 Active Slot Highlight** — active vehicle slot can be highlighted through attributes.
39. **T09 Swap Blocked Warning Hook** — common warning queue path for swap rejection reasons.
40. **T10 Trade/Swap Warning Priority** — ownership-changing warnings outrank cosmetic hints.

### Session onboarding — O01–O10
41. **O01 Welcome Objective** — first-session direction instead of dropping players into a blank sandbox.
42. **O02 First Build Prompt** — asks the player to enter build mode.
43. **O03 First Part Milestone** — acknowledges the first placed component.
44. **O04 Ten-Part Milestone** — acknowledges a meaningful early build milestone.
45. **O05 First Test Prompt** — points players toward testing after building.
46. **O06 First Drive Prompt** — introduces piloting controls once a machine becomes active.
47. **O07 First Fire Prompt** — introduces weapon input only after piloting.
48. **O08 Return-to-Edit Hint** — encourages iteration after testing.
49. **O09 Next-Step Resolver** — picks one useful next action from current state instead of showing every hint.
50. **O10 Session Hint Cooldown** — prevents tutorial spam and repeated milestone popups.

### Accessibility & comfort — A01–A10
51. **A01 Auto UI Scale** — clamps polish HUD scale against viewport size.
52. **A02 High Contrast Preference** — preference attribute increases outlines/contrast.
53. **A03 Reduced Motion Preference** — removes nonessential tween/pulse motion.
54. **A04 Camera Motion Preference** — separate switch for camera/FOV motion.
55. **A05 Screen Flash Preference** — separate switch for brief fire/hit flashes.
56. **A06 Vignette Preference** — separate switch for edge warning effects.
57. **A07 Crosshair Scale Preference** — bounded user scale for reticle size.
58. **A08 Text Scale Preference** — bounded user scale for polish text.
59. **A09 Input-Aware Legend** — legend switches between keyboard, gamepad, and touch wording.
60. **A10 Shape + Text Status** — warnings never rely on color alone.

### Performance & efficiency — P01–P10
61. **P01 Telemetry Rate Cap** — speed/vertical-speed updates are capped instead of rebuilt every frame.
62. **P02 Lazy Mech Resolution** — active assembly lookup occurs on state change and timed retry, not descendant scan per frame.
63. **P03 Build-Only Hint Work** — build guidance is dormant when not building.
64. **P04 Warning Object Reuse** — one warning label is reused instead of constantly creating UI.
65. **P05 Reticle Object Reuse** — reticle primitives are created once and mutated.
66. **P06 Attribute Debounce** — grouped refresh prevents bursts of redundant layout work.
67. **P07 Adaptive Hidden Updates** — hidden HUD groups skip expensive visual refreshes.
68. **P08 Bounded Raycast Rate** — airborne checks run at telemetry cadence rather than RenderStepped.
69. **P09 Bounded Notification Queue** — queue has a hard maximum and evicts low-priority stale items.
70. **P10 Connection Cleanup** — all event connections are tracked and disconnected on script destruction.

### World & immersion — W01–W10
71. **W01 Heading Tape** — compact cardinal heading while piloting.
72. **W02 High-Speed Indicator** — speed state appears when crossing a meaningful velocity threshold.
73. **W03 Landing Pulse** — detects airborne-to-ground transition and gives restrained landing feedback.
74. **W04 Climb/Descent Arrow** — shape cue supplements vertical-speed number.
75. **W05 Machine Name Chip** — active assembly name/ID is shown compactly.
76. **W06 Ownership Chip** — indicates owned/test-drive/foreign state when attributes expose it.
77. **W07 Engineering Alert Merge** — fuel, power, heat, and damage warnings share one prioritized surface.
78. **W08 Critical-State Urgency** — severe alerts pulse only when motion is allowed.
79. **W09 Velocity State Label** — PARKED/ROLLING/FAST/AIRBORNE state makes motion readable at a glance.
80. **W10 Safe HUD Fade** — noncritical telemetry fades in build mode so construction remains visually dominant.

### Reliability & fault tolerance — R01–R10
81. **R01 Master Polish Flag** — whole pack can be disabled without deleting code.
82. **R02 Per-Improvement Flags** — each catalog record has an independent enabled flag.
83. **R03 Catalog Validation** — server asserts count, ID uniqueness, and required fields.
84. **R04 Optional Remote Detection** — missing `CombatFeedback` cannot crash the client.
85. **R05 Camera Reacquisition** — camera references are reacquired after Roblox replaces CurrentCamera.
86. **R06 Late Mech Retry** — active mech may appear after the player attribute and is retried safely.
87. **R07 Destroyed Mech Recovery** — dead assembly references are cleared automatically.
88. **R08 Character Respawn Recovery** — player-health hooks are rebound after respawn.
89. **R09 Payload Shape Validation** — optional server feedback is checked before use.
90. **R10 Startup Readiness State** — framework publishes whether the polish pack loaded successfully.

### HUD quality-of-life — Q01–Q10
91. **Q01 Cinematic HUD Toggle** — F10 hides the polish HUD for screenshots/recording.
92. **Q02 Compact HUD Toggle** — H collapses noncritical telemetry while preserving warnings.
93. **Q03 Aim Focus Layout** — aiming hides unrelated helper text around the reticle.
94. **Q04 Duplicate Toast Suppression** — repeated identical warnings refresh rather than stack.
95. **Q05 Priority Notification Ordering** — critical gameplay warnings beat tutorial hints.
96. **Q06 Stale Notification Expiry** — warnings disappear after their valid window.
97. **Q07 Safe-Area Padding** — HUD respects top/edge insets and avoids screen corners.
98. **Q08 Critical Health Pulse** — health warning gains restrained urgency when below threshold.
99. **Q09 Polish Status Attributes** — version, readiness, and enabled-count are inspectable in Studio.
100. **Q10 Built-In Help Hint** — concise F10/H/accessibility hint makes the new HUD discoverable.

## Data flow
1. Rojo places the shared catalog, optional service, and StarterPlayerScript into the existing hierarchy.
2. Server bootstrap requires/initializes/starts `PolishService` after core gameplay services.
3. `PolishService` validates the catalog and publishes readiness metadata.
4. Client waits for MechFramework but not for optional gameplay remotes, builds its UI once, and binds local state.
5. Active mech telemetry is read from the canonical workspace assembly plus non-authoritative public attributes already replicated by services.
6. Optional combat/trade/swap feedback is treated as display-only and shape-validated.

## Error handling
- Every optional lookup uses `FindFirstChild`/type checks.
- Client feedback payloads are ignored unless tables with expected string/number fields.
- The controller never writes authoritative machine state.
- Missing attributes simply hide the associated readout.
- `PolishService` is optional in bootstrap; failures set degraded state but do not stop core builder startup.

## Verification
- Contract test: exactly 100 unique enabled records and all IDs B01–Q10 represented.
- Contract test: bootstrap includes `PolishService` only in optional order.
- Contract test: client contains master flag, cleanup, viewport scale, active-mech lazy resolution, F10 cinematic toggle, H compact toggle, and optional CombatFeedback handling.
- Existing workflow: `luau-compile` checks syntax across `src` and `tests`.
- Existing architecture verifier must continue to pass.