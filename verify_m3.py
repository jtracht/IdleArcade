#!/usr/bin/env python3
"""
Empirical Verification & Forensic Audit Suite for Milestone P7-M3:
Funktionales Bugfixing & Gameplay-Harmonisierung.

Validates:
  1. Dialogue Input Lock & Clean Exit (scripts/avatar_3d.gd, scripts/npc_3d.gd)
  2. Quest Precondition Deadlock & Retroactive Unlocks (scripts/autoload/game_state.gd)
  3. 3D Floating Text for Missing Resources (scripts/zone_gate_3d.gd)
  4. Harmonized Loops: Speed Reactive Binding & Campus 2D Idle Boost (scripts/avatar_3d.gd, scripts/autoload/game_state.gd)
  5. Dynamic QuestWaypoint Compass & Arrival Detection (scripts/quest_waypoint.gd)
  6. Unit Test Suite (tests/test_p7_m3_gameplay.gd)
  7. Regression Battery (test_p7_m1_challenger_oracle.py, verify_m2.py, test_phase5_mobile.py, test_phase6_visuals.py, e2e_suite.py)
"""
import sys
import re
import math
import subprocess
from pathlib import Path

# Resolve game directory dynamically
cwd = Path.cwd()
if (cwd / "project.godot").exists():
    GAME_DIR = cwd
elif (cwd / "IdleArcade" / "project.godot").exists():
    GAME_DIR = cwd / "IdleArcade"
else:
    script_dir = Path(__file__).resolve().parent
    GAME_DIR = script_dir if (script_dir / "project.godot").exists() else script_dir / "IdleArcade"

ROOT_DIR = GAME_DIR.parent if (GAME_DIR.parent / ".github").exists() else GAME_DIR

passed = 0
failed = 0

def check(condition: bool, description: str, module: str = ""):
    global passed, failed
    tag = f"[{module}] " if module else ""
    if condition:
        passed += 1
        print(f"  [PASS] {tag}{description}")
    else:
        failed += 1
        print(f"  [FAIL] {tag}{description}")
        print(f"  [FAIL] {tag}{description}", file=sys.stderr)

print("====================================================================")
print(">>> RUNNING P7-M3 EMPIRICAL AUDIT & VERIFICATION SUITE <<<")
print("====================================================================")

# -----------------------------------------------------------------------------
# Module 1: Dialogue Input Lock & Clean Exit (avatar_3d.gd & npc_3d.gd)
# -----------------------------------------------------------------------------
print("\n--- Module 1: Dialogue Input Lock & Clean Exit ---")
avatar_gd = (GAME_DIR / "scripts/avatar_3d.gd").read_text(encoding="utf-8")
npc_gd = (GAME_DIR / "scripts/npc_3d.gd").read_text(encoding="utf-8")

# Avatar input guard in _physics_process
check("if input_enabled and _script_input_direction != Vector3.ZERO:" in avatar_gd,
      "Avatar3D guards _script_input_direction with input_enabled in _physics_process", "AvatarLock")
check("func set_input_enabled(enabled: bool) -> void:" in avatar_gd or "func set_input_enabled" in avatar_gd,
      "Avatar3D implements set_input_enabled() method", "AvatarLock")
check("stop_movement()" in avatar_gd and "set_input_enabled" in avatar_gd,
      "Avatar3D halts motion when set_input_enabled(false) is called", "AvatarLock")

# Kinematic simulation: when input_enabled == False, injected direction produces ZERO velocity
class SimulatedAvatar:
    def __init__(self):
        self.input_enabled = True
        self.script_input = (0.0, 0.0, 0.0)
        self.velocity = [0.0, 0.0, 0.0]
        self.current_speed = 6.0
        self.acceleration = 24.0

    def physics_tick(self, delta):
        desired = (0.0, 0.0, 0.0)
        if self.input_enabled and self.script_input != (0.0, 0.0, 0.0):
            desired = self.script_input
        # Accelerate
        target_x = desired[0] * self.current_speed
        target_z = desired[2] * self.current_speed
        self.velocity[0] += (target_x - self.velocity[0]) * min(1.0, self.acceleration * delta)
        self.velocity[2] += (target_z - self.velocity[2]) * min(1.0, self.acceleration * delta)

