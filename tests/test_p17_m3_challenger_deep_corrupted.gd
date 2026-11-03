extends SceneTree

## =============================================================================
## Deep Adversarial Challenger Stress Harness for Milestone 3 (Phase 17)
## Edge-Case Battery: Nested Structures, Invalid Unicode, NaN/Inf, Huge Dicts.
##
## File: IdleArcade/tests/test_p17_m3_challenger_deep_corrupted.gd
## Runner: godot --headless --path IdleArcade -s tests/test_p17_m3_challenger_deep_corrupted.gd
## =============================================================================

var pass_count: int = 0
var fail_count: int = 0

const SAVE_PATH: String = "user://savegame.json"
const BACKUP_PATH: String = "user://savegame.json.deep_backup"

func _init() -> void:
	call_deferred("_run_deep_stress_suite")

func _assert_check(condition: bool, description: String, detail: String = "") -> void:
	if condition:
		print("  [PASS] %s" % description)
		pass_count += 1
	else:
		var err_msg = "  [FAIL] %s" % description
		if detail != "":
			err_msg += " (Detail: %s)" % detail
		printerr(err_msg)
		fail_count += 1

func _backup_savegame() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var src = FileAccess.open(SAVE_PATH, FileAccess.READ)
		if src != null:
			var content = src.get_as_text()
			src.close()
			var dst = FileAccess.open(BACKUP_PATH, FileAccess.WRITE)
			if dst != null:
				dst.store_string(content)
				dst.close()

func _restore_savegame() -> void:
	if FileAccess.file_exists(BACKUP_PATH):
		var src = FileAccess.open(BACKUP_PATH, FileAccess.READ)
		if src != null:
			var content = src.get_as_text()
			src.close()
			var dst = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
			if dst != null:
				dst.store_string(content)
				dst.close()
		DirAccess.remove_absolute(ProjectSettings.globalize_path(BACKUP_PATH))
	elif FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))

func _write_raw_save(raw_content: String) -> void:
	var f = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(raw_content)
		f.close()

