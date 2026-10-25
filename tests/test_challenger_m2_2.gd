extends SceneTree

## =============================================================================
## Empirical Challenger M2-2 Test Suite:
## Barista Station Dynamics & Cross-Station Lifecycle
## File: IdleArcade/tests/test_challenger_m2_2.gd
##
## Scope:
## 1. Manometer pressure dynamics (build rate, bleed-off rate, clamped range [0.0, 100.0])
## 2. Sweet spot boundaries (61.9 vs 62.0, 84.0 vs 84.1) & hold time soft-decay
## 3. Staff fatigue reset to exactly 0.0 and morale set to 1.0 across all hired workers
## 4. Station state transitions: Ready -> Playing -> Completed -> Cooldown -> Ready across all stations
## 5. Cooldown persistence & zero synchronous disk saving during frame updates
##
## Executable via:
##   godot --headless --path IdleArcade -s tests/test_challenger_m2_2.gd
## =============================================================================

var pass_count: int = 0
var fail_count: int = 0
var findings: Array = []

const EPSILON: float = 0.01

var _mounted_nodes: Array[Node] = []
var _save_backup_text: String = ""
var _had_save_backup: bool = false

func _assert_chall(condition: bool, test_name: String, detail: String = "") -> void:
	if condition:
		print("  [PASS] %s" % test_name)
		pass_count += 1
	else:
		var err_msg: String = "  [FAIL] %s" % test_name
		if detail != "":
			err_msg += " -> " + detail
		printerr(err_msg)
		findings.append(err_msg)
		fail_count += 1

func _init() -> void:
	print("====================================================================")
	print("[CHALLENGER M2-2] Barista Station & Cross-Station Lifecycle Suite")
	print("====================================================================")
	process_frame.connect(_on_first_frame, CONNECT_ONE_SHOT)

func _cleanup_and_quit(exit_code: int) -> void:
	print("\n--- TEARDOWN: Restoring Environment ---")
	if _had_save_backup:
		var f_res = FileAccess.open("user://savegame.json", FileAccess.WRITE)
		if f_res != null:
			f_res.store_string(_save_backup_text)
			f_res.close()
			print("  [CLEANUP] Restored original savegame.json")
	elif FileAccess.file_exists("user://savegame.json"):
		DirAccess.remove_absolute("user://savegame.json")
		print("  [CLEANUP] Cleaned test savegame.json")

	for i in range(_mounted_nodes.size() - 1, -1, -1):
		var n = _mounted_nodes[i]
		if is_instance_valid(n):
			if n.get_parent() != null:
				n.get_parent().remove_child(n)
			n.free()
	_mounted_nodes.clear()

	print("\n====================================================================")
	print("[CHALLENGER M2-2] SUMMARY: %d PASSED, %d FAILED" % [pass_count, fail_count])
	print("====================================================================")

	if findings.size() > 0:
		print("\nCRITICAL DEFECTS / ANOMALIES ENCOUNTERED:")
		for f in findings:
			print(" - %s" % f)

	if fail_count == 0:
		print("\n>>> EMPIRICAL VERDICT: APPROVE (Exit Code 0) <<<\n")
		quit(0)
	else:
		printerr("\n>>> EMPIRICAL VERDICT: REQUEST_CHANGES (%d defects) <<<\n" % fail_count)
		quit(1)

func _on_first_frame() -> void:
	# Backup savegame if it exists
	if FileAccess.file_exists("user://savegame.json"):
		var f_back = FileAccess.open("user://savegame.json", FileAccess.READ)
		if f_back != null:
			_save_backup_text = f_back.get_as_text()
			_had_save_backup = true
			f_back.close()

	await _run_all_tests()
	_cleanup_and_quit(0 if fail_count == 0 else 1)

func _run_all_tests() -> void:
	# Initialize singletons
	var gs_script = load("res://scripts/autoload/game_state.gd")
	var gs = root.get_node_or_null("GameState")
	if gs == null and gs_script != null:
		gs = gs_script.new()
		gs.name = "GameState"
		root.add_child(gs)
		_mounted_nodes.append(gs)
	if gs != null and gs.has_method("reset_state"):
		gs.reset_state()

	var hm_script = load("res://scripts/autoload/haptics_manager.gd")
	var hm = root.get_node_or_null("HapticsManager")
	if hm == null and hm_script != null:
		hm = hm_script.new()
		hm.name = "HapticsManager"
		if "mock_mode" in hm:
			hm.mock_mode = true
		root.add_child(hm)
		_mounted_nodes.append(hm)

	var am_script = load("res://scripts/autoload/audio_manager.gd")
	var am = root.get_node_or_null("AudioManager")
	if am == null and am_script != null:
		am = am_script.new()
		am.name = "AudioManager"
		root.add_child(am)
		_mounted_nodes.append(am)

	await process_frame

	await _test_1_manometer_pressure_dynamics(gs)
	await _test_2_sweet_spot_boundaries()
	await _test_3_staff_fatigue_and_morale(gs)
	await _test_4_station_state_machine_lifecycle(gs)
	await _test_5_cooldown_persistence_and_zero_frame_disk_writes(gs)

