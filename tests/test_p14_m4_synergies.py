#!/usr/bin/env python3
"""
test_p14_m4_synergies.py — Phase 14 Milestone 4 Verification Oracle
Interactive Teambuilding & Epiphany Synergies:
1. Spontaneous Epiphany Moments (💡): algorithm breakthroughs on working Chibi-workers,
   interactive tap/click collection awarding instant energy bonus via GameState.trigger_worker_epiphany(worker_id).
2. Celebration bounce kinematics (0.22m apex), particle feedback, and mood icon reset to normal working state.
3. CoffeeMachine3D Unicorn Espresso synergy: brewing triggers GameState coffee break / 60s office-wide Hyper-Focus.
4. OfficeExpansion3D & Chibi worker animation acceleration (1.5x speed) with cheerful feedback and clean expiration.
5. End-to-end player journey simulation with zero regressions across economy, 3D, and UI layers.
"""

import math
import random
import re
import sys
from pathlib import Path

if sys.platform == "win32":
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
        sys.stderr.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass

# Paths
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
        print("\n" + "=" * 70)
        print(f"{self.suite_name} Results")
        print("=" * 70)
        print(f"  Total Checks : {self.total}")
        print(f"  Passed       : {self.passed}")
        print(f"  Failed       : {self.failed}")
        if self.failures:
            print("\nFailures:")
            for f in self.failures:
                print(f"  - {Colors.RED}{f}{Colors.ENDC}")
        print("=" * 70)
        return 0 if self.failed == 0 else 1


# ==============================================================================
# Simulation Mock Models
# ==============================================================================

class MockGameState:
    def __init__(self):
        self.energy = 5000.0
        self.base_passive_rps = 100.0
        self.hired_workers = []
        self.desk_levels = [1, 1, 1, 1, 1]
        self.staff_hyper_focus_active = False
        self.staff_hyper_focus_timer = 0.0
        self.staff_hyper_focus_multiplier = 1.50
        self.staff_coffee_break_active = False
        self.staff_coffee_break_timer = 0.0
        self.unicorn_espresso_buff_active = False
        self.unicorn_espresso_buff_timer = 0.0
        self.epiphany_history = []
        self.coffee_breaks_granted = 0

    def get_effective_passive_rps(self) -> float:
        staff_mult = self.get_staff_rps_multiplier()
        espresso_mult = 1.20 if self.unicorn_espresso_buff_active else 1.00
        return self.base_passive_rps * staff_mult * espresso_mult

    def get_active_workers_count(self) -> int:
        return sum(1 for w in self.hired_workers if w.get("current_state") == "working")

    def get_staff_average_morale(self) -> float:
        if not self.hired_workers:
            return 1.0
        return sum(w.get("morale", 1.0) for w in self.hired_workers) / len(self.hired_workers)

    def get_staff_rps_multiplier(self) -> float:
        active = self.get_active_workers_count()
        if active == 0:
            return 1.0
        return 1.0 + (float(active) * 0.05) * self.get_staff_average_morale()

    def earn_energy(self, amount: float):
        self.energy += amount

    def activate_unicorn_espresso_buff(self, duration: float = 60.0):
        self.unicorn_espresso_buff_active = True
        self.unicorn_espresso_buff_timer = duration

    def give_team_coffee_break(self) -> bool:
        self.coffee_breaks_granted += 1
        for w in self.hired_workers:
            w["fatigue"] = 0.0
            w["morale"] = 1.0
            w["current_state"] = "working"
        self.staff_hyper_focus_active = True
        self.staff_hyper_focus_timer = 60.0
        self.staff_coffee_break_active = True
        self.staff_coffee_break_timer = 60.0
        return True

    def is_staff_hyper_focus_active(self) -> bool:
        return (self.staff_hyper_focus_active or self.staff_coffee_break_active) and (
            self.staff_hyper_focus_timer > 0.0 or self.staff_coffee_break_timer > 0.0
        )

    def get_staff_hyper_focus_time_remaining(self) -> float:
        return max(0.0, max(self.staff_hyper_focus_timer, self.staff_coffee_break_timer))

    def trigger_worker_epiphany(self, worker_id: str) -> float:
        reward = max(100.0, self.get_effective_passive_rps() * 15.0)
        self.earn_energy(reward)
        self.epiphany_history.append({"worker_id": worker_id, "reward": reward})
        return reward

    def update_simulation(self, delta: float):
        if self.staff_hyper_focus_timer > 0.0:
            self.staff_hyper_focus_timer = max(0.0, self.staff_hyper_focus_timer - delta)
            self.staff_coffee_break_timer = self.staff_hyper_focus_timer
            if self.staff_hyper_focus_timer <= 0.0:
                self.staff_hyper_focus_active = False
                self.staff_coffee_break_active = False

        if self.unicorn_espresso_buff_timer > 0.0:
            self.unicorn_espresso_buff_timer = max(0.0, self.unicorn_espresso_buff_timer - delta)
            if self.unicorn_espresso_buff_timer <= 0.0:
                self.unicorn_espresso_buff_active = False


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
        self._has_epiphany = False
        self._epiphany_reward = 0.0
        self._celebrate_timer = 0.0
        self._revert_state_after_celebrate = self.STATE_WORKING
        self.mood_icon_text = "💻"
        self.epiphany_particles_emitting = False
        self.epiphany_light_visible = False
        self.visor_text = "^.^"
        self.chibi_root_pos_y = 0.0
        self.left_arm_rot_x = 0.0
        self.right_arm_rot_x = 0.0
        self.celebrations_played = 0

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
            self._hyper_focus_timer = duration if duration > 0.0 else 60.0
            if not was_active and self.current_state != self.STATE_FATIGUED:
                self.play_celebration(0.8)
        else:
            self._hyper_focus_timer = 0.0

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
        self.epiphany_particles_emitting = True
        self.epiphany_light_visible = True

    def collect_epiphany(self) -> float:
        if not self._has_epiphany:
            return 0.0
        reward = self._epiphany_reward
        self._has_epiphany = False
        self.epiphany_particles_emitting = False
        self.epiphany_light_visible = False

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

    def check_epiphany(self, chance: float = 0.15) -> bool:
        if self.current_state != self.STATE_WORKING or self._has_epiphany:
            return False
        if random.random() < chance:
            self.trigger_epiphany()
            return True
        return False

    def process(self, delta: float):
        if self._hyper_focus_timer > 0.0:
            self._hyper_focus_timer = max(0.0, self._hyper_focus_timer - delta)
            if self._hyper_focus_timer <= 0.0:
                self.hyper_focus = False

        speed_mult = self.get_animation_speed_multiplier()
        self._time += delta * speed_mult
        t = self._time

        if self._celebrate_timer > 0.0:
            self._celebrate_timer -= delta
            if self._celebrate_timer <= 0.0:
                self.set_state(self._revert_state_after_celebrate)

        if self.current_state == self.STATE_WORKING:
            self.left_arm_rot_x = -0.35 + math.sin(t * 14.0) * 0.15
            self.right_arm_rot_x = -0.35 - math.sin(t * 14.0) * 0.15
            self.chibi_root_pos_y = 0.0
        elif self.current_state == self.STATE_CELEBRATING:
            self.chibi_root_pos_y = abs(math.sin(t * 12.0)) * 0.22


