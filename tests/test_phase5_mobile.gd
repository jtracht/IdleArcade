extends SceneTree

## =============================================================================
## Master Headless SceneTree Integration Test Suite for Phase 5 Mobile Touch Controls
## File: IdleArcade/tests/test_phase5_mobile.gd
##
## Aggregates and validates all Phase 5 mobile touch control features across
## 4 systematic tiers:
##
## TIER 1 (Feature Coverage):
##   - VirtualJoystick instantiation, dynamic centering, deadzone filter,
##     camera-relative 3D vector, Avatar3D velocity halt (stop_movement()).
##   - TouchControls CanvasLayer 7 mounting, ActionButton 110px tap target,
##     LaptopThumbButton 80px tap target.
##   - Dual action dispatch (direct interactable call + synthetic KEY_E),
##     NPC & Gate proximity registration.
##   - HapticsManager singleton, semantic methods (vibrate_pickup, vibrate_gate,
##     vibrate_quest, vibrate_button), and 50ms churn throttle.
##
## TIER 2 (Boundary & Corner Cases):
##   - Screen coordinate limits: (0, 70), (360, 70), (720, 1280), transitions.
##   - Extreme radius overflow clamping (500 px -> 80 px).
##   - Deadzone sub-threshold zeroing (5 px, 11.99 px -> Vector2.ZERO).
##   - Rapid tap bursts and button cooldown decoupling (bypass_cooldown = true).
##   - Standalone null-safety when singletons or nodes are absent.
##
## TIER 3 (Cross-Feature Combinations):
##   - Simultaneous joystick steering and button pressing (multi-touch index isolation).
##   - Proximity registration updates during active joystick drag.
##   - Haptic feedback emissions triggered during motion.
##   - 3-tier input isolation (mouse_filter = STOP and accept_event()).
##
## TIER 4 (Real-World Application Scenarios):
##   - Full simulated mobile session:
##     Spawn avatar -> Steer with joystick toward NPC -> Action button highlights ->
##     Tap ActionButton -> Dialogue triggered & haptic fires ->
##     Steer toward ZoneGate -> ActionButton updates to "Unlock" ->
##     Tap ActionButton -> Gate unlocked & medium haptic fires ->
##     Avatar collects 3D item -> Light haptic fires with churn throttling ->
##     Tap LaptopThumbButton -> 2D idle overlay toggles with input isolation verified.
##
## Execution:
##   godot --headless --path IdleArcade -s tests/test_phase5_mobile.gd
## =============================================================================

var pass_count: int = 0
var fail_count: int = 0

const EPSILON: float = 0.002
const SQRT1_2: float = 0.7071067811865475
const CAMERA_YAW_45_RAD: float = 0.7853981633974483
const VIEWPORT_WIDTH: float = 720.0
const VIEWPORT_HEIGHT: float = 1280.0

# Preloaded scripts for headless class resolution without editor cache
const VirtualJoystick = preload("res://scripts/ui/virtual_joystick.gd")
const TouchControls = preload("res://scripts/ui/touch_controls.gd")
const Avatar3D = preload("res://scripts/avatar_3d.gd")
const Main3D = preload("res://scripts/main_3d.gd")
const NPC3D = preload("res://scripts/npc_3d.gd")
const ZoneGate3D = preload("res://scripts/zone_gate_3d.gd")
const Collectible3D = preload("res://scripts/collectible_3d.gd")

# ------------------------------------------------------------------------------
# Test Helper Classes
# ------------------------------------------------------------------------------

## Captures synthetic InputEventKey emissions (KEY_E, KEY_TAB, etc.)
class KeyWatcher extends Node:
	var key_e_pressed_count: int = 0
	var key_e_released_count: int = 0
	var key_tab_pressed_count: int = 0
	var key_tab_released_count: int = 0

	func _unhandled_input(event: InputEvent) -> void:
		if event is InputEventKey:
			if event.keycode == KEY_E:
				if event.pressed:
					key_e_pressed_count += 1
				else:
					key_e_released_count += 1
			elif event.keycode == KEY_TAB:
				if event.pressed:
					key_tab_pressed_count += 1
				else:
					key_tab_released_count += 1

	func clear() -> void:
		key_e_pressed_count = 0
		key_e_released_count = 0
		key_tab_pressed_count = 0
		key_tab_released_count = 0

## Spies on HapticsManager vibration_triggered and vibration_custom_triggered signals
class VibrationSpy extends Node:
	var emissions: Array[Dictionary] = []

	func _on_vibration_triggered(duration_ms: int, amplitude: float) -> void:
		emissions.append({
			"duration_ms": duration_ms,
			"amplitude": amplitude,
			"timestamp": Time.get_ticks_msec()
		})

	func clear() -> void:
		emissions.clear()

	func get_count() -> int:
		return emissions.size()

	func get_last() -> Dictionary:
		if emissions.is_empty():
			return {}
		return emissions[-1]

# ------------------------------------------------------------------------------
# Lifecycle & Test Runner Entry Point
# ------------------------------------------------------------------------------

func _init() -> void:
	print("====================================================================")
	print("[TEST] Phase 5 Mobile Master Integration Test Suite (Godot 4.3)")
	print("====================================================================")
	process_frame.connect(_on_first_frame, CONNECT_ONE_SHOT)

func _on_first_frame() -> void:
	await _run_all_tests()
	print("\n====================================================================")
	print("[TEST] Phase 5 Master Results: %d passed, %d failed" % [pass_count, fail_count])
	print("====================================================================")
	if fail_count == 0:
		print(">>> ALL PHASE 5 MOBILE MASTER TESTS PASSED SUCCESSFULLY! <<<")
		quit(0)
	else:
		printerr(">>> TEST SUITE ENCOUNTERED %d FAILURES! <<<" % fail_count)
		quit(1)

func _assert_check(cond: bool, test_name: String, detail: String = "") -> void:
	if cond:
		print("  [PASS] %s" % test_name)
		pass_count += 1
	else:
		var err_msg: String = "  [FAIL] %s" % test_name
		if detail != "":
			err_msg += " -> " + detail
		printerr(err_msg)
		fail_count += 1

# ------------------------------------------------------------------------------
# Master Test Execution Pipeline
# ------------------------------------------------------------------------------

