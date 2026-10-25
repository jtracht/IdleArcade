extends SceneTree

## =============================================================================
## Adversarial Stress-Test Suite: Challenger M2-1
## Target: Server Overclock Terminal & Pitch Stage Minigames
## File: IdleArcade/tests/test_challenger_m2_1.gd
##
## Focus Areas:
## 1. Hit Boundary Precision (0.0, 0.499, 0.501, 1.0, zone thresholds [0.42, 0.58, 0.25, 0.75]).
## 2. Multiplier Stack Logic and Duration Renewal in GameState.
## 3. ServerTerminal Station ↔ CyberSyncMinigame Integration & Multiplier Propagation.
## 4. Pitch Stage QTE Rapid Inputs, Invalid Indices, Timeout Handling, Streak Resets.
## 5. Re-entrancy Safety (Double input in same frame, double completion, double activation).
## =============================================================================

var pass_count: int = 0
var fail_count: int = 0
var findings: Array[String] = []

const EPSILON: float = 0.005
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
		findings.append("%s | %s" % [description, detail])
		fail_count += 1

func _init() -> void:
	print("\n====================================================================")
	print(">>> RUNNING CHALLENGER M2-1 ADVERSARIAL STRESS-TEST SUITE <<<")
	print("====================================================================")
	call_deferred("_run_challenger_tests")

func _cleanup_and_quit() -> void:
	print("\n--- TEARDOWN: Restoring Test Environment ---")
	if _had_save_backup:
		var f_res = FileAccess.open("user://savegame.json", FileAccess.WRITE)
		if f_res != null:
			f_res.store_string(_save_backup_text)
			f_res.close()
			print("  [CLEANUP] Restored original savegame.json")
	elif FileAccess.file_exists("user://savegame.json"):
		DirAccess.remove_absolute("user://savegame.json")

	for i in range(_mounted_nodes.size() - 1, -1, -1):
		var n = _mounted_nodes[i]
		if is_instance_valid(n):
			if n.get_parent() != null:
				n.get_parent().remove_child(n)
			n.free()
	_mounted_nodes.clear()

	print("\n====================================================================")
	print(">>> CHALLENGER M2-1 SUMMARY: %d PASSED, %d FAILED <<<" % [pass_count, fail_count])
	if findings.size() > 0:
		print(">>> CRITICAL FINDINGS / DEFECTS DETECTED (%d):" % findings.size())
		for f in findings:
			print("    * %s" % f)
	print("====================================================================")

	# Challenger script exits 0 if no defects, exits 1 if defects found (standard test runner exit code)
	if fail_count == 0:
		print(">>> VERDICT: APPROVE (0 Defect Failures) <<<\n")
		quit(0)
	else:
		printerr(">>> VERDICT: REQUEST_CHANGES (%d Defect Failures) <<<\n" % fail_count)
		quit(1)

func _run_challenger_tests() -> void:
	await process_frame

	# Backup savegame
	if FileAccess.file_exists("user://savegame.json"):
		var f_back = FileAccess.open("user://savegame.json", FileAccess.READ)
		if f_back != null:
			_save_backup_text = f_back.get_as_text()
			_had_save_backup = true
			f_back.close()

	# Mount GameState
	var gs_script = load("res://scripts/autoload/game_state.gd")
	var gs = root.get_node_or_null("GameState")
	if gs == null and gs_script != null:
		gs = gs_script.new()
		gs.name = "GameState"
		root.add_child(gs)
		_mounted_nodes.append(gs)
	if gs.has_method("reset_state"):
		gs.reset_state()

	# Mount HapticsManager
	var hm_script = load("res://scripts/autoload/haptics_manager.gd")
	var hm = root.get_node_or_null("HapticsManager")
	if hm == null and hm_script != null:
		hm = hm_script.new()
		hm.name = "HapticsManager"
		if "mock_mode" in hm:
			hm.mock_mode = true
		root.add_child(hm)
		_mounted_nodes.append(hm)

	# Mount AudioManager
	var am_script = load("res://scripts/autoload/audio_manager.gd")
	var am = root.get_node_or_null("AudioManager")
	if am == null and am_script != null:
		am = am_script.new()
		am.name = "AudioManager"
		root.add_child(am)
		_mounted_nodes.append(am)

	# Mount LiveEventManager
	var lem_script = load("res://scripts/autoload/live_event_manager.gd")
	var lem = root.get_node_or_null("LiveEventManager")
	if lem == null and lem_script != null:
		lem = lem_script.new()
		lem.name = "LiveEventManager"
		root.add_child(lem)
		_mounted_nodes.append(lem)

	await process_frame

	# Run all test suites
	await _test_server_overclock_boundary_precision()
	await _test_multiplier_stacking_and_duration_renewal(gs)
	await _test_server_terminal_integration_adversarial(gs)
	await _test_pitch_stage_qte_adversarial(gs)
	await _test_reentrancy_safety_adversarial(gs)

	_cleanup_and_quit()

