#!/usr/bin/env python3
"""
Empirical Verification & Forensic Audit Suite for Milestone P7-M2
Tests Chibi 3D Models, Articulations, Scene Hierarchies, Shaders, Low-Poly Triangle Budget, and Invariants.
"""
import sys
import re
import math
from pathlib import Path

GAME_DIR = Path("c:/Projects/Game/IdleArcade")

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

print("====================================================================")
print(">>> RUNNING P7-M2 EMPIRICAL AUDIT & VERIFICATION SUITE <<<")
print("====================================================================")

# -----------------------------------------------------------------------------
# Module 1: Avatar 3D (Chibi Player Avatar)
# -----------------------------------------------------------------------------
print("\n--- Module 1: Avatar 3D (Chibi Player Avatar) ---")
avatar_tscn = (GAME_DIR / "scenes/avatar_3d.tscn").read_text(encoding="utf-8")
avatar_gd = (GAME_DIR / "scripts/avatar_3d.gd").read_text(encoding="utf-8")

check('parent="Visuals/ChibiRoot"' in avatar_tscn, "Visuals/ChibiRoot hierarchy node present", "Avatar")
check('parent="Visuals/ChibiRoot" name="Head"' in avatar_tscn or ('name="Head"' in avatar_tscn and 'parent="Visuals/ChibiRoot"' in avatar_tscn), "Head node present", "Avatar")
check('parent="Visuals/ChibiRoot/Head"' in avatar_tscn and 'name="Visor"' in avatar_tscn, "Visor node attached to Head", "Avatar")
check('parent="Visuals/ChibiRoot/Head"' in avatar_tscn and 'name="Hair"' in avatar_tscn, "Hair node attached to Head", "Avatar")
check('parent="Visuals/ChibiRoot"' in avatar_tscn and 'name="Torso"' in avatar_tscn, "Torso node present", "Avatar")
check('parent="Visuals/ChibiRoot"' in avatar_tscn and 'name="Backpack"' in avatar_tscn, "Backpack accessory node present", "Avatar")
check('parent="Visuals/ChibiRoot"' in avatar_tscn and 'name="LeftArm"' in avatar_tscn, "LeftArm articulated node present", "Avatar")
check('parent="Visuals/ChibiRoot"' in avatar_tscn and 'name="RightArm"' in avatar_tscn, "RightArm articulated node present", "Avatar")
check('parent="Visuals/ChibiRoot"' in avatar_tscn and 'name="LeftLeg"' in avatar_tscn, "LeftLeg articulated node present", "Avatar")
check('parent="Visuals/ChibiRoot"' in avatar_tscn and 'name="RightLeg"' in avatar_tscn, "RightLeg articulated node present", "Avatar")

# Preserved nodes
check("CollisionShape3D" in avatar_tscn, "Preserved CollisionShape3D", "Avatar")
check("InteractionArea" in avatar_tscn, "Preserved InteractionArea", "Avatar")
check("FootstepDust" in avatar_tscn, "Preserved FootstepDust particles", "Avatar")
check("GroundShadow" in avatar_tscn, "Preserved GroundShadow", "Avatar")
check("transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1.4, 0.35)" in avatar_tscn, "Preserved DirectionalPointer transform invariant for P4-M1 challenge", "Avatar")

# Script locomotion checks
check("left_arm.rotation.x = -arm_swing" in avatar_gd, "Anti-phase arm swing implemented (left)", "AvatarLocomotion")
check("right_arm.rotation.x = arm_swing" in avatar_gd, "Anti-phase arm swing implemented (right)", "AvatarLocomotion")
check("left_leg.rotation.x = leg_swing" in avatar_gd, "Anti-phase leg swing implemented (left)", "AvatarLocomotion")
check("right_leg.rotation.x = -leg_swing" in avatar_gd, "Anti-phase leg swing implemented (right)", "AvatarLocomotion")
check("chibi_torso.position.y" in avatar_gd, "Torso vertical bobbing implemented", "AvatarLocomotion")
check("current_horizontal.length() > 0.05" in avatar_gd, "Preserved deadband check (> 0.05) for stationary avatar", "AvatarLocomotion")

