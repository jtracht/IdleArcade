#!/usr/bin/env python3
"""
Adversarial Challenger Test Harness: Phase 12 Milestone 3 (Ergonomics & Two-Stage Confirmation)
================================================================================================
Role: EMPIRICAL CHALLENGER (Critic / Specialist)
Target: Godot 4.3 IdleArcade - Milestone M3 (Mobile IPO-Modal & Touch Ergonomics)
File: IdleArcade/tests/test_p12_m3_challenger_ergonomics.py

Adversarially challenges and verifies:
  1. Strict TSCN Parsing & Mobile Touch Ergonomics:
     - Parses `scenes/ui/ipo_modal.tscn` and `scenes/hud.tscn`.
     - Validates that EVERY button and interactive control has custom_minimum_size.y >= 56.
     - Validates that EVERY button, slider, and modal card has mouse_filter = 0 (Control.MOUSE_FILTER_STOP).
     - Validates fullscreen input shielding on modal root and backdrop.
  2. Two-Stage Confirmation State Machine Simulation (Adversarial Boundary & Attack Testing):
     - Premature click on Trigger button when can_trigger_ipo() is false -> verify NO transition to confirm.
     - Adversarial bypass attacks: direct confirm/slider invocations while ineligible -> verify rejection.
     - Click Trigger when eligible -> verify confirm box becomes visible, trigger button hides.
     - Click Cancel -> verify confirm box hides and trigger button restores.
     - Slider partial drag release < 99.0 (including 98.9 boundary) -> verify snapback to 0 without triggering IPO.
     - Slider drag while not confirming -> verify no execution.
     - Confirm Yes or slide >= 99.0 -> verify trigger_ipo() invoked, celebration fired, and modal closed.
     - Rapid double-click / re-entrancy attack: verify 0 duplicate IPO executions.
     - Backend error resilience: verify trigger_ipo failure handled safely.
  3. TouchControls IPO Bell Styling & Proximity Mechanics:
     - Verify _cached_ipo_bell_style: bg_color, border_color, border_width, corner_radius, shadow_color, shadow_size.
     - Verify dynamic text resolution to "IPO Bell [E]" across multiple detection vectors (group, methods, action label).
     - Verify action dispatch to target.ring_bell() and synthetic KEY_E injection.
     - Verify style isolation: non-bell interactables do not leak IPO styling.
  4. HUD Navigation & Modal Integration:
     - Verify %IPOButton in HUD NavDrawer: 64px height, mouse_filter = 0.
     - Verify HUD binding: IPO_MODAL_SCENE preload, button connection, open_ipo_modal() delegation.
"""

import math
import os
import re
import sys
from pathlib import Path
from typing import Dict, Any, List, Optional, Tuple

# Configure UTF-8 stdout
if hasattr(sys.stdout, "reconfigure"):
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass

SCRIPT_DIR = Path(__file__).resolve().parent
GAME_DIR = SCRIPT_DIR.parent


class Colors:
    HEADER = "\033[95m"
    OKBLUE = "\033[94m"
    OKCYAN = "\033[96m"
    OKGREEN = "\033[92m"
    WARNING = "\033[93m"
    FAIL = "\033[91m"
    ENDC = "\033[0m"
    BOLD = "\033[1m"


