extends SceneTree

## Adversarial Challenge & Empirical Verification Suite for Milestone P4-M2:
## Persistence, Legacy Migration, Overlay Transitions & Input Suspension.
##
## Author: p4_m2_challenger_2 (role: critic, specialist / empirical challenger)
## Target: Godot 4.3 IdleArcade - Milestone P4-M2 Deliverables
##
## Validates:
## 1. Deserialization of legacy saves (missing Phase 4 keys, fallback to safe defaults).
## 2. Deserialization of corrupted saves (invalid syntax, wrong root types, negative integers, wrong data types).
## 3. reset_state() deep baseline restoration after severe state pollution.
## 4. Overlay state transitions & rapid alternation stress harness (Tab, M, Esc, ToggleButton, CloseButton).
## 5. Sub-modal dismissal hierarchy (has_active_modal, dismiss_active_modal, 2-tier Esc hierarchy).
## 6. Avatar input suspension & click trapping (input_enabled false, DimBackdrop mouse_filter).
## 7. Discrepancy analysis on avatar movement speed contracts.
##
## Executable via: godot --headless --path IdleArcade -s tests/test_p4_m2_adversarial_challenge.gd

var pass_count: int = 0
var fail_count: int = 0
var findings: Array[String] = []

const TEST_SAVE_PATH: String = "user://savegame.json"

func _init() -> void:
	print("====================================================================")
	print("[CHALLENGE] Milestone P4-M2: Empirical Adversarial Challenge Suite")
	print("====================================================================")
	process_frame.connect(_on_first_frame, CONNECT_ONE_SHOT)

func _on_first_frame() -> void:
	await _run_all_challenges()
	print("\n====================================================================")
	print("[CHALLENGE SUMMARY] %d Passed | %d Failed" % [pass_count, fail_count])
	if findings.size() > 0:
		print("\n[CRITICAL FINDINGS / DISCREPANCIES DETECTED]:")
		for f in findings:
			print("  * " + f)
	print("====================================================================")
	if fail_count == 0:
		print(">>> ADVERSARIAL VERDICT: APPROVE <<<")
		quit(0)
	else:
		printerr(">>> ADVERSARIAL VERDICT: FAIL (%d failures) <<<" % fail_count)
		quit(1)

func _assert_chall(cond: bool, test_name: String, detail: String = "") -> void:
	if cond:
		print("  [PASS] %s" % test_name)
		pass_count += 1
	else:
		printerr("  [FAIL] %s %s" % [test_name, ("-> " + detail) if detail != "" else ""])
		fail_count += 1

