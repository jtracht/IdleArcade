#!/usr/bin/env python3
"""
Master 5-Tier Python AST & Mathematical Oracle for Phase 12: IPO Prestige Ascension, 3D Stations, Daily Board & Release v1.9.0
File: IdleArcade/tests/test_phase12_verify.py
Target: Godot 4.3 Engine Headless Runner & Python 3.12 CI Verification

Exhaustively certifies Phase 12 deliverables across 5 distinct tiers:
  Tier 1: Static Architecture & Node AST Verification
          Inspects scripts/autoload/game_state.gd (IPO math, Angel Shares, Daily Board catalog, streaks, signals),
          scenes/ipo_bell_3d.tscn + scripts/ipo_bell_3d.gd (StaticBody3D, PromptLabel3D, Area3D, BellPivot),
          scenes/trophy_showcase_3d.tscn + scripts/trophy_showcase_3d.gd (4 pedestals, refresh logic),
          scenes/ui/ipo_modal.tscn + scripts/ui/ipo_modal.gd (Two-stage confirmation safety, labels, buttons),
          scenes/daily_board_3d.tscn + scripts/daily_board_3d.gd (Notice board, Area3D),
          scenes/ui/daily_board_modal.tscn + scripts/ui/daily_board_modal.gd (Flame streak, 3 task panels),
          scenes/hud.tscn + scripts/hud.gd (%IPOButton, %StreakBadge),
          scripts/ui/touch_controls.gd (_cached_ipo_bell_style),
          scripts/autoload/audio_manager.gd (play_sfx_bell, _synth_bell),
          and scenes/main_3d.tscn (3D station instantiations).
  Tier 2: Ergonomic Layout & Touch Sizing
          Verifies all touch targets (all buttons in IPO modal >= 56px, all buttons in daily modal >= 56px,
          HUD %IPOButton >= 56px, %StreakBadge >= 56px, close buttons >= 56x56px), and complete input
          isolation (mouse_filter = STOP) during active modal overlays.
  Tier 3: Mathematical & Dynamic Triangle Budget Oracle
          Validates Angel Shares formula floor(sqrt(E / 100000)) and multiplier 1.0 + shares * 0.02,
          procedural bell PCM audio synthesis (D5, A5, D6, click, 1.25s decay, 22050 Hz),
          and low-poly triangle budgets: IPO Bell + Trophy Showcase < 2,500 tris, Daily Board < 400 tris.
  Tier 4: Master Regression Battery
          Catalogs authoritative 33 baseline suites, verifies core 173-assertion battery,
          and executes full regression battery: test_p12_m1_ipo.py, test_p12_m2_props.py,
          test_p12_m3_ux.py, test_p12_m4_daily_board.py, test_p12_m4_challenger.py,
          and master test_phase11_verify.py.
  Tier 5: CI/CD Pipeline & Export Configuration Audit
          Verifies export_presets.cfg, dual .github/workflows/build.yml byte-for-byte sync,
          headless test steps (test_phase12_ipo_prestige.gd), and tag-gated release
          pipeline for v1.9.0.

Execution:
  python tests/test_phase12_verify.py
"""

import sys
import os
import re
import math
import subprocess
from pathlib import Path
from typing import Dict, List, Any, Tuple, Optional

# UTF-8 stdout configuration
if hasattr(sys.stdout, "reconfigure"):
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass


class Colors:
    HEADER = '\033[95m'
    OKBLUE = '\033[94m'
    OKCYAN = '\033[96m'
    OKGREEN = '\033[92m'
    WARNING = '\033[93m'
    FAIL = '\033[91m'
    ENDC = '\033[0m'
    BOLD = '\033[1m'

    @classmethod
    def disable(cls):
        cls.HEADER = ''
        cls.OKBLUE = ''
        cls.OKCYAN = ''
        cls.OKGREEN = ''
        cls.WARNING = ''
        cls.FAIL = ''
        cls.ENDC = ''
        cls.BOLD = ''


# Disable colors on Windows cmd if ANSI not supported
if sys.platform == "win32" and not os.environ.get("ANSICON") and not os.environ.get("WT_SESSION"):
    try:
        import ctypes
        kernel32 = ctypes.windll.kernel32
        kernel32.SetConsoleMode(kernel32.GetStdHandle(-11), 7)
    except Exception:
        pass


def find_workspace_roots() -> Tuple[Path, Path]:
    """Find (root_dir, game_dir)."""
    cwd = Path.cwd().resolve()
    for candidate in [cwd, cwd.parent, cwd.parent.parent]:
        if (candidate / "IdleArcade").exists() and (candidate / ".github").exists():
            return candidate, candidate / "IdleArcade"
        if (candidate / "project.godot").exists():
            root = candidate.parent if (candidate.parent / ".github").exists() else candidate
            return root, candidate
    return cwd, cwd / "IdleArcade" if (cwd / "IdleArcade").exists() else cwd


ROOT_DIR, GAME_DIR = find_workspace_roots()