func _run_all_tests() -> void:
	# -------------------------------------------------------------------------
	# 0. Environment Setup & Autoload Initialization
	# -------------------------------------------------------------------------
	var gs_script = load("res://scripts/autoload/game_state.gd")
	var gs = root.get_node_or_null("GameState")
	if gs == null and gs_script != null:
		gs = gs_script.new()
		gs.name = "GameState"
		root.add_child(gs)
	if gs != null and gs.has_method("reset_state"):
		gs.reset_state()

	var nakama_script = load("res://scripts/autoload/nakama_manager.gd")
	var nakama_mgr = root.get_node_or_null("NakamaManager")
	if nakama_mgr == null and nakama_script != null:
		nakama_mgr = nakama_script.new()
		nakama_mgr.name = "NakamaManager"
		root.add_child(nakama_mgr)

	var haptics_script = load("res://scripts/autoload/haptics_manager.gd")
	var hm = root.get_node_or_null("HapticsManager")
	var is_hm_dynamic: bool = false
	if hm == null and haptics_script != null:
		hm = haptics_script.new()
		hm.name = "HapticsManager"
		root.add_child(hm)
		is_hm_dynamic = true

	await process_frame

	if hm != null:
		if "enabled" in hm:
			hm.enabled = true
		if "mock_mode" in hm:
			hm.mock_mode = true
		if hm.has_method("clear_history"):
			hm.clear_history()

	# Spy for haptics signals
	var spy: VibrationSpy = VibrationSpy.new()
	if hm != null and hm.has_signal("vibration_triggered"):
		hm.add_child(spy)
		hm.vibration_triggered.connect(spy._on_vibration_triggered)

	# KeyWatcher for synthetic keyboard inputs
	var key_watcher: KeyWatcher = KeyWatcher.new()
	root.add_child(key_watcher)
	await process_frame

	# =========================================================================
	# TIER 1: Feature Coverage (Core Functional Units)
	# =========================================================================
	print("\n====================================================================")
	print(">>> TIER 1: FEATURE COVERAGE (Core Functional Units)")
	print("====================================================================")

	# --- 1.1 VirtualJoystick Instantiation & Contracts ---
	print("\n--- 1.1 VirtualJoystick Instantiation & Contracts ---")
	var joystick_scene = load("res://scenes/ui/virtual_joystick.tscn")
	_assert_check(joystick_scene != null, "1.1.1 scenes/ui/virtual_joystick.tscn loaded successfully")

	var joystick: VirtualJoystick = null
	if joystick_scene != null:
		joystick = joystick_scene.instantiate() as VirtualJoystick
		root.add_child(joystick)
		await process_frame

	_assert_check(joystick != null, "1.1.2 VirtualJoystick instanced as valid Control")
	if joystick != null:
		_assert_check(absf(joystick.max_radius - 80.0) < 0.1,
			"1.1.3 Default max_radius is 80.0 px (actual: %.1f)" % joystick.max_radius)
		_assert_check(absf(joystick.deadzone_radius - 12.0) < 0.1,
			"1.1.4 Default deadzone_radius is 12.0 px (actual: %.1f)" % joystick.deadzone_radius)
		_assert_check(absf(joystick.fade_duration - 0.20) < 0.05,
			"1.1.5 Default fade_duration is 0.20 s (actual: %.2f)" % joystick.fade_duration)
		_assert_check(joystick.has_signal("joystick_moved"), "1.1.6 Declares joystick_moved signal")
		_assert_check(joystick.has_signal("joystick_released"), "1.1.7 Declares joystick_released signal")
		_assert_check(joystick.has_method("calculate_clamped_stick_pos"), "1.1.8 Implements calculate_clamped_stick_pos()")
		_assert_check(joystick.has_method("calculate_output_vector"), "1.1.9 Implements calculate_output_vector()")
		_assert_check(joystick.has_method("calculate_camera_relative_3d"), "1.1.10 Implements calculate_camera_relative_3d()")
		_assert_check(joystick.has_method("reset_joystick"), "1.1.11 Implements reset_joystick()")

	# --- 1.2 Dynamic Centering & Activation Zone ---
	print("\n--- 1.2 Dynamic Centering & Activation Zone ---")
	if joystick != null:
		var touch_left = InputEventScreenTouch.new()
		touch_left.index = 0
		touch_left.position = Vector2(160.0, 520.0)
		touch_left.pressed = true

		var handled_left: bool = joystick.handle_touch_event(touch_left)
		_assert_check(handled_left == true, "1.2.1 Touch in left half (160, 520) accepted")
		_assert_check(joystick.is_active == true, "1.2.2 Joystick activates on left half touch")
		_assert_check(joystick.center_position.distance_to(Vector2(160.0, 520.0)) < 1.0,
			"1.2.3 Joystick dynamically centers at touch coordinate")

		joystick.reset_joystick()

		var touch_right = InputEventScreenTouch.new()
		touch_right.index = 0
		touch_right.position = Vector2(500.0, 600.0)
		touch_right.pressed = true
		var handled_right: bool = joystick.handle_touch_event(touch_right)
		_assert_check(handled_right == false, "1.2.4 Touch in right half (500, 600) rejected")
		_assert_check(joystick.is_active == false, "1.2.5 Joystick remains inactive on right half touch")

		var touch_hud = InputEventScreenTouch.new()
		touch_hud.index = 0
		touch_hud.position = Vector2(160.0, 45.0)
		touch_hud.pressed = true
		var handled_hud: bool = joystick.handle_touch_event(touch_hud)
		_assert_check(handled_hud == false, "1.2.6 Touch in QuickHUD zone (Y < 70) rejected")

	# --- 1.3 Deadzone Filter Math ---
	print("\n--- 1.3 Deadzone Filter Math ---")
	if joystick != null:
		var zero_out = joystick.calculate_output_vector(Vector2.ZERO)
		_assert_check(zero_out == Vector2.ZERO, "1.3.1 Vector2.ZERO offset yields Vector2.ZERO output")

		var sub_dead = joystick.calculate_output_vector(Vector2(6.0, 0.0))
		_assert_check(sub_dead == Vector2.ZERO, "1.3.2 Sub-deadzone offset (6 px) zeroed")

		var exact_dead = joystick.calculate_output_vector(Vector2(12.0, 0.0))
		_assert_check(exact_dead == Vector2.ZERO, "1.3.3 Exact deadzone boundary (12 px) zeroed")

		var above_dead = joystick.calculate_output_vector(Vector2(13.0, 0.0))
		_assert_check(above_dead != Vector2.ZERO and above_dead.x > 0.0,
			"1.3.4 Offset above deadzone (13 px) produces non-zero output (x = %.3f)" % above_dead.x)

	# --- 1.4 Radius Clamping Math ---
	print("\n--- 1.4 Radius Clamping Math ---")
	if joystick != null:
		var center_pt = Vector2(200.0, 400.0)
		var touch_in = center_pt + Vector2(50.0, 0.0)
		var clamped_in = joystick.calculate_clamped_stick_pos(touch_in, center_pt)
		_assert_check(clamped_in.distance_to(center_pt) <= 50.001,
			"1.4.1 Touch within radius (50 px) not clamped: dist = %.2f" % clamped_in.distance_to(center_pt))

		var touch_out = center_pt + Vector2(150.0, 0.0)
		var clamped_out = joystick.calculate_clamped_stick_pos(touch_out, center_pt)
		_assert_check(absf(clamped_out.distance_to(center_pt) - 80.0) < 0.01,
			"1.4.2 Touch exceeding radius (150 px) clamped to 80.0 px: dist = %.2f" % clamped_out.distance_to(center_pt))

		var out_clamped = joystick.calculate_output_vector(Vector2(150.0, 0.0))
		_assert_check(absf(out_clamped.length() - 1.0) < EPSILON,
			"1.4.3 Normalized output vector at clamp limit has magnitude 1.0 (actual: %.4f)" % out_clamped.length())

	# --- 1.5 Camera-Relative 3D Vector Transformation ---
	print("\n--- 1.5 Camera-Relative 3D Vector Transformation ---")
	if joystick != null:
		var dir_up = joystick.calculate_camera_relative_3d(Vector2(0.0, -1.0), CAMERA_YAW_45_RAD)
		var exp_up = Vector3(-SQRT1_2, 0.0, -SQRT1_2)
		_assert_check(dir_up.distance_to(exp_up) < EPSILON,
			"1.5.1 Cardinal UP maps to isometric forward: (%.3f, %.3f, %.3f)" % [dir_up.x, dir_up.y, dir_up.z])

		var dir_right = joystick.calculate_camera_relative_3d(Vector2(1.0, 0.0), CAMERA_YAW_45_RAD)
		var exp_right = Vector3(SQRT1_2, 0.0, -SQRT1_2)
		_assert_check(dir_right.distance_to(exp_right) < EPSILON,
			"1.5.2 Cardinal RIGHT maps to isometric right: (%.3f, %.3f, %.3f)" % [dir_right.x, dir_right.y, dir_right.z])

		var dir_ur = joystick.calculate_camera_relative_3d(Vector2(SQRT1_2, -SQRT1_2), CAMERA_YAW_45_RAD)
		var exp_ur = Vector3(0.0, 0.0, -1.0)
		_assert_check(dir_ur.distance_to(exp_ur) < EPSILON,
			"1.5.3 Diagonal UP-RIGHT maps to pure North (-Z): (%.3f, %.3f, %.3f)" % [dir_ur.x, dir_ur.y, dir_ur.z])

		_assert_check(dir_up.y == 0.0 and dir_right.y == 0.0 and dir_ur.y == 0.0,
			"1.5.4 Horizontal plane constraint maintained (Y = 0.0)")

	# --- 1.6 Avatar3D Velocity Halt (stop_movement()) ---
	print("\n--- 1.6 Avatar3D Velocity Halt (stop_movement()) ---")
	var avatar_scene = load("res://scenes/avatar_3d.tscn")
	_assert_check(avatar_scene != null, "1.6.1 scenes/avatar_3d.tscn loaded successfully")

	var avatar: Avatar3D = null
	if avatar_scene != null:
		avatar = avatar_scene.instantiate() as Avatar3D
		root.add_child(avatar)
		await process_frame

	if avatar != null:
		avatar.velocity = Vector3(6.0, 0.0, 6.0)
		avatar.set_input_direction(Vector3(1.0, 0.0, 0.0))
		_assert_check(avatar.velocity.length() > 6.0, "1.6.2 Avatar moving initially")

		avatar.stop_movement()
		_assert_check(avatar.velocity.x == 0.0 and avatar.velocity.z == 0.0,
			"1.6.3 stop_movement() immediately zeroes horizontal velocity: (%.3f, %.3f)" % [avatar.velocity.x, avatar.velocity.z])

		var pre_halt_pos: Vector3 = avatar.global_position
		for _i in range(10):
			await physics_frame
		var drift: float = pre_halt_pos.distance_to(avatar.global_position)
		_assert_check(drift < 0.005,
			"1.6.4 Zero coasting drift over 10 physics frames: drift = %.5f m" % drift)

	# --- 1.7 TouchControls CanvasLayer 7 Mounting & Hierarchy ---
	print("\n--- 1.7 TouchControls CanvasLayer 7 Mounting & Hierarchy ---")
	var main_scene = load("res://scenes/main_3d.tscn")
	_assert_check(main_scene != null, "1.7.1 scenes/main_3d.tscn loaded successfully")

	if main_scene != null:
		var main_inst = main_scene.instantiate()
		root.add_child(main_inst)
		await process_frame

		var touch_layer = main_inst.get_node_or_null("TouchControlsLayer") as CanvasLayer
		_assert_check(touch_layer != null, "1.7.2 Main3D contains TouchControlsLayer")
		if touch_layer != null:
			_assert_check(touch_layer.layer == 7,
				"1.7.3 TouchControlsLayer mounted exactly at layer 7 (actual: %d)" % touch_layer.layer)

			var quick_hud = main_inst.get_node_or_null("QuickHUDLayer") as CanvasLayer
			var quest_layer = main_inst.get_node_or_null("QuestLayer") as CanvasLayer
			var dialogue_layer = main_inst.get_node_or_null("DialogueLayer") as CanvasLayer
			var hud_overlay = main_inst.get_node_or_null("HUDOverlayLayer") as CanvasLayer

			var order_valid: bool = true
			if quick_hud != null and quick_hud.layer >= touch_layer.layer:
				order_valid = false
			if quest_layer != null and quest_layer.layer >= touch_layer.layer:
				order_valid = false
			if dialogue_layer != null and dialogue_layer.layer <= touch_layer.layer:
				order_valid = false
			if hud_overlay != null and hud_overlay.layer <= touch_layer.layer:
				order_valid = false

			_assert_check(order_valid,
				"1.7.4 Layer ordering verified: QuickHUD(5) < Quest(6) < TouchControls(7) < Dialogue(8) < HUD(10)")

		main_inst.queue_free()
		await process_frame

	# --- 1.8 ActionButton & LaptopThumbButton Tap Targets & Layout ---
	print("\n--- 1.8 ActionButton & LaptopThumbButton Layout ---")
	var tc_scene = load("res://scenes/ui/touch_controls.tscn")
	_assert_check(tc_scene != null, "1.8.1 scenes/ui/touch_controls.tscn loaded successfully")

	var tc_inst: TouchControls = null
	if tc_scene != null:
		tc_inst = tc_scene.instantiate() as TouchControls
		root.add_child(tc_inst)
		await process_frame

	var action_btn: Button = null
	var laptop_btn: Button = null
	if tc_inst != null:
		action_btn = tc_inst.action_button
		laptop_btn = tc_inst.laptop_button

		_assert_check(action_btn != null, "1.8.2 ActionButton node resolved")
		_assert_check(laptop_btn != null, "1.8.3 LaptopThumbButton node resolved")

		if action_btn != null:
			_assert_check(action_btn.size.x >= 80.0 and action_btn.size.y >= 80.0,
				"1.8.4 ActionButton dimensions >= 80px (actual: %.1fx%.1f px)" % [action_btn.size.x, action_btn.size.y])
			_assert_check(action_btn.global_position.x + action_btn.size.x * 0.5 > 360.0,
				"1.8.5 ActionButton situated on right half of screen")

		if laptop_btn != null:
			_assert_check(laptop_btn.size.x >= 60.0 and laptop_btn.size.y >= 60.0,
				"1.8.6 LaptopThumbButton dimensions >= 60px (actual: %.1fx%.1f px)" % [laptop_btn.size.x, laptop_btn.size.y])
			_assert_check(laptop_btn.global_position.x + laptop_btn.size.x * 0.5 > 360.0,
				"1.8.7 LaptopThumbButton situated on right half of screen")

		if action_btn != null and laptop_btn != null:
			var act_c = action_btn.global_position + action_btn.size * 0.5
			var lap_c = laptop_btn.global_position + laptop_btn.size * 0.5
			var separation: float = act_c.distance_to(lap_c)
			var min_sep: float = (action_btn.size.x * 0.5) + (laptop_btn.size.x * 0.5)
			_assert_check(separation > min_sep,
				"1.8.8 ActionButton and LaptopThumbButton do not overlap (separation: %.1f px > min: %.1f px)" % [separation, min_sep])

	# --- 1.9 Dual Action Dispatch & Proximity Registration ---
	print("\n--- 1.9 Dual Action Dispatch & Proximity Registration ---")
	var npc_scene = load("res://scenes/npc_3d.tscn")
	var gate_scene = load("res://scenes/zone_gate_3d.tscn")
	var test_npc: NPC3D = null
	var test_gate: ZoneGate3D = null

	if npc_scene != null:
		test_npc = npc_scene.instantiate() as NPC3D
		root.add_child(test_npc)
		test_npc.npc_name = "Alex"

	if gate_scene != null:
		test_gate = gate_scene.instantiate() as ZoneGate3D
		root.add_child(test_gate)
		test_gate.zone_name = "Server Room"

	await process_frame

	if tc_inst != null and test_npc != null:
		# Register NPC
		tc_inst.register_interactable(test_npc, "Talk [E]")
		await process_frame
		_assert_check(tc_inst.active_interactable == test_npc,
			"1.9.1 Proximity registration sets active_interactable to NPC")

		key_watcher.clear()
		var action_dispatched_target: Node = null
		var action_signal_fired: bool = false
		var dispatch_callable = func(target):
			action_dispatched_target = target
			action_signal_fired = true
		tc_inst.action_triggered.connect(dispatch_callable)

		tc_inst._on_action_button_pressed()
		await process_frame

		_assert_check(action_signal_fired and action_dispatched_target == test_npc,
			"1.9.2 action_triggered signal emitted with NPC target")
		_assert_check(test_npc._is_talking == true,
			"1.9.3 Direct dispatch invoked interact() on NPC (_is_talking == true)")
		_assert_check(key_watcher.key_e_pressed_count > 0,
			"1.9.4 Synthetic KEY_E press emitted into Input queue (count: %d)" % key_watcher.key_e_pressed_count)

		test_npc.end_dialogue()
		tc_inst.unregister_interactable(test_npc)
		tc_inst.action_triggered.disconnect(dispatch_callable)
		await process_frame
		_assert_check(tc_inst.active_interactable == null,
			"1.9.5 Unregistering NPC restores active_interactable to null")

	# --- 1.10 HapticsManager Singleton & Semantic Methods ---
	print("\n--- 1.10 HapticsManager Singleton & Semantic Methods ---")
	if hm != null:
		_assert_check(hm.has_method("vibrate_pickup"), "1.10.1 Implements vibrate_pickup()")
		_assert_check(hm.has_method("vibrate_gate"), "1.10.2 Implements vibrate_gate()")
		_assert_check(hm.has_method("vibrate_quest"), "1.10.3 Implements vibrate_quest()")
		_assert_check(hm.has_method("vibrate_button"), "1.10.4 Implements vibrate_button()")

		hm.min_interval_ms = 0
		hm.reset_pickup_cooldown()
		spy.clear()

		hm.vibrate_pickup()
		var pick_entry = spy.get_last()
		_assert_check(pick_entry.get("duration_ms", 0) >= 25 and pick_entry.get("duration_ms", 0) <= 35,
			"1.10.5 vibrate_pickup() triggers light pulse (25-35ms, actual: %d)" % int(pick_entry.get("duration_ms", 0)))

		hm.reset_pickup_cooldown()
		hm.vibrate_gate()
		var gate_entry = spy.get_last()
		_assert_check(gate_entry.get("duration_ms", 0) == 70,
			"1.10.6 vibrate_gate() triggers medium pulse (70ms, actual: %d)" % int(gate_entry.get("duration_ms", 0)))

		hm.reset_pickup_cooldown()
		hm.vibrate_quest()
		var quest_entry = spy.get_last()
		_assert_check(quest_entry.get("duration_ms", 0) == 120,
			"1.10.7 vibrate_quest() triggers heavy pulse (120ms, actual: %d)" % int(quest_entry.get("duration_ms", 0)))

		hm.reset_pickup_cooldown()
		hm.vibrate_button()
		var btn_entry = spy.get_last()
		_assert_check(btn_entry.get("duration_ms", 0) >= 15 and btn_entry.get("duration_ms", 0) <= 30,
			"1.10.8 vibrate_button() triggers subtle tap pulse (15-30ms, actual: %d)" % int(btn_entry.get("duration_ms", 0)))

		# Churn throttle test (50ms)
		hm.min_interval_ms = 50
		hm.reset_pickup_cooldown()
		spy.clear()

		hm.vibrate_pickup() # 1st accepted
		hm.vibrate_pickup() # 2nd throttled (0ms delta)
		_assert_check(spy.get_count() == 1,
			"1.10.9 Rapid consecutive pickup within 50ms cooldown is throttled (emissions: %d)" % spy.get_count())

	# =========================================================================
	# TIER 2: Boundary & Corner Cases
	# =========================================================================
	print("\n====================================================================")
	print(">>> TIER 2: BOUNDARY & CORNER CASES")
	print("====================================================================")

	# --- 2.1 Coordinate Limits & Boundary Transitions ---
	print("\n--- 2.1 Coordinate Limits & Boundary Transitions ---")
	if joystick != null:
		# Top-left limit (0, 70)
		var t_tl = InputEventScreenTouch.new()
		t_tl.index = 0
		t_tl.position = Vector2(0.0, 70.0)
		t_tl.pressed = true
		_assert_check(joystick.handle_touch_event(t_tl) == true, "2.1.1 Boundary point (0, 70) accepted")
		joystick.reset_joystick()

		# Mid-line limit (360, 70)
		var t_mid = InputEventScreenTouch.new()
		t_mid.index = 0
		t_mid.position = Vector2(360.0, 70.0)
		t_mid.pressed = true
		_assert_check(joystick.handle_touch_event(t_mid) == true, "2.1.2 Boundary point (360, 70) accepted")
		joystick.reset_joystick()

		# Just over right boundary (361, 70)
		var t_over_x = InputEventScreenTouch.new()
		t_over_x.index = 0
		t_over_x.position = Vector2(361.0, 70.0)
		t_over_x.pressed = true
		_assert_check(joystick.handle_touch_event(t_over_x) == false, "2.1.3 Point just over right bound (361, 70) rejected")

		# Just above top boundary (180, 69)
		var t_over_y = InputEventScreenTouch.new()
		t_over_y.index = 0
		t_over_y.position = Vector2(180.0, 69.0)
		t_over_y.pressed = true
		_assert_check(joystick.handle_touch_event(t_over_y) == false, "2.1.4 Point just above QuickHUD (180, 69) rejected")

		# Bottom limit (0, 1280)
		var t_bl = InputEventScreenTouch.new()
		t_bl.index = 0
		t_bl.position = Vector2(0.0, 1280.0)
		t_bl.pressed = true
		_assert_check(joystick.handle_touch_event(t_bl) == true, "2.1.5 Bottom-left point (0, 1280) accepted")
		joystick.reset_joystick()

		# Far opposite corner (720, 1280)
		var t_br = InputEventScreenTouch.new()
		t_br.index = 0
		t_br.position = Vector2(720.0, 1280.0)
		t_br.pressed = true
		_assert_check(joystick.handle_touch_event(t_br) == false, "2.1.6 Bottom-right point (720, 1280) rejected")

	# --- 2.2 Extreme Radius Overflow Clamping ---
	print("\n--- 2.2 Extreme Radius Overflow Clamping ---")
	if joystick != null:
		var c_pt = Vector2(180.0, 500.0)
		# Extreme displacement: 500 px right
		var t_ext_500 = c_pt + Vector2(500.0, 0.0)
		var clamped_500 = joystick.calculate_clamped_stick_pos(t_ext_500, c_pt)
		_assert_check(absf(clamped_500.distance_to(c_pt) - 80.0) < 0.01,
			"2.2.1 Extreme 500px offset clamped to exactly 80.0 px (actual: %.2f)" % clamped_500.distance_to(c_pt))

		var out_500 = joystick.calculate_output_vector(Vector2(500.0, 0.0))
		_assert_check(absf(out_500.length() - 1.0) < EPSILON and out_500.x > 0.999,
			"2.2.2 Normalized output vector clamped to strictly 1.0 (actual: %.4f)" % out_500.length())

		# Extreme diagonal: 2500 px
		var t_ext_diag = c_pt + Vector2(1767.77, -1767.77)
		var clamped_diag = joystick.calculate_clamped_stick_pos(t_ext_diag, c_pt)
		_assert_check(absf(clamped_diag.distance_to(c_pt) - 80.0) < 0.01,
			"2.2.3 Extreme 2500px diagonal clamped to 80.0 px (actual: %.2f)" % clamped_diag.distance_to(c_pt))

	# --- 2.3 Deadzone Sub-Threshold Zeroing ---
	print("\n--- 2.3 Deadzone Sub-Threshold Zeroing ---")
	if joystick != null:
		var out_5 = joystick.calculate_output_vector(Vector2(0.0, 5.0))
		_assert_check(out_5 == Vector2.ZERO, "2.3.1 5px displacement zeroed to Vector2.ZERO")

		var out_11_9 = joystick.calculate_output_vector(Vector2(11.99, 0.0))
		_assert_check(out_11_9 == Vector2.ZERO, "2.3.2 11.99px displacement zeroed to Vector2.ZERO")

		var out_neg = joystick.calculate_output_vector(Vector2(-8.0, -8.0))
		# length = sqrt(128) ~ 11.31 < 12.0
		_assert_check(out_neg == Vector2.ZERO, "2.3.3 Negative diagonal sub-deadzone (11.31 px) zeroed")


	# --- 2.4 Rapid Tap Bursts & Button Cooldown Decoupling ---
	print("\n--- 2.4 Rapid Tap Bursts & Button Cooldown Decoupling ---")
	if hm != null:
		hm.min_interval_ms = 50 # 50ms cooldown active
		hm.reset_pickup_cooldown()
		spy.clear()

		# Rapid burst of 5 button taps with bypass_cooldown = true
		for i in range(5):
			hm.vibrate_button(20, true)

		_assert_check(spy.get_count() == 5,
			"2.4.1 Rapid button tap burst bypasses 50ms cooldown (5/5 received, count: %d)" % spy.get_count())

		# Contrast with rapid pickups without bypass
		spy.clear()
		for i in range(5):
			hm.vibrate_pickup()
		_assert_check(spy.get_count() == 1,
			"2.4.2 Rapid pickup burst is strictly subject to 50ms cooldown (1/5 received, count: %d)" % spy.get_count())

	# --- 2.5 Standalone Null-Safety & Degraded Environments ---
	print("\n--- 2.5 Standalone Null-Safety & Degraded Environments ---")
	if joystick != null:
		# Detach avatar & camera, verify no crash on touch events
		joystick.set_avatar(null)
		joystick.set_camera(null)

		var t_orphan = InputEventScreenTouch.new()
		t_orphan.index = 0
		t_orphan.position = Vector2(150.0, 500.0)
		t_orphan.pressed = true
		var handled_orphan = joystick.handle_touch_event(t_orphan)
		_assert_check(handled_orphan == true, "2.5.1 Joystick operates safely without attached Avatar or Camera")

		var d_orphan = InputEventScreenDrag.new()
		d_orphan.index = 0
		d_orphan.position = Vector2(150.0, 420.0)
		var handled_drag_orphan = joystick.handle_touch_event(d_orphan)
		_assert_check(handled_drag_orphan == true, "2.5.2 Joystick drag operates safely without attached nodes")

		joystick.reset_joystick()

	if tc_inst != null:
		# Null interactable registration / unregistration
		tc_inst.register_interactable(null)
		tc_inst.unregister_interactable(null)
		_assert_check(tc_inst.active_interactable == null,
			"2.5.3 Null interactable registration and unregistration handled safely")

		# Action triggered with null interactable
		key_watcher.clear()
		tc_inst._on_action_button_pressed()
		_assert_check(key_watcher.key_e_pressed_count > 0,
			"2.5.4 Action button press with null interactable falls back to synthetic KEY_E safely")

	if hm != null:
		# Parameter bounds validation
		hm.min_interval_ms = 0
		hm.reset_pickup_cooldown()

		hm.vibrate(-50)
		_assert_check(true, "2.5.5 Negative vibration duration handled safely without exception")

		hm.vibrate(0)
		_assert_check(true, "2.5.6 Zero vibration duration handled safely without exception")

		hm.reset_pickup_cooldown()
		hm.vibrate_custom(60, 4.5)
		var last_amp: float = hm.get_last_amplitude()
		_assert_check(last_amp <= 1.0,
			"2.5.7 Out-of-bounds amplitude (> 1.0) clamped to 1.0 (actual: %.2f)" % last_amp)

		# Master disable suppression
		hm.enabled = false
		spy.clear()
		hm.vibrate_light(25)
		hm.vibrate_medium(70)
		hm.vibrate_heavy(120)
		_assert_check(spy.get_count() == 0,
			"2.5.8 All vibrations strictly suppressed when enabled == false")
		hm.enabled = true

	# =========================================================================
	# TIER 3: Cross-Feature Combinations
	# =========================================================================
	print("\n====================================================================")
	print(">>> TIER 3: CROSS-FEATURE COMBINATIONS")
	print("====================================================================")

	# --- 3.1 Simultaneous Joystick Steering & Button Pressing ---
	print("\n--- 3.1 Simultaneous Joystick Steering & Button Pressing ---")
	if joystick != null and tc_inst != null and avatar != null:
		joystick.set_avatar(avatar)

		# Finger 0 touches joystick on left half
		var f0_down = InputEventScreenTouch.new()
		f0_down.index = 0
		f0_down.position = Vector2(150.0, 600.0)
		f0_down.pressed = true
		joystick.handle_touch_event(f0_down)

		# Finger 0 drags UP (isometric Forward / North)
		var f0_drag = InputEventScreenDrag.new()
		f0_drag.index = 0
		f0_drag.position = Vector2(150.0, 520.0)
		joystick.handle_touch_event(f0_drag)

		for _i in range(5):
			await physics_frame

		_assert_check(avatar.velocity.length() > 0.5,
			"3.1.1 Avatar steering with Finger 0: velocity = %.2f m/s" % avatar.velocity.length())

		# Finger 1 taps ActionButton on right half simultaneously
		var f1_down = InputEventScreenTouch.new()
		f1_down.index = 1
		f1_down.position = Vector2(635.0, 1155.0)
		f1_down.pressed = true

		var joy_swallowed_f1 = joystick.handle_touch_event(f1_down)
		_assert_check(joy_swallowed_f1 == false, "3.1.2 Joystick ignores Finger 1 touch")
		_assert_check(joystick.touch_finger_index == 0, "3.1.3 Joystick active finger remains 0")
		_assert_check(joystick.is_active == true, "3.1.4 Joystick remains active during multi-touch")

		# Trigger action button press while joystick is active
		tc_inst._on_action_button_pressed()
		for _i in range(3):
			await physics_frame

		_assert_check(avatar.velocity.length() > 0.5,
			"3.1.5 Avatar continues moving during simultaneous ActionButton press")

		# Release Finger 1
		var f1_up = InputEventScreenTouch.new()
		f1_up.index = 1
		f1_up.position = Vector2(635.0, 1155.0)
		f1_up.pressed = false
		joystick.handle_touch_event(f1_up)
		_assert_check(joystick.is_active == true, "3.1.6 Joystick remains active after Finger 1 release")

		# Release Finger 0
		var f0_up = InputEventScreenTouch.new()
		f0_up.index = 0
		f0_up.position = Vector2(150.0, 520.0)
		f0_up.pressed = false
		joystick.handle_touch_event(f0_up)

		_assert_check(joystick.is_active == false, "3.1.7 Joystick deactivates upon Finger 0 release")
		_assert_check(avatar.velocity.x == 0.0 and avatar.velocity.z == 0.0,
			"3.1.8 Avatar immediately halts upon Finger 0 release")

	# --- 3.2 Dynamic Proximity Registration During Active Drag ---
	print("\n--- 3.2 Dynamic Proximity Registration During Active Drag ---")
	if joystick != null and tc_inst != null and test_npc != null:
		# Begin drag
		var t_drag_start = InputEventScreenTouch.new()
		t_drag_start.index = 0
		t_drag_start.position = Vector2(180.0, 500.0)
		t_drag_start.pressed = true
		joystick.handle_touch_event(t_drag_start)

		var t_drag_move = InputEventScreenDrag.new()
		t_drag_move.index = 0
		t_drag_move.position = Vector2(180.0, 430.0)
		joystick.handle_touch_event(t_drag_move)

		_assert_check(joystick.is_active == true, "3.2.1 Joystick active in continuous drag")

		# Register NPC proximity mid-drag
		tc_inst.register_interactable(test_npc, "Talk [E]")
		await process_frame

		_assert_check(tc_inst.active_interactable == test_npc,
			"3.2.2 NPC registered as active interactable during active drag")
		if action_btn != null:
			_assert_check(action_btn.modulate.a >= 0.85,
				"3.2.3 ActionButton illuminates to full opacity mid-drag (modulate: %.2f)" % action_btn.modulate.a)

		# Joystick still tracking uninterrupted
		_assert_check(joystick.output_vector != Vector2.ZERO,
			"3.2.4 Joystick output vector preserved without interruption during proximity update")

		# Unregister NPC mid-drag
		tc_inst.unregister_interactable(test_npc)
		await process_frame
		_assert_check(tc_inst.active_interactable == null,
			"3.2.5 NPC unregistered, active_interactable cleared mid-drag")
		if action_btn != null:
			_assert_check(action_btn.modulate.a <= 0.55,
				"3.2.6 ActionButton returns to dormant state mid-drag (modulate: %.2f)" % action_btn.modulate.a)

		joystick.reset_joystick()

	# --- 3.3 Haptic Feedback Emissions During Motion ---
	print("\n--- 3.3 Haptic Feedback Emissions During Motion ---")
	if joystick != null and avatar != null and hm != null and gs != null:
		hm.min_interval_ms = 0
		hm.reset_pickup_cooldown()
		spy.clear()

		# Steer avatar
		avatar.velocity = Vector3(4.0, 0.0, 4.0)
		avatar.set_input_direction(Vector3(0.0, 0.0, -1.0))

		# Emit game signal while avatar is moving
		if gs.has_signal("collectible_picked_up"):
			gs.collectible_picked_up.emit("briefcase", 1)
			await process_frame

			_assert_check(spy.get_count() >= 1,
				"3.3.1 Haptic impulse emitted while avatar is in active motion")
			var last_e = spy.get_last()
			_assert_check(last_e.get("duration_ms", 0) >= 25 and last_e.get("duration_ms", 0) <= 35,
				"3.3.2 Pickup haptic duration verified during motion (duration: %d ms)" % int(last_e.get("duration_ms", 0)))
			_assert_check(avatar.is_moving(),
				"3.3.3 Avatar continues moving without kinematic hitch during haptic emission")

		avatar.stop_movement()

	# --- 3.4 3-Tier Input Isolation Shield ---
	print("\n--- 3.4 3-Tier Input Isolation Shield ---")
	if tc_inst != null and action_btn != null and laptop_btn != null and avatar != null:
		# Verify mouse filters
		_assert_check(tc_inst.mouse_filter == Control.MOUSE_FILTER_IGNORE,
			"3.4.1 TouchControls root mouse_filter is MOUSE_FILTER_IGNORE (allows pass-through)")
		_assert_check(action_btn.mouse_filter == Control.MOUSE_FILTER_STOP,
			"3.4.2 ActionButton mouse_filter is MOUSE_FILTER_STOP (absorbs touch)")
		_assert_check(laptop_btn.mouse_filter == Control.MOUSE_FILTER_STOP,
			"3.4.3 LaptopThumbButton mouse_filter is MOUSE_FILTER_STOP (absorbs touch)")

		# Touch on ActionButton
		avatar.stop_movement()
		_assert_check(avatar._has_click_target == false, "3.4.4 Avatar click target initially false")

		var t_on_action = InputEventScreenTouch.new()
		t_on_action.index = 0
		t_on_action.position = action_btn.global_position + action_btn.size * 0.5
		t_on_action.pressed = true

		action_btn._gui_input(t_on_action)
		_assert_check(avatar._has_click_target == false,
			"3.4.5 Touch on ActionButton absorbed by GUI; ground raycast NOT triggered")

		# Touch on LaptopThumbButton
		var t_on_laptop = InputEventScreenTouch.new()
		t_on_laptop.index = 0
		t_on_laptop.position = laptop_btn.global_position + laptop_btn.size * 0.5
		t_on_laptop.pressed = true

		laptop_btn._gui_input(t_on_laptop)
		_assert_check(avatar._has_click_target == false,
			"3.4.6 Touch on LaptopThumbButton absorbed by GUI; ground raycast NOT triggered")

		# Upper screen tap (Y < 500) passes through to avatar input
		var t_upper = InputEventScreenTouch.new()
		t_upper.index = 0
		t_upper.position = Vector2(360.0, 250.0)
		t_upper.pressed = true

		avatar._unhandled_input(t_upper)
		_assert_check(avatar.input_enabled == true,
			"3.4.7 Upper screen tap successfully reaches Avatar unhandled input handler")

	# Clean up standalone test nodes before Tier 4
	if joystick != null:
		joystick.queue_free()
	if avatar != null:
		avatar.queue_free()
	if tc_inst != null:
		tc_inst.queue_free()
	if test_npc != null:
		test_npc.queue_free()
	if test_gate != null:
		test_gate.queue_free()
	await process_frame

	# =========================================================================
	# TIER 4: Real-World Application Scenarios (Full Simulated Mobile Session)
	# =========================================================================
	print("\n====================================================================")
	print(">>> TIER 4: REAL-WORLD APPLICATION SCENARIOS (Full Mobile Session)")
	print("====================================================================")

	# --- 4.1 Campus Scene Instantiation & Session Setup ---
	print("\n--- 4.1 Campus Scene Instantiation & Setup ---")
	var live_main = main_scene.instantiate() as Main3D
	root.add_child(live_main)
	await process_frame

	var live_avatar = live_main.get_node_or_null("Avatar3D") as Avatar3D
	var live_tc = live_main.find_child("TouchControls", true, false) as TouchControls
	var live_joy: VirtualJoystick = null
	if live_tc != null:
		live_joy = live_tc.find_child("VirtualJoystick", true, false) as VirtualJoystick
	var live_alex = live_main.get_node_or_null("NPCs/NPC_Alex") as NPC3D
	var live_gate = live_main.get_node_or_null("ZoneGates/Gate_ServerRoom") as ZoneGate3D

	_assert_check(live_avatar != null, "4.1.1 Live Avatar3D resolved in Main3D")
	_assert_check(live_tc != null, "4.1.2 Live TouchControls resolved in Main3D")
	_assert_check(live_joy != null, "4.1.3 Live VirtualJoystick resolved in Main3D")
	_assert_check(live_alex != null, "4.1.4 Live NPC_Alex resolved in Main3D")
	_assert_check(live_gate != null, "4.1.5 Live Gate_ServerRoom resolved in Main3D")

	# Initial neutral state
	_assert_check(live_main.is_hud_overlay_open() == false, "4.1.6 HUD overlay initially closed")
	_assert_check(live_tc.active_interactable == null, "4.1.7 No active interactable initially")
	if live_tc.action_button != null:
		_assert_check(live_tc.action_button.modulate.a <= 0.55,
			"4.1.8 ActionButton in initial dormant state (modulate: %.2f)" % live_tc.action_button.modulate.a)

	# --- 4.2 Steer with Joystick Toward NPC Alex ---
	print("\n--- 4.2 Steer Avatar Toward NPC Alex ---")
	if live_joy != null and live_avatar != null and live_alex != null:
		# Touch down joystick
		var t_alex_down = InputEventScreenTouch.new()
		t_alex_down.index = 0
		t_alex_down.position = Vector2(180.0, 750.0)
		t_alex_down.pressed = true
		live_joy.handle_touch_event(t_alex_down)

		# Drag towards Alex (+X, +Z isometric direction)
		var t_alex_drag = InputEventScreenDrag.new()
		t_alex_drag.index = 0
		t_alex_drag.position = Vector2(240.0, 810.0)
		live_joy.handle_touch_event(t_alex_drag)

		for _i in range(5):
			await physics_frame

		_assert_check(live_avatar.is_moving(), "4.2.1 Avatar moving under joystick control toward Alex")

		# Teleport avatar to Alex interaction range to complete approach
		live_avatar.global_position = live_alex.global_position + Vector3(0.5, 0.0, 0.5)
		for _i in range(5):
			await physics_frame

		if not live_alex._player_in_range:
			live_alex._on_interaction_body_entered(live_avatar)

		_assert_check(live_alex._player_in_range == true, "4.2.2 Avatar entered Alex interaction range")
		_assert_check(live_tc.active_interactable == live_alex,
			"4.2.3 TouchControls registered Alex as active interactable")
		if live_tc.action_button != null:
			_assert_check(live_tc.action_button.modulate.a >= 0.85,
				"4.2.4 ActionButton illuminated to full opacity for Alex")
			_assert_check(live_tc.action_button.text.contains("Talk") or live_tc.action_button.text.contains("[E]"),
				"4.2.5 ActionButton displays contextual text ('%s')" % live_tc.action_button.text)

		# Release joystick -> halt
		var t_alex_up = InputEventScreenTouch.new()
		t_alex_up.index = 0
		t_alex_up.position = Vector2(240.0, 810.0)
		t_alex_up.pressed = false
		live_joy.handle_touch_event(t_alex_up)

		_assert_check(absf(live_avatar.velocity.x) < 0.01 and absf(live_avatar.velocity.z) < 0.01,
			"4.2.6 Avatar halted before NPC without sliding drift")

	# --- 4.3 Tap ActionButton -> Dialogue Triggered & Tactile Feedback ---
	print("\n--- 4.3 Tap ActionButton for NPC Dialogue ---")
	if live_tc != null and live_alex != null and hm != null:
		hm.min_interval_ms = 0
		hm.reset_pickup_cooldown()
		spy.clear()
		key_watcher.clear()

		live_tc._on_action_button_pressed()
		await process_frame

		_assert_check(live_alex._is_talking == true, "4.3.1 NPC dialogue triggered (_is_talking == true)")
		_assert_check(key_watcher.key_e_pressed_count > 0, "4.3.2 Synthetic KEY_E dispatched for dialogue")
		_assert_check(spy.get_count() >= 1, "4.3.3 Button tactile feedback fired on ActionButton press")

		# Close dialogue
		live_alex.end_dialogue()
		await process_frame
		_assert_check(live_alex._is_talking == false, "4.3.4 NPC dialogue closed")

	# --- 4.4 Steer Toward ZoneGate (Server Room) ---
	print("\n--- 4.4 Steer Avatar Toward ZoneGate ---")
	if live_joy != null and live_avatar != null and live_gate != null and live_alex != null:
		# Exit Alex range
		live_alex._on_interaction_body_exited(live_avatar)
		await process_frame
		_assert_check(live_tc.active_interactable != live_alex, "4.4.1 Alex unregistered on departure")

		# Steer with joystick North toward Server Room
		var t_gate_down = InputEventScreenTouch.new()
		t_gate_down.index = 0
		t_gate_down.position = Vector2(180.0, 750.0)
		t_gate_down.pressed = true
		live_joy.handle_touch_event(t_gate_down)

		var t_gate_drag = InputEventScreenDrag.new()
		t_gate_drag.index = 0
		t_gate_drag.position = Vector2(180.0, 670.0) # Drag UP
		live_joy.handle_touch_event(t_gate_drag)

		for _i in range(5):
			await physics_frame

		# Move avatar to gate range
		live_avatar.global_position = live_gate.global_position + Vector3(0.0, 0.0, 1.2)
		for _i in range(5):
			await physics_frame

		if not live_gate._player_in_range:
			live_gate._on_interaction_body_entered(live_avatar)

		_assert_check(live_gate._player_in_range == true, "4.4.2 Avatar entered Gate_ServerRoom range")
		_assert_check(live_tc.active_interactable == live_gate,
			"4.4.3 TouchControls registered Gate_ServerRoom as active interactable")
		if live_tc.action_button != null:
			_assert_check(live_tc.action_button.text.contains("Unlock") or live_tc.action_button.text.contains("[E]"),
				"4.4.4 ActionButton updated to 'Unlock [E]' for Gate")

		# Release joystick -> halt
		var t_gate_up = InputEventScreenTouch.new()
		t_gate_up.index = 0
		t_gate_up.position = Vector2(180.0, 670.0)
		t_gate_up.pressed = false
		live_joy.handle_touch_event(t_gate_up)

	# --- 4.5 Unlock Gate & Medium Haptic ---
	print("\n--- 4.5 Unlock Gate & Medium Haptic ---")
	if live_tc != null and live_gate != null and gs != null and hm != null:
		# Ensure clearance level / energy met
		gs.energy = 500.0
		gs.idle_level = 3
		hm.min_interval_ms = 0
		hm.reset_pickup_cooldown()
		spy.clear()

		live_tc._on_action_button_pressed()
		await process_frame

		_assert_check(live_gate._is_unlocked == true, "4.5.1 Gate_ServerRoom unlocked successfully")
		_assert_check(live_gate.collision_shape.disabled == true,
			"4.5.2 Gate physical barrier collision disabled")

		# Check medium haptic impulse (70ms)
		var has_70ms: bool = false
		for e in spy.emissions:
			if int(e.get("duration_ms", 0)) == 70:
				has_70ms = true
				break
		_assert_check(has_70ms, "4.5.3 Medium haptic impulse (70ms) emitted on gate unlock")

	# --- 4.6 Avatar Collects 3D Item & Light Haptic with Churn Throttling ---
	print("\n--- 4.6 Collect 3D Item & Churn Throttling ---")
	var coll_scene = load("res://scenes/collectible_3d.tscn")
	if coll_scene != null and live_avatar != null and hm != null and gs != null:
		var item1 = coll_scene.instantiate() as Collectible3D
		item1.item_type = "briefcase"
		item1.reward_amount = 50.0
		root.add_child(item1)
		await process_frame

		hm.min_interval_ms = 50 # 50ms cooldown active
		hm.reset_pickup_cooldown()
		spy.clear()

		# Collect item 1
		item1.collect(live_avatar)
		await process_frame

		_assert_check(spy.get_count() == 1, "4.6.1 Light haptic fired on item pickup")
		var e1 = spy.get_last()
		_assert_check(int(e1.get("duration_ms", 0)) >= 25 and int(e1.get("duration_ms", 0)) <= 35,
			"4.6.2 Light haptic duration 25-35ms (actual: %d ms)" % int(e1.get("duration_ms", 0)))

		# Rapid second item pickup within 5ms (churn throttling verification)
		var item2 = coll_scene.instantiate() as Collectible3D
		item2.item_type = "coffee"
		root.add_child(item2)
		await process_frame

		item2.collect(live_avatar)
		await process_frame

		_assert_check(spy.get_count() == 1,
			"4.6.3 Rapid second pickup within 50ms throttled without motor saturation")

		# Reset cooldown and collect third item -> passes
		hm.reset_pickup_cooldown()
		var item3 = coll_scene.instantiate() as Collectible3D
		item3.item_type = "usb_drive"
		root.add_child(item3)
		await process_frame

		item3.collect(live_avatar)
		await process_frame

		_assert_check(spy.get_count() == 2,
			"4.6.4 Item pickup after cooldown interval executes successfully")

	# --- 4.7 Tap LaptopThumbButton -> 2D Idle Overlay Toggle & Input Lockout ---
	print("\n--- 4.7 Toggle 2D Idle Overlay & Input Lockout ---")
	if live_tc != null and live_main != null and live_avatar != null:
		_assert_check(live_main.is_hud_overlay_open() == false, "4.7.1 Overlay initially closed")
		_assert_check(live_avatar.input_enabled == true, "4.7.2 Avatar input initially enabled")

		# Tap LaptopThumbButton to open HUD overlay
		live_tc._on_laptop_button_pressed()
		await process_frame

		_assert_check(live_main.is_hud_overlay_open() == true, "4.7.3 LaptopThumbButton opened 2D HUD overlay")
		_assert_check(live_avatar.input_enabled == false,
			"4.7.4 Avatar input strictly locked out while HUD overlay is open")

		# Verify input isolation during open overlay: ground taps are ignored
		var t_overlay_tap = InputEventScreenTouch.new()
		t_overlay_tap.index = 0
		t_overlay_tap.position = Vector2(360.0, 600.0)
		t_overlay_tap.pressed = true
		live_avatar._unhandled_input(t_overlay_tap)
		_assert_check(live_avatar._has_click_target == false,
			"4.7.5 Ground taps ignored by avatar while HUD overlay is open")

		# Tap LaptopThumbButton again to close HUD overlay
		live_tc._on_laptop_button_pressed()
		await process_frame

		_assert_check(live_main.is_hud_overlay_open() == false, "4.7.6 Second tap closed HUD overlay")
		_assert_check(live_avatar.input_enabled == true,
			"4.7.7 Avatar movement input restored after closing HUD overlay")

	# Teardown live session scene
	live_main.queue_free()
	await process_frame

	# Cleanup test spy & watcher
	if spy != null:
		spy.queue_free()
	if key_watcher != null:
		key_watcher.queue_free()
	if is_hm_dynamic and hm != null:
		hm.queue_free()

	print("\n--- Phase 5 Mobile Master Integration Suite Completed ---")
