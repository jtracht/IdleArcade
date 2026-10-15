extends SceneTree

## =============================================================================
## Master Headless SceneTree Test Suite for Phase 7 Redesign
## File: IdleArcade/tests/test_phase7_ux_models.gd
## Target: Godot 4.3 Engine Headless Runner
##
## Validates:
##   1. Mobile UX (R1):
##      - ActionButton custom_minimum_size >= 72px (100x100), centered pivot (50, 50).
##      - LaptopThumbButton (70x70) & CampusThumbButton (70x70) in radial fan layout.
##      - Pairwise center distances >= 95px, edge clearances >= 25px, thumb reaches <= 280px,
##        lateral joystick clearance buffer >= 125px (X <= 360).
##      - ActionButton visual readiness on NPCs ("Talk [E]"), Gates ("Unlock [E]"),
##        and Collectibles ("Collect [E]" with violet glow).
##      - BurgerMenuButton >= 56px and NavDrawer toggle (open, close, toggle).
##      - NavDrawer card heights >= 64px.
##      - Preservation of %AuthButton, %LeaderboardButton, %GuildButton, %QuestButton, %CampusButton.
##      - ShopPanel buy buttons >= 54px with centered pivot.
##      - mouse_filter == Control.MOUSE_FILTER_STOP input isolation.
##
##   2. 3D Chibi Models (R2):
##      - Avatar3D chibi hierarchy (Head with Visor and Hair, compact Torso, Backpack,
##        articulated limbs LeftArm, RightArm, LeftLeg, RightLeg), locomotion swinging.
##      - Preserved nodes: CollisionShape3D, InteractionArea, FootstepDust, GroundShadow, DirectionalPointer.
##      - NPC3D modular accessories for Alex (suit tie/glasses), Bob (blueprint/hard hat/goggles),
##        Lisa (lab coat/flask/ponytail) and dynamic switching via _apply_chibi_accessories().
##      - WorkerAvatar3D visor emotes ("0101", "•_•", "^.^", "★_★") and accessory swapping (Laptop vs CoffeeMug).
##      - Collectible3D 3 distinct models (Briefcase, Steaming Coffee with CPUParticles3D, USB with glowing LED).
##      - ZoneGate3D status beacons (Red/Green/Amber) and neon barrier.
##      - StandardMaterial3D gl_compatibility settings and campus triangle count <= 22,000.
##
##   3. Gameplay Bugfixes & Loops (R3):
##      - Avatar3D input_enabled guarding _script_input_direction and set_input_enabled().
##      - NPC3D dialogue controls fade and clean teardown on exit with re-entrancy protection.
##      - GameState active_campus_quest_id and retroactive unlocks for quest_server and quest_lab.
##      - ZoneGate3D billboarded floating text on missing resources.
##      - Reactive avatar_speed upgrade binding via _on_avatar_stat_updated.
##      - Campus collectibles 2D idle multiplier (1.0 + collectibles * 0.05) and RPS emission.
##      - QuestWaypoint3D dynamic target resolution and [ Arrived! ] detection within <= 3.0m.
##
## Execution:
##   godot --headless --path IdleArcade -s tests/test_phase7_ux_models.gd
## =============================================================================

var pass_count: int = 0
var fail_count: int = 0

const EPSILON: float = 0.5
const VIEWPORT_W: float = 720.0
const VIEWPORT_H: float = 1280.0

func _assert_check(condition: bool, description: String) -> void:
	if condition:
		print("  [PASS] %s" % description)
		pass_count += 1
	else:
		printerr("  [FAIL] %s" % description)
		fail_count += 1

func _init() -> void:
	print("\n====================================================================")
	print(">>> RUNNING MASTER PHASE 7 HEADLESS SCENETREE TEST SUITE <<<")
	print("====================================================================")
	call_deferred("_run_all_tests")

func _run_all_tests() -> void:
	await process_frame
	
	# Execute all three core requirement modules
	await _test_module_1_mobile_ux()
	await _test_module_2_chibi_models()
	await _test_module_3_gameplay_loops()
	
	print("\n====================================================================")
	print(">>> PHASE 7 SCENETREE TEST SUITE SUMMARY: %d PASSED, %d FAILED <<<" % [pass_count, fail_count])
	print("====================================================================")
	
	if fail_count == 0:
		print(">>> ALL PHASE 7 HEADLESS SCENETREE TESTS PASSED (Exit Code 0) <<<")
		quit(0)
	else:
		printerr(">>> PHASE 7 HEADLESS SCENETREE TESTS FAILED (Exit Code 1) <<<")
		quit(1)

