extends SceneTree

## =============================================================================
## Adversarial Stress-Test Suite: Challenger M2-IT2-1
## Target: Server Overclock Terminal & Pitch Stage Minigames (Phase 16 Iteration 2)
## File: IdleArcade/tests/test_challenger_m2_it2.gd
##
## Focus Areas:
## 1. Hit Boundary Precision & Epsilon Fuzzing (0.4200, 0.4199, 0.5800, 0.5801, 0.2500, 0.2499, 0.7500, 0.7501).
## 2. Multiplier & Duration Forwarding Matrix (Full 3-Hit Session Permutations & Overrides).
## 3. Cancel / Dismiss Behavior & Anti-Exploit Verification (Zero Free Buffs on Early Exit).
## 4. State Lifecycle, Cooldown Enforcement & Re-triggering Dynamics.
## 5. Pitch Stage Investor Thesis Validation, Streak Resets & Scaling Grant Invariants.
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
	print(">>> RUNNING CHALLENGER M2-IT2-1 ADVERSARIAL STRESS-TEST SUITE <<<")
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
	print(">>> CHALLENGER M2-IT2-1 SUMMARY: %d PASSED, %d FAILED <<<" % [pass_count, fail_count])
	if fail_count > 0:
		print(">>> DEFECTS DETECTED (%d):" % fail_count)
		for f in findings:
			print("    * %s" % f)
		print("====================================================================")
		print(">>> VERDICT: REQUEST_CHANGES (%d Defect Failures) <<<" % fail_count)
		quit(1)
	else:
		print("====================================================================")
		print(">>> VERDICT: APPROVE (0 Defect Failures) <<<")
		quit(0)

func _mount_node(node: Node) -> void:
	root.add_child(node)
	_mounted_nodes.append(node)

func _run_challenger_tests() -> void:
	# Backup savegame
	if FileAccess.file_exists("user://savegame.json"):
		var f_back = FileAccess.open("user://savegame.json", FileAccess.READ)
		if f_back != null:
			_save_backup_text = f_back.get_as_text()
			_had_save_backup = true
			f_back.close()

	var gs = root.get_node_or_null("/root/GameState")
	if gs == null:
		printerr("FATAL: GameState autoload not found.")
		quit(1)
		return

	# Reset GameState buffs
	gs.server_overclock_buff_timer = 0.0
	gs.server_overclock_buff_remaining = 0.0
	gs.server_overclock_buff_multiplier = 1.0
	gs.server_overclock_buff_active = false
	gs.reset_all_station_cooldowns()

	_test_suite_1_boundary_precision()
	_test_suite_2_multiplier_forwarding_matrix(gs)
	_test_suite_3_cancel_dismiss_anti_exploit(gs)
	_test_suite_4_lifecycle_and_cooldown(gs)
	_test_suite_5_pitch_stage_stress(gs)

	_cleanup_and_quit()

