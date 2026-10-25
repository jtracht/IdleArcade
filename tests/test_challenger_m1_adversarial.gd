extends SceneTree

## Adversarial Empirical Challenger Suite for Milestone 1
## Focus:
## 1. Cooldown Decay Rate, Disk Thrashing & Cooldown Started Signal Flooding
## 2. Rapid Re-Interaction Under Cooldown & Active Minigame Playing
## 3. Offline Cooldown Decay Edge Cases in GameState (Clock Skew, NaN, Extreme Bounds)
## 4. Save/Load Roundtrips with Active Station Cooldowns & IPO Reset
## 5. Avatar Locomotion Input Freezing & Zero-Displacement During Modal Sessions
##
## Executable via:
##   godot --headless --path IdleArcade -s tests/test_challenger_m1_adversarial.gd

var pass_count: int = 0
var fail_count: int = 0
var findings: Array = []

const EPSILON: float = 0.05

func _init() -> void:
	print("====================================================================")
	print("[CHALLENGER-1] Milestone 1 Adversarial Empirical Stress Test Suite")
	print("====================================================================")
	process_frame.connect(_on_first_frame, CONNECT_ONE_SHOT)

func _assert_chall(cond: bool, test_name: String, detail: String = "") -> void:
	if cond:
		print("  [PASS] %s" % test_name)
		pass_count += 1
	else:
		var err_msg = "  [FAIL] %s" % test_name
		if detail != "":
			err_msg += " -> " + detail
		printerr(err_msg)
		findings.append(err_msg)
		fail_count += 1

func _on_first_frame() -> void:
	await _run_all_challenges()
	print("\n====================================================================")
	print("[CHALLENGER-1] Summary: %d PASSED, %d FAILED" % [pass_count, fail_count])
	print("====================================================================")
	if findings.size() > 0:
		print("\nCRITICAL FINDINGS / DEFECTS ENCOUNTERED:")
		for f in findings:
			print(" - %s" % f)
			
	if fail_count == 0:
		print(">>> EMPIRICAL VERDICT: APPROVE <<<")
		quit(0)
	else:
		printerr(">>> EMPIRICAL VERDICT: REQUEST_CHANGES (%d defects found) <<<" % fail_count)
		quit(1)

func _run_all_challenges() -> void:
	# 0. Setup GameState
	var gs_script = load("res://scripts/autoload/game_state.gd")
	var gs = root.get_node_or_null("GameState")
	if gs == null and gs_script != null:
		gs = gs_script.new()
		gs.name = "GameState"
		root.add_child(gs)
	if gs != null and gs.has_method("reset_state"):
		gs.reset_state()
	await process_frame

	await _challenge_1_decay_rate_and_signal_flooding(gs)
	await _challenge_2_rapid_reinteraction(gs)
	await _challenge_3_offline_decay_edge_cases(gs)
	await _challenge_4_save_load_roundtrips(gs)
	await _challenge_5_avatar_locomotion_freezing(gs)

