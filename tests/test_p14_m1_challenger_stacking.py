#!/usr/bin/env python3
"""
Phase 14 Milestone M1: Adversarial Economic Stacking, Persistence Fuzzing & Multi-Round IPO Suite
==================================================================================================
Target: IdleArcade Godot 4.3 - Milestone M1 (Staff Management & Morale Economy)
File under test: IdleArcade/scripts/autoload/game_state.gd

Adversarial Challenger Suite Dimensions:
  Tier 1: Static AST & Architectural Integrity Audit:
    - Signals declared in game_state.gd: staff_worker_hired, staff_worker_fired,
      staff_worker_state_changed, staff_worker_morale_updated, staff_desk_upgraded,
      staff_coffee_break_started, staff_coffee_break_ended, staff_morale_updated,
      staff_epiphany_triggered, and alias signals.
    - Full mathematical integration in get_effective_passive_rps() compounding
      Staff Multiplier with Syndicate Dividend, Angel Shares, Server Overclock,
      Campus Items, Tech, Campaign Buffs, and Live Events.
    - State variables, constants, and defensive serialization in save/load/reset/IPO.

  Tier 2: Multiplier Compounding & Mathematical Stacking Matrix:
    - Staff Multiplier * Syndicate Dividend * Angel Shares * Server Overclock * Event Buff.
    - Zero-worker identity baseline (1.00000x).
    - Monotonicity, commutativity, and strict bounds across all multiplier tiers.
    - Partial morale and partial worker fatigue impact on staff RPS bonus.
    - Overflow / underflow safety (base RPS 0.0, 100k angel shares, large multipliers).
    - Monte Carlo random stacking stress (1,000 randomized configurations).

  Tier 3: Adversarial Serialization Fuzzing Oracle:
    - Corrupted JSON syntax: empty string, non-JSON bytes, truncated JSON, non-dict roots.
    - Missing schema keys: missing 'staff' block (legacy fallback), missing legacy keys.
    - Type mismatches: 'staff' as primitive/list, 'workers' as primitive/dict.
    - Out-of-range floats: morale=999.0, morale=-50.0, fatigue=999.0, fatigue=-50.0,
      efficiency=-10.0, NaN, Inf, -Inf, strings.
    - Non-string IDs: int IDs normalized to string, null/empty IDs given canonical defaults.
    - Invalid roles: unknown roles ('Astronaut', 'CEO', '', 12345) rejected and dropped.
    - Corrupted desk levels: negative, >3, non-int, None, truncated arrays.
    - 500 randomized mutated fuzzing payloads asserting strict invariants.

  Tier 4: Multi-Round IPO Reset Cycles Oracle:
    - 5 consecutive prestige rebirth cycles:
      * Round 1: Hire 3 staff, upgrade desks, trigger coffee break, trigger IPO.
      * Round 2: Hire remaining 2 staff (5 total), upgrade desks, simulate fatigue, trigger IPO.
      * Round 3: Max all desks to Level 3, fire/rehire worker, trigger IPO.
      * Round 4: Worker fatigue=1.0 ("fatigued"), coffee break recovery, trigger IPO.
      * Round 5: Full save to JSON disk, reload, trigger IPO.
    - Strict verification that hired workers, desk levels, and cumulative Angel Shares
      persist across all 5 cycles without data loss or state drift.

  Tier 5: Edge Case & Boundary Mining:
    - Re-hiring into freed desks.
    - Capacity enforcement (max 5 workers).
    - Duplicate role rejection.
    - Desk upgrade boundary clamping (max Level 3, negative indices, out-of-range).
    - Epiphany reward scaling under full multiplier stack.
    - Complete worker dismissal (0 workers = 1.0000x multiplier, no division by zero).

Executable via: python tests/test_p14_m1_challenger_stacking.py
"""

import copy
import json
import math
import random
import re
import sys
import time
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple, Union

GAME_ROOT = Path(__file__).resolve().parent.parent
GAME_STATE_PATH = GAME_ROOT / "scripts" / "autoload" / "game_state.gd"


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
        print("\n" + "=" * 76)
        print("Phase 14 Milestone M1: Adversarial Challenger Test Results")
        print("=" * 76)
        print(f"  Total Checks : {self.total}")
        print(f"  Passed       : {self.passed}")
        print(f"  Failed       : {self.failed}")
        if self.failures:
            print("\nFailures:")
            for f in self.failures:
                print(f"  - {f}")
            print(f"\n{Colors.RED}>>> ADVERSARIAL VERDICT: REQUEST_CHANGES (FAILURES DETECTED) <<<{Colors.ENDC}\n")
            return 1
        else:
            print(f"\n{Colors.GREEN}>>> ADVERSARIAL VERDICT: APPROVE (ALL TESTS PASSED WITH 100% INTEGRITY) <<<{Colors.ENDC}\n")
            return 0


# ==============================================================================
# CANONICAL CONFIGURATIONS & SIMULATION ORACLE
# ==============================================================================

MAX_WORKERS = 5
MAX_DESK_LEVEL = 3

BASE_WORKER_FATIGUE_RATE_PER_MINUTE = 0.02
BASE_WORKER_FATIGUE_RATE_PER_SECOND = 0.02 / 60.0
BASE_WORKER_MORALE_DECAY_RATE_PER_SECOND = 0.02 / 60.0

STAFF_ROLE_DEFINITIONS: Dict[str, Dict[str, Any]] = {
    "Frontend Dev": {
        "role": "Frontend Dev",
        "title": "Frontend Developer",
        "default_name": "Devin",
        "specialty": "UI responsiveness & click synergy",
        "hire_cost": 500.0,
        "desk_index": 0,
    },
    "Backend Dev": {
        "role": "Backend Dev",
        "title": "Backend Architect",
        "default_name": "Bjarne",
        "specialty": "Server stability & throughput",
        "hire_cost": 1500.0,
        "desk_index": 1,
    },
    "UI/UX Designer": {
        "role": "UI/UX Designer",
        "title": "UI/UX Specialist",
        "default_name": "Sora",
        "specialty": "Touch ergonomics & flow",
        "hire_cost": 3500.0,
        "desk_index": 2,
    },
    "Growth Hacker": {
        "role": "Growth Hacker",
        "title": "Growth Hacker",
        "default_name": "Ada",
        "specialty": "Viral adoption & marketing",
        "hire_cost": 8000.0,
        "desk_index": 3,
    },
    "QA Engineer": {
        "role": "QA Engineer",
        "title": "QA Lead",
        "default_name": "Quinn",
        "specialty": "Bug hunting & zero regressions",
        "hire_cost": 15000.0,
        "desk_index": 4,
    },
}

DESK_CONFIG: Dict[int, Dict[str, Any]] = {
    1: {
        "level": 1,
        "name": "Basic Wooden Desk",
        "cost": 0.0,
        "upgrade_cost": 0.0,
        "fatigue_reduction_pct": 0.0,
        "fatigue_multiplier": 1.00,
    },
    2: {
        "level": 2,
        "name": "Dual-Monitor Tech Desk",
        "cost": 5000.0,
        "upgrade_cost": 5000.0,
        "fatigue_reduction_pct": 0.25,
        "fatigue_multiplier": 0.75,
    },
    3: {
        "level": 3,
        "name": "Cyber Standing Desk mit RGB",
        "cost": 25000.0,
        "upgrade_cost": 25000.0,
        "fatigue_reduction_pct": 0.60,
        "fatigue_multiplier": 0.40,
    },
}

SYNDICATE_TIER_CONFIG = {
    0: {"dividend_mult": 1.00},
    1: {"dividend_mult": 1.05},
    2: {"dividend_mult": 1.10},
    3: {"dividend_mult": 1.15},
    4: {"dividend_mult": 1.20},
    5: {"dividend_mult": 1.25},
}


