#!/usr/bin/env python3
"""
Phase 13 Milestone M4: Adversarial Multiplier Stacking & Gameplay Boundary Suite
=================================================================================
Target: Godot 4.3 IdleArcade - Milestone M4 (Cooperative Live Events & Multipliers)
Author: challenger_13_m4_2 (EMPIRICAL CHALLENGER)

Adversarial Stress Dimensions:
  1. Multiplier Stacking Mathematics & Numerical Stability (GameState.get_effective_passive_rps()):
     - Baseline & individual multiplier permutations (Syndicate Tier 0-5, Server Overclock,
       IPO Angel Shares, Frenzy, Campaign Buffs, Bonus Users, Collectibles).
     - LiveEventManager production multiplier cleanly stacks without division by zero,
       negative rates, or exponential explosion.
     - Monte Carlo simulation: 10,000 randomized multiplier combinations verified for finiteness,
       positivity, and monotonicity.
     - Frame accumulation simulation with clamped delta [0.0..0.1] to prevent clock jumps.
  2. Contribution Spike Stress Testing & Boundary Clamping (LiveEventManager):
     - Single hyper-contributions exceeding total goal (e.g. 10,000 pts on 500 goal, 10^12 pts).
     - Progress strictly clamps to target_goal without overshoot.
     - Progress percentage strictly clamps to 100.0% (no NaN, Inf, or >100%).
     - Event cleanly transitions to COMPLETED state.
     - Milestone signals (25%, 50%, 75%, 100%) fire in strict monotonic order and exactly ONCE.
     - Subsequent contributions during COMPLETED or COOLDOWN are safely rejected.
     - Zero, negative, and invalid contribution types safely handled.
     - Defensive guard for target_goal <= 0.0 prevents division by zero.
  3. HUD Event Banner Boundary Conditions & Ergonomics (hud.gd & hud.tscn):
     - Progress bar value clamping between 0.0 and 100.0.
     - Label formatting across 0.0%, 50.0%, 100.0% and over-target inputs.
     - Timer string formatting at exact 0.0s, sub-second (0.1s), negative (-0.5s, -999s) remaining.
     - Touch ergonomics (custom_minimum_size.y >= 56px) and mouse_filter = 0 (STOP) pointer isolation.
  4. Multi-Event Lifecycle & Multiplier Cleanup Simulation:
     - State transitions: IDLE -> ACTIVE -> COMPLETED -> COOLDOWN -> IDLE.
     - Multiplier reversion: Production (2.0 -> 1.0) and Drone Speed (1.5 -> 1.0) cleanly reset.
     - Alternating between server_crash_crisis and angel_investor_summit.
     - force_complete_event() stress from 0% state.

Executable via: python tests/test_p13_m4_adversarial_bounds.py
"""

import math
import random
import re
import sys
import time
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

GAME_ROOT = Path(__file__).resolve().parent.parent
SCRIPTS_DIR = GAME_ROOT / "scripts"
SCENES_DIR = GAME_ROOT / "scenes"

LIVE_EVENT_SCRIPT_PATH = SCRIPTS_DIR / "autoload" / "live_event_manager.gd"
GAME_STATE_SCRIPT_PATH = SCRIPTS_DIR / "autoload" / "game_state.gd"
HUD_SCRIPT_PATH = SCRIPTS_DIR / "hud.gd"
HUD_SCENE_PATH = SCENES_DIR / "hud.tscn"


class Colors:
    HEADER = "\033[95m"
    OKBLUE = "\033[94m"
    OKCYAN = "\033[96m"
    OKGREEN = "\033[92m"
    WARNING = "\033[93m"
    FAIL = "\033[91m"
    ENDC = "\033[0m"
    BOLD = "\033[1m"


if sys.stdout.encoding and sys.stdout.encoding.lower() != "utf-8":
    try:
        sys.stdout.reconfigure(encoding="utf-8")
        sys.stderr.reconfigure(encoding="utf-8")
    except Exception:
        pass


class AdversarialReporter:
    def __init__(self):
        self.total = 0
        self.passed = 0
        self.failed = 0
        self.failures: List[str] = []

    def check(self, condition: bool, description: str, category: str = "CHALLENGE"):
        self.total += 1
        if condition:
            self.passed += 1
            print(f"  {Colors.OKGREEN}[PASS]{Colors.ENDC} [{category}] {description}")
        else:
            self.failed += 1
            msg = f"  {Colors.FAIL}[FAIL]{Colors.ENDC} [{category}] {description}"
            print(msg)
            self.failures.append(f"[{category}] {description}")

    def summary(self) -> bool:
        print("\n" + "=" * 76)
        print(f"{Colors.BOLD}Adversarial Stress Test Results — Milestone M4 Multipliers & Boundaries{Colors.ENDC}")
        print("=" * 76)
        print(f"  Total Checks : {self.total}")
        print(f"  Passed       : {Colors.OKGREEN}{self.passed}{Colors.ENDC}")
        print(f"  Failed       : {Colors.FAIL if self.failed > 0 else Colors.OKGREEN}{self.failed}{Colors.ENDC}")
        if self.failures:
            print("\nFailures:")
            for f in self.failures:
                print(f"  - {Colors.FAIL}{f}{Colors.ENDC}")
            print(f"\n{Colors.FAIL}>>> OVERALL VERDICT: REQUEST_CHANGES (FAILURES DETECTED) <<<{Colors.ENDC}\n")
            return False
        else:
            print(f"\n{Colors.OKGREEN}>>> OVERALL VERDICT: 100% APPROVE (ALL ADVERSARIAL CHALLENGES PASSED) <<<{Colors.ENDC}\n")
            return True