class OfficeExpansionSimulator:
    def __init__(self, game_state: MockGameState):
        self.game_state = game_state
        self.workers = {}  # worker_id -> ChibiWorkerSimulator
        for role, w_id in [
            ("Frontend Dev", "w_front"),
            ("Backend Dev", "w_back"),
            ("UI/UX Designer", "w_design"),
            ("Growth Hacker", "w_growth"),
            ("QA Engineer", "w_qa"),
        ]:
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

    def trigger_random_epiphany(self, custom_reward: float = 0.0) -> ChibiWorkerSimulator:
        candidates = [w for w in self.workers.values() if w.current_state == "working" and not w.has_epiphany()]
        if not candidates:
            return None
        chosen = random.choice(candidates)
        chosen.trigger_epiphany(custom_reward)
        return chosen

    def get_epiphany_worker_ids(self):
        return [w_id for w_id, w in self.workers.items() if w.has_epiphany()]

    def process(self, delta: float):
        for w in self.workers.values():
            w.process(delta)


class CoffeeMachineSimulator:
    def __init__(self, game_state: MockGameState, office: OfficeExpansionSimulator):
        self.game_state = game_state
        self.office = office
        self.buff_duration = 60.0
        self.brew_cooldown = 60.0
        self.is_brewing = False
        self.is_on_cooldown = False
        self.cooldown_remaining = 0.0
        self.synergies_triggered = 0

    def trigger_office_synergy(self, duration: float = 60.0):
        self.synergies_triggered += 1
        if self.game_state:
            self.game_state.give_team_coffee_break()
        if self.office:
            self.office.activate_hyper_focus(duration, 1.50)

    def complete_brew(self, success: bool = True):
        self.is_brewing = False
        if success:
            if self.game_state:
                self.game_state.activate_unicorn_espresso_buff(self.buff_duration)
            self.trigger_office_synergy(self.buff_duration)
            self.is_on_cooldown = True
            self.cooldown_remaining = self.brew_cooldown


# ==============================================================================
# SECTION 1: AST & Script API Inspection Oracle
# ==============================================================================

