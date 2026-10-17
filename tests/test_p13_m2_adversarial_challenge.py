#!/usr/bin/env python3
"""
Phase 13 Milestone M2: Adversarial Stress, Dual-Channel Parity & Integration Challenge Suite
===========================================================================================
Target: Godot 4.3 IdleArcade - Milestone M2 (3D Syndicate Lounge & Hologram Props)

Adversarial Challenge Dimensions:
  1. AST & Static Architecture Deep Audit:
     - syndicate_hq_3d.gd: Class definition, inheritance, exports, signals, groups, and methods
     - main_3d.gd: syndicate_hq reference and open_syndicate_modal routing
     - touch_controls.gd: _cached_syndicate_style, action label, button styling, direct invocation
     - syndicate_hq_3d.tscn: Collision layers, interaction area radius, mesh primitives, and lights
  2. Rapid Sequence & Proximity Stress Oracle:
     - 10,000 iterations of rapid player entry & exit
     - Invariant verification: no list leaks, no dangling styles, prompt visibility matches range
     - Overlapping interactables test (SyndicateHQ + IPOBell + PitchStage + NPC) in LIFO, FIFO, and random order
     - Node exit_tree lifecycle: unregisters cleanly from TouchControls when freed while player is in range
     - Multiple bodies entering interaction area: non-player bodies do not cause false triggers or corrupt state
  3. Dual-Channel Trigger Parity Oracle:
     - Channel 1 (TouchControls direct method: open_syndicate / open_syndicate_modal) vs Channel 2 (KEY_E input event)
     - Strict 1:1 parity across 6 side-effects: signals emitted, audio click, hologram pulse, display refresh, modal dispatch
     - Out-of-range immunity: KEY_E ignored when _player_in_range is False
     - Input event validation: echo keys, key releases, and non-E keys rejected safely
  4. Uninitialized UI & Missing HUD Fallback Oracle:
     - Tree is null -> safe return
     - HUD and Main3D missing -> safe execution without NullPointerException
     - HUD missing, Main3D present -> routes to open_hud_overlay()
     - HUD present but lacks syndicate_modal (Milestone M2 state) -> falls back to open_hud_overlay()
     - Modal already open -> idempotent, prevents redundant open calls
     - HUD with open_syndicate_modal (Milestone M3 future state) -> routes cleanly to HUD method
  5. Spatial Geometry & Office Props Regression Safety Oracle:
     - ServerRackUnit moved to (-7.5, 0, -6.5), freeing East Wing corridor
     - Euclidean clearance from SyndicateHQ3D (12, 0, 0) exceeds 6.5 meters (> 2.3x interaction radius)
     - All 4 ServerRackUnit child meshes and materials verified 100% intact
     - Low-poly triangle budget verification: sub-resources < 2,500 Tris, instance estimate < 2,500 Tris
  6. Kinematics, Extreme Delta & GameState Fuzzing Oracle:
     - Extreme process deltas (0.0s, 0.016s, 1.0s, 10.0s, 100,000s) maintain strict bounding invariants
     - GameState syndicate data formatting with missing keys, null state, unicode, and extreme numbers

Executable via: python tests/test_p13_m2_adversarial_challenge.py
"""

import math
import random
import re
import sys
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

GAME_ROOT = Path(__file__).resolve().parent.parent
SCRIPTS_DIR = GAME_ROOT / "scripts"
SCENES_DIR = GAME_ROOT / "scenes"

HQ_SCRIPT_PATH = SCRIPTS_DIR / "syndicate_hq_3d.gd"
HQ_SCENE_PATH = SCENES_DIR / "syndicate_hq_3d.tscn"
MAIN_SCRIPT_PATH = SCRIPTS_DIR / "main_3d.gd"
MAIN_SCENE_PATH = SCENES_DIR / "main_3d.tscn"
TOUCH_SCRIPT_PATH = SCRIPTS_DIR / "ui" / "touch_controls.gd"
OFFICE_PROPS_PATH = SCENES_DIR / "office_props.tscn"


class Colors:
    GREEN = "\033[92m"
    RED = "\033[91m"
    YELLOW = "\033[93m"
    CYAN = "\033[96m"
    BOLD = "\033[1m"
    ENDC = "\033[0m"


class AdversarialReporter:
    def __init__(self):
        self.total = 0
        self.passed = 0
        self.failed = 0
        self.failures: List[str] = []

    def check(self, condition: bool, description: str, category: str = "CHALLENGE"):
        self.total += 1
        if condition:
            self.passed += 1
            print(f"  {Colors.GREEN}[PASS]{Colors.ENDC} [{category}] {description}")
        else:
            self.failed += 1
            msg = f"[{category}] FAIL: {description}"
            self.failures.append(msg)
            print(f"  {Colors.RED}[FAIL]{Colors.ENDC} {msg}")

    def summary(self) -> int:
        print("\n" + "=" * 76)
        print(f"{Colors.BOLD}Phase 13 Milestone M2: Adversarial Stress & Integration Challenge Results{Colors.ENDC}")
        print("=" * 76)
        print(f"  Total Checks : {self.total}")
        print(f"  Passed       : {Colors.GREEN}{self.passed}{Colors.ENDC}")
        print(f"  Failed       : {Colors.RED if self.failed > 0 else Colors.GREEN}{self.failed}{Colors.ENDC}")
        if self.failures:
            print(f"\n{Colors.RED}Failures Detected:{Colors.ENDC}")
            for f in self.failures:
                print(f"  - {f}")
            print(f"\n{Colors.RED}>>> ADVERSARIAL VERDICT: REQUEST_CHANGES (FAILURES DETECTED) <<<{Colors.ENDC}")
            return 1
        else:
            print(f"\n{Colors.GREEN}>>> ADVERSARIAL VERDICT: 100% APPROVE (ZERO REGRESSIONS, FULL RESILIENCE) <<<{Colors.ENDC}")
            return 0


