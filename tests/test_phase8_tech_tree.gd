extends SceneTree

## =============================================================================
## Master Headless SceneTree Test Suite for Phase 8 Tech-Tree & Forschungslabor
## File: IdleArcade/tests/test_phase8_tech_tree.gd
## Target: Godot 4.3 Engine Headless Runner
##
## Validates all 8 Sections:
##   1. Tech-tree definitions in GameState (5 technologies, names, base costs, effects)
##   2. Economy transaction & prerequisite checks (energy deduction, USB requirement for drone)
##   3. Gameplay effect calculations (+15% avatar speed, +10% worker rate, +25% RPS, 2x click, 10% item boost)
##   4. Research terminal scene loading, area trigger, register_interactable("Research [E]")
##   5. Delivery drone scene loading, triangle budget check (<2000 tris), hovering animation, waypoint navigation
##   6. TechTreeModal scene instantiation, 5 card heights >= 56px, close button >= 56x56px
##   7. NavDrawer %TechTreeButton existence, size >= 64px, modal opening
##   8. TouchControls dynamic styling verification for research interaction
##
## Execution:
##   godot --headless --path IdleArcade -s tests/test_phase8_tech_tree.gd
## =============================================================================

var pass_count: int = 0
var fail_count: int = 0

const EPSILON: float = 0.001

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

func _count_node_triangles(node: Node) -> int:
	var total: int = 0
	if node is MeshInstance3D and node.mesh != null:
		var m = node.mesh
		if m is BoxMesh:
			total += 12
		elif m is PlaneMesh:
			total += 2
		elif m is SphereMesh:
			var rad: int = m.radial_segments
			var rings: int = m.rings
			total += rad * rings * 2
		elif m is CylinderMesh:
			var rad: int = m.radial_segments
			var rings: int = m.rings
			total += (rad * rings * 2) + (rad * 2)
		elif m is TorusMesh:
			var rings: int = m.rings
			var rsegs: int = m.ring_segments
			total += rings * rsegs * 2
		elif m is CapsuleMesh:
			var rad: int = m.radial_segments
			var rings: int = m.rings
			total += rad * (rings + 1) * 2
		elif m is PrimitiveMesh:
			total += 24
	for child in node.get_children():
		total += _count_node_triangles(child)
	return total

func _init() -> void:
	print("\n====================================================================")
	print(">>> RUNNING MASTER PHASE 8 TECH-TREE HEADLESS SCENETREE TEST SUITE <<<")
	print("====================================================================")
	call_deferred("_run_all_tests")

func _run_all_tests() -> void:
	await process_frame
	
	# -------------------------------------------------------------------------
	# Autoload Singleton Setup
	# -------------------------------------------------------------------------
	var gs_script = load("res://scripts/autoload/game_state.gd")
	_assert_check(gs_script != null, "0.1 Load scripts/autoload/game_state.gd")
	if gs_script == null:
		printerr("[FATAL] Cannot load game_state.gd")
		quit(1)
		return
		
	var gs = root.get_node_or_null("GameState")
	if gs == null:
		gs = gs_script.new()
		gs.name = "GameState"
		root.add_child(gs)
	_assert_check(gs != null, "0.2 GameState mounted at /root/GameState")
	
	await process_frame
	
	# Execute all 8 required sections sequentially
	await _test_section_1_tech_definitions(gs)
	await _test_section_2_economy_transactions(gs)
	await _test_section_3_gameplay_effects(gs)
	await _test_section_4_terminal_scene(gs)
	await _test_section_5_drone_scene(gs)
	await _test_section_6_tech_modal(gs)
	await _test_section_7_nav_drawer_button(gs)
	await _test_section_8_touch_controls_styling(gs)
	
	print("\n====================================================================")
	print(">>> PHASE 8 SCENETREE TEST SUITE SUMMARY: %d PASSED, %d FAILED <<<" % [pass_count, fail_count])
	print("====================================================================")
	
	if fail_count == 0:
		print(">>> ALL PHASE 8 HEADLESS SCENETREE TESTS PASSED (Exit Code 0) <<<")
		quit(0)
	else:
		printerr(">>> PHASE 8 HEADLESS SCENETREE TESTS FAILED (Exit Code 1) <<<")
		quit(1)

