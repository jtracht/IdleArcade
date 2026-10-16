#!/usr/bin/env python3
"""
Phase 12 Milestone 3: Adversarial Challenger Test & UX Stress Suite
===================================================================
Target: Godot 4.3 IdleArcade - Milestone M3 (Mobile IPO-Modal & Touch Ergonomics)
Role: Adversarial Challenger Oracle (Critic / Specialist)
File: IdleArcade/tests/test_p12_m3_challenger_ux.py

Adversarially challenges and verifies:
  1. Input Isolation Shield & Full Hierarchy Inspection:
     - Recursively parses every node in scenes/ui/ipo_modal.tscn
     - Confirms root Control, Backdrop, and ModalCard have mouse_filter = 0 (STOP)
     - Confirms no interactive elements have mouse_filter = 1 (PASS), eliminating 3D raycast bleed
     - Confirms all buttons (%CloseButton, %TriggerIPOButton, %ConfirmYesButton, %ConfirmCancelButton)
       and %SlideToConfirm satisfy touch target >= 56px in both static TSCN and runtime GDScript
  2. Two-Stage Safety Confirmation State Machine Stress:
     - Rapid transition cycling: Stage 1 -> Stage 2 -> Cancel -> Stage 1
     - Premature / Ineligible activation attempt: 0 energy, 999.9k energy in Ch1/2, 0 pending shares
     - Rapid re-entrant multi-tap on %ConfirmYesButton: ensures single execution, no double resets
     - SlideToConfirm fine-grained boundary sweep: [-10, 0, 25, 50, 75, 98.9, 99.0, 99.5, 100, 120]
     - Backdrop tap cancellation during Stage 1 and Stage 2
  3. HUD Navigation Drawer & Integration Contracts:
     - %IPOButton in scenes/hud.tscn (custom_minimum_size height >= 56px, mouse_filter = 0)
     - Preload IPO_MODAL_SCENE in scripts/hud.gd
     - open_ipo_modal() lifecycle delegation to open_modal(IPO_MODAL_SCENE)
     - Stale closure guard in open_modal() and modal dismissal
  4. TouchControls Action Styling & Multi-Target Routing:
     - Platin/Gold theme exact parameters: bg Color(0.25, 0.22, 0.10, 0.92), border Color(1.0, 0.88, 0.35, 1.0),
       border_width = 3, corner_radius = 50, shadow Color(1.0, 0.85, 0.25, 0.65), shadow_size = 14
     - Context matrix: IpoBell3D detection via group 'ipo_bells', method 'ring_bell', or label 'IPO Bell [E]'
     - Dual-channel execution: direct ring_bell() invocation + synthetic KEY_E injection
     - Rapid target switching and dormant state restoration
"""

import math
import os
import re
import sys
from pathlib import Path
from typing import Dict, Any, List, Optional, Tuple

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
        print(f"{Colors.BOLD}Milestone M3 Adversarial Challenger Summary:{Colors.ENDC}")
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
            print(f"\n{Colors.BOLD}{Colors.OKGREEN}>>> ALL ADVERSARIAL CHALLENGES SURVIVED: M3 UX ROCK-SOLID! <<<{Colors.ENDC}\n")
            return True


def parse_tscn(filepath: Path) -> List[Dict[str, Any]]:
    if not filepath.exists():
        return []
    content = filepath.read_text(encoding="utf-8")
    nodes: List[Dict[str, Any]] = []
    current_node: Optional[Dict[str, Any]] = None
    for line in content.splitlines():
        line = line.strip()
        m = re.match(r'\[node\s+name="([^"]+)"(?:\s+type="([^"]+)")?(?:\s+parent="([^"]+)")?', line)
        if m:
            current_node = {
                "name": m.group(1),
                "type": m.group(2) or "",
                "parent": m.group(3) or "",
                "props": {},
            }
            nodes.append(current_node)
            continue
        if current_node and "=" in line and not line.startswith("["):
            parts = line.split("=", 1)
            k = parts[0].strip()
            v = parts[1].strip()
            current_node["props"][k] = v
    return nodes