func _run_deep_stress_suite() -> void:
	print("=================================================================")
	print(">>> DEEP ADVERSARIAL CHALLENGER: CORRUPTED SAVES STRESS HARNESS <<<")
	print("=================================================================")

	await process_frame
	await process_frame

	_backup_savegame()

	var gs = root.get_node_or_null("GameState")
	var tm = root.get_node_or_null("TutorialManager")

	_assert_check(gs != null, "GameState autoload is reachable")
	_assert_check(tm != null, "TutorialManager autoload is reachable")

	if gs == null or tm == null:
		printerr("FATAL: GameState or TutorialManager not found.")
		_restore_savegame()
		quit(1)
		return

	# =========================================================================
	# TIER 1: Deeply Nested Structures & Collections in Savegame
	# =========================================================================
	print("\n--- TIER 1: Deeply Nested Structures & Collections in Savegame ---")

	var nested_payload = {
		"energy": 5000.0,
		"tutorial_current_step": {
			"sub_step": 3,
			"nested_list": [1, 2, 3],
			"deep": {"a": {"b": 10}}
		},
		"tutorial_completed": [true, false, {"nested": true}],
		"tutorial_skipped": {"skipped_flag": true},
		"tutorial_replay_requested": [[[[true]]]],
		"tutorial_seen_hints": {
			"hint_nested_dict": {"level2": {"level3": {"level4": true}}},
			"hint_nested_arr": [1, 2, [3, 4, [5, "seen"]]],
			"hint_empty_dict": {},
			"hint_empty_arr": [],
			"hint_dict_with_str": {"key": "true"},
			"hint_valid_under_nesting": true
		}
	}
	_write_raw_save(JSON.stringify(nested_payload))
	var res_nested = gs.load_from_disk()
	_assert_check(res_nested == true, "Nested structures payload loads without engine crash")
	_assert_check(gs.tutorial_current_step == 0,
		"tutorial_current_step handles nested dict safely -> defaults to 0 (actual: %d)" % gs.tutorial_current_step)
	_assert_check(gs.tutorial_completed == false,
		"tutorial_completed handles nested array safely -> defaults to false (actual: %s)" % str(gs.tutorial_completed))
	_assert_check(gs.tutorial_skipped == false,
		"tutorial_skipped handles nested dict safely -> defaults to false (actual: %s)" % str(gs.tutorial_skipped))
	_assert_check(gs.tutorial_replay_requested == false,
		"tutorial_replay_requested handles nested array safely -> defaults to false (actual: %s)" % str(gs.tutorial_replay_requested))
	_assert_check(gs.tutorial_seen_hints is Dictionary, "tutorial_seen_hints is a valid Dictionary")
	_assert_check(gs.tutorial_seen_hints.get("hint_valid_under_nesting") == true, "Valid boolean true preserved")
	_assert_check(gs.tutorial_seen_hints.get("hint_nested_dict") == false, "Nested dict sanitized to boolean false")
	_assert_check(gs.tutorial_seen_hints.get("hint_nested_arr") == false, "Nested arr sanitized to boolean false")
	_assert_check(gs.tutorial_seen_hints.get("hint_empty_dict") == false, "Empty dict sanitized to boolean false")
	_assert_check(gs.tutorial_seen_hints.get("hint_empty_arr") == false, "Empty arr sanitized to boolean false")

	# Verify strict TYPE_BOOL invariant across all stored hints
	var all_type_bool: bool = true
	for k in gs.tutorial_seen_hints:
		if typeof(gs.tutorial_seen_hints[k]) != TYPE_BOOL:
			all_type_bool = false
			printerr("Key '%s' has non-bool type: %d" % [k, typeof(gs.tutorial_seen_hints[k])])
	_assert_check(all_type_bool, "Strict Invariant: Every entry in tutorial_seen_hints has typeof() == TYPE_BOOL")

	# =========================================================================
	# TIER 2: Unicode, International Characters, Emojis & Whitespace Attack
	# =========================================================================
	print("\n--- TIER 2: Unicode, International Characters, Emojis & Whitespace Attack ---")

	var unicode_payload = {
		"energy": 12345.0,
		"tutorial_seen_hints": {
			"hint_🚀_rocket": true,
			"hint_💡_spark": "seen",
			"hint_Campus_Zonetor": "TRUE",
			"hint_科技树_tech": 1,
			"hint_Кириллица_test": false,
			"hint_العربية_test": 0,
			"   hint_with_surrounding_spaces   ": "true",
			"\t\nhint_tabs_newlines\r\n": true,
			"   ": true,                  # Only spaces -> must be stripped and rejected
			"\t\n\r": false,               # Only control whitespace -> rejected
			"": "seen",                    # Empty key -> rejected
			"hint_normal_after_unicode": true
		}
	}
	_write_raw_save(JSON.stringify(unicode_payload))
	var res_unicode = gs.load_from_disk()
	_assert_check(res_unicode == true, "Unicode and emoji hint keys load without error")
	_assert_check(gs.has_seen_contextual_hint("hint_🚀_rocket") == true, "Emoji key 'hint_🚀_rocket' preserved and true")
	_assert_check(gs.has_seen_contextual_hint("hint_💡_spark") == true, "Emoji key 'hint_💡_spark' parsed 'seen' to true")
	_assert_check(gs.has_seen_contextual_hint("hint_Campus_Zonetor") == true, "Case-insensitive 'TRUE' string parsed to true")
	_assert_check(gs.has_seen_contextual_hint("hint_科技树_tech") == true, "Chinese characters in key parsed int 1 to true")
	_assert_check(gs.has_seen_contextual_hint("hint_Кириллица_test") == false, "Cyrillic key parsed false correctly")
	_assert_check(gs.has_seen_contextual_hint("hint_العربية_test") == false, "Arabic key parsed 0 to false")
	_assert_check(gs.has_seen_contextual_hint("hint_with_surrounding_spaces") == true,
		"Surrounding whitespace stripped from key 'hint_with_surrounding_spaces'")
	_assert_check(gs.has_seen_contextual_hint("hint_tabs_newlines") == true,
		"Tabs and newlines stripped from key 'hint_tabs_newlines'")
	_assert_check(not gs.tutorial_seen_hints.has(""), "Blank key '' rejected")
	_assert_check(not gs.tutorial_seen_hints.has("   "), "Whitespace-only key '   ' rejected")
	_assert_check(not gs.tutorial_seen_hints.has("\t\n\r"), "Control-whitespace-only key rejected")
	_assert_check(gs.has_seen_contextual_hint("hint_normal_after_unicode") == true, "Normal key after unicode preserved")

	# =========================================================================
	# TIER 3: NaN, Inf, Extremes & String Representations of Numbers
	# =========================================================================
	print("\n--- TIER 3: NaN, Inf, Extremes & String Representations of Numbers ---")

	# 3.1 Step with string numbers and extreme values
	var step_variants = [
		{"val": "42", "expected": 42, "desc": "String integer '42' parsed to 42"},
		{"val": "-10", "expected": 0, "desc": "Negative string '-10' clamped to 0"},
		{"val": "99999", "expected": 99999, "desc": "Large string '99999' parsed"},
		{"val": "not_a_number", "expected": 0, "desc": "Non-numeric string 'not_a_number' defaults to 0"},
		{"val": 999.9, "expected": 999, "desc": "Float 999.9 converted to int 999"},
		{"val": -0.5, "expected": 0, "desc": "Negative float -0.5 clamped to 0"},
		{"val": null, "expected": 0, "desc": "Null step defaults to 0"},
		{"val": true, "expected": 0, "desc": "Boolean step defaults to 0"}
	]
	for item in step_variants:
		var step_save = {"tutorial_current_step": item["val"]}
		_write_raw_save(JSON.stringify(step_save))
		gs.load_from_disk()
		_assert_check(gs.tutorial_current_step == item["expected"],
			"Step variant: %s (actual: %d)" % [item["desc"], gs.tutorial_current_step])

	# 3.2 Floating point values in hint truthiness
	var float_hints_payload = {
		"tutorial_seen_hints": {
			"hint_pos_float": 0.0001,
			"hint_zero_float": 0.0,
			"hint_neg_float": -15.5,
			"hint_large_float": 1e20,
			"hint_nan_str": "NaN",
			"hint_inf_str": "Infinity",
			"hint_neginf_str": "-Infinity",
			"hint_null_val": null
		}
	}
	_write_raw_save(JSON.stringify(float_hints_payload))
	var res_float_hints = gs.load_from_disk()
	_assert_check(res_float_hints == true, "Float hints payload parsed cleanly")
	_assert_check(gs.has_seen_contextual_hint("hint_pos_float") == true, "0.0001 evaluates to true")
	_assert_check(gs.has_seen_contextual_hint("hint_zero_float") == false, "0.0 evaluates to false")
	_assert_check(gs.has_seen_contextual_hint("hint_neg_float") == true, "-15.5 evaluates to true")
	_assert_check(gs.has_seen_contextual_hint("hint_large_float") == true, "1e20 evaluates to true")
	_assert_check(gs.has_seen_contextual_hint("hint_nan_str") == false, "String 'NaN' evaluates to false")
	_assert_check(gs.has_seen_contextual_hint("hint_inf_str") == false, "String 'Infinity' evaluates to false")
	_assert_check(gs.has_seen_contextual_hint("hint_neginf_str") == false, "String '-Infinity' evaluates to false")
	_assert_check(gs.has_seen_contextual_hint("hint_null_val") == false, "Null value evaluates to false")

	# 3.3 Literal NaN, Infinity, -Infinity in raw JSON file syntax
	_write_raw_save("{\"tutorial_current_step\": NaN}")
	var res_lit_nan = gs.load_from_disk()
	_assert_check(res_lit_nan == false, "Literal NaN in raw JSON handled safely by load_from_disk() without crash")

	_write_raw_save("{\"tutorial_current_step\": Infinity}")
	var res_lit_inf = gs.load_from_disk()
	_assert_check(res_lit_inf == false, "Literal Infinity in raw JSON handled safely by load_from_disk() without crash")

	_write_raw_save("{\"tutorial_current_step\": -Infinity}")
	var res_lit_neginf = gs.load_from_disk()
	_assert_check(res_lit_neginf == false, "Literal -Infinity in raw JSON handled safely by load_from_disk() without crash")

	# 3.4 Raw null for tutorial_seen_hints in JSON
	_write_raw_save("{\"tutorial_seen_hints\": null, \"tutorial_current_step\": 3}")
	var res_null_hints = gs.load_from_disk()
	_assert_check(res_null_hints == true, "Null tutorial_seen_hints in JSON loads cleanly")
	_assert_check(gs.tutorial_current_step == 3, "Step parsed correctly when hints is null (actual: 3)")
	_assert_check(gs.tutorial_seen_hints is Dictionary, "tutorial_seen_hints safely falls back to Dictionary")
	_assert_check(gs.tutorial_seen_hints.is_empty(), "tutorial_seen_hints is empty when input was null")

	# 3.5 Raw array for tutorial_seen_hints in JSON
	_write_raw_save("{\"tutorial_seen_hints\": [\"a\", \"b\", \"c\"], \"tutorial_current_step\": 2}")
	var res_arr_hints = gs.load_from_disk()
	_assert_check(res_arr_hints == true, "Array tutorial_seen_hints in JSON loads cleanly")
	_assert_check(gs.tutorial_current_step == 2, "Step parsed correctly when hints is array")
	_assert_check(gs.tutorial_seen_hints is Dictionary, "tutorial_seen_hints safely falls back to Dictionary")
	_assert_check(gs.tutorial_seen_hints.is_empty(), "tutorial_seen_hints is empty when input was array")

	# 3.6 Very long key name (10,000 characters)
	var long_key: String = "hint_" + "x".repeat(10000)
	var long_key_save = {
		"tutorial_seen_hints": {
			long_key: true,
			"hint_after_long": true
		}
	}
	_write_raw_save(JSON.stringify(long_key_save))
	var res_long_key = gs.load_from_disk()
	_assert_check(res_long_key == true, "10,000-character key loads without crash")
	_assert_check(gs.has_seen_contextual_hint(long_key) == true, "10,000-character key recognized as seen")
	_assert_check(gs.has_seen_contextual_hint("hint_after_long") == true, "Subsequent key after long key recognized")

	# =========================================================================
	# TIER 4: Huge Dictionary & Scale Stress (5,000 and 10,000 keys)
	# =========================================================================
	print("\n--- TIER 4: Huge Dictionary & Scale Stress (5,000 and 10,000 keys) ---")

	var t0 = Time.get_ticks_msec()
	var huge_hints: Dictionary = {}
	for i in range(5000):
		huge_hints["huge_key_%05d" % i] = (i % 3 == 0)
	var huge_save = {
		"energy": 999999.0,
		"tutorial_current_step": 6,
		"tutorial_seen_hints": huge_hints
	}
	_write_raw_save(JSON.stringify(huge_save))
	var t_write = Time.get_ticks_msec() - t0

	var t1 = Time.get_ticks_msec()
	var res_huge = gs.load_from_disk()
	var t_load = Time.get_ticks_msec() - t1

	_assert_check(res_huge == true, "5,000 keys loaded successfully")
	_assert_check(gs.tutorial_seen_hints.size() == 5000,
		"5,000 keys retained in memory (actual: %d)" % gs.tutorial_seen_hints.size())
	_assert_check(t_load < 1000, "5,000 keys deserialization took < 1000ms (actual: %d ms)" % t_load)
	_assert_check(gs.has_seen_contextual_hint("huge_key_00000") == true, "huge_key_00000 correct (0 % 3 == 0)")
	_assert_check(gs.has_seen_contextual_hint("huge_key_00001") == false, "huge_key_00001 correct (1 % 3 != 0)")
	_assert_check(gs.has_seen_contextual_hint("huge_key_04998") == true, "huge_key_04998 correct (4998 % 3 == 0)")
	_assert_check(gs.has_seen_contextual_hint("huge_key_04999") == false, "huge_key_04999 correct (4999 % 3 != 0)")

	# Roundtrip test with save_to_disk()
	var t2 = Time.get_ticks_msec()
	gs.save_to_disk()
	var t_save = Time.get_ticks_msec() - t2
	_assert_check(t_save < 1000, "5,000 keys serialization took < 1000ms (actual: %d ms)" % t_save)

	# Read back saved file and verify JSON integrity
	var file_read = FileAccess.open(SAVE_PATH, FileAccess.READ)
	_assert_check(file_read != null, "Saved savegame.json is openable")
	var saved_text = file_read.get_as_text()
	file_read.close()
	var re_parsed = JSON.parse_string(saved_text)
	_assert_check(re_parsed is Dictionary, "Saved savegame.json is 100% valid JSON Dictionary")
	_assert_check(re_parsed.has("tutorial_seen_hints"), "Saved JSON includes 'tutorial_seen_hints'")
	_assert_check(re_parsed["tutorial_seen_hints"].size() == 5000,
		"Saved JSON retains all 5,000 hints on disk (actual: %d)" % re_parsed["tutorial_seen_hints"].size())

	# =========================================================================
	# TIER 5: Signal Integrity & Economy Protection Under Corruption
	# =========================================================================
	print("\n--- TIER 5: Signal Integrity & Economy Protection Under Corruption ---")

	var signals_fired = {
		"energy": false,
		"rps": false,
		"frenzy": false
	}

	var on_energy = func(_e, _gain): signals_fired["energy"] = true
	var on_rps = func(_r): signals_fired["rps"] = true
	var on_frenzy = func(_m, _d): signals_fired["frenzy"] = true

	gs.energy_changed.connect(on_energy)
	gs.rps_changed.connect(on_rps)
	gs.frenzy_updated.connect(on_frenzy)

	# Set baseline economy
	gs.energy = 55555.0
	gs.total_energy_earned = 88888.0
	gs.angel_shares = 42

	# Load corrupted tutorial data
	var corrupt_tutorial_only = {
		"energy": 55555.0,
		"total_energy_earned": 88888.0,
		"angel_shares": 42,
		"tutorial_current_step": "corrupted_step_not_int",
		"tutorial_completed": {"bad": "type"},
		"tutorial_skipped": [1, 2, 3],
		"tutorial_replay_requested": "not_bool",
		"tutorial_seen_hints": {"hint_bad": null, "hint_good": true}
	}
	_write_raw_save(JSON.stringify(corrupt_tutorial_only))
	var res_signals = gs.load_from_disk()

	_assert_check(res_signals == true, "Corrupted tutorial payload loads successfully")
	_assert_check(signals_fired["energy"], "energy_changed signal emitted during load_from_disk()")
	_assert_check(signals_fired["rps"], "rps_changed signal emitted during load_from_disk()")
	_assert_check(signals_fired["frenzy"], "frenzy_updated signal emitted during load_from_disk()")
	_assert_check(gs.energy == 55555.0, "Core economy energy preserved (actual: %f)" % gs.energy)
	_assert_check(gs.angel_shares == 42, "Prestige angel shares preserved (actual: %d)" % gs.angel_shares)

	gs.energy_changed.disconnect(on_energy)
	gs.rps_changed.disconnect(on_rps)
	gs.frenzy_updated.disconnect(on_frenzy)

	# =========================================================================
	# TIER 6: Reset Isolation After Extreme Corruption
	# =========================================================================
	print("\n--- TIER 6: Reset Isolation After Extreme Corruption ---")

	gs.reset_tutorial_state()
	_assert_check(gs.tutorial_current_step == 0, "After reset: tutorial_current_step is 0")
	_assert_check(gs.tutorial_completed == false, "After reset: tutorial_completed is false")
	_assert_check(gs.tutorial_skipped == false, "After reset: tutorial_skipped is false")
	_assert_check(gs.tutorial_replay_requested == true, "After reset: tutorial_replay_requested is true")
	_assert_check(gs.tutorial_seen_hints.is_empty(), "After reset: tutorial_seen_hints is empty")
	_assert_check(gs.is_first_time_player() == true, "After reset: is_first_time_player() is true")

	# Teardown & Restore
	_restore_savegame()

	print("\n=================================================================")
	print("DEEP ADVERSARIAL CHALLENGER SUMMARY: %d Passed, %d Failed" % [pass_count, fail_count])
	print("=================================================================")

	if fail_count > 0:
		quit(1)
	else:
		quit(0)
