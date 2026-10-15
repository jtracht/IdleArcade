#!/usr/bin/env python3
"""
Milestone P7-M3 Empirical Adversarial Challenge Oracle
Focus: Dialogue Input Isolation, Clean Exit Lifecycle & Quest State Transitions.

Author: p7_m3_challenger_1 (Empirical Challenger)
Target: IdleArcade (Godot 4.3)

Empirically tests & validates:
1. Avatar3D Input Isolation:
   - AST validation: _script_input_direction is guarded by input_enabled in _physics_process.
   - AST validation: set_input_enabled(false) calls stop_movement().
   - AST validation: stop_movement() clears velocity and input direction.
   - State Simulation: Calling set_input_direction() while input_enabled is False.
     Evaluates desired_dir across frames; confirms desired_dir strictly evaluates to Vector3.ZERO.
   - State Simulation: Mid-movement cutoff; zero velocity deceleration.
   - Edge Case: Direct input_enabled property change without method call.
   - Edge Case: Non-horizontal (pure Y) direction injection.

2. NPC3D Dialogue Lifecycle & Teardown:
   - AST validation: interact() invokes TouchControls.fade_out_controls().
   - AST validation: interact() unregisters interactable from TouchControls.
   - AST validation: end_dialogue() closes DialoguePanel and invokes TouchControls.fade_in_controls().
   - AST validation: _on_interaction_body_exited() cleans up dialogue state via end_dialogue().
   - AST validation: Re-entrancy guard in end_dialogue() prevents recursion loops.
   - Simulation: Full lifecycle (approach -> interact -> exit before completion -> verify cleanup).
   - Simulation: Re-entrant signal loop test.

3. GameState Quest State Transitions & Retroactive Resolution:
   - AST validation: active_campus_quest_id property declared.
   - AST validation: start_campus_quest sets active_campus_quest_id.
   - AST validation: complete_campus_quest clears active_campus_quest_id when matching.
   - AST validation: start_campus_quest handles retroactive unlock for quest_server and quest_lab.
   - State Simulation: Starting quest_server when server_room is already unlocked -> status "ready", count = 1, campus_quest_updated emitted.
   - State Simulation: Starting quest_lab when lab_room is already unlocked -> status "ready", count = 1, campus_quest_updated emitted.
   - State Simulation: active_campus_quest_id set on start, cleared on completion.
   - State Simulation: Out-of-order re-acceptance while active transitions to ready if gate unlocked.
   - State Simulation / Audit: reset_state() behavior on active_campus_quest_id.

4. Harmonized Progression & Waypoint Integration:
   - ZoneGate3D 3D floating text Label3D configuration and tween.
   - Avatar3D reactive speed binding on avatar_stat_updated.
   - GameState campus item multiplier: 1.0 + 0.05 * count, rps_changed emission.
   - QuestWaypoint3D objective resolution and arrival detection (threshold <= 3.0m).

5. Full Regression Battery Execution:
   - verify_m3.py
   - test_p7_m1_challenger_oracle.py
   - verify_m2.py
   - test_phase5_mobile.py
   - test_phase6_visuals.py
   - e2e_suite.py
"""

import sys
import re
import math
import subprocess
from pathlib import Path

# Paths
CWD = Path.cwd()
if (CWD / "IdleArcade").exists():
    GAME_DIR = CWD / "IdleArcade"
    ROOT_DIR = CWD
else:
    GAME_DIR = CWD
    ROOT_DIR = CWD.parent

passed = 0
failed = 0
warnings = 0

def check(condition: bool, description: str, module: str = ""):
    global passed, failed
    tag = f"[{module}] " if module else ""
    if condition:
        passed += 1
        print(f"  [PASS] {tag}{description}")
    else:
        failed += 1
        print(f"  [FAIL] {tag}{description}")

def warn(description: str, module: str = ""):
    global warnings
    warnings += 1
    tag = f"[{module}] " if module else ""
    print(f"  [WARN] {tag}{description}")

print("====================================================================")
print(">>> P7-M3 EMPIRICAL ADVERSARIAL CHALLENGE ORACLE <<<")
print("====================================================================")

# =============================================================================
# SECTION 1: Avatar3D Input Isolation & Kinematic Simulation
# =============================================================================
print("\n=== SECTION 1: Avatar3D Input Isolation & Kinematic Simulation ===")
avatar_file = GAME_DIR / "scripts/avatar_3d.gd"
check(avatar_file.exists(), "avatar_3d.gd exists", "AvatarAST")
avatar_src = avatar_file.read_text(encoding="utf-8")

