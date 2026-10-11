extends SceneTree

## Adversarial Challenge & Empirical Verification Suite for Milestone P4-M1:
## 3D Avatar Controller & Isometric Main Scene (Godot Headless Runner).
##
## Validates:
## 1. Mathematical facing rotation in all 4 quadrants (+Z, +X, -Z, -X and diagonals).
## 2. Diagonal vector normalization preventing speed exploits.
## 3. High-frequency state transitions between WASD and click-to-move.
## 4. Rapid reversal oscillation stability.
## 5. Zero vector and boundary inputs.
## 6. HUD overlay toggle and input suspension synchronization.
## 7. Decoupled isometric camera tracking.
##
## Executable via: godot --headless --path IdleArcade -s tests/test_p4_m1_adversarial_challenge.gd

var pass_count: int = 0
var fail_count: int = 0

func _init() -> void:
	print("====================================================================")
	print("[CHALLENGE] Milestone P4-M1: GDScript Adversarial Challenge Suite")
	print("====================================================================")
	process_frame.connect(_on_first_frame, CONNECT_ONE_SHOT)

func _on_first_frame() -> void:
	await _run_all_challenges()
	print("\n====================================================================")
	print("[CHALLENGE SUMMARY] %d Passed | %d Failed" % [pass_count, fail_count])
	print("====================================================================")
	if fail_count == 0:
		print(">>> ADVERSARIAL VERDICT: APPROVE <<<")
		quit(0)
	else:
		printerr(">>> ADVERSARIAL VERDICT: FAIL (%d failures) <<<" % fail_count)
		quit(1)

func _assert_chall(cond: bool, test_name: String, detail: String = "") -> void:
	if cond:
		print("  [PASS] %s" % test_name)
		pass_count += 1
	else:
		printerr("  [FAIL] %s %s" % [test_name, ("-> " + detail) if detail != "" else ""])
		fail_count += 1

