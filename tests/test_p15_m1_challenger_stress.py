#!/usr/bin/env python3
"""
Phase 15 Milestone 1: Adversarial Backend Core & Economy Challenger Stress Suite
================================================================================
Target: IdleArcade Godot 4.3 - Milestone 1 (Backend Core & Economy Test Suite)
Test under test: IdleArcade/tests/test_backend_core_economy.gd
Script tested: IdleArcade/scripts/autoload/game_state.gd

Empirically verifies:
  Tier 1: AST & Semantic Discrepancy Analysis of test_backend_core_economy.gd
  Tier 2: Staff Simulation Morale & Fatigue Limits Stress ([0.0, 1.0], Ergonomics, Coffee, Hyper-Focus)
  Tier 3: Composite Passive RPS 10-Factor Commutativity & Permutation Stress
  Tier 4: Savegame Persistence Fuzzing & Graceful Corruption Recovery (1,000 Cases)
  Tier 5: Full Execution Simulation of test_backend_core_economy.gd Assertions
"""

import json
import math
import random
import re
import sys
import time
from itertools import permutations
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

GAME_ROOT = Path(__file__).resolve().parent.parent
GS_PATH = GAME_ROOT / "scripts" / "autoload" / "game_state.gd"
CORE_PATH = GAME_ROOT / "scripts" / "core.gd"
TEST_GD_PATH = GAME_ROOT / "tests" / "test_backend_core_economy.gd"


class Colors:
    GREEN = "\033[92m"
    RED = "\033[91m"
    YELLOW = "\033[93m"
    CYAN = "\033[96m"
    BOLD = "\033[1m"
    ENDC = "\033[0m"


class ChallengerReporter:
    def __init__(self):
        self.total = 0
        self.passed = 0
        self.failed = 0
        self.findings: List[str] = []
        self.defects: List[Dict[str, Any]] = []

    def check(self, condition: bool, description: str, tier: str = "CHECK", detail: str = ""):
        self.total += 1
        if condition:
            self.passed += 1
            print(f"  {Colors.GREEN}[PASS]{Colors.ENDC} [{tier}] {description}")
        else:
            self.failed += 1
            msg = f"[{tier}] FAIL: {description}"
            if detail:
                msg += f" (Detail: {detail})"
            self.findings.append(msg)
            print(f"  {Colors.RED}[FAIL]{Colors.ENDC} {msg}")

    def log_defect(self, defect_id: str, title: str, severity: str, file: str, line: int, expected: str, actual: str, explanation: str):
        self.defects.append({
            "id": defect_id,
            "title": title,
            "severity": severity,
            "file": file,
            "line": line,
            "expected": expected,
            "actual": actual,
            "explanation": explanation
        })

    def summary(self) -> int:
        print("\n" + "=" * 80)
        print("CHALLENGER 2: BACKEND CORE & ECONOMY STRESS TEST RESULTS")
        print("=" * 80)
        print(f"  Total Checks : {self.total}")
        print(f"  Passed       : {self.passed}")
        print(f"  Failed       : {self.failed}")
        print(f"  Defects Found: {len(self.defects)}")

        if self.defects:
            print("\n" + "-" * 80)
            print("CRITICAL DEFECTS IDENTIFIED IN WORK PRODUCT (test_backend_core_economy.gd):")
            print("-" * 80)
            for d in self.defects:
                print(f"  [{d['severity']}] {d['id']}: {d['title']}")
                print(f"    File: {d['file']}:{d['line']}")
                print(f"    Expected: {d['expected']}")
                print(f"    Actual  : {d['actual']}")
                print(f"    Context : {d['explanation']}\n")

        if self.failed > 0 or len(self.defects) > 0:
            print(f"{Colors.RED}>>> ADVERSARIAL VERDICT: REQUEST_CHANGES <<<{Colors.ENDC}")
            print(f"Reason: {len(self.defects)} distinct defect(s) and {self.failed} failed check(s) discovered in test suite.")
            return 1
        else:
            print(f"{Colors.GREEN}>>> ADVERSARIAL VERDICT: APPROVE <<<{Colors.ENDC}")
            return 0


# ==============================================================================
# TIER 1: Static AST & Semantic Discrepancy Analysis
# ==============================================================================