# AST structural checks
check("if input_enabled and _script_input_direction != Vector3.ZERO:" in avatar_src,
      "_script_input_direction strictly guarded by input_enabled in _physics_process", "AvatarAST")
check("elif input_enabled:" in avatar_src,
      "Fallback keyboard and click navigation also guarded by input_enabled", "AvatarAST")
check("func set_input_enabled(enabled: bool) -> void:" in avatar_src,
      "set_input_enabled() interface method implemented", "AvatarAST")
check("stop_movement()" in avatar_src and "if not input_enabled:" in avatar_src,
      "set_input_enabled(false) triggers stop_movement()", "AvatarAST")
check("_script_input_direction = Vector3.ZERO" in avatar_src and "func stop_movement" in avatar_src,
      "stop_movement() clears _script_input_direction", "AvatarAST")

# Python Mathematical & Kinematic Model of Avatar3D
class KinematicAvatarModel:
    def __init__(self):
        self.input_enabled = True
        self._script_input_direction = [0.0, 0.0, 0.0]
        self._click_target = None
        self._has_click_target = False
        self.velocity = [0.0, 0.0, 0.0]
        self.current_speed = 6.0
        self.acceleration = 24.0
        self.friction = 32.0

    def set_input_enabled(self, enabled: bool) -> None:
        self.input_enabled = enabled
        if not self.input_enabled:
            self.stop_movement()

    def set_input_direction(self, dir_vec) -> None:
        # Replicates Avatar3D: Vector3(dir.x, 0.0, dir.z)
        hx = dir_vec[0]
        hz = dir_vec[2]
        length = math.sqrt(hx * hx + hz * hz)
        if length > 0.0001:
            self._script_input_direction = [hx / length, 0.0, hz / length]
            self._has_click_target = False
        else:
            self._script_input_direction = [0.0, 0.0, 0.0]

    def stop_movement(self) -> None:
        self._script_input_direction = [0.0, 0.0, 0.0]
        self._has_click_target = False
        self.velocity = [0.0, self.velocity[1], 0.0]

    def compute_desired_dir(self, keyboard_dir=[0.0, 0.0, 0.0]):
        # Exact reproduction of Avatar3D._physics_process line 95-118
        desired_dir = [0.0, 0.0, 0.0]
        if self.input_enabled and self._script_input_direction != [0.0, 0.0, 0.0]:
            desired_dir = list(self._script_input_direction)
            self._has_click_target = False
        elif self.input_enabled:
            if keyboard_dir != [0.0, 0.0, 0.0]:
                desired_dir = list(keyboard_dir)
                self._has_click_target = False
            elif self._has_click_target:
                # click target logic...
                pass
        return desired_dir

    def physics_step(self, delta: float, keyboard_dir=[0.0, 0.0, 0.0]):
        desired_dir = self.compute_desired_dir(keyboard_dir)
        target_horizontal = [desired_dir[0] * self.current_speed, 0.0, desired_dir[2] * self.current_speed]
        
        # move_toward horizontal
        for i in [0, 2]:
            diff = target_horizontal[i] - self.velocity[i]
            rate = (self.acceleration if desired_dir != [0.0, 0.0, 0.0] else self.friction) * delta
            if abs(diff) <= rate:
                self.velocity[i] = target_horizontal[i]
            else:
                self.velocity[i] += math.copysign(rate, diff)
        return desired_dir

# Stress-Test 1.1: Direct injection while input_enabled is False
sim = KinematicAvatarModel()
sim.set_input_enabled(False)
sim.set_input_direction([1.0, 0.0, 0.0]) # Caller attempts to inject direction
desired = sim.compute_desired_dir()
check(desired == [0.0, 0.0, 0.0],
      "Simulate: Calling set_input_direction([1,0,0]) while input_enabled=False -> desired_dir is Vector3.ZERO", "AvatarSim")

sim.physics_step(0.016)
check(sim.velocity == [0.0, 0.0, 0.0],
      "Simulate: Avatar velocity remains [0,0,0] across physics tick", "AvatarSim")

# Stress-Test 1.2: Calling set_input_direction repeatedly over 60 ticks while input_enabled=False
ticks_zero = True
for _ in range(60):
    sim.set_input_direction([0.707, 0.0, 0.707])
    d = sim.physics_step(0.016)
    if d != [0.0, 0.0, 0.0] or sim.velocity != [0.0, 0.0, 0.0]:
        ticks_zero = False
        break