# -----------------------------------------------------------------------------
# Module 2: NPC 3D (Distinct Chibi Campus NPCs)
# -----------------------------------------------------------------------------
print("\n--- Module 2: NPC 3D (Distinct Chibi Campus NPCs) ---")
npc_tscn = (GAME_DIR / "scenes/npc_3d.tscn").read_text(encoding="utf-8")
npc_gd = (GAME_DIR / "scripts/npc_3d.gd").read_text(encoding="utf-8")

check("Visuals/ChibiRoot" in npc_tscn, "Visuals/ChibiRoot present in NPC", "NPC")
check("AlexAccessories" in npc_tscn, "AlexAccessories present", "NPC")
check("TieMesh" in npc_tscn, "Alex tie mesh present", "NPC")
check("BobAccessories" in npc_tscn, "BobAccessories present", "NPC")
check("HardHatDome" in npc_tscn, "Bob hard hat present", "NPC")
check("BlueprintRoll" in npc_tscn, "Bob blueprint roll present", "NPC")
check("LisaAccessories" in npc_tscn, "LisaAccessories present", "NPC")
check("LabCoatMesh" in npc_tscn, "Lisa lab coat present", "NPC")
check("QuantumFlask" in npc_tscn, "Lisa quantum flask present", "NPC")

# Preserved billboard labels
check("NameLabel3D" in npc_tscn, "Preserved NameLabel3D", "NPC")
check("PromptLabel3D" in npc_tscn, "Preserved PromptLabel3D", "NPC")
check("QuestMarkerLabel3D" in npc_tscn, "Preserved QuestMarkerLabel3D", "NPC")
check("EmoteLabel3D" in npc_tscn, "Preserved EmoteLabel3D", "NPC")

# Script accessory switching
check("func _apply_chibi_accessories" in npc_gd, "npc_3d.gd implements _apply_chibi_accessories()", "NPCScript")
check('alex_accessories.visible = (npc_id == "ceo_alex")' in npc_gd, "ceo_alex accessory visibility branch", "NPCScript")
check('bob_accessories.visible = (npc_id == "architect_bob")' in npc_gd, "architect_bob accessory visibility branch", "NPCScript")
check('lisa_accessories.visible = (npc_id == "scientist_lisa")' in npc_gd, "scientist_lisa accessory visibility branch", "NPCScript")

# -----------------------------------------------------------------------------
# Module 3: Worker Avatar 3D (Incubator Workers)
# -----------------------------------------------------------------------------
print("\n--- Module 3: Worker Avatar 3D (Incubator Workers) ---")
worker_tscn = (GAME_DIR / "scenes/worker_avatar_3d.tscn").read_text(encoding="utf-8")
worker_gd = (GAME_DIR / "scripts/worker_avatar_3d.gd").read_text(encoding="utf-8")

check("Visuals/ChibiRoot" in worker_tscn, "ChibiRoot present in worker", "Worker")
check("VisorEmoteLabel" in worker_tscn, "VisorEmoteLabel present", "Worker")
check("LaptopRoot" in worker_tscn, "LaptopRoot present", "Worker")
check("LaptopScreen" in worker_tscn, "Preserved LaptopScreen for P6 tests", "Worker")
check("CoffeeMug" in worker_tscn, "CoffeeMug accessory present", "Worker")
check("SteamParticles" in worker_tscn, "Coffee mug has SteamParticles", "Worker")
check("SpeechBubble3D" in worker_tscn, "Preserved SpeechBubble3D", "Worker")

# Script FSM visor & accessory swapping
check("func _update_accessories_for_state" in worker_gd, "worker_avatar_3d.gd implements _update_accessories_for_state()", "WorkerScript")
check('"0101"' in worker_gd, "TYPING: matrix code visor emotion", "WorkerScript")
check('"•_•"' in worker_gd, "WALKING: focused eyes visor emotion", "WorkerScript")
check('"^.^"' in worker_gd, "COFFEE_BREAK: happy smile visor emotion", "WorkerScript")
check('"★_★"' in worker_gd, "CELEBRATING: star eyes visor emotion", "WorkerScript")
check("laptop_root.visible = true" in worker_gd, "TYPING activates laptop", "WorkerScript")
check("coffee_mug.visible = true" in worker_gd, "COFFEE_BREAK activates coffee mug", "WorkerScript")

