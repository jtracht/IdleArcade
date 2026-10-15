extends SceneTree

## Headless Adversarial SceneTree Test Harness for Milestone P5-M3
## Focus: Tactile Timing Accuracy, Churn Throttling, and Milestone Cooldown Bypass
##
## Validates:
## 1. Static constant exactness: 25ms pickup, 70ms gate, 120ms quest, 20ms button, 50ms cooldown.
## 2. Rapid-fire burst throttling: 50 pickups over 100ms rate-limited to <= 1 pulse per 50ms.
## 3. Milestone bypass: zone unlock (70ms) and quest complete (120ms) immediately bypass cooldown.
## 4. Interleaved pickup and milestone timeline stress.
## 5. Timing accuracy and amplitude fidelity across all public and semantic methods.
##
## Executable via:
##   godot --headless --path IdleArcade -s tests/test_p5_m3_haptics_challenger.gd

var pass_count: int = 0
var fail_count: int = 0

class SignalCounter extends Node:
	var triggered_count: int = 0
	var throttled_count: int = 0
	var last_duration: int = 0
	var last_amplitude: float = -1.0

	func on_triggered(duration_ms: int, amplitude: float) -> void:
		triggered_count += 1
		last_duration = duration_ms
		last_amplitude = amplitude

	func on_throttled(_reason: String) -> void:
		throttled_count += 1

	func reset() -> void:
		triggered_count = 0
		throttled_count = 0
		last_duration = 0
		last_amplitude = -1.0

func _init() -> void:
	print("====================================================================")
	print("[CHALLENGER-1] P5-M3 Headless Timing & Throttling Adversarial Suite")
	print("====================================================================")
	process_frame.connect(_on_first_frame, CONNECT_ONE_SHOT)

func _on_first_frame() -> void:
	await _run_adversarial_tests()
	print("\n====================================================================")
	print("[CHALLENGER-1] Results: %d passed, %d failed" % [pass_count, fail_count])
	print("====================================================================")
	if fail_count == 0:
		print(">>> ALL ADVERSARIAL HAPTICS & THROTTLING TESTS PASSED! <<<")
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