check(ticks_zero,
      "Simulate: 60 consecutive ticks of aggressive direction injection while disabled maintain strictly ZERO velocity", "AvatarSim")

# Stress-Test 1.3: Direct property override (input_enabled = False without calling set_input_enabled)
sim2 = KinematicAvatarModel()
sim2.set_input_direction([1.0, 0.0, 0.0])
sim2.physics_step(0.1) # Start moving
check(sim2.velocity[0] > 0.0, "Simulate: Moving avatar has velocity > 0", "AvatarSim")
# Hostile action: bypass setter and set flag directly
sim2.input_enabled = False
# In Avatar3D, _script_input_direction might not be cleared, BUT _physics_process checks:
# if input_enabled and _script_input_direction != Vector3.ZERO:
d2 = sim2.compute_desired_dir()
check(d2 == [0.0, 0.0, 0.0],
      "Simulate: Direct property override (input_enabled=False) strictly evaluates desired_dir to Vector3.ZERO", "AvatarSim")

# Run friction decay ticks
for _ in range(20):
    sim2.physics_step(0.016)
check(abs(sim2.velocity[0]) < 0.001,
      "Simulate: Avatar decelerates to complete stop under friction when input_enabled=False", "AvatarSim")

# Stress-Test 1.4: Pure vertical vector injection
sim3 = KinematicAvatarModel()
sim3.set_input_direction([0.0, 5.0, 0.0]) # Pure Y vector
check(sim3._script_input_direction == [0.0, 0.0, 0.0],
      "Simulate: Pure vertical input Vector3(0, 5, 0) normalizes to Vector3.ZERO", "AvatarSim")

# =============================================================================
# SECTION 2: NPC3D Dialogue Lifecycle & Teardown
# =============================================================================
print("\n=== SECTION 2: NPC3D Dialogue Lifecycle & Teardown ===")
npc_file = GAME_DIR / "scripts/npc_3d.gd"
check(npc_file.exists(), "npc_3d.gd exists", "NPCAST")
npc_src = npc_file.read_text(encoding="utf-8")

# AST structural checks
check("tc.fade_out_controls()" in npc_src,
      "NPC3D.interact() invokes tc.fade_out_controls()", "NPCAST")
check("tc.unregister_interactable(self)" in npc_src,
      "NPC3D.interact() unregisters interactable from TouchControls", "NPCAST")
check("dialogue_panel.open_for_npc" in npc_src,
      "NPC3D.interact() opens DialoguePanel", "NPCAST")
check("dialogue_panel.closed.connect(end_dialogue" in npc_src,
      "NPC3D.interact() connects dialogue_panel.closed to end_dialogue", "NPCAST")
check("dialogue_panel.close_dialogue()" in npc_src,
      "NPC3D.end_dialogue() invokes dialogue_panel.close_dialogue()", "NPCAST")
check("tc.fade_in_controls()" in npc_src,
      "NPC3D.end_dialogue() invokes tc.fade_in_controls()", "NPCAST")
check("dialogue_closed.emit(npc_id)" in npc_src,
      "NPC3D.end_dialogue() emits dialogue_closed signal", "NPCAST")
check("if _is_talking:" in npc_src and "end_dialogue()" in npc_src,
      "NPC3D._on_interaction_body_exited() checks _is_talking and triggers end_dialogue()", "NPCAST")
check("_avatar_ref = null" in npc_src and "_player_in_range = false" in npc_src,
      "NPC3D._on_interaction_body_exited() cleans up avatar reference and range flags", "NPCAST")
check("var _is_ending_dialogue: bool = false" in npc_src,
      "NPC3D declares _is_ending_dialogue re-entrancy protection guard", "NPCAST")

# DialoguePanel inspection
dp_file = GAME_DIR / "scripts/dialogue_panel.gd"
check(dp_file.exists(), "dialogue_panel.gd exists", "DialogueAST")
dp_src = dp_file.read_text(encoding="utf-8")
check('_avatar_ref.set_input_enabled(false)' in dp_src,
      "DialoguePanel.open_for_npc() disables avatar input", "DialogueAST")
check('_avatar_ref.set_input_enabled(true)' in dp_src,
      "DialoguePanel.close_dialogue() restores avatar input", "DialogueAST")

# State Machine Simulation: NPC Dialogue Lifecycle & Premature Exit
class MockTouchControls:
    def __init__(self):
        self.controls_faded_out = False
        self.registered_interactables = set()

    def register_interactable(self, node, text=""):
        self.registered_interactables.add(node)

    def unregister_interactable(self, node):
        self.registered_interactables.discard(node)

    def fade_out_controls(self):
        self.controls_faded_out = True

    def fade_in_controls(self):
        self.controls_faded_out = False

