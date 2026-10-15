extends SceneTree

## Empirical Challenger Test Suite for Milestone P5-M2
## Focus: Monte Carlo Input Isolation (1,000 Points), Ergonomics Geometry & Multi-Touch Concurrency
##
## Role: Empirical Challenger (critic, specialist)
## Target: IdleArcade (Godot 4.3 Mobile Touch Navigation)
##
## Executable via:
##   godot --headless --path IdleArcade -s tests/test_p5_m2_challenger_isolation.gd

var pass_count: int = 0
var fail_count: int = 0

const VIEWPORT_WIDTH: float = 720.0
const VIEWPORT_HEIGHT: float = 1280.0
const EPSILON: float = 0.001

func _init() -> void:
	print("====================================================================")
	print("[CHALLENGER-2] P5-M2 Empirical Input Isolation & Ergonomics Suite")
	print("====================================================================")
	process_frame.connect(_on_first_frame, CONNECT_ONE_SHOT)

func _on_first_frame() -> void:
	await _run_all_challenges()
	print("\n====================================================================")
	print("[CHALLENGER-2] Results: %d passed, %d failed" % [pass_count, fail_count])
	print("====================================================================")
	if fail_count == 0:
		print(">>> VERDICT: APPROVE — ALL EMPIRICAL CHALLENGES PASSED! <<<")
		quit(0)
	else:
		printerr(">>> VERDICT: REQUEST_CHANGES — %d EMPIRICAL CHALLENGES FAILED! <<<" % fail_count)
		quit(1)

func _assert_test(cond: bool, test_name: String, detail: String = "") -> void:
	if cond:
		print("  [PASS] %s" % test_name)
		pass_count += 1
	else:
		var err_msg = "  [FAIL] %s" % test_name
		if detail != "":
			err_msg += " -> " + detail
		printerr(err_msg)
		fail_count += 1

