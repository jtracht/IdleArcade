extends SceneTree

## =============================================================================
## EMPIRICAL ADVERSARIAL STRESS TEST FOR DOMAIN 5 (Phase 17)
## File: IdleArcade/tests/test_p17_m4_domain5_stress.gd
##
## Tests:
## 1. Zero State Pollution: Verifies GameState isolation and clean reset.
## 2. Repeated Execution Idempotency: Runs Domain 5 three consecutive times.
## 3. Hostile State Pre-Injection: Pollutes GameState before execution.
## 4. Reverse Domain Interleaving: Runs Domain 5 then Domain 1 to test pollution.
## 5. Signal Leak & Teardown Audit: Verifies signal listeners and file cleanup.
## =============================================================================

var pass_count: int = 0
var fail_count: int = 0
var _mounted_nodes: Array[Node] = []
var _save_backup_text: String = ""
var _had_save_backup: bool = false
const EPSILON: float = 0.005

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

func _init() -> void:
	print("\n====================================================================")
	print(">>> EMPIRICAL CHALLENGER: DOMAIN 5 ADVERSARIAL STRESS HARNESS <<<")
	print("====================================================================")

	if FileAccess.file_exists("user://savegame.json"):
		var f_back = FileAccess.open("user://savegame.json", FileAccess.READ)
		if f_back != null:
			_save_backup_text = f_back.get_as_text()
			_had_save_backup = true
			f_back.close()
	else:
		_had_save_backup = false

	call_deferred("_run_stress_harness")

func _cleanup_and_quit(exit_code: int) -> void:
	print("\n--- TEARDOWN: Restoring Environment & Cleaning Singletons ---")
	if _had_save_backup:
		var f_res = FileAccess.open("user://savegame.json", FileAccess.WRITE)
		if f_res != null:
			f_res.store_string(_save_backup_text)
			f_res.close()
			print("  [CLEANUP] Restored original user://savegame.json")
	elif FileAccess.file_exists("user://savegame.json"):
		DirAccess.remove_absolute("user://savegame.json")
		print("  [CLEANUP] Removed temporary user://savegame.json")

	for i in range(_mounted_nodes.size() - 1, -1, -1):
		var n = _mounted_nodes[i]
		if is_instance_valid(n):
			if n.get_parent() != null:
				n.get_parent().remove_child(n)
			n.free()
	_mounted_nodes.clear()
	print("  [CLEANUP] All test harness singletons safely unmounted.")
	quit(exit_code)