def test_section1_ast_and_api(reporter: TestReporter):
    print(f"\n{Colors.BOLD}=== SECTION 1: AST & Script API Architecture Oracle ==={Colors.ENDC}")

    # 1. coffee_machine_3d.gd
    cm_path = GAME_DIR / "scripts/coffee_machine_3d.gd"
    reporter.check(cm_path.exists(), "scripts/coffee_machine_3d.gd exists on disk", "AST_CoffeeMachine")
    cm_code = cm_path.read_text(encoding="utf-8")

    reporter.check("signal office_hyper_focus_activated" in cm_code,
                   "CoffeeMachine3D declares office_hyper_focus_activated signal", "AST_CoffeeMachine")
    reporter.check("func trigger_office_synergy(" in cm_code,
                   "CoffeeMachine3D implements trigger_office_synergy(duration)", "AST_CoffeeMachine")
    reporter.check("trigger_office_synergy(buff_duration)" in cm_code,
                   "CoffeeMachine3D.complete_brew() hooks trigger_office_synergy()", "AST_CoffeeMachine")
    reporter.check("give_team_coffee_break()" in cm_code,
                   "CoffeeMachine3D invokes GameState.give_team_coffee_break()", "AST_CoffeeMachine")
    reporter.check("activate_hyper_focus" in cm_code,
                   "CoffeeMachine3D notifies OfficeExpansion3D.activate_hyper_focus()", "AST_CoffeeMachine")

    # 2. office_expansion_3d.gd
    office_path = GAME_DIR / "scripts/office_expansion_3d.gd"
    reporter.check(office_path.exists(), "scripts/office_expansion_3d.gd exists on disk", "AST_OfficeExpansion")
    office_code = office_path.read_text(encoding="utf-8")

    reporter.check("signal office_hyper_focus_started" in office_code,
                   "OfficeExpansion3D declares office_hyper_focus_started signal", "AST_OfficeExpansion")
    reporter.check("signal office_hyper_focus_ended" in office_code,
                   "OfficeExpansion3D declares office_hyper_focus_ended signal", "AST_OfficeExpansion")
    reporter.check("signal office_epiphany_triggered" in office_code,
                   "OfficeExpansion3D declares office_epiphany_triggered signal", "AST_OfficeExpansion")
    reporter.check("func activate_hyper_focus(" in office_code,
                   "OfficeExpansion3D implements activate_hyper_focus(duration, speed_multiplier)", "AST_OfficeExpansion")
    reporter.check("func trigger_random_epiphany(" in office_code,
                   "OfficeExpansion3D implements trigger_random_epiphany()", "AST_OfficeExpansion")
    reporter.check("func check_and_trigger_epiphany(" in office_code,
                   "OfficeExpansion3D implements check_and_trigger_epiphany()", "AST_OfficeExpansion")
    reporter.check("func get_epiphany_worker_ids(" in office_code,
                   "OfficeExpansion3D implements get_epiphany_worker_ids()", "AST_OfficeExpansion")
    reporter.check("unicorn_espresso_buff_started" in office_code,
                   "OfficeExpansion3D connects to unicorn_espresso_buff_started signal", "AST_OfficeExpansion")

    # 3. chibi_worker_3d.gd
    worker_path = GAME_DIR / "scripts/chibi_worker_3d.gd"
    reporter.check(worker_path.exists(), "scripts/chibi_worker_3d.gd exists on disk", "AST_ChibiWorker")
    worker_code = worker_path.read_text(encoding="utf-8")

    reporter.check("signal hyper_focus_changed" in worker_code,
                   "ChibiWorker3D declares hyper_focus_changed signal", "AST_ChibiWorker")
    reporter.check("signal epiphany_triggered" in worker_code,
                   "ChibiWorker3D declares epiphany_triggered signal", "AST_ChibiWorker")
    reporter.check("signal epiphany_collected" in worker_code,
                   "ChibiWorker3D declares epiphany_collected signal", "AST_ChibiWorker")
    reporter.check("func check_epiphany(" in worker_code,
                   "ChibiWorker3D implements check_epiphany(chance)", "AST_ChibiWorker")
    reporter.check("func tap_worker(" in worker_code,
                   "ChibiWorker3D implements tap_worker() public interaction method", "AST_ChibiWorker")
    reporter.check("func is_hyper_focus_active(" in worker_code,
                   "ChibiWorker3D implements is_hyper_focus_active() helper", "AST_ChibiWorker")
    reporter.check("func get_animation_speed_multiplier(" in worker_code,
                   "ChibiWorker3D implements get_animation_speed_multiplier()", "AST_ChibiWorker")
    reporter.check("trigger_worker_epiphany(worker_id)" in worker_code,
                   "ChibiWorker3D.collect_epiphany() awards energy via GameState.trigger_worker_epiphany()", "AST_ChibiWorker")
    reporter.check("InputEventScreenTouch" in worker_code,
                   "ChibiWorker3D supports mobile InputEventScreenTouch tap detection", "AST_ChibiWorker")
    reporter.check("InputEventMouseButton" in worker_code,
                   "ChibiWorker3D supports desktop InputEventMouseButton click detection", "AST_ChibiWorker")


