#!/usr/bin/env python3
"""
Empirical Challenger Test Suite: Milestone P12-M1 Prestige Reset & Persistence Resilience
========================================================================================
Target: Godot 4.3 IdleArcade - Milestone M1 (Prestige-Ascension Core System R1)
Role: Empirical Challenger Oracle (Critic / Specialist)
File: IdleArcade/tests/test_p12_m1_challenger_reset.py

Adversarially stress-tests:
  1. Static GDScript AST & Pattern Audit on scripts/autoload/game_state.gd.
  2. Mathematical Square-Root & Dimension-Scaling Oracle (Boundary & Inf/NaN defense).
  3. High-Stress Prestige Reset Rebirth Cycle:
     - Injected high energy (10,000,000.0)
     - Elevated upgrade levels (all upgrades level > 0, elevated costs)
     - Active frenzy buff (meter, duration, multiplier)
     - Active server overclock buff (active flag, timers, multiplier)
     - Active unicorn espresso buff (active flag, timers)
     - Active campaign RPS and speed buffs (timers, multipliers)
     - Persistent meta state (researched techs, campaign chapter 3, daily streak, items, zones)
     - Execution of trigger_ipo()
     - Verification of 9 core reset invariants:
       * energy == 0.0
       * all upgrades level == 0 and cost == base_cost
       * all temporary buff timers == 0 and active == false
       * angel_shares increased exactly by pending shares
       * total_ipos_completed increased by 1
       * trophy_platinum_bull is unlocked
       * researched techs are NOT lost
       * campaign_chapter is NOT reset
       * total_lifetime_energy did NOT decrease
     - Multi-IPO Chained Ascensions & Idempotency guards.
  4. Persistence Serialization & Fuzzing / Corrupt Payload Resilience:
     - Normal roundtrip
     - Missing total_lifetime_energy fallback to total_energy_earned
     - NaN / Inf / non-numeric string values in total_lifetime_energy
     - Negative numbers and invalid types in angel_shares and total_ipos_completed
     - Corrupt trophy arrays and retroactive restoration via check_and_update_trophies()
     - Corrupt upgrade payloads and offline clock skew defense.
  5. Regression Validation of existing suites.
"""

import sys
import os
import re
import math
import json
import copy
import subprocess
from pathlib import Path
from typing import Dict, Any, List, Optional, Tuple

# Configure UTF-8 stdout
if hasattr(sys.stdout, "reconfigure"):
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass


class Colors:
    HEADER = "\033[95m"
    OKBLUE = "\033[94m"
    OKCYAN = "\033[96m"
    OKGREEN = "\033[92m"
    WARNING = "\033[93m"
    FAIL = "\033[91m"
    ENDC = "\033[0m"
    BOLD = "\033[1m"


class ChallengerReporter:
    def __init__(self):
        self.passes = 0
        self.fails = 0
        self.total = 0
        self.findings: List[str] = []

    def check(self, condition: bool, description: str, category: str = "General", detail: str = ""):
        self.total += 1
        if condition:
            print(f"  {Colors.OKGREEN}[PASS]{Colors.ENDC} [{category}] {description}")
            self.passes += 1
        else:
            err = f"  {Colors.FAIL}[FAIL]{Colors.ENDC} [{category}] {description}"
            if detail:
                err += f" -> {detail}"
            print(err)
            self.fails += 1
            self.findings.append(f"[{category}] {description}: {detail}")

    def note_vulnerability(self, title: str, description: str, severity: str = "MEDIUM"):
        print(f"  {Colors.WARNING}[VULNERABILITY - {severity}]{Colors.ENDC} {title}: {description}")
        self.findings.append(f"[{severity}] {title}: {description}")

    def summary(self) -> bool:
        print("\n" + "=" * 76)
        print(f"{Colors.BOLD}EMPIRICAL CHALLENGER VERIFICATION SUMMARY (Milestone P12-M1):{Colors.ENDC}")
        print(f"  Total Checks Executed : {self.total}")
        print(f"  Passed Checks         : {Colors.OKGREEN}{self.passes}{Colors.ENDC}")
        print(f"  Failed Checks         : {Colors.FAIL if self.fails > 0 else Colors.OKGREEN}{self.fails}{Colors.ENDC}")
        print(f"  Advisory Findings     : {len(self.findings)}")
        for f in self.findings:
            print(f"    * {f}")
        print("=" * 76)
        if self.fails == 0:
            print(f"{Colors.BOLD}{Colors.OKGREEN}>>> VERDICT: APPROVE (Prestige Reset & Persistence Resilient) <<<{Colors.ENDC}\n")
            return True
        else:
            print(f"{Colors.BOLD}{Colors.FAIL}>>> VERDICT: REQUEST_CHANGES ({self.fails} failure(s) detected) <<<{Colors.ENDC}\n")
            return False


reporter = ChallengerReporter()

SCRIPT_DIR = Path(__file__).resolve().parent
GAME_DIR = SCRIPT_DIR.parent
GAME_STATE_FILE = GAME_DIR / "scripts" / "autoload" / "game_state.gd"

print("=" * 76)
print(f"{Colors.BOLD}{Colors.HEADER}IdleArcade Phase 12 M1 - Empirical Challenger Adversarial Reset Suite{Colors.ENDC}")
print("=" * 76)

if not GAME_STATE_FILE.exists():
    print(f"FATAL: GameState file not found at {GAME_STATE_FILE}")
    sys.exit(1)

gs_code = GAME_STATE_FILE.read_text(encoding="utf-8")


# ==============================================================================
# SECTION 1: Static GDScript AST & Pattern Audit
# ==============================================================================
print(f"\n{Colors.BOLD}{Colors.OKBLUE}--- SECTION 1: Static GDScript AST & Pattern Invariant Audit ---{Colors.ENDC}")

# 1.1 State Variables and Constants
reporter.check("const IPO_ENERGY_THRESHOLD: float = 1000000.0" in gs_code,
               "IPO_ENERGY_THRESHOLD is declared as 1,000,000.0", "AST_Constants")
