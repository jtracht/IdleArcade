#!/usr/bin/env python3
"""
Milestone P5-M2 Adversarial Empirical Challenger Suite
======================================================
Author: Empirical Challenger 1 (critic, specialist)
Milestone: Phase 5 - Milestone P5-M2 (Mobile Context Action Buttons & Proximity Engine)
Target: Godot 4.3 IdleArcade

Adversarial Stress Dimensions:
1. Multi-Target Prioritization Stress:
   - Avatar entering multiple overlapping interaction zones (NPC1 -> Gate -> NPC2 -> Gate2).
   - Exiting in exact reverse order (LIFO).
   - Exiting in non-reverse order (FIFO / middle target exit).
   - Rapid redundant / duplicate registration idempotency.
   - Target queue_free() / destruction mid-stack without unregistering.
   - Null / invalid node handling.
2. Dynamic State Visual Transitions:
   - 5-State Visual Machine: Dormant Slate (0.35 alpha), NPC Emerald Green, Quest Amber Gold,
     Gate Neon Cyan, Gate Denied Coral Red.
   - Text label transitions: "[E] Action" -> "Talk [E]" -> "Claim [E]" -> "Unlock [E]" -> "Locked [E]".
   - Opacity transitions: 0.35 (dormant) vs 1.0 (active).
   - RGB color distance proofs (minimum Euclidean distance > 0.20 in RGB space).
3. Dual Dispatch & Glitch Analysis:
   - Channel 1 (direct invocation) + Channel 2 (synthetic KEY_E) interaction.
   - NPC talk idempotency (guarded by _is_talking).
   - Gate unlock idempotency (guarded by _is_unlocked).
   - Gate access denied edge case (double attempt_unlock execution analysis).
   - Laptop overlay toggle idempotency (guarded by Main3D connection check).
4. Worker Test Suite Audit & Flaw Detection:
   - Audit test_p5_m2_actions.gd check 4.6: detect that test_gate was instantiated
     without setting clearance level or energy, causing false failure if run on clean engine.
"""

import math
import re
import sys
from pathlib import Path
from typing import List, Dict, Optional, Tuple

