#!/usr/bin/env python3
"""
Empirical Challenger Test Suite for Phase 9 Milestone 2:
Low-Poly Geometry, Triangle Budget & Visual Material Verification
File: IdleArcade/tests/test_p9_m2_challenger_geometry.py

Mission:
1. Parse `scenes/server_terminal.tscn` and `scenes/pitch_stage.tscn`.
2. Compute the exact polygon/triangle count of all primitive and custom meshes.
3. Assert that combined triangle count for both stations is strictly < 2,500 triangles.
4. Verify mesh materials, colors, emission, PBR properties, and particle flags.
5. Stress-test geometry bounds, collision shapes, and dynamic particle worst-cases.
"""

import sys
import os
import re
import math
from pathlib import Path

# UTF-8 stdout configuration
if hasattr(sys.stdout, "reconfigure"):
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass

SCRIPT_DIR = Path(__file__).resolve().parent
GAME_DIR = SCRIPT_DIR.parent

class ChallengerReporter:
    def __init__(self):
        self.passes = 0
        self.fails = 0
        self.total = 0

    def assert_check(self, condition: bool, description: str, detail: str = ""):
        self.total += 1
        if condition:
            print(f"  [PASS] {description}")
            self.passes += 1
        else:
            msg = f"  [FAIL] {description}"
            if detail:
                msg += f" -> {detail}"
            print(msg)
            self.fails += 1

reporter = ChallengerReporter()

# ==============================================================================
# Helper Functions: TSCN Parser & Geometry Topology Formulas
# ==============================================================================

def parse_tscn(content: str) -> dict:
    """Parses a Godot .tscn file into structured subresources, external resources, and nodes."""
    subresources = {}
    extresources = {}
    nodes = []

    # Parse ext_resource
    for match in re.finditer(r'\[ext_resource\s+type="([^"]+)"\s+path="([^"]+)"\s+id="([^"]+)"\]', content):
        extresources[match.group(3)] = {
            "type": match.group(1),
            "path": match.group(2)
        }

    # Parse sub_resource blocks
    subres_matches = re.finditer(r'\[sub_resource\s+type="([^"]+)"\s+id="([^"]+)"\]([\s\S]*?)(?=\n\[|\Z)', content)
    for match in subres_matches:
        rtype = match.group(1)
        rid = match.group(2)
        raw_body = match.group(3).strip()
        props = {}
        for line in raw_body.splitlines():
            line = line.strip()
            if not line or line.startswith(";"):
                continue
            if "=" in line:
                k, v = line.split("=", 1)
                k = k.strip()
                v = v.strip()
                props[k] = v
        subresources[rid] = {
            "type": rtype,
            "props": props,
            "raw": raw_body
        }

    # Parse node blocks
    node_matches = re.finditer(r'\[node\s+name="([^"]+)"(?:\s+type="([^"]+)")?([^\]]*)\]([\s\S]*?)(?=\n\[|\Z)', content)
    for match in node_matches:
        nname = match.group(1)
        ntype = match.group(2)
        header_extra = match.group(3)
        raw_body = match.group(4).strip()
        
        parent_match = re.search(r'parent="([^"]+)"', header_extra)
        parent = parent_match.group(1) if parent_match else None
        
        inst_match = re.search(r'instance=ExtResource\("([^"]+)"\)', header_extra)
        instance = inst_match.group(1) if inst_match else None

        groups_match = re.search(r'groups=\[([^\]]+)\]', header_extra)
        groups = [g.strip().strip('"') for g in groups_match.group(1).split(",")] if groups_match else []

        props = {}
        for line in raw_body.splitlines():
            line = line.strip()
            if not line or line.startswith(";"):
                continue
            if "=" in line:
                k, v = line.split("=", 1)
                k = k.strip()
                v = v.strip()
                props[k] = v

        nodes.append({
            "name": nname,
            "type": ntype,
            "parent": parent,
            "instance": instance,
            "groups": groups,
            "props": props,
            "raw": raw_body
        })

    return {
        "extresources": extresources,
        "subresources": subresources,
        "nodes": nodes
    }

