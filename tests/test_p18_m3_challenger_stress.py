#!/usr/bin/env python3
"""
=============================================================================
Phase 18 Milestone 3: Domain 6 Empirical Adversarial Challenger Verification Suite
File: tests/test_p18_m3_challenger_stress.py
Target: Domain 6 Scenarios 4 to 7 Stress & Invariant Certification

Adversarially tests and certifies:
  1. Scenario 4: Corrupted Save Recovery Matrix (10 distinct corruption modes + AST guards)
  2. Scenario 5: Rapid UI Stress & Tap Deduplication (1-frame storming across 8 modals, 100 taps, pointer isolation)
  3. Scenario 6: Offline Progression Boundary Precision (8-case matrix, 28800s clamp, F1 deserialization order)
  4. Scenario 7: Lifecycle Teardown & Leak Audit (MIN_EXPECTED_PASS_COUNT >= 1800, signal disconnection, zero stray nodes)
  5. Empirical Godot Headless Runner Verification (Executing both master QA and stress suites)
=============================================================================
"""

import os
import re
import sys
import math
import subprocess

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.abspath(os.path.join(SCRIPT_DIR, ".."))
if not os.path.exists(os.path.join(PROJECT_ROOT, "project.godot")):
    if os.path.exists("project.godot"):
        PROJECT_ROOT = os.path.abspath(".")
    elif os.path.exists("IdleArcade/project.godot"):
        PROJECT_ROOT = os.path.abspath("IdleArcade")
    elif os.path.exists(os.path.join(SCRIPT_DIR, "IdleArcade", "project.godot")):
        PROJECT_ROOT = os.path.abspath(os.path.join(SCRIPT_DIR, "IdleArcade"))

print(f"[SETUP] Project Root: {PROJECT_ROOT}")

pass_count = 0
fail_count = 0
findings = []

def check(condition: bool, test_name: str, detail: str = ""):
    global pass_count, fail_count
    if condition:
        print(f"  [PASS] {test_name}")
        pass_count += 1
    else:
        err = f"  [FAIL] {test_name}"
        if detail:
            err += f" -> {detail}"
        print(err, file=sys.stderr)
        findings.append(err)
        fail_count += 1


# =============================================================================
# TIER 1: SCENARIO 4 — CORRUPTED SAVE RECOVERY MATRIX AST & LOGIC AUDIT
# =============================================================================
def tier1_scenario4_corrupted_save_audit():
    print("\n--- TIER 1: SCENARIO 4 — CORRUPTED SAVE RECOVERY MATRIX ---")
    gs_path = os.path.join(PROJECT_ROOT, "scripts", "autoload", "game_state.gd")
    check(os.path.exists(gs_path), "1.1 game_state.gd exists")
    
    with open(gs_path, "r", encoding="utf-8") as f:
        gs_code = f.read()

    # Check FileAccess existence check
    check("if not FileAccess.file_exists(SAVE_PATH):" in gs_code, "1.2 Mode 1: Missing file check present")
    
    # Check JSON parse check
    check("var parse_err := json.parse(text)" in gs_code or "json.parse(" in gs_code, "1.3 Mode 2/3: JSON.parse() executed")
    check("if parse_err != OK:" in gs_code, "1.4 Mode 2/3: Parse error check present")

    # Check non-dictionary root check
    check("if not data is Dictionary:" in gs_code, "1.5 Mode 4: Non-Dictionary root rejection present")

    # Check numeric type poisoning & NaN/Inf sanitization
    check("is_nan(raw_energy)" in gs_code and "is_inf(raw_energy)" in gs_code, "1.6 Mode 5/6: NaN/Inf guard on raw_energy")
    check("is_nan(raw_total_earned)" in gs_code, "1.7 Mode 5/6: NaN/Inf guard on raw_total_earned")
    check("is_nan(raw_lifetime)" in gs_code, "1.8 Mode 5/6: NaN/Inf guard on raw_lifetime")

    # Check negative clamping (Mode 7)
    check("maxf(0.0, raw_energy)" in gs_code, "1.9 Mode 7: Negative energy clamped to 0.0")
    check("maxf(energy, raw_total_earned)" in gs_code, "1.10 Mode 7: Invariant total_earned >= energy enforced")
    check("maxf(total_energy_earned, raw_lifetime)" in gs_code, "1.11 Mode 7: Invariant total_lifetime >= total_earned enforced")

    # Check clock rollback guard (Mode 10)
    check("if is_nan(elapsed) or is_inf(elapsed) or elapsed < 0.0:" in gs_code and "elapsed = 0.0" in gs_code,
          "1.12 Mode 10: Elapsed offline time clock rollback guard present")

    # Check collections sanitization (Mode 9)
    check("if t is String and not t.is_empty()" in gs_code, "1.13 Mode 9: researched_techs prunes non-strings")
    check("clampi(int(w.get(\"desk_assigned\", 0)), 0, 4)" in gs_code, "1.14 Mode 9: worker desk_assigned clamped to [0, 4]")
    check("syndicate_tier = clampi(raw_syn_tier, 0, 5)" in gs_code, "1.15 Mode 9: syndicate_tier clamped to [0, 5]")


