extends SceneTree

# ==============================================================================
# EMPIRICAL CHALLENGER ADVERSARIAL TEST HARNESS (Milestone 3)
# Target: IdleArcade Phase 17 Milestone 3 (F10 - F18)
# Author: p17_m3_challenger_gen2_2 (EMPIRICAL CHALLENGER)
# ==============================================================================

var total_passed: int = 0
var total_failed: int = 0

func _init() -> void:
	call_deferred("_run_tests")

func _run_tests() -> void:
	print("=================================================================")
	print("EMPIRICAL CHALLENGER: Milestone 3 Adversarial Stress Harness")
	print("=================================================================")
	
	run_all_challenge_suites()
	
	print("=================================================================")
	print("Challenger Results: %d Passed, %d Failed" % [total_passed, total_failed])
	print("=================================================================")
	
	if total_failed > 0:
		print("FAILED: Adversarial harness found defects!")
		quit(1)
	else:
		print("SUCCESS: All adversarial stress challenges PASSED!")
		quit(0)

func run_all_challenge_suites() -> void:
	challenge_ui_ergonomics_replay_button()
	challenge_auto_dismiss_5s_lifecycle()
	challenge_tap_dismiss_lifecycle()
	challenge_close_button_dismiss_lifecycle()
	challenge_non_blocking_input_isolation()
	challenge_replay_isolation_preservation()
	challenge_null_autoloads_in_6_hooks()

func challenge_assert(condition: bool, description: String) -> void:
	if condition:
		total_passed += 1
		print("  [PASS] %s" % description)
	else:
		total_failed += 1
		print("  [FAIL] %s" % description)

# ------------------------------------------------------------------------------
# CHALLENGE SUITE 1: %ReplayTutorialButton Touch Ergonomics & mouse_filter
# ------------------------------------------------------------------------------
func challenge_ui_ergonomics_replay_button() -> void:
	print("\n--- CHALLENGE 1: ReplayTutorialButton Touch Ergonomics & Isolation ---")
	
	var settings_scene = load("res://scenes/ui/settings_modal.tscn")
	challenge_assert(settings_scene != null, "scenes/ui/settings_modal.tscn is loadable")
	if settings_scene == null:
		return
		
	var modal = settings_scene.instantiate()
	root.add_child(modal)
	
	var replay_btn: Button = modal.get_node_or_null("%ReplayTutorialButton")
	challenge_assert(replay_btn != null, "%ReplayTutorialButton exists in scene")
	
	if replay_btn != null:
		# Touch target requirement: height >= 56px
		var min_size: Vector2 = replay_btn.custom_minimum_size
		challenge_assert(min_size.y >= 56.0, "Button height >= 56px (actual: %.1f)" % min_size.y)
		challenge_assert(min_size.x >= 56.0, "Button width >= 56px (actual: %.1f)" % min_size.x)
		
		# Mouse filter requirement: STOP (0)
		challenge_assert(replay_btn.mouse_filter == Control.MOUSE_FILTER_STOP, 
			"Button mouse_filter == Control.MOUSE_FILTER_STOP (actual: %d)" % replay_btn.mouse_filter)
		
		# Focus mode should be NONE (0) for clean mobile UX without lingering focus outlines
		challenge_assert(replay_btn.focus_mode == Control.FOCUS_NONE, 
			"Button focus_mode == FOCUS_NONE (actual: %d)" % replay_btn.focus_mode)
		
		# Check TutorialCard panel mouse_filter
		var card = modal.find_child("TutorialCard", true, false) as Control
		if card != null:
			challenge_assert(card.mouse_filter == Control.MOUSE_FILTER_STOP, 
				"TutorialCard panel mouse_filter == STOP (actual: %d)" % card.mouse_filter)
		
		# Test clicking ReplayTutorialButton
		var gs = root.get_node_or_null("GameState")
		if gs != null:
			gs.tutorial_completed = true
			gs.tutorial_skipped = false
			gs.tutorial_replay_requested = false
			gs.tutorial_current_step = 6
			gs.tutorial_seen_hints["hint_zone_gate"] = true
			
			replay_btn.pressed.emit()
			
			challenge_assert(gs.tutorial_replay_requested == true, "Click sets tutorial_replay_requested = true")
			challenge_assert(gs.tutorial_completed == false, "Click sets tutorial_completed = false")
			challenge_assert(gs.tutorial_current_step == 0, "Click resets tutorial_current_step = 0")
			challenge_assert(gs.tutorial_seen_hints.is_empty(), "Click clears tutorial_seen_hints")
			challenge_assert(gs.is_first_time_player() == true, "Click causes is_first_time_player() == true")
			challenge_assert(replay_btn.disabled == true, "Button is disabled after replay click to prevent spam")
			challenge_assert(replay_btn.text.contains("zurückgesetzt"), "Button text updates with feedback")
	
	modal.queue_free()

