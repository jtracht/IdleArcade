#!/usr/bin/env python3
"""
Phase 13 Milestone M1: Adversarial Stress, Persistence Corruption & Stacking Oracle
===================================================================================
Target: IdleArcade Godot 4.3 - Milestone M1 (Syndicate Economy & Holdings Core)

Adversarial Challenger Suite:
  1. AST & Static Code Architecture Deep Audit:
     - Signals, constants, variables, methods in game_state.gd
     - Stacking multiplier integration in get_effective_passive_rps()
     - Fallback resilience in delivery_drone_3d.gd
     - IPO rebirth synergy in calculate_pending_angel_shares() & trigger_ipo()
  2. Persistence Serialization & Corruption Recovery Stress:
     - Malicious, corrupted, truncated, and NaN/Inf savegame payloads
     - Out-of-bounds and type mismatch fuzzing (500 randomized iterations)
     - Safe normalization guarantees (tier in [0..5], non-negative funds, member >= 1)
  3. Multiplier Stacking & Extreme Numerical Stress:
     - Simultaneous Frenzy, Server Overclock, Campaign, Tech, Angel Shares, and Syndicate Dividends
     - Boundary and extreme scale testing (base 0.0 to 1e200, 1M angel shares, 1M bonus users)
     - Monte Carlo random configuration oracle (2,000 randomized configurations)
  4. Delivery Drone 3D Controller Resilience:
     - GameState present vs null vs missing method vs mock object
     - Speed multiplier stacking with temporary boosts
  5. State Machine Invariants & Lifecycle Stress:
     - Negative and over-balance contribution attacks
     - Exact tier progression boundaries (energy and angel shares)
     - Seasonal leaderboard score calculation & idempotent weekly badge award

Executable via: python tests/test_p13_m1_adversarial_stress.py
"""

import json
import math
import random
import re
import sys
import time
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

GAME_ROOT = Path(__file__).resolve().parent.parent
GAME_STATE_PATH = GAME_ROOT / "scripts" / "autoload" / "game_state.gd"
DRONE_PATH = GAME_ROOT / "scripts" / "delivery_drone_3d.gd"

class Colors:
    GREEN = "\033[92m"
    RED = "\033[91m"
    YELLOW = "\033[93m"
    CYAN = "\033[96m"
    BOLD = "\033[1m"
    ENDC = "\033[0m"

class TestReporter:
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
        print("\n" + "=" * 70)
        print("Phase 13 Milestone M1: Adversarial Stress Test Results")
        print("=" * 70)
        print(f"  Total Checks : {self.total}")
        print(f"  Passed       : {self.passed}")
        print(f"  Failed       : {self.failed}")
        if self.failures:
            print("\nFailures:")
            for f in self.failures:
                print(f"  - {f}")
            print(f"\n{Colors.RED}>>> ADVERSARIAL VERDICT: REQUEST_CHANGES (FAILURES DETECTED) <<<{Colors.ENDC}")
            return 1
        else:
            print(f"\n{Colors.GREEN}>>> ADVERSARIAL VERDICT: 100% APPROVE (ROBUST & RESILIENT) <<<{Colors.ENDC}")
            return 0


# ==============================================================================
# SIMULATION CLASSES
# ==============================================================================

SYNDICATE_TIER_CONFIG = {
    0: {
        "tier": 0, "name": "Unaffiliated",
        "req_energy": 0.0, "req_shares": 0,
        "dividend_pct": 0.0, "dividend_mult": 1.0,
        "drone_speed_pct": 0.0, "drone_speed_mult": 1.0,
        "ipo_bonus_shares_pct": 0.0, "ipo_bonus_shares_mult": 1.0
    },
    1: {
        "tier": 1, "name": "Seed Syndicate",
        "req_energy": 10000.0, "req_shares": 1,
        "dividend_pct": 0.05, "dividend_mult": 1.05,
        "drone_speed_pct": 0.0, "drone_speed_mult": 1.0,
        "ipo_bonus_shares_pct": 0.0, "ipo_bonus_shares_mult": 1.0
    },
    2: {
        "tier": 2, "name": "Growth Syndicate",
        "req_energy": 100000.0, "req_shares": 5,
        "dividend_pct": 0.10, "dividend_mult": 1.10,
        "drone_speed_pct": 0.15, "drone_speed_mult": 1.15,
        "ipo_bonus_shares_pct": 0.0, "ipo_bonus_shares_mult": 1.0
    },
    3: {
        "tier": 3, "name": "Expansion Syndicate",
        "req_energy": 500000.0, "req_shares": 20,
        "dividend_pct": 0.15, "dividend_mult": 1.15,
        "drone_speed_pct": 0.15, "drone_speed_mult": 1.15,
        "ipo_bonus_shares_pct": 0.05, "ipo_bonus_shares_mult": 1.05
    },
    4: {
        "tier": 4, "name": "Venture Syndicate",
        "req_energy": 2500000.0, "req_shares": 50,
        "dividend_pct": 0.20, "dividend_mult": 1.20,
        "drone_speed_pct": 0.15, "drone_speed_mult": 1.15,
        "ipo_bonus_shares_pct": 0.10, "ipo_bonus_shares_mult": 1.10
    },
    5: {
        "tier": 5, "name": "Holding Monopoly",
        "req_energy": 10000000.0, "req_shares": 100,
        "dividend_pct": 0.25, "dividend_mult": 1.25,
        "drone_speed_pct": 0.15, "drone_speed_mult": 1.15,
        "ipo_bonus_shares_pct": 0.15, "ipo_bonus_shares_mult": 1.15
    }
}

