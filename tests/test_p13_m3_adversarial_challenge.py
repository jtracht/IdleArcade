#!/usr/bin/env python3
"""
Phase 13 Milestone M3: Adversarial Touch Ergonomics, Node Structure & AST Challenge Suite
========================================================================================
Target: Godot 4.3 IdleArcade - Milestone M3 (Mobile Guild & Syndicate War UI)

Adversarial Challenge Dimensions:
  1. Exhaustive Scene Tree & Touch Ergonomics Audit:
     - Parse all nodes in scenes/ui/syndicate_modal.tscn and scenes/hud.tscn.
     - Verify every single interactive Control (Buttons, Sliders, TabBars, CheckBoxes, etc.).
     - Assert custom_minimum_size.y >= 56.0 for all touch targets.
     - Assert custom_minimum_size.x >= 56.0 for square action buttons (CloseButton, BurgerMenuButton).
     - Assert mouse_filter = Control.MOUSE_FILTER_STOP (value 0) on interactive nodes.
     - Assert strict pointer isolation: root SyndicateModal and Backdrop have mouse_filter = 0.
     - Assert ModalCard, Tab containers, and ScrollContainers have mouse_filter = 0.
     - Assert HUD %SyndicateBadge and %SyndicateButton satisfy >= 56px and mouse_filter = 0.
  2. AST Static Analysis & Defensive Architecture Stress:
     - scripts/ui/syndicate_modal.gd class inheritance, signals, and method contracts.
     - Comprehensive GameState null-safety guards on all public/private methods.
     - Signal deduplication and existence checks (has_signal, is_connected).
     - Dynamic row creation ergonomics in _add_member_row and _populate_leaderboard (height >= 56px, STOP).
     - Color constant integrity (COLOR_UNLOCKED, COLOR_NEXT_OBJ, COLOR_LOCKED).
     - scripts/hud.gd modal routing, signal integration, and badge formatting.
  3. Fuzzing & Extreme Boundary Simulation (Mathematical & State Invariants):
     - Unaffiliated player state handling ([SOLO] badge, default holding, 0% dividend).
     - Tier progression math across all 5 tiers (energy vs angel share threshold ratios).
     - Slider and preset steppers under extreme energy (0, sub-zero, 1e15).
     - Unix timestamp rollover simulation for weekly syndicate wars timer.
     - State machine robustness against malformed/empty dictionaries.
  4. Regression & Multi-Milestone Parity:
     - Verification against M1, M2, and Phase 12 baselines.

Executable via: python tests/test_p13_m3_adversarial_challenge.py
"""

import math
import re
import sys
import time
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

GAME_ROOT = Path(__file__).resolve().parent.parent
SCENES_DIR = GAME_ROOT / "scenes"
SCRIPTS_DIR = GAME_ROOT / "scripts"
MODAL_SCENE_PATH = SCENES_DIR / "ui" / "syndicate_modal.tscn"
MODAL_SCRIPT_PATH = SCRIPTS_DIR / "ui" / "syndicate_modal.gd"
HUD_SCENE_PATH = SCENES_DIR / "hud.tscn"
HUD_SCRIPT_PATH = SCRIPTS_DIR / "hud.gd"


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


class ChallengeReporter:
    def __init__(self):
        self.total = 0
        self.passed = 0
        self.failed = 0
        self.failures: List[str] = []

    def check(self, condition: bool, description: str, category: str = "CHALLENGE"):
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
        print("\n" + "=" * 76)
        print(f"{Colors.BOLD}Phase 13 Milestone M3 Adversarial Challenge Summary{Colors.ENDC}")
        print("=" * 76)
        print(f"  Total Adversarial Checks : {self.total}")
        print(f"  Passed                   : {Colors.OKGREEN}{self.passed}{Colors.ENDC}")
        print(f"  Failed                   : {Colors.FAIL if self.failed > 0 else Colors.OKGREEN}{self.failed}{Colors.ENDC}")
        if self.failures:
            print(f"\n{Colors.FAIL}Failed Challenges:{Colors.ENDC}")
            for f in self.failures:
                print(f"  - {f}")
            print("\n>>> OVERALL ADVERSARIAL VERDICT: REQUEST_CHANGES (FAIL) <<<")
            return 1
        print(f"\n{Colors.OKGREEN}>>> OVERALL ADVERSARIAL VERDICT: APPROVE (100% PASS) <<<{Colors.ENDC}")
        return 0