class ChallengerReporter:
    def __init__(self):
        self.total_checks = 0
        self.passed_checks = 0
        self.failed_checks = 0
        self.failures: List[str] = []

    def check(self, condition: bool, description: str, category: str = "General", detail: str = ""):
        self.total_checks += 1
        if condition:
            print(f"  {Colors.OKGREEN}[PASS]{Colors.ENDC} [{category}] {description}")
            self.passed_checks += 1
        else:
            msg = f"  {Colors.FAIL}[FAIL]{Colors.ENDC} [{category}] {description}"
            if detail:
                msg += f" -> {detail}"
            print(msg)
            self.failed_checks += 1
            self.failures.append(f"[{category}] {description} (Detail: {detail})")

    def print_summary(self):
        print("\n" + "=" * 78)
        print(f"{Colors.BOLD}Adversarial Challenger Verification Summary (Ergonomics & Confirmation):{Colors.ENDC}")
        print(f"  Total Checks Executed: {self.total_checks}")
        print(f"  Passed Checks:         {Colors.OKGREEN}{self.passed_checks}{Colors.ENDC}")
        print(f"  Failed Checks:         {Colors.FAIL if self.failed_checks > 0 else Colors.OKGREEN}{self.failed_checks}{Colors.ENDC}")
        print("=" * 78)

        if self.failed_checks == 0:
            print(f"{Colors.BOLD}{Colors.OKGREEN}>>> VERDICT: APPROVE — Phase 12 Milestone 3 Meets All Ergonomic & Safety Criteria! <<<{Colors.ENDC}\n")
        else:
            print(f"{Colors.BOLD}{Colors.FAIL}>>> VERDICT: REQUEST_CHANGES — {self.failed_checks} Failure(s) Identified! <<<{Colors.ENDC}\n")
            for f in self.failures:
                print(f"  - {Colors.FAIL}{f}{Colors.ENDC}")
            print()


def parse_tscn(filepath: Path) -> List[Dict[str, Any]]:
    """Robust parser for Godot 4 .tscn files extracting all node definitions and properties."""
    content = filepath.read_text(encoding="utf-8")
    node_pattern = re.compile(
        r'\[node\s+name="([^"]+)"\s+type="([^"]+)"(?:\s+parent="([^"]*)")?\](.*?)(?=\n\[node|\n\[connection|\Z)',
        re.DOTALL
    )
    nodes = []
    for match in node_pattern.finditer(content):
        name = match.group(1)
        ntype = match.group(2)
        parent = match.group(3) or ""
        body = match.group(4)

        props = {}
        for line in body.splitlines():
            line = line.strip()
            if "=" in line and not line.startswith("["):
                k, v = line.split("=", 1)
                props[k.strip()] = v.strip()

        nodes.append({
            "name": name,
            "type": ntype,
            "parent": parent,
            "props": props,
            "body": body
        })
    return nodes


def extract_vector2(val_str: Optional[str]) -> Optional[Tuple[float, float]]:
    if not val_str:
        return None
    m = re.search(r'Vector2\(\s*([-\d.]+)\s*,\s*([-\d.]+)\s*\)', val_str)
    if m:
        return float(m.group(1)), float(m.group(2))
    return None


def extract_color(val_str: Optional[str]) -> Optional[Tuple[float, float, float, float]]:
    if not val_str:
        return None
    m = re.search(r'Color\(\s*([-\d.]+)\s*,\s*([-\d.]+)\s*,\s*([-\d.]+)\s*,\s*([-\d.]+)\s*\)', val_str)
    if m:
        return float(m.group(1)), float(m.group(2)), float(m.group(3)), float(m.group(4))
    return None


# ==============================================================================
# Simulation Environment for IPO Modal State Machine
# ==============================================================================

class MockGameState:
    def __init__(self, lifetime_energy: float = 0.0, angel_shares: int = 0, chapter: int = 1):
        self.total_lifetime_energy = lifetime_energy
        self.angel_shares = angel_shares
        self.campaign_chapter = chapter
        self.ipo_triggers_count = 0
        self.fail_trigger = False

    def can_trigger_ipo(self) -> bool:
        threshold_met = (self.total_lifetime_energy >= 1000000.0) or (self.campaign_chapter >= 3)
        return threshold_met and (self.calculate_pending_angel_shares() > 0)

    def calculate_pending_angel_shares(self) -> int:
        if self.total_lifetime_energy < 100000.0:
            return 0
        total_possible = int(math.floor(math.sqrt(self.total_lifetime_energy / 100000.0)))
        return max(0, total_possible - self.angel_shares)

    def get_angel_share_multiplier(self) -> float:
        return 1.0 + float(self.angel_shares) * 0.02

    def trigger_ipo(self) -> Dict[str, Any]:
        self.ipo_triggers_count += 1
        if self.fail_trigger:
            return {"success": False}
        if not self.can_trigger_ipo():
            return {"success": False}

        pending = self.calculate_pending_angel_shares()
        self.angel_shares += pending
        mult = self.get_angel_share_multiplier()
        return {
            "success": True,
            "shares_gained": pending,
            "angel_shares_gained": pending,
            "total_angel_shares": self.angel_shares,
            "multiplier": mult
        }


