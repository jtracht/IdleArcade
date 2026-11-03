#!/usr/bin/env python3
"""
EMPIRICAL CHALLENGER ADVERSARIAL ORACLE (Milestone 3)
Target: IdleArcade Phase 17 Milestone 3 (F10 - F18)
Author: p17_m3_challenger_gen2_2 (EMPIRICAL CHALLENGER)
"""

import os
import re
import sys
import subprocess

PROJECT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))

passed_checks = 0
failed_checks = 0

def check(condition: bool, description: str):
    global passed_checks, failed_checks
    if condition:
        passed_checks += 1
        print(f"  [PASS] {description}")
    else:
        failed_checks += 1
        print(f"  [FAIL] {description}")

def read_file(rel_path: str) -> str:
    path = os.path.join(PROJECT_DIR, rel_path)
    if not os.path.exists(path):
        print(f"File not found: {path}")
        return ""
    with open(path, "r", encoding="utf-8", errors="replace") as f:
        return f.read()

def main():
    print("=" * 70)
    print("EMPIRICAL CHALLENGER PYTHON ORACLE: MILESTONE 3 ADVERSARIAL AUDIT")
    print("=" * 70)

    # --------------------------------------------------------------------------
    # SUITE 1: Settings Modal Touch Ergonomics & mouse_filter
    # --------------------------------------------------------------------------
    print("\n--- SUITE 1: %ReplayTutorialButton Touch Ergonomics & Attributes ---")
    settings_tscn = read_file("scenes/ui/settings_modal.tscn")
    check(len(settings_tscn) > 0, "scenes/ui/settings_modal.tscn exists")
    
    # Check ReplayTutorialButton node
    btn_match = re.search(r'\[node name="ReplayTutorialButton" type="Button" parent="([^"]+)"\](.*?)(\n\[|$)', settings_tscn, re.DOTALL)
    check(btn_match is not None, "ReplayTutorialButton declared in scenes/ui/settings_modal.tscn")
    if btn_match:
        btn_body = btn_match.group(2)
        
        # custom_minimum_size
        size_match = re.search(r'custom_minimum_size\s*=\s*Vector2\(\s*([\d\.]+)\s*,\s*([\d\.]+)\s*\)', btn_body)
        check(size_match is not None, "ReplayTutorialButton has explicit custom_minimum_size")
        if size_match:
            width = float(size_match.group(1))
            height = float(size_match.group(2))
            check(height >= 56.0, f"ReplayTutorialButton height >= 56px (actual: {height}px)")
            check(width >= 56.0, f"ReplayTutorialButton width >= 56px (actual: {width}px)")
            
        # mouse_filter
        mf_match = re.search(r'mouse_filter\s*=\s*(\d+)', btn_body)
        check(mf_match is not None and mf_match.group(1) == "0", 
              f"ReplayTutorialButton mouse_filter == 0 (Control.MOUSE_FILTER_STOP) (actual: {mf_match.group(1) if mf_match else 'missing'})")
        
        # focus_mode = 0 (FOCUS_NONE)
        fm_match = re.search(r'focus_mode\s*=\s*(\d+)', btn_body)
        check(fm_match is not None and fm_match.group(1) == "0", 
              f"ReplayTutorialButton focus_mode == 0 (FOCUS_NONE) (actual: {fm_match.group(1) if fm_match else 'missing'})")

    settings_gd = read_file("scripts/ui/settings_modal.gd")
    check("func _on_replay_tutorial_pressed" in settings_gd, "settings_modal.gd implements _on_replay_tutorial_pressed()")
    check("gs.reset_tutorial_state()" in settings_gd, "settings_modal.gd invokes GameState.reset_tutorial_state()")
    check("tm.reset_tutorial()" in settings_gd, "settings_modal.gd invokes TutorialManager.reset_tutorial()")
    check("tutorial_replay_triggered.emit()" in settings_gd, "settings_modal.gd emits tutorial_replay_triggered")

    # --------------------------------------------------------------------------
    # SUITE 2: Null Safety Across 6 Hook Point Scripts
    # --------------------------------------------------------------------------
    print("\n--- SUITE 2: Null Safety & Defensiveness in 6 Hook Point Scripts ---")
    
    hook_files = {
        "zone_gate_3d": ("scripts/zone_gate_3d.gd", "hint_zone_gate"),
        "tech_tree_modal": ("scripts/ui/tech_tree_modal.gd", "hint_tech_tree"),
        "staff_modal": ("scripts/ui/staff_modal.gd", "hint_staff"),
        "server_terminal": ("scripts/server_terminal.gd", "hint_minigame"),
        "daily_board_3d": ("scripts/daily_board_3d.gd", "hint_daily_board"),
        "ipo_bell_3d": ("scripts/ipo_bell_3d.gd", "hint_ipo_bell"),
    }
    
    for name, (path, hint_id) in hook_files.items():
        code = read_file(path)
        check(len(code) > 0, f"{path} exists")
        check(hint_id in code, f"{path} contains hook for '{hint_id}'")
        
        # Defensiveness check: must use get_node_or_null or null check before calling trigger_contextual_hint
        safe_tm_pattern = re.search(r'(get_node_or_null\([\'"]/root/TutorialManager[\'"]\)|TutorialManager\s*!=\s*null|if\s+tm\s*!=\s*null)', code)
        check(safe_tm_pattern is not None, f"{name}: Guards TutorialManager against null access")
        
        # Must not contain unguarded TutorialManager.trigger_contextual_hint
        unguarded = re.search(r'(?<!if\s)[^#\n]*\bTutorialManager\.trigger_contextual_hint', code)
        check(unguarded is None, f"{name}: No raw unchecked TutorialManager.trigger_contextual_hint calls")

    # --------------------------------------------------------------------------
    # SUITE 3: Contextual Hint Non-Blocking & Dismiss Wiring
    # --------------------------------------------------------------------------
    print("\n--- SUITE 3: Contextual Hint Non-Blocking Dismiss & Blocker Cleanup ---")
    tm_gd = read_file("scripts/autoload/tutorial_manager.gd")
    check("hint_dismissed.connect(_on_contextual_hint_dismissed)" in tm_gd, 
          "TutorialManager connects DialoguePanel.hint_dismissed to _on_contextual_hint_dismissed")
    check("tutorial_overlay.clear_highlight()" in tm_gd, 
          "TutorialManager._on_contextual_hint_dismissed calls tutorial_overlay.clear_highlight()")

    dp_gd = read_file("scripts/dialogue_panel.gd")
    check("func show_hint_popup" in dp_gd, "dialogue_panel.gd defines show_hint_popup()")
    check("mouse_filter = Control.MOUSE_FILTER_IGNORE" in dp_gd, "dialogue_panel.gd sets root mouse_filter = IGNORE during hint")
    check("backdrop.visible = false" in dp_gd, "dialogue_panel.gd hides DimBackdrop during hint")
    check("backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE" in dp_gd, "dialogue_panel.gd sets backdrop mouse_filter = IGNORE during hint")
    check("func dismiss_hint" in dp_gd, "dialogue_panel.gd defines dismiss_hint()")
    check("hint_dismissed.emit" in dp_gd, "dialogue_panel.gd emits hint_dismissed signal")

    to_gd = read_file("scripts/ui/tutorial_overlay.gd")
    check("func clear_highlight" in to_gd, "tutorial_overlay.gd defines clear_highlight()")
    check("top_blocker.visible = false" in to_gd, "clear_highlight hides top_blocker")
    check("top_blocker.size = Vector2.ZERO" in to_gd, "clear_highlight sets top_blocker.size = Vector2.ZERO")
    check("bottom_blocker.visible = false" in to_gd, "clear_highlight hides bottom_blocker")
    check("bottom_blocker.size = Vector2.ZERO" in to_gd, "clear_highlight sets bottom_blocker.size = Vector2.ZERO")
    check("left_blocker.visible = false" in to_gd, "clear_highlight hides left_blocker")
    check("left_blocker.size = Vector2.ZERO" in to_gd, "clear_highlight sets left_blocker.size = Vector2.ZERO")
    check("right_blocker.visible = false" in to_gd, "clear_highlight hides right_blocker")
    check("right_blocker.size = Vector2.ZERO" in to_gd, "clear_highlight sets right_blocker.size = Vector2.ZERO")

    # --------------------------------------------------------------------------
    # SUITE 4: GameState Persistence Invariants & Truth Table
    # --------------------------------------------------------------------------
    print("\n--- SUITE 4: GameState Persistence Invariants ---")
    gs_gd = read_file("scripts/autoload/game_state.gd")
    check("var tutorial_current_step: int = 0" in gs_gd, "GameState declares tutorial_current_step")
    check("var tutorial_completed: bool = false" in gs_gd, "GameState declares tutorial_completed")
    check("var tutorial_skipped: bool = false" in gs_gd, "GameState declares tutorial_skipped")
    check("var tutorial_replay_requested: bool = false" in gs_gd, "GameState declares tutorial_replay_requested")
    check("var tutorial_seen_hints: Dictionary = {}" in gs_gd, "GameState declares tutorial_seen_hints")
    check("func is_first_time_player() -> bool:" in gs_gd, "GameState declares is_first_time_player()")
    check("func reset_tutorial_state() -> void:" in gs_gd, "GameState declares reset_tutorial_state()")
    check("func mark_contextual_hint_seen" in gs_gd, "GameState declares mark_contextual_hint_seen()")
    check("func has_seen_contextual_hint" in gs_gd, "GameState declares has_seen_contextual_hint()")

    # --------------------------------------------------------------------------
    # SUITE 5: Execution of GDScript Adversarial Stress Harness & Script Error Check
    # --------------------------------------------------------------------------
    print("\n--- SUITE 5: Headless Execution & Zero SCRIPT ERROR Verification ---")
    cmd = ["godot", "--headless", "--path", "IdleArcade", "-s", "tests/test_p17_m3_challenger_adversarial.gd"]
    res = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, cwd=os.path.dirname(PROJECT_DIR))
    
    script_errors = [line for line in res.stdout.splitlines() if "SCRIPT ERROR" in line]
    check(len(script_errors) == 0, f"Headless execution has 0 SCRIPT ERRORs (found: {len(script_errors)})")
    if len(script_errors) > 0:
        for err in script_errors:
            print(f"    Error: {err}")
            
    check(res.returncode == 0, f"Adversarial GDScript harness exited with code 0 (actual: {res.returncode})")
    check("Challenger Results: " in res.stdout and ", 0 Failed" in res.stdout, "Adversarial GDScript harness reported 0 Failed")

    print("\n" + "=" * 70)
    print(f"ADVERSARIAL ORACLE SUMMARY: {passed_checks} Passed, {failed_checks} Failed")
    print("=" * 70)

    if failed_checks > 0:
        sys.exit(1)
    else:
        sys.exit(0)

if __name__ == "__main__":
    main()