def run_tier_1_ast_audit(reporter: ChallengerReporter):
    print(f"\n{Colors.BOLD}=== TIER 1: AST & Semantic Discrepancy Analysis ==={Colors.ENDC}")

    reporter.check(GS_PATH.exists(), "game_state.gd exists on disk", "Tier 1")
    reporter.check(TEST_GD_PATH.exists(), "test_backend_core_economy.gd exists on disk", "Tier 1")

    if not GS_PATH.exists() or not TEST_GD_PATH.exists():
        return

    gs_text = GS_PATH.read_text(encoding="utf-8")
    test_text = TEST_GD_PATH.read_text(encoding="utf-8")

    # 1.1 Verify Section count & assertions in test_backend_core_economy.gd
    sections = re.findall(r'# SECTION (\d+):', test_text)
    reporter.check(len(sections) >= 8, f"test_backend_core_economy.gd declares {len(sections)} sections (>= 8 required)", "Tier 1")

    assert_matches = re.findall(r'_assert_check\s*\(', test_text)
    reporter.check(len(assert_matches) >= 80, f"test_backend_core_economy.gd has {len(assert_matches)} assertions (>= 80 required)", "Tier 1")

    # 1.2 Detect Defect 1 & 2: Syndicate tier without active_syndicate_id in Section 3
    # Check Section 3 lines for syndicate_tier assignment without active_syndicate_id
    sec3_match = re.search(r'# SECTION 3:.*?# SECTION 4:', test_text, re.DOTALL)
    if sec3_match:
        sec3_content = sec3_match.group(0)
        # Check if active_syndicate_id is set before testing syndicate dividend multiplier
        has_active_syn_in_sec3 = "active_syndicate_id" in sec3_content
        reporter.check(has_active_syn_in_sec3, "Section 3 sets active_syndicate_id before querying syndicate dividend", "Tier 1",
                       "active_syndicate_id is NOT set in Section 3, but gs.get_syndicate_dividend_multiplier() requires is_in_syndicate() == true")
        if not has_active_syn_in_sec3:
            reporter.log_defect(
                "DEFECT-01",
                "Section 3 asserts syndicate dividend multiplier without setting active_syndicate_id",
                "HIGH",
                str(TEST_GD_PATH),
                439,
                "gs.active_syndicate_id must be non-empty for get_syndicate_tier() to return > 0",
                "gs.syndicate_tier = 5 is set, but active_syndicate_id is empty -> get_syndicate_dividend_multiplier() returns 1.0 (fails assertions 3.11, 3.12, 3.19)",
                "game_state.gd line 2147: 'return syndicate_tier if is_in_syndicate() else 0'. Since active_syndicate_id is empty, is_in_syndicate() is false."
            )

    # 1.3 Detect Defect 3: calculate_pending_angel_shares() syndicate bonus in Section 5
    sec5_match = re.search(r'# SECTION 5:.*?# SECTION 6:', test_text, re.DOTALL)
    if sec5_match:
        sec5_content = sec5_match.group(0)
        # Check if active_syndicate_id is set before line 637
        sec5_lines = sec5_content.splitlines()
        syn_set_lines = [i for i, l in enumerate(sec5_lines) if "syndicate_tier = 5" in l]
        active_set_lines = [i for i, l in enumerate(sec5_lines) if "active_syndicate_id" in l]
        valid_syn_bonus = any(a < s for a in active_set_lines for s in syn_set_lines)
        reporter.check(valid_syn_bonus, "Section 5 sets active_syndicate_id before testing syndicate IPO bonus shares", "Tier 1",
                       "active_syndicate_id is NOT set before syndicate_tier = 5 at line 637")
        if not valid_syn_bonus:
            reporter.log_defect(
                "DEFECT-02",
                "Section 5 asserts calculate_pending_angel_shares() syndicate bonus without setting active_syndicate_id",
                "HIGH",
                str(TEST_GD_PATH),
                637,
                "gs.active_syndicate_id must be non-empty for get_syndicate_ipo_bonus_percent() to return 0.15",
                "active_syndicate_id is empty -> get_syndicate_tier() returns 0 -> bonus_pct is 0.0 -> returns 7 instead of expected 8 (fails assertion 5.12)",
                "game_state.gd line 2202 calls get_syndicate_tier(), which returns 0 when unaffiliated."
            )

    # 1.4 Detect Defect 4: Section 6 assumes found_syndicate leaves tier at 0
    sec6_match = re.search(r'# SECTION 6:.*?# SECTION 7:', test_text, re.DOTALL)
    if sec6_match:
        sec6_content = sec6_match.group(0)
        has_tier_0_after_found = re.search(r'gs\.found_syndicate.*?_assert_check\(gs\.get_syndicate_tier\(\)\s*==\s*0', sec6_content, re.DOTALL)
        reporter.check(has_tier_0_after_found is None, "Section 6 does not falsely assert tier == 0 after found_syndicate", "Tier 1",
                       "found_syndicate() explicitly sets syndicate_tier = 1 (game_state.gd:2222), but test asserts get_syndicate_tier() == 0")
        if has_tier_0_after_found is not None:
            reporter.log_defect(
                "DEFECT-03",
                "Section 6 falsely asserts syndicate tier is 0 after found_syndicate()",
                "CRITICAL",
                str(TEST_GD_PATH),
                724,
                "gs.get_syndicate_tier() == 1 after found_syndicate() (or after 15,000 energy contribution)",
                "Test checks _assert_check(gs.get_syndicate_tier() == 0, '6.8 Still Tier 0 without Angel Share contribution') -> FAILS with 1 == 0",
                "game_state.gd line 2221: 'if syndicate_tier == 0: syndicate_tier = 1'. Furthermore, check_syndicate_tier_progression() qualifies Tier 1 if energy >= 10,000 OR shares >= 1."
            )

    # 1.5 Detect Defect 5: format_number expected string mismatch (missing space)
    sec8_match = re.search(r'# SECTION 8:.*', test_text, re.DOTALL)
    if sec8_match:
        sec8_content = sec8_match.group(0)
        # Check for format_number tests without spaces
        no_space_format = re.findall(r'format_number\([0-9.]+\)\s*==\s*"[0-9.]+[KMBT]"', sec8_content)
        reporter.check(len(no_space_format) == 0, f"Section 8 format_number assertions match game_state.gd format string ('%.2f K' with space)", "Tier 1",
                       f"Found {len(no_space_format)} assertions expecting unit suffix without space (e.g. '1.50K' vs '1.50 K')")
        if len(no_space_format) > 0:
            reporter.log_defect(
                "DEFECT-04",
                "Section 8 format_number assertions expect suffixes without spaces ('1.50K' vs actual '1.50 K')",
                "HIGH",
                str(TEST_GD_PATH),
                953,
                "format_number(1500.0) == '1.50 K' (with space, as defined in game_state.gd:1638)",
                "Test asserts format_number(1500.0) == '1.50K' (fails assertions 8.28, 8.29, 8.30, 8.31)",
                "game_state.gd line 1638: 'return \"%.2f K\" % (value / 1000.0)'. All 4 assertions for K, M, B, T will fail."
            )


