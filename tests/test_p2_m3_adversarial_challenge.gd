extends SceneTree

## Adversarial Empirical Challenge Test Suite for Phase 2 Milestone 3.
## Validates edge cases:
## 1. Quest progress clamping (target overflow protection, post-completion idempotency, negative guards)
## 2. UTC date rollover reset (date transitions reset active quests and cached storage)
## 3. Duplicate claim prevention (claim_quest_reward_async twice returns 0, pre-await flag safety)
## 4. Bonus user multiplier recalculation (+1% passive RPS per bonus user, offline catchup boost)
## 5. Legacy savegame loading (backward compatibility without bonus_users key, negative sanitization)
## 6. Regression safety for core GameState offline mechanics
##
## Executable via: godot --headless --path IdleArcade -s tests/test_p2_m3_adversarial_challenge.gd

func _init() -> void:
	print("=====================================================================")
	print("[ADVERSARIAL CHALLENGE] Phase 2 Milestone 3 Empirical Stress Suite")
	print("=====================================================================")
	process_frame.connect(_run_all_challenges, CONNECT_ONE_SHOT)

func _run_all_challenges() -> void:
	var pass_count: int = 0
	var fail_count: int = 0

	var assert_check = func(cond: bool, test_name: String) -> void:
		if cond:
			print("  [PASS] %s" % test_name)
			pass_count += 1
		else:
			printerr("  [FAIL] %s" % test_name)
			fail_count += 1

	# Instantiate GameState
	var gs_script = load("res://scripts/autoload/game_state.gd")
	if gs_script == null:
		printerr("[FATAL] Could not load game_state.gd")
		quit(1)
		return
	var gs = gs_script.new()
	gs.name = "GameState"
	root.add_child(gs)

	# Instantiate Nakama singleton (mock factory)
	var nakama_script = load("res://addons/com.heroiclabs.nakama/Nakama.gd")
	if nakama_script != null:
		var nakama_singleton = nakama_script.new()
		nakama_singleton.name = "Nakama"
		root.add_child(nakama_singleton)

	# Instantiate NakamaManager
	var mgr_script = load("res://scripts/autoload/nakama_manager.gd")
	if mgr_script == null:
		printerr("[FATAL] Could not load nakama_manager.gd")
		quit(1)
		return
	var mgr = mgr_script.new()
	mgr.name = "NakamaManager"
	mgr.auto_login_on_ready = false
	root.add_child(mgr)

	# =========================================================================
	# Challenge 1: Quest Progress Clamping & Overflow Protection
	# =========================================================================
	print("\n--- Challenge 1: Quest Progress Clamping & Overflow Protection ---")

	# Test 1.1: Single massive increment clamping (0 -> 1,000,000 against target 50)
	mgr.daily_quests = mgr._get_default_daily_quests()
	mgr.record_quest_progress("tap", 1000000)
	var tap_q = mgr.daily_quests["quests"]["daily_tap"]
	assert_check.call(
		tap_q["current"] == 50 and tap_q["is_completed"] == true,
		"Massive progress increment (+1,000,000) strictly clamped to target 50 (current=%d, completed=%s)" % [tap_q["current"], str(tap_q["is_completed"])]
	)

	# Test 1.2: Post-completion immunity (subsequent increments do not change current)
	mgr.record_quest_progress("tap", 50)
	assert_check.call(
		tap_q["current"] == 50 and tap_q["is_completed"] == true,
		"Post-completion progress increment does not exceed target (remains 50)"
	)

	# Test 1.3: Non-matching quests remain untouched
	var up_q = mgr.daily_quests["quests"]["daily_upgrade"]
	var sp_q = mgr.daily_quests["quests"]["daily_spark"]
	assert_check.call(
		up_q["current"] == 0 and not up_q["is_completed"] and sp_q["current"] == 0 and not sp_q["is_completed"],
		"Targeted event ('tap') leaves other quests untouched ('upgrade'=0, 'spark'=0)"
	)

	# Test 1.4: Zero and negative increments safely rejected
	var prev_up_current = up_q["current"]
	mgr.record_quest_progress("upgrade", 0)
	mgr.record_quest_progress("upgrade", -5)
	assert_check.call(
		up_q["current"] == prev_up_current,
		"Zero and negative progress increments rejected without modifying state"
	)

	# Test 1.5: Near-boundary clamping (target 3: current 2 + 10 -> clamped to 3)
	mgr.record_quest_progress("upgrade", 2)
	assert_check.call(up_q["current"] == 2 and not up_q["is_completed"], "Partial progress accumulates correctly (2/3)")
	mgr.record_quest_progress("upgrade", 10)
	assert_check.call(up_q["current"] == 3 and up_q["is_completed"] == true, "Boundary overshoot strictly clamped to target (3/3)")

	# =========================================================================
	# Challenge 2: UTC Date Rollover Reset
	# =========================================================================
	print("\n--- Challenge 2: UTC Date Rollover Reset ---")

	# Test 2.1: Outdated date reset on record_quest_progress
	var yesterday_date = "2026-10-05"
	mgr.daily_quests = mgr._get_default_daily_quests()
	mgr.daily_quests["date"] = yesterday_date
	mgr.daily_quests["quests"]["daily_tap"]["current"] = 50
	mgr.daily_quests["quests"]["daily_tap"]["is_completed"] = true
	mgr.daily_quests["quests"]["daily_tap"]["is_claimed"] = true

	mgr.record_quest_progress("tap", 1)
	var new_date = mgr.daily_quests["date"]
	var new_tap = mgr.daily_quests["quests"]["daily_tap"]
	assert_check.call(
		new_date == mgr.get_current_utc_date() and new_tap["current"] == 1 and not new_tap["is_completed"] and not new_tap["is_claimed"],
		"Outdated date (%s) triggers automatic daily rollover reset (date=%s, tap=1, completed=false, claimed=false)" % [yesterday_date, new_date]
	)

	# Test 2.2: Year-boundary transition simulation
	mgr.daily_quests["date"] = "2025-12-31"
	mgr.record_quest_progress("spark", 1)
	var year_transition_date = mgr.daily_quests["date"]
	var spark_q = mgr.daily_quests["quests"]["daily_spark"]
	assert_check.call(
		year_transition_date == mgr.get_current_utc_date() and spark_q["current"] == 1,
		"Year rollover (2025-12-31 -> current) safely resets schema"
	)

	# Test 2.3: Same-day idempotency (does not reset within same UTC day)
	var pre_spark = spark_q["current"]
	mgr.record_quest_progress("spark", 1)
	assert_check.call(
		spark_q["current"] == pre_spark + 1,
		"Same-day progress updates accumulate without resetting active progress"
	)

	# =========================================================================
	# Challenge 3: Duplicate Claim Prevention & Claim Idempotency
	# =========================================================================
	print("\n--- Challenge 3: Duplicate Claim Prevention & Claim Idempotency ---")

	gs.reset_state()
	gs.bonus_users = 0
	mgr.daily_quests = mgr._get_default_daily_quests()

	# Test 3.1: Incomplete quest claim attempt returns 0
	var uncompleted_claim = await mgr.claim_quest_reward_async("daily_tap")
	assert_check.call(
		uncompleted_claim == 0 and gs.bonus_users == 0,
		"Claiming incomplete quest returns 0 and awards 0 bonus users"
	)

	# Test 3.2: Non-existent quest ID claim returns 0
	var fake_claim = await mgr.claim_quest_reward_async("non_existent_quest_id")
	assert_check.call(
		fake_claim == 0 and gs.bonus_users == 0,
		"Claiming non-existent quest returns 0"
	)

	# Test 3.3: First valid claim of completed quest awards reward bonus users
	mgr.daily_quests["quests"]["daily_tap"]["current"] = 50
	mgr.daily_quests["quests"]["daily_tap"]["is_completed"] = true
	mgr.daily_quests["quests"]["daily_tap"]["is_claimed"] = false

	var first_claim = await mgr.claim_quest_reward_async("daily_tap")
	var is_claimed_flag = mgr.daily_quests["quests"]["daily_tap"]["is_claimed"]
	assert_check.call(
		first_claim == 25 and is_claimed_flag and gs.bonus_users == 25,
		"First claim awards 25 bonus users and sets is_claimed=true (gs.bonus_users=%d)" % gs.bonus_users
	)

	# Test 3.4: Duplicate claim attempt returns 0 and does NOT increment bonus users
	var second_claim = await mgr.claim_quest_reward_async("daily_tap")
	assert_check.call(
		second_claim == 0 and gs.bonus_users == 25,
		"Duplicate claim attempt returns 0 and leaves bonus_users at 25"
	)

	# Test 3.5: Triplicate claim attempt also returns 0
	var third_claim = await mgr.claim_quest_reward_async("daily_tap")
	assert_check.call(
		third_claim == 0 and gs.bonus_users == 25,
		"Triplicate claim attempt safely returns 0"
	)

	# =========================================================================
	# Challenge 4: Bonus User Multiplier Recalculation (+1% passive RPS / user)
	# =========================================================================
	print("\n--- Challenge 4: Bonus User Multiplier Recalculation ---")

	gs.reset_state()
	gs.bonus_users = 0
	gs.base_passive_rps = 100.0

	# Test 4.1: Baseline 0 bonus users -> multiplier 1.0, RPS 100.0
	assert_check.call(
		abs(gs.get_bonus_multiplier() - 1.0) < 0.0001 and abs(gs.get_effective_passive_rps() - 100.0) < 0.001,
		"0 bonus users yields 1.0x multiplier (effective RPS: 100.0)"
	)

	# Test 4.2: 25 bonus users -> multiplier 1.25 (+25%), RPS 125.0
	gs.award_bonus_users(25)
	assert_check.call(
		abs(gs.get_bonus_multiplier() - 1.25) < 0.0001 and abs(gs.get_effective_passive_rps() - 125.0) < 0.001,
		"25 bonus users yields 1.25x multiplier (effective RPS: 125.0)"
	)

	# Test 4.3: 75 additional bonus users (total 100) -> multiplier 2.0 (+100%), RPS 200.0
	gs.award_bonus_users(75)
	assert_check.call(
		gs.bonus_users == 100 and abs(gs.get_bonus_multiplier() - 2.0) < 0.0001 and abs(gs.get_effective_passive_rps() - 200.0) < 0.001,
		"100 bonus users yields 2.00x multiplier (effective RPS: 200.0)"
	)

	# Test 4.4: total_passive_rps property getter matches get_effective_passive_rps()
	assert_check.call(
		abs(gs.total_passive_rps - gs.get_effective_passive_rps()) < 0.0001,
		"total_passive_rps getter matches get_effective_passive_rps() (%f == %f)" % [gs.total_passive_rps, gs.get_effective_passive_rps()]
	)

	# Test 4.5: Passive accumulation in _process uses effective RPS boosted by bonus users
	var pre_accum_energy = gs.energy
	# 10 frames of 0.1s = 1.0s total at 200.0 RPS -> should add 200.0 energy
	for i in range(10):
		gs._process(0.1)
	var actual_gain = gs.energy - pre_accum_energy
	assert_check.call(
		abs(actual_gain - 200.0) < 0.01,
		"Passive accumulation over 1.0s with 100 bonus users gains 200.0 energy (actual: %f)" % actual_gain
	)

	# Test 4.6: Zero and negative awards safely ignored
	gs.award_bonus_users(0)
	gs.award_bonus_users(-50)
	assert_check.call(
		gs.bonus_users == 100,
		"award_bonus_users ignores zero and negative values (remains 100)"
	)

	# =========================================================================
	# Challenge 5: Legacy Savegame Loading & Backward Compatibility
	# =========================================================================
	print("\n--- Challenge 5: Legacy Savegame Loading & Backward Compatibility ---")

	const TEST_SAVE = "user://savegame.json"

	# Test 5.1: Legacy savegame dict without 'bonus_users' key
	var legacy_dict: Dictionary = {
		"version": 1,
		"timestamp": Time.get_unix_time_from_system(),
		"energy": 500.0,
		"total_energy_earned": 500.0,
		"total_clicks": 42,
		"sparks_collected": 5,
		"base_passive_rps": 50.0,
		"base_click_power": 1.0,
		"upgrades": {}
	}
	var f_save = FileAccess.open(TEST_SAVE, FileAccess.WRITE)
	f_save.store_string(JSON.stringify(legacy_dict))
	f_save.close()

	gs.reset_state()
	var legacy_loaded = gs.load_from_disk()
	assert_check.call(
		legacy_loaded and gs.bonus_users == 0 and abs(gs.get_bonus_multiplier() - 1.0) < 0.0001 and abs(gs.get_effective_passive_rps() - 50.0) < 0.001,
		"Legacy savegame lacking 'bonus_users' loads cleanly: bonus_users=0, multiplier=1.0x, RPS=50.0"
	)

	# Test 5.2: Corrupted negative bonus_users in savegame sanitized to 0
	legacy_dict["bonus_users"] = -999
	f_save = FileAccess.open(TEST_SAVE, FileAccess.WRITE)
	f_save.store_string(JSON.stringify(legacy_dict))
	f_save.close()

	gs.reset_state()
	gs.load_from_disk()
	assert_check.call(
		gs.bonus_users == 0,
		"Corrupted negative bonus_users (-999) safely sanitized to 0 via maxi(0, ...)"
	)

	# Test 5.3: Valid bonus_users persisted and reloaded accurately
	gs.bonus_users = 350
	gs.save_to_disk()
	gs.reset_state()
	assert_check.call(gs.bonus_users == 0, "reset_state sets bonus_users to 0 before load")
	gs.load_from_disk()
	assert_check.call(
		gs.bonus_users == 350 and abs(gs.get_bonus_multiplier() - 4.50) < 0.0001,
		"bonus_users=350 persists and reloads correctly with 4.50x multiplier"
	)

	# =========================================================================
	# Challenge 6: Regression Safety Verification for Core Mechanics
	# =========================================================================
	print("\n--- Challenge 6: Regression Safety Verification ---")

	gs.reset_state()
	# Verify Test 4 format_number regression
	assert_check.call(
		gs.format_number(0.0) == "0" and gs.format_number(1500.0) == "1.50 K" and gs.format_number(12500000000.0) == "12.50 B",
		"format_number regression checks match reference model"
	)

	# Verify Test 6 tap_core regression
	var tap_earned = gs.tap_core()
	assert_check.call(
		tap_earned == 1.0 and gs.energy == 1.0 and gs.total_clicks == 1,
		"tap_core regression: rewards 1.0 energy, increments total_clicks"
	)

	# Verify Test 9 geometric cost scaling regression
	gs.energy = 100.0
	var bought_drone = gs.buy_upgrade("tier_1")
	var drone_cost = float(gs.get_upgrade_data("tier_1").get("current_cost", 0.0))
	assert_check.call(
		bought_drone and drone_cost == 29.0 and gs.base_passive_rps == 1.0,
		"buy_upgrade regression: scales cost geometrically to 29.0, sets base_passive_rps=1.0"
	)

	# Verify Test 11 spark windfall regression
	var spark_earned = gs.collect_spark()
	assert_check.call(
		spark_earned == 50.0 and gs.sparks_collected == 1,
		"collect_spark regression: rewards 50.0 windfall at RPS=1.0"
	)

	# Verify Test 15 integrated 75.0 lifecycle simulation regression
	gs.reset_state()
	for i in range(25): gs.tap_core()
	for i in range(5): gs.tap_core()
	gs._process(6.0)
	gs.buy_upgrade("tier_1")
	gs.collect_spark()
	for i in range(600): gs._process(10.0 / 600.0)
	assert_check.call(
		abs(gs.energy - 75.0) < 0.01 and gs.total_clicks == 30 and gs.base_passive_rps == 1.0,
		"Full integrated lifecycle simulation reaches exactly 75.0 energy with 30 clicks, 1 upgrade, 1 spark"
	)

	# Clean up test nodes
	gs.queue_free()
	mgr.queue_free()

	print("\n=====================================================================")
	print("[ADVERSARIAL SUMMARY] Total Checks: %d | Passed: %d | Failed: %d" % [pass_count + fail_count, pass_count, fail_count])
	print("=====================================================================")

	if fail_count > 0:
		print(">>> ADVERSARIAL VERDICT: REQUEST_CHANGES <<<")
		quit(1)
	else:
		print(">>> ADVERSARIAL VERDICT: APPROVE <<<")
		quit(0)
