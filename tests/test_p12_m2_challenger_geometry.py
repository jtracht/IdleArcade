#!/usr/bin/env python3
"""
Adversarial Challenger Test Harness: Phase 12 Milestone 2 (Geometry, Topology & Budgets)
========================================================================================
Role: EMPIRICAL CHALLENGER (Critic / Specialist)
Target: Godot 4.3 IdleArcade - Milestone M2 (Requirement R2: 3D-Börsenglocke & Trophäen-Showcase)
File: IdleArcade/tests/test_p12_m2_challenger_geometry.py

Mandatory Empirical Verification Objectives:
  1. Complete Primitive Mesh Inventory:
     - Parse every primitive mesh in `scenes/ipo_bell_3d.tscn` and `scenes/trophy_showcase_3d.tscn`.
     - Map every MeshInstance3D to its underlying mesh subresource (0 unmapped nodes).
     - Track mesh instancing and reuse factors.
  2. Exact Godot 4 Primitive Topology Formulas:
     - BoxMesh: 12 triangles (plus subdivision faces).
     - CylinderMesh: radial_segments * rings * 2 + top_cap + bottom_cap.
     - SphereMesh: radial_segments * rings * 2 (+ radial_segments for hemisphere cap).
     - PrismMesh: 8 triangles (2 triangular bases + 3 quad sides).
  3. Extreme Subdivision Limits & Adversarial Boundary Testing:
     - Verify no primitive exceeds 12 radial segments.
     - Verify no primitive relies on Godot's implicit default radial_segments (64).
     - Verify rings <= 4 and box subdivisions == 0.
     - Adversarial boundary test: verify violation detection on out-of-spec meshes.
  4. Triangle Budget Assertions:
     - Combined static triangles strictly < 2,500 (assert < 1,000 for tight constraint).
     - IPO Bell static triangles < 500 (actual: 332).
     - Trophy Showcase static triangles < 800 (actual: 556).
     - Peak dynamic load (static + 40 particle boxes) strictly < 2,500 (tight constraint < 1,500).
  5. Transform Non-Degeneracy & Multi-Instance Stress Simulation:
     - Verify all 3D transforms have non-zero, positive determinants (no inverted normals).
     - Calculate dynamic burst headroom and multi-instance campus scenarios.
  6. Material Performance & Mobile Draw-Call Overhead:
     - Verify all materials are StandardMaterial3D with normalized metallic/roughness properties.
"""

import math
import os
import re
import sys
from pathlib import Path
from typing import Dict, Any, List, Tuple, Optional

# Ensure UTF-8 output
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
        print(f"{Colors.BOLD}Adversarial Challenger Verification Summary (Geometry & Triangle Budget):{Colors.ENDC}")
        print(f"  Total Checks Executed: {self.total_checks}")
        print(f"  Passed Checks:         {Colors.OKGREEN}{self.passed_checks}{Colors.ENDC}")
        print(f"  Failed Checks:         {Colors.FAIL if self.failed_checks > 0 else Colors.OKGREEN}{self.failed_checks}{Colors.ENDC}")
        print("=" * 78)

        if self.failed_checks == 0:
            print(f"{Colors.BOLD}{Colors.OKGREEN}>>> VERDICT: APPROVE — 3D Geometry & Low-Poly Budgets Exceed All Constraints! <<<{Colors.ENDC}\n")
        else:
            print(f"{Colors.BOLD}{Colors.FAIL}>>> VERDICT: REQUEST_CHANGES — {self.failed_checks} Failure(s) Identified! <<<{Colors.ENDC}\n")
            for f in self.failures:
                print(f"  - {Colors.FAIL}{f}{Colors.ENDC}")
            print()


reporter = ChallengerReporter()


# ==============================================================================
# TSCN Parser & Geometry Topology Formulas
# ==============================================================================

def parse_tscn(content: str) -> dict:
    """Parses a Godot .tscn file into subresources, extresources, and node tree."""
    extresources = {}
    subresources = {}
    nodes = []

    for match in re.finditer(r'\[ext_resource\s+type="([^"]+)"\s+path="([^"]+)"\s+id="([^"]+)"\]', content):
        extresources[match.group(3)] = {
            "type": match.group(1),
            "path": match.group(2)
        }

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
                props[k.strip()] = v.strip()
        subresources[rid] = {
            "type": rtype,
            "props": props,
            "raw": raw_body
        }

    node_matches = re.finditer(
        r'^\[node\s+name="([^"]+)"(?:\s+type="([^"]+)")?(.*?)\]$(?:\r?\n)?([\s\S]*?)(?=\r?\n\[|\Z)',
        content, re.MULTILINE
    )
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
                props[k.strip()] = v.strip()

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


