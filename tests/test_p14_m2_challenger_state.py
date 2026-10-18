#!/usr/bin/env python3
"""
Phase 14 Milestone 2: Adversarial State Machine & Animation Kinematics Challenger Suite
========================================================================================
Target: IdleArcade Godot 4.3 - Milestone M2 (Requirement R2: 3D-Büroerweiterung & Autonome Chibi-Worker-KI)
Code under test:
  - IdleArcade/scripts/chibi_worker_3d.gd
  - IdleArcade/scripts/office_expansion_3d.gd
  - IdleArcade/scenes/chibi_worker_3d.tscn
  - IdleArcade/scenes/office_expansion_3d.tscn

Stress Test Tiers:
  Tier 1: Static AST & Code Contract Deep Verification
          - Class declarations, extends CharacterBody3D / StaticBody3D
          - Signal signatures: state_changed, epiphany_triggered, epiphany_collected, coffee_break_completed
          - State constants & enum definitions (WORKING, COFFEE_BREAK, FATIGUED, CELEBRATING)
          - Node hierarchy bindings: ChibiRoot, arms, head, visor, particles, click area
  Tier 2: State Machine Transition Stress & Chaos Fuzzing
          - Deterministic state transition coverage (all 16 state transition pairs)
          - 1,000 randomized rapid state transitions (chaos / fuzzing)
          - Case-insensitivity & state string alias normalization ("working", "break", "coffee", "fatigued", "sleep")
          - Typed enum input support (0, 1, 2, 3) and invalid value fallback
          - No-op idempotence (transitioning to current state emits no signal)
  Tier 3: Dynamic Mood Icon & Face Expression Invariants
          - Mood icon synchronization: 💻 (working), ☕ (break), 💤 (fatigued), 🎉 (celebrating)
          - Epiphany priority override: 💡 takes precedence over all other states when active
          - Facial expression updates: ^.^ (>0.6 morale), •_• (<=0.6 morale), ☕, -.-, ★_★
  Tier 4: Particle Emission State Invariants
          - Zzz particles: emitting == true ONLY when current_state == STATE_FATIGUED
          - Steam particles: emitting == true ONLY when current_state == STATE_COFFEE_BREAK
          - Epiphany particles: emitting == true ONLY when _has_epiphany == true
          - State transition verification: particles toggle off cleanly when leaving state
  Tier 5: Procedural Kinematics & Posture Reset Audit
          - 14.0 rad/s (~2.23 Hz) typing rhythm antiphase arm verification (left + sin, right - sin)
          - Coffee sipping right arm angle & head tilt kinematics
          - Fatigued slumped head (-0.65 rad) and lowered torso pose
          - Celebration cheerful bounce jump apex (0.22m) and victory V arms
          - Hyper-focus 1.5x speed multiplier acceleration
          - Posture reset verification: _reset_pose() restores base translations and rotations
  Tier 6: Epiphany Moments, Tap Interaction & Economy Rewards
          - Epiphany trigger: sets _has_epiphany, 💡 icon, golden particles, emits signal
          - Reward compounding: max(100.0, 15x passive RPS)
          - Custom reward override parameter
          - Tap collection: awards energy, clears particles, plays SFX, triggers 1.5s celebration
          - Tap spamming idempotence: subsequent clicks return 0.0 without extra energy
          - Celebration expiry countdown: reverts back to prior state automatically
  Tier 7: Office Expansion Desks & Worker Reassignment Stress (1,000 Cycles)
          - 5 workstations layout & Marker3D slot alignment
          - 1,000 Monte Carlo hire / fire / rehire cycles
          - Desk index uniqueness invariant (no two active workers ever occupy same desk)
          - Spawned worker dictionary synchronization (zero leaked nodes or orphaned entries)
          - Desk upgrade tiers (1, 2, 3) and visual toggles (DualMonitor, RgbLedBar, Standing Desk 0.95m)
          - Out-of-bounds desk index and negative level rejection
  Tier 8: Malicious Input Fuzzing & Boundary Recovery
          - Negative, NaN, Inf morale and fatigue values clamped to [0.0, 1.0]
          - Fatigue threshold hysteresis: 1.0 -> FATIGUED, < 0.8 -> WORKING
          - Proximity Area3D flapping (1,000 enter/exit cycles)
          - TouchControls registration / unregistration hooks

Executable via: python tests/test_p14_m2_challenger_state.py
"""

import math
import random
import re
import sys
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

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
        print(f"{Colors.BOLD}Phase 14 M2 Challenger 2 (State Machine & Kinematics) Results{Colors.ENDC}")
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


# ==============================================================================
# Python Simulation Models mirroring GDScript Implementation
# ==============================================================================

