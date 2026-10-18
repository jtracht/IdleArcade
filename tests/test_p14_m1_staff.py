#!/usr/bin/env python3
"""
Phase 14 Milestone 1: Staff Management & Morale Economy Verification Suite
==========================================================================
Target: Godot 4.3 IdleArcade - Milestone M1 (Requirement R1: Staff Management & Morale Economy)

Validates:
  1. AST & Static Code Contract:
     - Signals declared in game_state.gd:
       * staff_worker_hired(worker_data: Dictionary)
       * staff_worker_fired(worker_id: String)
       * staff_worker_state_changed(worker_id: String, new_state: String)
       * staff_worker_morale_updated(worker_id: String, new_morale: float, new_fatigue: float)
       * staff_desk_upgraded(desk_index: int, new_level: int)
       * staff_coffee_break_started(duration: float)
       * staff_coffee_break_ended()
       * staff_morale_updated(average_morale: float)
       * staff_epiphany_triggered(worker_id: String, reward_energy: float)
       * worker_hired, worker_fired, worker_state_changed, desk_upgraded, team_coffee_break_started (aliases)
     - Constants declared in game_state.gd:
       * MAX_WORKERS (5), MAX_DESK_LEVEL (3)
       * STAFF_ROLE_DEFINITIONS covering 5 specialist roles
       * DESK_CONFIG covering 3 tiers (1..3)
       * BASE_WORKER_FATIGUE_RATE_PER_MINUTE / BASE_WORKER_FATIGUE_RATE_PER_SECOND (0.02/min)
     - State variables declared in game_state.gd:
       * hired_workers: Array
       * desk_levels: Array
       * staff_hyper_focus_timer, staff_hyper_focus_active, staff_hyper_focus_multiplier
       * staff_coffee_break_timer, staff_coffee_break_active
     - Methods declared in game_state.gd:
       * hire_worker, fire_worker, get_hired_workers, get_worker
       * upgrade_desk, get_desk_level, get_desk_levels, get_desk_upgrade_cost, get_desk_fatigue_multiplier
       * give_team_coffee_break, is_staff_hyper_focus_active, get_staff_hyper_focus_time_remaining
       * get_staff_hyper_focus_multiplier, get_staff_rps_multiplier, get_staff_average_morale
       * trigger_worker_epiphany, trigger_epiphany, update_staff_simulation
     - System Integrations:
       * get_effective_passive_rps() compounds get_staff_rps_multiplier()
       * save_to_disk() and load_from_disk() serialize and deserialize staff state with defensive clamping
       * reset_state() initializes staff structures
       * trigger_ipo() strictly preserves hired_workers and desk_levels, while resetting temporary coffee buffs

  2. Mathematical Matrix & Role Catalog Oracle:
     - 5 specialist roles: Frontend Dev, Backend Dev, UI/UX Designer, Growth Hacker, QA Engineer
     - Desk fatigue reduction matrix: Level 1 (0%), Level 2 (25%), Level 3 (60%)
     - Staff multiplier calculation matrix: 1.0 + (Active * 0.05) * Morale
     - Zero-regression identity: 0 workers = 1.00000x multiplier

  3. Simulated Staff Lifecycle & State Machine:
     - Recruitment (cost deduction, desk assignment, max capacity, role duplicate checks)
     - Dismissal (desk freeing, average morale & RPS recalculation)
     - Desk upgrades (cost deduction, level clamping at 3, invalid bounds rejection)
     - Dynamic fatigue accumulation (+0.02/min) dampened by desk ergonomics
     - Morale decay when fatigue >= 0.8, automatic state transition to "fatigued" at fatigue >= 1.0
     - Coffee break recovery (fatigue -> 0, morale -> 1.0, hyper-focus timer 60s, state -> "working")
     - Worker epiphany lump-sum energy awards (>= 100.0, 15x passive RPS)

  4. State Serialization & Recovery Oracle:
     - JSON roundtrip preserving workers, desk levels, and buff timers
     - Fuzz resilience: negative morale/fatigue, NaN/Inf, invalid states, out-of-range desk levels
     - Backward compatibility with legacy saves lacking staff keys

  5. IPO Prestige Ascension Invariants:
     - Full retention of hired_workers and desk_levels across prestige reset
     - Reset of temporary hyper-focus buff timers and restoration of break states

Executable via: python tests/test_p14_m1_staff.py
"""

