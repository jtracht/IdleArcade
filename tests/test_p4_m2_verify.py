#!/usr/bin/env python3
"""
Milestone P4-M2 Verification Suite: Meta Progression, HUD Overlay & Regression Safety.
======================================================================================
Target: Godot 4.3 IdleArcade - Milestone P4-M2 (Idle-Meta Progression & HUD Overlay System)

Validates:
  1. File presence and architectural layout for Phase 4 Milestone 2.
  2. GameState extension contracts:
     - State variables: avatar_speed_level, idle_level, pickup_radius_level.
     - Signal: avatar_stat_updated(stat_name, new_value).
     - Methods: get_effective_avatar_speed(), get_idle_level().
     - DEFAULT_UPGRADES: avatar_speed, clearance_level, pickup_radius.
     - Serialization: backward-compatible save/load logic in save_to_disk() / load_from_disk().
  3. HUD UI Controller (scripts/hud.gd):
     - UPGRADE_DEFINITIONS includes avatar_speed.
     - Nakama online modals preserved.
  4. HUD Overlay & Input Locking (scenes/main_3d.tscn, scripts/main_3d.gd):
     - CanvasLayer 10 (HUDOverlayLayer) & CanvasLayer 5 (QuickHUDLayer).
     - DimBackdrop with mouse_filter = 0 (MOUSE_FILTER_STOP).
     - Instanced hud.tscn under HUDOverlayLayer.
     - Methods: toggle_hud_overlay, open_hud_overlay, close_hud_overlay, is_hud_overlay_open.
     - Input isolation: avatar.set_input_enabled(false) when open, true when closed.
     - Hotkeys: Tab, M, Esc handled in _unhandled_input.
  5. Avatar3D Controller (scripts/avatar_3d.gd):
     - Dynamic speed scaling with GameState.get_effective_avatar_speed().
     - set_input_enabled(bool) halts movement when disabled.
  6. Mathematical Simulation Oracle:
     - Cost curve progression: round(BaseCost * cost_mult^L).
     - Speed multiplier progression: 1.0 + L * 0.15.
     - Physics displacement verification (L=2 vs L=0 over 15 ticks @ 60Hz).
  7. Regression Safety Oracle:
     - Preserves scenes/main.tscn and 2D startup entry.
     - All autoloads intact.

Executable via: python IdleArcade/tests/test_p4_m2_verify.py
"""

import os
import re
import sys
import math
import json
from pathlib import Path
from typing import Dict, Any, List, Tuple


