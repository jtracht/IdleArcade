extends SceneTree

## =============================================================================
## Adversarial Stress Test Suite for Milestone 3 (Phase 17):
## GameState Persistence, Savegame Corruption Immunity, First-Time Player
## Permutations, Economy Isolation, and Contextual Hint Firing Stress.
##
## File: IdleArcade/tests/test_p17_m3_adversarial_stress.gd
## Runner: godot --headless --path IdleArcade -s tests/test_p17_m3_adversarial_stress.gd
## =============================================================================

var pass_count: int = 0
var fail_count: int = 0

const SAVE_PATH: String = "user://savegame.json"
const BACKUP_PATH: String = "user://savegame.json.stress_backup"

func _init() -> void:
	call_deferred("_run_stress_suite")

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

func _run_stress_suite() -> void:
	print("=================================================================")
	print(">>> ADVERSARIAL STRESS HARNESS: MILESTONE 3 PERSISTENCE & HINTS <<<")
	print("=================================================================")

	await process_frame
	await process_frame

	_backup_savegame()

	var gs = root.get_node_or_null("GameState")
	var tm = root.get_node_or_null("TutorialManager")

	_assert_check(gs != null, "Autoload: GameState mounted")
	_assert_check(tm != null, "Autoload: TutorialManager mounted")

	if gs == null or tm == null:
		printerr("FATAL: GameState or TutorialManager missing.")
		_restore_savegame()
		quit(1)
		return

	# =========================================================================
	# SUITE 1: Savegame Corruption & Malformed JSON Attack Battery
	# =========================================================================
	print("\n--- SUITE 1: Savegame Corruption & Malformed JSON Attack Battery ---")

	# Test 1.1: 0-byte empty file
	_write_raw_save("")
	var res_empty = gs.load_from_disk()
	_assert_check(res_empty == false, "0-byte empty save: load_from_disk() safely returns false without crash")

	# Test 1.2: Whitespace only
	_write_raw_save("   \n\t  \r\n   ")
	var res_ws = gs.load_from_disk()
	_assert_check(res_ws == false, "Whitespace-only save: load_from_disk() returns false without crash")

	# Test 1.3: Truncated JSON
	_write_raw_save("{\"tutorial_current_step\": 4, \"tutorial_completed\":")
	var res_trunc = gs.load_from_disk()
	_assert_check(res_trunc == false, "Truncated JSON syntax: load_from_disk() returns false without crash")

	# Test 1.4: Extra closing brace & syntax error
	_write_raw_save("{\"energy\": 1000.0, \"tutorial_completed\": true}}")
	var res_bad_syntax = gs.load_from_disk()
	_assert_check(res_bad_syntax == false, "Malformed syntax (extra brace): load_from_disk() returns false")

	# Test 1.5: Non-dictionary JSON root: Array
	_write_raw_save("[1, 2, 3, 4, 5]")
	var res_arr = gs.load_from_disk()
	_assert_check(res_arr == false, "Array JSON root: rejected by load_from_disk() without crash")

	# Test 1.6: Non-dictionary JSON root: String
	_write_raw_save("\"just a raw string\"")
	var res_str = gs.load_from_disk()
	_assert_check(res_str == false, "String JSON root: rejected by load_from_disk() without crash")

	# Test 1.7: Non-dictionary JSON root: Number
	_write_raw_save("12345.678")
	var res_num = gs.load_from_disk()
	_assert_check(res_num == false, "Number JSON root: rejected by load_from_disk() without crash")

	# Test 1.8: Non-dictionary JSON root: Boolean
	_write_raw_save("true")
	var res_bool = gs.load_from_disk()
	_assert_check(res_bool == false, "Boolean JSON root: rejected by load_from_disk() without crash")

	# Test 1.9: Non-dictionary JSON root: Null
	_write_raw_save("null")
	var res_null = gs.load_from_disk()
	_assert_check(res_null == false, "Null JSON root: rejected by load_from_disk() without crash")

	# Test 1.10: Toxic & Corrupted Types Inside Dictionary
	var toxic_dict: Dictionary = {
		"energy": 500.0,
		"tutorial_current_step": -999999,
		"tutorial_completed": "not_a_bool_string",
		"tutorial_skipped": 12345,
		"tutorial_replay_requested": ["array_not_bool"],
		"tutorial_seen_hints": "string_not_dict"
	}
	_write_raw_save(JSON.stringify(toxic_dict))
	var res_toxic = gs.load_from_disk()
	_assert_check(res_toxic == true, "Toxic field types: dictionary parsed successfully")
	_assert_check(gs.tutorial_current_step >= 0,
		"Toxic step: negative step clamped to >= 0 (actual: %d)" % gs.tutorial_current_step)
	_assert_check(gs.tutorial_completed == false,
		"Toxic completed: non-bool string sanitized to false (actual: %s)" % str(gs.tutorial_completed))
	_assert_check(gs.tutorial_skipped == false,
		"Toxic skipped: integer sanitized to false (actual: %s)" % str(gs.tutorial_skipped))
	_assert_check(gs.tutorial_replay_requested == false,
		"Toxic replay: array sanitized to false (actual: %s)" % str(gs.tutorial_replay_requested))
	_assert_check(gs.tutorial_seen_hints is Dictionary,
		"Toxic hints: string sanitized to empty Dictionary")

	# Test 1.11: Integer and Boolean hint values (compatible with Godot bool constructor)
	var int_hints_dict: Dictionary = {
		"energy": 100.0,
		"tutorial_seen_hints": {
			"": true,                      # empty string key
			"hint_zone_gate": 1,           # int truthy (1)
			"hint_tech_tree": 0,           # int falsy (0)
			"hint_minigame": false,        # explicit false
			"hint_daily_board": true       # explicit true
		}
	}
	_write_raw_save(JSON.stringify(int_hints_dict))
	var res_hints_int = gs.load_from_disk()
	_assert_check(res_hints_int == true, "Integer and boolean hint values parse cleanly")
	_assert_check(not gs.tutorial_seen_hints.has(""), "Empty key '' was ignored and not saved to seen hints")
	_assert_check(gs.has_seen_contextual_hint("hint_zone_gate") == true, "int 1 converts to true")
	_assert_check(gs.has_seen_contextual_hint("hint_tech_tree") == false, "int 0 converts to false")
	_assert_check(gs.has_seen_contextual_hint("hint_minigame") == false, "false remains false")
	_assert_check(gs.has_seen_contextual_hint("hint_daily_board") == true, "true remains true")

	# Test 1.12: EMPIRICAL BUG REPRODUCER: String/null value in tutorial_seen_hints crashes load_from_disk()
	# GameState line 1802 calls `bool(raw_hints[hint_id])`.
	# In GDScript 4, bool() has NO constructor for String or Nil/null, throwing a fatal SCRIPT ERROR!
	var string_null_hints: Dictionary = {
		"energy": 100.0,
		"tutorial_seen_hints": {
			"hint_corrupted_str": "seen",   # string causes SCRIPT ERROR: Nonexistent 'bool' constructor
			"hint_corrupted_null": null     # null causes SCRIPT ERROR: Nonexistent 'bool' constructor
		}
	}
	_write_raw_save(JSON.stringify(string_null_hints))
	var res_string_null = gs.load_from_disk()
	# If this fails or load_from_disk throws SCRIPT ERROR, we record empirical vulnerability
	_assert_check(res_string_null == true,
		"[VULNERABILITY] Corrupted string/null hint values in savegame.json must not crash load_from_disk()")

	# Test 1.13: Massive Dictionary (1,000 hints stress)
	var massive_hints: Dictionary = {}
	for i in range(1000):
		massive_hints["hint_stress_%04d" % i] = (i % 2 == 0)
	var massive_save: Dictionary = {
		"energy": 9999.0,
		"tutorial_seen_hints": massive_hints
	}
	_write_raw_save(JSON.stringify(massive_save))
	var res_massive = gs.load_from_disk()
	_assert_check(res_massive == true, "Massive save (1,000 hints) loads without issue")
	_assert_check(gs.tutorial_seen_hints.size() == 1000,
		"Massive save: all 1,000 hints retained in memory (actual: %d)" % gs.tutorial_seen_hints.size())
	_assert_check(gs.has_seen_contextual_hint("hint_stress_0000") == true, "First hint correct")
	_assert_check(gs.has_seen_contextual_hint("hint_stress_0001") == false, "Second hint correct")
	_assert_check(gs.has_seen_contextual_hint("hint_stress_0998") == true, "998th hint correct")
	_assert_check(gs.has_seen_contextual_hint("hint_stress_0999") == false, "999th hint correct")

	# =========================================================================
	# SUITE 2: Exhaustive 16-Permutation Truth Table & Replay Precedence
	# =========================================================================
	print("\n--- SUITE 2: Exhaustive 16-Permutation Truth Table & Replay Precedence ---")

	# Truth Table Permutations:
	# (FileExists, ReplayRequested, Completed, Skipped) -> Expected is_first_time_player()
	# Spec:
	# - If ReplayRequested == true -> TRUE (always, regardless of file, completed, skipped)
	# - If FileExists == false -> TRUE (always on fresh game)
	# - Else (FileExists == true and ReplayRequested == false):
	#     return not Completed and not Skipped
	var perm_cases: Array[Dictionary] = []

	for f_exists in [false, true]:
		for replay in [false, true]:
			for comp in [false, true]:
				for skip in [false, true]:
					var expected: bool
					if replay:
						expected = true
					elif not f_exists:
						expected = true
					else:
						expected = (not comp) and (not skip)

					perm_cases.append({
						"f_exists": f_exists,
						"replay": replay,
						"comp": comp,
						"skip": skip,
						"expected": expected
					})

	var perm_index: int = 1
	for p in perm_cases:
		# Setup disk
		if p["f_exists"]:
			var dummy_save: Dictionary = {
				"energy": 10.0,
				"tutorial_current_step": 1,
				"tutorial_completed": p["comp"],
				"tutorial_skipped": p["skip"],
				"tutorial_replay_requested": p["replay"]
			}
			_write_raw_save(JSON.stringify(dummy_save))
		else:
			if FileAccess.file_exists(SAVE_PATH):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))

		# Setup memory
		gs.tutorial_completed = p["comp"]
		gs.tutorial_skipped = p["skip"]
		gs.tutorial_replay_requested = p["replay"]

		var actual_gs = gs.is_first_time_player()
		var actual_tm = tm.should_start_intro()

		var desc = "Perm #%02d [file=%s, replay=%s, comp=%s, skip=%s] -> expected=%s" % [
			perm_index,
			"Y" if p["f_exists"] else "N",
			"Y" if p["replay"] else "N",
			"Y" if p["comp"] else "N",
			"Y" if p["skip"] else "N",
			str(p["expected"]).to_upper()
		]
		_assert_check(actual_gs == p["expected"], "GameState: " + desc, "actual: %s" % str(actual_gs))
		_assert_check(actual_tm == p["expected"], "TutorialManager: " + desc, "actual: %s" % str(actual_tm))
		perm_index += 1

	# =========================================================================
	# SUITE 3: Economy Variable Isolation Under High-Frequency Resets
	# =========================================================================
	print("\n--- SUITE 3: Economy Variable Isolation Under High-Frequency Resets ---")

	# Set up comprehensive, deep late-game progression
	gs.energy = 876543210.0
	gs.total_energy_earned = 1234567890.0
	gs.total_lifetime_energy = 9999999999.0
	gs.angel_shares = 1250
	gs.total_ipos_completed = 14
	gs.total_clicks = 8844
	gs.sparks_collected = 7733
	gs.bonus_users = 450
	gs.avatar_speed_level = 4
	gs.idle_level = 9
	gs.pickup_radius_level = 3
	gs.collectibles_collected = 152
	gs.daily_streak = 21

	# Upgrades
	for up_id in gs.upgrades:
		gs.upgrades[up_id]["level"] = 15
		gs.upgrades[up_id]["current_cost"] = 750000.0

	# Workers
	gs.hired_workers.clear()
	gs.hire_worker("Senior DevOps")
	gs.hire_worker("Frontend Dev")
	gs.hire_worker("Backend Dev")

	# Zones
	gs.unlock_zone("server_room")
	gs.unlock_zone("executive_lounge")

	# Items
	gs.item_inventory["briefcase"] = 12
	gs.item_inventory["coffee_mug"] = 35

	# Tutorial state before reset (veteran state)
	gs.tutorial_current_step = 7
	gs.tutorial_completed = true
	gs.tutorial_skipped = false
	gs.tutorial_replay_requested = false
	gs.tutorial_seen_hints = {
		"hint_zone_gate": true,
		"hint_tech_tree": true,
		"hint_staff": true,
		"hint_minigame": true,
		"hint_daily_board": true,
		"hint_ipo_bell": true
	}
	gs.save_to_disk()

	# Record exact snapshot of economy
	var snap_energy = gs.energy
	var snap_total_earned = gs.total_energy_earned
	var snap_lifetime = gs.total_lifetime_energy
	var snap_angel_shares = gs.angel_shares
	var snap_ipos = gs.total_ipos_completed
	var snap_clicks = gs.total_clicks
	var snap_workers = gs.hired_workers.duplicate(true)
	var snap_zones = gs.unlocked_zones.duplicate()
	var snap_items = gs.item_inventory.duplicate()
	var snap_streak = gs.daily_streak

	# Execute 100 rapid reset calls in a loop!
	for i in range(100):
		gs.reset_tutorial_state()

	# Verify tutorial variables were reset
	_assert_check(gs.tutorial_current_step == 0, "After 100 resets: tutorial_current_step is 0")
	_assert_check(gs.tutorial_completed == false, "After 100 resets: tutorial_completed is false")
	_assert_check(gs.tutorial_skipped == false, "After 100 resets: tutorial_skipped is false")
	_assert_check(gs.tutorial_replay_requested == true, "After 100 resets: tutorial_replay_requested is true")
	_assert_check(gs.tutorial_seen_hints.is_empty(), "After 100 resets: tutorial_seen_hints is empty")
	_assert_check(gs.is_first_time_player() == true, "After 100 resets: is_first_time_player() is true")

	# Verify zero leakage / zero alteration into ANY economy variables
	_assert_check(absf(gs.energy - snap_energy) < 100.0,
		"Economy: Energy unchanged (actual: %.2f, expected: %.2f)" % [gs.energy, snap_energy])
	_assert_check(absf(gs.total_energy_earned - snap_total_earned) < 100.0,
		"Economy: Total earned unchanged")
	_assert_check(absf(gs.total_lifetime_energy - snap_lifetime) < 100.0,
		"Economy: Lifetime energy unchanged")
	_assert_check(gs.angel_shares == snap_angel_shares,
		"Economy: Angel shares preserved at %d" % snap_angel_shares)
	_assert_check(gs.total_ipos_completed == snap_ipos,
		"Economy: IPO count preserved at %d" % snap_ipos)
	_assert_check(gs.total_clicks == snap_clicks,
		"Economy: Total clicks preserved at %d" % snap_clicks)
	_assert_check(gs.hired_workers.size() == snap_workers.size(),
		"Economy: Hired workers size preserved (%d)" % snap_workers.size())
	_assert_check(gs.unlocked_zones.size() == snap_zones.size(),
		"Economy: Unlocked zones size preserved (%d)" % snap_zones.size())
	_assert_check(gs.item_inventory["briefcase"] == snap_items["briefcase"],
		"Economy: Inventory briefcases preserved (%d)" % snap_items["briefcase"])
	_assert_check(gs.daily_streak == snap_streak,
		"Economy: Daily streak preserved (%d)" % snap_streak)

	# Verify persistence roundtrip after reset
	var reloaded_ok = gs.load_from_disk()
	_assert_check(reloaded_ok == true, "Load from disk after reset successful")
	_assert_check(gs.tutorial_replay_requested == true, "Persisted replay_requested is true")
	_assert_check(gs.tutorial_seen_hints.is_empty(), "Persisted seen_hints is empty")
	_assert_check(gs.angel_shares == snap_angel_shares, "Persisted angel shares untouched")

	# =========================================================================
	# SUITE 4: Contextual Hint Concurrency & Rapid Multi-Firing Stress
	# =========================================================================
	print("\n--- SUITE 4: Contextual Hint Concurrency & Rapid Multi-Firing Stress ---")

	# Reset hints cleanly
	gs.tutorial_seen_hints.clear()
	tm.reset_tutorial()

	var fired_hint_history: Array[String] = []
	var test_hint_callback = func(hint_id: String):
		fired_hint_history.append(hint_id)

	tm.contextual_hint_triggered.connect(test_hint_callback)

	# Stress Test 4.1: Rapid 200x spam on a single hint ID
	print("  Sub-Test 4.1: 200x spam on single hint ('hint_zone_gate')")
	fired_hint_history.clear()

	for i in range(200):
		tm.trigger_contextual_hint("hint_zone_gate")

	_assert_check(fired_hint_history.size() == 1,
		"200 rapid triggers: emitted signal EXACTLY ONCE (actual: %d)" % fired_hint_history.size())
	_assert_check(fired_hint_history.size() == 1 and fired_hint_history[0] == "hint_zone_gate",
		"Signal payload is 'hint_zone_gate'")
	_assert_check(gs.has_seen_contextual_hint("hint_zone_gate") == true,
		"GameState records 'hint_zone_gate' as seen")

	# Stress Test 4.2: Interleaved randomized spam across all 6 hints (600 total calls)
	print("  Sub-Test 4.2: 600 interleaved random triggers across all 6 hints")
	var all_six_hints: Array[String] = [
		"hint_zone_gate",
		"hint_tech_tree",
		"hint_staff",
		"hint_minigame",
		"hint_daily_board",
		"hint_ipo_bell"
	]

	# Reset for test
	gs.tutorial_seen_hints.clear()
	fired_hint_history.clear()

	# Interleave 100 cycles of all 6 hints in pseudo-random order
	for cycle in range(100):
		for h_idx in [2, 0, 4, 1, 5, 3]:
			var hint_id = all_six_hints[h_idx]
			tm.trigger_contextual_hint(hint_id)

	_assert_check(fired_hint_history.size() == 6,
		"600 interleaved triggers: EXACTLY 6 signals emitted in total (actual: %d)" % fired_hint_history.size())
	_assert_check(gs.tutorial_seen_hints.size() == 6,
		"tutorial_seen_hints contains exactly 6 unique entries (actual: %d)" % gs.tutorial_seen_hints.size())

	for hint_id in all_six_hints:
		_assert_check(gs.has_seen_contextual_hint(hint_id) == true,
			"Hint '%s' is marked seen" % hint_id)
		_assert_check(fired_hint_history.count(hint_id) == 1,
			"Hint '%s' fired exactly once in history" % hint_id)

	# Stress Test 4.3: Edge case hint IDs (empty string, whitespace)
	print("  Sub-Test 4.3: Empty and whitespace hint IDs")
	var pre_size = gs.tutorial_seen_hints.size()
	tm.trigger_contextual_hint("")
	gs.mark_contextual_hint_seen("")
	_assert_check(gs.tutorial_seen_hints.size() == pre_size,
		"Empty hint_id '' ignored and does not corrupt tutorial_seen_hints")

	# Stress Test 4.4: Active linear tutorial suppression guard
	print("  Sub-Test 4.4: Hint suppression during active linear intro")
	# Force linear intro active
	tm.start_linear_intro()
	_assert_check(tm.is_tutorial_active() == true, "Linear intro is now active")

	# Try to trigger a brand new unseen hint
	fired_hint_history.clear()
	gs.tutorial_seen_hints.erase("hint_tech_tree")
	tm.trigger_contextual_hint("hint_tech_tree")

	_assert_check(fired_hint_history.is_empty(),
		"Suppression: Contextual hint blocked while linear intro is active (0 signals)")
	_assert_check(gs.has_seen_contextual_hint("hint_tech_tree") == false,
		"Suppression: Blocked hint is NOT marked seen in GameState")

	# Now skip tutorial and trigger again
	tm.skip_tutorial()
	_assert_check(tm.is_tutorial_active() == false, "Linear intro ended after skip")

	fired_hint_history.clear()
	tm.trigger_contextual_hint("hint_tech_tree")
	_assert_check(fired_hint_history.size() == 1,
		"Unblocked: Contextual hint triggers cleanly after tutorial skipped (1 signal)")
	_assert_check(gs.has_seen_contextual_hint("hint_tech_tree") == true,
		"Unblocked: Hint now marked seen")
	_assert_check(gs.has_seen_contextual_hint("hint_tech_tree") == true,
		"Unblocked: Hint now marked seen")

	# Stress Test 4.5: Rapid dismiss & dialogue spamming
	print("  Sub-Test 4.5: Rapid dismiss torture test")
	var dp = tm.get_dialogue_panel()
	_assert_check(dp != null, "Dialogue panel accessible")
	if dp != null:
		# Call dismiss_hint 50 times when already closed
		for i in range(50):
			dp.dismiss_hint()
		_assert_check(dp.visible == false, "DialoguePanel survived 50 redundant dismiss calls")

	tm.contextual_hint_triggered.disconnect(test_hint_callback)

	# =========================================================================
	# SUITE 5: Settings Modal Replay Button Rapid Spam Torture
	# =========================================================================
	print("\n--- SUITE 5: Settings Modal Replay Button Rapid Spam Torture ---")

	var sm_scene = load("res://scenes/ui/settings_modal.tscn")
	_assert_check(sm_scene != null, "SettingsModal scene loads")
	if sm_scene != null:
		var sm = sm_scene.instantiate()
		root.add_child(sm)
		await process_frame

		var btn = sm.get_node_or_null("%ReplayTutorialButton") as Button
		if btn == null:
			btn = sm.find_child("ReplayTutorialButton", true, false) as Button

		_assert_check(btn != null, "ReplayTutorialButton located")
		if btn != null:
			# Veteran player before click
			gs.tutorial_completed = true
			gs.tutorial_skipped = false
			gs.tutorial_replay_requested = false

			# Rapid spam press 20 times in a row
			for i in range(20):
				btn.pressed.emit()

			await process_frame

			_assert_check(gs.tutorial_replay_requested == true,
				"Spam press: tutorial_replay_requested is true")
			_assert_check(gs.tutorial_completed == false,
				"Spam press: tutorial_completed reset to false")
			_assert_check(gs.tutorial_current_step == 0,
				"Spam press: tutorial_current_step reset to 0")
			_assert_check(gs.is_first_time_player() == true,
				"Spam press: is_first_time_player() is true")
			_assert_check(btn.disabled == true,
				"Spam press: button disabled after first trigger to prevent duplicate scene reloads")

		sm.free()

	# =========================================================================
	# Teardown & Results
	# =========================================================================
	_restore_savegame()
	await process_frame
	await process_frame

	print("\n=================================================================")
	print("ADVERSARIAL STRESS TEST SUMMARY: %d Passed, %d Failed" % [pass_count, fail_count])
	print("=================================================================")

	quit(0 if fail_count == 0 else 1)
