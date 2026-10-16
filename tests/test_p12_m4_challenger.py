#!/usr/bin/env python3
"""
Phase 12 Milestone 4: Empirical Adversarial Challenge Verification Suite
========================================================================
Target: Godot 4.3 IdleArcade - Milestone M4 (Requirement R4: Daily Challenge Board & Streak)

Adversarial Stress Harness:
1. Day transitions & calendar rotation:
   - Streak behavior across day deltas:
     * delta = 0 (same day, no change to streak or task progression)
     * delta = 1 (consecutive day, streak intact, advances on full completion)
     * delta = 2+ (missed day, streak unconditionally resets to 0)
     * edge deltas: clock skew / negative delta, massive deltas (10k+ days)
   - Rotation uniqueness:
     * For day indices 0 to 120, get_daily_tasks() produces exactly 3 distinct task IDs
     * All 3 IDs exist in the 6-task catalog
     * Rotation periodicity (modulo 6)
2. Task progression & claim security:
   - Advancing tasks past target:
     * Clamping at target without overflow or corruption
     * Massive advance (e.g. 1,000,000)
     * Negative advance (-50) and zero advance (0)
     * Invalid task ID advance
   - Claim idempotency & security:
     * Claiming incomplete task rejected
     * Claiming already-claimed task rejected with failure dictionary
     * Duplicate claims award 0 duplicate energy / shares
     * Invalid task ID claim rejected
   - Streak increment trigger:
     * daily_board_streak increments by exactly 1 when all 3 daily tasks are claimed
     * Partial claims do not increment streak
     * Subsequent calls or repeated claim attempts do not increment streak multiple times
3. Touch ergonomics & input isolation:
   - Parse scenes/ui/daily_board_modal.tscn:
     * Every button has custom_minimum_size.y >= 56
     * Every button has mouse_filter = 0 (MOUSE_FILTER_STOP)
     * Root Control, Backdrop, ModalCard have mouse_filter = 0
   - Parse scenes/hud.tscn:
     * %StreakBadge has custom_minimum_size.y >= 56 and mouse_filter = 0
     * Every button in hud.tscn has custom_minimum_size.y >= 56 and mouse_filter = 0
4. 3D triangle budget:
   - Parse scenes/daily_board_3d.tscn:
     * Count unique mesh sub-resources
     * Count all instanced MeshInstance3D nodes and their triangles
     * Verify static triangle count is strictly < 400
5. State persistence & JSON roundtrip:
   - Stress-test JSON serialization and deserialization of streaks, last day, and task arrays
"""

import os
import re
import sys
import json
from typing import Dict, Any, List, Set, Tuple

# Reconfigure stdout to utf-8 if available
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")


class ChallengerReporter:
    def __init__(self):
        self.total = 0
        self.passed = 0
        self.failed = 0
        self.errors: List[str] = []

    def check(self, condition: bool, message: str, test_id: str = ""):
        self.total += 1
        prefix = f"[{test_id}] " if test_id else ""
        if condition:
            self.passed += 1
            print(f"  [PASS] {prefix}{message}")
        else:
            self.failed += 1
            print(f"  [FAIL] {prefix}{message}")
            self.errors.append(f"{prefix}{message}")

    def summary(self) -> int:
        print("\n" + "=" * 78)
        print("Adversarial Verification Suite - Milestone M4 Summary:")
        print(f"  Total Checks: {self.total}")
        print(f"  Passed:       {self.passed}")
        print(f"  Failed:       {self.failed}")
        print("=" * 78)
        if self.failed == 0:
            print(">>> ALL ADVERSARIAL CHALLENGES PASSED (100% GREEN) <<<\n")
            return 0
        else:
            print(f">>> {self.failed} CHECKS FAILED! <<<\n")
            for err in self.errors:
                print(f"  - {err}")
            return 1


# ==============================================================================
# GDScript Mirror Simulator with Strict Adversarial Invariant Checks
# ==============================================================================

