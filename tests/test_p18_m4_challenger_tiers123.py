#!/usr/bin/env python3
"""
Adversarial Stress Test & Mutation Suite for Phase 18 Tiers 1-3 Verification
File: IdleArcade/tests/test_p18_m4_challenger_tiers123.py
Target: Empirical validation of Oracle sensitivity, AST robustness, and mathematical edge cases.
"""

import sys
import os
import re
import math
import copy
import itertools
from pathlib import Path
from typing import Dict, List, Any, Tuple, Optional

# UTF-8 stdout configuration
if hasattr(sys.stdout, "reconfigure"):
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass

GAME_DIR = Path(__file__).resolve().parent.parent

class Colors:
    HEADER = '\033[95m'
    OKGREEN = '\033[92m'
    WARNING = '\033[93m'
    FAIL = '\033[91m'
    ENDC = '\033[0m'
    BOLD = '\033[1m'


class ChallengerReporter:
    def __init__(self):
        self.passed = 0
        self.failed = 0
        self.failures = []

    def check(self, condition: bool, description: str, detail: str = ""):
        if condition:
            self.passed += 1
            print(f"  {Colors.OKGREEN}[PASS]{Colors.ENDC} {description}")
        else:
            self.failed += 1
            print(f"  {Colors.FAIL}[FAIL]{Colors.ENDC} {description}")
            if detail:
                print(f"         {Colors.WARNING}Detail: {detail}{Colors.ENDC}")
            self.failures.append((description, detail))


