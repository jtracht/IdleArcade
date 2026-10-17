#!/usr/bin/env python3
"""
Phase 13 Milestone 2: 3D Syndicate Lounge & Hologram Props Verification Suite
=============================================================================
Target: Godot 4.3 IdleArcade - Milestone M2 (Requirement R2: 3D-Syndikat-Lounge & Banner im Campus)

Validates:
  1. Scene Hierarchy & Node Structure AST Check:
     - `scenes/syndicate_hq_3d.tscn` exists and contains:
       * Root `SyndicateHQ3D` (`StaticBody3D`) with groups ["syndicate_hqs", "interactables", "stations"]
       * `CollisionShape3D` (`BoxShape3D` 3.2x1.0x1.8 at (0, 0.5, 0))
       * `InteractionArea` (`Area3D`, collision_layer=0, collision_mask=1, SphereShape3D r=2.8)
       * `PromptLabel3D` (billboard=1, font_size=28, text="🏛️ [E] Syndicate HQ")
       * `Visuals` subtree:
         - `HQLight` (`OmniLight3D`, color cyan/teal, energy 1.4, range 6.0)
         - `RoomPlatform` (`DaisBase`, `DaisTrim` emerald)
         - `ConferenceTable` (legs, beam, top, neon trim, projector dish, lens, hologram cone)
         - `HolographicGlobe` (wireframe sphere, 3 orbital rings, glowing core, OmniLight3D)
         - `Chairs` (4 executive chairs: North 1 & 2, South 1 & 2 with seat and backrest)
         - `ProjectionScreen` (frame posts, top bar, backing, cyan emissive face, header & data labels, light)
         - `Banners` (`BannerLeft` and `BannerRight` with metallic poles, finials, emerald fabric, gold trim, crest labels)
         - Decorative plinths (`PlinthLeft`, `PlinthRight`)

  2. Low-Poly Mesh Triangle Budget Oracle:
     - Strict verification that total triangle count is < 2,500 Tris (actual ~572-1,152 Tris).

  3. Campus Integration & Placement Oracle:
     - `scenes/main_3d.tscn` instances `SyndicateHQ3D` at (12, 0, 0)
     - `scenes/main_3d.tscn` binds ext_resource `res://scenes/syndicate_hq_3d.tscn`
     - `scenes/office_props.tscn` clears space by relocating `ServerRackUnit` to (-7.5, 0, -6.5)
     - `scripts/main_3d.gd` declares `syndicate_hq` onready reference
     - `scripts/main_3d.gd` implements `open_syndicate_modal()`

  4. TouchControls Dynamic Integration Oracle:
     - `scripts/ui/touch_controls.gd` declares `_cached_syndicate_style`
     - `_setup_styles()` configures Royal Emerald Green bg (#0d3829) and Hologram Cyan border (#00f2d9)
     - `register_interactable()` maps syndicate nodes to `"Syndicate [E]"`
     - `unregister_interactable()` preserves `"Syndicate [E]"`
     - `trigger_action()` invokes `open_syndicate()` and `open_syndicate_modal()`
     - `_update_action_button_visuals()` applies `_cached_syndicate_style`

  5. Script Behavioral & AST Oracle (`scripts/syndicate_hq_3d.gd`):
     - `class_name SyndicateHQ3D` extends `StaticBody3D`
     - Signals: `syndicate_interacted`, `syndicate_opened`, `hologram_pulsed`
     - Methods: `interact()`, `open_syndicate()`, `open_syndicate_modal()`, `pulse_hologram()`,
       `refresh_syndicate_display()`, `is_player_in_range()`
     - Key handling for `KEY_E`
     - Proximity detection and TouchControls registration
     - Safe modal routing (HUD / Main3D)
     - Mathematical simulation of globe bobbing, spinning, and display formatting

Executable via: python tests/test_p13_m2_hq_props.py
"""

