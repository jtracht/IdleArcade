extends SceneTree

# ==============================================================================
# EMPIRICAL CHALLENGER ADVERSARIAL TEST HARNESS
# Target: Milestone 3 Edge Case - Save & Reload Immediately After Tutorial Reset
# Author: p17_m3_challenger_gen2_4
# ==============================================================================

const SAVE_PATH: String = "user://savegame.json"

var total_passed: int = 0
var total_failed: int = 0

func _init() -> void:
	call_deferred("_run_suite")

func _run_suite() -> void:
	print("=================================================================")
	print("CHALLENGER 2: Reset -> Immediate Save & Reload Stress Harness")
	print("=================================================================")

	suite_1_immediate_save_reload_after_reset()
	suite_2_multi_cycle_rapid_reset_save_reload_torture()
	suite_3_replay_partial_progress_save_reload()
	suite_4_replay_skip_and_complete_persistence_lifecycle()
	suite_5_reset_immediate_hint_persistence_cycle()
	suite_6_reset_recovery_over_corrupted_disk_save()
	suite_7_settings_modal_button_save_reload_sync()

	print("=================================================================")
	print("Challenger 2 Results: %d Passed, %d Failed" % [total_passed, total_failed])
	print("=================================================================")

	if total_failed > 0:
		print("FAILED: Challenger found edge case defects!")
		quit(1)
	else:
		print("SUCCESS: All reset -> save -> reload edge cases PASSED!")
		quit(0)

func assert_test(cond: bool, msg: String) -> void:
	if cond:
		total_passed += 1
		print("  [PASS] %s" % msg)
	else:
		total_failed += 1
		print("  [FAIL] %s" % msg)

# ------------------------------------------------------------------------------
# SUITE 1: Immediate Save and Reload After Reset
# ------------------------------------------------------------------------------
func suite_1_immediate_save_reload_after_reset() -> void:
	print("\n--- SUITE 1: Immediate Save & Reload After Tutorial Reset ---")
	var gs = root.get_node_or_null("GameState")
	var tm = root.get_node_or_null("TutorialManager")
	assert_test(gs != null and tm != null, "GameState and TutorialManager singletons available")
	if gs == null or tm == null:
		return

	# Setup veteran state with full progression
	gs.energy = 555555.0
	gs.total_energy_earned = 2000000.0
	gs.angel_shares = 88
	gs.tutorial_completed = true
	gs.tutorial_skipped = false
	gs.tutorial_replay_requested = false
	gs.tutorial_current_step = 7
	gs.tutorial_seen_hints = {
		"hint_zone_gate": true,
		"hint_tech_tree": true,
		"hint_staff": true,
		"hint_minigame": true,
		"hint_daily_board": true,
		"hint_ipo_bell": true
	}

	# Save veteran state
	gs.save_to_disk()
	assert_test(FileAccess.file_exists(SAVE_PATH), "Veteran save file exists on disk")
	assert_test(gs.is_first_time_player() == false, "Pre-condition: Veteran player is NOT first-time")

	# Trigger Reset
	gs.reset_tutorial_state()

	# Assert in-memory immediate state
	assert_test(gs.tutorial_current_step == 0, "Immediate: tutorial_current_step == 0")
	assert_test(gs.tutorial_completed == false, "Immediate: tutorial_completed == false")
	assert_test(gs.tutorial_skipped == false, "Immediate: tutorial_skipped == false")
	assert_test(gs.tutorial_replay_requested == true, "Immediate: tutorial_replay_requested == true")
	assert_test(gs.tutorial_seen_hints.is_empty(), "Immediate: tutorial_seen_hints is empty")
	assert_test(gs.is_first_time_player() == true, "Immediate: is_first_time_player() is true")
	assert_test(tm.should_start_intro() == true, "Immediate: TutorialManager.should_start_intro() is true")
	assert_test(gs.energy == 555555.0, "Immediate: Energy intact (555555.0)")
	assert_test(gs.angel_shares == 88, "Immediate: Angel shares intact (88)")

	# Redundant immediate save to disk
	gs.save_to_disk()
	assert_test(FileAccess.file_exists(SAVE_PATH), "Immediate re-save file exists on disk")

	# Pollute in-memory variables to guarantee load_from_disk() actually deserializes
	gs.tutorial_current_step = 99
	gs.tutorial_completed = true
	gs.tutorial_skipped = true
	gs.tutorial_replay_requested = false
	gs.tutorial_seen_hints["polluted"] = true
	gs.energy = 1.0

	# Immediate load from disk
	var load_res = gs.load_from_disk()
	assert_test(load_res == true, "Immediate load_from_disk() returned true")

	# Assert loaded state from disk
	assert_test(gs.tutorial_current_step == 0, "Loaded: tutorial_current_step restored to 0")
	assert_test(gs.tutorial_completed == false, "Loaded: tutorial_completed restored to false")
	assert_test(gs.tutorial_skipped == false, "Loaded: tutorial_skipped restored to false")
	assert_test(gs.tutorial_replay_requested == true, "Loaded: tutorial_replay_requested restored to true")
	assert_test(gs.tutorial_seen_hints.is_empty(), "Loaded: tutorial_seen_hints is empty")
	assert_test(not gs.tutorial_seen_hints.has("polluted"), "Loaded: Polluted in-memory key cleared")
	assert_test(gs.is_first_time_player() == true, "Loaded: is_first_time_player() is true")
	assert_test(tm.should_start_intro() == true, "Loaded: TutorialManager.should_start_intro() is true")
	assert_test(gs.energy == 555555.0, "Loaded: Energy restored from disk (555555.0)")
	assert_test(gs.angel_shares == 88, "Loaded: Angel shares restored from disk (88)")

