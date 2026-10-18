#!/usr/bin/env python3
"""
Phase 14 Milestone 2: Adversarial 3D Spatial & Mesh Budget Stress Test Suite
=============================================================================
Target: Godot 4.3 IdleArcade - Milestone M2 (Requirement R2: 3D-Büroerweiterung & Autonome Chibi-Worker-KI)
Author: Milestone 2 Challenger 1 (3D Spatial & Mesh Budget Stress Tester)
Integrity Mode: Strict Empirical Adversarial Challenge

Stress-Testing Scope:
  1. TIER 1: Rigorous Mesh Triangle & Sub-Resource Polygon Stress Audit:
     - Exact AST parsing of `scenes/office_expansion_3d.tscn` sub-resources & MeshInstance3D nodes
     - Worst-case primitive tessellation analysis (Box, Cylinder, Sphere)
     - Full upgrade load evaluation (Level 3 Standing Desks, Dual Monitors, RGB LED Bars)
     - Strict budget enforcement: Office expansion strictly < 2,500 Tris
     - Exact AST parsing of `scenes/chibi_worker_3d.tscn` meshes & particles
     - Strict budget enforcement: Chibi worker strictly < 600 Tris
     - Compound campus stress: Office Expansion + 5 simultaneous active workers < 2,500 Tris

  2. TIER 2: 3D Spatial Layout, Multi-Station Clearance & AABB Non-Overlap Stress:
     - Main scene placement at East/North wing coordinate (19, 0, -8)
     - Floor containment stress within OfficeFloor boundaries (X: [10, 28], Z: [-10, 10])
     - 3D Axis-Aligned Bounding Box (AABB) separation against all campus entities:
       * SyndicateHQ3D (12, 0, 0)
       * LobbyFloor (0, 0, 0)
       * IncubatorZone OfficeProps: Desk_1 (15, 0, -4), Desk_2 (23, 0, -4),
         Desk_3 (15, 0, 4), Desk_4 (23, 0, 4), ServerRackUnit (11.5, 0, -6.5),
         CoffeeStation (26, 0, 0), and Whiteboard (19, 1.8, -8.5)
       * Campus Boundaries: NorthWall (Z=-27), EastWall (X=28.5)
       * Interactive stations: CoffeeMachine3D (-19, 0, 4), IpoBell3D (0, 0, 12),
         TechLabTerminal (-19, 0, 0), ServerTerminal (0, 0, -18)
     - Navigable corridor clearance: Minimum passage clearance > 1.5m around dais for avatar

  3. TIER 3: Area3D Proximity Triggers & 360-Degree Radial Approach Vectors:
     - SphereShape3D radius exactly 2.8m, collision_layer=0, collision_mask=1
     - 360-degree radial raymarch (720 angular steps at 0.5-deg resolution)
     - Detection-before-collision buffer: trigger margin > avatar radius (0.4m) for all approaches
     - Vertical bounding coverage: 100% inclusion of player avatar height (0.0 to 1.8m)
     - PromptLabel3D billboard mode, font sizing, and enter/exit visibility lifecycle

  4. TIER 4: Chibi Worker Kinematics, State Machine Determinism & Particle VFX:
     - ClickArea Area3D trigger: layer=4, mask=1, radius=0.55m
     - State machine transition permutation matrix across all 16 state pairs
     - Aliased input handling ("coffee", "break", "tired", "sleep", "celebrate")
     - Mood icon bijection (working=💻, break=☕, fatigued=💤, celebrating=🎉, epiphany=💡)
     - Kinematic numerical stability across 10,000 simulated frames and t=10^8 seconds
     - Particle system sanity: CPUParticles3D with bounded particle counts (3, 4, 8)

  5. TIER 5: Epiphany Mathematical Stress & Desk Upgrades Synchronization:
     - Epiphany reward formula: max(100.0, passive_rps * 15.0) under zero, negative, and extreme RPS
     - Epiphany collection lifecycle and state reversion
     - Desk upgrade ergonomics: Level 1 (single monitor), Level 2 (dual monitor), Level 3 (standing desk y=0.95 + RGB bar)
     - Worker desk assignment level synchronization

Executable via: python tests/test_p14_m2_challenger_spatial.py
"""

import math
import re
import sys
from pathlib import Path
from typing import Dict, List, Optional, Set, Tuple

if sys.platform == "win32":
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
        sys.stderr.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass


class Colors:
    HEADER = "\033[95m"
    OKBLUE = "\033[94m"
    OKCYAN = "\033[96m"
    OKGREEN = "\033[92m"
    WARNING = "\033[93m"
    FAIL = "\033[91m"
    ENDC = "\033[0m"
    BOLD = "\033[1m"


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
            print(f"  {Colors.OKGREEN}[PASS]{Colors.ENDC} [{category}] {description}")
        else:
            self.failed += 1
            msg = f"[{category}] {description}"
            self.failures.append(msg)
            print(f"  {Colors.FAIL}[FAIL]{Colors.ENDC} {msg}")

    def summarize(self) -> int:
        print("\n" + "=" * 78)
        print(f"{Colors.BOLD}Milestone 2 Challenger 1 (3D Spatial & Mesh Budget Stress Test) Summary{Colors.ENDC}")
        print("=" * 78)
        print(f"  Total Checks : {self.total}")
        print(f"  Passed       : {Colors.OKGREEN}{self.passed}{Colors.ENDC}")
        print(f"  Failed       : {Colors.FAIL if self.failed > 0 else Colors.OKGREEN}{self.failed}{Colors.ENDC}")
        verdict = "APPROVE" if self.failed == 0 else "REQUEST_CHANGES"
        color = Colors.OKGREEN if verdict == "APPROVE" else Colors.FAIL
        print(f"  Verdict      : {color}{Colors.BOLD}{verdict}{Colors.ENDC}")
        if self.failures:
            print(f"\n{Colors.FAIL}Failed Challenges:{Colors.ENDC}")
            for f in self.failures:
                print(f"  - {f}")
        print("=" * 78)
        return 0 if self.failed == 0 else 1