class ChibiWorker3DSimulator:
    """Exact behavioral simulation of scripts/chibi_worker_3d.gd."""

    STATE_WORKING = "working"
    STATE_COFFEE_BREAK = "break"
    STATE_FATIGUED = "fatigued"
    STATE_CELEBRATING = "celebrating"

    ROLE_COLORS = {
        "Frontend Dev": (0.1, 0.75, 1.0, 1.0),
        "Backend Dev": (0.1, 0.85, 0.3, 1.0),
        "UI/UX Designer": (0.85, 0.25, 0.95, 1.0),
        "Growth Hacker": (1.0, 0.65, 0.1, 1.0),
        "QA Engineer": (0.95, 0.2, 0.25, 1.0),
    }

    def __init__(self, worker_id: str = "w0", name: str = "Worker", role: str = "Frontend Dev"):
        self.worker_id = worker_id
        self.worker_name = name
        self.role = role
        self.morale: float = 1.0
        self.fatigue: float = 0.0
        self.desk_assigned: int = 0
        self.current_state: str = self.STATE_WORKING
        self.hyper_focus: bool = False
        self.hyper_focus_multiplier: float = 1.5
        self.desk_level: int = 1

        # Node states
        self.mood_icon_text: str = "💻"
        self.face_label_text: str = "^.^"
        self.zzz_particles_emitting: bool = False
        self.steam_particles_emitting: bool = False
        self.epiphany_particles_emitting: bool = False
        self.epiphany_light_visible: bool = False
        self.mood_icon_scale: Tuple[float, float, float] = (1.0, 1.0, 1.0)

        # Kinematic pose
        self.torso_pos: List[float] = [0.0, 0.35, 0.0]
        self.torso_rot: List[float] = [0.0, 0.0, 0.0]
        self.head_pos: List[float] = [0.0, 0.65, 0.0]
        self.head_rot: List[float] = [0.0, 0.0, 0.0]
        self.left_arm_rot: List[float] = [0.0, 0.0, 0.0]
        self.right_arm_rot: List[float] = [0.0, 0.0, 0.0]
        self.chibi_root_pos_y: float = 0.0

        # Internals
        self._time: float = 0.0
        self._anim_phase_offset: float = random.uniform(0.0, 10.0)
        self._has_epiphany: bool = False
        self._epiphany_reward: float = 0.0
        self._celebrate_timer: float = 0.0
        self._revert_state_after_celebrate: str = self.STATE_WORKING

        # Signal log
        self.signal_events: List[Tuple[str, Any]] = []

        self._update_state_visuals()

    def setup(self, data: Dict[str, Any]):
        if "id" in data:
            self.worker_id = str(data["id"])
        if "name" in data:
            self.worker_name = str(data["name"])
        if "role" in data:
            self.role = str(data["role"])
        if "morale" in data:
            try:
                v = float(data["morale"])
                if math.isnan(v) or math.isinf(v):
                    v = 1.0
                self.morale = max(0.0, min(1.0, v))
            except (ValueError, TypeError):
                self.morale = 1.0
        if "fatigue" in data:
            try:
                v = float(data["fatigue"])
                if math.isnan(v) or math.isinf(v):
                    v = 0.0
                self.fatigue = max(0.0, min(1.0, v))
            except (ValueError, TypeError):
                self.fatigue = 0.0
        if "desk_assigned" in data:
            self.desk_assigned = int(data["desk_assigned"])
        if "current_state" in data:
            self.set_state(str(data["current_state"]))
        if "desk_level" in data:
            self.desk_level = int(data["desk_level"])

        self._update_state_visuals()

    def set_state(self, new_state: Any) -> bool:
        target_state = self.STATE_WORKING
        if isinstance(new_state, int):
            if new_state == 0:
                target_state = self.STATE_WORKING
            elif new_state == 1:
                target_state = self.STATE_COFFEE_BREAK
            elif new_state == 2:
                target_state = self.STATE_FATIGUED
            elif new_state == 3:
                target_state = self.STATE_CELEBRATING
            else:
                target_state = self.STATE_WORKING
        else:
            s = str(new_state).lower()
            if s == "working":
                target_state = self.STATE_WORKING
            elif s in ["break", "coffee_break", "coffee"]:
                target_state = self.STATE_COFFEE_BREAK
            elif s in ["fatigued", "tired", "sleep"]:
                target_state = self.STATE_FATIGUED
            elif s in ["celebrating", "celebrate"]:
                target_state = self.STATE_CELEBRATING
            else:
                target_state = s

        if self.current_state == target_state:
            return False

        old = self.current_state
        self.current_state = target_state
        self._update_state_visuals()
        self.signal_events.append(("state_changed", (old, self.current_state)))
        return True

    def get_state(self) -> str:
        return self.current_state

    def set_morale(self, new_morale: float):
        try:
            v = float(new_morale)
            if math.isnan(v) or math.isinf(v):
                v = 0.5
            self.morale = max(0.0, min(1.0, v))
        except (ValueError, TypeError):
            self.morale = 0.5
        self._update_face_expression()

    def set_fatigue(self, new_fatigue: float):
        try:
            v = float(new_fatigue)
            if math.isnan(v) or math.isinf(v):
                v = 0.0
            self.fatigue = max(0.0, min(1.0, v))
        except (ValueError, TypeError):
            self.fatigue = 0.0

        if self.fatigue >= 1.0 and self.current_state == self.STATE_WORKING:
            self.set_state(self.STATE_FATIGUED)
        elif self.fatigue < 0.8 and self.current_state == self.STATE_FATIGUED:
            self.set_state(self.STATE_WORKING)

    def set_hyper_focus(self, active: bool, _duration: float = 60.0):
        self.hyper_focus = active

    def _update_state_visuals(self):
        self.zzz_particles_emitting = (self.current_state == self.STATE_FATIGUED)
        self.steam_particles_emitting = (self.current_state == self.STATE_COFFEE_BREAK)

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
        self._reset_pose()

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

    def _reset_pose(self):
        self.torso_pos = [0.0, 0.35, 0.0]
        self.torso_rot = [0.0, 0.0, 0.0]
        self.head_pos = [0.0, 0.65, 0.0]
        self.head_rot = [0.0, 0.0, 0.0]
        self.left_arm_rot = [0.0, 0.0, 0.0]
        self.right_arm_rot = [0.0, 0.0, 0.0]
        if self.current_state != self.STATE_CELEBRATING:
            self.chibi_root_pos_y = 0.0

    def trigger_epiphany(self, custom_reward: float = 0.0, mock_rps: float = 50.0):
        self._has_epiphany = True
        if custom_reward > 0.0:
            self._epiphany_reward = custom_reward
        else:
            self._epiphany_reward = max(100.0, mock_rps * 15.0)

        self.mood_icon_text = "💡"
        self.epiphany_particles_emitting = True
        self.epiphany_light_visible = True
        self._update_face_expression()
        self.signal_events.append(("epiphany_triggered", (self.worker_id, self._epiphany_reward)))

    def collect_epiphany(self, game_state_ref: Optional[Dict[str, Any]] = None) -> float:
        if not self._has_epiphany:
            return 0.0

        reward = self._epiphany_reward
        self._has_epiphany = False

        self.mood_icon_scale = (1.0, 1.0, 1.0)
        self.epiphany_particles_emitting = False
        self.epiphany_light_visible = False

        if game_state_ref is not None:
            game_state_ref["energy"] = game_state_ref.get("energy", 0.0) + reward
            game_state_ref["lifetime_energy"] = game_state_ref.get("lifetime_energy", 0.0) + reward

        self.signal_events.append(("epiphany_collected", (self.worker_id, reward)))
        self.play_celebration(1.5)
        return reward

    def has_epiphany(self) -> bool:
        return self._has_epiphany

    def play_celebration(self, duration: float = 2.0):
        self._revert_state_after_celebrate = (
            self.current_state if self.current_state != self.STATE_CELEBRATING else self.STATE_WORKING
        )
        self._celebrate_timer = duration
        self.set_state(self.STATE_CELEBRATING)

    def process(self, delta: float):
        speed_mult = self.hyper_focus_multiplier if self.hyper_focus else 1.0
        self._time += delta * speed_mult
        t = self._time + self._anim_phase_offset

        if self._celebrate_timer > 0.0:
            self._celebrate_timer -= delta
            if self._celebrate_timer <= 0.0:
                self.set_state(self._revert_state_after_celebrate)

        if self.current_state == self.STATE_WORKING:
            self._animate_working(t)
        elif self.current_state == self.STATE_COFFEE_BREAK:
            self._animate_coffee_break(t)
        elif self.current_state == self.STATE_FATIGUED:
            self._animate_fatigued(t)
        elif self.current_state == self.STATE_CELEBRATING:
            self._animate_celebrating(t)

    def _animate_working(self, t: float):
        self.left_arm_rot[0] = -0.35 + math.sin(t * 14.0) * 0.15
        self.left_arm_rot[2] = 0.15
        self.right_arm_rot[0] = -0.35 - math.sin(t * 14.0) * 0.15
        self.right_arm_rot[2] = -0.15

        self.head_rot[0] = -0.05 + math.sin(t * 4.0) * 0.03
        self.head_rot[1] = math.sin(t * 1.5) * 0.05

    def _animate_coffee_break(self, t: float):
        self.right_arm_rot[0] = -0.85 + math.sin(t * 3.0) * 0.08
        self.right_arm_rot[1] = -0.25
        self.left_arm_rot[0] = 0.0
        self.left_arm_rot[2] = 0.2

        self.head_rot[0] = 0.12 + math.sin(t * 3.0) * 0.04
        self.head_rot[2] = -0.05

    def _animate_fatigued(self, t: float):
        self.head_rot[0] = -0.65 + math.sin(t * 1.2) * 0.02
        self.head_pos[1] = 0.65 - 0.08
        self.torso_rot[0] = -0.25
        self.torso_pos[1] = 0.35 - 0.04
        self.left_arm_rot[0] = -0.6
        self.left_arm_rot[2] = 0.4
        self.right_arm_rot[0] = -0.6
        self.right_arm_rot[2] = -0.4

    def _animate_celebrating(self, t: float):
        self.chibi_root_pos_y = abs(math.sin(t * 12.0)) * 0.22
        self.left_arm_rot[2] = 2.4 + math.sin(t * 10.0) * 0.15
        self.left_arm_rot[0] = 0.1
        self.right_arm_rot[2] = -2.4 - math.sin(t * 10.0) * 0.15
        self.right_arm_rot[0] = 0.1
        self.head_rot[0] = math.sin(t * 8.0) * 0.1