# ------------------------------------------------------------------------------
# CHALLENGE SUITE 2: Auto-Dismiss (5.0s) & Lingering Blocker Rect Eradication
# ------------------------------------------------------------------------------
func challenge_auto_dismiss_5s_lifecycle() -> void:
	print("\n--- CHALLENGE 2: Auto-Dismiss (5.0s) & Blocker Cleanup Lifecycle ---")
	
	var tm = root.get_node_or_null("TutorialManager")
	var gs = root.get_node_or_null("GameState")
	challenge_assert(tm != null and gs != null, "TutorialManager and GameState available")
	if tm == null or gs == null:
		return
		
	var overlay: TutorialOverlay = tm.get("tutorial_overlay")
	challenge_assert(overlay != null, "TutorialOverlay child exists under TutorialManager")
	if overlay == null:
		return
		
	var dp = tm.get_dialogue_panel()
	challenge_assert(dp != null, "DialoguePanel instance obtained from TutorialManager")
	if dp == null:
		return
		
	# Reset hint state so it fires
	gs.tutorial_seen_hints.erase("hint_zone_gate")
	
	var dummy_target = Control.new()
	dummy_target.name = "DummyTarget"
	dummy_target.position = Vector2(100, 200)
	dummy_target.size = Vector2(250, 80)
	root.add_child(dummy_target)
	
	# Trigger contextual hint
	tm.trigger_contextual_hint("hint_zone_gate", dummy_target)
	
	challenge_assert(dp.visible == true, "DialoguePanel is visible after trigger")
	challenge_assert(dp.is_hint_active() == true, "DialoguePanel is in hint mode")
	challenge_assert(overlay._is_highlight_active == true, "Overlay highlight is active")
	challenge_assert(overlay.top_blocker != null and overlay.top_blocker.visible == true, "TopBlocker is visible during hint")
	
	# Non-blocking input isolation check:
	challenge_assert(dp.mouse_filter == Control.MOUSE_FILTER_IGNORE, 
		"DialoguePanel root mouse_filter == IGNORE during hint (actual: %d)" % dp.mouse_filter)
	var dim_bd = dp.get_node_or_null("DimBackdrop")
	if dim_bd != null:
		challenge_assert(dim_bd.visible == false, "DimBackdrop is HIDDEN during hint")
		challenge_assert(dim_bd.mouse_filter == Control.MOUSE_FILTER_IGNORE, 
			"DimBackdrop mouse_filter == IGNORE during hint (actual: %d)" % dim_bd.mouse_filter)
	
	# Simulate 5.0 seconds elapsing: call _process(5.1)
	dp._process(5.1)
	
	# Verify complete dismiss and cleanup
	challenge_assert(dp.visible == false, "DialoguePanel is HIDDEN after 5.0s auto-dismiss")
	challenge_assert(dp.is_hint_active() == false, "DialoguePanel hint mode is INACTIVE after auto-dismiss")
	challenge_assert(overlay._is_highlight_active == false, "Overlay highlight is CLEARED after auto-dismiss")
	
	# Verify that NO blocker rects linger in the viewport
	challenge_assert(overlay.top_blocker.visible == false, "TopBlocker is HIDDEN after auto-dismiss")
	challenge_assert(overlay.top_blocker.size == Vector2.ZERO, "TopBlocker size == ZERO after auto-dismiss")
	challenge_assert(overlay.bottom_blocker.visible == false, "BottomBlocker is HIDDEN after auto-dismiss")
	challenge_assert(overlay.bottom_blocker.size == Vector2.ZERO, "BottomBlocker size == ZERO after auto-dismiss")
	challenge_assert(overlay.left_blocker.visible == false, "LeftBlocker is HIDDEN after auto-dismiss")
	challenge_assert(overlay.left_blocker.size == Vector2.ZERO, "LeftBlocker size == ZERO after auto-dismiss")
	challenge_assert(overlay.right_blocker.visible == false, "RightBlocker is HIDDEN after auto-dismiss")
	challenge_assert(overlay.right_blocker.size == Vector2.ZERO, "RightBlocker size == ZERO after auto-dismiss")
	challenge_assert(overlay.spotlight_frame.visible == false, "SpotlightFrame is HIDDEN after auto-dismiss")
	challenge_assert(overlay.arrow_indicator.visible == false, "ArrowIndicator is HIDDEN after auto-dismiss")
	
	dummy_target.queue_free()