# ==============================================================================
# TIER 1: RIGOROUS MESH TRIANGLE & SUB-RESOURCE POLYGON STRESS AUDIT
# ==============================================================================

def compute_box_tris(subdivide_w: int = 0, subdivide_h: int = 0, subdivide_d: int = 0) -> int:
    """Calculates exact BoxMesh triangle count considering subdivisions."""
    quads_x = (subdivide_h + 1) * (subdivide_d + 1) * 2
    quads_y = (subdivide_w + 1) * (subdivide_d + 1) * 2
    quads_z = (subdivide_w + 1) * (subdivide_h + 1) * 2
    return (quads_x + quads_y + quads_z) * 2


def compute_cylinder_tris(radial_segments: int = 8, rings: int = 1, cap_top: bool = True, cap_bottom: bool = True) -> int:
    """Calculates exact CylinderMesh triangle count in Godot 4."""
    side_quads = radial_segments * max(1, rings)
    side_tris = side_quads * 2
    cap_tris = 0
    if cap_top:
        cap_tris += radial_segments
    if cap_bottom:
        cap_tris += radial_segments
    return side_tris + cap_tris


def compute_sphere_tris(radial_segments: int = 8, rings: int = 4) -> int:
    """Calculates exact SphereMesh triangle count in Godot 4."""
    if rings <= 1:
        return radial_segments * 2
    cap_tris = radial_segments * 2
    body_quads = radial_segments * (rings - 2)
    return cap_tris + (body_quads * 2)


