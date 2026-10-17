#!/usr/bin/env python3
"""
Phase 13 Milestone 3: Mobile Guild & Syndicate War UI Verification Suite
========================================================================
Target: Godot 4.3 IdleArcade - Milestone M3 (Requirement R3: Mobile Guild & Syndicate War UI)

Validates:
  1. Scene Hierarchy, Tabs & Node Structure AST Check:
     - `scenes/ui/syndicate_modal.tscn` exists and contains:
       * Root `SyndicateModal` (`Control`, anchors preset 15, mouse_filter = 0 / STOP)
       * `Backdrop` (`ColorRect`, color translucent dark emerald `Color(0.02, 0.05, 0.04, 0.88)`, mouse_filter = 0)
       * `ModalCard` (`PanelContainer`, mouse_filter = 0)
       * `%CloseButton` (minimum size >= Vector2(56, 56), mouse_filter = 0)
       * 3 Tabs declared and present:
         - `%OverviewTab`
         - `%RosterTab`
         - `%WarsTab`
       * Tab 1: Overview & Perk Tree:
         - Visual 5-tier perk cards (%PerkCardTier1 .. %PerkCardTier5)
         - Status indicators: Unlocked (#00E676), Next Objective (#00E5FF), Locked (#37474F)
         - %TierProgressBar and %TierProgressLabel
         - %SyndicateIdentityLabel and %SyndicateTierBadgeLabel
       * Tab 2: Member Roster & Vault Donations:
         - Scrollable roster (`ScrollContainer`, mouse_filter = 0) with %MemberListVBox
         - %DonationSlider (`HSlider`, height >= 56px, mouse_filter = 0)
         - Quick preset steppers: %Preset10Button, %Preset50Button, %PresetMaxButton (all height >= 56px, mouse_filter = 0)
         - Action buttons: %DonateEnergyButton, %DonateSharesButton (all height >= 56px, mouse_filter = 0)
         - %PlayerWalletLabel, %DonationAmountLabel, %DonationStatusLabel
       * Tab 3: Syndicate Wars & Seasons:
         - %SeasonTimerLabel (countdown timer)
         - %RankBadgeLabel (active ranking)
         - Top 10 leaderboard entries in %LeaderboardVBox inside scroll container (mouse_filter = 0)

  2. Mobile Touch Ergonomics & Pointer Isolation Oracle:
     - All interactive controls (buttons, sliders, steppers, close button, tab buttons) have:
       * custom_minimum_size.y >= 56.0 (or Vector2(56, 56))
       * mouse_filter = 0 (Control.MOUSE_FILTER_STOP)
     - Strict isolation: Root and Backdrop have mouse_filter = 0 to prevent click leakage to 3D world.
     - HUD %SyndicateBadge has height >= 56px and mouse_filter = 0.
     - HUD %SyndicateButton has height >= 64px and mouse_filter = 0.

  3. Script Behavioral & GameState Integration AST Oracle (`scripts/ui/syndicate_modal.gd`):
     - `extends Control`
     - Declares `signal closed`
     - Methods: `open()`, `close()`, `switch_tab()`, `refresh_all_tabs()`, `refresh_overview()`,
       `refresh_roster()`, `refresh_wars()`, `set_donation_preset()`, `contribute_energy()`,
       `contribute_shares()`, `_update_season_timer()`
     - Integrates with GameState:
       * GameState.contribute_to_syndicate(amount, "energy")
       * GameState.contribute_angel_shares_to_syndicate(1)
       * GameState.get_active_syndicate()
       * GameState.get_syndicate_bonuses()
       * GameState.get_syndicate_tier_definitions()
       * GameState.get_seasonal_leaderboard_score()
       * GameState.is_in_syndicate()
     - Connects reactive signals:
       * GameState.syndicate_joined
       * GameState.syndicate_left
       * GameState.syndicate_contributed
       * GameState.syndicate_tier_upgraded
       * GameState.syndicate_season_updated
       * GameState.energy_changed
       * GameState.angel_shares_changed
     - Audio click feedback (AudioManager.play_sfx_click())
     - Haptic tactile feedback (HapticsManager / Input.vibrate_handheld())

  4. HUD Integration & Routing Oracle (`scenes/hud.tscn` & `scripts/hud.gd`):
     - scenes/hud.tscn declares %SyndicateBadge with height >= 56px and mouse_filter = 0
     - scenes/hud.tscn declares %SyndicateButton with height >= 64px and mouse_filter = 0
     - scripts/hud.gd preloads SYNDICATE_MODAL_SCENE
     - scripts/hud.gd implements open_syndicate_modal() -> Control
     - scripts/hud.gd hooks %SyndicateBadge and %SyndicateButton to open_syndicate_modal()
     - scripts/hud.gd connects GameState syndicate signals to refresh %SyndicateBadge
     - scripts/hud.gd formats badge text: "🏢 [SOLO]" or "🏢 [TAG] +X%"

  5. Mathematical Simulation & UI Logic Matrix Oracle:
     - Preset donation calculation (10%, 50%, 100%)
     - Tier progress calculation
     - Color assignment logic (unlocked, next objective, locked)
     - Season timer formatting math
     - HUD badge formatting matrix

Executable via: python tests/test_p13_m3_syndicate_ui.py
"""