# =============================================================================
# PART 1: Manometer Pressure Dynamics
# =============================================================================
func _test_1_manometer_pressure_dynamics(gs: Node) -> void:
	print("\n--- Part 1: Manometer Pressure Dynamics ---")
	var minigame_scene = load("res://scenes/ui/espresso_brew_minigame.tscn")
	_assert_chall(minigame_scene != null, "1.0 EspressoBrewMinigame scene loaded successfully")
	if minigame_scene == null:
		return

	var minigame: EspressoBrewMinigame = minigame_scene.instantiate() as EspressoBrewMinigame
	root.add_child(minigame)
	_mounted_nodes.append(minigame)
	await process_frame

	# 1.1 Initial Pressure Baseline
	minigame.reset_minigame()
	_assert_chall(absf(minigame.get_current_pressure() - 20.0) < EPSILON, 
		"1.1.1 Initial pressure is exactly 20.0 bar (got: %.2f)" % minigame.get_current_pressure())
	_assert_chall(not minigame.is_holding, "1.1.2 Initial valve hold state is false")
	_assert_chall(minigame.can_brew(), "1.1.3 Minigame is active and ready to brew")
	_assert_chall(absf(minigame.get_hold_progress() - 0.0) < EPSILON, "1.1.4 Initial hold progress is 0.0")

	# 1.2 Pressure Build Rate (+40.0 bar/s)
	minigame.is_holding = true
	# 10 frames at delta = 0.05s -> 0.5s total hold
	for i in range(10):
		minigame._process(0.05)
	# Expected: 20.0 + 40.0 * 0.5 = 40.0 bar
	_assert_chall(absf(minigame.get_current_pressure() - 40.0) < EPSILON,
		"1.2.1 Holding builds pressure at +40 bar/s (0.5s -> expected 40.0 bar, got: %.2f)" % minigame.get_current_pressure())

	# Another 0.5s hold (10 frames at 0.05s) -> Expected: 40.0 + 20.0 = 60.0 bar
	for i in range(10):
		minigame._process(0.05)
	_assert_chall(absf(minigame.get_current_pressure() - 60.0) < EPSILON,
		"1.2.2 Total 1.0s hold builds pressure to exactly 60.0 bar (got: %.2f)" % minigame.get_current_pressure())

	# 1.3 Pressure Bleed-off Rate (-24.0 bar/s)
	minigame.is_holding = false
	# 10 frames at delta = 0.05s -> 0.5s total release
	for i in range(10):
		minigame._process(0.05)
	# Expected: 60.0 - 24.0 * 0.5 = 48.0 bar
	_assert_chall(absf(minigame.get_current_pressure() - 48.0) < EPSILON,
		"1.3.1 Natural bleed-off at -24 bar/s (0.5s -> expected 48.0 bar, got: %.2f)" % minigame.get_current_pressure())

	# Another 0.5s release -> Expected: 48.0 - 12.0 = 36.0 bar
	for i in range(10):
		minigame._process(0.05)
	_assert_chall(absf(minigame.get_current_pressure() - 36.0) < EPSILON,
		"1.3.2 Total 1.0s release bleeds pressure to exactly 36.0 bar (got: %.2f)" % minigame.get_current_pressure())

	# 1.4 Pressure Clamped Range [0.0, 100.0]
	# Test lower bound clamping: release for 5.0 seconds (decay would be -120 bar)
	for i in range(50):
		minigame._process(0.1)
	_assert_chall(minigame.get_current_pressure() >= 0.0,
		"1.4.1 Pressure is never negative (>= 0.0)")
	_assert_chall(absf(minigame.get_current_pressure() - 0.0) < EPSILON,
		"1.4.2 Pressure is strictly clamped at 0.0 bar on complete bleed-off (got: %.2f)" % minigame.get_current_pressure())

	# Further decay frames at 0.0 bar remain strictly at 0.0
	minigame._process(0.1)
	minigame._process(0.1)
	_assert_chall(minigame.get_current_pressure() == 0.0,
		"1.4.3 Repeated bleed-off at 0.0 bar remains strictly 0.0")

	# Test upper bound clamping: hold for 5.0 seconds (rise would be +200 bar)
	minigame.is_holding = true
	for i in range(50):
		minigame._process(0.1)
	_assert_chall(minigame.get_current_pressure() <= 100.0,
		"1.4.4 Pressure never exceeds 100.0 bar (<= 100.0)")
	_assert_chall(absf(minigame.get_current_pressure() - 100.0) < EPSILON,
		"1.4.5 Pressure is strictly clamped at 100.0 bar on extreme hold (got: %.2f)" % minigame.get_current_pressure())

	# Further hold frames at 100.0 bar remain strictly at 100.0
	minigame._process(0.1)
	_assert_chall(minigame.get_current_pressure() == 100.0,
		"1.4.6 Repeated hold at 100.0 bar remains strictly 100.0")

	# 1.5 Extreme Discrete Pump Clamping
	minigame.reset_minigame()
	minigame.simulate_pump(500.0)
	_assert_chall(minigame.get_current_pressure() == 100.0,
		"1.5.1 Massive discrete pump (+500 bar) is strictly clamped at 100.0 bar")

	# 1.6 Safe Delta and Frame Hitch Clamping
	minigame.reset_minigame()
	minigame.is_holding = true
	# Delta spike of 10.0 seconds (massive frame freeze)
	# Implementation clamps delta to minf(0.1, delta), so pressure increases by 40.0 * 0.1 = 4.0 bar
	minigame._process(10.0)
	_assert_chall(absf(minigame.get_current_pressure() - 24.0) < EPSILON,
		"1.6.1 Frame freeze delta spike (10.0s) clamped to 0.1s safe_delta (got: %.2f bar)" % minigame.get_current_pressure())

	# Negative delta handling (clock skew)
	var pre_neg_pressure = minigame.get_current_pressure()
	minigame._process(-5.0)
	_assert_chall(minigame.get_current_pressure() == pre_neg_pressure,
		"1.6.2 Negative delta (-5.0s) safely clamped to 0.0s without pressure mutation or NaN")

	# 1.7 Signal Emission Dynamics
	var pressure_signals: Array = []
	var on_p_changed = func(p: float, in_spot: bool):
		pressure_signals.append({"p": p, "in_spot": in_spot})
	minigame.pressure_changed.connect(on_p_changed)

	minigame.reset_minigame()
	minigame.simulate_pump(15.0)
	_assert_chall(pressure_signals.size() > 0, "1.7.1 pressure_changed signal emitted on pump")
	var last_sig = pressure_signals[-1]
	_assert_chall(absf(float(last_sig["p"]) - 35.0) < EPSILON,
		"1.7.2 pressure_changed payload matches updated pressure (35.0 bar)")
	_assert_chall(bool(last_sig["in_spot"]) == false,
		"1.7.3 pressure_changed accurately reports outside sweet spot at 35.0 bar")

	minigame.queue_free()
	_mounted_nodes.erase(minigame)
	await process_frame

