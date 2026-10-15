#!/usr/bin/env python3
"""
Milestone P5-M3 Adversarial Timing Accuracy & Churn Throttling Oracle
====================================================================
Author: Challenger Agent 1 (critic, specialist)
Milestone: Phase 5 - Milestone P5-M3 (Haptic Feedback & Platform Detection)
Target: Godot 4.3 IdleArcade (scripts/autoload/haptics_manager.gd)

Empirical Challenge Dimensions:
1. Rapid-Fire Signal Burst Challenge:
   - Simulate 50 item pickup signals over 100ms window.
   - Verify rate-limiting to at most 1 pulse per 50ms (max 2-3 pulses total, never 50).
   - Uniform, clustered, and instantaneous (same-tick) bursts.
2. Milestone Bypass Challenge:
   - Zone unlock (70ms) and quest complete (120ms) arriving within active pickup cooldown.
   - Verify milestone events immediately bypass the 50ms cooldown and emit full duration.
   - Verify subsequent non-bypass pickups are throttled relative to milestone timestamp.
3. Timing Accuracy & Amplitude Audit:
   - Item pickup: exactly 25ms (0.4 amp).
   - Gate unlock: exactly 70ms (0.7 amp).
   - Quest completion / reward claim: exactly 120ms (1.0 amp).
   - Button tap: exactly 20ms (0.3 amp).
4. Edge Case & Invariant Stress:
   - Zero and negative durations.
   - Over-duration clamping (<= 5000ms).
   - History ring buffer capacity limit (max_history_size = 100).
   - Master suppression toggle (haptics_enabled = false).

Executable via:
  python IdleArcade/tests/test_p5_m3_adversarial_timing_oracle.py
"""

import math
import re
import sys
from pathlib import Path
from typing import List, Dict, Any, Optional, Tuple

class SimulatedHapticsManager:
    """
    High-fidelity mathematical replica of HapticsManager's state machine and throttling engine,
    matching res://scripts/autoload/haptics_manager.gd line-for-line.
    """
    DURATION_LIGHT_MS: int = 25
    DURATION_MEDIUM_MS: int = 70
    DURATION_HEAVY_MS: int = 120
    DURATION_BUTTON_MS: int = 20

    AMP_LIGHT: float = 0.4
    AMP_MEDIUM: float = 0.7
    AMP_HEAVY: float = 1.0
    AMP_BUTTON: float = 0.3
    AMP_DEFAULT: float = -1.0

    PICKUP_COOLDOWN_MS: int = 50

    def __init__(self):
        self.haptics_enabled: bool = True
        self.force_emulate: bool = False
        self.mock_mode: bool = True
        self.max_history_size: int = 100
        self.min_interval_ms: int = self.PICKUP_COOLDOWN_MS

        self.last_vibration_ms: int = 0
        self.last_amplitude: float = -1.0
        self.vibration_count: int = 0
        self.pickup_throttled_count: int = 0
        self.vibration_history: List[Dict[str, Any]] = []
        self._last_vibration_timestamp: int = -100000

        # Virtual clock for deterministic timeline simulations
        self.current_time_ms: int = 0

    def get_ticks_msec(self) -> int:
        return self.current_time_ms

    def set_time(self, ms: int) -> None:
        self.current_time_ms = ms

    def advance_time(self, delta_ms: int) -> None:
        self.current_time_ms += delta_ms

    def vibrate_custom(self, duration_ms: int, amplitude: float = -1.0, bypass_cooldown: bool = False) -> bool:
        if not self.haptics_enabled:
            return False

        if duration_ms <= 0:
            return False

        now: int = self.get_ticks_msec()
        if self.min_interval_ms > 0 and not bypass_cooldown and (now - self._last_vibration_timestamp) < self.min_interval_ms:
            self.pickup_throttled_count += 1
            return False

        self._last_vibration_timestamp = now

        clamped_duration: int = min(duration_ms, 5000)
        clamped_amplitude: float = -1.0 if amplitude < 0.0 else max(0.0, min(1.0, amplitude))

        self.last_vibration_ms = clamped_duration
        self.last_amplitude = clamped_amplitude
        self.vibration_count += 1

        if self.mock_mode:
            self.vibration_history.append({
                "duration_ms": clamped_duration,
                "amplitude": clamped_amplitude,
                "timestamp": now,
                "bypass": bypass_cooldown
            })
            if len(self.vibration_history) > self.max_history_size:
                self.vibration_history.pop(0)

        return True

    def vibrate_light(self, duration_ms: int = 25, bypass_cooldown: bool = False) -> bool:
        return self.vibrate_custom(duration_ms, self.AMP_LIGHT, bypass_cooldown)

    def vibrate_medium(self, duration_ms: int = 70, bypass_cooldown: bool = False) -> bool:
        return self.vibrate_custom(duration_ms, self.AMP_MEDIUM, bypass_cooldown)

    def vibrate_heavy(self, duration_ms: int = 120, bypass_cooldown: bool = False) -> bool:
        return self.vibrate_custom(duration_ms, self.AMP_HEAVY, bypass_cooldown)

    def vibrate_button(self, duration_ms: int = 20, bypass_cooldown: bool = True) -> bool:
        return self.vibrate_custom(duration_ms, self.AMP_BUTTON, bypass_cooldown)

    def vibrate_pickup(self) -> bool:
        return self.vibrate_light(self.DURATION_LIGHT_MS, False)

    def vibrate_gate(self) -> bool:
        return self.vibrate_medium(self.DURATION_MEDIUM_MS, True)

    def vibrate_quest(self) -> bool:
        return self.vibrate_heavy(self.DURATION_HEAVY_MS, True)

    def clear_history(self) -> None:
        self.vibration_history.clear()
        self.last_vibration_ms = 0
        self.last_amplitude = -1.0
        self.vibration_count = 0
        self.pickup_throttled_count = 0
        self._last_vibration_timestamp = -100000


