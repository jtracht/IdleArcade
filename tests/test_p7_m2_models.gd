extends SceneTree

## =============================================================================
## Unit & Integration Test Suite for Milestone P7-M2:
## Chibi 3D Models & Visual Assets Relaunch
## File: IdleArcade/tests/test_p7_m2_models.gd
##
## Validates:
##   1. Chibi Player Avatar (avatar_3d.tscn, avatar_3d.gd):
##      - Visuals/ChibiRoot hierarchy: Head (radius ~0.35) with Visor/Hair,
##        compact Torso, commuter Backpack, articulated limbs (LeftArm, RightArm, LeftLeg, RightLeg).
##      - Preserved nodes: CollisionShape3D, InteractionArea, FootstepDust, GroundShadow.
##      - Procedural locomotion: anti-phase arm/leg swinging and torso bobbing.
##   2. NPCs with Distinct Chibi Features (npc_3d.tscn, npc_3d.gd):
##      - Modular profession accessories: Alex (tie, dark glasses), Bob (hard hat, goggles, blueprint),
##        Lisa (lab coat, ponytail, glowing quantum flask).
##      - Dynamic switching via _apply_chibi_accessories() / _apply_visual_styling().
##      - Preserved billboard labels: NameLabel3D, PromptLabel3D, QuestMarkerLabel3D, EmoteLabel3D.
##   3. Incubator Workers (worker_avatar_3d.tscn, worker_avatar_3d.gd):
##      - Miniature Chibi model with VisorEmoteLabel reflecting FSM states
##        (TYPING "0101", WALKING "•_•", COFFEE_BREAK "^.^", CELEBRATING "★_★").
##      - Dynamic accessory swapping: LaptopBase/LaptopScreen vs CoffeeMug with steam.
##   4. 3 Distinct Collectible Props (collectible_3d.tscn, collectible_3d.gd):
##      - Distinct 3D models for "briefcase", "coffee" (with steam particles), "usb_drive" (with LED).
##      - Continuous rotation, sine wave bobbing, and sparkle particles.
##   5. Campus Tech Gates (zone_gate_3d.tscn, zone_gate_3d.gd):
##      - StatusBeacon LED indicators on posts (red when locked, green when unlocked, amber when affordable).
##      - Glowing neon barrier and unlock particles.
##      - 3D floating text feedback on missing resources.
##
## Execution:
##   godot --headless --path IdleArcade -s tests/test_p7_m2_models.gd
## =============================================================================

var pass_count: int = 0
var fail_count: int = 0

func _init() -> void:
	print("\n====================================================================")
	print(">>> RUNNING MILESTONE P7-M2 CHIBI 3D MODELS & VISUAL ASSETS TEST SUITE <<<")
	print("====================================================================")
	
	await process_frame
	
	await _test_chibi_player_avatar()
	await _test_chibi_npcs()
	await _test_incubator_workers()
	await _test_distinct_collectibles()
	await _test_campus_tech_gates()
	await _test_mobile_performance_materials()
	
	print("\n====================================================================")
	print(">>> P7-M2 TEST SUITE SUMMARY: %d PASSED, %d FAILED <<<" % [pass_count, fail_count])
	print("====================================================================")
	
	if fail_count == 0:
		print(">>> ALL P7-M2 TESTS PASSED WITH 100% GREEN INTEGRITY! <<<")
		quit(0)
	else:
		printerr(">>> P7-M2 TESTS FAILED WITH %d ERRORS! <<<" % fail_count)
		quit(1)

func _assert_check(condition: bool, description: String) -> void:
	if condition:
		pass_count += 1
		print("  [PASS] %s" % description)
	else:
		fail_count += 1
		printerr("  [FAIL] %s" % description)