func _run_stress_harness() -> void:
	await process_frame
	await process_frame

	# Mount GameState
	var gs = root.get_node_or_null("GameState")
	if gs == null:
		var gs_script = load("res://scripts/autoload/game_state.gd")
		gs = gs_script.new()
		gs.name = "GameState"
		root.add_child(gs)
		_mounted_nodes.append(gs)

	# Mount TutorialManager
	var tm = root.get_node_or_null("TutorialManager")
	if tm == null:
		var tm_script = load("res://scripts/autoload/tutorial_manager.gd")
		tm = tm_script.new()
		tm.name = "TutorialManager"
		root.add_child(tm)
		_mounted_nodes.append(tm)

	await process_frame

	_assert_check(gs != null, "Mount GameState singleton")
	_assert_check(tm != null, "Mount TutorialManager singleton")

	# -------------------------------------------------------------------------
	# EXPERIMENT 1: Single Domain 5 Run
	# -------------------------------------------------------------------------
	print("\n--- EXPERIMENT 1: Standard Domain 5 Execution & Baseline Verification ---")
	await _execute_domain_5_battery(gs, tm, "Run 1")

	# Check state pollution before reset
	_assert_check(gs.energy == 50000.0, "Exp 1: Expected end-of-domain energy is 50,000.0 (veteran test)")
	_assert_check(gs.tutorial_replay_requested == true, "Exp 1: Expected end-of-domain replay_requested is true")

	# Verify reset_state() fully neutralizes pollution
	gs.reset_state()
	gs.reset_tutorial_state()
	tm.reset_tutorial()
	_assert_check(gs.energy == 0.0, "Exp 1: GameState.reset_state() restores energy to 0.0")
	_assert_check(gs.total_energy_earned == 0.0, "Exp 1: GameState.reset_state() restores total_energy_earned to 0.0")
	_assert_check(gs.upgrades["tier_1"]["level"] == 0, "Exp 1: GameState.reset_state() restores tier_1 level to 0")
	_assert_check(gs.angel_shares == 0, "Exp 1: GameState.reset_state() restores angel_shares to 0")
	_assert_check(gs.tutorial_current_step == 0, "Exp 1: tutorial_current_step is 0 after reset")
	_assert_check(gs.tutorial_completed == false, "Exp 1: tutorial_completed is false after reset")
	_assert_check(gs.tutorial_skipped == false, "Exp 1: tutorial_skipped is false after reset")
	_assert_check(gs.tutorial_seen_hints.is_empty(), "Exp 1: tutorial_seen_hints is empty after reset")

	# -------------------------------------------------------------------------
	# EXPERIMENT 2: Consecutive Domain 5 Runs (Idempotency / 3x Repeat)
	# -------------------------------------------------------------------------
	print("\n--- EXPERIMENT 2: Back-to-Back Consecutive Domain 5 Runs (Idempotency) ---")
	for repeat_idx in [2, 3]:
		print("\n  >> Starting Consecutive Run %d <<" % repeat_idx)
		gs.reset_state()
		gs.reset_tutorial_state()
		tm.reset_tutorial()
		await _execute_domain_5_battery(gs, tm, "Run %d" % repeat_idx)

	# -------------------------------------------------------------------------
	# EXPERIMENT 3: Hostile Pre-State Pollution Resilience
	# -------------------------------------------------------------------------
	print("\n--- EXPERIMENT 3: Hostile Pre-State Pollution Resilience ---")
	# Inject corrupted / dirty state
	gs.energy = -999999.0
	gs.total_energy_earned = -1.0
	gs.tutorial_current_step = 99
	gs.tutorial_completed = true
	gs.tutorial_skipped = true
	gs.tutorial_seen_hints = {"hint_zone_gate": true, "corrupted_hint": true, "": false}
	gs.tutorial_replay_requested = false
	gs.frenzy_meter = 100.0
	gs.is_frenzy_active = true
	tm.current_step = 6
	tm.is_intro_active = true

	# Perform standard domain entry setup as done in test_full_stack_qa.gd
	if gs.has_method("reset_state"):
		gs.reset_state()
	if gs.has_method("reset_tutorial_state"):
		gs.reset_tutorial_state()
	if tm != null and tm.has_method("reset_tutorial"):
		tm.reset_tutorial()

	_assert_check(gs.energy == 0.0, "Exp 3: Hostile negative energy sanitized to 0.0")
	_assert_check(gs.tutorial_current_step == 0, "Exp 3: Corrupted step 99 sanitized to 0")
	_assert_check(gs.tutorial_completed == false, "Exp 3: Completed flag sanitized to false")
	_assert_check(gs.tutorial_skipped == false, "Exp 3: Skipped flag sanitized to false")
	_assert_check(gs.tutorial_seen_hints.is_empty(), "Exp 3: Corrupted hint dictionary wiped clean")
	_assert_check(tm.get_current_step() == 0, "Exp 3: TutorialManager step sanitized to 0 (IDLE)")
	_assert_check(not tm.is_tutorial_active(), "Exp 3: TutorialManager is_intro_active sanitized to false")

	await _execute_domain_5_battery(gs, tm, "Hostile Pre-Pollution Run")

	# -------------------------------------------------------------------------
	# EXPERIMENT 4: Reverse Domain Interleaving (Domain 5 -> Domain 1)
	# -------------------------------------------------------------------------
	print("\n--- EXPERIMENT 4: Reverse Domain Interleaving (Domain 5 -> Domain 1) ---")
	# After Domain 5, GameState has 50,000 energy from veteran replay test
	# Now simulate entering Domain 1 (Backend Core & Economy)
	if gs.has_method("reset_state"):
		gs.reset_state()
	await process_frame

	_assert_check(absf(gs.base_click_power - 1.0) < EPSILON, "Exp 4: Domain 1 base_click_power is 1.0")
	_assert_check(gs.total_clicks == 0, "Exp 4: Domain 1 total_clicks is 0")
	_assert_check(absf(gs.frenzy_meter - 0.0) < EPSILON, "Exp 4: Domain 1 frenzy_meter is 0.0")
	_assert_check(gs.is_frenzy_active == false, "Exp 4: Domain 1 is_frenzy_active is false")
	_assert_check(absf(gs.frenzy_multiplier - 1.0) < EPSILON, "Exp 4: Domain 1 frenzy_multiplier is 1.0")
	_assert_check(gs.energy == 0.0, "Exp 4: Domain 1 energy is pristine 0.0")

	# Simulate active click loop in Domain 1
	gs.tap_core()
	_assert_check(gs.total_clicks == 1, "Exp 4: Active click works post-Domain 5")
	_assert_check(gs.energy >= 1.0, "Exp 4: Energy accumulates properly post-Domain 5")

	# -------------------------------------------------------------------------
	# EXPERIMENT 5: Signal Leak & Teardown Audit
	# -------------------------------------------------------------------------
	print("\n--- EXPERIMENT 5: Signal Connection & Teardown Audit ---")
	tm.reset_tutorial()
	_assert_check(not tm.is_tutorial_active(), "Exp 5: TutorialManager inactive after final reset")
	_assert_check(tm.current_step == 0, "Exp 5: TutorialManager current_step is IDLE (0)")

	# Check overlay unblocked state
	if tm.tutorial_overlay != null:
		_assert_check(not tm.tutorial_overlay.is_highlight_active(), "Exp 5: Overlay highlight cleared")
		var skip_b = tm.tutorial_overlay.get_node_or_null("%SkipButton")
		if skip_b != null:
			_assert_check(not skip_b.visible, "Exp 5: SkipButton hidden after teardown")

	# -------------------------------------------------------------------------
	# Summary
	# -------------------------------------------------------------------------
	print("\n====================================================================")
	print(">>> EMPIRICAL STRESS HARNESS SUMMARY <<<")
	print("====================================================================")
	print("  Passed : %d" % pass_count)
	print("  Failed : %d" % fail_count)
	print("====================================================================")

	if fail_count == 0:
		print(">>> ALL EMPIRICAL CHALLENGER TESTS PASSED (Exit Code 0) <<<")
		_cleanup_and_quit(0)
	else:
		printerr(">>> CHALLENGER STRESS HARNESS DETECTED FAILURES (Exit Code 1) <<<")
		_cleanup_and_quit(1)