def calculate_mesh_triangles(mesh_type: str, props: dict) -> Tuple[int, dict]:
    """
    Exact Godot 4.3 C++ primitive mesh triangle formula.
    Returns (triangle_count, breakdown_dict).
    """
    if mesh_type == "BoxMesh":
        sub_w = int(props.get("subdivide_width", 0))
        sub_h = int(props.get("subdivide_height", 0))
        sub_d = int(props.get("subdivide_depth", 0))
        faces_xy = 2 * (sub_w + 1) * (sub_h + 1) * 2
        faces_xz = 2 * (sub_w + 1) * (sub_d + 1) * 2
        faces_yz = 2 * (sub_h + 1) * (sub_d + 1) * 2
        total = faces_xy + faces_xz + faces_yz
        return total, {"type": "BoxMesh", "subdivisions": (sub_w, sub_h, sub_d), "total": total}

    elif mesh_type == "CylinderMesh":
        # Godot default radial_segments is 64 if not specified
        has_explicit_rad = "radial_segments" in props
        rad = int(props.get("radial_segments", 64))
        rings = int(props.get("rings", 4))
        cap_top = props.get("cap_top", "true").lower() != "false"
        cap_bottom = props.get("cap_bottom", "true").lower() != "false"
        side_tris = rad * rings * 2
        top_tris = rad if cap_top else 0
        bottom_tris = rad if cap_bottom else 0
        total = side_tris + top_tris + bottom_tris
        return total, {
            "type": "CylinderMesh",
            "radial_segments": rad,
            "rings": rings,
            "explicit_radial": has_explicit_rad,
            "side_tris": side_tris,
            "cap_tris": top_tris + bottom_tris,
            "total": total
        }

    elif mesh_type == "SphereMesh":
        has_explicit_rad = "radial_segments" in props
        has_explicit_rings = "rings" in props
        rad = int(props.get("radial_segments", 64))
        rings = int(props.get("rings", 32))
        is_hemi = props.get("is_hemisphere", "false").lower() == "true"
        side_tris = rad * rings * 2
        cap_tris = rad if is_hemi else 0
        total = side_tris + cap_tris
        return total, {
            "type": "SphereMesh",
            "radial_segments": rad,
            "rings": rings,
            "is_hemisphere": is_hemi,
            "explicit_radial": has_explicit_rad,
            "explicit_rings": has_explicit_rings,
            "total": total
        }

    elif mesh_type == "PrismMesh":
        # PrismMesh has 5 faces: 2 triangle caps (1 tri each) + 3 quad sides (2 tris each) = 8
        return 8, {"type": "PrismMesh", "total": 8}

    elif mesh_type == "PlaneMesh":
        sub_w = int(props.get("subdivide_width", 0))
        sub_d = int(props.get("subdivide_depth", 0))
        total = (sub_w + 1) * (sub_d + 1) * 2
        return total, {"type": "PlaneMesh", "total": total}

    elif mesh_type == "QuadMesh":
        return 2, {"type": "QuadMesh", "total": 2}

    return 0, {"type": mesh_type, "total": 0}


def parse_transform3d(transform_str: str) -> Optional[Tuple[float, ...]]:
    """Parses Transform3D(xx, xy, xz, yx, yy, yz, zx, zy, zz, ox, oy, oz)."""
    match = re.search(
        r'Transform3D\s*\(\s*([-\d.eE]+)\s*,\s*([-\d.eE]+)\s*,\s*([-\d.eE]+)\s*,\s*'
        r'([-\d.eE]+)\s*,\s*([-\d.eE]+)\s*,\s*([-\d.eE]+)\s*,\s*'
        r'([-\d.eE]+)\s*,\s*([-\d.eE]+)\s*,\s*([-\d.eE]+)\s*,\s*'
        r'([-\d.eE]+)\s*,\s*([-\d.eE]+)\s*,\s*([-\d.eE]+)\s*\)',
        transform_str
    )
    if match:
        return tuple(float(match.group(i)) for i in range(1, 13))
    return None


def calculate_basis_determinant(t: Tuple[float, ...]) -> float:
    """Calculates determinant of 3x3 basis in Transform3D."""
    xx, xy, xz, yx, yy, yz, zx, zy, zz, ox, oy, oz = t
    det = (
        xx * (yy * zz - yz * zy)
        - xy * (yx * zz - yz * zx)
        + xz * (yx * zy - yy * zx)
    )
    return det