## -----------------------------------------------------------------------------
## 1. Chibi Player Avatar Tests
## -----------------------------------------------------------------------------
func _test_chibi_player_avatar() -> void:
	print("\n--- Module 1: Chibi Player Avatar Hierarchy & Locomotion ---")
	var scene = load("res://scenes/avatar_3d.tscn")
	_assert_check(scene != null, "scenes/avatar_3d.tscn loads successfully")
	if scene == null:
		return
		
	var avatar = scene.instantiate() as Avatar3D
	_assert_check(avatar != null, "Instantiated Avatar3D node")
	if avatar == null:
		return
		
	root.add_child(avatar)
	await process_frame
	
	# Verify preserved core physics & interaction nodes
	_assert_check(avatar.get_node_or_null("CollisionShape3D") != null, "Preserved CollisionShape3D")
	_assert_check(avatar.get_node_or_null("InteractionArea") != null, "Preserved InteractionArea")
	_assert_check(avatar.get_node_or_null("FootstepDust") != null, "Preserved FootstepDust particles")
	_assert_check(avatar.get_node_or_null("Visuals/GroundShadow") != null, "Preserved Visuals/GroundShadow")
	
	# Verify Chibi hierarchy
	var chibi_root = avatar.get_node_or_null("Visuals/ChibiRoot")
	_assert_check(chibi_root != null, "Visuals/ChibiRoot node exists")
	_assert_check(avatar.get_node_or_null("Visuals/ChibiRoot/Head") != null, "Visuals/ChibiRoot/Head exists")
	_assert_check(avatar.get_node_or_null("Visuals/ChibiRoot/Head/Visor") != null, "Visuals/ChibiRoot/Head/Visor exists")
	_assert_check(avatar.get_node_or_null("Visuals/ChibiRoot/Torso") != null, "Visuals/ChibiRoot/Torso exists")
	_assert_check(avatar.get_node_or_null("Visuals/ChibiRoot/Backpack") != null, "Visuals/ChibiRoot/Backpack exists")
	_assert_check(avatar.get_node_or_null("Visuals/ChibiRoot/LeftArm") != null, "Visuals/ChibiRoot/LeftArm exists")
	_assert_check(avatar.get_node_or_null("Visuals/ChibiRoot/RightArm") != null, "Visuals/ChibiRoot/RightArm exists")
	_assert_check(avatar.get_node_or_null("Visuals/ChibiRoot/LeftLeg") != null, "Visuals/ChibiRoot/LeftLeg exists")
	_assert_check(avatar.get_node_or_null("Visuals/ChibiRoot/RightLeg") != null, "Visuals/ChibiRoot/RightLeg exists")
	
	# Test procedural locomotion limb swing
	avatar._update_procedural_animation(0.1, Vector3(5.0, 0.0, 0.0))
	var l_arm = avatar.get_node_or_null("Visuals/ChibiRoot/LeftArm") as Node3D
	var r_arm = avatar.get_node_or_null("Visuals/ChibiRoot/RightArm") as Node3D
	var l_leg = avatar.get_node_or_null("Visuals/ChibiRoot/LeftLeg") as Node3D
	var r_leg = avatar.get_node_or_null("Visuals/ChibiRoot/RightLeg") as Node3D
	
	_assert_check(l_arm != null and r_arm != null, "Limb nodes resolved on avatar")
	if l_arm != null and r_arm != null:
		# Anti-phase check: when moving, arm rotations swing in opposite directions
		_assert_check(abs(l_arm.rotation.x) > 0.001, "Left arm rotates during locomotion")
		_assert_check(abs(r_arm.rotation.x) > 0.001, "Right arm rotates during locomotion")
		_assert_check(is_equal_approx(l_arm.rotation.x, -r_arm.rotation.x), "Arms rotate in exact anti-phase (left = -right)")
		
	if l_leg != null and r_leg != null:
		_assert_check(is_equal_approx(l_leg.rotation.x, -r_leg.rotation.x), "Legs rotate in exact anti-phase (left = -right)")
		# Arm and opposite leg swing together
		if l_arm != null:
			_assert_check(sign(l_arm.rotation.x) != sign(l_leg.rotation.x) or is_zero_approx(l_arm.rotation.x), "Left arm swings opposite to left leg")
			
	# Test stop_movement resets limbs
	avatar.stop_movement()
	if l_arm != null and r_arm != null:
		_assert_check(is_zero_approx(l_arm.rotation.x) and is_zero_approx(r_arm.rotation.x), "stop_movement() restores arms to resting angle")
	if l_leg != null and r_leg != null:
		_assert_check(is_zero_approx(l_leg.rotation.x) and is_zero_approx(r_leg.rotation.x), "stop_movement() restores legs to resting angle")
		
	avatar.queue_free()
	await process_frame

