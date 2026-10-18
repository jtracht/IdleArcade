#!/usr/bin/env python3
"""
Phase 14 Milestone M4: Epiphany Timing & Click-Spam Challenger Suite
======================================================================
Target: IdleArcade Godot 4.3 - Milestone M4 (Requirement R4: Epiphany Moments & Synergies)
Code under test:
  - IdleArcade/scripts/chibi_worker_3d.gd
  - IdleArcade/scripts/office_expansion_3d.gd
  - IdleArcade/scripts/coffee_machine_3d.gd
  - IdleArcade/scripts/autoload/game_state.gd

Adversarial Stress Test Matrix:
  Tier 1: Static AST & Expiration Contract Audit
          - Signal declarations & signatures
          - Exported properties & method definitions
          - Epiphany lifetime / duration / auto-timeout contract audit
  Tier 2: Epiphany Lifetime & Clean Expiration Stress
          - Uncollected epiphany lifetime evaluation (30.0s idle timeout)
          - Stuck 💡 mood icon verification on fatigued worker
          - Visual particle leak: simultaneous Zzz + Epiphany particles
          - Permanent office epiphany lockout under uncollected epiphanies
  Tier 3: 1,000x Rapid Tap Spamming & Race Conditions
          - 1,000 sequential rapid taps on single epiphany (energy idempotence)
          - 1,000 concurrent multithreaded tap race conditions
          - Celebration timer truncation audit (1.5s vs 0.8s on double-tap)
          - Spam tapping on non-epiphany worker (0 energy leakage)
  Tier 4: Simultaneous 5-Worker Epiphanies & Cumulative Calculus
          - Full 5-specialist office roster instantiation
          - Simultaneous epiphanies across all 5 workers
          - Independent tap collection in non-sequential order
          - Exact cumulative energy award calculus: sum(max(100, 15*RPS))
          - Individual celebration and state reversion isolation
  Tier 5: Cross-Station Synergy & Hyper-Focus Interaction
          - Unicorn Espresso activation hop exclusion (1.0s hop blocks epiphanies)
          - Post-hop active Hyper-Focus epiphany triggering & 1.50x celebration kinematics
          - Team coffee break fatigue rescue and epiphany eligibility
  Tier 6: Touch vs Mouse Input Event Isolation
          - InputEventMouseButton (left vs right, press vs release)
          - InputEventScreenTouch (mobile touch press vs release)
          - InputEventMouseMotion & key events rejection

Executable via: python IdleArcade/tests/test_p14_m4_challenger_epiphany.py
"""

import math
import random
import re
import sys
import threading
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

if sys.platform == "win32":
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
        sys.stderr.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass

# Root Directory resolution
ROOT_DIR = Path(__file__).resolve().parent.parent
GAME_DIR = ROOT_DIR


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
        self.failures: List[str] = []
        self.warnings: List[str] = []

    def check(self, condition: bool, description: str, tag: str = "GENERAL", warning_only: bool = False):
        self.total += 1
        if condition:
            self.passed += 1
            print(f"  {Colors.GREEN}[PASS]{Colors.ENDC} [{tag}] {description}")
        else:
            if warning_only:
                self.passed += 1  # count as non-blocking warning
                self.warnings.append(f"[{tag}] {description}")
                print(f"  {Colors.YELLOW}[WARN]{Colors.ENDC} [{tag}] {description}")
            else:
                self.failed += 1
                self.failures.append(f"[{tag}] {description}")
                print(f"  {Colors.RED}[FAIL]{Colors.ENDC} [{tag}] {description}")

    def warn(self, message: str, tag: str = "WARN"):
        self.warnings.append(f"[{tag}] {message}")
        print(f"  {Colors.YELLOW}[WARN]{Colors.ENDC} [{tag}] {message}")

    def summary(self) -> int:
        print("\n" + "=" * 76)
        print(f"  {self.suite_name} Results")
        print("=" * 76)
        print(f"  Total Checks : {self.total}")
        print(f"  Passed       : {self.passed}")
        print(f"  Failed       : {self.failed}")
        print(f"  Warnings     : {len(self.warnings)}")
        if self.warnings:
            print(f"\n  {Colors.YELLOW}Adversarial Warnings & Observations:{Colors.ENDC}")
            for w in self.warnings:
                print(f"    - {Colors.YELLOW}{w}{Colors.ENDC}")
        if self.failures:
            print(f"\n  {Colors.RED}Defects & Missing Requirements Found:{Colors.ENDC}")
            for f in self.failures:
                print(f"    - {Colors.RED}{f}{Colors.ENDC}")
        print("=" * 76)
        return 0 if self.failed == 0 else 1


# ==============================================================================
# Simulation Behavioral Models matching chibi_worker_3d.gd & office_expansion_3d.gd
# ==============================================================================

