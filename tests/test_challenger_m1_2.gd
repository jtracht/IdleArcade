extends SceneTree

## =============================================================================
## Empirical Challenger 2 Test Suite for Milestone 1:
## Multi-Station Concurrency, Touch Ergonomics & Modal Lifecycle
## File: IdleArcade/tests/test_challenger_m1_2.gd
## =============================================================================

var pass_count: int = 0
var fail_count: int = 0

const EPSILON: float = 0.01
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
		fail_count += 1

func _init() -> void:
	print("\n====================================================================")
	print(">>> RUNNING CHALLENGER 2: MULTI-STATION CONCURRENCY & TOUCH ERGONOMICS <<<")
	print("====================================================================")
	call_deferred("_run_tests")

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
		print("  [CLEANUP] Removed test savegame.json")

	for i in range(_mounted_nodes.size() - 1, -1, -1):
		var n = _mounted_nodes[i]
		if is_instance_valid(n):
			if n.get_parent() != null:
				n.get_parent().remove_child(n)
			n.free()
	_mounted_nodes.clear()

	print("\n====================================================================")
	print(">>> CHALLENGER 2 RESULTS: %d PASSED, %d FAILED <<<" % [pass_count, fail_count])
	print("====================================================================")

	if fail_count == 0:
		print(">>> ALL CHALLENGER CHECKS PASSED (Exit Code 0) <<<\n")
		quit(0)
	else:
		printerr(">>> CHALLENGER CHECKS FAILED WITH %d FAILURES (Exit Code 1) <<<\n" % fail_count)
		quit(1)

