extends SceneTree

## =============================================================================
## Phase 18 Milestone 2: Empirical Challenger Test Suite (Lifecycle, Leaks & Dynamic Bounds)
## File: IdleArcade/tests/test_p18_m2_challenger_lifecycle.gd
##
## Empirically challenges:
## 1. virtual_joystick.gd: Dynamic viewport bounds adaptation across portrait (720x1280),
##    tall screens (720x1600), and wide landscape screens (1280x720).
##    Specifically verifies whether bottom-edge touches (y > 1280) are accepted on tall screens.
## 2. incubator_manager.gd: Headcount scaling, worker spawning, and despawn cleanup on
##    headcount reduction / IPO prestige reset (checking if excess workers are unparented & freed).
## 3. audio_manager.gd: Lifecycle teardown in _exit_tree(), stream detachment, player cleanup,
##    and checking ObjectDB leaks on exit.
## =============================================================================

var pass_count: int = 0
var fail_count: int = 0
var findings: Array[String] = []

func _assert_check(condition: bool, test_name: String, detail: String = "") -> void:
	if condition:
		print("  [PASS] %s" % test_name)
		pass_count += 1
	else:
		var err: String = "  [FAIL] %s" % test_name
		if detail != "":
			err += " -> " + detail
		printerr(err)
		findings.append(err)
		fail_count += 1

func _init() -> void:
	print("====================================================================")
	print(">>> P18-M2 EMPIRICAL CHALLENGER: LIFECYCLE, LEAKS & BOUNDS <<<")
	print("====================================================================")
	call_deferred("_run_challenger_suite")

func _run_challenger_suite() -> void:
	await process_frame
	await process_frame

	print("\n--- TEST SUITE 1: ArcadeVirtualJoystick Dynamic Viewport Bounds ---")
	await _test_virtual_joystick_dynamic_bounds()

	print("\n--- TEST SUITE 2: IncubatorManager Headcount Shrink & Worker Despawn ---")
	await _test_incubator_manager_despawn()

	print("\n--- TEST SUITE 3: AudioManager Teardown & ObjectDB Leak Verification ---")
	await _test_audio_manager_lifecycle_teardown()

	_summarize_and_quit()

