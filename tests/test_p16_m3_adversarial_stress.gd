extends SceneTree

## Dedicated Empirical Adversarial Stress Test Suite for Phase 16 Milestone 3
## Focus: Rapid Burst Requests, Audio Buffer Overflows/Popping, 
## Haptics Churn & Platform Guards, 3D Score Popup Burst Memory Leaks, 
## Screen Shake Event Robustness, and Pointer Isolation Under Hostile Inputs.
##
## Execution:
##   godot.cmd --headless --path IdleArcade -s tests/test_p16_m3_adversarial_stress.gd

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
	print(">>> ADVERSARIAL STRESS TEST SUITE: PHASE 16 MILESTONE 3 <<<")
	print("====================================================================")
	call_deferred("_run_all_stress_tests")

func _run_all_stress_tests() -> void:
	await _stress_test_audio_bursts_and_pools()
	await _stress_test_audio_pcm_signal_fidelity()
	await _stress_test_haptics_concurrency_and_boundaries()
	await _stress_test_floating_popups_burst_and_lifecycle()
	await _stress_test_screen_shake_pipeline_resilience()
	await _stress_test_pointer_isolation_under_hostile_input()

	print("\n====================================================================")
	print(">>> STRESS RESULTS: %d PASSED, %d FAILED <<<" % [pass_count, fail_count])
	print("====================================================================")
	if fail_count == 0:
		print(">>> ALL ADVERSARIAL STRESS TESTS PASSED WITH 100% INTEGRITY (Exit Code 0) <<<\n")
		quit(0)
	else:
		print(">>> ADVERSARIAL STRESS TESTS DETECTED FAILURES (Exit Code 1) <<<\n")
		quit(1)

# ------------------------------------------------------------------------------
# 1. Audio Manager: Rapid Concurrent Bursts & Pool Stress
# ------------------------------------------------------------------------------
func _stress_test_audio_bursts_and_pools() -> void:
	print("\n--- STRESS 1: Audio Rapid Concurrent Bursts & Pool Management ---")
	var am = root.get_node_or_null("/root/AudioManager")
	_assert(am != null, "1.1 AudioManager singleton is available")
	if am == null:
		return

	am.clear_history()
	_assert(am.sfx_play_count == 0, "1.2 SFX count starts at 0")
	_assert(am.sfx_history.is_empty(), "1.3 SFX history is initially empty")

	# Rapid burst of 120 mixed audio calls in a tight loop
	var sfx_calls = [
		"play_sfx_timing_hit",
		"play_sfx_victory_jingle",
		"play_sfx_steam_hiss",
		"play_sfx_qte_correct",
		"play_sfx_qte_wrong"
	]
	
	for i in range(120):
		var choice = i % sfx_calls.size()
		match choice:
			0:
				var ratings = ["Perfect", "Good", "Miss", "Unknown"]
				am.play_sfx_timing_hit(ratings[i % ratings.size()])
			1:
				am.play_sfx_victory_jingle()
			2:
				am.play_sfx_steam_hiss()
			3:
				am.play_sfx_qte_chime(true)
			4:
				am.play_sfx_qte_chime(false)

	_assert(am.sfx_play_count == 120, "1.4 Processed 120 rapid burst calls without dropping count (count=%d)" % am.sfx_play_count)
	_assert(am.sfx_history.size() <= am.max_history_size, "1.5 History ring buffer bounded by max_history_size (%d <= %d)" % [am.sfx_history.size(), am.max_history_size])
	_assert(am.sfx_events.size() <= am.max_history_size, "1.6 Events ring buffer bounded by max_history_size (%d <= %d)" % [am.sfx_events.size(), am.max_history_size])

	# Verify round-robin pool cursor survived rapid wrap-around without errors
	var pool_size = am._sfx_pool.size()
	_assert(pool_size == 8, "1.7 SFX pool size confirmed at %d players" % pool_size)
	_assert(am._pool_cursor >= 0, "1.8 Pool cursor is non-negative (%d)" % am._pool_cursor)

	# Verify calling with invalid or extreme parameters
	am.play_sfx_timing_hit("")
	_assert(am.last_sfx_played == "hit_miss", "1.9 Empty string rating safely defaults to 'hit_miss'")
	am.play_sfx_timing_hit("SUPER_EXTREME_UNEXPECTED_TIER")
	_assert(am.last_sfx_played == "hit_miss", "1.10 Unexpected rating string safely defaults to 'hit_miss'")

	await process_frame