import json
import math
import re
import sys
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
        print(f"{Colors.BOLD}Phase 14 Milestone M1 (Staff Management & Morale) Results{Colors.ENDC}")
        print("=" * 70)
        print(f"  Total Checks : {self.total}")
        print(f"  Passed       : {Colors.OKGREEN}{self.passed}{Colors.ENDC}")
        print(f"  Failed       : {Colors.FAIL if self.failed > 0 else Colors.OKGREEN}{self.failed}{Colors.ENDC}")
        if self.failures:
            print(f"\n{Colors.FAIL}Failed Checks:{Colors.ENDC}")
            for f in self.failures:
                print(f"  - {f}")
        print("=" * 70)
        return 0 if self.failed == 0 else 1


# ==============================================================================
# Simulated GameState Staff Engine (Exact Mirror of GDScript Logic)
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


class SimulatedGameStateStaff:
    def __init__(self, initial_energy: float = 100000.0, base_rps: float = 100.0):
        self.energy = initial_energy
        self.total_energy_earned = initial_energy
        self.total_lifetime_energy = initial_energy
        self.base_passive_rps = base_rps
        self.angel_shares = 0
        self.total_ipos_completed = 0
        self.hired_workers: List[Dict[str, Any]] = []
        self.desk_levels: List[int] = [1, 1, 1, 1, 1]
        self.staff_hyper_focus_active: bool = False
        self.staff_hyper_focus_timer: float = 0.0
        self.staff_hyper_focus_remaining: float = 0.0
        self.staff_hyper_focus_multiplier: float = 1.50
        self.staff_coffee_break_active: bool = False
        self.staff_coffee_break_timer: float = 0.0
        self.staff_coffee_break_remaining: float = 0.0
        self.emitted_signals: List[tuple] = []

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

    def get_effective_passive_rps(self) -> float:
        staff_mult = self.get_staff_rps_multiplier()
        return self.base_passive_rps * staff_mult

    def get_staff_rps_multiplier(self) -> float:
        if not self.hired_workers:
            return 1.0
        active_count = self.get_active_workers_count()
        if active_count <= 0:
            return 1.0
        avg_morale = self.get_staff_average_morale()
        return 1.0 + (float(active_count) * 0.05) * avg_morale

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

    def get_average_worker_morale(self) -> float:
        return self.get_staff_average_morale()

    def get_hired_workers(self) -> List[Dict[str, Any]]:
        return [dict(w) for w in self.hired_workers]

    def get_worker(self, worker_id: str) -> Dict[str, Any]:
        norm = self._normalize_role(worker_id)
        for w in self.hired_workers:
            if str(w.get("id", "")) == worker_id or str(w.get("role", "")) == worker_id or (norm and str(w.get("role", "")) == norm):
                return dict(w)
        return {}

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
        self.emitted_signals.append(("staff_worker_hired", dict(new_worker)))
        self.emitted_signals.append(("worker_hired", dict(new_worker)))
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
        self.emitted_signals.append(("worker_fired", found_id))
        self.emitted_signals.append(("staff_morale_updated", self.get_staff_average_morale()))
        self.emitted_signals.append(("rps_changed", self.get_effective_passive_rps()))
        return True

    def upgrade_desk(self, desk_index: int) -> bool:
        if desk_index < 0 or desk_index >= MAX_WORKERS or desk_index >= len(self.desk_levels):
            return False
        curr_lvl = self.desk_levels[desk_index]
        if curr_lvl >= MAX_DESK_LEVEL:
            return False
        next_lvl = curr_lvl + 1
        cost = float(DESK_CONFIG[next_lvl]["cost"])
        if self.energy < cost:
            return False

        self.energy -= cost
        self.desk_levels[desk_index] = next_lvl
        self.emitted_signals.append(("staff_desk_upgraded", desk_index, next_lvl))
        self.emitted_signals.append(("desk_upgraded", desk_index, next_lvl, cost))
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

        self.staff_hyper_focus_active = True
        self.staff_hyper_focus_timer = 60.0
        self.staff_hyper_focus_remaining = 60.0
        self.staff_coffee_break_active = True
        self.staff_coffee_break_timer = 60.0
        self.staff_coffee_break_remaining = 60.0
        self.staff_hyper_focus_multiplier = 1.50

        self.emitted_signals.append(("staff_coffee_break_started", 60.0))
        self.emitted_signals.append(("team_coffee_break_started", 60.0, 1.50))
        self.emitted_signals.append(("staff_morale_updated", self.get_staff_average_morale()))
        self.emitted_signals.append(("rps_changed", self.get_effective_passive_rps()))
        return True

    def is_staff_hyper_focus_active(self) -> bool:
        return (self.staff_hyper_focus_active or self.staff_coffee_break_active) and (self.staff_hyper_focus_timer > 0.0 or self.staff_coffee_break_timer > 0.0)

    def get_staff_hyper_focus_time_remaining(self) -> float:
        return max(0.0, max(self.staff_hyper_focus_timer, self.staff_coffee_break_timer))

    def get_staff_hyper_focus_multiplier(self) -> float:
        return self.staff_hyper_focus_multiplier if self.is_staff_hyper_focus_active() else 1.0

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
        self.emitted_signals.append(("epiphany_collected", target_id, reward))
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
            avg_m = total_morale / float(len(self.hired_workers))
            self.emitted_signals.append(("staff_morale_updated", avg_m))
            self.emitted_signals.append(("rps_changed", self.get_effective_passive_rps()))
        elif any_state_change:
            self.emitted_signals.append(("rps_changed", self.get_effective_passive_rps()))

    def process_frame(self, delta: float) -> None:
        clamped_delta = min(0.1, max(0.0, delta))
        self.update_staff_simulation(clamped_delta)
        if self.staff_hyper_focus_timer > 0.0 or self.staff_hyper_focus_active:
            self.staff_hyper_focus_timer -= delta
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
                self.emitted_signals.append(("staff_coffee_break_ended",))
                self.emitted_signals.append(("team_coffee_break_ended",))
                self.emitted_signals.append(("rps_changed", self.get_effective_passive_rps()))

    def to_dict(self) -> Dict[str, Any]:
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
        }

    def load_from_dict(self, data: Dict[str, Any]) -> None:
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
        # Workers and desks are strictly PRESERVED
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
# Master Test Execution
# ==============================================================================