## =============================================================================
## 1. ArcadeVirtualJoystick Dynamic Viewport Bounds
## =============================================================================
func _test_virtual_joystick_dynamic_bounds() -> void:
	var vj_script = load("res://scripts/ui/virtual_joystick.gd")
	_assert_check(vj_script != null, "1.1 virtual_joystick.gd loaded successfully")

	# 1.1 Baseline Root Viewport
	var vj_root = vj_script.new() as ArcadeVirtualJoystick
	root.add_child(vj_root)
	await process_frame

	print("  [INFO] Root viewport size: %s, DisplayServer: %s" % [str(vj_root.get_viewport_rect().size), DisplayServer.get_name()])
	print("  [INFO] vj_root initial zone: X [%.1f, %.1f], Y [%.1f, %.1f]" % [vj_root.zone_min_x, vj_root.zone_max_x, vj_root.zone_min_y, vj_root.zone_max_y])

	_assert_check(vj_root.is_in_touch_zone(Vector2(100.0, 500.0)), "1.2 Touch within default zone (100, 500) accepted")
	_assert_check(not vj_root.is_in_touch_zone(Vector2(-10.0, 500.0)), "1.3 Negative X touch (-10, 500) rejected")
	_assert_check(not vj_root.is_in_touch_zone(Vector2(100.0, 30.0)), "1.4 Header zone touch (100, 30) rejected (< 70)")

	vj_root.queue_free()
	await process_frame

	# 1.2 Tall Screen Adaptation (720 x 1600) via SubViewport
	print("\n  -- Sub-Test 1.2: Tall Mobile Viewport (720x1600, 20:9 aspect ratio) --")
	var sub_vp_tall = SubViewport.new()
	sub_vp_tall.size = Vector2i(720, 1600)
	root.add_child(sub_vp_tall)

	var vj_tall = vj_script.new() as ArcadeVirtualJoystick
	sub_vp_tall.add_child(vj_tall)
	await process_frame

	var tall_vp_size: Vector2 = vj_tall.get_viewport_rect().size
	_assert_check(tall_vp_size == Vector2(720.0, 1600.0), "1.5 SubViewport size confirmed as (720, 1600)")

	# Force zone update / call is_in_touch_zone
	var in_mid = vj_tall.is_in_touch_zone(Vector2(200.0, 1000.0))
	_assert_check(in_mid, "1.6 Mid-screen touch (200, 1000) accepted on tall viewport")

	# CRITICAL CHECK: Bottom-edge touches (y > 1280) on tall screen (y = 1350, y = 1450, y = 1590)
	print("  [INFO] vj_tall zone bounds: X [%.1f, %.1f], Y [%.1f, %.1f]" % [vj_tall.zone_min_x, vj_tall.zone_max_x, vj_tall.zone_min_y, vj_tall.zone_max_y])
	var touch_1350 = vj_tall.is_in_touch_zone(Vector2(200.0, 1350.0))
	_assert_check(touch_1350, "1.7 Touch at y=1350 (y > 1280) accepted on 720x1600 screen", "zone_max_y is %.1f" % vj_tall.zone_max_y)

	var touch_1500 = vj_tall.is_in_touch_zone(Vector2(200.0, 1500.0))
	_assert_check(touch_1500, "1.8 Touch at y=1500 (y > 1280) accepted on 720x1600 screen", "zone_max_y is %.1f" % vj_tall.zone_max_y)

	var touch_1600 = vj_tall.is_in_touch_zone(Vector2(360.0, 1600.0))
	_assert_check(touch_1600, "1.9 Bottom-right edge touch (360, 1600) accepted on 720x1600 screen", "zone_max_y is %.1f" % vj_tall.zone_max_y)

	# Boundary check: past bottom edge (> 1600) must be rejected
	var touch_1601 = vj_tall.is_in_touch_zone(Vector2(200.0, 1600.1))
	_assert_check(not touch_1601, "1.10 Off-screen bottom touch (200, 1600.1) rejected on 720x1600 screen")

	# Boundary check: past right half (> 360) must be rejected
	var touch_right_tall = vj_tall.is_in_touch_zone(Vector2(360.5, 1000.0))
	_assert_check(not touch_right_tall, "1.11 Right-half touch (360.5, 1000) rejected on 720x1600 screen")

	vj_tall.queue_free()
	sub_vp_tall.queue_free()
	await process_frame

	# 1.3 Wide Landscape Screen Adaptation (1280 x 720) via SubViewport
	print("\n  -- Sub-Test 1.3: Wide Landscape Viewport (1280x720, 16:9 aspect ratio) --")
	var sub_vp_wide = SubViewport.new()
	sub_vp_wide.size = Vector2i(1280, 720)
	root.add_child(sub_vp_wide)

	var vj_wide = vj_script.new() as ArcadeVirtualJoystick
	sub_vp_wide.add_child(vj_wide)
	await process_frame

	var wide_vp_size: Vector2 = vj_wide.get_viewport_rect().size
	_assert_check(wide_vp_size == Vector2(1280.0, 720.0), "1.12 SubViewport size confirmed as (1280, 720)")

	print("  [INFO] vj_wide zone bounds: X [%.1f, %.1f], Y [%.1f, %.1f]" % [vj_wide.zone_min_x, vj_wide.zone_max_x, vj_wide.zone_min_y, vj_wide.zone_max_y])
	# On 1280x720, left half is [0, 640] and vertical range is [70, 720]
	var touch_wide_left = vj_wide.is_in_touch_zone(Vector2(500.0, 500.0))
	_assert_check(touch_wide_left, "1.13 Left-half touch (500, 500) accepted on 1280x720 landscape (left half extends to 640)", "zone_max_x is %.1f" % vj_wide.zone_max_x)

	var touch_wide_edge_x = vj_wide.is_in_touch_zone(Vector2(640.0, 500.0))
	_assert_check(touch_wide_edge_x, "1.14 Boundary touch at center split (640, 500) accepted on 1280x720 landscape", "zone_max_x is %.1f" % vj_wide.zone_max_x)

	var touch_wide_right = vj_wide.is_in_touch_zone(Vector2(640.5, 500.0))
	_assert_check(not touch_wide_right, "1.15 Right-half touch (640.5, 500) rejected on 1280x720 landscape")

	# Crucial: On 1280x720, y=800 is OFF SCREEN. Must be rejected!
	var touch_wide_off_y = vj_wide.is_in_touch_zone(Vector2(200.0, 800.0))
	_assert_check(not touch_wide_off_y, "1.16 Touch at y=800 rejected on 1280x720 landscape (screen height is only 720)", "zone_max_y is %.1f" % vj_wide.zone_max_y)

	vj_wide.queue_free()
	sub_vp_wide.queue_free()
	await process_frame

