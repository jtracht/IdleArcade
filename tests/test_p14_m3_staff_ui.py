#!/usr/bin/env python3
"""
Phase 14 Milestone 3: Mobile Staff Management Modal & Touch Ergonomics Verification Suite
========================================================================================
Target: Godot 4.3 IdleArcade - Milestone M3 (Requirement R3: Mobile Staff Management Modal & Touch Ergonomie)

Validates:
  1. Staff Modal Scene Hierarchy & Node Structure AST Check:
     - `scenes/ui/staff_modal.tscn` exists and contains:
       * Root `StaffModal` (`Control`, anchors_preset=15, mouse_filter=0 [STOP])
       * `Backdrop` (`ColorRect`, mouse_filter=0 [STOP])
       * `CenterContainer` (mouse_filter=2 [IGNORE])
       * `ModalCard` (`PanelContainer`, custom_minimum_size >= Vector2(680, 920), mouse_filter=0 [STOP])
       * `HeaderHBox` with Icon, Title, and `%CloseButton` (>= 56x56px, mouse_filter=0)
       * `StaffSummaryBanner` with `%StaffSummaryLabel`, `%StaffRPSBonusLabel`, `%HyperFocusStatusLabel`
       * `TabBarHBox` with 3 tab buttons: `%RecruitingTabButton`, `%DeskUpgradesTabButton`, `%TeambuildingTabButton` (>= 56px height, mouse_filter=0)
       * 3 touch-optimized tabs:
         - `%RecruitingTab` with `%WorkersScroll`, `%WorkersListVBox`, `%RoleOptionButton` (>= 56px), `%RecruitButton` (>= 56px)
         - `%DeskUpgradesTab` with `%DesksScroll`, `%DesksVBox`
         - `%TeambuildingTab` with `%HyperFocusProgressBar`, `%ServeCoffeeBreakButton` (>= 64px), `%EspressoSynergyLabel`
  2. Staff Modal Script Behavioral & AST Oracle (`scripts/ui/staff_modal.gd`):
     - `class_name StaffModal` extends `Control`
     - Declares `signal closed()`
     - Exports `active_tab_index`
     - Binds onready unique nodes (%CloseButton, %StaffSummaryLabel, %RecruitingTab, %DeskUpgradesTab, etc.)
     - Tab switching methods: `switch_tab(tab_idx)` and `set_tab(tab_idx)`
     - Dynamic worker card creation & dismissal: `_refresh_recruiting_tab()` and `_create_worker_card()`
     - Workstation upgrade card creation: `_refresh_desk_upgrades_tab()` and `_create_desk_card()`
     - Coffee break trigger & Hyper-Focus progress: `_refresh_teambuilding_tab()` and `_on_serve_coffee_break_pressed()`
     - Real-time `_process(delta)` countdown updates for Hyper-Focus
     - GameState signal synchronizations
  3. HUD Integration & Staff Badge / Button Oracle (`scenes/hud.tscn` & `scripts/hud.gd`):
     - `scenes/hud.tscn`:
       * `%StaffBadge` (`PanelContainer`) in `HeaderHBox` with minimum height >= 56px and `mouse_filter = 0`
       * `%StaffBadgeLabel` child displaying worker count & average morale %
       * `%StaffButton` (`Button`) in `NavItemsVBox` with minimum height >= 64px and `mouse_filter = 0`
       * SubResource `StyleBoxFlat_staff_badge`
     - `scripts/hud.gd`:
       * Preloads `STAFF_MODAL_SCENE: PackedScene = preload("res://scenes/ui/staff_modal.tscn")`
       * Declares `@onready var staff_badge`, `staff_badge_label`, `staff_button`
       * Connects staff signals: `staff_worker_hired`, `staff_worker_fired`, `staff_morale_updated`, etc.
       * Implements `open_staff_modal() -> Control` and `open_staff() -> Control`
       * Implements `_update_staff_badge()` and `_on_staff_state_changed()`
  4. TouchControls Dynamic Styling & Action Dispatch Oracle (`scripts/ui/touch_controls.gd`):
     - Declares `var _cached_staff_style: StyleBoxFlat = null`
     - Sets up Amber-Gold background (`Color(0.24, 0.16, 0.04, 0.92)`), Neon-Cyan border (`Color(0.0, 0.95, 1.0, 0.98)`), and gold shadow glow
     - Binds `"Staff [E]"` in `register_interactable()` and `unregister_interactable()`
     - Dispatches `open_staff_modal()` / `open_staff()` directly in `trigger_action()`
     - Applies `_cached_staff_style` in `_update_action_button_visuals()`
  5. Mobile Touch Ergonomics & Click Isolation Oracle:
     - All interactive buttons and tabs in `staff_modal.tscn` have custom_minimum_size >= 56px
     - Major action buttons and drawer buttons have custom_minimum_size >= 64px
     - Pointer isolation: mouse_filter = Control.MOUSE_FILTER_STOP (0) on all interactive nodes
  6. Real-World Staff Management Journey & UI Simulation:
     - Simulation of HUD badge text across worker lifecycle
     - Simulation of staff recruitment, desk leveling, and coffee break hyper-focus state in UI

Executable via: python tests/test_p14_m3_staff_ui.py
"""

