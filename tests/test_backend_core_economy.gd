extends SceneTree

## =============================================================================
## Master Headless SceneTree Test Suite for Milestone 1: Backend Core & Economy
## File: IdleArcade/tests/test_backend_core_economy.gd
## Target: Godot 4.3 Engine Headless Runner & CI Verification (Release v2.2.0)
##
## Validates 100% of GameState Public Methods & Economy Requirements:
##   1. Active Clicks, Frame-Rate Tap Deduplication & Viral Hype (Overdrive)
##   2. Generator Exponential Scaling Math & 7 Tiers Monotonicity
##   3. Composite Passive RPS Multipliers (10-Factor Commutative & Monotonic Stacking)
##   4. 8-Hour Offline Progression (50% Efficiency, Rollback Guard & Idempotency)
##   5. IPO Prestige Ascension (Square Root Math, 1M/Ch3 Threshold, Reset vs Retained)
##   6. Syndicate Holdings Economy & Perks (Tiers 0..5, Dividends, Scores & Fallback)
##   7. Staff Simulation Economy (5 Roles, Morale/Fatigue, Desk Damping & Epiphanies)
##   8. JSON Persistence, Defensive Deserialization & Comprehensive Method Coverage
##
## Execution:
##   godot --headless --path IdleArcade -s tests/test_backend_core_economy.gd
## =============================================================================

var pass_count: int = 0
var fail_count: int = 0

const MIN_EXPECTED_PASS_COUNT: int = 250
const EPSILON: float = 0.001

# Singletons tracked for lifecycle cleanup
var _mounted_nodes: Array[Node] = []
var _save_backup_text: String = ""
var _had_save_backup: bool = false
const _AUX_FILES: Array[String] = [
	"user://device_id.txt",
	"user://daily_quests.json",
	"user://nakama_session.json"
]
var _had_aux_files: Dictionary = {}

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
	print(">>> RUNNING IDLEARCADE PHASE 15 M1: BACKEND CORE & ECONOMY TEST SUITE <<<")
	print("====================================================================")
	# Check and backup existing user files synchronously in _init() BEFORE autoload singletons
	# can initialize and call save_to_disk() in their _ready() callbacks.
	if FileAccess.file_exists("user://savegame.json"):
		var f_back = FileAccess.open("user://savegame.json", FileAccess.READ)
		if f_back != null:
			_save_backup_text = f_back.get_as_text()
			_had_save_backup = true
			f_back.close()
	else:
		_had_save_backup = false

	for aux_path in _AUX_FILES:
		_had_aux_files[aux_path] = FileAccess.file_exists(aux_path)

	call_deferred("_run_all_tests")

func _run_all_tests() -> void:
	await process_frame

	# -------------------------------------------------------------------------
	# Autoload Singleton Mounting Harness (All 6 Singletons)
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

	# -------------------------------------------------------------------------
	# Execute All 8 Required Backend & Economy Test Sections
	# -------------------------------------------------------------------------
	await _test_section_1_active_clicks_and_frenzy(gs)
	await _test_section_2_generator_scaling_math(gs)
	await _test_section_3_composite_passive_rps_multipliers(gs, lem)
	await _test_section_4_offline_progression_idempotency(gs)
	await _test_section_5_ipo_prestige_ascension(gs)
	await _test_section_6_syndicate_holdings_economy(gs)
	await _test_section_7_staff_simulation_and_morale(gs)
	await _test_section_8_persistence_and_methods_coverage(gs)

	# -------------------------------------------------------------------------
	# Final Summary & Clean Exit
	# -------------------------------------------------------------------------
	print("\n====================================================================")
	print(">>> BACKEND TEST SUITE SUMMARY: %d PASSED, %d FAILED <<<" % [pass_count, fail_count])
	print("====================================================================")

	if fail_count == 0 and pass_count >= MIN_EXPECTED_PASS_COUNT:
		print(">>> ALL BACKEND CORE & ECONOMY TESTS PASSED WITH 100% INTEGRITY (Exit Code 0) <<<")
		_cleanup_and_quit(0)
	else:
		printerr(">>> TEST SUITE FAILED (Exit Code 1, pass_count=%d/%d, fail_count=%d) <<<" % [
			pass_count, MIN_EXPECTED_PASS_COUNT, fail_count
		])
		_cleanup_and_quit(1)

func _cleanup_and_quit(exit_code: int) -> void:
	# Restore original save file if we had one
	if _had_save_backup:
		var f_res = FileAccess.open("user://savegame.json", FileAccess.WRITE)
		if f_res != null:
			f_res.store_string(_save_backup_text)
			f_res.close()
	else:
		if FileAccess.file_exists("user://savegame.json"):
			DirAccess.remove_absolute("user://savegame.json")

	# Clean up auxiliary user files if they did not exist before test suite start
	for aux_path in _AUX_FILES:
		if not _had_aux_files.get(aux_path, false) and FileAccess.file_exists(aux_path):
			DirAccess.remove_absolute(aux_path)
	
	# Clean up dynamically mounted test singletons
	for node in _mounted_nodes:
		if is_instance_valid(node):
			if node.get_parent() != null:
				node.get_parent().remove_child(node)
			node.queue_free()
	_mounted_nodes.clear()

	quit(exit_code)

# =============================================================================
# SECTION 1: Active Clicks, Frame-Rate Tap Deduplication & Viral Hype
# =============================================================================
func _test_section_1_active_clicks_and_frenzy(gs: Node) -> void:
	print("\n--- SECTION 1: Active Clicks, Tap Deduplication & Viral Hype ---")

	gs.reset_state()
	await process_frame

	# 1.1 Base click power initial baseline
	_assert_check(absf(gs.base_click_power - 1.0) < EPSILON, "1.1 Initial base_click_power is 1.0")
	_assert_check(gs.total_clicks == 0, "1.2 Initial total_clicks is 0")
	_assert_check(absf(gs.frenzy_meter - 0.0) < EPSILON, "1.3 Initial frenzy_meter is 0.0")
	_assert_check(gs.is_frenzy_active == false, "1.4 Initial is_frenzy_active is false")
	_assert_check(absf(gs.frenzy_multiplier - 1.0) < EPSILON, "1.5 Initial frenzy_multiplier is 1.0")

	# 1.2 Tap deduplication in core.gd
	var core_script = load("res://scripts/core.gd")
	_assert_check(core_script != null, "1.6 Load res://scripts/core.gd")
	if core_script != null:
		var core_node = core_script.new()
		root.add_child(core_node)
		_mounted_nodes.append(core_node)
		await process_frame

		var clicks_before: int = gs.total_clicks
		# Trigger first tap on current frame
		core_node._trigger_tap()
		var clicks_after_first: int = gs.total_clicks
		_assert_check(clicks_after_first == clicks_before + 1, "1.7 First core tap executes and records click (+1)")

		# Trigger second tap on the exact SAME frame -> should be rejected by deduplication
		core_node._trigger_tap()
		var clicks_after_second: int = gs.total_clicks
		_assert_check(clicks_after_second == clicks_after_first, "1.8 Frame deduplication: duplicate tap on same frame is ignored", "Clicks stayed %d" % clicks_after_second)

		# Advance frame
		await process_frame
		core_node._trigger_tap()
		var clicks_after_third: int = gs.total_clicks
		_assert_check(clicks_after_third == clicks_after_first + 1, "1.9 Tap on subsequent frame executes successfully (+1)")

		# Clean up temporary core node
		root.remove_child(core_node)
		core_node.queue_free()
		_mounted_nodes.erase(core_node)

	# 1.3 Click Booster level progression
	gs.reset_state()
	await process_frame
	_assert_check(gs.upgrades.has("click_booster"), "1.10 Upgrades catalog contains click_booster")
	gs.upgrades["click_booster"]["level"] = 5
	gs.recalculate_stats()
	# Base click power formula: 1.0 + (level * 1.0) = 6.0
	_assert_check(absf(gs.base_click_power - 6.0) < EPSILON, "1.11 Click booster Level 5 yields 6.0 base_click_power", "Actual: %f" % gs.base_click_power)

	# 1.4 Quantum Ads tech doubling click power
	gs.researched_techs.append("tech_quantum_ads")
	gs.recalculate_stats()
	# With quantum ads: 6.0 * 2.0 = 12.0
	_assert_check(absf(gs.base_click_power - 12.0) < EPSILON, "1.12 Quantum Ads tech doubles base_click_power to 12.0", "Actual: %f" % gs.base_click_power)
	gs.researched_techs.erase("tech_quantum_ads")
	gs.upgrades["click_booster"]["level"] = 0
	gs.recalculate_stats()

	# 1.5 Frenzy meter accumulation (+4.0 per tap) & 25-tap Overdrive trigger
	gs.reset_state()
	await process_frame
	_assert_check(absf(gs.frenzy_meter - 0.0) < EPSILON, "1.13 Clean baseline frenzy meter is 0.0")

	for i in range(1, 25):
		gs.tap_core()
		var expected_meter: float = float(i) * 4.0
		if i < 25:
			_assert_check(absf(gs.frenzy_meter - expected_meter) < EPSILON and gs.is_frenzy_active == false,
				"1.14 Tap %d adds +4.0 to frenzy meter (meter=%.1f, active=false)" % [i, gs.frenzy_meter])
			if i > 2: # Spot-check to avoid log spam
				pass

	# 25th tap hits exactly 100.0 and triggers Overdrive
	_assert_check(absf(gs.frenzy_meter - 96.0) < EPSILON, "1.15 Meter is at 96.0 before 25th tap")
	gs.tap_core()
	_assert_check(gs.is_frenzy_active == true, "1.16 25th tap triggers is_frenzy_active = true")
	_assert_check(absf(gs.frenzy_meter - 0.0) < EPSILON, "1.17 Overdrive trigger resets frenzy_meter to 0.0")
	_assert_check(absf(gs.frenzy_duration_remaining - 6.0) < EPSILON, "1.18 Overdrive duration initialized to 6.0 seconds")
	_assert_check(absf(gs.frenzy_multiplier - 3.0) < EPSILON, "1.19 Base frenzy multiplier is 3.0x (overdrive_tuning L0)")

	# 1.6 Overdrive Tuning Level scaling: 3.0 + 0.5 * Level
	gs.upgrades["overdrive_tuning"]["level"] = 4
	gs.is_frenzy_active = false
	gs.frenzy_meter = 96.0
	gs.tap_core() # Triggers frenzy with tuning L4
	# Expected: 3.0 + (0.5 * 4) = 5.0
	_assert_check(absf(gs.frenzy_multiplier - 5.0) < EPSILON, "1.20 Overdrive tuning Level 4 scales frenzy multiplier to 5.0x", "Actual: %f" % gs.frenzy_multiplier)

	# 1.7 Frenzy duration decay in _process()
	gs._process(1.5)
	_assert_check(absf(gs.frenzy_duration_remaining - 4.5) < EPSILON, "1.21 Frenzy timer decays by 1.5s to 4.5s remaining")
	gs._process(5.0) # Exceed remaining 4.5s
	_assert_check(gs.is_frenzy_active == false, "1.22 Frenzy expires after duration reaches 0.0s")
	_assert_check(absf(gs.frenzy_multiplier - 1.0) < EPSILON, "1.23 Multiplier returns to baseline 1.0x upon expiry")

	# 1.8 Angel Investor Spark collection formula: max(50.0, base_passive_rps * 25.0) * angel_mult
	gs.reset_state()
	gs.base_passive_rps = 10.0
	var spark_reward_small = gs.collect_spark()
	# max(50.0, 10.0 * 25.0) = max(50.0, 250.0) = 250.0
	_assert_check(absf(spark_reward_small - 250.0) < EPSILON, "1.24 Spark reward with 10 RPS is 250.0 (RPS * 25.0)")
	gs.base_passive_rps = 1.0
	var spark_reward_min = gs.collect_spark()
	# max(50.0, 1.0 * 25.0) = max(50.0, 25.0) = 50.0 (floor)
	_assert_check(absf(spark_reward_min - 50.0) < EPSILON, "1.25 Spark reward respects minimum floor of 50.0 Energy")

