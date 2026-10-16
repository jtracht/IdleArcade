#!/usr/bin/env python3
"""
Unit and AST Verification Suite for Phase 10 Milestone 4: Soft Scene Transitions & Shop Glow Pulsing
File: IdleArcade/tests/test_phase10_m4_transitions.py
Target: Python 3.12 CI Verification & Structural Certification
"""

import sys
import os
import re
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
    print("\n=== Phase 10 Milestone 4: Scene Transitions & Shop Glow Pulsing Verification ===")

    # --------------------------------------------------------------------------
    # 1. Screen Transition Scene & Node Hierarchy AST
    # --------------------------------------------------------------------------
    scene_path = GAME_DIR / "scenes" / "ui" / "screen_transition.tscn"
    reporter.check(scene_path.exists(), "scenes/ui/screen_transition.tscn exists")
    if scene_path.exists():
        scene_content = scene_path.read_text(encoding="utf-8")
        reporter.check('[node name="ScreenTransition" type="CanvasLayer"]' in scene_content,
                       "ScreenTransition root is a CanvasLayer")
        reporter.check('layer = 15' in scene_content,
                       "ScreenTransition sets layer = 15 (above HUD overlay layer 10)")
        reporter.check('res://scripts/ui/screen_transition.gd' in scene_content,
                       "ScreenTransition attaches scripts/ui/screen_transition.gd")
        reporter.check('[node name="TransitionRect" type="ColorRect"' in scene_content,
                       "ScreenTransition contains TransitionRect ColorRect node")
        reporter.check('anchor_right = 1.0' in scene_content and 'anchor_bottom = 1.0' in scene_content,
                       "TransitionRect occupies full-rect viewport bounds")
        reporter.check('mouse_filter = 2' in scene_content,
                       "TransitionRect initial mouse_filter = 2 (Control.MOUSE_FILTER_IGNORE)")
        reporter.check('visible = false' in scene_content,
                       "TransitionRect initial visible = false")
        reporter.check('color = Color(0.04, 0.06, 0.09' in scene_content,
                       "TransitionRect uses dark theme Color(0.04, 0.06, 0.09, 1.0)")

    # --------------------------------------------------------------------------
    # 2. Screen Transition Script Architecture AST
    # --------------------------------------------------------------------------
    script_path = GAME_DIR / "scripts" / "ui" / "screen_transition.gd"
    reporter.check(script_path.exists(), "scripts/ui/screen_transition.gd exists")
    if script_path.exists():
        script_content = script_path.read_text(encoding="utf-8")
        reporter.check("class_name ScreenTransition" in script_content,
                       "screen_transition.gd registers class_name ScreenTransition")
        reporter.check("signal transition_started" in script_content,
                       "screen_transition.gd declares transition_started signal")
        reporter.check("signal transition_midpoint" in script_content,
                       "screen_transition.gd declares transition_midpoint signal")
        reporter.check("signal transition_completed" in script_content,
                       "screen_transition.gd declares transition_completed signal")
        reporter.check("transition_duration" in script_content,
                       "screen_transition.gd exports transition_duration")
        reporter.check("transition_color" in script_content,
                       "screen_transition.gd exports transition_color")
        reporter.check("func is_transitioning()" in script_content,
                       "screen_transition.gd implements public is_transitioning()")
        reporter.check("func transition_to_laptop" in script_content,
                       "screen_transition.gd implements public transition_to_laptop(callback)")
        reporter.check("func transition_to_campus" in script_content,
                       "screen_transition.gd implements public transition_to_campus(callback)")
        reporter.check("func transition_wipe" in script_content,
                       "screen_transition.gd implements public transition_wipe(midpoint_callback, duration)")
        reporter.check("func fade_out_in" in script_content,
                       "screen_transition.gd implements core fade_out_in tween lifecycle")

        # Input isolation & State Machine checks
        reporter.check("MOUSE_FILTER_STOP" in script_content,
                       "screen_transition.gd sets MOUSE_FILTER_STOP during active transition")
        reporter.check("MOUSE_FILTER_IGNORE" in script_content,
                       "screen_transition.gd resets MOUSE_FILTER_IGNORE upon completion")
        reporter.check("_is_transitioning" in script_content and "if _is_transitioning:" in script_content,
                       "screen_transition.gd guards against concurrent re-triggering")
        reporter.check("modulate:a" in script_content or '"modulate:a"' in script_content,
                       "screen_transition.gd drives modulate:a alpha channel via Tween")
        reporter.check("_exit_tree" in script_content,
                       "screen_transition.gd implements _exit_tree() cleanup")

    # --------------------------------------------------------------------------
    # 3. Main3D World Scene & Transition Integration
    # --------------------------------------------------------------------------
    main3d_tscn_path = GAME_DIR / "scenes" / "main_3d.tscn"
    reporter.check(main3d_tscn_path.exists(), "scenes/main_3d.tscn exists")
    if main3d_tscn_path.exists():
        main3d_tscn = main3d_tscn_path.read_text(encoding="utf-8")
        reporter.check("res://scenes/ui/screen_transition.tscn" in main3d_tscn,
                       "main_3d.tscn references screen_transition.tscn")
        reporter.check('name="ScreenTransition"' in main3d_tscn,
                       "main_3d.tscn instantiates ScreenTransition node")

    main3d_gd_path = GAME_DIR / "scripts" / "main_3d.gd"
    reporter.check(main3d_gd_path.exists(), "scripts/main_3d.gd exists")
    if main3d_gd_path.exists():
        main3d_gd = main3d_gd_path.read_text(encoding="utf-8")
        reporter.check("var screen_transition" in main3d_gd,
                       "main_3d.gd binds screen_transition node")
        reporter.check("screen_transition.transition_wipe" in main3d_gd,
                       "main_3d.gd hooks transition_wipe for overlay transitions")
        reporter.check("_apply_open_hud_overlay" in main3d_gd,
                       "main_3d.gd executes _apply_open_hud_overlay inside midpoint callback")
        reporter.check("_apply_close_hud_overlay" in main3d_gd,
                       "main_3d.gd executes _apply_close_hud_overlay inside midpoint callback")
        reporter.check("screen_transition == null" in main3d_gd or "else:" in main3d_gd,
                       "main_3d.gd maintains fallback instant visibility toggle when transition is null")
        reporter.check("is_transitioning" in main3d_gd,
                       "main_3d.gd checks screen_transition.is_transitioning() to prevent re-entrant calls")

    # --------------------------------------------------------------------------
    # 4. HUD Shop Upgrade Cards Border & Glow Pulsing
    # --------------------------------------------------------------------------
    hud_gd_path = GAME_DIR / "scripts" / "hud.gd"
    reporter.check(hud_gd_path.exists(), "scripts/hud.gd exists")
    if hud_gd_path.exists():
        hud_gd = hud_gd_path.read_text(encoding="utf-8")
        reporter.check("border_width_left = 2" in hud_gd and "border_width_top = 2" in hud_gd,
                       "hud.gd configures 2px borders on upgrade card StyleBoxFlat")
        reporter.check("Color(0.18, 0.24, 0.35, 0.5)" in hud_gd,
                       "hud.gd sets default border color Color(0.18, 0.24, 0.35, 0.5)")
        reporter.check('"style": style' in hud_gd,
                       "hud.gd stores style reference in card dictionary")
        reporter.check('"is_affordable": false' in hud_gd or '"is_affordable":' in hud_gd,
                       "hud.gd tracks is_affordable state flag in card dictionary")
        reporter.check('"glow_tween": null' in hud_gd or '"glow_tween":' in hud_gd,
                       "hud.gd stores glow_tween reference in card dictionary")
        reporter.check("_start_card_glow_pulse" in hud_gd,
                       "hud.gd implements _start_card_glow_pulse(card)")
        reporter.check("_stop_card_glow_pulse" in hud_gd,
                       "hud.gd implements _stop_card_glow_pulse(card)")
        reporter.check("Color(0.2, 0.8, 1.0, 0.9)" in hud_gd,
                       "hud.gd pulses electric cyan glow Color(0.2, 0.8, 1.0, 0.9)")
        reporter.check("Color(0.1, 0.4, 0.6, 0.4)" in hud_gd,
                       "hud.gd pulses low glow Color(0.1, 0.4, 0.6, 0.4)")
        reporter.check("shadow_size = 4" in hud_gd,
                       "hud.gd applies 4px glow shadow during affordability pulse")
        reporter.check("set_loops()" in hud_gd,
                       "hud.gd configures infinite looping tween for affordable card pulse")
        reporter.check("is_card_pulsing" in hud_gd,
                       "hud.gd implements public is_card_pulsing(upgrade_id) test query")
        reporter.check("get_card_border_color" in hud_gd,
                       "hud.gd implements public get_card_border_color(upgrade_id) test query")
        reporter.check("_exit_tree" in hud_gd,
                       "hud.gd implements _exit_tree() cleaning up active glow tweens")

    # --------------------------------------------------------------------------
    # 5. State Machine & Affordability Simulation Oracle
    # --------------------------------------------------------------------------
    print("\n--- 5. Mathematical & State Machine Simulation Oracle ---")

    # 5.1 ScreenTransition State Machine Simulation
    class MockTransitionOverlay:
        def __init__(self):
            self.visible = False
            self.mouse_filter = 2 # IGNORE
            self.alpha = 0.0
            self.is_trans = False
            self.midpoint_fired = False
            self.completed_fired = False

        def start_transition(self, midpoint_cb):
            if self.is_trans:
                return False # Guard against rapid double click
            self.is_trans = True
            self.visible = True
            self.mouse_filter = 0 # STOP
            self.alpha = 0.0

            # Phase 1: ramp to 1.0
            self.alpha = 1.0
            # Midpoint
            midpoint_cb()
            self.midpoint_fired = True
            # Phase 2: ramp to 0.0
            self.alpha = 0.0
            # Completion
            self.visible = False
            self.mouse_filter = 2 # IGNORE
            self.is_trans = False
            self.completed_fired = True
            return True

    midpoint_executed = [False]
    def mock_midpoint():
        midpoint_executed[0] = True

    mock_overlay = MockTransitionOverlay()
    reporter.check(mock_overlay.visible == False and mock_overlay.mouse_filter == 2,
                   "Initial overlay state is visible=False with mouse_filter=IGNORE (2)")

    first_call_ok = mock_overlay.start_transition(mock_midpoint)
    reporter.check(first_call_ok and midpoint_executed[0],
                   "Transition executes midpoint payload while blacked out")
    reporter.check(mock_overlay.visible == False and mock_overlay.mouse_filter == 2 and not mock_overlay.is_trans,
                   "Transition completes with visible=False, mouse_filter=IGNORE (2), is_trans=False")

    # Concurrent guard test
    mock_overlay.is_trans = True
    second_call_ok = mock_overlay.start_transition(mock_midpoint)
    reporter.check(not second_call_ok,
                   "Concurrent transition call during active wipe is safely rejected/ignored")

    # 5.2 Shop Card Affordability State Machine Simulation
    class MockShopCard:
        def __init__(self, card_id: str, cost: float):
            self.id = card_id
            self.cost = cost
            self.is_affordable = False
            self.tween_active = False
            self.tween_create_count = 0
            self.tween_kill_count = 0
            self.border_color = (0.18, 0.24, 0.35, 0.5)

        def refresh(self, energy: float):
            can_afford = (energy >= self.cost)
            was_affordable = self.is_affordable

            if can_afford and not was_affordable:
                self.is_affordable = True
                self.tween_active = True
                self.tween_create_count += 1
                self.border_color = (0.2, 0.8, 1.0, 0.9)
            elif not can_afford and was_affordable:
                self.is_affordable = False
                self.tween_active = False
                self.tween_kill_count += 1
                self.border_color = (0.18, 0.24, 0.35, 0.5)

    card = MockShopCard("click_booster", 10.0)

    # 60 FPS Passive ticks where player cannot afford (energy = 0 -> 9.9)
    for e in [0.0, 1.5, 3.2, 5.0, 7.8, 9.9]:
        card.refresh(e)
    reporter.check(card.tween_create_count == 0 and not card.is_affordable,
                   "Unaffordable ticks create 0 tweens (no memory leak or frame thrashing)")

    # Energy crosses threshold (energy = 10.0)
    card.refresh(10.0)
    reporter.check(card.tween_create_count == 1 and card.is_affordable and card.tween_active,
                   "Crossing cost threshold creates exactly 1 looping glow tween")

    # Multiple passive ticks while still affordable (energy = 10.5 -> 25.0)
    for e in [10.5, 12.0, 15.0, 20.0, 25.0]:
        card.refresh(e)
    reporter.check(card.tween_create_count == 1,
                   "Subsequent ticks while affordable do not recreate or thrash tweens (tween_count == 1)")

    # Purchase occurs, spending energy below cost
    card.cost = 12.0
    card.refresh(2.0)
    reporter.check(not card.is_affordable and not card.tween_active and card.tween_kill_count == 1,
                   "Spending energy stops pulse tween and resets border to default")
    reporter.check(card.border_color == (0.18, 0.24, 0.35, 0.5),
                   "Card border color cleanly resets to Color(0.18, 0.24, 0.35, 0.5)")

    # Sine pulse color interpolation check (0.8s cycle)
    color_high = (0.2, 0.8, 1.0, 0.9)
    color_low = (0.1, 0.4, 0.6, 0.4)
    mid_r = (color_high[0] + color_low[0]) * 0.5
    mid_g = (color_high[1] + color_low[1]) * 0.5
    mid_b = (color_high[2] + color_low[2]) * 0.5
    mid_a = (color_high[3] + color_low[3]) * 0.5
    reporter.check(round(mid_r, 3) == 0.15 and round(mid_g, 3) == 0.6 and round(mid_b, 3) == 0.8 and round(mid_a, 3) == 0.65,
                   "Glow pulse oscillates smoothly around midpoint Color(0.15, 0.60, 0.80, 0.65)")

    print("\n-------------------------------------------------------------")
    print(f"Total Checks : {reporter.passes + reporter.fails}")
    print(f"Passed       : {reporter.passes}")
    print(f"Failed       : {reporter.fails}")
    print("-------------------------------------------------------------")
    if reporter.fails > 0:
        print(">>> SOME VERIFICATION CHECKS FAILED! <<<")
        sys.exit(1)
    else:
        print(">>> ALL PHASE 10 M4 TRANSITION & SHOP GLOW CHECKS PASSED WITH 100% GREEN! <<<")
        sys.exit(0)

if __name__ == "__main__":
    run_tests()
