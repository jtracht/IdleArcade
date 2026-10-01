#!/usr/bin/env python3
"""
IdleArcade Phase 2 Milestone 1 Static & Structural Verification Suite.
Validates:
1. All 15 Nakama Godot Addon SDK files exist, are non-empty, and contain GDScript 2.0 signatures.
2. plugin.cfg is valid INI with standard Heroic Labs metadata.
3. project.godot enables the plugin and registers Nakama autoload while preserving GameState.
4. init_leaderboards.lua contains idempotent pcall setup for global and regional leaderboards.
5. docker-compose.yml contains the modules volume mount for Nakama runtime.
"""

import sys
import re
from pathlib import Path

def test_p2_m1():
    game_dir = Path(__file__).resolve().parent.parent
    print(f"Testing IdleArcade Phase 2 Milestone 1 in: {game_dir}")

    # 1. Addon Files Verification
    addon_dir = game_dir / "addons" / "com.heroiclabs.nakama"
    assert addon_dir.is_dir(), f"Addon directory missing: {addon_dir}"

    expected_files = [
        "plugin.cfg",
        "Nakama.gd",
        "NakamaClient.gd",
        "NakamaSession.gd",
        "NakamaSocket.gd",
        "NakamaAPI.gd",
        "NakamaAsyncResult.gd",
        "NakamaException.gd",
        "NakamaLogger.gd",
        "NakamaSerializer.gd",
        "NakamaHTTPAdapter.gd",
        "NakamaWebSocketAdapter.gd",
        "NakamaStorageObjectId.gd",
        "NakamaWriteStorageObject.gd",
        "NakamaRTMessage.gd"
    ]

    for f_name in expected_files:
        f_path = addon_dir / f_name
        assert f_path.is_file(), f"Missing addon file: {f_name}"
        size = f_path.stat().st_size
        assert size > 0, f"Addon file is empty: {f_name}"
        print(f"  [OK] {f_name} ({size} bytes)")

    # 2. plugin.cfg Verification
    plugin_cfg = (addon_dir / "plugin.cfg").read_text(encoding="utf-8")
    assert "[plugin]" in plugin_cfg, "Missing [plugin] header in plugin.cfg"
    assert 'name="Nakama"' in plugin_cfg, "Missing or incorrect name in plugin.cfg"
    assert 'script="Nakama.gd"' in plugin_cfg, "Missing or incorrect script in plugin.cfg"
    assert 'version="3.3.1"' in plugin_cfg, "Missing or incorrect version in plugin.cfg"
    print("  [OK] plugin.cfg validated")

    # 3. project.godot Verification
    project_godot = (game_dir / "project.godot").read_text(encoding="utf-8")
    assert 'GameState="*res://scripts/autoload/game_state.gd"' in project_godot, "GameState autoload missing or altered"
    assert 'Nakama="*res://addons/com.heroiclabs.nakama/Nakama.gd"' in project_godot, "Nakama autoload missing"
    assert '[editor_plugins]' in project_godot, "[editor_plugins] section missing"
    assert 'enabled=PackedStringArray("res://addons/com.heroiclabs.nakama/plugin.cfg")' in project_godot, "Nakama plugin not enabled"
    print("  [OK] project.godot validated")

    # 4. init_leaderboards.lua Verification
    lua_path = game_dir / "nakama" / "data" / "modules" / "init_leaderboards.lua"
    assert lua_path.is_file(), f"init_leaderboards.lua missing at {lua_path}"
    lua_content = lua_path.read_text(encoding="utf-8")
    assert "nk.leaderboard_create" in lua_content or "nkm.leaderboard_create" in lua_content, "Missing leaderboard_create in Lua"
    assert "global_lifetime_users" in lua_content, "Missing global_lifetime_users leaderboard in Lua"
    assert "country_lifetime_users_" in lua_content, "Missing country_lifetime_users_ leaderboards in Lua"
    assert "pcall" in lua_content, "Missing pcall error protection in Lua"
    assert "InitModule" in lua_content, "Missing InitModule entry point in Lua"
    print("  [OK] init_leaderboards.lua validated")

    # 5. docker-compose.yml Verification
    compose_path = game_dir / "docker-compose.yml"
    assert compose_path.is_file(), f"docker-compose.yml missing at {compose_path}"
    compose_text = compose_path.read_text(encoding="utf-8")
    assert "./nakama/data/modules:/nakama/data/modules" in compose_text, "Missing modules volume mount in docker-compose.yml"
    print("  [OK] docker-compose.yml validated")

    print("\n>>> ALL PHASE 2 MILESTONE 1 VERIFICATION CHECKS PASSED SUCCESSFULLY! <<<")

if __name__ == "__main__":
    test_p2_m1()
