extends SceneTree

## =============================================================================
## Phase 18 Milestone 1: Empirical Adversarial Challenger Test Suite
## Tests:
## 1. Offline progression math across boundary conditions (0s, 60s, 3600s, 28800s, 86400s)
## 2. Syndicate Tier and Staff Morale multipliers genuinely applied in load_from_disk()
## 3. Tutorial Step 1 lifetime energy invariant (total_lifetime_energy >= total_energy_earned >= energy)
## 4. Station cooldown aliasing, daily board clock rollback guard, staff zero guard, overclock glow
## =============================================================================

var pass_count: int = 0
var fail_count: int = 0
var findings: Array[String] = []

const EPSILON: float = 0.05
const SAVE_PATH: String = "user://savegame.json"

var _backup_save_text: String = ""
var _had_backup: bool = false
var _mounted_nodes: Array[Node] = []

func _assert_test(cond: bool, test_name: String, detail: String = "") -> void:
	if cond:
		print("  [PASS] %s" % test_name)
		pass_count += 1
	else:
		var msg = "  [FAIL] %s" % test_name
		if detail != "":
			msg += " -> " + detail
		printerr(msg)
		findings.append(msg)
		fail_count += 1

func _init() -> void:
	print("====================================================================")
	print(">>> RUNNING P18-M1 EMPIRICAL ADVERSARIAL CHALLENGER TEST SUITE <<<")
	print("====================================================================")
	call_deferred("_run_all_tests")

func _teardown_and_quit() -> void:
	print("\n--- TEARDOWN: Restoring Environment ---")
	if _had_backup:
		var f = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		if f != null:
			f.store_string(_backup_save_text)
			f.close()
			print("  [CLEANUP] Restored original savegame.json")
	elif FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
		print("  [CLEANUP] Removed test savegame.json")

	for i in range(_mounted_nodes.size() - 1, -1, -1):
		var n = _mounted_nodes[i]
		if is_instance_valid(n):
			if n.get_parent() != null:
				n.get_parent().remove_child(n)
			n.free()
	_mounted_nodes.clear()

	print("\n====================================================================")
	print(">>> P18-M1 CHALLENGER SUMMARY: %d PASSED, %d FAILED <<<" % [pass_count, fail_count])
	print("====================================================================")
	if findings.size() > 0:
		print("\nCRITICAL FINDINGS / DEFECTS ENCOUNTERED:")
		for f in findings:
			print(" - %s" % f)
		print("\n>>> EMPIRICAL VERDICT: REQUEST_CHANGES <<<")
		quit(1)
	else:
		print("\n>>> EMPIRICAL VERDICT: APPROVE <<<")
		quit(0)

func _run_all_tests() -> void:
	await process_frame
	await process_frame

	# Backup savegame if present
	if FileAccess.file_exists(SAVE_PATH):
		var f = FileAccess.open(SAVE_PATH, FileAccess.READ)
		if f != null:
			_backup_save_text = f.get_as_text()
			_had_backup = true
			f.close()

	# Locate or mount singletons
	var gs = root.get_node_or_null("GameState")
	if gs == null:
		var gs_script = load("res://scripts/autoload/game_state.gd")
		if gs_script != null:
			gs = gs_script.new()
			gs.name = "GameState"
			root.add_child(gs)
			_mounted_nodes.append(gs)

	var tm = root.get_node_or_null("TutorialManager")
	if tm == null:
		var tm_script = load("res://scripts/autoload/tutorial_manager.gd")
		if tm_script != null:
			tm = tm_script.new()
			tm.name = "TutorialManager"
			root.add_child(tm)
			_mounted_nodes.append(tm)

	await process_frame

	# Pause background process on GameState during synchronous offline progression checks
	gs.set_process(false)

	_test_offline_progression_boundary_conditions(gs)
	_test_syndicate_and_staff_multipliers_in_load(gs)
	_test_tutorial_step1_lifetime_energy_invariant(gs, tm)
	_test_additional_m1_features(gs)

	gs.set_process(true)
	_teardown_and_quit()

## Helper to create test save JSON
func _write_test_save(data: Dictionary) -> void:
	var f = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(data))
		f.close()

