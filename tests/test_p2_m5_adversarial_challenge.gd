extends SceneTree

## Headless Adversarial Stress & Verification Runner for Milestone P2-M5.
## Validates error recovery, session corruption, device ID regeneration,
## quest rollover & clamping, duplicate reward idempotency, number formatting boundaries,
## and offline catch-up clamping.
##
## Executable via: godot --headless --path IdleArcade -s tests/test_p2_m5_adversarial_challenge.gd

var pass_count: int = 0
var fail_count: int = 0

func _init() -> void:
	print("==========================================================================")
	print("[ADVERSARIAL CHALLENGE] Milestone P2-M5 Headless Stress Runner")
	print("==========================================================================")
	process_frame.connect(_on_first_frame, CONNECT_ONE_SHOT)

func _on_first_frame() -> void:
	await _run_adversarial_suite()
	print("\n==========================================================================")
	print("[ADVERSARIAL CHALLENGE] Results: %d passed, %d failed" % [pass_count, fail_count])
	print("==========================================================================")
	if fail_count == 0:
		print(">>> ALL ADVERSARIAL CHALLENGES PASSED! FINAL VERDICT: APPROVE <<<")
		quit(0)
	else:
		printerr(">>> ADVERSARIAL CHALLENGE FAILED WITH %d DEFECTS! <<<" % fail_count)
		quit(1)

func _assert_test(cond: bool, test_name: String) -> void:
	if cond:
		print("  [PASS] %s" % test_name)
		pass_count += 1
	else:
		printerr("  [FAIL] %s" % test_name)
		fail_count += 1

