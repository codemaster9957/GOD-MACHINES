# GOD MACHINES — 100 QoL Pack Design

## Goal

Add exactly 100 practical quality-of-life improvements without moving game authority to the client or rewriting stable builder/combat/trading systems. The pack should feel like polish layered over the current game: faster workshop navigation, clearer vehicle/trade feedback, better combat awareness, accessibility controls, and safer input/UI behavior.

## Architecture

The pack is intentionally additive. `QoLDefinitions.luau` is the canonical 100-feature manifest. `GodMachinesQoL.client.luau` owns general HUD/accessibility/command-palette behavior and reads the manifest at runtime. Small existing client adapters are extended only where the existing script already owns the action: builder aliases stay in `BuildInput`, quick-swap feedback stays in `VehicleQuickSwap`, trade keyboard/progress behavior stays in `VehicleTradeController`, and held combat inputs are released by `WeaponController` when focus is lost.

No QoL client may grant inventory, mutate ownership, apply damage, commit trades, or bypass existing server remotes/rules. Preferences are session-local player attributes prefixed `GMQoL_`; they survive respawn because the scripts/GUIs use `ResetOnSpawn=false`, but this change does not alter the save schema.

## Feature Manifest — exactly 100

### Workshop / Builder (25)
1. `builder_ctrl_z_undo` — Ctrl+Z undo alias.
2. `builder_ctrl_y_redo` — Ctrl+Y redo alias.
3. `builder_backspace_remove` — Backspace removes aimed component.
4. `builder_ctrl_d_duplicate` — Ctrl+D duplicate alias.
5. `builder_shift_r_reverse_rotate` — Shift+R rotates the opposite direction by applying three 90° turns.
6. `builder_ctrl_m_mirror` — Ctrl+M mirror alias.
7. `builder_ctrl_t_test` — Ctrl+T test/edit alias.
8. `builder_escape_close` — Escape leaves workshop when no search text is active.
9. `builder_alt_hotbar` — Alt+1…9 selects hotbar slots.
10. `builder_wheel_previous` — mouse-wheel up selects previous hotbar slot.
11. `builder_wheel_next` — mouse-wheel down selects next hotbar slot.
12. `builder_typing_guard` — build shortcuts never fire while a TextBox is focused.
13. `builder_repeat_guard` — aliases are Begin-event only and cannot repeat from held keys.
14. `workshop_slash_search` — `/` focuses component search.
15. `workshop_ctrl_f_search` — Ctrl+F focuses component search.
16. `workshop_escape_clear_search` — Escape clears search before closing workshop.
17. `workshop_home_scroll_top` — Home jumps catalog to top.
18. `workshop_end_scroll_bottom` — End jumps catalog to bottom.
19. `workshop_tab_next` — Tab cycles workshop pages forward.
20. `workshop_tab_previous` — Shift+Tab cycles workshop pages backward.
21. `workshop_favorites_filter` — Shift+F shows only starred catalog cards.
22. `workshop_favorites_filter_clear` — Ctrl+Shift+F restores the prior catalog visibility state.
23. `workshop_visible_count` — catalog chip shows visible component count.
24. `workshop_shortcut_chip` — compact workshop keyboard hint chip.
25. `workshop_search_state_chip` — active search/filter state is visible without opening another menu.

### Quick Swap (15)
26. `swap_mouse4_cycle` — MouseButton4 cycles the next quick vehicle.
27. `swap_alt_v_cycle` — Alt+V cycles quick swap.
28. `swap_cooldown_progress` — visual cooldown progress bar.
29. `swap_cooldown_seconds` — precise remaining seconds.
30. `swap_ready_pulse` — subtle ready pulse when cooldown completes.
31. `swap_active_slot` — persistent active-slot highlight.
32. `swap_full_name_tooltip` — full blueprint name on truncated cards.
33. `swap_empty_warning` — clear warning when no usable quick slots exist.
34. `swap_error_humanizer` — server error codes become readable messages.
35. `swap_success_toast` — successful swap toast.
36. `swap_profile_loading` — explicit profile-loading state.
37. `swap_slot_count` — usable-slot count indicator.
38. `swap_safe_area` — respects configurable screen-edge margin.
39. `swap_compact_mode` — compact quick-swap bar preference.
40. `swap_key_hint_toggle` — quick-swap key hint can be hidden.