## =============================================================================
## SUITE 1: Server Overclock Hit Boundary Precision
## =============================================================================
func _test_server_overclock_boundary_precision() -> void:
	print("\n--- SUITE 1: Server Overclock Hit Boundary Precision ---")
	var cyber_scene = load("res://scenes/ui/cyber_sync_minigame.tscn")
	_assert_check(cyber_scene != null, "S1.0 CyberSyncMinigame scene loaded successfully")
	if cyber_scene == null:
		return

	var minigame = cyber_scene.instantiate()
	root.add_child(minigame)
	await process_frame

	var target: float = minigame.target_position # 0.50
	var perf_win: float = minigame.perfect_window # 0.08
	var norm_win: float = minigame.normal_window # 0.25

	_assert_check(absf(target - 0.50) < EPSILON, "S1.1 Target center is exactly 0.50", "actual: %f" % target)
	_assert_check(absf(perf_win - 0.08) < EPSILON, "S1.2 Perfect window is exactly 0.08", "actual: %f" % perf_win)
	_assert_check(absf(norm_win - 0.25) < EPSILON, "S1.3 Normal window is exactly 0.25", "actual: %f" % norm_win)

	# 1. Exact Center (0.50)
	var res_center = minigame.evaluate_hit(0.50)
	_assert_check(res_center["rating"] == "Perfect" and res_center["is_perfect"] == true,
		"S1.4 Hit at center (0.50) -> Perfect", "got rating: %s" % res_center["rating"])
	_assert_check(absf(res_center["multiplier"] - 3.00) < EPSILON,
		"S1.5 Center hit awards 3.00x multiplier", "multiplier: %f" % res_center["multiplier"])
	_assert_check(absf(res_center["duration"] - 45.0) < EPSILON,
		"S1.6 Center hit awards 45.0s duration", "duration: %f" % res_center["duration"])

	# 2. Near-Center Precision Boundaries: 0.499 and 0.501
	var res_0499 = minigame.evaluate_hit(0.499)
	_assert_check(res_0499["rating"] == "Perfect" and res_0499["is_perfect"] == true,
		"S1.7 Hit at 0.499 -> Perfect (delta = 0.001)", "got: %s" % res_0499["rating"])
	_assert_check(absf(res_0499["multiplier"] - 3.00) < EPSILON, "S1.8 Hit at 0.499 multiplier is 3.00x")

	var res_0501 = minigame.evaluate_hit(0.501)
	_assert_check(res_0501["rating"] == "Perfect" and res_0501["is_perfect"] == true,
		"S1.9 Hit at 0.501 -> Perfect (delta = 0.001)", "got: %s" % res_0501["rating"])
	_assert_check(absf(res_0501["multiplier"] - 3.00) < EPSILON, "S1.10 Hit at 0.501 multiplier is 3.00x")

	# 3. Exact Perfect Zone Boundaries: 0.4200 and 0.5800 (diff = 0.0800 <= 0.0800)
	var res_lower_perf = minigame.evaluate_hit(0.4200)
	_assert_check(res_lower_perf["rating"] == "Perfect" and res_lower_perf["is_perfect"] == true,
		"S1.11 Hit at exact lower Perfect boundary (0.4200, diff 0.08) -> Perfect (<=)", "got: %s" % res_lower_perf["rating"])

	var res_upper_perf = minigame.evaluate_hit(0.5800)
	_assert_check(res_upper_perf["rating"] == "Perfect" and res_upper_perf["is_perfect"] == true,
		"S1.12 Hit at exact upper Perfect boundary (0.5800, diff 0.08) -> Perfect (<=)", "got: %s" % res_upper_perf["rating"])

	# 4. Just outside Perfect Zone: 0.4199 and 0.5801 (diff = 0.0801 > 0.0800)
	var res_just_out_lower = minigame.evaluate_hit(0.4199)
	_assert_check(res_just_out_lower["rating"] == "Good" and not res_just_out_lower["is_perfect"],
		"S1.13 Hit just outside Perfect lower (0.4199, diff 0.0801) -> Good", "got: %s" % res_just_out_lower["rating"])
	_assert_check(absf(res_just_out_lower["multiplier"] - 2.00) < EPSILON,
		"S1.14 Good rating awards 2.00x multiplier", "multiplier: %f" % res_just_out_lower["multiplier"])
	_assert_check(absf(res_just_out_lower["duration"] - 30.0) < EPSILON,
		"S1.15 Good rating awards 30.0s duration", "duration: %f" % res_just_out_lower["duration"])

	var res_just_out_upper = minigame.evaluate_hit(0.5801)
	_assert_check(res_just_out_upper["rating"] == "Good" and not res_just_out_upper["is_perfect"],
		"S1.16 Hit just outside Perfect upper (0.5801, diff 0.0801) -> Good", "got: %s" % res_just_out_upper["rating"])

	# 5. Exact Good/Normal Zone Boundaries: 0.2500 and 0.7500 (diff = 0.2500 <= 0.2500)
	var res_good_edge_lower = minigame.evaluate_hit(0.2500)
	_assert_check(res_good_edge_lower["rating"] == "Good",
		"S1.17 Hit at exact lower Good boundary (0.2500, diff 0.25) -> Good (<=)", "got: %s" % res_good_edge_lower["rating"])

	var res_good_edge_upper = minigame.evaluate_hit(0.7500)
	_assert_check(res_good_edge_upper["rating"] == "Good",
		"S1.18 Hit at exact upper Good boundary (0.7500, diff 0.25) -> Good (<=)", "got: %s" % res_good_edge_upper["rating"])

	# 6. Just outside Good Zone: 0.2499 and 0.7501 (diff = 0.2501 > 0.2500)
	var res_miss_lower = minigame.evaluate_hit(0.2499)
	_assert_check(res_miss_lower["rating"] == "Miss" and not res_miss_lower["is_perfect"],
		"S1.19 Hit just outside Good lower (0.2499, diff 0.2501) -> Miss", "got: %s" % res_miss_lower["rating"])
	_assert_check(absf(res_miss_lower["multiplier"] - 1.20) < EPSILON,
		"S1.20 Miss rating awards 1.20x comfort bonus", "multiplier: %f" % res_miss_lower["multiplier"])
	_assert_check(absf(res_miss_lower["duration"] - 15.0) < EPSILON,
		"S1.21 Miss rating awards 15.0s duration", "duration: %f" % res_miss_lower["duration"])

	var res_miss_upper = minigame.evaluate_hit(0.7501)
	_assert_check(res_miss_upper["rating"] == "Miss",
		"S1.22 Hit just outside Good upper (0.7501, diff 0.2501) -> Miss", "got: %s" % res_miss_upper["rating"])

	# 7. Extreme Bounds: 0.0 and 1.0
	var res_00 = minigame.evaluate_hit(0.0)
	_assert_check(res_00["rating"] == "Miss", "S1.23 Hit at extreme 0.0 -> Miss (diff 0.50)", "got: %s" % res_00["rating"])
	_assert_check(absf(res_00["multiplier"] - 1.20) < EPSILON, "S1.24 Hit at 0.0 multiplier is 1.20x")

	var res_10 = minigame.evaluate_hit(1.0)
	_assert_check(res_10["rating"] == "Miss", "S1.25 Hit at extreme 1.0 -> Miss (diff 0.50)", "got: %s" % res_10["rating"])
	_assert_check(absf(res_10["multiplier"] - 1.20) < EPSILON, "S1.26 Hit at 1.0 multiplier is 1.20x")

	# 8. Out of range: negative and > 1.0
	var res_neg = minigame.evaluate_hit(-0.5)
	_assert_check(res_neg["rating"] == "Miss", "S1.27 Hit at -0.5 -> Miss", "got: %s" % res_neg["rating"])
	var res_high = minigame.evaluate_hit(1.5)
	_assert_check(res_high["rating"] == "Miss", "S1.28 Hit at 1.5 -> Miss", "got: %s" % res_high["rating"])

	# 9. Test simulate_hit with exact 0.0 (ensure 0.0 is not treated as falsy defaulting to pulse_position)
	minigame._reset_minigame_state()
	var sim_00 = minigame.simulate_hit(0.0)
	_assert_check(sim_00["rating"] == "Miss" and absf(sim_00["position"] - 0.0) < EPSILON,
		"S1.29 simulate_hit(0.0) correctly registers position 0.0 without defaulting", "position: %f" % sim_00["position"])

	minigame.queue_free()
	await process_frame