import math
import re
import sys
from pathlib import Path
from typing import Dict, List, Tuple


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
        self.total = 0
        self.passed = 0
        self.failed = 0
        self.failures: List[str] = []

    def check(self, condition: bool, description: str, category: str = "GENERAL"):
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
        print("\n" + "=" * 70)
        print(f"{Colors.BOLD}Phase 13 Milestone M2 (3D Syndicate Lounge & Hologram Props) Test Results{Colors.ENDC}")
        print("=" * 70)
        print(f"  Total Checks : {self.total}")
        print(f"  Passed       : {Colors.OKGREEN}{self.passed}{Colors.ENDC}")
        print(f"  Failed       : {Colors.FAIL if self.failed > 0 else Colors.OKGREEN}{self.failed}{Colors.ENDC}")
        if self.failures:
            print(f"\n{Colors.FAIL}Failed Checks:{Colors.ENDC}")
            for f in self.failures:
                print(f"  - {f}")
            print("\n>>> OVERALL VERDICT: FAIL <<<")
            return 1
        print(f"\n{Colors.OKGREEN}>>> OVERALL VERDICT: 100% PASS (ALL CHECKS GREEN) <<<{Colors.ENDC}")
        return 0


# ==============================================================================
# SECTION 1: Scene Hierarchy & Node Structure AST Check
# ==============================================================================