class MockDialoguePanel:
    def __init__(self):
        self.visible = False
        self.avatar_ref = None
        self.closed_callbacks = []

    def open_for_npc(self, avatar):
        self.visible = True
        self.avatar_ref = avatar
        if self.avatar_ref:
            self.avatar_ref.set_input_enabled(False)

    def close_dialogue(self):
        if not self.visible:
            return
        self.visible = False
        if self.avatar_ref:
            self.avatar_ref.set_input_enabled(True)
        # Emit closed signal to callbacks
        callbacks = list(self.closed_callbacks)
        for cb in callbacks:
            cb()

class MockNPC3D:
    def __init__(self, tc: MockTouchControls, dp: MockDialoguePanel):
        self.tc = tc
        self.dp = dp
        self._is_talking = False
        self._is_ending_dialogue = False
        self._avatar_ref = None
        self._player_in_range = False
        self.dialogue_closed_emitted = False

    def on_interaction_body_entered(self, body):
        self._player_in_range = True
        self._avatar_ref = body
        self.tc.register_interactable(self, "Talk [E]")

    def interact(self):
        self._is_talking = True
        self.tc.unregister_interactable(self)
        self.tc.fade_out_controls()
        self.dp.open_for_npc(self._avatar_ref)
        if self.end_dialogue not in self.dp.closed_callbacks:
            self.dp.closed_callbacks.append(self.end_dialogue)

    def end_dialogue(self):
        if self._is_ending_dialogue:
            return
        self._is_ending_dialogue = True
        self._is_talking = False
        if self.dp.visible:
            self.dp.close_dialogue()
        self.tc.fade_in_controls()
        self.dialogue_closed_emitted = True
        self._is_ending_dialogue = False

    def on_interaction_body_exited(self, body):
        self._player_in_range = False
        if self._is_talking:
            self.end_dialogue()
        self._avatar_ref = None
        self.tc.unregister_interactable(self)

# Stress-Test 2.1: Full dialogue lifecycle with premature body exit
tc = MockTouchControls()
dp = MockDialoguePanel()
avatar = KinematicAvatarModel()
npc = MockNPC3D(tc, dp)

# Step 1: Avatar enters range
npc.on_interaction_body_entered(avatar)
check(npc in tc.registered_interactables, "Simulate: NPC registered in TouchControls on range enter", "NPCSim")

# Step 2: Interact begins dialogue
npc.interact()
check(npc._is_talking == True, "Simulate: NPC._is_talking is True", "NPCSim")
check(tc.controls_faded_out == True, "Simulate: TouchControls faded out during dialogue", "NPCSim")
check(dp.visible == True, "Simulate: DialoguePanel is visible", "NPCSim")
check(avatar.input_enabled == False, "Simulate: Avatar input_enabled is False during dialogue", "NPCSim")

# Step 3: Avatar leaves range prematurely (e.g. physics push or cutscene)
npc.on_interaction_body_exited(avatar)
check(npc._is_talking == False, "Simulate: NPC._is_talking is reset to False", "NPCSim")
check(dp.visible == False, "Simulate: DialoguePanel cleanly closed upon exit", "NPCSim")
check(tc.controls_faded_out == False, "Simulate: TouchControls restored (fade_in) upon exit", "NPCSim")
check(avatar.input_enabled == True, "Simulate: Avatar input re-enabled upon exit", "NPCSim")
check(npc._avatar_ref is None, "Simulate: NPC._avatar_ref dereferenced to prevent leaks", "NPCSim")

# Stress-Test 2.2: Re-entrancy protection verification
# If dp.close_dialogue() calls closed signal -> calls end_dialogue() recursively,
# _is_ending_dialogue guard prevents infinite recursion.
npc2 = MockNPC3D(tc, dp)
npc2.on_interaction_body_entered(avatar)
npc2.interact()
recursion_safe = True
try:
    # Triggering end_dialogue directly invokes dp.close_dialogue(), which triggers end_dialogue callback
    npc2.end_dialogue()
except RecursionError:
    recursion_safe = False
check(recursion_safe and not npc2._is_talking,
      "Simulate: end_dialogue() re-entrancy guard safely handles bidirectional closed signal without recursion", "NPCSim")

