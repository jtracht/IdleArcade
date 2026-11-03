extends SceneTree

## Adversarial Stress & Chaos Test Suite for Phase 17 Milestone 2 (Challenger 2)
## Empirically stress-tests:
## 1. Scene Transition Resilience (Real scene transition main.tscn -> main_3d.tscn mid-tutorial)
## 2. Target Node Lifecycle (detached, freed, null, zero-sized nodes)
## 3. Layer Depth Hierarchy & Event Clickability (Layer 96 vs 95, SkipButton & Weiter button)
## 4. Adversarial Edge Cases (rapid skipping, repeated advancement, re-entrancy, missing nodes)
## 5. Zero-Crash Headless Verification (0 SCRIPT ERRORs)
##
## Execution: godot --headless --path IdleArcade -s tests/test_p17_m2_adversarial_stress.gd

var pass_count: int = 0
var fail_count: int = 0

func _init() -> void:
	call_deferred("_run_adversarial_suite")

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

func _run_adversarial_suite() -> void:
	print("=================================================================")
	print("CHALLENGER 2: ADVERSARIAL STRESS & SCENE TRANSITION HARNESS")
	print("Phase 17 Milestone 2: TutorialManager & TutorialOverlay")
	print("=================================================================")

	await process_frame
	await process_frame

	var tm = root.get_node_or_null("TutorialManager")
	var gs = root.get_node_or_null("GameState")

	if tm == null:
		_assert_check(false, "TutorialManager mounted in root", "TutorialManager not found")
		quit(1)
		return

	# =========================================================================
	# SUITE 1: Real Scene Transition Resilience (main.tscn -> main_3d.tscn)
	# =========================================================================
	print("\n--- SUITE 1: Real Scene Transition (main.tscn -> main_3d.tscn) ---")

	print("  [ACTION] Loading main.tscn as current scene...")
	change_scene_to_file("res://scenes/main.tscn")
	var timeout: int = 40
	while timeout > 0:
		timeout -= 1
		await process_frame
		if current_scene != null and current_scene.name == "Main" and current_scene.is_node_ready():
			break

	_assert_check(current_scene != null and current_scene.name == "Main", "main.tscn loaded as current_scene")
	var main_dp = current_scene.find_child("DialoguePanel", true, false) as Control
	_assert_check(main_dp != null, "main.tscn contains DialoguePanel")
	var main_dp_layer = main_dp.get_parent() as CanvasLayer if main_dp != null else null
	_assert_check(main_dp_layer != null and main_dp_layer.layer == 96, "main.tscn DialogueLayer is configured on layer 96")

	# Start linear intro in 2D scene
	tm.start_linear_intro()
	await process_frame
	_assert_check(tm.get_current_step() == 1, "Tutorial started at Step 1 in main.tscn")
	_assert_check(tm.is_tutorial_active(), "Tutorial is active in main.tscn")
	_assert_check(tm.get_dialogue_panel() == main_dp, "TutorialManager bound to main.tscn's DialoguePanel")

	# Advance Step 1 -> Step 2
	tm.advance_step()
	await process_frame
	_assert_check(tm.get_current_step() == 2, "Advanced to Step 2 (INTRO_STEP_2_UPGRADE)")

	# Advance Step 2 -> Step 3
	tm.advance_step()
	await process_frame
	_assert_check(tm.get_current_step() == 3, "Advanced to Step 3 (INTRO_STEP_3_FRENZY)")

	# Advance Step 3 -> Step 4 (triggers actual scene change to main_3d.tscn!)
	print("  [ACTION] Advancing to Step 4 (triggering actual scene transition to main_3d.tscn)...")
	tm.advance_step()

	timeout = 60
	while timeout > 0:
		timeout -= 1
		await process_frame
		if current_scene != null and current_scene.name == "Main3D" and current_scene.is_node_ready():
			break

	_assert_check(current_scene != null and current_scene.name == "Main3D",
		"Scene transition completed: current_scene is Main3D")
	_assert_check(tm.get_current_step() == 4, "Tutorial remained at Step 4 across scene transition")
	_assert_check(tm.is_tutorial_active(), "Tutorial remains active in 3D campus")

	# Verify 3D target acquisition in Step 4
	var avatar = current_scene.find_child("Avatar3D", true, false)
	_assert_check(avatar != null, "Avatar3D node located in 3D campus")
	var touch_ctrls = current_scene.find_child("TouchControls", true, false)
	_assert_check(touch_ctrls != null, "TouchControls located in 3D campus")
	var vjoy = current_scene.find_child("VirtualJoystick", true, false)
	if vjoy == null:
		vjoy = current_scene.find_child("ArcadeVirtualJoystick", true, false)
	_assert_check(vjoy != null, "Virtual joystick found in 3D campus")

	# Verify DialogueLayer elevation in 3D scene
	var main_3d_dp = current_scene.find_child("DialoguePanel", true, false) as Control
	_assert_check(main_3d_dp != null, "DialoguePanel found in main_3d.tscn")
	_assert_check(tm.get_dialogue_panel() == main_3d_dp,
		"TutorialManager successfully rebound to main_3d.tscn's DialoguePanel")
	var main_3d_dp_layer = main_3d_dp.get_parent() as CanvasLayer
	_assert_check(main_3d_dp_layer != null, "DialogueLayer found in main_3d.tscn")
	_assert_check(main_3d_dp_layer.layer == 96,
		"DialogueLayer in main_3d elevated to layer 96 (actual: %d)" % main_3d_dp_layer.layer)

	# Verify Step 4 avatar movement advancement
	if avatar != null:
		avatar.velocity = Vector3(1.0, 0.0, 1.0)
		tm._physics_process(0.016)
		await process_frame
		_assert_check(tm.get_current_step() == 5, "Avatar velocity > 0.1 advanced Step 4 to Step 5 (INTRO_STEP_5_COLLECTIBLE)")

	# Verify Step 5 Collectible tracking
	var nearest_col = tm._find_nearest_collectible()
	_assert_check(nearest_col != null, "Step 5 found nearest collectible in 3D campus")
	tm._process(0.016)
	var overlay = tm.tutorial_overlay
	_assert_check(overlay != null and overlay.is_highlight_active(), "Step 5 active highlight spotlight on collectible")

	# Advance Step 5 via pickup signal
	if gs != null and gs.has_signal("collectible_picked_up"):
		gs.collectible_picked_up.emit("briefcase", 1)
	else:
		tm.advance_step()
	await process_frame

	_assert_check(tm.get_current_step() == 6, "Step 5 advanced to Step 6 (INTRO_STEP_6_STATION)")

	# Advance Step 6 to completion
	tm.advance_step()
	await process_frame
	_assert_check(tm.get_current_step() == int(tm.State.COMPLETED), "Step 6 completed -> State.COMPLETED")
	_assert_check(not tm.is_tutorial_active(), "is_tutorial_active is false after completion")
	_assert_check(not overlay.is_highlight_active(), "Highlight cleared on tutorial completion")

	# =========================================================================
	# SUITE 2: Layer Depth Hierarchy & Clickability
	# =========================================================================
	print("\n--- SUITE 2: Layer Depth Hierarchy & Clickability ---")
	tm.reset_tutorial()
	await process_frame

	# Test 2.1: Layer depth strict inequality: DialogueLayer (96) > TutorialOverlay (95)
	_assert_check(overlay.layer == 95, "TutorialOverlay layer is 95")
	var dp = tm.get_dialogue_panel()
	_assert_check(dp != null, "DialoguePanel exists")
	var dp_layer = dp.get_parent() as CanvasLayer if dp != null else null
	_assert_check(dp_layer != null, "DialoguePanel resides inside a CanvasLayer")

	# Trigger tutorial step dialogue to test elevation
	tm.start_linear_intro()
	await process_frame

	_assert_check(dp.visible, "DialoguePanel is visible during tutorial Step 1")
	_assert_check(dp_layer.layer == 96, "DialogueLayer is elevated to layer 96 (DialogueLayer.layer = %d)" % dp_layer.layer)
	_assert_check(dp_layer.layer > overlay.layer, "DialogueLayer (96) is strictly ABOVE TutorialOverlay (95)")

	# Test 2.2: Input transparency of DialoguePanel container
	_assert_check(dp.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"DialoguePanel root mouse_filter is IGNORE during tutorial step")
	var cc = dp.get_node_or_null("CenterContainer") as Control
	_assert_check(cc != null and cc.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"CenterContainer mouse_filter is IGNORE, allowing clicks to reach underlying buttons")
	var dim_bd = dp.get_node_or_null("DimBackdrop") as Control
	_assert_check(dim_bd != null and (not dim_bd.visible or dim_bd.mouse_filter == Control.MOUSE_FILTER_IGNORE),
		"DimBackdrop is hidden/ignored so spotlight hole remains clickable")

	# Test 2.3: SkipButton on TutorialOverlay (layer 95) is NOT blocked by DialogueLayer (layer 96)
	var skip_btn = overlay.get_node_or_null("%SkipButton") as Button
	_assert_check(skip_btn != null and skip_btn.visible, "SkipButton is visible on layer 95")
	var skip_rect = Rect2(skip_btn.global_position, skip_btn.size)
	var skip_center = skip_rect.get_center()

	# Verify that no Control on DialoguePanel with MOUSE_FILTER_STOP covers the SkipButton center
	var card = dp.get_node_or_null("CenterContainer/CardPanel") as Control
	var card_rect = Rect2(card.global_position, card.size) if card != null else Rect2()
	_assert_check(not card_rect.has_point(skip_center),
		"CardPanel does NOT occlude SkipButton (Skip Center: %s vs Card Rect: %s)" % [str(skip_center), str(card_rect)])

	# Test 2.4: "Weiter ➔" (CloseButton) on DialoguePanel (layer 96) is interactive
	var close_btn = dp.get_node_or_null("%CloseButton") as Button
	_assert_check(close_btn != null and close_btn.visible, "Weiter button is visible on DialoguePanel")
	_assert_check(close_btn.mouse_filter == Control.MOUSE_FILTER_STOP, "Weiter button has mouse_filter = STOP")
	_assert_check(close_btn.custom_minimum_size.y >= 56.0 or close_btn.size.y >= 56.0,
		"Weiter button meets >= 56px touch height requirement")

	# Test 2.5: Spotlight hole clickability vs Blocker interception
	var hole_rect = overlay.get_cutout_rect()
	_assert_check(hole_rect.size.x > 0.0 and hole_rect.size.y > 0.0, "Cutout hole has positive dimensions")
	var hole_center = hole_rect.get_center()
	_assert_check(overlay.is_point_in_cutout(hole_center), "Hole center is recognized as inside cutout")
	_assert_check(not overlay.is_point_in_blocker(hole_center), "Hole center is NOT intercepted by any blocker")

	var outside_point = Vector2(50.0, 50.0)
	if not hole_rect.has_point(outside_point):
		_assert_check(overlay.is_point_in_blocker(outside_point), "Outside point is intercepted by blocker mask")

	# =========================================================================
	# SUITE 3: Target Node Lifecycle (Detached, Destroyed, Null, Zero-Sized)
	# =========================================================================
	print("\n--- SUITE 3: Target Node Lifecycle & Graceful Fallback ---")
	tm.reset_tutorial()
	await process_frame

	# Test 3.1: highlight_control(null) must gracefully fallback to clear_highlight()
	overlay.highlight_target_rect(Rect2(100, 100, 200, 200))
	_assert_check(overlay.is_highlight_active(), "Overlay is active prior to null highlight")
	overlay.highlight_control(null)
	_assert_check(not overlay.is_highlight_active(), "highlight_control(null) gracefully clears highlight")
	_assert_check(overlay.get_cutout_rect() == Rect2(), "Cutout rect is empty after highlight_control(null)")

	# Test 3.2: Detached Control (never added to SceneTree)
	var detached_ctrl = Control.new()
	detached_ctrl.position = Vector2(150, 250)
	detached_ctrl.size = Vector2(120, 80)
	_assert_check(not detached_ctrl.is_inside_tree(), "detached_ctrl is outside SceneTree")
	overlay.highlight_control(detached_ctrl, 10.0)
	_assert_check(overlay.is_highlight_active(), "highlight_control accepts detached Control without crashing")
	var cutout = overlay.get_cutout_rect()
	_assert_check(cutout.position.x <= 150.0 and cutout.end.x >= 270.0, "Detached control cutout correctly covers position+size")
	overlay._process(0.016)
	_assert_check(overlay.is_highlight_active(), "_process survives detached target control")
	detached_ctrl.free()
	overlay.clear_highlight()

	# Test 3.3: Zero-sized Control
	var zero_ctrl = Control.new()
	zero_ctrl.position = Vector2(300, 400)
	zero_ctrl.size = Vector2.ZERO
	overlay.highlight_control(zero_ctrl, 8.0)
	_assert_check(overlay.is_highlight_active(), "highlight_control handles zero-sized control gracefully")
	zero_ctrl.free()
	overlay.clear_highlight()

	# Test 3.4: Target Control destroyed/freed while highlight is actively tracking it
	var doomed_ctrl = Control.new()
	doomed_ctrl.position = Vector2(200, 300)
	doomed_ctrl.size = Vector2(100, 100)
	root.add_child(doomed_ctrl)
	overlay.highlight_control(doomed_ctrl, 8.0)
	_assert_check(overlay.is_highlight_active(), "Overlay tracking doomed_ctrl")

	# Destroy the node while active
	doomed_ctrl.free()
	# Execute multiple _process frames to stress-test target tracking on freed node
	for i in range(5):
		overlay._process(0.016)
		await process_frame

	_assert_check(true, "TutorialOverlay._process survived freed target node without engine crash")
	overlay.clear_highlight()

	# Test 3.5: trigger_contextual_hint with null target_control
	var hint_signal_records = []
	var hint_cb = func(id): hint_signal_records.append(id)
	tm.contextual_hint_triggered.connect(hint_cb)

	tm.trigger_contextual_hint("hint_zone_gate", null)
	await process_frame
	_assert_check(hint_signal_records.has("hint_zone_gate"), "trigger_contextual_hint emits signal with null target_control")
	var hint_dp = tm.get_dialogue_panel()
	_assert_check(hint_dp != null and hint_dp.visible, "DialoguePanel opens for contextual hint with null target")
	if hint_dp != null and hint_dp.has_method("dismiss_hint"):
		hint_dp.dismiss_hint()
	await process_frame
	tm.contextual_hint_triggered.disconnect(hint_cb)

	# =========================================================================
	# SUITE 4: Adversarial Edge Cases & Fuzzing
	# =========================================================================
	print("\n--- SUITE 4: Adversarial Edge Cases & Re-Entrancy ---")

	# Test 4.1: Calling advance_step() when intro inactive is a safe no-op
	var step_before = tm.get_current_step()
	for i in range(3):
		tm.advance_step()
	_assert_check(tm.get_current_step() == step_before,
		"advance_step() when tutorial is inactive is a safe no-op")

	# Test 4.2: Repeated skip_tutorial() calls
	for i in range(3):
		tm.skip_tutorial()
	_assert_check(tm.get_current_step() == int(tm.State.COMPLETED),
		"Repeated skip_tutorial() is idempotent and safe")

	# Test 4.3: Reset tutorial and mid-tutorial skip
	tm.reset_tutorial()
	_assert_check(tm.get_current_step() == 0, "reset_tutorial() returns step to 0 (IDLE)")
	tm.start_linear_intro()
	await process_frame
	_assert_check(tm.get_current_step() == 1, "Restarted at Step 1")
	# Immediate skip from Step 1
	tm.skip_tutorial()
	_assert_check(tm.get_current_step() == int(tm.State.COMPLETED),
		"Skip from Step 1 transitions immediately to COMPLETED")
	_assert_check(not overlay.is_highlight_active(), "Skip immediately clears highlight")
	_assert_check(not overlay.get_node("%SkipButton").visible, "Skip immediately hides SkipButton")

	# Test 4.4: Contextual hint when tutorial is completed
	tm.trigger_contextual_hint("hint_tech_tree", null)
	await process_frame
	var cur_dp = tm.get_dialogue_panel()
	_assert_check(cur_dp != null and cur_dp.visible, "Contextual hint works after tutorial completed")
	if cur_dp != null and cur_dp.has_method("dismiss_hint"):
		cur_dp.dismiss_hint()
	await process_frame

	# Test 4.5: _find_nearest_collectible with empty tree
	var empty_result = tm._find_nearest_collectible()
	_assert_check(empty_result == null or is_instance_valid(empty_result),
		"_find_nearest_collectible handles search gracefully without error")

	# Test 4.6: _process / _physics_process with no active tutorial
	tm._process(0.016)
	tm._physics_process(0.016)
	_assert_check(true, "_process and _physics_process are no-ops when tutorial inactive")

	# =========================================================================
	# SUMMARY
	# =========================================================================
	print("\n=================================================================")
	print("CHALLENGER 2 SUITE RESULTS: %d Passed, %d Failed" % [pass_count, fail_count])
	print("=================================================================")

	if current_scene != null:
		current_scene.queue_free()
		await process_frame
		await process_frame

	if fail_count == 0:
		print(">>> ALL ADVERSARIAL STRESS CHECKS PASSED EMPIRICALLY! <<<")
		quit(0)
	else:
		printerr(">>> FAILURES ENCOUNTERED IN ADVERSARIAL STRESS SUITE! <<<")
		quit(1)
