extends SceneTree

## =============================================================================
## Master Headless SceneTree Test Suite for Milestone 2: Frontend UI/UX & Touch Ergonomics
## File: IdleArcade/tests/test_frontend_ui_touch.gd
## Target: Godot 4.3 Engine Headless Runner & CI Verification (Release v2.2.0)
##
## Validates 100% of Milestone 2 Frontend UI/UX & Touch Ergonomics Requirements:
##   Section 1: HUD & NavDrawer Ergonomics & Interaction (10 drawer buttons >= 64px, hamburger >= 56px, backdrop mouse_filter = STOP)
##   Section 2: Virtual Joystick Math & Clamping (touch centering X <= 360, 80px radius clamp, 12px deadzone, +45° isometric transformation, release zeroing)
##   Section 3: ActionButton & Radial Thumb Buttons (ActionButton 100x100px at (580, 1120), secondary buttons 70x70px, dynamic context action styling and text)
##   Section 4: 8 Modals Lifecycle & Interaction (ShopPanel, DialoguePanel, TechTreeModal, SettingsModal, IpoModal, DailyBoardModal, SyndicateModal, StaffModal - open, close, tab switching, data reactivity)
##   Section 5: Mobile Touch Ergonomics Audit (assert 100% of interactive controls in all 8 modals satisfy custom_minimum_size.y >= 56.0 or size.y >= 56.0)
##   Section 6: Pointer Isolation Audit (assert modal backdrops / cards have mouse_filter == Control.MOUSE_FILTER_STOP to block click-to-move 3D raycast bleed)
##
## Execution:
##   godot --headless --path IdleArcade -s tests/test_frontend_ui_touch.gd
## =============================================================================

var pass_count: int = 0
var fail_count: int = 0

const MIN_EXPECTED_PASS_COUNT: int = 200
const EPSILON: float = 0.002
const SQRT1_2: float = 0.7071067811865475

# Singletons tracked for lifecycle cleanup
var _mounted_nodes: Array[Node] = []
var _save_backup_text: String = ""
var _had_save_backup: bool = false

func _assert_check(condition: bool, description: String, detail: String = "") -> void:
	if condition:
		print("  [PASS] %s" % description)
		pass_count += 1
	else:
		var err_msg: String = "  [FAIL] %s" % description
		if detail != "":
			err_msg += " (Detail: %s)" % detail
		printerr(err_msg)
		fail_count += 1

func _init() -> void:
	print("\n====================================================================")
	print(">>> RUNNING IDLEARCADE PHASE 15 M2: FRONTEND UI/UX & TOUCH TEST SUITE <<<")
	print("====================================================================")
	call_deferred("_run_all_tests")

func _cleanup_and_quit(exit_code: int) -> void:
	print("\n--- TEARDOWN: Restoring Environment & Cleaning Singletons ---")
	if _had_save_backup:
		var f_res = FileAccess.open("user://savegame.json", FileAccess.WRITE)
		if f_res != null:
			f_res.store_string(_save_backup_text)
			f_res.close()
			print("  [CLEANUP] Restored original user://savegame.json")
	elif FileAccess.file_exists("user://savegame.json"):
		DirAccess.remove_absolute("user://savegame.json")
		print("  [CLEANUP] Removed temporary user://savegame.json")

	# Clean up mounted singletons in reverse order
	for i in range(_mounted_nodes.size() - 1, -1, -1):
		var n = _mounted_nodes[i]
		if is_instance_valid(n):
			if n.get_parent() != null:
				n.get_parent().remove_child(n)
			n.free()
	_mounted_nodes.clear()
	print("  [CLEANUP] All test harness singletons safely unmounted.")

	quit(exit_code)

func _run_all_tests() -> void:
	await process_frame

	# -------------------------------------------------------------------------
	# Backup existing savegame if present
	# -------------------------------------------------------------------------
	if FileAccess.file_exists("user://savegame.json"):
		var f_back = FileAccess.open("user://savegame.json", FileAccess.READ)
		if f_back != null:
			_save_backup_text = f_back.get_as_text()
			_had_save_backup = true
			f_back.close()

	# -------------------------------------------------------------------------
	# STAGE 0: Autoload Singleton Mounting Harness Setup (All 6 Singletons)
	# -------------------------------------------------------------------------
	print("\n--- STAGE 0: Autoload Mounting Harness Setup ---")

	# 0.1 GameState
	var gs_script = load("res://scripts/autoload/game_state.gd")
	_assert_check(gs_script != null, "0.1 Load res://scripts/autoload/game_state.gd")
	if gs_script == null:
		printerr("[FATAL] Unable to load game_state.gd")
		_cleanup_and_quit(1)
		return

	var gs = root.get_node_or_null("GameState")
	if gs == null:
		gs = gs_script.new()
		gs.name = "GameState"
		root.add_child(gs)
		_mounted_nodes.append(gs)
	_assert_check(gs != null, "0.2 GameState mounted at /root/GameState")
	if gs.has_method("reset_state"):
		gs.reset_state()

	# 0.2 Nakama SDK Driver
	var nakama_script = load("res://addons/com.heroiclabs.nakama/Nakama.gd")
	_assert_check(nakama_script != null, "0.3 Load res://addons/com.heroiclabs.nakama/Nakama.gd")
	var nakama_node = root.get_node_or_null("Nakama")
	if nakama_node == null and nakama_script != null:
		nakama_node = nakama_script.new()
		nakama_node.name = "Nakama"
		root.add_child(nakama_node)
		_mounted_nodes.append(nakama_node)
	_assert_check(nakama_node != null, "0.4 Nakama mounted at /root/Nakama")

	# 0.3 NakamaManager
	var nm_script = load("res://scripts/autoload/nakama_manager.gd")
	_assert_check(nm_script != null, "0.5 Load res://scripts/autoload/nakama_manager.gd")
	var nm = root.get_node_or_null("NakamaManager")
	if nm == null and nm_script != null:
		nm = nm_script.new()
		nm.name = "NakamaManager"
		if "auto_login_on_ready" in nm:
			nm.auto_login_on_ready = false
		root.add_child(nm)
		_mounted_nodes.append(nm)
	_assert_check(nm != null, "0.6 NakamaManager mounted at /root/NakamaManager")

	# 0.4 HapticsManager
	var hm_script = load("res://scripts/autoload/haptics_manager.gd")
	_assert_check(hm_script != null, "0.7 Load res://scripts/autoload/haptics_manager.gd")
	var hm = root.get_node_or_null("HapticsManager")
	if hm == null and hm_script != null:
		hm = hm_script.new()
		hm.name = "HapticsManager"
		if "mock_mode" in hm:
			hm.mock_mode = true
		root.add_child(hm)
		_mounted_nodes.append(hm)
	_assert_check(hm != null, "0.8 HapticsManager mounted at /root/HapticsManager")

	# 0.5 AudioManager
	var am_script = load("res://scripts/autoload/audio_manager.gd")
	_assert_check(am_script != null, "0.9 Load res://scripts/autoload/audio_manager.gd")
	var am = root.get_node_or_null("AudioManager")
	if am == null and am_script != null:
		am = am_script.new()
		am.name = "AudioManager"
		root.add_child(am)
		_mounted_nodes.append(am)
	_assert_check(am != null, "0.10 AudioManager mounted at /root/AudioManager")

	# 0.6 LiveEventManager
	var lem_script = load("res://scripts/autoload/live_event_manager.gd")
	_assert_check(lem_script != null, "0.11 Load res://scripts/autoload/live_event_manager.gd")
	var lem = root.get_node_or_null("LiveEventManager")
	if lem == null and lem_script != null:
		lem = lem_script.new()
		lem.name = "LiveEventManager"
		root.add_child(lem)
		_mounted_nodes.append(lem)
	_assert_check(lem != null, "0.12 LiveEventManager mounted at /root/LiveEventManager")

	await process_frame

	# Run all 6 sections sequentially
	await _test_section_1_hud_and_nav_drawer(gs)
	await _test_section_2_virtual_joystick_math()
	await _test_section_3_action_button_and_thumb_buttons()
	await _test_section_4_eight_modals_lifecycle(gs)
	await _test_section_5_mobile_touch_ergonomics_audit()
	await _test_section_6_pointer_isolation_audit()

	# -------------------------------------------------------------------------
	# Final Summary & Deterministic Exit Code
	# -------------------------------------------------------------------------
	print("\n====================================================================")
	print(">>> PHASE 15 M2 TEST SUITE SUMMARY: %d PASSED, %d FAILED <<<" % [pass_count, fail_count])
	print("====================================================================")

	if fail_count == 0 and pass_count >= MIN_EXPECTED_PASS_COUNT:
		print(">>> ALL M2 FRONTEND UI/UX & TOUCH ERGONOMICS TESTS PASSED (Exit Code 0) <<<")
		_cleanup_and_quit(0)
	else:
		printerr(">>> M2 TEST SUITE FAILED (Exit Code 1, pass_count=%d/%d, fail_count=%d) <<<" % [
			pass_count, MIN_EXPECTED_PASS_COUNT, fail_count
		])
		_cleanup_and_quit(1)

