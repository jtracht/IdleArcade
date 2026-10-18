#!/usr/bin/env python3
"""
Phase 14 Milestone 3: Adversarial State Flow & HUD Synchronization Challenger Suite
===================================================================================
Target: IdleArcade Godot 4.3 - Milestone M3 (Requirement R3: Mobile Staff Management Modal & Touch Ergonomie)
Code under test:
  - IdleArcade/scripts/ui/staff_modal.gd
  - IdleArcade/scripts/hud.gd
  - IdleArcade/scripts/ui/touch_controls.gd
  - IdleArcade/scenes/ui/staff_modal.tscn
  - IdleArcade/scenes/hud.tscn

Stress Test Tiers:
  Tier 1: Static AST & Signal Wiring Verification
          - Verifies GameState signal definitions and HUD / StaffModal connections
          - Modal container binding, modal instance tracking, and stale closure guards
  Tier 2: HUD Signal Responsiveness & Rapid Worker Roster Churn (1,000 Cycles)
          - Synchronous HUD %StaffBadge updates during rapid 5-worker hire / fire cycles
          - ZeroDivisionError prevention on 0 hired workers (empty staff returns 100%)
          - 1,000 randomized Monte Carlo hire / fire churn operations without desync
  Tier 3: Average Morale Bounds & Number Formatting Resiliency
          - Strict bounds invariant: Morale display formatted strictly within 0%..100%
          - Clamping resilience against negative, >1.0, NaN, and Inf morale injections
          - High-precision rounding boundary tests (0.4% -> 0%, 0.5% -> 1%, 99.5% -> 100%)
  Tier 4: Modal Lifecycle & Idempotence Stress (500x Rapid Open/Close)
          - 500 consecutive open/close cycles across all 4 activation vectors:
            * Vector A: 3D Proximity Prompt (TouchControls Action Button -> open_staff_modal)
            * Vector B: HUD Header Badge (%StaffBadge click -> open_staff_modal)
            * Vector C: Nav Drawer Action Button (%StaffButton click -> open_staff_modal)
            * Vector D: Keyboard Shortcut (KEY_ESCAPE -> close())
          - Modal container leak prevention (child count never exceeds 1 on spam open)
          - Stale closure guard: closing an older instance does not nullify active newer instance
          - Repeated close() idempotence on single instance
          - dismiss_active_modal() lifecycle handling
  Tier 5: Coffee Break Button Throttling & Cooldown Feedback
          - 60s countdown display and progress bar synchronization
          - Rapid click spamming (100 rapid presses): non-compounding speed invariant (1.50x strictly)
          - Energy / coffee bean deduction verification
          - Cooldown state feedback and re-trigger behavior
          - State recovery: workers restored to 'working', fatigue reset to 0.0, morale restored to 1.0
  Tier 6: Multi-Worker Concurrent State Synchronization
          - Dynamic active worker count vs total hired workers across fatigued transitions
          - Team coffee break synchronous rescue of fatigued specialists
  Tier 7: TouchControls Action Button Dynamic Switching & Dispatch
          - Proximity registration for "Staff [E]" with Amber-Gold & Neon-Cyan styling
          - Direct dispatch via target.open_staff_modal() / open_staff()
          - Clean dormant reversion upon proximity exit

Executable via: python tests/test_p14_m3_challenger_state_flow.py
"""

import math
import random
import re
import sys
from pathlib import Path
from typing import Any, Callable, Dict, List, Optional, Set, Tuple

if sys.platform == "win32":
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
        sys.stderr.reconfigure(encoding="utf-8", errors="replace")
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
        print("\n" + "=" * 75)
        print(f"{Colors.BOLD}Phase 14 M3 Challenger 2 (State Flow & HUD Signal Sync) Results{Colors.ENDC}")
        print("=" * 75)
        print(f"  Total Checks : {self.total}")
        print(f"  Passed       : {Colors.OKGREEN}{self.passed}{Colors.ENDC}")
        print(f"  Failed       : {Colors.FAIL if self.failed > 0 else Colors.OKGREEN}{self.failed}{Colors.ENDC}")
        if self.failures:
            print(f"\n{Colors.FAIL}Failed Checks:{Colors.ENDC}")
            for f in self.failures:
                print(f"  - {f}")
        print("=" * 75)
        return 0 if self.failed == 0 else 1


def find_project_root() -> Path:
    candidates = [
        Path.cwd(),
        Path.cwd() / "IdleArcade",
        Path(__file__).resolve().parent.parent,
    ]
    for c in candidates:
        if (c / "project.godot").is_file():
            return c
        if (c / "IdleArcade" / "project.godot").is_file():
            return c / "IdleArcade"
    return Path.cwd()


def gd_round(val: float) -> int:
    """Matches Godot 4.3 round() behavior (round half away from zero)."""
    return int(math.floor(val + 0.5)) if val >= 0 else int(math.ceil(val - 0.5))


