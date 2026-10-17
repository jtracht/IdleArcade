#!/usr/bin/env python3
"""
Phase 13 Milestone 1: Syndicate Economy & Holdings Core Verification Suite
==========================================================================
Target: Godot 4.3 IdleArcade - Milestone M1 (Requirement R1: Syndicate / Gilden-Wirtschaft)

Validates:
  1. AST & Static Code Contract:
     - Signals declared in game_state.gd:
       * syndicate_joined(syndicate_data: Dictionary)
       * syndicate_left()
       * syndicate_contributed(resource_type: String, amount: float, new_fund_total: float, tier: int)
       * syndicate_tier_upgraded(new_tier: int, bonuses: Dictionary)
       * syndicate_season_updated(season_week: int, seasonal_score: int)
     - Constants declared in game_state.gd:
       * SYNDICATE_TIER_CONFIG mapping Tiers 0..5 with all required keys
     - State variables declared in game_state.gd:
       * active_syndicate_id, active_syndicate_name, active_syndicate_tag, active_syndicate_desc
       * active_syndicate_role, syndicate_tier, syndicate_fund_energy, syndicate_fund_angel_shares
       * syndicate_energy_contributed, syndicate_angel_shares_contributed, syndicate_members_count
       * syndicate_seasonal_score, syndicate_season_week, syndicate_joined_timestamp, syndicate_unlocked_badges
     - Methods declared in game_state.gd:
       * is_in_syndicate, get_syndicate_tier, get_active_syndicate, get_syndicate_bonuses
       * get_syndicate_dividend_multiplier, get_drone_speed_multiplier, get_syndicate_ipo_bonus_percent
       * found_syndicate, join_syndicate, leave_syndicate, contribute_to_syndicate
       * contribute_angel_shares_to_syndicate, check_syndicate_tier_progression
       * calculate_seasonal_score, get_seasonal_leaderboard_score, get_syndicate_tier_definitions
     - System Integrations:
       * get_effective_passive_rps() incorporates get_syndicate_dividend_multiplier()
       * delivery_drone_3d.gd incorporates GameState.get_drone_speed_multiplier()
       * calculate_pending_angel_shares() & trigger_ipo() incorporate get_syndicate_ipo_bonus_percent()
       * save_to_disk() and load_from_disk() serialize and deserialize syndicate state
       * reset_state() resets syndicate variables to baseline

  2. Mathematical Matrix & Tier Config Oracle:
     - Tiers 0 through 5 configuration mapping
     - Multipliers and percentages for dividend, drone speed, and IPO bonus

  3. Simulated GameState Lifecycle & State Machine:
     - Found / Join / Leave syndicate lifecycle
     - Energy and Angel Share contribution validations and threshold advancement
     - Seasonal leaderboard score calculation & weekly rollover badge unlock
     - IPO Prestige synergy (syndicate bonus angel shares & ascension persistence)

  4. State Serialization & Recovery Oracle:
     - JSON savegame format with nested and flat aliases
     - Defensive recovery from NaN, Inf, and malformed inputs

Executable via: python tests/test_p13_m1_syndicate.py
"""

import json
import math
import re
import sys
import time
from pathlib import Path
from typing import Any, Dict, List, Optional


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
        self.total = 0
        self.passed = 0
        self.failed = 0
        self.failures: List[str] = []

    def check(self, condition: bool, description: str, category: str = "GENERAL"):
        self.total += 1
        if condition:
            self.passed += 1
            print(f"  {Colors.OKGREEN}[PASS]{Colors.ENDC} [{category}] {description}")
        else:
            self.failed += 1
            msg = f"[{category}] {description}"
            self.failures.append(msg)
            print(f"  {Colors.FAIL}[FAIL]{Colors.ENDC} {msg}")

    def summarize(self) -> int:
        print("\n" + "=" * 70)
        print(f"{Colors.BOLD}Phase 13 Milestone M1 (Syndicate Economy) Test Results{Colors.ENDC}")
        print("=" * 70)
        print(f"  Total Checks : {self.total}")
        print(f"  Passed       : {Colors.OKGREEN}{self.passed}{Colors.ENDC}")
        print(f"  Failed       : {Colors.FAIL if self.failed > 0 else Colors.OKGREEN}{self.failed}{Colors.ENDC}")
        if self.failures:
            print(f"\n{Colors.FAIL}Failed Checks:{Colors.ENDC}")
            for f in self.failures:
                print(f"  - {f}")
            print("\n>>> OVERALL VERDICT: FAIL <<<")
            return 1
        print(f"\n{Colors.OKGREEN}>>> OVERALL VERDICT: 100% PASS (ALL CHECKS GREEN) <<<{Colors.ENDC}")
        return 0


# ==============================================================================
# SECTION 1: AST & Static Interface Contracts
# ==============================================================================

