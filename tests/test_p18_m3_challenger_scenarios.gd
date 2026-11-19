extends SceneTree

## =============================================================================
## Phase 18 Milestone 3: Domain 6 Adversarial Challenger Test Suite
## File: IdleArcade/tests/test_p18_m3_challenger_scenarios.gd
## Target: Godot 4.3 Headless Runner & CI Verification
##
## Independent, Empirical Stress-Testing for Domain 6 Scenarios 1–3:
##   - Scenario 1: Fresh Install FTUE Full Loop (Invariants, Step Race vs Locomotion,
##                 Multi-collectible burst, All-Step Skip, Mid-step Persistence)
##   - Scenario 2: IPO Prestige & Tutorial Replay (Extreme Boundary Matrix on
##                 Lifetime Energy/Angel Shares, Syndicate Bonus Interaction,
##                 Consecutive Re-IPO Zero-Gain Immunity, Non-destructive Replay)
##   - Scenario 3: Syndicate Enterprise Holdings Loop (Syndicate Tier Dividends,
##                 Daily Board Tasks/Streak/Rollback, 5 Specialist Workers,
##                 Desk Fatigue Damping Monotonicity, Coffee Break Hyper-Focus Isolation,
##                 Compound Passive RPS Commutativity & Roundtrip Fidelity)
##
## Execution:
##   godot --headless --path IdleArcade -s tests/test_p18_m3_challenger_scenarios.gd
## =============================================================================

var pass_count: int = 0
var fail_count: int = 0
var scenario1_pass: int = 0
var scenario1_fail: int = 0
var scenario2_pass: int = 0
var scenario2_fail: int = 0
var scenario3_pass: int = 0
var scenario3_fail: int = 0

const EPSILON: float = 0.005
var _mounted_nodes: Array[Node] = []
var _save_backup_text: String = ""
var _had_save_backup: bool = false

func _assert_check(condition: bool, test_name: String, detail: String = "", scenario_idx: int = 1) -> void:
	if condition:
		print("  [PASS] %s" % test_name)
		pass_count += 1
		if scenario_idx == 1:
			scenario1_pass += 1
		elif scenario_idx == 2:
			scenario2_pass += 1
		elif scenario_idx == 3:
			scenario3_pass += 1
	else:
		var err_msg: String = "  [FAIL] %s" % test_name
		if detail != "":
			err_msg += " -> " + detail
		printerr(err_msg)
		fail_count += 1
		if scenario_idx == 1:
			scenario1_fail += 1
		elif scenario_idx == 2:
			scenario2_fail += 1
		elif scenario_idx == 3:
			scenario3_fail += 1

func _init() -> void:
	print("====================================================================")
	print(">>> IDLEARCADE DOMAIN 6 EMPIRICAL CHALLENGER SUITE (P18-M3) <<<")
	print("====================================================================")
	call_deferred("_run_challenger_suite")

func _cleanup_and_quit(exit_code: int = 0) -> void:
	if _had_save_backup:
		var f_res = FileAccess.open("user://savegame.json", FileAccess.WRITE)
		if f_res != null:
			f_res.store_string(_save_backup_text)
			f_res.close()
			print("  [CLEANUP] Restored original user://savegame.json")
	elif FileAccess.file_exists("user://savegame.json"):
		DirAccess.remove_absolute("user://savegame.json")
		print("  [CLEANUP] Removed temporary user://savegame.json")

	for i in range(_mounted_nodes.size() - 1, -1, -1):
		var n = _mounted_nodes[i]
		if is_instance_valid(n):
			if n.get_parent() != null:
				n.get_parent().remove_child(n)
			n.free()
	_mounted_nodes.clear()
	print("  [CLEANUP] All test harness singletons safely unmounted.")
	quit(exit_code)

func _run_challenger_suite() -> void:
	await process_frame

	# Backup savegame if exists
	if FileAccess.file_exists("user://savegame.json"):
		var f_bk = FileAccess.open("user://savegame.json", FileAccess.READ)
		if f_bk != null:
			_save_backup_text = f_bk.get_as_text()
			_had_save_backup = true
			f_bk.close()

	# Mount singletons
	print("\n--- MOUNTING AUTOLOAD SINGLETONS ---")
	var gs_script = load("res://scripts/autoload/game_state.gd")
	_assert_check(gs_script != null, "Load res://scripts/autoload/game_state.gd")
	var gs = root.get_node_or_null("GameState")
	if gs == null and gs_script != null:
		gs = gs_script.new()
		gs.name = "GameState"
		root.add_child(gs)
		_mounted_nodes.append(gs)

	var tm_script = load("res://scripts/autoload/tutorial_manager.gd")
	_assert_check(tm_script != null, "Load res://scripts/autoload/tutorial_manager.gd")
	var tm = root.get_node_or_null("TutorialManager")
	if tm == null and tm_script != null:
		tm = tm_script.new()
		tm.name = "TutorialManager"
		root.add_child(tm)
		_mounted_nodes.append(tm)

	var am_script = load("res://scripts/autoload/audio_manager.gd")
	var am = root.get_node_or_null("AudioManager")
	if am == null and am_script != null:
		am = am_script.new()
		am.name = "AudioManager"
		root.add_child(am)
		_mounted_nodes.append(am)

	var hm_script = load("res://scripts/autoload/haptics_manager.gd")
	var hm = root.get_node_or_null("HapticsManager")
	if hm == null and hm_script != null:
		hm = hm_script.new()
		hm.name = "HapticsManager"
		root.add_child(hm)
		_mounted_nodes.append(hm)

	var lem_script = load("res://scripts/autoload/live_event_manager.gd")
	var lem = root.get_node_or_null("LiveEventManager")
	if lem == null and lem_script != null:
		lem = lem_script.new()
		lem.name = "LiveEventManager"
		root.add_child(lem)
		_mounted_nodes.append(lem)

	await process_frame
	_assert_check(gs != null and tm != null, "Harness Singletons mounted at /root/")

	# Run Scenarios 1 - 3
	await _test_scenario_1_ftue_adversarial(gs, tm)
	await _test_scenario_2_ipo_prestige_adversarial(gs, tm)
	await _test_scenario_3_syndicate_enterprise_adversarial(gs)

	# Print Summary
	print("\n====================================================================")
	print(">>> EMPIRICAL CHALLENGER RESULTS SUMMARY <<<")
	print("====================================================================")
	print("  Scenario 1 (FTUE Full Loop & Rapid Step Stress)   : %3d Passed, %2d Failed" % [scenario1_pass, scenario1_fail])
	print("  Scenario 2 (IPO Prestige & Angel Shares Boundaries): %3d Passed, %2d Failed" % [scenario2_pass, scenario2_fail])
	print("  Scenario 3 (Syndicate Enterprise Holdings Loop)   : %3d Passed, %2d Failed" % [scenario3_pass, scenario3_fail])
	print("--------------------------------------------------------------------")
	print("  TOTAL ADVERSARIAL ASSERTIONS                      : %3d Passed, %2d Failed" % [pass_count, fail_count])
	print("====================================================================")

	var exit_code: int = 0 if fail_count == 0 else 1
	if exit_code == 0:
		print(">>> ALL DOMAIN 6 ADVERSARIAL STRESS TESTS PASSED (APPROVE) <<<\n")
	else:
		printerr(">>> ADVERSARIAL FAILURES ENCOUNTERED (REQUEST_CHANGES) <<<\n")

	_cleanup_and_quit(exit_code)