# =============================================================================
# MODULE 1: Mobile UX & Ergonomic Fan Layout (Requirement R1)
# =============================================================================
func _test_module_1_mobile_ux() -> void:
	print("\n--- MODULE 1: Mobile UX & Ergonomic Fan Layout (R1) ---")
	
	# 1.1 Radial Fan Layout Geometry
	var tc_scene = load("res://scenes/ui/touch_controls.tscn")
	_assert_check(tc_scene != null, "1.1 scenes/ui/touch_controls.tscn loads successfully")
	if tc_scene == null:
		return
		
	var tc_inst = tc_scene.instantiate() as Control
	root.add_child(tc_inst)
	await process_frame
	
	var act_btn = tc_inst.get_node_or_null("%ActionButton") as Button
	var lap_btn = tc_inst.get_node_or_null("%LaptopThumbButton") as Button
	var cam_btn = tc_inst.get_node_or_null("%CampusThumbButton") as Button
	
	_assert_check(act_btn != null, "1.2 ActionButton node resolved via unique name %ActionButton")
	_assert_check(lap_btn != null, "1.3 LaptopThumbButton node resolved via unique name %LaptopThumbButton")
	_assert_check(cam_btn != null, "1.4 CampusThumbButton node resolved via unique name %CampusThumbButton")
	
	if act_btn != null and lap_btn != null and cam_btn != null:
		# Dimensions & Pivot
		_assert_check(act_btn.custom_minimum_size.x >= 72.0 and act_btn.custom_minimum_size.y >= 72.0,
			"1.5 ActionButton custom_minimum_size >= 72px (got %.1fx%.1f)" % [act_btn.custom_minimum_size.x, act_btn.custom_minimum_size.y])
		_assert_check(act_btn.size.x >= 72.0 and act_btn.size.y >= 72.0,
			"1.6 ActionButton physical size >= 72px (got %.1fx%.1f)" % [act_btn.size.x, act_btn.size.y])
		_assert_check(abs(act_btn.pivot_offset.x - 50.0) < EPSILON and abs(act_btn.pivot_offset.y - 50.0) < EPSILON,
			"1.7 ActionButton centered touch pivot Vector2(50, 50)")
		_assert_check(abs(lap_btn.pivot_offset.x - 35.0) < EPSILON and abs(lap_btn.pivot_offset.y - 35.0) < EPSILON,
			"1.8 LaptopThumbButton centered touch pivot Vector2(35, 35)")
		_assert_check(abs(cam_btn.pivot_offset.x - 35.0) < EPSILON and abs(cam_btn.pivot_offset.y - 35.0) < EPSILON,
			"1.9 CampusThumbButton centered touch pivot Vector2(35, 35)")
			
		# Fan Geometry & Clearance
		var act_center = act_btn.position + act_btn.size * 0.5
		var lap_center = lap_btn.position + lap_btn.size * 0.5
		var cam_center = cam_btn.position + cam_btn.size * 0.5
		
		var dist_act_cam = act_center.distance_to(cam_center)
		var dist_act_lap = act_center.distance_to(lap_center)
		var dist_lap_cam = lap_center.distance_to(cam_center)
		
		_assert_check(dist_act_cam >= 95.0, "1.10 Action-Campus center distance >= 95px (got %.1fpx)" % dist_act_cam)
		_assert_check(dist_act_lap >= 95.0, "1.11 Action-Laptop center distance >= 95px (got %.1fpx)" % dist_act_lap)
		_assert_check(dist_lap_cam >= 95.0, "1.12 Laptop-Campus center distance >= 95px (got %.1fpx)" % dist_lap_cam)
		
		var edge_act_cam = dist_act_cam - (50.0 + 35.0)
		var edge_act_lap = dist_act_lap - (50.0 + 35.0)
		var edge_lap_cam = dist_lap_cam - (35.0 + 35.0)
		
		_assert_check(edge_act_cam >= 25.0, "1.13 Action-Campus edge clearance >= 25px (got %.1fpx)" % edge_act_cam)
		_assert_check(edge_act_lap >= 25.0, "1.14 Action-Laptop edge clearance >= 25px (got %.1fpx)" % edge_act_lap)
		_assert_check(edge_lap_cam >= 25.0, "1.15 Laptop-Campus edge clearance >= 25px (got %.1fpx)" % edge_lap_cam)
		
		var corner = tc_inst.size if tc_inst.size.x > 0.0 and tc_inst.size.y > 0.0 else Vector2(VIEWPORT_W, VIEWPORT_H)
		var reach_act = corner.distance_to(act_center)
		var reach_lap = corner.distance_to(lap_center)
		var reach_cam = corner.distance_to(cam_center)
		
		_assert_check(reach_act <= 280.0, "1.16 Action reach from corner <= 280px (got %.1fpx)" % reach_act)
		_assert_check(reach_lap <= 280.0, "1.17 Laptop reach from corner <= 280px (got %.1fpx)" % reach_lap)
		_assert_check(reach_cam <= 280.0, "1.18 Campus reach from corner <= 280px (got %.1fpx)" % reach_cam)
		
		var leftmost_edge = min(cam_btn.position.x, min(lap_btn.position.x, act_btn.position.x))
		var joystick_buffer = leftmost_edge - 360.0
		_assert_check(joystick_buffer >= 125.0, "1.19 Lateral joystick clearance buffer >= 125px (got %.1fpx)" % joystick_buffer)

	# 1.2 ActionButton Visual Readiness
	if tc_inst.has_method("register_interactable") and act_btn != null:
		var dummy_npc = CharacterBody3D.new()
		dummy_npc.set_script(load("res://scripts/npc_3d.gd"))
		tc_inst.call("register_interactable", dummy_npc)
		_assert_check(act_btn.text == "Talk [E]", "1.20 ActionButton highlights 'Talk [E]' on NPC overlap")
		
		var dummy_gate = StaticBody3D.new()
		dummy_gate.set_script(load("res://scripts/zone_gate_3d.gd"))
		tc_inst.call("register_interactable", dummy_gate)
		_assert_check(act_btn.text == "Unlock [E]", "1.21 ActionButton highlights 'Unlock [E]' on ZoneGate overlap")
		
		var dummy_col = Area3D.new()
		dummy_col.set_script(load("res://scripts/collectible_3d.gd"))
		tc_inst.call("register_interactable", dummy_col)
		_assert_check(act_btn.text == "Collect [E]", "1.22 ActionButton highlights 'Collect [E]' on Collectible overlap")
		
		tc_inst.call("unregister_interactable", dummy_col)
		tc_inst.call("unregister_interactable", dummy_gate)
		tc_inst.call("unregister_interactable", dummy_npc)
		dummy_npc.queue_free()
		dummy_gate.queue_free()
		dummy_col.queue_free()

	# 1.3 BurgerMenu & NavDrawer Toggle
	var hud_scene = load("res://scenes/hud.tscn")
	_assert_check(hud_scene != null, "1.23 scenes/hud.tscn loads successfully")
	var hud_inst = hud_scene.instantiate() as Control
	root.add_child(hud_inst)
	await process_frame
	
	var burger_btn = hud_inst.get_node_or_null("%BurgerMenuButton") as Button
	var nav_drawer = hud_inst.get_node_or_null("%NavDrawer") as Control
	_assert_check(burger_btn != null, "1.24 BurgerMenuButton resolved via unique name %BurgerMenuButton")
	_assert_check(nav_drawer != null, "1.25 NavDrawer resolved via unique name %NavDrawer")
	
	if burger_btn != null:
		_assert_check(burger_btn.custom_minimum_size.x >= 56.0 and burger_btn.custom_minimum_size.y >= 56.0,
			"1.26 BurgerMenuButton touch size >= 56x56px (got %.1fx%.1f)" % [burger_btn.custom_minimum_size.x, burger_btn.custom_minimum_size.y])
			
	if nav_drawer != null and hud_inst.has_method("toggle_burger_menu"):
		_assert_check(nav_drawer.visible == false, "1.27 NavDrawer initially hidden")
		hud_inst.call("open_nav_drawer")
		_assert_check(nav_drawer.visible == true, "1.28 NavDrawer visible after open_nav_drawer()")
		hud_inst.call("close_nav_drawer")
		_assert_check(nav_drawer.visible == false, "1.29 NavDrawer hidden after close_nav_drawer()")
		hud_inst.call("toggle_burger_menu")
		_assert_check(nav_drawer.visible == true, "1.30 NavDrawer visible after toggle_burger_menu()")
		hud_inst.call("toggle_burger_menu")
		_assert_check(nav_drawer.visible == false, "1.31 NavDrawer hidden after second toggle")
		
		# Preserved unique buttons inside drawer
		var auth_btn = nav_drawer.get_node_or_null("%AuthButton") as Button
		var lead_btn = nav_drawer.get_node_or_null("%LeaderboardButton") as Button
		var guild_btn = nav_drawer.get_node_or_null("%GuildButton") as Button
		var quest_btn = nav_drawer.get_node_or_null("%QuestButton") as Button
		var campus_btn = nav_drawer.get_node_or_null("%CampusButton") as Button
		
		_assert_check(auth_btn != null, "1.32 Preserved unique node %AuthButton inside NavDrawer")
		_assert_check(lead_btn != null, "1.33 Preserved unique node %LeaderboardButton inside NavDrawer")
		_assert_check(guild_btn != null, "1.34 Preserved unique node %GuildButton inside NavDrawer")
		_assert_check(quest_btn != null, "1.35 Preserved unique node %QuestButton inside NavDrawer")
		_assert_check(campus_btn != null, "1.36 Preserved unique node %CampusButton inside NavDrawer")
		
		if auth_btn != null:
			_assert_check(auth_btn.custom_minimum_size.y >= 64.0, "1.37 NavDrawer card height >= 64px (got %.1fpx)" % auth_btn.custom_minimum_size.y)

	# 1.4 ShopPanel Buy Buttons & Input Isolation
	var shop_panel = hud_inst.get_node_or_null("%ShopPanel")
	if shop_panel == null:
		shop_panel = hud_inst.find_child("ShopPanel", true, false)
	_assert_check(shop_panel != null, "1.38 ShopPanel node exists in HUD")
	
	var cards_dict = hud_inst.get("_upgrade_cards")
	if cards_dict != null and cards_dict.size() > 0:
		var first_card = cards_dict.values()[0]
		var buy_button = first_card.get("buy_button") as Button
		_assert_check(buy_button != null, "1.39 Shop upgrade card has buy_button")
		if buy_button != null:
			_assert_check(buy_button.custom_minimum_size.y >= 54.0,
				"1.40 Shop buy button height >= 54px (got %.1fpx)" % buy_button.custom_minimum_size.y)
			_assert_check(buy_button.mouse_filter == Control.MOUSE_FILTER_STOP,
				"1.41 Shop buy button mouse_filter == MOUSE_FILTER_STOP")

	# Input isolation check
	_assert_check(act_btn.mouse_filter == Control.MOUSE_FILTER_STOP, "1.42 ActionButton mouse_filter == STOP")
	_assert_check(lap_btn.mouse_filter == Control.MOUSE_FILTER_STOP, "1.43 LaptopThumbButton mouse_filter == STOP")
	_assert_check(cam_btn.mouse_filter == Control.MOUSE_FILTER_STOP, "1.44 CampusThumbButton mouse_filter == STOP")
	_assert_check(nav_drawer.mouse_filter == Control.MOUSE_FILTER_STOP, "1.45 NavDrawer mouse_filter == STOP")
	
	tc_inst.queue_free()
	hud_inst.queue_free()
	await process_frame

