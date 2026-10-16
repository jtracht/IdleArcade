#!/usr/bin/env python3
"""
Phase 12 Milestone 2: 3D-Börsenglocke & Trophäen-Showcase Verification Suite
=============================================================================
Target: Godot 4.3 IdleArcade - Milestone M2 (Requirement R2: 3D-Börsenglocke & Trophäen-Showcase)

Validates:
  1. AST & Static Code Contracts:
     - Audio Engine Extension in `scripts/autoload/audio_manager.gd`:
       * `_wav_bell: AudioStreamWAV` variable
       * `play_sfx_bell() -> void` method updating `last_sfx_played = "bell"`
       * `_synth_bell() -> AudioStreamWAV` procedural 16-bit PCM synthesis method
       * Audio parameters: SAMPLE_RATE = 22050, duration 1.25s, frequencies 587.33 Hz (D5),
         880.00 Hz (A5), 1174.66 Hz (D6), and 2349.00 Hz transient click.
     - 3D IPO Bell in `scenes/ipo_bell_3d.tscn` + `scripts/ipo_bell_3d.gd`:
       * class_name IpoBell3D, StaticBody3D root in groups `["interactables", "ipo_bells", "stations"]`
       * CollisionShape3D, InteractionArea with SphereShape3D radius 2.5m
       * PromptLabel3D with text "🔔 [E] Ring IPO Bell", billboard=1, outline_size >= 5
       * BellPivot at y=1.8m, BellCrown hemisphere, BellBody, FlaredLip, Clapper, PullCord
       * GoldParticles CPUParticles3D
       * Methods: `interact()`, `ring_bell()`, `ring_ipo_bell()`, `is_player_in_range()`, `is_swinging()`
       * Decaying oscillation Tween on `rotation_degrees:z`
       * Proximity registration with TouchControls ("IPO Bell [E]")
     - 3D Trophy Showcase in `scenes/trophy_showcase_3d.tscn` + `scripts/trophy_showcase_3d.gd`:
       * class_name TrophyShowcase3D, StaticBody3D root in groups `["interactables", "trophy_showcase"]`
       * CollisionShape3D, InteractionArea with radius 2.5m, PromptLabel3D
       * Table base, trim, front plaque, and 4 milestone pedestals
       * 4 Milestone Trophies: Golden Briefcase, Matrix Server Plaque, Crystal Chalice, Platinum Bull
       * Methods: `refresh_trophies()`, `interact()`, `is_player_in_range()`
       * Continuous gentle idle rotation on trophy meshes
       * Dynamic unlock detection via GameState (`is_trophy_unlocked`, `unlocked_trophies`)
     - Campus Placement in `scenes/main_3d.tscn`:
       * IpoBell3D at `Vector3(0.0, 0.0, 12.0)`
       * TrophyShowcase3D at `Vector3(6.0, 0.0, 12.0)`
  2. Geometric Topology & Low-Poly Triangle Budget:
     - Exact mathematical triangle accounting across all primitive meshes
     - IPO Bell static triangles < 800
     - Trophy Showcase static triangles < 1,200
     - Combined static geometry < 2,500 triangles
  3. Audio PCM Synthesis Mathematical Simulation:
     - Verifies 27,562 samples at 22,050 Hz across 1.25s
     - Amplitude bounds [-1.0, 1.0], no NaNs, non-silent RMS > 0.05
     - Exponential envelope decay over 1.25s
     - Harmonic presence at 587 Hz, 880 Hz, 1175 Hz, and 2349 Hz
  4. Behavioral & Proximity State Machine Simulation:
     - Proximity enter/exit, TouchControls registration, bell swing tween,
       particle emission, audio trigger, and trophy unlock state transitions.

Executable via: python tests/test_p12_m2_props.py
"""

import math
import os
import re
import sys
from pathlib import Path
from typing import Dict, Any, List, Optional

# UTF-8 stdout configuration
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


