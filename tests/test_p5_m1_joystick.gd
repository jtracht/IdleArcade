extends SceneTree

## Headless SceneTree Test Harness for Milestone P5-M1:
## Dynamic Virtual Touch-Joystick, Radial Math, Camera-Relative 3D Mapping & Avatar Integration.
##
## Validates:
## 1. Resource loading & syntax for VirtualJoystick scene and GDScript.
## 2. Node hierarchy, properties, signals, and interface contracts.
## 3. Deadzone filtering: displacements L <= 12.0 px yield Vector2.ZERO / Vector3.ZERO.
## 4. Radius clamping: displacements L > 80.0 px clamp knob distance to 80.0 px and normalize to 1.0.
## 5. Linear scaling: active range (12 px to 80 px) scales smoothly from 0.0 to 1.0.
## 6. Cardinal and diagonal 2D-to-3D isometric conversions (UP, DOWN, LEFT, RIGHT, and 4 diagonals).
## 7. Dynamic centering logic on touch-down in left screen half (X <= 360 px, Y >= 70 px).
## 8. Multi-touch finger isolation: ignores touches with different finger indices.
## 9. Touch-up release: resets stick to center, zeros output, emits joystick_released signal.
## 10. Avatar3D integration: Avatar3D.stop_movement() immediately zeroes velocity with zero drift.
##
## Executable via:
##   godot --headless --path IdleArcade -s tests/test_p5_m1_joystick.gd

var pass_count: int = 0
var fail_count: int = 0

const EPSILON: float = 0.002
const CAMERA_YAW_45_RAD: float = 0.785398163  # 45 degrees in radians
const SQRT1_2: float = 0.707106781           # sqrt(0.5)

func _init() -> void:
	print("====================================================================")
	print("[TEST] Milestone P5-M1: Virtual Joystick & Avatar Verification Suite")
	print("====================================================================")
	process_frame.connect(_on_first_frame, CONNECT_ONE_SHOT)

func _on_first_frame() -> void:
	await _run_all_tests()
	print("\n====================================================================")
	print("[TEST] P5-M1 Results: %d passed, %d failed" % [pass_count, fail_count])
	print("====================================================================")
	if fail_count == 0:
		print(">>> ALL P5-M1 VIRTUAL JOYSTICK & AVATAR TESTS PASSED SUCCESSFULLY! <<<")
		quit(0)
	else:
		printerr(">>> TEST SUITE ENCOUNTERED %d FAILURES! <<<" % fail_count)
		quit(1)

func _assert_check(cond: bool, test_name: String, detail: String = "") -> void:
	if cond:
		print("  [PASS] %s" % test_name)
		pass_count += 1
	else:
		var err_msg = "  [FAIL] %s" % test_name
		if detail != "":
			err_msg += " -> " + detail
		printerr(err_msg)
		fail_count += 1

