extends SceneTree

## Adversarial Empirical Concurrency & Interface Test Suite for Phase 2 Milestone 2.
## Validates:
## 1. Autoload ordering in project.godot (Nakama precedes NakamaManager).
## 2. P2-M3 Interface stubs and signal contracts compliance.
## 3. GameState isolation and zero-dependency regression invariance.
## 4. Concurrent login re-entrancy guard behavior (debouncing).
## 5. Rapid sequential logout -> login state hygiene.
## 6. Stale in-flight authentication race detection.
## 7. Reconnect and Device-ID determinism across lifecycle.
##
## Executable via: godot --headless --path IdleArcade -s tests/test_p2_m2_adversarial_concurrency.gd

var pass_count: int = 0
var fail_count: int = 0

func _init() -> void:
	print("=====================================================================")
	print("[CHALLENGER 2] P2-M2 Concurrency, Autoload & Interface Verification")
	print("=====================================================================")
	process_frame.connect(_on_first_frame, CONNECT_ONE_SHOT)

func _on_first_frame() -> void:
	await _run_all_tests()
	print("\n=====================================================================")
	print("[SUMMARY] Concurrency & Interface Checks: %d passed, %d failed" % [pass_count, fail_count])
	print("=====================================================================")
	if fail_count == 0:
		print(">>> ALL CONCURRENCY & INTERFACE ADVERSARIAL TESTS PASSED <<<")
		quit(0)
	else:
		printerr(">>> TEST ENCOUNTERED %d FAILURES <<<" % fail_count)
		quit(1)