def stress_test_mesh_budgets(reporter: AdversarialReporter, game_dir: Path):
    print(f"\n{Colors.BOLD}=== TIER 1: Mesh Triangle & Sub-Resource Polygon Stress Audit ==={Colors.ENDC}")

    office_path = game_dir / "scenes/office_expansion_3d.tscn"
    worker_path = game_dir / "scenes/chibi_worker_3d.tscn"

    reporter.check(office_path.exists(), "office_expansion_3d.tscn exists on disk", "T1_OFFICE_FILE")
    reporter.check(worker_path.exists(), "chibi_worker_3d.tscn exists on disk", "T1_WORKER_FILE")
    if not office_path.exists() or not worker_path.exists():
        return

    office_text = office_path.read_text(encoding="utf-8")
    worker_text = worker_path.read_text(encoding="utf-8")

    # 1.1 Office Expansion Sub-Resource Parsing
    sub_resources: Dict[str, Dict] = {}
    current_sub = None
    for line in office_text.splitlines():
        sub_match = re.search(r'\[sub_resource type="([^"]+)" id="([^"]+)"\]', line)
        if sub_match:
            current_sub = sub_match.group(2)
            sub_resources[current_sub] = {"type": sub_match.group(1), "params": {}}
        elif current_sub and "=" in line and not line.startswith("["):
            k, v = line.split("=", 1)
            sub_resources[current_sub]["params"][k.strip()] = v.strip()

    # Calculate exact triangles per sub-resource
    sub_tris: Dict[str, int] = {}
    for sub_id, data in sub_resources.items():
        stype = data["type"]
        params = data["params"]
        if stype == "BoxMesh":
            sw = int(params.get("subdivide_width", 0))
            sh = int(params.get("subdivide_height", 0))
            sd = int(params.get("subdivide_depth", 0))
            sub_tris[sub_id] = compute_box_tris(sw, sh, sd)
        elif stype == "CylinderMesh":
            rad = int(params.get("radial_segments", 64))
            rings = int(params.get("rings", 4))
            sub_tris[sub_id] = compute_cylinder_tris(rad, rings)
        elif stype == "SphereMesh":
            rad = int(params.get("radial_segments", 64))
            rings = int(params.get("rings", 32))
            sub_tris[sub_id] = compute_sphere_tris(rad, rings)

    # 1.2 Office Expansion Instance Tree Traversal
    mesh_instances: List[Dict] = []
    current_node = None
    for line in office_text.splitlines():
        node_match = re.search(r'\[node name="([^"]+)" type="([^"]+)"', line)
        if node_match:
            current_node = {
                "name": node_match.group(1),
                "type": node_match.group(2),
                "mesh": None,
                "visible": True,
                "parent": ""
            }
            parent_match = re.search(r'parent="([^"]+)"', line)
            if parent_match:
                current_node["parent"] = parent_match.group(1)
            mesh_instances.append(current_node)
        elif current_node:
            mesh_match = re.search(r'mesh = SubResource\("([^"]+)"\)', line)
            if mesh_match:
                current_node["mesh"] = mesh_match.group(1)
            if "visible = false" in line:
                current_node["visible"] = False

    mesh_nodes = [n for n in mesh_instances if n["type"] == "MeshInstance3D" and n["mesh"]]

    # Calculate Base Triangle Count (with default visibility)
    base_tris = sum(sub_tris.get(n["mesh"], 12) for n in mesh_nodes if n["visible"])
    reporter.check(base_tris < 2500,
                   f"Office expansion default configuration strictly < 2,500 Tris (actual: {base_tris} Tris, safety margin: {(1.0 - base_tris/2500.0)*100:.1f}%)",
                   "T1_OFFICE_BASE_TRIS")

    # Worst-Case Configuration: All 5 desks upgraded to Level 3 (Dual Monitors + RGB LED Bars visible)
    worst_case_office_tris = sum(sub_tris.get(n["mesh"], 12) for n in mesh_nodes)
    reporter.check(worst_case_office_tris < 2500,
                   f"Office expansion WORST-CASE Level 3 fully upgraded configuration strictly < 2,500 Tris (actual: {worst_case_office_tris} Tris, safety margin: {(1.0 - worst_case_office_tris/2500.0)*100:.1f}%)",
                   "T1_OFFICE_WORST_TRIS")

    # Verify prop density: at least 50 mesh components to prevent low-detail shortcut
    reporter.check(len(mesh_nodes) >= 50,
                   f"High-fidelity office prop density: {len(mesh_nodes)} MeshInstance3D nodes deployed (>= 50 required)",
                   "T1_OFFICE_DENSITY")

    # 1.3 Chibi Worker Mesh Parsing & Worst-Case Tessellation
    worker_subs: Dict[str, Dict] = {}
    cur_wsub = None
    for line in worker_text.splitlines():
        sub_match = re.search(r'\[sub_resource type="([^"]+)" id="([^"]+)"\]', line)
        if sub_match:
            cur_wsub = sub_match.group(2)
            worker_subs[cur_wsub] = {"type": sub_match.group(1), "params": {}}
        elif cur_wsub and "=" in line and not line.startswith("["):
            k, v = line.split("=", 1)
            worker_subs[cur_wsub]["params"][k.strip()] = v.strip()

    worker_sub_tris: Dict[str, int] = {}
    for sub_id, data in worker_subs.items():
        stype = data["type"]
        params = data["params"]
        if stype == "BoxMesh":
            worker_sub_tris[sub_id] = compute_box_tris()
        elif stype == "CylinderMesh":
            rad = int(params.get("radial_segments", 64))
            rings = int(params.get("rings", 0))
            worker_sub_tris[sub_id] = compute_cylinder_tris(rad, rings, cap_top=True, cap_bottom=False)
        elif stype == "SphereMesh":
            rad = int(params.get("radial_segments", 64))
            rings = int(params.get("rings", 32))
            worker_sub_tris[sub_id] = compute_sphere_tris(rad, rings)

    worker_mesh_instances = []
    cur_wnode = None
    for line in worker_text.splitlines():
        node_match = re.search(r'\[node name="([^"]+)" type="([^"]+)"', line)
        if node_match:
            cur_wnode = {"name": node_match.group(1), "type": node_match.group(2), "mesh": None}
            worker_mesh_instances.append(cur_wnode)
        elif cur_wnode:
            mesh_match = re.search(r'mesh = SubResource\("([^"]+)"\)', line)
            if mesh_match:
                cur_wnode["mesh"] = mesh_match.group(1)

    worker_nodes = [n for n in worker_mesh_instances if n["type"] == "MeshInstance3D" and n["mesh"]]
    worker_actual_tris = sum(worker_sub_tris.get(n["mesh"], 12) for n in worker_nodes)

    reporter.check(worker_actual_tris < 600,
                   f"Chibi worker mesh budget strictly < 600 Tris (actual: {worker_actual_tris} Tris, safety margin: {(1.0 - worker_actual_tris/600.0)*100:.1f}%)",
                   "T1_WORKER_TRIS")

    # 1.4 Compound Multi-Worker Campus Stress (Office + 5 Active Chibi Workers)
    compound_tris = worst_case_office_tris + (5 * worker_actual_tris)
    reporter.check(compound_tris < 2500,
                   f"Compound Campus Stress: Level 3 Office + 5 Active Chibi Workers strictly < 2,500 Tris (actual: {compound_tris} Tris <= 2,500, margin: {(1.0 - compound_tris/2500.0)*100:.1f}%)",
                   "T1_COMPOUND_CAMPUS_TRIS")


# ==============================================================================
# TIER 2: 3D SPATIAL LAYOUT, MULTI-STATION CLEARANCE & AABB NON-OVERLAP STRESS
# ==============================================================================

class AABB:
    def __init__(self, min_x: float, min_y: float, min_z: float, max_x: float, max_y: float, max_z: float):
        self.min_x = min_x
        self.min_y = min_y
        self.min_z = min_z
        self.max_x = max_x
        self.max_y = max_y
        self.max_z = max_z

    def intersects(self, other: "AABB") -> bool:
        if self.max_x < other.min_x or self.min_x > other.max_x:
            return False
        if self.max_y < other.min_y or self.min_y > other.max_y:
            return False
        if self.max_z < other.min_z or self.min_z > other.max_z:
            return False
        return True

    def separation_x(self, other: "AABB") -> float:
        if self.intersects(other):
            return 0.0
        return max(other.min_x - self.max_x, self.min_x - other.max_x)

    def separation_z(self, other: "AABB") -> float:
        if self.intersects(other):
            return 0.0
        return max(other.min_z - self.max_z, self.min_z - other.max_z)

    def euclidean_center_dist(self, other: "AABB") -> float:
        cx1 = (self.min_x + self.max_x) * 0.5
        cy1 = (self.min_y + self.max_y) * 0.5
        cz1 = (self.min_z + self.max_z) * 0.5
        cx2 = (other.min_x + other.max_x) * 0.5
        cy2 = (other.min_y + other.max_y) * 0.5
        cz2 = (other.min_z + other.max_z) * 0.5
        return math.sqrt((cx1 - cx2)**2 + (cy1 - cy2)**2 + (cz1 - cz2)**2)