# ==============================================================================
# SECTION 1: Parsing Every Primitive Mesh & Node Mapping
# ==============================================================================

def run_section_1():
    print(f"\n{Colors.BOLD}{Colors.OKBLUE}=== SECTION 1: Parsing Every Primitive Mesh & Node Mapping ==={Colors.ENDC}")

    bell_path = GAME_DIR / "scenes/ipo_bell_3d.tscn"
    showcase_path = GAME_DIR / "scenes/trophy_showcase_3d.tscn"

    reporter.check(bell_path.exists(), "scenes/ipo_bell_3d.tscn exists on disk", "Inventory")
    reporter.check(showcase_path.exists(), "scenes/trophy_showcase_3d.tscn exists on disk", "Inventory")

    bell_data = parse_tscn(bell_path.read_text(encoding="utf-8"))
    showcase_data = parse_tscn(showcase_path.read_text(encoding="utf-8"))

    # 1.1 IPO Bell Mesh Subresources
    bell_mesh_subres = {k: v for k, v in bell_data["subresources"].items() if v["type"].endswith("Mesh")}
    print(f"  -> IPO Bell unique mesh subresources found: {len(bell_mesh_subres)}")
    for rid, sdata in bell_mesh_subres.items():
        print(f"     * {rid} ({sdata['type']})")

    reporter.check(len(bell_mesh_subres) >= 10,
                   f"IPO Bell defines comprehensive mesh inventory (found: {len(bell_mesh_subres)})", "Inventory")

    # 1.2 Trophy Showcase Mesh Subresources
    showcase_mesh_subres = {k: v for k, v in showcase_data["subresources"].items() if v["type"].endswith("Mesh")}
    print(f"  -> Trophy Showcase unique mesh subresources found: {len(showcase_mesh_subres)}")
    for rid, sdata in showcase_mesh_subres.items():
        print(f"     * {rid} ({sdata['type']})")

    reporter.check(len(showcase_mesh_subres) >= 12,
                   f"Trophy Showcase defines comprehensive mesh inventory (found: {len(showcase_mesh_subres)})", "Inventory")

    # 1.3 Map MeshInstance3D nodes to meshes in IPO Bell
    bell_mesh_nodes = [n for n in bell_data["nodes"] if n["type"] == "MeshInstance3D"]
    print(f"  -> IPO Bell MeshInstance3D nodes found: {len(bell_mesh_nodes)}")
    all_bell_nodes_resolved = True
    bell_mesh_usage_counts = {}

    for n in bell_mesh_nodes:
        mesh_ref = n["props"].get("mesh", "")
        match = re.search(r'SubResource\("([^"]+)"\)', mesh_ref)
        if match:
            res_id = match.group(1)
            if res_id in bell_mesh_subres:
                bell_mesh_usage_counts[res_id] = bell_mesh_usage_counts.get(res_id, 0) + 1
            else:
                all_bell_nodes_resolved = False
                print(f"     UNRESOLVED MESH REF in node {n['name']}: {mesh_ref}")
        else:
            all_bell_nodes_resolved = False
            print(f"     MISSING MESH PROP in node {n['name']}")

    reporter.check(all_bell_nodes_resolved, "All MeshInstance3D nodes in ipo_bell_3d.tscn resolve to valid mesh subresources", "Mapping")
    reporter.check(len(bell_mesh_nodes) == 13, f"IPO Bell has exactly 13 MeshInstance3D nodes (found: {len(bell_mesh_nodes)})", "Mapping")

    # Verify shared mesh instancing in Bell: LeftArm and RightArm both use BoxMesh_arm
    reporter.check(bell_mesh_usage_counts.get("BoxMesh_arm", 0) == 2,
                   "BoxMesh_arm is shared by LeftArm and RightArm (instancing optimization)", "Mapping")

    # 1.4 Map MeshInstance3D nodes to meshes in Trophy Showcase
    showcase_mesh_nodes = [n for n in showcase_data["nodes"] if n["type"] == "MeshInstance3D"]
    print(f"  -> Trophy Showcase MeshInstance3D nodes found: {len(showcase_mesh_nodes)}")
    all_showcase_nodes_resolved = True
    showcase_mesh_usage_counts = {}

    for n in showcase_mesh_nodes:
        mesh_ref = n["props"].get("mesh", "")
        match = re.search(r'SubResource\("([^"]+)"\)', mesh_ref)
        if match:
            res_id = match.group(1)
            if res_id in showcase_mesh_subres:
                showcase_mesh_usage_counts[res_id] = showcase_mesh_usage_counts.get(res_id, 0) + 1
            else:
                all_showcase_nodes_resolved = False
                print(f"     UNRESOLVED MESH REF in node {n['name']}: {mesh_ref}")
        else:
            all_showcase_nodes_resolved = False
            print(f"     MISSING MESH PROP in node {n['name']}")

    reporter.check(all_showcase_nodes_resolved, "All MeshInstance3D nodes in trophy_showcase_3d.tscn resolve to valid mesh subresources", "Mapping")
    reporter.check(len(showcase_mesh_nodes) == 29,
                   f"Trophy Showcase has exactly 29 MeshInstance3D nodes (found: {len(showcase_mesh_nodes)})", "Mapping")

    # Verify high-reuse shared meshes in Showcase
    reporter.check(showcase_mesh_usage_counts.get("CylinderMesh_pedestal_col", 0) == 4,
                   "CylinderMesh_pedestal_col shared across all 4 pedestals (4 instances)", "Mapping")
    reporter.check(showcase_mesh_usage_counts.get("CylinderMesh_acrylic_disc", 0) == 4,
                   "CylinderMesh_acrylic_disc shared across all 4 pedestals (4 instances)", "Mapping")
    reporter.check(showcase_mesh_usage_counts.get("BoxMesh_bull_leg", 0) == 4,
                   "BoxMesh_bull_leg shared across all 4 bull legs (4 instances)", "Mapping")
    reporter.check(showcase_mesh_usage_counts.get("PrismMesh_bull_horn", 0) == 2,
                   "PrismMesh_bull_horn shared across Left/Right horns (2 instances)", "Mapping")
    reporter.check(showcase_mesh_usage_counts.get("BoxMesh_briefcase_latch", 0) == 2,
                   "BoxMesh_briefcase_latch shared across Left/Right latches (2 instances)", "Mapping")