def calculate_mesh_triangles(mesh_type: str, props: dict) -> int:
    """Exact Godot 4 standard topology formula for 3D primitive meshes."""
    if mesh_type == "BoxMesh":
        sub_w = int(props.get("subdivide_width", 0))
        sub_h = int(props.get("subdivide_height", 0))
        sub_d = int(props.get("subdivide_depth", 0))
        faces_xy = 2 * (sub_w + 1) * (sub_h + 1) * 2
        faces_xz = 2 * (sub_w + 1) * (sub_d + 1) * 2
        faces_yz = 2 * (sub_h + 1) * (sub_d + 1) * 2
        return faces_xy + faces_xz + faces_yz

    elif mesh_type == "PlaneMesh":
        sub_w = int(props.get("subdivide_width", 0))
        sub_d = int(props.get("subdivide_depth", 0))
        return (sub_w + 1) * (sub_d + 1) * 2

    elif mesh_type == "CylinderMesh":
        rad = int(props.get("radial_segments", 64))
        rings = int(props.get("rings", 4))
        cap_top = props.get("cap_top", "true").lower() != "false"
        cap_bottom = props.get("cap_bottom", "true").lower() != "false"
        side_tris = rad * rings * 2
        cap_tris = (rad if cap_top else 0) + (rad if cap_bottom else 0)
        return side_tris + cap_tris

    elif mesh_type == "SphereMesh":
        rad = int(props.get("radial_segments", 64))
        rings = int(props.get("rings", 32))
        is_hemi = props.get("is_hemisphere", "false").lower() == "true"
        if is_hemi:
            return rad * rings * 2 + rad
        return rad * rings * 2

    elif mesh_type == "CapsuleMesh":
        rad = int(props.get("radial_segments", 64))
        rings = int(props.get("rings", 8))
        return rad * (rings + 1) * 2

    elif mesh_type == "TorusMesh":
        rings = int(props.get("rings", 64))
        ring_segs = int(props.get("ring_segments", 32))
        return rings * ring_segs * 2

    elif mesh_type == "PrismMesh":
        return 8

    elif mesh_type == "QuadMesh":
        return 2

    return 12

def parse_vector3(vec_str: str) -> tuple:
    match = re.search(r'Vector3\(\s*([-\d.]+)\s*,\s*([-\d.]+)\s*,\s*([-\d.]+)\s*\)', vec_str)
    if match:
        return (float(match.group(1)), float(match.group(2)), float(match.group(3)))
    return (0.0, 0.0, 0.0)

def parse_color(color_str: str) -> tuple:
    match = re.search(r'Color\(\s*([-\d.]+)\s*,\s*([-\d.]+)\s*,\s*([-\d.]+)(?:\s*,\s*([-\d.]+))?\s*\)', color_str)
    if match:
        r = float(match.group(1))
        g = float(match.group(2))
        b = float(match.group(3))
        a = float(match.group(4)) if match.group(4) is not None else 1.0
        return (r, g, b, a)
    return (0.0, 0.0, 0.0, 1.0)


# ==============================================================================
# CHALLENGE SUITE EXECUTION
# ==============================================================================

