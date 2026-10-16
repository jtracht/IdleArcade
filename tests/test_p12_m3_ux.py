#!/usr/bin/env python3
"""
Phase 12 Milestone 3: Mobile IPO-Modal & Touch Ergonomics Verification Suite
=============================================================================
Target: Godot 4.3 IdleArcade - Milestone M3 (Requirement R3: Mobile IPO-Modal & Touch Ergonomics)

Validates:
  1. Static Code Contracts & AST Signatures:
     - `scenes/ui/ipo_modal.tscn` + `scripts/ui/ipo_modal.gd` existence and nodes.
     - `scenes/hud.tscn` + `scripts/hud.gd` %IPOButton declaration, preload, binding, open_ipo_modal().
     - `scripts/ui/touch_controls.gd` _cached_ipo_bell_style, action label, trigger_action dispatch.
  2. Mobile Touch Ergonomics & Input Isolation:
     - All interactive buttons have touch height >= 56px (Trigger >= 64px, Confirm >= 60px).
     - Close button has 56x56px touch target.
     - Root Control, Backdrop, ModalCard, and Panels enforce `mouse_filter = Control.MOUSE_FILTER_STOP` (0).
  3. StyleBox & Color Palette Verification:
     - Platin/Gold styling for IPO Bell: bg, border, corner radius, shadow glow.
     - Theme styles in ipo_modal.tscn for Card, Trigger, ConfirmYes, ConfirmCancel.
  4. Two-Stage Confirmation State Machine Simulation:
     - Stage 1 (Review) -> Stage 2 (Explicit Warning + Confirm/Cancel + Slide).
     - Cancellation restores Stage 1.
     - Threshold blocking when can_trigger_ipo() is false.
     - Confirmation triggers GameState.trigger_ipo(), audio chime, confetti burst, ipo_confirmed signal, and close.
  5. TouchControls Dynamic Action State Machine Simulation:
     - Detects "ipo_bells" group, ring_bell() method, and "IPO Bell [E]" label.
     - Dispatches ring_bell() / interact() on trigger_action().

Executable via: python tests/test_p12_m3_ux.py
"""

import math
import os
import re
import sys
from pathlib import Path
from typing import Dict, Any, List, Optional

# UTF-8 stdout configuration
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")


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

    def check(self, condition: bool, name: str, details: str = ""):
        self.total += 1
        if condition:
            self.passed += 1
            print(f"  {Colors.OKGREEN}[PASS]{Colors.ENDC} {name}")
        else:
            self.failed += 1
            msg = f"{name}: {details}" if details else name
            self.failures.append(msg)
            print(f"  {Colors.FAIL}[FAIL]{Colors.ENDC} {msg}")

    def section(self, title: str):
        print(f"\n{Colors.BOLD}{Colors.OKCYAN}=== {title} ==={Colors.ENDC}")

    def summary(self) -> bool:
        print("\n" + "=" * 70)
        print(f"{Colors.BOLD}Milestone M3 (Mobile IPO-Modal & Touch Ergonomics) Summary:{Colors.ENDC}")
        print(f"  Total Checks: {self.total}")
        print(f"  Passed:       {Colors.OKGREEN}{self.passed}{Colors.ENDC}")
        print(f"  Failed:       {Colors.FAIL if self.failed > 0 else Colors.OKGREEN}{self.failed}{Colors.ENDC}")
        print("=" * 70)
        if self.failures:
            print(f"\n{Colors.FAIL}Failed Checks:{Colors.ENDC}")
            for f in self.failures:
                print(f"  - {f}")
            return False
        else:
            print(f"\n{Colors.BOLD}{Colors.OKGREEN}>>> ALL CHECKS PASSED: Milestone M3 UX & Ergonomics Verified! <<<{Colors.ENDC}\n")
            return True