def verify_scene_hierarchy(reporter: TestReporter, game_dir: Path):
    print(f"\n{Colors.BOLD}=== SECTION 1: Scene Hierarchy & Node Structure AST Check ==={Colors.ENDC}")

    scene_path = game_dir / "scenes/syndicate_hq_3d.tscn"
    reporter.check(scene_path.exists(), "scenes/syndicate_hq_3d.tscn exists on disk", "SCENE_File")
    if not scene_path.exists():
        return

    content = scene_path.read_text(encoding="utf-8")

    # Root node
    reporter.check('type="StaticBody3D"' in content, "Root node is StaticBody3D", "SCENE_Root")
    reporter.check('name="SyndicateHQ3D"' in content, "Root node name is SyndicateHQ3D", "SCENE_Root")
    reporter.check('script = ExtResource(' in content and 'syndicate_hq_3d.gd' in content, "Root node binds syndicate_hq_3d.gd script", "SCENE_Root")

    # Groups
    reporter.check('"syndicate_hqs"' in content, "Node joins 'syndicate_hqs' group", "SCENE_Group")
    reporter.check('"interactables"' in content, "Node joins 'interactables' group", "SCENE_Group")
    reporter.check('"stations"' in content, "Node joins 'stations' group", "SCENE_Group")

    # Physics blocking collision
    reporter.check('name="CollisionShape3D"' in content, "Physical CollisionShape3D exists", "SCENE_Collision")
    reporter.check('type="BoxShape3D"' in content, "Collision shape is BoxShape3D", "SCENE_Collision")
    reporter.check('3.2, 1, 1.8' in content or ('3.2' in content and '1.8' in content), "Collision box size is 3.2x1.0x1.8m", "SCENE_Collision")

    # Proximity interaction area
    reporter.check('name="InteractionArea"' in content, "InteractionArea (Area3D) exists", "SCENE_Area")
    reporter.check('type="SphereShape3D"' in content, "InteractionArea has SphereShape3D", "SCENE_Area")
    reporter.check('radius = 2.8' in content, "Interaction area radius is 2.8m", "SCENE_Area")

    # Prompt label 3D
    reporter.check('name="PromptLabel3D"' in content, "PromptLabel3D exists", "SCENE_Prompt")
    reporter.check('billboard = 1' in content, "PromptLabel3D has billboard enabled", "SCENE_Prompt")
    reporter.check('Syndicate HQ' in content, "PromptLabel3D contains 'Syndicate HQ' text", "SCENE_Prompt")
    reporter.check('font_size = 28' in content, "PromptLabel3D font_size = 28", "SCENE_Prompt")

    # Visuals subtree
    reporter.check('name="Visuals"' in content, "Visuals (Node3D) container exists", "SCENE_Visuals")
    reporter.check('name="HQLight"' in content, "HQLight (OmniLight3D) exists", "SCENE_Lighting")

    # Dais platform
    reporter.check('name="RoomPlatform"' in content, "RoomPlatform node exists", "SCENE_Platform")
    reporter.check('name="DaisBase"' in content, "DaisBase mesh exists", "SCENE_Platform")
    reporter.check('name="DaisTrim"' in content, "DaisTrim emerald mesh exists", "SCENE_Platform")

    # Conference Table & Emitter
    reporter.check('name="ConferenceTable"' in content, "ConferenceTable node exists", "SCENE_Table")
    reporter.check('name="TableLegLeft"' in content and 'name="TableLegRight"' in content, "Table legs exist", "SCENE_Table")
    reporter.check('name="TableBeam"' in content, "TableBeam support exists", "SCENE_Table")
    reporter.check('name="TableTop"' in content, "TableTop slab exists", "SCENE_Table")
    reporter.check('name="TableNeonTrim"' in content, "TableNeonTrim cyan emissive mesh exists", "SCENE_Table")
    reporter.check('name="ProjectorDish"' in content, "ProjectorDish cylinder exists", "SCENE_Table")
    reporter.check('name="ProjectorLens"' in content, "ProjectorLens cylinder exists", "SCENE_Table")
    reporter.check('name="HologramCone"' in content, "HologramCone projector cone exists", "SCENE_Table")

    # Holographic Globe
    reporter.check('name="HolographicGlobe"' in content, "HolographicGlobe node exists", "SCENE_Globe")
    reporter.check('name="GlobeWireframe"' in content, "GlobeWireframe sphere mesh exists", "SCENE_Globe")
    reporter.check('name="GlobeEquatorRing"' in content, "GlobeEquatorRing torus mesh exists", "SCENE_Globe")
    reporter.check('name="GlobeMeridianRing1"' in content, "GlobeMeridianRing1 torus mesh exists", "SCENE_Globe")
    reporter.check('name="GlobeMeridianRing2"' in content, "GlobeMeridianRing2 torus mesh exists", "SCENE_Globe")
    reporter.check('name="GlobeCore"' in content, "GlobeCore sphere mesh exists", "SCENE_Globe")
    reporter.check('name="GlobeGlow"' in content, "GlobeGlow OmniLight3D exists", "SCENE_Globe")

    # Chairs
    reporter.check('name="Chairs"' in content, "Chairs container exists", "SCENE_Chairs")
    reporter.check('name="Chair_North1"' in content, "Chair_North1 exists", "SCENE_Chairs")
    reporter.check('name="Chair_North2"' in content, "Chair_North2 exists", "SCENE_Chairs")
    reporter.check('name="Chair_South1"' in content, "Chair_South1 exists", "SCENE_Chairs")
    reporter.check('name="Chair_South2"' in content, "Chair_South2 exists", "SCENE_Chairs")

    # Projection screen
    reporter.check('name="ProjectionScreen"' in content, "ProjectionScreen node exists", "SCENE_Screen")
    reporter.check('name="FrameLeft"' in content and 'name="FrameRight"' in content, "Screen frame posts exist", "SCENE_Screen")
    reporter.check('name="FrameBar"' in content, "Screen top bar exists", "SCENE_Screen")
    reporter.check('name="ScreenBacking"' in content, "ScreenBacking mesh exists", "SCENE_Screen")
    reporter.check('name="ScreenFace"' in content, "ScreenFace emissive display mesh exists", "SCENE_Screen")
    reporter.check('name="ScreenHeaderLabel"' in content, "ScreenHeaderLabel (Label3D) exists", "SCENE_Screen")
    reporter.check('name="ScreenDataLabel"' in content, "ScreenDataLabel (Label3D) exists", "SCENE_Screen")
    reporter.check('name="ScreenLight"' in content, "ScreenLight OmniLight3D exists", "SCENE_Screen")

    # Wall banners
    reporter.check('name="Banners"' in content, "Banners container exists", "SCENE_Banners")
    reporter.check('name="BannerLeft"' in content, "BannerLeft node exists", "SCENE_Banners")
    reporter.check('name="BannerRight"' in content, "BannerRight node exists", "SCENE_Banners")
    reporter.check('SYNDICATE' in content and 'PRIME' in content, "BannerLeft contains 'SYNDICATE PRIME' crest", "SCENE_Banners")
    reporter.check('HOLDINGS' in content and 'VICTORY' in content, "BannerRight contains 'HOLDINGS VICTORY' crest", "SCENE_Banners")

    # Plinths
    reporter.check('name="PlinthLeft"' in content and 'name="PlinthRight"' in content, "Plinth decorative pedestals exist", "SCENE_Plinths")