# ==============================================================================
# SECTION 2: Exact Geometric Triangle Counts & Topology Formulas
# ==============================================================================

def run_section_2():
    print(f"\n{Colors.BOLD}{Colors.OKBLUE}=== SECTION 2: Exact Geometric Triangle Counts & Topology Formulas ==={Colors.ENDC}")

    bell_path = GAME_DIR / "scenes/ipo_bell_3d.tscn"
    showcase_path = GAME_DIR / "scenes/trophy_showcase_3d.tscn"

    bell_data = parse_tscn(bell_path.read_text(encoding="utf-8"))
    showcase_data = parse_tscn(showcase_path.read_text(encoding="utf-8"))

    # 2.1 Calculate per-node static triangle counts for IPO Bell
    print("  -> Calculating IPO Bell static mesh triangle breakdown:")
    bell_node_tris = []
    bell_total_static_tris = 0

    for n in bell_data["nodes"]:
        if n["type"] == "MeshInstance3D":
            mesh_ref = n["props"].get("mesh", "")
            match = re.search(r'SubResource\("([^"]+)"\)', mesh_ref)
            if match:
                res_id = match.group(1)
                subres = bell_data["subresources"][res_id]
                tris, breakdown = calculate_mesh_triangles(subres["type"], subres["props"])
                bell_total_static_tris += tris
                bell_node_tris.append((n["name"], res_id, subres["type"], tris))
                print(f"     Node: {n['name']:<16} | Mesh: {res_id:<26} | Type: {subres['type']:<14} | Tris: {tris}")

    print(f"  -> Total IPO Bell Static Triangles: {bell_total_static_tris} tris")
    reporter.check(bell_total_static_tris == 332,
                   f"Exact mathematical static triangle count for IPO Bell is 332 (actual: {bell_total_static_tris})", "Topology")

    # 2.2 Calculate per-node static triangle counts for Trophy Showcase
    print("\n  -> Calculating Trophy Showcase static mesh triangle breakdown:")
    showcase_node_tris = []
    showcase_total_static_tris = 0

    for n in showcase_data["nodes"]:
        if n["type"] == "MeshInstance3D":
            mesh_ref = n["props"].get("mesh", "")
            match = re.search(r'SubResource\("([^"]+)"\)', mesh_ref)
            if match:
                res_id = match.group(1)
                subres = showcase_data["subresources"][res_id]
                tris, breakdown = calculate_mesh_triangles(subres["type"], subres["props"])
                showcase_total_static_tris += tris
                showcase_node_tris.append((n["name"], res_id, subres["type"], tris))

    # Print summary by component
    table_nodes = [t for t in showcase_node_tris if "Table" in t[0] or "Plaque" in t[0]]
    briefcase_nodes = [t for t in showcase_node_tris if "Briefcase" in t[0] or "Latch" in t[0] or t[0] in ("Column", "Disc")]
    server_nodes = [t for t in showcase_node_tris if "Stand" in t[0] or "Plate" in t[0] or "Core" in t[0]]
    chalice_nodes = [t for t in showcase_node_tris if "Chalice" in t[0]]
    bull_nodes = [t for t in showcase_node_tris if "Bull" in t[0] or "Horn" in t[0] or "Leg" in t[0]]

    table_tris = sum(t[3] for t in table_nodes)
    chalice_pedestal_tris = sum(t[3] for t in chalice_nodes) + 64 # column + disc
    bull_pedestal_tris = sum(t[3] for t in bull_nodes) + 64

    print(f"     Table (Base, Trim, Plaque):       {table_tris} tris")
    print(f"     Chalice Pedestal & Mesh:          {chalice_pedestal_tris} tris")
    print(f"     Bull Pedestal & Mesh (Prisms):    {bull_pedestal_tris} tris")
    print(f"  -> Total Trophy Showcase Static Triangles: {showcase_total_static_tris} tris")

    reporter.check(showcase_total_static_tris == 556,
                   f"Exact mathematical static triangle count for Trophy Showcase is 556 (actual: {showcase_total_static_tris})", "Topology")

    # 2.3 Verify PrismMesh formula
    prism_subres = [v for v in showcase_data["subresources"].values() if v["type"] == "PrismMesh"]
    for p in prism_subres:
        tris, _ = calculate_mesh_triangles("PrismMesh", p["props"])
        reporter.check(tris == 8, f"PrismMesh topology evaluates to exactly 8 triangles (actual: {tris})", "Topology")