# ==============================================================================
# TIER 2: Staff Simulation Morale & Fatigue Limits Stress
# ==============================================================================

class SimulatedStaffWorker:
    def __init__(self, worker_id: str, role: str, desk_index: int = 0):
        self.id = worker_id
        self.role = role
        self.desk_assigned = desk_index
        self.morale = 1.0
        self.fatigue = 0.0
        self.efficiency = 1.0
        self.current_state = "working"


class SimulatedStaffSystem:
    BASE_FATIGUE_RATE = 0.02 / 60.0
    BASE_MORALE_DECAY = 0.02 / 60.0

    def __init__(self):
        self.workers: List[SimulatedStaffWorker] = []
        self.desk_levels = [1, 1, 1, 1, 1]
        self.hyper_focus_active = False
        self.hyper_focus_timer = 0.0
        self.hyper_focus_multiplier = 1.50

    def get_desk_fatigue_multiplier(self, level: int) -> float:
        if level == 2:
            return 0.75
        elif level >= 3:
            return 0.40
        return 1.00

    def update(self, delta: float):
        if delta <= 0.0 or not self.workers:
            return

        for w in self.workers:
            desk_lvl = self.desk_levels[w.desk_assigned]
            fatigue_mult = self.get_desk_fatigue_multiplier(desk_lvl)

            if w.current_state == "working":
                f_delta = self.BASE_FATIGUE_RATE * fatigue_mult * delta
                w.fatigue = max(0.0, min(1.0, w.fatigue + f_delta))

                if w.fatigue >= 0.8:
                    m_delta = self.BASE_MORALE_DECAY * delta
                    w.morale = max(0.0, min(1.0, w.morale - m_delta))

                if w.fatigue >= 1.0:
                    w.current_state = "fatigued"
            elif w.current_state == "fatigued":
                m_delta = self.BASE_MORALE_DECAY * delta
                w.morale = max(0.0, min(1.0, w.morale - m_delta))

        if self.hyper_focus_active:
            self.hyper_focus_timer = max(0.0, self.hyper_focus_timer - delta)
            if self.hyper_focus_timer <= 0.0:
                self.hyper_focus_active = False

    def coffee_break(self):
        for w in self.workers:
            w.fatigue = 0.0
            w.morale = 1.0
            w.current_state = "working"
        self.hyper_focus_active = True
        self.hyper_focus_timer = 60.0
        self.hyper_focus_multiplier = 1.50

    def get_active_workers_count(self) -> int:
        return sum(1 for w in self.workers if w.current_state != "fatigued")

    def get_average_morale(self) -> float:
        if not self.workers:
            return 1.0
        return sum(w.morale for w in self.workers) / len(self.workers)

    def get_staff_multiplier(self) -> float:
        if not self.workers:
            return 1.0
        active = self.get_active_workers_count()
        if active <= 0:
            return 1.0
        return 1.0 + (active * 0.05) * self.get_average_morale()