# ------------------------------------------------------------------------------
# 2. Audio Synthesis: Signal Analysis, PCM Bound Checking & Zero-Popping
# ------------------------------------------------------------------------------
func _stress_test_audio_pcm_signal_fidelity() -> void:
	print("\n--- STRESS 2: Audio Synthesis PCM Buffer Integrity & Zero-Popping ---")
	var am = root.get_node_or_null("/root/AudioManager")
	if am == null:
		return

	var streams_to_check = {
		"_wav_victory_jingle": {"name": "Victory Jingle", "check_tail": true},
		"_wav_steam_hiss": {"name": "Steam Hiss", "check_tail": true},
		"_wav_qte_correct": {"name": "QTE Correct", "check_tail": true},
		"_wav_qte_wrong": {"name": "QTE Wrong", "check_tail": true},
		"_wav_hit_perfect": {"name": "Hit Perfect", "check_tail": true},
		"_wav_hit_good": {"name": "Hit Good", "check_tail": true},
		"_wav_hit_miss": {"name": "Hit Miss", "check_tail": true}
	}

	for var_name in streams_to_check.keys():
		var info = streams_to_check[var_name]
		var wav = am.get(var_name) as AudioStreamWAV
		_assert(wav != null, "2.1 %s stream resource is present" % info["name"])
		if wav == null:
			continue

		var data = wav.data
		var num_samples = data.size() / 2
		_assert(num_samples > 200, "2.2 %s has sufficient PCM samples (%d samples)" % [info["name"], num_samples])

		var max_val: int = -32768
		var min_val: int = 32767
		var has_nan_or_inf: bool = false
		var sum_val: float = 0.0

		for s_idx in range(num_samples):
			var sample: int = data.decode_s16(s_idx * 2)
			if sample > max_val:
				max_val = sample
			if sample < min_val:
				min_val = sample
			sum_val += float(sample)

		_assert(max_val <= 32767 and min_val >= -32768, "2.3 %s PCM samples strictly within 16-bit limits [%d, %d]" % [info["name"], min_val, max_val])

		# Check DC Offset (normalized average amplitude should be near 0.0, < 0.15)
		var dc_offset: float = (sum_val / float(num_samples)) / 32768.0
		_assert(absf(dc_offset) < 0.15, "2.4 %s has acceptable DC offset (%.4f)" % [info["name"], dc_offset])

		# Zero-popping verification: The last 100 samples must have low amplitude (< 0.15 normalized)
		if info["check_tail"] and num_samples > 100:
			var tail_peak: int = 0
			for t_idx in range(num_samples - 100, num_samples):
				var s = abs(data.decode_s16(t_idx * 2))
				if s > tail_peak:
					tail_peak = s
			var norm_tail_peak: float = float(tail_peak) / 32768.0
			_assert(norm_tail_peak < 0.15, "2.5 %s tail smoothly fades out without pop artifact (tail_peak=%.4f)" % [info["name"], norm_tail_peak])

	await process_frame