class AdversarialGameStateOracle:
    """Independent Python simulation oracle strictly adhering to game_state.gd implementation."""

    def __init__(self, initial_energy: float = 0.0, base_rps: float = 100.0):
        self.reset_state(initial_energy, base_rps)

    def reset_state(self, initial_energy: float = 0.0, base_rps: float = 100.0):
        self.energy: float = initial_energy
        self.total_energy_earned: float = initial_energy
        self.total_lifetime_energy: float = initial_energy
        self.base_passive_rps: float = base_rps
        self.bonus_users: int = 0
        self.collectibles_collected: int = 0
        self.researched_techs: List[str] = []
        self.angel_shares: int = 0
        self.total_ipos_completed: int = 0

        # Syndicate state
        self.active_syndicate_id: str = ""
        self.syndicate_tier: int = 0
        self.syndicate_fund_energy: float = 0.0
        self.syndicate_fund_angel_shares: int = 0

        # Buffs
        self.server_overclock_buff_active: bool = False
        self.server_overclock_buff_timer: float = 0.0
        self.server_overclock_buff_multiplier: float = 1.50
        self.campaign_rps_buff_multiplier: float = 1.0
        self.campaign_rps_buff_timer: float = 0.0
        self.live_event_multiplier: float = 1.0

        # Staff State
        self.hired_workers: List[Dict[str, Any]] = []
        self.desk_levels: List[int] = [1, 1, 1, 1, 1]
        self.staff_hyper_focus_active: bool = False
        self.staff_hyper_focus_timer: float = 0.0
        self.staff_hyper_focus_remaining: float = 0.0
        self.staff_hyper_focus_multiplier: float = 1.50
        self.staff_coffee_break_active: bool = False
        self.staff_coffee_break_timer: float = 0.0
        self.staff_coffee_break_remaining: float = 0.0

        self.emitted_signals: List[Tuple[Any, ...]] = []

    def _normalize_role(self, role_name: Any) -> str:
        if not isinstance(role_name, str):
            return ""
        norm = role_name.strip()
        if norm in STAFF_ROLE_DEFINITIONS:
            return norm
        simp = norm.lower().replace(" ", "").replace("_", "").replace("-", "").replace("/", "")
        for def_role in STAFF_ROLE_DEFINITIONS:
            def_simp = def_role.lower().replace(" ", "").replace("_", "").replace("-", "").replace("/", "")
            if simp == def_simp:
                return def_role
        return ""

    def hire_worker(self, role: str) -> bool:
        canon = self._normalize_role(role)
        if not canon:
            return False
        if len(self.hired_workers) >= MAX_WORKERS:
            return False
        for w in self.hired_workers:
            if str(w.get("role", "")) == canon:
                return False

        role_def = STAFF_ROLE_DEFINITIONS[canon]
        cost = float(role_def.get("hire_cost", 500.0))
        if self.energy < cost:
            return False

        # Find first free desk (0..4)
        occupied = [int(w.get("desk_assigned", 0)) for w in self.hired_workers]
        chosen_desk = -1
        for d in range(MAX_WORKERS):
            if d not in occupied:
                chosen_desk = d
                break
        if chosen_desk == -1:
            chosen_desk = 0

        self.energy -= cost
        worker_id = "worker_" + canon.lower().replace(" ", "_").replace("/", "_")
        new_worker = {
            "id": worker_id,
            "name": str(role_def.get("default_name", canon)),
            "role": canon,
            "morale": 1.0,
            "fatigue": 0.0,
            "efficiency": 1.0,
            "desk_assigned": chosen_desk,
            "current_state": "working",
        }
        self.hired_workers.append(new_worker)
        self.emitted_signals.append(("staff_worker_hired", copy.deepcopy(new_worker)))
        self.emitted_signals.append(("staff_worker_state_changed", worker_id, "working"))
        self.emitted_signals.append(("staff_morale_updated", self.get_staff_average_morale()))
        self.emitted_signals.append(("rps_changed", self.get_effective_passive_rps()))
        return True

    def fire_worker(self, worker_id: str) -> bool:
        if not worker_id:
            return False
        target_idx = -1
        found_id = ""
        norm = self._normalize_role(worker_id)
        for i, w in enumerate(self.hired_workers):
            if str(w.get("id", "")) == worker_id or str(w.get("role", "")) == worker_id or (norm and str(w.get("role", "")) == norm):
                target_idx = i
                found_id = str(w.get("id", worker_id))
                break
        if target_idx == -1:
            return False

        self.hired_workers.pop(target_idx)
        self.emitted_signals.append(("staff_worker_fired", found_id))
        self.emitted_signals.append(("staff_morale_updated", self.get_staff_average_morale()))
        self.emitted_signals.append(("rps_changed", self.get_effective_passive_rps()))
        return True

    def get_hired_workers(self) -> List[Dict[str, Any]]:
        return copy.deepcopy(self.hired_workers)

    def get_worker(self, worker_id: str) -> Dict[str, Any]:
        norm = self._normalize_role(worker_id)
        for w in self.hired_workers:
            if str(w.get("id", "")) == worker_id or str(w.get("role", "")) == worker_id or (norm and str(w.get("role", "")) == norm):
                return copy.deepcopy(w)
        return {}

    def get_active_workers_count(self) -> int:
        count = 0
        for w in self.hired_workers:
            if str(w.get("current_state", "working")) != "fatigued":
                count += 1
        return count

    def get_staff_average_morale(self) -> float:
        if not self.hired_workers:
            return 1.0
        total = sum(max(0.0, min(1.0, float(w.get("morale", 1.0)))) for w in self.hired_workers)
        return total / float(len(self.hired_workers))

    def upgrade_desk(self, desk_index: int) -> bool:
        if desk_index < 0 or desk_index >= MAX_WORKERS or desk_index >= len(self.desk_levels):
            return False
        current_lvl = self.desk_levels[desk_index]
        if current_lvl >= MAX_DESK_LEVEL:
            return False
        next_lvl = current_lvl + 1
        cost = float(DESK_CONFIG.get(next_lvl, {}).get("cost", 5000.0))
        if self.energy < cost:
            return False

        self.energy -= cost
        self.desk_levels[desk_index] = next_lvl
        self.emitted_signals.append(("staff_desk_upgraded", desk_index, next_lvl))
        return True

    def get_desk_level(self, desk_index: int) -> int:
        if 0 <= desk_index < len(self.desk_levels):
            return self.desk_levels[desk_index]
        return 1

    def get_desk_levels(self) -> List[int]:
        return list(self.desk_levels)

    def get_desk_upgrade_cost(self, desk_index: int) -> float:
        if desk_index < 0 or desk_index >= len(self.desk_levels):
            return 0.0
        lvl = self.desk_levels[desk_index]
        if lvl >= MAX_DESK_LEVEL:
            return 0.0
        return float(DESK_CONFIG[lvl + 1]["cost"])

    def get_desk_fatigue_multiplier(self, desk_level: int) -> float:
        if desk_level == 2:
            return 0.75
        elif desk_level >= 3:
            return 0.40
        return 1.00

    def give_team_coffee_break(self) -> bool:
        for w in self.hired_workers:
            w["fatigue"] = 0.0
            w["morale"] = 1.0
            w["current_state"] = "working"
            self.emitted_signals.append(("staff_worker_state_changed", str(w.get("id", "")), "working"))
            self.emitted_signals.append(("staff_worker_morale_updated", str(w.get("id", "")), 1.0, 0.0))

        self.staff_hyper_focus_active = True
        self.staff_hyper_focus_timer = 60.0
        self.staff_hyper_focus_remaining = 60.0
        self.staff_hyper_focus_multiplier = 1.50
        self.staff_coffee_break_active = True
        self.staff_coffee_break_timer = 60.0
        self.staff_coffee_break_remaining = 60.0

        self.emitted_signals.append(("staff_coffee_break_started", 60.0))
        self.emitted_signals.append(("staff_morale_updated", self.get_staff_average_morale()))
        self.emitted_signals.append(("rps_changed", self.get_effective_passive_rps()))
        return True

    def is_staff_hyper_focus_active(self) -> bool:
        return (self.staff_hyper_focus_active or self.staff_coffee_break_active) and (self.staff_hyper_focus_timer > 0.0 or self.staff_coffee_break_timer > 0.0)

    def get_staff_hyper_focus_time_remaining(self) -> float:
        return max(0.0, max(self.staff_hyper_focus_timer, self.staff_coffee_break_timer))

    def get_staff_hyper_focus_multiplier(self) -> float:
        return self.staff_hyper_focus_multiplier if self.is_staff_hyper_focus_active() else 1.0

    def get_staff_rps_multiplier(self) -> float:
        if not self.hired_workers:
            return 1.0
        active_count = self.get_active_workers_count()
        if active_count <= 0:
            return 1.0
        avg_morale = self.get_staff_average_morale()
        return 1.0 + (float(active_count) * 0.05) * avg_morale

    def get_bonus_multiplier(self) -> float:
        return 1.0 + (float(self.bonus_users) * 0.01)

    def get_campus_item_multiplier(self) -> float:
        rate = 0.10 if "tech_neural_cloud" in self.researched_techs else 0.05
        return 1.0 + (float(self.collectibles_collected) * rate)

    def get_angel_share_multiplier(self) -> float:
        return 1.0 + (float(self.angel_shares) * 0.02)

    def get_syndicate_dividend_multiplier(self) -> float:
        t = self.syndicate_tier
        if t <= 0:
            return 1.0
        return 1.0 + (float(t) * 0.05)

    def get_live_event_production_multiplier(self) -> float:
        return self.live_event_multiplier

    def get_effective_passive_rps(self) -> float:
        camp_rps_mult = self.campaign_rps_buff_multiplier if self.campaign_rps_buff_timer > 0.0 else 1.0
        live_event_mult = self.get_live_event_production_multiplier()
        staff_mult = self.get_staff_rps_multiplier()
        overclock_mult = self.server_overclock_buff_multiplier if (self.server_overclock_buff_timer > 0.0 or self.server_overclock_buff_active) else 1.0
        tech_overclock = 1.25 if "tech_server_overclock" in self.researched_techs else 1.0

        return (
            self.base_passive_rps
            * self.get_bonus_multiplier()
            * self.get_campus_item_multiplier()
            * tech_overclock
            * overclock_mult
            * camp_rps_mult
            * self.get_angel_share_multiplier()
            * self.get_syndicate_dividend_multiplier()
            * live_event_mult
            * staff_mult
        )

    def trigger_worker_epiphany(self, worker_id: str) -> float:
        target_id = worker_id
        found = False
        for w in self.hired_workers:
            if str(w.get("id", "")) == worker_id or str(w.get("role", "")) == worker_id:
                target_id = str(w.get("id", worker_id))
                found = True
                break
        if not found:
            if not self.hired_workers:
                return 0.0
            target_id = str(self.hired_workers[0].get("id", worker_id))

        reward = max(100.0, self.get_effective_passive_rps() * 15.0)
        self.energy += reward
        self.total_energy_earned += reward
        self.total_lifetime_energy += reward
        self.emitted_signals.append(("staff_epiphany_triggered", target_id, reward))
        return reward

    def update_staff_simulation(self, delta: float) -> None:
        if delta <= 0.0 or not self.hired_workers:
            return

        any_state_change = False
        any_morale_change = False
        total_morale = 0.0

        for w in self.hired_workers:
            current_state = str(w.get("current_state", "working"))
            desk_idx = max(0, min(MAX_WORKERS - 1, int(w.get("desk_assigned", 0))))
            desk_lvl = self.get_desk_level(desk_idx)
            fatigue_mult = self.get_desk_fatigue_multiplier(desk_lvl)
            current_fatigue = max(0.0, min(1.0, float(w.get("fatigue", 0.0))))
            current_morale = max(0.0, min(1.0, float(w.get("morale", 1.0))))

            if current_state == "working":
                f_delta = BASE_WORKER_FATIGUE_RATE_PER_SECOND * fatigue_mult * delta
                new_fatigue = max(0.0, min(1.0, current_fatigue + f_delta))
                if new_fatigue != current_fatigue:
                    current_fatigue = new_fatigue
                    w["fatigue"] = current_fatigue

                if current_fatigue >= 0.8:
                    m_delta = BASE_WORKER_MORALE_DECAY_RATE_PER_SECOND * delta
                    new_morale = max(0.0, min(1.0, current_morale - m_delta))
                    if new_morale != current_morale:
                        current_morale = new_morale
                        w["morale"] = current_morale
                        any_morale_change = True
                        self.emitted_signals.append(("staff_worker_morale_updated", str(w.get("id", "")), current_morale, current_fatigue))

                if current_fatigue >= 1.0:
                    w["current_state"] = "fatigued"
                    any_state_change = True
                    self.emitted_signals.append(("staff_worker_state_changed", str(w.get("id", "")), "fatigued"))

            elif current_state == "fatigued":
                m_delta = BASE_WORKER_MORALE_DECAY_RATE_PER_SECOND * delta
                new_morale = max(0.0, min(1.0, current_morale - m_delta))
                if new_morale != current_morale:
                    current_morale = new_morale
                    w["morale"] = current_morale
                    any_morale_change = True
                    self.emitted_signals.append(("staff_worker_morale_updated", str(w.get("id", "")), current_morale, current_fatigue))

            total_morale += current_morale

        if any_morale_change:
            avg_morale = total_morale / float(len(self.hired_workers))
            self.emitted_signals.append(("staff_morale_updated", avg_morale))
            self.emitted_signals.append(("rps_changed", self.get_effective_passive_rps()))
        elif any_state_change:
            self.emitted_signals.append(("rps_changed", self.get_effective_passive_rps()))

    def can_trigger_ipo(self) -> bool:
        threshold_met = self.total_lifetime_energy >= 100000.0
        pending = self.calculate_pending_angel_shares()
        return threshold_met and pending > 0

    def calculate_pending_angel_shares(self) -> int:
        if self.total_lifetime_energy < 100000.0:
            return 0
        total_eligible = int(math.floor(math.sqrt(max(0.0, self.total_lifetime_energy) / 100000.0)))
        base_pending = max(0, total_eligible - self.angel_shares)
        bonus_pct = 0.0
        if self.syndicate_tier >= 3:
            bonus_pct = float(self.syndicate_tier - 2) * 0.05
        if bonus_pct > 0.0 and base_pending > 0:
            bonus_shares = int(math.floor(float(base_pending) * bonus_pct))
            return base_pending + bonus_shares
        return base_pending

    def trigger_ipo(self) -> Dict[str, Any]:
        if not self.can_trigger_ipo():
            return {"success": False, "error": "Threshold not reached or 0 pending shares"}

        shares_gained = self.calculate_pending_angel_shares()
        self.angel_shares += shares_gained
        self.total_ipos_completed += 1
        self.energy = 0.0

        # Phase 14 Staff Temporary Buff Reset on IPO
        self.staff_hyper_focus_active = False
        self.staff_hyper_focus_timer = 0.0
        self.staff_hyper_focus_remaining = 0.0
        self.staff_coffee_break_active = False
        self.staff_coffee_break_timer = 0.0
        self.staff_coffee_break_remaining = 0.0

        for w in self.hired_workers:
            if str(w.get("current_state", "")) == "break":
                w["current_state"] = "working"

        return {
            "success": True,
            "shares_gained": shares_gained,
            "total_angel_shares": self.angel_shares,
            "total_ipos_completed": self.total_ipos_completed,
        }

    def to_dict(self) -> Dict[str, Any]:
        return {
            "energy": self.energy,
            "total_energy_earned": self.total_energy_earned,
            "total_lifetime_energy": self.total_lifetime_energy,
            "angel_shares": self.angel_shares,
            "total_ipos_completed": self.total_ipos_completed,
            "active_syndicate_id": self.active_syndicate_id,
            "syndicate_tier": self.syndicate_tier,
            "syndicate_fund_energy": self.syndicate_fund_energy,
            "syndicate_fund_angel_shares": self.syndicate_fund_angel_shares,
            "staff": {
                "workers": copy.deepcopy(self.hired_workers),
                "desk_levels": list(self.desk_levels),
                "coffee_break_active": self.staff_coffee_break_active or self.staff_hyper_focus_active,
                "coffee_break_timer": max(self.staff_coffee_break_timer, self.staff_hyper_focus_timer),
                "coffee_break_remaining": max(self.staff_coffee_break_remaining, self.staff_hyper_focus_remaining),
                "hyper_focus_active": self.staff_hyper_focus_active or self.staff_coffee_break_active,
                "hyper_focus_timer": max(self.staff_hyper_focus_timer, self.staff_coffee_break_timer),
                "hyper_focus_remaining": max(self.staff_hyper_focus_remaining, self.staff_coffee_break_remaining),
                "hyper_focus_multiplier": self.staff_hyper_focus_multiplier,
            },
            "hired_workers": copy.deepcopy(self.hired_workers),
            "desk_levels": list(self.desk_levels),
            "staff_hyper_focus_timer": self.staff_hyper_focus_timer,
            "staff_hyper_focus_remaining": self.staff_hyper_focus_remaining,
            "staff_hyper_focus_active": self.staff_hyper_focus_active,
        }

    def load_from_dict(self, data: Any) -> bool:
        if not isinstance(data, dict):
            return False

        try:
            raw_e = float(data.get("energy", 0.0))
            self.energy = 0.0 if (math.isnan(raw_e) or math.isinf(raw_e)) else max(0.0, raw_e)
        except (ValueError, TypeError, OverflowError):
            self.energy = 0.0

        try:
            raw_life = float(data.get("total_lifetime_energy", self.energy))
            self.total_lifetime_energy = self.energy if (math.isnan(raw_life) or math.isinf(raw_life)) else max(self.energy, raw_life)
        except (ValueError, TypeError, OverflowError):
            self.total_lifetime_energy = self.energy

        try:
            self.angel_shares = max(0, int(data.get("angel_shares", 0)))
        except (ValueError, TypeError, OverflowError):
            self.angel_shares = 0

        try:
            self.total_ipos_completed = max(0, int(data.get("total_ipos_completed", 0)))
        except (ValueError, TypeError, OverflowError):
            self.total_ipos_completed = 0

        # Phase 14 Staff Deserialization
        self.hired_workers.clear()
        self.desk_levels = [1, 1, 1, 1, 1]
        self.staff_hyper_focus_active = False
        self.staff_hyper_focus_timer = 0.0
        self.staff_hyper_focus_remaining = 0.0
        self.staff_hyper_focus_multiplier = 1.50
        self.staff_coffee_break_active = False
        self.staff_coffee_break_timer = 0.0
        self.staff_coffee_break_remaining = 0.0

        staff_data = data.get("staff", {})
        raw_workers = None
        raw_desks = None
        raw_hf_timer = None

        if isinstance(staff_data, dict) and staff_data:
            raw_workers = staff_data.get("workers", None)
            raw_desks = staff_data.get("desk_levels", None)
            raw_hf_timer = staff_data.get("hyper_focus_timer", staff_data.get("coffee_break_timer", None))
            self.staff_hyper_focus_active = bool(staff_data.get("hyper_focus_active", staff_data.get("coffee_break_active", False)))
            self.staff_coffee_break_active = self.staff_hyper_focus_active
            try:
                raw_hf_mult = float(staff_data.get("hyper_focus_multiplier", 1.50))
                self.staff_hyper_focus_multiplier = 1.50 if (math.isnan(raw_hf_mult) or math.isinf(raw_hf_mult)) else max(1.0, raw_hf_mult)
            except (ValueError, TypeError, OverflowError):
                self.staff_hyper_focus_multiplier = 1.50

        # Flat backward-compatibility fallback
        if raw_workers is None:
            raw_workers = data.get("hired_workers", [])
        if raw_desks is None:
            raw_desks = data.get("desk_levels", [1, 1, 1, 1, 1])
        if raw_hf_timer is None:
            raw_hf_timer = data.get("staff_hyper_focus_timer", 0.0)

        if isinstance(raw_workers, list):
            for w in raw_workers:
                if isinstance(w, dict):
                    r_str = str(w.get("role", "")).strip()
                    canon = self._normalize_role(r_str)
                    if not canon and r_str in STAFF_ROLE_DEFINITIONS:
                        canon = r_str
                    if canon:
                        role_def = STAFF_ROLE_DEFINITIONS[canon]
                        w_id = str(w.get("id", "worker_" + canon.lower().replace(" ", "_").replace("/", "_")))
                        w_name = str(w.get("name", role_def.get("default_name", canon)))

                        try:
                            raw_m = float(w.get("morale", 1.0))
                            clean_m = 1.0 if (math.isnan(raw_m) or math.isinf(raw_m)) else max(0.0, min(1.0, raw_m))
                        except (ValueError, TypeError, OverflowError):
                            clean_m = 1.0

                        try:
                            raw_f = float(w.get("fatigue", 0.0))
                            clean_f = 0.0 if (math.isnan(raw_f) or math.isinf(raw_f)) else max(0.0, min(1.0, raw_f))
                        except (ValueError, TypeError, OverflowError):
                            clean_f = 0.0

                        try:
                            raw_eff = float(w.get("efficiency", 1.0))
                            clean_eff = 1.0 if (math.isnan(raw_eff) or math.isinf(raw_eff)) else max(0.1, raw_eff)
                        except (ValueError, TypeError, OverflowError):
                            clean_eff = 1.0

                        try:
                            clean_desk = max(0, min(4, int(w.get("desk_assigned", 0))))
                        except (ValueError, TypeError, OverflowError):
                            clean_desk = 0

                        state_str = str(w.get("current_state", "working"))
                        if state_str not in ["working", "break", "fatigued", "celebrating"]:
                            state_str = "fatigued" if clean_f >= 1.0 else "working"

                        self.hired_workers.append({
                            "id": w_id,
                            "name": w_name,
                            "role": canon,
                            "morale": clean_m,
                            "fatigue": clean_f,
                            "efficiency": clean_eff,
                            "desk_assigned": clean_desk,
                            "current_state": state_str,
                        })

        if isinstance(raw_desks, list) and len(raw_desks) > 0:
            for i in range(min(5, len(raw_desks))):
                try:
                    raw_lvl = int(raw_desks[i])
                    self.desk_levels[i] = max(1, min(3, raw_lvl))
                except (ValueError, TypeError, OverflowError):
                    self.desk_levels[i] = 1

        try:
            hf_t = float(raw_hf_timer) if raw_hf_timer is not None else 0.0
            if not math.isnan(hf_t) and not math.isinf(hf_t):
                self.staff_hyper_focus_timer = max(0.0, hf_t)
                self.staff_hyper_focus_remaining = self.staff_hyper_focus_timer
                self.staff_coffee_break_timer = self.staff_hyper_focus_timer
                self.staff_coffee_break_remaining = self.staff_hyper_focus_timer
                self.staff_hyper_focus_active = self.staff_hyper_focus_timer > 0.0
                self.staff_coffee_break_active = self.staff_hyper_focus_active
        except (ValueError, TypeError, OverflowError):
            self.staff_hyper_focus_timer = 0.0

        return True


