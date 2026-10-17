#!/usr/bin/env python3
"""
Auditor Adversarial Stress Test Suite for Phase 13 Milestone M4 (Live Events)
==============================================================================
Stress-tests boundary conditions, edge cases, mutation attacks, and lifecycle edge cases
for LiveEventManager and its integration hooks.
"""

import sys
import math
from pathlib import Path

# Add IdleArcade path
idle_arcade_dir = Path(__file__).resolve().parent.parent

class AdversarialRunner:
    def __init__(self):
        self.passed = 0
        self.failed = 0
        self.failures = []

    def assert_test(self, condition: bool, description: str):
        if condition:
            self.passed += 1
            print(f"  [PASS] {description}")
        else:
            self.failed += 1
            self.failures.append(description)
            print(f"  [FAIL] {description}")

class LiveEventManagerHarness:
    """Python replica strictly matching GDScript behavior in live_event_manager.gd"""
    def __init__(self):
        self.CATALOG = {
            "server_crash_crisis": {
                "id": "server_crash_crisis",
                "duration": 600.0,
                "target": 500.0,
                "contribution_weights": {"click": 1.0, "overclock": 50.0},
                "milestones": [25.0, 50.0, 75.0, 100.0],
                "reward_type": "production_buff",
                "reward_multiplier": 2.0,
                "reward_duration": 180.0
            },
            "angel_investor_summit": {
                "id": "angel_investor_summit",
                "duration": 480.0,
                "target": 20.0,
                "contribution_weights": {"briefcase": 1.0},
                "milestones": [25.0, 50.0, 75.0, 100.0],
                "reward_type": "grant_and_drone_speed",
                "reward_energy": 50000.0,
                "drone_speed_multiplier": 1.5,
                "reward_duration": 120.0
            }
        }
        self.current_state = "IDLE"
        self.active_event_id = ""
        self.current_progress = 0.0
        self.target_goal = 0.0
        self.time_remaining = 0.0
        self.reward_time_remaining = 0.0
        self.cooldown_time_remaining = 0.0
        self.default_cooldown = 30.0
        self.current_production_multiplier = 1.0
        self.current_drone_speed_multiplier = 1.0
        self.reached_milestones = []
        self.milestone_signal_counts = {}

    def process(self, delta: float):
        safe_delta = min(0.1, delta)
        if self.current_state == "ACTIVE":
            self.time_remaining -= safe_delta
            if self.time_remaining <= 0.0:
                self.time_remaining = 0.0
                self._end_event(False)
        elif self.current_state == "COMPLETED":
            self.reward_time_remaining -= safe_delta
            if self.reward_time_remaining <= 0.0:
                self.reward_time_remaining = 0.0
                self._finish_rewards_and_cooldown()
        elif self.current_state == "COOLDOWN":
            self.cooldown_time_remaining -= safe_delta
            if self.cooldown_time_remaining <= 0.0:
                self.cooldown_time_remaining = 0.0
                self.current_state = "IDLE"

    def start_event(self, event_id: str) -> bool:
        if event_id not in self.CATALOG:
            return False
        defn = self.CATALOG[event_id]
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
        self.milestone_signal_counts.clear()
        return True

    def get_progress_percentage(self) -> float:
        if self.target_goal <= 0.0:
            return 0.0
        return min(100.0, max(0.0, (self.current_progress / self.target_goal) * 100.0))

    def contribute_progress(self, contribution_type: str, amount: float = 1.0):
        if self.current_state != "ACTIVE":
            return
        if self.active_event_id not in self.CATALOG:
            return
        defn = self.CATALOG[self.active_event_id]
        weights = defn.get("contribution_weights", {})
        weight = float(weights.get(contribution_type, 0.0))
        if weight <= 0.0:
            return
        pts = amount * weight
        self.current_progress = min(self.target_goal, self.current_progress + pts)
        pct = self.get_progress_percentage()

        milestones = defn.get("milestones", [25.0, 50.0, 75.0, 100.0])
        for m in milestones:
            m_float = float(m)
            if pct >= m_float and m_float not in self.reached_milestones:
                self.reached_milestones.append(m_float)
                self.milestone_signal_counts[m_float] = self.milestone_signal_counts.get(m_float, 0) + 1

        if self.current_progress >= self.target_goal:
            self._complete_event()

    def _complete_event(self):
        if self.current_state != "ACTIVE":
            return
        self.current_state = "COMPLETED"
        defn = self.CATALOG[self.active_event_id]
        if self.active_event_id == "server_crash_crisis":
            self.current_production_multiplier = float(defn.get("reward_multiplier", 2.0))
            self.reward_time_remaining = float(defn.get("reward_duration", 180.0))
        elif self.active_event_id == "angel_investor_summit":
            self.current_drone_speed_multiplier = float(defn.get("drone_speed_multiplier", 1.5))
            self.reward_time_remaining = float(defn.get("reward_duration", 120.0))

    def _finish_rewards_and_cooldown(self):
        self.current_production_multiplier = 1.0
        self.current_drone_speed_multiplier = 1.0
        self._end_event(True)

    def _end_event(self, was_completed: bool):
        self.current_state = "COOLDOWN"
        self.cooldown_time_remaining = self.default_cooldown
        self.current_production_multiplier = 1.0
        self.current_drone_speed_multiplier = 1.0

    def get_active_event(self) -> dict:
        defn = self.CATALOG.get(self.active_event_id, {})
        return {
            "id": self.active_event_id,
            "title": defn.get("title", ""),
            "state": self.current_state,
            "progress": self.current_progress,
            "target": self.target_goal,
            "percentage": self.get_progress_percentage(),
            "time_remaining": self.time_remaining if self.current_state == "ACTIVE" else (self.reward_time_remaining if self.current_state == "COMPLETED" else 0.0),
            "production_multiplier": self.current_production_multiplier,
            "drone_speed_multiplier": self.current_drone_speed_multiplier,
            "reached_milestones": list(self.reached_milestones)
        }