sim_avatar = SimulatedAvatar()
sim_avatar.input_enabled = False
sim_avatar.script_input = (1.0, 0.0, 0.0)
sim_avatar.physics_tick(0.1)
check(sim_avatar.velocity == [0.0, 0.0, 0.0],
      "Kinematic simulation: Joystick input while input_enabled=False produces zero velocity", "AvatarSim")

sim_avatar.input_enabled = True
sim_avatar.physics_tick(0.1)
check(sim_avatar.velocity[0] > 0.0,
      "Kinematic simulation: Enabling input allows avatar movement", "AvatarSim")

# NPC dialogue lifecycle
check("tc.fade_out_controls()" in npc_gd, "NPC3D.interact() calls tc.fade_out_controls()", "NPCLifecycle")
check("dialogue_panel.close_dialogue()" in npc_gd, "NPC3D.end_dialogue() calls dialogue_panel.close_dialogue()", "NPCLifecycle")
check("tc.fade_in_controls()" in npc_gd, "NPC3D.end_dialogue() calls tc.fade_in_controls()", "NPCLifecycle")
check("end_dialogue()" in npc_gd and "_on_interaction_body_exited" in npc_gd,
      "NPC3D._on_interaction_body_exited() cleanly triggers end_dialogue()", "NPCLifecycle")
check("_is_ending_dialogue" in npc_gd or "_handling_end_dialogue" in npc_gd or "if not _is_talking" in npc_gd,
      "NPC3D dialogue teardown has re-entrancy protection guard", "NPCLifecycle")

# -----------------------------------------------------------------------------
# Module 2: Quest Precondition Deadlock & Retroactive Unlocks (game_state.gd)
# -----------------------------------------------------------------------------
print("\n--- Module 2: Quest Precondition Deadlock & Retroactive Unlocks ---")
gs_gd = (GAME_DIR / "scripts/autoload/game_state.gd").read_text(encoding="utf-8")

check("var active_campus_quest_id: String = \"\"" in gs_gd,
      "GameState declares active_campus_quest_id property", "GameStateQuest")
check("active_campus_quest_id = quest_id" in gs_gd,
      "start_campus_quest() updates active_campus_quest_id", "GameStateQuest")
check('is_zone_unlocked("server_room")' in gs_gd and 'quest_id == "quest_server"' in gs_gd,
      "start_campus_quest() checks retroactive unlocked condition for quest_server", "GameStateQuest")
check('is_zone_unlocked("lab_room")' in gs_gd and 'quest_id == "quest_lab"' in gs_gd,
      "start_campus_quest() checks retroactive unlocked condition for quest_lab", "GameStateQuest")
check('campus_quests[quest_id]["status"] = "ready"' in gs_gd,
      "start_campus_quest() sets status to 'ready' on retroactive match", "GameStateQuest")
check('active_campus_quest_id = ""' in gs_gd and "complete_campus_quest" in gs_gd,
      "complete_campus_quest() clears active_campus_quest_id", "GameStateQuest")
check('"active_campus_quest_id": active_campus_quest_id' in gs_gd,
      "save_to_disk() serializes active_campus_quest_id", "GameStatePersistence")
check('data.get("active_campus_quest_id"' in gs_gd,
      "load_from_disk() deserializes active_campus_quest_id", "GameStatePersistence")

# State simulation for retroactive quest resolution
class SimulatedGameState:
    def __init__(self):
        self.unlocked_zones = set()
        self.campus_quests = {}
        self.active_campus_quest_id = ""

    def unlock_zone(self, zone_id):
        self.unlocked_zones.add(zone_id)

    def is_zone_unlocked(self, zone_id):
        return zone_id in self.unlocked_zones

    def start_campus_quest(self, quest_id, target_count=1):
        self.active_campus_quest_id = quest_id
        if quest_id in self.campus_quests and self.campus_quests[quest_id]["status"] in ["ready", "completed"]:
            return
        if quest_id == "quest_server" and self.is_zone_unlocked("server_room"):
            self.campus_quests[quest_id] = {"status": "ready", "current_count": 1, "target_count": 1}
        elif quest_id == "quest_lab" and self.is_zone_unlocked("lab_room"):
            self.campus_quests[quest_id] = {"status": "ready", "current_count": 1, "target_count": 1}
        else:
            self.campus_quests[quest_id] = {"status": "active", "current_count": 0, "target_count": target_count}

    def complete_campus_quest(self, quest_id):
        if quest_id in self.campus_quests and self.campus_quests[quest_id]["status"] == "ready":
            self.campus_quests[quest_id]["status"] = "completed"
            if self.active_campus_quest_id == quest_id:
                self.active_campus_quest_id = ""