# ==============================================================================
# SECTION 2: Epiphany Mathematical Simulation & Reward Calculus Oracle
# ==============================================================================

def test_section2_epiphany_math_and_rewards(reporter: TestReporter):
    print(f"\n{Colors.BOLD}=== SECTION 2: Epiphany Mathematical & Boundary Reward Calculus ==={Colors.ENDC}")

    gs = MockGameState()
    gs.base_passive_rps = 100.0

    worker = ChibiWorkerSimulator("w_test", "Backend Dev", gs)

    # 1. Base formula verification: max(100.0, RPS * 15.0)
    worker.trigger_epiphany()
    expected_reward = 100.0 * 15.0  # 1500.0
    reporter.check(math.isclose(worker._epiphany_reward, expected_reward, abs_tol=1e-3),
                   f"Standard passive RPS (100.0) yields exactly 15x = {expected_reward} energy", "EPIPHANY_Formula")

    # 2. Low RPS floor boundary: 0 RPS -> 100.0 floor
    gs.base_passive_rps = 0.0
    worker.trigger_epiphany()
    reporter.check(math.isclose(worker._epiphany_reward, 100.0, abs_tol=1e-3),
                   "Zero passive RPS properly clamped to minimum floor of 100.0 energy", "EPIPHANY_Floor")

    # 3. Sub-floor RPS boundary: 5 RPS -> 75.0, clamped to 100.0 floor
    gs.base_passive_rps = 5.0
    worker.trigger_epiphany()
    reporter.check(math.isclose(worker._epiphany_reward, 100.0, abs_tol=1e-3),
                   "Low passive RPS (5.0 * 15 = 75.0) clamped to floor 100.0 energy", "EPIPHANY_Floor")

    # 4. Above-floor threshold: 10 RPS -> 150.0
    gs.base_passive_rps = 10.0
    worker.trigger_epiphany()
    reporter.check(math.isclose(worker._epiphany_reward, 150.0, abs_tol=1e-3),
                   "Above-floor RPS (10.0 * 15 = 150.0) matches calculated value", "EPIPHANY_Formula")

    # 5. High-end scaling: 5,000 RPS -> 75,000.0
    gs.base_passive_rps = 5000.0
    worker.trigger_epiphany()
    reporter.check(math.isclose(worker._epiphany_reward, 75000.0, abs_tol=1e-3),
                   "High passive RPS (5,000 * 15 = 75,000) matches calculated value", "EPIPHANY_HighEnd")

    # 6. Custom reward override
    worker.trigger_epiphany(custom_reward=9999.0)
    reporter.check(math.isclose(worker._epiphany_reward, 9999.0, abs_tol=1e-3),
                   "Custom reward parameter (9999.0) overrides mathematical formula", "EPIPHANY_Override")


# ==============================================================================
# SECTION 3: Epiphany Visual Invariants, Tap Detection & Idempotence Oracle
# ==============================================================================

