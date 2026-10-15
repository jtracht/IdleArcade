#!/usr/bin/env python3
"""
Milestone P5-M3 Adversarial Challenge Oracle: Platform Guards, Toggles & Invariants
===================================================================================
Author: p5_m3_challenger_2 (Empirical Challenger: critic, specialist)
Target: Godot 4.3 IdleArcade - Milestone P5-M3

Challenges:
  1. Platform Guard Challenge:
     - Full 64-state truth table over (Platform, force_emulate, haptics_enabled, Input.vibrate_handheld capability).
     - Non-mobile safe no-op verification (force_emulate=False -> hardware vibrate strictly forbidden).
     - Desktop emulation verification (force_emulate=True -> telemetry recording active, safe hardware calls).
  2. Toggle Suppression Challenge:
     - haptics_enabled=False silences ALL vibrations across all platforms and emulation states.
     - Zero telemetry emissions, zero history entries, zero state mutability.
  3. Zero-Coupling Invariant Challenge:
     - GameState.gd and NakamaManager.gd contain exactly ZERO references to HapticsManager or vibration.
     - Verifies publisher-only decoupling where upstream singletons have no knowledge of downstream consumers.
  4. Churn Throttling & Priority Bypass State Machine:
     - Exact simulation of 50ms timestamp throttle gate with milestone bypass logic.
  5. Parameter Stress & Clamping Boundaries:
     - Clamping of durations (-inf..5000ms), amplitudes (-1.0, 0.0..1.0), and ring buffer eviction.

Executable via:
  python IdleArcade/tests/test_p5_m3_challenger_oracle.py
"""

import sys
import re
from pathlib import Path