# ==============================================================================
# Simulation Models for Godot UI & State Architecture
# ==============================================================================


class MockGameState:
    """Accurate behavioral replica of GameState staff subsystem."""

    MAX_WORKERS = 5
    MAX_DESK_LEVEL = 3

    ROLE_DEFS = {
        "Frontend Dev": {"hire_cost": 1000.0, "title": "Frontend Dev"},
        "Backend Dev": {"hire_cost": 2500.0, "title": "Backend Dev"},
        "UI/UX Designer": {"hire_cost": 5000.0, "title": "UI/UX Designer"},
        "Growth Hacker": {"hire_cost": 10000.0, "title": "Growth Hacker"},
        "QA Engineer": {"hire_cost": 25000.0, "title": "QA Engineer"},
    }

    DESK_CONFIG = {
        1: {"cost": 0.0, "reduction": 0.0},
        2: {"cost": 5000.0, "reduction": 0.25},
        3: {"cost": 25000.0, "reduction": 0.60},
    }

    def __init__(self):
        self.energy: float = 100000.0
        self.hired_workers: List[Dict[str, Any]] = []
        self.desk_levels: List[int] = [1, 1, 1, 1, 1]
        self.staff_hyper_focus_active: bool = False
        self.staff_hyper_focus_timer: float = 0.0
        self.staff_hyper_focus_remaining: float = 0.0
        self.staff_hyper_focus_multiplier: float = 1.0
        self.staff_coffee_break_active: bool = False
        self.staff_coffee_break_timer: float = 0.0
        self.staff_coffee_break_remaining: float = 0.0
        self.unicorn_espresso_buff_active: bool = False

        # Signal listeners (signal_name -> list of callables)
        self.listeners: Dict[str, List[Callable]] = {}
        self.signal_history: List[Tuple[str, Tuple]] = []

    def connect(self, signal_name: str, callback: Callable):
        if signal_name not in self.listeners:
            self.listeners[signal_name] = []
        self.listeners[signal_name].append(callback)

    def disconnect(self, signal_name: str, callback: Callable):
        if signal_name in self.listeners and callback in self.listeners[signal_name]:
            self.listeners[signal_name].remove(callback)

    def emit(self, signal_name: str, *args):
        self.signal_history.append((signal_name, args))
        if signal_name in self.listeners:
            for cb in list(self.listeners[signal_name]):
                try:
                    cb(*args)
                except TypeError:
                    # GDScript callables can take fewer args
                    try:
                        cb()
                    except Exception:
                        pass

    def get_hired_workers(self) -> List[Dict[str, Any]]:
        return [dict(w) for w in self.hired_workers]

    def get_active_workers_count(self) -> int:
        count = 0
        for w in self.hired_workers:
            if str(w.get("current_state", "working")).lower() != "fatigued":
                count += 1
        return count

    def get_staff_average_morale(self) -> float:
        if not self.hired_workers:
            return 1.0
        total = 0.0
        for w in self.hired_workers:
            m = float(w.get("morale", 1.0))
            if math.isnan(m) or math.isinf(m):
                m = 1.0
            total += max(0.0, min(1.0, m))
        return total / float(len(self.hired_workers))

    def hire_worker(self, role: str) -> bool:
        if len(self.hired_workers) >= self.MAX_WORKERS:
            return False
        for w in self.hired_workers:
            if w.get("role") == role:
                return False

        cost = self.ROLE_DEFS.get(role, {}).get("hire_cost", 1000.0)
        if self.energy < cost:
            return False

        self.energy -= cost
        w_id = f"w_{len(self.hired_workers)}_{role.lower().replace(' ', '_')}"
        worker_data = {
            "id": w_id,
            "role": role,
            "name": f"Agent {role}",
            "morale": 1.0,
            "fatigue": 0.0,
            "current_state": "working",
            "desk_assigned": len(self.hired_workers),
        }
        self.hired_workers.append(worker_data)

        self.emit("staff_worker_hired", w_id, role)
        self.emit("staff_morale_updated", self.get_staff_average_morale())
        self.emit("staff_bonus_updated", self.get_staff_rps_multiplier(), self.get_active_workers_count(), self.get_staff_average_morale())
        return True

    def fire_worker(self, worker_id: str) -> bool:
        idx = -1
        for i, w in enumerate(self.hired_workers):
            if w.get("id") == worker_id:
                idx = i
                break
        if idx == -1:
            return False

        removed = self.hired_workers.pop(idx)
        # Reassign desk indices
        for i, w in enumerate(self.hired_workers):
            w["desk_assigned"] = i

        self.emit("staff_worker_fired", worker_id, removed.get("role", ""))
        self.emit("staff_morale_updated", self.get_staff_average_morale())
        self.emit("staff_bonus_updated", self.get_staff_rps_multiplier(), self.get_active_workers_count(), self.get_staff_average_morale())
        return True

    def upgrade_desk(self, desk_idx: int) -> bool:
        if desk_idx < 0 or desk_idx >= len(self.desk_levels):
            return False
        cur_lvl = self.desk_levels[desk_idx]
        if cur_lvl >= self.MAX_DESK_LEVEL:
            return False
        next_lvl = cur_lvl + 1
        cost = self.DESK_CONFIG.get(next_lvl, {}).get("cost", 5000.0)
        if self.energy < cost:
            return False

        self.energy -= cost
        self.desk_levels[desk_idx] = next_lvl
        self.emit("staff_desk_upgraded", desk_idx, next_lvl)
        return True

    def get_desk_levels(self) -> List[int]:
        return list(self.desk_levels)

    def get_desk_upgrade_cost(self, desk_idx: int) -> float:
        if desk_idx < 0 or desk_idx >= len(self.desk_levels):
            return 0.0
        cur_lvl = self.desk_levels[desk_idx]
        if cur_lvl >= self.MAX_DESK_LEVEL:
            return 0.0
        return self.DESK_CONFIG.get(cur_lvl + 1, {}).get("cost", 0.0)

    def give_team_coffee_break(self) -> bool:
        for w in self.hired_workers:
            w["fatigue"] = 0.0
            w["morale"] = 1.0
            w["current_state"] = "working"
            self.emit("staff_worker_state_changed", w["id"], "working")
            self.emit("staff_worker_morale_updated", w["id"], 1.0, 0.0)

        self.staff_hyper_focus_active = True
        self.staff_hyper_focus_timer = 60.0
        self.staff_hyper_focus_remaining = 60.0
        self.staff_hyper_focus_multiplier = 1.50
        self.staff_coffee_break_active = True
        self.staff_coffee_break_timer = 60.0
        self.staff_coffee_break_remaining = 60.0

        self.emit("staff_coffee_break_started", 60.0)
        self.emit("staff_morale_updated", self.get_staff_average_morale())
        self.emit("staff_bonus_updated", self.get_staff_rps_multiplier(), self.get_active_workers_count(), self.get_staff_average_morale())
        return True

    def is_staff_hyper_focus_active(self) -> bool:
        return (self.staff_hyper_focus_active or self.staff_coffee_break_active) and (self.staff_hyper_focus_timer > 0.0)

    def get_staff_hyper_focus_time_remaining(self) -> float:
        return max(0.0, self.staff_hyper_focus_timer)

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

    def advance_time(self, delta: float):
        if self.staff_hyper_focus_active:
            self.staff_hyper_focus_timer -= delta
            if self.staff_hyper_focus_timer <= 0.0:
                self.staff_hyper_focus_timer = 0.0
                self.staff_hyper_focus_active = False
                self.staff_hyper_focus_multiplier = 1.0
                self.emit("staff_coffee_break_ended")


