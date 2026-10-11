extends SceneTree

## Headless Test Harness for Milestone P4-M2: Meta Progression & HUD Overlay System.
## Validates:
## 1. Resource loading & syntax verification for GameState, Main3D, Avatar3D, and HUD.
## 2. GameState extension contracts: avatar_speed_level, idle_level, pickup_radius_level,
##    get_effective_avatar_speed(), get_idle_level(), and avatar_stat_updated signal.
## 3. Upgrade economy: buying "avatar_speed" deducts energy, scales cost geometrically,
##    increases speed multiplier, and causes Avatar3D.get_move_speed() to scale.
## 4. Physical avatar displacement comparison (Level 0 vs Level 2 speed over physics ticks).
## 5. Main3D HUD Overlay Layer mounting, visibility toggle, and input isolation:
##    - Overlay opens/closes via open_hud_overlay, close_hud_overlay, toggle_hud_overlay.
##    - Avatar input is locked (input_enabled = false) while overlay is open, and restored on close.
##    - Background passive energy accumulation continues running while overlay is open.
##    - QuickHUD reactive binding to energy_changed and rps_changed signals.
## 6. Backward-compatible JSON persistence:
##    - Saving and loading preserves avatar upgrades.
##    - Legacy save games (without 3D upgrade keys) load safely with robust defaults.
##    - Corrupt JSON recovery preserves safe state without crashes.
## 7. Full regression safety:
##    - scenes/main.tscn (2D) preserved and loadable.
##    - Core 2D mechanics (tap_core, frenzy_meter, collect_spark) intact.
##
## Executable via: godot --headless --path IdleArcade -s tests/test_p4_m2_meta.gd

var pass_count: int = 0
var fail_count: int = 0

const TEST_SAVE_PATH: String = "user://savegame.json"

func _init() -> void:
	print("====================================================================")
	print("[TEST] Milestone P4-M2: Meta Progression & HUD Overlay Verification")
	print("====================================================================")
	process_frame.connect(_on_first_frame, CONNECT_ONE_SHOT)

func _on_first_frame() -> void:
	await _run_all_tests()
	print("\n====================================================================")
	print("[TEST] P4-M2 Results: %d passed, %d failed" % [pass_count, fail_count])
	print("====================================================================")
	if fail_count == 0:
		print(">>> ALL P4-M2 META PROGRESSION & HUD OVERLAY TESTS PASSED! <<<")
		quit(0)
	else:
		printerr(">>> TEST SUITE ENCOUNTERED %d FAILURES! <<<" % fail_count)
		quit(1)

func _assert_check(cond: bool, test_name: String) -> void:
	if cond:
		print("  [PASS] %s" % test_name)
		pass_count += 1
	else:
		printerr("  [FAIL] %s" % test_name)
		fail_count += 1