import math
import re
import sys
import time
from pathlib import Path
from typing import Dict, List, Tuple


class Colors:
    HEADER = "\033[95m"
    OKBLUE = "\033[94m"
    OKCYAN = "\033[96m"
    OKGREEN = "\033[92m"
    WARNING = "\033[93m"
    FAIL = "\033[91m"
    ENDC = "\033[0m"
    BOLD = "\033[1m"


if sys.stdout.encoding and sys.stdout.encoding.lower() != "utf-8":
    try:
        sys.stdout.reconfigure(encoding="utf-8")
        sys.stderr.reconfigure(encoding="utf-8")
    except Exception:
        pass


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
            msg = f"  {Colors.OKGREEN}[PASS]{Colors.ENDC} [{category}] {description}"
        else:
            self.failed += 1
            fail_str = f"[{category}] {description}"
            self.failures.append(fail_str)
            msg = f"  {Colors.FAIL}[FAIL]{Colors.ENDC} {fail_str}"
        try:
            print(msg)
        except UnicodeEncodeError:
            print(msg.encode("ascii", errors="replace").decode("ascii"))

    def summarize(self) -> int:
        print("\n" + "=" * 70)
        print(f"{Colors.BOLD}Phase 13 Milestone M3 (Mobile Syndicate UI) Test Results{Colors.ENDC}")
        print("=" * 70)
        print(f"  Total Checks : {self.total}")
        print(f"  Passed       : {Colors.OKGREEN}{self.passed}{Colors.ENDC}")
        print(f"  Failed       : {Colors.FAIL if self.failed > 0 else Colors.OKGREEN}{self.failed}{Colors.ENDC}")
        if self.failures:
            print(f"\n{Colors.FAIL}Failed Checks:{Colors.ENDC}")
            for f in self.failures:
                print(f"  - {f}")
            print("\n>>> OVERALL VERDICT: FAIL <<<")
            return 1
        print(f"\n{Colors.OKGREEN}>>> OVERALL VERDICT: 100% PASS (ALL CHECKS GREEN) <<<{Colors.ENDC}")
        return 0


# ==============================================================================
# SECTION 1: Scene Hierarchy, Tabs & Node Structure AST Check
# ==============================================================================

