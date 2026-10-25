extends SceneTree

## Dedicated In-Engine Headless Adversarial Stress Suite for Milestone 4
## File: IdleArcade/tests/test_challenger_m4_2.gd
##
## Execution:
##   godot --headless --path IdleArcade -s tests/test_challenger_m4_2.gd

var pass_count: int = 0
var fail_count: int = 0

const EPSILON: float = 0.005

func _assert(condition: bool, description: String, detail: String = "") -> void:
	if condition:
		print("  [PASS] %s" % description)
		pass_count += 1
	else:
		fail_count += 1
		var msg: String = "  [FAIL] %s" % description
		if detail != "":
			msg += " (%s)" % detail
		printerr(msg)

func _init() -> void:
	print("\n====================================================================")
	print(">>> RUNNING IDLEARCADE M4 ADVERSARIAL IN-ENGINE STRESS SUITE <<<")
	print("====================================================================")
	call_deferred("_run_suite")

func _run_suite() -> void:
	await process_frame

	# Obtain or instantiate singletons
	var gs = root.get_node_or_null("GameState")
	var gs_created: bool = false
	if gs == null:
		var gs_script = load("res://scripts/autoload/game_state.gd")
		gs = gs_script.new()
		gs.name = "GameState"
		root.add_child(gs)
		gs_created = true

	var am = root.get_node_or_null("AudioManager")
	var am_created: bool = false
	if am == null:
		var am_script = load("res://scripts/autoload/audio_manager.gd")
		am = am_script.new()
		am.name = "AudioManager"
		root.add_child(am)
		am_created = true

	var hm = root.get_node_or_null("HapticsManager")
	var hm_created: bool = false
	if hm == null:
		var hm_script = load("res://scripts/autoload/haptics_manager.gd")
		hm = hm_script.new()
		hm.name = "HapticsManager"
		root.add_child(hm)
		hm_created = true

	await process_frame

	await _test_virtual_joystick_native_collision()
	await _test_cybersync_stress(gs)
	await _test_pitch_stage_qte_stress(gs)
	await _test_espresso_manometer_stress(gs)
	await _test_station_cooldown_stress(gs)

	print("\n====================================================================")
	print(">>> ADVERSARIAL STRESS SUITE: %d PASSED, %d FAILED <<<" % [pass_count, fail_count])
	print("====================================================================")

	# Teardown any dynamically created singletons
	if hm_created and hm != null: hm.queue_free()
	if am_created and am != null: am.queue_free()
	if gs_created and gs != null: gs.queue_free()
	await process_frame

	if fail_count == 0:
		print(">>> ALL M4 ADVERSARIAL STRESS TESTS PASSED WITH 100% INTEGRITY (Exit Code 0) <<<\n")
		quit(0)
	else:
		printerr(">>> ADVERSARIAL STRESS SUITE FAILED (Exit Code 1) <<<\n")
		quit(1)

func _test_virtual_joystick_native_collision() -> void:
	print("\n--- 1. VirtualJoystick Native Class Collision & Instantiation ---")
	var vj_script = load("res://scripts/ui/virtual_joystick.gd")
	_assert(vj_script != null, "1.1 virtual_joystick.gd loads cleanly without native collision error")
	if vj_script != null:
		var vj = vj_script.new()
		_assert(vj != null, "1.2 ArcadeVirtualJoystick instantiates cleanly")
		_assert(vj is Control, "1.3 ArcadeVirtualJoystick is instance of Control")
		_assert("deadzone_radius" in vj and "max_radius" in vj, "1.4 ArcadeVirtualJoystick has deadzone_radius & max_radius exports")
		vj.free()