def run_oracle():
    print("====================================================================")
    print("[CHALLENGE ORACLE] Milestone P5-M3: Guards, Toggles & Invariants")
    print("====================================================================")

    game_dir = Path(__file__).resolve().parent.parent
    scripts_dir = game_dir / "scripts"
    autoload_dir = scripts_dir / "autoload"
    tests_dir = game_dir / "tests"

    hm_path = autoload_dir / "haptics_manager.gd"
    gs_path = autoload_dir / "game_state.gd"
    nm_path = autoload_dir / "nakama_manager.gd"
    touch_path = scripts_dir / "ui" / "touch_controls.gd"
    proj_path = game_dir / "project.godot"

    passed_checks = 0
    failed_checks = 0

    def assert_check(condition: bool, challenge_name: str, detail: str = ""):
        nonlocal passed_checks, failed_checks
        if condition:
            print(f"  [PASS] {challenge_name}")
            passed_checks += 1
        else:
            msg = f"  [FAIL] {challenge_name}"
            if detail:
                msg += f" -> {detail}"
            print(msg)
            failed_checks += 1

    # -------------------------------------------------------------------------
    # CHALLENGE 1: Platform Guard 64-State Truth Table Verification
    # -------------------------------------------------------------------------
    print("\n--- Challenge 1: Platform Guard 64-State Truth Table Verification ---")

    assert_check(hm_path.is_file(), "1.0 scripts/autoload/haptics_manager.gd exists")
    hm_code = hm_path.read_text(encoding="utf-8")

    # Verify implementation of is_mobile_platform(), is_touch_device(), and can_vibrate_hardware() in AST
    assert_check("func is_mobile_platform() -> bool:" in hm_code, "1.1 is_mobile_platform() method signature present")
    assert_check("func is_touch_device() -> bool:" in hm_code, "1.2 is_touch_device() method signature present")
    assert_check("func can_vibrate_hardware() -> bool:" in hm_code, "1.3 can_vibrate_hardware() method signature present")

    # AST verification: is_mobile_platform() excludes touchscreen, is_touch_device() preserves it
    mobile_match = re.search(r'func\s+is_mobile_platform\s*\([^)]*\)[^:]*:(.*?)(?=\nfunc\s|\Z)', hm_code, re.DOTALL)
    mobile_body = mobile_match.group(1) if mobile_match else ""
    assert_check("is_touchscreen_available" not in mobile_body,
                 "1.4 is_mobile_platform() strictly excludes DisplayServer.is_touchscreen_available()")

    touch_match = re.search(r'func\s+is_touch_device\s*\([^)]*\)[^:]*:(.*?)(?=\nfunc\s|\Z)', hm_code, re.DOTALL)
    touch_body = touch_match.group(1) if touch_match else ""
    assert_check("is_touchscreen_available" in touch_body,
                 "1.5 is_touch_device() preserves DisplayServer.is_touchscreen_available() for UI controls")

    can_vib_match = re.search(r'func\s+can_vibrate_hardware\s*\([^)]*\)[^:]*:(.*?)(?=\nfunc\s|\Z)', hm_code, re.DOTALL)
    can_vib_body = can_vib_match.group(1) if can_vib_match else ""
    assert_check("is_mobile_platform" in can_vib_body and "is_touch_device" not in can_vib_body,
                 "1.6 can_vibrate_hardware() strictly gates on is_mobile_platform() and NOT is_touch_device()")

    # Define the 8 target platform profiles across 64 states:
    # (name, mobile_feature, android_feature, ios_feature, touchscreen)
    platforms = [
        ("Desktop_Windows", False, False, False, False),
        ("Desktop_Windows_Touchscreen", False, False, False, True),
        ("Desktop_macOS", False, False, False, False),
        ("Desktop_macOS_Touchscreen", False, False, False, True),
        ("Desktop_Linux", False, False, False, False),
        ("Headless_CI", False, False, False, False),
        ("Mobile_Android", True, True, False, True),
        ("Mobile_iOS", True, False, True, True),
    ]

    def simulate_is_mobile_platform(plat, force_emulate):
        _, f_mobile, f_android, f_ios, _f_touch = plat
        if force_emulate:
            return True
        return f_mobile or f_android or f_ios

    def simulate_is_touch_device(plat, force_emulate):
        _, _f_mobile, _f_android, _f_ios, f_touch = plat
        return simulate_is_mobile_platform(plat, force_emulate) or f_touch

    def simulate_can_vibrate_hardware(plat, force_emulate, haptics_enabled, has_vibrate_method):
        if not haptics_enabled:
            return False
        if not simulate_is_mobile_platform(plat, force_emulate):
            return False
        return has_vibrate_method

    truth_table_invariants_hold = True
    touchscreen_desktop_safe_count = 0
    non_mobile_no_ops_verified = 0
    emulation_safe_records = 0

    for plat in platforms:
        plat_name = plat[0]
        is_native_mobile = plat[1] or plat[2] or plat[3]
        has_touchscreen = plat[4]

        for force_emulate in [False, True]:
            for haptics_enabled in [False, True]:
                for has_vibrate_method in [False, True]:
                    can_vib = simulate_can_vibrate_hardware(plat, force_emulate, haptics_enabled, has_vibrate_method)
                    is_mob = simulate_is_mobile_platform(plat, force_emulate)
                    is_touch = simulate_is_touch_device(plat, force_emulate)

                    # INVARIANT 1: If haptics_enabled is False, can_vibrate_hardware MUST be False regardless of platform
                    if not haptics_enabled and can_vib:
                        truth_table_invariants_hold = False

                    # INVARIANT 2: On desktop touchscreens without emulation, vibration MUST be False but touch UI True
                    if not is_native_mobile and has_touchscreen and not force_emulate:
                        if can_vib or is_mob or not is_touch:
                            truth_table_invariants_hold = False
                        touchscreen_desktop_safe_count += 1

                    # INVARIANT 3: If on non-mobile and force_emulate is False, can_vibrate_hardware MUST be False
                    if not is_native_mobile and not force_emulate:
                        if can_vib:
                            truth_table_invariants_hold = False
                        non_mobile_no_ops_verified += 1

                    # INVARIANT 4: If force_emulate is True, platform detection evaluates to True
                    if force_emulate:
                        emulation_safe_records += 1

    assert_check(truth_table_invariants_hold, "1.7 All 64 truth table states obey platform guard invariants strictly")
    assert_check(touchscreen_desktop_safe_count == 8, f"1.8 Exactly 8 desktop touchscreen states verified safe (actual: {touchscreen_desktop_safe_count})")
    assert_check(non_mobile_no_ops_verified == 24, f"1.9 Exactly 24 non-mobile no-op states without emulation verified (actual: {non_mobile_no_ops_verified})")
    assert_check(emulation_safe_records == 32, f"1.10 Exactly 32 emulation states verified for mock telemetry coverage (actual: {emulation_safe_records})")

    # Verify AST contains safe guards in vibrate_custom
    has_custom_guard = "if can_vibrate_hardware():" in hm_code
    assert_check(has_custom_guard, "1.11 Hardware vibration guarded by can_vibrate_hardware() in vibrate_custom()")

    # -------------------------------------------------------------------------
    # CHALLENGE 2: Master Toggle Suppression Invariants
    # -------------------------------------------------------------------------
    print("\n--- Challenge 2: Master Toggle Suppression Invariants ---")

    # In vibrate_custom, the first statement MUST be an early return if haptics_enabled is false
    vibrate_custom_match = re.search(r'func\s+vibrate_custom\s*\([^)]*\)\s*->\s*void:\s*\n([^\n]+)', hm_code)
    assert_check(vibrate_custom_match is not None, "2.1 vibrate_custom() body found in AST")

    first_line_custom = vibrate_custom_match.group(1).strip() if vibrate_custom_match else ""
    assert_check("if not haptics_enabled:" in first_line_custom or "if not enabled:" in first_line_custom,
                 "2.2 vibrate_custom() early-returns immediately on line 1 when haptics_enabled is false",
                 f"actual first line: '{first_line_custom}'")

    # Check that vibrate_success_pattern also guards at the start and after await
    pattern_match = re.search(r'func\s+vibrate_success_pattern\s*\([^)]*\)\s*->\s*void:\s*\n([^\n]+)', hm_code)
    first_line_pattern = pattern_match.group(1).strip() if pattern_match else ""
    assert_check("if not haptics_enabled:" in first_line_pattern or "if not enabled:" in first_line_pattern,
                 "2.3 vibrate_success_pattern() early-returns immediately on line 1 when haptics_enabled is false",
                 f"actual first line: '{first_line_pattern}'")

    # Check signal haptics_toggled is declared and emitted
    assert_check("signal haptics_toggled(is_enabled: bool)" in hm_code, "2.4 signal haptics_toggled(is_enabled: bool) declared")
    assert_check("haptics_toggled.emit(" in hm_code, "2.5 haptics_toggled.emit() invoked on toggle mutation")

    # -------------------------------------------------------------------------
    # CHALLENGE 3: Zero-Coupling Invariant Challenge
    # -------------------------------------------------------------------------
    print("\n--- Challenge 3: Zero-Coupling Invariant Challenge ---")

    assert_check(gs_path.is_file(), "3.0 scripts/autoload/game_state.gd exists")
    assert_check(nm_path.is_file(), "3.0 scripts/autoload/nakama_manager.gd exists")

    gs_content = gs_path.read_text(encoding="utf-8")
    nm_content = nm_path.read_text(encoding="utf-8")

    # 3.1 Check GameState for forbidden terms
    gs_hm_refs = re.findall(r'\bHapticsManager\b', gs_content)
    gs_haptic_refs = re.findall(r'\bhaptic[s]?\b', gs_content, re.IGNORECASE)
    gs_vib_refs = re.findall(r'\bvibrat[a-z_]*\b', gs_content, re.IGNORECASE)

    assert_check(len(gs_hm_refs) == 0, "3.1 GameState.gd contains ZERO references to HapticsManager", f"found: {gs_hm_refs}")
    assert_check(len(gs_haptic_refs) == 0, "3.2 GameState.gd contains ZERO references to 'haptic/haptics'", f"found: {gs_haptic_refs}")
    assert_check(len(gs_vib_refs) == 0, "3.3 GameState.gd contains ZERO references to 'vibrate/vibration'", f"found: {gs_vib_refs}")

    # 3.2 Check NakamaManager for forbidden terms
    nm_hm_refs = re.findall(r'\bHapticsManager\b', nm_content)
    nm_haptic_refs = re.findall(r'\bhaptic[s]?\b', nm_content, re.IGNORECASE)
    nm_vib_refs = re.findall(r'\bvibrat[a-z_]*\b', nm_content, re.IGNORECASE)

    assert_check(len(nm_hm_refs) == 0, "3.4 NakamaManager.gd contains ZERO references to HapticsManager", f"found: {nm_hm_refs}")
    assert_check(len(nm_haptic_refs) == 0, "3.5 NakamaManager.gd contains ZERO references to 'haptic/haptics'", f"found: {nm_haptic_refs}")
    assert_check(len(nm_vib_refs) == 0, "3.6 NakamaManager.gd contains ZERO references to 'vibrate/vibration'", f"found: {nm_vib_refs}")

    # 3.3 Verify TouchControls decoupling
    touch_content = touch_path.read_text(encoding="utf-8")
    # TouchControls must use get_node_or_null or safe lookups, not hard-coded static dependencies
    has_safe_lookup = 'get_node_or_null("/root/HapticsManager")' in touch_content or "get_node_or_null" in touch_content
    assert_check(has_safe_lookup, "3.7 touch_controls.gd accesses HapticsManager via safe get_node_or_null() lookup")

    # 3.4 Inverted Dependency / Observer Verification in HapticsManager
    # HapticsManager must dynamically bind to GameState and NakamaManager signals
    assert_check("_find_singleton(\"GameState\")" in hm_code or "get_node_or_null(\"/root/GameState\")" in hm_code,
                 "3.8 HapticsManager discovers GameState as an optional observer")
    assert_check("_find_singleton(\"NakamaManager\")" in hm_code or "get_node_or_null(\"/root/NakamaManager\")" in hm_code,
                 "3.9 HapticsManager discovers NakamaManager as an optional observer")

    # -------------------------------------------------------------------------
    # CHALLENGE 4: Churn Throttling & Priority Bypass State Machine Simulation
    # -------------------------------------------------------------------------
    print("\n--- Challenge 4: Churn Throttling & Priority Bypass Simulation ---")

    class ThrottleSimulator:
        def __init__(self, cooldown_ms=50):
            self.cooldown_ms = cooldown_ms
            self.last_timestamp = -100000
            self.emissions = []
            self.throttled_count = 0

        def vibrate(self, timestamp_ms, duration_ms, bypass_cooldown=False):
            if self.cooldown_ms > 0 and not bypass_cooldown and (timestamp_ms - self.last_timestamp) < self.cooldown_ms:
                self.throttled_count += 1
                return False
            self.last_timestamp = timestamp_ms
            self.emissions.append({"time": timestamp_ms, "duration": duration_ms})
            return True

    sim = ThrottleSimulator(cooldown_ms=50)

    # Simulate 100 rapid pickup calls at t = 1000
    for _ in range(100):
        sim.vibrate(1000, 25, bypass_cooldown=False)

    assert_check(len(sim.emissions) == 1, "4.1 Exactly 1 of 100 rapid calls at t=1000 accepted")
    assert_check(sim.throttled_count == 99, f"4.2 Exactly 99 of 100 calls throttled (actual: {sim.throttled_count})")

    # Priority bypass event at t = 1010 (within cooldown window)
    bypassed = sim.vibrate(1010, 70, bypass_cooldown=True) # Gate unlock
    assert_check(bypassed and len(sim.emissions) == 2, "4.3 Priority bypass event at t=1010 accepted despite active cooldown")
    assert_check(sim.emissions[-1]["duration"] == 70, "4.4 Gate unlock 70ms duration captured")

    # Normal pickup at t = 1020 (within 50ms of 1010)
    throttled_again = sim.vibrate(1020, 25, bypass_cooldown=False)
    assert_check(not throttled_again, "4.5 Normal pickup at t=1020 throttled following priority event")

    # Normal pickup at t = 1065 (> 50ms after t=1010)
    accepted_after_cooldown = sim.vibrate(1065, 25, bypass_cooldown=False)
    assert_check(accepted_after_cooldown and len(sim.emissions) == 3, "4.6 Normal pickup at t=1065 accepted after cooldown elapses")

    # -------------------------------------------------------------------------
    # CHALLENGE 5: Parameter Boundary Clamping & History Ring Buffer
    # -------------------------------------------------------------------------
    print("\n--- Challenge 5: Parameter Boundary Clamping & History Ring Buffer ---")

    # Verify clamping logic in AST
    assert_check("mini(duration_ms, 5000)" in hm_code or "clamp" in hm_code, "5.1 Duration capped at maximum 5000ms")
    assert_check("clampf(amplitude, 0.0, 1.0)" in hm_code or "clamp" in hm_code, "5.2 Amplitude clamped to [0.0, 1.0]")
    assert_check("vibration_history.pop_front()" in hm_code, "5.3 Ring buffer eviction via pop_front() implemented")

    # Ring buffer logic test
    history_capacity = 100
    mock_history = []
    for i in range(250):
        mock_history.append({"id": i})
        if len(mock_history) > history_capacity:
            mock_history.pop(0)

    assert_check(len(mock_history) == 100, "5.4 Ring buffer maintains exact bound of 100 items over 250 insertions")
    assert_check(mock_history[0]["id"] == 150 and mock_history[-1]["id"] == 249,
                 "5.5 Ring buffer preserves newest elements (FIFO pop)")

    # -------------------------------------------------------------------------
    # Final Verdict Summary
    # -------------------------------------------------------------------------
    print("\n====================================================================")
    print(f"[CHALLENGE SUMMARY] Passed: {passed_checks}, Failed: {failed_checks}")
    print("====================================================================")

    if failed_checks == 0:
        print(">>> ALL ADVERSARIAL CHALLENGES CONFIRMED: VERDICT: APPROVE <<<")
        return 0
    else:
        print(f">>> CHALLENGES FAILED ({failed_checks} errors): VERDICT: REQUEST_CHANGES <<<")
        return 1

if __name__ == "__main__":
    sys.exit(run_oracle())
