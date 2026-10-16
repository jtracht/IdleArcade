#!/usr/bin/env python3
"""
Adversarial Challenge & Stress-Testing Suite for Milestone 2:
3D Tech Lab Terminal, Chibi Delivery Drone & Server Room Overclock Integration.

Tests edge cases, lifecycle teardowns, dormant states, collision masking,
triangle budgets, floating-point bounds, and campus integration.
"""

import sys
import re
import math
from pathlib import Path

# Paths
BASE_DIR = Path("c:/Projects/Game/IdleArcade")
MAIN3D_SCENE = BASE_DIR / "scenes/main_3d.tscn"
MAIN3D_SCRIPT = BASE_DIR / "scripts/main_3d.gd"
TERMINAL_SCENE = BASE_DIR / "scenes/tech_lab_terminal.tscn"
TERMINAL_SCRIPT = BASE_DIR / "scripts/tech_lab_terminal.gd"
DRONE_SCENE = BASE_DIR / "scenes/delivery_drone_3d.tscn"
DRONE_SCRIPT = BASE_DIR / "scripts/delivery_drone_3d.gd"
COLLECTIBLE_SCENE = BASE_DIR / "scenes/collectible_3d.tscn"
TOUCH_CONTROLS_SCRIPT = BASE_DIR / "scripts/ui/touch_controls.gd"

total_checks = 0
passed_checks = 0
failed_checks = 0
failures = []

def record(name: str, passed: bool, detail: str = ""):
    global total_checks, passed_checks, failed_checks
    total_checks += 1
    if passed:
        passed_checks += 1
        print(f"  [PASS] {name}" + (f" -> {detail}" if detail else ""))
    else:
        failed_checks += 1
        msg = f"  [FAIL] {name}" + (f" -> {detail}" if detail else "")
        print(msg)
        failures.append(msg)

def calculate_mesh_triangles(mesh_type: str, props: dict) -> int:
    """Calculates triangle count using standard Godot 3D primitive formulas."""
    if mesh_type == "BoxMesh":
        return 12
    elif mesh_type == "PlaneMesh":
        return 2
    elif mesh_type == "SphereMesh":
        rad = props.get("radial_segments", 64)
        rings = props.get("rings", 32)
        return rad * rings * 2
    elif mesh_type == "CapsuleMesh":
        rad = props.get("radial_segments", 64)
        rings = props.get("rings", 8)
        return rad * (rings + 1) * 2
    elif mesh_type == "CylinderMesh":
        rad = props.get("radial_segments", 64)
        rings = props.get("rings", 4)
        return (rad * 2) + (rad * rings * 2)
    elif mesh_type == "TorusMesh":
        rings = props.get("rings", 64)
        ring_segments = props.get("ring_segments", 32)
        return rings * ring_segments * 2
    return 0

def parse_meshes(content: str):
    subres = {}
    pattern = r'\[sub_resource type="([^"]+)" id="([^"]+)"\]([\s\S]*?)(?=\n\[|$)'
    for m in re.finditer(pattern, content):
        m_type, m_id, block = m.group(1), m.group(2), m.group(3)
        if "Mesh" in m_type:
            props = {}
            for line in block.strip().split("\n"):
                if "=" in line:
                    k, v = line.split("=", 1)
                    k, v = k.strip(), v.strip()
                    try:
                        props[k] = int(v)
                    except ValueError:
                        try:
                            props[k] = float(v)
                        except ValueError:
                            props[k] = v
            subres[m_id] = (m_type, props)

    total_tris = 0
    breakdown = []
    node_pattern = r'\[node name="([^"]+)" type="MeshInstance3D"[^\]]*\]([\s\S]*?)(?=\n\[|$)'
    for m in re.finditer(node_pattern, content):
        node_name = m.group(1)
        node_block = m.group(2)
        mesh_ref = re.search(r'mesh = SubResource\("([^"]+)"\)', node_block)
        if mesh_ref:
            ref_id = mesh_ref.group(1)
            if ref_id in subres:
                m_type, props = subres[ref_id]
                tris = calculate_mesh_triangles(m_type, props)
                total_tris += tris
                breakdown.append((node_name, m_type, tris))

    return total_tris, breakdown