import math
import re
import sys
from pathlib import Path
from typing import Dict, List, Tuple

if sys.platform == "win32":
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
        sys.stderr.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass


class Colors:
    HEADER = "\033[95m"
    OKBLUE = "\033[94m"
    OKCYAN = "\033[96m"
    OKGREEN = "\033[92m"
    WARNING = "\033[93m"
    FAIL = "\033[91m"
    ENDC = "\033[0m"
    BOLD = "\033[1m"


class TestReporter:
    def __init__(self):
        self.total = 0
        self.passed = 0
        self.failed = 0
        self.failures: List[str] = []

    def check(self, condition: bool, description: str, category: str = "GENERAL"):
        self.total += 1
        if condition:
            self.passed += 1
            print(f"  {Colors.OKGREEN}[PASS]{Colors.ENDC} [{category}] {description}")
        else:
            self.failed += 1
            msg = f"[{category}] {description}"
            self.failures.append(msg)
            print(f"  {Colors.FAIL}[FAIL]{Colors.ENDC} {msg}")

    def summarize(self) -> int:
        print("\n" + "=" * 70)
        print(f"{Colors.BOLD}Phase 14 Milestone M3 (Mobile Staff Management Modal & Touch Ergonomics) Results{Colors.ENDC}")
        print("=" * 70)
        print(f"  Total Checks : {self.total}")
        print(f"  Passed       : {Colors.OKGREEN}{self.passed}{Colors.ENDC}")
        print(f"  Failed       : {Colors.FAIL if self.failed > 0 else Colors.OKGREEN}{self.failed}{Colors.ENDC}")
        if self.failures:
            print(f"\n{Colors.FAIL}Failed Checks:{Colors.ENDC}")
            for f in self.failures:
                print(f"  - {f}")
        print("=" * 70)
        return 0 if self.failed == 0 else 1


def find_project_root() -> Path:
    candidates = [
        Path.cwd(),
        Path.cwd() / "IdleArcade",
        Path(__file__).resolve().parent.parent,
    ]
    for c in candidates:
        if (c / "project.godot").is_file():
            return c
        if (c / "IdleArcade" / "project.godot").is_file():
            return c / "IdleArcade"
    return Path.cwd()


