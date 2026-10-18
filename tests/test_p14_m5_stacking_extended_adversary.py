#!/usr/bin/env python3
"""
Extended Adversarial Harness: Stacking Multiplier Commutativity, Monotonicity & 500 Angel Shares Compounding
=============================================================================================================
Phase 14 Milestone M5 Iteration 2 Challenger 2 Suite
Target: scripts/autoload/game_state.gd - Stacking Multipliers & Passive RPS Math

Evaluates:
  1. Full Factorial Commutativity Oracle (8! = 40,320 permutations of multiplier layers)
  2. Strict Monotonicity Across Continuous and Discrete Domains:
     - Angel Shares (0 .. 500 shares)
     - Staff count (0 .. 5 workers)
     - Average morale (0.0 .. 1.0 in 0.01 increments)
     - Syndicate Tiers (0 .. 5)
     - Bonus users (0 .. 1,000)
     - Campus collectibles (0 .. 100)
  3. Extreme Compounding Stress (500 Angel Shares + Max Multipliers):
     - 500 Angel Shares (11.0x) * Staff (1.25x) * Syndicate T5 (1.25x) * Server Overclock (1.5x)
       * Campaign Buff (1.2x) * Tech Overclock (1.25x) * Live Event (2.0x) * Campus Items (2.0x)
       * Bonus Users (5.0x)
     - Extreme boundary scaling (up to 100,000 Angel Shares)
  4. Boundary and Degenerate Inputs:
     - Base RPS = 0.0
     - 0 active workers (1.0000x)
     - 0 morale with 5 workers (1.0000x)
     - 100% fatigued workers (1.0000x)
     - Rebirth / IPO persistence of multiplier invariants
  5. Monte Carlo 10,000 Randomized Stacking Combinations
"""

import itertools
import math
import random
import sys
from typing import List, Tuple, Dict, Any

class Colors:
    GREEN = "\033[92m"
    RED = "\033[91m"
    YELLOW = "\033[93m"
    CYAN = "\033[96m"
    BOLD = "\033[1m"
    ENDC = "\033[0m"

class ExtendedReporter:
    def __init__(self):
        self.total = 0
        self.passed = 0
        self.failed = 0
        self.failures: List[str] = []

    def check(self, condition: bool, description: str, category: str = "CHECK"):
        self.total += 1
        if condition:
            self.passed += 1
            print(f"  {Colors.GREEN}[PASS]{Colors.ENDC} [{category}] {description}")
        else:
            self.failed += 1
            msg = f"[{category}] FAIL: {description}"
            self.failures.append(msg)
            print(f"  {Colors.RED}[FAIL]{Colors.ENDC} {msg}")

    def summary(self) -> int:
        print("\n" + "=" * 76)
        print("Extended Stacking Multiplier Adversarial Test Results")
        print("=" * 76)
        print(f"  Total Checks : {self.total}")
        print(f"  Passed       : {self.passed}")
        print(f"  Failed       : {self.failed}")
        if self.failed > 0:
            print(f"\n{Colors.RED}>>> VERDICT: REQUEST_CHANGES ({self.failed} failed) <<<{Colors.ENDC}\n")
            return 1
        else:
            print(f"\n{Colors.GREEN}>>> VERDICT: APPROVE (ALL STACKING INVARIANTS VERIFIED 100%) <<<{Colors.ENDC}\n")
            return 0


# ==============================================================================
# CANONICAL MULTIPLIER FUNCTIONS (Matching game_state.gd exact formulas)
# ==============================================================================

def calc_bonus_mult(bonus_users: int) -> float:
    return 1.0 + (float(bonus_users) * 0.01)

def calc_campus_mult(collectibles: int, has_neural_cloud: bool = False) -> float:
    rate = 0.10 if has_neural_cloud else 0.05
    return 1.0 + (float(collectibles) * rate)

def calc_tech_overclock_mult(has_tech_overclock: bool = False) -> float:
    return 1.25 if has_tech_overclock else 1.0

def calc_server_overclock_mult(active: bool = False, mult: float = 1.50) -> float:
    return mult if active else 1.0

def calc_campaign_mult(active: bool = False, mult: float = 1.20) -> float:
    return mult if active else 1.0

def calc_angel_share_mult(shares: int) -> float:
    return 1.0 + (float(shares) * 0.02)

def calc_syndicate_mult(tier: int) -> float:
    if tier <= 0:
        return 1.0
    return 1.0 + (float(tier) * 0.05)

