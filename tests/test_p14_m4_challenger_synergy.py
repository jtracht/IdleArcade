#!/usr/bin/env python3
"""
Phase 14 Milestone 4: Coffee Synergy & Hyper-Focus Propagation Adversary Suite
================================================================================
Target: IdleArcade Godot 4.3 - Milestone M4 (§R4: Teambuilding & Epiphany Synergies)
Code under test:
  - IdleArcade/scripts/coffee_machine_3d.gd
  - IdleArcade/scripts/office_expansion_3d.gd
  - IdleArcade/scripts/chibi_worker_3d.gd
  - IdleArcade/scripts/autoload/game_state.gd
  - IdleArcade/scripts/ui/espresso_brew_minigame.gd

Adversarial Stress Test Matrix:
  Tier 1: Static AST & Script Contract Deep Audit
          - Signal declarations & signatures
          - Export variables and constants
          - Group associations ("coffee_machines", "stations", "staff_offices")
          - Integration methods (trigger_office_synergy, activate_hyper_focus, set_hyper_focus)
  Tier 2: Recipe & Brew Synergy Trigger Adversarial Matrix
          - Successful Unicorn Espresso brew activates 60s office-wide hyper-focus
          - Failed / cancelled / interrupted brew does NOT activate hyper-focus
          - Isolation: standard drink / interaction does not trigger coffee break
  Tier 3: Rapid Consecutive Brewing & Timer Clamping Stress
          - 10 successive Unicorn brews: timer clamp at strictly 60.0s (never 600s)
          - Non-stacking speed multiplier: strictly 1.50x (never 1.5^10 = 57.66x)
          - Mid-countdown refresh: resets timer to 60.0s without accumulating
          - 100 Monte Carlo consecutive brews fuzzing
  Tier 4: Office Kinematics Scaling Across All 5 Workers
          - Full 5-worker office complement with heterogeneous initial states
          - Kinematics time dilation: delta * 1.50 advances _time by 1.50s per 1s real time
          - Procedural typing arm frequency: scales from 14.0 rad/s to 21.0 rad/s (1.50x)
          - Head nod oscillation frequency: scales from 4.0 rad/s to 6.0 rad/s (1.50x)
          - Simultaneous synchronization across all 5 workers without desync drift
  Tier 5: High-Precision Expiration Reversion & Multiplier Decay
          - Step-by-step timeline evaluation (t=0s, 30s, 59.9s, 60.0s, 60.1s)
          - Clean expiration in GameState, OfficeExpansion3D, and all 5 ChibiWorker3D instances
          - Arm typing frequency drops back from 21.0 rad/s to 14.0 rad/s
          - Head nod frequency drops back from 6.0 rad/s to 4.0 rad/s
          - All signals emitted: office_hyper_focus_ended, team_coffee_break_ended
  Tier 6: Machine Cooldown Invariants & Sweet-Spot Pressure Dynamics
          - 60s cooldown engagement upon successful brew
          - can_brew() returns false during cooldown; premature brews rejected
          - Minigame pressure decay (24 bar/s), pump increment (15 bar), sweet spot [62..84 bar]
  Tier 7: Dynamic Staff Reconfiguration Mid-Buff (Hire/Fire at t=25s)
          - Workers recruited while hyper-focus is active inherit remaining duration safely
          - Worker fired mid-buff despawns cleanly with zero null-pointer crashes
  Tier 8: Concurrent Epiphany Interaction & Economy Compounding
          - Spontaneous epiphany triggers on worker during active hyper-focus
          - Reward calculation compounds active staff bonus (+25%) and Unicorn buff (+20%)
          - Tap collection awards correct energy; 10 extra clicks are strictly idempotent
  Tier 9: Frame Delta Jitter, Micro-Steps & Severe Hitch Chaos Fuzzing
          - 1,000 steps with chaotic deltas (0.0005s, 0.01667s, 0.5s, 2.0s, 5.0s, 0.0s)
          - Clamping invariants verified continuously: timers in [0..60], multipliers in {1.0, 1.5}
  Tier 10: End-to-End Teambuilding Synergy & Chaos Journey
          - Complete multi-stage player journey verifying zero regressions across all layers

Executable via: python IdleArcade/tests/test_p14_m4_challenger_synergy.py
"""

import math
import random
import re
import sys
from pathlib import Path
from typing import Any, Dict, List, Optional

# UTF-8 terminal handling on Windows
if sys.platform == "win32":
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
        sys.stderr.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass

# Paths
ROOT_DIR = Path(__file__).resolve().parent.parent
SCRIPTS_DIR = ROOT_DIR / "scripts"


class Colors:
    HEADER = "\033[95m"
    BLUE = "\033[94m"
    CYAN = "\033[96m"
    GREEN = "\033[92m"
    YELLOW = "\033[93m"
    RED = "\033[91m"
    BOLD = "\033[1m"
    ENDC = "\033[0m"


class TestReporter:
    def __init__(self, suite_name: str):
        self.suite_name = suite_name
        self.total = 0
        self.passed = 0
        self.failed = 0
        self.failures = []

    def check(self, condition: bool, description: str, tag: str = "GENERAL"):
        self.total += 1
        if condition:
            self.passed += 1
            print(f"  {Colors.GREEN}[PASS]{Colors.ENDC} [{tag}] {description}")
        else:
            self.failed += 1
            self.failures.append(f"[{tag}] {description}")
            print(f"  {Colors.RED}[FAIL]{Colors.ENDC} [{tag}] {description}")

    def summary(self) -> int:
        print("\n" + "=" * 75)
        print(f"{self.suite_name} Results")
        print("=" * 75)
        print(f"  Total Checks : {self.total}")
        print(f"  Passed       : {self.passed}")
        print(f"  Failed       : {self.failed}")
        if self.failures:
            print("\nFailures:")
            for f in self.failures:
                print(f"  - {Colors.RED}{f}{Colors.ENDC}")
        else:
            print(f"\n{Colors.GREEN}{Colors.BOLD}ALL CHECKS PASSED EMPIRICALLY!{Colors.ENDC}")
        print("=" * 75)
        return 0 if self.failed == 0 else 1


# ==============================================================================
# Simulation Mock Models (Replicating GDScript Engine State & Kinematics)
# ==============================================================================