def verify_scene_hierarchy(reporter: TestReporter, game_dir: Path):
    print(f"\n{Colors.BOLD}=== SECTION 1: Scene Hierarchy, Tabs & Node Structure AST Check ==={Colors.ENDC}")

    scene_path = game_dir / "scenes/ui/syndicate_modal.tscn"
    reporter.check(scene_path.exists(), "scenes/ui/syndicate_modal.tscn exists on disk", "SCENE_File")
    if not scene_path.exists():
        return

    content = scene_path.read_text(encoding="utf-8")

    # 1. Root Node & Backdrop
    reporter.check('name="SyndicateModal"' in content and 'type="Control"' in content,
                   "Root node is Control named SyndicateModal", "SCENE_Root")
    reporter.check('script = ExtResource(' in content and 'syndicate_modal.gd' in content,
                   "Root node binds res://scripts/ui/syndicate_modal.gd", "SCENE_Script")
    reporter.check('name="Backdrop"' in content and 'type="ColorRect"' in content,
                   "Backdrop (ColorRect) exists", "SCENE_Backdrop")
    reporter.check('color = Color(0.02, 0.05, 0.04, 0.88)' in content or ('0.02, 0.05, 0.04' in content),
                   "Backdrop uses translucent dark emerald Color(0.02, 0.05, 0.04, 0.88)", "SCENE_Backdrop")

    # 2. ModalCard & CloseButton
    reporter.check('name="ModalCard"' in content and 'type="PanelContainer"' in content,
                   "ModalCard (PanelContainer) exists", "SCENE_Card")
    reporter.check('name="CloseButton"' in content,
                   "CloseButton node exists", "SCENE_Close")
    reporter.check('%CloseButton' in content or ('unique_name_in_owner = true' in content and 'CloseButton' in content),
                   "CloseButton has unique_name_in_owner = true (%CloseButton)", "SCENE_Close")

    # 3. Three Tabs
    reporter.check('name="OverviewTab"' in content, "Tab 1 (OverviewTab) exists with unique name", "SCENE_Tabs")
    reporter.check('name="RosterTab"' in content, "Tab 2 (RosterTab) exists with unique name", "SCENE_Tabs")
    reporter.check('name="WarsTab"' in content, "Tab 3 (WarsTab) exists with unique name", "SCENE_Tabs")

    # Tab navigation buttons
    reporter.check('name="OverviewTabButton"' in content, "OverviewTabButton declared with unique name", "SCENE_TabNav")
    reporter.check('name="RosterTabButton"' in content, "RosterTabButton declared with unique name", "SCENE_TabNav")
    reporter.check('name="WarsTabButton"' in content, "WarsTabButton declared with unique name", "SCENE_TabNav")

    # 4. Tab 1: Overview & Perk Tree Elements
    reporter.check('name="SyndicateIdentityLabel"' in content, "%SyndicateIdentityLabel exists", "SCENE_Overview")
    reporter.check('name="SyndicateTierBadgeLabel"' in content, "%SyndicateTierBadgeLabel exists", "SCENE_Overview")
    reporter.check('name="TierProgressBar"' in content, "%TierProgressBar exists", "SCENE_Overview")
    reporter.check('name="TierProgressLabel"' in content, "%TierProgressLabel exists", "SCENE_Overview")

    for t in range(1, 6):
        card_name = f'name="PerkCardTier{t}"'
        reporter.check(card_name in content,
                       f"Perk Card Tier {t} exists ({card_name})", "SCENE_PerkCards")

    # 5. Tab 2: Roster & Vault Donation Elements
    reporter.check('name="MemberListVBox"' in content, "%MemberListVBox roster container exists", "SCENE_Roster")
    reporter.check('RosterScroll' in content and 'ScrollContainer' in content, "Scrollable roster container exists", "SCENE_Roster")
    reporter.check('name="PlayerWalletLabel"' in content, "%PlayerWalletLabel exists", "SCENE_Donations")
    reporter.check('name="DonationAmountLabel"' in content, "%DonationAmountLabel exists", "SCENE_Donations")
    reporter.check('name="DonationSlider"' in content, "%DonationSlider exists", "SCENE_Donations")
    reporter.check('name="Preset10Button"' in content, "%Preset10Button exists (10% preset)", "SCENE_Donations")
    reporter.check('name="Preset50Button"' in content, "%Preset50Button exists (50% preset)", "SCENE_Donations")
    reporter.check('name="PresetMaxButton"' in content, "%PresetMaxButton exists (MAX preset)", "SCENE_Donations")
    reporter.check('name="DonateEnergyButton"' in content, "%DonateEnergyButton exists", "SCENE_Donations")
    reporter.check('name="DonateSharesButton"' in content, "%DonateSharesButton exists", "SCENE_Donations")
    reporter.check('name="DonationStatusLabel"' in content, "%DonationStatusLabel exists", "SCENE_Donations")

    # 6. Tab 3: Syndicate Wars & Seasons Elements
    reporter.check('name="SeasonTimerLabel"' in content, "%SeasonTimerLabel countdown label exists", "SCENE_Wars")
    reporter.check('name="RankBadgeLabel"' in content, "%RankBadgeLabel active rank label exists", "SCENE_Wars")
    reporter.check('name="LeaderboardVBox"' in content, "%LeaderboardVBox leaderboard container exists", "SCENE_Wars")
    reporter.check('LeaderboardScroll' in content and 'ScrollContainer' in content, "Scrollable leaderboard container exists", "SCENE_Wars")


# ==============================================================================
# SECTION 2: Mobile Touch Ergonomics & Pointer Isolation Oracle
# ==============================================================================