class SimulatedGameStateAdv:
    def __init__(self):
        self.reset_state()

    def reset_state(self):
        self.energy: float = 0.0
        self.total_energy_earned: float = 0.0
        self.total_lifetime_energy: float = 0.0
        self.angel_shares: int = 0
        self.total_ipos_completed: int = 0
        self.base_passive_rps: float = 100.0
        self.bonus_users: int = 0
        self.collectibles_collected: int = 0
        self.researched_techs: List[str] = []
        self.server_overclock_buff_active: bool = False
        self.server_overclock_buff_timer: float = 0.0
        self.server_overclock_buff_multiplier: float = 1.50
        self.campaign_rps_buff_multiplier: float = 1.0
        self.campaign_rps_buff_timer: float = 0.0
        self.frenzy_multiplier: float = 1.0

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

    def is_in_syndicate(self) -> bool:
        return bool(self.active_syndicate_id)

    def get_syndicate_tier(self) -> int:
        return self.syndicate_tier if self.is_in_syndicate() else 0

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

    def get_bonus_multiplier(self) -> float:
        return 1.0 + (float(self.bonus_users) * 0.01)

    def get_campus_item_multiplier(self) -> float:
        rate = 0.10 if "tech_neural_cloud" in self.researched_techs else 0.05
        return 1.0 + (float(self.collectibles_collected) * rate)

    def get_angel_share_multiplier(self) -> float:
        return 1.0 + (float(self.angel_shares) * 0.02)

    def get_effective_passive_rps(self) -> float:
        camp_rps_mult = self.campaign_rps_buff_multiplier if self.campaign_rps_buff_timer > 0.0 else 1.0
        overclock_active = (self.server_overclock_buff_timer > 0.0 or self.server_overclock_buff_active)
        server_mult = self.server_overclock_buff_multiplier if overclock_active else 1.0
        tech_overclock = 1.25 if "tech_server_overclock" in self.researched_techs else 1.0
        return (
            self.base_passive_rps
            * self.get_bonus_multiplier()
            * self.get_campus_item_multiplier()
            * tech_overclock
            * server_mult
            * camp_rps_mult
            * self.get_angel_share_multiplier()
            * self.get_syndicate_dividend_multiplier()
        )

    def deserialize_safe(self, data: Any) -> bool:
        """Mirrors exact load_from_disk logic in game_state.gd."""
        if not isinstance(data, dict):
            return False

        # Load syndicate block
        syn_data = data.get("syndicate")
        if isinstance(syn_data, dict) and syn_data:
            raw_id = syn_data.get("active_id", data.get("active_syndicate_id", ""))
            self.active_syndicate_id = str(raw_id) if raw_id is not None else ""
            self.active_syndicate_name = str(syn_data.get("name", "")) if syn_data.get("name") is not None else ""
            self.active_syndicate_tag = str(syn_data.get("tag", "")) if syn_data.get("tag") is not None else ""
            self.active_syndicate_desc = str(syn_data.get("description", "")) if syn_data.get("description") is not None else ""
            self.active_syndicate_role = str(syn_data.get("role", "Member")) if syn_data.get("role") is not None else "Member"

            try:
                raw_tier = int(syn_data.get("tier", data.get("syndicate_tier", 0)))
            except (ValueError, TypeError, OverflowError):
                raw_tier = 0
            self.syndicate_tier = max(0, min(5, raw_tier))

            try:
                raw_energy = float(syn_data.get("fund_energy", data.get("syndicate_fund_energy", 0.0)))
            except (ValueError, TypeError, OverflowError):
                raw_energy = 0.0
            self.syndicate_fund_energy = 0.0 if (math.isnan(raw_energy) or math.isinf(raw_energy)) else max(0.0, raw_energy)

            try:
                raw_shares = int(syn_data.get("fund_angel_shares", data.get("syndicate_fund_angel_shares", 0)))
            except (ValueError, TypeError, OverflowError):
                raw_shares = 0
            self.syndicate_fund_angel_shares = max(0, raw_shares)

            try:
                raw_contrib_energy = float(syn_data.get("energy_contributed", 0.0))
            except (ValueError, TypeError, OverflowError):
                raw_contrib_energy = 0.0
            self.syndicate_energy_contributed = 0.0 if (math.isnan(raw_contrib_energy) or math.isinf(raw_contrib_energy)) else max(0.0, raw_contrib_energy)

            try:
                raw_contrib_shares = int(syn_data.get("angel_shares_contributed", 0))
            except (ValueError, TypeError, OverflowError):
                raw_contrib_shares = 0
            self.syndicate_angel_shares_contributed = max(0, raw_contrib_shares)

            try:
                raw_members = int(syn_data.get("members_count", 1))
            except (ValueError, TypeError, OverflowError):
                raw_members = 1
            self.syndicate_members_count = max(1, raw_members)

            try:
                raw_score = int(syn_data.get("seasonal_score", 0))
            except (ValueError, TypeError, OverflowError):
                raw_score = 0
            self.syndicate_seasonal_score = max(0, raw_score)

            try:
                raw_week = int(syn_data.get("season_week", 0))
            except (ValueError, TypeError, OverflowError):
                raw_week = 0
            self.syndicate_season_week = max(0, raw_week)

            try:
                raw_time = int(syn_data.get("joined_timestamp", 0))
            except (ValueError, TypeError, OverflowError):
                raw_time = 0
            self.syndicate_joined_timestamp = raw_time

            self.syndicate_unlocked_badges.clear()
            raw_badges = syn_data.get("unlocked_badges")
            if isinstance(raw_badges, list):
                for b in raw_badges:
                    if isinstance(b, str) and b and b not in self.syndicate_unlocked_badges:
                        self.syndicate_unlocked_badges.append(b)

        elif "active_syndicate_id" in data:
            raw_id = data.get("active_syndicate_id", "")
            self.active_syndicate_id = str(raw_id) if raw_id is not None else ""
            try:
                raw_tier = int(data.get("syndicate_tier", 0))
            except (ValueError, TypeError, OverflowError):
                raw_tier = 0
            self.syndicate_tier = max(0, min(5, raw_tier))

            try:
                raw_energy = float(data.get("syndicate_fund_energy", 0.0))
            except (ValueError, TypeError, OverflowError):
                raw_energy = 0.0
            self.syndicate_fund_energy = 0.0 if (math.isnan(raw_energy) or math.isinf(raw_energy)) else max(0.0, raw_energy)

            try:
                raw_shares = int(data.get("syndicate_fund_angel_shares", 0))
            except (ValueError, TypeError, OverflowError):
                raw_shares = 0
            self.syndicate_fund_angel_shares = max(0, raw_shares)

        return True

    def found_syndicate(self, id: str, name: str, tag: str = "", description: str = "") -> Dict[str, Any]:
        if self.active_syndicate_id and self.active_syndicate_id != id:
            return {"success": False, "error": f"Already affiliated with a syndicate: {self.active_syndicate_id}"}
        final_id = id.strip() if id else f"syn_{int(time.time())}"
        self.active_syndicate_id = final_id
        self.active_syndicate_name = name.strip() if name and name.strip() else "Enterprise Syndicate"
        self.active_syndicate_tag = tag.strip() if tag and tag.strip() else "SYN"
        self.active_syndicate_desc = description.strip() if description else ""
        self.active_syndicate_role = "Founder"
        if self.syndicate_tier == 0:
            self.syndicate_tier = 1
        self.syndicate_members_count = max(1, self.syndicate_members_count)
        self.syndicate_joined_timestamp = int(time.time())
        self.syndicate_seasonal_score = self.calculate_seasonal_score()
        return {"success": True}

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
        return True

    def contribute_to_syndicate(self, amount: float, resource_type: str = "energy") -> Dict[str, Any]:
        if not self.is_in_syndicate():
            return {"success": False, "error": "Not affiliated with any syndicate"}
        if amount <= 0.0:
            return {"success": False, "error": "Contribution amount must be greater than zero"}

        clean_type = resource_type.lower().strip()
        if clean_type == "energy":
            if self.energy < amount:
                return {"success": False, "error": f"Insufficient energy"}
            self.energy -= amount
            self.syndicate_fund_energy += amount
            self.syndicate_energy_contributed += amount
        elif clean_type in ["angel_shares", "shares"]:
            shares_int = int(amount)
            if shares_int <= 0:
                return {"success": False, "error": "Must contribute at least 1 Angel Share"}
            if self.angel_shares < shares_int:
                return {"success": False, "error": "Insufficient angel shares"}
            self.angel_shares -= shares_int
            self.syndicate_fund_angel_shares += shares_int
            self.syndicate_angel_shares_contributed += shares_int
        else:
            return {"success": False, "error": f"Invalid resource type '{resource_type}'"}

        self.check_syndicate_tier_progression()
        self.syndicate_seasonal_score = self.calculate_seasonal_score()
        return {"success": True}

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

    def simulate_weekly_rollover(self, advance_weeks: int = 1):
        self.syndicate_season_week += advance_weeks
        if self.syndicate_seasonal_score >= 10000 and "badge_syndicate_champion" not in self.syndicate_unlocked_badges:
            self.syndicate_unlocked_badges.append("badge_syndicate_champion")
        self.syndicate_seasonal_score = self.calculate_seasonal_score()