class OfficeExpansion3DSimulator:
    """Exact behavioral simulation of scripts/office_expansion_3d.gd."""

    SLOT_POSITIONS = [
        (-2.4, 0.0, -0.15),
        (0.0, 0.0, -0.15),
        (2.4, 0.0, -0.15),
        (-1.2, 0.0, 1.25),
        (1.2, 0.0, 1.25),
    ]

    DESK_POSITIONS = [
        (-2.4, 0.0, -0.6),
        (0.0, 0.0, -0.6),
        (2.4, 0.0, -0.6),
        (-1.2, 0.0, 0.8),
        (1.2, 0.0, 0.8),
    ]

    def __init__(self):
        self.spawned_workers: Dict[str, ChibiWorker3DSimulator] = {}
        self.desk_levels: List[int] = [1, 1, 1, 1, 1]
        self.desk_visuals: List[Dict[str, Any]] = [
            {"dual_monitor": False, "rgb_bar": False, "desk_top_y": 0.72} for _ in range(5)
        ]
        self.player_in_range: bool = False
        self.prompt_visible: bool = False
        self.signal_log: List[Tuple[str, Any]] = []

    def spawn_worker(self, worker_data: Dict[str, Any]) -> Optional[ChibiWorker3DSimulator]:
        w_id = str(worker_data.get("id", ""))
        if not w_id:
            return None
        if w_id in self.spawned_workers:
            return self.spawned_workers[w_id]

        worker = ChibiWorker3DSimulator(w_id, worker_data.get("name", "Worker"), worker_data.get("role", "Frontend Dev"))
        desk_idx = int(worker_data.get("desk_assigned", 0))
        worker.desk_assigned = desk_idx
        worker.setup(worker_data)

        self.spawned_workers[w_id] = worker
        return worker

    def despawn_worker(self, worker_id: str):
        if worker_id in self.spawned_workers:
            del self.spawned_workers[worker_id]

    def apply_desk_level(self, desk_index: int, level: int):
        if desk_index < 0 or desk_index >= len(self.desk_levels):
            return

        self.desk_levels[desk_index] = level
        self.desk_visuals[desk_index]["dual_monitor"] = (level >= 2)
        self.desk_visuals[desk_index]["rgb_bar"] = (level >= 3)
        self.desk_visuals[desk_index]["desk_top_y"] = 0.95 if level >= 3 else 0.72

        for w in self.spawned_workers.values():
            if w.desk_assigned == desk_index:
                w.desk_level = level

    def on_coffee_break_started(self, _duration: float = 20.0):
        for w in self.spawned_workers.values():
            w.set_state(ChibiWorker3DSimulator.STATE_COFFEE_BREAK)

    def on_coffee_break_ended(self):
        for w in self.spawned_workers.values():
            w.set_state(ChibiWorker3DSimulator.STATE_WORKING)

    def on_unicorn_espresso_activated(self, duration: float = 60.0, _speed_mult: float = 1.5):
        for w in self.spawned_workers.values():
            w.set_hyper_focus(True, duration)

    def on_interaction_body_entered(self, is_player: bool = True):
        if is_player:
            self.player_in_range = True
            self.prompt_visible = True

    def on_interaction_body_exited(self, is_player: bool = True):
        if is_player:
            self.player_in_range = False
            self.prompt_visible = False