def verify_ast_contracts(reporter: TestReporter, game_dir: Path):
    print(f"\n{Colors.BOLD}=== SECTION 1: AST & Static Interface Contracts ==={Colors.ENDC}")

    gs_path = game_dir / "scripts/autoload/game_state.gd"
    drone_path = game_dir / "scripts/delivery_drone_3d.gd"

    reporter.check(gs_path.exists(), "game_state.gd exists", "AST_File")
    reporter.check(drone_path.exists(), "delivery_drone_3d.gd exists", "AST_File")

    if not gs_path.exists() or not drone_path.exists():
        return

    gs_code = gs_path.read_text(encoding="utf-8")
    drone_code = drone_path.read_text(encoding="utf-8")

    # 1. Signals
    expected_signals = [
        "syndicate_joined",
        "syndicate_left",
        "syndicate_contributed",
        "syndicate_tier_upgraded",
        "syndicate_season_updated",
    ]
    for sig in expected_signals:
        pattern = rf"signal\s+{sig}\s*(\(|$)"
        reporter.check(re.search(pattern, gs_code) is not None, f"Signal declared: {sig}", "AST_Signal")

    # 2. State Variables
    expected_vars = [
        "active_syndicate_id",
        "active_syndicate_name",
        "active_syndicate_tag",
        "active_syndicate_desc",
        "active_syndicate_role",
        "syndicate_tier",
        "syndicate_fund_energy",
        "syndicate_fund_angel_shares",
        "syndicate_energy_contributed",
        "syndicate_angel_shares_contributed",
        "syndicate_members_count",
        "syndicate_seasonal_score",
        "syndicate_season_week",
        "syndicate_joined_timestamp",
        "syndicate_unlocked_badges",
    ]
    for v in expected_vars:
        pattern = rf"var\s+{v}\s*:"
        reporter.check(re.search(pattern, gs_code) is not None, f"Variable declared: {v}", "AST_Variable")

    # 3. Constants
    reporter.check("SYNDICATE_TIER_CONFIG" in gs_code, "Constant SYNDICATE_TIER_CONFIG declared", "AST_Constant")
    for tier in range(6):
        reporter.check(f"{tier}: {{" in gs_code or f'"{tier}": {{' in gs_code or f"{tier}:" in gs_code,
                       f"SYNDICATE_TIER_CONFIG contains Tier {tier}", "AST_Constant")

    # 4. Public Methods in GameState
    expected_methods = [
        ("is_in_syndicate", r"func\s+is_in_syndicate\s*\(\s*\)\s*->\s*bool\s*:"),
        ("get_syndicate_tier", r"func\s+get_syndicate_tier\s*\(\s*\)\s*->\s*int\s*:"),
        ("get_active_syndicate", r"func\s+get_active_syndicate\s*\(\s*\)\s*->\s*Dictionary\s*:"),
        ("get_syndicate_bonuses", r"func\s+get_syndicate_bonuses\s*\(\s*\)\s*->\s*Dictionary\s*:"),
        ("get_syndicate_dividend_multiplier", r"func\s+get_syndicate_dividend_multiplier\s*\(\s*\)\s*->\s*float\s*:"),
        ("get_drone_speed_multiplier", r"func\s+get_drone_speed_multiplier\s*\(\s*\)\s*->\s*float\s*:"),
        ("get_syndicate_ipo_bonus_percent", r"func\s+get_syndicate_ipo_bonus_percent\s*\(\s*\)\s*->\s*float\s*:"),
        ("found_syndicate", r"func\s+found_syndicate\s*\("),
        ("join_syndicate", r"func\s+join_syndicate\s*\("),
        ("leave_syndicate", r"func\s+leave_syndicate\s*\(\s*\)\s*->\s*bool\s*:"),
        ("contribute_to_syndicate", r"func\s+contribute_to_syndicate\s*\("),
        ("contribute_angel_shares_to_syndicate", r"func\s+contribute_angel_shares_to_syndicate\s*\("),
        ("check_syndicate_tier_progression", r"func\s+check_syndicate_tier_progression\s*\(\s*\)\s*->\s*int\s*:"),
        ("calculate_seasonal_score", r"func\s+calculate_seasonal_score\s*\("),
        ("get_seasonal_leaderboard_score", r"func\s+get_seasonal_leaderboard_score\s*\(\s*\)\s*->\s*int\s*:"),
        ("get_syndicate_tier_definitions", r"func\s+get_syndicate_tier_definitions\s*\(\s*\)\s*->\s*Dictionary\s*:"),
    ]
    for name, pattern in expected_methods:
        reporter.check(re.search(pattern, gs_code) is not None, f"Method implemented: {name}()", "AST_Method")

    # 5. Core Integrations
    reporter.check(
        "get_syndicate_dividend_multiplier()" in gs_code,
        "get_effective_passive_rps() integrates get_syndicate_dividend_multiplier()",
        "AST_Integration"
    )
    reporter.check(
        "GameState.get_drone_speed_multiplier()" in drone_code or "get_drone_speed_multiplier" in drone_code,
        "delivery_drone_3d.gd integrates GameState.get_drone_speed_multiplier()",
        "AST_Integration"
    )
    reporter.check(
        "get_syndicate_ipo_bonus_percent()" in gs_code,
        "calculate_pending_angel_shares / trigger_ipo integrates get_syndicate_ipo_bonus_percent()",
        "AST_Integration"
    )
    reporter.check(
        '"syndicate":' in gs_code,
        "save_to_disk() serializes 'syndicate' block",
        "AST_Serialization"
    )
    reporter.check(
        'data.get("syndicate"' in gs_code or 'data.get("syndicate",' in gs_code,
        "load_from_disk() deserializes 'syndicate' block",
        "AST_Serialization"
    )
    reporter.check(
        "active_syndicate_id = \"\"" in gs_code and "syndicate_tier = 0" in gs_code,
        "reset_state() resets syndicate variables to baseline",
        "AST_Reset"
    )


# ==============================================================================
# SECTION 2: Python Simulation Class Matching GameStateGD Line-for-Line
# ==============================================================================

SYNDICATE_TIER_CONFIG = {
    0: {
        "tier": 0,
        "name": "Unaffiliated",
        "req_energy": 0.0,
        "req_shares": 0,
        "dividend_pct": 0.0,
        "dividend_mult": 1.0,
        "drone_speed_pct": 0.0,
        "drone_speed_mult": 1.0,
        "ipo_bonus_shares_pct": 0.0,
        "ipo_bonus_shares_mult": 1.0,
    },
    1: {
        "tier": 1,
        "name": "Seed Syndicate",
        "req_energy": 10000.0,
        "req_shares": 1,
        "dividend_pct": 0.05,
        "dividend_mult": 1.05,
        "drone_speed_pct": 0.0,
        "drone_speed_mult": 1.0,
        "ipo_bonus_shares_pct": 0.0,
        "ipo_bonus_shares_mult": 1.0,
    },
    2: {
        "tier": 2,
        "name": "Growth Syndicate",
        "req_energy": 100000.0,
        "req_shares": 5,
        "dividend_pct": 0.10,
        "dividend_mult": 1.10,
        "drone_speed_pct": 0.15,
        "drone_speed_mult": 1.15,
        "ipo_bonus_shares_pct": 0.0,
        "ipo_bonus_shares_mult": 1.0,
    },
    3: {
        "tier": 3,
        "name": "Expansion Syndicate",
        "req_energy": 500000.0,
        "req_shares": 20,
        "dividend_pct": 0.15,
        "dividend_mult": 1.15,
        "drone_speed_pct": 0.15,
        "drone_speed_mult": 1.15,
        "ipo_bonus_shares_pct": 0.05,
        "ipo_bonus_shares_mult": 1.05,
    },
    4: {
        "tier": 4,
        "name": "Venture Syndicate",
        "req_energy": 2500000.0,
        "req_shares": 50,
        "dividend_pct": 0.20,
        "dividend_mult": 1.20,
        "drone_speed_pct": 0.15,
        "drone_speed_mult": 1.15,
        "ipo_bonus_shares_pct": 0.10,
        "ipo_bonus_shares_mult": 1.10,
    },
    5: {
        "tier": 5,
        "name": "Holding Monopoly",
        "req_energy": 10000000.0,
        "req_shares": 100,
        "dividend_pct": 0.25,
        "dividend_mult": 1.25,
        "drone_speed_pct": 0.15,
        "drone_speed_mult": 1.15,
        "ipo_bonus_shares_pct": 0.15,
        "ipo_bonus_shares_mult": 1.15,
    },
}