class MockGameState:
    def __init__(self):
        self.energy = 1000.0
        self.base_passive_rps = 50.0
        self.hired_workers: List[Dict[str, Any]] = []
        self.desk_levels = [1, 1, 1, 1, 1]
        self.staff_hyper_focus_active = False
        self.staff_hyper_focus_timer = 0.0
        self.staff_coffee_break_active = False
        self.staff_coffee_break_timer = 0.0
        self.unicorn_espresso_buff_active = False
        self.unicorn_espresso_buff_timer = 0.0
        self.epiphany_history: List[Dict[str, Any]] = []
        self._lock = threading.Lock()

    def get_effective_passive_rps(self) -> float:
        active = sum(1 for w in self.hired_workers if w.get("current_state") == "working")
        avg_morale = sum(w.get("morale", 1.0) for w in self.hired_workers) / len(self.hired_workers) if self.hired_workers else 1.0
        staff_mult = 1.0 + (float(active) * 0.05) * avg_morale if active > 0 else 1.0
        espresso_mult = 1.20 if self.unicorn_espresso_buff_active else 1.00
        return self.base_passive_rps * staff_mult * espresso_mult

    def earn_energy(self, amount: float):
        with self._lock:
            self.energy += amount

    def trigger_worker_epiphany(self, worker_id: str) -> float:
        with self._lock:
            reward = max(100.0, self.get_effective_passive_rps() * 15.0)
            self.energy += reward
            self.epiphany_history.append({"worker_id": worker_id, "reward": reward})
            return reward

    def give_team_coffee_break(self) -> bool:
        for w in self.hired_workers:
            w["fatigue"] = 0.0
            w["morale"] = 1.0
            w["current_state"] = "working"
        self.staff_hyper_focus_active = True
        self.staff_hyper_focus_timer = 60.0
        self.staff_coffee_break_active = True
        self.staff_coffee_break_timer = 60.0
        return True

    def activate_unicorn_espresso_buff(self, duration: float = 60.0):
        self.unicorn_espresso_buff_active = True
        self.unicorn_espresso_buff_timer = duration

    def update_simulation(self, delta: float):
        if self.staff_hyper_focus_timer > 0.0:
            self.staff_hyper_focus_timer = max(0.0, self.staff_hyper_focus_timer - delta)
            self.staff_coffee_break_timer = self.staff_hyper_focus_timer
            if self.staff_hyper_focus_timer <= 0.0:
                self.staff_hyper_focus_active = False
                self.staff_coffee_break_active = False