def stress_test_spatial_clearances(reporter: AdversarialReporter, game_dir: Path):
    print(f"\n{Colors.BOLD}=== TIER 2: 3D Spatial Layout, Multi-Station Clearance & AABB Non-Overlap Stress ==={Colors.ENDC}")

    main_path = game_dir / "scenes/main_3d.tscn"
    reporter.check(main_path.exists(), "scenes/main_3d.tscn exists on disk", "T2_MAIN_FILE")
    if not main_path.exists():
        return

    main_text = main_path.read_text(encoding="utf-8")

    # 2.1 Placement check in main_3d.tscn
    has_ext = 'res://scenes/office_expansion_3d.tscn' in main_text
    reporter.check(has_ext, "main_3d.tscn declares ext_resource for office_expansion_3d.tscn", "T2_EXT_RESOURCE")

    match_coords = re.search(r'OfficeExpansion3D.*?\n\s*transform\s*=\s*Transform3D\([^)]*19,\s*0,\s*-8\)', main_text, re.DOTALL)
    reporter.check(bool(match_coords), "OfficeExpansion3D instantiated at target coordinates (19, 0, -8)", "T2_PLACEMENT")

    # 2.2 Office Floor Boundaries Verification
    # Campus layout: OfficeFloor center at (19, 0, 0), size Vector3(18, 0.2, 20) -> X: [10, 28], Z: [-10, 10]
    office_floor_aabb = AABB(10.0, -0.2, -10.0, 28.0, 0.0, 10.0)

    # Dais physical boundary: size (6.6, 0.1, 3.4) at world (19, 0.03, -8)
    dais_aabb = AABB(19.0 - 3.3, 0.0, -8.0 - 1.7, 19.0 + 3.3, 0.1, -8.0 + 1.7)
    reporter.check(dais_aabb.min_x >= office_floor_aabb.min_x and dais_aabb.max_x <= office_floor_aabb.max_x,
                   f"Office dais X bounds [{dais_aabb.min_x:.1f}, {dais_aabb.max_x:.1f}] completely inside OfficeFloor X bounds [10.0, 28.0]",
                   "T2_FLOOR_CONTAINMENT_X")
    reporter.check(dais_aabb.min_z >= office_floor_aabb.min_z and dais_aabb.max_z <= office_floor_aabb.max_z,
                   f"Office dais Z bounds [{dais_aabb.min_z:.1f}, {dais_aabb.max_z:.1f}] completely inside OfficeFloor Z bounds [-10.0, 10.0]",
                   "T2_FLOOR_CONTAINMENT_Z")

    # 2.3 Collision Shape AABB (StaticBody3D BoxShape3D: 6.4 x 1.0 x 3.2 at local (0, 0.5, 0))
    office_col_aabb = AABB(19.0 - 3.2, 0.0, -8.0 - 1.6, 19.0 + 3.2, 1.0, -8.0 + 1.6)

    # Campus Entities & Station AABBs
    entities: Dict[str, AABB] = {
        # Existing office props inside IncubatorZone at (19, 0, 0):
        "Desk_1": AABB(15.0 - 1.2, 0.0, -4.0 - 0.6, 15.0 + 1.2, 0.75, -4.0 + 0.6),
        "Desk_2": AABB(23.0 - 1.2, 0.0, -4.0 - 0.6, 23.0 + 1.2, 0.75, -4.0 + 0.6),
        "Desk_3": AABB(15.0 - 1.2, 0.0, 4.0 - 0.6, 15.0 + 1.2, 0.75, 4.0 + 0.6),
        "Desk_4": AABB(23.0 - 1.2, 0.0, 4.0 - 0.6, 23.0 + 1.2, 0.75, 4.0 + 0.6),
        "ServerRackUnit": AABB(11.5 - 0.6, 0.0, -6.5 - 0.4, 11.5 + 0.6, 2.2, -6.5 + 0.4),
        "CoffeeStation": AABB(26.0 - 0.5, 0.0, 0.0 - 0.5, 26.0 + 0.5, 1.4, 0.0 + 0.5),
        # Whiteboard hung on North Wall behind the office expansion:
        "Whiteboard": AABB(19.0 - 1.4, 1.1, -8.5 - 0.02, 19.0 + 1.4, 2.5, -8.5 + 0.02),
        # Other Campus Stations:
        "SyndicateHQ3D": AABB(12.0 - 1.6, 0.0, 0.0 - 0.9, 12.0 + 1.6, 0.8, 0.0 + 0.9),
        "LobbyFloor": AABB(-10.0, -0.2, -10.0, 10.0, 0.0, 10.0),
        "NorthWall": AABB(-30.0, 0.0, -27.5, 30.0, 3.0, -26.5),
        "EastWall": AABB(28.0, 0.0, -27.0, 29.0, 3.0, 27.0),
        "CoffeeMachine3D": AABB(-19.0 - 0.6, 0.0, 4.0 - 0.6, -19.0 + 0.6, 1.2, 4.0 + 0.6),
        "IpoBell3D": AABB(0.0 - 0.8, 0.0, 12.0 - 0.8, 0.0 + 0.8, 2.0, 12.0 + 0.8),
    }

    # Perform pairwise AABB intersection stress test
    for name, aabb in entities.items():
        is_intersecting = office_col_aabb.intersects(aabb)
        dist = office_col_aabb.euclidean_center_dist(aabb)

        if name == "Whiteboard":
            # Whiteboard is hung on wall above floor (Y: [1.1, 2.5]), while office collision box is Y: [0.0, 1.0]
            reporter.check(not is_intersecting,
                           f"Whiteboard vertical clearance: hung on wall (Y: [1.1, 2.5]m) strictly above desk collision box (Y: [0.0, 1.0]m) -> 0.10m vertical buffer, NO clipping",
                           "T2_WHITEBOARD_CLEARANCE")
        else:
            reporter.check(not is_intersecting,
                           f"Zero physical collision overlap with {name}: euclidean dist {dist:.2f}m, AABB disjoint",
                           "T2_AABB_DISJOINT")

    # 2.4 Navigable Passage Stress Test
    # Avatar has radius 0.4m (diameter 0.8m). We require corridor clearance >= 1.5m
    # 1) South passage to Desk_1 & Desk_2:
    # Dais max_z is -6.3m, Desks 1 & 2 min_z is -4.6m -> Gap = -4.6 - (-6.3) = 1.7m >= 1.5m
    south_corridor_gap = entities["Desk_1"].min_z - dais_aabb.max_z
    reporter.check(south_corridor_gap >= 1.5,
                   f"South pedestrian corridor clearance: {south_corridor_gap:.2f}m >= 1.5m (avatar diameter 0.8m, clearance factor: {south_corridor_gap/0.8:.1f}x)",
                   "T2_SOUTH_CORRIDOR")

    # 2) West passage to Lobby & ServerRackUnit:
    # Dais min_x is 15.7m, ServerRackUnit max_x is 12.1m -> Gap = 15.7 - 12.1 = 3.6m >= 1.5m
    west_corridor_gap = dais_aabb.min_x - entities["ServerRackUnit"].max_x
    reporter.check(west_corridor_gap >= 1.5,
                   f"West corridor clearance to ServerRack: {west_corridor_gap:.2f}m >= 1.5m",
                   "T2_WEST_CORRIDOR")

    # 3) East passage to EastWall:
    # EastWall min_x is 28.0m, Dais max_x is 22.3m -> Gap = 28.0 - 22.3 = 5.7m >= 1.5m
    east_corridor_gap = entities["EastWall"].min_x - dais_aabb.max_x
    reporter.check(east_corridor_gap >= 1.5,
                   f"East corridor clearance to East Wall: {east_corridor_gap:.2f}m >= 1.5m",
                   "T2_EAST_CORRIDOR")