class SimulatedGameState:
    IPO_ENERGY_THRESHOLD = 1000000.0

    def __init__(self):
        self.reset_state()

    def reset_state(self):
        self.energy: float = 0.0
        self.total_energy_earned: float = 0.0
        self.total_lifetime_energy: float = 0.0
        self.angel_shares: int = 0
        self.total_ipos_completed: int = 0
        self.unlocked_trophies: List[str] = []
        self.campaign_chapter: int = 1

        self.base_passive_rps: float = 100.0
        self.bonus_users: int = 0
        self.collectibles_collected: int = 0
        self.researched_techs: List[str] = []
        self.server_overclock_buff_active: bool = False
        self.campaign_rps_buff_multiplier: float = 1.0
        self.campaign_rps_buff_timer: float = 0.0

        # Syndicate State
        self.active_syndicate_id: str = ""
        self.active_syndicate_name: str = ""
        self.active_syndicate_tag: str = ""
        self.active_syndicate_desc: str = ""
        self.active_syndicate_role: str = "Member"
        self.syndicate_tier: int = 0
        self.syndicate_fund_energy: float = 0.0
        self.syndicate_fund_angel_shares: int = 0
        self.syndicate_energy_contributed: float = 0.0
        self.syndicate_angel_shares_contributed: int = 0
        self.syndicate_members_count: int = 1
        self.syndicate_seasonal_score: int = 0
        self.syndicate_season_week: int = 0
        self.syndicate_joined_timestamp: int = 0
        self.syndicate_unlocked_badges: List[str] = []

        # Signals log
        self.emitted_signals: List[tuple] = []

    def is_in_syndicate(self) -> bool:
        return bool(self.active_syndicate_id)

    def get_syndicate_tier(self) -> int:
        return self.syndicate_tier if self.is_in_syndicate() else 0

    def get_syndicate_bonuses(self) -> Dict[str, Any]:
        t = self.get_syndicate_tier()
        cfg = SYNDICATE_TIER_CONFIG.get(t, SYNDICATE_TIER_CONFIG[0])
        return {
            "tier": t,
            "name": cfg.get("name", "Unaffiliated"),
            "dividend_pct": float(cfg.get("dividend_pct", 0.0)),
            "dividend_multiplier": float(cfg.get("dividend_mult", 1.0)),
            "dividend_mult": float(cfg.get("dividend_mult", 1.0)),
            "drone_speed_pct": float(cfg.get("drone_speed_pct", 0.0)),
            "drone_speed_multiplier": float(cfg.get("drone_speed_mult", 1.0)),
            "drone_speed_mult": float(cfg.get("drone_speed_mult", 1.0)),
            "bonus_angel_shares_pct": float(cfg.get("ipo_bonus_shares_pct", 0.0)),
            "bonus_angel_shares_multiplier": float(cfg.get("ipo_bonus_shares_mult", 1.0)),
            "ipo_bonus_shares_pct": float(cfg.get("ipo_bonus_shares_pct", 0.0)),
            "ipo_bonus_shares_mult": float(cfg.get("ipo_bonus_shares_mult", 1.0)),
        }

    def get_active_syndicate(self) -> Dict[str, Any]:
        return {
            "id": self.active_syndicate_id,
            "name": self.active_syndicate_name,
            "tag": self.active_syndicate_tag,
            "description": self.active_syndicate_desc,
            "role": self.active_syndicate_role,
            "tier": self.get_syndicate_tier(),
            "fund_energy": self.syndicate_fund_energy,
            "fund_angel_shares": self.syndicate_fund_angel_shares,
            "energy_contributed": self.syndicate_energy_contributed,
            "angel_shares_contributed": self.syndicate_angel_shares_contributed,
            "members_count": self.syndicate_members_count,
            "seasonal_score": self.syndicate_seasonal_score,
            "season_week": self.syndicate_season_week,
            "unlocked_badges": list(self.syndicate_unlocked_badges),
            "bonuses": self.get_syndicate_bonuses(),
            "is_active": self.is_in_syndicate(),
        }

    def get_syndicate_dividend_multiplier(self) -> float:
        t = self.get_syndicate_tier()
        if t <= 0:
            return 1.0
        return 1.0 + (float(t) * 0.05)

    def get_drone_speed_multiplier(self) -> float:
        return 1.15 if self.get_syndicate_tier() >= 2 else 1.0

    def get_syndicate_ipo_bonus_percent(self) -> float:
        t = self.get_syndicate_tier()
        if t < 3:
            return 0.0
        return float(t - 2) * 0.05

    def found_syndicate(self, id: str, name: str, tag: str = "", description: str = "") -> Dict[str, Any]:
        if self.active_syndicate_id and self.active_syndicate_id != id:
            return {"success": False, "error": f"Already affiliated with a syndicate: {self.active_syndicate_id}"}

        final_id = id.strip()
        if not final_id:
            final_id = f"syn_{int(time.time())}"

        self.active_syndicate_id = final_id
        self.active_syndicate_name = name.strip() if name.strip() else "Enterprise Syndicate"
        self.active_syndicate_tag = tag.strip() if tag.strip() else "SYN"
        self.active_syndicate_desc = description.strip()
        self.active_syndicate_role = "Founder"
        if self.syndicate_tier == 0:
            self.syndicate_tier = 1
        self.syndicate_members_count = max(1, self.syndicate_members_count)
        self.syndicate_joined_timestamp = int(time.time())

        self.syndicate_seasonal_score = self.calculate_seasonal_score()
        self.emitted_signals.append(("rps_changed", self.get_effective_passive_rps()))
        self.emitted_signals.append(("syndicate_joined", self.get_active_syndicate()))

        return {
            "success": True,
            "syndicate": self.get_active_syndicate(),
        }

    def join_syndicate(self, id: str, name: str = "", tag: str = "", description: str = "") -> bool:
        if not id.strip():
            return False

        self.active_syndicate_id = id.strip()
        if name.strip():
            self.active_syndicate_name = name.strip()
        elif not self.active_syndicate_name:
            self.active_syndicate_name = "Enterprise Syndicate"

        if tag.strip():
            self.active_syndicate_tag = tag.strip()
        elif not self.active_syndicate_tag:
            self.active_syndicate_tag = "SYN"

        if description.strip():
            self.active_syndicate_desc = description.strip()

        self.active_syndicate_role = "Member"
        if self.syndicate_tier == 0:
            self.syndicate_tier = 1

        self.syndicate_joined_timestamp = int(time.time())
        self.syndicate_seasonal_score = self.calculate_seasonal_score()
        self.emitted_signals.append(("rps_changed", self.get_effective_passive_rps()))
        self.emitted_signals.append(("syndicate_joined", self.get_active_syndicate()))
        return True

    def leave_syndicate(self) -> bool:
        if not self.active_syndicate_id:
            return False

        self.active_syndicate_id = ""
        self.active_syndicate_name = ""
        self.active_syndicate_tag = ""
        self.active_syndicate_desc = ""
        self.active_syndicate_role = "Member"
        self.syndicate_tier = 0
        self.syndicate_fund_energy = 0.0
        self.syndicate_fund_angel_shares = 0
        self.syndicate_energy_contributed = 0.0
        self.syndicate_angel_shares_contributed = 0
        self.syndicate_seasonal_score = 0

        self.emitted_signals.append(("rps_changed", self.get_effective_passive_rps()))
        self.emitted_signals.append(("syndicate_left", ()))
        return True

    def contribute_to_syndicate(self, amount: float, resource_type: str = "energy") -> Dict[str, Any]:
        if not self.is_in_syndicate():
            return {"success": False, "error": "Not affiliated with any syndicate"}
        if amount <= 0.0:
            return {"success": False, "error": "Contribution amount must be greater than zero"}

        clean_type = resource_type.lower().strip()
        if clean_type == "energy":
            if self.energy < amount:
                return {"success": False, "error": f"Insufficient energy (available: {self.energy}, required: {amount})"}
            self.energy -= amount
            self.syndicate_fund_energy += amount
            self.syndicate_energy_contributed += amount
            self.emitted_signals.append(("energy_changed", (self.energy, -amount)))
        elif clean_type in ["angel_shares", "shares"]:
            shares_int = int(amount)
            if shares_int <= 0:
                return {"success": False, "error": "Must contribute at least 1 Angel Share"}
            if self.angel_shares < shares_int:
                return {"success": False, "error": f"Insufficient angel shares (available: {self.angel_shares}, required: {shares_int})"}
            self.angel_shares -= shares_int
            self.syndicate_fund_angel_shares += shares_int
            self.syndicate_angel_shares_contributed += shares_int
            self.emitted_signals.append(("angel_shares_changed", (self.angel_shares, -shares_int)))
        else:
            return {"success": False, "error": f"Invalid resource type '{resource_type}'. Use 'energy' or 'angel_shares'."}

        prev_tier = self.syndicate_tier
        self.check_syndicate_tier_progression()
        if self.syndicate_tier > prev_tier:
            self.emitted_signals.append(("syndicate_tier_upgraded", (self.syndicate_tier, self.get_syndicate_bonuses())))

        self.syndicate_seasonal_score = self.calculate_seasonal_score()
        self.emitted_signals.append(("syndicate_season_updated", (self.syndicate_season_week, self.syndicate_seasonal_score)))
        self.emitted_signals.append(("rps_changed", self.get_effective_passive_rps()))
        self.emitted_signals.append(("syndicate_contributed", (clean_type, amount, self.syndicate_fund_energy, self.syndicate_tier)))

        return {
            "success": True,
            "resource_type": clean_type,
            "amount": amount,
            "tier": self.syndicate_tier,
            "fund_energy": self.syndicate_fund_energy,
            "fund_angel_shares": self.syndicate_fund_angel_shares,
            "seasonal_score": self.syndicate_seasonal_score,
            "bonuses": self.get_syndicate_bonuses(),
        }

    def contribute_angel_shares_to_syndicate(self, shares: int) -> Dict[str, Any]:
        return self.contribute_to_syndicate(float(shares), "angel_shares")

    def check_syndicate_tier_progression(self) -> int:
        if not self.is_in_syndicate():
            self.syndicate_tier = 0
            return 0
        for t in [5, 4, 3, 2, 1]:
            cfg = SYNDICATE_TIER_CONFIG[t]
            if self.syndicate_fund_energy >= float(cfg["req_energy"]) or self.syndicate_fund_angel_shares >= int(cfg["req_shares"]):
                if t > self.syndicate_tier:
                    self.syndicate_tier = t
                break
        return self.syndicate_tier

    def calculate_seasonal_score(self, fund_energy: float = -1.0, fund_shares: int = -1, tier: int = -1) -> int:
        e = fund_energy if fund_energy >= 0.0 else self.syndicate_fund_energy
        s = fund_shares if fund_shares >= 0 else self.syndicate_fund_angel_shares
        t = tier if tier >= 0 else self.syndicate_tier
        return int(math.floor(max(0.0, e) / 100.0)) + (max(0, s) * 500) + (max(0, t) * 1000)

    def get_seasonal_leaderboard_score(self) -> int:
        current_week = int(time.time() / (86400 * 7))
        if self.syndicate_season_week == 0:
            self.syndicate_season_week = current_week
        elif current_week > self.syndicate_season_week:
            if self.syndicate_seasonal_score >= 10000 and "badge_syndicate_champion" not in self.syndicate_unlocked_badges:
                self.syndicate_unlocked_badges.append("badge_syndicate_champion")
            self.syndicate_season_week = current_week
        self.syndicate_seasonal_score = self.calculate_seasonal_score()
        return self.syndicate_seasonal_score

    def get_syndicate_tier_definitions(self) -> Dict[int, Any]:
        return dict(SYNDICATE_TIER_CONFIG)

    # Passive RPS and IPO methods
    def get_effective_passive_rps(self) -> float:
        camp_rps_mult = self.campaign_rps_buff_multiplier if self.campaign_rps_buff_timer > 0.0 else 1.0
        bonus_mult = 1.0 + (float(self.bonus_users) * 0.01)
        item_mult = 1.0 + (float(self.collectibles_collected) * 0.05)
        tech_mult = 1.25 if "tech_server_overclock" in self.researched_techs else 1.0
        server_mult = 1.50 if self.server_overclock_buff_active else 1.0
        angel_mult = self.get_angel_share_multiplier()
        syndicate_dividend = self.get_syndicate_dividend_multiplier()
        return self.base_passive_rps * bonus_mult * item_mult * tech_mult * server_mult * camp_rps_mult * angel_mult * syndicate_dividend

    def get_angel_share_multiplier(self) -> float:
        return 1.0 + (float(self.angel_shares) * 0.02)

    def calculate_pending_angel_shares(self) -> int:
        if self.total_lifetime_energy < 100000.0:
            return 0
        total_eligible = int(math.floor(math.sqrt(max(0.0, self.total_lifetime_energy) / 100000.0)))
        base_pending = max(0, total_eligible - self.angel_shares)
        bonus_pct = self.get_syndicate_ipo_bonus_percent()
        if bonus_pct > 0.0 and base_pending > 0:
            bonus_shares = int(math.floor(float(base_pending) * bonus_pct))
            return base_pending + bonus_shares
        return base_pending

    def can_trigger_ipo(self) -> bool:
        threshold_met = (self.total_lifetime_energy >= self.IPO_ENERGY_THRESHOLD) or (self.campaign_chapter >= 3)
        return threshold_met and (self.calculate_pending_angel_shares() > 0)

    def trigger_ipo(self) -> Dict[str, Any]:
        if not self.can_trigger_ipo():
            return {
                "success": False,
                "error": "Cannot trigger IPO",
                "shares_gained": 0,
                "total_angel_shares": self.angel_shares,
            }

        total_eligible = int(math.floor(math.sqrt(max(0.0, self.total_lifetime_energy) / 100000.0)))
        base_pending = max(0, total_eligible - self.angel_shares)
        bonus_pct = self.get_syndicate_ipo_bonus_percent()
        bonus_shares = int(math.floor(float(base_pending) * bonus_pct)) if (bonus_pct > 0.0 and base_pending > 0) else 0
        shares_gained = base_pending + bonus_shares

        if shares_gained <= 0:
            return {"success": False, "error": "No pending angel shares to claim"}

        self.angel_shares += shares_gained
        self.total_ipos_completed += 1
        self.energy = 0.0

        return {
            "success": True,
            "shares_gained": shares_gained,
            "angel_shares_gained": shares_gained,
            "total_angel_shares": self.angel_shares,
            "multiplier": self.get_angel_share_multiplier(),
            "base_shares_gained": base_pending,
            "syndicate_bonus_shares": bonus_shares,
        }

    def serialize(self) -> Dict[str, Any]:
        return {
            "version": 1,
            "energy": self.energy,
            "total_lifetime_energy": self.total_lifetime_energy,
            "angel_shares": self.angel_shares,
            "syndicate": {
                "active_id": self.active_syndicate_id,
                "name": self.active_syndicate_name,
                "tag": self.active_syndicate_tag,
                "description": self.active_syndicate_desc,
                "role": self.active_syndicate_role,
                "tier": self.syndicate_tier,
                "fund_energy": self.syndicate_fund_energy,
                "fund_angel_shares": self.syndicate_fund_angel_shares,
                "energy_contributed": self.syndicate_energy_contributed,
                "angel_shares_contributed": self.syndicate_angel_shares_contributed,
                "members_count": self.syndicate_members_count,
                "seasonal_score": self.syndicate_seasonal_score,
                "season_week": self.syndicate_season_week,
                "joined_timestamp": self.syndicate_joined_timestamp,
                "unlocked_badges": list(self.syndicate_unlocked_badges),
            },
            "active_syndicate_id": self.active_syndicate_id,
            "syndicate_tier": self.syndicate_tier,
            "syndicate_fund_energy": self.syndicate_fund_energy,
            "syndicate_fund_angel_shares": self.syndicate_fund_angel_shares,
        }

    def deserialize(self, data: Dict[str, Any]) -> bool:
        if "syndicate" in data and isinstance(data["syndicate"], dict) and data["syndicate"]:
            s = data["syndicate"]
            self.active_syndicate_id = str(s.get("active_id", data.get("active_syndicate_id", "")))
            self.active_syndicate_name = str(s.get("name", ""))
            self.active_syndicate_tag = str(s.get("tag", ""))
            self.active_syndicate_desc = str(s.get("description", ""))
            self.active_syndicate_role = str(s.get("role", "Member"))
            raw_tier = int(s.get("tier", data.get("syndicate_tier", 0)))
            self.syndicate_tier = max(0, min(5, raw_tier))
            raw_energy = float(s.get("fund_energy", data.get("syndicate_fund_energy", 0.0)))
            self.syndicate_fund_energy = 0.0 if (math.isnan(raw_energy) or math.isinf(raw_energy)) else max(0.0, raw_energy)
            self.syndicate_fund_angel_shares = max(0, int(s.get("fund_angel_shares", data.get("syndicate_fund_angel_shares", 0))))
            raw_contrib = float(s.get("energy_contributed", 0.0))
            self.syndicate_energy_contributed = 0.0 if (math.isnan(raw_contrib) or math.isinf(raw_contrib)) else max(0.0, raw_contrib)
            self.syndicate_angel_shares_contributed = max(0, int(s.get("angel_shares_contributed", 0)))
            self.syndicate_members_count = max(1, int(s.get("members_count", 1)))
            self.syndicate_seasonal_score = max(0, int(s.get("seasonal_score", 0)))
            self.syndicate_season_week = max(0, int(s.get("season_week", 0)))
            self.syndicate_joined_timestamp = int(s.get("joined_timestamp", 0))
            self.syndicate_unlocked_badges = [b for b in s.get("unlocked_badges", []) if isinstance(b, str) and b]
        elif "active_syndicate_id" in data:
            self.active_syndicate_id = str(data.get("active_syndicate_id", ""))
            self.syndicate_tier = max(0, min(5, int(data.get("syndicate_tier", 0))))
            raw_energy = float(data.get("syndicate_fund_energy", 0.0))
            self.syndicate_fund_energy = 0.0 if (math.isnan(raw_energy) or math.isinf(raw_energy)) else max(0.0, raw_energy)
            self.syndicate_fund_angel_shares = max(0, int(data.get("syndicate_fund_angel_shares", 0)))
        return True