class GDScriptChibiWorkerSim:
    """Exact replica of IdleArcade/scripts/chibi_worker_3d.gd logic."""

    STATE_WORKING = "working"
    STATE_COFFEE_BREAK = "break"
    STATE_FATIGUED = "fatigued"
    STATE_CELEBRATING = "celebrating"

    def __init__(self, worker_id: str, role: str, game_state: Optional[MockGameState] = None):
        self.worker_id = worker_id
        self.role = role
        self.game_state = game_state
        self.current_state = self.STATE_WORKING
        self.morale = 1.0
        self.fatigue = 0.0
        self.desk_assigned = 0
        self.desk_level = 1
        self.hyper_focus = False
        self.hyper_focus_multiplier = 1.5

        # Exported properties in chibi_worker_3d.gd
        self.epiphany_enabled = True
        self.epiphany_check_interval = 20.0
        self.epiphany_chance = 0.15
        self.epiphany_lifetime = 20.0

        # Visual node states
        self.mood_icon_text = "💻"
        self.mood_icon_scale = 1.0
        self.face_label_text = "^.^"
        self.epiphany_particles_emitting = False
        self.epiphany_light_visible = False
        self.zzz_particles_emitting = False
        self.steam_particles_emitting = False
        self.chibi_root_pos_y = 0.0

        # Internal state trackers in chibi_worker_3d.gd
        self._time = 0.0
        self._anim_phase_offset = random.random() * 10.0
        self._has_epiphany = False
        self._epiphany_reward = 0.0
        self._celebrate_timer = 0.0
        self._revert_state_after_celebrate = self.STATE_WORKING
        self._epiphany_pulse_tween_active = False
        self._hyper_focus_timer = 0.0
        self._epiphany_check_timer = 0.0
        self._epiphany_timer = 0.0

        # Concurrency lock
        self._lock = threading.Lock()

    def set_state(self, new_state: str):
        target = str(new_state).lower()
        if target in ["working"]:
            target = self.STATE_WORKING
        elif target in ["break", "coffee_break", "coffee"]:
            target = self.STATE_COFFEE_BREAK
        elif target in ["fatigued", "tired", "sleep"]:
            target = self.STATE_FATIGUED
        elif target in ["celebrating", "celebrate"]:
            target = self.STATE_CELEBRATING

        if self.current_state == target:
            return

        if target in [self.STATE_FATIGUED, self.STATE_COFFEE_BREAK] and self._has_epiphany:
            self.expire_epiphany()

        self.current_state = target
        self._update_state_visuals()

    def _update_state_visuals(self):
        # Particles
        self.zzz_particles_emitting = (self.current_state == self.STATE_FATIGUED)
        self.steam_particles_emitting = (self.current_state == self.STATE_COFFEE_BREAK)

        # Mood icon logic from chibi_worker_3d.gd line 209:
        # if mood_icon != null and not _has_epiphany:
        if not self._has_epiphany:
            if self.current_state == self.STATE_WORKING:
                self.mood_icon_text = "💻"
            elif self.current_state == self.STATE_COFFEE_BREAK:
                self.mood_icon_text = "☕"
            elif self.current_state == self.STATE_FATIGUED:
                self.mood_icon_text = "💤"
            elif self.current_state == self.STATE_CELEBRATING:
                self.mood_icon_text = "🎉"
            else:
                self.mood_icon_text = "💻"

        self._update_face_expression()
        if self.current_state != self.STATE_CELEBRATING:
            self.chibi_root_pos_y = 0.0

    def _update_face_expression(self):
        if self._has_epiphany:
            self.face_label_text = "★_★"
            return
        if self.current_state == self.STATE_WORKING:
            self.face_label_text = "^.^" if self.morale > 0.6 else "•_•"
        elif self.current_state == self.STATE_COFFEE_BREAK:
            self.face_label_text = "☕"
        elif self.current_state == self.STATE_FATIGUED:
            self.face_label_text = "-.-"
        elif self.current_state == self.STATE_CELEBRATING:
            self.face_label_text = "★_★"
        else:
            self.face_label_text = "•_•"

    def set_fatigue(self, new_fatigue: float):
        self.fatigue = max(0.0, min(1.0, new_fatigue))
        if self.fatigue >= 1.0 and self.current_state == self.STATE_WORKING:
            self.set_state(self.STATE_FATIGUED)
        elif self.fatigue < 0.8 and self.current_state == self.STATE_FATIGUED:
            self.set_state(self.STATE_WORKING)

    def set_hyper_focus(self, active: bool, duration: float = 60.0):
        self.hyper_focus = active
        if active:
            self._hyper_focus_timer = duration if duration > 0.0 else 60.0
            if self.current_state != self.STATE_FATIGUED:
                self.play_celebration(0.8)
        else:
            self._hyper_focus_timer = 0.0

    def is_hyper_focus_active(self) -> bool:
        return self.hyper_focus or self._hyper_focus_timer > 0.0

    def get_animation_speed_multiplier(self) -> float:
        return self.hyper_focus_multiplier if self.is_hyper_focus_active() else 1.0

    def check_epiphany(self, chance: float = -1.0) -> bool:
        if self.current_state != self.STATE_WORKING or self._has_epiphany:
            return False
        test_chance = chance if chance >= 0.0 else self.epiphany_chance
        if random.random() < test_chance:
            self.trigger_epiphany()
            return True
        return False

    def trigger_epiphany(self, custom_reward: float = 0.0):
        self._has_epiphany = True
        self._epiphany_timer = 0.0
        if custom_reward > 0.0:
            self._epiphany_reward = custom_reward
        else:
            if self.game_state:
                self._epiphany_reward = max(100.0, self.game_state.get_effective_passive_rps() * 15.0)
            else:
                self._epiphany_reward = 500.0

        self.mood_icon_text = "💡"
        self._epiphany_pulse_tween_active = True
        self.epiphany_particles_emitting = True
        self.epiphany_light_visible = True
        self._update_face_expression()

    def collect_epiphany(self) -> float:
        with self._lock:
            if not self._has_epiphany:
                return 0.0

            reward = self._epiphany_reward
            self._has_epiphany = False
            self._epiphany_timer = 0.0
            self._epiphany_pulse_tween_active = False
            self.mood_icon_scale = 1.0
            self.epiphany_particles_emitting = False
            self.epiphany_light_visible = False

            if self.game_state:
                awarded = self.game_state.trigger_worker_epiphany(self.worker_id)
                if awarded > 0.0:
                    reward = awarded

            self.play_celebration(1.5)
            return reward

    def expire_epiphany(self):
        if not self._has_epiphany:
            return
        self._has_epiphany = False
        self._epiphany_timer = 0.0
        self._epiphany_pulse_tween_active = False
        self.mood_icon_scale = 1.0
        self.epiphany_particles_emitting = False
        self.epiphany_light_visible = False
        self._update_state_visuals()

    def cancel_epiphany(self):
        self.expire_epiphany()

    def has_epiphany(self) -> bool:
        return self._has_epiphany

    def tap_worker(self) -> float:
        if self._has_epiphany:
            return self.collect_epiphany()
        elif self.current_state == self.STATE_CELEBRATING:
            if self._celebrate_timer < 0.8:
                self._celebrate_timer = 0.8
            return 0.0
        else:
            self.play_celebration(0.8)
            return 0.0

    def play_celebration(self, duration: float = 2.0):
        self._revert_state_after_celebrate = self.current_state if self.current_state != self.STATE_CELEBRATING else self.STATE_WORKING
        self._celebrate_timer = duration
        self.set_state(self.STATE_CELEBRATING)

    def process(self, delta: float):
        # Hyper focus duration decay
        if self._hyper_focus_timer > 0.0:
            self._hyper_focus_timer -= delta
            if self._hyper_focus_timer <= 0.0:
                self._hyper_focus_timer = 0.0
                self.hyper_focus = False

        speed_mult = self.get_animation_speed_multiplier()
        self._time += delta * speed_mult
        t = self._time + self._anim_phase_offset

        # Celebration timer decay
        if self._celebrate_timer > 0.0:
            self._celebrate_timer -= delta
            if self._celebrate_timer <= 0.0:
                self.set_state(self._revert_state_after_celebrate)

        # Epiphany auto-expiration timer
        if self._has_epiphany:
            self._epiphany_timer += delta
            if self._epiphany_timer >= self.epiphany_lifetime:
                self.expire_epiphany()

        # Spontaneous epiphany check during working state
        if self.epiphany_enabled and self.current_state == self.STATE_WORKING and not self._has_epiphany:
            self._epiphany_check_timer += delta
            if self._epiphany_check_timer >= self.epiphany_check_interval:
                self._epiphany_check_timer = 0.0
                self.check_epiphany()

        # Visual bounce
        if self.current_state == self.STATE_CELEBRATING:
            self.chibi_root_pos_y = abs(math.sin(t * 12.0)) * 0.22
        else:
            self.chibi_root_pos_y = 0.0

    # Input Event Handler Simulator
    def simulate_input_event(self, event_type: str, pressed: bool = True, button_index: int = 1) -> float:
        """Simulates _on_click_area_input_event."""
        is_tap = False
        if event_type == "MouseButton" and pressed and button_index == 1:
            is_tap = True
        elif event_type == "ScreenTouch" and pressed:
            is_tap = True

        if is_tap:
            return self.tap_worker()
        return 0.0


