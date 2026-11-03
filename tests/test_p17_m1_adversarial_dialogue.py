"""
Adversarial Verification Oracle & Subprocess Runner for DialoguePanel Integrity
Phase 17 Milestone 1 - Challenger 2
Validates:
1. AST structure and regression invariants in scripts/dialogue_panel.gd and scenes/dialogue_panel.tscn
2. Headless execution of tests/test_p17_m1_adversarial_dialogue.gd with 0 SCRIPT ERRORs and exit code 0
3. Complete regression safety against test_tutorial_ui_ergonomics.gd and test_phase11_dialogue_stress.py
"""

import os
import re
import subprocess
import sys
from pathlib import Path

GAME_DIR = Path(__file__).resolve().parent.parent
ROOT_DIR = GAME_DIR.parent

class ChallengerReporter:
    def __init__(self):
        self.passes = 0
        self.fails = 0
        self.results = []

    def check(self, condition: bool, description: str, detail: str = "") -> bool:
        if condition:
            print(f"  [PASS] {description}")
            self.passes += 1
            self.results.append((True, description))
            return True
        else:
            err = f"  [FAIL] {description}"
            if detail:
                err += f" (Detail: {detail})"
            print(err)
            self.fails += 1
            self.results.append((False, description))
            return False

def test_ast_and_invariants(rep: ChallengerReporter):
    print("\n--- TIER 1: DialoguePanel AST & Static Contract Invariants ---")
    gd_file = GAME_DIR / "scripts/dialogue_panel.gd"
    tscn_file = GAME_DIR / "scenes/dialogue_panel.tscn"
    
    rep.check(gd_file.exists(), "scripts/dialogue_panel.gd exists on disk")
    rep.check(tscn_file.exists(), "scenes/dialogue_panel.tscn exists on disk")
    
    gd_text = gd_file.read_text(encoding="utf-8")
    tscn_text = tscn_file.read_text(encoding="utf-8")
    
    # Invariant: exactly 6 Button nodes declared in tscn
    button_matches = re.findall(r'\[node name="(\w+)" type="Button"', tscn_text)
    rep.check(len(button_matches) == 6, f"Exactly 6 Button nodes in dialogue_panel.tscn (found: {len(button_matches)})")
    
    # Invariant: open_for_tutorial_step exists and declares expected arguments
    rep.check("func open_for_tutorial_step(" in gd_text, "open_for_tutorial_step defined in dialogue_panel.gd")
    rep.check("func show_hint_popup(" in gd_text, "show_hint_popup defined in dialogue_panel.gd")
    rep.check("signal tutorial_advanced()" in gd_text, "signal tutorial_advanced() declared")
    rep.check("signal hint_dismissed(hint_id: String)" in gd_text, "signal hint_dismissed(hint_id: String) declared")
    
    # Invariant: CardPanel default custom_minimum_size in tscn is 500x480
    rep.check('custom_minimum_size = Vector2(500, 480)' in tscn_text, "tscn declares CardPanel custom_minimum_size = Vector2(500, 480)")
    
    # Invariant: _restore_default_ui_state restores Vector2(500, 480)
    rep.check('card.custom_minimum_size = Vector2(500, 480)' in gd_text, "_restore_default_ui_state restores CardPanel to Vector2(500, 480)")
    
    # Defensive programming: is_instance_valid checked for _avatar_ref
    instance_valid_count = gd_text.count("is_instance_valid(_avatar_ref)")
    rep.check(instance_valid_count >= 3, f"_avatar_ref guarded with is_instance_valid (found {instance_valid_count} occurrences)")

def test_headless_godot_execution(rep: ChallengerReporter):
    print("\n--- TIER 2: Empirical Headless Execution of Adversarial Suite ---")
    cmd = ["godot", "--headless", "--path", str(GAME_DIR), "-s", "tests/test_p17_m1_adversarial_dialogue.gd"]
    
    print(f"Executing: {' '.join(cmd)}")
    proc = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=60)
    
    output = proc.stdout + "\n" + proc.stderr
    
    rep.check(proc.returncode == 0, f"Headless execution exited with code 0 (actual: {proc.returncode})")
    
    # Zero SCRIPT ERROR standard
    script_errors = re.findall(r"SCRIPT ERROR:.*", output)
    rep.check(len(script_errors) == 0, f"Zero SCRIPT ERROR occurrences in headless runner (found: {len(script_errors)})")
    
    # Check that all 58 assertions passed in output
    rep.check("Passed: 58, Failed: 0" in output, "Adversarial test runner reported 58 Passed, 0 Failed")

def test_regression_safety(rep: ChallengerReporter):
    print("\n--- TIER 3: Regression Safety Battery Against Baseline Suites ---")
    
    # 1. Milestone 1 Tutorial UI Ergonomics Suite
    cmd1 = ["godot", "--headless", "--path", str(GAME_DIR), "-s", "tests/test_tutorial_ui_ergonomics.gd"]
    proc1 = subprocess.run(cmd1, capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=60)
    rep.check(proc1.returncode == 0, "test_tutorial_ui_ergonomics.gd exited with code 0")
    rep.check("63 Passed, 0 Failed" in proc1.stdout, "test_tutorial_ui_ergonomics.gd reported 63 Passed, 0 Failed")
    
    # 2. Phase 11 Dialogue Stress Python Suite
    cmd2 = [sys.executable, str(GAME_DIR / "tests/test_phase11_dialogue_stress.py")]
    proc2 = subprocess.run(cmd2, capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=60)
    rep.check(proc2.returncode == 0, "test_phase11_dialogue_stress.py exited with code 0")
    rep.check("112 Passed, 0 Failed out of 112 Checks" in proc2.stdout, "test_phase11_dialogue_stress.py reported 112 Passed, 0 Failed")

def main():
    print("======================================================================")
    print("CHALLENGER 2: EMPIRICAL VERIFICATION HARNESS (PHASE 17 MILESTONE 1)")
    print("======================================================================")
    
    rep = ChallengerReporter()
    test_ast_and_invariants(rep)
    test_headless_godot_execution(rep)
    test_regression_safety(rep)
    
    print("\n======================================================================")
    print(f"CHALLENGER 2 HARNESS RESULTS: {rep.passes} Passed, {rep.fails} Failed")
    print("======================================================================")
    
    if rep.fails == 0:
        print("\n>>> EMPIRICAL VERDICT: ALL ADVERSARIAL STRESS CHALLENGES PASSED! <<<")
        sys.exit(0)
    else:
        print(f"\n>>> EMPIRICAL VERDICT: {rep.fails} CHALLENGES FAILED! <<<")
        sys.exit(1)

if __name__ == "__main__":
    main()