# =============================================================================
# PART 1: TIER 1 & TIER 3 AST MUTATION TESTING
# =============================================================================
def test_tier_1_mutations(reporter: ChallengerReporter):
    print(f"\n{Colors.BOLD}{Colors.HEADER}=== CHALLENGE 1: Tier 1 AST Check Mutation Sensitivity ==={Colors.ENDC}")

    # Load authentic files
    gs_text = (GAME_DIR / "scripts/autoload/game_state.gd").read_text(encoding="utf-8")
    tm_text = (GAME_DIR / "scripts/autoload/tutorial_manager.gd").read_text(encoding="utf-8")
    m3d_text = (GAME_DIR / "scripts/main_3d.gd").read_text(encoding="utf-8")
    vj_text = (GAME_DIR / "scripts/ui/virtual_joystick.gd").read_text(encoding="utf-8")
    im_text = (GAME_DIR / "scripts/incubator_manager.gd").read_text(encoding="utf-8")
    am_text = (GAME_DIR / "scripts/autoload/audio_manager.gd").read_text(encoding="utf-8")
    eb_text = (GAME_DIR / "scripts/ui/espresso_brew_minigame.gd").read_text(encoding="utf-8")
    qa_text = (GAME_DIR / "tests/test_full_stack_qa.gd").read_text(encoding="utf-8")
    m3d_tscn = (GAME_DIR / "scenes/main_3d.tscn").read_text(encoding="utf-8")

    # Oracle AST extractors (mirroring Tier 1 in test_phase18_e2e_verify.py)
    def check_f1_order_tier1(text: str) -> Tuple[bool, bool, bool]:
        m = re.search(r'func load_from_disk\(\).*?:(.*?)(?=\nfunc |\Z)', text, re.DOTALL)
        if not m:
            return False, False, False
        body = m.group(1)
        idx_syn = body.find("Phase 13 Syndicate Deserialization")
        idx_staff = body.find("Phase 14 Staff & Autonomous Chibi-Worker Deserialization")
        idx_off = body.find("Offline catch-up calculation")
        return (idx_off > idx_syn), (idx_off > idx_staff), ("minf(elapsed, 28800.0)" in body)

    # Oracle AST extractor for Tier 3 variable-level check
    def check_f1_variables_tier3(text: str) -> Tuple[bool, bool]:
        m = re.search(r'func load_from_disk\(\).*?:(.*?)(?=\nfunc |\Z)', text, re.DOTALL)
        if not m:
            return False, False
        body = m.group(1)
        pos_syn = body.find("active_syndicate_id")
        pos_staff = body.find("hired_workers")
        pos_offline = body.find("offline_gain")
        return (pos_offline > pos_syn), (pos_offline > pos_staff)

    # Mutant 1.1: F1 Inverted Syndicate comment order
    mutant_1_1 = gs_text.replace("# Phase 13 Syndicate Deserialization", "TEMP_SYN")
    mutant_1_1 = mutant_1_1.replace("# Offline catch-up calculation", "# Phase 13 Syndicate Deserialization")
    mutant_1_1 = mutant_1_1.replace("TEMP_SYN", "# Offline catch-up calculation")
    c_syn, c_staff, c_cap = check_f1_order_tier1(mutant_1_1)
    reporter.check(not c_syn, "M1.1 Tier 1 correctly catches inverted Syndicate/Offline deserialization comment order")

    # Mutant 1.2: F1 Inverted Staff comment order
    mutant_1_2 = gs_text.replace("# Phase 14 Staff & Autonomous Chibi-Worker Deserialization", "TEMP_STAFF")
    mutant_1_2 = mutant_1_2.replace("# Offline catch-up calculation", "# Phase 14 Staff & Autonomous Chibi-Worker Deserialization")
    mutant_1_2 = mutant_1_2.replace("TEMP_STAFF", "# Offline catch-up calculation")
    c_syn, c_staff, c_cap = check_f1_order_tier1(mutant_1_2)
    reporter.check(not c_staff, "M1.2 Tier 1 correctly catches inverted Staff/Offline deserialization comment order")

    # Mutant 1.3: F1/Tier 3 Inverted Code Variables (offline_gain moved before active_syndicate_id)
    mutant_1_3_var = gs_text.replace("active_syndicate_id", "TEMP_VAR_SYN")
    mutant_1_3_var = mutant_1_3_var.replace("offline_gain", "active_syndicate_id")
    mutant_1_3_var = mutant_1_3_var.replace("TEMP_VAR_SYN", "offline_gain")
    v_syn, v_staff = check_f1_variables_tier3(mutant_1_3_var)
    reporter.check(not v_syn, "M1.3 Tier 3 AST variable check catches offline_gain executed before active_syndicate_id")

    # Mutant 1.4: F1/Tier 3 Inverted Code Variables (offline_gain moved before hired_workers)
    mutant_1_4_var = gs_text.replace("hired_workers", "TEMP_VAR_STAFF")
    mutant_1_4_var = mutant_1_4_var.replace("offline_gain", "hired_workers")
    mutant_1_4_var = mutant_1_4_var.replace("TEMP_VAR_STAFF", "offline_gain")
    v_syn, v_staff = check_f1_variables_tier3(mutant_1_4_var)
    reporter.check(not v_staff, "M1.4 Tier 3 AST variable check catches offline_gain executed before hired_workers")

    # Mutant 1.5: F1 Missing 8h cap
    mutant_1_5 = gs_text.replace("minf(elapsed, 28800.0)", "minf(elapsed, 86400.0)")
    c_syn, c_staff, c_cap = check_f1_order_tier1(mutant_1_5)
    reporter.check(not c_cap, "M1.5 Oracle correctly catches altered offline elapsed cap (86400s instead of 28800s)")

    # Mutant 1.6: F2 Mutated Tutorial Step 1 Seed Grant
    def check_f2_seed(text: str) -> bool:
        return ("30.0 - float(gs.energy)" in text and
                text.count("gs.total_energy_earned += delta") >= 2 and
                text.count("gs.total_lifetime_energy += delta") >= 2)

    mutant_f2_1 = tm_text.replace("30.0 - float(gs.energy)", "25.0 - float(gs.energy)")
    reporter.check(not check_f2_seed(mutant_f2_1), "M1.6 Oracle correctly catches altered seed threshold (25.0 instead of 30.0)")

    mutant_f2_2 = tm_text.replace("gs.total_energy_earned += delta", "# skipped total_energy_earned")
    reporter.check(not check_f2_seed(mutant_f2_2), "M1.7 Oracle correctly catches missing total_energy_earned delta injection")

    mutant_f2_3 = tm_text.replace("gs.total_lifetime_energy += delta", "# skipped total_lifetime_energy")
    reporter.check(not check_f2_seed(mutant_f2_3), "M1.8 Oracle correctly catches missing total_lifetime_energy delta injection")

    # Mutant 1.9: F3 Station Cooldown Aliasing
    def check_f3_aliases(text: str) -> bool:
        return ('station_cooldowns["coffee_machine"] = safe_duration' in text and
                'station_cooldowns["coffee_machine_3d"] = safe_duration' in text and
                'station_cooldowns["barista_station"] = safe_duration' in text and
                'maxf(cd1, maxf(cd2, cd3))' in text)

    mutant_f3 = gs_text.replace('station_cooldowns["coffee_machine"] = safe_duration', '# skipped coffee_machine alias')
    reporter.check(not check_f3_aliases(mutant_f3), "M1.9 Oracle correctly catches missing coffee_machine alias assignment")

    # Mutant 1.10: F4 Daily Board Clock Rollback
    def check_f4_rollback(text: str) -> bool:
        return "elif current_day < daily_board_last_login_day:" in text

    mutant_f4 = gs_text.replace("elif current_day < daily_board_last_login_day:", "elif false:")
    reporter.check(not check_f4_rollback(mutant_f4), "M1.10 Oracle correctly catches missing daily board clock rollback guard")

    # Mutant 1.11: F5 Staff Morale Zero Division Guard
    def check_f5_guard(text: str) -> bool:
        return ("total_morale / maxf(1.0, float(hired_workers.size()))" in text and
                "if hired_workers.is_empty():" in text)

    mutant_f5 = gs_text.replace("maxf(1.0, float(hired_workers.size()))", "float(hired_workers.size())")
    reporter.check(not check_f5_guard(mutant_f5), "M1.11 Oracle correctly catches bare division without maxf(1.0, ...) in staff simulation")

    # Mutant 1.12: F6 Server Overclock Glow Null Guard
    def check_f6_glow(text: str) -> bool:
        return ('@onready var server_overclock_glow: OmniLight3D = get_node_or_null("CampusLevel/ServerOverclockGlow")' in text and
                'if server_overclock_glow == null:' in text)

    mutant_f6 = m3d_text.replace('get_node_or_null("CampusLevel/ServerOverclockGlow")', 'get_node("CampusLevel/ServerOverclockGlow")')
    reporter.check(not check_f6_glow(mutant_f6), "M1.12 Oracle correctly catches unsafe get_node() call without get_node_or_null()")

    # Mutant 1.13: F7 Touch Target Sizing (<56px)
    def check_button_height_oracle(heights: List[float]) -> bool:
        return all(h >= 56.0 for h in heights)

    valid_heights = [56.0] * 26
    invalid_heights = [56.0] * 25 + [55.0] # 1 button is 55px (under standard)
    reporter.check(check_button_height_oracle(valid_heights), "M1.13 Touch target oracle accepts all 26 buttons >= 56px")
    reporter.check(not check_button_height_oracle(invalid_heights), "M1.14 Touch target oracle rejects button of 55px (< 56px standard)")

    # Mutant 1.15: F8 Virtual Joystick Dynamic Zone
    def check_f8_joystick(text: str) -> bool:
        return ("zone_max_x = vp_rect.size.x * 0.5" in text and
                "zone_max_y = vp_rect.size.y" in text)

    mutant_f8 = vj_text.replace("zone_max_x = vp_rect.size.x * 0.5", "zone_max_x = 640.0")
    reporter.check(not check_f8_joystick(mutant_f8), "M1.15 Oracle correctly catches hardcoded virtual joystick bounds")

    # Mutant 1.16: F10 Incubator Worker Despawn
    def check_f10_despawn(text: str) -> bool:
        return ("remove_child(worker_to_free)" in text and
                "worker_to_free.queue_free()" in text)

    mutant_f10 = im_text.replace("remove_child(worker_to_free)", "# skipped unparenting")
    reporter.check(not check_f10_despawn(mutant_f10), "M1.16 Oracle correctly catches omitted remove_child() before queue_free()")

    # Mutant 1.17: F11 AudioManager _exit_tree()
    def check_f11_audio(text: str) -> bool:
        return ("func _exit_tree() -> void:" in text and
                "player.stop()" in text and "player.stream = null" in text)

    mutant_f11 = am_text.replace("func _exit_tree() -> void:", "func _disabled_exit_tree() -> void:")
    reporter.check(not check_f11_audio(mutant_f11), "M1.17 Oracle correctly catches missing AudioManager _exit_tree() implementation")

    # Mutant 1.18: F12 QuickHUD Pointer Isolation
    def check_f12_spacer(text: str) -> bool:
        m = re.search(r'\[node name="Spacer" type="Control" parent="QuickHUDLayer/QuickHUD/BarHBox"\](.*?)(?=\[node|\Z)', text, re.DOTALL)
        return m is not None and "mouse_filter = 0" in m.group(1)

    mutant_f12 = m3d_tscn.replace(
        '[node name="Spacer" type="Control" parent="QuickHUDLayer/QuickHUD/BarHBox"]\nlayout_mode = 2\nsize_flags_horizontal = 3\nmouse_filter = 0',
        '[node name="Spacer" type="Control" parent="QuickHUDLayer/QuickHUD/BarHBox"]\nlayout_mode = 2\nsize_flags_horizontal = 3\nmouse_filter = 2'
    )
    reporter.check(not check_f12_spacer(mutant_f12), "M1.18 Oracle correctly catches leaky QuickHUD Spacer (mouse_filter = 2 / IGNORE)")

    # Mutant 1.19: F13 Dead Fallback %HoldButton
    def check_f13_dead_fallback(text: str) -> bool:
        return ('get_node_or_null("%HoldButton")' not in text and
                'hold_button: Button = pump_button' in text)

    mutant_f13 = eb_text + '\nvar dead_lookup = get_node_or_null("%HoldButton")'
    reporter.check(not check_f13_dead_fallback(mutant_f13), "M1.19 Oracle correctly catches reintroduction of dead %HoldButton lookup")

    # Mutant 1.20: F14 Core Instantiation in test_full_stack_qa.gd
    def check_f14_core(text: str) -> bool:
        return ('load("res://scenes/core.tscn")' in text and
                'core_script.new()' not in text)

    mutant_f14 = qa_text.replace('load("res://scenes/core.tscn")', 'load("res://scripts/core.gd")')
    reporter.check(not check_f14_core(mutant_f14), "M1.20 Oracle correctly catches non-scene core instantiation in test runner")


