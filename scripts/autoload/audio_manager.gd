extends Node

## AudioManager Autoload Singleton (res://scripts/autoload/audio_manager.gd)
## Procedural Audio Engine & SFX Synthesizer for IdleArcade (Godot 4.3).
## Features 100% algorithmic 16-bit PCM wave synthesis into AudioStreamWAV resources at 22,050 Hz.
## Zero external audio asset dependencies, zero buffer underruns, and deterministic headless operation.

# ------------------------------------------------------------------------------
# Signals
# ------------------------------------------------------------------------------
signal sfx_played(sfx_name: String)
signal bgm_started()
signal bgm_stopped()
signal bus_volume_changed(bus_name: String, volume_linear: float, volume_db: float)
signal bus_mute_changed(bus_name: String, is_muted: bool)

# ------------------------------------------------------------------------------
# Constants
# ------------------------------------------------------------------------------
const SAMPLE_RATE: int = 22050
const SFX_POOL_SIZE: int = 8
const FOOTSTEP_MIN_INTERVAL_MS: int = 180

# ------------------------------------------------------------------------------
# Telemetry & Test State
# ------------------------------------------------------------------------------
var last_sfx_played: String = ""
var sfx_play_count: int = 0
var sfx_history: Array[String] = []
var sfx_events: Array[Dictionary] = []
var is_bgm_playing: bool = false

# Telemetry configuration
@export var max_history_size: int = 50

# Internal Audio Players
var _sfx_pool: Array[AudioStreamPlayer] = []
var _pool_cursor: int = 0
var _bgm_player: AudioStreamPlayer = null
var _drone_player: AudioStreamPlayer = null

# Cached Pre-Synthesized AudioStreamWAV Resources
var _wav_click: AudioStreamWAV = null
var _wav_pickup_briefcase: AudioStreamWAV = null
var _wav_pickup_coffee: AudioStreamWAV = null
var _wav_pickup_usb: AudioStreamWAV = null
var _wav_pickup_default: AudioStreamWAV = null
var _wav_footstep: AudioStreamWAV = null
var _wav_gate_unlock: AudioStreamWAV = null
var _wav_research: AudioStreamWAV = null
var _wav_drone_hum: AudioStreamWAV = null
var _wav_overdrive: AudioStreamWAV = null
var _wav_ambient_bgm: AudioStreamWAV = null
var _wav_confetti: AudioStreamWAV = null
var _wav_bell: AudioStreamWAV = null

# Footstep throttle tracking
var _last_footstep_msec: int = -10000

# ------------------------------------------------------------------------------
# Lifecycle
# ------------------------------------------------------------------------------
func _ready() -> void:
	_setup_audio_buses()
	_init_player_pool()
	_prebake_sound_streams()
	_bind_game_signals()
	print("[AudioManager] Procedural Audio Engine initialized successfully (22,050 Hz PCM).")

# ------------------------------------------------------------------------------
# Audio Bus Configuration & Volume Control
# ------------------------------------------------------------------------------

## Ensures Master, Music, and SFX buses exist and are properly routed.
func _setup_audio_buses() -> void:
	# Check or create Music bus
	var music_idx: int = AudioServer.get_bus_index("Music")
	if music_idx == -1:
		AudioServer.add_bus()
		music_idx = AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(music_idx, "Music")
		AudioServer.set_bus_send(music_idx, "Master")
	
	# Check or create SFX bus
	var sfx_idx: int = AudioServer.get_bus_index("SFX")
	if sfx_idx == -1:
		AudioServer.add_bus()
		sfx_idx = AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(sfx_idx, "SFX")
		AudioServer.set_bus_send(sfx_idx, "Master")

## Safe conversion from linear amplitude [0.0, 1.0] to decibels.
## Clamps linear <= 0.0001 to -80.0 dB to prevent -inf errors.
func linear_to_db_safe(linear_val: float) -> float:
	if linear_val <= 0.0001:
		return -80.0
	var clamped: float = clampf(linear_val, 0.0001, 1.0)
	return clampf(linear_to_db(clamped), -80.0, 6.0)

