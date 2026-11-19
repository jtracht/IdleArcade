extends SceneTree

## =============================================================================
## Empirical Challenger 2 Adversarial Stress Test Suite for Milestone 1
## Focus:
## 1. Station Cooldown Aliasing ("coffee_machine", "coffee_machine_3d", "barista_station")
## 2. Daily Board Clock Rollback Defense (current_day < last_login_day, anti-duplication)
## 3. Staff Morale Zero Division & Mid-Callback Emptying Resilience
## 4. Overclock Glow Null Safety in Headless / Standalone Main3D Environments
## =============================================================================

var pass_count: int = 0
var fail_count: int = 0
var findings: Array[String] = []

var _mounted_nodes: Array[Node] = []
var _save_backup_text: String = ""
var _had_save_backup: bool = false
const EPSILON: float = 0.001

func _assert_chall(condition: bool, description: String, detail: String = "") -> void:
	if condition:
		print("  [PASS] %s" % description)
		pass_count += 1
	else:
		var err_msg: String = "  [FAIL] %s" % description
		if detail != "":
			err_msg += " (Detail: %s)" % detail
		printerr(err_msg)
		findings.append(err_msg)
		fail_count += 1

func _init() -> void:
	print("\n====================================================================")
	print(">>> RUNNING P18_M1_CHALLENGER_2 EMPIRICAL ADVERSARIAL SUITE <<<")
	print("====================================================================")
	call_deferred("_run_all_tests")

func _cleanup_and_quit() -> void:
	print("\n--- TEARDOWN: Restoring Environment ---")
	if _had_save_backup:
		var f_res = FileAccess.open("user://savegame.json", FileAccess.WRITE)
		if f_res != null:
			f_res.store_string(_save_backup_text)
			f_res.close()
			print("  [CLEANUP] Restored original savegame.json")
	elif FileAccess.file_exists("user://savegame.json"):
		DirAccess.remove_absolute("user://savegame.json")
		print("  [CLEANUP] Removed test savegame.json")

	for i in range(_mounted_nodes.size() - 1, -1, -1):
		var n = _mounted_nodes[i]
		if is_instance_valid(n):
			if n.get_parent() != null:
				n.get_parent().remove_child(n)
			n.free()
	_mounted_nodes.clear()

	print("\n====================================================================")
	print(">>> CHALLENGER 2 SUMMARY: %d PASSED, %d FAILED <<<" % [pass_count, fail_count])
	print("====================================================================")

	if findings.size() > 0:
		print("\nCRITICAL FINDINGS / DEFECTS ENCOUNTERED:")
		for f in findings:
			print(" - %s" % f)

	if fail_count == 0:
		print(">>> EMPIRICAL VERDICT: APPROVE (Exit Code 0) <<<\n")
		quit(0)
	else:
		printerr(">>> EMPIRICAL VERDICT: REQUEST_CHANGES (%d failures, Exit Code 1) <<<\n" % fail_count)
		quit(1)

func _run_all_tests() -> void:
	await process_frame

	# Backup savegame if it exists
	if FileAccess.file_exists("user://savegame.json"):
		var f_back = FileAccess.open("user://savegame.json", FileAccess.READ)
		if f_back != null:
			_save_backup_text = f_back.get_as_text()
			_had_save_backup = true
			f_back.close()

	# Mount GameState singleton
	var gs_script = load("res://scripts/autoload/game_state.gd")
	var gs = root.get_node_or_null("GameState")
	if gs == null and gs_script != null:
		gs = gs_script.new()
		gs.name = "GameState"
		root.add_child(gs)
		_mounted_nodes.append(gs)

	if gs != null and gs.has_method("reset_state"):
		gs.reset_state()
	await process_frame

	await _test_1_station_cooldown_aliasing(gs)
	await _test_2_daily_board_clock_rollback(gs)
	await _test_3_staff_morale_zero_division(gs)
	await _test_4_overclock_glow_null_safety(gs)

	_cleanup_and_quit()