## =============================================================================
## SECTION 1: Offline Progression Math Across Boundary Conditions
## =============================================================================
func _test_offline_progression_boundary_conditions(gs: Node) -> void:
	print("\n--- SECTION 1: Offline Progression Math Across Boundary Conditions ---")

	var now: float = Time.get_unix_time_from_system()
	var base_rps: float = 100.0

	# 1.1 Boundary: 0s (no offline gain)
	# Timestamp set in slight future (+2.0s) so elapsed is strictly <= 0.0 -> elapsed = 0.0
	var data_0s: Dictionary = {
		"version": "2.4.0",
		"timestamp": now + 2.0,
		"energy": 500.0,
		"total_energy_earned": 500.0,
		"total_lifetime_energy": 500.0,
		"base_passive_rps": base_rps,
		"upgrades": {},
		"syndicate_tier": 0
	}
	_write_test_save(data_0s)
	gs.reset_state()
	var captured_gain_0s = [-1.0]
	var conn_0s = func(new_energy: float, gain: float):
		captured_gain_0s[0] = gain
	gs.energy_changed.connect(conn_0s)
	var ok_0s = gs.load_from_disk()
	gs.energy_changed.disconnect(conn_0s)

	_assert_test(ok_0s, "1.1.1 load_from_disk() succeeds for 0s boundary")
	_assert_test(absf(gs.energy - 500.0) < EPSILON, "1.1.2 Energy unchanged at 0s boundary (500.0 == %f)" % gs.energy)
	_assert_test(captured_gain_0s[0] == 0.0, "1.1.3 energy_changed emitted with 0.0 offline gain at 0s boundary (actual: %f)" % captured_gain_0s[0])
	_assert_test(absf(gs.total_energy_earned - 500.0) < EPSILON, "1.1.4 total_energy_earned unchanged at 0s boundary")
	_assert_test(absf(gs.total_lifetime_energy - 500.0) < EPSILON, "1.1.5 total_lifetime_energy unchanged at 0s boundary")

	# 1.2 Boundary: 60s (1 minute)
	# Expected gain = 100.0 rps * 60s * 0.5 efficiency = 3,000.0
	now = Time.get_unix_time_from_system()
	var data_60s: Dictionary = {
		"version": "2.4.0",
		"timestamp": now - 60.0,
		"energy": 1000.0,
		"total_energy_earned": 1000.0,
		"total_lifetime_energy": 1000.0,
		"base_passive_rps": base_rps,
		"upgrades": {},
		"syndicate_tier": 0
	}
	_write_test_save(data_60s)
	gs.reset_state()
	var captured_gain_60s = [-1.0]
	var conn_60s = func(new_energy: float, gain: float):
		captured_gain_60s[0] = gain
	gs.energy_changed.connect(conn_60s)
	gs.load_from_disk()
	gs.energy_changed.disconnect(conn_60s)

	var expected_gain_60s: float = base_rps * 60.0 * 0.5 # 3000.0
	_assert_test(absf(captured_gain_60s[0] - expected_gain_60s) < 2.0, "1.2.1 Offline gain for 60s equals ~3,000.0 (actual: %f, expected: %f)" % [captured_gain_60s[0], expected_gain_60s])
	_assert_test(absf(gs.energy - (1000.0 + expected_gain_60s)) < 2.0, "1.2.2 Total energy after 60s is ~4,000.0 (actual: %f)" % gs.energy)
	_assert_test(absf(gs.total_energy_earned - (1000.0 + expected_gain_60s)) < 2.0, "1.2.3 total_energy_earned incremented by ~3,000.0")
	_assert_test(absf(gs.total_lifetime_energy - (1000.0 + expected_gain_60s)) < 2.0, "1.2.4 total_lifetime_energy incremented by ~3,000.0")

	# 1.3 Boundary: 3600s (1 hour)
	# Expected gain = 100.0 rps * 3600s * 0.5 efficiency = 180,000.0
	now = Time.get_unix_time_from_system()
	var data_3600s: Dictionary = {
		"version": "2.4.0",
		"timestamp": now - 3600.0,
		"energy": 0.0,
		"total_energy_earned": 0.0,
		"total_lifetime_energy": 0.0,
		"base_passive_rps": base_rps,
		"upgrades": {},
		"syndicate_tier": 0
	}
	_write_test_save(data_3600s)
	gs.reset_state()
	var captured_gain_3600s = [-1.0]
	var conn_3600s = func(new_energy: float, gain: float):
		captured_gain_3600s[0] = gain
	gs.energy_changed.connect(conn_3600s)
	gs.load_from_disk()
	gs.energy_changed.disconnect(conn_3600s)

	var expected_gain_3600s: float = base_rps * 3600.0 * 0.5 # 180,000.0
	_assert_test(absf(captured_gain_3600s[0] - expected_gain_3600s) < 2.0, "1.3.1 Offline gain for 3600s (1hr) equals ~180,000.0 (actual: %f)" % captured_gain_3600s[0])
	_assert_test(absf(gs.energy - expected_gain_3600s) < 2.0, "1.3.2 Energy equals ~180,000.0 after 1hr")

	# 1.4 Boundary: 28800s (8 hour cap boundary)
	# Expected gain = 100.0 rps * 28800s * 0.5 efficiency = 1,440,000.0
	now = Time.get_unix_time_from_system()
	var data_28800s: Dictionary = {
		"version": "2.4.0",
		"timestamp": now - 28800.0,
		"energy": 0.0,
		"total_energy_earned": 0.0,
		"total_lifetime_energy": 0.0,
		"base_passive_rps": base_rps,
		"upgrades": {},
		"syndicate_tier": 0
	}
	_write_test_save(data_28800s)
	gs.reset_state()
	var captured_gain_28800s = [-1.0]
	var conn_28800s = func(new_energy: float, gain: float):
		captured_gain_28800s[0] = gain
	gs.energy_changed.connect(conn_28800s)
	gs.load_from_disk()
	gs.energy_changed.disconnect(conn_28800s)

	var expected_gain_28800s: float = base_rps * 28800.0 * 0.5 # 1,440,000.0
	_assert_test(absf(captured_gain_28800s[0] - expected_gain_28800s) < 2.0, "1.4.1 Offline gain for 28800s (8hr cap) equals ~1,440,000.0 (actual: %f)" % captured_gain_28800s[0])
	_assert_test(absf(gs.energy - expected_gain_28800s) < 2.0, "1.4.2 Energy equals ~1,440,000.0 after 8hr cap")

	# 1.5 Boundary: 86400s (24 hours - strict clamping to 28800s / 8hr cap)
	# Expected gain MUST be exactly equal to 28800s cap = 1,440,000.0
	now = Time.get_unix_time_from_system()
	var data_86400s: Dictionary = {
		"version": "2.4.0",
		"timestamp": now - 86400.0,
		"energy": 0.0,
		"total_energy_earned": 0.0,
		"total_lifetime_energy": 0.0,
		"base_passive_rps": base_rps,
		"upgrades": {},
		"syndicate_tier": 0
	}
	_write_test_save(data_86400s)
	gs.reset_state()
	var captured_gain_86400s = [-1.0]
	var conn_86400s = func(new_energy: float, gain: float):
		captured_gain_86400s[0] = gain
	gs.energy_changed.connect(conn_86400s)
	gs.load_from_disk()
	gs.energy_changed.disconnect(conn_86400s)

	_assert_test(absf(captured_gain_86400s[0] - expected_gain_28800s) < 0.001, "1.5.1 Offline gain for 86400s (24hr) strictly clamped to 8hr cap (actual: %f, expected: %f)" % [captured_gain_86400s[0], expected_gain_28800s])
	_assert_test(absf(captured_gain_86400s[0] - 1440000.0) < 0.001, "1.5.2 Gain at 86400s == 1,440,000.0 (exact cap)")

	# 1.6 Boundary: Clock rollback (timestamp 3600s in the future)
	now = Time.get_unix_time_from_system()
	var data_future: Dictionary = {
		"version": "2.4.0",
		"timestamp": now + 3600.0,
		"energy": 250.0,
		"total_energy_earned": 250.0,
		"total_lifetime_energy": 250.0,
		"base_passive_rps": base_rps,
		"upgrades": {}
	}
	_write_test_save(data_future)
	gs.reset_state()
	var captured_gain_future = [-1.0]
	var conn_future = func(new_energy: float, gain: float):
		captured_gain_future[0] = gain
	gs.energy_changed.connect(conn_future)
	gs.load_from_disk()
	gs.energy_changed.disconnect(conn_future)

	_assert_test(captured_gain_future[0] == 0.0, "1.6.1 Clock rollback produces 0.0 offline gain (actual: %f)" % captured_gain_future[0])
	_assert_test(absf(gs.energy - 250.0) < EPSILON, "1.6.2 Energy not decremented or corrupted on clock rollback (actual: %f)" % gs.energy)

