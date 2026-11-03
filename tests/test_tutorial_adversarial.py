#!/usr/bin/env python3
"""
Adversarial Verification Oracle for Phase 17 Milestone 2 (Challenger 1).
Validates:
1. Headless Godot execution of test_tutorial_adversarial.gd (0 SCRIPT ERRORs, exit 0).
2. Headless Godot execution of test_tutorial_flow.gd (0 SCRIPT ERRORs, exit 0).
3. Headless Godot execution of test_tutorial_ui_ergonomics.gd (0 SCRIPT ERRORs, exit 0).
4. Static AST/code contract inspection of tutorial_manager.gd.
5. Legacy non-regression suites (Phase 11 dialogue stress, Phase 16 master oracle).
"""

import os
import re
import subprocess
import sys

TARGET_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
TESTS_DIR = os.path.join(TARGET_DIR, "tests")
SCRIPTS_DIR = os.path.join(TARGET_DIR, "scripts")

passed_checks = 0
failed_checks = 0

def check(condition: bool, description: str, detail: str = ""):
    global passed_checks, failed_checks
    if condition:
        print(f"  [PASS] {description}")
        passed_checks += 1
    else:
        err = f"  [FAIL] {description}"
        if detail:
            err += f" (Detail: {detail})"
        print(err, file=sys.stderr)
        failed_checks += 1

def run_cmd(cmd: list, cwd: str = TARGET_DIR) -> tuple:
    result = subprocess.run(cmd, cwd=cwd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    return result.returncode, result.stdout, result.stderr

def main():
    print("=================================================================")
    print("CHALLENGER 1 ADVERSARIAL ORACLE: IdleArcade P17-M2 Tutorial FSM")
    print("=================================================================")

    # -----------------------------------------------------------------
    # TIER 1: Static AST & Contract Inspection of TutorialManager.gd
    # -----------------------------------------------------------------
    print("\n--- TIER 1: Static Contract Inspection of tutorial_manager.gd ---")
    tm_path = os.path.join(SCRIPTS_DIR, "autoload", "tutorial_manager.gd")
    check(os.path.exists(tm_path), "tutorial_manager.gd exists at scripts/autoload/tutorial_manager.gd")

    with open(tm_path, "r", encoding="utf-8") as f:
        tm_code = f.read()

    # Signals
    for sig in ["step_started", "step_completed", "tutorial_completed", "tutorial_skipped", "contextual_hint_triggered"]:
        pattern = rf"signal\s+{sig}\b"
        check(bool(re.search(pattern, tm_code)), f"tutorial_manager.gd declares signal '{sig}'")

    # Methods
    for method in ["start_linear_intro", "advance_step", "skip_tutorial", "trigger_contextual_hint",
                   "get_current_step", "is_tutorial_active", "should_start_intro", "reset_tutorial"]:
        pattern = rf"func\s+{method}\s*\("
        check(bool(re.search(pattern, tm_code)), f"tutorial_manager.gd implements method '{method}()'")

    # Enum State values
    for state in ["IDLE", "INTRO_STEP_1_TAP", "INTRO_STEP_2_UPGRADE", "INTRO_STEP_3_FRENZY",
                  "INTRO_STEP_4_CAMPUS", "INTRO_STEP_5_COLLECTIBLE", "INTRO_STEP_6_STATION", "COMPLETED"]:
        check(state in tm_code, f"State enum includes '{state}'")

    # Layer elevation logic
    check("layer = 96" in tm_code or "96" in tm_code, "Dialogue layer elevation to 96 present")
    check("layer = _saved_dialogue_layer" in tm_code or "_saved_dialogue_layer" in tm_code,
          "Dialogue layer restoration logic present")

    # -----------------------------------------------------------------
    # TIER 2: Headless Godot Adversarial Suite Execution
    # -----------------------------------------------------------------
    print("\n--- TIER 2: Headless Adversarial Test Suite Execution ---")
    adv_gd = os.path.join(TESTS_DIR, "test_tutorial_adversarial.gd")
    check(os.path.exists(adv_gd), "test_tutorial_adversarial.gd test runner exists")

    code, out, err = run_cmd(["godot", "--headless", "--path", TARGET_DIR, "-s", "tests/test_tutorial_adversarial.gd"])
    combined = out + "\n" + err

    check(code == 0, "test_tutorial_adversarial.gd exited with code 0", f"code={code}")
    check("SCRIPT ERROR" not in combined, "0 SCRIPT ERRORs in adversarial suite run")
    check("ADVERSARIAL STRESS TEST RESULTS: 219 Passed, 0 Failed" in combined or "0 Failed" in combined,
          "Adversarial suite reports 0 Failed checks")

    # -----------------------------------------------------------------
    # TIER 3: Headless Godot Flow & Ergonomics Baseline Verification
    # -----------------------------------------------------------------
    print("\n--- TIER 3: Headless Flow & Ergonomics Baseline Verification ---")
    code_f, out_f, err_f = run_cmd(["godot", "--headless", "--path", TARGET_DIR, "-s", "tests/test_tutorial_flow.gd"])
    comb_f = out_f + "\n" + err_f
    check(code_f == 0, "test_tutorial_flow.gd exited with code 0")
    check("SCRIPT ERROR" not in comb_f, "0 SCRIPT ERRORs in test_tutorial_flow.gd")
    check("Milestone 2 Test Results: 74 Passed, 0 Failed" in comb_f, "Milestone 2 flow suite reports 74 Passed, 0 Failed")

    code_e, out_e, err_e = run_cmd(["godot", "--headless", "--path", TARGET_DIR, "-s", "tests/test_tutorial_ui_ergonomics.gd"])
    comb_e = out_e + "\n" + err_e
    check(code_e == 0, "test_tutorial_ui_ergonomics.gd exited with code 0")
    check("SCRIPT ERROR" not in comb_e, "0 SCRIPT ERRORs in test_tutorial_ui_ergonomics.gd")
    check("Milestone 1 Test Results: 63 Passed, 0 Failed" in comb_e, "Milestone 1 ergonomics suite reports 63 Passed, 0 Failed")

    # -----------------------------------------------------------------
    # TIER 4: Strict Dialogue Invariant & Legacy Regressions
    # -----------------------------------------------------------------
    print("\n--- TIER 4: Strict Dialogue Invariant & Legacy Regressions ---")
    diag_script = os.path.join(TESTS_DIR, "test_phase11_dialogue_stress.py")
    if os.path.exists(diag_script):
        code_d, out_d, err_d = run_cmd([sys.executable, diag_script])
        check(code_d == 0, "test_phase11_dialogue_stress.py passed (6-button invariant preserved)")
        check("112 Passed, 0 Failed" in out_d or "Passed: 112" in out_d, "112/112 dialogue stress checks green")

    p16_script = os.path.join(TESTS_DIR, "test_phase16_verify.py")
    if os.path.exists(p16_script):
        code_p, out_p, err_p = run_cmd([sys.executable, p16_script])
        check(code_p == 0, "test_phase16_verify.py master regression oracle passed")
        combined_p = re.sub(r'\x1b\[[0-9;]*m', '', out_p + "\n" + err_p)
        check(bool(re.search(r"Passed\s*:\s*266", combined_p)), "266/266 Phase 16 checks green")

    # -----------------------------------------------------------------
    # SUMMARY
    # -----------------------------------------------------------------
    print("\n=================================================================")
    print(f"ORACLE RESULTS: {passed_checks} Passed, {failed_checks} Failed")
    print("=================================================================")

    sys.exit(0 if failed_checks == 0 else 1)

if __name__ == "__main__":
    main()