# ------------------------------------------------------------------------------
# SUITE 2: Multi-Cycle Rapid Reset -> Save -> Reload Torture
# ------------------------------------------------------------------------------
func suite_2_multi_cycle_rapid_reset_save_reload_torture() -> void:
	print("\n--- SUITE 2: Multi-Cycle Rapid Reset -> Save -> Reload Torture (50 Cycles) ---")
	var gs = root.get_node_or_null("GameState")
	if gs == null:
		return

	var all_passed: bool = true
	for cycle in range(50):
		# Randomly pollute state prior to reset
		gs.tutorial_current_step = cycle % 7
		gs.tutorial_completed = (cycle % 2 == 0)
		gs.tutorial_skipped = (cycle % 3 == 0)
		gs.tutorial_replay_requested = false
		gs.tutorial_seen_hints["hint_temp_%d" % cycle] = true
		gs.energy = float(1000 + cycle * 50)

		# Reset & immediate save & immediate reload
		gs.reset_tutorial_state()
		gs.save_to_disk()

		# Pollute memory before reading disk
		gs.tutorial_current_step = 88
		gs.tutorial_replay_requested = false

		var ok = gs.load_from_disk()
		if not ok:
			print("  [DEBUG FAIL] cycle %d: load_from_disk returned false" % cycle)
			all_passed = false
			break
		if gs.tutorial_current_step != 0:
			print("  [DEBUG FAIL] cycle %d: step != 0 (%d)" % [cycle, gs.tutorial_current_step])
			all_passed = false
			break
		if gs.tutorial_completed != false:
			print("  [DEBUG FAIL] cycle %d: completed != false" % cycle)
			all_passed = false
			break
		if gs.tutorial_skipped != false:
			print("  [DEBUG FAIL] cycle %d: skipped != false" % cycle)
			all_passed = false
			break
		if gs.tutorial_replay_requested != true:
			print("  [DEBUG FAIL] cycle %d: replay_requested != true (%s)" % [cycle, str(gs.tutorial_replay_requested)])
			all_passed = false
			break
		if not gs.tutorial_seen_hints.is_empty():
			print("  [DEBUG FAIL] cycle %d: hints not empty (%s)" % [cycle, str(gs.tutorial_seen_hints)])
			all_passed = false
			break
		if gs.is_first_time_player() != true:
			print("  [DEBUG FAIL] cycle %d: is_first_time_player != true" % cycle)
			all_passed = false
			break
		if typeof(gs.tutorial_replay_requested) != TYPE_BOOL:
			print("  [DEBUG FAIL] cycle %d: typeof != TYPE_BOOL" % cycle)
			all_passed = false
			break

	assert_test(all_passed, "All 50 cycles of Rapid Reset -> Save -> Reload maintained 100% invariants")