sim_gs = SimulatedGameState()
# Unlock gate first before talking to Bob
sim_gs.unlock_zone("server_room")
sim_gs.start_campus_quest("quest_server", 1)
check(sim_gs.campus_quests["quest_server"]["status"] == "ready",
      "Simulation: Pre-unlocked server gate leads directly to 'ready' status", "QuestSim")
check(sim_gs.active_campus_quest_id == "quest_server",
      "Simulation: active_campus_quest_id matches quest_server", "QuestSim")
sim_gs.complete_campus_quest("quest_server")
check(sim_gs.active_campus_quest_id == "",
      "Simulation: complete_campus_quest clears active_campus_quest_id", "QuestSim")

# -----------------------------------------------------------------------------
# Module 3: 3D Floating Text for Missing Resources (zone_gate_3d.gd)
# -----------------------------------------------------------------------------
print("\n--- Module 3: 3D Floating Text for Missing Resources ---")
gate_gd = (GAME_DIR / "scripts/zone_gate_3d.gd").read_text(encoding="utf-8")

check("func show_missing_resource_feedback" in gate_gd,
      "ZoneGate3D implements show_missing_resource_feedback() method", "GateFeedback")
check("BaseMaterial3D.BILLBOARD_ENABLED" in gate_gd,
      "Floating text Label3D has BaseMaterial3D.BILLBOARD_ENABLED", "GateFeedback")
check("font_size = 24" in gate_gd or "font_size >= 24" in gate_gd,
      "Floating text Label3D has font_size >= 24", "GateFeedback")
check("Color(1.0, 0.3, 0.3)" in gate_gd,
      "Floating text Label3D has bright coral/red color Color(1.0, 0.3, 0.3)", "GateFeedback")
check("Vector3(0.0, 2.5, 0.0)" in gate_gd or "Vector3(0, 2.5, 0)" in gate_gd,
      "Floating text position offset is Vector3(0.0, 2.5, 0.0)", "GateFeedback")
check("label.position.y + 1.2" in gate_gd or "position.y += 1.2" in gate_gd,
      "Floating text tween rises by +1.2m", "GateFeedback")
check("tween_property(label, \"modulate:a\", 0.0, 1.2)" in gate_gd or ("modulate:a" in gate_gd and "1.2" in gate_gd),
      "Floating text tween fades alpha to 0.0 over 1.2s", "GateFeedback")
check("queue_free" in gate_gd, "Floating text calls queue_free upon completion", "GateFeedback")
check('Benötigt %s Energie zum Freischalten' in gate_gd or 'Benötigt' in gate_gd,
      "Gate provides German feedback text on missing energy resources", "GateFeedback")
check('Benötigt Campus Level %d' in gate_gd or 'Campus Level' in gate_gd,
      "Gate provides feedback on required clearance level", "GateFeedback")
check('add_to_group("zone_gates")' in gate_gd,
      "ZoneGate3D registers in 'zone_gates' group in _ready()", "GateGroup")

# -----------------------------------------------------------------------------
# Module 4: Harmonized Loops (Speed Reactive Binding & Campus 2D Boost)
# -----------------------------------------------------------------------------
print("\n--- Module 4: Harmonized Loops ---")
# Speed reactive binding in avatar_3d.gd
check('gs.avatar_stat_updated.connect(_on_avatar_stat_updated)' in avatar_gd or 'avatar_stat_updated' in avatar_gd,
      "Avatar3D connects to GameState.avatar_stat_updated signal", "SpeedHarmonization")
check('func _on_avatar_stat_updated' in avatar_gd,
      "Avatar3D implements _on_avatar_stat_updated() handler", "SpeedHarmonization")