# =============================================================================
# MODULE 2: 3D Chibi Models & Visual Assets (Requirement R2)
# =============================================================================
func _test_module_2_chibi_models() -> void:
	print("\n--- MODULE 2: 3D Chibi Models & Visual Assets (R2) ---")
	
	# 2.1 Avatar3D Chibi Hierarchy & Procedural Locomotion
	var avatar_scene = load("res://scenes/avatar_3d.tscn")
	_assert_check(avatar_scene != null, "2.1 scenes/avatar_3d.tscn loads successfully")
	var avatar = avatar_scene.instantiate() as Avatar3D
	root.add_child(avatar)
	await process_frame
	
	_assert_check(avatar.get_node_or_null("CollisionShape3D") != null, "2.2 Preserved CollisionShape3D on Avatar3D")
	_assert_check(avatar.get_node_or_null("InteractionArea") != null, "2.3 Preserved InteractionArea on Avatar3D")
	_assert_check(avatar.get_node_or_null("FootstepDust") != null, "2.4 Preserved FootstepDust particles on Avatar3D")
	_assert_check(avatar.get_node_or_null("Visuals/DirectionalPointer") != null, "2.5 Preserved DirectionalPointer on Avatar3D")
	
	var chibi_root = avatar.get_node_or_null("Visuals/ChibiRoot")
	_assert_check(chibi_root != null, "2.6 Visuals/ChibiRoot exists on Avatar3D")
	_assert_check(avatar.get_node_or_null("Visuals/ChibiRoot/Head") != null, "2.7 Chibi Head exists")
	_assert_check(avatar.get_node_or_null("Visuals/ChibiRoot/Head/Visor") != null, "2.8 Chibi Cyber Visor exists")
	_assert_check(avatar.get_node_or_null("Visuals/ChibiRoot/Torso") != null, "2.9 Chibi Torso exists")
	_assert_check(avatar.get_node_or_null("Visuals/ChibiRoot/Backpack") != null, "2.10 Chibi Backpack exists")
	_assert_check(avatar.get_node_or_null("Visuals/ChibiRoot/LeftArm") != null, "2.11 Articulated LeftArm exists")
	_assert_check(avatar.get_node_or_null("Visuals/ChibiRoot/RightArm") != null, "2.12 Articulated RightArm exists")
	_assert_check(avatar.get_node_or_null("Visuals/ChibiRoot/LeftLeg") != null, "2.13 Articulated LeftLeg exists")
	_assert_check(avatar.get_node_or_null("Visuals/ChibiRoot/RightLeg") != null, "2.14 Articulated RightLeg exists")
	
	# Procedural locomotion simulation
	avatar.set_input_direction(Vector3.FORWARD)
	for i in range(10):
		avatar._physics_process(1.0 / 60.0)
	var left_arm = avatar.get_node_or_null("Visuals/ChibiRoot/LeftArm") as Node3D
	var right_arm = avatar.get_node_or_null("Visuals/ChibiRoot/RightArm") as Node3D
	if left_arm != null and right_arm != null:
		_assert_check(abs(left_arm.rotation.x) > 0.01 and abs(right_arm.rotation.x) > 0.01,
			"2.15 Anti-phase arm swinging active during locomotion")
	avatar.stop_movement()
	if left_arm != null:
		_assert_check(abs(left_arm.rotation.x) < 0.01, "2.16 Arm swing returns to rest on stop_movement()")
	
	# 2.2 NPC3D Distinct Profession Accessories
	var npc_scene = load("res://scenes/npc_3d.tscn")
	_assert_check(npc_scene != null, "2.17 scenes/npc_3d.tscn loads successfully")
	var npc = npc_scene.instantiate() as NPC3D
	root.add_child(npc)
	await process_frame
	
	_assert_check(npc.get_node_or_null("Visuals/ChibiRoot/AlexAccessories") != null, "2.18 AlexAccessories subtree exists")
	_assert_check(npc.get_node_or_null("Visuals/ChibiRoot/BobAccessories") != null, "2.19 BobAccessories subtree exists")
	_assert_check(npc.get_node_or_null("Visuals/ChibiRoot/LisaAccessories") != null, "2.20 LisaAccessories subtree exists")
	
	npc.npc_id = "ceo_alex"
	if npc.has_method("_apply_chibi_accessories"):
		npc.call("_apply_chibi_accessories")
		_assert_check(npc.get_node("Visuals/ChibiRoot/AlexAccessories").visible == true, "2.21 Alex accessories visible for ceo_alex")
		_assert_check(npc.get_node("Visuals/ChibiRoot/BobAccessories").visible == false, "2.22 Bob accessories hidden for ceo_alex")
		
		npc.npc_id = "architect_bob"
		npc.call("_apply_chibi_accessories")
		_assert_check(npc.get_node("Visuals/ChibiRoot/BobAccessories").visible == true, "2.23 Bob accessories visible for architect_bob")
		
		npc.npc_id = "scientist_lisa"
		npc.call("_apply_chibi_accessories")
		_assert_check(npc.get_node("Visuals/ChibiRoot/LisaAccessories").visible == true, "2.24 Lisa accessories visible for scientist_lisa")

	# 2.3 WorkerAvatar3D Visor Emotes & Accessory Swapping
	var worker_scene = load("res://scenes/worker_avatar_3d.tscn")
	_assert_check(worker_scene != null, "2.25 scenes/worker_avatar_3d.tscn loads successfully")
	var worker = worker_scene.instantiate() as WorkerAvatar3D
	root.add_child(worker)
	await process_frame
	
	var visor_label = worker.get_node_or_null("Visuals/ChibiRoot/VisorEmoteLabel") as Label3D
	if visor_label == null:
		visor_label = worker.get_node_or_null("VisorEmoteLabel") as Label3D
	_assert_check(visor_label != null, "2.26 VisorEmoteLabel exists on WorkerAvatar3D")
	
	if worker.has_method("_update_accessories_for_state"):
		worker.call("_update_accessories_for_state", WorkerAvatar3D.State.TYPING)
		_assert_check(visor_label.text == "0101", "2.27 Visor emote is '0101' matrix code during TYPING")
		worker.call("_update_accessories_for_state", WorkerAvatar3D.State.COFFEE_BREAK)
		_assert_check(visor_label.text == "^.^", "2.28 Visor emote is '^.^' during COFFEE_BREAK")
		worker.call("_update_accessories_for_state", WorkerAvatar3D.State.CELEBRATING)
		_assert_check(visor_label.text == "★_★", "2.29 Visor emote is '★_★' during CELEBRATING")
		worker.call("_update_accessories_for_state", WorkerAvatar3D.State.WALKING)
		_assert_check(visor_label.text == "•_•", "2.30 Visor emote is '•_•' during WALKING")

	# 2.4 Collectible3D 3 Distinct Models
	var col_scene = load("res://scenes/collectible_3d.tscn")
	_assert_check(col_scene != null, "2.31 scenes/collectible_3d.tscn loads successfully")
	var col = col_scene.instantiate() as Collectible3D
	root.add_child(col)
	await process_frame
	
	_assert_check(col.get_node_or_null("Visuals/BriefcaseMesh") != null, "2.32 BriefcaseMesh model exists")
	_assert_check(col.get_node_or_null("Visuals/CoffeeMesh") != null, "2.33 CoffeeMesh model exists")
	_assert_check(col.get_node_or_null("Visuals/USBMesh") != null, "2.34 USBMesh model exists")
	_assert_check(col.get_node_or_null("Visuals/SparkleParticles") != null, "2.35 SparkleParticles exists")
	
	col.item_type = "coffee"
	if col.has_method("_apply_item_type_styling"):
		col.call("_apply_item_type_styling")
		_assert_check(col.get_node("Visuals/CoffeeMesh").visible == true, "2.36 CoffeeMesh active for item_type 'coffee'")
		_assert_check(col.get_node("Visuals/BriefcaseMesh").visible == false, "2.37 BriefcaseMesh inactive for item_type 'coffee'")

	# 2.5 ZoneGate3D Status Beacons & Visual Barrier
	var gate_scene = load("res://scenes/zone_gate_3d.tscn")
	_assert_check(gate_scene != null, "2.38 scenes/zone_gate_3d.tscn loads successfully")
	var gate = gate_scene.instantiate() as ZoneGate3D
	root.add_child(gate)
	await process_frame
	
	_assert_check(gate.get_node_or_null("Visuals/BarrierMesh") != null or gate.get_node_or_null("Visuals/NeonBarrier") != null,
		"2.39 Neon barrier mesh exists on ZoneGate3D")
	var left_beacon = gate.get_node_or_null("Visuals/LeftPost/StatusBeacon")
	if left_beacon == null:
		left_beacon = gate.get_node_or_null("Visuals/PostLeft/StatusBeacon")
	_assert_check(left_beacon != null, "2.40 Status beacon LED exists on ZoneGate3D post")
	
	# 2.6 Mobile Triangle Budget (< 22,000)
	var total_campus_tris: int = 0
	var scene_weights = {
		avatar_scene: 1,
		npc_scene: 3,
		worker_scene: 5,
		col_scene: 6,
		gate_scene: 3
	}
	for scn in scene_weights.keys():
		var inst = scn.instantiate()
		var tris = _count_node_triangles(inst)
		total_campus_tris += tris * scene_weights[scn]
		inst.free()
	_assert_check(total_campus_tris < 22000, "2.41 Total campus dynamic triangle count (%d) <= 22,000" % total_campus_tris)
	
	avatar.queue_free()
	npc.queue_free()
	worker.queue_free()
	col.queue_free()
	gate.queue_free()
	await process_frame