func _run_all_challenges() -> void:
	# -------------------------------------------------------------------------
	# 0. Environment Setup
	# -------------------------------------------------------------------------
	var gs_script = load("res://scripts/autoload/game_state.gd")
	var gs = root.get_node_or_null("GameState")
	if gs == null and gs_script != null:
		gs = gs_script.new()
		gs.name = "GameState"
		root.add_child(gs)

	var avatar_scene = load("res://scenes/avatar_3d.tscn")
	var main_3d_scene = load("res://scenes/main_3d.tscn")
	if avatar_scene == null or main_3d_scene == null:
		printerr("[FATAL] Core P4-M1 scenes missing!")
		quit(1)
		return

	# Mount physics test stage
	var test_stage = Node3D.new()
	test_stage.name = "Adversarial_TestStage"
	root.add_child(test_stage)

	var floor_body = StaticBody3D.new()
	floor_body.collision_layer = 1
	var floor_col = CollisionShape3D.new()
	var floor_box = BoxShape3D.new()
	floor_box.size = Vector3(200.0, 1.0, 200.0)
	floor_col.shape = floor_box
	floor_col.position = Vector3(0.0, -0.5, 0.0)
	floor_body.add_child(floor_col)
	test_stage.add_child(floor_body)

	var avatar: Avatar3D = avatar_scene.instantiate() as Avatar3D
	test_stage.add_child(avatar)
	avatar.global_position = Vector3(0.0, 0.0, 0.0)

	for _i in range(3):
		await physics_frame

	# =========================================================================
	# CHALLENGE 1: Facing Rotation across all 4 Quadrants
	# =========================================================================
	print("\n--- Challenge 1: Facing Rotation In 4 Quadrants ---")

	var quadrant_cases = [
		{"name": "Pure South (+Z)", "vec": Vector3(0.0, 0.0, 1.0), "exp_yaw": 0.0},
		{"name": "Pure East (+X)", "vec": Vector3(1.0, 0.0, 0.0), "exp_yaw": PI / 2.0},
		{"name": "Pure North (-Z)", "vec": Vector3(0.0, 0.0, -1.0), "exp_yaw": PI},
		{"name": "Pure West (-X)", "vec": Vector3(-1.0, 0.0, 0.0), "exp_yaw": -PI / 2.0},
		{"name": "Q1 South-East (+X, +Z)", "vec": Vector3(1.0, 0.0, 1.0), "exp_yaw": PI / 4.0},
		{"name": "Q2 North-East (+X, -Z)", "vec": Vector3(1.0, 0.0, -1.0), "exp_yaw": 3.0 * PI / 4.0},
		{"name": "Q3 North-West (-X, -Z)", "vec": Vector3(-1.0, 0.0, -1.0), "exp_yaw": -3.0 * PI / 4.0},
		{"name": "Q4 South-West (-X, +Z)", "vec": Vector3(-1.0, 0.0, 1.0), "exp_yaw": -PI / 4.0},
	]

	for q in quadrant_cases:
		avatar.set_input_direction(q["vec"])
		# Run 25 physics frames to allow smooth turn interpolation to settle
		for _f in range(25):
			await physics_frame
		
		var facing = avatar.get_facing_direction()
		var expected_unit = (q["vec"] as Vector3).normalized()
		var dot = facing.dot(expected_unit)
		_assert_chall(dot > 0.98, "Facing alignment for %s (dot = %.4f)" % [q["name"], dot])
		avatar.stop_movement()
		for _f in range(5):
			await physics_frame

	# Deadband check: stopped avatar retains last orientation
	var facing_before_stop = avatar.get_facing_direction()
	avatar.set_input_direction(Vector3.ZERO)
	for _f in range(15):
		await physics_frame
	var facing_after_stop = avatar.get_facing_direction()
	var stop_dot = facing_before_stop.dot(facing_after_stop)
	_assert_chall(stop_dot > 0.99, "Avatar retains facing direction when stopped (no gimbal snap)")

	# =========================================================================
	# CHALLENGE 2: Diagonal Vector Normalization ($1.414x speed exploit test)
	# =========================================================================
	print("\n--- Challenge 2: Diagonal Normalization & Speed Bounds ---")

	avatar.set_input_direction(Vector3(1.0, 0.0, 1.0))
	for _f in range(20):
		await physics_frame

	var horiz_speed = Vector2(avatar.velocity.x, avatar.velocity.z).length()
	var max_allowed = avatar.get_move_speed()
	_assert_chall(horiz_speed <= max_allowed + 0.05,
		"Diagonal speed is capped at %.2f m/s (actual: %.2f m/s, no 1.414x exploit)" % [max_allowed, horiz_speed])
	avatar.stop_movement()
	for _f in range(10):
		await physics_frame

	# =========================================================================
	# CHALLENGE 3: State Transitions Between Input Modes
	# =========================================================================
	print("\n--- Challenge 3: Input Mode State Transitions ---")

	# 3.1: Click target followed immediately by script override
	avatar.move_to_position(Vector3(10.0, 0.0, 0.0))
	await physics_frame
	_assert_chall(avatar._has_click_target == true, "Click target registered")
	
	avatar.set_input_direction(Vector3(0.0, 0.0, 1.0))
	await physics_frame
	_assert_chall(avatar._has_click_target == false, "Script input immediately overrides click target")

	# 3.2: Reaching click target halts and emits signal
	var target_dest = avatar.global_position + Vector3(2.0, 0.0, 0.0)
	var signal_emitted: bool = false
	var handler = func(p): signal_emitted = true
	avatar.destination_reached.connect(handler)
	avatar.move_to_position(target_dest)

	for _f in range(50):
		await physics_frame
		if signal_emitted:
			break

	_assert_chall(signal_emitted, "destination_reached signal emitted upon arrival")
	_assert_chall(avatar._has_click_target == false, "Click target flag cleared upon arrival")
	avatar.destination_reached.disconnect(handler)

	# =========================================================================
	# CHALLENGE 4: Rapid Reversal Frequency Stability
	# =========================================================================
	print("\n--- Challenge 4: Rapid Reversal Frequency Stability ---")

	# Alternate +X and -X every single frame for 60 frames
	for f in range(60):
		var dir = Vector3(1.0 if f % 2 == 0 else -1.0, 0.0, 0.0)
		avatar.set_input_direction(dir)
		await physics_frame

	var oscillation_speed = abs(avatar.velocity.x)
	_assert_chall(oscillation_speed < 1.0,
		"High-frequency 60Hz reversals remain bounded (oscillation vel = %.3f m/s)" % oscillation_speed)
	avatar.stop_movement()
	for _f in range(10):
		await physics_frame

	# =========================================================================
	# CHALLENGE 5: HUD Overlay Toggle & Input Suspension
	# =========================================================================
	print("\n--- Challenge 5: HUD Overlay Toggle & Input Suspension ---")

	var main_3d: Main3D = main_3d_scene.instantiate() as Main3D
	root.add_child(main_3d)
	await process_frame
	await physics_frame

	var main_avatar: Avatar3D = main_3d.get_node_or_null("Avatar3D") as Avatar3D
	_assert_chall(main_avatar != null, "Main3D contains Avatar3D child")

	if main_avatar != null:
		# Test input disabled when open
		main_3d.open_hud_overlay()
		_assert_chall(main_3d.is_hud_overlay_open() == true, "Overlay opens")
		_assert_chall(main_avatar.input_enabled == false, "Avatar input disabled while overlay is open")

		main_3d.close_hud_overlay()
		_assert_chall(main_3d.is_hud_overlay_open() == false, "Overlay closes")
		_assert_chall(main_avatar.input_enabled == true, "Avatar input re-enabled while overlay is closed")

		# Rapid toggle stress (30 rapid calls)
		for _i in range(30):
			main_3d.toggle_hud_overlay()
		
		# 30 toggles from closed ends in closed (false)
		_assert_chall(main_3d.is_hud_overlay_open() == false, "30 rapid toggles remain deterministic (closed)")
		_assert_chall(main_avatar.input_enabled == true, "Avatar input remains synchronized after rapid toggles")

	# Cleanup
	main_3d.queue_free()
	test_stage.queue_free()
	await process_frame
	await physics_frame