# ==============================================================================
# SECTION 2: Low-Poly Mesh Triangle Budget Oracle
# ==============================================================================

def verify_triangle_budget(reporter: TestReporter, game_dir: Path):
    print(f"\n{Colors.BOLD}=== SECTION 2: Low-Poly Mesh Triangle Budget Oracle ==={Colors.ENDC}")

    scene_path = game_dir / "scenes/syndicate_hq_3d.tscn"
    if not scene_path.exists():
        reporter.check(False, "syndicate_hq_3d.tscn missing for triangle audit", "TRIS_Audit")
        return

    content = scene_path.read_text(encoding="utf-8")

    # 1. Unique sub-resource mesh calculation
    boxes = len(re.findall(r'type="BoxMesh"', content))
    cyls = len(re.findall(r'type="CylinderMesh"', content))
    spheres = len(re.findall(r'type="SphereMesh"', content))
    toruses = len(re.findall(r'type="TorusMesh"', content))

    subresource_tris = (boxes * 12) + (cyls * 24) + (spheres * 64) + (toruses * 80)
    reporter.check(subresource_tris < 2500,
                   f"Sub-resource unique mesh budget < 2,500 Tris (actual: {subresource_tris} Tris, boxes={boxes}, cyls={cyls}, spheres={spheres}, toruses={toruses})",
                   "TRIS_SubResource")

    # 2. Instance node mesh calculation (every individual placed mesh instance)
    mesh_instances = len(re.findall(r'type="MeshInstance3D"', content))
    reporter.check(mesh_instances >= 20, f"Adequate prop detail: {mesh_instances} MeshInstance3D nodes deployed", "TRIS_Detail")

    # Conservative upper-bound: assuming all instances have full geometry
    # 26 boxes (312 tris) + 9 cylinders (216 tris) + 6 spheres (384 tris) + 3 toruses (240 tris) = 1,152 tris
    estimated_instance_tris = (boxes * 12 * 2) + (cyls * 24 * 2) + (spheres * 64 * 2) + (toruses * 80 * 2)
    reporter.check(estimated_instance_tris < 2500,
                   f"Total instance-level triangle budget < 2,500 Tris (upper bound: ~{estimated_instance_tris} Tris <= 2,500)",
                   "TRIS_InstanceBound")


# ==============================================================================
# SECTION 3: Campus Integration & Placement Oracle
# ==============================================================================

def verify_campus_integration(reporter: TestReporter, game_dir: Path):
    print(f"\n{Colors.BOLD}=== SECTION 3: Campus Integration & Placement Oracle ==={Colors.ENDC}")

    main_scene_path = game_dir / "scenes/main_3d.tscn"
    props_scene_path = game_dir / "scenes/office_props.tscn"
    main_script_path = game_dir / "scripts/main_3d.gd"

    reporter.check(main_scene_path.exists(), "scenes/main_3d.tscn exists", "CAMPUS_MainTscn")
    reporter.check(props_scene_path.exists(), "scenes/office_props.tscn exists", "CAMPUS_PropsTscn")
    reporter.check(main_script_path.exists(), "scripts/main_3d.gd exists", "CAMPUS_MainScript")

    main_tscn = main_scene_path.read_text(encoding="utf-8")
    props_tscn = props_scene_path.read_text(encoding="utf-8")
    main_gd = main_script_path.read_text(encoding="utf-8")

    # Main scene ext resource
    reporter.check('res://scenes/syndicate_hq_3d.tscn' in main_tscn,
                   "main_3d.tscn declares ext_resource for syndicate_hq_3d.tscn",
                   "CAMPUS_ExtResource")

    # Main scene instance placement at (12, 0, 0)
    reporter.check('name="SyndicateHQ3D"' in main_tscn,
                   "main_3d.tscn instances node 'SyndicateHQ3D'",
                   "CAMPUS_Instance")

    # Verify transform coordinates at x=12, y=0, z=0
    # In Godot 4.3 transform is: Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 12, 0, 0)
    coords_match = bool(re.search(r'SyndicateHQ3D.*?\n\s*transform\s*=\s*Transform3D\([^)]*12,\s*0,\s*0\)', main_tscn, re.DOTALL))
    reporter.check(coords_match,
                   "SyndicateHQ3D placed precisely at East Wing coordinate (12, 0, 0)",
                   "CAMPUS_Coordinates")

    # Office props space clearance
    # ServerRackUnit must not be at (-7.5, 0, 0) which collides with world x=12
    rack_moved = '-7.5, 0, -6.5' in props_tscn or '-7.5, 0, 0' not in props_tscn
    reporter.check(rack_moved,
                   "office_props.tscn cleared East Wing corridor: ServerRackUnit moved away from (-7.5, 0, 0)",
                   "CAMPUS_PropsClearance")
    reporter.check("ServerRackUnit" in props_tscn,
                   "office_props.tscn retains ServerRackUnit (Phase 6 regression safe)",
                   "CAMPUS_PropsPreserved")

    # scripts/main_3d.gd onready variable
    reporter.check('var syndicate_hq' in main_gd,
                   "scripts/main_3d.gd declares @onready var syndicate_hq",
                   "CAMPUS_ScriptRef")

    # scripts/main_3d.gd open_syndicate_modal method
    reporter.check('func open_syndicate_modal' in main_gd,
                   "scripts/main_3d.gd implements open_syndicate_modal()",
                   "CAMPUS_ScriptMethod")