## -----------------------------------------------------------------------------
## 2. Chibi NPCs Tests
## -----------------------------------------------------------------------------
func _test_chibi_npcs() -> void:
	print("\n--- Module 2: Distinct Chibi NPCs & Profession Accessories ---")
	var scene = load("res://scenes/npc_3d.tscn")
	_assert_check(scene != null, "scenes/npc_3d.tscn loads successfully")
	if scene == null:
		return
		
	var npc = scene.instantiate() as NPC3D
	_assert_check(npc != null, "Instantiated NPC3D node")
	if npc == null:
		return
		
	root.add_child(npc)
	await process_frame
	
	# Preserved billboard labels
	_assert_check(npc.get_node_or_null("Visuals/NameLabel3D") != null, "Preserved NameLabel3D")
	_assert_check(npc.get_node_or_null("Visuals/PromptLabel3D") != null, "Preserved PromptLabel3D")
	_assert_check(npc.get_node_or_null("Visuals/QuestMarkerLabel3D") != null, "Preserved QuestMarkerLabel3D")
	_assert_check(npc.get_node_or_null("Visuals/EmoteLabel3D") != null, "Preserved EmoteLabel3D")
	
	# Chibi root and accessories
	var alex_acc = npc.get_node_or_null("Visuals/ChibiRoot/AlexAccessories")
	var bob_acc = npc.get_node_or_null("Visuals/ChibiRoot/BobAccessories")
	var lisa_acc = npc.get_node_or_null("Visuals/ChibiRoot/LisaAccessories")
	_assert_check(alex_acc != null, "AlexAccessories node exists (tie, dark glasses)")
	_assert_check(bob_acc != null, "BobAccessories node exists (hard hat, goggles, blueprint)")
	_assert_check(lisa_acc != null, "LisaAccessories node exists (lab coat, ponytail, flask)")
	
	# Test profession styling for CEO Alex
	npc.npc_id = "ceo_alex"
	npc._apply_chibi_accessories()
	_assert_check(alex_acc.visible == true, "CEO Alex: AlexAccessories is visible")
	_assert_check(bob_acc.visible == false, "CEO Alex: BobAccessories is hidden")
	_assert_check(lisa_acc.visible == false, "CEO Alex: LisaAccessories is hidden")
	
	# Test profession styling for Architect Bob
	npc.npc_id = "architect_bob"
	npc._apply_chibi_accessories()
	_assert_check(alex_acc.visible == false, "Architect Bob: AlexAccessories is hidden")
	_assert_check(bob_acc.visible == true, "Architect Bob: BobAccessories is visible")
	_assert_check(lisa_acc.visible == false, "Architect Bob: LisaAccessories is hidden")
	
	# Test profession styling for Dr. Lisa
	npc.npc_id = "scientist_lisa"
	npc._apply_chibi_accessories()
	_assert_check(alex_acc.visible == false, "Dr. Lisa: AlexAccessories is hidden")
	_assert_check(bob_acc.visible == false, "Dr. Lisa: BobAccessories is hidden")
	_assert_check(lisa_acc.visible == true, "Dr. Lisa: LisaAccessories is visible")
	
	npc.queue_free()
	await process_frame

## -----------------------------------------------------------------------------
## 3. Incubator Workers Tests
## -----------------------------------------------------------------------------
func _test_incubator_workers() -> void:
	print("\n--- Module 3: Chibi Workers, Visor Emotions & Dynamic Accessories ---")
	var scene = load("res://scenes/worker_avatar_3d.tscn")
	_assert_check(scene != null, "scenes/worker_avatar_3d.tscn loads successfully")
	if scene == null:
		return
		
	var worker = scene.instantiate() as WorkerAvatar3D
	_assert_check(worker != null, "Instantiated WorkerAvatar3D node")
	if worker == null:
		return
		
	root.add_child(worker)
	await process_frame
	
	var visor_label = worker.get_node_or_null("Visuals/ChibiRoot/VisorEmoteLabel") as Label3D
	var laptop = worker.get_node_or_null("Visuals/ChibiRoot/LaptopRoot")
	var coffee = worker.get_node_or_null("Visuals/ChibiRoot/CoffeeMug")
	
	_assert_check(visor_label != null, "VisorEmoteLabel node exists in ChibiRoot")
	_assert_check(laptop != null, "LaptopRoot node exists in ChibiRoot")
	_assert_check(coffee != null, "CoffeeMug node exists in ChibiRoot")
	_assert_check(worker.get_node_or_null("Visuals/ChibiRoot/LaptopRoot/LaptopScreen") != null, "LaptopScreen preserved for test compatibility")
	_assert_check(worker.get_node_or_null("Visuals/SpeechBubble3D") != null, "SpeechBubble3D preserved")
	
	# State 1: TYPING -> Laptop visible, Mug hidden, Visor emote = "0101"
	worker._update_accessories_for_state(WorkerAvatar3D.State.TYPING)
	_assert_check(laptop.visible == true, "TYPING: LaptopRoot is visible")
	_assert_check(coffee.visible == false, "TYPING: CoffeeMug is hidden")
	_assert_check(visor_label.text == "0101", "TYPING: Visor displays matrix code '0101'")
	
	# State 2: COFFEE_BREAK -> Laptop hidden, Mug visible, Visor emote = "^.^"
	worker._update_accessories_for_state(WorkerAvatar3D.State.COFFEE_BREAK)
	_assert_check(laptop.visible == false, "COFFEE_BREAK: LaptopRoot is hidden")
	_assert_check(coffee.visible == true, "COFFEE_BREAK: CoffeeMug is visible")
	_assert_check(visor_label.text == "^.^", "COFFEE_BREAK: Visor displays happy smile '^.^'")
	
	# State 3: WALKING -> Both hidden, Visor emote = "•_•"
	worker._update_accessories_for_state(WorkerAvatar3D.State.WALKING)
	_assert_check(laptop.visible == false, "WALKING: LaptopRoot is hidden")
	_assert_check(coffee.visible == false, "WALKING: CoffeeMug is hidden")
	_assert_check(visor_label.text == "•_•", "WALKING: Visor displays focused eyes '•_•'")
	
	# State 4: CELEBRATING -> Both hidden, Visor emote = "★_★"
	worker._update_accessories_for_state(WorkerAvatar3D.State.CELEBRATING)
	_assert_check(visor_label.text == "★_★", "CELEBRATING: Visor displays star eyes '★_★'")
	
	worker.queue_free()
	await process_frame