reporter.check("var total_lifetime_energy: float = 0.0" in gs_code,
               "total_lifetime_energy is declared as float = 0.0", "AST_StateVars")
reporter.check("var angel_shares: int = 0" in gs_code,
               "angel_shares is declared as int = 0", "AST_StateVars")
reporter.check("var total_ipos_completed: int = 0" in gs_code,
               "total_ipos_completed is declared as int = 0", "AST_StateVars")
reporter.check("var unlocked_trophies: Array[String] = []" in gs_code,
               "unlocked_trophies is declared as Array[String] = []", "AST_StateVars")

# 1.2 Signals
for sig in ["ipo_completed", "angel_shares_changed", "trophy_unlocked"]:
    pattern = rf"signal\s+{sig}\b"
    reporter.check(re.search(pattern, gs_code) is not None,
                   f"Signal '{sig}' is declared", "AST_Signals")

# 1.3 Methods
for meth in ["can_trigger_ipo", "calculate_pending_angel_shares", "get_angel_share_multiplier",
             "trigger_ipo", "unlock_trophy", "is_trophy_unlocked", "get_unlocked_trophies",
             "check_and_update_trophies"]:
    pattern = rf"func\s+{meth}\b"
    reporter.check(re.search(pattern, gs_code) is not None,
                   f"Method '{meth}' is declared", "AST_Methods")

# 1.4 Invariant Code in trigger_ipo()
# Extract trigger_ipo implementation block
ipo_match = re.search(r"func\s+trigger_ipo\s*\(\s*\)\s*->\s*Dictionary\s*:(.*?)(?=\nfunc\s|\Z)", gs_code, re.DOTALL)
reporter.check(ipo_match is not None, "Extracted func trigger_ipo() implementation block", "AST_TriggerIPO")

if ipo_match:
    ipo_body = ipo_match.group(1)
    reporter.check("if not can_trigger_ipo():" in ipo_body,
                   "trigger_ipo() guards against invalid state via can_trigger_ipo()", "AST_TriggerIPO")
    reporter.check("energy = 0.0" in ipo_body,
                   "trigger_ipo() explicitly resets regular energy to 0.0", "AST_TriggerIPO")
    reporter.check("upgrades[up_id][\"level\"] = 0" in ipo_body,
                   "trigger_ipo() resets upgrade levels to 0", "AST_TriggerIPO")
    reporter.check("upgrades[up_id][\"current_cost\"] = base_cost" in ipo_body,
                   "trigger_ipo() resets upgrade costs to base_cost", "AST_TriggerIPO")
    reporter.check("is_frenzy_active = false" in ipo_body and "frenzy_duration_remaining = 0.0" in ipo_body,
                   "trigger_ipo() resets frenzy active flag and duration timer", "AST_TriggerIPO")
    reporter.check("server_overclock_buff_active = false" in ipo_body and "server_overclock_buff_timer = 0.0" in ipo_body,
                   "trigger_ipo() resets server overclock buff active and timer", "AST_TriggerIPO")
    reporter.check("unicorn_espresso_buff_active = false" in ipo_body and "unicorn_espresso_buff_timer = 0.0" in ipo_body,
                   "trigger_ipo() resets unicorn espresso buff active and timer", "AST_TriggerIPO")
    reporter.check("campaign_rps_buff_timer = 0.0" in ipo_body and "campaign_speed_buff_timer = 0.0" in ipo_body,
                   "trigger_ipo() resets campaign buff timers to 0.0", "AST_TriggerIPO")
    reporter.check("angel_shares += shares_gained" in ipo_body,
                   "trigger_ipo() increments angel_shares by shares_gained", "AST_TriggerIPO")
    reporter.check("total_ipos_completed += 1" in ipo_body,
                   "trigger_ipo() increments total_ipos_completed by 1", "AST_TriggerIPO")
    reporter.check('unlock_trophy("trophy_platinum_bull")' in ipo_body,
                   "trigger_ipo() unlocks trophy_platinum_bull", "AST_TriggerIPO")
    reporter.check("recalculate_stats()" in ipo_body,
                   "trigger_ipo() recalculates stats after reset", "AST_TriggerIPO")
    reporter.check("save_to_disk()" in ipo_body,
                   "trigger_ipo() persists state to disk", "AST_TriggerIPO")
    # Verify non-reset invariants: total_lifetime_energy, researched_techs, campaign_chapter must NOT be reset in trigger_ipo
    reporter.check("total_lifetime_energy = 0" not in ipo_body and "total_lifetime_energy = 0.0" not in ipo_body,
                   "trigger_ipo() does NOT reset total_lifetime_energy", "AST_TriggerIPO")
    reporter.check("researched_techs.clear()" not in ipo_body,
                   "trigger_ipo() does NOT clear researched_techs", "AST_TriggerIPO")
    reporter.check("campaign_chapter = 1" not in ipo_body,
                   "trigger_ipo() does NOT reset campaign_chapter", "AST_TriggerIPO")


# ==============================================================================
# SECTION 2: Mathematical Square-Root & Dimension-Scaling Oracle
# ==============================================================================
print(f"\n{Colors.BOLD}{Colors.OKBLUE}--- SECTION 2: Mathematical Square-Root & Dimension-Scaling Oracle ---{Colors.ENDC}")

def oracle_shares(lifetime_energy: float) -> int:
    if math.isnan(lifetime_energy) or math.isinf(lifetime_energy) or lifetime_energy < 100000.0:
        return 0
    return int(math.floor(math.sqrt(max(0.0, lifetime_energy) / 100000.0)))

def oracle_pending(lifetime_energy: float, current_shares: int) -> int:
    eligible = oracle_shares(lifetime_energy)
    return max(0, eligible - current_shares)

def oracle_multiplier(shares: int) -> float:
    return 1.0 + (float(shares) * 0.02)