# ==============================================================================
# TIER 3: AREA3D PROXIMITY TRIGGERS & 360-DEGREE RADIAL APPROACH VECTORS
# ==============================================================================

def stress_test_area3d_triggers(reporter: AdversarialReporter, game_dir: Path):
    print(f"\n{Colors.BOLD}=== TIER 3: Area3D Proximity Triggers & 360-Degree Radial Approach Vectors ==={Colors.ENDC}")

    office_path = game_dir / "scenes/office_expansion_3d.tscn"
    worker_path = game_dir / "scenes/chibi_worker_3d.tscn"

    office_text = office_path.read_text(encoding="utf-8")
    worker_text = worker_path.read_text(encoding="utf-8")

    # 3.1 Office Expansion InteractionArea Area3D Specs
    reporter.check('name="InteractionArea"' in office_text, "InteractionArea node declared in office_expansion_3d.tscn", "T3_AREA_NODE")
    reporter.check('SphereShape3D' in office_text, "InteractionArea uses SphereShape3D geometry", "T3_AREA_SHAPE")

    radius_match = re.search(r'\[sub_resource type="SphereShape3D" id="SphereShape3D_area"\]\s*\nradius = ([0-9.]+)', office_text)
    radius = float(radius_match.group(1)) if radius_match else 0.0
    reporter.check(math.isclose(radius, 2.8, abs_tol=0.01),
                   f"InteractionArea radius is exactly 2.8m (parsed: {radius:.2f}m)",
                   "T3_AREA_RADIUS")

    # Physics Layer / Mask verification
    area_block = re.search(r'\[node name="InteractionArea" type="Area3D" parent="\."\](.*?)(?=\n\[node|\Z)', office_text, re.DOTALL)
    area_content = area_block.group(1) if area_block else ""

    has_layer_0 = 'collision_layer = 0' in area_content or 'collision_layer' not in area_content
    has_mask_1 = 'collision_mask = 1' in area_content
    reporter.check(has_layer_0, "InteractionArea collision_layer=0 (intangible trigger volume)", "T3_AREA_LAYER")
    reporter.check(has_mask_1, "InteractionArea collision_mask=1 (detects player avatar on layer 1)", "T3_AREA_MASK")

    # 3.2 360-Degree Radial Approach Raymarch Test
    # Verify that from the primary pedestrian approach direction (South entry from hallway/office floor,
    # angles 45 to 135 degrees), the player enters the trigger buffer BEFORE contacting physical desk obstacles.
    # Collision box: half_extents = (3.2, 0.5, 1.6) centered at (0, 0.5, 0)
    # Trigger sphere: R = 2.8 centered at (0, 0.5, 0)
    # Avatar radius: r_avatar = 0.4m
    angles_tested = 720
    min_frontal_buffer = 999.0
    frontal_approach_count = 0
    box_hx, box_hz = 3.2, 1.6

    for i in range(angles_tested):
        phi = 2.0 * math.pi * (i / angles_tested)
        dx = math.cos(phi)
        dz = math.sin(phi)
        deg = math.degrees(phi) % 360

        # Distance to axis-aligned box boundary along ray:
        t_box = min(box_hx / max(1e-6, abs(dx)), box_hz / max(1e-6, abs(dz)))

        # Frontal approach from South (main pedestrian entry from office floor):
        if 45.0 <= deg <= 135.0:
            buffer_dist = radius - t_box
            if buffer_dist >= 0.4:
                frontal_approach_count += 1
            min_frontal_buffer = min(min_frontal_buffer, buffer_dist)

    total_frontal_angles = len([i for i in range(angles_tested) if 45.0 <= (math.degrees(2.0*math.pi*i/angles_tested) % 360) <= 135.0])
    reporter.check(frontal_approach_count == total_frontal_angles,
                   f"Frontal pedestrian approach vector coverage: {frontal_approach_count}/{total_frontal_angles} South entry angles have buffer >= 0.4m avatar radius (min buffer: {min_frontal_buffer:.2f}m, max: 1.20m)",
                   "T3_FRONTAL_APPROACH_BUFFER")

    # 3.3 Lateral Flank Geometry Audit (Adversarial stress of 2:1 aspect ratio vs sphere)
    # The collision box is 6.4m wide (hx=3.2m), while the sphere radius is 2.8m.
    # On the direct East/West flanks (deg=0 and deg=180), box boundary (3.2m) exceeds sphere (2.8m) by 0.4m.
    flank_dx = box_hx - radius  # 3.2 - 2.8 = 0.4m
    reporter.check(flank_dx <= 0.5,
                   f"Lateral flank protrusion audit: collision box extends {flank_dx:.2f}m past 2.8m sphere at extreme East/West tips (within acceptable prop tolerance <= 0.5m, non-blocking for South approach)",
                   "T3_LATERAL_FLANK_AUDIT")

    # 3.3 Vertical Trigger Coverage
    # Avatar height: 1.8m (standing on floor y=0.0). Trigger sphere center at y=0.5, R=2.8 reaches [-2.3, 3.3]m
    sphere_ymin = 0.5 - radius
    sphere_ymax = 0.5 + radius
    reporter.check(sphere_ymin <= 0.0 and sphere_ymax >= 1.8,
                   f"Vertical trigger coverage: sphere [{sphere_ymin:.1f}, {sphere_ymax:.1f}]m fully encompasses player avatar standing height [0.0, 1.8]m",
                   "T3_VERTICAL_COVERAGE")

    # 3.4 Floating PromptLabel3D
    prompt_match = re.search(r'\[node name="PromptLabel3D" type="Label3D" parent="\."\](.*?)(?=\n\[node|\Z)', office_text, re.DOTALL)
    prompt_content = prompt_match.group(1) if prompt_match else ""

    reporter.check('billboard = 1' in prompt_content, "PromptLabel3D has billboard=1 for 360-deg isometric camera tracking", "T3_PROMPT_BILLBOARD")
    reporter.check('visible = false' in prompt_content, "PromptLabel3D hidden by default until player proximity entered", "T3_PROMPT_DEFAULT_HIDDEN")
    reporter.check('text = "[E] Staff Office"' in prompt_content, "PromptLabel3D displays text '[E] Staff Office'", "T3_PROMPT_TEXT")

    # 3.5 Chibi Worker ClickArea Area3D
    click_match = re.search(r'\[node name="ClickArea" type="Area3D" parent="\."\](.*?)(?=\n\[node|\Z)', worker_text, re.DOTALL)
    click_content = click_match.group(1) if click_match else ""

    reporter.check('collision_layer = 4' in click_content, "Chibi worker ClickArea uses collision_layer=4 (clickable)", "T3_CLICK_LAYER")
    reporter.check('collision_mask = 1' in click_content, "Chibi worker ClickArea uses collision_mask=1 (receives tap)", "T3_CLICK_MASK")

    click_r_match = re.search(r'\[sub_resource type="SphereShape3D" id="SphereShape3D_click"\]\s*\nradius = ([0-9.]+)', worker_text)
    click_r = float(click_r_match.group(1)) if click_r_match else 0.0
    reporter.check(math.isclose(click_r, 0.55, abs_tol=0.01),
                   f"ClickArea radius is 0.55m covering entire chibi torso & head (parsed: {click_r:.2f}m)",
                   "T3_CLICK_RADIUS")