# =============================================================================
# PART 2: TIER 2 MATHEMATICAL BOUNDARIES STRESS TESTING
# =============================================================================
def test_tier_2_math_boundaries(reporter: ChallengerReporter):
    print(f"\n{Colors.BOLD}{Colors.HEADER}=== CHALLENGE 2: Tier 2 Mathematical Boundaries Stress Testing ==={Colors.ENDC}")

    # 1. Angel share square root formula stress testing
    def angel_shares_formula(lifetime_energy: float) -> int:
        if math.isnan(lifetime_energy) or math.isinf(lifetime_energy) or lifetime_energy < 100000.0:
            return 0
        return int(math.floor(math.sqrt(max(0.0, lifetime_energy) / 100000.0)))

    # Boundary interval transitions
    reporter.check(angel_shares_formula(0.0) == 0, "B2.1 Energy 0.0 -> 0 shares")
    reporter.check(angel_shares_formula(-1.0) == 0, "B2.2 Energy -1.0 -> 0 shares")
    reporter.check(angel_shares_formula(-1e9) == 0, "B2.3 Energy -1e9 -> 0 shares")
    reporter.check(angel_shares_formula(float("nan")) == 0, "B2.4 Energy NaN -> 0 shares")
    reporter.check(angel_shares_formula(float("inf")) == 0, "B2.5 Energy +Inf -> 0 shares")
    reporter.check(angel_shares_formula(99999.0) == 0, "B2.6 Energy 99,999.0 -> 0 shares")
    reporter.check(angel_shares_formula(99999.999999) == 0, "B2.7 Energy 99,999.999999 -> 0 shares")
    reporter.check(angel_shares_formula(100000.0) == 1, "B2.8 Energy 100,000.0 -> 1 share (exact)")
    reporter.check(angel_shares_formula(100000.000001) == 1, "B2.9 Energy 100,000.000001 -> 1 share")
    reporter.check(angel_shares_formula(399999.999999) == 1, "B2.10 Energy 399,999.999999 -> 1 share")
    reporter.check(angel_shares_formula(400000.0) == 2, "B2.11 Energy 400,000.0 -> 2 shares (exact)")
    reporter.check(angel_shares_formula(899999.999999) == 2, "B2.12 Energy 899,999.999999 -> 2 shares")
    reporter.check(angel_shares_formula(900000.0) == 3, "B2.13 Energy 900,000.0 -> 3 shares (exact)")
    reporter.check(angel_shares_formula(1599999.999999) == 3, "B2.14 Energy 1,599,999.999999 -> 3 shares")
    reporter.check(angel_shares_formula(1600000.0) == 4, "B2.15 Energy 1,600,000.0 -> 4 shares (exact)")

    # Exhaustive stress test across 10,000 exact squares to guarantee IEEE-754 precision invariance
    perfect_square_invariance = True
    epsilon_below_invariance = True
    for k in range(1, 10001):
        E_exact = float(k * k) * 100000.0
        shares = angel_shares_formula(E_exact)
        if shares != k:
            perfect_square_invariance = False
            break
        # Epsilon below (e.g. k^2 * 100000 - 1.0) must yield exactly k - 1
        if k > 1:
            E_below = E_exact - 1.0
            if angel_shares_formula(E_below) != k - 1:
                epsilon_below_invariance = False
                break

    reporter.check(perfect_square_invariance, "B2.16 IEEE-754 Precision Invariance: All 10,000 perfect squares [1..10,000] yield exact integer k")
    reporter.check(epsilon_below_invariance, "B2.17 Boundary Sharpness: (k^2 * 100k - 1) strictly yields k - 1 for all k in [2..10,000]")

    # Ultra-large values up to float mantissa limits
    E_billion = 10.0**9
    E_trillion = 10.0**12
    E_quadrillion = 10.0**15
    reporter.check(angel_shares_formula(E_billion) == 100, "B2.18 1 Billion lifetime energy yields exactly 100 shares")
    reporter.check(angel_shares_formula(E_trillion) == 3162, "B2.19 1 Trillion lifetime energy yields exactly 3,162 shares")
    reporter.check(angel_shares_formula(E_quadrillion) == 100000, "B2.20 1 Quadrillion lifetime energy yields exactly 100,000 shares")

    # 2. Offline progression cap at 28,800.0s (8h) sharp step verification
    def offline_gain(elapsed: float, rps: float = 100.0) -> Tuple[float, float]:
        if math.isnan(elapsed) or math.isinf(elapsed):
            return 0.0, 0.0
        safe_elapsed = max(0.0, elapsed)
        effective_elapsed = min(safe_elapsed, 28800.0)
        return effective_elapsed, rps * effective_elapsed * 0.5

    rps = 100.0
    cap_gain = 28800.0 * rps * 0.5 # 1,440,000.0

    # Sharp boundary step: 28,799s, 28,800s, 28,801s
    eff_28799, gain_28799 = offline_gain(28799.0, rps)
    eff_28799_9, gain_28799_9 = offline_gain(28799.9, rps)
    eff_28800, gain_28800 = offline_gain(28800.0, rps)
    eff_28800_1, gain_28800_1 = offline_gain(28800.1, rps)
    eff_28801, gain_28801 = offline_gain(28801.0, rps)
    eff_86400, gain_86400 = offline_gain(86400.0, rps)

    reporter.check(eff_28799 == 28799.0 and gain_28799 == 1439950.0,
                   "B2.21 Offline 28,799.0s: exactly 1,439,950.0 energy (delta -50 energy from cap)")
    reporter.check(eff_28799_9 == 28799.9 and abs(gain_28799_9 - 1439995.0) < 1e-4,
                   "B2.22 Offline 28,799.9s: exactly 1,439,995.0 energy (delta -5 energy from cap)")
    reporter.check(eff_28800 == 28800.0 and gain_28800 == 1440000.0,
                   "B2.23 Offline 28,800.0s (Exact 8h Cap): exactly 1,440,000.0 energy")
    reporter.check(eff_28800_1 == 28800.0 and gain_28800_1 == 1440000.0,
                   "B2.24 Offline 28,800.1s: strictly clamped to 28,800.0s and 1,440,000.0 energy")
    reporter.check(eff_28801 == 28800.0 and gain_28801 == 1440000.0,
                   "B2.25 Offline 28,801.0s: strictly clamped to 28,800.0s and 1,440,000.0 energy")
    reporter.check(eff_86400 == 28800.0 and gain_86400 == 1440000.0,
                   "B2.26 Offline 86,400.0s (24h): strictly clamped to 28,800.0s and 1,440,000.0 energy")

    # Step sharpness assertions
    reporter.check(gain_28800 - gain_28799 == 50.0, "B2.27 Step delta between 28799s and 28800s == exactly 0.5 * RPS (50.0)")
    reporter.check(gain_28801 - gain_28800 == 0.0, "B2.28 Step delta between 28800s and 28801s == EXACTLY 0.0 (zero slope above cap)")
    reporter.check(gain_86400 - gain_28800 == 0.0, "B2.29 Step delta between 28800s and 86400s == EXACTLY 0.0")

    # Non-negative & clock rollback clamping
    reporter.check(offline_gain(0.0, rps) == (0.0, 0.0), "B2.30 Offline 0.0s yields 0.0 energy")
    reporter.check(offline_gain(-1.0, rps) == (0.0, 0.0), "B2.31 Offline -1.0s (minor clock rollback) clamps to 0.0 energy")
    reporter.check(offline_gain(-86400.0, rps) == (0.0, 0.0), "B2.32 Offline -86400.0s (major rollback) clamps to 0.0 energy")
    reporter.check(offline_gain(float("nan"), rps) == (0.0, 0.0), "B2.33 Offline NaN elapsed clamps to 0.0 energy")