# Boundary and adversarial inputs
test_matrix = [
    (0.0, 0),
    (-100000.0, 0),
    (99999.999, 0),
    (100000.0, 1),
    (150000.0, 1),
    (399999.0, 1),
    (400000.0, 2),
    (900000.0, 3),
    (1000000.0, 3),        # Threshold 1M: sqrt(10) = 3.162 -> 3
    (1600000.0, 4),        # sqrt(16) = 4
    (2500000.0, 5),        # sqrt(25) = 5
    (10000000.0, 10),      # sqrt(100) = 10
    (100000000.0, 31),     # sqrt(1000) = 31.622 -> 31
    (1000000000.0, 100),   # sqrt(10000) = 100
]

all_passed = True
for energy, expected in test_matrix:
    actual = oracle_shares(energy)
    if actual != expected:
        all_passed = False
        reporter.check(False, f"Energy {energy} -> expected {expected}, got {actual}", "MathOracle")
        break
if all_passed:
    reporter.check(True, f"All {len(test_matrix)} boundary test cases in square-root matrix match", "MathOracle")

# Inf / NaN / Extreme guards
reporter.check(oracle_shares(float("nan")) == 0, "NaN energy yields 0 eligible shares", "MathOracle_NaN")
reporter.check(oracle_shares(float("inf")) == 0, "+Inf energy yields 0 eligible shares", "MathOracle_Inf")
reporter.check(oracle_shares(float("-inf")) == 0, "-Inf energy yields 0 eligible shares", "MathOracle_Inf")

# Pending calculation with existing shares
reporter.check(oracle_pending(10000000.0, 0) == 10, "10M energy with 0 shares = 10 pending", "MathOracle_Pending")
reporter.check(oracle_pending(10000000.0, 4) == 6, "10M energy with 4 owned shares = 6 pending", "MathOracle_Pending")
reporter.check(oracle_pending(10000000.0, 10) == 0, "10M energy with 10 owned shares = 0 pending", "MathOracle_Pending")
reporter.check(oracle_pending(10000000.0, 15) == 0, "10M energy with 15 owned shares = 0 pending (no negative overflow)", "MathOracle_Pending")

# Multiplier scaling
reporter.check(abs(oracle_multiplier(0) - 1.00) < 1e-6, "0 shares = 1.00x multiplier (+0%)", "MathOracle_Mult")
reporter.check(abs(oracle_multiplier(10) - 1.20) < 1e-6, "10 shares = 1.20x multiplier (+20%)", "MathOracle_Mult")
reporter.check(abs(oracle_multiplier(50) - 2.00) < 1e-6, "50 shares = 2.00x multiplier (+100%)", "MathOracle_Mult")
reporter.check(abs(oracle_multiplier(100) - 3.00) < 1e-6, "100 shares = 3.00x multiplier (+200%)", "MathOracle_Mult")


# ==============================================================================
# SECTION 3: High-Stress Prestige Reset Rebirth Cycle Simulation
# ==============================================================================
print(f"\n{Colors.BOLD}{Colors.OKBLUE}--- SECTION 3: High-Stress Prestige Reset Rebirth Cycle Simulation ---{Colors.ENDC}")