## =============================================================================
## SUITE 1: BOUNDARY PRECISION & EPSILON FUZZING
## =============================================================================
func _test_suite_1_boundary_precision() -> void:
	print("\n--- SUITE 1: Boundary Precision & Epsilon Fuzzing ---")
	var scene = load("res://scenes/ui/cyber_sync_minigame.tscn")
	_assert_check(scene != null, "S1.0 CyberSyncMinigame scene loaded successfully")
	if scene == null:
		return

	var minigame = scene.instantiate()
	_mount_node(minigame)

	# Baseline geometry checks
	_assert_check(absf(minigame.target_position - 0.50) < 0.0001, "S1.1 Target center is exactly 0.50")
	_assert_check(absf(minigame.perfect_window - 0.08) < 0.0001, "S1.2 Perfect window is 0.08")
	_assert_check(absf(minigame.normal_window - 0.25) < 0.0001, "S1.3 Normal window is 0.25")

	# Dead center (0.50)
	var r_center = minigame.evaluate_hit(0.50)
	_assert_check(r_center["rating"] == "Perfect", "S1.4 Hit at center (0.50) -> Perfect")
	_assert_check(absf(r_center["multiplier"] - 3.00) < EPSILON, "S1.5 Center hit multiplier is 3.00x")
	_assert_check(absf(r_center["duration"] - 45.0) < EPSILON, "S1.6 Center hit duration is 45.0s")

	# Exact boundaries: 0.4200 and 0.5800 (Perfect thresholds)
	var r_p_low = minigame.evaluate_hit(0.4200)
	_assert_check(r_p_low["rating"] == "Perfect", "S1.7 Hit at exact lower Perfect boundary (0.4200) -> Perfect", "got: %s" % r_p_low["rating"])
	_assert_check(absf(r_p_low["multiplier"] - 3.00) < EPSILON, "S1.8 0.4200 multiplier is 3.00x")

	var r_p_high = minigame.evaluate_hit(0.5800)
	_assert_check(r_p_high["rating"] == "Perfect", "S1.9 Hit at exact upper Perfect boundary (0.5800) -> Perfect", "got: %s" % r_p_high["rating"])
	_assert_check(absf(r_p_high["multiplier"] - 3.00) < EPSILON, "S1.10 0.5800 multiplier is 3.00x")

	# Just outside Perfect boundaries: 0.4199 and 0.5801 (Good threshold)
	var r_g_low = minigame.evaluate_hit(0.4199)
	_assert_check(r_g_low["rating"] == "Good", "S1.11 Hit at 0.4199 (1 tick below Perfect) -> Good", "got: %s" % r_g_low["rating"])
	_assert_check(absf(r_g_low["multiplier"] - 2.00) < EPSILON, "S1.12 0.4199 multiplier is 2.00x")
	_assert_check(absf(r_g_low["duration"] - 30.0) < EPSILON, "S1.13 0.4199 duration is 30.0s")

	var r_g_high = minigame.evaluate_hit(0.5801)
	_assert_check(r_g_high["rating"] == "Good", "S1.14 Hit at 0.5801 (1 tick above Perfect) -> Good", "got: %s" % r_g_high["rating"])
	_assert_check(absf(r_g_high["multiplier"] - 2.00) < EPSILON, "S1.15 0.5801 multiplier is 2.00x")

	# Exact Good boundaries: 0.2500 and 0.7500
	var r_norm_low = minigame.evaluate_hit(0.2500)
	_assert_check(r_norm_low["rating"] == "Good", "S1.16 Hit at exact lower Good boundary (0.2500) -> Good", "got: %s" % r_norm_low["rating"])
	_assert_check(absf(r_norm_low["multiplier"] - 2.00) < EPSILON, "S1.17 0.2500 multiplier is 2.00x")

	var r_norm_high = minigame.evaluate_hit(0.7500)
	_assert_check(r_norm_high["rating"] == "Good", "S1.18 Hit at exact upper Good boundary (0.7500) -> Good", "got: %s" % r_norm_high["rating"])
	_assert_check(absf(r_norm_high["multiplier"] - 2.00) < EPSILON, "S1.19 0.7500 multiplier is 2.00x")

	# Just outside Good boundaries: 0.2499 and 0.7501 (Miss threshold)
	var r_m_low = minigame.evaluate_hit(0.2499)
	_assert_check(r_m_low["rating"] == "Miss", "S1.20 Hit at 0.2499 (1 tick below Good) -> Miss", "got: %s" % r_m_low["rating"])
	_assert_check(absf(r_m_low["multiplier"] - 1.20) < EPSILON, "S1.21 0.2499 awards 1.20x comfort bonus")
	_assert_check(absf(r_m_low["duration"] - 15.0) < EPSILON, "S1.22 0.2499 awards 15.0s duration")

	var r_m_high = minigame.evaluate_hit(0.7501)
	_assert_check(r_m_high["rating"] == "Miss", "S1.23 Hit at 0.7501 (1 tick above Good) -> Miss", "got: %s" % r_m_high["rating"])
	_assert_check(absf(r_m_high["multiplier"] - 1.20) < EPSILON, "S1.24 0.7501 awards 1.20x comfort bonus")

	# Micro-epsilon fuzzing (HIT_EPSILON = 0.00005)
	# Lower boundary threshold = 0.50 - 0.08 = 0.4200.
	# At 0.4200 - 0.00004 = 0.41996, diff = 0.08004 <= 0.08005 -> Perfect
	var r_eps_in_low = minigame.evaluate_hit(0.41996)
	_assert_check(r_eps_in_low["rating"] == "Perfect", "S1.25 Hit at 0.41996 (diff 0.08004, within HIT_EPSILON) -> Perfect")

	# At 0.4200 - 0.00006 = 0.41994, diff = 0.08006 > 0.08005 -> Good
	var r_eps_out_low = minigame.evaluate_hit(0.41994)
	_assert_check(r_eps_out_low["rating"] == "Good", "S1.26 Hit at 0.41994 (diff 0.08006, outside HIT_EPSILON) -> Good")

	# Upper boundary threshold = 0.50 + 0.08 = 0.5800.
	# At 0.5800 + 0.00004 = 0.58004, diff = 0.08004 <= 0.08005 -> Perfect
	var r_eps_in_high = minigame.evaluate_hit(0.58004)
	_assert_check(r_eps_in_high["rating"] == "Perfect", "S1.27 Hit at 0.58004 (diff 0.08004, within HIT_EPSILON) -> Perfect")

	# At 0.5800 + 0.00006 = 0.58006, diff = 0.08006 > 0.08005 -> Good
	var r_eps_out_high = minigame.evaluate_hit(0.58006)
	_assert_check(r_eps_out_high["rating"] == "Good", "S1.28 Hit at 0.58006 (diff 0.08006, outside HIT_EPSILON) -> Good")

	# Lower Good threshold = 0.50 - 0.25 = 0.2500.
	# At 0.2500 - 0.00004 = 0.24996, diff = 0.25004 <= 0.25005 -> Good
	var r_eps_in_norm = minigame.evaluate_hit(0.24996)
	_assert_check(r_eps_in_norm["rating"] == "Good", "S1.29 Hit at 0.24996 (diff 0.25004, within HIT_EPSILON) -> Good")

	# At 0.2500 - 0.00006 = 0.24994, diff = 0.25006 > 0.25005 -> Miss
	var r_eps_out_norm = minigame.evaluate_hit(0.24994)
	_assert_check(r_eps_out_norm["rating"] == "Miss", "S1.30 Hit at 0.24994 (diff 0.25006, outside HIT_EPSILON) -> Miss")

	# Extreme / degenerate inputs
	var r_neg = minigame.evaluate_hit(-10.0)
	_assert_check(r_neg["rating"] == "Miss", "S1.31 Hit at extreme negative (-10.0) -> Miss")
	_assert_check(absf(r_neg["multiplier"] - 1.20) < EPSILON, "S1.32 Negative hit awards 1.20x comfort bonus")

	var r_pos = minigame.evaluate_hit(10.0)
	_assert_check(r_pos["rating"] == "Miss", "S1.33 Hit at extreme positive (10.0) -> Miss")
	_assert_check(absf(r_pos["multiplier"] - 1.20) < EPSILON, "S1.34 Extreme positive hit awards 1.20x comfort bonus")