## =============================================================================
## SUITE 2: Multiplier Stack Logic and Duration Renewal in GameState
## =============================================================================
func _test_multiplier_stacking_and_duration_renewal(gs: Node) -> void:
	print("\n--- SUITE 2: Multiplier Stacking & Duration Renewal in GameState ---")
	gs.reset_state()
	gs.base_passive_rps = 100.0

	# 2.1 Direct activation of Server Overclock Buff
	gs.activate_server_overclock_buff(45.0, 3.00)
	_assert_check(gs.server_overclock_buff_active == true, "S2.1 server_overclock_buff_active is true after activation")
	_assert_check(absf(gs.server_overclock_buff_multiplier - 3.00) < EPSILON,
		"S2.2 server_overclock_buff_multiplier set to 3.00x", "actual: %f" % gs.server_overclock_buff_multiplier)
	_assert_check(absf(gs.server_overclock_buff_timer - 45.0) < EPSILON,
		"S2.3 server_overclock_buff_timer set to 45.0s", "actual: %f" % gs.server_overclock_buff_timer)

	# 2.2 Effective RPS with Overclock
	var eff_rps_overclock: float = gs.get_effective_passive_rps()
	_assert_check(absf(eff_rps_overclock - 300.0) < EPSILON,
		"S2.4 Effective RPS boosted 3.0x (100.0 -> 300.0)", "actual: %f" % eff_rps_overclock)

	# 2.3 Stacking with tech_server_overclock (+25% / 1.25x)
	gs.researched_techs.append("tech_server_overclock")
	var eff_rps_stacked_tech: float = gs.get_effective_passive_rps()
	# 100.0 * 1.25 * 3.00 = 375.0
	_assert_check(absf(eff_rps_stacked_tech - 375.0) < EPSILON,
		"S2.5 Multiplicative stack: Base(100) * Tech(1.25) * Overclock(3.0) = 375.0", "actual: %f" % eff_rps_stacked_tech)

	# 2.4 Stacking with Campus Items (+5% per item)
	gs.collectibles_collected = 10 # +50% -> 1.50x
	var eff_rps_stacked_items: float = gs.get_effective_passive_rps()
	# 100.0 * 1.50 * 1.25 * 3.00 = 562.5
	_assert_check(absf(eff_rps_stacked_items - 562.5) < EPSILON,
		"S2.6 Multiplicative stack with Items(1.5x) = 562.5", "actual: %f" % eff_rps_stacked_items)

	# 2.5 Duration Decay & Renewal
	# Simulate 15.0s passing via multiple delta steps
	for step in range(150):
		gs._process(0.1)
	_assert_check(gs.server_overclock_buff_timer < 31.0 and gs.server_overclock_buff_timer > 29.0,
		"S2.7 Overclock timer decayed after 15s to ~30s", "remaining: %f" % gs.server_overclock_buff_timer)

	# Re-activate (Duration Renewal)
	gs.activate_server_overclock_buff(45.0, 3.00)
	_assert_check(absf(gs.server_overclock_buff_timer - 45.0) < EPSILON,
		"S2.8 Duration renewed back to 45.0s on re-activation", "timer: %f" % gs.server_overclock_buff_timer)
	_assert_check(absf(gs.server_overclock_buff_multiplier - 3.00) < EPSILON,
		"S2.9 Multiplier maintained at 3.00x on duration renewal")

	# 2.6 Expiration & Cleanup
	for step in range(500):
		gs._process(0.1)
	_assert_check(not gs.server_overclock_buff_active, "S2.10 server_overclock_buff_active is false after full expiration")
	_assert_check(absf(gs.server_overclock_buff_timer - 0.0) < EPSILON, "S2.11 timer is 0.0s after expiration")
	_assert_check(absf(gs.server_overclock_buff_multiplier - 1.00) < EPSILON,
		"S2.12 multiplier resets to 1.00 baseline", "actual: %f" % gs.server_overclock_buff_multiplier)

	# Clean reset
	gs.reset_state()

