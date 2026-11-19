extends SceneTree

## =============================================================================
## Phase 18 Milestone 3: Domain 6 Adversarial Challenger Stress Suite
## File: IdleArcade/tests/test_p18_m3_challenger_stress.gd
##
## Empirical stress-testing of Domain 6 Scenarios 4 to 7:
##   Scenario 4: Corrupted Save Recovery Matrix (10 modes + extreme adversarial inputs)
##   Scenario 5: Rapid UI Stress & Tap Deduplication (1-frame storming, 100 taps, pointer isolation)
##   Scenario 6: Offline Progression Boundary Precision (8-case matrix, sharp 28800s clamp, F1 compound order)
##   Scenario 7: Lifecycle Teardown & Leak Audit (MIN_EXPECTED_PASS_COUNT >= 1800, orphan node inspection, signal disconnects)
##
## Target: Godot 4.3 Headless Runner
## Command: godot --headless --path IdleArcade -s tests/test_p18_m3_challenger_stress.gd
## =============================================================================

var pass_count: int = 0
var fail_count: int = 0
var findings: Array[String] = []

const SAVE_PATH: String = "user://savegame.json"
const EPSILON: float = 0.005

var _save_backup_text: String = ""
var _had_save_backup: bool = false
var _mounted_singletons: Array[Node] = []

func _assert_check(condition: bool, description: String, detail: String = "") -> void:
	if condition:
		print("  [PASS] %s" % description)
		pass_count += 1
	else:
		var err_msg: String = "  [FAIL] %s" % description
		if detail != "":
			err_msg += " (Detail: %s)" % detail
		printerr(err_msg)
		findings.append(err_msg)
		fail_count += 1

func _init() -> void:
	print("\n====================================================================")
	print(">>> RUNNING P18-M3 CHALLENGER 2: DOMAIN 6 EMPIRICAL STRESS SUITE <<<")
	print("====================================================================")

	# Backup save file synchronously before any autoloads can write to it
	if FileAccess.file_exists(SAVE_PATH):
		var f_back = FileAccess.open(SAVE_PATH, FileAccess.READ)
		if f_back != null:
			_save_backup_text = f_back.get_as_text()
			_had_save_backup = true
			f_back.close()
	else:
		_had_save_backup = false

	call_deferred("_run_challenger_stress_suite")

func _teardown_and_quit(exit_code: int) -> void:
	print("\n--- TEARDOWN: Restoring Environment & Cleaning Singletons ---")
	if _had_save_backup:
		var f_res: FileAccess = null
		for attempt in range(10):
			f_res = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
			if f_res != null:
				break
			OS.delay_msec(5)
		if f_res != null:
			f_res.store_string(_save_backup_text)
			f_res.flush()
			f_res.close()
			print("  [CLEANUP] Restored original %s" % SAVE_PATH)
	elif FileAccess.file_exists(SAVE_PATH):
		for attempt in range(10):
			var del_err = DirAccess.remove_absolute(SAVE_PATH)
			if del_err == OK and not FileAccess.file_exists(SAVE_PATH):
				break
			OS.delay_msec(5)
		print("  [CLEANUP] Removed temporary %s" % SAVE_PATH)
	# Clean up mounted test singletons
	for i in range(_mounted_singletons.size() - 1, -1, -1):
		var node = _mounted_singletons[i]
		if is_instance_valid(node):
			if node.get_parent() != null:
				node.get_parent().remove_child(node)
			node.free()
	_mounted_singletons.clear()
	print("  [CLEANUP] All test harness singletons safely unmounted.")

	print("\n====================================================================")
	print(">>> P18-M3 CHALLENGER 2 SUMMARY: %d PASSED, %d FAILED <<<" % [pass_count, fail_count])
	print("====================================================================")
	if fail_count == 0:
		print(">>> EMPIRICAL VERDICT: APPROVE (100% GREEN INTEGRITY) <<<")
	else:
		print(">>> EMPIRICAL VERDICT: REQUEST_CHANGES (%d FAILURES DETECTED) <<<" % fail_count)
		for f in findings:
			print("   - %s" % f)

	quit(0 if fail_count == 0 else 1)

func _run_challenger_stress_suite() -> void:
	await process_frame

	# -------------------------------------------------------------------------
	# Mount Autoload Singletons Harness
	# -------------------------------------------------------------------------
	print("\n--- STAGE 0: Autoload Singletons Mounting ---")
	var gs = _mount_singleton("GameState", "res://scripts/autoload/game_state.gd")
	var nakama = _mount_singleton("Nakama", "res://addons/com.heroiclabs.nakama/Nakama.gd")
	var nakama_mgr = _mount_singleton("NakamaManager", "res://scripts/autoload/nakama_manager.gd")
	var haptics = _mount_singleton("HapticsManager", "res://scripts/autoload/haptics_manager.gd")
	var audio = _mount_singleton("AudioManager", "res://scripts/autoload/audio_manager.gd")
	var live_event = _mount_singleton("LiveEventManager", "res://scripts/autoload/live_event_manager.gd")
	var tutorial = _mount_singleton("TutorialManager", "res://scripts/autoload/tutorial_manager.gd")

	_assert_check(gs != null, "0.1 GameState mounted")
	_assert_check(nakama != null, "0.2 Nakama mounted")
	_assert_check(nakama_mgr != null, "0.3 NakamaManager mounted")
	_assert_check(haptics != null, "0.4 HapticsManager mounted")
	_assert_check(audio != null, "0.5 AudioManager mounted")
	_assert_check(live_event != null, "0.6 LiveEventManager mounted")
	_assert_check(tutorial != null, "0.7 TutorialManager mounted")

	if gs == null:
		printerr("[FATAL] GameState failed to mount.")
		_teardown_and_quit(1)
		return

	# Run the 4 adversarial stress test suites
	await _test_scenario_4_corrupted_save_recovery_stress(gs)
	await _test_scenario_5_rapid_ui_stress_and_tap_dedup(gs)
	await _test_scenario_6_offline_progression_boundary_stress(gs)
	await _test_scenario_7_lifecycle_teardown_and_leak_audit(gs)

	_teardown_and_quit(0 if fail_count == 0 else 1)