## Safe conversion from decibels to linear amplitude [0.0, 1.0].
func db_to_linear_safe(db_val: float) -> float:
	if db_val <= -79.9:
		return 0.0
	return clampf(db_to_linear(db_val), 0.0, 1.0)

## Sets volume for a specific audio bus using linear value [0.0, 1.0].
func set_bus_volume(bus_name: String, volume_linear: float) -> void:
	var idx: int = AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return
	var vol: float = clampf(volume_linear, 0.0, 1.0)
	var db: float = linear_to_db_safe(vol)
	AudioServer.set_bus_volume_db(idx, db)
	# If volume is practically 0, optionally mute or let -80 dB handle it
	bus_volume_changed.emit(bus_name, vol, db)

## Gets linear volume [0.0, 1.0] for a specific audio bus.
func get_bus_volume(bus_name: String) -> float:
	var idx: int = AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return 1.0
	var db: float = AudioServer.get_bus_volume_db(idx)
	return db_to_linear_safe(db)

## Sets mute state for a specific audio bus.
func set_bus_mute(bus_name: String, muted: bool) -> void:
	var idx: int = AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return
	AudioServer.set_bus_mute(idx, muted)
	bus_mute_changed.emit(bus_name, muted)

## Returns true if the specific bus is currently muted.
func is_bus_muted(bus_name: String) -> bool:
	var idx: int = AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return false
	return AudioServer.is_bus_mute(idx)

# Bus Specific Helper Methods
func set_master_volume(vol: float) -> void:
	set_bus_volume("Master", vol)

func get_master_volume() -> float:
	return get_bus_volume("Master")

func set_music_volume(vol: float) -> void:
	set_bus_volume("Music", vol)

func get_music_volume() -> float:
	return get_bus_volume("Music")

func set_sfx_volume(vol: float) -> void:
	set_bus_volume("SFX", vol)

func get_sfx_volume() -> float:
	return get_bus_volume("SFX")

func set_master_mute(muted: bool) -> void:
	set_bus_mute("Master", muted)

func is_master_muted() -> bool:
	return is_bus_muted("Master")

func set_music_mute(muted: bool) -> void:
	set_bus_mute("Music", muted)

func is_music_muted() -> bool:
	return is_bus_muted("Music")

func set_sfx_mute(muted: bool) -> void:
	set_bus_mute("SFX", muted)

func is_sfx_muted() -> bool:
	return is_bus_muted("SFX")

## Applies a settings dictionary directly to buses.
func apply_settings(settings: Dictionary) -> void:
	if settings.has("master_volume"):
		set_master_volume(float(settings["master_volume"]))
	if settings.has("music_volume"):
		set_music_volume(float(settings["music_volume"]))
	if settings.has("sfx_volume"):
		set_sfx_volume(float(settings["sfx_volume"]))
	if settings.has("master_muted"):
		set_master_mute(bool(settings["master_muted"]))
	if settings.has("music_muted"):
		set_music_mute(bool(settings["music_muted"]))
	if settings.has("sfx_muted"):
		set_sfx_mute(bool(settings["sfx_muted"]))

## Returns current audio settings as a Dictionary.
func get_audio_settings() -> Dictionary:
	return {
		"master_volume": get_master_volume(),
		"music_volume": get_music_volume(),
		"sfx_volume": get_sfx_volume(),
		"master_muted": is_master_muted(),
		"music_muted": is_music_muted(),
		"sfx_muted": is_sfx_muted()
	}

# ------------------------------------------------------------------------------
# Audio Player Pool & Stream Playback
# ------------------------------------------------------------------------------
func _init_player_pool() -> void:
	_sfx_pool.clear()
	for i in range(SFX_POOL_SIZE):
		var p = AudioStreamPlayer.new()
		p.name = "SFXPlayer_%d" % i
		p.bus = "SFX"
		add_child(p)
		_sfx_pool.append(p)
		
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.name = "BGMPlayer"
	_bgm_player.bus = "Music"
	add_child(_bgm_player)
	
	_drone_player = AudioStreamPlayer.new()
	_drone_player.name = "DronePlayer"
	_drone_player.bus = "SFX"
	add_child(_drone_player)

