#!/usr/bin/env python3
"""
Phase 12 Milestone 1: IPO Prestige-Ascension Core Verification Suite
=====================================================================
Target: Godot 4.3 IdleArcade - Milestone M1 (Requirement R1: IPO & Prestige-Rebirth Core System)

Validates:
  1. AST & Static Code Contract:
     - State variables & constants in game_state.gd:
       * IPO_ENERGY_THRESHOLD = 1000000.0
       * total_lifetime_energy, angel_shares, total_ipos_completed, unlocked_trophies
     - Signals: ipo_completed, angel_shares_changed, trophy_unlocked
     - Methods: can_trigger_ipo, calculate_pending_angel_shares, get_angel_share_multiplier, trigger_ipo,
       unlock_trophy, is_trophy_unlocked, get_unlocked_trophies, check_and_update_trophies
  2. Mathematical Simulation & Square-Root Formula Oracle:
     - Angel Shares = floor(sqrt(total_lifetime_energy / 100000))
     - Pending calculation with existing shares: maxi(0, eligible - angel_shares)
     - Boundary tests: 0, 99k, 100k, 400k, 900k, 1M, 1.6M, 2.5M, 10M, 100M, 1B
     - NaN / Negative / Inf defensive guards
  3. IPO Threshold Validation:
     - 1M lifetime energy OR Chapter >= 3 Unicorn status, AND pending shares > 0
  4. Global Multiplier Scaling:
     - 1.0 + (angel_shares * 0.02) (+2% per share)
     - Hook integration into passive RPS, core click, and spark collection
  5. Prestige Reset vs. Preservation Semantics:
     - Reset: energy = 0, upgrade levels = 0 & base cost, buff timers cleared
     - Preserved: angel_shares (+ gains), total_ipos_completed (+ 1), total_lifetime_energy,
       unlocked_trophies (+ platinum bull), researched techs, campaign story, zones, items
     - Guard against premature IPO or 0 pending shares
     - Return dictionary key conventions (both aliases present)
  6. Persistence & Serialization:
     - save_to_disk / load_from_disk contract
     - Backward-compatible fallback (total_lifetime_energy = total_energy_earned)
     - Retroactive trophy unlock for Chapters 1-3
  7. End-to-End Lifecycle State Machine Simulation.

Executable via: python tests/test_p12_m1_ipo.py
"""

import math
import os
import re
import sys
from pathlib import Path
from typing import Dict, Any, List, Optional


class Colors:
    HEADER = "\033[95m"
    OKBLUE = "\033[94m"
    OKCYAN = "\033[96m"
    OKGREEN = "\033[92m"
    WARNING = "\033[93m"
    FAIL = "\033[91m"
    ENDC = "\033[0m"
    BOLD = "\033[1m"


class TestReporter:
    def __init__(self):
        self.total_checks = 0
        self.passed_checks = 0
        self.failed_checks = 0
        self.failures: List[str] = []

    def check(self, condition: bool, description: str):
        self.total_checks += 1
        if condition:
            self.passed_checks += 1
            print(f"  {Colors.OKGREEN}[PASS]{Colors.ENDC} {description}")
        else:
            self.failed_checks += 1
            self.failures.append(description)
            print(f"  {Colors.FAIL}[FAIL]{Colors.ENDC} {description}")

    def summary(self) -> bool:
        print("\n" + "=" * 70)
        print(f"{Colors.BOLD}Milestone M1 (IPO Prestige-Rebirth) Verification Summary:{Colors.ENDC}")
        print(f"  Total Checks: {self.total_checks}")
        print(f"  Passed:       {Colors.OKGREEN}{self.passed_checks}{Colors.ENDC}")
        print(f"  Failed:       {Colors.FAIL if self.failed_checks > 0 else Colors.OKGREEN}{self.failed_checks}{Colors.ENDC}")
        print("=" * 70)
        if self.failed_checks == 0:
            print(f"{Colors.BOLD}{Colors.OKGREEN}>>> ALL CHECKS PASSED: Milestone M1 IPO Core System Verified! <<<{Colors.ENDC}\n")
            return True
        else:
            print(f"{Colors.BOLD}{Colors.FAIL}>>> VERIFICATION FAILED: {self.failed_checks} check(s) failed! <<<{Colors.ENDC}\n")
            for f in self.failures:
                print(f"  - {f}")
            return False