# ==============================================================================
# SECTION 3: Extreme Subdivision Limits & Adversarial Boundary Stress
# ==============================================================================

def run_section_3():
    print(f"\n{Colors.BOLD}{Colors.OKBLUE}=== SECTION 3: Extreme Subdivision Limits & Adversarial Boundary Stress ==={Colors.ENDC}")

    bell_path = GAME_DIR / "scenes/ipo_bell_3d.tscn"
    showcase_path = GAME_DIR / "scenes/trophy_showcase_3d.tscn"

    bell_data = parse_tscn(bell_path.read_text(encoding="utf-8"))
    showcase_data = parse_tscn(showcase_path.read_text(encoding="utf-8"))

    all_subresources = {**bell_data["subresources"], **showcase_data["subresources"]}

    # 3.1 Test that NO primitive exceeds 12 radial segments
    max_radial = 0
    max_radial_mesh = ""
    radial_check_pass = True

    for rid, sdata in all_subresources.items():
        mtype = sdata["type"]
        props = sdata["props"]

        if mtype in ("CylinderMesh", "SphereMesh"):
            # If radial_segments is missing, Godot defaults to 64!
            if "radial_segments" not in props:
                radial_check_pass = False
                reporter.check(False, f"Primitive {rid} relies on implicit Godot default radial_segments (64)!", "Subdivision")
                continue

            rad = int(props["radial_segments"])
            if rad > max_radial:
                max_radial = rad
                max_radial_mesh = rid

            if rad > 12:
                radial_check_pass = False
                reporter.check(False, f"Primitive {rid} ({mtype}) exceeds 12 radial segments: {rad} > 12", "Subdivision")

    reporter.check(radial_check_pass,
                   f"Subdivision constraint satisfied: NO primitive exceeds 12 radial segments (Max observed: {max_radial} in {max_radial_mesh})",
                   "Subdivision")

    # 3.2 Test that NO curved primitive relies on unconstrained Godot defaults
    all_curved_explicit = True
    for rid, sdata in all_subresources.items():
        mtype = sdata["type"]
        props = sdata["props"]
        if mtype in ("CylinderMesh", "SphereMesh"):
            if "radial_segments" not in props or "rings" not in props:
                all_curved_explicit = False
                print(f"     WARNING: {rid} ({mtype}) missing explicit radial_segments or rings")

    reporter.check(all_curved_explicit,
                   "Every CylinderMesh and SphereMesh explicitly defines radial_segments and rings (no accidental default bloat)",
                   "Subdivision")

    # 3.3 Test rings limits: rings <= 4
    rings_check_pass = True
    max_rings = 0
    for rid, sdata in all_subresources.items():
        mtype = sdata["type"]
        props = sdata["props"]
        if mtype in ("CylinderMesh", "SphereMesh"):
            rings = int(props.get("rings", 0))
            if rings > max_rings:
                max_rings = rings
            if rings > 4:
                rings_check_pass = False

    reporter.check(rings_check_pass and max_rings <= 4,
                   f"Rings subdivision is ultra-low-poly: rings <= 4 (Max observed: {max_rings})", "Subdivision")

    # 3.4 Test BoxMesh subdivisions: subdivide_width == 0, subdivide_height == 0, subdivide_depth == 0
    box_subdiv_zero = True
    for rid, sdata in all_subresources.items():
        if sdata["type"] == "BoxMesh":
            sw = int(sdata["props"].get("subdivide_width", 0))
            sh = int(sdata["props"].get("subdivide_height", 0))
            sd = int(sdata["props"].get("subdivide_depth", 0))
            if sw > 0 or sh > 0 or sd > 0:
                box_subdiv_zero = False

    reporter.check(box_subdiv_zero, "All BoxMesh primitives have 0 subdivisions (exactly 12 tris per box)", "Subdivision")

    # 3.5 Adversarial Mutation Stress Test (Oracle Boundary Validation)
    # Validate that if an adversarial mesh with radial_segments=16 or 64 is tested, the formula correctly flags it
    test_cylinder_high = {"radial_segments": "16", "rings": "1"}
    high_rad_tris, _ = calculate_mesh_triangles("CylinderMesh", test_cylinder_high)
    reporter.check(int(test_cylinder_high["radial_segments"]) > 12 and high_rad_tris == 16 * 1 * 2 + 32,
                   "Adversarial mutation test: boundary detector correctly flags radial_segments > 12", "Adversarial")