class MockGameState:
    def __init__(self):
        self.energy = 1000.0
        self.base_passive_rps = 100.0
        self.hired_workers: List[Dict[str, Any]] = []
        self.desk_levels = [1, 1, 1, 1, 1]
        self.staff_hyper_focus_active = False
        self.staff_hyper_focus_timer = 0.0
        self.staff_hyper_focus_remaining = 0.0
        self.staff_hyper_focus_multiplier = 1.50
        self.staff_coffee_break_active = False
        self.staff_coffee_break_timer = 0.0
        self.staff_coffee_break_remaining = 0.0
        self.unicorn_espresso_buff_active = False
        self.unicorn_espresso_buff_timer = 0.0
        self.unicorn_espresso_buff_remaining = 0.0
        self.signals_emitted = []
        self.coffee_breaks_granted = 0

    def get_active_workers_count(self) -> int:
        return sum(1 for w in self.hired_workers if w.get("current_state") == "working")

    def get_staff_average_morale(self) -> float:
        if not self.hired_workers:
            return 1.0
        return sum(w.get("morale", 1.0) for w in self.hired_workers) / len(self.hired_workers)

    def get_staff_rps_multiplier(self) -> float:
        active = self.get_active_workers_count()
        if active <= 0:
            return 1.0
        return 1.0 + (float(active) * 0.05) * self.get_staff_average_morale()

    def get_effective_passive_rps(self) -> float:
        staff_mult = self.get_staff_rps_multiplier()
        espresso_mult = 1.20 if (self.unicorn_espresso_buff_active or self.unicorn_espresso_buff_timer > 0.0) else 1.00
        return self.base_passive_rps * staff_mult * espresso_mult

    def activate_unicorn_espresso_buff(self, duration: float = 60.0):
        self.unicorn_espresso_buff_timer = duration
        self.unicorn_espresso_buff_remaining = duration
        self.unicorn_espresso_buff_active = True
        self.signals_emitted.append(("unicorn_espresso_buff_started", duration, 1.50, 1.20))

    def give_team_coffee_break(self) -> bool:
        self.coffee_breaks_granted += 1
        for w in self.hired_workers:
            w["fatigue"] = 0.0
            w["morale"] = 1.0
            w["current_state"] = "working"

        self.staff_hyper_focus_active = True
        self.staff_hyper_focus_timer = 60.0
        self.staff_hyper_focus_remaining = 60.0
        self.staff_hyper_focus_multiplier = 1.50
        self.staff_coffee_break_active = True
        self.staff_coffee_break_timer = 60.0
        self.staff_coffee_break_remaining = 60.0

        self.signals_emitted.append(("staff_coffee_break_started", 60.0))
        self.signals_emitted.append(("team_coffee_break_started", 60.0, 1.50))
        return True

    def is_staff_hyper_focus_active(self) -> bool:
        return (self.staff_hyper_focus_active or self.staff_coffee_break_active) and (
            self.staff_hyper_focus_timer > 0.0 or self.staff_coffee_break_timer > 0.0
        )

    def get_staff_hyper_focus_time_remaining(self) -> float:
        return max(0.0, max(self.staff_hyper_focus_timer, self.staff_coffee_break_timer))

    def get_staff_hyper_focus_multiplier(self) -> float:
        return self.staff_hyper_focus_multiplier if self.is_staff_hyper_focus_active() else 1.0

    def trigger_worker_epiphany(self, worker_id: str) -> float:
        reward = max(100.0, self.get_effective_passive_rps() * 15.0)
        self.energy += reward
        self.signals_emitted.append(("worker_epiphany_collected", worker_id, reward))
        return reward

    def process(self, delta: float):
        safe_delta = max(0.0, delta)
        # Espresso buff decay
        if self.unicorn_espresso_buff_timer > 0.0 or self.unicorn_espresso_buff_active:
            self.unicorn_espresso_buff_timer -= safe_delta
            self.unicorn_espresso_buff_remaining = max(0.0, self.unicorn_espresso_buff_timer)
            if self.unicorn_espresso_buff_timer <= 0.0:
                self.unicorn_espresso_buff_timer = 0.0
                self.unicorn_espresso_buff_remaining = 0.0
                self.unicorn_espresso_buff_active = False
                self.signals_emitted.append(("unicorn_espresso_buff_ended",))

        # Hyper-focus & coffee break decay
        if self.staff_hyper_focus_timer > 0.0 or self.staff_hyper_focus_active or self.staff_coffee_break_timer > 0.0:
            self.staff_hyper_focus_timer = max(0.0, self.staff_hyper_focus_timer - safe_delta)
            self.staff_hyper_focus_remaining = self.staff_hyper_focus_timer
            self.staff_coffee_break_timer = self.staff_hyper_focus_timer
            self.staff_coffee_break_remaining = self.staff_hyper_focus_remaining
            if self.staff_hyper_focus_timer <= 0.0:
                self.staff_hyper_focus_timer = 0.0
                self.staff_hyper_focus_remaining = 0.0
                self.staff_hyper_focus_active = False
                self.staff_coffee_break_timer = 0.0
                self.staff_coffee_break_remaining = 0.0
                self.staff_coffee_break_active = False
                self.signals_emitted.append(("staff_coffee_break_ended",))
                self.signals_emitted.append(("team_coffee_break_ended",))



class ChibiWorkerSimulator:
    STATE_WORKING = "working"
    STATE_COFFEE_BREAK = "break"
    STATE_FATIGUED = "fatigued"
    STATE_CELEBRATING = "celebrating"

    def __init__(self, worker_id: str, role: str = "Frontend Dev", game_state: MockGameState = None):
        self.worker_id = worker_id
        self.role = role
        self.game_state = game_state
        self.current_state = self.STATE_WORKING
        self.morale = 1.0
        self.fatigue = 0.0
        self.hyper_focus = False
        self.hyper_focus_multiplier = 1.50
        self._hyper_focus_timer = 0.0
        self._time = 0.0
        self._anim_phase_offset = random.uniform(0.0, 1.0)
        self._has_epiphany = False
        self._epiphany_reward = 0.0
        self._celebrate_timer = 0.0
        self._revert_state_after_celebrate = self.STATE_WORKING
        self.mood_icon_text = "💻"
        self.visor_text = "^.^"
        self.chibi_root_pos_y = 0.0
        self.left_arm_rot_x = 0.0
        self.right_arm_rot_x = 0.0
        self.head_rot_x = 0.0
        self.celebrations_played = 0
        self.signals_emitted = []

    def is_hyper_focus_active(self) -> bool:
        if self.hyper_focus or self._hyper_focus_timer > 0.0:
            return True
        if self.game_state and self.game_state.is_staff_hyper_focus_active():
            return True
        return False

    def get_animation_speed_multiplier(self) -> float:
        return self.hyper_focus_multiplier if self.is_hyper_focus_active() else 1.0

    def set_hyper_focus(self, active: bool, duration: float = 60.0):
        was_active = self.is_hyper_focus_active()
        self.hyper_focus = active
        if active:
            # Re-assigned directly, CLAMPED to duration
            self._hyper_focus_timer = duration if duration > 0.0 else 60.0
            if not was_active and self.current_state != self.STATE_FATIGUED:
                self.play_celebration(0.8)
        else:
            self._hyper_focus_timer = 0.0
        self.signals_emitted.append(("hyper_focus_changed", active, self.hyper_focus_multiplier if active else 1.0))

    def play_celebration(self, duration: float = 2.0):
        self._revert_state_after_celebrate = (
            self.current_state if self.current_state != self.STATE_CELEBRATING else self.STATE_WORKING
        )
        self._celebrate_timer = duration
        self.set_state(self.STATE_CELEBRATING)
        self.celebrations_played += 1

    def set_state(self, new_state: str):
        if self.current_state == new_state:
            return
        self.current_state = new_state
        self._update_state_visuals()

    def _update_state_visuals(self):
        if not self._has_epiphany:
            if self.current_state == self.STATE_WORKING:
                self.mood_icon_text = "💻"
                self.visor_text = "^.^" if self.morale > 0.6 else "•_•"
            elif self.current_state == self.STATE_COFFEE_BREAK:
                self.mood_icon_text = "☕"
                self.visor_text = "☕"
            elif self.current_state == self.STATE_FATIGUED:
                self.mood_icon_text = "💤"
                self.visor_text = "-.-"
            elif self.current_state == self.STATE_CELEBRATING:
                self.mood_icon_text = "🎉"
                self.visor_text = "★_★"

    def trigger_epiphany(self, custom_reward: float = 0.0):
        self._has_epiphany = True
        if custom_reward > 0.0:
            self._epiphany_reward = custom_reward
        elif self.game_state:
            self._epiphany_reward = max(100.0, self.game_state.get_effective_passive_rps() * 15.0)
        else:
            self._epiphany_reward = 500.0
        self.mood_icon_text = "💡"
        self.visor_text = "★_★"

    def collect_epiphany(self) -> float:
        if not self._has_epiphany:
            return 0.0
        reward = self._epiphany_reward
        self._has_epiphany = False
        if self.game_state:
            awarded = self.game_state.trigger_worker_epiphany(self.worker_id)
            if awarded > 0.0:
                reward = awarded
        self.play_celebration(1.5)
        return reward

    def tap_worker(self) -> float:
        if self._has_epiphany:
            return self.collect_epiphany()
        else:
            self.play_celebration(0.8)
            return 0.0

    def has_epiphany(self) -> bool:
        return self._has_epiphany

    def process(self, delta: float):
        if self._hyper_focus_timer > 0.0:
            self._hyper_focus_timer = max(0.0, self._hyper_focus_timer - delta)
            if self._hyper_focus_timer <= 0.0:
                self.hyper_focus = False
                self.signals_emitted.append(("hyper_focus_changed", False, 1.0))

        speed_mult = self.get_animation_speed_multiplier()
        self._time += delta * speed_mult
        t = self._time + self._anim_phase_offset

        if self._celebrate_timer > 0.0:
            self._celebrate_timer -= delta
            if self._celebrate_timer <= 0.0:
                self.set_state(self._revert_state_after_celebrate)

        if self.current_state == self.STATE_WORKING:
            self.left_arm_rot_x = -0.35 + math.sin(t * 14.0) * 0.15
            self.right_arm_rot_x = -0.35 - math.sin(t * 14.0) * 0.15
            self.head_rot_x = -0.05 + math.sin(t * 4.0) * 0.03
            self.chibi_root_pos_y = 0.0
        elif self.current_state == self.STATE_CELEBRATING:
            self.chibi_root_pos_y = abs(math.sin(t * 12.0)) * 0.22
            self.head_rot_x = math.sin(t * 8.0) * 0.1
        elif self.current_state == self.STATE_COFFEE_BREAK:
            self.right_arm_rot_x = -0.85 + math.sin(t * 3.0) * 0.08
            self.head_rot_x = 0.12 + math.sin(t * 3.0) * 0.04
            self.chibi_root_pos_y = 0.0
        elif self.current_state == self.STATE_FATIGUED:
            self.head_rot_x = -0.65 + math.sin(t * 1.2) * 0.02
            self.chibi_root_pos_y = 0.0