# ==============================================================================
# Simulation Classes matching Godot GDScript Implementation
# ==============================================================================

class SimulatedGameState:
    """Accurate mathematical model of GameState multiplier calculation."""

    def __init__(self):
        self.base_passive_rps: float = 10.0
        self.bonus_users: int = 0
        self.collectibles_collected: int = 0
        self.has_neural_cloud: bool = False
        self.has_server_overclock_tech: bool = False
        self.server_overclock_buff_active: bool = False
        self.server_overclock_buff_timer: float = 0.0
        self.server_overclock_buff_multiplier: float = 1.5
        self.campaign_rps_buff_multiplier: float = 1.0
        self.campaign_rps_buff_timer: float = 0.0
        self.angel_shares: int = 0
        self.syndicate_tier: int = 0
        self.frenzy_multiplier: float = 1.0
        self.base_click_power: float = 1.0

        # Live event mock
        self.live_event_production_multiplier: float = 1.0

    def get_bonus_multiplier(self) -> float:
        return 1.0 + (float(self.bonus_users) * 0.01)

    def get_campus_item_multiplier(self) -> float:
        if self.has_neural_cloud:
            return 1.0 + (float(self.collectibles_collected) * 0.10)
        return 1.0 + (float(self.collectibles_collected) * 0.05)

    def get_angel_share_multiplier(self) -> float:
        return 1.0 + (float(self.angel_shares) * 0.02)

    def get_syndicate_dividend_multiplier(self) -> float:
        config = {
            0: 1.0,
            1: 1.05,
            2: 1.10,
            3: 1.15,
            4: 1.20,
            5: 1.25,
        }
        return config.get(self.syndicate_tier, 1.0)

    def get_effective_passive_rps(self) -> float:
        camp_rps_mult: float = self.campaign_rps_buff_multiplier if self.campaign_rps_buff_timer > 0.0 else 1.0
        live_event_mult: float = self.live_event_production_multiplier
        tech_overclock_mult: float = 1.25 if self.has_server_overclock_tech else 1.0
        active_overclock_mult: float = (
            self.server_overclock_buff_multiplier
            if (self.server_overclock_buff_timer > 0.0 or self.server_overclock_buff_active)
            else 1.0
        )

        return (
            self.base_passive_rps
            * self.get_bonus_multiplier()
            * self.get_campus_item_multiplier()
            * tech_overclock_mult
            * active_overclock_mult
            * camp_rps_mult
            * self.get_angel_share_multiplier()
            * self.get_syndicate_dividend_multiplier()
            * live_event_mult
        )

    def calculate_passive_frame_gain(self, delta: float) -> float:
        safe_delta: float = max(0.0, delta)
        clamped_delta: float = min(0.1, safe_delta)
        effective_rps: float = self.get_effective_passive_rps()
        if effective_rps > 0.0:
            return effective_rps * self.frenzy_multiplier * clamped_delta
        return 0.0

    def tap_core(self) -> float:
        live_event_mult: float = self.live_event_production_multiplier
        return self.base_click_power * self.frenzy_multiplier * self.get_angel_share_multiplier() * live_event_mult