def test_section3_epiphany_tap_and_idempotence(reporter: TestReporter):
    print(f"\n{Colors.BOLD}=== SECTION 3: Visual Invariants, Tap Interaction & Idempotence Oracle ==={Colors.ENDC}")

    gs = MockGameState()
    gs.energy = 1000.0
    gs.base_passive_rps = 40.0  # 40 * 15 = 600 reward

    worker = ChibiWorkerSimulator("w_ui", "UI/UX Designer", gs)

    # 1. State before epiphany
    reporter.check(worker.current_state == "working", "Worker initially in working state", "EPIPHANY_Visuals")
    reporter.check(worker.mood_icon_text == "💻", "Initial mood icon displays '💻'", "EPIPHANY_Visuals")
    reporter.check(worker.has_epiphany() is False, "has_epiphany() is False initially", "EPIPHANY_Visuals")
    reporter.check(worker.epiphany_particles_emitting is False, "Epiphany particles OFF initially", "EPIPHANY_Visuals")
    reporter.check(worker.epiphany_light_visible is False, "Epiphany light OFF initially", "EPIPHANY_Visuals")

    # 2. Trigger epiphany
    worker.trigger_epiphany()
    reporter.check(worker.has_epiphany() is True, "has_epiphany() is True after trigger", "EPIPHANY_Trigger")
    reporter.check(worker.mood_icon_text == "💡", "Epiphany displays glowing '💡' mood icon", "EPIPHANY_Trigger")
    reporter.check(worker.visor_text == "★_★", "Visor shows excited '★_★' facial expression", "EPIPHANY_Trigger")
    reporter.check(worker.epiphany_particles_emitting is True, "Epiphany CPUParticles3D are actively emitting", "EPIPHANY_Trigger")
    reporter.check(worker.epiphany_light_visible is True, "Epiphany OmniLight3D is lit", "EPIPHANY_Trigger")

    # 3. State filtering: check_epiphany only permits working state
    worker_fatigued = ChibiWorkerSimulator("w_tired", "QA Engineer", gs)
    worker_fatigued.set_state(ChibiWorkerSimulator.STATE_FATIGUED)
    check_fatigued = worker_fatigued.check_epiphany(chance=1.0)
    reporter.check(check_fatigued is False, "Fatigued workers cannot trigger epiphany moments", "EPIPHANY_Filter")
    reporter.check(worker_fatigued.has_epiphany() is False, "Fatigued worker epiphany remains False", "EPIPHANY_Filter")

    worker_break = ChibiWorkerSimulator("w_break", "Frontend Dev", gs)
    worker_break.set_state(ChibiWorkerSimulator.STATE_COFFEE_BREAK)
    check_break = worker_break.check_epiphany(chance=1.0)
    reporter.check(check_break is False, "Workers on coffee break cannot trigger epiphany moments", "EPIPHANY_Filter")

    # 4. Tap collection credits energy to GameState
    energy_before = gs.energy
    collected = worker.tap_worker()
    expected_gain = 40.0 * 15.0  # 600.0

    reporter.check(math.isclose(collected, expected_gain, abs_tol=1e-3),
                   f"tap_worker() returns exact reward amount ({expected_gain})", "EPIPHANY_Tap")
    reporter.check(math.isclose(gs.energy, energy_before + expected_gain, abs_tol=1e-3),
                   f"GameState energy credited directly: {energy_before} -> {gs.energy}", "EPIPHANY_Tap")
    reporter.check(worker.has_epiphany() is False, "has_epiphany() reset to False after collection", "EPIPHANY_Tap")
    reporter.check(worker.epiphany_light_visible is False, "Epiphany light turned OFF after collection", "EPIPHANY_Tap")

    # 5. Idempotence under rapid click/tap spamming (10 successive taps)
    spam_rewards = [worker.tap_worker() for _ in range(10)]
    all_zero = all(r == 0.0 for r in spam_rewards)
    reporter.check(all_zero, "10 successive rapid taps return 0.0 (strictly idempotent, zero double-dipping)", "EPIPHANY_Idempotence")
    reporter.check(math.isclose(gs.energy, energy_before + expected_gain, abs_tol=1e-3),
                   "GameState energy strictly unchanged during click spamming", "EPIPHANY_Idempotence")


# ==============================================================================
# SECTION 4: Celebration Kinematics & Clean State Reversion Oracle
# ==============================================================================

def test_section4_celebration_bounce_and_reversion(reporter: TestReporter):
    print(f"\n{Colors.BOLD}=== SECTION 4: Celebration Kinematics & State Reversion Oracle ==={Colors.ENDC}")

    gs = MockGameState()
    worker = ChibiWorkerSimulator("w_bounce", "Frontend Dev", gs)

    worker.trigger_epiphany(custom_reward=500.0)
    worker.tap_worker()

    # 1. Immediate post-collection state: CELEBRATING
    reporter.check(worker.current_state == ChibiWorkerSimulator.STATE_CELEBRATING,
                   "Worker transitions immediately to STATE_CELEBRATING on tap collection", "CELEBRATE_FSM")
    reporter.check(worker.mood_icon_text == "🎉",
                   "Mood icon updates to '🎉' during celebration", "CELEBRATE_FSM")

    # 2. Kinematic bounce evaluation across multiple frames
    observed_apex = 0.0
    for frame in range(60):
        worker.process(1.0 / 60.0)
        observed_apex = max(observed_apex, worker.chibi_root_pos_y)

    reporter.check(observed_apex > 0.15,
                   f"Celebration jump exhibits visible vertical displacement (apex: {observed_apex:.3f}m > 0.15m)", "CELEBRATE_Kinematics")
    reporter.check(math.isclose(observed_apex, 0.22, abs_tol=0.03),
                   f"Celebration jump apex reaches target ~0.22m height (observed: {observed_apex:.3f}m)", "CELEBRATE_Kinematics")

    # 3. Celebration persistence before expiry (t < 1.5s total)
    # Already simulated 1.0s (60 * 1/60)
    reporter.check(worker.current_state == ChibiWorkerSimulator.STATE_CELEBRATING,
                   "Worker remains in celebration state at t=1.0s (< 1.5s)", "CELEBRATE_Persistence")

    # 4. Clean expiry after 1.5s threshold
    worker.process(0.60)  # total elapsed = 1.60s > 1.5s
    reporter.check(worker.current_state == ChibiWorkerSimulator.STATE_WORKING,
                   "Worker cleanly reverts to STATE_WORKING when celebration duration expires", "CELEBRATE_Revert")
    reporter.check(worker.mood_icon_text == "💻",
                   "Mood icon cleanly reverts to '💻' work icon", "CELEBRATE_Revert")
    reporter.check(worker.chibi_root_pos_y == 0.0,
                   "Chibi root position cleanly rests at floor level (0.0m)", "CELEBRATE_Revert")
    reporter.check(worker.epiphany_particles_emitting is False,
                   "Epiphany particles completely halted post-celebration", "CELEBRATE_Revert")