## -----------------------------------------------------------------------------
## 4. Distinct Collectible Props Tests
## -----------------------------------------------------------------------------
func _test_distinct_collectibles() -> void:
	print("\n--- Module 4: 3 Distinct Collectible Props (Briefcase, Coffee, USB) ---")
	var scene = load("res://scenes/collectible_3d.tscn")
	_assert_check(scene != null, "scenes/collectible_3d.tscn loads successfully")
	if scene == null:
		return
		
	var coll = scene.instantiate() as Collectible3D
	_assert_check(coll != null, "Instantiated Collectible3D node")
	if coll == null:
		return
		
	root.add_child(coll)
	await process_frame
	
	var briefcase = coll.get_node_or_null("Visuals/BriefcaseMesh")
	var coffee = coll.get_node_or_null("Visuals/CoffeeMesh")
	var usb = coll.get_node_or_null("Visuals/USBMesh")
	var sparkles = coll.get_node_or_null("Visuals/SparkleParticles") as CPUParticles3D
	
	_assert_check(briefcase != null, "Visuals/BriefcaseMesh exists")
	_assert_check(coffee != null, "Visuals/CoffeeMesh exists")
	_assert_check(usb != null, "Visuals/USBMesh exists")
	_assert_check(sparkles != null, "Visuals/SparkleParticles exists")
	_assert_check(coll.get_node_or_null("Visuals/CoffeeMesh/SteamParticles") != null, "Coffee mug has SteamParticles")
	
	# Test Briefcase activation
	coll.item_type = "briefcase"
	coll._apply_item_type_styling()
	_assert_check(briefcase.visible == true, "item_type='briefcase' activates BriefcaseMesh")
	_assert_check(coffee.visible == false, "item_type='briefcase' hides CoffeeMesh")
	_assert_check(usb.visible == false, "item_type='briefcase' hides USBMesh")
	
	# Test Coffee activation
	coll.item_type = "coffee"
	coll._apply_item_type_styling()
	_assert_check(briefcase.visible == false, "item_type='coffee' hides BriefcaseMesh")
	_assert_check(coffee.visible == true, "item_type='coffee' activates CoffeeMesh")
	_assert_check(usb.visible == false, "item_type='coffee' hides USBMesh")
	
	# Test USB Drive activation
	coll.item_type = "usb_drive"
	coll._apply_item_type_styling()
	_assert_check(briefcase.visible == false, "item_type='usb_drive' hides BriefcaseMesh")
	_assert_check(coffee.visible == false, "item_type='usb_drive' hides CoffeeMesh")
	_assert_check(usb.visible == true, "item_type='usb_drive' activates USBMesh")
	
	# Continuous rotation and bobbing animation check
	var initial_rot_y = coll.visuals.rotation.y
	coll._process(0.1)
	_assert_check(coll.visuals.rotation.y != initial_rot_y, "Continuous Y-axis rotation advances in _process()")
	
	coll.queue_free()
	await process_frame