## =============================================================================
## SUITE 2: MULTIPLIER & DURATION FORWARDING MATRIX
## =============================================================================
func _test_suite_2_multiplier_forwarding_matrix(gs: Node) -> void:
	print("\n--- SUITE 2: Multiplier & Duration Forwarding Matrix ---")
	var st_scene = load("res://scenes/server_terminal.tscn")
	_assert_check(st_scene != null, "S2.0 ServerTerminal scene loaded")
	if st_scene == null:
		return

	var terminal = st_scene.instantiate()
	_mount_node(terminal)

	var permutations = [
		{ "name": "3x Perfect", "hits": [0.50, 0.50, 0.50], "expected_rating": "Perfect", "expected_mult": 3.00, "expected_dur": 45.0, "is_perf": true },
		{ "name": "2x Perfect + 1x Good", "hits": [0.50, 0.50, 0.35], "expected_rating": "Perfect", "expected_mult": 3.00, "expected_dur": 45.0, "is_perf": true },
		{ "name": "2x Perfect + 1x Miss", "hits": [0.50, 0.50, 0.05], "expected_rating": "Perfect", "expected_mult": 3.00, "expected_dur": 45.0, "is_perf": true },
		{ "name": "1x Perfect + 2x Good", "hits": [0.50, 0.35, 0.65], "expected_rating": "Good", "expected_mult": 2.00, "expected_dur": 30.0, "is_perf": false },
		{ "name": "1x Perfect + 2x Miss", "hits": [0.50, 0.05, 0.95], "expected_rating": "Good", "expected_mult": 2.00, "expected_dur": 30.0, "is_perf": false },
		{ "name": "3x Good", "hits": [0.35, 0.65, 0.35], "expected_rating": "Good", "expected_mult": 2.00, "expected_dur": 30.0, "is_perf": false },
		{ "name": "1x Good + 2x Miss", "hits": [0.35, 0.05, 0.95], "expected_rating": "Good", "expected_mult": 2.00, "expected_dur": 30.0, "is_perf": false },
		{ "name": "3x Miss", "hits": [0.05, 0.95, 0.02], "expected_rating": "Miss", "expected_mult": 1.20, "expected_dur": 15.0, "is_perf": false }
	]

	var idx: int = 1
	for p in permutations:
		# Reset state
		gs.server_overclock_buff_timer = 0.0
		gs.server_overclock_buff_multiplier = 1.0
		gs.server_overclock_buff_active = false
		terminal.is_overclock_active = false
		terminal.is_on_cooldown = false
		terminal.current_state = terminal.StationState.STATE_READY

		var modal = terminal.open_cyber_sync_minigame()
		_assert_check(modal != null and modal.terminal_ref == terminal, "S2.%d.0 Modal opened with bound terminal (%s)" % [idx, p["name"]])

		# Simulate 3 hits
		for hit_pos in p["hits"]:
			modal.simulate_hit(hit_pos)

		_assert_check(modal.is_completed == true, "S2.%d.1 Session completed (%s)" % [idx, p["name"]])

		# Verify GameState received exact Phase 16 multipliers and durations
		_assert_check(gs.server_overclock_buff_active == true, "S2.%d.2 GameState buff active (%s)" % [idx, p["name"]])
		_assert_check(absf(gs.server_overclock_buff_multiplier - p["expected_mult"]) < EPSILON,
			"S2.%d.3 GameState multiplier == %.2fx (%s)" % [idx, p["expected_mult"], p["name"]],
			"got: %.2f" % gs.server_overclock_buff_multiplier)
		_assert_check(absf(gs.server_overclock_buff_timer - p["expected_dur"]) < EPSILON,
			"S2.%d.4 GameState duration == %.1fs (%s)" % [idx, p["expected_dur"], p["name"]],
			"got: %.1f" % gs.server_overclock_buff_timer)

		# Verify ServerTerminal state
		_assert_check(terminal.is_overclock_active == true, "S2.%d.5 Terminal overclock active (%s)" % [idx, p["name"]])
		_assert_check(absf(terminal.current_multiplier - p["expected_mult"]) < EPSILON,
			"S2.%d.6 Terminal current_multiplier == %.2fx (%s)" % [idx, p["expected_mult"], p["name"]])
		_assert_check(terminal.is_perfect_overclock == p["is_perf"],
			"S2.%d.7 Terminal is_perfect_overclock == %s (%s)" % [idx, str(p["is_perf"]), p["name"]])

		modal.close_minigame()
		idx += 1

	# Test custom overrides via complete_cyber_sync()
	gs.server_overclock_buff_timer = 0.0
	gs.server_overclock_buff_multiplier = 1.0
	gs.server_overclock_buff_active = false
	terminal.complete_cyber_sync(false, "Custom", 55.0, 4.50)
	_assert_check(absf(gs.server_overclock_buff_multiplier - 4.50) < EPSILON, "S2.9.1 Custom multiplier 4.50x forwarded cleanly", "got: %.2f" % gs.server_overclock_buff_multiplier)
	_assert_check(absf(gs.server_overclock_buff_timer - 55.0) < EPSILON, "S2.9.2 Custom duration 55.0s forwarded cleanly", "got: %.1f" % gs.server_overclock_buff_timer)