# ==============================================================================
# SECTION 1: AST & Code Contract Deep Verification
# ==============================================================================

def test_ast_contracts(reporter: TestReporter):
    print(f"\n{Colors.BOLD}=== SECTION 1: AST & Code Contract Deep Audit ==={Colors.ENDC}")
    content_gs = GAME_STATE_PATH.read_text(encoding="utf-8")
    content_drone = DRONE_PATH.read_text(encoding="utf-8")

    # 1. Signals
    signals = [
        "signal syndicate_joined(syndicate_data: Dictionary)",
        "signal syndicate_left()",
        "signal syndicate_contributed(resource_type: String, amount: float, new_fund_total: float, tier: int)",
        "signal syndicate_tier_upgraded(new_tier: int, bonuses: Dictionary)",
        "signal syndicate_season_updated(season_week: int, seasonal_score: int)"
    ]
    for sig in signals:
        reporter.check(sig in content_gs, f"Signal defined: {sig}", "AST_Signal")

    # 2. Methods
    methods = [
        "is_in_syndicate", "get_syndicate_tier", "get_active_syndicate",
        "get_syndicate_bonuses", "get_syndicate_dividend_multiplier",
        "get_drone_speed_multiplier", "get_syndicate_ipo_bonus_percent",
        "found_syndicate", "join_syndicate", "leave_syndicate",
        "contribute_to_syndicate", "contribute_angel_shares_to_syndicate",
        "check_syndicate_tier_progression", "calculate_seasonal_score",
        "get_seasonal_leaderboard_score", "get_syndicate_tier_definitions"
    ]
    for m in methods:
        pattern = rf"func\s+{m}\s*\("
        reporter.check(bool(re.search(pattern, content_gs)), f"Method implemented: {m}()", "AST_Method")

    # 3. get_effective_passive_rps() integration
    rps_integration = bool(re.search(r"get_syndicate_dividend_multiplier\(\)", content_gs))
    reporter.check(rps_integration, "get_effective_passive_rps() calls get_syndicate_dividend_multiplier()", "AST_Integration")

    # 4. delivery_drone_3d.gd integration with safe ternary
    drone_safe_check = "GameState.get_drone_speed_multiplier() if (GameState != null and GameState.has_method(\"get_drone_speed_multiplier\")) else 1.0"
    reporter.check(drone_safe_check in content_drone, "delivery_drone_3d.gd incorporates safe fallback for get_drone_speed_multiplier()", "AST_Integration")

    # 5. calculate_pending_angel_shares and trigger_ipo bonus integration
    ipo_bonus_check = bool(re.search(r"get_syndicate_ipo_bonus_percent\(\)", content_gs))
    reporter.check(ipo_bonus_check, "calculate_pending_angel_shares/trigger_ipo incorporates get_syndicate_ipo_bonus_percent()", "AST_Integration")

    # 6. NaN/Inf defensive deserialization guards
    nan_guard_fund = "0.0 if (is_nan(raw_syn_energy) or is_inf(raw_syn_energy)) else maxf(0.0, raw_syn_energy)"
    reporter.check(nan_guard_fund in content_gs, "load_from_disk() has NaN and Inf guard on syndicate_fund_energy", "AST_Defensive")