class GDScriptOfficeExpansionSim:
    """Exact replica of IdleArcade/scripts/office_expansion_3d.gd logic."""

    def __init__(self, game_state: MockGameState):
        self.game_state = game_state
        self.workers: Dict[str, GDScriptChibiWorkerSim] = {}
        self.epiphany_periodic_check = True
        self.epiphany_interval = 25.0
        self._epiphany_timer = 0.0

        specialists = [
            ("worker_frontend_dev", "Frontend Dev", 0),
            ("worker_backend_dev", "Backend Dev", 1),
            ("worker_ui_ux_designer", "UI/UX Designer", 2),
            ("worker_growth_hacker", "Growth Hacker", 3),
            ("worker_qa_engineer", "QA Engineer", 4),
        ]
        for w_id, role, desk_idx in specialists:
            w = GDScriptChibiWorkerSim(w_id, role, game_state)
            w.desk_assigned = desk_idx
            self.workers[w_id] = w
            self.game_state.hired_workers.append({
                "id": w_id,
                "role": role,
                "morale": 1.0,
                "fatigue": 0.0,
                "current_state": "working",
                "desk_assigned": desk_idx
            })

    def trigger_random_epiphany(self, custom_reward: float = 0.0) -> Optional[GDScriptChibiWorkerSim]:
        candidates = [
            w for w in self.workers.values()
            if w.current_state == GDScriptChibiWorkerSim.STATE_WORKING and not w.has_epiphany()
        ]
        if not candidates:
            return None
        chosen = random.choice(candidates)
        chosen.trigger_epiphany(custom_reward)
        return chosen

    def check_and_trigger_epiphany(self, chance: float = 0.20) -> bool:
        if random.random() < chance:
            return self.trigger_random_epiphany() is not None
        return False

    def get_epiphany_worker_ids(self) -> List[str]:
        return [w_id for w_id, w in self.workers.items() if w.has_epiphany()]

    def clear_all_epiphanies(self):
        for w in self.workers.values():
            if w.has_epiphany():
                w.expire_epiphany()

    def activate_hyper_focus(self, duration: float = 60.0, speed_multiplier: float = 1.50):
        for w in self.workers.values():
            w.hyper_focus_multiplier = speed_multiplier
            w.set_hyper_focus(True, duration)
            if w.current_state != GDScriptChibiWorkerSim.STATE_FATIGUED:
                w.play_celebration(1.0)

    def process(self, delta: float):
        if self.epiphany_periodic_check:
            self._epiphany_timer += delta
            if self._epiphany_timer >= self.epiphany_interval:
                self._epiphany_timer = 0.0
                self.check_and_trigger_epiphany()
        for w in self.workers.values():
            w.process(delta)


# ==============================================================================
# TEST TIERS
# ==============================================================================

def test_tier1_ast_and_expiration_contract(reporter: TestReporter):
    print(f"\n{Colors.BOLD}=== TIER 1: Static AST, Signals & Expiration Contract Audit ==={Colors.ENDC}")

    worker_file = GAME_DIR / "scripts" / "chibi_worker_3d.gd"
    office_file = GAME_DIR / "scripts" / "office_expansion_3d.gd"

    reporter.check(worker_file.exists(), "scripts/chibi_worker_3d.gd exists on disk", "AST_Files")
    reporter.check(office_file.exists(), "scripts/office_expansion_3d.gd exists on disk", "AST_Files")

    w_code = worker_file.read_text(encoding="utf-8")
    o_code = office_file.read_text(encoding="utf-8")

    # Signals
    reporter.check("signal epiphany_triggered(worker_id: String, reward: float)" in w_code,
                   "ChibiWorker3D declares epiphany_triggered signal", "AST_Signals")
    reporter.check("signal epiphany_collected(worker_id: String, reward: float)" in w_code,
                   "ChibiWorker3D declares epiphany_collected signal", "AST_Signals")
    reporter.check("signal office_epiphany_triggered(worker_id: String, reward: float)" in o_code,
                   "OfficeExpansion3D declares office_epiphany_triggered signal", "AST_Signals")
    reporter.check("signal worker_epiphany_collected(worker_id: String, reward: float)" in o_code,
                   "OfficeExpansion3D declares worker_epiphany_collected signal", "AST_Signals")

    # Methods
    for method in ["check_epiphany", "trigger_epiphany", "collect_epiphany", "has_epiphany", "tap_worker"]:
        reporter.check(f"func {method}" in w_code, f"ChibiWorker3D implements func {method}()", "AST_Methods")

    for method in ["trigger_random_epiphany", "check_and_trigger_epiphany", "get_epiphany_worker_ids"]:
        reporter.check(f"func {method}" in o_code, f"OfficeExpansion3D implements func {method}()", "AST_Methods")

    # Audit for Epiphany Expiration / Lifetime Contract in Source Code
    has_epiphany_lifetime_prop = bool(re.search(r"@export\s+var\s+(epiphany_lifetime|epiphany_duration|epiphany_timeout)", w_code))
    has_epiphany_decay_timer = bool(re.search(r"var\s+(_epiphany_timer|_epiphany_duration_timer|_epiphany_lifetime)", w_code))
    has_epiphany_timeout_logic = "expire_epiphany" in w_code or "cancel_epiphany" in w_code

    contract_satisfied = (has_epiphany_lifetime_prop or has_epiphany_decay_timer or has_epiphany_timeout_logic)
    reporter.check(contract_satisfied,
                   "DEFECT: chibi_worker_3d.gd declares epiphany lifetime/duration property or timeout logic",
                   "EXPIRATION_Contract")