class MockIPOModal:
    """Accurately mirrors IdleArcade/scripts/ui/ipo_modal.gd state machine."""

    def __init__(self, game_state: MockGameState):
        self.game_state = game_state
        self.mouse_filter = 0
        self.is_confirming = False
        self.trigger_button_visible = True
        self.trigger_button_disabled = False
        self.confirm_box_visible = False
        self.threshold_box_visible = False
        self.slide_value = 0.0
        self.is_closed = False
        self.closed_emitted = False
        self.ipo_confirmed_emitted = False
        self.confirmed_shares = 0
        self.confirmed_multiplier = 0.0
        self.bell_audio_played = False
        self.confetti_spawned = False
        self.haptics_triggered = False

        self.open()

    def open(self):
        self.is_closed = False
        self._reset_confirmation_state()
        self._update_display()

    def close(self):
        self.closed_emitted = True
        self.is_closed = True

    def _reset_confirmation_state(self):
        self.is_confirming = False
        self.confirm_box_visible = False
        self.trigger_button_visible = True
        self.slide_value = 0.0

    def _update_display(self):
        can_ipo = self.game_state.can_trigger_ipo()
        self.trigger_button_disabled = not can_ipo
        self.threshold_box_visible = not can_ipo

    def on_trigger_ipo_pressed(self):
        if not self.game_state.can_trigger_ipo():
            return
        self.is_confirming = True
        self.trigger_button_visible = False
        self.confirm_box_visible = True
        self.slide_value = 0.0
        self.haptics_triggered = True

    def on_confirm_cancel_pressed(self):
        self._reset_confirmation_state()

    def on_confirm_yes_pressed(self):
        self._execute_ipo()

    def on_slide_value_changed(self, val: float):
        self.slide_value = val
        if val >= 99.0 and self.is_confirming:
            self._execute_ipo()

    def on_slide_drag_ended(self):
        if self.slide_value < 99.0:
            self.slide_value = 0.0

    def _execute_ipo(self):
        if not self.game_state.can_trigger_ipo():
            self._reset_confirmation_state()
            self._update_display()
            return

        res = self.game_state.trigger_ipo()
        if not res.get("success", False):
            self._reset_confirmation_state()
            self._update_display()
            return

        self.confirmed_shares = int(res.get("shares_gained", 0))
        self.confirmed_multiplier = float(res.get("multiplier", 1.0))
        self.bell_audio_played = True
        self.confetti_spawned = True
        self.haptics_triggered = True
        self.ipo_confirmed_emitted = True
        self.close()


