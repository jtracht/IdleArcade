extends SceneTree

## Headless Unit & Integration Test for Tutorial UI Ergonomics, Directional Indicator,
## Skip Button, and Dialogue Extensions (Phase 17 Milestone 1).
## Execution: godot --headless --path IdleArcade -s tests/test_tutorial_ui_ergonomics.gd

var pass_count: int = 0
var fail_count: int = 0

const TutorialOverlayScript = preload("res://scripts/ui/tutorial_overlay.gd")
const TutorialOverlayScene = preload("res://scenes/ui/tutorial_overlay.tscn")
const DialoguePanelScene = preload("res://scenes/dialogue_panel.tscn")

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
	print("Running Milestone 1 Tutorial UI Ergonomics & Indicator Test Suite")
	print("=================================================================")

	var root_node = root
	
	# -------------------------------------------------------------------------
	# TIER 1: Overlay Instantiation & 4-Blocker Mask Structure
	# -------------------------------------------------------------------------
	print("\n--- TIER 1: Overlay Instantiation & Blocker Mask Contracts ---")
	var overlay = TutorialOverlayScene.instantiate()
	root_node.add_child(overlay)
	
	_assert_check(overlay != null, "TutorialOverlay instantiates cleanly")
	_assert_check(overlay is CanvasLayer, "TutorialOverlay is a CanvasLayer")
	_assert_check(overlay.layer == 95, "TutorialOverlay is on layer 95")
	
	var top_b = overlay.get_node_or_null("%TopBlocker") as ColorRect
	var bottom_b = overlay.get_node_or_null("%BottomBlocker") as ColorRect
	var left_b = overlay.get_node_or_null("%LeftBlocker") as ColorRect
	var right_b = overlay.get_node_or_null("%RightBlocker") as ColorRect
	
	_assert_check(top_b != null and bottom_b != null and left_b != null and right_b != null,
		"All 4 Blocker ColorRect nodes exist in overlay")
		
	if top_b and bottom_b and left_b and right_b:
		_assert_check(top_b.mouse_filter == Control.MOUSE_FILTER_STOP, "TopBlocker mouse_filter is STOP (0)")
		_assert_check(bottom_b.mouse_filter == Control.MOUSE_FILTER_STOP, "BottomBlocker mouse_filter is STOP (0)")
		_assert_check(left_b.mouse_filter == Control.MOUSE_FILTER_STOP, "LeftBlocker mouse_filter is STOP (0)")
		_assert_check(right_b.mouse_filter == Control.MOUSE_FILTER_STOP, "RightBlocker mouse_filter is STOP (0)")
		_assert_check(is_equal_approx(top_b.color.a, 0.65), "TopBlocker color alpha is 0.65")

	# -------------------------------------------------------------------------
	# TIER 2: Spotlight Cutout Geometry
	# -------------------------------------------------------------------------
	print("\n--- TIER 2: Spotlight Cutout Geometry Calculations ---")
	var test_rect = Rect2(310, 470, 100, 100) # Core Reactor bounds
	var padding = 10.0
	overlay.highlight_target_rect(test_rect, padding)
	
	# Expanded cutout hole: Rect2(300, 460, 120, 120)
	var expected_hole = test_rect.grow(padding)
	if top_b and bottom_b and left_b and right_b:
		_assert_check(top_b.size.y == expected_hole.position.y,
			"TopBlocker height matches cutout top Y (460.0)")
		_assert_check(bottom_b.position.y == expected_hole.end.y,
			"BottomBlocker position Y matches cutout bottom Y (580.0)")
		_assert_check(left_b.position.y == expected_hole.position.y and left_b.size.y == expected_hole.size.y,
			"LeftBlocker vertical bounds match cutout hole")
		_assert_check(right_b.position.x == expected_hole.end.x,
			"RightBlocker position X matches cutout right X (420.0)")
			
		# Mathematical area check: blockers + cutout == total viewport area (720 * 1280)
		var vp_dims = overlay.get_viewport_dimensions()
		var total_vp_area = vp_dims.x * vp_dims.y
		var cutout_area = expected_hole.size.x * expected_hole.size.y
		var blocker_area = (top_b.size.x * top_b.size.y) + (bottom_b.size.x * bottom_b.size.y) + (left_b.size.x * left_b.size.y) + (right_b.size.x * right_b.size.y)
		_assert_check(is_equal_approx(total_vp_area, cutout_area + blocker_area),
			"Exact mathematical partition: blocker area + cutout area == total viewport area (%d px^2)" % int(total_vp_area))

		# Cutout point containment tests
		_assert_check(overlay.is_point_in_cutout(Vector2(360, 520)), "Center point (360, 520) is inside cutout")
		_assert_check(not overlay.is_point_in_blocker(Vector2(360, 520)), "Center point (360, 520) is NOT blocked")
		_assert_check(overlay.is_point_in_blocker(Vector2(100, 100)), "Off-target point (100, 100) is blocked by TopBlocker")
		_assert_check(overlay.is_point_in_blocker(Vector2(360, 800)), "Off-target point (360, 800) is blocked by BottomBlocker")

	overlay.clear_highlight()
	_assert_check(not overlay.is_highlight_active(), "clear_highlight() resets active flag")
	_assert_check(top_b.visible == false, "clear_highlight() hides TopBlocker")

	# -------------------------------------------------------------------------
	# TIER 3: Directional Arrow Math, Orientation & Animation
	# -------------------------------------------------------------------------
	print("\n--- TIER 3: Directional Arrow Math & Viewport Clamping ---")
	var arrow = overlay.get_node_or_null("%ArrowIndicator") as Control
	_assert_check(arrow != null, "ArrowIndicator node exists in TutorialOverlay")
	
	var vp = Vector2(720.0, 1280.0)
	
	# Test lower-half target (Y = 800) -> arrow should sit ABOVE pointing DOWN
	var lower_target = Rect2(300, 800, 120, 80)
	var transform_lower = overlay.calculate_arrow_transform(lower_target, vp)
	_assert_check(transform_lower.direction == Vector2.DOWN,
		"Arrow points DOWN for lower-half target", str(transform_lower.direction))
	_assert_check(transform_lower.position.y < lower_target.position.y,
		"Arrow is positioned ABOVE lower-half target", str(transform_lower.position.y))
	_assert_check(is_equal_approx(transform_lower.rotation, PI * 0.5),
		"Arrow rotation is PI/2 for downward orientation", str(transform_lower.rotation))

	# Test upper-half target (Y = 200) -> arrow should sit BELOW pointing UP
	var upper_target = Rect2(300, 200, 120, 80)
	var transform_upper = overlay.calculate_arrow_transform(upper_target, vp)
	_assert_check(transform_upper.direction == Vector2.UP,
		"Arrow points UP for upper-half target", str(transform_upper.direction))
	_assert_check(transform_upper.position.y > upper_target.end.y,
		"Arrow is positioned BELOW upper-half target", str(transform_upper.position.y))
	_assert_check(is_equal_approx(transform_upper.rotation, -PI * 0.5),
		"Arrow rotation is -PI/2 for upward orientation", str(transform_upper.rotation))

	# Test screen-edge clamping and flip safety
	var edge_target = Rect2(10, 10, 50, 50)
	var transform_edge = overlay.calculate_arrow_transform(edge_target, vp)
	_assert_check(transform_edge.position.x >= 40.0,
		"Arrow X position clamped to safe margin >= 40px", str(transform_edge.position.x))
	_assert_check(transform_edge.position.y >= 40.0,
		"Arrow Y position clamped to safe margin >= 40px", str(transform_edge.position.y))

	# Test oscillation stepping
	overlay.highlight_target_rect(lower_target)
	var initial_arrow_pos = arrow.position if arrow else Vector2.ZERO
	overlay._process(0.1) # Step frame
	_assert_check(arrow != null and arrow.position != initial_arrow_pos,
		"Arrow position updates smoothly during _process()")

	# -------------------------------------------------------------------------
	# TIER 4: Skip Button Ergonomics & Signals
	# -------------------------------------------------------------------------
	print("\n--- TIER 4: Skip Button Touch Ergonomics & Signal Contracts ---")
	var skip_btn = overlay.get_node_or_null("%SkipButton") as Button
	_assert_check(skip_btn != null, "SkipButton node exists with unique name %SkipButton")
	
	if skip_btn:
		_assert_check(skip_btn.custom_minimum_size.x >= 120.0,
			"SkipButton custom_minimum_size width >= 120px", str(skip_btn.custom_minimum_size.x))
		_assert_check(skip_btn.custom_minimum_size.y >= 56.0,
			"SkipButton custom_minimum_size height >= 56px (Mobile Compliant)", str(skip_btn.custom_minimum_size.y))
		_assert_check(skip_btn.mouse_filter == Control.MOUSE_FILTER_STOP,
			"SkipButton mouse_filter is STOP (0)")
		_assert_check("Überspringen" in skip_btn.text,
			"SkipButton text contains German label 'Überspringen'", skip_btn.text)
			
		# Signal emission test
		var skip_signal_received: Array = []
		overlay.skip_pressed.connect(func(): skip_signal_received.append(true))
		skip_btn.pressed.emit()
		_assert_check(skip_signal_received.size() > 0, "SkipButton press emits overlay.skip_pressed signal")
		
		# Visibility toggle test
		overlay.set_skip_visible(false)
		_assert_check(skip_btn.visible == false, "set_skip_visible(false) hides skip button")
		overlay.set_skip_visible(true)
		_assert_check(skip_btn.visible == true, "set_skip_visible(true) shows skip button")

	# -------------------------------------------------------------------------
	# TIER 5: DialoguePanel Mascot Extensions & Strict Invariants
	# -------------------------------------------------------------------------
	print("\n--- TIER 5: DialoguePanel Mascot Extensions & Strict Invariants ---")
	var dial = DialoguePanelScene.instantiate()
	root_node.add_child(dial)
	
	# Strict AST regression check: must have exactly 6 Button nodes in dialogue_panel.tscn
	var all_buttons: Array[Node] = []
	_collect_buttons(dial, all_buttons)
	_assert_check(all_buttons.size() == 6,
		"Strict Invariant: dialogue_panel.tscn contains EXACTLY 6 Button nodes (found: %d)" % all_buttons.size())

	# Test open_for_tutorial_step()
	dial.open_for_tutorial_step(
		"Angel Investor",
		"Pre-Seed Phase // Traktion",
		"Willkommen im Inkubator, Gründer! Tippe auf den Reaktorkern in der Mitte.",
		Color(1.0, 0.82, 0.15)
	)
	_assert_check(dial.visible == true, "DialoguePanel becomes visible on open_for_tutorial_step()")
	_assert_check(dial.name_label.text == "Angel Investor", "Mascot name displayed correctly")
	_assert_check(dial.title_label.text == "Pre-Seed Phase // Traktion", "Mascot title displayed correctly")
	_assert_check(dial.dialogue_label.text == "Willkommen im Inkubator, Gründer! Tippe auf den Reaktorkern in der Mitte.",
		"Dialogue text displayed correctly")
	_assert_check(dial.avatar_badge.color == Color(1.0, 0.82, 0.15), "Badge color set to venture gold")
	_assert_check(dial.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Root mouse_filter is IGNORE during tutorial step")
	_assert_check(dial.dim_backdrop.visible == false, "DimBackdrop hidden during tutorial step")
	_assert_check(dial.close_button.text == "Weiter ➔", "CloseButton styled as 'Weiter ➔'")

	# Test tutorial advance signal emission
	var tutorial_advanced_emitted: Array = []
	dial.tutorial_advanced.connect(func(): tutorial_advanced_emitted.append(true))
	dial.close_dialogue()
	_assert_check(tutorial_advanced_emitted.size() > 0, "close_dialogue in tutorial mode emits tutorial_advanced")
	_assert_check(dial.visible == false, "DialoguePanel hidden after advancing")

	# Test show_hint_popup() & Auto-dismiss countdown
	var hint_dismissed_events: Array = []
	dial.hint_dismissed.connect(func(h_id: String): hint_dismissed_events.append(h_id))
	dial.show_hint_popup("Sicherheitsbereich // Zonentor", "Dieses Zonentor verlangt ein Badge!", 3.0, Rect2(), "hint_zone_gate")
	_assert_check(dial.visible == true, "DialoguePanel visible on show_hint_popup()")
	_assert_check(dial.is_hint_active() == true, "is_hint_active() returns true during hint mode")
	_assert_check(dial.dim_backdrop.visible == false, "DimBackdrop is hidden during hint popup")
	_assert_check(dial.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Root mouse_filter is IGNORE during hint popup")
	
	# Step timer past duration
	dial._process(3.5)
	_assert_check(dial.visible == false, "Auto-dismiss timer hides hint popup after duration")
	_assert_check(hint_dismissed_events.size() > 0 and hint_dismissed_events[-1] == "hint_zone_gate",
		"hint_dismissed emitted with correct hint_id ('hint_zone_gate')")

	# Test tap-to-dismiss via GUI input event
	dial.show_hint_popup("R&D // Forschungsbaum", "Tech-Tree entdecken", 10.0, Rect2(), "hint_tech_tree")
	_assert_check(dial.is_hint_active() == true, "Hint active before tap")
	var click_event = InputEventMouseButton.new()
	click_event.pressed = true
	click_event.button_index = MOUSE_BUTTON_LEFT
	dial._on_card_panel_gui_input(click_event)
	_assert_check(dial.visible == false, "Tap on CardPanel immediately dismisses hint popup")
	_assert_check(hint_dismissed_events.size() > 1 and hint_dismissed_events[-1] == "hint_tech_tree",
		"hint_dismissed emitted with 'hint_tech_tree'")

	# Test open_for_npc state restoration
	dial.open_for_npc("ceo_alex", "Alex", "Founder & CEO", "Hallo Gründer!")
	_assert_check(dial.is_hint_active() == false, "open_for_npc cleanly clears hint mode")
	_assert_check(dial.is_tutorial_active() == false, "open_for_npc cleanly clears tutorial mode")
	_assert_check(dial.dim_backdrop.visible == true, "open_for_npc restores DimBackdrop visibility")
	_assert_check(dial.dim_backdrop.mouse_filter == Control.MOUSE_FILTER_STOP, "open_for_npc restores DimBackdrop mouse_filter to STOP")
	_assert_check(dial.mouse_filter == Control.MOUSE_FILTER_STOP, "open_for_npc restores root mouse_filter to STOP")
	dial.close_dialogue()

	# Cleanup
	overlay.queue_free()
	dial.queue_free()
	
	print("\n=================================================================")
	print("Milestone 1 Test Results: %d Passed, %d Failed" % [pass_count, fail_count])
	print("=================================================================")
	
	quit(0 if fail_count == 0 else 1)

func _collect_buttons(node: Node, result: Array[Node]) -> void:
	if node is Button:
		result.append(node)
	for child in node.get_children():
		_collect_buttons(child, result)