# ------------------------------------------------------------------------------
# SUITE 3: Replay Progress -> Mid-Intro Save -> Reload
# ------------------------------------------------------------------------------
func suite_3_replay_partial_progress_save_reload() -> void:
	print("\n--- SUITE 3: Partial Intro Progression Save & Reload After Reset ---")
	var gs = root.get_node_or_null("GameState")
	var tm = root.get_node_or_null("TutorialManager")
	if gs == null or tm == null:
		return

	# Reset
	gs.reset_tutorial_state()

	# Start intro and advance to step 3
	tm.start_linear_intro()
	assert_test(tm.get_current_step() == 1, "Intro started at Step 1")
	tm.advance_step() # to step 2
	tm.advance_step() # to step 3
	assert_test(tm.get_current_step() == 3, "Intro advanced to Step 3")

	# Save partial progress
	gs.tutorial_current_step = 3
	gs.save_to_disk()

	# Reset in-memory step
	gs.tutorial_current_step = 0

	# Reload from disk
	var ok = gs.load_from_disk()
	assert_test(ok == true, "Load partial intro from disk succeeded")
	assert_test(gs.tutorial_current_step == 3, "Partial intro step 3 restored from disk")
	assert_test(gs.tutorial_completed == false, "tutorial_completed is still false during mid-intro")
	assert_test(gs.is_first_time_player() == true, "is_first_time_player() remains true during mid-intro")

# ------------------------------------------------------------------------------
# SUITE 4: Replay -> Completion / Skip Persistence Lifecycle
# ------------------------------------------------------------------------------
func suite_4_replay_skip_and_complete_persistence_lifecycle() -> void:
	print("\n--- SUITE 4: Replay Completion and Skip Full Persistence Lifecycle ---")
	var gs = root.get_node_or_null("GameState")
	var tm = root.get_node_or_null("TutorialManager")
	if gs == null or tm == null:
		return

	# Sub-Test 4A: Reset -> Skip -> Save -> Reload
	gs.reset_tutorial_state()
	tm.start_linear_intro()
	assert_test(tm.is_tutorial_active() == true, "Tutorial is active during replayed intro")

	# Skip replayed tutorial
	tm.skip_tutorial()

	assert_test(gs.tutorial_completed == true, "After skip: tutorial_completed == true")
	assert_test(gs.tutorial_skipped == true, "After skip: tutorial_skipped == true")
	assert_test(gs.tutorial_replay_requested == false, "After skip: tutorial_replay_requested == false")
	assert_test(gs.is_first_time_player() == false, "After skip: is_first_time_player() == false")
	assert_test(tm.should_start_intro() == false, "After skip: tm.should_start_intro() == false")

	# Reload from disk to verify persisted skip state
	gs.tutorial_completed = false
	gs.tutorial_skipped = false
	gs.tutorial_replay_requested = true
	gs.load_from_disk()

	assert_test(gs.tutorial_completed == true, "Persisted Skip: tutorial_completed == true")
	assert_test(gs.tutorial_skipped == true, "Persisted Skip: tutorial_skipped == true")
	assert_test(gs.tutorial_replay_requested == false, "Persisted Skip: tutorial_replay_requested == false")
	assert_test(gs.is_first_time_player() == false, "Persisted Skip: is_first_time_player() == false")
	assert_test(tm.should_start_intro() == false, "Persisted Skip: tm.should_start_intro() == false")