## =============================================================================
## 2. IncubatorManager Headcount Shrink & Worker Despawn
## =============================================================================
func _test_incubator_manager_despawn() -> void:
	var im_script = load("res://scripts/incubator_manager.gd")
	_assert_check(im_script != null, "2.1 incubator_manager.gd loaded successfully")

	# Mock GameState
	var gs = root.get_node_or_null("GameState")
	var gs_created: bool = false
	if gs == null:
		var gs_script = load("res://scripts/autoload/game_state.gd")
		if gs_script != null:
			gs = gs_script.new()
			gs.name = "GameState"
			root.add_child(gs)
			gs_created = true

	# Set high idle level to spawn 5 workers (desired = 2 + (4-1) + 2 = 7 -> clamped to 5)
	gs.idle_level = 4
	gs.unlocked_zones.clear()
	gs.unlocked_zones.append("lab")
	gs.unlocked_zones.append("server")

	var incubator = im_script.new() as IncubatorManager
	root.add_child(incubator)
	await process_frame

	var initial_count: int = incubator.get_worker_count()
	_assert_check(initial_count == 5, "2.2 Incubator spawned 5 workers (actual: %d)" % initial_count)

	var workers_before = incubator.get_workers().duplicate()
	_assert_check(workers_before.size() == 5, "2.3 Workers array has 5 instances")

	for i in range(workers_before.size()):
		var w = workers_before[i]
		_assert_check(is_instance_valid(w) and w.get_parent() == incubator, "2.4.%d Worker %d parented to incubator" % [i, i])

	# Now simulate IPO prestige reset or headcount shrink:
	print("\n  -- Simulating Headcount Shrink / IPO Prestige Reset to 1 worker --")
	gs.idle_level = 1
	gs.unlocked_zones.clear()
	incubator.base_spawn_count = 1 # Force target headcount to 1

	# Trigger headcount update
	incubator._update_team_headcount()

	# Invariant checks immediately after despawn loop
	var count_after: int = incubator.get_worker_count()
	_assert_check(count_after == 1, "2.5 Incubator _workers shrunk to 1 worker (actual: %d)" % count_after)

	# Verify excess 4 workers:
	# Check whether workers_before[1..4] were unparented immediately or queued for deletion
	var excess_workers = workers_before.slice(1)
	var all_queued_for_deletion: bool = true
	var all_unparented_immediately: bool = true
	for w in excess_workers:
		if not w.is_queued_for_deletion():
			all_queued_for_deletion = false
		if w.get_parent() == incubator:
			all_unparented_immediately = false

	_assert_check(all_queued_for_deletion, "2.6 All 4 excess workers queued for deletion (is_queued_for_deletion == true)")
	_assert_check(all_unparented_immediately, "2.7 All 4 excess workers cleanly unparented immediately via remove_child()", "Note: If false, worker remained in scene tree until idle frame")

	# Wait for frame to process queue_free
	await process_frame
	await process_frame

	var all_freed_after_frame: bool = true
	for w in excess_workers:
		if is_instance_valid(w):
			all_freed_after_frame = false

	_assert_check(all_freed_after_frame, "2.8 All 4 excess workers completely freed and invalid in ObjectDB after frame")

	# Verify surviving worker 0 is intact and healthy
	var remaining_workers = incubator.get_workers()
	_assert_check(remaining_workers.size() == 1, "2.9 Remaining workers array size is exactly 1")
	var survivor = remaining_workers[0]
	_assert_check(is_instance_valid(survivor) and survivor.get_parent() == incubator, "2.10 Surviving worker intact, valid, and parented")
	_assert_check(survivor.worker_name == "Sam", "2.11 Surviving worker is primary worker 'Sam'")

	incubator.queue_free()
	if gs_created and is_instance_valid(gs):
		gs.queue_free()
	await process_frame