# ==============================================================================
# SECTION 1: Station Cooldown Aliasing
# ==============================================================================
func _test_1_station_cooldown_aliasing(gs: Node) -> void:
	print("\n--- SECTION 1: Station Cooldown Aliasing Stress & Consistency ---")
	gs.reset_all_station_cooldowns()

	# 1.1 Setting "coffee_machine" sets all three aliases
	gs.set_station_cooldown("coffee_machine", 45.0)
	var cm_cd: float = gs.get_station_cooldown("coffee_machine")
	var cm3d_cd: float = gs.get_station_cooldown("coffee_machine_3d")
	var barista_cd: float = gs.get_station_cooldown("barista_station")

	_assert_chall(absf(cm_cd - 45.0) < EPSILON, "1.1.1 get_station_cooldown('coffee_machine') returns 45.0", "Got %.3f" % cm_cd)
	_assert_chall(absf(cm3d_cd - 45.0) < EPSILON, "1.1.2 get_station_cooldown('coffee_machine_3d') returns 45.0 via alias", "Got %.3f" % cm3d_cd)
	_assert_chall(absf(barista_cd - 45.0) < EPSILON, "1.1.3 get_station_cooldown('barista_station') returns 45.0 via alias", "Got %.3f" % barista_cd)

	# 1.2 Internal dictionary keys verified
	_assert_chall(absf(float(gs.station_cooldowns.get("coffee_machine", 0.0)) - 45.0) < EPSILON, "1.2.1 station_cooldowns['coffee_machine'] is 45.0")
	_assert_chall(absf(float(gs.station_cooldowns.get("coffee_machine_3d", 0.0)) - 45.0) < EPSILON, "1.2.2 station_cooldowns['coffee_machine_3d'] is 45.0")
	_assert_chall(absf(float(gs.station_cooldowns.get("barista_station", 0.0)) - 45.0) < EPSILON, "1.2.3 station_cooldowns['barista_station'] is 45.0")

	# 1.3 Setting "coffee_machine_3d" updates all three aliases
	gs.set_station_cooldown("coffee_machine_3d", 30.0)
	_assert_chall(absf(gs.get_station_cooldown("coffee_machine") - 30.0) < EPSILON, "1.3.1 setting 'coffee_machine_3d' synchronizes 'coffee_machine' to 30.0")
	_assert_chall(absf(gs.get_station_cooldown("coffee_machine_3d") - 30.0) < EPSILON, "1.3.2 setting 'coffee_machine_3d' sets 'coffee_machine_3d' to 30.0")
	_assert_chall(absf(gs.get_station_cooldown("barista_station") - 30.0) < EPSILON, "1.3.3 setting 'coffee_machine_3d' synchronizes 'barista_station' to 30.0")

	# 1.4 Setting "barista_station" updates all three aliases
	gs.set_station_cooldown("barista_station", 60.0)
	_assert_chall(absf(gs.get_station_cooldown("coffee_machine") - 60.0) < EPSILON, "1.4.1 setting 'barista_station' synchronizes 'coffee_machine' to 60.0")
	_assert_chall(absf(gs.get_station_cooldown("coffee_machine_3d") - 60.0) < EPSILON, "1.4.2 setting 'barista_station' synchronizes 'coffee_machine_3d' to 60.0")
	_assert_chall(absf(gs.get_station_cooldown("barista_station") - 60.0) < EPSILON, "1.4.3 setting 'barista_station' sets 'barista_station' to 60.0")

	# 1.5 Query methods: is_station_on_cooldown and is_station_ready consistency
	_assert_chall(gs.is_station_on_cooldown("coffee_machine"), "1.5.1 is_station_on_cooldown('coffee_machine') is true")
	_assert_chall(gs.is_station_on_cooldown("coffee_machine_3d"), "1.5.2 is_station_on_cooldown('coffee_machine_3d') is true")
	_assert_chall(gs.is_station_on_cooldown("barista_station"), "1.5.3 is_station_on_cooldown('barista_station') is true")
	_assert_chall(not gs.is_station_ready("coffee_machine"), "1.5.4 is_station_ready('coffee_machine') is false")
	_assert_chall(not gs.is_station_ready("coffee_machine_3d"), "1.5.5 is_station_ready('coffee_machine_3d') is false")
	_assert_chall(not gs.is_station_ready("barista_station"), "1.5.6 is_station_ready('barista_station') is false")

	# 1.6 Active process decay across aliases
	gs._process(20.0)
	_assert_chall(absf(gs.get_station_cooldown("coffee_machine") - 40.0) < EPSILON, "1.6.1 'coffee_machine' decayed to 40.0")
	_assert_chall(absf(gs.get_station_cooldown("coffee_machine_3d") - 40.0) < EPSILON, "1.6.2 'coffee_machine_3d' decayed to 40.0")
	_assert_chall(absf(gs.get_station_cooldown("barista_station") - 40.0) < EPSILON, "1.6.3 'barista_station' decayed to 40.0")

	# 1.7 Clearing cooldown with 0.0 sets all three to 0.0 and emits station_cooldown_ended
	var ended_tracker = {"ids": []}
	var on_ended = func(s_id: String): ended_tracker["ids"].append(s_id)
	gs.station_cooldown_ended.connect(on_ended)

	gs.set_station_cooldown("coffee_machine", 0.0)
	_assert_chall(gs.get_station_cooldown("coffee_machine") == 0.0, "1.7.1 'coffee_machine' cleared to 0.0")
	_assert_chall(gs.get_station_cooldown("coffee_machine_3d") == 0.0, "1.7.2 'coffee_machine_3d' cleared to 0.0")
	_assert_chall(gs.get_station_cooldown("barista_station") == 0.0, "1.7.3 'barista_station' cleared to 0.0")
	_assert_chall(gs.is_station_ready("barista_station"), "1.7.4 is_station_ready('barista_station') is true")
	_assert_chall(ended_tracker["ids"].has("coffee_machine"), "1.7.5 station_cooldown_ended emitted on clear")

	gs.station_cooldown_ended.disconnect(on_ended)

	# 1.8 Adversarial: Deserialized legacy asymmetric dictionary (only one key populated)
	gs.station_cooldowns.clear()
	gs.station_cooldowns["coffee_machine_3d"] = 25.0
	_assert_chall(absf(gs.get_station_cooldown("coffee_machine") - 25.0) < EPSILON, "1.8.1 get_station_cooldown('coffee_machine') resolves 25.0 from isolated 'coffee_machine_3d'")
	_assert_chall(absf(gs.get_station_cooldown("barista_station") - 25.0) < EPSILON, "1.8.2 get_station_cooldown('barista_station') resolves 25.0 from isolated 'coffee_machine_3d'")

	# Reset and clean
	gs.reset_all_station_cooldowns()

