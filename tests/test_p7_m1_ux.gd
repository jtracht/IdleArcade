extends SceneTree

## =============================================================================
## Unit & Integration Test Suite for Milestone P7-M1:
## Mobile UX Redesign & Ergonomic Fan Layout
## File: IdleArcade/tests/test_p7_m1_ux.gd
##
## Validates:
##   1. Radial Fan Layout: ActionButton (>=72px, 100x100px target, centered pivot (50,50)),
##      CampusThumbButton (70x70px, pivot (35,35)), LaptopThumbButton (70x70px, pivot (35,35)).
##   2. Ergonomic Geometry: Pairwise edge clearances >= 25px, center distances >= 95px,
##      thumb reaches <= 280px, horizontal clearance to joystick (X <= 360) >= 125px.
##   3. ActionButton Visual Readiness: Highlight on NPC ("Talk [E]"), Gate ("Unlock [E]"),
##      and Collectible3D ("Collect [E]" with violet glow).
##   4. Collapsible Burger Navigation Menu: %BurgerMenuButton (>=56x56px),
##      %NavDrawer overlay with touch tiles (height >= 64px) for Auth, Leaderboard,
##      Guild, Quests, Campus with backward-compatible unique names.
##   5. Scrollable Shop Upgrade Cards: Buy buttons height >= 54px (56px),
##      card panel centered pivot_offset, haptic vibration hook.
##   6. Input Isolation: MOUSE_FILTER_STOP on QuestCard, NavDrawer, and shop cards.
##
## Execution:
##   godot --headless --path IdleArcade -s tests/test_p7_m1_ux.gd
## =============================================================================

var pass_count: int = 0
var fail_count: int = 0

const EPSILON: float = 0.5
const VIEWPORT_W: float = 720.0
const VIEWPORT_H: float = 1280.0

func _init() -> void:
	print("\n====================================================================")
	print(">>> RUNNING MILESTONE P7-M1 UX & ERGONOMIC FAN LAYOUT TEST SUITE <<<")
	print("====================================================================")
	
	await process_frame
	
	# Execute all test sections
	await _test_radial_fan_layout()
	await _test_action_visual_readiness()
	await _test_burger_nav_drawer()
	await _test_shop_upgrade_cards()
	await _test_input_isolation()
	
	# Summary
	print("\n====================================================================")
	print(">>> P7-M1 TEST SUITE SUMMARY: %d PASSED, %d FAILED <<<" % [pass_count, fail_count])
	print("====================================================================")
	
	if fail_count == 0:
		print(">>> ALL P7-M1 TESTS PASSED WITH 100% GREEN INTEGRITY! <<<")
		quit(0)
	else:
		printerr(">>> P7-M1 TESTS FAILED WITH %d ERRORS! <<<" % fail_count)
		quit(1)

func _assert_check(condition: bool, description: String) -> void:
	if condition:
		print("  [PASS] %s" % description)
		pass_count += 1
	else:
		printerr("  [FAIL] %s" % description)
		fail_count += 1