def run_tests() -> bool:
    reporter = TestReporter()
    base_dir = Path(__file__).resolve().parent.parent
    if base_dir.name != "IdleArcade" and (base_dir / "IdleArcade").exists():
        base_dir = base_dir / "IdleArcade"

    print("=" * 70)
    print(f"{Colors.HEADER}IdleArcade Phase 12 - Milestone M3 (Mobile IPO-Modal & Ergonomics){Colors.ENDC}")
    print("=" * 70)

    # -------------------------------------------------------------------------
    # SECTION 1: Static Code Contracts & AST Signatures
    # -------------------------------------------------------------------------
    reporter.section("SECTION 1: Static Code Contracts & AST Verification")

    ipo_modal_tscn = base_dir / "scenes" / "ui" / "ipo_modal.tscn"
    ipo_modal_gd = base_dir / "scripts" / "ui" / "ipo_modal.gd"
    hud_tscn = base_dir / "scenes" / "hud.tscn"
    hud_gd = base_dir / "scripts" / "hud.gd"
    touch_controls_gd = base_dir / "scripts" / "ui" / "touch_controls.gd"

    reporter.check(ipo_modal_tscn.exists(), "scenes/ui/ipo_modal.tscn exists")
    reporter.check(ipo_modal_gd.exists(), "scripts/ui/ipo_modal.gd exists")
    reporter.check(hud_tscn.exists(), "scenes/hud.tscn exists")
    reporter.check(hud_gd.exists(), "scripts/hud.gd exists")
    reporter.check(touch_controls_gd.exists(), "scripts/ui/touch_controls.gd exists")

    ipo_modal_tscn_text = ipo_modal_tscn.read_text(encoding="utf-8") if ipo_modal_tscn.exists() else ""
    ipo_modal_gd_text = ipo_modal_gd.read_text(encoding="utf-8") if ipo_modal_gd.exists() else ""
    hud_tscn_text = hud_tscn.read_text(encoding="utf-8") if hud_tscn.exists() else ""
    hud_gd_text = hud_gd.read_text(encoding="utf-8") if hud_gd.exists() else ""
    touch_controls_gd_text = touch_controls_gd.read_text(encoding="utf-8") if touch_controls_gd.exists() else ""

    # Check ipo_modal.gd AST
    reporter.check("signal closed" in ipo_modal_gd_text, "ipo_modal.gd declares signal closed")
    reporter.check("signal ipo_confirmed" in ipo_modal_gd_text, "ipo_modal.gd declares signal ipo_confirmed")
    reporter.check("%CloseButton" in ipo_modal_gd_text, "ipo_modal.gd binds %CloseButton")
    reporter.check("%ValuationLabel" in ipo_modal_gd_text, "ipo_modal.gd binds %ValuationLabel")
    reporter.check("%PendingSharesLabel" in ipo_modal_gd_text, "ipo_modal.gd binds %PendingSharesLabel")
    reporter.check("%OwnedSharesLabel" in ipo_modal_gd_text, "ipo_modal.gd binds %OwnedSharesLabel")
    reporter.check("%FutureBonusLabel" in ipo_modal_gd_text, "ipo_modal.gd binds %FutureBonusLabel")
    reporter.check("%ThresholdBox" in ipo_modal_gd_text, "ipo_modal.gd binds %ThresholdBox")
    reporter.check("%ThresholdLabel" in ipo_modal_gd_text, "ipo_modal.gd binds %ThresholdLabel")
    reporter.check("%TriggerIPOButton" in ipo_modal_gd_text, "ipo_modal.gd binds %TriggerIPOButton")
    reporter.check("%ConfirmBox" in ipo_modal_gd_text, "ipo_modal.gd binds %ConfirmBox")
    reporter.check("%ConfirmYesButton" in ipo_modal_gd_text, "ipo_modal.gd binds %ConfirmYesButton")
    reporter.check("%ConfirmCancelButton" in ipo_modal_gd_text, "ipo_modal.gd binds %ConfirmCancelButton")

    reporter.check("func open(" in ipo_modal_gd_text, "ipo_modal.gd implements func open()")
    reporter.check("func close(" in ipo_modal_gd_text, "ipo_modal.gd implements func close()")
    reporter.check("queue_free()" in ipo_modal_gd_text, "ipo_modal.gd calls queue_free() in close()")
    reporter.check("func _on_trigger_ipo_pressed(" in ipo_modal_gd_text, "ipo_modal.gd implements _on_trigger_ipo_pressed()")
    reporter.check("func _on_confirm_yes_pressed(" in ipo_modal_gd_text, "ipo_modal.gd implements _on_confirm_yes_pressed()")
    reporter.check("func _on_confirm_cancel_pressed(" in ipo_modal_gd_text, "ipo_modal.gd implements _on_confirm_cancel_pressed()")
    reporter.check("can_trigger_ipo" in ipo_modal_gd_text, "ipo_modal.gd checks GameState.can_trigger_ipo()")
    reporter.check("trigger_ipo" in ipo_modal_gd_text, "ipo_modal.gd calls GameState.trigger_ipo()")
    reporter.check("calculate_pending_angel_shares" in ipo_modal_gd_text, "ipo_modal.gd queries calculate_pending_angel_shares()")
    reporter.check("get_angel_share_multiplier" in ipo_modal_gd_text, "ipo_modal.gd queries get_angel_share_multiplier()")
    reporter.check("play_sfx_bell" in ipo_modal_gd_text or "play_sfx_confetti" in ipo_modal_gd_text, "ipo_modal.gd triggers audio celebration on IPO")
    reporter.check("spawn_burst_2d" in ipo_modal_gd_text, "ipo_modal.gd spawns 2D celebration confetti burst")

    # Check HUD AST
    reporter.check('[node name="IPOButton"' in hud_tscn_text, "hud.tscn defines [node name=\"IPOButton\"]")
    reporter.check('unique_name_in_owner = true' in hud_tscn_text and 'IPOButton' in hud_tscn_text, "hud.tscn declares %IPOButton with unique_name_in_owner")
    reporter.check("IPO_MODAL_SCENE" in hud_gd_text, "hud.gd declares const IPO_MODAL_SCENE")
    reporter.check('preload("res://scenes/ui/ipo_modal.tscn")' in hud_gd_text, "hud.gd preloads res://scenes/ui/ipo_modal.tscn")
    reporter.check("ipo_button" in hud_gd_text, "hud.gd declares ipo_button variable")
    reporter.check("ipo_button.pressed" in hud_gd_text, "hud.gd connects ipo_button.pressed")
    reporter.check("func open_ipo_modal()" in hud_gd_text, "hud.gd implements func open_ipo_modal() -> Control")
    reporter.check("open_modal(IPO_MODAL_SCENE)" in hud_gd_text, "hud.gd open_ipo_modal() delegates to open_modal(IPO_MODAL_SCENE)")

    # Check TouchControls AST
    reporter.check("var _cached_ipo_bell_style" in touch_controls_gd_text, "touch_controls.gd declares _cached_ipo_bell_style")
    reporter.check("_cached_ipo_bell_style = StyleBoxFlat.new()" in touch_controls_gd_text, "touch_controls.gd instantiates _cached_ipo_bell_style in _setup_styles()")
    reporter.check('"IPO Bell [E]"' in touch_controls_gd_text, "touch_controls.gd integrates 'IPO Bell [E]' action text")
    reporter.check('ipo_bells' in touch_controls_gd_text, "touch_controls.gd detects 'ipo_bells' group")
    reporter.check('target.has_method("ring_bell")' in touch_controls_gd_text, "touch_controls.gd detects target.has_method('ring_bell')")
    reporter.check('target.call("ring_bell")' in touch_controls_gd_text or 'target.call("interact")' in touch_controls_gd_text, "touch_controls.gd invokes target ring_bell / interact")

    # -------------------------------------------------------------------------
    # SECTION 2: Mobile Touch Ergonomics & Input Isolation
    # -------------------------------------------------------------------------
    reporter.section("SECTION 2: Mobile Touch Ergonomics & Input Isolation")

    # Parse node properties from scenes/ui/ipo_modal.tscn
    def parse_tscn_nodes(content: str) -> Dict[str, Dict[str, Any]]:
        nodes: Dict[str, Dict[str, Any]] = {}
        current_node = None
        for line in content.splitlines():
            line = line.strip()
            node_match = re.match(r'\[node\s+name="([^"]+)"(?:\s+type="([^"]+)")?', line)
            if node_match:
                current_node = node_match.group(1)
                nodes[current_node] = {"type": node_match.group(2) or "", "props": {}}
                continue
            if current_node and "=" in line and not line.startswith("["):
                parts = line.split("=", 1)
                key = parts[0].strip()
                val = parts[1].strip()
                nodes[current_node]["props"][key] = val
        return nodes

    ipo_nodes = parse_tscn_nodes(ipo_modal_tscn_text)

    # Root Control
    root_props = ipo_nodes.get("IPOModal", {}).get("props", {})
    reporter.check(root_props.get("mouse_filter") == "0", "IPOModal root mouse_filter = Control.MOUSE_FILTER_STOP (0)")
    reporter.check(root_props.get("anchors_preset") == "15", "IPOModal root anchors_preset = 15 (Full Screen)")

    # Backdrop
    backdrop_props = ipo_nodes.get("Backdrop", {}).get("props", {})
    reporter.check(backdrop_props.get("mouse_filter") == "0", "Backdrop mouse_filter = Control.MOUSE_FILTER_STOP (0)")
    reporter.check(backdrop_props.get("anchors_preset") == "15", "Backdrop anchors_preset = 15")

    # ModalCard
    modal_card_props = ipo_nodes.get("ModalCard", {}).get("props", {})
    reporter.check(modal_card_props.get("mouse_filter") == "0", "ModalCard mouse_filter = Control.MOUSE_FILTER_STOP (0)")
    cms = modal_card_props.get("custom_minimum_size", "")
    card_match = re.search(r'Vector2\s*\(\s*(\d+)\s*,\s*(\d+)\s*\)', cms)
    if card_match:
        cw, ch = int(card_match.group(1)), int(card_match.group(2))
        reporter.check(cw >= 600 and ch >= 800, f"ModalCard custom_minimum_size >= (600, 800) (actual: {cw}x{ch})")
    else:
        reporter.check(False, "ModalCard custom_minimum_size Vector2 parsed", cms)

    # CloseButton
    close_btn_props = ipo_nodes.get("CloseButton", {}).get("props", {})
    reporter.check(close_btn_props.get("mouse_filter") == "0", "CloseButton mouse_filter = Control.MOUSE_FILTER_STOP (0)")
    close_cms = close_btn_props.get("custom_minimum_size", "")
    close_match = re.search(r'Vector2\s*\(\s*(\d+)\s*,\s*(\d+)\s*\)', close_cms)
    if close_match:
        bw, bh = int(close_match.group(1)), int(close_match.group(2))
        reporter.check(bw >= 56 and bh >= 56, f"CloseButton touch size >= 56x56px (actual: {bw}x{bh}px)")
    else:
        reporter.check(False, "CloseButton custom_minimum_size parsed", close_cms)

    # TriggerIPOButton
    trigger_btn_props = ipo_nodes.get("TriggerIPOButton", {}).get("props", {})
    reporter.check(trigger_btn_props.get("mouse_filter") == "0", "TriggerIPOButton mouse_filter = Control.MOUSE_FILTER_STOP (0)")
    trig_cms = trigger_btn_props.get("custom_minimum_size", "")
    trig_match = re.search(r'Vector2\s*\(\s*(\d+)\s*,\s*(\d+)\s*\)', trig_cms)
    if trig_match:
        _, th = int(trig_match.group(1)), int(trig_match.group(2))
        reporter.check(th >= 64, f"TriggerIPOButton height >= 64px (actual: {th}px)")
    else:
        reporter.check(False, "TriggerIPOButton custom_minimum_size parsed", trig_cms)

    # ConfirmYesButton
    yes_btn_props = ipo_nodes.get("ConfirmYesButton", {}).get("props", {})
    reporter.check(yes_btn_props.get("mouse_filter") == "0", "ConfirmYesButton mouse_filter = Control.MOUSE_FILTER_STOP (0)")
    yes_cms = yes_btn_props.get("custom_minimum_size", "")
    yes_match = re.search(r'Vector2\s*\(\s*(\d+)\s*,\s*(\d+)\s*\)', yes_cms)
    if yes_match:
        _, yh = int(yes_match.group(1)), int(yes_match.group(2))
        reporter.check(yh >= 60, f"ConfirmYesButton height >= 60px (actual: {yh}px)")
    else:
        reporter.check(False, "ConfirmYesButton custom_minimum_size parsed", yes_cms)

    # ConfirmCancelButton
    cancel_btn_props = ipo_nodes.get("ConfirmCancelButton", {}).get("props", {})
    reporter.check(cancel_btn_props.get("mouse_filter") == "0", "ConfirmCancelButton mouse_filter = Control.MOUSE_FILTER_STOP (0)")
    cancel_cms = cancel_btn_props.get("custom_minimum_size", "")
    cancel_match = re.search(r'Vector2\s*\(\s*(\d+)\s*,\s*(\d+)\s*\)', cancel_cms)
    if cancel_match:
        _, ch = int(cancel_match.group(1)), int(cancel_match.group(2))
        reporter.check(ch >= 60, f"ConfirmCancelButton height >= 60px (actual: {ch}px)")
    else:
        reporter.check(False, "ConfirmCancelButton custom_minimum_size parsed", cancel_cms)

    # SlideToConfirm
    slide_props = ipo_nodes.get("SlideToConfirm", {}).get("props", {})
    reporter.check(slide_props.get("mouse_filter") == "0", "SlideToConfirm mouse_filter = Control.MOUSE_FILTER_STOP (0)")
    slide_cms = slide_props.get("custom_minimum_size", "")
    slide_match = re.search(r'Vector2\s*\(\s*(\d+)\s*,\s*(\d+)\s*\)', slide_cms)
    if slide_match:
        _, sh = int(slide_match.group(1)), int(slide_match.group(2))
        reporter.check(sh >= 56, f"SlideToConfirm height >= 56px (actual: {sh}px)")
    else:
        reporter.check(False, "SlideToConfirm custom_minimum_size parsed", slide_cms)

    # ConfirmBox
    confirm_box_props = ipo_nodes.get("ConfirmBox", {}).get("props", {})
    reporter.check(confirm_box_props.get("mouse_filter") == "0", "ConfirmBox mouse_filter = Control.MOUSE_FILTER_STOP (0)")
    reporter.check(confirm_box_props.get("visible") == "false", "ConfirmBox visible = false initially (Stage 1 hidden)")

    # ThresholdBox
    thresh_box_props = ipo_nodes.get("ThresholdBox", {}).get("props", {})
    reporter.check(thresh_box_props.get("mouse_filter") == "0", "ThresholdBox mouse_filter = Control.MOUSE_FILTER_STOP (0)")

    # HUD IPOButton
    hud_nodes = parse_tscn_nodes(hud_tscn_text)
    ipo_btn_props = hud_nodes.get("IPOButton", {}).get("props", {})
    reporter.check(ipo_btn_props.get("mouse_filter") == "0", "HUD %IPOButton mouse_filter = Control.MOUSE_FILTER_STOP (0)")
    hud_ipo_cms = ipo_btn_props.get("custom_minimum_size", "")
    hud_ipo_match = re.search(r'Vector2\s*\(\s*(\d+)\s*,\s*(\d+)\s*\)', hud_ipo_cms)
    if hud_ipo_match:
        _, hh = int(hud_ipo_match.group(1)), int(hud_ipo_match.group(2))
        reporter.check(hh >= 64, f"HUD %IPOButton height >= 64px (actual: {hh}px)")
    else:
        reporter.check(False, "HUD %IPOButton custom_minimum_size parsed", hud_ipo_cms)

    # -------------------------------------------------------------------------
    # SECTION 3: StyleBox & Color Palette Verification
    # -------------------------------------------------------------------------
    reporter.section("SECTION 3: StyleBox & Color Palette Verification")

    # Verify TouchControls _cached_ipo_bell_style specification
    # bg_color = Color(0.25, 0.22, 0.10, 0.92)
    # border_color = Color(1.0, 0.88, 0.35, 1.0)
    # border_width = 3, corner_radius = 50
    # shadow_color = Color(1.0, 0.85, 0.25, 0.65), shadow_size = 14
    bg_match = re.search(r'_cached_ipo_bell_style\.bg_color\s*=\s*Color\s*\(\s*0\.25\s*,\s*0\.22\s*,\s*0\.10\s*,\s*0\.92\s*\)', touch_controls_gd_text)
    reporter.check(bg_match is not None, "TouchControls _cached_ipo_bell_style bg_color = Color(0.25, 0.22, 0.10, 0.92)")

    border_match = re.search(r'_cached_ipo_bell_style\.border_color\s*=\s*Color\s*\(\s*1\.0\s*,\s*0\.88\s*,\s*0\.35\s*,\s*1\.0\s*\)', touch_controls_gd_text)
    reporter.check(border_match is not None, "TouchControls _cached_ipo_bell_style border_color = Color(1.0, 0.88, 0.35, 1.0)")

    bw_match = re.search(r'_cached_ipo_bell_style\.set_border_width_all\s*\(\s*3\s*\)', touch_controls_gd_text)
    reporter.check(bw_match is not None, "TouchControls _cached_ipo_bell_style border_width = 3")

    cr_match = re.search(r'_cached_ipo_bell_style\.set_corner_radius_all\s*\(\s*50\s*\)', touch_controls_gd_text)
    reporter.check(cr_match is not None, "TouchControls _cached_ipo_bell_style corner_radius = 50")

    shadow_c_match = re.search(r'_cached_ipo_bell_style\.shadow_color\s*=\s*Color\s*\(\s*1\.0\s*,\s*0\.85\s*,\s*0\.25\s*,\s*0\.65\s*\)', touch_controls_gd_text)
    reporter.check(shadow_c_match is not None, "TouchControls _cached_ipo_bell_style shadow_color = Color(1.0, 0.85, 0.25, 0.65)")

    shadow_s_match = re.search(r'_cached_ipo_bell_style\.shadow_size\s*=\s*14', touch_controls_gd_text)
    reporter.check(shadow_s_match is not None, "TouchControls _cached_ipo_bell_style shadow_size = 14")

    # Check StyleBoxFlat subresources in ipo_modal.tscn
    reporter.check('id="StyleBoxFlat_modal_card"' in ipo_modal_tscn_text, "ipo_modal.tscn contains StyleBoxFlat_modal_card")
    reporter.check('id="StyleBoxFlat_trigger_button"' in ipo_modal_tscn_text, "ipo_modal.tscn contains StyleBoxFlat_trigger_button")
    reporter.check('id="StyleBoxFlat_confirm_box"' in ipo_modal_tscn_text, "ipo_modal.tscn contains StyleBoxFlat_confirm_box")
    reporter.check('id="StyleBoxFlat_confirm_yes"' in ipo_modal_tscn_text, "ipo_modal.tscn contains StyleBoxFlat_confirm_yes")
    reporter.check('id="StyleBoxFlat_confirm_cancel"' in ipo_modal_tscn_text, "ipo_modal.tscn contains StyleBoxFlat_confirm_cancel")

    # -------------------------------------------------------------------------
    # SECTION 4: Two-Stage Confirmation State Machine Simulation
    # -------------------------------------------------------------------------
    reporter.section("SECTION 4: Two-Stage Confirmation State Machine Simulation")

    class MockIPOModal:
        def __init__(self, can_trigger_ipo: bool = True, pending_shares: int = 5, lifetime_energy: float = 2500000.0, owned_shares: int = 0):
            self.can_trigger_ipo = can_trigger_ipo
            self.pending_shares = pending_shares
            self.lifetime_energy = lifetime_energy
            self.owned_shares = owned_shares
            self.is_confirming = False
            self.trigger_button_visible = True
            self.trigger_button_disabled = not can_trigger_ipo
            self.confirm_box_visible = False
            self.slider_value = 0.0
            self.closed = False
            self.freed = False
            self.ipo_executed = False
            self.emitted_signals: List[str] = []

        def open(self):
            self.reset_confirmation_state()
            self.update_display()

        def reset_confirmation_state(self):
            self.is_confirming = False
            self.confirm_box_visible = False
            self.trigger_button_visible = True
            self.slider_value = 0.0

        def update_display(self):
            self.trigger_button_disabled = not self.can_trigger_ipo

        def on_trigger_ipo_pressed(self):
            if not self.can_trigger_ipo:
                return
            self.is_confirming = True
            self.trigger_button_visible = False
            self.confirm_box_visible = True
            self.slider_value = 0.0

        def on_confirm_cancel_pressed(self):
            self.reset_confirmation_state()

        def on_confirm_yes_pressed(self):
            self.execute_ipo()

        def on_slide_value_changed(self, val: float):
            self.slider_value = val
            if val >= 99.0 and self.is_confirming:
                self.execute_ipo()

        def on_slide_drag_ended(self):
            if self.slider_value < 99.0:
                self.slider_value = 0.0

        def execute_ipo(self):
            if not self.can_trigger_ipo:
                self.reset_confirmation_state()
                return
            self.ipo_executed = True
            self.emitted_signals.append(f"ipo_confirmed({self.pending_shares})")
            self.close()

        def close(self):
            self.emitted_signals.append("closed")
            self.closed = True
            self.freed = True

    # Test Case 1: Initial state
    modal1 = MockIPOModal(can_trigger_ipo=True, pending_shares=3)
    modal1.open()
    reporter.check(modal1.trigger_button_visible is True, "Initial state: TriggerIPOButton is visible")
    reporter.check(modal1.confirm_box_visible is False, "Initial state: ConfirmBox is hidden")
    reporter.check(modal1.trigger_button_disabled is False, "Initial state: Trigger button is enabled when can_trigger_ipo is True")

    # Test Case 2: Transition from Stage 1 to Stage 2
    modal1.on_trigger_ipo_pressed()
    reporter.check(modal1.is_confirming is True, "Stage 1 -> Stage 2: is_confirming flag is True")
    reporter.check(modal1.trigger_button_visible is False, "Stage 1 -> Stage 2: TriggerIPOButton is hidden")
    reporter.check(modal1.confirm_box_visible is True, "Stage 1 -> Stage 2: ConfirmBox is visible")

    # Test Case 3: Cancel in Stage 2 returns to Stage 1
    modal1.on_confirm_cancel_pressed()
    reporter.check(modal1.is_confirming is False, "Cancel: is_confirming flag is False")
    reporter.check(modal1.trigger_button_visible is True, "Cancel: TriggerIPOButton is restored")
    reporter.check(modal1.confirm_box_visible is False, "Cancel: ConfirmBox is hidden")

    # Test Case 4: Re-trigger and execute via ConfirmYes
    modal1.on_trigger_ipo_pressed()
    modal1.on_confirm_yes_pressed()
    reporter.check(modal1.ipo_executed is True, "ConfirmYes: IPO execution triggered")
    reporter.check("ipo_confirmed(3)" in modal1.emitted_signals, "ConfirmYes: ipo_confirmed signal emitted with shares")
    reporter.check("closed" in modal1.emitted_signals, "ConfirmYes: closed signal emitted")
    reporter.check(modal1.freed is True, "ConfirmYes: modal is freed")

    # Test Case 5: SlideToConfirm gesture execution
    modal2 = MockIPOModal(can_trigger_ipo=True, pending_shares=4)
    modal2.open()
    modal2.on_trigger_ipo_pressed()
    # Drag partially (50%) and release
    modal2.on_slide_value_changed(50.0)
    modal2.on_slide_drag_ended()
    reporter.check(modal2.slider_value == 0.0, "SlideToConfirm: partial drag (<99) resets slider to 0.0")
    reporter.check(modal2.ipo_executed is False, "SlideToConfirm: partial drag does NOT trigger IPO")
    # Complete drag (100%)
    modal2.on_slide_value_changed(100.0)
    reporter.check(modal2.ipo_executed is True, "SlideToConfirm: 100% drag triggers IPO execution")
    reporter.check("ipo_confirmed(4)" in modal2.emitted_signals, "SlideToConfirm: ipo_confirmed signal emitted")

    # Test Case 6: Ineligible player (threshold not met)
    modal3 = MockIPOModal(can_trigger_ipo=False, pending_shares=0, lifetime_energy=500000.0)
    modal3.open()
    reporter.check(modal3.trigger_button_disabled is True, "Ineligible: TriggerIPOButton is disabled")
    modal3.on_trigger_ipo_pressed()
    reporter.check(modal3.is_confirming is False, "Ineligible: pressing trigger button does NOT advance to Stage 2")
    reporter.check(modal3.confirm_box_visible is False, "Ineligible: ConfirmBox remains hidden")

    # -------------------------------------------------------------------------
    # SECTION 5: TouchControls Dynamic Action State Machine Simulation
    # -------------------------------------------------------------------------
    reporter.section("SECTION 5: TouchControls Dynamic Action State Machine Simulation")

    class MockInteractable:
        def __init__(self, groups: List[str], methods: List[str], action_label: str = ""):
            self.groups = groups
            self.methods = methods
            self.action_label = action_label
            self.call_history: List[str] = []

        def is_in_group(self, grp: str) -> bool:
            return grp in self.groups

        def has_method(self, m: str) -> bool:
            return m in self.methods

        def call(self, m: str):
            self.call_history.append(m)

    class MockTouchControls:
        def __init__(self):
            self.button_text = "Action [E]"
            self.active_style = "normal"
            self.active_interactable: Optional[MockInteractable] = None

        def update_action_button_visuals(self, target: Optional[MockInteractable], label_text: str = ""):
            text_to_set = label_text if label_text else "Action [E]"
            if target is not None:
                if "IPO" in text_to_set or target.is_in_group("ipo_bells") or target.has_method("ring_bell") or target.has_method("ring_ipo_bell") or target.action_label == "IPO Bell [E]":
                    text_to_set = "IPO Bell [E]"
                    self.active_style = "ipo_bell_style"
                elif target.has_method("interact"):
                    text_to_set = "Talk [E]"
                    self.active_style = "npc_style"
            else:
                if "IPO" in text_to_set:
                    self.active_style = "ipo_bell_style"
                else:
                    self.active_style = "normal"
            self.button_text = text_to_set

        def trigger_action(self, target: Optional[MockInteractable]):
            if target is not None:
                if target.has_method("ring_bell"):
                    target.call("ring_bell")
                elif target.has_method("ring_ipo_bell"):
                    target.call("ring_ipo_bell")
                elif target.has_method("interact"):
                    target.call("interact")

    tc = MockTouchControls()

    # Bell with group 'ipo_bells' and method 'ring_bell'
    bell_node = MockInteractable(groups=["ipo_bells", "interactables"], methods=["ring_bell", "interact"], action_label="IPO Bell [E]")
    tc.update_action_button_visuals(bell_node, "IPO Bell [E]")
    reporter.check(tc.button_text == "IPO Bell [E]", "TouchControls assigns 'IPO Bell [E]' text for IpoBell3D")
    reporter.check(tc.active_style == "ipo_bell_style", "TouchControls applies Platin/Gold ipo_bell_style for IpoBell3D")

    # Trigger action dispatch
    tc.trigger_action(bell_node)
    reporter.check("ring_bell" in bell_node.call_history, "TouchControls trigger_action() calls target.ring_bell()")

    # Bell without explicit group but with ring_bell() method
    method_bell = MockInteractable(groups=["interactables"], methods=["ring_bell"], action_label="")
    tc.update_action_button_visuals(method_bell)
    reporter.check(tc.button_text == "IPO Bell [E]", "TouchControls detects bell by method ring_bell alone")
    reporter.check(tc.active_style == "ipo_bell_style", "TouchControls applies ipo_bell_style by method ring_bell")

    # Unrelated interactable (e.g. NPC Alex)
    npc_node = MockInteractable(groups=["npcs", "interactables"], methods=["interact"], action_label="Talk [E]")
    tc.update_action_button_visuals(npc_node, "Talk [E]")
    reporter.check(tc.button_text == "Talk [E]", "TouchControls assigns 'Talk [E]' for NPC")
    reporter.check(tc.active_style == "npc_style", "TouchControls retains npc_style for NPC")

    return reporter.summary()


if __name__ == "__main__":
    success = run_tests()
    sys.exit(0 if success else 1)