func _run_all_challenges() -> void:
	# -------------------------------------------------------------------------
	# 0. Environment Setup: Autoload Singleton
	# -------------------------------------------------------------------------
	var gs_script = load("res://scripts/autoload/game_state.gd")
	if gs_script == null:
		printerr("[FATAL] Unable to load scripts/autoload/game_state.gd")
		quit(1)
		return

	var gs = root.get_node_or_null("GameState")
	if gs == null:
		gs = gs_script.new()
		gs.name = "GameState"
		root.add_child(gs)

	var main_3d_scene = load("res://scenes/main_3d.tscn")
	var avatar_scene = load("res://scenes/avatar_3d.tscn")
	var hud_scene = load("res://scenes/hud.tscn")

	_assert_chall(main_3d_scene != null, "0.1 scenes/main_3d.tscn loaded")
	_assert_chall(avatar_scene != null, "0.2 scenes/avatar_3d.tscn loaded")
	_assert_chall(hud_scene != null, "0.3 scenes/hud.tscn loaded")

	await process_frame

	# =========================================================================
	# CHALLENGE 1: Persistence & Migration Stress Test
	# =========================================================================
	print("\n--- Challenge 1: Persistence & Legacy Migration Stress Test ---")

	# 1.1 Legacy Save Migration (Missing Phase 4 keys)
	var legacy_save: Dictionary = {
		"version": 1,
		"timestamp": int(Time.get_unix_time_from_system()) - 100,
		"energy": 1250.0,
		"total_energy_earned": 5000.0,
		"total_clicks": 340,
		"sparks_collected": 12,
		"bonus_users": 5,
		"base_passive_rps": 25.0,
		"base_click_power": 4.0,
		"upgrades": {
			"click_booster": {"level": 3, "current_cost": 16.4},
			"tier_1": {"level": 5, "current_cost": 50.3}
			# Omitted: avatar_speed_level, idle_level, pickup_radius_level,
			#          collectibles_collected, unlocked_zones, and new upgrades!
		}
	}

	var f = FileAccess.open(TEST_SAVE_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(legacy_save))
		f.close()

	var test_gs = gs_script.new()
	var legacy_ok = test_gs.load_from_disk()
	_assert_chall(legacy_ok == true, "1.1.1 Legacy save without Phase 4 keys loads successfully")
	_assert_chall(test_gs.avatar_speed_level == 0, "1.1.2 Legacy migration defaults avatar_speed_level to 0")
	_assert_chall(test_gs.idle_level == 1, "1.1.3 Legacy migration defaults idle_level to 1 (baseline)")
	_assert_chall(test_gs.pickup_radius_level == 0, "1.1.4 Legacy migration defaults pickup_radius_level to 0")
	_assert_chall(test_gs.collectibles_collected == 0, "1.1.5 Legacy migration defaults collectibles_collected to 0")
	_assert_chall(test_gs.unlocked_zones.size() == 0, "1.1.6 Legacy migration defaults unlocked_zones to empty array")
	_assert_chall(abs(test_gs.get_effective_avatar_speed() - 1.0) < 0.001, "1.1.7 get_effective_avatar_speed() returns 1.0 baseline")
	_assert_chall(test_gs.get_idle_level() == 1, "1.1.8 get_idle_level() returns 1 baseline")
	_assert_chall(abs(test_gs.get_effective_pickup_radius() - 1.0) < 0.001, "1.1.9 get_effective_pickup_radius() returns 1.0 baseline")
	_assert_chall(test_gs.is_zone_unlocked("server_wing") == false, "1.1.10 is_zone_unlocked() returns false for legacy saves")
	test_gs.free()

	# 1.2 Corrupted Save Handling: Invalid JSON Syntax
	var f_corrupt = FileAccess.open(TEST_SAVE_PATH, FileAccess.WRITE)
	if f_corrupt != null:
		f_corrupt.store_string("<<<MALFORMED_JSON_STRING_NO_BRACKETS>>>")
		f_corrupt.close()

	var corrupt_gs1 = gs_script.new()
	var corrupt_res1 = corrupt_gs1.load_from_disk()
	_assert_chall(corrupt_res1 == false, "1.2.1 Corrupt syntax save load returns false")
	_assert_chall(corrupt_gs1.energy == 0.0 and corrupt_gs1.idle_level == 1, "1.2.2 Retains baseline state after corrupt syntax")
	corrupt_gs1.free()

	# 1.3 Corrupted Save Handling: Wrong Root Type (Array instead of Dict)
	var f_array = FileAccess.open(TEST_SAVE_PATH, FileAccess.WRITE)
	if f_array != null:
		f_array.store_string("[1, 2, 3, 4, 5]")
		f_array.close()

	var corrupt_gs2 = gs_script.new()
	var corrupt_res2 = corrupt_gs2.load_from_disk()
	_assert_chall(corrupt_res2 == false, "1.2.3 Array root JSON returns false")
	_assert_chall(corrupt_gs2.idle_level == 1, "1.2.4 Array root leaves state safely at defaults")
	corrupt_gs2.free()

	# 1.4 Corrupted Save Handling: Negative Integers & Boundary Fuzzing
	var fuzz_save: Dictionary = {
		"version": 1,
		"timestamp": int(Time.get_unix_time_from_system()) + 999999, # future clock
		"energy": -500.0,
		"total_energy_earned": -1000.0,
		"total_clicks": -25,
		"sparks_collected": -8,
		"bonus_users": -15,
		"avatar_speed_level": -10,
		"idle_level": -5,
		"pickup_radius_level": -3,
		"collectibles_collected": -40,
		"unlocked_zones": [123, null, "", "corrupt_null", "valid_wing"],
		"upgrades": {
			"avatar_speed": {"level": -2, "current_cost": -50.0}
		}
	}
	var f_fuzz = FileAccess.open(TEST_SAVE_PATH, FileAccess.WRITE)
	if f_fuzz != null:
		f_fuzz.store_string(JSON.stringify(fuzz_save))
		f_fuzz.close()

	var fuzz_gs = gs_script.new()
	var fuzz_load_ok = fuzz_gs.load_from_disk()
	_assert_chall(fuzz_load_ok == true, "1.2.5 Negative boundary save parses with sanitation")
	_assert_chall(fuzz_gs.energy >= 0.0, "1.2.6 Negative energy clamped to >= 0.0 (got %.1f)" % fuzz_gs.energy)
	_assert_chall(fuzz_gs.avatar_speed_level == 0, "1.2.7 Negative avatar_speed_level clamped to 0")
	_assert_chall(fuzz_gs.idle_level >= 1, "1.2.8 Negative idle_level clamped to >= 1 baseline (got %d)" % fuzz_gs.idle_level)
	_assert_chall(fuzz_gs.pickup_radius_level == 0, "1.2.9 Negative pickup_radius_level clamped to 0")
	_assert_chall(fuzz_gs.collectibles_collected == 0, "1.2.10 Negative collectibles_collected clamped to 0")
	# Check zone string filtering
	_assert_chall(fuzz_gs.unlocked_zones.has("valid_wing"), "1.2.11 Valid string zone preserved from mixed array")
	_assert_chall(not fuzz_gs.unlocked_zones.has(""), "1.2.12 Empty string zone discarded")
	fuzz_gs.free()

	# 1.5 Deep Reset State Restoration Test
	print("\n--- Testing reset_state() Deep Restoration ---")
	gs.energy = 888888.0
	gs.total_energy_earned = 999999.0
	gs.total_clicks = 4500
	gs.sparks_collected = 75
	gs.bonus_users = 30
	gs.base_click_power = 25.0
	gs.base_passive_rps = 400.0
	gs.frenzy_meter = 80.0
	gs.is_frenzy_active = true
	gs.frenzy_multiplier = 4.5
	gs.frenzy_duration_remaining = 5.0
	gs.avatar_speed_level = 7
	gs.idle_level = 5
	gs.pickup_radius_level = 4
	gs.collectibles_collected = 19
	gs.unlocked_zones.append("zone_alpha")
	gs.unlocked_zones.append("zone_beta")

	gs.reset_state()
	_assert_chall(gs.energy == 0.0, "1.3.1 reset_state() restores energy to 0.0")
	_assert_chall(gs.total_energy_earned == 0.0, "1.3.2 reset_state() restores total_energy_earned to 0.0")
	_assert_chall(gs.total_clicks == 0, "1.3.3 reset_state() restores total_clicks to 0")
	_assert_chall(gs.sparks_collected == 0, "1.3.4 reset_state() restores sparks_collected to 0")
	_assert_chall(gs.bonus_users == 0, "1.3.5 reset_state() restores bonus_users to 0")
	_assert_chall(gs.base_click_power == 1.0, "1.3.6 reset_state() restores base_click_power to 1.0")
	_assert_chall(gs.base_passive_rps == 0.0, "1.3.7 reset_state() restores base_passive_rps to 0.0")
	_assert_chall(gs.is_frenzy_active == false, "1.3.8 reset_state() deactivates frenzy")
	_assert_chall(gs.frenzy_multiplier == 1.0, "1.3.9 reset_state() restores frenzy_multiplier to 1.0")
	_assert_chall(gs.avatar_speed_level == 0, "1.3.10 reset_state() restores avatar_speed_level to 0")
	_assert_chall(gs.idle_level == 1, "1.3.11 reset_state() restores idle_level to 1")
	_assert_chall(gs.pickup_radius_level == 0, "1.3.12 reset_state() restores pickup_radius_level to 0")
	_assert_chall(gs.collectibles_collected == 0, "1.3.13 reset_state() restores collectibles_collected to 0")
	_assert_chall(gs.unlocked_zones.size() == 0, "1.3.14 reset_state() empties unlocked_zones")
	_assert_chall(gs.upgrades["avatar_speed"]["level"] == 0, "1.3.15 reset_state() resets avatar_speed upgrade level to 0")

	# =========================================================================
	# CHALLENGE 2: Overlay State Transitions & Rapid Key Alternation
	# =========================================================================
	print("\n--- Challenge 2: Overlay State Transitions & Rapid Alternation ---")

	var main_3d = main_3d_scene.instantiate() as Main3D
	root.add_child(main_3d)
	await process_frame
	await physics_frame

	var hud_overlay: CanvasLayer = main_3d.get_node_or_null("HUDOverlayLayer")
	var world_avatar: Avatar3D = main_3d.get_node_or_null("Avatar3D") as Avatar3D
	var toggle_btn: Button = main_3d.get_node_or_null("%ToggleOverlayButton") as Button
	var close_btn: Button = main_3d.get_node_or_null("%CloseOverlayButton") as Button
	var hud_inst = main_3d.get_node_or_null("HUDOverlayLayer/OverlayContainer/HUD")

	_assert_chall(hud_overlay != null and world_avatar != null, "2.0.1 Main3D core child nodes present")

	# 2.1 High-Frequency Rapid Alternation Stress Harness (100 toggles)
	var state_sync_errors: int = 0
	for i in range(100):
		var choice: int = i % 5
		match choice:
			0:
				# Simulate Tab Key
				var ev_tab = InputEventKey.new()
				ev_tab.pressed = true
				ev_tab.keycode = KEY_TAB
				main_3d._unhandled_input(ev_tab)
			1:
				# Simulate M Key
				var ev_m = InputEventKey.new()
				ev_m.pressed = true
				ev_m.keycode = KEY_M
				main_3d._unhandled_input(ev_m)
			2:
				# Simulate Toggle Button Press
				if toggle_btn != null:
					main_3d.toggle_hud_overlay()
			3:
				# Simulate Close Button Press
				if close_btn != null:
					main_3d.close_hud_overlay()
			4:
				# Simulate Escape Key
				var ev_esc = InputEventKey.new()
				ev_esc.pressed = true
				ev_esc.keycode = KEY_ESCAPE
				main_3d._unhandled_input(ev_esc)

		var is_open: bool = main_3d.is_hud_overlay_open()
		var is_vis: bool = hud_overlay.visible
		var avatar_locked: bool = not world_avatar.input_enabled

		if (is_open != is_vis) or (is_open != avatar_locked):
			state_sync_errors += 1

	_assert_chall(state_sync_errors == 0, "2.1.1 100-cycle rapid toggle state synchronization (errors: %d)" % state_sync_errors)

	# Clean state to closed
	main_3d.close_hud_overlay()
	_assert_chall(main_3d.is_hud_overlay_open() == false, "2.1.2 Overlay closed baseline established")
	_assert_chall(world_avatar.input_enabled == true, "2.1.3 Avatar input enabled when closed")

	# 2.2 Sub-Modal Dismissal Hierarchy Test
	print("\n--- Testing Sub-Modal Dismissal Hierarchy ---")
	_assert_chall(hud_inst != null, "2.2.1 Instanced HUD found under HUDOverlayLayer")

	# Open overlay
	main_3d.open_hud_overlay()
	_assert_chall(main_3d.is_hud_overlay_open() == true, "2.2.2 Overlay opened")
	_assert_chall(hud_inst.has_method("has_active_modal"), "2.2.3 HUD implements has_active_modal()")
	_assert_chall(hud_inst.has_active_modal() == false, "2.2.4 No active modal initially")

	# Create and attach a mock modal
	var mock_modal = Control.new()
	mock_modal.name = "MockModal"
	hud_inst.add_child(mock_modal)
	hud_inst.set("_active_modal", mock_modal)

	_assert_chall(hud_inst.has_active_modal() == true, "2.2.5 Sub-modal successfully set as active")

	# ESCAPE Trigger 1: Should dismiss modal, NOT close overlay!
	var ev_esc1 = InputEventKey.new()
	ev_esc1.pressed = true
	ev_esc1.keycode = KEY_ESCAPE
	main_3d._unhandled_input(ev_esc1)

	_assert_chall(hud_inst.has_active_modal() == false, "2.2.6 First ESC dismissed active sub-modal")
	_assert_chall(main_3d.is_hud_overlay_open() == true, "2.2.7 First ESC preserved HUD overlay as OPEN")
	_assert_chall(world_avatar.input_enabled == false, "2.2.8 Avatar input remains strictly suspended after sub-modal dismissal")

	# ESCAPE Trigger 2: No active modal remaining -> Should close HUD overlay!
	var ev_esc2 = InputEventKey.new()
	ev_esc2.pressed = true
	ev_esc2.keycode = KEY_ESCAPE
	main_3d._unhandled_input(ev_esc2)

	_assert_chall(main_3d.is_hud_overlay_open() == false, "2.2.9 Second ESC closed the HUD overlay")
	_assert_chall(hud_overlay.visible == false, "2.2.10 HUD overlay layer is hidden")
	_assert_chall(world_avatar.input_enabled == true, "2.2.11 Avatar input restored upon overlay closure")

	# 2.3 Avatar Input & Click Trapping Under Active Overlay
	print("\n--- Testing Avatar Input Lockout & DimBackdrop Click Trapping ---")
	var backdrop: ColorRect = main_3d.get_node_or_null("HUDOverlayLayer/OverlayContainer/DimBackdrop") as ColorRect
	_assert_chall(backdrop != null, "2.3.1 DimBackdrop found")
	_assert_chall(backdrop.mouse_filter == Control.MOUSE_FILTER_STOP, "2.3.2 DimBackdrop has MOUSE_FILTER_STOP (0) to trap clicks")

	main_3d.open_hud_overlay()
	_assert_chall(world_avatar.input_enabled == false, "2.3.3 Avatar input_enabled is false while overlay is open")

	# Attempt script movement while locked
	world_avatar.stop_movement()
	world_avatar.velocity = Vector3(10.0, 0.0, 10.0) # simulate leftover velocity
	world_avatar.set_input_enabled(false) # should invoke stop_movement()
	_assert_chall(world_avatar.velocity.x == 0.0 and world_avatar.velocity.z == 0.0,
		"2.3.4 set_input_enabled(false) instantly zeroes horizontal velocity")

	main_3d.close_hud_overlay()
	_assert_chall(world_avatar.input_enabled == true, "2.3.5 set_input_enabled(true) restored on close")

	main_3d.queue_free()
	await process_frame

	# =========================================================================
	# CHALLENGE 3: Speed Multiplier Contract Discrepancy Stress Test
	# =========================================================================
	print("\n--- Challenge 3: Avatar Speed Contract Discrepancy Analysis ---")

	var avatar_inst = avatar_scene.instantiate() as Avatar3D
	root.add_child(avatar_inst)
	await process_frame

	# Check formula in GameState
	gs.reset_state()
	var gs_mult_0 = gs.get_effective_avatar_speed()
	_assert_chall(abs(gs_mult_0 - 1.0) < 0.001, "3.1.1 GameState baseline speed multiplier is 1.00")

	gs.avatar_speed_level = 1
	var gs_mult_1 = gs.get_effective_avatar_speed()
	_assert_chall(abs(gs_mult_1 - 1.15) < 0.001, "3.1.2 GameState Level 1 speed multiplier is 1.15 (+15%)")

	gs.avatar_speed_level = 2
	var gs_mult_2 = gs.get_effective_avatar_speed()
	_assert_chall(abs(gs_mult_2 - 1.30) < 0.001, "3.1.3 GameState Level 2 speed multiplier is 1.30 (+30%)")

	# Check Avatar3D.get_move_speed() calculation
	var avatar_move_speed = avatar_inst.get_move_speed()
	var expected_contract_speed = avatar_inst.base_speed * gs_mult_2 # 6.0 * 1.30 = 7.80 m/s
	var actual_speed = avatar_move_speed

	print("  [DISCREPANCY CHECK] Avatar3D actual speed: %.2f m/s vs PROJECT.md contract: %.2f m/s" % [actual_speed, expected_contract_speed])
	if abs(actual_speed - expected_contract_speed) > 0.05:
		var diff = actual_speed - expected_contract_speed
		findings.append("Avatar3D.get_move_speed() scales at 25%% per level (got %.2f m/s) instead of 15%% per level (expected %.2f m/s) due to line 211 in avatar_3d.gd." % [actual_speed, expected_contract_speed])
		print("  [OBSERVATION] Detected avatar_3d.gd line 211 scaling discrepancy: +%.2f m/s" % diff)

	avatar_inst.queue_free()
	await process_frame
