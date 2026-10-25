extends SceneTree

## Dedicated Godot 4.3 Headless Test Suite for Phase 16 Milestone 3:
## Arcade Visuals, Audio & Ergonomics (Features 24..30)
##
## Execution:
##   godot --headless --path IdleArcade -s tests/test_phase16_m3_audio_visuals.gd

const FloatingScorePopup3D = preload("res://scripts/vfx/floating_score_popup.gd")

var pass_count: int = 0
var fail_count: int = 0

func _assert(condition: bool, description: String, detail: String = "") -> void:
	if condition:
		print("  [PASS] %s" % description)
		pass_count += 1
	else:
		fail_count += 1
		var msg: String = "  [FAIL] %s" % description
		if detail != "":
			msg += " (%s)" % detail
		print(msg)

func _init() -> void:
	print("\n====================================================================")
	print(">>> PHASE 16 MILESTONE 3: ARCADE VISUALS, AUDIO & ERGONOMICS TEST <<<")
	print("====================================================================")
	call_deferred("_run_all_tests")

func _run_all_tests() -> void:
	await _test_audio_manager_synthesis()
	await _test_haptics_manager_methods()
	await _test_floating_score_popup()
	await _test_station_popups_and_vfx()
	await _test_screen_shake_aliases()
	await _test_touch_ergonomics_and_isolation()

	print("\n====================================================================")
	print(">>> RESULTS: %d PASSED, %d FAILED <<<" % [pass_count, fail_count])
	print("====================================================================")
	if fail_count == 0:
		print(">>> ALL PHASE 16 M3 TESTS PASSED WITH 100% INTEGRITY (Exit Code 0) <<<\n")
		quit(0)
	else:
		print(">>> PHASE 16 M3 TESTS ENCOUNTERED FAILURES (Exit Code 1) <<<\n")
		quit(1)

func _test_audio_manager_synthesis() -> void:
	print("\n--- 1. Procedural Audio Synthesis (AudioManager) ---")
	var am = root.get_node_or_null("/root/AudioManager")
	_assert(am != null, "1.1 AudioManager autoload singleton is mounted")
	if am == null:
		return

	# Method signatures
	_assert(am.has_method("play_sfx_victory_jingle"), "1.2 play_sfx_victory_jingle() exists")
	_assert(am.has_method("play_sfx_victory"), "1.3 play_sfx_victory() alias exists")
	_assert(am.has_method("play_sfx_steam_hiss"), "1.4 play_sfx_steam_hiss() exists")
	_assert(am.has_method("play_sfx_qte_chime"), "1.5 play_sfx_qte_chime() exists")
	_assert(am.has_method("play_sfx_qte_correct"), "1.6 play_sfx_qte_correct() exists")
	_assert(am.has_method("play_sfx_qte_wrong"), "1.7 play_sfx_qte_wrong() exists")
	_assert(am.has_method("play_sfx_timing_hit"), "1.8 play_sfx_timing_hit() exists")
	_assert(am.has_method("play_sfx_rhythm_click"), "1.9 play_sfx_rhythm_click() exists")

	# Stream resources check
	var streams = [
		"_wav_victory_jingle",
		"_wav_steam_hiss",
		"_wav_qte_correct",
		"_wav_qte_wrong",
		"_wav_hit_perfect",
		"_wav_hit_good",
		"_wav_hit_miss"
	]
	for s_name in streams:
		var stream = am.get(s_name) as AudioStreamWAV
		_assert(stream != null, "1.10 Prebaked stream '%s' is AudioStreamWAV" % s_name)
		if stream != null:
			_assert(stream.mix_rate == 22050, "1.11 Stream '%s' has 22,050 Hz mix rate" % s_name)
			_assert(stream.data.size() > 0, "1.12 Stream '%s' has non-empty PCM buffer (%d bytes)" % [s_name, stream.data.size()])

	# Telemetry recording verification
	am.clear_history()
	am.play_sfx_victory_jingle()
	_assert(am.last_sfx_played == "victory_jingle", "1.13 Telemetry last_sfx_played recorded 'victory_jingle'")
	_assert(am.sfx_play_count == 1, "1.14 sfx_play_count incremented to 1")

	am.play_sfx_steam_hiss()
	_assert(am.last_sfx_played == "steam_hiss", "1.15 Telemetry last_sfx_played recorded 'steam_hiss'")
	_assert(am.sfx_play_count == 2, "1.16 sfx_play_count incremented to 2")

	am.play_sfx_qte_chime(true)
	_assert(am.last_sfx_played == "qte_correct", "1.17 QTE correct chime recorded 'qte_correct'")
	am.play_sfx_qte_chime(false)
	_assert(am.last_sfx_played == "qte_wrong", "1.18 QTE wrong chime recorded 'qte_wrong'")

	am.play_sfx_timing_hit("Perfect")
	_assert(am.last_sfx_played == "hit_perfect", "1.19 Timing hit Perfect recorded 'hit_perfect'")
	am.play_sfx_timing_hit("Good")
	_assert(am.last_sfx_played == "hit_good", "1.20 Timing hit Good recorded 'hit_good'")
	am.play_sfx_timing_hit("Miss")
	_assert(am.last_sfx_played == "hit_miss", "1.21 Timing hit Miss recorded 'hit_miss'")

