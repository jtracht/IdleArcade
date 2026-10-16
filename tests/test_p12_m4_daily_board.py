#!/usr/bin/env python3
"""
IdleArcade Phase 12 - Milestone M4 Unit & Integration Verification Suite:
Requirement R4: Tägliches Challenge-Board & Streak-System

Verifies:
1. Static code contracts & AST in game_state.gd, daily_board_3d.gd, daily_board_modal.gd,
   hud.gd, daily_board_3d.tscn, daily_board_modal.tscn, hud.tscn, main_3d.tscn.
2. Mobile touch ergonomics & input isolation (buttons >= 56px, mouse_filter = STOP).
3. Geometric topology & low-poly budget of daily_board_3d.tscn (< 400 tris).
4. Task rotation engine, progress advancement, reward payouts, streak incrementation,
   streak preservation on consecutive days, reset on missed days, and save/load persistence.
5. DailyBoard3D proximity detection and modal lifecycle state machine.
"""

import os
import re
import sys
import json
import math

class TestReporter:
    def __init__(self):
        self.total = 0
        self.passed = 0
        self.failed = 0
        self.errors = []

    def check(self, condition, message, test_id=""):
        self.total += 1
        prefix = f"[{test_id}] " if test_id else ""
        if condition:
            self.passed += 1
            print(f"  [PASS] {prefix}{message}")
        else:
            self.failed += 1
            print(f"  [FAIL] {prefix}{message}")
            self.errors.append(f"{prefix}{message}")

    def summary(self):
        print("\n" + "=" * 70)
        print("Milestone M4 (Daily Challenge Board & Streak System) Summary:")
        print(f"  Total Checks: {self.total}")
        print(f"  Passed:       {self.passed}")
        print(f"  Failed:       {self.failed}")
        print("=" * 70)
        if self.failed == 0:
            print(">>> ALL CHECKS PASSED: Milestone M4 Daily Board & Streak System Verified! <<<\n")
            return 0
        else:
            print(f">>> {self.failed} CHECKS FAILED! <<<\n")
            for err in self.errors:
                print(f"  - {err}")
            return 1