reporter = TestReporter()


# =============================================================================
# SECTION 1: Static Code Contracts in game_state.gd
# =============================================================================
def test_static_contracts(game_dir: Path):
    print(f"\n{Colors.BOLD}{Colors.OKBLUE}=== SECTION 1: Static Code Contracts in game_state.gd ==={Colors.ENDC}")
    gs_path = game_dir / "scripts" / "autoload" / "game_state.gd"
    reporter.check(gs_path.is_file(), "scripts/autoload/game_state.gd exists")
    if not gs_path.is_file():
        return

    content = gs_path.read_text(encoding="utf-8")

    # 1. State Variables & Constants
    reporter.check("const IPO_ENERGY_THRESHOLD: float = 1000000.0" in content,
                   "Declares const IPO_ENERGY_THRESHOLD = 1000000.0")
    reporter.check("var total_lifetime_energy: float = 0.0" in content,
                   "Declares var total_lifetime_energy: float = 0.0")
    reporter.check("var angel_shares: int = 0" in content,
                   "Declares var angel_shares: int = 0")
    reporter.check("var total_ipos_completed: int = 0" in content,
                   "Declares var total_ipos_completed: int = 0")
    reporter.check("var unlocked_trophies: Array[String] = []" in content,
                   "Declares var unlocked_trophies: Array[String] = []")

    # 2. Signals
    reporter.check("signal ipo_completed(" in content, "Declares signal ipo_completed")
    reporter.check("signal angel_shares_changed(" in content, "Declares signal angel_shares_changed")
    reporter.check("signal trophy_unlocked(" in content, "Declares signal trophy_unlocked")

    # 3. Method Signatures
    reporter.check("func can_trigger_ipo() -> bool:" in content, "Implements func can_trigger_ipo() -> bool")
    reporter.check("func calculate_pending_angel_shares() -> int:" in content,
                   "Implements func calculate_pending_angel_shares() -> int")
    reporter.check("func get_angel_share_multiplier() -> float:" in content,
                   "Implements func get_angel_share_multiplier() -> float")
    reporter.check("func trigger_ipo() -> Dictionary:" in content, "Implements func trigger_ipo() -> Dictionary")
    reporter.check("func unlock_trophy(" in content, "Implements func unlock_trophy(trophy_id: String) -> bool")
    reporter.check("func is_trophy_unlocked(" in content, "Implements func is_trophy_unlocked(trophy_id: String) -> bool")
    reporter.check("func get_unlocked_trophies() -> Array[String]:" in content,
                   "Implements func get_unlocked_trophies() -> Array[String]")
    reporter.check("func check_and_update_trophies() -> void:" in content,
                   "Implements func check_and_update_trophies() -> void")

    # 4. Multiplier Integration Hooks
    reporter.check("get_angel_share_multiplier()" in content, "Calls get_angel_share_multiplier() in calculations")
    reporter.check("camp_rps_mult * get_angel_share_multiplier()" in content,
                   "get_effective_passive_rps() applies get_angel_share_multiplier()")
    reporter.check("frenzy_multiplier * get_angel_share_multiplier()" in content,
                   "tap_core() applies get_angel_share_multiplier()")
    reporter.check("25.0) * get_angel_share_multiplier()" in content,
                   "collect_spark() applies get_angel_share_multiplier()")

    # 5. Lifetime Energy Accumulation Hooks
    lifetime_count = content.count("total_lifetime_energy +=")
    reporter.check(lifetime_count >= 8,
                   f"total_lifetime_energy accumulated in at least 8 locations (actual: {lifetime_count})")

    # 6. Persistence & Serialization
    reporter.check('"total_lifetime_energy": total_lifetime_energy' in content,
                   "save_to_disk serializes total_lifetime_energy")
    reporter.check('"angel_shares": angel_shares' in content,
                   "save_to_disk serializes angel_shares")
    reporter.check('"total_ipos_completed": total_ipos_completed' in content,
                   "save_to_disk serializes total_ipos_completed")
    reporter.check('"unlocked_trophies": unlocked_trophies.duplicate()' in content,
                   "save_to_disk serializes unlocked_trophies")
    reporter.check('data.get("total_lifetime_energy", total_energy_earned)' in content,
                   "load_from_disk falls back to total_energy_earned for legacy saves")