func _play_sfx_stream(stream: AudioStreamWAV, sfx_id: String) -> void:
	_record_telemetry(sfx_id)
	if stream == null or _sfx_pool.is_empty():
		return
		
	# Find idle player or pick round-robin
	var target_player: AudioStreamPlayer = null
	for p in _sfx_pool:
		if not p.playing:
			target_player = p
			break
			
	if target_player == null:
		target_player = _sfx_pool[_pool_cursor % _sfx_pool.size()]
		_pool_cursor += 1
		
	target_player.stream = stream
	target_player.play()

func _record_telemetry(sfx_id: String) -> void:
	last_sfx_played = sfx_id
	sfx_play_count += 1
	sfx_history.append(sfx_id)
	if sfx_history.size() > max_history_size:
		sfx_history.pop_front()
		
	sfx_events.append({
		"name": sfx_id,
		"timestamp": Time.get_ticks_msec()
	})
	if sfx_events.size() > max_history_size:
		sfx_events.pop_front()
		
	sfx_played.emit(sfx_id)

func clear_history() -> void:
	last_sfx_played = ""
	sfx_play_count = 0
	sfx_history.clear()
	sfx_events.clear()

func get_sfx_history() -> Array:
	return sfx_history.duplicate()

func get_sfx_events() -> Array[Dictionary]:
	return sfx_events.duplicate()

# ------------------------------------------------------------------------------
# Public SFX & BGM API (8 Required Functions)
# ------------------------------------------------------------------------------

## 1. Crisp UI click / confirmation.
func play_sfx_click() -> void:
	_play_sfx_stream(_wav_click, "click")

## 2. Harmonic chime for collectible item pickups.
func play_sfx_pickup(item_type: String = "") -> void:
	var stream: AudioStreamWAV = _wav_pickup_default
	var key: String = "pickup"
	if item_type == "briefcase":
		stream = _wav_pickup_briefcase
		key = "pickup_briefcase"
	elif item_type == "coffee":
		stream = _wav_pickup_coffee
		key = "pickup_coffee"
	elif item_type in ["usb", "usb_drive"]:
		stream = _wav_pickup_usb
		key = "pickup_usb"
	else:
		stream = _wav_pickup_default
		key = "pickup"
	_play_sfx_stream(stream, key)

## 3. Soft dust footstep with rate limiting.
func play_sfx_footstep() -> void:
	var now: int = Time.get_ticks_msec()
	if now - _last_footstep_msec < FOOTSTEP_MIN_INTERVAL_MS:
		return
	_last_footstep_msec = now
	_play_sfx_stream(_wav_footstep, "footstep")

## 4. Sci-fi gate unlock power chord.
func play_sfx_gate_unlock() -> void:
	_play_sfx_stream(_wav_gate_unlock, "gate_unlock")

## 5. Uplifting 4-note research milestone arpeggio.
func play_sfx_research() -> void:
	_play_sfx_stream(_wav_research, "research")

## 6. Subtle drone hover oscillator.
func play_sfx_drone_hum() -> void:
	_record_telemetry("drone_hum")
	if _drone_player != null and _wav_drone_hum != null:
		_drone_player.stream = _wav_drone_hum
		if not _drone_player.playing:
			_drone_player.play()

## Stops drone hover sound if playing.
func stop_sfx_drone_hum() -> void:
	if _drone_player != null and _drone_player.playing:
		_drone_player.stop()

## 7. Fast beat / siren hype for overdrive/frenzy mode.
func play_sfx_overdrive() -> void:
	_play_sfx_stream(_wav_overdrive, "overdrive")