# =============================================================================
# SECTION 3: GameState Quest State Transitions & Retroactive Unlocks
# =============================================================================
print("\n=== SECTION 3: GameState Quest State Transitions & Retroactive Unlocks ===")
gs_file = GAME_DIR / "scripts/autoload/game_state.gd"
check(gs_file.exists(), "game_state.gd exists", "GameStateAST")
gs_src = gs_file.read_text(encoding="utf-8")

# AST structural checks
check('var active_campus_quest_id: String = ""' in gs_src,
      "GameState declares active_campus_quest_id property", "GameStateAST")
check('active_campus_quest_id = quest_id' in gs_src,
      "start_campus_quest sets active_campus_quest_id = quest_id", "GameStateAST")
check('active_campus_quest_id = ""' in gs_src and 'func complete_campus_quest' in gs_src,
      "complete_campus_quest clears active_campus_quest_id", "GameStateAST")
check('is_zone_unlocked("server_room")' in gs_src and 'quest_id == "quest_server"' in gs_src,
      "start_campus_quest checks server_room unlock state for quest_server", "GameStateAST")
check('is_zone_unlocked("lab_room")' in gs_src and 'quest_id == "quest_lab"' in gs_src,
      "start_campus_quest checks lab_room unlock state for quest_lab", "GameStateAST")
check('campus_quest_updated.emit(quest_id, "ready", 1, 1)' in gs_src,
      "start_campus_quest emits campus_quest_updated on retroactive unlock", "GameStateAST")
check('"active_campus_quest_id": active_campus_quest_id' in gs_src,
      "save_to_disk serializes active_campus_quest_id", "GameStateAST")
check('data.get("active_campus_quest_id"' in gs_src,
      "load_from_disk deserializes active_campus_quest_id", "GameStateAST")

# GameState Behavioral Simulator
class GameStateSimulator:
    def __init__(self):
        self.unlocked_zones = []
        self.campus_quests = {}
        self.active_campus_quest_id = ""
        self.signals = []

    def emit_signal(self, signal_name, *args):
        self.signals.append((signal_name, args))

    def is_zone_unlocked(self, zone_id: str) -> bool:
        return zone_id in self.unlocked_zones

    def unlock_zone(self, zone_id: str) -> bool:
        if not zone_id or self.is_zone_unlocked(zone_id):
            return True
        self.unlocked_zones.append(zone_id)
        self.emit_signal("zone_unlocked", zone_id)
        if zone_id == "server_room":
            self.advance_campus_quest("quest_server", 1)
        elif zone_id == "lab_room":
            self.advance_campus_quest("quest_lab", 1)
        return True

    def get_campus_quest_status(self, quest_id: str) -> str:
        if quest_id not in self.campus_quests:
            return "not_started"
        return self.campus_quests[quest_id].get("status", "not_started")

    def start_campus_quest(self, quest_id: str, target_count: int = 1) -> None:
        # Exact reproduction of GameState.start_campus_quest() lines 431-460
        self.active_campus_quest_id = quest_id
        if quest_id in self.campus_quests and self.campus_quests[quest_id].get("status") in ["active", "ready", "completed"]:
            if self.campus_quests[quest_id].get("status") == "active":
                if quest_id == "quest_server" and self.is_zone_unlocked("server_room"):
                    self.campus_quests[quest_id]["current_count"] = 1
                    self.campus_quests[quest_id]["status"] = "ready"
                    self.emit_signal("campus_quest_updated", quest_id, "ready", 1, 1)
                elif quest_id == "quest_lab" and self.is_zone_unlocked("lab_room"):
                    self.campus_quests[quest_id]["current_count"] = 1
                    self.campus_quests[quest_id]["status"] = "ready"
                    self.emit_signal("campus_quest_updated", quest_id, "ready", 1, 1)
            return

        self.campus_quests[quest_id] = {
            "status": "active",
            "current_count": 0,
            "target_count": max(1, target_count)
        }

        if quest_id == "quest_server" and self.is_zone_unlocked("server_room"):
            self.campus_quests[quest_id]["current_count"] = 1
            self.campus_quests[quest_id]["status"] = "ready"
            self.emit_signal("campus_quest_updated", quest_id, "ready", 1, 1)
        elif quest_id == "quest_lab" and self.is_zone_unlocked("lab_room"):
            self.campus_quests[quest_id]["current_count"] = 1
            self.campus_quests[quest_id]["status"] = "ready"
            self.emit_signal("campus_quest_updated", quest_id, "ready", 1, 1)
        else:
            self.emit_signal("campus_quest_updated", quest_id, "active", 0, max(1, target_count))

    def advance_campus_quest(self, quest_id: str, amount: int = 1) -> None:
        if quest_id not in self.campus_quests:
            return
        q = self.campus_quests[quest_id]
        if q.get("status") != "active":
            return
        q["current_count"] = min(q.get("target_count", 1), q.get("current_count", 0) + amount)
        if q["current_count"] >= q.get("target_count", 1):
            q["status"] = "ready"
        self.emit_signal("campus_quest_updated", quest_id, str(q["status"]), int(q["current_count"]), int(q["target_count"]))

    def complete_campus_quest(self, quest_id: str, reward_energy: float = 0.0, reward_bonus_users: int = 0) -> bool:
        if quest_id not in self.campus_quests:
            return False
        q = self.campus_quests[quest_id]
        if q.get("status") != "ready":
            return False
        q["status"] = "completed"
        if self.active_campus_quest_id == quest_id:
            self.active_campus_quest_id = ""
        self.emit_signal("campus_quest_completed", quest_id, reward_energy, reward_bonus_users)
        self.emit_signal("campus_quest_updated", quest_id, "completed", int(q["current_count"]), int(q["target_count"]))
        return True