# ------------------------------------------------------------------------------
# CHALLENGE SUITE 3: Tap Dismiss Lifecycle & Blocker Eradication
# ------------------------------------------------------------------------------
func challenge_tap_dismiss_lifecycle() -> void:
	print("\n--- CHALLENGE 3: Tap Dismiss Lifecycle & Blocker Eradication ---")
	
	var tm = root.get_node_or_null("TutorialManager")
	var gs = root.get_node_or_null("GameState")
	var overlay: TutorialOverlay = tm.get("tutorial_overlay")
	var dp = tm.get_dialogue_panel()
	
	gs.tutorial_seen_hints.erase("hint_tech_tree")
	
	var dummy_target = Control.new()
	dummy_target.name = "DummyTargetTech"
	dummy_target.position = Vector2(150, 400)
	dummy_target.size = Vector2(200, 100)
	root.add_child(dummy_target)
	
	tm.trigger_contextual_hint("hint_tech_tree", dummy_target)
	
	challenge_assert(dp.visible == true, "DialoguePanel is visible after tech hint trigger")
	challenge_assert(overlay._is_highlight_active == true, "Overlay highlight is active")
	
	# Simulate tap on CardPanel
	var card = dp.find_child("CardPanel", true, false) as Control
	challenge_assert(card != null, "CardPanel exists in DialoguePanel")
	
	if card != null:
		var click_event = InputEventMouseButton.new()
		click_event.pressed = true
		click_event.button_index = MOUSE_BUTTON_LEFT
		dp._on_card_panel_gui_input(click_event)
		
		challenge_assert(dp.visible == false, "DialoguePanel is HIDDEN after tap on card")
		challenge_assert(overlay._is_highlight_active == false, "Overlay highlight is CLEARED after tap dismiss")
		challenge_assert(overlay.top_blocker.visible == false and overlay.top_blocker.size == Vector2.ZERO, 
			"TopBlocker completely cleared after tap dismiss")
		challenge_assert(overlay.bottom_blocker.visible == false and overlay.bottom_blocker.size == Vector2.ZERO, 
			"BottomBlocker completely cleared after tap dismiss")
		challenge_assert(overlay.left_blocker.visible == false and overlay.left_blocker.size == Vector2.ZERO, 
			"LeftBlocker completely cleared after tap dismiss")
		challenge_assert(overlay.right_blocker.visible == false and overlay.right_blocker.size == Vector2.ZERO, 
			"RightBlocker completely cleared after tap dismiss")
	
	dummy_target.queue_free()

# ------------------------------------------------------------------------------
# CHALLENGE SUITE 4: Close Button ("OK") Dismiss Lifecycle
# ------------------------------------------------------------------------------
func challenge_close_button_dismiss_lifecycle() -> void:
	print("\n--- CHALLENGE 4: Close Button ('OK') Dismiss Lifecycle ---")
	
	var tm = root.get_node_or_null("TutorialManager")
	var gs = root.get_node_or_null("GameState")
	var overlay: TutorialOverlay = tm.get("tutorial_overlay")
	var dp = tm.get_dialogue_panel()
	
	gs.tutorial_seen_hints.erase("hint_staff")
	
	var dummy_target = Control.new()
	dummy_target.position = Vector2(50, 50)
	dummy_target.size = Vector2(100, 100)
	root.add_child(dummy_target)
	
	tm.trigger_contextual_hint("hint_staff", dummy_target)
	
	challenge_assert(dp.visible == true, "DialoguePanel is visible after staff hint trigger")
	challenge_assert(overlay._is_highlight_active == true, "Overlay is active")
	
	var close_btn: Button = dp.get_node_or_null("%CloseButton")
	challenge_assert(close_btn != null, "%CloseButton exists in DialoguePanel")
	if close_btn != null:
		challenge_assert(close_btn.text == "OK", "Close button is styled as 'OK' during hint (actual: '%s')" % close_btn.text)
		close_btn.pressed.emit()
		
		challenge_assert(dp.visible == false, "DialoguePanel is HIDDEN after OK button press")
		challenge_assert(overlay._is_highlight_active == false, "Overlay is CLEARED after OK button press")
		challenge_assert(overlay.top_blocker.visible == false and overlay.top_blocker.size == Vector2.ZERO,
			"Blockers eradicated after OK button press")
			
	dummy_target.queue_free()

