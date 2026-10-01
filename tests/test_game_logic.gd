extends SceneTree

## Comprehensive Headless Test Harness for IdleArcade (Milestones 1 & 2).
## Executable via: godot --headless --path IdleArcade -s tests/test_game_logic.gd

func _init() -> void:
	print("========================================")
	print("[TEST] IdleArcade Headless Verification")
	print("========================================")
	
	var pass_count: int = 0
	var fail_count: int = 0
	
	# =========================================================================
	# [PRESERVED] Milestone 1 Assertions (Asserts 1 - 10)
	# =========================================================================
	
	# Test 1: Verify SceneTree instantiation
	assert(root != null, "SceneTree root is null.")
	if root != null:
		print("[PASS] SceneTree root exists.")
		pass_count += 1
	else:
		printerr("[FAIL] SceneTree root is null.")
		fail_count += 1
	
	# Test 2: Verify GameState script syntax can be parsed
	var game_state_script = load("res://scripts/autoload/game_state.gd")
	assert(game_state_script != null, "Failed to load res://scripts/autoload/game_state.gd")
	if game_state_script != null:
		print("[PASS] game_state.gd loaded successfully.")
		pass_count += 1
	else:
		printerr("[FAIL] Failed to load res://scripts/autoload/game_state.gd")
		fail_count += 1
		
	# Test 3: Verify main scene can be loaded
	var main_scene = load("res://scenes/main.tscn")
	assert(main_scene != null, "Failed to load res://scenes/main.tscn")
	if main_scene != null:
		print("[PASS] scenes/main.tscn loaded successfully.")
		pass_count += 1
	else:
		printerr("[FAIL] Failed to load res://scenes/main.tscn")
		fail_count += 1
	
	# Test 4: Verify GameState number formatting alignment
	if game_state_script != null:
		var game_state = game_state_script.new()
		assert(game_state != null, "Failed to instantiate GameState.")
		if game_state != null:
			var f_zero: String = game_state.format_number(0.0)
			var f_int: String = game_state.format_number(450.0)
			var f_k: String = game_state.format_number(1500.0)
			var f_m: String = game_state.format_number(5250000.0)
			var f_b: String = game_state.format_number(12500000000.0)
			var f_t: String = game_state.format_number(1000000000000.0)
			
			assert(f_zero == "0", "format_number(0.0) expected '0', got '%s'" % f_zero)
			assert(f_int == "450", "format_number(450.0) expected '450', got '%s'" % f_int)
			assert(f_k == "1.50 K", "format_number(1500.0) expected '1.50 K', got '%s'" % f_k)
			assert(f_m == "5.25 M", "format_number(5250000.0) expected '5.25 M', got '%s'" % f_m)
			assert(f_b == "12.50 B", "format_number(12.5e9) expected '12.50 B', got '%s'" % f_b)
			assert(f_t == "1.00 T", "format_number(1e12) expected '1.00 T', got '%s'" % f_t)
			
			if f_zero == "0" and f_int == "450" and f_k == "1.50 K" and f_m == "5.25 M" and f_b == "12.50 B" and f_t == "1.00 T":
				print("[PASS] GameState format_number conforms to reference model.")
				pass_count += 1
			else:
				printerr("[FAIL] GameState format_number mismatch.")
				fail_count += 1
			game_state.free()
		else:
			printerr("[FAIL] GameState instantiation returned null.")
			fail_count += 1
	else:
		printerr("[FAIL] Cannot run Test 4 because game_state_script is null.")
		fail_count += 1

	# =========================================================================
	# Milestone 2 Mechanics Verification
	# =========================================================================
	
	if game_state_script != null:
		var gs = game_state_script.new()
		
		# Test 5: Verify Initial Economy Baseline (TC-1.2.1)
		if gs.energy == 0.0 and gs.base_passive_rps == 0.0 and gs.base_click_power == 1.0 and gs.total_clicks == 0 and gs.frenzy_meter == 0.0 and not gs.is_frenzy_active:
			print("[PASS] Test 5: Baseline economy starts at 0 energy, 0 rps, 1.0 click power.")
			pass_count += 1
		else:
			printerr("[FAIL] Test 5: Baseline economy values incorrect.")
			fail_count += 1

		# Test 6: Verify Active Core Tapping & Signal Emission (TC-1.3.1, TC-1.4.1)
		var tap_signal_caught: bool = false
		var tap_handler = func(_tot: float, _d: float): tap_signal_caught = true
		gs.energy_changed.connect(tap_handler)
		var tap_earned: float = gs.tap_core()
		gs.energy_changed.disconnect(tap_handler)
		
		if tap_earned == 1.0 and gs.energy == 1.0 and gs.total_clicks == 1 and tap_signal_caught:
			print("[PASS] Test 6: Core tap rewards 1.0 energy and emits energy_changed signal.")
			pass_count += 1
		else:
			printerr("[FAIL] Test 6: Core tap failure: earned=%f, energy=%f" % [tap_earned, gs.energy])
			fail_count += 1

		# Test 7: Verify Frenzy Meter Charging & Overdrive Activation (TC-1.3.2, TC-1.3.3)
		# 9 more taps (total 10 taps) -> meter reaches 40% (4% per tap)
		for i in range(9):
			gs.tap_core()
		var meter_at_10: float = gs.frenzy_meter
		# 15 more taps (total 25 taps) -> meter reaches 100% -> triggers Overdrive (3x multiplier, 6s)
		for i in range(15):
			gs.tap_core()
		
		if meter_at_10 == 40.0 and gs.is_frenzy_active and gs.frenzy_multiplier == 3.0 and gs.frenzy_meter == 0.0:
			print("[PASS] Test 7: Frenzy meter charges (+4%/tap) and triggers 3x Overdrive at 100%.")
			pass_count += 1
		else:
			printerr("[FAIL] Test 7: Frenzy trigger failed: meter10=%f, active=%s, mult=%f" % [meter_at_10, gs.is_frenzy_active, gs.frenzy_multiplier])
			fail_count += 1

		# Test 8: Verify Frenzy Duration Decay via Process Ticks (TC-1.3.4)
		gs._process(3.0)  # Half duration elapsed
		var mid_active: bool = gs.is_frenzy_active
		gs._process(3.1)  # Remainder elapsed
		var end_active: bool = gs.is_frenzy_active
		var end_mult: float = gs.frenzy_multiplier
		
		if mid_active and not end_active and end_mult == 1.0:
			print("[PASS] Test 8: Frenzy duration decays cleanly to 0 and resets multiplier to 1.0x.")
			pass_count += 1
		else:
			printerr("[FAIL] Test 8: Frenzy decay failed: mid=%s, end=%s, mult=%f" % [mid_active, end_active, end_mult])
			fail_count += 1

		# Test 9: Verify Upgrade Catalogue, Affordability & Geometric Cost Scaling (TC-1.2.3, TC-1.2.4, TC-1.2.5, TC-2.1.1, TC-2.1.3)
		# Balance setup: give 40.0 energy
		gs.energy = 40.0
		# Insufficient funds check: tier_2 costs 150.0
		var buy_expensive: bool = gs.buy_upgrade("tier_2")
		# Valid purchase: tier_1 costs 25.0
		var buy_drone: bool = gs.buy_upgrade("tier_1")
		var drone_data: Dictionary = gs.get_upgrade_data("tier_1")
		# Next cost: round(25 * 1.15^1) = 29.0
		var next_cost: float = float(drone_data.get("current_cost", 0.0))
		
		if not buy_expensive and buy_drone and gs.energy == 15.0 and gs.base_passive_rps == 1.0 and next_cost == 29.0:
			print("[PASS] Test 9: Upgrade purchase verifies funds, deducts cost, updates RPS, and scales geometrically.")
			pass_count += 1
		else:
			printerr("[FAIL] Test 9: Upgrade purchase failed: buy_exp=%s, buy_drone=%s, energy=%f, rps=%f, next_cost=%f" % [buy_expensive, buy_drone, gs.energy, gs.base_passive_rps, next_cost])
			fail_count += 1

		# Test 10: Verify Passive Accumulation & Lag Spike Clamping (TC-1.2.2, TC-2.1.5)
		var pre_acc: float = gs.energy
		# 60 frames of 1/60s with RPS = 1.0 should add exactly 1.0 energy
		for i in range(60):
			gs._process(1.0 / 60.0)
		var acc_diff: float = gs.energy - pre_acc
		# Lag spike protection: delta 5.0 clamped to 0.1s -> should add 0.1 * 1.0 = 0.1 energy
		var pre_lag: float = gs.energy
		gs._process(5.0)
		var lag_gain: float = gs.energy - pre_lag
		
		if abs(acc_diff - 1.0) < 0.01 and abs(lag_gain - 0.1) < 0.001:
			print("[PASS] Test 10: Passive generation integrates delta*RPS and clamps lag spikes to 0.1s.")
			pass_count += 1
		else:
			printerr("[FAIL] Test 10: Passive accumulation drift: acc=%f, lag_gain=%f" % [acc_diff, lag_gain])
			fail_count += 1

		# Test 11: Verify Drifting Bonus Spark Windfall (TC-1.3.5)
		# Formula: max(50.0, rps * 25.0). At RPS=1.0, reward is 50.0
		var pre_spark: float = gs.energy
		var spark_reward: float = gs.collect_spark()
		if spark_reward == 50.0 and abs((gs.energy - pre_spark) - 50.0) < 0.001 and gs.sparks_collected == 1:
			print("[PASS] Test 11: Bonus spark collection awards correct lump-sum windfall.")
			pass_count += 1
		else:
			printerr("[FAIL] Test 11: Spark reward mismatch: reward=%f, diff=%f" % [spark_reward, gs.energy - pre_spark])
			fail_count += 1

		# Test 12: Verify Save to Disk & State Serialization (F10)
		const TEST_SAVE_PATH = "user://savegame.json"
		gs.save_to_disk()
		var file_exists: bool = FileAccess.file_exists(TEST_SAVE_PATH)
		var file_valid: bool = false
		if file_exists:
			var f = FileAccess.open(TEST_SAVE_PATH, FileAccess.READ)
			if f != null:
				var parsed = JSON.parse_string(f.get_as_text())
				if parsed is Dictionary and parsed.has("energy") and parsed.has("timestamp") and parsed.has("upgrades"):
					file_valid = true
				f.close()
				
		if file_exists and file_valid:
			print("[PASS] Test 12: save_to_disk() writes valid JSON schema with timestamp and state.")
			pass_count += 1
		else:
			printerr("[FAIL] Test 12: Save file missing or invalid.")
			fail_count += 1

		# Test 13: Verify Offline Catch-Up & System Clock Protections (TC-2.3.4, TC-2.3.5, SCENARIO-4.1)
		# Manually write test save file with timestamp set to 1800s in past, RPS=1.0, energy=75.0
		var now_unix: float = Time.get_unix_time_from_system()
		var f_write = FileAccess.open(TEST_SAVE_PATH, FileAccess.WRITE)
		var mock_save = {
			"timestamp": now_unix - 1800.0,
			"energy": 75.0,
			"total_clicks": 30,
			"base_passive_rps": 1.0,
			"base_click_power": 1.0,
			"sparks_collected": 1,
			"upgrades": {"tier_1": {"level": 1, "current_cost": 29.0}}
		}
		f_write.store_string(JSON.stringify(mock_save))
		f_write.close()
		
		var reload_gs = game_state_script.new()
		var loaded: bool = reload_gs.load_from_disk()
		# Expected: 75.0 + (1.0 * 1800 * 0.5) = 75.0 + 900.0 = 975.0
		var offline_match: bool = abs(reload_gs.energy - 975.0) < 0.1
		
		# Test Clock Future Guard:
		mock_save["timestamp"] = now_unix + 5000.0
		mock_save["energy"] = 100.0
		f_write = FileAccess.open(TEST_SAVE_PATH, FileAccess.WRITE)
		f_write.store_string(JSON.stringify(mock_save))
		f_write.close()
		
		var clock_guard_gs = game_state_script.new()
		clock_guard_gs.load_from_disk()
		var future_guard_pass: bool = (clock_guard_gs.energy == 100.0)
		
		if loaded and offline_match and future_guard_pass:
			print("[PASS] Test 13: Offline progress calculates 50% catch-up and guards against clock rollbacks.")
			pass_count += 1
		else:
			printerr("[FAIL] Test 13: Offline catch-up failed: energy=%f, future_energy=%f" % [reload_gs.energy, clock_guard_gs.energy])
			fail_count += 1
		reload_gs.free()
		clock_guard_gs.free()

		# Test 14: Verify Corrupted / Partial Save Recovery (TC-2.3.1, TC-2.3.2, TC-2.3.3)
		# Write malformed JSON
		var f_corrupt = FileAccess.open(TEST_SAVE_PATH, FileAccess.WRITE)
		f_corrupt.store_string("{ corrupt_json: invalid ... [")
		f_corrupt.close()
		
		var corrupt_gs = game_state_script.new()
		var corrupt_load_result: bool = corrupt_gs.load_from_disk()
		var safe_defaults: bool = (corrupt_gs.energy == 0.0 and corrupt_gs.base_click_power == 1.0)
		
		if not corrupt_load_result and safe_defaults:
			print("[PASS] Test 14: Corrupted save caught gracefully without crashing; defaults retained.")
			pass_count += 1
		else:
			printerr("[FAIL] Test 14: Corrupted save handling failed.")
			fail_count += 1
		corrupt_gs.free()

		# Test 15: Full Integrated Lifecycle Simulation (SCENARIO-4.1 in GDScript)
		var e2e_gs = game_state_script.new()
		for i in range(25): e2e_gs.tap_core()
		for i in range(5): e2e_gs.tap_core()
		e2e_gs._process(6.0) # Frenzy duration elapses, reverting multiplier cleanly to 1.0x
		e2e_gs.buy_upgrade("tier_1")
		e2e_gs.collect_spark()
		for i in range(600): e2e_gs._process(10.0 / 600.0) # 10s idle
		var lifecycle_pre_save: float = e2e_gs.energy # exactly 75.0
		
		if abs(lifecycle_pre_save - 75.0) < 0.01 and e2e_gs.total_clicks == 30 and e2e_gs.base_passive_rps == 1.0:
			print("[PASS] Test 15: Full integrated gameplay lifecycle (30 clicks, 1 upgrade, 1 spark, 10s idle) reaches 75.0 energy.")
			pass_count += 1
		else:
			printerr("[FAIL] Test 15: Lifecycle simulation error: energy=%f, clicks=%d" % [lifecycle_pre_save, e2e_gs.total_clicks])
			fail_count += 1
		e2e_gs.free()

		gs.free()

	print("========================================")
	print("[TEST] Results: %d passed, %d failed" % [pass_count, fail_count])
	print("========================================")
	
	# [PRESERVED] Assertion 11:
	assert(fail_count == 0, "Headless test harness encountered assertion failures.")
	
	if fail_count == 0:
		quit(0)
	else:
		quit(1)