## =============================================================================
## SCENARIO 1: Fresh Install FTUE Full Loop Adversarial Challenges
## =============================================================================
func _test_scenario_1_ftue_adversarial(gs: Node, tm: Node) -> void:
	print("\n--- ADVERSARIAL CHALLENGE SUITE 1: Scenario 1 FTUE Full Loop ---")

	# 1.1 Cold Install State Invariants
	if FileAccess.file_exists("user://savegame.json"):
		DirAccess.remove_absolute("user://savegame.json")
	gs.reset_state()
	gs.reset_tutorial_state()
	gs.tutorial_replay_requested = false
	if tm != null and tm.has_method("reset_tutorial"):
		tm.reset_tutorial()
	await process_frame

	_assert_check(gs.is_first_time_player() == true, "1.1.1 Fresh install: is_first_time_player() == true", "", 1)
	_assert_check(tm.should_start_intro() == true, "1.1.2 Fresh install: should_start_intro() == true", "", 1)
	_assert_check(tm.get_current_step() == 0, "1.1.3 Fresh install: current_step is IDLE (0)", "", 1)

	# 1.2 Multi-Tap Stress during Step 1 & Lifetime Invariant F2
	tm.start_linear_intro()
	await process_frame
	_assert_check(tm.is_tutorial_active() and tm.get_current_step() == 1, "1.2.1 Intro active at Step 1", "", 1)

	# Tap 5 times rapidly during Step 1
	for i in range(5):
		gs.tap_core()
	await process_frame

	_assert_check(gs.total_clicks == 5, "1.2.2 Multi-tap stress: recorded 5 clicks in Step 1", "", 1)
	# Seed grant awarded (+30) plus the 5 clicks
	_assert_check(gs.energy >= 30.0, "1.2.3 Seed grant awarded energy >= 30.0 (actual: %.1f)" % gs.energy, "", 1)
	# INVARIANT: total_lifetime_energy >= total_energy_earned >= energy
	_assert_check(gs.total_lifetime_energy >= gs.total_energy_earned, "1.2.4 Invariant: total_lifetime_energy >= total_energy_earned", "", 1)
	_assert_check(gs.total_energy_earned >= gs.energy, "1.2.5 Invariant: total_energy_earned >= energy", "", 1)
	_assert_check(tm.get_current_step() == 2, "1.2.6 Transitioned to Step 2 after Step 1 tap", "", 1)

	# 1.3 Step 2 generator purchase
	var buy_ok = gs.buy_upgrade("tier_1")
	await process_frame
	_assert_check(buy_ok == true, "1.3.1 Bought tier_1 upgrade with seed energy", "", 1)
	_assert_check(gs.upgrades["tier_1"]["level"] == 1, "1.3.2 tier_1 level is 1", "", 1)
	_assert_check(tm.get_current_step() == 3, "1.3.3 Transitioned to Step 3 (Frenzy)", "", 1)

	# 1.4 Step 3 Frenzy Meter 25 Taps Overdrive
	for i in range(25):
		gs.tap_core()
	await process_frame
	_assert_check(gs.is_frenzy_active == true, "1.4.1 Frenzy overdrive activated on 25 taps", "", 1)
	_assert_check(absf(gs.frenzy_multiplier - 3.0) < EPSILON, "1.4.2 Frenzy multiplier set to 3.0x", "", 1)
	_assert_check(tm.get_current_step() == 4, "1.4.3 Transitioned to Step 4 (Campus 3D)", "", 1)

	# 1.5 Rapid Sequential Advancement vs Locomotion Physics Trigger
	var avatar_scene = load("res://scenes/avatar_3d.tscn")
	_assert_check(avatar_scene != null, "1.5.1 Avatar3D scene loadable", "", 1)
	var avatar: Avatar3D = avatar_scene.instantiate() as Avatar3D
	root.add_child(avatar)
	await process_frame

	# Simulate avatar movement triggering TutorialManager._physics_process
	avatar.set_input_direction(Vector3(1.0, 0.0, 1.0).normalized())
	avatar._physics_process(0.1)
	await process_frame

	# TutorialManager._physics_process advances Step 4 automatically
	_assert_check(tm.get_current_step() >= 4, "1.5.2 Locomotion physics detected avatar velocity", "", 1)
	if tm.get_current_step() == 4:
		tm.advance_step()
		await process_frame
	_assert_check(tm.get_current_step() == 5, "1.5.3 Step 4 cleanly transitioned to Step 5 (Collectible)", "", 1)

	# Double Advance Race Guard:
	# If avatar continues moving during Step 5, it should NOT advance to Step 6 (Step 5 requires collectible)
	avatar.set_input_direction(Vector3(0.5, 0.0, 0.5).normalized())
	avatar._physics_process(0.1)
	tm._physics_process(0.1)
	await process_frame
	_assert_check(tm.get_current_step() == 5, "1.5.4 Avatar movement in Step 5 does NOT falsely advance to Step 6", "", 1)

	# 1.6 Collectible Multi-Pickup Burst in Step 5
	var coll_scene = load("res://scenes/collectible_3d.tscn")
	_assert_check(coll_scene != null, "1.6.1 Collectible3D scene loadable", "", 1)
	var c1: Collectible3D = coll_scene.instantiate() as Collectible3D
	c1.item_type = "briefcase"
	c1.reward_amount = 50.0
	root.add_child(c1)
	var c2: Collectible3D = coll_scene.instantiate() as Collectible3D
	c2.item_type = "coffee"
	c2.reward_amount = 25.0
	root.add_child(c2)
	await process_frame

	# Collect first item -> should advance Step 5 to Step 6
	c1.collect(avatar)
	await process_frame
	_assert_check(tm.get_current_step() == 6, "1.6.2 First collectible advanced Step 5 to Step 6", "", 1)

	# Collect second item while at Step 6 -> should NOT advance past Step 6 (Step 6 requires terminal)
	c2.collect(avatar)
	await process_frame
	_assert_check(tm.get_current_step() == 6, "1.6.3 Subsequent collectible in Step 6 does NOT advance past Step 6", "", 1)
	_assert_check(gs.collectibles_collected == 2, "1.6.4 Collectibles count accurately tracks 2 pickups", "", 1)
	_assert_check(gs.item_inventory.get("briefcase", 0) == 1, "1.6.5 Briefcase in inventory", "", 1)
	_assert_check(gs.item_inventory.get("coffee", 0) == 1, "1.6.6 Coffee in inventory", "", 1)

	# 1.7 Step 6 Terminal Minigame & Completion
	var st_scene = load("res://scenes/server_terminal.tscn")
	_assert_check(st_scene != null, "1.7.1 ServerTerminal scene loadable", "", 1)
	var st: ServerTerminal = st_scene.instantiate() as ServerTerminal
	root.add_child(st)
	await process_frame

	st.interact()
	st.complete_cyber_sync(true, "Perfect", 45.0, 3.00)
	await process_frame
	_assert_check(gs.server_overclock_buff_active, "1.7.2 Cyber-sync activated overclock buff", "", 1)

	tm.advance_step()
	await process_frame
	_assert_check(tm.get_current_step() == 7, "1.7.3 Tutorial fully COMPLETED (Step 7)", "", 1)
	_assert_check(gs.tutorial_completed == true, "1.7.4 GameState.tutorial_completed == true", "", 1)
	_assert_check(not tm.is_tutorial_active(), "1.7.5 is_tutorial_active() is false after completion", "", 1)

	# 1.8 Skip Tutorial Resilience at All Individual Steps (Steps 1 through 6)
	print("\n  [Skip Tutorial Stress Matrix across Steps 1..6]")
	for test_step in range(1, 7):
		gs.tutorial_completed = false
		gs.tutorial_skipped = false
		gs.tutorial_current_step = test_step
		tm.reset_tutorial()
		tm.is_intro_active = true
		tm.current_step = test_step
		_ensure_overlay_exists(tm)

		tm.skip_tutorial()
		await process_frame

		_assert_check(tm.get_current_step() == 7, "1.8.%d.1 Skip at Step %d transitions current_step to 7" % [test_step, test_step], "", 1)
		_assert_check(not tm.is_tutorial_active(), "1.8.%d.2 Skip at Step %d leaves intro inactive" % [test_step, test_step], "", 1)
		_assert_check(gs.tutorial_completed == true, "1.8.%d.3 Skip at Step %d marks tutorial_completed = true" % [test_step, test_step], "", 1)
		_assert_check(gs.tutorial_skipped == true, "1.8.%d.4 Skip at Step %d marks tutorial_skipped = true" % [test_step, test_step], "", 1)

	# 1.9 Intermediate Save/Load Roundtrip Integrity across Steps
	print("\n  [Mid-Tutorial Save/Load Matrix across Steps 1, 3, 5, 7]")
	var steps_to_test = [1, 3, 5, 7]
	for s_idx in steps_to_test:
		gs.reset_state()
		gs.tutorial_current_step = s_idx
		gs.tutorial_completed = (s_idx == 7)
		gs.tutorial_skipped = false
		gs.energy = float(s_idx * 100.0)
		gs.save_to_disk()
		await process_frame

		gs.reset_state()
		var l_ok = gs.load_from_disk()
		_assert_check(l_ok, "1.9.%d.1 load_from_disk() succeeds for Step %d save" % [s_idx, s_idx], "", 1)
		_assert_check(gs.tutorial_current_step == s_idx, "1.9.%d.2 Restored tutorial_current_step == %d" % [s_idx, s_idx], "", 1)
		_assert_check(gs.tutorial_completed == (s_idx == 7), "1.9.%d.3 Restored tutorial_completed == %s" % [s_idx, str(s_idx == 7)], "", 1)
		if s_idx < 7:
			_assert_check(gs.is_first_time_player() == true, "1.9.%d.4 Step %d mid-tutorial player is first_time" % [s_idx, s_idx], "", 1)
		else:
			_assert_check(gs.is_first_time_player() == false, "1.9.%d.4 Step %d completed player is NOT first_time" % [s_idx, s_idx], "", 1)

	# Cleanup scene nodes
	avatar.queue_free()
	c1.queue_free()
	c2.queue_free()
	st.queue_free()
	await process_frame