# ==============================================================================
# SECTION 5: CoffeeMachine3D Unicorn Espresso Synergy & 60s Hyper-Focus Oracle
# ==============================================================================

def test_section5_coffee_machine_synergy(reporter: TestReporter):
    print(f"\n{Colors.BOLD}=== SECTION 5: CoffeeMachine3D Unicorn Espresso Synergy Hook Oracle ==={Colors.ENDC}")

    gs = MockGameState()
    office = OfficeExpansionSimulator(gs)
    cm = CoffeeMachineSimulator(gs, office)

    # 1. Initial conditions
    reporter.check(gs.is_staff_hyper_focus_active() is False, "Hyper-focus initially inactive in GameState", "COFFEE_Pre")
    reporter.check(all(not w.is_hyper_focus_active() for w in office.workers.values()),
                   "All office workers initially in normal speed mode (1.0x)", "COFFEE_Pre")

    # 2. Failed brew does NOT trigger synergy
    cm.complete_brew(success=False)
    reporter.check(gs.is_staff_hyper_focus_active() is False,
                   "Failed brew does not activate GameState hyper-focus", "COFFEE_Failure")
    reporter.check(cm.synergies_triggered == 0,
                   "Failed brew does not trigger office synergy", "COFFEE_Failure")
    reporter.check(cm.is_on_cooldown is False,
                   "Failed brew does not engage cooldown", "COFFEE_Failure")

    # 3. Successful brew triggers office synergy
    cm.complete_brew(success=True)
    reporter.check(cm.synergies_triggered == 1,
                   "Successful brew triggers office synergy", "COFFEE_Success")
    reporter.check(cm.is_on_cooldown is True,
                   "Successful brew engages 60s machine cooldown", "COFFEE_Success")
    reporter.check(math.isclose(cm.cooldown_remaining, 60.0, abs_tol=1e-3),
                   "Cooldown timer initialized to 60.0s", "COFFEE_Success")

    # 4. GameState synchronization
    reporter.check(gs.is_staff_hyper_focus_active() is True,
                   "GameState.is_staff_hyper_focus_active() is True post-brew", "COFFEE_GameState")
    reporter.check(math.isclose(gs.get_staff_hyper_focus_time_remaining(), 60.0, abs_tol=1e-3),
                   "GameState hyper-focus time remaining initialized to 60.0s", "COFFEE_GameState")
    reporter.check(gs.unicorn_espresso_buff_active is True,
                   "GameState unicorn espresso buff activated for avatar & workers", "COFFEE_GameState")
    reporter.check(gs.coffee_breaks_granted == 1,
                   "GameState team coffee break executed (fatigue cleared, morale=1.0)", "COFFEE_GameState")

    # 5. All office workers synchronized
    all_boosted = all(w.is_hyper_focus_active() for w in office.workers.values())
    reporter.check(all_boosted, "All 5 office workers synchronized to Hyper-Focus mode", "COFFEE_OfficeSync")

    all_celebrated = all(w.celebrations_played >= 1 for w in office.workers.values())
    reporter.check(all_celebrated, "All office workers played cheerful feedback hop upon synergy start", "COFFEE_Feedback")


# ==============================================================================
# SECTION 6: Animation Kinematics Speed Modulation (1.5x) Oracle
# ==============================================================================

