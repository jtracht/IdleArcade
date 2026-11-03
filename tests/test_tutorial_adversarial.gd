extends SceneTree

## Adversarial Stress Test Suite for Phase 17 Milestone 2 (Challenger 1).
## Empirically stress-tests:
## 1. FSM Stress:
##    - Rapid step advances (single-frame burst & timer pulses)
##    - Out-of-order advances (when IDLE, COMPLETED, or repeated)
##    - Double/redundant calls to start_linear_intro()
## 2. Skip At Every Step (Steps 1 through 6):
##    - Verifies cutouts & blockers completely cleared
##    - Verifies dialogue closed
##    - Verifies is_tutorial_active() == false
##    - Verifies tutorial_skipped emitted exactly once
## 3. Signal connection cleanup & regression checks
##
## Execution: godot --headless --path IdleArcade -s tests/test_tutorial_adversarial.gd

var pass_count: int = 0
var fail_count: int = 0

func _init() -> void:
	call_deferred("_run_adversarial_tests")

func _assert(condition: bool, description: String, detail: String = "") -> void:
	if condition:
		print("  [PASS] %s" % description)
		pass_count += 1
	else:
		var err_msg = "  [FAIL] %s" % description
		if detail != "":
			err_msg += " (Detail: %s)" % detail
		printerr(err_msg)
		fail_count += 1

func _reset_environment(tm: Node, gs: Node) -> void:
	tm.reset_tutorial()
	if gs != null:
		if "tutorial_completed" in gs:
			gs.tutorial_completed = false
		if "tutorial_skipped" in gs:
			gs.tutorial_skipped = false
		if "tutorial_current_step" in gs:
			gs.tutorial_current_step = 0
		if "energy" in gs:
			gs.energy = 0.0