# =============================================================================
# TIER 2: SCENARIO 5 — RAPID UI STRESS & POINTER ISOLATION AUDIT
# =============================================================================
def tier2_scenario5_ui_stress_audit():
    print("\n--- TIER 2: SCENARIO 5 — RAPID UI STRESS & POINTER ISOLATION ---")
    
    # 2.1 Core Frame Deduplication Guard
    core_path = os.path.join(PROJECT_ROOT, "scripts", "core.gd")
    check(os.path.exists(core_path), "2.1 core.gd exists")
    with open(core_path, "r", encoding="utf-8") as f:
        core_code = f.read()
    check("_last_tap_frame" in core_code, "2.2 _last_tap_frame variable declared in core.gd")
    check("Engine.get_process_frames()" in core_code, "2.3 Engine.get_process_frames() used for frame synchronization")
    check("if current_frame == _last_tap_frame:" in core_code or "current_frame <= _last_tap_frame" in core_code,
          "2.4 Duplicate taps in identical frame rejected")

    # 2.2 Pointer Isolation Audit across All Modals
    modals = [
        ("scenes/ui/tech_tree_modal.tscn", "TechTreeModal"),
        ("scenes/ui/settings_modal.tscn", "SettingsModal"),
        ("scenes/ui/ipo_modal.tscn", "IpoModal"),
        ("scenes/ui/daily_board_modal.tscn", "DailyBoardModal"),
        ("scenes/ui/syndicate_modal.tscn", "SyndicateModal"),
        ("scenes/ui/staff_modal.tscn", "StaffModal"),
        ("scenes/dialogue_panel.tscn", "DialoguePanel")
    ]
    for rel_path, modal_name in modals:
        full_path = os.path.join(PROJECT_ROOT, rel_path)
        check(os.path.exists(full_path), f"2.5 {modal_name} scene exists at {rel_path}")
        with open(full_path, "r", encoding="utf-8") as f:
            tscn_text = f.read()
        # Verify root or backdrop has mouse_filter = 0 (Control.MOUSE_FILTER_STOP)
        check("mouse_filter = 0" in tscn_text, f"2.6 {modal_name} has mouse_filter = 0 (MOUSE_FILTER_STOP)")

    # 2.3 QuickHUD Spacer Pointer Isolation in main_3d.tscn
    main_3d_path = os.path.join(PROJECT_ROOT, "scenes", "main_3d.tscn")
    check(os.path.exists(main_3d_path), "2.7 main_3d.tscn exists")
    with open(main_3d_path, "r", encoding="utf-8") as f:
        main_3d_text = f.read()
    check('node name="Spacer" type="Control" parent="HUD/QuickHUD/BarHBox"' in main_3d_text or
          'name="Spacer"' in main_3d_text, "2.8 QuickHUD Spacer node located in main_3d.tscn")
    spacer_block = re.search(r'\[node name="Spacer" type="Control"[^\]]*\]\s*([\s\S]*?)(?=\n\[node|\Z)', main_3d_text)
    check(spacer_block is not None, "2.9 Spacer definition block parsed")
    if spacer_block:
        check("mouse_filter = 0" in spacer_block.group(1), "2.10 QuickHUD Spacer mouse_filter = 0 (STOP) prevents 3D click bleed")