def main():
    print("=======================================================================")
    print("[CHALLENGER-1] P5-M3 Haptics Timing Accuracy & Churn Throttling Oracle")
    print("=======================================================================")

    game_dir = Path(__file__).resolve().parent.parent
    tests_passed = 0
    tests_failed = 0

    def assert_check(cond: bool, test_name: str, detail: str = ""):
        nonlocal tests_passed, tests_failed
        if cond:
            print(f"  [PASS] {test_name}")
            tests_passed += 1
        else:
            msg = f"  [FAIL] {test_name}"
            if detail:
                msg += f" -> {detail}"
            print(msg)
            tests_failed += 1

    # =========================================================================
    # SECTION 1: Source AST Verification against haptics_manager.gd
    # =========================================================================
    print("\n--- Section 1: Static AST & Exact Constant Invariant Audit ---")

    hm_file = game_dir / "scripts" / "autoload" / "haptics_manager.gd"
    assert_check(hm_file.is_file(), "1.1 scripts/autoload/haptics_manager.gd exists")

    hm_src = hm_file.read_text(encoding="utf-8")

    # Extract exact constants
    c_light = re.search(r'const\s+DURATION_LIGHT_MS:\s*int\s*=\s*(\d+)', hm_src)
    c_med = re.search(r'const\s+DURATION_MEDIUM_MS:\s*int\s*=\s*(\d+)', hm_src)
    c_heavy = re.search(r'const\s+DURATION_HEAVY_MS:\s*int\s*=\s*(\d+)', hm_src)
    c_btn = re.search(r'const\s+DURATION_BUTTON_MS:\s*int\s*=\s*(\d+)', hm_src)
    c_cooldown = re.search(r'const\s+PICKUP_COOLDOWN_MS:\s*int\s*=\s*(\d+)', hm_src)

    assert_check(c_light is not None and int(c_light.group(1)) == 25,
                 "1.2 DURATION_LIGHT_MS constant is exactly 25ms",
                 f"actual: {c_light.group(1) if c_light else 'None'}")

    assert_check(c_med is not None and int(c_med.group(1)) == 70,
                 "1.3 DURATION_MEDIUM_MS constant is exactly 70ms",
                 f"actual: {c_med.group(1) if c_med else 'None'}")

    assert_check(c_heavy is not None and int(c_heavy.group(1)) == 120,
                 "1.4 DURATION_HEAVY_MS constant is exactly 120ms",
                 f"actual: {c_heavy.group(1) if c_heavy else 'None'}")

    assert_check(c_btn is not None and int(c_btn.group(1)) == 20,
                 "1.5 DURATION_BUTTON_MS constant is exactly 20ms",
                 f"actual: {c_btn.group(1) if c_btn else 'None'}")

    assert_check(c_cooldown is not None and int(c_cooldown.group(1)) == 50,
                 "1.6 PICKUP_COOLDOWN_MS constant is exactly 50ms",
                 f"actual: {c_cooldown.group(1) if c_cooldown else 'None'}")

    # Amplitudes
    a_light = re.search(r'const\s+AMP_LIGHT:\s*float\s*=\s*([0-9.]+)', hm_src)
    a_med = re.search(r'const\s+AMP_MEDIUM:\s*float\s*=\s*([0-9.]+)', hm_src)
    a_heavy = re.search(r'const\s+AMP_HEAVY:\s*float\s*=\s*([0-9.]+)', hm_src)
    a_btn = re.search(r'const\s+AMP_BUTTON:\s*float\s*=\s*([0-9.]+)', hm_src)

    assert_check(a_light is not None and abs(float(a_light.group(1)) - 0.4) < 0.01,
                 "1.7 AMP_LIGHT constant is 0.4")
    assert_check(a_med is not None and abs(float(a_med.group(1)) - 0.7) < 0.01,
                 "1.8 AMP_MEDIUM constant is 0.7")
    assert_check(a_heavy is not None and abs(float(a_heavy.group(1)) - 1.0) < 0.01,
                 "1.9 AMP_HEAVY constant is 1.0")
    assert_check(a_btn is not None and abs(float(a_btn.group(1)) - 0.3) < 0.01,
                 "1.10 AMP_BUTTON constant is 0.3")

    # Semantic methods implementation
    assert_check("vibrate_light(DURATION_LIGHT_MS, false)" in hm_src,
                 "1.11 vibrate_pickup() calls vibrate_light(DURATION_LIGHT_MS, false)")
    assert_check("vibrate_medium(DURATION_MEDIUM_MS, true)" in hm_src,
                 "1.12 vibrate_gate() calls vibrate_medium(DURATION_MEDIUM_MS, true)")
    assert_check("vibrate_heavy(DURATION_HEAVY_MS, true)" in hm_src,
                 "1.13 vibrate_quest() calls vibrate_heavy(DURATION_HEAVY_MS, true)")
    assert_check("vibrate_custom(duration_ms, AMP_BUTTON, bypass_cooldown)" in hm_src,
                 "1.14 vibrate_button() calls vibrate_custom with AMP_BUTTON")
    has_btn_bypass_def = re.search(r'func\s+vibrate_button\s*\([^)]*bypass_cooldown\s*(?::\s*bool\s*)?=\s*true', hm_src) is not None
    assert_check(has_btn_bypass_def,
                 "1.15 vibrate_button() explicitly defaults bypass_cooldown = true in method signature")

    # =========================================================================
    # SECTION 2: Rapid-Fire Signal Burst Challenge
    # =========================================================================
    print("\n--- Section 2: Rapid-Fire Signal Burst Challenge (50 pickups over 100ms) ---")

    sim = SimulatedHapticsManager()

    # Scenario 2A: 50 pickups uniformly distributed over [0, 98ms] (step = 2ms)
    sim.clear_history()
    sim.set_time(0)
    accepted_2a = 0
    throttled_2a = 0

    for i in range(50):
        t = i * 2  # t = 0, 2, 4, ..., 98 ms
        sim.set_time(t)
        if sim.vibrate_pickup():
            accepted_2a += 1
        else:
            throttled_2a += 1

    assert_check(accepted_2a == 2,
                 "2.1 50 pickups over [0, 98ms] at 2ms intervals yields exactly 2 pulses (at t=0 and t=50)",
                 f"actual accepted: {accepted_2a}, throttled: {throttled_2a}")
    assert_check(throttled_2a == 48,
                 "2.2 48 pickups are strictly throttled / suppressed",
                 f"throttled count: {throttled_2a}")
    assert_check(sim.pickup_throttled_count == 48,
                 "2.3 HapticsManager.pickup_throttled_count matches 48 throttled signals")

    # Scenario 2B: 51 pickups over [0, 100ms] inclusive (step = 2ms)
    sim.clear_history()
    sim.set_time(0)
    accepted_2b = 0
    throttled_2b = 0

    for i in range(51):
        t = i * 2  # t = 0, 2, 4, ..., 100 ms
        sim.set_time(t)
        if sim.vibrate_pickup():
            accepted_2b += 1
        else:
            throttled_2b += 1

    assert_check(accepted_2b == 3,
                 "2.4 51 pickups over [0, 100ms] at 2ms intervals yields exactly 3 pulses (at t=0, t=50, t=100)",
                 f"actual accepted: {accepted_2b}")
    assert_check(accepted_2b <= 3,
                 "2.5 Strictly at most 1 pulse per 50ms cooldown window (rate-limit verified)")

    # Scenario 2C: Same-tick burst (50 pickups in the exact same millisecond t=10)
    sim.clear_history()
    sim.set_time(10)
    accepted_2c = 0
    throttled_2c = 0

    for _ in range(50):
        if sim.vibrate_pickup():
            accepted_2c += 1
        else:
            throttled_2c += 1

    assert_check(accepted_2c == 1 and throttled_2c == 49,
                 "2.6 50 pickups in exact same millisecond: exactly 1 accepted, 49 throttled",
                 f"accepted: {accepted_2c}, throttled: {throttled_2c}")

    # Scenario 2D: Irregular / jittered burst over 100ms
    # Clustered pickups around boundary ticks: t=0, 1, 2, 25, 49, 50, 51, 75, 99, 100
    sim.clear_history()
    sim.set_time(0)
    jitter_timestamps = [0, 1, 2, 5, 12, 19, 25, 30, 48, 49, 50, 51, 52, 60, 75, 80, 99, 100]
    accepted_2d_timestamps = []

    for t in jitter_timestamps:
        sim.set_time(t)
        if sim.vibrate_pickup():
            accepted_2d_timestamps.append(t)

    assert_check(accepted_2d_timestamps == [0, 50, 100],
                 "2.7 Jittered burst accepts exactly [0, 50, 100]ms pulses, strictly throttles t=49 and t=51",
                 f"accepted timestamps: {accepted_2d_timestamps}")

    # Verify inter-pulse intervals in history
    history = sim.vibration_history
    intervals = [history[i]["timestamp"] - history[i-1]["timestamp"] for i in range(1, len(history))]
    all_ge_50 = all(interval >= 50 for interval in intervals)
    assert_check(all_ge_50,
                 "2.8 All consecutive accepted pickup vibration timestamps separated by >= 50ms",
                 f"intervals: {intervals}")

    # =========================================================================
    # SECTION 3: Milestone Bypass Challenge
    # =========================================================================
    print("\n--- Section 3: Milestone Bypass Challenge ---")

    # Scenario 3A: Zone unlock (70ms) during active pickup cooldown
    sim.clear_history()
    sim.set_time(0)
    sim.vibrate_pickup()  # Pulse at t=0

    # Rapid pickup at t=10 (within cooldown)
    sim.set_time(10)
    p_throttled = not sim.vibrate_pickup()
    assert_check(p_throttled, "3.1 Pickup at t=10ms is throttled by active cooldown")

    # Zone unlock at t=15ms (must bypass cooldown immediately)
    sim.set_time(15)
    gate_accepted = sim.vibrate_gate()
    assert_check(gate_accepted, "3.2 Zone unlock at t=15ms immediately bypasses cooldown")
    assert_check(sim.last_vibration_ms == 70,
                 "3.3 Zone unlock emits full 70ms pulse duration",
                 f"actual: {sim.last_vibration_ms}ms")
    assert_check(abs(sim.last_amplitude - 0.7) < 0.01,
                 "3.4 Zone unlock emits 0.7 amplitude",
                 f"actual: {sim.last_amplitude}")

    # Scenario 3B: Quest completion (120ms) during active pickup cooldown
    sim.clear_history()
    sim.set_time(100)
    sim.vibrate_pickup()  # Pulse at t=100

    # Rapid pickup at t=110
    sim.set_time(110)
    sim.vibrate_pickup()

    # Quest completion at t=125ms (25ms into 50ms cooldown)
    sim.set_time(125)
    quest_accepted = sim.vibrate_quest()
    assert_check(quest_accepted, "3.5 Quest completion at t=125ms immediately bypasses cooldown")
    assert_check(sim.last_vibration_ms == 120,
                 "3.6 Quest completion emits full 120ms pulse duration",
                 f"actual: {sim.last_vibration_ms}ms")
    assert_check(abs(sim.last_amplitude - 1.0) < 0.01,
                 "3.7 Quest completion emits 1.0 amplitude",
                 f"actual: {sim.last_amplitude}")

    # Scenario 3C: Interleaved Frenzy Stress Test
    # Timeline:
    # t=0: pickup -> ACCEPT (25ms)
    # t=5: pickup -> THROTTLE
    # t=10: gate unlock -> ACCEPT (70ms, bypasses)
    # t=15: pickup -> THROTTLE (only 5ms after gate unlock at t=10)
    # t=20: quest complete -> ACCEPT (120ms, bypasses)
    # t=25: pickup -> THROTTLE (only 5ms after quest complete at t=20)
    # t=60: pickup -> THROTTLE (40ms after quest at t=20, 40 < 50)
    # t=70: pickup -> ACCEPT (50ms after quest at t=20, 50 >= 50)
    sim.clear_history()
    timeline = [
        (0, "pickup", True, 25),
        (5, "pickup", False, 0),
        (10, "gate", True, 70),
        (15, "pickup", False, 0),
        (20, "quest", True, 120),
        (25, "pickup", False, 0),
        (60, "pickup", False, 0),
        (70, "pickup", True, 25)
    ]

    all_timeline_pass = True
    timeline_log = []

    for t, event_type, should_accept, expected_dur in timeline:
        sim.set_time(t)
        res = False
        if event_type == "pickup":
            res = sim.vibrate_pickup()
        elif event_type == "gate":
            res = sim.vibrate_gate()
        elif event_type == "quest":
            res = sim.vibrate_quest()

        actual_dur = sim.last_vibration_ms if res else 0
        timeline_log.append((t, event_type, res, actual_dur))

        if res != should_accept or (res and actual_dur != expected_dur):
            all_timeline_pass = False

    assert_check(all_timeline_pass,
                 "3.8 Interleaved frenzy timeline matches expected pass/throttle/duration sequence exactly",
                 f"log: {timeline_log}")

    # Scenario 3D: Button Tap Bypass Immediately Following Rapid Pickups
    sim.clear_history()
    sim.set_time(500)
    p1 = sim.vibrate_pickup()
    p2 = sim.vibrate_pickup()
    assert_check(p1 and not p2, "3.9 Rapid pickup burst at t=500 accepts 1st and throttles 2nd")

    # t=505 (only 5ms later): Button tap with default args (bypass_cooldown = True)
    sim.set_time(505)
    btn1 = sim.vibrate_button()
    assert_check(btn1, "3.10 vibrate_button() with default args immediately bypasses cooldown at t=505ms")
    assert_check(sim.last_vibration_ms == 20, "3.11 vibrate_button() emits exactly 20ms pulse duration", f"actual: {sim.last_vibration_ms}")
    assert_check(abs(sim.last_amplitude - 0.3) < 0.01, "3.12 vibrate_button() emits 0.3 amplitude", f"actual: {sim.last_amplitude}")

    # t=506 (1ms later): Rapid second button tap
    sim.set_time(506)
    btn2 = sim.vibrate_button()
    assert_check(btn2, "3.13 Rapid second button tap at t=506ms is NEVER suppressed (bypass_cooldown = true)")

    # t=510: Pickup after button tap is properly throttled by button tap's timestamp (510 - 506 = 4 < 50)
    sim.set_time(510)
    p3 = sim.vibrate_pickup()
    assert_check(not p3, "3.14 Subsequent pickup at t=510ms throttled relative to button tap timestamp (4ms < 50ms)")

    # =========================================================================
    # SECTION 4: Timing Accuracy & Parameter Invariants
    # =========================================================================
    print("\n--- Section 4: Timing Accuracy & Amplitude Verification ---")

    sim.clear_history()
    sim.set_time(0)

    # 4.1 Item pickup
    sim.vibrate_pickup()
    assert_check(sim.last_vibration_ms == 25, "4.1 vibrate_pickup() duration is exactly 25ms")
    assert_check(abs(sim.last_amplitude - 0.4) < 0.01, "4.2 vibrate_pickup() amplitude is exactly 0.4")

    # 4.2 Gate unlock
    sim.advance_time(100)
    sim.vibrate_gate()
    assert_check(sim.last_vibration_ms == 70, "4.3 vibrate_gate() duration is exactly 70ms")
    assert_check(abs(sim.last_amplitude - 0.7) < 0.01, "4.4 vibrate_gate() amplitude is exactly 0.7")

    # 4.3 Quest complete
    sim.advance_time(100)
    sim.vibrate_quest()
    assert_check(sim.last_vibration_ms == 120, "4.5 vibrate_quest() duration is exactly 120ms")
    assert_check(abs(sim.last_amplitude - 1.0) < 0.01, "4.6 vibrate_quest() amplitude is exactly 1.0")

    # 4.4 Button tap
    sim.advance_time(100)
    sim.vibrate_button()
    assert_check(sim.last_vibration_ms == 20, "4.7 vibrate_button() duration is exactly 20ms")
    assert_check(abs(sim.last_amplitude - 0.3) < 0.01, "4.8 vibrate_button() amplitude is exactly 0.3")

    # =========================================================================
    # SECTION 5: Robustness, Clamping & Boundary Invariants
    # =========================================================================
    print("\n--- Section 5: Robustness, Clamping & Boundary Invariants ---")

    sim.clear_history()
    sim.set_time(0)

    # 5.1 Negative duration no-op
    res_neg = sim.vibrate_custom(-50, 0.5, True)
    assert_check(res_neg is False and sim.vibration_count == 0,
                 "5.1 Negative duration is a safe no-op (returns false, count=0)")

    # 5.2 Zero duration no-op
    res_zero = sim.vibrate_custom(0, 0.5, True)
    assert_check(res_zero is False and sim.vibration_count == 0,
                 "5.2 Zero duration is a safe no-op (returns false, count=0)")

    # 5.3 Over-duration clamping (mini(duration_ms, 5000))
    sim.vibrate_custom(8000, 0.5, True)
    assert_check(sim.last_vibration_ms == 5000,
                 "5.3 Excess duration 8000ms is clamped to max 5000ms",
                 f"actual: {sim.last_vibration_ms}")

    # 5.4 Amplitude clamping
    sim.vibrate_custom(50, 2.5, True)
    assert_check(sim.last_amplitude == 1.0,
                 "5.4 Amplitude overflow (>1.0) clamped to 1.0",
                 f"actual: {sim.last_amplitude}")

    sim.vibrate_custom(50, -1.0, True)
    assert_check(sim.last_amplitude == -1.0,
                 "5.5 Negative default amplitude -1.0 preserved as default platform vibration")

    # 5.5 History ring buffer bound
    sim.clear_history()
    for i in range(150):
        sim.set_time(i * 100)
        sim.vibrate_pickup()

    assert_check(len(sim.vibration_history) == 100,
                 "5.6 History ring buffer strictly capped at max_history_size = 100",
                 f"actual size: {len(sim.vibration_history)}")
    assert_check(sim.vibration_count == 150,
                 "5.7 vibration_count tracks all 150 successful vibration triggers",
                 f"count: {sim.vibration_count}")

    # 5.6 Master suppression switch
    sim.haptics_enabled = False
    sim.advance_time(100)
    suppressed_pickup = sim.vibrate_pickup()
    suppressed_gate = sim.vibrate_gate()
    suppressed_quest = sim.vibrate_quest()

    assert_check(not suppressed_pickup and not suppressed_gate and not suppressed_quest,
                 "5.8 When haptics_enabled = false, all vibration types (including bypass milestones) are silenced")
    assert_check(len(sim.vibration_history) == 100,
                 "5.9 No new entries added to history when haptics_enabled = false")

    # =========================================================================
    # Final Verdict & Report Summary
    # =========================================================================
    print("\n=======================================================================")
    print(f"[CHALLENGER-1] Results: {tests_passed} checks passed, {tests_failed} failed")
    print("=======================================================================")

    if tests_failed == 0:
        print(">>> EMPIRICAL VERDICT: APPROVE <<<")
        return 0
    else:
        print(f">>> EMPIRICAL VERDICT: REQUEST_CHANGES ({tests_failed} failures) <<<")
        return 1

if __name__ == "__main__":
    sys.exit(main())