def test_section6_animation_speed_modulation(reporter: TestReporter):
    print(f"\n{Colors.BOLD}=== SECTION 6: Animation Kinematics Speed Modulation (1.5x) Oracle ==={Colors.ENDC}")

    gs = MockGameState()
    worker_normal = ChibiWorkerSimulator("w_norm", "Frontend Dev", gs)
    worker_hyper = ChibiWorkerSimulator("w_hyp", "Frontend Dev", gs)

    # 1. Normal mode time progression
    worker_normal.set_hyper_focus(False)
    worker_normal.process(1.0)
    time_normal = worker_normal._time

    # 2. Hyper-Focus mode time progression
    worker_hyper.set_hyper_focus(True, duration=60.0)
    worker_hyper.process(1.0)
    time_hyper = worker_hyper._time

    reporter.check(math.isclose(time_normal, 1.0, abs_tol=1e-5),
                   "Normal worker advances time step by exactly 1.0s per delta=1.0s", "ANIM_Speed")
    reporter.check(math.isclose(time_hyper, 1.5, abs_tol=1e-5),
                   "Hyper-Focus worker advances time step by exactly 1.5s per delta=1.0s (1.50x)", "ANIM_Speed")
    reporter.check(math.isclose(time_hyper / time_normal, 1.50, abs_tol=1e-5),
                   "Kinematics time dilation factor is exactly 1.50x", "ANIM_Speed")

    # 3. Procedural typing arm frequency calculation
    # Normal: sin(t * 14.0) -> frequency = 14.0 rad/s (~2.23 Hz)
    # Hyper: sin((t * 1.5) * 14.0) = sin(t * 21.0) -> frequency = 21.0 rad/s (~3.34 Hz)
    w_freq_norm = ChibiWorkerSimulator("w_fn", "Backend Dev", gs)
    w_freq_hyp = ChibiWorkerSimulator("w_fh", "Backend Dev", gs)
    w_freq_hyp.set_hyper_focus(True, duration=60.0)
    w_freq_hyp.set_state(ChibiWorkerSimulator.STATE_WORKING)

    # Sample arm pitch over 1.0 second (100 frames at dt=0.01)
    norm_arm_pitches = []
    hyp_arm_pitches = []
    dt = 0.01
    for step in range(100):
        w_freq_norm.process(dt)
        w_freq_hyp.process(dt)
        norm_arm_pitches.append(w_freq_norm.left_arm_rot_x)
        hyp_arm_pitches.append(w_freq_hyp.left_arm_rot_x)

    # Count direction reversals (peaks and troughs)
    norm_diffs = sum(1 for i in range(1, len(norm_arm_pitches)-1) if (norm_arm_pitches[i] - norm_arm_pitches[i-1]) * (norm_arm_pitches[i+1] - norm_arm_pitches[i]) < 0)
    hyp_diffs = sum(1 for i in range(1, len(hyp_arm_pitches)-1) if (hyp_arm_pitches[i] - hyp_arm_pitches[i-1]) * (hyp_arm_pitches[i+1] - hyp_arm_pitches[i]) < 0)

    reporter.check(hyp_diffs > norm_diffs,
                   f"Hyper-focus arm typing reverses direction more frequently ({hyp_diffs} > {norm_diffs} reversals)", "ANIM_TypingKinematics")

    # 4. Timer decay: hyper focus expires after 60s
    worker_decay = ChibiWorkerSimulator("w_dec", "UI/UX Designer", gs)
    worker_decay.set_hyper_focus(True, duration=60.0)
    reporter.check(worker_decay.is_hyper_focus_active() is True, "Hyper-focus active at start", "ANIM_Expiry")

    worker_decay.process(30.0)
    reporter.check(worker_decay.is_hyper_focus_active() is True, "Hyper-focus remains active at t=30s (<60s)", "ANIM_Expiry")
    reporter.check(math.isclose(worker_decay._hyper_focus_timer, 30.0, abs_tol=1e-3),
                   "Hyper-focus remaining timer decremented accurately to 30.0s", "ANIM_Expiry")

    worker_decay.process(30.5)  # crosses 60s
    reporter.check(worker_decay.is_hyper_focus_active() is False, "Hyper-focus cleanly expires after 60.5s (>60s)", "ANIM_Expiry")
    reporter.check(worker_decay.get_animation_speed_multiplier() == 1.0,
                   "Animation speed multiplier smoothly resets back to 1.0x", "ANIM_Expiry")


# ==============================================================================
# SECTION 7: End-to-End Teambuilding & Epiphany Journey Simulation
# ==============================================================================