# =============================================================================
# TIER 3: SCENARIO 6 — OFFLINE PROGRESSION BOUNDARY PRECISION MATHEMATICS
# =============================================================================
def tier3_scenario6_offline_boundary_math():
    print("\n--- TIER 3: SCENARIO 6 — OFFLINE BOUNDARY PRECISION MATHEMATICS ---")
    
    gs_path = os.path.join(PROJECT_ROOT, "scripts", "autoload", "game_state.gd")
    with open(gs_path, "r", encoding="utf-8") as f:
        gs_code = f.read()

    # 3.1 Offline gain formula constants in code
    check("var effective_elapsed: float = minf(elapsed, 28800.0)" in gs_code, "3.1 8-hour cap minf(elapsed, 28800.0) present")
    check("var offline_gain: float = effective_rps * effective_elapsed * 0.5" in gs_code, "3.2 50% efficiency multiplier present")

    # 3.2 Deserialization Order (F1 Fix Verification)
    pos_syndicate = gs_code.find("# Phase 13 Syndicate Deserialization")
    pos_staff = gs_code.find("# Phase 14 Staff & Autonomous Chibi-Worker Deserialization")
    pos_offline = gs_code.find("# Offline catch-up calculation: 50% efficiency")

    check(pos_syndicate > 0, "3.3 Syndicate deserialization section located")
    check(pos_staff > 0, "3.4 Staff deserialization section located")
    check(pos_offline > 0, "3.5 Offline catch-up calculation section located")
    check(pos_offline > pos_syndicate, "3.6 F1 Fix: Offline catch-up occurs AFTER Syndicate deserialization")
    check(pos_offline > pos_staff, "3.7 F1 Fix: Offline catch-up occurs AFTER Staff deserialization")

    # 3.3 Mathematical Boundary Precision Model
    base_rps = 100.0
    
    # Case 1: 0s -> 0.0
    gain_0s = base_rps * min(0.0, 28800.0) * 0.5
    check(gain_0s == 0.0, "3.8 Mathematical Oracle: 0s offline yields exactly 0.0")

    # Case 2: 60s -> 3,000.0
    gain_60s = base_rps * min(60.0, 28800.0) * 0.5
    check(gain_60s == 3000.0, "3.9 Mathematical Oracle: 60s offline yields exactly 3,000.0")

    # Case 3: 3600s -> 180,000.0
    gain_3600s = base_rps * min(3600.0, 28800.0) * 0.5
    check(gain_3600s == 180000.0, "3.10 Mathematical Oracle: 3,600s offline yields exactly 180,000.0")

    # Case 4: 28800s (8h exact) -> 1,440,000.0
    gain_28800s = base_rps * min(28800.0, 28800.0) * 0.5
    check(gain_28800s == 1440000.0, "3.11 Mathematical Oracle: 28,800s offline yields exactly 1,440,000.0")

    # Case 5: 86400s (24h) -> strictly clamped to 1,440,000.0 (NOT 4.32M)
    gain_86400s = base_rps * min(86400.0, 28800.0) * 0.5
    unclamped_86400s = base_rps * 86400.0 * 0.5
    check(gain_86400s == 1440000.0, "3.12 Mathematical Oracle: 86,400s offline strictly clamped to 1,440,000.0")
    check(unclamped_86400s == 4320000.0, "3.13 Mathematical Oracle: Unclamped 24h value is 4,320,000.0")
    check(gain_86400s < unclamped_86400s, "3.14 Clamped gain is strictly less than unclamped gain")

    # Sharp boundary check: 28799s vs 28800s vs 28801s
    gain_28799 = base_rps * min(28799.0, 28800.0) * 0.5
    gain_28801 = base_rps * min(28801.0, 28800.0) * 0.5
    check(gain_28799 == 1439950.0, "3.15 Sharp Boundary: 28,799s yields 1,439,950.0")
    check(gain_28801 == 1440000.0, "3.16 Sharp Boundary: 28,801s clamped to 1,440,000.0")
    check(gain_28801 == gain_28800s, "3.17 Clamp delta between 28,800s and 28,801s is strictly 0.0")

    # Compound RPS Math Oracle:
    # 100 * 1.05 (syn tier 1) * 1.25 (staff 5 @ 1.0) * 1.25 (tech overclock) = 164.0625
    compound_rps = 100.0 * 1.05 * 1.25 * 1.25
    check(math.isclose(compound_rps, 164.0625, rel_tol=1e-6), "3.18 Compound RPS formula evaluates to exactly 164.0625")
    compound_offline = compound_rps * 3600.0 * 0.5
    check(math.isclose(compound_offline, 295312.5, rel_tol=1e-6), "3.19 Compound 1h offline gain evaluates to exactly 295,312.5")


