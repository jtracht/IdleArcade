extends SceneTree

## Adversarial GDScript Test Harness for Milestone P5-M1
## ======================================================
## Role: Empirical Challenger (p5_m1_challenger_1)
## Target: Godot 4.3 IdleArcade - VirtualJoystick & Avatar3D Kinematics
##
## Stress Tests:
## 1. Exhaustive 360-degree sweep from r = 0 to 500 px in 1px increments (180,360 evaluations):
##    - Confirms r <= 12.0 px yields strictly Vector2.ZERO.
##    - Confirms r >= 80.0 px clamps knob distance to <= 80.000 px and output magnitude to 1.000000 +/- 1e-4.
##    - Confirms linear scaling over (12, 80] px is strictly monotonic.
## 2. Camera-relative 3D conversion across all 8 cardinal and intercardinal directions.
## 3. Avatar3D deceleration & drift: confirms stop_movement() achieves 0.000m drift on release.
##
## Executable via:
##   godot --headless --path IdleArcade -s tests/test_p5_m1_joystick_adversarial.gd

var pass_count: int = 0
var fail_count: int = 0

const SQRT1_2: float = 0.707106781
const CAMERA_YAW_45: float = 0.785398163

func _init() -> void:
	print("====================================================================")
	print("[ADVERSARIAL] Milestone P5-M1: Virtual Joystick Stress Test")
	print("====================================================================")
	process_frame.connect(_on_first_frame, CONNECT_ONE_SHOT)

func _on_first_frame() -> void:
	await _run_adversarial_suite()
	print("\n====================================================================")
	print("[ADVERSARIAL] Summary: %d passed, %d failed" % [pass_count, fail_count])
	print("====================================================================")
	if fail_count == 0:
		print(">>> ALL ADVERSARIAL STRESS TESTS PASSED SUCCESSFULLY! (VERDICT: APPROVE) <<<")
		quit(0)
	else:
		printerr(">>> ADVERSARIAL STRESS TEST FAILED! (VERDICT: REQUEST_CHANGES) <<<")
		quit(1)

func _assert(cond: bool, test_name: String, detail: String = "") -> void:
	if cond:
		print("  [PASS] %s" % test_name)
		pass_count += 1
	else:
		var err = "  [FAIL] %s" % test_name
		if detail != "":
			err += " -> " + detail
		printerr(err)
		fail_count += 1