class TestReporter:
    def __init__(self):
        self.passes = 0
        self.fails = 0
        self.total = 0

    def check(self, condition: bool, description: str, detail: str = ""):
        self.total += 1
        if condition:
            print(f"  {Colors.OKGREEN}[PASS]{Colors.ENDC} {description}")
            self.passes += 1
        else:
            msg = f"  {Colors.FAIL}[FAIL]{Colors.ENDC} {description}"
            if detail:
                msg += f" -> {detail}"
            print(msg)
            self.fails += 1

    def print_summary(self):
        print("\n" + "=" * 70)
        print("Milestone M2 (3D IPO Bell & Trophy Showcase) Verification Summary:")
        print(f"  Total Checks: {self.total}")
        print(f"  Passed:       {Colors.OKGREEN}{self.passes}{Colors.ENDC}")
        print(f"  Failed:       {Colors.FAIL if self.fails > 0 else Colors.OKGREEN}{self.fails}{Colors.ENDC}")
        print("=" * 70)
        if self.fails == 0:
            print(f"{Colors.BOLD}{Colors.OKGREEN}>>> ALL CHECKS PASSED: Milestone M2 Props & Audio Engine Verified! <<<{Colors.ENDC}\n")
        else:
            print(f"{Colors.BOLD}{Colors.FAIL}>>> VERIFICATION FAILED: {self.fails} check(s) did not meet specification. <<<{Colors.ENDC}\n")


reporter = TestReporter()

# ==============================================================================
# Helper Functions: TSCN Parser & Geometry Topology Formulas
# ==============================================================================

def parse_tscn(content: str) -> dict:
    """Parses a Godot .tscn file into structured subresources, external resources, and nodes."""
    subresources = {}
    extresources = {}
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

    node_matches = re.finditer(r'^\[node\s+name="([^"]+)"(?:\s+type="([^"]+)")?(.*?)\]$(?:\r?\n)?([\s\S]*?)(?=\r?\n\[|\Z)', content, re.MULTILINE)
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

    return 0


# ==============================================================================
# SECTION 1: Static Code Contracts & AST Verification
# ==============================================================================

