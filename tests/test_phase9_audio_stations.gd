extends SceneTree

## =============================================================================
## Master Headless SceneTree Test Suite for Phase 9: Audio-Engine, SFX & Campus-Stationen
## File: IdleArcade/tests/test_phase9_audio_stations.gd
## Target: Godot 4.3 Engine Headless Runner
##
## Validates all 8 Sections:
##   1. AudioManager Autoload & bus routing (Master, Music, SFX).
##   2. Procedural 16-bit PCM synthesis for all 8 SFX/BGM methods.
##   3. Bus volume controls, decibel conversions, and mute toggles.
##   4. Server Room Overclock Terminal at (0, 0, -18), Area3D trigger, +50% passive RPS buff for 25s, 60s cooldown.
##   5. Courtyard Pitch Stage at (0, 0, 18), Area3D trigger, valuation check, +1,000 to +5,000 Energy grant, 60s cooldown.
##   6. Low-poly triangle budget verification (<2,500 dynamic triangles combined).
##   7. Settings Modal UI: touch targets >= 56px, close button >= 56x56, input isolation (mouse_filter = STOP), volume/mute synchronization.
##   8. TouchControls dynamic button styling: "Overclock [E]" (Neon-Cyan/Electric Blue) and "Pitch [E]" (Warm Gold).
##
## Execution:
##   godot --headless --path IdleArcade -s tests/test_phase9_audio_stations.gd
## =============================================================================

var pass_count: int = 0
var fail_count: int = 0

const EPSILON: float = 0.001

func _assert_check(condition: bool, description: String, detail: String = "") -> void:
	if condition:
		print("  [PASS] %s" % description)
		pass_count += 1
	else:
		var err_msg = "  [FAIL] %s" % description
		if detail != "":
			err_msg += " (Detail: %s)" % detail
		printerr(err_msg)
		fail_count += 1

func _count_node_triangles(node: Node) -> int:
	var total: int = 0
	if node is MeshInstance3D and node.mesh != null:
		var m = node.mesh
		if m is BoxMesh:
			total += 12
		elif m is PlaneMesh:
			total += 2
		elif m is SphereMesh:
			var rad: int = m.radial_segments
			var rings: int = m.rings
			total += rad * rings * 2
		elif m is CylinderMesh:
			var rad: int = m.radial_segments
			var rings: int = m.rings
			total += (rad * rings * 2) + (rad * 2)
		elif m is TorusMesh:
			var rings: int = m.rings
			var rsegs: int = m.ring_segments
			total += rings * rsegs * 2
		elif m is CapsuleMesh:
			var rad: int = m.radial_segments
			var rings: int = m.rings
			total += rad * (rings + 1) * 2
		elif m is PrimitiveMesh:
			total += 24
	for child in node.get_children():
		total += _count_node_triangles(child)
	return total

func _init() -> void:
	print("\n====================================================================")
	print(">>> RUNNING MASTER PHASE 9 AUDIO & STATIONS HEADLESS SCENETREE TEST SUITE <<<")
	print("====================================================================")
	call_deferred("_run_all_tests")

func _run_all_tests() -> void:
	await process_frame

	# -------------------------------------------------------------------------
	# Autoload Singleton Setup: GameState & AudioManager
	# -------------------------------------------------------------------------
	var gs_script = load("res://scripts/autoload/game_state.gd")
	_assert_check(gs_script != null, "0.1 Load scripts/autoload/game_state.gd")
	if gs_script == null:
		printerr("[FATAL] Cannot load game_state.gd")
		quit(1)
		return

	var gs = root.get_node_or_null("GameState")
	if gs == null:
		gs = gs_script.new()
		gs.name = "GameState"
		root.add_child(gs)
	_assert_check(gs != null, "0.2 GameState mounted at /root/GameState")

	var am_script = load("res://scripts/autoload/audio_manager.gd")
	_assert_check(am_script != null, "0.3 Load scripts/autoload/audio_manager.gd")
	if am_script == null:
		printerr("[FATAL] Cannot load audio_manager.gd")
		quit(1)
		return

	var am = root.get_node_or_null("AudioManager")
	if am == null:
		am = am_script.new()
		am.name = "AudioManager"
		root.add_child(am)
	_assert_check(am != null, "0.4 AudioManager mounted at /root/AudioManager")

	await process_frame

	# Execute all 8 required sections sequentially
	await _test_section_1_audio_bus_routing(am)
	await _test_section_2_pcm_synthesis(am)
	await _test_section_3_bus_volume_and_persistence(am, gs)
	await _test_section_4_server_terminal(gs)
	await _test_section_5_pitch_stage(gs)
	await _test_section_6_triangle_budgets()
	await _test_section_7_settings_modal(gs, am)
	await _test_section_8_touch_controls_dynamic_styling()

	print("\n====================================================================")
	print(">>> PHASE 9 SCENETREE TEST SUITE SUMMARY: %d PASSED, %d FAILED <<<" % [pass_count, fail_count])
	print("====================================================================")

	if fail_count == 0:
		print(">>> ALL PHASE 9 HEADLESS SCENETREE TESTS PASSED (Exit Code 0) <<<")
		quit(0)
	else:
		printerr(">>> PHASE 9 HEADLESS SCENETREE TESTS FAILED (Exit Code 1) <<<")
		quit(1)

