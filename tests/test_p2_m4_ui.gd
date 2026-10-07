extends SceneTree

## Headless Test Harness for Milestone P2-M4: UI Modals & HUD Integration.
## Validates:
## 1. Scene loading & parsing for hud.tscn and 4 UI modals
## 2. HUD baseline integrity & unique node references
## 3. Modal control hierarchies, node paths, and input fields
## 4. Modal open/close lifecycles and close button behavior
## 5. HUD Online Action Bar button interactions
## 6. Dynamic connection status badge updates
## 7. Offline fallback resilience and regression safety
## 8. Quest modal signal handling & reward claim workflow
## 9. Guild modal description & name binding verification
## 10. Leaderboard modal concurrency & tab protection
##
## Executable via: godot --headless --path IdleArcade -s tests/test_p2_m4_ui.gd

var pass_count: int = 0
var fail_count: int = 0

func _init() -> void:
	print("===========================================================")
	print("[TEST] IdleArcade Phase 2 Milestone 4: UI & Modal Suite")
	print("===========================================================")
	process_frame.connect(_on_first_frame, CONNECT_ONE_SHOT)

func _on_first_frame() -> void:
	await _run_all_ui_tests()
	print("\n===========================================================")
	print("[TEST] Results: %d passed, %d failed" % [pass_count, fail_count])
	print("===========================================================")
	if fail_count == 0:
		print(">>> ALL P2-M4 UI TESTS PASSED SUCCESSFULLY! <<<")
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