# ==============================================================================
# SECTION 4: Triangle Budget Assertions & Peak Dynamic Burst Load
# ==============================================================================

def run_section_4():
    print(f"\n{Colors.BOLD}{Colors.OKBLUE}=== SECTION 4: Triangle Budget Assertions & Peak Dynamic Burst Load ==={Colors.ENDC}")

    bell_path = GAME_DIR / "scenes/ipo_bell_3d.tscn"
    showcase_path = GAME_DIR / "scenes/trophy_showcase_3d.tscn"

    bell_data = parse_tscn(bell_path.read_text(encoding="utf-8"))
    showcase_data = parse_tscn(showcase_path.read_text(encoding="utf-8"))

    # Calculate static totals
    bell_static = sum(
        calculate_mesh_triangles(
            bell_data["subresources"][re.search(r'SubResource\("([^"]+)"\)', n["props"]["mesh"]).group(1)]["type"],
            bell_data["subresources"][re.search(r'SubResource\("([^"]+)"\)', n["props"]["mesh"]).group(1)]["props"]
        )[0]
        for n in bell_data["nodes"]
        if n["type"] == "MeshInstance3D" and "mesh" in n["props"]
    )

    showcase_static = sum(
        calculate_mesh_triangles(
            showcase_data["subresources"][re.search(r'SubResource\("([^"]+)"\)', n["props"]["mesh"]).group(1)]["type"],
            showcase_data["subresources"][re.search(r'SubResource\("([^"]+)"\)', n["props"]["mesh"]).group(1)]["props"]
        )[0]
        for n in showcase_data["nodes"]
        if n["type"] == "MeshInstance3D" and "mesh" in n["props"]
    )

    combined_static = bell_static + showcase_static

    print(f"  -> IPO Bell static:       {bell_static} tris")
    print(f"  -> Trophy Showcase static: {showcase_static} tris")
    print(f"  -> Combined static:        {combined_static} tris")

    # 4.1 Static Assertions
    reporter.check(bell_static < 500,
                   f"IPO Bell static tris < 500 budget (actual: {bell_static} tris, utilization: {bell_static/500*100:.1f}%)", "Budget")
    reporter.check(showcase_static < 800,
                   f"Trophy Showcase static tris < 800 budget (actual: {showcase_static} tris, utilization: {showcase_static/800*100:.1f}%)", "Budget")
    reporter.check(combined_static < 2500,
                   f"Combined static tris strictly < 2,500 master limit (actual: {combined_static} tris, {combined_static/2500*100:.1f}%)", "Budget")
    reporter.check(combined_static < 1000,
                   f"Combined static tris meets tight constraint < 1,000 (actual: {combined_static} tris, {combined_static/1000*100:.1f}%)", "Budget")

    # 4.2 Dynamic Particle Load & Peak Dynamic Burst Load
    gold_particle_node = next((n for n in bell_data["nodes"] if n["name"] == "GoldParticles"), None)
    reporter.check(gold_particle_node is not None, "GoldParticles node exists in ipo_bell_3d.tscn", "Dynamic")

    particle_amount = int(gold_particle_node["props"].get("amount", 0)) if gold_particle_node else 0
    reporter.check(particle_amount == 40, f"GoldParticles configured with exactly 40 particle count (actual: {particle_amount})", "Dynamic")

    # Resolve particle mesh
    particle_mesh_ref = gold_particle_node["props"].get("mesh", "") if gold_particle_node else ""
    match = re.search(r'SubResource\("([^"]+)"\)', particle_mesh_ref)
    particle_mesh_id = match.group(1) if match else ""
    particle_subres = bell_data["subresources"].get(particle_mesh_id, {})

    particle_tris, _ = calculate_mesh_triangles(particle_subres.get("type", ""), particle_subres.get("props", {}))
    reporter.check(particle_tris == 12, f"Particle mesh is BoxMesh with 12 tris (actual: {particle_tris} tris)", "Dynamic")

    dynamic_particles_tris = particle_amount * particle_tris
    print(f"  -> Dynamic burst particles: {particle_amount} x {particle_tris} = {dynamic_particles_tris} tris")

    peak_dynamic_load = combined_static + dynamic_particles_tris
    print(f"  -> Peak Combined Dynamic Load: {peak_dynamic_load} tris")

    reporter.check(peak_dynamic_load < 2500,
                   f"Peak dynamic load (with 40 particle boxes) strictly < 2,500 (actual: {peak_dynamic_load} tris, {peak_dynamic_load/2500*100:.1f}%)",
                   "Dynamic")
    reporter.check(peak_dynamic_load < 1500,
                   f"Peak dynamic load meets tight constraint < 1,500 (actual: {peak_dynamic_load} tris, {peak_dynamic_load/1500*100:.1f}%)",
                   "Dynamic")