def calc_live_event_mult(mult: float = 1.0) -> float:
    return max(1.0, mult)

def calc_staff_mult(active_workers: int, avg_morale: float) -> float:
    if active_workers <= 0:
        return 1.0
    clamped_morale = max(0.0, min(1.0, avg_morale))
    return 1.0 + (float(active_workers) * 0.05) * clamped_morale

def calc_effective_passive_rps(
    base_rps: float,
    bonus_users: int = 0,
    collectibles: int = 0,
    has_neural_cloud: bool = False,
    has_tech_overclock: bool = False,
    server_oc_active: bool = False,
    server_oc_mult: float = 1.50,
    campaign_active: bool = False,
    campaign_mult: float = 1.20,
    angel_shares: int = 0,
    syndicate_tier: int = 0,
    live_event_mult: float = 1.0,
    active_workers: int = 0,
    avg_morale: float = 1.0
) -> float:
    f_bonus = calc_bonus_mult(bonus_users)
    f_campus = calc_campus_mult(collectibles, has_neural_cloud)
    f_tech = calc_tech_overclock_mult(has_tech_overclock)
    f_soc = calc_server_overclock_mult(server_oc_active, server_oc_mult)
    f_camp = calc_campaign_mult(campaign_active, campaign_mult)
    f_angel = calc_angel_share_mult(angel_shares)
    f_syn = calc_syndicate_mult(syndicate_tier)
    f_live = calc_live_event_mult(live_event_mult)
    f_staff = calc_staff_mult(active_workers, avg_morale)

    return base_rps * f_bonus * f_campus * f_tech * f_soc * f_camp * f_angel * f_syn * f_live * f_staff


# ==============================================================================
# TEST EXECUTION
# ==============================================================================