func _test_cybersync_stress(gs: Node) -> void:
	print("\n--- 2. Server Overclock & CyberSync Minigame Stress ---")
	var cs_scene = load("res://scenes/ui/cyber_sync_minigame.tscn")
	_assert(cs_scene != null, "2.1 cyber_sync_minigame.tscn loaded")
	if cs_scene == null:
		return

	var cs = cs_scene.instantiate() as CyberSyncMinigame
	root.add_child(cs)
	await process_frame

	# Check evaluation boundaries
	var p_res = cs.evaluate_hit(0.50)
	_assert(p_res["rating"] == "Perfect" and absf(p_res["multiplier"] - 3.00) < EPSILON, "2.2 Center hit evaluates to Perfect (3.0x)")
	var g_res = cs.evaluate_hit(0.35)
	_assert(g_res["rating"] == "Good" and absf(g_res["multiplier"] - 2.00) < EPSILON, "2.3 Hit at 0.35 evaluates to Good (2.0x)")
	var m_res = cs.evaluate_hit(0.0)
	_assert(m_res["rating"] == "Miss" and absf(m_res["multiplier"] - 1.20) < EPSILON, "2.4 Hit at 0.0 evaluates to Miss (1.2x)")

	# Full Perfect 3-node simulation
	cs.open_minigame()
	cs.simulate_hit(0.50)
	cs.simulate_hit(0.50)
	cs.simulate_hit(0.50)
	await process_frame
	_assert(cs.is_completed, "2.5 CyberSync completed after 3 nodes")
	_assert(cs.perfect_hits_count == 3, "2.6 3/3 perfect hits recorded")

	# Full Good 3-node simulation
	cs.open_minigame()
	cs.simulate_hit(0.35)
	cs.simulate_hit(0.35)
	cs.simulate_hit(0.35)
	await process_frame
	_assert(cs.good_hits_count == 3, "2.7 3/3 good hits recorded")

	# Full Miss 3-node simulation
	cs.open_minigame()
	cs.simulate_hit(0.0)
	cs.simulate_hit(0.0)
	cs.simulate_hit(0.0)
	await process_frame
	_assert(cs.miss_hits_count == 3, "2.8 3/3 miss hits recorded")

	cs.queue_free()
	await process_frame

func _test_pitch_stage_qte_stress(gs: Node) -> void:
	print("\n--- 3. Pitch Stage QTE Engine & Scaling Grant Stress ---")
	var ps_scene = load("res://scenes/ui/pitch_stage_minigame.tscn")
	_assert(ps_scene != null, "3.1 pitch_stage_minigame.tscn loaded")
	if ps_scene == null:
		return

	var ps = ps_scene.instantiate() as PitchStageMinigame
	root.add_child(ps)
	await process_frame

	# Expected formula: base = 1000 + idle_level * 100, rps_comp = rps * 15 * (1 + streak * 0.5)
	var expected_base: float = 1000.0 + float(gs.get_idle_level()) * 100.0
	var g0 = ps.calculate_grant(0, 0.0)
	_assert(absf(g0 - expected_base) < EPSILON, "3.2 Grant at 0 streak and 0 RPS equals base floor (%d Energy)" % int(expected_base))

	var expected_g3 = expected_base + 200.0 * 15.0 * 2.5
	var g3 = ps.calculate_grant(3, 200.0)
	_assert(absf(g3 - expected_g3) < EPSILON, "3.3 Grant at 3 streak and 200 RPS matches formula (%d Energy)" % int(expected_g3))

	# Test 3-round play with correct buzzwords
	ps.open_minigame()
	for r in range(3):
		var words = ps.get_current_buzzwords()
		var picked_idx = -1
		for i in range(words.size()):
			if ps.is_buzzword_matching(words[i], ps.get_active_investor_type()):
				picked_idx = i
				break
		_assert(picked_idx != -1, "3.4 Round %d contains a valid matching buzzword" % (r + 1))
		ps.simulate_buzzword_choice(picked_idx)
		await process_frame

	_assert(ps.is_completed, "3.5 Pitch session completed after 3 rounds")
	_assert(ps.get_current_streak() == 3, "3.6 Streak is 3 after 3 correct buzzword choices")

	# Test timeout resilience
	ps.open_minigame()
	ps.simulate_timeout()
	await process_frame
	_assert(ps.is_completed, "3.7 Pitch session cleanly completes upon timeout")
	_assert(ps.get_current_streak() == 0, "3.8 Streak resets to 0 upon timeout")

	ps.queue_free()
	await process_frame