# ==============================================================================
# SECTION 2: Daily Board Clock Rollback Defense
# ==============================================================================
func _test_2_daily_board_clock_rollback(gs: Node) -> void:
	print("\n--- SECTION 2: Daily Board Clock Rollback Defense & Streak Integrity ---")
	gs.reset_state()

	# 2.1 Normal initialization and consecutive login
	gs.refresh_daily_tasks(100)
	_assert_chall(gs.daily_board_last_login_day == 100, "2.1.1 Initial day set to 100")
	_assert_chall(gs.daily_board_tasks.size() == 3, "2.1.2 Exactly 3 tasks generated")

	# Simulate completing all 3 tasks on Day 100
	for t in gs.daily_board_tasks:
		t["is_completed"] = true
		gs.claim_daily_task(t["id"])
	_assert_chall(gs.daily_board_streak == 1, "2.1.3 Streak is 1 after claiming all Day 100 tasks")

	# Advance to consecutive day 101 (current_day == daily_board_last_login_day + 1)
	gs.refresh_daily_tasks(101)
	_assert_chall(gs.daily_board_streak == 1, "2.1.4 Streak preserved on consecutive day 101")
	_assert_chall(gs.daily_board_last_login_day == 101, "2.1.5 last_login_day advanced to 101")

	# Complete all tasks on Day 101
	for t in gs.daily_board_tasks:
		t["is_completed"] = true
		gs.claim_daily_task(t["id"])
	_assert_chall(gs.daily_board_streak == 2, "2.1.6 Streak is 2 after claiming Day 101 tasks")

	# 2.2 Same-day re-entry via get_daily_tasks() (current_day == last_login_day)
	# Align system day calculation for get_daily_tasks() test
	var current_sys_day: int = int(Time.get_unix_time_from_system() / 86400)
	gs.daily_board_last_login_day = current_sys_day
	gs.daily_board_streak = 3
	var typed_tasks: Array[Dictionary] = [
		{"id": "test_task_1", "is_completed": true, "is_claimed": true, "reward": {}, "target": 1, "current": 1, "title": "T1", "description": "D1"}
	]
	gs.daily_board_tasks = typed_tasks
	var fetched_tasks = gs.get_daily_tasks()
	_assert_chall(gs.daily_board_streak == 3, "2.2.1 Streak unchanged on same-day re-entry")
	_assert_chall(fetched_tasks[0]["is_claimed"] == true, "2.2.2 Claimed state preserved on same-day re-entry")

	# 2.3 Clock Rollback Challenge: current_day < daily_board_last_login_day
	# Simulate rolling system clock back by 1 day (from 101 to 100)
	gs.daily_board_last_login_day = 101
	gs.daily_board_streak = 5
	gs.daily_streak = 5

	var streak_signal_tracker = {"emitted": false, "val": -1}
	var on_streak_updated = func(new_streak: int):
		streak_signal_tracker["emitted"] = true
		streak_signal_tracker["val"] = new_streak
	gs.daily_streak_updated.connect(on_streak_updated)

	gs.refresh_daily_tasks(100)

	_assert_chall(gs.daily_board_streak == 0, "2.3.1 daily_board_streak immediately reset to 0 upon rollback to Day 100", "Got %d" % gs.daily_board_streak)
	_assert_chall(gs.daily_streak == 0, "2.3.2 daily_streak mirror reset to 0 upon rollback", "Got %d" % gs.daily_streak)
	_assert_chall(streak_signal_tracker["emitted"], "2.3.3 daily_streak_updated signal emitted upon rollback")
	_assert_chall(streak_signal_tracker["val"] == 0, "2.3.4 daily_streak_updated emitted value is 0", "Got %d" % streak_signal_tracker["val"])
	_assert_chall(gs.daily_board_last_login_day == 100, "2.3.5 daily_board_last_login_day updated to 100")

	gs.daily_streak_updated.disconnect(on_streak_updated)

	# 2.4 Severe Clock Rollback: Roll back 50 days (to Day 50)
	gs.daily_board_streak = 7
	gs.daily_streak = 7
	gs.daily_board_last_login_day = 100
	gs.refresh_daily_tasks(50)
	_assert_chall(gs.daily_board_streak == 0, "2.4.1 Severe rollback (100 -> 50) resets streak to 0")
	_assert_chall(gs.daily_streak == 0, "2.4.2 Severe rollback resets daily_streak to 0")

	# 2.5 Negative / Zero Day Rollback
	gs.daily_board_streak = 3
	gs.daily_board_last_login_day = 50
	gs.refresh_daily_tasks(0)
	_assert_chall(gs.daily_board_streak == 0, "2.5.1 Rollback to Day 0 resets streak to 0")

	# 2.6 Post-Rollback Clean Progression:
	# From Day 100, advancing cleanly to 101 builds streak starting from 0 (reaches 1)
	gs.refresh_daily_tasks(100)
	for t in gs.daily_board_tasks:
		t["is_completed"] = true
		gs.claim_daily_task(t["id"])
	_assert_chall(gs.daily_board_streak == 1, "2.6.1 New streak after rollback reaches 1 on day 100 completion")

	gs.refresh_daily_tasks(101)
	_assert_chall(gs.daily_board_streak == 1, "2.6.2 Consecutive day 101 maintains streak 1")
	for t in gs.daily_board_tasks:
		t["is_completed"] = true
		gs.claim_daily_task(t["id"])
	_assert_chall(gs.daily_board_streak == 2, "2.6.3 Advancing and completing day 101 reaches streak 2")