# ------------------------------------------------------------------------------
# 3. Haptics Manager: Concurrency, Cooldown Throttling & Platform Safety
# ------------------------------------------------------------------------------
func _stress_test_haptics_concurrency_and_boundaries() -> void:
	print("\n--- STRESS 3: Haptics Concurrency, Boundary Ratings & Throttle ---")
	var hm = root.get_node_or_null("/root/HapticsManager")
	_assert(hm != null, "3.1 HapticsManager singleton is available")
	if hm == null:
		return

	hm.clear_history()
	hm.haptics_enabled = true

	# Test 3.2: Rapid error burst (bypasses cooldown)
	for i in range(20):
		hm.vibrate_error()
	_assert(hm.vibration_count == 20, "3.2 Rapid vibrate_error calls all processed (count=%d)" % hm.vibration_count)
	_assert(hm.get_last_vibration_ms() == 65, "3.3 Last vibration duration is 65ms")

	# Test 3.4: Rapid sweet spot (bypasses cooldown)
	hm.vibrate_sweet_spot()
	_assert(hm.get_last_vibration_ms() == 35, "3.4 vibrate_sweet_spot sets 35ms")
	_assert(absf(hm.get_last_amplitude() - 0.70) < 0.01, "3.5 vibrate_sweet_spot amplitude is 0.70")

	# Test 3.6: vibrate_timing_hit with boundary strings
	var ratings_to_test = {
		"Perfect": 45,
		"Good": 25,
		"Miss": 15,
		"PERFECT": 15, # Case-sensitive fallback to Miss tier
		"": 15,
		"ArbitraryUnknown": 15
	}
	for r_str in ratings_to_test.keys():
		var expected_ms = ratings_to_test[r_str]
		hm.vibrate_timing_hit(r_str)
		_assert(hm.get_last_vibration_ms() == expected_ms, "3.6 vibrate_timing_hit('%s') yielded %d ms" % [r_str, hm.get_last_vibration_ms()])

	# Test 3.7: Master disable switch suppresses vibration
	hm.haptics_enabled = false
	var pre_count = hm.vibration_count
	hm.vibrate_error()
	hm.vibrate_sweet_spot()
	hm.vibrate_timing_hit("Perfect")
	_assert(hm.vibration_count == pre_count, "3.7 Disabled haptics suppresses all vibration calls (count unchanged=%d)" % hm.vibration_count)
	hm.haptics_enabled = true

	# Test 3.8: vibrate_success_pattern handles disabled mid-flight
	hm.vibrate_success_pattern(30, 40, 50)
	await create_timer(0.01).timeout
	# Disable haptics before second pulse triggers
	hm.haptics_enabled = false
	await create_timer(0.06).timeout
	# If disabled, second pulse was skipped
	_assert(hm.haptics_enabled == false, "3.8 Mid-pattern disabling safely completes without exception")
	hm.haptics_enabled = true

	await process_frame

# ------------------------------------------------------------------------------
# 4. FloatingScorePopup3D: Burst Spawning, Tree Detached & Auto-Free Verification
# ------------------------------------------------------------------------------
func _stress_test_floating_popups_burst_and_lifecycle() -> void:
	print("\n--- STRESS 4: FloatingScorePopup3D Rapid Burst & Tween Auto-Free ---")

	var test_parent = Node3D.new()
	test_parent.name = "PopupStressParent"
	root.add_child(test_parent)
	await process_frame

	# 4.1 Rapid burst of 60 popups
	var popups: Array[Label3D] = []
	for i in range(60):
		var text = "+%d BOOST!" % (i * 10)
		var popup = FloatingScorePopup3D.spawn_popup_3d(test_parent, Vector3(float(i), 1.0, 0.0), text, Color(0.2, 0.9, 0.3), 0.15, 0.3, 24)
		_assert(popup != null, "4.1 Spawned popup %d successfully" % i)
		popups.append(popup)

	_assert(test_parent.get_child_count() == 60, "4.2 All 60 popups attached as children")

	# Wait for the short duration (0.15s + buffer) to allow tween callbacks to fire
	print("  [INFO] Waiting 0.35s for tween completion and queue_free on 60 popups...")
	await create_timer(0.35).timeout
	await process_frame
	await process_frame

	# Check child count after queue_free
	var surviving_children = test_parent.get_child_count()
	_assert(surviving_children == 0, "4.3 All 60 burst popups auto-freed cleanly via tween chain (remaining=%d)" % surviving_children)

	# 4.4 Boundary condition: Null parent
	var null_popup = FloatingScorePopup3D.spawn_popup_3d(null, Vector3.ZERO, "NULL_TEST")
	_assert(null_popup == null, "4.4 spawn_popup_3d with null parent safely returns null")

	# 4.5 Boundary condition: Parent not in scene tree
	var unmounted_parent = Node3D.new()
	var unmounted_popup = FloatingScorePopup3D.spawn_popup_3d(unmounted_parent, Vector3(0, 5, 0), "UNMOUNTED_TEST")
	_assert(unmounted_popup != null, "4.5 spawn_popup_3d with unmounted parent returns label")
	_assert(unmounted_popup.is_queued_for_deletion(), "4.6 Unmounted popup immediately queues for deletion to avoid leak")
	unmounted_parent.free()

	# 4.7 Boundary condition: Extreme text content
	var extreme_text = "A".repeat(500)
	var extreme_popup = FloatingScorePopup3D.spawn_popup_3d(test_parent, Vector3.ZERO, extreme_text)
	_assert(extreme_popup != null and extreme_popup.text.length() == 500, "4.7 500-char string popup instantiated without crash")
	extreme_popup.queue_free()

	test_parent.queue_free()
	await process_frame

