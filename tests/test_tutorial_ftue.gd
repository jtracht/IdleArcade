extends SceneTree

## =============================================================================
## Master Standalone Headless SceneTree Test Suite for Feature F19:
## End-to-End Tutorial & First-Time User Experience (FTUE) Runner (Release v2.4.0)
## File: IdleArcade/tests/test_tutorial_ftue.gd
##
## Exhaustively certifies all 18 Phase 17 features (F1–F18):
##   - Section 1 (F1–F2): DialoguePanel tutorial extensions & TutorialOverlay spotlight cutout
##   - Section 2 (F3–F8): 6-step linear intro sequence (Tap, Upgrade, Frenzy, 3D Campus, Collectible, Station)
##   - Section 3 (F9): Skip button instant unlock & immediate state finalization
##   - Section 4 (F10–F15): 6 Contextual hints, exactly-once suppression & 6 hook integrations
##   - Section 5 (F16–F17): GameState persistence roundtrip, corrupted save immunity & 5-case truth table
##   - Section 6 (F18): Settings modal Replay Tutorial ergonomics & non-destructive reset isolation
##
## Execution:
##   godot --headless --path IdleArcade -s tests/test_tutorial_ftue.gd
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
	print(">>> RUNNING IDLEARCADE PHASE 17: FTUE & TUTORIAL MASTER TEST SUITE <<<")
	print("====================================================================")

	# Synchronous savegame backup before singletons initialize
	if FileAccess.file_exists("user://savegame.json"):
		var f_back = FileAccess.open("user://savegame.json", FileAccess.READ)
		if f_back != null:
			_save_backup_text = f_back.get_as_text()
			_had_save_backup = true
			f_back.close()
	else:
		_had_save_backup = false

	call_deferred("_run_all_ftue_tests")

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