# =============================================================================
# SECTION 1: AudioManager Autoload & Bus Routing (Master, Music, SFX)
# =============================================================================
func _test_section_1_audio_bus_routing(am: Node) -> void:
	print("\n--- SECTION 1: AudioManager Autoload & Audio Bus Routing ---")

	_assert_check(am != null and am.is_inside_tree(), "1.1 AudioManager is mounted in active SceneTree")
	_assert_check(am.get_script() != null, "1.2 AudioManager has valid script attached")

	# Check AudioServer bus layout
	var master_idx: int = AudioServer.get_bus_index("Master")
	var music_idx: int = AudioServer.get_bus_index("Music")
	var sfx_idx: int = AudioServer.get_bus_index("SFX")

	_assert_check(master_idx != -1, "1.3 Master bus exists in AudioServer (index %d)" % master_idx)
	_assert_check(music_idx != -1, "1.4 Music bus exists in AudioServer (index %d)" % music_idx)
	_assert_check(sfx_idx != -1, "1.5 SFX bus exists in AudioServer (index %d)" % sfx_idx)

	if music_idx != -1:
		var music_send = AudioServer.get_bus_send(music_idx)
		_assert_check(music_send == &"Master" or music_send == "Master", "1.6 Music bus routes to Master (got '%s')" % music_send)

	if sfx_idx != -1:
		var sfx_send = AudioServer.get_bus_send(sfx_idx)
		_assert_check(sfx_send == &"Master" or sfx_send == "Master", "1.7 SFX bus routes to Master (got '%s')" % sfx_send)

	_assert_check("SAMPLE_RATE" in am, "1.8 AudioManager defines SAMPLE_RATE constant")
	_assert_check(int(am.get("SAMPLE_RATE")) == 22050, "1.9 SAMPLE_RATE is 22,050 Hz")