## =============================================================================
## SUITE 3: CANCEL / DISMISS & ANTI-EXPLOIT INTEGRITY (ZERO FREE BUFFS)
## =============================================================================
func _test_suite_3_cancel_dismiss_anti_exploit(gs: Node) -> void:
	print("\n--- SUITE 3: Cancel / Dismiss & Anti-Exploit Integrity ---")
	var st_scene = load("res://scenes/server_terminal.tscn")
	var terminal = st_scene.instantiate()
	_mount_node(terminal)

	# --- S3.1 Cancel on open without any hits ---
	gs.server_overclock_buff_timer = 0.0
	gs.server_overclock_buff_multiplier = 1.0
	gs.server_overclock_buff_active = false
	terminal.is_overclock_active = false
	terminal.is_on_cooldown = false
	terminal.current_state = terminal.StationState.STATE_READY

	terminal.interact() # Starts overclock baseline and opens modal
	_assert_check(terminal.is_minigame_active == true, "S3.1.1 Terminal minigame is active upon interact")
	
	# User presses Close or ESC immediately without hitting nodes
	var modal1 = terminal._minigame_instance
	_assert_check(modal1 != null, "S3.1.2 Modal instance exists")
	modal1.close_minigame()

	# Reversion verification: NO free buff!
	_assert_check(gs.server_overclock_buff_active == false, "S3.1.3 CRITICAL: GameState buff active reverted to false upon cancel")
	_assert_check(absf(gs.server_overclock_buff_multiplier - 1.0) < EPSILON, "S3.1.4 CRITICAL: GameState multiplier reverted to 1.0 upon cancel", "got: %.2f" % gs.server_overclock_buff_multiplier)
	_assert_check(gs.server_overclock_buff_timer <= 0.0, "S3.1.5 CRITICAL: GameState timer reverted to 0.0 upon cancel", "got: %.2f" % gs.server_overclock_buff_timer)
	_assert_check(terminal.is_overclock_active == false, "S3.1.6 Terminal is_overclock_active reverted to false")
	_assert_check(terminal.current_state == terminal.StationState.STATE_READY, "S3.1.7 Terminal restored to STATE_READY")

	# --- S3.2 Cancel mid-session after 1 Perfect hit ---
	gs.server_overclock_buff_timer = 0.0
	gs.server_overclock_buff_multiplier = 1.0
	gs.server_overclock_buff_active = false
	terminal.is_overclock_active = false
	terminal.is_on_cooldown = false
	terminal.current_state = terminal.StationState.STATE_READY

	terminal.interact()
	var modal2 = terminal._minigame_instance
	modal2.simulate_hit(0.50) # 1st hit is Perfect
	_assert_check(modal2.current_node_index == 1, "S3.2.1 Node 1 hit registered")
	_assert_check(modal2.is_completed == false, "S3.2.2 Session not completed after 1 hit")

	# Close early
	modal2.close_minigame()
	_assert_check(gs.server_overclock_buff_active == false, "S3.2.3 GameState buff active is false after early exit at node 1")
	_assert_check(absf(gs.server_overclock_buff_multiplier - 1.0) < EPSILON, "S3.2.4 GameState multiplier is 1.0 after early exit at node 1")
	_assert_check(gs.server_overclock_buff_timer <= 0.0, "S3.2.5 GameState timer is 0.0 after early exit at node 1")
	_assert_check(terminal.is_overclock_active == false, "S3.2.6 Terminal overclock active is false")

	# --- S3.3 Cancel mid-session after 2 Perfect hits ---
	gs.server_overclock_buff_timer = 0.0
	gs.server_overclock_buff_multiplier = 1.0
	gs.server_overclock_buff_active = false
	terminal.is_overclock_active = false
	terminal.is_on_cooldown = false
	terminal.current_state = terminal.StationState.STATE_READY

	terminal.interact()
	var modal3 = terminal._minigame_instance
	modal3.simulate_hit(0.50) # Node 0
	modal3.simulate_hit(0.50) # Node 1
	_assert_check(modal3.perfect_hits_count == 2, "S3.3.1 Perfect hit count is 2")
	_assert_check(modal3.is_completed == false, "S3.3.2 Session not yet completed")

	# Close early before 3rd node
	modal3.close_minigame()
	_assert_check(gs.server_overclock_buff_active == false, "S3.3.3 GameState buff active is false after early exit at node 2")
	_assert_check(absf(gs.server_overclock_buff_multiplier - 1.0) < EPSILON, "S3.3.4 GameState multiplier is 1.0 after early exit at node 2")
	_assert_check(gs.server_overclock_buff_timer <= 0.0, "S3.3.5 GameState timer is 0.0 after early exit at node 2")

	# --- S3.4 Completed session close RETAINS the earned buff ---
	gs.server_overclock_buff_timer = 0.0
	gs.server_overclock_buff_multiplier = 1.0
	gs.server_overclock_buff_active = false
	terminal.is_overclock_active = false
	terminal.is_on_cooldown = false
	terminal.current_state = terminal.StationState.STATE_READY

	terminal.interact()
	var modal4 = terminal._minigame_instance
	modal4.simulate_hit(0.50)
	modal4.simulate_hit(0.50)
	modal4.simulate_hit(0.50)
	_assert_check(modal4.is_completed == true, "S3.4.1 Session completed with 3 hits")
	_assert_check(absf(gs.server_overclock_buff_multiplier - 3.00) < EPSILON, "S3.4.2 Perfect overclock awarded (3.00x)")

	# Now player closes completed modal
	modal4.close_minigame()
	_assert_check(gs.server_overclock_buff_active == true, "S3.4.3 Earned buff REMAINS active after closing completed modal")
	_assert_check(absf(gs.server_overclock_buff_multiplier - 3.00) < EPSILON, "S3.4.4 Multiplier maintained at 3.00x after closing")
	_assert_check(gs.server_overclock_buff_timer > 40.0, "S3.4.5 Duration maintained at ~45.0s after closing")

	# --- S3.5 Pitch Stage cancel/dismiss: Zero Free Grants ---
	var ps_scene = load("res://scenes/pitch_stage.tscn")
	_assert_check(ps_scene != null, "S3.5.0 PitchStage scene loaded")
	if ps_scene == null:
		return

	var pitch_stage = ps_scene.instantiate()
	_mount_node(pitch_stage)
	pitch_stage.is_pitch_ready = true
	pitch_stage.is_on_cooldown = false
	pitch_stage.current_state = pitch_stage.StationState.STATE_READY

	var energy_before = gs.energy
	var p_modal = pitch_stage.open_pitch_minigame()
	_assert_check(p_modal != null, "S3.5.1 Pitch modal opened")
	_assert_check(pitch_stage.current_state == pitch_stage.StationState.STATE_PLAYING, "S3.5.2 PitchStage in STATE_PLAYING")

	# Answer 1 round correctly
	var matching_idx = -1
	var current_words = p_modal.get_current_buzzwords()
	var inv_type = p_modal.get_active_investor_type()
	for i in range(current_words.size()):
		if p_modal.is_buzzword_matching(current_words[i], inv_type):
			matching_idx = i
			break
	if matching_idx >= 0:
		p_modal.simulate_buzzword_choice(matching_idx)
	_assert_check(p_modal.get_current_streak() == 1, "S3.5.3 Streak is 1 after round 1")
	_assert_check(p_modal.is_completed == false, "S3.5.4 Pitch session still in progress")

	# Dismiss modal early
	p_modal.close_minigame()
	_assert_check(absf(gs.energy - energy_before) < EPSILON, "S3.5.5 CRITICAL: Zero free energy grant awarded on early pitch dismiss", "before: %.1f, after: %.1f" % [energy_before, gs.energy])
	_assert_check(pitch_stage.is_minigame_active == false, "S3.5.6 PitchStage minigame inactive after dismiss")
	_assert_check(pitch_stage.current_state == pitch_stage.StationState.STATE_READY, "S3.5.7 PitchStage restored to STATE_READY")