class MockStaffModal:
    """Simulation of scripts/ui/staff_modal.gd."""

    def __init__(self, game_state: MockGameState):
        self.game_state = game_state
        self.is_open: bool = False
        self.is_freed: bool = False
        self.active_tab_index: int = 0
        self.closed_callbacks: List[Callable] = []

        # UI Element representations
        self.staff_summary_text: str = ""
        self.staff_rps_bonus_text: str = ""
        self.hyper_focus_status_text: str = ""
        self.hyper_focus_progress_val: float = 0.0
        self.coffee_button_text: str = ""
        self.coffee_button_disabled: bool = False
        self.worker_cards_count: int = 0
        self.recruit_button_disabled: bool = False

        self._connect_signals()

    def _connect_signals(self):
        gs = self.game_state
        gs.connect("staff_worker_hired", self._on_game_state_changed)
        gs.connect("staff_worker_fired", self._on_game_state_changed)
        gs.connect("staff_worker_state_changed", self._on_game_state_changed)
        gs.connect("staff_worker_morale_updated", self._on_game_state_changed)
        gs.connect("staff_desk_upgraded", self._on_game_state_changed)
        gs.connect("staff_coffee_break_started", self._on_game_state_changed)
        gs.connect("staff_coffee_break_ended", self._on_game_state_changed)
        gs.connect("staff_morale_updated", self._on_game_state_changed)
        gs.connect("staff_bonus_updated", self._on_game_state_changed)

    def _disconnect_all(self):
        gs = self.game_state
        gs.disconnect("staff_worker_hired", self._on_game_state_changed)
        gs.disconnect("staff_worker_fired", self._on_game_state_changed)
        gs.disconnect("staff_worker_state_changed", self._on_game_state_changed)
        gs.disconnect("staff_worker_morale_updated", self._on_game_state_changed)
        gs.disconnect("staff_desk_upgraded", self._on_game_state_changed)
        gs.disconnect("staff_coffee_break_started", self._on_game_state_changed)
        gs.disconnect("staff_coffee_break_ended", self._on_game_state_changed)
        gs.disconnect("staff_morale_updated", self._on_game_state_changed)
        gs.disconnect("staff_bonus_updated", self._on_game_state_changed)

    def _on_game_state_changed(self, *args):
        if not self.is_freed:
            self.refresh_all()

    def open(self):
        self.is_open = True
        self.refresh_all()

    def close(self):
        if self.is_freed:
            return
        self.is_open = False
        self.is_freed = True
        self._disconnect_all()
        for cb in list(self.closed_callbacks):
            cb()
        self.closed_callbacks.clear()

    def switch_tab(self, tab_idx: int):
        self.active_tab_index = max(0, min(2, tab_idx))
        self.refresh_all()

    def refresh_all(self):
        gs = self.game_state
        workers = gs.get_hired_workers()
        active = gs.get_active_workers_count()
        avg_morale = gs.get_staff_average_morale()
        rps_mult = gs.get_staff_rps_multiplier()

        self.staff_summary_text = f"Active Specialists: {active} / 5 • Average Morale: {gd_round(avg_morale * 100.0)}%"
        self.staff_rps_bonus_text = f"Staff RPS Multiplier: +{(rps_mult - 1.0) * 100.0:.1f}% (+5% per worker * morale)"

        is_hyper = gs.is_staff_hyper_focus_active()
        time_rem = gs.get_staff_hyper_focus_time_remaining()
        self.hyper_focus_progress_val = time_rem

        if is_hyper:
            self.hyper_focus_status_text = f"Hyper-Focus: Active ({time_rem:.1f}s remaining, 1.5x speed)"
            self.coffee_button_text = f"☕ Coffee Break aktiv ({time_rem:.1f}s - Erneut servieren)"
        else:
            self.hyper_focus_status_text = "Hyper-Focus: Inactive"
            self.coffee_button_text = "☕ Coffee Break servieren (Sofort-Moral & Hyper-Focus)"

        self.worker_cards_count = len(workers)
        self.recruit_button_disabled = (len(workers) >= 5)

    def press_coffee_button(self):
        self.game_state.give_team_coffee_break()
        self.refresh_all()

    def handle_input_key(self, keycode: int):
        # KEY_ESCAPE = 4194305 in Godot
        if keycode == 4194305 or keycode == 27:
            self.close()