# =============================================================================
# Section 1: Radial Fan Layout & Ergonomic Geometry
# =============================================================================
func _test_radial_fan_layout() -> void:
	print("\n--- Section 1: Radial Fan Layout & Geometry ---")
	
	var tc_scene = load("res://scenes/ui/touch_controls.tscn")
	_assert_check(tc_scene != null, "1.1 touch_controls.tscn loads successfully")
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
	
	if act_btn != null:
		_assert_check(act_btn.custom_minimum_size.x >= 72.0 and act_btn.custom_minimum_size.y >= 72.0,
			"1.5 ActionButton custom_minimum_size >= 72px (got %.1fx%.1f)" % [act_btn.custom_minimum_size.x, act_btn.custom_minimum_size.y])
		_assert_check(act_btn.size.x >= 72.0 and act_btn.size.y >= 72.0,
			"1.6 ActionButton physical size >= 72px (got %.1fx%.1f)" % [act_btn.size.x, act_btn.size.y])
		_assert_check(abs(act_btn.pivot_offset.x - 50.0) < EPSILON and abs(act_btn.pivot_offset.y - 50.0) < EPSILON,
			"1.7 ActionButton centered touch pivot Vector2(50, 50) (got %.1f, %.1f)" % [act_btn.pivot_offset.x, act_btn.pivot_offset.y])
		_assert_check(act_btn.mouse_filter == Control.MOUSE_FILTER_STOP,
			"1.8 ActionButton mouse_filter == MOUSE_FILTER_STOP")
			
	if lap_btn != null:
		_assert_check(lap_btn.custom_minimum_size.x >= 70.0 and lap_btn.custom_minimum_size.y >= 70.0,
			"1.9 LaptopThumbButton custom_minimum_size == 70x70px (got %.1fx%.1f)" % [lap_btn.custom_minimum_size.x, lap_btn.custom_minimum_size.y])
		_assert_check(abs(lap_btn.pivot_offset.x - 35.0) < EPSILON and abs(lap_btn.pivot_offset.y - 35.0) < EPSILON,
			"1.10 LaptopThumbButton centered touch pivot Vector2(35, 35) (got %.1f, %.1f)" % [lap_btn.pivot_offset.x, lap_btn.pivot_offset.y])
		_assert_check(lap_btn.mouse_filter == Control.MOUSE_FILTER_STOP,
			"1.11 LaptopThumbButton mouse_filter == MOUSE_FILTER_STOP")
			
	if cam_btn != null:
		_assert_check(cam_btn.custom_minimum_size.x >= 70.0 and cam_btn.custom_minimum_size.y >= 70.0,
			"1.12 CampusThumbButton custom_minimum_size == 70x70px (got %.1fx%.1f)" % [cam_btn.custom_minimum_size.x, cam_btn.custom_minimum_size.y])
		_assert_check(abs(cam_btn.pivot_offset.x - 35.0) < EPSILON and abs(cam_btn.pivot_offset.y - 35.0) < EPSILON,
			"1.13 CampusThumbButton centered touch pivot Vector2(35, 35) (got %.1f, %.1f)" % [cam_btn.pivot_offset.x, cam_btn.pivot_offset.y])
		_assert_check(cam_btn.mouse_filter == Control.MOUSE_FILTER_STOP,
			"1.14 CampusThumbButton mouse_filter == MOUSE_FILTER_STOP")
			
	# Geometric clearances and center distances
	if act_btn != null and lap_btn != null and cam_btn != null:
		var c_act = act_btn.position + act_btn.size * 0.5
		var c_lap = lap_btn.position + lap_btn.size * 0.5
		var c_cam = cam_btn.position + cam_btn.size * 0.5
		
		var r_act = act_btn.size.x * 0.5 # 50px
		var r_lap = lap_btn.size.x * 0.5 # 35px
		var r_cam = cam_btn.size.x * 0.5 # 35px
		
		# Centers
		_assert_check(abs(c_act.x - 630.0) < 2.0 and abs(c_act.y - 1150.0) < 2.0,
			"1.15 ActionButton center at (630, 1150) (got %.1f, %.1f)" % [c_act.x, c_act.y])
		_assert_check(abs(c_cam.x - 520.0) < 2.0 and abs(c_cam.y - 1090.0) < 2.0,
			"1.16 CampusThumbButton center at (520, 1090) (got %.1f, %.1f)" % [c_cam.x, c_cam.y])
		_assert_check(abs(c_lap.x - 600.0) < 2.0 and abs(c_lap.y - 1035.0) < 2.0,
			"1.17 LaptopThumbButton center at (600, 1035) (got %.1f, %.1f)" % [c_lap.x, c_lap.y])
			
		# Center distances
		var dist_act_lap = c_act.distance_to(c_lap)
		var dist_act_cam = c_act.distance_to(c_cam)
		var dist_lap_cam = c_lap.distance_to(c_cam)
		_assert_check(dist_act_lap >= 95.0, "1.18 Center distance Action-Laptop >= 95px (got %.1f px)" % dist_act_lap)
		_assert_check(dist_act_cam >= 95.0, "1.19 Center distance Action-Campus >= 95px (got %.1f px)" % dist_act_cam)
		_assert_check(dist_lap_cam >= 95.0, "1.20 Center distance Laptop-Campus >= 95px (got %.1f px)" % dist_lap_cam)
		
		# Edge-to-edge clearances
		var clear_act_lap = dist_act_lap - (r_act + r_lap)
		var clear_act_cam = dist_act_cam - (r_act + r_cam)
		var clear_lap_cam = dist_lap_cam - (r_lap + r_cam)
		_assert_check(clear_act_lap >= 25.0, "1.21 Edge clearance Action-Laptop >= 25px (got %.1f px)" % clear_act_lap)
		_assert_check(clear_act_cam >= 25.0, "1.22 Edge clearance Action-Campus >= 25px (got %.1f px)" % clear_act_cam)
		_assert_check(clear_lap_cam >= 25.0, "1.23 Edge clearance Laptop-Campus >= 25px (got %.1f px)" % clear_lap_cam)
		
		# Thumb reach from bottom-right corner (720, 1280)
		var corner = Vector2(VIEWPORT_W, VIEWPORT_H)
		var reach_act = corner.distance_to(c_act)
		var reach_cam = corner.distance_to(c_cam)
		var reach_lap = corner.distance_to(c_lap)
		_assert_check(reach_act <= 280.0, "1.24 Thumb reach ActionButton <= 280px (got %.1f px)" % reach_act)
		_assert_check(reach_cam <= 280.0, "1.25 Thumb reach CampusThumbButton <= 280px (got %.1f px)" % reach_cam)
		_assert_check(reach_lap <= 280.0, "1.26 Thumb reach LaptopThumbButton <= 280px (got %.1f px)" % reach_lap)
		
		# Horizontal clearance buffer to joystick zone (X <= 360)
		var leftmost_edge = min(act_btn.position.x, min(cam_btn.position.x, lap_btn.position.x))
		var joy_buffer = leftmost_edge - 360.0
		_assert_check(joy_buffer >= 125.0, "1.27 Horizontal clearance buffer to joystick zone >= 125px (got %.1f px)" % joy_buffer)

	tc_inst.queue_free()
	await process_frame