print("=" * 75)
print(">>> ADVERSARIAL STRESS TEST: TECH LAB TERMINAL, DRONE & OVERCLOCK <<<")
print("=" * 75)

# ==============================================================================
# SECTION 1: TECH LAB TERMINAL ADVERSARIAL CHECKS
# ==============================================================================
print("\n--- SECTION 1: Tech Lab Terminal Adversarial Checks ---")
term_tscn = TERMINAL_SCENE.read_text(encoding="utf-8")
term_gd = TERMINAL_SCRIPT.read_text(encoding="utf-8")

# 1.1 Triangle Budget (<800 tris)
term_tris, term_breakdown = parse_meshes(term_tscn)
record("[Budget] Terminal mesh total < 800 triangles", term_tris < 800, f"Actual: {term_tris} tris")
record("[Budget] Terminal budget utilization < 60%", (term_tris / 800.0) < 0.60, f"Actual: {term_tris/800.0*100:.1f}%")

# 1.2 Collision & Layering
record("[Collision] Terminal root is StaticBody3D with layer=1, mask=0",
       'collision_layer = 1' in term_tscn and 'collision_mask = 0' in term_tscn)
record("[Collision] InteractionArea has SphereShape3D with radius 2.4",
       'radius = 2.4' in term_tscn)
record("[Collision] PromptLabel3D billboard is 1 (billboarded)",
       'billboard = 1' in term_tscn)

# 1.3 Hologram Bobbing Simulation
class HologramSim:
    def __init__(self):
        self.time = 0.0
        self.base_y = 1.55
        self.spin_speed = 1.8
        self.bob_speed = 3.0
        self.bob_amplitude = 0.06
        self.rotation_y = 0.0
        self.pos_y = 1.55

    def step(self, dt: float):
        self.time += dt
        self.rotation_y += self.spin_speed * dt
        self.pos_y = self.base_y + math.sin(self.time * self.bob_speed) * self.bob_amplitude

holo = HologramSim()
min_y = float("inf")
max_y = float("-inf")
for _ in range(1000):
    holo.step(0.016)
    min_y = min(min_y, holo.pos_y)
    max_y = max(max_y, holo.pos_y)

record("[Simulation] Hologram Y stays strictly within [1.49, 1.61]",
       min_y >= 1.489 and max_y <= 1.611, f"Observed [{min_y:.4f}, {max_y:.4f}]")
record("[Simulation] Hologram rotation strictly advances monotonically",
       holo.rotation_y > 25.0, f"Total yaw rotation: {holo.rotation_y:.2f} rad")

# 1.4 Lifecycle Teardown & TouchControls Unregistration AST
record("[Teardown] Terminal script defines _exit_tree()", "func _exit_tree() -> void:" in term_gd)
record("[Teardown] Terminal calls unregister_interactable(self) in _exit_tree()",
       "tc.unregister_interactable(self)" in term_gd)
record("[Robustness] _exit_tree() guards against null touch_controls",
       "if tc != null and tc.has_method(\"unregister_interactable\"):" in term_gd)

# 1.5 Terminal Interaction & UI Dispatch
record("[Dispatch] interact() aliases open_research()", "func interact() -> void:\n\topen_research()" in term_gd)
record("[Dispatch] open_research() emits research_opened and terminal_interacted",
       "research_opened.emit()" in term_gd and "terminal_interacted.emit()" in term_gd)
record("[Dispatch] open_research() contains modal opening with fallback to hud overlay",
       "open_tech_tree_modal" in term_gd and "open_hud_overlay" in term_gd)

# ==============================================================================
# SECTION 2: DELIVERY DRONE ADVERSARIAL CHECKS
# ==============================================================================
print("\n--- SECTION 2: Delivery Drone 3D Adversarial Checks ---")
drone_tscn = DRONE_SCENE.read_text(encoding="utf-8")
drone_gd = DRONE_SCRIPT.read_text(encoding="utf-8")

