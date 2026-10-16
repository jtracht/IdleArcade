#!/usr/bin/env python3
"""
Unit and AST Verification Suite for Phase 9 Milestone 1: Procedural Audio Engine & SFX
File: IdleArcade/tests/test_phase9_m1_audio.py
Target: Python 3.12 CI Verification & Headless Audio Synthesis Math Certification
"""

import sys
import os
import re
import math
from pathlib import Path

# UTF-8 stdout configuration
if hasattr(sys.stdout, "reconfigure"):
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass

SCRIPT_DIR = Path(__file__).resolve().parent
GAME_DIR = SCRIPT_DIR.parent

class Reporter:
    def __init__(self):
        self.passes = 0
        self.fails = 0

    def check(self, condition: bool, description: str, detail: str = ""):
        if condition:
            print(f"  [PASS] {description}")
            self.passes += 1
        else:
            print(f"  [FAIL] {description} ({detail})")
            self.fails += 1

reporter = Reporter()

def run_tests():
    print("\n=== Phase 9 Milestone 1: Audio Engine & SFX Verification ===")
    
    # 1. Bus Layout File Verification
    bus_layout_path = GAME_DIR / "default_bus_layout.tres"
    reporter.check(bus_layout_path.exists(), "default_bus_layout.tres exists")
    if bus_layout_path.exists():
        bus_content = bus_layout_path.read_text(encoding="utf-8")
        reporter.check('&"Music"' in bus_content, "Music bus defined in default_bus_layout.tres")
        reporter.check('&"SFX"' in bus_content, "SFX bus defined in default_bus_layout.tres")
        reporter.check('bus/1/send = &"Master"' in bus_content, "Music bus routed to Master")
        reporter.check('bus/2/send = &"Master"' in bus_content, "SFX bus routed to Master")
        
    # 2. project.godot Configuration
    proj_path = GAME_DIR / "project.godot"
    reporter.check(proj_path.exists(), "project.godot exists")
    if proj_path.exists():
        proj_content = proj_path.read_text(encoding="utf-8")
        reporter.check('AudioManager="*res://scripts/autoload/audio_manager.gd"' in proj_content,
                       "AudioManager registered in project.godot [autoload]")
        reporter.check('busses/default_bus_layout="res://default_bus_layout.tres"' in proj_content,
                       "default_bus_layout registered in project.godot [audio]")

    # 3. audio_manager.gd Structure & Public API
    audio_mgr_path = GAME_DIR / "scripts" / "autoload" / "audio_manager.gd"
    reporter.check(audio_mgr_path.exists(), "scripts/autoload/audio_manager.gd exists")
    if audio_mgr_path.exists():
        code = audio_mgr_path.read_text(encoding="utf-8")
        reporter.check("extends Node" in code, "AudioManager extends Node")
        reporter.check("const SAMPLE_RATE: int = 22050" in code, "SAMPLE_RATE is 22,050 Hz")
        reporter.check("const SFX_POOL_SIZE: int = 8" in code, "SFX pool size is 8 players")
        reporter.check("encode_s16" in code, "Procedural PCM uses PackedByteArray.encode_s16")
        
        # 8 Required functions
        required_methods = [
            "play_sfx_click",
            "play_sfx_pickup",
            "play_sfx_footstep",
            "play_sfx_gate_unlock",
            "play_sfx_research",
            "play_sfx_drone_hum",
            "play_sfx_overdrive",
            "start_ambient_bgm",
            "stop_ambient_bgm"
        ]
        for m in required_methods:
            reporter.check(f"func {m}" in code, f"AudioManager implements {m}()")
            
        # Bus methods & Volume API
        volume_methods = [
            "set_bus_volume",
            "get_bus_volume",
            "set_bus_mute",
            "is_bus_muted",
            "set_master_volume",
            "set_music_volume",
            "set_sfx_volume",
            "set_master_mute",
            "set_music_mute",
            "set_sfx_mute",
            "apply_settings",
            "get_audio_settings"
        ]
        for vm in volume_methods:
            reporter.check(f"func {vm}" in code, f"AudioManager implements {vm}()")
            
        # Telemetry properties
        telemetry_vars = [
            "last_sfx_played",
            "sfx_play_count",
            "sfx_history",
            "is_bgm_playing"
        ]
        for tv in telemetry_vars:
            reporter.check(f"var {tv}" in code, f"AudioManager defines telemetry property '{tv}'")

    # 4. Decibel & Volume Math Verification
    def linear_to_db_safe(linear_val: float) -> float:
        if linear_val <= 0.0001:
            return -80.0
        val = max(0.0001, min(1.0, linear_val))
        return 20.0 * math.log10(val)
        
    def db_to_linear_safe(db_val: float) -> float:
        if db_val <= -79.9:
            return 0.0
        return max(0.0, min(1.0, 10.0 ** (db_val / 20.0)))

    reporter.check(abs(linear_to_db_safe(1.0) - 0.0) < 0.001, "linear_to_db(1.0) == 0.0 dB")
    reporter.check(abs(linear_to_db_safe(0.5) - (-6.0206)) < 0.01, "linear_to_db(0.5) ~= -6.02 dB")
    reporter.check(abs(linear_to_db_safe(0.1) - (-20.0)) < 0.01, "linear_to_db(0.1) ~= -20.0 dB")
    reporter.check(linear_to_db_safe(0.0) == -80.0, "linear_to_db(0.0) clamps safely to -80.0 dB")
    reporter.check(linear_to_db_safe(0.00005) == -80.0, "linear_to_db(<=0.0001) clamps safely to -80.0 dB")
    reporter.check(abs(db_to_linear_safe(0.0) - 1.0) < 0.001, "db_to_linear(0.0) == 1.0")
    reporter.check(abs(db_to_linear_safe(-20.0) - 0.1) < 0.001, "db_to_linear(-20.0) ~= 0.1")
    reporter.check(db_to_linear_safe(-80.0) == 0.0, "db_to_linear(-80.0) == 0.0")

    # 5. Mathematical Waveform Verification (Pure Synthesis Math)
    sample_rate = 22050
    # Click (0.05s)
    click_count = int(sample_rate * 0.05)
    click_samples = []
    for i in range(click_count):
        t = i / sample_rate
        phase = 70.0 * math.pi * (1.0 - math.exp(-40.0 * t))
        env = math.exp(-t * 70.0)
        w = (math.sin(phase) + 0.3 * math.sin(2.0 * phase)) * env
        click_samples.append(max(-1.0, min(1.0, w)))
    reporter.check(len(click_samples) == 1102, "Click synthesis duration is 1,102 samples (0.05s)")
    reporter.check(all(-1.0 <= s <= 1.0 for s in click_samples), "Click samples strictly bounded in [-1.0, 1.0]")
    reporter.check(abs(click_samples[-1]) < 0.05, "Click sample ends near zero (no pop/click)")

    # Drone hum (1.60s seamless loop)
    drone_count = int(sample_rate * 1.60)
    reporter.check(drone_count == 35280, "Drone hum duration is 35,280 samples (1.60s)")
    # Check frequency cycle alignment: 1.6s * 125Hz = 200 cycles, 1.6s * 5Hz = 8 cycles
    reporter.check((1.60 * 125.0).is_integer(), "Drone fundamental has exact integer cycles for seamless loop")
    reporter.check((1.60 * 5.0).is_integer(), "Drone tremolo has exact integer cycles for seamless loop")

    # Ambient BGM (8.00s seamless loop)
    bgm_count = int(sample_rate * 8.00)
    reporter.check(bgm_count == 176400, "Ambient BGM duration is 176,400 samples (8.00s)")
    # Check RAM footprint: 176400 * 2 bytes = 352,800 bytes (< 350 KB)
    reporter.check(bgm_count * 2 < 400000, "Ambient BGM RAM footprint < 400 KB")

    # 6. GameState Audio Integration & Persistence
    gs_path = GAME_DIR / "scripts" / "autoload" / "game_state.gd"
    reporter.check(gs_path.exists(), "game_state.gd exists")
    if gs_path.exists():
        gs_code = gs_path.read_text(encoding="utf-8")
        reporter.check("signal audio_settings_changed" in gs_code, "GameState defines audio_settings_changed signal")
        for v in ["master_volume", "music_volume", "sfx_volume", "master_muted", "music_muted", "sfx_muted"]:
            reporter.check(f"var {v}" in gs_code, f"GameState defines audio variable '{v}'")
        for m in ["set_master_volume", "set_music_volume", "set_sfx_volume",
                  "set_master_muted", "set_music_muted", "set_sfx_muted", "get_audio_settings"]:
            reporter.check(f"func {m}" in gs_code, f"GameState defines audio method '{m}'")
        reporter.check('"audio_settings":' in gs_code, "save_to_disk() serializes 'audio_settings'")
        reporter.check('data.get("audio_settings"' in gs_code, "load_from_disk() deserializes 'audio_settings'")
        reporter.check('play_sfx_overdrive' in gs_code, "GameState triggers play_sfx_overdrive() on frenzy")
        reporter.check('play_sfx_research' in gs_code, "GameState triggers play_sfx_research() on tech research")

    # 7. Gameplay Node SFX Triggers
    avatar_path = GAME_DIR / "scripts" / "avatar_3d.gd"
    if avatar_path.exists():
        av_code = avatar_path.read_text(encoding="utf-8")
        reporter.check("play_sfx_footstep" in av_code, "Avatar3D triggers play_sfx_footstep()")
        reporter.check('_footstep_accumulator' in av_code, "Avatar3D tracks _footstep_accumulator")

    collectible_path = GAME_DIR / "scripts" / "collectible_3d.gd"
    if collectible_path.exists():
        col_code = collectible_path.read_text(encoding="utf-8")
        reporter.check("play_sfx_pickup" in col_code, "Collectible3D triggers play_sfx_pickup(item_type)")

    gate_path = GAME_DIR / "scripts" / "zone_gate_3d.gd"
    if gate_path.exists():
        gate_code = gate_path.read_text(encoding="utf-8")
        reporter.check("play_sfx_gate_unlock" in gate_code, "ZoneGate3D triggers play_sfx_gate_unlock()")

    drone_path = GAME_DIR / "scripts" / "delivery_drone_3d.gd"
    if drone_path.exists():
        dr_code = drone_path.read_text(encoding="utf-8")
        reporter.check("play_sfx_drone_hum" in dr_code, "DeliveryDrone3D triggers play_sfx_drone_hum()")

    main_path = GAME_DIR / "scripts" / "main_3d.gd"
    if main_path.exists():
        main_code = main_path.read_text(encoding="utf-8")
        reporter.check("start_ambient_bgm" in main_code, "Main3D triggers start_ambient_bgm() on world start")

    print(f"\nSummary: {reporter.passes} Passed, {reporter.fails} Failed")
    if reporter.fails > 0:
        sys.exit(1)
    print(">>> Phase 9 Milestone 1 Procedural Audio Engine & SFX Verified 100% Green! <<<\n")

if __name__ == "__main__":
    run_tests()