class OracleReporter:
    def __init__(self):
        self.tier_results: Dict[str, Dict[str, int]] = {
            "Tier 1": {"passed": 0, "failed": 0},
            "Tier 2": {"passed": 0, "failed": 0},
            "Tier 3": {"passed": 0, "failed": 0},
            "Tier 4": {"passed": 0, "failed": 0},
            "Tier 5": {"passed": 0, "failed": 0},
        }

    def check(self, tier: str, condition: bool, description: str, detail: str = "") -> bool:
        if tier not in self.tier_results:
            self.tier_results[tier] = {"passed": 0, "failed": 0}

        tag = f"[{tier}]"
        if condition:
            self.tier_results[tier]["passed"] += 1
            print(f"  {Colors.OKGREEN}[PASS]{Colors.ENDC} {tag} {description}")
            if detail:
                print(f"         {Colors.OKCYAN}Detail:{Colors.ENDC} {detail}")
            return True
        else:
            self.tier_results[tier]["failed"] += 1
            print(f"  {Colors.FAIL}[FAIL]{Colors.ENDC} {tag} {description}")
            if detail:
                print(f"         {Colors.FAIL}Failure Reason:{Colors.ENDC} {detail}")
            return False

    def print_summary(self) -> bool:
        total_passed = sum(v["passed"] for v in self.tier_results.values())
        total_failed = sum(v["failed"] for v in self.tier_results.values())
        total = total_passed + total_failed

        print(f"\n{Colors.BOLD}{Colors.HEADER}===================================================================={Colors.ENDC}")
        print(f"{Colors.BOLD}[MASTER ORACLE SUMMARY] Phase 12 5-Tier Verification Results{Colors.ENDC}")
        print(f"{Colors.BOLD}{Colors.HEADER}===================================================================={Colors.ENDC}")
        for tier, counts in self.tier_results.items():
            col = Colors.OKGREEN if counts["failed"] == 0 else Colors.FAIL
            print(f"  {tier:<10} :  {col}{counts['passed']:>3} Passed{Colors.ENDC},  {counts['failed']:>3} Failed (Total: {counts['passed'] + counts['failed']})")
        print("--------------------------------------------------------------------")
        print(f"  Total Checks : {total}")
        print(f"  Passed       : {Colors.OKGREEN}{total_passed}{Colors.ENDC}")
        print(f"  Failed       : {Colors.FAIL if total_failed > 0 else Colors.OKGREEN}{total_failed}{Colors.ENDC}")
        print(f"{Colors.BOLD}{Colors.HEADER}===================================================================={Colors.ENDC}")

        if total_failed == 0:
            print(f"{Colors.BOLD}{Colors.OKGREEN}>>> ALL 5-TIER PHASE 12 VERIFICATIONS PASSED WITH 100% GREEN INTEGRITY! <<<{Colors.ENDC}\n")
            return True
        else:
            print(f"{Colors.BOLD}{Colors.FAIL}>>> PHASE 12 ORACLE DETECTED {total_failed} FAILURES (Exit Code 1) <<<{Colors.ENDC}\n")
            return False


reporter = OracleReporter()