# =============================================================================
# PART 2: Sweet Spot Boundaries (61.9 vs 62.0, 84.0 vs 84.1)
# =============================================================================
func _test_2_sweet_spot_boundaries() -> void:
	print("\n--- Part 2: Sweet Spot Boundaries (61.9 vs 62.0, 84.0 vs 84.1) ---")
	var minigame_scene = load("res://scenes/ui/espresso_brew_minigame.tscn")
	var minigame: EspressoBrewMinigame = minigame_scene.instantiate() as EspressoBrewMinigame
	root.add_child(minigame)
	_mounted_nodes.append(minigame)
	await process_frame

	minigame.reset_minigame()

	# 2.1 Lower Boundary Verification
	minigame.current_pressure = 61.90
	_assert_chall(not minigame.is_in_sweet_spot(),
		"2.1.1 Pressure at 61.90 bar is strictly OUT of sweet spot")

	minigame.current_pressure = 61.99
	_assert_chall(not minigame.is_in_sweet_spot(),
		"2.1.2 Pressure at 61.99 bar is strictly OUT of sweet spot")

	minigame.current_pressure = 62.00
	_assert_chall(minigame.is_in_sweet_spot(),
		"2.1.3 Pressure at exact threshold 62.00 bar is strictly IN sweet spot (>= 62.0)")

	minigame.current_pressure = 62.01
	_assert_chall(minigame.is_in_sweet_spot(),
		"2.1.4 Pressure at 62.01 bar is strictly IN sweet spot")

	# 2.2 Upper Boundary Verification
	minigame.current_pressure = 83.99
	_assert_chall(minigame.is_in_sweet_spot(),
		"2.2.1 Pressure at 83.99 bar is strictly IN sweet spot")

	minigame.current_pressure = 84.00
	_assert_chall(minigame.is_in_sweet_spot(),
		"2.2.2 Pressure at exact threshold 84.00 bar is strictly IN sweet spot (<= 84.0)")

	minigame.current_pressure = 84.01
	_assert_chall(not minigame.is_in_sweet_spot(),
		"2.2.3 Pressure at 84.01 bar is strictly OUT of sweet spot")

	minigame.current_pressure = 84.10
	_assert_chall(not minigame.is_in_sweet_spot(),
		"2.2.4 Pressure at 84.10 bar is strictly OUT of sweet spot")

	# 2.3 Hold Time Accumulation vs Soft Decay Dynamics
	# Accumulation at exact 62.00 bar
	minigame.reset_minigame()
	minigame.current_pressure = 62.00
	minigame.is_holding = true
	# Run 10 frames at delta = 0.05 with pressure artificially held at 62.0
	for i in range(10):
		minigame.current_pressure = 62.00 # preserve boundary
		minigame._process(0.05)
	# 0.5s in sweet spot -> current_hold_time should be 0.5s
	_assert_chall(absf(minigame.current_hold_time - 0.5) < EPSILON,
		"2.3.1 Hold time accumulates in sweet spot at 62.0 bar (0.5s hold -> %.2fs)" % minigame.current_hold_time)

	# Soft decay at 61.90 bar (just below sweet spot)
	# Valve released: pressure is outside sweet spot
	minigame.is_holding = false
	# Decay rate: safe_delta * 0.4. For 0.5s (10 frames of 0.05s) -> 0.5 * 0.4 = 0.2s decay
	for i in range(10):
		minigame.current_pressure = 61.90 # preserve outside boundary
		minigame._process(0.05)
	# Expected: 0.5 - 0.2 = 0.3s
	_assert_chall(absf(minigame.current_hold_time - 0.3) < EPSILON,
		"2.3.2 Hold time soft-decays when dipping below sweet spot to 61.90 bar (expected 0.30s, got: %.2fs)" % minigame.current_hold_time)

	# Accumulation at upper boundary 84.00 bar: releasing valve bleeds pressure into sweet spot (84.0 -> 82.8 bar)
	minigame.current_pressure = 84.00
	minigame.is_holding = false
	for i in range(10):
		minigame._process(0.05)
	# Expected: 0.3 + 0.5 = 0.8s
	_assert_chall(absf(minigame.current_hold_time - 0.8) < EPSILON,
		"2.3.3 Hold time accumulates at upper boundary 84.00 bar as pressure bleeds into sweet spot (expected 0.80s, got: %.2fs)" % minigame.current_hold_time)

	# Soft decay at 84.10 bar (overpressured): holding valve pushes further into overpressure (> 84.0 bar)
	minigame.current_pressure = 84.10
	minigame.is_holding = true
	for i in range(10):
		minigame._process(0.05)
	# Expected: 0.8 - 0.2 = 0.6s
	_assert_chall(absf(minigame.current_hold_time - 0.6) < EPSILON,
		"2.3.4 Hold time soft-decays when overpressured at 84.10 bar (expected 0.60s, got: %.2fs)" % minigame.current_hold_time)

	# Hold time decay clamping: cannot decay below 0.0s
	minigame.reset_minigame()
	minigame.current_hold_time = 1.0
	minigame.current_pressure = 20.0 # outside sweet spot
	minigame.is_holding = false
	for i in range(40): # 40 * 0.1s = 4.0s outside sweet spot
		minigame._process(0.1)
	_assert_chall(minigame.current_hold_time == 0.0,
		"2.3.5 Hold time soft-decay is strictly clamped at 0.0s (got: %.2fs)" % minigame.current_hold_time)

	# 2.4 Completion Extraction Threshold (3.0s in Sweet Spot)
	var completed_signals: Array = []
	minigame.brew_completed.connect(func(success: bool): completed_signals.append(success))

	minigame.reset_minigame()
	minigame.current_pressure = 70.0 # dead center of golden zone
	# Run until completed or up to 70 frames to absorb float representation epsilon
	for i in range(70):
		minigame.current_pressure = 70.0
		minigame._process(0.05)
		if minigame.is_finished:
			break

	_assert_chall(minigame.is_finished, "2.4.1 Minigame is_finished == true after 3.0s in sweet spot")
	_assert_chall(absf(minigame.current_hold_time - 3.0) < EPSILON,
		"2.4.2 Extraction hold time reached required 3.0s (got: %.2fs)" % minigame.current_hold_time)
	_assert_chall(completed_signals.size() == 1 and bool(completed_signals[0]) == true,
		"2.4.3 brew_completed(true) emitted exactly once on completion")

	# 2.5 Visual & Label Feedback at Boundary Points
	minigame.reset_minigame()
	minigame.current_pressure = 61.9
	minigame._update_display()
	_assert_chall(minigame.pressure_label.text.contains("LOW"),
		"2.5.1 PressureLabel displays LOW warning at 61.9 bar")

	minigame.current_pressure = 62.0
	minigame._update_display()
	_assert_chall(minigame.pressure_label.text.contains("SWEET SPOT"),
		"2.5.2 PressureLabel displays SWEET SPOT confirmation at 62.0 bar")

	minigame.current_pressure = 84.0
	minigame._update_display()
	_assert_chall(minigame.pressure_label.text.contains("SWEET SPOT"),
		"2.5.3 PressureLabel displays SWEET SPOT confirmation at 84.0 bar")

	minigame.current_pressure = 84.1
	minigame._update_display()
	_assert_chall(minigame.pressure_label.text.contains("OVERPRESSURE"),
		"2.5.4 PressureLabel displays OVERPRESSURE warning at 84.1 bar")

	minigame.queue_free()
	_mounted_nodes.erase(minigame)
	await process_frame