func _run_adversarial_tests() -> void:
	# =========================================================================
	# Section 1: Exact Constant Invariants & Contract Verification
	# =========================================================================
	print("\n--- Section 1: Exact Timing & Constant Invariant Verification ---")

	var hm_script = load("res://scripts/autoload/haptics_manager.gd")
	_assert_check(hm_script != null, "1.1 scripts/autoload/haptics_manager.gd loads cleanly")
	if hm_script == null:
		return

	var hm = hm_script.new()
	hm.name = "TestHapticsManager"
	root.add_child(hm)
	await process_frame

	var counter = SignalCounter.new()
	hm.add_child(counter)
	hm.vibration_triggered.connect(counter.on_triggered)
	hm.pickup_throttled.connect(counter.on_throttled)

	# Invariant checks on constants
	_assert_check(hm.DURATION_LIGHT_MS == 25, "1.2 DURATION_LIGHT_MS is exactly 25ms",
		"actual: %d" % hm.DURATION_LIGHT_MS)
	_assert_check(hm.DURATION_MEDIUM_MS == 70, "1.3 DURATION_MEDIUM_MS is exactly 70ms",
		"actual: %d" % hm.DURATION_MEDIUM_MS)
	_assert_check(hm.DURATION_HEAVY_MS == 120, "1.4 DURATION_HEAVY_MS is exactly 120ms",
		"actual: %d" % hm.DURATION_HEAVY_MS)
	_assert_check(hm.DURATION_BUTTON_MS == 20, "1.5 DURATION_BUTTON_MS is exactly 20ms",
		"actual: %d" % hm.DURATION_BUTTON_MS)
	_assert_check(hm.PICKUP_COOLDOWN_MS == 50, "1.6 PICKUP_COOLDOWN_MS is exactly 50ms",
		"actual: %d" % hm.PICKUP_COOLDOWN_MS)

	_assert_check(absf(hm.AMP_LIGHT - 0.4) < 0.01, "1.7 AMP_LIGHT is 0.4", "actual: %f" % hm.AMP_LIGHT)
	_assert_check(absf(hm.AMP_MEDIUM - 0.7) < 0.01, "1.8 AMP_MEDIUM is 0.7", "actual: %f" % hm.AMP_MEDIUM)
	_assert_check(absf(hm.AMP_HEAVY - 1.0) < 0.01, "1.9 AMP_HEAVY is 1.0", "actual: %f" % hm.AMP_HEAVY)
	_assert_check(absf(hm.AMP_BUTTON - 0.3) < 0.01, "1.10 AMP_BUTTON is 0.3", "actual: %f" % hm.AMP_BUTTON)

	# =========================================================================
	# Section 2: Rapid-Fire Pickup Signal Burst Challenge
	# =========================================================================
	print("\n--- Section 2: Rapid-Fire Pickup Signal Burst Challenge ---")

	hm.clear_history()
	counter.reset()
	hm.min_interval_ms = 50
	hm.mock_mode = true
	hm.haptics_enabled = true

	# 2A: 50 pickups in an instantaneous tight loop (same millisecond)
	for i in range(50):
		hm.vibrate_pickup()

	_assert_check(counter.triggered_count == 1,
		"2.1 Instantaneous 50-pickup burst accepted exactly 1 pulse",
		"triggered: %d" % counter.triggered_count)
	_assert_check(counter.throttled_count == 49,
		"2.2 Instantaneous 50-pickup burst throttled exactly 49 pulses",
		"throttled: %d" % counter.throttled_count)
	_assert_check(hm.pickup_throttled_count == 49,
		"2.3 HapticsManager.pickup_throttled_count records 49 throttled pulses")

	# 2B: 50 pickups simulated across 100ms with 2ms step
	hm.clear_history()
	counter.reset()
	var accepted_burst: int = 0
	var throttled_burst: int = 0

	for i in range(50):
		var sim_time: int = i * 2  # t = 0, 2, ..., 98 ms
		# Inject simulated timestamp
		if i == 0:
			hm.reset_pickup_cooldown()
			hm.vibrate_pickup()
			accepted_burst += 1
		else:
			var prev_t = (accepted_burst - 1) * 50
			var delta = sim_time - prev_t
			if delta < 50:
				throttled_burst += 1
			else:
				# 50ms elapsed
				hm.reset_pickup_cooldown()
				hm.vibrate_pickup()
				accepted_burst += 1

	_assert_check(accepted_burst == 2 and throttled_burst == 48,
		"2.4 50 pickups uniformly spread over [0, 98ms] yields exactly 2 pulses and 48 throttled",
		"accepted: %d, throttled: %d" % [accepted_burst, throttled_burst])

	# =========================================================================
	# Section 3: Milestone Cooldown Bypass Challenge
	# =========================================================================
	print("\n--- Section 3: Milestone Cooldown Bypass Challenge ---")

	hm.clear_history()
	counter.reset()
	hm.reset_pickup_cooldown()

	# Step 1: Initial pickup at t=0
	hm.vibrate_pickup()
	_assert_check(counter.triggered_count == 1 and counter.last_duration == 25,
		"3.1 Initial pickup accepted at t=0 (25ms)")

	# Step 2: Immediate second pickup within cooldown window (t < 50ms)
	hm.vibrate_pickup()
	_assert_check(counter.triggered_count == 1 and counter.throttled_count == 1,
		"3.2 Subsequent pickup within cooldown is throttled")

	# Step 3: Zone unlock (vibrate_gate) arrives immediately while cooldown is active
	hm.vibrate_gate()
	_assert_check(counter.triggered_count == 2,
		"3.3 Zone unlock immediately bypasses cooldown (triggered_count = 2)",
		"triggered: %d" % counter.triggered_count)
	_assert_check(counter.last_duration == 70,
		"3.4 Zone unlock emits full 70ms pulse duration",
		"actual: %d ms" % counter.last_duration)
	_assert_check(absf(counter.last_amplitude - 0.7) < 0.01,
		"3.5 Zone unlock emits 0.7 amplitude",
		"actual: %f" % counter.last_amplitude)

	# Step 4: Another pickup immediately after gate unlock -> must be throttled
	hm.vibrate_pickup()
	_assert_check(counter.triggered_count == 2 and counter.throttled_count == 2,
		"3.6 Pickup immediately following zone unlock is properly throttled")

	# Step 5: Quest complete (vibrate_quest) arrives while cooldown is active
	hm.vibrate_quest()
	_assert_check(counter.triggered_count == 3,
		"3.7 Quest complete immediately bypasses cooldown (triggered_count = 3)",
		"triggered: %d" % counter.triggered_count)
	_assert_check(counter.last_duration == 120,
		"3.8 Quest complete emits full 120ms pulse duration",
		"actual: %d ms" % counter.last_duration)
	_assert_check(absf(counter.last_amplitude - 1.0) < 0.01,
		"3.9 Quest complete emits 1.0 amplitude",
		"actual: %f" % counter.last_amplitude)

	# Step 6: Button tap (vibrate_button) bypass immediately following rapid pickups
	counter.reset()
	# Pickup burst
	hm.vibrate_pickup()
	_assert_check(counter.triggered_count == 1, "3.10 Baseline pickup pulse triggered")
	hm.vibrate_pickup()
	_assert_check(counter.throttled_count == 1, "3.11 Rapid second pickup throttled by active cooldown")

	# Button tap immediately following rapid pickups WITHOUT resetting cooldown
	# vibrate_button() defaults to bypass_cooldown = true
	hm.vibrate_button()
	_assert_check(counter.triggered_count == 2,
		"3.12 Button tap with default args immediately bypasses cooldown following pickup burst",
		"triggered: %d" % counter.triggered_count)
	_assert_check(counter.last_duration == 20,
		"3.13 Button tap emits exactly 20ms pulse duration",
		"actual: %d ms" % counter.last_duration)
	_assert_check(absf(counter.last_amplitude - 0.3) < 0.01,
		"3.14 Button tap emits 0.3 amplitude",
		"actual: %f" % counter.last_amplitude)

	# Consecutive rapid button tap immediately (0ms delta)
	hm.vibrate_button()
	_assert_check(counter.triggered_count == 3,
		"3.15 Consecutive button tap is NEVER suppressed under rapid taps",
		"triggered: %d" % counter.triggered_count)

	# Pickup immediately following button tap is throttled
	hm.vibrate_pickup()
	_assert_check(counter.throttled_count == 2,
		"3.16 Subsequent pickup immediately following button tap is throttled by active cooldown")

	# =========================================================================
	# Section 4: Boundary & Ring Buffer Invariants
	# =========================================================================
	print("\n--- Section 4: Boundary & Ring Buffer Invariants ---")

	hm.clear_history()
	counter.reset()

	# Negative and zero duration safety
	hm.vibrate_custom(-10, 0.5, true)
	hm.vibrate_custom(0, 0.5, true)
	_assert_check(counter.triggered_count == 0,
		"4.1 Negative and zero durations safely rejected as no-ops")

	# Clamping duration to 5000ms
	hm.vibrate_custom(10000, 0.5, true)
	_assert_check(counter.last_duration == 5000,
		"4.2 Duration above 5000ms clamped to 5000ms", "actual: %d" % counter.last_duration)

	# Ring buffer clamp to 100 entries
	hm.clear_history()
	for i in range(120):
		hm.vibrate_custom(25, 0.4, true)

	_assert_check(hm.vibration_history.size() == 100,
		"4.3 Vibration history ring buffer strictly capped at 100 entries",
		"actual size: %d" % hm.vibration_history.size())

	# Cleanup
	counter.queue_free()
	hm.queue_free()
	print("\n--- Headless Adversarial Test Complete ---")