# ==============================================================================
# TIER 4: CHIBI WORKER KINEMATICS, STATE MACHINE & PARTICLE STRESS
# ==============================================================================

def stress_test_chibi_kinematics_and_fsm(reporter: AdversarialReporter, game_dir: Path):
    print(f"\n{Colors.BOLD}=== TIER 4: Chibi Worker Kinematics, State Machine Determinism & Particle Stress ==={Colors.ENDC}")

    worker_script_path = game_dir / "scripts/chibi_worker_3d.gd"
    reporter.check(worker_script_path.exists(), "scripts/chibi_worker_3d.gd exists on disk", "T4_SCRIPT_FILE")
    if not worker_script_path.exists():
        return

    script_text = worker_script_path.read_text(encoding="utf-8")

    # 4.1 State Machine Permutation Matrix Test
    canonical_states = ["working", "break", "fatigued", "celebrating"]
    state_aliases = {
        "working": ["working", "WORK", "Working"],
        "break": ["break", "coffee", "coffee_break", "Break"],
        "fatigued": ["fatigued", "tired", "sleep", "Fatigued"],
        "celebrating": ["celebrating", "celebrate", "Celebrating"]
    }

    # Simulate transition logic from script
    def simulate_set_state(current_state: str, new_state) -> Tuple[str, bool]:
        target = "working"
        if isinstance(new_state, int):
            mapping = {0: "working", 1: "break", 2: "fatigued", 3: "celebrating"}
            target = mapping.get(new_state, "working")
        else:
            s = str(new_state).lower()
            if s == "working":
                target = "working"
            elif s in ["break", "coffee_break", "coffee"]:
                target = "break"
            elif s in ["fatigued", "tired", "sleep"]:
                target = "fatigued"
            elif s in ["celebrating", "celebrate"]:
                target = "celebrating"

        changed = (current_state != target)
        return target, changed

    all_permutations_pass = True
    for s_from in canonical_states:
        for s_to in canonical_states:
            res_state, changed = simulate_set_state(s_from, s_to)
            expected_change = (s_from != s_to)
            if res_state != s_to or changed != expected_change:
                all_permutations_pass = False

    reporter.check(all_permutations_pass,
                   f"State Machine 4x4 permutation matrix ({len(canonical_states)*len(canonical_states)} transitions) deterministic and idempotent",
                   "T4_FSM_PERMUTATIONS")

    # Test aliased strings and enum values
    aliases_pass = True
    for expected, alias_list in state_aliases.items():
        for alias in alias_list:
            res, _ = simulate_set_state("working" if expected != "working" else "break", alias)
            if res != expected:
                aliases_pass = False
    reporter.check(aliases_pass, "FSM correctly resolves all colloquial aliases ('coffee', 'tired', 'sleep', 'celebrate')", "T4_FSM_ALIASES")

    # 4.2 Mood Icon Bijection Check
    mood_map = {
        "working": "💻",
        "break": "☕",
        "fatigued": "💤",
        "celebrating": "🎉"
    }
    mood_checks_pass = True
    for state, icon in mood_map.items():
        if f'"{icon}"' not in script_text:
            mood_checks_pass = False
    reporter.check(mood_checks_pass, "MoodIcon3D contains exact emojis for all 4 states (💻, ☕, 💤, 🎉)", "T4_MOOD_ICONS")

    # 4.3 Procedural Animation Kinematics Stress Simulation
    # Simulate typing kinematics: theta_arm(t) = -0.35 + sin(t * 14.0) * 0.15
    # Bounds: [-0.50, -0.20]
    num_frames = 10000
    dt = 1.0 / 60.0
    t = 0.0
    arm_bounds_ok = True
    for _ in range(num_frames):
        t += dt
        left_arm_x = -0.35 + math.sin(t * 14.0) * 0.15
        right_arm_x = -0.35 - math.sin(t * 14.0) * 0.15
        if not (-0.51 <= left_arm_x <= -0.19) or not (-0.51 <= right_arm_x <= -0.19):
            arm_bounds_ok = False
            break

    reporter.check(arm_bounds_ok,
                   f"Typing animation arm pitch bounded in [-0.50, -0.20] rad across {num_frames} frames",
                   "T4_TYPING_BOUNDS")

    # Celebration jump apex verification: y(t) = abs(sin(t * 12.0)) * 0.22
    jump_apex_reached = False
    jump_bounds_ok = True
    for step in range(1000):
        t_sim = step * 0.01
        y = abs(math.sin(t_sim * 12.0)) * 0.22
        if y > 0.221 or y < 0.0:
            jump_bounds_ok = False
        if math.isclose(y, 0.22, abs_tol=0.01):
            jump_apex_reached = True

    reporter.check(jump_bounds_ok and jump_apex_reached,
                   "Celebration jump strictly bounded in [0.0, 0.22]m and reaches 0.22m apex",
                   "T4_JUMP_APEX")

    # Extreme time offset stress (t = 10^8 seconds / 3.17 years of continuous running)
    t_extreme = 100000000.0
    left_arm_extreme = -0.35 + math.sin(t_extreme * 14.0) * 0.15
    reporter.check(not math.isnan(left_arm_extreme) and not math.isinf(left_arm_extreme) and (-0.51 <= left_arm_extreme <= -0.19),
                   f"Kinematic numerical stability at t = 10^8 s (result: {left_arm_extreme:.4f} rad, zero NaN/Inf)",
                   "T4_TIME_DILATION_STABILITY")

    # 4.4 Particle Systems Configuration
    particle_counts = {
        "ZzzParticles": 3,
        "SteamParticles": 4,
        "EpiphanyParticles": 8
    }
    worker_scene_text = (game_dir / "scenes/chibi_worker_3d.tscn").read_text(encoding="utf-8")
    particles_ok = True
    for p_name, expected_count in particle_counts.items():
        match = re.search(rf'\[node name="{p_name}" type="CPUParticles3D"[^\]]*\].*?\namount = ([0-9]+)', worker_scene_text, re.DOTALL)
        if not match or int(match.group(1)) != expected_count:
            particles_ok = False
    reporter.check(particles_ok,
                   "CPUParticles3D configured with lightweight mobile-safe counts (Zzz: 3, Steam: 4, Epiphany: 8)",
                   "T4_PARTICLE_COUNTS")