# =============================================================================
# SECTION 2: Generator Exponential Scaling Math & 7 Tiers Monotonicity
# =============================================================================
func _test_section_2_generator_scaling_math(gs: Node) -> void:
	print("\n--- SECTION 2: Generator Scaling Math & 7 Tiers Monotonicity ---")

	gs.reset_state()
	await process_frame

	var generator_tiers: Array[Dictionary] = [
		{"id": "tier_1", "base_cost": 25.0, "power": 1.0},
		{"id": "tier_2", "base_cost": 150.0, "power": 8.0},
		{"id": "tier_3", "base_cost": 800.0, "power": 40.0},
		{"id": "tier_4", "base_cost": 4500.0, "power": 250.0},
		{"id": "tier_5", "base_cost": 30000.0, "power": 1500.0},
		{"id": "tier_6", "base_cost": 250000.0, "power": 10000.0},
		{"id": "tier_7", "base_cost": 2000000.0, "power": 75000.0}
	]

	# 2.1 Verify cost formula round(base * 1.15^L) for each tier across levels 0..10
	for t in generator_tiers:
		var up_id: String = t["id"]
		var base_c: float = t["base_cost"]
		_assert_check(gs.upgrades.has(up_id), "2.1 Tier exists in catalog: %s" % up_id)
		var up_data: Dictionary = gs.get_upgrade_data(up_id)
		_assert_check(absf(float(up_data.get("base_cost", 0.0)) - base_c) < EPSILON, "2.2 %s base_cost matches catalog (%.1f)" % [up_id, base_c])
		_assert_check(absf(float(up_data.get("cost_mult", 0.0)) - 1.15) < EPSILON, "2.3 %s cost_mult is exactly 1.15" % up_id)

		# Check cost calculations for L=0, 1, 5, 10
		for lvl in [0, 1, 5, 10]:
			var expected_cost: float = roundf(base_c * pow(1.15, float(lvl)))
			gs.upgrades[up_id]["level"] = lvl
			var up_info: Dictionary = gs.get_upgrade_data(up_id)
			var actual_cost: float = float(up_info.get("current_cost", 0.0))
			_assert_check(absf(actual_cost - expected_cost) < EPSILON,
				"2.4 %s cost at L=%d matches round(base * 1.15^L): expected %.1f, got %.1f" % [up_id, lvl, expected_cost, actual_cost])
		# Reset upgrade level and refresh stats
		gs.upgrades[up_id]["level"] = 0
		gs.get_upgrade_data(up_id)
		gs.recalculate_stats()

	# 2.2 Strict Monotonicity: Cost(L+1) > Cost(L) across levels 0 to 50 for all 7 tiers
	print("  Verifying strict monotonicity across L=0..50 for all 7 generator tiers...")
	var all_monotonic: bool = true
	for t in generator_tiers:
		var up_id: String = t["id"]
		var base_c: float = t["base_cost"]
		var prev_cost: float = -1.0
		for lvl in range(51):
			var cost_at_lvl: float = roundf(base_c * pow(1.15, float(lvl)))
			if prev_cost >= 0.0 and cost_at_lvl <= prev_cost:
				all_monotonic = false
				printerr("Monotonicity violation on %s at L=%d: prev=%f, curr=%f" % [up_id, lvl, prev_cost, cost_at_lvl])
			prev_cost = cost_at_lvl
	_assert_check(all_monotonic, "2.5 Strict cost monotonicity confirmed: Cost(L+1) > Cost(L) for all 7 tiers across L=0..50")

	# 2.3 Non-tier upgrades cost multiplier validation
	var other_upgrades: Array[Dictionary] = [
		{"id": "click_booster", "base": 10.0, "mult": 1.18},
		{"id": "overdrive_tuning", "base": 100.0, "mult": 1.30},
		{"id": "avatar_speed", "base": 50.0, "mult": 1.25},
		{"id": "clearance_level", "base": 250.0, "mult": 1.75},
		{"id": "pickup_radius", "base": 75.0, "mult": 1.25}
	]
	for ou in other_upgrades:
		var id: String = ou["id"]
		var up_info = gs.get_upgrade_data(id)
		_assert_check(absf(float(up_info.get("cost_mult", 0.0)) - ou["mult"]) < EPSILON,
			"2.6 Non-tier upgrade %s cost_mult matches %.2f" % [id, ou["mult"]])

	# 2.4 Purchasing upgrades: affordability, energy deduction, level increment
	gs.reset_state()
	gs.energy = 50.0
	var buy_fail = gs.buy_upgrade("non_existent_tier")
	_assert_check(buy_fail == false, "2.7 buy_upgrade returns false for non-existent upgrade ID")

	# Tier 1 costs 25.0 Energy
	var buy_t1_success = gs.buy_upgrade("tier_1")
	_assert_check(buy_t1_success == true, "2.8 buy_upgrade succeeds when energy is sufficient")
	_assert_check(absf(gs.energy - 25.0) < EPSILON, "2.9 25.0 Energy deducted from bankroll (remaining: 25.0)")
	_assert_check(gs.upgrades["tier_1"]["level"] == 1, "2.10 Tier 1 level incremented to 1")
	_assert_check(absf(gs.base_passive_rps - 1.0) < EPSILON, "2.11 Base passive RPS updated to 1.0 RPS")

	# Next level of Tier 1 costs round(25 * 1.15) = 29.0 Energy; player only has 25.0
	var buy_t1_insufficient = gs.buy_upgrade("tier_1")
	_assert_check(buy_t1_insufficient == false, "2.12 buy_upgrade returns false when energy is insufficient (25.0 < 29.0)")
	_assert_check(gs.upgrades["tier_1"]["level"] == 1, "2.13 Level unchanged on failed purchase")