## 8. Lo-Fi ambient synth chord progression BGM.
func start_ambient_bgm() -> void:
	if _bgm_player == null:
		return
	if _wav_ambient_bgm != null:
		_bgm_player.stream = _wav_ambient_bgm
	if not _bgm_player.playing:
		_bgm_player.play()
	is_bgm_playing = true
	bgm_started.emit()

## Stops ambient background music.
func stop_ambient_bgm() -> void:
	if _bgm_player != null and _bgm_player.playing:
		_bgm_player.stop()
	is_bgm_playing = false
	bgm_stopped.emit()

## 9. Sparkling celebratory confetti burst chime / arpeggio.
func play_sfx_confetti() -> void:
	_play_sfx_stream(_wav_confetti, "confetti")

## 10. Resonant ceremonial IPO bell chime.
func play_sfx_bell() -> void:
	_play_sfx_stream(_wav_bell, "bell")

# ------------------------------------------------------------------------------
# Decoupled Signal Bindings
# ------------------------------------------------------------------------------
func _bind_game_signals() -> void:
	var gs = get_node_or_null("/root/GameState")
	if gs != null:
		# Initial settings sync if GameState has audio variables
		if "master_volume" in gs:
			apply_settings({
				"master_volume": gs.master_volume,
				"music_volume": gs.music_volume,
				"sfx_volume": gs.sfx_volume,
				"master_muted": gs.master_muted,
				"music_muted": gs.music_muted,
				"sfx_muted": gs.sfx_muted
			})
			
		# Connect settings changed signal if present
		if gs.has_signal("audio_settings_changed") and not gs.audio_settings_changed.is_connected(_on_game_state_audio_changed):
			gs.audio_settings_changed.connect(_on_game_state_audio_changed)
			
		# Connect upgrade purchased to UI click SFX
		if gs.has_signal("upgrade_purchased") and not gs.upgrade_purchased.is_connected(_on_game_state_upgrade_purchased):
			gs.upgrade_purchased.connect(_on_game_state_upgrade_purchased)
			
		# Connect level up signal to confetti celebration SFX
		if gs.has_signal("level_up") and not gs.level_up.is_connected(_on_game_state_level_up):
			gs.level_up.connect(_on_game_state_level_up)
			
		# Connect campus quest completion to celebratory SFX
		if gs.has_signal("campus_quest_completed") and not gs.campus_quest_completed.is_connected(_on_game_state_quest_completed):
			gs.campus_quest_completed.connect(_on_game_state_quest_completed)

func _on_game_state_level_up(_new_level: int) -> void:
	play_sfx_confetti()

func _on_game_state_quest_completed(_quest_id: String, _reward_energy: float, _reward_bonus: int) -> void:
	play_sfx_confetti()

func _on_game_state_upgrade_purchased(_upgrade_id: String, _new_level: int, _current_cost: float) -> void:
	play_sfx_click()

func _on_game_state_audio_changed(setting_name: String, value: Variant) -> void:
	match setting_name:
		"master_volume":
			set_master_volume(float(value))
		"music_volume":
			set_music_volume(float(value))
		"sfx_volume":
			set_sfx_volume(float(value))
		"master_muted":
			set_master_mute(bool(value))
		"music_muted":
			set_music_mute(bool(value))
		"sfx_muted":
			set_sfx_mute(bool(value))

# ------------------------------------------------------------------------------
# Procedural Wave Synthesis Engine (16-bit Signed PCM at 22,050 Hz)
# ------------------------------------------------------------------------------

func _prebake_sound_streams() -> void:
	_wav_click = _synth_click()
	_wav_pickup_briefcase = _synth_pickup_briefcase()
	_wav_pickup_coffee = _synth_pickup_coffee()
	_wav_pickup_usb = _synth_pickup_usb()
	_wav_pickup_default = _synth_pickup_default()
	_wav_footstep = _synth_footstep()
	_wav_gate_unlock = _synth_gate_unlock()
	_wav_research = _synth_research()
	_wav_drone_hum = _synth_drone_hum()
	_wav_overdrive = _synth_overdrive()
	_wav_ambient_bgm = _synth_ambient_bgm()
	_wav_confetti = _synth_confetti()
	_wav_bell = _synth_bell()