## =============================================================================
## SUITE 3: ServerTerminal Station ↔ CyberSyncMinigame Integration & Propagation
## Adversarial check: Does ServerTerminal forward the Phase 16 3-tier multipliers?
## =============================================================================
func _test_server_terminal_integration_adversarial(gs: Node) -> void:
	print("\n--- SUITE 3: ServerTerminal ↔ CyberSyncMinigame Integration ---")
	gs.reset_state()
	gs.base_passive_rps = 100.0

	var terminal_scene = load("res://scenes/server_terminal.tscn")
	_assert_check(terminal_scene != null, "S3.0 ServerTerminal scene loaded successfully")
	if terminal_scene == null:
		return

	var terminal = terminal_scene.instantiate()
	root.add_child(terminal)
	await process_frame

	# 3.1 Standalone minigame (no terminal_ref) applies 3.0x multiplier to GameState
	var cyber_scene = load("res://scenes/ui/cyber_sync_minigame.tscn")
	var standalone_minigame = cyber_scene.instantiate()
	root.add_child(standalone_minigame)
	await process_frame

	# Hit 3 Perfects standalone
	standalone_minigame.simulate_hit(0.50)
	standalone_minigame.simulate_hit(0.50)
	standalone_minigame.simulate_hit(0.50)
	await process_frame

	_assert_check(absf(gs.server_overclock_buff_multiplier - 3.00) < EPSILON,
		"S3.1 Standalone CyberSync awards 3.00x to GameState on Perfect session",
		"actual multiplier: %f" % gs.server_overclock_buff_multiplier)
	_assert_check(absf(gs.server_overclock_buff_timer - 45.0) < 0.2,
		"S3.2 Standalone CyberSync awards 45.0s duration to GameState",
		"actual duration: %f" % gs.server_overclock_buff_timer)

	standalone_minigame.queue_free()
	await process_frame
	gs.reset_state()

	# 3.2 Now test integrated with ServerTerminal:
	# When minigame is attached to ServerTerminal, does it pass the Phase 16 3.00x multiplier?
	terminal.cooldown_time_remaining = 0.0
	terminal.is_on_cooldown = false
	terminal.current_state = 0 # STATE_READY

	var attached_minigame = terminal.open_cyber_sync_minigame()
	_assert_check(attached_minigame != null, "S3.3 Terminal successfully opens attached CyberSyncMinigame")
	_assert_check(attached_minigame.terminal_ref == terminal, "S3.4 attached_minigame has terminal_ref bound to ServerTerminal")

	# Simulate 3 Perfect hits on attached minigame
	attached_minigame.simulate_hit(0.50)
	attached_minigame.simulate_hit(0.50)
	attached_minigame.simulate_hit(0.50)
	await process_frame

	# CHECK: Did GameState receive Phase 16 3.00x multiplier or did it get degraded to 2.00x?
	var actual_mult: float = gs.server_overclock_buff_multiplier
	_assert_check(absf(actual_mult - 3.00) < EPSILON,
		"S3.5 CRITICAL: ServerTerminal forwards 3.00x multiplier (Feature 10) to GameState upon Perfect session",
		"Observed multiplier: %f (Expected: 3.00x). If 2.00x, terminal_ref.complete_cyber_sync(is_perfect) discarded 3-tier multiplier!" % actual_mult)

	# 3.3 Test Good Session through ServerTerminal:
	gs.reset_state()
	terminal.cooldown_time_remaining = 0.0
	terminal.is_on_cooldown = false
	terminal.is_overclock_active = false
	terminal.current_state = 0 # STATE_READY

	var good_minigame = terminal.open_cyber_sync_minigame()
	# 3 Good hits (pos = 0.35 -> Good)
	good_minigame.simulate_hit(0.35)
	good_minigame.simulate_hit(0.35)
	good_minigame.simulate_hit(0.35)
	await process_frame

	var good_mult: float = gs.server_overclock_buff_multiplier
	var good_dur: float = gs.server_overclock_buff_timer
	_assert_check(absf(good_mult - 2.00) < EPSILON,
		"S3.6 CRITICAL: ServerTerminal forwards 2.00x multiplier (Feature 11) to GameState upon Good session",
		"Observed multiplier: %f (Expected: 2.00x). If 1.50x, ServerTerminal used legacy rps_boost_multiplier!" % good_mult)
	_assert_check(absf(good_dur - 30.0) < 1.0,
		"S3.7 CRITICAL: ServerTerminal forwards 30.0s duration (Feature 11) upon Good session",
		"Observed duration: %f (Expected: 30.0s). If 25.0s, ServerTerminal used legacy overclock_duration!" % good_dur)

	# 3.4 Test Miss Session through ServerTerminal:
	gs.reset_state()
	terminal.cooldown_time_remaining = 0.0
	terminal.is_on_cooldown = false
	terminal.is_overclock_active = false
	terminal.current_state = 0 # STATE_READY

	var miss_minigame = terminal.open_cyber_sync_minigame()
	# 3 Misses (pos = 0.0 -> Miss)
	miss_minigame.simulate_hit(0.0)
	miss_minigame.simulate_hit(0.0)
	miss_minigame.simulate_hit(0.0)
	await process_frame

	var miss_mult: float = gs.server_overclock_buff_multiplier
	var miss_dur: float = gs.server_overclock_buff_timer
	_assert_check(absf(miss_mult - 1.20) < EPSILON,
		"S3.8 CRITICAL: ServerTerminal forwards 1.20x comfort bonus (Feature 12) upon Miss session",
		"Observed multiplier: %f (Expected: 1.20x). If 1.50x, ServerTerminal used legacy rps_boost_multiplier!" % miss_mult)
	_assert_check(absf(miss_dur - 15.0) < 1.0,
		"S3.9 CRITICAL: ServerTerminal forwards 15.0s duration (Feature 12) upon Miss session",
		"Observed duration: %f (Expected: 15.0s). If 25.0s, ServerTerminal used legacy overclock_duration!" % miss_dur)

	terminal.queue_free()
	await process_frame