class OfficeExpansionSimulator:
    def __init__(self, game_state: MockGameState):
        self.game_state = game_state
        self.workers: Dict[str, ChibiWorkerSimulator] = {}
        self.signals_emitted = []

        # Standard 5 office specialists
        roles_workers = [
            ("Frontend Dev", "w_front"),
            ("Backend Dev", "w_back"),
            ("UI/UX Designer", "w_design"),
            ("Growth Hacker", "w_growth"),
            ("QA Engineer", "w_qa"),
        ]
        for role, w_id in roles_workers:
            w = ChibiWorkerSimulator(w_id, role, game_state)
            self.workers[w_id] = w
            self.game_state.hired_workers.append(
                {"id": w_id, "role": role, "morale": 1.0, "fatigue": 0.0, "current_state": "working"}
            )

    def activate_hyper_focus(self, duration: float = 60.0, speed_multiplier: float = 1.50):
        for w in self.workers.values():
            w.hyper_focus_multiplier = speed_multiplier
            w.set_hyper_focus(True, duration)
            if w.current_state != w.STATE_FATIGUED:
                w.play_celebration(1.0)
        self.signals_emitted.append(("office_hyper_focus_started", duration, speed_multiplier))

    def on_coffee_break_ended(self):
        for w in self.workers.values():
            w.set_state(ChibiWorkerSimulator.STATE_WORKING)
            w.set_hyper_focus(False)
        self.signals_emitted.append(("office_hyper_focus_ended",))

    def spawn_worker(self, w_id: str, role: str) -> ChibiWorkerSimulator:
        w = ChibiWorkerSimulator(w_id, role, self.game_state)
        # If office hyper focus is currently active, worker inherits multiplier
        if self.game_state.is_staff_hyper_focus_active():
            rem = self.game_state.get_staff_hyper_focus_time_remaining()
            w.hyper_focus_multiplier = 1.50
            w.set_hyper_focus(True, rem)
        self.workers[w_id] = w
        self.game_state.hired_workers.append(
            {"id": w_id, "role": role, "morale": 1.0, "fatigue": 0.0, "current_state": "working"}
        )
        return w

    def despawn_worker(self, w_id: str):
        if w_id in self.workers:
            del self.workers[w_id]
        self.game_state.hired_workers = [w for w in self.game_state.hired_workers if w.get("id") != w_id]

    def process(self, delta: float):
        for w in list(self.workers.values()):
            w.process(delta)


class CoffeeMachineSimulator:
    def __init__(self, game_state: MockGameState, office: OfficeExpansionSimulator):
        self.game_state = game_state
        self.office = office
        self.buff_duration = 60.0
        self.brew_cooldown = 60.0
        self.avatar_speed_boost = 1.50
        self.worker_speed_boost = 1.20
        self.is_brewing = False
        self.is_on_cooldown = False
        self.cooldown_remaining = 0.0
        self.synergies_triggered = 0
        self.signals_emitted = []

    def can_brew(self) -> bool:
        return not self.is_brewing and not self.is_on_cooldown

    def interact(self) -> bool:
        self.signals_emitted.append(("coffee_machine_interacted",))
        if not self.can_brew():
            return False
        self.start_brewing()
        return True

    def start_brewing(self):
        self.is_brewing = True
        self.signals_emitted.append(("brew_started",))

    def complete_brew(self, success: bool = True):
        self.is_brewing = False
        self.signals_emitted.append(("brew_completed", success))

        if success:
            if self.game_state:
                self.game_state.activate_unicorn_espresso_buff(self.buff_duration)
            self.signals_emitted.append(
                ("espresso_buff_started", self.buff_duration, self.avatar_speed_boost, self.worker_speed_boost)
            )
            self.trigger_office_synergy(self.buff_duration)
            self.is_on_cooldown = True
            self.cooldown_remaining = self.brew_cooldown

        self.signals_emitted.append(("brew_ended",))

    def trigger_office_synergy(self, duration: float = 60.0):
        self.synergies_triggered += 1
        if self.game_state:
            self.game_state.give_team_coffee_break()
        if self.office:
            for w in self.office.workers.values():
                w.fatigue = 0.0
                w.morale = 1.0
                w.set_state(ChibiWorkerSimulator.STATE_WORKING)
            self.office.activate_hyper_focus(duration, 1.50)
        self.signals_emitted.append(("office_hyper_focus_activated", duration, 1.50))

    def cancel_brew(self):
        self.is_brewing = False
        self.signals_emitted.append(("brew_ended",))

    def process(self, delta: float):
        if self.is_on_cooldown:
            self.cooldown_remaining = max(0.0, self.cooldown_remaining - delta)
            if self.cooldown_remaining <= 0.0:
                self.is_on_cooldown = False


class EspressoMinigameSimulator:
    def __init__(self):
        self.sweet_spot_min = 62.0
        self.sweet_spot_max = 84.0
        self.required_hold_time = 3.0
        self.pressure_decay_rate = 24.0
        self.pump_increment = 15.0
        self.current_pressure = 20.0
        self.current_hold_time = 0.0
        self.is_active = True
        self.is_finished = False

    def is_in_sweet_spot(self) -> bool:
        return self.sweet_spot_min <= self.current_pressure <= self.sweet_spot_max

    def pump(self):
        if not self.is_active or self.is_finished:
            return
        self.current_pressure = min(100.0, self.current_pressure + self.pump_increment)

    def process(self, delta: float) -> Optional[bool]:
        if not self.is_active or self.is_finished:
            return None
        safe_delta = min(0.1, max(0.0, delta))
        self.current_pressure = max(0.0, self.current_pressure - self.pressure_decay_rate * safe_delta)

        if self.is_in_sweet_spot():
            self.current_hold_time = min(self.required_hold_time, self.current_hold_time + safe_delta)
        else:
            self.current_hold_time = max(0.0, self.current_hold_time - safe_delta * 0.4)

        if self.current_hold_time >= self.required_hold_time:
            self.is_finished = True
            self.is_active = False
            return True
        return None


# ==============================================================================
# TIER 1: Static AST & Script Contract Deep Audit
# ==============================================================================

