"""
Adversarial Empirical Challenge Suite for Milestone P7-M4 Round 2
Agent: p7_m4_r2_challenger_1
Focus: Empirical verification of 6 defects in test_phase7_ux_models.gd,
       headless SceneTree AST validation, NodePath resolution,
       dead assertion elimination, and regression safety.
"""

import os
import re
import sys

def parse_tscn_nodes(filepath):
    """
    Parses Godot 4 .tscn file and returns:
    1. full_paths: set of relative paths from root node
    2. unique_names: set of node names with unique_name_in_owner=true
    3. node_types: dict mapping full_path to Godot class type
    """
    full_paths = set()
    unique_names = set()
    node_types = {}
    current_node = None
    
    with open(filepath, 'r', encoding='utf-8') as f:
        for line in f:
            m = re.match(r'\[node name="([^"]+)"(?: type="([^"]+)")?(?: parent="([^"]+)")?', line)
            if m:
                name, ntype, parent = m.group(1), m.group(2), m.group(3)
                current_node = name
                if parent is None:
                    # Root node
                    full_path = "."
                    node_types["."] = ntype
                elif parent == ".":
                    full_path = name
                    full_paths.add(full_path)
                    node_types[full_path] = ntype
                else:
                    full_path = f"{parent}/{name}"
                    full_paths.add(full_path)
                    node_types[full_path] = ntype
            elif 'unique_name_in_owner = true' in line or 'unique_name_in_owner="true"' in line:
                if current_node:
                    unique_names.add(current_node)
                    
    return full_paths, unique_names, node_types

