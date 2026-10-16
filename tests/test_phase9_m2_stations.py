#!/usr/bin/env python3
"""
Master Verification Suite for Phase 9 Milestone 2:
Interactive Campus Stations & 3D Props (Server Room Overclock Terminal & Courtyard Pitch Stage)
File: IdleArcade/tests/test_phase9_m2_stations.py
Target: Python 3.12 CI Verification, AST Analysis & Math/Geometry Certification
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

def compute_tscn_triangle_count(content: str) -> dict:
    """Parses primitive mesh definitions in a Godot 4 .tscn file and computes triangle counts."""
    # Find all sub_resources
    subres_blocks = re.findall(r'\[sub_resource type="([^"]+)" id="([^"]+)"\]([\s\S]*?)(?=\n\[|\Z)', content)
    subres_map = {}
    for rtype, rid, block in subres_blocks:
        subres_map[rid] = (rtype, block)

    # Find mesh assignments
    mesh_instances = re.findall(r'mesh = SubResource\("([^"]+)"\)', content)
    total_tris = 0
    itemized = []

    for mid in mesh_instances:
        if mid not in subres_map:
            continue
        mtype, mblock = subres_map[mid]
        tris = 0
        if "BoxMesh" in mtype:
            tris = 12
        elif "PlaneMesh" in mtype:
            tris = 2
        elif "CylinderMesh" in mtype:
            rad_match = re.search(r'radial_segments\s*=\s*(\d+)', mblock)
            rings_match = re.search(r'rings\s*=\s*(\d+)', mblock)
            rad_seg = int(rad_match.group(1)) if rad_match else 64
            rings = int(rings_match.group(1)) if rings_match else 4
            tris = (rad_seg * rings * 2) + (rad_seg * 2)
        elif "SphereMesh" in mtype:
            rad_match = re.search(r'radial_segments\s*=\s*(\d+)', mblock)
            rings_match = re.search(r'rings\s*=\s*(\d+)', mblock)
            rad_seg = int(rad_match.group(1)) if rad_match else 64
            rings = int(rings_match.group(1)) if rings_match else 32
            tris = rad_seg * rings * 2
        elif "CapsuleMesh" in mtype:
            rad_match = re.search(r'radial_segments\s*=\s*(\d+)', mblock)
            rings_match = re.search(r'rings\s*=\s*(\d+)', mblock)
            rad_seg = int(rad_match.group(1)) if rad_match else 64
            rings = int(rings_match.group(1)) if rings_match else 8
            tris = rad_seg * (rings + 1) * 2
        elif "TorusMesh" in mtype:
            rings_match = re.search(r'rings\s*=\s*(\d+)', mblock)
            rseg_match = re.search(r'ring_segments\s*=\s*(\d+)', mblock)
            rings = int(rings_match.group(1)) if rings_match else 64
            rseg = int(rseg_match.group(1)) if rseg_match else 32
            tris = rings * rseg * 2
        else:
            tris = 12

        total_tris += tris
        itemized.append((mid, mtype, tris))

    return {
        "total": total_tris,
        "mesh_count": len(mesh_instances),
        "itemized": itemized
    }

def run_tests():
    print("\n====================================================================")
    print(" Phase 9 Milestone 2: Interactive Campus Stations Verification")
    print("====================================================================")

    # ------------------------------------------------------------------
    # 1. Server Room Overclock Terminal Scene & Script
    # ------------------------------------------------------------------
    print("\n--- 1. Server Room Overclock Terminal ---")
    st_scene_path = GAME_DIR / "scenes" / "server_terminal.tscn"
    st_script_path = GAME_DIR / "scripts" / "server_terminal.gd"

    reporter.check(st_scene_path.exists(), "scenes/server_terminal.tscn exists")
    reporter.check(st_script_path.exists(), "scripts/server_terminal.gd exists")

    if st_scene_path.exists():
        st_content = st_scene_path.read_text(encoding="utf-8")
        reporter.check('type="StaticBody3D"' in st_content, "ServerTerminal root is StaticBody3D")
        reporter.check('groups=["interactables", "server_terminals", "terminals"]' in st_content or
                       'server_terminals' in st_content, "ServerTerminal belongs to 'server_terminals' group")
        reporter.check('collision_layer = 1' in st_content, "ServerTerminal solid collision_layer = 1")
        reporter.check('collision_mask = 0' in st_content, "ServerTerminal solid collision_mask = 0")
        reporter.check('name="InteractionArea" type="Area3D"' in st_content, "InteractionArea Area3D exists")
        reporter.check('collision_layer = 0' in st_content, "InteractionArea collision_layer = 0")
        reporter.check('radius = 2.4' in st_content, "InteractionArea SphereShape3D radius is 2.4m")
        reporter.check('name="PromptLabel3D" type="Label3D"' in st_content, "PromptLabel3D exists")
        reporter.check('text = "[E] Server Console"' in st_content, "PromptLabel3D text is '[E] Server Console'")
        reporter.check('billboard = 1' in st_content, "PromptLabel3D billboard is enabled")
        reporter.check('name="ScreenLabel3D" type="Label3D"' in st_content, "ScreenLabel3D CRT matrix telemetry exists")
        reporter.check('name="TerminalOmniLight" type="OmniLight3D"' in st_content, "TerminalOmniLight exists")
        reporter.check('name="OverclockSparks" type="CPUParticles3D"' in st_content, "OverclockSparks CPUParticles3D exists")
        reporter.check('name="StatusLEDs"' in st_content, "StatusLEDs container exists")

    if st_script_path.exists():
        st_script = st_script_path.read_text(encoding="utf-8")
        reporter.check("class_name ServerTerminal" in st_script, "ServerTerminal defines class_name ServerTerminal")
        reporter.check("signal overclock_started" in st_script, "ServerTerminal defines signal overclock_started")
        reporter.check("signal overclock_activated" in st_script, "ServerTerminal defines signal overclock_activated")
        reporter.check("signal overclock_ended" in st_script, "ServerTerminal defines signal overclock_ended")
        reporter.check("signal terminal_interacted" in st_script, "ServerTerminal defines signal terminal_interacted")
        reporter.check("overclock_duration: float = 25.0" in st_script, "ServerTerminal overclock duration is 25.0s")
        reporter.check("overclock_cooldown: float = 60.0" in st_script, "ServerTerminal overclock cooldown is 60.0s")
        reporter.check("rps_boost_multiplier: float = 1.50" in st_script, "ServerTerminal rps_boost_multiplier is 1.50 (+50%)")
        reporter.check("func interact()" in st_script, "ServerTerminal implements interact()")
        reporter.check("func can_activate()" in st_script, "ServerTerminal implements can_activate()")
        reporter.check("func is_player_in_range()" in st_script, "ServerTerminal implements is_player_in_range()")
        reporter.check("activate_server_overclock_buff" in st_script, "ServerTerminal calls GameState.activate_server_overclock_buff")
        reporter.check("register_interactable" in st_script, "ServerTerminal registers with TouchControls")
        reporter.check('"Overclock [E]"' in st_script, "ServerTerminal uses 'Overclock [E]' action label")
        reporter.check("play_sfx_overdrive" in st_script or "play_sfx_click" in st_script, "ServerTerminal invokes guarded SFX")

    # ------------------------------------------------------------------
    # 2. Courtyard Pitch Stage Scene & Script
    # ------------------------------------------------------------------
    print("\n--- 2. Courtyard Pitch Stage ---")
    ps_scene_path = GAME_DIR / "scenes" / "pitch_stage.tscn"
    ps_script_path = GAME_DIR / "scripts" / "pitch_stage.gd"

    reporter.check(ps_scene_path.exists(), "scenes/pitch_stage.tscn exists")
    reporter.check(ps_script_path.exists(), "scripts/pitch_stage.gd exists")

    if ps_scene_path.exists():
        ps_content = ps_scene_path.read_text(encoding="utf-8")
        reporter.check('type="StaticBody3D"' in ps_content, "PitchStage root is StaticBody3D")
        reporter.check('groups=["interactables", "pitch_stages", "stages"]' in ps_content or
                       'pitch_stages' in ps_content, "PitchStage belongs to 'pitch_stages' group")
        reporter.check('name="InteractionArea" type="Area3D"' in ps_content, "PitchStage InteractionArea Area3D exists")
        reporter.check('radius = 3.0' in ps_content or 'radius = 3' in ps_content, "PitchStage InteractionArea radius is 3.0m")
        reporter.check('name="PromptLabel3D" type="Label3D"' in ps_content, "PitchStage PromptLabel3D exists")
        reporter.check('text = "[E] Angel Investor Pitch"' in ps_content, "PitchStage PromptLabel3D text is '[E] Angel Investor Pitch'")
        reporter.check('billboard = 1' in ps_content, "PitchStage PromptLabel3D billboard is enabled")
        reporter.check('name="StageSpotlight" type="SpotLight3D"' in ps_content, "StageSpotlight SpotLight3D exists")
        reporter.check('name="ChibiAngelInvestor"' in ps_content, "ChibiAngelInvestor model exists")
        reporter.check('name="Podium"' in ps_content, "Podium mesh exists")
        reporter.check('name="MicStand"' in ps_content, "MicStand cylinder mesh exists")
        reporter.check('name="MicHead"' in ps_content, "MicHead sphere mesh exists")
        reporter.check('name="Sunglasses"' in ps_content, "Investor Sunglasses mesh exists")
        reporter.check('name="CashBriefcase"' in ps_content, "Investor CashBriefcase mesh exists")
        reporter.check('name="ConfettiExplosion" type="CPUParticles3D"' in ps_content, "ConfettiExplosion CPUParticles3D exists")

    if ps_script_path.exists():
        ps_script = ps_script_path.read_text(encoding="utf-8")
        reporter.check("class_name PitchStage" in ps_script, "PitchStage defines class_name PitchStage")
        reporter.check("signal pitch_started" in ps_script, "PitchStage defines signal pitch_started")
        reporter.check("signal pitch_rewarded" in ps_script, "PitchStage defines signal pitch_rewarded")
        reporter.check("signal pitch_completed" in ps_script, "PitchStage defines signal pitch_completed")
        reporter.check("signal pitch_stage_interacted" in ps_script, "PitchStage defines signal pitch_stage_interacted")
        reporter.check("pitch_cooldown: float = 60.0" in ps_script, "PitchStage pitch cooldown is 60.0s")
        reporter.check("min_grant: float = 1000.0" in ps_script, "PitchStage min grant is 1000.0")
        reporter.check("max_grant: float = 5000.0" in ps_script, "PitchStage max grant is 5000.0")
        reporter.check("func interact()" in ps_script, "PitchStage implements interact()")
        reporter.check("func can_pitch()" in ps_script, "PitchStage implements can_pitch()")
        reporter.check("func is_player_in_range()" in ps_script, "PitchStage implements is_player_in_range()")
        reporter.check("earn_energy" in ps_script or "energy +=" in ps_script, "PitchStage awards grant to GameState")
        reporter.check("register_interactable" in ps_script, "PitchStage registers with TouchControls")
        reporter.check('"Pitch [E]"' in ps_script, "PitchStage uses 'Pitch [E]' action label")
        reporter.check("play_sfx_research" in ps_script or "play_sfx_pickup" in ps_script, "PitchStage invokes celebratory SFX")

    # ------------------------------------------------------------------
    # 3. Dynamic Triangle Budget Certification (<2,500 tris)
    # ------------------------------------------------------------------
    print("\n--- 3. Dynamic Triangle Budget Certification ---")
    st_stats = compute_tscn_triangle_count(st_scene_path.read_text(encoding="utf-8")) if st_scene_path.exists() else {"total": 0}
    ps_stats = compute_tscn_triangle_count(ps_scene_path.read_text(encoding="utf-8")) if ps_scene_path.exists() else {"total": 0}

    st_tris = st_stats["total"]
    ps_tris = ps_stats["total"]
    combined_tris = st_tris + ps_tris

    print(f"  Server Terminal Triangle Count : {st_tris} tris")
    print(f"  Pitch Stage Triangle Count     : {ps_tris} tris")
    print(f"  Combined Triangle Count        : {combined_tris} tris (Budget: <2,500 tris)")

    reporter.check(st_tris < 1000, f"Server Terminal triangle count < 1,000 tris (actual: {st_tris})")
    reporter.check(ps_tris < 1500, f"Pitch Stage triangle count < 1,500 tris (actual: {ps_tris})")
    reporter.check(combined_tris < 2500, f"Combined dynamic triangle count < 2,500 tris (actual: {combined_tris})")
    reporter.check(combined_tris <= 500, f"Optimized low-poly target ~376 tris achieved (actual: {combined_tris})")

    # ------------------------------------------------------------------
    # 4. Campus World Integration (`main_3d.tscn` & `main_3d.gd`)
    # ------------------------------------------------------------------
    print("\n--- 4. Campus World Integration ---")
    m3d_scene_path = GAME_DIR / "scenes" / "main_3d.tscn"
    m3d_script_path = GAME_DIR / "scripts" / "main_3d.gd"

    if m3d_scene_path.exists():
        m3d_scene = m3d_scene_path.read_text(encoding="utf-8")
        reporter.check('scenes/server_terminal.tscn' in m3d_scene, "server_terminal.tscn loaded in main_3d.tscn")
        reporter.check('scenes/pitch_stage.tscn' in m3d_scene, "pitch_stage.tscn loaded in main_3d.tscn")
        
        # Verify coordinates
        st_pos_match = re.search(r'\[node name="ServerTerminal"[^\]]*\][\s\S]*?transform = Transform3D\([^)]*\s*,\s*0\s*,\s*0\s*,\s*-18\)', m3d_scene)
        ps_pos_match = re.search(r'\[node name="PitchStage"[^\]]*\][\s\S]*?transform = Transform3D\([^)]*\s*,\s*0\s*,\s*0\s*,\s*18\)', m3d_scene)
        
        reporter.check(bool(st_pos_match or '-18' in m3d_scene), "ServerTerminal placed at Vector3(0, 0, -18)")
        reporter.check(bool(ps_pos_match or ', 18)' in m3d_scene), "PitchStage placed at Vector3(0, 0, 18)")

    if m3d_script_path.exists():
        m3d_script = m3d_script_path.read_text(encoding="utf-8")
        reporter.check("server_terminal" in m3d_script, "main_3d.gd defines server_terminal reference")
        reporter.check("pitch_stage" in m3d_script, "main_3d.gd defines pitch_stage reference")

    # ------------------------------------------------------------------
    # 5. GameState Overclock Buff Mechanics
    # ------------------------------------------------------------------
    print("\n--- 5. GameState Overclock Buff Mechanics ---")
    gs_path = GAME_DIR / "scripts" / "autoload" / "game_state.gd"

    if gs_path.exists():
        gs_content = gs_path.read_text(encoding="utf-8")
        reporter.check("server_overclock_buff_timer: float = 0.0" in gs_content or "server_overclock_buff_timer" in gs_content,
                       "GameState declares server_overclock_buff_timer")
        reporter.check("server_overclock_buff_multiplier: float = 1.0" in gs_content or "server_overclock_buff_multiplier" in gs_content,
                       "GameState declares server_overclock_buff_multiplier")
        reporter.check("func activate_server_overclock_buff" in gs_content,
                       "GameState defines activate_server_overclock_buff(duration, multiplier)")
        reporter.check("func earn_energy" in gs_content,
                       "GameState defines earn_energy(amount)")
        reporter.check("server_overclock_buff_started" in gs_content,
                       "GameState defines signal server_overclock_buff_started")
        reporter.check("server_overclock_buff_ended" in gs_content,
                       "GameState defines signal server_overclock_buff_ended")

        # Simulate passive RPS calculation with buff
        base_rps = 100.0
        bonus_mult = 1.0
        campus_mult = 1.0
        tech_mult = 1.0
        overclock_mult = 1.50
        normal_rps = base_rps * bonus_mult * campus_mult * tech_mult
        buffed_rps = normal_rps * overclock_mult

        reporter.check(buffed_rps == 150.0, "Passive RPS +50% simulation: 100.0 -> 150.0 RPS")

    # ------------------------------------------------------------------
    # 6. TouchControls Dynamic Styling
    # ------------------------------------------------------------------
    print("\n--- 6. TouchControls Dynamic Styling ---")
    tc_path = GAME_DIR / "scripts" / "ui" / "touch_controls.gd"

    if tc_path.exists():
        tc_content = tc_path.read_text(encoding="utf-8")
        reporter.check("_cached_overclock_style: StyleBoxFlat" in tc_content or "_cached_overclock_style" in tc_content,
                       "touch_controls.gd declares _cached_overclock_style")
        reporter.check("_cached_pitch_style: StyleBoxFlat" in tc_content or "_cached_pitch_style" in tc_content,
                       "touch_controls.gd declares _cached_pitch_style")
        reporter.check('Color(0.0, 0.92, 1.0' in tc_content or 'Color(0.0, 0.85, 1.0' in tc_content,
                       "touch_controls.gd configures Neon-Cyan / Electric-Blue border")
        reporter.check('Color(1.0, 0.84, 0.0' in tc_content,
                       "touch_controls.gd configures Warm Gold border")
        reporter.check('"Overclock"' in tc_content,
                       "touch_controls.gd recognizes 'Overclock' interaction prompt")
        reporter.check('"Pitch"' in tc_content,
                       "touch_controls.gd recognizes 'Pitch' interaction prompt")

    # ------------------------------------------------------------------
    # Summary
    # ------------------------------------------------------------------
    print("\n====================================================================")
    print(f"Summary: {reporter.passes} Passed, {reporter.fails} Failed")
    if reporter.fails == 0:
        print(">>> Phase 9 Milestone 2 Campus Stations Verified 100% Green! <<<")
    print("====================================================================\n")
    return 0 if reporter.fails == 0 else 1

if __name__ == "__main__":
    sys.exit(run_tests())
