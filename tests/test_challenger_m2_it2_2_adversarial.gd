# =============================================================================
# Challenger M2-IT2-2 Adversarial Re-verification Test Suite
# Tests Cross-Station Concurrency, State Decoupling, Buff Isolation,
# and Disk Write Decoupling across Barista, Server, and Pitch stations.
# =============================================================================
extends SceneTree

const EPSILON: float = 0.001

var _pass_count: int = 0
var _fail_count: int = 0
var _mounted_nodes: Array[Node] = []
var _original_savegame: String = ""

func _init() -> void:
	print("\n====================================================================")
	print(">>> RUNNING CHALLENGER M2-IT2-2 ADVERSARIAL RE-VERIFICATION SUITE <<<")
	print("====================================================================")
	_backup_savegame()
	call_deferred("_run_suite")

func _backup_savegame() -> void:
	if FileAccess.file_exists("user://savegame.json"):
		var f = FileAccess.open("user://savegame.json", FileAccess.READ)
		if f != null:
			_original_savegame = f.get_as_text()
			f.close()

func _restore_savegame() -> void:
	if _original_savegame.is_empty():
		if DirAccess.dir_exists_absolute("user://"):
			DirAccess.remove_absolute("user://savegame.json")
	else:
		var f = FileAccess.open("user://savegame.json", FileAccess.WRITE)
		if f != null:
			f.store_string(_original_savegame)
			f.close()
	print("  [CLEANUP] Savegame restored to initial state.")

func _assert_test(condition: bool, description: String, detail: String = "") -> void:
	if condition:
		_pass_count += 1
		print("  [PASS] %s" % description)
	else:
		_fail_count += 1
		var err_msg = "  [FAIL] %s" % description
		if not detail.is_empty():
			err_msg += " (Detail: %s)" % detail
		print(err_msg)

func _run_suite() -> void:
	var gs = root.get_node_or_null("/root/GameState")
	if gs == null:
		print("  [FATAL] GameState autoload singleton not found.")
		quit(1)
		return

	await _test_1_cross_station_concurrency_and_buff_isolation(gs)
	await _test_2_server_cancel_isolation_from_barista_and_pitch(gs)
	await _test_3_barista_full_lifecycle_and_staff_integrity(gs)
	await _test_4_extended_disk_write_decoupling(gs)
	await _test_5_cooldown_cross_station_persistence(gs)

	# Teardown
	for node in _mounted_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_mounted_nodes.clear()
	_restore_savegame()

	print("\n====================================================================")
	print(">>> CHALLENGER M2-IT2-2 SUMMARY: %d PASSED, %d FAILED <<<" % [_pass_count, _fail_count])
	print("====================================================================")

	if _fail_count == 0:
		print(">>> EMPIRICAL VERDICT: APPROVE (Exit Code 0) <<<\n")
		quit(0)
	else:
		print(">>> EMPIRICAL VERDICT: REQUEST_CHANGES (Exit Code 1) <<<\n")
		quit(1)

