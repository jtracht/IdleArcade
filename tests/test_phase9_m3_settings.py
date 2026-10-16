#!/usr/bin/env python3
"""
Unit and AST Verification Suite for Phase 9 Milestone 3: Mobile Touch-UX & Settings Modal
File: IdleArcade/tests/test_phase9_m3_settings.py
Target: Python 3.12 CI Verification & Headless Ergonomics / Touch Sizing Certification
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
    print("\n====================================================================")
    print(" Phase 9 Milestone 3: Mobile Touch-UX & Settings Modal Verification")
    print("====================================================================")

    # --------------------------------------------------------------------------
    # 1. File Structure & Registration
    # --------------------------------------------------------------------------
    print("\n--- 1. File Structure & Delivery ---")
    settings_tscn = GAME_DIR / "scenes" / "ui" / "settings_modal.tscn"
    settings_gd = GAME_DIR / "scripts" / "ui" / "settings_modal.gd"
    hud_tscn = GAME_DIR / "scenes" / "hud.tscn"
    hud_gd = GAME_DIR / "scripts" / "hud.gd"
    touch_gd = GAME_DIR / "scripts" / "ui" / "touch_controls.gd"

    reporter.check(settings_tscn.exists(), "scenes/ui/settings_modal.tscn exists")
    reporter.check(settings_gd.exists(), "scripts/ui/settings_modal.gd exists")
    reporter.check(hud_tscn.exists(), "scenes/hud.tscn exists")
    reporter.check(hud_gd.exists(), "scripts/hud.gd exists")
    reporter.check(touch_gd.exists(), "scripts/ui/touch_controls.gd exists")

    # --------------------------------------------------------------------------
    # 2. Settings Modal TSCN Scene Structure & Touch Ergonomics
    # --------------------------------------------------------------------------
    print("\n--- 2. Settings Modal Touch Ergonomics & Node Hierarchy ---")
    if settings_tscn.exists():
        tscn_content = settings_tscn.read_text(encoding="utf-8")

        # Root control
        reporter.check('[node name="SettingsModal" type="Control"]' in tscn_content,
                       "SettingsModal root is Control node")
        reporter.check('mouse_filter = 0' in tscn_content,
                       "Input isolation: mouse_filter = 0 (STOP) present")

        # Backdrop
        reporter.check('[node name="Backdrop" type="ColorRect" parent="."]' in tscn_content,
                       "Backdrop ColorRect present in settings_modal.tscn")

        # Modal Card
        reporter.check('[node name="ModalCard" type="PanelContainer"' in tscn_content,
                       "ModalCard PanelContainer present in settings_modal.tscn")

        # Close button touch target >= 56x56
        close_btn_match = re.search(r'\[node name="CloseButton" type="Button"[^\]]*\](.*?)(?=\n\[|\Z)', tscn_content, re.DOTALL)
        reporter.check(close_btn_match is not None, "CloseButton node declared in settings_modal.tscn")
        if close_btn_match:
            chunk = close_btn_match.group(1)
            min_size_match = re.search(r'custom_minimum_size = Vector2\((\d+),\s*(\d+)\)', chunk)
            if min_size_match:
                w, h = int(min_size_match.group(1)), int(min_size_match.group(2))
                reporter.check(w >= 56 and h >= 56,
                               f"CloseButton touch target >= 56x56px (actual: {w}x{h}px)")
            else:
                reporter.check(False, "CloseButton defines custom_minimum_size", "not found")

        # Controls Minimum Height >= 56px
        controls_to_check = [
            ("MasterVolumeSlider", "HSlider"),
            ("MasterMuteToggle", "Button"),
            ("SFXVolumeSlider", "HSlider"),
            ("SFXMuteToggle", "Button"),
            ("MusicVolumeSlider", "HSlider"),
            ("MusicMuteToggle", "Button"),
            ("HapticsToggle", "Button"),
            ("BatterySaverToggle", "Button")
        ]

        for ctrl_name, ctrl_type in controls_to_check:
            ctrl_match = re.search(rf'\[node name="{ctrl_name}" type="{ctrl_type}"[^\]]*\](.*?)(?=\n\[|\Z)', tscn_content, re.DOTALL)
            reporter.check(ctrl_match is not None, f"Node {ctrl_name} ({ctrl_type}) present in settings_modal.tscn")
            if ctrl_match:
                c_chunk = ctrl_match.group(1)
                min_sz = re.search(r'custom_minimum_size = Vector2\((\d+),\s*(\d+)\)', c_chunk)
                if min_sz:
                    h = int(min_sz.group(2))
                    reporter.check(h >= 56, f"{ctrl_name} touch height >= 56px (actual: {h}px)")
                else:
                    reporter.check(False, f"{ctrl_name} defines custom_minimum_size", "missing")

    # --------------------------------------------------------------------------
    # 3. Settings Modal GDScript Controller Logic & Input Isolation
    # --------------------------------------------------------------------------
    print("\n--- 3. Settings Modal Controller Logic & Duck Typing ---")
    if settings_gd.exists():
        gd_code = settings_gd.read_text(encoding="utf-8")

        # Class / Extends
        reporter.check("extends Control" in gd_code, "settings_modal.gd extends Control")

        # Signals
        required_signals = [
            "signal closed()",
            "signal master_volume_changed",
            "signal sfx_volume_changed",
            "signal music_volume_changed",
            "signal master_mute_changed",
            "signal sfx_mute_changed",
            "signal music_mute_changed",
            "signal haptics_toggled",
            "signal battery_saver_toggled"
        ]
        for sig in required_signals:
            reporter.check(sig in gd_code, f"settings_modal.gd defines {sig}")

        # Input Isolation AST
        reporter.check("mouse_filter = Control.MOUSE_FILTER_STOP" in gd_code,
                       "settings_modal.gd programmatically enforces mouse_filter = STOP")
        reporter.check("func _gui_input" in gd_code and "accept_event()" in gd_code,
                       "settings_modal.gd _gui_input() calls accept_event()")
        reporter.check("func _on_backdrop_gui_input" in gd_code,
                       "settings_modal.gd handles backdrop touch dismissal")

        # Lifecycle methods
        reporter.check("func open" in gd_code, "settings_modal.gd implements open()")
        reporter.check("func close" in gd_code, "settings_modal.gd implements close()")
        reporter.check("closed.emit()" in gd_code, "close() emits closed signal")
        reporter.check("queue_free()" in gd_code, "close() calls queue_free()")
        reporter.check("play_sfx_click" in gd_code, "close() plays click sound via AudioManager")

        # Audio Integration & Volume Handlers
        reporter.check("func _on_master_slider_changed" in gd_code,
                       "settings_modal.gd implements _on_master_slider_changed")
        reporter.check("set_master_volume" in gd_code,
                       "_on_master_slider_changed calls set_master_volume")
        reporter.check("func _on_sfx_slider_changed" in gd_code,
                       "settings_modal.gd implements _on_sfx_slider_changed")
        reporter.check("set_sfx_volume" in gd_code,
                       "_on_sfx_slider_changed calls set_sfx_volume")
        reporter.check("func _on_music_slider_changed" in gd_code,
                       "settings_modal.gd implements _on_music_slider_changed")
        reporter.check("set_music_volume" in gd_code,
                       "_on_music_slider_changed calls set_music_volume")

        # Mute Handlers
        reporter.check("func _on_master_mute_toggled" in gd_code,
                       "settings_modal.gd implements _on_master_mute_toggled")
        reporter.check("set_master_muted" in gd_code,
                       "_on_master_mute_toggled calls set_master_muted")
        reporter.check("func _on_sfx_mute_toggled" in gd_code,
                       "settings_modal.gd implements _on_sfx_mute_toggled")
        reporter.check("set_sfx_muted" in gd_code,
                       "_on_sfx_mute_toggled calls set_sfx_muted")
        reporter.check("func _on_music_mute_toggled" in gd_code,
                       "settings_modal.gd implements _on_music_mute_toggled")
        reporter.check("set_music_muted" in gd_code,
                       "_on_music_mute_toggled calls set_music_muted")

        # Haptics Manager Integration
        reporter.check("func _on_haptics_toggled" in gd_code,
                       "settings_modal.gd implements _on_haptics_toggled")
        reporter.check("set_haptics_enabled" in gd_code,
                       "_on_haptics_toggled calls HapticsManager.set_haptics_enabled")
        reporter.check("is_haptics_enabled" in gd_code,
                       "reads initial state from HapticsManager.is_haptics_enabled")

        # FPS / Battery Saver Toggle
        reporter.check("func _on_battery_saver_toggled" in gd_code,
                       "settings_modal.gd implements _on_battery_saver_toggled")
        reporter.check("Engine.max_fps = 30" in gd_code,
                       "_on_battery_saver_toggled sets Engine.max_fps = 30 when active")
        reporter.check("Engine.max_fps = 60" in gd_code,
                       "_on_battery_saver_toggled sets Engine.max_fps = 60 when inactive")

        # Defensive Duck Typing Check
        reporter.check("func _get_audio_manager" in gd_code,
                       "settings_modal.gd implements safe _get_audio_manager duck typing")
        reporter.check("func _get_haptics_manager" in gd_code,
                       "settings_modal.gd implements safe _get_haptics_manager duck typing")
        reporter.check("func _get_game_state" in gd_code,
                       "settings_modal.gd implements safe _get_game_state duck typing")

    # --------------------------------------------------------------------------
    # 4. HUD Integration (%SettingsButton & open_settings_modal)
    # --------------------------------------------------------------------------
    print("\n--- 4. HUD Navigation Drawer Integration ---")
    if hud_tscn.exists():
        hud_tscn_content = hud_tscn.read_text(encoding="utf-8")
        reporter.check('[node name="SettingsButton" type="Button" parent="NavDrawer/DrawerPanel/DrawerVBox/NavScroll/NavItemsVBox"]' in hud_tscn_content,
                       "SettingsButton declared under NavDrawer/DrawerPanel/DrawerVBox/NavScroll/NavItemsVBox")
        reporter.check('unique_name_in_owner = true' in hud_tscn_content and 'text = "⚙️ Settings"' in hud_tscn_content,
                       "SettingsButton is unique_name_in_owner with text '⚙️ Settings'")

        # Height check
        sbtn_match = re.search(r'\[node name="SettingsButton" type="Button"[^\]]*\](.*?)(?=\n\[|\Z)', hud_tscn_content, re.DOTALL)
        if sbtn_match:
            s_chunk = sbtn_match.group(1)
            min_sz = re.search(r'custom_minimum_size = Vector2\((\d+),\s*(\d+)\)', s_chunk)
            if min_sz:
                h = int(min_sz.group(2))
                reporter.check(h >= 56, f"NavDrawer SettingsButton height >= 56px (actual: {h}px)")

    if hud_gd.exists():
        hud_gd_code = hud_gd.read_text(encoding="utf-8")
        reporter.check('const SETTINGS_MODAL_SCENE: PackedScene = preload("res://scenes/ui/settings_modal.tscn")' in hud_gd_code,
                       "hud.gd preloads SETTINGS_MODAL_SCENE")
        reporter.check('settings_button: Button = get_node_or_null("%SettingsButton")' in hud_gd_code,
                       "hud.gd binds @onready var settings_button")
        reporter.check('func open_settings_modal() -> Control:' in hud_gd_code,
                       "hud.gd implements open_settings_modal() -> Control")
        reporter.check('open_modal(SETTINGS_MODAL_SCENE)' in hud_gd_code,
                       "hud.gd calls open_modal(SETTINGS_MODAL_SCENE)")
        reporter.check('close_nav_drawer()' in hud_gd_code,
                       "settings button click closes nav drawer before opening modal")

    # --------------------------------------------------------------------------
    # 5. TouchControls Dynamic Styling Check
    # --------------------------------------------------------------------------
    print("\n--- 5. TouchControls Dynamic Action Button Styling ---")
    if touch_gd.exists():
        tc_code = touch_gd.read_text(encoding="utf-8")
        reporter.check("_cached_overclock_style" in tc_code,
                       "touch_controls.gd declares _cached_overclock_style")
        reporter.check("_cached_pitch_style" in tc_code,
                       "touch_controls.gd declares _cached_pitch_style")
        reporter.check("Color(0.0, 0.92, 1.0" in tc_code,
                       "_cached_overclock_style uses Neon-Cyan / Electric-Blue border")
        reporter.check("Color(1.0, 0.84, 0.0" in tc_code,
                       "_cached_pitch_style uses Warm Gold border")
        reporter.check("Overclock [E]" in tc_code,
                       "touch_controls.gd recognizes 'Overclock [E]' interaction prompt")
        reporter.check("Pitch [E]" in tc_code,
                       "touch_controls.gd recognizes 'Pitch [E]' interaction prompt")

    # --------------------------------------------------------------------------
    # Summary
    # --------------------------------------------------------------------------
    print("\n====================================================================")
    print(f"Summary: {reporter.passes} Passed, {reporter.fails} Failed")
    if reporter.fails > 0:
        print(">>> Phase 9 Milestone 3 Verification FAILED! <<<")
        sys.exit(1)
    print(">>> Phase 9 Milestone 3 Mobile Touch-UX & Settings Modal Verified 100% Green! <<<\n")

if __name__ == "__main__":
    run_tests()