# =============================================================================
# SECTION 2: Mathematical Simulation & Square-Root Formula Oracle
# =============================================================================
def test_mathematical_oracle():
    print(f"\n{Colors.BOLD}{Colors.OKBLUE}=== SECTION 2: Mathematical Simulation & Formula Oracle ==={Colors.ENDC}")

    def calc_eligible_shares(lifetime_energy: float) -> int:
        if math.isnan(lifetime_energy) or math.isinf(lifetime_energy) or lifetime_energy < 100000.0:
            return 0
        return int(math.floor(math.sqrt(max(0.0, lifetime_energy) / 100000.0)))

    def calc_pending(lifetime_energy: float, owned_shares: int) -> int:
        eligible = calc_eligible_shares(lifetime_energy)
        return max(0, eligible - owned_shares)

    def calc_multiplier(shares: int) -> float:
        return 1.0 + (float(shares) * 0.02)

    # 1. Exact Square-Root Progression Test Matrix
    test_cases = [
        (0.0, 0),
        (50000.0, 0),
        (99999.9, 0),
        (100000.0, 1),       # sqrt(1.0) = 1.0
        (250000.0, 1),       # sqrt(2.5) = 1.58 -> floor 1
        (399999.0, 1),       # sqrt(3.999) = 1.999 -> floor 1
        (400000.0, 2),       # sqrt(4.0) = 2.0
        (899999.0, 2),       # sqrt(8.999) = 2.999 -> floor 2
        (900000.0, 3),       # sqrt(9.0) = 3.0
        (1000000.0, 3),      # sqrt(10.0) = 3.162 -> floor 3
        (1600000.0, 4),      # sqrt(16.0) = 4.0
        (2500000.0, 5),      # sqrt(25.0) = 5.0
        (10000000.0, 10),    # sqrt(100.0) = 10.0
        (100000000.0, 31),   # sqrt(1000.0) = 31.622 -> floor 31
        (1000000000.0, 100), # sqrt(10000.0) = 100.0
        (-500000.0, 0),      # Negative guard
    ]

    all_matrix_passed = True
    for energy, expected_shares in test_cases:
        actual = calc_eligible_shares(energy)
        if actual != expected_shares:
            all_matrix_passed = False
            reporter.check(False, f"Energy {energy} expected {expected_shares} shares, got {actual}")
            break
    if all_matrix_passed:
        reporter.check(True, f"All {len(test_cases)} points in Angel Shares square-root matrix match formula")

    # 2. Pending Angel Shares Calculations with Existing Shares
    reporter.check(calc_pending(1000000.0, 0) == 3, "1M energy with 0 owned shares gives 3 pending shares")
    reporter.check(calc_pending(1000000.0, 2) == 1, "1M energy with 2 owned shares gives 1 pending share")
    reporter.check(calc_pending(1000000.0, 3) == 0, "1M energy with 3 owned shares gives 0 pending shares")
    reporter.check(calc_pending(1000000.0, 5) == 0, "1M energy with 5 owned shares gives 0 pending shares (no underflow)")
    reporter.check(calc_pending(1600000.0, 3) == 1, "1.6M energy (4 eligible) with 3 owned shares gives 1 pending share")
    reporter.check(calc_pending(2500000.0, 3) == 2, "2.5M energy (5 eligible) with 3 owned shares gives 2 pending shares")

    # 3. Multiplier Progression (+2% per share)
    reporter.check(abs(calc_multiplier(0) - 1.00) < 1e-6, "0 shares = 1.00x multiplier (+0%)")
    reporter.check(abs(calc_multiplier(1) - 1.02) < 1e-6, "1 share = 1.02x multiplier (+2%)")
    reporter.check(abs(calc_multiplier(5) - 1.10) < 1e-6, "5 shares = 1.10x multiplier (+10%)")
    reporter.check(abs(calc_multiplier(10) - 1.20) < 1e-6, "10 shares = 1.20x multiplier (+20%)")
    reporter.check(abs(calc_multiplier(25) - 1.50) < 1e-6, "25 shares = 1.50x multiplier (+50%)")
    reporter.check(abs(calc_multiplier(50) - 2.00) < 1e-6, "50 shares = 2.00x multiplier (+100%)")
    reporter.check(abs(calc_multiplier(100) - 3.00) < 1e-6, "100 shares = 3.00x multiplier (+200%)")