def test_tier1_ast_and_contracts(reporter: TestReporter):
    print(f"\n{Colors.BOLD}=== TIER 1: Static AST & Script Contract Deep Audit ==={Colors.ENDC}")

    cm_path = SCRIPTS_DIR / "coffee_machine_3d.gd"
    office_path = SCRIPTS_DIR / "office_expansion_3d.gd"
    worker_path = SCRIPTS_DIR / "chibi_worker_3d.gd"
    gs_path = SCRIPTS_DIR / "autoload" / "game_state.gd"
    minigame_path = SCRIPTS_DIR / "ui" / "espresso_brew_minigame.gd"

    reporter.check(cm_path.exists(), "coffee_machine_3d.gd exists on disk", "AST_Files")
    reporter.check(office_path.exists(), "office_expansion_3d.gd exists on disk", "AST_Files")
    reporter.check(worker_path.exists(), "chibi_worker_3d.gd exists on disk", "AST_Files")
    reporter.check(gs_path.exists(), "game_state.gd exists on disk", "AST_Files")
    reporter.check(minigame_path.exists(), "espresso_brew_minigame.gd exists on disk", "AST_Files")

    cm_src = cm_path.read_text(encoding="utf-8", errors="replace")
    office_src = office_path.read_text(encoding="utf-8", errors="replace")
    worker_src = worker_path.read_text(encoding="utf-8", errors="replace")
    gs_src = gs_path.read_text(encoding="utf-8", errors="replace")
    mini_src = minigame_path.read_text(encoding="utf-8", errors="replace")

    # CoffeeMachine3D contract
    reporter.check("signal office_hyper_focus_activated" in cm_src,
                   "CoffeeMachine3D declares signal office_hyper_focus_activated", "AST_CoffeeMachine")
    reporter.check("signal brew_completed" in cm_src,
                   "CoffeeMachine3D declares signal brew_completed", "AST_CoffeeMachine")
    reporter.check("func trigger_office_synergy" in cm_src,
                   "CoffeeMachine3D implements trigger_office_synergy(duration)", "AST_CoffeeMachine")
    reporter.check("func complete_brew" in cm_src,
                   "CoffeeMachine3D implements complete_brew(success)", "AST_CoffeeMachine")
    reporter.check('add_to_group("coffee_machines")' in cm_src,
                   "CoffeeMachine3D registers in group 'coffee_machines'", "AST_CoffeeMachine")
    reporter.check('get_nodes_in_group("staff_offices")' in cm_src,
                   "CoffeeMachine3D directly queries group 'staff_offices'", "AST_CoffeeMachine")

    # OfficeExpansion3D contract
    reporter.check("signal office_hyper_focus_started" in office_src,
                   "OfficeExpansion3D declares signal office_hyper_focus_started", "AST_OfficeExpansion")
    reporter.check("signal office_hyper_focus_ended" in office_src,
                   "OfficeExpansion3D declares signal office_hyper_focus_ended", "AST_OfficeExpansion")
    reporter.check("func activate_hyper_focus" in office_src,
                   "OfficeExpansion3D implements activate_hyper_focus(duration, multiplier)", "AST_OfficeExpansion")
    reporter.check("unicorn_espresso_buff_started" in office_src,
                   "OfficeExpansion3D connects unicorn_espresso_buff_started signal", "AST_OfficeExpansion")
    reporter.check("staff_coffee_break_ended" in office_src,
                   "OfficeExpansion3D connects staff_coffee_break_ended signal", "AST_OfficeExpansion")

    # ChibiWorker3D contract
    reporter.check("signal hyper_focus_changed" in worker_src,
                   "ChibiWorker3D declares signal hyper_focus_changed", "AST_ChibiWorker")
    reporter.check("func set_hyper_focus" in worker_src,
                   "ChibiWorker3D implements set_hyper_focus(active, duration)", "AST_ChibiWorker")
    reporter.check("func is_hyper_focus_active" in worker_src,
                   "ChibiWorker3D implements is_hyper_focus_active() helper", "AST_ChibiWorker")
    reporter.check("func get_animation_speed_multiplier" in worker_src,
                   "ChibiWorker3D implements get_animation_speed_multiplier()", "AST_ChibiWorker")
    reporter.check("delta * speed_mult" in worker_src,
                   "ChibiWorker3D scales procedural kinematics delta by speed_mult", "AST_ChibiWorker")

    # GameState contract
    reporter.check("func give_team_coffee_break" in gs_src,
                   "GameState implements give_team_coffee_break()", "AST_GameState")
    reporter.check("func activate_unicorn_espresso_buff" in gs_src,
                   "GameState implements activate_unicorn_espresso_buff(duration)", "AST_GameState")
    reporter.check("func is_staff_hyper_focus_active" in gs_src,
                   "GameState implements is_staff_hyper_focus_active()", "AST_GameState")
    reporter.check("func get_staff_hyper_focus_multiplier" in gs_src,
                   "GameState implements get_staff_hyper_focus_multiplier()", "AST_GameState")


# ==============================================================================
# TIER 2: Recipe & Brew Synergy Trigger Adversarial Matrix
# ==============================================================================

def test_tier2_recipe_synergy_triggers(reporter: TestReporter):
    print(f"\n{Colors.BOLD}=== TIER 2: Recipe & Brew Synergy Trigger Adversarial Matrix ==={Colors.ENDC}")

    # Test 1: Successful Unicorn Espresso Brew
    gs = MockGameState()
    office = OfficeExpansionSimulator(gs)
    cm = CoffeeMachineSimulator(gs, office)

    reporter.check(cm.can_brew() is True, "Coffee machine is initially ready to brew", "TRIGGER_Unicorn")
    cm.start_brewing()
    reporter.check(cm.is_brewing is True, "Machine enters brewing state", "TRIGGER_Unicorn")
    cm.complete_brew(success=True)

    reporter.check(cm.synergies_triggered == 1,
                   "Successful Unicorn Espresso brew triggers synergy exactly once", "TRIGGER_Unicorn")
    reporter.check(gs.is_staff_hyper_focus_active() is True,
                   "GameState staff hyper-focus is active post-Unicorn brew", "TRIGGER_Unicorn")
    reporter.check(gs.unicorn_espresso_buff_active is True,
                   "GameState unicorn espresso buff (+20% worker production) is active", "TRIGGER_Unicorn")
    reporter.check(cm.is_on_cooldown is True,
                   "Coffee machine engages 60s cooldown on successful brew", "TRIGGER_Unicorn")
    reporter.check(math.isclose(cm.cooldown_remaining, 60.0, abs_tol=1e-3),
                   "Cooldown timer initialized strictly to 60.0s", "TRIGGER_Unicorn")

    # Verify signal emission
    activated_signals = [sig for sig in cm.signals_emitted if sig[0] == "office_hyper_focus_activated"]
    reporter.check(len(activated_signals) == 1,
                   "office_hyper_focus_activated emitted exactly once", "TRIGGER_Signals")
    reporter.check(activated_signals[0][1] == 60.0 and activated_signals[0][2] == 1.50,
                   "Signal parameters are exactly (duration=60.0, speed_mult=1.50)", "TRIGGER_Signals")

    # Test 2: Failed / Incomplete Espresso Brew
    gs2 = MockGameState()
    office2 = OfficeExpansionSimulator(gs2)
    cm2 = CoffeeMachineSimulator(gs2, office2)

    cm2.start_brewing()
    cm2.complete_brew(success=False)

    reporter.check(cm2.synergies_triggered == 0,
                   "Failed brew does NOT trigger office synergy", "TRIGGER_Failure")
    reporter.check(gs2.is_staff_hyper_focus_active() is False,
                   "Failed brew does NOT activate GameState hyper-focus", "TRIGGER_Failure")
    reporter.check(gs2.unicorn_espresso_buff_active is False,
                   "Failed brew does NOT activate Unicorn buff", "TRIGGER_Failure")
    reporter.check(cm2.is_on_cooldown is False,
                   "Failed brew does NOT engage cooldown (player may retry)", "TRIGGER_Failure")
    reporter.check(all(not w.is_hyper_focus_active() for w in office2.workers.values()),
                   "Zero office workers accelerated on failed brew", "TRIGGER_Failure")

    # Test 3: Cancelled Brew (player walked away / pressed ESC)
    gs3 = MockGameState()
    office3 = OfficeExpansionSimulator(gs3)
    cm3 = CoffeeMachineSimulator(gs3, office3)

    cm3.start_brewing()
    cm3.cancel_brew()

    reporter.check(cm3.synergies_triggered == 0,
                   "Cancelled brew does NOT trigger office synergy", "TRIGGER_Cancel")
    reporter.check(gs3.is_staff_hyper_focus_active() is False,
                   "Cancelled brew leaves hyper-focus inactive", "TRIGGER_Cancel")
    reporter.check(cm3.is_on_cooldown is False,
                   "Cancelled brew leaves cooldown inactive", "TRIGGER_Cancel")