## Encodes normalized float samples [-1.0, 1.0] into an AudioStreamWAV resource.
func _create_wav_stream(samples: PackedFloat32Array, sample_rate: int = SAMPLE_RATE, loop: bool = false) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	
	var num_samples: int = samples.size()
	var byte_buffer := PackedByteArray()
	byte_buffer.resize(num_samples * 2)
	
	for i in range(num_samples):
		var s_clamped: float = clampf(samples[i], -1.0, 1.0)
		var s_int16: int = clampi(int(s_clamped * 32767.0), -32768, 32767)
		byte_buffer.encode_s16(i * 2, s_int16)
		
	wav.data = byte_buffer
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = num_samples
	else:
		wav.loop_mode = AudioStreamWAV.LOOP_DISABLED
		
	return wav

# 1. UI Click: Exponential pitch drop 1400 Hz -> 500 Hz (0.05s)
func _synth_click() -> AudioStreamWAV:
	var count: int = int(SAMPLE_RATE * 0.05)
	var samples := PackedFloat32Array()
	samples.resize(count)
	for i in range(count):
		var t: float = float(i) / float(SAMPLE_RATE)
		# Phase integration: integral(2*PI*1400*exp(-40*t)) dt = 70*PI*(1 - exp(-40*t))
		var phase: float = 70.0 * PI * (1.0 - exp(-40.0 * t))
		var env: float = exp(-t * 70.0)
		var wave: float = (sin(phase) + 0.3 * sin(2.0 * phase)) * env
		samples[i] = clampf(wave, -1.0, 1.0)
	return _create_wav_stream(samples, SAMPLE_RATE, false)

# 2a. Pickup Briefcase: C5-E5-G5 Major Triad Bell Chime (0.35s)
func _synth_pickup_briefcase() -> AudioStreamWAV:
	var count: int = int(SAMPLE_RATE * 0.35)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var f1: float = 523.25 # C5
	var f2: float = 659.25 # E5
	var f3: float = 783.99 # G5
	for i in range(count):
		var t: float = float(i) / float(SAMPLE_RATE)
		var env: float = exp(-t * 9.0)
		var wave: float = (sin(2.0 * PI * f1 * t) + sin(2.0 * PI * f2 * t) + sin(2.0 * PI * f3 * t) + 0.25 * sin(4.0 * PI * f3 * t)) / 3.25
		samples[i] = clampf(wave * env * 0.85, -1.0, 1.0)
	return _create_wav_stream(samples, SAMPLE_RATE, false)

# 2b. Pickup Coffee: Ascending Two-Tone E5 -> B5 (0.25s)
func _synth_pickup_coffee() -> AudioStreamWAV:
	var count: int = int(SAMPLE_RATE * 0.25)
	var samples := PackedFloat32Array()
	samples.resize(count)
	for i in range(count):
		var t: float = float(i) / float(SAMPLE_RATE)
		var f: float = 659.25 if t < 0.10 else 987.77 # E5 -> B5
		var t_rel: float = t if t < 0.10 else (t - 0.10)
		var attack: float = 1.0 - exp(-t_rel * 400.0)
		var env: float = attack * exp(-t_rel * 12.0)
		var wave: float = (sin(2.0 * PI * f * t) + 0.3 * sin(4.0 * PI * f * t)) / 1.3
		samples[i] = clampf(wave * env * 0.85, -1.0, 1.0)
	return _create_wav_stream(samples, SAMPLE_RATE, false)

# 2c. Pickup USB: Perfect Fifth D5 + A5 Sci-Fi Digital Ping (0.30s)
func _synth_pickup_usb() -> AudioStreamWAV:
	var count: int = int(SAMPLE_RATE * 0.30)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var f1: float = 587.33 # D5
	var f2: float = 880.00 # A5
	for i in range(count):
		var t: float = float(i) / float(SAMPLE_RATE)
		var env: float = exp(-t * 10.0)
		var wave: float = (sin(2.0 * PI * f1 * t) + sin(2.0 * PI * f2 * t) + 0.35 * sin(2.0 * PI * 1760.0 * t)) / 2.35
		samples[i] = clampf(wave * env * 0.85, -1.0, 1.0)
	return _create_wav_stream(samples, SAMPLE_RATE, false)