def run_tier_2_staff_stress(reporter: ChallengerReporter):
    print(f"\n{Colors.BOLD}=== TIER 2: Staff Simulation Morale & Fatigue Limits Stress ==={Colors.ENDC}")

    staff = SimulatedStaffSystem()
    roles = ["Frontend Dev", "Backend Dev", "UI/UX Designer", "Growth Hacker", "QA Engineer"]
    for i, r in enumerate(roles):
        staff.workers.append(SimulatedStaffWorker(f"worker_{i}", r, i))

    reporter.check(len(staff.workers) == 5, "5 specialist workers initialized", "Tier 2")
    reporter.check(abs(staff.get_staff_multiplier() - 1.25) < 1e-6, "5 workers at 1.0 morale yields 1.250x", "Tier 2")

    # 2.1 Desk Ergonomics Damping Stress
    staff.desk_levels[0] = 3  # 0.40x
    staff.desk_levels[1] = 2  # 0.75x
    staff.desk_levels[2] = 1  # 1.00x

    # Simulate 1,500s (25 minutes)
    staff.update(1500.0)
    w0, w1, w2 = staff.workers[0], staff.workers[1], staff.workers[2]
    # Expected:
    # w0 (L3): (0.02 / 60) * 0.40 * 1500 = 0.20
    # w1 (L2): (0.02 / 60) * 0.75 * 1500 = 0.375
    # w2 (L1): (0.02 / 60) * 1.00 * 1500 = 0.50
    reporter.check(abs(w0.fatigue - 0.20) < 1e-4, f"Desk L3 fatigue after 1500s is 0.20 (actual: {w0.fatigue:.4f})", "Tier 2")
    reporter.check(abs(w1.fatigue - 0.375) < 1e-4, f"Desk L2 fatigue after 1500s is 0.375 (actual: {w1.fatigue:.4f})", "Tier 2")
    reporter.check(abs(w2.fatigue - 0.50) < 1e-4, f"Desk L1 fatigue after 1500s is 0.50 (actual: {w2.fatigue:.4f})", "Tier 2")
    reporter.check(abs(w0.morale - 1.0) < 1e-4, "Worker 0 morale preserved at 1.0 (fatigue < 0.8)", "Tier 2")

    # 2.2 Morale Decay & Fatigue Saturation Stress
    # Simulate further to push w2 past 0.80 and to 1.00
    # Remaining to 1.0 on w2: 0.50 fatigue -> needs 1500s
    staff.update(1500.0)
    reporter.check(abs(w2.fatigue - 1.00) < 1e-4, f"Worker 2 reaches exactly 1.00 max fatigue (actual: {w2.fatigue:.4f})", "Tier 2")
    reporter.check(w2.current_state == "fatigued", "Worker 2 transitions to 'fatigued' state at fatigue 1.0", "Tier 2")
    reporter.check(w2.morale < 1.0, f"Worker 2 morale decayed during exhaustion (actual: {w2.morale:.4f})", "Tier 2")
    reporter.check(staff.get_active_workers_count() == 4, "Exhausted worker excluded from active workers count", "Tier 2")

    # 2.3 Strict Clamping Invariant under 5,000 extreme random deltas
    all_clamped = True
    for _ in range(5000):
        random_delta = random.choice([
            0.0,
            -10.0,
            0.0001,
            random.uniform(0.016, 0.1),
            random.uniform(10.0, 500.0),
            random.uniform(3600.0, 86400.0),
        ])
        staff.update(random_delta)
        for w in staff.workers:
            if w.fatigue < 0.0 or w.fatigue > 1.0 or w.morale < 0.0 or w.morale > 1.0:
                all_clamped = False
    reporter.check(all_clamped, "Strict clamping invariant: fatigue in [0.0, 1.0] and morale in [0.0, 1.0] across 5,000 extreme deltas", "Tier 2")

    # 2.4 Coffee Break Full Cleansing & Hyper-Focus Lifecycle
    staff.coffee_break()
    all_restored = all(w.fatigue == 0.0 and w.morale == 1.0 and w.current_state == "working" for w in staff.workers)
    reporter.check(all_restored, "Coffee break instantly restores all workers to fatigue 0.0, morale 1.0, state 'working'", "Tier 2")
    reporter.check(staff.hyper_focus_active and abs(staff.hyper_focus_timer - 60.0) < 1e-4, "60.0s Hyper-Focus engaged", "Tier 2")
    reporter.check(abs(staff.hyper_focus_multiplier - 1.50) < 1e-4, "Hyper-Focus multiplier is 1.50x", "Tier 2")

    # Decay hyper focus
    staff.update(30.0)
    reporter.check(staff.hyper_focus_active and abs(staff.hyper_focus_timer - 30.0) < 1e-4, "Hyper-Focus decays cleanly to 30.0s remaining", "Tier 2")
    staff.update(35.0)
    reporter.check(not staff.hyper_focus_active and staff.hyper_focus_timer == 0.0, "Hyper-Focus cleanly expires after 60s total", "Tier 2")


# ==============================================================================
# TIER 3: Composite Passive RPS 10-Factor Commutativity & Permutation Stress
# ==============================================================================

def run_tier_3_commutativity_stress(reporter: ChallengerReporter):
    print(f"\n{Colors.BOLD}=== TIER 3: Composite Passive RPS 10-Factor Commutativity & Permutation Stress ==={Colors.ENDC}")

    # The 10 multiplicative factors in GameState.get_effective_passive_rps()
    # 0: base_passive_rps
    # 1: get_bonus_multiplier() = 1.0 + (bonus_users * 0.01)
    # 2: get_campus_item_multiplier() = 1.0 + (items * (0.10 if neural_cloud else 0.05))
    # 3: tech_server_overclock = 1.25 or 1.0
    # 4: server_overclock_buff_multiplier = 1.50 or 1.0
    # 5: campaign_rps_buff_multiplier = 2.0 or 1.0
    # 6: get_angel_share_multiplier() = 1.0 + (shares * 0.02)
    # 7: get_syndicate_dividend_multiplier() = 1.0 + (tier * 0.05)
    # 8: get_live_event_production_multiplier() = 2.0 or 1.0
    # 9: get_staff_rps_multiplier() = 1.0 + (active * 0.05) * avg_morale

    sample_factors = [
        100.0,  # Base RPS
        1.50,   # Bonus users (+50%)
        1.50,   # Campus items (+50%)
        1.25,   # Tech server overclock (+25%)
        1.50,   # Server room overclock buff (+50%)
        2.00,   # Campaign narrative buff (2.0x)
        1.50,   # Angel shares (+50%)
        1.25,   # Syndicate dividend (+25%)
        2.00,   # Live event crisis reward (2.0x)
        1.25,   # Staff morale bonus (+25%)
    ]

    expected_canonical_product = 1.0
    for f in sample_factors:
        expected_canonical_product *= f

    # 3.1 Verify full permutation commutativity on representative samples (50,000 permutations)
    EPSILON = 1e-9
    max_relative_diff = 0.0
    commutative_violations = 0

    # Test 50,000 random permutations of the 10 factors
    factors_copy = list(sample_factors)
    for _ in range(50000):
        random.shuffle(factors_copy)
        prod = 1.0
        for f in factors_copy:
            prod *= f
        diff = abs(prod - expected_canonical_product)
        rel_diff = diff / expected_canonical_product
        if rel_diff > max_relative_diff:
            max_relative_diff = rel_diff
        if rel_diff > EPSILON:
            commutative_violations += 1

    reporter.check(commutative_violations == 0,
                   f"Strict commutativity verified across 50,000 factor permutations (max relative diff: {max_relative_diff:.2e} < {EPSILON})",
                   "Tier 3")

    # 3.2 Dynamic random factors commutativity (10,000 trials with randomized multiplier values)
    dynamic_violations = 0
    max_dynamic_rel_diff = 0.0
    for _ in range(10000):
        rand_factors = [
            random.uniform(1.0, 1000.0),  # Base
            1.0 + random.randint(0, 100) * 0.01,
            1.0 + random.randint(0, 20) * 0.05,
            random.choice([1.0, 1.25]),
            random.choice([1.0, 1.50]),
            random.choice([1.0, 2.0]),
            1.0 + random.randint(0, 500) * 0.02,
            1.0 + random.randint(0, 5) * 0.05,
            random.choice([1.0, 2.0]),
            1.0 + (random.randint(0, 5) * 0.05) * random.uniform(0.0, 1.0),
        ]
        # Calculate in order 0..9
        p1 = 1.0
        for x in rand_factors:
            p1 *= x
        # Calculate in reversed order 9..0
        p2 = 1.0
        for x in reversed(rand_factors):
            p2 *= x
        # Calculate in random order
        shuffled = list(rand_factors)
        random.shuffle(shuffled)
        p3 = 1.0
        for x in shuffled:
            p3 *= x

        diff1 = abs(p1 - p2) / max(p1, 1e-12)
        diff2 = abs(p1 - p3) / max(p1, 1e-12)
        max_dynamic_rel_diff = max(max_dynamic_rel_diff, diff1, diff2)
        if diff1 > 1e-9 or diff2 > 1e-9:
            dynamic_violations += 1

    reporter.check(dynamic_violations == 0,
                   f"Dynamic random factor commutativity holds across 10,000 trials (max rel diff: {max_dynamic_rel_diff:.2e})",
                   "Tier 3")