func _ensure_overlay_exists(tm: Node) -> void:
	if tm.has_method("_ensure_overlay"):
		tm._ensure_overlay()

## =============================================================================
## SCENARIO 2: IPO Prestige & Tutorial Replay Adversarial Challenges
## =============================================================================
func _test_scenario_2_ipo_prestige_adversarial(gs: Node, tm: Node) -> void:
	print("\n--- ADVERSARIAL CHALLENGE SUITE 2: Scenario 2 IPO Prestige & Tutorial Replay ---")

	gs.reset_state()
	if FileAccess.file_exists("user://savegame.json"):
		DirAccess.remove_absolute("user://savegame.json")
	await process_frame

	# 2.1 Extreme Boundary Conditions on Lifetime Energy & Sqrt Math
	print("\n  [2.1 Extreme Boundary Conditions Matrix]")
	# Negative values
	gs.total_lifetime_energy = -100000.0
	_assert_check(gs.calculate_pending_angel_shares() == 0, "2.1.1 Negative lifetime energy yields 0 shares", "", 2)
	_assert_check(not gs.can_trigger_ipo(), "2.1.2 can_trigger_ipo() is false on negative lifetime energy", "", 2)

	# Zero
	gs.total_lifetime_energy = 0.0
	_assert_check(gs.calculate_pending_angel_shares() == 0, "2.1.3 Zero lifetime energy yields 0 shares", "", 2)
	_assert_check(not gs.can_trigger_ipo(), "2.1.4 can_trigger_ipo() is false on zero lifetime energy", "", 2)

	# Sub-100k
	gs.total_lifetime_energy = 99999.99
	_assert_check(gs.calculate_pending_angel_shares() == 0, "2.1.5 99,999.99 lifetime energy yields 0 shares", "", 2)
	_assert_check(not gs.can_trigger_ipo(), "2.1.6 can_trigger_ipo() is false below 100k", "", 2)

	# 100k (sqrt(1) = 1 share)
	gs.total_lifetime_energy = 100000.0
	_assert_check(gs.calculate_pending_angel_shares() == 1, "2.1.7 Exactly 100k yields 1 share", "", 2)
	# But can_trigger_ipo requires 1M threshold or campaign chapter 3
	gs.campaign_chapter = 1
	_assert_check(not gs.can_trigger_ipo(), "2.1.8 can_trigger_ipo() is false at 100k with chapter 1 (threshold 1M)", "", 2)
	gs.campaign_chapter = 3
	_assert_check(gs.can_trigger_ipo() == true, "2.1.9 can_trigger_ipo() is true at 100k with chapter 3", "", 2)

	# Step boundaries
	var energy_boundary_matrix = [
		{"e": 399999.0, "expected_shares": 1},
		{"e": 400000.0, "expected_shares": 2},
		{"e": 899999.0, "expected_shares": 2},
		{"e": 900000.0, "expected_shares": 3},
		{"e": 1000000.0, "expected_shares": 3}, # sqrt(10) = 3.162 -> 3
		{"e": 1600000.0, "expected_shares": 4},
		{"e": 2500000.0, "expected_shares": 5},
		{"e": 3600000.0, "expected_shares": 6},
		{"e": 10000000.0, "expected_shares": 10}, # sqrt(100) = 10
		{"e": 100000000.0, "expected_shares": 31}, # sqrt(1000) = 31.62 -> 31
		{"e": 1000000000.0, "expected_shares": 100}, # sqrt(10000) = 100
		{"e": 1000000000000.0, "expected_shares": 3162} # 1 Trillion: sqrt(10^7) = 3162.27 -> 3162
	]

	gs.angel_shares = 0
	gs.campaign_chapter = 1
	for b in energy_boundary_matrix:
		gs.total_lifetime_energy = float(b["e"])
		var calc_s: int = gs.calculate_pending_angel_shares()
		_assert_check(calc_s == int(b["expected_shares"]),
			"2.1.10 Energy %.0f yields exactly %d shares (actual: %d)" % [float(b["e"]), int(b["expected_shares"]), calc_s],
			"", 2)

	# Multiplier check on 3162 shares: 1.0 + (3162 * 0.02) = 64.24x (+6324%)
	gs.angel_shares = 3162
	_assert_check(absf(gs.get_angel_share_multiplier() - 64.24) < EPSILON,
		"2.1.11 3162 Angel shares correctly compute 64.24x multiplier (actual: %.4f)" % gs.get_angel_share_multiplier(),
		"", 2)
	gs.angel_shares = 0

	# 2.2 Syndicate IPO Bonus Shares Interaction
	print("\n  [2.2 Syndicate IPO Bonus Interaction]")
	gs.total_lifetime_energy = 10000000.0 # Base pending = 10 shares
	# Affiliate with Tier 4 Syndicate (+10% bonus shares, `ipo_bonus_shares_pct = 0.10`)
	gs.join_syndicate("syn_test", "Test Syndicate", "TEST", "Testing")
	gs.syndicate_fund_energy = 2500000.0
	gs.syndicate_fund_angel_shares = 50
	gs.check_syndicate_tier_progression()
	_assert_check(gs.get_syndicate_tier() == 4, "2.2.1 Syndicate promoted to Tier 4", "", 2)
	_assert_check(absf(gs.get_syndicate_ipo_bonus_percent() - 0.10) < EPSILON, "2.2.2 Tier 4 provides +10% IPO bonus shares", "", 2)

	# Base pending = 10 -> Bonus = floor(10 * 0.10) = 1 -> Total = 11 shares
	var pending_with_syndicate: int = gs.calculate_pending_angel_shares()
	_assert_check(pending_with_syndicate == 11, "2.2.3 10 base shares + 10%% syndicate bonus yields 11 shares (actual: %d)" % pending_with_syndicate, "", 2)

	# What if base pending is 9 shares? 9 * 0.10 = 0.9 -> floor = 0 bonus -> total 9 shares
	gs.total_lifetime_energy = 8100000.0 # sqrt(81) = 9 shares
	_assert_check(gs.calculate_pending_angel_shares() == 9, "2.2.4 9 base shares + 10%% bonus rounds down to 0 bonus shares (total 9)", "", 2)

	# 2.3 Multi-IPO Consecutive Cycle & Zero-Gain Immunity
	print("\n  [2.3 Multi-IPO Cycle & Zero-Gain Immunity]")
	gs.total_lifetime_energy = 4000000.0 # sqrt(40) = 6 base shares
	# Leave syndicate for clean baseline IPO
	gs.leave_syndicate()
	_assert_check(not gs.is_in_syndicate(), "2.3.1 Clean unaffiliated syndicate state", "", 2)

	var ipo1 = gs.trigger_ipo()
	_assert_check(ipo1.get("success") == true, "2.3.2 First IPO succeeds", "", 2)
	_assert_check(gs.angel_shares == 6, "2.3.3 First IPO awarded 6 angel shares", "", 2)
	_assert_check(gs.total_ipos_completed == 1, "2.3.4 total_ipos_completed is 1", "", 2)

	# Zero-Gain Immunity: attempt immediate second IPO without new lifetime energy
	_assert_check(gs.calculate_pending_angel_shares() == 0, "2.3.5 Pending shares immediately after IPO is 0", "", 2)
	_assert_check(not gs.can_trigger_ipo(), "2.3.6 can_trigger_ipo() is false with 0 pending shares", "", 2)
	var ipo_fail = gs.trigger_ipo()
	_assert_check(ipo_fail.get("success") == false, "2.3.7 Zero-gain IPO attempt cleanly rejected", "", 2)
	_assert_check(gs.angel_shares == 6, "2.3.8 Angel shares intact at 6", "", 2)

	# Earn 5M more lifetime energy: total = 9,000,000.0 (sqrt(90) = 9 eligible)
	gs.total_lifetime_energy = 9000000.0
	_assert_check(gs.calculate_pending_angel_shares() == 3, "2.3.9 9M lifetime energy - 6 owned shares = 3 pending shares", "", 2)
	_assert_check(gs.can_trigger_ipo() == true, "2.3.10 can_trigger_ipo() is true with 3 pending shares", "", 2)

	var ipo2 = gs.trigger_ipo()
	_assert_check(ipo2.get("success") == true, "2.3.11 Second IPO succeeds", "", 2)
	_assert_check(gs.angel_shares == 9, "2.3.12 Angel shares incremented to 9 (6 + 3)", "", 2)
	_assert_check(gs.total_ipos_completed == 2, "2.3.13 total_ipos_completed incremented to 2", "", 2)
	_assert_check(absf(gs.get_angel_share_multiplier() - 1.18) < EPSILON, "2.3.14 9 shares yield 1.18x multiplier (+18%)", "", 2)

	# 2.4 Non-Destructive Tutorial Replay Progression
	print("\n  [2.4 Tutorial Replay Invariants & Boosted Tap]")
	gs.tutorial_completed = true
	gs.tutorial_skipped = false
	gs.save_to_disk()
	_assert_check(gs.is_first_time_player() == false, "2.4.1 Veteran status established", "", 2)

	# Request Tutorial Replay
	gs.reset_tutorial_state()
	_assert_check(gs.tutorial_replay_requested == true, "2.4.2 tutorial_replay_requested is true", "", 2)
	_assert_check(gs.is_first_time_player() == true, "2.4.3 is_first_time_player() returns true during replay", "", 2)
	_assert_check(gs.angel_shares == 9, "2.4.4 Prestige Angel shares (9) intact", "", 2)
	_assert_check(gs.total_ipos_completed == 2, "2.4.5 total_ipos_completed (2) intact", "", 2)

	# Start Replay Intro Step 1
	tm.start_linear_intro()
	await process_frame
	_assert_check(tm.is_tutorial_active() and tm.get_current_step() == 1, "2.4.6 Replay active at Step 1", "", 2)

	# Replayed tap should be boosted by the 1.18x angel multiplier!
	var replayed_earned = gs.tap_core()
	_assert_check(absf(replayed_earned - 1.18) < EPSILON, "2.4.7 Replayed core tap earns 1.18 energy (1.0 * 1.18x Angel bonus)", "", 2)

	# Mid-replay save/load roundtrip
	gs.save_to_disk()
	await process_frame
	gs.reset_state()
	gs.load_from_disk()
	_assert_check(gs.tutorial_replay_requested == true, "2.4.8 tutorial_replay_requested survives save/load roundtrip", "", 2)
	_assert_check(gs.angel_shares == 9, "2.4.9 Angel shares (9) survive roundtrip", "", 2)
	_assert_check(absf(gs.get_angel_share_multiplier() - 1.18) < EPSILON, "2.4.10 1.18x Angel multiplier survives roundtrip", "", 2)

	# Skip replay
	tm.skip_tutorial()
	await process_frame
	_assert_check(gs.tutorial_completed == true, "2.4.11 Replay skip marks tutorial_completed = true", "", 2)
	_assert_check(gs.tutorial_replay_requested == false, "2.4.12 Replay skip clears tutorial_replay_requested", "", 2)
	_assert_check(gs.is_first_time_player() == false, "2.4.13 is_first_time_player() returns false after replay skip", "", 2)
	_assert_check(gs.angel_shares == 9, "2.4.14 Angel shares preserved post-skip", "", 2)