func _mount_singleton(node_name: String, script_path: String) -> Node:
	var existing = root.get_node_or_null(node_name)
	if existing != null:
		return existing
	var script = load(script_path)
	if script == null:
		printerr("[ERROR] Failed to load %s" % script_path)
		return null
	var inst: Node = script.new()
	inst.name = node_name
	root.add_child(inst)
	_mounted_singletons.append(inst)
	return inst


## =============================================================================
## SCENARIO 4: CORRUPTED SAVE RECOVERY MATRIX (ADVERSARIAL STRESS)
## =============================================================================
func _test_scenario_4_corrupted_save_recovery_stress(gs: Node) -> void:
	print("\n====================================================================")
	print(">>> SUITE 1: SCENARIO 4 — CORRUPTED SAVE RECOVERY MATRIX (12 MODES) <<<")
	print("====================================================================")

	# Mode 1: Missing file
	if FileAccess.file_exists(SAVE_PATH):
		for attempt in range(10):
			var del_err = DirAccess.remove_absolute(SAVE_PATH)
			if del_err == OK and not FileAccess.file_exists(SAVE_PATH):
				break
			await process_frame
	gs.reset_state()
	await process_frame
	_assert_check(not FileAccess.file_exists(SAVE_PATH), "S4.1 Mode 1: Savegame verified absent")
	var m1_ok = gs.load_from_disk()
	_assert_check(m1_ok == false, "S4.2 Mode 1: load_from_disk() returns false on missing file")
	_assert_check(gs.energy >= 0.0, "S4.3 Mode 1: Invariant energy >= 0 preserved")
	await process_frame

	# Mode 2: 0-byte file
	var f_empty: FileAccess = null
	for attempt in range(10):
		f_empty = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		if f_empty != null:
			break
		await process_frame
	if f_empty != null:
		f_empty.flush()
		f_empty.close()
	await process_frame
	await process_frame
	var m2_ok = gs.load_from_disk()
	_assert_check(m2_ok == false, "S4.4 Mode 2: load_from_disk() returns false on 0-byte file")
	await process_frame

	# Mode 3A: Syntax Error - Truncated JSON
	var f3a: FileAccess = null
	for attempt in range(10):
		f3a = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		if f3a != null:
			break
		await process_frame
	if f3a != null:
		f3a.store_string("{ \"energy\": 1000.0, \"upgrades\": { \"tier_1\": ")
		f3a.flush()
		f3a.close()
	await process_frame
	await process_frame
	var m3a_ok = gs.load_from_disk()
	_assert_check(m3a_ok == false, "S4.5 Mode 3A: Truncated JSON returns false")
	await process_frame

	# Mode 3B: Syntax Error - Trailing Garbage
	var f3b: FileAccess = null
	for attempt in range(10):
		f3b = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		if f3b != null:
			break
		await process_frame
	if f3b != null:
		f3b.store_string("{\"version\": 1, \"energy\": 500.0} JUNK_DATA_TRAILING_BYTES")
		f3b.flush()
		f3b.close()
	await process_frame
	await process_frame
	var m3b_ok = gs.load_from_disk()
	_assert_check(m3b_ok == false, "S4.6 Mode 3B: Trailing garbage returns false")
	await process_frame

	# Mode 3C: Syntax Error - Null Byte Injection
	var f3c: FileAccess = null
	for attempt in range(10):
		f3c = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		if f3c != null:
			break
		await process_frame
	if f3c != null:
		var null_byte_buf = '{"version": 1, '.to_utf8_buffer()
		null_byte_buf.append(0x00)
		null_byte_buf.append_array('"energy": 500.0}'.to_utf8_buffer())
		f3c.store_buffer(null_byte_buf)
		f3c.flush()
		f3c.close()
	await process_frame
	await process_frame
	var m3c_ok = gs.load_from_disk()
	_assert_check(m3c_ok == false, "S4.7 Mode 3C: Null byte injection returns false")
	await process_frame

	# Mode 3D: Syntax Error - Raw Binary Garbage
	var f3d: FileAccess = null
	for attempt in range(10):
		f3d = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		if f3d != null:
			break
		await process_frame
	if f3d != null:
		var raw_bin = PackedByteArray([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0xFF, 0xFE])
		f3d.store_buffer(raw_bin)
		f3d.flush()
		f3d.close()
	await process_frame
	await process_frame
	var m3d_ok = gs.load_from_disk()
	_assert_check(m3d_ok == false, "S4.8 Mode 3D: Raw binary blob returns false safely")
	await process_frame

	# Mode 4A-4F: Non-Dictionary Root Types
	var non_dict_cases: Array[Dictionary] = [
		{"name": "Array", "content": "[1, 2, 3, {\"energy\": 500.0}]"},
		{"name": "Integer", "content": "12345"},
		{"name": "Float", "content": "99.999"},
		{"name": "String", "content": "\"corrupted string root\""},
		{"name": "Boolean", "content": "true"},
		{"name": "Null", "content": "null"}
	]
	var case_idx: int = 9
	for nd in non_dict_cases:
		var f_nd: FileAccess = null
		for attempt in range(10):
			f_nd = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
			if f_nd != null:
				break
			await process_frame
		if f_nd != null:
			f_nd.store_string(nd["content"])
			f_nd.flush()
			f_nd.close()
		await process_frame
		await process_frame
		var nd_ok = gs.load_from_disk()
		_assert_check(nd_ok == false, "S4.%d Mode 4 (%s root): returns false without crash" % [case_idx, nd["name"]])
		case_idx += 1
		await process_frame

	# Mode 5: Numeric Type Poisoning (Strings, Arrays in Numeric Fields)
	var f5: FileAccess = null
	for attempt in range(10):
		f5 = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		if f5 != null:
			break
		await process_frame
	if f5 != null:
		f5.store_string('{\n' +
			'\t"version": 1,\n' +
			'\t"energy": "poison_string_energy",\n' +
			'\t"total_energy_earned": "poison_earned",\n' +
			'\t"total_lifetime_energy": "poison_lifetime",\n' +
			'\t"total_clicks": "invalid_clicks",\n' +
			'\t"angel_shares": "invalid_shares",\n' +
			'\t"idle_level": "twenty",\n' +
			'\t"bonus_users": "lots"\n' +
		'}')
		f5.flush()
		f5.close()
	await process_frame
	await process_frame
	var m5_ok = gs.load_from_disk()
	_assert_check(m5_ok == true, "S4.15 Mode 5: Type-poisoned dictionary loads and sanitizes")
	_assert_check(absf(gs.energy - 0.0) < EPSILON, "S4.16 Mode 5: String in energy sanitized to 0.0")
	_assert_check(gs.total_clicks == 0, "S4.17 Mode 5: String in total_clicks sanitized to 0")
	_assert_check(gs.angel_shares == 0, "S4.18 Mode 5: String in angel_shares sanitized to 0")
	_assert_check(gs.idle_level >= 1, "S4.19 Mode 5: String in idle_level defaulted to >= 1")
	_assert_check(gs.total_lifetime_energy >= gs.total_energy_earned, "S4.20 Mode 5: Invariant total_lifetime >= total_earned holds")
	await process_frame

	# Mode 6: NaN & Infinity Injection
	var f6: FileAccess = null
	for attempt in range(10):
		f6 = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		if f6 != null:
			break
		await process_frame
	if f6 != null:
		f6.store_string('{\n' +
			'\t"version": 1,\n' +
			'\t"energy": "NaN",\n' +
			'\t"total_energy_earned": "Infinity",\n' +
			'\t"total_lifetime_energy": "-Infinity",\n' +
			'\t"audio_settings": {"master_volume": "NaN"}\n' +
		'}')
		f6.flush()
		f6.close()
	await process_frame
	await process_frame
	var m6_ok = gs.load_from_disk()
	_assert_check(m6_ok == true, "S4.21 Mode 6: NaN/Infinity payload processed cleanly")
	_assert_check(not is_nan(gs.energy) and not is_inf(gs.energy), "S4.22 Mode 6: energy is finite")
	_assert_check(absf(gs.energy - 0.0) < EPSILON, "S4.23 Mode 6: NaN energy clamped to 0.0")
	_assert_check(not is_inf(gs.total_energy_earned), "S4.24 Mode 6: Infinity total_earned clamped")
	_assert_check(not is_inf(gs.total_lifetime_energy), "S4.25 Mode 6: -Infinity total_lifetime clamped")
	_assert_check(not is_nan(gs.master_volume) and gs.master_volume >= 0.0 and gs.master_volume <= 1.0,
		"S4.26 Mode 6: NaN master_volume clamped to [0.0, 1.0]")
	await process_frame

	# Mode 7: Negative Values Injection
	var f7: FileAccess = null
	for attempt in range(10):
		f7 = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		if f7 != null:
			break
		await process_frame
	if f7 != null:
		f7.store_string('{\n' +
			'\t"version": 1,\n' +
			'\t"energy": -999999.0,\n' +
			'\t"total_energy_earned": -500.0,\n' +
			'\t"total_lifetime_energy": -12345.0,\n' +
			'\t"total_clicks": -100,\n' +
			'\t"sparks_collected": -25,\n' +
			'\t"angel_shares": -10,\n' +
			'\t"daily_board_streak": -5,\n' +
			'\t"idle_level": -3\n' +
			'}')
		f7.flush()
		f7.close()
	await process_frame
	await process_frame
	var m7_ok = gs.load_from_disk()
	_assert_check(m7_ok == true, "S4.27 Mode 7: Negative values payload parsed successfully")
	_assert_check(absf(gs.energy - 0.0) < EPSILON, "S4.28 Mode 7: Negative energy clamped to 0.0")
	_assert_check(gs.total_energy_earned >= 0.0, "S4.29 Mode 7: Negative total_earned clamped non-negative")
	_assert_check(gs.total_clicks == 0, "S4.30 Mode 7: Negative total_clicks clamped to 0")
	_assert_check(gs.sparks_collected == 0, "S4.31 Mode 7: Negative sparks_collected clamped to 0")
	_assert_check(gs.angel_shares == 0, "S4.32 Mode 7: Negative angel_shares clamped to 0")
	_assert_check(gs.daily_board_streak == 0, "S4.33 Mode 7: Negative daily_board_streak clamped to 0")
	_assert_check(gs.idle_level == 1, "S4.34 Mode 7: Negative idle_level clamped to 1")
	await process_frame

	# Mode 8: Legacy / Partial Save Schema
	var f8: FileAccess = null
	for attempt in range(10):
		f8 = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		if f8 != null:
			break
		await process_frame
	if f8 != null:
		f8.store_string('{\n' +
			'\t"version": 1,\n' +
			'\t"energy": 2500.0,\n' +
			'\t"total_clicks": 150\n' +
			'}')
		f8.flush()
		f8.close()
	await process_frame
	await process_frame
	var m8_ok = gs.load_from_disk()
	_assert_check(m8_ok == true, "S4.35 Mode 8: Legacy partial save loaded successfully")
	_assert_check(absf(gs.energy - 2500.0) < 50.0, "S4.36 Mode 8: Legacy energy restored (~2,500.0)")
	_assert_check(gs.total_clicks == 150, "S4.37 Mode 8: Legacy total_clicks restored (150)")
	_assert_check(not gs.is_in_syndicate(), "S4.38 Mode 8: Missing syndicate defaults to unaffiliated")
	_assert_check(gs.get_hired_workers().is_empty(), "S4.39 Mode 8: Missing staff defaults to empty array")
	_assert_check(gs.get_desk_levels() == [1, 1, 1, 1, 1], "S4.40 Mode 8: Missing desk_levels defaults to [1,1,1,1,1]")
	_assert_check(gs.tutorial_completed == false, "S4.41 Mode 8: Missing tutorial defaults to incomplete")
	_assert_check(gs.station_cooldowns.size() >= 3, "S4.42 Mode 8: Station cooldowns cleanly initialized")
	await process_frame

	# Mode 9: Poisoned Collections & Nested Structures
	var f9: FileAccess = null
	for attempt in range(10):
		f9 = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		if f9 != null:
			break
		await process_frame
	if f9 != null:
		f9.store_string('{\n' +
			'\t"version": 1,\n' +
			'\t"researched_techs": [null, 9999, "", "tech_delivery_drone", true, {"invalid": 1}],\n' +
			'\t"unlocked_trophies": [null, 42, "trophy_golden_briefcase", ""],\n' +
			'\t"item_inventory": {"coffee": -10, "briefcase": 5, "usb_drive": "three"},\n' +
			'\t"staff": {\n' +
			'\t\t"workers": [null, "bad_worker", {"role": "fake_role"}, {"role": "Frontend Dev", "morale": 2.5, "fatigue": -0.5, "desk_assigned": 10}],\n' +
			'\t\t"desk_levels": [-2, 0, 3, 99, "bad"]\n' +
			'\t},\n' +
			'\t"syndicate": {\n' +
			'\t\t"active_id": "syn_poisoned",\n' +
			'\t\t"tier": 50,\n' +
			'\t\t"fund_energy": -1000.0\n' +
			'\t}\n' +
			'}')
		f9.flush()
		f9.close()
	await process_frame
	await process_frame
	var m9_ok = gs.load_from_disk()
	_assert_check(m9_ok == true, "S4.43 Mode 9: Poisoned collections parsed cleanly")
	_assert_check(gs.researched_techs == ["tech_delivery_drone"], "S4.44 Mode 9: researched_techs sanitized to valid string only")
	_assert_check(gs.unlocked_trophies == ["trophy_golden_briefcase"], "S4.45 Mode 9: unlocked_trophies sanitized to valid string only")
	_assert_check(gs.item_inventory["coffee"] == 0, "S4.46 Mode 9: item_inventory clamped negative coffee to 0")
	_assert_check(gs.item_inventory["briefcase"] == 5, "S4.47 Mode 9: item_inventory retained valid briefcase count (5)")
	_assert_check(gs.get_hired_workers().size() == 1, "S4.48 Mode 9: staff workers pruned nulls and fake roles (1 worker loaded)")
	var w = gs.get_worker("Frontend Dev")
	_assert_check(float(w.get("morale", -1.0)) <= 1.0, "S4.49 Mode 9: worker morale clamped <= 1.0")
	_assert_check(float(w.get("fatigue", -1.0)) >= 0.0, "S4.50 Mode 9: worker fatigue clamped >= 0.0")
	_assert_check(int(w.get("desk_assigned", -1)) <= 4, "S4.51 Mode 9: desk_assigned clamped <= 4")
	_assert_check(gs.syndicate_tier <= 5, "S4.52 Mode 9: syndicate_tier clamped to max 5")
	_assert_check(gs.syndicate_fund_energy >= 0.0, "S4.53 Mode 9: syndicate_fund_energy clamped non-negative")
	await process_frame

	# Mode 10: Clock Rollback / Extreme Future Timestamp
	var future_ts: float = Time.get_unix_time_from_system() + 5000000.0
	var f10: FileAccess = null
	for attempt in range(10):
		f10 = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		if f10 != null:
			break
		await process_frame
	if f10 != null:
		f10.store_string('{\n' +
			'\t"version": 1,\n' +
			'\t"timestamp": ' + str(int(future_ts)) + ',\n' +
			'\t"energy": 8000.0,\n' +
			'\t"base_passive_rps": 100.0,\n' +
			'\t"station_cooldowns": {"server_terminal": 45.0}\n' +
			'}')
		f10.flush()
		f10.close()
	await process_frame
	await process_frame
	var m10_ok = gs.load_from_disk()
	_assert_check(m10_ok == true, "S4.54 Mode 10: Future timestamp save loaded successfully")
	_assert_check(absf(gs.energy - 8000.0) < EPSILON, "S4.55 Mode 10: Clock rollback guard clamped offline elapsed time to 0.0s (energy intact)")
	_assert_check(absf(gs.get_station_cooldown("server_terminal") - 45.0) < EPSILON, "S4.56 Mode 10: Station cooldown protected from negative time dilation")
	await process_frame

	# Mode 11 (Adversarial): Deeply Nested JSON Hierarchy (40 levels)
	var deep_json: String = "{"
	for i in range(40):
		deep_json += '"level_%d": {' % i
	deep_json += '"leaf": 42'
	for i in range(40):
		deep_json += "}"
	deep_json += "}"
	var f11: FileAccess = null
	for attempt in range(10):
		f11 = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		if f11 != null:
			break
		await process_frame
	if f11 != null:
		f11.store_string(deep_json)
		f11.flush()
		f11.close()
	await process_frame
	await process_frame
	var m11_ok = gs.load_from_disk()
	_assert_check(m11_ok == true, "S4.57 Mode 11 (Adversarial): 40-level deep nested JSON parsed without stack overflow")
	await process_frame

	# Mode 12 (Adversarial): Extreme Numeric Overflow / Underflow Strings
	var f12: FileAccess = null
	for attempt in range(10):
		f12 = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		if f12 != null:
			break
		await process_frame
	if f12 != null:
		f12.store_string('{\n' +
			'\t"version": 1,\n' +
			'\t"energy": 1e308,\n' +
			'\t"total_energy_earned": 1e308,\n' +
			'\t"total_lifetime_energy": 1e308\n' +
			'}')
		f12.flush()
		f12.close()
	await process_frame
	await process_frame
	var m12_ok = gs.load_from_disk()
	_assert_check(m12_ok == true, "S4.58 Mode 12 (Adversarial): Extreme double (1e308) loaded without engine crash")
	_assert_check(not is_nan(gs.energy), "S4.59 Mode 12 (Adversarial): Energy is not NaN")
	await process_frame

	# Cleanup temporary savegame
	if FileAccess.file_exists(SAVE_PATH):
		for attempt in range(10):
			var del_err = DirAccess.remove_absolute(SAVE_PATH)
			if del_err == OK and not FileAccess.file_exists(SAVE_PATH):
				break
			await process_frame
	gs.reset_state()
	await process_frame


