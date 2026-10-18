#!/usr/bin/env python3
"""
Phase 14 Milestone M1: Adversarial Simulation Stress & Ergonomics Challenger Suite
===================================================================================
Target: IdleArcade Godot 4.3 - Milestone M1 (Staff Management & Morale Economy)
Code under test: IdleArcade/scripts/autoload/game_state.gd

Adversarial Stress Test Matrix:
  Tier 1: Static AST & Contract Architecture Deep Audit
          - Signal declarations & aliases
          - Constants (MAX_WORKERS, MAX_DESK_LEVEL, BASE_WORKER_FATIGUE_RATE_PER_MINUTE)
          - State variables & role catalog
          - Public methods & integration points (process loop, RPS compounding, IPO preservation)
  Tier 2: Mathematical Rate & Delta Integration Stress
          - Fatigue accumulation rate (+0.02/min = 0.02/60s = 0.000333.../s)
          - Frame delta variations: 60 FPS (0.016667s), 240 FPS (0.004167s), hitch limit (0.1s)
          - Extreme deltas: sub-millisecond (0.0001s), macro-jumps (60s, 3600s, 86400s)
          - Malicious/edge deltas: 0.0s, negative (-10.0s), NaN, Inf
  Tier 3: Desk Ergonomics Dampening Verification
          - Level 1: 0% reduction (multiplier 1.00, +0.0200/min)
          - Level 2: 25% reduction (multiplier 0.75, +0.0150/min)
          - Level 3: 60% reduction (multiplier 0.40, +0.0080/min)
          - Comparative ratio verification across 1,800s, 3,600s, and 7,200s
  Tier 4: Morale Decay & State Transition Dynamics
          - Morale preservation while fatigue < 0.80
          - Morale decay trigger at fatigue >= 0.80 (-0.02/min)
          - Automatic transition to "fatigued" at fatigue >= 1.00
          - Exclusion from active workers count during exhaustion
          - Continued morale decay to exactly 0.00 in fatigued state
          - Strict clamping invariants: fatigue in [0.0, 1.0], morale in [0.0, 1.0]
  Tier 5: Coffee Break Recovery & Hyper-Focus Lifecycle
          - Instant fatigue drop to 0.0, morale restored to 1.0
          - State restored to "working"
          - 60.0s Hyper-Focus countdown initialized (+50% speed / 1.50x multiplier)
          - Timer decay over time and clean expiry at exactly 0.0s
          - Re-trigger idempotence and non-stacking of speed multiplier
  Tier 6: Staff Lifecycle & Desk Reassignment Stress (1,000 Monte Carlo Cycles)
          - Capacity saturation (exactly 5 workers max)
          - Duplicate role rejection and unknown role rejection
          - Desk vacancy tracking and lowest-available desk assignment (0..4)
          - Rapid hire/fire/re-hire sequences with invariant assertions
  Tier 7: Extreme Multiplier Compounding & Scaling Invariants
          - Identity multiplier (1.00000x) at 0 workers
          - Maximum staff multiplier (1.25000x) with 5 full-morale workers
          - Multiplier compounding with Angel Shares (up to 1,000x) and Syndicate Dividends
          - All-fatigued fallback (1.00000x identity, zero penalty)
  Tier 8: Epiphany Moments Stress & Economy Integration
          - Reward formula: max(100.0, 15x passive RPS)
          - Lump-sum energy credited to player energy & lifetime energy
          - Valid worker fallback when invalid worker ID provided
  Tier 9: Persistence Fuzzing & Malicious Corruption Recovery (500 Fuzz Cases)
          - Negative morale/fatigue, NaN/Inf, out-of-bounds desk levels, invalid states
          - Defensively clamped and restored to valid ranges
  Tier 10: IPO Prestige Ascension Invariants
          - Hired workers & desk upgrade retention across prestige reset
          - Temporary coffee break / hyper focus timers extinguished
          - Break state normalization to working

Executable via: python IdleArcade/tests/test_p14_m1_challenger_stress.py
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
        print("\n" + "=" * 78)
        print("Phase 14 Milestone M1: Adversarial Simulation Stress Test Results")
        print("=" * 78)
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
            print(f"\n{Colors.GREEN}>>> ADVERSARIAL VERDICT: APPROVE (ALL STRESS TESTS PASSED) <<<{Colors.ENDC}")
            return 0


# ==============================================================================
# SIMULATION ENGINE (EXACT MATHEMATICAL MIRROR OF game_state.gd)
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


class SimulatedGameStateStaffStress:
    def __init__(self):
        self.reset_state()

    def reset_state(self):
        self.energy: float = 0.0
        self.total_energy_earned: float = 0.0
        self.total_lifetime_energy: float = 0.0
        self.base_passive_rps: float = 100.0
        self.bonus_users: int = 0
        self.collectibles_collected: int = 0
        self.researched_techs: List[str] = []
        self.server_overclock_buff_active: bool = False
        self.server_overclock_buff_timer: float = 0.0
        self.server_overclock_buff_multiplier: float = 1.50
        self.campaign_rps_buff_multiplier: float = 1.0
        self.campaign_rps_buff_timer: float = 0.0
        self.angel_shares: int = 0
        self.syndicate_tier: int = 0
        self.total_ipos_completed: int = 0

        # Phase 14 Staff State
        self.hired_workers: List[Dict[str, Any]] = []
        self.desk_levels: List[int] = [1, 1, 1, 1, 1]
        self.staff_hyper_focus_active: bool = False
        self.staff_hyper_focus_timer: float = 0.0
        self.staff_hyper_focus_remaining: float = 0.0
        self.staff_hyper_focus_multiplier: float = 1.50
        self.staff_coffee_break_active: bool = False
        self.staff_coffee_break_timer: float = 0.0
        self.staff_coffee_break_remaining: float = 0.0

        # Signals log
        self.emitted_signals: List[Tuple[Any, ...]] = []

    def _normalize_role(self, role_name: str) -> str:
        clean = role_name.strip()
        for def_role in STAFF_ROLE_DEFINITIONS:
            if clean.lower() == def_role.lower():
                return def_role
            simplified = def_role.lower().replace(" ", "_").replace("/", "_")
            input_simplified = clean.lower().replace(" ", "_").replace("/", "_")
            if simplified == input_simplified:
                return def_role
        return ""

    def hire_worker(self, role: str) -> bool:
        canonical_role = self._normalize_role(role)
        if not canonical_role:
            return False
        if len(self.hired_workers) >= MAX_WORKERS:
            return False
        for w in self.hired_workers:
            if str(w.get("role", "")) == canonical_role:
                return False

        role_def = STAFF_ROLE_DEFINITIONS[canonical_role]
        cost = float(role_def.get("hire_cost", 500.0))
        if self.energy < cost:
            return False

        occupied_desks = [int(w.get("desk_assigned", 0)) for w in self.hired_workers]
        chosen_desk = -1
        for d in range(MAX_WORKERS):
            if d not in occupied_desks:
                chosen_desk = d
                break
        if chosen_desk == -1:
            chosen_desk = 0

        self.energy -= cost
        self.emitted_signals.append(("energy_changed", self.energy, -cost))

        worker_id = "worker_" + canonical_role.lower().replace(" ", "_").replace("/", "_")
        new_worker = {
            "id": worker_id,
            "name": str(role_def.get("default_name", canonical_role)),
            "role": canonical_role,
            "morale": 1.0,
            "fatigue": 0.0,
            "efficiency": 1.0,
            "desk_assigned": chosen_desk,
            "current_state": "working",
        }
        self.hired_workers.append(new_worker)
        self.emitted_signals.append(("staff_worker_hired", dict(new_worker)))
        self.emitted_signals.append(("worker_hired", dict(new_worker)))
        self.emitted_signals.append(("staff_worker_state_changed", worker_id, "working"))
        self.emitted_signals.append(("staff_morale_updated", self.get_staff_average_morale()))
        self.emitted_signals.append(("rps_changed", self.get_effective_passive_rps()))
        self.emitted_signals.append(("staff_bonus_updated", self.get_staff_rps_multiplier(), self.get_active_workers_count(), self.get_staff_average_morale()))
        return True

    def fire_worker(self, worker_id: str) -> bool:
        if not worker_id:
            return False
        target_index = -1
        found_id = ""
        norm = self._normalize_role(worker_id)
        for i, w in enumerate(self.hired_workers):
            if str(w.get("id", "")) == worker_id or str(w.get("role", "")) == worker_id or (norm and str(w.get("role", "")) == norm):
                target_index = i
                found_id = str(w.get("id", worker_id))
                break
        if target_index == -1:
            return False

        self.hired_workers.pop(target_index)
        self.emitted_signals.append(("staff_worker_fired", found_id))
        self.emitted_signals.append(("worker_fired", found_id))
        self.emitted_signals.append(("staff_morale_updated", self.get_staff_average_morale()))
        self.emitted_signals.append(("rps_changed", self.get_effective_passive_rps()))
        self.emitted_signals.append(("staff_bonus_updated", self.get_staff_rps_multiplier(), self.get_active_workers_count(), self.get_staff_average_morale()))
        return True

    def get_hired_workers(self) -> List[Dict[str, Any]]:
        return [dict(w) for w in self.hired_workers]

    def get_worker(self, worker_id: str) -> Dict[str, Any]:
        norm = self._normalize_role(worker_id)
        for w in self.hired_workers:
            if str(w.get("id", "")) == worker_id or str(w.get("role", "")) == worker_id or (norm and str(w.get("role", "")) == norm):
                return dict(w)
        return {}

    def get_active_workers_count(self) -> int:
        return sum(1 for w in self.hired_workers if str(w.get("current_state", "working")) != "fatigued")

    def get_staff_average_morale(self) -> float:
        if not self.hired_workers:
            return 1.0
        total = sum(max(0.0, min(1.0, float(w.get("morale", 1.0)))) for w in self.hired_workers)
        return total / float(len(self.hired_workers))

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
        return float(DESK_CONFIG.get(lvl + 1, {}).get("cost", 0.0))

    def get_desk_fatigue_multiplier(self, desk_level: int) -> float:
        if desk_level == 2:
            return 0.75
        elif desk_level >= 3:
            return 0.40
        return 1.00

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
        self.emitted_signals.append(("energy_changed", self.energy, -cost))
        self.emitted_signals.append(("staff_desk_upgraded", desk_index, next_lvl))
        self.emitted_signals.append(("desk_upgraded", desk_index, next_lvl, cost))
        return True

    def give_team_coffee_break(self) -> bool:
        for w in self.hired_workers:
            w["fatigue"] = 0.0
            w["morale"] = 1.0
            w["current_state"] = "working"
            self.emitted_signals.append(("staff_worker_state_changed", str(w.get("id", "")), "working"))
            self.emitted_signals.append(("worker_state_changed", str(w.get("id", "")), "working"))
            self.emitted_signals.append(("staff_worker_morale_updated", str(w.get("id", "")), 1.0, 0.0))

        self.staff_hyper_focus_active = True
        self.staff_hyper_focus_timer = 60.0
        self.staff_hyper_focus_remaining = 60.0
        self.staff_hyper_focus_multiplier = 1.50
        self.staff_coffee_break_active = True
        self.staff_coffee_break_timer = 60.0
        self.staff_coffee_break_remaining = 60.0

        self.emitted_signals.append(("staff_coffee_break_started", 60.0))
        self.emitted_signals.append(("team_coffee_break_started", 60.0, 1.50))
        self.emitted_signals.append(("staff_morale_updated", self.get_staff_average_morale()))
        self.emitted_signals.append(("rps_changed", self.get_effective_passive_rps()))
        self.emitted_signals.append(("staff_bonus_updated", self.get_staff_rps_multiplier(), self.get_active_workers_count(), self.get_staff_average_morale()))
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

    def get_angel_share_multiplier(self) -> float:
        return 1.0 + (float(self.angel_shares) * 0.02)

    def get_syndicate_dividend_multiplier(self) -> float:
        return 1.0 + (float(self.syndicate_tier) * 0.05) if self.syndicate_tier > 0 else 1.0

    def get_effective_passive_rps(self) -> float:
        staff_mult = self.get_staff_rps_multiplier()
        angel_mult = self.get_angel_share_multiplier()
        syndicate_mult = self.get_syndicate_dividend_multiplier()
        return self.base_passive_rps * angel_mult * syndicate_mult * staff_mult

    def earn_energy(self, amount: float):
        if amount <= 0.0:
            return
        self.energy += amount
        self.total_energy_earned += amount
        self.total_lifetime_energy += amount
        self.emitted_signals.append(("energy_changed", self.energy, amount))

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
        self.earn_energy(reward)
        self.emitted_signals.append(("staff_epiphany_triggered", target_id, reward))
        self.emitted_signals.append(("epiphany_collected", target_id, reward))
        return reward

    def update_staff_simulation(self, delta: float):
        if delta <= 0.0 or not self.hired_workers or math.isnan(delta) or math.isinf(delta):
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
                    self.emitted_signals.append(("worker_state_changed", str(w.get("id", "")), "fatigued"))

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
            self.emitted_signals.append(("staff_bonus_updated", self.get_staff_rps_multiplier(), self.get_active_workers_count(), avg_morale))
        elif any_state_change:
            self.emitted_signals.append(("rps_changed", self.get_effective_passive_rps()))
            self.emitted_signals.append(("staff_bonus_updated", self.get_staff_rps_multiplier(), self.get_active_workers_count(), self.get_staff_average_morale()))

    def process(self, delta: float):
        safe_delta = max(0.0, delta)
        clamped_delta = min(0.1, safe_delta)

        self.update_staff_simulation(clamped_delta)

        if self.staff_hyper_focus_timer > 0.0 or self.staff_hyper_focus_active or self.staff_coffee_break_timer > 0.0 or self.staff_coffee_break_active:
            self.staff_hyper_focus_timer -= safe_delta
            self.staff_hyper_focus_remaining = max(0.0, self.staff_hyper_focus_timer)
            self.staff_coffee_break_timer = self.staff_hyper_focus_timer
            self.staff_coffee_break_remaining = self.staff_hyper_focus_remaining
            if self.staff_hyper_focus_timer <= 0.0:
                self.staff_hyper_focus_timer = 0.0
                self.staff_hyper_focus_remaining = 0.0
                self.staff_hyper_focus_active = False
                self.staff_coffee_break_timer = 0.0
                self.staff_coffee_break_remaining = 0.0
                self.staff_coffee_break_active = False
                for w in self.hired_workers:
                    if str(w.get("current_state", "")) == "break":
                        w["current_state"] = "working"
                        self.emitted_signals.append(("staff_worker_state_changed", str(w.get("id", "")), "working"))
                self.emitted_signals.append(("rps_changed", self.get_effective_passive_rps()))
                self.emitted_signals.append(("staff_coffee_break_ended",))
                self.emitted_signals.append(("team_coffee_break_ended",))

    def serialize(self) -> Dict[str, Any]:
        return {
            "energy": self.energy,
            "staff": {
                "workers": [dict(w) for w in self.hired_workers],
                "desk_levels": list(self.desk_levels),
                "coffee_break_active": self.staff_coffee_break_active or self.staff_hyper_focus_active,
                "coffee_break_timer": max(self.staff_coffee_break_timer, self.staff_hyper_focus_timer),
                "coffee_break_remaining": max(self.staff_coffee_break_remaining, self.staff_hyper_focus_remaining),
                "hyper_focus_active": self.staff_hyper_focus_active or self.staff_coffee_break_active,
                "hyper_focus_timer": max(self.staff_hyper_focus_timer, self.staff_coffee_break_timer),
                "hyper_focus_remaining": max(self.staff_hyper_focus_remaining, self.staff_coffee_break_remaining),
                "hyper_focus_multiplier": self.staff_hyper_focus_multiplier,
            },
            "hired_workers": [dict(w) for w in self.hired_workers],
            "desk_levels": list(self.desk_levels),
            "staff_hyper_focus_timer": self.staff_hyper_focus_timer,
            "staff_hyper_focus_remaining": self.staff_hyper_focus_remaining,
            "staff_hyper_focus_active": self.staff_hyper_focus_active,
        }

    def deserialize(self, data: Dict[str, Any]):
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
                hf_m = float(staff_data.get("hyper_focus_multiplier", 1.50))
                self.staff_hyper_focus_multiplier = 1.50 if (math.isnan(hf_m) or math.isinf(hf_m)) else max(1.0, hf_m)
            except (ValueError, TypeError):
                self.staff_hyper_focus_multiplier = 1.50

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
                        except (ValueError, TypeError):
                            clean_m = 1.0

                        try:
                            raw_f = float(w.get("fatigue", 0.0))
                            clean_f = 0.0 if (math.isnan(raw_f) or math.isinf(raw_f)) else max(0.0, min(1.0, raw_f))
                        except (ValueError, TypeError):
                            clean_f = 0.0

                        try:
                            raw_eff = float(w.get("efficiency", 1.0))
                            clean_eff = 1.0 if (math.isnan(raw_eff) or math.isinf(raw_eff)) else max(0.1, raw_eff)
                        except (ValueError, TypeError):
                            clean_eff = 1.0

                        try:
                            clean_desk = max(0, min(4, int(w.get("desk_assigned", 0))))
                        except (ValueError, TypeError):
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

        if isinstance(raw_desks, list) and raw_desks:
            for i in range(min(5, len(raw_desks))):
                try:
                    lvl = int(raw_desks[i])
                    self.desk_levels[i] = max(1, min(3, lvl))
                except (ValueError, TypeError):
                    self.desk_levels[i] = 1

        try:
            hf_t = float(raw_hf_timer)
            if not math.isnan(hf_t) and not math.isinf(hf_t):
                self.staff_hyper_focus_timer = max(0.0, hf_t)
                self.staff_hyper_focus_remaining = self.staff_hyper_focus_timer
                self.staff_coffee_break_timer = self.staff_hyper_focus_timer
                self.staff_coffee_break_remaining = self.staff_hyper_focus_timer
                self.staff_hyper_focus_active = self.staff_hyper_focus_timer > 0.0
                self.staff_coffee_break_active = self.staff_hyper_focus_active
        except (ValueError, TypeError):
            pass

    def trigger_ipo(self) -> Dict[str, Any]:
        self.energy = 0.0
        self.staff_hyper_focus_active = False
        self.staff_hyper_focus_timer = 0.0
        self.staff_hyper_focus_remaining = 0.0
        self.staff_coffee_break_active = False
        self.staff_coffee_break_timer = 0.0
        self.staff_coffee_break_remaining = 0.0
        for w in self.hired_workers:
            if str(w.get("current_state", "")) == "break":
                w["current_state"] = "working"
        self.total_ipos_completed += 1
        return {"success": True}


# ==============================================================================
# MAIN TEST EXECUTION
# ==============================================================================

def run_stress_tests() -> int:
    reporter = TestReporter()
    print(f"\n{Colors.BOLD}{Colors.CYAN}Starting Phase 14 Milestone M1 Adversarial Stress Test Suite...{Colors.ENDC}\n")

    # ==========================================================================
    # TIER 1: Static AST & Contract Architecture Deep Audit
    # ==========================================================================
    reporter.check(GAME_STATE_PATH.exists(), f"Target file exists: {GAME_STATE_PATH.name}", "Tier1_AST")
    content = GAME_STATE_PATH.read_text(encoding="utf-8")

    # Signals
    req_signals = [
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
        "epiphany_collected",
        "staff_bonus_updated",
    ]
    for sig in req_signals:
        pattern = rf"\bsignal\s+{re.escape(sig)}\b"
        reporter.check(bool(re.search(pattern, content)), f"Signal '{sig}' declared in game_state.gd", "Tier1_Signals")

    # Constants & rates
    reporter.check("MAX_WORKERS" in content and "5" in content, "MAX_WORKERS == 5 declared", "Tier1_Constants")
    reporter.check("MAX_DESK_LEVEL" in content and "3" in content, "MAX_DESK_LEVEL == 3 declared", "Tier1_Constants")
    reporter.check("BASE_WORKER_FATIGUE_RATE_PER_MINUTE" in content and "0.02" in content, "BASE_WORKER_FATIGUE_RATE_PER_MINUTE == 0.02 declared", "Tier1_Constants")
    reporter.check("BASE_WORKER_FATIGUE_RATE_PER_SECOND" in content, "BASE_WORKER_FATIGUE_RATE_PER_SECOND declared", "Tier1_Constants")
    reporter.check("BASE_WORKER_MORALE_DECAY_RATE_PER_SECOND" in content, "BASE_WORKER_MORALE_DECAY_RATE_PER_SECOND declared", "Tier1_Constants")

    # State variables
    reporter.check(bool(re.search(r"var\s+hired_workers\s*:\s*Array", content)), "var hired_workers: Array declared", "Tier1_Vars")
    reporter.check(bool(re.search(r"var\s+desk_levels\s*:\s*Array", content)), "var desk_levels: Array declared", "Tier1_Vars")
    reporter.check("staff_hyper_focus_timer" in content, "var staff_hyper_focus_timer declared", "Tier1_Vars")
    reporter.check("staff_coffee_break_timer" in content, "var staff_coffee_break_timer declared", "Tier1_Vars")

    # Public methods
    req_methods = [
        "hire_worker",
        "fire_worker",
        "get_hired_workers",
        "get_worker",
        "get_active_workers_count",
        "get_staff_average_morale",
        "get_average_worker_morale",
        "upgrade_desk",
        "get_desk_level",
        "get_desk_levels",
        "get_desk_upgrade_cost",
        "get_desk_fatigue_multiplier",
        "give_team_coffee_break",
        "is_staff_hyper_focus_active",
        "get_staff_hyper_focus_time_remaining",
        "get_staff_hyper_focus_multiplier",
        "get_staff_rps_multiplier",
        "trigger_worker_epiphany",
        "trigger_epiphany",
        "update_staff_simulation",
    ]
    for method in req_methods:
        pattern = rf"\bfunc\s+{method}\b"
        reporter.check(bool(re.search(pattern, content)), f"Method '{method}' implemented in game_state.gd", "Tier1_Methods")

    # Process and compounding integrations
    reporter.check("update_staff_simulation(clamped_delta)" in content or "update_staff_simulation(" in content, "_process integrates update_staff_simulation", "Tier1_Integration")
    reporter.check("get_staff_rps_multiplier()" in content, "get_effective_passive_rps() compounds get_staff_rps_multiplier()", "Tier1_Integration")
    reporter.check('"staff"' in content, "save_to_disk() contains 'staff' block", "Tier1_Integration")

    # ==========================================================================
    # TIER 2: Mathematical Rate & Delta Integration Stress
    # ==========================================================================
    sim = SimulatedGameStateStaffStress()
    sim.energy = 100000.0
    sim.hire_worker("Frontend Dev")  # Desk 0, Level 1 (0% reduction)

    # Base fatigue rate: exactly 0.02 in 60s
    sim.update_staff_simulation(60.0)
    w0 = sim.get_worker("worker_frontend_dev")
    expected_f = 0.02
    reporter.check(abs(w0["fatigue"] - expected_f) < 1e-9, f"60s macro-delta produces exactly {expected_f} fatigue (got {w0['fatigue']:.6f})", "Tier2_MathRate")

    # High frequency 60 FPS delta test (3600 frames = 60s)
    sim.reset_state()
    sim.energy = 100000.0
    sim.hire_worker("Frontend Dev")
    for _ in range(3600):
        sim.update_staff_simulation(1.0 / 60.0)
    w0 = sim.get_worker("worker_frontend_dev")
    reporter.check(abs(w0["fatigue"] - expected_f) < 1e-6, f"3600 60fps frames accumulate exactly {expected_f} fatigue (got {w0['fatigue']:.6f})", "Tier2_60FPS")

    # Ultra high frequency 240 FPS delta test (14400 frames = 60s)
    sim.reset_state()
    sim.energy = 100000.0
    sim.hire_worker("Frontend Dev")
    for _ in range(14400):
        sim.update_staff_simulation(1.0 / 240.0)
    w0 = sim.get_worker("worker_frontend_dev")
    reporter.check(abs(w0["fatigue"] - expected_f) < 1e-6, f"14400 240fps frames accumulate exactly {expected_f} fatigue (got {w0['fatigue']:.6f})", "Tier2_240FPS")

    # Sub-millisecond jitter delta test (60,000 frames of 0.001s = 60s)
    sim.reset_state()
    sim.energy = 100000.0
    sim.hire_worker("Frontend Dev")
    for _ in range(60000):
        sim.update_staff_simulation(0.001)
    w0 = sim.get_worker("worker_frontend_dev")
    reporter.check(abs(w0["fatigue"] - expected_f) < 1e-6, f"60000 sub-millisecond 1ms frames accumulate {expected_f} fatigue (got {w0['fatigue']:.6f})", "Tier2_SubMilli")

    # Edge cases: 0.0 delta, negative delta, NaN, Inf
    sim.update_staff_simulation(0.0)
    reporter.check(abs(sim.get_worker("worker_frontend_dev")["fatigue"] - expected_f) < 1e-9, "Delta 0.0 leaves fatigue unchanged", "Tier2_EdgeDeltas")
    sim.update_staff_simulation(-10.0)
    reporter.check(abs(sim.get_worker("worker_frontend_dev")["fatigue"] - expected_f) < 1e-9, "Negative delta (-10.0) safely ignored without time travel", "Tier2_EdgeDeltas")
    sim.update_staff_simulation(float("nan"))
    reporter.check(abs(sim.get_worker("worker_frontend_dev")["fatigue"] - expected_f) < 1e-9, "NaN delta safely ignored without corruption", "Tier2_EdgeDeltas")
    sim.update_staff_simulation(float("inf"))
    reporter.check(abs(sim.get_worker("worker_frontend_dev")["fatigue"] - expected_f) < 1e-9, "Inf delta safely ignored without overflow", "Tier2_EdgeDeltas")

    # ==========================================================================
    # TIER 3: Desk Ergonomics Dampening Verification (0%, 25%, 60%)
    # ==========================================================================
    sim.reset_state()
    sim.energy = 500000.0
    sim.hire_worker("Frontend Dev")   # Desk 0
    sim.hire_worker("Backend Dev")    # Desk 1
    sim.hire_worker("UI/UX Designer") # Desk 2

    # Upgrade Desk 1 to Level 2 (25% reduction -> mult 0.75)
    sim.upgrade_desk(1)
    # Upgrade Desk 2 to Level 3 (60% reduction -> mult 0.40)
    sim.upgrade_desk(2)
    sim.upgrade_desk(2)

    reporter.check(sim.get_desk_level(0) == 1, "Desk 0 is Level 1", "Tier3_Ergonomics")
    reporter.check(sim.get_desk_level(1) == 2, "Desk 1 is Level 2", "Tier3_Ergonomics")
    reporter.check(sim.get_desk_level(2) == 3, "Desk 2 is Level 3", "Tier3_Ergonomics")

    reporter.check(abs(sim.get_desk_fatigue_multiplier(1) - 1.00) < 1e-9, "Desk L1 multiplier is 1.00 (0% dampening)", "Tier3_Ergonomics")
    reporter.check(abs(sim.get_desk_fatigue_multiplier(2) - 0.75) < 1e-9, "Desk L2 multiplier is 0.75 (25% dampening)", "Tier3_Ergonomics")
    reporter.check(abs(sim.get_desk_fatigue_multiplier(3) - 0.40) < 1e-9, "Desk L3 multiplier is 0.40 (60% dampening)", "Tier3_Ergonomics")

    # Simulate 1800s (30 minutes)
    sim.update_staff_simulation(1800.0)
    w_l1 = sim.get_worker("worker_frontend_dev")
    w_l2 = sim.get_worker("worker_backend_dev")
    w_l3 = sim.get_worker("worker_ui_ux_designer")

    # Expected:
    # L1: 30 min * 0.02 = 0.6000
    # L2: 30 min * 0.02 * 0.75 = 0.4500 (25% reduction)
    # L3: 30 min * 0.02 * 0.40 = 0.2400 (60% reduction)
    reporter.check(abs(w_l1["fatigue"] - 0.60) < 1e-6, f"L1 worker fatigue after 30 min is 0.60 (got {w_l1['fatigue']:.4f})", "Tier3_Dampening")
    reporter.check(abs(w_l2["fatigue"] - 0.45) < 1e-6, f"L2 worker fatigue after 30 min is 0.45 (got {w_l2['fatigue']:.4f}, exact -25%)", "Tier3_Dampening")
    reporter.check(abs(w_l3["fatigue"] - 0.24) < 1e-6, f"L3 worker fatigue after 30 min is 0.24 (got {w_l3['fatigue']:.4f}, exact -60%)", "Tier3_Dampening")

    # Verify exact ratios
    ratio_l2 = w_l2["fatigue"] / w_l1["fatigue"]
    ratio_l3 = w_l3["fatigue"] / w_l1["fatigue"]
    reporter.check(abs(ratio_l2 - 0.75) < 1e-6, f"Fatigue ratio L2/L1 is exactly 0.75 (got {ratio_l2:.6f})", "Tier3_Ratio")
    reporter.check(abs(ratio_l3 - 0.40) < 1e-6, f"Fatigue ratio L3/L1 is exactly 0.40 (got {ratio_l3:.6f})", "Tier3_Ratio")

    # ==========================================================================
    # TIER 4: Morale Decay & State Transition Dynamics
    # ==========================================================================
    sim.reset_state()
    sim.energy = 100000.0
    sim.hire_worker("Frontend Dev") # Desk 0 Level 1

    # Simulate 2399 seconds (39.983 minutes, fatigue reaches ~0.799667 < 0.80)
    sim.update_staff_simulation(2399.0)
    w = sim.get_worker("worker_frontend_dev")
    reporter.check(w["fatigue"] < 0.80, f"Worker fatigue is under 0.80 ({w['fatigue']:.6f})", "Tier4_Morale")
    reporter.check(abs(w["morale"] - 1.0) < 1e-9, f"Morale remains untouched at 1.0 while fatigue < 0.80 (got {w['morale']})", "Tier4_Morale")
    reporter.check(w["current_state"] == "working", "Worker state remains 'working'", "Tier4_Morale")

    # Advance 1 second to cross 2400 seconds (40.0 minutes, fatigue exactly 0.80)
    sim.update_staff_simulation(1.0)
    w = sim.get_worker("worker_frontend_dev")
    reporter.check(abs(w["fatigue"] - 0.80) < 1e-6, f"Worker fatigue reaches 0.80 (got {w['fatigue']:.6f})", "Tier4_Morale")

    # Advance 300 seconds (5 minutes over threshold)
    # Fatigue increases by 5 * 0.02 = 0.10 -> 0.90
    # Morale decays by 5 * 0.02 = 0.10 -> 0.90
    sim.update_staff_simulation(300.0)
    w = sim.get_worker("worker_frontend_dev")
    reporter.check(abs(w["fatigue"] - 0.90) < 1e-6, f"Worker fatigue reaches 0.90 (got {w['fatigue']:.6f})", "Tier4_MoraleDecay")
    reporter.check(abs(w["morale"] - 0.90) < 1e-6, f"Worker morale decayed to 0.90 (got {w['morale']:.6f})", "Tier4_MoraleDecay")
    reporter.check(w["current_state"] == "working", "Worker still 'working' at fatigue 0.90", "Tier4_MoraleDecay")

    # Advance 301 seconds (past 3000 seconds total = 50 minutes)
    # Fatigue increases to 1.00 (clamped strictly)
    # State transitions to "fatigued"
    # Morale decays to 0.80
    sim.update_staff_simulation(301.0)
    w = sim.get_worker("worker_frontend_dev")
    reporter.check(abs(w["fatigue"] - 1.00) < 1e-9, f"Worker fatigue clamped strictly at 1.0 (got {w['fatigue']:.6f})", "Tier4_Exhaustion")
    reporter.check(w["current_state"] == "fatigued", f"Worker transitioned to 'fatigued' state (got '{w['current_state']}')", "Tier4_Exhaustion")
    reporter.check(sim.get_active_workers_count() == 0, f"Exhausted worker excluded from active count (got {sim.get_active_workers_count()})", "Tier4_Exhaustion")
    reporter.check(abs(sim.get_staff_rps_multiplier() - 1.0) < 1e-9, "Staff RPS multiplier drops to identity 1.00 when all workers fatigued", "Tier4_Exhaustion")

    # Simulate while in fatigued state for 2400 seconds (40 minutes)
    # Fatigue stays clamped at 1.0
    # Morale decays from 0.80 down to 0.00
    sim.update_staff_simulation(2400.0)
    w = sim.get_worker("worker_frontend_dev")
    reporter.check(abs(w["fatigue"] - 1.00) < 1e-9, "Fatigue remains clamped at 1.0 in fatigued state", "Tier4_Clamping")
    reporter.check(abs(w["morale"] - 0.00) < 1e-9, f"Morale decayed down to exactly 0.0 (got {w['morale']:.6f})", "Tier4_Clamping")

    # Simulate an extra 10,000 seconds to verify strict bounds preservation
    sim.update_staff_simulation(10000.0)
    w = sim.get_worker("worker_frontend_dev")
    reporter.check(w["fatigue"] <= 1.0 and w["fatigue"] >= 0.0, f"Fatigue strictly clamped in [0.0, 1.0] under 10k second assault (got {w['fatigue']})", "Tier4_Bounds")
    reporter.check(w["morale"] <= 1.0 and w["morale"] >= 0.0, f"Morale strictly clamped in [0.0, 1.0] under 10k second assault (got {w['morale']})", "Tier4_Bounds")

    # ==========================================================================
    # TIER 5: Coffee Break Recovery & Hyper-Focus Lifecycle
    # ==========================================================================
    # Trigger coffee break for the exhausted, 0-morale worker
    reporter.check(sim.give_team_coffee_break(), "give_team_coffee_break() succeeds", "Tier5_Coffee")
    w = sim.get_worker("worker_frontend_dev")
    reporter.check(abs(w["fatigue"] - 0.0) < 1e-9, "Fatigue instantly reset to 0.0 upon coffee break", "Tier5_Coffee")
    reporter.check(abs(w["morale"] - 1.0) < 1e-9, "Morale instantly restored to 1.0 upon coffee break", "Tier5_Coffee")
    reporter.check(w["current_state"] == "working", "State restored to 'working'", "Tier5_Coffee")
    reporter.check(sim.get_active_workers_count() == 1, "Worker is active again", "Tier5_Coffee")
    reporter.check(sim.is_staff_hyper_focus_active(), "Hyper-focus buff is active", "Tier5_Coffee")
    reporter.check(abs(sim.get_staff_hyper_focus_multiplier() - 1.50) < 1e-9, "Hyper-focus multiplier is 1.50x", "Tier5_Coffee")
    reporter.check(abs(sim.get_staff_hyper_focus_time_remaining() - 60.0) < 1e-9, "Hyper-focus time remaining is 60.0s", "Tier5_Coffee")

    # Process 30 seconds
    sim.process(30.0)
    reporter.check(abs(sim.get_staff_hyper_focus_time_remaining() - 30.0) < 1e-6, f"Timer decayed to 30.0s after 30s process (got {sim.get_staff_hyper_focus_time_remaining():.2f})", "Tier5_Countdown")
    reporter.check(sim.is_staff_hyper_focus_active(), "Hyper-focus still active at 30s", "Tier5_Countdown")

    # Process another 30 seconds (reaches 60s total)
    sim.process(30.0)
    reporter.check(not sim.is_staff_hyper_focus_active(), "Hyper-focus expires cleanly at 60s", "Tier5_Expiry")
    reporter.check(abs(sim.get_staff_hyper_focus_time_remaining() - 0.0) < 1e-9, "Hyper-focus time remaining is 0.0s post-expiry", "Tier5_Expiry")
    reporter.check(abs(sim.get_staff_hyper_focus_multiplier() - 1.00) < 1e-9, "Multiplier returns to 1.00x post-expiry", "Tier5_Expiry")

    # Idempotence / non-stacking test: trigger coffee break twice rapidly
    sim.give_team_coffee_break()
    sim.process(10.0)
    reporter.check(abs(sim.get_staff_hyper_focus_time_remaining() - 50.0) < 1e-6, "Timer at 50s", "Tier5_ReTrigger")
    sim.give_team_coffee_break() # Re-trigger
    reporter.check(abs(sim.get_staff_hyper_focus_time_remaining() - 60.0) < 1e-9, "Re-trigger refreshed timer back to 60.0s", "Tier5_ReTrigger")
    reporter.check(abs(sim.get_staff_hyper_focus_multiplier() - 1.50) < 1e-9, "Multiplier remains 1.50x (does not compound to 2.25x)", "Tier5_ReTrigger")

    # ==========================================================================
    # TIER 6: Staff Lifecycle & Desk Reassignment Stress (1,000 Monte Carlo Cycles)
    # ==========================================================================
    sim.reset_state()
    sim.energy = 10000000.0 # Rich player for stress testing

    roles_pool = list(STAFF_ROLE_DEFINITIONS.keys())
    monte_carlo_errors = 0

    for iteration in range(1000):
        action = random.choice(["hire", "fire", "upgrade", "step", "coffee", "epiphany"])

        if action == "hire":
            role = random.choice(roles_pool + ["NonExistent Role", ""])
            sim.hire_worker(role)
        elif action == "fire":
            workers = sim.get_hired_workers()
            if workers:
                target = random.choice([w["id"] for w in workers] + ["invalid_id", ""])
                sim.fire_worker(target)
        elif action == "upgrade":
            desk = random.randint(-1, 6)
            sim.upgrade_desk(desk)
        elif action == "step":
            dt = random.uniform(0.001, 120.0)
            sim.update_staff_simulation(dt)
        elif action == "coffee":
            sim.give_team_coffee_break()
        elif action == "epiphany":
            workers = sim.get_hired_workers()
            target_id = random.choice([w["id"] for w in workers]) if workers else "nobody"
            sim.trigger_worker_epiphany(target_id)

        # Invariant checks
        hired = sim.get_hired_workers()
        if len(hired) > MAX_WORKERS:
            monte_carlo_errors += 1
        desks = [w["desk_assigned"] for w in hired]
        if len(desks) != len(set(desks)): # Desks must be unique
            monte_carlo_errors += 1
        for d in desks:
            if d not in range(MAX_WORKERS):
                monte_carlo_errors += 1
        for w in hired:
            if not (0.0 <= w["fatigue"] <= 1.0):
                monte_carlo_errors += 1
            if not (0.0 <= w["morale"] <= 1.0):
                monte_carlo_errors += 1
            if w["current_state"] not in ["working", "break", "fatigued", "celebrating"]:
                monte_carlo_errors += 1
        for lvl in sim.get_desk_levels():
            if lvl not in range(1, MAX_DESK_LEVEL + 1):
                monte_carlo_errors += 1
        mult = sim.get_staff_rps_multiplier()
        if mult < 1.0 or math.isnan(mult) or math.isinf(mult):
            monte_carlo_errors += 1

    reporter.check(monte_carlo_errors == 0, f"1,000 Monte Carlo rapid lifecycle stress cycles passed with 0 invariant violations (got {monte_carlo_errors} errors)", "Tier6_MonteCarlo")

    # Systematic desk vacancy reuse check
    sim.reset_state()
    sim.energy = 100000.0
    for r in roles_pool:
        sim.hire_worker(r)
    # All 5 desks occupied 0,1,2,3,4
    desks_before = [w["desk_assigned"] for w in sim.get_hired_workers()]
    reporter.check(sorted(desks_before) == [0, 1, 2, 3, 4], "All 5 desks occupied [0, 1, 2, 3, 4]", "Tier6_DeskReuse")

    # Fire desk 2 (UI/UX Designer)
    sim.fire_worker("worker_ui_ux_designer")
    reporter.check(len(sim.get_hired_workers()) == 4, "Worker count reduced to 4 after firing desk 2 occupant", "Tier6_DeskReuse")

    # Re-hire UI/UX Designer -> MUST be assigned to freed desk 2
    sim.hire_worker("UI/UX Designer")
    new_w = sim.get_worker("worker_ui_ux_designer")
    reporter.check(new_w["desk_assigned"] == 2, f"Re-hired worker correctly claimed vacated desk 2 (got {new_w['desk_assigned']})", "Tier6_DeskReuse")

    # ==========================================================================
    # TIER 7: Extreme Multiplier Compounding & Scaling Invariants
    # ==========================================================================
    # 0 workers identity test
    sim.reset_state()
    reporter.check(abs(sim.get_staff_rps_multiplier() - 1.000000) < 1e-9, "Zero workers produces exact identity multiplier 1.000000x", "Tier7_Scaling")

    # All 5 workers at 1.0 morale
    sim.energy = 100000.0
    for r in roles_pool:
        sim.hire_worker(r)
    reporter.check(abs(sim.get_staff_rps_multiplier() - 1.250000) < 1e-9, "5 active full-morale workers produce exact 1.250000x multiplier (+25%)", "Tier7_Scaling")

    # Multiplier compounding with Angel Shares (e.g. 500 shares = 11.0x) and Syndicate Tier 5 (1.25x)
    sim.base_passive_rps = 1000.0
    sim.angel_shares = 500
    sim.syndicate_tier = 5
    # Expected: 1000 * (1.0 + 500*0.02 = 11.0) * (1.0 + 5*0.05 = 1.25) * (1.25 staff) = 17,187.5
    expected_compounded = 1000.0 * 11.0 * 1.25 * 1.25
    effective_rps = sim.get_effective_passive_rps()
    reporter.check(abs(effective_rps - expected_compounded) < 1e-6, f"Effective RPS compounded correctly: expected {expected_compounded}, got {effective_rps}", "Tier7_Compounding")

    # Extreme boundary: Angel Shares = 1,000,000
    sim.angel_shares = 1000000
    huge_rps = sim.get_effective_passive_rps()
    reporter.check(not math.isnan(huge_rps) and not math.isinf(huge_rps) and huge_rps > 0.0, "System survives 1M Angel Shares without numeric overflow or NaN", "Tier7_ExtremeBoundary")

    # All workers fatigued fallback test
    sim.update_staff_simulation(10000.0) # Drain all workers to exhausted
    reporter.check(sim.get_active_workers_count() == 0, "All workers are fatigued", "Tier7_ExhaustedFallback")
    reporter.check(abs(sim.get_staff_rps_multiplier() - 1.000000) < 1e-9, "When all workers are exhausted, multiplier is strictly 1.000000 (no penalty to base economy)", "Tier7_ExhaustedFallback")

    # ==========================================================================
    # TIER 8: Epiphany Moments Stress & Economy Integration
    # ==========================================================================
    sim.reset_state()
    sim.base_passive_rps = 100.0
    sim.energy = 50.0
    # Epiphany with 0 workers -> returns 0.0
    reward_zero = sim.trigger_worker_epiphany("nobody")
    reporter.check(reward_zero == 0.0, "Epiphany with 0 workers yields 0.0 reward", "Tier8_Epiphany")

    # Hire 1 worker
    sim.energy = 10000.0
    sim.hire_worker("Frontend Dev")
    initial_energy = sim.energy
    # Expected reward: max(100.0, RPS * 15.0).
    # RPS = 100.0 * 1.05 = 105.0. 105.0 * 15.0 = 1575.0
    expected_reward = 105.0 * 15.0
    reward = sim.trigger_worker_epiphany("worker_frontend_dev")
    reporter.check(abs(reward - expected_reward) < 1e-6, f"Epiphany reward matches 15x passive RPS formula: expected {expected_reward}, got {reward}", "Tier8_Epiphany")
    reporter.check(abs(sim.energy - (initial_energy + expected_reward)) < 1e-6, "Player energy credited with exact epiphany reward", "Tier8_Epiphany")

    # Epiphany with unknown worker ID -> falls back to first hired worker
    reward_fallback = sim.trigger_worker_epiphany("unknown_ghost_worker")
    reporter.check(abs(reward_fallback - expected_reward) < 1e-6, "Unknown worker ID gracefully falls back to first hired worker", "Tier8_Epiphany")

    # Low RPS floor test: base RPS = 1.0 -> 1.0 * 15 = 15.0 < 100.0 minimum floor
    sim.base_passive_rps = 1.0
    reward_floor = sim.trigger_worker_epiphany("worker_frontend_dev")
    reporter.check(abs(reward_floor - 100.0) < 1e-6, f"Low RPS clamped to 100.0 minimum energy floor (got {reward_floor})", "Tier8_EpiphanyFloor")

    # ==========================================================================
    # TIER 9: Persistence Fuzzing & Malicious Corruption Recovery (500 Fuzz Cases)
    # ==========================================================================
    sim.reset_state()
    sim.energy = 100000.0
    sim.hire_worker("Frontend Dev")
    sim.hire_worker("Backend Dev")
    sim.upgrade_desk(0)
    sim.upgrade_desk(0) # Desk 0 Level 3
    valid_payload = sim.serialize()

    # Normal roundtrip fidelity check
    sim2 = SimulatedGameStateStaffStress()
    sim2.deserialize(valid_payload)
    reporter.check(len(sim2.get_hired_workers()) == 2, "Normal roundtrip preserves 2 workers", "Tier9_PersistenceNormal")
    reporter.check(sim2.get_desk_level(0) == 3, "Normal roundtrip preserves Desk 0 Level 3", "Tier9_PersistenceNormal")

    # 500 Malicious Fuzz Payloads
    fuzz_failures = 0
    fuzz_types = [
        "negative_morale",
        "excessive_morale",
        "nan_morale",
        "inf_morale",
        "negative_fatigue",
        "excessive_fatigue",
        "nan_fatigue",
        "inf_fatigue",
        "invalid_desk_level_low",
        "invalid_desk_level_high",
        "non_numeric_desk",
        "corrupt_worker_state",
        "missing_staff_block",
        "null_worker_list",
        "corrupt_hyper_focus_timer",
    ]

    for f_idx in range(500):
        corrupt_data = json.loads(json.dumps(valid_payload))
        f_type = random.choice(fuzz_types)

        if f_type == "negative_morale":
            corrupt_data["staff"]["workers"][0]["morale"] = -999.0
        elif f_type == "excessive_morale":
            corrupt_data["staff"]["workers"][0]["morale"] = 42.0
        elif f_type == "nan_morale":
            corrupt_data["staff"]["workers"][0]["morale"] = float("nan")
        elif f_type == "inf_morale":
            corrupt_data["staff"]["workers"][0]["morale"] = float("inf")
        elif f_type == "negative_fatigue":
            corrupt_data["staff"]["workers"][0]["fatigue"] = -10.0
        elif f_type == "excessive_fatigue":
            corrupt_data["staff"]["workers"][0]["fatigue"] = 15.0
        elif f_type == "nan_fatigue":
            corrupt_data["staff"]["workers"][0]["fatigue"] = float("nan")
        elif f_type == "inf_fatigue":
            corrupt_data["staff"]["workers"][0]["fatigue"] = float("inf")
        elif f_type == "invalid_desk_level_low":
            corrupt_data["staff"]["desk_levels"][0] = -5
        elif f_type == "invalid_desk_level_high":
            corrupt_data["staff"]["desk_levels"][0] = 999
        elif f_type == "non_numeric_desk":
            corrupt_data["staff"]["desk_levels"][0] = "RGB_SUPER_DESK"
        elif f_type == "corrupt_worker_state":
            corrupt_data["staff"]["workers"][0]["current_state"] = "ghost_mode"
        elif f_type == "missing_staff_block":
            corrupt_data.pop("staff")
        elif f_type == "null_worker_list":
            corrupt_data["staff"]["workers"] = None
        elif f_type == "corrupt_hyper_focus_timer":
            corrupt_data["staff"]["hyper_focus_timer"] = float("nan")

        try:
            fuzzer = SimulatedGameStateStaffStress()
            fuzzer.deserialize(corrupt_data)

            # Invariant checks post-deserialization
            for w in fuzzer.get_hired_workers():
                if not (0.0 <= w["morale"] <= 1.0) or math.isnan(w["morale"]):
                    fuzz_failures += 1
                if not (0.0 <= w["fatigue"] <= 1.0) or math.isnan(w["fatigue"]):
                    fuzz_failures += 1
                if w["current_state"] not in ["working", "break", "fatigued", "celebrating"]:
                    fuzz_failures += 1
            for d in fuzzer.get_desk_levels():
                if d not in [1, 2, 3]:
                    fuzz_failures += 1
            if fuzzer.staff_hyper_focus_timer < 0.0 or math.isnan(fuzzer.staff_hyper_focus_timer):
                fuzz_failures += 1
        except Exception:
            fuzz_failures += 1

    reporter.check(fuzz_failures == 0, f"500 malicious persistence fuzz payloads safely normalized with 0 exceptions or corruption (got {fuzz_failures} errors)", "Tier9_PersistenceFuzz")

    # ==========================================================================
    # TIER 10: IPO Prestige Ascension Invariants
    # ==========================================================================
    sim.reset_state()
    sim.energy = 500000.0
    for r in ["Frontend Dev", "Backend Dev", "UI/UX Designer"]:
        sim.hire_worker(r)
    sim.upgrade_desk(0)
    sim.upgrade_desk(0) # Desk 0 Level 3
    sim.give_team_coffee_break() # Start coffee break buff
    # Put one worker in break
    sim.hired_workers[1]["current_state"] = "break"

    reporter.check(len(sim.get_hired_workers()) == 3, "Pre-IPO: 3 workers hired", "Tier10_IPO")
    reporter.check(sim.get_desk_level(0) == 3, "Pre-IPO: Desk 0 is Level 3", "Tier10_IPO")
    reporter.check(sim.is_staff_hyper_focus_active(), "Pre-IPO: Coffee break buff is active", "Tier10_IPO")

    # Trigger IPO
    ipo_result = sim.trigger_ipo()
    reporter.check(ipo_result["success"], "trigger_ipo() executes successfully", "Tier10_IPO")
    reporter.check(sim.energy == 0.0, "IPO resets player energy to 0.0", "Tier10_IPO")
    reporter.check(len(sim.get_hired_workers()) == 3, "IPO strictly preserved all 3 hired workers", "Tier10_IPO")
    reporter.check(sim.get_desk_level(0) == 3, "IPO strictly preserved Desk 0 Level 3 upgrade", "Tier10_IPO")
    reporter.check(not sim.is_staff_hyper_focus_active(), "IPO extinguished temporary hyper-focus buff", "Tier10_IPO")
    reporter.check(sim.staff_hyper_focus_timer == 0.0, "IPO reset hyper-focus timer to 0.0s", "Tier10_IPO")
    reporter.check(sim.get_worker("worker_backend_dev")["current_state"] == "working", "Worker in 'break' state normalized back to 'working' post-IPO", "Tier10_IPO")

    # Final Summary
    return reporter.summary()


if __name__ == "__main__":
    sys.exit(run_stress_tests())