# =============================================================================
# TEST 1: Cross-Station Concurrency & Multi-Buff Stacking
# =============================================================================
func _test_1_cross_station_concurrency_and_buff_isolation(gs: Node) -> void:
	print("\n--- TEST 1: Cross-Station Concurrency & Multi-Buff Stacking ---")
	gs.reset_state()
	gs.reset_all_station_cooldowns()

	var cm_scene = load("res://scenes/coffee_machine_3d.tscn")
	var st_scene = load("res://scenes/server_terminal.tscn")
	var ps_scene = load("res://scenes/pitch_stage.tscn")

	var cm: CoffeeMachine3D = cm_scene.instantiate() as CoffeeMachine3D
	var st: ServerTerminal = st_scene.instantiate() as ServerTerminal
	var ps: PitchStage = ps_scene.instantiate() as PitchStage

	root.add_child(cm)
	root.add_child(st)
	root.add_child(ps)
	_mounted_nodes.append(cm)
	_mounted_nodes.append(st)
	_mounted_nodes.append(ps)
	await process_frame

	# Setup base economic conditions
	gs.base_passive_rps = 100.0
	gs.hired_workers = [
		{"id": "w1", "name": "Dev", "role": "developer", "morale": 0.2, "fatigue": 0.8, "current_state": "fatigued"}
	]

	# Station 1: Barista Brew Completion
	cm.start_brewing()
	_assert_test(cm.current_state == CoffeeMachine3D.StationState.STATE_PLAYING, "1.1 CoffeeMachine is STATE_PLAYING")
	cm.complete_brew(true)
	_assert_test(cm.current_state == CoffeeMachine3D.StationState.STATE_COOLDOWN, "1.2 CoffeeMachine enters STATE_COOLDOWN")
	_assert_test(gs.is_staff_hyper_focus_active(), "1.3 Staff hyper focus active (+50% speed)")
	_assert_test(gs.is_unicorn_espresso_active(), "1.4 Unicorn espresso buff active (+50% avatar speed)")

	# Station 2: Server Terminal Perfect Overclock
	st.open_cyber_sync_minigame()
	_assert_test(st.current_state == ServerTerminal.StationState.STATE_PLAYING, "1.5 ServerTerminal is STATE_PLAYING")
	st.complete_cyber_sync(true, "Perfect", 45.0, 3.00)
	_assert_test(gs.server_overclock_buff_active, "1.6 Server overclock buff active")
	_assert_test(absf(gs.server_overclock_buff_multiplier - 3.00) < EPSILON, "1.7 Overclock multiplier is 3.00x")

	# Station 3: Pitch Stage Concurrent Action
	ps.open_pitch_minigame()
	_assert_test(ps.current_state == PitchStage.StationState.STATE_PLAYING, "1.8 PitchStage is STATE_PLAYING")
	ps._on_pitch_minigame_completed(3, 5000.0)
	ps._on_pitch_minigame_closed()
	_assert_test(ps.current_state == PitchStage.StationState.STATE_COOLDOWN, "1.9 PitchStage enters STATE_COOLDOWN")
	_assert_test(gs.energy >= 5000.0, "1.10 Energy credited from Pitch Stage")

	# Verify multi-buff co-existence without cross-pollution
	_assert_test(gs.is_staff_hyper_focus_active(), "1.11 Staff hyper focus remains active during overclock")
	_assert_test(gs.is_unicorn_espresso_active(), "1.12 Unicorn espresso remains active during overclock")
	_assert_test(gs.server_overclock_buff_active, "1.13 Server overclock remains active alongside espresso")

	# Clean up mounted nodes for next test
	cm.queue_free()
	st.queue_free()
	ps.queue_free()
	_mounted_nodes.erase(cm)
	_mounted_nodes.erase(st)
	_mounted_nodes.erase(ps)
	await process_frame

# =============================================================================
# TEST 2: Server Terminal Cancel Reversion Isolation
# =============================================================================
func _test_2_server_cancel_isolation_from_barista_and_pitch(gs: Node) -> void:
	print("\n--- TEST 2: Server Terminal Cancel Reversion Isolation ---")
	gs.reset_state()
	gs.reset_all_station_cooldowns()

	var st_scene = load("res://scenes/server_terminal.tscn")
	var st: ServerTerminal = st_scene.instantiate() as ServerTerminal
	root.add_child(st)
	_mounted_nodes.append(st)
	await process_frame

	# Pre-activate Barista coffee break and unicorn espresso
	gs.give_team_coffee_break()
	gs.activate_unicorn_espresso_buff(60.0)
	_assert_test(gs.is_staff_hyper_focus_active(), "2.1 Pre-condition: hyper focus is active")
	_assert_test(gs.is_unicorn_espresso_active(), "2.2 Pre-condition: unicorn espresso is active")

	# Open Server Terminal and simulate immediate cancellation without hitting data nodes
	st.open_cyber_sync_minigame()
	_assert_test(st.current_state == ServerTerminal.StationState.STATE_PLAYING, "2.3 Terminal opened in STATE_PLAYING")
	_assert_test(st.is_minigame_active, "2.4 is_minigame_active is true")

	# Dismiss modal (cancelled session)
	st._on_minigame_closed()

	# Verify ServerTerminal reverted cleanly to READY without activating overclock
	_assert_test(st.current_state == ServerTerminal.StationState.STATE_READY, "2.5 Terminal reverted to STATE_READY on cancel")
	_assert_test(not gs.server_overclock_buff_active, "2.6 Server overclock buff is NOT active after cancel")
	_assert_test(absf(gs.server_overclock_buff_multiplier - 1.0) < EPSILON, "2.7 Overclock multiplier is 1.0 baseline")

	# Verify Barista buffs remained 100% untouched
	_assert_test(gs.is_staff_hyper_focus_active(), "2.8 Staff hyper-focus NOT cleared by server cancel")
	_assert_test(gs.is_unicorn_espresso_active(), "2.9 Unicorn espresso NOT cleared by server cancel")

	st.queue_free()
	_mounted_nodes.erase(st)
	await process_frame