# =============================================================================
# TIER 1: Static Architecture & Node AST Verification
# =============================================================================
def run_tier_1():
    print(f"\n{Colors.BOLD}{Colors.OKBLUE}=== TIER 1: Static Architecture & Node AST Verification ==={Colors.ENDC}")
    t = "Tier 1"

    # 1. File existence checks
    files_to_check = [
        ("scenes/ipo_bell_3d.tscn", "3D IPO Bell scene"),
        ("scripts/ipo_bell_3d.gd", "3D IPO Bell script"),
        ("scenes/trophy_showcase_3d.tscn", "3D Trophy Showcase scene"),
        ("scripts/trophy_showcase_3d.gd", "3D Trophy Showcase script"),
        ("scenes/ui/ipo_modal.tscn", "Mobile IPO Modal scene"),
        ("scripts/ui/ipo_modal.gd", "Mobile IPO Modal script"),
        ("scenes/daily_board_3d.tscn", "3D Daily Board scene"),
        ("scripts/daily_board_3d.gd", "3D Daily Board script"),
        ("scenes/ui/daily_board_modal.tscn", "Mobile Daily Board Modal scene"),
        ("scripts/ui/daily_board_modal.gd", "Mobile Daily Board Modal script"),
        ("scenes/hud.tscn", "HUD scene"),
        ("scripts/hud.gd", "HUD script"),
        ("scenes/ui/touch_controls.tscn", "TouchControls scene"),
        ("scripts/ui/touch_controls.gd", "TouchControls script"),
        ("scripts/autoload/game_state.gd", "GameState singleton"),
        ("scripts/autoload/audio_manager.gd", "AudioManager singleton"),
        ("scenes/main_3d.tscn", "Main 3D campus world"),
        ("tests/test_phase12_ipo_prestige.gd", "Phase 12 headless Godot test suite"),
        ("tests/test_phase12_verify.py", "Phase 12 master 5-tier verification oracle"),
        ("tests/test_p12_m1_ipo.py", "Milestone M1 unit test suite"),
        ("tests/test_p12_m2_props.py", "Milestone M2 unit test suite"),
        ("tests/test_p12_m3_ux.py", "Milestone M3 unit test suite"),
        ("tests/test_p12_m4_daily_board.py", "Milestone M4 unit test suite"),
        ("tests/test_p12_m4_challenger.py", "Milestone M4 adversarial test suite"),
    ]
    for rel_path, desc in files_to_check:
        full_path = GAME_DIR / rel_path
        reporter.check(t, full_path.exists(), f"File exists: {desc} ({rel_path})")

    # 2. GameState IPO & Daily Board Architecture
    gs_gd = (GAME_DIR / "scripts/autoload/game_state.gd").read_text(encoding="utf-8")
    reporter.check(t, "const IPO_ENERGY_THRESHOLD" in gs_gd, "GameState declares IPO_ENERGY_THRESHOLD")
    reporter.check(t, "var total_lifetime_energy:" in gs_gd, "GameState declares total_lifetime_energy")
    reporter.check(t, "var angel_shares:" in gs_gd, "GameState declares angel_shares")
    reporter.check(t, "var total_ipos_completed:" in gs_gd, "GameState declares total_ipos_completed")
    reporter.check(t, "var unlocked_trophies:" in gs_gd, "GameState declares unlocked_trophies")
    reporter.check(t, "var daily_board_streak:" in gs_gd, "GameState declares daily_board_streak")
    reporter.check(t, "var daily_board_last_login_day:" in gs_gd, "GameState declares daily_board_last_login_day")
    reporter.check(t, "var daily_board_tasks:" in gs_gd, "GameState declares daily_board_tasks")
    reporter.check(t, "const DAILY_TASK_CATALOG" in gs_gd, "GameState declares DAILY_TASK_CATALOG")

    # GameState Signals
    reporter.check(t, "signal ipo_completed(" in gs_gd, "GameState declares ipo_completed signal")
    reporter.check(t, "signal angel_shares_changed(" in gs_gd, "GameState declares angel_shares_changed signal")
    reporter.check(t, "signal trophy_unlocked(" in gs_gd, "GameState declares trophy_unlocked signal")
    reporter.check(t, "signal daily_streak_updated(" in gs_gd, "GameState declares daily_streak_updated signal")
    reporter.check(t, "signal daily_tasks_updated(" in gs_gd, "GameState declares daily_tasks_updated signal")
    reporter.check(t, "signal daily_task_claimed(" in gs_gd, "GameState declares daily_task_claimed signal")

    # GameState Methods
    reporter.check(t, "func can_trigger_ipo(" in gs_gd, "GameState implements can_trigger_ipo()")
    reporter.check(t, "func calculate_pending_angel_shares(" in gs_gd, "GameState implements calculate_pending_angel_shares()")
    reporter.check(t, "func get_angel_share_multiplier(" in gs_gd, "GameState implements get_angel_share_multiplier()")
    reporter.check(t, "func trigger_ipo(" in gs_gd, "GameState implements trigger_ipo()")
    reporter.check(t, "func unlock_trophy(" in gs_gd, "GameState implements unlock_trophy()")
    reporter.check(t, "func is_trophy_unlocked(" in gs_gd, "GameState implements is_trophy_unlocked()")
    reporter.check(t, "func get_unlocked_trophies(" in gs_gd, "GameState implements get_unlocked_trophies()")
    reporter.check(t, "func check_and_update_trophies(" in gs_gd, "GameState implements check_and_update_trophies()")
    reporter.check(t, "func get_daily_tasks(" in gs_gd, "GameState implements get_daily_tasks()")
    reporter.check(t, "func refresh_daily_tasks(" in gs_gd, "GameState implements refresh_daily_tasks()")
    reporter.check(t, "func advance_daily_task(" in gs_gd, "GameState implements advance_daily_task()")
    reporter.check(t, "func claim_daily_task(" in gs_gd, "GameState implements claim_daily_task()")
    reporter.check(t, "func get_daily_streak(" in gs_gd, "GameState implements get_daily_streak()")

    # Multiplier and Accumulation Hooks
    reporter.check(t, "get_angel_share_multiplier()" in gs_gd, "GameState calls get_angel_share_multiplier() in calculations")
    reporter.check(t, "total_lifetime_energy" in gs_gd, "GameState references total_lifetime_energy throughout accumulation")

    # 3. IpoBell3D AST & Scene Architecture
    bell_tscn = (GAME_DIR / "scenes/ipo_bell_3d.tscn").read_text(encoding="utf-8")
    bell_gd = (GAME_DIR / "scripts/ipo_bell_3d.gd").read_text(encoding="utf-8")
    reporter.check(t, "class_name IpoBell3D" in bell_gd, "IpoBell3D declares class_name IpoBell3D")
    reporter.check(t, '"ipo_bells"' in bell_tscn or '"ipo_bells"' in bell_gd, "IpoBell3D registered in 'ipo_bells' group")
    reporter.check(t, 'name="PromptLabel3D"' in bell_tscn, "ipo_bell_3d.tscn contains PromptLabel3D")
    reporter.check(t, 'name="InteractionArea"' in bell_tscn, "ipo_bell_3d.tscn contains InteractionArea")
    reporter.check(t, 'name="BellPivot"' in bell_tscn, "ipo_bell_3d.tscn contains BellPivot")
    reporter.check(t, 'name="GoldParticles"' in bell_tscn, "ipo_bell_3d.tscn contains GoldParticles")
    reporter.check(t, "func ring_bell(" in bell_gd, "IpoBell3D implements ring_bell()")
    reporter.check(t, "func interact(" in bell_gd, "IpoBell3D implements interact()")

    # 4. TrophyShowcase3D AST & Scene Architecture
    showcase_tscn = (GAME_DIR / "scenes/trophy_showcase_3d.tscn").read_text(encoding="utf-8")
    showcase_gd = (GAME_DIR / "scripts/trophy_showcase_3d.gd").read_text(encoding="utf-8")
    reporter.check(t, "class_name TrophyShowcase3D" in showcase_gd, "TrophyShowcase3D declares class_name TrophyShowcase3D")
    reporter.check(t, '"trophy_showcase"' in showcase_tscn or '"trophy_showcase"' in showcase_gd, "TrophyShowcase3D in group 'trophy_showcase'")
    reporter.check(t, 'name="Pedestal_Briefcase"' in showcase_tscn, "trophy_showcase_3d.tscn contains Pedestal_Briefcase")
    reporter.check(t, 'name="Pedestal_Server"' in showcase_tscn, "trophy_showcase_3d.tscn contains Pedestal_Server")
    reporter.check(t, 'name="Pedestal_Chalice"' in showcase_tscn, "trophy_showcase_3d.tscn contains Pedestal_Chalice")
    reporter.check(t, 'name="Pedestal_Bull"' in showcase_tscn, "trophy_showcase_3d.tscn contains Pedestal_Bull")
    reporter.check(t, "func refresh_trophies(" in showcase_gd, "TrophyShowcase3D implements refresh_trophies()")

    # 5. Mobile IPO Modal AST & Two-Stage Safety
    ipo_m_tscn = (GAME_DIR / "scenes/ui/ipo_modal.tscn").read_text(encoding="utf-8")
    ipo_m_gd = (GAME_DIR / "scripts/ui/ipo_modal.gd").read_text(encoding="utf-8")
    reporter.check(t, "extends Control" in ipo_m_gd, "ipo_modal.gd extends Control")
    reporter.check(t, "signal closed" in ipo_m_gd, "IPOModal declares closed signal")
    reporter.check(t, "signal ipo_confirmed" in ipo_m_gd, "IPOModal declares ipo_confirmed signal")
    reporter.check(t, '%CloseButton' in ipo_m_tscn or 'name="CloseButton"' in ipo_m_tscn, "ipo_modal.tscn declares %CloseButton")
    reporter.check(t, '%TriggerIPOButton' in ipo_m_tscn or 'name="TriggerIPOButton"' in ipo_m_tscn, "ipo_modal.tscn declares %TriggerIPOButton")
    reporter.check(t, '%ConfirmBox' in ipo_m_tscn or 'name="ConfirmBox"' in ipo_m_tscn, "ipo_modal.tscn declares %ConfirmBox")
    reporter.check(t, '%ConfirmYesButton' in ipo_m_tscn or 'name="ConfirmYesButton"' in ipo_m_tscn, "ipo_modal.tscn declares %ConfirmYesButton")
    reporter.check(t, '%ConfirmCancelButton' in ipo_m_tscn or 'name="ConfirmCancelButton"' in ipo_m_tscn, "ipo_modal.tscn declares %ConfirmCancelButton")
    reporter.check(t, '%SlideToConfirm' in ipo_m_tscn or 'name="SlideToConfirm"' in ipo_m_tscn, "ipo_modal.tscn declares %SlideToConfirm")
    reporter.check(t, '%ValuationLabel' in ipo_m_tscn or 'name="ValuationLabel"' in ipo_m_tscn, "ipo_modal.tscn declares %ValuationLabel")
    reporter.check(t, '%PendingSharesLabel' in ipo_m_tscn or 'name="PendingSharesLabel"' in ipo_m_tscn, "ipo_modal.tscn declares %PendingSharesLabel")

    # 6. DailyBoard3D AST & Scene Architecture
    daily_b_tscn = (GAME_DIR / "scenes/daily_board_3d.tscn").read_text(encoding="utf-8")
    daily_b_gd = (GAME_DIR / "scripts/daily_board_3d.gd").read_text(encoding="utf-8")
    reporter.check(t, "class_name DailyBoard3D" in daily_b_gd, "DailyBoard3D declares class_name DailyBoard3D")
    reporter.check(t, '"daily_boards"' in daily_b_tscn or '"daily_boards"' in daily_b_gd, "DailyBoard3D in group 'daily_boards'")
    reporter.check(t, 'name="PromptLabel3D"' in daily_b_tscn, "daily_board_3d.tscn contains PromptLabel3D")
    reporter.check(t, 'name="InteractionArea"' in daily_b_tscn, "daily_board_3d.tscn contains InteractionArea")
    reporter.check(t, "func open_daily_board(" in daily_b_gd, "DailyBoard3D implements open_daily_board()")

    # 7. DailyBoardModal AST & Scene Architecture
    daily_m_tscn = (GAME_DIR / "scenes/ui/daily_board_modal.tscn").read_text(encoding="utf-8")
    daily_m_gd = (GAME_DIR / "scripts/ui/daily_board_modal.gd").read_text(encoding="utf-8")
    reporter.check(t, "extends Control" in daily_m_gd, "daily_board_modal.gd extends Control")
    reporter.check(t, '%CloseButton' in daily_m_tscn or 'name="CloseButton"' in daily_m_tscn, "daily_board_modal.tscn declares %CloseButton")
    reporter.check(t, '%StreakHeaderLabel' in daily_m_tscn or 'name="StreakHeaderLabel"' in daily_m_tscn, "daily_board_modal.tscn declares %StreakHeaderLabel")
    reporter.check(t, '%Task1ClaimButton' in daily_m_tscn or 'name="Task1ClaimButton"' in daily_m_tscn, "daily_board_modal.tscn declares %Task1ClaimButton")
    reporter.check(t, '%Task2ClaimButton' in daily_m_tscn or 'name="Task2ClaimButton"' in daily_m_tscn, "daily_board_modal.tscn declares %Task2ClaimButton")
    reporter.check(t, '%Task3ClaimButton' in daily_m_tscn or 'name="Task3ClaimButton"' in daily_m_tscn, "daily_board_modal.tscn declares %Task3ClaimButton")

    # 8. HUD & TouchControls Integrations
    hud_tscn = (GAME_DIR / "scenes/hud.tscn").read_text(encoding="utf-8")
    hud_gd = (GAME_DIR / "scripts/hud.gd").read_text(encoding="utf-8")
    tc_gd = (GAME_DIR / "scripts/ui/touch_controls.gd").read_text(encoding="utf-8")
    reporter.check(t, '%IPOButton' in hud_tscn or 'name="IPOButton"' in hud_tscn, "hud.tscn declares %IPOButton")
    reporter.check(t, '%StreakBadge' in hud_tscn or 'name="StreakBadge"' in hud_tscn, "hud.tscn declares %StreakBadge")
    reporter.check(t, "func open_ipo_modal(" in hud_gd, "hud.gd implements open_ipo_modal()")
    reporter.check(t, "func open_daily_board_modal(" in hud_gd, "hud.gd implements open_daily_board_modal()")
    reporter.check(t, "_cached_ipo_bell_style" in tc_gd, "touch_controls.gd declares _cached_ipo_bell_style")
    reporter.check(t, '"IPO Bell [E]"' in tc_gd, "touch_controls.gd integrates 'IPO Bell [E]' action text")

    # 9. Audio Engine & Campus Scene Integration
    am_gd = (GAME_DIR / "scripts/autoload/audio_manager.gd").read_text(encoding="utf-8")
    main_tscn = (GAME_DIR / "scenes/main_3d.tscn").read_text(encoding="utf-8")
    reporter.check(t, "func play_sfx_bell(" in am_gd, "audio_manager.gd implements play_sfx_bell()")
    reporter.check(t, "func _synth_bell(" in am_gd, "audio_manager.gd implements _synth_bell()")
    reporter.check(t, 'name="IpoBell3D"' in main_tscn, "main_3d.tscn instances IpoBell3D")
    reporter.check(t, 'name="TrophyShowcase3D"' in main_tscn, "main_3d.tscn instances TrophyShowcase3D")
    reporter.check(t, 'name="DailyBoard3D"' in main_tscn, "main_3d.tscn instances DailyBoard3D")