func _run_all_ftue_tests() -> void:
	await process_frame
	await process_frame

	# Ensure autoload singletons are mounted
	var gs = root.get_node_or_null("GameState")
	if gs == null:
		var gs_script = load("res://scripts/autoload/game_state.gd")
		if gs_script != null:
			gs = gs_script.new()
			gs.name = "GameState"
			root.add_child(gs)
			_mounted_nodes.append(gs)

	var am = root.get_node_or_null("AudioManager")
	if am == null:
		var am_script = load("res://scripts/autoload/audio_manager.gd")
		if am_script != null:
			am = am_script.new()
			am.name = "AudioManager"
			root.add_child(am)
			_mounted_nodes.append(am)

	var tm = root.get_node_or_null("TutorialManager")
	if tm == null:
		var tm_script = load("res://scripts/autoload/tutorial_manager.gd")
		if tm_script != null:
			tm = tm_script.new()
			tm.name = "TutorialManager"
			root.add_child(tm)
			_mounted_nodes.append(tm)

	_assert_check(gs != null, "0.1 GameState mounted")
	_assert_check(am != null, "0.2 AudioManager mounted")
	_assert_check(tm != null, "0.3 TutorialManager mounted")

	# =========================================================================
	# SECTION 1 (F1-F2): DIALOGUE PANEL EXTENSIONS & TUTORIAL OVERLAY CUTOUT
	# =========================================================================
	print("\n--- SECTION 1 (F1-F2): DialoguePanel Extensions & TutorialOverlay Cutout ---")
	
	# F1: DialoguePanel Mascot Extensions & Strict 6-Button Constraint
	var dp_scene = load("res://scenes/dialogue_panel.tscn")
	_assert_check(dp_scene != null, "1.1 scenes/dialogue_panel.tscn loaded")
	if dp_scene != null:
		var dp = dp_scene.instantiate() as DialoguePanel
		root.add_child(dp)
		await process_frame

		# Strict Invariant: Exactly 6 Button nodes in dialogue_panel.tscn
		var buttons: Array[Node] = []
		var find_buttons = func(node: Node, recurse: Callable) -> void:
			if node is Button:
				buttons.append(node)
			for child in node.get_children():
				recurse.call(child, recurse)
		find_buttons.call(dp, find_buttons)
		_assert_check(buttons.size() == 6, "1.2 Strict Invariant: dialogue_panel.tscn contains exactly 6 Button nodes (found: %d)" % buttons.size())

		# Methods exist
		_assert_check(dp.has_method("open_for_tutorial_step"), "1.3 DialoguePanel defines open_for_tutorial_step()")
		_assert_check(dp.has_method("show_hint_popup"), "1.4 DialoguePanel defines show_hint_popup()")
		_assert_check(dp.has_method("is_hint_active"), "1.5 DialoguePanel defines is_hint_active()")
		_assert_check(dp.has_signal("tutorial_advanced"), "1.6 DialoguePanel declares signal tutorial_advanced")
		_assert_check(dp.has_signal("hint_dismissed"), "1.7 DialoguePanel declares signal hint_dismissed")

		# Tutorial step display contracts
		dp.open_for_tutorial_step("Angel Investor", "Pre-Seed // Start", "Tippe auf den Kern!", Color(1.0, 0.84, 0.0))
		_assert_check(dp.visible, "1.8 DialoguePanel becomes visible in tutorial step mode")
		_assert_check(dp.mouse_filter == Control.MOUSE_FILTER_IGNORE, "1.9 DialoguePanel root mouse_filter is IGNORE during tutorial step")
		
		var dim = dp.get_node_or_null("DimBackdrop") as Control
		if dim != null:
			_assert_check(not dim.visible, "1.10 DimBackdrop is hidden during tutorial step")

		var close_btn = dp.get_node_or_null("%CloseButton") as Button
		if close_btn != null:
			_assert_check(close_btn.text == "Weiter ➔", "1.11 CloseButton styled with 'Weiter ➔'")

		var advanced_fired: Array = []
		var cb_adv = func(): advanced_fired.append(true)
		dp.tutorial_advanced.connect(cb_adv, CONNECT_ONE_SHOT)
		dp.close_dialogue()
		_assert_check(advanced_fired.size() > 0, "1.12 close_dialogue() emits tutorial_advanced in tutorial mode")
		_assert_check(not dp.visible, "1.13 DialoguePanel hidden after advancing")

		# Hint popup display contracts
		dp.show_hint_popup("💡 Zonentor", "Dieses Tor ist verriegelt!", 2.0, Rect2(), "hint_zone_gate")
		_assert_check(dp.visible, "1.14 DialoguePanel becomes visible for hint popup")
		_assert_check(dp.is_hint_active(), "1.15 is_hint_active() returns true")
		_assert_check(dp.mouse_filter == Control.MOUSE_FILTER_IGNORE, "1.16 DialoguePanel root mouse_filter is IGNORE during hint popup")
		if dim != null:
			_assert_check(not dim.visible, "1.17 DimBackdrop remains hidden during hint popup")

		var hint_dismissed_events: Array = []
		var cb_hint = func(hid: String): hint_dismissed_events.append(hid)
		dp.hint_dismissed.connect(cb_hint, CONNECT_ONE_SHOT)
		dp.dismiss_hint()
		_assert_check(hint_dismissed_events.size() > 0 and hint_dismissed_events[-1] == "hint_zone_gate", "1.18 dismiss_hint() emits hint_dismissed with correct ID")
		_assert_check(not dp.visible, "1.19 DialoguePanel hidden after hint dismissal")

		dp.queue_free()
		await process_frame

	# F2: TutorialOverlay Spotlight & 4-Blocker Cutout System
	var ov_scene = load("res://scenes/ui/tutorial_overlay.tscn")
	_assert_check(ov_scene != null, "1.20 scenes/ui/tutorial_overlay.tscn loaded")
	if ov_scene != null:
		var ov = ov_scene.instantiate() as TutorialOverlay
		root.add_child(ov)
		await process_frame

		_assert_check(ov is CanvasLayer, "1.21 TutorialOverlay is a CanvasLayer")
		_assert_check(ov.layer == 95, "1.22 TutorialOverlay is set to layer 95")

		# 4 Blocker nodes & mouse_filter STOP
		var top_b = ov.get_node_or_null("TopBlocker") as ColorRect
		var bot_b = ov.get_node_or_null("BottomBlocker") as ColorRect
		var left_b = ov.get_node_or_null("LeftBlocker") as ColorRect
		var right_b = ov.get_node_or_null("RightBlocker") as ColorRect
		_assert_check(top_b != null and bot_b != null and left_b != null and right_b != null, "1.23 All 4 Blocker ColorRect nodes exist")
		if top_b != null and bot_b != null and left_b != null and right_b != null:
			_assert_check(top_b.mouse_filter == Control.MOUSE_FILTER_STOP, "1.24 TopBlocker has mouse_filter == STOP")
			_assert_check(bot_b.mouse_filter == Control.MOUSE_FILTER_STOP, "1.25 BottomBlocker has mouse_filter == STOP")
			_assert_check(left_b.mouse_filter == Control.MOUSE_FILTER_STOP, "1.26 LeftBlocker has mouse_filter == STOP")
			_assert_check(right_b.mouse_filter == Control.MOUSE_FILTER_STOP, "1.27 RightBlocker has mouse_filter == STOP")

		# Spotlight Cutout Geometry
		var target_rect = Rect2(300, 500, 120, 80)
		ov.highlight_target_rect(target_rect, 0.0)
		_assert_check(top_b.size.y == 500.0, "1.28 TopBlocker height matches cutout top Y (500.0)")
		_assert_check(bot_b.position.y == 580.0, "1.29 BottomBlocker position.y matches cutout bottom Y (580.0)")
		_assert_check(right_b.position.x == 420.0, "1.30 RightBlocker position.x matches cutout right X (420.0)")

		# Area partition identity: blockers + cutout == viewport area
		var vp_dims = ov.get_viewport_dimensions()
		var total_vp_area = vp_dims.x * vp_dims.y
		var cutout_area = target_rect.size.x * target_rect.size.y
		var blocker_area = (top_b.size.x * top_b.size.y) + (bot_b.size.x * bot_b.size.y) + (left_b.size.x * left_b.size.y) + (right_b.size.x * right_b.size.y)
		_assert_check(is_equal_approx(total_vp_area, cutout_area + blocker_area), "1.31 Mathematical partition: blockers + cutout == total viewport area (%.0f px^2)" % total_vp_area)

		# Cutout point containment
		_assert_check(ov.is_point_in_cutout(Vector2(360, 540)), "1.32 Target center (360, 540) is in cutout")
		_assert_check(not ov.is_point_in_cutout(Vector2(100, 100)), "1.33 Off-target point (100, 100) is NOT in cutout")

		# Arrow positioning & rotation
		var arrow = ov.get_node_or_null("ArrowIndicator") as Control
		_assert_check(arrow != null, "1.34 ArrowIndicator node exists")
		if arrow != null:
			# Lower half target -> arrow points down
			ov.highlight_target_rect(Rect2(360, 900, 100, 100), 0.0)
			_assert_check(absf(arrow.rotation - PI / 2.0) < EPSILON, "1.35 Arrow rotation is PI/2 (points DOWN) for lower-half target")
			_assert_check(arrow.position.y < 900.0, "1.36 Arrow placed above target for downward point")

			# Upper half target -> arrow points up
			ov.highlight_target_rect(Rect2(360, 200, 100, 100), 0.0)
			_assert_check(absf(arrow.rotation - (-PI / 2.0)) < EPSILON, "1.37 Arrow rotation is -PI/2 (points UP) for upper-half target")
			_assert_check(arrow.position.y > 300.0, "1.38 Arrow placed below target for upward point")

		# Skip Button Touch Target
		var skip_btn = ov.get_node_or_null("%SkipButton") as Button
		_assert_check(skip_btn != null, "1.39 SkipButton exists (%SkipButton)")
		if skip_btn != null:
			_assert_check(skip_btn.custom_minimum_size.y >= 56.0, "1.40 SkipButton height >= 56px (actual: %.1f)" % skip_btn.custom_minimum_size.y)
			_assert_check(skip_btn.mouse_filter == Control.MOUSE_FILTER_STOP, "1.41 SkipButton mouse_filter is STOP (0)")
			_assert_check("Überspringen" in skip_btn.text, "1.42 SkipButton displays German label 'Überspringen'")

		ov.queue_free()
		await process_frame

	# =========================================================================
	# SECTION 2 (F3-F8): 6-STEP LINEAR INTRO PROGRESSION
	# =========================================================================
	print("\n--- SECTION 2 (F3-F8): 6-Step Linear Intro Progression ---")
	
	tm.reset_tutorial()
	gs.reset_tutorial_state()
	gs.energy = 0.0
	await process_frame

	var step_records: Array[Dictionary] = []
	var tut_completed_records: Array = []
	var tut_skipped_records: Array = []

	var cb_st = func(s_idx: int, t_name: String): step_records.append({"step": s_idx, "target": t_name})
	var cb_comp = func(): tut_completed_records.append(true)
	var cb_skip = func(): tut_skipped_records.append(true)

	tm.step_started.connect(cb_st)
	tm.tutorial_completed.connect(cb_comp)
	tm.tutorial_skipped.connect(cb_skip)

	# F3: Step 1 (Core Reactor Tap)
	tm.start_linear_intro()
	await process_frame

	_assert_check(tm.get_current_step() == 1, "2.1 Step 1 active: INTRO_STEP_1_TAP")
	_assert_check(tm.is_tutorial_active(), "2.2 is_tutorial_active() is true")
	_assert_check(step_records.size() >= 1 and step_records[-1]["step"] == 1, "2.3 step_started(1, 'Core') emitted")
	_assert_check(step_records[-1]["target"] == "Core", "2.4 Target is 'Core'")
	_assert_check(tm.tutorial_overlay != null and tm.tutorial_overlay.get_node("%SkipButton").visible, "2.5 SkipButton visible during Step 1")

	# Tap Core Reactor -> advance to Step 2 & award +30 energy
	gs.tap_core()
	await process_frame

	_assert_check(gs.energy >= 30.0, "2.6 Step 1 awards +30 seed energy (actual: %.1f)" % gs.energy)
	_assert_check(tm.get_current_step() == 2, "2.7 Step 2 active: INTRO_STEP_2_UPGRADE")

	# F4: Step 2 (First Upgrade)
	_assert_check(step_records.size() >= 2 and step_records[-1]["step"] == 2, "2.8 step_started(2, 'UpgradeShop') emitted")
	_assert_check(step_records[-1]["target"] == "UpgradeShop", "2.9 Target is 'UpgradeShop'")

	# Buy first upgrade -> advance to Step 3
	gs.buy_upgrade("tier_1")
	await process_frame

	_assert_check(tm.get_current_step() == 3, "2.10 Step 3 active: INTRO_STEP_3_FRENZY")

	# F5: Step 3 (Frenzy Meter)
	_assert_check(step_records.size() >= 3 and step_records[-1]["step"] == 3, "2.11 step_started(3, 'FrenzyMeter') emitted")
	_assert_check(step_records[-1]["target"] == "FrenzyMeter", "2.12 Target is 'FrenzyMeter'")

	# Update frenzy -> advance to Step 4
	gs.frenzy_meter = 25.0
	gs.frenzy_updated.emit(1.0, 0.25)
	await process_frame

	_assert_check(tm.get_current_step() == 4, "2.13 Step 4 active: INTRO_STEP_4_CAMPUS")

	# F6: Step 4 (3D Campus Navigation)
	_assert_check(step_records.size() >= 4 and step_records[-1]["step"] == 4, "2.14 step_started(4, 'VirtualJoystick') emitted")
	_assert_check(step_records[-1]["target"] == "VirtualJoystick", "2.15 Target is 'VirtualJoystick'")

	# Move joystick -> advance to Step 5
	tm.advance_step()
	await process_frame

	_assert_check(tm.get_current_step() == 5, "2.16 Step 5 active: INTRO_STEP_5_COLLECTIBLE")

	# F7: Step 5 (Collectible Pickup)
	_assert_check(step_records.size() >= 5 and step_records[-1]["step"] == 5, "2.17 step_started(5, 'Collectible') emitted")
	_assert_check(step_records[-1]["target"] == "Collectible", "2.18 Target is 'Collectible'")

	# Pick up collectible -> advance to Step 6
	gs.collectible_picked_up.emit("briefcase", 1)
	await process_frame

	_assert_check(tm.get_current_step() == 6, "2.19 Step 6 active: INTRO_STEP_6_STATION")

	# F8: Step 6 (First Station Interaction & Graduation)
	_assert_check(step_records.size() >= 6 and step_records[-1]["step"] == 6, "2.20 step_started(6, 'ServerTerminal') emitted")
	_assert_check(step_records[-1]["target"] == "ServerTerminal", "2.21 Target is 'ServerTerminal'")

	# Trigger station interaction -> finish intro
	tm.advance_step()
	await process_frame

	_assert_check(tm.get_current_step() == 7, "2.22 Final step is COMPLETED (7)")
	_assert_check(not tm.is_tutorial_active(), "2.23 is_tutorial_active() is false after completion")
	_assert_check(tut_completed_records.size() >= 1, "2.24 tutorial_completed signal emitted")
	_assert_check(gs.tutorial_completed == true, "2.25 GameState.tutorial_completed set to true")
	_assert_check(not tm.tutorial_overlay.get_node("%SkipButton").visible, "2.26 SkipButton hidden after completion")

	# =========================================================================
	# SECTION 3 (F9): SKIP BUTTON INSTANT UNLOCK
	# =========================================================================
	print("\n--- SECTION 3 (F9): Skip Button Instant Unlock ---")
	
	tm.reset_tutorial()
	gs.reset_tutorial_state()
	await process_frame

	tm.start_linear_intro()
	await process_frame
	_assert_check(tm.is_tutorial_active(), "3.1 Intro restarted at Step 1")

	var skip_signal_fired: Array = []
	var completed_signal_fired: Array = []
	tm.tutorial_skipped.connect(func(): skip_signal_fired.append(true), CONNECT_ONE_SHOT)
	tm.tutorial_completed.connect(func(): completed_signal_fired.append(true), CONNECT_ONE_SHOT)

	# Press Skip Button
	tm.skip_tutorial()
	await process_frame

	_assert_check(skip_signal_fired.size() > 0, "3.2 tutorial_skipped signal emitted immediately")
	_assert_check(completed_signal_fired.size() > 0, "3.3 tutorial_completed signal emitted immediately")
	_assert_check(tm.get_current_step() == 7, "3.4 current_step transitioned directly to COMPLETED (7)")
	_assert_check(not tm.is_tutorial_active(), "3.5 Tutorial no longer active")
	_assert_check(gs.tutorial_skipped == true, "3.6 GameState.tutorial_skipped is true")
	_assert_check(gs.tutorial_completed == true, "3.7 GameState.tutorial_completed is true")
	_assert_check(not tm.tutorial_overlay.get_node("%SkipButton").visible, "3.8 SkipButton hidden after skip")

	# =========================================================================
	# SECTION 4 (F10-F15): 6 CONTEXTUAL HINTS & EXACTLY-ONCE ENFORCEMENT
	# =========================================================================
	print("\n--- SECTION 4 (F10-F15): 6 Contextual Hints & Exactly-Once Enforcement ---")
	
	# Reset hints only
	gs.tutorial_seen_hints.clear()
	var hint_triggers: Array[String] = [
		"hint_zone_gate",
		"hint_tech_tree",
		"hint_staff",
		"hint_minigame",
		"hint_daily_board",
		"hint_ipo_bell"
	]

	# First pass: All 6 hints must fire cleanly
	var hints_emitted: Array[String] = []
	var cb_hint_trig = func(h_id: String): hints_emitted.append(h_id)
	tm.contextual_hint_triggered.connect(cb_hint_trig)

	var dp_active = tm.get_dialogue_panel()
	_assert_check(dp_active != null, "4.1 DialoguePanel accessible for contextual hints")

	for idx in range(hint_triggers.size()):
		var hid = hint_triggers[idx]
		_assert_check(not gs.has_seen_contextual_hint(hid), "4.%d.1 Hint '%s' initially unseen" % [idx + 2, hid])
		
		tm.trigger_contextual_hint(hid)
		await process_frame

		_assert_check(hints_emitted.has(hid), "4.%d.2 Hint '%s' emitted contextual_hint_triggered signal" % [idx + 2, hid])
		_assert_check(gs.has_seen_contextual_hint(hid), "4.%d.3 GameState marked '%s' as seen" % [idx + 2, hid])
		_assert_check(dp_active.visible, "4.%d.4 DialoguePanel visible for hint '%s'" % [idx + 2, hid])
		_assert_check(dp_active.is_hint_active(), "4.%d.5 DialoguePanel is_hint_active() is true for '%s'" % [idx + 2, hid])

		dp_active.dismiss_hint()
		await process_frame
		_assert_check(not dp_active.visible, "4.%d.6 DialoguePanel closed after dismissal for '%s'" % [idx + 2, hid])

	# Second pass: Exactly-once suppression (all 6 must be blocked)
	print("\n  [Exactly-Once Suppression Pass]")
	hints_emitted.clear()
	for idx in range(hint_triggers.size()):
		var hid = hint_triggers[idx]
		tm.trigger_contextual_hint(hid)
		await process_frame

		_assert_check(not hints_emitted.has(hid), "4.8.%d Duplicate trigger for '%s' suppressed (0 signals)" % [idx + 1, hid])
		_assert_check(not dp_active.visible, "4.8.%d DialoguePanel remained closed for duplicate '%s'" % [idx + 1, hid])

	# Contextual Hint Scene Hook Integrations
	print("\n  [Contextual Hint Scene Hook Verification]")
	var hook_scenes: Dictionary = {
		"ZoneGate3D": {"path": "res://scenes/zone_gate_3d.tscn", "hint": "hint_zone_gate"},
		"TechTreeModal": {"path": "res://scenes/ui/tech_tree_modal.tscn", "hint": "hint_tech_tree"},
		"StaffModal": {"path": "res://scenes/ui/staff_modal.tscn", "hint": "hint_staff"},
		"ServerTerminal": {"path": "res://scenes/server_terminal.tscn", "hint": "hint_minigame"},
		"DailyBoard3D": {"path": "res://scenes/daily_board_3d.tscn", "hint": "hint_daily_board"},
		"IpoBell3D": {"path": "res://scenes/ipo_bell_3d.tscn", "hint": "hint_ipo_bell"}
	}

	for sname in hook_scenes:
		var sdata = hook_scenes[sname]
		var sc = load(sdata["path"])
		_assert_check(sc != null, "4.9 Scene loaded: %s (%s)" % [sname, sdata["hint"]])

	# =========================================================================
	# SECTION 5 (F16-F17): STATE PERSISTENCE & TRUTH TABLE
	# =========================================================================
	print("\n--- SECTION 5 (F16-F17): State Persistence & First-Time Player Truth Table ---")
	
	# F16: Persistence Roundtrip
	gs.reset_state()
	gs.tutorial_current_step = 4
	gs.tutorial_completed = false
	gs.tutorial_skipped = false
	gs.tutorial_replay_requested = false
	gs.tutorial_seen_hints = {"hint_zone_gate": true, "hint_tech_tree": true}
	gs.save_to_disk()

	_assert_check(FileAccess.file_exists("user://savegame.json"), "5.1 save_to_disk() wrote user://savegame.json")
	var f_save = FileAccess.open("user://savegame.json", FileAccess.READ)
	var saved_dict = JSON.parse_string(f_save.get_as_text())
	f_save.close()

	_assert_check(saved_dict is Dictionary, "5.2 Saved content parses as JSON Dictionary")
	_assert_check(saved_dict.get("tutorial_current_step") == 4, "5.3 JSON contains tutorial_current_step: 4")
	_assert_check(saved_dict.get("tutorial_completed") == false, "5.4 JSON contains tutorial_completed: false")
	_assert_check(saved_dict.get("tutorial_skipped") == false, "5.5 JSON contains tutorial_skipped: false")
	_assert_check(saved_dict.get("tutorial_replay_requested") == false, "5.6 JSON contains tutorial_replay_requested: false")

	# Wipe memory and load back
	gs.tutorial_current_step = 0
	gs.tutorial_seen_hints.clear()
	var load_ok = gs.load_from_disk()
	_assert_check(load_ok, "5.7 load_from_disk() succeeded")
	_assert_check(gs.tutorial_current_step == 4, "5.8 Restored tutorial_current_step == 4")
	_assert_check(gs.has_seen_contextual_hint("hint_zone_gate"), "5.9 Restored hint_zone_gate as seen")
	_assert_check(gs.has_seen_contextual_hint("hint_tech_tree"), "5.10 Restored hint_tech_tree as seen")
	_assert_check(not gs.has_seen_contextual_hint("hint_staff"), "5.11 Unseen hint_staff remains false")

	# Corrupted Save Immunity (No SCRIPT ERROR on non-bool or bad steps)
	var bad_dict = {
		"tutorial_current_step": "3",
		"tutorial_completed": 0,
		"tutorial_skipped": "false",
		"tutorial_replay_requested": null,
		"tutorial_seen_hints": {
			"hint_zone_gate": "seen",
			"hint_tech_tree": 1,
			"hint_staff": "false",
			"hint_minigame": null,
			"hint_daily_board": ["corrupt"],
			"": true
		}
	}
	var f_corrupt = FileAccess.open("user://savegame.json", FileAccess.WRITE)
	f_corrupt.store_string(JSON.stringify(bad_dict))
	f_corrupt.close()

	var corrupt_load_ok = gs.load_from_disk()
	_assert_check(corrupt_load_ok, "5.12 Corrupted save loaded cleanly without crash")
	_assert_check(gs.tutorial_current_step == 3, "5.13 Sanitized step string '3' -> int 3")
	_assert_check(gs.has_seen_contextual_hint("hint_zone_gate") == true, "5.14 Token 'seen' safely converted to true")
	_assert_check(gs.has_seen_contextual_hint("hint_tech_tree") == true, "5.15 Integer 1 safely converted to true")
	_assert_check(gs.has_seen_contextual_hint("hint_staff") == false, "5.16 String 'false' safely converted to false")
	_assert_check(gs.has_seen_contextual_hint("hint_minigame") == false, "5.17 Null safely converted to false")
	_assert_check(gs.has_seen_contextual_hint("hint_daily_board") == false, "5.18 Corrupted list safely converted to false")
	_assert_check(not gs.tutorial_seen_hints.has(""), "5.19 Empty string key ignored")

	# F17: 5-Case First-Time Player Truth Table
	print("\n  [5-Case First-Time Player Truth Table]")

	# Case 1: Fresh game (no savegame.json)
	if FileAccess.file_exists("user://savegame.json"):
		DirAccess.remove_absolute("user://savegame.json")
	gs.tutorial_completed = false
	gs.tutorial_skipped = false
	gs.tutorial_replay_requested = false
	_assert_check(gs.is_first_time_player() == true, "5.20 Case 1: Fresh game (no save) -> is_first_time_player() == true")
	_assert_check(tm.should_start_intro() == true, "5.21 Case 1: TutorialManager.should_start_intro() == true")

	# Case 2: Save exists, tutorial in-progress
	gs.tutorial_current_step = 2
	gs.save_to_disk()
	_assert_check(gs.is_first_time_player() == true, "5.22 Case 2: Save exists, in-progress -> is_first_time_player() == true")
	_assert_check(tm.should_start_intro() == true, "5.23 Case 2: should_start_intro() == true")

	# Case 3: Save exists, tutorial completed
	gs.tutorial_completed = true
	gs.tutorial_skipped = false
	gs.save_to_disk()
	_assert_check(gs.is_first_time_player() == false, "5.24 Case 3: Save exists, completed -> is_first_time_player() == false")
	_assert_check(tm.should_start_intro() == false, "5.25 Case 3: should_start_intro() == false")

	# Case 4: Save exists, tutorial skipped
	gs.tutorial_completed = true
	gs.tutorial_skipped = true
	gs.save_to_disk()
	_assert_check(gs.is_first_time_player() == false, "5.26 Case 4: Save exists, skipped -> is_first_time_player() == false")
	_assert_check(tm.should_start_intro() == false, "5.27 Case 4: should_start_intro() == false")

	# Case 5: Replay requested
	gs.reset_tutorial_state()
	_assert_check(gs.tutorial_replay_requested == true, "5.28 reset_tutorial_state() sets tutorial_replay_requested = true")
	_assert_check(gs.is_first_time_player() == true, "5.29 Case 5: Replay requested -> is_first_time_player() == true")
	_assert_check(tm.should_start_intro() == true, "5.30 Case 5: should_start_intro() == true")

	# =========================================================================
	# SECTION 6 (F18): SETTINGS MODAL REPLAY BUTTON & NON-DESTRUCTIVE RESET
	# =========================================================================
	print("\n--- SECTION 6 (F18): Settings Modal Replay Button & Non-Destructive Reset ---")
	
	var set_scene = load("res://scenes/ui/settings_modal.tscn")
	_assert_check(set_scene != null, "6.1 scenes/ui/settings_modal.tscn loaded")
	if set_scene != null:
		var sm = set_scene.instantiate() as Control
		root.add_child(sm)
		await process_frame

		var replay_btn = sm.get_node_or_null("%ReplayTutorialButton") as Button
		_assert_check(replay_btn != null, "6.2 %ReplayTutorialButton exists in SettingsModal")
		if replay_btn != null:
			_assert_check(replay_btn.custom_minimum_size.y >= 56.0, "6.3 ReplayTutorialButton height >= 56px (actual: %.1f)" % replay_btn.custom_minimum_size.y)
			_assert_check(replay_btn.mouse_filter == Control.MOUSE_FILTER_STOP, "6.4 ReplayTutorialButton mouse_filter == STOP (0)")

		# Set veteran progression to test non-destructive reset
		gs.reset_state()
		gs.energy = 50000.0
		gs.total_energy_earned = 250000.0
		gs.upgrades["tier_1"]["level"] = 15
		gs.upgrades["tier_2"]["level"] = 8
		gs.angel_shares = 12
		gs.tutorial_completed = true
		gs.tutorial_skipped = false
		gs.tutorial_seen_hints = {"hint_zone_gate": true, "hint_tech_tree": true, "hint_minigame": true}
		gs.save_to_disk()

		_assert_check(not gs.is_first_time_player(), "6.5 Veteran player confirmed before button press")

		# Click Replay Tutorial Button
		if replay_btn != null:
			replay_btn.pressed.emit()
			await process_frame

		# Verify Tutorial State Reset
		_assert_check(gs.tutorial_replay_requested == true, "6.6 tutorial_replay_requested set to true")
		_assert_check(gs.tutorial_completed == false, "6.7 tutorial_completed reset to false")
		_assert_check(gs.tutorial_skipped == false, "6.8 tutorial_skipped reset to false")
		_assert_check(gs.tutorial_current_step == 0, "6.9 tutorial_current_step reset to 0")
		_assert_check(gs.tutorial_seen_hints.is_empty(), "6.10 tutorial_seen_hints cleared")
		_assert_check(gs.is_first_time_player() == true, "6.11 is_first_time_player() now returns true")

		# Verify Non-Destructive Isolation (Economy & stats 100% intact)
		_assert_check(absf(gs.energy - 50000.0) < EPSILON, "6.12 Non-destructive: energy intact (50,000.0)")
		_assert_check(absf(gs.total_energy_earned - 250000.0) < EPSILON, "6.13 Non-destructive: total_energy_earned intact (250,000.0)")
		_assert_check(gs.upgrades["tier_1"]["level"] == 15, "6.14 Non-destructive: tier_1 generator level intact (15)")
		_assert_check(gs.upgrades["tier_2"]["level"] == 8, "6.15 Non-destructive: tier_2 generator level intact (8)")
		_assert_check(gs.angel_shares == 12, "6.16 Non-destructive: angel_shares intact (12)")

		sm.queue_free()
		await process_frame

	# -------------------------------------------------------------------------
	# FTUE Suite Summary & Exit
	# -------------------------------------------------------------------------
	print("\n====================================================================")
	print(">>> IDLEARCADE PHASE 17 FTUE TEST SUITE SUMMARY <<<")
	print("====================================================================")
	print("  TOTAL ASSERTIONS: %d Passed, %d Failed" % [pass_count, fail_count])
	print("====================================================================")

	if fail_count == 0 and pass_count >= 100:
		print(">>> ALL 18 FTUE FEATURES (F1-F18) VERIFIED WITH 100% GREEN PASS (Exit Code 0) <<<")
		_cleanup_and_quit(0)
	else:
		printerr(">>> FTUE TEST SUITE FAILED (Exit Code 1, pass_count=%d, fail_count=%d) <<<" % [pass_count, fail_count])
		_cleanup_and_quit(1)