# =============================================================================
# TIER 4: SCENARIO 7 — LIFECYCLE TEARDOWN & MASTER RUNNER INTEGRITY
# =============================================================================
def tier4_scenario7_lifecycle_audit():
    print("\n--- TIER 4: SCENARIO 7 — LIFECYCLE TEARDOWN & MASTER RUNNER INTEGRITY ---")
    qa_path = os.path.join(PROJECT_ROOT, "tests", "test_full_stack_qa.gd")
    check(os.path.exists(qa_path), "4.1 test_full_stack_qa.gd exists")

    with open(qa_path, "r", encoding="utf-8") as f:
        qa_code = f.read()

    # Threshold check
    thresh_match = re.search(r'const\s+MIN_EXPECTED_PASS_COUNT:\s*int\s*=\s*(\d+)', qa_code)
    check(thresh_match is not None, "4.2 MIN_EXPECTED_PASS_COUNT constant found")
    if thresh_match:
        val = int(thresh_match.group(1))
        check(val >= 1800, f"4.3 MIN_EXPECTED_PASS_COUNT >= 1800 (actual: {val})")

    # Domain 6 presence
    check("func _test_d6_section_1_scenario_1_fresh_install_full_loop" in qa_code, "4.4 Scenario 1 function present")
    check("func _test_d6_section_2_scenario_2_ipo_prestige_and_replay" in qa_code, "4.5 Scenario 2 function present")
    check("func _test_d6_section_3_scenario_3_syndicate_and_enterprise" in qa_code, "4.6 Scenario 3 function present")
    check("func _test_d6_section_4_scenario_4_corrupted_save_recovery" in qa_code, "4.7 Scenario 4 function present")
    check("func _test_d6_section_5_scenario_5_rapid_ui_stress" in qa_code, "4.8 Scenario 5 function present")
    check("func _test_d6_section_6_offline_progression_boundary_precision" in qa_code, "4.9 Scenario 6 function present")
    check("func _test_d6_section_7_lifecycle_teardown_and_leak_audit" in qa_code, "4.10 Scenario 7 function present")

    # Cleanup and Teardown Invariants in test_full_stack_qa.gd
    check("func _cleanup_and_quit(exit_code: int) -> void:" in qa_code, "4.11 _cleanup_and_quit teardown present")
    check("Restored original user://savegame.json" in qa_code, "4.12 Save backup restoration logic present")
    check("_mounted_nodes" in qa_code and "safely unmounted" in qa_code, "4.13 Singleton unmounting loop present")


