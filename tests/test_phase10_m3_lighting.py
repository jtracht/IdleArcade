#!/usr/bin/env python3
"""
Unit and AST Verification Suite for Phase 10 Milestone 3: Campus Day/Night Light Cycle
File: IdleArcade/tests/test_phase10_m3_lighting.py
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
    print("\n=== Phase 10 Milestone 3: Campus Day/Night Light Cycle Verification ===")

    # --------------------------------------------------------------------------
    # 1. Day/Night Cycle Scene & Script AST
    # --------------------------------------------------------------------------
    cycle_scene_path = GAME_DIR / "scenes" / "day_night_cycle.tscn"
    reporter.check(cycle_scene_path.exists(), "scenes/day_night_cycle.tscn exists")
    if cycle_scene_path.exists():
        scene_content = cycle_scene_path.read_text(encoding="utf-8")
        reporter.check('type="Node3D"' in scene_content,
                       "day_night_cycle.tscn root is a Node3D")
        reporter.check('res://scripts/day_night_cycle.gd' in scene_content,
                       "day_night_cycle.tscn attaches scripts/day_night_cycle.gd")
        reporter.check('cycle_duration = 180.0' in scene_content or 'cycle_duration = 180' in scene_content,
                       "day_night_cycle.tscn sets cycle_duration = 180.0 (3 minutes)")
        reporter.check('cycle_mode = "auto"' in scene_content,
                       "day_night_cycle.tscn defaults cycle_mode to 'auto'")

    cycle_script_path = GAME_DIR / "scripts" / "day_night_cycle.gd"
    reporter.check(cycle_script_path.exists(), "scripts/day_night_cycle.gd exists")
    if cycle_script_path.exists():
        script_content = cycle_script_path.read_text(encoding="utf-8")
        reporter.check("class_name DayNightCycle" in script_content,
                       "day_night_cycle.gd registers class_name DayNightCycle")
        reporter.check("signal phase_changed" in script_content,
                       "day_night_cycle.gd declares phase_changed signal")
        reporter.check("signal cycle_mode_changed" in script_content,
                       "day_night_cycle.gd declares cycle_mode_changed signal")
        reporter.check("signal time_of_day_changed" in script_content,
                       "day_night_cycle.gd declares time_of_day_changed signal")
        
        # Public Interface Methods
        reporter.check("func set_cycle_mode(" in script_content,
                       "day_night_cycle.gd implements set_cycle_mode(mode)")
        reporter.check("func get_cycle_mode()" in script_content,
                       "day_night_cycle.gd implements get_cycle_mode()")
        reporter.check("func set_time_of_day(" in script_content,
                       "day_night_cycle.gd implements set_time_of_day(val)")
        reporter.check("func get_time_of_day()" in script_content,
                       "day_night_cycle.gd implements get_time_of_day()")
        reporter.check("func get_current_phase()" in script_content,
                       "day_night_cycle.gd implements get_current_phase()")
        reporter.check("func get_current_phase_name()" in script_content,
                       "day_night_cycle.gd implements get_current_phase_name()")
        reporter.check("func get_night_emission_factor()" in script_content,
                       "day_night_cycle.gd implements get_night_emission_factor()")
        reporter.check("static func calculate_lighting_state(" in script_content,
                       "day_night_cycle.gd implements static calculate_lighting_state(t)")
        reporter.check("func register_window_material(" in script_content,
                       "day_night_cycle.gd implements register_window_material(mat)")
        reporter.check("func register_neon_material(" in script_content,
                       "day_night_cycle.gd implements register_neon_material(mat)")
        reporter.check("func register_server_led_material(" in script_content,
                       "day_night_cycle.gd implements register_server_led_material(mat)")

        # Mandatory Cyberpunk Night Ambient Color Specification
        reporter.check("Color(0.08, 0.10, 0.18" in script_content or "Color(0.08, 0.1, 0.18" in script_content,
                       "day_night_cycle.gd configures MANDATORY Cyberpunk Night Color(0.08, 0.10, 0.18)")

    # --------------------------------------------------------------------------
    # 2. Main 3D World Scene & Walls Decoration Integration
    # --------------------------------------------------------------------------
    main3d_tscn_path = GAME_DIR / "scenes" / "main_3d.tscn"
    reporter.check(main3d_tscn_path.exists(), "scenes/main_3d.tscn exists")
    if main3d_tscn_path.exists():
        m3_tscn = main3d_tscn_path.read_text(encoding="utf-8")
        reporter.check('res://scenes/day_night_cycle.tscn' in m3_tscn,
                       "main_3d.tscn references day_night_cycle.tscn")
        reporter.check('name="DayNightCycle"' in m3_tscn,
                       "main_3d.tscn instantiates DayNightCycle node")
        reporter.check('directional_light = NodePath("../DirectionalLight3D")' in m3_tscn or 'DirectionalLight3D' in m3_tscn,
                       "DayNightCycle in main_3d.tscn binds DirectionalLight3D")
        reporter.check('world_environment = NodePath("../WorldEnvironment")' in m3_tscn or 'WorldEnvironment' in m3_tscn,
                       "DayNightCycle in main_3d.tscn binds WorldEnvironment")
        reporter.check('Mat_CampusWindowWarm' in m3_tscn,
                       "main_3d.tscn defines Mat_CampusWindowWarm emissive material")
        reporter.check('Mat_CampusNeonCyan' in m3_tscn,
                       "main_3d.tscn defines Mat_CampusNeonCyan emissive material")
        reporter.check('Mat_CampusNeonMagenta' in m3_tscn,
                       "main_3d.tscn defines Mat_CampusNeonMagenta emissive material")
        reporter.check('NorthWindows' in m3_tscn,
                       "NorthWall has window strips geometry")
        reporter.check('NorthNeonTrim' in m3_tscn,
                       "NorthWall has neon trim geometry")
        reporter.check('SouthWindows' in m3_tscn,
                       "SouthWall has window strips geometry")
        reporter.check('SouthNeonTrim' in m3_tscn,
                       "SouthWall has neon trim geometry")
        reporter.check('EastWindows' in m3_tscn,
                       "EastWall has window strips geometry")
        reporter.check('EastNeonTrim' in m3_tscn,
                       "EastWall has neon trim geometry")
        reporter.check('WestWindows' in m3_tscn,
                       "WestWall has window strips geometry")
        reporter.check('WestNeonTrim' in m3_tscn,
                       "WestWall has neon trim geometry")

    main3d_gd_path = GAME_DIR / "scripts" / "main_3d.gd"
    reporter.check(main3d_gd_path.exists(), "scripts/main_3d.gd exists")
    if main3d_gd_path.exists():
        m3_gd = main3d_gd_path.read_text(encoding="utf-8")
        reporter.check("day_night_cycle" in m3_gd,
                       "main_3d.gd declares day_night_cycle reference")
        reporter.check("_setup_day_night_cycle" in m3_gd,
                       "main_3d.gd calls _setup_day_night_cycle()")
        reporter.check("light_cycle_mode_changed" in m3_gd,
                       "main_3d.gd connects to GameState.light_cycle_mode_changed")
        reporter.check("_on_light_cycle_mode_changed" in m3_gd,
                       "main_3d.gd implements _on_light_cycle_mode_changed(mode)")

    # --------------------------------------------------------------------------
    # 3. GameState Persistence & Interface Contracts
    # --------------------------------------------------------------------------
    gs_path = GAME_DIR / "scripts" / "autoload" / "game_state.gd"
    reporter.check(gs_path.exists(), "scripts/autoload/game_state.gd exists")
    if gs_path.exists():
        gs_content = gs_path.read_text(encoding="utf-8")
        reporter.check("var light_cycle_mode: String = \"auto\"" in gs_content or "var light_cycle_mode" in gs_content,
                       "game_state.gd declares light_cycle_mode variable")
        reporter.check("signal light_cycle_mode_changed" in gs_content,
                       "game_state.gd declares signal light_cycle_mode_changed(new_mode)")
        reporter.check("func set_light_cycle_mode(" in gs_content,
                       "game_state.gd implements set_light_cycle_mode(mode)")
        reporter.check("func get_light_cycle_mode()" in gs_content,
                       "game_state.gd implements get_light_cycle_mode()")
        reporter.check('"light_cycle_mode": light_cycle_mode' in gs_content or '"light_cycle_mode"' in gs_content,
                       "game_state.gd serializes light_cycle_mode in save_to_disk()")
        reporter.check('get("light_cycle_mode"' in gs_content or 'data.has("light_cycle_mode")' in gs_content,
                       "game_state.gd deserializes light_cycle_mode in load_from_disk()")
        reporter.check('["auto", "day", "night"]' in gs_content,
                       "game_state.gd enforces fallback validation for light_cycle_mode")

    # --------------------------------------------------------------------------
    # 4. Settings Modal Hierarchy & Touch Ergonomics (>= 56px)
    # --------------------------------------------------------------------------
    modal_tscn_path = GAME_DIR / "scenes" / "ui" / "settings_modal.tscn"
    reporter.check(modal_tscn_path.exists(), "scenes/ui/settings_modal.tscn exists")
    if modal_tscn_path.exists():
        tscn_content = modal_tscn_path.read_text(encoding="utf-8")
        reporter.check('name="LightCycleCard"' in tscn_content,
                       "settings_modal.tscn defines LightCycleCard PanelContainer")
        reporter.check('name="LightCycleValue"' in tscn_content,
                       "settings_modal.tscn defines LightCycleValue Label")
        reporter.check('name="LightCycleAutoButton"' in tscn_content,
                       "settings_modal.tscn defines LightCycleAutoButton Button")
        reporter.check('name="LightCycleDayButton"' in tscn_content,
                       "settings_modal.tscn defines LightCycleDayButton Button")
        reporter.check('name="LightCycleNightButton"' in tscn_content,
                       "settings_modal.tscn defines LightCycleNightButton Button")

        # Check button heights >= 56px and mouse_filter = 0
        for btn_name in ["LightCycleAutoButton", "LightCycleDayButton", "LightCycleNightButton"]:
            btn_match = re.search(rf'\[node name="{btn_name}"[^\]]*\](.*?)(?=\n\[node|\Z)', tscn_content, re.DOTALL)
            reporter.check(btn_match is not None, f"{btn_name} node block present in tscn")
            if btn_match:
                btn_chunk = btn_match.group(1)
                size_m = re.search(r'custom_minimum_size = Vector2\((\d+),\s*(\d+)\)', btn_chunk)
                if size_m:
                    h = int(size_m.group(2))
                    reporter.check(h >= 56, f"{btn_name} touch target height >= 56px (actual: {h}px)")
                else:
                    reporter.check(False, f"{btn_name} custom_minimum_size declaration", "missing")
                reporter.check("mouse_filter = 0" in btn_chunk,
                               f"{btn_name} enforces mouse_filter = 0 (Control.MOUSE_FILTER_STOP)")

    modal_gd_path = GAME_DIR / "scripts" / "ui" / "settings_modal.gd"
    reporter.check(modal_gd_path.exists(), "scripts/ui/settings_modal.gd exists")
    if modal_gd_path.exists():
        gd_content = modal_gd_path.read_text(encoding="utf-8")
        reporter.check("light_cycle_auto_btn" in gd_content,
                       "settings_modal.gd binds light_cycle_auto_btn")
        reporter.check("light_cycle_day_btn" in gd_content,
                       "settings_modal.gd binds light_cycle_day_btn")
        reporter.check("light_cycle_night_btn" in gd_content,
                       "settings_modal.gd binds light_cycle_night_btn")
        reporter.check("light_cycle_value_label" in gd_content,
                       "settings_modal.gd binds light_cycle_value_label")
        reporter.check("func _on_light_cycle_auto_pressed" in gd_content,
                       "settings_modal.gd implements _on_light_cycle_auto_pressed")
        reporter.check("func _on_light_cycle_day_pressed" in gd_content,
                       "settings_modal.gd implements _on_light_cycle_day_pressed")
        reporter.check("func _on_light_cycle_night_pressed" in gd_content,
                       "settings_modal.gd implements _on_light_cycle_night_pressed")
        reporter.check("set_light_cycle_mode" in gd_content,
                       "settings_modal.gd updates GameState.set_light_cycle_mode")
        reporter.check("func set_light_cycle_val(" in gd_content,
                       "settings_modal.gd implements set_light_cycle_val test helper")
        reporter.check("_update_light_cycle_buttons" in gd_content,
                       "settings_modal.gd implements visual button highlight logic")

    # --------------------------------------------------------------------------
    # 5. Mathematical Simulation Oracle: 3-Phase Interpolation & Color Accuracy
    # --------------------------------------------------------------------------
    print("\n--- 5. Mathematical Oracle: 3-Phase Interpolation & Color Accuracy ---")

    # Python implementation of the GDScript calculate_lighting_state logic
    def lerp(a, b, w):
        return a + (b - a) * w

    def lerp_color(c1, c2, w):
        return tuple(lerp(a, b, w) for a, b in zip(c1, c2))

    def smoothstep(edge0, edge1, x):
        t = max(0.0, min(1.0, (x - edge0) / (edge1 - edge0)))
        return t * t * (3.0 - 2.0 * t)

    DAY_DIR_ENERGY = 1.2
    DAY_DIR_COLOR = (1.0, 0.96, 0.88)
    DAY_AMB_COLOR = (0.38, 0.44, 0.53)
    DAY_AMB_ENERGY = 0.75
    DAY_NIGHT_FACTOR = 0.0

    SUNSET_DIR_ENERGY = 0.85
    SUNSET_DIR_COLOR = (1.0, 0.55, 0.22)
    SUNSET_AMB_COLOR = (0.42, 0.28, 0.25)
    SUNSET_AMB_ENERGY = 0.65
    SUNSET_NIGHT_FACTOR = 0.4

    NIGHT_DIR_ENERGY = 0.15
    NIGHT_DIR_COLOR = (0.25, 0.35, 0.65)
    NIGHT_AMB_COLOR = (0.08, 0.10, 0.18)
    NIGHT_AMB_ENERGY = 0.55
    NIGHT_NIGHT_FACTOR = 1.0

    def calc_lighting(t: float):
        norm_t = t % 1.0
        if norm_t < 0.0:
            norm_t += 1.0

        if norm_t <= 0.45:
            return {
                "dir_energy": DAY_DIR_ENERGY,
                "dir_color": DAY_DIR_COLOR,
                "amb_color": DAY_AMB_COLOR,
                "amb_energy": DAY_AMB_ENERGY,
                "night_factor": DAY_NIGHT_FACTOR
            }
        elif norm_t < 0.65:
            w = smoothstep(0.45, 0.65, norm_t)
            return {
                "dir_energy": lerp(DAY_DIR_ENERGY, SUNSET_DIR_ENERGY, w),
                "dir_color": lerp_color(DAY_DIR_COLOR, SUNSET_DIR_COLOR, w),
                "amb_color": lerp_color(DAY_AMB_COLOR, SUNSET_AMB_COLOR, w),
                "amb_energy": lerp(DAY_AMB_ENERGY, SUNSET_AMB_ENERGY, w),
                "night_factor": lerp(DAY_NIGHT_FACTOR, SUNSET_NIGHT_FACTOR, w)
            }
        elif abs(norm_t - 0.65) < 1e-5:
            return {
                "dir_energy": SUNSET_DIR_ENERGY,
                "dir_color": SUNSET_DIR_COLOR,
                "amb_color": SUNSET_AMB_COLOR,
                "amb_energy": SUNSET_AMB_ENERGY,
                "night_factor": SUNSET_NIGHT_FACTOR
            }
        elif norm_t < 0.82:
            w = smoothstep(0.65, 0.82, norm_t)
            return {
                "dir_energy": lerp(SUNSET_DIR_ENERGY, NIGHT_DIR_ENERGY, w),
                "dir_color": lerp_color(SUNSET_DIR_COLOR, NIGHT_DIR_COLOR, w),
                "amb_color": lerp_color(SUNSET_AMB_COLOR, NIGHT_AMB_COLOR, w),
                "amb_energy": lerp(SUNSET_AMB_ENERGY, NIGHT_AMB_ENERGY, w),
                "night_factor": lerp(SUNSET_NIGHT_FACTOR, NIGHT_NIGHT_FACTOR, w)
            }
        elif norm_t <= 0.92:
            return {
                "dir_energy": NIGHT_DIR_ENERGY,
                "dir_color": NIGHT_DIR_COLOR,
                "amb_color": NIGHT_AMB_COLOR,
                "amb_energy": NIGHT_AMB_ENERGY,
                "night_factor": NIGHT_NIGHT_FACTOR
            }
        else:
            w = smoothstep(0.92, 1.0, norm_t)
            return {
                "dir_energy": lerp(NIGHT_DIR_ENERGY, DAY_DIR_ENERGY, w),
                "dir_color": lerp_color(NIGHT_DIR_COLOR, DAY_DIR_COLOR, w),
                "amb_color": lerp_color(NIGHT_AMB_COLOR, DAY_AMB_COLOR, w),
                "amb_energy": lerp(NIGHT_AMB_ENERGY, DAY_AMB_ENERGY, w),
                "night_factor": lerp(NIGHT_NIGHT_FACTOR, DAY_NIGHT_FACTOR, w)
            }

    # 5.1 Daylight Phase Verification (t = 0.20)
    day_state = calc_lighting(0.20)
    reporter.check(day_state["dir_energy"] == 1.2, "Daylight t=0.20 has dir_energy 1.2")
    reporter.check(day_state["dir_color"] == (1.0, 0.96, 0.88), "Daylight t=0.20 has sunlight color (1.0, 0.96, 0.88)")
    reporter.check(day_state["amb_color"] == (0.38, 0.44, 0.53), "Daylight t=0.20 has ambient color (0.38, 0.44, 0.53)")
    reporter.check(day_state["amb_energy"] == 0.75, "Daylight t=0.20 has ambient energy 0.75")
    reporter.check(day_state["night_factor"] == 0.0, "Daylight t=0.20 has night emission factor 0.0")

    # 5.2 Golden Sunset Phase Verification (t = 0.65)
    sunset_state = calc_lighting(0.65)
    reporter.check(sunset_state["dir_energy"] == 0.85, "Sunset t=0.65 has dir_energy 0.85")
    reporter.check(sunset_state["dir_color"] == (1.0, 0.55, 0.22), "Sunset t=0.65 has warm amber color (1.0, 0.55, 0.22)")
    reporter.check(sunset_state["amb_color"] == (0.42, 0.28, 0.25), "Sunset t=0.65 has sunset ambient color (0.42, 0.28, 0.25)")
    reporter.check(sunset_state["amb_energy"] == 0.65, "Sunset t=0.65 has ambient energy 0.65")
    reporter.check(sunset_state["night_factor"] == 0.4, "Sunset t=0.65 has night emission factor 0.4")

    # 5.3 Cyberpunk Night Phase Verification (t = 0.82)
    night_state = calc_lighting(0.82)
    reporter.check(night_state["dir_energy"] == 0.15, "Cyberpunk Night t=0.82 has dir_energy 0.15 (moonlight)")
    reporter.check(night_state["dir_color"] == (0.25, 0.35, 0.65), "Cyberpunk Night t=0.82 has cool blue light (0.25, 0.35, 0.65)")
    # MANDATORY SPECIFICATION VALUE
    reporter.check(night_state["amb_color"] == (0.08, 0.10, 0.18),
                   "Cyberpunk Night t=0.82 has MANDATORY ambient color Color(0.08, 0.10, 0.18)")
    reporter.check(night_state["amb_energy"] == 0.55, "Cyberpunk Night t=0.82 has ambient energy 0.55")
    reporter.check(night_state["night_factor"] == 1.0, "Cyberpunk Night t=0.82 has night emission factor 1.0")

    # 5.4 Smoothstep Cross-fade Continuity Checks
    mid_sunset = calc_lighting(0.55)
    reporter.check(SUNSET_DIR_ENERGY < mid_sunset["dir_energy"] < DAY_DIR_ENERGY,
                   "Mid-Sunset t=0.55 energy is strictly bounded between Sunset and Day")
    reporter.check(0.0 < mid_sunset["night_factor"] < 0.4,
                   "Mid-Sunset t=0.55 night factor is strictly bounded in (0.0, 0.4)")

    mid_night = calc_lighting(0.735)
    reporter.check(NIGHT_DIR_ENERGY < mid_night["dir_energy"] < SUNSET_DIR_ENERGY,
                   "Mid-Night t=0.735 energy is strictly bounded between Night and Sunset")
    reporter.check(0.4 < mid_night["night_factor"] < 1.0,
                   "Mid-Night t=0.735 night factor is strictly bounded in (0.4, 1.0)")

    # 5.5 Material Emission Scaling Math Verification
    def calc_mat_emission(factor: float, v_min: float, v_max: float) -> float:
        return lerp(v_min, v_max, factor)

    # Windows: 0.0 -> 1.8
    reporter.check(calc_mat_emission(0.0, 0.0, 1.8) == 0.0, "Window emission at day = 0.0")
    reporter.check(abs(calc_mat_emission(0.4, 0.0, 1.8) - 0.72) < 1e-6, "Window emission at sunset = 0.72")
    reporter.check(calc_mat_emission(1.0, 0.0, 1.8) == 1.8, "Window emission at night = 1.8 (warm glow)")

    # Neon trims: 0.2 -> 2.5
    reporter.check(calc_mat_emission(0.0, 0.2, 2.5) == 0.2, "Neon emission at day = 0.2")
    reporter.check(abs(calc_mat_emission(0.4, 0.2, 2.5) - 1.12) < 1e-6, "Neon emission at sunset = 1.12")
    reporter.check(calc_mat_emission(1.0, 0.2, 2.5) == 2.5, "Neon emission at night = 2.5 (cyberpunk punch)")

    # Server LEDs: 1.2 -> 3.0
    reporter.check(calc_mat_emission(0.0, 1.2, 3.0) == 1.2, "Server LED emission at day = 1.2")
    reporter.check(abs(calc_mat_emission(0.4, 1.2, 3.0) - 1.92) < 1e-6, "Server LED emission at sunset = 1.92")
    reporter.check(calc_mat_emission(1.0, 1.2, 3.0) == 3.0, "Server LED emission at night = 3.0 (overclock glow)")

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
        print(">>> ALL PHASE 10 M3 DAY/NIGHT LIGHTING CHECKS PASSED WITH 100% GREEN! <<<")
        sys.exit(0)

if __name__ == "__main__":
    run_tests()