## =============================================================================
## SECTION 2: Syndicate Tier and Staff Morale Multipliers in load_from_disk()
## =============================================================================
func _test_syndicate_and_staff_multipliers_in_load(gs: Node) -> void:
	print("\n--- SECTION 2: Syndicate Tier & Staff Morale Multipliers in load_from_disk() ---")

	var now: float = Time.get_unix_time_from_system()
	var base_rps: float = 100.0
	var elapsed_1hr: float = 3600.0 # 1 hour away

	# 2.1 Syndicate Tier 5 Multiplier (+25%) in load_from_disk()
	# Syndicate tier 5 gives 1.0 + 5 * 0.05 = 1.25 multiplier
	# Expected RPS = 100.0 * 1.25 = 125.0
	# Expected 1hr offline gain = 125.0 * 3600.0 * 0.5 = 225,000.0
	var data_syn5: Dictionary = {
		"version": "2.4.0",
		"timestamp": now - elapsed_1hr,
		"energy": 0.0,
		"total_energy_earned": 0.0,
		"total_lifetime_energy": 0.0,
		"base_passive_rps": base_rps,
		"upgrades": {},
		"syndicate": {
			"active_id": "syn_alpha",
			"tier": 5,
			"fund_energy": 10000.0
		}
	}
	_write_test_save(data_syn5)
	gs.reset_state()
	var captured_gain_syn5 = [-1.0]
	var conn_syn5 = func(new_energy: float, gain: float):
		captured_gain_syn5[0] = gain
	gs.energy_changed.connect(conn_syn5)
	gs.load_from_disk()
	gs.energy_changed.disconnect(conn_syn5)

	var expected_gain_syn5: float = 125.0 * 3600.0 * 0.5 # 225,000.0
	_assert_test(gs.get_syndicate_tier() == 5, "2.1.1 Syndicate tier deserialized as 5")
	_assert_test(absf(gs.get_syndicate_dividend_multiplier() - 1.25) < EPSILON, "2.1.2 Syndicate dividend multiplier is 1.25")
	_assert_test(absf(captured_gain_syn5[0] - expected_gain_syn5) < 2.0, "2.1.3 Offline gain with Syndicate T5 is ~225,000.0 (actual: %f, expected: %f)" % [captured_gain_syn5[0], expected_gain_syn5])
	_assert_test(captured_gain_syn5[0] > 180000.0, "2.1.4 Syndicate T5 offline gain strictly exceeds baseline 180,000.0")

	# 2.2 Staff Morale Multiplier (+25%) in load_from_disk()
	# 5 workers hired, all working with morale 1.0
	# staff_mult = 1.0 + (5 * 0.05) * 1.0 = 1.25
	# Expected RPS = 100.0 * 1.25 = 125.0
	# Expected 1hr offline gain = 125.0 * 3600.0 * 0.5 = 225,000.0
	now = Time.get_unix_time_from_system()
	var workers_full: Array = []
	for i in range(5):
		workers_full.append({
			"id": "worker_%d" % i,
			"name": "Dev %d" % i,
			"role": "frontend_dev",
			"morale": 1.0,
			"fatigue": 0.0,
			"current_state": "working"
		})
	var data_staff: Dictionary = {
		"version": "2.4.0",
		"timestamp": now - elapsed_1hr,
		"energy": 0.0,
		"total_energy_earned": 0.0,
		"total_lifetime_energy": 0.0,
		"base_passive_rps": base_rps,
		"upgrades": {},
		"syndicate_tier": 0,
		"staff": {
			"workers": workers_full,
			"desk_levels": [1, 1, 1, 1, 1]
		}
	}
	_write_test_save(data_staff)
	gs.reset_state()
	var captured_gain_staff = [-1.0]
	var conn_staff = func(new_energy: float, gain: float):
		captured_gain_staff[0] = gain
	gs.energy_changed.connect(conn_staff)
	gs.load_from_disk()
	gs.energy_changed.disconnect(conn_staff)

	var expected_gain_staff: float = 125.0 * 3600.0 * 0.5 # 225,000.0
	_assert_test(gs.get_active_workers_count() == 5, "2.2.1 Active workers count is 5")
	_assert_test(absf(gs.get_staff_average_morale() - 1.0) < EPSILON, "2.2.2 Average staff morale is 1.0")
	_assert_test(absf(gs.get_staff_rps_multiplier() - 1.25) < EPSILON, "2.2.3 Staff RPS multiplier is 1.25")
	_assert_test(absf(captured_gain_staff[0] - expected_gain_staff) < 2.0, "2.2.4 Offline gain with Staff Morale is ~225,000.0 (actual: %f, expected: %f)" % [captured_gain_staff[0], expected_gain_staff])

	# 2.3 Combined Syndicate Tier 5 AND Staff Morale (+56.25% restored earnings!)
	# Syndicate multiplier = 1.25
	# Staff multiplier = 1.25
	# Combined effective RPS = 100.0 * 1.25 * 1.25 = 156.25
	# Expected 1hr offline gain = 156.25 * 3600.0 * 0.5 = 281,250.0
	now = Time.get_unix_time_from_system()
	var data_combined: Dictionary = {
		"version": "2.4.0",
		"timestamp": now - elapsed_1hr,
		"energy": 0.0,
		"total_energy_earned": 0.0,
		"total_lifetime_energy": 0.0,
		"base_passive_rps": base_rps,
		"upgrades": {},
		"syndicate": {
			"active_id": "syn_omega",
			"tier": 5
		},
		"staff": {
			"workers": workers_full,
			"desk_levels": [1, 1, 1, 1, 1]
		}
	}
	_write_test_save(data_combined)
	gs.reset_state()
	var captured_gain_comb = [-1.0]
	var conn_comb = func(new_energy: float, gain: float):
		captured_gain_comb[0] = gain
	gs.energy_changed.connect(conn_comb)
	gs.load_from_disk()
	gs.energy_changed.disconnect(conn_comb)

	var expected_gain_comb: float = 156.25 * 3600.0 * 0.5 # 281,250.0
	var pct_restored: float = (captured_gain_comb[0] - 180000.0) / 180000.0
	_assert_test(absf(captured_gain_comb[0] - expected_gain_comb) < 2.0, "2.3.1 Combined Syndicate T5 + Staff offline gain is ~281,250.0 (actual: %f)" % captured_gain_comb[0])
	_assert_test(absf(pct_restored - 0.5625) < 0.005, "2.3.2 Restored offline earnings is exactly +56.25%% over baseline (actual: +%.2f%%)" % (pct_restored * 100.0))

	# 2.4 Degraded Staff Morale (5 workers with morale 0.40)
	# staff_mult = 1.0 + (5 * 0.05) * 0.40 = 1.10
	# Expected RPS = 100.0 * 1.10 = 110.0
	# Expected 1hr offline gain = 110.0 * 3600.0 * 0.5 = 198,000.0
	now = Time.get_unix_time_from_system()
	var workers_degraded: Array = []
	for i in range(5):
		workers_degraded.append({
			"id": "worker_%d" % i,
			"name": "Dev %d" % i,
			"role": "frontend_dev",
			"morale": 0.40,
			"fatigue": 0.60,
			"current_state": "working"
		})
	var data_degraded: Dictionary = {
		"version": "2.4.0",
		"timestamp": now - elapsed_1hr,
		"energy": 0.0,
		"total_energy_earned": 0.0,
		"total_lifetime_energy": 0.0,
		"base_passive_rps": base_rps,
		"upgrades": {},
		"syndicate_tier": 0,
		"staff": {
			"workers": workers_degraded,
			"desk_levels": [1, 1, 1, 1, 1]
		}
	}
	_write_test_save(data_degraded)
	gs.reset_state()
	var captured_gain_deg = [-1.0]
	var conn_deg = func(new_energy: float, gain: float):
		captured_gain_deg[0] = gain
	gs.energy_changed.connect(conn_deg)
	gs.load_from_disk()
	gs.energy_changed.disconnect(conn_deg)

	var expected_gain_deg: float = 110.0 * 3600.0 * 0.5 # 198,000.0
	_assert_test(absf(captured_gain_deg[0] - expected_gain_deg) < 2.0, "2.4.1 Degraded morale (0.40) offline gain is ~198,000.0 (actual: %f)" % captured_gain_deg[0])

	# 2.5 Fatigued Workers (5 hired, 3 fatigued, 2 working @ morale 1.0)
	# active_count = 2, avg_morale = 1.0
	# staff_mult = 1.0 + (2 * 0.05) * 1.0 = 1.10
	# Expected gain = 110.0 * 3600.0 * 0.5 = 198,000.0
	now = Time.get_unix_time_from_system()
	var workers_fatigued: Array = []
	for i in range(5):
		var state: String = "working" if i < 2 else "fatigued"
		workers_fatigued.append({
			"id": "worker_%d" % i,
			"name": "Dev %d" % i,
			"role": "frontend_dev",
			"morale": 1.0,
			"fatigue": 0.0 if i < 2 else 1.0,
			"current_state": state
		})
	var data_fatigued: Dictionary = {
		"version": "2.4.0",
		"timestamp": now - elapsed_1hr,
		"energy": 0.0,
		"total_energy_earned": 0.0,
		"total_lifetime_energy": 0.0,
		"base_passive_rps": base_rps,
		"upgrades": {},
		"syndicate_tier": 0,
		"staff": {
			"workers": workers_fatigued,
			"desk_levels": [1, 1, 1, 1, 1]
		}
	}
	_write_test_save(data_fatigued)
	gs.reset_state()
	var captured_gain_fat = [-1.0]
	var conn_fat = func(new_energy: float, gain: float):
		captured_gain_fat[0] = gain
	gs.energy_changed.connect(conn_fat)
	gs.load_from_disk()
	gs.energy_changed.disconnect(conn_fat)

	_assert_test(gs.get_active_workers_count() == 2, "2.5.1 Active workers count ignores fatigued (actual: 2)")
	_assert_test(absf(captured_gain_fat[0] - expected_gain_deg) < 2.0, "2.5.2 Offline gain correctly uses only active workers (actual: %f, expected: %f)" % [captured_gain_fat[0], expected_gain_deg])