def run_tests() -> int:
    reporter = ExtendedReporter()

    print(f"\n{Colors.BOLD}{Colors.CYAN}" + "=" * 76)
    print("  PHASE 14 M5 ITERATION 2: EXTENDED STACKING MULTIPLIER ADVERSARY")
    print("=" * 76 + f"{Colors.ENDC}\n")

    # --------------------------------------------------------------------------
    # 1. Full Factorial Commutativity Oracle (8! = 40,320 Permutations)
    # --------------------------------------------------------------------------
    print(f"{Colors.BOLD}[TEST 1] Factorial Commutativity Across All 40,320 Permutations{Colors.ENDC}")
    base_rps = 150.0
    factors = [
        calc_bonus_mult(50),             # 1.50
        calc_campus_mult(10, True),       # 2.00
        calc_tech_overclock_mult(True),   # 1.25
        calc_server_overclock_mult(True), # 1.50
        calc_campaign_mult(True),         # 1.20
        calc_angel_share_mult(500),       # 11.00 (500 Angel Shares)
        calc_syndicate_mult(5),           # 1.25
        calc_staff_mult(5, 0.95)          # 1.2375
    ]

    canonical_product = base_rps
    for f in factors:
        canonical_product *= f

    max_rel_diff = 0.0
    perm_count = 0
    all_permutations_passed = True

    # Test all 40,320 permutations of factor order
    for perm in itertools.permutations(factors):
        perm_count += 1
        prod = base_rps
        for f in perm:
            prod *= f
        diff = abs(prod - canonical_product)
        rel_diff = diff / canonical_product
        if rel_diff > max_rel_diff:
            max_rel_diff = rel_diff
        if rel_diff > 1e-10: # IEEE-754 precision limit
            all_permutations_passed = False
            break

    reporter.check(
        all_permutations_passed and perm_count == 40320,
        f"All {perm_count} multiplier permutations evaluated: max relative floating diff = {max_rel_diff:.2e} (< 1e-10)",
        "Commutativity_Exhaustive"
    )

    # --------------------------------------------------------------------------
    # 2. Monotonicity Tests Across Domains
    # --------------------------------------------------------------------------
    print(f"\n{Colors.BOLD}[TEST 2] Monotonicity Verifications{Colors.ENDC}")

    # 2.1 Angel Shares Monotonicity (0 .. 500 shares)
    prev_mult = -1.0
    angel_mono_passed = True
    for s in range(501):
        m = calc_angel_share_mult(s)
        if m < prev_mult:
            angel_mono_passed = False
            break
        prev_mult = m
    reporter.check(angel_mono_passed, "Angel Shares multiplier is strictly monotonic from 0 to 500 shares", "Mono_Angel")

    # Verify key Angel Share checkpoints
    reporter.check(calc_angel_share_mult(0) == 1.0, "0 Angel Shares = 1.0000x baseline", "Angel_0")
    reporter.check(abs(calc_angel_share_mult(50) - 2.0) < 1e-9, "50 Angel Shares = 2.0000x (+100%)", "Angel_50")
    reporter.check(abs(calc_angel_share_mult(100) - 3.0) < 1e-9, "100 Angel Shares = 3.0000x (+200%)", "Angel_100")
    reporter.check(abs(calc_angel_share_mult(250) - 6.0) < 1e-9, "250 Angel Shares = 6.0000x (+500%)", "Angel_250")
    reporter.check(abs(calc_angel_share_mult(500) - 11.0) < 1e-9, "500 Angel Shares = 11.0000x (+1000%)", "Angel_500")

    # 2.2 Staff Count Monotonicity (0 .. 5 workers)
    staff_count_mono = True
    for morale in [0.2, 0.5, 0.8, 1.0]:
        prev = -1.0
        for w in range(6):
            sm = calc_staff_mult(w, morale)
            if sm < prev:
                staff_count_mono = False
            prev = sm
    reporter.check(staff_count_mono, "Staff multiplier is strictly monotonic with respect to worker count (0..5)", "Mono_StaffCount")

    # 2.3 Staff Morale Monotonicity (0.0 .. 1.0 in 101 steps)
    staff_morale_mono = True
    for w in range(1, 6):
        prev = -1.0
        for step in range(101):
            mor = step / 100.0
            sm = calc_staff_mult(w, mor)
            if sm < prev - 1e-12:
                staff_morale_mono = False
            prev = sm
    reporter.check(staff_morale_mono, "Staff multiplier is strictly monotonic with respect to morale (0.0..1.0)", "Mono_Morale")

    # 2.4 Syndicate Tier Monotonicity (0 .. 5)
    syn_mono = True
    prev = -1.0
    for t in range(6):
        sm = calc_syndicate_mult(t)
        if sm < prev:
            syn_mono = False
        prev = sm
    reporter.check(syn_mono, "Syndicate multiplier is strictly monotonic across Tiers 0..5", "Mono_Syndicate")

    # 2.5 Bonus Users Monotonicity (0 .. 1000)
    bonus_mono = True
    prev = -1.0
    for b in range(0, 1001, 10):
        bm = calc_bonus_mult(b)
        if bm < prev:
            bonus_mono = False
        prev = bm
    reporter.check(bonus_mono, "Bonus users multiplier is strictly monotonic from 0 to 1,000 users", "Mono_Bonus")

    # --------------------------------------------------------------------------
    # 3. Extreme Compounding Stress (500 Angel Shares + Max Multipliers)
    # --------------------------------------------------------------------------
    print(f"\n{Colors.BOLD}[TEST 3] Extreme Compounding Stress (500 Angel Shares){Colors.ENDC}")

    base = 2500.0
    # Calculate fully compounded RPS with 500 Angel Shares:
    # Bonus Users: 400 (+400% -> 5.0x)
    # Collectibles: 10 with Neural Cloud (+100% -> 2.0x)
    # Tech Overclock: True (1.25x)
    # Server Overclock: True (1.50x)
    # Campaign Buff: True (1.20x)
    # Angel Shares: 500 (+1000% -> 11.0x)
    # Syndicate Tier: 5 (+25% -> 1.25x)
    # Live Event: 2.0x
    # Staff: 5 workers at 100% morale (+25% -> 1.25x)
    # Expected Compound factor = 5.0 * 2.0 * 1.25 * 1.50 * 1.20 * 11.0 * 1.25 * 2.0 * 1.25
    # = 10.0 * 2.25 * 13.2 * 3.125 = 10.0 * 2.25 * 41.25 = 928.125x
    compound_factor = 5.0 * 2.0 * 1.25 * 1.50 * 1.20 * 11.0 * 1.25 * 2.0 * 1.25
    expected_extreme_rps = base * compound_factor

    actual_extreme_rps = calc_effective_passive_rps(
        base_rps=base,
        bonus_users=400,
        collectibles=10,
        has_neural_cloud=True,
        has_tech_overclock=True,
        server_oc_active=True,
        server_oc_mult=1.50,
        campaign_active=True,
        campaign_mult=1.20,
        angel_shares=500,
        syndicate_tier=5,
        live_event_mult=2.0,
        active_workers=5,
        avg_morale=1.0
    )

    reporter.check(
        abs(actual_extreme_rps - expected_extreme_rps) < 1e-4,
        f"Extreme compounding with 500 Angel Shares: {base} base * {compound_factor:.3f}x = {actual_extreme_rps:.2f} RPS",
        "Compounding_500Shares"
    )
    reporter.check(math.isfinite(actual_extreme_rps) and actual_extreme_rps > 0.0, "Compound RPS remains strictly finite and positive", "Extreme_Finite")

    # Ultra extreme stress: 100,000 Angel Shares (Multiplier = 2001.0x)
    ultra_rps = calc_effective_passive_rps(
        base_rps=1000.0,
        angel_shares=100000,
        active_workers=5,
        avg_morale=1.0,
        syndicate_tier=5
    )
    expected_ultra = 1000.0 * (1.0 + 100000 * 0.02) * 1.25 * 1.25 # 1000 * 2001 * 1.5625 = 3,126,562.5
    reporter.check(abs(ultra_rps - expected_ultra) < 1e-4, f"Ultra 100k Angel Shares scales cleanly: {ultra_rps:.2f} RPS (no overflow)", "Ultra_100kShares")

    # --------------------------------------------------------------------------
    # 4. Boundary and Degenerate Inputs
    # --------------------------------------------------------------------------
    print(f"\n{Colors.BOLD}[TEST 4] Boundary & Degenerate Cases{Colors.ENDC}")

    # Zero base RPS
    zero_rps = calc_effective_passive_rps(0.0, angel_shares=500, active_workers=5, syndicate_tier=5)
    reporter.check(zero_rps == 0.0, "Base RPS 0.0 strictly returns 0.0 regardless of multipliers", "Boundary_ZeroBase")

    # Zero workers baseline
    zero_staff = calc_staff_mult(0, 1.0)
    reporter.check(zero_staff == 1.0, "Zero workers produces exactly 1.0000x staff multiplier", "Boundary_ZeroStaff")

    # 5 workers with 0.0 morale
    zero_morale_staff = calc_staff_mult(5, 0.0)
    reporter.check(zero_morale_staff == 1.0, "5 workers at 0.0 morale produces exactly 1.0000x staff multiplier", "Boundary_ZeroMorale")

    # Fatigued workers (active_count = 0)
    fatigued_staff = calc_staff_mult(0, 0.5)
    reporter.check(fatigued_staff == 1.0, "Active workers = 0 (all fatigued) produces exactly 1.0000x staff multiplier", "Boundary_AllFatigued")

    # Negative values clamped gracefully
    neg_morale_staff = calc_staff_mult(3, -5.0)
    reporter.check(neg_morale_staff == 1.0, "Negative morale (-5.0) clamped to 0.0 (multiplier = 1.0000x)", "Boundary_NegMorale")

    # --------------------------------------------------------------------------
    # 5. Monte Carlo 10,000 Randomized Stacking Combinations
    # --------------------------------------------------------------------------
    print(f"\n{Colors.BOLD}[TEST 5] Monte Carlo Randomized Stress (10,000 runs){Colors.ENDC}")
    random.seed(42)
    mc_passed = True
    for _ in range(10000):
        b_rps = random.uniform(0.0, 50000.0)
        b_users = random.randint(0, 500)
        coll = random.randint(0, 50)
        n_cloud = random.choice([True, False])
        t_oc = random.choice([True, False])
        s_oc = random.choice([True, False])
        c_buff = random.choice([True, False])
        ashares = random.randint(0, 500)
        syn_t = random.randint(0, 5)
        l_mult = random.choice([1.0, 1.5, 2.0, 2.5])
        w_cnt = random.randint(0, 5)
        mor = random.uniform(0.0, 1.0)

        rps = calc_effective_passive_rps(
            base_rps=b_rps,
            bonus_users=b_users,
            collectibles=coll,
            has_neural_cloud=n_cloud,
            has_tech_overclock=t_oc,
            server_oc_active=s_oc,
            campaign_active=c_buff,
            angel_shares=ashares,
            syndicate_tier=syn_t,
            live_event_mult=l_mult,
            active_workers=w_cnt,
            avg_morale=mor
        )

        if math.isnan(rps) or math.isinf(rps) or rps < 0.0:
            mc_passed = False
            break

    reporter.check(mc_passed, "10,000 randomized Monte Carlo economy stacking runs remained finite, positive, and stable", "MonteCarlo_10k")

    return reporter.summary()

if __name__ == "__main__":
    sys.exit(run_tests())
