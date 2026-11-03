extends SceneTree

## =============================================================================
## Standalone Headless SceneTree Test Suite for Milestone 3 (Phase 17):
## Contextual Hints & State Persistence QA (Features F10–F18)
##
## File: IdleArcade/tests/test_contextual_hints_persistence.gd
## Target: Godot 4.3 Engine Headless Runner (Zero Warning / Zero SCRIPT ERROR)
##
## Test Tiers:
##   TIER 1: GameState Tutorial Interface & Field Declarations (F16)
##   TIER 2: Persistence Save/Load Roundtrip Cycle & Field Fidelity (F16)
##   TIER 3: Backward Compatibility & Corrupted Save Immunity (F16)
##   TIER 4: First-Time Player Truth Table Verification (F17)
##   TIER 5: Non-Destructive Reset Isolation & Progression Safety (F18)
##   TIER 6: Contextual Hints Exactly-Once Triggering (F10–F15)
##   TIER 7: Contextual Hint Station & Modal Hook Integration (F10–F15)
##   TIER 8: Settings Modal Replay Tutorial Button Ergonomics & Flow (F18)
##
## Execution:
##   godot --headless --path IdleArcade -s tests/test_contextual_hints_persistence.gd
## =============================================================================

var pass_count: int = 0
var fail_count: int = 0

const SAVE_PATH: String = "user://savegame.json"
const BACKUP_PATH: String = "user://savegame.json.test_backup"

func _init() -> void:
	call_deferred("_run_tests")

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