## =============================================================================
## SUITE 4: STATE LIFECYCLE & COOLDOWN ENFORCEMENT
## =============================================================================
func _test_suite_4_lifecycle_and_cooldown(gs: Node) -> void:
	print("\n--- SUITE 4: State Lifecycle & Cooldown Enforcement ---")
	var st_scene = load("res://scenes/server_terminal.tscn")
	var terminal = st_scene.instantiate()
	_mount_node(terminal)

	gs.server_overclock_buff_timer = 0.0
	gs.server_overclock_buff_multiplier = 1.0
	gs.server_overclock_buff_active = false
	terminal.is_overclock_active = false
	terminal.is_on_cooldown = false
	terminal.current_state = terminal.StationState.STATE_READY

	# Complete a session to activate overclock
	terminal.interact()
	var modal = terminal._minigame_instance
	modal.simulate_hit(0.50)
	modal.simulate_hit(0.50)
	modal.simulate_hit(0.50)
	modal.close_minigame()
	terminal._minigame_instance = null

	_assert_check(terminal.is_overclock_active == true, "S4.1 Overclock is active")
	_assert_check(terminal.can_activate() == false, "S4.2 can_activate() is false during active overclock")

	# Calling interact while overclock active must be rejected
	var prev_timer = terminal.overclock_time_remaining
	terminal.interact()
	_assert_check(terminal._minigame_instance == null, "S4.3 interact() while active does not spawn new modal")
	_assert_check(terminal.overclock_time_remaining <= prev_timer, "S4.4 interact() does not artificially reset or extend timer")

	# Simulate overclock expiration
	terminal.overclock_time_remaining = 0.1
	terminal._process(0.2) # Triggers _end_overclock()

	_assert_check(terminal.is_overclock_active == false, "S4.5 Overclock ended after duration")
	_assert_check(terminal.is_on_cooldown == true, "S4.6 Terminal placed on cooldown")
	_assert_check(terminal.current_state == terminal.StationState.STATE_COOLDOWN, "S4.7 Terminal in STATE_COOLDOWN")
	_assert_check(absf(terminal.cooldown_time_remaining - terminal.overclock_cooldown) < 1.0, "S4.8 Cooldown timer initialized to ~60s")
	_assert_check(terminal.can_activate() == false, "S4.9 can_activate() locked during cooldown")

	# Interact during cooldown must be rejected
	terminal.interact()
	_assert_check(terminal.is_minigame_active == false, "S4.10 interact() rejected during cooldown")

	# Simulate cooldown completion
	terminal.cooldown_time_remaining = 0.1
	terminal._process(0.2)
	_assert_check(terminal.is_on_cooldown == false, "S4.11 Cooldown ended")
	_assert_check(terminal.current_state == terminal.StationState.STATE_READY, "S4.12 Terminal restored to STATE_READY")
	_assert_check(terminal.can_activate() == true, "S4.13 can_activate() restored to true")