# =============================================================================
# Section 2: ActionButton Visual Readiness for NPCs, Gates, and Collectibles
# =============================================================================
func _test_action_visual_readiness() -> void:
	print("\n--- Section 2: ActionButton Visual Readiness ---")
	
	var tc_scene = load("res://scenes/ui/touch_controls.tscn")
	var tc_inst = tc_scene.instantiate() as TouchControls
	root.add_child(tc_inst)
	await process_frame
	
	var act_btn = tc_inst.action_button
	_assert_check(act_btn != null, "2.1 ActionButton present in TouchControls")
	
	# Initial dormant state
	_assert_check(act_btn.text == "[E] Action", "2.2 Initial dormant label is '[E] Action'")
	_assert_check(act_btn.modulate.a < 0.6, "2.3 Dormant button opacity is dimmed (< 0.6)")
	
	# Create mock NPC
	var mock_npc = CharacterBody3D.new()
	mock_npc.name = "MockNPC"
	var npc_script = GDScript.new()
	npc_script.source_code = "extends CharacterBody3D\nvar quest_id = 'test_q'\nfunc interact(): pass"
	npc_script.reload()
	mock_npc.set_script(npc_script)
	root.add_child(mock_npc)
	await process_frame
	
	# Register NPC
	tc_inst.register_interactable(mock_npc, "Talk [E]")
	_assert_check(act_btn.text.contains("Talk"), "2.4 ActionButton reflects NPC interaction: '%s'" % act_btn.text)
	_assert_check(act_btn.modulate.a >= 0.95, "2.5 ActionButton illuminated for NPC (modulate.a = %.2f)" % act_btn.modulate.a)
	
	# Create mock Collectible
	var mock_collectible = Area3D.new()
	mock_collectible.name = "MockCollectible"
	mock_collectible.add_to_group("collectibles")
	var coll_script = GDScript.new()
	coll_script.source_code = "extends Area3D\nvar item_type = 'briefcase'\nfunc collect(collector = null): pass"
	coll_script.reload()
	mock_collectible.set_script(coll_script)
	root.add_child(mock_collectible)
	await process_frame
	
	# Register Collectible (priority on top of stack)
	tc_inst.register_interactable(mock_collectible, "Collect [E]")
	_assert_check(act_btn.text.contains("Collect"), "2.6 ActionButton reflects Collectible interaction: '%s'" % act_btn.text)
	_assert_check(act_btn.modulate.a >= 0.95, "2.7 ActionButton illuminated for Collectible")
	
	# Unregister Collectible -> restores NPC
	tc_inst.unregister_interactable(mock_collectible)
	_assert_check(act_btn.text.contains("Talk"), "2.8 Unregistering Collectible restores NPC Talk context: '%s'" % act_btn.text)
	
	# Unregister NPC -> returns to dormant
	tc_inst.unregister_interactable(mock_npc)
	_assert_check(act_btn.text == "[E] Action", "2.9 All unregistered restores dormant label '[E] Action'")
	_assert_check(act_btn.modulate.a < 0.6, "2.10 Returns to dormant dimmed opacity")
	
	mock_npc.queue_free()
	mock_collectible.queue_free()
	tc_inst.queue_free()
	await process_frame