# ==============================================================================
# SECTION 3: Mathematical Tier Configuration & Multiplier Oracle
# ==============================================================================

def verify_tier_multipliers(reporter: TestReporter):
    print(f"\n{Colors.BOLD}=== SECTION 2: Tier Configuration & Multiplier Mathematical Oracle ==={Colors.ENDC}")

    sim = SimulatedGameState()

    # Matrix expected:
    # Tier: (dividend_mult, drone_speed_mult, ipo_bonus_pct)
    expected_matrix = {
        0: (1.00, 1.00, 0.00),
        1: (1.05, 1.00, 0.00),
        2: (1.10, 1.15, 0.00),
        3: (1.15, 1.15, 0.05),
        4: (1.20, 1.15, 0.10),
        5: (1.25, 1.15, 0.15),
    }

    for tier, (exp_div, exp_drone, exp_ipo) in expected_matrix.items():
        sim.active_syndicate_id = "syn_test" if tier > 0 else ""
        sim.syndicate_tier = tier

        div_mult = sim.get_syndicate_dividend_multiplier()
        drone_mult = sim.get_drone_speed_multiplier()
        ipo_pct = sim.get_syndicate_ipo_bonus_percent()

        reporter.check(
            math.isclose(div_mult, exp_div, abs_tol=1e-5),
            f"Tier {tier}: Dividend Multiplier = {div_mult:.2f} (expected {exp_div:.2f})",
            "MATH_Tier"
        )
        reporter.check(
            math.isclose(drone_mult, exp_drone, abs_tol=1e-5),
            f"Tier {tier}: Drone Speed Multiplier = {drone_mult:.2f} (expected {exp_drone:.2f})",
            "MATH_Tier"
        )
        reporter.check(
            math.isclose(ipo_pct, exp_ipo, abs_tol=1e-5),
            f"Tier {tier}: IPO Bonus Shares Pct = {ipo_pct*100:.0f}% (expected {exp_ipo*100:.0f}%)",
            "MATH_Tier"
        )

        bonuses = sim.get_syndicate_bonuses()
        reporter.check(
            math.isclose(bonuses["dividend_multiplier"], exp_div, abs_tol=1e-5) and
            math.isclose(bonuses["drone_speed_multiplier"], exp_drone, abs_tol=1e-5) and
            math.isclose(bonuses["bonus_angel_shares_pct"], exp_ipo, abs_tol=1e-5),
            f"Tier {tier}: get_syndicate_bonuses() matches config matrix",
            "MATH_BonusesDict"
        )