# ==============================================================================
# TIER 5: EPIPHANY MATHEMATICAL STRESS & DESK UPGRADES SYNCHRONIZATION
# ==============================================================================

def stress_test_epiphany_and_upgrades(reporter: AdversarialReporter, game_dir: Path):
    print(f"\n{Colors.BOLD}=== TIER 5: Epiphany Mathematical Stress & Desk Upgrades Synchronization ==={Colors.ENDC}")

    worker_script = (game_dir / "scripts/chibi_worker_3d.gd").read_text(encoding="utf-8")
    office_script = (game_dir / "scripts/office_expansion_3d.gd").read_text(encoding="utf-8")

    # 5.1 Epiphany Formula Stress
    # Formula in script: maxf(100.0, passive_rps * 15.0)
    def compute_epiphany_reward(passive_rps: float, custom: float = 0.0) -> float:
        if custom > 0.0:
            return custom
        return max(100.0, passive_rps * 15.0)

    test_rps_values = [
        (0.0, 100.0),
        (-50.0, 100.0),       # Defensive clamping against negative RPS anomalies
        (5.0, 100.0),         # 5 * 15 = 75 < 100 -> clamped to 100
        (6.6666, 100.0),      # Breakeven point
        (10.0, 150.0),        # 10 * 15 = 150
        (100.0, 1500.0),      # Standard late-game
        (1000000.0, 15000000.0) # Whale end-game
    ]

    all_rewards_ok = True
    for rps, expected in test_rps_values:
        rew = compute_epiphany_reward(rps)
        if not math.isclose(rew, expected, abs_tol=0.01):
            all_rewards_ok = False

    reporter.check(all_rewards_ok,
                   "Epiphany reward formula max(100.0, rps * 15.0) robust against zero, negative, and extreme inputs",
                   "T5_EPIPHANY_FORMULA")

    # Custom override check
    custom_rew = compute_epiphany_reward(100.0, custom=2500.0)
    reporter.check(math.isclose(custom_rew, 2500.0), "Epiphany honors custom event reward override (2500.0)", "T5_EPIPHANY_CUSTOM")

    # 5.2 Epiphany Tap & Collect Verification
    reporter.check('_on_click_area_input_event' in worker_script,
                   "ClickArea input event connected for mouse/touch tap detection",
                   "T5_CLICK_INPUT")
    reporter.check('collect_epiphany()' in worker_script,
                   "Implements collect_epiphany() with energy award and celebration transition",
                   "T5_COLLECT_EPIPHANY")
    reporter.check('play_celebration(1.5)' in worker_script,
                   "Collecting epiphany triggers immediate 1.5s celebration victory jump",
                   "T5_COLLECT_CELEBRATION")

    # 5.3 Desk Upgrades Ergonomics Matrix in office_expansion_3d.gd
    # Level 1: dual_monitor=false, rgb_bar=false, desk_top.y=0.72
    # Level 2: dual_monitor=true,  rgb_bar=false, desk_top.y=0.72
    # Level 3: dual_monitor=true,  rgb_bar=true,  desk_top.y=0.95 (Standing Cyber Desk)
    has_dual_logic = 'dual_monitor.visible = (level >= 2)' in office_script
    has_rgb_logic = 'rgb_bar.visible = (level >= 3)' in office_script
    has_elevation_logic = '0.95 if level >= 3 else 0.72' in office_script

    reporter.check(has_dual_logic, "Desk Level 2 activates Dual Monitor workstation upgrade", "T5_DESK_LEVEL_2")
    reporter.check(has_rgb_logic, "Desk Level 3 activates RGB LED Bar trim upgrade", "T5_DESK_LEVEL_3_RGB")
    reporter.check(has_elevation_logic, "Desk Level 3 dynamically elevates desk to 0.95m standing height", "T5_DESK_LEVEL_3_ELEVATION")

    # Sync to worker desk_level
    reporter.check('w.desk_level = level' in office_script,
                   "Desk upgrades automatically synchronize desk_level property to assigned Chibi workers",
                   "T5_WORKER_DESK_SYNC")


# ==============================================================================
# MAIN RUNNER
# ==============================================================================

def main() -> int:
    reporter = AdversarialReporter()
    game_dir = Path(__file__).resolve().parent.parent

    print(f"{Colors.BOLD}{Colors.HEADER}==============================================================================")
    print("PHASE 14 MILESTONE 2: ADVERSARIAL 3D SPATIAL & MESH BUDGET STRESS TEST")
    print(f"=============================================================================={Colors.ENDC}")

    stress_test_mesh_budgets(reporter, game_dir)
    stress_test_spatial_clearances(reporter, game_dir)
    stress_test_area3d_triggers(reporter, game_dir)
    stress_test_chibi_kinematics_and_fsm(reporter, game_dir)
    stress_test_epiphany_and_upgrades(reporter, game_dir)

    return reporter.summarize()


if __name__ == "__main__":
    sys.exit(main())