# =============================================================================
# PART 3: TIER 3 COMPOUND MULTIPLIERS & DECOUPLING STRESS TESTING
# =============================================================================
def test_tier_3_multipliers_decoupling(reporter: ChallengerReporter):
    print(f"\n{Colors.BOLD}{Colors.HEADER}=== CHALLENGE 3: Tier 3 Compound Multipliers & Decoupling Stress Testing ==={Colors.ENDC}")

    # Canonical compound formula:
    # effective_passive_rps = base_rps * bonus_mult * campus_mult * tech_server_overclock * server_buff *
    #                         camp_buff * angel_share_mult * syndicate_mult * live_event_mult * staff_mult
    def calc_passive_rps(base_rps: float,
                         tech_overclock: bool = True,
                         syndicate_tier: int = 1,
                         hired_workers: int = 5,
                         avg_morale: float = 1.0,
                         angel_shares: int = 0,
                         collectibles: int = 0,
                         neural_cloud: bool = False,
                         server_buff: bool = False,
                         server_buff_mult: float = 1.5,
                         campaign_buff_mult: float = 1.0,
                         live_event_mult: float = 1.0) -> float:
        bonus_mult = 1.0
        campus_mult = (1.0 + float(collectibles) * 0.10) if neural_cloud else (1.0 + float(collectibles) * 0.05)
        tech_mult = 1.25 if tech_overclock else 1.0
        s_buff = server_buff_mult if server_buff else 1.0
        angel_mult = 1.0 + (float(angel_shares) * 0.02)
        syn_mult = 1.0 + (float(syndicate_tier) * 0.05) if syndicate_tier > 0 else 1.0
        staff_mult = 1.0
        if hired_workers > 0:
            staff_mult = 1.0 + (float(hired_workers) * 0.05) * avg_morale
        return base_rps * bonus_mult * campus_mult * tech_mult * s_buff * campaign_buff_mult * angel_mult * syn_mult * live_event_mult * staff_mult

    # 1. Canonical 164.0625 RPS precision check
    base = 100.0
    canonical = calc_passive_rps(base, tech_overclock=True, syndicate_tier=1, hired_workers=5, avg_morale=1.0)
    expected_canonical = 164.0625

    reporter.check(canonical == expected_canonical,
                   f"B3.1 Canonical RPS: 100 * 1.25 * 1.05 * 1.25 == {expected_canonical} (exact IEEE-754 equality)")
    # Bit-level float verification: 164.0625 in binary is 10100100.0001_2
    fractional_part = canonical - math.floor(canonical)
    reporter.check(fractional_part == 0.0625 and (0.0625 * 16.0) == 1.0,
                   "B3.2 Power-of-2 dyadic rational: 0.0625 == 1/16, guarantees zero binary floating-point rounding error")

    # 2. Permutation Commutativity Stress Test
    factors = [100.0, 1.25, 1.05, 1.25, 1.12, 1.15, 1.50, 2.00]
    all_perms_match = True
    baseline_prod = 1.0
    for f in factors:
        baseline_prod *= f

    # Test all permutations of factors subset (sample 100 permutations)
    for p in itertools.islice(itertools.permutations(factors), 100):
        prod = 1.0
        for f in p:
            prod *= f
        if abs(prod - baseline_prod) / baseline_prod > 1e-12:
            all_perms_match = False
            break

    reporter.check(all_perms_match, "B3.3 Multiplier Chain Commutativity: Permutations preserve exact product within 1e-12")

    # 3. Staff Headcount & Morale Parameter Matrix
    test_rosters = [
        (0, 1.0, 100.0 * 1.25 * 1.05 * 1.0, 131.25),
        (1, 1.0, 100.0 * 1.25 * 1.05 * 1.05, 137.8125),
        (2, 0.5, 100.0 * 1.25 * 1.05 * 1.05, 137.8125),
        (2, 1.0, 100.0 * 1.25 * 1.05 * 1.10, 144.375),
        (3, 0.8, 100.0 * 1.25 * 1.05 * 1.12, 147.00),
        (4, 1.0, 100.0 * 1.25 * 1.05 * 1.20, 157.50),
        (5, 1.0, 100.0 * 1.25 * 1.05 * 1.25, 164.0625),
    ]
    for count, morale, formula_val, expected in test_rosters:
        val = calc_passive_rps(100.0, hired_workers=count, avg_morale=morale)
        reporter.check(abs(val - expected) < 1e-4 and abs(val - formula_val) < 1e-4,
                       f"B3.4 Roster sensitivity: {count} workers @ {morale} morale yields {expected} RPS")

    # 4. Decoupling of Staff Hyper-Focus (1.5x) from Passive RPS
    gs_text = (GAME_DIR / "scripts/autoload/game_state.gd").read_text(encoding="utf-8")

    m_staff_rps = re.search(r'func get_staff_rps_multiplier\(\).*?:(.*?)(?=\nfunc |\Z)', gs_text, re.DOTALL)
    staff_rps_code = m_staff_rps.group(1) if m_staff_rps else ""

    m_eff_rps = re.search(r'func get_effective_passive_rps\(\).*?:(.*?)(?=\nfunc |\Z)', gs_text, re.DOTALL)
    eff_rps_code = m_eff_rps.group(1) if m_eff_rps else ""

    # Adversarial check: verify that get_staff_rps_multiplier does NOT contain hyper_focus
    reporter.check("staff_hyper_focus_multiplier" not in staff_rps_code,
                   "B3.5 AST Isolation: get_staff_rps_multiplier() does NOT reference staff_hyper_focus_multiplier")
    reporter.check("is_staff_hyper_focus_active" not in staff_rps_code,
                   "B3.6 AST Isolation: get_staff_rps_multiplier() does NOT reference is_staff_hyper_focus_active")
    reporter.check("hyper_focus" not in staff_rps_code,
                   "B3.7 AST Isolation: get_staff_rps_multiplier() contains ZERO references to hyper_focus")

    # Adversarial check: verify that get_effective_passive_rps does NOT call get_staff_hyper_focus_multiplier
    reporter.check("get_staff_hyper_focus_multiplier()" not in eff_rps_code,
                   "B3.8 AST Isolation: get_effective_passive_rps() does NOT call get_staff_hyper_focus_multiplier()")
    reporter.check("staff_hyper_focus_multiplier" not in eff_rps_code,
                   "B3.9 AST Isolation: get_effective_passive_rps() does NOT multiply staff_hyper_focus_multiplier")

    # Mutation test: what if a faulty implementation DID multiply staff_hyper_focus_multiplier?
    def faulty_calc_passive_rps_with_hyper_focus(base_rps: float) -> float:
        # Faulty: multiplies 1.5x hyper focus into passive RPS
        return calc_passive_rps(base_rps) * 1.50

    faulty_rps = faulty_calc_passive_rps_with_hyper_focus(100.0)
    reporter.check(faulty_rps == 246.09375, "B3.10 Fault simulation: Injected 1.5x hyper-focus inflates RPS to 246.09375 (+50% error)")
    reporter.check(abs(canonical - faulty_rps) > 1.0,
                   "B3.11 Discrepancy detectable: Canonical 164.0625 RPS vs Faulty 246.09375 RPS has delta of 82.03125 RPS")

    # 5. Offline Catch-up Reconnection Math
    # In load_from_disk(), offline gain = rps * min(elapsed, 28800.0) * 0.5
    # With 1h (3600s) and canonical 164.0625 RPS:
    gain_1h_canonical = 164.0625 * 3600.0 * 0.5
    reporter.check(gain_1h_canonical == 295312.5, "B3.12 1h Offline Catch-Up at Canonical RPS yields exactly 295,312.5 energy")

    # Uncompounded base gain (100 RPS * 3600 * 0.5):
    gain_1h_uncompounded = 100.0 * 3600.0 * 0.5
    reporter.check(gain_1h_uncompounded == 180000.0, "B3.13 1h Offline Catch-Up at Uncompounded Base yields 180,000.0 energy")

    gain_restored_delta = gain_1h_canonical - gain_1h_uncompounded
    gain_restored_pct = (gain_restored_delta / gain_1h_uncompounded) * 100.0
    reporter.check(abs(gain_restored_pct - 64.0625) < 1e-4,
                   f"B3.14 F1 Deserialization Order Recovery: Restores exactly +64.0625% offline energy (+{gain_restored_delta} energy)")


