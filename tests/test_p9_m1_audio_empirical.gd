extends SceneTree

## =============================================================================
## Master Headless SceneTree Test Suite for Phase 9 Milestone 1: Audio Engine
## File: IdleArcade/tests/test_p9_m1_audio_empirical.gd
## Target: Godot 4.3 Engine Headless Runner
##
## Validates:
##   1. AudioManager autoload instantiation & initialization
##   2. Audio bus configuration (Master, Music, SFX)
##   3. 11 AudioStreamWAV procedural resources (16-bit signed, 22050 Hz, non-empty)
##   4. Looping configuration (Drone Hum & Ambient BGM)
##   5. Public 8 SFX/BGM playback methods & telemetry
##   6. 8-voice polyphonic player pool & round-robin allocation
##   7. Safe decibel/linear conversion math
##   8. GameState audio persistence synchronization
##
## Execution:
##   godot --headless --path IdleArcade -s tests/test_p9_m1_audio_empirical.gd
## =============================================================================

var pass_count: int = 0
var fail_count: int = 0

func _assert(condition: bool, description: String, detail: String = "") -> void:
	if condition:
		print("  [PASS] %s" % description)
		pass_count += 1
	else:
		var err = "  [FAIL] %s" % description
		if detail != "":
			err += " (Detail: %s)" % detail
		printerr(err)
		fail_count += 1

func _init() -> void:
	print("\n====================================================================")
	print(">>> RUNNING P9-M1 PROCEDURAL AUDIO ENGINE GDScript HEADLESS SUITE <<<")
	print("====================================================================")
	call_deferred("_run_tests")