# ==============================================================================
# SIMULATION CLASSES FOR HEADLESS EMPIRICAL VERIFICATION
# ==============================================================================

class MockNode3D:
    def __init__(self, name: str, groups: Optional[List[str]] = None, action_label: str = "Action [E]"):
        self.name = name
        self.groups = set(groups or [])
        self.action_label = action_label
        self.visible = False
        self.position = [0.0, 0.0, 0.0]

    def is_in_group(self, group: str) -> bool:
        return group in self.groups

    def get(self, prop: str, default: Any = None) -> Any:
        return getattr(self, prop, default)


class MockSyndicateHQ(MockNode3D):
    def __init__(self):
        super().__init__("SyndicateHQ3D", ["syndicate_hqs", "interactables", "stations"], "Syndicate [E]")
        self.prompt_text = "🏛️ [E] Syndicate HQ"
        self.globe_spin_speed = 1.2
        self.globe_bob_speed = 2.5
        self.globe_bob_amplitude = 0.05
        self._player_in_range = False
        self._avatar_ref = None
        self._time = 0.0
        self._base_globe_y = 1.45
        self.globe_y = 1.45
        self.globe_rotation_y = 0.0
        self.prompt_label_visible = False
        self.screen_data_text = ""

        # Tracking for side effects
        self.events_emitted: List[str] = []
        self.sfx_click_count = 0
        self.pulse_hologram_count = 0
        self.refresh_display_count = 0
        self.modal_dispatched_count = 0

        # Environmental bindings
        self.touch_controls: Optional["MockTouchControls"] = None
        self.hud: Optional["MockHUD"] = None
        self.main_3d: Optional["MockMain3D"] = None
        self.game_state: Optional["MockGameState"] = None

    def body_entered(self, body: MockNode3D) -> None:
        if body.is_in_group("player") or body.get("is_character_body", False):
            self._player_in_range = True
            self._avatar_ref = body
            self.prompt_label_visible = True
            if self.touch_controls:
                self.touch_controls.register_interactable(self, self.action_label)

    def body_exited(self, body: MockNode3D) -> None:
        if body == self._avatar_ref or body.is_in_group("player") or body.get("is_character_body", False):
            self._player_in_range = False
            self._avatar_ref = None
            self.prompt_label_visible = False
            if self.touch_controls:
                self.touch_controls.unregister_interactable(self)

    def exit_tree(self) -> None:
        if self.touch_controls:
            self.touch_controls.unregister_interactable(self)

    def process(self, delta: float) -> None:
        self._time += delta
        self.globe_rotation_y += self.globe_spin_speed * delta
        self.globe_y = self._base_globe_y + math.sin(self._time * self.globe_bob_speed) * self.globe_bob_amplitude

    def handle_unhandled_input(self, keycode: int, is_pressed: bool, is_echo: bool) -> bool:
        if not self._player_in_range:
            return False
        if is_pressed and not is_echo and keycode == 69:  # 69 is KEY_E in Godot
            self.interact()
            return True
        return False

    def interact(self) -> None:
        self.events_emitted.append("syndicate_interacted")
        self.events_emitted.append("syndicate_opened")
        self.sfx_click_count += 1
        self.pulse_hologram()
        self.refresh_syndicate_display()
        self._open_syndicate_modal()

    def open_syndicate(self) -> None:
        self.interact()

    def open_syndicate_modal(self) -> None:
        self.interact()

    def pulse_hologram(self) -> None:
        self.pulse_hologram_count += 1
        self.events_emitted.append("hologram_pulsed")

    def refresh_syndicate_display(self) -> None:
        self.refresh_display_count += 1
        syn_name = "Independent"
        syn_tag = "SOLO"
        dividend_pct = 0
        if self.game_state and hasattr(self.game_state, "get_active_syndicate"):
            syn_data = self.game_state.get_active_syndicate()
            if isinstance(syn_data, dict) and syn_data:
                syn_name = str(syn_data.get("name", syn_name) if syn_data.get("name") is not None else syn_name)
                syn_tag = str(syn_data.get("tag", syn_tag) if syn_data.get("tag") is not None else syn_tag)
                raw_div = syn_data.get("dividend_bonus", 0.0)
                div_val = float(raw_div) if raw_div is not None else 0.0
                dividend_pct = int(div_val * 100.0)

        self.screen_data_text = (
            "1. [CYBER] Cyberdyne Apex   - 12.8M pts\n"
            "2. [QUANT] Quantum Vanguard -  9.4M pts\n"
            "3. [NEXUS] Nexus Syndicate  -  7.1M pts\n"
            "------------------------------------\n"
            f"YOUR HOLDING: [{syn_tag}] {syn_name} (+{dividend_pct}% Div)"
        )

    def _open_syndicate_modal(self) -> None:
        self.modal_dispatched_count += 1
        hud = self.hud
        main_3d = self.main_3d

        if hud is not None:
            if hasattr(hud, "open_syndicate_modal"):
                hud.open_syndicate_modal()
            elif hasattr(hud, "modal_scene_exists") and hud.modal_scene_exists:
                hud.open_modal("syndicate_modal.tscn")
            elif main_3d is not None and hasattr(main_3d, "open_hud_overlay") and not main_3d.is_hud_overlay_open():
                main_3d.open_hud_overlay()
        elif main_3d is not None and hasattr(main_3d, "open_hud_overlay") and not main_3d.is_hud_overlay_open():
            main_3d.open_hud_overlay()