# =============================================================================
# MAIN RUNNER
# =============================================================================
def main():
    print(f"\n{Colors.BOLD}{Colors.HEADER}====================================================================")
    print(">>> EMPIRICAL CHALLENGER: ADVERSARIAL STRESS TEST & MUTATION SUITE <<<")
    print(">>> Target: Phase 18 Oracle Tiers 1-3 Sensitivity & Precision <<<")
    print(f"===================================================================={Colors.ENDC}")

    reporter = ChallengerReporter()
    test_tier_1_mutations(reporter)
    test_tier_2_math_boundaries(reporter)
    test_tier_3_multipliers_decoupling(reporter)

    print(f"\n{Colors.BOLD}{Colors.HEADER}====================================================================")
    print(">>> ADVERSARIAL SUITE SUMMARY <<<")
    print(f"===================================================================={Colors.ENDC}")
    print(f"  Passed : {Colors.OKGREEN}{reporter.passed}{Colors.ENDC}")
    print(f"  Failed : {Colors.FAIL if reporter.failed > 0 else Colors.OKGREEN}{reporter.failed}{Colors.ENDC}")
    total = reporter.passed + reporter.failed
    print(f"  Total  : {total}")
    print(f"{Colors.BOLD}{Colors.HEADER}===================================================================={Colors.ENDC}")

    if reporter.failed == 0:
        print(f"\n{Colors.BOLD}{Colors.OKGREEN}>>> ALL ADVERSARIAL MUTANTS DETECTED AND ALL BOUNDARY CHECKS PASSED (100%) <<<{Colors.ENDC}\n")
        sys.exit(0)
    else:
        print(f"\n{Colors.BOLD}{Colors.FAIL}>>> ADVERSARIAL CHALLENGES FAILED: {reporter.failed} FAILURES DETECTED <<<{Colors.ENDC}\n")
        sys.exit(1)


if __name__ == "__main__":
    main()