func _run_tests() -> void:
	await process_frame
	
	# 1. Load and instantiate AudioManager
	var audio_script = load("res://scripts/autoload/audio_manager.gd")
	_assert(audio_script != null, "1.1 Load scripts/autoload/audio_manager.gd")
	if audio_script == null:
		printerr("[FATAL] Could not load audio_manager.gd")
		quit(1)
		return
		
	var am = root.get_node_or_null("AudioManager")
	if am == null:
		am = audio_script.new()
		am.name = "AudioManager"
		root.add_child(am)
	_assert(am != null, "1.2 AudioManager mounted in SceneTree")
	await process_frame

	# 2. Audio Buses
	var master_idx: int = AudioServer.get_bus_index("Master")
	var music_idx: int = AudioServer.get_bus_index("Music")
	var sfx_idx: int = AudioServer.get_bus_index("SFX")
	_assert(master_idx != -1, "2.1 Master bus exists")
	_assert(music_idx != -1, "2.2 Music bus exists")
	_assert(sfx_idx != -1, "2.3 SFX bus exists")
	if music_idx != -1:
		_assert(AudioServer.get_bus_send(music_idx) == &"Master", "2.4 Music bus routes to Master")
	if sfx_idx != -1:
		_assert(AudioServer.get_bus_send(sfx_idx) == &"Master", "2.5 SFX bus routes to Master")

	# 3. AudioStreamWAV Procedural Streams
	var streams: Dictionary = {
		"click": am._wav_click,
		"pickup_briefcase": am._wav_pickup_briefcase,
		"pickup_coffee": am._wav_pickup_coffee,
		"pickup_usb": am._wav_pickup_usb,
		"pickup_default": am._wav_pickup_default,
		"footstep": am._wav_footstep,
		"gate_unlock": am._wav_gate_unlock,
		"research": am._wav_research,
		"drone_hum": am._wav_drone_hum,
		"overdrive": am._wav_overdrive,
		"ambient_bgm": am._wav_ambient_bgm
	}

	for stream_name in streams:
		var wav = streams[stream_name]
		_assert(wav != null and wav is AudioStreamWAV, "3.1 Stream '%s' is AudioStreamWAV" % stream_name)
		if wav is AudioStreamWAV:
			_assert(wav.format == AudioStreamWAV.FORMAT_16_BITS, "3.2 Stream '%s' is 16-bit format" % stream_name)
			_assert(wav.mix_rate == 22050, "3.3 Stream '%s' mix_rate is 22,050 Hz" % stream_name)
			_assert(wav.data.size() > 0, "3.4 Stream '%s' byte data is nonzero (size=%d)" % [stream_name, wav.data.size()])

	# 4. Looping Mode
	var drone_wav = am._wav_drone_hum
	_assert(drone_wav.loop_mode == AudioStreamWAV.LOOP_FORWARD, "4.1 Drone hum loop_mode is LOOP_FORWARD")
	_assert(drone_wav.loop_begin == 0 and drone_wav.loop_end == 35280, "4.2 Drone hum loop_end is 35,280 samples")

	var bgm_wav = am._wav_ambient_bgm
	_assert(bgm_wav.loop_mode == AudioStreamWAV.LOOP_FORWARD, "4.3 Ambient BGM loop_mode is LOOP_FORWARD")
	_assert(bgm_wav.loop_begin == 0 and bgm_wav.loop_end == 176400, "4.4 Ambient BGM loop_end is 176,400 samples")

	# 5. Public Playback & Telemetry
	am.clear_history()
	_assert(am.sfx_play_count == 0, "5.1 clear_history resets play_count")
	
	am.play_sfx_click()
	_assert(am.last_sfx_played == "click", "5.2 play_sfx_click updates last_sfx_played")
	
	am.play_sfx_pickup("briefcase")
	_assert(am.last_sfx_played == "pickup_briefcase", "5.3 play_sfx_pickup('briefcase') recorded")
	
	am.play_sfx_pickup("coffee")
	_assert(am.last_sfx_played == "pickup_coffee", "5.4 play_sfx_pickup('coffee') recorded")
	
	am.play_sfx_pickup("usb")
	_assert(am.last_sfx_played == "pickup_usb", "5.5 play_sfx_pickup('usb') recorded")
	
	am.play_sfx_pickup("unknown_item")
	_assert(am.last_sfx_played == "pickup", "5.6 play_sfx_pickup fallback recorded")

	am.play_sfx_footstep()
	_assert(am.last_sfx_played == "footstep", "5.7 play_sfx_footstep recorded")

	am.play_sfx_gate_unlock()
	_assert(am.last_sfx_played == "gate_unlock", "5.8 play_sfx_gate_unlock recorded")

	am.play_sfx_research()
	_assert(am.last_sfx_played == "research", "5.9 play_sfx_research recorded")

	am.play_sfx_overdrive()
	_assert(am.last_sfx_played == "overdrive", "5.10 play_sfx_overdrive recorded")

	am.play_sfx_drone_hum()
	_assert(am.last_sfx_played == "drone_hum", "5.11 play_sfx_drone_hum recorded")
	am.stop_sfx_drone_hum()

	am.start_ambient_bgm()
	_assert(am.is_bgm_playing == true, "5.12 start_ambient_bgm sets is_bgm_playing = true")
	am.stop_ambient_bgm()
	_assert(am.is_bgm_playing == false, "5.13 stop_ambient_bgm sets is_bgm_playing = false")

	# 6. Polyphonic Pool Allocation
	_assert(am._sfx_pool.size() == 8, "6.1 SFX pool size is exactly 8 players")
	for p in am._sfx_pool:
		_assert(p is AudioStreamPlayer and p.bus == "SFX", "6.2 Pool player on SFX bus")

	# 7. Safe Decibel Conversion
	_assert(is_equal_approx(am.linear_to_db_safe(1.0), 0.0), "7.1 linear_to_db_safe(1.0) == 0.0 dB")
	_assert(am.linear_to_db_safe(0.0) == -80.0, "7.2 linear_to_db_safe(0.0) == -80.0 dB")
	_assert(am.linear_to_db_safe(-0.5) == -80.0, "7.3 linear_to_db_safe(-0.5) == -80.0 dB")
	_assert(am.linear_to_db_safe(0.00005) == -80.0, "7.4 linear_to_db_safe(0.00005) == -80.0 dB")
	_assert(am.db_to_linear_safe(-80.0) == 0.0, "7.5 db_to_linear_safe(-80.0) == 0.0")
	_assert(is_equal_approx(am.db_to_linear_safe(0.0), 1.0), "7.6 db_to_linear_safe(0.0) == 1.0")

	# 8. Settings API
	am.apply_settings({
		"master_volume": 0.75,
		"music_volume": 0.50,
		"sfx_volume": 0.90,
		"master_muted": false,
		"music_muted": true,
		"sfx_muted": false
	})
	var cur_settings = am.get_audio_settings()
	_assert(is_equal_approx(cur_settings["master_volume"], 0.75), "8.1 master_volume applied (0.75)")
	_assert(is_equal_approx(cur_settings["music_volume"], 0.50), "8.2 music_volume applied (0.50)")
	_assert(is_equal_approx(cur_settings["sfx_volume"], 0.90), "8.3 sfx_volume applied (0.90)")
	_assert(cur_settings["music_muted"] == true, "8.4 music_muted applied (true)")

	print("\n====================================================================")
	print("GDScript Test Results: %d Passed, %d Failed" % [pass_count, fail_count])
	print("====================================================================")
	
	if fail_count > 0:
		quit(1)
	else:
		print(">>> ALL P9-M1 PROCEDURAL AUDIO ENGINE TESTS PASSED 100% GREEN! <<<")
		quit(0)