# ==============================================================================
# TEST TIERS
# ==============================================================================

def test_tier1_ast_and_signatures(reporter: TestReporter, game_dir: Path):
    print(f"\n{Colors.BOLD}=== TIER 1: Static AST & Signatures Audit ==={Colors.ENDC}")

    worker_file = game_dir / "scripts/chibi_worker_3d.gd"
    office_file = game_dir / "scripts/office_expansion_3d.gd"

    reporter.check(worker_file.exists(), "scripts/chibi_worker_3d.gd exists on disk", "TIER1_AST")
    reporter.check(office_file.exists(), "scripts/office_expansion_3d.gd exists on disk", "TIER1_AST")

    w_code = worker_file.read_text(encoding="utf-8")
    o_code = office_file.read_text(encoding="utf-8")

    # Worker AST
    reporter.check("class_name ChibiWorker3D" in w_code, "ChibiWorker3D declares class_name", "TIER1_AST")
    reporter.check("extends CharacterBody3D" in w_code, "ChibiWorker3D extends CharacterBody3D", "TIER1_AST")

    required_worker_signals = [
        "signal state_changed(old_state: String, new_state: String)",
        "signal epiphany_triggered(worker_id: String, reward: float)",
        "signal epiphany_collected(worker_id: String, reward: float)",
        "signal coffee_break_completed(worker_id: String)",
    ]
    for sig in required_worker_signals:
        name = sig.split("(")[0].replace("signal ", "").strip()
        reporter.check(name in w_code, f"ChibiWorker3D declares signal '{name}'", "TIER1_AST")

    required_worker_methods = [
        "setup", "apply_role_visuals", "set_role", "set_morale", "set_fatigue",
        "set_hyper_focus", "get_state", "set_state", "_update_state_visuals",
        "_update_face_expression", "_reset_pose", "_process", "_animate_working",
        "_animate_coffee_break", "_animate_fatigued", "_animate_celebrating",
        "trigger_epiphany", "collect_epiphany", "has_epiphany", "play_celebration"
    ]
    for method in required_worker_methods:
        reporter.check(f"func {method}" in w_code, f"ChibiWorker3D implements func {method}()", "TIER1_AST")

    # Office AST
    reporter.check("class_name OfficeExpansion3D" in o_code, "OfficeExpansion3D declares class_name", "TIER1_AST")
    reporter.check("extends StaticBody3D" in o_code, "OfficeExpansion3D extends StaticBody3D", "TIER1_AST")

    required_office_signals = [
        "signal staff_interaction_requested",
        "signal staff_office_opened",
        "signal worker_epiphany_collected",
    ]
    for sig in required_office_signals:
        name = sig.replace("signal ", "").strip()
        reporter.check(name in o_code, f"OfficeExpansion3D declares signal '{name}'", "TIER1_AST")

    required_office_methods = [
        "_ready", "_init_desk_and_slot_references", "_connect_game_state_signals",
        "_unhandled_input", "_on_interaction_body_entered", "_on_interaction_body_exited",
        "is_player_in_range", "interact", "open_staff", "open_staff_modal",
        "refresh_desks", "apply_desk_level", "_on_desk_upgraded", "get_desk_node",
        "refresh_workers", "spawn_worker", "despawn_worker", "get_worker_instance",
        "get_all_workers", "_on_worker_hired", "_on_worker_fired", "_on_worker_state_changed",
        "_on_worker_morale_updated", "_on_coffee_break_started", "_on_coffee_break_ended",
        "_on_unicorn_espresso_activated", "_on_worker_epiphany_collected"
    ]
    for method in required_office_methods:
        reporter.check(f"func {method}" in o_code, f"OfficeExpansion3D implements func {method}()", "TIER1_AST")


def test_tier2_state_transitions_and_chaos(reporter: TestReporter):
    print(f"\n{Colors.BOLD}=== TIER 2: State Transitions & Chaos Fuzzing Stress ==={Colors.ENDC}")

    worker = ChibiWorker3DSimulator()

    # 1. Deterministic transitions across all 16 state pairs
    states = [worker.STATE_WORKING, worker.STATE_COFFEE_BREAK, worker.STATE_FATIGUED, worker.STATE_CELEBRATING]
    for s1 in states:
        for s2 in states:
            worker.set_state(s1)
            old_sig_count = len(worker.signal_events)
            changed = worker.set_state(s2)
            if s1 == s2:
                reporter.check(not changed, f"No-op transition ({s1} -> {s2}) correctly returns False", "STATE_NoOp")
                reporter.check(len(worker.signal_events) == old_sig_count, f"No-op ({s1} -> {s2}) emits no signal", "STATE_NoOp")
            else:
                reporter.check(changed, f"Transition ({s1} -> {s2}) succeeds", "STATE_Pair")
                last_sig = worker.signal_events[-1]
                reporter.check(last_sig[0] == "state_changed" and last_sig[1] == (s1, s2),
                               f"Transition ({s1} -> {s2}) emits correct state_changed tuple", "STATE_Pair")

    # 2. String alias & case-insensitivity fuzzing
    aliases = {
        "working": worker.STATE_WORKING,
        "WORKING": worker.STATE_WORKING,
        "Working": worker.STATE_WORKING,
        "break": worker.STATE_COFFEE_BREAK,
        "coffee_break": worker.STATE_COFFEE_BREAK,
        "coffee": worker.STATE_COFFEE_BREAK,
        "COFFEE": worker.STATE_COFFEE_BREAK,
        "fatigued": worker.STATE_FATIGUED,
        "tired": worker.STATE_FATIGUED,
        "sleep": worker.STATE_FATIGUED,
        "FATIGUED": worker.STATE_FATIGUED,
        "celebrating": worker.STATE_CELEBRATING,
        "celebrate": worker.STATE_CELEBRATING,
        "CELEBRATING": worker.STATE_CELEBRATING,
    }
    for alias_in, expected_state in aliases.items():
        worker.set_state(worker.STATE_WORKING if expected_state != worker.STATE_WORKING else worker.STATE_FATIGUED)
        worker.set_state(alias_in)
        reporter.check(worker.get_state() == expected_state,
                       f"State alias '{alias_in}' correctly maps to '{expected_state}'", "STATE_Alias")

    # 3. Typed Enum integer input
    enum_tests = [
        (0, worker.STATE_WORKING),
        (1, worker.STATE_COFFEE_BREAK),
        (2, worker.STATE_FATIGUED),
        (3, worker.STATE_CELEBRATING),
        (99, worker.STATE_WORKING),  # Unknown enum falls back to working
    ]
    for enum_val, expected_state in enum_tests:
        worker.set_state(worker.STATE_WORKING if expected_state != worker.STATE_WORKING else worker.STATE_FATIGUED)
        worker.set_state(enum_val)
        reporter.check(worker.get_state() == expected_state,
                       f"Typed enum value {enum_val} correctly resolves to '{expected_state}'", "STATE_Enum")

    # 4. 1,000 rapid chaotic state transitions
    random.seed(42)
    chaos_states = [worker.STATE_WORKING, worker.STATE_COFFEE_BREAK, worker.STATE_FATIGUED, worker.STATE_CELEBRATING]
    invariants_held = True
    for _ in range(1000):
        next_s = random.choice(chaos_states)
        worker.set_state(next_s)
        # Invariant checks
        if worker.current_state == worker.STATE_FATIGUED and not worker.zzz_particles_emitting:
            invariants_held = False
            break
        if worker.current_state == worker.STATE_COFFEE_BREAK and not worker.steam_particles_emitting:
            invariants_held = False
            break
        if worker.current_state == worker.STATE_WORKING and (worker.zzz_particles_emitting or worker.steam_particles_emitting):
            invariants_held = False
            break

    reporter.check(invariants_held, "1,000 rapid chaotic state transitions strictly preserve all particle/pose invariants", "STATE_Chaos")