func _run_all_tests() -> void:
	# -------------------------------------------------------------------------
	# 0. Environment Setup: Autoload check
	# -------------------------------------------------------------------------
	var gs_script = load("res://scripts/autoload/game_state.gd")
	var gs = root.get_node_or_null("GameState")
	if gs == null and gs_script != null:
		gs = gs_script.new()
		gs.name = "GameState"
		root.add_child(gs)
	await process_frame

	# =========================================================================
	# SECTION 1: Resource Loading & Syntax Verification
	# =========================================================================
	print("\n--- Section 1: Resource Loading & Syntax Verification ---")

	var joystick_script = load("res://scripts/ui/virtual_joystick.gd")
	_assert_check(joystick_script != null, "1.1 scripts/ui/virtual_joystick.gd parsed and loaded")

	var joystick_scene = load("res://scenes/ui/virtual_joystick.tscn")
	_assert_check(joystick_scene != null, "1.2 scenes/ui/virtual_joystick.tscn loaded successfully")

	var avatar_script = load("res://scripts/avatar_3d.gd")
	_assert_check(avatar_script != null, "1.3 scripts/avatar_3d.gd parsed and loaded")

	var avatar_scene = load("res://scenes/avatar_3d.tscn")
	_assert_check(avatar_scene != null, "1.4 scenes/avatar_3d.tscn loaded successfully")

	if joystick_script == null or joystick_scene == null:
		printerr("[FATAL] Virtual Joystick resources failed to load. Halting remaining tests.")
		return

	# =========================================================================
	# SECTION 2: Node Hierarchy & Interface Contract Verification
	# =========================================================================
	print("\n--- Section 2: Node Hierarchy & Interface Contracts ---")

	var joystick = joystick_scene.instantiate()
	root.add_child(joystick)
	await process_frame

	_assert_check(joystick is Control, "2.1 VirtualJoystick root is a Control node")

	# Check mouse_filter property for input isolation
	_assert_check(joystick.mouse_filter == Control.MOUSE_FILTER_STOP or joystick.mouse_filter == Control.MOUSE_FILTER_PASS,
		"2.2 VirtualJoystick mouse_filter configured for touch reception (STOP or PASS)")

	# Check exported/public properties
	_assert_check("max_radius" in joystick, "2.3 VirtualJoystick has property max_radius")
	if "max_radius" in joystick:
		_assert_check(abs(joystick.max_radius - 80.0) < 0.1, "2.4 max_radius default is 80.0 px (actual: %.1f)" % joystick.max_radius)

	_assert_check("deadzone_radius" in joystick, "2.5 VirtualJoystick has property deadzone_radius")
	if "deadzone_radius" in joystick:
		_assert_check(abs(joystick.deadzone_radius - 12.0) < 0.1, "2.6 deadzone_radius default is 12.0 px (actual: %.1f)" % joystick.deadzone_radius)

	_assert_check("fade_duration" in joystick, "2.7 VirtualJoystick has property fade_duration")
	_assert_check("is_active" in joystick, "2.8 VirtualJoystick has property is_active")
	_assert_check("touch_finger_index" in joystick, "2.9 VirtualJoystick has property touch_finger_index")
	_assert_check("output_vector" in joystick, "2.10 VirtualJoystick has property output_vector")
	_assert_check("world_direction_3d" in joystick, "2.11 VirtualJoystick has property world_direction_3d")

	# Check signals
	_assert_check(joystick.has_signal("joystick_moved"), "2.12 VirtualJoystick declares signal joystick_moved")
	_assert_check(joystick.has_signal("joystick_released"), "2.13 VirtualJoystick declares signal joystick_released")

	# Check required calculation methods
	_assert_check(joystick.has_method("handle_touch_event"), "2.14 VirtualJoystick implements handle_touch_event(event)")
	_assert_check(joystick.has_method("calculate_clamped_stick_pos"), "2.15 VirtualJoystick implements calculate_clamped_stick_pos(touch_pos, center_pos)")
	_assert_check(joystick.has_method("calculate_output_vector"), "2.16 VirtualJoystick implements calculate_output_vector(stick_offset)")
	_assert_check(joystick.has_method("calculate_camera_relative_3d"), "2.17 VirtualJoystick implements calculate_camera_relative_3d(input_2d, camera_yaw)")
	_assert_check(joystick.has_method("reset_joystick"), "2.18 VirtualJoystick implements reset_joystick()")

	# =========================================================================
	# SECTION 3: Deadzone Rejection Mathematics (L <= 12 px => Vector2.ZERO)
	# =========================================================================
	print("\n--- Section 3: Deadzone Rejection Mathematics ---")

	# 3.1 Zero offset
	var out_zero = joystick.calculate_output_vector(Vector2.ZERO)
	_assert_check(out_zero == Vector2.ZERO, "3.1 Zero stick offset yields Vector2.ZERO")

	# 3.2 Sub-deadzone offset along X (length = 6 px)
	var out_sub_x = joystick.calculate_output_vector(Vector2(6.0, 0.0))
	_assert_check(out_sub_x == Vector2.ZERO, "3.2 Sub-deadzone offset (6 px) yields Vector2.ZERO")

	# 3.3 Sub-deadzone offset along Y (length = 10 px)
	var out_sub_y = joystick.calculate_output_vector(Vector2(0.0, 10.0))
	_assert_check(out_sub_y == Vector2.ZERO, "3.3 Sub-deadzone offset (10 px) yields Vector2.ZERO")

	# 3.4 Deadzone boundary exact (length = 12.0 px)
	var out_dead_boundary = joystick.calculate_output_vector(Vector2(12.0, 0.0))
	_assert_check(out_dead_boundary == Vector2.ZERO, "3.4 Exact deadzone boundary (12.0 px) rejected to Vector2.ZERO")

	# 3.5 Diagonal deadzone boundary (length = 12.0 px => 8.485, 8.485)
	var diag_dead_vec = Vector2(SQRT1_2 * 12.0, SQRT1_2 * 12.0)
	var out_diag_dead = joystick.calculate_output_vector(diag_dead_vec)
	_assert_check(out_diag_dead == Vector2.ZERO, "3.5 Diagonal deadzone boundary (12.0 px) rejected to Vector2.ZERO")

	# 3.6 Just above deadzone (length = 13.0 px) -> must be active and non-zero
	var out_above_dead = joystick.calculate_output_vector(Vector2(13.0, 0.0))
	_assert_check(out_above_dead != Vector2.ZERO and out_above_dead.x > 0.0,
		"3.6 Offset just above deadzone (13.0 px) produces non-zero output: (%.3f, %.3f)" % [out_above_dead.x, out_above_dead.y])

	# 3.7 Deadzone 3D conversion check
	var out_3d_zero = joystick.calculate_camera_relative_3d(Vector2.ZERO, CAMERA_YAW_45_RAD)
	_assert_check(out_3d_zero == Vector3.ZERO, "3.7 Vector2.ZERO converts to Vector3.ZERO in 3D camera conversion")

	# =========================================================================
	# SECTION 4: Radius Clamping & Linear Scaling Mathematics (R_max = 80 px)
	# =========================================================================
	print("\n--- Section 4: Radius Clamping & Linear Scaling ---")

	var center = Vector2(200.0, 400.0)

	# 4.1 Within radius clamping (no clamp applied)
	var touch_within = center + Vector2(50.0, 0.0)
	var clamped_within = joystick.calculate_clamped_stick_pos(touch_within, center)
	_assert_check(clamped_within.distance_to(center) <= 50.001,
		"4.1 Stick pos within max radius (50 px) is not clamped: dist = %.2f" % clamped_within.distance_to(center))

	# 4.2 Exact boundary (80.0 px)
	var touch_exact = center + Vector2(80.0, 0.0)
	var clamped_exact = joystick.calculate_clamped_stick_pos(touch_exact, center)
	var dist_exact = clamped_exact.distance_to(center)
	_assert_check(abs(dist_exact - 80.0) < 0.01,
		"4.2 Stick pos at exact boundary (80 px) equals max radius: dist = %.2f" % dist_exact)
	var out_exact = joystick.calculate_output_vector(Vector2(80.0, 0.0))
	_assert_check(abs(out_exact.length() - 1.0) < EPSILON,
		"4.3 Output vector at max radius has normalized magnitude 1.0 (actual: %.4f)" % out_exact.length())

	# 4.3 Beyond max radius (140.0 px)
	var touch_exceed = center + Vector2(140.0, 0.0)
	var clamped_exceed = joystick.calculate_clamped_stick_pos(touch_exceed, center)
	var dist_exceed = clamped_exceed.distance_to(center)
	_assert_check(abs(dist_exceed - 80.0) < 0.01,
		"4.4 Stick pos exceeding max radius (140 px) is clamped to exactly 80 px (actual: %.2f)" % dist_exceed)
	var out_exceed = joystick.calculate_output_vector(Vector2(140.0, 0.0))
	_assert_check(abs(out_exceed.length() - 1.0) < EPSILON,
		"4.5 Output vector for exceeding offset maintains normalized magnitude 1.0 (actual: %.4f)" % out_exceed.length())

	# 4.4 Arbitrary diagonal angle clamp (length = 200 px at 30 degrees)
	var angle_rad = deg_to_rad(30.0)
	var touch_diag_exceed = center + Vector2(cos(angle_rad), sin(angle_rad)) * 200.0
	var clamped_diag = joystick.calculate_clamped_stick_pos(touch_diag_exceed, center)
	var dist_diag = clamped_diag.distance_to(center)
	_assert_check(abs(dist_diag - 80.0) < 0.01,
		"4.6 Diagonal offset (200 px @ 30 deg) clamped to 80 px (actual: %.2f)" % dist_diag)

	# 4.5 Linear scaling midpoint test: L = 46.0 px (midway between 12 and 80)
	# Expected magnitude: (46 - 12) / (80 - 12) = 34 / 68 = 0.50
	var out_mid = joystick.calculate_output_vector(Vector2(46.0, 0.0))
	_assert_check(abs(out_mid.length() - 0.50) < 0.02,
		"4.7 Linear scaling at midpoint (L = 46 px) yields ~0.50 magnitude (actual: %.3f)" % out_mid.length())

	# =========================================================================
	# SECTION 5: Directional Transformations & Camera-Relative 3D Mapping
	# =========================================================================
	print("\n--- Section 5: Cardinal & Diagonal 3D Transformations ---")

	# In isometric projection with camera yaw = 45 deg:
	# Right3D = (0.707107, 0, -0.707107)
	# Forward3D = (-0.707107, 0, -0.707107)
	# D_3D = Right3D * I_2D.x + Forward3D * (-I_2D.y)

	# 5.1 Cardinal UP: 2D offset = (0, -80) => I_2D = (0, -1)
	var dir_up_3d = joystick.calculate_camera_relative_3d(Vector2(0.0, -1.0), CAMERA_YAW_45_RAD)
	var exp_up_3d = Vector3(-SQRT1_2, 0.0, -SQRT1_2)
	_assert_check(dir_up_3d.distance_to(exp_up_3d) < EPSILON,
		"5.1 Cardinal UP maps to isometric forward: (%.3f, %.3f, %.3f)" % [dir_up_3d.x, dir_up_3d.y, dir_up_3d.z])

	# 5.2 Cardinal DOWN: 2D offset = (0, 80) => I_2D = (0, 1)
	var dir_down_3d = joystick.calculate_camera_relative_3d(Vector2(0.0, 1.0), CAMERA_YAW_45_RAD)
	var exp_down_3d = Vector3(SQRT1_2, 0.0, SQRT1_2)
	_assert_check(dir_down_3d.distance_to(exp_down_3d) < EPSILON,
		"5.2 Cardinal DOWN maps to isometric backward: (%.3f, %.3f, %.3f)" % [dir_down_3d.x, dir_down_3d.y, dir_down_3d.z])

	# 5.3 Cardinal LEFT: 2D offset = (-80, 0) => I_2D = (-1, 0)
	var dir_left_3d = joystick.calculate_camera_relative_3d(Vector2(-1.0, 0.0), CAMERA_YAW_45_RAD)
	var exp_left_3d = Vector3(-SQRT1_2, 0.0, SQRT1_2)
	_assert_check(dir_left_3d.distance_to(exp_left_3d) < EPSILON,
		"5.3 Cardinal LEFT maps to isometric left: (%.3f, %.3f, %.3f)" % [dir_left_3d.x, dir_left_3d.y, dir_left_3d.z])

	# 5.4 Cardinal RIGHT: 2D offset = (80, 0) => I_2D = (1, 0)
	var dir_right_3d = joystick.calculate_camera_relative_3d(Vector2(1.0, 0.0), CAMERA_YAW_45_RAD)
	var exp_right_3d = Vector3(SQRT1_2, 0.0, -SQRT1_2)
	_assert_check(dir_right_3d.distance_to(exp_right_3d) < EPSILON,
		"5.4 Cardinal RIGHT maps to isometric right: (%.3f, %.3f, %.3f)" % [dir_right_3d.x, dir_right_3d.y, dir_right_3d.z])

	# 5.5 Diagonal UP-RIGHT: 2D offset = (SQRT1_2, -SQRT1_2) => purely along world -Z (North)
	var dir_ur_3d = joystick.calculate_camera_relative_3d(Vector2(SQRT1_2, -SQRT1_2), CAMERA_YAW_45_RAD)
	var exp_ur_3d = Vector3(0.0, 0.0, -1.0)
	_assert_check(dir_ur_3d.distance_to(exp_ur_3d) < EPSILON,
		"5.5 Diagonal UP-RIGHT maps to pure North (-Z): (%.3f, %.3f, %.3f)" % [dir_ur_3d.x, dir_ur_3d.y, dir_ur_3d.z])

	# 5.6 Diagonal UP-LEFT: 2D offset = (-SQRT1_2, -SQRT1_2) => purely along world -X (West)
	var dir_ul_3d = joystick.calculate_camera_relative_3d(Vector2(-SQRT1_2, -SQRT1_2), CAMERA_YAW_45_RAD)
	var exp_ul_3d = Vector3(-1.0, 0.0, 0.0)
	_assert_check(dir_ul_3d.distance_to(exp_ul_3d) < EPSILON,
		"5.6 Diagonal UP-LEFT maps to pure West (-X): (%.3f, %.3f, %.3f)" % [dir_ul_3d.x, dir_ul_3d.y, dir_ul_3d.z])

	# 5.7 Diagonal DOWN-RIGHT: 2D offset = (SQRT1_2, SQRT1_2) => purely along world +X (East)
	var dir_dr_3d = joystick.calculate_camera_relative_3d(Vector2(SQRT1_2, SQRT1_2), CAMERA_YAW_45_RAD)
	var exp_dr_3d = Vector3(1.0, 0.0, 0.0)
	_assert_check(dir_dr_3d.distance_to(exp_dr_3d) < EPSILON,
		"5.7 Diagonal DOWN-RIGHT maps to pure East (+X): (%.3f, %.3f, %.3f)" % [dir_dr_3d.x, dir_dr_3d.y, dir_dr_3d.z])

	# 5.8 Diagonal DOWN-LEFT: 2D offset = (-SQRT1_2, SQRT1_2) => purely along world +Z (South)
	var dir_dl_3d = joystick.calculate_camera_relative_3d(Vector2(-SQRT1_2, SQRT1_2), CAMERA_YAW_45_RAD)
	var exp_dl_3d = Vector3(0.0, 0.0, 1.0)
	_assert_check(dir_dl_3d.distance_to(exp_dl_3d) < EPSILON,
		"5.8 Diagonal DOWN-LEFT maps to pure South (+Z): (%.3f, %.3f, %.3f)" % [dir_dl_3d.x, dir_dl_3d.y, dir_dl_3d.z])

	# 5.9 Vertical axis zeroed: Y component must be strictly 0.0 across all transformations
	_assert_check(dir_up_3d.y == 0.0 and dir_down_3d.y == 0.0 and dir_left_3d.y == 0.0 and dir_right_3d.y == 0.0,
		"5.9 All 3D directional vectors maintain Y = 0.0 (horizontal plane movement only)")

	# =========================================================================
	# SECTION 6: Dynamic Centering & Touch Zone Boundaries
	# =========================================================================
	print("\n--- Section 6: Dynamic Centering & Boundary Acceptance ---")

	# 6.1 Valid touch on left half (e.g. 150, 500)
	var touch_valid = InputEventScreenTouch.new()
	touch_valid.index = 0
	touch_valid.position = Vector2(150.0, 500.0)
	touch_valid.pressed = true

	var handled_valid = joystick.handle_touch_event(touch_valid)
	_assert_check(handled_valid == true, "6.1 Touch-down on left half (150, 500) accepted by joystick")
	_assert_check(joystick.is_active == true, "6.2 Joystick is_active is true after valid touch-down")
	if "center_position" in joystick:
		_assert_check(joystick.center_position.distance_to(Vector2(150.0, 500.0)) < 1.0,
			"6.3 Joystick center dynamically aligned to touch position (150, 500)")

	# Reset
	joystick.reset_joystick()

	# 6.2 Touch on right half (e.g. 500, 600) -> should be rejected
	var touch_right = InputEventScreenTouch.new()
	touch_right.index = 0
	touch_right.position = Vector2(500.0, 600.0)
	touch_right.pressed = true

	var handled_right = joystick.handle_touch_event(touch_right)
	_assert_check(handled_right == false, "6.4 Touch-down on right half (500, 600) rejected by joystick")
	_assert_check(joystick.is_active == false, "6.5 Joystick remains inactive for right half touch")

	# 6.3 Touch in QuickHUD zone (Y < 70, e.g. 150, 40) -> should be rejected
	var touch_top = InputEventScreenTouch.new()
	touch_top.index = 0
	touch_top.position = Vector2(150.0, 40.0)
	touch_top.pressed = true

	var handled_top = joystick.handle_touch_event(touch_top)
	_assert_check(handled_top == false, "6.6 Touch-down in upper QuickHUD area (Y < 70) rejected by joystick")

	# 6.4 Boundary test at X = 360, Y = 70 (exact boundary)
	var touch_boundary = InputEventScreenTouch.new()
	touch_boundary.index = 0
	touch_boundary.position = Vector2(360.0, 70.0)
	touch_boundary.pressed = true

	var handled_boundary = joystick.handle_touch_event(touch_boundary)
	_assert_check(handled_boundary == true, "6.7 Touch-down at exact boundary (360, 70) accepted")

	joystick.reset_joystick()

	# =========================================================================
	# SECTION 7: Multi-Touch Finger Index Isolation
	# =========================================================================
	print("\n--- Section 7: Multi-Touch Finger Isolation ---")

	# 7.1 Start joystick with finger 0
	var touch_f0 = InputEventScreenTouch.new()
	touch_f0.index = 0
	touch_f0.position = Vector2(120.0, 450.0)
	touch_f0.pressed = true
	joystick.handle_touch_event(touch_f0)
	_assert_check(joystick.touch_finger_index == 0, "7.1 Joystick bound to finger index 0")

	# 7.2 Secondary touch from finger 1 (e.g. right side button tap)
	var touch_f1 = InputEventScreenTouch.new()
	touch_f1.index = 1
	touch_f1.position = Vector2(650.0, 1000.0)
	touch_f1.pressed = true
	var handled_f1 = joystick.handle_touch_event(touch_f1)
	_assert_check(handled_f1 == false, "7.2 Finger 1 touch ignored while finger 0 owns joystick")
	_assert_check(joystick.touch_finger_index == 0, "7.3 Active finger index remains 0")

	# 7.3 Secondary drag from finger 1
	var drag_f1 = InputEventScreenDrag.new()
	drag_f1.index = 1
	drag_f1.position = Vector2(660.0, 1010.0)
	var handled_drag_f1 = joystick.handle_touch_event(drag_f1)
	_assert_check(handled_drag_f1 == false, "7.4 Finger 1 drag ignored by joystick")

	# 7.4 Release finger 1 -> joystick should remain active
	var up_f1 = InputEventScreenTouch.new()
	up_f1.index = 1
	up_f1.position = Vector2(660.0, 1010.0)
	up_f1.pressed = false
	var handled_up_f1 = joystick.handle_touch_event(up_f1)
	_assert_check(handled_up_f1 == false, "7.5 Finger 1 touch-up ignored by joystick")
	_assert_check(joystick.is_active == true, "7.6 Joystick remains active after finger 1 release")

	# 7.5 Drag with active finger 0 (drag 80 px UP)
	var drag_f0 = InputEventScreenDrag.new()
	drag_f0.index = 0
	drag_f0.position = Vector2(120.0, 370.0)
	var handled_drag_f0 = joystick.handle_touch_event(drag_f0)
	_assert_check(handled_drag_f0 == true, "7.7 Finger 0 drag processed successfully")
	_assert_check(joystick.output_vector.y < -0.9,
		"7.8 Output vector reflects drag UP: output.y = %.3f" % joystick.output_vector.y)

	# 7.6 Release active finger 0
	var signal_released_emitted: bool = false
	var on_released_callable = func(): signal_released_emitted = true
	joystick.joystick_released.connect(on_released_callable)

	var up_f0 = InputEventScreenTouch.new()
	up_f0.index = 0
	up_f0.position = Vector2(120.0, 370.0)
	up_f0.pressed = false
	var handled_up_f0 = joystick.handle_touch_event(up_f0)

	_assert_check(handled_up_f0 == true, "7.9 Finger 0 touch-up handled successfully")
	_assert_check(joystick.is_active == false, "7.10 Joystick is_active is false after release")
	_assert_check(joystick.touch_finger_index == -1, "7.11 touch_finger_index reset to -1")
	_assert_check(signal_released_emitted == true, "7.12 joystick_released signal emitted on release")
	_assert_check(joystick.output_vector == Vector2.ZERO, "7.13 output_vector zeroed on release")
	_assert_check(joystick.world_direction_3d == Vector3.ZERO, "7.14 world_direction_3d zeroed on release")

	joystick.joystick_released.disconnect(on_released_callable)

	# =========================================================================
	# SECTION 8: Avatar3D Integration & Immediate Zero-Drift Halt
	# =========================================================================
	print("\n--- Section 8: Avatar3D Integration & Stop Movement ---")

	var avatar = avatar_scene.instantiate() as Avatar3D
	root.add_child(avatar)
	avatar.global_position = Vector3(0.0, 0.0, 0.0)
	await process_frame

	# 8.1 Direct verification of Avatar3D.stop_movement()
	avatar.velocity = Vector3(5.0, 0.0, 5.0)
	avatar.set_input_direction(Vector3(1.0, 0.0, 0.0))
	_assert_check(avatar.velocity.length() > 5.0, "8.1 Avatar initially moving with velocity > 5.0 m/s")

	avatar.stop_movement()
	_assert_check(avatar.velocity.x == 0.0 and avatar.velocity.z == 0.0,
		"8.2 Avatar3D.stop_movement() immediately zeroes horizontal velocity: (%.3f, %.3f)" % [avatar.velocity.x, avatar.velocity.z])

	# 8.2 End-to-end Signal Wiring Test: Joystick -> Avatar3D
	var moved_callable = func(dir_3d: Vector3, _raw_2d: Vector2):
		avatar.set_input_direction(dir_3d)
	var stop_callable = func():
		avatar.stop_movement()

	joystick.joystick_moved.connect(moved_callable)
	joystick.joystick_released.connect(stop_callable)

	# Simulate touch down + drag UP-RIGHT (pure North in 3D: Vector3(0, 0, -1))
	var t_down = InputEventScreenTouch.new()
	t_down.index = 0
	t_down.position = Vector2(200.0, 500.0)
	t_down.pressed = true
	joystick.handle_touch_event(t_down)

	var t_drag = InputEventScreenDrag.new()
	t_drag.index = 0
	# Drag offset: +60 px X, -60 px Y
	t_drag.position = Vector2(260.0, 440.0)
	joystick.handle_touch_event(t_drag)

	# Allow avatar physics to step 5 frames
	for _i in range(5):
		await physics_frame

	_assert_check(avatar.velocity.z < -0.5,
		"8.3 Avatar steered North by joystick drag: velocity.z = %.3f m/s" % avatar.velocity.z)

	# Release joystick
	var t_up = InputEventScreenTouch.new()
	t_up.index = 0
	t_up.position = Vector2(260.0, 440.0)
	t_up.pressed = false
	joystick.handle_touch_event(t_up)

	# Assert velocity immediately zeroed without waiting for friction
	_assert_check(abs(avatar.velocity.x) < 0.01 and abs(avatar.velocity.z) < 0.01,
		"8.4 Avatar horizontal velocity zeroed immediately upon joystick release: (%.3f, %.3f)" % [avatar.velocity.x, avatar.velocity.z])

	# Physics step 10 frames to prove zero coasting / drift
	var halt_pos = avatar.global_position
	for _i in range(10):
		await physics_frame
	var post_halt_pos = avatar.global_position
	var drift_dist = halt_pos.distance_to(post_halt_pos)

	_assert_check(drift_dist < 0.005,
		"8.5 Zero coasting drift over 10 physics frames after release: drift = %.5f m" % drift_dist)

	# Clean up signal connections and nodes
	joystick.joystick_moved.disconnect(moved_callable)
	joystick.joystick_released.disconnect(stop_callable)
	joystick.queue_free()
	avatar.queue_free()
	await process_frame