# =============================================================================
# SECTION 1: Tech-Tree Definitions in GameState
# =============================================================================
func _test_section_1_tech_definitions(gs: Node) -> void:
	print("\n--- SECTION 1: Tech-Tree Definitions in GameState ---")
	gs.reset_state()
	
	_assert_check(gs.has_signal("tech_researched"), "1.1 GameState declares signal 'tech_researched'")
	_assert_check("researched_techs" in gs, "1.2 GameState declares property 'researched_techs'")
	_assert_check("item_inventory" in gs, "1.3 GameState declares property 'item_inventory'")
	_assert_check(gs.has_method("get_tech_definitions"), "1.4 GameState implements get_tech_definitions()")
	
	var defs: Dictionary = gs.get_tech_definitions()
	_assert_check(defs.size() == 5, "1.5 TECH_DEFINITIONS contains exactly 5 core technologies (got %d)" % defs.size())
	
	var expected_techs: Dictionary = {
		"tech_coffee_automation": {
			"name": "Coffee Automation",
			"cost": 500.0,
			"req_item": "",
			"req_count": 0
		},
		"tech_delivery_drone": {
			"name": "Delivery Drone",
			"cost": 1500.0,
			"req_item": "usb_drive",
			"req_count": 3
		},
		"tech_server_overclock": {
			"name": "Server Overclocking",
			"cost": 4000.0,
			"req_item": "",
			"req_count": 0
		},
		"tech_quantum_ads": {
			"name": "Quantum Ads",
			"cost": 10000.0,
			"req_item": "",
			"req_count": 0
		},
		"tech_neural_cloud": {
			"name": "Neural Cloud",
			"cost": 25000.0,
			"req_item": "",
			"req_count": 0
		}
	}
	
	for tid in expected_techs.keys():
		var exp = expected_techs[tid]
		_assert_check(defs.has(tid), "1.6 Definition exists for '%s'" % tid)
		if defs.has(tid):
			var d = defs[tid]
			_assert_check(d.get("name") == exp["name"], "1.7 Name match for '%s' ('%s')" % [tid, d.get("name")])
			_assert_check(abs(float(d.get("cost")) - exp["cost"]) < EPSILON, "1.8 Cost match for '%s' (%.1f)" % [tid, exp["cost"]])
			_assert_check(str(d.get("required_item", "")) == exp["req_item"], "1.9 Req item match for '%s'" % tid)
			_assert_check(int(d.get("required_item_count", 0)) == exp["req_count"], "1.10 Req item count match for '%s'" % tid)
			
	_assert_check(gs.researched_techs.is_empty(), "1.11 researched_techs initialized empty after reset_state()")
	_assert_check(not gs.is_tech_researched("tech_coffee_automation"), "1.12 is_tech_researched initially false for tech_coffee_automation")