func _run_all_ui_tests() -> void:
	# -------------------------------------------------------------------------
	# 0. Environment Setup: Mount GameState, Nakama, and NakamaManager
	# -------------------------------------------------------------------------
	var gs_script = load("res://scripts/autoload/game_state.gd")
	var gs = root.get_node_or_null("GameState")
	if gs == null and gs_script != null:
		gs = gs_script.new()
		gs.name = "GameState"
		root.add_child(gs)

	var nakama_script = load("res://addons/com.heroiclabs.nakama/Nakama.gd")
	var nakama_singleton = root.get_node_or_null("Nakama")
	if nakama_singleton == null and nakama_script != null:
		nakama_singleton = nakama_script.new()
		nakama_singleton.name = "Nakama"
		root.add_child(nakama_singleton)

	var mgr_script = load("res://scripts/autoload/nakama_manager.gd")
	var mgr = root.get_node_or_null("NakamaManager")
	if mgr == null and mgr_script != null:
		mgr = mgr_script.new()
		mgr.name = "NakamaManager"
		mgr.auto_login_on_ready = false  # Controlled test mode
		root.add_child(mgr)

	await process_frame

	# =========================================================================
	# SECTION 1: Scene & Script Loading (Syntax Verification)
	# =========================================================================
	print("\n--- Section 1: Scene & Script Loading ---")

	var hud_scene = load("res://scenes/hud.tscn")
	_assert_check(hud_scene != null, "1.1 scenes/hud.tscn loaded successfully")

	var auth_scene = load("res://scenes/ui/auth_modal.tscn")
	_assert_check(auth_scene != null, "1.2 scenes/ui/auth_modal.tscn loaded successfully")

	var lb_scene = load("res://scenes/ui/leaderboard_modal.tscn")
	_assert_check(lb_scene != null, "1.3 scenes/ui/leaderboard_modal.tscn loaded successfully")

	var guild_scene = load("res://scenes/ui/guild_modal.tscn")
	_assert_check(guild_scene != null, "1.4 scenes/ui/guild_modal.tscn loaded successfully")

	var quest_scene = load("res://scenes/ui/quest_modal.tscn")
	_assert_check(quest_scene != null, "1.5 scenes/ui/quest_modal.tscn loaded successfully")

	if hud_scene == null or auth_scene == null or lb_scene == null or guild_scene == null or quest_scene == null:
		printerr("[FATAL] One or more required scenes failed to load. Halting further tests.")
		return

	# =========================================================================
	# SECTION 2: HUD Baseline Integrity & Action Bar Integration
	# =========================================================================
	print("\n--- Section 2: HUD Integrity & Action Bar ---")

	var hud_instance = hud_scene.instantiate()
	root.add_child(hud_instance)
	await process_frame

	# 2.1 Verify Preserved Unique Nodes
	var energy_lbl = hud_instance.get_node_or_null("%EnergyLabel")
	var rps_lbl = hud_instance.get_node_or_null("%RPSLabel")
	var frenzy_mult_lbl = hud_instance.get_node_or_null("%FrenzyMultiplierLabel")
	var frenzy_bar = hud_instance.get_node_or_null("%FrenzyProgressBar")
	var upgrade_list = hud_instance.get_node_or_null("%UpgradeList")

	_assert_check(
		energy_lbl != null and rps_lbl != null and frenzy_mult_lbl != null and frenzy_bar != null and upgrade_list != null,
		"2.1 All 5 baseline HUD unique nodes present (%EnergyLabel, %RPSLabel, etc.)"
	)

	# 2.2 Verify Upgrade Cards Populated
	var card_count: int = upgrade_list.get_child_count() if upgrade_list != null else 0
	_assert_check(card_count == 9, "2.2 Upgrade list contains exactly 9 upgrade cards (got %d)" % card_count)

	# 2.3 Verify Online Action Bar Buttons
	var auth_btn = hud_instance.find_child("AuthButton", true, false)
	var lb_btn = hud_instance.find_child("LeaderboardButton", true, false)
	var guild_btn = hud_instance.find_child("GuildButton", true, false)
	var quest_btn = hud_instance.find_child("QuestButton", true, false)

	_assert_check(
		auth_btn is Button and lb_btn is Button and guild_btn is Button and quest_btn is Button,
		"2.3 Online Action Bar buttons exist (Auth, Leaderboard, Guild, Quest)"
	)

	# 2.4 Verify Connection Status Badge
	var status_ind = hud_instance.find_child("StatusIndicator", true, false)
	_assert_check(status_ind is Label, "2.4 StatusIndicator label present in HUD")

	if status_ind is Label and mgr != null:
		mgr.connection_status_changed.emit(true, "ONLINE")
		await process_frame
		var online_txt = status_ind.text
		mgr.connection_status_changed.emit(false, "OFFLINE")
		await process_frame
		var offline_txt = status_ind.text
		_assert_check(
			online_txt.contains("ONLINE") and offline_txt.contains("OFFLINE"),
			"2.5 StatusIndicator dynamically updates on connection_status_changed"
		)

	# =========================================================================
	# SECTION 3: Auth Modal Hierarchy & Interactions
	# =========================================================================
	print("\n--- Section 3: Auth Modal Hierarchy & Interactions ---")

	var auth_instance = auth_scene.instantiate()
	root.add_child(auth_instance)
	await process_frame

	var auth_backdrop = auth_instance.find_child("Backdrop", true, false)
	var auth_close = auth_instance.find_child("CloseButton", true, false)
	var email_input = auth_instance.find_child("EmailInput", true, false)
	var pass_input = auth_instance.find_child("PasswordInput", true, false)
	var login_btn = auth_instance.find_child("LoginButton", true, false)
	var reg_btn = auth_instance.find_child("RegisterButton", true, false)
	var google_btn = auth_instance.find_child("GoogleButton", true, false)
	var logout_btn = auth_instance.find_child("LogoutButton", true, false)
	var dev_id_lbl = auth_instance.find_child("DeviceIdLabel", true, false)

	_assert_check(auth_backdrop != null and auth_backdrop.mouse_filter == Control.MOUSE_FILTER_STOP, "3.1 AuthModal backdrop blocks input")
	_assert_check(auth_close is Button, "3.2 AuthModal CloseButton exists")
	_assert_check(email_input is LineEdit and pass_input is LineEdit and pass_input.secret == true, "3.3 AuthModal email/password inputs exist with secret mask")
	_assert_check(login_btn is Button and reg_btn is Button and google_btn is Button and logout_btn is Button, "3.4 AuthModal action buttons exist")
	_assert_check(dev_id_lbl is Label, "3.5 AuthModal DeviceIdLabel exists")

	# Test Close Button
	auth_instance.visible = true
	auth_close.pressed.emit()
	await process_frame
	_assert_check(not auth_instance.visible or auth_instance.is_queued_for_deletion(), "3.6 AuthModal hides or frees when CloseButton pressed")

	auth_instance.queue_free()
	await process_frame

	# =========================================================================
	# SECTION 4: Leaderboard Modal Hierarchy & Interactions
	# =========================================================================
	print("\n--- Section 4: Leaderboard Modal Hierarchy & Interactions ---")

	var lb_instance = lb_scene.instantiate()
	root.add_child(lb_instance)
	await process_frame

	var lb_close = lb_instance.find_child("CloseButton", true, false)
	var global_tab = lb_instance.find_child("GlobalTab", true, false)
	var local_tab = lb_instance.find_child("LocalTab", true, false)
	var guild_tab = lb_instance.find_child("GuildTab", true, false)
	var refresh_btn = lb_instance.find_child("RefreshButton", true, false)
	var records_list = lb_instance.find_child("LeaderboardList", true, false)

	_assert_check(lb_close is Button, "4.1 LeaderboardModal CloseButton exists")
	_assert_check(
		(global_tab != null and local_tab != null and guild_tab != null) or lb_instance.find_child("TabContainer", true, false) != null,
		"4.2 LeaderboardModal contains tabs for Global, Local, and Guild"
	)
	_assert_check(records_list != null or lb_instance.find_child("RecordsContainer", true, false) != null, "4.3 Leaderboard records list container exists")

	# Test Close Button
	lb_instance.visible = true
	lb_close.pressed.emit()
	await process_frame
	_assert_check(not lb_instance.visible or lb_instance.is_queued_for_deletion(), "4.4 LeaderboardModal hides or frees when CloseButton pressed")

	lb_instance.queue_free()
	await process_frame

	# =========================================================================
	# SECTION 5: Guild Modal Hierarchy & Interactions
	# =========================================================================
	print("\n--- Section 5: Guild Modal Hierarchy & Interactions ---")

	var guild_instance = guild_scene.instantiate()
	root.add_child(guild_instance)
	await process_frame

	var guild_close = guild_instance.find_child("CloseButton", true, false)
	var create_btn = guild_instance.find_child("CreateButton", true, false)
	var guild_name_in = guild_instance.find_child("GuildNameInput", true, false)
	var guild_list_cont = guild_instance.find_child("GuildList", true, false)

	_assert_check(guild_close is Button, "5.1 GuildModal CloseButton exists")
	_assert_check(create_btn is Button or guild_instance.find_child("CreateGuildButton", true, false) is Button, "5.2 GuildModal Create Button exists")
	_assert_check(guild_name_in is LineEdit or guild_instance.find_child("NameInput", true, false) is LineEdit, "5.3 GuildModal Name Input exists")
	_assert_check(guild_list_cont != null, "5.4 GuildModal GuildList container exists")

	# Test Close Button
	guild_instance.visible = true
	guild_close.pressed.emit()
	await process_frame
	_assert_check(not guild_instance.visible or guild_instance.is_queued_for_deletion(), "5.5 GuildModal hides or frees when CloseButton pressed")

	guild_instance.queue_free()
	await process_frame

	# =========================================================================
	# SECTION 6: Quest Modal Hierarchy & Claim Workflow
	# =========================================================================
	print("\n--- Section 6: Quest Modal Hierarchy & Claim Workflow ---")

	var quest_instance = quest_scene.instantiate()
	root.add_child(quest_instance)
	await process_frame

	var quest_close = quest_instance.find_child("CloseButton", true, false)
	var tap_progress = quest_instance.find_child("TapProgressBar", true, false)
	var upgrade_progress = quest_instance.find_child("UpgradeProgressBar", true, false)
	var spark_progress = quest_instance.find_child("SparkProgressBar", true, false)
	var total_bonus_lbl = quest_instance.find_child("TotalBonusLabel", true, false)

	_assert_check(quest_close is Button, "6.1 QuestModal CloseButton exists")
	_assert_check(
		(tap_progress is ProgressBar and upgrade_progress is ProgressBar and spark_progress is ProgressBar)
		or quest_instance.find_children("", "ProgressBar", true, false).size() >= 3,
		"6.2 QuestModal contains 3 progress bars for Daily Quests"
	)
	_assert_check(total_bonus_lbl is Label, "6.3 QuestModal TotalBonusLabel exists")

	# Test Close Button
	quest_instance.visible = true
	quest_close.pressed.emit()
	await process_frame
	_assert_check(not quest_instance.visible or quest_instance.is_queued_for_deletion(), "6.4 QuestModal hides or frees when CloseButton pressed")

	quest_instance.queue_free()
	await process_frame

	# =========================================================================
	# SECTION 7: HUD Action Bar Modal Invocation
	# =========================================================================
	print("\n--- Section 7: HUD Action Bar Modal Invocation ---")

	# 7.1 Open Auth Modal from HUD
	if auth_btn is Button:
		auth_btn.pressed.emit()
		await process_frame
		var active_auth = hud_instance.find_child("AuthModal", true, false)
		_assert_check(active_auth != null and active_auth.visible == true, "7.1 Pressing AuthButton displays AuthModal")
		if active_auth != null:
			var btn_close = active_auth.find_child("CloseButton", true, false)
			if btn_close is Button:
				btn_close.pressed.emit()
				await process_frame
				_assert_check(not active_auth.visible or active_auth.is_queued_for_deletion(), "7.2 Closing AuthModal returns HUD to clean state")

	# 7.3 Open Leaderboard Modal from HUD
	if lb_btn is Button:
		lb_btn.pressed.emit()
		await process_frame
		var active_lb = hud_instance.find_child("LeaderboardModal", true, false)
		_assert_check(active_lb != null and active_lb.visible == true, "7.3 Pressing LeaderboardButton displays LeaderboardModal")
		if active_lb != null:
			var btn_close = active_lb.find_child("CloseButton", true, false)
			if btn_close is Button:
				btn_close.pressed.emit()
				await process_frame
				_assert_check(not active_lb.visible or active_lb.is_queued_for_deletion(), "7.4 Closing LeaderboardModal cleans up")

	# 7.5 Open Guild Modal from HUD
	if guild_btn is Button:
		guild_btn.pressed.emit()
		await process_frame
		var active_guild = hud_instance.find_child("GuildModal", true, false)
		_assert_check(active_guild != null and active_guild.visible == true, "7.5 Pressing GuildButton displays GuildModal")
		if active_guild != null:
			var btn_close = active_guild.find_child("CloseButton", true, false)
			if btn_close is Button:
				btn_close.pressed.emit()
				await process_frame
				_assert_check(not active_guild.visible or active_guild.is_queued_for_deletion(), "7.6 Closing GuildModal cleans up")

	# 7.7 Open Quest Modal from HUD
	if quest_btn is Button:
		quest_btn.pressed.emit()
		await process_frame
		var active_quest = hud_instance.find_child("QuestModal", true, false)
		_assert_check(active_quest != null and active_quest.visible == true, "7.7 Pressing QuestButton displays QuestModal")
		if active_quest != null:
			var btn_close = active_quest.find_child("CloseButton", true, false)
			if btn_close is Button:
				btn_close.pressed.emit()
				await process_frame
				_assert_check(not active_quest.visible or active_quest.is_queued_for_deletion(), "7.8 Closing QuestModal cleans up")

	# Teardown HUD
	hud_instance.queue_free()
	await process_frame

	# =========================================================================
	# SECTION 8: Quest Modal Signal Handling & Reward Claim Workflow
	# =========================================================================
	print("\n--- Section 8: Quest Modal Signal Handling & Reward Claim Workflow ---")

	var qm_instance = quest_scene.instantiate()
	root.add_child(qm_instance)
	await process_frame

	var qm_bonus_lbl: Label = qm_instance.find_child("TotalBonusLabel", true, false)
	var qm_claim_btn: Button = qm_instance.find_child("ClaimButton_Tap", true, false)
	var qm_status_lbl: Label = qm_instance.find_child("StatusLabel", true, false)

	# 8.1 Verify Initial TotalBonusLabel format
	_assert_check(
		qm_bonus_lbl != null and qm_bonus_lbl.text.contains("👥 Bonus Users: +0"),
		"8.1 TotalBonusLabel displays initial 0 bonus users correctly"
	)

	# 8.2 Verify GameState.bonus_users_changed 2-arg emission handled without callable crash
	var _initial_bonus: int = gs.bonus_users
	gs.bonus_users = 100
	gs.bonus_users_changed.emit(100, 100)
	await process_frame

	_assert_check(
		qm_bonus_lbl.text.contains("+100") and qm_bonus_lbl.text.contains("+100% Passive RPS Boost"),
		"8.2 QuestModal handles bonus_users_changed(total, added) 2-parameter signal without crash and updates %TotalBonusLabel"
	)

	# 8.3 Verify award_bonus_users(amount) integration flow
	gs.award_bonus_users(25)
	await process_frame

	_assert_check(
		gs.bonus_users == 125 and qm_bonus_lbl.text.contains("+125"),
		"8.3 GameState.award_bonus_users propagates to QuestModal display (+125 Bonus Users)"
	)

	# 8.4 Setup Completed Daily Quest and simulate claim button click
	mgr.daily_quests = {
		"last_updated": int(Time.get_unix_time_from_system()),
		"date": "2026-10-07",
		"quests": {
			"daily_tap": {
				"id": "daily_tap",
				"title": "Reactor Tapper",
				"type": "tap",
				"target": 50,
				"current": 50,
				"reward_bonus_users": 25,
				"is_completed": true,
				"is_claimed": false
			},
			"daily_upgrade": {
				"id": "daily_upgrade",
				"title": "Industrial Expansion",
				"type": "upgrade",
				"target": 3,
				"current": 1,
				"reward_bonus_users": 50,
				"is_completed": false,
				"is_claimed": false
			},
			"daily_spark": {
				"id": "daily_spark",
				"title": "Energy Surge",
				"type": "spark",
				"target": 3,
				"current": 0,
				"reward_bonus_users": 100,
				"is_completed": false,
				"is_claimed": false
			}
		}
	}

	qm_instance._apply_quests_data(mgr.daily_quests)
	await process_frame

	_assert_check(
		qm_claim_btn != null and qm_claim_btn.disabled == false and qm_claim_btn.text.contains("CLAIM +25"),
		"8.4 Completed quest sets claim button enabled with 'CLAIM +25 BONUS USERS!'"
	)

	# 8.5 Trigger Claim Action
	var pre_claim_bonus: int = gs.bonus_users
	qm_claim_btn.pressed.emit()
	await process_frame
	await process_frame

	_assert_check(
		gs.bonus_users == pre_claim_bonus + 25,
		"8.5 Claim button invocation successfully increments GameState.bonus_users by 25"
	)

	_assert_check(
		qm_claim_btn.disabled == true and qm_claim_btn.text.contains("Claimed ✓"),
		"8.6 Claim button transitions to disabled 'Claimed ✓' state post-claim"
	)

	_assert_check(
		qm_status_lbl != null and qm_status_lbl.text.contains("Success! Earned +25 Bonus Users"),
		"8.7 QuestModal displays success feedback label post-claim"
	)

	# 8.8 Verify Duplicate Claim Protection
	qm_instance._on_claim_pressed("daily_tap")
	await process_frame

	_assert_check(
		gs.bonus_users == pre_claim_bonus + 25,
		"8.8 Duplicate claim attempt does not re-award bonus users"
	)

	qm_instance.queue_free()
	await process_frame

	# =========================================================================
	# SECTION 9: Guild Modal Description & Name Binding Verification
	# =========================================================================
	print("\n--- Section 9: Guild Modal Description & Name Binding Verification ---")

	var gm_instance = guild_scene.instantiate()
	root.add_child(gm_instance)
	await process_frame

	var gm_no_guild_view = gm_instance.find_child("NoGuildView", true, false)
	var gm_in_guild_view = gm_instance.find_child("InGuildView", true, false)
	var gm_name_lbl: Label = gm_instance.find_child("GuildNameLabel", true, false)
	var gm_desc_lbl: Label = gm_instance.find_child("GuildDescLabel", true, false)

	# 9.1 Verify Unaffiliated Initial State
	_assert_check(
		gm_no_guild_view.visible == true and gm_in_guild_view.visible == false,
		"9.1 Unaffiliated player displays NoGuildView and hides InGuildView"
	)

	# 9.2 Simulate Affiliated State with Custom Name and Description
	mgr.current_guild_id = "test_guild_alpha_001"
	mgr.current_guild_name = "Quantum Syndicate"
	if "current_guild_desc" in mgr:
		mgr.current_guild_desc = "Pioneering decentralized idle computing solutions."
	gm_instance._refresh_guild_state()
	await process_frame

	_assert_check(
		gm_in_guild_view.visible == true and gm_no_guild_view.visible == false,
		"9.2 Affiliated player displays InGuildView and hides NoGuildView"
	)

	_assert_check(
		gm_name_lbl != null and gm_name_lbl.text == "Quantum Syndicate",
		"9.3 GuildNameLabel displays real guild name ('Quantum Syndicate') instead of fallback"
	)

	_assert_check(
		gm_desc_lbl != null and gm_desc_lbl.text != "Network description..." and (
			gm_desc_lbl.text.contains("Pioneering") or gm_desc_lbl.text.contains("Syndicate")
		),
		"9.4 GuildDescLabel displays real guild description instead of static placeholder 'Network description...'"
	)

	# 9.5 Simulate Leaving Guild
	if gm_instance.find_child("LeaveButton", true, false) != null:
		mgr.current_guild_id = ""
		mgr.current_guild_name = ""
		if "current_guild_desc" in mgr:
			mgr.current_guild_desc = ""
		gm_instance._refresh_guild_state()
		await process_frame

		_assert_check(
			gm_no_guild_view.visible == true and gm_in_guild_view.visible == false,
			"9.5 Leaving guild returns view to NoGuildView and clears active syndicate overview"
		)

	gm_instance.queue_free()
	await process_frame

	# =========================================================================
	# SECTION 10: Leaderboard Modal Concurrency & Tab Protection
	# =========================================================================
	print("\n--- Section 10: Leaderboard Modal Concurrency & Tab Protection ---")

	var lbm_instance = lb_scene.instantiate()
	root.add_child(lbm_instance)
	await process_frame

	var g_tab: Button = lbm_instance.find_child("GlobalTab", true, false)
	var l_tab: Button = lbm_instance.find_child("LocalTab", true, false)
	var n_tab: Button = lbm_instance.find_child("GuildTab", true, false)
	var lbm_records_list: VBoxContainer = lbm_instance.find_child("LeaderboardList", true, false)

	# 10.1 Verify Tab Busy Lock Mechanism
	lbm_instance._set_busy(true, "Simulating network request...")

	_assert_check(
		g_tab.disabled == true and l_tab.disabled == true and n_tab.disabled == true,
		"10.1 LeaderboardModal disables Global, Local, and Guild tab buttons during _is_busy == true"
	)

	# 10.2 Verify Tab Switch Rejection While Busy
	var pre_tab: String = lbm_instance._current_tab
	lbm_instance._switch_tab("local")

	_assert_check(
		lbm_instance._current_tab == pre_tab,
		"10.2 LeaderboardModal._switch_tab ignores requests during _is_busy == true"
	)

	# 10.3 Verify Tab Unlock When Busy Cleared
	lbm_instance._set_busy(false)

	_assert_check(
		g_tab.disabled == false and l_tab.disabled == false and n_tab.disabled == false,
		"10.3 Tab buttons re-enabled when _is_busy is cleared (false)"
	)

	# 10.4 Verify Stale Asynchronous Response Discarding
	# Switch to local tab legitimately
	lbm_instance._switch_tab("local")
	_assert_check(lbm_instance._current_tab == "local", "10.4 Successfully switched active tab to 'local'")

	# Simulate stale global leaderboard signal arrival while local tab is active
	var stale_records: Array = [
		{"owner_id": "stale_user_99", "username": "StaleGlobalWhale", "score": 1000000, "rank": 1}
	]
	# If signal arrives for global_lifetime_users, it should NOT populate the local view
	lbm_instance._on_leaderboard_received("global_lifetime_users", stale_records)
	await process_frame

	var found_stale: bool = false
	if lbm_records_list != null:
		for child in lbm_records_list.get_children():
			if child.get_text() if child.has_method("get_text") else str(child).contains("StaleGlobalWhale"):
				found_stale = true
				break
			for lbl in child.find_children("", "Label", true, false):
				if lbl.text.contains("StaleGlobalWhale"):
					found_stale = true
					break
			if found_stale:
				break

	_assert_check(
		not found_stale,
		"10.5 Stale async/signal responses for inactive tabs are discarded and do not pollute active view"
	)

	lbm_instance.queue_free()
	await process_frame