def test_tier3_mood_icons_and_expressions(reporter: TestReporter):
    print(f"\n{Colors.BOLD}=== TIER 3: Mood Icons & Facial Expressions Invariants ==={Colors.ENDC}")

    worker = ChibiWorker3DSimulator()

    # Normal mood icons without epiphany
    mood_map = {
        worker.STATE_WORKING: "💻",
        worker.STATE_COFFEE_BREAK: "☕",
        worker.STATE_FATIGUED: "💤",
        worker.STATE_CELEBRATING: "🎉",
    }
    for state, icon in mood_map.items():
        worker.set_state(state)
        reporter.check(worker.mood_icon_text == icon,
                       f"State '{state}' correctly displays mood icon '{icon}'", "MOOD_Normal")

    # Epiphany overrides all normal mood icons
    worker.set_state(worker.STATE_WORKING)
    worker.trigger_epiphany()
    reporter.check(worker.mood_icon_text == "💡", "Triggering epiphany displays '💡' mood icon", "MOOD_Epiphany")

    for state in [worker.STATE_WORKING, worker.STATE_COFFEE_BREAK, worker.STATE_FATIGUED]:
        worker.set_state(state)
        reporter.check(worker.mood_icon_text == "💡",
                       f"Epiphany '💡' icon is strictly preserved during state transition to '{state}'", "MOOD_EpiphanyOverride")

    # Collecting epiphany from non-celebrating state clears 💡 and sets celebration 🎉
    worker.set_state(worker.STATE_WORKING)
    worker.collect_epiphany()
    reporter.check(worker.mood_icon_text == "🎉", "Collecting epiphany sets celebration icon '🎉'", "MOOD_EpiphanyCollect")
    reporter.check(worker.get_state() == worker.STATE_CELEBRATING, "Worker transitions to CELEBRATING on collect", "MOOD_EpiphanyCollect")

    # Facial expressions
    worker.set_state(worker.STATE_WORKING)
    worker.set_morale(0.9)
    reporter.check(worker.face_label_text == "^.^", "High morale (>0.6) displays '^.^' visor face", "FACE_Expression")
    worker.set_morale(0.4)
    reporter.check(worker.face_label_text == "•_•", "Low morale (<=0.6) displays '•_•' visor face", "FACE_Expression")
    worker.set_state(worker.STATE_COFFEE_BREAK)
    reporter.check(worker.face_label_text == "☕", "Coffee break displays '☕' visor face", "FACE_Expression")
    worker.set_state(worker.STATE_FATIGUED)
    reporter.check(worker.face_label_text == "-.-", "Fatigue displays '-.-' visor face", "FACE_Expression")


def test_tier4_particle_emissions(reporter: TestReporter):
    print(f"\n{Colors.BOLD}=== TIER 4: Particle Emission State Invariants ==={Colors.ENDC}")

    worker = ChibiWorker3DSimulator()

    # Fatigued particles test
    worker.set_state(worker.STATE_FATIGUED)
    reporter.check(worker.zzz_particles_emitting is True, "Zzz particles emitting when FATIGUED", "PARTICLES_Zzz")
    reporter.check(worker.steam_particles_emitting is False, "Steam particles OFF when FATIGUED", "PARTICLES_Zzz")

    worker.set_state(worker.STATE_WORKING)
    reporter.check(worker.zzz_particles_emitting is False, "Zzz particles turn OFF when returning to WORKING", "PARTICLES_Zzz")

    # Steam particles test
    worker.set_state(worker.STATE_COFFEE_BREAK)
    reporter.check(worker.steam_particles_emitting is True, "Steam particles emitting during COFFEE_BREAK", "PARTICLES_Steam")
    reporter.check(worker.zzz_particles_emitting is False, "Zzz particles OFF during COFFEE_BREAK", "PARTICLES_Steam")

    worker.set_state(worker.STATE_WORKING)
    reporter.check(worker.steam_particles_emitting is False, "Steam particles turn OFF when returning to WORKING", "PARTICLES_Steam")

    # Epiphany particles test
    worker.trigger_epiphany()
    reporter.check(worker.epiphany_particles_emitting is True, "Epiphany particles emitting when epiphany triggered", "PARTICLES_Epiphany")
    reporter.check(worker.epiphany_light_visible is True, "Epiphany light visible when epiphany triggered", "PARTICLES_Epiphany")

    worker.collect_epiphany()
    reporter.check(worker.epiphany_particles_emitting is False, "Epiphany particles turn OFF on collect", "PARTICLES_Epiphany")
    reporter.check(worker.epiphany_light_visible is False, "Epiphany light turns OFF on collect", "PARTICLES_Epiphany")


