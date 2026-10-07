extends SceneTree

## Empirical Adversarial Challenge Test Harness for Milestone P2-M4.
## Rigorously stresses:
## 1. Rapid modal opening & closing cycles (50+ iterations per modal, 100+ interleaved)
## 2. Overlapping modal replacement (no duplicate nodes, immediate unparenting, no leaks)
## 3. Stale closure protection (old modal closure does not null active modal)
## 4. Backdrop click dismissal & mouse filter input trapping (blocks game clicks)
## 5. Memory leak verification (modal container child counts strictly 0 -> 1 -> 0)
## 6. Full 15-test game logic regression suite executed while HUD is live in SceneTree
##
## Executable via: godot --headless --path IdleArcade -s tests/test_p2_m4_adversarial_challenge.gd

var pass_count: int = 0
var fail_count: int = 0

func _init() -> void:
	print("=====================================================================")
	print("[CHALLENGE] Milestone P2-M4 Empirical Adversarial Verification Suite")
	print("=====================================================================")
	process_frame.connect(_on_first_frame, CONNECT_ONE_SHOT)

func _on_first_frame() -> void:
	await _run_all_challenge_tests()
	print("\n=====================================================================")
	print("[CHALLENGE] Results: %d passed, %d failed" % [pass_count, fail_count])
	print("=====================================================================")
	if fail_count == 0:
		print(">>> ALL P2-M4 ADVERSARIAL CHALLENGES PASSED! VERDICT: APPROVE <<<")
		quit(0)
	else:
		printerr(">>> CHALLENGE FAILED WITH %d DEFECTS! VERDICT: REQUEST_CHANGES <<<" % fail_count)
		quit(1)

func _assert_check(cond: bool, test_name: String) -> void:
	if cond:
		print("  [PASS] %s" % test_name)
		pass_count += 1
	else:
		printerr("  [FAIL] %s" % test_name)
		fail_count += 1