# =============================================================================
# TEST 3: Barista Full Lifecycle & Staff Integrity
# =============================================================================
func _test_3_barista_full_lifecycle_and_staff_integrity(gs: Node) -> void:
	print("\n--- TEST 3: Barista Full Lifecycle & Staff Integrity ---")
	gs.reset_state()
	gs.reset_all_station_cooldowns()

	var cm_scene = load("res://scenes/coffee_machine_3d.tscn")
	var cm: CoffeeMachine3D = cm_scene.instantiate() as CoffeeMachine3D
	root.add_child(cm)
	_mounted_nodes.append(cm)
	await process_frame

	var roster: Array = [
		{"id": "d1", "name": "Frontend", "role": "developer", "morale": 0.1, "fatigue": 0.9, "current_state": "fatigued"},
		{"id": "d2", "name": "Backend", "role": "developer", "morale": 0.3, "fatigue": 0.7, "current_state": "fatigued"},
		{"id": "d3", "name": "QA", "role": "qa", "morale": 0.0, "fatigue": 1.0, "current_state": "fatigued"}
	]
	gs.hired_workers = roster

	# Station transitions
	_assert_test(cm.can_brew(), "3.1 CoffeeMachine can_brew() initially true")
	cm.start_brewing()
	_assert_test(not cm.can_brew(), "3.2 can_brew() false while brewing")
	_assert_test(cm.current_state == CoffeeMachine3D.StationState.STATE_PLAYING, "3.3 STATE_PLAYING while brewing")

	# Successful brew completion
	cm.complete_brew(true)
	_assert_test(cm.current_state == CoffeeMachine3D.StationState.STATE_COOLDOWN, "3.4 STATE_COOLDOWN after brew")
	_assert_test(cm.is_on_cooldown, "3.5 is_on_cooldown true")
	_assert_test(absf(cm.cooldown_time_remaining - 60.0) < EPSILON, "3.6 Cooldown initialized to 60.0s")

	# Staff recovery verification
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
	_assert_test(all_fatigue_zero, "3.7 All workers fatigue reset to 0.0")
	_assert_test(all_morale_one, "3.8 All workers morale restored to 1.0")
	_assert_test(all_working, "3.9 All workers current_state restored to 'working'")

	# Cooldown decay to completion
	cm._process(60.1)
	_assert_test(cm.current_state == CoffeeMachine3D.StationState.STATE_READY, "3.10 STATE_READY after 60s cooldown")
	_assert_test(cm.can_brew(), "3.11 can_brew() restored to true")
	_assert_test(not cm.is_on_cooldown, "3.12 is_on_cooldown is false")

	cm.queue_free()
	_mounted_nodes.erase(cm)
	await process_frame

# =============================================================================
# TEST 4: Extended Disk Write Decoupling (300 Frames Continuous Decay)
# =============================================================================
func _test_4_extended_disk_write_decoupling(gs: Node) -> void:
	print("\n--- TEST 4: Extended Disk Write Decoupling (300 Frames Continuous Decay) ---")
	gs.reset_state()
	gs.reset_all_station_cooldowns()

	var cm_scene = load("res://scenes/coffee_machine_3d.tscn")
	var st_scene = load("res://scenes/server_terminal.tscn")
	var ps_scene = load("res://scenes/pitch_stage.tscn")

	var cm: CoffeeMachine3D = cm_scene.instantiate() as CoffeeMachine3D
	var st: ServerTerminal = st_scene.instantiate() as ServerTerminal
	var ps: PitchStage = ps_scene.instantiate() as PitchStage

	root.add_child(cm)
	root.add_child(st)
	root.add_child(ps)
	_mounted_nodes.append(cm)
	_mounted_nodes.append(st)
	_mounted_nodes.append(ps)
	await process_frame

	# Put all 3 stations in active cooldown
	gs.set_station_cooldown("coffee_machine", 60.0)
	gs.set_station_cooldown("server_terminal", 60.0)
	gs.set_station_cooldown("pitch_stage", 60.0)

	cm.is_on_cooldown = true
	cm.cooldown_time_remaining = 60.0
	cm.current_state = CoffeeMachine3D.StationState.STATE_COOLDOWN

	st.is_on_cooldown = true
	st.cooldown_time_remaining = 60.0
	st.current_state = ServerTerminal.StationState.STATE_COOLDOWN

	ps.is_on_cooldown = true
	ps.cooldown_time_remaining = 60.0
	ps.current_state = PitchStage.StationState.STATE_COOLDOWN

	# Plant a canary token in user://savegame.json
	var canary_token = "CANARY_TOKEN_M2_IT2_2_%d" % Time.get_ticks_msec()
	var f_canary = FileAccess.open("user://savegame.json", FileAccess.WRITE)
	if f_canary != null:
		f_canary.store_string(canary_token)
		f_canary.close()

	# Simulate 300 continuous frames at 60 FPS (5.0s game time)
	var delta = 1.0 / 60.0
	for i in range(300):
		gs._process(delta)
		cm._process(delta)
		st._process(delta)
		ps._process(delta)

	# Check canary token: if any node called save_to_disk() in any of the 300 frames,
	# the file would be overwritten with JSON
	var f_check = FileAccess.open("user://savegame.json", FileAccess.READ)
	var read_content = ""
	if f_check != null:
		read_content = f_check.get_as_text()
		f_check.close()

	_assert_test(read_content == canary_token,
		"4.1 Canary token intact across 300 frames of multi-station decay (ZERO disk writes)")
	_assert_test(gs.get_station_cooldown("coffee_machine") < 56.0,
		"4.2 GameState coffee cooldown decayed in memory (%.2fs)" % gs.get_station_cooldown("coffee_machine"))
	_assert_test(gs.get_station_cooldown("server_terminal") < 56.0,
		"4.3 GameState server cooldown decayed in memory (%.2fs)" % gs.get_station_cooldown("server_terminal"))
	_assert_test(gs.get_station_cooldown("pitch_stage") < 56.0,
		"4.4 GameState pitch cooldown decayed in memory (%.2fs)" % gs.get_station_cooldown("pitch_stage"))

	cm.queue_free()
	st.queue_free()
	ps.queue_free()
	_mounted_nodes.erase(cm)
	_mounted_nodes.erase(st)
	_mounted_nodes.erase(ps)
	await process_frame