## =============================================================================
## SCENARIO 5: RAPID UI STRESS & TAP DEDUPLICATION
## =============================================================================
func _test_scenario_5_rapid_ui_stress_and_tap_dedup(gs: Node) -> void:
	print("\n====================================================================")
	print(">>> SUITE 2: SCENARIO 5 — RAPID UI STRESS & TAP DEDUPLICATION <<<")
	print("====================================================================")

	# -------------------------------------------------------------------------
	# Part A: 1-Frame Rapid Modal Storming (All 8 Modals)
	# -------------------------------------------------------------------------
	print("  [Part A: 1-Frame Rapid Modal Storming]")
	var frame_start: int = Engine.get_process_frames()

	# 1. ShopPanel (in HUD)
	var hud_scene = load("res://scenes/hud.tscn")
	_assert_check(hud_scene != null, "S5.1 res://scenes/hud.tscn loaded")
	var hud = hud_scene.instantiate() as Control
	root.add_child(hud)
	var shop = hud.get_node_or_null("BottomContainer/ShopPanel") as Control
	_assert_check(shop != null, "S5.2 ShopPanel found in HUD")
	shop.visible = true
	shop.visible = false
	_assert_check(shop.visible == false, "S5.3 Modal 1 (ShopPanel) toggled in 1 frame")

	# 2. DialoguePanel
	var dial_scene = load("res://scenes/dialogue_panel.tscn")
	var dial = dial_scene.instantiate() as DialoguePanel
	root.add_child(dial)
	dial.open_for_npc("alex", "Alex", "CEO", "Welcome!", "", "", "", 1, 0.0, 0, Color.CYAN, null, [], 1)
	dial.close_dialogue()
	_assert_check(dial.visible == false, "S5.4 Modal 2 (DialoguePanel) cycled in 1 frame")
	dial.queue_free()

	# 3. TechTreeModal
	var tech_scene = load("res://scenes/ui/tech_tree_modal.tscn")
	var tech = tech_scene.instantiate() as Control
	root.add_child(tech)
	tech.open()
	tech.close()
	_assert_check(tech.visible == false, "S5.5 Modal 3 (TechTreeModal) cycled in 1 frame")
	tech.queue_free()

	# 4. SettingsModal
	var sett_scene = load("res://scenes/ui/settings_modal.tscn")
	var sett = sett_scene.instantiate() as Control
	root.add_child(sett)
	sett.open()
	sett.close()
	_assert_check(sett.visible == false, "S5.6 Modal 4 (SettingsModal) cycled in 1 frame")
	sett.queue_free()

	# 5. IpoModal
	var ipo_scene = load("res://scenes/ui/ipo_modal.tscn")
	var ipo = ipo_scene.instantiate() as Control
	root.add_child(ipo)
	ipo.open()
	ipo.close()
	_assert_check(ipo.visible == false, "S5.7 Modal 5 (IpoModal) cycled in 1 frame")
	ipo.queue_free()

	# 6. DailyBoardModal
	var daily_scene = load("res://scenes/ui/daily_board_modal.tscn")
	var daily = daily_scene.instantiate() as Control
	root.add_child(daily)
	daily.open()
	daily.close()
	_assert_check(daily.visible == false, "S5.8 Modal 6 (DailyBoardModal) cycled in 1 frame")
	daily.queue_free()

	# 7. SyndicateModal
	var syn_scene = load("res://scenes/ui/syndicate_modal.tscn")
	var syn = syn_scene.instantiate() as Control
	root.add_child(syn)
	syn.open()
	syn.close()
	_assert_check(syn.is_queued_for_deletion() or not syn.visible, "S5.9 Modal 7 (SyndicateModal) closed in 1 frame")

	# 8. StaffModal
	var staff_scene = load("res://scenes/ui/staff_modal.tscn")
	var staff = staff_scene.instantiate() as Control
	root.add_child(staff)
	staff.open()
	staff.close()
	_assert_check(staff.is_queued_for_deletion() or not staff.visible, "S5.10 Modal 8 (StaffModal) closed in 1 frame")

	var frame_end: int = Engine.get_process_frames()
	_assert_check(frame_start == frame_end, "S5.11 1-Frame Storming Invariant: All 8 modals cycled in exact frame %d" % frame_start)

	hud.queue_free()
	await process_frame

	# -------------------------------------------------------------------------
	# Part B: 100 Consecutive Rapid Taps Across Engine Frames
	# -------------------------------------------------------------------------
	print("\n  [Part B: 100 Consecutive Rapid Taps Across Frame Boundaries]")
	var core_scene = load("res://scenes/core.tscn")
	_assert_check(core_scene != null, "S5.12 res://scenes/core.tscn loaded")
	var core_node = core_scene.instantiate()
	root.add_child(core_node)
	await process_frame

	var base_clicks: int = gs.total_clicks

	# Test B1: 100 rapid taps in a single frame
	for i in range(100):
		core_node._trigger_tap()

	_assert_check(gs.total_clicks == base_clicks + 1, "S5.13 100 taps in single frame deduplicated to exactly 1 registered click (+1)")
	_assert_check(core_node._last_tap_frame == Engine.get_process_frames(), "S5.14 _last_tap_frame matches current process frame")

	# Test B2: 100 rapid taps spread over 10 consecutive frames (10 taps / frame)
	var clicks_before_burst = gs.total_clicks
	for f in range(10):
		await process_frame
		for t in range(10):
			core_node._trigger_tap()

	var clicks_after_burst = gs.total_clicks
	var burst_gain = clicks_after_burst - clicks_before_burst
	_assert_check(burst_gain == 10, "S5.15 100 taps across 10 distinct frames registered exactly 10 clicks (+10, actual: %d)" % burst_gain)

	# Test B3: Rapid tap Frenzy Meter trigger (25 distinct frame taps)
	gs.reset_state()
	_assert_check(not gs.is_frenzy_active and gs.frenzy_meter == 0.0, "S5.16 Clean baseline for Frenzy stress")
	for f in range(25):
		await process_frame
		core_node._trigger_tap()

	_assert_check(gs.is_frenzy_active == true, "S5.17 25 sequential frame taps triggered Frenzy Overdrive successfully")
	_assert_check(absf(gs.frenzy_meter - 0.0) < EPSILON, "S5.18 Frenzy meter reset to 0.0 on Overdrive activation")
	_assert_check(gs.frenzy_multiplier >= 3.0, "S5.19 Frenzy multiplier active (>= 3.0x)")

	core_node.queue_free()
	await process_frame

	# -------------------------------------------------------------------------
	# Part C: Pointer Isolation Audit (mouse_filter = STOP)
	# -------------------------------------------------------------------------
	print("\n  [Part C: Pointer Isolation Audit]")
	var tc_scene = load("res://scenes/ui/touch_controls.tscn")
	var tc = tc_scene.instantiate() as TouchControls
	root.add_child(tc)
	await process_frame

	var joystick = tc.get_node_or_null("VirtualJoystick") as Control
	_assert_check(joystick != null and joystick.mouse_filter == Control.MOUSE_FILTER_STOP, "S5.20 VirtualJoystick mouse_filter == STOP (0)")

	var dial_inst = dial_scene.instantiate() as Control
	root.add_child(dial_inst)
	_assert_check(dial_inst.mouse_filter == Control.MOUSE_FILTER_STOP, "S5.21 DialoguePanel mouse_filter == STOP (0)")
	dial_inst.queue_free()

	var tech_inst = tech_scene.instantiate() as Control
	root.add_child(tech_inst)
	_assert_check(tech_inst.mouse_filter == Control.MOUSE_FILTER_STOP, "S5.22 TechTreeModal mouse_filter == STOP (0)")
	tech_inst.queue_free()

	var staff_inst = staff_scene.instantiate() as Control
	root.add_child(staff_inst)
	_assert_check(staff_inst.mouse_filter == Control.MOUSE_FILTER_STOP, "S5.23 StaffModal mouse_filter == STOP (0)")
	staff_inst.queue_free()

	var main_3d_scene = load("res://scenes/main_3d.tscn")
	if main_3d_scene != null:
		var main_3d = main_3d_scene.instantiate()
		var spacer = main_3d.find_child("Spacer", true, false) as Control
		_assert_check(spacer != null and spacer.mouse_filter == Control.MOUSE_FILTER_STOP, "S5.24 QuickHUD/BarHBox/Spacer mouse_filter == STOP (0)")
		main_3d.queue_free()

	tc.queue_free()
	await process_frame