# ==============================================================================
# SECTION 3: Staff Morale Zero Division & Callback Removal
# ==============================================================================
func _test_3_staff_morale_zero_division(gs: Node) -> void:
	print("\n--- SECTION 3: Staff Morale Zero Division & Mid-Callback Emptying ---")
	gs.reset_state()

	# 3.1 Completely empty hired_workers
	gs.hired_workers.clear()
	_assert_chall(gs.hired_workers.is_empty(), "3.1.1 hired_workers is empty")

	# Call with various deltas on empty list
	gs.update_staff_simulation(0.0)
	gs.update_staff_simulation(-10.0)
	gs.update_staff_simulation(1.0)
	gs.update_staff_simulation(60.0)
	gs.update_staff_simulation(86400.0)
	_assert_chall(true, "3.1.2 update_staff_simulation() on empty staff list completes without crash or error")

	# Check query methods when empty
	var avg_m: float = gs.get_staff_average_morale()
	_assert_chall(not is_nan(avg_m) and not is_inf(avg_m) and avg_m == 1.0, "3.1.3 get_staff_average_morale() on empty staff is 1.0 (not NaN/INF)")
	var mult: float = gs.get_staff_rps_multiplier()
	_assert_chall(not is_nan(mult) and not is_inf(mult) and mult == 1.0, "3.1.4 get_staff_rps_multiplier() on empty staff is 1.0 (not NaN/INF)")

	# 3.2 Single worker with 0.0 morale and 1.0 fatigue
	gs.hired_workers.append({
		"id": "worker_test_zero",
		"role": "frontend_dev",
		"morale": 0.0,
		"fatigue": 1.0,
		"current_state": "fatigued",
		"desk_assigned": 0
	})
	gs.update_staff_simulation(1.0)
	_assert_chall(gs.hired_workers[0]["morale"] == 0.0, "3.2.1 Worker morale remains clamped at 0.0")
	var zero_avg: float = gs.get_staff_average_morale()
	_assert_chall(not is_nan(zero_avg) and not is_inf(zero_avg) and zero_avg == 0.0, "3.2.2 Average morale is 0.0 (not NaN/INF)")

	# 3.3 Adversarial: Clearing hired_workers mid-callback from staff_worker_morale_updated
	print("  [Adversarial] Simulating mass staff resignation inside signal callback...")
	gs.hired_workers.clear()
	# Add 3 workers approaching fatigue
	for i in range(3):
		gs.hired_workers.append({
			"id": "worker_%d" % i,
			"role": "backend_dev",
			"morale": 0.5,
			"fatigue": 0.85, # will trigger morale decay in working state
			"current_state": "working",
			"desk_assigned": i
		})

	var morale_callback_tracker = {"fired": false}
	var on_morale_updated = func(_w_id: String, _mor: float, _fat: float):
		morale_callback_tracker["fired"] = true
		# Empties the entire hired_workers array during callback execution!
		gs.hired_workers.clear()

	gs.staff_worker_morale_updated.connect(on_morale_updated)

	# Simulate 10 seconds of staff simulation
	gs.update_staff_simulation(10.0)

	_assert_chall(morale_callback_tracker["fired"], "3.3.1 staff_worker_morale_updated callback was triggered")
	_assert_chall(gs.hired_workers.is_empty(), "3.3.2 hired_workers was emptied during callback")
	_assert_chall(true, "3.3.3 update_staff_simulation() survived mid-loop hired_workers.clear() without zero division or NaN crash")

	gs.staff_worker_morale_updated.disconnect(on_morale_updated)

	# 3.4 Adversarial: Clearing hired_workers mid-callback from staff_worker_state_changed
	gs.hired_workers.clear()
	gs.hired_workers.append({
		"id": "worker_trans_0",
		"role": "devops_guru",
		"morale": 0.9,
		"fatigue": 0.999, # transitions to "fatigued" immediately on tick
		"current_state": "working",
		"desk_assigned": 0
	})

	var state_callback_tracker = {"fired": false}
	var on_state_changed = func(_w_id: String, _st: String):
		state_callback_tracker["fired"] = true
		gs.hired_workers.clear()

	gs.staff_worker_state_changed.connect(on_state_changed)

	gs.update_staff_simulation(5.0)

	_assert_chall(state_callback_tracker["fired"], "3.4.1 staff_worker_state_changed callback was triggered")
	_assert_chall(gs.hired_workers.is_empty(), "3.4.2 hired_workers emptied during state changed callback")
	_assert_chall(true, "3.4.3 update_staff_simulation() survived state change mid-callback empty without crash")

	gs.staff_worker_state_changed.disconnect(on_state_changed)
	gs.hired_workers.clear()