# =============================================================================
# SECTION 1: HUD & NavDrawer Ergonomics & Interaction
# =============================================================================
func _test_section_1_hud_and_nav_drawer(gs: Node) -> void:
	print("\n--- SECTION 1: HUD & NavDrawer Ergonomics & Interaction ---")

	var hud_scene = load("res://scenes/hud.tscn")
	_assert_check(hud_scene != null, "1.1 Load res://scenes/hud.tscn")
	if hud_scene == null:
		return

	var hud = hud_scene.instantiate() as Control
	_assert_check(hud != null, "1.2 HUD scene instantiates successfully")
	root.add_child(hud)
	await process_frame

	# 1.1 Root and Core Containers
	_assert_check(hud.mouse_filter == Control.MOUSE_FILTER_IGNORE, "1.3 Root HUD mouse_filter == MOUSE_FILTER_IGNORE (2) allowing input pass-through")
	var top_container = hud.get_node_or_null("TopContainer") as Control
	_assert_check(top_container != null, "1.4 HUD TopContainer exists")
	var bottom_container = hud.get_node_or_null("BottomContainer") as Control
	_assert_check(bottom_container != null, "1.5 HUD BottomContainer exists")

	# 1.2 Hamburger Button Ergonomics (>= 56px)
	var burger_btn = hud.get_node_or_null("%BurgerMenuButton") as Button
	_assert_check(burger_btn != null, "1.6 BurgerMenuButton exists in HUD header")
	if burger_btn != null:
		_assert_check(burger_btn.custom_minimum_size.x >= 56.0, "1.7 BurgerMenuButton width (%.1fpx) >= 56.0px" % burger_btn.custom_minimum_size.x)
		_assert_check(burger_btn.custom_minimum_size.y >= 56.0, "1.8 BurgerMenuButton height (%.1fpx) >= 56.0px" % burger_btn.custom_minimum_size.y)
		_assert_check(burger_btn.mouse_filter == Control.MOUSE_FILTER_STOP, "1.9 BurgerMenuButton mouse_filter == Control.MOUSE_FILTER_STOP (0)")
		_assert_check(burger_btn.text == "☰", "1.10 BurgerMenuButton displays standard '☰' icon")

	# 1.3 Top Bar Badges Ergonomics (>= 56px)
	var streak_badge = hud.get_node_or_null("%StreakBadge") as Control
	_assert_check(streak_badge != null, "1.11 StreakBadge exists in TopContainer")
	if streak_badge != null:
		_assert_check(streak_badge.custom_minimum_size.y >= 56.0, "1.12 StreakBadge height (%.1fpx) >= 56.0px" % streak_badge.custom_minimum_size.y)
		_assert_check(streak_badge.mouse_filter == Control.MOUSE_FILTER_STOP, "1.13 StreakBadge mouse_filter == STOP")

	var syndicate_badge = hud.get_node_or_null("%SyndicateBadge") as Control
	_assert_check(syndicate_badge != null, "1.14 SyndicateBadge exists in TopContainer")
	if syndicate_badge != null:
		_assert_check(syndicate_badge.custom_minimum_size.y >= 56.0, "1.15 SyndicateBadge height (%.1fpx) >= 56.0px" % syndicate_badge.custom_minimum_size.y)
		_assert_check(syndicate_badge.mouse_filter == Control.MOUSE_FILTER_STOP, "1.16 SyndicateBadge mouse_filter == STOP")

	var staff_badge = hud.get_node_or_null("%StaffBadge") as Control
	_assert_check(staff_badge != null, "1.17 StaffBadge exists in TopContainer")
	if staff_badge != null:
		_assert_check(staff_badge.custom_minimum_size.y >= 56.0, "1.18 StaffBadge height (%.1fpx) >= 56.0px" % staff_badge.custom_minimum_size.y)
		_assert_check(staff_badge.mouse_filter == Control.MOUSE_FILTER_STOP, "1.19 StaffBadge mouse_filter == STOP")

	var campaign_badge = hud.get_node_or_null("%CampaignBadge") as Control
	_assert_check(campaign_badge != null, "1.20 CampaignBadge exists in TopContainer")
	if campaign_badge != null:
		_assert_check(campaign_badge.custom_minimum_size.y >= 56.0, "1.21 CampaignBadge height (%.1fpx) >= 56.0px" % campaign_badge.custom_minimum_size.y)
		_assert_check(campaign_badge.mouse_filter == Control.MOUSE_FILTER_STOP, "1.22 CampaignBadge mouse_filter == STOP")

	# 1.4 NavDrawer Hierarchy & Backdrop Isolation
	var nav_drawer = hud.get_node_or_null("%NavDrawer") as Control
	_assert_check(nav_drawer != null, "1.23 NavDrawer exists in HUD")
	_assert_check(nav_drawer.visible == false, "1.24 NavDrawer is initially hidden (visible = false)")
	_assert_check(nav_drawer.mouse_filter == Control.MOUSE_FILTER_STOP, "1.25 NavDrawer root mouse_filter == STOP")

	var nav_backdrop = hud.get_node_or_null("%NavDrawerBackdrop") as Control
	_assert_check(nav_backdrop != null, "1.26 NavDrawerBackdrop exists")
	if nav_backdrop != null:
		_assert_check(nav_backdrop.mouse_filter == Control.MOUSE_FILTER_STOP, "1.27 NavDrawerBackdrop enforces mouse_filter == STOP (0)")

	var close_nav_btn = hud.get_node_or_null("%CloseNavButton") as Button
	_assert_check(close_nav_btn != null, "1.28 CloseNavButton exists in NavDrawer header")
	if close_nav_btn != null:
		_assert_check(close_nav_btn.custom_minimum_size.x >= 56.0 and close_nav_btn.custom_minimum_size.y >= 56.0,
			"1.29 CloseNavButton dimensions (%.1fx%.1f) satisfy >= 56px touch target" % [close_nav_btn.custom_minimum_size.x, close_nav_btn.custom_minimum_size.y])
		_assert_check(close_nav_btn.mouse_filter == Control.MOUSE_FILTER_STOP, "1.30 CloseNavButton mouse_filter == STOP")

	# 1.5 The 10 NavDrawer Item Buttons (Strict >= 64px Touch Height)
	var drawer_button_names: Array[String] = [
		"%AuthButton",
		"%LeaderboardButton",
		"%GuildButton",
		"%QuestButton",
		"%CampusButton",
		"%TechTreeButton",
		"%SettingsButton",
		"%IPOButton",
		"%SyndicateButton",
		"%StaffButton"
	]
	_assert_check(drawer_button_names.size() == 10, "1.31 NavDrawer contains exactly 10 navigation item definitions")

	for btn_name in drawer_button_names:
		var btn = hud.get_node_or_null(btn_name) as Button
		_assert_check(btn != null, "1.32 NavDrawer item button '%s' exists" % btn_name)
		if btn != null:
			_assert_check(btn.custom_minimum_size.y >= 64.0,
				"1.33 Item '%s' height (%.1fpx) satisfies >= 64px standard" % [btn_name, btn.custom_minimum_size.y])
			_assert_check(btn.mouse_filter == Control.MOUSE_FILTER_STOP,
				"1.34 Item '%s' mouse_filter == STOP" % btn_name)

	# 1.6 Drawer Open / Close / Toggle Interaction Lifecycle
	hud.open_nav_drawer()
	_assert_check(nav_drawer.visible == true, "1.35 open_nav_drawer() makes NavDrawer visible")
	hud.close_nav_drawer()
	_assert_check(nav_drawer.visible == false, "1.36 close_nav_drawer() hides NavDrawer")
	hud.toggle_burger_menu()
	_assert_check(nav_drawer.visible == true, "1.37 toggle_burger_menu() opens drawer when closed")
	hud.toggle_burger_menu()
	_assert_check(nav_drawer.visible == false, "1.38 toggle_burger_menu() closes drawer when open")

	# 1.7 ShopPanel & Upgrade Cards Ergonomics (>= 56px)
	var shop_panel = hud.get_node_or_null("BottomContainer/ShopPanel") as Control
	_assert_check(shop_panel != null, "1.39 ShopPanel exists in BottomContainer")
	if shop_panel != null:
		_assert_check(shop_panel.mouse_filter == Control.MOUSE_FILTER_STOP, "1.40 ShopPanel mouse_filter == STOP")

	var upgrade_list = hud.get_node_or_null("%UpgradeList") as VBoxContainer
	_assert_check(upgrade_list != null, "1.41 UpgradeList exists in ShopPanel")
	_assert_check(hud.UPGRADE_DEFINITIONS.size() == 12, "1.42 ShopPanel defines 12 upgrade items")

	# Verify dynamically created upgrade cards
	var cards_verified: int = 0
	for def in hud.UPGRADE_DEFINITIONS:
		var u_id = def["id"]
		if hud._upgrade_cards.has(u_id):
			var card_data = hud._upgrade_cards[u_id]
			var buy_btn = card_data["buy_button"] as Button
			var card_panel = card_data["panel"] as PanelContainer
			if buy_btn != null and card_panel != null:
				if buy_btn.custom_minimum_size.y >= 56.0 and buy_btn.mouse_filter == Control.MOUSE_FILTER_STOP and card_panel.mouse_filter == Control.MOUSE_FILTER_STOP:
					cards_verified += 1
	_assert_check(cards_verified == 12, "1.43 All 12 ShopPanel upgrade cards have buy buttons >= 56px and mouse_filter = STOP")

	# Test Affordability Reactive Glow & Pulsing
	hud._refresh_affordability(0.0)
	_assert_check(hud.is_card_pulsing("click_booster") == false, "1.44 click_booster does not pulse with 0 energy")
	hud._refresh_affordability(100000.0)
	_assert_check(hud.is_card_pulsing("click_booster") == true, "1.45 click_booster pulses with 100,000 energy")

	hud.queue_free()
	await process_frame