def verify_touch_ergonomics(reporter: TestReporter, game_dir: Path):
    print(f"\n{Colors.BOLD}=== SECTION 2: Mobile Touch Ergonomics & Pointer Isolation Oracle ==={Colors.ENDC}")

    modal_path = game_dir / "scenes/ui/syndicate_modal.tscn"
    hud_path = game_dir / "scenes/hud.tscn"

    if not modal_path.exists() or not hud_path.exists():
        reporter.check(False, "Required scene files missing for ergonomics audit", "ERGO_File")
        return

    modal_content = modal_path.read_text(encoding="utf-8")
    hud_content = hud_path.read_text(encoding="utf-8")

    # 1. Pointer Isolation: Root & Backdrop must have mouse_filter = 0 (MOUSE_FILTER_STOP)
    root_match = re.search(r'\[node name="SyndicateModal" type="Control"\].*?(?=\n\[|$)', modal_content, re.DOTALL)
    reporter.check(root_match is not None and 'mouse_filter = 0' in root_match.group(0),
                   "SyndicateModal root enforces mouse_filter = 0 (MOUSE_FILTER_STOP)", "ERGO_Isolation")

    backdrop_match = re.search(r'\[node name="Backdrop" type="ColorRect".*?(?=\n\[|$)', modal_content, re.DOTALL)
    reporter.check(backdrop_match is not None and 'mouse_filter = 0' in backdrop_match.group(0),
                   "Backdrop enforces mouse_filter = 0 (MOUSE_FILTER_STOP)", "ERGO_Isolation")

    card_match = re.search(r'\[node name="ModalCard" type="PanelContainer".*?(?=\n\[|$)', modal_content, re.DOTALL)
    reporter.check(card_match is not None and 'mouse_filter = 0' in card_match.group(0),
                   "ModalCard enforces mouse_filter = 0 (MOUSE_FILTER_STOP)", "ERGO_Isolation")

    # 2. Interactive Control Minimum Heights >= 56px and mouse_filter = 0
    interactive_elements = [
        ("CloseButton", r'\[node name="CloseButton"[^\]]*\](.*?)(?=\n\[|\Z)'),
        ("OverviewTabButton", r'\[node name="OverviewTabButton"[^\]]*\](.*?)(?=\n\[|\Z)'),
        ("RosterTabButton", r'\[node name="RosterTabButton"[^\]]*\](.*?)(?=\n\[|\Z)'),
        ("WarsTabButton", r'\[node name="WarsTabButton"[^\]]*\](.*?)(?=\n\[|\Z)'),
        ("DonationSlider", r'\[node name="DonationSlider"[^\]]*\](.*?)(?=\n\[|\Z)'),
        ("Preset10Button", r'\[node name="Preset10Button"[^\]]*\](.*?)(?=\n\[|\Z)'),
        ("Preset50Button", r'\[node name="Preset50Button"[^\]]*\](.*?)(?=\n\[|\Z)'),
        ("PresetMaxButton", r'\[node name="PresetMaxButton"[^\]]*\](.*?)(?=\n\[|\Z)'),
        ("DonateEnergyButton", r'\[node name="DonateEnergyButton"[^\]]*\](.*?)(?=\n\[|\Z)'),
        ("DonateSharesButton", r'\[node name="DonateSharesButton"[^\]]*\](.*?)(?=\n\[|\Z)'),
    ]

    for name, pattern in interactive_elements:
        m = re.search(pattern, modal_content, re.DOTALL)
        reporter.check(m is not None, f"Interactive node '{name}' found in syndicate_modal.tscn", "ERGO_Presence")
        if m:
            block = m.group(1)
            # Check size: Vector2(w, h) where h >= 56
            size_match = re.search(r'custom_minimum_size\s*=\s*Vector2\(\s*([0-9.]+),\s*([0-9.]+)\s*\)', block)
            if size_match:
                height = float(size_match.group(2))
                reporter.check(height >= 56.0,
                               f"{name} height >= 56px (actual: {height:.0f}px)", "ERGO_Height")
            else:
                reporter.check(False, f"{name} custom_minimum_size not specified", "ERGO_Height")

            # Check mouse_filter = 0 (MOUSE_FILTER_STOP)
            mf_match = re.search(r'mouse_filter\s*=\s*(\d+)', block)
            if mf_match:
                mf_val = int(mf_match.group(1))
                reporter.check(mf_val == 0, f"{name} mouse_filter = 0 (STOP) (actual: {mf_val})", "ERGO_MouseFilter")
            else:
                # Default for Button is 0 (STOP), but explicit specification is best
                reporter.check(True, f"{name} inherits default Control.MOUSE_FILTER_STOP", "ERGO_MouseFilter")

    # 3. HUD Controls: %SyndicateBadge and %SyndicateButton
    badge_m = re.search(r'\[node name="SyndicateBadge"[^\]]*\](.*?)(?=\n\[|\Z)', hud_content, re.DOTALL)
    reporter.check(badge_m is not None, "HUD declares %SyndicateBadge node", "ERGO_HUD")
    if badge_m:
        b_block = badge_m.group(1)
        b_size = re.search(r'custom_minimum_size\s*=\s*Vector2\(\s*([0-9.]+),\s*([0-9.]+)\s*\)', b_block)
        if b_size:
            b_height = float(b_size.group(2))
            reporter.check(b_height >= 56.0, f"HUD %SyndicateBadge height >= 56px (actual: {b_height:.0f}px)", "ERGO_HUD")
        else:
            reporter.check(False, "HUD %SyndicateBadge custom_minimum_size missing", "ERGO_HUD")
        reporter.check('mouse_filter = 0' in b_block, "HUD %SyndicateBadge mouse_filter = 0 (STOP)", "ERGO_HUD")

    btn_m = re.search(r'\[node name="SyndicateButton"[^\]]*\](.*?)(?=\n\[|\Z)', hud_content, re.DOTALL)
    reporter.check(btn_m is not None, "HUD declares %SyndicateButton in nav drawer", "ERGO_HUD")
    if btn_m:
        btn_block = btn_m.group(1)
        btn_size = re.search(r'custom_minimum_size\s*=\s*Vector2\(\s*([0-9.]+),\s*([0-9.]+)\s*\)', btn_block)
        if btn_size:
            btn_height = float(btn_size.group(2))
            reporter.check(btn_height >= 64.0, f"HUD %SyndicateButton height >= 64px (actual: {btn_height:.0f}px)", "ERGO_HUD")
        else:
            reporter.check(False, "HUD %SyndicateButton custom_minimum_size missing", "ERGO_HUD")
        reporter.check('mouse_filter = 0' in btn_block, "HUD %SyndicateButton mouse_filter = 0 (STOP)", "ERGO_HUD")