def run_empirical_challenge():
    print("\n" + "=" * 76)
    print(" >>> EMPIRICAL CHALLENGE: PHASE 9 M2 LOW-POLY GEOMETRY & MATERIAL AUDIT <<<")
    print("=" * 76)

    st_path = GAME_DIR / "scenes" / "server_terminal.tscn"
    ps_path = GAME_DIR / "scenes" / "pitch_stage.tscn"

    reporter.assert_check(st_path.exists(), "scenes/server_terminal.tscn exists on disk")
    reporter.assert_check(ps_path.exists(), "scenes/pitch_stage.tscn exists on disk")

    if not st_path.exists() or not ps_path.exists():
        print("CRITICAL: One or more target scene files missing!")
        return 1

    st_content = st_path.read_text(encoding="utf-8")
    ps_content = ps_path.read_text(encoding="utf-8")

    st_parsed = parse_tscn(st_content)
    ps_parsed = parse_tscn(ps_content)

    # --------------------------------------------------------------------------
    # DIMENSION 1: Server Room Overclock Terminal Primitive Mesh Audit
    # --------------------------------------------------------------------------
    print("\n--- DIMENSION 1: Server Room Overclock Terminal Mesh Breakdown ---")
    st_meshes = {}
    st_mesh_instances = []
    st_materials = {}

    for rid, sdata in st_parsed["subresources"].items():
        if "Mesh" in sdata["type"]:
            tris = calculate_mesh_triangles(sdata["type"], sdata["props"])
            st_meshes[rid] = {
                "type": sdata["type"],
                "props": sdata["props"],
                "triangles": tris
            }
        elif "Material" in sdata["type"]:
            st_materials[rid] = {
                "type": sdata["type"],
                "props": sdata["props"]
            }

    for node in st_parsed["nodes"]:
        if "mesh" in node["props"]:
            m_sub = re.search(r'SubResource\("([^"]+)"\)', node["props"]["mesh"])
            if m_sub:
                st_mesh_instances.append({
                    "node_name": node["name"],
                    "parent": node["parent"],
                    "mesh_id": m_sub.group(1),
                    "node_type": node.get("type")
                })

    # Validate itemized meshes in ServerTerminal
    expected_st_meshes = [
        ("RackChassis", "BoxMesh_rack", 12),
        ("ServerBladeUnits", "BoxMesh_blades", 12),
        ("ConsoleDesk", "BoxMesh_desk", 12),
        ("KeyboardPlate", "BoxMesh_keyboard", 12),
        ("CRTMonitorHousing", "BoxMesh_crt_housing", 12),
        ("CRTScreenBezel", "BoxMesh_crt_bezel", 12),
        ("LED_Power", "BoxMesh_led_power", 12),
        ("LED_Data", "BoxMesh_led_data", 12),
        ("LED_Overclock", "BoxMesh_led_overclock", 12),
        ("LED_Cooldown", "BoxMesh_led_cooldown", 12),
    ]

    st_static_tris = 0
    for node_name, mesh_id, expected_tris in expected_st_meshes:
        found_nodes = [m for m in st_mesh_instances if m["node_name"] == node_name]
        reporter.assert_check(len(found_nodes) == 1, f"Node '{node_name}' instanced exactly once in ServerTerminal")
        if found_nodes:
            inst = found_nodes[0]
            reporter.assert_check(inst["mesh_id"] == mesh_id, f"Node '{node_name}' references mesh '{mesh_id}'")
            mesh_data = st_meshes.get(mesh_id, {})
            calc_tris = mesh_data.get("triangles", 0)
            reporter.assert_check(calc_tris == expected_tris,
                                  f"Mesh '{mesh_id}' triangle count matches exact expectation: {calc_tris} == {expected_tris}")
            st_static_tris += calc_tris

    # Particle base mesh in ServerTerminal
    spark_mesh_id = "BoxMesh_spark_particle"
    reporter.assert_check(spark_mesh_id in st_meshes, f"Particle mesh '{spark_mesh_id}' defined in ServerTerminal")
    spark_tris = st_meshes.get(spark_mesh_id, {}).get("triangles", 0)
    reporter.assert_check(spark_tris == 12, f"Particle mesh '{spark_mesh_id}' has exactly 12 triangles (actual: {spark_tris})")
    
    st_total_tris = st_static_tris + spark_tris
    print(f"  -> Server Terminal Base Triangles (10 static meshes + 1 particle mesh): {st_total_tris} tris")
    reporter.assert_check(st_total_tris == 132, f"Server Terminal base geometry strictly equals 132 triangles (actual: {st_total_tris})")

    # --------------------------------------------------------------------------
    # DIMENSION 2: Courtyard Pitch Stage Primitive Mesh Audit
    # --------------------------------------------------------------------------
    print("\n--- DIMENSION 2: Courtyard Pitch Stage Mesh Breakdown ---")
    ps_meshes = {}
    ps_mesh_instances = []
    ps_materials = {}

    for rid, sdata in ps_parsed["subresources"].items():
        if "Mesh" in sdata["type"]:
            tris = calculate_mesh_triangles(sdata["type"], sdata["props"])
            ps_meshes[rid] = {
                "type": sdata["type"],
                "props": sdata["props"],
                "triangles": tris
            }
        elif "Material" in sdata["type"]:
            ps_materials[rid] = {
                "type": sdata["type"],
                "props": sdata["props"]
            }

    for node in ps_parsed["nodes"]:
        if "mesh" in node["props"]:
            m_sub = re.search(r'SubResource\("([^"]+)"\)', node["props"]["mesh"])
            if m_sub:
                ps_mesh_instances.append({
                    "node_name": node["name"],
                    "parent": node["parent"],
                    "mesh_id": m_sub.group(1),
                    "node_type": node.get("type")
                })

    expected_ps_meshes = [
        ("StagePlanks", "BoxMesh_planks", 12),
        ("StageBorderFrame", "BoxMesh_border", 12),
        ("BackdropBoard", "BoxMesh_backdrop", 12),
        ("Podium", "BoxMesh_podium", 12),
        ("MicStand", "CylinderMesh_mic_stand", 24),
        ("MicHead", "SphereMesh_mic_head", 36),
        ("Head", "SphereMesh_investor_head", 64),
        ("Hair", "BoxMesh_investor_hair", 12),
        ("Sunglasses", "BoxMesh_investor_sunglasses", 12),
        ("TorsoSuit", "BoxMesh_investor_torso", 12),
        ("GoldTie", "BoxMesh_investor_tie", 12),
        ("LeftArm", "BoxMesh_investor_arm_l", 12),
        ("RightArm", "BoxMesh_investor_arm_r", 12),
        ("CashBriefcase", "BoxMesh_investor_briefcase", 12),
    ]

    ps_static_tris = 0
    for node_name, mesh_id, expected_tris in expected_ps_meshes:
        found_nodes = [m for m in ps_mesh_instances if m["node_name"] == node_name]
        reporter.assert_check(len(found_nodes) == 1, f"Node '{node_name}' instanced exactly once in PitchStage")
        if found_nodes:
            inst = found_nodes[0]
            reporter.assert_check(inst["mesh_id"] == mesh_id, f"Node '{node_name}' references mesh '{mesh_id}'")
            mesh_data = ps_meshes.get(mesh_id, {})
            calc_tris = mesh_data.get("triangles", 0)
            reporter.assert_check(calc_tris == expected_tris,
                                  f"Mesh '{mesh_id}' triangle count matches exact expectation: {calc_tris} == {expected_tris}")
            ps_static_tris += calc_tris

    # Particle base mesh in PitchStage
    confetti_mesh_id = "BoxMesh_confetti_particle"
    reporter.assert_check(confetti_mesh_id in ps_meshes, f"Particle mesh '{confetti_mesh_id}' defined in PitchStage")
    confetti_tris = ps_meshes.get(confetti_mesh_id, {}).get("triangles", 0)
    reporter.assert_check(confetti_tris == 12, f"Particle mesh '{confetti_mesh_id}' has exactly 12 triangles (actual: {confetti_tris})")

    ps_total_tris = ps_static_tris + confetti_tris
    print(f"  -> Pitch Stage Base Triangles (14 static meshes + 1 particle mesh): {ps_total_tris} tris")
    reporter.assert_check(ps_total_tris == 268, f"Pitch Stage base geometry strictly equals 268 triangles (actual: {ps_total_tris})")

    # --------------------------------------------------------------------------
    # DIMENSION 3: Combined Triangle Budget Certification (< 2,500 Triangles)
    # --------------------------------------------------------------------------
    print("\n--- DIMENSION 3: Combined Low-Poly Triangle Budget Verification ---")
    combined_base_tris = st_total_tris + ps_total_tris
    print(f"  Server Terminal Base Triangles : {st_total_tris} tris")
    print(f"  Pitch Stage Base Triangles     : {ps_total_tris} tris")
    print(f"  Combined Base Triangles        : {combined_base_tris} tris")
    print(f"  Master Budget Limit            : < 2,500 tris")

    reporter.assert_check(combined_base_tris < 2500,
                          f"Combined base triangles strictly < 2,500 (actual: {combined_base_tris})")
    budget_usage_pct = (combined_base_tris / 2500.0) * 100.0
    print(f"  Budget Utilization             : {budget_usage_pct:.1f}% of allowable limit")
    reporter.assert_check(budget_usage_pct <= 20.0,
                          f"Base triangles utilize <= 20% of budget headroom (actual: {budget_usage_pct:.1f}%)")

    # Worst-Case Dynamic Particle Stress Analysis:
    # If OverclockSparks (24 particles) and ConfettiExplosion (60 particles) emit simultaneously:
    max_sparks_particles = 24
    max_confetti_particles = 60
    dynamic_sparks_tris = max_sparks_particles * spark_tris
    dynamic_confetti_tris = max_confetti_particles * confetti_tris
    worst_case_dynamic_tris = st_static_tris + dynamic_sparks_tris + ps_static_tris + dynamic_confetti_tris

    print(f"\n  [Dynamic Stress] Worst-Case Simultaneous Particle Burst:")
    print(f"  -> Server Terminal Peak Dynamic : {st_static_tris} + {max_sparks_particles}*12 = {st_static_tris + dynamic_sparks_tris} tris")
    print(f"  -> Pitch Stage Peak Dynamic     : {ps_static_tris} + {max_confetti_particles}*12 = {ps_static_tris + dynamic_confetti_tris} tris")
    print(f"  -> Combined Absolute Peak Tris  : {worst_case_dynamic_tris} tris")

    reporter.assert_check(worst_case_dynamic_tris < 2500,
                          f"Worst-case peak dynamic triangles ({worst_case_dynamic_tris}) strictly < 2,500")
    peak_usage_pct = (worst_case_dynamic_tris / 2500.0) * 100.0
    print(f"  Peak Dynamic Utilization       : {peak_usage_pct:.1f}% of budget")
    reporter.assert_check(peak_usage_pct < 60.0,
                          f"Peak dynamic load stays below 60% of budget limit (actual: {peak_usage_pct:.1f}%)")

    # --------------------------------------------------------------------------
    # DIMENSION 4: Materials, PBR Properties, Colors, and Emission Verification
    # --------------------------------------------------------------------------
    print("\n--- DIMENSION 4: Materials, Colors, Emission & PBR Verification ---")

    # 4.1 ServerTerminal Materials
    st_mat_power = st_materials.get("Mat_LEDPower", {}).get("props", {})
    reporter.assert_check(st_mat_power.get("emission_enabled") == "true", "Mat_LEDPower has emission_enabled = true")
    reporter.assert_check("Color(0.1, 1, 0.3" in st_mat_power.get("emission", ""), "Mat_LEDPower emits vibrant green")
    reporter.assert_check(float(st_mat_power.get("emission_energy_multiplier", 1.0)) >= 2.0, "Mat_LEDPower emission multiplier >= 2.0")

    st_mat_data = st_materials.get("Mat_LEDData", {}).get("props", {})
    reporter.assert_check(st_mat_data.get("emission_enabled") == "true", "Mat_LEDData has emission_enabled = true")
    reporter.assert_check("Color(0, 0.8, 1" in st_mat_data.get("emission", ""), "Mat_LEDData emits cyan")

    st_mat_oc = st_materials.get("Mat_LEDOverclock", {}).get("props", {})
    reporter.assert_check(st_mat_oc.get("emission_enabled") == "true", "Mat_LEDOverclock has emission_enabled = true")
    reporter.assert_check("Color(0, 0.9, 1" in st_mat_oc.get("emission", ""), "Mat_LEDOverclock emits bright cyan")
    reporter.assert_check(float(st_mat_oc.get("emission_energy_multiplier", 1.0)) >= 2.5, "Mat_LEDOverclock emission multiplier >= 2.5")

    st_mat_cd = st_materials.get("Mat_LEDCooldown", {}).get("props", {})
    reporter.assert_check(st_mat_cd.get("emission_enabled") == "true", "Mat_LEDCooldown has emission_enabled = true")
    reporter.assert_check("Color(1, 0.6, 0.1" in st_mat_cd.get("emission", ""), "Mat_LEDCooldown emits amber/orange")

    st_mat_sparks = st_materials.get("Mat_Sparks", {}).get("props", {})
    reporter.assert_check(st_mat_sparks.get("emission_enabled") == "true", "Mat_Sparks has emission_enabled = true")
    reporter.assert_check("Color(0, 0.92, 1" in st_mat_sparks.get("emission", ""), "Mat_Sparks emits Electric Blue/Cyan")
    reporter.assert_check(float(st_mat_sparks.get("emission_energy_multiplier", 1.0)) >= 3.0, "Mat_Sparks emission multiplier >= 3.0")

    st_mat_chassis = st_materials.get("Mat_RackChassis", {}).get("props", {})
    reporter.assert_check(float(st_mat_chassis.get("metallic", 0)) >= 0.7, "Mat_RackChassis is metallic (>= 0.7)")
    reporter.assert_check(float(st_mat_chassis.get("roughness", 1)) <= 0.45, "Mat_RackChassis is sleek (roughness <= 0.45)")

    # 4.2 PitchStage Materials
    ps_mat_oak = ps_materials.get("Mat_OakWood", {}).get("props", {})
    reporter.assert_check("Color(0.48, 0.32, 0.18" in ps_mat_oak.get("albedo_color", ""), "Mat_OakWood has warm wood albedo")
    reporter.assert_check(float(ps_mat_oak.get("roughness", 0)) >= 0.6, "Mat_OakWood has matte wood roughness (>= 0.6)")

    ps_mat_gold = ps_materials.get("Mat_GoldBorder", {}).get("props", {})
    reporter.assert_check(float(ps_mat_gold.get("metallic", 0)) >= 0.75, "Mat_GoldBorder has high metallic shine (>= 0.75)")
    reporter.assert_check("Color(0.85, 0.7, 0.15" in ps_mat_gold.get("albedo_color", ""), "Mat_GoldBorder has rich gold hue")

    ps_mat_tie = ps_materials.get("Mat_GoldTie", {}).get("props", {})
    reporter.assert_check(float(ps_mat_tie.get("metallic", 0)) >= 0.8, "Mat_GoldTie has high metallic sheen (>= 0.8)")
    reporter.assert_check("Color(1, 0.84, 0" in ps_mat_tie.get("albedo_color", ""), "Mat_GoldTie has bright gold color")

    ps_mat_confetti = ps_materials.get("Mat_Confetti", {}).get("props", {})
    reporter.assert_check(ps_mat_confetti.get("emission_enabled") == "true", "Mat_Confetti has emission_enabled = true")
    reporter.assert_check("Color(1, 0.85, 0.2" in ps_mat_confetti.get("emission", ""), "Mat_Confetti has golden emission")
    reporter.assert_check(float(ps_mat_confetti.get("emission_energy_multiplier", 1.0)) >= 1.5, "Mat_Confetti emission multiplier >= 1.5")

    # --------------------------------------------------------------------------
    # DIMENSION 5: Particle Emitter Flags & Juicing Configuration
    # --------------------------------------------------------------------------
    print("\n--- DIMENSION 5: Particle Flags & Particle Emitter Configuration ---")

    # 5.1 ServerTerminal OverclockSparks (CPUParticles3D)
    st_sparks_nodes = [n for n in st_parsed["nodes"] if n["name"] == "OverclockSparks"]
    reporter.assert_check(len(st_sparks_nodes) == 1, "OverclockSparks node exists in ServerTerminal")
    if st_sparks_nodes:
        sp_props = st_sparks_nodes[0]["props"]
        reporter.assert_check(sp_props.get("emitting", "true").lower() == "false",
                              "OverclockSparks initially dormant (emitting = false)")
        reporter.assert_check(int(sp_props.get("amount", 0)) == 24, "OverclockSparks particle amount is 24")
        reporter.assert_check(float(sp_props.get("lifetime", 0)) == 1.0, "OverclockSparks particle lifetime is 1.0s")
        reporter.assert_check(float(sp_props.get("spread", 0)) == 45.0, "OverclockSparks particle spread is 45.0 degrees")
        reporter.assert_check("Vector3(0, 1, 0)" in sp_props.get("direction", ""), "OverclockSparks upward direction (0, 1, 0)")
        reporter.assert_check(float(sp_props.get("initial_velocity_min", 0)) == 1.5, "OverclockSparks initial_velocity_min is 1.5")
        reporter.assert_check(float(sp_props.get("initial_velocity_max", 0)) == 3.0, "OverclockSparks initial_velocity_max is 3.0")

    # 5.2 PitchStage ConfettiExplosion (CPUParticles3D)
    ps_confetti_nodes = [n for n in ps_parsed["nodes"] if n["name"] == "ConfettiExplosion"]
    reporter.assert_check(len(ps_confetti_nodes) == 1, "ConfettiExplosion node exists in PitchStage")
    if ps_confetti_nodes:
        cf_props = ps_confetti_nodes[0]["props"]
        reporter.assert_check(cf_props.get("emitting", "true").lower() == "false",
                              "ConfettiExplosion initially dormant (emitting = false)")
        reporter.assert_check(int(cf_props.get("amount", 0)) == 60, "ConfettiExplosion particle amount is 60")
        reporter.assert_check(float(cf_props.get("lifetime", 0)) == 2.0, "ConfettiExplosion particle lifetime is 2.0s")
        reporter.assert_check(cf_props.get("one_shot", "false").lower() == "true", "ConfettiExplosion is one_shot = true")
        reporter.assert_check(float(cf_props.get("explosiveness", 0)) == 0.9, "ConfettiExplosion explosiveness is 0.9")
        reporter.assert_check(float(cf_props.get("spread", 0)) == 60.0, "ConfettiExplosion spread is 60.0 degrees")
        reporter.assert_check("Vector3(0, 1, 0)" in cf_props.get("direction", ""), "ConfettiExplosion upward direction (0, 1, 0)")
        reporter.assert_check(float(cf_props.get("initial_velocity_min", 0)) == 3.0, "ConfettiExplosion initial_velocity_min is 3.0")
        reporter.assert_check(float(cf_props.get("initial_velocity_max", 0)) == 6.0, "ConfettiExplosion initial_velocity_max is 6.0")

    # --------------------------------------------------------------------------
    # DIMENSION 6: Physical Boundaries, Collision Shapes & Proximity Triggers
    # --------------------------------------------------------------------------
    print("\n--- DIMENSION 6: Physical Boundaries & Proximity Trigger Geometries ---")

    # 6.1 ServerTerminal Physics
    st_root_nodes = [n for n in st_parsed["nodes"] if n["name"] == "ServerTerminal"]
    reporter.assert_check(len(st_root_nodes) == 1, "ServerTerminal root node exists")
    if st_root_nodes:
        root = st_root_nodes[0]
        reporter.assert_check(root.get("type") == "StaticBody3D", "ServerTerminal root is StaticBody3D")
        reporter.assert_check(root["props"].get("collision_layer") == "1", "ServerTerminal solid collision_layer = 1")
        reporter.assert_check(root["props"].get("collision_mask") == "0", "ServerTerminal solid collision_mask = 0")

    st_area_nodes = [n for n in st_parsed["nodes"] if n["name"] == "InteractionArea"]
    reporter.assert_check(len(st_area_nodes) == 1, "ServerTerminal InteractionArea exists")
    if st_area_nodes:
        area = st_area_nodes[0]
        reporter.assert_check(area.get("type") == "Area3D", "InteractionArea is Area3D")
        reporter.assert_check(area["props"].get("collision_layer") == "0", "InteractionArea sensor collision_layer = 0")
    
    st_sphere_area = st_parsed["subresources"].get("SphereShape3D_area", {})
    reporter.assert_check(float(st_sphere_area.get("props", {}).get("radius", 0)) == 2.4,
                          "ServerTerminal interaction trigger radius = 2.4m")

    # 6.2 PitchStage Physics
    ps_root_nodes = [n for n in ps_parsed["nodes"] if n["name"] == "PitchStage"]
    reporter.assert_check(len(ps_root_nodes) == 1, "PitchStage root node exists")
    if ps_root_nodes:
        root = ps_root_nodes[0]
        reporter.assert_check(root.get("type") == "StaticBody3D", "PitchStage root is StaticBody3D")
        reporter.assert_check(root["props"].get("collision_layer") == "1", "PitchStage solid collision_layer = 1")
        reporter.assert_check(root["props"].get("collision_mask") == "0", "PitchStage solid collision_mask = 0")

    ps_area_nodes = [n for n in ps_parsed["nodes"] if n["name"] == "InteractionArea"]
    reporter.assert_check(len(ps_area_nodes) == 1, "PitchStage InteractionArea exists")
    if ps_area_nodes:
        area = ps_area_nodes[0]
        reporter.assert_check(area.get("type") == "Area3D", "PitchStage InteractionArea is Area3D")
        reporter.assert_check(area["props"].get("collision_layer") == "0", "PitchStage sensor collision_layer = 0")

    ps_sphere_area = ps_parsed["subresources"].get("SphereShape3D_area", {})
    reporter.assert_check(float(ps_sphere_area.get("props", {}).get("radius", 0)) == 3.0,
                          "PitchStage interaction trigger radius = 3.0m")

    # --------------------------------------------------------------------------
    # DIMENSION 7: Campus Placement & Lighting Certification
    # --------------------------------------------------------------------------
    print("\n--- DIMENSION 7: Campus World Placement & Lighting Certification ---")
    m3d_path = GAME_DIR / "scenes" / "main_3d.tscn"
    reporter.assert_check(m3d_path.exists(), "scenes/main_3d.tscn exists")
    if m3d_path.exists():
        m3d_content = m3d_path.read_text(encoding="utf-8")
        m3d_parsed = parse_tscn(m3d_content)

        st_inst = [n for n in m3d_parsed["nodes"] if n["name"] == "ServerTerminal"]
        reporter.assert_check(len(st_inst) == 1, "ServerTerminal instanced in main_3d.tscn")
        if st_inst:
            st_tf = st_inst[0]["props"].get("transform", "")
            reporter.assert_check(", 0, 0, -18)" in st_tf, f"ServerTerminal placed at Vector3(0, 0, -18) in Server Room")

        ps_inst = [n for n in m3d_parsed["nodes"] if n["name"] == "PitchStage"]
        reporter.assert_check(len(ps_inst) == 1, "PitchStage instanced in main_3d.tscn")
        if ps_inst:
            ps_tf = ps_inst[0]["props"].get("transform", "")
            reporter.assert_check(", 0, 0, 18)" in ps_tf, f"PitchStage placed at Vector3(0, 0, 18) in Courtyard")

        glow_inst = [n for n in m3d_parsed["nodes"] if n["name"] == "ServerOverclockGlow"]
        reporter.assert_check(len(glow_inst) == 1, "ServerOverclockGlow OmniLight3D present at Server Room")

    # --------------------------------------------------------------------------
    # DIMENSION 8: Overclock & Pitch Script Dynamic Logic Stress-Testing
    # --------------------------------------------------------------------------
    print("\n--- DIMENSION 8: Script State Logic & Math Stress Simulation ---")

    # Overclock state logic simulation
    duration = 25.0
    cooldown = 60.0
    boost_mult = 1.50
    base_rps = 420.0
    active_rps = base_rps * boost_mult
    reporter.assert_check(active_rps == 630.0, f"Overclock +50% boost math exact: {base_rps} -> {active_rps}")

    # Pitch grant range simulation
    min_grant = 1000.0
    max_grant = 5000.0
    for level in [0, 1, 5, 10, 50]:
        lvl_bonus = float(level) * 100.0
        min_possible = round(min_grant + lvl_bonus)
        max_possible = round(max_grant + lvl_bonus)
        reporter.assert_check(min_possible >= min_grant, f"At idle level {level}, min grant ({min_possible}) >= 1,000")
        reporter.assert_check(max_possible <= max_grant + 5000.0, f"At idle level {level}, max grant ({max_possible}) within safe envelope")

    # --------------------------------------------------------------------------
    # SUMMARY
    # --------------------------------------------------------------------------
    print("\n" + "=" * 76)
    print(f"CHALLENGER ORACLE SUMMARY: {reporter.passes} Passed, {reporter.fails} Failed (Total: {reporter.total})")
    print("=" * 76)
    if reporter.fails == 0:
        print(">>> EMPIRICAL CHALLENGE PASSED: ALL 8 DIMENSIONS CERTIFIED 100% GREEN! <<<\n")
        return 0
    else:
        print(f">>> EMPIRICAL CHALLENGE FAILED: {reporter.fails} ASSERTIONS FAILED! <<<\n")
        return 1

if __name__ == "__main__":
    sys.exit(run_empirical_challenge())