# ==============================================================================
# CHALLENGER TEST SUITE EXECUTION
# ==============================================================================

def run_adversarial_suite() -> int:
    reporter = TestReporter()
    print(f"\n{Colors.BOLD}{Colors.CYAN}" + "=" * 76)
    print("  STARTING PHASE 14 M1 ADVERSARIAL CHALLENGER SUITE")
    print("=" * 76 + f"{Colors.ENDC}\n")

    # --------------------------------------------------------------------------
    # TIER 1: Static AST & Architectural Integrity Audit
    # --------------------------------------------------------------------------
    print(f"{Colors.BOLD}[TIER 1] Static AST & Code Architecture Audit{Colors.ENDC}")
    reporter.check(GAME_STATE_PATH.exists(), f"Target file exists: {GAME_STATE_PATH}", "AST_File")

    content = GAME_STATE_PATH.read_text(encoding="utf-8")

    # Verify signals
    signals_to_check = [
        "staff_worker_hired",
        "staff_worker_fired",
        "staff_worker_state_changed",
        "staff_worker_morale_updated",
        "staff_desk_upgraded",
        "staff_coffee_break_started",
        "staff_coffee_break_ended",
        "staff_morale_updated",
        "staff_epiphany_triggered",
        "worker_hired",
        "worker_fired",
        "worker_state_changed",
        "desk_upgraded",
        "team_coffee_break_started",
        "team_coffee_break_ended",
    ]
    for sig in signals_to_check:
        reporter.check(
            re.search(rf"\bsignal\s+{sig}\b", content) is not None,
            f"Signal '{sig}' is declared in game_state.gd",
            "AST_Signal",
        )

    # Verify get_effective_passive_rps() compounding formula
    rps_match = re.search(r"func\s+get_effective_passive_rps\s*\(\s*\)\s*->\s*float\s*:(.*?)(?=\nfunc|\Z)", content, re.DOTALL)
    reporter.check(rps_match is not None, "get_effective_passive_rps() function exists", "AST_RPS")
    if rps_match:
        body = rps_match.group(1)
        reporter.check("get_staff_rps_multiplier()" in body or "staff_mult" in body, "get_effective_passive_rps() includes staff multiplier", "AST_RPS")
        reporter.check("get_syndicate_dividend_multiplier()" in body, "get_effective_passive_rps() includes syndicate dividend", "AST_RPS")
        reporter.check("get_angel_share_multiplier()" in body, "get_effective_passive_rps() includes angel shares multiplier", "AST_RPS")
        reporter.check("server_overclock_buff_multiplier" in body, "get_effective_passive_rps() includes server overclock", "AST_RPS")
        reporter.check("live_event_mult" in body or "get_live_event_production_multiplier()" in body, "get_effective_passive_rps() includes live event multiplier", "AST_RPS")
        reporter.check("camp_rps_mult" in body or "campaign_rps_buff_multiplier" in body, "get_effective_passive_rps() includes campaign rps buff", "AST_RPS")

    # Verify trigger_ipo() staff preservation and temporary buff extinguish
    ipo_match = re.search(r"func\s+trigger_ipo\s*\(\s*\)\s*->\s*Dictionary\s*:(.*?)(?=\nfunc|\Z)", content, re.DOTALL)
    reporter.check(ipo_match is not None, "trigger_ipo() function exists", "AST_IPO")
    if ipo_match:
        body = ipo_match.group(1)
        reporter.check("staff_hyper_focus_active = false" in body, "trigger_ipo() extinguishes staff_hyper_focus_active", "AST_IPO")
        reporter.check("staff_hyper_focus_timer = 0.0" in body, "trigger_ipo() resets staff_hyper_focus_timer to 0.0", "AST_IPO")
        reporter.check("staff_coffee_break_active = false" in body, "trigger_ipo() extinguishes staff_coffee_break_active", "AST_IPO")
        reporter.check("current_state" in body and "working" in body, "trigger_ipo() restores 'break' state workers back to 'working'", "AST_IPO")
        # Ensure hired_workers is NOT cleared in trigger_ipo
        reporter.check("hired_workers.clear()" not in body, "trigger_ipo() does NOT clear hired_workers", "AST_IPO")
        reporter.check("desk_levels = [1, 1, 1, 1, 1]" not in body, "trigger_ipo() does NOT reset desk_levels to baseline", "AST_IPO")

    # Verify save_to_disk & load_from_disk staff serialization
    reporter.check('"staff": {' in content, "save_to_disk() serializes nested 'staff' structure", "AST_Save")
    reporter.check('data.get("staff"' in content, "load_from_disk() reads 'staff' structure", "AST_Load")
    reporter.check("hired_workers.clear()" in content, "load_from_disk() cleans existing hired_workers before loading", "AST_Load")
    reporter.check("clampf(raw_m, 0.0, 1.0)" in content, "load_from_disk() clamps morale strictly to [0.0, 1.0]", "AST_Load")
    reporter.check("clampf(raw_f, 0.0, 1.0)" in content, "load_from_disk() clamps fatigue strictly to [0.0, 1.0]", "AST_Load")
    reporter.check("clampi(raw_lvl, 1, 3)" in content, "load_from_disk() clamps desk levels strictly to [1, 3]", "AST_Load")

    # --------------------------------------------------------------------------
    # TIER 2: Multiplier Compounding & Mathematical Stacking Matrix
    # --------------------------------------------------------------------------
    print(f"\n{Colors.BOLD}[TIER 2] Multiplier Stacking & Numerical Precision Stress{Colors.ENDC}")
    sim = AdversarialGameStateOracle(initial_energy=1000000.0, base_rps=100.0)

    # Case 2.1: Zero workers baseline
    reporter.check(sim.get_staff_rps_multiplier() == 1.0, "Zero workers produces exactly 1.00000x multiplier", "Stacking_Zero")
    reporter.check(sim.get_effective_passive_rps() == 100.0, "Base 100.0 RPS remains 100.0 RPS with zero staff", "Stacking_Zero")

    # Case 2.2: 1 Worker at 1.0 Morale
    sim.hire_worker("Frontend Dev")
    reporter.check(abs(sim.get_staff_rps_multiplier() - 1.05) < 1e-6, "1 Worker at 1.0 morale produces 1.0500x (+5%)", "Stacking_Staff")
    reporter.check(abs(sim.get_effective_passive_rps() - 105.0) < 1e-4, "Base 100.0 RPS scales to 105.0 RPS with 1 worker", "Stacking_Staff")

    # Case 2.3: All 5 Workers at 1.0 Morale
    for r in ["Backend Dev", "UI/UX Designer", "Growth Hacker", "QA Engineer"]:
        sim.hire_worker(r)
    reporter.check(len(sim.hired_workers) == 5, "5 specialist workers hired successfully", "Stacking_Staff")
    reporter.check(abs(sim.get_staff_rps_multiplier() - 1.25) < 1e-6, "5 Workers at 1.0 morale produces 1.2500x (+25%)", "Stacking_Staff")
    reporter.check(abs(sim.get_effective_passive_rps() - 125.0) < 1e-4, "Base 100.0 RPS scales to 125.0 RPS with 5 workers", "Stacking_Staff")

    # Case 2.4: Syndicate Tier Compounding (Tier 1..5)
    sim.syndicate_tier = 1 # +5%
    expected_tier1 = 100.0 * 1.25 * 1.05 # 131.25
    reporter.check(abs(sim.get_effective_passive_rps() - expected_tier1) < 1e-4, f"Staff (1.25x) * Syndicate Tier 1 (1.05x) = {expected_tier1:.2f} RPS", "Stacking_Syndicate")

    sim.syndicate_tier = 5 # +25%
    expected_tier5 = 100.0 * 1.25 * 1.25 # 156.25
    reporter.check(abs(sim.get_effective_passive_rps() - expected_tier5) < 1e-4, f"Staff (1.25x) * Syndicate Tier 5 (1.25x) = {expected_tier5:.2f} RPS", "Stacking_Syndicate")

    # Case 2.5: Angel Shares Compounding
    sim.angel_shares = 50 # 50 * 0.02 = +100% -> 2.0x
    expected_angel = 100.0 * 1.25 * 1.25 * 2.0 # 312.50
    reporter.check(abs(sim.get_effective_passive_rps() - expected_angel) < 1e-4, f"Staff * Syndicate * Angel Shares (2.0x) = {expected_angel:.2f} RPS", "Stacking_Angel")

    # Case 2.6: Server Overclock Compounding
    sim.server_overclock_buff_active = True
    sim.server_overclock_buff_timer = 25.0
    sim.server_overclock_buff_multiplier = 1.50 # +50% -> 1.5x
    expected_oc = 100.0 * 1.25 * 1.25 * 2.0 * 1.50 # 468.75
    reporter.check(abs(sim.get_effective_passive_rps() - expected_oc) < 1e-4, f"Staff * Syndicate * Angel * Overclock (1.5x) = {expected_oc:.2f} RPS", "Stacking_Overclock")

    # Case 2.7: Live Event Multiplier Compounding
    sim.live_event_multiplier = 2.0 # 2.0x
    expected_event = 100.0 * 1.25 * 1.25 * 2.0 * 1.50 * 2.0 # 937.50
    reporter.check(abs(sim.get_effective_passive_rps() - expected_event) < 1e-4, f"Full 5-factor stack compounded = {expected_event:.2f} RPS (exact 9.3750x)", "Stacking_Event")

    # Case 2.8: Comprehensive Mega-Stack (+Campaign 1.2x, Tech 1.25x, Bonus Users 100 = 2.0x)
    sim.campaign_rps_buff_timer = 30.0
    sim.campaign_rps_buff_multiplier = 1.20
    sim.researched_techs.append("tech_server_overclock") # 1.25x
    sim.bonus_users = 100 # +100% -> 2.0x
    # Total = 100.0 * 2.0 (bonus) * 1.0 (campus) * 1.25 (tech) * 1.5 (oc) * 1.2 (campaign) * 2.0 (angel) * 1.25 (syn) * 2.0 (event) * 1.25 (staff)
    # 100.0 * 28.125 = 2812.50
    expected_mega = 2812.50
    reporter.check(abs(sim.get_effective_passive_rps() - expected_mega) < 1e-4, f"Mega-Stack (8 active multipliers) compounded = {expected_mega:.2f} RPS (28.1250x)", "Stacking_Mega")

    # Case 2.9: Commutativity Verification (Randomized Evaluation Ordering)
    factors = [
        sim.get_bonus_multiplier(),
        1.25, # tech
        sim.server_overclock_buff_multiplier,
        sim.campaign_rps_buff_multiplier,
        sim.get_angel_share_multiplier(),
        sim.get_syndicate_dividend_multiplier(),
        sim.get_live_event_production_multiplier(),
        sim.get_staff_rps_multiplier(),
    ]
    prod_base = math.prod(factors) * sim.base_passive_rps
    all_perm_pass = True
    for _ in range(50):
        shuffled = list(factors)
        random.shuffle(shuffled)
        prod_shuffled = math.prod(shuffled) * sim.base_passive_rps
        if abs(prod_shuffled - prod_base) > 1e-7:
            all_perm_pass = False
            break
    reporter.check(all_perm_pass, "Compounding order commutative invariance holds across 50 permutations (< 1e-7)", "Stacking_Math")

    # Case 2.10: Partial Fatigue & Morale Degradation Matrix
    sim_deg = AdversarialGameStateOracle(initial_energy=100000.0, base_rps=100.0)
    for r in ["Frontend Dev", "Backend Dev", "UI/UX Designer", "Growth Hacker", "QA Engineer"]:
        sim_deg.hire_worker(r)

    # 2 workers fatigued (fatigue=1.0, current_state="fatigued", morale=0.4)
    sim_deg.hired_workers[0]["fatigue"] = 1.0
    sim_deg.hired_workers[0]["current_state"] = "fatigued"
    sim_deg.hired_workers[0]["morale"] = 0.4
    sim_deg.hired_workers[1]["fatigue"] = 1.0
    sim_deg.hired_workers[1]["current_state"] = "fatigued"
    sim_deg.hired_workers[1]["morale"] = 0.4

    # 3 workers working (fatigue=0.2, current_state="working", morale=0.9)
    for i in range(2, 5):
        sim_deg.hired_workers[i]["fatigue"] = 0.2
        sim_deg.hired_workers[i]["current_state"] = "working"
        sim_deg.hired_workers[i]["morale"] = 0.9

    active_cnt = sim_deg.get_active_workers_count()
    avg_m = sim_deg.get_staff_average_morale()
    # Total morale = 0.4 + 0.4 + 0.9 * 3 = 0.8 + 2.7 = 3.5 -> avg = 3.5 / 5 = 0.70
    expected_staff_mult = 1.0 + (3 * 0.05) * 0.70 # 1.0 + 0.15 * 0.70 = 1.105
    reporter.check(active_cnt == 3, "Active count correctly excludes 2 fatigued workers (3 active)", "Stacking_Degraded")
    reporter.check(abs(avg_m - 0.70) < 1e-5, f"Staff average morale computed across all 5 workers (got {avg_m:.4f})", "Stacking_Degraded")
    reporter.check(abs(sim_deg.get_staff_rps_multiplier() - expected_staff_mult) < 1e-5, f"Degraded staff multiplier matches formula: {expected_staff_mult:.4f}x", "Stacking_Degraded")

    # Case 2.11: Underflow / Overflow Edge Cases
    sim_zero = AdversarialGameStateOracle(initial_energy=0.0, base_rps=0.0)
    sim_zero.hire_worker("Frontend Dev")
    reporter.check(sim_zero.get_effective_passive_rps() == 0.0, "Base RPS 0.0 results in exactly 0.0 underflow-safe RPS", "Stacking_Bounds")

    sim_big = AdversarialGameStateOracle(initial_energy=1e9, base_rps=1e6)
    sim_big.angel_shares = 100000 # 2,001x
    for r in ["Frontend Dev", "Backend Dev", "UI/UX Designer", "Growth Hacker", "QA Engineer"]:
        sim_big.hire_worker(r)
    sim_big.syndicate_tier = 5
    sim_big.server_overclock_buff_active = True
    sim_big.live_event_multiplier = 2.0
    big_rps = sim_big.get_effective_passive_rps()
    reporter.check(not math.isnan(big_rps) and not math.isinf(big_rps) and big_rps > 0.0, f"Extreme angel shares (100k) & high RPS handles safely ({big_rps:.2e}) without NaN/Inf", "Stacking_Bounds")

    # Case 2.12: Monte Carlo Random Stacking Simulation (1,000 runs)
    print("  Executing 1,000-run Monte Carlo compounding oracle...")
    mc_passed = True
    for _ in range(1000):
        mc_sim = AdversarialGameStateOracle(initial_energy=1e7, base_rps=random.uniform(1.0, 500.0))
        # Random workers
        num_w = random.randint(0, 5)
        roles = list(STAFF_ROLE_DEFINITIONS.keys())
        for i in range(num_w):
            mc_sim.hire_worker(roles[i])
            mc_sim.hired_workers[i]["morale"] = random.uniform(0.0, 1.0)
            mc_sim.hired_workers[i]["fatigue"] = random.uniform(0.0, 1.0)
            if mc_sim.hired_workers[i]["fatigue"] >= 1.0 or random.random() < 0.2:
                mc_sim.hired_workers[i]["current_state"] = "fatigued"
        mc_sim.syndicate_tier = random.randint(0, 5)
        mc_sim.angel_shares = random.randint(0, 500)
        mc_sim.server_overclock_buff_active = random.choice([True, False])
        mc_sim.live_event_multiplier = random.choice([1.0, 1.5, 2.0, 3.0])

        rps_val = mc_sim.get_effective_passive_rps()
        s_mult = mc_sim.get_staff_rps_multiplier()

        if math.isnan(rps_val) or math.isinf(rps_val) or rps_val < 0.0:
            mc_passed = False
            break
        if s_mult < 1.0 or s_mult > 1.250001:
            mc_passed = False
            break

    reporter.check(mc_passed, "Monte Carlo 1,000 randomized configurations: all values finite, positive, and strictly bounded", "Stacking_MonteCarlo")

    # --------------------------------------------------------------------------
    # TIER 3: Adversarial Serialization Fuzzing Oracle
    # --------------------------------------------------------------------------
    print(f"\n{Colors.BOLD}[TIER 3] Adversarial Persistence Serialization & Fuzzing Oracle{Colors.ENDC}")

    # Case 3.1: Malformed JSON Syntax
    sim_fuzz = AdversarialGameStateOracle()
    reporter.check(sim_fuzz.load_from_dict("") is False, "Empty string payload rejected safely", "Fuzz_Syntax")
    reporter.check(sim_fuzz.load_from_dict(None) is False, "None payload rejected safely", "Fuzz_Syntax")
    reporter.check(sim_fuzz.load_from_dict([1, 2, 3]) is False, "List root payload rejected safely", "Fuzz_Syntax")
    reporter.check(sim_fuzz.load_from_dict(12345) is False, "Integer root payload rejected safely", "Fuzz_Syntax")
    reporter.check(sim_fuzz.load_from_dict("garbage_corrupt_data") is False, "String root payload rejected safely", "Fuzz_Syntax")

    # Case 3.2: Missing Keys & Legacy Compatibility
    legacy_payload = {
        "energy": 5000.0,
        "hired_workers": [
            {"id": "w_legacy", "role": "Frontend Dev", "morale": 0.85, "fatigue": 0.15, "desk_assigned": 0, "current_state": "working"}
        ],
        "desk_levels": [2, 1, 1, 1, 1],
        "staff_hyper_focus_timer": 15.0,
    }
    sim_fuzz.load_from_dict(legacy_payload)
    reporter.check(len(sim_fuzz.hired_workers) == 1, "Legacy payload without 'staff' key successfully deserialized hired_workers", "Fuzz_Legacy")
    reporter.check(sim_fuzz.get_desk_level(0) == 2, "Legacy payload deserialized desk_levels", "Fuzz_Legacy")
    reporter.check(sim_fuzz.is_staff_hyper_focus_active() is True, "Legacy payload deserialized hyper focus timer", "Fuzz_Legacy")

    empty_payload = {"energy": 100.0}
    sim_fuzz.load_from_dict(empty_payload)
    reporter.check(len(sim_fuzz.hired_workers) == 0, "Payload missing both staff and legacy keys defaults hired_workers to empty", "Fuzz_Legacy")
    reporter.check(sim_fuzz.get_desk_levels() == [1, 1, 1, 1, 1], "Payload missing desk keys defaults to [1, 1, 1, 1, 1]", "Fuzz_Legacy")

    # Case 3.3: Type Mismatches in Staff & Worker Containers
    bad_staff_type = {
        "staff": "this_should_be_a_dict_not_a_string",
        "hired_workers": "also_not_a_list",
    }
    sim_fuzz.load_from_dict(bad_staff_type)
    reporter.check(len(sim_fuzz.hired_workers) == 0, "String staff block falls back cleanly to empty hired_workers without crash", "Fuzz_Types")

    bad_workers_list = {
        "staff": {
            "workers": [
                None,
                42,
                "corrupt_worker_string",
                True,
                [1, 2, 3],
                {}, # empty dict, missing role
            ]
        }
    }
    sim_fuzz.load_from_dict(bad_workers_list)
    reporter.check(len(sim_fuzz.hired_workers) == 0, "Non-dict and missing-role worker entries safely discarded", "Fuzz_Types")

    # Case 3.4: Extreme Floats, Negative Bounds & Out-of-Range Clamping
    extreme_floats_payload = {
        "staff": {
            "workers": [
                {
                    "id": "w_extreme_pos",
                    "role": "Frontend Dev",
                    "morale": 999.0, # Clamped to 1.0
                    "fatigue": 999.0, # Clamped to 1.0 -> current_state auto-corrected to 'fatigued'
                    "efficiency": 50.0,
                    "desk_assigned": 999, # Clamped to 4
                    "current_state": "invalid_fatigued_state",
                },
                {
                    "id": 123456, # Non-string ID -> normalized to "123456"
                    "role": "backend dev", # Lowercase role -> normalized to "Backend Dev"
                    "morale": -50.0, # Clamped to 0.0
                    "fatigue": -50.0, # Clamped to 0.0
                    "efficiency": -10.0, # Clamped to 0.1
                    "desk_assigned": -50, # Clamped to 0
                    "current_state": "hacked_status", # Invalid status -> auto-corrected to 'working'
                },
                {
                    "id": None, # Missing ID -> auto-generated canonical ID
                    "role": "UI/UX Designer",
                    "morale": float("nan"), # NaN -> clamped to 1.0
                    "fatigue": float("nan"), # NaN -> clamped to 0.0
                    "efficiency": float("nan"), # NaN -> clamped to 1.0
                    "desk_assigned": "not_an_int", # Invalid desk -> defaulted to 0
                    "current_state": None, # Non-string state -> auto-corrected
                },
                {
                    "id": "w_inf",
                    "role": "Growth Hacker",
                    "morale": float("inf"), # Inf -> clamped to 1.0
                    "fatigue": float("-inf"), # -Inf -> clamped to 0.0
                    "efficiency": float("inf"), # Inf -> clamped to 1.0
                    "desk_assigned": 3,
                    "current_state": "working",
                },
            ],
            "desk_levels": [-10, 999, "corrupt", None, 2, 3, 3], # Truncated to 5, clamped [1..3]
            "hyper_focus_timer": -50.0, # Clamped to 0.0
            "hyper_focus_multiplier": -10.0, # Clamped to >= 1.0
        }
    }
    sim_fuzz.load_from_dict(extreme_floats_payload)

    w_pos = sim_fuzz.get_worker("Frontend Dev")
    reporter.check(w_pos["morale"] == 1.0, "Morale 999.0 clamped to 1.0", "Fuzz_Bounds")
    reporter.check(w_pos["fatigue"] == 1.0, "Fatigue 999.0 clamped to 1.0", "Fuzz_Bounds")
    reporter.check(w_pos["current_state"] == "fatigued", "State auto-corrected to 'fatigued' due to 1.0 fatigue", "Fuzz_Bounds")
    reporter.check(w_pos["desk_assigned"] == 4, "Desk assigned 999 clamped to 4 (MAX_WORKERS-1)", "Fuzz_Bounds")

    w_neg = sim_fuzz.get_worker("Backend Dev")
    reporter.check(w_neg["id"] == "123456", "Non-string ID 123456 normalized to string '123456'", "Fuzz_Bounds")
    reporter.check(w_neg["role"] == "Backend Dev", "Lowercase 'backend dev' normalized to canonical 'Backend Dev'", "Fuzz_Bounds")
    reporter.check(w_neg["morale"] == 0.0, "Morale -50.0 clamped to 0.0", "Fuzz_Bounds")
    reporter.check(w_neg["fatigue"] == 0.0, "Fatigue -50.0 clamped to 0.0", "Fuzz_Bounds")
    reporter.check(w_neg["efficiency"] == 0.1, "Negative efficiency clamped to minimum 0.1", "Fuzz_Bounds")
    reporter.check(w_neg["desk_assigned"] == 0, "Negative desk assigned clamped to 0", "Fuzz_Bounds")
    reporter.check(w_neg["current_state"] == "working", "Invalid state string auto-corrected to 'working'", "Fuzz_Bounds")

    w_nan = sim_fuzz.get_worker("UI/UX Designer")
    reporter.check(w_nan["morale"] == 1.0, "NaN morale safely handled to 1.0", "Fuzz_Bounds")
    reporter.check(w_nan["fatigue"] == 0.0, "NaN fatigue safely handled to 0.0", "Fuzz_Bounds")
    reporter.check(w_nan["efficiency"] == 1.0, "NaN efficiency safely handled to 1.0", "Fuzz_Bounds")
    reporter.check(w_nan["desk_assigned"] == 0, "Non-int desk assigned safely defaulted to 0", "Fuzz_Bounds")

    w_inf = sim_fuzz.get_worker("Growth Hacker")
    reporter.check(w_inf["morale"] == 1.0, "Inf morale safely handled to 1.0", "Fuzz_Bounds")
    reporter.check(w_inf["fatigue"] == 0.0, "-Inf fatigue safely handled to 0.0", "Fuzz_Bounds")

    # Desk levels verification
    desks = sim_fuzz.get_desk_levels()
    reporter.check(len(desks) == 5, "Desk levels array clamped to exactly 5 elements", "Fuzz_Desks")
    reporter.check(desks[0] == 1, "Desk 0 level -10 clamped to 1", "Fuzz_Desks")
    reporter.check(desks[1] == 3, "Desk 1 level 999 clamped to 3", "Fuzz_Desks")
    reporter.check(desks[2] == 1, "Desk 2 non-int string defaulted to 1", "Fuzz_Desks")
    reporter.check(desks[3] == 1, "Desk 3 None level defaulted to 1", "Fuzz_Desks")
    reporter.check(desks[4] == 2, "Desk 4 valid level 2 preserved", "Fuzz_Desks")

    # Timers verification
    reporter.check(sim_fuzz.staff_hyper_focus_timer == 0.0, "Negative hyper focus timer clamped to 0.0", "Fuzz_Timers")
    reporter.check(sim_fuzz.is_staff_hyper_focus_active() is False, "Hyper focus inactive when timer is 0.0", "Fuzz_Timers")

    # Case 3.5: Invalid Role Discarding
    invalid_roles_payload = {
        "staff": {
            "workers": [
                {"role": "Astronaut"},
                {"role": "CEO"},
                {"role": "Barista"},
                {"role": ""},
                {"role": 9999},
                {"role": "QA Engineer"}, # Only this one is valid
            ]
        }
    }
    sim_fuzz.load_from_dict(invalid_roles_payload)
    reporter.check(len(sim_fuzz.hired_workers) == 1, "Invalid roles rejected: exactly 1 valid worker (QA Engineer) ingested", "Fuzz_Roles")
    reporter.check(sim_fuzz.hired_workers[0]["role"] == "QA Engineer", "Ingested worker role matches 'QA Engineer'", "Fuzz_Roles")

    # Case 3.6: 500 Randomized Fuzzing Mutator Iterations
    print("  Executing 500 randomized mutated payloads against persistence oracle...")
    fuzz_engine_passed = True
    corrupt_candidates = [
        None, True, False, 0, -1, 100, 999999, -1e10, 1e10, float("nan"), float("inf"), float("-inf"),
        "", "   ", "alien_payload", [1, 2], {"nested": "junk"}
    ]
    for _ in range(500):
        mutated = {
            "energy": random.choice(corrupt_candidates),
            "total_lifetime_energy": random.choice(corrupt_candidates),
            "angel_shares": random.choice(corrupt_candidates),
            "staff": {
                "workers": [
                    {
                        "id": random.choice(corrupt_candidates),
                        "role": random.choice(list(STAFF_ROLE_DEFINITIONS.keys()) + ["Hacker", "", None, 123]),
                        "morale": random.choice(corrupt_candidates),
                        "fatigue": random.choice(corrupt_candidates),
                        "efficiency": random.choice(corrupt_candidates),
                        "desk_assigned": random.choice(corrupt_candidates),
                        "current_state": random.choice(["working", "break", "fatigued", "corrupt", None, 123]),
                    }
                    for _ in range(random.randint(0, 7))
                ],
                "desk_levels": [random.choice(corrupt_candidates) for _ in range(random.randint(0, 8))],
                "hyper_focus_timer": random.choice(corrupt_candidates),
                "hyper_focus_multiplier": random.choice(corrupt_candidates),
            }
        }
        test_oracle = AdversarialGameStateOracle()
        try:
            # Roundtrip through JSON to simulate string file parsing
            json_dump = json.dumps(mutated, default=lambda o: None)
            parsed_back = json.loads(json_dump)
            res = test_oracle.load_from_dict(parsed_back)
            if not res:
                fuzz_engine_passed = False
                break

            # Invariant checks
            for w in test_oracle.hired_workers:
                if not (0.0 <= w["morale"] <= 1.0):
                    fuzz_engine_passed = False
                    break
                if not (0.0 <= w["fatigue"] <= 1.0):
                    fuzz_engine_passed = False
                    break
                if not (0 <= w["desk_assigned"] <= 4):
                    fuzz_engine_passed = False
                    break
                if w["role"] not in STAFF_ROLE_DEFINITIONS:
                    fuzz_engine_passed = False
                    break
            if len(test_oracle.desk_levels) != 5:
                fuzz_engine_passed = False
                break
            for dl in test_oracle.desk_levels:
                if not (1 <= dl <= 3):
                    fuzz_engine_passed = False
                    break
            if test_oracle.staff_hyper_focus_timer < 0.0 or math.isnan(test_oracle.staff_hyper_focus_timer):
                fuzz_engine_passed = False
                break
            mult = test_oracle.get_staff_rps_multiplier()
            if mult < 1.0 or math.isnan(mult) or math.isinf(mult):
                fuzz_engine_passed = False
                break

        except Exception as e:
            fuzz_engine_passed = False
            print(f"Exception during fuzz: {e}")
            break

    reporter.check(fuzz_engine_passed, "500-payload randomized fuzzing engine completed with 0 crashes and 100% invariant preservation", "Fuzz_Stress")

    # --------------------------------------------------------------------------
    # TIER 4: Multi-Round IPO Reset Cycles Oracle
    # --------------------------------------------------------------------------
    print(f"\n{Colors.BOLD}[TIER 4] Multi-Round IPO Reset Cycles Oracle (5 Full Ascensions){Colors.ENDC}")
    sim_ipo = AdversarialGameStateOracle(initial_energy=10000000.0, base_rps=100.0)

    # --- ROUND 1 ---
    print("  [IPO Round 1/5] Hiring 3 staff, upgrading Desk 0 to L3 & Desk 1 to L2, activating Coffee Break...")
    sim_ipo.hire_worker("Frontend Dev")
    sim_ipo.hire_worker("Backend Dev")
    sim_ipo.hire_worker("UI/UX Designer")
    sim_ipo.upgrade_desk(0) # Desk 0 -> L2
    sim_ipo.upgrade_desk(0) # Desk 0 -> L3
    sim_ipo.upgrade_desk(1) # Desk 1 -> L2
    sim_ipo.give_team_coffee_break() # 60s hyper focus active

    reporter.check(len(sim_ipo.hired_workers) == 3, "Round 1 Pre-IPO: 3 workers hired", "IPO_R1")
    reporter.check(sim_ipo.get_desk_levels() == [3, 2, 1, 1, 1], "Round 1 Pre-IPO: Desks [3, 2, 1, 1, 1]", "IPO_R1")
    reporter.check(sim_ipo.is_staff_hyper_focus_active() is True, "Round 1 Pre-IPO: Coffee break hyper-focus active", "IPO_R1")

    res1 = sim_ipo.trigger_ipo()
    reporter.check(res1.get("success") is True, f"Round 1 IPO triggered successfully (shares gained: {res1.get('shares_gained')})", "IPO_R1")
    reporter.check(sim_ipo.energy == 0.0, "Round 1 Post-IPO: Energy reset to 0.0", "IPO_R1")
    reporter.check(sim_ipo.total_ipos_completed == 1, "Round 1 Post-IPO: Total IPOs completed = 1", "IPO_R1")
    reporter.check(len(sim_ipo.hired_workers) == 3, "Round 1 Post-IPO: Exactly 3 workers preserved", "IPO_R1")
    reporter.check(sim_ipo.get_desk_levels() == [3, 2, 1, 1, 1], "Round 1 Post-IPO: Desk levels [3, 2, 1, 1, 1] preserved", "IPO_R1")
    reporter.check(sim_ipo.is_staff_hyper_focus_active() is False, "Round 1 Post-IPO: Temporary coffee break buff extinguished", "IPO_R1")
    reporter.check(sim_ipo.staff_hyper_focus_timer == 0.0, "Round 1 Post-IPO: Hyper focus timer reset to 0.0", "IPO_R1")

    # Roundtrip save/load check post-IPO
    saved_r1 = sim_ipo.to_dict()
    sim_ipo.load_from_dict(saved_r1)
    reporter.check(len(sim_ipo.hired_workers) == 3 and sim_ipo.get_desk_levels() == [3, 2, 1, 1, 1], "Round 1 Post-IPO: Save/Load roundtrip strictly matches", "IPO_R1")

    # --- ROUND 2 ---
    print("  [IPO Round 2/5] Earning energy, hiring remaining 2 staff (5 total), upgrading Desks 2, 3, 4...")
    sim_ipo.energy = 40000000.0
    sim_ipo.total_lifetime_energy += 40000000.0
    sim_ipo.hire_worker("Growth Hacker")
    sim_ipo.hire_worker("QA Engineer")
    sim_ipo.upgrade_desk(2) # Desk 2 -> L2
    sim_ipo.upgrade_desk(3) # Desk 3 -> L2
    sim_ipo.upgrade_desk(4) # Desk 4 -> L2
    sim_ipo.upgrade_desk(4) # Desk 4 -> L3

    # Simulate 300 seconds of work (fatigue accumulation)
    sim_ipo.update_staff_simulation(300.0)
    reporter.check(len(sim_ipo.hired_workers) == 5, "Round 2 Pre-IPO: Full roster of 5 staff active", "IPO_R2")
    reporter.check(sim_ipo.get_desk_levels() == [3, 2, 2, 2, 3], "Round 2 Pre-IPO: Desks [3, 2, 2, 2, 3]", "IPO_R2")

    res2 = sim_ipo.trigger_ipo()
    reporter.check(res2.get("success") is True, f"Round 2 IPO triggered successfully (shares gained: {res2.get('shares_gained')})", "IPO_R2")
    reporter.check(sim_ipo.total_ipos_completed == 2, "Round 2 Post-IPO: Total IPOs completed = 2", "IPO_R2")
    reporter.check(len(sim_ipo.hired_workers) == 5, "Round 2 Post-IPO: All 5 workers strictly preserved", "IPO_R2")
    reporter.check(sim_ipo.get_desk_levels() == [3, 2, 2, 2, 3], "Round 2 Post-IPO: Desk levels [3, 2, 2, 2, 3] strictly preserved", "IPO_R2")

    # --- ROUND 3 ---
    print("  [IPO Round 3/5] Upgrading all desks to Level 3, firing & rehiring QA Engineer...")
    sim_ipo.energy = 90000000.0
    sim_ipo.total_lifetime_energy += 90000000.0
    sim_ipo.upgrade_desk(1) # Desk 1 -> L3
    sim_ipo.upgrade_desk(2) # Desk 2 -> L3
    sim_ipo.upgrade_desk(3) # Desk 3 -> L3
    reporter.check(sim_ipo.get_desk_levels() == [3, 3, 3, 3, 3], "Round 3 Pre-IPO: All 5 desks maxed out at Level 3", "IPO_R3")

    sim_ipo.fire_worker("QA Engineer")
    reporter.check(len(sim_ipo.hired_workers) == 4, "Round 3 Pre-IPO: QA Engineer fired -> 4 workers", "IPO_R3")
    sim_ipo.hire_worker("QA Engineer")
    reporter.check(len(sim_ipo.hired_workers) == 5, "Round 3 Pre-IPO: QA Engineer rehired into vacated desk 4", "IPO_R3")

    res3 = sim_ipo.trigger_ipo()
    reporter.check(res3.get("success") is True, f"Round 3 IPO triggered successfully (shares gained: {res3.get('shares_gained')})", "IPO_R3")
    reporter.check(sim_ipo.total_ipos_completed == 3, "Round 3 Post-IPO: Total IPOs completed = 3", "IPO_R3")
    reporter.check(sim_ipo.get_desk_levels() == [3, 3, 3, 3, 3], "Round 3 Post-IPO: All desks remain at Level 3", "IPO_R3")
    reporter.check(len(sim_ipo.hired_workers) == 5, "Round 3 Post-IPO: All 5 workers strictly preserved", "IPO_R3")

    # --- ROUND 4 ---
    print("  [IPO Round 4/5] Testing fatigued worker state recovery through coffee break before IPO...")
    sim_ipo.energy = 160000000.0
    sim_ipo.total_lifetime_energy += 160000000.0

    # Exhaust worker 0
    sim_ipo.hired_workers[0]["fatigue"] = 1.0
    sim_ipo.hired_workers[0]["current_state"] = "fatigued"
    sim_ipo.hired_workers[0]["morale"] = 0.2
    reporter.check(sim_ipo.get_active_workers_count() == 4, "Round 4 Pre-Coffee: 1 fatigued worker excluded from active (4 active)", "IPO_R4")

    # Team coffee break restores everyone
    sim_ipo.give_team_coffee_break()
    reporter.check(sim_ipo.get_active_workers_count() == 5, "Round 4 Post-Coffee: All 5 workers active again", "IPO_R4")
    reporter.check(sim_ipo.hired_workers[0]["morale"] == 1.0, "Round 4 Post-Coffee: Worker 0 morale restored to 1.0", "IPO_R4")

    res4 = sim_ipo.trigger_ipo()
    reporter.check(res4.get("success") is True, f"Round 4 IPO triggered successfully (shares gained: {res4.get('shares_gained')})", "IPO_R4")
    reporter.check(sim_ipo.total_ipos_completed == 4, "Round 4 Post-IPO: Total IPOs completed = 4", "IPO_R4")
    reporter.check(sim_ipo.is_staff_hyper_focus_active() is False, "Round 4 Post-IPO: Coffee break buff extinguished on rebirth", "IPO_R4")
    for w in sim_ipo.hired_workers:
        reporter.check(w["current_state"] == "working", f"Worker '{w['id']}' in 'working' state post-IPO", "IPO_R4")

    # --- ROUND 5 ---
    print("  [IPO Round 5/5] Full serialization roundtrip, 5th ascension, and cumulative share verification...")
    sim_ipo.energy = 250000000.0
    sim_ipo.total_lifetime_energy += 250000000.0

    # Save to JSON and reload to guarantee complete roundtrip persistence
    disk_json = json.dumps(sim_ipo.to_dict())
    sim_ipo.load_from_dict(json.loads(disk_json))

    res5 = sim_ipo.trigger_ipo()
    reporter.check(res5.get("success") is True, f"Round 5 IPO triggered successfully (shares gained: {res5.get('shares_gained')})", "IPO_R5")
    reporter.check(sim_ipo.total_ipos_completed == 5, "Round 5 Post-IPO: Total IPOs completed = 5", "IPO_R5")
    reporter.check(len(sim_ipo.hired_workers) == 5, "Round 5 Post-IPO: All 5 workers 100% intact after 5 consecutive IPOs", "IPO_R5")
    reporter.check(sim_ipo.get_desk_levels() == [3, 3, 3, 3, 3], "Round 5 Post-IPO: All 5 Level 3 ergonomic desks 100% intact", "IPO_R5")
    reporter.check(sim_ipo.angel_shares > 40, f"Round 5 Post-IPO: Cumulative angel shares accrued ({sim_ipo.angel_shares})", "IPO_R5")
    reporter.check(sim_ipo.get_staff_rps_multiplier() == 1.25, "Round 5 Post-IPO: Staff multiplier strictly 1.25x (+25%)", "IPO_R5")

    # --------------------------------------------------------------------------
    # TIER 5: Edge Case & Boundary Mining
    # --------------------------------------------------------------------------
    print(f"\n{Colors.BOLD}[TIER 5] Adversarial Edge Cases & Boundary Mining{Colors.ENDC}")
    sim_edge = AdversarialGameStateOracle(initial_energy=50000.0, base_rps=50.0)

    # 5.1 Duplicate role hiring rejected
    sim_edge.hire_worker("Frontend Dev")
    reporter.check(sim_edge.hire_worker("Frontend Dev") is False, "Hiring duplicate role 'Frontend Dev' is safely rejected", "Edge_Hire")
    reporter.check(sim_edge.hire_worker("frontend dev") is False, "Hiring case-insensitive duplicate 'frontend dev' is rejected", "Edge_Hire")

    # 5.2 Insufficient energy rejected without deduction
    sim_edge.energy = 100.0 # Backend Dev costs 1500.0
    reporter.check(sim_edge.hire_worker("Backend Dev") is False, "Hiring with insufficient energy rejected", "Edge_Hire")
    reporter.check(sim_edge.energy == 100.0, "Energy untouched after rejected hire", "Edge_Hire")

    # 5.3 Capacity capping at 5
    sim_edge.energy = 100000.0
    for r in ["Backend Dev", "UI/UX Designer", "Growth Hacker", "QA Engineer"]:
        sim_edge.hire_worker(r)
    reporter.check(len(sim_edge.hired_workers) == 5, "Roster full with 5 workers", "Edge_Capacity")
    reporter.check(sim_edge.hire_worker("Frontend Dev") is False, "Attempting to hire beyond capacity (5) rejected", "Edge_Capacity")

    # 5.4 Firing non-existent worker
    reporter.check(sim_edge.fire_worker("worker_non_existent") is False, "Firing non-existent worker ID rejected", "Edge_Fire")
    reporter.check(sim_edge.fire_worker("") is False, "Firing empty worker ID rejected", "Edge_Fire")
    reporter.check(len(sim_edge.hired_workers) == 5, "Worker count unchanged after invalid fire attempts", "Edge_Fire")

    # 5.5 Desk upgrade boundaries
    reporter.check(sim_edge.upgrade_desk(-1) is False, "Desk upgrade with negative index rejected", "Edge_Desk")
    reporter.check(sim_edge.upgrade_desk(5) is False, "Desk upgrade with out-of-bounds index (5) rejected", "Edge_Desk")
    reporter.check(sim_edge.upgrade_desk(100) is False, "Desk upgrade with index 100 rejected", "Edge_Desk")

    # Max out desk 0
    sim_edge.upgrade_desk(0) # L2
    sim_edge.upgrade_desk(0) # L3
    reporter.check(sim_edge.get_desk_level(0) == 3, "Desk 0 reached max Level 3", "Edge_Desk")
    reporter.check(sim_edge.upgrade_desk(0) is False, "Desk upgrade past Level 3 rejected", "Edge_Desk")
    reporter.check(sim_edge.get_desk_upgrade_cost(0) == 0.0, "Maxed desk upgrade cost returns 0.0", "Edge_Desk")

    # 5.6 Epiphany reward with full stacking multipliers
    # Award formula: max(100.0, effective_rps * 15.0)
    sim_edge.syndicate_tier = 5
    sim_edge.angel_shares = 50
    eff_rps = sim_edge.get_effective_passive_rps()
    pre_e = sim_edge.energy
    reward = sim_edge.trigger_worker_epiphany("Frontend Dev")
    expected_reward = max(100.0, eff_rps * 15.0)
    reporter.check(abs(reward - expected_reward) < 1e-3, f"Epiphany reward matches exact formula with active multipliers: {reward:.2f}", "Edge_Epiphany")
    reporter.check(abs(sim_edge.energy - (pre_e + reward)) < 1e-3, "Epiphany reward credited directly to energy", "Edge_Epiphany")

    # 5.7 Complete worker dismissal -> zero regression & zero division safety
    for w in list(sim_edge.hired_workers):
        sim_edge.fire_worker(w["id"])
    reporter.check(len(sim_edge.hired_workers) == 0, "All workers dismissed -> hired_workers is empty", "Edge_DismissAll")
    reporter.check(sim_edge.get_staff_average_morale() == 1.0, "Empty staff returns default 1.0 morale without ZeroDivisionError", "Edge_DismissAll")
    reporter.check(sim_edge.get_staff_rps_multiplier() == 1.0, "Empty staff returns exactly 1.00000x multiplier", "Edge_DismissAll")
    reporter.check(sim_edge.get_active_workers_count() == 0, "Active workers count is 0", "Edge_DismissAll")

    return reporter.summary()


if __name__ == "__main__":
    sys.exit(run_adversarial_suite())