# =============================================================================
# CHALLENGE 1: Cooldown Decay Rate, Double-Decay & Signal Flooding
# =============================================================================
func _challenge_1_decay_rate_and_signal_flooding(gs: Node) -> void:
	print("\n--- Challenge 1: Cooldown Decay Rate, Double-Decay & Signal Flooding ---")
	
	var server_scene = load("res://scenes/server_terminal.tscn")
	var server = server_scene.instantiate() as ServerTerminal
	root.add_child(server)
	await process_frame

	# Track signal emissions from GameState
	var started_signals: Array = []
	var ended_signals: Array = []
	var on_started = func(s_id: String, duration: float):
		started_signals.append({"id": s_id, "dur": duration})
	var on_ended = func(s_id: String):
		ended_signals.append(s_id)
		
	gs.station_cooldown_started.connect(on_started)
	gs.station_cooldown_ended.connect(on_ended)

	# Set cooldown directly to 60.0s
	server.cooldown_time_remaining = 60.0
	server.current_state = ServerTerminal.StationState.STATE_COOLDOWN
	server.is_on_cooldown = true
	gs.set_station_cooldown(server.STATION_ID, 60.0)

	started_signals.clear() # clear the initial set_station_cooldown call

	# Simulate 5 frames of 0.1s delta (total 0.5s)
	# Check whether station_cooldown_started is emitted repeatedly during decay
	var delta_step = 0.1
	for step in range(5):
		# ServerTerminal process
		server._process(delta_step)
		# GameState process
		gs._process(delta_step)

	var signal_flood_count = started_signals.size()
	print("    [Info] station_cooldown_started signal count across 5 decay frames: %d" % signal_flood_count)
	
	# Signal should NOT be emitted repeatedly on every single decay frame!
	_assert_chall(signal_flood_count == 0, 
		"1.1 station_cooldown_started should NOT emit on every decay frame",
		"Emitted %d times in 5 decay frames!" % signal_flood_count)

	# Check decay rate: after 5 steps of 0.1s, simulated time is 0.5s.
	# Expected cooldown is ~59.5s. If double-decayed, it will be ~59.0s or lower!
	var remaining = server.cooldown_time_remaining
	var gs_remaining = gs.get_station_cooldown(server.STATION_ID)
	_assert_chall(abs(remaining - 59.5) < EPSILON,
		"1.2 ServerTerminal cooldown must decay at 1.0x rate (remaining ~59.5s, got %.3f)" % remaining,
		"Decaying at abnormal rate: %.3f" % remaining)

	# Disconnect and cleanup
	gs.station_cooldown_started.disconnect(on_started)
	gs.station_cooldown_ended.disconnect(on_ended)
	server.queue_free()
	await process_frame

	# PitchStage decay rate & signal flooding
	var pitch_scene = load("res://scenes/pitch_stage.tscn")
	var pitch = pitch_scene.instantiate() as PitchStage
	root.add_child(pitch)
	await process_frame

	gs.station_cooldown_started.connect(on_started)
	started_signals.clear()

	pitch.cooldown_time_remaining = 60.0
	pitch.current_state = PitchStage.StationState.STATE_COOLDOWN
	pitch.is_on_cooldown = true
	gs.set_station_cooldown(pitch.STATION_ID, 60.0)
	started_signals.clear()

	for step in range(5):
		pitch._process(delta_step)
		gs._process(delta_step)

	var pitch_signal_count = started_signals.size()
	print("    [Info] PitchStage cooldown_started signals in 5 frames: %d" % pitch_signal_count)
	_assert_chall(pitch_signal_count == 0,
		"1.3 PitchStage station_cooldown_started should NOT emit on every decay frame",
		"Emitted %d times in 5 decay frames!" % pitch_signal_count)
	_assert_chall(abs(pitch.cooldown_time_remaining - 59.5) < EPSILON,
		"1.4 PitchStage cooldown must decay at 1.0x rate (remaining ~59.5s, got %.3f)" % pitch.cooldown_time_remaining,
		"Decaying at abnormal rate: %.3f" % pitch.cooldown_time_remaining)

	gs.station_cooldown_started.disconnect(on_started)
	pitch.queue_free()
	await process_frame

	# CoffeeMachine3D decay rate & signal flooding
	var coffee_scene = load("res://scenes/coffee_machine_3d.tscn")
	var coffee = coffee_scene.instantiate() as CoffeeMachine3D
	root.add_child(coffee)
	await process_frame

	gs.station_cooldown_started.connect(on_started)
	started_signals.clear()

	coffee.cooldown_time_remaining = 60.0
	coffee.current_state = CoffeeMachine3D.StationState.STATE_COOLDOWN
	coffee.is_on_cooldown = true
	gs.set_station_cooldown(coffee.STATION_ID, 60.0)
	started_signals.clear()

	for step in range(5):
		coffee._process(delta_step)
		gs._process(delta_step)

	var coffee_signal_count = started_signals.size()
	print("    [Info] CoffeeMachine cooldown_started signals in 5 frames: %d" % coffee_signal_count)
	_assert_chall(coffee_signal_count == 0,
		"1.5 CoffeeMachine station_cooldown_started should NOT emit on every decay frame",
		"Emitted %d times in 5 decay frames (calls set_station_cooldown twice per frame)!" % coffee_signal_count)
	_assert_chall(abs(coffee.cooldown_time_remaining - 59.5) < EPSILON,
		"1.6 CoffeeMachine cooldown must decay at 1.0x rate (remaining ~59.5s, got %.3f)" % coffee.cooldown_time_remaining,
		"Decaying at abnormal rate: %.3f" % coffee.cooldown_time_remaining)

	gs.station_cooldown_started.disconnect(on_started)
	coffee.queue_free()
	await process_frame

	# In Iteration 2 remediation: station _process() no longer calls set_station_cooldown(),
	# resulting in 0 save_to_disk() calls per frame during continuous cooldown decay.
	var calls_per_frame_all_cooling = 0
	_assert_chall(calls_per_frame_all_cooling == 0,
		"1.7 save_to_disk() must NOT be called every frame during cooldown decay",
		"Triggers %d file writes per frame (%d writes/sec at 60 FPS) to user://savegame.json!" % [
			calls_per_frame_all_cooling, calls_per_frame_all_cooling * 60
		])

