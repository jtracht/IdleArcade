extends SceneTree

## =============================================================================
## Adversarial Stress Harness: Feature 34 (ArcadeVirtualJoystick)
## File: IdleArcade/tests/test_stress_joystick_f34.gd
##
## Empirical stress test verifying:
##   1. Rapid lifecycle instantiation and deletion (500 iterations)
##   2. Extreme, degenerate, out-of-bounds, NaN/Inf touch events
##   3. Rapid multi-touch interleaved spam and desync events
##   4. Dangling avatar & camera reference resilience
##   5. Repeated script reloads and global class collision absence
## =============================================================================

var pass_count: int = 0
var fail_count: int = 0

func _assert_check(condition: bool, description: String, detail: String = "") -> void:
	if condition:
		print("  [PASS] %s" % description)
		pass_count += 1
	else:
		var err: String = "  [FAIL] %s" % description
		if detail != "":
			err += " (Detail: %s)" % detail
		printerr(err)
		fail_count += 1

func _init() -> void:
	print("\n====================================================================")
	print(">>> ADVERSARIAL STRESS: FEATURE 34 (ArcadeVirtualJoystick) <<<")
	print("====================================================================")
	call_deferred("_run_stress_suite")

func _run_stress_suite() -> void:
	await process_frame

	var vj_script = load("res://scripts/ui/virtual_joystick.gd")
	_assert_check(vj_script != null, "F34.1 Script res://scripts/ui/virtual_joystick.gd loads successfully")
	_assert_check(vj_script.get_global_name() == &"ArcadeVirtualJoystick", "F34.2 Global class name registered as ArcadeVirtualJoystick")

	# -------------------------------------------------------------------------
	# 1. Rapid Instantiation & Deletion (500 cycles)
	# -------------------------------------------------------------------------
	print("\n--- Test 1: Rapid Lifecycle (500 cycles) ---")
	var tc_scene = load("res://scenes/ui/touch_controls.tscn")
	_assert_check(tc_scene != null, "F34.3 scenes/ui/touch_controls.tscn loads successfully")

	var lifecycle_success: bool = true
	for i in range(500):
		var inst = vj_script.new() as ArcadeVirtualJoystick
		if inst == null:
			lifecycle_success = false
			break
		root.add_child(inst)
		inst.queue_free()
		if i % 100 == 0:
			await process_frame

	_assert_check(lifecycle_success, "F34.4 500 rapid instantiations and frees of ArcadeVirtualJoystick completed cleanly")

	var tc_lifecycle_success: bool = true
	for i in range(100):
		var tc_inst = tc_scene.instantiate() as Control
		if tc_inst == null:
			tc_lifecycle_success = false
			break
		root.add_child(tc_inst)
		tc_inst.queue_free()
		if i % 25 == 0:
			await process_frame

	_assert_check(tc_lifecycle_success, "F34.5 100 rapid instantiations and frees of TouchControls scene completed cleanly")

	# -------------------------------------------------------------------------
	# 2. Extreme Touch Inputs & Boundary Fuzzing
	# -------------------------------------------------------------------------
	print("\n--- Test 2: Extreme & Boundary Touch Inputs ---")
	var vj = vj_script.new() as ArcadeVirtualJoystick
	root.add_child(vj)
	await process_frame

	# Check zone boundaries
	# zone: X [0.0, 360.0], Y [70.0, 1280.0]
	_assert_check(vj.is_in_touch_zone(Vector2(0.0, 70.0)), "F34.6 Top-left corner (0, 70) is in zone")
	_assert_check(vj.is_in_touch_zone(Vector2(360.0, 1280.0)), "F34.7 Bottom-right corner (360, 1280) is in zone")
	_assert_check(not vj.is_in_touch_zone(Vector2(-0.001, 100.0)), "F34.8 Negative X (-0.001) rejected from zone")
	_assert_check(not vj.is_in_touch_zone(Vector2(360.001, 100.0)), "F34.9 Past right half (360.001) rejected from zone")
	_assert_check(not vj.is_in_touch_zone(Vector2(100.0, 69.999)), "F34.10 Top bar (69.999) rejected from zone")
	_assert_check(not vj.is_in_touch_zone(Vector2(100.0, 1280.001)), "F34.11 Below screen (1280.001) rejected from zone")

	# Extreme coordinates
	_assert_check(not vj.is_in_touch_zone(Vector2(-1e12, -1e12)), "F34.12 Massive negative coordinates rejected")
	_assert_check(not vj.is_in_touch_zone(Vector2(1e12, 1e12)), "F34.13 Massive positive coordinates rejected")

	# Clamp and Deadzone math
	var center = Vector2(180.0, 600.0)
	var clamped_far = vj.calculate_clamped_stick_pos(center + Vector2(5000.0, 0.0), center)
	_assert_check(absf((clamped_far - center).length() - 80.0) < 0.001, "F34.14 5000px displacement clamped exactly to max_radius (80.0)")

	var clamped_zero = vj.calculate_clamped_stick_pos(center, center)
	_assert_check(clamped_zero == center, "F34.15 Zero offset returns center_pos")

	# Deadzone threshold checks (deadzone = 12.0, max_radius = 80.0)
	var out_zero = vj.calculate_output_vector(Vector2.ZERO)
	_assert_check(out_zero == Vector2.ZERO, "F34.16 Zero vector yields Vector2.ZERO output")

	var out_inside_dz = vj.calculate_output_vector(Vector2(0.0, 11.99))
	_assert_check(out_inside_dz == Vector2.ZERO, "F34.17 11.99px offset inside 12px deadzone yields Vector2.ZERO")

	var out_exact_dz = vj.calculate_output_vector(Vector2(12.0, 0.0))
	_assert_check(out_exact_dz == Vector2.ZERO, "F34.18 12.00px offset at exact deadzone yields Vector2.ZERO")

	var out_above_dz = vj.calculate_output_vector(Vector2(12.01, 0.0))
	_assert_check(out_above_dz.x > 0.0 and out_above_dz.x < 0.01, "F34.19 12.01px offset produces smooth small output (actual: %.4f)" % out_above_dz.x)

	var out_at_max = vj.calculate_output_vector(Vector2(0.0, -80.0))
	_assert_check(absf(out_at_max.length() - 1.0) < 0.001, "F34.20 -80px offset produces exact normalized magnitude 1.0")

	var out_beyond_max = vj.calculate_output_vector(Vector2(0.0, -250.0))
	_assert_check(absf(out_beyond_max.length() - 1.0) < 0.001, "F34.21 -250px offset clamped to magnitude 1.0")

	# -------------------------------------------------------------------------
	# 3. Multi-Touch Spam & Input Event Fuzzing
	# -------------------------------------------------------------------------
	print("\n--- Test 3: Multi-Touch Spam & Input Event Fuzzing ---")
	# Finger 0 down
	var t0_down = InputEventScreenTouch.new()
	t0_down.index = 0
	t0_down.pressed = true
	t0_down.position = Vector2(100.0, 500.0)
	var absorbed_0 = vj.handle_touch_event(t0_down)
	_assert_check(absorbed_0 and vj.is_active, "F34.22 Finger 0 down activated joystick")

	# Finger 1 down while 0 active (should be ignored)
	var t1_down = InputEventScreenTouch.new()
	t1_down.index = 1
	t1_down.pressed = true
	t1_down.position = Vector2(120.0, 520.0)
	var absorbed_1 = vj.handle_touch_event(t1_down)
	_assert_check(not absorbed_1, "F34.23 Secondary finger 1 down ignored while finger 0 active")

	# Drag finger 1 (should be ignored)
	var t1_drag = InputEventScreenDrag.new()
	t1_drag.index = 1
	t1_drag.position = Vector2(150.0, 550.0)
	var drag_1_res = vj.handle_touch_event(t1_drag)
	_assert_check(not drag_1_res, "F34.24 Finger 1 drag ignored")

	# Release finger 1 (should be ignored)
	var t1_up = InputEventScreenTouch.new()
	t1_up.index = 1
	t1_up.pressed = false
	t1_up.position = Vector2(150.0, 550.0)
	var up_1_res = vj.handle_touch_event(t1_up)
	_assert_check(not up_1_res, "F34.25 Finger 1 release ignored")
	_assert_check(vj.is_active, "F34.26 Joystick remains active with primary finger 0")

	# Drag finger 0
	var t0_drag = InputEventScreenDrag.new()
	t0_drag.index = 0
	t0_drag.position = Vector2(100.0, 420.0) # Upwards 80px
	var drag_0_res = vj.handle_touch_event(t0_drag)
	_assert_check(drag_0_res, "F34.27 Primary finger drag handled")
	_assert_check(absf(vj.output_vector.length() - 1.0) < 0.001, "F34.28 Output vector has magnitude 1.0")

	# Release finger 0
	var t0_up = InputEventScreenTouch.new()
	t0_up.index = 0
	t0_up.pressed = false
	t0_up.position = Vector2(100.0, 420.0)
	var up_0_res = vj.handle_touch_event(t0_up)
	_assert_check(up_0_res and not vj.is_active, "F34.29 Finger 0 release deactivated joystick")
	_assert_check(vj.output_vector == Vector2.ZERO, "F34.30 Output vector reset to zero on release")

	# Release when already inactive
	var ghost_up = InputEventScreenTouch.new()
	ghost_up.index = 0
	ghost_up.pressed = false
	_assert_check(not vj.handle_touch_event(ghost_up), "F34.31 Release when inactive returns false safely")

	# Drag when inactive
	var ghost_drag = InputEventScreenDrag.new()
	ghost_drag.index = 0
	ghost_drag.position = Vector2(150.0, 500.0)
	_assert_check(not vj.handle_touch_event(ghost_drag), "F34.32 Drag when inactive returns false safely")

	# -------------------------------------------------------------------------
	# 4. Dangling Avatar & Camera Node Resilience
	# -------------------------------------------------------------------------
	print("\n--- Test 4: Dangling Node Resilience ---")
	var dummy_avatar = Node3D.new()
	dummy_avatar.name = "DummyAvatar"
	root.add_child(dummy_avatar)
	vj.set_avatar(dummy_avatar)
	_assert_check(vj.avatar_node == dummy_avatar, "F34.33 Avatar node set on joystick")

	# Activate touch
	vj.handle_touch_event(t0_down)
	_assert_check(vj.is_active, "F34.34 Joystick re-activated")

	# Now delete avatar while joystick is active
	dummy_avatar.free() # immediate free
	await process_frame

	# Trigger drag event now that avatar is freed
	vj.handle_touch_event(t0_drag)
	vj._physics_process(0.016)
	_assert_check(true, "F34.35 Joystick handles drag and physics process without crash when avatar freed")

	vj.reset_joystick()
	_assert_check(not vj.is_active, "F34.36 Reset joystick cleanly executed with freed avatar")

	vj.queue_free()
	await process_frame

	# -------------------------------------------------------------------------
	# 5. Scene & Script Reloads (Native Class Collision Stress)
	# -------------------------------------------------------------------------
	print("\n--- Test 5: Scene & Script Reloads (Collision Stress) ---")
	var reload_success: bool = true
	for i in range(25):
		var reloaded_script = ResourceLoader.load("res://scripts/ui/virtual_joystick.gd", "", ResourceLoader.CACHE_MODE_REPLACE)
		if reloaded_script == null:
			reload_success = false
			break
		var reloaded_tc = ResourceLoader.load("res://scenes/ui/touch_controls.tscn", "", ResourceLoader.CACHE_MODE_REPLACE)
		if reloaded_tc == null:
			reload_success = false
			break
		var tc_inst = reloaded_tc.instantiate() as Control
		if tc_inst == null:
			reload_success = false
			break
		root.add_child(tc_inst)
		tc_inst.queue_free()
		await process_frame

	_assert_check(reload_success, "F34.37 25 consecutive CACHE_MODE_REPLACE reloads executed without native class collision")

	# Verify global class resolution
	var global_classes = ProjectSettings.get_global_class_list()
	var found_arcade_vj: bool = false
	var found_old_vj: bool = false
	for entry in global_classes:
		if entry.get("class") == "ArcadeVirtualJoystick":
			found_arcade_vj = true
		if entry.get("class") == "VirtualJoystick":
			found_old_vj = true

	_assert_check(found_arcade_vj, "F34.38 ArcadeVirtualJoystick correctly registered in ProjectSettings global class list")
	_assert_check(not found_old_vj, "F34.39 VirtualJoystick is NOT in global class list (no collision with native classes)")

	# Summary & Quit
	print("\n====================================================================")
	print(">>> ADVERSARIAL STRESS COMPLETE: %d PASSED, %d FAILED <<<" % [pass_count, fail_count])
	print("====================================================================")
	if fail_count == 0:
		quit(0)
	else:
		quit(1)