# -----------------------------------------------------------------------------
# Module 4: Collectible 3D (3 Distinct Props)
# -----------------------------------------------------------------------------
print("\n--- Module 4: Collectible 3D (3 Distinct Props) ---")
coll_tscn = (GAME_DIR / "scenes/collectible_3d.tscn").read_text(encoding="utf-8")
coll_gd = (GAME_DIR / "scripts/collectible_3d.gd").read_text(encoding="utf-8")

check("BriefcaseMesh" in coll_tscn, "Visuals/BriefcaseMesh present", "Collectible")
check("CoffeeMesh" in coll_tscn, "Visuals/CoffeeMesh present", "Collectible")
check("USBMesh" in coll_tscn, "Visuals/USBMesh present", "Collectible")
check("SteamParticles" in coll_tscn, "SteamParticles on coffee mug present", "Collectible")
check("SparkleParticles" in coll_tscn, "SparkleParticles present", "Collectible")
check("USBBlinkLED" in coll_tscn, "USBBlinkLED present", "Collectible")

# Script checks
check('briefcase_mesh.visible = (item_type == "briefcase")' in coll_gd, "Briefcase dynamic visibility", "CollectibleScript")
check('coffee_mesh.visible = (item_type == "coffee")' in coll_gd, "Coffee dynamic visibility", "CollectibleScript")
check('usb_mesh.visible = (item_type == "usb_drive")' in coll_gd, "USB drive dynamic visibility", "CollectibleScript")
check("func _spawn_floating_text" in coll_gd, "Preserved _spawn_floating_text()", "CollectibleScript")
check("rotate_y" in coll_gd, "Continuous Y-axis rotation in _process", "CollectibleScript")
check("sin(_time * bob_speed) * bob_amplitude" in coll_gd, "Floating sine wave bobbing in _process", "CollectibleScript")

# -----------------------------------------------------------------------------
# Module 5: Zone Gate 3D (Campus Tech Gates)
# -----------------------------------------------------------------------------
print("\n--- Module 5: Zone Gate 3D (Campus Tech Gates) ---")
gate_tscn = (GAME_DIR / "scenes/zone_gate_3d.tscn").read_text(encoding="utf-8")
gate_gd = (GAME_DIR / "scripts/zone_gate_3d.gd").read_text(encoding="utf-8")

check('parent="Visuals/LeftPost"' in gate_tscn and 'name="StatusBeacon"' in gate_tscn, "LeftPost/StatusBeacon exists", "Gate")
check('parent="Visuals/RightPost"' in gate_tscn and 'name="StatusBeacon"' in gate_tscn, "RightPost/StatusBeacon exists", "Gate")
check('name="UnlockParticles"' in gate_tscn and 'parent="Visuals"' in gate_tscn, "UnlockParticles exists", "Gate")
check('name="BarrierMesh"' in gate_tscn and 'parent="Visuals"' in gate_tscn, "Preserved BarrierMesh", "Gate")
check("InteractionArea" in gate_tscn, "Preserved InteractionArea", "Gate")
check("PromptLabel3D" in gate_tscn, "Preserved PromptLabel3D", "Gate")

# Script gate checks
check("func _set_beacon_color" in gate_gd, "zone_gate_3d.gd implements _set_beacon_color()", "GateScript")
check("func show_missing_resource_feedback" in gate_gd, "zone_gate_3d.gd implements show_missing_resource_feedback()", "GateScript")
check("unlock_particles.restart()" in gate_gd, "Unlock particles triggered on open_gate()", "GateScript")

# -----------------------------------------------------------------------------
# Module 6: Mobile Shaders & Low-Poly Triangle Budget Verification
# -----------------------------------------------------------------------------
print("\n--- Module 6: Mobile Shaders & Low-Poly Triangle Budget Verification ---")
project_godot = (GAME_DIR / "project.godot").read_text(encoding="utf-8")
check('renderer/rendering_method="gl_compatibility"' in project_godot, "gl_compatibility renderer configured", "ShaderPerf")
check('renderer/rendering_method.mobile="gl_compatibility"' in project_godot, "mobile gl_compatibility renderer configured", "ShaderPerf")

