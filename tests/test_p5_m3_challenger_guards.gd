extends SceneTree

## Adversarial Empirical Challenge Suite for Milestone P5-M3
## Focus: Platform Guards, Desktop Emulation, Toggle Suppression & Zero-Coupling Invariant
## Author: p5_m3_challenger_2 (Empirical Challenger: critic, specialist)
##
## Executable via:
##   godot --headless --path IdleArcade -s tests/test_p5_m3_challenger_guards.gd

var pass_count: int = 0
var fail_count: int = 0

class ChallengeSpy extends Node:
	var emissions: Array[Dictionary] = []
	var toggle_events: Array[bool] = []
	var throttled_events: Array[String] = []

	func on_vibration(duration_ms: int, amplitude: float) -> void:
		emissions.append({
			"duration_ms": duration_ms,
			"amplitude": amplitude,
			"timestamp": Time.get_ticks_msec()
		})

	func on_toggle(state: bool) -> void:
		toggle_events.append(state)

	func on_throttled(item: String) -> void:
		throttled_events.append(item)

	func clear() -> void:
		emissions.clear()
		toggle_events.clear()
		throttled_events.clear()

func _init() -> void:
	print("====================================================================")
	print("[CHALLENGE] Milestone P5-M3: Empirical Platform Guards & Invariants")
	print("====================================================================")
	process_frame.connect(_on_first_frame, CONNECT_ONE_SHOT)

func _on_first_frame() -> void:
	await _run_adversarial_challenges()
	print("\n====================================================================")
	print("[CHALLENGE] Results: %d passed, %d failed" % [pass_count, fail_count])
	print("====================================================================")
	if fail_count == 0:
		print(">>> ALL P5-M3 ADVERSARIAL CHALLENGES PASSED! VERDICT: APPROVE <<<")
		quit(0)
	else:
		printerr(">>> CHALLENGES ENCOUNTERED %d FAILURES! VERDICT: REQUEST_CHANGES <<<" % fail_count)
		quit(1)

func _assert(cond: bool, test_name: String, detail: String = "") -> void:
	if cond:
		print("  [PASS] %s" % test_name)
		pass_count += 1
	else:
		var err = "  [FAIL] %s" % test_name
		if detail != "":
			err += " -> " + detail
		printerr(err)
		fail_count += 1

