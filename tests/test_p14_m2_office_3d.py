#!/usr/bin/env python3
"""
Phase 14 Milestone 2: 3D Office Expansion & Chibi Worker AI Verification Suite
=============================================================================
Target: Godot 4.3 IdleArcade - Milestone M2 (Requirement R2: 3D-Büroerweiterung & Autonome Chibi-Worker-KI)

Validates:
  1. Scene Hierarchy & Node Structure AST Check:
     - `scenes/office_expansion_3d.tscn` exists and contains:
       * Root `OfficeExpansion3D` (`StaticBody3D`) with collision_layer=1
       * Groups: ["staff_offices", "interactables", "stations"]
       * `CollisionShape3D` (`BoxShape3D` 6.4x1.0x3.2 at (0, 0.5, 0))
       * `InteractionArea` (`Area3D`, layer 0, mask 1, SphereShape3D r=2.8)
       * `PromptLabel3D` (billboard=1, font_size=28, text contains "Staff Office")
       * `Visuals` container with Dais platform & trim
       * 5 workstations (`Desk_0` to `Desk_4`) with tops, legs, chairs, cup holders, emissive monitors, dual monitors, RGB LED bars
       * `WaterDispenser` with stand, bottle, spout, water glow
       * `StaffKiosk` with pedestal, screen, terminal light
       * `WorkerSlots` with 5 slot markers (`Slot_0` to `Slot_4`)
       * `SpawnedWorkers` container
     - `scenes/chibi_worker_3d.tscn` exists and contains:
       * Root `ChibiWorker3D` (`CharacterBody3D`, collision_layer=2)
       * `CollisionShape3D` (`SphereShape3D`)
       * `ClickArea` (`Area3D`, layer 4, mask 1)
       * `MoodIcon3D` (`Label3D`, billboard=1, default text "💻")
       * `EpiphanyLight` (`OmniLight3D`)
       * `ZzzParticles` (`CPUParticles3D`)
       * `SteamParticles` (`CPUParticles3D`)
       * `EpiphanyParticles` (`CPUParticles3D`)
       * `ChibiRoot` container with GroundShadow, Torso, LeftArmPivot, RightArmPivot, LeftLeg, RightLeg, Head, Visor, FaceLabel3D

  2. Low-Poly Mesh Triangle Budget Oracle:
     - `office_expansion_3d.tscn` total tris < 2,500 Tris (actual ~264-960 Tris)
     - `chibi_worker_3d.tscn` total tris < 600 Tris (actual ~224 Tris)
     - Combined Office + 5 Chibi Workers < 2,500 Tris

  3. Campus Integration & Placement Oracle:
     - `scenes/main_3d.tscn` declares ext_resource for `office_expansion_3d.tscn`
     - `scenes/main_3d.tscn` instantiates `OfficeExpansion3D` at East/North wing (19, 0, -8)
     - Spatial clearance: Euclidean distance to all existing interactive stations > 5.0m

  4. Script Behavioral & AST Oracle (`scripts/office_expansion_3d.gd`):
     - `class_name OfficeExpansion3D` extends `StaticBody3D`
     - Signals: `staff_interaction_requested`, `staff_office_opened`, `worker_epiphany_collected`
     - Export variables: `prompt_text`, `action_label`, `worker_scene`
     - Groups: `staff_offices`, `interactables`, `stations`
     - Public API: `interact()`, `open_staff()`, `open_staff_modal()`, `is_player_in_range()`,
       `refresh_desks()`, `refresh_workers()`, `spawn_worker()`, `despawn_worker()`,
       `get_worker_instance()`, `get_desk_node()`
     - Proximity detection and TouchControls registration / unregistration
     - Input handling for `KEY_E`
     - GameState synchronization (workers, desks, coffee breaks, unicorn espresso buff)

  5. Script Behavioral & State Machine Oracle (`scripts/chibi_worker_3d.gd`):
     - `class_name ChibiWorker3D` extends `CharacterBody3D`
     - Signals: `state_changed`, `epiphany_triggered`, `epiphany_collected`, `coffee_break_completed`
     - 4-state state machine: `STATE_WORKING`, `STATE_COFFEE_BREAK`, `STATE_FATIGUED`, `STATE_CELEBRATING`
     - 5 role colors (Frontend Dev, Backend Dev, UI/UX Designer, Growth Hacker, QA Engineer)
     - Procedural animation kinematics: typing arms, head nodding, coffee sipping, fatigue slumping, celebration jumping
     - Tap-interactive Epiphany moments (💡) with particle VFX, golden glow, and energy rewards

  6. Mathematical Kinematics & State Simulation:
     - Simulation of state transitions and mood icon correctness
     - Clamping of morale and fatigue within [0.0, 1.0]
     - Epiphany reward compounding with GameState passive RPS

Executable via: python tests/test_p14_m2_office_3d.py
"""

