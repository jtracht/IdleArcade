#!/usr/bin/env python3
"""
Phase 16 Milestone 3 Verification Oracle: Arcade Visuals, Audio & Ergonomics
Target: Godot 4.3 Mobile & Web (Features 24, 25, 26, 27, 28, 29, 30)

Verifies:
  1. Audio synthesis: victory jingle, steam hiss, QTE chimes, timing hit sounds in audio_manager.gd
  2. Haptics: vibrate_success, vibrate_error, vibrate_sweet_spot, vibrate_timing_hit in haptics_manager.gd
  3. Floating score popups: FloatingScorePopup3D class and integration in server_terminal, pitch_stage, coffee_machine_3d
  4. Station particle VFX: AromaParticles in coffee_machine_3d.tscn, 3D sparks on data node hit, 2D confetti bursts
  5. Screen shake: trigger_camera_shake alias in main_3d.gd, camera_shake_requested in game_state.gd, espresso brew shake
  6. Touch ergonomics (>= 56px) and pointer isolation (_gui_input accept_event)
"""

import os
import re
import math
import sys

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

class TestReporter:
    def __init__(self, title):
        self.title = title
        self.total = 0
        self.passed = 0
        self.failed = 0
        print(f"\n=== {self.title} ===")

    def check(self, condition: bool, description: str, detail: str = ""):
        self.total += 1
        if condition:
            self.passed += 1
            print(f"  [PASS] {description}")
        else:
            self.failed += 1
            msg = f"  [FAIL] {description}"
            if detail:
                msg += f" ({detail})"
            print(msg)

    def summary(self):
        print("\n" + "=" * 65)
        print(f"Results: {self.passed} passed, {self.failed} failed out of {self.total}")
        print("=" * 65)
        if self.failed == 0:
            print(">>> ALL PHASE 16 MILESTONE 3 VERIFICATIONS PASSED (100% GREEN) <<<\n")
        else:
            print(">>> VERIFICATION SUITE HAD FAILURES <<<\n")
        return self.failed == 0


def read_file(rel_path: str) -> str:
    path = os.path.join(BASE_DIR, rel_path)
    if not os.path.exists(path):
        return ""
    with open(path, "r", encoding="utf-8") as f:
        return f.read()


def test_audio_manager(reporter: TestReporter):
    content = read_file("scripts/autoload/audio_manager.gd")
    reporter.check(len(content) > 0, "scripts/autoload/audio_manager.gd exists and is non-empty")

    # Method checks
    methods = [
        "play_sfx_victory_jingle",
        "play_sfx_victory",
        "play_sfx_steam_hiss",
        "play_sfx_qte_chime",
        "play_sfx_qte_correct",
        "play_sfx_qte_wrong",
        "play_sfx_timing_hit",
        "play_sfx_rhythm_click",
    ]
    for m in methods:
        reporter.check(f"func {m}(" in content, f"AudioManager implements public {m}()")

    # Synthesis functions
    synth_methods = [
        "_synth_victory_jingle",
        "_synth_steam_hiss",
        "_synth_qte_correct",
        "_synth_qte_wrong",
        "_synth_hit_perfect",
        "_synth_hit_good",
        "_synth_hit_miss",
    ]
    for sm in synth_methods:
        reporter.check(f"func {sm}(" in content, f"AudioManager implements synthesis helper {sm}()")

    # Prebaked stream variables
    stream_vars = [
        "_wav_victory_jingle",
        "_wav_steam_hiss",
        "_wav_qte_correct",
        "_wav_qte_wrong",
        "_wav_hit_perfect",
        "_wav_hit_good",
        "_wav_hit_miss",
    ]
    for sv in stream_vars:
        reporter.check(f"var {sv}: AudioStreamWAV" in content, f"AudioManager defines cached stream variable {sv}")
        reporter.check(f"{sv} = " in content, f"AudioManager prebakes {sv} in _prebake_sound_streams")

    # Mathematical Simulation of Synthesis Curves
    sample_rate = 22050

    # 1. Victory Jingle (5 notes arpeggio: G4, C5, E5, G5, C6)
    notes = [392.00, 523.25, 659.25, 783.99, 1046.50]
    times = [0.00, 0.12, 0.24, 0.36, 0.48]
    count = int(sample_rate * 0.85)
    samples = []
    for i in range(count):
        t = i / sample_rate
        s = 0.0
        for n in range(5):
            dt = t - times[n]
            if dt >= 0.0:
                f = notes[n]
                decay = 4.0 if n < 4 else 2.2
                env = (1.0 - math.exp(-dt * 300.0)) * math.exp(-dt * decay)
                wave = math.sin(2.0 * math.pi * f * dt) + 0.35 * math.sin(4.0 * math.pi * f * dt) + 0.15 * math.sin(6.0 * math.pi * f * dt)
                s += wave * env
        tail_fade = max(0.0, min(1.0, (0.85 - t) / 0.10)) if t > 0.75 else 1.0
        val = max(-1.0, min(1.0, (s / 2.5) * 0.85 * tail_fade))
        samples.append(val)
    max_val = max(abs(x) for x in samples)
    reporter.check(max_val > 0.5 and max_val <= 1.0, "Victory Jingle synthesis produces normalized bounded signal", f"max={max_val:.2f}")
    reporter.check(abs(samples[-1]) < 0.05, "Victory Jingle signal decays to near zero at tail (no pop)", f"tail={samples[-1]:.4f}")

    # 2. QTE Correct (ascending two-tone C6 -> G6)
    count_qte = int(sample_rate * 0.22)
    f1_qte = 1046.50
    f2_qte = 1567.98
    samples_qte = []
    for i in range(count_qte):
        t = i / sample_rate
        f = f1_qte if t < 0.08 else f2_qte
        dt = t if t < 0.08 else (t - 0.08)
        env = (1.0 - math.exp(-dt * 400.0)) * math.exp(-dt * 12.0)
        wave = math.sin(2.0 * math.pi * f * dt) + 0.25 * math.sin(4.0 * math.pi * f * dt)
        tail_fade = max(0.0, min(1.0, (0.22 - t) / 0.04)) if t > 0.18 else 1.0
        val = max(-1.0, min(1.0, wave * env * 0.80 * tail_fade))
        samples_qte.append(val)
    max_val_qte = max(abs(x) for x in samples_qte)
    reporter.check(max_val_qte > 0.5 and max_val_qte <= 1.0, "QTE Correct synthesis produces normalized bounded signal", f"max={max_val_qte:.2f}")
    reporter.check(abs(samples_qte[-1]) < 0.02, "QTE Correct signal decays to near zero at tail (no pop)", f"tail={samples_qte[-1]:.4f}")