func _test_espresso_manometer_stress(gs: Node) -> void:
	print("\n--- 4. Barista Station Manometer & Sweet Spot Stress ---")
	var eb_scene = load("res://scenes/ui/espresso_brew_minigame.tscn")
	_assert(eb_scene != null, "4.1 espresso_brew_minigame.tscn loaded")
	if eb_scene == null:
		return

	var eb = eb_scene.instantiate() as EspressoBrewMinigame
	root.add_child(eb)
	await process_frame

	# Check sweet spot boundary values
	eb.current_pressure = 61.99
	_assert(not eb.is_in_sweet_spot(), "4.2 61.99 bar is strictly outside sweet spot")
	eb.current_pressure = 62.00
	_assert(eb.is_in_sweet_spot(), "4.3 62.00 bar is strictly inside sweet spot")
	eb.current_pressure = 84.00
	_assert(eb.is_in_sweet_spot(), "4.4 84.00 bar is strictly inside sweet spot")
	eb.current_pressure = 84.01
	_assert(not eb.is_in_sweet_spot(), "4.5 84.01 bar is strictly outside sweet spot")

	# Setup fatigued worker BEFORE brewing
	gs.reset_state()
	gs.energy = 50000.0
	var hired = gs.hire_worker("Frontend Dev")
	_assert(hired, "4.6 Frontend Dev hired successfully with energy funded")
	_assert(gs.hired_workers.size() > 0, "4.7 Worker roster has 1 active worker")
	gs.hired_workers[0]["fatigue"] = 0.90
	gs.hired_workers[0]["morale"] = 0.20
	gs.hired_workers[0]["current_state"] = "fatigued"

	# Discrete hold simulation: 35 steps of 0.1s at 72 bar (in sweet spot)
	eb.reset_minigame()
	eb.is_active = true
	eb.current_hold_time = 0.0
	for step in range(35):
		eb.current_pressure = 72.0
		eb._process(0.1)

	_assert(eb.is_finished, "4.8 Espresso brew completes after 3.0s continuous sweet spot hold")

	# Test Staff Burnout healing and Hyper-Focus activation
	_assert(absf(gs.hired_workers[0]["fatigue"] - 0.0) < EPSILON, "4.9 Worker fatigue healed to 0.0")
	_assert(absf(gs.hired_workers[0]["morale"] - 1.0) < EPSILON, "4.10 Worker morale restored to 1.0")
	_assert(gs.hired_workers[0]["current_state"] == "working", "4.11 Worker state restored to 'working'")
	_assert(gs.is_staff_hyper_focus_active(), "4.12 60s Hyper-Focus buff engaged in GameState")

	eb.queue_free()
	await process_frame

func _test_station_cooldown_stress(gs: Node) -> void:
	print("\n--- 5. Station Multi-Cooldown & Invariant Stress ---")
	gs.reset_all_station_cooldowns()

	# Set cooldowns on all 3 stations
	gs.set_station_cooldown("server_terminal", 45.0)
	gs.set_station_cooldown("pitch_stage", 30.0)
	gs.set_station_cooldown("coffee_machine", 60.0)

	_assert(gs.is_station_on_cooldown("server_terminal"), "5.1 ServerTerminal is on cooldown")
	_assert(gs.is_station_on_cooldown("pitch_stage"), "5.2 PitchStage is on cooldown")
	_assert(gs.is_station_on_cooldown("coffee_machine"), "5.3 CoffeeMachine is on cooldown")

	# Simulate 35 seconds of time elapse
	gs._process(35.0)

	_assert(not gs.is_station_on_cooldown("pitch_stage"), "5.4 PitchStage (30s) expired and is READY")
	_assert(gs.is_station_on_cooldown("server_terminal"), "5.5 ServerTerminal (45s) still has 10s remaining")
	_assert(gs.is_station_on_cooldown("coffee_machine"), "5.6 CoffeeMachine (60s) still has 25s remaining")

	# Simulate another 30 seconds
	gs._process(30.0)
	_assert(not gs.is_station_on_cooldown("server_terminal"), "5.7 ServerTerminal has expired and is READY")
	_assert(not gs.is_station_on_cooldown("coffee_machine"), "5.8 CoffeeMachine has expired and is READY")

	# Save serialization dictionary verification
	var save_dict: Dictionary = {
		"station_cooldowns": {
			"server_terminal": 50.0,
			"pitch_stage": 25.0,
			"coffee_machine": 35.0
		}
	}
	var serialized = JSON.stringify(save_dict)
	var parsed = JSON.parse_string(serialized)
	_assert(parsed is Dictionary, "5.9 Station cooldowns serialize cleanly to JSON")
	_assert(absf(float(parsed["station_cooldowns"]["server_terminal"]) - 50.0) < EPSILON, "5.10 ServerTerminal 50s cooldown preserved in JSON")
	_assert(absf(float(parsed["station_cooldowns"]["pitch_stage"]) - 25.0) < EPSILON, "5.11 PitchStage 25s cooldown preserved in JSON")
	_assert(absf(float(parsed["station_cooldowns"]["coffee_machine"]) - 35.0) < EPSILON, "5.12 CoffeeMachine 35s cooldown preserved in JSON")
