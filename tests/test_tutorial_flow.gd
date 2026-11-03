extends SceneTree

## Headless Integration & Unit Test Runner for Milestone 2:
## TutorialManager Autoload, 6-Step Linear Intro Flow (F3-F8), Skip Button Flow (F9),
## and Layer Elevation / Ergonomics.
## Execution: godot --headless --path IdleArcade -s tests/test_tutorial_flow.gd

var pass_count: int = 0
var fail_count: int = 0

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

func _run_tests() -> void:
	print("=================================================================")
	print("Running Milestone 2 Tutorial Flow & Autoload Test Suite")
	print("=================================================================")

	await process_frame
	await process_frame

	var tm = root.get_node_or_null("TutorialManager")
	var gs = root.get_node_or_null("GameState")

	# -------------------------------------------------------------------------
	# TIER 1: Autoload Registration, Properties & API Contracts
	# -------------------------------------------------------------------------
	print("\n--- TIER 1: Autoload Registration & Public API Contracts ---")
	_assert_check(tm != null, "TutorialManager autoload is mounted at /root/TutorialManager")
	_assert_check(tm is Node, "TutorialManager extends Node")
	_assert_check(tm.has_signal("step_started"), "TutorialManager declares signal 'step_started'")
	_assert_check(tm.has_signal("step_completed"), "TutorialManager declares signal 'step_completed'")
	_assert_check(tm.has_signal("tutorial_completed"), "TutorialManager declares signal 'tutorial_completed'")
	_assert_check(tm.has_signal("tutorial_skipped"), "TutorialManager declares signal 'tutorial_skipped'")
	_assert_check(tm.has_signal("contextual_hint_triggered"), "TutorialManager declares signal 'contextual_hint_triggered'")

	_assert_check(tm.has_method("start_linear_intro"), "TutorialManager defines method 'start_linear_intro'")
	_assert_check(tm.has_method("advance_step"), "TutorialManager defines method 'advance_step'")
	_assert_check(tm.has_method("skip_tutorial"), "TutorialManager defines method 'skip_tutorial'")
	_assert_check(tm.has_method("trigger_contextual_hint"), "TutorialManager defines method 'trigger_contextual_hint'")
	_assert_check(tm.has_method("get_current_step"), "TutorialManager defines method 'get_current_step'")
	_assert_check(tm.has_method("is_tutorial_active"), "TutorialManager defines method 'is_tutorial_active'")
	_assert_check(tm.has_method("should_start_intro"), "TutorialManager defines method 'should_start_intro'")
	_assert_check(tm.has_method("reset_tutorial"), "TutorialManager defines method 'reset_tutorial'")

	_assert_check(tm.get_current_step() == 0, "Initial current_step is 0 (IDLE)")
	_assert_check(not tm.is_tutorial_active(), "Initial is_tutorial_active() is false")

	_assert_check(tm.tutorial_overlay != null, "TutorialManager automatically instantiates TutorialOverlay child")
	_assert_check(tm.tutorial_overlay is CanvasLayer, "TutorialOverlay is a CanvasLayer")
	_assert_check(tm.tutorial_overlay.layer == 95, "TutorialOverlay resides on layer 95")

	# -------------------------------------------------------------------------
	# TIER 2: Linear Intro Step 1: Core Reactor Tapping (Feature F3)
	# -------------------------------------------------------------------------
	print("\n--- TIER 2: Linear Intro Step 1 (Core Reactor Tap) ---")
	var step_started_records: Array = []
	var step_completed_records: Array = []
	var signal_events: Dictionary = {
		"tutorial_completed": 0,
		"tutorial_skipped": 0,
		"hints": []
	}

	var cb_started = func(step_idx: int, target_name: String):
		step_started_records.append({"step": step_idx, "target": target_name})
	var cb_completed = func(step_idx: int):
		step_completed_records.append(step_idx)
	var cb_tut_done = func():
		signal_events["tutorial_completed"] += 1
	var cb_tut_skip = func():
		signal_events["tutorial_skipped"] += 1

	tm.step_started.connect(cb_started)
	tm.step_completed.connect(cb_completed)
	tm.tutorial_completed.connect(cb_tut_done)
	tm.tutorial_skipped.connect(cb_tut_skip)

	if gs != null:
		gs.energy = 0.0

	tm.start_linear_intro()
	await process_frame

	_assert_check(tm.get_current_step() == 1, "start_linear_intro() sets current_step to 1")
	_assert_check(tm.is_tutorial_active(), "is_tutorial_active() returns true during intro")
	_assert_check(step_started_records.size() >= 1 and step_started_records[-1]["step"] == 1,
		"step_started(1, 'Core') signal emitted")
	_assert_check(tm.tutorial_overlay.get_node("%SkipButton").visible, "SkipButton is visible during Step 1")

	var dp = tm.get_dialogue_panel()
	_assert_check(dp != null and dp.visible, "DialoguePanel is visible during Step 1")
	if dp != null:
		var name_lbl = dp.get_node_or_null("%NPCNameLabel") as Label
		var title_lbl = dp.get_node_or_null("%NPCTitleLabel") as Label
		var dial_lbl = dp.get_node_or_null("%DialogueLabel") as Label
		_assert_check(name_lbl != null and name_lbl.text == "Angel Investor", "Mascot speaker is 'Angel Investor'")
		_assert_check(title_lbl != null and "Pre-Seed" in title_lbl.text, "Title contains 'Pre-Seed'")
		_assert_check(dial_lbl != null and "Reaktorkern" in dial_lbl.text, "German copy guides tapping the reactor core")

	# Simulate core tap in Step 1
	if gs != null and gs.has_signal("core_tapped"):
		gs.core_tapped.emit(1)
	else:
		tm.advance_step()
	await process_frame

	_assert_check(gs == null or gs.energy >= 30.0, "Step 1 awards +30 seed energy to guarantee upgrade liquidity")
	_assert_check(step_completed_records.has(1), "step_completed(1) emitted on core tap")
	_assert_check(tm.get_current_step() == 2, "Progressed to Step 2 (INTRO_STEP_2_UPGRADE)")

	# -------------------------------------------------------------------------
	# TIER 3: Linear Intro Step 2: First Upgrade Purchase (Feature F4)
	# -------------------------------------------------------------------------
	print("\n--- TIER 3: Linear Intro Step 2 (First Upgrade) ---")
	_assert_check(step_started_records[-1]["step"] == 2, "step_started(2, 'UpgradeShop') emitted")
	if dp != null:
		var title_lbl = dp.get_node_or_null("%NPCTitleLabel") as Label
		var dial_lbl = dp.get_node_or_null("%DialogueLabel") as Label
		_assert_check(title_lbl != null and ("Seed" in title_lbl.text or "Wachstum" in title_lbl.text),
			"Step 2 title relates to Seed Stage / Upgrades")
		_assert_check(dial_lbl != null and "Virale Memes" in dial_lbl.text,
			"German copy guides buying 'Virale Memes' upgrade")

	# Simulate upgrade purchase in Step 2
	if gs != null and gs.has_signal("upgrade_purchased"):
		gs.upgrade_purchased.emit("tier_1", 1, 25.0)
	else:
		tm.advance_step()
	await process_frame

	_assert_check(step_completed_records.has(2), "step_completed(2) emitted on upgrade purchase")
	_assert_check(tm.get_current_step() == 3, "Progressed to Step 3 (INTRO_STEP_3_FRENZY)")

	# -------------------------------------------------------------------------
	# TIER 4: Linear Intro Step 3: Frenzy / Overdrive Meter (Feature F5)
	# -------------------------------------------------------------------------
	print("\n--- TIER 4: Linear Intro Step 3 (Frenzy Meter) ---")
	_assert_check(step_started_records[-1]["step"] == 3, "step_started(3, 'FrenzyMeter') emitted")
	if dp != null:
		var title_lbl = dp.get_node_or_null("%NPCTitleLabel") as Label
		var dial_lbl = dp.get_node_or_null("%DialogueLabel") as Label
		_assert_check(title_lbl != null and "Overdrive" in title_lbl.text, "Step 3 title contains 'Overdrive'")
		_assert_check(dial_lbl != null and "Hype-Balken" in dial_lbl.text, "German copy explains frenzy hype meter")

	# Advance via dialogue Weiter button or frenzy update
	if dp != null and dp.has_signal("tutorial_advanced"):
		dp.tutorial_advanced.emit()
	else:
		tm.advance_step()
	await process_frame

	_assert_check(step_completed_records.has(3), "step_completed(3) emitted")
	_assert_check(tm.get_current_step() == 4, "Progressed to Step 4 (INTRO_STEP_4_CAMPUS)")

	# -------------------------------------------------------------------------
	# TIER 5: Linear Intro Step 4: 3D Campus Navigation (Feature F6)
	# -------------------------------------------------------------------------
	print("\n--- TIER 5: Linear Intro Step 4 (3D Campus Navigation) ---")
	_assert_check(step_started_records[-1]["step"] == 4, "step_started(4, 'VirtualJoystick') emitted")
	if dp != null:
		var title_lbl = dp.get_node_or_null("%NPCTitleLabel") as Label
		var dial_lbl = dp.get_node_or_null("%DialogueLabel") as Label
		_assert_check(title_lbl != null and "Campus" in title_lbl.text, "Step 4 title contains 'Campus'")
		_assert_check(dial_lbl != null and "virtuellen Joystick" in dial_lbl.text,
			"German copy explains virtual joystick navigation")

	# Advance on movement simulation
	tm.advance_step()
	await process_frame

	_assert_check(step_completed_records.has(4), "step_completed(4) emitted")
	_assert_check(tm.get_current_step() == 5, "Progressed to Step 5 (INTRO_STEP_5_COLLECTIBLE)")

	# -------------------------------------------------------------------------
	# TIER 6: Linear Intro Step 5: Collectible Pickup (Feature F7)
	# -------------------------------------------------------------------------
	print("\n--- TIER 6: Linear Intro Step 5 (Collectible Pickup) ---")
	_assert_check(step_started_records[-1]["step"] == 5, "step_started(5, 'Collectible') emitted")
	if dp != null:
		var title_lbl = dp.get_node_or_null("%NPCTitleLabel") as Label
		var dial_lbl = dp.get_node_or_null("%DialogueLabel") as Label
		_assert_check(title_lbl != null and ("Förderung" in title_lbl.text or "Ressourcen" in title_lbl.text),
			"Step 5 title relates to campus resources")
		_assert_check(dial_lbl != null and "Sammelradius" in dial_lbl.text,
			"German copy explains magnetic collection radius")

	# Simulate collectible pickup
	if gs != null and gs.has_signal("collectible_picked_up"):
		gs.collectible_picked_up.emit("briefcase", 1)
	else:
		tm.advance_step()
	await process_frame

	_assert_check(step_completed_records.has(5), "step_completed(5) emitted")
	_assert_check(tm.get_current_step() == 6, "Progressed to Step 6 (INTRO_STEP_6_STATION)")

	# -------------------------------------------------------------------------
	# TIER 7: Linear Intro Step 6: First Station Interaction & Completion (Feature F8)
	# -------------------------------------------------------------------------
	print("\n--- TIER 7: Linear Intro Step 6 (Station Interaction & Graduation) ---")
	_assert_check(step_started_records[-1]["step"] == 6, "step_started(6, 'ServerTerminal') emitted")
	if dp != null:
		var title_lbl = dp.get_node_or_null("%NPCTitleLabel") as Label
		var dial_lbl = dp.get_node_or_null("%DialogueLabel") as Label
		_assert_check(title_lbl != null and ("Server" in title_lbl.text or "Stationen" in title_lbl.text or "Infrastruktur" in title_lbl.text),
			"Step 6 title relates to server station")
		_assert_check(dial_lbl != null and "[E] Hack" in dial_lbl.text,
			"German copy explains '[E] Hack' action button")

	# Trigger completion
	tm.advance_step()
	await process_frame

	_assert_check(step_completed_records.has(6), "step_completed(6) emitted")
	_assert_check(signal_events["tutorial_completed"] >= 1, "tutorial_completed signal emitted upon Step 6 finish")
	_assert_check(tm.get_current_step() == int(tm.State.COMPLETED), "current_step is COMPLETED (7)")
	_assert_check(not tm.is_tutorial_active(), "is_tutorial_active() returns false after completion")
	_assert_check(not tm.tutorial_overlay.get_node("%SkipButton").visible, "SkipButton is hidden after completion")

	if dp != null:
		var title_lbl = dp.get_node_or_null("%NPCTitleLabel") as Label
		var close_btn = dp.get_node_or_null("%CloseButton") as Button
		_assert_check(title_lbl != null and "Unicorn-Ready" in title_lbl.text,
			"Graduation dialogue congratulates with 'Unicorn-Ready'")
		_assert_check(close_btn != null and "Los geht's" in close_btn.text,
			"Graduation button labeled 'Los geht's! 🚀'")

	# -------------------------------------------------------------------------
	# TIER 8: Skip Button Flow & Immediate Unlock (Feature F9)
	# -------------------------------------------------------------------------
	print("\n--- TIER 8: Skip Button Flow & Immediate Unlock (Feature F9) ---")
	tm.reset_tutorial()
	_assert_check(tm.get_current_step() == 0, "reset_tutorial() resets current_step to 0")
	_assert_check(not tm.is_tutorial_active(), "is_tutorial_active() is false after reset")

	# Clean state in GameState if applicable
	if gs != null:
		if "tutorial_completed" in gs:
			gs.tutorial_completed = false
		if "tutorial_skipped" in gs:
			gs.tutorial_skipped = false

	# Reset counters
	signal_events["tutorial_completed"] = 0
	signal_events["tutorial_skipped"] = 0

	# Start intro afresh
	tm.start_linear_intro()
	_assert_check(tm.get_current_step() == 1, "Intro restarted at Step 1")
	_assert_check(tm.is_tutorial_active(), "Intro is active")

	# Trigger skip via public method or overlay signal
	tm.skip_tutorial()
	await process_frame

	_assert_check(signal_events["tutorial_skipped"] >= 1, "tutorial_skipped signal emitted on skip_tutorial()")
	_assert_check(signal_events["tutorial_completed"] >= 1, "tutorial_completed signal emitted on skip_tutorial()")
	_assert_check(tm.get_current_step() == int(tm.State.COMPLETED), "Step transitioned directly to COMPLETED")
	_assert_check(not tm.is_tutorial_active(), "Tutorial no longer active after skip")
	_assert_check(not tm.tutorial_overlay.get_node("%SkipButton").visible, "SkipButton is hidden after skip")
	if gs != null:
		if "tutorial_skipped" in gs:
			_assert_check(gs.tutorial_skipped == true, "GameState.tutorial_skipped flag set to true")
		if "tutorial_completed" in gs:
			_assert_check(gs.tutorial_completed == true, "GameState.tutorial_completed flag set to true")

	# -------------------------------------------------------------------------
	# TIER 9: Contextual Hint System Delegation
	# -------------------------------------------------------------------------
	print("\n--- TIER 9: Contextual Hint System Delegation ---")
	var on_hint = func(h_id: String): signal_events["hints"].append(h_id)
	tm.contextual_hint_triggered.connect(on_hint)

	tm.trigger_contextual_hint("hint_zone_gate")
	await process_frame

	_assert_check(signal_events["hints"].has("hint_zone_gate"), "contextual_hint_triggered emitted with 'hint_zone_gate'")
	if dp != null:
		_assert_check(dp.visible, "DialoguePanel opened for contextual hint")
		var name_lbl = dp.get_node_or_null("%NPCNameLabel") as Label
		var title_lbl = dp.get_node_or_null("%NPCTitleLabel") as Label
		_assert_check(name_lbl != null and "Zonentor" in name_lbl.text,
			"Hint popup displays correct German title for zone gate in name_label")
		_assert_check(title_lbl != null and "Hinweis" in title_lbl.text,
			"Hint popup displays 'Hinweis' badge in title_label")
		if dp.has_method("close_dialogue"):
			dp.close_dialogue()

	# Disconnect test listeners
	tm.step_started.disconnect(cb_started)
	tm.step_completed.disconnect(cb_completed)
	tm.tutorial_completed.disconnect(cb_tut_done)
	tm.tutorial_skipped.disconnect(cb_tut_skip)
	tm.contextual_hint_triggered.disconnect(on_hint)

	await process_frame

	print("\n=================================================================")
	print("Milestone 2 Test Results: %d Passed, %d Failed" % [pass_count, fail_count])
	print("=================================================================")

	quit(0 if fail_count == 0 else 1)