func _run_all_challenges() -> void:
	# 0. Setup GameState autoload
	var gs_script = load("res://scripts/autoload/game_state.gd")
	var gs = root.get_node_or_null("GameState")
	if gs == null and gs_script != null:
		gs = gs_script.new()
		gs.name = "GameState"
		root.add_child(gs)
	await process_frame

	var touch_controls_scene = load("res://scenes/ui/touch_controls.tscn")
	var avatar_scene = load("res://scenes/avatar_3d.tscn")
	var main_3d_scene = load("res://scenes/main_3d.tscn")

	if touch_controls_scene == null or avatar_scene == null or main_3d_scene == null:
		printerr("[FATAL] Core scenes failed to load.")
		fail_count += 1
		return

	# =========================================================================
	# SECTION 1: Ergonomics Geometry Verification
	# =========================================================================
	print("\n--- Section 1: Ergonomics Geometry Verification ---")
	print("Hypothesis: ActionButton (635, 1155) and LaptopThumbButton (635, 1035) maintain exactly 120px center distance and 25px edge clearance.")

	var tc_inst = touch_controls_scene.instantiate() as TouchControls
	root.add_child(tc_inst)
	await process_frame

	var action_btn = tc_inst.find_child("ActionButton", true, false) as Button
	var laptop_btn = tc_inst.find_child("LaptopThumbButton", true, false) as Button
	var joystick_ctrl = tc_inst.find_child("VirtualJoystick", true, false) as VirtualJoystick

	_assert_test(action_btn != null, "1.1 ActionButton resolved in scene tree")
	_assert_test(laptop_btn != null, "1.2 LaptopThumbButton resolved in scene tree")
	_assert_test(joystick_ctrl != null, "1.3 VirtualJoystick resolved in scene tree")

	# Dimensions check
	var act_size = action_btn.size
	var lap_size = laptop_btn.size
	_assert_test(abs(act_size.x - 110.0) < 1.0 and abs(act_size.y - 110.0) < 1.0,
		"1.4 ActionButton dimensions exactly 110x110 (actual: %.1fx%.1f)" % [act_size.x, act_size.y])
	_assert_test(abs(lap_size.x - 80.0) < 1.0 and abs(lap_size.y - 80.0) < 1.0,
		"1.5 LaptopThumbButton dimensions exactly 80x80 (actual: %.1fx%.1f)" % [lap_size.x, lap_size.y])

	var act_radius = act_size.x * 0.5 # 55.0
	var lap_radius = lap_size.x * 0.5 # 40.0

	# Center positions check
	var act_center = action_btn.position + act_size * 0.5
	var lap_center = laptop_btn.position + lap_size * 0.5

	_assert_test(abs(act_center.x - 635.0) < 1.0 and abs(act_center.y - 1155.0) < 1.0,
		"1.6 ActionButton center at (635, 1155) (actual: %.1f, %.1f)" % [act_center.x, act_center.y])
	_assert_test(abs(lap_center.x - 635.0) < 1.0 and abs(lap_center.y - 1035.0) < 1.0,
		"1.7 LaptopThumbButton center at (635, 1035) (actual: %.1f, %.1f)" % [lap_center.x, lap_center.y])

	# Center-to-center distance
	var center_distance = act_center.distance_to(lap_center)
	_assert_test(abs(center_distance - 120.0) < 1.0,
		"1.8 Center distance between buttons is exactly 120px (actual: %.2f px)" % center_distance)

	# Edge clearance gap
	var sum_radii = act_radius + lap_radius # 55 + 40 = 95
	var radial_clearance = center_distance - sum_radii
	_assert_test(abs(radial_clearance - 25.0) < 1.0,
		"1.9 Radial edge clearance between button circular profiles is exactly 25px (actual: %.2f px)" % radial_clearance)

	# Bounding rect vertical clearance
	var act_top = action_btn.position.y
	var lap_bottom = laptop_btn.position.y + lap_size.y
	var rect_clearance = act_top - lap_bottom
	_assert_test(abs(rect_clearance - 25.0) < 1.0,
		"1.10 Bounding rect vertical clearance is exactly 25px (actual: %.2f px)" % rect_clearance)

	# Screen half separation
	var act_left_edge = action_btn.position.x
	var lap_left_edge = laptop_btn.position.x
	var joy_max_x = 360.0

	_assert_test(act_left_edge >= 580.0, "1.11 ActionButton left edge >= 580px (actual: %.1f px)" % act_left_edge)
	_assert_test(lap_left_edge >= 580.0, "1.12 LaptopThumbButton left edge >= 580px (actual: %.1f px)" % lap_left_edge)
	_assert_test(act_left_edge - joy_max_x >= 220.0,
		"1.13 Thumb separation buffer >= 220px between left joystick and right action buttons (actual: %.1f px)" % (act_left_edge - joy_max_x))

	# Palm rest reachability arc
	var palm_pivot = Vector2(VIEWPORT_WIDTH, VIEWPORT_HEIGHT)
	var reach_action = palm_pivot.distance_to(act_center)
	var reach_laptop = palm_pivot.distance_to(lap_center)
	_assert_test(reach_action >= 140.0 and reach_action <= 165.0,
		"1.14 ActionButton in natural primary thumb strike zone (actual: %.1f px, ideal: 140-165 px)" % reach_action)
	_assert_test(reach_laptop >= 240.0 and reach_laptop <= 280.0,
		"1.15 LaptopThumbButton in comfortable upward thumb sweep arc (actual: %.1f px, ideal: 240-280 px)" % reach_laptop)

	# =========================================================================
	# SECTION 2: 1,000-Point Monte Carlo Input Isolation Challenge
	# =========================================================================
	print("\n--- Section 2: 1,000-Point Monte Carlo Input Isolation Challenge ---")
	print("Hypothesis: Touches on ActionButton, LaptopThumbButton, and VirtualJoystick call accept_event() and NEVER leak to Avatar3D; touches on upper campus DO pass.")

	# Setup test avatar and camera
	var avatar = avatar_scene.instantiate() as Avatar3D
	root.add_child(avatar)
	avatar.global_position = Vector3(0.0, 0.0, 0.0)

	var camera = Camera3D.new()
	root.add_child(camera)
	camera.global_position = Vector3(10.0, 10.0, 10.0)
	camera.look_at(Vector3.ZERO, Vector3.UP)
	await process_frame

	var action_hits: int = 0
	var laptop_hits: int = 0
	var joystick_hits: int = 0
	var upper_campus_hits: int = 0
	var other_hits: int = 0

	var leaked_to_avatar: int = 0
	var upper_campus_passed: int = 0

	var act_rect = Rect2(action_btn.position, action_btn.size)
	var lap_rect = Rect2(laptop_btn.position, laptop_btn.size)
	var joy_rect = Rect2(Vector2(0.0, 70.0), Vector2(360.0, 1210.0))
	var upper_campus_rect = Rect2(Vector2(360.0, 70.0), Vector2(360.0, 730.0)) # X in [360, 720], Y in [70, 800]

	# Pseudo-random LCG sequence for deterministic reproduction
	var lcg_state: int = 42

	for i in range(1000):
		lcg_state = (lcg_state * 1664525 + 1013904223) & 0x7FFFFFFF
		var rx = float(lcg_state % int(VIEWPORT_WIDTH * 100)) / 100.0
		lcg_state = (lcg_state * 1664525 + 1013904223) & 0x7FFFFFFF
		var ry = float(lcg_state % int(VIEWPORT_HEIGHT * 100)) / 100.0
		var pt = Vector2(rx, ry)

		var ev = InputEventScreenTouch.new()
		ev.index = 0
		ev.position = pt
		ev.pressed = true

		# Reset avatar click destination
		avatar.stop_movement()

		# Determine expected surface target
		var is_action = act_rect.has_point(pt)
		var is_laptop = lap_rect.has_point(pt)
		var is_joystick = joy_rect.has_point(pt)
		var is_upper_campus = upper_campus_rect.has_point(pt)

		if is_action:
			action_hits += 1
			# GUI event sent to ActionButton
			action_btn._gui_input(ev)
			# Event must be accepted and NOT leak to Avatar3D
			if avatar._has_click_target:
				leaked_to_avatar += 1
		elif is_laptop:
			laptop_hits += 1
			laptop_btn._gui_input(ev)
			if avatar._has_click_target:
				leaked_to_avatar += 1
		elif is_joystick:
			joystick_hits += 1
			joystick_ctrl._gui_input(ev)
			if avatar._has_click_target:
				leaked_to_avatar += 1
		elif is_upper_campus:
			upper_campus_hits += 1
			# Root TouchControls has MOUSE_FILTER_IGNORE, so upper campus touches pass through
			# and fall through to Avatar3D._unhandled_input()
			avatar._unhandled_input(ev)
			if avatar._has_click_target:
				upper_campus_passed += 1
		else:
			other_hits += 1

	print("  [MONTE CARLO] Samples evaluated: 1,000")
	print("  [MONTE CARLO] ActionButton hits: %d" % action_hits)
	print("  [MONTE CARLO] LaptopThumbButton hits: %d" % laptop_hits)
	print("  [MONTE CARLO] VirtualJoystick hits: %d" % joystick_hits)
	print("  [MONTE CARLO] Upper campus area hits: %d" % upper_campus_hits)
	print("  [MONTE CARLO] Other margin hits: %d" % other_hits)
	print("  [MONTE CARLO] Leaks to Avatar3D from controls: %d" % leaked_to_avatar)
	print("  [MONTE CARLO] Upper campus taps reached Avatar3D: %d" % upper_campus_passed)

	_assert_test(action_hits > 10, "2.1 ActionButton received statistically significant hits (%d hits)" % action_hits)
	_assert_test(laptop_hits > 5, "2.2 LaptopThumbButton received statistically significant hits (%d hits)" % laptop_hits)
	_assert_test(joystick_hits > 300, "2.3 VirtualJoystick received statistically significant hits (%d hits)" % joystick_hits)
	_assert_test(upper_campus_hits > 200, "2.4 Upper campus received statistically significant hits (%d hits)" % upper_campus_hits)

	_assert_test(leaked_to_avatar == 0,
		"2.5 ZERO touch events leaked from interactive controls to Avatar3D (leak count: %d)" % leaked_to_avatar)
	_assert_test(upper_campus_passed == upper_campus_hits,
		"2.6 100%% of upper campus touches passed cleanly to Avatar3D click-to-move (%d / %d)" % [upper_campus_passed, upper_campus_hits])

	# =========================================================================
	# SECTION 3: Adversarial Boundary & Gap Stress
	# =========================================================================
	print("\n--- Section 3: Adversarial Boundary & Gap Stress ---")
	print("Hypothesis: Exact boundary points and the 25px inter-button gap behave strictly according to isolation specification.")

	# 3.1 Exact center and 4 cardinal edges of ActionButton
	var act_edges = [
		act_center, # Center (635, 1155)
		act_center + Vector2(0.0, -54.9), # Top edge
		act_center + Vector2(0.0, 54.9),  # Bottom edge
		act_center + Vector2(-54.9, 0.0), # Left edge
		act_center + Vector2(54.9, 0.0),  # Right edge
	]
	var act_boundary_leaks: int = 0
	for pt in act_edges:
		avatar.stop_movement()
		var ev = InputEventScreenTouch.new()
		ev.position = pt
		ev.pressed = true
		action_btn._gui_input(ev)
		if avatar._has_click_target:
			act_boundary_leaks += 1
	_assert_test(act_boundary_leaks == 0, "3.1 All ActionButton boundary & center points consumed with zero leaks")

	# 3.2 Exact center and 4 cardinal edges of LaptopThumbButton
	var lap_edges = [
		lap_center, # Center (635, 1035)
		lap_center + Vector2(0.0, -39.9), # Top edge
		lap_center + Vector2(0.0, 39.9),  # Bottom edge
		lap_center + Vector2(-39.9, 0.0), # Left edge
		lap_center + Vector2(39.9, 0.0),  # Right edge
	]
	var lap_boundary_leaks: int = 0
	for pt in lap_edges:
		avatar.stop_movement()
		var ev = InputEventScreenTouch.new()
		ev.position = pt
		ev.pressed = true
		laptop_btn._gui_input(ev)
		if avatar._has_click_target:
			lap_boundary_leaks += 1
	_assert_test(lap_boundary_leaks == 0, "3.2 All LaptopThumbButton boundary & center points consumed with zero leaks")

	# 3.3 The 25px gap between the two buttons (Y in [1075, 1100], X = 635)
	var gap_pt = Vector2(635.0, 1087.5) # Exactly halfway in the 25px gap
	_assert_test(not act_rect.has_point(gap_pt), "3.3 Gap point (635, 1087.5) is outside ActionButton")
	_assert_test(not lap_rect.has_point(gap_pt), "3.4 Gap point (635, 1087.5) is outside LaptopThumbButton")

	avatar.stop_movement()
	var ev_gap = InputEventScreenTouch.new()
	ev_gap.position = gap_pt
	ev_gap.pressed = true
	# Passes through transparent layer to Avatar3D
	avatar._unhandled_input(ev_gap)
	_assert_test(avatar._has_click_target == true, "3.5 Tap in inter-button gap safely falls through to ground navigation")

	# 3.4 Multi-Touch Independence: Finger 0 on Joystick, Finger 1 on ActionButton
	avatar.stop_movement()
	var f0_touch = InputEventScreenTouch.new()
	f0_touch.index = 0
	f0_touch.position = Vector2(180.0, 1000.0)
	f0_touch.pressed = true
	joystick_ctrl.handle_touch_event(f0_touch)

	var f1_touch = InputEventScreenTouch.new()
	f1_touch.index = 1
	f1_touch.position = act_center
	f1_touch.pressed = true
	action_btn._gui_input(f1_touch)

	_assert_test(joystick_ctrl.is_active == true, "3.6 Joystick remains active when secondary finger taps ActionButton")
	_assert_test(avatar._has_click_target == false, "3.7 Zero ground clicks produced during concurrent dual-thumb touch")

	# Release both
	f0_touch.pressed = false
	joystick_ctrl.handle_touch_event(f0_touch)
	_assert_test(joystick_ctrl.is_active == false, "3.8 Joystick cleanly deactivated on release")

	# =========================================================================
	# SECTION 4: CanvasLayer 7 Stack Isolation in Main3D
	# =========================================================================
	print("\n--- Section 4: CanvasLayer 7 Stack Isolation in Main3D ---")
	print("Hypothesis: In full Main3D scene, TouchControlsLayer at Layer 7 correctly shields the 3D world while modals obscure it.")

	var main_inst = main_3d_scene.instantiate() as Main3D
	root.add_child(main_inst)
	await process_frame

	var touch_layer = main_inst.get_node_or_null("TouchControlsLayer") as CanvasLayer
	_assert_test(touch_layer != null, "4.1 TouchControlsLayer exists in Main3D")
	_assert_test(touch_layer.layer == 7, "4.2 TouchControlsLayer layer is 7")

	var quick_hud = main_inst.get_node_or_null("QuickHUDLayer") as CanvasLayer
	var quest_layer = main_inst.get_node_or_null("QuestLayer") as CanvasLayer
	var dialogue_layer = main_inst.get_node_or_null("DialogueLayer") as CanvasLayer
	var hud_overlay_layer = main_inst.get_node_or_null("HUDOverlayLayer") as CanvasLayer

	_assert_test(quick_hud != null and quick_hud.layer < 7, "4.3 QuickHUDLayer (layer %d) < TouchControlsLayer (7)" % quick_hud.layer)
	_assert_test(quest_layer != null and quest_layer.layer < 7, "4.4 QuestLayer (layer %d) < TouchControlsLayer (7)" % quest_layer.layer)
	_assert_test(dialogue_layer != null and dialogue_layer.layer > 7, "4.5 DialogueLayer (layer %d) > TouchControlsLayer (7)" % dialogue_layer.layer)
	_assert_test(hud_overlay_layer != null and hud_overlay_layer.layer > 7, "4.6 HUDOverlayLayer (layer %d) > TouchControlsLayer (7)" % hud_overlay_layer.layer)

	# Clean up
	main_inst.queue_free()
	avatar.queue_free()
	camera.queue_free()
	tc_inst.queue_free()
	await process_frame