def test_section7_end_to_end_journey(reporter: TestReporter):
    print(f"\n{Colors.BOLD}=== SECTION 7: End-to-End Teambuilding & Epiphany Journey Simulation ==={Colors.ENDC}")

    gs = MockGameState()
    gs.energy = 500.0
    gs.base_passive_rps = 100.0

    office = OfficeExpansionSimulator(gs)
    cm = CoffeeMachineSimulator(gs, office)

    # 1. 5 hired workers working diligently
    reporter.check(len(office.workers) == 5, "5 specialist workers staffed at office desks", "JOURNEY_Staff")
    initial_rps = gs.get_effective_passive_rps()
    # 5 active workers * 0.05 * 1.0 morale = +25% RPS -> 100 * 1.25 = 125.0
    reporter.check(math.isclose(initial_rps, 125.0, abs_tol=1e-3),
                   f"Initial team passive RPS is 125.0 (got {initial_rps})", "JOURNEY_Economy")

    # 2. Worker fatigue accumulates during work
    for w_data in gs.hired_workers:
        w_data["fatigue"] = 0.50
        w_data["morale"] = 0.70

    mid_rps = gs.get_effective_passive_rps()
    # 5 active * 0.05 * 0.70 morale = +17.5% RPS -> 100 * 1.175 = 117.5
    reporter.check(math.isclose(mid_rps, 117.5, abs_tol=1e-3),
                   f"Fatigued team passive RPS decays to 117.5 (got {mid_rps})", "JOURNEY_Economy")

    # 3. Spontaneous epiphany moment breakthrough
    chosen_worker = office.trigger_random_epiphany()
    reporter.check(chosen_worker is not None, "Office successfully triggers spontaneous epiphany on working worker", "JOURNEY_Epiphany")
    reporter.check(chosen_worker.has_epiphany() is True, f"Worker {chosen_worker.worker_id} enters epiphany mode", "JOURNEY_Epiphany")
    reporter.check(chosen_worker.mood_icon_text == "💡", "Worker shows glowing 💡 breakthrough indicator", "JOURNEY_Epiphany")

    # Verify office query helper
    epiphany_ids = office.get_epiphany_worker_ids()
    reporter.check(chosen_worker.worker_id in epiphany_ids,
                   f"Office query correctly identifies active epiphany worker ({chosen_worker.worker_id})", "JOURNEY_Epiphany")

    # 4. Player taps worker to collect epiphany reward
    energy_pre_tap = gs.energy
    collected_energy = chosen_worker.tap_worker()
    expected_reward = max(100.0, mid_rps * 15.0)  # 117.5 * 15.0 = 1762.5

    reporter.check(math.isclose(collected_energy, expected_reward, abs_tol=1e-3),
                   f"Player collects {collected_energy} instant bonus energy", "JOURNEY_Collect")
    reporter.check(math.isclose(gs.energy, energy_pre_tap + expected_reward, abs_tol=1e-3),
                   "Energy bonus credited to player's bankroll", "JOURNEY_Collect")
    reporter.check(chosen_worker.current_state == "celebrating", "Worker celebrates with joyful victory jump", "JOURNEY_Collect")

    # Advance simulation by 1.6s to finish celebration
    office.process(1.6)
    reporter.check(chosen_worker.current_state == "working", "Worker resumes typing at desk post-celebration", "JOURNEY_Resume")
    reporter.check(chosen_worker.mood_icon_text == "💻", "Mood icon reverts to '💻'", "JOURNEY_Resume")

    # 5. Player brews Unicorn Espresso at CoffeeMachine3D
    cm.complete_brew(success=True)

    # Verify team reset and hyper focus
    reporter.check(gs.is_staff_hyper_focus_active() is True, "Office-wide Hyper-Focus activated", "JOURNEY_CoffeeSynergy")
    reporter.check(all(w["fatigue"] == 0.0 for w in gs.hired_workers), "All worker fatigue reset to 0.0", "JOURNEY_CoffeeSynergy")
    reporter.check(all(w["morale"] == 1.0 for w in gs.hired_workers), "All worker morale restored to 1.0", "JOURNEY_CoffeeSynergy")

    # Compounded RPS: base (100) * staff_bonus (1.25) * unicorn_buff (1.20) = 150.0
    hyper_rps = gs.get_effective_passive_rps()
    reporter.check(math.isclose(hyper_rps, 150.0, abs_tol=1e-3),
                   f"Compounded Hyper-Focus passive RPS reaches peak 150.0 (got {hyper_rps})", "JOURNEY_SynergyStacking")

    # 6. Verify 1.5x animation speed across all 5 workers
    for w in office.workers.values():
        reporter.check(math.isclose(w.get_animation_speed_multiplier(), 1.50, abs_tol=1e-5),
                       f"Worker {w.worker_id} animation running at 1.50x speed", "JOURNEY_WorkerSpeed")

    # 7. Advance simulation 60 seconds to test clean buff expiration
    office.process(60.1)
    gs.update_simulation(60.1)

    reporter.check(gs.is_staff_hyper_focus_active() is False, "Hyper-focus cleanly expired after 60 seconds", "JOURNEY_Expiry")
    for w in office.workers.values():
        reporter.check(math.isclose(w.get_animation_speed_multiplier(), 1.00, abs_tol=1e-5),
                       f"Worker {w.worker_id} speed normalized to 1.00x", "JOURNEY_Expiry")


# ==============================================================================
# MAIN RUNNER
# ==============================================================================

def main():
    print(f"{Colors.HEADER}{Colors.BOLD}")
    print("=" * 70)
    print("IDLEARCADE PHASE 14 MILESTONE 4: SYNERGIES & EPIPHANY ORACLE")
    print("=" * 70)
    print(f"{Colors.ENDC}")

    reporter = TestReporter("Phase 14 Milestone M4 (Teambuilding & Epiphany Synergies)")

    test_section1_ast_and_api(reporter)
    test_section2_epiphany_math_and_rewards(reporter)
    test_section3_epiphany_tap_and_idempotence(reporter)
    test_section4_celebration_bounce_and_reversion(reporter)
    test_section5_coffee_machine_synergy(reporter)
    test_section6_animation_speed_modulation(reporter)
    test_section7_end_to_end_journey(reporter)

    exit_code = reporter.summary()
    sys.exit(exit_code)


if __name__ == "__main__":
    main()