# 2d. Pickup Default: Clean Ascending Chime A5 -> E6 (0.25s)
func _synth_pickup_default() -> AudioStreamWAV:
	var count: int = int(SAMPLE_RATE * 0.25)
	var samples := PackedFloat32Array()
	samples.resize(count)
	for i in range(count):
		var t: float = float(i) / float(SAMPLE_RATE)
		var f: float = 880.0 + 438.5 * (t / 0.25)
		var env: float = exp(-t * 10.0)
		var wave: float = (sin(2.0 * PI * f * t) + 0.2 * sin(4.0 * PI * f * t)) / 1.2
		samples[i] = clampf(wave * env * 0.85, -1.0, 1.0)
	return _create_wav_stream(samples, SAMPLE_RATE, false)

# 3. Soft Dust Footstep: 95 Hz -> 55 Hz thump + filtered noise (0.07s)
func _synth_footstep() -> AudioStreamWAV:
	var count: int = int(SAMPLE_RATE * 0.07)
	var samples := PackedFloat32Array()
	samples.resize(count)
	for i in range(count):
		var t: float = float(i) / float(SAMPLE_RATE)
		var phase: float = 2.0 * PI * (95.0 * t - 20.0 * t * t / 0.07)
		var thump: float = sin(phase) * exp(-t * 45.0)
		# Deterministic pseudo-noise
		var noise: float = sin(t * 138542.17) * exp(-t * 60.0)
		var wave: float = 0.75 * thump + 0.25 * noise
		samples[i] = clampf(wave * 0.70, -1.0, 1.0)
	return _create_wav_stream(samples, SAMPLE_RATE, false)

# 4. Sci-Fi Gate Unlock: Resonant Power Chord F3 + C4 + F4 riser (0.90s)
func _synth_gate_unlock() -> AudioStreamWAV:
	var count: int = int(SAMPLE_RATE * 0.90)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var f_root: float = 174.61 # F3
	var f_fifth: float = 261.63 # C4
	var f_octave: float = 349.23 # F4
	for i in range(count):
		var t: float = float(i) / float(SAMPLE_RATE)
		var env: float = 0.0
		if t < 0.05:
			env = t / 0.05
		elif t < 0.25:
			env = 1.0
		else:
			env = exp(-(t - 0.25) * 5.0)
		var riser: float = 1.0 + (0.08 * (t / 0.25) if t < 0.25 else 0.08)
		var s: float = (sin(2.0 * PI * f_root * t) + 0.8 * sin(2.0 * PI * f_fifth * t) + 0.6 * sin(2.0 * PI * (f_octave * riser) * t)) / 2.4
		var saturated: float = tanh(1.5 * s)
		samples[i] = clampf(saturated * env * 0.85, -1.0, 1.0)
	return _create_wav_stream(samples, SAMPLE_RATE, false)

# 5. Festive Research Arpeggio: C5 -> E5 -> G5 -> C6 Fanfare (0.80s)
func _synth_research() -> AudioStreamWAV:
	var count: int = int(SAMPLE_RATE * 0.80)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var notes: Array[float] = [523.25, 659.25, 783.99, 1046.50]
	var times: Array[float] = [0.00, 0.12, 0.24, 0.36]
	for i in range(count):
		var t: float = float(i) / float(SAMPLE_RATE)
		var sum: float = 0.0
		for n_idx in range(4):
			var t_start: float = times[n_idx]
			if t >= t_start:
				var dt: float = t - t_start
				var f: float = notes[n_idx]
				var decay: float = 5.0 if n_idx < 3 else 3.0
				var env: float = (1.0 - exp(-dt * 200.0)) * exp(-dt * decay)
				sum += (sin(2.0 * PI * f * dt) + 0.25 * sin(6.0 * PI * f * dt)) * env
		samples[i] = clampf((sum / 2.0) * 0.85, -1.0, 1.0)
	return _create_wav_stream(samples, SAMPLE_RATE, false)

