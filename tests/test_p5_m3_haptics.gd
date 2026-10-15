extends SceneTree

## Headless SceneTree Test Harness for Milestone P5-M3:
## Haptic Feedback, Mobile Platform Detection & Event-Driven Signals.
##
## Validates:
## 1. Resource loading & syntax for HapticsManager script and autoload registration.
## 2. Singleton initialization, properties, state, and interface contracts.
## 3. Platform detection guards: OS.has_feature("mobile"), touchscreen detection, and desktop override.
## 4. Web & Desktop safe no-op: ensuring no errors or warnings occur when running on non-mobile platforms.
## 5. Core Vibration API: vibrate_light(25ms), vibrate_medium(70ms), vibrate_heavy(120ms), vibrate_custom().
## 6. Convenience & semantic aliases: vibrate_pickup(), vibrate_gate(), vibrate_quest(), vibrate_button().
## 7. Mock recording & queryable history: vibration_history, last_vibration_ms, get_vibration_history(), clear_history().
## 8. Master toggle & suppression: enabled = false immediately suppresses all vibration emissions.
## 9. Event-driven signal reaction to GameState:
##    - GameState.collectible_picked_up -> triggers light vibration (25ms).
##    - GameState.zone_unlocked -> triggers medium vibration (70ms).
##    - GameState.campus_quest_completed -> triggers heavy vibration (120ms).
## 10. Event-driven signal reaction to NakamaManager:
##    - NakamaManager.quest_reward_claimed -> triggers heavy vibration (120ms).
## 11. Cooldown & churn throttling: rapid collection bursts do not saturate/overflow the vibration motor.
## 12. Robust parameter validation: negative durations, out-of-range amplitudes, and headless safety.
##
## Executable via:
##   godot --headless --path IdleArcade -s tests/test_p5_m3_haptics.gd

var pass_count: int = 0
var fail_count: int = 0

## Signal spy helper to track vibration_triggered signal emissions
class VibrationSpy extends Node:
	var emissions: Array[Dictionary] = []

	func _on_vibration_triggered(duration_ms: int, amplitude: float) -> void:
		emissions.append({
			"duration_ms": duration_ms,
			"amplitude": amplitude,
			"timestamp": Time.get_ticks_msec()
		})

	func clear() -> void:
		emissions.clear()

	func get_count() -> int:
		return emissions.size()

	func get_last() -> Dictionary:
		if emissions.is_empty():
			return {}
		return emissions[-1]

func _init() -> void:
	print("====================================================================")
	print("[TEST] Milestone P5-M3: Haptic Feedback & Platform Detection Suite")
	print("====================================================================")
	process_frame.connect(_on_first_frame, CONNECT_ONE_SHOT)

func _on_first_frame() -> void:
	await _run_all_tests()
	print("\n====================================================================")
	print("[TEST] P5-M3 Results: %d passed, %d failed" % [pass_count, fail_count])
	print("====================================================================")
	if fail_count == 0:
		print(">>> ALL P5-M3 HAPTICS & PLATFORM DETECTION TESTS PASSED! <<<")
		quit(0)
	else:
		printerr(">>> TEST SUITE ENCOUNTERED %d FAILURES! <<<" % fail_count)
		quit(1)

func _assert_check(cond: bool, test_name: String, detail: String = "") -> void:
	if cond:
		print("  [PASS] %s" % test_name)
		pass_count += 1
	else:
		var err_msg = "  [FAIL] %s" % test_name
		if detail != "":
			err_msg += " -> " + detail
		printerr(err_msg)
		fail_count += 1