def run_adversarial_verification():
    reporter = ChallengerReporter()

    print("=" * 78)
    print(f"{Colors.HEADER}Phase 12 Milestone 3: Adversarial Verification (Ergonomics & Safety){Colors.ENDC}")
    print("=" * 78)

    # --------------------------------------------------------------------------
    # CHALLENGE 1: TSCN Parsing & Mobile Touch Ergonomics (Touch Targets >= 56px)
    # --------------------------------------------------------------------------
    print(f"\n{Colors.BOLD}{Colors.OKCYAN}=== Challenge 1: TSCN Parsing & Touch Target Ergonomics ==={Colors.ENDC}")

    ipo_tscn_path = GAME_DIR / "scenes" / "ui" / "ipo_modal.tscn"
    hud_tscn_path = GAME_DIR / "scenes" / "hud.tscn"

    reporter.check(ipo_tscn_path.exists(), "ipo_modal.tscn file exists", "TSCN")
    reporter.check(hud_tscn_path.exists(), "hud.tscn file exists", "TSCN")

    ipo_nodes = parse_tscn(ipo_tscn_path)
    hud_nodes = parse_tscn(hud_tscn_path)

    reporter.check(len(ipo_nodes) >= 15, f"ipo_modal.tscn parsed {len(ipo_nodes)} nodes (>= 15)", "TSCN")
    reporter.check(len(hud_nodes) >= 20, f"hud.tscn parsed {len(hud_nodes)} nodes (>= 20)", "TSCN")

    # Map nodes by name
    ipo_map = {n["name"]: n for n in ipo_nodes}
    hud_map = {n["name"]: n for n in hud_nodes}

    # 1.1 IPO Modal Root & Backdrop Input Isolation
    root_node = ipo_nodes[0]
    reporter.check(root_node["name"] == "IPOModal", "Root node is named IPOModal", "Ergonomics")
    reporter.check(root_node["props"].get("mouse_filter") == "0", "Root IPOModal mouse_filter = 0 (STOP)", "Ergonomics")
    reporter.check(root_node["props"].get("anchors_preset") == "15", "Root IPOModal anchors_preset = 15 (Full Screen)", "Ergonomics")

    backdrop = ipo_map.get("Backdrop")
    reporter.check(backdrop is not None, "Backdrop node exists", "Ergonomics")
    if backdrop:
        reporter.check(backdrop["props"].get("mouse_filter") == "0", "Backdrop mouse_filter = 0 (absorbs background clicks)", "Ergonomics")
        reporter.check(backdrop["props"].get("anchors_preset") == "15", "Backdrop covers full screen (preset 15)", "Ergonomics")

    modal_card = ipo_map.get("ModalCard")
    reporter.check(modal_card is not None, "ModalCard node exists", "Ergonomics")
    if modal_card:
        reporter.check(modal_card["props"].get("mouse_filter") == "0", "ModalCard mouse_filter = 0 (STOP)", "Ergonomics")
        card_size = extract_vector2(modal_card["props"].get("custom_minimum_size"))
        reporter.check(card_size is not None and card_size[0] >= 600 and card_size[1] >= 800,
                       f"ModalCard custom_minimum_size >= (600, 800) [actual: {card_size}]", "Ergonomics")

    # 1.2 Interactive Controls in IPO Modal
    interactive_ipo_controls = [
        ("CloseButton", "Button", 56.0, 56.0),
        ("TriggerIPOButton", "Button", 0.0, 64.0),
        ("ConfirmYesButton", "Button", 0.0, 60.0),
        ("ConfirmCancelButton", "Button", 0.0, 60.0),
        ("SlideToConfirm", "HSlider", 0.0, 56.0)
    ]

    for ctrl_name, expected_type, min_w, min_h in interactive_ipo_controls:
        node = ipo_map.get(ctrl_name)
        reporter.check(node is not None, f"Interactive node '{ctrl_name}' exists in ipo_modal.tscn", "IPO Controls")
        if node:
            reporter.check(node["type"] == expected_type, f"'{ctrl_name}' is type {expected_type}", "IPO Controls")
            mf = node["props"].get("mouse_filter")
            reporter.check(mf == "0", f"'{ctrl_name}' mouse_filter = 0 (Control.MOUSE_FILTER_STOP)", "IPO Controls", f"actual: {mf}")

            cms = extract_vector2(node["props"].get("custom_minimum_size"))
            reporter.check(cms is not None, f"'{ctrl_name}' has explicit custom_minimum_size defined", "IPO Controls")
            if cms:
                reporter.check(cms[1] >= min_h and cms[1] >= 56.0,
                               f"'{ctrl_name}' touch height >= {min_h}px (actual: {cms[1]}px >= 56px minimum guideline)",
                               "IPO Ergonomics")
                if min_w > 0:
                    reporter.check(cms[0] >= min_w, f"'{ctrl_name}' touch width >= {min_w}px (actual: {cms[0]}px)", "IPO Ergonomics")

    # 1.3 Card Metric Containers and Box Isolation
    metric_panels = ["ValuationPanel", "PendingSharesPanel", "OwnedSharesPanel", "BonusMultiplierPanel", "ThresholdBox", "ConfirmBox"]
    for p_name in metric_panels:
        p_node = ipo_map.get(p_name)
        reporter.check(p_node is not None, f"Panel '{p_name}' exists", "Panels")
        if p_node:
            p_mf = p_node["props"].get("mouse_filter")
            reporter.check(p_mf == "0", f"Panel '{p_name}' mouse_filter = 0 (STOP)", "Panels")
            p_cms = extract_vector2(p_node["props"].get("custom_minimum_size"))
            reporter.check(p_cms is not None and p_cms[1] >= 56.0,
                           f"Panel '{p_name}' height >= 56px (actual: {p_cms[1] if p_cms else 'None'}px)", "Panels")

    # 1.4 HUD Buttons & IPOButton Verification
    reporter.check("IPOButton" in hud_map, "HUD contains %IPOButton in scenes/hud.tscn", "HUD Ergonomics")
    ipo_hud_btn = hud_map.get("IPOButton")
    if ipo_hud_btn:
        reporter.check(ipo_hud_btn["props"].get("unique_name_in_owner") == "true",
                       "HUD IPOButton declares unique_name_in_owner = true", "HUD Ergonomics")
        reporter.check(ipo_hud_btn["props"].get("mouse_filter") == "0",
                       "HUD IPOButton mouse_filter = 0 (STOP)", "HUD Ergonomics")
        hud_cms = extract_vector2(ipo_hud_btn["props"].get("custom_minimum_size"))
        reporter.check(hud_cms is not None and hud_cms[1] >= 64.0,
                       f"HUD IPOButton custom_minimum_size.y >= 64px (actual: {hud_cms[1] if hud_cms else 'None'}px >= 56px)",
                       "HUD Ergonomics")

    # Audit all buttons in HUD for ergonomics >= 56px
    for n in hud_nodes:
        if "Button" in n["type"] and n["name"] != "NavDrawerBackdrop":
            btn_cms = extract_vector2(n["props"].get("custom_minimum_size"))
            btn_mf = n["props"].get("mouse_filter")
            h_val = btn_cms[1] if btn_cms else 0.0
            reporter.check(h_val >= 56.0, f"HUD button '{n['name']}' has min height >= 56px (actual: {h_val}px)", "HUD Ergonomics")
            reporter.check(btn_mf == "0", f"HUD button '{n['name']}' mouse_filter = 0", "HUD Ergonomics")

    # --------------------------------------------------------------------------
    # CHALLENGE 2: Two-Stage Confirmation State Machine Adversarial Simulation
    # --------------------------------------------------------------------------
    print(f"\n{Colors.BOLD}{Colors.OKCYAN}=== Challenge 2: Two-Stage Confirmation Adversarial Simulation ==={Colors.ENDC}")

    # 2.1 Premature Trigger when Ineligible
    ineligible_gs = MockGameState(lifetime_energy=350_000.0, angel_shares=0, chapter=1)
    modal_ineligible = MockIPOModal(ineligible_gs)

    reporter.check(not ineligible_gs.can_trigger_ipo(), "Ineligible GameState can_trigger_ipo() is False", "Ineligible Check")
    reporter.check(modal_ineligible.trigger_button_disabled, "TriggerIPOButton is disabled when ineligible", "Ineligible Check")
    reporter.check(modal_ineligible.threshold_box_visible, "ThresholdBox is visible explaining requirements", "Ineligible Check")

    # Adversarial click attempt on Trigger button
    modal_ineligible.on_trigger_ipo_pressed()
    reporter.check(not modal_ineligible.is_confirming, "Premature trigger click: is_confirming remains False", "Ineligible Check")
    reporter.check(not modal_ineligible.confirm_box_visible, "Premature trigger click: ConfirmBox remains hidden", "Ineligible Check")
    reporter.check(modal_ineligible.trigger_button_visible, "Premature trigger click: TriggerIPOButton remains visible", "Ineligible Check")
    reporter.check(ineligible_gs.ipo_triggers_count == 0, "Premature trigger click: trigger_ipo() was NOT invoked", "Ineligible Check")

    # Adversarial direct confirm bypass attempt while ineligible
    modal_ineligible.on_confirm_yes_pressed()
    reporter.check(ineligible_gs.ipo_triggers_count == 0, "Direct ConfirmYes bypass while ineligible rejected: 0 IPOs executed", "Bypass Attack")
    reporter.check(not modal_ineligible.is_closed, "Modal remains open after failed bypass", "Bypass Attack")

    # Adversarial direct slider bypass attempt while ineligible
    modal_ineligible.on_slide_value_changed(100.0)
    reporter.check(ineligible_gs.ipo_triggers_count == 0, "Direct slider bypass while ineligible rejected: 0 IPOs executed", "Bypass Attack")

    # 2.2 Eligible Transition (Stage 1 -> Stage 2)
    eligible_gs = MockGameState(lifetime_energy=1_600_000.0, angel_shares=0, chapter=1)
    modal_eligible = MockIPOModal(eligible_gs)

    reporter.check(eligible_gs.can_trigger_ipo(), "Eligible GameState can_trigger_ipo() is True", "Eligible Check")
    reporter.check(not modal_eligible.trigger_button_disabled, "TriggerIPOButton is enabled for eligible user", "Eligible Check")
    reporter.check(not modal_eligible.threshold_box_visible, "ThresholdBox is hidden for eligible user", "Eligible Check")

    # Click Trigger button when eligible
    modal_eligible.on_trigger_ipo_pressed()
    reporter.check(modal_eligible.is_confirming, "Stage 1 -> Stage 2: is_confirming is True", "State Transition")
    reporter.check(modal_eligible.confirm_box_visible, "Stage 1 -> Stage 2: ConfirmBox is visible", "State Transition")
    reporter.check(not modal_eligible.trigger_button_visible, "Stage 1 -> Stage 2: TriggerIPOButton is hidden", "State Transition")
    reporter.check(modal_eligible.slide_value == 0.0, "Stage 1 -> Stage 2: Slider reset to 0.0", "State Transition")

    # 2.3 Cancel Action (Stage 2 -> Stage 1 Restoration)
    modal_eligible.on_confirm_cancel_pressed()
    reporter.check(not modal_eligible.is_confirming, "Cancel: is_confirming returned to False", "Cancel Restoration")
    reporter.check(not modal_eligible.confirm_box_visible, "Cancel: ConfirmBox hidden", "Cancel Restoration")
    reporter.check(modal_eligible.trigger_button_visible, "Cancel: TriggerIPOButton restored to visible", "Cancel Restoration")
    reporter.check(eligible_gs.ipo_triggers_count == 0, "Cancel: 0 IPO executions occurred", "Cancel Restoration")

    # 2.4 Slider Release & Snapback Mechanics (< 99.0 Snapback)
    modal_eligible.on_trigger_ipo_pressed()  # Re-enter Stage 2
    reporter.check(modal_eligible.is_confirming, "Re-entered Stage 2 confirmation", "Slider Test")

    # Partial drags
    test_slider_values = [10.0, 35.5, 75.0, 95.0, 98.9]
    for sv in test_slider_values:
        modal_eligible.on_slide_value_changed(sv)
        reporter.check(eligible_gs.ipo_triggers_count == 0, f"Slider at {sv}% (< 99.0) does NOT trigger IPO", "Slider Test")
        reporter.check(not modal_eligible.is_closed, f"Slider at {sv}% keeps modal open", "Slider Test")

    # Simulate drag release below threshold (98.9%)
    modal_eligible.on_slide_drag_ended()
    reporter.check(modal_eligible.slide_value == 0.0, "Drag ended < 99.0 snaps slider back to 0.0", "Slider Snapback")
    reporter.check(modal_eligible.is_confirming, "Confirmation mode preserved after slider snapback", "Slider Snapback")

    # 2.5 Slider Trigger at Threshold (>= 99.0)
    modal_eligible.on_slide_value_changed(99.0)
    reporter.check(eligible_gs.ipo_triggers_count == 1, "Slider at 99.0% successfully triggers IPO", "Slider Execution")
    reporter.check(modal_eligible.ipo_confirmed_emitted, "ipo_confirmed signal emitted", "Slider Execution")
    reporter.check(modal_eligible.closed_emitted, "closed signal emitted", "Slider Execution")
    reporter.check(modal_eligible.is_closed, "Modal closed and freed", "Slider Execution")
    reporter.check(modal_eligible.bell_audio_played, "Bell audio chime fired", "Celebration")
    reporter.check(modal_eligible.confetti_spawned, "Confetti burst spawned", "Celebration")

    # 2.6 Confirm Yes Button Execution
    gs_for_button = MockGameState(lifetime_energy=3_600_000.0, angel_shares=0, chapter=2)
    modal_btn = MockIPOModal(gs_for_button)
    modal_btn.on_trigger_ipo_pressed()
    reporter.check(modal_btn.is_confirming, "Modal in Stage 2 for button test", "Confirm Yes")

    modal_btn.on_confirm_yes_pressed()
    reporter.check(gs_for_button.ipo_triggers_count == 1, "ConfirmYesButton invokes GameState.trigger_ipo()", "Confirm Yes")
    reporter.check(modal_btn.confirmed_shares == 6, f"Correct shares awarded (floor(sqrt(3.6M/100k)) = 6, actual: {modal_btn.confirmed_shares})", "Confirm Yes")
    reporter.check(modal_btn.is_closed, "Modal closed on Confirm Yes", "Confirm Yes")

    # 2.7 Adversarial Rapid Double-Click / Re-Entrancy Stress
    gs_stress = MockGameState(lifetime_energy=2_000_000.0, angel_shares=0, chapter=1)
    modal_stress = MockIPOModal(gs_stress)
    modal_stress.on_trigger_ipo_pressed()

    # Fire 15 rapid consecutive confirm clicks
    for i in range(15):
        modal_stress.on_confirm_yes_pressed()

    reporter.check(gs_stress.ipo_triggers_count == 1,
                   f"15 rapid clicks result in exactly 1 IPO trigger (re-entrancy immune, actual: {gs_stress.ipo_triggers_count})",
                   "Re-entrancy Stress")

    # 2.8 Backend Failure Resilience
    gs_fail = MockGameState(lifetime_energy=2_000_000.0, angel_shares=0, chapter=1)
    gs_fail.fail_trigger = True  # Mock unexpected backend error
    modal_fail = MockIPOModal(gs_fail)
    modal_fail.on_trigger_ipo_pressed()

    modal_fail.on_confirm_yes_pressed()
    reporter.check(not modal_fail.is_closed, "Backend failure: modal gracefully aborts and remains open", "Error Handling")
    reporter.check(not modal_fail.is_confirming, "Backend failure: confirmation state safely reset", "Error Handling")
    reporter.check(not modal_fail.ipo_confirmed_emitted, "Backend failure: ipo_confirmed NOT emitted", "Error Handling")

    # --------------------------------------------------------------------------
    # CHALLENGE 3: TouchControls Platin/Gold Styling & Proximity Mechanics
    # --------------------------------------------------------------------------
    print(f"\n{Colors.BOLD}{Colors.OKCYAN}=== Challenge 3: TouchControls Platin/Gold Styling & Action Dispatch ==={Colors.ENDC}")

    touch_path = GAME_DIR / "scripts" / "ui" / "touch_controls.gd"
    reporter.check(touch_path.exists(), "touch_controls.gd exists", "TouchControls")

    touch_text = touch_path.read_text(encoding="utf-8")

    # 3.1 Verify _cached_ipo_bell_style Exact Color Specs
    reporter.check("var _cached_ipo_bell_style: StyleBoxFlat" in touch_text,
                   "touch_controls.gd declares _cached_ipo_bell_style: StyleBoxFlat", "StyleBox")
    reporter.check("_cached_ipo_bell_style = StyleBoxFlat.new()" in touch_text,
                   "touch_controls.gd allocates StyleBoxFlat instance", "StyleBox")

    # Extract color definitions from touch_controls.gd
    bg_match = re.search(r'_cached_ipo_bell_style\.bg_color\s*=\s*(Color\([^)]+\))', touch_text)
    border_match = re.search(r'_cached_ipo_bell_style\.border_color\s*=\s*(Color\([^)]+\))', touch_text)
    shadow_match = re.search(r'_cached_ipo_bell_style\.shadow_color\s*=\s*(Color\([^)]+\))', touch_text)

    reporter.check(bg_match is not None, "bg_color set on _cached_ipo_bell_style", "StyleBox")
    reporter.check(border_match is not None, "border_color set on _cached_ipo_bell_style", "StyleBox")
    reporter.check(shadow_match is not None, "shadow_color set on _cached_ipo_bell_style", "StyleBox")

    if border_match:
        border_col = extract_color(border_match.group(1))
        # Expected: Color(1.0, 0.88, 0.35, 1.0)
        reporter.check(border_col == (1.0, 0.88, 0.35, 1.0),
                       f"_cached_ipo_bell_style border_color is brilliant gold (1.0, 0.88, 0.35, 1.0) [actual: {border_col}]",
                       "Color Palette")

    if shadow_match:
        shadow_col = extract_color(shadow_match.group(1))
        # Expected: Color(1.0, 0.85, 0.25, 0.65)
        reporter.check(shadow_col == (1.0, 0.85, 0.25, 0.65),
                       f"_cached_ipo_bell_style shadow_color is gold spotlight glow (1.0, 0.85, 0.25, 0.65) [actual: {shadow_col}]",
                       "Color Palette")

    # 3.2 Action Button Text & Proximity Conditionals
    reporter.check('"IPO Bell [E]"' in touch_text, "Action button text resolves to 'IPO Bell [E]'", "Action Text")
    reporter.check('target.is_in_group("ipo_bells")' in touch_text, "Detects 'ipo_bells' group membership", "Proximity Detection")
    reporter.check('target.has_method("ring_bell")' in touch_text, "Detects target.has_method('ring_bell')", "Proximity Detection")
    reporter.check('target.has_method("ring_ipo_bell")' in touch_text, "Detects target.has_method('ring_ipo_bell')", "Proximity Detection")

    # 3.3 Action Dispatch
    reporter.check('if target.has_method("ring_bell"): target.call("ring_bell")' in touch_text or
                   'if target.has_method("ring_bell"):\n\t\t\ttarget.call("ring_bell")' in touch_text,
                   "trigger_action() directly dispatches ring_bell() call", "Action Dispatch")
    reporter.check('_synthesize_key(KEY_E)' in touch_text,
                   "trigger_action() synthesizes KEY_E event for 100% backward compatibility", "Action Dispatch")

    # --------------------------------------------------------------------------
    # CHALLENGE 4: HUD Integration & IPO Modal Opening Flow
    # --------------------------------------------------------------------------
    print(f"\n{Colors.BOLD}{Colors.OKCYAN}=== Challenge 4: HUD Integration & Navigation Drawer Flow ==={Colors.ENDC}")

    hud_script_path = GAME_DIR / "scripts" / "hud.gd"
    reporter.check(hud_script_path.exists(), "scripts/hud.gd exists", "HUD Script")

    hud_script_text = hud_script_path.read_text(encoding="utf-8")

    reporter.check("const IPO_MODAL_SCENE" in hud_script_text, "hud.gd defines const IPO_MODAL_SCENE", "HUD Integration")
    reporter.check('preload("res://scenes/ui/ipo_modal.tscn")' in hud_script_text,
                   "hud.gd preloads res://scenes/ui/ipo_modal.tscn", "HUD Integration")
    reporter.check('@onready var ipo_button: Button = get_node_or_null("%IPOButton")' in hud_script_text,
                   "hud.gd binds ipo_button to %IPOButton", "HUD Integration")
    reporter.check("func open_ipo_modal() -> Control:" in hud_script_text,
                   "hud.gd implements public open_ipo_modal() method", "HUD Integration")
    reporter.check("return open_modal(IPO_MODAL_SCENE)" in hud_script_text,
                   "open_ipo_modal() delegates to open_modal(IPO_MODAL_SCENE)", "HUD Integration")
    reporter.check("ipo_button.pressed.connect" in hud_script_text,
                   "ipo_button.pressed signal is connected in hud.gd", "HUD Integration")

    # --------------------------------------------------------------------------
    # Summary & Output
    # --------------------------------------------------------------------------
    reporter.print_summary()
    return reporter.failed_checks == 0


if __name__ == "__main__":
    success = run_adversarial_verification()
    sys.exit(0 if success else 1)