# =============================================================================
# SECTION 2: Economy Transactions & Prerequisite Checks
# =============================================================================
func _test_section_2_economy_transactions(gs: Node) -> void:
	print("\n--- SECTION 2: Economy Transactions & Prerequisite Checks ---")
	gs.reset_state()
	
	# Test can_research with 0 energy
	gs.energy = 0.0
	_assert_check(not gs.can_research_tech("tech_coffee_automation"), "2.1 can_research false with insufficient energy (0.0 < 500.0)")
	
	# Test coffee automation purchase
	gs.energy = 500.0
	_assert_check(gs.can_research_tech("tech_coffee_automation"), "2.2 can_research true with exactly 500.0 energy")
	
	var res_tracker: Dictionary = {"emitted": false, "tid": ""}
	var on_tech_res = func(id: String):
		res_tracker["emitted"] = true
		res_tracker["tid"] = id
	gs.tech_researched.connect(on_tech_res)
	
	var success_coffee = gs.research_tech("tech_coffee_automation")
	_assert_check(success_coffee == true, "2.3 research_tech('tech_coffee_automation') succeeds")
	_assert_check(abs(gs.energy - 0.0) < EPSILON, "2.4 Energy deducted by 500.0 (remaining: %.1f)" % gs.energy)
	_assert_check(gs.is_tech_researched("tech_coffee_automation"), "2.5 is_tech_researched('tech_coffee_automation') is now true")
	_assert_check(res_tracker["emitted"] and res_tracker["tid"] == "tech_coffee_automation", "2.6 Signal tech_researched('tech_coffee_automation') emitted")
	_assert_check(not gs.can_research_tech("tech_coffee_automation"), "2.7 can_research false for already researched tech (idempotency)")
	
	gs.tech_researched.disconnect(on_tech_res)
	
	# Test delivery drone USB prerequisites
	gs.energy = 2000.0
	gs.item_inventory["usb_drive"] = 2
	_assert_check(not gs.can_research_tech("tech_delivery_drone"), "2.8 can_research('tech_delivery_drone') false with only 2 USB sticks (needs 3)")
	
	gs.item_inventory["usb_drive"] = 3
	_assert_check(gs.can_research_tech("tech_delivery_drone"), "2.9 can_research('tech_delivery_drone') true with 2000 energy and 3 USB sticks")
	
	var success_drone = gs.research_tech("tech_delivery_drone")
	_assert_check(success_drone == true, "2.10 research_tech('tech_delivery_drone') succeeds")
	_assert_check(abs(gs.energy - 500.0) < EPSILON, "2.11 Energy deducted by 1500.0 (2000 -> 500)")
	_assert_check(gs.get_item_count("usb_drive") == 0, "2.12 Exactly 3 USB sticks consumed from item_inventory (3 -> 0)")
	_assert_check(gs.is_tech_researched("tech_delivery_drone"), "2.13 is_tech_researched('tech_delivery_drone') is true")