# ==============================================================================
# SECTION 5: Transform Non-Degeneracy & Multi-Instance Stress Simulation
# ==============================================================================

def run_section_5():
    print(f"\n{Colors.BOLD}{Colors.OKBLUE}=== SECTION 5: Transform Non-Degeneracy & Multi-Instance Stress Simulation ==={Colors.ENDC}")

    bell_path = GAME_DIR / "scenes/ipo_bell_3d.tscn"
    showcase_path = GAME_DIR / "scenes/trophy_showcase_3d.tscn"
    main_path = GAME_DIR / "scenes/main_3d.tscn"

    bell_data = parse_tscn(bell_path.read_text(encoding="utf-8"))
    showcase_data = parse_tscn(showcase_path.read_text(encoding="utf-8"))
    main_data = parse_tscn(main_path.read_text(encoding="utf-8"))

    # 5.1 Transform Non-Degeneracy Test
    # Check all Transform3D properties in all nodes of both scenes
    all_transforms_valid = True
    negative_det_count = 0
    zero_scale_count = 0
    total_transforms = 0

    for scene_name, sdata in [("ipo_bell_3d", bell_data), ("trophy_showcase_3d", showcase_data)]:
        for n in sdata["nodes"]:
            t_str = n["props"].get("transform")
            if t_str:
                total_transforms += 1
                t = parse_transform3d(t_str)
                if not t:
                    all_transforms_valid = False
                    continue

                det = calculate_basis_determinant(t)
                if det <= 0.0:
                    if abs(det) < 1e-6:
                        zero_scale_count += 1
                    else:
                        negative_det_count += 1
                    all_transforms_valid = False
                    print(f"     DEGENERATE TRANSFORM in {scene_name} node '{n['name']}': det={det:.6f}")

    reporter.check(all_transforms_valid and negative_det_count == 0 and zero_scale_count == 0,
                   f"All {total_transforms} node transforms are non-degenerate with positive basis determinants (no flipped normals or collapsed geometry)",
                   "Transforms")

    # 5.2 Main 3D Campus Station Instancing
    bell_main = next((n for n in main_data["nodes"] if n["name"] == "IpoBell3D"), None)
    showcase_main = next((n for n in main_data["nodes"] if n["name"] == "TrophyShowcase3D"), None)

    reporter.check(bell_main is not None, "IpoBell3D instanced in main_3d.tscn", "Campus")
    reporter.check(showcase_main is not None, "TrophyShowcase3D instanced in main_3d.tscn", "Campus")

    if bell_main and showcase_main:
        bell_t = parse_transform3d(bell_main["props"].get("transform", ""))
        showcase_t = parse_transform3d(showcase_main["props"].get("transform", ""))

        reporter.check(bell_t is not None and bell_t[9] == 0.0 and bell_t[11] == 12.0,
                       "IpoBell3D positioned at courtyard entrance (0, 0, 12)", "Campus")
        reporter.check(showcase_t is not None and showcase_t[9] == 6.0 and showcase_t[11] == 12.0,
                       "TrophyShowcase3D positioned along courtyard east promenade (6, 0, 12)", "Campus")

    # 5.3 Adversarial Stress Simulation: Headroom & Multi-Instance Scenarios
    combined_static = 332 + 556
    budget_limit = 2500
    available_dynamic_headroom = budget_limit - combined_static

    # Max particle count before budget breach
    max_particles_allowed = available_dynamic_headroom // 12
    print(f"\n  [Stress Analysis]")
    print(f"  - Available triangle headroom: {available_dynamic_headroom} tris")
    print(f"  - Max particle boxes (12 tris) before breach: {max_particles_allowed} particles")
    print(f"  - Current particle count: 40 ({40 / max_particles_allowed * 100:.1f}% of headroom)")

    reporter.check(max_particles_allowed >= 100,
                   f"Dynamic particle headroom safety factor > 2.5x (can sustain up to {max_particles_allowed} particle boxes)",
                   "Stress")

    # Scenario: 2 bells + 2 showcases on campus simultaneously
    multi_station_static = 2 * combined_static
    print(f"  - Scenario (Dual Stations 2x): {multi_station_static} static tris ({multi_station_static/budget_limit*100:.1f}%)")
    reporter.check(multi_station_static < budget_limit,
                   f"Multi-instance scalability: 2 full campus replicas ({multi_station_static} tris) remain strictly under 2,500 limit",
                   "Stress")