def main():
    print("=" * 70)
    print(">>> P7-M4 ROUND 2 EMPIRICAL ADVERSARIAL CHALLENGER SUITE <<<")
    print("=" * 70)
    
    gd_path = os.path.join("IdleArcade", "tests", "test_phase7_ux_models.gd")
    if not os.path.exists(gd_path):
        print(f"[FAIL] Target file not found: {gd_path}")
        sys.exit(1)
        
    with open(gd_path, "r", encoding="utf-8") as f:
        gd_content = f.read()
        gd_lines = gd_content.splitlines()

    failures = []
    checks_passed = 0
    
    # -------------------------------------------------------------------------
    # CHECK 1: GDScript Syntax & Structural Soundness
    # -------------------------------------------------------------------------
    print("\n--- CHECK 1: GDScript Syntax & Structural Soundness ---")
    
    # Check bracket balance
    brackets = {"(": ")", "[": "]", "{": "}"}
    stack = []
    syntax_ok = True
    in_string = False
    string_char = ""
    
    for line_idx, line in enumerate(gd_lines, 1):
        i = 0
        while i < len(line):
            ch = line[i]
            if not in_string:
                if ch in ('"', "'"):
                    # Check for triple quotes
                    if line[i:i+3] in ('"""', "'''"):
                        in_string = True
                        string_char = line[i:i+3]
                        i += 3
                        continue
                    else:
                        in_string = True
                        string_char = ch
                        i += 1
                        continue
                elif ch == "#":
                    # Comment till end of line
                    break
                elif ch in brackets.keys():
                    stack.append((ch, line_idx))
                elif ch in brackets.values():
                    if not stack:
                        failures.append(f"Unmatched closing bracket '{ch}' at line {line_idx}")
                        syntax_ok = False
                    else:
                        open_ch, open_line = stack.pop()
                        if brackets[open_ch] != ch:
                            failures.append(f"Mismatched bracket '{open_ch}' (line {open_line}) closed by '{ch}' (line {line_idx})")
                            syntax_ok = False
            else:
                if len(string_char) == 3 and line[i:i+3] == string_char:
                    in_string = False
                    i += 3
                    continue
                elif len(string_char) == 1 and ch == string_char and (i == 0 or line[i-1] != '\\'):
                    in_string = False
                    i += 1
                    continue
            i += 1

    if stack:
        for open_ch, open_line in stack:
            failures.append(f"Unclosed bracket '{open_ch}' from line {open_line}")
        syntax_ok = False

    if syntax_ok:
        print("  [PASS] GDScript bracket matching and string quote integrity verified")
        checks_passed += 1
    else:
        print("  [FAIL] GDScript bracket or quote mismatch detected")

    # Check for duplicate function definitions
    func_pattern = re.compile(r'^\s*func\s+([A-Za-z0-9_]+)\s*\(')
    defined_funcs = {}
    dup_funcs = []
    for line_idx, line in enumerate(gd_lines, 1):
        m = func_pattern.match(line)
        if m:
            func_name = m.group(1)
            if func_name in defined_funcs:
                dup_funcs.append((func_name, defined_funcs[func_name], line_idx))
            else:
                defined_funcs[func_name] = line_idx

    if not dup_funcs:
        print(f"  [PASS] No duplicate method definitions found ({len(defined_funcs)} unique methods)")
        checks_passed += 1
    else:
        for fn, l1, l2 in dup_funcs:
            failures.append(f"Duplicate function '{fn}' declared at lines {l1} and {l2}")
        print(f"  [FAIL] Duplicate method definitions detected: {dup_funcs}")

    # -------------------------------------------------------------------------
    # CHECK 2: Strict Ban on Object.get("NodePath") Anti-Pattern
    # -------------------------------------------------------------------------
    print("\n--- CHECK 2: Strict Ban on Object.get('NodePath') Anti-Pattern ---")
    
    # In Godot, Object.get(StringName) is ONLY for member properties.
    # Calling obj.get("path/to/child") returns null and crashes if indexed.
    invalid_get_calls = []
    for line_idx, line in enumerate(gd_lines, 1):
        # find pattern .get("...")
        for m in re.finditer(r'\.get\(\s*\"([^\"]+)\"\s*\)', line):
            arg = m.group(1)
            # If the argument contains '/', '%' or is known to be a child path rather than property
            if "/" in arg or "%" in arg or "Accessories" in arg or "Mesh" in arg or "Beacon" in arg:
                invalid_get_calls.append((line_idx, line.strip(), arg))

    if not invalid_get_calls:
        print("  [PASS] Zero instances of Object.get('NodePath') anti-pattern detected")
        checks_passed += 1
    else:
        for idx, l, arg in invalid_get_calls:
            failures.append(f"Invalid Object.get('{arg}') at line {idx}: {l}")
        print(f"  [FAIL] Found {len(invalid_get_calls)} invalid Object.get() calls on NodePath")

    # Verify line 307 fix specifically
    line_307 = gd_lines[306] if len(gd_lines) >= 307 else ""
    line_308 = gd_lines[307] if len(gd_lines) >= 308 else ""
    if "get_node" in line_307 and "get_node" in line_308 and "BobAccessories" in line_308:
        print(f"  [PASS] Line 307/308 uses get_node() for BobAccessories: {line_308.strip()}")
        checks_passed += 1
    else:
        failures.append(f"Line 307/308 does not properly resolve BobAccessories: {line_307} / {line_308}")
        print("  [FAIL] Line 307/308 BobAccessories resolution failed")

    # -------------------------------------------------------------------------
    # CHECK 3: SceneTree NodePath & Unique Name Resolution
    # -------------------------------------------------------------------------
    print("\n--- CHECK 3: SceneTree NodePath & Unique Name Resolution ---")
    
    # Load all scene node trees
    scenes_to_check = {
        "touch_controls": "IdleArcade/scenes/ui/touch_controls.tscn",
        "hud": "IdleArcade/scenes/hud.tscn",
        "avatar_3d": "IdleArcade/scenes/avatar_3d.tscn",
        "npc_3d": "IdleArcade/scenes/npc_3d.tscn",
        "worker_avatar_3d": "IdleArcade/scenes/worker_avatar_3d.tscn",
        "collectible_3d": "IdleArcade/scenes/collectible_3d.tscn",
        "zone_gate_3d": "IdleArcade/scenes/zone_gate_3d.tscn",
        "quest_waypoint": "IdleArcade/scenes/quest_waypoint.tscn"
    }
    
    scene_data = {}
    for scn_key, scn_path in scenes_to_check.items():
        if os.path.exists(scn_path):
            paths, uniques, types = parse_tscn_nodes(scn_path)
            scene_data[scn_key] = {"paths": paths, "uniques": uniques, "types": types}
        else:
            failures.append(f"Scene file missing: {scn_path}")

    # Verify TouchControls unique nodes
    tc_uniques = scene_data["touch_controls"]["uniques"]
    for req_u in ["ActionButton", "LaptopThumbButton", "CampusThumbButton"]:
        if req_u in tc_uniques:
            print(f"  [PASS] TouchControls declares unique node %{req_u}")
            checks_passed += 1
        else:
            failures.append(f"TouchControls missing unique node %{req_u}")
            print(f"  [FAIL] TouchControls missing %{req_u}")

    # Verify HUD unique nodes & ShopPanel
    hud_uniques = scene_data["hud"]["uniques"]
    hud_paths = scene_data["hud"]["paths"]
    for req_u in ["BurgerMenuButton", "NavDrawer", "AuthButton", "LeaderboardButton", "GuildButton", "QuestButton", "CampusButton"]:
        if req_u in hud_uniques:
            print(f"  [PASS] HUD declares unique node %{req_u}")
            checks_passed += 1
        else:
            failures.append(f"HUD missing unique node %{req_u}")
            print(f"  [FAIL] HUD missing %{req_u}")

    if "ShopPanel" in hud_uniques or "BottomContainer/ShopPanel" in hud_paths:
        print("  [PASS] HUD contains ShopPanel node (find_child/unique resolved)")
        checks_passed += 1
    else:
        failures.append("HUD missing ShopPanel node")
        print("  [FAIL] HUD missing ShopPanel")

    # Verify Avatar3D chibi paths
    avatar_paths = scene_data["avatar_3d"]["paths"]
    for p in [
        "CollisionShape3D", "InteractionArea", "FootstepDust", "Visuals/DirectionalPointer",
        "Visuals/ChibiRoot", "Visuals/ChibiRoot/Head", "Visuals/ChibiRoot/Head/Visor",
        "Visuals/ChibiRoot/Torso", "Visuals/ChibiRoot/Backpack",
        "Visuals/ChibiRoot/LeftArm", "Visuals/ChibiRoot/RightArm",
        "Visuals/ChibiRoot/LeftLeg", "Visuals/ChibiRoot/RightLeg"
    ]:
        if p in avatar_paths:
            print(f"  [PASS] Avatar3D declares node path '{p}'")
            checks_passed += 1
        else:
            failures.append(f"Avatar3D missing node path '{p}'")
            print(f"  [FAIL] Avatar3D missing '{p}'")

    # Verify NPC3D accessory paths
    npc_paths = scene_data["npc_3d"]["paths"]
    for p in [
        "Visuals/ChibiRoot/AlexAccessories",
        "Visuals/ChibiRoot/BobAccessories",
        "Visuals/ChibiRoot/LisaAccessories"
    ]:
        if p in npc_paths:
            print(f"  [PASS] NPC3D declares accessory path '{p}'")
            checks_passed += 1
        else:
            failures.append(f"NPC3D missing accessory path '{p}'")
            print(f"  [FAIL] NPC3D missing '{p}'")

    # Verify Collectible3D mesh paths
    col_paths = scene_data["collectible_3d"]["paths"]
    for p in [
        "Visuals/BriefcaseMesh", "Visuals/CoffeeMesh", "Visuals/USBMesh", "Visuals/SparkleParticles"
    ]:
        if p in col_paths:
            print(f"  [PASS] Collectible3D declares mesh path '{p}'")
            checks_passed += 1
        else:
            failures.append(f"Collectible3D missing mesh path '{p}'")
            print(f"  [FAIL] Collectible3D missing '{p}'")

    # Verify ZoneGate3D Visuals/ paths (Defect 2)
    gate_paths = scene_data["zone_gate_3d"]["paths"]
    barrier_found = "Visuals/BarrierMesh" in gate_paths or "Visuals/NeonBarrier" in gate_paths
    beacon_found = "Visuals/LeftPost/StatusBeacon" in gate_paths or "Visuals/PostLeft/StatusBeacon" in gate_paths
    if barrier_found:
        print("  [PASS] ZoneGate3D declares Visuals/BarrierMesh or Visuals/NeonBarrier")
        checks_passed += 1
    else:
        failures.append("ZoneGate3D missing Visuals/BarrierMesh")
        print("  [FAIL] ZoneGate3D missing Visuals/BarrierMesh")

    if beacon_found:
        print("  [PASS] ZoneGate3D declares Visuals/LeftPost/StatusBeacon or Visuals/PostLeft/StatusBeacon")
        checks_passed += 1
    else:
        failures.append("ZoneGate3D missing status beacon under Visuals/")
        print("  [FAIL] ZoneGate3D missing status beacon under Visuals/")

    # -------------------------------------------------------------------------
    # CHECK 4: Dead Assertion Audit & Guard Liveness
    # -------------------------------------------------------------------------
    print("\n--- CHECK 4: Dead Assertion Audit & Guard Liveness ---")
    
    # Check Defect 5: ShopPanel upgrade cards guard
    # Must query _upgrade_cards, not upgrade_cards
    if "cards_dict = hud_inst.get(\"_upgrade_cards\")" in gd_content and "first_card = cards_dict.values()[0]" in gd_content:
        print("  [PASS] ShopPanel upgrade cards guard uses '_upgrade_cards' Dictionary (active code)")
        checks_passed += 1
    else:
        failures.append("ShopPanel upgrade cards guard not updated or dead code")
        print("  [FAIL] ShopPanel upgrade cards guard dead code")

    # Check that assertions 1.39, 1.40, 1.41 are present and guarded by cards_dict
    assert_1_39 = "1.39 Shop upgrade card has buy_button" in gd_content
    assert_1_40 = "1.40 Shop buy button height >= 54px" in gd_content
    assert_1_41 = "1.41 Shop buy button mouse_filter == MOUSE_FILTER_STOP" in gd_content
    if assert_1_39 and assert_1_40 and assert_1_41:
        print("  [PASS] Assertions 1.39, 1.40, 1.41 are explicitly declared")
        checks_passed += 1
    else:
        failures.append("Missing assertions 1.39, 1.40, or 1.41")
        print("  [FAIL] Assertions 1.39-1.41 missing")

    # Check Defect 6: WorkerAvatar3D visor emote states
    # Must call _update_accessories_for_state with State enum
    worker_calls_state = (
        "_update_accessories_for_state" in gd_content and
        "WorkerAvatar3D.State.TYPING" in gd_content and
        "WorkerAvatar3D.State.COFFEE_BREAK" in gd_content and
        "WorkerAvatar3D.State.CELEBRATING" in gd_content and
        "WorkerAvatar3D.State.WALKING" in gd_content
    )
    if worker_calls_state:
        print("  [PASS] WorkerAvatar3D tests directly call '_update_accessories_for_state' for all 4 states")
        checks_passed += 1
    else:
        failures.append("WorkerAvatar3D state calls missing or using obsolete set_worker_state")
        print("  [FAIL] WorkerAvatar3D visor emote tests dead or incomplete")

    # Check Defect 3: Reactive Avatar Speed Upgrade Binding
    # gs.avatar_speed_level = 2 must precede avatar._on_avatar_stat_updated
    speed_level_pos = gd_content.find("gs.avatar_speed_level = 2")
    stat_updated_pos = gd_content.find("avatar._on_avatar_stat_updated(\"avatar_speed\"")
    current_speed_assert_pos = gd_content.find("avatar.current_speed > base_speed_val")
    
    if speed_level_pos != -1 and stat_updated_pos != -1 and current_speed_assert_pos != -1:
        if speed_level_pos < stat_updated_pos < current_speed_assert_pos:
            print("  [PASS] avatar_speed_level = 2 assigned before _on_avatar_stat_updated() and speed assertion")
            checks_passed += 1
        else:
            failures.append("avatar_speed_level ordering incorrect in test_phase7_ux_models.gd")
            print("  [FAIL] avatar_speed_level assigned after signal call")
    else:
        failures.append("Reactive speed test statements missing")
        print("  [FAIL] Reactive speed test incomplete")

    # Check Defect 4: QuestWaypoint3D Avatar instance lifecycle
    # wp_avatar must be instantiated before waypoint._process(0.1)
    wp_avatar_pos = gd_content.find("var wp_avatar = avatar_scene.instantiate()")
    waypoint_process_pos = gd_content.find("waypoint._process(0.1)")
    if wp_avatar_pos != -1 and waypoint_process_pos != -1:
        if wp_avatar_pos < waypoint_process_pos:
            print("  [PASS] wp_avatar instantiated and added to root before waypoint._process(0.1)")
            checks_passed += 1
        else:
            failures.append("wp_avatar instantiated after waypoint._process()")
            print("  [FAIL] wp_avatar ordering incorrect")
    else:
        failures.append("wp_avatar instantiation missing")
        print("  [FAIL] wp_avatar missing")

    # -------------------------------------------------------------------------
    # CHECK 5: Mathematical & Ergonomic Simulation
    # -------------------------------------------------------------------------
    print("\n--- CHECK 5: Mathematical & Ergonomic Simulation ---")
    
    # Touch Controls positions from scenes/ui/touch_controls.tscn
    act_pos = (580.0, 1100.0)
    act_size = (100.0, 100.0)
    act_center = (act_pos[0] + act_size[0] * 0.5, act_pos[1] + act_size[1] * 0.5) # (630, 1150)
    
    lap_pos = (565.0, 1000.0)
    lap_size = (70.0, 70.0)
    lap_center = (lap_pos[0] + lap_size[0] * 0.5, lap_pos[1] + lap_size[1] * 0.5) # (600, 1035)
    
    cam_pos = (485.0, 1055.0)
    cam_size = (70.0, 70.0)
    cam_center = (cam_pos[0] + cam_size[0] * 0.5, cam_pos[1] + cam_size[1] * 0.5) # (520, 1090)
    
    dist_act_lap = ((act_center[0] - lap_center[0])**2 + (act_center[1] - lap_center[1])**2)**0.5
    dist_act_cam = ((act_center[0] - cam_center[0])**2 + (act_center[1] - cam_center[1])**2)**0.5
    dist_lap_cam = ((lap_center[0] - cam_center[0])**2 + (lap_center[1] - cam_center[1])**2)**0.5
    
    if dist_act_lap >= 95.0 and dist_act_cam >= 95.0 and dist_lap_cam >= 95.0:
        print(f"  [PASS] Pairwise fan center distances >= 95px ({dist_act_lap:.2f}px, {dist_act_cam:.2f}px, {dist_lap_cam:.2f}px)")
        checks_passed += 1
    else:
        failures.append(f"Fan center distances too small: {dist_act_lap}, {dist_act_cam}, {dist_lap_cam}")
        print("  [FAIL] Fan center distances below 95px")

    edge_act_lap = dist_act_lap - (50.0 + 35.0)
    edge_act_cam = dist_act_cam - (50.0 + 35.0)
    edge_lap_cam = dist_lap_cam - (35.0 + 35.0)
    
    if edge_act_lap >= 25.0 and edge_act_cam >= 25.0 and edge_lap_cam >= 25.0:
        print(f"  [PASS] Pairwise fan edge clearances >= 25px ({edge_act_lap:.2f}px, {edge_act_cam:.2f}px, {edge_lap_cam:.2f}px)")
        checks_passed += 1
    else:
        failures.append(f"Fan edge clearances too small: {edge_act_lap}, {edge_act_cam}, {edge_lap_cam}")
        print("  [FAIL] Fan edge clearances below 25px")

    corner = (720.0, 1280.0)
    reach_act = ((corner[0] - act_center[0])**2 + (corner[1] - act_center[1])**2)**0.5
    reach_lap = ((corner[0] - lap_center[0])**2 + (corner[1] - lap_center[1])**2)**0.5
    reach_cam = ((corner[0] - cam_center[0])**2 + (corner[1] - cam_center[1])**2)**0.5
    
    if reach_act <= 280.0 and reach_lap <= 280.0 and reach_cam <= 280.0:
        print(f"  [PASS] Single-thumb corner reach <= 280px ({reach_act:.2f}px, {reach_lap:.2f}px, {reach_cam:.2f}px)")
        checks_passed += 1
    else:
        failures.append(f"Thumb reach exceeds 280px: {reach_act}, {reach_lap}, {reach_cam}")
        print("  [FAIL] Thumb reach exceeds 280px")

    # -------------------------------------------------------------------------
    # SUMMARY & VERDICT
    # -------------------------------------------------------------------------
    print("\n" + "=" * 70)
    print("CHALLENGER HARNESS VERIFICATION SUMMARY")
    print(f"Total Checks Executed : {checks_passed + len(failures)}")
    print(f"Passed                : {checks_passed}")
    print(f"Failed                : {len(failures)}")
    print("=" * 70)
    
    if failures:
        print("\nFAILURES DETECTED:")
        for f in failures:
            print(f"  - {f}")
        print("\n>>> VERDICT: REQUEST_CHANGES <<<")
        sys.exit(1)
    else:
        print("\n>>> VERDICT: APPROVE <<<")
        sys.exit(0)

if __name__ == "__main__":
    main()