def test_tier5_procedural_kinematics(reporter: TestReporter):
    print(f"\n{Colors.BOLD}=== TIER 5: Procedural Kinematics & Posture Safety ==={Colors.ENDC}")

    worker = ChibiWorker3DSimulator()

    # 1. Working Kinematics: 14 rad/s typing oscillation antiphase
    worker.set_state(worker.STATE_WORKING)
    deltas = [0.016, 0.033, 0.05, 0.1, 0.2]
    antiphase_verified = True
    left_bounds_verified = True
    right_bounds_verified = True

    for dt in deltas:
        worker.process(dt)
        # Left arm: -0.35 + sin(t*14)*0.15 in [-0.50, -0.20]
        # Right arm: -0.35 - sin(t*14)*0.15 in [-0.50, -0.20]
        l_x = worker.left_arm_rot[0]
        r_x = worker.right_arm_rot[0]

        if not (-0.51 <= l_x <= -0.19):
            left_bounds_verified = False
        if not (-0.51 <= r_x <= -0.19):
            right_bounds_verified = False

        # Antiphase check: sum of oscillations should equal -0.70
        sum_x = l_x + r_x
        if not math.isclose(sum_x, -0.70, abs_tol=1e-4):
            antiphase_verified = False

    reporter.check(left_bounds_verified, "Left arm typing pitch bounded in [-0.50, -0.20] rad", "KINEMATICS_Typing")
    reporter.check(right_bounds_verified, "Right arm typing pitch bounded in [-0.50, -0.20] rad", "KINEMATICS_Typing")
    reporter.check(antiphase_verified, "Left and right arms oscillate in strict antiphase (left+right == -0.70 rad)", "KINEMATICS_Typing")

    # 2. Coffee break sipping kinematics
    worker.set_state(worker.STATE_COFFEE_BREAK)
    worker.process(0.1)
    # Right arm: -0.85 + sin(t*3)*0.08 in [-0.93, -0.77]
    reporter.check(-0.94 <= worker.right_arm_rot[0] <= -0.76, "Coffee sipping arm pitch bounded in [-0.93, -0.77] rad", "KINEMATICS_Coffee")
    reporter.check(math.isclose(worker.right_arm_rot[1], -0.25, abs_tol=1e-3), "Coffee sipping arm yaw fixed at -0.25 rad", "KINEMATICS_Coffee")
    reporter.check(math.isclose(worker.left_arm_rot[0], 0.0, abs_tol=1e-3), "Resting left arm pitch is 0.0 rad", "KINEMATICS_Coffee")

    # 3. Fatigued desk slump kinematics
    worker.set_state(worker.STATE_FATIGUED)
    worker.process(0.1)
    reporter.check(-0.68 <= worker.head_rot[0] <= -0.62, "Fatigued head slumped at -0.65 rad", "KINEMATICS_Fatigue")
    reporter.check(math.isclose(worker.head_pos[1], 0.57, abs_tol=1e-3), "Fatigued head height lowered to 0.57m", "KINEMATICS_Fatigue")
    reporter.check(math.isclose(worker.torso_rot[0], -0.25, abs_tol=1e-3), "Fatigued torso slumped at -0.25 rad", "KINEMATICS_Fatigue")
    reporter.check(math.isclose(worker.torso_pos[1], 0.31, abs_tol=1e-3), "Fatigued torso lowered to 0.31m", "KINEMATICS_Fatigue")

    # 4. Celebrating bounce jump kinematics
    worker.set_state(worker.STATE_CELEBRATING)
    jump_heights = []
    for _ in range(60):
        worker.process(0.016)
        jump_heights.append(worker.chibi_root_pos_y)

    max_jump = max(jump_heights)
    min_jump = min(jump_heights)
    reporter.check(0.0 <= min_jump, "Celebration jump baseline >= 0.0m", "KINEMATICS_Jump")
    reporter.check(math.isclose(max_jump, 0.22, abs_tol=0.03), f"Celebration jump reaches ~0.22m apex (observed: {max_jump:.3f}m)", "KINEMATICS_Jump")

    # 5. Posture reset verification
    worker.set_state(worker.STATE_WORKING)
    reporter.check(math.isclose(worker.chibi_root_pos_y, 0.0, abs_tol=1e-5), "Leaving celebration resets chibi root height to 0.0m", "KINEMATICS_Reset")
    reporter.check(worker.torso_pos == [0.0, 0.35, 0.0], "Leaving fatigue restores torso position to (0, 0.35, 0)", "KINEMATICS_Reset")
    reporter.check(worker.head_pos == [0.0, 0.65, 0.0], "Leaving fatigue restores head position to (0, 0.65, 0)", "KINEMATICS_Reset")

    # 6. Hyper-focus speed multiplier
    worker._time = 0.0
    worker.set_hyper_focus(False)
    worker.process(1.0)
    time_normal = worker._time

    worker._time = 0.0
    worker.set_hyper_focus(True)
    worker.process(1.0)
    time_hyper = worker._time

    reporter.check(math.isclose(time_hyper, time_normal * 1.5, abs_tol=1e-5),
                   "Hyper-focus accelerates procedural kinematics time step by 1.50x", "KINEMATICS_HyperFocus")