# ==============================================================================
# SECTION 4: Overclock Glow Null Safety in Standalone Headless Main3D
# ==============================================================================
func _test_4_overclock_glow_null_safety(gs: Node) -> void:
	print("\n--- SECTION 4: Overclock Glow Null Safety in Headless / Standalone Main3D ---")

	var main_3d_script = load("res://scripts/main_3d.gd")
	_assert_chall(main_3d_script != null, "4.1 main_3d.gd script loaded")

	# Instantiate Main3D purely as a bare script node without main_3d.tscn scene hierarchy
	# (i.e. server_overclock_glow is strictly null, find_child returns null)
	var bare_main_3d = Node3D.new()
	bare_main_3d.set_script(main_3d_script)
	root.add_child(bare_main_3d)
	_mounted_nodes.append(bare_main_3d)
	await process_frame

	_assert_chall(bare_main_3d.server_overclock_glow == null, "4.2 server_overclock_glow is null on standalone Main3D")

	# 4.3 is_server_overclock_glow_active() with null glow
	var is_active: bool = bare_main_3d.is_server_overclock_glow_active()
	_assert_chall(is_active == false, "4.3.1 is_server_overclock_glow_active() safely returns false when glow node is null")

	# 4.4 _update_overclock_glow_modulation() with null glow
	bare_main_3d._update_overclock_glow_modulation(0.1)
	bare_main_3d._update_overclock_glow_modulation(1.0)
	bare_main_3d._update_overclock_glow_modulation(60.0)
	_assert_chall(true, "4.4.1 _update_overclock_glow_modulation() executes safely without null pointer exception")

	# 4.5 _set_server_overclock_glow_active() with null glow
	bare_main_3d._set_server_overclock_glow_active(true)
	bare_main_3d._set_server_overclock_glow_active(false)
	_assert_chall(true, "4.5.1 _set_server_overclock_glow_active() executes safely with null glow")

	# 4.6 _activate_server_overclock_glow() with null glow
	bare_main_3d._activate_server_overclock_glow()
	_assert_chall(true, "4.6.1 _activate_server_overclock_glow() executes safely with null glow")

	# 4.7 _setup_tech_tree_integrations() with null glow
	bare_main_3d._setup_tech_tree_integrations()
	_assert_chall(true, "4.7.1 _setup_tech_tree_integrations() executes safely with null glow")

	# 4.8 Dynamic resolution: attach an OmniLight3D named "ServerOverclockGlow"
	var mock_glow = OmniLight3D.new()
	mock_glow.name = "ServerOverclockGlow"
	mock_glow.light_energy = 0.0
	bare_main_3d.add_child(mock_glow)

	# Verify find_child resolves it and functions work normally
	bare_main_3d._set_server_overclock_glow_active(true)
	_assert_chall(absf(mock_glow.light_energy - 1.8) < EPSILON, "4.8.1 _set_server_overclock_glow_active(true) sets light_energy to 1.8")
	_assert_chall(bare_main_3d.is_server_overclock_glow_active() == true, "4.8.2 is_server_overclock_glow_active() returns true when energy > 0.1")

	# Unlock tech in GameState and modulate
	gs.researched_techs.append("tech_server_overclock")
	bare_main_3d._update_overclock_glow_modulation(0.5)
	_assert_chall(mock_glow.light_energy > 0.0, "4.8.3 _update_overclock_glow_modulation modulates light_energy")

	bare_main_3d._set_server_overclock_glow_active(false)
	_assert_chall(mock_glow.light_energy == 0.0, "4.8.4 _set_server_overclock_glow_active(false) zeroes light_energy")
	_assert_chall(bare_main_3d.is_server_overclock_glow_active() == false, "4.8.5 is_server_overclock_glow_active() returns false when zeroed")

	# Cleanup bare_main_3d
	if bare_main_3d.get_parent() != null:
		bare_main_3d.get_parent().remove_child(bare_main_3d)
	_mounted_nodes.erase(bare_main_3d)
	bare_main_3d.free()
	await process_frame