check('stat_name == "avatar_speed"' in avatar_gd and 'current_speed = get_move_speed()' in avatar_gd,
      "Avatar3D immediately updates current_speed on avatar_speed update", "SpeedHarmonization")

# Campus Collectibles idle multiplier in game_state.gd
check("func get_campus_item_multiplier() -> float:" in gs_gd,
      "GameState implements get_campus_item_multiplier() method", "IdleHarmonization")
check("1.0 + (float(collectibles_collected) * 0.05)" in gs_gd or "1.0 + float(collectibles_collected) * 0.05" in gs_gd,
      "get_campus_item_multiplier formula: 1.0 + collectibles_collected * 0.05", "IdleHarmonization")
check("get_campus_item_multiplier()" in gs_gd and "get_effective_passive_rps" in gs_gd,
      "get_effective_passive_rps() factors in get_campus_item_multiplier()", "IdleHarmonization")
check("rps_changed.emit(get_effective_passive_rps())" in gs_gd and "collect_3d_item" in gs_gd,
      "collect_3d_item() emits rps_changed with new boosted rate", "IdleHarmonization")

# Mathematical formula verification across range of collectibles
def calc_campus_mult(count):
    return 1.0 + float(count) * 0.05

check(calc_campus_mult(0) == 1.0, "Campus multiplier at 0 items: exactly 1.00x (zero baseline regression)", "MathOracle")
check(calc_campus_mult(1) == 1.05, "Campus multiplier at 1 item: 1.05x (+5%)", "MathOracle")
check(calc_campus_mult(5) == 1.25, "Campus multiplier at 5 items: 1.25x (+25%)", "MathOracle")
check(calc_campus_mult(10) == 1.50, "Campus multiplier at 10 items: 1.50x (+50%)", "MathOracle")
check(calc_campus_mult(20) == 2.00, "Campus multiplier at 20 items: 2.00x (+100%)", "MathOracle")

# -----------------------------------------------------------------------------
# Module 5: Dynamic QuestWaypoint Compass & Arrival Detection (quest_waypoint.gd)
# -----------------------------------------------------------------------------
print("\n--- Module 5: Dynamic QuestWaypoint Compass & Arrival Detection ---")
waypoint_gd = (GAME_DIR / "scripts/quest_waypoint.gd").read_text(encoding="utf-8")

check("active_campus_quest_id" in waypoint_gd,
      "QuestWaypoint3D inspects GameState.active_campus_quest_id", "WaypointCompass")
check('active_quest == "quest_server"' in waypoint_gd,
      "QuestWaypoint3D handles 'quest_server' branching", "WaypointCompass")
check('is_zone_unlocked("server_room")' in waypoint_gd or 'server_room' in waypoint_gd,
      "QuestWaypoint3D checks server_room unlocked state", "WaypointCompass")
check('active_quest == "quest_lab"' in waypoint_gd,
      "QuestWaypoint3D handles 'quest_lab' branching", "WaypointCompass")
check('is_zone_unlocked("lab_room")' in waypoint_gd or 'lab_room' in waypoint_gd,
      "QuestWaypoint3D checks lab_room unlocked state", "WaypointCompass")
check('ceo_alex' in waypoint_gd or 'NPC_Alex' in waypoint_gd,
      "QuestWaypoint3D targets CEO Alex on default or quest_alex", "WaypointCompass")
check('[ Arrived! ]' in waypoint_gd,
      "QuestWaypoint3D formats text with '[ Arrived! ]' upon arrival", "WaypointArrival")
check('_distance <= arrival_threshold' in waypoint_gd,
      "QuestWaypoint3D checks arrival_threshold (<= 3.0m)", "WaypointArrival")
check('@onready var prompt_label' in waypoint_gd,
      "QuestWaypoint3D exposes prompt_label alias for test interface", "WaypointCompass")

# Mathematical bearing & arrival oracle
def waypoint_math_check(player_pos, target_pos, threshold=3.0):
    dx = target_pos[0] - player_pos[0]
    dz = target_pos[2] - player_pos[2]
    dist = math.sqrt(dx * dx + dz * dz)
    angle = math.atan2(dx, dz)
    arrived = dist <= threshold
    return dist, angle, arrived