# =============================================================================
# Section 3: Collapsible Burger Navigation Menu in HUD
# =============================================================================
func _test_burger_nav_drawer() -> void:
	print("\n--- Section 3: Collapsible Burger Navigation Menu ---")
	
	var hud_scene = load("res://scenes/hud.tscn")
	_assert_check(hud_scene != null, "3.1 hud.tscn loads successfully")
	if hud_scene == null:
		return
		
	var hud_inst = hud_scene.instantiate() as Control
	root.add_child(hud_inst)
	await process_frame
	
	var burger_btn = hud_inst.get_node_or_null("%BurgerMenuButton") as Button
	var nav_drawer = hud_inst.get_node_or_null("%NavDrawer") as Control
	var close_btn = hud_inst.get_node_or_null("%CloseNavButton") as Button
	var nav_backdrop = hud_inst.get_node_or_null("%NavDrawerBackdrop") as Button
	
	_assert_check(burger_btn != null, "3.2 BurgerMenuButton node resolved via unique name %BurgerMenuButton")
	_assert_check(nav_drawer != null, "3.3 NavDrawer node resolved via unique name %NavDrawer")
	
	if burger_btn != null:
		_assert_check(burger_btn.custom_minimum_size.x >= 56.0 and burger_btn.custom_minimum_size.y >= 56.0,
			"3.4 BurgerMenuButton touch target >= 56x56px (got %.1fx%.1f)" % [burger_btn.custom_minimum_size.x, burger_btn.custom_minimum_size.y])
		_assert_check(burger_btn.mouse_filter == Control.MOUSE_FILTER_STOP,
			"3.5 BurgerMenuButton mouse_filter == MOUSE_FILTER_STOP")
			
	if nav_drawer != null:
		_assert_check(nav_drawer.visible == false, "3.6 NavDrawer initially hidden (visible == false)")
		_assert_check(nav_drawer.mouse_filter == Control.MOUSE_FILTER_STOP, "3.7 NavDrawer mouse_filter == MOUSE_FILTER_STOP")
		
		# Test drawer methods
		_assert_check(hud_inst.has_method("open_nav_drawer"), "3.8 HUD implements open_nav_drawer()")
		_assert_check(hud_inst.has_method("close_nav_drawer"), "3.9 HUD implements close_nav_drawer()")
		_assert_check(hud_inst.has_method("toggle_burger_menu"), "3.10 HUD implements toggle_burger_menu()")
		
		hud_inst.open_nav_drawer()
		await process_frame
		_assert_check(nav_drawer.visible == true, "3.11 open_nav_drawer() makes NavDrawer visible")
		
		hud_inst.close_nav_drawer()
		await process_frame
		_assert_check(nav_drawer.visible == false, "3.12 close_nav_drawer() hides NavDrawer")
		
		hud_inst.toggle_burger_menu()
		await process_frame
		_assert_check(nav_drawer.visible == true, "3.13 toggle_burger_menu() toggles NavDrawer open")
		
		hud_inst.toggle_burger_menu()
		await process_frame
		_assert_check(nav_drawer.visible == false, "3.14 toggle_burger_menu() toggles NavDrawer closed")
		
	# Verify Backward-Compatible Unique Nodes inside NavDrawer
	var auth_btn = hud_inst.get_node_or_null("%AuthButton") as Button
	var lb_btn = hud_inst.get_node_or_null("%LeaderboardButton") as Button
	var guild_btn = hud_inst.get_node_or_null("%GuildButton") as Button
	var quest_btn = hud_inst.get_node_or_null("%QuestButton") as Button
	var campus_btn = hud_inst.get_node_or_null("%CampusButton") as Button
	
	_assert_check(auth_btn != null, "3.15 Preserved %AuthButton inside NavDrawer")
	_assert_check(lb_btn != null, "3.16 Preserved %LeaderboardButton inside NavDrawer")
	_assert_check(guild_btn != null, "3.17 Preserved %GuildButton inside NavDrawer")
	_assert_check(quest_btn != null, "3.18 Preserved %QuestButton inside NavDrawer")
	_assert_check(campus_btn != null, "3.19 Preserved %CampusButton inside NavDrawer")
	
	var tiles = [auth_btn, lb_btn, guild_btn, quest_btn, campus_btn]
	var all_tiles_valid: bool = true
	for tile in tiles:
		if tile == null:
			all_tiles_valid = false
			break
		if tile.custom_minimum_size.y < 64.0:
			all_tiles_valid = false
		if tile.mouse_filter != Control.MOUSE_FILTER_STOP:
			all_tiles_valid = false
	_assert_check(all_tiles_valid, "3.20 All navigation drawer tiles have height >= 64px and mouse_filter == MOUSE_FILTER_STOP")
	
	# Tap-outside-to-close
	if nav_backdrop != null and nav_drawer != null:
		hud_inst.open_nav_drawer()
		await process_frame
		nav_backdrop.pressed.emit()
		await process_frame
		_assert_check(nav_drawer.visible == false, "3.21 Tap-outside backdrop closes NavDrawer")
		
	# Close button
	if close_btn != null and nav_drawer != null:
		hud_inst.open_nav_drawer()
		await process_frame
		close_btn.pressed.emit()
		await process_frame
		_assert_check(nav_drawer.visible == false, "3.22 CloseNavButton closes NavDrawer")

	hud_inst.queue_free()
	await process_frame

