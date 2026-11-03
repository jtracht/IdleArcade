"""
Forensic Auditor Static & AST Oracle for Phase 17 Milestone 2
Verifies structural, syntactic, invariant, and integrity properties.
"""

import os
import re
import sys

PASS_COUNT = 0
FAIL_COUNT = 0

def check(condition: bool, description: str = "", detail: str = ""):
    global PASS_COUNT, FAIL_COUNT
    if condition:
        print(f"  [PASS] {description}")
        PASS_COUNT += 1
    else:
        err_msg = f"  [FAIL] {description}"
        if detail:
            err_msg += f" (Detail: {detail})"
        print(err_msg, file=sys.stderr)
        FAIL_COUNT += 1

def main():
    global PASS_COUNT, FAIL_COUNT
    print("=" * 65)
    print("FORENSIC AUDITOR ORACLE: Milestone 2 Deliverables Inspection")
    print("=" * 65)

    base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

    # 1. Inspect project.godot
    print("\n--- 1. project.godot Autoload Inspection ---")
    proj_path = os.path.join(base_dir, "project.godot")
    check(os.path.exists(proj_path), "project.godot exists")
    with open(proj_path, "r", encoding="utf-8") as f:
        proj_content = f.read()

    autoload_match = re.search(r'TutorialManager="\*res://scripts/autoload/tutorial_manager\.gd"', proj_content)
    check(bool(autoload_match), "TutorialManager autoload correctly registered in project.godot")

    # 2. Inspect scripts/autoload/tutorial_manager.gd
    print("\n--- 2. tutorial_manager.gd Structure & FSM Inspection ---")
    tm_path = os.path.join(base_dir, "scripts", "autoload", "tutorial_manager.gd")
    check(os.path.exists(tm_path), "scripts/autoload/tutorial_manager.gd exists")
    with open(tm_path, "r", encoding="utf-8") as f:
        tm_src = f.read()

    # Check class declaration and inheritance
    check("extends Node" in tm_src, "Extends Node")
    check("class_name TutorialManagerClass" in tm_src or "class_name" in tm_src, "Class name declared")

    # Check 8-state FSM
    states = [
        "IDLE", "INTRO_STEP_1_TAP", "INTRO_STEP_2_UPGRADE", "INTRO_STEP_3_FRENZY",
        "INTRO_STEP_4_CAMPUS", "INTRO_STEP_5_COLLECTIBLE", "INTRO_STEP_6_STATION", "COMPLETED"
    ]
    for st in states:
        check(st in tm_src, f"FSM defines state '{st}'")

    # Check signals
    signals = [
        "step_started", "step_completed", "tutorial_completed",
        "tutorial_skipped", "contextual_hint_triggered"
    ]
    for sig in signals:
        check(f"signal {sig}" in tm_src, f"Declares signal '{sig}'")

    # Check core methods
    methods = [
        "start_linear_intro", "advance_step", "skip_tutorial",
        "trigger_contextual_hint", "get_current_step", "is_tutorial_active",
        "should_start_intro", "reset_tutorial", "on_scene_ready"
    ]
    for m in methods:
        check(f"func {m}" in tm_src, f"Declares method '{m}'")

    # Check German Angel Investor copy
    german_phrases = [
        "Angel Investor", "Pre-Seed // Erste Traktion", "Reaktorkern",
        "Virale Memes", "Overdrive // Viraler Hype", "Campus // 3D-Navigation",
        "virtuellen Joystick", "Sammelradius", "Server-Overclock",
        "[E] Hack", "Unicorn-Ready", "Los geht's"
    ]
    for phrase in german_phrases:
        check(phrase in tm_src, f"German copy includes '{phrase}'")

    # Check absence of lazy cheats / stubs
    forbidden = ["TODO", "FIXME", "XXX", "dummy_pass", "return true # stub"]
    for fb in forbidden:
        check(fb not in tm_src, f"tutorial_manager.gd does not contain '{fb}'")

    # 3. Inspect scenes/main.tscn
    print("\n--- 3. scenes/main.tscn Hierarchy Inspection ---")
    main_tscn_path = os.path.join(base_dir, "scenes", "main.tscn")
    check(os.path.exists(main_tscn_path), "scenes/main.tscn exists")
    with open(main_tscn_path, "r", encoding="utf-8") as f:
        main_tscn = f.read()

    check('name="DialogueLayer" type="CanvasLayer"' in main_tscn, "DialogueLayer CanvasLayer exists in main.tscn")
    check('layer = 96' in main_tscn, "DialogueLayer layer set to 96")
    check('name="DialoguePanel" parent="DialogueLayer"' in main_tscn, "DialoguePanel instanced under DialogueLayer")

    # 4. Invariant: scenes/dialogue_panel.tscn
    print("\n--- 4. dialogue_panel.tscn Invariant Verification ---")
    dp_tscn_path = os.path.join(base_dir, "scenes", "dialogue_panel.tscn")
    check(os.path.exists(dp_tscn_path), "scenes/dialogue_panel.tscn exists")
    with open(dp_tscn_path, "r", encoding="utf-8") as f:
        dp_tscn = f.read()

    button_matches = re.findall(r'type="Button"', dp_tscn)
    check(len(button_matches) == 6, f"dialogue_panel.tscn contains EXACTLY 6 Button nodes (found: {len(button_matches)})")

    card_min_size = re.search(r'custom_minimum_size\s*=\s*Vector2\(\s*(\d+)\s*,\s*(\d+)\s*\)', dp_tscn)
    if card_min_size:
        w, h = int(card_min_size.group(1)), int(card_min_size.group(2))
        check(w >= 500 and h >= 480, f"CardPanel custom_minimum_size >= (500, 480) (actual: {w}x{h})")
    else:
        check(False, "CardPanel custom_minimum_size found in dialogue_panel.tscn")

    # 5. Inspect tests/test_tutorial_flow.gd for cheating / tautologies
    print("\n--- 5. test_tutorial_flow.gd Genuineness Inspection ---")
    test_path = os.path.join(base_dir, "tests", "test_tutorial_flow.gd")
    check(os.path.exists(test_path), "tests/test_tutorial_flow.gd exists")
    with open(test_path, "r", encoding="utf-8") as f:
        test_src = f.read()

    # Look for assert(true) or 1 == 1
    tautologies = re.findall(r'assert\s*\(\s*(true|1\s*==\s*1)\s*\)', test_src)
    check(len(tautologies) == 0, f"Zero tautological assert(true) or (1 == 1) found (found: {len(tautologies)})")

    # Check for _assert_check(true, ...) without conditional
    unconditional_pass = re.findall(r'_assert_check\s*\(\s*true\s*,', test_src)
    check(len(unconditional_pass) == 0, f"Zero unconditional _assert_check(true, ...) found (found: {len(unconditional_pass)})")

    # Count real assertions
    assert_calls = re.findall(r'_assert_check\s*\(', test_src)
    check(len(assert_calls) >= 70, f"test_tutorial_flow.gd contains >= 70 assertions (found: {len(assert_calls)})")

    print("\n" + "=" * 65)
    print(f"ORACLE RESULTS: {PASS_COUNT} Passed, {FAIL_COUNT} Failed out of {PASS_COUNT + FAIL_COUNT} Checks")
    print("=" * 65)

    sys.exit(0 if FAIL_COUNT == 0 else 1)

if __name__ == "__main__":
    main()