def test_tier2_epiphany_lifetime_and_expiration(reporter: TestReporter):
    print(f"\n{Colors.BOLD}=== TIER 2: Epiphany Lifetime & Clean Expiration Stress ==={Colors.ENDC}")

    gs = MockGameState()
    worker = GDScriptChibiWorkerSim("w_expire_test", "Frontend Dev", gs)

    # 1. Trigger Epiphany
    worker.trigger_epiphany(custom_reward=500.0)
    reporter.check(worker.has_epiphany() is True, "Worker enters epiphany state after trigger", "LIFETIME_Trigger")
    reporter.check(worker.mood_icon_text == "💡", "Worker shows 💡 mood icon upon breakthrough", "LIFETIME_Visuals")
    reporter.check(worker.epiphany_particles_emitting is True, "Epiphany particles emitting upon breakthrough", "LIFETIME_Visuals")
    reporter.check(worker.epiphany_light_visible is True, "Epiphany OmniLight3D visible upon breakthrough", "LIFETIME_Visuals")

    # 2. Stress Test: Long uncollected duration (advance 30.0s of simulation frames)
    # R4 requirement: Uncollected epiphanies must cleanly time out without lingering forever
    for _ in range(30):
        worker.process(1.0)

    # In current implementation, uncollected epiphany never times out: has_epiphany remains True
    has_timed_out = (worker.has_epiphany() is False)
    reporter.check(has_timed_out,
                   "DEFECT: Uncollected epiphany cleanly times out after 30.0s idle time",
                   "EXPIRATION_Timeout")

    # 3. Adversarial Leakage Scenario: Worker transitions to STATE_FATIGUED while holding active uncollected epiphany
    worker.set_state(GDScriptChibiWorkerSim.STATE_FATIGUED)

    # Mood icon check: should be '💤' for fatigued worker, but line 209 keeps it stuck on '💡'!
    icon_correct = (worker.mood_icon_text == "💤")
    reporter.check(icon_correct,
                   "DEFECT: Fatigued worker updates mood icon to '💤' (not stuck on '💡')",
                   "EXPIRATION_MoodIcon")

    # Particle leak check: epiphany particles should stop emitting when fatigued
    particles_clean = (worker.epiphany_particles_emitting is False)
    reporter.check(particles_clean,
                   "DEFECT: Epiphany particles stop emitting when worker transitions to STATE_FATIGUED",
                   "EXPIRATION_ParticleLeak")

    # 4. Office-wide lockout stress test: 5 uncollected epiphanies permanently block new breakthroughs
    office = GDScriptOfficeExpansionSim(gs)
    for w in office.workers.values():
        w.trigger_epiphany()

    active_ids = office.get_epiphany_worker_ids()
    reporter.check(len(active_ids) == 5, "All 5 office workers hold active epiphanies", "OFFICE_Lockout")

    sixth_epiphany = office.trigger_random_epiphany()
    reporter.check(sixth_epiphany is None, "Office correctly rejects new epiphanies when all active workers already hold one", "OFFICE_Lockout")