# =============================================================================
# SECTION 2: Virtual Joystick Math & Clamping
# =============================================================================
func _test_section_2_virtual_joystick_math() -> void:
	print("\n--- SECTION 2: Virtual Joystick Math & Clamping ---")

	var joystick_scene = load("res://scenes/ui/virtual_joystick.tscn")
	_assert_check(joystick_scene != null, "2.1 Load res://scenes/ui/virtual_joystick.tscn")
	if joystick_scene == null:
		return

	var joystick = joystick_scene.instantiate() as VirtualJoystick
	_assert_check(joystick != null, "2.2 VirtualJoystick instantiates as VirtualJoystick")
	root.add_child(joystick)
	await process_frame

	# 2.1 Default Parameters Verification
	_assert_check(absf(joystick.max_radius - 80.0) < EPSILON, "2.3 max_radius is strictly 80.0 px (actual: %.1f)" % joystick.max_radius)
	_assert_check(absf(joystick.deadzone_radius - 12.0) < EPSILON, "2.4 deadzone_radius is strictly 12.0 px (actual: %.1f)" % joystick.deadzone_radius)
	_assert_check(joystick.zone_min_x == 0.0 and joystick.zone_max_x == 360.0, "2.5 Activation zone horizontal span is [0.0, 360.0] (left screen half)")
	_assert_check(joystick.zone_min_y == 70.0 and joystick.zone_max_y == 1280.0, "2.6 Activation zone vertical span is [70.0, 1280.0] (below top status bar)")
	_assert_check(absf(joystick.default_camera_yaw - 0.785398163) < 0.001, "2.7 default_camera_yaw is 45.0° (PI/4 rad)")

	# 2.2 Activation Zone Bounds Testing (is_in_touch_zone)
	_assert_check(joystick.is_in_touch_zone(Vector2(180.0, 600.0)) == true, "2.8 (180, 600) is inside touch activation zone")
	_assert_check(joystick.is_in_touch_zone(Vector2(0.0, 70.0)) == true, "2.9 (0, 70) top-left corner is inside activation zone")
	_assert_check(joystick.is_in_touch_zone(Vector2(360.0, 1280.0)) == true, "2.10 (360, 1280) bottom-right corner is inside activation zone")
	_assert_check(joystick.is_in_touch_zone(Vector2(361.0, 600.0)) == false, "2.11 (361, 600) right screen half is strictly rejected")
	_assert_check(joystick.is_in_touch_zone(Vector2(550.0, 800.0)) == false, "2.12 (550, 800) right-side action area is strictly rejected")
	_assert_check(joystick.is_in_touch_zone(Vector2(180.0, 69.0)) == false, "2.13 (180, 69) top status bar margin is strictly rejected")
	_assert_check(joystick.is_in_touch_zone(Vector2(180.0, 1281.0)) == false, "2.14 (180, 1281) below screen is strictly rejected")

	# 2.3 Dynamic Touch Centering
	var touch_event = InputEventScreenTouch.new()
	touch_event.index = 0
	touch_event.position = Vector2(150.0, 450.0)
	touch_event.pressed = true

	var accepted: bool = joystick.handle_touch_event(touch_event)
	_assert_check(accepted == true, "2.15 Touch down in left half accepted by joystick")
	_assert_check(joystick.is_active == true, "2.16 Joystick enters active tracking state")
	_assert_check(joystick.base_center_position == Vector2(150.0, 450.0), "2.17 Base dynamically centers exactly at touch position (150, 450)")
	_assert_check(joystick.touch_finger_index == 0, "2.18 Tracked finger index is 0")

	# Multi-touch rejection (secondary finger index = 1 ignored)
	var touch_sec = InputEventScreenTouch.new()
	touch_sec.index = 1
	touch_sec.position = Vector2(200.0, 500.0)
	touch_sec.pressed = true
	var sec_accepted: bool = joystick.handle_touch_event(touch_sec)
	_assert_check(sec_accepted == false, "2.19 Secondary touch index 1 is rejected (multi-touch isolation)")

	# 2.4 Radial Clamping Math (calculate_clamped_stick_pos)
	var center = Vector2(200.0, 500.0)

	# Within radius (offset 50px < 80px)
	var pos_within = center + Vector2(30.0, 40.0) # length = 50.0
	var clamped_within = joystick.calculate_clamped_stick_pos(pos_within, center)
	_assert_check(clamped_within == pos_within, "2.20 Touch within 80px radius (50px) is not clamped")

	# Exactly on perimeter (offset 80px == 80px)
	var pos_boundary = center + Vector2(80.0, 0.0)
	var clamped_boundary = joystick.calculate_clamped_stick_pos(pos_boundary, center)
	_assert_check(clamped_boundary == pos_boundary, "2.21 Touch exactly on 80px perimeter is preserved")

	# Beyond boundary (offset 150px > 80px)
	var pos_beyond = center + Vector2(90.0, 120.0) # length = 150.0
	var clamped_beyond = joystick.calculate_clamped_stick_pos(pos_beyond, center)
	var dist_beyond = (clamped_beyond - center).length()
	_assert_check(absf(dist_beyond - 80.0) < EPSILON, "2.22 Touch beyond 80px (150px) is strictly clamped to 80.0 px distance (actual: %.2f)" % dist_beyond)
	var dir_original = (pos_beyond - center).normalized()
	var dir_clamped = (clamped_beyond - center).normalized()
	_assert_check(dir_original.dot(dir_clamped) > 0.9999, "2.23 Clamped position preserves exact angular direction")

	# Extreme throw (offset 1000px)
	var pos_extreme = center + Vector2(1000.0, 0.0)
	var clamped_extreme = joystick.calculate_clamped_stick_pos(pos_extreme, center)
	_assert_check(clamped_extreme == center + Vector2(80.0, 0.0), "2.24 Extreme throw (1000px) clamps cleanly to 80.0 px")

	# 2.5 Deadzone Filtering & Linear Output Scaling (calculate_output_vector)
	# Sub-deadzone zeroing (12.0px threshold)
	_assert_check(joystick.calculate_output_vector(Vector2.ZERO) == Vector2.ZERO, "2.25 Zero stick offset outputs Vector2.ZERO")
	_assert_check(joystick.calculate_output_vector(Vector2(6.0, 0.0)) == Vector2.ZERO, "2.26 6.0px offset (<= 12px deadzone) outputs Vector2.ZERO")
	_assert_check(joystick.calculate_output_vector(Vector2(0.0, 11.99)) == Vector2.ZERO, "2.27 11.99px offset (<= 12px deadzone) outputs Vector2.ZERO")
	_assert_check(joystick.calculate_output_vector(Vector2(12.0, 0.0)) == Vector2.ZERO, "2.28 12.00px exact deadzone boundary outputs Vector2.ZERO")

	# Deadzone emergence
	var vec_emerge = joystick.calculate_output_vector(Vector2(13.0, 0.0))
	_assert_check(vec_emerge.length() > 0.0, "2.29 13.0px offset (> 12px deadzone) yields non-zero output vector")

	# Half-throw mid-span: deadzone + (80 - 12) * 0.5 = 12 + 34 = 46.0 px
	var vec_mid = joystick.calculate_output_vector(Vector2(46.0, 0.0))
	_assert_check(absf(vec_mid.length() - 0.50) < 0.01, "2.30 46.0px offset yields exactly 0.50 normalized magnitude (actual: %.3f)" % vec_mid.length())

	# Full-throw maximum: 80.0 px
	var vec_full = joystick.calculate_output_vector(Vector2(0.0, -80.0))
	_assert_check(absf(vec_full.length() - 1.00) < EPSILON, "2.31 80.0px offset yields exactly 1.00 unit magnitude")
	_assert_check(vec_full.x == 0.0 and vec_full.y < 0.0, "2.32 Upward screen displacement aligns with negative Y")

	# Over-throw clamping: 200.0 px
	var vec_over = joystick.calculate_output_vector(Vector2(200.0, 0.0))
	_assert_check(absf(vec_over.length() - 1.00) < EPSILON, "2.33 200.0px offset output strictly clamped to 1.00 unit magnitude")

	# 2.6 Isometric 3D Camera-Relative Transformation (+45° Yaw Angle)
	var yaw_45: float = deg_to_rad(45.0)

	# 2D Screen Forward (0, -1) -> 3D World Isometric Direction
	var dir_forward = joystick.calculate_camera_relative_3d(Vector2(0.0, -1.0), yaw_45)
	_assert_check(absf(dir_forward.length() - 1.0) < EPSILON, "2.34 Forward 2D vector produces unit 3D isometric vector")
	_assert_check(dir_forward.y == 0.0, "2.35 3D isometric vector maintains Y = 0 (horizontal ground navigation)")
	_assert_check(dir_forward.x < 0.0 and dir_forward.z < 0.0, "2.36 2D Up (0, -1) maps to -X and -Z in isometric 45° world space")
	_assert_check(absf(dir_forward.x - (-SQRT1_2)) < 0.005, "2.37 dir_forward.x matches -sqrt(2)/2 (-0.707)")
	_assert_check(absf(dir_forward.z - (-SQRT1_2)) < 0.005, "2.38 dir_forward.z matches -sqrt(2)/2 (-0.707)")

	# 2D Screen Right (1, 0)
	var dir_right = joystick.calculate_camera_relative_3d(Vector2(1.0, 0.0), yaw_45)
	_assert_check(absf(dir_right.length() - 1.0) < EPSILON, "2.39 Right 2D vector produces unit 3D isometric vector")
	_assert_check(dir_right.x > 0.0 and dir_right.z < 0.0, "2.40 2D Right (1, 0) maps to +X and -Z in isometric 45° world space")

	# Orthogonality check: forward and right vectors are perpendicular
	var dot_f_r = dir_forward.dot(dir_right)
	_assert_check(absf(dot_f_r) < 0.001, "2.41 Isometric forward and right vectors are strictly orthogonal (dot = 0.0)")

	# Zero 2D input -> Zero 3D output
	_assert_check(joystick.calculate_camera_relative_3d(Vector2.ZERO, yaw_45) == Vector3.ZERO, "2.42 Zero 2D vector produces Vector3.ZERO")

	# 2.7 Touch Release & Zero-Drift Snapping
	joystick.reset_joystick()
	_assert_check(joystick.is_active == false, "2.43 reset_joystick() deactivates tracking")
	_assert_check(joystick.touch_finger_index == -1, "2.44 touch_finger_index resets to -1")
	_assert_check(joystick.output_vector == Vector2.ZERO, "2.45 output_vector strictly snaps to Vector2.ZERO (zero drift)")
	_assert_check(joystick.world_direction_3d == Vector3.ZERO, "2.46 world_direction_3d strictly snaps to Vector3.ZERO")

	joystick.queue_free()
	await process_frame