## =============================================================================
## SCENARIO 6: OFFLINE PROGRESSION BOUNDARY PRECISION
## =============================================================================
func _test_scenario_6_offline_progression_boundary_stress(gs: Node) -> void:
	print("\n====================================================================")
	print(">>> SUITE 3: SCENARIO 6 — OFFLINE PROGRESSION BOUNDARY PRECISION <<<")
	print("====================================================================")

	# Disable process loop to prevent frame tick energy changes
	(gs as Node).set_process(false)
	gs.reset_state()
	gs.base_passive_rps = 0.0
	gs.energy = 0.0
	gs.total_energy_earned = 0.0
	gs.total_lifetime_energy = 0.0
	await process_frame

	var now_unix: float = Time.get_unix_time_from_system()

	# -------------------------------------------------------------------------
	# 8-Case Matrix
	# -------------------------------------------------------------------------
	# Case 1: 0s Offline (0 RPS prevents frame yield duration from inflating energy)
	_write_offline_save(now_unix, 0.0, 0.0)
	await process_frame
	await process_frame
	gs.load_from_disk()
	_assert_check(absf(gs.energy - 0.0) < 1.0, "S6.1 Case 1: 0s offline yields exactly 0.0 energy")
	await process_frame

	# Case 2: 60s Offline (1 Minute) -> 100 * 60 * 0.5 = 3,000.0
	now_unix = Time.get_unix_time_from_system()
	_write_offline_save(now_unix - 60.0, 0.0, 100.0)
	await process_frame
	await process_frame
	gs.load_from_disk()
	_assert_check(absf(gs.energy - 3000.0) < 5.0, "S6.2 Case 2: 60s offline yields 3,000.0 energy (actual: %.1f)" % gs.energy)
	await process_frame

	# Case 3: 3,600s Offline (1 Hour) -> 100 * 3600 * 0.5 = 180,000.0
	now_unix = Time.get_unix_time_from_system()
	_write_offline_save(now_unix - 3600.0, 0.0, 100.0)
	await process_frame
	await process_frame
	gs.load_from_disk()
	_assert_check(absf(gs.energy - 180000.0) < 10.0, "S6.3 Case 3: 1h offline yields 180,000.0 energy (actual: %.1f)" % gs.energy)
	await process_frame

	# Case 4: 28,800.0s Offline (8h Exact Cap) -> 100 * 28800 * 0.5 = 1,440,000.0
	now_unix = Time.get_unix_time_from_system()
	_write_offline_save(now_unix - 28800.0, 0.0, 100.0)
	await process_frame
	await process_frame
	gs.load_from_disk()
	_assert_check(absf(gs.energy - 1440000.0) < 10.0, "S6.4 Case 4: 8h exact cap yields 1,440,000.0 energy (actual: %.1f)" % gs.energy)
	await process_frame

	# Case 5: 86,400.0s Offline (24h Clamped to 8h) -> exactly 1,440,000.0
	now_unix = Time.get_unix_time_from_system()
	_write_offline_save(now_unix - 86400.0, 0.0, 100.0)
	await process_frame
	await process_frame
	gs.load_from_disk()
	_assert_check(absf(gs.energy - 1440000.0) < 10.0, "S6.5 Case 5: 24h offline strictly clamped to 8h cap (1,440,000.0)")
	_assert_check(gs.energy < 2000000.0, "S6.6 Case 5: Energy is strictly below unclamped 4.32M")
	await process_frame

	# Case 6: Clock Rollback Guard (-3,600s)
	now_unix = Time.get_unix_time_from_system()
	_write_offline_save(now_unix + 3600.0, 5000.0, 100.0)
	await process_frame
	await process_frame
	gs.load_from_disk()
	_assert_check(absf(gs.energy - 5000.0) < EPSILON, "S6.7 Case 6: Clock rollback yields 0 gain and retains existing 5,000.0")
	await process_frame

	# Case 7: Station Cooldown Offline Decay (60s CD, 30s offline -> 30s remaining)
	now_unix = Time.get_unix_time_from_system()
	_write_offline_save_with_cd(now_unix - 30.0, "server_terminal", 60.0)
	await process_frame
	await process_frame
	gs.load_from_disk()
	var cd7 = gs.get_station_cooldown("server_terminal")
	_assert_check(absf(cd7 - 30.0) < 1.0, "S6.8 Case 7: Station cooldown decayed to 30.0s (actual: %.1f)" % cd7)
	_assert_check(gs.is_station_on_cooldown("server_terminal") == true, "S6.9 Case 7: Station remains on cooldown")
	await process_frame

	# Case 8: Station Cooldown Offline Expiry (60s CD, 120s offline -> 0.0s remaining)
	now_unix = Time.get_unix_time_from_system()
	_write_offline_save_with_cd(now_unix - 120.0, "server_terminal", 60.0)
	await process_frame
	await process_frame
	gs.load_from_disk()
	var cd8 = gs.get_station_cooldown("server_terminal")
	_assert_check(absf(cd8 - 0.0) < EPSILON, "S6.10 Case 8: Station cooldown expired to 0.0s (actual: %.1f)" % cd8)
	_assert_check(gs.is_station_ready("server_terminal") == true, "S6.11 Case 8: Station is ready for interaction")
	await process_frame

	# -------------------------------------------------------------------------
	# Sharp Boundary Stress: 28,799s vs 28,800s vs 28,801s
	# -------------------------------------------------------------------------
	print("\n  [Sharp Boundary Stress: 28,799s vs 28,800s vs 28,801s]")
	# 28,799.0s -> 100 * 28799 * 0.5 = 1,439,950.0
	now_unix = Time.get_unix_time_from_system()
	_write_offline_save(now_unix - 28799.0, 0.0, 100.0)
	await process_frame
	await process_frame
	gs.load_from_disk()
	_assert_check(absf(gs.energy - 1439950.0) < 10.0, "S6.12 28,799s offline yields 1,439,950.0 (pre-clamp)")
	await process_frame

	# 28,800.0s -> 100 * 28800 * 0.5 = 1,440,000.0
	now_unix = Time.get_unix_time_from_system()
	_write_offline_save(now_unix - 28800.0, 0.0, 100.0)
	await process_frame
	await process_frame
	gs.load_from_disk()
	_assert_check(absf(gs.energy - 1440000.0) < 10.0, "S6.13 28,800s offline yields 1,440,000.0 (exact cap)")
	await process_frame

	# 28,801.0s -> minf(28801, 28800) = 28,800.0 -> 1,440,000.0
	now_unix = Time.get_unix_time_from_system()
	_write_offline_save(now_unix - 28801.0, 0.0, 100.0)
	await process_frame
	await process_frame
	gs.load_from_disk()
	_assert_check(absf(gs.energy - 1440000.0) < 10.0, "S6.14 28,801s offline clamped to 1,440,000.0 (post-clamp invariant)")
	await process_frame

	# -------------------------------------------------------------------------
	# F1 Fix Verification: Compound Multiplier Offline Gain Order
	# -------------------------------------------------------------------------
	print("\n  [F1 Fix Verification: Compound Multiplier Application]")
	# Save file with 100 base RPS, Syndicate Tier 1 (+5%), Staff 5 workers (+25%), tech_server_overclock (+25%)
	# Compound RPS = 100 * 1.05 * 1.25 * 1.25 = 164.0625 RPS
	# 3,600s offline gain = 164.0625 * 3600 * 0.5 = 295,312.5 Energy
	var compound_save: Dictionary = {
		"version": 1,
		"timestamp": now_unix - 3600.0,
		"energy": 0.0,
		"total_energy_earned": 0.0,
		"total_lifetime_energy": 0.0,
		"upgrades": {"tier_1": {"level": 100}},
		"researched_techs": ["tech_server_overclock"],
		"syndicate": {
			"active_id": "syn_compound_test",
			"tier": 1
		},
		"staff": {
			"workers": [
				{"role": "Frontend Dev", "morale": 1.0, "fatigue": 0.0},
				{"role": "Backend Dev", "morale": 1.0, "fatigue": 0.0},
				{"role": "UI/UX Designer", "morale": 1.0, "fatigue": 0.0},
				{"role": "Growth Hacker", "morale": 1.0, "fatigue": 0.0},
				{"role": "QA Engineer", "morale": 1.0, "fatigue": 0.0}
			],
			"desk_levels": [1, 1, 1, 1, 1]
		}
	}
	var fc: FileAccess = null
	for attempt in range(10):
		fc = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		if fc != null:
			break
		OS.delay_msec(2)
	if fc != null:
		fc.store_string(JSON.stringify(compound_save))
		fc.flush()
		fc.close()
	await process_frame
	await process_frame

	gs.load_from_disk()
	var eff_compound_rps = gs.get_effective_passive_rps()
	_assert_check(absf(eff_compound_rps - 164.0625) < 1.0, "S6.15 Compound RPS matches 164.0625 (actual: %.4f)" % eff_compound_rps)
	_assert_check(absf(gs.energy - 295312.5) < 50.0,
		"S6.16 F1 Deserialization Order Verified: Compound offline gain is 295,312.5 (actual: %.1f)" % gs.energy)
	await process_frame

	# Clean save and re-enable process loop
	if FileAccess.file_exists(SAVE_PATH):
		for attempt in range(10):
			var del_err = DirAccess.remove_absolute(SAVE_PATH)
			if del_err == OK and not FileAccess.file_exists(SAVE_PATH):
				break
			await process_frame
	gs.reset_state()
	(gs as Node).set_process(true)
	await process_frame