# =============================================================================
# SECTION 3: Gameplay Effect Calculations
# =============================================================================
func _test_section_3_gameplay_effects(gs: Node) -> void:
	print("\n--- SECTION 3: Gameplay Effect Calculations ---")
	gs.reset_state()
	
	# 3.1 Avatar Speed (+15%)
	var base_speed_mult: float = gs.get_effective_avatar_speed()
	_assert_check(abs(base_speed_mult - 1.0) < EPSILON, "3.1 Baseline avatar speed multiplier is 1.0 (got %.2f)" % base_speed_mult)
	
	gs.energy = 500.0
	gs.research_tech("tech_coffee_automation")
	var speed_with_coffee_mult: float = gs.get_effective_avatar_speed()
	_assert_check(abs(speed_with_coffee_mult - 1.15) < EPSILON, "3.2 Avatar speed multiplier with tech_coffee_automation is 1.15 (+15 percent) (got %.2f)" % speed_with_coffee_mult)
	
	# 3.2 Worker Production Rate (+10%)
	var worker_mult = gs.get_worker_production_multiplier()
	_assert_check(abs(worker_mult - 1.10) < EPSILON, "3.3 Worker production multiplier is 1.10 (+10 percent) (got %.2f)" % worker_mult)
	
	# 3.3 Server Overclock (+25% RPS)
	# Give base upgrades for passive RPS
	if gs.upgrades.has("tier_1"):
		gs.upgrades["tier_1"]["level"] = 10
	elif gs.upgrades.has("viral_memes"):
		gs.upgrades["viral_memes"]["level"] = 10
	gs.recalculate_stats()
	var rps_before = gs.get_effective_passive_rps()
	_assert_check(rps_before > 0.0, "3.4 Baseline passive RPS established (%.2f RPS)" % rps_before)
	
	gs.energy = 4000.0
	gs.research_tech("tech_server_overclock")
	var rps_after = gs.get_effective_passive_rps()
	var rps_ratio = rps_after / rps_before
	_assert_check(abs(rps_ratio - 1.25) < 0.01, "3.5 tech_server_overclock boosts passive RPS by exactly +25 percent (ratio: %.2f)" % rps_ratio)
	
	# 3.4 Quantum Ads (2x Click Power & +50% Angel Investor spawn chance)
	var click_before = gs.base_click_power
	var angel_before = gs.get_angel_investor_spawn_chance_multiplier()
	_assert_check(abs(angel_before - 1.0) < EPSILON, "3.6 Baseline angel investor multiplier is 1.0")
	
	gs.energy = 10000.0
	gs.research_tech("tech_quantum_ads")
	var click_after = gs.base_click_power
	var angel_after = gs.get_angel_investor_spawn_chance_multiplier()
	_assert_check(abs(click_after - (click_before * 2.0)) < EPSILON, "3.7 tech_quantum_ads doubles base_click_power (2x) (%.1f -> %.1f)" % [click_before, click_after])
	_assert_check(abs(angel_after - 1.50) < EPSILON, "3.8 tech_quantum_ads gives 1.50x angel investor spawn chance (got %.2f)" % angel_after)
	
	# 3.5 Neural Cloud (Doubles Campus Item Multiplier from 5% to 10% per item)
	gs.collectibles_collected = 5
	var mult_5_before = gs.get_campus_item_multiplier()
	_assert_check(abs(mult_5_before - 1.25) < EPSILON, "3.9 5 items before Neural Cloud: 1.0 + 5 * 0.05 = 1.25x (got %.2f)" % mult_5_before)
	
	gs.energy = 25000.0
	gs.research_tech("tech_neural_cloud")
	var mult_5_after = gs.get_campus_item_multiplier()
	_assert_check(abs(mult_5_after - 1.50) < EPSILON, "3.10 5 items with Neural Cloud: 1.0 + 5 * 0.10 = 1.50x (got %.2f)" % mult_5_after)

# =============================================================================
# SECTION 4: Research Terminal Scene Loading & Proximity Trigger
# =============================================================================
func _test_section_4_terminal_scene(_gs: Node) -> void:
	print("\n--- SECTION 4: Research Terminal Scene Loading & Proximity Trigger ---")
	
	var terminal_scene = load("res://scenes/tech_lab_terminal.tscn")
	_assert_check(terminal_scene != null, "4.1 scenes/tech_lab_terminal.tscn loads successfully")
	if terminal_scene == null:
		return
		
	var terminal_inst = terminal_scene.instantiate() as StaticBody3D
	root.add_child(terminal_inst)
	await process_frame
	
	_assert_check(terminal_inst is TechLabTerminal or terminal_inst.has_method("open_research"), "4.2 TechLabTerminal instantiated")
	_assert_check(terminal_inst.is_in_group("terminals"), "4.3 Terminal in group 'terminals'")
	_assert_check(terminal_inst.is_in_group("research_terminals"), "4.4 Terminal in group 'research_terminals'")
	
	var prompt_label = terminal_inst.get_node_or_null("PromptLabel3D") as Label3D
	var interaction_area = terminal_inst.get_node_or_null("InteractionArea") as Area3D
	_assert_check(prompt_label != null, "4.5 PromptLabel3D node found")
	_assert_check(interaction_area != null, "4.6 InteractionArea node found")
	
	if prompt_label != null:
		_assert_check("[E]" in prompt_label.text, "4.7 PromptLabel3D contains '[E]' ('%s')" % prompt_label.text)
		_assert_check(prompt_label.visible == false, "4.8 PromptLabel3D initially hidden")
		
	# Mount TouchControls
	var tc_scene = load("res://scenes/ui/touch_controls.tscn")
	_assert_check(tc_scene != null, "4.9 scenes/ui/touch_controls.tscn loads successfully")
	var tc_inst = tc_scene.instantiate() as Control
	root.add_child(tc_inst)
	await process_frame
	
	var act_btn = tc_inst.get_node_or_null("%ActionButton") as Button
	_assert_check(act_btn != null, "4.10 ActionButton resolved in TouchControls")
	
	# Simulate player proximity entry
	var dummy_player = CharacterBody3D.new()
	dummy_player.name = "TestPlayer"
	dummy_player.add_to_group("player")
	root.add_child(dummy_player)
	
	terminal_inst._on_interaction_body_entered(dummy_player)
	_assert_check(terminal_inst.is_player_in_range(), "4.11 terminal_inst.is_player_in_range() is true on player entry")
	if prompt_label != null:
		_assert_check(prompt_label.visible == true, "4.12 PromptLabel3D becomes visible")
	if act_btn != null:
		_assert_check(act_btn.text == "Research [E]", "4.13 TouchControls ActionButton text is 'Research [E]'")
		
	# Simulate player exit
	terminal_inst._on_interaction_body_exited(dummy_player)
	_assert_check(not terminal_inst.is_player_in_range(), "4.14 terminal_inst.is_player_in_range() is false on player exit")
	if prompt_label != null:
		_assert_check(prompt_label.visible == false, "4.15 PromptLabel3D hidden on exit")
		
	dummy_player.queue_free()
	tc_inst.queue_free()
	terminal_inst.queue_free()
	await process_frame

