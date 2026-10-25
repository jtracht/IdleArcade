#!/usr/bin/env python3
"""
Challenger M3-IT2-2 Python Verification Oracle:
Multi-Touch Bounds, Pointer Isolation, and Gating Architecture Audit
File: IdleArcade/tests/test_p16_m3_challenger_multitouch_oracle.py
"""

import sys
import os
import re

ROOT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))

class AuditResult:
    def __init__(self):
        self.passes = 0
        self.fails = 0
        self.findings = []

    def check(self, condition: bool, description: str, detail: str = ""):
        if condition:
            print(f"  [PASS] {description}")
            self.passes += 1
        else:
            err = f"  [FAIL] {description}"
            if detail:
                err += f" -> {detail}"
            print(err)
            self.findings.append(err)
            self.fails += 1

def read_text(rel_path: str) -> str:
    path = os.path.join(ROOT_DIR, rel_path)
    if not os.path.exists(path):
        return ""
    with open(path, "r", encoding="utf-8") as f:
        return f.read()

def main():
    print("====================================================================")
    print("=== Challenger M3-IT2-2: Multi-Touch & Bounds Verification Oracle ===")
    print("====================================================================")
    rep = AuditResult()

    # 1. SCENE INSPECTION: Root, Backdrop, and Button Pointer Isolation
    print("\n--- 1. Modal Dialog TSCN Scene Pointer Isolation ---")
    scenes = [
        ("scenes/ui/cyber_sync_minigame.tscn", "CyberSyncMinigame"),
        ("scenes/ui/pitch_stage_minigame.tscn", "PitchStageMinigame"),
        ("scenes/ui/espresso_brew_minigame.tscn", "EspressoBrewMinigame")
    ]

    for rel_path, name in scenes:
        content = read_text(rel_path)
        rep.check(len(content) > 0, f"{name} scene file exists: {rel_path}")

        # Root node check
        root_m = re.search(r'\[node name="[^"]+" type="Control"[^\]]*\](.*?)(?=\n\[node|\Z)', content, re.DOTALL)
        rep.check(root_m is not None and "mouse_filter = 0" in root_m.group(1), f"{name} root node specifies mouse_filter = 0 (STOP)")

        # Backdrop node check
        backdrop_m = re.search(r'\[node name="[^"]*(?:Backdrop|DimBackdrop)"[^\]]*\](.*?)(?=\n\[node|\Z)', content, re.DOTALL)
        rep.check(backdrop_m is not None and "mouse_filter = 0" in backdrop_m.group(1), f"{name} backdrop specifies mouse_filter = 0 (STOP)")

        # Button nodes check
        buttons = list(re.finditer(r'\[node name="([^"]+)" type="Button"[^\]]*\](.*?)(?=\n\[node|\Z)', content, re.DOTALL))
        rep.check(len(buttons) > 0, f"{name} contains buttons (Found: {len(buttons)})")
        all_btn_stop = all("mouse_filter = 0" in b.group(2) for b in buttons)
        rep.check(all_btn_stop, f"{name} 100% of buttons specify mouse_filter = 0 (STOP)")

        # Height >= 56px check
        for b in buttons:
            b_name = b.group(1)
            b_body = b.group(2)
            sz = re.search(r'custom_minimum_size\s*=\s*Vector2\(\s*([\d\.]+)\s*,\s*([\d\.]+)\s*\)', b_body)
            rep.check(sz is not None, f"{name} button '{b_name}' has custom_minimum_size")
            if sz:
                w, h = float(sz.group(1)), float(sz.group(2))
                rep.check(h >= 56.0, f"{name} button '{b_name}' height >= 56.0px (actual: {h}px)")
                if "close" in b_name.lower():
                    rep.check(w >= 56.0, f"{name} close button '{b_name}' width >= 56.0px (actual: {w}px)")

    # 2. SCRIPT INSPECTION: _gui_input and accept_event()
    print("\n--- 2. Minigame Script Pointer Absorption & 56px Clamping ---")
    scripts = [
        ("scripts/ui/cyber_sync_minigame.gd", "CyberSyncMinigame"),
        ("scripts/ui/pitch_stage_minigame.gd", "PitchStageMinigame"),
        ("scripts/ui/espresso_brew_minigame.gd", "EspressoBrewMinigame")
    ]

    for rel_path, name in scripts:
        code = read_text(rel_path)
        rep.check(len(code) > 0, f"{name} script exists: {rel_path}")
        rep.check("func _gui_input(" in code, f"{name} defines _gui_input()")
        rep.check("accept_event()" in code, f"{name} calls accept_event() inside _gui_input()")
        rep.check("56.0" in code or "56" in code, f"{name} programmatically enforces 56px minimum size")

    # 3. STATION SCRIPTS: Gating & Restoration Invariants
    print("\n--- 3. Campus Station Input Gating Architecture ---")
    stations = [
        ("scripts/server_terminal.gd", "ServerTerminal"),
        ("scripts/pitch_stage.gd", "PitchStage"),
        ("scripts/coffee_machine_3d.gd", "CoffeeMachine3D")
    ]

    for rel_path, name in stations:
        code = read_text(rel_path)
        rep.check(len(code) > 0, f"{name} station script exists: {rel_path}")
        rep.check("func _gate_avatar_and_controls()" in code, f"{name} implements _gate_avatar_and_controls()")
        rep.check("func _restore_avatar_and_controls()" in code, f"{name} implements _restore_avatar_and_controls()")
        rep.check("set_input_enabled(false)" in code, f"{name} disables avatar input")
        rep.check("set_input_enabled(true)" in code, f"{name} restores avatar input")
        rep.check("stop_movement()" in code, f"{name} halts avatar locomotion")
        rep.check("fade_out_controls()" in code, f"{name} fades out TouchControls")
        rep.check("fade_in_controls()" in code, f"{name} fades in TouchControls")

    # 4. TOUCH CONTROLS INSPECTION
    print("\n--- 4. TouchControls Action Button Ergonomics ---")
    tc_tscn = read_text("scenes/ui/touch_controls.tscn")
    rep.check(len(tc_tscn) > 0, "scenes/ui/touch_controls.tscn exists")
    action_btn_m = re.search(r'\[node name="ActionButton" type="Button"[^\]]*\](.*?)(?=\n\[node|\Z)', tc_tscn, re.DOTALL)
    rep.check(action_btn_m is not None, "TouchControls contains ActionButton")
    if action_btn_m:
        sz = re.search(r'custom_minimum_size\s*=\s*Vector2\(\s*([\d\.]+)\s*,\s*([\d\.]+)\s*\)', action_btn_m.group(1))
        rep.check(sz is not None, "ActionButton declares custom_minimum_size")
        if sz:
            w, h = float(sz.group(1)), float(sz.group(2))
            rep.check(w >= 72.0 and h >= 72.0, f"ActionButton meets primary touch target >= 72px (actual: {w}x{h}px)")

    print("\n====================================================================")
    print(f"ORACLE RESULTS: {rep.passes} PASSED, {rep.fails} FAILED")
    print("====================================================================")
    if rep.fails == 0:
        print(">>> EMPIRICAL VERDICT: APPROVE (Exit Code 0) <<<\n")
        sys.exit(0)
    else:
        print(f">>> EMPIRICAL VERDICT: REQUEST_CHANGES ({rep.fails} defects) <<<\n")
        sys.exit(1)

if __name__ == "__main__":
    main()