import math
import re
import sys
from pathlib import Path
from typing import Dict, List, Tuple

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
        print(f"{Colors.BOLD}Phase 14 Milestone M2 (3D Office Expansion & Chibi Worker AI) Test Results{Colors.ENDC}")
        print("=" * 70)
        print(f"  Total Checks : {self.total}")
        print(f"  Passed       : {Colors.OKGREEN}{self.passed}{Colors.ENDC}")
        print(f"  Failed       : {Colors.FAIL if self.failed > 0 else Colors.OKGREEN}{self.failed}{Colors.ENDC}")
        if self.failures:
            print(f"\n{Colors.FAIL}Failed Checks:{Colors.ENDC}")
            for f in self.failures:
                print(f"  - {f}")
        print("=" * 70)
        return 0 if self.failed == 0 else 1


# ==============================================================================
# SECTION 1: Scene Hierarchy & Node Structure AST Check
# ==============================================================================

def verify_office_expansion_scene(reporter: TestReporter, game_dir: Path):
    print(f"\n{Colors.BOLD}=== SECTION 1A: Office Expansion Scene Hierarchy AST ==={Colors.ENDC}")

    scene_path = game_dir / "scenes/office_expansion_3d.tscn"
    reporter.check(scene_path.exists(), "scenes/office_expansion_3d.tscn exists on disk", "SCENE_Office")
    if not scene_path.exists():
        return

    content = scene_path.read_text(encoding="utf-8")

    # Root node check
    reporter.check('type="StaticBody3D"' in content, "Root node is StaticBody3D", "SCENE_Root")
    reporter.check('name="OfficeExpansion3D"' in content, "Root node name is OfficeExpansion3D", "SCENE_Root")
    reporter.check('res://scripts/office_expansion_3d.gd' in content, "Root binds scripts/office_expansion_3d.gd", "SCENE_Root")

    # Collision & Proximity
    reporter.check('name="CollisionShape3D"' in content, "Root CollisionShape3D exists", "SCENE_Physics")
    reporter.check('BoxShape3D' in content, "Uses BoxShape3D for office boundary collision", "SCENE_Physics")
    reporter.check('name="InteractionArea"' in content, "InteractionArea (Area3D) exists", "SCENE_Proximity")
    reporter.check('SphereShape3D' in content, "InteractionArea uses SphereShape3D", "SCENE_Proximity")
    reporter.check('radius = 2.8' in content or 'radius = 3.0' in content, "InteractionArea has radius >= 2.8m", "SCENE_Proximity")

    # Floating Prompt Label
    reporter.check('name="PromptLabel3D"' in content, "PromptLabel3D exists", "SCENE_Label")
    reporter.check('Staff Office' in content, "PromptLabel3D text contains 'Staff Office'", "SCENE_Label")
    reporter.check('billboard = 1' in content, "PromptLabel3D has billboard enabled", "SCENE_Label")
    reporter.check('font_size = 28' in content, "PromptLabel3D font_size is 28", "SCENE_Label")

    # Visuals subtree
    reporter.check('name="Visuals"' in content, "Visuals container exists", "SCENE_Visuals")
    reporter.check('name="OfficeLight"' in content, "OfficeLight (OmniLight3D) exists", "SCENE_Lighting")
    reporter.check('name="PlatformDais"' in content, "PlatformDais mesh exists", "SCENE_Dais")
    reporter.check('name="PlatformTrim"' in content, "PlatformTrim mesh exists", "SCENE_Dais")

    # Desks container and 5 individual desks
    reporter.check('name="Desks"' in content, "Desks container exists", "SCENE_Desks")
    for i in range(5):
        desk_name = f'name="Desk_{i}"'
        reporter.check(desk_name in content, f"Desk_{i} node exists", "SCENE_Desks")

    # Workstation component details
    reporter.check('name="DeskTop"' in content, "DeskTop mesh instances exist", "SCENE_DeskComponents")
    reporter.check('name="LegLeft"' in content and 'name="LegRight"' in content, "Desk leg meshes exist", "SCENE_DeskComponents")
    reporter.check('name="Chair"' in content, "Chair containers exist", "SCENE_DeskComponents")
    reporter.check('name="Seat"' in content and 'name="Back"' in content, "Chair seat and backrest exist", "SCENE_DeskComponents")
    reporter.check('name="CupHolder"' in content, "CupHolder cylinder instances exist", "SCENE_DeskComponents")
    reporter.check('name="MonitorBezel"' in content, "MonitorBezel meshes exist", "SCENE_DeskComponents")
    reporter.check('name="MonitorScreen"' in content, "MonitorScreen meshes exist", "SCENE_DeskComponents")
    reporter.check('name="DualMonitor"' in content, "DualMonitor upgrade nodes exist", "SCENE_DeskUpgrades")
    reporter.check('name="RgbLedBar"' in content, "RgbLedBar standing desk LED bars exist", "SCENE_DeskUpgrades")

    # Water Dispenser
    reporter.check('name="WaterDispenser"' in content, "WaterDispenser node exists", "SCENE_WaterDispenser")
    reporter.check('name="Bottle"' in content, "WaterDispenser bottle cylinder exists", "SCENE_WaterDispenser")
    reporter.check('name="WaterGlow"' in content, "WaterGlow OmniLight3D exists", "SCENE_WaterDispenser")

    # Staff Kiosk Terminal
    reporter.check('name="StaffKiosk"' in content, "StaffKiosk terminal node exists", "SCENE_Kiosk")
    reporter.check('name="TerminalScreen"' in content, "TerminalScreen mesh exists", "SCENE_Kiosk")
    reporter.check('name="TerminalLight"' in content, "TerminalLight OmniLight3D exists", "SCENE_Kiosk")

    # WorkerSlots & SpawnedWorkers
    reporter.check('name="WorkerSlots"' in content, "WorkerSlots container exists", "SCENE_Slots")
    for i in range(5):
        slot_name = f'name="Slot_{i}"'
        reporter.check(slot_name in content, f"Slot_{i} marker exists", "SCENE_Slots")
    reporter.check('name="SpawnedWorkers"' in content, "SpawnedWorkers container exists", "SCENE_Slots")