# ------------------------------------------------------------------------------
# SUITE 5: Reset -> Immediate Hint Triggering -> Save -> Reload
# ------------------------------------------------------------------------------
func suite_5_reset_immediate_hint_persistence_cycle() -> void:
	print("\n--- SUITE 5: Reset -> Contextual Hint Trigger -> Save -> Reload ---")
	var gs = root.get_node_or_null("GameState")
	var tm = root.get_node_or_null("TutorialManager")
	if gs == null or tm == null:
		return

	# Reset tutorial state
	gs.reset_tutorial_state()
	assert_test(gs.tutorial_seen_hints.is_empty(), "Pre-condition: hints empty after reset")

	# Trigger a contextual hint
	tm.trigger_contextual_hint("hint_zone_gate")
	assert_test(gs.has_seen_contextual_hint("hint_zone_gate") == true,
		"Hint 'hint_zone_gate' marked seen after trigger")

	# Save to disk and reload
	gs.save_to_disk()
	gs.tutorial_seen_hints.clear()
	assert_test(gs.tutorial_seen_hints.is_empty(), "Memory cleared before disk reload")

	var ok = gs.load_from_disk()
	assert_test(ok == true, "load_from_disk() succeeded after hint trigger")
	assert_test(gs.has_seen_contextual_hint("hint_zone_gate") == true,
		"Persisted hint 'hint_zone_gate' restored as seen")
	assert_test(gs.has_seen_contextual_hint("hint_tech_tree") == false,
		"Untriggered hint 'hint_tech_tree' remains unseen")
	assert_test(gs.tutorial_seen_hints.size() == 1,
		"Exactly 1 hint present in tutorial_seen_hints dictionary")

# ------------------------------------------------------------------------------
# SUITE 6: Reset on Corrupted Disk File
# ------------------------------------------------------------------------------
func suite_6_reset_recovery_over_corrupted_disk_save() -> void:
	print("\n--- SUITE 6: Reset Recovery Over Corrupted Disk Save ---")
	var gs = root.get_node_or_null("GameState")
	if gs == null:
		return

	# Write corrupted non-JSON junk to disk
	var f = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	f.store_string("<<<CORRUPT_JUNK_DATA_NOT_JSON>>>")
	f.close()

	assert_test(FileAccess.file_exists(SAVE_PATH), "Corrupted save exists on disk")

	# Call reset_tutorial_state() - should cleanly overwrite corrupted disk file with valid save
	gs.reset_tutorial_state()

	# Read file content from disk to verify it is valid JSON
	var f_read = FileAccess.open(SAVE_PATH, FileAccess.READ)
	var content = f_read.get_as_text()
	f_read.close()

	var test_json = JSON.new()
	var parse_err = test_json.parse(content)
	assert_test(parse_err == OK, "File overwritten by reset_tutorial_state() parses cleanly as valid JSON")

	var data = test_json.data
	assert_test(data is Dictionary, "Parsed JSON root is a Dictionary")
	assert_test(data.get("tutorial_replay_requested") == true, "JSON contains 'tutorial_replay_requested': true")
	assert_test(data.get("tutorial_completed") == false, "JSON contains 'tutorial_completed': false")

	# Verify load_from_disk() recovers smoothly
	var load_ok = gs.load_from_disk()
	assert_test(load_ok == true, "load_from_disk() succeeds after reset recovery")

# ------------------------------------------------------------------------------
# SUITE 7: Settings Modal Button Press -> Save -> Reload Sync
# ------------------------------------------------------------------------------
func suite_7_settings_modal_button_save_reload_sync() -> void:
	print("\n--- SUITE 7: Settings Modal Button Press -> Save -> Reload Sync ---")
	var gs = root.get_node_or_null("GameState")
	if gs == null:
		return

	# Veteran state
	gs.tutorial_completed = true
	gs.tutorial_skipped = false
	gs.tutorial_replay_requested = false
	gs.save_to_disk()

	var settings_scene = load("res://scenes/ui/settings_modal.tscn")
	assert_test(settings_scene != null, "settings_modal.tscn is loadable")
	if settings_scene == null:
		return

	var modal = settings_scene.instantiate()
	root.add_child(modal)

	var replay_btn: Button = modal.get_node_or_null("%ReplayTutorialButton")
	assert_test(replay_btn != null, "%ReplayTutorialButton found in settings modal")

	if replay_btn != null:
		# Click button
		replay_btn.pressed.emit()
		assert_test(gs.tutorial_replay_requested == true, "Button pressed sets tutorial_replay_requested = true")

		# Check that disk save was triggered by button press handler
		gs.tutorial_replay_requested = false
		var ok = gs.load_from_disk()
		assert_test(ok == true, "load_from_disk() after button press succeeds")
		assert_test(gs.tutorial_replay_requested == true, "Disk save confirmed: tutorial_replay_requested persisted as true")
		assert_test(gs.is_first_time_player() == true, "is_first_time_player() confirmed true after reload")

	modal.queue_free()