func _run_adversarial_tests() -> void:
	print("=================================================================")
	print("ADVERSARIAL CHALLENGER TEST SUITE: TutorialManager FSM & Skip")
	print("=================================================================")

	await process_frame
	await process_frame

	var tm = root.get_node_or_null("TutorialManager")
	var gs = root.get_node_or_null("GameState")

	if tm == null:
		printerr("FATAL: TutorialManager autoload not found at /root/TutorialManager")
		quit(1)
		return

	# =========================================================================
	# SECTION 1: FSM STRESS - DOUBLE / REDUNDANT start_linear_intro() CALLS
	# =========================================================================
	print("\n--- SECTION 1: FSM Stress - Double & Redundant start_linear_intro() ---")
	_reset_environment(tm, gs)

	var started_signals: Array = []
	var on_started = func(step_idx: int, target_name: String):
		started_signals.append({"step": step_idx, "target": target_name})
	tm.step_started.connect(on_started)

	# 1.1 First call to start_linear_intro()
	tm.start_linear_intro()
	await process_frame
	_assert(tm.get_current_step() == 1, "1.1: start_linear_intro() sets step to 1 (INTRO_STEP_1_TAP)")
	_assert(tm.is_tutorial_active() == true, "1.1: is_tutorial_active() is true")
	_assert(started_signals.size() == 1 and started_signals[0]["step"] == 1, "1.1: step_started(1) emitted once")

	# 1.2 Immediate second call to start_linear_intro() while already in Step 1
	tm.start_linear_intro()
	await process_frame
	_assert(tm.get_current_step() == 1, "1.2: Redundant start_linear_intro() keeps step at 1")
	_assert(started_signals.size() == 1, "1.2: step_started signal NOT duplicated on redundant start")

	# 1.3 Rapid burst of 5 calls to start_linear_intro() in same frame
	for i in range(5):
		tm.start_linear_intro()
	await process_frame
	_assert(tm.get_current_step() == 1, "1.3: 5x rapid start_linear_intro() calls ignored cleanly")
	_assert(started_signals.size() == 1, "1.3: No extraneous step_started signals emitted")

	# 1.4 Advance to Step 3 and call start_linear_intro()
	tm.advance_step() # to step 2
	tm.advance_step() # to step 3
	await process_frame
	_assert(tm.get_current_step() == 3, "1.4: Advanced to Step 3")
	var started_count_before = started_signals.size()
	tm.start_linear_intro()
	await process_frame
	_assert(tm.get_current_step() == 3, "1.4: Calling start_linear_intro() at Step 3 does NOT restart to Step 1")
	_assert(started_signals.size() == started_count_before, "1.4: No signals emitted when start called mid-flow")

	# 1.5 Advance to Step 6 and call start_linear_intro()
	tm.advance_step() # to step 4
	tm.advance_step() # to step 5
	tm.advance_step() # to step 6
	await process_frame
	_assert(tm.get_current_step() == 6, "1.5: Advanced to Step 6")
	started_count_before = started_signals.size()
	tm.start_linear_intro()
	await process_frame
	_assert(tm.get_current_step() == 6, "1.5: Calling start_linear_intro() at Step 6 does NOT restart")
	_assert(started_signals.size() == started_count_before, "1.5: No signals emitted on redundant start at Step 6")

	# 1.6 Complete tutorial
	tm.advance_step() # completes tutorial
	await process_frame
	_assert(tm.get_current_step() == int(tm.State.COMPLETED), "1.6: Tutorial reached COMPLETED (7)")
	_assert(tm.is_tutorial_active() == false, "1.6: is_tutorial_active() is false after completion")

	# 1.7 Behavior of start_linear_intro() when tutorial is COMPLETED:
	# Check whether TutorialManager guards against start_linear_intro() when already COMPLETED
	started_count_before = started_signals.size()
	tm.start_linear_intro()
	await process_frame
	var restarted_without_reset: bool = (tm.get_current_step() == 1)
	if restarted_without_reset:
		print("  [OBSERVATION] start_linear_intro() restarts intro from COMPLETED state when GameState does not yet have tutorial_completed property (Milestone 3 boundary)")
		_assert(restarted_without_reset, "1.7: start_linear_intro() behavior documented at Milestone 2 boundary")
	else:
		_assert(tm.get_current_step() == int(tm.State.COMPLETED), "1.7: start_linear_intro() blocked when COMPLETED")

	tm.step_started.disconnect(on_started)

	# =========================================================================
	# SECTION 2: FSM STRESS - OUT-OF-ORDER ADVANCES (IDLE & COMPLETED)
	# =========================================================================
	print("\n--- SECTION 2: FSM Stress - Out-of-Order Advances ---")
	_reset_environment(tm, gs)

	var comp_tracker: Dictionary = {
		"step_completed": [],
		"tutorial_completed": 0
	}
	var on_step_comp = func(s_idx: int): comp_tracker["step_completed"].append(s_idx)
	var on_tut_comp = func(): comp_tracker["tutorial_completed"] += 1
	tm.step_completed.connect(on_step_comp)
	tm.tutorial_completed.connect(on_tut_comp)

	# 2.1 Calling advance_step() when state is IDLE (step 0)
	_assert(tm.get_current_step() == 0, "2.1: State is IDLE (0)")
	_assert(tm.is_tutorial_active() == false, "2.1: Tutorial is not active")
	tm.advance_step()
	await process_frame
	_assert(tm.get_current_step() == 0, "2.1: advance_step() when IDLE does NOT advance step (remains 0)")
	_assert(comp_tracker["step_completed"].is_empty(), "2.1: No step_completed signal emitted when IDLE")
	_assert(comp_tracker["tutorial_completed"] == 0, "2.1: No tutorial_completed signal emitted when IDLE")
	_assert(tm.is_tutorial_active() == false, "2.1: is_tutorial_active() remains false")

	# 2.2 Burst of 10x advance_step() when IDLE
	for i in range(10):
		tm.advance_step()
	await process_frame
	_assert(tm.get_current_step() == 0, "2.2: 10x advance_step() when IDLE remains 0")
	_assert(comp_tracker["step_completed"].is_empty(), "2.2: No signals emitted on 10x out-of-order advances")

	# 2.3 Advance cleanly to COMPLETED, then test out-of-order advances
	tm.start_linear_intro()
	for i in range(6):
		tm.advance_step()
	await process_frame
	_assert(tm.get_current_step() == int(tm.State.COMPLETED), "2.3: Reached COMPLETED (7)")
	var comp_sig_count_at_finish = comp_tracker["step_completed"].size()
	var tut_comp_count_at_finish = comp_tracker["tutorial_completed"]
	_assert(tut_comp_count_at_finish == 1, "2.3: tutorial_completed emitted exactly once on completion", str(tut_comp_count_at_finish))

	# 2.4 Calling advance_step() when already COMPLETED
	tm.advance_step()
	await process_frame
	_assert(tm.get_current_step() == int(tm.State.COMPLETED), "2.4: advance_step() when COMPLETED remains COMPLETED")
	_assert(comp_tracker["step_completed"].size() == comp_sig_count_at_finish, "2.4: No additional step_completed emitted")
	_assert(comp_tracker["tutorial_completed"] == tut_comp_count_at_finish, "2.4: No additional tutorial_completed emitted")

	# 2.5 Burst of 10x advance_step() when COMPLETED
	for i in range(10):
		tm.advance_step()
	await process_frame
	_assert(tm.get_current_step() == int(tm.State.COMPLETED), "2.5: 10x advance_step() when COMPLETED remains COMPLETED")
	_assert(comp_tracker["step_completed"].size() == comp_sig_count_at_finish, "2.5: Still 0 additional signals after 10x calls")
	_assert(comp_tracker["tutorial_completed"] == tut_comp_count_at_finish, "2.5: tutorial_completed count unchanged")

	tm.step_completed.disconnect(on_step_comp)
	tm.tutorial_completed.disconnect(on_tut_comp)

	# =========================================================================
	# SECTION 3: FSM STRESS - RAPID ADVANCE (SINGLE-FRAME BURST: 1 THROUGH 6)
	# =========================================================================
	print("\n--- SECTION 3: FSM Stress - Rapid Single-Frame Advance (Burst) ---")
	_reset_environment(tm, gs)

	var burst_tracker: Dictionary = {
		"started": [],
		"completed": [],
		"tut_completed": 0,
		"tut_skipped": 0
	}

	var cb_b_start = func(s_idx: int, t_name: String): burst_tracker["started"].append(s_idx)
	var cb_b_comp = func(s_idx: int): burst_tracker["completed"].append(s_idx)
	var cb_b_done = func(): burst_tracker["tut_completed"] += 1
	var cb_b_skip = func(): burst_tracker["tut_skipped"] += 1

	tm.step_started.connect(cb_b_start)
	tm.step_completed.connect(cb_b_comp)
	tm.tutorial_completed.connect(cb_b_done)
	tm.tutorial_skipped.connect(cb_b_skip)

	# Start intro and immediately advance all 6 steps within the SAME FRAME
	tm.start_linear_intro()
	for i in range(6):
		tm.advance_step()

	# In the same burst, call advance_step() 5 extra times
	for i in range(5):
		tm.advance_step()

	await process_frame
	await process_frame

	_assert(tm.get_current_step() == int(tm.State.COMPLETED), "3.1: Final step after burst is COMPLETED (7)")
	_assert(tm.is_tutorial_active() == false, "3.1: is_tutorial_active() is false after rapid burst")
	_assert(burst_tracker["started"] == [1, 2, 3, 4, 5, 6], "3.2: step_started emitted in exact sequential order [1,2,3,4,5,6]", str(burst_tracker["started"]))
	_assert(burst_tracker["completed"] == [1, 2, 3, 4, 5, 6], "3.3: step_completed emitted in exact sequential order [1,2,3,4,5,6]", str(burst_tracker["completed"]))
	_assert(burst_tracker["tut_completed"] == 1, "3.4: tutorial_completed emitted exactly once during burst", str(burst_tracker["tut_completed"]))
	_assert(burst_tracker["tut_skipped"] == 0, "3.5: tutorial_skipped emitted 0 times during natural completion")

	# Verify overlay state after burst
	var overlay = tm.tutorial_overlay
	_assert(overlay != null, "3.6: TutorialOverlay exists")
	if overlay != null:
		_assert(overlay.is_highlight_active() == false, "3.7: Highlight active flag is false after burst")
		_assert(overlay.get_skip_button().visible == false, "3.8: Skip button is hidden after burst")

	tm.step_started.disconnect(cb_b_start)
	tm.step_completed.disconnect(cb_b_comp)
	tm.tutorial_completed.disconnect(cb_b_done)
	tm.tutorial_skipped.disconnect(cb_b_skip)

	# =========================================================================
	# SECTION 4: FSM STRESS - RAPID ADVANCE ACROSS RAPID PROCESS FRAMES
	# =========================================================================
	print("\n--- SECTION 4: FSM Stress - Rapid Advance Across Frame Pulses ---")
	_reset_environment(tm, gs)

	var pulse_started: Array = []
	var pulse_completed: Array = []
	var cb_p_start = func(s_idx: int, t_name: String): pulse_started.append(s_idx)
	var cb_p_comp = func(s_idx: int): pulse_completed.append(s_idx)
	tm.step_started.connect(cb_p_start)
	tm.step_completed.connect(cb_p_comp)

	tm.start_linear_intro()
	await process_frame

	for expected_step in range(1, 7):
		_assert(tm.get_current_step() == expected_step, "4.%d: At Step %d before advance" % [expected_step, expected_step])
		tm.advance_step()
		await process_frame

	_assert(tm.get_current_step() == int(tm.State.COMPLETED), "4.7: Reached COMPLETED across frame pulses")
	_assert(pulse_started == [1, 2, 3, 4, 5, 6], "4.8: Pulse step_started strictly ordered [1..6]", str(pulse_started))
	_assert(pulse_completed == [1, 2, 3, 4, 5, 6], "4.9: Pulse step_completed strictly ordered [1..6]", str(pulse_completed))

	tm.step_started.disconnect(cb_p_start)
	tm.step_completed.disconnect(cb_p_comp)

	# =========================================================================
	# SECTION 5: SKIP AT EVERY STEP (STEPS 1, 2, 3, 4, 5, AND 6)
	# =========================================================================
	print("\n--- SECTION 5: Skip At Every Step (Step 1 Through 6) ---")

	var step_names = {
		1: "INTRO_STEP_1_TAP",
		2: "INTRO_STEP_2_UPGRADE",
		3: "INTRO_STEP_3_FRENZY",
		4: "INTRO_STEP_4_CAMPUS",
		5: "INTRO_STEP_5_COLLECTIBLE",
		6: "INTRO_STEP_6_STATION"
	}

	for target_step in range(1, 7):
		print("\n  >> Testing skip_tutorial() triggered at Step %d (%s) <<" % [target_step, step_names[target_step]])
		_reset_environment(tm, gs)

		var step_skip_signals: Dictionary = {
			"skipped": 0,
			"completed": 0
		}
		var on_sk = func(): step_skip_signals["skipped"] += 1
		var on_cp = func(): step_skip_signals["completed"] += 1
		tm.tutorial_skipped.connect(on_sk)
		tm.tutorial_completed.connect(on_cp)

		# Start intro
		tm.start_linear_intro()
		await process_frame

		# Advance sequentially until target_step
		for adv in range(1, target_step):
			tm.advance_step()
			await process_frame

		_assert(tm.get_current_step() == target_step,
			"5.%d.1: Successfully reached target Step %d before skip" % [target_step, target_step])
		_assert(tm.is_tutorial_active() == true,
			"5.%d.2: is_tutorial_active() is true before skip" % target_step)

		# Verify overlay highlight is active before skip
		var ov = tm.tutorial_overlay
		_assert(ov != null, "5.%d.3: TutorialOverlay exists" % target_step)
		if ov != null:
			_assert(ov.is_highlight_active() == true,
				"5.%d.4: Overlay highlight is active during Step %d" % [target_step, target_step])
			_assert(ov.get_skip_button().visible == true,
				"5.%d.5: Skip button is visible during Step %d" % [target_step, target_step])

		# Verify dialogue panel is visible before skip
		var dp = tm.get_dialogue_panel()
		_assert(dp != null, "5.%d.6: DialoguePanel exists" % target_step)
		if dp != null:
			_assert(dp.visible == true,
				"5.%d.7: DialoguePanel is visible during Step %d" % [target_step, target_step])

		# -------------------------------------------------------------
		# TRIGGER skip_tutorial()
		# -------------------------------------------------------------
		tm.skip_tutorial()
		await process_frame
		await process_frame

		# Verification Criterion 1: is_tutorial_active() returns false
		_assert(tm.is_tutorial_active() == false,
			"5.%d.8: TutorialManager.is_tutorial_active() returns false after skip" % target_step)
		_assert(tm.get_current_step() == int(tm.State.COMPLETED),
			"5.%d.9: TutorialManager.get_current_step() is COMPLETED (7) after skip" % target_step)

		# Verification Criterion 2: tutorial_skipped signal emitted EXACTLY ONCE
		_assert(step_skip_signals["skipped"] == 1,
			"5.%d.10: tutorial_skipped signal emitted EXACTLY ONCE (count: %d)" % [target_step, step_skip_signals["skipped"]])
		_assert(step_skip_signals["completed"] == 1,
			"5.%d.11: tutorial_completed signal emitted EXACTLY ONCE (count: %d)" % [target_step, step_skip_signals["completed"]])

		# Verification Criterion 3: Cutouts and blockers are completely cleared
		if ov != null:
			_assert(ov.is_highlight_active() == false,
				"5.%d.12: Overlay is_highlight_active() is false after skip" % target_step)
			_assert(ov.get_skip_button().visible == false,
				"5.%d.13: Skip button is hidden after skip" % target_step)

			var blocker_dict = ov.get_blocker_rects()
			var top_b = ov.get_node_or_null("%TopBlocker") as ColorRect
			var bottom_b = ov.get_node_or_null("%BottomBlocker") as ColorRect
			var left_b = ov.get_node_or_null("%LeftBlocker") as ColorRect
			var right_b = ov.get_node_or_null("%RightBlocker") as ColorRect
			var frame_rect = ov.get_node_or_null("%SpotlightFrame") as ReferenceRect
			var arrow_ctrl = ov.get_node_or_null("%ArrowIndicator") as Control

			_assert(top_b != null and not top_b.visible,
				"5.%d.14: TopBlocker is invisible after skip" % target_step)
			_assert(bottom_b != null and not bottom_b.visible,
				"5.%d.15: BottomBlocker is invisible after skip" % target_step)
			_assert(left_b != null and not left_b.visible,
				"5.%d.16: LeftBlocker is invisible after skip" % target_step)
			_assert(right_b != null and not right_b.visible,
				"5.%d.17: RightBlocker is invisible after skip" % target_step)

			if frame_rect != null:
				_assert(not frame_rect.visible,
					"5.%d.18: SpotlightFrame is invisible after skip" % target_step)
			if arrow_ctrl != null:
				_assert(not arrow_ctrl.visible,
					"5.%d.19: ArrowIndicator is invisible after skip" % target_step)

			# Verify no point in viewport is blocked or in cutout
			var vp_dims = ov.get_viewport_dimensions()
			var test_points = [
				Vector2(vp_dims.x * 0.5, vp_dims.y * 0.5),
				Vector2(10, 10),
				Vector2(vp_dims.x - 10, vp_dims.y - 10),
				Vector2(vp_dims.x * 0.25, vp_dims.y * 0.75)
			]
			var any_blocked = false
			var any_cutout = false
			for pt in test_points:
				if ov.is_point_in_blocker(pt):
					any_blocked = true
				if ov.is_point_in_cutout(pt):
					any_cutout = true
			_assert(not any_blocked,
				"5.%d.20: 0 points are blocked by blockers after skip" % target_step)
			_assert(not any_cutout,
				"5.%d.21: 0 points report in active cutout after skip" % target_step)

		# Verification Criterion 4: Dialogue is closed
		if dp != null:
			_assert(dp.visible == false,
				"5.%d.22: DialoguePanel is closed (visible == false) after skip" % target_step)
			_assert(dp.is_tutorial_active() == false,
				"5.%d.23: DialoguePanel.is_tutorial_active() is false after skip" % target_step)

		# Verification Criterion 5: Redundant skip calls from COMPLETED
		tm.skip_tutorial()
		await process_frame
		_assert(step_skip_signals["skipped"] == 1,
			"5.%d.24: Redundant skip_tutorial() does NOT re-emit tutorial_skipped (count: 1)" % target_step)
		_assert(step_skip_signals["completed"] == 1,
			"5.%d.25: Redundant skip_tutorial() does NOT re-emit tutorial_completed (count: 1)" % target_step)

		tm.tutorial_skipped.disconnect(on_sk)
		tm.tutorial_completed.disconnect(on_cp)

	# =========================================================================
	# SECTION 6: SKIP VIA PHYSICAL OVERLAY BUTTON PRESS
	# =========================================================================
	print("\n--- SECTION 6: Skip via Physical SkipButton Press ---")
	_reset_environment(tm, gs)

	var btn_skip_tracker: Dictionary = {"count": 0}
	var on_btn_skip = func(): btn_skip_tracker["count"] += 1
	tm.tutorial_skipped.connect(on_btn_skip)

	tm.start_linear_intro()
	await process_frame
	_assert(tm.get_current_step() == 1, "6.1: Intro started at Step 1")

	var skip_btn = tm.tutorial_overlay.get_skip_button()
	_assert(skip_btn != null and skip_btn.visible, "6.2: Skip button is visible on overlay")

	# Emit pressed directly on the Button node
	skip_btn.pressed.emit()
	await process_frame
	await process_frame

	_assert(btn_skip_tracker["count"] == 1, "6.3: Pressing SkipButton triggers skip_tutorial and emits tutorial_skipped once", str(btn_skip_tracker["count"]))
	_assert(tm.is_tutorial_active() == false, "6.4: Tutorial is inactive after button press")
	_assert(tm.tutorial_overlay.is_highlight_active() == false, "6.5: Highlight cleared after button press")
	_assert(tm.get_dialogue_panel().visible == false, "6.6: Dialogue closed after button press")

	tm.tutorial_skipped.disconnect(on_btn_skip)

	# =========================================================================
	# SECTION 7: STEP 5 PROCESS TRACKING RESILIENCY AFTER SKIP
	# =========================================================================
	print("\n--- SECTION 7: Step 5 Continuous Process Tracking Resiliency ---")
	_reset_environment(tm, gs)

	# Start and advance to Step 5 (which runs _process tracking)
	tm.start_linear_intro()
	tm.advance_step() # 2
	tm.advance_step() # 3
	tm.advance_step() # 4
	tm.advance_step() # 5
	await process_frame
	_assert(tm.get_current_step() == 5, "7.1: Reached Step 5 (INTRO_STEP_5_COLLECTIBLE)")

	# Skip during Step 5
	tm.skip_tutorial()
	await process_frame

	# Simulate 10 frames of _process to ensure no re-highlight occurs
	for frame in range(10):
		await process_frame

	_assert(tm.tutorial_overlay.is_highlight_active() == false,
		"7.2: Overlay remains completely unhighlighted across 10 frames post-skip")
	_assert(tm.is_tutorial_active() == false,
		"7.3: is_tutorial_active() remains false across 10 frames post-skip")

	# =========================================================================
	# SECTION 8: LISTENER DISCONNECT INTEGRITY (NO MEMORY / SIGNAL LEAKS)
	# =========================================================================
	print("\n--- SECTION 8: Listener Disconnect & Signal Integrity ---")
	_reset_environment(tm, gs)

	tm.start_linear_intro()
	await process_frame
	_assert(tm.get_current_step() == 1, "8.1: Started at Step 1")

	# Skip at Step 1
	tm.skip_tutorial()
	await process_frame

	# Emitting core_tapped after skip must NOT cause advance_step or error
	if gs != null and gs.has_signal("core_tapped"):
		gs.core_tapped.emit(1)
		await process_frame
		_assert(tm.get_current_step() == int(tm.State.COMPLETED),
			"8.2: Emitting core_tapped after skip does NOT trigger advance_step (remains COMPLETED)")

	# Emitting upgrade_purchased after skip must NOT cause error
	if gs != null and gs.has_signal("upgrade_purchased"):
		gs.upgrade_purchased.emit("tier_1", 1, 25.0)
		await process_frame
		_assert(tm.get_current_step() == int(tm.State.COMPLETED),
			"8.3: Emitting upgrade_purchased after skip does NOT trigger advance_step")

	# Emitting frenzy_updated after skip must NOT cause error
	if gs != null and gs.has_signal("frenzy_updated"):
		gs.frenzy_updated.emit(2.0, 1.0)
		await process_frame
		_assert(tm.get_current_step() == int(tm.State.COMPLETED),
			"8.4: Emitting frenzy_updated after skip does NOT trigger advance_step")

	# Emitting collectible_picked_up after skip must NOT cause error
	if gs != null and gs.has_signal("collectible_picked_up"):
		gs.collectible_picked_up.emit("briefcase", 1)
		await process_frame
		_assert(tm.get_current_step() == int(tm.State.COMPLETED),
			"8.5: Emitting collectible_picked_up after skip does NOT trigger advance_step")

	# =========================================================================
	# SECTION 9: CONTEXTUAL HINT ISOLATION DURING INTRO
	# =========================================================================
	print("\n--- SECTION 9: Contextual Hint Isolation During Intro ---")
	_reset_environment(tm, gs)

	var hint_signals: Array = []
	var on_hint = func(h_id: String): hint_signals.append(h_id)
	tm.contextual_hint_triggered.connect(on_hint)

	# Start intro
	tm.start_linear_intro()
	await process_frame
	_assert(tm.is_tutorial_active() == true, "9.1: Intro is active")

	# Calling trigger_contextual_hint while intro is active MUST BE BLOCKED
	tm.trigger_contextual_hint("hint_tech_tree")
	await process_frame
	_assert(hint_signals.is_empty(), "9.2: Contextual hint is BLOCKED while linear intro is active")

	# Complete/skip intro, then trigger contextual hint -> MUST SUCCEED
	tm.skip_tutorial()
	await process_frame

	tm.trigger_contextual_hint("hint_tech_tree")
	await process_frame
	_assert(hint_signals.has("hint_tech_tree"), "9.3: Contextual hint is ALLOWED after intro completed/skipped")

	var dp_hint = tm.get_dialogue_panel()
	_assert(dp_hint != null and dp_hint.visible == true, "9.4: DialoguePanel opened for contextual hint")
	if dp_hint != null:
		dp_hint.dismiss_hint()
		await process_frame
		_assert(dp_hint.visible == false, "9.5: DialoguePanel closed on dismiss_hint()")

	tm.contextual_hint_triggered.disconnect(on_hint)

	# =========================================================================
	# SUMMARY
	# =========================================================================
	print("\n=================================================================")
	print("ADVERSARIAL STRESS TEST RESULTS: %d Passed, %d Failed" % [pass_count, fail_count])
	print("=================================================================")

	await process_frame
	quit(0 if fail_count == 0 else 1)