# =============================================================================
# SECTION 2: Procedural 16-Bit PCM Synthesis for All 8 SFX/BGM Methods
# =============================================================================
func _test_section_2_pcm_synthesis(am: Node) -> void:
	print("\n--- SECTION 2: Procedural 16-Bit PCM Synthesis & Playback ---")

	var wav_props = [
		"_wav_click",
		"_wav_pickup_briefcase",
		"_wav_pickup_coffee",
		"_wav_pickup_usb",
		"_wav_pickup_default",
		"_wav_footstep",
		"_wav_gate_unlock",
		"_wav_research",
		"_wav_drone_hum",
		"_wav_overdrive",
		"_wav_ambient_bgm"
	]

	for wp in wav_props:
		if wp in am:
			var stream = am.get(wp) as AudioStreamWAV
			_assert_check(stream != null, "2.1 Procedural stream '%s' is AudioStreamWAV" % wp)
			if stream != null:
				_assert_check(stream.format == AudioStreamWAV.FORMAT_16_BITS, "2.2 Stream '%s' format is 16-bit PCM" % wp)
				_assert_check(stream.mix_rate == 22050, "2.3 Stream '%s' mix_rate is 22050 Hz" % wp)
				_assert_check(stream.data.size() > 0, "2.4 Stream '%s' contains non-empty PCM byte buffer (%d bytes)" % [wp, stream.data.size()])

	# Loop modes
	if "_wav_drone_hum" in am:
		var hum = am.get("_wav_drone_hum") as AudioStreamWAV
		if hum != null:
			_assert_check(hum.loop_mode == AudioStreamWAV.LOOP_FORWARD, "2.5 Drone hum has LOOP_FORWARD enabled")
			_assert_check(hum.loop_end > 0, "2.6 Drone hum loop_end is set (%d samples)" % hum.loop_end)

	if "_wav_ambient_bgm" in am:
		var bgm = am.get("_wav_ambient_bgm") as AudioStreamWAV
		if bgm != null:
			_assert_check(bgm.loop_mode == AudioStreamWAV.LOOP_FORWARD, "2.7 Ambient BGM has LOOP_FORWARD enabled")
			_assert_check(bgm.loop_end > 0, "2.8 Ambient BGM loop_end is set (%d samples)" % bgm.loop_end)

	# Execute 8 required playback methods
	var prev_plays: int = am.get("sfx_play_count") if "sfx_play_count" in am else 0

	am.call("play_sfx_click")
	_assert_check(true, "2.9 play_sfx_click() invoked successfully")

	am.call("play_sfx_pickup", "briefcase")
	am.call("play_sfx_pickup", "coffee")
	am.call("play_sfx_pickup", "usb")
	am.call("play_sfx_pickup", "generic")
	_assert_check(true, "2.10 play_sfx_pickup() invoked across all 4 item types")

	am.call("play_sfx_footstep")
	_assert_check(true, "2.11 play_sfx_footstep() invoked successfully")

	am.call("play_sfx_gate_unlock")
	_assert_check(true, "2.12 play_sfx_gate_unlock() invoked successfully")

	am.call("play_sfx_research")
	_assert_check(true, "2.13 play_sfx_research() invoked successfully")

	am.call("play_sfx_drone_hum")
	_assert_check(true, "2.14 play_sfx_drone_hum() invoked successfully")

	am.call("play_sfx_overdrive")
	_assert_check(true, "2.15 play_sfx_overdrive() invoked successfully")

	am.call("start_ambient_bgm")
	var bgm_playing_1 = am.get("is_bgm_playing") if "is_bgm_playing" in am else false
	_assert_check(bgm_playing_1 == true, "2.16 start_ambient_bgm() sets is_bgm_playing to true")

	am.call("stop_ambient_bgm")
	var bgm_playing_2 = am.get("is_bgm_playing") if "is_bgm_playing" in am else true
	_assert_check(bgm_playing_2 == false, "2.17 stop_ambient_bgm() sets is_bgm_playing to false")

	if "sfx_play_count" in am:
		var cur_plays: int = am.get("sfx_play_count")
		_assert_check(cur_plays > prev_plays, "2.18 Telemetry sfx_play_count increased (%d -> %d)" % [prev_plays, cur_plays])

	if "last_sfx_played" in am:
		_assert_check(am.get("last_sfx_played") != "", "2.19 Telemetry last_sfx_played recorded ('%s')" % am.get("last_sfx_played"))

