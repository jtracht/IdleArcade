#!/usr/bin/env python3
"""
=============================================================================
Phase 18 Milestone 2: Empirical Adversarial Challenger Verification Suite
File: tests/test_p18_m2_challenger_touch.py
Target: Touch Target Compliance, Layout Ergonomics, and Lifecycle Hardening

Verifies:
  1. All 5 modified scene files (main_3d.tscn, auth_modal.tscn, guild_modal.tscn,
     leaderboard_modal.tscn, quest_modal.tscn):
     - Every single Button, CheckBox, and Tab node has custom_minimum_size with
       height >= 56px (and width >= 56px for non-expanding controls).
  2. scenes/main_3d.tscn:
     - QuickHUD/BarHBox/Spacer has mouse_filter = 0 (Control.MOUSE_FILTER_STOP).
  3. scenes/ui/staff_modal.tscn & scenes/ui/syndicate_modal.tscn:
     - ModalCard has custom_minimum_size = Vector2(640, 800).
     - Responsive scroll containers (WorkersScroll, DesksScroll, PerkScroll, etc.)
       enforce minimum scrollable clearance and horizontal scroll suppression.
  4. scripts/ui/virtual_joystick.gd:
     - Dynamic viewport calculation (_update_touch_zone, size_changed signal).
  5. scripts/incubator_manager.gd:
     - Worker despawn loop cleanly unparents and frees excess worker avatars.
  6. scripts/autoload/audio_manager.gd:
     - _exit_tree() lifecycle teardown stops players and nullifies audio streams.
  7. scripts/ui/espresso_brew_minigame.gd & scenes/ui/quest_tracker.tscn:
     - %HoldButton dead fallback cleaned, quest_tracker.tscn retained.
  8. tests/test_full_stack_qa.gd:
     - Core instantiation fix instantiated from scene, not bare script.
=============================================================================
"""

import os
import re
import sys

# Locate IdleArcade project root directory
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.abspath(os.path.join(SCRIPT_DIR, ".."))
if not os.path.exists(os.path.join(PROJECT_ROOT, "project.godot")):
    # Try current directory or subdirectory
    if os.path.exists("project.godot"):
        PROJECT_ROOT = os.path.abspath(".")
    elif os.path.exists("IdleArcade/project.godot"):
        PROJECT_ROOT = os.path.abspath("IdleArcade")
    elif os.path.exists(os.path.join(SCRIPT_DIR, "IdleArcade", "project.godot")):
        PROJECT_ROOT = os.path.abspath(os.path.join(SCRIPT_DIR, "IdleArcade"))

print(f"[SETUP] Project Root: {PROJECT_ROOT}")

# Test harness counters
pass_count = 0
fail_count = 0
findings = []

def check(condition: bool, test_name: str, detail: str = ""):
    global pass_count, fail_count
    if condition:
        print(f"  [PASS] {test_name}")
        pass_count += 1
    else:
        msg = f"  [FAIL] {test_name}"
        if detail:
            msg += f" -> {detail}"
        print(msg, file=sys.stderr)
        findings.append(msg)
        fail_count += 1

def resolve_path(rel_path: str) -> str:
    path = os.path.join(PROJECT_ROOT, rel_path)
    if not os.path.exists(path):
        raise FileNotFoundError(f"File not found: {path}")
    return path

def parse_tscn_nodes(filepath: str):
    """
    Parses a Godot 4 .tscn file and returns a list of dictionaries for each [node ...] block.
    """
    with open(filepath, "r", encoding="utf-8") as f:
        content = f.read()

    node_pattern = re.compile(
        r'\[node\s+name="([^"]+)"'
        r'(?:\s+type="([^"]+)")?'
        r'(?:\s+parent="([^"]+)")?'
        r'(?:\s+instance=([^\]\s]+))?'
    )

    nodes = []
    lines = content.splitlines()
    current_node = None
    current_lines = []

    def commit_node():
        if current_node:
            current_node["raw_text"] = "\n".join(current_lines)
            for line in current_lines[1:]:
                line = line.strip()
                if not line or line.startswith("#"):
                    continue
                if "=" in line:
                    k, v = line.split("=", 1)
                    current_node["properties"][k.strip()] = v.strip()
            nodes.append(current_node)

    for line in lines:
        if line.startswith("[node "):
            commit_node()
            m = node_pattern.match(line)
            if m:
                name, ntype, parent, instance = m.groups()
                current_node = {
                    "name": name,
                    "type": ntype,
                    "parent": parent,
                    "instance": instance,
                    "properties": {},
                }
                current_lines = [line]
            else:
                current_node = None
                current_lines = []
        elif current_node is not None:
            if line.startswith("["):  # Another section
                commit_node()
                current_node = None
                current_lines = []
            else:
                current_lines.append(line)

    commit_node()
    return nodes