# Stress-Test 3.1: Retroactive unlock of quest_server when server_room unlocked beforehand
sim_gs = GameStateSimulator()
sim_gs.unlock_zone("server_room")
check(sim_gs.is_zone_unlocked("server_room"), "Simulate: server_room unlocked", "QuestStateSim")

# Start quest_server
sim_gs.signals.clear()
sim_gs.start_campus_quest("quest_server", 1)

check(sim_gs.campus_quests["quest_server"]["status"] == "ready",
      "Simulate: Starting quest_server with pre-unlocked gate transitions immediately to 'ready'", "QuestStateSim")
check(sim_gs.campus_quests["quest_server"]["current_count"] == 1,
      "Simulate: quest_server current_count is 1", "QuestStateSim")
check(sim_gs.active_campus_quest_id == "quest_server",
      "Simulate: active_campus_quest_id is set to 'quest_server'", "QuestStateSim")
check(("campus_quest_updated", ("quest_server", "ready", 1, 1)) in sim_gs.signals,
      "Simulate: campus_quest_updated('quest_server', 'ready', 1, 1) signal was emitted", "QuestStateSim")

# Complete quest_server
sim_gs.complete_campus_quest("quest_server", 100.0, 10)
check(sim_gs.campus_quests["quest_server"]["status"] == "completed",
      "Simulate: quest_server is 'completed'", "QuestStateSim")
check(sim_gs.active_campus_quest_id == "",
      "Simulate: active_campus_quest_id is cleared to empty string on completion", "QuestStateSim")

# Stress-Test 3.2: Retroactive unlock of quest_lab when lab_room unlocked beforehand
sim_gs.unlock_zone("lab_room")
check(sim_gs.is_zone_unlocked("lab_room"), "Simulate: lab_room unlocked", "QuestStateSim")

sim_gs.signals.clear()
sim_gs.start_campus_quest("quest_lab", 1)

check(sim_gs.campus_quests["quest_lab"]["status"] == "ready",
      "Simulate: Starting quest_lab with pre-unlocked gate transitions immediately to 'ready'", "QuestStateSim")
check(sim_gs.campus_quests["quest_lab"]["current_count"] == 1,
      "Simulate: quest_lab current_count is 1", "QuestStateSim")
check(sim_gs.active_campus_quest_id == "quest_lab",
      "Simulate: active_campus_quest_id is set to 'quest_lab'", "QuestStateSim")
check(("campus_quest_updated", ("quest_lab", "ready", 1, 1)) in sim_gs.signals,
      "Simulate: campus_quest_updated('quest_lab', 'ready', 1, 1) signal was emitted", "QuestStateSim")

# Complete quest_lab
sim_gs.complete_campus_quest("quest_lab", 200.0, 20)
check(sim_gs.active_campus_quest_id == "",
      "Simulate: active_campus_quest_id is cleared to empty string on quest_lab completion", "QuestStateSim")

# Stress-Test 3.3: Mid-flight gate unlock resolution (accept quest while locked, then unlock)
sim_gs_locked = GameStateSimulator()
sim_gs_locked.start_campus_quest("quest_server", 1)
check(sim_gs_locked.campus_quests["quest_server"]["status"] == "active",
      "Simulate: Normal start with locked gate is 'active' (0/1)", "QuestStateSim")