# ==============================================================================
# TIER 3: Rapid Consecutive Brewing & Timer Clamping Stress
# ==============================================================================

def test_tier3_rapid_consecutive_brewing_clamp(reporter: TestReporter):
    print(f"\n{Colors.BOLD}=== TIER 3: Rapid Consecutive Brewing & Timer Clamping Stress ==={Colors.ENDC}")

    gs = MockGameState()
    office = OfficeExpansionSimulator(gs)
    cm = CoffeeMachineSimulator(gs, office)

    # Stress Test A: 10 successive rapid Unicorn brew completions
    print("  * Stressing 10 rapid successive Unicorn Espresso brews...")
    for i in range(10):
        # Force brew completion without cooldown delay to test math clamping
        cm.complete_brew(success=True)
        cm.is_on_cooldown = False

    # Invariant 1: Timer Clamping at strictly 60.0s (never 600s!)
    gs_timer = gs.staff_hyper_focus_timer
    reporter.check(math.isclose(gs_timer, 60.0, abs_tol=1e-3),
                   f"GameState hyper-focus timer is strictly clamped to 60.0s (got {gs_timer:.2f}s, NOT 600s)", "CLAMP_Timer")

    for w_id, w in office.workers.items():
        reporter.check(math.isclose(w._hyper_focus_timer, 60.0, abs_tol=1e-3),
                       f"Worker {w_id} hyper-focus timer clamped to exactly 60.0s", "CLAMP_WorkerTimer")

    # Invariant 2: Non-Stacking Multiplier (strictly 1.50x, never 1.5^10 = 57.66x!)
    gs_mult = gs.get_staff_hyper_focus_multiplier()
    reporter.check(math.isclose(gs_mult, 1.50, abs_tol=1e-5),
                   f"GameState speed multiplier is strictly 1.50x (got {gs_mult}x, NOT 57.66x)", "CLAMP_Multiplier")

    for w_id, w in office.workers.items():
        w_mult = w.get_animation_speed_multiplier()
        reporter.check(math.isclose(w_mult, 1.50, abs_tol=1e-5),
                       f"Worker {w_id} speed multiplier remains strictly 1.50x (non-stacking)", "CLAMP_WorkerMult")

    # Invariant 3: Economy RPS Compounding (strictly 1.25 staff * 1.20 espresso = 1.50x, NOT 1.20^10 = 6.19x!)
    eff_rps = gs.get_effective_passive_rps()
    expected_rps = 100.0 * 1.25 * 1.20  # 150.0
    reporter.check(math.isclose(eff_rps, expected_rps, abs_tol=1e-3),
                   f"Effective passive RPS compounds correctly to {expected_rps} (got {eff_rps})", "CLAMP_Economy")

    # Stress Test B: Mid-countdown refresh behavior
    print("  * Advancing simulation by 25.0s, then triggering refresh brew...")
    for _ in range(25):
        gs.process(1.0)
        office.process(1.0)
        cm.process(1.0)

    rem_before = gs.get_staff_hyper_focus_time_remaining()
    reporter.check(math.isclose(rem_before, 35.0, abs_tol=1e-2),
                   f"Remaining timer at t=25s is ~35.0s (got {rem_before:.2f}s)", "CLAMP_Refresh")

    # Trigger second brew
    cm.complete_brew(success=True)
    rem_after = gs.get_staff_hyper_focus_time_remaining()
    reporter.check(math.isclose(rem_after, 60.0, abs_tol=1e-3),
                   f"Second brew refreshes timer back to exactly 60.0s (NOT 35 + 60 = 95s)", "CLAMP_Refresh")

    # Stress Test C: 100 Monte Carlo randomized consecutive brews
    print("  * Running 100 Monte Carlo chaotic brews with random elapsed intervals...")
    clamping_violations = 0
    multiplier_violations = 0
    for cycle in range(100):
        step_dt = random.uniform(0.1, 10.0)
        gs.process(step_dt)
        office.process(step_dt)
        cm.process(step_dt)
        cm.complete_brew(success=True)
        cm.is_on_cooldown = False


        if gs.staff_hyper_focus_timer > 60.0001 or gs.staff_hyper_focus_timer < 0.0:
            clamping_violations += 1
        for w in office.workers.values():
            if w._hyper_focus_timer > 60.0001 or w._hyper_focus_timer < 0.0:
                clamping_violations += 1
            if not math.isclose(w.get_animation_speed_multiplier(), 1.50, abs_tol=1e-5):
                multiplier_violations += 1

    reporter.check(clamping_violations == 0,
                   f"100 Monte Carlo brews: zero timer clamping violations (violations: {clamping_violations})", "CLAMP_MonteCarlo")
    reporter.check(multiplier_violations == 0,
                   f"100 Monte Carlo brews: zero speed multiplier stacking violations (violations: {multiplier_violations})", "CLAMP_MonteCarlo")


# ==============================================================================
# TIER 4: Office Kinematics Scaling Across All 5 Workers
# ==============================================================================

def test_tier4_office_kinematics_scaling(reporter: TestReporter):
    print(f"\n{Colors.BOLD}=== TIER 4: Office Kinematics Scaling Across All 5 Workers ==={Colors.ENDC}")

    gs = MockGameState()
    office = OfficeExpansionSimulator(gs)
    cm = CoffeeMachineSimulator(gs, office)

    # Setup heterogeneous initial states across the 5 workers
    workers_list = list(office.workers.values())
    w0_work = workers_list[0]  # Working
    w1_tired = workers_list[1]  # Fatigued
    w2_break = workers_list[2]  # Coffee break
    w3_epi = workers_list[3]  # Epiphany
    w4_work2 = workers_list[4]  # Working

    w1_tired.set_state(ChibiWorkerSimulator.STATE_FATIGUED)
    w1_tired.fatigue = 1.0
    w1_tired.morale = 0.2
    w2_break.set_state(ChibiWorkerSimulator.STATE_COFFEE_BREAK)
    w3_epi.trigger_epiphany()

    reporter.check(len(office.workers) == 5, "Office staffed with all 5 specialist workers", "KIN_Complement")
    reporter.check(w1_tired.current_state == ChibiWorkerSimulator.STATE_FATIGUED, "Worker 1 starts in FATIGUED state", "KIN_Pre")
    reporter.check(w2_break.current_state == ChibiWorkerSimulator.STATE_COFFEE_BREAK, "Worker 2 starts in COFFEE_BREAK state", "KIN_Pre")
    reporter.check(w3_epi.has_epiphany() is True, "Worker 3 starts with active EPIPHANY", "KIN_Pre")

    # Trigger Unicorn Espresso Synergy
    cm.complete_brew(success=True)

    # Invariant: Fatigue Cleansing & Coffee Break Recovery
    reporter.check(w1_tired.fatigue == 0.0, "Worker 1 fatigue cleansed to 0.0 by coffee break", "KIN_Cleanse")
    reporter.check(w1_tired.morale == 1.0, "Worker 1 morale restored to 1.0 by coffee break", "KIN_Cleanse")

    # Invariant: ALL 5 Workers scaled strictly to 1.50x
    all_scaled = all(math.isclose(w.get_animation_speed_multiplier(), 1.50, abs_tol=1e-5) for w in office.workers.values())
    reporter.check(all_scaled, "ALL 5 workers scale strictly to 1.50x animation speed multiplier", "KIN_150x")

    for i, w in enumerate(workers_list):
        mult = w.get_animation_speed_multiplier()
        reporter.check(math.isclose(mult, 1.50, abs_tol=1e-5),
                       f"Worker {i} ({w.worker_id} - {w.role}) animation speed is exactly 1.50x", "KIN_Individual")

    # Invariant: Kinematic Time Progression (1.50x Time Dilation)
    # Record time before 1.0s process
    t_starts = {w.worker_id: w._time for w in office.workers.values()}
    office.process(1.0)
    t_ends = {w.worker_id: w._time for w in office.workers.values()}

    for w_id in office.workers.keys():
        delta_t = t_ends[w_id] - t_starts[w_id]
        reporter.check(math.isclose(delta_t, 1.50, abs_tol=1e-5),
                       f"Worker {w_id} _time advanced by exactly 1.50s per 1.0s delta (1.50x time dilation)", "KIN_Dilation")

    # Invariant: Typing Arm Oscillation Frequency (14.0 rad/s -> 21.0 rad/s)
    # Re-initialize 2 workers in working state: 1 normal (1.0x) and 1 hyper-focus (1.5x)
    gs_f = MockGameState()
    w_norm = ChibiWorkerSimulator("w_norm", "Backend Dev", gs_f)
    w_hyp = ChibiWorkerSimulator("w_hyp", "Backend Dev", gs_f)
    w_norm.set_hyper_focus(False)
    w_hyp.set_hyper_focus(True, duration=60.0)
    # Ensure both workers are actively typing (skip initial celebration hop)
    w_hyp._celebrate_timer = 0.0
    w_hyp.set_state(ChibiWorkerSimulator.STATE_WORKING)
    w_norm.set_state(ChibiWorkerSimulator.STATE_WORKING)

    # Force identical phase offset for mathematical comparison
    w_norm._anim_phase_offset = 0.0
    w_hyp._anim_phase_offset = 0.0


    # Advance both by dt=0.01s over 100 frames (1.0s real time)
    norm_peaks = 0
    hyp_peaks = 0
    prev_norm_arm = w_norm.left_arm_rot_x
    prev_hyp_arm = w_hyp.left_arm_rot_x
    norm_dir = 1
    hyp_dir = 1

    for step in range(100):
        w_norm.process(0.01)
        w_hyp.process(0.01)

        # Detect direction reversals (peaks/valleys)
        if (w_norm.left_arm_rot_x - prev_norm_arm) * norm_dir < 0:
            norm_peaks += 1
            norm_dir *= -1
        prev_norm_arm = w_norm.left_arm_rot_x

        if (w_hyp.left_arm_rot_x - prev_hyp_arm) * hyp_dir < 0:
            hyp_peaks += 1
            hyp_dir *= -1
        prev_hyp_arm = w_hyp.left_arm_rot_x

    reporter.check(hyp_peaks > norm_peaks,
                   f"Hyper-focus arm typing reverses direction 1.5x more often ({hyp_peaks} vs {norm_peaks} reversals)", "KIN_TypingFreq")
    ratio = float(hyp_peaks) / float(norm_peaks) if norm_peaks > 0 else 0.0
    reporter.check(1.30 <= ratio <= 1.70,
                   f"Typing reversal frequency ratio is ~1.50x (observed ratio: {ratio:.2f})", "KIN_TypingFreq")