func _test_haptics_manager_methods() -> void:
	print("\n--- 2. Haptics Enhancements (HapticsManager) ---")
	var hm = root.get_node_or_null("/root/HapticsManager")
	_assert(hm != null, "2.1 HapticsManager autoload singleton is mounted")
	if hm == null:
		return

	# Method signatures
	_assert(hm.has_method("vibrate_success"), "2.2 vibrate_success() exists")
	_assert(hm.has_method("vibrate_error"), "2.3 vibrate_error() exists")
	_assert(hm.has_method("vibrate_sweet_spot"), "2.4 vibrate_sweet_spot() exists")
	_assert(hm.has_method("vibrate_timing_hit"), "2.5 vibrate_timing_hit() exists")

	# Mock telemetry execution
	hm.clear_history()
	hm.vibrate_error()
	_assert(hm.get_last_vibration_ms() == 65, "2.6 vibrate_error recorded 65ms vibration")
	_assert(absf(hm.get_last_amplitude() - 0.75) < 0.01, "2.7 vibrate_error recorded 0.75 amplitude")

	hm.vibrate_sweet_spot()
	_assert(hm.get_last_vibration_ms() == 35, "2.8 vibrate_sweet_spot recorded 35ms vibration")
	_assert(absf(hm.get_last_amplitude() - 0.70) < 0.01, "2.9 vibrate_sweet_spot recorded 0.70 amplitude")

	hm.vibrate_timing_hit("Perfect")
	_assert(hm.get_last_vibration_ms() == 45, "2.10 vibrate_timing_hit('Perfect') recorded 45ms")
	_assert(absf(hm.get_last_amplitude() - 0.80) < 0.01, "2.11 vibrate_timing_hit('Perfect') recorded 0.80 amplitude")

	hm.vibrate_timing_hit("Good")
	_assert(hm.get_last_vibration_ms() == 25, "2.12 vibrate_timing_hit('Good') recorded 25ms")

	hm.vibrate_timing_hit("Miss")
	_assert(hm.get_last_vibration_ms() == 15, "2.13 vibrate_timing_hit('Miss') recorded 15ms")

func _test_floating_score_popup() -> void:
	print("\n--- 3. Centralized Floating 3D Score Popups ---")
	var popup_script = load("res://scripts/vfx/floating_score_popup.gd")
	_assert(popup_script != null, "3.1 scripts/vfx/floating_score_popup.gd loads successfully")

	var dummy_parent = Node3D.new()
	root.add_child(dummy_parent)
	await process_frame

	var label = FloatingScorePopup3D.spawn_popup_3d(dummy_parent, Vector3(0, 2, 0), "+3x BOOST!", Color(0.1, 1.0, 0.4))
	_assert(label != null, "3.2 spawn_popup_3d instantiates Label3D")
	if label != null:
		_assert(label.text == "+3x BOOST!", "3.3 Label text is '+3x BOOST!'")
		_assert(label.modulate == Color(0.1, 1.0, 0.4), "3.4 Label modulate matches neon green")
		_assert(label.billboard == BaseMaterial3D.BILLBOARD_ENABLED, "3.5 Label billboard is enabled")
		_assert(label.no_depth_test == true, "3.6 Label no_depth_test is true")

	dummy_parent.queue_free()
	await process_frame