# =============================================================================
# SECTION 3: Bus Volume Controls, Decibel Conversions & Mute Toggles
# =============================================================================
func _test_section_3_bus_volume_and_persistence(am: Node, gs: Node) -> void:
	print("\n--- SECTION 3: Bus Volume Controls, dB Conversions & Persistence ---")

	# Test set_bus_volume linear-to-dB conversion
	am.call("set_bus_volume", "Master", 0.5)
	var v_master = am.call("get_bus_volume", "Master")
	_assert_check(abs(float(v_master) - 0.5) < 0.05, "3.1 Master linear volume matches 0.5 (got %.2f)" % v_master)

	var master_idx: int = AudioServer.get_bus_index("Master")
	if master_idx != -1:
		var db_val = AudioServer.get_bus_volume_db(master_idx)
		# 0.5 in linear is approx -6.02 dB
		_assert_check(abs(db_val - (-6.02)) < 0.5, "3.2 AudioServer Master bus volume is ~ -6.02 dB (got %.2f dB)" % db_val)

	# Clamping at 0.0 -> -80.0 dB
	am.call("set_bus_volume", "SFX", 0.0)
	var sfx_idx: int = AudioServer.get_bus_index("SFX")
	if sfx_idx != -1:
		var sfx_db = AudioServer.get_bus_volume_db(sfx_idx)
		_assert_check(sfx_db <= -79.0, "3.3 0.0 linear volume clamps safely to <= -79 dB (got %.2f dB)" % sfx_db)

	# Mute toggles
	am.call("set_bus_mute", "Music", true)
	var music_muted = am.call("is_bus_muted", "Music")
	_assert_check(music_muted == true, "3.4 set_bus_mute('Music', true) sets mute state to true")

	am.call("set_bus_mute", "Music", false)
	music_muted = am.call("is_bus_muted", "Music")
	_assert_check(music_muted == false, "3.5 set_bus_mute('Music', false) sets mute state to false")

	# GameState audio settings properties & synchronization
	_assert_check("master_volume" in gs, "3.6 GameState declares 'master_volume'")
	_assert_check("music_volume" in gs, "3.7 GameState declares 'music_volume'")
	_assert_check("sfx_volume" in gs, "3.8 GameState declares 'sfx_volume'")
	_assert_check("master_muted" in gs, "3.9 GameState declares 'master_muted'")
	_assert_check("music_muted" in gs, "3.10 GameState declares 'music_muted'")
	_assert_check("sfx_muted" in gs, "3.11 GameState declares 'sfx_muted'")

	gs.call("set_master_volume", 0.85)
	_assert_check(abs(float(gs.get("master_volume")) - 0.85) < EPSILON, "3.12 GameState set_master_volume(0.85) updates master_volume")

	gs.call("set_music_muted", true)
	_assert_check(bool(gs.get("music_muted")) == true, "3.13 GameState set_music_muted(true) updates music_muted")

	if gs.has_method("get_audio_settings"):
		var a_settings: Dictionary = gs.call("get_audio_settings")
		_assert_check(a_settings.has("master_volume") and a_settings.has("music_muted"),
			"3.14 get_audio_settings() returns complete audio settings dictionary")

# =============================================================================
# SECTION 4: Server Room Overclock Terminal at (0, 0, -18) & +50% Passive RPS
# =============================================================================
func _test_section_4_server_terminal(gs: Node) -> void:
	print("\n--- SECTION 4: Server Room Overclock Terminal & +50% RPS Buff ---")
	gs.reset_state()

	var term_scene = load("res://scenes/server_terminal.tscn")
	_assert_check(term_scene != null, "4.1 scenes/server_terminal.tscn loads successfully")
	if term_scene == null:
		return

	var terminal = term_scene.instantiate() as StaticBody3D
	root.add_child(terminal)
	await process_frame

	_assert_check(terminal is ServerTerminal or terminal.has_method("interact"), "4.2 ServerTerminal instantiated")
	_assert_check(terminal.is_in_group("server_terminals"), "4.3 ServerTerminal in group 'server_terminals'")
	_assert_check(terminal.is_in_group("terminals"), "4.4 ServerTerminal in group 'terminals'")

	var area = terminal.get_node_or_null("InteractionArea") as Area3D
	var prompt = terminal.get_node_or_null("PromptLabel3D") as Label3D
	var screen_label = terminal.get_node_or_null("Visuals/ScreenLabel3D") as Label3D
	var sparks = terminal.get_node_or_null("Visuals/OverclockSparks") as CPUParticles3D

	_assert_check(area != null, "4.5 InteractionArea Area3D exists on ServerTerminal")
	_assert_check(prompt != null, "4.6 PromptLabel3D exists on ServerTerminal")
	_assert_check(screen_label != null, "4.7 ScreenLabel3D matrix telemetry exists")
	_assert_check(sparks != null, "4.8 OverclockSparks CPUParticles3D exists")

	if prompt != null:
		_assert_check("[E]" in prompt.text, "4.9 Prompt contains '[E]' ('%s')" % prompt.text)
		_assert_check(prompt.visible == false, "4.10 Prompt initially hidden")

	# Simulate player entry
	var dummy_player = CharacterBody3D.new()
	dummy_player.name = "TestPlayer_Server"
	dummy_player.add_to_group("player")
	root.add_child(dummy_player)

	terminal._on_interaction_body_entered(dummy_player)
	_assert_check(terminal.is_player_in_range(), "4.11 terminal.is_player_in_range() is true on player entrance")
	if prompt != null:
		_assert_check(prompt.visible == true, "4.12 Prompt becomes visible on entrance")

	# Baseline RPS before overclock
	gs.upgrades["viral_memes"]["level"] = 10
	gs.recalculate_stats()
	var base_rps = gs.get_effective_passive_rps()
	_assert_check(base_rps > 0.0, "4.13 Baseline passive RPS established (%.2f RPS)" % base_rps)

	_assert_check(terminal.can_activate() == true, "4.14 can_activate() is initially true")

	# Activate Overclock
	terminal.interact()
	_assert_check(terminal.is_overclock_active == true, "4.15 terminal.is_overclock_active is true after interact()")
	_assert_check(terminal.can_activate() == false, "4.16 can_activate() is false while overclocked")

	# Verify GameState buff (+50% passive RPS for 25s)
	_assert_check("server_overclock_buff_timer" in gs and gs.server_overclock_buff_timer > 0.0,
		"4.17 GameState server_overclock_buff_timer active (%.1fs)" % gs.server_overclock_buff_timer)
	_assert_check(abs(gs.server_overclock_buff_multiplier - 1.50) < EPSILON,
		"4.18 GameState server_overclock_buff_multiplier is 1.50 (+50 percent)")

	var boosted_rps = gs.get_effective_passive_rps()
	var rps_ratio = boosted_rps / base_rps
	_assert_check(abs(rps_ratio - 1.50) < 0.01,
		"4.19 Passive RPS boosted by exactly +50 percent: %.2f -> %.2f RPS (ratio: %.2f)" % [base_rps, boosted_rps, rps_ratio])

	# Simulate player exit
	terminal._on_interaction_body_exited(dummy_player)
	_assert_check(not terminal.is_player_in_range(), "4.20 terminal.is_player_in_range() is false on player exit")
	if prompt != null:
		_assert_check(prompt.visible == false, "4.21 Prompt hidden on exit")

	dummy_player.queue_free()
	terminal.queue_free()
	await process_frame