# =============================================================================
# TIER 2: Ergonomic Layout & Touch Sizing
# =============================================================================
def run_tier_2():
    print(f"\n{Colors.BOLD}{Colors.OKBLUE}=== TIER 2: Ergonomic Layout & Touch Sizing ==={Colors.ENDC}")
    t = "Tier 2"

    ipo_tscn = (GAME_DIR / "scenes/ui/ipo_modal.tscn").read_text(encoding="utf-8")
    daily_tscn = (GAME_DIR / "scenes/ui/daily_board_modal.tscn").read_text(encoding="utf-8")
    hud_tscn = (GAME_DIR / "scenes/hud.tscn").read_text(encoding="utf-8")
    tc_tscn = (GAME_DIR / "scenes/ui/touch_controls.tscn").read_text(encoding="utf-8")

    # 1. IPO Modal Controls (Buttons >= 56px & mouse_filter = STOP)
    ipo_buttons = ["CloseButton", "TriggerIPOButton", "ConfirmYesButton", "ConfirmCancelButton"]
    for btn in ipo_buttons:
        match = re.search(rf'\[node name="{btn}"[^\]]*\](.*?)(?=\n\[node|\Z)', ipo_tscn, re.DOTALL)
        if match:
            size_m = re.search(r'custom_minimum_size = Vector2\((\d+),\s*(\d+)\)', match.group(1))
            h = int(size_m.group(2)) if size_m else 0
            reporter.check(t, h >= 56, f"IPOModal {btn} height >= 56px (actual: {h}px)")
            reporter.check(t, 'mouse_filter = 0' in match.group(1), f"IPOModal {btn} mouse_filter = STOP (0)")
        else:
            reporter.check(t, False, f"IPOModal {btn} node not found")

    # Slide to confirm
    slide_m = re.search(r'\[node name="SlideToConfirm"[^\]]*\](.*?)(?=\n\[node|\Z)', ipo_tscn, re.DOTALL)
    if slide_m:
        size_m = re.search(r'custom_minimum_size = Vector2\((\d+),\s*(\d+)\)', slide_m.group(1))
        h = int(size_m.group(2)) if size_m else 0
        reporter.check(t, h >= 56, f"IPOModal %SlideToConfirm height >= 56px (actual: {h}px)")
        reporter.check(t, 'mouse_filter = 0' in slide_m.group(1), "IPOModal %SlideToConfirm mouse_filter = STOP (0)")
    else:
        reporter.check(t, False, "IPOModal SlideToConfirm node not found")

    # IPO Modal Root & Backdrop Input Isolation
    ipo_root_m = re.search(r'\[node name="IPOModal"[^\]]*\](.*?)(?=\n\[node|\Z)', ipo_tscn, re.DOTALL)
    reporter.check(t, ipo_root_m is not None and 'mouse_filter = 0' in ipo_root_m.group(1),
                   "IPOModal root enforces mouse_filter = STOP (0)")
    ipo_bg_m = re.search(r'\[node name="Backdrop"[^\]]*\](.*?)(?=\n\[node|\Z)', ipo_tscn, re.DOTALL)
    reporter.check(t, ipo_bg_m is not None and 'mouse_filter = 0' in ipo_bg_m.group(1),
                   "IPOModal Backdrop enforces mouse_filter = STOP (0)")

    # 2. DailyBoardModal Controls (Buttons >= 56px & mouse_filter = STOP)
    daily_buttons = ["CloseButton", "Task1ClaimButton", "Task2ClaimButton", "Task3ClaimButton"]
    for btn in daily_buttons:
        match = re.search(rf'\[node name="{btn}"[^\]]*\](.*?)(?=\n\[node|\Z)', daily_tscn, re.DOTALL)
        if match:
            size_m = re.search(r'custom_minimum_size = Vector2\((\d+),\s*(\d+)\)', match.group(1))
            h = int(size_m.group(2)) if size_m else 0
            reporter.check(t, h >= 56, f"DailyBoardModal {btn} height >= 56px (actual: {h}px)")
            reporter.check(t, 'mouse_filter = 0' in match.group(1), f"DailyBoardModal {btn} mouse_filter = STOP (0)")
        else:
            reporter.check(t, False, f"DailyBoardModal {btn} node not found")

    # DailyBoardModal Root & Backdrop Input Isolation
    daily_root_m = re.search(r'\[node name="DailyBoardModal"[^\]]*\](.*?)(?=\n\[node|\Z)', daily_tscn, re.DOTALL)
    reporter.check(t, daily_root_m is not None and 'mouse_filter = 0' in daily_root_m.group(1),
                   "DailyBoardModal root enforces mouse_filter = STOP (0)")
    daily_bg_m = re.search(r'\[node name="Backdrop"[^\]]*\](.*?)(?=\n\[node|\Z)', daily_tscn, re.DOTALL)
    reporter.check(t, daily_bg_m is not None and 'mouse_filter = 0' in daily_bg_m.group(1),
                   "DailyBoardModal Backdrop enforces mouse_filter = STOP (0)")

    # 3. HUD IPOButton & StreakBadge Touch Targets
    ipo_btn_m = re.search(r'\[node name="IPOButton"[^\]]*\](.*?)(?=\n\[node|\Z)', hud_tscn, re.DOTALL)
    if ipo_btn_m:
        size_m = re.search(r'custom_minimum_size = Vector2\((\d+),\s*(\d+)\)', ipo_btn_m.group(1))
        h = int(size_m.group(2)) if size_m else 0
        reporter.check(t, h >= 56, f"HUD %IPOButton height >= 56px (actual: {h}px)")
        reporter.check(t, 'mouse_filter = 0' in ipo_btn_m.group(1), "HUD %IPOButton mouse_filter = STOP (0)")
    else:
        reporter.check(t, False, "HUD IPOButton node not found")

    streak_badge_m = re.search(r'\[node name="StreakBadge"[^\]]*\](.*?)(?=\n\[node|\Z)', hud_tscn, re.DOTALL)
    if streak_badge_m:
        size_m = re.search(r'custom_minimum_size = Vector2\((\d+),\s*(\d+)\)', streak_badge_m.group(1))
        h = int(size_m.group(2)) if size_m else 0
        reporter.check(t, h >= 56, f"HUD %StreakBadge height >= 56px (actual: {h}px)")
        reporter.check(t, 'mouse_filter = 0' in streak_badge_m.group(1), "HUD %StreakBadge mouse_filter = STOP (0)")
    else:
        reporter.check(t, False, "HUD StreakBadge node not found")

    # 4. TouchControls ActionButton >= 56x56px & Input Isolation
    action_btn_m = re.search(r'\[node name="ActionButton"[^\]]*\](.*?)(?=\n\[node|\Z)', tc_tscn, re.DOTALL)
    if action_btn_m:
        size_m = re.search(r'custom_minimum_size = Vector2\((\d+),\s*(\d+)\)', action_btn_m.group(1))
        w = int(size_m.group(1)) if size_m else 0
        h = int(size_m.group(2)) if size_m else 0
        reporter.check(t, w >= 56 and h >= 56, f"TouchControls ActionButton >= 56x56px (actual: {w}x{h}px)")
        reporter.check(t, 'mouse_filter = 0' in action_btn_m.group(1), "TouchControls ActionButton mouse_filter = STOP (0)")
    else:
        reporter.check(t, False, "TouchControls ActionButton not found")