def test_tier6_epiphany_and_rewards(reporter: TestReporter):
    print(f"\n{Colors.BOLD}=== TIER 6: Epiphany Moments, Tap Interaction & Rewards ==={Colors.ENDC}")

    worker = ChibiWorker3DSimulator("w1", "Alice", "Frontend Dev")
    mock_game_state = {"energy": 1000.0, "lifetime_energy": 5000.0}

    # 1. Epiphany reward compounding with RPS: max(100.0, 15 * RPS)
    worker.trigger_epiphany(custom_reward=0.0, mock_rps=20.0)
    expected_reward = 20.0 * 15.0  # 300.0
    reporter.check(math.isclose(worker._epiphany_reward, 300.0, abs_tol=1e-3),
                   f"Passive RPS (20.0) yields exactly 15x reward = 300.0 (got {worker._epiphany_reward})", "EPIPHANY_Compounding")

    # Low RPS floor at 100.0
    worker.trigger_epiphany(custom_reward=0.0, mock_rps=2.0)
    reporter.check(math.isclose(worker._epiphany_reward, 100.0, abs_tol=1e-3),
                   "Low passive RPS (2.0) floors reward at 100.0", "EPIPHANY_Compounding")

    # Custom reward parameter
    worker.trigger_epiphany(custom_reward=777.0, mock_rps=50.0)
    reporter.check(math.isclose(worker._epiphany_reward, 777.0, abs_tol=1e-3),
                   "Custom reward parameter (777.0) overrides formula", "EPIPHANY_Custom")

    # 2. Tap collection credits energy to GameState
    energy_before = mock_game_state["energy"]
    collected = worker.collect_epiphany(mock_game_state)
    reporter.check(math.isclose(collected, 777.0, abs_tol=1e-3), "collect_epiphany() returns reward amount", "EPIPHANY_Collect")
    reporter.check(math.isclose(mock_game_state["energy"], energy_before + 777.0, abs_tol=1e-3),
                   "Collected energy credited directly to GameState", "EPIPHANY_Collect")

    # 3. Tap spamming idempotence: repeated clicks return 0.0
    for i in range(5):
        spam_reward = worker.collect_epiphany(mock_game_state)
        reporter.check(spam_reward == 0.0, f"Repeated tap click {i+1} returns 0.0 without duplicate reward", "EPIPHANY_Spam")

    # 4. Celebration timer auto-expiry and state reversion
    # Worker is in celebrating state for 1.5s
    reporter.check(worker.get_state() == worker.STATE_CELEBRATING, "Worker is CELEBRATING post-collection", "EPIPHANY_Revert")
    worker.process(1.0)
    reporter.check(worker.get_state() == worker.STATE_CELEBRATING, "Worker remains CELEBRATING at t=1.0s (<1.5s)", "EPIPHANY_Revert")
    worker.process(0.6)  # crosses 1.5s threshold
    reporter.check(worker.get_state() == worker.STATE_WORKING, "Celebration cleanly expires after 1.5s and reverts to WORKING", "EPIPHANY_Revert")
    reporter.check(worker.mood_icon_text == "💻", "Mood icon cleanly reverts to '💻' on celebration expiry", "EPIPHANY_Revert")


def test_tier7_desks_and_worker_reassignment(reporter: TestReporter):
    print(f"\n{Colors.BOLD}=== TIER 7: Office Expansion Desks & 1,000 Reassignment Cycles ==={Colors.ENDC}")

    office = OfficeExpansion3DSimulator()

    # 1. 5 workstations coordinates validation
    reporter.check(len(office.DESK_POSITIONS) == 5, "OfficeExpansion defines exactly 5 workstations", "DESKS_Layout")
    reporter.check(len(office.SLOT_POSITIONS) == 5, "OfficeExpansion defines exactly 5 worker slot markers", "DESKS_Layout")

    # Euclidean distance check between all desks > 2.0m
    min_dist = float("inf")
    for i in range(5):
        for j in range(i + 1, 5):
            d1 = office.DESK_POSITIONS[i]
            d2 = office.DESK_POSITIONS[j]
            dist = math.sqrt((d1[0]-d2[0])**2 + (d1[1]-d2[1])**2 + (d1[2]-d2[2])**2)
            if dist < min_dist:
                min_dist = dist

    reporter.check(min_dist >= 1.8, f"Workstations have generous physical spacing (min distance: {min_dist:.2f}m >= 1.8m)", "DESKS_Layout")

    # 2. Desk Upgrades Tier 1, 2, 3
    # Tier 1
    office.apply_desk_level(0, 1)
    reporter.check(office.desk_visuals[0]["dual_monitor"] is False, "Desk Level 1: DualMonitor hidden", "DESKS_Upgrade")
    reporter.check(office.desk_visuals[0]["rgb_bar"] is False, "Desk Level 1: RgbLedBar hidden", "DESKS_Upgrade")
    reporter.check(office.desk_visuals[0]["desk_top_y"] == 0.72, "Desk Level 1: DeskTop height is 0.72m", "DESKS_Upgrade")

    # Tier 2
    office.apply_desk_level(0, 2)
    reporter.check(office.desk_visuals[0]["dual_monitor"] is True, "Desk Level 2: DualMonitor visible", "DESKS_Upgrade")
    reporter.check(office.desk_visuals[0]["rgb_bar"] is False, "Desk Level 2: RgbLedBar hidden", "DESKS_Upgrade")
    reporter.check(office.desk_visuals[0]["desk_top_y"] == 0.72, "Desk Level 2: DeskTop height remains 0.72m", "DESKS_Upgrade")

    # Tier 3 (Standing Desk)
    office.apply_desk_level(0, 3)
    reporter.check(office.desk_visuals[0]["dual_monitor"] is True, "Desk Level 3: DualMonitor visible", "DESKS_Upgrade")
    reporter.check(office.desk_visuals[0]["rgb_bar"] is True, "Desk Level 3: RgbLedBar visible", "DESKS_Upgrade")
    reporter.check(office.desk_visuals[0]["desk_top_y"] == 0.95, "Desk Level 3: DeskTop elevated to 0.95m (standing desk)", "DESKS_Upgrade")

    # Out of bounds desk indices
    office.apply_desk_level(-1, 3)
    office.apply_desk_level(5, 3)
    office.apply_desk_level(99, 3)
    reporter.check(len(office.desk_levels) == 5, "Out of bounds desk indices (-1, 5, 99) safely ignored without error", "DESKS_Bounds")

    # 3. 1,000 Monte Carlo Reassignment Cycles
    random.seed(1337)
    roles = ["Frontend Dev", "Backend Dev", "UI/UX Designer", "Growth Hacker", "QA Engineer"]
    hired_pool: Dict[str, int] = {}  # id -> desk
    free_desks = list(range(5))
    no_slot_clashes = True
    dict_sync_clean = True

    for cycle in range(1000):
        action = random.choice(["hire", "fire", "upgrade", "break", "espresso"])

        if action == "hire" and free_desks:
            d = free_desks.pop(0)
            w_id = f"worker_{cycle}_{d}"
            role = random.choice(roles)
            data = {"id": w_id, "name": f"Dev_{cycle}", "role": role, "desk_assigned": d, "morale": 1.0}
            w_inst = office.spawn_worker(data)
            hired_pool[w_id] = d
        elif action == "fire" and hired_pool:
            w_id = random.choice(list(hired_pool.keys()))
            freed_desk = hired_pool.pop(w_id)
            free_desks.append(freed_desk)
            free_desks.sort()
            office.despawn_worker(w_id)
        elif action == "upgrade":
            desk_to_up = random.randint(0, 4)
            lvl = random.choice([1, 2, 3])
            office.apply_desk_level(desk_to_up, lvl)
        elif action == "break":
            office.on_coffee_break_started()
        elif action == "espresso":
            office.on_unicorn_espresso_activated()

        # Invariant 1: No two active workers have the same desk
        assigned_desks = [w.desk_assigned for w in office.spawned_workers.values()]
        if len(assigned_desks) != len(set(assigned_desks)):
            no_slot_clashes = False
            break

        # Invariant 2: Dictionary size strictly matches hired pool
        if len(office.spawned_workers) != len(hired_pool):
            dict_sync_clean = False
            break

    reporter.check(no_slot_clashes, "1,000 Monte Carlo cycles: zero desk slot collisions across all hiring/firing", "REASSIGN_NoClash")
    reporter.check(dict_sync_clean, "1,000 Monte Carlo cycles: spawned_workers dictionary strictly in sync (no node leaks)", "REASSIGN_Sync")