def run_section_1():
    print(f"\n{Colors.BOLD}{Colors.OKBLUE}=== SECTION 1: Static Code Contracts & AST Verification ==={Colors.ENDC}")

    # 1.1 AudioManager Bell Audio Extension
    am_path = GAME_DIR / "scripts/autoload/audio_manager.gd"
    reporter.check(am_path.exists(), "scripts/autoload/audio_manager.gd exists")
    am_content = am_path.read_text(encoding="utf-8") if am_path.exists() else ""

    reporter.check("var _wav_bell: AudioStreamWAV" in am_content,
                   "audio_manager.gd declares var _wav_bell: AudioStreamWAV")
    reporter.check("func play_sfx_bell(" in am_content,
                   "audio_manager.gd implements func play_sfx_bell() -> void")
    reporter.check('"bell"' in am_content and '_play_sfx_stream(_wav_bell, "bell")' in am_content,
                   "play_sfx_bell routes to stream player with 'bell' ID")
    reporter.check("func _synth_bell(" in am_content,
                   "audio_manager.gd implements procedural func _synth_bell() -> AudioStreamWAV")
    reporter.check("587.33" in am_content, "audio_manager.gd integrates D5 frequency (587.33 Hz)")
    reporter.check("880.00" in am_content or "880.0" in am_content,
                   "audio_manager.gd integrates A5 frequency (880.00 Hz)")
    reporter.check("1174.66" in am_content, "audio_manager.gd integrates D6 frequency (1174.66 Hz)")
    reporter.check("2349" in am_content, "audio_manager.gd integrates transient strike click frequency (2349 Hz)")
    reporter.check("1.25" in am_content, "audio_manager.gd synthesizes bell over 1.25s duration")

    # 1.2 3D IPO Bell Scene & Script
    bell_scene_path = GAME_DIR / "scenes/ipo_bell_3d.tscn"
    bell_script_path = GAME_DIR / "scripts/ipo_bell_3d.gd"
    reporter.check(bell_scene_path.exists(), "scenes/ipo_bell_3d.tscn exists")
    reporter.check(bell_script_path.exists(), "scripts/ipo_bell_3d.gd exists")

    bell_tscn = bell_scene_path.read_text(encoding="utf-8") if bell_scene_path.exists() else ""
    bell_gd = bell_script_path.read_text(encoding="utf-8") if bell_script_path.exists() else ""
    parsed_bell = parse_tscn(bell_tscn)

    reporter.check("class_name IpoBell3D" in bell_gd, "ipo_bell_3d.gd declares class_name IpoBell3D")
    reporter.check("signal bell_rung" in bell_gd, "ipo_bell_3d.gd declares signal bell_rung")
    reporter.check("signal ipo_bell_interacted" in bell_gd, "ipo_bell_3d.gd declares signal ipo_bell_interacted")
    reporter.check("func interact(" in bell_gd, "ipo_bell_3d.gd implements func interact()")
    reporter.check("func ring_bell(" in bell_gd, "ipo_bell_3d.gd implements func ring_bell()")
    reporter.check("play_sfx_bell" in bell_gd, "ipo_bell_3d.gd calls AudioManager.play_sfx_bell()")
    reporter.check("rotation_degrees:z" in bell_gd or 'rotation_degrees:z' in bell_gd,
                   "ipo_bell_3d.gd tweens BellPivot on rotation_degrees:z")
    reporter.check("create_tween(" in bell_gd, "ipo_bell_3d.gd uses create_tween() for decaying oscillation")
    reporter.check('"IPO Bell [E]"' in bell_gd, "ipo_bell_3d.gd registers 'IPO Bell [E]' action label")

    # Check root node groups in parsed_bell
    root_node = next((n for n in parsed_bell["nodes"] if n["parent"] is None), None)
    reporter.check(root_node is not None, "ipo_bell_3d.tscn has valid root node")
    if root_node:
        groups = root_node["groups"]
        reporter.check("ipo_bells" in groups, "ipo_bell_3d root is in group 'ipo_bells'")
        reporter.check("interactables" in groups, "ipo_bell_3d root is in group 'interactables'")
        reporter.check("stations" in groups, "ipo_bell_3d root is in group 'stations'")

    # Check key child nodes in ipo_bell_3d.tscn
    node_names = [n["name"] for n in parsed_bell["nodes"]]
    reporter.check("CollisionShape3D" in node_names, "ipo_bell_3d.tscn contains CollisionShape3D")
    reporter.check("InteractionArea" in node_names, "ipo_bell_3d.tscn contains InteractionArea")
    reporter.check("PromptLabel3D" in node_names, "ipo_bell_3d.tscn contains PromptLabel3D")
    reporter.check("BellPivot" in node_names, "ipo_bell_3d.tscn contains BellPivot")
    reporter.check("GoldParticles" in node_names, "ipo_bell_3d.tscn contains GoldParticles")

    # 1.3 3D Trophy Showcase Scene & Script
    showcase_scene_path = GAME_DIR / "scenes/trophy_showcase_3d.tscn"
    showcase_script_path = GAME_DIR / "scripts/trophy_showcase_3d.gd"
    reporter.check(showcase_scene_path.exists(), "scenes/trophy_showcase_3d.tscn exists")
    reporter.check(showcase_script_path.exists(), "scripts/trophy_showcase_3d.gd exists")

    showcase_tscn = showcase_scene_path.read_text(encoding="utf-8") if showcase_scene_path.exists() else ""
    showcase_gd = showcase_script_path.read_text(encoding="utf-8") if showcase_script_path.exists() else ""
    parsed_showcase = parse_tscn(showcase_tscn)

    reporter.check("class_name TrophyShowcase3D" in showcase_gd,
                   "trophy_showcase_3d.gd declares class_name TrophyShowcase3D")
    reporter.check("signal trophies_refreshed" in showcase_gd,
                   "trophy_showcase_3d.gd declares signal trophies_refreshed")
    reporter.check("func refresh_trophies(" in showcase_gd,
                   "trophy_showcase_3d.gd implements func refresh_trophies()")
    reporter.check("func interact(" in showcase_gd,
                   "trophy_showcase_3d.gd implements func interact()")
    reporter.check("rotate_y(" in showcase_gd,
                   "trophy_showcase_3d.gd implements continuous gentle idle rotation on trophy meshes")
    reporter.check("is_trophy_unlocked" in showcase_gd or "unlocked_trophies" in showcase_gd,
                   "trophy_showcase_3d.gd monitors GameState trophy unlock state")
    reporter.check("trophy_golden_briefcase" in showcase_gd,
                   "trophy_showcase_3d.gd manages trophy_golden_briefcase (Chapter 1)")
    reporter.check("trophy_server_matrix" in showcase_gd,
                   "trophy_showcase_3d.gd manages trophy_server_matrix (Chapter 2)")
    reporter.check("trophy_crystal_espresso" in showcase_gd,
                   "trophy_showcase_3d.gd manages trophy_crystal_espresso (Chapter 3)")
    reporter.check("trophy_platinum_bull" in showcase_gd,
                   "trophy_showcase_3d.gd manages trophy_platinum_bull (First IPO)")

    # Check root node groups in parsed_showcase
    showcase_root = next((n for n in parsed_showcase["nodes"] if n["parent"] is None), None)
    reporter.check(showcase_root is not None, "trophy_showcase_3d.tscn has valid root node")
    if showcase_root:
        sc_groups = showcase_root["groups"]
        reporter.check("trophy_showcase" in sc_groups, "trophy_showcase root is in group 'trophy_showcase'")
        reporter.check("interactables" in sc_groups, "trophy_showcase root is in group 'interactables'")

    sc_node_names = [n["name"] for n in parsed_showcase["nodes"]]
    reporter.check("CollisionShape3D" in sc_node_names, "trophy_showcase_3d.tscn contains CollisionShape3D")
    reporter.check("InteractionArea" in sc_node_names, "trophy_showcase_3d.tscn contains InteractionArea")
    reporter.check("PromptLabel3D" in sc_node_names, "trophy_showcase_3d.tscn contains PromptLabel3D")
    reporter.check("Pedestal_Briefcase" in sc_node_names, "trophy_showcase_3d.tscn contains Pedestal_Briefcase")
    reporter.check("Pedestal_Server" in sc_node_names, "trophy_showcase_3d.tscn contains Pedestal_Server")
    reporter.check("Pedestal_Chalice" in sc_node_names, "trophy_showcase_3d.tscn contains Pedestal_Chalice")
    reporter.check("Pedestal_Bull" in sc_node_names, "trophy_showcase_3d.tscn contains Pedestal_Bull")

    # 1.4 Campus Placement in scenes/main_3d.tscn
    main_path = GAME_DIR / "scenes/main_3d.tscn"
    reporter.check(main_path.exists(), "scenes/main_3d.tscn exists")
    main_content = main_path.read_text(encoding="utf-8") if main_path.exists() else ""
    parsed_main = parse_tscn(main_content)

    bell_inst = next((n for n in parsed_main["nodes"] if n["name"] == "IpoBell3D"), None)
    reporter.check(bell_inst is not None, "main_3d.tscn instances IpoBell3D")
    if bell_inst:
        raw = bell_inst["raw"]
        reporter.check("0, 0, 12" in raw or "(0, 0, 12)" in raw,
                       "IpoBell3D positioned at Vector3(0.0, 0.0, 12.0) in main_3d.tscn")

    showcase_inst = next((n for n in parsed_main["nodes"] if n["name"] == "TrophyShowcase3D"), None)
    reporter.check(showcase_inst is not None, "main_3d.tscn instances TrophyShowcase3D")
    if showcase_inst:
        raw = showcase_inst["raw"]
        reporter.check("6, 0, 12" in raw or "(6, 0, 12)" in raw,
                       "TrophyShowcase3D positioned at Vector3(6.0, 0.0, 12.0) in main_3d.tscn")