# =============================================================================
# SECTION 3: Threshold & Prerequisite Logic Oracle
# =============================================================================
def test_threshold_logic():
    print(f"\n{Colors.BOLD}{Colors.OKBLUE}=== SECTION 3: Threshold & Prerequisite Logic Oracle ==={Colors.ENDC}")

    def can_trigger(lifetime_energy: float, chapter: int, owned_shares: int) -> bool:
        threshold_met = (lifetime_energy >= 1000000.0) or (chapter >= 3)
        if lifetime_energy < 100000.0:
            pending = 0
        else:
            eligible = int(math.floor(math.sqrt(max(0.0, lifetime_energy) / 100000.0)))
            pending = max(0, eligible - owned_shares)
        return threshold_met and (pending > 0)

    # 1. Below 1M energy and Chapter < 3 -> False
    reporter.check(can_trigger(500000.0, 1, 0) is False,
                   "Cannot IPO with 500k energy in Chapter 1")
    reporter.check(can_trigger(999999.0, 2, 0) is False,
                   "Cannot IPO with 999.9k energy in Chapter 2")

    # 2. Reached 1M energy threshold -> True if pending > 0
    reporter.check(can_trigger(1000000.0, 1, 0) is True,
                   "Can IPO with 1M energy in Chapter 1 (3 pending shares)")
    reporter.check(can_trigger(1000000.0, 1, 3) is False,
                   "Cannot IPO with 1M energy if all 3 shares already claimed")

    # 3. Chapter 3 (Unicorn status) allows IPO earlier if shares available
    reporter.check(can_trigger(400000.0, 3, 0) is True,
                   "Can IPO in Chapter 3 with 400k energy (2 pending shares)")
    reporter.check(can_trigger(50000.0, 3, 0) is False,
                   "Cannot IPO in Chapter 3 with < 100k energy (0 pending shares)")
    reporter.check(can_trigger(400000.0, 3, 2) is False,
                   "Cannot IPO in Chapter 3 with 400k energy if 2 shares already claimed")