# 6. Drone Hover Oscillator: Steady 125 Hz / 250 Hz with 5.0 Hz Tremolo (1.60s seamless loop)
func _synth_drone_hum() -> AudioStreamWAV:
	var count: int = int(SAMPLE_RATE * 1.60)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var f_base: float = 125.0
	var f_blade: float = 250.0
	for i in range(count):
		var t: float = float(i) / float(SAMPLE_RATE)
		# 5.0 Hz tremolo over 1.60s = exactly 8 full integer cycles (seamless loop)
		var tremolo: float = 0.85 + 0.15 * sin(2.0 * PI * 5.0 * t)
		var wave: float = (sin(2.0 * PI * f_base * t) + 0.5 * sin(2.0 * PI * f_blade * t)) / 1.5
		samples[i] = clampf(wave * tremolo * 0.55, -1.0, 1.0)
	return _create_wav_stream(samples, SAMPLE_RATE, true)

# 7. Fast Beat / Siren Hype: 735 Hz +/- 185 Hz Siren + 4 Kick Pulses (0.75s)
func _synth_overdrive() -> AudioStreamWAV:
	var count: int = int(SAMPLE_RATE * 0.75)
	var samples := PackedFloat32Array()
	samples.resize(count)
	for i in range(count):
		var t: float = float(i) / float(SAMPLE_RATE)
		# Siren sweep: f(t) = 735.0 + 185.0 * sin(2 * PI * 8.0 * t)
		var siren_phase: float = 2.0 * PI * 735.0 * t - (185.0 / 8.0) * cos(2.0 * PI * 8.0 * t)
		var siren: float = sin(siren_phase)
		# 4 kick pulses: every 0.1875s (sub-bass punch 130 Hz dropping to 40 Hz)
		var pulse_t: float = fmod(t, 0.1875)
		var kick_phase: float = 2.0 * PI * (130.0 / -20.0) * (exp(-pulse_t * 20.0) - 1.0)
		var kick: float = sin(kick_phase) * exp(-pulse_t * 25.0)
		var combined: float = 0.55 * siren + 0.45 * kick
		samples[i] = clampf(combined * 0.80, -1.0, 1.0)
	return _create_wav_stream(samples, SAMPLE_RATE, false)

# 8. Lo-Fi Ambient Synth Chord Progression: 8.0s seamless loop (Cmaj7 -> Am7 -> Dm7 -> G7)
func _synth_ambient_bgm() -> AudioStreamWAV:
	var count: int = int(SAMPLE_RATE * 8.00)
	var samples := PackedFloat32Array()
	samples.resize(count)
	
	# 4 chords, 2.0s per chord
	# Chord 1: Cmaj7 (C4 261.63, E4 329.63, G4 392.00, B4 493.88)
	# Chord 2: Am7   (A3 220.00, C4 261.63, E4 329.63, G4 392.00)
	# Chord 3: Dm7   (D4 293.66, F4 349.23, A4 440.00, C5 523.25)
	# Chord 4: G7    (G3 196.00, B3 246.94, D4 293.66, F4 349.23)
	var chord_frequencies: Array = [
		[261.63, 329.63, 392.00, 493.88],
		[220.00, 261.63, 329.63, 392.00],
		[293.66, 349.23, 440.00, 523.25],
		[196.00, 246.94, 293.66, 349.23]
	]
	
	for i in range(count):
		var t: float = float(i) / float(SAMPLE_RATE)
		var chord_idx: int = int(t / 2.0) % 4
		var next_chord_idx: int = (chord_idx + 1) % 4
		var t_in_chord: float = fmod(t, 2.0)
		
		# Current chord wave
		var current_freqs: Array = chord_frequencies[chord_idx]
		var cur_wave: float = 0.0
		for f in current_freqs:
			cur_wave += sin(2.0 * PI * f * t) + 0.2 * sin(4.0 * PI * f * t)
		cur_wave = cur_wave / 4.8
		
		# Crossfade at chord boundaries (last 0.25s of each 2s block)
		var final_wave: float = cur_wave
		if t_in_chord > 1.75:
			var cross: float = (t_in_chord - 1.75) / 0.25
			var next_freqs: Array = chord_frequencies[next_chord_idx]
			var next_wave: float = 0.0
			for f in next_freqs:
				next_wave += sin(2.0 * PI * f * t) + 0.2 * sin(4.0 * PI * f * t)
			next_wave = next_wave / 4.8
			# Smooth cosine crossfade
			var fade: float = 0.5 - 0.5 * cos(PI * cross)
			final_wave = (1.0 - fade) * cur_wave + fade * next_wave
			
		# Gentle tremolo LFO (3.5 Hz)
		var tremolo: float = 0.90 + 0.10 * sin(2.0 * PI * 3.5 * t)
		samples[i] = clampf(final_wave * tremolo * 0.45, -1.0, 1.0)
		
	return _create_wav_stream(samples, SAMPLE_RATE, true)

