#!/usr/bin/env python3
"""
Adversarial Challenge Verification Suite for Phase 2 Milestone 2:
Concurrency, Async Race Conditions, Autoload Order, Interface Contracts, and Regression Safety.
"""

import sys
import re
from pathlib import Path

def run_p2_m2_adversarial_suite():
    print("=====================================================================")
    print("[CHALLENGER 2] Phase 2 Milestone 2 Python Adversarial Verification")
    print("=====================================================================")

    game_dir = Path(__file__).resolve().parent.parent
    scripts_dir = game_dir / "scripts" / "autoload"
    tests_dir = game_dir / "tests"
    checks_passed = 0
    checks_failed = 0

    def assert_test(cond, msg):
        nonlocal checks_passed, checks_failed
        if cond:
            print(f"[PASS] {msg}")
            checks_passed += 1
        else:
            print(f"[FAIL] {msg}")
            checks_failed += 1

    # -------------------------------------------------------------------------
    # 1. Autoload Order in project.godot
    # -------------------------------------------------------------------------
    print("\n--- 1. Autoload Ordering in project.godot ---")
    proj_path = game_dir / "project.godot"
    proj_text = proj_path.read_text(encoding="utf-8")

    assert_test('GameState="*res://scripts/autoload/game_state.gd"' in proj_text, "GameState registered as singleton in project.godot")
    assert_test('Nakama="*res://addons/com.heroiclabs.nakama/Nakama.gd"' in proj_text, "Nakama registered as singleton in project.godot")
    assert_test('NakamaManager="*res://scripts/autoload/nakama_manager.gd"' in proj_text, "NakamaManager registered as singleton in project.godot")

    pos_gs = proj_text.find('GameState="*res://scripts/autoload/game_state.gd"')
    pos_nakama = proj_text.find('Nakama="*res://addons/com.heroiclabs.nakama/Nakama.gd"')
    pos_mgr = proj_text.find('NakamaManager="*res://scripts/autoload/nakama_manager.gd"')

    assert_test(pos_nakama < pos_mgr, f"Nakama (idx {pos_nakama}) precedes NakamaManager (idx {pos_mgr}) in project.godot autoloads")
    assert_test(pos_gs < pos_mgr, f"GameState (idx {pos_gs}) precedes NakamaManager (idx {pos_mgr}) in project.godot autoloads")

    # -------------------------------------------------------------------------
    # 2. Concurrency & Async Guards in nakama_manager.gd
    # -------------------------------------------------------------------------
    print("\n--- 2. Concurrency & Re-entrancy Debounce Guards ---")
    mgr_path = scripts_dir / "nakama_manager.gd"
    mgr_text = mgr_path.read_text(encoding="utf-8")

    assert_test("var is_authenticating: bool = false" in mgr_text, "is_authenticating state variable exists")
    
    # Check guard in auto_login_async
    auto_login_match = re.search(r"func auto_login_async\(\)[^:]*:\s+if is_authenticating:\s+return session\s+is_authenticating = true", mgr_text)
    assert_test(bool(auto_login_match), "auto_login_async() enforces re-entrancy lock")

    # Check guard in login_device_async
    device_login_match = re.search(r"func login_device_async\([^)]*\)[^:]*:\s+if is_authenticating:\s+return session\s+is_authenticating = true", mgr_text)
    assert_test(bool(device_login_match), "login_device_async() enforces re-entrancy lock")

    # Check guard in login_email_async
    email_login_match = re.search(r"func login_email_async\([^)]*\)[^:]*:\s+if is_authenticating:\s+return session\s+is_authenticating = true", mgr_text)
    assert_test(bool(email_login_match), "login_email_async() enforces re-entrancy lock")

    # Check guard in register_email_async
    reg_email_match = re.search(r"func register_email_async\([^)]*\)[^:]*:\s+if is_authenticating:\s+return session\s+is_authenticating = true", mgr_text)
    assert_test(bool(reg_email_match), "register_email_async() enforces re-entrancy lock")

    # Check that logout cleanly unsets state
    logout_match = re.search(r"func logout\(\)[^:]*:\s+session = null\s+is_online = false\s+_clear_saved_session\(\)\s+logged_out\.emit\(\)", mgr_text)
    assert_test(bool(logout_match), "logout() sets session=null, is_online=false, removes session file, and emits logged_out")

    # -------------------------------------------------------------------------
    # 3. P2-M3 Interface Stubs vs PROJECT.md Contracts
    # -------------------------------------------------------------------------
    print("\n--- 3. P2-M3 Interface Stubs vs PROJECT.md ---")
    p2_m3_methods = [
        ("submit_score_async", r"func submit_score_async\(score:\s*int,\s*leaderboard_id:\s*String\s*=\s*\"global_lifetime_users\"\) -> bool:"),
        ("fetch_leaderboard_async", r"func fetch_leaderboard_async\(leaderboard_id:\s*String\s*=\s*\"global_lifetime_users\",\s*limit:\s*int\s*=\s*20\) -> Array:"),
        ("fetch_guild_leaderboard_async", r"func fetch_guild_leaderboard_async\(group_id:\s*String,\s*limit:\s*int\s*=\s*20\) -> Array:"),
        ("create_guild_async", r"func create_guild_async\(name:\s*String,\s*desc:\s*String,\s*is_open:\s*bool\s*=\s*true\) -> Dictionary:"),
        ("join_guild_async", r"func join_guild_async\(group_id:\s*String\) -> bool:"),
        ("leave_guild_async", r"func leave_guild_async\(group_id:\s*String\) -> bool:"),
        ("list_guilds_async", r"func list_guilds_async\(filter:\s*String\s*=\s*\"\"\) -> Array:"),
        ("list_guild_members_async", r"func list_guild_members_async\(group_id:\s*String\) -> Array:"),
        ("fetch_daily_quests_async", r"func fetch_daily_quests_async\(\) -> Dictionary:"),
        ("record_quest_progress", r"func record_quest_progress\(quest_type:\s*String,\s*amount:\s*int\s*=\s*1\) -> void:"),
        ("claim_quest_reward_async", r"func claim_quest_reward_async\(quest_id:\s*String\) -> int:")
    ]

    for name, pattern in p2_m3_methods:
        found = bool(re.search(pattern, mgr_text))
        assert_test(found, f"P2-M3 method stub '{name}' matches contract signature")

    p2_m3_signals = [
        "signal score_submitted(leaderboard_id: String, score: int)",
        "signal leaderboard_received(leaderboard_id: String, records: Array)",
        "signal guild_updated(guild_data: Dictionary)",
        "signal guild_members_received(group_id: String, members: Array)",
        "signal quests_updated(quests_dict: Dictionary)",
        "signal quest_reward_claimed(quest_id: String, bonus_users: int)"
    ]

    for sig in p2_m3_signals:
        assert_test(sig in mgr_text, f"P2-M3 signal '{sig}' declared in nakama_manager.gd")

    # -------------------------------------------------------------------------
    # 4. Regression Invariance & GameState Decoupling
    # -------------------------------------------------------------------------
    print("\n--- 4. Regression Invariance & GameState Decoupling ---")
    gs_path = scripts_dir / "game_state.gd"
    gs_text = gs_path.read_text(encoding="utf-8")

    assert_test("Nakama" not in gs_text, "game_state.gd contains zero references to 'Nakama'")
    assert_test("NakamaManager" not in gs_text, "game_state.gd contains zero references to 'NakamaManager'")
    assert_test("/root/" not in gs_text, "game_state.gd has no external singleton dependencies via /root/")

    test_logic_path = tests_dir / "test_game_logic.gd"
    test_logic_text = test_logic_path.read_text(encoding="utf-8")
    assert_test("Nakama" not in test_logic_text, "test_game_logic.gd has zero dependencies on Nakama or online stack")

    # -------------------------------------------------------------------------
    # 5. Device ID Generation & RFC 4122 Compliance
    # -------------------------------------------------------------------------
    print("\n--- 5. Device ID Generation & RFC 4122 Compliance ---")
    assert_test("const DEVICE_ID_FILE: String = \"user://device_id.txt\"" in mgr_text, "DEVICE_ID_FILE constant set to user://device_id.txt")
    assert_test("const SESSION_FILE: String = \"user://nakama_session.json\"" in mgr_text, "SESSION_FILE constant set to user://nakama_session.json")
    assert_test("generate_uuid_v4" in mgr_text, "generate_uuid_v4 generator exists")
    assert_test("0x0F) | 0x40" in mgr_text, "UUID v4 version nibble masking (0x40) present")
    assert_test("0x3F) | 0x80" in mgr_text, "UUID v4 variant bits masking (0x80) present")

    # -------------------------------------------------------------------------
    # Summary & Verdict
    # -------------------------------------------------------------------------
    print("\n=====================================================================")
    print(f"[SUMMARY] Total Checks Passed: {checks_passed} | Failed: {checks_failed}")
    print("=====================================================================")

    if checks_failed > 0:
        print(">>> VERDICT: REQUEST_CHANGES <<<")
        sys.exit(1)
    else:
        print(">>> VERDICT: APPROVE <<<")
        sys.exit(0)

if __name__ == "__main__":
    run_p2_m2_adversarial_suite()