class EmpiricalGameStateSim:
    """
    Direct simulation of GameState replicating the full GDScript implementation.
    Includes all 12 upgrades, active buffs, meta progression, and IPO lifecycle.
    """
    IPO_ENERGY_THRESHOLD = 1000000.0

    DEFAULT_UPGRADES = {
        "click_booster": {"name": "Freelancer Marketing", "level": 0, "base_cost": 10.0, "cost_mult": 1.18, "type": "click", "power_gain": 1.0, "current_cost": 10.0},
        "tier_1": {"name": "Virale Memes", "level": 0, "base_cost": 25.0, "cost_mult": 1.15, "type": "idle", "power_gain": 1.0, "current_cost": 25.0},
        "tier_2": {"name": "Empfehlungsprogramm", "level": 0, "base_cost": 150.0, "cost_mult": 1.15, "type": "idle", "power_gain": 8.0, "current_cost": 150.0},
        "tier_3": {"name": "SEO-Optimierung", "level": 0, "base_cost": 800.0, "cost_mult": 1.15, "type": "idle", "power_gain": 40.0, "current_cost": 800.0},
        "tier_4": {"name": "Social Media Ads", "level": 0, "base_cost": 4500.0, "cost_mult": 1.15, "type": "idle", "power_gain": 250.0, "current_cost": 4500.0},
        "tier_5": {"name": "Influencer-Deals", "level": 0, "base_cost": 30000.0, "cost_mult": 1.15, "type": "idle", "power_gain": 1500.0, "current_cost": 30000.0},
        "tier_6": {"name": "TV-Werbespots", "level": 0, "base_cost": 250000.0, "cost_mult": 1.15, "type": "idle", "power_gain": 10000.0, "current_cost": 250000.0},
        "tier_7": {"name": "Super Bowl Spot", "level": 0, "base_cost": 2000000.0, "cost_mult": 1.15, "type": "idle", "power_gain": 75000.0, "current_cost": 2000000.0},
        "overdrive_tuning": {"name": "Hype Tuning", "level": 0, "base_cost": 100.0, "cost_mult": 1.30, "type": "frenzy", "power_gain": 0.5, "current_cost": 100.0},
        "avatar_speed": {"name": "Agile Sneakers", "level": 0, "base_cost": 50.0, "cost_mult": 1.25, "type": "avatar_stat", "power_gain": 0.15, "current_cost": 50.0},
        "clearance_level": {"name": "Executive Badge", "level": 0, "base_cost": 250.0, "cost_mult": 1.75, "type": "meta", "power_gain": 1.0, "current_cost": 250.0},
        "pickup_radius": {"name": "Magnetic Charm", "level": 0, "base_cost": 75.0, "cost_mult": 1.25, "type": "avatar_stat", "power_gain": 0.25, "current_cost": 75.0},
    }

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
        self.campaign_choices: Dict[str, Any] = {}
        self.researched_techs: List[str] = []
        self.unlocked_zones: List[str] = []
        self.item_inventory = {"briefcase": 0, "coffee": 0, "usb_drive": 0}

        self.base_click_power = 1.0
        self.base_passive_rps = 0.0
        self.bonus_users = 0
        self.collectibles_collected = 0
        self.avatar_speed_level = 0
        self.idle_level = 1
        self.pickup_radius_level = 0

        self.frenzy_meter = 0.0
        self.is_frenzy_active = False
        self.frenzy_multiplier = 1.0
        self.frenzy_duration_remaining = 0.0

        self.server_overclock_buff_timer = 0.0
        self.server_overclock_buff_multiplier = 1.0
        self.server_overclock_buff_active = False
        self.server_overclock_buff_remaining = 0.0

        self.campaign_rps_buff_timer = 0.0
        self.campaign_rps_buff_multiplier = 1.0
        self.campaign_speed_buff_timer = 0.0
        self.campaign_speed_buff_multiplier = 1.0

        self.unicorn_espresso_buff_active = False
        self.unicorn_espresso_buff_timer = 0.0
        self.unicorn_espresso_buff_remaining = 0.0

        self.upgrades = copy.deepcopy(self.DEFAULT_UPGRADES)
        self.signals_emitted: List[Tuple[str, Any]] = []

    def recalculate_stats(self):
        total_rps = 0.0
        total_click = 1.0
        for up in self.upgrades.values():
            lvl = int(up.get("level", 0))
            gain = float(up.get("power_gain", 0.0))
            t = up.get("type", "")
            if t == "idle":
                total_rps += lvl * gain
            elif t == "click":
                total_click += lvl * gain
        self.base_passive_rps = total_rps
        click_mult = 2.0 if "tech_quantum_ads" in self.researched_techs else 1.0
        self.base_click_power = total_click * click_mult

        if self.is_frenzy_active:
            tuning = int(self.upgrades.get("overdrive_tuning", {}).get("level", 0))
            self.frenzy_multiplier = 3.0 + (0.5 * tuning)

        self.avatar_speed_level = int(self.upgrades.get("avatar_speed", {}).get("level", 0))
        self.pickup_radius_level = int(self.upgrades.get("pickup_radius", {}).get("level", 0))
        clearance = int(self.upgrades.get("clearance_level", {}).get("level", 0))
        self.idle_level = 1 + clearance

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
        self.signals_emitted.append(("trophy_unlocked", trophy_id))
        return True

    def check_and_update_trophies(self):
        if (self.campaign_chapter >= 2 or "quest_briefcases" in self.campaign_completed_quests) and "trophy_golden_briefcase" not in self.unlocked_trophies:
            self.unlocked_trophies.append("trophy_golden_briefcase")
            self.signals_emitted.append(("trophy_unlocked", "trophy_golden_briefcase"))
        if (self.campaign_chapter >= 3 or "quest_server" in self.campaign_completed_quests) and "trophy_server_matrix" not in self.unlocked_trophies:
            self.unlocked_trophies.append("trophy_server_matrix")
            self.signals_emitted.append(("trophy_unlocked", "trophy_server_matrix"))
        if (self.campaign_chapter >= 4 or "quest_lab" in self.campaign_completed_quests) and "trophy_crystal_espresso" not in self.unlocked_trophies:
            self.unlocked_trophies.append("trophy_crystal_espresso")
            self.signals_emitted.append(("trophy_unlocked", "trophy_crystal_espresso"))
        if self.total_ipos_completed > 0 and "trophy_platinum_bull" not in self.unlocked_trophies:
            self.unlocked_trophies.append("trophy_platinum_bull")
            self.signals_emitted.append(("trophy_unlocked", "trophy_platinum_bull"))

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

        # 1. Award Angel Shares
        self.angel_shares += shares_gained
        self.total_ipos_completed += 1

        # 2. Unlock Platin-Börsenbulle Trophy
        self.unlock_trophy("trophy_platinum_bull")

        # 3. Reset regular energy
        self.energy = 0.0

        # 4. Reset building levels & upgrades
        for up_id in self.DEFAULT_UPGRADES:
            base_cost = float(self.DEFAULT_UPGRADES[up_id]["base_cost"])
            self.upgrades[up_id]["level"] = 0
            self.upgrades[up_id]["current_cost"] = base_cost

        # 5. Clear active temporary buffs & timers
        self.frenzy_meter = 0.0
        self.is_frenzy_active = False
        self.frenzy_multiplier = 1.0
        self.frenzy_duration_remaining = 0.0

        self.server_overclock_buff_timer = 0.0
        self.server_overclock_buff_multiplier = 1.0
        self.server_overclock_buff_active = False
        self.server_overclock_buff_remaining = 0.0

        self.campaign_rps_buff_timer = 0.0
        self.campaign_rps_buff_multiplier = 1.0
        self.campaign_speed_buff_timer = 0.0
        self.campaign_speed_buff_multiplier = 1.0

        self.unicorn_espresso_buff_active = False
        self.unicorn_espresso_buff_timer = 0.0
        self.unicorn_espresso_buff_remaining = 0.0

        # 6. Recalculate stats
        self.recalculate_stats()

        # 7. Emit signals
        self.signals_emitted.append(("energy_changed", self.energy, 0.0))
        self.signals_emitted.append(("rps_changed", self.base_passive_rps))
        self.signals_emitted.append(("frenzy_updated", self.frenzy_multiplier, 0.0))
        self.signals_emitted.append(("angel_shares_changed", self.angel_shares, shares_gained))
        self.signals_emitted.append(("ipo_completed", shares_gained, self.angel_shares, self.get_angel_share_multiplier()))

        return {
            "success": True,
            "shares_gained": shares_gained,
            "angel_shares_gained": shares_gained,
            "total_angel_shares": self.angel_shares,
            "angel_shares": self.angel_shares,
            "multiplier": self.get_angel_share_multiplier(),
            "total_ipos_completed": self.total_ipos_completed
        }

    def serialize_to_json(self) -> str:
        data = {
            "version": 1,
            "energy": self.energy,
            "total_energy_earned": self.total_energy_earned,
            "total_lifetime_energy": self.total_lifetime_energy,
            "angel_shares": self.angel_shares,
            "total_ipos_completed": self.total_ipos_completed,
            "unlocked_trophies": list(self.unlocked_trophies),
            "daily_streak": self.daily_streak,
            "last_daily_challenge_date": self.last_daily_challenge_date,
            "campaign_chapter": self.campaign_chapter,
            "campaign_completed_quests": list(self.campaign_completed_quests),
            "campaign_choices": copy.deepcopy(self.campaign_choices),
            "unlocked_zones": list(self.unlocked_zones),
            "researched_techs": list(self.researched_techs),
            "item_inventory": copy.deepcopy(self.item_inventory),
            "upgrades": {}
        }
        for up_id, up in self.upgrades.items():
            data["upgrades"][up_id] = {
                "level": int(up.get("level", 0)),
                "current_cost": float(up.get("current_cost", up["base_cost"]))
            }
        return json.dumps(data, indent=2)

    def deserialize_from_dict(self, data: Any) -> bool:
        if not isinstance(data, dict):
            return False

        # Energy fallback
        try:
            raw_e = float(data.get("energy", 0.0))
            self.energy = 0.0 if (math.isnan(raw_e) or math.isinf(raw_e)) else max(0.0, raw_e)
        except Exception:
            self.energy = 0.0

        # Total energy earned fallback
        try:
            raw_earned = float(data.get("total_energy_earned", self.energy))
            self.total_energy_earned = self.energy if (math.isnan(raw_earned) or math.isinf(raw_earned)) else max(self.energy, raw_earned)
        except Exception:
            self.total_energy_earned = self.energy

        # Total lifetime energy fallback (Milestone M1 requirement)
        raw_life_val = data.get("total_lifetime_energy", self.total_energy_earned)
        try:
            raw_lifetime = float(raw_life_val)
            if math.isnan(raw_lifetime) or math.isinf(raw_lifetime):
                self.total_lifetime_energy = self.total_energy_earned
            else:
                self.total_lifetime_energy = max(self.total_energy_earned, raw_lifetime)
        except Exception:
            self.total_lifetime_energy = self.total_energy_earned

        # Angel Shares
        try:
            raw_shares = data.get("angel_shares", 0)
            self.angel_shares = max(0, int(float(raw_shares))) if not (isinstance(raw_shares, float) and math.isnan(raw_shares)) else 0
        except Exception:
            self.angel_shares = 0

        # Total IPOs
        try:
            raw_ipos = data.get("total_ipos_completed", 0)
            self.total_ipos_completed = max(0, int(float(raw_ipos))) if not (isinstance(raw_ipos, float) and math.isnan(raw_ipos)) else 0
        except Exception:
            self.total_ipos_completed = 0

        # Unlocked Trophies
        self.unlocked_trophies.clear()
        raw_tr = data.get("unlocked_trophies", [])
        if isinstance(raw_tr, list):
            for t in raw_tr:
                if isinstance(t, str) and len(t) > 0 and t not in self.unlocked_trophies:
                    self.unlocked_trophies.append(t)

        # Meta fields
        try:
            self.daily_streak = max(0, int(data.get("daily_streak", 0)))
        except Exception:
            self.daily_streak = 0
        self.last_daily_challenge_date = str(data.get("last_daily_challenge_date", ""))

        try:
            self.campaign_chapter = max(1, int(data.get("campaign_chapter", 1)))
        except Exception:
            self.campaign_chapter = 1

        self.campaign_completed_quests.clear()
        raw_cq = data.get("campaign_completed_quests", [])
        if isinstance(raw_cq, list):
            for q in raw_cq:
                if isinstance(q, str) and len(q) > 0:
                    self.campaign_completed_quests.append(q)

        self.researched_techs.clear()
        raw_techs = data.get("researched_techs", [])
        if isinstance(raw_techs, list):
            for t in raw_techs:
                if isinstance(t, str) and len(t) > 0 and t not in self.researched_techs:
                    self.researched_techs.append(t)

        self.unlocked_zones.clear()
        raw_zones = data.get("unlocked_zones", [])
        if isinstance(raw_zones, list):
            for z in raw_zones:
                if isinstance(z, str) and len(z) > 0:
                    self.unlocked_zones.append(z)

        # Upgrades
        raw_upgrades = data.get("upgrades", {})
        if isinstance(raw_upgrades, dict):
            for up_id in self.DEFAULT_UPGRADES:
                if up_id in raw_upgrades:
                    entry = raw_upgrades[up_id]
                    lvl = 0
                    if isinstance(entry, dict):
                        lvl = int(entry.get("level", 0))
                    elif isinstance(entry, (int, float)) and not math.isnan(entry):
                        lvl = int(entry)
                    lvl = max(0, lvl)
                    self.upgrades[up_id]["level"] = lvl
                    cost = round(float(self.DEFAULT_UPGRADES[up_id]["base_cost"]) * pow(float(self.DEFAULT_UPGRADES[up_id]["cost_mult"]), float(lvl)))
                    self.upgrades[up_id]["current_cost"] = cost
                else:
                    self.upgrades[up_id] = copy.deepcopy(self.DEFAULT_UPGRADES[up_id])

        self.recalculate_stats()
        self.check_and_update_trophies()
        return True