func _run_tests() -> void:
	await process_frame

	if FileAccess.file_exists("user://savegame.json"):
		var f_back = FileAccess.open("user://savegame.json", FileAccess.READ)
		if f_back != null:
			_save_backup_text = f_back.get_as_text()
			_had_save_backup = true
			f_back.close()

	# -------------------------------------------------------------------------
	# Setup singletons
	# -------------------------------------------------------------------------
	var gs_script = load("res://scripts/autoload/game_state.gd")
	var gs = root.get_node_or_null("GameState")
	if gs == null:
		gs = gs_script.new()
		gs.name = "GameState"
		root.add_child(gs)
		_mounted_nodes.append(gs)
	if gs.has_method("reset_state"):
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

	# =========================================================================
	# PART 1: Multi-Station Concurrent Cooldowns
	# =========================================================================
	print("\n--- PART 1: Multi-Station Concurrent Cooldowns ---")

	# 1.1 Setting all 3 stations on cooldown concurrently
	gs.reset_all_station_cooldowns()
	gs.set_station_cooldown("server_terminal", 60.0)
	gs.set_station_cooldown("pitch_stage", 60.0)
	gs.set_station_cooldown("coffee_machine", 60.0)

	_assert_check(gs.is_station_on_cooldown("server_terminal"), "1.1.1 server_terminal is on cooldown in GameState")
	_assert_check(gs.is_station_on_cooldown("pitch_stage"), "1.1.2 pitch_stage is on cooldown in GameState")
	_assert_check(gs.is_station_on_cooldown("coffee_machine"), "1.1.3 coffee_machine is on cooldown in GameState")

	_assert_check(absf(gs.get_station_cooldown("server_terminal") - 60.0) < EPSILON, "1.1.4 server_terminal cooldown is 60.0s")
	_assert_check(absf(gs.get_station_cooldown("pitch_stage") - 60.0) < EPSILON, "1.1.5 pitch_stage cooldown is 60.0s")
	_assert_check(absf(gs.get_station_cooldown("coffee_machine") - 60.0) < EPSILON, "1.1.6 coffee_machine cooldown is 60.0s")

	# 1.2 Alias lookup support
	_assert_check(absf(gs.get_station_cooldown("barista_station") - 60.0) < EPSILON, "1.2.1 barista_station alias maps to coffee_machine")
	_assert_check(absf(gs.get_station_cooldown("coffee_machine_3d") - 60.0) < EPSILON, "1.2.2 coffee_machine_3d alias maps to coffee_machine")

	# 1.3 Active decay in GameState._process
	gs._process(15.0)
	_assert_check(absf(gs.get_station_cooldown("server_terminal") - 45.0) < EPSILON, "1.3.1 server_terminal decayed to 45.0s")
	_assert_check(absf(gs.get_station_cooldown("pitch_stage") - 45.0) < EPSILON, "1.3.2 pitch_stage decayed to 45.0s")
	_assert_check(absf(gs.get_station_cooldown("coffee_machine") - 45.0) < EPSILON, "1.3.3 coffee_machine decayed to 45.0s")

	# 1.4 Instantiating 3 stations and verifying sync with GameState
	var server_scene = load("res://scenes/server_terminal.tscn")
	var coffee_scene = load("res://scenes/coffee_machine_3d.tscn")
	var pitch_scene = load("res://scenes/pitch_stage.tscn")

	_assert_check(server_scene != null, "1.4.1 server_terminal.tscn loaded")
	_assert_check(coffee_scene != null, "1.4.2 coffee_machine_3d.tscn loaded")
	_assert_check(pitch_scene != null, "1.4.3 pitch_stage.tscn loaded")

	var st = server_scene.instantiate() as ServerTerminal
	var cm = coffee_scene.instantiate() as CoffeeMachine3D
	var ps = pitch_scene.instantiate() as PitchStage
	root.add_child(st)
	root.add_child(cm)
	root.add_child(ps)
	_mounted_nodes.append(st)
	_mounted_nodes.append(cm)
	_mounted_nodes.append(ps)
	await process_frame

	# Stations should initialize with GameState cooldowns (45.0s)
	_assert_check(absf(st.cooldown_time_remaining - 45.0) < 1.0, "1.4.4 ServerTerminal synced initial cooldown from GameState (~45s, actual: %.1f)" % st.cooldown_time_remaining)
	_assert_check(absf(cm.cooldown_time_remaining - 45.0) < 1.0, "1.4.5 CoffeeMachine3D synced initial cooldown from GameState (~45s, actual: %.1f)" % cm.cooldown_time_remaining)
	_assert_check(absf(ps.cooldown_time_remaining - 45.0) < 1.0, "1.4.6 PitchStage synced initial cooldown from GameState (~45s, actual: %.1f)" % ps.cooldown_time_remaining)

	# Verify states during cooldown
	_assert_check(st.current_state == ServerTerminal.StationState.STATE_COOLDOWN, "1.4.7 ServerTerminal in STATE_COOLDOWN")
	_assert_check(cm.current_state == CoffeeMachine3D.StationState.STATE_COOLDOWN, "1.4.8 CoffeeMachine3D in STATE_COOLDOWN")
	_assert_check(ps.current_state == PitchStage.StationState.STATE_COOLDOWN, "1.4.9 PitchStage in STATE_COOLDOWN")

	_assert_check(not st.can_activate(), "1.4.10 ServerTerminal can_activate() is false")
	_assert_check(not cm.can_brew(), "1.4.11 CoffeeMachine3D can_brew() is false")
	_assert_check(not ps.can_pitch(), "1.4.12 PitchStage can_pitch() is false")

	# 1.5 Parallel restoration to READY
	gs._process(46.0)
	st._process(46.0)
	cm._process(46.0)
	ps._process(46.0)

	_assert_check(st.can_activate(), "1.5.1 ServerTerminal restored to READY")
	_assert_check(cm.can_brew(), "1.5.2 CoffeeMachine3D restored to READY")
	_assert_check(ps.can_pitch(), "1.5.3 PitchStage restored to READY")

	_assert_check(st.current_state == ServerTerminal.StationState.STATE_READY, "1.5.4 ServerTerminal state is STATE_READY")
	_assert_check(cm.current_state == CoffeeMachine3D.StationState.STATE_READY, "1.5.5 CoffeeMachine3D state is STATE_READY")
	_assert_check(ps.current_state == PitchStage.StationState.STATE_READY, "1.5.6 PitchStage state is STATE_READY")

	_assert_check(gs.is_station_ready("server_terminal"), "1.5.7 GameState reports server_terminal ready")
	_assert_check(gs.is_station_ready("coffee_machine"), "1.5.8 GameState reports coffee_machine ready")
	_assert_check(gs.is_station_ready("pitch_stage"), "1.5.9 GameState reports pitch_stage ready")

	# 1.6 Persistence roundtrip with concurrent cooldowns and offline catch-up
	gs.set_station_cooldown("server_terminal", 30.0)
	gs.set_station_cooldown("pitch_stage", 45.0)
	gs.set_station_cooldown("coffee_machine", 15.0)
	gs.save_to_disk()

	var f_read = FileAccess.open("user://savegame.json", FileAccess.READ)
	_assert_check(f_read != null, "1.6.0 Save file exists on disk")
	if f_read != null:
		var save_json_str = f_read.get_as_text()
		f_read.close()
		var json_parser = JSON.new()
		if json_parser.parse(save_json_str) == OK:
			var save_dict: Dictionary = json_parser.data
			var cur_ts: int = int(save_dict.get("timestamp", 0))
			save_dict["timestamp"] = cur_ts - 10
			var f_write = FileAccess.open("user://savegame.json", FileAccess.WRITE)
			if f_write != null:
				f_write.store_string(JSON.stringify(save_dict, "\t"))
				f_write.close()

	var load_ok = gs.load_from_disk()
	_assert_check(load_ok, "1.6.1 load_from_disk() succeeded with offline decay")
	_assert_check(absf(gs.get_station_cooldown("server_terminal") - 20.0) < 1.5, "1.6.2 server_terminal after 10s offline is ~20s (actual: %.1f)" % gs.get_station_cooldown("server_terminal"))
	_assert_check(absf(gs.get_station_cooldown("pitch_stage") - 35.0) < 1.5, "1.6.3 pitch_stage after 10s offline is ~35s (actual: %.1f)" % gs.get_station_cooldown("pitch_stage"))
	_assert_check(absf(gs.get_station_cooldown("coffee_machine") - 5.0) < 1.5, "1.6.4 coffee_machine after 10s offline is ~5s (actual: %.1f)" % gs.get_station_cooldown("coffee_machine"))

	# 1.7 Empirical Investigation: Cooldown decay synchronization and signal emission analysis
	print("\n--- 1.7 Cooldown Synchronization & Signal Analysis ---")
	var signal_tracker = {"count": 0, "ids": []}
	var on_cd_started = func(s_id: String, dur: float):
		signal_tracker["count"] = int(signal_tracker["count"]) + 1
		signal_tracker["ids"].append(s_id)
	gs.station_cooldown_started.connect(on_cd_started)

	# Trigger cooldown on ServerTerminal
	st.is_on_cooldown = true
	st.cooldown_time_remaining = 60.0
	gs.set_station_cooldown("server_terminal", 60.0)
	var initial_signal_count = int(signal_tracker["count"])
	_assert_check(initial_signal_count >= 1, "1.7.1 Cooldown start emits station_cooldown_started")

	# Now simulate 3 ticks of st._process(1.0)
	signal_tracker["count"] = 0
	st._process(1.0)
	st._process(1.0)
	st._process(1.0)
	var tick_signal_count = int(signal_tracker["count"])
	print("  [DIAGNOSTIC] station_cooldown_started emitted %d times across 3 station process ticks" % tick_signal_count)
	_assert_check(tick_signal_count == 0, "1.7.2 Observation: station_cooldown_started NOT emitted during process decay (tick_signal_count == 0)")

	# 1.7.3 Cooldown Decay Rate when both GameState and Station process ticks
	gs.reset_all_station_cooldowns()
	gs.set_station_cooldown("server_terminal", 60.0)
	st.is_on_cooldown = true
	st.cooldown_time_remaining = 60.0

	# 1 second of simulation
	gs._process(1.0)
	st._process(1.0)

	var gs_rem = gs.get_station_cooldown("server_terminal")
	var st_rem = st.cooldown_time_remaining
	print("  [DIAGNOSTIC] After 1.0s elapsed: GameState cd = %.2f, Station cd = %.2f" % [gs_rem, st_rem])
	# If gs decrements 1s and st decrements 1s, the net remaining is 58.0s (2x speed decay!)
	var is_double_decay = (absf(gs_rem - 58.0) < 0.1)
	print("  [DIAGNOSTIC] Double decay detected: %s" % str(is_double_decay))
	_assert_check(not is_double_decay and absf(gs_rem - 59.0) < 0.1 and absf(st_rem - 59.0) < 0.1, "1.7.3 Decay rate measured: GameState=%.1fs, Station=%.1fs (Double decay: %s)" % [gs_rem, st_rem, str(is_double_decay)])

	gs.station_cooldown_started.disconnect(on_cd_started)
	gs.reset_all_station_cooldowns()

	# =========================================================================
	# PART 2: Proximity Transitions & Priority Stack Unwinding in TouchControls
	# =========================================================================
	print("\n--- PART 2: Proximity Transitions & Priority Stack Unwinding ---")

	var tc_scene = load("res://scenes/ui/touch_controls.tscn")
	_assert_check(tc_scene != null, "2.1 touch_controls.tscn loaded")

	var tc = tc_scene.instantiate() as TouchControls
	root.add_child(tc)
	_mounted_nodes.append(tc)
	await process_frame

	var action_btn: Button = tc.action_button
	_assert_check(action_btn != null, "2.2 ActionButton exists in TouchControls")
	_assert_check(action_btn.text == "[E] Action", "2.3 Initial ActionButton text is '[E] Action'")
	_assert_check(absf(action_btn.modulate.a - tc.dormant_opacity) < EPSILON, "2.4 Initial ActionButton opacity is dormant (0.35)")

	# 2.1 First station entry: ServerTerminal
	tc.register_interactable(st, "Hack [E]")
	_assert_check(tc.active_interactable == st, "2.1.1 active_interactable is ServerTerminal")
	_assert_check(action_btn.text == "Hack [E]", "2.1.2 ActionButton text updated to 'Hack [E]'")
	_assert_check(absf(action_btn.modulate.a - tc.active_opacity) < EPSILON, "2.1.3 ActionButton opacity is active (1.0)")
	_assert_check(tc.active_interactables.size() == 1, "2.1.4 Stack size is 1")

	# 2.2 Second station entry: CoffeeMachine3D (overlapping proximity)
	tc.register_interactable(cm, "Brew [E]")
	_assert_check(tc.active_interactable == cm, "2.2.1 active_interactable updated to CoffeeMachine3D")
	_assert_check(action_btn.text == "Brew [E]", "2.2.2 ActionButton text updated to 'Brew [E]'")
	_assert_check(tc.active_interactables.size() == 2, "2.2.3 Stack size is 2")

	# 2.3 Third station entry: PitchStage (triple overlap)
	tc.register_interactable(ps, "Pitch [E]")
	_assert_check(tc.active_interactable == ps, "2.3.1 active_interactable updated to PitchStage")
	_assert_check(action_btn.text == "Pitch [E]", "2.3.2 ActionButton text updated to 'Pitch [E]'")
	_assert_check(tc.active_interactables.size() == 3, "2.3.3 Stack size is 3")

	# 2.4 LIFO unwinding: exit PitchStage
	tc.unregister_interactable(ps)
	_assert_check(tc.active_interactables.size() == 2, "2.4.1 Stack size is 2 after exiting PitchStage")
	_assert_check(tc.active_interactable == cm, "2.4.2 active_interactable reverted to CoffeeMachine3D")
	_assert_check(action_btn.text == "Brew [E]", "2.4.3 ActionButton text reverted to 'Brew [E]'")

	# Exit CoffeeMachine3D
	tc.unregister_interactable(cm)
	_assert_check(tc.active_interactables.size() == 1, "2.4.4 Stack size is 1 after exiting CoffeeMachine3D")
	_assert_check(tc.active_interactable == st, "2.4.5 active_interactable reverted to ServerTerminal")
	_assert_check(action_btn.text == "Hack [E]", "2.4.6 ActionButton text reverted to 'Hack [E]'")

	# Exit ServerTerminal
	tc.unregister_interactable(st)
	_assert_check(tc.active_interactables.size() == 0, "2.4.7 Stack size is 0 after exiting ServerTerminal")
	_assert_check(tc.active_interactable == null, "2.4.8 active_interactable is null")
	_assert_check(action_btn.text == "[E] Action", "2.4.9 ActionButton text returned to '[E] Action'")
	_assert_check(absf(action_btn.modulate.a - tc.dormant_opacity) < EPSILON, "2.4.10 ActionButton opacity returned to dormant (0.35)")

	# 2.5 Non-LIFO unwinding: Middle node exits first
	tc.register_interactable(st, "Hack [E]")
	tc.register_interactable(cm, "Brew [E]")
	tc.register_interactable(ps, "Pitch [E]")
	_assert_check(tc.active_interactables.size() == 3, "2.5.1 Stack refilled to 3")

	# Exit CoffeeMachine (middle node) while PitchStage is top
	tc.unregister_interactable(cm)
	_assert_check(tc.active_interactables.size() == 2, "2.5.2 Stack size is 2 after middle node exit")
	_assert_check(tc.active_interactable == ps, "2.5.3 active_interactable remains PitchStage")
	_assert_check(action_btn.text == "Pitch [E]", "2.5.4 ActionButton text remains 'Pitch [E]'")

	# Now exit PitchStage -> should jump directly back to ServerTerminal
	tc.unregister_interactable(ps)
	_assert_check(tc.active_interactables.size() == 1, "2.5.5 Stack size is 1 after top node exit")
	_assert_check(tc.active_interactable == st, "2.5.6 active_interactable jumped cleanly to ServerTerminal")
	_assert_check(action_btn.text == "Hack [E]", "2.5.7 ActionButton text jumped cleanly to 'Hack [E]'")

	tc.unregister_interactable(st)
	_assert_check(tc.active_interactables.is_empty(), "2.5.8 Stack empty")

	# 2.6 Bottom node exits first
	tc.register_interactable(st, "Hack [E]")
	tc.register_interactable(cm, "Brew [E]")
	tc.register_interactable(ps, "Pitch [E]")

	# Exit ServerTerminal (bottom node)
	tc.unregister_interactable(st)
	_assert_check(tc.active_interactables.size() == 2, "2.6.1 Stack size is 2 after bottom node exit")
	_assert_check(tc.active_interactable == ps, "2.6.2 active_interactable remains top (PitchStage)")

	# Exit PitchStage -> should fall back to CoffeeMachine
	tc.unregister_interactable(ps)
	_assert_check(tc.active_interactable == cm, "2.6.3 active_interactable falls back to CoffeeMachine")
	_assert_check(action_btn.text == "Brew [E]", "2.6.4 ActionButton text is 'Brew [E]'")
	tc.unregister_interactable(cm)

	# 2.7 Duplicate registration resilience
	tc.register_interactable(st, "Hack [E]")
	tc.register_interactable(st, "Hack [E]")
	tc.register_interactable(st, "Hack [E]")
	_assert_check(tc.active_interactables.size() == 1, "2.7.1 Duplicate registration prevented, stack size is 1")
	tc.unregister_interactable(st)
	_assert_check(tc.active_interactables.is_empty(), "2.7.2 Unregistering removes single entry")

	# 2.8 Unregistering un-registered node does not crash
	tc.unregister_interactable(st)
	tc.unregister_interactable(null)
	_assert_check(tc.active_interactable == null, "2.8.1 Safe unregister with null or missing node")

	# =========================================================================
	# PART 3: TouchControls Fading During Modal Lifecycle
	# =========================================================================
	print("\n--- PART 3: TouchControls Fading During Modal Lifecycle ---")

	# 3.1 Normal fade out
	_assert_check(tc.visible, "3.1.1 TouchControls initially visible")
	_assert_check(absf(tc.modulate.a - 1.0) < EPSILON, "3.1.2 TouchControls modulate.a is 1.0")

	var vis_tracker = {"emitted": false, "val": true}
	var on_vis_changed = func(v: bool):
		vis_tracker["emitted"] = true
		vis_tracker["val"] = v
	tc.controls_visibility_changed.connect(on_vis_changed)

	tc.fade_out_controls(0.02)
	_assert_check(tc.is_faded_out, "3.1.3 is_faded_out set to true immediately")

	# Await tween finished
	if tc._fade_tween != null and tc._fade_tween.is_valid():
		await tc._fade_tween.finished
	await process_frame

	_assert_check(absf(tc.modulate.a - 0.0) < 0.05, "3.1.4 modulate.a faded to 0.0 (actual: %.2f)" % tc.modulate.a)
	_assert_check(not tc.visible, "3.1.5 visible set to false after fade out")
	_assert_check(bool(vis_tracker["emitted"]) and bool(vis_tracker["val"]) == false, "3.1.6 controls_visibility_changed(false) emitted")

	# 3.2 Normal fade in
	vis_tracker["emitted"] = false
	tc.fade_in_controls(0.02)
	_assert_check(not tc.is_faded_out, "3.2.1 is_faded_out set to false immediately")
	_assert_check(tc.visible, "3.2.2 visible set to true immediately upon fade_in")

	if tc._fade_tween != null and tc._fade_tween.is_valid():
		await tc._fade_tween.finished
	await process_frame

	_assert_check(absf(tc.modulate.a - 1.0) < 0.05, "3.2.3 modulate.a faded to 1.0 (actual: %.2f)" % tc.modulate.a)
	_assert_check(bool(vis_tracker["emitted"]) and bool(vis_tracker["val"]) == true, "3.2.4 controls_visibility_changed(true) emitted")

	# 3.3 Mid-tween interruption (rapid cancel / toggle)
	tc.fade_out_controls(0.20)
	_assert_check(tc.is_faded_out, "3.3.1 fade_out started")
	await process_frame

	# Interrupt with fade_in
	tc.fade_in_controls(0.02)
	_assert_check(not tc.is_faded_out, "3.3.2 fade_in interrupted fade_out")
	_assert_check(tc.visible, "3.3.3 visible restored immediately")

	if tc._fade_tween != null and tc._fade_tween.is_valid():
		await tc._fade_tween.finished
	await process_frame

	_assert_check(absf(tc.modulate.a - 1.0) < 0.05, "3.3.4 Final modulate.a is 1.0 after interrupted fade (actual: %.2f)" % tc.modulate.a)
	_assert_check(tc.visible, "3.3.5 Final visible is true after interrupted fade")

	# 3.4 Modal lifecycle integration with Station
	var avatar_scene = load("res://scenes/avatar_3d.tscn")
	var av = null
	if avatar_scene != null:
		av = avatar_scene.instantiate()
		root.add_child(av)
		_mounted_nodes.append(av)
		await process_frame

	if av != null:
		_assert_check(av.has_method("is_input_enabled") and av.is_input_enabled(), "3.4.1 Avatar input initially enabled")

		# Open minigame on ServerTerminal
		var modal = st.open_cyber_sync_minigame()
		_assert_check(modal != null, "3.4.2 CyberSyncMinigame opened")
		_assert_check(not av.is_input_enabled(), "3.4.3 Avatar input disabled while minigame open")
		_assert_check(tc.is_faded_out, "3.4.4 TouchControls faded out while minigame open")
		_assert_check(st.current_state == ServerTerminal.StationState.STATE_PLAYING, "3.4.5 ServerTerminal state is STATE_PLAYING")

		# Close minigame modal
		if modal.has_signal("closed"):
			modal.closed.emit()
		await process_frame

		_assert_check(av.is_input_enabled(), "3.4.6 Avatar input restored after minigame closed")
		_assert_check(not tc.is_faded_out, "3.4.7 TouchControls un-faded after minigame closed")
		_assert_check(tc.visible, "3.4.8 TouchControls visible after minigame closed")

		# 3.5 Rapid modal open/close cycle stress test (5 cycles)
		var cycles_passed: bool = true
		for cycle_idx in range(5):
			var m_inst = st.open_cyber_sync_minigame()
			if av.is_input_enabled() or not tc.is_faded_out:
				cycles_passed = false
			if m_inst.has_signal("closed"):
				m_inst.closed.emit()
			await process_frame
			if not av.is_input_enabled() or tc.is_faded_out:
				cycles_passed = false

		_assert_check(cycles_passed, "3.5.1 Rapid modal open/close cycle (5x) preserved gating integrity")
		_assert_check(av.is_input_enabled(), "3.5.2 Avatar input enabled after rapid cycles")
		_assert_check(tc.visible and not tc.is_faded_out, "3.5.3 TouchControls visible after rapid cycles")

	# -------------------------------------------------------------------------
	# Finish and report
	# -------------------------------------------------------------------------
	tc.controls_visibility_changed.disconnect(on_vis_changed)
	_cleanup_and_quit(0 if fail_count == 0 else 1)