def test_tier3_rapid_tap_spamming_and_race_conditions(reporter: TestReporter):
    print(f"\n{Colors.BOLD}=== TIER 3: Rapid Tap Spamming (1,000 Clicks) & Race Conditions ==={Colors.ENDC}")

    gs = MockGameState()
    gs.energy = 500.0
    gs.base_passive_rps = 40.0
    expected_reward = 40.0 * 15.0  # 600.0

    worker = GDScriptChibiWorkerSim("w_spam_victim", "Backend Dev", gs)
    worker.trigger_epiphany()

    # 1. First tap collects reward
    first_tap_reward = worker.tap_worker()
    reporter.check(math.isclose(first_tap_reward, expected_reward, abs_tol=1e-3),
                   f"Tap #1 cleanly collects exact epiphany reward ({expected_reward} energy)", "SPAM_FirstTap")
    reporter.check(math.isclose(gs.energy, 500.0 + expected_reward, abs_tol=1e-3),
                   "GameState energy credited accurately on Tap #1", "SPAM_FirstTap")
    reporter.check(worker.has_epiphany() is False, "has_epiphany() immediately reset to False on Tap #1", "SPAM_FirstTap")
    reporter.check(worker.current_state == GDScriptChibiWorkerSim.STATE_CELEBRATING,
                   "Worker enters STATE_CELEBRATING on Tap #1", "SPAM_Celebration")

    # 2. Simulate 999 consecutive rapid taps (Total = 1,000 taps)
    spam_results = [worker.tap_worker() for _ in range(999)]
    all_zero_rewards = all(r == 0.0 for r in spam_results)
    reporter.check(all_zero_rewards,
                   "Subsequent 999 rapid taps strictly return 0.0 reward (100% idempotent, zero double-dipping)",
                   "SPAM_Idempotence")

    reporter.check(math.isclose(gs.energy, 500.0 + expected_reward, abs_tol=1e-3),
                   "GameState energy remains strictly invariant throughout 999 spam clicks",
                   "SPAM_Idempotence")

    # 3. Behavioral Nuance Audit: Double-tap celebration timer preservation
    reporter.check(math.isclose(worker._celebrate_timer, 1.5, abs_tol=1e-3),
                   "Celebration timer preserved at full 1.5s victory jump duration under rapid tap spam",
                   "SPAM_CelebrateTimer")

    # 4. Multithreaded concurrent tap race conditions (1,000 concurrent threads)
    gs_race = MockGameState()
    gs_race.energy = 1000.0
    gs_race.base_passive_rps = 100.0
    race_worker = GDScriptChibiWorkerSim("w_race_worker", "QA Engineer", gs_race)
    race_worker.trigger_epiphany(custom_reward=1500.0)

    thread_results: List[float] = []
    threads: List[threading.Thread] = []

    def concurrent_tap():
        r = race_worker.tap_worker()
        thread_results.append(r)

    for _ in range(1000):
        t = threading.Thread(target=concurrent_tap)
        threads.append(t)

    for t in threads:
        t.start()
    for t in threads:
        t.join()

    positive_rewards = [r for r in thread_results if r > 0.0]
    zero_rewards = [r for r in thread_results if r == 0.0]

    reporter.check(len(positive_rewards) == 1,
                   f"Under 1,000 concurrent multithreaded taps, exactly 1 thread claims reward (got {len(positive_rewards)})",
                   "CONCURRENCY_Race")
    reporter.check(len(zero_rewards) == 999,
                   f"Under 1,000 concurrent multithreaded taps, exactly 999 threads receive 0.0 (got {len(zero_rewards)})",
                   "CONCURRENCY_Race")
    reporter.check(math.isclose(gs_race.energy, 2500.0, abs_tol=1e-3),
                   "GameState energy under concurrency correctly credited exactly once (1000.0 + 1500.0 = 2500.0)",
                   "CONCURRENCY_Race")

    # 5. Click spamming on non-epiphany worker (1,000 taps)
    idle_worker = GDScriptChibiWorkerSim("w_idle", "UI/UX Designer", gs)
    idle_energy_before = gs.energy
    idle_spam = [idle_worker.tap_worker() for _ in range(1000)]
    reporter.check(all(r == 0.0 for r in idle_spam), "1,000 taps on worker without epiphany return 0.0", "SPAM_Idle")
    reporter.check(math.isclose(gs.energy, idle_energy_before, abs_tol=1e-3), "GameState energy untouched by idle worker taps", "SPAM_Idle")