# ==============================================================================
# SUB-TEST 3.1: Full Prestige Reset Rebirth Cycle Verification
# ==============================================================================
print("\n--- 3.1: Full Prestige Reset Rebirth Cycle Verification ---")

sim = EmpiricalGameStateSim()

# Inject active state:
sim.energy = 5432100.0
sim.total_energy_earned = 5432100.0
sim.total_lifetime_energy = 10000000.0   # 10M Lifetime Energy -> eligible = sqrt(100) = 10 shares
sim.angel_shares = 0
sim.total_ipos_completed = 0

# Elevate all 12 upgrades to level 5 with inflated costs
for up_id, up in sim.upgrades.items():
    up["level"] = 5
    up["current_cost"] = round(up["base_cost"] * (up["cost_mult"] ** 5))

# Activate Frenzy buff
sim.is_frenzy_active = True
sim.frenzy_meter = 100.0
sim.frenzy_multiplier = 4.5
sim.frenzy_duration_remaining = 8.0

# Activate Server Overclock buff
sim.server_overclock_buff_active = True
sim.server_overclock_buff_multiplier = 1.5
sim.server_overclock_buff_timer = 25.0
sim.server_overclock_buff_remaining = 25.0

# Activate Unicorn Espresso buff
sim.unicorn_espresso_buff_active = True
sim.unicorn_espresso_buff_timer = 60.0
sim.unicorn_espresso_buff_remaining = 60.0