## Executes all 6 subdomains corresponding to Domain 5
func _execute_domain_5_battery(gs: Node, tm: Node, tag: String) -> void:
	# Subdomain 5.1: State Machine & Intro Flow (F3-F9)
	tm.reset_tutorial()
	gs.reset_tutorial_state()
	gs.energy = 0.0
	await process_frame

	_assert_check(tm.get_current_step() == 0, "[%s] Sub 5.1: Initial step is 0" % tag)
	_assert_check(not tm.is_tutorial_active(), "[%s] Sub 5.1: Tutorial inactive after reset" % tag)

	var step_events: Array[int] = []
	var comp_events: Array = []
	var skip_events: Array = []
	var cb_st = func(s: int, _t: String): step_events.append(s)
	var cb_co = func(): comp_events.append(true)
	var cb_sk = func(): skip_events.append(true)

	tm.step_started.connect(cb_st)
	tm.tutorial_completed.connect(cb_co)
	tm.tutorial_skipped.connect(cb_sk)

	tm.start_linear_intro()
	await process_frame
	_assert_check(tm.get_current_step() == 1, "[%s] Sub 5.1: Step 1 active" % tag)
	_assert_check(tm.is_tutorial_active(), "[%s] Sub 5.1: Tutorial active" % tag)

	# Tap Core -> Advance to 2
	gs.tap_core()
	await process_frame
	_assert_check(tm.get_current_step() == 2, "[%s] Sub 5.1: Step 2 active" % tag)

	# Buy upgrade -> Advance to 3
	gs.buy_upgrade("tier_1")
	await process_frame
	_assert_check(tm.get_current_step() == 3, "[%s] Sub 5.1: Step 3 active" % tag)

	# Frenzy -> Advance to 4
	gs.frenzy_meter = 25.0
	gs.frenzy_updated.emit(1.0, 0.25)
	await process_frame
	_assert_check(tm.get_current_step() == 4, "[%s] Sub 5.1: Step 4 active" % tag)

	# Campus -> Advance to 5
	tm.advance_step()
	await process_frame
	_assert_check(tm.get_current_step() == 5, "[%s] Sub 5.1: Step 5 active" % tag)

	# Collectible -> Advance to 6
	gs.collectible_picked_up.emit("briefcase", 1)
	await process_frame
	_assert_check(tm.get_current_step() == 6, "[%s] Sub 5.1: Step 6 active" % tag)

	# Station -> Advance to COMPLETED (7)
	tm.advance_step()
	await process_frame
	_assert_check(tm.get_current_step() == 7, "[%s] Sub 5.1: Step COMPLETED (7)" % tag)
	_assert_check(not tm.is_tutorial_active(), "[%s] Sub 5.1: Tutorial inactive after completion" % tag)
	_assert_check(comp_events.size() >= 1, "[%s] Sub 5.1: tutorial_completed signal received" % tag)
	_assert_check(gs.tutorial_completed == true, "[%s] Sub 5.1: GameState.tutorial_completed is true" % tag)

	# Skip Flow
	tm.reset_tutorial()
	gs.reset_tutorial_state()
	await process_frame
	tm.start_linear_intro()
	await process_frame
	_assert_check(tm.is_tutorial_active(), "[%s] Sub 5.1: Intro active before skip" % tag)
	skip_events.clear()
	comp_events.clear()
	tm.skip_tutorial()
	await process_frame
	_assert_check(skip_events.size() >= 1, "[%s] Sub 5.1: tutorial_skipped received" % tag)
	_assert_check(comp_events.size() >= 1, "[%s] Sub 5.1: tutorial_completed received on skip" % tag)
	_assert_check(tm.get_current_step() == 7, "[%s] Sub 5.1: Step 7 after skip" % tag)
	_assert_check(gs.tutorial_skipped == true, "[%s] Sub 5.1: GameState.tutorial_skipped is true" % tag)

	# Disconnect local test lambdas
	tm.step_started.disconnect(cb_st)
	tm.tutorial_completed.disconnect(cb_co)
	tm.tutorial_skipped.disconnect(cb_sk)

	# Subdomain 5.2: DialoguePanel Integration (F1)
	var dp_scene = load("res://scenes/dialogue_panel.tscn")
	var dp = dp_scene.instantiate() as DialoguePanel
	root.add_child(dp)
	await process_frame

	dp.open_for_tutorial_step("Angel Investor", "Test", "Test text", Color(1.0, 0.84, 0.0))
	_assert_check(dp.visible, "[%s] Sub 5.2: DialoguePanel visible" % tag)
	_assert_check(dp.name_label.text == "Angel Investor", "[%s] Sub 5.2: Angel Investor persona name" % tag)
	_assert_check(dp.mouse_filter == Control.MOUSE_FILTER_IGNORE, "[%s] Sub 5.2: Mouse filter IGNORE during tutorial" % tag)
	dp.close_dialogue()
	_assert_check(not dp.visible, "[%s] Sub 5.2: DialoguePanel hidden after close" % tag)

	dp.show_hint_popup("💡 Hint", "Hint text", 2.0, Rect2(), "hint_test")
	_assert_check(dp.visible, "[%s] Sub 5.2: DialoguePanel visible for hint" % tag)
	_assert_check(dp.is_hint_active(), "[%s] Sub 5.2: is_hint_active() is true" % tag)
	dp.dismiss_hint()
	_assert_check(not dp.visible, "[%s] Sub 5.2: DialoguePanel hidden after dismiss" % tag)

	dp.queue_free()
	await process_frame

	# Subdomain 5.3: Spotlight Overlay (F2)
	var ov_scene = load("res://scenes/ui/tutorial_overlay.tscn")
	var ov = ov_scene.instantiate() as TutorialOverlay
	root.add_child(ov)
	await process_frame

	_assert_check(ov.layer == 95, "[%s] Sub 5.3: Overlay layer is 95" % tag)
	var top_b = ov.get_node_or_null("TopBlocker") as ColorRect
	_assert_check(top_b != null and top_b.mouse_filter == Control.MOUSE_FILTER_STOP, "[%s] Sub 5.3: TopBlocker mouse filter is STOP" % tag)
	ov.highlight_target_rect(Rect2(200, 300, 100, 50), 0.0)
	_assert_check(ov.is_highlight_active(), "[%s] Sub 5.3: Highlight is active" % tag)
	_assert_check(ov.is_point_in_cutout(Vector2(250, 325)), "[%s] Sub 5.3: Cutout contains center" % tag)
	_assert_check(not ov.is_point_in_blocker(Vector2(250, 325)), "[%s] Sub 5.3: Center is not blocked" % tag)
	ov.clear_highlight()
	_assert_check(not ov.is_highlight_active(), "[%s] Sub 5.3: Highlight inactive after clear" % tag)

	ov.queue_free()
	await process_frame

	# Subdomain 5.4: Contextual Hints Exactly-Once (F10-F15)
	gs.tutorial_seen_hints.clear()
	var trig_hints: Array[String] = []
	var cb_h = func(h: String): trig_hints.append(h)
	tm.contextual_hint_triggered.connect(cb_h)

	var h_id = "hint_zone_gate"
	_assert_check(not gs.has_seen_contextual_hint(h_id), "[%s] Sub 5.4: Hint initially unseen" % tag)
	tm.trigger_contextual_hint(h_id)
	await process_frame
	_assert_check(trig_hints.has(h_id), "[%s] Sub 5.4: Hint triggered first time" % tag)
	_assert_check(gs.has_seen_contextual_hint(h_id), "[%s] Sub 5.4: Hint marked seen" % tag)

	# Second trigger must be suppressed
	trig_hints.clear()
	tm.trigger_contextual_hint(h_id)
	await process_frame
	_assert_check(trig_hints.is_empty(), "[%s] Sub 5.4: Duplicate hint trigger suppressed" % tag)

	tm.contextual_hint_triggered.disconnect(cb_h)

	# Subdomain 5.5: Save/Load & Truth Table (F16-F17)
	gs.reset_state()
	gs.tutorial_current_step = 4
	gs.tutorial_completed = false
	gs.tutorial_skipped = false
	gs.tutorial_seen_hints = {"hint_tech_tree": true}
	gs.save_to_disk()

	gs.tutorial_current_step = 0
	gs.tutorial_seen_hints.clear()
	var load_res = gs.load_from_disk()
	_assert_check(load_res, "[%s] Sub 5.5: load_from_disk() succeeded" % tag)
	_assert_check(gs.tutorial_current_step == 4, "[%s] Sub 5.5: Restored step 4" % tag)
	_assert_check(gs.has_seen_contextual_hint("hint_tech_tree"), "[%s] Sub 5.5: Restored seen hint" % tag)

	# Subdomain 5.6: Replay Flow Non-Destructive Isolation (F18)
	var sm_scene = load("res://scenes/ui/settings_modal.tscn")
	var sm = sm_scene.instantiate() as Control
	root.add_child(sm)
	await process_frame

	var replay_b = sm.get_node_or_null("%ReplayTutorialButton") as Button
	_assert_check(replay_b != null, "[%s] Sub 5.6: ReplayTutorialButton exists" % tag)

	# Veteran progression
	gs.reset_state()
	gs.energy = 50000.0
	gs.total_energy_earned = 250000.0
	gs.upgrades["tier_1"]["level"] = 15
	gs.angel_shares = 12
	gs.tutorial_completed = true
	gs.save_to_disk()

	replay_b.pressed.emit()
	await process_frame

	_assert_check(gs.tutorial_replay_requested == true, "[%s] Sub 5.6: replay_requested is true" % tag)
	_assert_check(gs.tutorial_completed == false, "[%s] Sub 5.6: tutorial_completed reset to false" % tag)
	_assert_check(absf(gs.energy - 50000.0) < EPSILON, "[%s] Sub 5.6: Energy intact" % tag)
	_assert_check(gs.upgrades["tier_1"]["level"] == 15, "[%s] Sub 5.6: Tier 1 level intact" % tag)
	_assert_check(gs.angel_shares == 12, "[%s] Sub 5.6: Angel shares intact" % tag)

	sm.queue_free()
	await process_frame