# =============================================================================
# PART 3: Staff Fatigue Reset & Morale Restoration
# =============================================================================
func _test_3_staff_fatigue_and_morale(gs: Node) -> void:
	print("\n--- Part 3: Staff Fatigue Reset & Morale Restoration ---")

	# 3.1 Empty Roster Safety
	gs.reset_state()
	gs.hired_workers.clear()
	var cb_empty = gs.give_team_coffee_break()
	_assert_chall(cb_empty == true, "3.1.1 give_team_coffee_break() returns true with empty worker roster")
	_assert_chall(gs.is_staff_hyper_focus_active(), "3.1.2 Hyper-focus active even with empty roster")
	_assert_chall(absf(gs.get_staff_rps_multiplier() - 1.0) < EPSILON,
		"3.1.3 Staff RPS multiplier is strictly 1.0 with zero hired workers")

	# 3.2 Single Worker Extreme Burnout Recovery
	var single_worker = {
		"id": "dev_001",
		"name": "Alex Core",
		"role": "Frontend Dev",
		"morale": 0.05,
		"fatigue": 0.99,
		"efficiency": 1.0,
		"desk_assigned": 0,
		"current_state": "fatigued"
	}
	gs.hired_workers = [single_worker]
	_assert_chall(absf(float(gs.hired_workers[0]["fatigue"]) - 0.99) < EPSILON, "3.2.1 Pre-condition: worker fatigue is 0.99")
	_assert_chall(str(gs.hired_workers[0]["current_state"]) == "fatigued", "3.2.2 Pre-condition: worker state is 'fatigued'")

	gs.give_team_coffee_break()

	_assert_chall(float(gs.hired_workers[0]["fatigue"]) == 0.0,
		"3.2.3 Worker fatigue reset to exactly 0.0 (zero tolerance)")
	_assert_chall(float(gs.hired_workers[0]["morale"]) == 1.0,
		"3.2.4 Worker morale set to exactly 1.0 (100%)")
	_assert_chall(str(gs.hired_workers[0]["current_state"]) == "working",
		"3.2.5 Worker current_state restored to 'working'")

	# 3.3 Full 5-Specialist Roster Burnout Recovery
	var team: Array = [
		{"id": "w1", "name": "Frontend Dev", "role": "developer", "morale": 0.10, "fatigue": 0.95, "current_state": "fatigued"},
		{"id": "w2", "name": "Backend Dev", "role": "developer", "morale": 0.25, "fatigue": 0.80, "current_state": "fatigued"},
		{"id": "w3", "name": "UI/UX Designer", "role": "designer", "morale": 0.40, "fatigue": 0.60, "current_state": "break"},
		{"id": "w4", "name": "Growth Hacker", "role": "marketer", "morale": 0.00, "fatigue": 1.00, "current_state": "fatigued"},
		{"id": "w5", "name": "QA Engineer", "role": "qa", "morale": 0.30, "fatigue": 0.75, "current_state": "fatigued"}
	]
	gs.hired_workers = team

	_assert_chall(gs.hired_workers.size() == 5, "3.3.1 Full 5-specialist roster mounted")
	gs.give_team_coffee_break()

	var all_fatigue_zero: bool = true
	var all_morale_one: bool = true
	var all_working: bool = true
	for w in gs.hired_workers:
		if float(w.get("fatigue", -1.0)) != 0.0:
			all_fatigue_zero = false
		if float(w.get("morale", -1.0)) != 1.0:
			all_morale_one = false
		if str(w.get("current_state", "")) != "working":
			all_working = false

	_assert_chall(all_fatigue_zero, "3.3.2 100% of workers have fatigue reset to exactly 0.0")
	_assert_chall(all_morale_one, "3.3.3 100% of workers have morale set to exactly 1.0")
	_assert_chall(all_working, "3.3.4 100% of workers have current_state set to 'working'")

	# 3.4 Economic Synergies & Hyper-Focus Stacking
	_assert_chall(gs.is_staff_hyper_focus_active(), "3.4.1 is_staff_hyper_focus_active() returns true")
	_assert_chall(absf(gs.get_staff_hyper_focus_multiplier() - 1.50) < EPSILON,
		"3.4.2 Hyper-focus multiplier is exactly 1.50 (+50% speed)")
	_assert_chall(absf(gs.get_staff_hyper_focus_time_remaining() - 60.0) < EPSILON,
		"3.4.3 Hyper-focus duration timer initialized to 60.0s")
	_assert_chall(absf(gs.get_staff_average_morale() - 1.0) < EPSILON,
		"3.4.4 Average team morale is strictly 1.0 (100%)")
	# Formula: 1.0 + (active_workers * 0.05) * avg_morale = 1.0 + (5 * 0.05) * 1.0 = 1.25
	_assert_chall(absf(gs.get_staff_rps_multiplier() - 1.25) < EPSILON,
		"3.4.5 Staff RPS multiplier reaches optimal 1.25 (+25% team bonus)")

	# 3.5 Integration: Minigame Brew Success Triggers Coffee Break
	var minigame_scene = load("res://scenes/ui/espresso_brew_minigame.tscn")
	var minigame: EspressoBrewMinigame = minigame_scene.instantiate() as EspressoBrewMinigame
	root.add_child(minigame)
	_mounted_nodes.append(minigame)
	await process_frame

	# Degrade worker again
	gs.hired_workers[0]["fatigue"] = 0.85
	gs.hired_workers[0]["morale"] = 0.15
	minigame.reset_minigame()
	minigame.complete_brew(true) # Success trigger

	_assert_chall(float(gs.hired_workers[0]["fatigue"]) == 0.0,
		"3.5.1 minigame.complete_brew(true) triggers GameState staff fatigue healing (0.0)")
	_assert_chall(float(gs.hired_workers[0]["morale"]) == 1.0,
		"3.5.2 minigame.complete_brew(true) triggers GameState staff morale restoration (1.0)")

	# Test cancelled brew does NOT heal burnout
	gs.hired_workers[0]["fatigue"] = 0.70
	gs.hired_workers[0]["morale"] = 0.30
	minigame.reset_minigame()
	minigame.complete_brew(false) # Cancellation

	_assert_chall(float(gs.hired_workers[0]["fatigue"]) == 0.70,
		"3.5.3 minigame.complete_brew(false) does NOT clear fatigue")
	_assert_chall(float(gs.hired_workers[0]["morale"]) == 0.30,
		"3.5.4 minigame.complete_brew(false) does NOT restore morale")

	minigame.queue_free()
	_mounted_nodes.erase(minigame)
	await process_frame