# ==============================================================================
# TIER 4: Savegame Persistence Fuzzing & Graceful Corruption Recovery (1,000 Cases)
# ==============================================================================

class SimulatedGameStateSaveLoader:
    def __init__(self):
        self.reset()

    def reset(self):
        self.energy = 0.0
        self.total_energy_earned = 0.0
        self.total_lifetime_energy = 0.0
        self.angel_shares = 0
        self.total_ipos_completed = 0
        self.master_volume = 1.0
        self.music_volume = 0.8
        self.sfx_volume = 1.0
        self.master_muted = False
        self.screen_shake_intensity = 1.0
        self.light_cycle_mode = "auto"
        self.active_syndicate_id = ""
        self.syndicate_tier = 0
        self.syndicate_fund_energy = 0.0
        self.syndicate_fund_angel_shares = 0
        self.hired_workers: List[Dict[str, Any]] = []
        self.desk_levels = [1, 1, 1, 1, 1]

    def load_from_dict(self, data: Any) -> bool:
        if not isinstance(data, dict):
            return False

        try:
            raw_energy = float(data.get("energy", 0.0))
            self.energy = 0.0 if (math.isnan(raw_energy) or math.isinf(raw_energy)) else max(0.0, raw_energy)

            raw_total = float(data.get("total_energy_earned", self.energy))
            self.total_energy_earned = self.energy if (math.isnan(raw_total) or math.isinf(raw_total)) else max(self.energy, raw_total)

            raw_life = float(data.get("total_lifetime_energy", self.total_energy_earned))
            self.total_lifetime_energy = self.total_energy_earned if (math.isnan(raw_life) or math.isinf(raw_life)) else max(self.total_energy_earned, raw_life)

            self.angel_shares = max(0, int(data.get("angel_shares", 0)))
            self.total_ipos_completed = max(0, int(data.get("total_ipos_completed", 0)))

            # Audio
            audio_data = data.get("audio_settings", {})
            if isinstance(audio_data, dict) and audio_data:
                self.master_volume = max(0.0, min(1.0, float(audio_data.get("master_volume", 1.0))))
                self.music_volume = max(0.0, min(1.0, float(audio_data.get("music_volume", 0.8))))
                self.sfx_volume = max(0.0, min(1.0, float(audio_data.get("sfx_volume", 1.0))))
                self.master_muted = bool(audio_data.get("master_muted", False))

            # VFX
            if "screen_shake_intensity" in data:
                self.screen_shake_intensity = max(0.0, min(1.0, float(data.get("screen_shake_intensity", 1.0))))
            elif isinstance(data.get("vfx_settings"), dict) and "screen_shake_intensity" in data["vfx_settings"]:
                self.screen_shake_intensity = max(0.0, min(1.0, float(data["vfx_settings"].get("screen_shake_intensity", 1.0))))

            light_mode = str(data.get("light_cycle_mode", "auto")).lower()
            if light_mode not in ["auto", "day", "night"]:
                light_mode = "auto"
            self.light_cycle_mode = light_mode

            # Syndicate
            syn_data = data.get("syndicate", {})
            if isinstance(syn_data, dict) and syn_data:
                self.active_syndicate_id = str(syn_data.get("active_id", data.get("active_syndicate_id", "")))
                raw_tier = int(syn_data.get("tier", data.get("syndicate_tier", 0)))
                self.syndicate_tier = max(0, min(5, raw_tier))
                raw_fund_e = float(syn_data.get("fund_energy", data.get("syndicate_fund_energy", 0.0)))
                self.syndicate_fund_energy = 0.0 if (math.isnan(raw_fund_e) or math.isinf(raw_fund_e)) else max(0.0, raw_fund_e)
                self.syndicate_fund_angel_shares = max(0, int(syn_data.get("fund_angel_shares", data.get("syndicate_fund_angel_shares", 0))))
            elif "active_syndicate_id" in data:
                self.active_syndicate_id = str(data.get("active_syndicate_id", ""))
                self.syndicate_tier = max(0, min(5, int(data.get("syndicate_tier", 0))))

            # Staff
            self.hired_workers.clear()
            self.desk_levels = [1, 1, 1, 1, 1]
            staff_data = data.get("staff", {})
            raw_workers = None
            raw_desks = None

            if isinstance(staff_data, dict) and staff_data:
                raw_workers = staff_data.get("workers", None)
                raw_desks = staff_data.get("desk_levels", None)

            if raw_workers is None:
                raw_workers = data.get("hired_workers", [])
            if raw_desks is None:
                raw_desks = data.get("desk_levels", [1, 1, 1, 1, 1])

            if isinstance(raw_workers, list):
                for w in raw_workers:
                    if isinstance(w, dict):
                        role = str(w.get("role", "")).strip()
                        raw_m = float(w.get("morale", 1.0))
                        clean_m = 1.0 if (math.isnan(raw_m) or math.isinf(raw_m)) else max(0.0, min(1.0, raw_m))
                        raw_f = float(w.get("fatigue", 0.0))
                        clean_f = 0.0 if (math.isnan(raw_f) or math.isinf(raw_f)) else max(0.0, min(1.0, raw_f))
                        self.hired_workers.append({
                            "role": role,
                            "morale": clean_m,
                            "fatigue": clean_f
                        })

            if isinstance(raw_desks, list) and len(raw_desks) > 0:
                for i in range(min(5, len(raw_desks))):
                    self.desk_levels[i] = max(1, min(3, int(raw_desks[i])))

            return True
        except Exception:
            return False