func _test_station_popups_and_vfx() -> void:
	print("\n--- 4. Station Popups & VFX Integration ---")
	# 4.1 ServerTerminal
	var st_scene = load("res://scenes/server_terminal.tscn")
	_assert(st_scene != null, "4.1 Load res://scenes/server_terminal.tscn")
	var st = st_scene.instantiate()
	root.add_child(st)
	await process_frame

	_assert(st.has_method("spawn_score_popup"), "4.2 ServerTerminal implements spawn_score_popup()")
	var st_popup = st.spawn_score_popup("+3x BOOST!")
	_assert(st_popup != null, "4.3 ServerTerminal.spawn_score_popup returns Label3D")
	_assert(st_popup != null and st_popup.text == "+3x BOOST!", "4.4 ServerTerminal score popup text is '+3x BOOST!'")

	# Test node hit spark pulse
	st.emit_data_node_hit(0, true)
	_assert(st.matrix_sparks != null and st.matrix_sparks.emitting == true, "4.5 ServerTerminal pulses matrix_sparks on perfect node hit")
	st.emit_data_node_hit(1, false)
	_assert(st.overclock_sparks != null and st.overclock_sparks.emitting == true, "4.6 ServerTerminal pulses overclock_sparks on good node hit")

	st.queue_free()
	await process_frame

	# 4.2 PitchStage
	var ps_scene = load("res://scenes/pitch_stage.tscn")
	_assert(ps_scene != null, "4.7 Load res://scenes/pitch_stage.tscn")
	var ps = ps_scene.instantiate()
	root.add_child(ps)
	await process_frame

	_assert(ps.has_method("spawn_score_popup"), "4.8 PitchStage implements spawn_score_popup()")
	_assert(ps.has_method("_format_popup_energy"), "4.9 PitchStage implements _format_popup_energy()")
	_assert(ps._format_popup_energy(50000.0) == "50.000", "4.10 _format_popup_energy(50000) formats as '50.000'")
	_assert(ps._format_popup_energy(1234567.0) == "1.234.567", "4.11 _format_popup_energy(1234567) formats as '1.234.567'")

	var ps_popup = ps.spawn_score_popup("+50.000 ENERGY!")
	_assert(ps_popup != null and ps_popup.text == "+50.000 ENERGY!", "4.12 PitchStage score popup text is '+50.000 ENERGY!'")

	ps.queue_free()
	await process_frame

	# 4.3 CoffeeMachine3D
	var cm_scene = load("res://scenes/coffee_machine_3d.tscn")
	_assert(cm_scene != null, "4.13 Load res://scenes/coffee_machine_3d.tscn")
	var cm = cm_scene.instantiate()
	root.add_child(cm)
	await process_frame

	_assert(cm.has_node("Visuals/AromaParticles"), "4.14 scenes/coffee_machine_3d.tscn contains AromaParticles node")
	var aroma = cm.get_node_or_null("Visuals/AromaParticles") as CPUParticles3D
	_assert(aroma != null, "4.15 AromaParticles is CPUParticles3D")
	_assert(cm.has_method("spawn_score_popup"), "4.16 CoffeeMachine3D implements spawn_score_popup()")

	var cm_popup = cm.spawn_score_popup("HYPER-FOCUS 60s!")
	_assert(cm_popup != null and cm_popup.text == "HYPER-FOCUS 60s!", "4.17 CoffeeMachine score popup text is 'HYPER-FOCUS 60s!'")

	cm.queue_free()
	await process_frame