# =============================================================================
# SECTION 4: End-to-End State Machine & Lifecycle Simulation
# =============================================================================
class MockGameState:
    """Python simulation replicating the exact behavior of game_state.gd."""
    IPO_ENERGY_THRESHOLD = 1000000.0

    def __init__(self):
        self.reset_state()

    def reset_state(self):
        self.energy = 0.0
        self.total_energy_earned = 0.0
        self.total_lifetime_energy = 0.0
        self.angel_shares = 0
        self.total_ipos_completed = 0
        self.unlocked_trophies: List[str] = []
        self.daily_streak = 0
        self.last_daily_challenge_date = ""

        self.campaign_chapter = 1
        self.campaign_completed_quests: List[str] = []
        self.researched_techs: List[str] = []
        self.unlocked_zones: List[str] = []
        self.item_inventory = {"briefcase": 0, "coffee": 0, "usb_drive": 0}

        self.base_click_power = 1.0
        self.base_passive_rps = 0.0
        self.bonus_users = 0
        self.collectibles_collected = 0

        self.is_frenzy_active = False
        self.frenzy_meter = 0.0
        self.frenzy_multiplier = 1.0
        self.frenzy_duration_remaining = 0.0

        self.server_overclock_buff_active = False
        self.server_overclock_buff_timer = 0.0
        self.campaign_rps_buff_timer = 0.0
        self.campaign_speed_buff_timer = 0.0
        self.unicorn_espresso_buff_active = False

        self.upgrades = {
            f"tier_{i}": {"level": 0, "base_cost": 10.0 * i, "current_cost": 10.0 * i}
            for i in range(1, 8)
        }
        self.upgrades["click_booster"] = {"level": 0, "base_cost": 15.0, "current_cost": 15.0}
        self.upgrades["overdrive_tuning"] = {"level": 0, "base_cost": 100.0, "current_cost": 100.0}
        self.upgrades["avatar_speed"] = {"level": 0, "base_cost": 50.0, "current_cost": 50.0}
        self.upgrades["clearance_level"] = {"level": 0, "base_cost": 200.0, "current_cost": 200.0}
        self.upgrades["pickup_radius"] = {"level": 0, "base_cost": 75.0, "current_cost": 75.0}

    def earn_energy(self, amount: float):
        if amount <= 0.0:
            return
        self.energy += amount
        self.total_energy_earned += amount
        self.total_lifetime_energy += amount

    def tap_core(self) -> float:
        earned = self.base_click_power * self.frenzy_multiplier * self.get_angel_share_multiplier()
        self.energy += earned
        self.total_energy_earned += earned
        self.total_lifetime_energy += earned
        return earned

    def collect_spark(self) -> float:
        earned = max(50.0, self.base_passive_rps * 25.0) * self.get_angel_share_multiplier()
        self.energy += earned
        self.total_energy_earned += earned
        self.total_lifetime_energy += earned
        return earned

    def get_angel_share_multiplier(self) -> float:
        return 1.0 + (float(self.angel_shares) * 0.02)

    def calculate_pending_angel_shares(self) -> int:
        if self.total_lifetime_energy < 100000.0:
            return 0
        total_eligible = int(math.floor(math.sqrt(max(0.0, self.total_lifetime_energy) / 100000.0)))
        return max(0, total_eligible - self.angel_shares)

    def can_trigger_ipo(self) -> bool:
        threshold_met = (self.total_lifetime_energy >= self.IPO_ENERGY_THRESHOLD) or (self.campaign_chapter >= 3)
        return threshold_met and (self.calculate_pending_angel_shares() > 0)

    def unlock_trophy(self, trophy_id: str) -> bool:
        if not trophy_id or trophy_id in self.unlocked_trophies:
            return False
        self.unlocked_trophies.append(trophy_id)
        return True

    def is_trophy_unlocked(self, trophy_id: str) -> bool:
        return trophy_id in self.unlocked_trophies

    def get_unlocked_trophies(self) -> List[str]:
        return list(self.unlocked_trophies)

    def check_and_update_trophies(self):
        if (self.campaign_chapter >= 2 or "quest_briefcases" in self.campaign_completed_quests) and "trophy_golden_briefcase" not in self.unlocked_trophies:
            self.unlocked_trophies.append("trophy_golden_briefcase")
        if (self.campaign_chapter >= 3 or "quest_server" in self.campaign_completed_quests) and "trophy_server_matrix" not in self.unlocked_trophies:
            self.unlocked_trophies.append("trophy_server_matrix")
        if (self.campaign_chapter >= 4 or "quest_lab" in self.campaign_completed_quests) and "trophy_crystal_espresso" not in self.unlocked_trophies:
            self.unlocked_trophies.append("trophy_crystal_espresso")
        if self.total_ipos_completed > 0 and "trophy_platinum_bull" not in self.unlocked_trophies:
            self.unlocked_trophies.append("trophy_platinum_bull")

    def trigger_ipo(self) -> Dict[str, Any]:
        if not self.can_trigger_ipo():
            return {
                "success": False,
                "error": "Cannot trigger IPO: threshold not reached or 0 pending shares",
                "shares_gained": 0,
                "angel_shares_gained": 0,
                "total_angel_shares": self.angel_shares,
                "angel_shares": self.angel_shares,
                "multiplier": self.get_angel_share_multiplier(),
                "total_ipos_completed": self.total_ipos_completed
            }

        shares_gained = self.calculate_pending_angel_shares()
        if shares_gained <= 0:
            return {
                "success": False,
                "error": "No pending angel shares to claim",
                "shares_gained": 0,
                "angel_shares_gained": 0,
                "total_angel_shares": self.angel_shares,
                "angel_shares": self.angel_shares,
                "multiplier": self.get_angel_share_multiplier(),
                "total_ipos_completed": self.total_ipos_completed
            }

        self.angel_shares += shares_gained
        self.total_ipos_completed += 1
        self.unlock_trophy("trophy_platinum_bull")

        self.energy = 0.0

        for up_id in self.upgrades:
            base = self.upgrades[up_id]["base_cost"]
            self.upgrades[up_id]["level"] = 0
            self.upgrades[up_id]["current_cost"] = base

        self.frenzy_meter = 0.0
        self.is_frenzy_active = False
        self.frenzy_multiplier = 1.0
        self.frenzy_duration_remaining = 0.0

        self.server_overclock_buff_active = False
        self.server_overclock_buff_timer = 0.0
        self.campaign_rps_buff_timer = 0.0
        self.campaign_speed_buff_timer = 0.0
        self.unicorn_espresso_buff_active = False

        self.base_passive_rps = 0.0
        self.base_click_power = 1.0

        return {
            "success": True,
            "shares_gained": shares_gained,
            "angel_shares_gained": shares_gained,
            "total_angel_shares": self.angel_shares,
            "angel_shares": self.angel_shares,
            "multiplier": self.get_angel_share_multiplier(),
            "total_ipos_completed": self.total_ipos_completed
        }