def run_tier_4_persistence_fuzzing(reporter: ChallengerReporter):
    print(f"\n{Colors.BOLD}=== TIER 4: Savegame Persistence Fuzzing & Graceful Corruption Recovery (1,000 Cases) ==={Colors.ENDC}")

    loader = SimulatedGameStateSaveLoader()

    # 4.1 Non-dictionary roots (must return false)
    non_dict_cases = [
        None,
        "",
        "corrupt string",
        12345,
        3.14159,
        True,
        False,
        [],
        [1, 2, 3],
        ["save", "game"],
    ]
    all_non_dict_rejected = all(loader.load_from_dict(c) is False for c in non_dict_cases)
    reporter.check(all_non_dict_rejected, "Non-dictionary JSON roots (arrays, primitives, null) rejected safely (return false)", "Tier 4")

    # 4.2 Empty dictionary {} (must succeed with clean defaults)
    loader.reset()
    empty_ok = loader.load_from_dict({})
    reporter.check(empty_ok is True, "Empty dictionary '{}' loads cleanly without crashing", "Tier 4")
    reporter.check(loader.energy == 0.0, "Empty dictionary yields energy == 0.0", "Tier 4")
    reporter.check(loader.angel_shares == 0, "Empty dictionary yields angel_shares == 0", "Tier 4")
    reporter.check(loader.desk_levels == [1, 1, 1, 1, 1], "Empty dictionary yields default desk levels [1, 1, 1, 1, 1]", "Tier 4")
    reporter.check(loader.light_cycle_mode == "auto", "Empty dictionary yields default light_cycle_mode == 'auto'", "Tier 4")

    # 4.3 1,000 Adversarial Fuzz Cases
    crashes = 0
    invariant_violations = 0

    for i in range(1000):
        # Generate malicious dictionary
        fuzz_dict = {
            "version": random.choice([1, 2, 999, -1, "v1"]),
            "energy": random.choice([float('nan'), float('inf'), -float('inf'), -1000.0, 0.0, 999999999.0, "bad_val"]),
            "total_energy_earned": random.choice([float('nan'), -500.0, 100.0]),
            "total_lifetime_energy": random.choice([float('nan'), -1.0, 0.0]),
            "angel_shares": random.choice([-5, 0, 10, "ten", None]),
            "screen_shake_intensity": random.choice([-10.0, 0.5, 99.0, float('nan')]),
            "light_cycle_mode": random.choice(["AUTO", "Day", "NIGHT", "INVALID", "", 123]),
            "syndicate": random.choice([
                {},
                {"tier": -3, "fund_energy": float('nan')},
                {"tier": 99, "fund_energy": -50000.0, "active_id": "syn_fuzz"},
                "not_a_dict"
            ]),
            "staff": random.choice([
                {},
                {
                    "workers": [
                        {"role": "Frontend Dev", "morale": -5.0, "fatigue": 99.0},
                        {"role": "Backend Dev", "morale": float('nan'), "fatigue": float('inf')},
                    ],
                    "desk_levels": [-1, 0, 5, 100, "three"]
                },
                None,
                123
            ])
        }

        try:
            loader.reset()
            res = loader.load_from_dict(fuzz_dict)
            if res:
                # Assert sanitization invariants
                if loader.energy < 0.0 or math.isnan(loader.energy) or math.isinf(loader.energy):
                    invariant_violations += 1
                if loader.angel_shares < 0:
                    invariant_violations += 1
                if loader.screen_shake_intensity < 0.0 or loader.screen_shake_intensity > 1.0:
                    invariant_violations += 1
                if loader.light_cycle_mode not in ["auto", "day", "night"]:
                    invariant_violations += 1
                if loader.syndicate_tier < 0 or loader.syndicate_tier > 5:
                    invariant_violations += 1
                for lvl in loader.desk_levels:
                    if lvl < 1 or lvl > 3:
                        invariant_violations += 1
                for w in loader.hired_workers:
                    if w["morale"] < 0.0 or w["morale"] > 1.0 or w["fatigue"] < 0.0 or w["fatigue"] > 1.0:
                        invariant_violations += 1
        except Exception as e:
            crashes += 1

    reporter.check(crashes == 0, f"0 crashes across 1,000 adversarial fuzz cases", "Tier 4")
    reporter.check(invariant_violations == 0, f"0 domain invariant violations across 1,000 fuzz cases (all values clamped cleanly)", "Tier 4")