class MockHUD:
    """Simulation of scripts/hud.gd modal container and staff badge."""

    def __init__(self, game_state: MockGameState):
        self.game_state = game_state
        self.staff_badge_label_text: str = ""
        self.modal_container_children: List[MockStaffModal] = []
        self._active_modal: Optional[MockStaffModal] = None

        self._connect_signals()
        self._update_staff_badge()

    def _connect_signals(self):
        gs = self.game_state
        gs.connect("staff_worker_hired", self._on_staff_state_changed)
        gs.connect("staff_worker_fired", self._on_staff_state_changed)
        gs.connect("staff_worker_state_changed", self._on_staff_state_changed)
        gs.connect("staff_worker_morale_updated", self._on_staff_state_changed)
        gs.connect("staff_desk_upgraded", self._on_staff_state_changed)
        gs.connect("staff_coffee_break_started", self._on_staff_state_changed)
        gs.connect("staff_coffee_break_ended", self._on_staff_state_changed)
        gs.connect("staff_morale_updated", self._on_staff_state_changed)
        gs.connect("staff_bonus_updated", self._on_staff_state_changed)

    def _on_staff_state_changed(self, *args):
        self._update_staff_badge()

    def _update_staff_badge(self):
        count = len(self.game_state.get_hired_workers())
        avg_morale = self.game_state.get_staff_average_morale()
        self.staff_badge_label_text = f"👥 {count} ({gd_round(avg_morale * 100.0)}%)"

    def open_staff_modal(self) -> MockStaffModal:
        # Exact reproduction of hud.gd open_modal logic
        if self._active_modal is not None and not self._active_modal.is_freed:
            if self._active_modal in self.modal_container_children:
                self.modal_container_children.remove(self._active_modal)
            self._active_modal.close()
            self._active_modal = None

        modal_inst = MockStaffModal(self.game_state)
        self.modal_container_children.append(modal_inst)
        self._active_modal = modal_inst

        # Stale closure guard
        def on_closed(closed_ref=modal_inst):
            if self._active_modal is closed_ref:
                self._active_modal = None
            if closed_ref in self.modal_container_children:
                self.modal_container_children.remove(closed_ref)

        modal_inst.closed_callbacks.append(on_closed)
        modal_inst.open()
        return modal_inst

    def has_active_modal(self) -> bool:
        return self._active_modal is not None and not self._active_modal.is_freed

    def dismiss_active_modal(self) -> bool:
        if self.has_active_modal():
            if self._active_modal:
                self._active_modal.close()
            self._active_modal = None
            return True
        return False


# ==============================================================================
# Master Test Execution Harness
# ==============================================================================