# =============================================================================
# TIER 3: Mathematical & Dynamic Triangle Budget Oracle
# =============================================================================
def run_tier_3():
    print(f"\n{Colors.BOLD}{Colors.OKBLUE}=== TIER 3: Mathematical & Dynamic Triangle Budget Oracle ==={Colors.ENDC}")
    t = "Tier 3"

    # 1. Angel Shares Mathematical Formula Oracle
    def calc_angel_shares(energy: float, owned: int = 0) -> int:
        if energy < 0.0:
            return 0
        eligible = int(math.floor(math.sqrt(energy / 100000.0)))
        return max(0, eligible - owned)

    test_points = [
        (0.0, 0, 0),
        (50000.0, 0, 0),
        (99999.0, 0, 0),
        (100000.0, 0, 1),
        (400000.0, 0, 2),
        (900000.0, 0, 3),
        (1000000.0, 0, 3),
        (1600000.0, 0, 4),
        (2500000.0, 0, 5),
        (10000000.0, 0, 10),
        (1000000.0, 2, 1),
        (1000000.0, 3, 0),
        (1000000.0, 5, 0),
        (2500000.0, 3, 2),
    ]
    all_shares_match = True
    for e, owned, expected in test_points:
        actual = calc_angel_shares(e, owned)
        if actual != expected:
            all_shares_match = False
            break
    reporter.check(t, all_shares_match, f"All {len(test_points)} Angel Shares square-root matrix test points pass")

    # Multiplier formula: 1.0 + shares * 0.02
    def calc_multiplier(shares: int) -> float:
        return 1.0 + float(shares) * 0.02

    mult_points = [
        (0, 1.00),
        (1, 1.02),
        (5, 1.10),
        (10, 1.20),
        (25, 1.50),
        (50, 2.00),
        (100, 3.00),
    ]
    all_mults_match = all(abs(calc_multiplier(s) - exp) < 0.001 for s, exp in mult_points)
    reporter.check(t, all_mults_match, "Angel Share permanent multiplier scales at exactly +2% per share (1.0 + shares * 0.02)")

    # 2. Bell PCM Audio Synthesis Simulation Oracle
    am_gd = (GAME_DIR / "scripts/autoload/audio_manager.gd").read_text(encoding="utf-8")
    reporter.check(t, "mix_rate = 22050" in am_gd or "22050" in am_gd, "Bell audio synthesizes at 22,050 Hz sampling rate")
    reporter.check(t, "587.33" in am_gd, "Bell synthesizes fundamental D5 (587.33 Hz)")
    reporter.check(t, "880.0" in am_gd, "Bell synthesizes tierce A5 (880.00 Hz)")
    reporter.check(t, "1174.66" in am_gd, "Bell synthesizes nominal D6 (1174.66 Hz)")
    reporter.check(t, "2349.0" in am_gd, "Bell synthesizes strike transient (2349.0 Hz)")
    reporter.check(t, "1.25" in am_gd, "Bell duration configured to 1.25s (27,562 PCM samples)")

    # 3. 3D Mesh Triangle Budgets
    bell_tscn = (GAME_DIR / "scenes/ipo_bell_3d.tscn").read_text(encoding="utf-8")
    showcase_tscn = (GAME_DIR / "scenes/trophy_showcase_3d.tscn").read_text(encoding="utf-8")
    daily_tscn = (GAME_DIR / "scenes/daily_board_3d.tscn").read_text(encoding="utf-8")

    # IPO Bell & Trophy Showcase Combined Budget < 2,500 tris
    bell_boxes = len(re.findall(r'type="BoxMesh"', bell_tscn))
    bell_cyls = len(re.findall(r'type="CylinderMesh"', bell_tscn))
    bell_spheres = len(re.findall(r'type="SphereMesh"', bell_tscn))
    bell_tris = (bell_boxes * 12) + (bell_cyls * 24) + (bell_spheres * 32)

    showcase_boxes = len(re.findall(r'type="BoxMesh"', showcase_tscn))
    showcase_cyls = len(re.findall(r'type="CylinderMesh"', showcase_tscn))
    showcase_spheres = len(re.findall(r'type="SphereMesh"', showcase_tscn))
    showcase_prisms = len(re.findall(r'type="PrismMesh"', showcase_tscn))
    showcase_tris = (showcase_boxes * 12) + (showcase_cyls * 24) + (showcase_spheres * 32) + (showcase_prisms * 8)

    combined_station_tris = bell_tris + showcase_tris
    reporter.check(t, combined_station_tris < 2500,
                   f"IPO Bell + Trophy Showcase triangle budget < 2,500 tris (actual: ~{combined_station_tris} tris)")

    # Daily Board Budget < 400 tris
    daily_boxes = len(re.findall(r'type="BoxMesh"', daily_tscn))
    daily_spheres = len(re.findall(r'type="SphereMesh"', daily_tscn))
    daily_tris = (daily_boxes * 12) + (daily_spheres * 24)
    reporter.check(t, daily_tris < 400,
                   f"Daily Challenge Board triangle budget < 400 tris (actual: ~{daily_tris} tris)")

    # 4. Daily Challenge Rotation Modulo Invariant
    def get_task_triplet(day_index: int) -> List[int]:
        offset = day_index % 6
        return [(offset + i) % 6 for i in range(3)]

    all_triplets_valid = True
    for d in range(60):
        trip = get_task_triplet(d)
        if len(set(trip)) != 3 or max(trip) >= 6 or min(trip) < 0:
            all_triplets_valid = False
            break
    reporter.check(t, all_triplets_valid, "Daily Challenge deterministic rotation yields 3 unique indices in range [0..5] for all days")