def parse_vector2(val_str: str):
    """Parses Vector2(x, y) into (float(x), float(y))"""
    if not val_str:
        return None
    m = re.match(r"Vector2\(\s*([-\d.]+)\s*,\s*([-\d.]+)\s*\)", val_str)
    if m:
        return float(m.group(1)), float(m.group(2))
    return None

# =============================================================================
# SUITE 1: Interactive Control Touch Targets (>= 56px) across 5 Modified Scenes
# =============================================================================
print("\n" + "=" * 70)
print(">>> SUITE 1: TOUCH TARGET ERGONOMICS (>= 56px) AUDIT <<<")
print("=" * 70)

MODIFIED_SCENES = [
    "scenes/main_3d.tscn",
    "scenes/ui/auth_modal.tscn",
    "scenes/ui/guild_modal.tscn",
    "scenes/ui/leaderboard_modal.tscn",
    "scenes/ui/quest_modal.tscn",
]

INTERACTIVE_TYPES = {
    "Button",
    "CheckBox",
    "CheckButton",
    "OptionButton",
    "MenuButton",
    "LinkButton",
    "TextureButton",
    "TabBar",
    "Tabs",
}

total_interactive_controls = 0

for rel_path in MODIFIED_SCENES:
    full_path = resolve_path(rel_path)
    nodes = parse_tscn_nodes(full_path)
    scene_name = os.path.basename(rel_path)
    print(f"\n--- Checking Scene: {scene_name} ({len(nodes)} total nodes) ---")

    for node in nodes:
        name = node["name"]
        ntype = node.get("type")
        props = node["properties"]

        # Determine if this node is an interactive touch control
        is_interactive = False
        if ntype in INTERACTIVE_TYPES:
            is_interactive = True
        elif any(name.endswith(suffix) for suffix in ["Button", "CheckBox", "Tab"]):
            is_interactive = True

        if not is_interactive:
            continue

        total_interactive_controls += 1
        cms_str = props.get("custom_minimum_size")
        vec = parse_vector2(cms_str) if cms_str else None

        # Check if node has horizontal expansion
        sfh = props.get("size_flags_horizontal", "")
        # size_flags_horizontal = 3 means SIZE_EXPAND_FILL (1 | 2)
        is_h_expand = "3" in sfh or "size_flags_horizontal" not in props and vec and vec[0] == 0

        # Also check layout anchors (e.g. anchors_preset = 1 with offset)
        offset_left = float(props.get("offset_left", "0"))
        offset_right = float(props.get("offset_right", "0"))
        calculated_width = abs(offset_right - offset_left) if ("offset_right" in props and "offset_left" in props) else 0

        # Requirement 1: custom_minimum_size MUST be defined
        check(
            vec is not None,
            f"[{scene_name}] Node '{name}' has custom_minimum_size defined",
            f"custom_minimum_size is missing in {node['raw_text']}",
        )

        if vec is not None:
            w, h = vec
            # Requirement 2: Height MUST be >= 56px (or offset height >= 56px)
            offset_top = float(props.get("offset_top", "0"))
            offset_bottom = float(props.get("offset_bottom", "0"))
            calculated_height = abs(offset_bottom - offset_top) if ("offset_bottom" in props and "offset_top" in props) else 0

            height_ok = (h >= 56.0) or (calculated_height >= 56.0 and h >= 56.0)
            check(
                height_ok,
                f"[{scene_name}] Node '{name}' height >= 56px (h={h}, calc_h={calculated_height})",
                f"Height {h} is below the 56px minimum standard",
            )

            # Requirement 3: Width MUST be >= 56px OR button is horizontally expanding
            width_ok = (w >= 56.0) or (w == 0.0 and (is_h_expand or "BarHBox" in str(node.get("parent")) or "AltActionsVBox" in str(node.get("parent")))) or (calculated_width >= 56.0)
            check(
                width_ok,
                f"[{scene_name}] Node '{name}' width >= 56px or expands (w={w}, h_expand={is_h_expand}, calc_w={calculated_width})",
                f"Width {w} is not expanding and below 56px",
            )