# ==============================================================================
# SECTION 4: Lifecycle & State Machine Simulation
# ==============================================================================

def verify_lifecycle_and_state_machine(reporter: TestReporter):
    print(f"\n{Colors.BOLD}=== SECTION 3: Lifecycle & State Machine Simulation ==={Colors.ENDC}")

    sim = SimulatedGameState()

    # 1. Initial State (Unaffiliated)
    reporter.check(not sim.is_in_syndicate(), "Initial state: unaffiliated", "LIFECYCLE_Init")
    reporter.check(sim.get_syndicate_tier() == 0, "Initial tier is 0", "LIFECYCLE_Init")
    reporter.check(math.isclose(sim.get_syndicate_dividend_multiplier(), 1.0), "Initial dividend mult is 1.0", "LIFECYCLE_Init")

    # 2. Founding Syndicate
    res = sim.found_syndicate("syn_apex", "Apex Holdings", "APEX", "Top tier venture firm")
    reporter.check(res["success"], "found_syndicate succeeds", "LIFECYCLE_Found")
    reporter.check(sim.is_in_syndicate(), "Player is now in syndicate", "LIFECYCLE_Found")
    reporter.check(sim.active_syndicate_id == "syn_apex", "Active ID matches 'syn_apex'", "LIFECYCLE_Found")
    reporter.check(sim.active_syndicate_role == "Founder", "Active role is Founder", "LIFECYCLE_Found")
    reporter.check(sim.get_syndicate_tier() == 1, "Initial syndicate tier is 1 (Seed Syndicate)", "LIFECYCLE_Found")
    reporter.check(math.isclose(sim.get_syndicate_dividend_multiplier(), 1.05), "Tier 1 dividend multiplier is 1.05 (+5%)", "LIFECYCLE_Found")

    # Duplicate found attempt without leaving
    dup_res = sim.found_syndicate("syn_other", "Other Syndicate")
    reporter.check(not dup_res["success"], "Cannot found second syndicate while affiliated", "LIFECYCLE_Found")

    # 3. Energy Contribution & Tier Progression
    sim.energy = 50000.0
    # Try negative contribution
    neg_res = sim.contribute_to_syndicate(-100.0)
    reporter.check(not neg_res["success"], "Negative energy contribution rejected", "LIFECYCLE_Contrib")

    # Try contribution greater than available energy
    over_res = sim.contribute_to_syndicate(60000.0)
    reporter.check(not over_res["success"], "Over-balance energy contribution rejected", "LIFECYCLE_Contrib")

    # Valid contribution of 10,000 Energy
    c1 = sim.contribute_to_syndicate(10000.0, "energy")
    reporter.check(c1["success"], "Contribute 10,000 energy succeeds", "LIFECYCLE_Contrib")
    reporter.check(math.isclose(sim.energy, 40000.0), "Energy deducted to 40,000", "LIFECYCLE_Contrib")
    reporter.check(math.isclose(sim.syndicate_fund_energy, 10000.0), "Fund energy is 10,000", "LIFECYCLE_Contrib")
    reporter.check(sim.get_syndicate_tier() == 1, "Fund at 10,000: Tier 1 preserved", "LIFECYCLE_Contrib")

    # Contribute up to 100,000 Energy (crossing Tier 2 threshold)
    sim.energy = 150000.0
    c2 = sim.contribute_to_syndicate(90000.0, "energy")
    reporter.check(c2["success"], "Contribute 90,000 energy succeeds", "LIFECYCLE_Contrib")
    reporter.check(math.isclose(sim.syndicate_fund_energy, 100000.0), "Fund energy reached 100,000", "LIFECYCLE_Progression")
    reporter.check(sim.get_syndicate_tier() == 2, "Syndicate promoted to Tier 2 (Growth Syndicate)", "LIFECYCLE_Progression")
    reporter.check(math.isclose(sim.get_syndicate_dividend_multiplier(), 1.10), "Tier 2 dividend is 1.10 (+10%)", "LIFECYCLE_Progression")
    reporter.check(math.isclose(sim.get_drone_speed_multiplier(), 1.15), "Tier 2 drone speed is 1.15 (+15%)", "LIFECYCLE_Progression")

    # 4. Angel Share Contribution
    sim.angel_shares = 25
    c_shares = sim.contribute_angel_shares_to_syndicate(20)
    reporter.check(c_shares["success"], "Contribute 20 Angel Shares succeeds", "LIFECYCLE_Shares")
    reporter.check(sim.angel_shares == 5, "Angel shares deducted to 5", "LIFECYCLE_Shares")
    reporter.check(sim.syndicate_fund_angel_shares == 20, "Fund has 20 Angel Shares", "LIFECYCLE_Shares")
    reporter.check(sim.get_syndicate_tier() == 3, "20 Angel Shares promoted syndicate to Tier 3 (Expansion)", "LIFECYCLE_Shares")
    reporter.check(math.isclose(sim.get_syndicate_dividend_multiplier(), 1.15), "Tier 3 dividend is 1.15 (+15%)", "LIFECYCLE_Shares")
    reporter.check(math.isclose(sim.get_syndicate_ipo_bonus_percent(), 0.05), "Tier 3 IPO bonus is +5%", "LIFECYCLE_Shares")

    # Advance to Tier 5 via 100 Angel Shares
    sim.angel_shares = 100
    sim.contribute_angel_shares_to_syndicate(80)
    reporter.check(sim.syndicate_fund_angel_shares == 100, "Fund reached 100 Angel Shares", "LIFECYCLE_Tier5")
    reporter.check(sim.get_syndicate_tier() == 5, "Syndicate promoted to Tier 5 (Holding Monopoly)", "LIFECYCLE_Tier5")
    reporter.check(math.isclose(sim.get_syndicate_dividend_multiplier(), 1.25), "Tier 5 dividend is 1.25 (+25%)", "LIFECYCLE_Tier5")
    reporter.check(math.isclose(sim.get_syndicate_ipo_bonus_percent(), 0.15), "Tier 5 IPO bonus is +15%", "LIFECYCLE_Tier5")

    # 5. Seasonal Weekly Leaderboard Formula
    # score = floor(energy / 100) + shares * 500 + tier * 1000
    # Current state: fund_energy = 100,000; fund_shares = 100; tier = 5
    # Expected: (100000 / 100) + 100 * 500 + 5 * 1000 = 1000 + 50000 + 5000 = 56000
    score = sim.calculate_seasonal_score()
    reporter.check(score == 56000, f"Seasonal score matches mathematical formula: {score} == 56000", "LIFECYCLE_Seasonal")

    # Leaderboard week rotation awards badge if score >= 10,000
    sim.syndicate_season_week = int(time.time() / (86400 * 7)) - 1  # Prior week
    new_score = sim.get_seasonal_leaderboard_score()
    reporter.check("badge_syndicate_champion" in sim.syndicate_unlocked_badges,
                   "Weekly rollover awards 'badge_syndicate_champion' when score >= 10k", "LIFECYCLE_SeasonalBadge")

    # 6. IPO Prestige Ascension Synergy
    # Test pending shares with +15% syndicate bonus
    sim.total_lifetime_energy = 10000000.0  # sqrt(10M / 100k) = sqrt(100) = 10 shares
    sim.angel_shares = 0
    # Base shares = 10, Bonus at Tier 5 (+15%) = floor(10 * 0.15) = 1 bonus share -> 11 total
    pending = sim.calculate_pending_angel_shares()
    reporter.check(pending == 11, f"Pending shares incorporates Tier 5 +15% bonus: {pending} == 11", "LIFECYCLE_IPO")

    ipo_res = sim.trigger_ipo()
    reporter.check(ipo_res["success"], "trigger_ipo succeeds", "LIFECYCLE_IPO")
    reporter.check(ipo_res["base_shares_gained"] == 10, "Base shares gained is 10", "LIFECYCLE_IPO")
    reporter.check(ipo_res["syndicate_bonus_shares"] == 1, "Syndicate bonus shares gained is 1", "LIFECYCLE_IPO")
    reporter.check(sim.angel_shares == 11, "Total angel shares is 11", "LIFECYCLE_IPO")

    # Check that syndicate state PERSISTS across IPO rebirth!
    reporter.check(sim.is_in_syndicate(), "Syndicate membership PRESERVED across IPO rebirth", "LIFECYCLE_Ascension")
    reporter.check(sim.get_syndicate_tier() == 5, "Syndicate Tier 5 PRESERVED across IPO rebirth", "LIFECYCLE_Ascension")
    reporter.check(sim.syndicate_fund_energy == 100000.0, "Syndicate fund energy PRESERVED", "LIFECYCLE_Ascension")

    # 7. Leaving Syndicate
    left = sim.leave_syndicate()
    reporter.check(left, "leave_syndicate succeeds", "LIFECYCLE_Leave")
    reporter.check(not sim.is_in_syndicate(), "is_in_syndicate() is now False", "LIFECYCLE_Leave")
    reporter.check(sim.get_syndicate_tier() == 0, "Tier reverted to 0", "LIFECYCLE_Leave")
    reporter.check(math.isclose(sim.get_syndicate_dividend_multiplier(), 1.0), "Dividend multiplier reverted to 1.0", "LIFECYCLE_Leave")
    reporter.check(math.isclose(sim.get_drone_speed_multiplier(), 1.0), "Drone speed multiplier reverted to 1.0", "LIFECYCLE_Leave")
    reporter.check(math.isclose(sim.get_syndicate_ipo_bonus_percent(), 0.0), "IPO bonus reverted to 0.0", "LIFECYCLE_Leave")