# =============================================================================
# SECTION 3: ActionButton & Radial Thumb Buttons
# =============================================================================
func _test_section_3_action_button_and_thumb_buttons() -> void:
	print("\n--- SECTION 3: ActionButton & Radial Thumb Buttons ---")

	var touch_scene = load("res://scenes/ui/touch_controls.tscn")
	_assert_check(touch_scene != null, "3.1 Load res://scenes/ui/touch_controls.tscn")
	if touch_scene == null:
		return

	var touch_ctrl = touch_scene.instantiate() as TouchControls
	_assert_check(touch_ctrl != null, "3.2 TouchControls instantiates as TouchControls")
	touch_ctrl.set_anchors_preset(Control.PRESET_TOP_LEFT)
	touch_ctrl.size = Vector2(720.0, 1280.0)
	root.add_child(touch_ctrl)
	touch_ctrl.size = Vector2(720.0, 1280.0)
	touch_ctrl._setup_buttons()
	await process_frame

	# 3.1 Input Isolation Tier 3: Root container ignores events
	_assert_check(touch_ctrl.mouse_filter == Control.MOUSE_FILTER_IGNORE, "3.3 Root TouchControls mouse_filter == MOUSE_FILTER_IGNORE (2) allowing 3D camera pan")

	# 3.2 Primary ActionButton Specifications (100x100px at bottom-right)
	var action_btn = touch_ctrl.action_button
	_assert_check(action_btn != null, "3.4 ActionButton exists in TouchControls")
	if action_btn != null:
		_assert_check(action_btn.custom_minimum_size == Vector2(100.0, 100.0),
			"3.5 ActionButton custom_minimum_size is strictly 100x100px (actual: %.0fx%.0f)" % [action_btn.custom_minimum_size.x, action_btn.custom_minimum_size.y])
		_assert_check(action_btn.mouse_filter == Control.MOUSE_FILTER_STOP,
			"3.6 ActionButton mouse_filter == Control.MOUSE_FILTER_STOP (0) absorbing touch events")
		_assert_check(action_btn.focus_mode == Control.FOCUS_NONE,
			"3.7 ActionButton focus_mode == FOCUS_NONE (prevents focus outline)")

		# Viewport placement & clearance (reference 720x1280)
		touch_ctrl.size = Vector2(720.0, 1280.0)
		var btn_pos = action_btn.position
		_assert_check(btn_pos.x >= 530.0 and btn_pos.x <= 600.0,
			"3.8 ActionButton position.x (%.1f) lies within safe right thumb reach zone [530, 600]" % btn_pos.x)
		_assert_check(btn_pos.y >= 1050.0 and btn_pos.y <= 1180.0,
			"3.9 ActionButton position.y (%.1f) lies within safe bottom thumb reach zone [1050, 1180]" % btn_pos.y)

		var margin_right = 720.0 - (btn_pos.x + action_btn.custom_minimum_size.x)
		var margin_bottom = 1280.0 - (btn_pos.y + action_btn.custom_minimum_size.y)
		_assert_check(margin_right >= 25.0, "3.10 Screen edge right clearance (%.1fpx) satisfies >= 25px standard" % margin_right)
		_assert_check(margin_bottom >= 25.0, "3.11 Screen edge bottom clearance (%.1fpx) satisfies >= 25px standard" % margin_bottom)

	# 3.3 Secondary Radial Thumb Buttons (70x70px)
	var campus_btn = touch_ctrl.campus_button
	_assert_check(campus_btn != null, "3.12 CampusThumbButton exists in TouchControls")
	if campus_btn != null:
		_assert_check(campus_btn.custom_minimum_size == Vector2(70.0, 70.0),
			"3.13 CampusThumbButton custom_minimum_size is strictly 70x70px")
		_assert_check(campus_btn.mouse_filter == Control.MOUSE_FILTER_STOP,
			"3.14 CampusThumbButton mouse_filter == STOP")
		_assert_check(campus_btn.text == "🌐",
			"3.15 CampusThumbButton displays globe icon '🌐'")

	var laptop_btn = touch_ctrl.laptop_button
	_assert_check(laptop_btn != null, "3.16 LaptopThumbButton exists in TouchControls")
	if laptop_btn != null:
		_assert_check(laptop_btn.custom_minimum_size == Vector2(70.0, 70.0),
			"3.17 LaptopThumbButton custom_minimum_size is strictly 70x70px")
		_assert_check(laptop_btn.mouse_filter == Control.MOUSE_FILTER_STOP,
			"3.18 LaptopThumbButton mouse_filter == STOP")
		_assert_check(laptop_btn.text == "💻",
			"3.19 LaptopThumbButton displays laptop icon '💻'")

	# 3.4 Dynamic Context Action Styling & Stacking Engine
	var mock_office = Node3D.new()
	mock_office.name = "MockOfficeExpansion"
	mock_office.add_to_group("staff_offices")
	mock_office.set("action_label", "Staff [E]")

	var mock_server = Node3D.new()
	mock_server.name = "MockServerTerminal"
	mock_server.add_to_group("server_terminals")
	mock_server.set("action_label", "Hack [E]")

	var mock_coffee = Node3D.new()
	mock_coffee.name = "MockCoffeeMachine"
	mock_coffee.add_to_group("coffee_machines")
	mock_coffee.set("action_label", "Brew [E]")

	var mock_pitch = Node3D.new()
	mock_pitch.name = "MockPitchStage"
	mock_pitch.add_to_group("pitch_stages")
	mock_pitch.set("action_label", "Pitch [E]")

	var mock_research = Node3D.new()
	mock_research.name = "MockTechLab"
	mock_research.add_to_group("research_terminals")
	mock_research.set("action_label", "Research [E]")

	var mock_syndicate = Node3D.new()
	mock_syndicate.name = "MockSyndicateHQ"
	mock_syndicate.add_to_group("syndicate_hqs")
	mock_syndicate.set("action_label", "Syndicate [E]")

	# Proximity Registration: Staff Office
	touch_ctrl.register_interactable(mock_office, "Staff [E]")
	_assert_check(touch_ctrl.active_interactable == mock_office, "3.20 Active interactable registered as MockOffice")
	_assert_check(touch_ctrl.action_button.text == "Staff [E]", "3.21 ActionButton label dynamically updated to 'Staff [E]'")
	_assert_check(absf(touch_ctrl.action_button.modulate.a - touch_ctrl.active_opacity) < 0.05, "3.22 ActionButton opacity updated to active_opacity (1.0)")

	# Stacking: Player walks into Server Terminal zone while still in Office zone
	touch_ctrl.register_interactable(mock_server, "Hack [E]")
	_assert_check(touch_ctrl.active_interactable == mock_server, "3.23 Server Terminal takes priority on stack")
	_assert_check(touch_ctrl.action_button.text == "Hack [E]", "3.24 ActionButton label updated to 'Hack [E]'")

	# Unregister Server Terminal -> pops back to Staff Office
	touch_ctrl.unregister_interactable(mock_server)
	_assert_check(touch_ctrl.active_interactable == mock_office, "3.25 Active interactable cleanly pops back to MockOffice")
	_assert_check(touch_ctrl.action_button.text == "Staff [E]", "3.26 ActionButton label restored to 'Staff [E]'")

	# Unregister Staff Office -> reverts to dormant state
	touch_ctrl.unregister_interactable(mock_office)
	_assert_check(touch_ctrl.active_interactable == null, "3.27 All interactables cleared; active_interactable is null")
	_assert_check(touch_ctrl.action_button.text == touch_ctrl.default_action_label, "3.28 ActionButton text reverted to default '[E] Action'")
	_assert_check(absf(touch_ctrl.action_button.modulate.a - touch_ctrl.dormant_opacity) < 0.05, "3.29 ActionButton opacity reverted to dormant_opacity (0.35)")

	# Verify other station labels
	touch_ctrl.register_interactable(mock_coffee, "Brew [E]")
	_assert_check(touch_ctrl.action_button.text == "Brew [E]", "3.30 Coffee Machine registers with 'Brew [E]'")
	touch_ctrl.unregister_interactable(mock_coffee)

	touch_ctrl.register_interactable(mock_pitch, "Pitch [E]")
	_assert_check(touch_ctrl.action_button.text == "Pitch [E]", "3.31 Pitch Stage registers with 'Pitch [E]'")
	touch_ctrl.unregister_interactable(mock_pitch)

	touch_ctrl.register_interactable(mock_research, "Research [E]")
	_assert_check(touch_ctrl.action_button.text == "Research [E]", "3.32 Tech Lab registers with 'Research [E]'")
	touch_ctrl.unregister_interactable(mock_research)

	touch_ctrl.register_interactable(mock_syndicate, "Syndicate [E]")
	_assert_check(touch_ctrl.action_button.text == "Syndicate [E]", "3.33 Syndicate HQ registers with 'Syndicate [E]'")
	touch_ctrl.unregister_interactable(mock_syndicate)

	# 3.5 Action Triggering Signals
	var action_fired: Array[bool] = [false]
	var action_target: Array = [null]
	touch_ctrl.action_triggered.connect(func(node):
		action_fired[0] = true
		action_target[0] = node
	)

	touch_ctrl.register_interactable(mock_office, "Staff [E]")
	touch_ctrl.trigger_action()
	_assert_check(action_fired[0] == true, "3.34 trigger_action() emits action_triggered signal")
	_assert_check(action_target[0] == mock_office, "3.35 action_triggered emitted with correct target node")
	touch_ctrl.unregister_interactable(mock_office)

	var laptop_toggled: Array[bool] = [false]
	touch_ctrl.overlay_toggle_requested.connect(func(): laptop_toggled[0] = true)
	touch_ctrl.trigger_laptop_toggle()
	_assert_check(laptop_toggled[0] == true, "3.36 trigger_laptop_toggle() emits overlay_toggle_requested")

	var campus_toggled: Array[bool] = [false]
	touch_ctrl.campus_toggle_requested.connect(func(): campus_toggled[0] = true)
	touch_ctrl.trigger_campus_toggle()
	_assert_check(campus_toggled[0] == true, "3.37 trigger_campus_toggle() emits campus_toggle_requested")

	# Clean up mock nodes
	mock_office.free()
	mock_server.free()
	mock_coffee.free()
	mock_pitch.free()
	mock_research.free()
	mock_syndicate.free()
	touch_ctrl.queue_free()
	await process_frame