## =============================================================================
## SUITE 4: Pitch Stage QTE Rapid Inputs, Invalid Indices, Timeouts & Streaks
## =============================================================================
func _test_pitch_stage_qte_adversarial(gs: Node) -> void:
	print("\n--- SUITE 4: Pitch Stage QTE Rapid Inputs, Bounds & Streaks ---")
	gs.reset_state()
	gs.base_passive_rps = 100.0

	var pitch_modal_scene = load("res://scenes/ui/pitch_stage_minigame.tscn")
	_assert_check(pitch_modal_scene != null, "S4.0 PitchStageMinigame scene loaded successfully")
	if pitch_modal_scene == null:
		return

	var pitch = pitch_modal_scene.instantiate()
	root.add_child(pitch)
	await process_frame

	# 4.1 Invalid Button Indices Stress
	pitch.open_minigame()
	var initial_streak: int = pitch.current_streak
	var initial_round: int = pitch.current_round

	var res_neg1 = pitch.simulate_buzzword_choice(-1)
	_assert_check(not res_neg1, "S4.1 simulate_buzzword_choice(-1) returns false safely")
	_assert_check(pitch.current_streak == initial_streak and pitch.current_round == initial_round,
		"S4.2 -1 index does not mutate streak or round")

	var res_idx3 = pitch.simulate_buzzword_choice(3) # Size is 3 (indices 0, 1, 2)
	_assert_check(not res_idx3, "S4.3 simulate_buzzword_choice(3) (out-of-bounds) returns false safely")
	_assert_check(pitch.current_streak == initial_streak and pitch.current_round == initial_round,
		"S4.4 Out-of-bounds index 3 does not mutate streak or round")

	var res_idx999 = pitch.simulate_buzzword_choice(999)
	_assert_check(not res_idx999, "S4.5 simulate_buzzword_choice(999) returns false safely")

	var res_idx_huge_neg = pitch.simulate_buzzword_choice(-999)
	_assert_check(not res_idx_huge_neg, "S4.6 simulate_buzzword_choice(-999) returns false safely")

	# 4.2 Streak Resets on Wrong Answer
	# Reset to start fresh
	pitch.open_minigame()

	# Round 0: Pick correct buzzword
	var round0_correct_idx: int = -1
	for i in range(pitch.current_buzzwords.size()):
		if pitch.is_buzzword_matching(pitch.current_buzzwords[i], pitch.active_investor_type):
			round0_correct_idx = i
			break
	_assert_check(round0_correct_idx >= 0, "S4.7 Found matching buzzword for Round 0")
	pitch.simulate_buzzword_choice(round0_correct_idx)
	_assert_check(pitch.current_streak == 1, "S4.8 Streak incremented to 1 after correct choice")
	_assert_check(pitch.current_round == 1, "S4.9 Advanced to Round 1")

	# Round 1: Pick correct buzzword
	var round1_correct_idx: int = -1
	for i in range(pitch.current_buzzwords.size()):
		if pitch.is_buzzword_matching(pitch.current_buzzwords[i], pitch.active_investor_type):
			round1_correct_idx = i
			break
	_assert_check(round1_correct_idx >= 0, "S4.10 Found matching buzzword for Round 1")
	pitch.simulate_buzzword_choice(round1_correct_idx)
	_assert_check(pitch.current_streak == 2, "S4.11 Streak incremented to 2 after second correct choice")
	_assert_check(pitch.current_round == 2, "S4.12 Advanced to Round 2")

	# Round 2: Adversarially pick a WRONG (distractor) buzzword!
	var round2_wrong_idx: int = -1
	for i in range(pitch.current_buzzwords.size()):
		if not pitch.is_buzzword_matching(pitch.current_buzzwords[i], pitch.active_investor_type):
			round2_wrong_idx = i
			break
	_assert_check(round2_wrong_idx >= 0, "S4.13 Found distractor buzzword for Round 2")
	pitch.simulate_buzzword_choice(round2_wrong_idx)

	# Verify Streak was RESET to 0 on wrong answer!
	_assert_check(pitch.current_streak == 0,
		"S4.14 CRITICAL: Streak strictly reset to 0 upon wrong answer in Round 2",
		"Observed streak: %d (Expected: 0)" % pitch.current_streak)
	_assert_check(pitch.is_completed, "S4.15 Minigame marked completed after round 2")

	# 4.3 Scaling Grant Formula Accuracy
	# Formula: grant = max(1000.0, (base_min_grant + idle_level * 100.0) + rps * 15.0 * (1.0 + streak * 0.5))
	var base_with_level: float = 1000.0 + float(gs.get_idle_level()) * 100.0 # 1100.0 at level 1
	var expected_s0: float = maxf(1000.0, roundf(base_with_level + 100.0 * 15.0 * 1.0)) # 2600.0
	var grant_s0 = pitch.calculate_grant(0, 100.0)
	_assert_check(absf(grant_s0 - expected_s0) < EPSILON,
		"S4.16 Grant at Streak 0 (100 RPS) matches formula (%.0f)" % expected_s0, "actual: %f" % grant_s0)

	var expected_s2: float = maxf(1000.0, roundf(base_with_level + 100.0 * 15.0 * 2.0)) # 4100.0
	var grant_s2 = pitch.calculate_grant(2, 100.0)
	_assert_check(absf(grant_s2 - expected_s2) < EPSILON,
		"S4.17 Grant at Streak 2 (100 RPS) matches formula (%.0f)" % expected_s2, "actual: %f" % grant_s2)

	var expected_s3: float = maxf(1000.0, roundf(base_with_level + 100.0 * 15.0 * 2.5)) # 4850.0
	var grant_s3 = pitch.calculate_grant(3, 100.0)
	_assert_check(absf(grant_s3 - expected_s3) < EPSILON,
		"S4.18 Grant at Streak 3 (100 RPS) matches formula (%.0f)" % expected_s3, "actual: %f" % grant_s3)

	var expected_zero: float = maxf(1000.0, roundf(base_with_level)) # 1100.0
	var grant_zero_rps = pitch.calculate_grant(0, 0.0)
	_assert_check(absf(grant_zero_rps - expected_zero) < EPSILON,
		"S4.19 Zero RPS grant matches base floor (%.0f)" % expected_zero, "actual: %f" % grant_zero_rps)

	# 4.4 Timeout Handling Stress
	pitch.open_minigame()
	# Hit one correct answer
	for i in range(pitch.current_buzzwords.size()):
		if pitch.is_buzzword_matching(pitch.current_buzzwords[i], pitch.active_investor_type):
			pitch.simulate_buzzword_choice(i)
			break
	_assert_check(pitch.current_streak == 1, "S4.20 Streak is 1 before timeout")

	# Trigger timeout
	pitch.simulate_timeout()
	_assert_check(pitch.current_streak == 0, "S4.21 Timeout strictly resets streak to 0", "streak: %d" % pitch.current_streak)
	_assert_check(pitch.is_completed, "S4.22 Minigame completed upon timeout")
	_assert_check(not pitch.is_active, "S4.23 Minigame inactive upon timeout")

	# Attempting choices after timeout returns false
	var res_after_timeout = pitch.simulate_buzzword_choice(0)
	_assert_check(not res_after_timeout, "S4.24 Input after timeout safely returns false")

	# 4.5 Rapid Inputs Fuzzing Stress Test (15 consecutive inputs in same frame)
	pitch.open_minigame()
	var choice_returns: Array[bool] = []
	for fuzz_i in range(15):
		var res = pitch.simulate_buzzword_choice(fuzz_i % 3)
		choice_returns.append(res)

	_assert_check(pitch.is_completed, "S4.25 Rapid 15-input burst terminates cleanly with is_completed == true")
	_assert_check(pitch.current_round == 3, "S4.26 Round clamped to total_rounds (3)")
	# Tail calls must return false
	_assert_check(not choice_returns[14] and not choice_returns[13],
		"S4.27 Excess inputs beyond round 3 return false without crashing")

	pitch.queue_free()
	await process_frame

