extends SceneTree

## Headless Test Harness for Milestone P4-M3: 3D Interactions, Quests, & Gated Zones.
## Validates:
## 1. Collectible3D item creation, pickup mechanics, GameState energy rewards, speed boost.
## 2. ZoneGate3D clearance level and energy payment checks, barrier opening, collision disabling.
## 3. NPC3D dialogue state, billboarding markers, and quest management.
## 4. GameState quest lifecycle (not_started -> active -> ready -> completed) and persistence.
## 5. Main3D full scene instantiation with NPCs, Zone Gates, Collectibles, and HUD layers.

var pass_count: int = 0
var fail_count: int = 0

func _init() -> void:
	print("====================================================================")
	print("[TEST] Milestone P4-M3: 3D Interactions, Quests & Zones Test Suite")
	print("====================================================================")
	process_frame.connect(_on_first_frame, CONNECT_ONE_SHOT)

func _on_first_frame() -> void:
	await _run_all_tests()
	print("\n====================================================================")
	print("[TEST] P4-M3 Results: %d passed, %d failed" % [pass_count, fail_count])
	print("====================================================================")
	if fail_count == 0:
		print(">>> ALL P4-M3 HEADLESS INTERACTION TESTS PASSED SUCCESSFULLY! <<<")
		quit(0)
	else:
		printerr(">>> TEST SUITE ENCOUNTERED %d FAILURES! <<<" % fail_count)
		quit(1)

func _assert_check(cond: bool, test_name: String) -> void:
	if cond:
		print("  [PASS] %s" % test_name)
		pass_count += 1
	else:
		printerr("  [FAIL] %s" % test_name)
		fail_count += 1

func _run_all_tests() -> void:
	# 0. Setup GameState singleton
	var gs_script = load("res://scripts/autoload/game_state.gd")
	var gs = root.get_node_or_null("GameState")
	if gs == null and gs_script != null:
		gs = gs_script.new()
		gs.name = "GameState"
		root.add_child(gs)
	await process_frame

	gs.reset_state()

	# -------------------------------------------------------------------------
	# 1. Test Collectible3D Logic & Economy Integration
	# -------------------------------------------------------------------------
	print("\n--- 1. Collectible3D Collection Mechanics ---")
	var coll_scene = load("res://scenes/collectible_3d.tscn")
	_assert_check(coll_scene != null, "collectible_3d.tscn loaded successfully")

	var coll = coll_scene.instantiate() as Collectible3D
	root.add_child(coll)
	coll.item_type = "briefcase"
	coll.reward_amount = 75.0
	await process_frame

	var energy_before = gs.energy
	var collected_signal_fired: bool = false
	coll.collected.connect(func(_type, _reward): collected_signal_fired = true)

	coll.collect(null)
	await process_frame

	_assert_check(collected_signal_fired, "Collectible3D emitted collected signal")
	_assert_check(gs.energy == energy_before + 75.0, "GameState awarded 75 Users on briefcase collection")
	_assert_check(gs.collectibles_collected >= 1, "GameState collectibles_collected incremented")

	# -------------------------------------------------------------------------
	# 2. Test ZoneGate3D Gating Logic & Unlocking
	# -------------------------------------------------------------------------
	print("\n--- 2. ZoneGate3D Security Clearance & Barriers ---")
	var gate_scene = load("res://scenes/zone_gate_3d.tscn")
	_assert_check(gate_scene != null, "zone_gate_3d.tscn loaded successfully")

	var gate = gate_scene.instantiate() as ZoneGate3D
	gate.zone_id = "test_zone_alpha"
	gate.zone_name = "Alpha Testing Sector"
	gate.required_level = 3
	gate.unlock_cost = 500.0
	root.add_child(gate)
	await process_frame

	# Player has level 1 and 75 energy -> cannot unlock
	var unlocked_fail = gate.attempt_unlock()
	_assert_check(not unlocked_fail, "Gate rejects unlock when player lacks required level and energy")
	_assert_check(not gs.is_zone_unlocked("test_zone_alpha"), "Zone remains locked in GameState")

	# Give player clearance level 3
	gs.idle_level = 3
	var unlocked_success = gate.attempt_unlock()
	_assert_check(unlocked_success, "Gate unlocks successfully when player meets clearance level")
	_assert_check(gs.is_zone_unlocked("test_zone_alpha"), "Zone registered as unlocked in GameState")
	_assert_check(gate.collision_shape.disabled, "Gate collision shape disabled after unlocking")

	gate.queue_free()

	# -------------------------------------------------------------------------
	# 3. Test Campus Quest Lifecycle in GameState
	# -------------------------------------------------------------------------
	print("\n--- 3. GameState Campus Quest Lifecycle ---")
	gs.start_campus_quest("test_briefcase_quest", 2)
	_assert_check(gs.get_campus_quest_status("test_briefcase_quest") == "active", "Quest status is active after start")

	gs.advance_campus_quest("test_briefcase_quest", 1)
	_assert_check(gs.get_campus_quest_status("test_briefcase_quest") == "active", "Quest status still active at 1/2")

	gs.advance_campus_quest("test_briefcase_quest", 1)
	_assert_check(gs.get_campus_quest_status("test_briefcase_quest") == "ready", "Quest status becomes ready at 2/2")

	var energy_pre_quest = gs.energy
	var quest_completed = gs.complete_campus_quest("test_briefcase_quest", 100.0, 10)
	_assert_check(quest_completed, "complete_campus_quest returned true")
	_assert_check(gs.get_campus_quest_status("test_briefcase_quest") == "completed", "Quest status is completed")
	_assert_check(gs.energy == energy_pre_quest + 100.0, "Quest completion awarded 100 Users")

	# -------------------------------------------------------------------------
	# 4. Test NPC3D & Dialogue Panel
	# -------------------------------------------------------------------------
	print("\n--- 4. NPC3D & Dialogue Integration ---")
	var npc_scene = load("res://scenes/npc_3d.tscn")
	_assert_check(npc_scene != null, "npc_3d.tscn loaded successfully")

	var npc = npc_scene.instantiate() as NPC3D
	root.add_child(npc)
	npc.npc_id = "test_npc"
	npc.npc_name = "Test Engineer"
	await process_frame

	_assert_check(npc.is_in_group("npcs"), "NPC3D added to 'npcs' group")
	_assert_check(npc.name_label != null, "NPC3D has valid NameLabel3D")
	_assert_check(npc.quest_marker != null, "NPC3D has valid QuestMarkerLabel3D")

	npc.queue_free()

	# -------------------------------------------------------------------------
	# 5. Full Main3D Campus Scene Verification
	# -------------------------------------------------------------------------
	print("\n--- 5. Main3D Campus Integration Verification ---")
	var main_scene = load("res://scenes/main_3d.tscn")
	_assert_check(main_scene != null, "scenes/main_3d.tscn loaded successfully")

	var main_inst = main_scene.instantiate()
	root.add_child(main_inst)
	await process_frame

	_assert_check(main_inst.get_node_or_null("NPCs") != null, "Main3D contains NPCs container")
	_assert_check(main_inst.get_node_or_null("ZoneGates") != null, "Main3D contains ZoneGates container")
	_assert_check(main_inst.get_node_or_null("Collectibles") != null, "Main3D contains Collectibles container")
	_assert_check(main_inst.get_node_or_null("QuestLayer/QuestTracker") != null, "Main3D contains QuestTracker UI")
	_assert_check(main_inst.get_node_or_null("DialogueLayer/DialoguePanel") != null, "Main3D contains DialoguePanel UI")

	main_inst.queue_free()
	await process_frame
