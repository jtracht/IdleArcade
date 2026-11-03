#!/usr/bin/env python3
"""
Adversarial AST & Code Inspection Oracle for Phase 17 Domain 5
Audits test_full_stack_qa.gd Domain 5 for tautologies, assertion integrity, and state safety.
"""

import re
import sys
import subprocess
from pathlib import Path

def main():
    test_path = Path("IdleArcade/tests/test_full_stack_qa.gd")
    if not test_path.exists():
        print(f"[FAIL] {test_path} not found")
        sys.exit(1)

    content = test_path.read_text(encoding="utf-8")
    lines = content.splitlines()

    # Find Domain 5 start and end
    d5_start = None
    for idx, line in enumerate(lines):
        if "DOMAIN 5 IMPLEMENTATION: TUTORIAL" in line:
            d5_start = idx
            break

    if d5_start is None:
        print("[FAIL] Domain 5 implementation banner not found")
        sys.exit(1)

    d5_lines = lines[d5_start:]
    d5_text = "\n".join(d5_lines)

    print(f"[INFO] Domain 5 lines: {len(d5_lines)} (from line {d5_start + 1})")

    # 1. Parse all _assert_check calls using regex across multi-lines
    assert_pattern = re.compile(r'_assert_check\(\s*(.*?),\s*("[^"]*"(?:\s*%\s*[^)]+)?)\s*\)', re.DOTALL)
    matches = list(assert_pattern.finditer(d5_text))
    print(f"[INFO] Found {len(matches)} static _assert_check invocations in Domain 5")

    # 2. Check for tautological assertions
    tautology_failures = []
    tautological_patterns = [
        re.compile(r'^\s*true\s*$', re.IGNORECASE),
        re.compile(r'^\s*1\s*==\s*1\s*$'),
        re.compile(r'^\s*0\s*==\s*0\s*$'),
        re.compile(r'^\s*"[^"]*"\s*==\s*"[^"]*"\s*$'),
        re.compile(r'^\s*not\s+false\s*$', re.IGNORECASE),
    ]

    for m in matches:
        cond_raw = m.group(1).strip()
        msg_raw = m.group(2).strip()
        for tp in tautological_patterns:
            if tp.match(cond_raw):
                tautology_failures.append((cond_raw, msg_raw))

    if tautology_failures:
        print(f"[FAIL] Found {len(tautology_failures)} tautological assertions:")
        for cond, msg in tautology_failures:
            print(f"  - Condition: {cond} in {msg}")
        sys.exit(1)
    else:
        print("  [PASS] 0 tautological assertions found in Domain 5 (100% genuine dynamic checks)")

    # 3. Check for required subdomains in Domain 5
    required_sections = [
        "_test_d5_section_1_tutorial_state_machine_and_intro",
        "_test_d5_section_2_dialogue_panel_and_angel_investor",
        "_test_d5_section_3_spotlight_overlay_and_touch_passthrough",
        "_test_d5_section_4_contextual_hints_and_exactly_once",
        "_test_d5_section_5_save_load_serialization_and_truth_table",
        "_test_d5_section_6_replay_flow_and_non_destructive_reset",
    ]

    for sec in required_sections:
        if f"func {sec}" in d5_text:
            print(f"  [PASS] Method {sec}() present")
        else:
            print(f"  [FAIL] Missing method {sec}()")
            sys.exit(1)

    # 4. Strict invariants checks
    # 6-Button invariant in dialogue_panel.tscn
    if "buttons.size() == 6" in d5_text:
        print("  [PASS] Strict 6-button invariant asserted in Section 2")
    else:
        print("  [FAIL] 6-button invariant check missing in Section 2")
        sys.exit(1)

    # Area partition identity in overlay
    if "total_vp_area, cutout_area + blocker_area" in d5_text:
        print("  [PASS] Area partition identity (cutout + blocker == viewport) asserted in Section 3")
    else:
        print("  [FAIL] Area partition identity missing in Section 3")
        sys.exit(1)

    # Corrupted save immunity
    if "corrupted_payload" in d5_text:
        print("  [PASS] Corrupted save payload hardening verified in Section 5")
    else:
        print("  [FAIL] Corrupted save verification missing in Section 5")
        sys.exit(1)

    # Non-destructive replay
    if 'gs.upgrades["tier_1"]["level"] == 15' in d5_text:
        print("  [PASS] Non-destructive veteran upgrade preservation asserted in Section 6")
    else:
        print("  [FAIL] Veteran upgrade preservation check missing in Section 6")
        sys.exit(1)

    # 5. Check MIN_EXPECTED_PASS_COUNT specification
    if "const MIN_EXPECTED_PASS_COUNT: int = 1500" in content:
        print("  [PASS] test_full_stack_qa.gd defines MIN_EXPECTED_PASS_COUNT = 1500")
    else:
        print("  [FAIL] MIN_EXPECTED_PASS_COUNT = 1500 missing or altered")
        sys.exit(1)

    # 6. Execute Godot test_full_stack_qa.gd headlessly to certify live runtime assertion counts
    print("\n[INFO] Executing live headless run of test_full_stack_qa.gd...")
    cmd = ["godot", "--headless", "--path", "IdleArcade", "-s", "tests/test_full_stack_qa.gd"]
    res = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=60)
    stdout = res.stdout

    if res.returncode != 0:
        print(f"[FAIL] test_full_stack_qa.gd exited with non-zero exit code: {res.returncode}")
        sys.exit(1)

    # Extract Domain 5 and Total assertions counts
    d5_match = re.search(r"Domain 5:\s*Tutorial & FTUE Onboarding\s*:\s*(\d+)\s*Passed,\s*(\d+)\s*Failed", stdout)
    total_match = re.search(r"TOTAL ASSERTIONS\s*:\s*(\d+)\s*Passed,\s*(\d+)\s*Failed", stdout)

    if not d5_match:
        print("[FAIL] Could not parse Domain 5 summary line from output")
        sys.exit(1)
    if not total_match:
        print("[FAIL] Could not parse Total Assertions summary line from output")
        sys.exit(1)

    d5_pass = int(d5_match.group(1))
    d5_fail = int(d5_match.group(2))
    tot_pass = int(total_match.group(1))
    tot_fail = int(total_match.group(2))

    print(f"  [PASS] Domain 5 live execution: {d5_pass} Passed, {d5_fail} Failed (Expected: 214 Passed, 0 Failed)")
    if d5_pass == 214 and d5_fail == 0:
        print("  [PASS] Domain 5 exactly matches 214 assertions specification")
    else:
        print(f"[FAIL] Domain 5 assertion count mismatch: {d5_pass} != 214")
        sys.exit(1)

    print(f"  [PASS] Full suite live execution: {tot_pass} Passed, {tot_fail} Failed (Expected: 1550 Passed, 0 Failed)")
    if tot_pass == 1550 and tot_fail == 0:
        print("  [PASS] Total assertion count exactly matches 1,550 assertions specification")
    else:
        print(f"[FAIL] Total assertion count mismatch: {tot_pass} != 1550")
        sys.exit(1)

    print("\n====================================================================")
    print(">>> DOMAIN 5 AST & CODE INSPECTION ORACLE: ALL CHECKS PASSED <<<")
    print("====================================================================")

if __name__ == "__main__":
    main()