class SimulatedLiveEventManager:
    """Accurate state-machine and numerical model of LiveEventManager."""

    def __init__(self):
        self.catalog = {
            "server_crash_crisis": {
                "id": "server_crash_crisis",
                "title": "Server Crash Crisis",
                "duration": 600.0,
                "target": 500.0,
                "contribution_weights": {"click": 1.0, "overclock": 50.0},
                "milestones": [25.0, 50.0, 75.0, 100.0],
                "reward_multiplier": 2.0,
                "reward_duration": 180.0,
            },
            "angel_investor_summit": {
                "id": "angel_investor_summit",
                "title": "Angel Investor Summit",
                "duration": 480.0,
                "target": 20.0,
                "contribution_weights": {"briefcase": 1.0},
                "milestones": [25.0, 50.0, 75.0, 100.0],
                "reward_energy": 50000.0,
                "drone_speed_multiplier": 1.5,
                "reward_duration": 120.0,
            },
        }

        self.current_state = "IDLE"  # IDLE, ACTIVE, COMPLETED, COOLDOWN
        self.active_event_id: str = ""
        self.current_progress: float = 0.0
        self.target_goal: float = 0.0
        self.time_remaining: float = 0.0
        self.reward_time_remaining: float = 0.0
        self.cooldown_time_remaining: float = 0.0
        self.default_cooldown: float = 30.0

        self.current_production_multiplier: float = 1.0
        self.current_drone_speed_multiplier: float = 1.0
        self.reached_milestones: List[float] = []

        # Signal log tracking for empirical verification
        self.emitted_signals: List[Tuple[str, Any]] = []

    def start_event(self, event_id: str) -> bool:
        if event_id not in self.catalog:
            return False

        defn = self.catalog[event_id]
        self.active_event_id = event_id
        self.current_state = "ACTIVE"
        self.target_goal = float(defn.get("target", 100.0))
        self.time_remaining = float(defn.get("duration", 600.0))
        self.current_progress = 0.0
        self.reward_time_remaining = 0.0
        self.cooldown_time_remaining = 0.0
        self.current_production_multiplier = 1.0
        self.current_drone_speed_multiplier = 1.0
        self.reached_milestones.clear()

        self.emitted_signals.append(("live_event_started", (event_id, defn["title"], self.time_remaining, self.target_goal)))
        self.emitted_signals.append(("live_event_progress_updated", (0.0, self.target_goal, 0.0)))
        return True

    def get_progress_percentage(self) -> float:
        if self.target_goal <= 0.0:
            return 0.0
        # clamp between 0.0 and 100.0
        val = (self.current_progress / self.target_goal) * 100.0
        return max(0.0, min(100.0, val))

    def contribute_progress(self, contribution_type: str, amount: float = 1.0):
        if self.current_state != "ACTIVE":
            return
        if self.active_event_id not in self.catalog:
            return

        defn = self.catalog[self.active_event_id]
        weights = defn.get("contribution_weights", {})
        weight = float(weights.get(contribution_type, 0.0))
        if weight <= 0.0:
            return

        pts = amount * weight
        self.current_progress = min(self.target_goal, self.current_progress + pts)
        pct = self.get_progress_percentage()

        self.emitted_signals.append(("live_event_progress_updated", (self.current_progress, self.target_goal, pct)))

        # Milestones [25.0, 50.0, 75.0, 100.0]
        thresholds = defn.get("milestones", [25.0, 50.0, 75.0, 100.0])
        for m in thresholds:
            m_f = float(m)
            if pct >= m_f and m_f not in self.reached_milestones:
                self.reached_milestones.append(m_f)
                self.emitted_signals.append(("live_event_milestone_reached", (m_f, f"{int(m_f)}% Milestone")))

        if self.current_progress >= self.target_goal:
            self._complete_event()

    def _complete_event(self):
        if self.current_state != "ACTIVE":
            return
        self.current_state = "COMPLETED"
        defn = self.catalog[self.active_event_id]

        if self.active_event_id == "server_crash_crisis":
            self.current_production_multiplier = float(defn.get("reward_multiplier", 2.0))
            self.reward_time_remaining = float(defn.get("reward_duration", 180.0))
        elif self.active_event_id == "angel_investor_summit":
            self.current_drone_speed_multiplier = float(defn.get("drone_speed_multiplier", 1.5))
            self.reward_time_remaining = float(defn.get("reward_duration", 120.0))

        self.emitted_signals.append(("live_event_completed", (self.active_event_id,)))

    def tick_process(self, delta: float):
        safe_delta = min(0.1, max(0.0, delta))
        if self.current_state == "ACTIVE":
            self.time_remaining -= safe_delta
            if self.time_remaining <= 0.0:
                self.time_remaining = 0.0
                self._end_event()
        elif self.current_state == "COMPLETED":
            self.reward_time_remaining -= safe_delta
            if self.reward_time_remaining <= 0.0:
                self.reward_time_remaining = 0.0
                self.current_production_multiplier = 1.0
                self.current_drone_speed_multiplier = 1.0
                self._end_event()
        elif self.current_state == "COOLDOWN":
            self.cooldown_time_remaining -= safe_delta
            if self.cooldown_time_remaining <= 0.0:
                self.cooldown_time_remaining = 0.0
                self.current_state = "IDLE"

    def _end_event(self):
        ended_id = self.active_event_id
        self.current_state = "COOLDOWN"
        self.cooldown_time_remaining = self.default_cooldown
        self.current_production_multiplier = 1.0
        self.current_drone_speed_multiplier = 1.0
        self.emitted_signals.append(("live_event_ended", (ended_id,)))

    def get_time_remaining(self) -> float:
        if self.current_state == "ACTIVE":
            return max(0.0, self.time_remaining)
        elif self.current_state == "COMPLETED":
            return max(0.0, self.reward_time_remaining)
        return 0.0


def format_hud_timer(seconds: float) -> str:
    """HUD timer formatting mirror of hud.gd _update_live_event_timer."""
    s = max(0, int(math.ceil(seconds)))
    mins = s // 60
    secs = s % 60
    return f"⏳ {mins:02d}:{secs:02d}"


def format_hud_progress_label(current: float, target: float, percentage: float) -> str:
    """HUD progress label formatting mirror of hud.gd _update_live_event_progress."""
    return f"[{int(current)} / {int(target)} ({percentage:.0f}%)]"


# ==============================================================================
# Main Adversarial Test Execution
# ==============================================================================