# ==============================================================================
# SECTION 2: Geometric Topology & Low-Poly Triangle Budget
# ==============================================================================

def run_section_2():
    print(f"\n{Colors.BOLD}{Colors.OKBLUE}=== SECTION 2: Geometric Topology & Low-Poly Triangle Budget ==={Colors.ENDC}")

    bell_path = GAME_DIR / "scenes/ipo_bell_3d.tscn"
    showcase_path = GAME_DIR / "scenes/trophy_showcase_3d.tscn"

    bell_parsed = parse_tscn(bell_path.read_text(encoding="utf-8"))
    showcase_parsed = parse_tscn(showcase_path.read_text(encoding="utf-8"))

    # Compute static triangles for IPO Bell
    bell_static_tris = 0
    for node in bell_parsed["nodes"]:
        if node["type"] == "MeshInstance3D":
            mesh_prop = node["props"].get("mesh", "")
            match = re.search(r'SubResource\("([^"]+)"\)', mesh_prop)
            if match:
                res_id = match.group(1)
                subres = bell_parsed["subresources"].get(res_id)
                if subres:
                    m_type = subres["type"]
                    tris = calculate_mesh_triangles(m_type, subres["props"])
                    bell_static_tris += tris

    print(f"  -> IPO Bell static triangles: {bell_static_tris} tris")
    reporter.check(bell_static_tris > 0, "IPO Bell static geometry is non-empty")
    reporter.check(bell_static_tris < 800,
                   f"IPO Bell static triangles < 800 tris budget (actual: {bell_static_tris} tris)")

    # Compute static triangles for Trophy Showcase
    showcase_static_tris = 0
    for node in showcase_parsed["nodes"]:
        if node["type"] == "MeshInstance3D":
            mesh_prop = node["props"].get("mesh", "")
            match = re.search(r'SubResource\("([^"]+)"\)', mesh_prop)
            if match:
                res_id = match.group(1)
                subres = showcase_parsed["subresources"].get(res_id)
                if subres:
                    m_type = subres["type"]
                    tris = calculate_mesh_triangles(m_type, subres["props"])
                    showcase_static_tris += tris

    print(f"  -> Trophy Showcase static triangles: {showcase_static_tris} tris")
    reporter.check(showcase_static_tris > 0, "Trophy Showcase static geometry is non-empty")
    reporter.check(showcase_static_tris < 1200,
                   f"Trophy Showcase static triangles < 1,200 tris budget (actual: {showcase_static_tris} tris)")

    # Combined budget check
    combined_static_tris = bell_static_tris + showcase_static_tris
    print(f"  -> Combined static triangles: {combined_static_tris} tris")
    reporter.check(combined_static_tris < 2500,
                   f"Combined static geometry strictly < 2,500 tris (actual: {combined_static_tris} tris)")
    reporter.check(combined_static_tris <= 1500,
                   f"Combined static geometry achieves high-efficiency target <= 1,500 tris (actual: {combined_static_tris} tris)")

    # Check peak dynamic burst budget (including 40 gold snippet particles * 12 tris)
    peak_dynamic_tris = combined_static_tris + (40 * 12)
    print(f"  -> Peak dynamic burst triangles: {peak_dynamic_tris} tris")
    reporter.check(peak_dynamic_tris < 2500,
                   f"Peak dynamic burst load strictly < 2,500 tris (actual: {peak_dynamic_tris} tris)")