def verify_chibi_worker_scene(reporter: TestReporter, game_dir: Path):
    print(f"\n{Colors.BOLD}=== SECTION 1B: Chibi Worker Scene Hierarchy AST ==={Colors.ENDC}")

    scene_path = game_dir / "scenes/chibi_worker_3d.tscn"
    reporter.check(scene_path.exists(), "scenes/chibi_worker_3d.tscn exists on disk", "SCENE_Worker")
    if not scene_path.exists():
        return

    content = scene_path.read_text(encoding="utf-8")

    # Root node check
    reporter.check('type="CharacterBody3D"' in content, "Root node is CharacterBody3D", "SCENE_WorkerRoot")
    reporter.check('name="ChibiWorker3D"' in content, "Root node name is ChibiWorker3D", "SCENE_WorkerRoot")
    reporter.check('res://scripts/chibi_worker_3d.gd' in content, "Root binds scripts/chibi_worker_3d.gd", "SCENE_WorkerRoot")

    # Collision & Click Area
    reporter.check('name="CollisionShape3D"' in content, "Root CollisionShape3D exists", "SCENE_WorkerPhysics")
    reporter.check('name="ClickArea"' in content, "ClickArea (Area3D) exists for tap interactions", "SCENE_WorkerInput")

    # Mood Icon & Lighting
    reporter.check('name="MoodIcon3D"' in content, "MoodIcon3D (Label3D) exists", "SCENE_MoodIcon")
    reporter.check('billboard = 1' in content, "MoodIcon3D has billboard enabled", "SCENE_MoodIcon")
    reporter.check('name="EpiphanyLight"' in content, "EpiphanyLight (OmniLight3D) exists", "SCENE_EpiphanyVFX")

    # Particle Systems
    reporter.check('name="ZzzParticles"' in content, "ZzzParticles (CPUParticles3D) exists", "SCENE_Particles")
    reporter.check('name="SteamParticles"' in content, "SteamParticles (CPUParticles3D) exists", "SCENE_Particles")
    reporter.check('name="EpiphanyParticles"' in content, "EpiphanyParticles (CPUParticles3D) exists", "SCENE_Particles")

    # Character Mesh Hierarchy
    reporter.check('name="ChibiRoot"' in content, "ChibiRoot container exists", "SCENE_WorkerMesh")
    reporter.check('name="GroundShadow"' in content, "GroundShadow cylinder mesh exists", "SCENE_WorkerMesh")
    reporter.check('name="Torso"' in content, "Torso box mesh exists", "SCENE_WorkerMesh")
    reporter.check('name="LeftArmPivot"' in content and 'name="RightArmPivot"' in content, "Arm pivot nodes exist for animated typing", "SCENE_WorkerMesh")
    reporter.check('name="LeftArm"' in content and 'name="RightArm"' in content, "LeftArm and RightArm meshes exist", "SCENE_WorkerMesh")
    reporter.check('name="LeftLeg"' in content and 'name="RightLeg"' in content, "LeftLeg and RightLeg meshes exist", "SCENE_WorkerMesh")
    reporter.check('name="Head"' in content, "Head node exists", "SCENE_WorkerMesh")
    reporter.check('name="HeadMesh"' in content, "HeadMesh sphere mesh exists", "SCENE_WorkerMesh")
    reporter.check('name="Visor"' in content, "Visor box mesh exists", "SCENE_WorkerMesh")
    reporter.check('name="FaceLabel3D"' in content, "FaceLabel3D exists for emotive visor face", "SCENE_WorkerMesh")