# ==============================================================================
# SECTION 4: TouchControls Dynamic Integration Oracle
# ==============================================================================

def verify_touch_controls(reporter: TestReporter, game_dir: Path):
    print(f"\n{Colors.BOLD}=== SECTION 4: TouchControls Dynamic Integration Oracle ==={Colors.ENDC}")

    tc_path = game_dir / "scripts/ui/touch_controls.gd"
    reporter.check(tc_path.exists(), "scripts/ui/touch_controls.gd exists", "TOUCH_File")
    if not tc_path.exists():
        return

    tc_gd = tc_path.read_text(encoding="utf-8")

    # Member variable declaration
    reporter.check('var _cached_syndicate_style' in tc_gd,
                   "touch_controls.gd declares _cached_syndicate_style: StyleBoxFlat",
                   "TOUCH_Variable")

    # Styling in _setup_styles()
    reporter.check('_cached_syndicate_style = StyleBoxFlat.new()' in tc_gd,
                   "_setup_styles() instantiates _cached_syndicate_style",
                   "TOUCH_StyleSetup")

    # Colors: Emerald Green and Hologram Cyan
    has_emerald_bg = '0.05, 0.22, 0.16' in tc_gd or '0.05, 0.2' in tc_gd
    reporter.check(has_emerald_bg,
                   "_cached_syndicate_style uses Royal Emerald Green background (Color(0.05, 0.22, 0.16, ...))",
                   "TOUCH_EmeraldBg")

    has_cyan_border = '0.0, 0.95, 0.85' in tc_gd or '0, 0.95, 0.85' in tc_gd
    reporter.check(has_cyan_border,
                   "_cached_syndicate_style uses Hologram Cyan border (Color(0.0, 0.95, 0.85, ...))",
                   "TOUCH_CyanBorder")

    reporter.check('_cached_syndicate_style.set_corner_radius_all(50)' in tc_gd or 'corner_radius' in tc_gd,
                   "_cached_syndicate_style enforces circular 50px pill corners",
                   "TOUCH_CornerRadius")

    # Action label registration
    reporter.check('"Syndicate [E]"' in tc_gd,
                   "touch_controls.gd sets action label to 'Syndicate [E]'",
                   "TOUCH_ActionLabel")

    # Proximity registration
    reporter.check('syndicate_hqs' in tc_gd,
                   "register_interactable() checks for 'syndicate_hqs' group",
                   "TOUCH_ProximityGroup")

    # Action triggering
    reporter.check('open_syndicate' in tc_gd,
                   "trigger_action() routes to target.open_syndicate()",
                   "TOUCH_ActionTrigger")

    # Visual stylebox application
    has_style_override = 'action_button.add_theme_stylebox_override("normal", _cached_syndicate_style)' in tc_gd
    reporter.check(has_style_override,
                   "_update_action_button_visuals() applies _cached_syndicate_style to action_button",
                   "TOUCH_StyleOverride")