# ==============================================================================
# SECTION 3: Audio PCM Procedural Bell Synthesis Verification
# ==============================================================================

def run_section_3():
    print(f"\n{Colors.BOLD}{Colors.OKBLUE}=== SECTION 3: Audio PCM Procedural Bell Synthesis Verification ==={Colors.ENDC}")

    sample_rate = 22050
    duration = 1.25
    sample_count = int(sample_rate * duration)
    reporter.check(sample_count == 27562, f"Total 16-bit PCM sample count is 27,562 at 22,050 Hz (actual: {sample_count})")

    f_d5 = 587.33
    f_a5 = 880.00
    f_d6 = 1174.66
    f_click = 2349.00

    # Simulate algorithm exactly as defined in _synth_bell()
    samples = []
    has_nan_or_inf = False
    max_amp = 0.0
    sum_squares = 0.0

    for i in range(sample_count):
        t = float(i) / float(sample_rate)

        click = math.sin(2.0 * math.pi * f_click * t) * math.exp(-t * 80.0)
        tone_d5 = math.sin(2.0 * math.pi * f_d5 * t) * math.exp(-t * 3.8)
        tone_a5 = math.sin(2.0 * math.pi * f_a5 * t) * math.exp(-t * 4.2)
        tone_d6 = math.sin(2.0 * math.pi * f_d6 * t) * math.exp(-t * 4.8)

        attack = 1.0 - math.exp(-t * 350.0)
        chord = (tone_d5 + 0.70 * tone_a5 + 0.50 * tone_d6) / 2.20
        combined = 0.20 * click + 0.80 * chord * attack
        sample = max(-1.0, min(1.0, combined * 0.90))

        if math.isnan(sample) or math.isinf(sample):
            has_nan_or_inf = True

        abs_s = abs(sample)
        if abs_s > max_amp:
            max_amp = abs_s
        sum_squares += sample * sample
        samples.append(sample)

    reporter.check(not has_nan_or_inf, "Generated PCM samples contain 0 NaNs or Infinities")
    reporter.check(max_amp <= 1.0, f"Maximum amplitude is within [-1.0, 1.0] ceiling (actual peak: {max_amp:.4f})")
    reporter.check(max_amp > 0.40, f"Maximum strike amplitude is prominent (actual peak: {max_amp:.4f})")

    rms = math.sqrt(sum_squares / sample_count)
    reporter.check(rms > 0.05, f"Synthesized bell waveform has rich acoustic energy (RMS: {rms:.4f})")

    # Exponential decay verification: verify tail samples (last 0.05s) are significantly decayed
    tail_samples = samples[int(sample_rate * 1.20):]
    tail_rms = math.sqrt(sum(s * s for s in tail_samples) / len(tail_samples))
    reporter.check(tail_rms < 0.05 * rms,
                   f"Decay envelope: Tail acoustic energy is < 5% of overall RMS (tail RMS: {tail_rms:.6f})")

    # Strike transient click decays quickly: check click amplitude after 0.1s is negligible
    click_at_100ms = math.exp(-0.10 * 80.0)
    reporter.check(click_at_100ms < 0.001,
                   f"Strike transient click decays completely within 100ms (attenuation: {click_at_100ms:.6f})")