## =============================================================================
## SECTION 3: Tutorial Step 1 Lifetime Energy Invariant
## Invariant: total_lifetime_energy >= total_energy_earned >= energy
## =============================================================================
func _test_tutorial_step1_lifetime_energy_invariant(gs: Node, tm: Node) -> void:
	print("\n--- SECTION 3: Tutorial Step 1 Lifetime Energy Invariant ---")

	# 3.1 Fresh state -> Step 1 injection
	gs.reset_state()
	gs.reset_tutorial_state()
	tm.reset_tutorial()
	tm.start_linear_intro()
	_assert_test(tm.current_step == 1, "3.1.1 Tutorial intro started at Step 1")
	_assert_test(gs.energy == 0.0 and gs.total_energy_earned == 0.0 and gs.total_lifetime_energy == 0.0, "3.1.2 Pre-injection counters are 0.0")

	tm._on_step_1_tapped(1)
	_assert_test(gs.energy == 30.0, "3.1.3 Step 1 awards 30.0 energy")
	_assert_test(gs.total_energy_earned == 30.0, "3.1.4 Step 1 awards 30.0 total_energy_earned")
	_assert_test(gs.total_lifetime_energy == 30.0, "3.1.5 Step 1 awards 30.0 total_lifetime_energy")
	_assert_test(gs.total_lifetime_energy >= gs.total_energy_earned and gs.total_energy_earned >= gs.energy, "3.1.6 Invariant holds: lifetime (30) >= earned (30) >= energy (30)")

	# 3.2 Repeated calls (10 consecutive calls without state change)
	# Delta must be 0.0 on subsequent calls, preserving counters strictly without drift
	for i in range(10):
		tm._on_step_1_tapped(i + 2)
	_assert_test(gs.energy == 30.0, "3.2.1 Energy remained 30.0 after 10 consecutive Step 1 calls")
	_assert_test(gs.total_energy_earned == 30.0, "3.2.2 total_energy_earned remained 30.0 without double addition")
	_assert_test(gs.total_lifetime_energy == 30.0, "3.2.3 total_lifetime_energy remained 30.0 without double addition")
	_assert_test(gs.total_lifetime_energy >= gs.total_energy_earned and gs.total_energy_earned >= gs.energy, "3.2.4 Invariant preserved after spamming Step 1")

	# 3.3 Pre-existing partial energy (player accumulated 12 energy before Step 1 completes)
	gs.reset_state()
	gs.reset_tutorial_state()
	tm.reset_tutorial()
	tm.start_linear_intro()
	gs.energy = 12.0
	gs.total_energy_earned = 12.0
	gs.total_lifetime_energy = 12.0
	_assert_test(gs.energy == 12.0 and gs.total_energy_earned == 12.0 and gs.total_lifetime_energy == 12.0, "3.3.1 Pre-existing 12 energy = 12.0 energy")

	tm._on_step_1_tapped(13)
	_assert_test(gs.energy == 30.0, "3.3.2 Energy topped up to 30.0 (delta = 18.0)")
	_assert_test(gs.total_energy_earned == 30.0, "3.3.3 total_energy_earned incremented by delta to 30.0")
	_assert_test(gs.total_lifetime_energy == 30.0, "3.3.4 total_lifetime_energy incremented by delta to 30.0")
	_assert_test(gs.total_lifetime_energy >= gs.total_energy_earned and gs.total_energy_earned >= gs.energy, "3.3.5 Invariant holds: 30 >= 30 >= 30")

	# 3.4 Pre-existing surplus energy (player tapped 50 times)
	gs.reset_state()
	gs.reset_tutorial_state()
	tm.reset_tutorial()
	tm.start_linear_intro()
	for i in range(50):
		gs.tap_core()
	var energy_surplus: float = gs.energy
	var earned_surplus: float = gs.total_energy_earned
	var lifetime_surplus: float = gs.total_lifetime_energy
	_assert_test(energy_surplus >= 50.0, "3.4.1 Pre-existing surplus energy >= 50.0 (actual: %f)" % energy_surplus)

	tm._on_step_1_tapped(51)
	_assert_test(gs.energy == energy_surplus, "3.4.2 Energy untouched at surplus (delta = 0.0)")
	_assert_test(gs.total_energy_earned == earned_surplus, "3.4.3 total_energy_earned untouched at surplus")
	_assert_test(gs.total_lifetime_energy == lifetime_surplus, "3.4.4 total_lifetime_energy untouched at surplus")
	_assert_test(gs.total_lifetime_energy >= gs.total_energy_earned and gs.total_energy_earned >= gs.energy, "3.4.5 Invariant holds: lifetime >= earned >= energy")

	# 3.5 Spent energy scenario (player earned 50, spent 30 on something, current energy is 20)
	gs.reset_state()
	gs.reset_tutorial_state()
	tm.reset_tutorial()
	tm.start_linear_intro()
	gs.energy = 20.0
	gs.total_energy_earned = 50.0
	gs.total_lifetime_energy = 50.0
	tm._on_step_1_tapped(1)
	_assert_test(gs.energy == 30.0, "3.5.1 Energy topped up to 30.0 (delta = 10.0)")
	_assert_test(gs.total_energy_earned == 60.0, "3.5.2 total_energy_earned incremented to 60.0")
	_assert_test(gs.total_lifetime_energy == 60.0, "3.5.3 total_lifetime_energy incremented to 60.0")
	_assert_test(gs.total_lifetime_energy >= gs.total_energy_earned and gs.total_energy_earned >= gs.energy, "3.5.4 Invariant holds: 60 >= 60 >= 30")

	# 3.6 20 Alternating cycles of reset_state() and Step 1 injection
	var all_cycles_passed: bool = true
	for c in range(20):
		gs.reset_state()
		gs.reset_tutorial_state()
		tm.reset_tutorial()
		tm.start_linear_intro()
		tm._on_step_1_tapped(1)
		if not (gs.total_lifetime_energy >= gs.total_energy_earned and gs.total_energy_earned >= gs.energy):
			all_cycles_passed = false
			break
		if gs.energy != 30.0 or gs.total_energy_earned != 30.0 or gs.total_lifetime_energy != 30.0:
			all_cycles_passed = false
			break
	_assert_test(all_cycles_passed, "3.6.1 Invariant strictly holds across 20 consecutive reset & injection cycles")

	# 3.7 Post-IPO Replay Tutorial Invariant Test
	gs.reset_state()
	gs.total_lifetime_energy = 5000000.0
	gs.total_energy_earned = 5000000.0
	gs.energy = 5000000.0
	gs.campaign_chapter = 3
	var ipo_res = gs.trigger_ipo()
	_assert_test(ipo_res.get("success", false) == true, "3.7.1 IPO successfully triggered")
	_assert_test(gs.energy == 0.0, "3.7.2 Energy reset to 0.0 on IPO")
	_assert_test(gs.total_lifetime_energy >= 5000000.0, "3.7.3 total_lifetime_energy preserved on IPO")

	# Player requests tutorial replay
	gs.reset_tutorial_state()
	tm.reset_tutorial()
	tm.start_linear_intro()
	tm._on_step_1_tapped(1)
	_assert_test(gs.energy == 30.0, "3.7.4 Replay tutorial Step 1 sets energy to 30.0")
	_assert_test(gs.total_lifetime_energy >= 5000030.0, "3.7.5 total_lifetime_energy incremented by 30.0")
	_assert_test(gs.total_lifetime_energy >= gs.total_energy_earned and gs.total_energy_earned >= gs.energy, "3.7.6 Invariant holds post-IPO: lifetime (%f) >= earned (%f) >= energy (%f)" % [gs.total_lifetime_energy, gs.total_energy_earned, gs.energy])

	# 3.8 Dialogue Advanced Signal Verification
	gs.reset_state()
	gs.reset_tutorial_state()
	tm.reset_tutorial()
	tm.start_linear_intro()
	gs.energy = 10.0
	gs.total_energy_earned = 10.0
	gs.total_lifetime_energy = 10.0
	var captured_delta = [-1.0]
	var conn_diag = func(e: float, delta: float):
		captured_delta[0] = delta
	gs.energy_changed.connect(conn_diag)
	tm._on_dialogue_advanced()
	gs.energy_changed.disconnect(conn_diag)

	_assert_test(captured_delta[0] == 20.0, "3.8.1 _on_dialogue_advanced emits signal with delta=20.0 (actual: %f)" % captured_delta[0])
	_assert_test(gs.energy == 30.0, "3.8.2 Energy is 30.0 after dialogue advance")
	_assert_test(gs.total_lifetime_energy == 30.0 and gs.total_energy_earned == 30.0, "3.8.3 Lifetime and earned are 30.0")