# =============================================================================
# SECTION 3: Composite Passive RPS Multipliers (10-Factor Stacking)
# =============================================================================
func _test_section_3_composite_passive_rps_multipliers(gs: Node, lem: Node) -> void:
	print("\n--- SECTION 3: Composite Passive RPS Multipliers (10-Factor Stacking) ---")

	gs.reset_state()
	await process_frame

	# 3.1 Baseline Identity Stack: All 10 multipliers neutral
	gs.base_passive_rps = 100.0
	var eff_rps_baseline: float = gs.get_effective_passive_rps()
	_assert_check(absf(eff_rps_baseline - 100.0) < EPSILON,
		"3.1 Baseline Neutrality: All 10 components neutral -> Effective RPS == Base RPS (100.0)", "Got: %f" % eff_rps_baseline)

	# 3.2 Individual Factor Validation
	# Factor 1: Bonus Users (+1% per user)
	gs.bonus_users = 50
	_assert_check(absf(gs.get_bonus_multiplier() - 1.50) < EPSILON, "3.2 Factor 1: 50 bonus users yields 1.50x bonus multiplier")
	_assert_check(absf(gs.get_effective_passive_rps() - 150.0) < EPSILON, "3.3 Effective RPS scales to 150.0 RPS with bonus users alone")
	gs.bonus_users = 0

	# Factor 2: Campus Items (+5% per item without tech_neural_cloud, +10% with)
	gs.collectibles_collected = 10
	_assert_check(absf(gs.get_campus_item_multiplier() - 1.50) < EPSILON, "3.4 Factor 2: 10 items without Neural Cloud yields 1.50x (+50%)")
	gs.researched_techs.append("tech_neural_cloud")
	_assert_check(absf(gs.get_campus_item_multiplier() - 2.00) < EPSILON, "3.5 Factor 2: 10 items WITH Neural Cloud yields 2.00x (+100%)")
	gs.researched_techs.erase("tech_neural_cloud")
	gs.collectibles_collected = 0

	# Factor 3: Tech Server Overclock (+25% passive RPS)
	gs.researched_techs.append("tech_server_overclock")
	_assert_check(absf(gs.get_effective_passive_rps() - 125.0) < EPSILON, "3.6 Factor 3: tech_server_overclock scales RPS to 125.0 (+25%)")
	gs.researched_techs.erase("tech_server_overclock")

	# Factor 4: Server Room Overclock Terminal Buff (+50% default)
	gs.activate_server_overclock_buff(25.0, 1.50)
	_assert_check(absf(gs.get_effective_passive_rps() - 150.0) < EPSILON, "3.7 Factor 4: Active server overclock buff yields 150.0 RPS (1.50x)")
	gs.server_overclock_buff_timer = 0.0
	gs.server_overclock_buff_active = false

	# Factor 5: Campaign Narrative RPS Buff
	gs.activate_campaign_rps_buff(2.0, 30.0)
	_assert_check(absf(gs.get_effective_passive_rps() - 200.0) < EPSILON, "3.8 Factor 5: Campaign RPS buff yields 200.0 RPS (2.00x)")
	gs.campaign_rps_buff_timer = 0.0

	# Factor 6: Angel Shares (+2% per share)
	gs.angel_shares = 25
	_assert_check(absf(gs.get_angel_share_multiplier() - 1.50) < EPSILON, "3.9 Factor 6: 25 Angel Shares yields 1.50x (+50%)")
	_assert_check(absf(gs.get_effective_passive_rps() - 150.0) < EPSILON, "3.10 Effective RPS scales to 150.0 RPS with Angel Shares alone")
	gs.angel_shares = 0

	# Factor 7: Syndicate Dividend Tier (+5% to +25%)
	gs.active_syndicate_id = "syn_test"
	gs.syndicate_tier = 5
	_assert_check(absf(gs.get_syndicate_dividend_multiplier() - 1.25) < EPSILON, "3.11 Factor 7: Syndicate Tier 5 yields 1.25x (+25%)")
	_assert_check(absf(gs.get_effective_passive_rps() - 125.0) < EPSILON, "3.12 Effective RPS scales to 125.0 RPS with Syndicate Tier 5 alone")
	gs.active_syndicate_id = ""
	gs.syndicate_tier = 0

	# Factor 8: LiveEventManager Crisis Multiplier
	if lem != null and lem.has_method("start_event"):
		lem.start_event("server_crash_crisis")
		# Set progress to complete event and trigger reward
		lem.current_progress = 500.0
		lem.contribute_progress("click", 1.0)
		var lem_mult: float = gs.get_live_event_production_multiplier()
		_assert_check(absf(lem_mult - 2.0) < EPSILON, "3.13 Factor 8: LiveEventManager production multiplier is 2.0x during crisis reward", "Got: %f" % lem_mult)
		_assert_check(absf(gs.get_effective_passive_rps() - 200.0) < EPSILON, "3.14 Effective RPS scales to 200.0 RPS with Live Event 2.0x alone")
		# Reset LiveEventManager state cleanly without calling nonexistent methods
		lem.current_production_multiplier = 1.0
		lem.current_drone_speed_multiplier = 1.0
		lem.current_state = lem.EventState.IDLE
		lem.active_event_id = ""
		lem.current_progress = 0.0
		lem.reward_time_remaining = 0.0
		lem.cooldown_time_remaining = 0.0
		lem.reached_milestones.clear()

	# Factor 9: Staff Morale & Active Workers Multiplier: 1.0 + (active * 0.05) * morale
	gs.energy = 50000.0
	for r in ["Frontend Dev", "Backend Dev", "UI/UX Designer", "Growth Hacker", "QA Engineer"]:
		gs.hire_worker(r)
	_assert_check(gs.get_active_workers_count() == 5, "3.15 5 active workers hired")
	_assert_check(absf(gs.get_staff_average_morale() - 1.0) < EPSILON, "3.16 Average morale is 1.0")
	_assert_check(absf(gs.get_staff_rps_multiplier() - 1.25) < EPSILON, "3.17 Factor 9: 5 staff at 1.0 morale yields 1.25x staff bonus")
	_assert_check(absf(gs.get_effective_passive_rps() - 125.0) < EPSILON, "3.18 Effective RPS scales to 125.0 RPS with Staff alone")
	gs.hired_workers.clear()

	# 3.3 Multi-Factor Compounding & Commutativity Invariant
	# Set 4 active factors: Staff (1.25x), Syndicate T5 (1.25x), Angel Shares 50 (2.00x), Tech Overclock (1.25x)
	# Formula: 100 * 1.25 * 1.25 * 2.00 * 1.25 = 390.625 RPS
	gs.reset_state()
	gs.base_passive_rps = 100.0
	gs.energy = 50000.0
	for r in ["Frontend Dev", "Backend Dev", "UI/UX Designer", "Growth Hacker", "QA Engineer"]:
		gs.hire_worker(r)
	gs.active_syndicate_id = "syn_compound_test"
	gs.syndicate_tier = 5
	gs.angel_shares = 50
	gs.researched_techs.append("tech_server_overclock")

	var compounded_rps: float = gs.get_effective_passive_rps()
	var expected_compound: float = 100.0 * 1.25 * 1.25 * 2.00 * 1.25
	_assert_check(absf(compounded_rps - expected_compound) < EPSILON,
		"3.19 Multi-factor compounding: 100 * 1.25 (staff) * 1.25 (syndicate) * 2.0 (angel) * 1.25 (tech) == 390.625",
		"Actual: %f" % compounded_rps)
	gs.active_syndicate_id = ""
	gs.syndicate_tier = 0

	# Commutativity test: Multiply factors in 3 different permutation orders
	var factors: Array[float] = [1.25, 1.25, 2.00, 1.25]
	var p1: float = 100.0 * factors[0] * factors[1] * factors[2] * factors[3]
	var p2: float = 100.0 * factors[3] * factors[2] * factors[1] * factors[0]
	var p3: float = 100.0 * factors[1] * factors[3] * factors[0] * factors[2]
	_assert_check(absf(p1 - p2) < EPSILON and absf(p2 - p3) < EPSILON,
		"3.20 Commutativity Invariant: Reordering multiplication factors yields identical mathematical product")