func _run_adversarial_suite() -> void:
	# -------------------------------------------------------------------------
	# Mount Autoload Singletons
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
		mgr.auto_login_on_ready = false
		root.add_child(mgr)

	await process_frame

	# =========================================================================
	# DOMAIN 1: Number Formatting Model & Boundary Invariants
	# =========================================================================
	print("\n--- DOMAIN 1: GameState.format_number Boundaries & Special Values ---")
	if gs != null:
		_assert_test(gs.format_number(0.0) == "0", "1.1 format_number(0.0) == '0'")
		_assert_test(gs.format_number(-0.0) == "0", "1.2 format_number(-0.0) == '0'")
		_assert_test(gs.format_number(-100.0) == "0", "1.3 format_number(-100.0) == '0'")
		_assert_test(gs.format_number(NAN) == "0", "1.4 format_number(NAN) == '0'")
		_assert_test(gs.format_number(INF) == "0", "1.5 format_number(INF) == '0'")
		_assert_test(gs.format_number(-INF) == "0", "1.6 format_number(-INF) == '0'")
		_assert_test(gs.format_number(1.0) == "1", "1.7 format_number(1.0) == '1'")
		_assert_test(gs.format_number(450.0) == "450", "1.8 format_number(450.0) == '450'")
		_assert_test(gs.format_number(450.5) == "450.5", "1.9 format_number(450.5) == '450.5'")
		_assert_test(gs.format_number(999.0) == "999", "1.10 format_number(999.0) == '999'")
		_assert_test(gs.format_number(1000.0) == "1.00 K", "1.11 format_number(1000.0) == '1.00 K'")
		_assert_test(gs.format_number(1500.0) == "1.50 K", "1.12 format_number(1500.0) == '1.50 K'")
		_assert_test(gs.format_number(999990.0) == "999.99 K", "1.13 format_number(999990.0) == '999.99 K'")
		_assert_test(gs.format_number(1000000.0) == "1.00 M", "1.14 format_number(1000000.0) == '1.00 M'")
		_assert_test(gs.format_number(5250000.0) == "5.25 M", "1.15 format_number(5250000.0) == '5.25 M'")
		_assert_test(gs.format_number(12500000000.0) == "12.50 B", "1.16 format_number(12.50 B) == '12.50 B'")
		_assert_test(gs.format_number(1000000000000.0) == "1.00 T", "1.17 format_number(1.00 T) == '1.00 T'")
		_assert_test(gs.format_number(1e15) == "1.00e+15", "1.18 format_number(1e15) == '1.00e+15'")

	# =========================================================================
	# DOMAIN 2: Offline Progress 50% Efficiency, 8h Cap & Clock Guards
	# =========================================================================
	print("\n--- DOMAIN 2: Offline Progress Clamping & System Clock Guards ---")
	const TEST_SAVE = "user://savegame.json"
	var now_ts: float = Time.get_unix_time_from_system()

	# 2.1 30-min offline catch-up (1800s at 1.0 RPS -> 75 + 900 = 975.0)
	var f_save := FileAccess.open(TEST_SAVE, FileAccess.WRITE)
	f_save.store_string(JSON.stringify({
		"timestamp": now_ts - 1800.0,
		"energy": 75.0,
		"base_passive_rps": 1.0,
		"bonus_users": 0,
		"upgrades": {}
	}))
	f_save.close()

	gs.reset_state()
	gs.load_from_disk()
	_assert_test(abs(gs.energy - 975.0) < 0.1, "2.1 30m offline catch-up: 75.0 + (1.0 * 1800 * 0.5) = 975.0")

	# 2.2 72 hours offline -> capped strictly at 8 hours (28,800s)
	# 8h at 10.0 RPS -> 10.0 * 28800 * 0.5 = 144,000.0 gain + 100 baseline = 144,100.0
	f_save = FileAccess.open(TEST_SAVE, FileAccess.WRITE)
	f_save.store_string(JSON.stringify({
		"timestamp": now_ts - 259200.0, # 72 hours ago
		"energy": 100.0,
		"base_passive_rps": 10.0,
		"bonus_users": 0,
		"upgrades": {}
	}))
	f_save.close()

	gs.reset_state()
	gs.load_from_disk()
	_assert_test(abs(gs.energy - 144100.0) < 1.0, "2.2 72h offline catch-up strictly capped at 8h ceiling (144,100.0 energy)")

	# 2.3 Clock rollback / future timestamp (+5000s) -> 0 offline gain
	f_save = FileAccess.open(TEST_SAVE, FileAccess.WRITE)
	f_save.store_string(JSON.stringify({
		"timestamp": now_ts + 5000.0,
		"energy": 250.0,
		"base_passive_rps": 10.0,
		"bonus_users": 0,
		"upgrades": {}
	}))
	f_save.close()

	gs.reset_state()
	gs.load_from_disk()
	_assert_test(gs.energy == 250.0, "2.3 Future timestamp (clock rollback) awards 0 extra energy (energy remains 250.0)")

	# 2.4 Corrupted JSON save recovery
	f_save = FileAccess.open(TEST_SAVE, FileAccess.WRITE)
	f_save.store_string("{ corrupt: syntax ... [")
	f_save.close()

	gs.reset_state()
	var corrupt_res: bool = gs.load_from_disk()
	_assert_test(corrupt_res == false and gs.energy == 0.0 and gs.base_click_power == 1.0, "2.4 Malformed JSON handled gracefully without crashing; defaults retained")

	# =========================================================================
	# DOMAIN 3: Device-ID Resolution, Corruption Recovery & UUID v4
	# =========================================================================
	print("\n--- DOMAIN 3: Device-ID Resolution, Corruption & UUID v4 Compliance ---")
	if mgr != null:
		const DEV_FILE = "user://device_id.txt"

		# 3.1 Normal generation
		if FileAccess.file_exists(DEV_FILE):
			DirAccess.remove_absolute(DEV_FILE)
		mgr.device_id = ""
		var dev1: String = mgr.get_or_create_device_id()
		_assert_test(dev1.length() >= 6 and dev1.length() <= 128, "3.1 Valid Device ID generated and persisted (length: %d)" % dev1.length())

		# 3.2 Whitespace corruption recovery
		var f_dev := FileAccess.open(DEV_FILE, FileAccess.WRITE)
		f_dev.store_string("   \n\t  ")
		f_dev.close()
		mgr.device_id = ""
		var dev2: String = mgr.get_or_create_device_id()
		_assert_test(dev2.length() >= 6 and dev2 != "   \n\t  ", "3.2 Whitespace-corrupted device_id.txt regenerated cleanly")

		# 3.3 UUID v4 compliance
		var u1: String = mgr.generate_uuid_v4()
		var u2: String = mgr.generate_uuid_v4()
		var is_v4: bool = (u1.length() == 36 and u2.length() == 36 and u1 != u2 and u1[14] == "4" and ["8","9","a","b"].has(u1[19].to_lower()))
		_assert_test(is_v4, "3.3 generate_uuid_v4 generates RFC 4122 v4 compliant UUID: %s" % u1)

	# =========================================================================
	# DOMAIN 4: Session Serialization, Expiration & Disk Corruption
	# =========================================================================
	print("\n--- DOMAIN 4: NakamaSession Serialization & Corruption Recovery ---")
	if mgr != null:
		const SESS_FILE = "user://nakama_session.json"

		# 4.1 Empty file recovery
		var f_s := FileAccess.open(SESS_FILE, FileAccess.WRITE)
		f_s.store_string("")
		f_s.close()
		var s_res1 = mgr._load_cached_session()
		_assert_test(s_res1 == null, "4.1 Empty session file safely returns null")

		# 4.2 Malformed JSON recovery
		f_s = FileAccess.open(SESS_FILE, FileAccess.WRITE)
		f_s.store_string("{ corrupt json payload: [")
		f_s.close()
		var s_res2 = mgr._load_cached_session()
		_assert_test(s_res2 == null, "4.2 Malformed JSON session safely returns null")

		# 4.3 Missing token recovery
		f_s = FileAccess.open(SESS_FILE, FileAccess.WRITE)
		f_s.store_string(JSON.stringify({"user_id": "usr_without_token"}))
		f_s.close()
		var s_res3 = mgr._load_cached_session()
		_assert_test(s_res3 == null, "4.3 Session dictionary without token safely returns null")

		# 4.4 Clean file deletion post-corruption
		_assert_test(not FileAccess.file_exists(SESS_FILE), "4.4 Corrupted session file was automatically purged from disk")

	# =========================================================================
	# DOMAIN 5: Daily Quests Rollover, Progress Clamping & Claim Idempotency
	# =========================================================================
	print("\n--- DOMAIN 5: Daily Quests UTC Rollover, Clamping & Idempotency ---")
	if mgr != null and gs != null:
		gs.reset_state()
		gs.energy = 0.0
		gs.bonus_users = 0
		gs.base_passive_rps = 100.0

		# 5.1 Initialize default quests
		mgr.daily_quests = mgr._get_default_daily_quests()
		var tap_q: Dictionary = mgr.daily_quests["quests"]["daily_tap"]
		_assert_test(tap_q["target"] == 50 and tap_q["reward_bonus_users"] == 25, "5.1 Default daily_tap quest has target=50, reward=25")

		# 5.2 Target overflow clamping (target=50, add 100 -> clamped strictly to 50)
		mgr.record_quest_progress("tap", 100)
		var post_clamp: int = int(mgr.daily_quests["quests"]["daily_tap"]["current"])
		var is_comp: bool = mgr.daily_quests["quests"]["daily_tap"]["is_completed"]
		_assert_test(post_clamp == 50 and is_comp, "5.2 Target overflow: 100 taps on 50-target quest clamped strictly to 50/50, is_completed == true")

		# 5.3 Valid Reward Claiming
		var claimed_amt: int = await mgr.claim_quest_reward_async("daily_tap")
		var is_claimed: bool = mgr.daily_quests["quests"]["daily_tap"]["is_claimed"]
		_assert_test(claimed_amt == 25 and is_claimed and gs.bonus_users == 25, "5.3 Claiming completed quest awards exactly 25 bonus users (GameState.bonus_users: 25)")

		# 5.4 RPS boost recalculation (+25% boost: 100 -> 125 RPS)
		var mult: float = gs.get_bonus_multiplier()
		var eff_rps: float = gs.get_effective_passive_rps()
		_assert_test(abs(mult - 1.25) < 0.001 and abs(eff_rps - 125.0) < 0.01, "5.4 Bonus users amplify passive generation: 1.25x multiplier, effective RPS: 125.0")

		# 5.5 Duplicate claim idempotency
		var dup_claim: int = await mgr.claim_quest_reward_async("daily_tap")
		_assert_test(dup_claim == 0 and gs.bonus_users == 25, "5.5 Duplicate claim returns 0 and does NOT re-award bonus users (Idempotent)")

		# 5.6 Uncompleted quest claim rejection
		var uncomp_claim: int = await mgr.claim_quest_reward_async("daily_upgrade")
		_assert_test(uncomp_claim == 0, "5.6 Claiming uncompleted quest (daily_upgrade) returns 0")

		# 5.7 UTC Date Rollover Detection
		mgr.daily_quests["date"] = "1999-12-31"
		mgr.record_quest_progress("tap", 2)
		var roll_date: String = mgr.daily_quests["date"]
		var roll_curr: int = int(mgr.daily_quests["quests"]["daily_tap"]["current"])
		var roll_comp: bool = mgr.daily_quests["quests"]["daily_tap"]["is_completed"]
		_assert_test(roll_date == mgr.get_current_utc_date() and roll_curr == 2 and not roll_comp, "5.7 UTC day rollover resets quests for today and starts fresh progress (current: 2)")

	# =========================================================================
	# DOMAIN 6: Signal Arity & Callable Safety
	# =========================================================================
	print("\n--- DOMAIN 6: Signal Arity & Callable Safety ---")
	if gs != null:
		var qm_scene = load("res://scenes/ui/quest_modal.tscn")
		if qm_scene != null:
			var qm_inst = qm_scene.instantiate()
			root.add_child(qm_inst)
			await process_frame

			# Trigger 2-argument signal emission
			gs.bonus_users = 50
			gs.bonus_users_changed.emit(50, 25)
			await process_frame

			var lbl: Label = qm_inst.find_child("TotalBonusLabel", true, false)
			_assert_test(lbl != null and lbl.text.contains("+50"), "6.1 QuestModal handles 2-arg bonus_users_changed(50, 25) without callable mismatch crash and displays '+50'")
			qm_inst.queue_free()
			await process_frame

	# =========================================================================
	# DOMAIN 7: Regression Safety (Core Gameplay Mechanics)
	# =========================================================================
	print("\n--- DOMAIN 7: Core Game Logic Regression Verification ---")
	if gs != null:
		gs.reset_state()
		# Tap core
		var tap_res: float = gs.tap_core()
		_assert_test(tap_res == 1.0 and gs.energy == 1.0 and gs.total_clicks == 1, "7.1 Core tap rewards 1.0 energy and updates total_clicks")

		# Spark windfall
		var spark_res: float = gs.collect_spark()
		_assert_test(spark_res == 50.0 and gs.sparks_collected == 1, "7.2 Spark collection awards 50.0 windfall")

		# Upgrades
		gs.energy = 50.0
		var buy_drone: bool = gs.buy_upgrade("tier_1")
		_assert_test(buy_drone and gs.base_passive_rps == 1.0, "7.3 Upgrade purchase updates base_passive_rps to 1.0")

	print("\nAdversarial verification complete.")