func _run_all_tests() -> void:
	# -------------------------------------------------------------------------
	# 0. Environment Setup: Mount GameState autoload if missing in SceneTree
	# -------------------------------------------------------------------------
	var gs_script = load("res://scripts/autoload/game_state.gd")
	var gs = root.get_node_or_null("GameState")
	if gs == null and gs_script != null:
		gs = gs_script.new()
		gs.name = "GameState"
		root.add_child(gs)

	await process_frame

	# =========================================================================
	# SECTION 1: Scene & Script Loading (Syntax Verification)
	# =========================================================================
	print("\n--- Section 1: Resource Loading & Syntax Verification ---")

	_assert_check(gs_script != null, "1.1 scripts/autoload/game_state.gd parsed & loaded")

	var main_3d_script = load("res://scripts/main_3d.gd")
	_assert_check(main_3d_script != null, "1.2 scripts/main_3d.gd parsed & loaded")

	var main_3d_scene = load("res://scenes/main_3d.tscn")
	_assert_check(main_3d_scene != null, "1.3 scenes/main_3d.tscn loaded successfully")

	var avatar_script = load("res://scripts/avatar_3d.gd")
	_assert_check(avatar_script != null, "1.4 scripts/avatar_3d.gd parsed & loaded")

	var avatar_scene = load("res://scenes/avatar_3d.tscn")
	_assert_check(avatar_scene != null, "1.5 scenes/avatar_3d.tscn loaded successfully")

	var hud_scene = load("res://scenes/hud.tscn")
	_assert_check(hud_scene != null, "1.6 scenes/hud.tscn loaded successfully")

	var hud_script = load("res://scripts/hud.gd")
	_assert_check(hud_script != null, "1.7 scripts/hud.gd parsed & loaded")

	if gs == null or main_3d_scene == null or avatar_scene == null or hud_scene == null:
		printerr("[FATAL] Core P4-M2 scenes/scripts failed to load. Halting further tests.")
		return

	# Reset state before testing
	if gs.has_method("reset_state"):
		gs.reset_state()

	# =========================================================================
	# SECTION 2: GameState Meta-Progression Extension Contracts
	# =========================================================================
	print("\n--- Section 2: GameState Meta-Progression Extension Contracts ---")

	_assert_check("avatar_speed_level" in gs, "2.1 GameState declares avatar_speed_level")
	if "avatar_speed_level" in gs:
		_assert_check(gs.avatar_speed_level == 0, "2.2 Initial avatar_speed_level is 0")

	_assert_check("idle_level" in gs, "2.3 GameState declares idle_level")
	if "idle_level" in gs:
		_assert_check(gs.idle_level >= 1, "2.4 Initial idle_level is >= 1 (baseline = 1)")

	_assert_check("pickup_radius_level" in gs, "2.5 GameState declares pickup_radius_level")

	_assert_check(gs.has_method("get_effective_avatar_speed"), "2.6 GameState implements get_effective_avatar_speed()")
	if gs.has_method("get_effective_avatar_speed"):
		var base_mult: float = gs.get_effective_avatar_speed()
		_assert_check(abs(base_mult - 1.0) < 0.001, "2.7 get_effective_avatar_speed() baseline is 1.0 (got %.3f)" % base_mult)

	_assert_check(gs.has_method("get_idle_level"), "2.8 GameState implements get_idle_level()")
	if gs.has_method("get_idle_level"):
		_assert_check(gs.get_idle_level() >= 1, "2.9 get_idle_level() baseline returns >= 1")

	_assert_check(gs.has_signal("avatar_stat_updated"), "2.10 GameState declares signal avatar_stat_updated")

	# Check upgrade catalog entries in GameState
	var has_avatar_speed_up: bool = gs.upgrades.has("avatar_speed")
	_assert_check(has_avatar_speed_up, "2.11 GameState upgrades contains 'avatar_speed'")
	if has_avatar_speed_up:
		var speed_up: Dictionary = gs.upgrades["avatar_speed"]
		_assert_check(speed_up.get("level", -1) == 0, "2.12 avatar_speed initial level is 0")
		_assert_check(float(speed_up.get("base_cost", 0.0)) > 0.0, "2.13 avatar_speed base_cost is positive")
		_assert_check(float(speed_up.get("cost_mult", 0.0)) > 1.0, "2.14 avatar_speed cost_mult is > 1.0")

	var has_clearance_up: bool = gs.upgrades.has("clearance_level")
	_assert_check(has_clearance_up, "2.15 GameState upgrades contains 'clearance_level'")

	var has_pickup_up: bool = gs.upgrades.has("pickup_radius")
	_assert_check(has_pickup_up, "2.16 GameState upgrades contains 'pickup_radius'")

	# =========================================================================
	# SECTION 3: Upgrade Purchase Dynamics & Avatar Speed Scaling
	# =========================================================================
	print("\n--- Section 3: Upgrade Purchase Dynamics & Speed Scaling ---")

	var avatar_instance = avatar_scene.instantiate()
	root.add_child(avatar_instance)
	await process_frame

	var baseline_avatar_speed: float = avatar_instance.get_move_speed()
	_assert_check(baseline_avatar_speed >= 1.0, "3.1 Avatar baseline move speed valid: %.2f m/s" % baseline_avatar_speed)

	# 3.1 Insufficient funds purchase rejection
	gs.energy = 0.0
	var buy_fail: bool = gs.buy_upgrade("avatar_speed")
	_assert_check(buy_fail == false, "3.2 buy_upgrade('avatar_speed') fails when energy is 0.0")

	# 3.2 Affordability & successful purchase
	var speed_data = gs.get_upgrade_data("avatar_speed")
	var initial_cost: float = float(speed_data.get("current_cost", speed_data.get("base_cost", 50.0)))
	gs.energy = initial_cost + 20.0

	var stat_signal_caught: bool = false
	var stat_name_reported: String = ""
	var stat_val_reported: float = 0.0
	var stat_handler = func(s_name: String, s_val: float):
		stat_signal_caught = true
		stat_name_reported = s_name
		stat_val_reported = s_val

	if gs.has_signal("avatar_stat_updated"):
		gs.avatar_stat_updated.connect(stat_handler)

	var buy_success: bool = gs.buy_upgrade("avatar_speed")
	if gs.has_signal("avatar_stat_updated"):
		gs.avatar_stat_updated.disconnect(stat_handler)

	_assert_check(buy_success == true, "3.3 buy_upgrade('avatar_speed') succeeds with sufficient funds")
	_assert_check(abs(gs.energy - 20.0) < 0.01, "3.4 Purchase accurately deducted upgrade cost (remaining: %.2f)" % gs.energy)

	# 3.3 Verify upgraded level and speed multiplier
	var upgraded_speed_data = gs.get_upgrade_data("avatar_speed")
	_assert_check(int(upgraded_speed_data.get("level", 0)) == 1, "3.5 avatar_speed upgrade level incremented to 1")

	var effective_mult: float = gs.get_effective_avatar_speed() if gs.has_method("get_effective_avatar_speed") else 1.0
	var expected_mult_lvl1: float = 1.0 + 1.0 * 0.15  # Exactly 1.15x (+15%)
	_assert_check(abs(effective_mult - expected_mult_lvl1) < 0.001,
		"3.6 get_effective_avatar_speed() strictly matches 1.15x (+15%% at Level 1, got %.3f)" % effective_mult)

	var upgraded_avatar_speed: float = avatar_instance.get_move_speed()
	var expected_avatar_speed_lvl1: float = baseline_avatar_speed * 1.15
	_assert_check(abs(upgraded_avatar_speed - expected_avatar_speed_lvl1) < 0.001,
		"3.7 Avatar3D.get_move_speed() strictly matches baseline * 1.15 (expected: %.3f m/s, got: %.3f m/s)" % [expected_avatar_speed_lvl1, upgraded_avatar_speed])
	_assert_check(abs(upgraded_avatar_speed - (baseline_avatar_speed * effective_mult)) < 0.001,
		"3.7b Avatar3D speed strictly couples with GameState.get_effective_avatar_speed()")

	# 3.4 Geometric cost curve verification
	var next_cost: float = float(upgraded_speed_data.get("current_cost", 0.0))
	var expected_next_cost: float = roundf(float(upgraded_speed_data["base_cost"]) * float(upgraded_speed_data["cost_mult"]))
	_assert_check(abs(next_cost - expected_next_cost) < 0.01,
		"3.8 avatar_speed cost scaled geometrically (next cost: %.1f, expected: %.1f)" % [next_cost, expected_next_cost])

	# 3.5 Purchase Level 2 & verify cumulative scaling
	gs.energy = next_cost + 50.0
	var buy_lvl2: bool = gs.buy_upgrade("avatar_speed")
	_assert_check(buy_lvl2 == true, "3.9 Successfully purchased avatar_speed Level 2")

	var effective_mult_lvl2: float = gs.get_effective_avatar_speed() if gs.has_method("get_effective_avatar_speed") else 1.0
	var expected_mult_lvl2: float = 1.0 + 2.0 * 0.15  # Exactly 1.30x (+30%)
	_assert_check(abs(effective_mult_lvl2 - expected_mult_lvl2) < 0.001,
		"3.10 get_effective_avatar_speed() at Level 2 strictly matches 1.30x (expected: %.3f, got: %.3f)" % [expected_mult_lvl2, effective_mult_lvl2])

	var upgraded_avatar_speed_lvl2: float = avatar_instance.get_move_speed()
	var expected_avatar_speed_lvl2: float = baseline_avatar_speed * 1.30
	_assert_check(abs(upgraded_avatar_speed_lvl2 - expected_avatar_speed_lvl2) < 0.001,
		"3.11 Avatar3D.get_move_speed() at Level 2 strictly matches baseline * 1.30 (expected: %.3f m/s, got: %.3f m/s)" % [expected_avatar_speed_lvl2, upgraded_avatar_speed_lvl2])
	_assert_check(abs(upgraded_avatar_speed_lvl2 - (baseline_avatar_speed * effective_mult_lvl2)) < 0.001,
		"3.11b Avatar3D speed at Level 2 strictly couples with GameState")

	# =========================================================================
	# SECTION 4: Headless Physics Displacement Test (Level 0 vs Level 2)
	# =========================================================================
	print("\n--- Section 4: Physical Displacement Comparison ---")

	# Setup static floor test stage
	var test_stage = Node3D.new()
	test_stage.name = "P4_M2_DisplacementStage"
	root.add_child(test_stage)

	var floor_body = StaticBody3D.new()
	floor_body.collision_layer = 1
	var floor_col = CollisionShape3D.new()
	var floor_box = BoxShape3D.new()
	floor_box.size = Vector3(200.0, 1.0, 200.0)
	floor_col.shape = floor_box
	floor_col.position = Vector3(0.0, -0.5, 0.0)
	floor_body.add_child(floor_col)
	test_stage.add_child(floor_body)

	# Safely re-parent avatar instance to test stage
	if avatar_instance.get_parent() != null:
		avatar_instance.get_parent().remove_child(avatar_instance)
	test_stage.add_child(avatar_instance)

	avatar_instance.global_position = Vector3.ZERO
	avatar_instance.velocity = Vector3.ZERO
	for _i in range(3):
		await physics_frame

	var start_pos_upgraded = avatar_instance.global_position
	avatar_instance.set_input_direction(Vector3(1.0, 0.0, 0.0))
	for _i in range(30):  # 30 physics ticks (0.50s @ 60Hz)
		await physics_frame
	var end_pos_upgraded = avatar_instance.global_position
	var dx_upgraded = end_pos_upgraded.x - start_pos_upgraded.x
	avatar_instance.stop_movement()

	# Temporarily reset to Level 0 for comparison
	var original_level = gs.upgrades["avatar_speed"]["level"]
	gs.upgrades["avatar_speed"]["level"] = 0
	if "avatar_speed_level" in gs:
		gs.avatar_speed_level = 0
	if gs.has_method("recalculate_stats"):
		gs.recalculate_stats()

	avatar_instance.global_position = Vector3.ZERO
	avatar_instance.velocity = Vector3.ZERO
	for _i in range(3):
		await physics_frame

	var start_pos_base = avatar_instance.global_position
	avatar_instance.set_input_direction(Vector3(1.0, 0.0, 0.0))
	for _i in range(30):  # 30 physics ticks (0.50s @ 60Hz)
		await physics_frame
	var end_pos_base = avatar_instance.global_position
	var dx_base = end_pos_base.x - start_pos_base.x
	avatar_instance.stop_movement()

	var disp_delta: float = dx_upgraded - dx_base
	_assert_check(dx_upgraded > dx_base and disp_delta > 0.20,
		"4.1 Physical displacement over 0.5s strictly scales (Level 2: %.3f m > Level 0: %.3f m, delta: +%.3f m)" % [dx_upgraded, dx_base, disp_delta])

	# Restore Level 2
	gs.upgrades["avatar_speed"]["level"] = original_level
	if "avatar_speed_level" in gs:
		gs.avatar_speed_level = original_level
	if gs.has_method("recalculate_stats"):
		gs.recalculate_stats()

	# Cleanup test stage
	test_stage.queue_free()
	await process_frame

	# =========================================================================
	# SECTION 5: Main3D HUD Overlay Layer, Toggle, & Input Isolation
	# =========================================================================
	print("\n--- Section 5: Main3D HUD Overlay Mounting & Input Isolation ---")

	var main_3d = main_3d_scene.instantiate()
	root.add_child(main_3d)
	await process_frame
	await physics_frame

	_assert_check(main_3d is Node3D, "5.1 main_3d.tscn root is Node3D")

	# Check layers presence
	var hud_overlay: CanvasLayer = main_3d.get_node_or_null("HUDOverlayLayer")
	_assert_check(hud_overlay != null, "5.2 main_3d contains HUDOverlayLayer (CanvasLayer)")
	if hud_overlay != null:
		_assert_check(hud_overlay.layer == 10, "5.3 HUDOverlayLayer is set to layer 10")
		_assert_check(hud_overlay.visible == false, "5.4 HUDOverlayLayer starts hidden (visible = false)")

	var quick_hud: CanvasLayer = main_3d.get_node_or_null("QuickHUDLayer")
	_assert_check(quick_hud != null, "5.5 main_3d contains QuickHUDLayer (CanvasLayer)")
	if quick_hud != null:
		_assert_check(quick_hud.layer == 5, "5.6 QuickHUDLayer is set to layer 5")

	# Check DimBackdrop click trapping
	var backdrop: ColorRect = main_3d.get_node_or_null("HUDOverlayLayer/OverlayContainer/DimBackdrop")
	_assert_check(backdrop != null, "5.7 HUDOverlayLayer contains DimBackdrop ColorRect")
	if backdrop != null:
		_assert_check(backdrop.mouse_filter == Control.MOUSE_FILTER_STOP,
			"5.8 DimBackdrop mouse_filter is MOUSE_FILTER_STOP (0) to trap clicks")

	# Check embedded HUD instance
	var embedded_hud = main_3d.get_node_or_null("HUDOverlayLayer/OverlayContainer/HUD")
	_assert_check(embedded_hud != null, "5.9 HUDOverlayLayer contains instanced HUD (scenes/hud.tscn)")

	# Check Main3D methods
	_assert_check(main_3d.has_method("open_hud_overlay"), "5.10 main_3d implements open_hud_overlay()")
	_assert_check(main_3d.has_method("close_hud_overlay"), "5.11 main_3d implements close_hud_overlay()")
	_assert_check(main_3d.has_method("toggle_hud_overlay"), "5.12 main_3d implements toggle_hud_overlay()")
	_assert_check(main_3d.has_method("is_hud_overlay_open"), "5.13 main_3d implements is_hud_overlay_open()")

	var world_avatar = main_3d.get_node_or_null("Avatar3D")
	_assert_check(world_avatar != null, "5.14 main_3d contains Avatar3D child")

	# 5.15 Test Overlay Open & Input Lockout
	if main_3d.has_method("open_hud_overlay") and world_avatar != null:
		main_3d.open_hud_overlay()
		_assert_check(main_3d.is_hud_overlay_open() == true, "5.15 open_hud_overlay sets state to open")
		_assert_check(hud_overlay.visible == true, "5.16 HUDOverlayLayer is visible when open")
		_assert_check(world_avatar.input_enabled == false, "5.17 Avatar input is locked (input_enabled = false) when overlay is open")

		# Test that background passive accumulation continues running while overlay is open
		gs.base_passive_rps = 100.0
		var energy_before_idle: float = gs.energy
		gs._process(0.1)  # tick passive accumulation
		var energy_after_idle: float = gs.energy
		_assert_check(energy_after_idle > energy_before_idle,
			"5.18 Background passive energy generation continues while HUD overlay is open")

		# 5.19 Test Overlay Close & Input Restoration
		main_3d.close_hud_overlay()
		_assert_check(main_3d.is_hud_overlay_open() == false, "5.19 close_hud_overlay sets state to closed")
		_assert_check(hud_overlay.visible == false, "5.20 HUDOverlayLayer is hidden when closed")
		_assert_check(world_avatar.input_enabled == true, "5.21 Avatar input restored (input_enabled = true) when overlay is closed")

		# 5.22 Test Toggle cycling
		main_3d.toggle_hud_overlay()
		_assert_check(main_3d.is_hud_overlay_open() == true, "5.22 toggle_hud_overlay toggles closed -> open")
		main_3d.toggle_hud_overlay()
		_assert_check(main_3d.is_hud_overlay_open() == false, "5.23 toggle_hud_overlay toggles open -> closed")

	# 5.24 Test QuickHUD Reactive Signal Updates
	var quick_energy_lbl: Label = main_3d.get_node_or_null("%QuickEnergyLabel")
	var quick_rps_lbl: Label = main_3d.get_node_or_null("%QuickRPSLabel")
	_assert_check(quick_energy_lbl != null, "5.24 QuickEnergyLabel exists in QuickHUD")
	_assert_check(quick_rps_lbl != null, "5.25 QuickRPSLabel exists in QuickHUD")

	if quick_energy_lbl != null and quick_rps_lbl != null:
		gs.energy = 12345.0
		gs.energy_changed.emit(12345.0, 0.0)
		_assert_check(quick_energy_lbl.text.contains("12.35 K") or quick_energy_lbl.text.contains("12345"),
			"5.26 QuickEnergyLabel reactively updated on energy_changed (got: '%s')" % quick_energy_lbl.text)

		gs.rps_changed.emit(500.0)
		_assert_check(quick_rps_lbl.text.contains("500"),
			"5.27 QuickRPSLabel reactively updated on rps_changed (got: '%s')" % quick_rps_lbl.text)

	# Clean up main_3d
	main_3d.queue_free()
	await process_frame

	# =========================================================================
	# SECTION 6: Backward-Compatible Save / Load Persistence
	# =========================================================================
	print("\n--- Section 6: Backward-Compatible Persistence ---")

	# 6.1 Save state with P4-M2 upgrades
	gs.upgrades["avatar_speed"]["level"] = 3
	if "avatar_speed_level" in gs:
		gs.avatar_speed_level = 3
	if gs.has_method("recalculate_stats"):
		gs.recalculate_stats()
	gs.save_to_disk()

	var file_exists: bool = FileAccess.file_exists(TEST_SAVE_PATH)
	_assert_check(file_exists, "6.1 save_to_disk() created save file")

	# 6.2 Reload state in fresh GameState instance
	var reload_gs = gs_script.new()
	var load_success: bool = reload_gs.load_from_disk()
	_assert_check(load_success == true, "6.2 load_from_disk() successfully parsed save file")
	if load_success:
		var loaded_speed_lvl: int = int(reload_gs.upgrades.get("avatar_speed", {}).get("level", 0))
		_assert_check(loaded_speed_lvl == 3, "6.3 Reloaded GameState preserved avatar_speed level 3")
		if reload_gs.has_method("get_effective_avatar_speed"):
			var expected_mult_lvl3: float = 1.0 + 3.0 * 0.15  # Exactly 1.45x
			_assert_check(abs(reload_gs.get_effective_avatar_speed() - expected_mult_lvl3) < 0.001,
				"6.4 Reloaded GameState restored exact speed multiplier 1.45x (expected: %.3f, got: %.3f)" % [expected_mult_lvl3, reload_gs.get_effective_avatar_speed()])
	reload_gs.free()

	# 6.3 Backward compatibility with Legacy Save (Missing 3D Meta Keys)
	var now_unix: float = Time.get_unix_time_from_system()
	var legacy_save: Dictionary = {
		"version": 1,
		"timestamp": now_unix,
		"energy": 500.0,
		"total_energy_earned": 500.0,
		"total_clicks": 42,
		"sparks_collected": 2,
		"bonus_users": 0,
		"base_passive_rps": 10.0,
		"base_click_power": 1.0,
		"upgrades": {
			"click_booster": {"level": 2, "current_cost": 13.9},
			"tier_1": {"level": 3, "current_cost": 38.0}
			# Note: avatar_speed, idle_level, clearance_level NOT present!
		}
	}
	var f_legacy = FileAccess.open(TEST_SAVE_PATH, FileAccess.WRITE)
	if f_legacy != null:
		f_legacy.store_string(JSON.stringify(legacy_save))
		f_legacy.close()

	var legacy_gs = gs_script.new()
	var legacy_load_ok: bool = legacy_gs.load_from_disk()
	_assert_check(legacy_load_ok == true, "6.5 Legacy save file (without 3D keys) loads successfully")
	if legacy_load_ok:
		_assert_check(legacy_gs.energy == 500.0, "6.6 Legacy save energy (500.0) preserved")
		var fallback_speed_lvl: int = int(legacy_gs.upgrades.get("avatar_speed", {}).get("level", 0))
		_assert_check(fallback_speed_lvl == 0, "6.7 Missing avatar_speed defaults safely to Level 0")
		if legacy_gs.has_method("get_effective_avatar_speed"):
			_assert_check(abs(legacy_gs.get_effective_avatar_speed() - 1.0) < 0.001,
				"6.8 Legacy save get_effective_avatar_speed() defaults safely to 1.0x")
	legacy_gs.free()

	# 6.4 Corrupted Save Graceful Recovery
	var f_corrupt = FileAccess.open(TEST_SAVE_PATH, FileAccess.WRITE)
	if f_corrupt != null:
		f_corrupt.store_string("<<<INVALID JSON SYNTAX>>>")
		f_corrupt.close()

	var corrupt_gs = gs_script.new()
	var corrupt_result: bool = corrupt_gs.load_from_disk()
	_assert_check(corrupt_result == false, "6.9 Corrupt save file caught cleanly, returning false")
	_assert_check(corrupt_gs.energy == 0.0 and corrupt_gs.base_click_power == 1.0,
		"6.10 Safe default state retained after corrupt load attempt")
	corrupt_gs.free()

	# =========================================================================
	# SECTION 7: Regression Safety Checks
	# =========================================================================
	print("\n--- Section 7: Regression Safety Checks ---")

	var legacy_main = load("res://scenes/main.tscn")
	_assert_check(legacy_main != null, "7.1 scenes/main.tscn (2D) remains intact and loadable")

	# Verify core 2D gameplay methods
	gs.reset_state()
	var tap_earned: float = gs.tap_core()
	_assert_check(tap_earned == 1.0 and gs.energy == 1.0, "7.2 tap_core() functions identically (+1.0 energy)")

	gs.collect_spark()
	_assert_check(gs.sparks_collected == 1 and gs.energy == 51.0, "7.3 collect_spark() functions identically (+50 energy)")

	# Verify 2D upgrades preserved
	_assert_check(gs.upgrades.has("click_booster"), "7.4 click_booster preserved in upgrades")
	_assert_check(gs.upgrades.has("tier_1"), "7.5 tier_1 preserved in upgrades")
	_assert_check(gs.upgrades.has("tier_7"), "7.6 tier_7 preserved in upgrades")
	_assert_check(gs.upgrades.has("overdrive_tuning"), "7.7 overdrive_tuning preserved in upgrades")
	_assert_check(gs.upgrades.size() >= 11, "7.8 Upgrades dictionary expanded to >= 11 upgrades (currently: %d)" % gs.upgrades.size())