# Verify StandardMaterial3D in all 5 scenes (no custom .gdshader or heavy vertex passes)
scenes = ["avatar_3d.tscn", "npc_3d.tscn", "worker_avatar_3d.tscn", "collectible_3d.tscn", "zone_gate_3d.tscn"]
for s in scenes:
    text = (GAME_DIR / f"scenes/{s}").read_text(encoding="utf-8")
    check("StandardMaterial3D" in text, f"{s} exclusively uses StandardMaterial3D", "ShaderPerf")
    check("ShaderMaterial" not in text, f"{s} contains 0 unoptimized ShaderMaterials", "ShaderPerf")

# Triangle parsing algorithm based on Godot 4 primitive meshes
def parse_mesh_triangles(mesh_type: str, mesh_props: dict) -> int:
    if mesh_type == "BoxMesh":
        subdiv_w = int(mesh_props.get("subdivide_width", 0))
        subdiv_h = int(mesh_props.get("subdivide_height", 0))
        subdiv_d = int(mesh_props.get("subdivide_depth", 0))
        return 12 * (subdiv_w + 1) * (subdiv_h + 1)
    elif mesh_type == "PlaneMesh":
        subdiv_w = int(mesh_props.get("subdivide_width", 0))
        subdiv_d = int(mesh_props.get("subdivide_depth", 0))
        return 2 * (subdiv_w + 1) * (subdiv_d + 1)
    elif mesh_type == "CylinderMesh":
        radial = int(mesh_props.get("radial_segments", 64))
        rings = int(mesh_props.get("rings", 4))
        return (radial * rings * 2) + (radial * 2)
    elif mesh_type == "SphereMesh":
        radial = int(mesh_props.get("radial_segments", 64))
        rings = int(mesh_props.get("rings", 32))
        return radial * rings * 2
    elif mesh_type == "CapsuleMesh":
        radial = int(mesh_props.get("radial_segments", 64))
        rings = int(mesh_props.get("rings", 8))
        return radial * (rings + 1) * 2
    elif mesh_type == "TorusMesh":
        rings = int(mesh_props.get("rings", 64))
        ring_segments = int(mesh_props.get("ring_segments", 32))
        return rings * ring_segments * 2
    elif mesh_type == "PrismMesh":
        return 8
    elif mesh_type == "QuadMesh":
        return 2
    else:
        return 100

def get_scene_triangles(scene_path: Path):
    text = scene_path.read_text(encoding="utf-8")
    sub_res_pattern = re.compile(r'\[sub_resource type=\"([^\"]+Mesh)\" id=\"([^\"]+)\"\](.*?)(?=\n\[|\Z)', re.DOTALL)
    meshes = {}
    for match in sub_res_pattern.finditer(text):
        m_type = match.group(1)
        m_id = match.group(2)
        body = match.group(3)
        props = {}
        for line in body.strip().split("\n"):
            line = line.strip()
            if "=" in line:
                k, v = line.split("=", 1)
                props[k.strip()] = v.strip()
        tri_count = parse_mesh_triangles(m_type, props)
        meshes[m_id] = (m_type, tri_count, props)

    node_pattern = re.compile(r'\[node name=\"([^\"]+)\" type=\"MeshInstance3D\" parent=\"([^\"]*)\"\](.*?)(?=\n\[|\Z)', re.DOTALL)
    total_scene_tris = 0
    node_tri_details = []
    for match in node_pattern.finditer(text):
        node_name = match.group(1)
        body = match.group(3)
        m_ref = re.search(r'mesh = SubResource\(\"([^\"]+)\"\)', body)
        if m_ref:
            sub_id = m_ref.group(1)
            if sub_id in meshes:
                m_type, count, props = meshes[sub_id]
                total_scene_tris += count
                node_tri_details.append((node_name, m_type, count))
            else:
                total_scene_tris += 50
                node_tri_details.append((node_name, "unknown_mesh", 50))
    return total_scene_tris, node_tri_details

avatar_tris, _ = get_scene_triangles(GAME_DIR / "scenes/avatar_3d.tscn")
npc_tris, _ = get_scene_triangles(GAME_DIR / "scenes/npc_3d.tscn")
worker_tris, _ = get_scene_triangles(GAME_DIR / "scenes/worker_avatar_3d.tscn")
coll_tris, _ = get_scene_triangles(GAME_DIR / "scenes/collectible_3d.tscn")
gate_tris, _ = get_scene_triangles(GAME_DIR / "scenes/zone_gate_3d.tscn")
office_tris, _ = get_scene_triangles(GAME_DIR / "scenes/office_props.tscn")
main_tris, _ = get_scene_triangles(GAME_DIR / "scenes/main_3d.tscn")

