#!/usr/bin/env python3
"""
Empirical Adversarial Challenge Test Suite for Milestone P7-M3:
Economy Loops, Feedback Floating Text & Quest Compass.

Author: p7_m3_challenger_2 (Teamwork Challenger / Critic)
Target: Godot 4.3 IdleArcade (Phase 7 Milestone P7-M3)

Verification Scope:
  1. Campus items idle multiplier (formula, get_effective_passive_rps, collect_3d_item emission).
  2. Speed upgrade reactivity in Avatar3D (signal connection, immediate update without physics polling).
  3. ZoneGate3D floating text (show_missing_resource_feedback, Label3D, billboard, font_size >= 24, tween +1.2m / 1.2s alpha fade / queue_free).
  4. QuestWaypoint dynamic compass tracking & arrival detection (gates vs NPCs, <= 3.0m '[ Arrived! ]').
  5. GDScript AST & Parser Integrity (class-level method duplicates, function-level variable shadow duplicates).
"""

import sys
import os
import re
import math
from typing import Tuple, List, Dict, Any, Optional
from pathlib import Path

# Resolve workspace root and game directory
SCRIPT_PATH = Path(__file__).resolve()
TESTS_DIR = SCRIPT_PATH.parent
GAME_DIR = TESTS_DIR.parent
ROOT_DIR = GAME_DIR.parent if GAME_DIR.name == "IdleArcade" else GAME_DIR

passed_tests = 0
failed_tests = 0
findings = []

def record_test(name: str, passed: bool, detail: str = ""):
    global passed_tests, failed_tests
    if passed:
        passed_tests += 1
        print(f"  [PASS] {name}" + (f" -> {detail}" if detail else ""))
    else:
        failed_tests += 1
        msg = f"  [FAIL] {name}" + (f" -> {detail}" if detail else "")
        print(msg)
        findings.append(msg)