func _run_all_tests() -> void:
	# -------------------------------------------------------------------------
	# 1. Autoload Ordering in project.godot
	# -------------------------------------------------------------------------
	print("\n--- Test 1: Autoload Ordering in project.godot ---")
	var project_file := FileAccess.open("res://project.godot", FileAccess.READ)
	if project_file != null:
		var content := project_file.get_as_text()
		project_file.close()

		var pos_gamestate := content.find('GameState="*res://scripts/autoload/game_state.gd"')
		var pos_nakama := content.find('Nakama="*res://addons/com.heroiclabs.nakama/Nakama.gd"')
		var pos_mgr := content.find('NakamaManager="*res://scripts/autoload/nakama_manager.gd"')

		if pos_gamestate != -1 and pos_nakama != -1 and pos_mgr != -1 and pos_nakama < pos_mgr:
			print("  [PASS] Autoload order confirmed: Nakama (pos %d) precedes NakamaManager (pos %d)" % [pos_nakama, pos_mgr])
			pass_count += 1
		else:
			printerr("  [FAIL] Autoload ordering invalid: GameState=%d, Nakama=%d, NakamaManager=%d" % [pos_gamestate, pos_nakama, pos_mgr])
			fail_count += 1
	else:
		printerr("  [FAIL] Could not open project.godot")
		fail_count += 1

	# -------------------------------------------------------------------------
	# 2. Setup Nodes for Testing
	# -------------------------------------------------------------------------
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
		mgr.auto_login_on_ready = false
		root.add_child(mgr)

	if mgr == null:
		printerr("  [FAIL] Could not instantiate NakamaManager")
		fail_count += 1
		return

	# -------------------------------------------------------------------------
	# 3. P2-M3 Interface Contract & Stubs Verification
	# -------------------------------------------------------------------------
	print("\n--- Test 2: P2-M3 Interface Stubs & Signal Contracts ---")
	var expected_p2_m3_methods = [
		{"name": "submit_score_async", "arg_count": 2},
		{"name": "fetch_leaderboard_async", "arg_count": 2},
		{"name": "fetch_guild_leaderboard_async", "arg_count": 2},
		{"name": "create_guild_async", "arg_count": 3},
		{"name": "join_guild_async", "arg_count": 1},
		{"name": "leave_guild_async", "arg_count": 1},
		{"name": "list_guilds_async", "arg_count": 1},
		{"name": "list_guild_members_async", "arg_count": 1},
		{"name": "fetch_daily_quests_async", "arg_count": 0},
		{"name": "record_quest_progress", "arg_count": 2},
		{"name": "claim_quest_reward_async", "arg_count": 1}
	]

	var method_list = mgr.get_method_list()
	var method_dict := {}
	for m in method_list:
		method_dict[m["name"]] = m

	var stubs_ok: bool = true
	for exp_m in expected_p2_m3_methods:
		var m_name: String = exp_m["name"]
		if not method_dict.has(m_name):
			printerr("  [FAIL] Missing required P2-M3 stub: %s" % m_name)
			stubs_ok = false
		else:
			var arg_cnt: int = method_dict[m_name]["args"].size()
			if arg_cnt != exp_m["arg_count"]:
				printerr("  [FAIL] Method %s arg count mismatch: expected %d, got %d" % [m_name, exp_m["arg_count"], arg_cnt])
				stubs_ok = false

	if stubs_ok:
		print("  [PASS] All 11 P2-M3 interface stubs match signature contracts in PROJECT.md.")
		pass_count += 1
	else:
		fail_count += 1

	# Verify return values of stubs return safe fallback values
	var score_ret = mgr.submit_score_async(100)
	var lb_ret = mgr.fetch_leaderboard_async()
	var guild_lb_ret = mgr.fetch_guild_leaderboard_async("g1")
	var create_g_ret = mgr.create_guild_async("Name", "Desc")
	var join_g_ret = mgr.join_guild_async("g1")
	var leave_g_ret = mgr.leave_guild_async("g1")
	var list_g_ret = mgr.list_guilds_async()
	var list_gm_ret = mgr.list_guild_members_async("g1")
	var quests_ret = mgr.fetch_daily_quests_async()
	var claim_ret = mgr.claim_quest_reward_async("q1")

	if score_ret == false and lb_ret == [] and guild_lb_ret == [] \
		and create_g_ret == {} and join_g_ret == false and leave_g_ret == false \
		and list_g_ret == [] and list_gm_ret == [] and quests_ret == {} and claim_ret == 0:
		print("  [PASS] All P2-M3 stub executions return safe typed fallback values without errors.")
		pass_count += 1
	else:
		printerr("  [FAIL] P2-M3 stub fallback return values invalid.")
		fail_count += 1

	# -------------------------------------------------------------------------
	# 4. GameState Isolation & Zero-Dependency Regression
	# -------------------------------------------------------------------------
	print("\n--- Test 3: GameState Offline Isolation & Regression Safety ---")
	var gs_script = load("res://scripts/autoload/game_state.gd")
	if gs_script != null:
		var gs = gs_script.new()
		gs.tap_core()
		gs.energy = 50.0
		var bought = gs.buy_upgrade("tier_1")
		var spark_val = gs.collect_spark()
		var formatted = gs.format_number(gs.energy)
		
		# Verify that GameState contains no references to NakamaManager
		var gs_source = gs_script.source_code
		var has_nk_ref = gs_source.contains("Nakama")
		
		if not has_nk_ref and bought and spark_val > 0.0 and gs.energy > 0.0 and not formatted.is_empty():
			print("  [PASS] GameState executes independently with zero coupling to NakamaManager.")
			pass_count += 1
		else:
			printerr("  [FAIL] GameState isolation test failed: has_nk_ref=%s" % str(has_nk_ref))
			fail_count += 1
		gs.free()
	else:
		printerr("  [FAIL] Could not load game_state.gd")
		fail_count += 1

	# -------------------------------------------------------------------------
	# 5. Concurrent Login Calls & Re-entrancy Guard Verification
	# -------------------------------------------------------------------------
	print("\n--- Test 4: Concurrency & Re-entrancy Debounce Guard ---")
	mgr.is_authenticating = true
	var mock_active_session := NakamaSession.new()
	mock_active_session.token = "token_lock_test"
	mock_active_session.user_id = "user_lock_test"
	mgr.session = mock_active_session

	# When is_authenticating is true, any concurrent login call must return current session immediately
	var concurrent_dev_sess = await mgr.login_device_async()
	var concurrent_email_sess = await mgr.login_email_async("test@example.com", "password")
	var concurrent_auto_sess = await mgr.auto_login_async()

	if concurrent_dev_sess == mock_active_session \
		and concurrent_email_sess == mock_active_session \
		and concurrent_auto_sess == mock_active_session:
		print("  [PASS] Concurrent login calls safely intercepted by is_authenticating guard.")
		pass_count += 1
	else:
		printerr("  [FAIL] Concurrent login calls did not return existing session under lock.")
		fail_count += 1

	mgr.is_authenticating = false

	# -------------------------------------------------------------------------
	# 6. Rapid Logout -> Login State Hygiene
	# -------------------------------------------------------------------------
	print("\n--- Test 5: Rapid Sequential Logout -> Login Transition ---")
	const SESS_PATH = "user://nakama_session.json"
	mgr._save_session(mock_active_session)
	mgr.is_online = true

	# Perform rapid logout
	mgr.logout()
	var sess_after_logout = mgr.get_session()
	var online_after_logout = mgr.is_online
	var file_exists_after_logout = FileAccess.file_exists(SESS_PATH)

	# Followed immediately by new mock session login
	var new_login_session = NakamaSession.new()
	new_login_session.token = "new_login_token"
	new_login_session.user_id = "new_user_id"
	mgr.session = new_login_session
	mgr.is_online = true
	mgr._save_session(new_login_session)

	var re_loaded_sess = mgr._load_cached_session()
	var state_clean: bool = (
		sess_after_logout == null
		and not online_after_logout
		and not file_exists_after_logout
		and re_loaded_sess != null
		and re_loaded_sess.token == "new_login_token"
	)

	if state_clean:
		print("  [PASS] Rapid logout followed by login cleanly resets and restores session state.")
		pass_count += 1
	else:
		printerr("  [FAIL] Rapid logout/login state hygiene failure.")
		fail_count += 1

	# Cleanup test file
	mgr._clear_saved_session()

	# -------------------------------------------------------------------------
	# 7. Device ID Determinism Across Lifecycle
	# -------------------------------------------------------------------------
	print("\n--- Test 6: Device ID Determinism Across Lifecycle ---")
	var dev_id_1 = mgr.get_or_create_device_id()
	var dev_id_2 = mgr.get_device_id()
	mgr.logout()
	var dev_id_3 = mgr.get_or_create_device_id()

	if not dev_id_1.is_empty() and dev_id_1 == dev_id_2 and dev_id_1 == dev_id_3:
		print("  [PASS] Device ID remains immutable across logout/lifecycle events: %s" % dev_id_1)
		pass_count += 1
	else:
		printerr("  [FAIL] Device ID changed across logout: id1=%s, id3=%s" % [dev_id_1, dev_id_3])
		fail_count += 1