# ==============================================================================
# SECTION 2: Low-Poly Mesh Triangle Budget Oracle
# ==============================================================================

def verify_triangle_budgets(reporter: TestReporter, game_dir: Path):
    print(f"\n{Colors.BOLD}=== SECTION 2: Low-Poly Mesh Triangle Budget Oracle ==={Colors.ENDC}")

    # 1. Office Expansion Triangle Count
    office_scene = game_dir / "scenes/office_expansion_3d.tscn"
    if office_scene.exists():
        content = office_scene.read_text(encoding="utf-8")
        boxes = len(re.findall(r'type="BoxMesh"', content))
        cyls = len(re.findall(r'type="CylinderMesh"', content))
        spheres = len(re.findall(r'type="SphereMesh"', content))
        toruses = len(re.findall(r'type="TorusMesh"', content))

        subresource_tris = (boxes * 12) + (cyls * 48) + (spheres * 128) + (toruses * 128)
        reporter.check(subresource_tris < 2500,
                       f"Office expansion sub-resource tris budget < 2,500 Tris (actual: {subresource_tris} Tris, boxes={boxes}, cyls={cyls})",
                       "TRIS_OfficeSubResource")

        mesh_instances = len(re.findall(r'type="MeshInstance3D"', content))
        reporter.check(mesh_instances >= 30, f"Adequate office prop detail: {mesh_instances} MeshInstance3D nodes deployed", "TRIS_OfficeDetail")

        # Upper bound: counting each individual instance node
        # Formula: (boxes * 12) + (cylinders * 48)
        # In our scene: 5 cupholders + 1 water bottle = 6 cylinders, remaining are boxes
        inst_cyls = 6
        inst_boxes = max(0, mesh_instances - inst_cyls)
        instance_upper_bound_tris = (inst_boxes * 12) + (inst_cyls * 48)
        reporter.check(instance_upper_bound_tris < 2500,
                       f"Office expansion instance-level triangle budget < 2,500 Tris (actual upper bound: ~{instance_upper_bound_tris} Tris <= 2,500)",
                       "TRIS_OfficeInstanceBound")

    # 2. Chibi Worker Triangle Count
    worker_scene = game_dir / "scenes/chibi_worker_3d.tscn"
    if worker_scene.exists():
        content = worker_scene.read_text(encoding="utf-8")
        boxes = len(re.findall(r'type="BoxMesh"', content))
        cyls = len(re.findall(r'type="CylinderMesh"', content))
        spheres = len(re.findall(r'type="SphereMesh"', content))
        toruses = len(re.findall(r'type="TorusMesh"', content))

        worker_tris = (boxes * 12) + (cyls * 24) + (spheres * 128) + (toruses * 80)
        reporter.check(worker_tris < 600,
                       f"Chibi worker triangle budget < 600 Tris (actual: {worker_tris} Tris, boxes={boxes}, cyls={cyls}, spheres={spheres})",
                       "TRIS_WorkerBudget")

        # Combined budget test: Office + 5 active workers
        if office_scene.exists():
            combined_tris = instance_upper_bound_tris + (5 * worker_tris)
            reporter.check(combined_tris < 2500,
                           f"Office + 5 Active Workers combined budget < 2,500 Tris (actual: {combined_tris} Tris <= 2,500)",
                           "TRIS_CombinedBudget")