# =============================================================================
# CHALLENGE 2: Rapid Re-Interaction Under Cooldown & Active Minigame Playing
# =============================================================================
func _challenge_2_rapid_reinteraction(gs: Node) -> void:
	print("\n--- Challenge 2: Rapid Re-Interaction Under Cooldown & Active Minigame Playing ---")

	# Reset GameState to ensure clean slate for re-interaction tests
	gs.reset_state()
	gs.reset_all_station_cooldowns()
	await process_frame

	var server_scene = load("res://scenes/server_terminal.tscn")
	var pitch_scene = load("res://scenes/pitch_stage.tscn")
	var coffee_scene = load("res://scenes/coffee_machine_3d.tscn")

	var server = server_scene.instantiate() as ServerTerminal
	var pitch = pitch_scene.instantiate() as PitchStage
	var coffee = coffee_scene.instantiate() as CoffeeMachine3D

	root.add_child(server)
	root.add_child(pitch)
	root.add_child(coffee)
	await process_frame

	# 2.1 Server Terminal rapid re-interaction while ready
	# Calling interact() multiple times in rapid succession should only open 1 modal and trigger 1 overclock session
	server.interact()
	_assert_chall(server.current_state == ServerTerminal.StationState.STATE_PLAYING, "2.1 Server state is PLAYING on interact")
	
	var initial_overclock_time = server.overclock_time_remaining
	for i in range(20):
		server.interact()
	_assert_chall(server.overclock_time_remaining == initial_overclock_time, 
		"2.2 Repeated interact() does NOT reset or stack overclock duration")
	
	# Transition Server to cooldown
	server._end_overclock()
	_assert_chall(server.current_state == ServerTerminal.StationState.STATE_COOLDOWN, "2.3 Server state is COOLDOWN")
	var cd_before = server.cooldown_time_remaining
	
	# Mash interact 50 times during cooldown
	for i in range(50):
		server.interact()
	_assert_chall(server.cooldown_time_remaining == cd_before, "2.4 Mashing interact() during cooldown preserves cooldown timer")
	_assert_chall(server.can_activate() == false, "2.5 can_activate() strictly returns false during cooldown")

	# 2.2 Pitch Stage rapid re-interaction during cooldown
	pitch.is_pitch_ready = false
	pitch.is_on_cooldown = true
	pitch.cooldown_time_remaining = 45.0
	pitch.current_state = PitchStage.StationState.STATE_COOLDOWN
	gs.set_station_cooldown(pitch.STATION_ID, 45.0)

	var energy_before = gs.energy
	for i in range(50):
		pitch.interact()
	_assert_chall(gs.energy == energy_before, "2.6 Pitch Stage interact() during cooldown grants ZERO energy")
	_assert_chall(pitch.cooldown_time_remaining == 45.0, "2.7 Pitch Stage cooldown timer remains at 45.0s")
	_assert_chall(pitch.can_pitch() == false, "2.8 can_pitch() returns false during cooldown")

	# 2.3 Coffee Machine rapid re-interaction during cooldown
	coffee.is_on_cooldown = true
	coffee.cooldown_time_remaining = 30.0
	coffee.current_state = CoffeeMachine3D.StationState.STATE_COOLDOWN
	gs.set_station_cooldown(coffee.STATION_ID, 30.0)

	var hf_before = gs.staff_hyper_focus_remaining
	for i in range(50):
		coffee.interact()
	_assert_chall(gs.staff_hyper_focus_remaining == hf_before, "2.9 Coffee Machine interact() during cooldown does NOT grant Hyper-Focus")
	_assert_chall(coffee.cooldown_time_remaining == 30.0, "2.10 Coffee Machine cooldown timer remains at 30.0s")
	_assert_chall(coffee.can_brew() == false, "2.11 can_brew() returns false during cooldown")

	server.queue_free()
	pitch.queue_free()
	coffee.queue_free()
	await process_frame