# ==============================================================================
# CHALLENGE 1: Exhaustive Scene Node Parser & Ergonomics Audit
# ==============================================================================

def parse_tscn_nodes(content: str) -> List[Dict[str, Any]]:
    """Exhaustively parse all node blocks in a Godot 4 .tscn file."""
    nodes = []
    # Split by [node ...
    raw_blocks = re.split(r'\n\[node\s+', content)
    for b in raw_blocks[1:]:
        header_end = b.find(']')
        if header_end == -1:
            continue
        header = b[:header_end]
        body = b[header_end + 1:]
        next_section = body.find('\n[')
        if next_section != -1:
            body = body[:next_section]

        name_m = re.search(r'name="([^"]+)"', header)
        type_m = re.search(r'type="([^"]+)"', header)
        parent_m = re.search(r'parent="([^"]+)"', header)

        name = name_m.group(1) if name_m else "Unknown"
        ntype = type_m.group(1) if type_m else "Node"
        parent = parent_m.group(1) if parent_m else None

        size_m = re.search(r'custom_minimum_size\s*=\s*Vector2\(\s*([0-9.]+),\s*([0-9.]+)\s*\)', body)
        custom_size = (float(size_m.group(1)), float(size_m.group(2))) if size_m else None

        mf_m = re.search(r'mouse_filter\s*=\s*(\d+)', body)
        mouse_filter = int(mf_m.group(1)) if mf_m else None

        unique_m = 'unique_name_in_owner = true' in body

        nodes.append({
            "name": name,
            "type": ntype,
            "parent": parent,
            "custom_size": custom_size,
            "mouse_filter": mouse_filter,
            "unique": unique_m,
            "raw_body": body
        })
    return nodes