## =============================================================================
## SUITE 5: Re-entrancy Safety (Double Input in Same Frame)
## =============================================================================
func _test_reentrancy_safety_adversarial(gs: Node) -> void:
	print("\n--- SUITE 5: Re-entrancy Safety (Double Input in Same Frame) ---")
	gs.reset_state()

	# 5.1 CyberSyncMinigame Same-Frame Re-entrancy
	var cyber_scene = load("res://scenes/ui/cyber_sync_minigame.tscn")
	var cyber = cyber_scene.instantiate()
	root.add_child(cyber)
	await process_frame

	# Simulate double hit in same frame for node 0 and node 1
	var hit1 = cyber.simulate_hit(0.50)
	var hit2 = cyber.simulate_hit(0.50)
	_assert_check(hit1["rating"] == "Perfect" and hit2["rating"] == "Perfect",
		"S5.1 Double hit in same frame executes cleanly for nodes 0 and 1")
	_assert_check(cyber.current_node_index == 2, "S5.2 Current node index is 2")

	# Hit node 2 (completes) and immediately hit node 3 in same frame
	var hit3 = cyber.simulate_hit(0.50)
	var hit4_extra = cyber.simulate_hit(0.50)
	_assert_check(cyber.is_completed, "S5.3 Session completed on node 2 hit")
	_assert_check(hit4_extra["rating"] == "Completed",
		"S5.4 Same-frame re-entrant hit after completion returns 'Completed' guard",
		"actual rating: %s" % hit4_extra["rating"])
	_assert_check(cyber.current_node_index == 3, "S5.5 current_node_index clamped at 3 without overflow")

	# 5.2 ServerTerminal Same-Frame Double Interact
	var terminal_scene = load("res://scenes/server_terminal.tscn")
	var terminal = terminal_scene.instantiate()
	root.add_child(terminal)
	await process_frame

	terminal.interact()
	_assert_check(terminal.current_state == 1, "S5.6 First interact() enters STATE_PLAYING (1)")
	_assert_check(not terminal.can_activate(), "S5.7 can_activate() returns false immediately")

	# Second interact in same frame
	terminal.interact()
	_assert_check(terminal.current_state == 1,
		"S5.8 Second interact() in same frame safely blocked by can_activate() guard")

	# 5.3 PitchStage Same-Frame Double Open
	var pitch_stage_scene = load("res://scenes/pitch_stage.tscn")
	var stage = pitch_stage_scene.instantiate()
	root.add_child(stage)
	await process_frame

	var modal1 = stage.open_pitch_minigame()
	var modal2 = stage.open_pitch_minigame()
	_assert_check(modal1 == modal2, "S5.9 Double open_pitch_minigame() returns existing modal without duplication")
	_assert_check(stage.current_state == 1, "S5.10 PitchStage in STATE_PLAYING (1)")
	_assert_check(not stage.can_pitch(), "S5.11 can_pitch() returns false while modal active")

	# 5.4 PitchStageMinigame Double complete_pitch in Same Frame
	var initial_energy: float = gs.energy
	if modal1 != null and modal1.has_method("complete_pitch"):
		modal1.complete_pitch(true)
		var energy_after_first: float = gs.energy
		modal1.complete_pitch(true) # Re-entrant second call in same frame
		var energy_after_second: float = gs.energy
		_assert_check(absf(energy_after_first - energy_after_second) < EPSILON,
			"S5.12 Double complete_pitch() in same frame does not double-award energy",
			"first: %f, second: %f" % [energy_after_first, energy_after_second])

	cyber.queue_free()
	terminal.queue_free()
	stage.queue_free()
	await process_frame