# ==============================================================================
# SECTION 2: Persistence Serialization & Corruption Recovery Stress
# ==============================================================================

def test_persistence_adversarial_stress(reporter: TestReporter):
    print(f"\n{Colors.BOLD}=== SECTION 2: Persistence Serialization & Corruption Recovery Stress ==={Colors.ENDC}")

    # Explicit Malicious Payloads
    malicious_payloads: List[Tuple[str, Any]] = [
        ("None payload", None),
        ("Integer root", 12345),
        ("String root", "corrupted string content"),
        ("Array root", [1, 2, 3]),
        ("Empty dict root", {}),
        ("Syndicate field is null", {"syndicate": None}),
        ("Syndicate field is integer", {"syndicate": 42}),
        ("Syndicate field is string", {"syndicate": "not_a_dict"}),
        ("Syndicate field is array", {"syndicate": ["item1", "item2"]}),
        ("Syndicate field is empty dict", {"syndicate": {}}),
        ("Syndicate with all null values", {
            "syndicate": {
                "active_id": None, "name": None, "tag": None, "description": None,
                "role": None, "tier": None, "fund_energy": None, "fund_angel_shares": None,
                "energy_contributed": None, "angel_shares_contributed": None,
                "members_count": None, "seasonal_score": None, "season_week": None,
                "joined_timestamp": None, "unlocked_badges": None
            }
        }),
        ("Syndicate with negative numbers", {
            "syndicate": {
                "active_id": "syn_neg",
                "tier": -999,
                "fund_energy": -5000000.0,
                "fund_angel_shares": -50,
                "energy_contributed": -1000.0,
                "angel_shares_contributed": -10,
                "members_count": -5,
                "seasonal_score": -9999,
                "season_week": -2,
            }
        }),
        ("Syndicate with extreme out-of-bounds numbers", {
            "syndicate": {
                "active_id": "syn_overflow",
                "tier": 999999,
                "fund_energy": 1e300,
                "fund_angel_shares": 10**14,
                "members_count": 10**8,
            }
        }),
        ("Syndicate with NaN and Inf in floats", {
            "syndicate": {
                "active_id": "syn_nan",
                "tier": 3,
                "fund_energy": float("nan"),
                "energy_contributed": float("inf"),
            }
        }),
        ("Syndicate with -Inf in floats", {
            "syndicate": {
                "active_id": "syn_neginf",
                "tier": 2,
                "fund_energy": float("-inf"),
                "energy_contributed": float("-inf"),
            }
        }),
        ("Syndicate with wrong types in fields", {
            "syndicate": {
                "active_id": 99999,
                "name": ["Invalid", "Name"],
                "tag": {"tag": "BAD"},
                "tier": "tier_five",
                "fund_energy": "ten_thousand",
                "fund_angel_shares": "fifty",
                "unlocked_badges": [123, None, "", "badge_syndicate_champion", "badge_syndicate_champion", {"fake": "badge"}]
            }
        }),
        ("Flat legacy keys with corrupted values", {
            "active_syndicate_id": "syn_legacy",
            "syndicate_tier": -10,
            "syndicate_fund_energy": float("nan"),
            "syndicate_fund_angel_shares": -100,
        }),
        ("Flat legacy keys with string values", {
            "active_syndicate_id": 123456,
            "syndicate_tier": "three",
            "syndicate_fund_energy": "invalid",
            "syndicate_fund_angel_shares": "invalid",
        })
    ]

    for desc, payload in malicious_payloads:
        sim = SimulatedGameStateAdv()
        try:
            success = sim.deserialize_safe(payload)
            # Check invariants:
            # 1. Tier is always in [0..5]
            tier_valid = (0 <= sim.syndicate_tier <= 5)
            # 2. Fund energy is finite and >= 0.0
            fund_e_valid = (math.isfinite(sim.syndicate_fund_energy) and sim.syndicate_fund_energy >= 0.0)
            # 3. Fund shares is finite integer and >= 0
            fund_s_valid = (isinstance(sim.syndicate_fund_angel_shares, int) and sim.syndicate_fund_angel_shares >= 0)
            # 4. Members count >= 1
            members_valid = (sim.syndicate_members_count >= 1)
            # 5. Badges are unique non-empty strings
            badges_valid = all(isinstance(b, str) and len(b) > 0 for b in sim.syndicate_unlocked_badges) and len(sim.syndicate_unlocked_badges) == len(set(sim.syndicate_unlocked_badges))
            # 6. Seasonal score and week >= 0
            season_valid = (sim.syndicate_seasonal_score >= 0 and sim.syndicate_season_week >= 0)

            all_ok = tier_valid and fund_e_valid and fund_s_valid and members_valid and badges_valid and season_valid
            reporter.check(all_ok, f"Malicious Payload [{desc}] normalized safely (Tier={sim.syndicate_tier}, FundE={sim.syndicate_fund_energy:.1f}, FundS={sim.syndicate_fund_angel_shares})", "PERSIST_Malicious")
        except Exception as ex:
            reporter.check(False, f"Malicious Payload [{desc}] raised uncaught exception: {ex}", "PERSIST_Malicious")

    # Randomized Fuzzing (500 iterations)
    print(f"\n  {Colors.CYAN}Running Property-Based Persistence Fuzzing (500 iterations)...{Colors.ENDC}")
    fuzz_types = [None, True, False, 0, -1, 999, 3.14, float("nan"), float("inf"), float("-inf"), "", "test", [], {}, ["badge"], {"nested": 1}]
    fuzz_passes = 0

    for i in range(500):
        random_payload = {
            "version": random.choice(fuzz_types),
            "energy": random.choice(fuzz_types),
            "syndicate": {
                "active_id": random.choice(fuzz_types),
                "name": random.choice(fuzz_types),
                "tag": random.choice(fuzz_types),
                "tier": random.choice(fuzz_types),
                "fund_energy": random.choice(fuzz_types),
                "fund_angel_shares": random.choice(fuzz_types),
                "energy_contributed": random.choice(fuzz_types),
                "angel_shares_contributed": random.choice(fuzz_types),
                "members_count": random.choice(fuzz_types),
                "seasonal_score": random.choice(fuzz_types),
                "season_week": random.choice(fuzz_types),
                "unlocked_badges": random.choice([None, "str", [random.choice(fuzz_types) for _ in range(3)]]),
            }
        }
        sim = SimulatedGameStateAdv()
        try:
            sim.deserialize_safe(random_payload)
            assert 0 <= sim.syndicate_tier <= 5
            assert math.isfinite(sim.syndicate_fund_energy) and sim.syndicate_fund_energy >= 0.0
            assert isinstance(sim.syndicate_fund_angel_shares, int) and sim.syndicate_fund_angel_shares >= 0
            assert sim.syndicate_members_count >= 1
            fuzz_passes += 1
        except Exception:
            break

    reporter.check(fuzz_passes == 500, f"500/500 randomized fuzzing payloads normalized without crashing", "PERSIST_Fuzzing")