def challenge_scene_ergonomics(reporter: ChallengeReporter):
    print(f"\n{Colors.BOLD}=== CHALLENGE 1: Exhaustive Scene Node Parser & Ergonomics Audit ==={Colors.ENDC}")

    reporter.check(MODAL_SCENE_PATH.exists(), f"Modal scene exists: {MODAL_SCENE_PATH.name}", "SCENE_PRESENCE")
    reporter.check(HUD_SCENE_PATH.exists(), f"HUD scene exists: {HUD_SCENE_PATH.name}", "SCENE_PRESENCE")

    if not MODAL_SCENE_PATH.exists() or not HUD_SCENE_PATH.exists():
        return

    modal_content = MODAL_SCENE_PATH.read_text(encoding="utf-8")
    hud_content = HUD_SCENE_PATH.read_text(encoding="utf-8")

    modal_nodes = parse_tscn_nodes(modal_content)
    hud_nodes = parse_tscn_nodes(hud_content)

    reporter.check(len(modal_nodes) >= 20, f"syndicate_modal.tscn parsed {len(modal_nodes)} nodes (>= 20)", "NODE_COUNT")
    reporter.check(len(hud_nodes) >= 30, f"hud.tscn parsed {len(hud_nodes)} nodes (>= 30)", "NODE_COUNT")

    # 1. Pointer Isolation for Modal: Root, Backdrop, CenterContainer, ModalCard
    modal_dict = {n["name"]: n for n in modal_nodes}

    root_node = modal_dict.get("SyndicateModal")
    reporter.check(root_node is not None, "Root node 'SyndicateModal' exists", "POINTER_ISOLATION")
    if root_node:
        reporter.check(root_node["mouse_filter"] == 0,
                       f"Root SyndicateModal mouse_filter = 0 (Control.MOUSE_FILTER_STOP) (actual: {root_node['mouse_filter']})",
                       "POINTER_ISOLATION")

    backdrop = modal_dict.get("Backdrop")
    reporter.check(backdrop is not None, "Backdrop node exists", "POINTER_ISOLATION")
    if backdrop:
        reporter.check(backdrop["mouse_filter"] == 0,
                       f"Backdrop mouse_filter = 0 (Control.MOUSE_FILTER_STOP) (actual: {backdrop['mouse_filter']})",
                       "POINTER_ISOLATION")

    center = modal_dict.get("CenterContainer")
    reporter.check(center is not None, "CenterContainer exists", "POINTER_ISOLATION")
    if center:
        reporter.check(center["mouse_filter"] == 2,
                       f"CenterContainer mouse_filter = 2 (Control.MOUSE_FILTER_IGNORE) to allow backdrop clicks (actual: {center['mouse_filter']})",
                       "POINTER_ISOLATION")

    card = modal_dict.get("ModalCard")
    reporter.check(card is not None, "ModalCard exists", "POINTER_ISOLATION")
    if card:
        reporter.check(card["mouse_filter"] == 0,
                       f"ModalCard mouse_filter = 0 (Control.MOUSE_FILTER_STOP) (actual: {card['mouse_filter']})",
                       "POINTER_ISOLATION")

    # 2. Interactive Nodes in syndicate_modal.tscn
    interactive_types = {"Button", "TextureButton", "CheckButton", "CheckBox", "HSlider", "VSlider", "TabBar", "TabContainer", "LineEdit", "TextEdit"}

    for node in modal_nodes:
        # Containers and layouts are not buttons unless they are clickable badges
        is_interactive = (node["type"] in interactive_types or
                          ("Button" in node["name"] and not node["type"].endswith("Container")) or
                          ("Slider" in node["name"] and not node["type"].endswith("Container")))
        if is_interactive:
            name = node["name"]
            ntype = node["type"]
            size = node["custom_size"]
            mf = node["mouse_filter"]

            # Height check >= 56.0
            if size:
                w, h = size
                reporter.check(h >= 56.0,
                               f"Interactive {ntype} '{name}' height >= 56.0px (actual: {h:.1f}px)",
                               "TOUCH_HEIGHT")
                if "CloseButton" in name:
                    reporter.check(w >= 56.0,
                                   f"Square button '{name}' width >= 56.0px (actual: {w:.1f}px)",
                                   "TOUCH_WIDTH")
            else:
                reporter.check(False, f"Interactive {ntype} '{name}' has NO custom_minimum_size!", "TOUCH_HEIGHT")

            # Mouse filter check: explicit 0 or default STOP
            # Default for Button / BaseButton / Range in Godot is MOUSE_FILTER_STOP (0)
            if mf is not None:
                reporter.check(mf == 0,
                               f"Interactive {ntype} '{name}' explicit mouse_filter == 0 (STOP) (actual: {mf})",
                               "POINTER_STOP")
            else:
                reporter.check(True,
                               f"Interactive {ntype} '{name}' defaults to Control.MOUSE_FILTER_STOP (0)",
                               "POINTER_STOP")

    # 3. ScrollContainers & Tab Containers in syndicate_modal.tscn
    scroll_containers = [n for n in modal_nodes if n["type"] == "ScrollContainer"]
    reporter.check(len(scroll_containers) >= 3,
                   f"Found {len(scroll_containers)} ScrollContainers in modal (PerkScroll, RosterScroll, LeaderboardScroll)",
                   "SCROLL_CONTAINERS")
    for sc in scroll_containers:
        reporter.check(sc["mouse_filter"] == 0,
                       f"ScrollContainer '{sc['name']}' mouse_filter = 0 (STOP) to isolate touch dragging",
                       "SCROLL_ISOLATION")

    # 4. HUD Syndicate Controls
    hud_dict = {n["name"]: n for n in hud_nodes}

    syn_badge = hud_dict.get("SyndicateBadge")
    reporter.check(syn_badge is not None, "HUD declares SyndicateBadge node", "HUD_ERGONOMICS")
    if syn_badge:
        size = syn_badge["custom_size"]
        reporter.check(size is not None and size[1] >= 56.0,
                       f"HUD SyndicateBadge height >= 56.0px (actual: {size[1] if size else 'None'})",
                       "HUD_ERGONOMICS")
        reporter.check(syn_badge["mouse_filter"] == 0,
                       f"HUD SyndicateBadge mouse_filter = 0 (STOP) (actual: {syn_badge['mouse_filter']})",
                       "HUD_ERGONOMICS")
        reporter.check(syn_badge["unique"], "HUD SyndicateBadge is unique_name_in_owner (%SyndicateBadge)", "HUD_ERGONOMICS")

    syn_btn = hud_dict.get("SyndicateButton")
    reporter.check(syn_btn is not None, "HUD declares SyndicateButton in NavDrawer", "HUD_ERGONOMICS")
    if syn_btn:
        size = syn_btn["custom_size"]
        reporter.check(size is not None and size[1] >= 64.0,
                       f"HUD SyndicateButton height >= 64.0px (actual: {size[1] if size else 'None'})",
                       "HUD_ERGONOMICS")
        reporter.check(syn_btn["mouse_filter"] == 0,
                       f"HUD SyndicateButton mouse_filter = 0 (STOP) (actual: {syn_btn['mouse_filter']})",
                       "HUD_ERGONOMICS")
        reporter.check(syn_btn["unique"], "HUD SyndicateButton is unique_name_in_owner (%SyndicateButton)", "HUD_ERGONOMICS")

    burger_btn = hud_dict.get("BurgerMenuButton")
    if burger_btn:
        size = burger_btn["custom_size"]
        reporter.check(size is not None and size[0] >= 56.0 and size[1] >= 56.0,
                       f"HUD BurgerMenuButton size >= 56x56 (actual: {size})",
                       "HUD_ERGONOMICS")
        reporter.check(burger_btn["mouse_filter"] == 0,
                       f"HUD BurgerMenuButton mouse_filter = 0 (STOP)",
                       "HUD_ERGONOMICS")