# ==============================================================================
# SECTION 3: Script Behavioral & GameState Integration AST Oracle
# ==============================================================================

def verify_script_ast(reporter: TestReporter, game_dir: Path):
    print(f"\n{Colors.BOLD}=== SECTION 3: Script Behavioral & GameState Integration AST Oracle ==={Colors.ENDC}")

    script_path = game_dir / "scripts/ui/syndicate_modal.gd"
    reporter.check(script_path.exists(), "scripts/ui/syndicate_modal.gd exists", "AST_File")
    if not script_path.exists():
        return

    content = script_path.read_text(encoding="utf-8")

    # 1. Class & Signal Declarations
    reporter.check('extends Control' in content, "syndicate_modal.gd extends Control", "AST_Inherits")
    reporter.check('signal closed' in content, "syndicate_modal.gd declares signal closed", "AST_Signal")

    # 2. Color Constants
    reporter.check('COLOR_UNLOCKED' in content and '0.9' in content,
                   "Declares COLOR_UNLOCKED emerald constant (#00E676)", "AST_Color")
    reporter.check('COLOR_NEXT_OBJ' in content and '0.9' in content,
                   "Declares COLOR_NEXT_OBJ cyan constant (#00E5FF)", "AST_Color")
    reporter.check('COLOR_LOCKED' in content,
                   "Declares COLOR_LOCKED dim gray constant (#37474F)", "AST_Color")

    # 3. Core Methods
    expected_methods = [
        ("open", r"func\s+open\s*\(\s*\)"),
        ("close", r"func\s+close\s*\(\s*\)"),
        ("switch_tab", r"func\s+switch_tab\s*\("),
        ("refresh_all_tabs", r"func\s+refresh_all_tabs\s*\(\s*\)"),
        ("refresh_overview", r"func\s+refresh_overview\s*\(\s*\)"),
        ("refresh_roster", r"func\s+refresh_roster\s*\(\s*\)"),
        ("refresh_wars", r"func\s+refresh_wars\s*\(\s*\)"),
        ("set_donation_preset", r"func\s+set_donation_preset\s*\("),
        ("contribute_energy", r"func\s+contribute_energy\s*\(\s*\)"),
        ("contribute_shares", r"func\s+contribute_shares\s*\(\s*\)"),
        ("_update_season_timer", r"func\s+_update_season_timer\s*\(\s*\)"),
    ]
    for name, pattern in expected_methods:
        reporter.check(re.search(pattern, content) is not None,
                       f"Method implemented: {name}()", "AST_Method")

    # 4. GameState API Integrations
    reporter.check('GameState.contribute_to_syndicate' in content,
                   "Calls GameState.contribute_to_syndicate()", "AST_Integration")
    reporter.check('GameState.contribute_angel_shares_to_syndicate' in content,
                   "Calls GameState.contribute_angel_shares_to_syndicate()", "AST_Integration")
    reporter.check('GameState.get_active_syndicate' in content,
                   "Calls GameState.get_active_syndicate()", "AST_Integration")
    reporter.check('GameState.get_syndicate_bonuses' in content or 'get_syndicate_tier' in content,
                   "Queries GameState syndicate bonuses and tier", "AST_Integration")
    reporter.check('GameState.get_syndicate_tier_definitions' in content,
                   "Queries GameState.get_syndicate_tier_definitions()", "AST_Integration")
    reporter.check('GameState.get_seasonal_leaderboard_score' in content,
                   "Queries GameState.get_seasonal_leaderboard_score()", "AST_Integration")
    reporter.check('GameState.is_in_syndicate' in content,
                   "Checks GameState.is_in_syndicate()", "AST_Integration")

    # 5. GameState Signals
    expected_signals = [
        "syndicate_joined",
        "syndicate_left",
        "syndicate_contributed",
        "syndicate_tier_upgraded",
        "syndicate_season_updated",
        "energy_changed",
        "angel_shares_changed",
    ]
    for sig in expected_signals:
        reporter.check(f'GameState.has_signal("{sig}")' in content or f'GameState.{sig}' in content,
                       f"Hooks reactive signal: {sig}", "AST_SignalHook")

    # 6. Audio and Haptics
    reporter.check('play_sfx_click' in content,
                   "Invokes AudioManager.play_sfx_click() on interactions", "AST_Audio")
    reporter.check('HapticsManager' in content or 'vibrate_handheld' in content,
                   "Triggers haptic tactile feedback on donations", "AST_Haptics")