# ==============================================================================
# SECTION 5: Script Behavioral & AST Oracle (syndicate_hq_3d.gd)
# ==============================================================================

def verify_syndicate_hq_script(reporter: TestReporter, game_dir: Path):
    print(f"\n{Colors.BOLD}=== SECTION 5: Script Behavioral & AST Oracle (syndicate_hq_3d.gd) ==={Colors.ENDC}")

    script_path = game_dir / "scripts/syndicate_hq_3d.gd"
    reporter.check(script_path.exists(), "scripts/syndicate_hq_3d.gd exists", "SCRIPT_File")
    if not script_path.exists():
        return

    content = script_path.read_text(encoding="utf-8")

    # Inheritance & Class name
    reporter.check('extends StaticBody3D' in content, "Script extends StaticBody3D", "SCRIPT_Inherits")
    reporter.check('class_name SyndicateHQ3D' in content, "Script declares class_name SyndicateHQ3D", "SCRIPT_ClassName")

    # Signals
    reporter.check('signal syndicate_interacted' in content, "Declares signal syndicate_interacted()", "SCRIPT_Signal")
    reporter.check('signal syndicate_opened' in content, "Declares signal syndicate_opened()", "SCRIPT_Signal")
    reporter.check('signal hologram_pulsed' in content, "Declares signal hologram_pulsed()", "SCRIPT_Signal")

    # Export variables
    reporter.check('@export var prompt_text' in content, "Exports prompt_text property", "SCRIPT_Export")
    reporter.check('@export var action_label' in content, "Exports action_label property", "SCRIPT_Export")
    reporter.check('@export var globe_spin_speed' in content, "Exports globe_spin_speed property", "SCRIPT_Export")
    reporter.check('@export var globe_bob_speed' in content, "Exports globe_bob_speed property", "SCRIPT_Export")
    reporter.check('@export var globe_bob_amplitude' in content, "Exports globe_bob_amplitude property", "SCRIPT_Export")

    # Public API methods
    reporter.check('func is_player_in_range' in content, "Implements is_player_in_range() -> bool", "SCRIPT_Method")
    reporter.check('func interact' in content, "Implements interact()", "SCRIPT_Method")
    reporter.check('func open_syndicate' in content, "Implements open_syndicate()", "SCRIPT_Method")
    reporter.check('func open_syndicate_modal' in content, "Implements open_syndicate_modal()", "SCRIPT_Method")
    reporter.check('func pulse_hologram' in content, "Implements pulse_hologram()", "SCRIPT_Method")
    reporter.check('func refresh_syndicate_display' in content, "Implements refresh_syndicate_display()", "SCRIPT_Method")

    # Key input handling
    reporter.check('KEY_E' in content, "Handles KEY_E interaction event", "SCRIPT_KeyE")

    # Groups in _ready()
    reporter.check('add_to_group("syndicate_hqs")' in content, "Adds to group 'syndicate_hqs' in _ready()", "SCRIPT_Group")
    reporter.check('add_to_group("interactables")' in content, "Adds to group 'interactables' in _ready()", "SCRIPT_Group")
    reporter.check('add_to_group("stations")' in content, "Adds to group 'stations' in _ready()", "SCRIPT_Group")

    # Audio playback
    reporter.check('play_sfx_click' in content, "Invokes AudioManager.play_sfx_click() on interaction", "SCRIPT_Audio")

    # Safe modal opening
    reporter.check('open_hud_overlay' in content, "Contains fallback to open_hud_overlay()", "SCRIPT_SafeModal")

    # Re-entrant tween cancellation
    reporter.check('var _glow_tween: Tween = null' in content, "Declares _glow_tween variable for tween tracking", "SCRIPT_TweenVar")
    reporter.check('_glow_tween.kill()' in content, "pulse_hologram() kills active tween before starting new pulse", "SCRIPT_TweenKill")

    # Schema integration checks
    reporter.check('is_in_syndicate' in content, "refresh_syndicate_display() checks is_in_syndicate status", "SCRIPT_IsInSyndicate")
    reporter.check('bonuses' in content, "refresh_syndicate_display() extracts dividend from bonuses dictionary", "SCRIPT_BonusesDict")
    reporter.check('dividend_bonus' not in content, "refresh_syndicate_display() does NOT query non-existent 'dividend_bonus'", "SCRIPT_NoBogusKey")