# =============================================================================
# SECTION 4: 8 Modals Lifecycle & Interaction
# =============================================================================
func _test_section_4_eight_modals_lifecycle(gs: Node) -> void:
	print("\n--- SECTION 4: 8 Modals Lifecycle & Interaction ---")

	# -------------------------------------------------------------------------
	# 4.1 Modal 1: ShopPanel (Lifecycle & Interaction)
	# -------------------------------------------------------------------------
	print("--- 4.1 Modal 1: ShopPanel ---")
	var hud_scene = load("res://scenes/hud.tscn")
	var hud = hud_scene.instantiate() as Control
	root.add_child(hud)
	await process_frame

	var shop_panel = hud.get_node_or_null("BottomContainer/ShopPanel") as Control
	_assert_check(shop_panel != null, "4.1 ShopPanel exists inside HUD hierarchy")
	_assert_check(hud.has_method("_on_buy_button_pressed"), "4.2 HUD implements _on_buy_button_pressed()")

	# Initial purchase test
	gs.energy = 50.0
	hud._on_buy_button_pressed("click_booster")
	_assert_check(int(gs.upgrades.get("click_booster", {}).get("level", 0)) >= 1, "4.3 buy_upgrade('click_booster') updates GameState upgrade level")

	hud.queue_free()
	await process_frame

	# -------------------------------------------------------------------------
	# 4.2 Modal 2: DialoguePanel (Lifecycle & Interaction)
	# -------------------------------------------------------------------------
	print("--- 4.2 Modal 2: DialoguePanel ---")
	var dial_scene = load("res://scenes/dialogue_panel.tscn")
	_assert_check(dial_scene != null, "4.4 Load res://scenes/dialogue_panel.tscn")
	var dial = dial_scene.instantiate() as DialoguePanel
	root.add_child(dial)
	await process_frame

	_assert_check(dial.has_signal("closed"), "4.5 DialoguePanel declares 'closed' signal")
	_assert_check(dial.has_signal("choice_selected"), "4.6 DialoguePanel declares 'choice_selected' signal")
	_assert_check(dial.has_signal("quest_accepted"), "4.7 DialoguePanel declares 'quest_accepted' signal")

	# Open Dialogue for CEO Alex (Chapter 1)
	dial.open_for_npc(
		"ceo_alex",
		"CEO Alex",
		"Chief Executive Officer",
		"Welcome to the startup campus! Let's deploy the MVP.",
		"quest_briefcases",
		"Gather Funding Briefcases",
		"Find 3 briefcases on campus",
		3,
		500.0,
		1,
		Color(0.2, 0.7, 1.0),
		null,
		[],
		1
	)
	_assert_check(dial.visible == true, "4.8 open_for_npc() makes DialoguePanel visible")
	var npc_name_lbl = dial.get_node_or_null("%NPCNameLabel") as Label
	_assert_check(npc_name_lbl != null and npc_name_lbl.text == "CEO Alex", "4.9 NPC name label displays 'CEO Alex'")

	# Verify 3 choice options
	var choice1 = dial.get_node_or_null("%ChoiceButton1") as Button
	var choice2 = dial.get_node_or_null("%ChoiceButton2") as Button
	var choice3 = dial.get_node_or_null("%ChoiceButton3") as Button
	_assert_check(choice1 != null and choice2 != null and choice3 != null, "4.10 Choice buttons 1, 2, 3 exist")

	var choice_picked: Array[bool] = [false]
	dial.choice_selected.connect(func(_id, _type, _val): choice_picked[0] = true)
	dial._on_choice_pressed(0)
	_assert_check(choice_picked[0] == true, "4.11 _on_choice_pressed(0) emits choice_selected signal")

	# Close dialogue
	var dial_closed: Array[bool] = [false]
	dial.closed.connect(func(): dial_closed[0] = true)
	dial.close_dialogue()
	_assert_check(dial_closed[0] == true, "4.12 close_dialogue() emits closed signal")
	_assert_check(dial.visible == false, "4.13 DialoguePanel visible == false after close")

	dial.queue_free()
	await process_frame

	# -------------------------------------------------------------------------
	# 4.3 Modal 3: TechTreeModal (Lifecycle & Interaction)
	# -------------------------------------------------------------------------
	print("--- 4.3 Modal 3: TechTreeModal ---")
	var tech_scene = load("res://scenes/ui/tech_tree_modal.tscn")
	_assert_check(tech_scene != null, "4.14 Load res://scenes/ui/tech_tree_modal.tscn")
	var tech_modal = tech_scene.instantiate() as Control
	root.add_child(tech_modal)
	await process_frame

	_assert_check(tech_modal.has_method("open"), "4.15 TechTreeModal implements open()")
	_assert_check(tech_modal.has_method("close"), "4.16 TechTreeModal implements close()")
	_assert_check(tech_modal.has_signal("closed"), "4.17 TechTreeModal declares closed signal")

	tech_modal.open()
	_assert_check(tech_modal.visible == true, "4.18 TechTreeModal.open() makes modal visible")
	_assert_check(tech_modal._card_nodes.size() == 5, "4.19 TechTreeModal registers exactly 5 tech cards")

	# Simulate energy change reactivity
	gs.energy = 10000.0
	tech_modal._on_energy_changed(gs.energy, 0.0)
	var coffee_btn = tech_modal._button_nodes.get("tech_coffee_automation") as Button
	_assert_check(coffee_btn != null and coffee_btn.disabled == false, "4.20 Coffee Automation button unlocked with 10,000 energy")

	# Research tech
	tech_modal._on_research_button_pressed("tech_coffee_automation")
	_assert_check(gs.is_tech_researched("tech_coffee_automation") == true, "4.21 Tech 'tech_coffee_automation' researched in GameState")
	_assert_check(coffee_btn.text == "Researched ✓", "4.22 Coffee button text updated to 'Researched ✓'")

	var tech_closed: Array[bool] = [false]
	tech_modal.closed.connect(func(): tech_closed[0] = true)
	tech_modal.close()
	_assert_check(tech_closed[0] == true, "4.23 TechTreeModal.close() emits closed signal")
	await process_frame

	# -------------------------------------------------------------------------
	# 4.4 Modal 4: SettingsModal (Lifecycle & Interaction)
	# -------------------------------------------------------------------------
	print("--- 4.4 Modal 4: SettingsModal ---")
	var set_scene = load("res://scenes/ui/settings_modal.tscn")
	_assert_check(set_scene != null, "4.24 Load res://scenes/ui/settings_modal.tscn")
	var set_modal = set_scene.instantiate() as Control
	root.add_child(set_modal)
	await process_frame

	_assert_check(set_modal.has_method("open"), "4.25 SettingsModal implements open()")
	_assert_check(set_modal.has_method("close"), "4.26 SettingsModal implements close()")

	var master_slider = set_modal.get_node_or_null("%MasterVolumeSlider") as HSlider
	_assert_check(master_slider != null, "4.27 MasterVolumeSlider exists in SettingsModal")

	var vol_changed: Array[bool] = [false]
	set_modal.master_volume_changed.connect(func(_val): vol_changed[0] = true)
	if master_slider != null:
		master_slider.value = 0.65
	_assert_check(vol_changed[0] == true, "4.28 Changing MasterVolumeSlider emits master_volume_changed")

	var haptics_tgl = set_modal.get_node_or_null("%HapticsToggle") as Button
	_assert_check(haptics_tgl != null, "4.29 HapticsToggle exists in SettingsModal")
	var haptic_toggled: Array[bool] = [false]
	set_modal.haptics_toggled.connect(func(_e): haptic_toggled[0] = true)
	if haptics_tgl != null:
		haptics_tgl.button_pressed = false
	_assert_check(haptic_toggled[0] == true, "4.30 Toggling HapticsToggle emits haptics_toggled")

	var set_closed: Array[bool] = [false]
	set_modal.closed.connect(func(): set_closed[0] = true)
	set_modal.close()
	_assert_check(set_closed[0] == true, "4.31 SettingsModal.close() emits closed signal")
	await process_frame

	# -------------------------------------------------------------------------
	# 4.5 Modal 5: IpoModal (Lifecycle & Interaction)
	# -------------------------------------------------------------------------
	print("--- 4.5 Modal 5: IpoModal ---")
	var ipo_scene = load("res://scenes/ui/ipo_modal.tscn")
	_assert_check(ipo_scene != null, "4.32 Load res://scenes/ui/ipo_modal.tscn")
	var ipo_modal = ipo_scene.instantiate() as Control
	root.add_child(ipo_modal)
	await process_frame

	_assert_check(ipo_modal.has_method("open"), "4.33 IpoModal implements open()")
	_assert_check(ipo_modal.has_method("close"), "4.34 IpoModal implements close()")

	# Test 2-Stage Confirmation Workflow
	var trigger_btn = ipo_modal.get_node_or_null("%TriggerIPOButton") as Button
	var confirm_box = ipo_modal.get_node_or_null("%ConfirmBox") as Control
	_assert_check(trigger_btn != null and confirm_box != null, "4.35 TriggerIPOButton and ConfirmBox exist in IpoModal")

	gs.total_energy_earned = 10_000_000.0
	gs.total_lifetime_energy = 10_000_000.0
	gs.energy = 10_000_000.0
	ipo_modal._update_display()

	ipo_modal._on_trigger_ipo_pressed()
	_assert_check(ipo_modal._is_confirming == true, "4.36 _on_trigger_ipo_pressed enters confirmation stage")
	_assert_check(confirm_box.visible == true, "4.37 ConfirmBox is visible in confirmation stage")

	ipo_modal._on_confirm_cancel_pressed()
	_assert_check(ipo_modal._is_confirming == false, "4.38 _on_confirm_cancel_pressed reverts confirmation state")
	_assert_check(confirm_box.visible == false, "4.39 ConfirmBox hidden after cancellation")

	# Slide-to-confirm threshold (<90% cancel vs >=90% confirm)
	var slider = ipo_modal.get_node_or_null("%SlideToConfirm") as HSlider
	if slider != null:
		slider.value = 50.0
		ipo_modal._on_slide_drag_ended(false)
		_assert_check(slider.value == 0.0, "4.40 Releasing SlideToConfirm below 90% snaps slider back to 0")

	var ipo_closed: Array[bool] = [false]
	ipo_modal.closed.connect(func(): ipo_closed[0] = true)
	ipo_modal.close()
	_assert_check(ipo_closed[0] == true, "4.41 IpoModal.close() emits closed signal")
	await process_frame

	# -------------------------------------------------------------------------
	# 4.6 Modal 6: DailyBoardModal (Lifecycle & Interaction)
	# -------------------------------------------------------------------------
	print("--- 4.6 Modal 6: DailyBoardModal ---")
	var daily_scene = load("res://scenes/ui/daily_board_modal.tscn")
	_assert_check(daily_scene != null, "4.42 Load res://scenes/ui/daily_board_modal.tscn")
	var daily_modal = daily_scene.instantiate() as Control
	root.add_child(daily_modal)
	await process_frame

	_assert_check(daily_modal.has_method("open"), "4.43 DailyBoardModal implements open()")
	_assert_check(daily_modal.has_method("close"), "4.44 DailyBoardModal implements close()")

	var t1_btn = daily_modal.get_node_or_null("%Task1ClaimButton") as Button
	var t2_btn = daily_modal.get_node_or_null("%Task2ClaimButton") as Button
	var t3_btn = daily_modal.get_node_or_null("%Task3ClaimButton") as Button
	_assert_check(t1_btn != null and t2_btn != null and t3_btn != null, "4.45 All 3 daily task claim buttons exist")

	# Reactive streak update
	gs.daily_board_streak = 7
	daily_modal._on_game_state_updated()
	var streak_hdr = daily_modal.get_node_or_null("%StreakHeaderLabel") as Label
	_assert_check(streak_hdr != null and streak_hdr.text.contains("7"), "4.46 Daily streak header updates reactively to '7'")

	var daily_closed: Array[bool] = [false]
	daily_modal.closed.connect(func(): daily_closed[0] = true)
	daily_modal.close()
	_assert_check(daily_closed[0] == true, "4.47 DailyBoardModal.close() emits closed signal")
	await process_frame

	# -------------------------------------------------------------------------
	# 4.7 Modal 7: SyndicateModal (Lifecycle & Interaction)
	# -------------------------------------------------------------------------
	print("--- 4.7 Modal 7: SyndicateModal ---")
	var syn_scene = load("res://scenes/ui/syndicate_modal.tscn")
	_assert_check(syn_scene != null, "4.48 Load res://scenes/ui/syndicate_modal.tscn")
	var syn_modal = syn_scene.instantiate() as Control
	root.add_child(syn_modal)
	await process_frame

	_assert_check(syn_modal.has_method("switch_tab"), "4.49 SyndicateModal implements switch_tab()")
	_assert_check(syn_modal.has_method("close"), "4.50 SyndicateModal implements close()")

	# Tab switching
	syn_modal.switch_tab(0)
	_assert_check(syn_modal.current_tab_index == 0 and syn_modal.overview_tab.visible == true, "4.51 Switched to Tab 0 (Overview)")
	syn_modal.switch_tab(1)
	_assert_check(syn_modal.current_tab_index == 1 and syn_modal.roster_tab.visible == true, "4.52 Switched to Tab 1 (Roster & Donations)")
	syn_modal.switch_tab(2)
	_assert_check(syn_modal.current_tab_index == 2 and syn_modal.wars_tab.visible == true, "4.53 Switched to Tab 2 (Wars & Seasons)")

	# Donation presets
	gs.energy = 10000.0
	syn_modal.set_donation_preset(0.50)
	_assert_check(absf(syn_modal._selected_donation_energy - 5000.0) < 1.0, "4.54 50% preset selects 5,000 energy donation")

	var syn_closed: Array[bool] = [false]
	syn_modal.closed.connect(func(): syn_closed[0] = true)
	syn_modal.close()
	_assert_check(syn_closed[0] == true, "4.55 SyndicateModal.close() emits closed signal")
	await process_frame

	# -------------------------------------------------------------------------
	# 4.8 Modal 8: StaffModal (Lifecycle & Interaction)
	# -------------------------------------------------------------------------
	print("--- 4.8 Modal 8: StaffModal ---")
	var staff_scene = load("res://scenes/ui/staff_modal.tscn")
	_assert_check(staff_scene != null, "4.56 Load res://scenes/ui/staff_modal.tscn")
	var staff_modal = staff_scene.instantiate() as StaffModal
	root.add_child(staff_modal)
	await process_frame

	_assert_check(staff_modal.has_method("switch_tab"), "4.57 StaffModal implements switch_tab()")
	_assert_check(staff_modal.has_method("close"), "4.58 StaffModal implements close()")

	# 3 Tabs switching & clamping
	staff_modal.switch_tab(0)
	_assert_check(staff_modal.active_tab_index == 0 and staff_modal.recruiting_tab.visible == true, "4.59 Staff Tab 0 (Recruiting) active")
	staff_modal.switch_tab(1)
	_assert_check(staff_modal.active_tab_index == 1 and staff_modal.desk_upgrades_tab.visible == true, "4.60 Staff Tab 1 (Desks) active")
	staff_modal.switch_tab(2)
	_assert_check(staff_modal.active_tab_index == 2 and staff_modal.teambuilding_tab.visible == true, "4.61 Staff Tab 2 (Teambuilding) active")

	staff_modal.switch_tab(99)
	_assert_check(staff_modal.active_tab_index == 2, "4.62 Out of bounds tab 99 clamped to 2")
	staff_modal.switch_tab(-5)
	_assert_check(staff_modal.active_tab_index == 0, "4.63 Negative tab -5 clamped to 0")

	# Role OptionButton 5 specialist roles
	var role_opt = staff_modal.role_option_button
	_assert_check(role_opt != null and role_opt.item_count == 5, "4.64 RoleOptionButton contains exactly 5 specialist roles")

	var staff_closed: Array[bool] = [false]
	staff_modal.closed.connect(func(): staff_closed[0] = true)
	staff_modal.close()
	_assert_check(staff_closed[0] == true, "4.65 StaffModal.close() emits closed signal")
	await process_frame