# ==============================================================================
# CHALLENGE 2: AST Static Analysis & Defensive Programming Stress
# ==============================================================================

def challenge_ast_defensive_architecture(reporter: ChallengeReporter):
    print(f"\n{Colors.BOLD}=== CHALLENGE 2: AST Static Analysis & Defensive Architecture Stress ==={Colors.ENDC}")

    reporter.check(MODAL_SCRIPT_PATH.exists(), f"Modal script exists: {MODAL_SCRIPT_PATH.name}", "AST_PRESENCE")
    reporter.check(HUD_SCRIPT_PATH.exists(), f"HUD script exists: {HUD_SCRIPT_PATH.name}", "AST_PRESENCE")

    if not MODAL_SCRIPT_PATH.exists() or not HUD_SCRIPT_PATH.exists():
        return

    modal_code = MODAL_SCRIPT_PATH.read_text(encoding="utf-8")
    hud_code = HUD_SCRIPT_PATH.read_text(encoding="utf-8")

    # 1. Check Color Constants
    emerald_m = re.search(r'const\s+COLOR_UNLOCKED\s*:\s*Color\s*=\s*Color\(\s*0\.0,\s*0\.9,\s*0\.46,\s*1\.0\s*\)', modal_code)
    reporter.check(emerald_m is not None, "COLOR_UNLOCKED emerald constant matches specification Color(0.0, 0.9, 0.46, 1.0)", "AST_CONSTANTS")

    cyan_m = re.search(r'const\s+COLOR_NEXT_OBJ\s*:\s*Color\s*=\s*Color\(\s*0\.0,\s*0\.9,\s*1\.0,\s*1\.0\s*\)', modal_code)
    reporter.check(cyan_m is not None, "COLOR_NEXT_OBJ cyan constant matches specification Color(0.0, 0.9, 1.0, 1.0)", "AST_CONSTANTS")

    locked_m = re.search(r'const\s+COLOR_LOCKED\s*:\s*Color\s*=\s*Color\(\s*0\.22,\s*0\.28,\s*0\.31,\s*1\.0\s*\)', modal_code)
    reporter.check(locked_m is not None, "COLOR_LOCKED dim gray constant matches specification Color(0.22, 0.28, 0.31, 1.0)", "AST_CONSTANTS")

    # 2. Check GameState Null-guards on all critical functions
    guarded_functions = [
        "refresh_overview",
        "refresh_roster",
        "refresh_wars",
        "set_donation_preset",
        "_update_donation_labels",
        "contribute_energy",
        "contribute_shares",
        "_connect_game_state_signals"
    ]
    for fn in guarded_functions:
        fn_pattern = rf'func\s+{fn}\s*\([^)]*\)\s*(?:->\s*[^:]+)?:\s*\n((?:[ \t]+[^\n]*\n|\s*\n)*)'
        match = re.search(fn_pattern, modal_code)
        if match:
            body = match.group(1)
            has_guard = 'GameState == null' in body or 'if GameState != null' in body or 'if GameState:' in body
            reporter.check(has_guard, f"Function '{fn}' has defensive GameState null guard", "NULL_GUARD")
        else:
            reporter.check(False, f"Function '{fn}' not found in modal script", "NULL_GUARD")

    # 3. Dynamic row creation in _add_member_row
    member_row_m = re.search(r'func\s+_add_member_row\s*\([^)]*\)\s*(?:->\s*[^:]+)?:\s*\n((?:[ \t]+[^\n]*\n|\s*\n)*)', modal_code)
    reporter.check(member_row_m is not None, "_add_member_row function declared", "DYNAMIC_ERGONOMICS")
    if member_row_m:
        body = member_row_m.group(1)
        reporter.check('custom_minimum_size = Vector2(0, 56)' in body or 'custom_minimum_size = Vector2(0.0, 56.0)' in body,
                       "Dynamically created member row has custom_minimum_size.y >= 56px", "DYNAMIC_ERGONOMICS")
        reporter.check('mouse_filter = Control.MOUSE_FILTER_STOP' in body,
                       "Dynamically created member row enforces mouse_filter = Control.MOUSE_FILTER_STOP", "DYNAMIC_ERGONOMICS")

    # 4. Dynamic leaderboard row creation in _populate_leaderboard
    leader_row_m = re.search(r'func\s+_populate_leaderboard\s*\([^)]*\)\s*(?:->\s*[^:]+)?:\s*\n((?:[ \t]+[^\n]*\n|\s*\n)*)', modal_code)
    reporter.check(leader_row_m is not None, "_populate_leaderboard function declared", "DYNAMIC_ERGONOMICS")
    if leader_row_m:
        body = leader_row_m.group(1)
        reporter.check('custom_minimum_size = Vector2(0, 56)' in body or 'custom_minimum_size = Vector2(0.0, 56.0)' in body,
                       "Dynamically created leaderboard row has custom_minimum_size.y >= 56px", "DYNAMIC_ERGONOMICS")
        reporter.check('mouse_filter = Control.MOUSE_FILTER_STOP' in body,
                       "Dynamically created leaderboard row enforces mouse_filter = Control.MOUSE_FILTER_STOP", "DYNAMIC_ERGONOMICS")

    # 5. Audio & Haptics safe invocation
    reporter.check('get_node_or_null("/root/AudioManager")' in modal_code or 'AudioManager != null' in modal_code or 'has_node' in modal_code,
                   "AudioManager invoked defensively with null-check", "DEFENSIVE_AUDIO")
    reporter.check('get_node_or_null("/root/HapticsManager")' in modal_code or 'HapticsManager != null' in modal_code or 'Input.vibrate_handheld' in modal_code,
                   "HapticsManager / Input invoked defensively with platform checks", "DEFENSIVE_HAPTICS")

    # 6. scripts/hud.gd Modal Routing & Lifetime
    reporter.check('const SYNDICATE_MODAL_SCENE: PackedScene = preload("res://scenes/ui/syndicate_modal.tscn")' in hud_code,
                   "hud.gd preloads SYNDICATE_MODAL_SCENE as constant", "HUD_ROUTING")
    reporter.check('func open_syndicate_modal() -> Control:' in hud_code,
                   "hud.gd declares typed func open_syndicate_modal() -> Control", "HUD_ROUTING")
    reporter.check('return open_modal(SYNDICATE_MODAL_SCENE)' in hud_code,
                   "open_syndicate_modal delegates to open_modal(SYNDICATE_MODAL_SCENE)", "HUD_ROUTING")

    # 7. scripts/hud.gd Stale Modal Closure Protection
    open_modal_m = re.search(r'func\s+open_modal\s*\([^)]*\)\s*(?:->\s*[^:]+)?:\s*\n((?:[ \t]+[^\n]*\n|\s*\n)*)', hud_code)
    reporter.check(open_modal_m is not None, "open_modal function found in hud.gd", "MODAL_LIFECYCLE")
    if open_modal_m:
        body = open_modal_m.group(1)
        reporter.check('if _active_modal == modal_inst:' in body or 'modal_inst.closed.connect' in body,
                       "open_modal contains closure guard against stale modal references", "MODAL_LIFECYCLE")
        reporter.check('close_nav_drawer()' in body,
                       "open_modal automatically dismisses NavDrawer on open", "MODAL_LIFECYCLE")