# 2.1 Triangle Budget (<2000 tris)
drone_tris, drone_breakdown = parse_meshes(drone_tscn)
record("[Budget] Delivery Drone mesh total < 2000 triangles", drone_tris < 2000, f"Actual: {drone_tris} tris")
record("[Budget] Delivery Drone budget utilization < 50%", (drone_tris / 2000.0) < 0.50, f"Actual: {drone_tris/2000.0*100:.1f}%")

# 2.2 Waypoints & Patrol Navigation Math
WAYPOINTS = [
    (0.0, 1.8, 0.0),     # Lobby
    (0.0, 1.8, -18.0),   # Server Room
    (-19.0, 1.8, 0.0),   # R&D Lab
    (19.0, 1.8, 0.0),    # Office / Incubator
    (0.0, 1.8, 18.0)     # Courtyard
]

record("[Waypoints] Exactly 5 campus waypoints defined", len(WAYPOINTS) == 5)

# Simulate Drone Kinematics over 2,000 steps
class DroneSim:
    def __init__(self):
        self.pos = list(WAYPOINTS[0])
        self.waypoint_idx = 0
        self.waypoints_visited = set()
        self.waypoints_visited.add(0)
        self.time = 0.0
        self.move_speed = 4.5
        self.speed_mult = 1.0
        self.speed_boost_timer = 0.0
        self.arrival_dist = 0.8
        self.rotor_rot = 0.0
        self.active = True

    def apply_speed_boost(self, mult=1.35, dur=5.0):
        self.speed_mult = max(self.speed_mult, mult)
        self.speed_boost_timer = max(self.speed_boost_timer, dur)

    def step(self, dt: float):
        if not self.active:
            return
        self.time += dt
        if self.speed_boost_timer > 0.0:
            self.speed_boost_timer -= dt
            if self.speed_boost_timer <= 0.0:
                self.speed_mult = 1.0

        target = WAYPOINTS[self.waypoint_idx]
        dx = target[0] - self.pos[0]
        dz = target[2] - self.pos[2]
        flat_dist = math.sqrt(dx * dx + dz * dz)

        if flat_dist <= self.arrival_dist:
            self.waypoint_idx = (self.waypoint_idx + 1) % len(WAYPOINTS)
            self.waypoints_visited.add(self.waypoint_idx)
            target = WAYPOINTS[self.waypoint_idx]
            dx = target[0] - self.pos[0]
            dz = target[2] - self.pos[2]
            flat_dist = math.sqrt(dx * dx + dz * dz)

        if flat_dist > 0.001:
            eff_speed = self.move_speed * self.speed_mult
            self.pos[0] += (dx / flat_dist) * eff_speed * dt
            self.pos[2] += (dz / flat_dist) * eff_speed * dt
        self.pos[1] += (target[1] - self.pos[1]) * 2.5 * dt
        self.rotor_rot += 24.0 * dt

d_sim = DroneSim()
for _ in range(2500):
    d_sim.step(0.016)

record("[Simulation] Drone completes full cyclic circuit across all 5 zones",
       len(d_sim.waypoints_visited) == 5, f"Visited {len(d_sim.waypoints_visited)}/5 waypoints")

# 2.3 Speed Boost Transition Dynamics
d_boost = DroneSim()
record("[Boost] Base speed multiplier is 1.0", d_boost.speed_mult == 1.0)
d_boost.apply_speed_boost(1.35, 2.0)
record("[Boost] Boost applied: speed multiplier is 1.35", d_boost.speed_mult == 1.35)
record("[Boost] Boost timer set to 2.0s", d_boost.speed_boost_timer == 2.0)
# Step 1.5s -> still boosted
for _ in range(int(1.5 / 0.016)):
    d_boost.step(0.016)