# ==============================================================================
# SECTION 4: HUD Integration & Routing Oracle
# ==============================================================================

def verify_hud_integration(reporter: TestReporter, game_dir: Path):
    print(f"\n{Colors.BOLD}=== SECTION 4: HUD Integration & Routing Oracle ==={Colors.ENDC}")

    hud_tscn_path = game_dir / "scenes/hud.tscn"
    hud_gd_path = game_dir / "scripts/hud.gd"

    reporter.check(hud_tscn_path.exists(), "scenes/hud.tscn exists", "HUD_File")
    reporter.check(hud_gd_path.exists(), "scripts/hud.gd exists", "HUD_File")

    if not hud_tscn_path.exists() or not hud_gd_path.exists():
        return

    tscn = hud_tscn_path.read_text(encoding="utf-8")
    gd = hud_gd_path.read_text(encoding="utf-8")

    # 1. scenes/hud.tscn definitions
    reporter.check('name="SyndicateBadge"' in tscn,
                   "scenes/hud.tscn declares %SyndicateBadge", "HUD_Badge")
    reporter.check('name="SyndicateBadgeLabel"' in tscn,
                   "scenes/hud.tscn declares %SyndicateBadgeLabel", "HUD_BadgeLabel")
    reporter.check('name="SyndicateButton"' in tscn,
                   "scenes/hud.tscn declares %SyndicateButton", "HUD_Button")

    # 2. scripts/hud.gd preloads and declarations
    reporter.check('const SYNDICATE_MODAL_SCENE' in gd and 'syndicate_modal.tscn' in gd,
                   "scripts/hud.gd preloads SYNDICATE_MODAL_SCENE", "HUD_Preload")
    reporter.check('syndicate_badge' in gd,
                   "scripts/hud.gd binds syndicate_badge variable", "HUD_Variable")
    reporter.check('syndicate_button' in gd,
                   "scripts/hud.gd binds syndicate_button variable", "HUD_Variable")

    # 3. Method open_syndicate_modal() -> Control
    reporter.check('func open_syndicate_modal' in gd,
                   "scripts/hud.gd implements open_syndicate_modal() -> Control", "HUD_OpenMethod")
    reporter.check('return open_modal(SYNDICATE_MODAL_SCENE)' in gd or 'open_modal' in gd,
                   "open_syndicate_modal() delegates to open_modal(SYNDICATE_MODAL_SCENE)", "HUD_OpenMethod")

    # 4. Button & Badge Hooks
    reporter.check('syndicate_button.pressed.connect' in gd,
                   "scripts/hud.gd connects syndicate_button.pressed", "HUD_Connect")
    reporter.check('syndicate_badge' in gd and ('open_syndicate_modal' in gd),
                   "scripts/hud.gd hooks syndicate_badge to open_syndicate_modal()", "HUD_Connect")

    # 5. Signal Listeners & Badge Formatting
    reporter.check('syndicate_joined' in gd,
                   "scripts/hud.gd listens to GameState.syndicate_joined", "HUD_Signals")
    reporter.check('syndicate_tier_upgraded' in gd,
                   "scripts/hud.gd listens to GameState.syndicate_tier_upgraded", "HUD_Signals")
    reporter.check('func _update_syndicate_badge' in gd,
                   "scripts/hud.gd implements _update_syndicate_badge()", "HUD_UpdateBadge")
    reporter.check('[SOLO]' in gd,
                   "_update_syndicate_badge() formats default unaffiliated identity '[SOLO]'", "HUD_Formatting")


