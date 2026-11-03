extends SceneTree

## Adversarial Stress & Verification Test Suite for DialoguePanel
## Phase 17 Milestone 1 - Challenger 2 Mission
## Stress-tests lifecycle, boundary durations, modal transitions, and input gating integrity.
## Execution: godot --headless --path IdleArcade -s tests/test_p17_m1_adversarial_dialogue.gd

var pass_count: int = 0
var fail_count: int = 0

const DialoguePanelScene = preload("res://scenes/dialogue_panel.tscn")

class MockAvatar extends Node:
	var input_enabled: bool = true
	var set_input_calls: int = 0
	
	func set_input_enabled(enabled: bool) -> void:
		input_enabled = enabled
		set_input_calls += 1

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

func _run_adversarial_tests() -> void:
	print("======================================================================")
	print("CHALLENGER 2 ADVERSARIAL STRESS TEST: DIALOGUE PANEL RUNTIME INTEGRITY")
	print("======================================================================")

	var root_node = root
	var dial = DialoguePanelScene.instantiate()
	root_node.add_child(dial)
	
	_assert(dial != null, "DialoguePanel instantiated and added to tree")
	
	# =========================================================================
	# SUITE 1: Rapid Lifecycle Stress & Signal Duplication Defense
	# =========================================================================
	print("\n--- SUITE 1: Rapid Lifecycle Stress & Signal Duplication Defense ---")
	
	# 1.1: Call open_for_tutorial_step 50 times rapidly in sequence without closing
	var child_count_initial = dial.get_child_count()
	for i in range(50):
		dial.open_for_tutorial_step(
			"Angel Investor",
			"Tutorial Step %d" % i,
			"Rapid sequence execution step %d" % i,
			Color(1.0, 0.8, 0.2)
		)
	
	_assert(dial.get_child_count() == child_count_initial,
		"Child node count remains strictly constant after 50 rapid open_for_tutorial_step calls (no node leak)")
	_assert(dial.title_label.text == "Tutorial Step 49",
		"Final rapid title updated correctly to 'Tutorial Step 49'")
	_assert(dial.is_tutorial_active() == true,
		"is_tutorial_active() is true after 50 rapid calls")
	
	# Verify signal emission on close is NOT duplicated by 50 prior opens
	var adv_emits: Array = []
	var closed_emits: Array = []
	var adv_callable = func(): adv_emits.append(true)
	var closed_callable = func(): closed_emits.append(true)
	
	dial.tutorial_advanced.connect(adv_callable)
	dial.closed.connect(closed_callable)
	
	dial.close_dialogue()
	
	_assert(adv_emits.size() == 1,
		"tutorial_advanced emitted EXACTLY ONCE after 50 rapid opens (actual: %d)" % adv_emits.size())
	_assert(closed_emits.size() == 1,
		"closed signal emitted EXACTLY ONCE after 50 rapid opens (actual: %d)" % closed_emits.size())
	_assert(dial.visible == false,
		"DialoguePanel is hidden after close_dialogue()")
	_assert(dial.is_tutorial_active() == false,
		"is_tutorial_active() is false after close")
		
	# Disconnect listeners
	dial.tutorial_advanced.disconnect(adv_callable)
	dial.closed.disconnect(closed_callable)
	
	# 1.2: 50 full alternating open/advance cycles
	var cycle_adv_emits: Array = []
	var cycle_closed_emits: Array = []
	var cycle_adv_cb = func(): cycle_adv_emits.append(true)
	var cycle_closed_cb = func(): cycle_closed_emits.append(true)
	dial.tutorial_advanced.connect(cycle_adv_cb)
	dial.closed.connect(cycle_closed_cb)
	
	for i in range(50):
		dial.open_for_tutorial_step("Angel Investor", "Step %d" % i, "Text %d" % i)
		dial.close_dialogue()
		
	_assert(cycle_adv_emits.size() == 50,
		"50 open/close cycles emitted tutorial_advanced EXACTLY 50 times (actual: %d)" % cycle_adv_emits.size())
	_assert(cycle_closed_emits.size() == 50,
		"50 open/close cycles emitted closed EXACTLY 50 times (actual: %d)" % cycle_closed_emits.size())
	_assert(dial.get_child_count() == child_count_initial,
		"Node hierarchy completely intact after 50 alternating open/close cycles")
		
	dial.tutorial_advanced.disconnect(cycle_adv_cb)
	dial.closed.disconnect(cycle_closed_cb)
	
	# 1.3: Re-entrant advance calls when already closed do not fire spurious signals
	var spurious_emits: Array = []
	var spurious_cb = func(): spurious_emits.append(true)
	dial.tutorial_advanced.connect(spurious_cb)
	dial.advance_tutorial_step()
	dial.advance_tutorial_step()
	dial.close_dialogue()
	_assert(spurious_emits.size() == 0,
		"Spurious advance_tutorial_step() calls on closed panel emit 0 signals")
	dial.tutorial_advanced.disconnect(spurious_cb)

	# =========================================================================
	# SUITE 2: Boundary Durations & Countdown Auto-Dismissal
	# =========================================================================
	print("\n--- SUITE 2: Boundary Durations & Countdown Auto-Dismissal ---")
	
	var hint_dismissed_records: Array = []
	var hint_cb = func(h_id: String): hint_dismissed_records.append(h_id)
	dial.hint_dismissed.connect(hint_cb)
	
	# 2.1: duration = 0.001 (Micro-duration auto-dismiss)
	dial.show_hint_popup("Micro Hint", "Should dismiss almost instantly", 0.001, Rect2(), "hint_micro")
	_assert(dial.is_hint_active() == true, "Micro hint is active immediately on show")
	_assert(dial.visible == true, "DialoguePanel is visible for micro hint")
	dial._process(0.016) # Step 1 typical 60fps frame
	_assert(dial.is_hint_active() == false, "Micro hint auto-dismissed on next frame step")
	_assert(dial.visible == false, "DialoguePanel hidden after micro hint auto-dismiss")
	_assert(hint_dismissed_records.size() == 1 and hint_dismissed_records[-1] == "hint_micro",
		"hint_dismissed emitted with 'hint_micro'")
		
	# 2.2: duration = 1000.0 (Long duration countdown)
	dial.show_hint_popup("Long Hint", "Should stay open until 1000s elapsed", 1000.0, Rect2(), "hint_long")
	_assert(dial.is_hint_active() == true, "Long hint active on show")
	dial._process(500.0) # Step halfway
	_assert(dial.is_hint_active() == true, "Long hint remains active at 500s elapsed")
	_assert(hint_dismissed_records.size() == 1, "No premature hint dismissal at 500s")
	dial._process(501.0) # Step past remaining 500s
	_assert(dial.is_hint_active() == false, "Long hint auto-dismisses at 1001s total elapsed")
	_assert(dial.visible == false, "DialoguePanel hidden after long hint auto-dismiss")
	_assert(hint_dismissed_records.size() == 2 and hint_dismissed_records[-1] == "hint_long",
		"hint_dismissed emitted with 'hint_long'")

	# 2.3: duration = 0.0 (Zero-duration boundary case)
	dial.show_hint_popup("Zero Hint", "Zero duration boundary", 0.0, Rect2(), "hint_zero")
	_assert(dial.is_hint_active() == true, "Zero duration hint displayed without crash")
	# Process frame - verify graceful behavior (no division by zero, no error)
	dial._process(1.0)
	_assert(dial.visible == true, "Zero duration hint persists gracefully until dismissed")
	# Dismiss via dismiss_hint()
	dial.dismiss_hint()
	_assert(dial.is_hint_active() == false, "Zero duration hint dismissed cleanly via dismiss_hint()")
	_assert(hint_dismissed_records.size() == 3 and hint_dismissed_records[-1] == "hint_zero",
		"hint_dismissed emitted with 'hint_zero'")

	# 2.4: duration = -5.0 (Negative duration edge case)
	dial.show_hint_popup("Neg Hint", "Negative duration corner case", -5.0, Rect2(), "hint_neg")
	_assert(dial.is_hint_active() == true, "Negative duration hint initialized without crash")
	dial._process(2.0)
	_assert(dial.visible == true, "Negative duration hint handles process stepping gracefully without crash")
	# Dismiss via close_dialogue()
	dial.close_dialogue()
	_assert(dial.is_hint_active() == false, "Negative duration hint dismissed cleanly via close_dialogue()")
	_assert(hint_dismissed_records.size() == 4 and hint_dismissed_records[-1] == "hint_neg",
		"hint_dismissed emitted with 'hint_neg'")

	# 2.5: Tap-to-dismiss via simulated gui_input while countdown is ticking
	dial.show_hint_popup("Ticking Hint", "Ticking countdown test", 10.0, Rect2(), "hint_tick")
	_assert(dial.is_hint_active() == true, "Ticking hint active")
	dial._process(3.0) # 7.0s remaining
	_assert(dial.is_hint_active() == true, "Ticking hint still active at 3s elapsed")
	
	# Simulate left mouse click on CardPanel
	var click_ev = InputEventMouseButton.new()
	click_ev.pressed = true
	click_ev.button_index = MOUSE_BUTTON_LEFT
	dial._on_card_panel_gui_input(click_ev)
	
	_assert(dial.is_hint_active() == false, "Ticking hint immediately dismissed on tap")
	_assert(dial.visible == false, "DialoguePanel hidden after tap-to-dismiss")
	_assert(hint_dismissed_records.size() == 5 and hint_dismissed_records[-1] == "hint_tick",
		"hint_dismissed emitted with 'hint_tick'")
		
	# Process further - verify timer does NOT fire a second dismissal
	dial._process(15.0)
	_assert(hint_dismissed_records.size() == 5,
		"No duplicate hint_dismissed emission after timer expires post-tap")
		
	dial.hint_dismissed.disconnect(hint_cb)

	# =========================================================================
	# SUITE 3: Modal Transition Invariants & Input Gating Integrity
	# =========================================================================
	print("\n--- SUITE 3: Modal Transition Invariants & Input Gating Integrity ---")
	
	var mock_avatar = MockAvatar.new()
	root_node.add_child(mock_avatar)
	mock_avatar.input_enabled = true
	
	# Transition: show_hint_popup -> open_for_npc -> close_dialogue
	# Step 1: Open Hint Popup
	dial.show_hint_popup("Hint Mode", "Avatar should be free", 5.0, Rect2(), "hint_trans")
	dial._avatar_ref = mock_avatar
	# Verify Hint mode invariant
	_assert(dial.is_hint_active() == true, "Hint mode is active")
	_assert(dial.dim_backdrop.visible == false, "DimBackdrop is hidden in hint mode")
	_assert(dial.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Root mouse_filter is IGNORE in hint mode")
	_assert(mock_avatar.input_enabled == true, "Avatar input remains ENABLED in hint mode")
	
	# Step 2: Immediately call open_for_npc (Standard NPC Mode)
	dial.open_for_npc(
		"ceo_alex",
		"Alex",
		"Founder & CEO",
		"Welcome to the incubator, founder!",
		"quest_briefcases",
		"Collect Briefcases",
		"Find 3 briefcases",
		3,
		150.0,
		15,
		Color(0.2, 0.7, 1.0),
		mock_avatar
	)
	
	_assert(dial.is_hint_active() == false, "Hint mode cleanly cleared by open_for_npc")
	_assert(dial.is_tutorial_active() == false, "Tutorial mode is false in NPC mode")
	_assert(mock_avatar.input_enabled == false,
		"Invariant: Avatar input is strictly DISABLED when open_for_npc is called")
	_assert(dial.dim_backdrop.visible == true,
		"Invariant: DimBackdrop is strictly VISIBLE in NPC mode")
	_assert(dial.dim_backdrop.mouse_filter == Control.MOUSE_FILTER_STOP,
		"Invariant: DimBackdrop mouse_filter is STOP (0) in NPC mode")
	_assert(dial.mouse_filter == Control.MOUSE_FILTER_STOP,
		"Invariant: Root mouse_filter is STOP (0) in NPC mode")
	_assert(dial.card_panel.custom_minimum_size.x >= 500.0 and dial.card_panel.custom_minimum_size.y >= 480.0,
		"Invariant: CardPanel custom_minimum_size restored to >= 500x480 (actual: %s)" % str(dial.card_panel.custom_minimum_size))
		
	# Step 3: Call close_dialogue()
	dial.close_dialogue()
	_assert(dial.visible == false, "DialoguePanel hidden after close_dialogue()")
	_assert(mock_avatar.input_enabled == true,
		"Invariant: Avatar input is cleanly RE-ENABLED after close_dialogue()")

	# =========================================================================
	# SUITE 4: Interleaved Re-entrancy & Rapid Mode Switching
	# =========================================================================
	print("\n--- SUITE 4: Interleaved Re-entrancy & Rapid Mode Switching ---")
	
	var mode_stress_passed = true
	for i in range(20):
		# Tutorial -> Hint -> NPC -> Close
		dial.open_for_tutorial_step("Angel", "Tut %d" % i, "Desc")
		if mock_avatar.input_enabled != true or dial.dim_backdrop.visible != false:
			mode_stress_passed = false
			break
			
		dial.show_hint_popup("Hint %d" % i, "Text", 5.0, Rect2(), "hint_%d" % i)
		if mock_avatar.input_enabled != true or dial.dim_backdrop.visible != false:
			mode_stress_passed = false
			break
			
		dial.open_for_npc("architect_bob", "Bob", "Architect", "Dialogue", "", "", "", 1, 0.0, 0, Color.WHITE, mock_avatar)
		if mock_avatar.input_enabled != false or dial.dim_backdrop.visible != true or dial.mouse_filter != Control.MOUSE_FILTER_STOP:
			mode_stress_passed = false
			break
			
		dial.close_dialogue()
		if mock_avatar.input_enabled != true or dial.visible != false:
			mode_stress_passed = false
			break
			
	_assert(mode_stress_passed,
		"20 rapid interleaved cycles (Tutorial -> Hint -> NPC -> Close) maintained 100% invariant consistency")

	# =========================================================================
	# SUITE 5: Event Discrimination, Pointer Isolation & Freed Avatar Safety
	# =========================================================================
	print("\n--- SUITE 5: Event Discrimination, Pointer Isolation & Freed Avatar Safety ---")
	
	# 5.1: Touch event (InputEventScreenTouch) dismisses hint
	dial.show_hint_popup("Touch Hint", "Test touch dismiss", 5.0, Rect2(), "hint_touch")
	var touch_ev = InputEventScreenTouch.new()
	touch_ev.pressed = true
	dial._on_card_panel_gui_input(touch_ev)
	_assert(dial.is_hint_active() == false, "InputEventScreenTouch successfully dismisses hint popup")
	
	# 5.2: Right mouse click does NOT dismiss hint
	dial.show_hint_popup("Right Click Hint", "Test right click isolation", 5.0, Rect2(), "hint_rmb")
	var rmb_ev = InputEventMouseButton.new()
	rmb_ev.pressed = true
	rmb_ev.button_index = MOUSE_BUTTON_RIGHT
	dial._on_card_panel_gui_input(rmb_ev)
	_assert(dial.is_hint_active() == true, "Right mouse click does NOT dismiss hint popup")
	
	# 5.3: Mouse button release does NOT dismiss hint
	var release_ev = InputEventMouseButton.new()
	release_ev.pressed = false
	release_ev.button_index = MOUSE_BUTTON_LEFT
	dial._on_card_panel_gui_input(release_ev)
	_assert(dial.is_hint_active() == true, "Mouse button release does NOT dismiss hint popup")
	dial.dismiss_hint()
	
	# 5.4: Gui input on CardPanel during NPC mode does NOT close NPC dialogue
	dial.open_for_npc("ceo_alex", "Alex", "CEO", "Test", "", "", "", 1, 0.0, 0, Color.WHITE, mock_avatar)
	dial._on_card_panel_gui_input(click_ev)
	_assert(dial.visible == true, "CardPanel gui_input during NPC mode does NOT dismiss dialogue")
	dial.close_dialogue()
	
	# 5.5: Freed avatar reference defense
	var ephemeral_avatar = MockAvatar.new()
	root_node.add_child(ephemeral_avatar)
	dial.open_for_npc("ceo_alex", "Alex", "CEO", "Test", "", "", "", 1, 0.0, 0, Color.WHITE, ephemeral_avatar)
	ephemeral_avatar.free() # Free immediately
	# Close dialogue should safely verify is_instance_valid() without crashing
	dial.close_dialogue()
	_assert(dial.visible == false, "close_dialogue() survived freed avatar reference gracefully without crash")
	
	# Test freed avatar in show_hint_popup
	var ephemeral_avatar2 = MockAvatar.new()
	root_node.add_child(ephemeral_avatar2)
	dial._avatar_ref = ephemeral_avatar2
	ephemeral_avatar2.free()
	dial.show_hint_popup("Safe Hint", "Testing freed avatar safety", 0.01)
	dial._process(0.02)
	_assert(dial.visible == false, "show_hint_popup auto-dismiss survived freed avatar reference gracefully")

	# =========================================================================
	# SUITE 6: Headless Stability & Static Scene Contract Safety
	# =========================================================================
	print("\n--- SUITE 6: Headless Stability & Static Scene Contract Safety ---")
	
	# Verify button count invariant
	var all_buttons: Array[Node] = []
	var check_btns = func(node: Node, recurse: Callable) -> void:
		if node is Button:
			all_buttons.append(node)
		for c in node.get_children():
			recurse.call(c, recurse)
	check_btns.call(dial, check_btns)
	_assert(all_buttons.size() == 6, "Strict Invariant: Exactly 6 Button nodes exist in DialoguePanel (actual: %d)" % all_buttons.size())
	
	# Cleanup test nodes
	mock_avatar.queue_free()
	dial.queue_free()
	
	print("\n======================================================================")
	print("CHALLENGER 2 ADVERSARIAL STRESS TEST SUMMARY")
	print("Passed: %d, Failed: %d" % [pass_count, fail_count])
	print("======================================================================")
	
	quit(0 if fail_count == 0 else 1)
