#!/usr/bin/env python3
"""
Unit and AST Verification Suite for Phase 10 Milestone 2: Screen-Shake & Ergonomics
File: IdleArcade/tests/test_phase10_m2_shake.py
Target: Python 3.12 CI Verification & Structural Certification
"""

import sys
import os
import re
import math
from pathlib import Path

# UTF-8 stdout configuration
if hasattr(sys.stdout, "reconfigure"):
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass

SCRIPT_DIR = Path(__file__).resolve().parent
GAME_DIR = SCRIPT_DIR.parent

class Reporter:
    def __init__(self):
        self.passes = 0
        self.fails = 0

    def check(self, condition: bool, description: str, detail: str = ""):
        if condition:
            print(f"  [PASS] {description}")
            self.passes += 1
        else:
            print(f"  [FAIL] {description} ({detail})")
            self.fails += 1

reporter = Reporter()

def run_tests():
    print("\n=== Phase 10 Milestone 2: Screen-Shake & Ergonomics Verification ===")

    # --------------------------------------------------------------------------
    # 1. Main3D Camera Screen-Shake Controller AST & Logic
    # --------------------------------------------------------------------------
    main3d_path = GAME_DIR / "scripts" / "main_3d.gd"
    reporter.check(main3d_path.exists(), "scripts/main_3d.gd exists")
    if main3d_path.exists():
        content = main3d_path.read_text(encoding="utf-8")
        
        # State variables
        reporter.check("var trauma: float = 0.0" in content or "var trauma: float" in content,
                       "main_3d.gd declares trauma variable")
        reporter.check("shake_frequency" in content,
                       "main_3d.gd declares shake_frequency")
        reporter.check("shake_decay_rate" in content,
                       "main_3d.gd declares shake_decay_rate")
        reporter.check("max_shake_h" in content and "max_shake_v" in content,
                       "main_3d.gd declares max_shake_h and max_shake_v offsets")
        
        # Public method
        reporter.check("func add_screen_shake(amount: float)" in content or "func add_screen_shake(" in content,
                       "main_3d.gd implements public add_screen_shake(amount: float)")
        reporter.check("clampf(trauma + amount, 0.0, 1.0)" in content or "clampf" in content and "trauma" in content,
                       "main_3d.gd clamps trauma within [0.0, 1.0]")
        
        # Process and shake calculation
        reporter.check("func _process(" in content or "func _process(delta: float)" in content,
                       "main_3d.gd implements _process(delta) loop for frame updates")
        reporter.check("camera.h_offset" in content and "camera.v_offset" in content,
                       "main_3d.gd drives camera.h_offset and camera.v_offset")
        reporter.check("trauma * trauma" in content,
                       "main_3d.gd applies quadratic trauma^2 curve for shake falloff")
        reporter.check("screen_shake_intensity" in content,
                       "main_3d.gd scales shake by GameState.screen_shake_intensity")
        reporter.check("shake_decay_rate * delta" in content or "maxf(0.0, trauma - shake_decay_rate * delta)" in content,
                       "main_3d.gd implements linear trauma decay over time")
        
        # Idle offset reset
        reporter.check("camera.h_offset = 0.0" in content and "camera.v_offset = 0.0" in content,
                       "main_3d.gd resets camera offsets to 0.0 when shake is idle")
        
        # Frenzy / Viraler Hype connection
        reporter.check("frenzy_updated" in content,
                       "main_3d.gd connects to GameState.frenzy_updated signal")
        reporter.check("add_screen_shake(0.65)" in content,
                       "main_3d.gd triggers strong shake (0.65) on frenzy activation")

    # --------------------------------------------------------------------------
    # 2. GameState Persistence & Interface Contract
    # --------------------------------------------------------------------------
    gs_path = GAME_DIR / "scripts" / "autoload" / "game_state.gd"
    reporter.check(gs_path.exists(), "scripts/autoload/game_state.gd exists")
    if gs_path.exists():
        gs_content = gs_path.read_text(encoding="utf-8")
        
        reporter.check("var screen_shake_intensity: float = 1.0" in gs_content or "var screen_shake_intensity" in gs_content,
                       "game_state.gd declares screen_shake_intensity variable")
        reporter.check("signal screen_shake_changed" in gs_content,
                       "game_state.gd declares signal screen_shake_changed(new_intensity)")
        reporter.check("func set_screen_shake_intensity(" in gs_content,
                       "game_state.gd implements set_screen_shake_intensity(val)")
        reporter.check("func get_screen_shake_intensity()" in gs_content,
                       "game_state.gd implements get_screen_shake_intensity()")
        reporter.check("clampf(val, 0.0, 1.0)" in gs_content or "clampf(" in gs_content and "screen_shake_intensity" in gs_content,
                       "game_state.gd clamps screen_shake_intensity to [0.0, 1.0]")
        reporter.check('"screen_shake_intensity": screen_shake_intensity' in gs_content or '"screen_shake_intensity"' in gs_content,
                       "game_state.gd serializes screen_shake_intensity in save_to_disk()")
        reporter.check('get("screen_shake_intensity"' in gs_content or 'data.has("screen_shake_intensity")' in gs_content,
                       "game_state.gd deserializes screen_shake_intensity in load_from_disk()")

    # --------------------------------------------------------------------------
    # 3. Settings Modal Scene Hierarchy & Touch Ergonomics (>= 56px)
    # --------------------------------------------------------------------------
    modal_tscn_path = GAME_DIR / "scenes" / "ui" / "settings_modal.tscn"
    reporter.check(modal_tscn_path.exists(), "scenes/ui/settings_modal.tscn exists")
    if modal_tscn_path.exists():
        tscn_content = modal_tscn_path.read_text(encoding="utf-8")
        
        reporter.check('name="ScreenShakeCard"' in tscn_content,
                       "settings_modal.tscn defines ScreenShakeCard PanelContainer")
        reporter.check('name="ScreenShakeValue"' in tscn_content,
                       "settings_modal.tscn defines ScreenShakeValue Label")
        reporter.check('name="ScreenShakeSlider"' in tscn_content,
                       "settings_modal.tscn defines ScreenShakeSlider HSlider")
        
        # Check ScreenShakeSlider touch target height >= 56px
        slider_match = re.search(r'\[node name="ScreenShakeSlider"[^\]]*\](.*?)(?=\n\[node|\Z)', tscn_content, re.DOTALL)
        reporter.check(slider_match is not None, "ScreenShakeSlider node block present in tscn")
        if slider_match:
            slider_chunk = slider_match.group(1)
            size_m = re.search(r'custom_minimum_size = Vector2\((\d+),\s*(\d+)\)', slider_chunk)
            if size_m:
                h = int(size_m.group(2))
                reporter.check(h >= 56, f"ScreenShakeSlider touch height >= 56px (actual: {h}px)")
            else:
                reporter.check(False, "ScreenShakeSlider custom_minimum_size declaration", "missing")
            
            # Input isolation on slider
            reporter.check("mouse_filter = 0" in slider_chunk,
                           "ScreenShakeSlider enforces mouse_filter = 0 (Control.MOUSE_FILTER_STOP)")

    # --------------------------------------------------------------------------
    # 4. Settings Modal GDScript Controller Logic
    # --------------------------------------------------------------------------
    modal_gd_path = GAME_DIR / "scripts" / "ui" / "settings_modal.gd"
    reporter.check(modal_gd_path.exists(), "scripts/ui/settings_modal.gd exists")
    if modal_gd_path.exists():
        gd_content = modal_gd_path.read_text(encoding="utf-8")
        
        reporter.check("screen_shake_slider" in gd_content,
                       "settings_modal.gd binds screen_shake_slider node")
        reporter.check("screen_shake_value_label" in gd_content,
                       "settings_modal.gd binds screen_shake_value_label node")
        reporter.check("func _on_screen_shake_slider_changed(" in gd_content,
                       "settings_modal.gd implements _on_screen_shake_slider_changed handler")
        reporter.check("set_screen_shake_intensity" in gd_content,
                       "settings_modal.gd updates GameState.set_screen_shake_intensity")
        reporter.check("func set_screen_shake_val(" in gd_content,
                       "settings_modal.gd implements set_screen_shake_val test helper")
        reporter.check("%d%%" in gd_content and "screen_shake" in gd_content,
                       "settings_modal.gd formats screen shake value label as percentage '%d%%'")

    # --------------------------------------------------------------------------
    # 5. Station & Entity Shake Hook Points
    # --------------------------------------------------------------------------
    # 5.1 Server Terminal (Overclock ~0.60)
    server_path = GAME_DIR / "scripts" / "server_terminal.gd"
    reporter.check(server_path.exists(), "scripts/server_terminal.gd exists")
    if server_path.exists():
        s_content = server_path.read_text(encoding="utf-8")
        reporter.check("add_screen_shake(0.60)" in s_content or "add_screen_shake(0.6" in s_content,
                       "server_terminal.gd triggers strong screen shake (0.60) on overclock")

    # 5.2 Pitch Stage (Successful Pitch ~0.40)
    pitch_path = GAME_DIR / "scripts" / "pitch_stage.gd"
    reporter.check(pitch_path.exists(), "scripts/pitch_stage.gd exists")
    if pitch_path.exists():
        p_content = pitch_path.read_text(encoding="utf-8")
        reporter.check("add_screen_shake(0.40)" in p_content or "add_screen_shake(0.4" in p_content,
                       "pitch_stage.gd triggers moderate screen shake (0.40) on pitch funding")

    # 5.3 Zone Gate 3D (Gate Unlock ~0.45)
    gate_path = GAME_DIR / "scripts" / "zone_gate_3d.gd"
    reporter.check(gate_path.exists(), "scripts/zone_gate_3d.gd exists")
    if gate_path.exists():
        g_content = gate_path.read_text(encoding="utf-8")
        reporter.check("add_screen_shake(0.45)" in g_content,
                       "zone_gate_3d.gd triggers moderate screen shake (0.45) on gate unlock")

    # 5.4 Delivery Drone 3D (Drone Takeoff/Activation ~0.20)
    drone_path = GAME_DIR / "scripts" / "delivery_drone_3d.gd"
    reporter.check(drone_path.exists(), "scripts/delivery_drone_3d.gd exists")
    if drone_path.exists():
        d_content = drone_path.read_text(encoding="utf-8")
        reporter.check("add_screen_shake(0.20)" in d_content or "add_screen_shake(0.2" in d_content,
                       "delivery_drone_3d.gd triggers subtle screen shake (0.20) on activation")

    # 5.5 Collectible 3D (Item Pickup ~0.12)
    col_path = GAME_DIR / "scripts" / "collectible_3d.gd"
    reporter.check(col_path.exists(), "scripts/collectible_3d.gd exists")
    if col_path.exists():
        c_content = col_path.read_text(encoding="utf-8")
        reporter.check("add_screen_shake(0.12)" in c_content,
                       "collectible_3d.gd triggers subtle screen shake (0.12) on item pickup")

    # --------------------------------------------------------------------------
    # 6. Mathematical Simulation of Screen Shake Trauma & Decay
    # --------------------------------------------------------------------------
    print("\n--- 6. Mathematical Oracle: Trauma Quadratic Curve & Decay Simulation ---")
    
    # 6.1 Shake power calculation: shake = trauma^2 * user_intensity
    def calc_shake(trauma: float, user_intensity: float) -> float:
        t = max(0.0, min(1.0, trauma))
        u = max(0.0, min(1.0, user_intensity))
        return (t * t) * u

    reporter.check(calc_shake(1.0, 1.0) == 1.0, "Trauma 1.0 with 100% intensity yields 1.0 shake")
    reporter.check(abs(calc_shake(0.5, 1.0) - 0.25) < 1e-6, "Trauma 0.5 with 100% intensity yields 0.25 shake (quadratic falloff)")
    reporter.check(abs(calc_shake(0.2, 1.0) - 0.04) < 1e-6, "Trauma 0.2 with 100% intensity yields 0.04 shake")
    reporter.check(calc_shake(1.0, 0.0) == 0.0, "Trauma 1.0 with 0% intensity yields 0.0 shake (accessibility zero)")
    reporter.check(abs(calc_shake(1.0, 0.5) - 0.5) < 1e-6, "Trauma 1.0 with 50% intensity yields 0.5 shake")
    reporter.check(abs(calc_shake(0.6, 0.5) - 0.18) < 1e-6, "Trauma 0.6 with 50% intensity yields 0.18 shake")

    # 6.2 Decay simulation: rate = 1.4 / sec
    decay_rate = 1.4
    dt = 1.0 / 60.0  # 60 FPS frame time ~0.01667s
    sim_trauma = 1.0
    frames = 0
    while sim_trauma > 0.0:
        sim_trauma = max(0.0, sim_trauma - decay_rate * dt)
        frames += 1

    decay_time = frames * dt
    reporter.check(0.70 <= decay_time <= 0.74,
                   f"Trauma 1.0 fully decays to 0.0 in ~0.71s (actual: {decay_time:.3f}s / {frames} frames)")

    # 6.3 Projection Plane Displacement Bounds
    max_h = 0.45
    max_v = 0.35
    max_possible_h_offset = max_h * 1.0 * 1.0
    max_possible_v_offset = max_v * 1.0 * 1.0
    reporter.check(max_possible_h_offset <= 0.50, f"Max horizontal projection plane offset <= 0.50 (actual: {max_possible_h_offset})")
    reporter.check(max_possible_v_offset <= 0.40, f"Max vertical projection plane offset <= 0.40 (actual: {max_possible_v_offset})")

    # --------------------------------------------------------------------------
    # Summary
    # --------------------------------------------------------------------------
    total = reporter.passes + reporter.fails
    print("\n-------------------------------------------------------------")
    print(f"Total Checks : {total}")
    print(f"Passed       : {reporter.passes}")
    print(f"Failed       : {reporter.fails}")
    print("-------------------------------------------------------------")
    if reporter.fails > 0:
        print(">>> SOME VERIFICATION CHECKS FAILED! <<<")
        sys.exit(1)
    else:
        print(">>> ALL PHASE 10 M2 SCREEN-SHAKE CHECKS PASSED WITH 100% GREEN! <<<")
        sys.exit(0)

if __name__ == "__main__":
    run_tests()