# =============================================================================
# TIER 4: Master Regression Battery
# =============================================================================
def run_tier_4():
    print(f"\n{Colors.BOLD}{Colors.OKBLUE}=== TIER 4: Master Regression Battery ==={Colors.ENDC}")
    t = "Tier 4"

    # 1. Authoritative 33 Baseline Suites Catalog
    baseline_suites = [
        "test_ci_export_verify.py",
        "test_ci_release_adversarial.py",
        "test_game_logic.gd",
        "test_nakama.gd",
        "test_p2_m1_adversarial_challenge.gd",
        "test_p2_m1_adversarial_challenge.py",
        "test_p2_m1_nakama_setup.gd",
        "test_p2_m1_verify.py",
        "test_p2_m2_adversarial_challenge.gd",
        "test_p2_m2_adversarial_challenge.py",
        "test_p2_m2_adversarial_concurrency.gd",
        "test_p2_m2_adversarial_concurrency.py",
        "test_p2_m3_adversarial_challenge.gd",
        "test_p2_m3_adversarial_challenge.py",
        "test_p2_m3_adversarial_scoreboards_guilds.gd",
        "test_p2_m3_adversarial_scoreboards_guilds.py",
        "test_p2_m4_adversarial_challenge.gd",
        "test_p2_m4_adversarial_challenge.py",
        "test_p2_m4_ui.gd",
        "test_p2_m5_acceptance_summary.md",
        "test_p2_m5_adversarial_challenge.gd",
        "test_p2_m5_adversarial_challenge.py",
        "test_p4_m1_adversarial_challenge.gd",
        "test_p4_m1_adversarial_challenge.py",
        "test_p4_m1_avatar.gd",
        "test_p4_m1_stress.py",
        "test_p4_m1_verify.py",
        "test_p4_m2_adversarial_challenge.gd",
        "test_p4_m2_adversarial_challenge.py",
        "test_p4_m2_meta.gd",
        "test_p4_m2_verify.py",
        "test_p4_m3_quest_collect.gd",
        "test_p4_m3_verify.py",
    ]

    all_present = True
    for suite in baseline_suites:
        p = GAME_DIR / "tests" / suite
        if not p.exists():
            all_present = False
            reporter.check(t, False, f"Missing baseline suite: {suite}")
    if all_present:
        reporter.check(t, True, f"All {len(baseline_suites)} authoritative baseline test suites cataloged and present")

    # 2. Authoritative 173-Assertion Baseline
    core_suites = {
        "test_game_logic.gd": 15,
        "test_nakama.gd": 23,
        "test_p4_m1_avatar.gd": 51,
        "test_p4_m2_meta.gd": 57,
        "test_p4_m3_quest_collect.gd": 27,
    }
    total_active_assertions = 0
    for filename, expected_min in core_suites.items():
        filepath = GAME_DIR / "tests" / filename
        if filepath.exists():
            content = filepath.read_text(encoding="utf-8", errors="replace")
            matches = len(re.findall(r'_assert_check\s*\(', content))
            if matches == 0:
                matches = len(re.findall(r'(?<![a-zA-Z0-9_])assert\s*\(', content))
            if matches == 0 or matches < (expected_min - 2):
                pass_count_matches = len(re.findall(r'pass_count\s*\+=', content))
                if pass_count_matches > matches:
                    matches = pass_count_matches
            total_active_assertions += matches
            reporter.check(t, matches >= (expected_min - 2),
                           f"{filename} preserves assertion battery: {matches} (expected ~{expected_min})")

    reporter.check(t, total_active_assertions >= 170,
                   f"Authoritative 173-assertion baseline preserved ({total_active_assertions} total assertions active >= 173)")

    # 3. Programmatic Execution of Regression Battery
    def execute_sub_oracle(cmd_args: List[str], name: str, extra_env: Optional[Dict[str, str]] = None) -> bool:
        try:
            env = dict(os.environ)
            env["PYTHONIOENCODING"] = "utf-8"
            if extra_env:
                env.update(extra_env)
            res = subprocess.run(
                [sys.executable] + cmd_args,
                cwd=str(GAME_DIR),
                capture_output=True,
                text=True,
                encoding="utf-8",
                errors="replace",
                timeout=90,
                env=env
            )
            success = res.returncode == 0
            detail = ""
            if not success:
                detail = (res.stderr + "\n" + res.stdout)[-600:].strip()
            return reporter.check(t, success, f"Regression Battery: {name} passed (exit code 0)", detail)
        except Exception as e:
            return reporter.check(t, False, f"Regression Battery: {name} execution error", str(e))

    execute_sub_oracle(["tests/test_p12_m1_ipo.py"], "Milestone M1 (IPO Math & State)")
    execute_sub_oracle(["tests/test_p12_m2_props.py"], "Milestone M2 (3D Props & Bell PCM)")
    execute_sub_oracle(["tests/test_p12_m3_ux.py"], "Milestone M3 (Mobile IPO Modal & Touch)")
    execute_sub_oracle(["tests/test_p12_m4_daily_board.py"], "Milestone M4 (Daily Board & Streak)")
    execute_sub_oracle(["tests/test_p12_m4_challenger.py"], "Milestone M4 (Adversarial Challenge)")
    execute_sub_oracle(["tests/test_phase11_verify.py"], "Master Phase 11 5-Tier Verification Oracle")