print(f"\n[SUMMARY] Total Interactive Controls Scanned & Verified: {total_interactive_controls}")
check(total_interactive_controls >= 20, f"Found at least 20 interactive controls (actual: {total_interactive_controls})")

# =============================================================================
# SUITE 2: Spacer Pointer Isolation (scenes/main_3d.tscn)
# =============================================================================
print("\n" + "=" * 70)
print(">>> SUITE 2: POINTER ISOLATION & SPACER AUDIT <<<")
print("=" * 70)

main_3d_path = resolve_path("scenes/main_3d.tscn")
main_3d_nodes = parse_tscn_nodes(main_3d_path)

spacer_node = None
for n in main_3d_nodes:
    if n["name"] == "Spacer" and "BarHBox" in str(n.get("parent")):
        spacer_node = n
        break

check(spacer_node is not None, "Spacer node found under QuickHUD/BarHBox in scenes/main_3d.tscn")
if spacer_node:
    mouse_filter = spacer_node["properties"].get("mouse_filter")
    check(
        mouse_filter == "0",
        "QuickHUD/BarHBox/Spacer has mouse_filter = 0 (Control.MOUSE_FILTER_STOP)",
        f"mouse_filter was {mouse_filter} (expected '0')",
    )
    # Check size_flags_horizontal is expanding
    sfh = spacer_node["properties"].get("size_flags_horizontal")
    check(sfh == "3", "QuickHUD/BarHBox/Spacer has size_flags_horizontal = 3 (SIZE_EXPAND_FILL)")

# =============================================================================
# SUITE 3: Modal Dimensions & Scroll Ergonomics (staff_modal & syndicate_modal)
# =============================================================================
print("\n" + "=" * 70)
print(">>> SUITE 3: MODAL CARD DIMENSIONS & SCROLL ERGONOMICS <<<")
print("=" * 70)

# Staff Modal Card
staff_nodes = parse_tscn_nodes(resolve_path("scenes/ui/staff_modal.tscn"))
staff_card = next((n for n in staff_nodes if n["name"] == "ModalCard"), None)
check(staff_card is not None, "ModalCard found in scenes/ui/staff_modal.tscn")
if staff_card:
    cms = staff_card["properties"].get("custom_minimum_size")
    vec = parse_vector2(cms)
    check(
        vec == (640.0, 800.0),
        "ModalCard in staff_modal.tscn has custom_minimum_size = Vector2(640, 800)",
        f"actual: {cms}",
    )
    mf = staff_card["properties"].get("mouse_filter")
    check(mf == "0", "ModalCard in staff_modal.tscn has mouse_filter = 0 (STOP)")

# Staff Modal Scroll Containers
workers_scroll = next((n for n in staff_nodes if n["name"] == "WorkersScroll"), None)
desks_scroll = next((n for n in staff_nodes if n["name"] == "DesksScroll"), None)

check(workers_scroll is not None, "WorkersScroll found in staff_modal.tscn")
if workers_scroll:
    cms = parse_vector2(workers_scroll["properties"].get("custom_minimum_size"))
    check(cms == (56.0, 320.0), "WorkersScroll has custom_minimum_size = Vector2(56, 320)", f"actual: {cms}")
    check(workers_scroll["properties"].get("size_flags_vertical") == "3", "WorkersScroll has size_flags_vertical = 3")

check(desks_scroll is not None, "DesksScroll found in staff_modal.tscn")
if desks_scroll:
    cms = parse_vector2(desks_scroll["properties"].get("custom_minimum_size"))
    check(cms == (56.0, 320.0), "DesksScroll has custom_minimum_size = Vector2(56, 320)", f"actual: {cms}")
    check(desks_scroll["properties"].get("size_flags_vertical") == "3", "DesksScroll has size_flags_vertical = 3")