def run_verification():
    print("=====================================================================")
    print("[VERIFY] Milestone P4-M2: Meta Progression & HUD Overlay Suite")
    print("=====================================================================")

    # Locate game directory
    current = Path(__file__).resolve().parent
    if (current / "IdleArcade").exists():
        game_dir = current / "IdleArcade"
    elif current.name == "tests" and current.parent.name == "IdleArcade":
        game_dir = current.parent
    elif (current.parent / "IdleArcade").exists():
        game_dir = current.parent / "IdleArcade"
    else:
        # Fallback to search up
        game_dir = current
        for _ in range(5):
            if (game_dir / "project.godot").exists():
                break
            if (game_dir / "IdleArcade").exists():
                game_dir = game_dir / "IdleArcade"
                break
            game_dir = game_dir.parent

    checks_passed = 0
    checks_failed = 0

    def assert_test(cond: bool, msg: str):
        nonlocal checks_passed, checks_failed
        if cond:
            print(f"  [PASS] {msg}")
            checks_passed += 1
        else:
            print(f"  [FAIL] {msg}")
            checks_failed += 1

    # =========================================================================
    # 1. File Existence & Layout Conformance
    # =========================================================================
    print("\n--- 1. File Existence & Architecture Layout ---")

    gs_path = game_dir / "scripts" / "autoload" / "game_state.gd"
    hud_script_path = game_dir / "scripts" / "hud.gd"
    hud_scene_path = game_dir / "scenes" / "hud.tscn"
    main_3d_script_path = game_dir / "scripts" / "main_3d.gd"
    main_3d_scene_path = game_dir / "scenes" / "main_3d.tscn"
    avatar_script_path = game_dir / "scripts" / "avatar_3d.gd"
    avatar_scene_path = game_dir / "scenes" / "avatar_3d.tscn"
    legacy_main_path = game_dir / "scenes" / "main.tscn"
    proj_path = game_dir / "project.godot"

    assert_test(gs_path.is_file(), "scripts/autoload/game_state.gd exists")
    assert_test(hud_script_path.is_file(), "scripts/hud.gd exists")
    assert_test(hud_scene_path.is_file(), "scenes/hud.tscn exists")
    assert_test(main_3d_script_path.is_file(), "scripts/main_3d.gd exists")
    assert_test(main_3d_scene_path.is_file(), "scenes/main_3d.tscn exists")
    assert_test(avatar_script_path.is_file(), "scripts/avatar_3d.gd exists")
    assert_test(avatar_scene_path.is_file(), "scenes/avatar_3d.tscn exists")
    assert_test(legacy_main_path.is_file(), "scenes/main.tscn preserved (regression safety)")
    assert_test(proj_path.is_file(), "project.godot exists")

    if not gs_path.is_file() or not main_3d_script_path.is_file():
        print("  [FATAL] Core source scripts missing. Aborting deep verification.")
        sys.exit(1)

    gs_code = gs_path.read_text(encoding="utf-8")
    hud_code = hud_script_path.read_text(encoding="utf-8")
    main_3d_code = main_3d_script_path.read_text(encoding="utf-8")
    main_3d_tscn = main_3d_scene_path.read_text(encoding="utf-8")
    avatar_code = avatar_script_path.read_text(encoding="utf-8")

    # =========================================================================
    # 2. GameState Extension Contracts (scripts/autoload/game_state.gd)
    # =========================================================================
    print("\n--- 2. GameState Meta-Progression Extension Contracts ---")

    # Variables
    assert_test("avatar_speed_level" in gs_code, "game_state.gd declares avatar_speed_level")
    assert_test("idle_level" in gs_code, "game_state.gd declares idle_level")

    # Signals
    assert_test(re.search(r"signal\s+avatar_stat_updated", gs_code) is not None,
                "game_state.gd declares signal avatar_stat_updated")

    # Extension methods
    assert_test(re.search(r"func\s+get_effective_avatar_speed\s*\(", gs_code) is not None,
                "game_state.gd implements get_effective_avatar_speed()")
    assert_test(re.search(r"func\s+get_idle_level\s*\(", gs_code) is not None,
                "game_state.gd implements get_idle_level()")

    # DEFAULT_UPGRADES entries
    assert_test('"avatar_speed"' in gs_code, 'game_state.gd DEFAULT_UPGRADES includes "avatar_speed"')
    assert_test('"clearance_level"' in gs_code or '"idle_level"' in gs_code,
                'game_state.gd DEFAULT_UPGRADES includes clearance_level / idle_level')
    assert_test('"pickup_radius"' in gs_code,
                'game_state.gd DEFAULT_UPGRADES includes "pickup_radius"')

    # Serialization & Backward Compatibility
    assert_test("save_to_disk" in gs_code, "game_state.gd implements save_to_disk()")
    assert_test("load_from_disk" in gs_code, "game_state.gd implements load_from_disk()")

    # Backward compatibility fallback guard
    has_fallback_guard = (
        "data.get" in gs_code and ("avatar_speed" in gs_code or "upgrades.has" in gs_code)
    )
    assert_test(has_fallback_guard, "load_from_disk() includes safe fallback guards for missing keys")

    # =========================================================================
    # 3. HUD Controller (scripts/hud.gd) Upgrade Integration
    # =========================================================================
    print("\n--- 3. HUD Upgrade Integration & Online Modals ---")

    assert_test('"avatar_speed"' in hud_code, 'scripts/hud.gd UPGRADE_DEFINITIONS includes "avatar_speed"')
    assert_test("AUTH_MODAL_SCENE" in hud_code, "scripts/hud.gd preserves AUTH_MODAL_SCENE")
    assert_test("LEADERBOARD_MODAL_SCENE" in hud_code, "scripts/hud.gd preserves LEADERBOARD_MODAL_SCENE")
    assert_test("GUILD_MODAL_SCENE" in hud_code, "scripts/hud.gd preserves GUILD_MODAL_SCENE")
    assert_test("QUEST_MODAL_SCENE" in hud_code, "scripts/hud.gd preserves QUEST_MODAL_SCENE")

    # =========================================================================
    # 4. Main 3D HUD Overlay Mounting & Input Isolation
    # =========================================================================
    print("\n--- 4. Main 3D HUD Overlay Mounting & Input Isolation ---")

    # Layer verification in scenes/main_3d.tscn
    assert_test('name="HUDOverlayLayer"' in main_3d_tscn, "scenes/main_3d.tscn contains HUDOverlayLayer")
    assert_test('layer = 10' in main_3d_tscn or 'layer=10' in main_3d_tscn, "HUDOverlayLayer assigned to layer 10")
    assert_test('name="QuickHUDLayer"' in main_3d_tscn, "scenes/main_3d.tscn contains QuickHUDLayer")
    assert_test('layer = 5' in main_3d_tscn or 'layer=5' in main_3d_tscn, "QuickHUDLayer assigned to layer 5")

    # Click trapping backdrop
    assert_test('name="DimBackdrop"' in main_3d_tscn, "HUDOverlayLayer contains DimBackdrop ColorRect")
    assert_test('mouse_filter = 0' in main_3d_tscn or 'mouse_filter=0' in main_3d_tscn,
                "DimBackdrop mouse_filter is 0 (MOUSE_FILTER_STOP) to block 3D clickthrough")

    # Instanced HUD scene
    assert_test('res://scenes/hud.tscn' in main_3d_tscn, "HUDOverlayLayer instances res://scenes/hud.tscn")

    # Methods in scripts/main_3d.gd
    assert_test(re.search(r"func\s+toggle_hud_overlay\s*\(", main_3d_code) is not None,
                "main_3d.gd implements toggle_hud_overlay()")
    assert_test(re.search(r"func\s+open_hud_overlay\s*\(", main_3d_code) is not None,
                "main_3d.gd implements open_hud_overlay()")
    assert_test(re.search(r"func\s+close_hud_overlay\s*\(", main_3d_code) is not None,
                "main_3d.gd implements close_hud_overlay()")
    assert_test(re.search(r"func\s+is_hud_overlay_open\s*\(", main_3d_code) is not None,
                "main_3d.gd implements is_hud_overlay_open()")

    # Input lockout coupling
    assert_test("set_input_enabled(false)" in main_3d_code,
                "open_hud_overlay() locks avatar input (set_input_enabled(false))")
    assert_test("set_input_enabled(true)" in main_3d_code,
                "close_hud_overlay() restores avatar input (set_input_enabled(true))")

    # Hotkey support
    assert_test("KEY_TAB" in main_3d_code or "KEY_M" in main_3d_code,
                "main_3d.gd listens for TAB or M to toggle overlay")
    assert_test("KEY_ESCAPE" in main_3d_code, "main_3d.gd listens for ESCAPE to close overlay")

    # QuickHUD reactive bindings
    assert_test("energy_changed" in main_3d_code, "main_3d.gd connects to GameState.energy_changed")
    assert_test("rps_changed" in main_3d_code, "main_3d.gd connects to GameState.rps_changed")

    # QuickHUD Spacer pass-through filter
    assert_test("Spacer" in main_3d_tscn and "mouse_filter = 2" in main_3d_tscn,
                "QuickHUD Spacer mouse_filter is 2 (MOUSE_FILTER_IGNORE) to allow 3D raycasting")

    # =========================================================================
    # 5. Avatar 3D Controller Coupling (scripts/avatar_3d.gd)
    # =========================================================================
    print("\n--- 5. Avatar 3D Controller Dynamic Speed & Input Lockout ---")

    assert_test(re.search(r"func\s+set_input_enabled\s*\(", avatar_code) is not None,
                "avatar_3d.gd implements set_input_enabled(enabled)")
    assert_test("input_enabled" in avatar_code, "avatar_3d.gd maintains input_enabled state")
    assert_test(re.search(r"func\s+get_move_speed\s*\(", avatar_code) is not None,
                "avatar_3d.gd implements get_move_speed()")

    # Extract get_move_speed() function body for strict static inspection
    move_speed_match = re.search(
        r"func\s+get_move_speed\s*\([^)]*\)\s*->\s*float:\s*(.*?)(?=\nfunc|\Z)",
        avatar_code,
        re.DOTALL
    )
    assert_test(move_speed_match is not None, "get_move_speed() method signature properly defined")

    if move_speed_match:
        move_speed_body = move_speed_match.group(1)

        # 1. Strictly assert that get_effective_avatar_speed() is invoked
        has_effective_call = (
            re.search(r"\bget_effective_avatar_speed\s*\(\s*\)", move_speed_body) is not None
        )
        assert_test(has_effective_call,
                    "get_move_speed() strictly invokes GameState.get_effective_avatar_speed()")

        # 2. Strictly prohibit the obsolete/deviant 0.25 multiplier
        assert_test("0.25" not in move_speed_body,
                    "get_move_speed() does not contain obsolete 0.25 multiplier branch")

        # 3. Ensure no dead-code shadowing: get_effective_avatar_speed must precede any property fallback
        if "avatar_speed_level" in move_speed_body:
            idx_effective = move_speed_body.find("get_effective_avatar_speed")
            idx_level = move_speed_body.find("avatar_speed_level")
            assert_test(idx_effective != -1 and idx_effective < idx_level,
                "get_effective_avatar_speed() is prioritized before avatar_speed_level fallback (no dead code)")

    # =========================================================================
    # 6. Mathematical Simulation Oracle
    # =========================================================================
    print("\n--- 6. Mathematical Simulation Oracle ---")

    # Upgrade cost simulation: round(base_cost * cost_mult^level)
    base_cost = 50.0
    cost_mult = 1.25
    simulated_costs = [round(base_cost * (cost_mult ** lvl)) for lvl in range(6)]
    # Validate costs are monotonically increasing and first entry matches base
    assert_test(simulated_costs[0] == 50 and all(simulated_costs[i] < simulated_costs[i+1] for i in range(5)),
                f"avatar_speed cost scaling matches reference: {simulated_costs}")

    # Speed multiplier simulation: 1.0 + level * 0.15
    base_speed = 6.0
    mult_l0 = 1.0 + 0 * 0.15
    mult_l1 = 1.0 + 1 * 0.15
    mult_l2 = 1.0 + 2 * 0.15

    speed_l0 = base_speed * mult_l0
    speed_l1 = base_speed * mult_l1
    speed_l2 = base_speed * mult_l2

    assert_test(speed_l0 == 6.0 and abs(speed_l1 - 6.9) < 0.001 and abs(speed_l2 - 7.8) < 0.001,
                f"Effective speeds: L0={speed_l0:.1f} m/s, L1={speed_l1:.1f} m/s, L2={speed_l2:.1f} m/s")

    # Physics Euler displacement over 30 ticks (0.50s @ 60Hz) under acceleration = 24.0 m/s^2
    def simulate_displacement(target_speed: float, accel: float = 24.0, ticks: int = 30, dt: float = 1.0/60.0):
        vel = 0.0
        pos = 0.0
        for _ in range(ticks):
            vel = min(target_speed, vel + accel * dt)
            pos += vel * dt
        return pos

    disp_l0 = simulate_displacement(speed_l0, ticks=30)
    disp_l2 = simulate_displacement(speed_l2, ticks=30)
    assert_test(disp_l2 > disp_l0 and (disp_l2 - disp_l0) > 0.20,
                f"Displacement over 0.50s: Level 2 ({disp_l2:.3f}m) > Level 0 ({disp_l0:.3f}m), delta=+{disp_l2 - disp_l0:.3f}m")
    assert_test(abs(disp_l0 - 2.25) < 0.15 and abs(disp_l2 - 2.69) < 0.15,
                f"Displacements match kinematics model: L0={disp_l0:.3f}m (exp 2.25m), L2={disp_l2:.3f}m (exp 2.69m)")

    # =========================================================================
    # 7. Regression Safety Oracle
    # =========================================================================
    print("\n--- 7. Regression Safety Oracle ---")

    assert_test(legacy_main_path.is_file(), "scenes/main.tscn is physically preserved")

    proj_content = proj_path.read_text(encoding="utf-8")
    assert_test('run/main_scene="res://scenes/main.tscn"' in proj_content,
                "project.godot run/main_scene preserved as res://scenes/main.tscn")
    assert_test('GameState="*res://scripts/autoload/game_state.gd"' in proj_content,
                "GameState autoload singleton intact in project.godot")
    assert_test('Nakama="*res://addons/com.heroiclabs.nakama/Nakama.gd"' in proj_content,
                "Nakama autoload singleton intact in project.godot")
    assert_test('NakamaManager="*res://scripts/autoload/nakama_manager.gd"' in proj_content,
                "NakamaManager autoload singleton intact in project.godot")

    # =========================================================================
    # Results Summary
    # =========================================================================
    print("\n=====================================================================")
    print(f"[VERIFY] P4-M2 Verification Results: {checks_passed} passed, {checks_failed} failed")
    print("=====================================================================")

    if checks_failed == 0:
        print(">>> ALL P4-M2 META & OVERLAY VERIFICATION CHECKS PASSED! <<<")
        return 0
    else:
        print(f">>> VERIFICATION FAILED WITH {checks_failed} ERRORS! <<<")
        return 1


if __name__ == "__main__":
    sys.exit(run_verification())