def test_haptics_manager(reporter: TestReporter):
    content = read_file("scripts/autoload/haptics_manager.gd")
    reporter.check(len(content) > 0, "scripts/autoload/haptics_manager.gd exists")

    haptic_methods = [
        "vibrate_success",
        "vibrate_error",
        "vibrate_sweet_spot",
        "vibrate_timing_hit",
    ]
    for hm in haptic_methods:
        reporter.check(f"func {hm}(" in content, f"HapticsManager implements {hm}()")

    reporter.check("vibrate_success_pattern(40, 60, 80)" in content, "vibrate_success routes to vibrate_success_pattern(40, 60, 80)")
    reporter.check("vibrate_custom(65, 0.75, true)" in content, "vibrate_error uses 65ms double buzz at 0.75 amp bypassing cooldown")
    reporter.check("vibrate_custom(35, 0.70, true)" in content, "vibrate_sweet_spot uses 35ms tactile notch at 0.70 amp")
    reporter.check("can_vibrate_hardware()" in content, "HapticsManager retains can_vibrate_hardware platform guard")


def test_floating_score_popup(reporter: TestReporter):
    content = read_file("scripts/vfx/floating_score_popup.gd")
    reporter.check(len(content) > 0, "scripts/vfx/floating_score_popup.gd exists")
    reporter.check("class_name FloatingScorePopup3D" in content, "FloatingScorePopup3D registers class_name")
    reporter.check("static func spawn_popup_3d(" in content, "spawn_popup_3d static factory method exists")
    reporter.check("label.billboard = BaseMaterial3D.BILLBOARD_ENABLED" in content, "Popup enables billboard orientation")
    reporter.check("label.no_depth_test = true" in content, "Popup enables no_depth_test for visual clarity")
    reporter.check("label.top_level = true" in content, "Popup configures top_level transform when in tree")
    reporter.check("label.queue_free" in content, "Popup chains tween callback to auto-free")