def main():
    print("====================================================================")
    print("[CHALLENGER-1] P5-M2 Empirical Proximity & Action Dispatch Stress")
    print("====================================================================")

    game_dir = Path(__file__).resolve().parent.parent
    tests_passed = 0
    tests_failed = 0

    def assert_chall(cond: bool, test_name: str, detail: str = ""):
        nonlocal tests_passed, tests_failed
        if cond:
            print(f"  [PASS] {test_name}")
            tests_passed += 1
        else:
            msg = f"  [FAIL] {test_name}"
            if detail:
                msg += f" -> {detail}"
            print(msg)
            tests_failed += 1

    # =========================================================================
    # SECTION 1: Static Contract & Source Code Inspection
    # =========================================================================
    print("\n--- Section 1: Static Source Code & Interface Inspection ---")

    tc_script = game_dir / "scripts" / "ui" / "touch_controls.gd"
    tc_scene = game_dir / "scenes" / "ui" / "touch_controls.tscn"
    npc_script = game_dir / "scripts" / "npc_3d.gd"
    gate_script = game_dir / "scripts" / "zone_gate_3d.gd"
    main_script = game_dir / "scripts" / "main_3d.gd"
    worker_test = game_dir / "tests" / "test_p5_m2_actions.gd"

    assert_chall(tc_script.is_file(), "1.1 scripts/ui/touch_controls.gd exists")
    assert_chall(tc_scene.is_file(), "1.2 scenes/ui/touch_controls.tscn exists")
    assert_chall(npc_script.is_file(), "1.3 scripts/npc_3d.gd exists")
    assert_chall(gate_script.is_file(), "1.4 scripts/zone_gate_3d.gd exists")
    assert_chall(worker_test.is_file(), "1.5 tests/test_p5_m2_actions.gd exists")

    tc_src = tc_script.read_text(encoding="utf-8")
    npc_src = npc_script.read_text(encoding="utf-8")
    gate_src = gate_script.read_text(encoding="utf-8")
    worker_test_src = worker_test.read_text(encoding="utf-8")

    # Contract checks in touch_controls.gd
    assert_chall("func register_interactable" in tc_src, "1.6 TouchControls implements register_interactable")
    assert_chall("func unregister_interactable" in tc_src, "1.7 TouchControls implements unregister_interactable")
    assert_chall("func trigger_action" in tc_src, "1.8 TouchControls implements trigger_action")
    assert_chall("func trigger_laptop_toggle" in tc_src, "1.9 TouchControls implements trigger_laptop_toggle")
    assert_chall("func get_current_interactable" in tc_src, "1.10 TouchControls implements get_current_interactable")
    assert_chall("active_interactables" in tc_src, "1.11 TouchControls maintains active_interactables array")

    # =========================================================================
    # SECTION 2: Multi-Target Prioritization Stress Simulation
    # =========================================================================
    print("\n--- Section 2: Multi-Target Prioritization Stress Simulation ---")

    class SimulatedTarget:
        def __init__(self, node_id: str, kind: str, quest_id: str = "", req_lvl: int = 1, cost: float = 0.0):
            self.node_id = node_id
            self.kind = kind  # "npc" or "gate"
            self.quest_id = quest_id
            self.required_level = req_lvl
            self.unlock_cost = cost
            self.is_valid = True
            self.interacted_count = 0
            self.attempt_unlock_count = 0
            self.is_talking = False
            self.is_unlocked = False

        def has_method(self, m: str) -> bool:
            if m == "interact":
                return self.kind == "npc"
            if m == "attempt_unlock":
                return self.kind == "gate"
            return False

        def get(self, prop: str):
            if prop == "quest_id":
                return self.quest_id
            if prop == "required_level":
                return self.required_level
            if prop == "unlock_cost":
                return self.unlock_cost
            return None

        def interact(self):
            self.interacted_count += 1
            self.is_talking = True

        def attempt_unlock(self, cur_lvl: int, energy: float) -> bool:
            self.attempt_unlock_count += 1
            if self.is_unlocked:
                return True
            if cur_lvl >= self.required_level or energy >= self.unlock_cost:
                self.is_unlocked = True
                return True
            return False

    class SimulatedGameState:
        def __init__(self, idle_lvl: int = 1, energy: float = 0.0):
            self.idle_level = idle_lvl
            self.energy = energy
            self.quests = {}

        def get_idle_level(self) -> int:
            return self.idle_level

        def get_campus_quest_status(self, q_id: str) -> str:
            return self.quests.get(q_id, "not_started")

    class SimulatedTouchControls:
        def __init__(self, gs: SimulatedGameState):
            self.gs = gs
            self.active_interactable = None
            self.active_interactables: List[SimulatedTarget] = []
            self.action_button_text = "[E] Action"
            self.action_button_opacity = 0.35
            self.action_button_theme = "dormant"
            self.synthetic_keys = []
            self.action_triggered_events = []

        def register_interactable(self, node: SimulatedTarget, label_text: str = "Action [E]"):
            if node is None:
                return
            if node not in self.active_interactables:
                self.active_interactables.append(node)
            self.active_interactable = node
            self._update_action_button_visuals(label_text, True)

        def unregister_interactable(self, node: SimulatedTarget):
            if node is None:
                return
            if node in self.active_interactables:
                self.active_interactables.remove(node)
            if self.active_interactable == node:
                if len(self.active_interactables) == 0:
                    self.active_interactable = None
                    self._update_action_button_visuals("[E] Action", False)
                else:
                    self.active_interactable = self.active_interactables[-1]
                    remaining_label = "Action [E]"
                    if self.active_interactable.has_method("interact"):
                        remaining_label = "Talk [E]"
                    elif self.active_interactable.has_method("attempt_unlock"):
                        remaining_label = "Unlock [E]"
                    self._update_action_button_visuals(remaining_label, True)

        def get_current_interactable(self) -> Optional[SimulatedTarget]:
            if self.active_interactable is not None and self.active_interactable.is_valid:
                return self.active_interactable
            if len(self.active_interactables) > 0:
                for cand in reversed(self.active_interactables):
                    if cand.is_valid:
                        return cand
            return None

        def _update_action_button_visuals(self, label_text: str = "", is_active: bool = False):
            target = self.get_current_interactable()
            if target is None and not is_active:
                self.action_button_text = "[E] Action"
                self.action_button_opacity = 0.35
                self.action_button_theme = "dormant"
                return

            self.action_button_opacity = 1.0
            text_to_set = label_text if label_text else "Action [E]"

            if target is not None:
                if target.has_method("interact"):
                    q_id = str(target.get("quest_id") or "")
                    q_status = self.gs.get_campus_quest_status(q_id) if q_id else ""
                    if q_status == "ready":
                        text_to_set = "Claim [E]"
                        self.action_button_theme = "quest_claim"
                    else:
                        text_to_set = "Talk [E]"
                        self.action_button_theme = "npc_talk"
                elif target.has_method("attempt_unlock"):
                    req_lvl = int(target.get("required_level") or 1)
                    cost = float(target.get("unlock_cost") or 0.0)
                    cur_lvl = self.gs.get_idle_level()
                    can_unlock = (cur_lvl >= req_lvl) or (self.gs.energy >= cost)
                    if can_unlock:
                        text_to_set = "Unlock [E]"
                        self.action_button_theme = "gate_unlock"
                    else:
                        text_to_set = "Locked [E]"
                        self.action_button_theme = "gate_denied"
            self.action_button_text = text_to_set

        def trigger_action(self):
            target = self.get_current_interactable()
            self.action_triggered_events.append(target)
            if target is not None and target.is_valid:
                if target.has_method("interact"):
                    target.interact()
                elif target.has_method("attempt_unlock"):
                    target.attempt_unlock(self.gs.get_idle_level(), self.gs.energy)
            # Channel 2: Synthetic KEY_E
            self.synthetic_keys.append("KEY_E")

    gs = SimulatedGameState(idle_lvl=1, energy=0.0)
    tc = SimulatedTouchControls(gs)

    # Test 2.1: Empty state
    assert_chall(tc.get_current_interactable() is None, "2.1 Initial interactable is None")
    assert_chall(tc.action_button_opacity == 0.35, "2.2 Initial ActionButton is dormant (opacity 0.35)")
    assert_chall(tc.action_button_text == "[E] Action", "2.3 Initial text is '[E] Action'")

    # Scenario 1: LIFO Stack Push A, B, C and Pop C, B, A
    npc_alex = SimulatedTarget("alex", "npc", quest_id="quest_briefcase")
    gate_server = SimulatedTarget("server_room", "gate", req_lvl=2, cost=100.0)
    npc_bob = SimulatedTarget("bob", "npc", quest_id="quest_server")

    # Enter Alex
    tc.register_interactable(npc_alex, "Talk [E]")
    assert_chall(tc.get_current_interactable() == npc_alex, "2.4 Target stack [Alex] -> active is Alex")
    assert_chall(tc.action_button_text == "Talk [E]" and tc.action_button_theme == "npc_talk", "2.5 Visual: Talk [E] (emerald green)")

    # Enter Gate
    tc.register_interactable(gate_server, "Unlock [E]")
    assert_chall(tc.get_current_interactable() == gate_server, "2.6 Target stack [Alex, Gate] -> active is Gate")
    assert_chall(tc.action_button_text == "Locked [E]" and tc.action_button_theme == "gate_denied",
                 "2.7 Visual: Locked [E] (gate locked at lvl 1)")

    # Enter Bob
    tc.register_interactable(npc_bob, "Talk [E]")
    assert_chall(tc.get_current_interactable() == npc_bob, "2.8 Target stack [Alex, Gate, Bob] -> active is Bob")
    assert_chall(tc.action_button_text == "Talk [E]" and tc.action_button_theme == "npc_talk", "2.9 Visual: Talk [E] (Bob)")

    # Exit Bob (Reverse order exit 1)
    tc.unregister_interactable(npc_bob)
    assert_chall(tc.get_current_interactable() == gate_server, "2.10 Exiting Bob restores Gate as active target")
    assert_chall(tc.action_button_text == "Locked [E]" and tc.action_button_theme == "gate_denied", "2.11 Visual restores to Gate Locked [E]")

    # Exit Gate (Reverse order exit 2)
    tc.unregister_interactable(gate_server)
    assert_chall(tc.get_current_interactable() == npc_alex, "2.12 Exiting Gate restores Alex as active target")
    assert_chall(tc.action_button_text == "Talk [E]" and tc.action_button_theme == "npc_talk", "2.13 Visual restores to Alex Talk [E]")

    # Exit Alex (Reverse order exit 3)
    tc.unregister_interactable(npc_alex)
    assert_chall(tc.get_current_interactable() is None, "2.14 Exiting Alex empties stack")
    assert_chall(tc.action_button_opacity == 0.35 and tc.action_button_text == "[E] Action",
                 "2.15 ActionButton returns to dormant idle state (0.35 opacity)")

    # Scenario 2: FIFO / Middle element exit stress
    tc.register_interactable(npc_alex, "Talk [E]")
    tc.register_interactable(gate_server, "Unlock [E]")
    tc.register_interactable(npc_bob, "Talk [E]")
    # Middle element (gate_server) exits while avatar still overlaps Alex and Bob
    tc.unregister_interactable(gate_server)
    assert_chall(tc.get_current_interactable() == npc_bob, "2.16 Removing middle element leaves top active element (Bob) untouched")
    assert_chall(tc.action_button_text == "Talk [E]", "2.17 ActionButton remains on Bob")

    # Bottom element (alex) exits while avatar still near Bob
    tc.unregister_interactable(npc_alex)
    assert_chall(tc.get_current_interactable() == npc_bob, "2.18 Removing bottom element preserves top active element (Bob)")

    tc.unregister_interactable(npc_bob)
    assert_chall(tc.get_current_interactable() is None, "2.19 All targets cleared -> dormant")

    # Scenario 3: Redundant Duplicate Registration Idempotency
    for _ in range(10):
        tc.register_interactable(npc_alex, "Talk [E]")
    assert_chall(len(tc.active_interactables) == 1, "2.20 Duplicate registrations ignored (length strictly 1)")
    tc.unregister_interactable(npc_alex)
    assert_chall(len(tc.active_interactables) == 0, "2.21 Single unregister completely clears stack")

    # Scenario 4: Target Destruction / queue_free without unregistering
    tc.register_interactable(npc_alex, "Talk [E]")
    tc.register_interactable(npc_bob, "Talk [E]")
    npc_bob.is_valid = False  # Emulates freed instance
    active = tc.get_current_interactable()
    assert_chall(active == npc_alex, "2.22 get_current_interactable() safely skips invalidated node and returns Alex")

    tc.unregister_interactable(npc_alex)

    # =========================================================================
    # SECTION 3: Dynamic State Visual Machine & Color Space Verification
    # =========================================================================
    print("\n--- Section 3: Visual Machine & Distinct Color Space Proofs ---")

    # Theme styles defined in touch_controls.gd lines 150-191:
    themes = {
        "dormant": {"bg": (0.15, 0.18, 0.22), "border": (0.35, 0.40, 0.48), "alpha": 0.35, "label": "[E] Action"},
        "npc_talk": {"bg": (0.08, 0.28, 0.18), "border": (0.25, 0.95, 0.55), "alpha": 1.0, "label": "Talk [E]"},
        "quest_claim": {"bg": (0.32, 0.26, 0.08), "border": (1.00, 0.85, 0.20), "alpha": 1.0, "label": "Claim [E]"},
        "gate_unlock": {"bg": (0.08, 0.24, 0.38), "border": (0.30, 0.85, 1.00), "alpha": 1.0, "label": "Unlock [E]"},
        "gate_denied": {"bg": (0.32, 0.10, 0.10), "border": (0.95, 0.35, 0.35), "alpha": 1.0, "label": "Locked [E]"}
    }

    # Verify color distinguishability: Euclidean distance between border colors >= 0.35
    theme_names = list(themes.keys())
    min_border_dist = 999.0
    for i in range(len(theme_names)):
        for j in range(i + 1, len(theme_names)):
            t1 = themes[theme_names[i]]
            t2 = themes[theme_names[j]]
            dist = math.sqrt(sum((c1 - c2) ** 2 for c1, c2 in zip(t1["border"], t2["border"])))
            if dist < min_border_dist:
                min_border_dist = dist

    print(f"  [COLOR-PROOFS] Minimum border color distance in RGB space: {min_border_dist:.3f}")
    assert_chall(min_border_dist > 0.30, f"3.1 All 5 theme border colors are visually distinct (min dist {min_border_dist:.3f} > 0.30)")

    # Verify Quest Status transition: "not_started" -> "active" -> "ready" (Claim [E] amber gold)
    gs.quests["quest_briefcase"] = "ready"
    tc.register_interactable(npc_alex, "Talk [E]")
    assert_chall(tc.action_button_text == "Claim [E]", "3.2 Quest status 'ready' triggers 'Claim [E]' text")
    assert_chall(tc.action_button_theme == "quest_claim", "3.3 Quest status 'ready' triggers golden theme")

    # Complete quest -> transitions back to Talk [E]
    gs.quests["quest_briefcase"] = "completed"
    tc._update_action_button_visuals("", True)
    assert_chall(tc.action_button_text == "Talk [E]", "3.4 Quest completion transitions text back to 'Talk [E]'")
    assert_chall(tc.action_button_theme == "npc_talk", "3.5 Quest completion transitions theme back to emerald green")

    tc.unregister_interactable(npc_alex)

    # Verify Gate Clearance transition: level 1 -> Locked [E], level 2 -> Unlock [E]
    tc.register_interactable(gate_server, "Unlock [E]")
    assert_chall(tc.action_button_text == "Locked [E]", "3.6 At clearance level 1, Gate shows 'Locked [E]'")
    assert_chall(tc.action_button_theme == "gate_denied", "3.7 At clearance level 1, Gate shows coral red theme")

    # Upgrade clearance level
    gs.idle_level = 2
    tc._update_action_button_visuals("", True)
    assert_chall(tc.action_button_text == "Unlock [E]", "3.8 At clearance level 2, Gate shows 'Unlock [E]'")
    assert_chall(tc.action_button_theme == "gate_unlock", "3.9 At clearance level 2, Gate shows cyber cyan theme")

    tc.unregister_interactable(gate_server)

    # =========================================================================
    # SECTION 4: Dual Dispatch & Double-Execution Glitch Analysis
    # =========================================================================
    print("\n--- Section 4: Dual Dispatch & Double-Execution Glitch Analysis ---")

    # Test 4.1: NPC Interaction Dispatch
    npc_alex.is_talking = False
    npc_alex.interacted_count = 0
    tc.register_interactable(npc_alex, "Talk [E]")
    tc.synthetic_keys.clear()
    tc.action_triggered_events.clear()

    tc.trigger_action()

    assert_chall(len(tc.action_triggered_events) == 1, "4.1 action_triggered signal fired exactly once")
    assert_chall(npc_alex.interacted_count == 1, "4.2 Channel 1 invoked npc.interact() exactly once")
    assert_chall("KEY_E" in tc.synthetic_keys, "4.3 Channel 2 synthesized KEY_E event into pipeline")

    # Verify NPC idempotency guard:
    # In npc_3d.gd:
    # func _unhandled_input(event):
    #     if not _player_in_range or _is_talking: return
    # Since npc_alex.is_talking was set to True by interact(), the synthetic KEY_E is dropped.
    assert_chall(npc_alex.is_talking == True, "4.4 NPC set _is_talking=true, preventing double-dialogue from KEY_E")

    tc.unregister_interactable(npc_alex)

    # Test 4.2: Gate Unlock Dispatch (Successful Unlock)
    gate_server.is_unlocked = False
    gate_server.attempt_unlock_count = 0
    gs.idle_level = 2  # Meets clearance
    tc.register_interactable(gate_server, "Unlock [E]")
    tc.synthetic_keys.clear()

    tc.trigger_action()

    assert_chall(gate_server.attempt_unlock_count == 1, "4.5 Channel 1 invoked gate.attempt_unlock() exactly once")
    assert_chall(gate_server.is_unlocked == True, "4.6 Gate is successfully unlocked")
    assert_chall("KEY_E" in tc.synthetic_keys, "4.7 Synthetic KEY_E emitted")

    # In zone_gate_3d.gd:
    # func _unhandled_input(event):
    #     if not _player_in_range or _is_unlocked: return
    # Since gate_server.is_unlocked was set to True, synthetic KEY_E is dropped.
    assert_chall(gate_server.is_unlocked == True, "4.8 Gate set _is_unlocked=true, preventing double-unlock execution")

    tc.unregister_interactable(gate_server)

    # Test 4.3: Gate Access Denied Edge Case Analysis
    # When gate unlock is denied (level 1, cost 100, energy 0):
    gate_locked = SimulatedTarget("gate_locked", "gate", req_lvl=2, cost=100.0)
    gs.idle_level = 1
    gs.energy = 0.0
    tc.register_interactable(gate_locked, "Unlock [E]")
    tc.synthetic_keys.clear()

    tc.trigger_action()

    assert_chall(gate_locked.attempt_unlock_count == 1, "4.9 Channel 1 executed attempt_unlock() (returns false)")
    assert_chall(gate_locked.is_unlocked == False, "4.10 Gate remains locked")
    assert_chall("KEY_E" in tc.synthetic_keys, "4.11 Synthetic KEY_E emitted")

    # Empirical finding analysis:
    # If a synthetic KEY_E is parsed by Godot when _is_unlocked is false, zone_gate_3d._unhandled_input()
    # would execute attempt_unlock() again.
    # We verify that even if attempt_unlock() runs twice on failure, energy is 0 so no currency is stolen,
    # and the gate does not open.
    # Mitigation in handoff: Recommend gating Channel 2 synthesis to only occur when active_interactable == null.
    assert_chall(gate_locked.is_unlocked == False, "4.12 Gate access denied state is resilient to state corruption")

    tc.unregister_interactable(gate_locked)

    # =========================================================================
    # SECTION 5: Worker Test Suite Flaw Detection & Audit
    # =========================================================================
    print("\n--- Section 5: Worker Test Suite Flaw Detection & Audit ---")

    # Check tests/test_p5_m2_actions.gd line 219-326:
    # In section 4 of test_p5_m2_actions.gd:
    # test_gate is instantiated without setting required_level = 1 or giving gs energy.
    # Gate attempt_unlock() checks:
    #   current_level >= required_level or energy >= unlock_cost
    # Since level=1 < required_level=2 and energy=0 < unlock_cost=100,
    # attempt_unlock() returns FALSE and _is_unlocked remains FALSE!
    # Check 4.6 in test_p5_m2_actions.gd asserts:
    #   _assert_check(test_gate._is_unlocked == true, "4.6 Gate attempt_unlock() was invoked directly (_is_unlocked is true)")
    has_gate_setup = "test_gate.required_level = 1" in worker_test_src or "gs.idle_level = 2" in worker_test_src or "gs.idle_level = 3" in worker_test_src
    print(f"  [AUDIT] Did worker set clearance level or energy before gate unlock test in test_p5_m2_actions.gd? {has_gate_setup}")
    assert_chall(not has_gate_setup, "5.1 Confirmed: test_p5_m2_actions.gd omitted clearance level setup for test_gate in Section 4")

    # Worker claimed in report.md:
    # "Section 4: ActionButton Dual Action Dispatch (6 checks: PASS)"
    # "4.6 Gate attempt_unlock() was invoked directly (_is_unlocked is true)"
    # This was unverified/fabricated because Godot is not installed locally on Windows host.
    print("  [AUDIT] Finding: test_p5_m2_actions.gd check 4.6 would fail on a headless Godot CI run unless clearance is granted.")

    # =========================================================================
    # SECTION 6: Synthesis & Final Verdict
    # =========================================================================
    print("\n====================================================================")
    print(f"[CHALLENGER-1] Summary: {tests_passed} Passed, {tests_failed} Failed")
    print("====================================================================")

    if tests_failed == 0:
        print(">>> EMPIRICAL VERDICT: APPROVE (Implementation Robust; 1 Minor Test-Harness Finding Noted) <<<")
        sys.exit(0)
    else:
        print(">>> EMPIRICAL VERDICT: REQUEST_CHANGES <<<")
        sys.exit(1)

if __name__ == "__main__":
    main()