# =============================================================================
# PART 4: Station State Transitions (Ready -> Playing -> Completed -> Cooldown -> Ready)
# =============================================================================
func _test_4_station_state_machine_lifecycle(gs: Node) -> void:
	print("\n--- Part 4: Station State Transitions (Ready -> Playing -> Completed -> Cooldown -> Ready) ---")

	var coffee_scene = load("res://scenes/coffee_machine_3d.tscn")
	var server_scene = load("res://scenes/server_terminal.tscn")
	var pitch_scene = load("res://scenes/pitch_stage.tscn")

	_assert_chall(coffee_scene != null and server_scene != null and pitch_scene != null,
		"4.0 All 3 station scenes loaded successfully")

	var cm: CoffeeMachine3D = coffee_scene.instantiate() as CoffeeMachine3D
	var st: ServerTerminal = server_scene.instantiate() as ServerTerminal
	var ps: PitchStage = pitch_scene.instantiate() as PitchStage

	root.add_child(cm)
	root.add_child(st)
	root.add_child(ps)
	_mounted_nodes.append(cm)
	_mounted_nodes.append(st)
	_mounted_nodes.append(ps)
	await process_frame

	# Track state transition signals for CoffeeMachine
	var cm_state_history: Array = []
	cm.state_changed.connect(func(n_state: int, o_state: int):
		cm_state_history.append({"from": o_state, "to": n_state})
	)

	# -------------------------------------------------------------------------
	# 4.1 CoffeeMachine3D Lifecycle
	# -------------------------------------------------------------------------
	print("  - Testing CoffeeMachine3D lifecycle...")
	gs.reset_all_station_cooldowns()
	cm.is_on_cooldown = false
	cm.cooldown_time_remaining = 0.0
	cm.current_state = CoffeeMachine3D.StationState.STATE_READY

	# [1] READY
	_assert_chall(cm.current_state == CoffeeMachine3D.StationState.STATE_READY,
		"4.1.1 CoffeeMachine initial state is STATE_READY (0)")
	_assert_chall(cm.can_brew(), "4.1.2 can_brew() returns true in STATE_READY")
	_assert_chall(cm.is_ready(), "4.1.3 is_ready() returns true in STATE_READY")

	# [2] PLAYING
	cm.start_brewing()
	_assert_chall(cm.current_state == CoffeeMachine3D.StationState.STATE_PLAYING,
		"4.1.4 CoffeeMachine transitions to STATE_PLAYING (1)")
	_assert_chall(cm.is_brewing, "4.1.5 is_brewing is true in STATE_PLAYING")
	_assert_chall(not cm.can_brew(), "4.1.6 can_brew() locked during STATE_PLAYING")

	# [3] COMPLETED (Explicit Verification of Enum & Value)
	_assert_chall(CoffeeMachine3D.StationState.STATE_COMPLETED == 2,
		"4.1.7 CoffeeMachine defines STATE_COMPLETED == 2 in StationState enum")
	_assert_chall(CoffeeMachine3D.STATE_COMPLETED == 2,
		"4.1.8 CoffeeMachine exposes const STATE_COMPLETED == 2")
	cm.current_state = CoffeeMachine3D.StationState.STATE_COMPLETED
	_assert_chall(cm.current_state == CoffeeMachine3D.StationState.STATE_COMPLETED,
		"4.1.9 CoffeeMachine successfully assumes STATE_COMPLETED (2)")

	# [4] COOLDOWN
	cm.complete_brew(true)
	_assert_chall(cm.current_state == CoffeeMachine3D.StationState.STATE_COOLDOWN,
		"4.1.10 CoffeeMachine transitions to STATE_COOLDOWN (3) on completion")
	_assert_chall(cm.is_on_cooldown, "4.1.11 is_on_cooldown is true in STATE_COOLDOWN")
	_assert_chall(absf(cm.cooldown_time_remaining - 60.0) < EPSILON,
		"4.1.12 Cooldown timer initialized to 60.0s")
	_assert_chall(not cm.can_brew(), "4.1.13 can_brew() locked during STATE_COOLDOWN")

	# [5] Return to READY
	cm._process(60.1)
	gs._process(60.1)
	_assert_chall(cm.current_state == CoffeeMachine3D.StationState.STATE_READY,
		"4.1.14 CoffeeMachine restored to STATE_READY (0) after cooldown expiration")
	_assert_chall(cm.can_brew(), "4.1.15 can_brew() restored to true after cooldown completes")
	_assert_chall(cm.is_ready(), "4.1.16 is_ready() restored to true after cooldown completes")

	# -------------------------------------------------------------------------
	# 4.2 ServerTerminal Lifecycle
	# -------------------------------------------------------------------------
	print("  - Testing ServerTerminal lifecycle...")
	gs.reset_all_station_cooldowns()
	st.is_on_cooldown = false
	st.cooldown_time_remaining = 0.0
	st.current_state = ServerTerminal.StationState.STATE_READY

	# [1] READY
	_assert_chall(st.current_state == ServerTerminal.StationState.STATE_READY,
		"4.2.1 ServerTerminal initial state is STATE_READY (0)")
	_assert_chall(st.can_activate(), "4.2.2 can_activate() returns true in STATE_READY")

	# [2] PLAYING
	st.open_cyber_sync_minigame()
	_assert_chall(st.current_state == ServerTerminal.StationState.STATE_PLAYING,
		"4.2.3 ServerTerminal transitions to STATE_PLAYING (1)")
	_assert_chall(st.is_minigame_active, "4.2.4 is_minigame_active is true in STATE_PLAYING")
	_assert_chall(not st.can_activate(), "4.2.5 can_activate() locked during STATE_PLAYING")

	# [3] COMPLETED (Explicit Verification of Enum & Value)
	_assert_chall(ServerTerminal.StationState.STATE_COMPLETED == 2,
		"4.2.6 ServerTerminal defines STATE_COMPLETED == 2 in StationState enum")
	_assert_chall(ServerTerminal.STATE_COMPLETED == 2,
		"4.2.7 ServerTerminal exposes const STATE_COMPLETED == 2")
	st.current_state = ServerTerminal.StationState.STATE_COMPLETED
	_assert_chall(st.current_state == ServerTerminal.StationState.STATE_COMPLETED,
		"4.2.8 ServerTerminal successfully assumes STATE_COMPLETED (2)")

	# [4] COOLDOWN
	st.complete_cyber_sync(true)
	st._end_overclock()
	st._on_minigame_closed()
	_assert_chall(st.current_state == ServerTerminal.StationState.STATE_COOLDOWN,
		"4.2.9 ServerTerminal transitions to STATE_COOLDOWN (3)")
	_assert_chall(st.is_on_cooldown, "4.2.10 is_on_cooldown is true in STATE_COOLDOWN")
	_assert_chall(not st.can_activate(), "4.2.11 can_activate() locked during STATE_COOLDOWN")

	# [5] Return to READY
	st._process(60.1)
	gs._process(60.1)
	_assert_chall(st.current_state == ServerTerminal.StationState.STATE_READY,
		"4.2.12 ServerTerminal restored to STATE_READY (0) after cooldown expiration")
	_assert_chall(st.can_activate(), "4.2.13 can_activate() restored to true after cooldown completes")

	# -------------------------------------------------------------------------
	# 4.3 PitchStage Lifecycle
	# -------------------------------------------------------------------------
	print("  - Testing PitchStage lifecycle...")
	gs.reset_all_station_cooldowns()
	ps.is_on_cooldown = false
	ps.cooldown_time_remaining = 0.0
	ps.current_state = PitchStage.StationState.STATE_READY

	# [1] READY
	_assert_chall(ps.current_state == PitchStage.StationState.STATE_READY,
		"4.3.1 PitchStage initial state is STATE_READY (0)")
	_assert_chall(ps.can_pitch(), "4.3.2 can_pitch() returns true in STATE_READY")

	# [2] PLAYING
	ps.open_pitch_minigame()
	_assert_chall(ps.current_state == PitchStage.StationState.STATE_PLAYING,
		"4.3.3 PitchStage transitions to STATE_PLAYING (1)")
	_assert_chall(ps.is_minigame_active, "4.3.4 is_minigame_active is true in STATE_PLAYING")
	_assert_chall(not ps.can_pitch(), "4.3.5 can_pitch() locked during STATE_PLAYING")

	# [3] COMPLETED (Explicit Verification of Enum & Value)
	_assert_chall(PitchStage.StationState.STATE_COMPLETED == 2,
		"4.3.6 PitchStage defines STATE_COMPLETED == 2 in StationState enum")
	_assert_chall(PitchStage.STATE_COMPLETED == 2,
		"4.3.7 PitchStage exposes const STATE_COMPLETED == 2")
	ps.current_state = PitchStage.StationState.STATE_COMPLETED
	_assert_chall(ps.current_state == PitchStage.StationState.STATE_COMPLETED,
		"4.3.8 PitchStage successfully assumes STATE_COMPLETED (2)")

	# [4] COOLDOWN
	ps._apply_grant_rewards(2500.0)
	ps._on_pitch_minigame_closed()
	_assert_chall(ps.current_state == PitchStage.StationState.STATE_COOLDOWN,
		"4.3.9 PitchStage transitions to STATE_COOLDOWN (3)")
	_assert_chall(ps.is_on_cooldown, "4.3.10 is_on_cooldown is true in STATE_COOLDOWN")
	_assert_chall(not ps.can_pitch(), "4.3.11 can_pitch() locked during STATE_COOLDOWN")

	# [5] Return to READY
	ps._process(60.1)
	gs._process(60.1)
	_assert_chall(ps.current_state == PitchStage.StationState.STATE_READY,
		"4.3.12 PitchStage restored to STATE_READY (0) after cooldown expiration")
	_assert_chall(ps.can_pitch(), "4.3.13 can_pitch() restored to true after cooldown completes")

	# Clean up stations
	cm.queue_free()
	st.queue_free()
	ps.queue_free()
	_mounted_nodes.erase(cm)
	_mounted_nodes.erase(st)
	_mounted_nodes.erase(ps)
	await process_frame