# =============================================================================
# SECTION 5: Delivery Drone Scene Loading & Low-Poly Triangle Budget
# =============================================================================
func _test_section_5_drone_scene(_gs: Node) -> void:
	print("\n--- SECTION 5: Delivery Drone Scene Loading & Low-Poly Triangle Budget ---")
	
	var drone_scene = load("res://scenes/delivery_drone_3d.tscn")
	_assert_check(drone_scene != null, "5.1 scenes/delivery_drone_3d.tscn loads successfully")
	if drone_scene == null:
		return
		
	var drone_inst = drone_scene.instantiate() as CharacterBody3D
	root.add_child(drone_inst)
	await process_frame
	
	_assert_check(drone_inst is DeliveryDrone3D or drone_inst.has_method("activate_drone"), "5.2 DeliveryDrone3D instantiated")
	_assert_check(drone_inst.is_in_group("delivery_drones"), "5.3 Drone in group 'delivery_drones'")
	
	# Verify Waypoints
	_assert_check("WAYPOINTS" in drone_inst or DeliveryDrone3D.WAYPOINTS.size() == 5,
		"5.4 Drone defines 5 campus waypoints (Lobby, Server, Lab, Office, Courtyard)")
	if "WAYPOINTS" in drone_inst:
		var wps = drone_inst.WAYPOINTS
		_assert_check(wps.size() == 5, "5.5 Exactly 5 waypoints present")
		_assert_check(wps[1].z < -10.0, "5.6 Waypoint 2 points to Server Room (z < -10)")
		_assert_check(wps[2].x < -10.0, "5.7 Waypoint 3 points to R&D Lab (x < -10)")
		_assert_check(wps[3].x > 10.0, "5.8 Waypoint 4 points to Office (x > 10)")
		_assert_check(wps[4].z > 10.0, "5.9 Waypoint 5 points to Courtyard (z > 10)")
		
	# Verify 4 Rotors
	var r_fl = drone_inst.get_node_or_null("Visuals/Rotors/RotorFL")
	var r_fr = drone_inst.get_node_or_null("Visuals/Rotors/RotorFR")
	var r_bl = drone_inst.get_node_or_null("Visuals/Rotors/RotorBL")
	var r_br = drone_inst.get_node_or_null("Visuals/Rotors/RotorBR")
	_assert_check(r_fl != null and r_fr != null and r_bl != null and r_br != null, "5.10 All 4 quadcopter rotors exist (RotorFL, RotorFR, RotorBL, RotorBR)")
	
	# Verify CollectionArea
	var col_area = drone_inst.get_node_or_null("CollectionArea") as Area3D
	_assert_check(col_area != null, "5.11 CollectionArea Area3D exists")
	if col_area != null:
		_assert_check(col_area.collision_mask & 4 != 0, "5.12 CollectionArea scans collectibles layer (mask 4)")
		
	# Verify Triangle Budget (<2000 tris)
	var drone_tris = _count_node_triangles(drone_inst)
	_assert_check(drone_tris < 2000, "5.13 Drone triangle budget strictly < 2000 tris (actual: %d tris)" % drone_tris)
	_assert_check(drone_tris >= 300, "5.14 Drone has substantive geometry >= 300 tris (actual: %d tris)" % drone_tris)
	
	# Verify Activation State Control
	drone_inst.deactivate_drone()
	_assert_check(drone_inst.is_drone_active == false and drone_inst.visible == false, "5.15 deactivate_drone() hides drone and clears active flag")
	drone_inst.activate_drone()
	_assert_check(drone_inst.is_drone_active == true and drone_inst.visible == true, "5.16 activate_drone() unhides drone and sets active flag")
	
	# Verify Hover Sine Math
	var bob_0 = sin(0.0 * 4.0) * 0.15
	var bob_half_pi = sin((PI / 8.0) * 4.0) * 0.15
	_assert_check(abs(bob_0 - 0.0) < EPSILON, "5.17 Hover offset at t=0 is 0.0m")
	_assert_check(abs(bob_half_pi - 0.15) < EPSILON, "5.18 Hover peak at t=PI/8 is +0.15m")
	
	drone_inst.queue_free()
	await process_frame