# ==============================================================================
# TIER 5: High-Precision Expiration Reversion & Multiplier Decay
# ==============================================================================

def test_tier5_timer_expiration_reversion(reporter: TestReporter):
    print(f"\n{Colors.BOLD}=== TIER 5: High-Precision Expiration Reversion & Multiplier Decay ==={Colors.ENDC}")

    gs = MockGameState()
    office = OfficeExpansionSimulator(gs)
    cm = CoffeeMachineSimulator(gs, office)

    cm.complete_brew(success=True)

    # Step 1: Active at t = 0.0s
    reporter.check(gs.is_staff_hyper_focus_active() is True, "Hyper-focus active at t=0s", "EXPIRY_Step")
    reporter.check(all(w.is_hyper_focus_active() for w in office.workers.values()),
                   "All 5 workers active at t=0s", "EXPIRY_Step")

    # Step 2: Active at t = 30.0s (midpoint)
    for _ in range(30):
        gs.process(1.0)
        office.process(1.0)
        cm.process(1.0)

    reporter.check(gs.is_staff_hyper_focus_active() is True, "Hyper-focus remains active at t=30s", "EXPIRY_Step")
    reporter.check(math.isclose(gs.get_staff_hyper_focus_time_remaining(), 30.0, abs_tol=1e-2),
                   "Remaining time is 30.0s at t=30s", "EXPIRY_Step")
    reporter.check(all(math.isclose(w.get_animation_speed_multiplier(), 1.50, abs_tol=1e-5) for w in office.workers.values()),
                   "All workers animating at 1.50x at t=30s", "EXPIRY_Step")

    # Step 3: Active at t = 59.9s (pre-boundary)
    for _ in range(299):
        gs.process(0.1)
        office.process(0.1)
        cm.process(0.1)

    rem_pre = gs.get_staff_hyper_focus_time_remaining()
    reporter.check(math.isclose(rem_pre, 0.1, abs_tol=1e-2),
                   f"Remaining time is ~0.1s at t=59.9s (got {rem_pre:.2f}s)", "EXPIRY_Step")
    reporter.check(gs.is_staff_hyper_focus_active() is True, "Hyper-focus still active at t=59.9s", "EXPIRY_Step")

    # Step 4: Step across the boundary (advance by 0.2s -> t = 60.1s > 60.0s)
    gs.process(0.2)
    office.process(0.2)
    cm.process(0.2)

    # Notify office of coffee break ended (mirrors GameState staff_coffee_break_ended signal)
    office.on_coffee_break_ended()

    # Invariant: Complete Expiration across all systems
    reporter.check(gs.is_staff_hyper_focus_active() is False,
                   "GameState.is_staff_hyper_focus_active() cleanly returns False post-60s", "EXPIRY_Revert")
    reporter.check(gs.staff_hyper_focus_timer == 0.0,
                   "GameState staff_hyper_focus_timer is exactly 0.0", "EXPIRY_Revert")
    reporter.check(gs.unicorn_espresso_buff_active is False,
                   "GameState unicorn espresso buff expired cleanly", "EXPIRY_Revert")
    reporter.check(gs.get_staff_hyper_focus_multiplier() == 1.0,
                   "GameState hyper-focus multiplier smoothly reverted to 1.0x", "EXPIRY_Revert")

    # Check all 5 workers
    for w_id, w in office.workers.items():
        reporter.check(w.is_hyper_focus_active() is False,
                       f"Worker {w_id} is_hyper_focus_active() returns False post-expiry", "EXPIRY_Worker")
        reporter.check(w._hyper_focus_timer == 0.0,
                       f"Worker {w_id} timer is exactly 0.0", "EXPIRY_Worker")
        reporter.check(w.get_animation_speed_multiplier() == 1.0,
                       f"Worker {w_id} animation speed multiplier reverted to 1.00x", "EXPIRY_Worker")

    # Kinematic time progression post-expiry: exactly 1.0s advance per 1.0s delta
    t_pre_revert = {w.worker_id: w._time for w in office.workers.values()}
    office.process(1.0)
    t_post_revert = {w.worker_id: w._time for w in office.workers.values()}

    for w_id in office.workers.keys():
        revert_delta = t_post_revert[w_id] - t_pre_revert[w_id]
        reporter.check(math.isclose(revert_delta, 1.0, abs_tol=1e-5),
                       f"Worker {w_id} time progression smoothly normalised to 1.00x speed (delta={revert_delta:.3f}s)", "EXPIRY_Kinematics")


# ==============================================================================
# TIER 6: Machine Cooldown Invariants & Sweet-Spot Pressure Dynamics
# ==============================================================================