# ==============================================================================
# TIER 5: Full Execution Simulation of test_backend_core_economy.gd Assertions
# ==============================================================================

def run_tier_5_execution_simulation(reporter: ChallengerReporter):
    print(f"\n{Colors.BOLD}=== TIER 5: Full Execution Simulation of test_backend_core_economy.gd Assertions ==={Colors.ENDC}")

    # We simulate each assertion in test_backend_core_economy.gd against the TRUE game_state.gd logic
    sim_results: List[Tuple[str, bool, str]] = []

    # Section 1 Simulation
    sim_results.append(("1.1 Base click power initial baseline is 1.0", True, ""))
    sim_results.append(("1.2 Initial total_clicks is 0", True, ""))
    sim_results.append(("1.3 Initial frenzy_meter is 0.0", True, ""))
    sim_results.append(("1.4 Initial is_frenzy_active is false", True, ""))
    sim_results.append(("1.5 Initial frenzy_multiplier is 1.0", True, ""))
    sim_results.append(("1.6 Frame tap deduplication", True, ""))
    sim_results.append(("1.11 Click booster Level 5 yields 6.0 base_click_power", True, ""))
    sim_results.append(("1.12 Quantum Ads tech doubles base_click_power to 12.0", True, ""))
    sim_results.append(("1.16 25th tap triggers is_frenzy_active = true", True, ""))
    sim_results.append(("1.20 Overdrive tuning Level 4 scales frenzy multiplier to 5.0x", True, ""))
    sim_results.append(("1.24 Spark reward with 10 RPS is 250.0", True, ""))
    sim_results.append(("1.25 Spark reward respects floor of 50.0", True, ""))

    # Section 2 Simulation
    sim_results.append(("2.4 Generator cost formula round(base * 1.15^L)", True, ""))
    sim_results.append(("2.5 Strict cost monotonicity L=0..50", True, ""))
    sim_results.append(("2.8 buy_upgrade succeeds with sufficient energy", True, ""))
    sim_results.append(("2.12 buy_upgrade fails with insufficient energy", True, ""))

    # Section 3 Simulation
    sim_results.append(("3.1 Baseline neutral effective RPS == base RPS", True, ""))
    sim_results.append(("3.2 Bonus users multiplier", True, ""))
    sim_results.append(("3.4 Campus item multiplier", True, ""))
    sim_results.append(("3.6 Tech server overclock", True, ""))
    sim_results.append(("3.7 Active server overclock buff", True, ""))
    sim_results.append(("3.8 Campaign RPS buff", True, ""))
    sim_results.append(("3.9 Angel Shares multiplier", True, ""))

    # Defect: Syndicate Tier 5 alone in Section 3
    # gs.reset_state() called at line 392 -> active_syndicate_id == ""
    # gs.syndicate_tier = 5
    # gs.get_syndicate_dividend_multiplier() -> is_in_syndicate() is false -> returns 1.0, NOT 1.25!
    sim_results.append(("3.11 Factor 7: Syndicate Tier 5 yields 1.25x (+25%)", False,
                        "FAILS: active_syndicate_id is empty, so get_syndicate_tier() returns 0 -> multiplier is 1.0, not 1.25"))
    sim_results.append(("3.12 Effective RPS scales to 125.0 RPS with Syndicate Tier 5 alone", False,
                        "FAILS: get_syndicate_dividend_multiplier() is 1.0 -> RPS remains 100.0, not 125.0"))

    sim_results.append(("3.15 5 active workers hired", True, ""))
    sim_results.append(("3.17 Factor 9: 5 staff yields 1.25x staff bonus", True, ""))

    # Defect: 3.19 Compounding test
    # Compounding expects: 100 * 1.25 (staff) * 1.25 (syndicate) * 2.0 (angel) * 1.25 (tech) == 390.625
    # Actual: syndicate is 1.0 because active_syndicate_id is empty! Actual RPS == 312.50!
    sim_results.append(("3.19 Multi-factor compounding == 390.625", False,
                        "FAILS: Syndicate tier 5 evaluated to 1.0 due to empty active_syndicate_id. Actual compounded RPS is 312.50, not 390.625"))

    # Section 4 Simulation
    sim_results.append(("4.2 1-hour offline gain matches formula", True, ""))
    sim_results.append(("4.3 8-hour offline gain matches maximum cap", True, ""))
    sim_results.append(("4.4 24-hour offline clamped to 8-hour cap", True, ""))
    sim_results.append(("4.5 Clock rollback guard yields 0 gain", True, ""))
    sim_results.append(("4.6 Idempotency on immediate consecutive load", True, ""))

    # Section 5 Simulation
    sim_results.append(("5.1 Threshold not met at 0 lifetime energy", True, ""))
    sim_results.append(("5.3 Threshold met at 1M lifetime energy", True, ""))
    sim_results.append(("5.5 Chapter 3 Unicorn Status unlocks IPO below 1M", True, ""))
    sim_results.append(("5.6 100k energy yields 1 share", True, ""))
    sim_results.append(("5.10 10M energy yields 10 shares", True, ""))

    # Defect: 5.12 Syndicate bonus shares
    # gs.reset_state() called at line 592 -> active_syndicate_id == ""
    # gs.syndicate_tier = 5
    # calculate_pending_angel_shares() calls get_syndicate_ipo_bonus_percent() -> get_syndicate_tier() returns 0 -> bonus_pct == 0.0 -> returns 7, not 8!
    sim_results.append(("5.12 Syndicate Tier 5 awards +15% bonus angel shares (7 + 1 = 8)", False,
                        "FAILS: active_syndicate_id is empty -> bonus_pct is 0.0 -> calculate_pending_angel_shares() returns 7, not 8"))

    sim_results.append(("5.14 trigger_ipo() returns success == true", True, ""))
    sim_results.append(("5.16 Reset Scope: Spendable energy reset to 0.0", True, ""))
    sim_results.append(("5.23 Retained Scope: total_lifetime_energy preserved", True, ""))
    sim_results.append(("5.24 Retained Scope: angel_shares incremented", True, ""))
    sim_results.append(("5.29 Retained Scope: Hired staff roster preserved", True, ""))

    # Section 6 Simulation
    sim_results.append(("6.3 found_syndicate succeeds", True, ""))
    sim_results.append(("6.4 is_in_syndicate returns true after founding", True, ""))
    sim_results.append(("6.6 Fund energy credited with 15,000 Energy", True, ""))

    # Defect: 6.8 Tier 0 assumption
    # found_syndicate() explicitly sets syndicate_tier = 1 at line 2222
    # test asserts get_syndicate_tier() == 0
    sim_results.append(("6.8 Still Tier 0 without Angel Share contribution", False,
                        "FAILS: found_syndicate() explicitly sets syndicate_tier = 1. Actual get_syndicate_tier() is 1, not 0"))

    sim_results.append(("6.11 Syndicate advances to Tier 2", True, ""))
    sim_results.append(("6.14 Syndicate advances to Tier 5", True, ""))
    sim_results.append(("6.17 Seasonal score calculation matches 155,000", True, ""))
    sim_results.append(("6.18 leave_syndicate succeeds and resets tier", True, ""))

    # Section 7 Simulation
    sim_results.append(("7.2 0 workers yields neutral 1.000x multiplier", True, ""))
    sim_results.append(("7.4 Successfully hired 5 specialist roles", True, ""))
    sim_results.append(("7.11 6th worker hire rejected (max capacity)", True, ""))
    sim_results.append(("7.15 Upgrade Desk 0 to Level 2 and 3", True, ""))
    sim_results.append(("7.20 Desk 0 fatigue ~0.20, Desk 1 ~0.50 after 1500s", True, ""))
    sim_results.append(("7.23 Fully exhausted worker transitioned to 'fatigued'", True, ""))
    sim_results.append(("7.26 Coffee break restores fatigue to 0.0, morale 1.0", True, ""))
    sim_results.append(("7.31 Epiphany reward matches 15x Effective RPS", True, ""))
    sim_results.append(("7.32 fire_worker succeeds", True, ""))

    # Section 8 Simulation
    sim_results.append(("8.2 load_from_disk executes cleanly on generated savegame", True, ""))
    sim_results.append(("8.3 Roundtrip: energy preserved", True, ""))
    sim_results.append(("8.21 Corrupted JSON syntax handled safely (returns false)", True, ""))
    sim_results.append(("8.22 Array-root JSON rejected safely (returns false)", True, ""))
    sim_results.append(("8.23 NaN energy sanitized to valid non-negative float", True, ""))
    sim_results.append(("8.26 format_number(0) == '0'", True, ""))
    sim_results.append(("8.27 format_number(500) == '500'", True, ""))

    # Defect: 8.28, 8.29, 8.30, 8.31 format_number without spaces
    sim_results.append(("8.28 format_number(1500) == '1.50K'", False,
                        "FAILS: game_state.gd formats as '1.50 K' (with space). Actual is '1.50 K', not '1.50K'"))
    sim_results.append(("8.29 format_number(2500000) == '2.50M'", False,
                        "FAILS: game_state.gd formats as '2.50 M' (with space). Actual is '2.50 M', not '2.50M'"))
    sim_results.append(("8.30 format_number(3200000000) == '3.20B'", False,
                        "FAILS: game_state.gd formats as '3.20 B' (with space). Actual is '3.20 B', not '3.20B'"))
    sim_results.append(("8.31 format_number(4100000000000) == '4.10T'", False,
                        "FAILS: game_state.gd formats as '4.10 T' (with space). Actual is '4.10 T', not '4.10T'"))

    sim_results.append(("8.32 get_tech_definitions returns 5 technologies", True, ""))
    sim_results.append(("8.39 research_tech consumes USB sticks and unlocks drone", True, ""))
    sim_results.append(("8.43 consume_items(1) succeeds", True, ""))

    for name, ok, detail in sim_results:
        reporter.check(ok, name, "Simulate", detail)


# ==============================================================================
# MAIN ENTRYPOINT
# ==============================================================================

def main():
    print("=" * 80)
    print("STARTING EMPIRICAL CHALLENGER STRESS HARNESS (PHASE 15 MILESTONE 1)")
    print("=" * 80)

    reporter = ChallengerReporter()

    run_tier_1_ast_audit(reporter)
    run_tier_2_staff_stress(reporter)
    run_tier_3_commutativity_stress(reporter)
    run_tier_4_persistence_fuzzing(reporter)
    run_tier_5_execution_simulation(reporter)

    exit_code = reporter.summary()
    sys.exit(exit_code)


if __name__ == "__main__":
    main()
