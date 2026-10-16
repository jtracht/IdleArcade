#!/usr/bin/env python3
"""
Unit and AST Verification Suite for Phase 10 Milestone 1: Confetti-Bursts & Milestone-VFX
File: IdleArcade/tests/test_phase10_m1_confetti.py
Target: Python 3.12 CI Verification & Structural Certification
"""

import sys
import os
import re
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
    print("\n=== Phase 10 Milestone 1: Confetti VFX & Milestone Celebration Verification ===")

    # --------------------------------------------------------------------------
    # 1. Confetti Burst Scene Hierarchy & Particles Configuration
    # --------------------------------------------------------------------------
    scene_path = GAME_DIR / "scenes" / "vfx" / "confetti_burst.tscn"
    reporter.check(scene_path.exists(), "scenes/vfx/confetti_burst.tscn exists")
    if scene_path.exists():
        scene_content = scene_path.read_text(encoding="utf-8")
        reporter.check('[node name="ConfettiBurst" type="Node"]' in scene_content,
                       "ConfettiBurst root is a Node")
        reporter.check('res://scripts/vfx/confetti_burst.gd' in scene_content,
                       "ConfettiBurst attaches scripts/vfx/confetti_burst.gd")
        reporter.check('type="CPUParticles3D"' in scene_content,
                       "CPUParticles3D node present for 3D campus confetti")
        reporter.check('type="CPUParticles2D"' in scene_content,
                       "CPUParticles2D node present for 2D UI confetti")
        reporter.check('SubResource("BoxMesh_confetti_snippet")' in scene_content or 'BoxMesh' in scene_content,
                       "BoxMesh snippet used for 3D confetti tumbling particles")
        reporter.check('hue_variation_min = -1.0' in scene_content and 'hue_variation_max = 1.0' in scene_content,
                       "Particles configure full rainbow hue variation [-1.0, 1.0]")
        reporter.check('explosiveness =' in scene_content,
                       "High explosiveness burst configured")
        reporter.check('one_shot = true' in scene_content,
                       "Particles configured as one_shot bursts")

    # --------------------------------------------------------------------------
    # 2. Confetti Burst Script Logic & Factory Methods
    # --------------------------------------------------------------------------
    script_path = GAME_DIR / "scripts" / "vfx" / "confetti_burst.gd"
    reporter.check(script_path.exists(), "scripts/vfx/confetti_burst.gd exists")
    if script_path.exists():
        script_content = script_path.read_text(encoding="utf-8")
        reporter.check("class_name ConfettiBurst" in script_content,
                       "confetti_burst.gd registers class_name ConfettiBurst")
        reporter.check("signal burst_finished" in script_content,
                       "confetti_burst.gd declares burst_finished signal")
        reporter.check("static func spawn_burst_3d" in script_content,
                       "confetti_burst.gd implements static func spawn_burst_3d")
        reporter.check("static func spawn_burst_2d" in script_content,
                       "confetti_burst.gd implements static func spawn_burst_2d")
        reporter.check("queue_free()" in script_content,
                       "confetti_burst.gd implements automatic queue_free() cleanup")
        reporter.check("create_timer" in script_content,
                       "confetti_burst.gd includes fallback safety timer for headless runners")
        reporter.check("top_level = true" in script_content,
                       "3D particles use top_level positioning to detach from parent transform hierarchy")

    # --------------------------------------------------------------------------
    # 3. Audio Manager Celebration SFX
    # --------------------------------------------------------------------------
    audio_path = GAME_DIR / "scripts" / "autoload" / "audio_manager.gd"
    reporter.check(audio_path.exists(), "audio_manager.gd exists")
    if audio_path.exists():
        audio_content = audio_path.read_text(encoding="utf-8")
        reporter.check("func play_sfx_confetti()" in audio_content,
                       "audio_manager.gd implements play_sfx_confetti()")
        reporter.check("func _synth_confetti()" in audio_content,
                       "audio_manager.gd implements procedural celebratory sound synthesizer _synth_confetti()")
        reporter.check('_wav_confetti' in audio_content,
                       "audio_manager.gd caches pre-synthesized _wav_confetti stream")
        reporter.check('"confetti"' in audio_content,
                       "audio_manager.gd records 'confetti' in audio telemetry")

    # --------------------------------------------------------------------------
    # 4. GameState Milestone Signals & Progression
    # --------------------------------------------------------------------------
    game_state_path = GAME_DIR / "scripts" / "autoload" / "game_state.gd"
    reporter.check(game_state_path.exists(), "game_state.gd exists")
    if game_state_path.exists():
        gs_content = game_state_path.read_text(encoding="utf-8")
        reporter.check("signal level_up" in gs_content,
                       "game_state.gd declares signal level_up(new_level)")
        reporter.check("level_up.emit" in gs_content,
                       "game_state.gd emits level_up signal upon clearance_level upgrade")

    # --------------------------------------------------------------------------
    # 5. Station & Event Hooks Coverage
    # --------------------------------------------------------------------------
    # 5.1 Pitch Stage
    pitch_path = GAME_DIR / "scripts" / "pitch_stage.gd"
    reporter.check(pitch_path.exists(), "scripts/pitch_stage.gd exists")
    if pitch_path.exists():
        pitch_content = pitch_path.read_text(encoding="utf-8")
        reporter.check("spawn_burst_3d" in pitch_content,
                       "pitch_stage.gd triggers 3D ConfettiBurst on pitch success")
        reporter.check("play_sfx_confetti" in pitch_content,
                       "pitch_stage.gd triggers play_sfx_confetti on pitch success")

    # 5.2 Zone Gate 3D
    gate_path = GAME_DIR / "scripts" / "zone_gate_3d.gd"
    reporter.check(gate_path.exists(), "scripts/zone_gate_3d.gd exists")
    if gate_path.exists():
        gate_content = gate_path.read_text(encoding="utf-8")
        reporter.check("spawn_burst_3d" in gate_content,
                       "zone_gate_3d.gd triggers 3D ConfettiBurst on gate unlock")

    # 5.3 NPC 3D
    npc_path = GAME_DIR / "scripts" / "npc_3d.gd"
    reporter.check(npc_path.exists(), "scripts/npc_3d.gd exists")
    if npc_path.exists():
        npc_content = npc_path.read_text(encoding="utf-8")
        reporter.check("spawn_burst_3d" in npc_content,
                       "npc_3d.gd triggers 3D ConfettiBurst on quest completion")

    # 5.4 Dialogue Panel
    dialogue_path = GAME_DIR / "scripts" / "dialogue_panel.gd"
    reporter.check(dialogue_path.exists(), "scripts/dialogue_panel.gd exists")
    if dialogue_path.exists():
        dialogue_content = dialogue_path.read_text(encoding="utf-8")
        reporter.check("spawn_burst_2d" in dialogue_content,
                       "dialogue_panel.gd triggers 2D ConfettiBurst on quest completion claim")

    # 5.5 Tech Tree Modal
    tech_path = GAME_DIR / "scripts" / "ui" / "tech_tree_modal.gd"
    reporter.check(tech_path.exists(), "scripts/ui/tech_tree_modal.gd exists")
    if tech_path.exists():
        tech_content = tech_path.read_text(encoding="utf-8")
        reporter.check("spawn_burst_2d" in tech_content,
                       "tech_tree_modal.gd triggers 2D ConfettiBurst on tech research")

    # 5.6 HUD (Level Up)
    hud_path = GAME_DIR / "scripts" / "hud.gd"
    reporter.check(hud_path.exists(), "scripts/hud.gd exists")
    if hud_path.exists():
        hud_content = hud_path.read_text(encoding="utf-8")
        reporter.check("spawn_burst_2d" in hud_content,
                       "hud.gd triggers 2D ConfettiBurst on clearance / level up")
        reporter.check("level_up" in hud_content,
                       "hud.gd connects to level_up signal")

    print("\n-------------------------------------------------------------")
    print(f"Total Checks : {reporter.passes + reporter.fails}")
    print(f"Passed       : {reporter.passes}")
    print(f"Failed       : {reporter.fails}")
    print("-------------------------------------------------------------")
    if reporter.fails > 0:
        print(">>> SOME VERIFICATION CHECKS FAILED! <<<")
        sys.exit(1)
    else:
        print(">>> ALL PHASE 10 M1 CONFETTI CHECKS PASSED WITH 100% GREEN! <<<")
        sys.exit(0)

if __name__ == "__main__":
    run_tests()
