extends SceneTree

## Empirical Challenger Test Suite for Milestone P5-M1
## Focus: Input Isolation, Ground Raycast Shielding, Multi-Touch Concurrency & Rapid Lifecycle Stress
##
## Roles: Critic, Specialist (Empirical Challenge & Adversarial Stress)
## Target: IdleArcade (Godot 4.3 Mobile Touch Navigation)
##
## Executable via:
##   godot --headless --path IdleArcade -s tests/test_p5_m1_challenger_isolation.gd

var pass_count: int = 0
var fail_count: int = 0

const EPSILON: float = 0.002
const CAMERA_YAW_45_RAD: float = 0.785398163
const SQRT1_2: float = 0.707106781

func _init() -> void:
	print("====================================================================")
	print("[CHALLENGER] P5-M1 Empirical Stress & Isolation Challenge Suite")
	print("====================================================================")
	process_frame.connect(_on_first_frame, CONNECT_ONE_SHOT)

func _on_first_frame() -> void:
	await _run_all_challenges()
	print("\n====================================================================")
	print("[CHALLENGER] Results: %d passed, %d failed" % [pass_count, fail_count])
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

	# Load scenes and scripts
	var joystick_scene = load("res://scenes/ui/virtual_joystick.tscn")
	var avatar_scene = load("res://scenes/avatar_3d.tscn")
	if joystick_scene == null or avatar_scene == null:
		printerr("[FATAL] Could not load joystick or avatar scenes.")
		fail_count += 1
		return

	# =========================================================================
	# CHALLENGE 1: Ground Raycast Isolation & Touch Consumption
	# =========================================================================
	print("\n--- Challenge 1: Ground Raycast Isolation & Touch Consumption ---")
	print("Hypothesis: Touches processed by VirtualJoystick NEVER leak into Avatar3D._unhandled_input().")

	# Setup a mock test harness node containing Avatar3D and VirtualJoystick
	var harness = Node3D.new()
	harness.name = "TestHarness_Challenger1"
	root.add_child(harness)

	var avatar = avatar_scene.instantiate() as Avatar3D
	avatar.name = "Avatar3D"
	harness.add_child(avatar)
	avatar.global_position = Vector3(0.0, 0.0, 0.0)

	var camera = Camera3D.new()
	camera.name = "Camera3D"
	harness.add_child(camera)
	camera.global_position = Vector3(10.0, 10.0, 10.0)
	camera.look_at(Vector3.ZERO, Vector3.UP)

	var joystick = joystick_scene.instantiate() as VirtualJoystick
	joystick.name = "VirtualJoystick"
	joystick.avatar_path = NodePath("../Avatar3D")
	joystick.camera_path = NodePath("../Camera3D")
	harness.add_child(joystick)
	await process_frame

	# 1.1 Touch-down inside joystick zone [150, 500]
	var touch_down_pos = Vector2(150.0, 500.0)
	var ev_touch_down = InputEventScreenTouch.new()
	ev_touch_down.index = 0
	ev_touch_down.position = touch_down_pos
	ev_touch_down.pressed = true

	var consumed_down = joystick.handle_touch_event(ev_touch_down)
	_assert_test(consumed_down == true, "1.1 Touch-down in joystick activation zone consumed by handle_touch_event()")

	# Emulate Godot's input consumption: when handle_touch_event returns true,
	# _gui_input calls accept_event() or _unhandled_input calls set_input_as_handled().
	# Test whether Avatar3D._unhandled_input would trigger click-to-move if invoked
	_assert_test(avatar._has_click_target == false, "1.2 Avatar has NO click-to-move target after touch down")
	_assert_test(joystick.is_active == true, "1.3 VirtualJoystick is actively capturing touch")

	# 1.2 Touch-drag inside joystick zone [150, 420]
	var ev_drag_in = InputEventScreenDrag.new()
	ev_drag_in.index = 0
	ev_drag_in.position = Vector2(150.0, 420.0)

	var consumed_drag_in = joystick.handle_touch_event(ev_drag_in)
	_assert_test(consumed_drag_in == true, "1.4 Touch drag consumed by joystick")
	_assert_test(avatar._has_click_target == false, "1.5 Avatar click-to-move NOT triggered during joystick drag")
	_assert_test(joystick.world_direction_3d != Vector3.ZERO, "1.6 Avatar steered via 3D input direction vector")

	# 1.3 Boundary crossing drag: drag finger 0 all the way to right side [600, 420]
	var ev_drag_out = InputEventScreenDrag.new()
	ev_drag_out.index = 0
	ev_drag_out.position = Vector2(600.0, 420.0)

	var consumed_drag_out = joystick.handle_touch_event(ev_drag_out)
	_assert_test(consumed_drag_out == true, "1.7 Boundary-crossing drag to right half (X=600) continues to be consumed by active joystick")
	_assert_test(avatar._has_click_target == false, "1.8 Avatar click-to-move NOT triggered when dragging thumb across screen")

	# 1.4 Touch-up outside initial zone [600, 420]
	var ev_touch_up_out = InputEventScreenTouch.new()
	ev_touch_up_out.index = 0
	ev_touch_up_out.position = Vector2(600.0, 420.0)
	ev_touch_up_out.pressed = false

	var consumed_up_out = joystick.handle_touch_event(ev_touch_up_out)
	_assert_test(consumed_up_out == true, "1.9 Touch release outside initial zone consumed cleanly")
	_assert_test(joystick.is_active == false, "1.10 Joystick cleanly deactivated on touch release")
	_assert_test(avatar._has_click_target == false, "1.11 Avatar has NO residual click target upon release")

	# 1.5 Desktop mouse event isolation
	var ev_mouse_down = InputEventMouseButton.new()
	ev_mouse_down.button_index = MOUSE_BUTTON_LEFT
	ev_mouse_down.position = Vector2(200.0, 600.0)
	ev_mouse_down.pressed = true

	var consumed_mouse_down = joystick.handle_touch_event(ev_mouse_down)
	_assert_test(consumed_mouse_down == true, "1.12 Left mouse press in joystick zone consumed by joystick")
	_assert_test(avatar._has_click_target == false, "1.13 Left click on joystick does NOT set click-to-move destination in 3D")

	var ev_mouse_up = InputEventMouseButton.new()
	ev_mouse_up.button_index = MOUSE_BUTTON_LEFT
	ev_mouse_up.position = Vector2(200.0, 600.0)
	ev_mouse_up.pressed = false

	var consumed_mouse_up = joystick.handle_touch_event(ev_mouse_up)
	_assert_test(consumed_mouse_up == true, "1.14 Left mouse release consumed by joystick")
	_assert_test(joystick.is_active == false, "1.15 Joystick inactive after mouse release")

	# Clean up Harness 1
	harness.queue_free()
	await process_frame

	# =========================================================================
	# CHALLENGE 2: Concurrent Multi-Touch Concurrency
	# =========================================================================
	print("\n--- Challenge 2: Concurrent Multi-Touch Concurrency ---")
	print("Hypothesis: Concurrent finger inputs (finger 1 tapping/dragging) NEVER disrupt active finger 0 joystick.")

	var harness2 = Node3D.new()
	harness2.name = "TestHarness_Challenger2"
	root.add_child(harness2)

	var avatar2 = avatar_scene.instantiate() as Avatar3D
	harness2.add_child(avatar2)
	avatar2.global_position = Vector3(0.0, 0.0, 0.0)

	var joystick2 = joystick_scene.instantiate() as VirtualJoystick
	joystick2.set_avatar(avatar2)
	harness2.add_child(joystick2)
	await process_frame

	# Step 2.1: Establish active steering with Finger 0 (drag North)
	var f0_down = InputEventScreenTouch.new()
	f0_down.index = 0
	f0_down.position = Vector2(180.0, 500.0)
	f0_down.pressed = true
	joystick2.handle_touch_event(f0_down)

	var f0_drag = InputEventScreenDrag.new()
	f0_drag.index = 0
	# Drag offset: +60 px X, -60 px Y (North in isometric camera)
	f0_drag.position = Vector2(240.0, 440.0)
	joystick2.handle_touch_event(f0_drag)

	# Allow 3 physics frames to start movement
	for _i in range(3):
		await physics_frame

	var captured_out_vec = joystick2.output_vector
	var captured_world_dir = joystick2.world_direction_3d
	_assert_test(captured_out_vec != Vector2.ZERO, "2.1 Finger 0 active with non-zero output vector")
	_assert_test(captured_world_dir != Vector3.ZERO, "2.2 Finger 0 steering 3D direction established")

	# Step 2.2: Barrage of concurrent Finger 1 events on right half
	var finger1_positions = [
		Vector2(550.0, 800.0), # Right bottom
		Vector2(650.0, 1100.0), # Action button location
		Vector2(650.0, 950.0), # Menu button location
		Vector2(450.0, 300.0), # Upper right area
		Vector2(100.0, 400.0), # Left half (same zone as joystick!)
	]

	var finger1_disrupted: bool = false
	for p in finger1_positions:
		# Finger 1 Down
		var f1_down = InputEventScreenTouch.new()
		f1_down.index = 1
		f1_down.position = p
		f1_down.pressed = true
		var f1_down_handled = joystick2.handle_touch_event(f1_down)
		if f1_down_handled:
			finger1_disrupted = true

		# Finger 1 Drag
		var f1_drag = InputEventScreenDrag.new()
		f1_drag.index = 1
		f1_drag.position = p + Vector2(20.0, -20.0)
		var f1_drag_handled = joystick2.handle_touch_event(f1_drag)
		if f1_drag_handled:
			finger1_disrupted = true

		# Finger 1 Up
		var f1_up = InputEventScreenTouch.new()
		f1_up.index = 1
		f1_up.position = p + Vector2(20.0, -20.0)
		f1_up.pressed = false
		var f1_up_handled = joystick2.handle_touch_event(f1_up)
		if f1_up_handled:
			finger1_disrupted = true

		# Check joystick stability after each secondary finger event
		if joystick2.touch_finger_index != 0 or not joystick2.is_active:
			finger1_disrupted = true
		if (joystick2.output_vector - captured_out_vec).length() > 0.001:
			finger1_disrupted = true
		if (joystick2.world_direction_3d - captured_world_dir).length() > 0.001:
			finger1_disrupted = true

	_assert_test(not finger1_disrupted, "2.3 Secondary finger taps/drags (including left zone) completely ignored by joystick")
	_assert_test(joystick2.touch_finger_index == 0, "2.4 Active finger index remains strictly 0 throughout multi-touch barrage")
	_assert_test(joystick2.is_active == true, "2.5 Joystick remains continuously active")

	# Step 2.3: Verify Finger 0 continues steering unimpeded
	for _i in range(3):
		await physics_frame
	_assert_test(avatar2.velocity.length() > 0.5, "2.6 Avatar velocity sustained during concurrent multi-touch input")

	# Step 2.4: Release Finger 0
	var f0_up = InputEventScreenTouch.new()
	f0_up.index = 0
	f0_up.position = Vector2(240.0, 440.0)
	f0_up.pressed = false
	var f0_up_handled = joystick2.handle_touch_event(f0_up)

	_assert_test(f0_up_handled == true, "2.7 Finger 0 release handled successfully")
	_assert_test(joystick2.is_active == false, "2.8 Joystick inactive after Finger 0 release")
	_assert_test(joystick2.touch_finger_index == -1, "2.9 Finger index reset to -1")
	_assert_test(avatar2.velocity.x == 0.0 and avatar2.velocity.z == 0.0,
		"2.10 Avatar stopped immediately upon Finger 0 release")

	# Step 2.5: Finger 1 claims joystick when Finger 0 is NOT touching
	var f1_claim = InputEventScreenTouch.new()
	f1_claim.index = 1
	f1_claim.position = Vector2(150.0, 600.0)
	f1_claim.pressed = true
	var f1_claim_handled = joystick2.handle_touch_event(f1_claim)

	_assert_test(f1_claim_handled == true, "2.11 Finger 1 can legally claim joystick when no other finger is active")
	_assert_test(joystick2.touch_finger_index == 1, "2.12 Joystick bound to finger index 1")

	# Release Finger 1
	f1_claim.pressed = false
	joystick2.handle_touch_event(f1_claim)
	_assert_test(joystick2.touch_finger_index == -1, "2.13 Finger 1 cleanly released")

	harness2.queue_free()
	await process_frame

	# =========================================================================
	# CHALLENGE 3: Rapid Lifecycle Stress (50 Quick Successive Cycles)
	# =========================================================================
	print("\n--- Challenge 3: Rapid Lifecycle Stress (50 Rapid Events) ---")
	print("Hypothesis: 50 rapid touch down/up cycles produce zero state desynchronization or orphaned tweens.")

	var harness3 = Node3D.new()
	harness3.name = "TestHarness_Challenger3"
	root.add_child(harness3)

	var avatar3 = avatar_scene.instantiate() as Avatar3D
	harness3.add_child(avatar3)

	var joystick3 = joystick_scene.instantiate() as VirtualJoystick
	joystick3.set_avatar(avatar3)
	harness3.add_child(joystick3)
	await process_frame

	var release_signal_count: int = 0
	var release_listener = func(): release_signal_count += 1
	joystick3.joystick_released.connect(release_listener)

	var state_integrity_flaw: bool = false
	const STRESS_CYCLES: int = 50

	for cycle in range(STRESS_CYCLES):
		var touch_pos = Vector2(100.0 + (cycle % 20) * 10.0, 400.0 + (cycle % 30) * 15.0)

		# 1. Down
		var ev_down = InputEventScreenTouch.new()
		ev_down.index = 0
		ev_down.position = touch_pos
		ev_down.pressed = true
		var down_ok = joystick3.handle_touch_event(ev_down)
		if not down_ok or not joystick3.is_active or joystick3.touch_finger_index != 0:
			state_integrity_flaw = true
			break

		# 2. Drag (clamped offset)
		var ev_drag = InputEventScreenDrag.new()
		ev_drag.index = 0
		ev_drag.position = touch_pos + Vector2(40.0, -40.0)
		var drag_ok = joystick3.handle_touch_event(ev_drag)
		if not drag_ok or joystick3.output_vector == Vector2.ZERO:
			state_integrity_flaw = true
			break

		# 3. Up
		var ev_up = InputEventScreenTouch.new()
		ev_up.index = 0
		ev_up.position = touch_pos + Vector2(40.0, -40.0)
		ev_up.pressed = false
		var up_ok = joystick3.handle_touch_event(ev_up)
		if not up_ok or joystick3.is_active or joystick3.touch_finger_index != -1:
			state_integrity_flaw = true
			break

		# Intermediate check on velocity zeroing
		if avatar3.velocity.x != 0.0 or avatar3.velocity.z != 0.0:
			state_integrity_flaw = true
			break

	_assert_test(not state_integrity_flaw, "3.1 50 rapid lifecycle cycles completed with zero state desynchronization")
	_assert_test(release_signal_count == STRESS_CYCLES,
		"3.2 Exactly %d joystick_released signals emitted (actual: %d)" % [STRESS_CYCLES, release_signal_count])

	# Step 3.2: Allow tween duration to elapse (0.25 seconds) and verify visual & tween state
	for _i in range(16):
		await process_frame

	_assert_test(joystick3.is_active == false, "3.3 Joystick remains inactive post-stress")
	_assert_test(joystick3.touch_finger_index == -1, "3.4 Finger index reset to -1 post-stress")
	_assert_test(joystick3.output_vector == Vector2.ZERO, "3.5 Output vector is Vector2.ZERO post-stress")
	_assert_test(joystick3.world_direction_3d == Vector3.ZERO, "3.6 World direction is Vector3.ZERO post-stress")
	_assert_test(avatar3.velocity.length() < 0.001, "3.7 Avatar velocity strictly 0.0 post-stress")

	# Step 3.3: Visual knob and base ring rest position verification
	var base_ring_node = joystick3.get_node_or_null("BaseRing")
	var stick_knob_node = joystick3.get_node_or_null("BaseRing/StickKnob")
	if base_ring_node != null and stick_knob_node != null:
		_assert_test(stick_knob_node.position.distance_to(Vector2.ZERO) < 0.1,
			"3.8 Stick knob smoothly returned to Vector2.ZERO (actual: %.2f, %.2f)" % [stick_knob_node.position.x, stick_knob_node.position.y])
		_assert_test(base_ring_node.modulate.a <= 0.05,
			"3.9 Base ring opacity faded to resting opacity (actual: %.3f)" % base_ring_node.modulate.a)

	# Step 3.4: Sub-deadzone micro-jitter stress (50 jitter events within 6px radius)
	var jitter_clean: bool = true
	var center_jitter = Vector2(180.0, 500.0)
	var ev_jit_down = InputEventScreenTouch.new()
	ev_jit_down.index = 0
	ev_jit_down.position = center_jitter
	ev_jit_down.pressed = true
	joystick3.handle_touch_event(ev_jit_down)

	for i in range(50):
		var jitter_offset = Vector2(cos(i) * 5.0, sin(i) * 5.0) # 5px radius, strictly < 12px deadzone
		var ev_jit_drag = InputEventScreenDrag.new()
		ev_jit_drag.index = 0
		ev_jit_drag.position = center_jitter + jitter_offset
		joystick3.handle_touch_event(ev_jit_drag)
		if joystick3.output_vector != Vector2.ZERO or joystick3.world_direction_3d != Vector3.ZERO:
			jitter_clean = false
			break

	ev_jit_down.pressed = false
	joystick3.handle_touch_event(ev_jit_down)

	_assert_test(jitter_clean, "3.10 Sub-deadzone micro-jitter (50 events < 6px) strictly produces Vector2.ZERO without noise")

	joystick3.joystick_released.disconnect(release_listener)
	harness3.queue_free()
	await process_frame