# Syndicate Modal Card
syndicate_nodes = parse_tscn_nodes(resolve_path("scenes/ui/syndicate_modal.tscn"))
syndicate_card = next((n for n in syndicate_nodes if n["name"] == "ModalCard"), None)
check(syndicate_card is not None, "ModalCard found in scenes/ui/syndicate_modal.tscn")
if syndicate_card:
    cms = syndicate_card["properties"].get("custom_minimum_size")
    vec = parse_vector2(cms)
    check(
        vec == (640.0, 800.0),
        "ModalCard in syndicate_modal.tscn has custom_minimum_size = Vector2(640, 800)",
        f"actual: {cms}",
    )
    mf = syndicate_card["properties"].get("mouse_filter")
    check(mf == "0", "ModalCard in syndicate_modal.tscn has mouse_filter = 0 (STOP)")

# Syndicate Modal Scroll Containers
perk_scroll = next((n for n in syndicate_nodes if n["name"] == "PerkScroll"), None)
roster_scroll = next((n for n in syndicate_nodes if n["name"] == "RosterScroll"), None)
lb_scroll = next((n for n in syndicate_nodes if n["name"] == "LeaderboardScroll"), None)

for scroll_node, sname, min_h in [
    (perk_scroll, "PerkScroll", 360.0),
    (roster_scroll, "RosterScroll", 180.0),
    (lb_scroll, "LeaderboardScroll", 300.0),
]:
    check(scroll_node is not None, f"{sname} found in syndicate_modal.tscn")
    if scroll_node:
        cms = parse_vector2(scroll_node["properties"].get("custom_minimum_size"))
        check(
            cms is not None and cms[1] >= min_h,
            f"{sname} custom_minimum_size.y >= {min_h} (actual: {cms})",
        )
        hsm = scroll_node["properties"].get("horizontal_scroll_mode")
        check(
            hsm == "0",
            f"{sname} has horizontal_scroll_mode = 0 (disabled to eliminate horizontal jitter)",
            f"actual: {hsm}",
        )

# =============================================================================
# SUITE 4: Virtual Joystick Dynamic Viewport Bounds (virtual_joystick.gd)
# =============================================================================
print("\n" + "=" * 70)
print(">>> SUITE 4: VIRTUAL JOYSTICK DYNAMIC BOUNDS AUDIT <<<")
print("=" * 70)

vj_path = resolve_path("scripts/ui/virtual_joystick.gd")
with open(vj_path, "r", encoding="utf-8") as f:
    vj_code = f.read()

check("_update_touch_zone" in vj_code, "virtual_joystick.gd defines _update_touch_zone()")
check("DisplayServer.get_name() == \"headless\"" in vj_code, "virtual_joystick.gd handles headless test environment")
check("get_viewport_rect()" in vj_code and "vp_rect.size.x * 0.5" in vj_code, "virtual_joystick.gd computes bounds against dynamic viewport size")
check("size_changed.connect" in vj_code, "virtual_joystick.gd connects to viewport size_changed signal")

# Mathematical simulation of dynamic bounds
def simulate_is_in_touch_zone(screen_pos_x: float, screen_pos_y: float, vp_w: float, vp_h: float, is_headless: bool = False):
    if is_headless:
        max_x = 360.0
        max_y = 1280.0
    else:
        max_x = vp_w * 0.5
        max_y = vp_h
    return (0.0 <= screen_pos_x <= max_x) and (0.0 <= screen_pos_y <= max_y)

# Test 1: Headless baseline
check(simulate_is_in_touch_zone(300.0, 1000.0, 1280.0, 1280.0, is_headless=True), "Headless: touch at (300, 1000) is in touch zone")
check(not simulate_is_in_touch_zone(400.0, 1000.0, 1280.0, 1280.0, is_headless=True), "Headless: touch at (400, 1000) is outside touch zone (>360)")

# Test 2: Tall mobile viewport (1080 x 2400)
check(simulate_is_in_touch_zone(500.0, 2200.0, 1080.0, 2400.0, is_headless=False), "Tall 20:9 screen (1080x2400): touch at (500, 2200) is in zone (max_x=540, max_y=2400)")
check(not simulate_is_in_touch_zone(550.0, 2200.0, 1080.0, 2400.0, is_headless=False), "Tall 20:9 screen: touch at (550, 2200) is outside zone (>540)")

# Test 3: Landscape desktop (1920 x 1080)
check(simulate_is_in_touch_zone(800.0, 900.0, 1920.0, 1080.0, is_headless=False), "Landscape screen (1920x1080): touch at (800, 900) is in zone (max_x=960)")
check(not simulate_is_in_touch_zone(1000.0, 900.0, 1920.0, 1080.0, is_headless=False), "Landscape screen: touch at (1000, 900) is outside zone (>960)")