func _write_offline_save(timestamp: float, current_energy: float, base_rps: float) -> void:
	var s: Dictionary = {
		"version": 1,
		"timestamp": timestamp,
		"energy": current_energy,
		"total_energy_earned": current_energy,
		"total_lifetime_energy": current_energy,
		"base_passive_rps": base_rps
	}
	var f: FileAccess = null
	for attempt in range(10):
		f = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		if f != null:
			break
		OS.delay_msec(2)
	if f != null:
		f.store_string(JSON.stringify(s))
		f.flush()
		f.close()
	else:
		printerr("[ERROR] _write_offline_save failed to open ", SAVE_PATH)

func _write_offline_save_with_cd(timestamp: float, station_id: String, cd_duration: float) -> void:
	var s: Dictionary = {
		"version": 1,
		"timestamp": timestamp,
		"energy": 1000.0,
		"total_energy_earned": 1000.0,
		"total_lifetime_energy": 1000.0,
		"base_passive_rps": 100.0,
		"station_cooldowns": {
			station_id: cd_duration
		}
	}
	var f: FileAccess = null
	for attempt in range(10):
		f = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		if f != null:
			break
		OS.delay_msec(2)
	if f != null:
		f.store_string(JSON.stringify(s))
		f.flush()
		f.close()
	else:
		printerr("[ERROR] _write_offline_save_with_cd failed to open ", SAVE_PATH)