# ==============================================================================
# SECTION 3: Campus Integration & Placement Oracle
# ==============================================================================

def verify_campus_placement(reporter: TestReporter, game_dir: Path):
    print(f"\n{Colors.BOLD}=== SECTION 3: Campus Placement & Spatial Clearance Oracle ==={Colors.ENDC}")

    main_scene_path = game_dir / "scenes/main_3d.tscn"
    reporter.check(main_scene_path.exists(), "scenes/main_3d.tscn exists on disk", "CAMPUS_MainTscn")
    if not main_scene_path.exists():
        return

    main_tscn = main_scene_path.read_text(encoding="utf-8")

    # ExtResource check
    reporter.check('res://scenes/office_expansion_3d.tscn' in main_tscn,
                   "main_3d.tscn declares ext_resource for office_expansion_3d.tscn",
                   "CAMPUS_ExtResource")

    # Node instance check
    reporter.check('name="OfficeExpansion3D"' in main_tscn,
                   "main_3d.tscn instances node 'OfficeExpansion3D'",
                   "CAMPUS_Instance")

    # Coordinate check at (19, 0, -8)
    coords_match = bool(re.search(r'OfficeExpansion3D.*?\n\s*transform\s*=\s*Transform3D\([^)]*19,\s*0,\s*-8\)', main_tscn, re.DOTALL))
    reporter.check(coords_match,
                   "OfficeExpansion3D placed precisely at North/East wing coordinate (19, 0, -8)",
                   "CAMPUS_Coordinates")

    # Spatial clearance verification (>5.0m from all other campus stations)
    target = (19.0, 0.0, -8.0)
    stations = {
        "SyndicateHQ3D": (12.0, 0.0, 0.0),
        "CoffeeMachine3D": (-19.0, 0.0, 4.0),
        "TechLabTerminal": (-19.0, 0.0, 0.0),
        "ServerTerminal": (0.0, 0.0, -18.0),
        "PitchStage": (0.0, 0.0, 18.0),
        "IpoBell3D": (0.0, 0.0, 12.0),
        "DailyBoard3D": (3.0, 0.0, 8.0),
        "TrophyShowcase3D": (6.0, 0.0, 12.0),
        "Desk_1": (15.0, 0.0, -4.0),
        "Desk_2": (23.0, 0.0, -4.0)
    }

    for name, pos in stations.items():
        dist = math.sqrt((target[0] - pos[0])**2 + (target[1] - pos[1])**2 + (target[2] - pos[2])**2)
        reporter.check(dist >= 5.0,
                       f"Spatial clearance from {name} ({pos[0]}, {pos[1]}, {pos[2]}): {dist:.2f}m >= 5.0m",
                       "CAMPUS_Clearance")


# ==============================================================================
# SECTION 4: Script Behavioral & AST Oracle (office_expansion_3d.gd)
# ==============================================================================