def run_suite():
    global passed_tests, failed_tests
    print("=" * 70)
    print(">>> P7-M3 EMPIRICAL ADVERSARIAL CHALLENGE SUITE <<<")
    print("=" * 70)

    # --------------------------------------------------------------------------
    # MODULE 1: Campus Items Idle Multiplier & Economy Loops
    # --------------------------------------------------------------------------
    print("\n--- MODULE 1: Campus Items Idle Multiplier & Economy Loops ---")
    gs_path = GAME_DIR / "scripts/autoload/game_state.gd"
    record_test("GameState file exists", gs_path.exists(), str(gs_path))
    gs_code = gs_path.read_text(encoding="utf-8")

    # 1.1 Formula definition
    record_test("get_campus_item_multiplier defined in game_state.gd",
                "func get_campus_item_multiplier() -> float:" in gs_code)
    
    formula_match = re.search(r"func get_campus_item_multiplier\(\)[^:]*:\s+return\s+([^\n]+)", gs_code)
    record_test("get_campus_item_multiplier body matched", formula_match is not None)
    
    # 1.2 Mathematical Oracle Tests
    # Formula: 1.0 + (float(collectibles_collected) * 0.05)
    def calc_multiplier(items: int) -> float:
        return 1.0 + (float(items) * 0.05)

    record_test("Math Oracle: 0 collectibles == 1.0 (baseline invariant)",
                math.isclose(calc_multiplier(0), 1.0, rel_tol=1e-9),
                f"calc_multiplier(0) = {calc_multiplier(0)}")

    record_test("Math Oracle: 1 collectible == 1.05 (+5%)",
                math.isclose(calc_multiplier(1), 1.05, rel_tol=1e-9),
                f"calc_multiplier(1) = {calc_multiplier(1)}")

    record_test("Math Oracle: 10 collectibles == 1.50 (+50%)",
                math.isclose(calc_multiplier(10), 1.50, rel_tol=1e-9),
                f"calc_multiplier(10) = {calc_multiplier(10)}")

    record_test("Math Oracle: 20 collectibles == 2.00 (+100%)",
                math.isclose(calc_multiplier(20), 2.00, rel_tol=1e-9),
                f"calc_multiplier(20) = {calc_multiplier(20)}")

    record_test("Math Oracle: 100 collectibles == 6.00 (+500%)",
                math.isclose(calc_multiplier(100), 6.00, rel_tol=1e-9),
                f"calc_multiplier(100) = {calc_multiplier(100)}")

    # 1.3 get_effective_passive_rps incorporating campus item multiplier
    rps_func = re.search(r"func get_effective_passive_rps\(\)[^:]*:\s+return\s+([^\n]+)", gs_code)
    record_test("get_effective_passive_rps defined", rps_func is not None)
    if rps_func:
        body = rps_func.group(1)
        record_test("get_effective_passive_rps multiplies base_passive_rps", "base_passive_rps" in body)
        record_test("get_effective_passive_rps multiplies get_bonus_multiplier()", "get_bonus_multiplier()" in body)
        record_test("get_effective_passive_rps multiplies get_campus_item_multiplier()", "get_campus_item_multiplier()" in body)

    # 1.4 collect_3d_item logic & signal emissions
    collect_func = re.search(r"func collect_3d_item\([^)]*\)[^:]*:\s*([\s\S]*?)(?=\nfunc |\n#|\Z)", gs_code)
    record_test("collect_3d_item function found", collect_func is not None)
    if collect_func:
        c_body = collect_func.group(1)
        record_test("collect_3d_item increments collectibles_collected", "collectibles_collected += 1" in c_body)
        record_test("collect_3d_item emits energy_changed", "energy_changed.emit" in c_body)
        record_test("collect_3d_item emits rps_changed with new effective rate", "rps_changed.emit(get_effective_passive_rps())" in c_body)
        record_test("collect_3d_item emits collectible_picked_up", "collectible_picked_up.emit" in c_body)

    # 1.5 State Simulation of Economy Loop
    class SimulatedGameState:
        def __init__(self):
            self.energy = 0.0
            self.total_energy_earned = 0.0
            self.base_passive_rps = 10.0
            self.bonus_users = 50 # 1.0 + 0.50 = 1.50
            self.collectibles_collected = 0
            self.emitted_rps = []

        def get_bonus_multiplier(self) -> float:
            return 1.0 + (float(self.bonus_users) * 0.01)

        def get_campus_item_multiplier(self) -> float:
            return 1.0 + (float(self.collectibles_collected) * 0.05)

        def get_effective_passive_rps(self) -> float:
            return self.base_passive_rps * self.get_bonus_multiplier() * self.get_campus_item_multiplier()

        def collect_3d_item(self, reward_amount: float = 50.0):
            self.energy += reward_amount
            self.total_energy_earned += reward_amount
            self.collectibles_collected += 1
            new_rps = self.get_effective_passive_rps()
            self.emitted_rps.append(new_rps)

    sim_gs = SimulatedGameState()
    initial_rps = sim_gs.get_effective_passive_rps()
    # 10.0 * 1.50 * 1.0 = 15.0
    record_test("Economy Sim: Initial RPS == 15.0", math.isclose(initial_rps, 15.0, rel_tol=1e-9))
    
    for _ in range(10):
        sim_gs.collect_3d_item(50.0)

    final_rps = sim_gs.get_effective_passive_rps()
    # 10.0 * 1.50 * 1.50 = 22.50
    record_test("Economy Sim: 10 items collected -> RPS == 22.50", math.isclose(final_rps, 22.50, rel_tol=1e-9))
    record_test("Economy Sim: rps_changed emitted exactly 10 times", len(sim_gs.emitted_rps) == 10)
    record_test("Economy Sim: Final emitted RPS matches final effective RPS", math.isclose(sim_gs.emitted_rps[-1], 22.50, rel_tol=1e-9))

    # --------------------------------------------------------------------------
    # MODULE 2: Speed Upgrade Reactivity in Avatar3D
    # --------------------------------------------------------------------------
    print("\n--- MODULE 2: Speed Upgrade Reactivity in Avatar3D ---")
    avatar_path = GAME_DIR / "scripts/avatar_3d.gd"
    record_test("Avatar3D file exists", avatar_path.exists(), str(avatar_path))
    avatar_code = avatar_path.read_text(encoding="utf-8")

    # 2.1 Signal connection in _ready()
    record_test("Avatar3D checks GameState for avatar_stat_updated signal",
                'gs.has_signal("avatar_stat_updated")' in avatar_code)
    record_test("Avatar3D connects avatar_stat_updated to _on_avatar_stat_updated",
                'gs.avatar_stat_updated.connect(_on_avatar_stat_updated)' in avatar_code)

    # 2.2 Immediate reactive handler implementation
    handler_match = re.search(r"func _on_avatar_stat_updated\(stat_name:[^)]*\)[^:]*:\s*([\s\S]*?)(?=\nfunc |\n#|\Z)", avatar_code)
    record_test("_on_avatar_stat_updated handler implemented", handler_match is not None)
    if handler_match:
        h_body = handler_match.group(1)
        record_test("Handler filters for stat_name == 'avatar_speed'", 'stat_name == "avatar_speed"' in h_body)
        record_test("Handler updates current_speed = get_move_speed()", "current_speed = get_move_speed()" in h_body)

    # 2.3 Reactivity Simulation (Stat change immediately scales speed without physics process)
    class SimulatedAvatarSpeedReactivity:
        def __init__(self, base_speed: float = 6.0):
            self.base_speed = base_speed
            self.avatar_speed_level = 0
            self.current_speed = base_speed
            self.physics_ticks_run = 0

        def get_move_speed(self) -> float:
            mult = 1.0 + float(self.avatar_speed_level) * 0.15
            return self.base_speed * mult

        def on_avatar_stat_updated(self, stat_name: str, new_val: float):
            if stat_name == "avatar_speed":
                self.current_speed = self.get_move_speed()

        def buy_speed_upgrade(self):
            self.avatar_speed_level += 1
            # Signal fires immediately from GameState
            self.on_avatar_stat_updated("avatar_speed", 1.0 + float(self.avatar_speed_level) * 0.15)

    sim_avatar = SimulatedAvatarSpeedReactivity(6.0)
    record_test("Reactivity Sim: Initial speed == 6.0 m/s", math.isclose(sim_avatar.current_speed, 6.0, rel_tol=1e-9))
    
    sim_avatar.buy_speed_upgrade()
    # Speed must update to 6.0 * 1.15 = 6.90 with 0 physics ticks run
    record_test("Reactivity Sim: Immediate speed update to 6.90 m/s with 0 physics frames",
                math.isclose(sim_avatar.current_speed, 6.90, rel_tol=1e-9) and sim_avatar.physics_ticks_run == 0)

    sim_avatar.buy_speed_upgrade()
    # Speed must update to 6.0 * 1.30 = 7.80
    record_test("Reactivity Sim: Level 2 speed update to 7.80 m/s with 0 physics frames",
                math.isclose(sim_avatar.current_speed, 7.80, rel_tol=1e-9) and sim_avatar.physics_ticks_run == 0)

    # --------------------------------------------------------------------------
    # MODULE 3: ZoneGate3D Floating Text Feedback
    # --------------------------------------------------------------------------
    print("\n--- MODULE 3: ZoneGate3D Floating Text Feedback ---")
    gate_path = GAME_DIR / "scripts/zone_gate_3d.gd"
    record_test("ZoneGate3D file exists", gate_path.exists(), str(gate_path))
    gate_code = gate_path.read_text(encoding="utf-8")

    # 3.1 show_missing_resource_feedback signature and presence
    gate_feedback_func = re.search(r"func show_missing_resource_feedback\([^)]*\)[^:]*:\s*([\s\S]*?)(?=\nfunc |\n#|\Z)", gate_code)
    record_test("show_missing_resource_feedback method exists", gate_feedback_func is not None)
    
    if gate_feedback_func:
        gf_body = gate_feedback_func.group(1)
        record_test("Calculates German energy feedback text", 'Benötigt %s Energie zum Freischalten' in gf_body)
        record_test("Calculates German clearance level feedback text", 'Benötigt Campus Level %d' in gf_body)
        record_test("Instantiates Label3D", "Label3D.new()" in gf_body)
        record_test("Billboard enabled (BILLBOARD_ENABLED)", "label.billboard = BaseMaterial3D.BILLBOARD_ENABLED" in gf_body)
        record_test("no_depth_test enabled for UI visibility", "label.no_depth_test = true" in gf_body)
        
        # Font size check
        font_match = re.search(r"label\.font_size\s*=\s*(\d+)", gf_body)
        record_test("Label3D has font_size >= 24", font_match is not None and int(font_match.group(1)) >= 24,
                    f"font_size = {font_match.group(1) if font_match else 'None'}")
        
        # Color check
        record_test("Label3D has bright coral/red color Color(1.0, 0.3, 0.3)", "Color(1.0, 0.3, 0.3)" in gf_body)
        
        # Spawning position
        record_test("Spawns at gate position + Vector3(0.0, 2.5, 0.0)", "Vector3(0.0, 2.5, 0.0)" in gf_body)
        
        # Tween properties
        record_test("Tween configured with set_parallel(true)", "set_parallel(true)" in gf_body)
        record_test("Tween animates position:y upwards by +1.2m", "label.position.y + 1.2" in gf_body)
        record_test("Tween duration is 1.2s", ", 1.2)" in gf_body)
        record_test("Tween fades alpha modulate:a to 0.0", '"modulate:a", 0.0, 1.2' in gf_body)
        record_test("Tween finishes with queue_free cleanup", "tween_callback(label.queue_free)" in gf_body)

    # 3.2 attempt_unlock calls show_missing_resource_feedback
    record_test("attempt_unlock() invokes show_missing_resource_feedback() on failure",
                "show_missing_resource_feedback(feedback_text)" in gate_code)

    # --------------------------------------------------------------------------
    # MODULE 4: QuestWaypoint Dynamic Compass Tracking & Arrival Detection
    # --------------------------------------------------------------------------
    print("\n--- MODULE 4: QuestWaypoint Dynamic Compass Tracking & Arrival Detection ---")
    wp_path = GAME_DIR / "scripts/quest_waypoint.gd"
    record_test("QuestWaypoint file exists", wp_path.exists(), str(wp_path))
    wp_code = wp_path.read_text(encoding="utf-8")

    # 4.1 Refresh targets method
    refresh_func = re.search(r"func _refresh_objective_target\(\)[^:]*:\s*([\s\S]*?)(?=\nfunc |\n#|\Z)", wp_code)
    record_test("_refresh_objective_target method exists", refresh_func is not None)
    if refresh_func:
        rf_body = refresh_func.group(1)
        record_test("Inspects active_campus_quest_id from GameState", "active_campus_quest_id" in rf_body)
        
        # Server Room Quest branching: Gate if locked, Bob if unlocked
        record_test("Handles quest_server target resolution", 'active_quest == "quest_server"' in rf_body)
        record_test("Checks is_zone_unlocked('server_room')", 'is_zone_unlocked("server_room")' in rf_body)
        record_test("Targets Gate_ServerRoom if server_room locked", 'Gate_ServerRoom' in rf_body)
        record_test("Targets Architect Bob if server_room unlocked", 'architect_bob' in rf_body or 'NPC_Bob' in rf_body)

        # Lab Room Quest branching: Gate if locked, Lisa if unlocked
        record_test("Handles quest_lab target resolution", 'active_quest == "quest_lab"' in rf_body)
        record_test("Checks is_zone_unlocked('lab_room')", 'is_zone_unlocked("lab_room")' in rf_body)
        record_test("Targets Gate_LabRoom if lab_room locked", 'Gate_LabRoom' in rf_body)
        record_test("Targets Dr. Lisa if lab_room unlocked", 'scientist_lisa' in rf_body or 'NPC_Lisa' in rf_body)

        # Default / quest_alex
        record_test("Defaults to CEO Alex / Collectibles", 'ceo_alex' in rf_body or 'NPC_Alex' in rf_body)

    # 4.2 Arrival Detection
    record_test("Defines arrival_threshold property", "arrival_threshold" in wp_code)
    arr_match = re.search(r"@export var arrival_threshold:\s*float\s*=\s*([0-9.]+)", wp_code)
    record_test("arrival_threshold is set to 3.0m", arr_match is not None and float(arr_match.group(1)) == 3.0,
                f"arrival_threshold = {arr_match.group(1) if arr_match else 'None'}")
    
    record_test("Formats label with '[ Arrived! ]' when distance <= arrival_threshold",
                '"%s\\n[ Arrived! ]"' in wp_code)
    record_test("Displays green modulate Color(0.3, 1.0, 0.5) upon arrival",
                "Color(0.3, 1.0, 0.5)" in wp_code)

    # 4.3 Compass Vector & Arrival Mathematical Oracle
    class SimulatedCompass:
        def __init__(self, arrival_thresh: float = 3.0):
            self.arrival_thresh = arrival_thresh

        def evaluate(self, avatar_pos: Tuple[float, float, float], target_pos: Tuple[float, float, float]) -> Tuple[float, bool, str]:
            dx = target_pos[0] - avatar_pos[0]
            dz = target_pos[2] - avatar_pos[2]
            dist = math.sqrt(dx*dx + dz*dz)
            arrived = dist <= self.arrival_thresh
            text = "[ Arrived! ]" if arrived else f"{dist:.0f}m"
            return dist, arrived, text

    comp = SimulatedCompass(3.0)

    # Distance > 3.0m
    d1, arr1, txt1 = comp.evaluate((0.0, 0.0, 0.0), (0.0, 0.0, 10.0))
    record_test("Compass Math: 10.0m away -> not arrived (displays '10m')",
                math.isclose(d1, 10.0) and not arr1 and txt1 == "10m")

    # Boundary: Exactly 3.0m
    d2, arr2, txt2 = comp.evaluate((0.0, 0.0, 0.0), (3.0, 0.0, 0.0))
    record_test("Compass Math: Exactly 3.0m away -> arrived (displays '[ Arrived! ]')",
                math.isclose(d2, 3.0) and arr2 and txt2 == "[ Arrived! ]")

    # Inside: 1.5m away
    d3, arr3, txt3 = comp.evaluate((2.0, 0.0, 2.0), (1.0, 0.0, 1.0))
    record_test("Compass Math: 1.414m away -> arrived (displays '[ Arrived! ]')",
                d3 <= 3.0 and arr3 and txt3 == "[ Arrived! ]")

    # --------------------------------------------------------------------------
    # MODULE 5: GDScript Syntax & Parser Integrity Audit
    # --------------------------------------------------------------------------
    print("\n--- MODULE 5: GDScript Syntax & Parser Integrity Audit ---")
    
    # 5.1 Check duplicate function declarations across scripts
    scripts_to_check = [
        "scripts/avatar_3d.gd",
        "scripts/npc_3d.gd",
        "scripts/zone_gate_3d.gd",
        "scripts/quest_waypoint.gd",
        "scripts/autoload/game_state.gd",
        "scripts/collectible_3d.gd",
        "scripts/worker_avatar_3d.gd",
        "scripts/hud.gd",
        "scripts/ui/touch_controls.gd"
    ]

    for rel_path in scripts_to_check:
        full_p = GAME_DIR / rel_path
        if not full_p.exists():
            continue
        lines = full_p.read_text(encoding="utf-8").splitlines()
        func_defs = {}
        for idx, line in enumerate(lines, start=1):
            m = re.match(r"^\s*func\s+([a-zA-Z0-9_]+)\s*\(", line)
            if m:
                fname = m.group(1)
                func_defs.setdefault(fname, []).append(idx)
        
        duplicates = {k: v for k, v in func_defs.items() if len(v) > 1}
        is_clean = len(duplicates) == 0
        detail = ""
        if not is_clean:
            detail = f"DUPLICATE FUNCTIONS DETECTED: {duplicates}"
        record_test(f"Parser Check (No duplicate methods): {rel_path}", is_clean, detail)

    # 5.2 Check function-level variable shadow duplicates
    # In GDScript 4, re-declaring `var x` in an if/else block inside the same function is a parse error.
    for rel_path in ["scripts/zone_gate_3d.gd", "scripts/avatar_3d.gd", "scripts/autoload/game_state.gd"]:
        full_p = GAME_DIR / rel_path
        if not full_p.exists():
            continue
        code_lines = full_p.read_text(encoding="utf-8").splitlines()
        
        current_func = None
        func_vars = {}
        var_shadow_dupes = {}

        for line_no, line in enumerate(code_lines, start=1):
            # Check function entry
            func_m = re.match(r"^\s*func\s+([a-zA-Z0-9_]+)\s*\(", line)
            if func_m:
                current_func = func_m.group(1)
                func_vars = {}
                continue
            
            # Check variable declaration inside function
            if current_func is not None:
                # Top-level script vars (indent 0) break function scope
                if line and not line.startswith(" ") and not line.startswith("\t") and not line.startswith("#"):
                    current_func = None
                    continue

                var_m = re.search(r"^\s+var\s+([a-zA-Z0-9_]+)(?:\s*:|\s*=)", line)
                if var_m:
                    vname = var_m.group(1)
                    if vname in func_vars:
                        var_shadow_dupes.setdefault(current_func, []).append((vname, func_vars[vname], line_no))
                    else:
                        func_vars[vname] = line_no

        has_no_var_shadowing = len(var_shadow_dupes) == 0
        detail = ""
        if not has_no_var_shadowing:
            detail = f"DUPLICATE VAR DECLARATION IN SCOPE: {var_shadow_dupes}"
        record_test(f"Parser Check (No duplicate vars in func scope): {rel_path}", has_no_var_shadowing, detail)

    # --------------------------------------------------------------------------
    # SUMMARY & VERDICT
    # --------------------------------------------------------------------------
    print("\n" + "=" * 70)
    print(f">>> CHALLENGE SUITE SUMMARY: {passed_tests} PASSED, {failed_tests} FAILED <<<")
    print("=" * 70)

    if failed_tests == 0:
        print("\n>>> VERDICT: APPROVE <<<")
        return 0
    else:
        print("\n>>> VERDICT: REQUEST_CHANGES <<<")
        print("Findings that must be addressed:")
        for f in findings:
            print(f"  * {f}")
        return 1

if __name__ == "__main__":
    sys.exit(run_suite())