## =============================================================================
## SCENARIO 7: LIFECYCLE TEARDOWN & LEAK AUDIT
## =============================================================================
func _test_scenario_7_lifecycle_teardown_and_leak_audit(gs: Node) -> void:
	print("\n====================================================================")
	print(">>> SUITE 4: SCENARIO 7 — LIFECYCLE TEARDOWN & LEAK AUDIT <<<")
	print("====================================================================")

	# -------------------------------------------------------------------------
	# 1. MIN_EXPECTED_PASS_COUNT Static & Dynamic Audit
	# -------------------------------------------------------------------------
	var f_qa = FileAccess.open("res://tests/test_full_stack_qa.gd", FileAccess.READ)
	_assert_check(f_qa != null, "S7.1 res://tests/test_full_stack_qa.gd opened for constant check")
	if f_qa != null:
		var qa_content = f_qa.get_as_text()
		f_qa.close()
		var has_threshold: bool = qa_content.contains("const MIN_EXPECTED_PASS_COUNT: int = 1800")
		_assert_check(has_threshold, "S7.2 MIN_EXPECTED_PASS_COUNT is configured to 1800 in test_full_stack_qa.gd")

	# -------------------------------------------------------------------------
	# 2. Scene Tree Cleanliness Audit (7 Autoload Singletons Under /root)
	# -------------------------------------------------------------------------
	var valid_singletons: Array[String] = [
		"GameState", "Nakama", "NakamaManager", "HapticsManager",
		"AudioManager", "LiveEventManager", "TutorialManager"
	]
	var stray_nodes: Array[String] = []
	for child in root.get_children():
		if child.name not in valid_singletons:
			stray_nodes.append(child.name)

	_assert_check(stray_nodes.is_empty(), "S7.3 Root scene tree has 0 stray unparented nodes", "Stray: %s" % str(stray_nodes))

	# -------------------------------------------------------------------------
	# 3. Orphan Node Inspection Across Modal Lifecycles
	# -------------------------------------------------------------------------
	var initial_orphans: int = Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)

	# Instantiate, mount, unmount, and free a modal
	var sett_scene = load("res://scenes/ui/settings_modal.tscn")
	var sett_inst = sett_scene.instantiate()
	root.add_child(sett_inst)
	await process_frame
	root.remove_child(sett_inst)
	sett_inst.free()
	await process_frame

	var post_orphans: int = Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	_assert_check(post_orphans <= initial_orphans, "S7.4 Modal instantiation/free cycle created 0 orphan nodes (delta: %d)" % [post_orphans - initial_orphans])

	# -------------------------------------------------------------------------
	# 4. Signal Disconnection & Clean Teardown
	# -------------------------------------------------------------------------
	var callback_count: Array[int] = [0]
	var test_cb_2arg: Callable = func(_arg1, _arg2):
		callback_count[0] += 1
	var test_cb_1arg: Callable = func(_arg1):
		callback_count[0] += 1

	# Connect 3 real GameState signals
	gs.energy_changed.connect(test_cb_2arg)
	gs.frenzy_updated.connect(test_cb_2arg)
	gs.rps_changed.connect(test_cb_1arg)

	_assert_check(gs.energy_changed.is_connected(test_cb_2arg), "S7.5 energy_changed connected")
	_assert_check(gs.frenzy_updated.is_connected(test_cb_2arg), "S7.6 frenzy_updated connected")
	_assert_check(gs.rps_changed.is_connected(test_cb_1arg), "S7.7 rps_changed connected")

	# Emit while connected
	gs.energy_changed.emit(10.0, 5.0)
	gs.rps_changed.emit(50.0)
	_assert_check(callback_count[0] == 2, "S7.8 Callbacks invoked while connected (count: 2)")

	# Disconnect all
	gs.energy_changed.disconnect(test_cb_2arg)
	gs.frenzy_updated.disconnect(test_cb_2arg)
	gs.rps_changed.disconnect(test_cb_1arg)

	_assert_check(not gs.energy_changed.is_connected(test_cb_2arg), "S7.9 energy_changed cleanly disconnected")
	_assert_check(not gs.frenzy_updated.is_connected(test_cb_2arg), "S7.10 frenzy_updated cleanly disconnected")
	_assert_check(not gs.rps_changed.is_connected(test_cb_1arg), "S7.11 rps_changed cleanly disconnected")

	# Emit after disconnection
	gs.energy_changed.emit(20.0, 10.0)
	gs.frenzy_updated.emit(3.0, 1.0)
	gs.rps_changed.emit(100.0)

	_assert_check(callback_count[0] == 2, "S7.12 No signals leaked to disconnected callback (count remained 2)")