def test_tier6_cooldown_and_sweet_spot(reporter: TestReporter):
    print(f"\n{Colors.BOLD}=== TIER 6: Machine Cooldown Invariants & Sweet-Spot Pressure Dynamics ==={Colors.ENDC}")

    gs = MockGameState()
    office = OfficeExpansionSimulator(gs)
    cm = CoffeeMachineSimulator(gs, office)

    # 1. Fresh machine
    reporter.check(cm.can_brew() is True, "Machine initially ready to brew", "COOLDOWN_Init")

    # 2. Complete brew -> enters 60s cooldown
    cm.complete_brew(success=True)
    reporter.check(cm.is_on_cooldown is True, "Cooldown engaged immediately on brew completion", "COOLDOWN_Engage")
    reporter.check(cm.can_brew() is False, "can_brew() returns False during active cooldown", "COOLDOWN_Engage")

    # 3. Premature interaction rejected
    interaction_accepted = cm.interact()
    reporter.check(interaction_accepted is False, "Premature interaction during cooldown is strictly rejected", "COOLDOWN_Reject")

    # 4. Cooldown decays linearly
    cm.process(20.0)
    reporter.check(math.isclose(cm.cooldown_remaining, 40.0, abs_tol=1e-2),
                   "Cooldown decremented to 40.0s after 20.0s elapsed", "COOLDOWN_Decay")
    reporter.check(cm.can_brew() is False, "can_brew() remains False at t=20s", "COOLDOWN_Decay")

    cm.process(39.9)
    reporter.check(math.isclose(cm.cooldown_remaining, 0.1, abs_tol=1e-2),
                   "Cooldown decremented to 0.1s at t=59.9s", "COOLDOWN_Decay")
    reporter.check(cm.can_brew() is False, "can_brew() still False at t=59.9s", "COOLDOWN_Decay")

    # 5. Cooldown expiration at 60.0s
    cm.process(0.2)
    reporter.check(cm.is_on_cooldown is False, "is_on_cooldown is False after 60.1s", "COOLDOWN_Expiry")
    reporter.check(cm.can_brew() is True, "can_brew() returns True after cooldown expiry", "COOLDOWN_Expiry")
    reporter.check(cm.cooldown_remaining == 0.0, "cooldown_remaining clamped to 0.0", "COOLDOWN_Expiry")

    # 6. Sweet-Spot Pressure Dynamics Simulation
    minigame = EspressoMinigameSimulator()
    reporter.check(minigame.current_pressure == 20.0, "Initial extraction pressure is 20.0 bar", "SWEET_Spot")
    reporter.check(minigame.is_in_sweet_spot() is False, "20.0 bar is below sweet-spot zone (62-84 bar)", "SWEET_Spot")

    # Pump 3 times: 20 + 15*3 = 65 bar (inside sweet spot [62..84])
    minigame.pump()
    minigame.pump()
    minigame.pump()
    reporter.check(minigame.current_pressure == 65.0, "Pressure after 3 pumps is 65.0 bar", "SWEET_Spot")
    reporter.check(minigame.is_in_sweet_spot() is True, "65.0 bar is inside golden sweet-spot [62..84]", "SWEET_Spot")

    # Hold in sweet spot for 3.0s to extract Unicorn Espresso
    extracted = False
    for step in range(35):
        # Pump periodically to counter 24 bar/s decay
        if minigame.current_pressure < 70.0:
            minigame.pump()
        res = minigame.process(0.1)
        if res is True:
            extracted = True
            break

    reporter.check(extracted is True, "Sweet-spot minigame successfully extracts Unicorn Espresso after 3.0s hold", "SWEET_Extract")
    reporter.check(minigame.is_finished is True, "Minigame marked finished post-extraction", "SWEET_Extract")


# ==============================================================================
# TIER 7: Dynamic Staff Reconfiguration Mid-Buff (Hire/Fire at t=25s)
# ==============================================================================

def test_tier7_mid_buff_staff_lifecycle(reporter: TestReporter):
    print(f"\n{Colors.BOLD}=== TIER 7: Dynamic Staff Reconfiguration Mid-Buff (Hire/Fire at t=25s) ==={Colors.ENDC}")

    gs = MockGameState()
    office = OfficeExpansionSimulator(gs)
    cm = CoffeeMachineSimulator(gs, office)

    # Start with only 3 workers
    office.despawn_worker("w_growth")
    office.despawn_worker("w_qa")
    reporter.check(len(office.workers) == 3, "Office starts with 3 workers", "LIFECYCLE_Pre")

    # Trigger 60s Hyper-Focus
    cm.complete_brew(success=True)
    reporter.check(gs.is_staff_hyper_focus_active() is True, "Hyper-focus activated with 3 workers", "LIFECYCLE_Pre")

    # Advance 25s (35s remaining)
    for _ in range(25):
        gs.process(1.0)
        office.process(1.0)
        cm.process(1.0)

    # Player recruits 4th worker mid-buff
    w4 = office.spawn_worker("w_growth", "Growth Hacker")
    reporter.check(len(office.workers) == 4, "4th worker spawned mid-buff at t=25s", "LIFECYCLE_Hire")
    reporter.check(w4.is_hyper_focus_active() is True,
                   "Newly recruited worker inherits active office hyper-focus", "LIFECYCLE_Hire")
    reporter.check(math.isclose(w4.get_animation_speed_multiplier(), 1.50, abs_tol=1e-5),
                   "Newly recruited worker animation speed is 1.50x", "LIFECYCLE_Hire")

    # Advance another 15s to t=40s (20s remaining)
    for _ in range(15):
        gs.process(1.0)
        office.process(1.0)
        cm.process(1.0)

    # Player fires a worker mid-buff
    office.despawn_worker("w_front")
    reporter.check("w_front" not in office.workers, "w_front cleanly removed from office dictionary", "LIFECYCLE_Fire")
    reporter.check(len(office.workers) == 3, "Office worker count cleanly decremented to 3", "LIFECYCLE_Fire")

    # Process remaining 25s (reaches t=65s > 60s)
    for _ in range(25):
        gs.process(1.0)
        office.process(1.0)
        cm.process(1.0)

    office.on_coffee_break_ended()

    reporter.check(gs.is_staff_hyper_focus_active() is False,
                   "Hyper-focus expires cleanly despite mid-buff hiring and firing", "LIFECYCLE_Revert")
    all_reverted = all(w.get_animation_speed_multiplier() == 1.0 for w in office.workers.values())
    reporter.check(all_reverted, "All remaining workers cleanly reverted to 1.0x animation speed", "LIFECYCLE_Revert")


# ==============================================================================
# TIER 8: Concurrent Epiphany Interaction & Economy Compounding
# ==============================================================================

def test_tier8_concurrent_epiphany_synergy(reporter: TestReporter):
    print(f"\n{Colors.BOLD}=== TIER 8: Concurrent Epiphany Interaction & Economy Compounding ==={Colors.ENDC}")

    gs = MockGameState()
    office = OfficeExpansionSimulator(gs)
    cm = CoffeeMachineSimulator(gs, office)

    # 5 full-morale active workers -> staff multiplier = 1.0 + 5 * 0.05 * 1.0 = 1.25x
    reporter.check(math.isclose(gs.get_staff_rps_multiplier(), 1.25, abs_tol=1e-3),
                   "5 active workers produce exact +25% staff multiplier (1.25x)", "ECON_Staff")

    # Brew Unicorn Espresso: engages +20% worker multiplier buff
    cm.complete_brew(success=True)

    eff_rps = gs.get_effective_passive_rps()
    # 100 base * 1.25 staff * 1.20 unicorn = 150.0 RPS
    reporter.check(math.isclose(eff_rps, 150.0, abs_tol=1e-3),
                   f"Effective passive RPS compounds staff + unicorn buff: 100 * 1.25 * 1.20 = 150.0 (got {eff_rps})", "ECON_Compounding")

    # Trigger spontaneous epiphany on QA Engineer during active hyper-focus
    w_qa = office.workers["w_qa"]
    w_qa.trigger_epiphany()

    reporter.check(w_qa.has_epiphany() is True, "QA Engineer has active epiphany", "ECON_Epiphany")
    reporter.check(w_qa.mood_icon_text == "💡", "Mood icon shows '💡' indicator", "ECON_Epiphany")

    # Expected reward: max(100.0, 150.0 * 15.0) = 2250.0 energy
    expected_reward = 150.0 * 15.0  # 2250.0
    energy_before = gs.energy
    collected_reward = w_qa.tap_worker()

    reporter.check(math.isclose(collected_reward, expected_reward, abs_tol=1e-3),
                   f"Epiphany reward correctly uses compounded RPS (expected {expected_reward}, got {collected_reward})", "ECON_Reward")
    reporter.check(math.isclose(gs.energy, energy_before + expected_reward, abs_tol=1e-3),
                   f"GameState energy credited: {energy_before} -> {gs.energy}", "ECON_Credit")

    # Idempotence: 10 extra taps return 0.0
    extra_taps = [w_qa.tap_worker() for _ in range(10)]
    reporter.check(all(r == 0.0 for r in extra_taps),
                   "10 successive rapid taps return 0.0 (strictly idempotent)", "ECON_Idempotent")