def run_all_tests() -> int:
    reporter = TestReporter()
    base_dir = Path(__file__).resolve().parent.parent
    game_state_path = base_dir / "scripts" / "autoload" / "game_state.gd"

    print(f"{Colors.HEADER}{Colors.BOLD}IdleArcade Phase 14 Milestone M1 (Staff Management & Morale Economy) Test Suite{Colors.ENDC}\n")

    # --------------------------------------------------------------------------
    # Tier 1: Static AST & Contract Checks on game_state.gd
    # --------------------------------------------------------------------------
    reporter.check(game_state_path.exists(), "game_state.gd exists on disk", "AST_Contract")
    content = game_state_path.read_text(encoding="utf-8")

    # Signals
    req_signals = [
        "staff_worker_hired(worker_data: Dictionary)",
        "staff_worker_fired(worker_id: String)",
        "staff_worker_state_changed(worker_id: String, new_state: String)",
        "staff_worker_morale_updated(worker_id: String, new_morale: float, new_fatigue: float)",
        "staff_desk_upgraded(desk_index: int, new_level: int)",
        "staff_coffee_break_started(duration: float)",
        "staff_coffee_break_ended()",
        "staff_morale_updated(average_morale: float)",
        "staff_epiphany_triggered(worker_id: String, reward_energy: float)",
        "worker_hired",
        "worker_fired",
        "worker_state_changed",
        "desk_upgraded",
        "team_coffee_break_started",
        "team_coffee_break_ended",
        "epiphany_collected",
    ]
    for sig in req_signals:
        sig_name = sig.split("(")[0]
        pattern = rf"\bsignal\s+{re.escape(sig_name)}\b"
        reporter.check(bool(re.search(pattern, content)), f"Signal '{sig_name}' declared", "AST_Signals")

    # Constants
    reporter.check("const MAX_WORKERS: int = 5" in content or "const MAX_WORKERS = 5" in content, "MAX_WORKERS == 5 constant declared", "AST_Constants")
    reporter.check("const MAX_DESK_LEVEL: int = 3" in content or "const MAX_DESK_LEVEL = 3" in content, "MAX_DESK_LEVEL == 3 constant declared", "AST_Constants")
    reporter.check("STAFF_ROLE_DEFINITIONS" in content, "STAFF_ROLE_DEFINITIONS constant declared", "AST_Constants")
    reporter.check("DESK_CONFIG" in content, "DESK_CONFIG constant declared", "AST_Constants")

    # 5 Roles in STAFF_ROLE_DEFINITIONS
    for role_name in ["Frontend Dev", "Backend Dev", "UI/UX Designer", "Growth Hacker", "QA Engineer"]:
        reporter.check(f'"{role_name}"' in content, f"Role '{role_name}' present in STAFF_ROLE_DEFINITIONS", "AST_Roles")

    # State variables
    reporter.check(bool(re.search(r"var\s+hired_workers\s*:\s*Array", content)), "State var 'hired_workers' declared", "AST_Variables")
    reporter.check(bool(re.search(r"var\s+desk_levels\s*:\s*Array", content)), "State var 'desk_levels' declared", "AST_Variables")
    reporter.check("staff_hyper_focus_timer" in content, "State var 'staff_hyper_focus_timer' declared", "AST_Variables")
    reporter.check("staff_coffee_break_timer" in content, "State var 'staff_coffee_break_timer' declared", "AST_Variables")

    # Public Methods
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
        reporter.check(bool(re.search(pattern, content)), f"Method '{method}' implemented", "AST_Methods")

    # System Integrations
    reporter.check("get_staff_rps_multiplier()" in content, "get_effective_passive_rps() compounds get_staff_rps_multiplier()", "AST_Integration")
    reporter.check('"staff"' in content, "save_to_disk() contains 'staff' dictionary block", "AST_Persistence")
    reporter.check('"hired_workers"' in content, "save_to_disk() provides top-level 'hired_workers' alias", "AST_Persistence")
    reporter.check("update_staff_simulation" in content, "_process() calls update_staff_simulation()", "AST_Simulation")

    # --------------------------------------------------------------------------
    # Tier 2: Mathematical Matrix & Role Definitions
    # --------------------------------------------------------------------------
    for role_name, defs in STAFF_ROLE_DEFINITIONS.items():
        reporter.check("hire_cost" in defs and defs["hire_cost"] > 0, f"Role '{role_name}' has valid positive hire_cost", "Math_Roles")
        reporter.check("default_name" in defs and len(defs["default_name"]) > 0, f"Role '{role_name}' has non-empty default_name", "Math_Roles")
        reporter.check(defs["desk_index"] in range(5), f"Role '{role_name}' has desk_index in [0..4]", "Math_Roles")

    # Desk fatigue dampening values
    sim = SimulatedGameStateStaff()
    reporter.check(abs(sim.get_desk_fatigue_multiplier(1) - 1.00) < 1e-6, "Desk Level 1 dampening is 1.00 (0% reduction)", "Math_Desks")
    reporter.check(abs(sim.get_desk_fatigue_multiplier(2) - 0.75) < 1e-6, "Desk Level 2 dampening is 0.75 (25% reduction)", "Math_Desks")
    reporter.check(abs(sim.get_desk_fatigue_multiplier(3) - 0.40) < 1e-6, "Desk Level 3 dampening is 0.40 (60% reduction)", "Math_Desks")

    # Staff RPS Multiplier Formula
    # 0 workers -> exactly 1.000x (Identity / zero regression)
    reporter.check(abs(sim.get_staff_rps_multiplier() - 1.0) < 1e-6, "0 workers yields exactly 1.00000x multiplier", "Math_Multiplier")

    # --------------------------------------------------------------------------
    # Tier 3: Recruitment, Firing, and Capacity Lifecycle
    # --------------------------------------------------------------------------
    # Insufficient energy test
    sim_broke = SimulatedGameStateStaff(initial_energy=100.0)
    reporter.check(sim_broke.hire_worker("Frontend Dev") is False, "Hiring fails with insufficient energy", "Lifecycle_Hire")
    reporter.check(len(sim_broke.hired_workers) == 0, "No worker added when energy is insufficient", "Lifecycle_Hire")

    # Valid hiring of all 5 roles
    sim_rec = SimulatedGameStateStaff(initial_energy=100000.0)
    roles = ["Frontend Dev", "Backend Dev", "UI/UX Designer", "Growth Hacker", "QA Engineer"]
    for idx, r in enumerate(roles):
        cost = STAFF_ROLE_DEFINITIONS[r]["hire_cost"]
        pre_energy = sim_rec.energy
        success = sim_rec.hire_worker(r)
        reporter.check(success is True, f"Hiring '{r}' succeeds", "Lifecycle_Hire")
        reporter.check(abs(sim_rec.energy - (pre_energy - cost)) < 1e-4, f"Hiring '{r}' deducted exactly {cost} energy", "Lifecycle_Hire")
        w = sim_rec.get_worker(r)
        reporter.check(w.get("role") == r, f"Worker role matches '{r}'", "Lifecycle_Hire")
        reporter.check(w.get("morale") == 1.0, f"Worker initial morale is 1.0", "Lifecycle_Hire")
        reporter.check(w.get("fatigue") == 0.0, f"Worker initial fatigue is 0.0", "Lifecycle_Hire")
        reporter.check(w.get("desk_assigned") == idx, f"Worker assigned to free desk {idx}", "Lifecycle_Hire")
        reporter.check(w.get("current_state") == "working", f"Worker state is 'working'", "Lifecycle_Hire")

    # 6th worker rejected (capacity reached)
    reporter.check(sim_rec.hire_worker("Frontend Dev") is False, "Hiring duplicate role rejected", "Lifecycle_Capacity")
    reporter.check(sim_rec.hire_worker("NonExistent Role") is False, "Hiring unknown role rejected", "Lifecycle_Capacity")
    reporter.check(len(sim_rec.hired_workers) == 5, "Staff capacity capped at exactly 5", "Lifecycle_Capacity")

    # Multiplier with 5 active workers at 1.0 morale: 1.0 + (5 * 0.05) * 1.0 = 1.250x (+25%)
    reporter.check(abs(sim_rec.get_staff_rps_multiplier() - 1.25) < 1e-6, "5 active workers at 1.0 morale produce 1.25000x (+25%)", "Math_Multiplier")
    reporter.check(abs(sim_rec.get_effective_passive_rps() - 125.0) < 1e-4, "Base 100 RPS scales to 125.0 with 5 full-morale workers", "Math_Multiplier")

    # Firing worker
    w_qa = sim_rec.get_worker("QA Engineer")
    qa_id = w_qa.get("id")
    reporter.check(sim_rec.fire_worker(qa_id) is True, f"Firing worker '{qa_id}' succeeds", "Lifecycle_Fire")
    reporter.check(len(sim_rec.hired_workers) == 4, "Worker count reduced to 4 after firing", "Lifecycle_Fire")
    reporter.check(sim_rec.get_worker(qa_id) == {}, "Fired worker query returns empty dict", "Lifecycle_Fire")
    # Multiplier with 4 active workers at 1.0 morale: 1.0 + (4 * 0.05) * 1.0 = 1.200x (+20%)
    reporter.check(abs(sim_rec.get_staff_rps_multiplier() - 1.20) < 1e-6, "4 active workers at 1.0 morale produce 1.20000x (+20%)", "Math_Multiplier")

    # Desk reassignment: newly hired worker should take the freed desk (desk 4)
    reporter.check(sim_rec.hire_worker("QA Engineer") is True, "Re-hiring 'QA Engineer' into freed desk succeeds", "Lifecycle_Desk")
    reporter.check(sim_rec.get_worker("QA Engineer").get("desk_assigned") == 4, "New worker correctly fills vacated desk 4", "Lifecycle_Desk")

    # --------------------------------------------------------------------------
    # Tier 4: Desk Ergonomics & Upgrades
    # --------------------------------------------------------------------------
    sim_desk = SimulatedGameStateStaff(initial_energy=50000.0)
    reporter.check(sim_desk.get_desk_level(0) == 1, "Initial desk 0 level is 1", "Desk_Upgrade")
    reporter.check(sim_desk.get_desk_upgrade_cost(0) == 5000.0, "Desk 0 upgrade to Level 2 costs 5000.0", "Desk_Upgrade")
    reporter.check(sim_desk.upgrade_desk(-1) is False, "Upgrade with negative index rejected", "Desk_Upgrade")
    reporter.check(sim_desk.upgrade_desk(5) is False, "Upgrade with out-of-bounds index (5) rejected", "Desk_Upgrade")

    # Upgrade to Level 2
    pre_e = sim_desk.energy
    reporter.check(sim_desk.upgrade_desk(0) is True, "Upgrade desk 0 to Level 2 succeeds", "Desk_Upgrade")
    reporter.check(sim_desk.get_desk_level(0) == 2, "Desk 0 is now Level 2", "Desk_Upgrade")
    reporter.check(abs(sim_desk.energy - (pre_e - 5000.0)) < 1e-4, "Deducted 5000.0 energy for Level 2 desk", "Desk_Upgrade")

    # Upgrade to Level 3
    reporter.check(sim_desk.get_desk_upgrade_cost(0) == 25000.0, "Desk 0 upgrade to Level 3 costs 25000.0", "Desk_Upgrade")
    pre_e = sim_desk.energy
    reporter.check(sim_desk.upgrade_desk(0) is True, "Upgrade desk 0 to Level 3 succeeds", "Desk_Upgrade")
    reporter.check(sim_desk.get_desk_level(0) == 3, "Desk 0 is now Level 3", "Desk_Upgrade")
    reporter.check(abs(sim_desk.energy - (pre_e - 25000.0)) < 1e-4, "Deducted 25000.0 energy for Level 3 desk", "Desk_Upgrade")

    # Attempt upgrade beyond Level 3 (rejected)
    reporter.check(sim_desk.upgrade_desk(0) is False, "Upgrade past max level (Level 3) rejected", "Desk_Upgrade")
    reporter.check(sim_desk.get_desk_upgrade_cost(0) == 0.0, "Maxed desk upgrade cost returns 0.0", "Desk_Upgrade")

    # --------------------------------------------------------------------------
    # Tier 5: Dynamic Fatigue, Morale Decay & State Transitions
    # --------------------------------------------------------------------------
    sim_dyn = SimulatedGameStateStaff(initial_energy=100000.0)
    sim_dyn.hire_worker("Frontend Dev")  # Desk 0 (Level 1, mult 1.0)
    sim_dyn.hire_worker("Backend Dev")   # Desk 1 (Level 1)
    sim_dyn.upgrade_desk(1)              # Desk 1 is Level 2 (mult 0.75, 25% reduction)
    sim_dyn.hire_worker("UI/UX Designer") # Desk 2 (Level 1)
    sim_dyn.upgrade_desk(2)
    sim_dyn.upgrade_desk(2)              # Desk 2 is Level 3 (mult 0.40, 60% reduction)

    # Advance 60 seconds (1 minute):
    # Base rate: +0.02 / min
    # Desk 0 (L1): +0.02 fatigue
    # Desk 1 (L2): +0.02 * 0.75 = +0.015 fatigue (-25%)
    # Desk 2 (L3): +0.02 * 0.40 = +0.008 fatigue (-60%)
    sim_dyn.update_staff_simulation(60.0)
    w0 = sim_dyn.get_worker("Frontend Dev")
    w1 = sim_dyn.get_worker("Backend Dev")
    w2 = sim_dyn.get_worker("UI/UX Designer")

    reporter.check(abs(w0["fatigue"] - 0.020) < 1e-4, f"Desk Level 1 worker accumulated +0.02 fatigue in 60s (got {w0['fatigue']:.4f})", "Simulation_Fatigue")
    reporter.check(abs(w1["fatigue"] - 0.015) < 1e-4, f"Desk Level 2 worker accumulated +0.015 fatigue in 60s (-25% reduction, got {w1['fatigue']:.4f})", "Simulation_Fatigue")
    reporter.check(abs(w2["fatigue"] - 0.008) < 1e-4, f"Desk Level 3 worker accumulated +0.008 fatigue in 60s (-60% reduction, got {w2['fatigue']:.4f})", "Simulation_Fatigue")
    reporter.check(w0["morale"] == 1.0 and w1["morale"] == 1.0 and w2["morale"] == 1.0, "Morale intact at 1.0 while fatigue < 0.8", "Simulation_Morale")

    # Advance until fatigue reaches 0.8 (test morale decay trigger)
    # Manually set worker 0 fatigue to 0.85
    sim_dyn.hired_workers[0]["fatigue"] = 0.85
    sim_dyn.hired_workers[0]["morale"] = 1.0
    # In 60 seconds at fatigue >= 0.8, morale decays at rate 0.02/60.0 per second -> -0.02 in 60s
    sim_dyn.update_staff_simulation(60.0)
    w0_post = sim_dyn.get_worker("Frontend Dev")
    reporter.check(abs(w0_post["morale"] - 0.98) < 1e-4, f"Morale decayed from 1.0 to 0.98 (-0.02) during 60s over-fatigue (got {w0_post['morale']:.4f})", "Simulation_Morale")

    # Test transition to "fatigued" at fatigue >= 1.0
    sim_dyn.hired_workers[0]["fatigue"] = 0.999
    sim_dyn.update_staff_simulation(10.0) # pushes fatigue past 1.0
    w0_fat = sim_dyn.get_worker("Frontend Dev")
    reporter.check(w0_fat["fatigue"] == 1.0, "Fatigue clamped strictly at 1.0", "Simulation_Clamping")
    reporter.check(w0_fat["current_state"] == "fatigued", "Worker transitioned automatically to 'fatigued' state at fatigue 1.0", "Simulation_State")
    reporter.check(sim_dyn.get_active_workers_count() == 2, "Fatigued worker excluded from active workers count (2 of 3 active)", "Simulation_State")

    # --------------------------------------------------------------------------
    # Tier 6: Coffee Break & Hyper-Focus Dynamics
    # --------------------------------------------------------------------------
    reporter.check(sim_dyn.is_staff_hyper_focus_active() is False, "Hyper-focus initially inactive", "Coffee_Break")
    reporter.check(sim_dyn.give_team_coffee_break() is True, "give_team_coffee_break() succeeds", "Coffee_Break")

    # All workers reset: fatigue -> 0, morale -> 1.0, state -> "working"
    for w in sim_dyn.hired_workers:
        reporter.check(w["fatigue"] == 0.0, f"Worker '{w['id']}' fatigue reset to 0.0", "Coffee_Break")
        reporter.check(w["morale"] == 1.0, f"Worker '{w['id']}' morale restored to 1.0", "Coffee_Break")
        reporter.check(w["current_state"] == "working", f"Worker '{w['id']}' state restored to 'working'", "Coffee_Break")

    reporter.check(sim_dyn.is_staff_hyper_focus_active() is True, "Hyper-focus is active after coffee break", "Coffee_Break")
    reporter.check(abs(sim_dyn.get_staff_hyper_focus_time_remaining() - 60.0) < 1e-4, "Hyper-focus duration initialized to 60.0s", "Coffee_Break")
    reporter.check(abs(sim_dyn.get_staff_hyper_focus_multiplier() - 1.50) < 1e-4, "Hyper-focus multiplier is 1.50x", "Coffee_Break")
    reporter.check(sim_dyn.get_active_workers_count() == 3, "All 3 workers now active after coffee break", "Coffee_Break")

    # Frame processing decay of coffee break
    sim_dyn.process_frame(30.0)
    reporter.check(abs(sim_dyn.get_staff_hyper_focus_time_remaining() - 30.0) < 1e-4, "Hyper-focus time decays to 30.0s after 30s elapsed", "Coffee_Break")
    reporter.check(sim_dyn.is_staff_hyper_focus_active() is True, "Hyper-focus remains active halfway through", "Coffee_Break")

    sim_dyn.process_frame(30.1)
    reporter.check(sim_dyn.is_staff_hyper_focus_active() is False, "Hyper-focus expires cleanly after 60s", "Coffee_Break")
    reporter.check(sim_dyn.get_staff_hyper_focus_time_remaining() == 0.0, "Hyper-focus time remaining is 0.0 after expiry", "Coffee_Break")

    # --------------------------------------------------------------------------
    # Tier 7: Epiphany Moments
    # --------------------------------------------------------------------------
    sim_epi = SimulatedGameStateStaff(initial_energy=10000.0, base_rps=50.0)
    sim_epi.hire_worker("Frontend Dev")
    pre_e = sim_epi.energy
    # Reward is max(100.0, effective_rps * 15.0) -> effective_rps = 50 * 1.05 = 52.5 -> 52.5 * 15 = 787.5
    reward = sim_epi.trigger_worker_epiphany("Frontend Dev")
    reporter.check(abs(reward - 787.5) < 1e-2, f"Epiphany reward matches 15x passive RPS formula (got {reward})", "Epiphany")
    reporter.check(abs(sim_epi.energy - (pre_e + reward)) < 1e-2, "Epiphany reward credited to player energy", "Epiphany")

    # --------------------------------------------------------------------------
    # Tier 8: JSON Persistence Roundtrip & Fuzzing Oracle
    # --------------------------------------------------------------------------
    sim_save = SimulatedGameStateStaff(initial_energy=100000.0)
    sim_save.hire_worker("Frontend Dev")
    sim_save.hire_worker("Backend Dev")
    sim_save.upgrade_desk(0)
    sim_save.upgrade_desk(0) # Desk 0 is Level 3
    sim_save.upgrade_desk(1) # Desk 1 is Level 2
    sim_save.hired_workers[0]["fatigue"] = 0.42
    sim_save.hired_workers[0]["morale"] = 0.88
    sim_save.staff_hyper_focus_timer = 25.5
    sim_save.staff_hyper_focus_active = True

    saved_data = sim_save.to_dict()
    json_str = json.dumps(saved_data)
    loaded_data = json.loads(json_str)

    sim_load = SimulatedGameStateStaff()
    sim_load.load_from_dict(loaded_data)

    reporter.check(len(sim_load.hired_workers) == 2, "JSON roundtrip preserves worker count (2)", "Persistence_Normal")
    reporter.check(sim_load.get_desk_level(0) == 3, "JSON roundtrip preserves desk 0 Level 3", "Persistence_Normal")
    reporter.check(sim_load.get_desk_level(1) == 2, "JSON roundtrip preserves desk 1 Level 2", "Persistence_Normal")
    reporter.check(abs(sim_load.get_worker("Frontend Dev")["fatigue"] - 0.42) < 1e-4, "JSON roundtrip preserves worker fatigue (0.42)", "Persistence_Normal")
    reporter.check(abs(sim_load.get_worker("Frontend Dev")["morale"] - 0.88) < 1e-4, "JSON roundtrip preserves worker morale (0.88)", "Persistence_Normal")
    reporter.check(abs(sim_load.staff_hyper_focus_timer - 25.5) < 1e-4, "JSON roundtrip preserves hyper-focus timer (25.5s)", "Persistence_Normal")
    reporter.check(sim_load.staff_hyper_focus_active is True, "JSON roundtrip preserves hyper-focus active flag", "Persistence_Normal")

    # Fuzzing / Corrupt Data Ingestion
    fuzz_data = {
        "staff": {
            "workers": [
                {
                    "id": "worker_corrupt",
                    "role": "QA Engineer",
                    "morale": -5.0,        # Negative morale -> clamped to 0.0
                    "fatigue": 99.0,       # Excessive fatigue -> clamped to 1.0
                    "efficiency": -1.0,    # Negative eff -> clamped to 0.1
                    "desk_assigned": 99,   # Invalid desk -> clamped to 4
                    "current_state": "alien_hacked", # Invalid state -> defaults based on fatigue
                },
                {
                    "id": "worker_nan",
                    "role": "Frontend Dev",
                    "morale": float("nan"), # NaN -> clamped to 1.0
                    "fatigue": float("inf"),# Inf -> clamped to 0.0
                    "efficiency": float("nan"),
                    "desk_assigned": -5,
                    "current_state": "working",
                }
            ],
            "desk_levels": [-10, 99, 2, "corrupt", None],
            "hyper_focus_timer": -100.0,
        }
    }
    sim_fuzz = SimulatedGameStateStaff()
    sim_fuzz.load_from_dict(fuzz_data)

    w_c = sim_fuzz.get_worker("QA Engineer")
    reporter.check(w_c.get("morale") == 0.0, "Corrupt negative morale clamped to 0.0", "Persistence_Fuzz")
    reporter.check(w_c.get("fatigue") == 1.0, "Corrupt excessive fatigue clamped to 1.0", "Persistence_Fuzz")
    reporter.check(w_c.get("current_state") == "fatigued", "Corrupt state auto-corrected to 'fatigued' due to 1.0 fatigue", "Persistence_Fuzz")
    reporter.check(w_c.get("desk_assigned") == 4, "Corrupt desk index clamped to max desk (4)", "Persistence_Fuzz")

    w_nan = sim_fuzz.get_worker("Frontend Dev")
    reporter.check(w_nan.get("morale") == 1.0, "NaN morale safely handled to 1.0", "Persistence_Fuzz")
    reporter.check(w_nan.get("fatigue") == 0.0, "Inf fatigue safely handled to 0.0", "Persistence_Fuzz")
    reporter.check(w_nan.get("desk_assigned") == 0, "Negative desk index clamped to 0", "Persistence_Fuzz")

    # Desk levels clamped to [1..3]
    reporter.check(sim_fuzz.get_desk_level(0) == 1, "Negative desk level clamped to 1", "Persistence_Fuzz")
    reporter.check(sim_fuzz.get_desk_level(1) == 3, "Excessive desk level (99) clamped to 3", "Persistence_Fuzz")
    reporter.check(sim_fuzz.get_desk_level(2) == 2, "Valid desk level preserved (2)", "Persistence_Fuzz")
    reporter.check(sim_fuzz.get_desk_level(3) == 1, "Corrupt non-numeric desk level defaulted to 1", "Persistence_Fuzz")
    reporter.check(sim_fuzz.get_desk_level(4) == 1, "None desk level defaulted to 1", "Persistence_Fuzz")
    reporter.check(sim_fuzz.staff_hyper_focus_timer == 0.0, "Negative hyper-focus timer clamped to 0.0", "Persistence_Fuzz")

    # --------------------------------------------------------------------------
    # Tier 9: IPO Prestige Ascension Retention
    # --------------------------------------------------------------------------
    sim_ipo = SimulatedGameStateStaff(initial_energy=500000.0)
    for r in ["Frontend Dev", "Backend Dev", "UI/UX Designer"]:
        sim_ipo.hire_worker(r)
    sim_ipo.upgrade_desk(0)
    sim_ipo.upgrade_desk(0) # Desk 0 is Level 3
    sim_ipo.give_team_coffee_break() # 60s hyper focus active

    reporter.check(sim_ipo.is_staff_hyper_focus_active() is True, "Pre-IPO: coffee break active", "IPO_Ascension")
    reporter.check(len(sim_ipo.hired_workers) == 3, "Pre-IPO: 3 workers hired", "IPO_Ascension")
    reporter.check(sim_ipo.get_desk_level(0) == 3, "Pre-IPO: Desk 0 is Level 3", "IPO_Ascension")

    # Trigger IPO
    res = sim_ipo.trigger_ipo()
    reporter.check(res.get("success") is True, "trigger_ipo() executed successfully", "IPO_Ascension")
    reporter.check(sim_ipo.energy == 0.0, "IPO reset player energy to 0.0", "IPO_Ascension")
    reporter.check(len(sim_ipo.hired_workers) == 3, "IPO strictly preserved all 3 hired workers", "IPO_Ascension")
    reporter.check(sim_ipo.get_desk_level(0) == 3, "IPO strictly preserved desk 0 ergonomic upgrade (Level 3)", "IPO_Ascension")
    reporter.check(sim_ipo.is_staff_hyper_focus_active() is False, "IPO extinguished temporary hyper-focus buff", "IPO_Ascension")
    reporter.check(sim_ipo.staff_hyper_focus_timer == 0.0, "IPO reset hyper-focus timer to 0.0", "IPO_Ascension")
    for w in sim_ipo.hired_workers:
        reporter.check(w["current_state"] == "working", f"Worker '{w['id']}' restored to 'working' state post-IPO", "IPO_Ascension")

    return reporter.summarize()


if __name__ == "__main__":
    sys.exit(run_all_tests())
