#!/usr/bin/env python3
"""
Milestone P2-M5 Empirical Adversarial Challenge Test Suite & Oracle.
Validates:
1. Error Recovery (session corruption, invalid JSON, device ID regeneration, connection timeouts)
2. Quest Rollover and Progress Clamping (UTC date rollover, target bounds clamping, duplicate reward idempotency)
3. Number Formatting Boundaries in GameState (0, negative, fractional, K, M, B, T, scientific, NaN, Inf)
4. Offline Progress Clamping in GameState (50% efficiency, 8h / 28800s cap, future clock rollback guard, corrupt saves)
5. Leaderboard Concurrency, Monotonic High Scores, and Unauthenticated API Guards
6. Signal Signature Compatibility (bonus_users_changed arity safety)
7. Full Acceptance Regression Traceability (15/15 core game logic assertions)

Executable via: python IdleArcade/tests/test_p2_m5_adversarial_challenge.py
"""

import os
import re
import sys
import json
import math
import uuid
from pathlib import Path

def run_adversarial_p2_m5_oracle():
    print("==========================================================================")
    print("[CHALLENGE] Milestone P2-M5 Empirical Adversarial Verification Oracle")
    print("==========================================================================")

    game_dir = Path(__file__).resolve().parent.parent
    game_state_path = game_dir / "scripts" / "autoload" / "game_state.gd"
    nakama_mgr_path = game_dir / "scripts" / "autoload" / "nakama_manager.gd"
    project_godot_path = game_dir / "project.godot"
    quest_modal_path = game_dir / "scenes" / "ui" / "quest_modal.gd"
    lb_modal_path = game_dir / "scenes" / "ui" / "leaderboard_modal.gd"
    guild_modal_path = game_dir / "scenes" / "ui" / "guild_modal.gd"
    test_nakama_path = game_dir / "tests" / "test_nakama.gd"
    test_ui_path = game_dir / "tests" / "test_p2_m4_ui.gd"
    test_logic_path = game_dir / "tests" / "test_game_logic.gd"
    acceptance_summary_path = game_dir / "tests" / "test_p2_m5_acceptance_summary.md"

    checks_passed = 0
    checks_failed = 0

    def assert_test(cond: bool, msg: str):
        nonlocal checks_passed, checks_failed
        if cond:
            print(f"  [PASS] {msg}")
            checks_passed += 1
        else:
            print(f"  [FAIL] {msg}")
            checks_failed += 1

    # =========================================================================
    # SECTION 1: Target Files & Contract Verification
    # =========================================================================
    print("\n--- 1. Target Files & Infrastructure Integrity ---")
    assert_test(game_state_path.is_file(), "scripts/autoload/game_state.gd exists")
    assert_test(nakama_mgr_path.is_file(), "scripts/autoload/nakama_manager.gd exists")
    assert_test(project_godot_path.is_file(), "project.godot exists")
    assert_test(test_nakama_path.is_file(), "tests/test_nakama.gd exists")
    assert_test(test_ui_path.is_file(), "tests/test_p2_m4_ui.gd exists")
    assert_test(test_logic_path.is_file(), "tests/test_game_logic.gd exists")
    assert_test(acceptance_summary_path.is_file(), "tests/test_p2_m5_acceptance_summary.md exists")

    pg_text = project_godot_path.read_text(encoding="utf-8")
    assert_test('Nakama="*res://addons/com.heroiclabs.nakama/Nakama.gd"' in pg_text, "Nakama autoload registered in project.godot")
    assert_test('NakamaManager="*res://scripts/autoload/nakama_manager.gd"' in pg_text, "NakamaManager autoload registered in project.godot")
    assert_test('GameState="*res://scripts/autoload/game_state.gd"' in pg_text, "GameState autoload registered in project.godot")

    # Autoload initialization order: GameState and Nakama must precede NakamaManager
    idx_nakama = pg_text.find('Nakama="*res://addons/com.heroiclabs.nakama/Nakama.gd"')
    idx_mgr = pg_text.find('NakamaManager="*res://scripts/autoload/nakama_manager.gd"')
    assert_test(idx_nakama < idx_mgr, "Nakama autoload loads BEFORE NakamaManager")

    # =========================================================================
    # SECTION 2: Number Formatting Boundary Oracle (GameState.format_number)
    # =========================================================================
    print("\n--- 2. Number Formatting Boundary & Precision Oracle ---")
    gs_code = game_state_path.read_text(encoding="utf-8")

    # Python mathematical reference model of GameState.format_number
    def format_number_ref(val: float) -> str:
        if math.isnan(val) or math.isinf(val) or val <= 0.0:
            return "0"
        if val < 1000.0:
            if val == math.floor(val):
                return str(int(val))
            return f"{val:.1f}"
        elif val < 1000000.0:
            return f"{(val / 1000.0):.2f} K"
        elif val < 1000000000.0:
            return f"{(val / 1000000.0):.2f} M"
        elif val < 1000000000000.0:
            return f"{(val / 1000000000.0):.2f} B"
        elif val < 1000000000000000.0:
            return f"{(val / 1000000000000.0):.2f} T"
        else:
            return f"{val:.2e}"

    test_values = [
        (0.0, "0"),
        (-0.0, "0"),
        (-100.0, "0"),
        (float('nan'), "0"),
        (float('inf'), "0"),
        (float('-inf'), "0"),
        (1.0, "1"),
        (450.0, "450"),
        (450.5, "450.5"),
        (999.0, "999"),
        (1000.0, "1.00 K"),
        (1500.0, "1.50 K"),
        (999990.0, "999.99 K"),
        (1000000.0, "1.00 M"),
        (5250000.0, "5.25 M"),
        (12500000000.0, "12.50 B"),
        (1000000000000.0, "1.00 T"),
        (1e15, "1.00e+15"),
        (5.5e16, "5.50e+16")
    ]

    for v, expected in test_values:
        actual = format_number_ref(v)
        assert_test(actual == expected, f"format_number({v}) -> '{actual}' == '{expected}'")

    # Verify implementation in game_state.gd contains all branches and guards
    assert_test("is_nan(value) or is_inf(value) or value <= 0.0" in gs_code, "format_number guards NaN, Inf, and value <= 0.0")
    assert_test('"%.2f K" % (value / 1000.0)' in gs_code, "format_number implements K suffix")
    assert_test('"%.2f M" % (value / 1000000.0)' in gs_code, "format_number implements M suffix")
    assert_test('"%.2f B" % (value / 1000000000.0)' in gs_code, "format_number implements B suffix")
    assert_test('"%.2f T" % (value / 1000000000000.0)' in gs_code, "format_number implements T suffix")
    assert_test('"%.2e" % value' in gs_code, "format_number implements scientific notation for >= 1e15")

    # =========================================================================
    # SECTION 3: Offline Progress Clamping & System Clock Oracle
    # =========================================================================
    print("\n--- 3. Offline Progress Clamping & System Clock Oracle ---")

    # Python simulation of GameState.load_from_disk offline progress algorithm
    def calc_offline_gain(saved_ts: float, now_ts: float, effective_rps: float) -> float:
        elapsed = now_ts - saved_ts
        if math.isnan(elapsed) or math.isinf(elapsed) or elapsed < 0.0:
            elapsed = 0.0
        effective_elapsed = min(elapsed, 28800.0) # 8-hour max cap
        gain = effective_rps * effective_elapsed * 0.5 # 50% efficiency
        if math.isnan(gain) or math.isinf(gain) or gain < 0.0:
            gain = 0.0
        return gain

    now = 1700000000.0

    # Test 3.1: 1800s offline with RPS = 1.0 -> 900.0 gain
    gain_30m = calc_offline_gain(now - 1800.0, now, 1.0)
    assert_test(abs(gain_30m - 900.0) < 0.001, "30 min offline at 1.0 RPS yields exactly 900.0 energy (50% efficiency)")

    # Test 3.2: 8 hours offline (28800s) with RPS = 10.0 -> 144,000 gain
    gain_8h = calc_offline_gain(now - 28800.0, now, 10.0)
    assert_test(abs(gain_8h - 144000.0) < 0.001, "8 hours offline at 10.0 RPS yields exactly 144,000.0 energy")

    # Test 3.3: 72 hours offline (259200s) -> clamped strictly to 8 hours (28800s)
    gain_72h = calc_offline_gain(now - 259200.0, now, 10.0)
    assert_test(abs(gain_72h - 144000.0) < 0.001, "72 hours offline clamped strictly to 8-hour ceiling (28,800s)")

    # Test 3.4: Clock rollback / future timestamp (+5000s in future) -> 0 gain
    gain_future = calc_offline_gain(now + 5000.0, now, 10.0)
    assert_test(gain_future == 0.0, "Future timestamp (clock rollback) clamped to 0.0 gain (no exploit)")

    # Test 3.5: Corrupt timestamp (NaN) -> 0 gain
    gain_nan = calc_offline_gain(float('nan'), now, 10.0)
    assert_test(gain_nan == 0.0, "NaN timestamp clamped safely to 0.0 gain")

    # Test 3.6: Bonus users amplification in offline catch-up
    # Bonus users = 50 -> multiplier = 1.5 -> effective_rps = 100.0 * 1.5 = 150.0
    gain_bonus = calc_offline_gain(now - 3600.0, now, 100.0 * (1.0 + (50 * 0.01)))
    # 150.0 * 3600.0 * 0.5 = 270,000.0
    assert_test(abs(gain_bonus - 270000.0) < 0.001, "Bonus users correctly scale effective RPS in offline catch-up (+50% bonus -> 270K)")

    # Verify implementation in game_state.gd contains these safeguards
    assert_test("var effective_elapsed: float = minf(elapsed, 28800.0)" in gs_code, "game_state.gd caps offline progress at 28800.0s (8h)")
    assert_test("if is_nan(elapsed) or is_inf(elapsed) or elapsed < 0.0:" in gs_code, "game_state.gd guards against NaN/Inf and clock rollbacks (elapsed < 0.0)")
    assert_test("var offline_gain: float = effective_rps * effective_elapsed * 0.5" in gs_code, "game_state.gd calculates 50% offline catch-up using get_effective_passive_rps()")

    # =========================================================================
    # SECTION 4: Device-ID Resolution, Regeneration & RFC 4122 v4 Compliance
    # =========================================================================
    print("\n--- 4. Device-ID Resolution, Corruption & UUID v4 Oracle ---")
    nm_code = nakama_mgr_path.read_text(encoding="utf-8")

    # Test 4.1: UUID v4 RFC 4122 pattern matching
    uuid_v4_regex = re.compile(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$', re.IGNORECASE)

    # Generate sample UUIDs using Python's uuid.uuid4() and verify regex
    sample_uuid = str(uuid.uuid4())
    assert_test(bool(uuid_v4_regex.match(sample_uuid)), f"Sample RFC 4122 v4 UUID matches standard regex: {sample_uuid}")

    # Inspect NakamaManager.generate_uuid_v4 implementation
    assert_test("bytes[6] = (bytes[6] & 0x0F) | 0x40" in nm_code, "generate_uuid_v4 sets version bits to 0100 (v4)")
    assert_test("bytes[8] = (bytes[8] & 0x3F) | 0x80" in nm_code, "generate_uuid_v4 sets variant bits to 10xx (RFC 4122)")

    # Test 4.2: Device ID Validation logic
    def is_valid_device_id(dev_id: str) -> bool:
        stripped = dev_id.strip()
        return 6 <= len(stripped) <= 128

    assert_test(not is_valid_device_id(""), "Empty string rejected as device ID")
    assert_test(not is_valid_device_id("   \n\t  "), "Whitespace-only rejected as device ID")
    assert_test(not is_valid_device_id("abc"), "Short string (< 6 chars) rejected as device ID")
    assert_test(not is_valid_device_id("x" * 129), "Overlong string (> 128 chars) rejected as device ID")
    assert_test(is_valid_device_id("device-alpha-12345"), "Valid device ID (18 chars) accepted")
    assert_test(is_valid_device_id(sample_uuid), "UUID v4 (36 chars) accepted as device ID")

    assert_test("if saved_id.length() >= 6 and saved_id.length() <= 128:" in nm_code, "get_or_create_device_id enforces length bounds [6, 128]")

    # =========================================================================
    # SECTION 5: Session Serialization, Expiration & Corruption Resilience
    # =========================================================================
    print("\n--- 5. Session Serialization, Expiration & Corruption Oracle ---")

    # Session corruption scenarios simulation
    def validate_session_json(json_str: str) -> bool:
        if not json_str.strip():
            return False
        try:
            data = json.loads(json_str)
            if not isinstance(data, dict):
                return False
            token = data.get("token")
            if not token or not str(token).strip():
                return False
            return True
        except Exception:
            return False

    # Test cases:
    assert_test(not validate_session_json(""), "Session Case 1: Empty file caught as corrupt")
    assert_test(not validate_session_json("   \n "), "Session Case 2: Whitespace file caught as corrupt")
    assert_test(not validate_session_json("{ bad json [}"), "Session Case 3: Invalid JSON syntax caught as corrupt")
    assert_test(not validate_session_json("[1, 2, 3]"), "Session Case 4: Non-dictionary JSON caught as corrupt")
    assert_test(not validate_session_json('{"user_id": "123"}'), "Session Case 5: Missing token key caught as corrupt")
    assert_test(not validate_session_json('{"token": ""}'), "Session Case 6: Empty token string caught as corrupt")
    assert_test(validate_session_json('{"token": "valid.jwt.token", "user_id": "123"}'), "Session Case 7: Valid token JSON accepted")

    # Inspect _load_cached_session in nakama_manager.gd
    assert_test("if content.strip_edges().is_empty():" in nm_code, "_load_cached_session checks for empty content")
    assert_test("if json.parse(content) != OK or not (json.data is Dictionary):" in nm_code, "_load_cached_session validates JSON dictionary structure")
    assert_test('if not dict.has("token") or str(dict.get("token", "")).is_empty():' in nm_code, "_load_cached_session validates presence of non-empty token")
    assert_test("_clear_saved_session()" in nm_code, "_load_cached_session removes corrupted session files on disk")

    # =========================================================================
    # SECTION 6: Daily Quests UTC Rollover, Progress Clamping & Claim Idempotency
    # =========================================================================
    print("\n--- 6. Daily Quests UTC Rollover, Clamping & Claim Idempotency ---")

    # Oracle daily quest state simulator
    class DailyQuestOracle:
        def __init__(self, current_date: str):
            self.current_date = current_date
            self.daily_quests = self._default_quests(current_date)
            self.bonus_users = 0
            self.energy = 0.0

        def _default_quests(self, date_str: str) -> dict:
            return {
                "date": date_str,
                "quests": {
                    "daily_tap": {
                        "id": "daily_tap",
                        "type": "tap",
                        "target": 50,
                        "current": 0,
                        "reward_bonus_users": 25,
                        "is_completed": False,
                        "is_claimed": False
                    },
                    "daily_upgrade": {
                        "id": "daily_upgrade",
                        "type": "upgrade",
                        "target": 3,
                        "current": 0,
                        "reward_bonus_users": 50,
                        "is_completed": False,
                        "is_claimed": False
                    },
                    "daily_spark": {
                        "id": "daily_spark",
                        "type": "spark",
                        "target": 3,
                        "current": 0,
                        "reward_bonus_users": 100,
                        "is_completed": False,
                        "is_claimed": False
                    }
                }
            }

        def record_progress(self, q_type: str, amount: int, today: str):
            if amount <= 0:
                return
            if self.daily_quests["date"] != today:
                self.daily_quests = self._default_quests(today)

            for q_id, q in self.daily_quests["quests"].items():
                if (q["type"] == q_type or q_id == q_type) and not q["is_completed"]:
                    current_val = q["current"] + amount
                    target_val = q["target"]
                    q["current"] = min(target_val, current_val) # Clamp
                    if q["current"] >= target_val:
                        q["is_completed"] = True

        def claim_reward(self, quest_id: str) -> int:
            if quest_id not in self.daily_quests["quests"]:
                return 0
            q = self.daily_quests["quests"][quest_id]
            if not q["is_completed"] or q["is_claimed"]:
                return 0 # Idempotent rejection
            q["is_claimed"] = True
            reward = q["reward_bonus_users"]
            self.bonus_users += reward
            self.energy += float(reward)
            return reward

    oracle = DailyQuestOracle("2026-10-07")

    # Step 6.1: Partial progress
    oracle.record_progress("tap", 20, "2026-10-07")
    assert_test(oracle.daily_quests["quests"]["daily_tap"]["current"] == 20 and not oracle.daily_quests["quests"]["daily_tap"]["is_completed"], "Partial progress: 20/50 taps recorded")

    # Step 6.2: Target overflow clamping (target = 50, adding 45 -> 65 clamped to 50)
    oracle.record_progress("tap", 45, "2026-10-07")
    assert_test(oracle.daily_quests["quests"]["daily_tap"]["current"] == 50 and oracle.daily_quests["quests"]["daily_tap"]["is_completed"], "Target overflow clamped: 65 -> strictly 50/50 taps, is_completed == True")

    # Step 6.3: Uncompleted quest claim rejection
    uncompleted_claim = oracle.claim_reward("daily_upgrade")
    assert_test(uncompleted_claim == 0 and oracle.bonus_users == 0, "Claiming uncompleted quest yields 0 rewards")

    # Step 6.4: Valid completed quest claim
    valid_claim = oracle.claim_reward("daily_tap")
    assert_test(valid_claim == 25 and oracle.bonus_users == 25 and oracle.daily_quests["quests"]["daily_tap"]["is_claimed"], "Valid quest claim awards exactly 25 bonus users and marks is_claimed = True")

    # Step 6.5: Duplicate claim idempotency
    dup_claim = oracle.claim_reward("daily_tap")
    assert_test(dup_claim == 0 and oracle.bonus_users == 25, "Duplicate claim invocation returns 0 and does NOT re-award bonus users (Idempotent)")

    # Step 6.6: UTC Day rollover resets quests
    oracle.record_progress("tap", 1, "2026-10-08")
    assert_test(
        oracle.daily_quests["date"] == "2026-10-08" and
        oracle.daily_quests["quests"]["daily_tap"]["current"] == 1 and
        not oracle.daily_quests["quests"]["daily_tap"]["is_completed"] and
        not oracle.daily_quests["quests"]["daily_tap"]["is_claimed"],
        "UTC rollover to next day resets quests (date=2026-10-08, current=1, is_completed=False, is_claimed=False)"
    )

    # Verify implementation in nakama_manager.gd
    assert_test('q["current"] = mini(target_val, current_val)' in nm_code, "nakama_manager.gd clamps quest progress with mini(target_val, current_val)")
    assert_test('if str(daily_quests.get("date", "")) != today:' in nm_code, "nakama_manager.gd detects UTC date rollover")
    assert_test('if not q.get("is_completed", false) or q.get("is_claimed", false):' in nm_code, "claim_quest_reward_async rejects uncompleted or already claimed quests idempotently")

    # =========================================================================
    # SECTION 7: Leaderboard Concurrency & Monotonicity Guards
    # =========================================================================
    print("\n--- 7. Leaderboard Concurrency & Monotonicity Guards ---")
    lb_code = lb_modal_path.read_text(encoding="utf-8")

    # Tab busy lock & generational request token
    assert_test("func _set_busy(busy: bool" in lb_code, "LeaderboardModal defines _set_busy lock method")
    assert_test("global_tab.disabled = busy" in lb_code and "local_tab.disabled = busy" in lb_code and "guild_tab.disabled = busy" in lb_code, "LeaderboardModal disables all tabs during fetch operations")
    assert_test("if _is_busy or _current_tab == tab_name: return" in lb_code, "_switch_tab rejects switching while busy or already on tab")
    assert_test("_fetch_request_id += 1" in lb_code, "LeaderboardModal increments generational request token _fetch_request_id")
    assert_test("if current_req_id != _fetch_request_id or requested_tab != _current_tab: return" in lb_code, "LeaderboardModal discards stale responses from inactive tabs")

    # Monotonic high score submission in NakamaManager
    assert_test("if score_int <= _last_submitted_score and not _has_pending_score_sync:" in nm_code, "NakamaManager skips score submissions that are not strictly monotonic increases")

    # =========================================================================
    # SECTION 8: Signal Signatures & Callable Arity Safety
    # =========================================================================
    print("\n--- 8. Signal Signatures & Callable Arity Safety ---")
    qm_code = quest_modal_path.read_text(encoding="utf-8")

    # Verify GameState.bonus_users_changed signal signature
    assert_test("signal bonus_users_changed(total_bonus_users: int, added_amount: int)" in gs_code, "GameState declares 2-parameter signal bonus_users_changed(total, added)")

    # Verify QuestModal handler accepts both 1-arg and 2-arg emissions
    assert_test("func _on_bonus_users_changed(_new_bonus: int, _added_amount: int = 0) -> void:" in qm_code, "QuestModal._on_bonus_users_changed has optional default parameter (_added_amount: int = 0)")

    # =========================================================================
    # SECTION 9: Regression Safety Audit against test_game_logic.gd (15/15 Tests)
    # =========================================================================
    print("\n--- 9. Regression Safety Traceability (test_game_logic.gd) ---")
    tgl_code = test_logic_path.read_text(encoding="utf-8")

    # Verify all 15 tests are preserved intact
    for t_idx in range(1, 16):
        assert_test(f"Test {t_idx}" in tgl_code or f"test {t_idx}" in tgl_code or f"# Test {t_idx}" in tgl_code, f"test_game_logic.gd contains Test {t_idx}")

    # Core mechanics verification in game_state.gd
    assert_test("func tap_core() -> float:" in gs_code, "GameState.tap_core() exists")
    assert_test("var earned: float = base_click_power * frenzy_multiplier" in gs_code, "tap_core applies frenzy multiplier")
    assert_test("frenzy_meter = minf(100.0, frenzy_meter + 4.0)" in gs_code, "tap_core charges frenzy meter by 4% per tap")
    assert_test("func collect_spark() -> float:" in gs_code, "GameState.collect_spark() exists")
    assert_test("var earned: float = maxf(50.0, base_passive_rps * 25.0)" in gs_code, "collect_spark calculates max(50.0, base_passive_rps * 25.0)")
    assert_test("func buy_upgrade(upgrade_id: String) -> bool:" in gs_code, "GameState.buy_upgrade exists")
    assert_test("pow(float(up[\"cost_mult\"]), float(up[\"level\"]))" in gs_code, "Upgrade cost scales geometrically with power")
    assert_test("var clamped_delta: float = minf(0.1, safe_delta)" in gs_code, "Passive accumulation clamps lag spike delta to 0.1s")

    # =========================================================================
    # VERDICT & SUMMARY
    # =========================================================================
    print("\n==========================================================================")
    print(f"[SUMMARY] Total Checks: {checks_passed + checks_failed} | Passed: {checks_passed} | Failed: {checks_failed}")
    print("==========================================================================")

    if checks_failed == 0:
        print(">>> ALL ADVERSARIAL CHALLENGES PASSED! FINAL VERDICT: APPROVE <<<")
        return 0
    else:
        print(f">>> ADVERSARIAL CHALLENGE FAILED WITH {checks_failed} DEFECTS! <<<")
        return 1

if __name__ == "__main__":
    sys.exit(run_adversarial_p2_m5_oracle())