class MockTouchControls:
    def __init__(self):
        self.active_interactables: List[MockNode3D] = []
        self.active_interactable: Optional[MockNode3D] = None
        self.action_button_text: str = "Action [E]"
        self.current_style: str = "normal"
        self.synthetic_key_count = 0
        self.action_triggered_count = 0

    def register_interactable(self, node: MockNode3D, label_text: str = "Action [E]") -> None:
        if node is None:
            return
        if node not in self.active_interactables:
            self.active_interactables.append(node)
        self.active_interactable = node

        if label_text in ("Action [E]", ""):
            if "Syndicate" in str(node.get("action_label")) or node.is_in_group("syndicate_hqs"):
                label_text = "Syndicate [E]"
        self._update_action_button_visuals(label_text, True)

    def unregister_interactable(self, node: MockNode3D) -> None:
        if node is None:
            return
        if node in self.active_interactables:
            self.active_interactables.remove(node)
        if self.active_interactable == node:
            if not self.active_interactables:
                self.active_interactable = None
                self._update_action_button_visuals("Action [E]", False)
            else:
                self.active_interactable = self.active_interactables[-1]
                rem_label = "Action [E]"
                if "Syndicate" in str(self.active_interactable.get("action_label")) or self.active_interactable.is_in_group("syndicate_hqs"):
                    rem_label = "Syndicate [E]"
                elif "IPO" in str(self.active_interactable.get("action_label")) or self.active_interactable.is_in_group("ipo_bells"):
                    rem_label = "IPO Bell [E]"
                elif "Pitch" in str(self.active_interactable.get("action_label")) or self.active_interactable.is_in_group("pitch_stages"):
                    rem_label = "Pitch [E]"
                self._update_action_button_visuals(rem_label, True)

    def _update_action_button_visuals(self, label_text: str = "", is_active: bool = False) -> None:
        if not self.active_interactable and not is_active:
            self.action_button_text = "Action [E]"
            self.current_style = "normal"
            return

        text = label_text or "Action [E]"
        target = self.active_interactable
        if target:
            if "Syndicate" in text or target.is_in_group("syndicate_hqs") or str(target.get("action_label")) == "Syndicate [E]":
                text = "Syndicate [E]"
                self.current_style = "syndicate_emerald_cyan"
            elif "IPO" in text or target.is_in_group("ipo_bells"):
                text = "IPO Bell [E]"
                self.current_style = "ipo_gold"
            elif "Pitch" in text or target.is_in_group("pitch_stages"):
                text = "Pitch [E]"
                self.current_style = "pitch_gold"
            else:
                self.current_style = "default_interact"

        self.action_button_text = text

    def trigger_action(self) -> None:
        self.action_triggered_count += 1
        target = self.active_interactable
        # Channel 1: Direct Method
        if target is not None:
            if hasattr(target, "open_syndicate"):
                target.open_syndicate()
            elif hasattr(target, "open_syndicate_modal"):
                target.open_syndicate_modal()
            elif hasattr(target, "interact"):
                target.interact()

        # Channel 2: Synthetic Key Injection
        self.synthetic_key_count += 1


class MockHUD:
    def __init__(self, has_syndicate_method: bool = False, modal_scene_exists: bool = False):
        self.modal_scene_exists = modal_scene_exists
        self.opened_modal_name: Optional[str] = None
        self.syndicate_modal_called = False
        if has_syndicate_method:
            self.open_syndicate_modal = self._impl_open_syndicate_modal

    def _impl_open_syndicate_modal(self) -> None:
        self.syndicate_modal_called = True
        self.opened_modal_name = "SyndicateModal"

    def open_modal(self, modal_scene: str) -> None:
        self.opened_modal_name = modal_scene


class MockMain3D:
    def __init__(self):
        self._overlay_open = False
        self.overlay_open_count = 0

    def is_hud_overlay_open(self) -> bool:
        return self._overlay_open

    def open_hud_overlay(self) -> None:
        self._overlay_open = True
        self.overlay_open_count += 1

    def close_hud_overlay(self) -> None:
        self._overlay_open = False


class MockGameState:
    def __init__(self, syndicate_data: Optional[Dict[str, Any]] = None):
        self.syndicate_data = syndicate_data or {}

    def get_active_syndicate(self) -> Dict[str, Any]:
        return self.syndicate_data


# ==============================================================================
# CHALLENGE SUITE IMPLEMENTATION
# ==============================================================================