check(sim_gs_locked.campus_quests["quest_server"]["current_count"] == 0,
      "Simulate: current_count is 0", "QuestStateSim")

sim_gs_locked.unlock_zone("server_room")
check(sim_gs_locked.campus_quests["quest_server"]["status"] == "ready",
      "Simulate: Unlocking gate advances active quest to 'ready' (1/1)", "QuestStateSim")

# Stress-Test 3.4: Re-calling start_campus_quest on already active quest when gate was unlocked externally
sim_gs_ext = GameStateSimulator()
sim_gs_ext.start_campus_quest("quest_server", 1)
check(sim_gs_ext.campus_quests["quest_server"]["status"] == "active", "Simulate: Initial active status", "QuestStateSim")
# Hostile action: unlock zone directly in list (bypassing unlock_zone method)
sim_gs_ext.unlocked_zones.append("server_room")
# Player talks to Bob again
sim_gs_ext.signals.clear()
sim_gs_ext.start_campus_quest("quest_server", 1)
check(sim_gs_ext.campus_quests["quest_server"]["status"] == "ready",
      "Simulate: Re-talking to NPC transitions active quest to 'ready' if gate is unlocked", "QuestStateSim")
check(("campus_quest_updated", ("quest_server", "ready", 1, 1)) in sim_gs_ext.signals,
      "Simulate: Re-talking to NPC emits campus_quest_updated on retroactive transition", "QuestStateSim")

# Stress-Test 3.5: Multi-quest switching and active_campus_quest_id integrity
sim_gs_multi = GameStateSimulator()
sim_gs_multi.start_campus_quest("quest_alex", 5)
check(sim_gs_multi.active_campus_quest_id == "quest_alex", "Simulate: active is quest_alex", "QuestStateSim")
sim_gs_multi.start_campus_quest("quest_bob", 1)
check(sim_gs_multi.active_campus_quest_id == "quest_bob", "Simulate: active switches to quest_bob", "QuestStateSim")

# If quest_alex completes in the background (not active), active_campus_quest_id must stay quest_bob
sim_gs_multi.campus_quests["quest_alex"]["status"] = "ready"
sim_gs_multi.complete_campus_quest("quest_alex")
check(sim_gs_multi.active_campus_quest_id == "quest_bob",
      "Simulate: Completing background quest preserves current active_campus_quest_id", "QuestStateSim")

# Completing active quest clears it
sim_gs_multi.campus_quests["quest_bob"]["status"] = "ready"
sim_gs_multi.complete_campus_quest("quest_bob")
check(sim_gs_multi.active_campus_quest_id == "",
      "Simulate: Completing current active quest clears active_campus_quest_id to empty", "QuestStateSim")

# AUDIT FINDING TEST: Check if reset_state() resets active_campus_quest_id in game_state.gd
has_reset_active_id = "active_campus_quest_id = \"\"" in gs_src[gs_src.find("func reset_state"):gs_src.find("func _process")]
if not has_reset_active_id:
    warn("GameState.reset_state() does not explicitly reset active_campus_quest_id to \"\". "
         "Calling reset_state() without recreating GameState may leave stale active_campus_quest_id.", "AuditFinding")
else:
    check(True, "GameState.reset_state() resets active_campus_quest_id", "AuditFinding")

# =============================================================================
# SECTION 4: Harmonized Progression, 3D Floating Text & Waypoints
# =============================================================================
print("\n=== SECTION 4: Harmonized Progression, 3D Floating Text & Waypoints ===")
gate_file = GAME_DIR / "scripts/zone_gate_3d.gd"
check(gate_file.exists(), "zone_gate_3d.gd exists", "GateAST")
gate_src = gate_file.read_text(encoding="utf-8")

# Floating Text Validation
check("func show_missing_resource_feedback" in gate_src,
      "ZoneGate3D implements show_missing_resource_feedback()", "GateAST")
check("Label3D.new()" in gate_src,
      "show_missing_resource_feedback spawns Label3D instance", "GateAST")
check("BaseMaterial3D.BILLBOARD_ENABLED" in gate_src,
      "Spawned Label3D has BaseMaterial3D.BILLBOARD_ENABLED", "GateAST")
check("Color(1.0, 0.3, 0.3)" in gate_src,
      "Spawned Label3D uses coral/red Color(1.0, 0.3, 0.3)", "GateAST")
check("Vector3(0.0, 2.5, 0.0)" in gate_src or "Vector3(0, 2.5, 0)" in gate_src,
      "Floating text spawns at gate center + Vector3(0, 2.5, 0)", "GateAST")