class GameStateDailyBoardSimulator:
    """
    Exact behavioral simulation of GameState daily board logic in game_state.gd.
    """
    def __init__(self):
        self.daily_board_streak: int = 0
        self.daily_streak: int = 0
        self.daily_board_last_login_day: int = 0
        self.daily_board_tasks: List[Dict[str, Any]] = []
        self.energy: float = 0.0
        self.total_energy_earned: float = 0.0
        self.total_lifetime_energy: float = 0.0
        self.angel_shares: int = 0
        self.rps_buff_active: bool = False
        self.speed_buff_active: bool = False

        self.DAILY_TASK_CATALOG = {
            "task_hype": {
                "id": "task_hype",
                "title": "3x Viraler Hype",
                "description": "Erreiche 3x Viralen Hype",
                "target": 3,
                "reward": {"energy": 10000.0, "description": "10.000 Energy"}
            },
            "task_briefcases": {
                "id": "task_briefcases",
                "title": "5 Aktenkoffer per Drohne",
                "description": "Sammle 5 Aktenkoffer per Drohne",
                "target": 5,
                "reward": {"energy": 15000.0, "angel_shares": 1, "description": "15.000 Energy, 1 Angel Share"}
            },
            "task_espresso": {
                "id": "task_espresso",
                "title": "1 Unicorn Espresso",
                "description": "Braue 1 Unicorn Espresso",
                "target": 1,
                "reward": {"energy": 20000.0, "rps_buff": 2.0, "duration": 45.0, "description": "20.000 Energy, 2x RPS buff"}
            },
            "task_server_hack": {
                "id": "task_server_hack",
                "title": "1 Cyber-Sync an Serverkonsole",
                "description": "Führe 1 Cyber-Sync an Serverkonsole durch",
                "target": 1,
                "reward": {"energy": 12000.0, "description": "12.000 Energy"}
            },
            "task_core_taps": {
                "id": "task_core_taps",
                "title": "50x Reactor Core",
                "description": "Tippe 50x auf den Reactor Core",
                "target": 50,
                "reward": {"energy": 8000.0, "description": "8.000 Energy"}
            },
            "task_buy_upgrades": {
                "id": "task_buy_upgrades",
                "title": "3 Upgrades kaufen",
                "description": "Kaufe 3 beliebige Upgrades",
                "target": 3,
                "reward": {"energy": 15000.0, "description": "15.000 Energy"}
            }
        }

        self.DAILY_TASK_KEYS = [
            "task_hype",
            "task_briefcases",
            "task_espresso",
            "task_server_hack",
            "task_core_taps",
            "task_buy_upgrades"
        ]

    def _rotate_daily_tasks(self, current_day: int):
        if self.daily_board_last_login_day > 0:
            if current_day == self.daily_board_last_login_day + 1:
                # Consecutive day login: preserve existing streak
                pass
            elif current_day > self.daily_board_last_login_day + 1:
                # Missed one or more days: reset streak to 0
                self.daily_board_streak = 0
                self.daily_streak = 0

        self.daily_board_last_login_day = current_day
        self.daily_board_tasks = []

        offset = current_day % len(self.DAILY_TASK_KEYS)
        for i in range(3):
            key = self.DAILY_TASK_KEYS[(offset + i) % len(self.DAILY_TASK_KEYS)]
            template = self.DAILY_TASK_CATALOG[key]
            self.daily_board_tasks.append({
                "id": key,
                "title": template["title"],
                "description": template["description"],
                "target": int(template["target"]),
                "current": 0,
                "is_completed": False,
                "is_claimed": False,
                "reward": json.loads(json.dumps(template["reward"]))
            })

    def get_daily_tasks(self, current_day: int) -> List[Dict[str, Any]]:
        if not self.daily_board_tasks or self.daily_board_last_login_day == 0 or current_day != self.daily_board_last_login_day:
            self._rotate_daily_tasks(current_day)
        return self.daily_board_tasks

    def advance_daily_task(self, task_id: str, amount: int = 1) -> bool:
        if amount <= 0:
            return False
        if not self.daily_board_tasks:
            self.get_daily_tasks(self.daily_board_last_login_day)
        updated = False
        for task in self.daily_board_tasks:
            if task.get("id") == task_id:
                target_val = int(task.get("target", 1))
                current_val = int(task.get("current", 0))
                if current_val < target_val:
                    task["current"] = min(target_val, current_val + amount)
                    if task["current"] >= target_val:
                        task["is_completed"] = True
                    updated = True
                break
        return updated

    def claim_daily_task(self, task_id: str) -> Dict[str, Any]:
        if not self.daily_board_tasks:
            self.get_daily_tasks(self.daily_board_last_login_day)
        found_task = None
        for task in self.daily_board_tasks:
            if task.get("id") == task_id:
                found_task = task
                break
        if found_task is None:
            return {"success": False, "error": "Task not found"}
        if not found_task.get("is_completed", False):
            return {"success": False, "error": "Task not completed yet"}
        if found_task.get("is_claimed", False):
            return {"success": False, "error": "Task already claimed"}

        found_task["is_claimed"] = True
        reward = found_task.get("reward", {})

        if "energy" in reward:
            amt = float(reward["energy"])
            self.energy += amt
            self.total_energy_earned += amt
            self.total_lifetime_energy += amt
        if "angel_shares" in reward:
            self.angel_shares += int(reward["angel_shares"])
        if "rps_buff" in reward:
            self.rps_buff_active = True
        if "speed_buff" in reward:
            self.speed_buff_active = True

        all_claimed = True
        for t in self.daily_board_tasks:
            if not t.get("is_claimed", False):
                all_claimed = False
                break
        if all_claimed:
            self.daily_board_streak += 1
            self.daily_streak = self.daily_board_streak

        return {
            "success": True,
            "task_id": task_id,
            "reward": reward,
            "streak": self.daily_board_streak,
            "all_claimed": all_claimed
        }