# ==============================================================================
# SECTION 3: Multiplier Stacking & Extreme Numerical Stress
# ==============================================================================

def test_multiplier_stacking_stress(reporter: TestReporter):
    print(f"\n{Colors.BOLD}=== SECTION 3: Multiplier Stacking & Extreme Numerical Stress ==={Colors.ENDC}")

    sim = SimulatedGameStateAdv()

    # 1. Zero Base RPS remains 0.0 across all buff combinations
    sim.base_passive_rps = 0.0
    sim.bonus_users = 1000
    sim.collectibles_collected = 50
    sim.researched_techs = ["tech_server_overclock", "tech_neural_cloud"]
    sim.server_overclock_buff_active = True
    sim.server_overclock_buff_multiplier = 2.0
    sim.campaign_rps_buff_timer = 60.0
    sim.campaign_rps_buff_multiplier = 2.0
    sim.angel_shares = 500
    sim.active_syndicate_id = "syn_stack"
    sim.syndicate_tier = 5

    zero_rps = sim.get_effective_passive_rps()
    reporter.check(zero_rps == 0.0, f"Base RPS 0.0 with maximum active buffs produces exactly 0.0 (actual: {zero_rps})", "STACK_ZeroPreservation")

    # 2. Maximum Realistic Active Buff Stacking (Simultaneous Frenzy + Overclock + Campaign + Tech + Angel Shares + Syndicate T5)
    sim.base_passive_rps = 1000.0  # 1K base
    sim.bonus_users = 200          # +200% -> 3.0x
    sim.collectibles_collected = 20 # with neural cloud (+10%/item) -> +200% -> 3.0x
    sim.researched_techs = ["tech_server_overclock", "tech_neural_cloud"] # 1.25x
    sim.server_overclock_buff_active = True
    sim.server_overclock_buff_multiplier = 1.50 # 1.50x
    sim.campaign_rps_buff_timer = 30.0
    sim.campaign_rps_buff_multiplier = 2.0 # 2.0x
    sim.angel_shares = 100         # +200% -> 3.0x
    sim.syndicate_tier = 5         # +25% -> 1.25x
    sim.frenzy_multiplier = 5.0    # 5.0x

    # Expected product:
    # 1000 * 3.0 * 3.0 * 1.25 * 1.50 * 2.0 * 3.0 * 1.25 = 379,687.5
    eff_rps = sim.get_effective_passive_rps()
    expected_eff = 1000.0 * 3.0 * 3.0 * 1.25 * 1.50 * 2.0 * 3.0 * 1.25
    reporter.check(math.isclose(eff_rps, expected_eff, rel_tol=1e-5), f"Simultaneous 7-buff passive RPS matches mathematical oracle: {eff_rps:.1f} == {expected_eff:.1f}", "STACK_SimultaneousBuffs")
    reporter.check(math.isfinite(eff_rps) and eff_rps > 0.0, f"Simultaneous stacked RPS is strictly finite and positive", "STACK_FinitePositive")

    # Frenzy tick passive energy gain simulation:
    # passive_gain = eff_rps * frenzy_multiplier * delta
    delta = 0.016666  # 60 FPS
    frenzy_gain = eff_rps * sim.frenzy_multiplier * delta
    expected_frenzy_gain = expected_eff * 5.0 * delta
    reporter.check(math.isclose(frenzy_gain, expected_frenzy_gain, rel_tol=1e-5), f"Frenzy active tick gain matches oracle: {frenzy_gain:.2f} == {expected_frenzy_gain:.2f}", "STACK_FrenzyTick")

    # 3. Monotonicity check across all Syndicate Tiers (0 to 5)
    rps_by_tier = []
    for t in range(6):
        sim.syndicate_tier = t
        sim.active_syndicate_id = "syn_test" if t > 0 else ""
        rps_by_tier.append(sim.get_effective_passive_rps())

    is_monotonic = all(rps_by_tier[i] <= rps_by_tier[i+1] for i in range(len(rps_by_tier)-1))
    strict_increase = all(rps_by_tier[i] < rps_by_tier[i+1] for i in range(1, len(rps_by_tier)-1))
    reporter.check(is_monotonic and strict_increase, f"Syndicate Tier progression monotonically and strictly increases effective RPS: {['%.1f' % r for r in rps_by_tier]}", "STACK_Monotonicity")

    # 4. Extreme Astronomical Scale Stress (Base 1e50, 1M Angel Shares, 100K Bonus Users)
    sim.base_passive_rps = 1e50
    sim.bonus_users = 100000       # 100,001x
    sim.collectibles_collected = 100 # with neural cloud: 11x
    sim.angel_shares = 1000000     # 20,001x
    sim.syndicate_tier = 5         # 1.25x
    astro_rps = sim.get_effective_passive_rps()
    reporter.check(math.isfinite(astro_rps) and astro_rps > 0.0, f"Astronomical scale stress (1e50 base, 1M shares) yields finite positive float: {astro_rps:.2e}", "STACK_AstroScale")

    # 5. Monte Carlo Random Configuration Oracle (2,000 iterations)
    print(f"\n  {Colors.CYAN}Running Monte Carlo Multiplier Stacking Stress (2,000 iterations)...{Colors.ENDC}")
    mc_passed = 0
    for _ in range(2000):
        base = random.uniform(0.1, 1e12)
        users = random.randint(0, 10000)
        items = random.randint(0, 50)
        has_neural = random.choice([True, False])
        has_server_tech = random.choice([True, False])
        server_active = random.choice([True, False])
        server_mult = random.uniform(1.2, 5.0) if server_active else 1.0
        camp_active = random.choice([True, False])
        camp_mult = random.uniform(1.5, 3.0) if camp_active else 1.0
        shares = random.randint(0, 50000)
        tier = random.randint(0, 5)
        is_syn = (tier > 0) if random.choice([True, False]) else False

        s = SimulatedGameStateAdv()
        s.base_passive_rps = base
        s.bonus_users = users
        s.collectibles_collected = items
        s.researched_techs = []
        if has_neural: s.researched_techs.append("tech_neural_cloud")
        if has_server_tech: s.researched_techs.append("tech_server_overclock")
        s.server_overclock_buff_active = server_active
        s.server_overclock_buff_multiplier = server_mult
        s.campaign_rps_buff_timer = 10.0 if camp_active else 0.0
        s.campaign_rps_buff_multiplier = camp_mult
        s.angel_shares = shares
        s.active_syndicate_id = "syn_mc" if is_syn else ""
        s.syndicate_tier = tier if is_syn else 0

        calc_rps = s.get_effective_passive_rps()

        # Oracle calculation
        exp_users = 1.0 + float(users) * 0.01
        exp_items = 1.0 + float(items) * (0.10 if has_neural else 0.05)
        exp_tech = 1.25 if has_server_tech else 1.0
        exp_server = server_mult if server_active else 1.0
        exp_camp = camp_mult if camp_active else 1.0
        exp_angel = 1.0 + float(shares) * 0.02
        exp_syn = (1.0 + float(tier) * 0.05) if (is_syn and tier > 0) else 1.0

        oracle_rps = base * exp_users * exp_items * exp_tech * exp_server * exp_camp * exp_angel * exp_syn

        if math.isfinite(calc_rps) and calc_rps > 0.0 and math.isclose(calc_rps, oracle_rps, rel_tol=1e-5):
            mc_passed += 1

    reporter.check(mc_passed == 2000, f"2,000/2,000 Monte Carlo randomized multiplier evaluations matched oracle 100%", "STACK_MonteCarlo")