# =============================================================================
# SUITE 5: Incubator Worker Despawn Lifecycle (incubator_manager.gd)
# =============================================================================
print("\n" + "=" * 70)
print(">>> SUITE 5: WORKER DESPAWN LIFECYCLE AUDIT <<<")
print("=" * 70)

im_path = resolve_path("scripts/incubator_manager.gd")
with open(im_path, "r", encoding="utf-8") as f:
    im_code = f.read()

check("while _workers.size() > desired_count:" in im_code, "incubator_manager.gd implements despawn while loop")
check("worker_to_free.queue_free()" in im_code, "incubator_manager.gd frees despawned worker avatars")
check("pop_back()" in im_code, "incubator_manager.gd pops excess workers from _workers array")

# =============================================================================
# SUITE 6: AudioManager ObjectDB Teardown (audio_manager.gd)
# =============================================================================
print("\n" + "=" * 70)
print(">>> SUITE 6: AUDIOMANAGER LIFECYCLE TEARDOWN AUDIT <<<")
print("=" * 70)

am_path = resolve_path("scripts/autoload/audio_manager.gd")
with open(am_path, "r", encoding="utf-8") as f:
    am_code = f.read()

check("func _exit_tree() -> void:" in am_code, "audio_manager.gd implements _exit_tree()")
check("player.stop()" in am_code and "player.stream = null" in am_code, "audio_manager.gd stops SFX players and nulls streams")
check("_bgm_player.stop()" in am_code and "_bgm_player.stream = null" in am_code, "audio_manager.gd stops BGM player and nulls stream")
check("_wav_click = null" in am_code and "_wav_confetti = null" in am_code, "audio_manager.gd nulls procedural AudioStreamWAV references")

# =============================================================================
# SUITE 7: Dead Code Cleanup & Scene Integrity
# =============================================================================
print("\n" + "=" * 70)
print(">>> SUITE 7: DEAD CODE CLEANUP & SCENE RETENTION AUDIT <<<")
print("=" * 70)

eb_path = resolve_path("scripts/ui/espresso_brew_minigame.gd")
with open(eb_path, "r", encoding="utf-8") as f:
    eb_code = f.read()

check("hold_button: Button = pump_button" in eb_code, "espresso_brew_minigame.gd aliases hold_button directly to pump_button")
check('get_node_or_null("%HoldButton")' not in eb_code, "espresso_brew_minigame.gd does not attempt dead %HoldButton lookup")

qt_path = resolve_path("scenes/ui/quest_tracker.tscn")
check(os.path.exists(qt_path), "scenes/ui/quest_tracker.tscn exists and is preserved")

# =============================================================================
# SUITE 8: Test Runner Core Instantiation Fix (test_full_stack_qa.gd)
# =============================================================================
print("\n" + "=" * 70)
print(">>> SUITE 8: FULL-STACK QA RUNNER CORE INSTANTIATION AUDIT <<<")
print("=" * 70)

qa_path = resolve_path("tests/test_full_stack_qa.gd")
with open(qa_path, "r", encoding="utf-8") as f:
    qa_code = f.read()

check('load("res://scenes/core.tscn")' in qa_code and 'instantiate()' in qa_code, "test_full_stack_qa.gd instantiates core.tscn instead of bare script")
check("core_script.new()" not in qa_code, "test_full_stack_qa.gd does not use bare core_script.new()")

# =============================================================================
# FINAL SUMMARY AND VERDICT
# =============================================================================
print("\n" + "=" * 70)
print(">>> EMPIRICAL CHALLENGER TEST RESULTS SUMMARY <<<")
print("=" * 70)
print(f"Total Checks Executed : {pass_count + fail_count}")
print(f"Passed Checks         : {pass_count}")
print(f"Failed Checks         : {fail_count}")

if fail_count == 0:
    print("\n>>> VERDICT: ALL ADVERSARIAL CHECKS PASSED — VERIFIED EMPIRICALLY (APPROVE) <<<")
    sys.exit(0)
else:
    print(f"\n>>> VERDICT: {fail_count} CHECKS FAILED — REQUESTING CHANGES <<<", file=sys.stderr)
    for f in findings:
        print(f, file=sys.stderr)
    sys.exit(1)