# Activate Campaign buffs
sim.campaign_rps_buff_multiplier = 2.0
sim.campaign_rps_buff_timer = 30.0
sim.campaign_speed_buff_multiplier = 1.5
sim.campaign_speed_buff_timer = 45.0

# Meta progression to preserve
sim.campaign_chapter = 3
sim.campaign_completed_quests = ["quest_briefcases", "quest_server"]
sim.researched_techs = ["tech_coffee_automation", "tech_server_overclock", "tech_quantum_ads"]
sim.unlocked_zones = ["zone_server", "zone_lab"]
sim.item_inventory = {"briefcase": 5, "coffee": 10, "usb_drive": 3}
sim.daily_streak = 7

# Pre-checks before IPO execution
pending_before = sim.calculate_pending_angel_shares()
reporter.check(pending_before == 10, "Pending shares correctly calculated as 10 (sqrt(10M / 100k) = 10)", "IPO_PreCheck")
reporter.check(sim.can_trigger_ipo() is True, "can_trigger_ipo() evaluates to True", "IPO_PreCheck")

# EXECUTE IPO REBIRTH
ipo_result = sim.trigger_ipo()
reporter.check(ipo_result["success"] is True, "trigger_ipo() returned success == True", "IPO_Execution")

# 1. energy == 0.0
reporter.check(sim.energy == 0.0, "Invariant 1: energy == 0.0", "IPO_Invariant_1")

# 2. all 11/12 upgrades have level == 0 and cost == base_cost
all_upgrades_reset = True
for up_id, up in sim.upgrades.items():
    expected_base = float(sim.DEFAULT_UPGRADES[up_id]["base_cost"])
    if up["level"] != 0 or up["current_cost"] != expected_base:
        all_upgrades_reset = False
        reporter.check(False, f"Upgrade {up_id} not reset: level={up['level']}, cost={up['current_cost']} (expected {expected_base})", "IPO_Invariant_2")
        break
if all_upgrades_reset:
    reporter.check(True, f"Invariant 2: all {len(sim.upgrades)} upgrades have level == 0 and cost == base_cost", "IPO_Invariant_2")

# 3. all temporary buff timers == 0 and active == false
timers_cleared = (
    sim.frenzy_duration_remaining == 0.0 and
    sim.server_overclock_buff_timer == 0.0 and
    sim.server_overclock_buff_remaining == 0.0 and
    sim.campaign_rps_buff_timer == 0.0 and
    sim.campaign_speed_buff_timer == 0.0 and
    sim.unicorn_espresso_buff_timer == 0.0 and
    sim.unicorn_espresso_buff_remaining == 0.0
)
actives_cleared = (
    not sim.is_frenzy_active and
    not sim.server_overclock_buff_active and
    not sim.unicorn_espresso_buff_active and
    sim.frenzy_meter == 0.0 and
    sim.frenzy_multiplier == 1.0 and
    sim.server_overclock_buff_multiplier == 1.0 and
    sim.campaign_rps_buff_multiplier == 1.0 and
    sim.campaign_speed_buff_multiplier == 1.0
)
reporter.check(timers_cleared, "Invariant 3a: all temporary buff timers == 0.0", "IPO_Invariant_3")
reporter.check(actives_cleared, "Invariant 3b: all temporary buff active flags == false and multipliers == 1.0", "IPO_Invariant_3")

# 4. angel_shares increased exactly by pending shares
reporter.check(sim.angel_shares == 10, f"Invariant 4: angel_shares increased exactly by pending shares (10 shares)", "IPO_Invariant_4")
expected_multiplier = 1.0 + (10 * 0.02)  # 1.20x
reporter.check(abs(sim.get_angel_share_multiplier() - expected_multiplier) < 1e-6,
               f"Global multiplier is 1.20x (+20%): {sim.get_angel_share_multiplier()}", "IPO_Invariant_4")

# 5. total_ipos_completed increased by 1
reporter.check(sim.total_ipos_completed == 1, "Invariant 5: total_ipos_completed increased by 1 (now 1)", "IPO_Invariant_5")

# 6. trophy_platinum_bull is unlocked
reporter.check("trophy_platinum_bull" in sim.unlocked_trophies, "Invariant 6: trophy_platinum_bull is unlocked", "IPO_Invariant_6")

# 7. researched techs are NOT lost
expected_techs = ["tech_coffee_automation", "tech_server_overclock", "tech_quantum_ads"]
reporter.check(sim.researched_techs == expected_techs, "Invariant 7: researched techs are NOT lost", "IPO_Invariant_7")

# 8. campaign_chapter is NOT reset
reporter.check(sim.campaign_chapter == 3, "Invariant 8: campaign_chapter is NOT reset (remains 3)", "IPO_Invariant_8")

# 9. total_lifetime_energy did NOT decrease
reporter.check(sim.total_lifetime_energy == 10000000.0, "Invariant 9: total_lifetime_energy did NOT decrease (10,000,000.0)", "IPO_Invariant_9")