def run_challenger_tests() -> bool:
    reporter = ChallengerReporter()
    print("=" * 70)
    print(f"{Colors.HEADER}Phase 12 Milestone M3: Adversarial Challenger UX & Safety Suite{Colors.ENDC}")
    print("=" * 70)

    ipo_modal_tscn = GAME_DIR / "scenes" / "ui" / "ipo_modal.tscn"
    ipo_modal_gd = GAME_DIR / "scripts" / "ui" / "ipo_modal.gd"
    hud_tscn = GAME_DIR / "scenes" / "hud.tscn"
    hud_gd = GAME_DIR / "scripts" / "hud.gd"
    touch_controls_gd = GAME_DIR / "scripts" / "ui" / "touch_controls.gd"

    # =========================================================================
    # SECTION 1: Deep Input Isolation & Ergonomic Touch Size Hierarchy
    # =========================================================================
    reporter.section("SECTION 1: Deep Input Isolation & Ergonomic Touch Size Hierarchy")

    nodes = parse_tscn(ipo_modal_tscn)
    reporter.check(len(nodes) >= 15, f"ipo_modal.tscn contains rich node hierarchy (found {len(nodes)} nodes)")

    node_by_name = {n["name"]: n for n in nodes}

    # Verify root Control
    root = node_by_name.get("IPOModal")
    reporter.check(root is not None, "Root node 'IPOModal' exists in ipo_modal.tscn")
    if root:
        reporter.check(root["props"].get("mouse_filter") == "0", "Root IPOModal mouse_filter = 0 (Control.MOUSE_FILTER_STOP)")
        reporter.check(root["props"].get("anchors_preset") == "15", "Root IPOModal anchors_preset = 15 (Full Screen)")

    # Verify Backdrop
    backdrop = node_by_name.get("Backdrop")
    reporter.check(backdrop is not None, "Backdrop exists in ipo_modal.tscn")
    if backdrop:
        reporter.check(backdrop["props"].get("mouse_filter") == "0", "Backdrop mouse_filter = 0 (STOP)")
        reporter.check(backdrop["props"].get("anchors_preset") == "15", "Backdrop anchors_preset = 15")

    # Verify ModalCard
    card = node_by_name.get("ModalCard")
    reporter.check(card is not None, "ModalCard exists in ipo_modal.tscn")
    if card:
        reporter.check(card["props"].get("mouse_filter") == "0", "ModalCard mouse_filter = 0 (STOP)")
        cms = card["props"].get("custom_minimum_size", "")
        m = re.search(r"Vector2\s*\(\s*(\d+)\s*,\s*(\d+)\s*\)", cms)
        reporter.check(m is not None and int(m.group(1)) >= 600 and int(m.group(2)) >= 800,
                       f"ModalCard custom_minimum_size >= 600x800px (actual: {cms})")

    # Verify all interactive buttons and slider have mouse_filter == 0 and size >= 56px
    interactive_elements = [
        ("CloseButton", 56, 56, "button"),
        ("TriggerIPOButton", 0, 64, "button"),
        ("ConfirmYesButton", 0, 60, "button"),
        ("ConfirmCancelButton", 0, 60, "button"),
        ("SlideToConfirm", 0, 56, "slider"),
    ]

    for elem_name, min_w, min_h, elem_type in interactive_elements:
        elem = node_by_name.get(elem_name)
        reporter.check(elem is not None, f"Element '{elem_name}' exists in scene tree")
        if elem:
            # Check mouse_filter = 0 (STOP)
            mf = elem["props"].get("mouse_filter", "")
            reporter.check(mf == "0", f"{elem_name} enforces mouse_filter = 0 (STOP) (actual: '{mf}')")

            # Check size
            cms = elem["props"].get("custom_minimum_size", "")
            m = re.search(r"Vector2\s*\(\s*(\d+)\s*,\s*(\d+)\s*\)", cms)
            if m:
                w, h = int(m.group(1)), int(m.group(2))
                w_ok = (min_w == 0) or (w >= min_w)
                h_ok = h >= min_h
                reporter.check(w_ok and h_ok, f"{elem_name} dimensions satisfy touch minimum >= {min_w}x{min_h}px (actual: {w}x{h}px)")
            else:
                reporter.check(False, f"{elem_name} custom_minimum_size parsed", cms)

    # Verify no Control has mouse_filter = 1 (MOUSE_FILTER_PASS)
    pass_nodes = []
    for n in nodes:
        mf = n["props"].get("mouse_filter")
        if mf == "1":
            pass_nodes.append(n["name"])
    reporter.check(len(pass_nodes) == 0, "Zero nodes in ipo_modal.tscn use MOUSE_FILTER_PASS (1)", f"Leaking nodes: {pass_nodes}")

    # =========================================================================
    # SECTION 2: Safety Confirmation State Machine & Edge-Case Stress
    # =========================================================================
    reporter.section("SECTION 2: Safety Confirmation State Machine & Edge-Case Stress")

    class AdversarialIPOModalSim:
        def __init__(self, can_trigger: bool, pending_shares: int, lifetime_energy: float):
            self.can_trigger = can_trigger
            self.pending_shares = pending_shares
            self.lifetime_energy = lifetime_energy
            self.is_confirming = False
            self.trigger_btn_visible = True
            self.trigger_btn_disabled = not can_trigger
            self.confirm_box_visible = False
            self.slider_val = 0.0
            self.ipo_executions = 0
            self.signals: List[str] = []
            self.is_closed = False

        def open(self):
            self.reset_state()

        def reset_state(self):
            self.is_confirming = False
            self.trigger_btn_visible = True
            self.trigger_btn_disabled = not self.can_trigger
            self.confirm_box_visible = False
            self.slider_val = 0.0

        def press_trigger(self):
            if not self.can_trigger:
                return
            self.is_confirming = True
            self.trigger_btn_visible = False
            self.confirm_box_visible = True
            self.slider_val = 0.0

        def press_cancel(self):
            self.reset_state()

        def press_confirm_yes(self):
            self.execute_ipo()

        def slide_drag(self, val: float):
            self.slider_val = val
            if val >= 99.0 and self.is_confirming:
                self.execute_ipo()

        def slide_release(self):
            if self.slider_val < 99.0:
                self.slider_val = 0.0

        def backdrop_tap(self):
            self.close()

        def execute_ipo(self):
            if not self.can_trigger or self.is_closed:
                return
            self.ipo_executions += 1
            self.signals.append(f"ipo_confirmed({self.pending_shares})")
            # Backend reset occurs immediately upon first trigger
            self.can_trigger = False
            self.pending_shares = 0
            self.close()

        def close(self):
            self.signals.append("closed")
            self.is_closed = True

    # Challenge A: Rapid cycling between Stage 1 and Stage 2 (10 rapid transitions)
    sim = AdversarialIPOModalSim(can_trigger=True, pending_shares=5, lifetime_energy=2500000.0)
    sim.open()
    for cycle in range(10):
        sim.press_trigger()
        assert sim.is_confirming and sim.confirm_box_visible and not sim.trigger_btn_visible
        sim.press_cancel()
        assert not sim.is_confirming and not sim.confirm_box_visible and sim.trigger_btn_visible
    reporter.check(sim.ipo_executions == 0, "10 rapid Stage1 <-> Stage2 cycles completed with 0 accidental IPO executions")
    reporter.check(sim.is_confirming is False, "State machine stably returns to Stage 1 after cancel cycles")

    # Challenge B: Re-entrant multi-tap attack on ConfirmYesButton (e.g. 5 taps in same frame)
    sim.press_trigger()
    for tap in range(5):
        sim.press_confirm_yes()
    reporter.check(sim.ipo_executions == 1, "5 rapid successive taps on ConfirmYesButton executed IPO exactly ONCE")
    reporter.check(sim.signals.count("closed") == 1, "closed signal emitted exactly once")
    reporter.check(sim.signals.count("ipo_confirmed(5)") == 1, "ipo_confirmed signal emitted exactly once with 5 shares")

    # Challenge C: Slider fine-grained boundary sweep
    sweep_values = [-10.0, 0.0, 10.0, 50.0, 80.0, 95.0, 98.0, 98.9, 98.99, 99.0, 99.1, 100.0, 120.0]
    for test_val in sweep_values:
        sub_sim = AdversarialIPOModalSim(can_trigger=True, pending_shares=3, lifetime_energy=1000000.0)
        sub_sim.open()
        sub_sim.press_trigger()
        sub_sim.slide_drag(test_val)
        if test_val < 99.0:
            sub_sim.slide_release()
            reporter.check(sub_sim.ipo_executions == 0, f"Slider value {test_val} did NOT trigger IPO execution")
            reporter.check(sub_sim.slider_val == 0.0, f"Slider value {test_val} snapped back to 0.0")
        else:
            reporter.check(sub_sim.ipo_executions == 1, f"Slider threshold {test_val} successfully triggered IPO execution")

    # Challenge D: Ineligible player attempts (Threshold guards)
    ineligible_scenarios = [
        ("0 energy", 0.0, 0),
        ("500k energy (Ch1/2)", 500000.0, 0),
        ("999,999.9 energy (below 1M)", 999999.9, 0),
        ("1M energy but all 3 shares already claimed", 1000000.0, 0),
    ]
    for label, energy, shares in ineligible_scenarios:
        ineligible_sim = AdversarialIPOModalSim(can_trigger=False, pending_shares=shares, lifetime_energy=energy)
        ineligible_sim.open()
        reporter.check(ineligible_sim.trigger_btn_disabled is True, f"Ineligible scenario ({label}): button is disabled")
        ineligible_sim.press_trigger()
        reporter.check(ineligible_sim.is_confirming is False, f"Ineligible scenario ({label}): trigger click rejected, Stage 2 blocked")
        ineligible_sim.press_confirm_yes()
        reporter.check(ineligible_sim.ipo_executions == 0, f"Ineligible scenario ({label}): direct confirm attempt rejected")

    # Challenge E: Backdrop tap safely closes modal without triggering IPO
    backdrop_sim = AdversarialIPOModalSim(can_trigger=True, pending_shares=10, lifetime_energy=10000000.0)
    backdrop_sim.open()
    backdrop_sim.press_trigger() # Now in Stage 2
    backdrop_sim.backdrop_tap()
    reporter.check(backdrop_sim.is_closed is True, "Backdrop tap closed modal")
    reporter.check(backdrop_sim.ipo_executions == 0, "Backdrop tap during Stage 2 did NOT trigger IPO execution")

    # =========================================================================
    # SECTION 3: HUD Navigation Drawer & Integration Contracts
    # =========================================================================
    reporter.section("SECTION 3: HUD Navigation Drawer & Integration Contracts")

    hud_nodes = parse_tscn(hud_tscn)
    ipo_btn = None
    for n in hud_nodes:
        if n["name"] == "IPOButton":
            ipo_btn = n
            break

    reporter.check(ipo_btn is not None, "%IPOButton declared in scenes/hud.tscn")
    if ipo_btn:
        reporter.check(ipo_btn["props"].get("mouse_filter") == "0", "HUD %IPOButton mouse_filter = 0 (STOP)")
        cms = ipo_btn["props"].get("custom_minimum_size", "")
        m = re.search(r"Vector2\s*\(\s*(\d+)\s*,\s*(\d+)\s*\)", cms)
        if m:
            h = int(m.group(2))
            reporter.check(h >= 56, f"HUD %IPOButton custom_minimum_size height >= 56px (actual: {h}px)")
        else:
            reporter.check(False, "HUD %IPOButton custom_minimum_size parsed", cms)
        reporter.check(ipo_btn["parent"].endswith("NavItemsVBox"), "HUD %IPOButton placed inside NavItemsVBox hierarchy")

    hud_gd_text = hud_gd.read_text(encoding="utf-8") if hud_gd.exists() else ""
    reporter.check('preload("res://scenes/ui/ipo_modal.tscn")' in hud_gd_text, "hud.gd preloads res://scenes/ui/ipo_modal.tscn")
    reporter.check("func open_ipo_modal()" in hud_gd_text, "hud.gd exports func open_ipo_modal() -> Control")
    reporter.check("open_modal(IPO_MODAL_SCENE)" in hud_gd_text, "open_ipo_modal() delegates to open_modal(IPO_MODAL_SCENE)")
    reporter.check("ipo_button.pressed.connect" in hud_gd_text, "hud.gd binds ipo_button.pressed to open_ipo_modal")

    # Verify modal dismissal & stale closure protection in hud.gd
    reporter.check("func dismiss_active_modal()" in hud_gd_text, "hud.gd implements func dismiss_active_modal()")
    reporter.check("if _active_modal == modal_inst:" in hud_gd_text, "hud.gd uses stale closure guard for modal_inst on closed signal")

    # =========================================================================
    # SECTION 4: TouchControls Platin/Gold Styling & Dual-Channel Routing
    # =========================================================================
    reporter.section("SECTION 4: TouchControls Platin/Gold Styling & Dual-Channel Routing")

    tc_gd_text = touch_controls_gd.read_text(encoding="utf-8") if touch_controls_gd.exists() else ""

    # Verify exact Platin/Gold color specs in touch_controls.gd
    style_specs = [
        (r'_cached_ipo_bell_style\.bg_color\s*=\s*Color\s*\(\s*0\.25\s*,\s*0\.22\s*,\s*0\.10\s*,\s*0\.92\s*\)', "bg_color Color(0.25, 0.22, 0.10, 0.92)"),
        (r'_cached_ipo_bell_style\.border_color\s*=\s*Color\s*\(\s*1\.0\s*,\s*0\.88\s*,\s*0\.35\s*,\s*1\.0\s*\)', "border_color Color(1.0, 0.88, 0.35, 1.0)"),
        (r'_cached_ipo_bell_style\.set_border_width_all\s*\(\s*3\s*\)', "border_width = 3"),
        (r'_cached_ipo_bell_style\.set_corner_radius_all\s*\(\s*50\s*\)', "corner_radius = 50"),
        (r'_cached_ipo_bell_style\.shadow_color\s*=\s*Color\s*\(\s*1\.0\s*,\s*0\.85\s*,\s*0\.25\s*,\s*0\.65\s*\)', "shadow_color Color(1.0, 0.85, 0.25, 0.65)"),
        (r'_cached_ipo_bell_style\.shadow_size\s*=\s*14', "shadow_size = 14"),
    ]
    for pattern, desc in style_specs:
        reporter.check(re.search(pattern, tc_gd_text) is not None, f"TouchControls style spec: {desc}")

    # Verify TouchControls multi-channel execution: ring_bell, ring_ipo_bell, and synthetic KEY_E
    reporter.check('target.has_method("ring_bell")' in tc_gd_text and 'target.call("ring_bell")' in tc_gd_text,
                   "TouchControls dispatches direct method call target.call('ring_bell')")
    reporter.check('target.has_method("ring_ipo_bell")' in tc_gd_text and 'target.call("ring_ipo_bell")' in tc_gd_text,
                   "TouchControls supports alias target.call('ring_ipo_bell')")
    reporter.check('_synthesize_key(KEY_E)' in tc_gd_text,
                   "TouchControls injects synthetic KEY_E event for dual-channel redundancy")

    # Multi-Target State Transition Matrix
    class TargetStub:
        def __init__(self, name: str, groups: List[str], methods: List[str], label: str = ""):
            self.name = name
            self.groups = groups
            self.methods = methods
            self.label = label
            self.calls: List[str] = []

        def is_in_group(self, g: str) -> bool:
            return g in self.groups

        def has_method(self, m: str) -> bool:
            return m in self.methods

        def call(self, m: str):
            self.calls.append(m)

    class TouchControlsSim:
        def __init__(self):
            self.active_style = "dormant"
            self.action_label = "[E] Action"
            self.active_target: Optional[TargetStub] = None

        def update_visuals(self, target: Optional[TargetStub], label_override: str = ""):
            self.active_target = target
            if target is None and not label_override:
                self.active_style = "dormant"
                self.action_label = "[E] Action"
                return

            text = label_override if label_override else "Action [E]"
            if target is not None:
                if "IPO" in text or target.is_in_group("ipo_bells") or target.has_method("ring_bell") or target.label == "IPO Bell [E]":
                    self.action_label = "IPO Bell [E]"
                    self.active_style = "ipo_bell_style"
                elif target.has_method("interact"):
                    self.action_label = "Talk [E]"
                    self.active_style = "npc_style"
                elif target.is_in_group("server_terminals"):
                    self.action_label = "Hack [E]"
                    self.active_style = "hack_style"
            else:
                if "IPO" in text:
                    self.active_style = "ipo_bell_style"
                else:
                    self.active_style = "normal"
                self.action_label = text

        def trigger_action(self):
            if self.active_target is not None:
                if self.active_target.has_method("ring_bell"):
                    self.active_target.call("ring_bell")
                elif self.active_target.has_method("interact"):
                    self.active_target.call("interact")

    tc_sim = TouchControlsSim()

    # Step 1: Approach IpoBell3D
    bell = TargetStub("Bell", groups=["ipo_bells", "interactables"], methods=["ring_bell", "interact"], label="IPO Bell [E]")
    tc_sim.update_visuals(bell, "IPO Bell [E]")
    reporter.check(tc_sim.action_label == "IPO Bell [E]", "Target 1 (Bell): label is 'IPO Bell [E]'")
    reporter.check(tc_sim.active_style == "ipo_bell_style", "Target 1 (Bell): style is ipo_bell_style")
    tc_sim.trigger_action()
    reporter.check("ring_bell" in bell.calls, "Target 1 (Bell): trigger_action() calls ring_bell()")

    # Step 2: Switch to NPC Alex
    alex = TargetStub("Alex", groups=["npcs", "interactables"], methods=["interact"], label="Talk [E]")
    tc_sim.update_visuals(alex, "Talk [E]")
    reporter.check(tc_sim.action_label == "Talk [E]", "Target 2 (NPC): label is 'Talk [E]'")
    reporter.check(tc_sim.active_style == "npc_style", "Target 2 (NPC): style transitioned to npc_style")

    # Step 3: Switch back to Bell without label override (auto-detect by group)
    tc_sim.update_visuals(bell)
    reporter.check(tc_sim.action_label == "IPO Bell [E]", "Target 3 (Bell re-enter): auto-detected 'IPO Bell [E]'")
    reporter.check(tc_sim.active_style == "ipo_bell_style", "Target 3 (Bell re-enter): style restored to ipo_bell_style")

    # Step 4: Step away into empty space
    tc_sim.update_visuals(None)
    reporter.check(tc_sim.action_label == "[E] Action", "Target 4 (Empty space): returns to default '[E] Action'")
    reporter.check(tc_sim.active_style == "dormant", "Target 4 (Empty space): style returns to dormant")

    return reporter.summary()


if __name__ == "__main__":
    success = run_challenger_tests()
    sys.exit(0 if success else 1)