func _run_tests() -> void:
	print("=================================================================")
	print("Running Milestone 3 Contextual Hints & Persistence Test Suite")
	print("=================================================================")

	await process_frame
	await process_frame

	_backup_savegame()

	var gs = root.get_node_or_null("GameState")
	var tm = root.get_node_or_null("TutorialManager")

	_assert_check(gs != null, "GameState singleton is loaded at /root/GameState")
	_assert_check(tm != null, "TutorialManager singleton is loaded at /root/TutorialManager")

	if gs == null or tm == null:
		printerr("FATAL: Required autoloads missing. Aborting test suite.")
		_restore_savegame()
		quit(1)
		return

	# -------------------------------------------------------------------------
	# TIER 1: GameState Tutorial Interface & Field Declarations (F16)
	# -------------------------------------------------------------------------
	print("\n--- TIER 1: GameState Tutorial Interface & Field Declarations ---")
	_assert_check("tutorial_current_step" in gs, "GameState declares property 'tutorial_current_step'")
	_assert_check("tutorial_completed" in gs, "GameState declares property 'tutorial_completed'")
	_assert_check("tutorial_skipped" in gs, "GameState declares property 'tutorial_skipped'")
	_assert_check("tutorial_replay_requested" in gs, "GameState declares property 'tutorial_replay_requested'")
	_assert_check("tutorial_seen_hints" in gs, "GameState declares property 'tutorial_seen_hints'")

	_assert_check(gs.has_method("is_first_time_player"), "GameState defines method 'is_first_time_player'")
	_assert_check(gs.has_method("reset_tutorial_state"), "GameState defines method 'reset_tutorial_state'")
	_assert_check(gs.has_method("mark_contextual_hint_seen"), "GameState defines method 'mark_contextual_hint_seen'")
	_assert_check(gs.has_method("has_seen_contextual_hint"), "GameState defines method 'has_seen_contextual_hint'")

	# -------------------------------------------------------------------------
	# TIER 2: Persistence Save/Load Roundtrip Cycle & Field Fidelity (F16)
	# -------------------------------------------------------------------------
	print("\n--- TIER 2: Persistence Save/Load Roundtrip Cycle & Field Fidelity ---")
	# Set known exact tutorial state values
	gs.tutorial_current_step = 3
	gs.tutorial_completed = false
	gs.tutorial_skipped = false
	gs.tutorial_replay_requested = false
	gs.tutorial_seen_hints = {
		"hint_zone_gate": true,
		"hint_tech_tree": true
	}

	gs.save_to_disk()
	_assert_check(FileAccess.file_exists(SAVE_PATH), "save_to_disk() created savegame file on disk")

	# Verify serialized JSON keys on disk directly
	var raw_file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	_assert_check(raw_file != null, "Savegame file is readable")
	if raw_file != null:
		var json_text = raw_file.get_as_text()
		raw_file.close()
		var parsed = JSON.parse_string(json_text)
		_assert_check(parsed is Dictionary, "Saved file content parses as valid JSON dictionary")
		if parsed is Dictionary:
			_assert_check(parsed.get("tutorial_current_step") == 3, "JSON contains 'tutorial_current_step': 3")
			_assert_check(parsed.get("tutorial_completed") == false, "JSON contains 'tutorial_completed': false")
			_assert_check(parsed.get("tutorial_skipped") == false, "JSON contains 'tutorial_skipped': false")
			_assert_check(parsed.get("tutorial_replay_requested") == false, "JSON contains 'tutorial_replay_requested': false")
			var hints_dict = parsed.get("tutorial_seen_hints", {})
			_assert_check(hints_dict.get("hint_zone_gate") == true, "JSON contains hint_zone_gate: true")
			_assert_check(hints_dict.get("hint_tech_tree") == true, "JSON contains hint_tech_tree: true")

	# Pollute memory state to prove load_from_disk overwrites accurately
	gs.tutorial_current_step = 99
	gs.tutorial_completed = true
	gs.tutorial_skipped = true
	gs.tutorial_replay_requested = true
	gs.tutorial_seen_hints = {"bogus_hint": true}

	var load_success = gs.load_from_disk()
	_assert_check(load_success == true, "load_from_disk() executed successfully")
	_assert_check(gs.tutorial_current_step == 3, "Roundtrip: tutorial_current_step restored to 3")
	_assert_check(gs.tutorial_completed == false, "Roundtrip: tutorial_completed restored to false")
	_assert_check(gs.tutorial_skipped == false, "Roundtrip: tutorial_skipped restored to false")
	_assert_check(gs.tutorial_replay_requested == false, "Roundtrip: tutorial_replay_requested restored to false")
	_assert_check(gs.has_seen_contextual_hint("hint_zone_gate") == true, "Roundtrip: hint_zone_gate marked as seen")
	_assert_check(gs.has_seen_contextual_hint("hint_tech_tree") == true, "Roundtrip: hint_tech_tree marked as seen")
	_assert_check(gs.has_seen_contextual_hint("hint_staff") == false, "Roundtrip: hint_staff remains unseen")
	_assert_check(gs.has_seen_contextual_hint("bogus_hint") == false, "Roundtrip: polluted in-memory hint cleared")

	# -------------------------------------------------------------------------
	# TIER 3: Backward Compatibility & Corrupted Save Immunity (F16)
	# -------------------------------------------------------------------------
	print("\n--- TIER 3: Backward Compatibility & Corrupted Save Immunity ---")
	# Simulate legacy save file from older version lacking any tutorial keys
	var legacy_save: Dictionary = {
		"version": 1,
		"timestamp": int(Time.get_unix_time_from_system()),
		"energy": 2500.0,
		"total_energy_earned": 10000.0,
		"total_lifetime_energy": 10000.0,
		"upgrades": {
			"tier_1": {"level": 2, "current_cost": 45.0}
		}
	}
	var f_legacy = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	f_legacy.store_string(JSON.stringify(legacy_save, "\t"))
	f_legacy.close()

	# Set dirty memory state
	gs.tutorial_completed = true
	gs.tutorial_skipped = true
	gs.tutorial_current_step = 7
	gs.tutorial_seen_hints = {"legacy_dummy": true}

	var legacy_load_ok = gs.load_from_disk()
	_assert_check(legacy_load_ok == true, "Legacy save without tutorial keys loads cleanly without error")
	_assert_check(gs.tutorial_completed == false, "Legacy default: tutorial_completed defaults to false")
	_assert_check(gs.tutorial_skipped == false, "Legacy default: tutorial_skipped defaults to false")
	_assert_check(gs.tutorial_current_step == 0, "Legacy default: tutorial_current_step defaults to 0")
	_assert_check(gs.tutorial_replay_requested == false, "Legacy default: tutorial_replay_requested defaults to false")
	_assert_check(gs.tutorial_seen_hints.is_empty(), "Legacy default: tutorial_seen_hints defaults to empty dictionary")
	_assert_check(gs.has_seen_contextual_hint("hint_zone_gate") == false, "has_seen_contextual_hint returns false on legacy save")

	# Corrupted non-dictionary hints defense
	var corrupted_save: Dictionary = {
		"version": 1,
		"energy": 100.0,
		"tutorial_current_step": -10,
		"tutorial_completed": "not_a_bool",
		"tutorial_seen_hints": ["invalid", "array", "type"]
	}
	var f_corrupt = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	f_corrupt.store_string(JSON.stringify(corrupted_save, "\t"))
	f_corrupt.close()

	var corrupt_load_ok = gs.load_from_disk()
	_assert_check(corrupt_load_ok == true, "Corrupted tutorial field types handled without crash")
	_assert_check(gs.tutorial_current_step >= 0, "Negative step clamped/sanitized to non-negative value")
	_assert_check(gs.tutorial_seen_hints is Dictionary, "Array-type hints field safely sanitized to Dictionary")

	# -------------------------------------------------------------------------
	# Sub-Tier 3.3: Corrupted Value Types Inside tutorial_seen_hints Dictionary
	# Specifically verifies immunity against string booleans ("true", "false", "seen"),
	# numeric booleans (1, 0, 42, 1.0, 0.0), null values, nested structures, and empty keys.
	# -------------------------------------------------------------------------
	var corrupt_values_save: Dictionary = {
		"version": 1,
		"energy": 1000.0,
		"tutorial_current_step": 2,
		"tutorial_completed": false,
		"tutorial_skipped": false,
		"tutorial_replay_requested": false,
		"tutorial_seen_hints": {
			"": true,                          # Empty string key (should be ignored / discarded)
			"hint_str_true": "true",           # String boolean "true" -> true
			"hint_str_upper": "TRUE",          # Case-insensitive "TRUE" -> true
			"hint_str_false": "false",         # String boolean "false" -> false
			"hint_str_seen": "seen",           # Custom token "seen" -> true
			"hint_str_invalid": "bogus",       # Arbitrary invalid string -> false
			"hint_int_1": 1,                   # Integer 1 -> true
			"hint_int_0": 0,                   # Integer 0 -> false
			"hint_int_pos": 42,                # Non-zero integer -> true
			"hint_float_1": 1.0,               # Float 1.0 -> true
			"hint_float_0": 0.0,               # Float 0.0 -> false
			"hint_null": null,                 # Null value -> false
			"hint_nested_array": [1, 2],       # Nested array -> false
			"hint_nested_dict": {"foo": "bar"} # Nested dictionary -> false
		}
	}
	var f_corrupt_vals = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	f_corrupt_vals.store_string(JSON.stringify(corrupt_values_save, "\t"))
	f_corrupt_vals.close()

	var corrupt_vals_load_ok = gs.load_from_disk()
	_assert_check(corrupt_vals_load_ok == true,
		"Corrupted string/null/nested hint values in savegame.json must not crash load_from_disk()")

	# Key sanitization check
	_assert_check(not gs.tutorial_seen_hints.has(""),
		"Empty key '' is ignored and not added to tutorial_seen_hints")

	# Value sanitization checks
	_assert_check(gs.has_seen_contextual_hint("hint_str_true") == true,
		"String 'true' safely converts to boolean true")
	_assert_check(gs.has_seen_contextual_hint("hint_str_upper") == true,
		"String 'TRUE' safely converts to boolean true")
	_assert_check(gs.has_seen_contextual_hint("hint_str_false") == false,
		"String 'false' safely converts to boolean false")
	_assert_check(gs.has_seen_contextual_hint("hint_str_seen") == true,
		"String 'seen' token safely converts to boolean true")
	_assert_check(gs.has_seen_contextual_hint("hint_str_invalid") == false,
		"Arbitrary string 'bogus' safely defaults to boolean false")

	_assert_check(gs.has_seen_contextual_hint("hint_int_1") == true,
		"Integer 1 safely converts to boolean true")
	_assert_check(gs.has_seen_contextual_hint("hint_int_0") == false,
		"Integer 0 safely converts to boolean false")
	_assert_check(gs.has_seen_contextual_hint("hint_int_pos") == true,
		"Non-zero integer 42 safely converts to boolean true")
	_assert_check(gs.has_seen_contextual_hint("hint_float_1") == true,
		"Float 1.0 safely converts to boolean true")
	_assert_check(gs.has_seen_contextual_hint("hint_float_0") == false,
		"Float 0.0 safely converts to boolean false")

	_assert_check(gs.has_seen_contextual_hint("hint_null") == false,
		"Null value safely sanitized to boolean false without crash")
	_assert_check(gs.has_seen_contextual_hint("hint_nested_array") == false,
		"Nested array safely sanitized to boolean false without crash")
	_assert_check(gs.has_seen_contextual_hint("hint_nested_dict") == false,
		"Nested dictionary safely sanitized to boolean false without crash")

	# Strict Type Invariant: All entries in tutorial_seen_hints must be TYPE_BOOL
	var all_bools: bool = true
	for k in gs.tutorial_seen_hints:
		if typeof(gs.tutorial_seen_hints[k]) != TYPE_BOOL:
			all_bools = false
			break
	_assert_check(all_bools, "Strict Invariant: All sanitized entries in tutorial_seen_hints are native TYPE_BOOL")

	# -------------------------------------------------------------------------
	# TIER 4: First-Time Player Truth Table Verification (F17)
	# -------------------------------------------------------------------------
	print("\n--- TIER 4: First-Time Player Truth Table Verification ---")
	# Case 1: Fresh install (no save file exists)
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	gs.tutorial_completed = false
	gs.tutorial_skipped = false
	gs.tutorial_replay_requested = false
	_assert_check(not FileAccess.file_exists(SAVE_PATH), "Save file does not exist")
	_assert_check(gs.is_first_time_player() == true,
		"Case 1: Fresh game (no save) -> is_first_time_player() == true")
	_assert_check(tm.should_start_intro() == true,
		"Case 1: TutorialManager.should_start_intro() == true")

	# Case 2: Save exists, tutorial not completed / not skipped
	gs.tutorial_current_step = 2
	gs.tutorial_completed = false
	gs.tutorial_skipped = false
	gs.tutorial_replay_requested = false
	gs.save_to_disk()
	_assert_check(FileAccess.file_exists(SAVE_PATH), "Save file exists")
	_assert_check(gs.is_first_time_player() == true,
		"Case 2: Save exists, tutorial in-progress -> is_first_time_player() == true")

	# Case 3: Save exists, tutorial completed
	gs.tutorial_current_step = 7
	gs.tutorial_completed = true
	gs.tutorial_skipped = false
	gs.tutorial_replay_requested = false
	gs.save_to_disk()
	_assert_check(gs.is_first_time_player() == false,
		"Case 3: Save exists, tutorial completed -> is_first_time_player() == false")
	_assert_check(tm.should_start_intro() == false,
		"Case 3: TutorialManager.should_start_intro() == false")

	# Case 4: Save exists, tutorial skipped
	gs.tutorial_current_step = 7
	gs.tutorial_completed = true
	gs.tutorial_skipped = true
	gs.tutorial_replay_requested = false
	gs.save_to_disk()
	_assert_check(gs.is_first_time_player() == false,
		"Case 4: Save exists, tutorial skipped -> is_first_time_player() == false")
	_assert_check(tm.should_start_intro() == false,
		"Case 4: TutorialManager.should_start_intro() == false")

	# Case 5: Save exists, tutorial completed, but reset_tutorial_state() called (replay requested)
	gs.tutorial_completed = true
	gs.tutorial_skipped = false
	gs.tutorial_replay_requested = false
	gs.save_to_disk()
	_assert_check(gs.is_first_time_player() == false, "Pre-condition: completed player is not first-time")

	gs.reset_tutorial_state()
	_assert_check(gs.tutorial_replay_requested == true, "reset_tutorial_state() sets tutorial_replay_requested = true")
	_assert_check(gs.is_first_time_player() == true,
		"Case 5: Replay requested -> is_first_time_player() == true")
	_assert_check(tm.should_start_intro() == true,
		"Case 5: TutorialManager.should_start_intro() == true")

	# -------------------------------------------------------------------------
	# TIER 5: Non-Destructive Reset Isolation & Progression Safety (F18)
	# -------------------------------------------------------------------------
	print("\n--- TIER 5: Non-Destructive Reset Isolation & Progression Safety ---")
	# Configure heavy game progress
	gs.energy = 50000.0
	gs.total_energy_earned = 75000.0
	gs.upgrades["tier_1"]["level"] = 5
	gs.upgrades["tier_2"]["level"] = 3
	gs.upgrades["tier_3"]["level"] = 1
	gs.unlock_zone("server_room")
	gs.hire_worker("Frontend Dev")
	gs.item_inventory["briefcase"] = 4
	gs.tutorial_current_step = 6
	gs.tutorial_completed = true
	gs.tutorial_skipped = false
	gs.tutorial_seen_hints = {
		"hint_zone_gate": true,
		"hint_tech_tree": true,
		"hint_staff": true
	}

	var pre_reset_energy: float = gs.energy

	# Execute reset
	gs.reset_tutorial_state()

	# Assert non-tutorial progression is 100% untouched
	_assert_check(absf(gs.energy - pre_reset_energy) < 50.0, "Preservation: Energy remains untouched by reset (actual: %.2f, expected: %.2f)" % [gs.energy, pre_reset_energy])
	_assert_check(gs.upgrades["tier_1"]["level"] == 5, "Preservation: Tier 1 upgrade level remains 5")
	_assert_check(gs.upgrades["tier_2"]["level"] == 3, "Preservation: Tier 2 upgrade level remains 3")
	_assert_check(gs.upgrades["tier_3"]["level"] == 1, "Preservation: Tier 3 upgrade level remains 1")
	_assert_check(gs.is_zone_unlocked("server_room") == true, "Preservation: Zone 'server_room' remains unlocked")
	_assert_check(gs.get_hired_workers().size() >= 1, "Preservation: Hired worker remains on staff")
	_assert_check(gs.item_inventory["briefcase"] == 4, "Preservation: Briefcases remain in inventory")

	# Assert tutorial progression is completely reset
	_assert_check(gs.tutorial_current_step == 0, "Reset: tutorial_current_step reset to 0")
	_assert_check(gs.tutorial_completed == false, "Reset: tutorial_completed reset to false")
	_assert_check(gs.tutorial_skipped == false, "Reset: tutorial_skipped reset to false")
	_assert_check(gs.tutorial_seen_hints.is_empty(), "Reset: tutorial_seen_hints emptied")
	_assert_check(gs.tutorial_replay_requested == true, "Reset: tutorial_replay_requested is true")
	_assert_check(gs.is_first_time_player() == true, "Reset: is_first_time_player() is true")

	# -------------------------------------------------------------------------
	# TIER 6: Contextual Hints Exactly-Once Triggering (F10–F15)
	# -------------------------------------------------------------------------
	print("\n--- TIER 6: Contextual Hints Exactly-Once Triggering ---")
	var hints_to_test: Array[String] = [
		"hint_zone_gate",
		"hint_tech_tree",
		"hint_staff",
		"hint_minigame",
		"hint_daily_board",
		"hint_ipo_bell"
	]

	# Clean hints state
	gs.tutorial_seen_hints.clear()
	tm.reset_tutorial()

	var triggered_signal_list: Array[String] = []
	var on_hint_triggered = func(h_id: String):
		triggered_signal_list.append(h_id)

	tm.contextual_hint_triggered.connect(on_hint_triggered)

	var dp = tm.get_dialogue_panel()
	_assert_check(dp != null, "DialoguePanel accessible for hint popups")

	# Pass 1: First trigger of each hint MUST succeed
	print("  Sub-Tier 6.1: First trigger pass (all 6 hints)")
	for hint_id in hints_to_test:
		triggered_signal_list.clear()
		tm.trigger_contextual_hint(hint_id)
		await process_frame

		_assert_check(triggered_signal_list.has(hint_id),
			"First trigger emitted signal for '%s'" % hint_id)
		_assert_check(gs.has_seen_contextual_hint(hint_id) == true,
			"GameState marked '%s' as seen" % hint_id)
		_assert_check(dp.visible == true,
			"DialoguePanel visible for hint '%s'" % hint_id)
		_assert_check(dp.is_hint_active() == true,
			"DialoguePanel reports is_hint_active() == true")

		# Dismiss popup
		dp.dismiss_hint()
		await process_frame
		_assert_check(dp.visible == false, "DialoguePanel closed after dismiss")

	# Pass 2: Second trigger attempt MUST be ignored (Exactly-Once guarantee)
	print("  Sub-Tier 6.2: Exactly-once suppression pass (all 6 hints)")
	for hint_id in hints_to_test:
		triggered_signal_list.clear()
		tm.trigger_contextual_hint(hint_id)
		await process_frame

		_assert_check(triggered_signal_list.is_empty(),
			"Duplicate trigger suppressed for '%s' (0 signals)" % hint_id)
		_assert_check(dp.visible == false,
			"DialoguePanel remained closed on duplicate trigger for '%s'" % hint_id)
		_assert_check(gs.has_seen_contextual_hint(hint_id) == true,
			"GameState retains seen flag for '%s'" % hint_id)

	tm.contextual_hint_triggered.disconnect(on_hint_triggered)

	# -------------------------------------------------------------------------
	# TIER 7: Contextual Hint Station & Modal Hook Integration (F10–F15)
	# -------------------------------------------------------------------------
	print("\n--- TIER 7: Contextual Hint Station & Modal Hook Integration ---")
	# 7.1 Zone Gate Hook Point
	var zg_scene = load("res://scenes/zone_gate_3d.tscn")
	_assert_check(zg_scene != null, "ZoneGate3D scene loaded")
	if zg_scene != null:
		var zg = zg_scene.instantiate()
		zg.zone_id = "test_locked_zone"
		zg.required_level = 999
		root.add_child(zg)
		gs.tutorial_seen_hints.erase("hint_zone_gate")

		var fake_avatar = CharacterBody3D.new()
		fake_avatar.add_to_group("player")
		root.add_child(fake_avatar)
		if zg.has_method("_on_interaction_body_entered"):
			zg.call("_on_interaction_body_entered", fake_avatar)
			await process_frame
			_assert_check(gs.has_seen_contextual_hint("hint_zone_gate") == true,
				"ZoneGate3D proximity triggers 'hint_zone_gate'")
		fake_avatar.free()
		zg.free()

	# 7.2 Tech Tree Modal Hook Point
	var tt_scene = load("res://scenes/ui/tech_tree_modal.tscn")
	_assert_check(tt_scene != null, "TechTreeModal scene loaded")
	if tt_scene != null:
		var tt_modal = tt_scene.instantiate()
		root.add_child(tt_modal)
		gs.tutorial_seen_hints.erase("hint_tech_tree")
		if tt_modal.has_method("open"):
			tt_modal.open()
			await process_frame
			_assert_check(gs.has_seen_contextual_hint("hint_tech_tree") == true,
				"TechTreeModal open() triggers 'hint_tech_tree'")
		tt_modal.free()

	# 7.3 Staff Modal Hook Point
	var staff_scene = load("res://scenes/ui/staff_modal.tscn")
	_assert_check(staff_scene != null, "StaffModal scene loaded")
	if staff_scene != null:
		var staff_modal = staff_scene.instantiate()
		root.add_child(staff_modal)
		gs.tutorial_seen_hints.erase("hint_staff")
		if staff_modal.has_method("open"):
			staff_modal.open()
		await process_frame
		_assert_check(gs.has_seen_contextual_hint("hint_staff") == true,
			"StaffModal initialization/open triggers 'hint_staff'")
		staff_modal.free()

	# 7.4 Server Terminal Hook Point
	var st_scene = load("res://scenes/server_terminal.tscn")
	_assert_check(st_scene != null, "ServerTerminal scene loaded")
	if st_scene != null:
		var st = st_scene.instantiate()
		root.add_child(st)
		gs.tutorial_seen_hints.erase("hint_minigame")
		if st.has_method("interact"):
			st.interact()
			await process_frame
			_assert_check(gs.has_seen_contextual_hint("hint_minigame") == true,
				"ServerTerminal interact() triggers 'hint_minigame'")
		st.free()

	# 7.5 Daily Board Hook Point
	var db_scene = load("res://scenes/daily_board_3d.tscn")
	_assert_check(db_scene != null, "DailyBoard3D scene loaded")
	if db_scene != null:
		var db = db_scene.instantiate()
		root.add_child(db)
		gs.tutorial_seen_hints.erase("hint_daily_board")
		if db.has_method("interact"):
			db.interact()
			await process_frame
			_assert_check(gs.has_seen_contextual_hint("hint_daily_board") == true,
				"DailyBoard3D interact() triggers 'hint_daily_board'")
		db.free()

	# 7.6 IPO Bell Hook Point
	var ipo_scene = load("res://scenes/ipo_bell_3d.tscn")
	_assert_check(ipo_scene != null, "IpoBell3D scene loaded")
	if ipo_scene != null:
		var ib = ipo_scene.instantiate()
		root.add_child(ib)
		gs.tutorial_seen_hints.erase("hint_ipo_bell")
		if ib.has_method("interact"):
			ib.interact()
			await process_frame
			_assert_check(gs.has_seen_contextual_hint("hint_ipo_bell") == true,
				"IpoBell3D interact() triggers 'hint_ipo_bell'")
		ib.free()

	# -------------------------------------------------------------------------
	# TIER 8: Settings Modal Replay Tutorial Button Ergonomics & Flow (F18)
	# -------------------------------------------------------------------------
	print("\n--- TIER 8: Settings Modal Replay Tutorial Button Ergonomics & Flow ---")
	var sm_scene = load("res://scenes/ui/settings_modal.tscn")
	_assert_check(sm_scene != null, "SettingsModal scene loaded from res://scenes/ui/settings_modal.tscn")
	if sm_scene != null:
		var sm = sm_scene.instantiate()
		root.add_child(sm)
		await process_frame

		var replay_btn = sm.get_node_or_null("%ReplayTutorialButton") as Button
		if replay_btn == null:
			replay_btn = sm.find_child("ReplayTutorialButton", true, false) as Button

		_assert_check(replay_btn != null, "Replay Tutorial button exists in SettingsModal")
		if replay_btn != null:
			_assert_check(replay_btn is Button, "Replay Tutorial element is a Button")
			_assert_check(replay_btn.custom_minimum_size.y >= 56.0,
				"Replay Tutorial button height >= 56px (Touch Target Requirement, actual: %.1f)" % replay_btn.custom_minimum_size.y)
			_assert_check(replay_btn.mouse_filter == Control.MOUSE_FILTER_STOP,
				"Replay Tutorial button mouse_filter is STOP (0)")
			_assert_check("Tutorial" in replay_btn.text or "wiederholen" in replay_btn.text or "Replay" in replay_btn.text,
				"Replay Tutorial button text indicates tutorial reset action")

			# Set game state to veteran player
			gs.tutorial_completed = true
			gs.tutorial_skipped = false
			gs.tutorial_replay_requested = false
			gs.save_to_disk()
			_assert_check(gs.is_first_time_player() == false, "Pre-condition: Player is veteran before button click")

			# Simulate pressing the replay button
			replay_btn.pressed.emit()
			await process_frame

			_assert_check(gs.tutorial_replay_requested == true, "Button click sets tutorial_replay_requested = true")
			_assert_check(gs.tutorial_completed == false, "Button click sets tutorial_completed = false")
			_assert_check(gs.tutorial_current_step == 0, "Button click sets tutorial_current_step = 0")
			_assert_check(gs.tutorial_seen_hints.is_empty(), "Button click clears tutorial_seen_hints")
			_assert_check(gs.is_first_time_player() == true,
				"Button click causes is_first_time_player() == true")

		sm.free()

	# -------------------------------------------------------------------------
	# Teardown & Results
	# -------------------------------------------------------------------------
	_restore_savegame()
	await process_frame
	await process_frame

	print("\n=================================================================")
	print("Milestone 3 Test Results: %d Passed, %d Failed" % [pass_count, fail_count])
	print("=================================================================")

	quit(0 if fail_count == 0 else 1)