func _test_screen_shake_aliases() -> void:
	print("\n--- 5. Screen Shake Aliases & Event Pipeline ---")
	var gs = root.get_node_or_null("/root/GameState")
	_assert(gs != null, "5.1 GameState singleton is mounted")
	if gs == null:
		return

	_assert(gs.has_signal("camera_shake_requested"), "5.2 GameState declares camera_shake_requested signal")
	_assert(gs.has_method("trigger_camera_shake"), "5.3 GameState implements trigger_camera_shake()")

	var m3d_scene = load("res://scenes/main_3d.tscn")
	_assert(m3d_scene != null, "5.4 Load res://scenes/main_3d.tscn")
	var m3d = m3d_scene.instantiate()
	root.add_child(m3d)
	await process_frame

	_assert(m3d.has_method("add_screen_shake"), "5.5 Main3D implements add_screen_shake()")
	_assert(m3d.has_method("trigger_camera_shake"), "5.6 Main3D implements trigger_camera_shake() alias")

	m3d.trauma = 0.0
	m3d.trigger_camera_shake(0.35)
	_assert(absf(m3d.trauma - 0.35) < 0.01, "5.7 trigger_camera_shake(0.35) updates trauma correctly (%.2f)" % m3d.trauma)

	# Signal emission dispatch to Main3D
	m3d.trauma = 0.0
	gs.trigger_camera_shake(0.40)
	_assert(absf(m3d.trauma - 0.40) < 0.01, "5.8 GameState.trigger_camera_shake forwards to Main3D via signal (%.2f)" % m3d.trauma)
	await process_frame

	m3d.queue_free()
	await process_frame

func _test_touch_ergonomics_and_isolation() -> void:
	print("\n--- 6. Touch Ergonomics & Pointer Isolation ---")
	# CyberSyncMinigame
	var cs_scene = load("res://scenes/ui/cyber_sync_minigame.tscn")
	var cs = cs_scene.instantiate()
	root.add_child(cs)
	await process_frame

	_assert(cs.has_method("_gui_input"), "6.1 CyberSyncMinigame implements _gui_input for pointer isolation")
	_assert(cs.mouse_filter == Control.MOUSE_FILTER_STOP, "6.2 CyberSyncMinigame root has mouse_filter == STOP")

	var cs_btn = cs.get_node_or_null("%SyncHitButton") as Button
	_assert(cs_btn != null and cs_btn.size.y >= 56.0, "6.3 SyncHitButton meets >= 56px height (actual: %.1f)" % (cs_btn.size.y if cs_btn else 0.0))

	cs.queue_free()
	await process_frame

	# PitchStageMinigame
	var ps_scene = load("res://scenes/ui/pitch_stage_minigame.tscn")
	var psm = ps_scene.instantiate()
	root.add_child(psm)
	await process_frame

	_assert(psm.has_method("_gui_input"), "6.4 PitchStageMinigame implements _gui_input for pointer isolation")
	_assert(psm.mouse_filter == Control.MOUSE_FILTER_STOP, "6.5 PitchStageMinigame root has mouse_filter == STOP")

	psm.queue_free()
	await process_frame

	# EspressoBrewMinigame
	var eb_scene = load("res://scenes/ui/espresso_brew_minigame.tscn")
	var ebm = eb_scene.instantiate()
	root.add_child(ebm)
	await process_frame

	_assert(ebm.has_method("_gui_input"), "6.6 EspressoBrewMinigame implements _gui_input for pointer isolation")
	_assert(ebm.mouse_filter == Control.MOUSE_FILTER_STOP, "6.7 EspressoBrewMinigame root has mouse_filter == STOP")

	var pump_btn = ebm.get_node_or_null("%PumpButton") as Button
	_assert(pump_btn != null and pump_btn.custom_minimum_size.y >= 56.0, "6.8 PumpButton custom_minimum_size.y >= 56px (actual: %.1f)" % (pump_btn.custom_minimum_size.y if pump_btn else 0.0))

	var close_btn = ebm.get_node_or_null("%CloseButton") as Button
	_assert(close_btn != null and close_btn.custom_minimum_size.y >= 56.0, "6.9 CloseButton custom_minimum_size.y >= 56px (actual: %.1f)" % (close_btn.custom_minimum_size.y if close_btn else 0.0))

	ebm.queue_free()
	await process_frame
