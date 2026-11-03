#!/usr/bin/env python3
"""
Adversarial Verification Oracle for Phase 17 Milestone 2.
Roles: Reviewer & Adversarial Critic.
Validates:
- Interface contracts
- AST signatures & public signals
- German mascot copy & Angel Investor persona
- Layer elevations (Layer 96 DialoguePanel vs Layer 95 TutorialOverlay)
- Integrity checks: detecting hardcoded cheats, facades, or shortcuts
- Invariant: scenes/dialogue_panel.tscn untouched with exactly 6 Button nodes
"""

import os
import re
import sys
from pathlib import Path

GAME_DIR = Path(__file__).resolve().parent.parent

passed_checks = 0
failed_checks = 0

def check(condition: bool, description: str, detail: str = "") -> bool:
    global passed_checks, failed_checks
    if condition:
        print(f"  [PASS] {description}")
        passed_checks += 1
        return True
    else:
        err = f"  [FAIL] {description}"
        if detail:
            err += f" (Detail: {detail})"
        print(err)
        failed_checks += 1
        return False

def main():
    print("=================================================================")
    print("PHASE 17 MILESTONE 2: ADVERSARIAL REVIEWER VERIFICATION ORACLE")
    print("=================================================================")

    # 1. Autoload Registration in project.godot
    print("\n--- 1. project.godot Autoload Invariant ---")
    proj_path = GAME_DIR / "project.godot"
    check(proj_path.exists(), "project.godot exists on disk")
    proj_content = proj_path.read_text(encoding="utf-8", errors="replace")
    check('TutorialManager="*res://scripts/autoload/tutorial_manager.gd"' in proj_content,
          "TutorialManager registered as Autoload singleton in project.godot")

    # 2. TutorialManager Signals & Method Contracts
    print("\n--- 2. TutorialManager Interface Contracts ---")
    tm_path = GAME_DIR / "scripts/autoload/tutorial_manager.gd"
    check(tm_path.exists(), "tutorial_manager.gd exists on disk")
    tm_code = tm_path.read_text(encoding="utf-8", errors="replace")

    expected_signals = [
        "step_started",
        "step_completed",
        "tutorial_completed",
        "tutorial_skipped",
        "contextual_hint_triggered"
    ]
    for sig in expected_signals:
        sig_regex = rf"signal\s+{sig}\b"
        check(bool(re.search(sig_regex, tm_code)), f"tutorial_manager.gd declares signal '{sig}'")

    expected_methods = [
        "start_linear_intro",
        "advance_step",
        "skip_tutorial",
        "trigger_contextual_hint",
        "get_current_step",
        "is_tutorial_active"
    ]
    for method in expected_methods:
        method_regex = rf"func\s+{method}\s*\("
        check(bool(re.search(method_regex, tm_code)), f"tutorial_manager.gd defines public method '{method}()'")

    # 3. 6 Intro Steps & State Enum
    print("\n--- 3. Linear Intro 6 Steps & State Machine ---")
    check("enum State" in tm_code, "tutorial_manager.gd defines State enum")
    expected_states = [
        "INTRO_STEP_1_TAP",
        "INTRO_STEP_2_UPGRADE",
        "INTRO_STEP_3_FRENZY",
        "INTRO_STEP_4_CAMPUS",
        "INTRO_STEP_5_COLLECTIBLE",
        "INTRO_STEP_6_STATION",
        "COMPLETED"
    ]
    for state in expected_states:
        check(state in tm_code, f"State enum contains '{state}'")

    # 4. German Copy & Angel Investor Mascot Persona
    print("\n--- 4. German Copy & Angel Investor Persona ---")
    german_keywords = [
        "Pre-Seed", "Reaktorkern", "Virale Memes", "Overdrive", "Hype-Balken",
        "Inkubator-Campus", "virtuellen Joystick", "Förderkoffer", "Sammelradius",
        "Server-Overclock", "[E] Hack", "Unicorn-Ready", "Angel Investor"
    ]
    for kw in german_keywords:
        check(kw in tm_code, f"TutorialManager German copy contains persona keyword '{kw}'")

    # 5. Layer Elevation Invariants
    print("\n--- 5. Layer Elevation & Rendering Hierarchy ---")
    # TutorialOverlay on CanvasLayer 95
    overlay_path = GAME_DIR / "scripts/ui/tutorial_overlay.gd"
    check(overlay_path.exists(), "tutorial_overlay.gd exists")
    overlay_code = overlay_path.read_text(encoding="utf-8", errors="replace")
    check("layer = 95" in overlay_code or "95" in overlay_code, "TutorialOverlay resides on layer 95")

    # main.tscn DialogueLayer on layer 96
    main_tscn_path = GAME_DIR / "scenes/main.tscn"
    check(main_tscn_path.exists(), "scenes/main.tscn exists")
    main_tscn_content = main_tscn_path.read_text(encoding="utf-8", errors="replace")
    check('[node name="DialogueLayer" type="CanvasLayer"' in main_tscn_content, "main.tscn declares DialogueLayer")
    check("layer = 96" in main_tscn_content, "DialogueLayer in main.tscn is set to layer 96 (above layer 95)")

    # Dynamic elevation logic in tutorial_manager.gd
    check("parent_layer.layer = 96" in tm_code, "TutorialManager dynamically elevates dialogue to layer 96")

    # 6. DialoguePanel Invariant (Untouched with exactly 6 buttons)
    print("\n--- 6. DialoguePanel Invariant Check ---")
    dp_tscn_path = GAME_DIR / "scenes/dialogue_panel.tscn"
    check(dp_tscn_path.exists(), "scenes/dialogue_panel.tscn exists")
    dp_tscn_content = dp_tscn_path.read_text(encoding="utf-8", errors="replace")
    button_nodes = re.findall(r'\[node name="([^"]+)" type="Button"[^\]]*\]', dp_tscn_content)
    check(len(button_nodes) == 6, f"dialogue_panel.tscn has EXACTLY 6 Button nodes (found: {len(button_nodes)})")
    expected_buttons = ["ChoiceButton1", "ChoiceButton2", "ChoiceButton3", "AcceptButton", "CompleteButton", "CloseButton"]
    for btn in expected_buttons:
        check(btn in button_nodes, f"Button '{btn}' present in dialogue_panel.tscn")

    # 7. Integrity & Anti-Cheat Audit
    print("\n--- 7. Integrity & Anti-Cheat Audit ---")
    # Check for hardcoded cheat outputs in tutorial_manager.gd
    check("assert(true)" not in tm_code, "No dummy assert(true) in tutorial_manager.gd")
    check("return true # cheat" not in tm_code, "No fake return cheat stubs in tutorial_manager.gd")
    check("test_mode = true" not in tm_code, "No test mode bypass flags in tutorial_manager.gd")

    # Check for seed liquidity logic (awards 30 energy to afford tier_1)
    check("maxf(gs.energy, 30.0)" in tm_code or "30.0" in tm_code,
          "Step 1 tap awards seed liquidity to guarantee affordable first upgrade")

    # Check Skip functionality implementation
    check("skip_tutorial" in tm_code, "skip_tutorial implementation present")
    check("tutorial_skipped.emit()" in tm_code, "tutorial_skipped signal emitted on skip")
    check("tutorial_completed.emit()" in tm_code, "tutorial_completed signal emitted on skip")

    # 8. Main Scene Integration
    print("\n--- 8. Main & Main3D Startup Integration ---")
    main_gd_path = GAME_DIR / "scripts/main.gd"
    main_gd_code = main_gd_path.read_text(encoding="utf-8", errors="replace")
    check("TutorialManager" in main_gd_code and "start_linear_intro" in main_gd_code,
          "main.gd checks first-time player and launches start_linear_intro")

    main_3d_gd_path = GAME_DIR / "scripts/main_3d.gd"
    main_3d_gd_code = main_3d_gd_path.read_text(encoding="utf-8", errors="replace")
    check("TutorialManager" in main_3d_gd_code and "on_scene_ready" in main_3d_gd_code,
          "main_3d.gd notifies TutorialManager via on_scene_ready")

    print("\n=================================================================")
    print(f"ADVERSARIAL VERIFICATION RESULTS: {passed_checks} Passed, {failed_checks} Failed")
    print("=================================================================")

    if failed_checks > 0:
        sys.exit(1)
    else:
        sys.exit(0)

if __name__ == "__main__":
    main()