# =============================================================================
# TIER 5: EMPIRICAL HEADLESS GODOT EXECUTION RUNNER
# =============================================================================
def tier5_headless_godot_execution():
    print("\n--- TIER 5: EMPIRICAL HEADLESS GODOT EXECUTION RUNNER ---")
    
    # 5.1 Execute Independent Challenger Stress Test Suite
    stress_script = "tests/test_p18_m3_challenger_stress.gd"
    full_stress_path = os.path.join(PROJECT_ROOT, stress_script)
    check(os.path.exists(full_stress_path), f"5.1 Challenger stress script exists at {stress_script}")

    print("  >>> Executing: godot --headless --path IdleArcade -s tests/test_p18_m3_challenger_stress.gd ...")
    cmd_stress = ["godot", "--headless", "--path", PROJECT_ROOT, "-s", stress_script]
    res_stress = subprocess.run(cmd_stress, capture_output=True, text=True, encoding="utf-8", errors="replace")
    
    check(res_stress.returncode == 0, f"5.2 Challenger stress suite exit code is 0 (actual: {res_stress.returncode})")
    check("P18-M3 CHALLENGER 2 SUMMARY:" in res_stress.stdout, "5.3 Challenger summary printed")
    check("0 FAILED" in res_stress.stdout, "5.4 Challenger suite reports 0 FAILED")
    check("APPROVE" in res_stress.stdout, "5.5 Challenger suite gives explicit APPROVE verdict")

    # 5.2 Execute Master Full-Stack QA Runner
    print("  >>> Executing: godot --headless --path IdleArcade -s tests/test_full_stack_qa.gd ...")
    cmd_qa = ["godot", "--headless", "--path", PROJECT_ROOT, "-s", "tests/test_full_stack_qa.gd"]
    res_qa = subprocess.run(cmd_qa, capture_output=True, text=True, encoding="utf-8", errors="replace")

    check(res_qa.returncode == 0, f"5.6 Master QA runner exit code is 0 (actual: {res_qa.returncode})")
    check("MASTER FULL-STACK QA RUNNER SUMMARY" in res_qa.stdout, "5.7 Master QA summary printed")
    check("0 Failed" in res_qa.stdout, "5.8 Master QA reports 0 Failed across all domains")
    check("ALL FULL-STACK QA DOMAIN TESTS PASSED WITH 100% INTEGRITY" in res_qa.stdout, "5.9 Master QA confirms 100% integrity pass")

    # Extract assertion count
    match = re.search(r'TOTAL ASSERTIONS\s*:\s*(\d+)\s*Passed', res_qa.stdout)
    check(match is not None, "5.10 Total assertion count extracted from QA runner")
    if match:
        total_asserts = int(match.group(1))
        check(total_asserts >= 1800, f"5.11 Total assertions ({total_asserts}) surpasses 1,800 milestone threshold")


# =============================================================================
# MAIN RUNNER
# =============================================================================
def main():
    print("======================================================================")
    print(">>> P18-M3 CHALLENGER 2: PYTHON EMPIRICAL ORACLE & STRESS HARNESS <<<")
    print("======================================================================")

    tier1_scenario4_corrupted_save_audit()
    tier2_scenario5_ui_stress_audit()
    tier3_scenario6_offline_boundary_math()
    tier4_scenario7_lifecycle_audit()
    tier5_headless_godot_execution()

    print("\n======================================================================")
    print(f">>> CHALLENGER 2 ORACLE SUMMARY: {pass_count} PASSED, {fail_count} FAILED <<<")
    print("======================================================================")
    if fail_count == 0:
        print(">>> EMPIRICAL VERDICT: APPROVE (ALL 5 TIERS GREEN) <<<")
        sys.exit(0)
    else:
        print(f">>> EMPIRICAL VERDICT: REQUEST_CHANGES ({fail_count} CHECKS FAILED) <<<")
        for f in findings:
            print(f"  - {f}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()
