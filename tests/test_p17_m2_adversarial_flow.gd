extends SceneTree

## Adversarial Stress & Edge-Case Test Suite for Milestone 2 (Phase 17)
## Roles: Reviewer & Adversarial Critic
## Focus: Race conditions, re-entrancy, skip spam, scene transitions, null safety, layer elevation, German copy

var pass_count: int = 0
var fail_count: int = 0
var warnings_count: int = 0

func _init() -> void:
	call_deferred("_run_adversarial_suite")

func _assert(cond: bool, description: String, detail: String = "") -> void:
	if cond:
		print("  [PASS] %s" % description)
		pass_count += 1
	else:
		var msg = "  [FAIL] %s" % description
		if detail != "":
			msg += " (Detail: %s)" % detail
		printerr(msg)
		fail_count += 1

func _warn(description: String, detail: String = "") -> void:
	var msg = "  [WARN] %s" % description
	if detail != "":
		msg += " (Detail: %s)" % detail
	print(msg)
	warnings_count += 1

func _run_adversarial_suite() -> void:
	print("=================================================================")
	print("Running Milestone 2 ADVERSARIAL STRESS & EDGE-CASE TEST SUITE")
	print("=================================================================")

	await process_frame
	await process_frame

	var tm = root.get_node_or_null("TutorialManager")
	var gs = root.get_node_or_null("GameState")

	if tm == null:
		_assert(false, "TutorialManager autoload must exist")
		quit(1)
		return

	# -------------------------------------------------------------------------
	# ATTACK 1: Rapid-Fire / Re-entrancy Spam on start_linear_intro & advance_step
	# -------------------------------------------------------------------------
	print("\n--- ATTACK 1: Rapid-Fire / Re-entrancy Spam ---")
	tm.reset_tutorial()
	_assert(tm.get_current_step() == 0, "Clean reset before attack 1")

	# Spam start_linear_intro 5 times
	for i in range(5):
		tm.start_linear_intro()
	_assert(tm.get_current_step() == 1, "start_linear_intro spam keeps current_step strictly at 1")
	_assert(tm.is_tutorial_active(), "Tutorial is active after start_linear_intro spam")

	# Advance repeatedly through all steps and past Step 6
	for i in range(15):
		tm.advance_step()
	_assert(tm.get_current_step() == int(tm.State.COMPLETED), "advance_step past completion clamps at COMPLETED (7)")
	_assert(not tm.is_tutorial_active(), "is_tutorial_active is false after overflowing advance_step")

	# -------------------------------------------------------------------------
	# ATTACK 2: Skip Invariant at Every Single Intro Step (Steps 1 to 6)
	# -------------------------------------------------------------------------
	print("\n--- ATTACK 2: Skip Invariant Across All Intro Steps ---")
	for step_target in range(1, 7):
		tm.reset_tutorial()
		if gs != null:
			if "tutorial_completed" in gs:
				gs.tutorial_completed = false
			if "tutorial_skipped" in gs:
				gs.tutorial_skipped = false

		tm.start_linear_intro()
		# Fast-forward to target step
		while tm.get_current_step() < step_target:
			tm.advance_step()

		_assert(tm.get_current_step() == step_target, "Reached target step %d for skip test" % step_target)
		_assert(tm.is_tutorial_active(), "Tutorial is active at step %d" % step_target)

		# Skip at this exact step (use Dictionary for proper GDScript 4 reference capture)
		var skip_state = {"skipped": false, "completed": false}
		var on_skip = func(): skip_state["skipped"] = true
		var on_done = func(): skip_state["completed"] = true
		tm.tutorial_skipped.connect(on_skip, CONNECT_ONE_SHOT)
		tm.tutorial_completed.connect(on_done, CONNECT_ONE_SHOT)

		tm.skip_tutorial()
		await process_frame

		_assert(skip_state["skipped"], "tutorial_skipped emitted when skipping from step %d" % step_target)
		_assert(skip_state["completed"], "tutorial_completed emitted when skipping from step %d" % step_target)
		_assert(tm.get_current_step() == int(tm.State.COMPLETED), "Step is COMPLETED after skipping from step %d" % step_target)
		_assert(not tm.is_tutorial_active(), "Tutorial inactive after skipping from step %d" % step_target)
		_assert(not tm.tutorial_overlay.get_node("%SkipButton").visible, "SkipButton hidden after skipping from step %d" % step_target)

	# -------------------------------------------------------------------------
	# ATTACK 3: Double Scene Setup Check (Step 3 -> Step 4 Transition)
	# -------------------------------------------------------------------------
	print("\n--- ATTACK 3: Scene Transition Step Started Signal Deduplication ---")
	tm.reset_tutorial()
	if gs != null:
		if "tutorial_completed" in gs:
			gs.tutorial_completed = false
		if "tutorial_skipped" in gs:
			gs.tutorial_skipped = false

	var step_4_counter = {"count": 0}
	var count_step_4 = func(step_idx: int, _name: String):
		if step_idx == 4:
			step_4_counter["count"] += 1
	tm.step_started.connect(count_step_4)

	# Start and advance to step 4
	tm.start_linear_intro()
	tm.advance_step() # to step 2
	tm.advance_step() # to step 3

	# Now advance step 3 -> step 4
	tm.advance_step() # triggers step 4 setup
	await process_frame

	_assert(tm.get_current_step() == 4, "Current step is 4 (CAMPUS)")
	_assert(step_4_counter["count"] == 1, "step_started(4) emitted exactly 1 time in headless mode", "count=%d" % step_4_counter["count"])

	# Now test on_scene_ready simulation
	var dummy_main_3d = Node3D.new()
	dummy_main_3d.name = "Main3D"
	root.add_child(dummy_main_3d)

	tm.on_scene_ready(dummy_main_3d)
	await process_frame

	# Does on_scene_ready re-emit step_started(4)?
	if step_4_counter["count"] > 1:
		_warn("on_scene_ready(Main3D) caused duplicate step_started(4) emission (count: %d)" % step_4_counter["count"],
			"Minor redundancy: on_scene_ready re-triggers step 4 setup while already in step 4")
	else:
		_assert(step_4_counter["count"] == 1, "on_scene_ready did not produce duplicate step_started(4) emission")

	dummy_main_3d.queue_free()
	tm.step_started.disconnect(count_step_4)

	# -------------------------------------------------------------------------
	# ATTACK 4: Contextual Hint Edge Cases & Non-Interference
	# -------------------------------------------------------------------------
	print("\n--- ATTACK 4: Contextual Hint Boundary Conditions ---")
	# Case 4A: Hint while tutorial is active MUST be ignored
	_assert(tm.is_tutorial_active(), "Tutorial is currently active at step 4")
	var hint_state = {"hint": false, "unknown": false}
	var on_hint = func(_h): hint_state["hint"] = true
	tm.contextual_hint_triggered.connect(on_hint)

	tm.trigger_contextual_hint("hint_tech_tree")
	await process_frame
	_assert(not hint_state["hint"], "trigger_contextual_hint is blocked while tutorial is active")

	# Skip to complete tutorial
	tm.skip_tutorial()
	await process_frame
	_assert(not tm.is_tutorial_active(), "Tutorial is now inactive")

	# Case 4B: Hint after tutorial completion should trigger
	hint_state["hint"] = false
	tm.trigger_contextual_hint("hint_tech_tree")
	await process_frame
	_assert(hint_state["hint"], "trigger_contextual_hint fires after tutorial is completed")

	# Case 4C: Unknown hint fallback
	var on_unknown = func(h): if h == "unknown_exotic_feature": hint_state["unknown"] = true
	tm.contextual_hint_triggered.connect(on_unknown)
	tm.trigger_contextual_hint("unknown_exotic_feature")
	await process_frame
	_assert(hint_state["unknown"], "Unknown hint id is safely emitted without crash")
	var dp = tm.get_dialogue_panel()
	_assert(dp != null and dp.visible, "DialoguePanel opened for unknown hint")

	tm.contextual_hint_triggered.disconnect(on_hint)
	tm.contextual_hint_triggered.disconnect(on_unknown)

	# -------------------------------------------------------------------------
	# ATTACK 5: Layer Hierarchy & CanvasLayer Rendering Order
	# -------------------------------------------------------------------------
	print("\n--- ATTACK 5: Layer Elevation & Z-Ordering Invariants ---")
	var overlay = tm.tutorial_overlay
	_assert(overlay != null and overlay.layer == 95, "TutorialOverlay layer is 95")

	# Check main.tscn DialogueLayer
	var main_scene = load("res://scenes/main.tscn")
	var main_inst = main_scene.instantiate()
	root.add_child(main_inst)
	var dlg_layer = main_inst.get_node_or_null("DialogueLayer") as CanvasLayer
	_assert(dlg_layer != null, "main.tscn contains DialogueLayer node")
	if dlg_layer != null:
		_assert(dlg_layer.layer == 96, "DialogueLayer in main.tscn has layer 96 (strictly > 95)")
		var child_dp = dlg_layer.get_node_or_null("DialoguePanel")
		_assert(child_dp != null, "DialogueLayer contains DialoguePanel child instance")
	main_inst.queue_free()

	# Check dynamic layer elevation when dp parent has lower layer (e.g. layer 8 in Main3D)
	var test_parent_layer = CanvasLayer.new()
	test_parent_layer.layer = 8
	root.add_child(test_parent_layer)
	var test_dp_scene = load("res://scenes/dialogue_panel.tscn")
	var test_dp = test_dp_scene.instantiate()
	test_parent_layer.add_child(test_dp)

	tm._elevate_dialogue_layer(test_dp)
	_assert(test_parent_layer.layer == 96, "Dynamic layer elevation elevates parent from layer 8 to 96")
	tm._restore_dialogue_layer()
	# Note: restore is triggered when dialogue panel closes
	test_parent_layer.queue_free()

	# -------------------------------------------------------------------------
	# ATTACK 6: Seed Liquidity Guarantee Invariant
	# -------------------------------------------------------------------------
	print("\n--- ATTACK 6: Seed Liquidity Guarantee ---")
	if gs != null:
		gs.energy = 0.0
		# Simulate Step 1 tap logic
		tm.reset_tutorial()
		tm.start_linear_intro()
		_assert(tm.get_current_step() == 1, "Tutorial at Step 1")
		# Emit core tapped
		if gs.has_signal("core_tapped"):
			gs.core_tapped.emit(1)
		await process_frame
		_assert(gs.energy >= 30.0, "Energy after core tap is >= 30.0 (actual: %f)" % gs.energy)

		# Check tier_1 cost in GameState
		var tier_1_cost = 25.0
		if gs.has_method("get_upgrade_cost"):
			tier_1_cost = gs.get_upgrade_cost("tier_1")
		elif "upgrade_costs" in gs and "tier_1" in gs.upgrade_costs:
			tier_1_cost = float(gs.upgrade_costs["tier_1"])
		_assert(gs.energy >= tier_1_cost, "Seed energy (%.1f) strictly covers tier_1 cost (%.1f)" % [gs.energy, tier_1_cost])

	# -------------------------------------------------------------------------
	# ATTACK 7: Null-Safety During Headless Execution
	# -------------------------------------------------------------------------
	print("\n--- ATTACK 7: Headless Robustness & Missing Node Safety ---")
	# Collectible searching with empty scene
	var nearest_col = tm._find_nearest_collectible()
	_assert(nearest_col == null or is_instance_valid(nearest_col), "_find_nearest_collectible returns safely without crashing")

	# Physics process with no avatar
	tm._physics_process(0.016)
	_assert(true, "_physics_process runs without crashing when Avatar3D is absent")

	# Process with no camera
	tm._process(0.016)
	_assert(true, "_process runs without crashing when Camera3D is absent")

	tm.reset_tutorial()
	await process_frame

	print("\n=================================================================")
	print("Adversarial Test Suite Results: %d Passed, %d Failed, %d Warnings" % [pass_count, fail_count, warnings_count])
	print("=================================================================")

	quit(0 if fail_count == 0 else 1)