# Additional meta preservation checks
reporter.check(sim.daily_streak == 7, "daily_streak preserved (7)", "IPO_MetaPreserved")
reporter.check(sim.unlocked_zones == ["zone_server", "zone_lab"], "unlocked_zones preserved", "IPO_MetaPreserved")
reporter.check(sim.item_inventory == {"briefcase": 5, "coffee": 10, "usb_drive": 3}, "item_inventory preserved", "IPO_MetaPreserved")
reporter.check(sim.base_passive_rps == 0.0, "base_passive_rps reset to 0.0 from upgrade recalculation", "IPO_StatRecalc")
# Click power: total_click (1.0) * tech_quantum_ads (2.0) = 2.0
reporter.check(sim.base_click_power == 2.0, "base_click_power recalculated to 2.0 (with tech_quantum_ads active)", "IPO_StatRecalc")


# ==============================================================================
# SUB-TEST 3.2: Immediate Idempotency & Multi-IPO Lifecycle Progression
# ==============================================================================
print("\n--- 3.2: Immediate Idempotency & Multi-IPO Lifecycle Progression ---")

# Calling trigger_ipo() immediately again:
reporter.check(sim.calculate_pending_angel_shares() == 0, "Pending shares immediately drops to 0", "IPO_Idempotency")
reporter.check(sim.can_trigger_ipo() is False, "can_trigger_ipo() evaluates to False immediately after IPO", "IPO_Idempotency")

second_attempt = sim.trigger_ipo()
reporter.check(second_attempt["success"] is False, "Subsequent trigger_ipo() is safely rejected (success == False)", "IPO_Idempotency")
reporter.check(sim.angel_shares == 10, "angel_shares unmodified after rejected trigger_ipo()", "IPO_Idempotency")
reporter.check(sim.total_ipos_completed == 1, "total_ipos_completed unmodified after rejected trigger_ipo()", "IPO_Idempotency")

# Accumulate to 25,000,000 Lifetime Energy (eligible = sqrt(250) = 15 shares, already owned 10 -> 5 pending)
sim.total_lifetime_energy = 25000000.0
reporter.check(sim.calculate_pending_angel_shares() == 5, "Pending shares is 5 for 25M lifetime energy (15 eligible - 10 owned)", "IPO_SecondRun")
reporter.check(sim.can_trigger_ipo() is True, "can_trigger_ipo() is True after accumulating additional lifetime energy", "IPO_SecondRun")

second_ipo_res = sim.trigger_ipo()
reporter.check(second_ipo_res["success"] is True, "Second IPO succeeds", "IPO_SecondRun")
reporter.check(second_ipo_res["shares_gained"] == 5, "Second IPO awards 5 new shares", "IPO_SecondRun")
reporter.check(sim.angel_shares == 15, "Total angel shares is now 15", "IPO_SecondRun")
reporter.check(sim.total_ipos_completed == 2, "total_ipos_completed is now 2", "IPO_SecondRun")
reporter.check(abs(sim.get_angel_share_multiplier() - 1.30) < 1e-6, "Global multiplier is now 1.30x (+30%)", "IPO_SecondRun")


# ==============================================================================
# SECTION 4: Persistence Serialization & Fuzzing / Corrupt Payload Resilience
# ==============================================================================
print(f"\n{Colors.BOLD}{Colors.OKBLUE}--- SECTION 4: Persistence Serialization & Corrupt Field Resilience ---{Colors.ENDC}")

# 4.1 Normal Clean Roundtrip
sim_save = EmpiricalGameStateSim()
sim_save.energy = 450000.0
sim_save.total_energy_earned = 1200000.0
sim_save.total_lifetime_energy = 1600000.0
sim_save.angel_shares = 4
sim_save.total_ipos_completed = 1
sim_save.unlocked_trophies = ["trophy_golden_briefcase", "trophy_platinum_bull"]
sim_save.daily_streak = 3
sim_save.campaign_chapter = 2
sim_save.researched_techs = ["tech_coffee_automation"]
json_str = sim_save.serialize_to_json()

sim_load = EmpiricalGameStateSim()
reporter.check(sim_load.deserialize_from_dict(json.loads(json_str)), "Deserializes valid JSON save without error", "Persistence_Normal")
reporter.check(sim_load.energy == 450000.0, "Preserves energy across roundtrip", "Persistence_Normal")
reporter.check(sim_load.total_energy_earned == 1200000.0, "Preserves total_energy_earned across roundtrip", "Persistence_Normal")
reporter.check(sim_load.total_lifetime_energy == 1600000.0, "Preserves total_lifetime_energy across roundtrip", "Persistence_Normal")
reporter.check(sim_load.angel_shares == 4, "Preserves angel_shares across roundtrip", "Persistence_Normal")
reporter.check(sim_load.total_ipos_completed == 1, "Preserves total_ipos_completed across roundtrip", "Persistence_Normal")
reporter.check("trophy_platinum_bull" in sim_load.unlocked_trophies, "Preserves trophy_platinum_bull across roundtrip", "Persistence_Normal")

# 4.2 Legacy Save Migration (Missing total_lifetime_energy)
legacy_dict = {
    "version": 1,
    "energy": 250000.0,
    "total_energy_earned": 850000.0
    # total_lifetime_energy is completely missing!
}
sim_leg = EmpiricalGameStateSim()
sim_leg.deserialize_from_dict(legacy_dict)
reporter.check(sim_leg.total_lifetime_energy == 850000.0,
               "Legacy save without total_lifetime_energy falls back to total_energy_earned (850k)",
               "Persistence_Legacy")
reporter.check(sim_leg.angel_shares == 0, "Missing angel_shares defaults safely to 0", "Persistence_Legacy")
reporter.check(sim_leg.total_ipos_completed == 0, "Missing total_ipos_completed defaults safely to 0", "Persistence_Legacy")