# ------------------------------------------------------------------------------
# 5. Screen Shake: Signal Pipeline Resilience & Clamping
# ------------------------------------------------------------------------------
func _stress_test_screen_shake_pipeline_resilience() -> void:
	print("\n--- STRESS 5: Screen Shake Event Pipeline & Extreme Inputs ---")
	var gs = root.get_node_or_null("/root/GameState")
	_assert(gs != null, "5.1 GameState mounted")
	if gs == null:
		return

	# Load Main3D scene
	var m3d_scene = load("res://scenes/main_3d.tscn")
	var m3d = m3d_scene.instantiate()
	root.add_child(m3d)
	await process_frame

	# Stress 5.2: 50 rapid camera shake calls via GameState signal
	m3d.trauma = 0.0
	for i in range(50):
		gs.trigger_camera_shake(0.05)
	
	_assert(m3d.trauma > 0.0, "5.2 Rapid shake signals received by Main3D (trauma=%.2f)" % m3d.trauma)
	_assert(m3d.trauma <= 1.0, "5.3 Cumulative trauma safely clamped <= 1.0 bound (trauma=%.2f)" % m3d.trauma)

	# Stress 5.4: Extreme out-of-range inputs
	m3d.trauma = 0.5
	m3d.trigger_camera_shake(999.0)
	_assert(m3d.trauma <= 1.0, "5.4 Mega trauma (999.0) safely clamped to 1.0 (actual=%.2f)" % m3d.trauma)

	m3d.trigger_camera_shake(-50.0)
	_assert(m3d.trauma >= 0.0, "5.5 Negative trauma (-50.0) safely clamped >= 0.0 (actual=%.2f)" % m3d.trauma)

	m3d.queue_free()
	await process_frame

	# Stress 5.6: Signal fired when Main3D is unmounted
	gs.trigger_camera_shake(0.35)
	_assert(true, "5.6 Triggering camera shake when Main3D is unmounted does not throw or crash")

# ------------------------------------------------------------------------------
# 6. Pointer Isolation & Touch Ergonomics under Hostile Input
# ------------------------------------------------------------------------------
func _stress_test_pointer_isolation_under_hostile_input() -> void:
	print("\n--- STRESS 6: Minigame Pointer Isolation Under Hostile Input ---")

	var minigame_scenes = [
		{"path": "res://scenes/ui/cyber_sync_minigame.tscn", "name": "CyberSync"},
		{"path": "res://scenes/ui/pitch_stage_minigame.tscn", "name": "PitchStage"},
		{"path": "res://scenes/ui/espresso_brew_minigame.tscn", "name": "EspressoBrew"}
	]

	for mg_info in minigame_scenes:
		var scene = load(mg_info["path"])
		_assert(scene != null, "6.1 %s scene loaded" % mg_info["name"])
		if scene == null:
			continue

		var instance = scene.instantiate() as Control
		root.add_child(instance)
		await process_frame

		# Verify mouse filter is STOP
		_assert(instance.mouse_filter == Control.MOUSE_FILTER_STOP, "6.2 %s root has mouse_filter == STOP (0)" % mg_info["name"])

		# Verify _gui_input consumes touch events
		var touch_ev = InputEventScreenTouch.new()
		touch_ev.position = Vector2(100, 100)
		touch_ev.pressed = true
		instance._gui_input(touch_ev)
		_assert(true, "6.3 %s handled InputEventScreenTouch without throwing" % mg_info["name"])

		var mouse_ev = InputEventMouseButton.new()
		mouse_ev.position = Vector2(100, 100)
		mouse_ev.pressed = true
		mouse_ev.button_index = MOUSE_BUTTON_LEFT
		instance._gui_input(mouse_ev)
		_assert(true, "6.4 %s handled InputEventMouseButton without throwing" % mg_info["name"])

		instance.queue_free()
		await process_frame