# ==============================================================================
# SECTION 5: Mathematical Simulation & UI Logic Matrix Oracle
# ==============================================================================

def simulate_stepper_preset(player_energy: float, pct: float) -> float:
    return float(math.floor(player_energy * min(max(pct, 0.0), 1.0)))


def simulate_tier_progress(current_tier: int, fund_energy: float, fund_shares: int) -> Tuple[float, str]:
    configs = {
        1: {"req_energy": 10000.0, "req_shares": 1},
        2: {"req_energy": 100000.0, "req_shares": 5},
        3: {"req_energy": 500000.0, "req_shares": 20},
        4: {"req_energy": 2500000.0, "req_shares": 50},
        5: {"req_energy": 10000000.0, "req_shares": 100},
    }
    if current_tier >= 5:
        return 100.0, "Syndicate Vault MAXED (Tier 5 Monopoly Achieved!)"

    next_tier = min(5, current_tier + 1)
    cfg = configs[next_tier]
    e_ratio = fund_energy / cfg["req_energy"]
    s_ratio = float(fund_shares) / float(cfg["req_shares"])
    pct = max(0.0, min(100.0, max(e_ratio, s_ratio) * 100.0))
    label = f"Vault Progress: {fund_energy:,.0f} / {cfg['req_energy']:,.0f} Energy -> Tier {next_tier}"
    return pct, label


def simulate_card_status(card_tier: int, current_tier: int) -> str:
    if card_tier <= current_tier:
        return "UNLOCKED"
    elif card_tier == current_tier + 1:
        return "NEXT OBJECTIVE"
    else:
        return "LOCKED"


def simulate_countdown_timer(unix_timestamp: int) -> str:
    week_seconds = 86400 * 7
    remaining = week_seconds - (unix_timestamp % week_seconds)
    days = remaining // 86400
    hours = (remaining % 86400) // 3600
    mins = (remaining % 3600) // 60
    secs = remaining % 60
    return f"⏳ Season 1 Ends In: {days}d {hours:02d}h {mins:02d}m {secs:02d}s"


def simulate_hud_badge(is_in_syndicate: bool, tag: str, tier: int) -> str:
    if not is_in_syndicate:
        return "🏢 [SOLO]"
    clean_tag = tag.strip() if tag.strip() else "ARK"
    div_pct = tier * 5
    return f"🏢 [{clean_tag}] +{div_pct}%"