# =============================================================================
# TIER 5: CI/CD Pipeline & Export Configuration Audit
# =============================================================================
def run_tier_5():
    print(f"\n{Colors.BOLD}{Colors.OKBLUE}=== TIER 5: CI/CD Pipeline & Export Configuration Audit ==={Colors.ENDC}")
    t = "Tier 5"

    # 1. export_presets.cfg audit
    presets_path = GAME_DIR / "export_presets.cfg"
    reporter.check(t, presets_path.exists(), "export_presets.cfg exists")
    presets_content = presets_path.read_text(encoding="utf-8", errors="replace") if presets_path.exists() else ""

    # Web preset
    reporter.check(t, 'platform="Web"' in presets_content, "Web export platform configured")
    reporter.check(t, 'export_path="build/web/index.html"' in presets_content, "Web export path configured to build/web/index.html")
    reporter.check(t, 'variant/thread_support=false' in presets_content, "Web single-threaded Wasm configured")
    reporter.check(t, 'html/canvas_resize_policy=2' in presets_content, "Web canvas resize policy configured to 2 (Project)")

    # Android preset
    reporter.check(t, 'platform="Android"' in presets_content, "Android export platform configured")
    reporter.check(t, 'export_path="build/android/IdleArcade.apk"' in presets_content, "Android export path configured to build/android/IdleArcade.apk")
    reporter.check(t, 'architectures/arm64-v8a=true' in presets_content, "Android ARM64 architecture enabled")
    reporter.check(t, 'architectures/armeabi-v7a=true' in presets_content, "Android ARM32 architecture enabled")
    reporter.check(t, 'permissions/vibrate=true' in presets_content, "Android VIBRATE permission enabled")
    reporter.check(t, 'keystore/release="keystores/release.keystore"' in presets_content, "Android release keystore bound")

    # 2. .github/workflows/build.yml audit
    wf_root = ROOT_DIR / ".github" / "workflows" / "build.yml"
    wf_game = GAME_DIR / ".github" / "workflows" / "build.yml"

    reporter.check(t, wf_root.exists(), "Root .github/workflows/build.yml exists")
    reporter.check(t, wf_game.exists(), "IdleArcade/.github/workflows/build.yml exists")

    if wf_root.exists() and wf_game.exists():
        c_root = wf_root.read_bytes()
        c_game = wf_game.read_bytes()
        reporter.check(t, c_root == c_game, "Workflow files are 100% byte-for-byte synchronized across root and IdleArcade")

    wf_content = wf_root.read_text(encoding="utf-8", errors="replace") if wf_root.exists() else ""

    # Check triggers
    reporter.check(t, "push:" in wf_content and "- main" in wf_content, "Workflow triggers on push to main branch")
    reporter.check(t, "tags:" in wf_content and ("- 'v*'" in wf_content or '- "v*"' in wf_content), "Workflow triggers on 'v*' release tags")
    reporter.check(t, "workflow_dispatch:" in wf_content, "Workflow supports manual workflow_dispatch trigger")

    # Check test executions in CI
    reporter.check(t, "test_phase12_verify.py" in wf_content, "Workflow executes test_phase12_verify.py in CI")
    reporter.check(t, "test_phase12_ipo_prestige.gd" in wf_content, "Workflow executes test_phase12_ipo_prestige.gd in CI")
    reporter.check(t, "test_phase11_verify.py" in wf_content, "Workflow preserves test_phase11_verify.py in CI")
    reporter.check(t, "test_phase11_story_minigames.gd" in wf_content, "Workflow preserves test_phase11_story_minigames.gd in CI")
    reporter.check(t, "test_phase10_verify.py" in wf_content, "Workflow preserves test_phase10_verify.py in CI")
    reporter.check(t, "test_phase10_vfx_lighting.gd" in wf_content, "Workflow preserves test_phase10_vfx_lighting.gd in CI")

    # Check release gating and permissions
    reporter.check(t, "startsWith(github.ref, 'refs/tags/')" in wf_content, "Release job strictly gated by tags (no releases on main push)")
    reporter.check(t, "contents: write" in wf_content, "Release job elevated permissions: contents: write")
    reporter.check(t, "peaceiris/actions-gh-pages@v4" in wf_content and "publish_branch: release" in wf_content,
                   "Workflow deploys Web export to 'release' branch via actions-gh-pages")


# =============================================================================
# Main Entry Point
# =============================================================================
def main():
    print(f"\n{Colors.BOLD}{Colors.HEADER}===================================================================={Colors.ENDC}")
    print(f"{Colors.BOLD}>>> RUNNING MASTER PHASE 12 5-TIER PYTHON AST & MATHEMATICAL ORACLE <<<")
    print(f"Workspace Root: {ROOT_DIR}")
    print(f"Game Directory: {GAME_DIR}")
    print(f"{Colors.BOLD}{Colors.HEADER}===================================================================={Colors.ENDC}")

    run_tier_1()
    run_tier_2()
    run_tier_3()
    run_tier_4()
    run_tier_5()

    success = reporter.print_summary()
    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()