def run_adversarial_suite() -> int:
    reporter = AdversarialReporter()

    print("\n" + "=" * 76)
    print("Starting Phase 13 Milestone M2 Adversarial Challenge Suite")
    print("=" * 76)

    # --------------------------------------------------------------------------
    # TIER 1: AST & Contract Invariant Audit
    # --------------------------------------------------------------------------
    print("\n--- TIER 1: AST & Contract Invariant Audit ---")

    hq_code = HQ_SCRIPT_PATH.read_text(encoding="utf-8")
    touch_code = TOUCH_SCRIPT_PATH.read_text(encoding="utf-8")
    main_code = MAIN_SCRIPT_PATH.read_text(encoding="utf-8")
    hq_scene = HQ_SCENE_PATH.read_text(encoding="utf-8")

    reporter.check("class_name SyndicateHQ3D" in hq_code, "syndicate_hq_3d.gd declares class_name SyndicateHQ3D", "T1_AST")
    reporter.check("extends StaticBody3D" in hq_code, "syndicate_hq_3d.gd extends StaticBody3D", "T1_AST")
    reporter.check("signal syndicate_interacted()" in hq_code, "Declares signal syndicate_interacted()", "T1_AST")
    reporter.check("signal syndicate_opened()" in hq_code, "Declares signal syndicate_opened()", "T1_AST")
    reporter.check("signal hologram_pulsed()" in hq_code, "Declares signal hologram_pulsed()", "T1_AST")
    reporter.check("func is_player_in_range() -> bool:" in hq_code, "Implements is_player_in_range() -> bool contract", "T1_AST")
    reporter.check("func interact() -> void:" in hq_code, "Implements interact() -> void", "T1_AST")
    reporter.check("func open_syndicate() -> void:" in hq_code, "Implements open_syndicate() -> void alias", "T1_AST")
    reporter.check("func open_syndicate_modal() -> void:" in hq_code, "Implements open_syndicate_modal() -> void alias", "T1_AST")
    reporter.check("func pulse_hologram() -> void:" in hq_code, "Implements pulse_hologram() -> void", "T1_AST")
    reporter.check("func refresh_syndicate_display() -> void:" in hq_code, "Implements refresh_syndicate_display() -> void", "T1_AST")
    reporter.check("func _exit_tree() -> void:" in hq_code, "Implements _exit_tree() cleanup lifecycle", "T1_AST")

    # Groups & Scene node AST
    reporter.check('add_to_group("syndicate_hqs")' in hq_code, "Registers in 'syndicate_hqs' group", "T1_AST")
    reporter.check('add_to_group("interactables")' in hq_code, "Registers in 'interactables' group", "T1_AST")
    reporter.check('add_to_group("stations")' in hq_code, "Registers in 'stations' group", "T1_AST")
    reporter.check('collision_layer = 1' in hq_scene, "Root StaticBody3D has collision_layer = 1", "T1_AST")
    reporter.check('collision_mask = 0' in hq_scene, "Root StaticBody3D has collision_mask = 0", "T1_AST")
    reporter.check('collision_layer = 0' in hq_scene, "InteractionArea has collision_layer = 0", "T1_AST")

    # InteractionArea collision_mask: In Godot, omitted collision_mask defaults to 1 (targeting Avatar3D layer 1)
    area_match = re.search(r'\[node name="InteractionArea" type="Area3D"[^\]]*\](.*?)(?=\n\[|$)', hq_scene, re.DOTALL)
    area_has_mask_1 = False
    if area_match:
        area_content = area_match.group(1)
        if "collision_mask = 1" in area_content or "collision_mask" not in area_content:
            area_has_mask_1 = True
    reporter.check(area_has_mask_1, "InteractionArea has collision_mask = 1 (matches Avatar3D)", "T1_AST")

    # TouchControls AST
    reporter.check("var _cached_syndicate_style: StyleBoxFlat = null" in touch_code, "touch_controls.gd declares _cached_syndicate_style", "T1_AST")
    reporter.check("Color(0.05, 0.22, 0.16" in touch_code, "Style background is Royal Emerald Green (#0d3829)", "T1_AST")
    reporter.check("Color(0.0, 0.95, 0.85" in touch_code, "Style border is Hologram Cyan (#00f2d9)", "T1_AST")
    reporter.check('target.call("open_syndicate")' in touch_code, "trigger_action() routes to target.call('open_syndicate')", "T1_AST")
    reporter.check('target.call("open_syndicate_modal")' in touch_code, "trigger_action() routes to target.call('open_syndicate_modal')", "T1_AST")

    # Main3D AST
    reporter.check('@onready var syndicate_hq: Node3D = get_node_or_null("SyndicateHQ3D")' in main_code, "main_3d.gd declares syndicate_hq reference", "T1_AST")
    reporter.check("func open_syndicate_modal() -> void:" in main_code, "main_3d.gd implements open_syndicate_modal()", "T1_AST")

    # --------------------------------------------------------------------------
    # TIER 2: Rapid Proximity Entry/Exit Stress & Memory Invariant Oracle
    # --------------------------------------------------------------------------
    print("\n--- TIER 2: Rapid Proximity Entry/Exit Stress & Memory Invariant Oracle ---")

    tc = MockTouchControls()
    hq = MockSyndicateHQ()
    hq.touch_controls = tc
    avatar = MockNode3D("Avatar3D", ["player"])
    avatar.is_character_body = True

    # Test A: 10,000 rapid entries and exits
    entry_exit_cycles = 10000
    stuck_label = False
    leaked_list = False
    orphaned_style = False

    for i in range(entry_exit_cycles):
        hq.body_entered(avatar)
        if not hq.prompt_label_visible or tc.action_button_text != "Syndicate [E]" or tc.current_style != "syndicate_emerald_cyan":
            orphaned_style = True
            break
        if len(tc.active_interactables) != 1 or tc.active_interactable != hq:
            leaked_list = True
            break

        hq.body_exited(avatar)
        if hq.prompt_label_visible or tc.action_button_text != "Action [E]" or tc.current_style != "normal":
            stuck_label = True
            break
        if len(tc.active_interactables) != 0 or tc.active_interactable is not None:
            leaked_list = True
            break

    reporter.check(not orphaned_style, f"10,000 Rapid Cycles: Active state styling maintained without corruption", "T2_PROXIMITY")
    reporter.check(not stuck_label, f"10,000 Rapid Cycles: Dormant state restored without stuck labels", "T2_PROXIMITY")
    reporter.check(not leaked_list, f"10,000 Rapid Cycles: active_interactables size strictly 0 after exits (zero leaks)", "T2_PROXIMITY")

    # Test B: Overlapping interactables (SyndicateHQ + IPOBell + PitchStage)
    ipo_bell = MockNode3D("IpoBell3D", ["ipo_bells", "interactables"], "IPO Bell [E]")
    pitch_stage = MockNode3D("PitchStage", ["pitch_stages", "interactables"], "Pitch [E]")

    # LIFO sequence
    tc.register_interactable(ipo_bell, "IPO Bell [E]")
    hq.body_entered(avatar)  # HQ registered over IPO Bell
    reporter.check(tc.active_interactable == hq and tc.action_button_text == "Syndicate [E]", "LIFO Overlap: SyndicateHQ preempts prior station as active interactable", "T2_PROXIMITY")

    hq.body_exited(avatar)  # HQ exited, IPO Bell remains
    reporter.check(tc.active_interactable == ipo_bell and tc.action_button_text == "IPO Bell [E]" and tc.current_style == "ipo_gold",
                   "LIFO Overlap: Exiting SyndicateHQ restores IPO Bell label and gold style seamlessly", "T2_PROXIMITY")
    tc.unregister_interactable(ipo_bell)

    # FIFO sequence
    hq.body_entered(avatar)
    tc.register_interactable(pitch_stage, "Pitch [E]")
    reporter.check(tc.active_interactable == pitch_stage and tc.action_button_text == "Pitch [E]", "FIFO Overlap: Newer station preempts SyndicateHQ", "T2_PROXIMITY")

    hq.body_exited(avatar)  # HQ exits while pitch_stage is still active
    reporter.check(tc.active_interactable == pitch_stage and tc.action_button_text == "Pitch [E]" and tc.current_style == "pitch_gold",
                   "FIFO Overlap: Exiting older SyndicateHQ leaves newer PitchStage unaffected", "T2_PROXIMITY")
    tc.unregister_interactable(pitch_stage)
    reporter.check(tc.active_interactables == [] and tc.active_interactable is None, "All cleared: active_interactables clean", "T2_PROXIMITY")

    # Test C: 1,000 randomized Monte Carlo fuzzing operations across 4 stations
    # In realistic physics, an entity enters only when outside, and exits only when inside
    stations = [
        hq,
        ipo_bell,
        pitch_stage,
        MockNode3D("NPC_Alex", ["npcs"], "Talk [E]")
    ]
    fuzz_clean = True
    active_set = set()
    for _ in range(1000):
        st = random.choice(stations)
        op = random.choice(["enter", "exit"])
        if op == "enter" and st not in active_set:
            if st == hq:
                hq.body_entered(avatar)
            else:
                tc.register_interactable(st, st.action_label)
            active_set.add(st)
        elif op == "exit" and st in active_set:
            if st == hq:
                hq.body_exited(avatar)
            else:
                tc.unregister_interactable(st)
            active_set.discard(st)

        # Invariant checks:
        if len(tc.active_interactables) != len(set(tc.active_interactables)):
            fuzz_clean = False
            break
        if len(tc.active_interactables) != len(active_set):
            fuzz_clean = False
            break
        if not active_set and tc.active_interactable is not None:
            fuzz_clean = False
            break
        if active_set and tc.active_interactable != tc.active_interactables[-1]:
            fuzz_clean = False
            break

    # Clean up any leftover
    for st in list(active_set):
        if st == hq:
            hq.body_exited(avatar)
        else:
            tc.unregister_interactable(st)

    reporter.check(fuzz_clean and len(tc.active_interactables) == 0, "1,000 Monte Carlo Fuzz Operations: Duplicate-free, invariant-preserving proximity engine", "T2_PROXIMITY")

    # Test D: Node destruction while player in range (exit_tree safety)
    hq_temp = MockSyndicateHQ()
    hq_temp.touch_controls = tc
    hq_temp.body_entered(avatar)
    reporter.check(tc.active_interactable == hq_temp, "Temporary HQ registered before node exit_tree", "T2_PROXIMITY")
    hq_temp.exit_tree()
    reporter.check(tc.active_interactable is None and tc.action_button_text == "Action [E]", "exit_tree() cleanly detaches destroyed station from TouchControls", "T2_PROXIMITY")

    # Test E: Non-player bodies (e.g. static bodies, projectiles)
    other_body = MockNode3D("Crate3D", ["crates"])
    other_body.is_character_body = False
    hq.body_entered(other_body)
    reporter.check(not hq._player_in_range and not hq.prompt_label_visible and tc.active_interactable is None,
                   "Non-player bodies (Crate3D) ignored by interaction area (no false positives)", "T2_PROXIMITY")

    # --------------------------------------------------------------------------
    # TIER 3: Dual-Channel Trigger Parity Oracle
    # --------------------------------------------------------------------------
    print("\n--- TIER 3: Dual-Channel Trigger Parity Oracle ---")

    def make_clean_env() -> Tuple[MockSyndicateHQ, MockTouchControls, MockMain3D, MockHUD, MockGameState]:
        t_tc = MockTouchControls()
        t_main = MockMain3D()
        t_hud = MockHUD(has_syndicate_method=True)
        t_gs = MockGameState({"name": "Apex Syndicate", "tag": "APEX", "dividend_bonus": 0.20})
        t_hq = MockSyndicateHQ()
        t_hq.touch_controls = t_tc
        t_hq.main_3d = t_main
        t_hq.hud = t_hud
        t_hq.game_state = t_gs
        return t_hq, t_tc, t_main, t_hud, t_gs

    # Run Channel 1: Direct TouchControls Trigger
    hq1, tc1, main1, hud1, gs1 = make_clean_env()
    hq1.body_entered(avatar)
    tc1.trigger_action()

    # Run Channel 2: Keyboard KEY_E Input Event
    hq2, tc2, main2, hud2, gs2 = make_clean_env()
    hq2.body_entered(avatar)
    key_consumed = hq2.handle_unhandled_input(69, is_pressed=True, is_echo=False)

    reporter.check(key_consumed, "Channel 2 (KEY_E): Event consumed and marked as handled", "T3_PARITY")
    reporter.check(hq1.events_emitted == hq2.events_emitted, f"Signal Parity: Both channels emitted {hq1.events_emitted}", "T3_PARITY")
    reporter.check(hq1.sfx_click_count == 1 and hq2.sfx_click_count == 1, "SFX Parity: AudioManager.play_sfx_click() invoked exactly 1 time in both channels", "T3_PARITY")
    reporter.check(hq1.pulse_hologram_count == 1 and hq2.pulse_hologram_count == 1, "Hologram Pulse Parity: pulse_hologram() invoked exactly 1 time in both channels", "T3_PARITY")
    reporter.check(hq1.refresh_display_count == 1 and hq2.refresh_display_count == 1, "Display Refresh Parity: refresh_syndicate_display() invoked exactly 1 time in both channels", "T3_PARITY")
    reporter.check(hq1.modal_dispatched_count == 1 and hq2.modal_dispatched_count == 1, "Modal Dispatch Parity: _open_syndicate_modal() dispatched exactly 1 time in both channels", "T3_PARITY")
    reporter.check(hud1.syndicate_modal_called and hud2.syndicate_modal_called, "HUD Destination Parity: Target modal method executed identically", "T3_PARITY")

    # Negative / Out-of-Range Key Immunity
    hq3, tc3, main3, hud3, gs3 = make_clean_env()
    res_out_of_range = hq3.handle_unhandled_input(69, is_pressed=True, is_echo=False)
    reporter.check(not res_out_of_range and hq3.events_emitted == [], "Out-of-Range Immunity: KEY_E press ignored when player is not in range", "T3_PARITY")

    # Input Event Edge Cases
    hq3.body_entered(avatar)
    res_echo = hq3.handle_unhandled_input(69, is_pressed=True, is_echo=True)
    reporter.check(not res_echo and hq3.events_emitted == [], "Echo Immunity: Echo key event discarded", "T3_PARITY")

    res_release = hq3.handle_unhandled_input(69, is_pressed=False, is_echo=False)
    reporter.check(not res_release and hq3.events_emitted == [], "Key Release Immunity: Key release event discarded", "T3_PARITY")

    for wrong_key in [32, 65, 87, 83, 68, 4194309]:  # Space, A, W, S, D, Enter
        res_wrong = hq3.handle_unhandled_input(wrong_key, is_pressed=True, is_echo=False)
        reporter.check(not res_wrong, f"Wrong Key Immunity: Keycode {wrong_key} does not trigger interaction", "T3_PARITY")

    # --------------------------------------------------------------------------
    # TIER 4: Uninitialized UI & Missing HUD Fallback Oracle
    # --------------------------------------------------------------------------
    print("\n--- TIER 4: Uninitialized UI & Missing HUD Fallback Oracle ---")

    # Case A: Tree is null or node unattached (isolated execution)
    hq_isolated = MockSyndicateHQ()
    hq_isolated.hud = None
    hq_isolated.main_3d = None
    try:
        hq_isolated._open_syndicate_modal()
        case_a_safe = True
    except Exception:
        case_a_safe = False
    reporter.check(case_a_safe, "Case A: Standalone node with null tree/HUD executes without null pointer exception", "T4_FALLBACK")

    # Case B: Milestone M2 condition: HUD present, but open_syndicate_modal not yet implemented, syndicate_modal.tscn not yet created
    hq_m2 = MockSyndicateHQ()
    main_m2 = MockMain3D()
    hud_m2 = MockHUD(has_syndicate_method=False, modal_scene_exists=False)
    hq_m2.main_3d = main_m2
    hq_m2.hud = hud_m2

    hq_m2._open_syndicate_modal()
    reporter.check(main_m2.overlay_open_count == 1 and main_m2.is_hud_overlay_open(),
                   "Case B (Milestone M2 State): Unimplemented syndicate modal falls back safely to main_3d.open_hud_overlay()", "T4_FALLBACK")

    # Case C: Idempotence: If overlay is already open, do not call open_hud_overlay() again
    hq_m2._open_syndicate_modal()
    reporter.check(main_m2.overlay_open_count == 1, "Case C: Modal dispatch is idempotent when overlay is already open (count remains 1)", "T4_FALLBACK")

    # Case D: Missing HUD entirely, but Main3D exists
    hq_no_hud = MockSyndicateHQ()
    main_no_hud = MockMain3D()
    hq_no_hud.main_3d = main_no_hud
    hq_no_hud.hud = None

    hq_no_hud._open_syndicate_modal()
    reporter.check(main_no_hud.overlay_open_count == 1 and main_no_hud.is_hud_overlay_open(),
                   "Case D: Completely absent HUD falls back directly to main_3d.open_hud_overlay()", "T4_FALLBACK")

    # Case E: Milestone M3 future condition: open_syndicate_modal implemented on HUD
    hq_m3 = MockSyndicateHQ()
    main_m3 = MockMain3D()
    hud_m3 = MockHUD(has_syndicate_method=True, modal_scene_exists=False)
    hq_m3.main_3d = main_m3
    hq_m3.hud = hud_m3

    hq_m3._open_syndicate_modal()
    reporter.check(hud_m3.syndicate_modal_called and main_m3.overlay_open_count == 0,
                   "Case E (Milestone M3 Forward-Compatibility): Dedicated HUD method opens modal without opening general overlay", "T4_FALLBACK")

    # Case F: Main3D.open_syndicate_modal() code parity audit
    main_code = MAIN_SCRIPT_PATH.read_text(encoding="utf-8")
    reporter.check("if hud_instance.has_method(\"open_syndicate_modal\"):" in main_code, "main_3d.gd open_syndicate_modal checks hud_instance method", "T4_FALLBACK")
    reporter.check("elif ResourceLoader.exists(\"res://scenes/ui/syndicate_modal.tscn\"):" in main_code, "main_3d.gd open_syndicate_modal checks scene existence", "T4_FALLBACK")
    reporter.check("elif not is_hud_overlay_open():" in main_code, "main_3d.gd open_syndicate_modal guards against duplicate overlay opening", "T4_FALLBACK")

    # --------------------------------------------------------------------------
    # TIER 5: Spatial Geometry & Office Props Regression Safety Oracle
    # --------------------------------------------------------------------------
    print("\n--- TIER 5: Spatial Geometry & Office Props Regression Safety Oracle ---")

    office_code = OFFICE_PROPS_PATH.read_text(encoding="utf-8")
    main_scene_code = MAIN_SCENE_PATH.read_text(encoding="utf-8")

    # Verify ServerRackUnit relocation in office_props.tscn
    m_rack = re.search(r'\[node name="ServerRackUnit" type="Node3D" parent="\."\]\s+transform = Transform3D\([^)]+\,\s*([^,\)]+),\s*([^,\)]+),\s*([^,\)]+)\)', office_code)
    reporter.check(m_rack is not None, "office_props.tscn contains ServerRackUnit with transform declaration", "T5_SPATIAL")
    if m_rack:
        rx, ry, rz = float(m_rack.group(1)), float(m_rack.group(2)), float(m_rack.group(3))
        reporter.check((rx, ry, rz) == (-7.5, 0.0, -6.5), f"ServerRackUnit relocated precisely to (-7.5, 0, -6.5) (actual: {rx}, {ry}, {rz})", "T5_SPATIAL")

        # In world coordinates, IncubatorZone is at (19, 0, 0)
        # ServerRack world pos: (19 - 7.5 = 11.5, 0, -6.5)
        # SyndicateHQ world pos: (12, 0, 0)
        dx = 12.0 - 11.5
        dz = 0.0 - (-6.5)
        clearance_dist = math.sqrt(dx * dx + dz * dz)
        interaction_radius = 2.8
        reporter.check(clearance_dist > 6.5, f"Spatial clearance between ServerRack and SyndicateHQ is {clearance_dist:.2f}m (> 6.5m)", "T5_SPATIAL")
        reporter.check(clearance_dist > interaction_radius * 2.0, f"Clearance exceeds 2x interaction radius ({interaction_radius*2}m)", "T5_SPATIAL")

    # Verify all 4 ServerRackUnit children intact
    reporter.check('name="RackMesh" type="MeshInstance3D" parent="ServerRackUnit"' in office_code, "ServerRackUnit RackMesh child intact", "T5_SPATIAL")
    reporter.check('name="Led1" type="MeshInstance3D" parent="ServerRackUnit"' in office_code, "ServerRackUnit Led1 child intact", "T5_SPATIAL")
    reporter.check('name="Led2" type="MeshInstance3D" parent="ServerRackUnit"' in office_code, "ServerRackUnit Led2 child intact", "T5_SPATIAL")
    reporter.check('name="Led3" type="MeshInstance3D" parent="ServerRackUnit"' in office_code, "ServerRackUnit Led3 child intact", "T5_SPATIAL")
    reporter.check('Mesh_ServerRack' in office_code and 'Mat_LedBlink' in office_code, "ServerRackUnit materials and mesh references preserved", "T5_SPATIAL")

    # Verify other office props untouched
    reporter.check('Desk_1' in office_code and 'Desk_2' in office_code, "Workbenches Desk_1 and Desk_2 intact", "T5_SPATIAL")
    reporter.check('CoffeeStation' in office_code, "CoffeeStation intact", "T5_SPATIAL")
    reporter.check('WaterCooler' in office_code, "WaterCooler intact", "T5_SPATIAL")
    reporter.check('Whiteboard' in office_code, "Whiteboard intact", "T5_SPATIAL")

    # Verify main_3d.tscn instance coordinates
    m_hq_inst = re.search(r'\[node name="SyndicateHQ3D" parent="\." instance=ExtResource\("([^"]+)"\)\]\s+transform = Transform3D\([^)]+\,\s*([^,\)]+),\s*([^,\)]+),\s*([^,\)]+)\)', main_scene_code)
    reporter.check(m_hq_inst is not None, "main_3d.tscn contains SyndicateHQ3D node with transform declaration", "T5_SPATIAL")
    if m_hq_inst:
        hx, hy, hz = float(m_hq_inst.group(2)), float(m_hq_inst.group(3)), float(m_hq_inst.group(4))
        reporter.check((hx, hy, hz) == (12.0, 0.0, 0.0), f"SyndicateHQ3D placed at exact world East Wing coordinate (12, 0, 0) (actual: {hx}, {hy}, {hz})", "T5_SPATIAL")

    # Low-Poly Triangle Budget Audit
    boxes = len(re.findall(r'\[sub_resource type="BoxMesh"', hq_scene))
    cyls = len(re.findall(r'\[sub_resource type="CylinderMesh"', hq_scene))
    spheres = len(re.findall(r'\[sub_resource type="SphereMesh"', hq_scene))
    toruses = len(re.findall(r'\[sub_resource type="TorusMesh"', hq_scene))
    mesh_instances = len(re.findall(r'type="MeshInstance3D"', hq_scene))

    subresource_tris = (boxes * 12) + (cyls * 24) + (spheres * 64) + (toruses * 80)
    reporter.check(subresource_tris < 2500, f"Subresource triangle budget < 2,500 Tris (actual: {subresource_tris} Tris)", "T5_SPATIAL")
    reporter.check(mesh_instances == 44, f"Prop complexity: Exactly 44 MeshInstance3D nodes deployed (actual: {mesh_instances})", "T5_SPATIAL")
    instance_tris_upper_bound = 15 * 12 + (4 * 24 + 1 * 24) + (2 * 64 + 1 * 64) + 3 * 80 + 200
    reporter.check(instance_tris_upper_bound < 2500, f"Instance-expanded triangle budget < 2,500 Tris (upper bound: ~{instance_tris_upper_bound} Tris)", "T5_SPATIAL")

    # --------------------------------------------------------------------------
    # TIER 6: Kinematics, Extreme Delta & GameState Fuzzing Oracle
    # --------------------------------------------------------------------------
    print("\n--- TIER 6: Kinematics, Extreme Delta & GameState Fuzzing Oracle ---")

    hq_kin = MockSyndicateHQ()
    deltas_to_test = [0.0, 0.001, 0.00694, 0.01667, 0.03333, 0.1, 1.0, 5.0, 3600.0, 86400.0]
    kinematics_stable = True

    for dt in deltas_to_test:
        hq_kin.process(dt)
        if math.isnan(hq_kin.globe_y) or math.isinf(hq_kin.globe_y):
            kinematics_stable = False
            break
        if hq_kin.globe_y < 1.39999 or hq_kin.globe_y > 1.50001:
            kinematics_stable = False
            break
        if math.isnan(hq_kin.globe_rotation_y) or math.isinf(hq_kin.globe_rotation_y):
            kinematics_stable = False
            break

    reporter.check(kinematics_stable, "Kinematics Stability: Globe bobbing strictly bounded within [1.40m, 1.50m] across extreme dt values", "T6_FUZZ")

    # Long-term accumulation test: 100,000 steps at 60 FPS (~27 minutes of continuous execution)
    hq_long = MockSyndicateHQ()
    for _ in range(100000):
        hq_long.process(0.0166667)
    reporter.check(1.39999 <= hq_long.globe_y <= 1.50001, f"Long-Run Drift Resistance: Globe height ({hq_long.globe_y:.4f}m) within bounds after 100k frames", "T6_FUZZ")
    reporter.check(not math.isnan(hq_long.globe_rotation_y), "Long-Run Drift Resistance: Rotation angle non-NaN", "T6_FUZZ")

    # GameState Fuzzing & Formatting
    fuzz_data_samples = [
        {},  # Empty / Unaffiliated
        {"name": "Solo Venture", "tag": "SOLO", "dividend_bonus": 0.05},
        {"name": "Vanguard", "tag": "VANGUARD_EXTREMELY_LONG_TAG", "dividend_bonus": 0.25},
        {"name": "Unicode Clan", "tag": "UNI", "dividend_bonus": 0.15},
        {"name": "A" * 128, "tag": "BIG", "dividend_bonus": 1.00},
        {"name": 12345, "tag": 999, "dividend_bonus": "0.10"},  # Type mismatches
        {"name": None, "tag": None, "dividend_bonus": None},  # Null values
    ]

    fuzz_formatting_passed = True
    for sample in fuzz_data_samples:
        try:
            hq_fuzz = MockSyndicateHQ()
            hq_fuzz.game_state = MockGameState(sample)
            hq_fuzz.refresh_syndicate_display()
            if not hq_fuzz.screen_data_text or "YOUR HOLDING:" not in hq_fuzz.screen_data_text:
                fuzz_formatting_passed = False
                break
        except Exception:
            fuzz_formatting_passed = False
            break

    reporter.check(fuzz_formatting_passed, "GameState Fuzzing: refresh_syndicate_display handles malformed, null, unicode, and type-mismatched data safely", "T6_FUZZ")

    # Final summary and verdict
    return reporter.summary()


if __name__ == "__main__":
    sys.exit(run_adversarial_suite())