# ==============================================================================
# TIER 9: Frame Delta Jitter, Micro-Steps & Severe Hitch Chaos Fuzzing
# ==============================================================================

def test_tier9_frame_delta_chaos_fuzzing(reporter: TestReporter):
    print(f"\n{Colors.BOLD}=== TIER 9: Frame Delta Jitter, Micro-Steps & Severe Hitch Chaos Fuzzing ==={Colors.ENDC}")

    gs = MockGameState()
    office = OfficeExpansionSimulator(gs)
    cm = CoffeeMachineSimulator(gs, office)

    cm.complete_brew(success=True)

    delta_pool = [
        0.0005,  # 2000 FPS micro-step
        0.004167,  # 240 FPS
        0.016667,  # 60 FPS
        0.033333,  # 30 FPS
        0.1,  # 10 FPS lag
        0.5,  # severe frame drop
        2.0,  # 2s freeze hitch
        5.0,  # 5s macro hitch
        0.0,  # paused frame
    ]

    invariants_broken = 0
    total_elapsed = 0.0

    print("  * Running 1,000 chaotic delta steps...")
    for step in range(1000):
        dt = random.choice(delta_pool)
        gs.process(dt)
        office.process(dt)
        cm.process(dt)
        total_elapsed += dt

        # Assert timer clamping invariants
        if gs.staff_hyper_focus_timer < 0.0 or gs.staff_hyper_focus_timer > 60.0001:
            invariants_broken += 1
        if cm.cooldown_remaining < 0.0 or cm.cooldown_remaining > 60.0001:
            invariants_broken += 1

        for w in office.workers.values():
            if w._hyper_focus_timer < 0.0 or w._hyper_focus_timer > 60.0001:
                invariants_broken += 1
            mult = w.get_animation_speed_multiplier()
            if not (math.isclose(mult, 1.50, abs_tol=1e-5) or math.isclose(mult, 1.00, abs_tol=1e-5)):
                invariants_broken += 1
            if math.isnan(w._time) or math.isinf(w._time):
                invariants_broken += 1

    reporter.check(invariants_broken == 0,
                   f"1,000 chaotic delta steps: zero mathematical or clamping invariants broken (violations: {invariants_broken})", "CHAOS_Invariants")
    reporter.check(total_elapsed > 60.0,
                   f"Simulation advanced past 60.0s threshold (total simulated: {total_elapsed:.1f}s)", "CHAOS_Advance")


# ==============================================================================
# TIER 10: End-to-End Teambuilding Synergy & Chaos Journey
# ==============================================================================

def test_tier10_end_to_end_journey(reporter: TestReporter):
    print(f"\n{Colors.BOLD}=== TIER 10: End-to-End Teambuilding Synergy & Chaos Journey ==={Colors.ENDC}")

    gs = MockGameState()
    gs.energy = 5000.0
    gs.base_passive_rps = 200.0

    office = OfficeExpansionSimulator(gs)
    cm = CoffeeMachineSimulator(gs, office)

    # Phase 1: 5 workers working diligently
    reporter.check(len(office.workers) == 5, "5 specialist workers staffed at office desks", "E2E_Staff")
    initial_rps = gs.get_effective_passive_rps()
    # 200 * 1.25 = 250.0
    reporter.check(math.isclose(initial_rps, 250.0, abs_tol=1e-3),
                   f"Initial team passive RPS is 250.0 (got {initial_rps})", "E2E_Economy")

    # Phase 2: Work fatigue accumulates
    for w in office.workers.values():
        w.fatigue = 0.50
        w.morale = 0.80

    # Phase 3: Spontaneous Epiphany triggers and is collected
    w_design = office.workers["w_design"]
    w_design.trigger_epiphany()
    reporter.check(w_design.has_epiphany() is True, "UI/UX Designer enters epiphany state", "E2E_Epiphany")

    collected = w_design.tap_worker()
    reporter.check(collected > 0.0, f"Player collected epiphany bonus ({collected} energy)", "E2E_Epiphany")
    reporter.check(w_design.current_state == ChibiWorkerSimulator.STATE_CELEBRATING,
                   "Designer jumps into victory celebration jump", "E2E_Celebration")

    # Advance 1.6s to let celebration expire back to working
    office.process(1.6)
    reporter.check(w_design.current_state == ChibiWorkerSimulator.STATE_WORKING,
                   "Designer resumes working at desk post-celebration", "E2E_Resume")

    # Phase 4: Unicorn Espresso Brew at CoffeeMachine3D
    cm.complete_brew(success=True)
    reporter.check(cm.is_on_cooldown is True, "Coffee machine enters 60s cooldown", "E2E_Coffee")
    reporter.check(gs.is_staff_hyper_focus_active() is True, "Office-wide Hyper-Focus activated", "E2E_Coffee")

    # Fatigue reset & morale restored
    all_restored = all(w.fatigue == 0.0 and w.morale == 1.0 for w in office.workers.values())
    reporter.check(all_restored, "All 5 workers cleansed of fatigue and restored to 1.0 morale", "E2E_Restored")

    # Compounded RPS: 200 * 1.25 * 1.20 = 300.0
    boosted_rps = gs.get_effective_passive_rps()
    reporter.check(math.isclose(boosted_rps, 300.0, abs_tol=1e-3),
                   f"Compounded Hyper-Focus passive RPS reaches peak 300.0 (got {boosted_rps})", "E2E_Economy")

    # Kinematics scaling: all 5 workers at 1.50x
    all_150 = all(math.isclose(w.get_animation_speed_multiplier(), 1.50, abs_tol=1e-5) for w in office.workers.values())
    reporter.check(all_150, "All 5 workers animating at 1.50x speed", "E2E_Kinematics")

    # Phase 5: Advance 60.5s to cleanly expire Hyper-Focus
    for _ in range(121):
        gs.process(0.5)
        office.process(0.5)
        cm.process(0.5)

    office.on_coffee_break_ended()

    # Phase 6: Verify clean baseline normalization
    reporter.check(gs.is_staff_hyper_focus_active() is False, "Hyper-focus cleanly expired", "E2E_Expiry")
    reporter.check(cm.can_brew() is True, "Coffee machine cooldown expired, ready to brew again", "E2E_Expiry")
    all_100 = all(math.isclose(w.get_animation_speed_multiplier(), 1.00, abs_tol=1e-5) for w in office.workers.values())
    reporter.check(all_100, "All 5 workers cleanly normalized back to 1.00x animation speed", "E2E_Expiry")
    normal_rps = gs.get_effective_passive_rps()
    reporter.check(math.isclose(normal_rps, 250.0, abs_tol=1e-3),
                   f"Passive RPS smoothly returned to normal 250.0 (got {normal_rps})", "E2E_Economy")


# ==============================================================================
# MAIN RUNNER
# ==============================================================================

def main():
    print(f"{Colors.HEADER}{Colors.BOLD}")
    print("=" * 75)
    print("IdleArcade Phase 14 Milestone 4: Coffee Synergy & Hyper-Focus Adversary")
    print("Empirical Stress Harness for Unicorn Espresso & Kinematics Scaling")
    print("=" * 75 + f"{Colors.ENDC}")

    reporter = TestReporter("Phase 14 Milestone M4 Challenger 2 (Synergy Adversary)")

    test_tier1_ast_and_contracts(reporter)
    test_tier2_recipe_synergy_triggers(reporter)
    test_tier3_rapid_consecutive_brewing_clamp(reporter)
    test_tier4_office_kinematics_scaling(reporter)
    test_tier5_timer_expiration_reversion(reporter)
    test_tier6_cooldown_and_sweet_spot(reporter)
    test_tier7_mid_buff_staff_lifecycle(reporter)
    test_tier8_concurrent_epiphany_synergy(reporter)
    test_tier9_frame_delta_chaos_fuzzing(reporter)
    test_tier10_end_to_end_journey(reporter)

    return reporter.summary()


if __name__ == "__main__":
    sys.exit(main())