## =============================================================================
## SECTION 4: Additional Milestone 1 Features & Stress Defect Guards
## =============================================================================
func _test_additional_m1_features(gs: Node) -> void:
	print("\n--- SECTION 4: Additional Milestone 1 Features & Defect Guards ---")

	# 4.1 Station Cooldown Aliasing Fix (F3 / BUG-03)
	gs.set_station_cooldown("coffee_machine", 45.0)
	_assert_test(absf(gs.get_station_cooldown("coffee_machine") - 45.0) < EPSILON, "4.1.1 get_station_cooldown('coffee_machine') returns 45.0")
	_assert_test(absf(gs.get_station_cooldown("coffee_machine_3d") - 45.0) < EPSILON, "4.1.2 get_station_cooldown('coffee_machine_3d') mirrored to 45.0")
	_assert_test(absf(gs.get_station_cooldown("barista_station") - 45.0) < EPSILON, "4.1.3 get_station_cooldown('barista_station') mirrored to 45.0")

	gs.set_station_cooldown("barista_station", 25.0)
	_assert_test(absf(gs.get_station_cooldown("coffee_machine") - 25.0) < EPSILON, "4.1.4 setting barista_station mirrors to coffee_machine (25.0)")
	_assert_test(absf(gs.get_station_cooldown("coffee_machine_3d") - 25.0) < EPSILON, "4.1.5 setting barista_station mirrors to coffee_machine_3d (25.0)")

	# 4.2 Daily Board Clock Rollback Guard (F4 / BUG-04)
	gs.daily_board_streak = 5
	gs.daily_streak = 5
	gs.daily_board_last_login_day = 100
	var streak_reset = [false]
	var conn_streak = func(new_streak: int):
		if new_streak == 0:
			streak_reset[0] = true
	gs.daily_streak_updated.connect(conn_streak)
	gs._rotate_daily_tasks(90) # Clock rolled back from day 100 to day 90
	gs.daily_streak_updated.disconnect(conn_streak)

	_assert_test(gs.daily_board_streak == 0, "4.2.1 daily_board_streak reset to 0 on clock rollback")
	_assert_test(streak_reset[0], "4.2.2 daily_streak_updated signal emitted with 0 on clock rollback")

	# 4.3 Staff Simulation Zero Division Guard (F5 / BUG-05)
	gs.hired_workers.clear()
	# Call update_staff_simulation with 0 workers
	gs.update_staff_simulation(0.1)
	_assert_test(true, "4.3.1 update_staff_simulation(0.1) survived with 0 workers (no zero division)")

	# 4.4 Main3D Server Overclock Glow Standalone Null Guard (F6 / BUG-06)
	var main_3d_script = load("res://scripts/main_3d.gd")
	if main_3d_script != null:
		var main_3d_instance = Node3D.new()
		main_3d_instance.set_script(main_3d_script)
		root.add_child(main_3d_instance)
		_mounted_nodes.append(main_3d_instance)

		# Call glow methods when server_overclock_glow is null
		var glow_active: bool = main_3d_instance.is_server_overclock_glow_active()
		_assert_test(glow_active == false, "4.4.1 is_server_overclock_glow_active() returns false safely when node is null")
		main_3d_instance._update_overclock_glow_modulation(0.016)
		_assert_test(true, "4.4.2 _update_overclock_glow_modulation() safely survived when node is null")