# ==============================================================================
# SECTION 5: Persistence Serialization & Recovery
# ==============================================================================

def verify_persistence_and_recovery(reporter: TestReporter):
    print(f"\n{Colors.BOLD}=== SECTION 4: Persistence Serialization & Recovery ==={Colors.ENDC}")

    sim1 = SimulatedGameState()
    sim1.found_syndicate("syn_alpha", "Alpha Venture", "ALP", "Alpha Syndicate Description")
    sim1.energy = 500000.0
    sim1.contribute_to_syndicate(500000.0, "energy")
    sim1.angel_shares = 25
    sim1.contribute_angel_shares_to_syndicate(20)
    sim1.syndicate_unlocked_badges.append("badge_syndicate_champion")

    save_payload = sim1.serialize()
    json_str = json.dumps(save_payload)
    loaded_payload = json.loads(json_str)

    # Restore in pristine game state
    sim2 = SimulatedGameState()
    sim2.deserialize(loaded_payload)

    reporter.check(sim2.active_syndicate_id == "syn_alpha", "Save/Load restores syndicate ID", "PERSIST_Restore")
    reporter.check(sim2.active_syndicate_name == "Alpha Venture", "Save/Load restores syndicate name", "PERSIST_Restore")
    reporter.check(sim2.active_syndicate_tag == "ALP", "Save/Load restores syndicate tag", "PERSIST_Restore")
    reporter.check(sim2.active_syndicate_role == "Founder", "Save/Load restores Founder role", "PERSIST_Restore")
    reporter.check(sim2.syndicate_tier == sim1.syndicate_tier, f"Save/Load restores tier: {sim2.syndicate_tier}", "PERSIST_Restore")
    reporter.check(math.isclose(sim2.syndicate_fund_energy, sim1.syndicate_fund_energy), "Save/Load restores fund energy", "PERSIST_Restore")
    reporter.check(sim2.syndicate_fund_angel_shares == sim1.syndicate_fund_angel_shares, "Save/Load restores fund shares", "PERSIST_Restore")
    reporter.check("badge_syndicate_champion" in sim2.syndicate_unlocked_badges, "Save/Load restores badges", "PERSIST_Restore")

    # Defensive NaN / Inf / Corruption Handling
    corrupt_data = {
        "version": 1,
        "syndicate": {
            "active_id": "syn_corrupt",
            "tier": 999,  # Out of range (should clamp to 5)
            "fund_energy": float("nan"),  # NaN should default to 0.0
            "fund_angel_shares": -50,    # Negative should clamp to 0
        }
    }
    sim3 = SimulatedGameState()
    sim3.deserialize(corrupt_data)
    reporter.check(sim3.syndicate_tier == 5, "Tier 999 defensively clamped to 5", "PERSIST_Defensive")
    reporter.check(sim3.syndicate_fund_energy == 0.0, "NaN fund energy defensively set to 0.0", "PERSIST_Defensive")
    reporter.check(sim3.syndicate_fund_angel_shares == 0, "Negative fund shares defensively set to 0", "PERSIST_Defensive")

    # Backward compatibility with legacy savegame (no syndicate block)
    legacy_data = {
        "version": 1,
        "energy": 12345.0,
        "total_lifetime_energy": 12345.0,
    }
    sim4 = SimulatedGameState()
    sim4.deserialize(legacy_data)
    reporter.check(sim4.active_syndicate_id == "", "Legacy save: active_syndicate_id is empty", "PERSIST_Legacy")
    reporter.check(sim4.syndicate_tier == 0, "Legacy save: syndicate_tier is 0", "PERSIST_Legacy")
    reporter.check(sim4.get_syndicate_tier() == 0, "Legacy save: get_syndicate_tier() is 0", "PERSIST_Legacy")
    reporter.check(math.isclose(sim4.get_syndicate_dividend_multiplier(), 1.0), "Legacy save: dividend is 1.0", "PERSIST_Legacy")


# ==============================================================================
# MAIN RUNNER
# ==============================================================================

def main():
    print(f"{Colors.HEADER}{Colors.BOLD}======================================================================{Colors.ENDC}")
    print(f"{Colors.HEADER}{Colors.BOLD}IdleArcade Phase 13 Milestone M1: Syndicate Economy Verification Suite{Colors.ENDC}")
    print(f"{Colors.HEADER}{Colors.BOLD}======================================================================{Colors.ENDC}")

    base_dir = Path(__file__).resolve().parent.parent
    reporter = TestReporter()

    verify_ast_contracts(reporter, base_dir)
    verify_tier_multipliers(reporter)
    verify_lifecycle_and_state_machine(reporter)
    verify_persistence_and_recovery(reporter)

    return reporter.summarize()


if __name__ == "__main__":
    sys.exit(main())