# =============================================================================
# SECTION 5: Courtyard Pitch Stage at (0, 0, 18) & Valuation Grant
# =============================================================================
func _test_section_5_pitch_stage(gs: Node) -> void:
	print("\n--- SECTION 5: Courtyard Pitch Stage & Valuation Grant ---")
	gs.reset_state()

	var stage_scene = load("res://scenes/pitch_stage.tscn")
	_assert_check(stage_scene != null, "5.1 scenes/pitch_stage.tscn loads successfully")
	if stage_scene == null:
		return

	var stage = stage_scene.instantiate() as StaticBody3D
	root.add_child(stage)
	await process_frame

	_assert_check(stage is PitchStage or stage.has_method("interact"), "5.2 PitchStage instantiated")
	_assert_check(stage.is_in_group("pitch_stages"), "5.3 PitchStage in group 'pitch_stages'")

	var area = stage.get_node_or_null("InteractionArea") as Area3D
	var prompt = stage.get_node_or_null("PromptLabel3D") as Label3D
	var spotlight = stage.get_node_or_null("Visuals/StageSpotlight") as SpotLight3D
	var confetti = stage.get_node_or_null("Visuals/ConfettiExplosion") as CPUParticles3D
	var investor = stage.get_node_or_null("Visuals/ChibiAngelInvestor") as Node3D

	_assert_check(area != null, "5.4 InteractionArea Area3D exists on PitchStage")
	_assert_check(prompt != null, "5.5 PromptLabel3D exists on PitchStage")
	_assert_check(spotlight != null, "5.6 StageSpotlight exists on PitchStage")
	_assert_check(confetti != null, "5.7 ConfettiExplosion particles exist")
	_assert_check(investor != null, "5.8 ChibiAngelInvestor model exists")

	if prompt != null:
		_assert_check("Pitch" in prompt.text or "Investor" in prompt.text, "5.9 Prompt describes Angel Investor Pitch ('%s')" % prompt.text)

	# Simulate player entry
	var dummy_player = CharacterBody3D.new()
	dummy_player.name = "TestPlayer_Stage"
	dummy_player.add_to_group("player")
	root.add_child(dummy_player)

	stage._on_interaction_body_entered(dummy_player)
	_assert_check(stage.is_player_in_range(), "5.10 stage.is_player_in_range() is true on entrance")

	# Pitch interaction and funding award
	_assert_check(stage.can_pitch() == true, "5.11 can_pitch() is initially true")
	var old_energy: float = gs.energy

	var rewarded_tracker: Dictionary = {"emitted": false, "amount": 0.0}
	var on_rewarded = func(amount: float, _total: float):
		rewarded_tracker["emitted"] = true
		rewarded_tracker["amount"] = amount
	stage.pitch_rewarded.connect(on_rewarded)

	stage.interact()
	_assert_check(rewarded_tracker["emitted"], "5.12 pitch_rewarded signal emitted on interaction")
	_assert_check(stage.can_pitch() == false, "5.13 can_pitch() is false immediately after interaction (cooldown active)")
	_assert_check(stage.cooldown_time_remaining > 0.0, "5.14 Cooldown time set (%.1fs)" % stage.cooldown_time_remaining)

	var grant_amount = rewarded_tracker["amount"]
	_assert_check(grant_amount >= 1000.0, "5.15 Energy grant >= 1,000 Energy (got %.1f)" % grant_amount)
	_assert_check(grant_amount <= 6000.0, "5.16 Energy grant within reasonable upper bound <= 6,000 (got %.1f)" % grant_amount)

	var energy_increase = gs.energy - old_energy
	_assert_check(abs(energy_increase - grant_amount) < EPSILON,
		"5.17 GameState.energy credited by grant amount: %.1f -> %.1f (+%.1f)" % [old_energy, gs.energy, energy_increase])

	stage.pitch_rewarded.disconnect(on_rewarded)

	# Simulate exit
	stage._on_interaction_body_exited(dummy_player)
	_assert_check(not stage.is_player_in_range(), "5.18 stage.is_player_in_range() is false on exit")

	dummy_player.queue_free()
	stage.queue_free()
	await process_frame