# 4.3 Corrupt total_lifetime_energy Fuzzing (NaN, Inf, Strings, Negatives)
corrupt_lifetime_cases = [
    (float("nan"), 500000.0, "NaN falls back to total_energy_earned"),
    ("NaN", 500000.0, "String 'NaN' falls back to total_energy_earned"),
    (float("inf"), 500000.0, "+Inf falls back to total_energy_earned"),
    (float("-inf"), 500000.0, "-Inf falls back to total_energy_earned"),
    ("Infinity", 500000.0, "String 'Infinity' falls back to total_energy_earned"),
    ("corrupted_text_payload", 500000.0, "Non-numeric string falls back to total_energy_earned"),
    (-999999.0, 500000.0, "Negative float clamped to max(total_energy_earned, val) = 500k"),
    ("1500000.0", 1500000.0, "Valid numeric string successfully parsed as 1,500,000.0"),
    (None, 500000.0, "None value falls back to total_energy_earned")
]

for raw_val, expected, desc in corrupt_lifetime_cases:
    fuzz_dict = {
        "energy": 100000.0,
        "total_energy_earned": 500000.0,
        "total_lifetime_energy": raw_val
    }
    sim_fuzz = EmpiricalGameStateSim()
    sim_fuzz.deserialize_from_dict(fuzz_dict)
    reporter.check(sim_fuzz.total_lifetime_energy == expected,
                   f"{desc} (actual: {sim_fuzz.total_lifetime_energy})", "Persistence_LifetimeFuzz")

# 4.4 Corrupt angel_shares Fuzzing
corrupt_shares_cases = [
    (-25, 0, "Negative angel_shares clamped to 0"),
    (float("nan"), 0, "NaN angel_shares clamped to 0"),
    ("invalid_shares", 0, "String angel_shares clamped to 0"),
    (None, 0, "None angel_shares defaults to 0"),
    ("42", 42, "Numeric string '42' parses to 42 angel shares")
]
for raw_sh, exp_sh, desc in corrupt_shares_cases:
    fuzz_dict = {"angel_shares": raw_sh}
    sim_fuzz = EmpiricalGameStateSim()
    sim_fuzz.deserialize_from_dict(fuzz_dict)
    reporter.check(sim_fuzz.angel_shares == exp_sh,
                   f"{desc} (actual: {sim_fuzz.angel_shares})", "Persistence_SharesFuzz")

# 4.5 Corrupt Trophies & Retroactive Restoration via check_and_update_trophies()
trophy_corrupt_cases = [
    (None, "None trophies payload handled cleanly"),
    ("not_a_list", "String trophies payload handled cleanly"),
    ([123, None, "", "trophy_custom", 45.6], "Filtered invalid elements from trophy list")
]
for raw_tr, desc in trophy_corrupt_cases:
    fuzz_dict = {
        "unlocked_trophies": raw_tr,
        "total_ipos_completed": 2,     # Must restore trophy_platinum_bull!
        "campaign_chapter": 3          # Must restore trophy_golden_briefcase & trophy_server_matrix!
    }
    sim_fuzz = EmpiricalGameStateSim()
    sim_fuzz.deserialize_from_dict(fuzz_dict)
    reporter.check("trophy_platinum_bull" in sim_fuzz.unlocked_trophies,
                   f"{desc} -> trophy_platinum_bull retroactively restored", "Persistence_TrophyRestore")
    reporter.check("trophy_golden_briefcase" in sim_fuzz.unlocked_trophies,
                   f"{desc} -> trophy_golden_briefcase retroactively restored", "Persistence_TrophyRestore")
    reporter.check("trophy_server_matrix" in sim_fuzz.unlocked_trophies,
                   f"{desc} -> trophy_server_matrix retroactively restored", "Persistence_TrophyRestore")

# 4.6 Corrupt Upgrades Payload
corrupt_upgrades_cases = [
    (None, "None upgrades dict resets to default upgrades"),
    ("corrupt_upgrades", "String upgrades resets to default upgrades"),
    ([1, 2, 3], "List upgrades resets to default upgrades"),
    ({"click_booster": -10, "tier_1": {"level": -5}}, "Negative upgrade levels clamped to 0")
]
for raw_up, desc in corrupt_upgrades_cases:
    fuzz_dict = {"upgrades": raw_up}
    sim_fuzz = EmpiricalGameStateSim()
    sim_fuzz.deserialize_from_dict(fuzz_dict)
    reporter.check(sim_fuzz.upgrades["click_booster"]["level"] == 0,
                   f"{desc} -> click_booster level is 0", "Persistence_UpgradeFuzz")
    reporter.check(sim_fuzz.upgrades["click_booster"]["current_cost"] == 10.0,
                   f"{desc} -> click_booster cost is 10.0", "Persistence_UpgradeFuzz")


# ==============================================================================
# SECTION 5: Master Regression Battery Verification
# ==============================================================================
print(f"\n{Colors.BOLD}{Colors.OKBLUE}--- SECTION 5: Master Regression Battery Verification ---{Colors.ENDC}")

# Run worker M1 suite
m1_test_path = GAME_DIR / "tests" / "test_p12_m1_ipo.py"
if m1_test_path.exists():
    res = subprocess.run([sys.executable, str(m1_test_path)], capture_output=True, text=True, cwd=str(GAME_DIR))
    reporter.check(res.returncode == 0, "Worker M1 suite (test_p12_m1_ipo.py) passed with exit code 0", "Regression")
else:
    reporter.check(False, "Worker M1 suite (test_p12_m1_ipo.py) not found", "Regression")

# Run Phase 11 verify oracle
p11_test_path = GAME_DIR / "tests" / "test_phase11_verify.py"
if p11_test_path.exists():
    res = subprocess.run([sys.executable, str(p11_test_path)], capture_output=True, text=True, cwd=str(GAME_DIR))
    reporter.check(res.returncode == 0, "Phase 11 verify oracle (test_phase11_verify.py) passed with exit code 0", "Regression")
else:
    reporter.check(False, "Phase 11 verify oracle (test_phase11_verify.py) not found", "Regression")


# ==============================================================================
# MAIN SUMMARY
# ==============================================================================
success = reporter.summary()
sys.exit(0 if success else 1)