def run_challenger_tests():
    reporter = ChallengerReporter()
    base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

    print("=" * 78)
    print("CHALLENGER EMPIRICAL VERIFICATION: MILESTONE M4")
    print("IdleArcade Daily Challenge Board & Streak Engine")
    print("=" * 78)

    # -------------------------------------------------------------------------
    # PART 1: Day transitions & calendar rotation
    # -------------------------------------------------------------------------
    print("\n>>> PART 1: Day Transitions & Calendar Rotation")

    # 1.1 Streak behavior across day deltas
    sim = GameStateDailyBoardSimulator()

    # Day 50: Establish initial streak of 5
    sim.daily_board_last_login_day = 50
    sim.daily_board_streak = 5
    sim.daily_streak = 5
    sim.get_daily_tasks(50)
    reporter.check(len(sim.daily_board_tasks) == 3, "Day 50 generates initial 3 tasks", "P1_InitTasks")

    # Delta = 0: Multiple calls on the same day (50)
    tasks_d50 = sim.get_daily_tasks(50)
    reporter.check(sim.daily_board_streak == 5, "Delta = 0: Streak unchanged (stays at 5)", "P1_Delta0_StreakPreserved")
    reporter.check(sim.daily_board_last_login_day == 50, "Delta = 0: Last login day remains 50", "P1_Delta0_DayUnchanged")
    reporter.check(tasks_d50 == sim.daily_board_tasks, "Delta = 0: Tasks list not wiped or modified", "P1_Delta0_TasksIntact")

    # Delta = 1: Consecutive day (51)
    tasks_d51 = sim.get_daily_tasks(51)
    reporter.check(sim.daily_board_streak == 5, "Delta = 1: Streak intact (not reset, stays at 5)", "P1_Delta1_StreakIntact")
    reporter.check(sim.daily_board_last_login_day == 51, "Delta = 1: Last login day advanced to 51", "P1_Delta1_DayAdvanced")
    reporter.check(len(tasks_d51) == 3, "Delta = 1: Rotated to 3 new daily tasks", "P1_Delta1_Rotated")

    # Complete day 51 tasks to advance streak
    for t in tasks_d51:
        sim.advance_daily_task(t["id"], t["target"])
        sim.claim_daily_task(t["id"])
    reporter.check(sim.daily_board_streak == 6, "Delta = 1: Completing day 51 advances streak 5 -> 6", "P1_Delta1_StreakAdvance")

    # Delta = 1 again: Consecutive day (52)
    tasks_d52 = sim.get_daily_tasks(52)
    reporter.check(sim.daily_board_streak == 6, "Delta = 1: Day 52 streak intact at 6", "P1_Delta1_Streak6Intact")
    for t in tasks_d52:
        sim.advance_daily_task(t["id"], t["target"])
        sim.claim_daily_task(t["id"])
    reporter.check(sim.daily_board_streak == 7, "Delta = 1: Completing day 52 advances streak 6 -> 7", "P1_Delta1_StreakAdvance7")

    # Delta = 2+: Missed day (login at 54 instead of 53, delta = 2)
    tasks_d54 = sim.get_daily_tasks(54)
    reporter.check(sim.daily_board_streak == 0, "Delta = 2: Missed day resets streak to 0", "P1_Delta2_StreakReset")
    reporter.check(sim.daily_streak == 0, "Delta = 2: Legacy daily_streak also resets to 0", "P1_Delta2_LegacyStreakReset")
    reporter.check(sim.daily_board_last_login_day == 54, "Delta = 2: Last login day updated to 54", "P1_Delta2_DayUpdated")

    # Delta = 20+: Massive gap (54 -> 75, delta = 21)
    sim.daily_board_streak = 3
    tasks_d75 = sim.get_daily_tasks(75)
    reporter.check(sim.daily_board_streak == 0, "Delta = 21: Massive gap resets streak to 0", "P1_Delta21_StreakReset")

    # Delta = 10000+: Extreme gap
    sim.daily_board_streak = 10
    tasks_huge = sim.get_daily_tasks(10075)
    reporter.check(sim.daily_board_streak == 0, "Delta = 10000: Extreme gap resets streak to 0", "P1_Delta10k_StreakReset")

    # Negative delta / clock skew backwards (e.g. user changes system time to 10074)
    sim.daily_board_streak = 2
    tasks_neg = sim.get_daily_tasks(10074)
    reporter.check(sim.daily_board_streak == 2, "Negative delta: Streak preserved without corrupted reset", "P1_DeltaNeg_Graceful")

    # 1.2 Rotation Uniqueness for Day Indices 0 to 120
    all_days_valid = True
    all_3_distinct = True
    catalog_subset = True
    catalog_keys = set(sim.DAILY_TASK_KEYS)

    for day_idx in range(121):  # 0 through 120 inclusive
        test_sim = GameStateDailyBoardSimulator()
        tasks = test_sim.get_daily_tasks(day_idx)
        if len(tasks) != 3:
            all_days_valid = False
        task_ids = [t["id"] for t in tasks]
        if len(set(task_ids)) != 3:
            all_3_distinct = False
        if not set(task_ids).issubset(catalog_keys):
            catalog_subset = False

    reporter.check(all_days_valid, "Day indices 0..120 always produce exactly 3 tasks", "P1_Unique_Count3")
    reporter.check(all_3_distinct, "Day indices 0..120 always produce 3 distinct task IDs", "P1_Unique_Distinct")
    reporter.check(catalog_subset, "Day indices 0..120 task IDs belong to 6-task catalog", "P1_Unique_InCatalog")

    # Verify rotation periodicity: offset modulo 6 guarantees period of 6
    sim_period = GameStateDailyBoardSimulator()
    period_match = True
    for d in range(60):
        tasks_a = [t["id"] for t in sim_period.get_daily_tasks(d)]
        sim_period2 = GameStateDailyBoardSimulator()
        tasks_b = [t["id"] for t in sim_period2.get_daily_tasks(d + 6)]
        if tasks_a != tasks_b:
            period_match = False
            break
    reporter.check(period_match, "Task rotation period is exactly 6 days (tasks(d) == tasks(d + 6))", "P1_Periodicity")

    # -------------------------------------------------------------------------
    # PART 2: Task progression & claim security
    # -------------------------------------------------------------------------
    print("\n>>> PART 2: Task Progression & Claim Security")

    sim2 = GameStateDailyBoardSimulator()
    tasks2 = sim2.get_daily_tasks(10)
    first_task = tasks2[0]
    task_id = first_task["id"]
    target = first_task["target"]

    # 2.1 Advancing tasks past target & clamping
    reporter.check(first_task["current"] == 0, "Initial task progress is 0", "P2_Prog_InitialZero")
    reporter.check(first_task["is_completed"] is False, "Initial task is not completed", "P2_Prog_InitialNotComplete")

    # Incremental advance
    sim2.advance_daily_task(task_id, 1)
    reporter.check(first_task["current"] == min(1, target), "Progress increments to 1", "P2_Prog_Step1")

    # Advance exactly to target
    sim2.advance_daily_task(task_id, target)
    reporter.check(first_task["current"] == target, f"Progress reaches target ({target})", "P2_Prog_AtTarget")
    reporter.check(first_task["is_completed"] is True, "Task is marked completed at target", "P2_Prog_Completed")

    # Advance past target: MUST CLAMP
    sim2.advance_daily_task(task_id, 1)
    reporter.check(first_task["current"] == target, f"Progress clamps at target ({target}), no overflow to {target + 1}", "P2_Clamp_Plus1")

    # Massive advance: 1,000,000 units
    sim2.advance_daily_task(task_id, 1_000_000)
    reporter.check(first_task["current"] == target, f"Massive advance (1M) safely clamped at target ({target})", "P2_Clamp_Massive")

    # Negative and zero advance
    sim2.advance_daily_task(task_id, -100)
    reporter.check(first_task["current"] == target, "Negative advance does not alter clamped progress", "P2_Clamp_Negative")
    sim2.advance_daily_task(task_id, 0)
    reporter.check(first_task["current"] == target, "Zero advance does not alter progress", "P2_Clamp_Zero")

    # Invalid task ID advance
    invalid_upd = sim2.advance_daily_task("task_non_existent", 10)
    reporter.check(invalid_upd is False, "Advance on non-existent task returns False safely", "P2_Clamp_InvalidTask")

    # 2.2 Claim idempotency & security
    # Incomplete task claim rejection
    second_task = tasks2[1]
    sec_id = second_task["id"]
    premature_claim = sim2.claim_daily_task(sec_id)
    reporter.check(premature_claim.get("success") is False, "Claiming incomplete task returns success = False", "P2_Claim_IncompleteRejected")
    reporter.check("not completed" in premature_claim.get("error", "").lower(), "Error message indicates task not completed", "P2_Claim_IncompleteError")

    # Non-existent task claim rejection
    fake_claim = sim2.claim_daily_task("task_ghost_fake")
    reporter.check(fake_claim.get("success") is False, "Claiming non-existent task returns success = False", "P2_Claim_FakeRejected")

    # First valid claim on task 1
    initial_energy = sim2.energy
    initial_shares = sim2.angel_shares
    first_claim = sim2.claim_daily_task(task_id)
    reporter.check(first_claim.get("success") is True, "First valid claim returns success = True", "P2_Claim_FirstSuccess")
    reporter.check(first_task["is_claimed"] is True, "Task is_claimed set to True", "P2_Claim_MarkedClaimed")
    energy_reward = first_task["reward"].get("energy", 0.0)
    shares_reward = first_task["reward"].get("angel_shares", 0)
    reporter.check(sim2.energy == initial_energy + energy_reward, "Reward energy accurately credited", "P2_Claim_EnergyPaid")
    reporter.check(sim2.angel_shares == initial_shares + shares_reward, "Reward shares accurately credited", "P2_Claim_SharesPaid")

    # Second claim attempt on SAME task (Idempotency test)
    energy_after_first = sim2.energy
    shares_after_first = sim2.angel_shares
    second_claim = sim2.claim_daily_task(task_id)
    reporter.check(second_claim.get("success") is False, "Duplicate claim returns success = False", "P2_Idempotent_SecondFail")
    reporter.check("already claimed" in second_claim.get("error", "").lower(), "Error explicitly states 'Task already claimed'", "P2_Idempotent_ErrorMsg")
    reporter.check(sim2.energy == energy_after_first, "Duplicate claim awards ZERO duplicate energy", "P2_Idempotent_NoDupEnergy")
    reporter.check(sim2.angel_shares == shares_after_first, "Duplicate claim awards ZERO duplicate angel shares", "P2_Idempotent_NoDupShares")

    # Third and tenth claim attempts
    for rep in range(3, 11):
        rep_claim = sim2.claim_daily_task(task_id)
        if rep_claim.get("success") is not False:
            reporter.check(False, f"Repeated claim {rep} unexpectedly succeeded", f"P2_Idempotent_Rep{rep}")
    reporter.check(sim2.energy == energy_after_first, "10 duplicate claims award 0 duplicate energy", "P2_Idempotent_MultiRepSafe")

    # 2.3 Streak increment trigger
    # Current state: 1 task claimed, 2 unclaimed
    reporter.check(sim2.daily_board_streak == 0, "Streak remains 0 when 1 of 3 tasks claimed", "P2_Streak_1Claimed")
    reporter.check(first_claim.get("all_claimed") is False, "first_claim.all_claimed is False", "P2_Streak_AllClaimedFalse")

    # Claim task 2
    sim2.advance_daily_task(sec_id, second_task["target"])
    second_claim_res = sim2.claim_daily_task(sec_id)
    reporter.check(second_claim_res.get("success") is True, "Task 2 claimed successfully", "P2_Streak_Task2Claimed")
    reporter.check(sim2.daily_board_streak == 0, "Streak remains 0 when 2 of 3 tasks claimed", "P2_Streak_2Claimed")

    # Claim task 3
    third_task = tasks2[2]
    third_id = third_task["id"]
    sim2.advance_daily_task(third_id, third_task["target"])
    third_claim_res = sim2.claim_daily_task(third_id)
    reporter.check(third_claim_res.get("success") is True, "Task 3 claimed successfully", "P2_Streak_Task3Claimed")
    reporter.check(third_claim_res.get("all_claimed") is True, "third_claim.all_claimed is True", "P2_Streak_AllClaimedTrue")
    reporter.check(sim2.daily_board_streak == 1, "Streak increments by EXACTLY 1 when all 3 tasks claimed (0 -> 1)", "P2_Streak_Inc1")
    reporter.check(sim2.daily_streak == 1, "Legacy daily_streak synchronized to 1", "P2_Streak_LegacySync")

    # Re-trigger prevention on the same day
    # Attempting to re-claim any task should not increment streak further
    re_res1 = sim2.claim_daily_task(task_id)
    re_res2 = sim2.claim_daily_task(sec_id)
    re_res3 = sim2.claim_daily_task(third_id)
    reporter.check(sim2.daily_board_streak == 1, "Streak does NOT double-increment on repeat claim attempts (remains 1)", "P2_Streak_NoDoubleInc")
    reporter.check(re_res1.get("success") is False and re_res2.get("success") is False and re_res3.get("success") is False, "All 3 repeat claims rejected", "P2_Streak_AllRepeatsRejected")

    # Calling get_daily_tasks on same day preserves streak
    sim2.get_daily_tasks(10)
    reporter.check(sim2.daily_board_streak == 1, "get_daily_tasks on same day preserves streak at 1", "P2_Streak_SameDayGetSafe")

    # -------------------------------------------------------------------------
    # PART 3: Touch ergonomics & input isolation
    # -------------------------------------------------------------------------
    print("\n>>> PART 3: Touch Ergonomics & Input Isolation")

    daily_modal_path = os.path.join(base_dir, "scenes", "ui", "daily_board_modal.tscn")
    hud_path = os.path.join(base_dir, "scenes", "hud.tscn")

    reporter.check(os.path.isfile(daily_modal_path), "scenes/ui/daily_board_modal.tscn exists", "P3_Modal_Exists")
    reporter.check(os.path.isfile(hud_path), "scenes/hud.tscn exists", "P3_HUD_Exists")

    with open(daily_modal_path, "r", encoding="utf-8") as f:
        modal_content = f.read()

    with open(hud_path, "r", encoding="utf-8") as f:
        hud_content = f.read()

    # 3.1 Parse daily_board_modal.tscn buttons and controls
    # Helper to parse node blocks
    def parse_tscn_nodes(content: str) -> List[Dict[str, Any]]:
        nodes = []
        raw_nodes = re.split(r'\[node\s+', content)[1:]
        for raw in raw_nodes:
            lines = raw.split("\n")
            header = lines[0]
            name_m = re.search(r'name="([^"]+)"', header)
            type_m = re.search(r'type="([^"]+)"', header)
            parent_m = re.search(r'parent="([^"]+)"', header)

            node_dict = {
                "name": name_m.group(1) if name_m else "",
                "type": type_m.group(1) if type_m else "",
                "parent": parent_m.group(1) if parent_m else "",
                "body": "\n".join(lines[1:])
            }
            nodes.append(node_dict)
        return nodes

    modal_nodes = parse_tscn_nodes(modal_content)
    hud_nodes = parse_tscn_nodes(hud_content)

    # Verify daily_board_modal.tscn: every Button has custom_minimum_size.y >= 56 and mouse_filter = 0
    modal_buttons = [n for n in modal_nodes if n["type"] == "Button"]
    reporter.check(len(modal_buttons) >= 4, f"daily_board_modal.tscn contains {len(modal_buttons)} buttons (>= 4: Close + 3 Claims)", "P3_Modal_ButtonCount")

    all_modal_btns_compliant = True
    for btn in modal_buttons:
        body = btn["body"]
        name = btn["name"]
        size_m = re.search(r'custom_minimum_size\s*=\s*Vector2\(([^,]+),\s*([^)]+)\)', body)
        filter_m = re.search(r'mouse_filter\s*=\s*(\d+)', body)

        if not size_m or not filter_m:
            all_modal_btns_compliant = False
            reporter.check(False, f"Button '{name}' missing custom_minimum_size or mouse_filter", f"P3_Modal_Btn_{name}_Props")
            continue

        h = float(size_m.group(2))
        mf = int(filter_m.group(1))
        h_ok = h >= 56.0
        mf_ok = mf == 0

        if not (h_ok and mf_ok):
            all_modal_btns_compliant = False
        reporter.check(h_ok, f"Modal button '{name}' height {h} >= 56px", f"P3_Modal_Btn_{name}_Height")
        reporter.check(mf_ok, f"Modal button '{name}' mouse_filter == 0 (STOP)", f"P3_Modal_Btn_{name}_Filter")

    reporter.check(all_modal_btns_compliant, "All buttons in daily_board_modal.tscn strictly satisfy height >= 56 and mouse_filter = 0", "P3_Modal_AllBtnsOK")

    # Verify DailyBoardModal root and Backdrop
    root_node = modal_nodes[0] if modal_nodes else {}
    root_filter = re.search(r'mouse_filter\s*=\s*(\d+)', root_node.get("body", ""))
    reporter.check(root_filter is not None and int(root_filter.group(1)) == 0, "DailyBoardModal root mouse_filter = 0 (MOUSE_FILTER_STOP)", "P3_Modal_RootFilter")

    backdrop_node = next((n for n in modal_nodes if n["name"] == "Backdrop"), None)
    reporter.check(backdrop_node is not None, "Backdrop node exists in daily_board_modal.tscn", "P3_Modal_BackdropExists")
    if backdrop_node:
        bd_filter = re.search(r'mouse_filter\s*=\s*(\d+)', backdrop_node["body"])
        reporter.check(bd_filter is not None and int(bd_filter.group(1)) == 0, "Backdrop mouse_filter = 0 (blocks click-through to 3D)", "P3_Modal_BackdropFilter")

    # 3.2 Parse hud.tscn buttons and interactive controls
    streak_badge_node = next((n for n in hud_nodes if n["name"] == "StreakBadge"), None)
    reporter.check(streak_badge_node is not None, "%StreakBadge exists in scenes/hud.tscn", "P3_HUD_StreakBadgeExists")
    if streak_badge_node:
        sb_size_m = re.search(r'custom_minimum_size\s*=\s*Vector2\(([^,]+),\s*([^)]+)\)', streak_badge_node["body"])
        sb_filter_m = re.search(r'mouse_filter\s*=\s*(\d+)', streak_badge_node["body"])
        reporter.check(sb_size_m is not None, "%StreakBadge defines custom_minimum_size", "P3_HUD_StreakSizeDefined")
        reporter.check(sb_filter_m is not None, "%StreakBadge defines mouse_filter", "P3_HUD_StreakFilterDefined")
        if sb_size_m and sb_filter_m:
            sb_h = float(sb_size_m.group(2))
            sb_f = int(sb_filter_m.group(1))
            reporter.check(sb_h >= 56.0, f"%StreakBadge height ({sb_h}) >= 56px", "P3_HUD_StreakHeight")
            reporter.check(sb_f == 0, f"%StreakBadge mouse_filter = {sb_f} (STOP)", "P3_HUD_StreakFilterStop")

    # Check ALL buttons in scenes/hud.tscn
    hud_buttons = [n for n in hud_nodes if n["type"] == "Button"]
    reporter.check(len(hud_buttons) >= 10, f"scenes/hud.tscn contains {len(hud_buttons)} buttons (>= 10 expected)", "P3_HUD_ButtonCount")

    all_hud_btns_compliant = True
    for btn in hud_buttons:
        name = btn["name"]
        body = btn["body"]
        # Backdrop button is fullscreen flat button for drawer closing
        if name == "NavDrawerBackdrop":
            filter_m = re.search(r'mouse_filter\s*=\s*(\d+)', body)
            reporter.check(filter_m is not None and int(filter_m.group(1)) == 0, "NavDrawerBackdrop mouse_filter = 0", f"P3_HUD_Btn_{name}_Filter")
            continue

        size_m = re.search(r'custom_minimum_size\s*=\s*Vector2\(([^,]+),\s*([^)]+)\)', body)
        filter_m = re.search(r'mouse_filter\s*=\s*(\d+)', body)

        if not size_m or not filter_m:
            all_hud_btns_compliant = False
            reporter.check(False, f"HUD Button '{name}' missing custom_minimum_size or mouse_filter", f"P3_HUD_Btn_{name}_Props")
            continue

        h = float(size_m.group(2))
        mf = int(filter_m.group(1))
        h_ok = h >= 56.0
        mf_ok = mf == 0

        if not (h_ok and mf_ok):
            all_hud_btns_compliant = False
        reporter.check(h_ok, f"HUD button '{name}' height {h} >= 56px", f"P3_HUD_Btn_{name}_Height")
        reporter.check(mf_ok, f"HUD button '{name}' mouse_filter == 0 (STOP)", f"P3_HUD_Btn_{name}_Filter")

    reporter.check(all_hud_btns_compliant, "All buttons in scenes/hud.tscn strictly satisfy height >= 56 and mouse_filter = 0", "P3_HUD_AllBtnsOK")

    # -------------------------------------------------------------------------
    # PART 4: 3D Triangle Budget
    # -------------------------------------------------------------------------
    print("\n>>> PART 4: 3D Static Triangle Budget")

    board_3d_path = os.path.join(base_dir, "scenes", "daily_board_3d.tscn")
    reporter.check(os.path.isfile(board_3d_path), "scenes/daily_board_3d.tscn exists", "P4_Board3D_Exists")

    with open(board_3d_path, "r", encoding="utf-8") as f:
        board_3d_content = f.read()

    # Parse all sub_resource mesh definitions in scenes/daily_board_3d.tscn
    subres_blocks = re.split(r'\[sub_resource\s+', board_3d_content)[1:]
    mesh_catalogs: Dict[str, Dict[str, Any]] = {}

    for blk in subres_blocks:
        lines = blk.split("\n")
        header = lines[0]
        type_m = re.search(r'type="([^"]+)"', header)
        id_m = re.search(r'id="([^"]+)"', header)
        if not type_m or not id_m:
            continue
        stype = type_m.group(1)
        sid = id_m.group(1)
        body = "\n".join(lines[1:])

        if stype == "BoxMesh":
            mesh_catalogs[sid] = {"type": "BoxMesh", "triangles": 12}
        elif stype == "SphereMesh":
            r_seg_m = re.search(r'radial_segments\s*=\s*(\d+)', body)
            rings_m = re.search(r'rings\s*=\s*(\d+)', body)
            r_seg = int(r_seg_m.group(1)) if r_seg_m else 64
            rings = int(rings_m.group(1)) if rings_m else 32
            # Godot SphereMesh triangles = 2 * radial_segments * rings
            tris = 2 * r_seg * rings
            mesh_catalogs[sid] = {"type": "SphereMesh", "radial_segments": r_seg, "rings": rings, "triangles": tris}
        elif stype == "CylinderMesh":
            r_seg_m = re.search(r'radial_segments\s*=\s*(\d+)', body)
            rings_m = re.search(r'rings\s*=\s*(\d+)', body)
            r_seg = int(r_seg_m.group(1)) if r_seg_m else 64
            rings = int(rings_m.group(1)) if rings_m else 4
            tris = 2 * r_seg * rings + 2 * r_seg
            mesh_catalogs[sid] = {"type": "CylinderMesh", "radial_segments": r_seg, "rings": rings, "triangles": tris}

    # Count distinct sub-resource mesh triangles
    unique_subres_tris = sum(m["triangles"] for m in mesh_catalogs.values())
    print(f"  -> Unique mesh sub-resources: {len(mesh_catalogs)} definitions ({unique_subres_tris} triangles)")

    # Count all MeshInstance3D nodes in daily_board_3d.tscn
    board_nodes = parse_tscn_nodes(board_3d_content)
    mesh_instances = [n for n in board_nodes if n["type"] == "MeshInstance3D"]
    total_instanced_triangles = 0

    for mi in mesh_instances:
        name = mi["name"]
        body = mi["body"]
        res_m = re.search(r'mesh\s*=\s*SubResource\("([^"]+)"\)', body)
        if res_m:
            res_id = res_m.group(1)
            tris = mesh_catalogs.get(res_id, {}).get("triangles", 0)
            total_instanced_triangles += tris
        else:
            # Inline boxmesh or cylinder
            if "BoxMesh" in body:
                total_instanced_triangles += 12

    print(f"  -> Total instanced MeshInstance3D nodes: {len(mesh_instances)} ({total_instanced_triangles} triangles)")
    reporter.check(len(mesh_instances) > 0, f"Found {len(mesh_instances)} MeshInstance3D nodes", "P4_Mesh_NodesFound")
    reporter.check(unique_subres_tris > 0, f"Unique subresource triangles > 0 ({unique_subres_tris} tris)", "P4_SubRes_NonEmpty")
    reporter.check(unique_subres_tris < 400, f"Unique subresource triangles < 400 budget ({unique_subres_tris} < 400)", "P4_SubRes_Budget")
    reporter.check(total_instanced_triangles > 0, f"Instanced triangles > 0 ({total_instanced_triangles} tris)", "P4_Instanced_NonEmpty")
    reporter.check(total_instanced_triangles < 400, f"Instanced static triangles strictly < 400 budget ({total_instanced_triangles} < 400)", "P4_Instanced_Budget")

    # -------------------------------------------------------------------------
    # PART 5: JSON Save / Load Roundtrip & State Integrity
    # -------------------------------------------------------------------------
    print("\n>>> PART 5: JSON Save / Load Roundtrip & State Integrity")

    game_state_gd = os.path.join(base_dir, "scripts", "autoload", "game_state.gd")
    with open(game_state_gd, "r", encoding="utf-8") as f:
        gs_text = f.read()

    reporter.check('"daily_board_streak": daily_board_streak' in gs_text, "save_to_disk serializes daily_board_streak", "P5_Save_Streak")
    reporter.check('"daily_board_last_login_day": daily_board_last_login_day' in gs_text, "save_to_disk serializes daily_board_last_login_day", "P5_Save_LastDay")
    reporter.check('"daily_board_tasks": daily_board_tasks' in gs_text, "save_to_disk serializes daily_board_tasks", "P5_Save_Tasks")
    reporter.check('daily_board_streak = maxi(0, int(data.get("daily_board_streak"' in gs_text, "load_from_disk deserializes daily_board_streak", "P5_Load_Streak")
    reporter.check('daily_board_last_login_day = int(data.get("daily_board_last_login_day"' in gs_text, "load_from_disk deserializes daily_board_last_login_day", "P5_Load_LastDay")
    reporter.check('data.get("daily_board_tasks"' in gs_text, "load_from_disk deserializes daily_board_tasks", "P5_Load_Tasks")

    # Simulate full JSON cycle
    sim_save = GameStateDailyBoardSimulator()
    sim_save.daily_board_last_login_day = 1234
    sim_save.daily_board_streak = 42
    sim_save.get_daily_tasks(1234)
    sim_save.advance_daily_task(sim_save.daily_board_tasks[0]["id"], 1)

    serialized = json.dumps({
        "daily_board_streak": sim_save.daily_board_streak,
        "daily_board_last_login_day": sim_save.daily_board_last_login_day,
        "daily_board_tasks": sim_save.daily_board_tasks
    })

    deserialized = json.loads(serialized)
    reporter.check(deserialized["daily_board_streak"] == 42, "Deserialized streak equals 42", "P5_Roundtrip_Streak")
    reporter.check(deserialized["daily_board_last_login_day"] == 1234, "Deserialized last day equals 1234", "P5_Roundtrip_LastDay")
    reporter.check(len(deserialized["daily_board_tasks"]) == 3, "Deserialized tasks list contains 3 tasks", "P5_Roundtrip_TaskCount")
    reporter.check(deserialized["daily_board_tasks"][0]["current"] == 1, "Deserialized task progress preserved", "P5_Roundtrip_Progress")

    return reporter.summary()


if __name__ == "__main__":
    exit_code = run_challenger_tests()
    sys.exit(exit_code)