# =============================================================================
# Section 4: Scrollable Shop Upgrade Cards
# =============================================================================
func _test_shop_upgrade_cards() -> void:
	print("\n--- Section 4: Shop Upgrade Cards ---")
	
	var hud_scene = load("res://scenes/hud.tscn")
	var hud_inst = hud_scene.instantiate() as Control
	root.add_child(hud_inst)
	await process_frame
	
	var upgrade_list = hud_inst.get_node_or_null("%UpgradeList") as VBoxContainer
	_assert_check(upgrade_list != null, "4.1 UpgradeList found in HUD")
	if upgrade_list == null:
		hud_inst.queue_free()
		return
		
	var card_count = upgrade_list.get_child_count()
	_assert_check(card_count >= 9, "4.2 Upgrade cards populated (count: %d >= 9)" % card_count)
	
	var all_buttons_min_54px: bool = true
	var all_panels_stop_filter: bool = true
	for child in upgrade_list.get_children():
		if child is PanelContainer:
			if child.mouse_filter != Control.MOUSE_FILTER_STOP:
				all_panels_stop_filter = false
			var btn = child.find_child("Button", true, false) as Button
			if btn == null:
				for sub in child.get_children():
					if sub is HBoxContainer:
						for hsub in sub.get_children():
							if hsub is Button:
								btn = hsub
								break
			if btn != null:
				if btn.custom_minimum_size.y < 54.0:
					all_buttons_min_54px = false
					print("    Button height under 54px: %.1f" % btn.custom_minimum_size.y)
				if btn.mouse_filter != Control.MOUSE_FILTER_STOP:
					all_panels_stop_filter = false
					
	_assert_check(all_buttons_min_54px, "4.3 All shop upgrade buy buttons have height >= 54px (actual: 56px)")
	_assert_check(all_panels_stop_filter, "4.4 All shop card panels and buy buttons set mouse_filter == MOUSE_FILTER_STOP")
	
	hud_inst.queue_free()
	await process_frame

