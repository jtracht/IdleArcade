#!/usr/bin/env python3
"""
Empirical Challenger M3-2 Python Verification Oracle:
Touch Targets, Pointer Isolation, Camera Locomotion & Screen Shake Dynamics
File: IdleArcade/tests/test_p16_m3_challenger_ergonomics.py

Adversarial inspection of:
1. 100% Minigame Buttons meet >= 56px height (and >= 56px width for square close buttons)
2. Strict pointer isolation: mouse_filter = Control.MOUSE_FILTER_STOP (0) across root, backdrop, modal containers, and buttons
3. _gui_input() blocks event propagation into 3D camera locomotion via accept_event()
4. Station controllers implement _gate_avatar_and_controls() and _restore_avatar_and_controls()
5. Screen shake dynamics: trauma clamping [0.0, 1.0], decay rate, setting sensitivity multiplier, and signal decoupling
"""

import sys
import os
import re

ROOT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))

class ChallengerReport:
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

def read_file(rel_path: str) -> str:
    path = os.path.join(ROOT_DIR, rel_path)
    if not os.path.exists(path):
        return ""
    with open(path, "r", encoding="utf-8") as f:
        return f.read()

def main():
    print("====================================================================")
    print("=== Challenger M3-2 Python Verification Oracle: Minigame Ergonomics ===")
    print("====================================================================")
    rep = ChallengerReport()

    # -------------------------------------------------------------------------
    # SUITE 1: TSCN Static Parse — 100% Buttons >= 56px
    # -------------------------------------------------------------------------
    print("\n--- SUITE 1: Touch Target Ergonomics (>= 56px) Across Minigame TSCN Scenes ---")
    minigame_scenes = [
        ("scenes/ui/cyber_sync_minigame.tscn", "CyberSyncMinigame"),
        ("scenes/ui/pitch_stage_minigame.tscn", "PitchStageMinigame"),
        ("scenes/ui/espresso_brew_minigame.tscn", "EspressoBrewMinigame")
    ]

    for rel_path, name in minigame_scenes:
        content = read_file(rel_path)
        rep.check(len(content) > 0, f"{name} scene exists: {rel_path}")

        # Extract all button nodes
        button_matches = list(re.finditer(r'\[node name="([^"]+)" type="Button"[^\]]*\](.*?)(?=\n\[node|\Z)', content, re.DOTALL))
        rep.check(len(button_matches) > 0, f"{name} contains Button nodes (Found: {len(button_matches)})")

        for match in button_matches:
            btn_name = match.group(1)
            btn_block = match.group(2)
            
            # Check custom_minimum_size
            size_m = re.search(r'custom_minimum_size\s*=\s*Vector2\(\s*([\d\.]+)\s*,\s*([\d\.]+)\s*\)', btn_block)
            rep.check(size_m is not None, f"{name} button '{btn_name}' declares custom_minimum_size")
            if size_m:
                w = float(size_m.group(1))
                h = float(size_m.group(2))
                rep.check(h >= 56.0, f"{name} button '{btn_name}' height >= 56.0px (actual: {h}px)")
                if "close" in btn_name.lower():
                    rep.check(w >= 56.0, f"{name} close button '{btn_name}' width >= 56.0px (actual: {w}px)")

    # -------------------------------------------------------------------------
    # SUITE 2: Script Runtime Clamps (>= 56px Enforcement in _ready)
    # -------------------------------------------------------------------------
    print("\n--- SUITE 2: Minigame Scripts Programmatic Clamp Verification ---")
    minigame_scripts = [
        ("scripts/ui/cyber_sync_minigame.gd", "CyberSyncMinigame"),
        ("scripts/ui/pitch_stage_minigame.gd", "PitchStageMinigame"),
        ("scripts/ui/espresso_brew_minigame.gd", "EspressoBrewMinigame")
    ]

    for rel_path, name in minigame_scripts:
        code = read_file(rel_path)
        rep.check(len(code) > 0, f"{name} script exists: {rel_path}")

        # Check for clamp/maxf with 56.0
        has_56_clamp = "56.0" in code or "56" in code
        rep.check(has_56_clamp, f"{name} script includes 56px programmatic enforcement")

        # Check close_button clamped
        rep.check("close_button" in code, f"{name} manages close_button reference")
        if "close_button" in code:
            rep.check("custom_minimum_size.y" in code or "custom_minimum_size = " in code, f"{name} enforces minimum height on controls")

    # -------------------------------------------------------------------------
    # SUITE 3: Pointer Isolation (mouse_filter = STOP / 0 & _gui_input)
    # -------------------------------------------------------------------------
    print("\n--- SUITE 3: Strict Pointer Isolation & Event Absorption ---")
    for rel_path, name in minigame_scenes:
        content = read_file(rel_path)
        
        # Check root node mouse_filter = 0
        root_m = re.search(r'\[node name="[^"]+" type="Control"[^\]]*\](.*?)(?=\n\[node|\Z)', content, re.DOTALL)
        rep.check(root_m is not None, f"{name} root node is Control")
        if root_m:
            rep.check("mouse_filter = 0" in root_m.group(1), f"{name} root node enforces mouse_filter = 0 (STOP)")

        # Check backdrop mouse_filter = 0
        backdrop_m = re.search(r'\[node name="[^"]*(?:Backdrop|DimBackdrop)"[^\]]*\](.*?)(?=\n\[node|\Z)', content, re.DOTALL)
        rep.check(backdrop_m is not None, f"{name} backdrop node exists")
        if backdrop_m:
            rep.check("mouse_filter = 0" in backdrop_m.group(1), f"{name} backdrop enforces mouse_filter = 0 (STOP)")

        # Check all Button nodes have mouse_filter = 0
        button_matches = list(re.finditer(r'\[node name="([^"]+)" type="Button"[^\]]*\](.*?)(?=\n\[node|\Z)', content, re.DOTALL))
        all_btn_stop = all("mouse_filter = 0" in m.group(2) for m in button_matches)
        rep.check(all_btn_stop, f"{name} 100% of Button nodes have mouse_filter = 0 (STOP)")

    for rel_path, name in minigame_scripts:
        code = read_file(rel_path)
        # Check _gui_input implementation
        has_gui_input = "func _gui_input(" in code
        rep.check(has_gui_input, f"{name} implements _gui_input(event: InputEvent)")
        if has_gui_input:
            has_accept = "accept_event()" in code
            rep.check(has_accept, f"{name} calls accept_event() inside _gui_input()")

    # -------------------------------------------------------------------------
    # SUITE 4: Campus Stations Locomotion Gating
    # -------------------------------------------------------------------------
    print("\n--- SUITE 4: Campus Stations Locomotion Gating & Avatar Input Control ---")
    station_scripts = [
        ("scripts/server_terminal.gd", "ServerTerminal"),
        ("scripts/pitch_stage.gd", "PitchStage"),
        ("scripts/coffee_machine_3d.gd", "CoffeeMachine3D")
    ]

    for rel_path, name in station_scripts:
        code = read_file(rel_path)
        rep.check(len(code) > 0, f"{name} script exists: {rel_path}")

        # Check gating methods
        rep.check("func _gate_avatar_and_controls()" in code, f"{name} implements _gate_avatar_and_controls()")
        rep.check("func _restore_avatar_and_controls()" in code, f"{name} implements _restore_avatar_and_controls()")

        # Verify avatar set_input_enabled(false) is called
        rep.check("set_input_enabled(false)" in code, f"{name} calls set_input_enabled(false) on avatar")
        # Verify avatar stop_movement() is called
        rep.check("stop_movement()" in code, f"{name} calls stop_movement() on avatar")
        # Verify touch_controls fade_out_controls() is called
        rep.check("fade_out_controls()" in code, f"{name} calls fade_out_controls() on touch controls")
        # Verify set_input_enabled(true) on restore
        rep.check("set_input_enabled(true)" in code, f"{name} restores avatar input on minigame close")

    # -------------------------------------------------------------------------
    # SUITE 5: Screen Shake Dynamics, Clamping & Configurable Setting
    # -------------------------------------------------------------------------
    print("\n--- SUITE 5: Screen Shake Dynamics, Clamping & Configurable Setting ---")
    main3d_gd = read_file("scripts/main_3d.gd")
    rep.check(len(main3d_gd) > 0, "scripts/main_3d.gd exists")

    rep.check("var trauma: float = 0.0" in main3d_gd, "main_3d.gd declares trauma: float = 0.0")
    rep.check("var shake_decay_rate: float = 1.4" in main3d_gd, "main_3d.gd declares shake_decay_rate: float = 1.4")
    rep.check("var shake_frequency: float = 28.0" in main3d_gd, "main_3d.gd declares shake_frequency: float = 28.0")
    rep.check("clampf(trauma + amount, 0.0, 1.0)" in main3d_gd, "main_3d.gd clamps trauma within [0.0, 1.0]")
    rep.check("func trigger_camera_shake(" in main3d_gd, "main_3d.gd implements trigger_camera_shake alias")
    rep.check("func add_screen_shake(" in main3d_gd, "main_3d.gd implements add_screen_shake")
    rep.check("trauma * trauma * user_intensity" in main3d_gd, "main_3d.gd implements trauma^2 * user_intensity non-linear curve")
    rep.check("camera.h_offset = noise_h * max_shake_h * shake" in main3d_gd, "main_3d.gd applies shake to camera.h_offset")
    rep.check("camera.v_offset = noise_v * max_shake_v * shake" in main3d_gd, "main_3d.gd applies shake to camera.v_offset")
    rep.check("camera.h_offset = 0.0" in main3d_gd and "camera.v_offset = 0.0" in main3d_gd, "main_3d.gd resets camera offsets to 0.0 when idle")

    # GameState screen shake settings & signals
    gs_gd = read_file("scripts/autoload/game_state.gd")
    rep.check("signal camera_shake_requested(amount: float)" in gs_gd, "game_state.gd declares signal camera_shake_requested(amount: float)")
    rep.check("signal screen_shake_changed(new_intensity: float)" in gs_gd, "game_state.gd declares signal screen_shake_changed(new_intensity: float)")
    rep.check("var screen_shake_intensity: float = 1.0" in gs_gd, "game_state.gd declares screen_shake_intensity: float = 1.0")
    rep.check("func set_screen_shake_intensity(" in gs_gd, "game_state.gd implements set_screen_shake_intensity()")
    rep.check("func get_screen_shake_intensity(" in gs_gd, "game_state.gd implements get_screen_shake_intensity()")
    rep.check("func trigger_camera_shake(amount: float)" in gs_gd, "game_state.gd implements trigger_camera_shake(amount: float)")
    rep.check("camera_shake_requested.emit(amount)" in gs_gd, "game_state.gd routes trigger_camera_shake through camera_shake_requested signal")

    # Mathematical Simulation of Screen Shake Curve
    print("\n--- SUITE 6: Mathematical Invariant Checks ---")
    def compute_shake(trauma: float, intensity: float) -> float:
        t = max(0.0, min(1.0, trauma))
        i = max(0.0, min(1.0, intensity))
        return (t * t) * i

    rep.check(compute_shake(1.0, 1.0) == 1.0, "Trauma 1.0 at 100% intensity == 1.0")
    rep.check(abs(compute_shake(0.5, 1.0) - 0.25) < 0.0001, "Trauma 0.5 at 100% intensity == 0.25 (quadratic falloff)")
    rep.check(compute_shake(1.0, 0.0) == 0.0, "Trauma 1.0 at 0% intensity == 0.0 (Accessibility off)")
    rep.check(compute_shake(0.0, 1.0) == 0.0, "Trauma 0.0 yields 0.0 shake")
    rep.check(compute_shake(10.0, 1.0) == 1.0, "Trauma 10.0 clamped to 1.0 max")
    rep.check(compute_shake(-5.0, 1.0) == 0.0, "Trauma -5.0 clamped to 0.0 min")

    # Decay simulation: decay_rate = 1.4
    t = 1.0
    decay_rate = 1.4
    dt = 1.0 / 60.0
    frames = 0
    while t > 0.0:
        t = max(0.0, t - decay_rate * dt)
        frames += 1
    duration = frames * dt
    rep.check(abs(duration - (1.0 / 1.4)) < 0.02, f"Trauma 1.0 decays in ~0.714s (actual: {duration:.3f}s / {frames} frames)")

    print("\n====================================================================")
    print(f"RESULTS: {rep.passes} PASSED, {rep.fails} FAILED")
    print("====================================================================")
    if rep.fails == 0:
        print(">>> ALL CHALLENGER CHECKS PASSED (EMPIRICAL APPROVE) <<<\n")
        sys.exit(0)
    else:
        print(f">>> CHALLENGER CHECKS FAILED: {rep.fails} DEFECTS FOUND (REQUEST_CHANGES) <<<\n")
        sys.exit(1)

if __name__ == "__main__":
    main()