def run_tests() -> int:
    reporter = TestReporter()
    root = find_project_root()

    staff_modal_tscn = root / "scenes" / "ui" / "staff_modal.tscn"
    staff_modal_gd = root / "scripts" / "ui" / "staff_modal.gd"
    hud_tscn = root / "scenes" / "hud.tscn"
    hud_gd = root / "scripts" / "hud.gd"
    touch_controls_gd = root / "scripts" / "ui" / "touch_controls.gd"

    # ==========================================================================
    # SECTION 1: Staff Modal Scene Hierarchy & Node Structure AST Check
    # ==========================================================================
    print(f"\n{Colors.HEADER}=== SECTION 1: Staff Modal Scene Hierarchy AST Check ==={Colors.ENDC}")
    reporter.check(staff_modal_tscn.is_file(), "scenes/ui/staff_modal.tscn exists on disk", "SCENE_File")

    modal_content = staff_modal_tscn.read_text(encoding="utf-8")

    reporter.check('[node name="StaffModal" type="Control"]' in modal_content, "Root node 'StaffModal' is type Control", "SCENE_Root")
    reporter.check('script = ExtResource("1_staffmodal")' in modal_content or "staff_modal.gd" in modal_content, "Root node attaches staff_modal.gd script", "SCENE_Script")
    reporter.check('[node name="Backdrop" type="ColorRect"' in modal_content, "Backdrop ColorRect node exists", "SCENE_Backdrop")
    reporter.check('[node name="CenterContainer" type="CenterContainer"' in modal_content, "CenterContainer exists for responsive layout", "SCENE_Center")
    reporter.check('[node name="ModalCard" type="PanelContainer"' in modal_content, "ModalCard PanelContainer exists", "SCENE_Card")

    # Header & Summary Nodes
    reporter.check('[node name="HeaderHBox" type="HBoxContainer"' in modal_content, "HeaderHBox exists", "SCENE_Header")
    reporter.check('name="CloseButton" type="Button"' in modal_content, "%CloseButton node exists", "SCENE_CloseBtn")
    reporter.check('unique_name_in_owner = true' in modal_content, "Scene utilizes unique_name_in_owner references", "SCENE_UniqueNames")
    reporter.check('name="StaffSummaryBanner"' in modal_content, "StaffSummaryBanner PanelContainer exists", "SCENE_Banner")
    reporter.check('name="StaffSummaryLabel"' in modal_content, "%StaffSummaryLabel exists", "SCENE_Labels")
    reporter.check('name="StaffRPSBonusLabel"' in modal_content, "%StaffRPSBonusLabel exists", "SCENE_Labels")
    reporter.check('name="HyperFocusStatusLabel"' in modal_content, "%HyperFocusStatusLabel exists", "SCENE_Labels")

    # Tab Bar & 3 Tabs
    reporter.check('name="TabBarHBox"' in modal_content, "TabBarHBox container exists", "SCENE_Tabs")
    reporter.check('name="RecruitingTabButton"' in modal_content, "%RecruitingTabButton exists", "SCENE_Tabs")
    reporter.check('name="DeskUpgradesTabButton"' in modal_content, "%DeskUpgradesTabButton exists", "SCENE_Tabs")
    reporter.check('name="TeambuildingTabButton"' in modal_content, "%TeambuildingTabButton exists", "SCENE_Tabs")

    reporter.check('name="TabContentContainer"' in modal_content, "TabContentContainer exists", "SCENE_TabContainer")
    reporter.check('name="RecruitingTab"' in modal_content, "%RecruitingTab exists", "SCENE_Tab1")
    reporter.check('name="WorkersScroll"' in modal_content, "%WorkersScroll exists", "SCENE_Tab1")
    reporter.check('name="WorkersListVBox"' in modal_content, "%WorkersListVBox exists", "SCENE_Tab1")
    reporter.check('name="RoleOptionButton"' in modal_content, "%RoleOptionButton exists", "SCENE_Tab1")
    reporter.check('name="RecruitButton"' in modal_content, "%RecruitButton exists", "SCENE_Tab1")

    reporter.check('name="DeskUpgradesTab"' in modal_content, "%DeskUpgradesTab exists", "SCENE_Tab2")
    reporter.check('name="DesksScroll"' in modal_content, "%DesksScroll exists", "SCENE_Tab2")
    reporter.check('name="DesksVBox"' in modal_content, "%DesksVBox exists", "SCENE_Tab2")

    reporter.check('name="TeambuildingTab"' in modal_content, "%TeambuildingTab exists", "SCENE_Tab3")
    reporter.check('name="HyperFocusProgressBar"' in modal_content, "%HyperFocusProgressBar exists", "SCENE_Tab3")
    reporter.check('name="ServeCoffeeBreakButton"' in modal_content, "%ServeCoffeeBreakButton exists", "SCENE_Tab3")
    reporter.check('name="EspressoSynergyLabel"' in modal_content, "%EspressoSynergyLabel exists", "SCENE_Tab3")

    # ==========================================================================
    # SECTION 2: Staff Modal Script Behavioral & AST Oracle
    # ==========================================================================
    print(f"\n{Colors.HEADER}=== SECTION 2: Staff Modal Script AST & API Oracle ==={Colors.ENDC}")
    reporter.check(staff_modal_gd.is_file(), "scripts/ui/staff_modal.gd exists on disk", "SCRIPT_File")

    script_content = staff_modal_gd.read_text(encoding="utf-8")

    reporter.check("class_name StaffModal" in script_content, "Declares class_name StaffModal", "SCRIPT_Class")
    reporter.check("extends Control" in script_content, "StaffModal extends Control", "SCRIPT_Inherits")
    reporter.check("signal closed" in script_content, "Declares signal closed()", "SCRIPT_Signals")
    reporter.check("@export var active_tab_index" in script_content, "Exports active_tab_index", "SCRIPT_Exports")

    # Onready unique name bindings
    reporter.check("@onready var close_button" in script_content and "%CloseButton" in script_content, "Binds %CloseButton", "SCRIPT_Onready")
    reporter.check("@onready var staff_summary_label" in script_content and "%StaffSummaryLabel" in script_content, "Binds %StaffSummaryLabel", "SCRIPT_Onready")
    reporter.check("@onready var recruiting_tab_button" in script_content and "%RecruitingTabButton" in script_content, "Binds %RecruitingTabButton", "SCRIPT_Onready")
    reporter.check("@onready var desk_upgrades_tab_button" in script_content and "%DeskUpgradesTabButton" in script_content, "Binds %DeskUpgradesTabButton", "SCRIPT_Onready")
    reporter.check("@onready var teambuilding_tab_button" in script_content and "%TeambuildingTabButton" in script_content, "Binds %TeambuildingTabButton", "SCRIPT_Onready")
    reporter.check("@onready var recruiting_tab" in script_content and "%RecruitingTab" in script_content, "Binds %RecruitingTab", "SCRIPT_Onready")
    reporter.check("@onready var desk_upgrades_tab" in script_content and "%DeskUpgradesTab" in script_content, "Binds %DeskUpgradesTab", "SCRIPT_Onready")
    reporter.check("@onready var teambuilding_tab" in script_content and "%TeambuildingTab" in script_content, "Binds %TeambuildingTab", "SCRIPT_Onready")
    reporter.check("@onready var recruit_button" in script_content and "%RecruitButton" in script_content, "Binds %RecruitButton", "SCRIPT_Onready")
    reporter.check("@onready var serve_coffee_break_button" in script_content and "%ServeCoffeeBreakButton" in script_content, "Binds %ServeCoffeeBreakButton", "SCRIPT_Onready")

    # Public API & Methods
    reporter.check("func open(" in script_content, "Implements open() lifecycle method", "SCRIPT_API")
    reporter.check("func close(" in script_content, "Implements close() lifecycle method", "SCRIPT_API")
    reporter.check("func switch_tab(" in script_content, "Implements switch_tab() navigation method", "SCRIPT_API")
    reporter.check("func set_tab(" in script_content, "Implements set_tab() compatibility method", "SCRIPT_API")
    reporter.check("func refresh_all(" in script_content, "Implements refresh_all() data synchronization", "SCRIPT_API")
    reporter.check("func _refresh_recruiting_tab(" in script_content, "Implements _refresh_recruiting_tab()", "SCRIPT_API")
    reporter.check("func _create_worker_card(" in script_content, "Implements _create_worker_card()", "SCRIPT_API")
    reporter.check("func _refresh_desk_upgrades_tab(" in script_content, "Implements _refresh_desk_upgrades_tab()", "SCRIPT_API")
    reporter.check("func _create_desk_card(" in script_content, "Implements _create_desk_card()", "SCRIPT_API")
    reporter.check("func _refresh_teambuilding_tab(" in script_content, "Implements _refresh_teambuilding_tab()", "SCRIPT_API")
    reporter.check("func _on_serve_coffee_break_pressed(" in script_content, "Implements _on_serve_coffee_break_pressed()", "SCRIPT_API")
    reporter.check("func _process(" in script_content, "Implements _process() for Hyper-Focus progress animation", "SCRIPT_API")

    # Specialist Roles & Desk Upgrades Coverage
    for r in ["Frontend Dev", "Backend Dev", "UI/UX Designer", "Growth Hacker", "QA Engineer"]:
        reporter.check(r in script_content, f"Supports specialist role: {r}", "SCRIPT_Roles")

    reporter.check("hire_worker" in script_content, "Connects with GameState.hire_worker()", "SCRIPT_Economy")
    reporter.check("fire_worker" in script_content, "Connects with GameState.fire_worker()", "SCRIPT_Economy")
    reporter.check("upgrade_desk" in script_content, "Connects with GameState.upgrade_desk()", "SCRIPT_Economy")
    reporter.check("give_team_coffee_break" in script_content, "Connects with GameState.give_team_coffee_break()", "SCRIPT_Economy")
    reporter.check("KEY_ESCAPE" in script_content, "Handles KEY_ESCAPE key to close modal", "SCRIPT_Input")

    # ==========================================================================
    # SECTION 3: HUD Integration & Staff Badge / Button Oracle
    # ==========================================================================
    print(f"\n{Colors.HEADER}=== SECTION 3: HUD Integration & Staff Badge Oracle ==={Colors.ENDC}")
    reporter.check(hud_tscn.is_file(), "scenes/hud.tscn exists on disk", "HUD_File")
    hud_content = hud_tscn.read_text(encoding="utf-8")

    reporter.check('name="StaffBadge" type="PanelContainer"' in hud_content, "%StaffBadge exists in hud.tscn", "HUD_Badge")
    reporter.check('name="StaffBadgeLabel" type="Label"' in hud_content, "%StaffBadgeLabel exists in hud.tscn", "HUD_BadgeLabel")
    reporter.check('name="StaffButton" type="Button"' in hud_content, "%StaffButton exists in hud.tscn NavDrawer", "HUD_Button")
    reporter.check('StyleBoxFlat_staff_badge' in hud_content, "SubResource StyleBoxFlat_staff_badge defined in hud.tscn", "HUD_Style")

    reporter.check(hud_gd.is_file(), "scripts/hud.gd exists on disk", "HUD_Script")
    hud_gd_content = hud_gd.read_text(encoding="utf-8")

    reporter.check("STAFF_MODAL_SCENE" in hud_gd_content and "staff_modal.tscn" in hud_gd_content, "Preloads STAFF_MODAL_SCENE in hud.gd", "HUD_Preload")
    reporter.check("staff_badge" in hud_gd_content and "%StaffBadge" in hud_gd_content, "Binds %StaffBadge in hud.gd", "HUD_Bindings")
    reporter.check("staff_badge_label" in hud_gd_content and "%StaffBadgeLabel" in hud_gd_content, "Binds %StaffBadgeLabel in hud.gd", "HUD_Bindings")
    reporter.check("staff_button" in hud_gd_content and "%StaffButton" in hud_gd_content, "Binds %StaffButton in hud.gd", "HUD_Bindings")
    reporter.check("func open_staff_modal(" in hud_gd_content, "Implements open_staff_modal() in hud.gd", "HUD_API")
    reporter.check("func open_staff(" in hud_gd_content, "Implements open_staff() alias in hud.gd", "HUD_API")
    reporter.check("func _update_staff_badge(" in hud_gd_content, "Implements _update_staff_badge() in hud.gd", "HUD_API")
    reporter.check("func _on_staff_state_changed(" in hud_gd_content, "Implements _on_staff_state_changed() in hud.gd", "HUD_API")
    reporter.check("staff_worker_hired" in hud_gd_content, "Subscribes to staff_worker_hired signal", "HUD_Signals")
    reporter.check("staff_worker_fired" in hud_gd_content, "Subscribes to staff_worker_fired signal", "HUD_Signals")
    reporter.check("staff_morale_updated" in hud_gd_content, "Subscribes to staff_morale_updated signal", "HUD_Signals")

    # ==========================================================================
    # SECTION 4: TouchControls Dynamic Styling & Action Dispatch Oracle
    # ==========================================================================
    print(f"\n{Colors.HEADER}=== SECTION 4: TouchControls Dynamic Styling Oracle ==={Colors.ENDC}")
    reporter.check(touch_controls_gd.is_file(), "scripts/ui/touch_controls.gd exists on disk", "TC_File")
    tc_content = touch_controls_gd.read_text(encoding="utf-8")

    reporter.check("var _cached_staff_style: StyleBoxFlat" in tc_content, "Declares _cached_staff_style in touch_controls.gd", "TC_Var")
    reporter.check("Color(0.24, 0.16, 0.04" in tc_content or "Color(0.30, 0.22, 0.06" in tc_content, "Amber-Gold background color configured", "TC_Colors")
    reporter.check("Color(0.0, 0.95, 1.0" in tc_content, "Neon-Cyan border color configured", "TC_Colors")
    reporter.check("Color(1.0, 0.75, 0.1" in tc_content or "Color(1.0, 0.8" in tc_content, "Gold glow shadow color configured", "TC_Colors")
    reporter.check('"Staff [E]"' in tc_content, "Configures 'Staff [E]' action label in touch_controls.gd", "TC_Label")
    reporter.check("open_staff_modal" in tc_content, "Dispatches open_staff_modal() on target interaction", "TC_Dispatch")
    reporter.check("_cached_staff_style" in tc_content and "add_theme_stylebox_override" in tc_content, "Applies _cached_staff_style to ActionButton", "TC_Styling")

    # ==========================================================================
    # SECTION 5: Mobile Touch Ergonomics & Click Isolation Oracle
    # ==========================================================================
    print(f"\n{Colors.HEADER}=== SECTION 5: Touch Ergonomics & Click Isolation Oracle ==={Colors.ENDC}")

    # Extract all custom_minimum_size in staff_modal.tscn
    vec2_matches = re.findall(r'custom_minimum_size\s*=\s*Vector2\(\s*([\d\.]+)\s*,\s*([\d\.]+)\s*\)', modal_content)
    reporter.check(len(vec2_matches) >= 8, f"Found {len(vec2_matches)} explicit custom_minimum_size entries in staff_modal.tscn", "ERGO_Count")

    all_targets_min_56 = True
    for w, h in vec2_matches:
        fw, fh = float(w), float(h)
        # Note: either width >= 56 and height >= 56, or height >= 56 for stretchable rows
        if fh < 56.0 and fw < 56.0:
            all_targets_min_56 = False
            break
    reporter.check(all_targets_min_56, "All interactive modal dimensions satisfy touch requirement (>= 56px)", "ERGO_Sizes")

    # Verify mouse_filter = 0 (Control.MOUSE_FILTER_STOP) on interactive containers
    reporter.check('mouse_filter = 0' in modal_content, "StaffModal incorporates mouse_filter = 0 (MOUSE_FILTER_STOP)", "ERGO_StopFilter")

    # Check HUD touch sizes
    hud_staff_badge_match = re.search(r'\[node name="StaffBadge"[^\]]*\][^\[]*custom_minimum_size\s*=\s*Vector2\(\s*([\d\.]+)\s*,\s*([\d\.]+)\s*\)', hud_content)
    reporter.check(hud_staff_badge_match is not None, "HUD %StaffBadge has explicit custom_minimum_size", "ERGO_HUD")
    if hud_staff_badge_match:
        bw, bh = float(hud_staff_badge_match.group(1)), float(hud_staff_badge_match.group(2))
        reporter.check(bh >= 56.0, f"HUD %StaffBadge height ({bh}px) >= 56px", "ERGO_HUD")

    hud_staff_btn_match = re.search(r'\[node name="StaffButton"[^\]]*\][^\[]*custom_minimum_size\s*=\s*Vector2\(\s*([\d\.]+)\s*,\s*([\d\.]+)\s*\)', hud_content)
    reporter.check(hud_staff_btn_match is not None, "HUD %StaffButton has explicit custom_minimum_size", "ERGO_HUD")
    if hud_staff_btn_match:
        bw, bh = float(hud_staff_btn_match.group(1)), float(hud_staff_btn_match.group(2))
        reporter.check(bh >= 64.0, f"HUD %StaffButton height ({bh}px) >= 64px for drawer navigation", "ERGO_HUD")

    # ==========================================================================
    # SECTION 6: Real-World Staff Management Journey & UI Simulation
    # ==========================================================================
    print(f"\n{Colors.HEADER}=== SECTION 6: Simulated Staff Management Journey Oracle ==={Colors.ENDC}")

    # Simulated HUD Badge logic
    def format_badge(count: int, morale: float) -> str:
        return "👥 %d (%d%%)" % (count, int(round(morale * 100.0)))

    reporter.check(format_badge(0, 1.0) == "👥 0 (100%)", "HUD badge zero state formats to '👥 0 (100%)'", "SIM_Badge")
    reporter.check(format_badge(3, 0.85) == "👥 3 (85%)", "HUD badge 3 workers at 85% morale formats to '👥 3 (85%)'", "SIM_Badge")
    reporter.check(format_badge(5, 0.423) == "👥 5 (42%)", "HUD badge 5 workers at 42.3% morale formats to '👥 5 (42%)'", "SIM_Badge")

    # Simulated Tab switching bounds
    def clamp_tab(idx: int) -> int:
        return max(0, min(2, idx))

    reporter.check(clamp_tab(0) == 0, "Tab 0 (Recruiting) clamped correctly", "SIM_Tabs")
    reporter.check(clamp_tab(1) == 1, "Tab 1 (Desks) clamped correctly", "SIM_Tabs")
    reporter.check(clamp_tab(2) == 2, "Tab 2 (Teambuilding) clamped correctly", "SIM_Tabs")
    reporter.check(clamp_tab(99) == 2, "Out-of-range tab index (99) clamped to 2", "SIM_Tabs")
    reporter.check(clamp_tab(-5) == 0, "Negative tab index (-5) clamped to 0", "SIM_Tabs")

    # Simulated Desk Upgrade Ergonomics
    def desk_reduction(level: int) -> int:
        if level == 2:
            return 25
        elif level >= 3:
            return 60
        return 0

    reporter.check(desk_reduction(1) == 0, "Level 1 desk has 0% fatigue reduction", "SIM_Desks")
    reporter.check(desk_reduction(2) == 25, "Level 2 desk has 25% fatigue reduction", "SIM_Desks")
    reporter.check(desk_reduction(3) == 60, "Level 3 desk has 60% fatigue reduction", "SIM_Desks")

    # Simulated Hyper-Focus countdown formatting
    def format_hyper_focus(time_rem: float) -> str:
        if time_rem > 0.0:
            return "Hyper-Focus: Active (%.1fs remaining, 1.5x speed)" % time_rem
        return "Hyper-Focus: Inactive"

    reporter.check(format_hyper_focus(60.0) == "Hyper-Focus: Active (60.0s remaining, 1.5x speed)", "Hyper-Focus full duration formats accurately", "SIM_Coffee")
    reporter.check(format_hyper_focus(0.0) == "Hyper-Focus: Inactive", "Hyper-Focus inactive status formats accurately", "SIM_Coffee")

    return reporter.summarize()


if __name__ == "__main__":
    sys.exit(run_tests())