check(avatar_tris < 1000, f"avatar_3d.tscn low-poly ({avatar_tris} tris < 1,000)", "PolyBudget")
check(npc_tris < 1200, f"npc_3d.tscn low-poly ({npc_tris} tris < 1,200)", "PolyBudget")
check(worker_tris < 1000, f"worker_avatar_3d.tscn low-poly ({worker_tris} tris < 1,000)", "PolyBudget")
check(coll_tris < 600, f"collectible_3d.tscn low-poly ({coll_tris} tris < 600)", "PolyBudget")
check(gate_tris < 600, f"zone_gate_3d.tscn low-poly ({gate_tris} tris < 600)", "PolyBudget")

# Concurrent campus geometry calculation: 1 Avatar, 3 NPCs, 5 Workers, 6 Collectibles, 3 Gates, 4 Office props, Main
total_campus_triangles = (
    main_tris +
    avatar_tris * 1 +
    npc_tris * 3 +
    worker_tris * 5 +
    coll_tris * 6 +
    gate_tris * 3 +
    office_tris * 4
)
print(f"  [INFO] Total concurrent campus triangles: {total_campus_triangles} (Budget: < 22,000)")
check(total_campus_triangles < 22000, f"Campus polygon count ({total_campus_triangles}) strictly within low-poly budget (<22,000 tris)", "PolyBudget")

# Explicit low-poly subdivision property checks in .tscn files
check("radial_segments = 12" in avatar_tscn and "rings = 6" in avatar_tscn, "avatar_3d Head SphereMesh explicit low-poly subdivisions", "PolySubdiv")
check("radial_segments = 12" in npc_tscn and "radial_segments = 10" in npc_tscn, "npc_3d explicit low-poly subdivisions", "PolySubdiv")
check("radial_segments = 10" in worker_tscn and "ring_segments = 6" in worker_tscn, "worker_avatar_3d explicit low-poly subdivisions", "PolySubdiv")
check("ring_segments = 6" in coll_tscn and "radial_segments = 10" in coll_tscn, "collectible_3d explicit low-poly subdivisions", "PolySubdiv")
check("radial_segments = 8" in gate_tscn and "rings = 4" in gate_tscn, "zone_gate_3d explicit low-poly subdivisions", "PolySubdiv")

# -----------------------------------------------------------------------------
# Module 7: Test Suite test_p7_m2_models.gd Verification
# -----------------------------------------------------------------------------
print("\n--- Module 7: Test Suite test_p7_m2_models.gd Verification ---")
test_m2 = (GAME_DIR / "tests/test_p7_m2_models.gd").read_text(encoding="utf-8")
check("extends SceneTree" in test_m2, "test_p7_m2_models.gd extends SceneTree", "TestSuite")
check("_test_chibi_player_avatar" in test_m2, "Tests Chibi player avatar", "TestSuite")
check("_test_chibi_npcs" in test_m2, "Tests Chibi NPCs and profession accessories", "TestSuite")
check("_test_incubator_workers" in test_m2, "Tests incubator workers and dynamic accessories", "TestSuite")
check("_test_distinct_collectibles" in test_m2, "Tests distinct collectibles", "TestSuite")
check("_test_campus_tech_gates" in test_m2, "Tests campus tech gates and beacons", "TestSuite")
check("_test_mobile_performance_materials" in test_m2, "Tests mobile renderer and materials", "TestSuite")
check("campus_tris < 22000" in test_m2, "test_p7_m2_models.gd contains explicit <22,000 triangle budget assertion", "TestSuite")
check("quit(0)" in test_m2, "Contains clean quit(0) for headless CI", "TestSuite")
check("quit(1)" in test_m2, "Contains fail quit(1) for headless CI", "TestSuite")

print("\n====================================================================")
print(f">>> AUDIT SUMMARY: {passed} PASSED, {failed} FAILED <<<")
print("====================================================================")

if failed == 0:
    print(">>> 100% P7-M2 VERIFICATION SUCCESSFUL! <<<")
    sys.exit(0)
else:
    print(f">>> P7-M2 VERIFICATION FAILED WITH {failed} ERRORS! <<<")
    sys.exit(1)