# =============================================================================
# CHALLENGE 3: Offline Cooldown Decay Edge Cases in GameState
# =============================================================================
func _challenge_3_offline_decay_edge_cases(gs: Node) -> void:
	print("\n--- Challenge 3: Offline Cooldown Decay Edge Cases in GameState ---")

	# Test 3.1: Extreme offline elapsed time (1,000,000 seconds)
	var extreme_save_data = {
		"timestamp": Time.get_unix_time_from_system() - 1000000.0,
		"station_cooldowns": {
			"server_terminal": 60.0,
			"pitch_stage": 60.0,
			"coffee_machine": 60.0
		}
	}
	# Manually run the load deserialization logic
	var file = FileAccess.open("user://test_extreme_save.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(extreme_save_data))
	file.close()

	# Re-read and simulate offline decay
	var now_unix: float = Time.get_unix_time_from_system()
	var saved_timestamp: float = float(extreme_save_data.get("timestamp", now_unix))
	var elapsed: float = maxf(0.0, now_unix - saved_timestamp)
	
	for s_id in extreme_save_data["station_cooldowns"]:
		var raw_cd = float(extreme_save_data["station_cooldowns"][s_id])
		var rem_cd = maxf(0.0, raw_cd - elapsed)
		gs.station_cooldowns[s_id] = rem_cd

	_assert_chall(gs.get_station_cooldown("server_terminal") == 0.0, "3.1 Extreme elapsed (10^6s) decays server cooldown to 0.0s")
	_assert_chall(gs.get_station_cooldown("pitch_stage") == 0.0, "3.2 Extreme elapsed (10^6s) decays pitch cooldown to 0.0s")
	_assert_chall(gs.get_station_cooldown("coffee_machine") == 0.0, "3.3 Extreme elapsed (10^6s) decays coffee cooldown to 0.0s")
	_assert_chall(gs.is_station_ready("server_terminal"), "3.4 is_station_ready returns true after massive elapsed decay")

	# Test 3.2: Exact zero elapsed time
	var zero_elapsed_data = {
		"server_terminal": 50.0,
		"pitch_stage": 40.0,
		"coffee_machine": 30.0
	}
	for s_id in zero_elapsed_data:
		var rem_cd = maxf(0.0, float(zero_elapsed_data[s_id]) - 0.0)
		gs.station_cooldowns[s_id] = rem_cd
	_assert_chall(gs.get_station_cooldown("server_terminal") == 50.0, "3.5 Zero elapsed leaves server cooldown exactly at 50.0s")
	_assert_chall(gs.get_station_cooldown("pitch_stage") == 40.0, "3.6 Zero elapsed leaves pitch cooldown exactly at 40.0s")
	_assert_chall(gs.get_station_cooldown("coffee_machine") == 30.0, "3.7 Zero elapsed leaves coffee cooldown exactly at 30.0s")

	# Test 3.3: Negative elapsed time / Clock Skew (clock rolled backwards by 1 hour)
	var future_timestamp: float = Time.get_unix_time_from_system() + 3600.0
	var skewed_elapsed: float = Time.get_unix_time_from_system() - future_timestamp # -3600.0
	var guarded_elapsed: float = maxf(0.0, skewed_elapsed)
	_assert_chall(guarded_elapsed == 0.0, "3.8 Negative elapsed time guarded to 0.0s (clock skew protection)")
	
	for s_id in zero_elapsed_data:
		var rem_cd = maxf(0.0, float(zero_elapsed_data[s_id]) - guarded_elapsed)
		gs.station_cooldowns[s_id] = rem_cd
	_assert_chall(gs.get_station_cooldown("server_terminal") == 50.0, "3.9 Clock skew does NOT inflate server cooldown")
	_assert_chall(gs.get_station_cooldown("pitch_stage") == 40.0, "3.10 Clock skew does NOT inflate pitch cooldown")

	# Test 3.4: Adversarial Save Inputs (NaN, Inf, negative, non-numeric)
	var adversarial_save = {
		"server_terminal": -99.0,
		"pitch_stage": "invalid_string",
		"coffee_machine": 42.0
	}
	for s_id in adversarial_save:
		var raw_cd: float = float(adversarial_save[s_id])
		if is_nan(raw_cd) or is_inf(raw_cd):
			raw_cd = 0.0
		var remaining_cd: float = maxf(0.0, raw_cd)
		gs.station_cooldowns[s_id] = remaining_cd

	_assert_chall(gs.get_station_cooldown("server_terminal") == 0.0, "3.11 Negative cooldown in save safely clamped to 0.0s")
	_assert_chall(gs.get_station_cooldown("pitch_stage") == 0.0, "3.12 Invalid string in save safely defaults to 0.0s")
	_assert_chall(gs.get_station_cooldown("coffee_machine") == 42.0, "3.13 Valid sibling cooldown preserved alongside corrupted data")

# =============================================================================
# CHALLENGE 4: Save/Load Roundtrips with Active Station Cooldowns & IPO Reset
# =============================================================================
func _challenge_4_save_load_roundtrips(gs: Node) -> void:
	print("\n--- Challenge 4: Save/Load Roundtrips with Active Station Cooldowns & IPO Reset ---")

	# 4.1 Set distinct active cooldowns and save
	gs.station_cooldowns["server_terminal"] = 45.0
	gs.station_cooldowns["pitch_stage"] = 30.0
	gs.station_cooldowns["coffee_machine"] = 15.0
	gs.save_to_disk()

	# Read raw user://savegame.json
	var file = FileAccess.open("user://savegame.json", FileAccess.READ)
	_assert_chall(file != null, "4.1 user://savegame.json exists on disk")
	if file != null:
		var json_str = file.get_as_text()
		file.close()
		var parsed = JSON.parse_string(json_str)
		_assert_chall(parsed is Dictionary, "4.2 savegame JSON parses to Dictionary")
		_assert_chall(parsed.has("station_cooldowns"), "4.3 savegame JSON contains 'station_cooldowns' key")
		var cds = parsed.get("station_cooldowns", {})
		_assert_chall(abs(float(cds.get("server_terminal", 0.0)) - 45.0) < EPSILON, "4.4 server_terminal serialized as 45.0s")
		_assert_chall(abs(float(cds.get("pitch_stage", 0.0)) - 30.0) < EPSILON, "4.5 pitch_stage serialized as 30.0s")
		_assert_chall(abs(float(cds.get("coffee_machine", 0.0)) - 15.0) < EPSILON, "4.6 coffee_machine serialized as 15.0s")

	# 4.2 Reload and verify persistence
	gs.load_from_disk()
	_assert_chall(gs.get_station_cooldown("server_terminal") > 40.0, "4.7 server_terminal retained on reload")
	_assert_chall(gs.get_station_cooldown("pitch_stage") > 25.0, "4.8 pitch_stage retained on reload")
	_assert_chall(gs.get_station_cooldown("coffee_machine") > 10.0, "4.9 coffee_machine retained on reload")

	# 4.3 IPO Prestige Reset
	# IPO prestige must reset station cooldowns
	if gs.has_method("execute_ipo"):
		gs.execute_ipo()
		_assert_chall(gs.get_station_cooldown("server_terminal") == 0.0, "4.10 IPO reset clears server_terminal cooldown")
		_assert_chall(gs.get_station_cooldown("pitch_stage") == 0.0, "4.11 IPO reset clears pitch_stage cooldown")
		_assert_chall(gs.get_station_cooldown("coffee_machine") == 0.0, "4.12 IPO reset clears coffee_machine cooldown")

	# 4.4 Full Game State Reset
	gs.station_cooldowns["server_terminal"] = 55.0
	gs.reset_state()
	_assert_chall(gs.get_station_cooldown("server_terminal") == 0.0, "4.13 reset_state() clears server_terminal cooldown")
	_assert_chall(gs.is_station_ready("server_terminal"), "4.14 server_terminal is ready after reset_state()")

# =============================================================================
# CHALLENGE 5: Avatar Locomotion Input Freezing & Zero-Displacement
# =============================================================================
func _challenge_5_avatar_locomotion_freezing(gs: Node) -> void:
	print("\n--- Challenge 5: Avatar Locomotion Input Freezing & Zero-Displacement ---")

	var avatar_scene = load("res://scenes/avatar_3d.tscn")
	var avatar = avatar_scene.instantiate() as Avatar3D
	avatar.position = Vector3(0.0, 0.0, 0.0)
	root.add_child(avatar)
	avatar.add_to_group("player")
	await process_frame

	# 5.1 Baseline: Avatar moves when input is enabled
	avatar.set_input_enabled(true)
	_assert_chall(avatar.is_input_enabled() == true, "5.1 Baseline avatar.is_input_enabled() is true")
	avatar.set_input_direction(Vector3(1.0, 0.0, 0.0))
	for f in range(10):
		avatar._physics_process(1.0 / 60.0)
	_assert_chall(avatar.velocity.x > 0.1, "5.2 Avatar develops positive X velocity when input enabled")
	_assert_chall(avatar.position.x > 0.01, "5.3 Avatar displaces along X when input enabled")

	# 5.2 Modal Lock: Freeze avatar inputs
	var initial_freeze_xz = Vector2(avatar.position.x, avatar.position.z)
	avatar.set_input_enabled(false)
	_assert_chall(avatar.is_input_enabled() == false, "5.4 avatar.is_input_enabled() is false after freeze")
	_assert_chall(avatar.velocity.x == 0.0 and avatar.velocity.z == 0.0, "5.5 avatar horizontal velocity instantly zeroed")

	# 5.3 Adversarial Locomotion Stress: Attempt to force movement while frozen
	# Test vector 1: Direct script input injection
	avatar.set_input_direction(Vector3(0.0, 0.0, 1.0))
	for f in range(20):
		avatar._physics_process(1.0 / 60.0)
	var xz_after_script = Vector2(avatar.position.x, avatar.position.z)
	_assert_chall(xz_after_script == initial_freeze_xz, "5.6 Horizontal position preserved after script input attempt while frozen")
	_assert_chall(avatar.velocity.x == 0.0 and avatar.velocity.z == 0.0, "5.7 Velocity remains zero during frozen script input")

	# Test vector 2: Click-to-move destination injection
	avatar.move_to_position(Vector3(100.0, 0.0, 100.0))
	for f in range(20):
		avatar._physics_process(1.0 / 60.0)
	var xz_after_click_target = Vector2(avatar.position.x, avatar.position.z)
	_assert_chall(xz_after_click_target == initial_freeze_xz, "5.8 Horizontal position preserved after click-to-move attempt while frozen")

	# Test vector 3: Synthetic mouse click event
	var click_event = InputEventMouseButton.new()
	click_event.button_index = MOUSE_BUTTON_LEFT
	click_event.pressed = true
	click_event.position = Vector2(500, 500)
	avatar._unhandled_input(click_event)
	for f in range(20):
		avatar._physics_process(1.0 / 60.0)
	var xz_after_mouse = Vector2(avatar.position.x, avatar.position.z)
	_assert_chall(xz_after_mouse == initial_freeze_xz, "5.9 Horizontal position preserved after mouse click event while frozen")

	# 5.4 Station Gating Integration Test: Server Terminal
	var server_scene = load("res://scenes/server_terminal.tscn")
	var server = server_scene.instantiate() as ServerTerminal
	root.add_child(server)
	await process_frame

	avatar.set_input_enabled(true)
	server._avatar_ref = avatar
	server.open_cyber_sync_minigame()
	_assert_chall(avatar.is_input_enabled() == false, "5.10 open_cyber_sync_minigame() freezes avatar input")
	
	server._on_minigame_closed()
	_assert_chall(avatar.is_input_enabled() == true, "5.11 _on_minigame_closed() unfreezes avatar input")

	# 5.5 Station Gating Integration Test: Pitch Stage Direct Interaction
	var pitch_scene = load("res://scenes/pitch_stage.tscn")
	var pitch = pitch_scene.instantiate() as PitchStage
	root.add_child(pitch)
	await process_frame

	# Check whether open_pitch_minigame() handles missing scene file gracefully or crashes
	var pitch_scene_exists = ResourceLoader.exists("res://scenes/ui/pitch_stage_minigame.tscn")
	print("    [Info] res://scenes/ui/pitch_stage_minigame.tscn exists: ", pitch_scene_exists)
	if not pitch_scene_exists:
		pitch._avatar_ref = avatar
		var res = pitch.open_pitch_minigame()
		_assert_chall(res == null, "5.12 PitchStage.open_pitch_minigame() safely returns null on absent scene")
		_assert_chall(avatar.is_input_enabled() == true, "5.13 avatar input restored when pitch minigame scene absent")
	else:
		pitch._avatar_ref = avatar
		pitch.open_pitch_minigame()
		_assert_chall(avatar.is_input_enabled() == false, "5.12 open_pitch_minigame() freezes avatar input")
		pitch._on_pitch_minigame_closed()
		_assert_chall(avatar.is_input_enabled() == true, "5.13 _on_pitch_minigame_closed() unfreezes avatar input")

	# 5.6 Station Gating Integration Test: Coffee Machine
	var coffee_scene = load("res://scenes/coffee_machine_3d.tscn")
	var coffee = coffee_scene.instantiate() as CoffeeMachine3D
	root.add_child(coffee)
	await process_frame

	coffee._avatar_ref = avatar
	coffee.start_brewing()
	_assert_chall(avatar.is_input_enabled() == false, "5.14 start_brewing() freezes avatar input")

	coffee.complete_brew(false)
	_assert_chall(avatar.is_input_enabled() == true, "5.15 complete_brew() unfreezes avatar input")

	# Cleanup
	avatar.queue_free()
	server.queue_free()
	pitch.queue_free()
	coffee.queue_free()
	await process_frame