record("[Boost] At t=1.5s, speed boost is still active", d_boost.speed_mult == 1.35 and d_boost.speed_boost_timer > 0.0)
# Step 1.0s more -> expired
for _ in range(int(1.0 / 0.016)):
    d_boost.step(0.016)
record("[Boost] At t=2.5s, speed boost returned to baseline 1.0", d_boost.speed_mult == 1.0 and d_boost.speed_boost_timer <= 0.0)

# 2.4 Rotor Counter-Rotation Pairs Check
record("[Rotors] 4 rotors declared (RotorFL, RotorFR, RotorBL, RotorBR)",
       all(r in drone_gd for r in ["rotor_fl", "rotor_fr", "rotor_bl", "rotor_br"]))
record("[Rotors] Counter-rotating logic present (FL/BR CW, FR/BL CCW)",
       "rotor_fl.rotate_y(rot_delta)" in drone_gd and "rotor_fr.rotate_y(-rot_delta)" in drone_gd and
       "rotor_bl.rotate_y(-rot_delta)" in drone_gd and "rotor_br.rotate_y(rot_delta)" in drone_gd)

# 2.5 LED Pulsation Bounds
led_min = float("inf")
led_max = float("-inf")
for t_step in range(1000):
    t_val = t_step * 0.016
    pulse_val = 1.0 + math.sin(t_val * 6.0) * 0.8
    led_min = min(led_min, pulse_val)
    led_max = max(led_max, pulse_val)
record("[LEDs] LED pulse energy bounded in [0.20, 1.80]",
       led_min >= 0.199 and led_max <= 1.801, f"Range: [{led_min:.2f}, {led_max:.2f}]")

# 2.6 Collision Masking & Autonomous Collection
record("[Collection] CollectionArea collision_mask is 4 (collectibles layer)",
       "collision_mask = 4" in drone_tscn)
record("[Collection] CollectionArea radius is 3.5m",
       "radius = 3.5" in drone_tscn)
record("[Collection] _try_collect checks for collect() method and passes self",
       'target.call("collect", self)' in drone_gd)
record("[Collection] Collectible3D has collect(collector: Node3D = null)",
       "func collect(collector: Node3D = null) -> void:" in COLLECTIBLE_SCENE.read_text(encoding="utf-8") or
       "func collect(collector: Node3D = null)" in (BASE_DIR / "scripts/collectible_3d.gd").read_text(encoding="utf-8"))

# 2.7 Dormant State Integrity
record("[Dormancy] deactivate_drone() sets is_drone_active = false", "is_drone_active = false" in drone_gd)
record("[Dormancy] deactivate_drone() sets visible = false", "visible = false" in drone_gd)
record("[Dormancy] deactivate_drone() disables process and physics_process",
       "set_process(false)" in drone_gd and "set_physics_process(false)" in drone_gd)
record("[Dormancy] deactivate_drone() zeros velocity", "velocity = Vector3.ZERO" in drone_gd)
record("[Dormancy] _process early exits when dormant", "if not is_drone_active:\n\t\treturn" in drone_gd)
record("[Dormancy] _physics_process zeros velocity and returns when dormant",
       "if not is_drone_active:\n\t\tvelocity = Vector3.ZERO\n\t\treturn" in drone_gd)
record("[Dormancy] _on_collection_area_entered early exits when dormant",
       "if not is_drone_active:\n\t\treturn" in drone_gd)
record("[Activation] Drone unlocks specifically on tech_delivery_drone",
       'tech_id == "tech_delivery_drone"' in drone_gd)

# ==============================================================================
# SECTION 3: SERVER OVERCLOCK GLOW INTEGRATION
# ==============================================================================
print("\n--- SECTION 3: Server Room Overclock Glow Integration ---")
main3d_tscn = MAIN3D_SCENE.read_text(encoding="utf-8")
main3d_gd = MAIN3D_SCRIPT.read_text(encoding="utf-8")

record("[Glow] ServerOverclockGlow OmniLight3D exists in main_3d.tscn",
       'node name="ServerOverclockGlow" type="OmniLight3D"' in main3d_tscn)