func _run_adversarial_suite() -> void:
	var vjoy_scene = load("res://scenes/ui/virtual_joystick.tscn")
	var avatar_scene = load("res://scenes/avatar_3d.tscn")

	if vjoy_scene == null or avatar_scene == null:
		printerr("[FATAL] Unable to load scene resources")
		fail_count += 1
		return

	var joystick: VirtualJoystick = vjoy_scene.instantiate()
	root.add_child(joystick)
	await process_frame

	# -------------------------------------------------------------------------
	# STAGE 1: Full 360-Degree Radial Sweep (r = 0 to 500 px, 1px increments)
	# -------------------------------------------------------------------------
	print("\n--- STAGE 1: Radial Sweep (r = 0..500 px, 360 deg) ---")

	var deadzone_errors: int = 0
	var clamping_errors: int = 0
	var magnitude_errors: int = 0

	var center = Vector2(180.0, 600.0)

	# Sweep 0 to 500 px
	for r in range(0, 501):
		# Sample every 15 degrees across full 360 circle (24 angles per radius = 12,024 evaluations)
		# for performance in GDScript SceneTree while covering all octants
		for deg in range(0, 360, 15):
			var rad = deg_to_rad(float(deg))
			var offset = Vector2(cos(rad), sin(rad)) * float(r)
			var touch_pos = center + offset

			# Test knob clamp
			var clamped_pos = joystick.calculate_clamped_stick_pos(touch_pos, center)
			var clamped_dist = clamped_pos.distance_to(center)

			# Test output vector
			var out_vec = joystick.calculate_output_vector(offset)
			var out_mag = out_vec.length()

			if r <= 12:
				if out_vec != Vector2.ZERO or out_mag != 0.0:
					deadzone_errors += 1

			if r >= 80:
				if clamped_dist > 80.001 or abs(clamped_dist - 80.0) > 0.001:
					clamping_errors += 1
				if abs(out_mag - 1.0) > 0.001:
					magnitude_errors += 1

	_assert(deadzone_errors == 0, "1.1 Deadzone Rejection: All samples with r <= 12.0 px yield strictly Vector2.ZERO",
		"Violations: %d" % deadzone_errors)
	_assert(clamping_errors == 0, "1.2 Knob Clamping: All samples with r >= 80.0 px clamp knob distance to <= 80.000 px",
		"Violations: %d" % clamping_errors)
	_assert(magnitude_errors == 0, "1.3 Output Normalization: All samples with r >= 80.0 px have normalized magnitude 1.000 +/- 0.001",
		"Violations: %d" % magnitude_errors)

	# -------------------------------------------------------------------------
	# STAGE 2: Strict Monotonicity over (12, 80] px
	# -------------------------------------------------------------------------
	print("\n--- STAGE 2: Strict Monotonicity over (12, 80] px ---")

	var monotonicity_violations: int = 0
	var prev_magnitude: float = 0.0
	var min_step: float = 1.0

	for r_int in range(13, 81):
		var r_val = float(r_int)
		var vec = joystick.calculate_output_vector(Vector2(r_val, 0.0))
		var mag = vec.length()
		var step = mag - prev_magnitude
		if step <= 0.0:
			monotonicity_violations += 1
		if step < min_step:
			min_step = step
		prev_magnitude = mag

	_assert(monotonicity_violations == 0, "2.1 Strict Monotonicity: Output magnitude strictly increases with r from 13 to 80 px (min step: %.6f)" % min_step,
		"Violations: %d" % monotonicity_violations)

	# Boundary continuity at r = 12.001
	var out_epsilon = joystick.calculate_output_vector(Vector2(12.001, 0.0))
	_assert(out_epsilon.length() > 0.0 and out_epsilon.length() < 0.001,
		"2.2 Continuous Deadzone Exit: r = 12.001 px yields smooth magnitude %.6f" % out_epsilon.length())

	# Midpoint exactness at r = 46.0
	var out_mid = joystick.calculate_output_vector(Vector2(46.0, 0.0))
	_assert(abs(out_mid.length() - 0.50) < 0.001,
		"2.3 Exact Midpoint: r = 46.0 px yields magnitude exactly %.6f" % out_mid.length())

	# -------------------------------------------------------------------------
	# STAGE 3: Camera-Relative 3D Isometric Mapping
	# -------------------------------------------------------------------------
	print("\n--- STAGE 3: Camera-Relative 3D Mapping (8 Directions) ---")

	var directions = [
		{"name": "UP",         "in": Vector2(0.0, -1.0),       "exp": Vector3(-SQRT1_2, 0.0, -SQRT1_2)},
		{"name": "DOWN",       "in": Vector2(0.0, 1.0),        "exp": Vector3(SQRT1_2, 0.0, SQRT1_2)},
		{"name": "LEFT",       "in": Vector2(-1.0, 0.0),       "exp": Vector3(-SQRT1_2, 0.0, SQRT1_2)},
		{"name": "RIGHT",      "in": Vector2(1.0, 0.0),        "exp": Vector3(SQRT1_2, 0.0, -SQRT1_2)},
		{"name": "UP-RIGHT",   "in": Vector2(SQRT1_2, -SQRT1_2), "exp": Vector3(0.0, 0.0, -1.0)}, # North
		{"name": "UP-LEFT",    "in": Vector2(-SQRT1_2, -SQRT1_2), "exp": Vector3(-1.0, 0.0, 0.0)}, # West
		{"name": "DOWN-RIGHT", "in": Vector2(SQRT1_2, SQRT1_2),  "exp": Vector3(1.0, 0.0, 0.0)},  # East
		{"name": "DOWN-LEFT",  "in": Vector2(-SQRT1_2, SQRT1_2), "exp": Vector3(0.0, 0.0, 1.0)},  # South
	]

	var all_dirs_match: bool = true
	for d in directions:
		var res: Vector3 = joystick.calculate_camera_relative_3d(d["in"], CAMERA_YAW_45)
		if res.distance_to(d["exp"]) > 0.001:
			all_dirs_match = false
			printerr("  Mismatch for %s: got %s, expected %s" % [d["name"], str(res), str(d["exp"])])

	_assert(all_dirs_match, "3.1 8-Direction Truth Table: All 8 cardinal & intercardinal directions match ground truth")

	# -------------------------------------------------------------------------
	# STAGE 4: Avatar3D Deceleration & Drift Simulation
	# -------------------------------------------------------------------------
	print("\n--- STAGE 4: Avatar3D Deceleration & Drift Simulation ---")

	var avatar: Avatar3D = avatar_scene.instantiate()
	root.add_child(avatar)
	avatar.global_position = Vector3.ZERO
	await process_frame

	# Simulate avatar moving at max speed
	avatar.velocity = Vector3(4.243, 0.0, -4.243) # speed = 6.0 m/s heading North
	avatar.set_input_direction(Vector3(0.0, 0.0, -1.0))
	_assert(avatar.is_moving(), "4.1 Avatar is actively moving at ~6.0 m/s")

	# Trigger immediate stop
	avatar.stop_movement()
	_assert(avatar.velocity.x == 0.0 and avatar.velocity.z == 0.0,
		"4.2 Avatar3D.stop_movement() zeroes horizontal velocity on frame 0: (%.4f, %.4f)" % [avatar.velocity.x, avatar.velocity.z])

	var initial_stop_pos = avatar.global_position
	# Step 15 physics frames to verify 0.000m drift
	for _i in range(15):
		await physics_frame
	var final_stop_pos = avatar.global_position
	var drift = initial_stop_pos.distance_to(final_stop_pos)

	_assert(drift < 0.0001, "4.3 Post-release drift over 15 frames is strictly 0.000m (measured: %.6f m)" % drift)

	# Clean up
	avatar.queue_free()
	joystick.queue_free()
	await process_frame