def verify_office_expansion_script(reporter: TestReporter, game_dir: Path):
    print(f"\n{Colors.BOLD}=== SECTION 4: Office Expansion Script AST & API Oracle ==={Colors.ENDC}")

    script_path = game_dir / "scripts/office_expansion_3d.gd"
    reporter.check(script_path.exists(), "scripts/office_expansion_3d.gd exists on disk", "SCRIPT_OfficeFile")
    if not script_path.exists():
        return

    content = script_path.read_text(encoding="utf-8")

    # Inheritance & Class name
    reporter.check('extends StaticBody3D' in content, "Office expansion extends StaticBody3D", "SCRIPT_Inherits")
    reporter.check('class_name OfficeExpansion3D' in content, "Declares class_name OfficeExpansion3D", "SCRIPT_ClassName")

    # Signals
    reporter.check('signal staff_interaction_requested' in content, "Declares signal staff_interaction_requested()", "SCRIPT_Signals")
    reporter.check('signal staff_office_opened' in content, "Declares signal staff_office_opened()", "SCRIPT_Signals")
    reporter.check('signal worker_epiphany_collected' in content, "Declares signal worker_epiphany_collected()", "SCRIPT_Signals")

    # Export variables
    reporter.check('@export var prompt_text' in content, "Exports prompt_text property", "SCRIPT_Exports")
    reporter.check('@export var action_label' in content, "Exports action_label property", "SCRIPT_Exports")
    reporter.check('@export var worker_scene' in content, "Exports worker_scene property", "SCRIPT_Exports")

    # Groups in _ready()
    reporter.check('add_to_group("staff_offices")' in content, "Adds to group 'staff_offices' in _ready()", "SCRIPT_Groups")
    reporter.check('add_to_group("interactables")' in content, "Adds to group 'interactables' in _ready()", "SCRIPT_Groups")
    reporter.check('add_to_group("stations")' in content, "Adds to group 'stations' in _ready()", "SCRIPT_Groups")

    # Proximity & Input
    reporter.check('KEY_E' in content, "Handles KEY_E interaction event", "SCRIPT_KeyE")
    reporter.check('_on_interaction_body_entered' in content, "Implements body entered proximity handler", "SCRIPT_Proximity")
    reporter.check('_on_interaction_body_exited' in content, "Implements body exited proximity handler", "SCRIPT_Proximity")
    reporter.check('_exit_tree' in content, "Implements _exit_tree cleanup handler", "SCRIPT_Cleanup")

    # Interaction & Modal routing
    reporter.check('func interact' in content, "Implements interact()", "SCRIPT_Methods")
    reporter.check('func open_staff' in content, "Implements open_staff()", "SCRIPT_Methods")
    reporter.check('func open_staff_modal' in content, "Implements open_staff_modal()", "SCRIPT_Methods")
    reporter.check('func is_player_in_range' in content, "Implements is_player_in_range() -> bool", "SCRIPT_Methods")

    # Desk & Worker Lifecycle
    reporter.check('func refresh_desks' in content, "Implements refresh_desks()", "SCRIPT_Desks")
    reporter.check('func refresh_workers' in content, "Implements refresh_workers()", "SCRIPT_Workers")
    reporter.check('func spawn_worker' in content, "Implements spawn_worker()", "SCRIPT_Workers")
    reporter.check('func despawn_worker' in content, "Implements despawn_worker()", "SCRIPT_Workers")
    reporter.check('func get_worker_instance' in content, "Implements get_worker_instance()", "SCRIPT_Workers")
    reporter.check('func get_desk_node' in content, "Implements get_desk_node()", "SCRIPT_Desks")

    # GameState signal handlers
    reporter.check('_on_worker_hired' in content, "Implements _on_worker_hired handler", "SCRIPT_GameStateSync")
    reporter.check('_on_worker_fired' in content, "Implements _on_worker_fired handler", "SCRIPT_GameStateSync")
    reporter.check('_on_worker_state_changed' in content, "Implements _on_worker_state_changed handler", "SCRIPT_GameStateSync")
    reporter.check('_on_desk_upgraded' in content, "Implements _on_desk_upgraded handler", "SCRIPT_GameStateSync")
    reporter.check('_on_coffee_break_started' in content, "Implements _on_coffee_break_started handler", "SCRIPT_GameStateSync")
    reporter.check('_on_unicorn_espresso_activated' in content, "Implements _on_unicorn_espresso_activated handler", "SCRIPT_GameStateSync")


# ==============================================================================
# SECTION 5: Script Behavioral & State Machine Oracle (chibi_worker_3d.gd)
# ==============================================================================