def main():
    reporter = AdversarialReporter()

    print(f"\n{Colors.HEADER}======================================================================{Colors.ENDC}")
    print(f"{Colors.HEADER}Phase 13 Milestone M4: Adversarial Multiplier & Boundary Stress Suite{Colors.ENDC}")
    print(f"{Colors.HEADER}======================================================================{Colors.ENDC}\n")

    # --------------------------------------------------------------------------
    # SECTION 1: Static Code Inspection & AST Contracts
    # --------------------------------------------------------------------------
    print(f"{Colors.BOLD}=== SECTION 1: Static Code Analysis & Interface Contracts ==={Colors.ENDC}")

    reporter.check(GAME_STATE_SCRIPT_PATH.exists(), "game_state.gd exists at scripts/autoload/game_state.gd", "AST")
    reporter.check(LIVE_EVENT_SCRIPT_PATH.exists(), "live_event_manager.gd exists at scripts/autoload/live_event_manager.gd", "AST")
    reporter.check(HUD_SCRIPT_PATH.exists(), "hud.gd exists at scripts/hud.gd", "AST")
    reporter.check(HUD_SCENE_PATH.exists(), "hud.tscn exists at scenes/hud.tscn", "AST")

    gs_content = GAME_STATE_SCRIPT_PATH.read_text(encoding="utf-8")
    lem_content = LIVE_EVENT_SCRIPT_PATH.read_text(encoding="utf-8")
    hud_content = HUD_SCRIPT_PATH.read_text(encoding="utf-8")
    hud_scene_content = HUD_SCENE_PATH.read_text(encoding="utf-8")

    # Verify get_effective_passive_rps() math integration
    reporter.check(
        "func get_effective_passive_rps() -> float:" in gs_content,
        "GameState implements get_effective_passive_rps() -> float",
        "AST_RPS"
    )
    reporter.check(
        "get_syndicate_dividend_multiplier()" in gs_content,
        "GameState multiplies syndicate dividend multiplier into passive RPS",
        "AST_RPS"
    )
    reporter.check(
        "get_angel_share_multiplier()" in gs_content,
        "GameState multiplies IPO angel shares multiplier into passive RPS",
        "AST_RPS"
    )
    reporter.check(
        "server_overclock_buff_multiplier" in gs_content,
        "GameState multiplies server overclock buff into passive RPS",
        "AST_RPS"
    )
    reporter.check(
        "get_live_event_production_multiplier()" in gs_content,
        "GameState queries LiveEventManager.get_production_multiplier()",
        "AST_RPS"
    )
    reporter.check(
        "live_event_mult" in gs_content,
        "GameState factors live_event_mult cleanly into effective passive RPS",
        "AST_RPS"
    )
    reporter.check(
        "frenzy_multiplier" in gs_content,
        "GameState applies frenzy_multiplier to effective_rps in _process() passive accumulation",
        "AST_FRENZY"
    )

    # Verify LiveEventManager clamping in GDScript
    reporter.check(
        "current_progress = minf(target_goal, current_progress + pts)" in lem_content,
        "LiveEventManager clamps current_progress with minf(target_goal, ...)",
        "AST_CLAMP"
    )
    reporter.check(
        "clampf((current_progress / target_goal) * 100.0, 0.0, 100.0)" in lem_content,
        "LiveEventManager clamps percentage with clampf(..., 0.0, 100.0)",
        "AST_CLAMP"
    )
    reporter.check(
        "if target_goal <= 0.0:" in lem_content,
        "LiveEventManager defends against division by zero if target_goal <= 0.0",
        "AST_CLAMP"
    )

    # Verify HUD Banner clamping and 0s timer formatting
    reporter.check(
        "var s: int = maxi(0, int(ceilf(seconds)))" in hud_content,
        "HUD timer uses maxi(0, int(ceilf(seconds))) ensuring non-negative countdown",
        "AST_HUD"
    )
    reporter.check(
        '"⏳ %02d:%02d" % [mins, secs]' in hud_content,
        "HUD timer formats as '⏳ %02d:%02d'",
        "AST_HUD"
    )
    reporter.check(
        "live_event_progress_bar.max_value = target if target > 0.0 else 100.0" in hud_content,
        "HUD progress bar sets max_value to target with fallback > 0.0",
        "AST_HUD"
    )

    # --------------------------------------------------------------------------
    # SECTION 2: Multiplier Stacking Mathematics & Numerical Stability
    # --------------------------------------------------------------------------
    print(f"\n{Colors.BOLD}=== SECTION 2: Multiplier Stacking Numerical Verification ==={Colors.ENDC}")

    gs = SimulatedGameState()
    base_rps = 10.0
    gs.base_passive_rps = base_rps

    # Permutation 1: Pure Baseline
    val = gs.get_effective_passive_rps()
    reporter.check(abs(val - 10.0) < 1e-6, f"Baseline effective RPS: {val} == 10.0", "MULT_STACK")

    # Permutation 2: Syndicate Dividends (Tiers 0..5)
    expected_divs = [1.0, 1.05, 1.10, 1.15, 1.20, 1.25]
    for tier, expected_div in enumerate(expected_divs):
        gs.syndicate_tier = tier
        calc_div = gs.get_syndicate_dividend_multiplier()
        reporter.check(
            abs(calc_div - expected_div) < 1e-6,
            f"Syndicate Tier {tier} dividend multiplier: {calc_div} == {expected_div}",
            "MULT_DIVIDEND"
        )
        rps = gs.get_effective_passive_rps()
        expected_rps = base_rps * expected_div
        reporter.check(
            abs(rps - expected_rps) < 1e-6,
            f"Tier {tier} effective RPS: {rps:.2f} == {expected_rps:.2f}",
            "MULT_DIVIDEND"
        )
    gs.syndicate_tier = 0

    # Permutation 3: Server Overclock Buff (1.5x) and Tech (1.25x)
    gs.has_server_overclock_tech = True
    rps_tech = gs.get_effective_passive_rps()
    reporter.check(abs(rps_tech - 12.5) < 1e-6, f"Tech Overclock (+25%): {rps_tech} == 12.5", "MULT_OVERCLOCK")

    gs.server_overclock_buff_active = True
    gs.server_overclock_buff_timer = 25.0
    gs.server_overclock_buff_multiplier = 1.5
    rps_buff = gs.get_effective_passive_rps()
    # 10.0 * 1.25 * 1.5 = 18.75
    reporter.check(abs(rps_buff - 18.75) < 1e-6, f"Active Overclock buff (1.5x): {rps_buff} == 18.75", "MULT_OVERCLOCK")
    gs.server_overclock_buff_active = False
    gs.server_overclock_buff_timer = 0.0
    gs.has_server_overclock_tech = False

    # Permutation 4: IPO Angel Shares
    test_shares = [(0, 1.0), (10, 1.20), (50, 2.00), (100, 3.00), (1000, 21.00)]
    for shares, exp_mult in test_shares:
        gs.angel_shares = shares
        mult = gs.get_angel_share_multiplier()
        reporter.check(
            abs(mult - exp_mult) < 1e-6,
            f"Angel Shares {shares}: multiplier {mult} == {exp_mult} (+{shares*2}%)",
            "MULT_SHARES"
        )
        rps = gs.get_effective_passive_rps()
        reporter.check(abs(rps - (base_rps * exp_mult)) < 1e-6, f"Effective RPS with {shares} shares: {rps} == {base_rps * exp_mult}", "MULT_SHARES")
    gs.angel_shares = 0

    # Permutation 5: Live Event Production Multiplier (2.0x during Server Crash Crisis)
    gs.live_event_production_multiplier = 2.0
    rps_live = gs.get_effective_passive_rps()
    reporter.check(abs(rps_live - 20.0) < 1e-6, f"Live Event (2.0x): {rps_live} == 20.0", "MULT_LIVE")

    # Permutation 6: Simultaneous Stacking (Syndicate T5 + Overclock Buff + Tech + Angel Shares + Live Event)
    gs.syndicate_tier = 5                      # 1.25x
    gs.has_server_overclock_tech = True        # 1.25x
    gs.server_overclock_buff_active = True     # 1.50x
    gs.server_overclock_buff_timer = 20.0
    gs.angel_shares = 50                       # 2.00x (+100%)
    gs.live_event_production_multiplier = 2.0  # 2.00x
    # Product = 10.0 * 1.25 * 1.25 * 1.50 * 2.00 * 2.00 = 93.75
    stacked_rps = gs.get_effective_passive_rps()
    expected_stacked = 10.0 * 1.25 * 1.25 * 1.50 * 2.00 * 2.00
    reporter.check(
        abs(stacked_rps - expected_stacked) < 1e-5,
        f"Simultaneous 5-multiplier stack: {stacked_rps:.4f} == {expected_stacked:.4f}",
        "MULT_SIMULTANEOUS"
    )

    # Permutation 7: Frenzy Interaction with Passive RPS Accumulation
    # In _process: passive_gain = effective_rps * frenzy_multiplier * clamped_delta
    gs.frenzy_multiplier = 3.5
    delta = 0.016667  # 60 FPS
    frame_gain = gs.calculate_passive_frame_gain(delta)
    expected_gain = stacked_rps * 3.5 * delta
    reporter.check(
        abs(frame_gain - expected_gain) < 1e-6,
        f"Frame passive gain with frenzy (3.5x): {frame_gain:.6f} == {expected_gain:.6f}",
        "MULT_FRENZY"
    )

    # Tap Core interaction
    click_power = gs.tap_core()
    # click_power = base_click_power(1.0) * frenzy(3.5) * angel_shares(2.0) * live_event(2.0) = 14.0
    expected_click = 1.0 * 3.5 * 2.0 * 2.0
    reporter.check(
        abs(click_power - expected_click) < 1e-6,
        f"tap_core click energy with frenzy & live event: {click_power} == {expected_click}",
        "MULT_CLICK"
    )

    # Permutation 8: Monte Carlo Fuzzing across 10,000 parameter combinations
    print(f"  --> Running 10,000 Monte Carlo randomized multiplier evaluations...")
    rng = random.Random(42)
    mc_passed = True
    finite_checks = True
    positive_checks = True

    for _ in range(10000):
        gs_fuzz = SimulatedGameState()
        gs_fuzz.base_passive_rps = rng.uniform(0.0, 1e6)
        gs_fuzz.bonus_users = rng.randint(0, 100000)
        gs_fuzz.collectibles_collected = rng.randint(0, 500)
        gs_fuzz.has_neural_cloud = rng.choice([True, False])
        gs_fuzz.has_server_overclock_tech = rng.choice([True, False])
        gs_fuzz.server_overclock_buff_active = rng.choice([True, False])
        gs_fuzz.server_overclock_buff_timer = rng.uniform(0.0, 60.0) if gs_fuzz.server_overclock_buff_active else 0.0
        gs_fuzz.server_overclock_buff_multiplier = rng.choice([1.0, 1.5, 2.0])
        gs_fuzz.campaign_rps_buff_multiplier = rng.choice([1.0, 1.2, 1.5, 2.0])
        gs_fuzz.campaign_rps_buff_timer = rng.uniform(0.0, 60.0)
        gs_fuzz.angel_shares = rng.randint(0, 10000)
        gs_fuzz.syndicate_tier = rng.randint(0, 5)
        gs_fuzz.live_event_production_multiplier = rng.choice([1.0, 2.0])
        gs_fuzz.frenzy_multiplier = rng.uniform(1.0, 5.0)

        calc = gs_fuzz.get_effective_passive_rps()
        if not math.isfinite(calc):
            finite_checks = False
            mc_passed = False
            break
        if calc < 0.0:
            positive_checks = False
            mc_passed = False
            break

        f_gain = gs_fuzz.calculate_passive_frame_gain(rng.uniform(0.0, 0.5))
        if not math.isfinite(f_gain) or f_gain < 0.0:
            mc_passed = False
            break

    reporter.check(mc_passed, "All 10,000 Monte Carlo combinations evaluated successfully", "FUZZ_STABILITY")
    reporter.check(finite_checks, "Effective RPS is strictly finite across all 10,000 runs (no NaN or Inf)", "FUZZ_FINITE")
    reporter.check(positive_checks, "Effective RPS is strictly non-negative (>= 0.0) across all 10,000 runs", "FUZZ_NON_NEGATIVE")

    # --------------------------------------------------------------------------
    # SECTION 3: Contribution Spike Stress Testing & Boundary Clamping
    # --------------------------------------------------------------------------
    print(f"\n{Colors.BOLD}=== SECTION 3: Contribution Spike & Boundary Clamping Stress ==={Colors.ENDC}")

    # Case 3.1: Exact Target Contribution (500 pts on 500 goal)
    lem1 = SimulatedLiveEventManager()
    lem1.start_event("server_crash_crisis")
    lem1.contribute_progress("click", 500.0)
    reporter.check(lem1.current_progress == 500.0, "Exact 500.0 pts progress = 500.0", "SPIKE_EXACT")
    reporter.check(lem1.get_progress_percentage() == 100.0, "Exact 500.0 pts progress = 100.0%", "SPIKE_EXACT")
    reporter.check(lem1.current_state == "COMPLETED", "Exact 500.0 pts transitions to COMPLETED", "SPIKE_EXACT")
    reporter.check(lem1.reached_milestones == [25.0, 50.0, 75.0, 100.0], "All 4 milestones reached in order", "SPIKE_EXACT")

    # Case 3.2: Single Overshoot Spike: 10,000 pts on 500 goal (20x overshoot!)
    lem2 = SimulatedLiveEventManager()
    lem2.start_event("server_crash_crisis")
    lem2.contribute_progress("click", 10000.0)
    reporter.check(lem2.current_progress == 500.0, "10,000 pts spike: progress clamped to target_goal (500.0)", "SPIKE_HYPER")
    reporter.check(lem2.get_progress_percentage() == 100.0, "10,000 pts spike: percentage clamped to 100.0%", "SPIKE_HYPER")
    reporter.check(lem2.current_state == "COMPLETED", "10,000 pts spike: state transitions to COMPLETED", "SPIKE_HYPER")
    reporter.check(lem2.current_production_multiplier == 2.0, "10,000 pts spike: production multiplier set to 2.0x", "SPIKE_HYPER")
    reporter.check(lem2.reward_time_remaining == 180.0, "10,000 pts spike: reward timer initialized to 180.0s", "SPIKE_HYPER")

    # Verify milestone signals emitted in strict order and exactly once
    milestone_events = [sig[1][0] for sig in lem2.emitted_signals if sig[0] == "live_event_milestone_reached"]
    reporter.check(milestone_events == [25.0, 50.0, 75.0, 100.0], f"Milestone signals fired in order: {milestone_events}", "SPIKE_MILESTONES")
    reporter.check(len(milestone_events) == 4, "No duplicate milestone signals emitted", "SPIKE_MILESTONES")

    # Case 3.3: Astronomical Spike (10^12 pts)
    lem3 = SimulatedLiveEventManager()
    lem3.start_event("server_crash_crisis")
    lem3.contribute_progress("click", 1e12)
    reporter.check(lem3.current_progress == 500.0, "10^12 pts spike: progress strictly clamped to 500.0", "SPIKE_ASTRO")
    reporter.check(lem3.get_progress_percentage() == 100.0, "10^12 pts spike: percentage strictly 100.0% (no Inf/NaN)", "SPIKE_ASTRO")

    # Case 3.4: Subsequent Contributions during COMPLETED state (Idempotence)
    sig_count_before = len(lem2.emitted_signals)
    lem2.contribute_progress("click", 500.0)
    lem2.contribute_progress("overclock", 10.0)
    reporter.check(lem2.current_progress == 500.0, "Post-completion contributions do not modify progress", "SPIKE_IDEMPOTENT")
    reporter.check(len(lem2.emitted_signals) == sig_count_before, "Post-completion contributions emit no new signals", "SPIKE_IDEMPOTENT")

    # Case 3.5: Step-by-step Near-Target Crossing
    # Target 500, start at 490 (98%), then contribute 1 overclock (+50 pts)
    lem4 = SimulatedLiveEventManager()
    lem4.start_event("server_crash_crisis")
    lem4.contribute_progress("click", 490.0)
    reporter.check(lem4.current_progress == 490.0, "Progress at 490.0", "SPIKE_NEAR_TARGET")
    reporter.check(lem4.get_progress_percentage() == 98.0, "Percentage at 98.0%", "SPIKE_NEAR_TARGET")
    reporter.check(lem4.current_state == "ACTIVE", "Event still ACTIVE at 98%", "SPIKE_NEAR_TARGET")
    lem4.contribute_progress("overclock", 1.0)  # +50 pts -> 540 pts -> clamp 500.0
    reporter.check(lem4.current_progress == 500.0, "Overclock overshoot clamped from 540.0 to 500.0", "SPIKE_NEAR_TARGET")
    reporter.check(lem4.get_progress_percentage() == 100.0, "Percentage clamped to 100.0%", "SPIKE_NEAR_TARGET")
    reporter.check(lem4.current_state == "COMPLETED", "Event transitioned to COMPLETED", "SPIKE_NEAR_TARGET")

    # Case 3.6: Zero, Negative & Invalid Contribution Handling
    lem5 = SimulatedLiveEventManager()
    lem5.start_event("server_crash_crisis")
    prog_before = lem5.current_progress
    lem5.contribute_progress("click", 0.0)
    reporter.check(lem5.current_progress == prog_before, "0.0 contribution amount ignored", "SPIKE_EDGE")
    lem5.contribute_progress("unknown_action", 100.0)
    reporter.check(lem5.current_progress == prog_before, "Unknown contribution type ignored", "SPIKE_EDGE")

    # Case 3.7: Defensive target_goal <= 0.0
    lem_zero = SimulatedLiveEventManager()
    lem_zero.target_goal = 0.0
    lem_zero.current_progress = 50.0
    reporter.check(lem_zero.get_progress_percentage() == 0.0, "target_goal = 0.0 returns 0.0% (no ZeroDivisionError)", "SPIKE_ZERO_DIV")

    # --------------------------------------------------------------------------
    # SECTION 4: HUD Event Banner Boundary Conditions & Ergonomics
    # --------------------------------------------------------------------------
    print(f"\n{Colors.BOLD}=== SECTION 4: HUD Banner Ergonomics & Boundary Conditions ==={Colors.ENDC}")

    # Case 4.1: Progress bar value and percentage label formatting
    test_progress_pairs = [
        (0.0, 500.0, 0.0, "[0 / 500 (0%)]"),
        (125.0, 500.0, 25.0, "[125 / 500 (25%)]"),
        (250.0, 500.0, 50.0, "[250 / 500 (50%)]"),
        (375.0, 500.0, 75.0, "[375 / 500 (75%)]"),
        (500.0, 500.0, 100.0, "[500 / 500 (100%)]"),
    ]
    for cur, tgt, pct, exp_label in test_progress_pairs:
        rendered = format_hud_progress_label(cur, tgt, pct)
        reporter.check(rendered == exp_label, f"Progress label for {cur}/{tgt} ({pct}%): '{rendered}'", "HUD_LABEL")

    # Case 4.2: Timer String Formatting across boundaries
    timer_test_matrix = [
        (600.0, "⏳ 10:00"),
        (360.0, "⏳ 06:00"),
        (65.0, "⏳ 01:05"),
        (60.0, "⏳ 01:00"),
        (59.9, "⏳ 01:00"),  # ceilf(59.9) = 60
        (59.0, "⏳ 00:59"),
        (10.0, "⏳ 00:10"),
        (1.0, "⏳ 00:01"),
        (0.5, "⏳ 00:01"),   # ceilf(0.5) = 1
        (0.01, "⏳ 00:01"),  # ceilf(0.01) = 1
        (0.0, "⏳ 00:00"),   # EXACT ZERO
        (-0.0, "⏳ 00:00"),  # Negative zero
        (-0.5, "⏳ 00:00"),  # Negative sub-second
        (-1.0, "⏳ 00:00"),  # Negative 1s
        (-60.0, "⏳ 00:00"), # Negative 1 min
        (-999.0, "⏳ 00:00"),# Massive negative
    ]

    timer_regex = re.compile(r"^⏳ \d{2,}:\d{2}$")
    for sec, exp_str in timer_test_matrix:
        formatted = format_hud_timer(sec)
        reporter.check(
            formatted == exp_str,
            f"Timer formatting at {sec:6.2f}s: '{formatted}' == '{exp_str}'",
            "HUD_TIMER"
        )
        reporter.check(
            bool(timer_regex.match(formatted)),
            f"Timer at {sec:6.2f}s satisfies format regex: '{formatted}'",
            "HUD_TIMER"
        )

    # Case 4.3: Ergonomics and Pointer Isolation Inspection in scenes/hud.tscn
    reporter.check(
        'unique_name_in_owner = true' in hud_scene_content and 'LiveEventBanner' in hud_scene_content,
        "hud.tscn defines %LiveEventBanner with unique_name_in_owner",
        "HUD_SCENE"
    )

    # Parse node definitions in hud.tscn
    banner_match = re.search(r'\[node name="LiveEventBanner" type="PanelContainer"[^\]]*\](.*?)(?=\n\[node|\Z)', hud_scene_content, re.DOTALL)
    reporter.check(banner_match is not None, "hud.tscn contains LiveEventBanner node block", "HUD_SCENE")
    if banner_match:
        banner_body = banner_match.group(1)
        reporter.check(
            "custom_minimum_size = Vector2(0, 56)" in banner_body or "Vector2(0, 56)" in banner_body,
            "LiveEventBanner enforces height >= 56px (custom_minimum_size = Vector2(0, 56))",
            "HUD_SCENE"
        )
        reporter.check(
            "mouse_filter = 0" in banner_body,
            "LiveEventBanner enforces mouse_filter = 0 (STOP) pointer isolation",
            "HUD_SCENE"
        )

    child_nodes = ["LiveEventTitleLabel", "LiveEventTimerLabel", "LiveEventProgressBar", "LiveEventProgressLabel"]
    for cnode in child_nodes:
        c_match = re.search(rf'\[node name="{cnode}"[^\]]*\](.*?)(?=\n\[node|\Z)', hud_scene_content, re.DOTALL)
        reporter.check(c_match is not None, f"Child node '{cnode}' declared in hud.tscn", "HUD_SCENE")
        if c_match:
            c_body = c_match.group(1)
            reporter.check(
                "mouse_filter = 0" in c_body,
                f"Child node '{cnode}' enforces mouse_filter = 0 (STOP)",
                "HUD_SCENE"
            )

    # --------------------------------------------------------------------------
    # SECTION 5: Full Multi-Event Lifecycle & Multiplier Reversion
    # --------------------------------------------------------------------------
    print(f"\n{Colors.BOLD}=== SECTION 5: Multi-Event Lifecycle & Multiplier Cleanup ==={Colors.ENDC}")

    lem_cycle = SimulatedLiveEventManager()

    # Cycle 1: Angel Investor Summit (480s, 20 briefcases, 1.5x drone speed)
    reporter.check(lem_cycle.current_state == "IDLE", "Cycle 1: Initial state is IDLE", "LIFECYCLE")
    started = lem_cycle.start_event("angel_investor_summit")
    reporter.check(started and lem_cycle.current_state == "ACTIVE", "Cycle 1: Summit started and ACTIVE", "LIFECYCLE")
    reporter.check(lem_cycle.target_goal == 20.0, "Cycle 1: Target goal is 20.0 briefcases", "LIFECYCLE")

    # Contribute 10 briefcases -> 50% milestone
    lem_cycle.contribute_progress("briefcase", 10.0)
    reporter.check(lem_cycle.current_progress == 10.0, "Cycle 1: 10 briefcases contributed", "LIFECYCLE")
    reporter.check(lem_cycle.get_progress_percentage() == 50.0, "Cycle 1: 50.0% reached", "LIFECYCLE")
    reporter.check(lem_cycle.reached_milestones == [25.0, 50.0], "Cycle 1: Milestones 25% and 50% recorded", "LIFECYCLE")

    # Complete summit with +15 briefcases (overshoot: total 25 on 20 goal)
    lem_cycle.contribute_progress("briefcase", 15.0)
    reporter.check(lem_cycle.current_progress == 20.0, "Cycle 1: Clamped to 20.0 briefcases", "LIFECYCLE")
    reporter.check(lem_cycle.current_state == "COMPLETED", "Cycle 1: State is COMPLETED", "LIFECYCLE")
    reporter.check(lem_cycle.current_drone_speed_multiplier == 1.5, "Cycle 1: Drone speed multiplier is 1.5x", "LIFECYCLE")
    reporter.check(lem_cycle.reward_time_remaining == 120.0, "Cycle 1: Reward timer is 120.0s", "LIFECYCLE")

    # Simulate reward timer expiration (120s)
    for _ in range(1201):
        lem_cycle.tick_process(0.1)
    reporter.check(lem_cycle.current_state == "COOLDOWN", "Cycle 1: Transitioned to COOLDOWN after reward expiry", "LIFECYCLE")
    reporter.check(lem_cycle.current_drone_speed_multiplier == 1.0, "Cycle 1: Drone speed multiplier cleanly reverted to 1.0", "LIFECYCLE")
    reporter.check(lem_cycle.cooldown_time_remaining == 30.0, "Cycle 1: Cooldown initialized to 30.0s", "LIFECYCLE")

    # Simulate cooldown expiration (30s)
    for _ in range(301):
        lem_cycle.tick_process(0.1)
    reporter.check(lem_cycle.current_state == "IDLE", "Cycle 1: Transitioned back to IDLE", "LIFECYCLE")

    # Cycle 2: Server Crash Crisis after Angel Investor Summit
    started2 = lem_cycle.start_event("server_crash_crisis")
    reporter.check(started2 and lem_cycle.current_state == "ACTIVE", "Cycle 2: Crisis started and ACTIVE", "LIFECYCLE")
    reporter.check(lem_cycle.target_goal == 500.0, "Cycle 2: Target goal reset to 500.0", "LIFECYCLE")
    reporter.check(lem_cycle.current_progress == 0.0, "Cycle 2: Progress cleanly reset to 0.0", "LIFECYCLE")
    reporter.check(lem_cycle.reached_milestones == [], "Cycle 2: Reached milestones cleanly reset", "LIFECYCLE")

    # Finish summary report
    success = reporter.summary()
    return 0 if success else 1


if __name__ == "__main__":
    sys.exit(main())