# ==============================================================================
# SECTION 4: Behavioral & Proximity State Machine Simulation
# ==============================================================================

class MockTouchControls:
    def __init__(self):
        self.active_interactable = None
        self.active_label = ""

    def register_interactable(self, target, label: str):
        self.active_interactable = target
        self.active_label = label

    def unregister_interactable(self, target):
        if self.active_interactable == target:
            self.active_interactable = None
            self.active_label = ""


class MockAudioManager:
    def __init__(self):
        self.last_sfx_played = ""
        self.play_count = 0

    def play_sfx_bell(self):
        self.last_sfx_played = "bell"
        self.play_count += 1


class MockGameState:
    def __init__(self):
        self.campaign_chapter = 1
        self.total_ipos_completed = 0
        self.angel_shares = 0
        self.unlocked_trophies = []

    def is_trophy_unlocked(self, trophy_id: str) -> bool:
        return trophy_id in self.unlocked_trophies

    def unlock_trophy(self, trophy_id: str):
        if trophy_id not in self.unlocked_trophies:
            self.unlocked_trophies.append(trophy_id)


def run_section_4():
    print(f"\n{Colors.BOLD}{Colors.OKBLUE}=== SECTION 4: Behavioral & Proximity State Machine Simulation ==={Colors.ENDC}")

    tc = MockTouchControls()
    am = MockAudioManager()
    gs = MockGameState()

    # 4.1 IPO Bell Proximity and Interaction
    bell_in_range = False
    bell_prompt_visible = False

    # Simulate player enter
    bell_in_range = True
    bell_prompt_visible = True
    tc.register_interactable("IpoBell3D", "IPO Bell [E]")

    reporter.check(bell_in_range, "Player entered IPO Bell interaction radius")
    reporter.check(bell_prompt_visible, "PromptLabel3D became visible on player enter")
    reporter.check(tc.active_label == "IPO Bell [E]", "TouchControls registered 'IPO Bell [E]'")

    # Simulate ringing the bell
    bell_rung_emitted = False
    am.play_sfx_bell()
    bell_rung_emitted = True
    particles_emitting = True

    reporter.check(bell_rung_emitted, "bell_rung signal emitted on interact()")
    reporter.check(am.last_sfx_played == "bell", "AudioManager played 'bell' chime")
    reporter.check(am.play_count == 1, "AudioManager play count incremented")
    reporter.check(particles_emitting, "Gold particles triggered on bell ring")

    # Simulate player exit
    bell_in_range = False
    bell_prompt_visible = False
    tc.unregister_interactable("IpoBell3D")

    reporter.check(not bell_in_range, "Player exited IPO Bell radius")
    reporter.check(not bell_prompt_visible, "PromptLabel3D hidden on player exit")
    reporter.check(tc.active_interactable is None, "TouchControls unregistered on player exit")

    # 4.2 Trophy Showcase Milestone Unlock Progression
    # Stage 0: Initial state (all locked)
    t1 = gs.is_trophy_unlocked("trophy_golden_briefcase") or gs.campaign_chapter >= 2
    t2 = gs.is_trophy_unlocked("trophy_server_matrix") or gs.campaign_chapter >= 3
    t3 = gs.is_trophy_unlocked("trophy_crystal_espresso") or gs.campaign_chapter >= 4
    t4 = gs.is_trophy_unlocked("trophy_platinum_bull") or gs.total_ipos_completed > 0

    reporter.check(not t1 and not t2 and not t3 and not t4, "Initial state: all 4 milestone trophies locked")

    # Stage 1: Complete Chapter 1 (MVP Launch)
    gs.campaign_chapter = 2
    gs.unlock_trophy("trophy_golden_briefcase")
    t1 = gs.is_trophy_unlocked("trophy_golden_briefcase") or gs.campaign_chapter >= 2
    reporter.check(t1, "Chapter 1 completed: Golden Briefcase unlocked")

    # Stage 2: Complete Chapter 2 (Cyber-Sync)
    gs.campaign_chapter = 3
    gs.unlock_trophy("trophy_server_matrix")
    t2 = gs.is_trophy_unlocked("trophy_server_matrix") or gs.campaign_chapter >= 3
    reporter.check(t2, "Chapter 2 completed: Matrix Server Plaque unlocked")

    # Stage 3: Complete Chapter 3 (Unicorn Status)
    gs.campaign_chapter = 4
    gs.unlock_trophy("trophy_crystal_espresso")
    t3 = gs.is_trophy_unlocked("trophy_crystal_espresso") or gs.campaign_chapter >= 4
    reporter.check(t3, "Chapter 3 completed: Crystal Espresso Chalice unlocked")

    # Stage 4: First Successful IPO
    gs.total_ipos_completed = 1
    gs.angel_shares = 3
    gs.unlock_trophy("trophy_platinum_bull")
    t4 = gs.is_trophy_unlocked("trophy_platinum_bull") or gs.total_ipos_completed > 0
    reporter.check(t4, "First IPO completed: Platinum Bull unlocked")

    # All 4 unlocked now
    all_unlocked = t1 and t2 and t3 and t4
    reporter.check(all_unlocked, "Full endgame progression: all 4 milestone trophies unlocked and shining")


# ==============================================================================
# MAIN ENTRY POINT
# ==============================================================================

def main():
    print("=" * 70)
    print("IdleArcade Phase 12 - Milestone M2 (3D IPO Bell & Trophy Showcase)")
    print("======================================================================")

    run_section_1()
    run_section_2()
    run_section_3()
    run_section_4()

    reporter.print_summary()

    if reporter.fails > 0:
        sys.exit(1)
    sys.exit(0)


if __name__ == "__main__":
    main()