## =============================================================================
## 3. AudioManager Lifecycle Teardown & ObjectDB Leak Verification
## =============================================================================
func _test_audio_manager_lifecycle_teardown() -> void:
	var am_script = load("res://scripts/autoload/audio_manager.gd")
	_assert_check(am_script != null, "3.1 audio_manager.gd loaded successfully")

	var am = am_script.new()
	root.add_child(am)
	await process_frame

	# Verify players initialized
	var sfx_pool = am.get("_sfx_pool")
	_assert_check(sfx_pool != null and sfx_pool.size() == 8, "3.2 SFX player pool initialized with 8 players")

	var bgm_player = am.get("_bgm_player")
	_assert_check(bgm_player != null and is_instance_valid(bgm_player), "3.3 BGM player instantiated")

	var drone_player = am.get("_drone_player")
	_assert_check(drone_player != null and is_instance_valid(drone_player), "3.4 Drone player instantiated")

	# Play SFX to bind streams
	am.play_sfx_click()
	am.play_sfx_pickup("briefcase")
	am.play_sfx_footstep()
	am.play_sfx_gate_unlock()
	am.play_sfx_research()
	am.play_sfx_drone_hum()
	am.start_ambient_bgm()

	var stream_assigned: bool = false
	for p in sfx_pool:
		if p.stream != null:
			stream_assigned = true
			break
	_assert_check(stream_assigned, "3.5 AudioStream assigned to at least one pool player")
	_assert_check(bgm_player.stream != null, "3.6 AudioStream assigned to BGM player")
	_assert_check(drone_player.stream != null, "3.7 AudioStream assigned to Drone player")

	# Invoke _exit_tree() teardown
	print("\n  -- Invoking _exit_tree() Teardown on AudioManager --")
	am._exit_tree()

	# Verify all streams detached from players
	var all_streams_detached: bool = true
	for p in sfx_pool:
		if is_instance_valid(p) and p.stream != null:
			all_streams_detached = false
	if is_instance_valid(bgm_player) and bgm_player.stream != null:
		all_streams_detached = false
	if is_instance_valid(drone_player) and drone_player.stream != null:
		all_streams_detached = false

	_assert_check(all_streams_detached, "3.8 All AudioStream references cleared from players (stream == null)")

	# Verify pre-synthesized PCM wave resources nullified
	var wav_click = am.get("_wav_click")
	var wav_briefcase = am.get("_wav_pickup_briefcase")
	var wav_bgm = am.get("_wav_ambient_bgm")
	var wav_drone = am.get("_wav_drone_hum")
	_assert_check(wav_click == null and wav_briefcase == null and wav_bgm == null and wav_drone == null, "3.9 Pre-synthesized AudioStreamWAV cached resources nullified in memory")

	# Verify player status: Are players freed upon _exit_tree()?
	var players_freed_by_exit_tree: bool = true
	for p in sfx_pool:
		if is_instance_valid(p) and not p.is_queued_for_deletion():
			players_freed_by_exit_tree = false
	if is_instance_valid(bgm_player) and not bgm_player.is_queued_for_deletion():
		players_freed_by_exit_tree = false
	if is_instance_valid(drone_player) and not drone_player.is_queued_for_deletion():
		players_freed_by_exit_tree = false

	_assert_check(players_freed_by_exit_tree, "3.10 All child audio players freed or queued for deletion by _exit_tree()", "Note: If false, players are kept alive until parent node is freed")

	# Now cleanly free AudioManager and await frame to verify 0 ObjectDB leaks
	am.queue_free()
	await process_frame
	await process_frame

	_assert_check(not is_instance_valid(am), "3.11 AudioManager node freed cleanly")

## =============================================================================
## Summary & Quit
## =============================================================================
func _summarize_and_quit() -> void:
	print("\n====================================================================")
	print(">>> P18-M2 CHALLENGER SUMMARY: %d PASSED, %d FAILED <<<" % [pass_count, fail_count])
	print("====================================================================")
	if findings.size() > 0:
		print("\nCRITICAL DEFECTS / EMPIRICAL FINDINGS:")
		for f in findings:
			print(" - %s" % f)
		print("\n>>> EMPIRICAL VERDICT: REQUEST_CHANGES <<<")
		quit(1)
	else:
		print("\n>>> EMPIRICAL VERDICT: APPROVE <<<")
		quit(0)