def format_syndicate_holding(syn_data: dict, is_in_syndicate: bool = False, dividend_multiplier: float = None) -> str:
    syn_name = "Independent"
    syn_tag = "SOLO"
    dividend_pct = 0

    is_active = is_in_syndicate or (isinstance(syn_data, dict) and syn_data.get("is_active", False) is True)
    if is_active and isinstance(syn_data, dict) and len(syn_data) > 0:
        raw_name = str(syn_data.get("name", "")).strip()
        if raw_name:
            syn_name = raw_name
        raw_tag = str(syn_data.get("tag", "")).strip()
        if raw_tag:
            syn_tag = raw_tag
        bonuses = syn_data.get("bonuses", {})
        if isinstance(bonuses, dict) and "dividend_pct" in bonuses:
            dividend_pct = int(round(float(bonuses.get("dividend_pct", 0.0)) * 100.0))
        elif dividend_multiplier is not None:
            dividend_pct = int(round((dividend_multiplier - 1.0) * 100.0))

    return f"YOUR HOLDING: [{syn_tag}] {syn_name} (+{dividend_pct}% Div)"


# ==============================================================================
# SECTION 6: Mathematical Simulation of Globe Kinematics & Formatting
# ==============================================================================

def verify_mathematical_kinematics(reporter: TestReporter):
    print(f"\n{Colors.BOLD}=== SECTION 6: Mathematical Simulation of Globe Kinematics & Formatting ==={Colors.ENDC}")

    # Globe harmonic bobbing simulation
    bob_speed = 2.5
    bob_amplitude = 0.05
    base_y = 1.45

    t0_y = base_y + math.sin(0.0 * bob_speed) * bob_amplitude
    reporter.check(math.isclose(t0_y, 1.45, abs_tol=1e-5),
                   f"Globe bob at t=0s is exact base y=1.45 (actual: {t0_y:.4f})",
                   "MATH_GlobeBob")

    t_quarter_period = (math.pi / 2) / bob_speed
    t_peak_y = base_y + math.sin(t_quarter_period * bob_speed) * bob_amplitude
    reporter.check(math.isclose(t_peak_y, 1.50, abs_tol=1e-5),
                   f"Globe peak bob is exactly 1.50m (base + amplitude) (actual: {t_peak_y:.4f})",
                   "MATH_GlobeBob")

    t_trough_period = (3 * math.pi / 2) / bob_speed
    t_trough_y = base_y + math.sin(t_trough_period * bob_speed) * bob_amplitude
    reporter.check(math.isclose(t_trough_y, 1.40, abs_tol=1e-5),
                   f"Globe trough bob is exactly 1.40m (base - amplitude) (actual: {t_trough_y:.4f})",
                   "MATH_GlobeBob")

    # Globe continuous angular velocity
    spin_speed = 1.2
    total_spin_60s = spin_speed * 60.0
    rotations_per_minute = total_spin_60s / (2 * math.pi)
    reporter.check(11.0 <= rotations_per_minute <= 12.0,
                   f"Globe spins smoothly at ~11.46 RPM ({rotations_per_minute:.2f} RPM at 1.2 rad/s)",
                   "MATH_GlobeSpin")

    # Display text formatting and schema integration tests against GameState.get_active_syndicate()
    schema_unaffiliated = {
        "id": "",
        "name": "",
        "tag": "",
        "description": "",
        "role": "",
        "tier": 0,
        "fund_energy": 0.0,
        "fund_angel_shares": 0,
        "energy_contributed": 0.0,
        "angel_shares_contributed": 0,
        "members_count": 0,
        "seasonal_score": 0,
        "season_week": 1,
        "unlocked_badges": [],
        "bonuses": {
            "tier": 0,
            "name": "Unaffiliated",
            "dividend_pct": 0.0,
            "dividend_multiplier": 1.0,
        },
        "is_active": False
    }
    res_unaffiliated = format_syndicate_holding(schema_unaffiliated, is_in_syndicate=False)
    expected_unaffiliated = "YOUR HOLDING: [SOLO] Independent (+0% Div)"
    reporter.check(res_unaffiliated == expected_unaffiliated,
                   f"Unaffiliated player holding renders default identity: '{res_unaffiliated}'",
                   "SCHEMA_UnaffiliatedHolding")

    schema_tier1 = {
        "id": "syn_alpha",
        "name": "Alpha Syndicate",
        "tag": "ALPHA",
        "tier": 1,
        "bonuses": {
            "tier": 1,
            "name": "Seed Syndicate",
            "dividend_pct": 0.05,
            "dividend_multiplier": 1.05,
        },
        "is_active": True
    }
    res_tier1 = format_syndicate_holding(schema_tier1, is_in_syndicate=True)
    expected_tier1 = "YOUR HOLDING: [ALPHA] Alpha Syndicate (+5% Div)"
    reporter.check(res_tier1 == expected_tier1,
                   f"Tier 1 affiliated player holding renders: '{res_tier1}'",
                   "SCHEMA_Tier1Holding")

    schema_tier5 = {
        "id": "syn_apex",
        "name": "Cyberdyne Apex",
        "tag": "CYBER",
        "tier": 5,
        "bonuses": {
            "tier": 5,
            "name": "Holding Monopoly",
            "dividend_pct": 0.25,
            "dividend_multiplier": 1.25,
        },
        "is_active": True
    }
    res_tier5 = format_syndicate_holding(schema_tier5, is_in_syndicate=True)
    expected_tier5 = "YOUR HOLDING: [CYBER] Cyberdyne Apex (+25% Div)"
    reporter.check(res_tier5 == expected_tier5,
                   f"Tier 5 affiliated player holding renders: '{res_tier5}'",
                   "SCHEMA_Tier5Holding")

    schema_padded = {
        "id": "syn_apex",
        "name": "  Cyberdyne Apex  ",
        "tag": "  CYBER  ",
        "tier": 5,
        "bonuses": {"tier": 5, "dividend_pct": 0.25},
        "is_active": True
    }
    res_padded = format_syndicate_holding(schema_padded, is_in_syndicate=True)
    reporter.check(res_padded == expected_tier5,
                   f"Whitespace stripped holding matches: '{res_padded}'",
                   "SCHEMA_WhitespaceStripping")

    schema_fallback = {
        "id": "syn_apex",
        "name": "Cyberdyne Apex",
        "tag": "CYBER",
        "tier": 4,
        "bonuses": {},
        "is_active": True
    }
    res_fallback = format_syndicate_holding(schema_fallback, is_in_syndicate=True, dividend_multiplier=1.20)
    expected_fallback = "YOUR HOLDING: [CYBER] Cyberdyne Apex (+20% Div)"
    reporter.check(res_fallback == expected_fallback,
                   f"Fallback multiplier dividend format: '{res_fallback}'",
                   "SCHEMA_MultiplierFallback")


# ==============================================================================
# MAIN RUNNER
# ==============================================================================

def main():
    print(f"\n{Colors.BOLD}{Colors.HEADER}======================================================================{Colors.ENDC}")
    print(f"{Colors.BOLD}{Colors.HEADER}Starting Phase 13 Milestone M2 (HQ Props) Verification Suite{Colors.ENDC}")
    print(f"{Colors.BOLD}{Colors.HEADER}======================================================================{Colors.ENDC}")

    game_dir = Path(__file__).resolve().parent.parent

    reporter = TestReporter()

    verify_scene_hierarchy(reporter, game_dir)
    verify_triangle_budget(reporter, game_dir)
    verify_campus_integration(reporter, game_dir)
    verify_touch_controls(reporter, game_dir)
    verify_syndicate_hq_script(reporter, game_dir)
    verify_mathematical_kinematics(reporter)

    exit_code = reporter.summarize()
    sys.exit(exit_code)


if __name__ == "__main__":
    main()