## -----------------------------------------------------------------------------
## 5. Campus Tech Gates Tests
## -----------------------------------------------------------------------------
func _test_campus_tech_gates() -> void:
	print("\n--- Module 5: Campus Tech Gates & Status Beacons ---")
	var scene = load("res://scenes/zone_gate_3d.tscn")
	_assert_check(scene != null, "scenes/zone_gate_3d.tscn loads successfully")
	if scene == null:
		return
		
	var gate = scene.instantiate() as ZoneGate3D
	_assert_check(gate != null, "Instantiated ZoneGate3D node")
	if gate == null:
		return
		
	root.add_child(gate)
	await process_frame
	
	var left_beacon = gate.get_node_or_null("Visuals/LeftPost/StatusBeacon")
	var right_beacon = gate.get_node_or_null("Visuals/RightPost/StatusBeacon")
	var unlock_fx = gate.get_node_or_null("Visuals/UnlockParticles") as CPUParticles3D
	
	_assert_check(left_beacon != null, "LeftPost/StatusBeacon exists")
	_assert_check(right_beacon != null, "RightPost/StatusBeacon exists")
	_assert_check(unlock_fx != null, "Visuals/UnlockParticles exists")
	_assert_check(gate.has_method("show_missing_resource_feedback"), "Implements show_missing_resource_feedback()")
	
	# Check unlock behavior
	gate.open_gate(false)
	_assert_check(gate._is_unlocked == true, "Gate is marked unlocked")
	_assert_check(left_beacon != null and left_beacon.material_override != null, "Status beacon material is assigned on unlock")
	
	gate.queue_free()
	await process_frame

## -----------------------------------------------------------------------------
## 6. Mobile Low-Poly Performance & Material Verification
## -----------------------------------------------------------------------------
func _test_mobile_performance_materials() -> void:
	print("\n--- Module 6: Mobile Low-Poly Performance & Shader Verification ---")
	# Verify project gl_compatibility renderer
	var rendering_method = ProjectSettings.get_setting("rendering/renderer/rendering_method")
	_assert_check(rendering_method == "gl_compatibility", "Rendering method is gl_compatibility (actual: %s)" % rendering_method)
	
	var mobile_rendering = ProjectSettings.get_setting("rendering/renderer/rendering_method.mobile")
	_assert_check(mobile_rendering == "gl_compatibility", "Mobile rendering method is gl_compatibility")

	# Triangle Budget Verification (< 22,000 triangles)
	var scenes_to_check = {
		"res://scenes/avatar_3d.tscn": 1,
		"res://scenes/npc_3d.tscn": 3,
		"res://scenes/worker_avatar_3d.tscn": 5,
		"res://scenes/collectible_3d.tscn": 6,
		"res://scenes/zone_gate_3d.tscn": 3,
	}
	var campus_tris: int = 0
	for scene_path in scenes_to_check.keys():
		var scn = load(scene_path)
		_assert_check(scn != null, "Scene %s loads for triangle audit" % scene_path)
		if scn != null:
			var inst = scn.instantiate()
			var scene_tris = _count_scene_triangles(inst)
			var mult: int = scenes_to_check[scene_path]
			campus_tris += scene_tris * mult
			print("  [INFO] %s: %d triangles x %d = %d" % [scene_path.get_file(), scene_tris, mult, scene_tris * mult])
			inst.free()
			
	var office_scene = load("res://scenes/office_props.tscn")
	if office_scene != null:
		var inst_office = office_scene.instantiate()
		var office_tris = _count_scene_triangles(inst_office)
		campus_tris += office_tris * 4
		inst_office.free()

	print("  [INFO] Total campus dynamic triangles: %d (Budget: < 22,000)" % campus_tris)
	_assert_check(campus_tris < 22000, "Campus triangle count (%d) is strictly within low-poly budget (<22,000)" % campus_tris)

func _count_scene_triangles(node: Node) -> int:
	var total_tris: int = 0
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		var m = (node as MeshInstance3D).mesh
		var faces = m.get_faces()
		if faces.size() > 0:
			total_tris += faces.size() / 3
		elif m is BoxMesh:
			total_tris += 12
		elif m is PlaneMesh:
			total_tris += 2
		elif m is SphereMesh:
			var sm = m as SphereMesh
			total_tris += sm.radial_segments * sm.rings * 2
		elif m is CapsuleMesh:
			var cm = m as CapsuleMesh
			total_tris += cm.radial_segments * (cm.rings + 1) * 2
		elif m is CylinderMesh:
			var cym = m as CylinderMesh
			total_tris += (cym.radial_segments * cym.rings * 2) + (cym.radial_segments * 2)
		elif m is TorusMesh:
			var tm = m as TorusMesh
			total_tris += tm.rings * tm.ring_segments * 2
		else:
			total_tris += 24
	for child in node.get_children():
		total_tris += _count_scene_triangles(child)
	return total_tris