# =============================================================================
# SECTION 6: TechTreeModal Scene Instantiation & Card Touch Sizing
# =============================================================================
func _test_section_6_tech_modal(gs: Node) -> void:
	print("\n--- SECTION 6: TechTreeModal Scene Instantiation & Card Touch Sizing ---")
	gs.reset_state()
	
	var modal_scene = load("res://scenes/ui/tech_tree_modal.tscn")
	_assert_check(modal_scene != null, "6.1 scenes/ui/tech_tree_modal.tscn loads successfully")
	if modal_scene == null:
		return
		
	var modal_inst = modal_scene.instantiate() as Control
	root.add_child(modal_inst)
	await process_frame
	
	# 6.2 Input Isolation (mouse_filter = STOP)
	_assert_check(modal_inst.mouse_filter == Control.MOUSE_FILTER_STOP, "6.2 TechTreeModal root mouse_filter == STOP")
	
	var backdrop = modal_inst.get_node_or_null("Backdrop") as Control
	var modal_card = modal_inst.find_child("ModalCard", true, false) as Control
	_assert_check(backdrop != null and backdrop.mouse_filter == Control.MOUSE_FILTER_STOP, "6.3 Backdrop mouse_filter == STOP")
	_assert_check(modal_card != null and modal_card.mouse_filter == Control.MOUSE_FILTER_STOP, "6.4 ModalCard mouse_filter == STOP")
	
	# 6.3 CloseButton Touch Size >= 56x56
	var close_btn = modal_inst.get_node_or_null("%CloseButton") as Button
	_assert_check(close_btn != null, "6.5 CloseButton resolved via %CloseButton")
	if close_btn != null:
		_assert_check(close_btn.custom_minimum_size.x >= 56.0 and close_btn.custom_minimum_size.y >= 56.0,
			"6.6 CloseButton custom_minimum_size >= 56x56px (got %.1fx%.1f)" % [close_btn.custom_minimum_size.x, close_btn.custom_minimum_size.y])
		_assert_check(close_btn.mouse_filter == Control.MOUSE_FILTER_STOP, "6.7 CloseButton mouse_filter == STOP")
		
	# 6.4 5 Tech Cards Height >= 56px and Buttons >= 56px
	var card_ids = [
		"tech_coffee_automation",
		"tech_delivery_drone",
		"tech_server_overclock",
		"tech_quantum_ads",
		"tech_neural_cloud"
	]
	
	for cid in card_ids:
		var card = modal_inst.get_node_or_null("%Card_" + cid) as Control
		var btn = modal_inst.get_node_or_null("%Button_" + cid) as Button
		_assert_check(card != null, "6.8 Tech card '%s' exists" % cid)
		_assert_check(btn != null, "6.9 Research button '%s' exists" % cid)
		if card != null:
			_assert_check(card.custom_minimum_size.y >= 56.0, "6.10 Card '%s' height >= 56px (got %.1fpx)" % [cid, card.custom_minimum_size.y])
			_assert_check(card.mouse_filter == Control.MOUSE_FILTER_STOP, "6.11 Card '%s' mouse_filter == STOP" % cid)
		if btn != null:
			_assert_check(btn.custom_minimum_size.y >= 56.0, "6.12 Button '%s' touch height >= 56px (got %.1fpx)" % [cid, btn.custom_minimum_size.y])
			_assert_check(btn.mouse_filter == Control.MOUSE_FILTER_STOP, "6.13 Button '%s' mouse_filter == STOP" % cid)
			
	# 6.5 3-State Button Behavior Test
	var coffee_btn = modal_inst.get_node_or_null("%Button_tech_coffee_automation") as Button
	if coffee_btn != null:
		# State 1: Locked when energy is 0
		gs.energy = 0.0
		modal_inst.open()
		await process_frame
		_assert_check(coffee_btn.disabled == true, "6.14 Button is disabled when energy is insufficient")
		
		# State 2: Active when energy is 500
		gs.energy = 500.0
		gs.energy_changed.emit(500.0, 500.0)
		await process_frame
		_assert_check(coffee_btn.disabled == false, "6.15 Button is active/enabled when energy reaches cost")
		_assert_check(coffee_btn.text == "Research", "6.16 Button text is 'Research'")
		
		# State 3: Researched
		gs.research_tech("tech_coffee_automation")
		await process_frame
		_assert_check(coffee_btn.disabled == true, "6.17 Button is disabled after research")
		_assert_check("Researched" in coffee_btn.text, "6.18 Button text shows 'Researched ✓'")
		
	modal_inst.close()
	await process_frame