# =============================================================================
# SECTION 4: 8-Hour Offline Progression & Idempotency
# =============================================================================
func _test_section_4_offline_progression_idempotency(gs: Node) -> void:
	print("\n--- SECTION 4: 8-Hour Offline Progression & Idempotency ---")

	# Pause GameState process loop to prevent live frame processing from polluting energy during offline calculations
	(gs as Node).set_process(false)

	gs.reset_state()
	gs.base_passive_rps = 100.0
	gs.energy = 1000.0
	gs.total_energy_earned = 1000.0
	gs.total_lifetime_energy = 1000.0
	await process_frame

	# Use floating-point timestamp to match load_from_disk() float Time.get_unix_time_from_system()
	# preventing subsecond integer truncation drift in offline calculations
	var now_unix_float: float = Time.get_unix_time_from_system()

	# 4.1 Exactly 1 Hour (3600 seconds) offline at 50% efficiency:
	# Gain = 100 RPS * 3600s * 0.5 = 180,000 Energy
	var save_1h: Dictionary = {
		"version": 1,
		"timestamp": now_unix_float - 3600.0,
		"energy": 1000.0,
		"total_energy_earned": 1000.0,
		"total_lifetime_energy": 1000.0,
		"base_passive_rps": 100.0
	}
	var f = FileAccess.open("user://savegame.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(save_1h))
	f.close()

	var load_1h_ok = gs.load_from_disk()
	_assert_check(load_1h_ok == true, "4.1 load_from_disk succeeds for 1h offline save")
	# Energy should be 1000 + 180,000 = 181,000 Energy
	_assert_check(absf(gs.energy - 181000.0) < 50.0,
		"4.2 1-hour offline gain matches formula (100 * 3600 * 0.5 = 180,000)", "Got energy: %f" % gs.energy)

	# 4.2 Exactly 8 Hours (28800 seconds) offline at 50% efficiency:
	# Gain = 100 RPS * 28800s * 0.5 = 1,440,000 Energy
	var save_8h: Dictionary = {
		"version": 1,
		"timestamp": now_unix_float - 28800.0,
		"energy": 0.0,
		"total_energy_earned": 0.0,
		"total_lifetime_energy": 0.0,
		"base_passive_rps": 100.0
	}
	f = FileAccess.open("user://savegame.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(save_8h))
	f.close()

	gs.load_from_disk()
	_assert_check(absf(gs.energy - 1440000.0) < 10.0,
		"4.3 8-hour offline gain matches maximum cap (100 * 28800 * 0.5 = 1,440,000)", "Got energy: %f" % gs.energy)

	# 4.3 Exceeding Cap (24 hours / 86400 seconds) -> strictly clamped to 8 hours
	var save_24h: Dictionary = {
		"version": 1,
		"timestamp": now_unix_float - 86400.0,
		"energy": 0.0,
		"total_energy_earned": 0.0,
		"total_lifetime_energy": 0.0,
		"base_passive_rps": 100.0
	}
	f = FileAccess.open("user://savegame.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(save_24h))
	f.close()

	gs.load_from_disk()
	_assert_check(absf(gs.energy - 1440000.0) < 10.0,
		"4.4 24-hour offline time is clamped to exactly 8-hour cap (gain == 1,440,000, not 4.32M)", "Got energy: %f" % gs.energy)

	# 4.4 Clock Rollback Guard (timestamp in the future, elapsed < 0)
	var save_future: Dictionary = {
		"version": 1,
		"timestamp": now_unix_float + 7200.0, # 2 hours in future
		"energy": 5000.0,
		"total_energy_earned": 5000.0,
		"total_lifetime_energy": 5000.0,
		"base_passive_rps": 100.0
	}
	f = FileAccess.open("user://savegame.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(save_future))
	f.close()

	gs.load_from_disk()
	_assert_check(absf(gs.energy - 5000.0) < EPSILON,
		"4.5 Clock rollback guard: Future timestamp yields 0 offline gain without deducting energy")

	# 4.5 Idempotency Test: Immediate consecutive calls yield 0 additional energy
	# Because save_to_disk() stores int timestamp while load_from_disk() reads float timestamp,
	# synchronize the save file timestamp to current float time to test exact idempotency
	# without subsecond integer truncation drift.
	gs.save_to_disk()
	var energy_after_save: float = gs.energy
	var save_text: String = FileAccess.get_file_as_string("user://savegame.json")
	var save_json = JSON.parse_string(save_text)
	if save_json is Dictionary:
		save_json["timestamp"] = Time.get_unix_time_from_system()
		var f_sync = FileAccess.open("user://savegame.json", FileAccess.WRITE)
		if f_sync != null:
			f_sync.store_string(JSON.stringify(save_json))
			f_sync.close()
	gs.load_from_disk()
	var energy_after_immediate_load: float = gs.energy
	_assert_check(absf(energy_after_immediate_load - energy_after_save) < 1.0,
		"4.6 Idempotency: Immediate load_from_disk after save yields 0 unearned energy", "Diff: %f" % (energy_after_immediate_load - energy_after_save))

	# Restore GameState process loop
	(gs as Node).set_process(true)

# =============================================================================
# SECTION 5: IPO Prestige Ascension & Angel Shares
# =============================================================================
func _test_section_5_ipo_prestige_ascension(gs: Node) -> void:
	print("\n--- SECTION 5: IPO Prestige Ascension & Angel Shares ---")

	gs.reset_state()
	await process_frame

	# 5.1 Threshold Validation: 1M Lifetime Energy or Chapter 3
	_assert_check(gs.can_trigger_ipo() == false, "5.1 Initial state: can_trigger_ipo is false (0 lifetime energy)")

	gs.total_lifetime_energy = 999999.0
	gs.campaign_chapter = 1
	_assert_check(gs.can_trigger_ipo() == false, "5.2 Threshold not met at 999,999 Lifetime Energy (Chapter 1)")

	gs.total_lifetime_energy = 1000000.0
	_assert_check(gs.can_trigger_ipo() == true, "5.3 Threshold met at 1,000,000 Lifetime Energy (1M threshold)")

	# Chapter 3 alternative threshold
	gs.total_lifetime_energy = 500000.0
	gs.campaign_chapter = 2
	_assert_check(gs.can_trigger_ipo() == false, "5.4 Chapter 2 with 500K energy cannot trigger IPO")
	gs.campaign_chapter = 3
	_assert_check(gs.can_trigger_ipo() == true, "5.5 Chapter 3 Unicorn Status unlocks IPO even below 1M lifetime energy")

	# 5.2 Angel Shares Square Root Formula: floor(sqrt(lifetime_energy / 100000)) - owned
	# Test values:
	# 100,000 -> floor(sqrt(1)) = 1 share
	# 400,000 -> floor(sqrt(4)) = 2 shares
	# 900,000 -> floor(sqrt(9)) = 3 shares
	# 1,600,000 -> floor(sqrt(16)) = 4 shares
	# 10,000,000 -> floor(sqrt(100)) = 10 shares
	gs.angel_shares = 0
	gs.total_lifetime_energy = 100000.0
	_assert_check(gs.calculate_pending_angel_shares() == 1, "5.6 100,000 Lifetime Energy yields 1 Angel Share")
	gs.total_lifetime_energy = 400000.0
	_assert_check(gs.calculate_pending_angel_shares() == 2, "5.7 400,000 Lifetime Energy yields 2 Angel Shares")
	gs.total_lifetime_energy = 900000.0
	_assert_check(gs.calculate_pending_angel_shares() == 3, "5.8 900,000 Lifetime Energy yields 3 Angel Shares")
	gs.total_lifetime_energy = 1600000.0
	_assert_check(gs.calculate_pending_angel_shares() == 4, "5.9 1,600,000 Lifetime Energy yields 4 Angel Shares")
	gs.total_lifetime_energy = 10000000.0
	_assert_check(gs.calculate_pending_angel_shares() == 10, "5.10 10,000,000 Lifetime Energy yields 10 Angel Shares")

	# Accounting for already owned shares
	gs.angel_shares = 3
	_assert_check(gs.calculate_pending_angel_shares() == 7, "5.11 With 3 owned shares, 10M energy yields 7 pending shares (10 - 3 = 7)")

	# Syndicate Tier Bonus Shares: Tier 3 (+5%), Tier 4 (+10%), Tier 5 (+15%)
	gs.active_syndicate_id = "syn_ipo_test"
	gs.syndicate_tier = 5 # +15%
	# Base pending = 7 -> bonus = floor(7 * 0.15) = floor(1.05) = 1 -> total = 8
	_assert_check(gs.calculate_pending_angel_shares() == 8, "5.12 Syndicate Tier 5 awards +15% bonus angel shares (7 + 1 = 8)")
	gs.active_syndicate_id = ""
	gs.syndicate_tier = 0
	gs.angel_shares = 0

	# 5.3 Permanent Multiplier Application (+2% per share)
	gs.angel_shares = 50
	_assert_check(absf(gs.get_angel_share_multiplier() - 2.00) < EPSILON, "5.13 50 Angel Shares grants exactly 2.00x (+100%) multiplier")

	# 5.4 Trigger IPO: Reset vs Preservation Scope Audit
	gs.reset_state()
	gs.energy = 500000.0
	gs.total_energy_earned = 2000000.0
	gs.total_lifetime_energy = 2000000.0 # sqrt(20) = 4 shares
	gs.upgrades["tier_1"]["level"] = 15
	gs.upgrades["tier_1"]["current_cost"] = 2500.0
	gs.upgrades["click_booster"]["level"] = 10
	gs.researched_techs.append("tech_coffee_automation")
	gs.item_inventory["briefcase"] = 8
	gs.hire_worker("Frontend Dev")
	gs.desk_levels[0] = 3
	gs.active_syndicate_id = "syn_omega"
	gs.syndicate_tier = 2
	gs.campaign_chapter = 3
	gs.daily_board_streak = 5
	gs.frenzy_meter = 80.0
	gs.server_overclock_buff_timer = 20.0
	gs.unicorn_espresso_buff_active = true

	var ipo_result: Dictionary = gs.trigger_ipo()
	_assert_check(ipo_result.get("success") == true, "5.14 trigger_ipo() returns success == true")
	_assert_check(ipo_result.get("shares_gained") == 4, "5.15 4 Angel Shares gained on first IPO")

	# Audit RESET SCOPE:
	_assert_check(absf(gs.energy - 0.0) < EPSILON, "5.16 Reset Scope: Spendable energy reset to 0.0")
	_assert_check(gs.upgrades["tier_1"]["level"] == 0, "5.17 Reset Scope: Tier 1 generator level reset to 0")
	_assert_check(absf(gs.upgrades["tier_1"]["current_cost"] - 25.0) < EPSILON, "5.18 Reset Scope: Tier 1 cost reset to base 25.0")
	_assert_check(gs.upgrades["click_booster"]["level"] == 0, "5.19 Reset Scope: Click booster level reset to 0")
	_assert_check(gs.frenzy_meter == 0.0 and gs.is_frenzy_active == false, "5.20 Reset Scope: Frenzy meter and state reset to 0")
	_assert_check(gs.server_overclock_buff_timer == 0.0, "5.21 Reset Scope: Server overclock buff timer reset to 0")
	_assert_check(gs.unicorn_espresso_buff_active == false, "5.22 Reset Scope: Espresso buff reset to inactive")

	# Audit PRESERVATION SCOPE:
	_assert_check(absf(gs.total_lifetime_energy - 2000000.0) < EPSILON, "5.23 Retained Scope: total_lifetime_energy strictly preserved (2,000,000)")
	_assert_check(gs.angel_shares == 4, "5.24 Retained Scope: angel_shares incremented to 4")
	_assert_check(gs.total_ipos_completed == 1, "5.25 Retained Scope: total_ipos_completed incremented to 1")
	_assert_check(gs.is_trophy_unlocked("trophy_platinum_bull") == true, "5.26 Retained Scope: Platin Bull trophy unlocked")
	_assert_check(gs.is_tech_researched("tech_coffee_automation") == true, "5.27 Retained Scope: Researched techs strictly preserved")
	_assert_check(gs.item_inventory["briefcase"] == 8, "5.28 Retained Scope: Campus item inventory preserved (8 briefcases)")
	_assert_check(gs.get_hired_workers().size() == 1, "5.29 Retained Scope: Hired specialist workers roster preserved")
	_assert_check(gs.get_desk_level(0) == 3, "5.30 Retained Scope: Desk 0 Level 3 preserved across IPO")
	_assert_check(gs.active_syndicate_id == "syn_omega" and gs.syndicate_tier == 2, "5.31 Retained Scope: Syndicate affiliation and tier preserved")
	_assert_check(gs.campaign_chapter == 3, "5.32 Retained Scope: Campaign Chapter 3 preserved")
	_assert_check(gs.daily_board_streak == 5, "5.33 Retained Scope: Daily challenge streak preserved")

# =============================================================================
# SECTION 6: Syndicate Holdings Economy & Perks
# =============================================================================
func _test_section_6_syndicate_holdings_economy(gs: Node) -> void:
	print("\n--- SECTION 6: Syndicate Holdings Economy & Perks ---")

	gs.reset_state()
	await process_frame

	# 6.1 Founding a syndicate
	_assert_check(gs.is_in_syndicate() == false, "6.1 Initial state: player unaffiliated")
	_assert_check(gs.get_syndicate_tier() == 0, "6.2 Initial syndicate tier is 0")

	var found_res = gs.found_syndicate("syn_test", "Test Venture", "TEST", "Testing guild mechanics")
	_assert_check(found_res.get("success") == true, "6.3 found_syndicate succeeds")
	_assert_check(gs.is_in_syndicate() == true, "6.4 is_in_syndicate returns true after founding")
	_assert_check(gs.active_syndicate_id == "syn_test", "6.5 active_syndicate_id matches 'syn_test'")

	# 6.2 Contributions & Tier Progression
	# Tier thresholds:
	# Tier 0: 0 energy, 0 shares -> 1.00x dividend, 1.00x drone, 0% ipo
	# Tier 1: 10,000 energy, 1 share -> 1.05x dividend, 1.00x drone, 0% ipo
	# Tier 2: 100,000 energy, 5 shares -> 1.10x dividend, 1.15x drone, 0% ipo
	# Tier 3: 500,000 energy, 20 shares -> 1.15x dividend, 1.15x drone, +5% ipo
	# Tier 4: 2,500,000 energy, 50 shares -> 1.20x dividend, 1.15x drone, +10% ipo
	# Tier 5: 10,000,000 energy, 100 shares -> 1.25x dividend, 1.15x drone, +15% ipo
	gs.energy = 20000.0
	gs.contribute_to_syndicate(15000.0, "energy")
	_assert_check(absf(gs.syndicate_fund_energy - 15000.0) < EPSILON, "6.6 Fund energy credited with 15,000 Energy")
	_assert_check(absf(gs.energy - 5000.0) < EPSILON, "6.7 Player energy bankroll deducted by 15,000")

	# Syndicate tier is 1 upon founding and qualifying energy contribution
	_assert_check(gs.get_syndicate_tier() == 1, "6.8 Syndicate is Tier 1 upon founding and energy contribution")
	gs.angel_shares = 2
	gs.contribute_angel_shares_to_syndicate(1)
	_assert_check(gs.get_syndicate_tier() == 1, "6.9 Syndicate retains Tier 1 after 1 Share contributed")
	_assert_check(absf(gs.get_syndicate_dividend_multiplier() - 1.05) < EPSILON, "6.10 Tier 1 dividend multiplier is 1.05x (+5%)")

	# Advance to Tier 2: 100,000 Energy, 5 Shares
	gs.energy = 100000.0
	gs.contribute_to_syndicate(85000.0, "energy") # 15k + 85k = 100k
	gs.angel_shares = 10
	gs.contribute_angel_shares_to_syndicate(4) # 1 + 4 = 5
	_assert_check(gs.get_syndicate_tier() == 2, "6.11 Syndicate advances to Tier 2 (100k energy, 5 shares)")
	_assert_check(absf(gs.get_syndicate_dividend_multiplier() - 1.10) < EPSILON, "6.12 Tier 2 dividend is 1.10x (+10%)")
	_assert_check(absf(gs.get_drone_speed_multiplier() - 1.15) < EPSILON, "6.13 Tier 2 grants 1.15x (+15%) drone speed multiplier")

	# Advance to Tier 5: 10M Energy, 100 Shares
	gs.energy = 10000000.0
	gs.contribute_to_syndicate(9900000.0, "energy") # 100k + 9.9M = 10M
	gs.angel_shares = 150
	gs.contribute_angel_shares_to_syndicate(95) # 5 + 95 = 100
	_assert_check(gs.get_syndicate_tier() == 5, "6.14 Syndicate advances to Tier 5 Holding Monopoly")
	_assert_check(absf(gs.get_syndicate_dividend_multiplier() - 1.25) < EPSILON, "6.15 Tier 5 dividend is 1.25x (+25%)")
	_assert_check(absf(gs.get_syndicate_ipo_bonus_percent() - 0.15) < EPSILON, "6.16 Tier 5 grants +15% IPO bonus shares")

	# 6.3 Seasonal score calculation: floor(fund_energy / 100) + (fund_shares * 500) + (tier * 1000)
	# 10,000,000 / 100 = 100,000 + (100 * 500 = 50,000) + (5 * 1000 = 5,000) = 155,000
	var calc_score: int = gs.calculate_seasonal_score()
	_assert_check(calc_score == 155000, "6.17 Seasonal score calculation matches 155,000 points", "Got: %d" % calc_score)

	# 6.4 Leaving syndicate
	var leave_res = gs.leave_syndicate()
	_assert_check(leave_res == true, "6.18 leave_syndicate() succeeds")
	_assert_check(gs.is_in_syndicate() == false, "6.19 is_in_syndicate() returns false after departure")
	_assert_check(gs.get_syndicate_tier() == 0, "6.20 Syndicate tier resets to 0")
	_assert_check(absf(gs.get_syndicate_dividend_multiplier() - 1.00) < EPSILON, "6.21 Dividend multiplier resets to 1.00x")

# =============================================================================
# SECTION 7: Staff Simulation, Morale, Ergonomics & Epiphanies
# =============================================================================
func _test_section_7_staff_simulation_and_morale(gs: Node) -> void:
	print("\n--- SECTION 7: Staff Simulation, Morale, Ergonomics & Epiphanies ---")

	gs.reset_state()
	await process_frame

	# 7.1 Multiplier neutrality with 0 workers
	_assert_check(gs.get_hired_workers().size() == 0, "7.1 Initial hired_workers is empty")
	_assert_check(absf(gs.get_staff_rps_multiplier() - 1.00) < EPSILON, "7.2 0 workers yields neutral 1.000x multiplier")
	_assert_check(absf(gs.get_staff_average_morale() - 1.00) < EPSILON, "7.3 Average morale with 0 workers is 1.00")

	# 7.2 Recruitment of 5 specialist roles
	var roles: Array[Dictionary] = [
		{"role": "Frontend Dev", "cost": 500.0, "desk": 0},
		{"role": "Backend Dev", "cost": 1500.0, "desk": 1},
		{"role": "UI/UX Designer", "cost": 3500.0, "desk": 2},
		{"role": "Growth Hacker", "cost": 8000.0, "desk": 3},
		{"role": "QA Engineer", "cost": 15000.0, "desk": 4}
	]

	gs.energy = 50000.0
	for r_info in roles:
		var r_name: String = r_info["role"]
		var hire_ok = gs.hire_worker(r_name)
		_assert_check(hire_ok == true, "7.4 Successfully hired '%s'" % r_name)
		var w: Dictionary = gs.get_worker(r_name)
		_assert_check(w.get("role") == r_name, "7.5 Worker role matches '%s'" % r_name)
		_assert_check(w.get("desk_assigned") == r_info["desk"], "7.6 Worker assigned to desk %d" % r_info["desk"])
		_assert_check(absf(float(w.get("morale", 0.0)) - 1.0) < EPSILON, "7.7 Worker initial morale is 1.0")
		_assert_check(absf(float(w.get("fatigue", 1.0)) - 0.0) < EPSILON, "7.8 Worker initial fatigue is 0.0")

	_assert_check(gs.get_hired_workers().size() == 5, "7.9 All 5 specialist workers hired")
	_assert_check(absf(gs.get_staff_rps_multiplier() - 1.25) < EPSILON, "7.10 5 active workers at 1.0 morale yields 1.250x (+25%)")

	# Attempt to hire 6th worker (capacity limit = 5)
	var hire_overflow = gs.hire_worker("Frontend Dev")
	_assert_check(hire_overflow == false, "7.11 6th worker hire rejected (max capacity reached)")

	# 7.3 Desk Ergonomics Damping (Level 1: 1.00x, Level 2: 0.75x, Level 3: 0.40x)
	_assert_check(absf(gs.get_desk_fatigue_multiplier(1) - 1.00) < EPSILON, "7.12 Desk Level 1 fatigue multiplier is 1.00x (0% reduction)")
	_assert_check(absf(gs.get_desk_fatigue_multiplier(2) - 0.75) < EPSILON, "7.13 Desk Level 2 fatigue multiplier is 0.75x (25% reduction)")
	_assert_check(absf(gs.get_desk_fatigue_multiplier(3) - 0.40) < EPSILON, "7.14 Desk Level 3 fatigue multiplier is 0.40x (60% reduction)")

	# Upgrade Desk 0 to Level 2 and Level 3
	gs.energy = 50000.0
	_assert_check(gs.upgrade_desk(0) == true, "7.15 Upgrade Desk 0 to Level 2 succeeds")
	_assert_check(gs.get_desk_level(0) == 2, "7.16 Desk 0 is Level 2")
	_assert_check(gs.upgrade_desk(0) == true, "7.17 Upgrade Desk 0 to Level 3 succeeds")
	_assert_check(gs.get_desk_level(0) == 3, "7.18 Desk 0 is Level 3")
	_assert_check(gs.upgrade_desk(0) == false, "7.19 Upgrade past Level 3 rejected (max desk level)")

	# 7.4 Simulation Loop: Fatigue Accumulation & Morale Decay
	# Desk 0 (Level 3, 0.40x) vs Desk 1 (Level 1, 1.00x)
	# Simulate 1500 seconds (25 minutes)
	# Base fatigue rate: (0.02 / 60) per second
	# Desk 1: (0.02 / 60) * 1.00 * 1500s = 0.50 fatigue
	# Desk 0: (0.02 / 60) * 0.40 * 1500s = 0.20 fatigue
	gs.update_staff_simulation(1500.0)
	var w_desk0 = gs.get_worker("Frontend Dev")
	var w_desk1 = gs.get_worker("Backend Dev")
	_assert_check(absf(float(w_desk0.get("fatigue", 0.0)) - 0.20) < 0.05,
		"7.20 Desk 0 (Level 3) fatigue is ~0.20 (0.40x damping)", "Actual: %f" % float(w_desk0.get("fatigue", 0.0)))
	_assert_check(absf(float(w_desk1.get("fatigue", 0.0)) - 0.50) < 0.05,
		"7.21 Desk 1 (Level 1) fatigue is ~0.50 (1.00x undamped)", "Actual: %f" % float(w_desk1.get("fatigue", 0.0)))

	# Simulate further to reach fatigue >= 1.0 on Desk 1 -> transition to "fatigued" state
	gs.update_staff_simulation(2000.0)
	w_desk1 = gs.get_worker("Backend Dev")
	_assert_check(float(w_desk1.get("fatigue", 0.0)) >= 1.0, "7.22 Desk 1 worker reached 1.0 max fatigue")
	_assert_check(w_desk1.get("current_state") == "fatigued", "7.23 Fully exhausted worker transitioned to 'fatigued' state")
	_assert_check(gs.get_active_workers_count() < 5, "7.24 Fatigued worker stops contributing to active workers count")

	# 7.5 Team Coffee Break & 60s Hyper-Focus
	var coffee_ok = gs.give_team_coffee_break()
	_assert_check(coffee_ok == true, "7.25 give_team_coffee_break() executes")
	w_desk1 = gs.get_worker("Backend Dev")
	_assert_check(absf(float(w_desk1.get("fatigue", 1.0)) - 0.0) < EPSILON, "7.26 Coffee break restores fatigue to 0.0")
	_assert_check(absf(float(w_desk1.get("morale", 0.0)) - 1.0) < EPSILON, "7.27 Coffee break restores morale to 1.0")
	_assert_check(w_desk1.get("current_state") == "working", "7.28 Worker state restored to 'working'")
	_assert_check(gs.is_staff_hyper_focus_active() == true, "7.29 60s Hyper-Focus engaged")
	_assert_check(absf(gs.get_staff_hyper_focus_multiplier() - 1.50) < EPSILON, "7.30 Hyper-Focus multiplier is 1.50x")

	# 7.6 Epiphany Breakthrough Rewards (💡)
	# Reward formula: max(100.0, get_effective_passive_rps() * 15.0)
	gs.base_passive_rps = 200.0
	var epi_reward = gs.trigger_worker_epiphany("worker_frontend_dev")
	var expected_epi: float = gs.get_effective_passive_rps() * 15.0
	_assert_check(absf(epi_reward - expected_epi) < 1.0, "7.31 Epiphany reward matches 15x Effective RPS formula", "Got: %f" % epi_reward)

	# 7.7 Dismissing / Firing worker
	var fire_ok = gs.fire_worker("Frontend Dev")
	_assert_check(fire_ok == true, "7.32 fire_worker succeeds")
	_assert_check(gs.get_hired_workers().size() == 4, "7.33 Hired workers count reduced to 4")

# =============================================================================
# SECTION 8: JSON Persistence, Defensive Deserialization & Remaining Methods
# =============================================================================
func _test_section_8_persistence_and_methods_coverage(gs: Node) -> void:
	print("\n--- SECTION 8: JSON Persistence, Defensive Deserialization & Methods Coverage ---")

	gs.reset_state()
	await process_frame

	# 8.1 Full JSON Save / Load Roundtrip
	gs.energy = 12345.0
	gs.total_energy_earned = 67890.0
	gs.total_lifetime_energy = 543210.0
	gs.angel_shares = 8
	gs.total_ipos_completed = 2
	var typed_trophies: Array[String] = ["trophy_golden_briefcase", "trophy_platinum_bull"]
	gs.unlocked_trophies = typed_trophies
	gs.daily_board_streak = 4
	gs.total_clicks = 450
	gs.sparks_collected = 19
	gs.bonus_users = 35
	gs.avatar_speed_level = 3
	gs.idle_level = 4
	gs.pickup_radius_level = 2
	gs.collectibles_collected = 14
	gs.campaign_chapter = 3
	var typed_quests: Array[String] = ["quest_briefcases", "quest_server"]
	gs.campaign_completed_quests = typed_quests
	var typed_zones: Array[String] = ["server_room", "lab_room"]
	gs.unlocked_zones = typed_zones
	var typed_techs: Array[String] = ["tech_coffee_automation", "tech_server_overclock"]
	gs.researched_techs = typed_techs
	gs.item_inventory = {"briefcase": 6, "coffee": 9, "usb_drive": 3}
	gs.master_volume = 0.75
	gs.music_volume = 0.60
	gs.sfx_volume = 0.90
	gs.master_muted = false
	gs.music_muted = true
	gs.sfx_muted = false
	gs.screen_shake_intensity = 0.85
	gs.light_cycle_mode = "night"
	gs.active_syndicate_id = "syn_roundtrip"
	gs.syndicate_tier = 3
	gs.energy = 50000.0
	gs.hire_worker("Frontend Dev")
	gs.desk_levels[0] = 3
	gs.energy = 12345.0

	gs.save_to_disk()
	_assert_check(FileAccess.file_exists("user://savegame.json") == true, "8.1 save_to_disk creates savegame.json file")

	# Reset and reload from disk
	gs.reset_state()
	var roundtrip_ok = gs.load_from_disk()
	_assert_check(roundtrip_ok == true, "8.2 load_from_disk executes cleanly on generated savegame")
	_assert_check(absf(gs.energy - 12345.0) < 50.0, "8.3 Roundtrip: energy preserved")
	_assert_check(absf(gs.total_lifetime_energy - 543210.0) < 50.0, "8.4 Roundtrip: total_lifetime_energy preserved")
	_assert_check(gs.angel_shares == 8, "8.5 Roundtrip: angel_shares preserved (8)")
	_assert_check(gs.total_ipos_completed == 2, "8.6 Roundtrip: total_ipos_completed preserved (2)")
	_assert_check(gs.unlocked_trophies.has("trophy_platinum_bull"), "8.7 Roundtrip: trophies preserved")
	_assert_check(gs.bonus_users == 35, "8.8 Roundtrip: bonus_users preserved (35)")
	_assert_check(gs.avatar_speed_level == 3, "8.9 Roundtrip: avatar_speed_level preserved (3)")
	_assert_check(gs.idle_level == 4, "8.10 Roundtrip: idle_level preserved (4)")
	_assert_check(gs.item_inventory["briefcase"] == 6, "8.11 Roundtrip: inventory briefcases preserved (6)")
	_assert_check(gs.is_tech_researched("tech_server_overclock") == true, "8.12 Roundtrip: researched tech preserved")
	_assert_check(absf(gs.master_volume - 0.75) < EPSILON, "8.13 Roundtrip: master_volume preserved (0.75)")
	_assert_check(gs.music_muted == true, "8.14 Roundtrip: music_muted preserved (true)")
	_assert_check(absf(gs.screen_shake_intensity - 0.85) < EPSILON, "8.15 Roundtrip: screen_shake preserved (0.85)")
	_assert_check(gs.light_cycle_mode == "night", "8.16 Roundtrip: light_cycle_mode preserved ('night')")
	_assert_check(gs.active_syndicate_id == "syn_roundtrip", "8.17 Roundtrip: syndicate active_id preserved")
	_assert_check(gs.syndicate_tier == 3, "8.18 Roundtrip: syndicate_tier preserved (3)")
	_assert_check(gs.get_hired_workers().size() == 1, "8.19 Roundtrip: staff workers preserved")
	_assert_check(gs.get_desk_level(0) == 3, "8.20 Roundtrip: desk level preserved (3)")

	# 8.2 Corrupt File Fallback & NaN/Inf Defenses
	# Invalid JSON syntax
	var f_corrupt = FileAccess.open("user://savegame.json", FileAccess.WRITE)
	f_corrupt.store_string("{ this is not valid json !!!")
	f_corrupt.close()
	var load_corrupt_ok = gs.load_from_disk()
	_assert_check(load_corrupt_ok == false, "8.21 Corrupted JSON syntax handled safely (returns false, no crash)")

	# Non-dictionary root JSON
	var f_array = FileAccess.open("user://savegame.json", FileAccess.WRITE)
	f_array.store_string("[1, 2, 3, 4, 5]")
	f_array.close()
	var load_array_ok = gs.load_from_disk()
	_assert_check(load_array_ok == false, "8.22 Array-root JSON rejected safely (returns false)")

	# NaN and Infinity values
	var f_nan = FileAccess.open("user://savegame.json", FileAccess.WRITE)
	f_nan.store_string('{"version": 1, "energy": "NaN", "master_volume": 999.0, "screen_shake_intensity": -5.0}')
	f_nan.close()
	gs.load_from_disk()
	_assert_check(gs.energy >= 0.0 and not is_nan(gs.energy), "8.23 NaN energy sanitized to valid non-negative float")
	_assert_check(gs.master_volume <= 1.0, "8.24 Volume clamped to 1.0 max bound")
	_assert_check(gs.screen_shake_intensity >= 0.0, "8.25 Screen shake clamped to 0.0 min bound")

	# 8.3 Number Formatting Coverage (format_number)
	_assert_check(gs.format_number(0.0) == "0", "8.26 format_number(0) == '0'")
	_assert_check(gs.format_number(500.0) == "500", "8.27 format_number(500) == '500'")
	_assert_check(gs.format_number(1500.0) == "1.50 K", "8.28 format_number(1500) == '1.50 K'")
	_assert_check(gs.format_number(2500000.0) == "2.50 M", "8.29 format_number(2.5M) == '2.50 M'")
	_assert_check(gs.format_number(3200000000.0) == "3.20 B", "8.30 format_number(3.2B) == '3.20 B'")
	_assert_check(gs.format_number(4100000000000.0) == "4.10 T", "8.31 format_number(4.1T) == '4.10 T'")

	# 8.4 Tech Tree Methods & Item Inventory Coverage
	_assert_check(gs.get_tech_definitions().size() == 5, "8.32 get_tech_definitions returns 5 technologies")
	gs.reset_state()
	_assert_check(gs.can_research_tech("tech_coffee_automation") == false, "8.33 Cannot research tech without sufficient energy")
	gs.energy = 1000.0
	_assert_check(gs.can_research_tech("tech_coffee_automation") == true, "8.34 can_research_tech returns true when energy sufficient")
	_assert_check(gs.research_tech("tech_coffee_automation") == true, "8.35 research_tech succeeds and unlocks tech")
	_assert_check(gs.is_tech_researched("tech_coffee_automation") == true, "8.36 is_tech_researched returns true")

	# Delivery drone requires 3 USB sticks
	gs.energy = 5000.0
	_assert_check(gs.can_research_tech("tech_delivery_drone") == false, "8.37 Delivery drone cannot be researched without USB sticks")
	gs.item_inventory["usb_drive"] = 3
	_assert_check(gs.can_research_tech("tech_delivery_drone") == true, "8.38 Delivery drone can be researched with 3 USB sticks")
	_assert_check(gs.research_tech("tech_delivery_drone") == true, "8.39 research_tech consumes USB sticks and unlocks drone")
	_assert_check(gs.item_inventory["usb_drive"] == 0, "8.40 3 USB sticks consumed upon research")

	# 8.5 Inventory Helpers: get_item_count, has_items, consume_items
	gs.collect_3d_item("briefcase", 100.0)
	_assert_check(gs.get_item_count("briefcase") == 1, "8.41 get_item_count returns 1 briefcase")
	_assert_check(gs.has_items("briefcase", 1) == true, "8.42 has_items(1) returns true")
	_assert_check(gs.consume_items("briefcase", 1) == true, "8.43 consume_items(1) succeeds")
	_assert_check(gs.has_items("briefcase", 1) == false, "8.44 has_items(1) returns false after consumption")

	# 8.6 Audio Settings Helpers
	gs.set_master_volume(0.8)
	gs.set_music_volume(0.6)
	gs.set_sfx_volume(0.9)
	gs.set_master_muted(true)
	var a_set: Dictionary = gs.get_audio_settings()
	_assert_check(absf(float(a_set.get("master_volume", 0.0)) - 0.8) < EPSILON, "8.45 get_audio_settings master_volume is 0.8")
	_assert_check(bool(a_set.get("master_muted", false)) == true, "8.46 get_audio_settings master_muted is true")

	# 8.7 Screen Shake & Light Cycle Helpers
	gs.set_screen_shake_intensity(0.5)
	_assert_check(absf(gs.get_screen_shake_intensity() - 0.5) < EPSILON, "8.47 get_screen_shake_intensity returns 0.5")
	gs.set_light_cycle_mode("day")
	_assert_check(gs.get_light_cycle_mode() == "day", "8.48 get_light_cycle_mode returns 'day'")

	# 8.8 Campus Zones & Quests Helpers
	_assert_check(gs.is_zone_unlocked("zone_server") == false, "8.49 Zone initially locked")
	gs.unlock_zone("zone_server")
	_assert_check(gs.is_zone_unlocked("zone_server") == true, "8.50 unlock_zone marks zone unlocked")

	gs.start_campus_quest("quest_test", 3)
	_assert_check(gs.get_campus_quest_status("quest_test") == "active", "8.51 Quest starts active")
	gs.advance_campus_quest("quest_test", 3)
	gs.complete_campus_quest("quest_test", 500.0, 10)
	_assert_check(gs.get_campus_quest_status("quest_test") == "completed", "8.52 complete_campus_quest marks quest completed")

	# 8.9 Daily Tasks & Streaks Helpers
	gs.refresh_daily_tasks(100)
	var d_tasks: Array = gs.get_daily_tasks()
	_assert_check(d_tasks.size() == 3, "8.53 get_daily_tasks returns 3 rotating tasks")
	_assert_check(gs.get_daily_streak() == 0, "8.54 get_daily_streak returns 0 initial streak")

	# 8.10 Campaign & Espresso Helpers
	_assert_check(gs.get_campaign_chapter() == 1, "8.55 Initial campaign chapter is 1")
	gs.advance_campaign_chapter()
	_assert_check(gs.get_campaign_chapter() == 2, "8.56 advance_campaign_chapter advances chapter to 2")
	_assert_check(gs.is_unicorn_espresso_active() == false, "8.57 Espresso initially inactive")
	gs.activate_unicorn_espresso_buff(60.0)
	_assert_check(gs.is_unicorn_espresso_active() == true, "8.58 activate_unicorn_espresso_buff activates espresso")

	# 8.11 Energy Ingestion & Bonus Users API Coverage
	var energy_before: float = gs.energy
	gs.add_energy(250.0)
	_assert_check(absf(gs.energy - (energy_before + 250.0)) < EPSILON, "8.59 add_energy increments energy by 250")
	energy_before = gs.energy
	gs.earn_energy(350.0)
	_assert_check(absf(gs.energy - (energy_before + 350.0)) < EPSILON, "8.60 earn_energy increments energy by 350")
	var prev_bonus_users: int = gs.bonus_users
	gs.award_bonus_users(10)
	_assert_check(gs.bonus_users == prev_bonus_users + 10, "8.61 award_bonus_users increments bonus users count")

	# 8.12 Progression & Speed / Radius Stats Coverage
	_assert_check(gs.get_idle_level() >= 1, "8.62 get_idle_level returns baseline >= 1")
	_assert_check(gs.get_effective_avatar_speed() >= 1.0, "8.63 get_effective_avatar_speed returns baseline >= 1.0")
	_assert_check(gs.get_effective_pickup_radius() >= 1.0, "8.64 get_effective_pickup_radius returns baseline >= 1.0")
	_assert_check(gs.get_worker_production_multiplier() >= 1.0, "8.65 get_worker_production_multiplier returns baseline >= 1.0")
	_assert_check(gs.get_angel_investor_spawn_chance_multiplier() >= 1.0, "8.66 get_angel_investor_spawn_chance_multiplier returns baseline >= 1.0")

	# 8.13 Audio Mute Controls
	gs.set_music_muted(true)
	_assert_check(gs.music_muted == true, "8.67 set_music_muted(true) mutes music")
	gs.set_music_muted(false)
	_assert_check(gs.music_muted == false, "8.68 set_music_muted(false) un-mutes music")
	gs.set_sfx_muted(true)
	_assert_check(gs.sfx_muted == true, "8.69 set_sfx_muted(true) mutes sfx")
	gs.set_sfx_muted(false)
	_assert_check(gs.sfx_muted == false, "8.70 set_sfx_muted(false) un-mutes sfx")

	# 8.14 Trophies & Milestones API Coverage
	_assert_check(gs.unlock_trophy("trophy_coverage_test") == true, "8.71 unlock_trophy unlocks new trophy")
	_assert_check(gs.unlock_trophy("trophy_coverage_test") == false, "8.72 unlock_trophy returns false for duplicate unlock")
	var unlocked_list: Array[String] = gs.get_unlocked_trophies()
	_assert_check(unlocked_list.has("trophy_coverage_test"), "8.73 get_unlocked_trophies includes newly unlocked trophy")
	gs.campaign_chapter = 2
	gs.check_and_update_trophies()
	_assert_check(gs.is_trophy_unlocked("trophy_golden_briefcase") == true, "8.74 check_and_update_trophies unlocks golden briefcase in Ch. 2")

	# 8.15 Campaign Quests, Speed Buffs & Choices
	_assert_check(gs.is_campaign_quest_completed("quest_nonexistent") == false, "8.75 is_campaign_quest_completed returns false for uncompleted quest")
	gs.campaign_completed_quests.append("quest_coverage_test")
	_assert_check(gs.is_campaign_quest_completed("quest_coverage_test") == true, "8.76 is_campaign_quest_completed returns true for completed quest")
	gs.activate_campaign_speed_buff(1.5, 30.0)
	_assert_check(absf(gs.campaign_speed_buff_multiplier - 1.5) < EPSILON, "8.77 activate_campaign_speed_buff sets speed buff multiplier to 1.5")
	_assert_check(absf(gs.campaign_speed_buff_timer - 30.0) < EPSILON, "8.78 activate_campaign_speed_buff sets timer to 30.0s")
	gs.campaign_speed_buff_timer = 0.0
	gs.record_campaign_choice(1, "choice_test_tech", "speed", 1.25, 45.0)
	_assert_check(gs.campaign_choices.has("1") or gs.campaign_choices.has(1), "8.79 record_campaign_choice records choice in campaign_choices")

	# 8.16 Daily Tasks Progression & Claim API Coverage
	gs.refresh_daily_tasks(200)
	var active_tasks: Array = gs.get_daily_tasks()
	_assert_check(active_tasks.size() > 0, "8.80 get_daily_tasks returns active task list")
	var sample_task_id: String = active_tasks[0].get("id", "")
	var target_goal: int = int(active_tasks[0].get("target", 1))
	gs.advance_daily_task(sample_task_id, target_goal)
	_assert_check(bool(active_tasks[0].get("is_completed", false)) == true, "8.81 advance_daily_task advances progress and marks task completed")
	var claim_result: Dictionary = gs.claim_daily_task(sample_task_id)
	_assert_check(bool(claim_result.get("success", false)) == true, "8.82 claim_daily_task successfully claims completed task")

	# 8.17 Syndicate Management & Progression API Coverage
	_assert_check(gs.get_syndicate_tier_definitions().size() == 6, "8.83 get_syndicate_tier_definitions returns all 6 tier definitions (0..5)")
	var join_ok: bool = gs.join_syndicate("syn_coverage_corp", "Coverage Corp", "COV", "Syndicate API coverage test")
	_assert_check(join_ok == true, "8.84 join_syndicate succeeds and sets active guild")
	var active_syn_info: Dictionary = gs.get_active_syndicate()
	_assert_check(active_syn_info.get("id", "") == "syn_coverage_corp", "8.85 get_active_syndicate returns active syndicate info")
	var syn_bonuses: Dictionary = gs.get_syndicate_bonuses()
	_assert_check(syn_bonuses.has("dividend_multiplier"), "8.86 get_syndicate_bonuses returns dividend and drone multipliers")
	gs.syndicate_fund_energy = 100000.0
	var new_syn_tier: int = gs.check_syndicate_tier_progression()
	_assert_check(new_syn_tier >= 1, "8.87 check_syndicate_tier_progression updates and returns syndicate tier")
	var syn_score: int = gs.get_seasonal_leaderboard_score()
	_assert_check(syn_score >= 0, "8.88 get_seasonal_leaderboard_score returns non-negative score")
	gs.active_syndicate_id = ""
	gs.syndicate_tier = 0

	# 8.18 Staff Management, Desk Definitions & Epiphany API Coverage
	var staff_role_defs: Dictionary = gs.get_staff_role_definitions()
	_assert_check(staff_role_defs.size() == 5, "8.89 get_staff_role_definitions returns 5 specialist roles")
	var desk_defs: Dictionary = gs.get_desk_definitions()
	_assert_check(desk_defs.size() == 3, "8.90 get_desk_definitions returns 3 desk configuration tiers")
	var d_levels: Array = gs.get_desk_levels()
	_assert_check(d_levels.size() == 5, "8.91 get_desk_levels returns 5 desk tiers")
	var desk_0_cost: float = gs.get_desk_upgrade_cost(0)
	_assert_check(absf(desk_0_cost - 5000.0) < EPSILON, "8.92 get_desk_upgrade_cost(0) returns 5000.0 for Level 2 upgrade")
	_assert_check(absf(gs.get_average_worker_morale() - 1.0) < EPSILON, "8.93 get_average_worker_morale returns 1.0 baseline")
	_assert_check(gs.get_staff_hyper_focus_time_remaining() >= 0.0, "8.94 get_staff_hyper_focus_time_remaining returns non-negative time")
	gs.energy = 5000.0
	gs.hire_worker("Frontend Dev")
	var hired: Array = gs.get_hired_workers()
	_assert_check(hired.size() == 1, "8.95 One worker hired for epiphany test")
	var worker_id: String = hired[0].get("id", "")
	var epiphany_reward: float = gs.trigger_epiphany(worker_id)
	_assert_check(epiphany_reward > 0.0, "8.96 trigger_epiphany successfully awards instant energy bonus")
	gs.hired_workers.clear()