# =============================================================================
# PART 5: Cooldown Persistence & Zero Frame Disk Writes
# =============================================================================
func _test_5_cooldown_persistence_and_zero_frame_disk_writes(gs: Node) -> void:
	print("\n--- Part 5: Cooldown Persistence & Zero Frame Disk Writes ---")

	# 5.1 Cooldown Persistence & Offline Catch-up Roundtrip
	gs.reset_state()
	gs.reset_all_station_cooldowns()

	# Set multi-station cooldowns
	gs.set_station_cooldown("server_terminal", 50.0)
	gs.set_station_cooldown("pitch_stage", 40.0)
	gs.set_station_cooldown("coffee_machine", 30.0)
	gs.save_to_disk()

	_assert_chall(FileAccess.file_exists("user://savegame.json"),
		"5.1.1 user://savegame.json created successfully on disk")

	# Read savegame text and verify exact serialization
	var f_read = FileAccess.open("user://savegame.json", FileAccess.READ)
	_assert_chall(f_read != null, "5.1.2 Savegame file open for reading succeeded")
	if f_read != null:
		var json_str = f_read.get_as_text()
		f_read.close()
		var p = JSON.new()
		var parse_res = p.parse(json_str)
		_assert_chall(parse_res == OK, "5.1.3 Savegame JSON parsed without errors")
		var save_dict: Dictionary = p.data
		_assert_chall(save_dict.has("station_cooldowns"),
			"5.1.4 Savegame dictionary contains 'station_cooldowns' section")
		var cds: Dictionary = save_dict.get("station_cooldowns", {})
		_assert_chall(absf(float(cds.get("server_terminal", 0.0)) - 50.0) < EPSILON,
			"5.1.5 server_terminal serialized as 50.0s")
		_assert_chall(absf(float(cds.get("pitch_stage", 0.0)) - 40.0) < EPSILON,
			"5.1.6 pitch_stage serialized as 40.0s")
		_assert_chall(absf(float(cds.get("coffee_machine", 0.0)) - 30.0) < EPSILON,
			"5.1.7 coffee_machine serialized as 30.0s")

		# Simulate 12 seconds offline elapsed
		var saved_ts: int = int(save_dict.get("timestamp", 0))
		save_dict["timestamp"] = saved_ts - 12
		var f_write = FileAccess.open("user://savegame.json", FileAccess.WRITE)
		if f_write != null:
			f_write.store_string(JSON.stringify(save_dict, "\t"))
			f_write.close()

	# Reload from disk and verify catch-up calculation
	var load_ok = gs.load_from_disk()
	_assert_chall(load_ok, "5.1.8 load_from_disk() executed successfully")
	# 50 - 12 = 38.0s
	_assert_chall(absf(gs.get_station_cooldown("server_terminal") - 38.0) < 1.5,
		"5.1.9 server_terminal cooldown decayed by 12s offline (expected ~38.0s, got: %.2fs)" % gs.get_station_cooldown("server_terminal"))
	# 40 - 12 = 28.0s
	_assert_chall(absf(gs.get_station_cooldown("pitch_stage") - 28.0) < 1.5,
		"5.1.10 pitch_stage cooldown decayed by 12s offline (expected ~28.0s, got: %.2fs)" % gs.get_station_cooldown("pitch_stage"))
	# 30 - 12 = 18.0s
	_assert_chall(absf(gs.get_station_cooldown("coffee_machine") - 18.0) < 1.5,
		"5.1.11 coffee_machine cooldown decayed by 12s offline (expected ~18.0s, got: %.2fs)" % gs.get_station_cooldown("coffee_machine"))

	# 5.2 Verification: ZERO Synchronous Disk Writes During Frame Updates
	print("  - Testing zero disk writes during continuous frame updates...")
	var coffee_scene = load("res://scenes/coffee_machine_3d.tscn")
	var server_scene = load("res://scenes/server_terminal.tscn")
	var pitch_scene = load("res://scenes/pitch_stage.tscn")

	var cm: CoffeeMachine3D = coffee_scene.instantiate() as CoffeeMachine3D
	var st: ServerTerminal = server_scene.instantiate() as ServerTerminal
	var ps: PitchStage = pitch_scene.instantiate() as PitchStage

	root.add_child(cm)
	root.add_child(st)
	root.add_child(ps)
	_mounted_nodes.append(cm)
	_mounted_nodes.append(st)
	_mounted_nodes.append(ps)
	await process_frame

	# Ensure all stations are in active cooldown
	gs.set_station_cooldown("coffee_machine", 45.0)
	gs.set_station_cooldown("server_terminal", 45.0)
	gs.set_station_cooldown("pitch_stage", 45.0)
	cm.is_on_cooldown = true
	cm.cooldown_time_remaining = 45.0
	cm.current_state = CoffeeMachine3D.StationState.STATE_COOLDOWN
	st.is_on_cooldown = true
	st.cooldown_time_remaining = 45.0
	st.current_state = ServerTerminal.StationState.STATE_COOLDOWN
	ps.is_on_cooldown = true
	ps.cooldown_time_remaining = 45.0
	ps.current_state = PitchStage.StationState.STATE_COOLDOWN

	# Force a save to establish clean baseline file state
	gs.save_to_disk()
	var initial_mod_time: int = FileAccess.get_modified_time("user://savegame.json")

	# Write a unique canary token into the save file to verify it is NOT overwritten
	var canary_token: String = "CANARY_TOKEN_ACTIVE_DECAY_%d" % Time.get_ticks_msec()
	var f_canary_write = FileAccess.open("user://savegame.json", FileAccess.WRITE)
	if f_canary_write != null:
		f_canary_write.store_string(canary_token)
		f_canary_write.close()

	# Simulate 120 consecutive frames at 60 FPS (2.0 seconds of gameplay)
	# Each frame calls _process() on GameState, CoffeeMachine3D, ServerTerminal, and PitchStage
	var frame_delta: float = 1.0 / 60.0
	for frame in range(120):
		gs._process(frame_delta)
		cm._process(frame_delta)
		st._process(frame_delta)
		ps._process(frame_delta)

	# Read save file back: if save_to_disk() was invoked during any of the 120 frames,
	# the file would have been rewritten with JSON, obliterating the canary token!
	var f_canary_check = FileAccess.open("user://savegame.json", FileAccess.READ)
	var content_after_120_frames: String = ""
	if f_canary_check != null:
		content_after_120_frames = f_canary_check.get_as_text()
		f_canary_check.close()

	_assert_chall(content_after_120_frames == canary_token,
		"5.2.1 Zero disk writes over 120 continuous _process() frames (canary token intact)")

	# Verify timers actively decayed despite zero disk writes
	_assert_chall(gs.get_station_cooldown("coffee_machine") < 43.5,
		"5.2.2 GameState coffee_machine cooldown actively decayed in memory (now: %.2fs)" % gs.get_station_cooldown("coffee_machine"))
	_assert_chall(cm.cooldown_time_remaining < 43.5,
		"5.2.3 CoffeeMachine3D cooldown actively decayed in memory (now: %.2fs)" % cm.cooldown_time_remaining)
	_assert_chall(st.cooldown_time_remaining < 43.5,
		"5.2.4 ServerTerminal cooldown actively decayed in memory (now: %.2fs)" % st.cooldown_time_remaining)
	_assert_chall(ps.cooldown_time_remaining < 43.5,
		"5.2.5 PitchStage cooldown actively decayed in memory (now: %.2fs)" % ps.cooldown_time_remaining)

	# 5.3 Cooldown Completion Saves to Disk Cleanly
	# When cooldown decays to 0.0s, set_station_cooldown(id, 0.0) is called, which persists to disk
	gs.set_station_cooldown("coffee_machine", 0.0)
	var f_final = FileAccess.open("user://savegame.json", FileAccess.READ)
	var content_after_completion: String = ""
	if f_final != null:
		content_after_completion = f_final.get_as_text()
		f_final.close()

	_assert_chall(content_after_completion != canary_token and content_after_completion.begins_with("{"),
		"5.3.1 Clean disk save triggered upon explicit cooldown completion/clearing")

	cm.queue_free()
	st.queue_free()
	ps.queue_free()
	_mounted_nodes.erase(cm)
	_mounted_nodes.erase(st)
	_mounted_nodes.erase(ps)
	await process_frame