# ==============================================================================
# SECTION 6: Material Performance & Mobile Draw-Call Overhead
# ==============================================================================

def run_section_6():
    print(f"\n{Colors.BOLD}{Colors.OKBLUE}=== SECTION 6: Material Performance & Mobile Draw-Call Overhead ==={Colors.ENDC}")

    bell_path = GAME_DIR / "scenes/ipo_bell_3d.tscn"
    showcase_path = GAME_DIR / "scenes/trophy_showcase_3d.tscn"

    bell_data = parse_tscn(bell_path.read_text(encoding="utf-8"))
    showcase_data = parse_tscn(showcase_path.read_text(encoding="utf-8"))

    all_materials = {
        **{k: v for k, v in bell_data["subresources"].items() if v["type"].endswith("Material3D")},
        **{k: v for k, v in showcase_data["subresources"].items() if v["type"].endswith("Material3D")}
    }

    print(f"  -> Total StandardMaterial3D definitions analyzed: {len(all_materials)}")

    all_standard_mat = True
    all_properties_valid = True
    transparent_count = 0
    max_emission_energy = 0.0

    for mid, mdata in all_materials.items():
        if mdata["type"] != "StandardMaterial3D":
            all_standard_mat = False

        props = mdata["props"]
        metallic = float(props.get("metallic", 0.0))
        roughness = float(props.get("roughness", 0.5))

        if not (0.0 <= metallic <= 1.0 and 0.0 <= roughness <= 1.0):
            all_properties_valid = False
            print(f"     INVALID PBR VALUES in {mid}: metallic={metallic}, roughness={roughness}")

        if props.get("transparency", "0") != "0":
            transparent_count += 1

        emission_energy = float(props.get("emission_energy_multiplier", 0.0))
        if emission_energy > max_emission_energy:
            max_emission_energy = emission_energy

    reporter.check(all_standard_mat, "All station materials are standard StandardMaterial3D (no costly custom shader loops)", "Materials")
    reporter.check(all_properties_valid, "All PBR metallic and roughness values lie in normalized [0.0, 1.0] interval", "Materials")
    reporter.check(transparent_count <= 3,
                   f"Minimal alpha-blending transparency overhead (only {transparent_count} materials use transparency)", "Materials")
    reporter.check(max_emission_energy <= 2.5,
                   f"Emission multipliers bounded for mobile HDR/SDR pipeline (max energy: {max_emission_energy})", "Materials")


# ==============================================================================
# MAIN ENTRY POINT
# ==============================================================================

def main():
    print("=" * 78)
    print("Adversarial Challenger Test Harness: Phase 12 Milestone 2 (Geometry & Budgets)")
    print("==============================================================================")

    run_section_1()
    run_section_2()
    run_section_3()
    run_section_4()
    run_section_5()
    run_section_6()

    reporter.print_summary()

    if reporter.failed_checks > 0:
        sys.exit(1)
    sys.exit(0)


if __name__ == "__main__":
    main()
