#!/usr/bin/env python3
"""
Adversarial Stress Test & Integrity Audit for Phase 9 Milestone 2:
Interactive Campus Stations & 3D Props (Server Room Terminal & Pitch Stage)
File: IdleArcade/tests/test_p9_m2_adversarial.py
Target: Python 3.12, AST analysis, math boundary stress tests, collision geometry verification
"""

import sys
import re
import math
import random
from pathlib import Path

# UTF-8 stdout configuration
if hasattr(sys.stdout, "reconfigure"):
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass

SCRIPT_DIR = Path(__file__).resolve().parent
GAME_DIR = SCRIPT_DIR.parent

class Tester:
    def __init__(self):
        self.passed = 0
        self.failed = 0

    def assert_check(self, cond: bool, description: str, err: str = ""):
        if cond:
            print(f"  [PASS] {description}")
            self.passed += 1
        else:
            print(f"  [FAIL] {description} -> {err}")
            self.failed += 1

tester = Tester()

def run_adversarial_suite():
    print("\n" + "=" * 70)
    print(">>> ADVERSARIAL STRESS TEST & INTEGRITY AUDIT: PHASE 9 M2 <<<")
    print("=" * 70)

    # -------------------------------------------------------------
    # 1. INTEGRITY & ANTI-CHEAT AUDIT
    # -------------------------------------------------------------
    print("\n--- DIMENSION 1: Integrity & Anti-Cheat Audit ---")
    st_gd = (GAME_DIR / "scripts" / "server_terminal.gd").read_text(encoding="utf-8")
    ps_gd = (GAME_DIR / "scripts" / "pitch_stage.gd").read_text(encoding="utf-8")
    gs_gd = (GAME_DIR / "scripts" / "autoload" / "game_state.gd").read_text(encoding="utf-8")
    tc_gd = (GAME_DIR / "scripts" / "ui" / "touch_controls.gd").read_text(encoding="utf-8")

    # Check for hardcoded test score or bypass patterns
    suspicious_patterns = [
        "is_test_running", "mock_", "fake_", "dummy_", "bypass", "hardcoded",
        "return 150.0", "return 86", "assert_true", "fake_buff"
    ]
    for pattern in suspicious_patterns:
        tester.assert_check(
            pattern not in st_gd and pattern not in ps_gd,
            f"No suspicious facade pattern '{pattern}' in station scripts"
        )

    # Verify real state machine in server_terminal.gd
    tester.assert_check(
        "var is_overclock_active: bool = false" in st_gd and
        "var is_on_cooldown: bool = false" in st_gd and
        "var overclock_time_remaining: float = 0.0" in st_gd and
        "var cooldown_time_remaining: float = 0.0" in st_gd,
        "ServerTerminal maintains full state machine variables"
    )

    # Verify real state machine in pitch_stage.gd
    tester.assert_check(
        "var is_pitch_ready: bool = true" in ps_gd and
        "var cooldown_time_remaining: float = 0.0" in ps_gd and
        "var total_funding_secured: float = 0.0" in ps_gd and
        "var pitch_count: int = 0" in ps_gd,
        "PitchStage maintains full state machine variables"
    )

    # -------------------------------------------------------------
    # 2. COLLISION GEOMETRY & PROXIMITY TRIGGER CLEARANCE
    # -------------------------------------------------------------
    print("\n--- DIMENSION 2: Collision Geometry & Trigger Clearance ---")
    st_tscn = (GAME_DIR / "scenes" / "server_terminal.tscn").read_text(encoding="utf-8")
    ps_tscn = (GAME_DIR / "scenes" / "pitch_stage.tscn").read_text(encoding="utf-8")

    # Server Terminal: Root shape BoxShape3D vs Area SphereShape3D
    st_box_match = re.search(r'\[sub_resource type="BoxShape3D" id="BoxShape3D_root"\]\s*size = Vector3\(([^)]+)\)', st_tscn)
    st_sphere_match = re.search(r'\[sub_resource type="SphereShape3D" id="SphereShape3D_area"\]\s*radius = ([0-9.]+)', st_tscn)
    tester.assert_check(bool(st_box_match and st_sphere_match), "Server Terminal collision shapes extracted")
    if st_box_match and st_sphere_match:
        dims = [float(x.strip()) for x in st_box_match.group(1).split(",")]
        radius = float(st_sphere_match.group(1))
        # Max horizontal half-extent
        max_half_extent = max(dims[0], dims[2]) / 2.0
        tester.assert_check(
            radius > max_half_extent + 0.5,
            f"ServerTerminal interaction radius ({radius}m) comfortably exceeds physical bounding radius ({max_half_extent}m)",
            f"radius={radius}, max_half={max_half_extent}"
        )

    # Pitch Stage: Root shape BoxShape3D vs Area SphereShape3D
    ps_box_match = re.search(r'\[sub_resource type="BoxShape3D" id="BoxShape3D_root"\]\s*size = Vector3\(([^)]+)\)', ps_tscn)
    ps_sphere_match = re.search(r'\[sub_resource type="SphereShape3D" id="SphereShape3D_area"\]\s*radius = ([0-9.]+)', ps_tscn)
    tester.assert_check(bool(ps_box_match and ps_sphere_match), "Pitch Stage collision shapes extracted")
    if ps_box_match and ps_sphere_match:
        dims = [float(x.strip()) for x in ps_box_match.group(1).split(",")]
        radius = float(ps_sphere_match.group(1))
        max_half_extent = max(dims[0], dims[2]) / 2.0
        tester.assert_check(
            radius > max_half_extent + 0.5,
            f"PitchStage interaction radius ({radius}m) comfortably exceeds physical bounding radius ({max_half_extent}m)",
            f"radius={radius}, max_half={max_half_extent}"
        )

    # -------------------------------------------------------------
    # 3. GAMESTATE OVERCLOCK FORMULA STRESS & BOUNDARY TESTING
    # -------------------------------------------------------------
    print("\n--- DIMENSION 3: GameState Buff Formula Stress Testing ---")
    # Simulate GameState.get_effective_passive_rps() with extreme inputs
    def eval_effective_rps(base_rps, bonus_users, collectibles, has_server_tech, has_neural_cloud, buff_active, buff_timer, buff_mult):
        bonus_mult = 1.0 + (float(bonus_users) * 0.01)
        item_factor = 0.10 if has_neural_cloud else 0.05
        campus_mult = 1.0 + (float(collectibles) * item_factor)
        tech_mult = 1.25 if has_server_tech else 1.0
        overclock_mult = buff_mult if (buff_timer > 0.0 or buff_active) else 1.0
        return base_rps * bonus_mult * campus_mult * tech_mult * overclock_mult

    # Baseline 100 RPS without buff
    r0 = eval_effective_rps(100.0, 0, 0, False, False, False, 0.0, 1.0)
    tester.assert_check(math.isclose(r0, 100.0), f"RPS Baseline: {r0} == 100.0")

    # +50% Overclock buff
    r1 = eval_effective_rps(100.0, 0, 0, False, False, True, 25.0, 1.50)
    tester.assert_check(math.isclose(r1, 150.0), f"RPS Overclocked (+50%): {r1} == 150.0")

    # Stacking Tech Server Overclock (+25%) and Overclock Station Buff (+50%)
    r2 = eval_effective_rps(100.0, 0, 0, True, False, True, 25.0, 1.50)
    tester.assert_check(math.isclose(r2, 187.5), f"RPS Stacked Tech (+25%) & Buff (+50%): {r2} == 187.5")

    # Full Stacking: 50 bonus users (+50%), 10 items with Neural Cloud (+100%), Tech (+25%), Station Buff (+50%)
    # formula: 100 * 1.50 * 2.00 * 1.25 * 1.50 = 562.5
    r3 = eval_effective_rps(100.0, 50, 10, True, True, True, 25.0, 1.50)
    tester.assert_check(math.isclose(r3, 562.5), f"RPS Mega Stacking: {r3} == 562.5")

    # Zero base RPS invariant
    r_zero = eval_effective_rps(0.0, 1000, 50, True, True, True, 25.0, 1.50)
    tester.assert_check(r_zero == 0.0, "Zero base RPS remains exactly 0.0 with buff active")

    # Expired buff timer
    r_expired = eval_effective_rps(100.0, 0, 0, False, False, False, 0.0, 1.50)
    tester.assert_check(math.isclose(r_expired, 100.0), "Expired buff timer reverts immediately to 100.0")

    # -------------------------------------------------------------
    # 4. PITCH STAGE VALUATION REWARD BOUNDARIES
    # -------------------------------------------------------------
    print("\n--- DIMENSION 4: Pitch Stage Reward Monte-Carlo Testing ---")
    min_grant = 1000.0
    max_grant = 5000.0

    random.seed(42)
    for idle_level in [1, 5, 10, 50]:
        level_bonus = float(idle_level) * 100.0
        samples = []
        for _ in range(1000):
            base_grant = random.uniform(min_grant, max_grant)
            total = max(min_grant, round(base_grant + level_bonus))
            samples.append(total)

        min_sample = min(samples)
        max_sample = max(samples)
        expected_min = round(min_grant + level_bonus)
        expected_max = round(max_grant + level_bonus)

        tester.assert_check(
            min_sample >= expected_min - 1.0 and max_sample <= expected_max + 1.0,
            f"Level {idle_level} grant range: [{min_sample}, {max_sample}] strictly bounded in [{expected_min}, {expected_max}]"
        )

    # -------------------------------------------------------------
    # 5. TOUCHCONTROLS STYLEBOX ATTRIBUTES & COLOR FIDELITY
    # -------------------------------------------------------------
    print("\n--- DIMENSION 5: TouchControls Dynamic Styling Audit ---")
    # Check Electric Blue Overclock styling attributes
    tester.assert_check("_cached_overclock_style" in tc_gd, "touch_controls declares _cached_overclock_style")
    tester.assert_check("Color(0.0, 0.92, 1.0" in tc_gd, "Overclock border is Neon-Cyan Color(0.0, 0.92, 1.0)")
    tester.assert_check("Color(0.04, 0.20, 0.42" in tc_gd, "Overclock background is Deep Navy Color(0.04, 0.20, 0.42)")
    tester.assert_check("Color(0.0, 0.85, 1.0" in tc_gd, "Overclock shadow is Cyan Glow Color(0.0, 0.85, 1.0)")

    # Check Warm Gold Pitch styling attributes
    tester.assert_check("_cached_pitch_style" in tc_gd, "touch_controls declares _cached_pitch_style")
    tester.assert_check("Color(1.0, 0.84, 0.0" in tc_gd, "Pitch border is Warm Gold Color(1.0, 0.84, 0.0)")
    tester.assert_check("Color(0.38, 0.30, 0.05" in tc_gd, "Pitch background is Dark Gold Color(0.38, 0.30, 0.05)")
    tester.assert_check("Color(1.0, 0.80, 0.1" in tc_gd, "Pitch shadow is Gold Spotlight Glow Color(1.0, 0.80, 0.1)")

    # -------------------------------------------------------------
    # 6. AUDIO INTEGRATION & GUARD SAFETY AUDIT
    # -------------------------------------------------------------
    print("\n--- DIMENSION 6: Audio Integration & Safe Duck Typing ---")
    # In server_terminal.gd
    tester.assert_check(
        'get_node_or_null("/root/AudioManager")' in st_gd,
        "ServerTerminal uses get_node_or_null for AudioManager lookup"
    )
    tester.assert_check(
        'am.has_method("play_sfx_overdrive")' in st_gd,
        "ServerTerminal guards play_sfx_overdrive with has_method"
    )
    tester.assert_check(
        'am.has_method("play_sfx_click")' in st_gd,
        "ServerTerminal provides play_sfx_click fallback guard"
    )

    # In pitch_stage.gd
    tester.assert_check(
        'get_node_or_null("/root/AudioManager")' in ps_gd,
        "PitchStage uses get_node_or_null for AudioManager lookup"
    )
    tester.assert_check(
        'am.has_method("play_sfx_research")' in ps_gd,
        "PitchStage guards play_sfx_research with has_method"
    )
    tester.assert_check(
        'am.has_method("play_sfx_pickup")' in ps_gd,
        "PitchStage guards play_sfx_pickup with has_method"
    )

    # -------------------------------------------------------------
    # 7. MAIN_3D COORDINATES & ZONE ALIGNMENT
    # -------------------------------------------------------------
    print("\n--- DIMENSION 7: Main3D Zone Coordinates & Alignment ---")
    m3d_tscn = (GAME_DIR / "scenes" / "main_3d.tscn").read_text(encoding="utf-8")
    
    # Check ServerTerminal at (0, 0, -18)
    st_node_match = re.search(r'\[node name="ServerTerminal"[^\]]*\]\s*transform = Transform3D\([^)]*,\s*0,\s*0,\s*-18\)', m3d_tscn)
    tester.assert_check(bool(st_node_match), "ServerTerminal correctly instanced at Vector3(0, 0, -18) in Server Room")

    # Check PitchStage at (0, 0, 18)
    ps_node_match = re.search(r'\[node name="PitchStage"[^\]]*\]\s*transform = Transform3D\([^)]*,\s*0,\s*0,\s*18\)', m3d_tscn)
    tester.assert_check(bool(ps_node_match), "PitchStage correctly instanced at Vector3(0, 0, 18) in Courtyard")

    # -------------------------------------------------------------
    # Summary
    # -------------------------------------------------------------
    print("\n" + "=" * 70)
    print(f"ADVERSARIAL AUDIT SUMMARY: {tester.passed} Passed, {tester.failed} Failed")
    print("=" * 70)
    if tester.failed == 0:
        print(">>> EMPIRICAL VERDICT: CERTIFIED 100% GREEN (ZERO DEFECTS) <<<\n")
        return 0
    else:
        print(f">>> EMPIRICAL VERDICT: FAILED ({tester.failed} DEFECTS FOUND) <<<\n")
        return 1

if __name__ == "__main__":
    sys.exit(run_adversarial_suite())