# 9. Festive Confetti Chime: Sparkling upward arpeggio + pop transient (0.32s)
func _synth_confetti() -> AudioStreamWAV:
	var count: int = int(SAMPLE_RATE * 0.32)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var notes: Array[float] = [783.99, 987.77, 1174.66, 1567.98]
	var delays: Array[float] = [0.00, 0.04, 0.08, 0.12]
	for i in range(count):
		var t: float = float(i) / float(SAMPLE_RATE)
		var pop: float = sin(2.0 * PI * 1800.0 * (1.0 - exp(-t * 120.0)) * 0.02) * exp(-t * 90.0)
		var sparkle_sum: float = 0.0
		for n in range(4):
			var note_t: float = t - delays[n]
			if note_t >= 0.0:
				var f: float = notes[n]
				var env: float = (1.0 - exp(-note_t * 300.0)) * exp(-note_t * 9.0)
				var tone: float = sin(2.0 * PI * f * note_t) + 0.35 * sin(4.0 * PI * f * note_t)
				sparkle_sum += tone * env
		var combined: float = 0.35 * pop + 0.65 * (sparkle_sum / 2.0)
		samples[i] = clampf(combined * 0.85, -1.0, 1.0)
	return _create_wav_stream(samples, SAMPLE_RATE, false)

# 10. Resonant Ceremonial IPO Bell Chime (1.25s)
# Combines D5 (587.33 Hz), A5 (880.00 Hz), D6 (1174.66 Hz), and transient click (2349 Hz)
func _synth_bell() -> AudioStreamWAV:
	var count: int = int(SAMPLE_RATE * 1.25)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var f_d5: float = 587.33
	var f_a5: float = 880.00
	var f_d6: float = 1174.66
	var f_click: float = 2349.00
	for i in range(count):
		var t: float = float(i) / float(SAMPLE_RATE)
		# Fast strike click transient
		var click: float = sin(2.0 * PI * f_click * t) * exp(-t * 80.0)
		# Sustained resonant bell harmonics with exponential decay over 1.25s
		var tone_d5: float = sin(2.0 * PI * f_d5 * t) * exp(-t * 3.8)
		var tone_a5: float = sin(2.0 * PI * f_a5 * t) * exp(-t * 4.2)
		var tone_d6: float = sin(2.0 * PI * f_d6 * t) * exp(-t * 4.8)
		# Rapid initial attack envelope to prevent clicks
		var attack: float = 1.0 - exp(-t * 350.0)
		var chord: float = (tone_d5 + 0.70 * tone_a5 + 0.50 * tone_d6) / 2.20
		var combined: float = 0.20 * click + 0.80 * chord * attack
		samples[i] = clampf(combined * 0.90, -1.0, 1.0)
	return _create_wav_stream(samples, SAMPLE_RATE, false)