## =============================================================================
## SUITE 5: PITCH STAGE INVESTOR THESIS & STRESS
## =============================================================================
func _test_suite_5_pitch_stage_stress(gs: Node) -> void:
	print("\n--- SUITE 5: Pitch Stage Investor Thesis & Stress ---")
	var modal_scene = load("res://scenes/ui/pitch_stage_minigame.tscn")
	_assert_check(modal_scene != null, "S5.0 PitchStageMinigame scene loaded")
	if modal_scene == null:
		return

	var p_modal = modal_scene.instantiate()
	_mount_node(p_modal)

	# Validate thesis matching across all 4 archetypes
	var archetypes = ["Tech VC", "Crypto Baron", "Growth Hacker", "Enterprise Titan"]
	for arch in archetypes:
		_assert_check(p_modal.INVESTOR_PROFILES.has(arch), "S5.1 Profile exists: %s" % arch)
		var profile = p_modal.INVESTOR_PROFILES[arch]
		var keywords: Array = profile.get("matching_keywords", [])
		_assert_check(keywords.size() >= 3, "S5.2 Profile %s has >= 3 thesis keywords" % arch)
		for kw in keywords:
			_assert_check(p_modal.is_buzzword_matching(str(kw), arch) == true, "S5.3 Keyword '%s' matches %s" % [str(kw), arch])
		_assert_check(p_modal.is_buzzword_matching("IrrelevantBogusKeyword", arch) == false, "S5.4 Bogus keyword rejected by %s" % arch)

	# Full streak play-through: 3 consecutive matches
	p_modal.open_minigame(null)
	var words_r0 = p_modal.get_current_buzzwords()
	var inv_r0 = p_modal.get_active_investor_type()
	var match_idx0 = -1
	for i in range(words_r0.size()):
		if p_modal.is_buzzword_matching(words_r0[i], inv_r0):
			match_idx0 = i
			break
	_assert_check(match_idx0 >= 0, "S5.5 Round 0 has matching thesis keyword")
	p_modal.simulate_buzzword_choice(match_idx0)
	_assert_check(p_modal.get_current_streak() == 1, "S5.6 Streak is 1 after round 0 match")

	var words_r1 = p_modal.get_current_buzzwords()
	var inv_r1 = p_modal.get_active_investor_type()
	var match_idx1 = -1
	for i in range(words_r1.size()):
		if p_modal.is_buzzword_matching(words_r1[i], inv_r1):
			match_idx1 = i
			break
	_assert_check(match_idx1 >= 0, "S5.7 Round 1 has matching thesis keyword")
	p_modal.simulate_buzzword_choice(match_idx1)
	_assert_check(p_modal.get_current_streak() == 2, "S5.8 Streak is 2 after round 1 match")

	var words_r2 = p_modal.get_current_buzzwords()
	var inv_r2 = p_modal.get_active_investor_type()
	var match_idx2 = -1
	for i in range(words_r2.size()):
		if p_modal.is_buzzword_matching(words_r2[i], inv_r2):
			match_idx2 = i
			break
	_assert_check(match_idx2 >= 0, "S5.9 Round 2 has matching thesis keyword")
	p_modal.simulate_buzzword_choice(match_idx2)
	_assert_check(p_modal.get_current_streak() == 3, "S5.10 Streak is 3 after round 2 match")
	_assert_check(p_modal.is_completed == true, "S5.11 Session completed after 3 rounds")

	# Excess inputs locked out
	var post_choice = p_modal.simulate_buzzword_choice(0)
	_assert_check(post_choice == false, "S5.12 Extra choice after completion safely returns false")
	_assert_check(p_modal.get_current_streak() == 3, "S5.13 Streak remains locked at 3")

	# Scaling Grant Math Verification
	# Formula: max(1000.0, (1000.0 + idle_level * 100.0) + rps * 15.0 * (1.0 + streak * 0.5))
	var g_s0_zero = p_modal.calculate_grant(0, 0.0)
	var expected_floor = maxf(1000.0, 1000.0 + float(gs.get_idle_level()) * 100.0)
	_assert_check(absf(g_s0_zero - expected_floor) < EPSILON, "S5.14 Zero RPS grant matches level floor (%.0f)" % expected_floor)

	var g_s3_100rps = p_modal.calculate_grant(3, 100.0)
	var expected_s3 = maxf(1000.0, (1000.0 + float(gs.get_idle_level()) * 100.0) + 100.0 * 15.0 * (1.0 + 3.0 * 0.5))
	_assert_check(absf(g_s3_100rps - expected_s3) < EPSILON, "S5.15 Streak 3 at 100 RPS matches formula (%.0f)" % expected_s3, "got: %.0f" % g_s3_100rps)

	p_modal.close_minigame()