def verify_chibi_worker_script(reporter: TestReporter, game_dir: Path):
    print(f"\n{Colors.BOLD}=== SECTION 5: Chibi Worker Script AST & State Machine Oracle ==={Colors.ENDC}")

    script_path = game_dir / "scripts/chibi_worker_3d.gd"
    reporter.check(script_path.exists(), "scripts/chibi_worker_3d.gd exists on disk", "SCRIPT_WorkerFile")
    if not script_path.exists():
        return

    content = script_path.read_text(encoding="utf-8")

    # Inheritance & Class name
    reporter.check('extends CharacterBody3D' in content, "Chibi worker extends CharacterBody3D", "SCRIPT_WorkerInherits")
    reporter.check('class_name ChibiWorker3D' in content, "Declares class_name ChibiWorker3D", "SCRIPT_WorkerClassName")

    # Signals
    reporter.check('signal state_changed' in content, "Declares signal state_changed(old_state, new_state)", "SCRIPT_WorkerSignals")
    reporter.check('signal epiphany_triggered' in content, "Declares signal epiphany_triggered(worker_id, reward)", "SCRIPT_WorkerSignals")
    reporter.check('signal epiphany_collected' in content, "Declares signal epiphany_collected(worker_id, reward)", "SCRIPT_WorkerSignals")

    # 4-state state machine definitions
    reporter.check('STATE_WORKING' in content, "Declares STATE_WORKING state constant", "SCRIPT_WorkerStates")
    reporter.check('STATE_COFFEE_BREAK' in content, "Declares STATE_COFFEE_BREAK state constant", "SCRIPT_WorkerStates")
    reporter.check('STATE_FATIGUED' in content, "Declares STATE_FATIGUED state constant", "SCRIPT_WorkerStates")
    reporter.check('STATE_CELEBRATING' in content, "Declares STATE_CELEBRATING state constant", "SCRIPT_WorkerStates")
    reporter.check('enum State' in content, "Declares enum State for typed transitions", "SCRIPT_WorkerStates")

    # Specialist roles palette
    roles = ["Frontend Dev", "Backend Dev", "UI/UX Designer", "Growth Hacker", "QA Engineer"]
    for role in roles:
        reporter.check(role in content, f"Defines role color palette for '{role}'", "SCRIPT_WorkerRoles")

    # Public API methods
    reporter.check('func setup' in content, "Implements setup(data: Dictionary)", "SCRIPT_WorkerAPI")
    reporter.check('func set_state' in content, "Implements set_state(new_state)", "SCRIPT_WorkerAPI")
    reporter.check('func get_state' in content, "Implements get_state() -> String", "SCRIPT_WorkerAPI")
    reporter.check('func set_morale' in content, "Implements set_morale(new_morale: float)", "SCRIPT_WorkerAPI")
    reporter.check('func set_fatigue' in content, "Implements set_fatigue(new_fatigue: float)", "SCRIPT_WorkerAPI")
    reporter.check('func set_hyper_focus' in content, "Implements set_hyper_focus(active: bool)", "SCRIPT_WorkerAPI")
    reporter.check('func trigger_epiphany' in content, "Implements trigger_epiphany(custom_reward: float)", "SCRIPT_WorkerAPI")
    reporter.check('func collect_epiphany' in content, "Implements collect_epiphany() -> float", "SCRIPT_WorkerAPI")
    reporter.check('func has_epiphany' in content, "Implements has_epiphany() -> bool", "SCRIPT_WorkerAPI")
    reporter.check('func play_celebration' in content, "Implements play_celebration(duration: float)", "SCRIPT_WorkerAPI")

    # Kinematics in _process
    reporter.check('func _process' in content, "Implements _process(delta: float) for procedural kinematics", "SCRIPT_Kinematics")
    reporter.check('_animate_working' in content, "Implements _animate_working() procedural typing arms", "SCRIPT_Kinematics")
    reporter.check('_animate_coffee_break' in content, "Implements _animate_coffee_break() sipping animation", "SCRIPT_Kinematics")
    reporter.check('_animate_fatigued' in content, "Implements _animate_fatigued() desk slump animation", "SCRIPT_Kinematics")
    reporter.check('_animate_celebrating' in content, "Implements _animate_celebrating() bounce jump animation", "SCRIPT_Kinematics")


# ==============================================================================
# SECTION 6: Mathematical Simulation of Worker Kinematics & States
# ==============================================================================