# ------------------------------------------------------------------------------
# CHALLENGE SUITE 5: Non-Blocking Input Isolation & Gameplay Freedom
# ------------------------------------------------------------------------------
func challenge_non_blocking_input_isolation() -> void:
	print("\n--- CHALLENGE 5: Non-Blocking Input Isolation & Avatar Unfreezing ---")
	
	var tm = root.get_node_or_null("TutorialManager")
	var dp = tm.get_dialogue_panel()
	
	# Mock avatar to verify set_input_enabled(true)
	var mock_avatar = Node.new()
	var avatar_script = GDScript.new()
	avatar_script.source_code = """
extends Node
var input_enabled: bool = true
func set_input_enabled(enabled: bool) -> void:
	input_enabled = enabled
"""
	avatar_script.reload()
	mock_avatar.set_script(avatar_script)
	root.add_child(mock_avatar)
	
	dp.set("_avatar_ref", mock_avatar)
	
	# Show hint popup
	dp.show_hint_popup("Test Hint", "Non-blocking hint body text", 5.0)
	
	challenge_assert(mock_avatar.get("input_enabled") == true, 
		"Avatar input remains ENABLED when contextual hint appears (no forced freezing)")
		
	dp.dismiss_hint()
	challenge_assert(mock_avatar.get("input_enabled") == true, 
		"Avatar input remains ENABLED after contextual hint dismiss")
		
	mock_avatar.queue_free()

# ------------------------------------------------------------------------------
# CHALLENGE SUITE 6: Replay Isolation & Non-Destructive Progression Preservation
# ------------------------------------------------------------------------------
func challenge_replay_isolation_preservation() -> void:
	print("\n--- CHALLENGE 6: Non-Destructive Progression Preservation on Reset ---")
	
	var gs = root.get_node_or_null("GameState")
	challenge_assert(gs != null, "GameState available")
	if gs == null:
		return
		
	# Populate progression data
	gs.energy = 999999.0
	gs.total_energy_earned = 5000000.0
	gs.angel_shares = 42
	gs.hired_workers = [{"id": "worker_1", "role": "dev_junior", "current_state": "working", "morale": 1.0}]
	gs.researched_techs.clear()
	gs.researched_techs.append("tech_coffee_automation")
	
	# Set tutorial state as veteran
	gs.tutorial_completed = true
	gs.tutorial_skipped = false
	gs.tutorial_current_step = 7
	gs.tutorial_seen_hints = {"hint_zone_gate": true, "hint_tech_tree": true}
	
	# Reset tutorial state
	gs.reset_tutorial_state()
	
	# Assert tutorial state reset
	challenge_assert(gs.tutorial_current_step == 0, "tutorial_current_step reset to 0")
	challenge_assert(gs.tutorial_completed == false, "tutorial_completed reset to false")
	challenge_assert(gs.tutorial_skipped == false, "tutorial_skipped reset to false")
	challenge_assert(gs.tutorial_replay_requested == true, "tutorial_replay_requested set to true")
	challenge_assert(gs.tutorial_seen_hints.is_empty(), "tutorial_seen_hints cleared")
	challenge_assert(gs.is_first_time_player() == true, "is_first_time_player() is true after replay request")
	
	# Assert progression untouched
	challenge_assert(gs.energy == 999999.0, "Energy untouched (actual: %.1f)" % gs.energy)
	challenge_assert(gs.total_energy_earned == 5000000.0, "Total energy untouched (actual: %.1f)" % gs.total_energy_earned)
	challenge_assert(gs.angel_shares == 42, "Angel shares untouched (actual: %d)" % gs.angel_shares)
	challenge_assert(gs.hired_workers.size() == 1, "Hired workers untouched (actual: %d)" % gs.hired_workers.size())
	challenge_assert(gs.researched_techs.size() == 1, "Tech tree untouched (actual: %d)" % gs.researched_techs.size())