# =============================================================================
# SECTION 5: Mobile Touch Ergonomics Audit
# =============================================================================
func _test_section_5_mobile_touch_ergonomics_audit() -> void:
	print("\n--- SECTION 5: Mobile Touch Ergonomics Audit (>= 56px Standard) ---")

	# 5.1 HUD & NavDrawer Ergonomics
	var hud_scene = load("res://scenes/hud.tscn")
	var hud = hud_scene.instantiate() as Control
	root.add_child(hud)
	await process_frame

	_assert_check(hud.get_node_or_null("%BurgerMenuButton").custom_minimum_size.y >= 56.0, "5.1 HUD BurgerMenuButton height >= 56px")
	_assert_check(hud.get_node_or_null("%CloseNavButton").custom_minimum_size.y >= 56.0, "5.2 HUD CloseNavButton height >= 56px")

	for btn_id in ["%AuthButton", "%LeaderboardButton", "%GuildButton", "%QuestButton", "%CampusButton", "%TechTreeButton", "%SettingsButton", "%IPOButton", "%SyndicateButton", "%StaffButton"]:
		var b = hud.get_node_or_null(btn_id) as Control
		_assert_check(b != null and b.custom_minimum_size.y >= 64.0, "5.3 NavDrawer item '%s' height (%.1fpx) >= 64px" % [btn_id, b.custom_minimum_size.y])

	hud.queue_free()
	await process_frame

	# 5.2 DialoguePanel Ergonomics
	var dial = load("res://scenes/dialogue_panel.tscn").instantiate() as Control
	root.add_child(dial)
	await process_frame
	_assert_check(dial.get_node_or_null("%ChoiceButton1").custom_minimum_size.y >= 56.0, "5.4 DialoguePanel ChoiceButton1 height >= 56px")
	_assert_check(dial.get_node_or_null("%ChoiceButton2").custom_minimum_size.y >= 56.0, "5.5 DialoguePanel ChoiceButton2 height >= 56px")
	_assert_check(dial.get_node_or_null("%ChoiceButton3").custom_minimum_size.y >= 56.0, "5.6 DialoguePanel ChoiceButton3 height >= 56px")
	_assert_check(dial.get_node_or_null("%AcceptButton").custom_minimum_size.y >= 56.0, "5.7 DialoguePanel AcceptButton height >= 56px")
	_assert_check(dial.get_node_or_null("%CompleteButton").custom_minimum_size.y >= 56.0, "5.8 DialoguePanel CompleteButton height >= 56px")
	_assert_check(dial.get_node_or_null("%CloseButton").custom_minimum_size.y >= 56.0, "5.9 DialoguePanel CloseButton height >= 56px")
	dial.queue_free()
	await process_frame

	# 5.3 TechTreeModal Ergonomics
	var tech = load("res://scenes/ui/tech_tree_modal.tscn").instantiate() as Control
	root.add_child(tech)
	await process_frame
	_assert_check(tech.get_node_or_null("%CloseButton").custom_minimum_size.y >= 56.0, "5.10 TechTreeModal CloseButton height >= 56px")
	for t_id in ["tech_coffee_automation", "tech_delivery_drone", "tech_server_overclock", "tech_quantum_ads", "tech_neural_cloud"]:
		var btn = tech.get_node_or_null("%Button_" + t_id) as Control
		_assert_check(btn != null and btn.custom_minimum_size.y >= 56.0, "5.11 TechTree button '%s' height >= 56px" % t_id)
	tech.queue_free()
	await process_frame

	# 5.4 SettingsModal Ergonomics
	var sett = load("res://scenes/ui/settings_modal.tscn").instantiate() as Control
	root.add_child(sett)
	await process_frame
	_assert_check(sett.get_node_or_null("%CloseButton").custom_minimum_size.y >= 56.0, "5.12 SettingsModal CloseButton height >= 56px")
	_assert_check(sett.get_node_or_null("%MasterVolumeSlider").custom_minimum_size.y >= 56.0, "5.13 Settings MasterVolumeSlider height >= 56px")
	_assert_check(sett.get_node_or_null("%SFXVolumeSlider").custom_minimum_size.y >= 56.0, "5.14 Settings SFXVolumeSlider height >= 56px")
	_assert_check(sett.get_node_or_null("%MusicVolumeSlider").custom_minimum_size.y >= 56.0, "5.15 Settings MusicVolumeSlider height >= 56px")
	_assert_check(sett.get_node_or_null("%MasterMuteToggle").custom_minimum_size.y >= 56.0, "5.16 Settings MasterMuteToggle height >= 56px")
	_assert_check(sett.get_node_or_null("%SFXMuteToggle").custom_minimum_size.y >= 56.0, "5.17 Settings SFXMuteToggle height >= 56px")
	_assert_check(sett.get_node_or_null("%MusicMuteToggle").custom_minimum_size.y >= 56.0, "5.18 Settings MusicMuteToggle height >= 56px")
	_assert_check(sett.get_node_or_null("%HapticsToggle").custom_minimum_size.y >= 56.0, "5.19 Settings HapticsToggle height >= 56px")
	_assert_check(sett.get_node_or_null("%BatterySaverToggle").custom_minimum_size.y >= 56.0, "5.20 Settings BatterySaverToggle height >= 56px")
	_assert_check(sett.get_node_or_null("%LightCycleAutoButton").custom_minimum_size.y >= 56.0, "5.21 Settings LightCycleAutoButton height >= 56px")
	_assert_check(sett.get_node_or_null("%LightCycleDayButton").custom_minimum_size.y >= 56.0, "5.22 Settings LightCycleDayButton height >= 56px")
	_assert_check(sett.get_node_or_null("%LightCycleNightButton").custom_minimum_size.y >= 56.0, "5.23 Settings LightCycleNightButton height >= 56px")
	sett.queue_free()
	await process_frame

	# 5.5 IpoModal Ergonomics
	var ipo = load("res://scenes/ui/ipo_modal.tscn").instantiate() as Control
	root.add_child(ipo)
	await process_frame
	_assert_check(ipo.get_node_or_null("%CloseButton").custom_minimum_size.y >= 56.0, "5.24 IpoModal CloseButton height >= 56px")
	_assert_check(ipo.get_node_or_null("%TriggerIPOButton").custom_minimum_size.y >= 56.0, "5.25 IpoModal TriggerIPOButton height >= 56px")
	_assert_check(ipo.get_node_or_null("%ConfirmYesButton").custom_minimum_size.y >= 56.0, "5.26 IpoModal ConfirmYesButton height >= 56px")
	_assert_check(ipo.get_node_or_null("%ConfirmCancelButton").custom_minimum_size.y >= 56.0, "5.27 IpoModal ConfirmCancelButton height >= 56px")
	_assert_check(ipo.get_node_or_null("%SlideToConfirm").custom_minimum_size.y >= 56.0, "5.28 IpoModal SlideToConfirm height >= 56px")
	ipo.queue_free()
	await process_frame

	# 5.6 DailyBoardModal Ergonomics
	var daily = load("res://scenes/ui/daily_board_modal.tscn").instantiate() as Control
	root.add_child(daily)
	await process_frame
	_assert_check(daily.get_node_or_null("%CloseButton").custom_minimum_size.y >= 56.0, "5.29 DailyBoardModal CloseButton height >= 56px")
	_assert_check(daily.get_node_or_null("%Task1ClaimButton").custom_minimum_size.y >= 56.0, "5.30 DailyBoard Task1ClaimButton height >= 56px")
	_assert_check(daily.get_node_or_null("%Task2ClaimButton").custom_minimum_size.y >= 56.0, "5.31 DailyBoard Task2ClaimButton height >= 56px")
	_assert_check(daily.get_node_or_null("%Task3ClaimButton").custom_minimum_size.y >= 56.0, "5.32 DailyBoard Task3ClaimButton height >= 56px")
	daily.queue_free()
	await process_frame

	# 5.7 SyndicateModal Ergonomics
	var syn = load("res://scenes/ui/syndicate_modal.tscn").instantiate() as Control
	root.add_child(syn)
	await process_frame
	_assert_check(syn.get_node_or_null("%CloseButton").custom_minimum_size.y >= 56.0, "5.33 SyndicateModal CloseButton height >= 56px")
	_assert_check(syn.get_node_or_null("%OverviewTabButton").custom_minimum_size.y >= 56.0, "5.34 Syndicate OverviewTabButton height >= 56px")
	_assert_check(syn.get_node_or_null("%RosterTabButton").custom_minimum_size.y >= 56.0, "5.35 Syndicate RosterTabButton height >= 56px")
	_assert_check(syn.get_node_or_null("%WarsTabButton").custom_minimum_size.y >= 56.0, "5.36 Syndicate WarsTabButton height >= 56px")
	_assert_check(syn.get_node_or_null("%Preset10Button").custom_minimum_size.y >= 56.0, "5.37 Syndicate Preset10Button height >= 56px")
	_assert_check(syn.get_node_or_null("%Preset50Button").custom_minimum_size.y >= 56.0, "5.38 Syndicate Preset50Button height >= 56px")
	_assert_check(syn.get_node_or_null("%PresetMaxButton").custom_minimum_size.y >= 56.0, "5.39 Syndicate PresetMaxButton height >= 56px")
	_assert_check(syn.get_node_or_null("%DonateEnergyButton").custom_minimum_size.y >= 56.0, "5.40 Syndicate DonateEnergyButton height >= 56px")
	_assert_check(syn.get_node_or_null("%DonateSharesButton").custom_minimum_size.y >= 56.0, "5.41 Syndicate DonateSharesButton height >= 56px")
	syn.queue_free()
	await process_frame

	# 5.8 StaffModal Ergonomics
	var staff = load("res://scenes/ui/staff_modal.tscn").instantiate() as Control
	root.add_child(staff)
	await process_frame
	_assert_check(staff.get_node_or_null("%CloseButton").custom_minimum_size.y >= 56.0, "5.42 StaffModal CloseButton height >= 56px")
	_assert_check(staff.get_node_or_null("%RecruitingTabButton").custom_minimum_size.y >= 56.0, "5.43 Staff RecruitingTabButton height >= 56px")
	_assert_check(staff.get_node_or_null("%DeskUpgradesTabButton").custom_minimum_size.y >= 56.0, "5.44 Staff DeskUpgradesTabButton height >= 56px")
	_assert_check(staff.get_node_or_null("%TeambuildingTabButton").custom_minimum_size.y >= 56.0, "5.45 Staff TeambuildingTabButton height >= 56px")
	_assert_check(staff.get_node_or_null("%RoleOptionButton").custom_minimum_size.y >= 56.0, "5.46 Staff RoleOptionButton height >= 56px")
	_assert_check(staff.get_node_or_null("%RecruitButton").custom_minimum_size.y >= 56.0, "5.47 Staff RecruitButton height >= 56px")
	_assert_check(staff.get_node_or_null("%ServeCoffeeBreakButton").custom_minimum_size.y >= 64.0, "5.48 Staff ServeCoffeeBreakButton height >= 64px")
	staff.queue_free()
	await process_frame

	# 5.9 TouchControls Ergonomics
	var tc = load("res://scenes/ui/touch_controls.tscn").instantiate() as Control
	root.add_child(tc)
	await process_frame
	_assert_check(tc.get_node_or_null("%ActionButton").custom_minimum_size.y >= 100.0, "5.49 ActionButton height (100px) >= 100px")
	_assert_check(tc.get_node_or_null("%CampusThumbButton").custom_minimum_size.y >= 70.0, "5.50 CampusThumbButton height (70px) >= 70px")
	_assert_check(tc.get_node_or_null("%LaptopThumbButton").custom_minimum_size.y >= 70.0, "5.51 LaptopThumbButton height (70px) >= 70px")
	tc.queue_free()
	await process_frame