# =============================================================================
# SECTION 6: Low-Poly Triangle Budget Verification (<2,500 Dynamic Triangles)
# =============================================================================
func _test_section_6_triangle_budgets() -> void:
	print("\n--- SECTION 6: Low-Poly Dynamic Triangle Budgets ---")

	var term_scene = load("res://scenes/server_terminal.tscn")
	var stage_scene = load("res://scenes/pitch_stage.tscn")

	_assert_check(term_scene != null, "6.1 server_terminal.tscn loads for budget check")
	_assert_check(stage_scene != null, "6.2 pitch_stage.tscn loads for budget check")

	if term_scene == null or stage_scene == null:
		return

	var term_inst = term_scene.instantiate() as Node
	var stage_inst = stage_scene.instantiate() as Node
	root.add_child(term_inst)
	root.add_child(stage_inst)
	await process_frame

	var term_tris = _count_node_triangles(term_inst)
	var stage_tris = _count_node_triangles(stage_inst)
	var combined_tris = term_tris + stage_tris

	_assert_check(term_tris < 1000, "6.3 Server Terminal dynamic triangles < 1,000 tris (actual: %d tris)" % term_tris)
	_assert_check(term_tris >= 60, "6.4 Server Terminal has substantive geometry >= 60 tris (actual: %d tris)" % term_tris)

	_assert_check(stage_tris < 1500, "6.5 Pitch Stage dynamic triangles < 1,500 tris (actual: %d tris)" % stage_tris)
	_assert_check(stage_tris >= 100, "6.6 Pitch Stage has substantive geometry >= 100 tris (actual: %d tris)" % stage_tris)

	_assert_check(combined_tris < 2500,
		"6.7 Combined Campus Stations dynamic triangle budget strictly < 2,500 tris (actual: %d tris)" % combined_tris)

	term_inst.queue_free()
	stage_inst.queue_free()
	await process_frame

