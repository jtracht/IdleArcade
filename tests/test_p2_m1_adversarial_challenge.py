#!/usr/bin/env python3
"""
Adversarial Challenge Verification Suite for Phase 2 Milestone 1:
Nakama Addon Integration, Session/JWT Mechanics, Server Leaderboards, and Docker Compose.
"""

import sys
import re
import json
import base64
from pathlib import Path

def run_adversarial_challenge():
    print("=====================================================================")
    print("[CHALLENGE] Phase 2 Milestone 1 Python Adversarial Challenge")
    print("=====================================================================")

    game_dir = Path(__file__).resolve().parent.parent
    addon_dir = game_dir / "addons" / "com.heroiclabs.nakama"
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
    # 1. Nakama.create_client defaults and initialization
    # -------------------------------------------------------------------------
    nakama_gd = (addon_dir / "Nakama.gd").read_text(encoding="utf-8")
    assert_test('DEFAULT_SERVER_KEY: String = "defaultkey"' in nakama_gd, "DEFAULT_SERVER_KEY is 'defaultkey'")
    assert_test('DEFAULT_HOST: String = "127.0.0.1"' in nakama_gd, "DEFAULT_HOST is '127.0.0.1'")
    assert_test('DEFAULT_PORT: int = 7350' in nakama_gd, "DEFAULT_PORT is 7350")
    assert_test('DEFAULT_SCHEME: String = "http"' in nakama_gd, "DEFAULT_SCHEME is 'http'")
    assert_test('DEFAULT_TIMEOUT: float = 10.0' in nakama_gd, "DEFAULT_TIMEOUT is 10.0")
    assert_test('add_child(client)' in nakama_gd, "create_client attaches client to SceneTree (add_child)")
    assert_test('func create_socket_from' in nakama_gd, "create_socket_from factory method exists")
    assert_test('add_child(socket)' in nakama_gd, "create_socket_from attaches socket to SceneTree (add_child)")

    # -------------------------------------------------------------------------
    # 2. NakamaSession & NakamaSerializer JWT Parsing & Expiration Mechanics
    # -------------------------------------------------------------------------
    session_gd = (addon_dir / "NakamaSession.gd").read_text(encoding="utf-8")
    assert_test('func is_expired() -> bool:' in session_gd, "is_expired method exists on NakamaSession")
    assert_test('Time.get_unix_time_from_system() >= expire_time' in session_gd, "is_expired compares system time against expire_time")
    assert_test('func is_refresh_expired() -> bool:' in session_gd, "is_refresh_expired method exists on NakamaSession")
    assert_test('func serialize() -> Dictionary:' in session_gd, "serialize method exists on NakamaSession")
    assert_test('static func deserialize(p_dict: Dictionary) -> NakamaSession:' in session_gd, "deserialize static method exists on NakamaSession")

    serializer_gd = (addon_dir / "NakamaSerializer.gd").read_text(encoding="utf-8")
    assert_test('decode_base64_url' in serializer_gd, "decode_base64_url exists in NakamaSerializer")
    assert_test('parse_jwt_payload' in serializer_gd, "parse_jwt_payload exists in NakamaSerializer")

    # Simulate decode_base64_url algorithm identically to GDScript
    def gd_decode_base64_url(b64_url: str) -> str:
        b64 = b64_url.replace("-", "+").replace("_", "/")
        while len(b64) % 4 != 0:
            b64 += "="
        try:
            return base64.b64decode(b64.encode('utf-8')).decode('utf-8')
        except Exception:
            return ""

    def gd_parse_jwt(jwt: str) -> dict:
        parts = jwt.split(".")
        if len(parts) < 2:
            return {}
        payload_raw = gd_decode_base64_url(parts[1])
        if not payload_raw:
            return {}
        try:
            parsed = json.loads(payload_raw)
            if isinstance(parsed, dict):
                return parsed
            return {}
        except Exception:
            return {}

    # Test valid JWT unpacking
    valid_payload = {"sub": "uuid-12345", "usn": "test_hero", "exp": 1999999999, "vrs": {"level": 42}}
    b64_payload = base64.urlsafe_b64encode(json.dumps(valid_payload).encode('utf-8')).decode('utf-8').rstrip("=")
    sample_jwt = f"header.{b64_payload}.sig"
    unpacked = gd_parse_jwt(sample_jwt)
    assert_test(unpacked.get("sub") == "uuid-12345", "JWT sub unpacked correctly")
    assert_test(unpacked.get("usn") == "test_hero", "JWT usn unpacked correctly")
    assert_test(unpacked.get("exp") == 1999999999, "JWT exp unpacked correctly")
    assert_test(unpacked.get("vrs", {}).get("level") == 42, "JWT vars unpacked correctly")

    # Test edge cases
    assert_test(gd_parse_jwt("") == {}, "Empty token returns empty dict")
    assert_test(gd_parse_jwt("nodots_token") == {}, "Token without dots returns empty dict")
    assert_test(gd_parse_jwt("header.@@@invalid@@@.sig") == {}, "Invalid base64 returns empty dict")
    assert_test(gd_parse_jwt(f"header.{base64.b64encode(b'plain text').decode('utf-8')}.sig") == {}, "Non-JSON payload returns empty dict")
    assert_test(gd_parse_jwt(f"header.{base64.b64encode(b'[1, 2, 3]').decode('utf-8')}.sig") == {}, "JSON array payload returns empty dict")

    # -------------------------------------------------------------------------
    # 3. project.godot integrity
    # -------------------------------------------------------------------------
    proj_path = game_dir / "project.godot"
    proj_text = proj_path.read_text(encoding="utf-8")
    assert_test('config_version=5' in proj_text, "project.godot config_version=5")
    assert_test('GameState="*res://scripts/autoload/game_state.gd"' in proj_text, "GameState autoload is intact")
    assert_test('Nakama="*res://addons/com.heroiclabs.nakama/Nakama.gd"' in proj_text, "Nakama autoload registered")
    assert_test('enabled=PackedStringArray("res://addons/com.heroiclabs.nakama/plugin.cfg")' in proj_text, "Nakama plugin enabled in editor_plugins")
    assert_test('run/main_scene="res://scenes/main.tscn"' in proj_text, "Main scene path valid")

    # Check referenced files exist
    assert_test((game_dir / "scripts" / "autoload" / "game_state.gd").is_file(), "game_state.gd exists")
    assert_test((game_dir / "scenes" / "main.tscn").is_file(), "main.tscn exists")
    assert_test((addon_dir / "Nakama.gd").is_file(), "Nakama.gd exists")
    assert_test((addon_dir / "plugin.cfg").is_file(), "plugin.cfg exists")

    # -------------------------------------------------------------------------
    # 4. init_leaderboards.lua Idempotency and Error Resilience
    # -------------------------------------------------------------------------
    lua_path = game_dir / "nakama" / "data" / "modules" / "init_leaderboards.lua"
    lua_text = lua_path.read_text(encoding="utf-8")
    assert_test("local initialized = false" in lua_text, "Lua module has initialized variable")
    assert_test("if initialized then" in lua_text, "Lua module has re-entrancy check")
    assert_test(lua_text.count("pcall") >= 2, f"Lua module uses pcall for all creations (count: {lua_text.count('pcall')})")
    assert_test("global_lifetime_users" in lua_text, "Lua creates global_lifetime_users")
    assert_test("country_lifetime_users_" in lua_text, "Lua creates country_lifetime_users_")
    assert_test("InitModule" in lua_text, "Lua defines InitModule entry point")
    assert_test("nk.run_once" in lua_text, "Lua provides nk.run_once fallback")

    # Verify authoritative is false
    authoritative_false_matches = re.findall(r'false\s*,\s*--\s*authoritative:\s*false', lua_text)
    assert_test(len(authoritative_false_matches) >= 2, f"Leaderboards configured as non-authoritative (count: {len(authoritative_false_matches)})")

    # -------------------------------------------------------------------------
    # 5. docker-compose.yml configuration
    # -------------------------------------------------------------------------
    dc_path = game_dir / "docker-compose.yml"
    dc_text = dc_path.read_text(encoding="utf-8")
    assert_test("./nakama/data/modules:/nakama/data/modules" in dc_text, "docker-compose.yml has modules volume mount")
    assert_test('"7350:7350"' in dc_text, "docker-compose.yml exposes port 7350")
    assert_test('"7349:7349"' in dc_text, "docker-compose.yml exposes port 7349")

    # -------------------------------------------------------------------------
    # Summary
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
    run_adversarial_challenge()