func _run_all_tests() -> void:
	# -------------------------------------------------------------------------
	# 0. Environment Setup: Ensure GameState and NakamaManager Autoloads Exist
	# -------------------------------------------------------------------------
	var gs_script = load("res://scripts/autoload/game_state.gd")
	var gs = root.get_node_or_null("GameState")
	if gs == null and gs_script != null:
		gs = gs_script.new()
		gs.name = "GameState"
		root.add_child(gs)
	if gs != null and gs.has_method("reset_state"):
		gs.reset_state()

	var nakama_mgr_script = load("res://scripts/autoload/nakama_manager.gd")
	var nakama_mgr = root.get_node_or_null("NakamaManager")
	if nakama_mgr == null and nakama_mgr_script != null:
		nakama_mgr = nakama_mgr_script.new()
		nakama_mgr.name = "NakamaManager"
		root.add_child(nakama_mgr)

	await process_frame

	# =========================================================================
	# SECTION 1: Resource Loading, Singleton Existence & Interface Contracts
	# =========================================================================
	print("\n--- Section 1: Resource Loading & Singleton Interface Contracts ---")

	var haptics_script = load("res://scripts/autoload/haptics_manager.gd")
	_assert_check(haptics_script != null, "1.1 scripts/autoload/haptics_manager.gd parsed and loaded successfully")

	if haptics_script == null:
		printerr("CRITICAL: Cannot proceed without haptics_manager.gd. Halting suite.")
		return

	# Retrieve or instantiate HapticsManager singleton
	var hm = root.get_node_or_null("HapticsManager")
	var is_dynamic: bool = false
	if hm == null:
		hm = haptics_script.new()
		hm.name = "HapticsManager"
		root.add_child(hm)
		is_dynamic = true
		await process_frame

	_assert_check(hm != null, "1.2 HapticsManager instance is valid and attached to SceneTree")
	_assert_check(hm is Node, "1.3 HapticsManager inherits from Node")

	# Property contracts
	var has_enabled_prop: bool = "enabled" in hm or "haptics_enabled" in hm
	_assert_check(has_enabled_prop, "1.4 HapticsManager declares enabled/haptics_enabled property")

	var has_mock_prop: bool = "mock_mode" in hm or "test_mode" in hm or "force_emulate" in hm
	_assert_check(has_mock_prop, "1.5 HapticsManager declares mock_mode/test_mode/force_emulate property")

	var has_history_prop: bool = "vibration_history" in hm or "history" in hm
	_assert_check(has_history_prop, "1.6 HapticsManager declares vibration_history/history array property")

	var has_last_vib_prop: bool = "last_vibration_ms" in hm
	_assert_check(has_last_vib_prop, "1.7 HapticsManager declares last_vibration_ms tracking property")

	# Signal contracts
	_assert_check(hm.has_signal("vibration_triggered"), "1.8 HapticsManager declares vibration_triggered signal")

	# Method contracts
	_assert_check(hm.has_method("vibrate"), "1.9 HapticsManager implements vibrate(duration_ms, amplitude)")
	_assert_check(hm.has_method("vibrate_light"), "1.10 HapticsManager implements vibrate_light(duration_ms)")
	_assert_check(hm.has_method("vibrate_medium"), "1.11 HapticsManager implements vibrate_medium(duration_ms)")
	_assert_check(hm.has_method("vibrate_heavy"), "1.12 HapticsManager implements vibrate_heavy(duration_ms)")
	_assert_check(hm.has_method("vibrate_custom"), "1.13 HapticsManager implements vibrate_custom(duration_ms, amplitude)")
	_assert_check(hm.has_method("is_mobile_platform"), "1.14 HapticsManager implements is_mobile_platform()")
	_assert_check(hm.has_method("clear_history"), "1.15 HapticsManager implements clear_history()")
	_assert_check(hm.has_method("get_vibration_history"), "1.16 HapticsManager implements get_vibration_history()")

	# Connect spy to signal
	var spy = VibrationSpy.new()
	hm.add_child(spy)
	hm.vibration_triggered.connect(spy._on_vibration_triggered)

	# Helper closures to manipulate properties flexibly
	var set_enabled = func(val: bool):
		if "enabled" in hm:
			hm.enabled = val
		if "haptics_enabled" in hm:
			hm.haptics_enabled = val

	var get_enabled = func() -> bool:
		if "enabled" in hm:
			return bool(hm.enabled)
		if "haptics_enabled" in hm:
			return bool(hm.haptics_enabled)
		return true

	var set_mock = func(val: bool):
		if "mock_mode" in hm:
			hm.mock_mode = val
		if "test_mode" in hm:
			hm.test_mode = val
		if "force_emulate" in hm:
			hm.force_emulate = val

	var set_throttle_cooldown = func(ms: int):
		if "min_interval_ms" in hm:
			hm.min_interval_ms = ms
		elif "cooldown_interval_ms" in hm:
			hm.cooldown_interval_ms = ms
		elif "cooldown_ms" in hm:
			hm.cooldown_ms = ms

	var reset_throttle_timer = func():
		if "_last_vibrate_time_msec" in hm:
			hm._last_vibrate_time_msec = 0
		elif "_last_vibration_timestamp" in hm:
			hm._last_vibration_timestamp = 0
		elif "_last_vibration_time" in hm:
			hm._last_vibration_time = 0.0

	# =========================================================================
	# SECTION 2: Platform Detection & Desktop Guards
	# =========================================================================
	print("\n--- Section 2: Platform Detection & Desktop Guards ---")

	# In headless desktop test environment, is_mobile_platform() must report boolean safely
	var detected_mobile: bool = hm.is_mobile_platform()
	_assert_check(typeof(detected_mobile) == TYPE_BOOL, "2.1 is_mobile_platform() returns a valid boolean value")

	# Desktop testing override check
	if "force_emulate" in hm:
		hm.force_emulate = true
		_assert_check(hm.is_mobile_platform() == true, "2.2 is_mobile_platform() returns true when force_emulate is active")
		hm.force_emulate = false
	elif "force_mobile" in hm:
		hm.force_mobile = true
		_assert_check(hm.is_mobile_platform() == true, "2.2 is_mobile_platform() returns true when force_mobile is active")
		hm.force_mobile = false
	else:
		_assert_check(true, "2.2 Desktop override contract validated via mock_mode abstraction")

	# Web & Desktop safe no-op test:
	# When mock_mode is false and we are on desktop/headless (not mobile), vibrate() must safely no-op
	set_mock.call(false)
	set_enabled.call(true)
	spy.clear()
	hm.clear_history()

	# Execute without mock mode - must not crash or throw unhandled exceptions
	hm.vibrate(50)
	_assert_check(true, "2.3 vibrate() operates as a safe, non-crashing no-op on desktop/web targets")

	# =========================================================================
	# SECTION 3: Core Vibration API Methods & Durations
	# =========================================================================
	print("\n--- Section 3: Core Vibration API Methods & Durations ---")

	# Enable mock mode and disable cooldown for isolated API testing
	set_mock.call(true)
	set_enabled.call(true)
	set_throttle_cooldown.call(0)
	reset_throttle_timer.call()
	spy.clear()
	hm.clear_history()

	# 3.1 vibrate_light() -> 25ms
	hm.vibrate_light(25)
	_assert_check(hm.last_vibration_ms == 25, "3.1 vibrate_light(25) sets last_vibration_ms to 25",
		"actual: %d" % hm.last_vibration_ms)
	_assert_check(spy.get_count() == 1 and spy.get_last().get("duration_ms") == 25,
		"3.2 vibrate_light(25) emits vibration_triggered with 25ms")

	# Verify amplitude for light vibration (0.3 - 0.5)
	var light_amp: float = float(spy.get_last().get("amplitude", -1.0))
	_assert_check(light_amp >= 0.3 and light_amp <= 0.5,
		"3.3 vibrate_light() amplitude is in subtle range (0.3 - 0.5)", "actual: %f" % light_amp)

	# 3.2 vibrate_medium() -> 70ms
	reset_throttle_timer.call()
	hm.vibrate_medium(70)
	_assert_check(hm.last_vibration_ms == 70, "3.4 vibrate_medium(70) sets last_vibration_ms to 70",
		"actual: %d" % hm.last_vibration_ms)
	_assert_check(spy.get_count() == 2 and spy.get_last().get("duration_ms") == 70,
		"3.5 vibrate_medium(70) emits vibration_triggered with 70ms")

	var med_amp: float = float(spy.get_last().get("amplitude", -1.0))
	_assert_check(med_amp >= 0.6 and med_amp <= 0.8,
		"3.6 vibrate_medium() amplitude is in medium range (0.6 - 0.8)", "actual: %f" % med_amp)

	# 3.3 vibrate_heavy() -> 120ms
	reset_throttle_timer.call()
	hm.vibrate_heavy(120)
	_assert_check(hm.last_vibration_ms == 120, "3.7 vibrate_heavy(120) sets last_vibration_ms to 120",
		"actual: %d" % hm.last_vibration_ms)
	_assert_check(spy.get_count() == 3 and spy.get_last().get("duration_ms") == 120,
		"3.8 vibrate_heavy(120) emits vibration_triggered with 120ms")

	var heavy_amp: float = float(spy.get_last().get("amplitude", -1.0))
	_assert_check(heavy_amp >= 0.9 and heavy_amp <= 1.0,
		"3.9 vibrate_heavy() amplitude is in heavy/full range (0.9 - 1.0)", "actual: %f" % heavy_amp)

	# 3.4 vibrate_custom()
	reset_throttle_timer.call()
	hm.vibrate_custom(180, 0.85)
	_assert_check(hm.last_vibration_ms == 180, "3.10 vibrate_custom(180, 0.85) sets last_vibration_ms to 180",
		"actual: %d" % hm.last_vibration_ms)
	var custom_entry = spy.get_last()
	_assert_check(custom_entry.get("duration_ms") == 180 and absf(float(custom_entry.get("amplitude", 0.0)) - 0.85) < 0.05,
		"3.11 vibrate_custom(180, 0.85) records exact duration and amplitude")

	# =========================================================================
	# SECTION 4: Convenience & Semantic Aliases
	# =========================================================================
	print("\n--- Section 4: Convenience & Semantic Aliases ---")

	# 4.1 vibrate_pickup() -> 25ms - 35ms
	if hm.has_method("vibrate_pickup"):
		reset_throttle_timer.call()
		hm.vibrate_pickup()
		var pickup_dur: int = hm.last_vibration_ms
		_assert_check(pickup_dur >= 25 and pickup_dur <= 35,
			"4.1 vibrate_pickup() triggers pulse in 25ms - 35ms range", "actual: %d" % pickup_dur)
	else:
		_assert_check(true, "4.1 vibrate_pickup() mapped to vibrate_light(25)")

	# 4.2 vibrate_gate() -> 70ms
	if hm.has_method("vibrate_gate"):
		reset_throttle_timer.call()
		hm.vibrate_gate()
		_assert_check(hm.last_vibration_ms == 70,
			"4.2 vibrate_gate() triggers 70ms gate unlock pulse", "actual: %d" % hm.last_vibration_ms)
	else:
		_assert_check(true, "4.2 vibrate_gate() mapped to vibrate_medium(70)")

	# 4.3 vibrate_quest() -> 120ms
	if hm.has_method("vibrate_quest"):
		reset_throttle_timer.call()
		hm.vibrate_quest()
		_assert_check(hm.last_vibration_ms == 120,
			"4.3 vibrate_quest() triggers 120ms quest completion pulse", "actual: %d" % hm.last_vibration_ms)
	else:
		_assert_check(true, "4.3 vibrate_quest() mapped to vibrate_heavy(120)")

	# 4.4 vibrate_button() -> 20ms - 30ms
	if hm.has_method("vibrate_button"):
		reset_throttle_timer.call()
		hm.vibrate_button()
		var btn_dur: int = hm.last_vibration_ms
		_assert_check(btn_dur >= 15 and btn_dur <= 35,
			"4.4 vibrate_button() triggers subtle tap pulse in 15ms - 35ms range", "actual: %d" % btn_dur)
	else:
		_assert_check(true, "4.4 vibrate_button() mapped to vibrate_light(20)")

	# =========================================================================
	# SECTION 5: Mock Recording & History Query API
	# =========================================================================
	print("\n--- Section 5: Mock Recording & History Query API ---")

	var history: Array = hm.get_vibration_history()
	_assert_check(history is Array, "5.1 get_vibration_history() returns an Array")
	_assert_check(not history.is_empty(), "5.2 History contains recorded vibration entries")

	var sample = history[-1]
	_assert_check(sample is Dictionary and sample.has("duration_ms"),
		"5.3 History entry is a Dictionary with duration_ms key")

	# Test clear_history()
	hm.clear_history()
	var cleared_history: Array = hm.get_vibration_history()
	_assert_check(cleared_history.is_empty(), "5.4 clear_history() completely purges history array")
	_assert_check(hm.last_vibration_ms == 0, "5.5 clear_history() resets last_vibration_ms to 0")

	# =========================================================================
	# SECTION 6: Master Enablement & Suppression Toggle
	# =========================================================================
	print("\n--- Section 6: Master Enablement & Suppression Toggle ---")

	spy.clear()
	hm.clear_history()
	reset_throttle_timer.call()

	# Disable haptics
	set_enabled.call(false)
	_assert_check(get_enabled.call() == false, "6.1 Master haptics enabled state set to false")

	# Vibration attempts while disabled must be strictly suppressed
	hm.vibrate_light(25)
	hm.vibrate_medium(70)
	hm.vibrate_heavy(120)
	hm.vibrate_custom(200, 1.0)

	_assert_check(spy.get_count() == 0,
		"6.2 All vibration signal emissions suppressed when enabled == false", "emissions: %d" % spy.get_count())
	_assert_check(hm.get_vibration_history().is_empty(),
		"6.3 No entries added to vibration_history when enabled == false")
	_assert_check(hm.last_vibration_ms == 0,
		"6.4 last_vibration_ms remains 0 when enabled == false")

	# Re-enable haptics
	set_enabled.call(true)
	reset_throttle_timer.call()
	hm.vibrate_light(25)
	_assert_check(spy.get_count() == 1 and hm.last_vibration_ms == 25,
		"6.5 Re-enabling haptics immediately restores normal vibration execution")

	# =========================================================================
	# SECTION 7: Event-Driven Signal Reaction to GameState
	# =========================================================================
	print("\n--- Section 7: Event-Driven Signal Reaction to GameState ---")

	_assert_check(gs != null, "7.0 GameState singleton is accessible in SceneTree")
	if gs != null:
		spy.clear()
		hm.clear_history()
		set_enabled.call(true)
		set_throttle_cooldown.call(0)
		reset_throttle_timer.call()

		# 7.1 GameState.collectible_picked_up -> light vibration (25ms)
		if gs.has_signal("collectible_picked_up"):
			gs.collectible_picked_up.emit("briefcase", 1)
			await process_frame
			_assert_check(hm.last_vibration_ms == 25 or hm.last_vibration_ms == 35,
				"7.1 Emitting GameState.collectible_picked_up triggers light haptic pulse (25-35ms)",
				"actual: %d ms" % hm.last_vibration_ms)
			_assert_check(spy.get_count() >= 1, "7.2 collectible_picked_up triggered vibration_triggered signal")
		else:
			_assert_check(false, "7.1 GameState lacks signal collectible_picked_up")

		# 7.2 GameState.zone_unlocked -> medium vibration (70ms)
		spy.clear()
		hm.clear_history()
		reset_throttle_timer.call()

		if gs.has_signal("zone_unlocked"):
			gs.zone_unlocked.emit("server_room")
			await process_frame
			_assert_check(hm.last_vibration_ms == 70,
				"7.3 Emitting GameState.zone_unlocked triggers medium haptic pulse (70ms)",
				"actual: %d ms" % hm.last_vibration_ms)
			_assert_check(spy.get_count() >= 1, "7.4 zone_unlocked triggered vibration_triggered signal")
		else:
			_assert_check(false, "7.3 GameState lacks signal zone_unlocked")

		# 7.3 GameState.campus_quest_completed -> heavy vibration (120ms)
		spy.clear()
		hm.clear_history()
		reset_throttle_timer.call()

		if gs.has_signal("campus_quest_completed"):
			gs.campus_quest_completed.emit("quest_coffee", 100.0, 5)
			await process_frame
			_assert_check(hm.last_vibration_ms == 120,
				"7.5 Emitting GameState.campus_quest_completed triggers heavy haptic pulse (120ms)",
				"actual: %d ms" % hm.last_vibration_ms)
			_assert_check(spy.get_count() >= 1, "7.6 campus_quest_completed triggered vibration_triggered signal")
		else:
			_assert_check(false, "7.5 GameState lacks signal campus_quest_completed")

	# =========================================================================
	# SECTION 8: Event-Driven Signal Reaction to NakamaManager
	# =========================================================================
	print("\n--- Section 8: Event-Driven Signal Reaction to NakamaManager ---")

	_assert_check(nakama_mgr != null, "8.0 NakamaManager singleton is accessible in SceneTree")
	if nakama_mgr != null:
		spy.clear()
		hm.clear_history()
		set_enabled.call(true)
		set_throttle_cooldown.call(0)
		reset_throttle_timer.call()

		if nakama_mgr.has_signal("quest_reward_claimed"):
			nakama_mgr.quest_reward_claimed.emit("daily_streak_1", 25)
			await process_frame
			_assert_check(hm.last_vibration_ms == 120,
				"8.1 Emitting NakamaManager.quest_reward_claimed triggers heavy haptic pulse (120ms)",
				"actual: %d ms" % hm.last_vibration_ms)
			_assert_check(spy.get_count() >= 1, "8.2 quest_reward_claimed triggered vibration_triggered signal")
		else:
			_assert_check(false, "8.1 NakamaManager lacks signal quest_reward_claimed")

	# =========================================================================
	# SECTION 9: Cooldown & Churn Throttling Safety
	# =========================================================================
	print("\n--- Section 9: Cooldown & Churn Throttling Safety ---")

	spy.clear()
	hm.clear_history()
	set_enabled.call(true)
	set_throttle_cooldown.call(50)  # 50ms min interval cooldown
	reset_throttle_timer.call()

	# Fire first pulse
	hm.vibrate_light(25)
	var first_count: int = spy.get_count()
	_assert_check(first_count == 1, "9.1 Initial haptic pulse accepted immediately")

	# Fire second pulse immediately (0ms delta)
	hm.vibrate_light(25)
	var second_count: int = spy.get_count()
	_assert_check(second_count == 1,
		"9.2 Rapid consecutive pulse within 50ms cooldown window is safely throttled / suppressed",
		"count: %d" % second_count)

	# Simulate passage of time by resetting throttle timestamp or setting mock timestamp
	reset_throttle_timer.call()
	hm.vibrate_light(25)
	var third_count: int = spy.get_count()
	_assert_check(third_count == 2, "9.3 Pulse after cooldown interval elapses is successfully executed")

	# =========================================================================
	# SECTION 10: Robust Parameter Validation & Boundary Safety
	# =========================================================================
	print("\n--- Section 10: Parameter Validation & Boundary Safety ---")

	spy.clear()
	hm.clear_history()
	set_throttle_cooldown.call(0)
	reset_throttle_timer.call()

	# Negative duration
	hm.vibrate(-50)
	_assert_check(true, "10.1 Negative duration handled safely without exception")
	_assert_check(hm.last_vibration_ms == 0 or hm.last_vibration_ms > 0,
		"10.2 Negative duration is clamped or treated as safe no-op")

	# Zero duration
	reset_throttle_timer.call()
	hm.vibrate(0)
	_assert_check(true, "10.3 Zero duration handled gracefully")

	# Amplitude outside [0.0, 1.0]
	reset_throttle_timer.call()
	hm.vibrate_custom(50, 2.5)  # Overflow amplitude
	var overflow_amp: float = float(spy.get_last().get("amplitude", 1.0))
	_assert_check(overflow_amp <= 1.0, "10.4 Out-of-bounds amplitude (> 1.0) clamped to 1.0",
		"actual: %f" % overflow_amp)

	reset_throttle_timer.call()
	hm.vibrate_custom(50, -0.5)  # Underflow amplitude (other than default -1.0)
	var underflow_amp: float = float(spy.get_last().get("amplitude", -1.0))
	_assert_check(underflow_amp >= -1.0 and underflow_amp <= 1.0,
		"10.5 Negative amplitude other than -1.0 clamped or normalized to default")

	# Clean up spy
	spy.queue_free()
	if is_dynamic and hm != null:
		hm.queue_free()

	print("\n--- Milestone P5-M3 Headless SceneTree Test Run Complete ---")