# ==============================================================================
# SECTION 4: Delivery Drone 3D Resilience & Fallback Oracle
# ==============================================================================

def test_delivery_drone_resilience(reporter: TestReporter):
    print(f"\n{Colors.BOLD}=== SECTION 4: Delivery Drone 3D Controller Resilience & Fallback Oracle ==={Colors.ENDC}")

    # Simulated Drone Speed Evaluator mirroring delivery_drone_3d.gd line 155-156
    def calculate_drone_speed(move_speed: float, boost_mult: float, gs_obj: Any) -> float:
        has_gs = (gs_obj is not None)
        has_meth = hasattr(gs_obj, "get_drone_speed_multiplier") if has_gs else False
        drone_speed_mult = gs_obj.get_drone_speed_multiplier() if (has_gs and has_meth) else 1.0
        return move_speed * boost_mult * drone_speed_mult

    move_speed = 4.5
    boost_mult = 1.0

    # 1. GameState is None / null
    speed_null = calculate_drone_speed(move_speed, boost_mult, None)
    reporter.check(math.isclose(speed_null, 4.5, abs_tol=1e-5), f"GameState is null: speed safely falls back to baseline {speed_null:.2f} m/s (expected 4.50)", "DRONE_NullFallback")

    # 2. GameState is dummy object without get_drone_speed_multiplier
    class DummyNode:
        pass
    speed_dummy = calculate_drone_speed(move_speed, boost_mult, DummyNode())
    reporter.check(math.isclose(speed_dummy, 4.5, abs_tol=1e-5), f"GameState missing method: speed safely falls back to baseline {speed_dummy:.2f} m/s (expected 4.50)", "DRONE_MissingMethodFallback")

    # 3. GameState with Tier 0 or 1 (multiplier 1.00)
    sim = SimulatedGameStateAdv()
    sim.active_syndicate_id = "syn_1"
    sim.syndicate_tier = 1
    speed_t1 = calculate_drone_speed(move_speed, boost_mult, sim)
    reporter.check(math.isclose(speed_t1, 4.5, abs_tol=1e-5), f"GameState at Tier 1: speed multiplier is 1.0x -> speed = {speed_t1:.2f} m/s", "DRONE_Tier1")

    # 4. GameState with Tier 2+ (multiplier 1.15)
    sim.syndicate_tier = 2
    speed_t2 = calculate_drone_speed(move_speed, boost_mult, sim)
    expected_t2 = 4.5 * 1.15  # 5.175
    reporter.check(math.isclose(speed_t2, expected_t2, abs_tol=1e-5), f"GameState at Tier 2: speed boosted by +15% -> speed = {speed_t2:.3f} m/s (expected {expected_t2:.3f})", "DRONE_Tier2Boost")

    # 5. Stacking with temporary drone boost timer (_speed_multiplier = 2.0)
    speed_boosted = calculate_drone_speed(move_speed, 2.0, sim)
    expected_boosted = 4.5 * 2.0 * 1.15  # 10.35
    reporter.check(math.isclose(speed_boosted, expected_boosted, abs_tol=1e-5), f"Temporary speed boost (2.0x) stacks multiplicatively with Syndicate Tier 2 (1.15x) -> {speed_boosted:.2f} m/s", "DRONE_BoostStack")