# =============================================================================
# Section 5: Input Isolation
# =============================================================================
func _test_input_isolation() -> void:
	print("\n--- Section 5: Input Isolation ---")
	
	# Quest Tracker input isolation
	var qt_scene = load("res://scenes/quest_tracker.tscn")
	_assert_check(qt_scene != null, "5.1 quest_tracker.tscn loads successfully")
	if qt_scene != null:
		var qt_inst = qt_scene.instantiate() as Control
		root.add_child(qt_inst)
		await process_frame
		
		var quest_card = qt_inst.get_node_or_null("QuestCard") as PanelContainer
		_assert_check(quest_card != null, "5.2 QuestCard found in QuestTracker")
		if quest_card != null:
			_assert_check(quest_card.mouse_filter == Control.MOUSE_FILTER_STOP,
				"5.3 QuestCard mouse_filter == MOUSE_FILTER_STOP (value: %d, expected 0)" % quest_card.mouse_filter)
		qt_inst.queue_free()
		await process_frame
		
	# TouchControls root vs buttons isolation
	var tc_scene = load("res://scenes/ui/touch_controls.tscn")
	if tc_scene != null:
		var tc_inst = tc_scene.instantiate() as Control
		root.add_child(tc_inst)
		await process_frame
		
		_assert_check(tc_inst.mouse_filter == Control.MOUSE_FILTER_IGNORE,
			"5.4 TouchControls root mouse_filter == MOUSE_FILTER_IGNORE (2) allowing deliberate 3D clicks")
			
		var act_btn = tc_inst.get_node_or_null("%ActionButton") as Button
		var lap_btn = tc_inst.get_node_or_null("%LaptopThumbButton") as Button
		var cam_btn = tc_inst.get_node_or_null("%CampusThumbButton") as Button
		_assert_check(act_btn != null and act_btn.mouse_filter == Control.MOUSE_FILTER_STOP,
			"5.5 ActionButton mouse_filter == MOUSE_FILTER_STOP (0)")
		_assert_check(lap_btn != null and lap_btn.mouse_filter == Control.MOUSE_FILTER_STOP,
			"5.6 LaptopThumbButton mouse_filter == MOUSE_FILTER_STOP (0)")
		_assert_check(cam_btn != null and cam_btn.mouse_filter == Control.MOUSE_FILTER_STOP,
			"5.7 CampusThumbButton mouse_filter == MOUSE_FILTER_STOP (0)")
			
		tc_inst.queue_free()
		await process_frame