### Vehicle Trade (20)
41. `trade_escape_close` — Escape closes the console.
42. `trade_f5_refresh` — F5 refreshes trade overview while open.
43. `trade_partner_left` — Left selects previous partner.
44. `trade_partner_right` — Right selects next partner.
45. `trade_vehicle_up` — Up selects previous vehicle.
46. `trade_vehicle_down` — Down selects next vehicle.
47. `trade_enter_primary` — Enter performs the context-appropriate primary action.
48. `trade_countdown_progress` — test-drive progress bar.
49. `trade_timer_warn` — timer shifts to warning state under 30 seconds.
50. `trade_timer_danger` — timer shifts to danger state under 10 seconds.
51. `trade_progress_percent` — remaining test percentage is shown.
52. `trade_review_banner` — review phase gets a clear decision banner.
53. `trade_partner_emphasis` — current partner is visually emphasized.
54. `trade_acceptance_badge` — local acceptance state has a dedicated badge.
55. `trade_partner_acceptance_badge` — partner acceptance is surfaced when provided by server state.
56. `trade_busy_feedback` — double-submit attempts show BUSY instead of silently doing nothing.
57. `trade_network_toast` — network/server failures generate a toast.
58. `trade_cancel_toast` — cancellation reason toast.
59. `trade_complete_toast` — verified swap completion toast.
60. `trade_responsive_layout` — compact/safe-area layout for smaller screens.

### Combat / Driving (15)
61. `combat_focus_release` — losing window focus releases held actions immediately.
62. `combat_crosshair` — clean machine combat crosshair.
63. `combat_crosshair_size` — adjustable crosshair size.
64. `combat_crosshair_opacity` — adjustable crosshair opacity.
65. `combat_crosshair_gap` — adjustable crosshair gap.
66. `combat_component_highlight` — aimed component outline.
67. `combat_mech_highlight` — aimed mech outline.
68. `combat_target_chip` — target mech/component identifier chip.
69. `combat_primary_indicator` — primary-fire input indicator.
70. `combat_secondary_indicator` — secondary-fire input indicator.
71. `combat_reload_hint` — reload key hint.
72. `combat_utility_hint` — utility key hint.
73. `combat_mechanism_hint` — mechanism 1/2 key hint.
74. `combat_control_help` — togglable driving/control help strip.
75. `combat_hide_in_builder` — combat overlays disappear in build mode.

### Accessibility / General UI (20)
76. `global_command_palette` — Ctrl+K searchable command palette.
77. `global_settings_panel` — F10 QoL settings panel.
78. `access_ui_scale` — adjustable UI scale.
79. `access_large_text` — large-text mode.
80. `access_high_contrast` — stronger text contrast.
81. `access_reduced_motion` — suppress optional QoL/trade/swap animation.
82. `access_hud_opacity` — adjustable overlay opacity.
83. `access_panel_opacity` — adjustable panel opacity.
84. `access_safe_margin` — configurable edge safe area.
85. `access_compact_hud` — condense nonessential HUD spacing.
86. `access_tooltips` — tooltips on/off.
87. `access_tooltip_delay` — adjustable hover delay.
88. `access_toast_duration` — adjustable toast duration.
89. `access_focus_outline` — stronger keyboard/text focus outline.
90. `access_colorblind_glyphs` — status uses symbols in addition to color.
91. `access_streamer_mode` — abbreviates sensitive/long player and blueprint labels.
92. `access_performance_mode` — disables optional highlights/pulses and lowers refresh work.
93. `access_hide_hints` — hides tutorial-style hint labels.
94. `access_chip_density` — low/normal/high informational chip density.
95. `access_reset_settings` — one action restores all QoL defaults.

### Reliability / Polish (5)
96. `reliability_singleton_gui` — removes duplicate QoL GUI instances before creating a new one.
97. `reliability_rebind_ui` — automatically re-detects workshop/trade/swap UI after recreation.
98. `reliability_clear_stale_target` — target highlights are destroyed as soon as targets disappear or become invalid.
99. `reliability_global_typing_guard` — global QoL shortcuts do not steal input from focused text fields except explicit Escape/Enter behavior.
100. `reliability_destroy_cleanup` — connections, actions, highlights, and temporary UI clean up on script destruction.

## Data Flow

- Existing server-authoritative remotes remain the only gameplay mutation path.
- Builder aliases invoke the same callbacks already supplied to `BuildInput`.
- Quick swap still invokes `RequestMachineAction` with `Action="QuickSwap"`; QoL only improves activation/feedback.
- Trade still invokes `RequestVehicleTrade`; new keyboard actions call the same local functions as the buttons.
- Combat crosshair/targeting reads mouse target attributes only; damage/fire intent still travels through `RequestControlAction`.
- General preferences are stored as `Player` attributes and consumed by the QoL-aware client scripts.

## Error Handling

QoL scripts must fail soft: missing optional GUI surfaces should hide the relevant enhancement rather than yield forever; remote errors are shown readably; target highlights are always cleaned; repeated input while a remote is busy is rejected locally with feedback.

## Testing

A Python contract test verifies: exactly 100 unique manifest IDs, the 25/15/20/15/20/5 category budget, required global controller surfaces, real builder alias inputs, quick-swap progress/alias integration, trade keyboard/progress integration, and weapon focus-release behavior. Existing repo verification remains unchanged and will be checked after the feature branch is assembled.