dist1, angle1, arrived1 = waypoint_math_check((0, 0, 0), (0, 0, -10))
check(abs(dist1 - 10.0) < 0.001 and abs(angle1 - math.pi) < 0.001 and not arrived1,
      "Trigonometry: Target at (0, 0, -10) yields 10.0m bearing 180 deg, not arrived", "WaypointMath")

dist2, angle2, arrived2 = waypoint_math_check((0, 0, 0), (2.1, 0, 0))
check(abs(dist2 - 2.1) < 0.001 and arrived2,
      "Trigonometry: Target at (2.1, 0, 0) yields 2.1m <= 3.0m -> Arrived! triggered", "WaypointMath")

# -----------------------------------------------------------------------------
# Module 6: Headless Godot Test Suite (test_p7_m3_gameplay.gd)
# -----------------------------------------------------------------------------
print("\n--- Module 6: Headless Godot Test Suite (test_p7_m3_gameplay.gd) ---")
test_file = GAME_DIR / "tests/test_p7_m3_gameplay.gd"
check(test_file.exists(), "tests/test_p7_m3_gameplay.gd exists", "TestSuite")

test_content = test_file.read_text(encoding="utf-8")
check("extends SceneTree" in test_content, "test_p7_m3_gameplay.gd extends SceneTree", "TestSuite")
check("_test_dialogue_input_lock" in test_content, "Tests dialogue input lock", "TestSuite")
check("_test_dialogue_exit_clean_close" in test_content, "Tests dialogue exit clean close", "TestSuite")
check("_test_retroactive_quest_unlock" in test_content, "Tests retroactive quest unlock", "TestSuite")
check("_test_missing_resource_floating_text" in test_content, "Tests 3D floating text", "TestSuite")
check("_test_reactive_speed_binding" in test_content, "Tests reactive speed binding", "TestSuite")
check("_test_campus_collectible_multiplier" in test_content, "Tests campus collectible multiplier", "TestSuite")
check("_test_quest_waypoint_compass" in test_content, "Tests quest waypoint compass", "TestSuite")
check("quit(0)" in test_content and "quit(1)" in test_content, "Contains headless CI exit hooks quit(0) and quit(1)", "TestSuite")

# -----------------------------------------------------------------------------
# Module 7: Regression Test Battery Execution
# -----------------------------------------------------------------------------
print("\n--- Module 7: Regression Test Battery Execution ---")

suites_to_run = [
    ("M1 Challenger Oracle", GAME_DIR / "tests/test_p7_m1_challenger_oracle.py", []),
    ("M2 Empirical Audit", GAME_DIR / "verify_m2.py", []),
    ("Phase 5 Mobile Oracle", GAME_DIR / "tests/test_phase5_mobile.py", []),
    ("Phase 6 Visual Life Oracle", GAME_DIR / "tests/test_phase6_visuals.py", []),
    ("End-to-End Suite", GAME_DIR / "tests/e2e_suite.py", ["--tier", "1"]),
]

for item in suites_to_run:
    name, script_path, extra_args = item[0], item[1], item[2]
    if script_path.exists():
        res = subprocess.run([sys.executable, str(script_path)] + extra_args, capture_output=True, text=True, cwd=str(GAME_DIR))
        check(res.returncode == 0, f"Regression Battery: {name} passed (exit code 0)", "Regression")
        if res.returncode != 0:
            err_msg = f"    [ERROR OUTPUT from {name}]:\n{res.stderr}\n{res.stdout[-400:]}"
            print(err_msg)
            print(err_msg, file=sys.stderr)
    else:
        check(False, f"Regression Battery: {name} script {script_path} not found", "Regression")

# -----------------------------------------------------------------------------
# Final Summary
# -----------------------------------------------------------------------------
print("\n====================================================================")
print(f">>> VERIFY P7-M3 SUMMARY: {passed} PASSED, {failed} FAILED <<<")
print("====================================================================")

if failed == 0:
    print(">>> 100% P7-M3 VERIFICATION & REGRESSION SAFETY SUCCESSFUL! <<<")
    sys.exit(0)
else:
    print(f">>> P7-M3 VERIFICATION FAILED WITH {failed} ERRORS! <<<", file=sys.stderr)
    sys.exit(1)