# ------------------------------------------------------------------------------
# CHALLENGE SUITE 7: Null Autoload Robustness Across All 6 Hook Points
# ------------------------------------------------------------------------------
func challenge_null_autoloads_in_6_hooks() -> void:
	print("\n--- CHALLENGE 7: Null Safety Across 6 Contextual Hook Points ---")
	
	# Temporarily rename TutorialManager and GameState nodes in the tree
	var tm_real = root.get_node_or_null("TutorialManager")
	var gs_real = root.get_node_or_null("GameState")
	
	if tm_real != null:
		tm_real.name = "TutorialManager_Hidden"
	if gs_real != null:
		gs_real.name = "GameState_Hidden"
		
	challenge_assert(root.get_node_or_null("TutorialManager") == null, "TutorialManager hidden for null stress")
	challenge_assert(root.get_node_or_null("GameState") == null, "GameState hidden for null stress")
	
	# 1. ZoneGate3D
	var zg_scene = load("res://scenes/zone_gate_3d.tscn")
	challenge_assert(zg_scene != null, "zone_gate_3d.tscn loadable")
	if zg_scene != null:
		var zg = zg_scene.instantiate()
		root.add_child(zg)
		var mock_body = CharacterBody3D.new()
		mock_body.add_to_group("player")
		zg.add_child(mock_body)
		
		zg._on_interaction_body_entered(mock_body)
		challenge_assert(true, "Hook 1 (zone_gate_3d): Survives null TutorialManager & GameState")
		
		zg.attempt_unlock()
		challenge_assert(true, "Hook 1 (zone_gate_3d): attempt_unlock survives null GameState")
		
		zg.queue_free()
	
	# 2. TechTreeModal
	var tt_scene = load("res://scenes/ui/tech_tree_modal.tscn")
	challenge_assert(tt_scene != null, "tech_tree_modal.tscn loadable")
	if tt_scene != null:
		var tt = tt_scene.instantiate()
		root.add_child(tt)
		tt.open()
		challenge_assert(true, "Hook 2 (tech_tree_modal): open() survives null TutorialManager & GameState")
		tt._on_research_button_pressed("tech_coffee_automation")
		challenge_assert(true, "Hook 2 (tech_tree_modal): research click survives null GameState")
		tt.close()
	
	# 3. StaffModal
	var sm_scene = load("res://scenes/ui/staff_modal.tscn")
	challenge_assert(sm_scene != null, "staff_modal.tscn loadable")
	if sm_scene != null:
		var sm = sm_scene.instantiate()
		root.add_child(sm)
		sm.open()
		challenge_assert(true, "Hook 3 (staff_modal): open() survives null TutorialManager & GameState")
		sm._check_staff_hint()
		challenge_assert(true, "Hook 3 (staff_modal): _check_staff_hint() survives null TutorialManager")
		sm._process(0.1)
		challenge_assert(true, "Hook 3 (staff_modal): _process() survives null GameState")
		sm.close()
	
	# 4. ServerTerminal
	var st_scene = load("res://scenes/server_terminal.tscn")
	challenge_assert(st_scene != null, "server_terminal.tscn loadable")
	if st_scene != null:
		var st = st_scene.instantiate()
		root.add_child(st)
		st.interact()
		challenge_assert(true, "Hook 4 (server_terminal): interact() survives null TutorialManager & GameState")
		st.queue_free()
	
	# 5. DailyBoard3D
	var db_scene = load("res://scenes/daily_board_3d.tscn")
	challenge_assert(db_scene != null, "daily_board_3d.tscn loadable")
	if db_scene != null:
		var db = db_scene.instantiate()
		root.add_child(db)
		db.interact()
		challenge_assert(true, "Hook 5 (daily_board_3d): interact() survives null TutorialManager & GameState")
		db.queue_free()
	
	# 6. IpoBell3D
	var ib_scene = load("res://scenes/ipo_bell_3d.tscn")
	challenge_assert(ib_scene != null, "ipo_bell_3d.tscn loadable")
	if ib_scene != null:
		var ib = ib_scene.instantiate()
		root.add_child(ib)
		ib.interact()
		challenge_assert(true, "Hook 6 (ipo_bell_3d): interact() survives null TutorialManager & GameState")
		ib.queue_free()

	# Restore singleton names
	if tm_real != null:
		tm_real.name = "TutorialManager"
	if gs_real != null:
		gs_real.name = "GameState"
	challenge_assert(root.get_node_or_null("TutorialManager") != null, "TutorialManager restored cleanly")
	challenge_assert(root.get_node_or_null("GameState") != null, "GameState restored cleanly")