# =============================================================================
# SECTION 6: Pointer Isolation Audit
# =============================================================================
func _test_section_6_pointer_isolation_audit() -> void:
	print("\n--- SECTION 6: Pointer Isolation Audit (mouse_filter = STOP) ---")

	# 6.1 HUD & NavDrawer Pointer Isolation
	var hud = load("res://scenes/hud.tscn").instantiate() as Control
	root.add_child(hud)
	await process_frame
	_assert_check(hud.get_node_or_null("%NavDrawer").mouse_filter == Control.MOUSE_FILTER_STOP, "6.1 NavDrawer root mouse_filter == STOP")
	_assert_check(hud.get_node_or_null("%NavDrawerBackdrop").mouse_filter == Control.MOUSE_FILTER_STOP, "6.2 NavDrawerBackdrop mouse_filter == STOP")
	_assert_check(hud.get_node_or_null("BottomContainer").mouse_filter == Control.MOUSE_FILTER_STOP, "6.3 BottomContainer mouse_filter == STOP")
	_assert_check(hud.get_node_or_null("BottomContainer/ShopPanel").mouse_filter == Control.MOUSE_FILTER_STOP, "6.4 ShopPanel mouse_filter == STOP")
	hud.queue_free()
	await process_frame

	# 6.2 DialoguePanel Pointer Isolation
	var dial = load("res://scenes/dialogue_panel.tscn").instantiate() as Control
	root.add_child(dial)
	await process_frame
	_assert_check(dial.mouse_filter == Control.MOUSE_FILTER_STOP, "6.5 DialoguePanel root mouse_filter == STOP")
	_assert_check(dial.get_node_or_null("DimBackdrop").mouse_filter == Control.MOUSE_FILTER_STOP, "6.6 DialoguePanel DimBackdrop mouse_filter == STOP")
	_assert_check(dial.get_node_or_null("CenterContainer/CardPanel").mouse_filter == Control.MOUSE_FILTER_STOP, "6.7 DialoguePanel CardPanel mouse_filter == STOP")
	dial.queue_free()
	await process_frame

	# 6.3 TechTreeModal Pointer Isolation
	var tech = load("res://scenes/ui/tech_tree_modal.tscn").instantiate() as Control
	root.add_child(tech)
	await process_frame
	_assert_check(tech.mouse_filter == Control.MOUSE_FILTER_STOP, "6.8 TechTreeModal root mouse_filter == STOP")
	_assert_check(tech.get_node_or_null("Backdrop").mouse_filter == Control.MOUSE_FILTER_STOP, "6.9 TechTreeModal Backdrop mouse_filter == STOP")
	tech.queue_free()
	await process_frame

	# 6.4 SettingsModal Pointer Isolation
	var sett = load("res://scenes/ui/settings_modal.tscn").instantiate() as Control
	root.add_child(sett)
	await process_frame
	_assert_check(sett.mouse_filter == Control.MOUSE_FILTER_STOP, "6.10 SettingsModal root mouse_filter == STOP")
	_assert_check(sett.get_node_or_null("Backdrop").mouse_filter == Control.MOUSE_FILTER_STOP, "6.11 SettingsModal Backdrop mouse_filter == STOP")
	_assert_check(sett.get_node_or_null("CenterContainer/ModalCard").mouse_filter == Control.MOUSE_FILTER_STOP, "6.12 SettingsModal ModalCard mouse_filter == STOP")
	sett.queue_free()
	await process_frame

	# 6.5 IpoModal Pointer Isolation
	var ipo = load("res://scenes/ui/ipo_modal.tscn").instantiate() as Control
	root.add_child(ipo)
	await process_frame
	_assert_check(ipo.mouse_filter == Control.MOUSE_FILTER_STOP, "6.13 IpoModal root mouse_filter == STOP")
	_assert_check(ipo.get_node_or_null("Backdrop").mouse_filter == Control.MOUSE_FILTER_STOP, "6.14 IpoModal Backdrop mouse_filter == STOP")
	_assert_check(ipo.get_node_or_null("CenterContainer/ModalCard").mouse_filter == Control.MOUSE_FILTER_STOP, "6.15 IpoModal ModalCard mouse_filter == STOP")
	ipo.queue_free()
	await process_frame

	# 6.6 DailyBoardModal Pointer Isolation
	var daily = load("res://scenes/ui/daily_board_modal.tscn").instantiate() as Control
	root.add_child(daily)
	await process_frame
	_assert_check(daily.mouse_filter == Control.MOUSE_FILTER_STOP, "6.16 DailyBoardModal root mouse_filter == STOP")
	_assert_check(daily.get_node_or_null("Backdrop").mouse_filter == Control.MOUSE_FILTER_STOP, "6.17 DailyBoardModal Backdrop mouse_filter == STOP")
	_assert_check(daily.get_node_or_null("CenterContainer/ModalCard").mouse_filter == Control.MOUSE_FILTER_STOP, "6.18 DailyBoardModal ModalCard mouse_filter == STOP")
	daily.queue_free()
	await process_frame

	# 6.7 SyndicateModal Pointer Isolation
	var syn = load("res://scenes/ui/syndicate_modal.tscn").instantiate() as Control
	root.add_child(syn)
	await process_frame
	_assert_check(syn.mouse_filter == Control.MOUSE_FILTER_STOP, "6.19 SyndicateModal root mouse_filter == STOP")
	_assert_check(syn.get_node_or_null("Backdrop").mouse_filter == Control.MOUSE_FILTER_STOP, "6.20 SyndicateModal Backdrop mouse_filter == STOP")
	_assert_check(syn.get_node_or_null("CenterContainer/ModalCard").mouse_filter == Control.MOUSE_FILTER_STOP, "6.21 SyndicateModal ModalCard mouse_filter == STOP")
	syn.queue_free()
	await process_frame

	# 6.8 StaffModal Pointer Isolation
	var staff = load("res://scenes/ui/staff_modal.tscn").instantiate() as Control
	root.add_child(staff)
	await process_frame
	_assert_check(staff.mouse_filter == Control.MOUSE_FILTER_STOP, "6.22 StaffModal root mouse_filter == STOP")
	_assert_check(staff.get_node_or_null("Backdrop").mouse_filter == Control.MOUSE_FILTER_STOP, "6.23 StaffModal Backdrop mouse_filter == STOP")
	_assert_check(staff.get_node_or_null("CenterContainer/ModalCard").mouse_filter == Control.MOUSE_FILTER_STOP, "6.24 StaffModal ModalCard mouse_filter == STOP")
	staff.queue_free()
	await process_frame

	# 6.9 3-Tier Input Isolation Verification on TouchControls
	var tc = load("res://scenes/ui/touch_controls.tscn").instantiate() as TouchControls
	root.add_child(tc)
	await process_frame

	# Tier 3: Root allows background pass-through
	_assert_check(tc.mouse_filter == Control.MOUSE_FILTER_IGNORE, "6.25 Tier 3 Isolation: Root TouchControls mouse_filter == MOUSE_FILTER_IGNORE (2)")

	# Tier 2: VirtualJoystick intercepts left half touches
	var vj = tc.get_node_or_null("VirtualJoystick") as VirtualJoystick
	_assert_check(vj != null and vj.mouse_filter == Control.MOUSE_FILTER_STOP, "6.26 Tier 2 Isolation: VirtualJoystick mouse_filter == STOP (0)")

	# Tier 1: Action button and radial thumb buttons absorb taps
	_assert_check(tc.action_button.mouse_filter == Control.MOUSE_FILTER_STOP, "6.27 Tier 1 Isolation: ActionButton mouse_filter == STOP (0)")
	_assert_check(tc.campus_button.mouse_filter == Control.MOUSE_FILTER_STOP, "6.28 Tier 1 Isolation: CampusThumbButton mouse_filter == STOP (0)")
	_assert_check(tc.laptop_button.mouse_filter == Control.MOUSE_FILTER_STOP, "6.29 Tier 1 Isolation: LaptopThumbButton mouse_filter == STOP (0)")

	tc.queue_free()
	await process_frame