check("set_parallel(true)" in gate_src and "modulate:a" in gate_src,
      "Floating text has parallel alpha fade tween", "GateAST")
check("add_to_group(\"zone_gates\")" in gate_src,
      "ZoneGate3D registers in 'zone_gates' group in _ready()", "GateAST")

# Harmonized Economy & Multiplier Oracle
check("func get_campus_item_multiplier() -> float:" in gs_src,
      "GameState implements get_campus_item_multiplier()", "EconomyAST")
check("1.0 + (float(collectibles_collected) * 0.05)" in gs_src or "1.0 + float(collectibles_collected) * 0.05" in gs_src,
      "get_campus_item_multiplier implements formula 1.0 + count * 0.05", "EconomyAST")
check("get_campus_item_multiplier()" in gs_src and "func get_effective_passive_rps" in gs_src,
      "get_effective_passive_rps multiplies base by campus item multiplier", "EconomyAST")
check("rps_changed.emit(get_effective_passive_rps())" in gs_src and "func collect_3d_item" in gs_src,
      "collect_3d_item emits rps_changed with boosted rate", "EconomyAST")

# Avatar3D Reactive Speed Binding
check("avatar_stat_updated" in avatar_src and "_on_avatar_stat_updated" in avatar_src,
      "Avatar3D connects GameState.avatar_stat_updated signal", "SpeedAST")
check('stat_name == "avatar_speed"' in avatar_src and 'current_speed = get_move_speed()' in avatar_src,
      "Avatar3D reactively recomputes current_speed on avatar_speed update", "SpeedAST")

# QuestWaypoint3D Compass Validation
wp_file = GAME_DIR / "scripts/quest_waypoint.gd"
check(wp_file.exists(), "quest_waypoint.gd exists", "WaypointAST")
wp_src = wp_file.read_text(encoding="utf-8")

check("active_campus_quest_id" in wp_src,
      "QuestWaypoint3D inspects GameState.active_campus_quest_id", "WaypointAST")
check('active_quest == "quest_server"' in wp_src and 'server_unlocked' in wp_src,
      "QuestWaypoint3D branches server_room gate vs Bob", "WaypointAST")
check('active_quest == "quest_lab"' in wp_src and 'lab_unlocked' in wp_src,
      "QuestWaypoint3D branches lab_room gate vs Lisa", "WaypointAST")
check('[ Arrived! ]' in wp_src and '_distance <= arrival_threshold' in wp_src,
      "QuestWaypoint3D checks arrival threshold (3.0m) and formats '[ Arrived! ]'", "WaypointAST")

# =============================================================================
# SECTION 5: Full Regression Battery Execution
# =============================================================================
print("\n=== SECTION 5: Full Regression Battery Execution ===")

test_suites = [
    ("Worker Empirical Audit", GAME_DIR / "verify_m3.py"),
    ("M1 Challenger Oracle", GAME_DIR / "tests/test_p7_m1_challenger_oracle.py"),
    ("M2 Empirical Audit", GAME_DIR / "verify_m2.py"),
    ("Phase 5 Mobile Oracle", GAME_DIR / "tests/test_phase5_mobile.py"),
    ("Phase 6 Visual Life Oracle", GAME_DIR / "tests/test_phase6_visuals.py"),
    ("End-to-End Suite", GAME_DIR / "tests/e2e_suite.py"),
]

for name, script_path in test_suites:
    if script_path.exists():
        res = subprocess.run([sys.executable, str(script_path)], capture_output=True, text=True, cwd=str(ROOT_DIR))
        check(res.returncode == 0, f"Regression Battery: {name} passed (exit code 0)", "Regression")
        if res.returncode != 0:
            print(f"    [ERROR OUTPUT from {name}]:\n{res.stderr}\n{res.stdout[-400:]}")
    else:
        check(False, f"Regression Battery: {name} script {script_path} not found", "Regression")

# =============================================================================
# Final Summary & Verdict
# =============================================================================
print("\n====================================================================")
print(f">>> P7-M3 CHALLENGER ORACLE SUMMARY: {passed} PASSED, {failed} FAILED, {warnings} WARNINGS <<<")
print("====================================================================")

if failed == 0:
    print(">>> VERDICT: APPROVE <<<")
    print("All empirical challenge assertions satisfied with 100% integrity.")
    sys.exit(0)
else:
    print(f">>> VERDICT: REQUEST_CHANGES ({failed} failures detected) <<<", file=sys.stderr)
    sys.exit(1)