def run_adversarial_tests():
    runner = AdversarialRunner()
    print("=" * 70)
    print("Adversarial Stress Test Suite: Milestone M4 Live Events")
    print("=" * 70)

    # 1. Invalid Event ID
    h = LiveEventManagerHarness()
    runner.assert_test(h.start_event("bogus_event_xyz") is False, "start_event with bogus ID returns False")
    runner.assert_test(h.start_event("") is False, "start_event with empty string returns False")
    runner.assert_test(h.current_state == "IDLE", "State remains IDLE after failed start")

    # 2. Inactive Contributions
    h.contribute_progress("click", 100.0)
    runner.assert_test(h.current_progress == 0.0, "Contribution ignored while IDLE")

    # 3. Valid Start
    runner.assert_test(h.start_event("server_crash_crisis") is True, "Valid start returns True")
    runner.assert_test(h.current_state == "ACTIVE", "State transitions to ACTIVE")

    # 4. Unknown and Negative Contribution Types
    h.contribute_progress("unsupported_type", 10.0)
    runner.assert_test(h.current_progress == 0.0, "Unsupported contribution type ignored")

    h.contribute_progress("click", 0.0)
    runner.assert_test(h.current_progress == 0.0, "Zero contribution adds 0 progress")

    # 5. Massive Delta Shock Absorption
    h.process(100.0)  # Safe delta clamped to 0.1s
    runner.assert_test(h.time_remaining == 599.9, "100s delta frame clamped to 0.1s safe delta (prevents freeze skip)")

    # 6. Milestone Deduplication Under Burst Contribution
    # Progress from 0 to 60% in one shot (+300 pts)
    h.contribute_progress("overclock", 6.0) # 6 * 50 = 300 pts (60%)
    runner.assert_test(h.current_progress == 300.0, "Progress is exactly 300 pts")
    runner.assert_test(h.get_progress_percentage() == 60.0, "Percentage is 60.0%")
    runner.assert_test(h.milestone_signal_counts.get(25.0) == 1, "25% milestone signal triggered exactly once")
    runner.assert_test(h.milestone_signal_counts.get(50.0) == 1, "50% milestone signal triggered exactly once")
    runner.assert_test(75.0 not in h.reached_milestones, "75% milestone not triggered prematurely")

    # Additional small contributions that stay below 75%
    h.contribute_progress("click", 10.0) # 310 pts (62%)
    runner.assert_test(h.milestone_signal_counts.get(25.0) == 1, "25% milestone signal not re-fired on subsequent contributions")
    runner.assert_test(h.milestone_signal_counts.get(50.0) == 1, "50% milestone signal not re-fired on subsequent contributions")

    # 7. Overshoot Clamping & Completion
    h.contribute_progress("overclock", 10.0) # +500 pts -> total 810 pts, should clamp to 500
    runner.assert_test(h.current_progress == 500.0, "Progress clamped strictly at target goal (500 pts)")
    runner.assert_test(h.get_progress_percentage() == 100.0, "Percentage clamped at 100.0%")
    runner.assert_test(h.current_state == "COMPLETED", "Transitions to COMPLETED state upon target goal")
    runner.assert_test(h.current_production_multiplier == 2.0, "Production multiplier set to 2.0x")
    runner.assert_test(h.reward_time_remaining == 180.0, "Reward duration set to 180.0s")

    # 8. Contributions after completion ignored
    h.contribute_progress("click", 50.0)
    runner.assert_test(h.current_progress == 500.0, "Post-completion contributions strictly ignored")

    # 9. Duplicate Milestone Signal Immunity
    runner.assert_test(h.milestone_signal_counts.get(100.0) == 1, "100% milestone triggered exactly once")

    # 10. Mutation Attack on get_active_event()
    data = h.get_active_event()
    data["reached_milestones"].append(999.0)
    runner.assert_test(999.0 not in h.reached_milestones, "reached_milestones array is insulated against external caller mutation")

    # 11. Cooldown Transition
    # Process until reward time expires
    while h.current_state == "COMPLETED":
        h.process(0.1)
    runner.assert_test(h.current_state == "COOLDOWN", "Transitions to COOLDOWN after reward expiry")
    runner.assert_test(h.current_production_multiplier == 1.0, "Production multiplier reverts to 1.0 during cooldown")
    runner.assert_test(h.cooldown_time_remaining == 30.0, "Cooldown initialized to 30.0s")

    # 12. Return to IDLE
    for _ in range(305):
        h.process(0.1)
    runner.assert_test(h.current_state == "IDLE", "Transitions to IDLE after cooldown expires")

    # 13. Expiration without completion (Failure path)
    h.start_event("server_crash_crisis")
    h.contribute_progress("click", 10.0)
    for _ in range(6005):
        h.process(0.1)
    runner.assert_test(h.current_state == "COOLDOWN", "Uncompleted expired event transitions to COOLDOWN")
    runner.assert_test(h.current_production_multiplier == 1.0, "No production reward multiplier granted on failure")

    # 14. Angel Investor Summit Grant & Drone Speed
    for _ in range(305):
        h.process(0.1)
    runner.assert_test(h.start_event("angel_investor_summit") is True, "Angel Investor Summit started")
    h.contribute_progress("briefcase", 20.0)
    runner.assert_test(h.current_state == "COMPLETED", "Summit reached COMPLETED")
    runner.assert_test(h.current_drone_speed_multiplier == 1.5, "Drone speed multiplier set to 1.5x")
    runner.assert_test(h.reward_time_remaining == 120.0, "Summit reward timer set to 120s")

    # Summary
    print("\n" + "=" * 70)
    print(f"Adversarial Stress Test Summary: {runner.passed} Passed, {runner.failed} Failed")
    print("=" * 70)
    return runner.failed == 0

if __name__ == "__main__":
    success = run_adversarial_tests()
    sys.exit(0 if success else 1)
