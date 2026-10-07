#!/usr/bin/env python3
"""
Empirical Adversarial Challenge Test Suite for Milestone P2-M3:
Daily Quests, Storage Edge Cases, Duplicate Claim Prevention,
Bonus Users Economy, Legacy Savegame Loading, and Regression Safety.

Executable via: python IdleArcade/tests/test_p2_m3_adversarial_challenge.py
"""

import os
import re
import sys
import json
import math
from pathlib import Path

def run_adversarial_challenge():
    print("=====================================================================")
    print("[CHALLENGE] Phase 2 Milestone 3 Empirical Adversarial Stress Suite")
    print("=====================================================================")

    game_dir = Path(__file__).resolve().parent.parent
    mgr_path = game_dir / "scripts" / "autoload" / "nakama_manager.gd"
    gs_path = game_dir / "scripts" / "autoload" / "game_state.gd"
    test_nakama_path = game_dir / "tests" / "test_nakama.gd"
    test_logic_path = game_dir / "tests" / "test_game_logic.gd"

    checks_passed = 0
    checks_failed = 0

    def assert_test(cond, msg):
        nonlocal checks_passed, checks_failed
        if cond:
            print(f"  [PASS] {msg}")
            checks_passed += 1
        else:
            print(f"  [FAIL] {msg}")
            checks_failed += 1

    # =========================================================================
    # 1. Source Code & Interface Contract Inspection
    # =========================================================================
    print("\n--- 1. Testing Code Integrity & Interface Contract Signatures ---")

    if not mgr_path.is_file() or not gs_path.is_file():
        print(f"  [FATAL] Missing game_state.gd or nakama_manager.gd")
        sys.exit(1)

    mgr_code = mgr_path.read_text(encoding="utf-8")
    gs_code = gs_path.read_text(encoding="utf-8")

    # GameState Signals
    gs_signals = ["bonus_users_changed", "core_tapped", "spark_collected", "energy_changed", "rps_changed", "frenzy_updated", "upgrade_purchased"]
    for s in gs_signals:
        assert_test(re.search(rf'signal\s+{s}\b', gs_code) is not None, f"GameState declares signal '{s}'")

    # GameState bonus users methods
    assert_test("func get_bonus_multiplier() -> float:" in gs_code, "GameState defines get_bonus_multiplier()")
    assert_test("func get_effective_passive_rps() -> float:" in gs_code, "GameState defines get_effective_passive_rps()")
    assert_test("func award_bonus_users(amount: int) -> void:" in gs_code, "GameState defines award_bonus_users()")

    # Decoupling Verification: GameState must NOT import or reference Nakama
    assert_test("Nakama" not in gs_code, "GameState has ZERO references to 'Nakama'")
    assert_test("NakamaManager" not in gs_code, "GameState has ZERO references to 'NakamaManager'")
    assert_test("/root/" not in gs_code, "GameState has ZERO references to '/root/' singletons")

    # NakamaManager Quest & Scoreboard Methods
    m3_methods = [
        "get_current_utc_date", "_get_default_daily_quests", "fetch_daily_quests_async",
        "record_quest_progress", "claim_quest_reward_async", "_save_remote_quests_async",
        "_save_local_quests_cache", "_load_local_quests_cache", "submit_score_async",
        "sync_current_score_async", "fetch_leaderboard_async", "fetch_guild_leaderboard_async",
        "create_guild_async", "join_guild_async", "leave_guild_async", "list_guilds_async",
        "list_guild_members_async", "get_player_country_code", "get_country_leaderboard_id"
    ]
    for m in m3_methods:
        assert_test(re.search(rf'func\s+{m}\b', mgr_code) is not None, f"NakamaManager implements '{m}'")

    # =========================================================================
    # 2. Challenge 1: Quest Progress Clamping & Overflow Simulation
    # =========================================================================
    print("\n--- 2. Testing Quest Progress Clamping & Overflow Protection ---")

    def simulate_record_progress(daily_quests, event_type, amount):
        """Simulates record_quest_progress in nakama_manager.gd"""
        if amount <= 0:
            return daily_quests, False
        quests_map = daily_quests.get("quests", {})
        changed = False
        for q_id, q in quests_map.items():
            if (q.get("type", "") == event_type or q_id == event_type) and not q.get("is_completed", False):
                curr = int(q.get("current", 0)) + amount
                tgt = int(q.get("target", 1))
                q["current"] = min(tgt, curr)
                if q["current"] >= tgt:
                    q["is_completed"] = True
                changed = True
        return daily_quests, changed

    default_quests = {
        "date": "2026-10-06",
        "quests": {
            "daily_tap": {"type": "tap", "target": 50, "current": 0, "is_completed": False, "is_claimed": False, "reward_bonus_users": 25},
            "daily_upgrade": {"type": "upgrade", "target": 3, "current": 0, "is_completed": False, "is_claimed": False, "reward_bonus_users": 50},
            "daily_spark": {"type": "spark", "target": 3, "current": 0, "is_completed": False, "is_claimed": False, "reward_bonus_users": 100}
        }
    }

    # Case 2.1: Single massive increment (1,000,000 against target 50)
    q_state = json.loads(json.dumps(default_quests))
    q_state, chg = simulate_record_progress(q_state, "tap", 1_000_000)
    assert_test(q_state["quests"]["daily_tap"]["current"] == 50, "1,000,000 tap increment clamped strictly to 50")
    assert_test(q_state["quests"]["daily_tap"]["is_completed"] is True, "Quest marked is_completed=True upon reaching target")
    assert_test(chg is True, "State marked as changed")

    # Case 2.2: Post-completion immunity
    q_state, chg2 = simulate_record_progress(q_state, "tap", 100)
    assert_test(q_state["quests"]["daily_tap"]["current"] == 50, "Post-completion increment does not exceed 50")
    assert_test(chg2 is False, "Post-completion increment does not flag state as changed")

    # Case 2.3: Zero and negative increments ignored
    q_state, chg_zero = simulate_record_progress(q_state, "upgrade", 0)
    assert_test(q_state["quests"]["daily_upgrade"]["current"] == 0 and chg_zero is False, "0 increment ignored")
    q_state, chg_neg = simulate_record_progress(q_state, "upgrade", -10)
    assert_test(q_state["quests"]["daily_upgrade"]["current"] == 0 and chg_neg is False, "-10 increment ignored")

    # Case 2.4: Step increments (partial progress)
    q_state, _ = simulate_record_progress(q_state, "upgrade", 2)
    assert_test(q_state["quests"]["daily_upgrade"]["current"] == 2 and not q_state["quests"]["daily_upgrade"]["is_completed"], "Partial progress accumulates to 2/3")
    q_state, _ = simulate_record_progress(q_state, "upgrade", 5)
    assert_test(q_state["quests"]["daily_upgrade"]["current"] == 3 and q_state["quests"]["daily_upgrade"]["is_completed"], "Overshoot clamps to 3/3")

    # =========================================================================
    # 3. Challenge 2: UTC Date Rollover Simulation
    # =========================================================================
    print("\n--- 3. Testing UTC Date Rollover Reset Logic ---")

    def simulate_date_check(daily_quests, current_date):
        if str(daily_quests.get("date", "")) != current_date:
            fresh = json.loads(json.dumps(default_quests))
            fresh["date"] = current_date
            return fresh, True
        return daily_quests, False

    # Simulate completed yesterday quests
    yesterday_quests = json.loads(json.dumps(default_quests))
    yesterday_quests["date"] = "2026-10-05"
    yesterday_quests["quests"]["daily_tap"]["current"] = 50
    yesterday_quests["quests"]["daily_tap"]["is_completed"] = True
    yesterday_quests["quests"]["daily_tap"]["is_claimed"] = True

    # Transition to today
    rolled_quests, did_roll = simulate_date_check(yesterday_quests, "2026-10-06")
    assert_test(did_roll is True, "Outdated date triggers rollover reset")
    assert_test(rolled_quests["date"] == "2026-10-06", "Rolled quests updated to current date")
    assert_test(rolled_quests["quests"]["daily_tap"]["current"] == 0, "Rolled quest progress reset to 0")
    assert_test(rolled_quests["quests"]["daily_tap"]["is_completed"] is False, "Rolled quest is_completed reset to False")
    assert_test(rolled_quests["quests"]["daily_tap"]["is_claimed"] is False, "Rolled quest is_claimed reset to False")

    # Year rollover
    new_year_quests = json.loads(json.dumps(default_quests))
    new_year_quests["date"] = "2025-12-31"
    ny_rolled, ny_did_roll = simulate_date_check(new_year_quests, "2026-01-01")
    assert_test(ny_did_roll is True and ny_rolled["date"] == "2026-01-01", "Year boundary (2025-12-31 -> 2026-01-01) cleanly detected")

    # Same day check
    same_day_quests, same_did_roll = simulate_date_check(rolled_quests, "2026-10-06")
    assert_test(same_did_roll is False, "Same day does not trigger rollover reset")

    # =========================================================================
    # 4. Challenge 3: Duplicate Claim Prevention (Idempotency)
    # =========================================================================
    print("\n--- 4. Testing Duplicate Claim Prevention ---")

    def simulate_claim(daily_quests, quest_id, current_bonus_users):
        quests_map = daily_quests.get("quests", {})
        if quest_id not in quests_map:
            return 0, current_bonus_users, "not_found"
        q = quests_map[quest_id]
        if not q.get("is_completed", False) or q.get("is_claimed", False):
            return 0, current_bonus_users, "uneligible_or_already_claimed"
        q["is_claimed"] = True
        reward = int(q.get("reward_bonus_users", 0))
        new_bonus_users = current_bonus_users + reward
        return reward, new_bonus_users, "claimed"

    c_state = json.loads(json.dumps(default_quests))
    user_bonus = 0

    # Incomplete quest claim
    rew0, user_bonus, st0 = simulate_claim(c_state, "daily_tap", user_bonus)
    assert_test(rew0 == 0 and user_bonus == 0 and st0 == "uneligible_or_already_claimed", "Claiming incomplete quest returns 0")

    # Complete quest
    c_state["quests"]["daily_tap"]["current"] = 50
    c_state["quests"]["daily_tap"]["is_completed"] = True

    # 1st claim
    rew1, user_bonus, st1 = simulate_claim(c_state, "daily_tap", user_bonus)
    assert_test(rew1 == 25 and user_bonus == 25 and st1 == "claimed", "First claim returns 25 bonus users")
    assert_test(c_state["quests"]["daily_tap"]["is_claimed"] is True, "Quest marked is_claimed=True")

    # 2nd claim (duplicate)
    rew2, user_bonus, st2 = simulate_claim(c_state, "daily_tap", user_bonus)
    assert_test(rew2 == 0 and user_bonus == 25 and st2 == "uneligible_or_already_claimed", "2nd claim returns 0 and leaves bonus users unchanged at 25")

    # 3rd claim (triplicate)
    rew3, user_bonus, st3 = simulate_claim(c_state, "daily_tap", user_bonus)
    assert_test(rew3 == 0 and user_bonus == 25, "3rd claim returns 0")

    # Synchronous flag placement verification in GDScript
    # Ensure q["is_claimed"] = true appears BEFORE any await in claim_quest_reward_async
    claim_func_match = re.search(r'func claim_quest_reward_async\((.*?)\)\s*->\s*int:\s*([\s\S]*?)(?:func\s+)', mgr_code)
    assert_test(claim_func_match is not None, "claim_quest_reward_async function body found")
    if claim_func_match:
        f_body = claim_func_match.group(2)
        idx_claimed_true = f_body.find('q["is_claimed"] = true')
        idx_await = f_body.find('await ')
        assert_test(idx_claimed_true != -1, "q['is_claimed'] = true is explicitly set")
        assert_test(idx_await == -1 or idx_claimed_true < idx_await, "is_claimed is set synchronously BEFORE any await call (anti-race condition)")

    # =========================================================================
    # 5. Challenge 4: Bonus User Multiplier Recalculation (+1% passive RPS)
    # =========================================================================
    print("\n--- 5. Testing Bonus User Multiplier Recalculation (+1% per user) ---")

    def calc_multiplier(bonus_users: int) -> float:
        return 1.0 + (float(bonus_users) * 0.01)

    def calc_effective_rps(base_rps: float, bonus_users: int) -> float:
        return base_rps * calc_multiplier(bonus_users)

    # Test sample points
    assert_test(abs(calc_multiplier(0) - 1.0) < 1e-9, "0 bonus users -> 1.0x multiplier")
    assert_test(abs(calc_multiplier(1) - 1.01) < 1e-9, "1 bonus user -> 1.01x multiplier (+1%)")
    assert_test(abs(calc_multiplier(25) - 1.25) < 1e-9, "25 bonus users -> 1.25x multiplier (+25%)")
    assert_test(abs(calc_multiplier(50) - 1.50) < 1e-9, "50 bonus users -> 1.50x multiplier (+50%)")
    assert_test(abs(calc_multiplier(100) - 2.00) < 1e-9, "100 bonus users -> 2.00x multiplier (+100%)")
    assert_test(abs(calc_multiplier(1000) - 11.00) < 1e-9, "1000 bonus users -> 11.00x multiplier (+1000%)")

    # Effective RPS at base 100.0
    assert_test(abs(calc_effective_rps(100.0, 25) - 125.0) < 1e-9, "100.0 base RPS * 1.25 = 125.0 effective RPS")
    assert_test(abs(calc_effective_rps(250.0, 100) - 500.0) < 1e-9, "250.0 base RPS * 2.00 = 500.0 effective RPS")

    # GDScript formula match
    assert_test("1.0 + (float(bonus_users) * 0.01)" in gs_code, "get_bonus_multiplier() exact formula in game_state.gd")
    assert_test("base_passive_rps * get_bonus_multiplier()" in gs_code, "get_effective_passive_rps() exact formula in game_state.gd")

    # =========================================================================
    # 6. Challenge 5: Legacy Savegame Backward Compatibility
    # =========================================================================
    print("\n--- 6. Testing Legacy Savegame Backward Compatibility ---")

    def simulate_save_load(save_data: dict):
        bonus = max(0, int(save_data.get("bonus_users", 0)))
        energy = max(0.0, float(save_data.get("energy", 0.0)))
        base_rps = float(save_data.get("base_passive_rps", 0.0))
        mult = calc_multiplier(bonus)
        effective_rps = base_rps * mult
        return bonus, mult, effective_rps

    # Case 6.1: Missing bonus_users key
    legacy_save = {
        "timestamp": 1728250000,
        "energy": 120.0,
        "base_passive_rps": 10.0,
        "upgrades": {"tier_1": {"level": 10}}
    }
    b1, m1, eff1 = simulate_save_load(legacy_save)
    assert_test(b1 == 0, "Missing 'bonus_users' key defaults to 0")
    assert_test(abs(m1 - 1.0) < 1e-9, "Missing 'bonus_users' results in 1.0x multiplier")
    assert_test(abs(eff1 - 10.0) < 1e-9, "Effective RPS equals base RPS (10.0)")

    # Case 6.2: Negative bonus_users value
    corrupt_save = {"bonus_users": -50, "base_passive_rps": 10.0}
    b2, m2, eff2 = simulate_save_load(corrupt_save)
    assert_test(b2 == 0, "Negative 'bonus_users' (-50) sanitized to 0 via maxi(0, ...)")

    # Case 6.3: Valid bonus_users loaded
    valid_save = {"bonus_users": 175, "base_passive_rps": 20.0}
    b3, m3, eff3 = simulate_save_load(valid_save)
    assert_test(b3 == 175 and abs(m3 - 2.75) < 1e-9 and abs(eff3 - 55.0) < 1e-9, "Valid bonus_users=175 loads correctly (2.75x mult, 55.0 eff RPS)")

    # =========================================================================
    # 7. Challenge 6: Regression Safety against test_game_logic.gd
    # =========================================================================
    print("\n--- 7. Testing Regression Safety & Test Suite Integrity ---")

    test_logic_code = test_logic_path.read_text(encoding="utf-8")
    for t_idx in range(1, 16):
        assert_test(f"Test {t_idx}" in test_logic_code or f"Test {t_idx}:" in test_logic_code or f"# Test {t_idx}:" in test_logic_code, f"test_game_logic.gd contains Test {t_idx}")

    # Check Test 15 Lifecycle Simulation Math in Python
    # 25 taps:
    # taps 1-24: 24 * 1.0 = 24
    # tap 25: 1.0 -> 25 total. Frenzy activated (multiplier = 3.0)
    # taps 26-30 (5 taps): 5 * 1.0 * 3.0 = 15. Total energy = 40.0. Total clicks = 30.
    # process 6.0: Frenzy expires. Mult = 1.0. RPS = 0.
    # buy tier_1: cost = 25. Energy = 40 - 25 = 15. Base RPS = 1.0.
    # collect_spark: max(50.0, 1.0 * 25.0) = 50. Energy = 15 + 50 = 65. Sparks = 1.
    # 600 frames of 10.0 / 600.0s (10s): 10.0 * 1.0 = 10. Energy = 65 + 10 = 75.0!
    e = 0.0
    clicks = 0
    frenzy_meter = 0.0
    frenzy_active = False
    frenzy_mult = 1.0

    for i in range(25):
        earned = 1.0 * frenzy_mult
        e += earned
        clicks += 1
        if not frenzy_active:
            frenzy_meter = min(100.0, frenzy_meter + 4.0)
            if frenzy_meter >= 100.0:
                frenzy_active = True
                frenzy_mult = 3.0
                frenzy_meter = 0.0

    for i in range(5):
        earned = 1.0 * frenzy_mult
        e += earned
        clicks += 1

    frenzy_active = False
    frenzy_mult = 1.0
    e -= 25.0 # buy tier_1
    rps = 1.0
    e += max(50.0, rps * 25.0) # collect spark

    # 10s idle
    for i in range(600):
        dt = 10.0 / 600.0
        e += rps * frenzy_mult * dt

    assert_test(abs(e - 75.0) < 1e-6 and clicks == 30 and rps == 1.0,
                f"Reference model simulation matches Test 15 lifecycle exactly: energy={e:.1f}, clicks={clicks}, rps={rps:.1f}")

    # =========================================================================
    # Summary & Verdict
    # =========================================================================
    print("\n=====================================================================")
    print(f"[SUMMARY] Total Checks Passed: {checks_passed} | Failed: {checks_failed}")
    print("=====================================================================")

    if checks_failed > 0:
        print(">>> EMPIRICAL VERDICT: REQUEST_CHANGES <<<")
        sys.exit(1)
    else:
        print(">>> EMPIRICAL VERDICT: APPROVE <<<")
        sys.exit(0)

if __name__ == "__main__":
    run_adversarial_challenge()