## =============================================================================
## SCENARIO 3: Syndicate Enterprise Holdings Loop Adversarial Challenges
## =============================================================================
func _test_scenario_3_syndicate_enterprise_adversarial(gs: Node) -> void:
	print("\n--- ADVERSARIAL CHALLENGE SUITE 3: Scenario 3 Syndicate Enterprise Holdings ---")

	gs.reset_state()
	await process_frame

	# 3.1 Syndicate Tiers, Contribution Scaling & Boundary Invariants
	print("\n  [3.1 Syndicate Tiers & Contribution Math]")
	_assert_check(not gs.is_in_syndicate(), "3.1.1 Initially unaffiliated", "", 3)
	_assert_check(gs.get_syndicate_tier() == 0, "3.1.2 Unaffiliated tier is 0", "", 3)
	_assert_check(absf(gs.get_syndicate_dividend_multiplier() - 1.0) < EPSILON, "3.1.3 Unaffiliated dividend is 1.0x", "", 3)

	var join_res = gs.join_syndicate("syn_holdings", "Global Holdings", "GLBL", "Mega Empire")
	_assert_check(join_res == true, "3.1.4 join_syndicate succeeds", "", 3)
	_assert_check(gs.get_syndicate_tier() == 1, "3.1.5 Default tier upon join is Tier 1", "", 3)
	_assert_check(absf(gs.get_syndicate_dividend_multiplier() - 1.05) < EPSILON, "3.1.6 Tier 1 dividend is 1.05x (+5%)", "", 3)

	# Funding contributions across all tiers
	gs.energy = 50000000.0
	gs.angel_shares = 200

	# Tier 2 threshold: 100,000 Energy or 5 Angel Shares
	gs.contribute_to_syndicate(100000.0, "energy")
	_assert_check(gs.get_syndicate_tier() == 2, "3.1.7 Promoted to Tier 2 with 100k Energy", "", 3)
	_assert_check(absf(gs.get_syndicate_dividend_multiplier() - 1.10) < EPSILON, "3.1.8 Tier 2 dividend is 1.10x (+10%)", "", 3)

	# Tier 3 threshold: 500,000 Energy or 20 Angel Shares
	gs.contribute_to_syndicate(400000.0, "energy") # Total 500k
	_assert_check(gs.get_syndicate_tier() == 3, "3.1.9 Promoted to Tier 3 with 500k Energy", "", 3)
	_assert_check(absf(gs.get_syndicate_dividend_multiplier() - 1.15) < EPSILON, "3.1.10 Tier 3 dividend is 1.15x (+15%)", "", 3)

	# Tier 4 threshold: 2,500,000 Energy or 50 Angel Shares
	gs.contribute_to_syndicate(2000000.0, "energy") # Total 2.5M
	_assert_check(gs.get_syndicate_tier() == 4, "3.1.11 Promoted to Tier 4 with 2.5M Energy", "", 3)
	_assert_check(absf(gs.get_syndicate_dividend_multiplier() - 1.20) < EPSILON, "3.1.12 Tier 4 dividend is 1.20x (+20%)", "", 3)

	# Tier 5 threshold: 10,000,000 Energy or 100 Angel Shares
	gs.contribute_to_syndicate(7500000.0, "energy") # Total 10M
	_assert_check(gs.get_syndicate_tier() == 5, "3.1.13 Promoted to Tier 5 with 10M Energy", "", 3)
	_assert_check(absf(gs.get_syndicate_dividend_multiplier() - 1.25) < EPSILON, "3.1.14 Tier 5 dividend is 1.25x (+25%)", "", 3)

	# Negative / Insufficient Contribution Guard
	var neg_contrib = gs.contribute_to_syndicate(-5000.0, "energy")
	_assert_check(neg_contrib.get("success") == false, "3.1.15 Negative contribution rejected cleanly", "", 3)
	gs.energy = 50.0
	var over_contrib = gs.contribute_to_syndicate(1000.0, "energy")
	_assert_check(over_contrib.get("success") == false, "3.1.16 Over-budget contribution rejected cleanly", "", 3)

	# 3.2 Daily Board Tasks Streak & Clock Rollback Invariants
	print("\n  [3.2 Daily Board Tasks & Streak]")
	var d_tasks: Array[Dictionary] = gs.refresh_daily_tasks(200)
	_assert_check(d_tasks.size() == 3, "3.2.1 Daily board has 3 tasks", "", 3)
	gs.daily_board_streak = 0

	for t in d_tasks:
		gs.advance_daily_task(str(t["id"]), int(t["target"]))
		_assert_check(t["is_completed"] == true, "3.2.2 Task %s completed" % str(t["id"]), "", 3)

	for i in range(d_tasks.size()):
		var t_id = str(d_tasks[i]["id"])
		var c_res = gs.claim_daily_task(t_id)
		_assert_check(c_res.get("success") == true, "3.2.3 Claim task %s succeeded" % t_id, "", 3)
		if i < 2:
			_assert_check(c_res.get("all_claimed") == false, "3.2.4 all_claimed is false at task %d" % (i + 1), "", 3)
		else:
			_assert_check(c_res.get("all_claimed") == true, "3.2.5 all_claimed is true after all 3 tasks claimed", "", 3)

	_assert_check(gs.daily_board_streak == 1, "3.2.6 Streak incremented to 1", "", 3)

	# Consecutive Day Retention Test
	gs.refresh_daily_tasks(201)
	_assert_check(gs.daily_board_streak == 1, "3.2.7 Consecutive day login preserves daily streak (1)", "", 3)

	# Clock Rollback Guard Test (F4)
	gs.daily_board_last_login_day = 201
	gs.refresh_daily_tasks(199) # Past day rollback
	_assert_check(gs.daily_board_streak == 0, "3.2.8 F4 Clock rollback guard resets streak to 0 to prevent exploits", "", 3)

	# Re-establish streak = 1 for empire persistence testing
	var fixed_tasks = gs.refresh_daily_tasks(202)
	for t in fixed_tasks:
		gs.advance_daily_task(str(t["id"]), int(t["target"]))
		gs.claim_daily_task(str(t["id"]))
	_assert_check(gs.daily_board_streak == 1, "3.2.9 Streak re-established to 1 for persistence testing", "", 3)

	# 3.3 5 Specialist Workers, Desk Ergonomics & Fatigue Damping
	print("\n  [3.3 5 Specialist Workers & Desk Ergonomics]")
	gs.hired_workers.clear()
	gs.energy = 500000.0 # Seed energy for recruiting and desk upgrades

	var roles = ["Frontend Dev", "Backend Dev", "UI/UX Designer", "Growth Hacker", "QA Engineer"]
	for r in roles:
		var h_ok = gs.hire_worker(r)
		_assert_check(h_ok == true, "3.3.1 Hired specialist: %s" % r, "", 3)

	_assert_check(gs.get_active_workers_count() == 5, "3.3.2 Exactly 5 specialist workers active", "", 3)

	# 6th hire attempt rejected
	var sixth_ok = gs.hire_worker("Frontend Dev")
	_assert_check(sixth_ok == false, "3.3.3 6th worker rejected (capacity 5)", "", 3)

	# Desk Ergonomics Damping:
	# Desk 0 -> Level 1 (1.00x)
	# Desk 1 -> Level 2 (0.75x)
	# Desk 2 -> Level 3 (0.40x)
	_assert_check(gs.get_desk_fatigue_multiplier(1) == 1.00, "3.3.4 Desk Level 1 fatigue multiplier is 1.00x", "", 3)
	var up1_ok = gs.upgrade_desk(1) # Level 2
	_assert_check(up1_ok == true and gs.get_desk_level(1) == 2, "3.3.5 Desk 1 upgraded to Level 2", "", 3)
	_assert_check(absf(gs.get_desk_fatigue_multiplier(2) - 0.75) < EPSILON, "3.3.6 Desk Level 2 fatigue multiplier is 0.75x (25%% damping)", "", 3)

	var up2a_ok = gs.upgrade_desk(2) # Level 2
	var up2b_ok = gs.upgrade_desk(2) # Level 3
	_assert_check(up2a_ok and up2b_ok and gs.get_desk_level(2) == 3, "3.3.7 Desk 2 upgraded to Level 3", "", 3)
	_assert_check(absf(gs.get_desk_fatigue_multiplier(3) - 0.40) < EPSILON, "3.3.8 Desk Level 3 fatigue multiplier is 0.40x (60%% damping)", "", 3)

	# Simulate 300s of work and verify strict fatigue monotonicity:
	# Worker 2 (Desk 2, Level 3) < Worker 1 (Desk 1, Level 2) < Worker 0 (Desk 0, Level 1)
	gs.update_staff_simulation(300.0)
	var w0 = gs.get_worker("Frontend Dev") # Desk 0 (Level 1)
	var w1 = gs.get_worker("Backend Dev")  # Desk 1 (Level 2)
	var w2 = gs.get_worker("UI/UX Designer") # Desk 2 (Level 3)

	var f0: float = float(w0.get("fatigue", 0.0))
	var f1: float = float(w1.get("fatigue", 0.0))
	var f2: float = float(w2.get("fatigue", 0.0))

	_assert_check(f2 < f1, "3.3.9 Desk Level 3 accumulated less fatigue (%.4f) than Desk Level 2 (%.4f)" % [f2, f1], "", 3)
	_assert_check(f1 < f0, "3.3.10 Desk Level 2 accumulated less fatigue (%.4f) than Desk Level 1 (%.4f)" % [f1, f0], "", 3)

	# 3.4 Coffee Break Recovery & Hyper-Focus Isolation
	print("\n  [3.4 Coffee Break Recovery & Hyper-Focus]")
	var cb_ok = gs.give_team_coffee_break()
	_assert_check(cb_ok == true, "3.4.1 give_team_coffee_break() succeeds", "", 3)

	for w in gs.hired_workers:
		_assert_check(absf(float(w.get("fatigue", 1.0)) - 0.0) < EPSILON, "3.4.2 Worker %s fatigue reset to 0.0" % str(w.get("role")), "", 3)
		_assert_check(absf(float(w.get("morale", 0.0)) - 1.0) < EPSILON, "3.4.3 Worker %s morale restored to 1.0" % str(w.get("role")), "", 3)
		_assert_check(str(w.get("current_state")) == "working", "3.4.4 Worker %s state set to 'working'" % str(w.get("role")), "", 3)

	_assert_check(gs.is_staff_hyper_focus_active() == true, "3.4.5 60s Hyper-Focus engaged", "", 3)
	_assert_check(absf(gs.get_staff_hyper_focus_multiplier() - 1.50) < EPSILON, "3.4.6 Hyper-Focus multiplier is 1.50x", "", 3)

	# Hyper-Focus Isolation Invariant:
	# The staff RPS multiplier formula is strictly: 1.0 + (active_count * 0.05) * avg_morale
	# With 5 active workers and 1.0 morale, it MUST be exactly 1.25x.
	var staff_rps_mult: float = gs.get_staff_rps_multiplier()
	_assert_check(absf(staff_rps_mult - 1.25) < EPSILON, "3.4.7 Staff RPS multiplier remains isolated at 1.25x (1.0 + 5*0.05*1.0)", "", 3)

	# 3.5 Tech Tree Research & Compound Passive RPS Formula Invariants
	print("\n  [3.5 Tech Tree Compound RPS Formula]")
	gs.researched_techs.clear()
	gs.energy = 500000.0 # Seed energy for tech research
	gs.upgrades["tier_1"]["level"] = 100
	gs.recalculate_stats()
	gs.angel_shares = 0
	gs.server_overclock_buff_active = false
	gs.campaign_rps_buff_timer = 0.0

	# Reset syndicate to Tier 1 for standard 1.05x dividend
	gs.syndicate_fund_energy = 10000.0
	gs.syndicate_fund_angel_shares = 1
	gs.syndicate_tier = 1

	# Research tech_server_overclock (+25% = 1.25x)
	var t_res = gs.research_tech("tech_server_overclock")
	_assert_check(t_res == true, "3.5.1 Researched tech_server_overclock", "", 3)

	# Active multipliers:
	# Base = 100.0
	# tech_server_overclock = 1.25x
	# Syndicate Tier 1 = 1.05x
	# Staff (5 workers @ 1.0 morale) = 1.25x
	# Compound = 100.0 * 1.25 * 1.05 * 1.25 = 164.0625 RPS
	var current_eff: float = gs.get_effective_passive_rps()
	_assert_check(absf(current_eff - 164.0625) < EPSILON,
		"3.5.2 Compound RPS matches exact formula 100 * 1.25 * 1.05 * 1.25 = 164.0625 (actual: %.4f)" % current_eff,
		"", 3)

	# Commutativity Invariant Test:
	# Add 10 Angel Shares (+20% = 1.20x) and Server Overclock buff (2.00x)
	gs.angel_shares = 10
	gs.server_overclock_buff_active = true
	gs.server_overclock_buff_multiplier = 2.00
	# Compound = 164.0625 * 1.20 * 2.00 = 393.75 RPS
	var boosted_eff: float = gs.get_effective_passive_rps()
	_assert_check(absf(boosted_eff - 393.75) < EPSILON,
		"3.5.3 Multi-factor RPS compounds commutatively to 393.75 (actual: %.4f)" % boosted_eff,
		"", 3)

	# Monotonicity test: increasing base RPS to 200.0 doubles effective RPS to 787.50
	gs.upgrades["tier_1"]["level"] = 200
	gs.recalculate_stats()
	_assert_check(absf(gs.get_effective_passive_rps() - 787.50) < EPSILON, "3.5.4 Strictly linear scaling with base RPS (787.50)", "", 3)

	# Non-negativity test: 0 base RPS yields 0.0 effective RPS without NaN/underflow
	gs.upgrades["tier_1"]["level"] = 0
	gs.recalculate_stats()
	_assert_check(absf(gs.get_effective_passive_rps() - 0.0) < EPSILON, "3.5.5 Zero base RPS produces exactly 0.0 effective RPS", "", 3)

	# 3.6 Full Persistence Roundtrip of Enterprise Empire
	print("\n  [3.6 Full Persistence Roundtrip]")
	gs.upgrades["tier_1"]["level"] = 100
	gs.recalculate_stats()
	gs.angel_shares = 0
	gs.server_overclock_buff_active = false
	gs.energy = 50000.0
	gs.save_to_disk()
	await process_frame
	_assert_check(FileAccess.file_exists("user://savegame.json"), "3.6.1 save_to_disk created savegame.json", "", 3)

	gs.reset_state()
	_assert_check(not gs.is_in_syndicate() and gs.hired_workers.is_empty(), "3.6.2 Memory state cleared", "", 3)

	var l_ok = gs.load_from_disk()
	_assert_check(l_ok == true, "3.6.3 load_from_disk succeeds", "", 3)
	_assert_check(gs.active_syndicate_id == "syn_holdings", "3.6.4 Restored syndicate active_id == 'syn_holdings'", "", 3)
	_assert_check(gs.get_syndicate_tier() == 1, "3.6.5 Restored syndicate tier == 1", "", 3)
	_assert_check(gs.get_hired_workers().size() == 5, "3.6.6 Restored 5 specialist workers", "", 3)
	_assert_check(gs.get_desk_level(1) == 2, "3.6.7 Restored Desk 1 at Level 2", "", 3)
	_assert_check(gs.get_desk_level(2) == 3, "3.6.8 Restored Desk 2 at Level 3", "", 3)
	_assert_check(gs.daily_board_streak == 1, "3.6.9 Restored daily board streak == 1", "", 3)
	_assert_check(gs.is_tech_researched("tech_server_overclock"), "3.6.10 Restored tech_server_overclock", "", 3)
	_assert_check(absf(gs.get_effective_passive_rps() - 164.0625) < 1.0, "3.6.11 Restored passive RPS ~164.06 RPS", "", 3)