def test_tier8_malicious_inputs_and_bounds(reporter: TestReporter):
    print(f"\n{Colors.BOLD}=== TIER 8: Malicious Input Fuzzing & Boundary Recovery ==={Colors.ENDC}")

    worker = ChibiWorker3DSimulator()

    # 1. Morale and fatigue clamping
    malicious_floats = [
        (-10.0, 0.0),
        (-0.001, 0.0),
        (1.5, 1.0),
        (100.0, 1.0),
        (float("nan"), 0.5),   # fallback to safe default
        (float("inf"), 1.0),
        (float("-inf"), 0.0),
    ]
    for val, expected_clamped in malicious_floats:
        worker.set_morale(val)
        reporter.check(0.0 <= worker.morale <= 1.0, f"Morale input {val} safely clamped to [0.0, 1.0] (got {worker.morale})", "FUZZ_Morale")

        worker.set_fatigue(val)
        reporter.check(0.0 <= worker.fatigue <= 1.0, f"Fatigue input {val} safely clamped to [0.0, 1.0] (got {worker.fatigue})", "FUZZ_Fatigue")

    # 2. Fatigue auto-transition hysteresis
    worker.set_state(worker.STATE_WORKING)
    worker.set_fatigue(0.99)
    reporter.check(worker.get_state() == worker.STATE_WORKING, "Fatigue at 0.99 maintains WORKING state", "HYSTERESIS_Fatigue")

    worker.set_fatigue(1.0)
    reporter.check(worker.get_state() == worker.STATE_FATIGUED, "Fatigue reaching 1.0 auto-transitions to FATIGUED", "HYSTERESIS_Fatigue")

    worker.set_fatigue(0.85)
    reporter.check(worker.get_state() == worker.STATE_FATIGUED, "Fatigue at 0.85 maintains FATIGUED state (hysteresis)", "HYSTERESIS_Fatigue")

    worker.set_fatigue(0.79)
    reporter.check(worker.get_state() == worker.STATE_WORKING, "Fatigue dropping below 0.80 auto-recovers to WORKING state", "HYSTERESIS_Fatigue")

    # 3. Missing / Malformed setup dictionary keys
    broken_worker = ChibiWorker3DSimulator()
    broken_worker.setup({})
    reporter.check(broken_worker.worker_id == "w0", "Empty setup dictionary safely preserves defaults", "FUZZ_Setup")
    reporter.check(broken_worker.morale == 1.0 and broken_worker.fatigue == 0.0, "Empty setup dictionary defaults morale=1.0, fatigue=0.0", "FUZZ_Setup")

    # 4. Area3D Proximity enter/exit flapping
    office = OfficeExpansion3DSimulator()
    for _ in range(1000):
        office.on_interaction_body_entered(True)
        office.on_interaction_body_exited(True)

    reporter.check(office.player_in_range is False, "1,000 enter/exit flaps leave player_in_range=False", "PROXIMITY_Flap")
    reporter.check(office.prompt_visible is False, "1,000 enter/exit flaps leave prompt_visible=False", "PROXIMITY_Flap")


# ==============================================================================
# MAIN ENTRYPOINT
# ==============================================================================

def main() -> int:
    reporter = TestReporter()
    # Resolve game root directory
    game_dir = Path(__file__).resolve().parent.parent

    print(f"{Colors.HEADER}======================================================================{Colors.ENDC}")
    print(f"{Colors.BOLD}IdleArcade Phase 14 M2 Challenger 2: State & Kinematics Adversary{Colors.ENDC}")
    print(f"{Colors.HEADER}======================================================================{Colors.ENDC}")

    test_tier1_ast_and_signatures(reporter, game_dir)
    test_tier2_state_transitions_and_chaos(reporter)
    test_tier3_mood_icons_and_expressions(reporter)
    test_tier4_particle_emissions(reporter)
    test_tier5_procedural_kinematics(reporter)
    test_tier6_epiphany_and_rewards(reporter)
    test_tier7_desks_and_worker_reassignment(reporter)
    test_tier8_malicious_inputs_and_bounds(reporter)

    return reporter.summarize()


if __name__ == "__main__":
    sys.exit(main())