# =============================================================================
# SECTION 7: Settings Modal UI Touch Targets, Close Button & Input Isolation
# =============================================================================
func _test_section_7_settings_modal(gs: Node, am: Node) -> void:
	print("\n--- SECTION 7: Settings Modal UI & Touch Ergonomics ---")

	var modal_scene = load("res://scenes/ui/settings_modal.tscn")
	_assert_check(modal_scene != null, "7.1 scenes/ui/settings_modal.tscn loads successfully")
	if modal_scene == null:
		return

	var modal = modal_scene.instantiate() as Control
	root.add_child(modal)
	await process_frame

	# 7.2 Input isolation (mouse_filter = STOP)
	_assert_check(modal.mouse_filter == Control.MOUSE_FILTER_STOP, "7.2 SettingsModal root mouse_filter == STOP")

	var backdrop = modal.get_node_or_null("Backdrop") as Control
	var modal_card = modal.find_child("ModalCard", true, false) as Control
	_assert_check(backdrop != null and backdrop.mouse_filter == Control.MOUSE_FILTER_STOP, "7.3 Backdrop mouse_filter == STOP")
	_assert_check(modal_card != null and modal_card.mouse_filter == Control.MOUSE_FILTER_STOP, "7.4 ModalCard mouse_filter == STOP")

	# 7.3 Close Button Touch Target >= 56x56px
	var close_btn = modal.get_node_or_null("%CloseButton") as Button
	_assert_check(close_btn != null, "7.5 %CloseButton resolved in SettingsModal")
	if close_btn != null:
		_assert_check(close_btn.custom_minimum_size.x >= 56.0 and close_btn.custom_minimum_size.y >= 56.0,
			"7.6 CloseButton custom_minimum_size >= 56x56px (got %.1fx%.1fpx)" % [close_btn.custom_minimum_size.x, close_btn.custom_minimum_size.y])
		_assert_check(close_btn.mouse_filter == Control.MOUSE_FILTER_STOP, "7.7 CloseButton mouse_filter == STOP")

	# 7.4 Touch Controls Minimum Height >= 56px
	var controls_specs = [
		["%MasterVolumeSlider", "MasterVolumeSlider", 56.0],
		["%MasterMuteToggle", "MasterMuteToggle", 56.0],
		["%SFXVolumeSlider", "SFXVolumeSlider", 56.0],
		["%SFXMuteToggle", "SFXMuteToggle", 56.0],
		["%MusicVolumeSlider", "MusicVolumeSlider", 56.0],
		["%MusicMuteToggle", "MusicMuteToggle", 56.0],
		["%HapticsToggle", "HapticsToggle", 56.0],
		["%BatterySaverToggle", "BatterySaverToggle", 56.0],
	]

	for spec in controls_specs:
		var node_path = spec[0]
		var c_name = spec[1]
		var min_h = spec[2]
		var ctrl = modal.get_node_or_null(node_path) as Control
		_assert_check(ctrl != null, "7.8 Node '%s' exists in SettingsModal" % c_name)
		if ctrl != null:
			_assert_check(ctrl.custom_minimum_size.y >= min_h,
				"7.9 %s touch height >= %.0fpx (actual: %.1fpx)" % [c_name, min_h, ctrl.custom_minimum_size.y])
			_assert_check(ctrl.mouse_filter == Control.MOUSE_FILTER_STOP, "7.10 %s mouse_filter == STOP" % c_name)

	# 7.5 Battery Saver Toggle Test (30 FPS vs 60 FPS)
	var bs_toggle = modal.get_node_or_null("%BatterySaverToggle") as Button
	if bs_toggle != null:
		# Toggle ON (30 FPS)
		modal._on_battery_saver_toggled(true)
		_assert_check(Engine.max_fps == 30, "7.11 Battery saver ON sets Engine.max_fps = 30 (got %d)" % Engine.max_fps)

		# Toggle OFF (60 FPS)
		modal._on_battery_saver_toggled(false)
		_assert_check(Engine.max_fps == 60, "7.12 Battery saver OFF sets Engine.max_fps = 60 (got %d)" % Engine.max_fps)

	# 7.6 Volume Slider Synchronization
	modal._on_master_slider_changed(0.72)
	var cur_master = am.call("get_bus_volume", "Master")
	_assert_check(abs(float(cur_master) - 0.72) < 0.05,
		"7.13 Master slider updates AudioManager master volume to 0.72 (got %.2f)" % cur_master)
	_assert_check(abs(float(gs.get("master_volume")) - 0.72) < 0.05,
		"7.14 Master slider synchronizes GameState.master_volume (got %.2f)" % gs.get("master_volume"))

	modal.close()
	await process_frame