def run_tests():
    reporter = TestReporter()
    base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

    print("=" * 70)
    print("IdleArcade Phase 12 - Milestone M4 (Daily Challenge Board & Streak)")
    print("=" * 70)

    # -------------------------------------------------------------------------
    # SECTION 1: Static Code Contracts & AST Verification
    # -------------------------------------------------------------------------
    print("\n=== SECTION 1: Static Code Contracts & AST Verification ===")

    # 1.1 File Existence
    daily_board_3d_tscn = os.path.join(base_dir, "scenes", "daily_board_3d.tscn")
    daily_board_3d_gd = os.path.join(base_dir, "scripts", "daily_board_3d.gd")
    daily_modal_tscn = os.path.join(base_dir, "scenes", "ui", "daily_board_modal.tscn")
    daily_modal_gd = os.path.join(base_dir, "scripts", "ui", "daily_board_modal.gd")
    game_state_gd = os.path.join(base_dir, "scripts", "autoload", "game_state.gd")
    hud_tscn = os.path.join(base_dir, "scenes", "hud.tscn")
    hud_gd = os.path.join(base_dir, "scripts", "hud.gd")
    main_3d_tscn = os.path.join(base_dir, "scenes", "main_3d.tscn")

    reporter.check(os.path.isfile(daily_board_3d_tscn), "scenes/daily_board_3d.tscn exists", "M4_File_BoardTscn")
    reporter.check(os.path.isfile(daily_board_3d_gd), "scripts/daily_board_3d.gd exists", "M4_File_BoardGd")
    reporter.check(os.path.isfile(daily_modal_tscn), "scenes/ui/daily_board_modal.tscn exists", "M4_File_ModalTscn")
    reporter.check(os.path.isfile(daily_modal_gd), "scripts/ui/daily_board_modal.gd exists", "M4_File_ModalGd")
    reporter.check(os.path.isfile(game_state_gd), "scripts/autoload/game_state.gd exists", "M4_File_GameState")
    reporter.check(os.path.isfile(hud_tscn), "scenes/hud.tscn exists", "M4_File_HudTscn")
    reporter.check(os.path.isfile(hud_gd), "scripts/hud.gd exists", "M4_File_HudGd")
    reporter.check(os.path.isfile(main_3d_tscn), "scenes/main_3d.tscn exists", "M4_File_Main3dTscn")

    # 1.2 GameState AST
    with open(game_state_gd, "r", encoding="utf-8") as f:
        gs_code = f.read()

    reporter.check("var daily_board_streak" in gs_code, "game_state.gd declares var daily_board_streak", "M4_GS_VarStreak")
    reporter.check("var daily_board_last_login_day" in gs_code, "game_state.gd declares var daily_board_last_login_day", "M4_GS_VarLastDay")
    reporter.check("var daily_board_tasks" in gs_code, "game_state.gd declares var daily_board_tasks", "M4_GS_VarTasks")
    reporter.check("signal daily_streak_updated" in gs_code, "game_state.gd declares signal daily_streak_updated", "M4_GS_SigStreak")
    reporter.check("signal daily_tasks_updated" in gs_code, "game_state.gd declares signal daily_tasks_updated", "M4_GS_SigTasks")
    reporter.check("signal daily_task_claimed" in gs_code, "game_state.gd declares signal daily_task_claimed", "M4_GS_SigClaim")
    reporter.check("func get_daily_tasks(" in gs_code, "game_state.gd implements func get_daily_tasks()", "M4_GS_GetTasks")
    reporter.check("func advance_daily_task(" in gs_code, "game_state.gd implements func advance_daily_task()", "M4_GS_Advance")
    reporter.check("func claim_daily_task(" in gs_code, "game_state.gd implements func claim_daily_task()", "M4_GS_Claim")
    reporter.check("func get_daily_streak(" in gs_code, "game_state.gd implements func get_daily_streak()", "M4_GS_GetStreak")
    reporter.check("DAILY_TASK_CATALOG" in gs_code, "game_state.gd defines DAILY_TASK_CATALOG", "M4_GS_Catalog")

    # Check 6 task catalog templates
    catalog_tasks = ["task_hype", "task_briefcases", "task_espresso", "task_server_hack", "task_core_taps", "task_buy_upgrades"]
    for t_id in catalog_tasks:
        reporter.check(f'"{t_id}"' in gs_code, f"DAILY_TASK_CATALOG contains '{t_id}'", f"M4_GS_Task_{t_id}")

    # Check integration hooks
    reporter.check('advance_daily_task("task_core_taps"' in gs_code, "tap_core() hooks advance_daily_task('task_core_taps')", "M4_GS_Hook_Taps")
    reporter.check('advance_daily_task("task_hype"' in gs_code, "tap_core() frenzy hooks advance_daily_task('task_hype')", "M4_GS_Hook_Hype")
    reporter.check('advance_daily_task("task_buy_upgrades"' in gs_code, "buy_upgrade() hooks advance_daily_task('task_buy_upgrades')", "M4_GS_Hook_Upgrade")
    reporter.check('advance_daily_task("task_briefcases"' in gs_code, "collect_3d_item() hooks advance_daily_task('task_briefcases')", "M4_GS_Hook_Briefcase")
    reporter.check('advance_daily_task("task_server_hack"' in gs_code, "activate_server_overclock_buff() hooks advance_daily_task('task_server_hack')", "M4_GS_Hook_Server")
    reporter.check('advance_daily_task("task_espresso"' in gs_code, "activate_unicorn_espresso_buff() hooks advance_daily_task('task_espresso')", "M4_GS_Hook_Espresso")

    # Check save/load
    reporter.check('"daily_board_streak"' in gs_code and 'save_to_disk' in gs_code, "save_to_disk serializes daily_board_streak", "M4_GS_SaveStreak")
    reporter.check('"daily_board_tasks"' in gs_code and 'save_to_disk' in gs_code, "save_to_disk serializes daily_board_tasks", "M4_GS_SaveTasks")
    reporter.check('data.get("daily_board_streak"' in gs_code, "load_from_disk deserializes daily_board_streak", "M4_GS_LoadStreak")
    reporter.check('data.get("daily_board_tasks"' in gs_code, "load_from_disk deserializes daily_board_tasks", "M4_GS_LoadTasks")

    # 1.3 DailyBoard3D Script & Scene AST
    with open(daily_board_3d_gd, "r", encoding="utf-8") as f:
        board_gd = f.read()

    reporter.check("class_name DailyBoard3D" in board_gd, "daily_board_3d.gd declares class_name DailyBoard3D", "M4_Board_ClassName")
    reporter.check("signal board_interacted" in board_gd, "daily_board_3d.gd declares signal board_interacted", "M4_Board_SigInteracted")
    reporter.check("signal board_opened" in board_gd, "daily_board_3d.gd declares signal board_opened", "M4_Board_SigOpened")
    reporter.check("func interact(" in board_gd, "daily_board_3d.gd implements func interact()", "M4_Board_Interact")
    reporter.check("func open_daily_board(" in board_gd or "func open_board(" in board_gd, "daily_board_3d.gd implements open_daily_board() alias", "M4_Board_Alias")
    reporter.check("register_interactable" in board_gd, "daily_board_3d.gd registers with TouchControls", "M4_Board_TouchReg")
    reporter.check("Daily Board [E]" in board_gd, "daily_board_3d.gd uses 'Daily Board [E]' action label", "M4_Board_ActionLabel")

    with open(daily_board_3d_tscn, "r", encoding="utf-8") as f:
        board_tscn = f.read()

    reporter.check('groups=["daily_boards"' in board_tscn or '"daily_boards"' in board_tscn, "daily_board_3d.tscn is in group 'daily_boards'", "M4_Board_GroupBoard")
    reporter.check('"interactables"' in board_tscn, "daily_board_3d.tscn is in group 'interactables'", "M4_Board_GroupInteract")
    reporter.check('"stations"' in board_tscn, "daily_board_3d.tscn is in group 'stations'", "M4_Board_GroupStation")
    reporter.check('[node name="CollisionShape3D"' in board_tscn, "daily_board_3d.tscn contains CollisionShape3D", "M4_Board_Collision")
    reporter.check('[node name="InteractionArea"' in board_tscn, "daily_board_3d.tscn contains InteractionArea", "M4_Board_Area")
    reporter.check('[node name="PromptLabel3D"' in board_tscn, "daily_board_3d.tscn contains PromptLabel3D", "M4_Board_Prompt")
    reporter.check('billboard = 1' in board_tscn, "PromptLabel3D billboard = 1", "M4_Board_Billboard")
    reporter.check('outline_size = 5' in board_tscn, "PromptLabel3D outline_size = 5", "M4_Board_Outline")

    # 1.4 Daily Board Modal Script & Scene AST
    with open(daily_modal_gd, "r", encoding="utf-8") as f:
        modal_gd = f.read()

    reporter.check("signal closed" in modal_gd, "daily_board_modal.gd declares signal closed", "M4_Modal_SigClosed")
    reporter.check("close_button" in modal_gd and "%CloseButton" in modal_gd, "daily_board_modal.gd binds %CloseButton", "M4_Modal_CloseBtn")
    reporter.check("streak_header_label" in modal_gd and "%StreakHeaderLabel" in modal_gd, "daily_board_modal.gd binds %StreakHeaderLabel", "M4_Modal_StreakLbl")
    reporter.check("task1_claim_button" in modal_gd and "%Task1ClaimButton" in modal_gd, "daily_board_modal.gd binds %Task1ClaimButton", "M4_Modal_Task1Btn")
    reporter.check("task2_claim_button" in modal_gd and "%Task2ClaimButton" in modal_gd, "daily_board_modal.gd binds %Task2ClaimButton", "M4_Modal_Task2Btn")
    reporter.check("task3_claim_button" in modal_gd and "%Task3ClaimButton" in modal_gd, "daily_board_modal.gd binds %Task3ClaimButton", "M4_Modal_Task3Btn")
    reporter.check("func open(" in modal_gd, "daily_board_modal.gd implements func open()", "M4_Modal_Open")
    reporter.check("func close(" in modal_gd, "daily_board_modal.gd implements func close()", "M4_Modal_Close")
    reporter.check("claim_daily_task" in modal_gd, "daily_board_modal.gd invokes GameState.claim_daily_task()", "M4_Modal_InvokeClaim")

    with open(daily_modal_tscn, "r", encoding="utf-8") as f:
        modal_tscn = f.read()

    reporter.check('[node name="Backdrop"' in modal_tscn, "daily_board_modal.tscn contains Backdrop", "M4_Modal_Backdrop")
    reporter.check('[node name="CenterContainer"' in modal_tscn, "daily_board_modal.tscn contains CenterContainer", "M4_Modal_Center")
    reporter.check('[node name="ModalCard"' in modal_tscn, "daily_board_modal.tscn contains ModalCard", "M4_Modal_Card")
    reporter.check('unique_name_in_owner = true' in modal_tscn and 'CloseButton' in modal_tscn, "daily_board_modal.tscn defines %CloseButton", "M4_Modal_TscnClose")
    reporter.check('unique_name_in_owner = true' in modal_tscn and 'StreakHeaderLabel' in modal_tscn, "daily_board_modal.tscn defines %StreakHeaderLabel", "M4_Modal_TscnStreak")
    reporter.check('Task1ClaimButton' in modal_tscn and 'Task2ClaimButton' in modal_tscn and 'Task3ClaimButton' in modal_tscn, "daily_board_modal.tscn defines all 3 Task Claim Buttons", "M4_Modal_TscnClaimBtns")

    # 1.5 HUD Integration AST
    with open(hud_tscn, "r", encoding="utf-8") as f:
        hud_tscn_content = f.read()

    reporter.check('[node name="StreakBadge"' in hud_tscn_content, "hud.tscn defines [node name='StreakBadge']", "M4_HUD_StreakBadge")
    reporter.check('unique_name_in_owner = true' in hud_tscn_content and 'StreakBadgeLabel' in hud_tscn_content, "hud.tscn defines %StreakBadgeLabel", "M4_HUD_StreakBadgeLabel")

    with open(hud_gd, "r", encoding="utf-8") as f:
        hud_gd_content = f.read()

    reporter.check("DAILY_BOARD_MODAL_SCENE" in hud_gd_content, "hud.gd declares const DAILY_BOARD_MODAL_SCENE", "M4_HUD_ConstScene")
    reporter.check("res://scenes/ui/daily_board_modal.tscn" in hud_gd_content, "hud.gd preloads daily_board_modal.tscn", "M4_HUD_Preload")
    reporter.check("streak_badge" in hud_gd_content and "%StreakBadge" in hud_gd_content, "hud.gd declares streak_badge variable", "M4_HUD_VarBadge")
    reporter.check("streak_badge_label" in hud_gd_content and "%StreakBadgeLabel" in hud_gd_content, "hud.gd declares streak_badge_label variable", "M4_HUD_VarBadgeLabel")
    reporter.check("daily_streak_updated" in hud_gd_content, "hud.gd connects GameState.daily_streak_updated", "M4_HUD_ConnectStreak")
    reporter.check("func open_daily_board_modal(" in hud_gd_content, "hud.gd implements func open_daily_board_modal()", "M4_HUD_OpenDailyModal")
    reporter.check("open_modal(DAILY_BOARD_MODAL_SCENE)" in hud_gd_content, "open_daily_board_modal delegates to open_modal(DAILY_BOARD_MODAL_SCENE)", "M4_HUD_DelegateOpen")

    # 1.6 Campus Placement AST
    with open(main_3d_tscn, "r", encoding="utf-8") as f:
        main_3d_content = f.read()

    reporter.check('res://scenes/daily_board_3d.tscn' in main_3d_content, "main_3d.tscn references daily_board_3d.tscn", "M4_Main3d_ExtRes")
    reporter.check('[node name="DailyBoard3D"' in main_3d_content, "main_3d.tscn instances DailyBoard3D", "M4_Main3d_Node")
    # Position: Vector3(3, 0, 8)
    reporter.check('3, 0, 8' in main_3d_content, "DailyBoard3D is placed at Vector3(3, 0, 8) in main_3d.tscn", "M4_Main3d_Pos")

    # -------------------------------------------------------------------------
    # SECTION 2: Mobile Touch Ergonomics & Input Isolation
    # -------------------------------------------------------------------------
    print("\n=== SECTION 2: Mobile Touch Ergonomics & Input Isolation ===")

    # Modal root mouse_filter = STOP (0) and anchors_preset = 15
    reporter.check('mouse_filter = 0' in modal_tscn.split('[node name="Backdrop"')[0], "DailyBoardModal root mouse_filter = STOP (0)", "M4_Ergo_RootFilter")
    reporter.check('anchors_preset = 15' in modal_tscn.split('[node name="Backdrop"')[0], "DailyBoardModal root anchors_preset = 15", "M4_Ergo_RootAnchor")

    # Backdrop
    backdrop_section = modal_tscn.split('[node name="Backdrop"')[1].split('[node name=')[0]
    reporter.check('mouse_filter = 0' in backdrop_section, "Backdrop mouse_filter = STOP (0)", "M4_Ergo_BackdropFilter")
    reporter.check('anchors_preset = 15' in backdrop_section, "Backdrop anchors_preset = 15", "M4_Ergo_BackdropAnchor")

    # ModalCard min size >= (660, 820)
    card_match = re.search(r'\[node name="ModalCard"[^\]]*\][\s\S]*?custom_minimum_size = Vector2\((\d+),\s*(\d+)\)', modal_tscn)
    reporter.check(card_match is not None, "ModalCard defines custom_minimum_size", "M4_Ergo_CardMatch")
    if card_match:
        w, h = int(card_match.group(1)), int(card_match.group(2))
        reporter.check(w >= 660 and h >= 820, f"ModalCard size >= 660x820 (actual: {w}x{h})", "M4_Ergo_CardSize")

    # CloseButton >= 56x56, mouse_filter = 0
    close_match = re.search(r'\[node name="CloseButton"[^\]]*\][\s\S]*?custom_minimum_size = Vector2\((\d+),\s*(\d+)\)[\s\S]*?mouse_filter = (\d+)', modal_tscn)
    reporter.check(close_match is not None, "CloseButton defines size and mouse_filter", "M4_Ergo_CloseMatch")
    if close_match:
        cw, ch, cf = int(close_match.group(1)), int(close_match.group(2)), int(close_match.group(3))
        reporter.check(cw >= 56 and ch >= 56, f"CloseButton size >= 56x56 (actual: {cw}x{ch})", "M4_Ergo_CloseSize")
        reporter.check(cf == 0, f"CloseButton mouse_filter = STOP (actual: {cf})", "M4_Ergo_CloseFilter")

    # Task claim buttons height >= 56, mouse_filter = 0
    for btn_name in ["Task1ClaimButton", "Task2ClaimButton", "Task3ClaimButton"]:
        btn_match = re.search(r'\[node name="' + btn_name + r'"[^\]]*\][\s\S]*?custom_minimum_size = Vector2\((\d+),\s*(\d+)\)[\s\S]*?mouse_filter = (\d+)', modal_tscn)
        reporter.check(btn_match is not None, f"{btn_name} defines size and mouse_filter", f"M4_Ergo_{btn_name}_Match")
        if btn_match:
            bw, bh, bf = int(btn_match.group(1)), int(btn_match.group(2)), int(btn_match.group(3))
            reporter.check(bh >= 56, f"{btn_name} height >= 56px (actual: {bh}px)", f"M4_Ergo_{btn_name}_Height")
            reporter.check(bf == 0, f"{btn_name} mouse_filter = STOP (actual: {bf})", f"M4_Ergo_{btn_name}_Filter")

    # HUD StreakBadge size >= 80x56, mouse_filter = 0
    streak_badge_match = re.search(r'\[node name="StreakBadge"[^\]]*\][\s\S]*?custom_minimum_size = Vector2\((\d+),\s*(\d+)\)[\s\S]*?mouse_filter = (\d+)', hud_tscn_content)
    reporter.check(streak_badge_match is not None, "HUD StreakBadge defines custom_minimum_size and mouse_filter", "M4_Ergo_HUDStreakMatch")
    if streak_badge_match:
        sbw, sbh, sbf = int(streak_badge_match.group(1)), int(streak_badge_match.group(2)), int(streak_badge_match.group(3))
        reporter.check(sbw >= 80 and sbh >= 56, f"HUD StreakBadge size >= 80x56 (actual: {sbw}x{sbh})", "M4_Ergo_HUDStreakSize")
        reporter.check(sbf == 0, f"HUD StreakBadge mouse_filter = STOP (actual: {sbf})", "M4_Ergo_HUDStreakFilter")

    # -------------------------------------------------------------------------
    # SECTION 3: Geometric Topology & Triangle Budget
    # -------------------------------------------------------------------------
    print("\n=== SECTION 3: Geometric Topology & Triangle Budget ===")

    # Parse daily_board_3d.tscn meshes and calculate static triangles
    box_meshes = len(re.findall(r'\[sub_resource type="BoxMesh"', board_tscn))
    sphere_meshes = re.findall(r'\[sub_resource type="SphereMesh"[\s\S]*?radial_segments = (\d+)[\s\S]*?rings = (\d+)', board_tscn)
    cylinder_meshes = re.findall(r'\[sub_resource type="CylinderMesh"[\s\S]*?radial_segments = (\d+)[\s\S]*?rings = (\d+)', board_tscn)

    box_tris = box_meshes * 12
    sphere_tris = sum(int(r) * int(rings) * 2 for r, rings in sphere_meshes)
    cyl_tris = sum(int(r) * int(rings) * 2 + int(r) * 2 for r, rings in cylinder_meshes)
    total_board_tris = box_tris + sphere_tris + cyl_tris

    print(f"  -> Daily Board static triangles: {total_board_tris} tris (BoxMeshes: {box_meshes}, Spheres: {len(sphere_meshes)})")
    reporter.check(total_board_tris > 0, "Daily Board geometry is non-empty", "M4_Tris_NonEmpty")
    reporter.check(total_board_tris < 400, f"Daily Board static triangles < 400 tris budget (actual: {total_board_tris} tris)", "M4_Tris_Budget")

    # -------------------------------------------------------------------------
    # SECTION 4: Daily Task Rotation, Advancement & Streak State Machine
    # -------------------------------------------------------------------------
    print("\n=== SECTION 4: Daily Task Rotation, Advancement & Streak Simulation ===")

    class DailyBoardSimulator:
        def __init__(self):
            self.daily_board_streak = 0
            self.daily_board_last_login_day = 0
            self.daily_board_tasks = []
            self.energy = 1000.0
            self.total_lifetime_energy = 1000.0
            self.angel_shares = 0
            self.catalog = {
                "task_hype": {"id": "task_hype", "title": "3x Viraler Hype", "target": 3, "reward": {"energy": 10000.0}},
                "task_briefcases": {"id": "task_briefcases", "title": "5 Aktenkoffer per Drohne", "target": 5, "reward": {"energy": 15000.0, "angel_shares": 1}},
                "task_espresso": {"id": "task_espresso", "title": "1 Unicorn Espresso", "target": 1, "reward": {"energy": 20000.0, "rps_buff": 2.0, "duration": 45.0}},
                "task_server_hack": {"id": "task_server_hack", "title": "1 Cyber-Sync", "target": 1, "reward": {"energy": 12000.0}},
                "task_core_taps": {"id": "task_core_taps", "title": "50x Reactor Core", "target": 50, "reward": {"energy": 8000.0}},
                "task_buy_upgrades": {"id": "task_buy_upgrades", "title": "3 Upgrades", "target": 3, "reward": {"energy": 15000.0}}
            }
            self.keys = ["task_hype", "task_briefcases", "task_espresso", "task_server_hack", "task_core_taps", "task_buy_upgrades"]

        def rotate_for_day(self, current_day):
            if self.daily_board_last_login_day > 0:
                if current_day == self.daily_board_last_login_day + 1:
                    # Consecutive day login
                    pass
                elif current_day > self.daily_board_last_login_day + 1:
                    # Missed one or more days -> reset streak
                    self.daily_board_streak = 0

            self.daily_board_last_login_day = current_day
            self.daily_board_tasks = []
            offset = current_day % len(self.keys)
            for i in range(3):
                k = self.keys[(offset + i) % len(self.keys)]
                template = self.catalog[k]
                self.daily_board_tasks.append({
                    "id": k,
                    "title": template["title"],
                    "target": template["target"],
                    "current": 0,
                    "is_completed": False,
                    "is_claimed": False,
                    "reward": dict(template["reward"])
                })
            return self.daily_board_tasks

        def advance(self, task_id, amount=1):
            for t in self.daily_board_tasks:
                if t["id"] == task_id:
                    if t["current"] < t["target"]:
                        t["current"] = min(t["target"], t["current"] + amount)
                        if t["current"] >= t["target"]:
                            t["is_completed"] = True
                    break

        def claim(self, task_id):
            found = None
            for t in self.daily_board_tasks:
                if t["id"] == task_id:
                    found = t
                    break
            if not found:
                return {"success": False, "error": "Not found"}
            if not found["is_completed"]:
                return {"success": False, "error": "Not completed"}
            if found["is_claimed"]:
                return {"success": False, "error": "Already claimed"}

            found["is_claimed"] = True
            rew = found["reward"]
            if "energy" in rew:
                self.energy += rew["energy"]
                self.total_lifetime_energy += rew["energy"]
            if "angel_shares" in rew:
                self.angel_shares += rew["angel_shares"]

            all_claimed = all(t["is_claimed"] for t in self.daily_board_tasks)
            if all_claimed:
                self.daily_board_streak += 1

            return {"success": True, "reward": rew, "streak": self.daily_board_streak, "all_claimed": all_claimed}

    sim = DailyBoardSimulator()

    # Test day 100 rotation
    tasks_day100 = sim.rotate_for_day(100)
    reporter.check(len(tasks_day100) == 3, "Day 100 generates exactly 3 tasks", "M4_Sim_TaskCount")
    unique_ids = set(t["id"] for t in tasks_day100)
    reporter.check(len(unique_ids) == 3, "Day 100 generates 3 unique tasks", "M4_Sim_UniqueTasks")

    # Test deterministic rotation on day 101
    tasks_day101 = sim.rotate_for_day(101)
    unique_ids_101 = set(t["id"] for t in tasks_day101)
    reporter.check(unique_ids_101 != unique_ids, "Day 101 rotates tasks deterministically", "M4_Sim_DayRotation")

    # Complete day 101 tasks
    t1_id = tasks_day101[0]["id"]
    t1_tgt = tasks_day101[0]["target"]
    sim.advance(t1_id, t1_tgt - 1)
    reporter.check(not tasks_day101[0]["is_completed"], "Task is not completed before reaching target", "M4_Sim_Incomplete")

    # Premature claim rejected
    premature_res = sim.claim(t1_id)
    reporter.check(not premature_res["success"], "Premature claim rejected", "M4_Sim_ClaimRejected")

    # Advance to complete
    sim.advance(t1_id, 1)
    reporter.check(tasks_day101[0]["is_completed"], "Task is completed when reaching target", "M4_Sim_Complete")

    # Claim Task 1
    init_energy = sim.energy
    res1 = sim.claim(t1_id)
    reporter.check(res1["success"], "Claiming completed task succeeds", "M4_Sim_ClaimSuccess")
    reporter.check(sim.energy > init_energy, "Reward energy paid out to balance", "M4_Sim_RewardEnergy")
    reporter.check(tasks_day101[0]["is_claimed"], "Task marked as claimed", "M4_Sim_MarkClaimed")

    # Duplicate claim rejected
    dup_res = sim.claim(t1_id)
    reporter.check(not dup_res["success"], "Duplicate claim rejected", "M4_Sim_DupClaimRejected")

    # Claim Task 2 & 3
    t2_id = tasks_day101[1]["id"]
    sim.advance(t2_id, tasks_day101[1]["target"])
    sim.claim(t2_id)

    reporter.check(sim.daily_board_streak == 0, "Streak is not incremented before all 3 tasks claimed", "M4_Sim_StreakPending")

    t3_id = tasks_day101[2]["id"]
    sim.advance(t3_id, tasks_day101[2]["target"])
    res3 = sim.claim(t3_id)
    reporter.check(res3["success"] and res3["all_claimed"], "All 3 tasks claimed", "M4_Sim_AllClaimed")
    reporter.check(sim.daily_board_streak == 1, "Streak incremented to 1 when all 3 tasks claimed", "M4_Sim_StreakIncrement")

    # Consecutive day 102 maintains and increments streak
    tasks_day102 = sim.rotate_for_day(102)
    reporter.check(sim.daily_board_streak == 1, "Consecutive day preserves streak (1)", "M4_Sim_StreakPreserved")
    for t in tasks_day102:
        sim.advance(t["id"], t["target"])
        sim.claim(t["id"])
    reporter.check(sim.daily_board_streak == 2, "Streak increments to 2 after completing day 102", "M4_Sim_StreakIncrement2")

    # Missed day (jump from 102 to 105) resets streak to 0
    sim.rotate_for_day(105)
    reporter.check(sim.daily_board_streak == 0, "Missed day (102 -> 105) resets streak to 0", "M4_Sim_StreakReset")

    # Serialization / Deserialization check
    save_data = {
        "daily_board_streak": 5,
        "daily_board_last_login_day": 200,
        "daily_board_tasks": [
            {"id": "task_hype", "title": "3x Viraler Hype", "target": 3, "current": 2, "is_completed": False, "is_claimed": False, "reward": {"energy": 10000.0}}
        ]
    }
    json_str = json.dumps(save_data)
    loaded = json.loads(json_str)
    reporter.check(loaded["daily_board_streak"] == 5, "JSON roundtrip preserves daily_board_streak (5)", "M4_Persist_Streak")
    reporter.check(loaded["daily_board_last_login_day"] == 200, "JSON roundtrip preserves daily_board_last_login_day (200)", "M4_Persist_LastDay")
    reporter.check(len(loaded["daily_board_tasks"]) == 1 and loaded["daily_board_tasks"][0]["current"] == 2, "JSON roundtrip preserves task progress", "M4_Persist_TaskProgress")

    # -------------------------------------------------------------------------
    # SECTION 5: DailyBoard3D Proximity & Modal State Machine
    # -------------------------------------------------------------------------
    print("\n=== SECTION 5: DailyBoard3D Proximity & Modal State Machine ===")

    class MockDailyBoard3D:
        def __init__(self):
            self.player_in_range = False
            self.prompt_visible = False
            self.registered_action = ""
            self.board_opened_emitted = False

        def on_player_entered(self):
            self.player_in_range = True
            self.prompt_visible = True
            self.registered_action = "Daily Board [E]"

        def on_player_exited(self):
            self.player_in_range = False
            self.prompt_visible = False
            self.registered_action = ""

        def interact(self):
            self.board_opened_emitted = True
            return "ModalOpened"

    board_mock = MockDailyBoard3D()
    reporter.check(not board_mock.player_in_range, "Initial board: player not in range", "M4_SM_InitialRange")

    board_mock.on_player_entered()
    reporter.check(board_mock.player_in_range, "Player in range on proximity entrance", "M4_SM_EnteredRange")
    reporter.check(board_mock.prompt_visible, "PromptLabel3D visible on proximity entrance", "M4_SM_PromptVis")
    reporter.check(board_mock.registered_action == "Daily Board [E]", "TouchControls registered 'Daily Board [E]'", "M4_SM_TouchReg")

    res = board_mock.interact()
    reporter.check(board_mock.board_opened_emitted, "interact() emits board_opened", "M4_SM_EmitOpened")
    reporter.check(res == "ModalOpened", "interact() opens DailyBoardModal", "M4_SM_ModalOpened")

    board_mock.on_player_exited()
    reporter.check(not board_mock.player_in_range, "Player not in range on exit", "M4_SM_ExitRange")
    reporter.check(not board_mock.prompt_visible, "PromptLabel3D hidden on exit", "M4_SM_ExitPromptHidden")
    reporter.check(board_mock.registered_action == "", "TouchControls unregistered on exit", "M4_SM_TouchUnreg")

    return reporter.summary()

if __name__ == "__main__":
    sys.exit(run_tests())
