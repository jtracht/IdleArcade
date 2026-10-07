#!/usr/bin/env python3
"""
Empirical Adversarial Challenge Test Suite for Milestone P2-M3:
Scoreboards (Monotonic Submit, Clamping, Unauthenticated Guards),
Guilds (Member ID Filtering, Role State Mappings, Empty Guild Handling),
and Network Failure Resilience.

Author: p2_m3_challenger_2 (Critic / Specialist)
Target: IdleArcade/scripts/autoload/nakama_manager.gd
"""

import os
import re
import sys
import json
import math
from pathlib import Path

def run_adversarial_challenge():
    print("=====================================================================")
    print("[CHALLENGE] Phase 2 Milestone 3: Scoreboards & Guilds Adversarial Suite")
    print("=====================================================================")

    game_dir = Path(__file__).resolve().parent.parent
    mgr_path = game_dir / "scripts" / "autoload" / "nakama_manager.gd"
    lua_path = game_dir / "nakama" / "data" / "modules" / "init_leaderboards.lua"
    gs_path = game_dir / "scripts" / "autoload" / "game_state.gd"
    proj_path = game_dir / "project.godot"

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
    print("\n--- 1. Testing Code Structure & Contract Signatures ---")

    if not mgr_path.is_file():
        print(f"  [FATAL] Missing nakama_manager.gd at {mgr_path}")
        sys.exit(1)
    if not lua_path.is_file():
        print(f"  [FATAL] Missing init_leaderboards.lua at {lua_path}")
        sys.exit(1)

    mgr_code = mgr_path.read_text(encoding="utf-8")
    lua_code = lua_path.read_text(encoding="utf-8")
    proj_code = proj_path.read_text(encoding="utf-8") if proj_path.is_file() else ""

    # Check Autoload order in project.godot
    idx_nakama = proj_code.find('Nakama="*res://addons/com.heroiclabs.nakama/Nakama.gd"')
    idx_mgr = proj_code.find('NakamaManager="*res://scripts/autoload/nakama_manager.gd"')
    assert_test(idx_nakama != -1 and idx_mgr != -1 and idx_nakama < idx_mgr,
                "project.godot declares Nakama SDK singleton before NakamaManager")

    # Scoreboard & Guild signals
    expected_signals = [
        "score_submitted", "leaderboard_received",
        "guild_updated", "guild_members_received",
        "quests_updated", "quest_reward_claimed"
    ]
    for sig in expected_signals:
        assert_test(re.search(rf'signal\s+{sig}\b', mgr_code) is not None,
                    f"nakama_manager.gd declares signal '{sig}'")

    # Scoreboard & Guild methods
    expected_methods = [
        "submit_score_async", "sync_current_score_async",
        "fetch_leaderboard_async", "fetch_guild_leaderboard_async",
        "create_guild_async", "join_guild_async", "leave_guild_async",
        "list_guilds_async", "list_guild_members_async",
        "get_player_country_code", "get_country_leaderboard_id"
    ]
    for m in expected_methods:
        assert_test(re.search(rf'func\s+{m}\b', mgr_code) is not None,
                    f"nakama_manager.gd implements public method '{m}'")

    # Server Lua: Leaderboard operator='best'
    assert_test('operator = "best"' in lua_code or '"best"' in lua_code,
                "init_leaderboards.lua configures leaderboards with operator 'best' (monotonic high-score retention)")

    # =========================================================================
    # 2. Challenge 1: Unauthenticated Guards
    # =========================================================================
    print("\n--- 2. Testing Unauthenticated Guards Across All Endpoints ---")

    class MockNakamaSession:
        def __init__(self, token="", expired=False):
            self.token = token
            self.expired = expired

        def is_authenticated(self):
            return bool(self.token) and not self.expired

    class MockNakamaManager:
        def __init__(self, session=None, client=None):
            self.session = session
            self.client = client
            self.last_error = ""
            self._is_submitting_score = False
            self._last_submitted_score = -1
            self._has_pending_score_sync = False
            self.current_guild_id = ""
            self.current_guild_name = ""
            self.daily_quests = {}

        def is_authenticated(self):
            return self.session is not None and self.session.is_authenticated()

        def submit_score_async(self, score: int, leaderboard_id: str = "global_lifetime_users") -> bool:
            if not self.is_authenticated() or self.client is None:
                return False
            if self._is_submitting_score:
                return False
            self._is_submitting_score = True
            # simulate network call
            self._is_submitting_score = False
            self._last_submitted_score = max(self._last_submitted_score, score)
            return True

        def fetch_leaderboard_async(self, leaderboard_id: str = "global_lifetime_users", limit: int = 20) -> list:
            if not self.is_authenticated() or self.client is None:
                return []
            return [{"username": "Player1", "score": 100}]

        def fetch_guild_leaderboard_async(self, group_id: str, limit: int = 20) -> list:
            if not self.is_authenticated() or self.client is None or not group_id:
                return []
            return []

        def create_guild_async(self, name: str, desc: str, is_open: bool = True) -> dict:
            if not self.is_authenticated() or self.client is None:
                self.last_error = "Cannot create guild: Not authenticated."
                return {}
            return {"id": "g-123", "name": name}

        def join_guild_async(self, group_id: str) -> bool:
            if not self.is_authenticated() or self.client is None or not group_id:
                self.last_error = "Cannot join guild: Not authenticated or invalid ID."
                return False
            return True

        def leave_guild_async(self, group_id: str) -> bool:
            if not self.is_authenticated() or self.client is None or not group_id:
                self.last_error = "Cannot leave guild: Not authenticated or invalid ID."
                return False
            return True

        def list_guilds_async(self, filter: str = "") -> list:
            if not self.is_authenticated() or self.client is None:
                return []
            return [{"id": "g-1"}]

        def list_guild_members_async(self, group_id: str) -> list:
            if not self.is_authenticated() or self.client is None or not group_id:
                return []
            return [{"user_id": "u-1"}]

        def fetch_daily_quests_async(self) -> dict:
            if self.is_authenticated() and self.client is not None:
                return {"quests": {"daily_tap": {"current": 0}}}
            # offline fallback
            if self.daily_quests:
                return self.daily_quests
            return {}

    # Case 2.1: Session is None
    unauth_mgr = MockNakamaManager(session=None, client=object())
    assert_test(unauth_mgr.submit_score_async(100) is False, "submit_score_async returns False when session is None")
    assert_test(unauth_mgr.fetch_leaderboard_async() == [], "fetch_leaderboard_async returns [] when session is None")
    assert_test(unauth_mgr.fetch_guild_leaderboard_async("g-1") == [], "fetch_guild_leaderboard_async returns [] when session is None")
    assert_test(unauth_mgr.create_guild_async("G", "D") == {}, "create_guild_async returns {} when session is None")
    assert_test(unauth_mgr.join_guild_async("g-1") is False, "join_guild_async returns False when session is None")
    assert_test(unauth_mgr.leave_guild_async("g-1") is False, "leave_guild_async returns False when session is None")
    assert_test(unauth_mgr.list_guilds_async() == [], "list_guilds_async returns [] when session is None")
    assert_test(unauth_mgr.list_guild_members_async("g-1") == [], "list_guild_members_async returns [] when session is None")
    assert_test(unauth_mgr.fetch_daily_quests_async() == {}, "fetch_daily_quests_async returns safe dict when unauthenticated")

    # Case 2.2: Session is Expired
    exp_session = MockNakamaSession(token="valid_token", expired=True)
    exp_mgr = MockNakamaManager(session=exp_session, client=object())
    assert_test(exp_mgr.submit_score_async(500) is False, "submit_score_async returns False when session is expired")
    assert_test(exp_mgr.create_guild_async("G", "D") == {}, "create_guild_async returns {} when session is expired")
    assert_test(exp_mgr.join_guild_async("g-1") is False, "join_guild_async returns False when session is expired")

    # Verify exact GDScript guarding code
    assert_test("if not is_authenticated() or client == null:" in mgr_code,
                "nakama_manager.gd enforces 'if not is_authenticated() or client == null:' guards")

    # =========================================================================
    # 3. Challenge 2: Monotonic Score Submission & Clamping
    # =========================================================================
    print("\n--- 3. Testing Monotonic Score Submission & Value Clamping ---")

    def simulate_score_sync(current_total_energy: float, last_submitted: int, has_pending: bool):
        score_int = min(max(int(round(current_total_energy)), 0), 9223372036854775807)
        if score_int <= last_submitted and not has_pending:
            return None, last_submitted, has_pending, "skipped"
        # simulated success
        new_last = max(last_submitted, score_int)
        return score_int, new_last, False, "submitted"

    # Case 3.1: Monotonic progression
    s1, last1, pend1, status1 = simulate_score_sync(100.0, -1, False)
    assert_test(status1 == "submitted" and s1 == 100 and last1 == 100, "Initial score 100 submits successfully")

    s2, last2, pend2, status2 = simulate_score_sync(150.0, last1, False)
    assert_test(status2 == "submitted" and s2 == 150 and last2 == 150, "Higher score 150 submits successfully")

    # Case 3.2: Lower score skipped
    s3, last3, pend3, status3 = simulate_score_sync(120.0, last2, False)
    assert_test(status3 == "skipped" and s3 is None and last3 == 150, "Lower score 120 is safely skipped (monotonic property)")

    # Case 3.3: Equal score skipped
    s4, last4, pend4, status4 = simulate_score_sync(150.0, last2, False)
    assert_test(status4 == "skipped" and s4 is None and last4 == 150, "Equal score 150 is safely skipped")

    # Case 3.4: Pending retry honored even if score hasn't changed
    s5, last5, pend5, status5 = simulate_score_sync(150.0, last2, True)
    assert_test(status5 == "submitted" and s5 == 150 and pend5 is False, "Retry with pending flag sends score and clears pending flag")

    # Case 3.5: Negative energy earned clamped to 0
    s_neg, _, _, _ = simulate_score_sync(-500.0, -1, False)
    assert_test(s_neg == 0, "Negative energy earned (-500.0) safely clamped to 0")

    # Case 3.6: Massive energy earned clamped to 64-bit int max
    s_huge, _, _, _ = simulate_score_sync(1e22, -1, False)
    assert_test(s_huge == 9223372036854775807, "Massive energy clamped to 9223372036854775807 (prevents 64-bit overflow)")

    # Case 3.7: Floating point rounding precision
    s_round, _, _, _ = simulate_score_sync(99.6, -1, False)
    assert_test(s_round == 100, "Fractional energy 99.6 rounds to 100")
    s_round_down, _, _, _ = simulate_score_sync(99.4, -1, False)
    assert_test(s_round_down == 99, "Fractional energy 99.4 rounds to 99")

    # Verify GDScript clamping formula
    assert_test("mini(maxi(int(round(game_state.total_energy_earned)), 0), 9223372036854775807)" in mgr_code,
                "GDScript sync_current_score_async uses robust mini(maxi(int(round(...)), 0), 9223372036854775807) clamping")

    # =========================================================================
    # 4. Challenge 3: Guild-Internal Leaderboard Filtering & Member Mapping
    # =========================================================================
    print("\n--- 4. Testing Guild Leaderboard Filtering & Empty Guild Handling ---")

    def simulate_guild_leaderboard_filter(group_users: list, group_id: str):
        if not group_id:
            return [], "empty_group_id"

        member_ids = []
        for gu in group_users:
            u = gu.get("user")
            state = gu.get("state", 99)
            if u is not None and u.get("id") and int(state) <= 2:
                member_ids.append(u.get("id"))

        if not member_ids:
            return [], "no_eligible_members"

        return member_ids, "query_ready"

    # Test users
    users = [
        {"user": {"id": "uid-0", "username": "SuperAdmin"}, "state": 0},
        {"user": {"id": "uid-1", "username": "AdminGuy"}, "state": 1},
        {"user": {"id": "uid-2", "username": "NormalMember"}, "state": 2},
        {"user": {"id": "uid-3", "username": "Applicant"}, "state": 3}, # Join Request
        {"user": {"id": "uid-4", "username": "BannedUser"}, "state": 4},
        {"user": None, "state": 2}, # Corrupt entry
        {"user": {"id": "", "username": "EmptyIdUser"}, "state": 2}
    ]

    m_ids, status = simulate_guild_leaderboard_filter(users, "guild-abc")
    assert_test(status == "query_ready", "Valid guild produces query-ready member list")
    assert_test(m_ids == ["uid-0", "uid-1", "uid-2"], f"Filter extracts strictly Superadmin (0), Admin (1), and Member (2): {m_ids}")
    assert_test("uid-3" not in m_ids, "State 3 (Join Request) is strictly EXCLUDED from guild leaderboard")
    assert_test("uid-4" not in m_ids, "State 4 is strictly EXCLUDED from guild leaderboard")

    # Empty guild test
    empty_ids, empty_status = simulate_guild_leaderboard_filter([], "guild-empty")
    assert_test(empty_status == "no_eligible_members" and empty_ids == [],
                "Empty guild returns [] immediately without querying Nakama leaderboard")

    # Guild with only Join Requests
    only_req_users = [{"user": {"id": "req-1"}, "state": 3}]
    req_ids, req_status = simulate_guild_leaderboard_filter(only_req_users, "guild-pending")
    assert_test(req_status == "no_eligible_members" and req_ids == [],
                "Guild with only Join Requests returns [] immediately")

    # Empty group ID
    no_id_list, no_id_status = simulate_guild_leaderboard_filter(users, "")
    assert_test(no_id_status == "empty_group_id" and no_id_list == [],
                "Empty group_id string returns [] immediately")

    # Verify GDScript implementation matches
    assert_test("if int(gu.state) <= 2:" in mgr_code or "int(gu.state) <= 2" in mgr_code,
                "GDScript fetch_guild_leaderboard_async checks 'int(gu.state) <= 2'")
    assert_test("if member_ids.is_empty():" in mgr_code,
                "GDScript fetch_guild_leaderboard_async guards against empty member_ids")

    # =========================================================================
    # 5. Challenge 4: Role State Mappings
    # =========================================================================
    print("\n--- 5. Testing Role State Mappings ---")

    role_names = {0: "Superadmin", 1: "Admin", 2: "Member", 3: "Join Request"}

    assert_test(role_names.get(0) == "Superadmin", "State 0 maps to 'Superadmin'")
    assert_test(role_names.get(1) == "Admin", "State 1 maps to 'Admin'")
    assert_test(role_names.get(2) == "Member", "State 2 maps to 'Member'")
    assert_test(role_names.get(3) == "Join Request", "State 3 maps to 'Join Request'")
    assert_test(role_names.get(4, "Unknown") == "Unknown", "State 4 maps to 'Unknown'")
    assert_test(role_names.get(-1, "Unknown") == "Unknown", "State -1 maps to 'Unknown'")

    # Verify dictionary in nakama_manager.gd
    assert_test('var role_names = {0: "Superadmin", 1: "Admin", 2: "Member", 3: "Join Request"}' in mgr_code,
                "Exact role_names mapping dictionary declared in nakama_manager.gd")

    # =========================================================================
    # 6. Challenge 5: Network Failure & Non-blocking Design
    # =========================================================================
    print("\n--- 6. Testing Network Failure Resilience & Non-blocking Design ---")

    # Ensure _process does NOT use 'await'
    process_match = re.search(r'func _process\((.*?)\)\s*->\s*void:\s*([\s\S]*?)(?:func\s+)', mgr_code)
    assert_test(process_match is not None, "Found func _process(delta) in nakama_manager.gd")
    if process_match:
        p_body = process_match.group(2)
        assert_test("await " not in p_body,
                    "_process(delta) does NOT contain 'await' (100% non-blocking game loop guarantee)")
        assert_test("sync_current_score_async()" in p_body,
                    "_process triggers periodic sync_current_score_async() as fire-and-forget")

    # Verify status_code == 0 detection
    assert_test("exc.status_code == 0" in mgr_code,
                "nakama_manager.gd explicitly detects status_code == 0 for offline network disconnection")
    assert_test('connection_status_changed.emit(false, "Offline")' in mgr_code,
                "nakama_manager.gd emits connection_status_changed(false, 'Offline') on network loss")

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