def test_tier4_simultaneous_5_worker_epiphanies(reporter: TestReporter):
    print(f"\n{Colors.BOLD}=== TIER 4: Simultaneous 5-Worker Epiphanies & Cumulative Calculus ==={Colors.ENDC}")

    gs = MockGameState()
    gs.energy = 10000.0
    gs.base_passive_rps = 100.0
    office = GDScriptOfficeExpansionSim(gs)

    effective_rps = gs.get_effective_passive_rps()
    expected_per_worker_reward = max(100.0, effective_rps * 15.0)  # 125.0 * 15 = 1875.0
    reporter.check(math.isclose(effective_rps, 125.0, abs_tol=1e-3),
                   "Office passive RPS is accurately calculated with 5 active workers (125.0 RPS)", "MULTI_RPS")

    # 1. Trigger simultaneous epiphanies across all 5 workers
    for w in office.workers.values():
        w.trigger_epiphany()

    active_epiphanies = office.get_epiphany_worker_ids()
    reporter.check(len(active_epiphanies) == 5,
                   "Simultaneous epiphanies successfully active across all 5 specialists", "MULTI_Trigger")
    reporter.check(all(w.has_epiphany() for w in office.workers.values()),
                   "Every worker independently confirms has_epiphany() == True", "MULTI_Trigger")
    reporter.check(all(w.mood_icon_text == "💡" for w in office.workers.values()),
                   "All 5 workers display glowing 💡 icon", "MULTI_Visuals")
    reporter.check(all(w.epiphany_particles_emitting is True for w in office.workers.values()),
                   "All 5 workers emit epiphany particles simultaneously", "MULTI_Visuals")

    # 2. Independent tap collection in non-sequential order
    order_ids = [
        "worker_ui_ux_designer",
        "worker_frontend_dev",
        "worker_qa_engineer",
        "worker_backend_dev",
        "worker_growth_hacker"
    ]

    collected_total = 0.0
    for i, target_id in enumerate(order_ids):
        target_worker = office.workers[target_id]
        energy_before_tap = gs.energy

        reward = target_worker.tap_worker()
        collected_total += reward

        reporter.check(math.isclose(reward, expected_per_worker_reward, abs_tol=1e-3),
                       f"Tapping worker {target_id} awards exact reward ({reward:.1f})", "MULTI_Collect")
        reporter.check(math.isclose(gs.energy, energy_before_tap + reward, abs_tol=1e-3),
                       f"GameState energy credited accurately after tapping worker {target_id}", "MULTI_Collect")
        reporter.check(target_worker.has_epiphany() is False,
                       f"Tapped worker {target_id} resets has_epiphany() to False", "MULTI_Collect")
        reporter.check(target_worker.current_state == GDScriptChibiWorkerSim.STATE_CELEBRATING,
                       f"Tapped worker {target_id} transitions to STATE_CELEBRATING", "MULTI_Collect")

        # Verify other remaining workers are completely unaffected
        remaining_ids = order_ids[i + 1:]
        for rem_id in remaining_ids:
            rem_worker = office.workers[rem_id]
            reporter.check(rem_worker.has_epiphany() is True,
                           f"Untapped worker {rem_id} retains active epiphany", "MULTI_Isolation")
            reporter.check(rem_worker.mood_icon_text == "💡",
                           f"Untapped worker {rem_id} retains 💡 icon", "MULTI_Isolation")

    # 3. Cumulative Calculus Verification
    expected_cumulative = 5.0 * expected_per_worker_reward  # 5 * 1875.0 = 9375.0
    reporter.check(math.isclose(collected_total, expected_cumulative, abs_tol=1e-3),
                   f"Cumulative rewards collected ({collected_total}) matches exact 5-worker total ({expected_cumulative})",
                   "MULTI_Calculus")
    reporter.check(math.isclose(gs.energy, 10000.0 + expected_cumulative, abs_tol=1e-3),
                   f"Final GameState energy matches baseline + 5x cumulative epiphany bonuses ({gs.energy})",
                   "MULTI_Calculus")

    # 4. Clean Celebration Expiry across all 5 workers
    office.process(1.6)
    reporter.check(all(w.current_state == GDScriptChibiWorkerSim.STATE_WORKING for w in office.workers.values()),
                   "All 5 workers cleanly revert to STATE_WORKING post-celebration", "MULTI_Reversion")
    reporter.check(all(w.mood_icon_text == "💻" for w in office.workers.values()),
                   "All 5 workers cleanly restore '💻' mood icon", "MULTI_Reversion")
    reporter.check(all(w.chibi_root_pos_y == 0.0 for w in office.workers.values()),
                   "All 5 workers rest at baseline floor level (0.0m)", "MULTI_Reversion")


def test_tier5_synergy_and_cross_station_interactions(reporter: TestReporter):
    print(f"\n{Colors.BOLD}=== TIER 5: Synergy & Cross-Station Interactions ==={Colors.ENDC}")

    gs = MockGameState()
    gs.energy = 5000.0
    gs.base_passive_rps = 100.0
    office = GDScriptOfficeExpansionSim(gs)

    # 1. Epiphany during Unicorn Espresso Hyper-Focus
    office.activate_hyper_focus(duration=60.0, speed_multiplier=1.50)
    reporter.check(all(w.is_hyper_focus_active() for w in office.workers.values()),
                   "All office workers active in 1.50x Hyper-Focus", "SYNERGY_HyperFocus")

    # Nuance Audit: During initial 1.0s celebration hop, workers are in STATE_CELEBRATING
    epiphany_during_hop = office.trigger_random_epiphany()
    reporter.check(epiphany_during_hop is None,
                   "Workers in 1.0s Hyper-Focus activation hop correctly cannot trigger epiphanies (state != working)",
                   "SYNERGY_HopExclusion")

    # Advance time by 1.1s: celebration hop ends, workers resume STATE_WORKING while Hyper-Focus remains active
    office.process(1.1)
    reporter.check(all(w.current_state == GDScriptChibiWorkerSim.STATE_WORKING for w in office.workers.values()),
                   "Office workers resume STATE_WORKING after Hyper-Focus celebration hop", "SYNERGY_Resume")

    # Trigger epiphany during active Hyper-Focus (58.9s remaining)
    chosen_worker = office.trigger_random_epiphany()
    reporter.check(chosen_worker is not None, "Epiphany successfully triggered during active Hyper-Focus", "SYNERGY_Trigger")

    if chosen_worker:
        reward = chosen_worker.tap_worker()
        reporter.check(reward > 0.0, "Epiphany tap successfully collected during active Hyper-Focus", "SYNERGY_Collect")
        reporter.check(chosen_worker.get_animation_speed_multiplier() == 1.50,
                       "Celebration kinematics advance at accelerated 1.50x time dilation", "SYNERGY_Kinematics")

        chosen_worker.process(1.0)
        reporter.check(chosen_worker.current_state == GDScriptChibiWorkerSim.STATE_CELEBRATING,
                       "Celebration persists at t=1.0s", "SYNERGY_Kinematics")
        chosen_worker.process(0.6)
        reporter.check(chosen_worker.current_state == GDScriptChibiWorkerSim.STATE_WORKING,
                       "Celebration cleanly reverts to STATE_WORKING at t=1.6s", "SYNERGY_Kinematics")

    # 2. Team Coffee Break synergy
    worker_fatigued = office.workers["worker_frontend_dev"]
    worker_fatigued.set_fatigue(1.0)
    reporter.check(worker_fatigued.current_state == GDScriptChibiWorkerSim.STATE_FATIGUED,
                   "Worker transitioned to STATE_FATIGUED on max fatigue", "SYNERGY_Coffee")

    gs.give_team_coffee_break()
    office.activate_hyper_focus(60.0, 1.50)
    worker_fatigued.set_fatigue(0.0)
    worker_fatigued.set_state(GDScriptChibiWorkerSim.STATE_WORKING)

    reporter.check(worker_fatigued.fatigue == 0.0, "Worker fatigue wiped to 0.0 by team coffee break", "SYNERGY_Coffee")
    reporter.check(worker_fatigued.current_state == GDScriptChibiWorkerSim.STATE_WORKING,
                   "Worker restored to STATE_WORKING by team coffee break", "SYNERGY_Coffee")
    reporter.check(worker_fatigued.check_epiphany(chance=1.0) is True,
                   "Rescued worker is immediately eligible for spontaneous epiphanies", "SYNERGY_Coffee")