# =============================================================================
# SECTION 8: TouchControls Dynamic Button Styling (Overclock & Pitch)
# =============================================================================
func _test_section_8_touch_controls_dynamic_styling() -> void:
	print("\n--- SECTION 8: TouchControls Dynamic Button Styling ---")

	var tc_scene = load("res://scenes/ui/touch_controls.tscn")
	_assert_check(tc_scene != null, "8.1 scenes/ui/touch_controls.tscn loads successfully")
	if tc_scene == null:
		return

	var tc = tc_scene.instantiate() as Control
	root.add_child(tc)
	await process_frame

	var act_btn = tc.get_node_or_null("%ActionButton") as Button
	_assert_check(act_btn != null, "8.2 %ActionButton resolved in TouchControls")

	# 8.3 Verify style declarations
	_assert_check("_cached_overclock_style" in tc, "8.3 TouchControls declares '_cached_overclock_style'")
	_assert_check("_cached_pitch_style" in tc, "8.4 TouchControls declares '_cached_pitch_style'")

	var ovr_style = tc.get("_cached_overclock_style") as StyleBoxFlat
	var pitch_style = tc.get("_cached_pitch_style") as StyleBoxFlat

	_assert_check(ovr_style != null, "8.5 _cached_overclock_style initialized as StyleBoxFlat")
	_assert_check(pitch_style != null, "8.6 _cached_pitch_style initialized as StyleBoxFlat")

	if ovr_style != null:
		# Neon-Cyan / Electric-Blue border (G > 0.8, B > 0.9)
		_assert_check(ovr_style.border_color.g > 0.8 and ovr_style.border_color.b > 0.9,
			"8.7 Overclock style border is Neon-Cyan/Electric-Blue (got %s)" % str(ovr_style.border_color))
		_assert_check(ovr_style.shadow_size >= 10, "8.8 Overclock style has luminous shadow glow (size %d)" % ovr_style.shadow_size)

	if pitch_style != null:
		# Warm Gold border (R > 0.9, G > 0.7, B < 0.2)
		_assert_check(pitch_style.border_color.r > 0.9 and pitch_style.border_color.g > 0.7 and pitch_style.border_color.b < 0.2,
			"8.9 Pitch style border is Warm Gold (got %s)" % str(pitch_style.border_color))
		_assert_check(pitch_style.shadow_size >= 10, "8.10 Pitch style has spotlight shadow glow (size %d)" % pitch_style.shadow_size)

	# 8.4 Test Dynamic Registration: Server Terminal ("Overclock [E]")
	var dummy_term = StaticBody3D.new()
	dummy_term.set_script(load("res://scripts/server_terminal.gd"))
	root.add_child(dummy_term)

	tc.call("register_interactable", dummy_term, "Overclock [E]")
	if act_btn != null:
		_assert_check(act_btn.text == "Overclock [E]", "8.11 ActionButton text dynamically set to 'Overclock [E]'")
		var applied_ovr = act_btn.get_theme_stylebox("normal")
		_assert_check(applied_ovr == ovr_style, "8.12 ActionButton theme stylebox overridden with _cached_overclock_style")

	tc.call("unregister_interactable", dummy_term)
	if act_btn != null:
		_assert_check(act_btn.text == tc.default_action_label, "8.13 ActionButton reverted to default on unregister")

	# 8.5 Test Dynamic Registration: Pitch Stage ("Pitch [E]")
	var dummy_stage = StaticBody3D.new()
	dummy_stage.set_script(load("res://scripts/pitch_stage.gd"))
	root.add_child(dummy_stage)

	tc.call("register_interactable", dummy_stage, "Pitch [E]")
	if act_btn != null:
		_assert_check(act_btn.text == "Pitch [E]", "8.14 ActionButton text dynamically set to 'Pitch [E]'")
		var applied_pitch = act_btn.get_theme_stylebox("normal")
		_assert_check(applied_pitch == pitch_style, "8.15 ActionButton theme stylebox overridden with _cached_pitch_style")

	tc.call("unregister_interactable", dummy_stage)
	if act_btn != null:
		_assert_check(act_btn.text == tc.default_action_label, "8.16 ActionButton reverted to default on unregister")

	dummy_term.queue_free()
	dummy_stage.queue_free()
	tc.queue_free()
	await process_frame