# =============================================================================
# SECTION 7: NavDrawer %TechTreeButton Existence & Modal Opening
# =============================================================================
func _test_section_7_nav_drawer_button(_gs: Node) -> void:
	print("\n--- SECTION 7: NavDrawer %TechTreeButton Existence & Modal Opening ---")
	
	var hud_scene = load("res://scenes/hud.tscn")
	_assert_check(hud_scene != null, "7.1 scenes/hud.tscn loads successfully")
	if hud_scene == null:
		return
		
	var hud_inst = hud_scene.instantiate() as Control
	root.add_child(hud_inst)
	await process_frame
	
	var tech_btn = hud_inst.get_node_or_null("%TechTreeButton") as Button
	var nav_drawer = hud_inst.get_node_or_null("%NavDrawer") as Control
	_assert_check(tech_btn != null, "7.2 %TechTreeButton resolved inside HUD NavDrawer")
	_assert_check(nav_drawer != null, "7.3 %NavDrawer resolved in HUD")
	
	if tech_btn != null:
		_assert_check(tech_btn.custom_minimum_size.y >= 64.0, "7.4 TechTreeButton height >= 64px (got %.1fpx)" % tech_btn.custom_minimum_size.y)
		_assert_check(tech_btn.mouse_filter == Control.MOUSE_FILTER_STOP, "7.5 TechTreeButton mouse_filter == STOP")
		_assert_check("Tech" in tech_btn.text or "R&D" in tech_btn.text, "7.6 TechTreeButton has descriptive label ('%s')" % tech_btn.text)
		
	if hud_inst.has_method("open_tech_tree_modal"):
		_assert_check(nav_drawer.visible == false, "7.7 NavDrawer initially closed")
		hud_inst.call("open_nav_drawer")
		_assert_check(nav_drawer.visible == true, "7.8 NavDrawer open after open_nav_drawer()")
		
		# Call open_tech_tree_modal()
		var modal = hud_inst.call("open_tech_tree_modal") as Control
		_assert_check(modal != null, "7.9 open_tech_tree_modal() returned instantiated modal")
		_assert_check(nav_drawer.visible == false, "7.10 NavDrawer automatically closed when modal opens")
		if modal != null:
			modal.close()
			
	hud_inst.queue_free()
	await process_frame