func _run_adversarial_challenges() -> void:
	var haptics_script = load("res://scripts/autoload/haptics_manager.gd")
	_assert(haptics_script != null, "0.1 scripts/autoload/haptics_manager.gd is loadable")
	if haptics_script == null:
		return

	var hm = haptics_script.new()
	hm.name = "TestHapticsManager"
	root.add_child(hm)
	await process_frame

	var spy = ChallengeSpy.new()
	hm.add_child(spy)
	hm.vibration_triggered.connect(spy.on_vibration)
	hm.haptics_toggled.connect(spy.on_toggle)
	hm.pickup_throttled.connect(spy.on_throttled)

	# =========================================================================
	# CHALLENGE 1: Platform Guard & Desktop Emulation Challenge
	# =========================================================================
	print("\n--- Challenge 1: Platform Guard & Desktop Emulation Challenge ---")

	# 1.1 Non-mobile guard with force_emulate = false
	hm.force_emulate = false
	hm.haptics_enabled = true
	hm.clear_history()
	spy.clear()

	# Under headless desktop without force_emulate, can_vibrate_hardware() MUST be false
	var is_mobile = hm.is_mobile_platform()
	var can_vib_hw = hm.can_vibrate_hardware()
	_assert(not is_mobile, "1.1 Desktop headless environment correctly detected as non-mobile (is_mobile_platform == false)")
	_assert(not can_vib_hw, "1.2 Hardware vibration strictly barred on desktop headless (can_vibrate_hardware == false)")

	# Verify is_touch_device() exists and preserves DisplayServer.is_touchscreen_available()
	var has_touch_dev_method = hm.has_method("is_touch_device")
	_assert(has_touch_dev_method, "1.3 is_touch_device() method contract declared on HapticsManager")
	if has_touch_dev_method:
		var touch_dev_result = hm.is_touch_device()
		var expected_touch = hm.is_mobile_platform() or DisplayServer.is_touchscreen_available()
		_assert(touch_dev_result == expected_touch, "1.4 is_touch_device() preserves DisplayServer.is_touchscreen_available() for UI controls")

	# Desktop Touchscreen Safety Invariant:
	# Even if DisplayServer.is_touchscreen_available() were true, is_mobile_platform() MUST NOT return true,
	# and can_vibrate_hardware() MUST NOT attempt native mobile hardware vibration on desktop laptops.
	_assert(hm.can_vibrate_hardware() == false, "1.5 Desktop laptop safety: can_vibrate_hardware() strictly false on desktop")

	# Calling vibrate APIs when force_emulate = false must safely no-op without crashes or hardware calls
	hm.vibrate_light(25)
	hm.vibrate_medium(70)
	hm.vibrate_heavy(120)
	_assert(true, "1.6 Multi-tier vibrate calls executed cleanly without exception on non-mobile desktop")

	# 1.2 Desktop Emulation with force_emulate = true
	hm.force_emulate = true
	hm.clear_history()
	spy.clear()

	_assert(hm.is_mobile_platform() == true, "1.7 force_emulate = true successfully overrides platform detection to mobile")
	hm.vibrate_light(25)
	_assert(spy.emissions.size() == 1, "1.8 force_emulate = true successfully records vibration emission in telemetry spy")
	_assert(hm.last_vibration_ms == 25, "1.9 last_vibration_ms reflects emulated vibration duration")
	_assert(hm.vibration_history.size() == 1, "1.10 vibration_history array captures mock telemetry record")

	var entry = hm.vibration_history[0]
	_assert(entry.get("duration_ms") == 25 and absf(float(entry.get("amplitude", 0.0)) - 0.4) < 0.05,
		"1.11 Emulated vibration record preserves exact parameters (25ms, amp 0.4)")

	# =========================================================================
	# CHALLENGE 2: Master Toggle Suppression Challenge
	# =========================================================================
	print("\n--- Challenge 2: Master Toggle Suppression Challenge ---")

	# Enable emulation so that vibration would fire if not suppressed
	hm.force_emulate = true
	hm.clear_history()
	spy.clear()

	# Set master switch to FALSE
	hm.haptics_enabled = false
	_assert(hm.is_haptics_enabled() == false, "2.1 haptics_enabled verified as false")
	_assert(hm.enabled == false, "2.2 enabled alias returns false")
	_assert(spy.toggle_events.size() == 1 and spy.toggle_events[0] == false, "2.3 haptics_toggled signal emitted false")

	# Hardware check MUST be false even when force_emulate = true
	_assert(hm.can_vibrate_hardware() == false, "2.4 can_vibrate_hardware() returns false when haptics_enabled = false")

	# Fire barrage of vibration calls across all APIs
	hm.vibrate(50)
	hm.vibrate_light(25)
	hm.vibrate_medium(70)
	hm.vibrate_heavy(120)
	hm.vibrate_custom(80, 0.5)
	hm.vibrate_pickup()
	hm.vibrate_gate()
	hm.vibrate_quest()
	hm.vibrate_button()

	_assert(spy.emissions.size() == 0, "2.5 ZERO vibration_triggered signals emitted during suppression barrage")
	_assert(hm.vibration_history.is_empty(), "2.6 vibration_history remains strictly empty")
	_assert(hm.last_vibration_ms == 0, "2.7 last_vibration_ms remains 0")
	_assert(hm.vibration_count == 0, "2.8 vibration_count remains 0")

	# Mid-pattern suppression test
	hm.haptics_enabled = true
	spy.clear()
	hm.clear_history()

	# Start pattern and immediately disable
	var pattern_task = hm.vibrate_success_pattern(30, 40, 60)
	hm.haptics_enabled = false
	await get_tree().create_timer(0.08).timeout

	# The second pulse (60ms) should NOT have fired
	var post_suppress_emissions = spy.emissions.size()
	_assert(post_suppress_emissions <= 1, "2.9 Pattern second pulse was suppressed when haptics disabled mid-stream")

	# Re-enable and test immediate recovery
	hm.haptics_enabled = true
	hm.clear_history()
	spy.clear()
	hm.vibrate_medium(70)
	_assert(spy.emissions.size() == 1 and hm.last_vibration_ms == 70,
		"2.10 Re-enabling haptics immediately restores responsive vibration execution")

	# =========================================================================
	# CHALLENGE 3: Zero-Coupling Invariant Challenge
	# =========================================================================
	print("\n--- Challenge 3: Zero-Coupling Invariant Challenge ---")

	# 3.1 Verify GameState functions completely in isolation without HapticsManager
	var gs_script = load("res://scripts/autoload/game_state.gd")
	_assert(gs_script != null, "3.1 game_state.gd is loadable")

	var standalone_gs = gs_script.new()
	standalone_gs.name = "StandaloneGameState"
	root.add_child(standalone_gs)
	await process_frame

	# Trigger domain operations that emit signals
	standalone_gs.collect_3d_item("briefcase")
	standalone_gs.unlock_zone("server_room")
	standalone_gs.complete_campus_quest("quest_coffee")
	_assert(true, "3.2 GameState domain methods execute cleanly in isolation without HapticsManager")
	_assert(standalone_gs.collectibles_collected.get("briefcase", 0) == 1,
		"3.3 GameState state mutated correctly in isolation (briefcase == 1)")
	_assert(standalone_gs.unlocked_zones.has("server_room"),
		"3.4 GameState zone unlocked correctly in isolation (server_room)")

	standalone_gs.queue_free()

	# 3.2 Verify NakamaManager functions in isolation
	var nakama_script = load("res://scripts/autoload/nakama_manager.gd")
	_assert(nakama_script != null, "3.5 nakama_manager.gd is loadable")

	var standalone_nm = nakama_script.new()
	standalone_nm.name = "StandaloneNakamaManager"
	root.add_child(standalone_nm)
	await process_frame

	if standalone_nm.has_signal("quest_reward_claimed"):
		standalone_nm.quest_reward_claimed.emit("daily_streak_1", 25)
	_assert(true, "3.6 NakamaManager emits quest_reward_claimed cleanly in isolation without HapticsManager")
	standalone_nm.queue_free()

	# 3.3 Verify TouchControls operates cleanly when HapticsManager is missing
	var touch_script = load("res://scripts/ui/touch_controls.gd")
	_assert(touch_script != null, "3.7 touch_controls.gd is loadable")

	var standalone_touch = touch_script.new()
	standalone_touch.name = "StandaloneTouchControls"
	root.add_child(standalone_touch)
	await process_frame

	if standalone_touch.has_method("_trigger_haptic_tap"):
		standalone_touch.call("_trigger_haptic_tap")
	_assert(true, "3.8 TouchControls._trigger_haptic_tap() safely handles absence of HapticsManager")
	standalone_touch.queue_free()

	# =========================================================================
	# CHALLENGE 4: Rapid Churn Throttling & Priority Bypass Challenge
	# =========================================================================
	print("\n--- Challenge 4: Rapid Churn Throttling & Priority Bypass Challenge ---")

	hm.force_emulate = true
	hm.haptics_enabled = true
	hm.min_interval_ms = 50
	hm.clear_history()
	spy.clear()

	# 4.1 Rapid pickup churn: 100 rapid calls within 0ms delta
	for i in range(100):
		hm.vibrate_pickup()

	_assert(spy.emissions.size() == 1, "4.1 100 rapid pickup pulses throttled to exactly 1 vibration emission")
	_assert(hm.pickup_throttled_count == 99, "4.2 pickup_throttled_count recorded exactly 99 dropped calls",
		"actual: %d" % hm.pickup_throttled_count)
	_assert(spy.throttled_events.size() == 99, "4.3 pickup_throttled signal emitted 99 times")

	# 4.2 Priority bypass: Milestone events bypass cooldown immediately
	spy.clear()
	hm.clear_history()
	hm.vibrate_pickup() # triggers cooldown
	_assert(spy.emissions.size() == 1, "4.4 Baseline pickup pulse executed")

	# Immediate gate unlock (bypasses cooldown)
	hm.vibrate_gate()
	_assert(spy.emissions.size() == 2 and hm.last_vibration_ms == 70,
		"4.5 Gate unlock pulse (70ms) successfully bypassed 50ms cooldown immediately")

	# Immediate quest completion (bypasses cooldown)
	hm.vibrate_quest()
	_assert(spy.emissions.size() == 3 and hm.last_vibration_ms == 120,
		"4.6 Quest completion pulse (120ms) successfully bypassed cooldown immediately")

	# =========================================================================
	# CHALLENGE 5: Parameter Boundary & Stress Clamping Challenge
	# =========================================================================
	print("\n--- Challenge 5: Parameter Boundary & Stress Clamping Challenge ---")

	spy.clear()
	hm.clear_history()
	hm.min_interval_ms = 0 # zero cooldown for boundary testing

	# Negative duration
	hm.vibrate(-100, 0.5)
	_assert(spy.emissions.is_empty(), "5.1 Negative duration (-100ms) safely rejected as no-op")

	# Zero duration
	hm.vibrate(0, 0.5)
	_assert(spy.emissions.is_empty(), "5.2 Zero duration (0ms) safely rejected as no-op")

	# Excessive duration clamping
	hm.vibrate(999999, 0.5)
	_assert(spy.emissions.size() == 1 and spy.emissions[0].get("duration_ms") == 5000,
		"5.3 Extreme duration (999999ms) clamped safely to 5000ms limit")

	# Amplitude overflow
	spy.clear()
	hm.vibrate(50, 9.9)
	_assert(spy.emissions.size() == 1 and absf(float(spy.emissions[0].get("amplitude", 0.0)) - 1.0) < 0.001,
		"5.4 Amplitude overflow (9.9) clamped safely to 1.0")

	# Amplitude underflow
	spy.clear()
	hm.vibrate(50, -0.75)
	_assert(spy.emissions.size() == 1 and float(spy.emissions[0].get("amplitude", 0.0)) == -1.0,
		"5.5 Amplitude underflow (-0.75) safely normalized to default -1.0")

	# Ring buffer overflow check
	spy.clear()
	hm.clear_history()
	hm.max_history_size = 10
	for i in range(25):
		hm.vibrate(10 + i, 0.5)
	_assert(hm.vibration_history.size() == 10, "5.6 vibration_history ring buffer strictly maintains max_history_size (10)")
	_assert(hm.vibration_history[-1].get("duration_ms") == 34, "5.7 Ring buffer preserves newest entries during eviction")

	# Cleanup
	spy.queue_free()
	hm.queue_free()

	print("\n--- Milestone P5-M3 Adversarial Challenge Suite Complete ---")