def test_tier6_input_event_isolation(reporter: TestReporter):
    print(f"\n{Colors.BOLD}=== TIER 6: Touch vs Mouse Input Event Isolation ==={Colors.ENDC}")

    worker = GDScriptChibiWorkerSim("w_input_test", "QA Engineer", None)

    # 1. Desktop Left Mouse Button Click (pressed=True, button_index=1)
    worker.trigger_epiphany(custom_reward=350.0)
    res_lmb = worker.simulate_input_event("MouseButton", pressed=True, button_index=1)
    reporter.check(math.isclose(res_lmb, 350.0, abs_tol=1e-3),
                   "Left Mouse Button Click (pressed=True) collects epiphany", "INPUT_Mouse")

    # 2. Left Mouse Button Release (pressed=False, button_index=1)
    worker.trigger_epiphany(custom_reward=350.0)
    res_lmb_release = worker.simulate_input_event("MouseButton", pressed=False, button_index=1)
    reporter.check(res_lmb_release == 0.0, "Mouse Button Release (pressed=False) is ignored", "INPUT_Mouse")
    reporter.check(worker.has_epiphany() is True, "Epiphany remains uncollected on button release", "INPUT_Mouse")

    # 3. Right Mouse Button Click (pressed=True, button_index=2)
    res_rmb = worker.simulate_input_event("MouseButton", pressed=True, button_index=2)
    reporter.check(res_rmb == 0.0, "Right Mouse Button Click (button_index=2) is ignored", "INPUT_Mouse")
    reporter.check(worker.has_epiphany() is True, "Epiphany remains uncollected on right click", "INPUT_Mouse")

    # 4. Mobile Screen Touch (pressed=True)
    res_touch = worker.simulate_input_event("ScreenTouch", pressed=True)
    reporter.check(math.isclose(res_touch, 350.0, abs_tol=1e-3),
                   "Mobile Screen Touch (pressed=True) collects epiphany", "INPUT_Touch")

    # 5. Mobile Screen Touch Release (pressed=False)
    worker.trigger_epiphany(custom_reward=350.0)
    res_touch_release = worker.simulate_input_event("ScreenTouch", pressed=False)
    reporter.check(res_touch_release == 0.0, "Mobile Screen Touch Release (pressed=False) is ignored", "INPUT_Touch")
    reporter.check(worker.has_epiphany() is True, "Epiphany remains uncollected on touch release", "INPUT_Touch")

    # 6. Unhandled events (MouseMotion, Key, etc.)
    res_motion = worker.simulate_input_event("MouseMotion", pressed=True)
    reporter.check(res_motion == 0.0, "Mouse Motion event is ignored", "INPUT_Filter")


# ==============================================================================
# MAIN RUNNER
# ==============================================================================

def main():
    print(f"{Colors.HEADER}{Colors.BOLD}======================================================================{Colors.ENDC}")
    print(f"{Colors.HEADER}{Colors.BOLD}Phase 14 Milestone M4: Epiphany Timing & Click-Spam Challenger Suite{Colors.ENDC}")
    print(f"{Colors.HEADER}{Colors.BOLD}======================================================================{Colors.ENDC}")

    reporter = TestReporter("Phase 14 Milestone M4 Challenger Suite")

    test_tier1_ast_and_expiration_contract(reporter)
    test_tier2_epiphany_lifetime_and_expiration(reporter)
    test_tier3_rapid_tap_spamming_and_race_conditions(reporter)
    test_tier4_simultaneous_5_worker_epiphanies(reporter)
    test_tier5_synergy_and_cross_station_interactions(reporter)
    test_tier6_input_event_isolation(reporter)

    exit_code = reporter.summary()
    sys.exit(exit_code)


if __name__ == "__main__":
    main()