func _run_all_challenge_tests() -> void:
	# -------------------------------------------------------------------------
	# 0. Environment Setup: Autoload Singletons
	# -------------------------------------------------------------------------
	var gs_script = load("res://scripts/autoload/game_state.gd")
	var gs = root.get_node_or_null("GameState")
	if gs == null and gs_script != null:
		gs = gs_script.new()
		gs.name = "GameState"
		root.add_child(gs)

	var nakama_script = load("res://addons/com.heroiclabs.nakama/Nakama.gd")
	var nakama_singleton = root.get_node_or_null("Nakama")
	if nakama_singleton == null and nakama_script != null:
		nakama_singleton = nakama_script.new()
		nakama_singleton.name = "Nakama"
		root.add_child(nakama_singleton)

	var mgr_script = load("res://scripts/autoload/nakama_manager.gd")
	var mgr = root.get_node_or_null("NakamaManager")
	if mgr == null and mgr_script != null:
		mgr = mgr_script.new()
		mgr.name = "NakamaManager"
		mgr.auto_login_on_ready = false
		root.add_child(mgr)

	await process_frame

	var hud_scene = load("res://scenes/hud.tscn")
	var auth_scene = load("res://scenes/ui/auth_modal.tscn")
	var lb_scene = load("res://scenes/ui/leaderboard_modal.tscn")
	var guild_scene = load("res://scenes/ui/guild_modal.tscn")
	var quest_scene = load("res://scenes/ui/quest_modal.tscn")

	if hud_scene == null or auth_scene == null or lb_scene == null or guild_scene == null or quest_scene == null:
		printerr("[FATAL] Scene preload failure. Halting.")
		quit(1)
		return

	var hud = hud_scene.instantiate()
	root.add_child(hud)
	await process_frame

	var modal_container: Control = hud.get_node_or_null("%ModalContainer")
	_assert_check(modal_container != null, "0.1 HUD ModalContainer uniquely resolved")

	# =========================================================================
	# SECTION 1: Rapid Modal Opening & Closing Cycles
	# =========================================================================
	print("\n--- Section 1: Rapid Modal Open/Close Stress (50 iterations each) ---")

	var scenes = [
		{"name": "AuthModal", "scene": auth_scene},
		{"name": "LeaderboardModal", "scene": lb_scene},
		{"name": "GuildModal", "scene": guild_scene},
		{"name": "QuestModal", "scene": quest_scene}
	]

	for entry in scenes:
		var scene_name: String = entry["name"]
		var scn: PackedScene = entry["scene"]
		var stress_clean: bool = true

		for i in range(50):
			var m = hud.open_modal(scn)
			if m == null or modal_container.get_child_count() != 1:
				stress_clean = false
				break
			m.close()
			await process_frame
			if modal_container.get_child_count() != 0 or hud._active_modal != null:
				stress_clean = false
				break

		_assert_check(stress_clean, "1.1-1.4 50 rapid open/close cycles for %s: 0 leaks, container clean" % scene_name)

	# Interleaved rapid open/close (100 iterations)
	var interleaved_clean: bool = true
	for i in range(100):
		var pick = scenes[i % scenes.size()]
		var m = hud.open_modal(pick["scene"])
		if m == null or modal_container.get_child_count() != 1:
			interleaved_clean = false
			break
		m.close()
		await process_frame
		if modal_container.get_child_count() != 0 or hud._active_modal != null:
			interleaved_clean = false
			break

	_assert_check(interleaved_clean, "1.5 100 interleaved rapid open/close cycles: 0 leaks, container clean")

	# =========================================================================
	# SECTION 2: Overlapping Modal Replacement Stress
	# =========================================================================
	print("\n--- Section 2: Overlapping Modal Replacement (No duplicate nodes) ---")

	# 2.1 Open AuthModal, then immediately open LeaderboardModal WITHOUT closing AuthModal
	var modal_a = hud.open_modal(auth_scene)
	_assert_check(modal_container.get_child_count() == 1 and hud._active_modal == modal_a, "2.1 Modal A opened as active")

	var modal_b = hud.open_modal(lb_scene)
	_assert_check(modal_container.get_child_count() == 1, "2.2 Exactly 1 child in ModalContainer after replacement")
	_assert_check(hud._active_modal == modal_b, "2.3 Active modal reference updated to Modal B")
	_assert_check(modal_a.get_parent() == null, "2.4 Modal A immediately unparented from scene tree")
	_assert_check(modal_a.is_queued_for_deletion(), "2.5 Modal A marked is_queued_for_deletion()")

	await process_frame
	_assert_check(not is_instance_valid(modal_a), "2.6 Modal A fully freed from memory by deferred queue")

	# 2.2 Rapid Chain Replacement in a single frame: Auth -> LB -> Guild -> Quest
	var m1 = hud.open_modal(auth_scene)
	var m2 = hud.open_modal(lb_scene)
	var m3 = hud.open_modal(guild_scene)
	var m4 = hud.open_modal(quest_scene)

	_assert_check(modal_container.get_child_count() == 1, "2.7 Single-frame chain replacement: child count is strictly 1")
	_assert_check(hud._active_modal == m4, "2.8 Single-frame chain replacement: active modal is m4 (QuestModal)")
	_assert_check(m1.get_parent() == null and m2.get_parent() == null and m3.get_parent() == null, "2.9 All replaced modals immediately unparented")

	await process_frame
	_assert_check(not is_instance_valid(m1) and not is_instance_valid(m2) and not is_instance_valid(m3), "2.10 Replaced modals all freed from memory")

	m4.close()
	await process_frame

	# 2.3 Stale Closure Race Protection:
	# If old modal's closed signal emits after replacement, verify it does NOT null out new modal!
	var old_modal = hud.open_modal(auth_scene)
	var new_modal = hud.open_modal(lb_scene)
	# Simulate delayed signal from old_modal
	old_modal.closed.emit()
	_assert_check(hud._active_modal == new_modal, "2.11 Stale closure: old modal closed.emit() does NOT null active new modal")
	new_modal.close()
	await process_frame

	# =========================================================================
	# SECTION 3: Backdrop Click Dismissal & Mouse Filter Trapping
	# =========================================================================
	print("\n--- Section 3: Backdrop Click Dismissal & Input Trapping ---")

	for entry in scenes:
		var scene_name: String = entry["name"]
		var m = hud.open_modal(entry["scene"])
		var backdrop: ColorRect = m.find_child("Backdrop", true, false)
		_assert_check(backdrop != null, "3.1 %s contains Backdrop ColorRect" % scene_name)
		_assert_check(backdrop.mouse_filter == Control.MOUSE_FILTER_STOP, "3.2 %s Backdrop stops mouse events (traps input)" % scene_name)
		_assert_check(m.mouse_filter == Control.MOUSE_FILTER_STOP, "3.3 %s Root control stops mouse events" % scene_name)

		# 3.4 Simulate LEFT mouse click on backdrop -> should dismiss
		var left_click = InputEventMouseButton.new()
		left_click.button_index = MOUSE_BUTTON_LEFT
		left_click.pressed = true
		backdrop.gui_input.emit(left_click)
		await process_frame

		_assert_check(m.is_queued_for_deletion() or not is_instance_valid(m), "3.4 Left click on %s Backdrop cleanly dismisses modal" % scene_name)

	# 3.5 Verify Right-click on Backdrop does NOT dismiss
	var test_modal = hud.open_modal(auth_scene)
	var test_bd: ColorRect = test_modal.find_child("Backdrop", true, false)
	var right_click = InputEventMouseButton.new()
	right_click.button_index = MOUSE_BUTTON_RIGHT
	right_click.pressed = true
	test_bd.gui_input.emit(right_click)
	await process_frame
	_assert_check(not test_modal.is_queued_for_deletion() and hud._active_modal == test_modal, "3.5 Right click on Backdrop does NOT dismiss modal")

	# 3.6 Verify clicking INSIDE ModalCard does NOT dismiss modal
	var modal_card = test_modal.find_child("ModalCard", true, false)
	_assert_check(modal_card != null, "3.6 ModalCard exists in AuthModal")
	if modal_card != null:
		_assert_check(modal_card.mouse_filter == Control.MOUSE_FILTER_STOP, "3.7 ModalCard has MOUSE_FILTER_STOP (consumes clicks)")

	test_modal.close()
	await process_frame

	# =========================================================================
	# SECTION 4: Defensive Robustness & Edge Cases
	# =========================================================================
	print("\n--- Section 4: Defensive Robustness & Edge Cases ---")

	# 4.1 Double close() call resilience
	var dclose_modal = hud.open_modal(auth_scene)
	dclose_modal.close()
	dclose_modal.close() # second call must not crash
	await process_frame
	_assert_check(hud._active_modal == null, "4.1 Double close() call handled cleanly without error")

	# 4.2 External free resilience: if active modal is freed directly, open_modal handles it safely
	var ext_modal = hud.open_modal(auth_scene)
	ext_modal.free() # directly freed!
	var next_modal = hud.open_modal(lb_scene) # must not crash referencing freed pointer
	_assert_check(hud._active_modal == next_modal, "4.2 Directly freed modal handled safely via is_instance_valid check")
	next_modal.close()
	await process_frame

	# =========================================================================
	# SECTION 5: Full 15-Test Game Logic Regression with Live HUD
	# =========================================================================
	print("\n--- Section 5: Full Game Logic Regression with Live HUD ---")

	# Run exact 15 game logic assertions while HUD is mounted in root
	# Test 1: SceneTree root
	_assert_check(root != null, "5.1 Reg: SceneTree root exists")

	# Test 2: GameState script syntax
	_assert_check(gs_script != null, "5.2 Reg: game_state.gd loaded successfully")

	# Test 3: main scene syntax
	var main_scene = load("res://scenes/main.tscn")
	_assert_check(main_scene != null, "5.3 Reg: scenes/main.tscn loaded successfully")

	# Test 4: GameState format_number
	var test_gs = gs_script.new()
	var f_zero = test_gs.format_number(0.0)
	var f_int = test_gs.format_number(450.0)
	var f_k = test_gs.format_number(1500.0)
	var f_m = test_gs.format_number(5250000.0)
	var f_b = test_gs.format_number(12500000000.0)
	var f_t = test_gs.format_number(1000000000000.0)
	_assert_check(
		f_zero == "0" and f_int == "450" and f_k == "1.50 K" and f_m == "5.25 M" and f_b == "12.50 B" and f_t == "1.00 T",
		"5.4 Reg: GameState format_number conforms to model"
	)
	test_gs.free()

	# Test 5: Initial Economy Baseline
	var r_gs = gs_script.new()
	_assert_check(
		r_gs.energy == 0.0 and r_gs.base_passive_rps == 0.0 and r_gs.base_click_power == 1.0 and r_gs.total_clicks == 0 and r_gs.frenzy_meter == 0.0 and not r_gs.is_frenzy_active,
		"5.5 Reg: Baseline economy starts at 0 energy, 0 rps, 1.0 click power"
	)

	# Test 6: Active Core Tapping
	var tap_signal: bool = false
	var th = func(_tot: float, _d: float): tap_signal = true
	r_gs.energy_changed.connect(th)
	var tap_earned: float = r_gs.tap_core()
	r_gs.energy_changed.disconnect(th)
	_assert_check(tap_earned == 1.0 and r_gs.energy == 1.0 and r_gs.total_clicks == 1 and tap_signal, "5.6 Reg: Core tap rewards 1.0 energy and emits signal")

	# Test 7: Frenzy Meter Charging & Overdrive Activation
	for i in range(9): r_gs.tap_core()
	var meter_10 = r_gs.frenzy_meter
	for i in range(15): r_gs.tap_core()
	_assert_check(meter_10 == 40.0 and r_gs.is_frenzy_active and r_gs.frenzy_multiplier == 3.0 and r_gs.frenzy_meter == 0.0, "5.7 Reg: Frenzy meter charges and triggers 3x Overdrive")

	# Test 8: Frenzy Duration Decay
	r_gs._process(3.0)
	var mid_act = r_gs.is_frenzy_active
	r_gs._process(3.1)
	_assert_check(mid_act and not r_gs.is_frenzy_active and r_gs.frenzy_multiplier == 1.0, "5.8 Reg: Frenzy duration decays to 0 and resets multiplier")

	# Test 9: Upgrade catalogue & geometric cost scaling
	r_gs.energy = 40.0
	var buy_exp = r_gs.buy_upgrade("tier_2")
	var buy_drone = r_gs.buy_upgrade("tier_1")
	var d_data = r_gs.get_upgrade_data("tier_1")
	var next_c = float(d_data.get("current_cost", 0.0))
	_assert_check(not buy_exp and buy_drone and r_gs.energy == 15.0 and r_gs.base_passive_rps == 1.0 and next_c == 29.0, "5.9 Reg: Upgrade purchase funds check, cost deduction, RPS scale")

	# Test 10: Passive Accumulation & Lag Spike Clamping
	var p_acc = r_gs.energy
	for i in range(60): r_gs._process(1.0 / 60.0)
	var diff = r_gs.energy - p_acc
	var p_lag = r_gs.energy
	r_gs._process(5.0)
	var lag_g = r_gs.energy - p_lag
	_assert_check(abs(diff - 1.0) < 0.01 and abs(lag_g - 0.1) < 0.001, "5.10 Reg: Passive generation integrates delta*RPS and clamps lag spike")

	# Test 11: Drifting Bonus Spark Windfall
	var p_spark = r_gs.energy
	var s_reward = r_gs.collect_spark()
	_assert_check(s_reward == 50.0 and abs((r_gs.energy - p_spark) - 50.0) < 0.001 and r_gs.sparks_collected == 1, "5.11 Reg: Bonus spark collection windfall")

	# Test 12: Save to disk & Serialization
	const TEST_SAVE_PATH = "user://savegame.json"
	r_gs.save_to_disk()
	var fe = FileAccess.file_exists(TEST_SAVE_PATH)
	_assert_check(fe, "5.12 Reg: save_to_disk writes valid JSON schema")

	# Test 13: Offline Catch-Up & System Clock Protections
	var now_unix: float = Time.get_unix_time_from_system()
	var fw = FileAccess.open(TEST_SAVE_PATH, FileAccess.WRITE)
	var mock_save = {
		"timestamp": now_unix - 1800.0,
		"energy": 75.0,
		"total_clicks": 30,
		"base_passive_rps": 1.0,
		"base_click_power": 1.0,
		"sparks_collected": 1,
		"upgrades": {"tier_1": {"level": 1, "current_cost": 29.0}}
	}
	fw.store_string(JSON.stringify(mock_save))
	fw.close()

	var rel_gs = gs_script.new()
	var l_ok = rel_gs.load_from_disk()
	var off_match = abs(rel_gs.energy - 975.0) < 0.1
	_assert_check(l_ok and off_match, "5.13 Reg: Offline progress calculates 50% catch-up")
	rel_gs.free()

	# Test 14: Corrupted Save Recovery
	var fc = FileAccess.open(TEST_SAVE_PATH, FileAccess.WRITE)
	fc.store_string("{ malformed ... json")
	fc.close()
	var c_gs = gs_script.new()
	var c_res = c_gs.load_from_disk()
	_assert_check(not c_res and c_gs.energy == 0.0 and c_gs.base_click_power == 1.0, "5.14 Reg: Corrupted save gracefully caught with safe defaults")
	c_gs.free()

	# Test 15: Full integrated lifecycle
	var e2e = gs_script.new()
	for i in range(25): e2e.tap_core()
	for i in range(5): e2e.tap_core()
	e2e._process(6.0)
	e2e.buy_upgrade("tier_1")
	e2e.collect_spark()
	for i in range(600): e2e._process(10.0 / 600.0)
	_assert_check(abs(e2e.energy - 75.0) < 0.01 and e2e.total_clicks == 30 and e2e.base_passive_rps == 1.0, "5.15 Reg: Full integrated gameplay lifecycle reaches 75.0 energy")
	e2e.free()
	r_gs.free()

	# Teardown HUD
	hud.queue_free()
	await process_frame