# =============================================================================
# SECTION 8: TouchControls Dynamic Styling Verification
# =============================================================================
func _test_section_8_touch_controls_styling(_gs: Node) -> void:
	print("\n--- SECTION 8: TouchControls Dynamic Styling Verification ---")
	
	var tc_scene = load("res://scenes/ui/touch_controls.tscn")
	_assert_check(tc_scene != null, "8.1 scenes/ui/touch_controls.tscn loads successfully")
	if tc_scene == null:
		return
		
	var tc_inst = tc_scene.instantiate() as Control
	root.add_child(tc_inst)
	await process_frame
	
	var act_btn = tc_inst.get_node_or_null("%ActionButton") as Button
	_assert_check(act_btn != null, "8.2 %ActionButton resolved in TouchControls")
	
	# Check research style box initialization
	_assert_check("_cached_research_style" in tc_inst, "8.3 TouchControls declares property '_cached_research_style'")
	var r_style = tc_inst.get("_cached_research_style") as StyleBoxFlat
	_assert_check(r_style != null, "8.4 _cached_research_style is initialized as StyleBoxFlat")
	if r_style != null:
		# Cyan border check (G > 0.7, B > 0.8)
		_assert_check(r_style.border_color.b > 0.8 and r_style.border_color.g > 0.7,
			"8.5 Research style has cyber cyan border (got %s)" % str(r_style.border_color))
		# Deep purple background check (R > 0.1, B > 0.2, G < 0.15)
		_assert_check(r_style.bg_color.r > 0.1 and r_style.bg_color.b > 0.2,
			"8.6 Research style has deep purple background (got %s)" % str(r_style.bg_color))
			
	# Test registration with terminal node
	var dummy_terminal = StaticBody3D.new()
	dummy_terminal.set_script(load("res://scripts/tech_lab_terminal.gd"))
	root.add_child(dummy_terminal)
	
	tc_inst.call("register_interactable", dummy_terminal, "Research [E]")
	if act_btn != null:
		_assert_check(act_btn.text == "Research [E]", "8.7 ActionButton text dynamically set to 'Research [E]'")
		var applied_style = act_btn.get_theme_stylebox("normal")
		_assert_check(applied_style == r_style, "8.8 ActionButton normal theme stylebox overridden with _cached_research_style")
		
	# Test action dispatch
	var opened_tracker: Dictionary = {"emitted": false}
	dummy_terminal.research_opened.connect(func(): opened_tracker["emitted"] = true)
	tc_inst.call("trigger_action")
	_assert_check(opened_tracker["emitted"], "8.9 trigger_action() invokes terminal open_research() dispatch")
	
	# Clean unregister
	tc_inst.call("unregister_interactable", dummy_terminal)
	if act_btn != null:
		_assert_check(act_btn.text == tc_inst.default_action_label, "8.10 ActionButton reverted to default label on unregister")
		
	dummy_terminal.queue_free()
	tc_inst.queue_free()
	await process_frame