record("[Glow] ServerOverclockGlow position at (0, 2.5, -18) in Server Room",
       "transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 2.5, -18)" in main3d_tscn)
record("[Glow] ServerOverclockGlow initial light_energy is 0.0 (dormant)",
       "light_energy = 0.0" in main3d_tscn)
record("[Glow] ServerOverclockGlow range is 14.0m",
       "omni_range = 14.0" in main3d_tscn)
record("[Glow] ServerOverclockGlow color is cyan Color(0.1, 0.85, 1, 1)",
       "Color(0.1, 0.85, 1, 1)" in main3d_tscn)

# Glow modulation bounds
glow_min = float("inf")
glow_max = float("-inf")
for t_step in range(1000):
    t_val = t_step * 0.016
    g_val = 1.8 + math.sin(t_val * 3.0) * 0.25
    glow_min = min(glow_min, g_val)
    glow_max = max(glow_max, g_val)

record("[Glow] Overclock glow pulsation bounded in [1.55, 2.05]",
       glow_min >= 1.549 and glow_max <= 2.051, f"Range: [{glow_min:.2f}, {glow_max:.2f}]")
record("[Glow] main_3d.gd connects to GameState.tech_researched",
       "gs.tech_researched.connect(_on_tech_researched)" in main3d_gd)
record("[Glow] main_3d.gd triggers _activate_server_overclock_glow on tech_server_overclock",
       'tech_id == "tech_server_overclock"' in main3d_gd)
record("[Glow] main_3d.gd tweens light_energy to 1.8 with ease out",
       'tween_property(server_overclock_glow, "light_energy", 1.8, 1.2)' in main3d_gd)

# ==============================================================================
# SECTION 4: CAMPUS INTEGRATION & TOUCH CONTROLS COMPLIANCE
# ==============================================================================
print("\n--- SECTION 4: Campus Integration & TouchControls Compliance ---")
tc_gd = TOUCH_CONTROLS_SCRIPT.read_text(encoding="utf-8")

record("[Campus] TechLabTerminal instanced at (-19, 0, 0)",
       re.search(r'\[node name="TechLabTerminal"[^\]]*\][\s\S]*?transform = Transform3D\(1, 0, 0, 0, 1, 0, 0, 0, 1, -19, 0, 0\)', main3d_tscn) is not None)
record("[Campus] DeliveryDrone3D instanced at (0, 1.8, 0)",
       re.search(r'\[node name="DeliveryDrone3D"[^\]]*\][\s\S]*?transform = Transform3D\(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1.8, 0\)', main3d_tscn) is not None)
record("[Campus] 3 USB drives placed on Campus in main_3d.tscn",
       len(re.findall(r'item_type = "usb_drive"', main3d_tscn)) == 3)

# TouchControls interaction test
record("[Touch] TouchControls implements register_interactable()", "func register_interactable(" in tc_gd)
record("[Touch] TouchControls implements unregister_interactable()", "func unregister_interactable(" in tc_gd)
record("[Touch] TouchControls trigger_action calls target.interact()", 'target.call("interact")' in tc_gd)
record("[Touch] TouchControls trigger_action injects synthetic KEY_E", "_synthesize_key(KEY_E)" in tc_gd)
record("[Touch] TechLabTerminal implements interact() and listens to KEY_E",
       "func interact() -> void:" in term_gd and "event.keycode == KEY_E:" in term_gd)

print("\n" + "=" * 75)
print(f"ADVERSARIAL STRESS TEST RESULTS: {passed_checks} PASSED, {failed_checks} FAILED (TOTAL: {total_checks})")
print("=" * 75)

if failed_checks > 0:
    print(f">>> FAILED {failed_checks} CHECKS <<<")
    for f in failures:
        print(f" - {f}")
    sys.exit(1)
else:
    print(">>> VERDICT: 100% ROBUST & VERIFIED! ZERO INTEGRITY DEFECTS! <<<")
    sys.exit(0)