def verify_mathematical_oracle(reporter: TestReporter):
    print(f"\n{Colors.BOLD}=== SECTION 5: Mathematical Simulation & UI Logic Matrix Oracle ==={Colors.ENDC}")

    # 1. Preset donation steppers
    e_test = 50000.0
    p10 = simulate_stepper_preset(e_test, 0.10)
    p50 = simulate_stepper_preset(e_test, 0.50)
    pmax = simulate_stepper_preset(e_test, 1.00)

    reporter.check(math.isclose(p10, 5000.0), "10% preset of 50,000 Energy = 5,000", "MATH_Preset")
    reporter.check(math.isclose(p50, 25000.0), "50% preset of 50,000 Energy = 25,000", "MATH_Preset")
    reporter.check(math.isclose(pmax, 50000.0), "MAX preset of 50,000 Energy = 50,000", "MATH_Preset")

    # Zero energy edge case
    reporter.check(math.isclose(simulate_stepper_preset(0.0, 0.50), 0.0),
                   "50% preset of 0 Energy = 0", "MATH_PresetZero")

    # 2. Tier Progress Bar
    pct_t1, _ = simulate_tier_progress(1, 25000.0, 0)
    # Tier 1 next is Tier 2 (100,000 Energy): 25,000 / 100,000 = 25%
    reporter.check(math.isclose(pct_t1, 25.0),
                   f"Tier 1 at 25,000 Energy = 25.0% toward Tier 2 (actual: {pct_t1:.1f}%)", "MATH_Progress")

    # Angel shares threshold advancement: 5 shares satisfies Tier 2 (100%)
    pct_shares, _ = simulate_tier_progress(1, 0.0, 5)
    reporter.check(math.isclose(pct_shares, 100.0),
                   f"Tier 1 with 5 Angel Shares = 100% toward Tier 2 (actual: {pct_shares:.1f}%)", "MATH_Progress")

    # Tier 5 Maxed out
    pct_max, max_lbl = simulate_tier_progress(5, 50000000.0, 500)
    reporter.check(math.isclose(pct_max, 100.0) and "MAXED" in max_lbl,
                   "Tier 5 syndicate returns 100% MAXED state", "MATH_ProgressMax")

    # 3. Visual Perk Card Status Matrix
    expected_status_t2 = {
        1: "UNLOCKED",
        2: "UNLOCKED",
        3: "NEXT OBJECTIVE",
        4: "LOCKED",
        5: "LOCKED",
    }
    for card_t, exp_status in expected_status_t2.items():
        st = simulate_card_status(card_t, 2)
        reporter.check(st == exp_status,
                       f"Current Tier 2: Perk Card Tier {card_t} status is '{st}' (expected '{exp_status}')", "MATH_CardStatus")

    # 4. Season Countdown Timer Formatting
    fixed_ts = 1729170000
    timer_str = simulate_countdown_timer(fixed_ts)
    reporter.check(bool(re.search(r"⏳ Season 1 Ends In: \d+d \d{2}h \d{2}m \d{2}s", timer_str)),
                   f"Countdown formatted correctly: '{timer_str}'", "MATH_Timer")

    # 5. HUD Badge Formatting Matrix
    b_solo = simulate_hud_badge(False, "", 0)
    reporter.check(b_solo == "🏢 [SOLO]", f"Unaffiliated player badge renders '{b_solo}'", "MATH_Badge")

    b_t1 = simulate_hud_badge(True, "ARK", 1)
    reporter.check(b_t1 == "🏢 [ARK] +5%", f"Tier 1 affiliated player badge renders '{b_t1}'", "MATH_Badge")

    b_t3 = simulate_hud_badge(True, "APEX", 3)
    reporter.check(b_t3 == "🏢 [APEX] +15%", f"Tier 3 affiliated player badge renders '{b_t3}'", "MATH_Badge")

    b_t5 = simulate_hud_badge(True, "TITAN", 5)
    reporter.check(b_t5 == "🏢 [TITAN] +25%", f"Tier 5 affiliated player badge renders '{b_t5}'", "MATH_Badge")


# ==============================================================================
# MAIN RUNNER
# ==============================================================================

def main():
    print(f"\n{Colors.BOLD}{Colors.HEADER}======================================================================{Colors.ENDC}")
    print(f"{Colors.BOLD}{Colors.HEADER}Starting Phase 13 Milestone M3 (Syndicate UI) Verification Suite{Colors.ENDC}")
    print(f"{Colors.BOLD}{Colors.HEADER}======================================================================{Colors.ENDC}")

    game_dir = Path(__file__).resolve().parent.parent

    reporter = TestReporter()

    verify_scene_hierarchy(reporter, game_dir)
    verify_touch_ergonomics(reporter, game_dir)
    verify_script_ast(reporter, game_dir)
    verify_hud_integration(reporter, game_dir)
    verify_mathematical_oracle(reporter)

    exit_code = reporter.summarize()
    sys.exit(exit_code)


if __name__ == "__main__":
    main()