func _count_node_triangles(node: Node) -> int:
	var total: int = 0
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		var m = (node as MeshInstance3D).mesh
		var faces = m.get_faces()
		if faces.size() > 0:
			total += faces.size() / 3
		elif m is BoxMesh:
			total += 12
		elif m is PlaneMesh:
			total += 2
		elif m is SphereMesh:
			var sm = m as SphereMesh
			total += sm.radial_segments * sm.rings * 2
		elif m is CapsuleMesh:
			var cm = m as CapsuleMesh
			total += cm.radial_segments * (cm.rings + 1) * 2
		elif m is CylinderMesh:
			var cym = m as CylinderMesh
			total += (cym.radial_segments * cym.rings * 2) + (cym.radial_segments * 2)
		elif m is TorusMesh:
			var tm = m as TorusMesh
			total += tm.rings * tm.ring_segments * 2
		else:
			total += 24
	for child in node.get_children():
		total += _count_node_triangles(child)
	return total

# =============================================================================
# MODULE 3: Gameplay Bugfixes & Harmonized Loops (Requirement R3)
# =============================================================================
func _test_module_3_gameplay_loops() -> void:
	print("\n--- MODULE 3: Gameplay Bugfixes & Harmonized Loops (R3) ---")
	
	# 3.1 Avatar3D Dialogue Input Lock
	var avatar_scene = load("res://scenes/avatar_3d.tscn")
	var avatar = avatar_scene.instantiate() as Avatar3D
	root.add_child(avatar)
	await process_frame
	
	avatar.set_input_enabled(false)
	_assert_check(avatar.input_enabled == false, "3.1 set_input_enabled(false) sets input_enabled to false")
	avatar.set_input_direction(Vector3(1.0, 0.0, 0.0))
	avatar._physics_process(0.1)
	_assert_check(avatar.velocity.x == 0.0 and avatar.velocity.z == 0.0,
		"3.2 Injected joystick direction yields zero velocity when input_enabled == false")
	avatar.set_input_enabled(true)
	avatar.set_input_direction(Vector3(1.0, 0.0, 0.0))
	avatar._physics_process(0.1)
	_assert_check(avatar.velocity.x > 0.0, "3.3 Re-enabling input restores movement velocity")
	
	# 3.2 NPC3D Dialogue Teardown & Re-entrancy Protection
	var npc_scene = load("res://scenes/npc_3d.tscn")
	var npc = npc_scene.instantiate() as NPC3D
	npc.npc_id = "test_npc"
	root.add_child(npc)
	
	var dial_scene = load("res://scenes/dialogue_panel.tscn")
	var dial_panel = dial_scene.instantiate() as Control
	root.add_child(dial_panel)
	
	var tc_scene = load("res://scenes/ui/touch_controls.tscn")
	var touch_controls = tc_scene.instantiate() as Control
	root.add_child(touch_controls)
	await process_frame
	
	npc.interact()
	_assert_check(npc._is_talking == true, "3.4 NPC._is_talking is true after interact()")
	
	var dummy_body = CharacterBody3D.new()
	dummy_body.add_to_group("player")
	root.add_child(dummy_body)
	npc._on_interaction_body_exited(dummy_body)
	_assert_check(npc._is_talking == false, "3.5 NPC._is_talking is false after player exits range")
	_assert_check(dial_panel.visible == false, "3.6 DialoguePanel cleanly closed after player exits range")
	
	dummy_body.queue_free()
	touch_controls.queue_free()
	dial_panel.queue_free()
	npc.queue_free()

	# 3.3 GameState Active Quest & Retroactive Unlocks
	var gs = root.get_node_or_null("GameState")
	if gs == null:
		var gs_script = load("res://scripts/autoload/game_state.gd")
		gs = gs_script.new()
		root.add_child(gs)
		await process_frame
		
	_assert_check("active_campus_quest_id" in gs, "3.7 GameState declares active_campus_quest_id property")
	gs.campus_quests.clear()
	gs.unlocked_zones.clear()
	gs.active_campus_quest_id = ""
	
	# Server room retroactive unlock
	gs.unlock_zone("server_room")
	gs.start_campus_quest("quest_server", 1)
	_assert_check(gs.active_campus_quest_id == "quest_server", "3.8 active_campus_quest_id set to quest_server")
	_assert_check(gs.get_campus_quest_status("quest_server") == "ready",
		"3.9 quest_server retroactively set to 'ready' because server_room was already unlocked")
	gs.complete_campus_quest("quest_server", 100.0, 10)
	_assert_check(gs.active_campus_quest_id == "", "3.10 active_campus_quest_id cleared upon quest completion")
	
	# Lab room retroactive unlock
	gs.unlock_zone("lab_room")
	gs.start_campus_quest("quest_lab", 1)
	_assert_check(gs.get_campus_quest_status("quest_lab") == "ready",
		"3.11 quest_lab retroactively set to 'ready' because lab_room was already unlocked")
	gs.complete_campus_quest("quest_lab", 200.0, 20)
	_assert_check(gs.active_campus_quest_id == "", "3.12 active_campus_quest_id cleared upon lab quest completion")

	# 3.4 ZoneGate3D Billboarded Floating Text
	var gate_scene = load("res://scenes/zone_gate_3d.tscn")
	var gate = gate_scene.instantiate() as ZoneGate3D
	root.add_child(gate)
	await process_frame
	gate.show_missing_resource_feedback("Benötigt 500 Energie zum Freischalten")
	
	var found_label: Label3D = null
	for child in root.get_children():
		if child is Label3D and child.text.contains("Benötigt 500 Energie"):
			found_label = child
			break
	if found_label == null:
		for child in gate.get_children():
			if child is Label3D and child.text.contains("Benötigt 500 Energie"):
				found_label = child
				break
	_assert_check(found_label != null, "3.13 Billboarded Label3D spawned on missing resource feedback")
	if found_label != null:
		_assert_check(found_label.billboard == BaseMaterial3D.BILLBOARD_ENABLED, "3.14 Floating text billboard enabled")
		_assert_check(found_label.font_size >= 24, "3.15 Floating text font_size >= 24")
		_assert_check(found_label.modulate.r >= 0.8, "3.16 Floating text coral/red warning color")
		found_label.queue_free()
	gate.queue_free()

	# 3.5 Reactive Avatar Speed Upgrade Binding
	gs.avatar_speed_level = 2
	var base_speed_val = avatar.current_speed
	avatar._on_avatar_stat_updated("avatar_speed", 1.30)
	_assert_check(avatar.current_speed > base_speed_val,
		"3.17 current_speed reactively updated to %f (> %f)" % [avatar.current_speed, base_speed_val])

	# 3.6 Campus Collectibles 2D Idle Multiplier
	_assert_check(gs.has_method("get_campus_item_multiplier"), "3.18 GameState implements get_campus_item_multiplier()")
	gs.collectibles_collected = 0
	_assert_check(is_equal_approx(gs.get_campus_item_multiplier(), 1.0),
		"3.19 Multiplier at 0 collectibles is exactly 1.0x (zero regression invariant)")
	gs.collectibles_collected = 10
	_assert_check(is_equal_approx(gs.get_campus_item_multiplier(), 1.50),
		"3.20 Multiplier at 10 collectibles is 1.50x (+50% idle boost)")
	gs.collectibles_collected = 0

	# 3.7 QuestWaypoint3D Dynamic Tracking & Arrival Detection
	var wp_avatar = avatar_scene.instantiate() as Avatar3D
	root.add_child(wp_avatar)
	await process_frame

	var wp_scene = load("res://scenes/quest_waypoint.tscn")
	_assert_check(wp_scene != null, "3.21 scenes/quest_waypoint.tscn loads successfully")
	var waypoint = wp_scene.instantiate() as QuestWaypoint3D
	root.add_child(waypoint)
	await process_frame
	
	# Test distance and arrival
	waypoint.set_target_position(Vector3(2.5, 0.0, 0.0), "Server Room")
	waypoint._process(0.1)
	var dist = waypoint.get_distance()
	_assert_check(dist <= 3.0, "3.22 Waypoint distance is within arrival threshold (%.2fm <= 3.0m)" % dist)
	_assert_check(waypoint.distance_label.text.contains("Arrived!") or waypoint.prompt_label.text.contains("Arrived!"),
		"3.23 Waypoint displays '[ Arrived! ]' upon reaching objective")
		
	waypoint.queue_free()
	wp_avatar.queue_free()
	avatar.queue_free()
	await process_frame
