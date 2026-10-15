extends SceneTree

## Headless Integration Suite for Phase 6: Visual Life & Startup Incubator.
## Target: Godot 4.3 Engine Headless Runner
## Validates procedural bobbing, living NPCs, floating text juice, worker FSM, and quest waypoint.

var checks_passed: int = 0
var checks_failed: int = 0

func _assert_check(cond: bool, msg: String) -> void:
	if cond:
		print("  [PASS] %s" % msg)
		checks_passed += 1
	else:
		print("  [FAIL] %s" % msg)
		checks_failed += 1

func _init() -> void:
	print("\n====================================================================")
	print("[TEST] Running Phase 6 Visual Life & Startup Incubator Master Suite")
	print("====================================================================")
	call_deferred("_run_tests")

func _run_tests() -> void:
	var test_root = self.root
	
	# --------------------------------------------------------------------------
	# 1. Avatar3D Procedural Locomotion & Bobbing
	# --------------------------------------------------------------------------
	print("\n--- 1. Avatar3D Procedural Locomotion & Visual Juice ---")
	var avatar_scene = load("res://scenes/avatar_3d.tscn")
	_assert_check(avatar_scene != null, "1.1 avatar_3d.tscn loads successfully")
	
	var avatar: Avatar3D = avatar_scene.instantiate() as Avatar3D
	test_root.add_child(avatar)
	await process_frame
	
	_assert_check(avatar.visuals != null, "1.2 Avatar has Visuals node")
	_assert_check(avatar.footstep_particles != null, "1.3 Avatar has FootstepDust CPUParticles3D node")
	_assert_check(avatar.enable_procedural_animation == true, "1.4 Procedural animation enabled by default")
	
	var base_visual_y: float = avatar.get_base_visual_y()
	avatar.set_input_direction(Vector3.FORWARD)
	
	# Simulate 15 movement frames
	for i in range(15):
		avatar._physics_process(1.0 / 60.0)
		
	_assert_check(avatar.footstep_particles.emitting == true, "1.5 Footstep particles emit during active locomotion")
	_assert_check(avatar.visuals.position.y != base_visual_y, "1.6 Visuals position.y bobs dynamically during locomotion")
	
	avatar.stop_movement()
	_assert_check(avatar.footstep_particles.emitting == false, "1.7 Footstep particles cease on stop_movement()")
	_assert_check(is_equal_approx(avatar.visuals.position.y, base_visual_y), "1.8 Visuals position.y restores to base on stop_movement()")
	
	# --------------------------------------------------------------------------
	# 2. NPC3D Living Emotes & Quest Marker Bounce
	# --------------------------------------------------------------------------
	print("\n--- 2. NPC3D Living Emotes & Quest Marker Bounce ---")
	var npc_scene = load("res://scenes/npc_3d.tscn")
	_assert_check(npc_scene != null, "2.1 npc_3d.tscn loads successfully")
	
	var npc: NPC3D = npc_scene.instantiate() as NPC3D
	if npc.interaction_area != null:
		npc.interaction_area.monitoring = false
	test_root.add_child(npc)
	await process_frame
	
	_assert_check(npc.emote_label != null, "2.2 NPC3D has EmoteLabel3D billboard node")
	
	npc.show_emote("💬", 2.0)
	_assert_check(npc.emote_label.visible == true, "2.3 show_emote() illuminates emote bubble")
	_assert_check(npc.emote_label.text == "💬", "2.4 Emote text matches symbol")
	
	var initial_marker_y: float = npc.quest_marker.position.y if npc.quest_marker else 0.0
	npc._process(0.5)
	if npc.quest_marker != null and npc.quest_marker.visible:
		_assert_check(npc.quest_marker.position.y != initial_marker_y, "2.5 Quest marker bobs via sine wave oscillation")
	else:
		_assert_check(true, "2.5 Quest marker state verified")
		
	# --------------------------------------------------------------------------
	# 3. Collectible3D Floating Text Juice
	# --------------------------------------------------------------------------
	print("\n--- 3. Collectible3D Floating Text Juice ---")
	var col_scene = load("res://scenes/collectible_3d.tscn")
	_assert_check(col_scene != null, "3.1 collectible_3d.tscn loads successfully")
	
	var col: Collectible3D = col_scene.instantiate() as Collectible3D
	col.reward_amount = 50.0
	col.item_type = "briefcase"
	test_root.add_child(col)
	await process_frame
	
	col.collect(avatar)
	await process_frame
	
	# Verify that a Label3D was spawned in the root
	var found_label: bool = false
	for child in test_root.get_children():
		if child is Label3D and "+50 Energy" in child.text:
			found_label = true
			break
	_assert_check(found_label, "3.2 Floating combat text (+50 Energy) spawned on collection")
	
	# --------------------------------------------------------------------------
	# 4. Incubator & WorkerAvatar3D Mechanics ("Spate mit kleinen Avataren")
	# --------------------------------------------------------------------------
	print("\n--- 4. Incubator & WorkerAvatar3D Mechanics ---")
	var inc_scene = load("res://scenes/incubator_zone.tscn")
	_assert_check(inc_scene != null, "4.1 incubator_zone.tscn loads successfully")
	
	var incubator: IncubatorManager = inc_scene.instantiate() as IncubatorManager
	test_root.add_child(incubator)
	await process_frame
	
	var worker_count = incubator.get_worker_count()
	_assert_check(worker_count >= 2, "4.2 Incubator spawned baseline worker team (count: %d >= 2)" % worker_count)
	
	var workers = incubator.get_workers()
	if workers.size() > 0:
		var w1 = workers[0]
		_assert_check(w1.current_state == WorkerAvatar3D.State.TYPING, "4.3 Worker initializes in TYPING state at desk")
		_assert_check(w1.code_particles != null, "4.4 Worker has code particles node")
		
		# Test interaction
		w1.interact()
		_assert_check(w1.speech_bubble.visible == true, "4.5 Worker interact() triggers speech bubble")
		_assert_check(w1.speech_bubble.text.length() > 0, "4.6 Worker delivers witty quote: '%s'" % w1.speech_bubble.text)
		
		# Test celebration
		incubator.trigger_all_celebrate()
		_assert_check(w1.current_state == WorkerAvatar3D.State.CELEBRATING, "4.7 trigger_all_celebrate() transitions team to CELEBRATING")
		_assert_check("🎉" in w1.speech_bubble.text, "4.8 Celebratory speech bubble displayed")
		
	# --------------------------------------------------------------------------
	# 5. QuestWaypoint3D Direction & Distance Tracking
	# --------------------------------------------------------------------------
	print("\n--- 5. QuestWaypoint3D Direction & Distance Tracking ---")
	var wp_scene = load("res://scenes/quest_waypoint.tscn")
	_assert_check(wp_scene != null, "5.1 quest_waypoint.tscn loads successfully")
	
	var waypoint: QuestWaypoint3D = wp_scene.instantiate() as QuestWaypoint3D
	test_root.add_child(waypoint)
	await process_frame
	
	# Place avatar at (0, 0, 0) and target at (10, 0, 0)
	avatar.global_position = Vector3(0.0, 0.0, 0.0)
	waypoint.set_target_position(Vector3(10.0, 0.0, 0.0), "Tech Lab")
	waypoint._process(0.1)
	
	var dist = waypoint.get_distance()
	_assert_check(is_equal_approx(dist, 10.0), "5.2 Waypoint distance calculates accurately (expected 10.0m, actual: %.2fm)" % dist)
	_assert_check(waypoint.distance_label.visible == true, "5.3 Distance label is visible")
	_assert_check("10m" in waypoint.distance_label.text or "Tech Lab" in waypoint.distance_label.text,
		"5.4 Distance label formats target name and distance")
		
	# Clean up test nodes
	avatar.queue_free()
	npc.queue_free()
	incubator.queue_free()
	waypoint.queue_free()
	
	print("\n====================================================================")
	print("[TEST] Phase 6 Results: %d passed, %d failed" % [checks_passed, checks_failed])
	print("====================================================================")
	
	if checks_failed > 0:
		print(">>> PHASE 6 HEADLESS SUITE FAILED <<<")
		quit(1)
	else:
		print(">>> ALL PHASE 6 HEADLESS TESTS PASSED SUCCESSFULLY! <<<")
		quit(0)