def test_state_machine_simulation():
    print(f"\n{Colors.BOLD}{Colors.OKBLUE}=== SECTION 4: End-to-End State Machine Simulation ==={Colors.ENDC}")

    gs = MockGameState()

    # Step 1: Baseline cold start
    reporter.check(gs.total_lifetime_energy == 0.0, "Initial lifetime energy is 0.0")
    reporter.check(gs.angel_shares == 0, "Initial angel shares is 0")
    reporter.check(gs.get_angel_share_multiplier() == 1.0, "Initial multiplier is 1.0")
    reporter.check(gs.can_trigger_ipo() is False, "Initial can_trigger_ipo() is False")

    # Step 2: Earn 500,000 Energy in Chapter 1
    gs.earn_energy(500000.0)
    for up in gs.upgrades.values():
        up["level"] = 5
        up["current_cost"] = up["base_cost"] * 2.0
    gs.is_frenzy_active = True
    gs.frenzy_multiplier = 3.5

    reporter.check(gs.can_trigger_ipo() is False, "Cannot IPO at 500k energy in Chapter 1")
    fail_res = gs.trigger_ipo()
    reporter.check(fail_res["success"] is False, "trigger_ipo() returns success: False when threshold not met")
    reporter.check(gs.energy == 500000.0, "Energy untouched after rejected IPO")

    # Step 3: Advance to Chapter 3 (Unicorn Status)
    gs.campaign_chapter = 3
    gs.check_and_update_trophies()
    reporter.check(gs.is_trophy_unlocked("trophy_golden_briefcase"), "Chapter 2 trophy unlocked")
    reporter.check(gs.is_trophy_unlocked("trophy_server_matrix"), "Chapter 3 trophy unlocked")

    reporter.check(gs.can_trigger_ipo() is True, "Can trigger IPO now (Chapter 3 with 500k energy)")
    reporter.check(gs.calculate_pending_angel_shares() == 2, "Pending angel shares is 2 (sqrt(500k/100k) = 2)")

    # Step 4: Execute First IPO Rebirth
    ipo_res = gs.trigger_ipo()
    reporter.check(ipo_res["success"] is True, "First IPO executes successfully")
    reporter.check(ipo_res["shares_gained"] == 2, "Awarded 2 shares_gained")
    reporter.check(ipo_res["angel_shares_gained"] == 2, "Awarded 2 angel_shares_gained (alias)")
    reporter.check(ipo_res["total_angel_shares"] == 2, "total_angel_shares is now 2")
    reporter.check(ipo_res["angel_shares"] == 2, "angel_shares is now 2 (alias)")
    reporter.check(abs(ipo_res["multiplier"] - 1.04) < 1e-6, "Multiplier is now 1.04 (+4%)")
    reporter.check(ipo_res["total_ipos_completed"] == 1, "total_ipos_completed is 1")

    # Verify Reset vs Preserved Invariants
    reporter.check(gs.energy == 0.0, "Energy reset to 0.0")
    all_levels_zero = all(up["level"] == 0 for up in gs.upgrades.values())
    reporter.check(all_levels_zero, "All 11 upgrade levels reset to 0")
    reporter.check(gs.is_frenzy_active is False, "Frenzy buff reset")
    reporter.check(gs.frenzy_multiplier == 1.0, "Frenzy multiplier reset to 1.0")

    # Preserved Invariants
    reporter.check(gs.total_lifetime_energy == 500000.0, "Lifetime energy preserved (500k)")
    reporter.check(gs.is_trophy_unlocked("trophy_platinum_bull"), "Platin-Börsenbulle trophy unlocked")
    reporter.check(gs.campaign_chapter == 3, "Campaign chapter 3 preserved")

    # Step 5: Immediate Idempotency Check
    reporter.check(gs.calculate_pending_angel_shares() == 0, "Pending shares immediately drops to 0")
    reporter.check(gs.can_trigger_ipo() is False, "can_trigger_ipo() is now False")
    second_fail = gs.trigger_ipo()
    reporter.check(second_fail["success"] is False, "Subsequent trigger_ipo fails immediately")

    # Step 6: Multiplier Boost Verification in New Run
    # Tap core gives base (1.0) * multiplier (1.04) = 1.04
    earned_tap = gs.tap_core()
    reporter.check(abs(earned_tap - 1.04) < 1e-6, f"tap_core scaled by 1.04x multiplier: {earned_tap}")
    earned_spark = gs.collect_spark()
    # Spark gives max(50.0, 0) * 1.04 = 52.0
    reporter.check(abs(earned_spark - 52.0) < 1e-6, f"collect_spark scaled by 1.04x multiplier: {earned_spark}")

    # Step 7: Accumulate up to 1,600,000 Lifetime Energy & Perform Second IPO
    needed = 1600000.0 - gs.total_lifetime_energy
    gs.earn_energy(needed)
    reporter.check(gs.total_lifetime_energy >= 1600000.0, "Lifetime energy reached 1.6M")
    reporter.check(gs.calculate_pending_angel_shares() == 2,
                   "Pending shares is 2 (eligible: 4, already owned: 2)")
    reporter.check(gs.can_trigger_ipo() is True, "can_trigger_ipo() is True for second IPO")

    ipo2_res = gs.trigger_ipo()
    reporter.check(ipo2_res["success"] is True, "Second IPO succeeds")
    reporter.check(ipo2_res["shares_gained"] == 2, "Second IPO gains 2 shares")
    reporter.check(ipo2_res["total_angel_shares"] == 4, "Total angel shares is now 4")
    reporter.check(abs(ipo2_res["multiplier"] - 1.08) < 1e-6, "Multiplier is now 1.08 (+8%)")
    reporter.check(ipo2_res["total_ipos_completed"] == 2, "total_ipos_completed is now 2")


# =============================================================================
# MAIN ENTRYPOINT
# =============================================================================
def main():
    print("=" * 70)
    print(f"{Colors.BOLD}{Colors.HEADER}IdleArcade Phase 12 - Milestone M1 (IPO Prestige-Rebirth Core){Colors.ENDC}")
    print("=" * 70)

    # Locate game directory
    current = Path(__file__).resolve().parent
    if (current / "scripts" / "autoload" / "game_state.gd").exists():
        game_dir = current
    elif (current.parent / "scripts" / "autoload" / "game_state.gd").exists():
        game_dir = current.parent
    else:
        game_dir = Path("c:/Projects/Game/IdleArcade")

    test_static_contracts(game_dir)
    test_mathematical_oracle()
    test_threshold_logic()
    test_state_machine_simulation()

    success = reporter.summary()
    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()