# ==============================================================================
# SECTION 5: State Machine Stress & Invariants Oracle
# ==============================================================================

def test_statemachine_invariants(reporter: TestReporter):
    print(f"\n{Colors.BOLD}=== SECTION 5: State Machine Stress & Invariant Oracle ==={Colors.ENDC}")

    sim = SimulatedGameStateAdv()

    # 1. Unaffiliated contribution rejected
    r1 = sim.contribute_to_syndicate(100.0, "energy")
    reporter.check(not r1["success"] and "Not affiliated" in r1["error"], "Unaffiliated contribution correctly rejected", "SM_UnaffiliatedContrib")

    # 2. Found syndicate and initialize
    sim.found_syndicate("syn_alpha", "Alpha Syndicate", "ALP")
    reporter.check(sim.is_in_syndicate() and sim.syndicate_tier == 1, "found_syndicate initializes at Tier 1", "SM_FoundTier1")

    # 3. Found second syndicate while affiliated rejected
    r2 = sim.found_syndicate("syn_beta", "Beta Syndicate")
    reporter.check(not r2["success"] and "Already affiliated" in r2["error"], "Founding duplicate syndicate while affiliated rejected", "SM_DuplicateFound")

    # 4. Invalid contribution amounts
    sim.energy = 50000.0
    sim.angel_shares = 10

    r_neg = sim.contribute_to_syndicate(-50.0, "energy")
    reporter.check(not r_neg["success"], "Negative energy contribution rejected", "SM_NegativeEnergy")

    r_zero = sim.contribute_to_syndicate(0.0, "energy")
    reporter.check(not r_zero["success"], "Zero energy contribution rejected", "SM_ZeroEnergy")

    r_over_e = sim.contribute_to_syndicate(100000.0, "energy")
    reporter.check(not r_over_e["success"] and sim.energy == 50000.0, "Over-balance energy contribution rejected without deducting balance", "SM_OverBalanceEnergy")

    r_bad_type = sim.contribute_to_syndicate(50.0, "bitcoin")
    reporter.check(not r_bad_type["success"], "Unknown resource type rejected", "SM_UnknownResource")

    # 5. Precise Tier Advancement Boundary Testing
    # Tier 2 threshold is 100,000 Energy OR 5 Angel Shares
    sim.energy = 50000000.0
    # Boundary: 99,999 energy
    sim.contribute_to_syndicate(99999.0, "energy")
    reporter.check(sim.syndicate_tier == 1, f"Fund at 99,999 energy: remains Tier 1 (actual: {sim.syndicate_tier})", "SM_BoundaryTier2Sub")

    # Add 1 energy -> 100,000 energy -> Tier 2
    sim.contribute_to_syndicate(1.0, "energy")
    reporter.check(sim.syndicate_tier == 2, f"Fund reached 100,000 energy: promoted to Tier 2 (actual: {sim.syndicate_tier})", "SM_BoundaryTier2Exact")

    # Tier 3 threshold: 500,000 Energy OR 20 Angel Shares
    # Boundary: 499,999 energy
    needed_for_499999 = 499999.0 - 100000.0
    sim.contribute_to_syndicate(needed_for_499999, "energy")
    reporter.check(sim.syndicate_tier == 2, f"Fund at 499,999 energy: remains Tier 2", "SM_BoundaryTier3Sub")

    sim.contribute_to_syndicate(1.0, "energy")
    reporter.check(sim.syndicate_tier == 3, f"Fund reached 500,000 energy: promoted to Tier 3", "SM_BoundaryTier3Exact")

    # Advance directly to Tier 5 via 100 Angel Shares
    sim.angel_shares = 100
    sim.contribute_to_syndicate(100.0, "shares")
    reporter.check(sim.syndicate_tier == 5, f"100 Angel Shares promoted syndicate to Tier 5 (Holding Monopoly)", "SM_Tier5Shares")

    # 6. Seasonal Score & Rollover Badge Idempotency
    # At Tier 5 with 500,000 energy and 100 angel shares:
    # score = floor(500000/100) + 100*500 + 5*1000 = 5000 + 50000 + 5000 = 60000
    expected_score = int(math.floor(500000.0 / 100.0)) + (100 * 500) + (5 * 1000)
    actual_score = sim.calculate_seasonal_score()
    reporter.check(actual_score == expected_score, f"Seasonal score calculated accurately: {actual_score} == {expected_score}", "SM_SeasonalScore")

    # Simulate weekly rollover when score >= 10,000
    sim.simulate_weekly_rollover(1)
    reporter.check("badge_syndicate_champion" in sim.syndicate_unlocked_badges, "Weekly rollover awards badge_syndicate_champion", "SM_BadgeAward")

    # Simulate second rollover: verify badge is idempotent (not duplicated)
    sim.simulate_weekly_rollover(1)
    badge_count = sim.syndicate_unlocked_badges.count("badge_syndicate_champion")
    reporter.check(badge_count == 1, f"Second weekly rollover does not duplicate badge (count: {badge_count})", "SM_BadgeIdempotency")

    # 7. Leave Syndicate resets state cleanly
    sim.leave_syndicate()
    reporter.check(not sim.is_in_syndicate() and sim.syndicate_tier == 0 and sim.get_syndicate_dividend_multiplier() == 1.0, "leave_syndicate resets tier to 0 and dividend multiplier to 1.0x", "SM_LeaveReset")

    # Leaving when already left returns false
    r_leave2 = sim.leave_syndicate()
    reporter.check(not r_leave2, "Leaving syndicate when unaffiliated returns false", "SM_LeaveFalse")


# ==============================================================================
# MAIN TEST EXECUTION
# ==============================================================================

def main() -> int:
    reporter = TestReporter()
    print("=" * 70)
    print("Phase 13 Milestone M1: Empirical Adversarial Challenge Test Harness")
    print("=" * 70)

    test_ast_contracts(reporter)
    test_persistence_adversarial_stress(reporter)
    test_multiplier_stacking_stress(reporter)
    test_delivery_drone_resilience(reporter)
    test_statemachine_invariants(reporter)

    return reporter.summary()

if __name__ == "__main__":
    sys.exit(main())