# =============================================================================
# TEST 5: Cooldown Cross-Station Persistence & IPO Reset
# =============================================================================
func _test_5_cooldown_cross_station_persistence(gs: Node) -> void:
	print("\n--- TEST 5: Cooldown Cross-Station Persistence & IPO Reset ---")
	gs.reset_state()
	gs.reset_all_station_cooldowns()

	# Set different cooldowns for each station
	gs.set_station_cooldown("server_terminal", 45.0)
	gs.set_station_cooldown("pitch_stage", 30.0)
	gs.set_station_cooldown("coffee_machine", 15.0)
	gs.save_to_disk()

	# Verify on-disk serialization
	var f_read = FileAccess.open("user://savegame.json", FileAccess.READ)
	_assert_test(f_read != null, "5.1 savegame.json exists and opened")
	if f_read != null:
		var txt = f_read.get_as_text()
		f_read.close()
		var p = JSON.new()
		var parse_res = p.parse(txt)
		_assert_test(parse_res == OK, "5.2 savegame.json valid JSON")
		var d: Dictionary = p.data
		var cds: Dictionary = d.get("station_cooldowns", {})
		_assert_test(absf(float(cds.get("server_terminal", 0.0)) - 45.0) < EPSILON, "5.3 server_terminal saved as 45.0s")
		_assert_test(absf(float(cds.get("pitch_stage", 0.0)) - 30.0) < EPSILON, "5.4 pitch_stage saved as 30.0s")
		_assert_test(absf(float(cds.get("coffee_machine", 0.0)) - 15.0) < EPSILON, "5.5 coffee_machine saved as 15.0s")

	# Test IPO Reset: IPO must clear all station cooldowns
	gs.total_lifetime_energy = 1000000.0
	var ipo_res = gs.trigger_ipo()
	_assert_test(ipo_res.get("success", false) == true or ipo_res.has("shares_gained"), "5.6 trigger_ipo executed successfully")
	_assert_test(gs.get_station_cooldown("server_terminal") == 0.0, "5.7 server_terminal cooldown reset to 0.0 on IPO")
	_assert_test(gs.get_station_cooldown("pitch_stage") == 0.0, "5.8 pitch_stage cooldown reset to 0.0 on IPO")
	_assert_test(gs.get_station_cooldown("coffee_machine") == 0.0, "5.9 coffee_machine cooldown reset to 0.0 on IPO")
	_assert_test(gs.is_station_ready("server_terminal"), "5.10 server_terminal is_station_ready is true")
	_assert_test(gs.is_station_ready("pitch_stage"), "5.11 pitch_stage is_station_ready is true")
	_assert_test(gs.is_station_ready("coffee_machine"), "5.12 coffee_machine is_station_ready is true")