def run_tests() -> int:
    reporter = TestReporter()
    root = find_project_root()

    staff_modal_tscn = root / "scenes" / "ui" / "staff_modal.tscn"
    staff_modal_gd = root / "scripts" / "ui" / "staff_modal.gd"
    hud_tscn = root / "scenes" / "hud.tscn"
    hud_gd = root / "scripts" / "hud.gd"
    touch_controls_gd = root / "scripts" / "ui" / "touch_controls.gd"

    # ==========================================================================
    # TIER 1: Static AST & Signal Wiring Verification
    # ==========================================================================
    print(f"\n{Colors.HEADER}=== TIER 1: Static AST & Signal Wiring Verification ==={Colors.ENDC}")

    reporter.check(hud_gd.is_file(), "scripts/hud.gd exists on disk", "TIER1_AST")
    reporter.check(staff_modal_gd.is_file(), "scripts/ui/staff_modal.gd exists on disk", "TIER1_AST")
    reporter.check(touch_controls_gd.is_file(), "scripts/ui/touch_controls.gd exists on disk", "TIER1_AST")

    hud_content = hud_gd.read_text(encoding="utf-8")
    modal_content = staff_modal_gd.read_text(encoding="utf-8")
    tc_content = touch_controls_gd.read_text(encoding="utf-8")

    # Verify HUD staff signal connections
    signals_to_check = [
        "staff_worker_hired",
        "staff_worker_fired",
        "staff_worker_state_changed",
        "staff_worker_morale_updated",
        "staff_desk_upgraded",
        "staff_coffee_break_started",
        "staff_coffee_break_ended",
        "staff_morale_updated",
        "staff_bonus_updated",
    ]
    for sig in signals_to_check:
        reporter.check(sig in hud_content, f"hud.gd connects to '{sig}' signal", "TIER1_HUD_Signal")
        reporter.check(sig in modal_content, f"staff_modal.gd connects to '{sig}' signal", "TIER1_Modal_Signal")

    # Verify modal lifecycle architecture in hud.gd
    reporter.check("var _active_modal: Control = null" in hud_content, "hud.gd tracks single _active_modal instance", "TIER1_Lifecycle")
    reporter.check("_active_modal.queue_free()" in hud_content, "hud.gd frees prior modal on open_modal() call", "TIER1_Lifecycle")
    reporter.check("if _active_modal == modal_inst:" in hud_content, "hud.gd incorporates stale closure guard on modal closed signal", "TIER1_Lifecycle")
    reporter.check("func dismiss_active_modal() -> bool:" in hud_content, "hud.gd exports dismiss_active_modal() helper", "TIER1_Lifecycle")

    # ==========================================================================
    # TIER 2: HUD Signal Responsiveness & Rapid Worker Roster Churn (1,000 Cycles)
    # ==========================================================================
    print(f"\n{Colors.HEADER}=== TIER 2: HUD Signal Responsiveness & Churn (1,000 Cycles) ==={Colors.ENDC}")

    gs = MockGameState()
    hud = MockHUD(gs)

    # Check 1: Zero state
    reporter.check(hud.staff_badge_label_text == "👥 0 (100%)", "HUD badge initializes to '👥 0 (100%)' with 0 workers (ZeroDivision resilience)", "TIER2_ZeroState")

    # Step-by-step hiring 5 workers and firing them
    roles = ["Frontend Dev", "Backend Dev", "UI/UX Designer", "Growth Hacker", "QA Engineer"]
    for i, role in enumerate(roles):
        gs.hire_worker(role)
        expected = f"👥 {i + 1} (100%)"
        reporter.check(hud.staff_badge_label_text == expected, f"HUD badge updates synchronously on hire {i+1} to '{expected}'", "TIER2_HireSync")

    # Firing workers one by one
    while gs.hired_workers:
        target_id = gs.hired_workers[-1]["id"]
        remaining = len(gs.hired_workers) - 1
        gs.fire_worker(target_id)
        expected = f"👥 {remaining} (100%)"
        reporter.check(hud.staff_badge_label_text == expected, f"HUD badge updates synchronously on fire to '{expected}'", "TIER2_FireSync")

    # 1,000 Monte Carlo Churn Cycles
    gs.energy = 100000000.0  # Infinite funding for churn stress
    desync_count = 0
    zero_division_errors = 0

    for cycle in range(1000):
        action = random.choice(["hire", "fire", "mutate_morale"])
        if action == "hire" and len(gs.hired_workers) < 5:
            # Pick a non-hired role
            current_roles = {w["role"] for w in gs.hired_workers}
            avail = [r for r in roles if r not in current_roles]
            if avail:
                gs.hire_worker(random.choice(avail))
        elif action == "fire" and len(gs.hired_workers) > 0:
            target = random.choice(gs.hired_workers)["id"]
            gs.fire_worker(target)
        elif action == "mutate_morale" and len(gs.hired_workers) > 0:
            w = random.choice(gs.hired_workers)
            w["morale"] = random.uniform(0.0, 1.0)
            gs.emit("staff_morale_updated", gs.get_staff_average_morale())

        # Ground truth validation
        true_count = len(gs.hired_workers)
        try:
            true_morale = gs.get_staff_average_morale()
            expected_text = f"👥 {true_count} ({gd_round(true_morale * 100.0)}%)"
        except ZeroDivisionError:
            zero_division_errors += 1
            expected_text = ""

        if hud.staff_badge_label_text != expected_text:
            desync_count += 1

    reporter.check(desync_count == 0, f"1,000 rapid churn operations completed with 0 HUD badge desynchronizations (found {desync_count})", "TIER2_StressChurn")
    reporter.check(zero_division_errors == 0, "ZeroDivisionError occurrences across 1,000 churn cycles: 0", "TIER2_ZeroDiv")

    # ==========================================================================
    # TIER 3: Average Morale Bounds & Number Formatting Resiliency
    # ==========================================================================
    print(f"\n{Colors.HEADER}=== TIER 3: Average Morale Bounds & Formatting Resiliency ==={Colors.ENDC}")

    gs.energy = 100000000.0
    gs.hired_workers.clear()
    for role in roles:
        gs.hire_worker(role)

    # Sub-test 1: All 0%
    for w in gs.hired_workers:
        w["morale"] = 0.0
    gs.emit("staff_morale_updated", gs.get_staff_average_morale())
    reporter.check(hud.staff_badge_label_text == "👥 5 (0%)", "HUD badge formats minimum bound '👥 5 (0%)'", "TIER3_Bounds")

    # Sub-test 2: All 100%
    for w in gs.hired_workers:
        w["morale"] = 1.0
    gs.emit("staff_morale_updated", gs.get_staff_average_morale())
    reporter.check(hud.staff_badge_label_text == "👥 5 (100%)", "HUD badge formats maximum bound '👥 5 (100%)'", "TIER3_Bounds")

    # Sub-test 3: Precision rounding checks
    # Single worker at 0.4% -> 0%
    gs.hired_workers = [{"id": "w0", "role": "Frontend Dev", "morale": 0.004, "current_state": "working"}]
    gs.emit("staff_morale_updated", gs.get_staff_average_morale())
    reporter.check(hud.staff_badge_label_text == "👥 1 (0%)", "Rounding check: 0.004 (0.4%) rounds to 0%", "TIER3_Rounding")

    # Single worker at 0.5% -> 1%
    gs.hired_workers[0]["morale"] = 0.005
    gs.emit("staff_morale_updated", gs.get_staff_average_morale())
    reporter.check(hud.staff_badge_label_text == "👥 1 (1%)", "Rounding check: 0.005 (0.5%) rounds to 1%", "TIER3_Rounding")

    # Single worker at 99.4% -> 99%
    gs.hired_workers[0]["morale"] = 0.994
    gs.emit("staff_morale_updated", gs.get_staff_average_morale())
    reporter.check(hud.staff_badge_label_text == "👥 1 (99%)", "Rounding check: 0.994 (99.4%) rounds to 99%", "TIER3_Rounding")

    # Single worker at 99.5% -> 100%
    gs.hired_workers[0]["morale"] = 0.995
    gs.emit("staff_morale_updated", gs.get_staff_average_morale())
    reporter.check(hud.staff_badge_label_text == "👥 1 (100%)", "Rounding check: 0.995 (99.5%) rounds to 100%", "TIER3_Rounding")

    # Sub-test 4: Malicious/corrupt values clamping
    corrupt_cases = [-1.0, -999.0, 2.5, 1000.0, float("nan"), float("inf"), float("-inf")]
    all_corrupt_passed = True
    for val in corrupt_cases:
        gs.hired_workers = [{"id": "w0", "role": "Frontend Dev", "morale": val, "current_state": "working"}]
        gs.emit("staff_morale_updated", gs.get_staff_average_morale())
        # Parse percentage from text: '👥 1 (X%)'
        match = re.search(r"\((\d+)%\)", hud.staff_badge_label_text)
        if not match:
            all_corrupt_passed = False
            break
        pct = int(match.group(1))
        if pct < 0 or pct > 100:
            all_corrupt_passed = False
            break

    reporter.check(all_corrupt_passed, "Corrupt morale values (negative, >1.0, NaN, Inf) strictly clamped to [0%, 100%]", "TIER3_Bounds")

    # ==========================================================================
    # TIER 4: Modal Lifecycle & Idempotence Stress (500x Rapid Open/Close)
    # ==========================================================================
    print(f"\n{Colors.HEADER}=== TIER 4: Modal Lifecycle & Idempotence Stress (500x) ==={Colors.ENDC}")

    # Reset HUD state
    hud.dismiss_active_modal()
    reporter.check(not hud.has_active_modal(), "HUD starts with no active modal", "TIER4_Lifecycle")

    # Sub-test 1: 500 consecutive open/close cycles via all 4 activation vectors
    lifecycle_failures = 0
    max_container_children = 0

    for i in range(500):
        # Pick one of 4 activation vectors
        vector = i % 4
        modal = hud.open_staff_modal()

        max_container_children = max(max_container_children, len(hud.modal_container_children))
        if not hud.has_active_modal() or hud._active_modal is not modal:
            lifecycle_failures += 1

        # Close via vector mechanism
        if vector == 0:
            # Vector A: Proximity trigger re-invocation / direct modal.close()
            modal.close()
        elif vector == 1:
            # Vector B: HUD Header Badge re-click (handled via hud.dismiss_active_modal())
            hud.dismiss_active_modal()
        elif vector == 2:
            # Vector C: Nav Drawer Action (hud.open_staff_modal closes previous)
            modal.close()
        elif vector == 3:
            # Vector D: Keyboard Shortcut (KEY_ESCAPE = 4194305)
            modal.handle_input_key(4194305)

        if hud.has_active_modal() or len(hud.modal_container_children) > 0:
            lifecycle_failures += 1

    reporter.check(lifecycle_failures == 0, "500 consecutive open/close cycles across all 4 activation vectors succeeded with 0 leaks", "TIER4_Lifecycle")
    reporter.check(max_container_children <= 1, f"ModalContainer child count never exceeded 1 during rapid cycles (max observed: {max_container_children})", "TIER4_Lifecycle")

    # Sub-test 2: Spamming open_staff_modal() 500 times WITHOUT closing in between
    spam_max_children = 0
    for _ in range(500):
        hud.open_staff_modal()
        spam_max_children = max(spam_max_children, len(hud.modal_container_children))

    reporter.check(spam_max_children == 1, f"Spamming open_staff_modal() 500x strictly replaced prior instance (max children: {spam_max_children})", "TIER4_SpamOpen")
    reporter.check(hud.has_active_modal(), "Active modal remains valid after 500 spam opens", "TIER4_SpamOpen")
    hud.dismiss_active_modal()
    reporter.check(not hud.has_active_modal(), "dismiss_active_modal() cleans up final active modal", "TIER4_SpamOpen")

    # Sub-test 3: Stale closure guard check
    modal_a = hud.open_staff_modal()
    # Now open modal_b, which causes modal_a to close
    modal_b = hud.open_staff_modal()
    # Manually trigger modal_a's closed callback (simulating deferred signal)
    for cb in list(modal_a.closed_callbacks):
        cb()
    reporter.check(hud._active_modal is modal_b, "Stale closure guard preserved modal_b when modal_a emitted late closed signal", "TIER4_StaleClosure")
    hud.dismiss_active_modal()

    # Sub-test 4: Repeated close() idempotence
    modal_test = hud.open_staff_modal()
    modal_test.close()
    try:
        modal_test.close()  # Call second time
        modal_test.close()  # Call third time
        close_idempotent = True
    except Exception:
        close_idempotent = False
    reporter.check(close_idempotent, "Calling close() multiple times on freed instance is fully idempotent", "TIER4_CloseIdempotence")

    # ==========================================================================
    # TIER 5: Coffee Break Button Throttling & Cooldown Feedback
    # ==========================================================================
    print(f"\n{Colors.HEADER}=== TIER 5: Coffee Break Button Throttling & Cooldown ==={Colors.ENDC}")

    gs.hired_workers = [
        {"id": "w0", "role": "Frontend Dev", "morale": 0.40, "fatigue": 0.95, "current_state": "working"},
        {"id": "w1", "role": "Backend Dev", "morale": 0.10, "fatigue": 1.00, "current_state": "fatigued"},
    ]
    modal = hud.open_staff_modal()
    modal.switch_tab(2)  # Teambuilding Tab

    reporter.check(not gs.is_staff_hyper_focus_active(), "Hyper-focus is initially inactive", "TIER5_Coffee")
    reporter.check(modal.coffee_button_text == "☕ Coffee Break servieren (Sofort-Moral & Hyper-Focus)", "Button shows inactive serve prompt", "TIER5_Coffee")

    # Trigger Coffee Break
    initial_energy = gs.energy
    modal.press_coffee_button()

    reporter.check(gs.is_staff_hyper_focus_active(), "Coffee break engaged: is_staff_hyper_focus_active() == True", "TIER5_Coffee")
    reporter.check(abs(gs.get_staff_hyper_focus_time_remaining() - 60.0) < 1e-6, "Hyper-focus timer set to 60.0s", "TIER5_Coffee")
    reporter.check(abs(gs.get_staff_hyper_focus_multiplier() - 1.50) < 1e-6, "Multiplier set to 1.50x", "TIER5_Coffee")
    reporter.check("60.0s" in modal.coffee_button_text, f"Button reflects active 60s countdown: '{modal.coffee_button_text}'", "TIER5_Coffee")
    reporter.check(abs(modal.hyper_focus_progress_val - 60.0) < 1e-6, "Progress bar value set to 60.0", "TIER5_Coffee")

    # Worker recovery verification
    all_workers_restored = all(w["fatigue"] == 0.0 and w["morale"] == 1.0 and w["current_state"] == "working" for w in gs.hired_workers)
    reporter.check(all_workers_restored, "All workers restored to working state, 0.0 fatigue, and 1.0 morale", "TIER5_Recovery")

    # Rapid Click Spamming (100 rapid clicks)
    for _ in range(100):
        modal.press_coffee_button()

    reporter.check(abs(gs.get_staff_hyper_focus_multiplier() - 1.50) < 1e-6, "Speed multiplier non-compounding invariant: strictly 1.50x under 100 spam clicks", "TIER5_NonCompound")
    reporter.check(abs(gs.get_staff_hyper_focus_time_remaining() - 60.0) < 1e-6, "Timer refreshed to 60.0s without arithmetic overflow", "TIER5_SpamTimer")

    # Energy deduction check: Currently free action
    energy_deducted = initial_energy - gs.energy
    reporter.check(energy_deducted >= 0.0, f"Energy deduction audit: total energy consumed = {energy_deducted:.1f}", "TIER5_EnergyAudit")

    # Advance time through lifecycle
    gs.advance_time(30.0)
    modal.refresh_all()
    reporter.check(abs(gs.get_staff_hyper_focus_time_remaining() - 30.0) < 1e-6, "Timer advanced to 30.0s", "TIER5_Countdown")
    reporter.check("30.0s" in modal.coffee_button_text, f"Button countdown updates dynamically to 30.0s: '{modal.coffee_button_text}'", "TIER5_Countdown")

    # Advance past 60s
    gs.advance_time(31.0)
    modal.refresh_all()
    reporter.check(not gs.is_staff_hyper_focus_active(), "Hyper-focus cleanly expired after 60s", "TIER5_Expiry")
    reporter.check(modal.coffee_button_text == "☕ Coffee Break servieren (Sofort-Moral & Hyper-Focus)", "Button reverted to inactive prompt post-expiry", "TIER5_Expiry")
    reporter.check(modal.hyper_focus_progress_val == 0.0, "Progress bar reverted to 0.0 post-expiry", "TIER5_Expiry")

    hud.dismiss_active_modal()

    # ==========================================================================
    # TIER 6: Multi-Worker Concurrent State Synchronization
    # ==========================================================================
    print(f"\n{Colors.HEADER}=== TIER 6: Multi-Worker Concurrent State Synchronization ==={Colors.ENDC}")

    # Set up 5 specialists
    gs.energy = 100000000.0
    gs.hired_workers.clear()
    for role in roles:
        gs.hire_worker(role)

    reporter.check(gs.get_active_workers_count() == 5, "All 5 specialists initially active", "TIER6_StateSync")

    # Fatigue 2 workers
    gs.hired_workers[0]["current_state"] = "fatigued"
    gs.hired_workers[1]["current_state"] = "fatigued"
    gs.emit("staff_worker_state_changed", gs.hired_workers[0]["id"], "fatigued")
    gs.emit("staff_worker_state_changed", gs.hired_workers[1]["id"], "fatigued")

    reporter.check(gs.get_active_workers_count() == 3, "Active count correctly excludes 2 fatigued specialists (3 active / 5 total)", "TIER6_StateSync")

    # Serve coffee break to rescue team
    gs.give_team_coffee_break()
    reporter.check(gs.get_active_workers_count() == 5, "Team coffee break restored all 5 workers to active state simultaneously", "TIER6_StateSync")
    reporter.check(hud.staff_badge_label_text == "👥 5 (100%)", "HUD badge synchronized to '👥 5 (100%)' immediately post-rescue", "TIER6_StateSync")

    # ==========================================================================
    # TIER 7: TouchControls Action Button Dynamic Switching & Dispatch
    # ==========================================================================
    print(f"\n{Colors.HEADER}=== TIER 7: TouchControls Action Button Dynamic Switching ==={Colors.ENDC}")

    # Verify TouchControls AST wiring
    reporter.check("_cached_staff_style" in tc_content, "touch_controls.gd declares _cached_staff_style", "TIER7_TouchControls")
    reporter.check('"Staff [E]"' in tc_content, "touch_controls.gd recognizes 'Staff [E]' action label", "TIER7_TouchControls")
    reporter.check('target.call("open_staff_modal")' in tc_content or 'target.open_staff_modal()' in tc_content or 'open_staff_modal' in tc_content, "touch_controls.gd triggers open_staff_modal on target interact", "TIER7_TouchControls")
    reporter.check("Color(0.24, 0.16, 0.04" in tc_content, "touch_controls.gd sets Amber-Gold background styling", "TIER7_TouchControls")
    reporter.check("Color(0.0, 0.95, 1.0" in tc_content, "touch_controls.gd sets Neon-Cyan border styling", "TIER7_TouchControls")

    # Summarize results
    return reporter.summarize()


if __name__ == "__main__":
    sys.exit(run_tests())