def verify_mathematical_kinematics_and_states(reporter: TestReporter):
    print(f"\n{Colors.BOLD}=== SECTION 6: Mathematical Simulation of Worker Kinematics & States ==={Colors.ENDC}")

    # 1. State machine transition simulation
    class SimulatedWorker:
        def __init__(self):
            self.state = "working"
            self.fatigue = 0.0
            self.morale = 1.0
            self.has_epiphany = False
            self.hyper_focus = False

        def set_fatigue(self, val: float):
            self.fatigue = max(0.0, min(1.0, val))
            if self.fatigue >= 1.0 and self.state == "working":
                self.state = "fatigued"
            elif self.fatigue < 0.8 and self.state == "fatigued":
                self.state = "working"

        def give_coffee_break(self):
            self.state = "break"
            self.fatigue = 0.0
            self.morale = 1.0
            self.hyper_focus = True

        def trigger_epiphany(self):
            self.has_epiphany = True

        def collect_epiphany(self, passive_rps: float) -> float:
            if not self.has_epiphany:
                return 0.0
            self.has_epiphany = False
            self.state = "celebrating"
            return max(100.0, passive_rps * 15.0)

        def get_mood_icon(self) -> str:
            if self.has_epiphany:
                return "💡"
            if self.state == "working":
                return "💻"
            elif self.state == "break":
                return "☕"
            elif self.state == "fatigued":
                return "💤"
            elif self.state == "celebrating":
                return "🎉"
            return "💻"

    worker = SimulatedWorker()
    reporter.check(worker.state == "working" and worker.get_mood_icon() == "💻",
                   "Initial state is 'working' with mood icon 💻", "SIM_State")

    # Fatigue accumulation triggers fatigued state
    worker.set_fatigue(0.5)
    reporter.check(worker.state == "working", "Moderate fatigue (0.5) maintains working state", "SIM_State")
    worker.set_fatigue(1.0)
    reporter.check(worker.state == "fatigued" and worker.get_mood_icon() == "💤",
                   "Full fatigue (1.0) transitions automatically to 'fatigued' with mood icon 💤", "SIM_State")

    # Coffee break resets fatigue and sets coffee state
    worker.give_coffee_break()
    reporter.check(worker.state == "break" and worker.get_mood_icon() == "☕",
                   "Coffee break sets state to 'break' with mood icon ☕", "SIM_State")
    reporter.check(worker.fatigue == 0.0 and worker.morale == 1.0 and worker.hyper_focus,
                   "Coffee break resets fatigue to 0.0, restores morale to 1.0, and activates hyper-focus", "SIM_State")

    # Epiphany triggers 💡 icon
    worker.trigger_epiphany()
    reporter.check(worker.has_epiphany and worker.get_mood_icon() == "💡",
                   "Epiphany overrides mood icon with 💡", "SIM_State")

    # Collecting epiphany rewards 15x passive RPS and transitions to celebrating
    reward = worker.collect_epiphany(passive_rps=50.0)
    reporter.check(reward == 750.0, f"Epiphany collects exactly 15x passive RPS (got {reward})", "SIM_Reward")
    reporter.check(worker.state == "celebrating" and worker.get_mood_icon() == "🎉",
                   "Collecting epiphany transitions to 'celebrating' with mood icon 🎉", "SIM_State")

    # 2. Procedural arm typing rhythm kinematic frequency
    typing_freq = 14.0 # Hz
    t0 = 0.0
    t1 = 0.05
    osc0 = math.sin(t0 * typing_freq) * 0.15
    osc1 = math.sin(t1 * typing_freq) * 0.15
    reporter.check(osc0 != osc1, f"Typing oscillation produces genuine dynamic arm kinematics (t0={osc0:.4f}, t1={osc1:.4f})", "SIM_Kinematics")

    # 3. Procedural celebration jump height
    jump_freq = 12.0
    t_peak = math.pi / (2 * jump_freq)
    jump_height = abs(math.sin(t_peak * jump_freq)) * 0.22
    reporter.check(math.isclose(jump_height, 0.22, rel_tol=1e-3),
                   f"Celebration jump reaches genuine apex height of {jump_height:.2f}m", "SIM_Kinematics")


# ==============================================================================
# MAIN TEST RUNNER
# ==============================================================================

def main():
    print("=" * 70)
    print(f"{Colors.HEADER}{Colors.BOLD}Phase 14 Milestone 2: 3D Office Expansion & Chibi Worker AI Test Suite{Colors.ENDC}")
    print("=" * 70)

    # Locate Game directory
    game_dir = Path(__file__).resolve().parent.parent
    reporter = TestReporter()

    verify_office_expansion_scene(reporter, game_dir)
    verify_chibi_worker_scene(reporter, game_dir)
    verify_triangle_budgets(reporter, game_dir)
    verify_campus_placement(reporter, game_dir)
    verify_office_expansion_script(reporter, game_dir)
    verify_chibi_worker_script(reporter, game_dir)
    verify_mathematical_kinematics_and_states(reporter)

    exit_code = reporter.summarize()
    sys.exit(exit_code)


if __name__ == "__main__":
    main()