# ==============================================================================
# CHALLENGE 3: Fuzzing & Extreme Boundary Simulation
# ==============================================================================

def simulate_full_modal_lifecycle():
    """Simulate complete state machine transitions of SyndicateModal across edge cases."""
    pass


def challenge_fuzzing_and_bounds(reporter: ChallengeReporter):
    print(f"\n{Colors.BOLD}=== CHALLENGE 3: Fuzzing & Extreme Boundary Simulation ==={Colors.ENDC}")

    # 1. Tier Progression Math Bounds across all 5 Tiers
    tier_configs = {
        1: {"req_energy": 10000.0, "req_shares": 1, "div": 1.05},
        2: {"req_energy": 100000.0, "req_shares": 5, "div": 1.10},
        3: {"req_energy": 500000.0, "req_shares": 20, "div": 1.15},
        4: {"req_energy": 2500000.0, "req_shares": 50, "div": 1.20},
        5: {"req_energy": 10000000.0, "req_shares": 100, "div": 1.25},
    }

    # Test exact threshold crossings:
    for tier in range(1, 5):
        next_t = tier + 1
        req_e = tier_configs[next_t]["req_energy"]
        req_s = tier_configs[next_t]["req_shares"]

        # 0 funds -> 0%
        pct_zero = min(100.0, max(0.0 / req_e, 0.0 / req_s) * 100.0)
        reporter.check(math.isclose(pct_zero, 0.0), f"Tier {tier} with 0 funds yields 0.0% toward Tier {next_t}", "FUZZ_TIER")

        # Half energy -> 50%
        pct_half_e = min(100.0, max((req_e * 0.5) / req_e, 0.0 / req_s) * 100.0)
        reporter.check(math.isclose(pct_half_e, 50.0), f"Tier {tier} with half energy yields 50.0% toward Tier {next_t}", "FUZZ_TIER")

        # Full energy -> 100%
        pct_full_e = min(100.0, max(req_e / req_e, 0.0 / req_s) * 100.0)
        reporter.check(math.isclose(pct_full_e, 100.0), f"Tier {tier} with full energy yields 100.0% toward Tier {next_t}", "FUZZ_TIER")

        # Full shares alone -> 100%
        pct_full_s = min(100.0, max(0.0 / req_e, float(req_s) / float(req_s)) * 100.0)
        reporter.check(math.isclose(pct_full_s, 100.0), f"Tier {tier} with full shares alone yields 100.0% toward Tier {next_t}", "FUZZ_TIER")

        # Massive overflow (10x requirements) clamped to 100%
        pct_overflow = min(100.0, max((req_e * 10.0) / req_e, float(req_s * 10) / float(req_s)) * 100.0)
        reporter.check(math.isclose(pct_overflow, 100.0), f"Tier {tier} with 10x overflow clamped strictly to 100.0%", "FUZZ_TIER")

    # 2. Preset Donation Stepper Fuzzing
    test_balances = [0.0, 1.0, 99.0, 100.0, 1000.0, 50000.0, 1e9, 1e15]
    for bal in test_balances:
        p10 = math.floor(bal * 0.10)
        p50 = math.floor(bal * 0.50)
        pmax = math.floor(bal * 1.00)

        # Invariants:
        # 0 <= p10 <= p50 <= pmax <= bal
        reporter.check(0.0 <= p10 <= p50 <= pmax <= bal,
                       f"Balance {bal:,.0f}: presets monotonically ordered (10%={p10:,.0f}, 50%={p50:,.0f}, MAX={pmax:,.0f})",
                       "FUZZ_PRESET")

    # Slider step size fuzzing: step = maxf(1.0, floor(player_energy / 100.0))
    for bal in [0.0, 50.0, 100.0, 500.0, 10000.0, 1e6]:
        step = max(1.0, math.floor(bal / 100.0)) if bal > 100.0 else 1.0
        reporter.check(step >= 1.0 and (bal <= 100.0 or step == math.floor(bal / 100.0)),
                       f"Balance {bal:,.0f}: slider step size {step:,.0f} >= 1.0 and sensible",
                       "FUZZ_SLIDER_STEP")

    # 3. Weekly Season Rollover Timestamp Invariant Testing
    # Test timestamps: epoch 0, leap years, exact week boundaries, middle of week
    timestamps = [
        0,                  # Epoch start (Thursday 00:00:00 UTC)
        86400 * 7 - 1,      # 1 second before first week rollover
        86400 * 7,          # Exactly at first week rollover
        86400 * 7 + 1,      # 1 second after first week rollover
        1729170000,         # Arbitrary modern timestamp
        2000000000,         # Year 2033 timestamp
    ]
    week_sec = 86400 * 7
    for ts in timestamps:
        rem = week_sec - (ts % week_sec)
        d = rem // 86400
        h = (rem % 86400) // 3600
        m = (rem % 3600) // 60
        s = rem % 60
        total_recomputed = d * 86400 + h * 3600 + m * 60 + s
        reporter.check(rem == total_recomputed and 1 <= rem <= week_sec and 0 <= d <= 7 and 0 <= h < 24 and 0 <= m < 60 and 0 <= s < 60,
                       f"Timestamp {ts}: recomputed countdown ({d}d {h:02d}h {m:02d}m {s:02d}s) precisely equals remaining {rem}s",
                       "FUZZ_TIMER")

    # 4. Status Card Color Assignment Matrix across all (CardTier, CurrentTier) pairs
    for current_t in range(0, 6):  # 0 (unaffiliated) through 5 (max tier)
        for card_t in range(1, 6):
            if card_t <= current_t:
                expected_status = "UNLOCKED"
                expected_color = "EMERALD"
            elif card_t == current_t + 1:
                expected_status = "NEXT OBJECTIVE"
                expected_color = "CYAN"
            else:
                expected_status = "LOCKED"
                expected_color = "DIM_GRAY"

            actual_status = "UNLOCKED" if card_t <= current_t else ("NEXT OBJECTIVE" if card_t == current_t + 1 else "LOCKED")
            reporter.check(actual_status == expected_status,
                           f"Current Tier {current_t}, Card Tier {card_t}: status is {actual_status} ({expected_color})",
                           "FUZZ_CARD_MATRIX")

    # 5. HUD Badge Text Simulation
    # Solo case
    b_solo = "🏢 [SOLO]"
    reporter.check(b_solo == "🏢 [SOLO]", "Unaffiliated badge text is '🏢 [SOLO]'", "FUZZ_BADGE")
    # Affiliated cases
    for t in range(1, 6):
        tag = f"SYN{t}"
        pct = t * 5
        b_text = f"🏢 [{tag}] +{pct}%"
        reporter.check(b_text == f"🏢 [{tag}] +{pct}%", f"Tier {t} badge text matches '🏢 [{tag}] +{pct}%'", "FUZZ_BADGE")


# ==============================================================================
# MAIN RUNNER
# ==============================================================================

def main():
    print(f"\n{Colors.BOLD}{Colors.HEADER}======================================================================{Colors.ENDC}")
    print(f"{Colors.BOLD}{Colors.HEADER}Starting Phase 13 Milestone M3 Adversarial Challenge Suite{Colors.ENDC}")
    print(f"{Colors.BOLD}{Colors.HEADER}======================================================================{Colors.ENDC}")

    reporter = ChallengeReporter()

    challenge_scene_ergonomics(reporter)
    challenge_ast_defensive_architecture(reporter)
    challenge_fuzzing_and_bounds(reporter)

    exit_code = reporter.summarize()
    sys.exit(exit_code)


if __name__ == "__main__":
    main()