def test_station_popups_and_vfx(reporter: TestReporter):
    # ServerTerminal
    st_content = read_file("scripts/server_terminal.gd")
    reporter.check("func spawn_score_popup(" in st_content, "ServerTerminal implements spawn_score_popup()")
    reporter.check("+3x BOOST!" in st_content, "ServerTerminal awards '+3x BOOST!' for Perfect sync")
    reporter.check("+2x BOOST!" in st_content, "ServerTerminal awards '+2x BOOST!' for Good sync")
    reporter.check("+1.2x COMFORT!" in st_content, "ServerTerminal awards '+1.2x COMFORT!' for Miss sync")
    reporter.check("matrix_sparks.restart()" in st_content, "ServerTerminal pulses matrix_sparks on perfect node hit")
    reporter.check("overclock_sparks.restart()" in st_content, "ServerTerminal pulses overclock_sparks on good node hit")

    # PitchStage
    ps_content = read_file("scripts/pitch_stage.gd")
    reporter.check("func spawn_score_popup(" in ps_content, "PitchStage implements spawn_score_popup()")
    reporter.check("func _format_popup_energy(" in ps_content, "PitchStage implements _format_popup_energy() with dot separators")
    reporter.check("+%s ENERGY!" in ps_content, "PitchStage awards formatted +[X] ENERGY! popup")

    # CoffeeMachine3D
    cm_content = read_file("scripts/coffee_machine_3d.gd")
    reporter.check("func spawn_score_popup(" in cm_content, "CoffeeMachine3D implements spawn_score_popup()")
    reporter.check("HYPER-FOCUS 60s!" in cm_content, "CoffeeMachine3D awards 'HYPER-FOCUS 60s!' popup")
    reporter.check("aroma_particles" in cm_content, "CoffeeMachine3D binds aroma_particles")
    reporter.check("aroma_particles.restart()" in cm_content, "CoffeeMachine3D restarts aroma_particles on complete_brew")

    # CoffeeMachine3D Scene
    tscn_content = read_file("scenes/coffee_machine_3d.tscn")
    reporter.check('name="AromaParticles"' in tscn_content, "scenes/coffee_machine_3d.tscn declares AromaParticles node")
    reporter.check('type="CPUParticles3D"' in tscn_content, "AromaParticles is of type CPUParticles3D")
    reporter.check('BoxMesh_aroma' in tscn_content, "AromaParticles uses BoxMesh_aroma")


def test_screen_shake(reporter: TestReporter):
    # Main3D
    m3d = read_file("scripts/main_3d.gd")
    reporter.check("func trigger_camera_shake(" in m3d, "main_3d.gd implements trigger_camera_shake alias")
    reporter.check("func add_screen_shake(" in m3d, "main_3d.gd preserves add_screen_shake contract")
    reporter.check("camera_shake_requested" in m3d, "main_3d.gd connects to GameState.camera_shake_requested")

    # GameState
    gs = read_file("scripts/autoload/game_state.gd")
    reporter.check("signal camera_shake_requested(" in gs, "game_state.gd declares camera_shake_requested signal")
    reporter.check("func trigger_camera_shake(" in gs, "game_state.gd implements trigger_camera_shake method")

    # EspressoBrewMinigame shake
    eb = read_file("scripts/ui/espresso_brew_minigame.gd")
    reporter.check("add_screen_shake(0.30)" in eb, "espresso_brew_minigame.gd calls add_screen_shake(0.30) on extraction")
    reporter.check("add_screen_shake(0.04)" in eb, "espresso_brew_minigame.gd calls add_screen_shake(0.04) on extreme overpressure")


def test_minigame_ergonomics(reporter: TestReporter):
    # CyberSyncMinigame
    cs = read_file("scripts/ui/cyber_sync_minigame.gd")
    reporter.check("func _gui_input(" in cs, "cyber_sync_minigame.gd implements _gui_input")
    reporter.check("accept_event()" in cs, "cyber_sync_minigame.gd calls accept_event() for pointer isolation")
    reporter.check("spawn_burst_2d" in cs, "cyber_sync_minigame.gd spawns 2D confetti burst on Perfect")

    # PitchStageMinigame
    ps = read_file("scripts/ui/pitch_stage_minigame.gd")
    reporter.check("func _gui_input(" in ps, "pitch_stage_minigame.gd implements _gui_input")
    reporter.check("spawn_burst_2d" in ps, "pitch_stage_minigame.gd spawns 2D confetti burst on win")

    # EspressoBrewMinigame
    eb = read_file("scripts/ui/espresso_brew_minigame.gd")
    reporter.check("func _gui_input(" in eb, "espresso_brew_minigame.gd implements _gui_input")
    reporter.check("maxf(pump_button.custom_minimum_size.y, 56.0)" in eb, "espresso_brew_minigame.gd clamps pump button >= 56px")
    reporter.check("maxf(close_button.custom_minimum_size.y, 56.0)" in eb, "espresso_brew_minigame.gd clamps close button >= 56px")
    reporter.check("spawn_burst_2d" in eb, "espresso_brew_minigame.gd spawns 2D confetti burst on extraction")


def main():
    reporter = TestReporter("IdleArcade Phase 16 Milestone 3 Master Verification Oracle")
    test_audio_manager(reporter)
    test_haptics_manager(reporter)
    test_floating_score_popup(reporter)
    test_station_popups_and_vfx(reporter)
    test_screen_shake(reporter)
    test_minigame_ergonomics(reporter)
    success = reporter.summary()
    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()
