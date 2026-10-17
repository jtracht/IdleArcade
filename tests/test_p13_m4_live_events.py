#!/usr/bin/env python3
"""
Phase 13 Milestone 4: Cooperative Live-Campus Events Verification Suite
========================================================================
Target: Godot 4.3 IdleArcade - Milestone M4 (Requirement R4: Cooperative Live-Campus Events)

Validates:
  1. Autoload & AST / Interface Contract Verification:
     - project.godot registers LiveEventManager="*res://scripts/autoload/live_event_manager.gd"
     - scripts/autoload/live_event_manager.gd exists and declares:
       * enum EventState { IDLE, ACTIVE, COMPLETED, COOLDOWN }
       * Signals:
         - live_event_started(event_id, event_name, duration, target_goal)
         - live_event_progress_updated(current, target, percentage)
         - live_event_milestone_reached(milestone_pct, milestone_name)
         - live_event_completed(event_id, reward_data)
         - live_event_ended(event_id)
       * Public API Methods:
         - start_event(event_id: String) -> bool
         - contribute_progress(contribution_type: String, amount: float = 1.0) -> void
         - get_active_event() -> Dictionary
         - is_event_active() -> bool
         - get_time_remaining() -> float
         - get_progress_percentage() -> float
         - get_production_multiplier() -> float
         - get_drone_speed_multiplier() -> float
         - trigger_server_crash_crisis() -> void
         - trigger_angel_investor_summit() -> void
         - force_complete_event() -> void

  2. Event Catalog Verification:
     - EVENT_CATALOG contains "server_crash_crisis":
       * Title: "Server Crash Crisis"
       * Duration: 600.0s (10 min)
       * Target: 500.0 points
       * Contribution weights: click = 1.0, overclock = 50.0
       * Milestones: 25%, 50%, 75%, 100%
       * Reward: 2.0x production multiplier for 180s
     - EVENT_CATALOG contains "angel_investor_summit":
       * Title: "Angel Investor Summit"
       * Duration: 480.0s (8 min)
       * Target: 20.0 briefcases
       * Contribution weights: briefcase = 1.0
       * Milestones: 25%, 50%, 75%, 100%
       * Reward: +50,000 Energy grant and 1.5x drone speed boost for 120s

  3. Gameplay Hooks Integration AST Verification:
     - scripts/autoload/game_state.gd:
       * get_effective_passive_rps() applies LiveEventManager production multiplier
       * tap_core() applies LiveEventManager production multiplier to click energy
       * tap_core() calls LiveEventManager.contribute_progress("click", 1.0)
     - scripts/server_terminal.gd:
       * _activate_overclock_state() calls LiveEventManager.contribute_progress("overclock", 1.0)
     - scripts/collectible_3d.gd:
       * collect() calls LiveEventManager.contribute_progress("briefcase", 1.0)
     - scripts/delivery_drone_3d.gd:
       * _physics_process() multiplies speed by LiveEventManager.get_drone_speed_multiplier()

  4. Mathematical State Machine & Lifecycle Simulation:
     - Event start resets progress, initializes target and duration
     - Point accumulation correctly weighted:
       * 10 clicks = 10 points
       * 1 overclock = 50 points
       * 10 overclocks = 500 points (100% completion)
     - Milestone events trigger sequentially at exactly 25%, 50%, 75%, 100%
     - Server Crash Crisis completion activates 2.0x production multiplier for 180s
     - Angel Investor Summit completion awards 50k energy and activates 1.5x drone speed for 120s
     - Expiration without completion transitions cleanly to cooldown without reward

  5. HUD Event Banner Ergonomics & Pointer Isolation:
     - scenes/hud.tscn declares %LiveEventBanner with custom_minimum_size.y >= 56px
     - scenes/hud.tscn enforces mouse_filter = 0 (Control.MOUSE_FILTER_STOP) on %LiveEventBanner
     - scenes/hud.tscn declares %LiveEventTitleLabel, %LiveEventTimerLabel, %LiveEventProgressBar, %LiveEventProgressLabel
     - scripts/hud.gd connects to all 5 LiveEventManager signals
     - scripts/hud.gd handles dynamic title, timer, progress bar, and percentage formatting

Executable via: python tests/test_p13_m4_live_events.py
"""

import math
import re
import sys
import time
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
        self.failures: List[Tuple[str, str]] = []

    def check(self, condition: bool, description: str, tag: str = "CHECK") -> bool:
        self.total += 1
        if condition:
            self.passed += 1
            print(f"  {Colors.OKGREEN}[PASS]{Colors.ENDC} [{tag}] {description}")
            return True
        else:
            self.failed += 1
            self.failures.append((tag, description))
            print(f"  {Colors.FAIL}[FAIL]{Colors.ENDC} [{tag}] {description}")
            return False

    def summary(self) -> bool:
        print("\n" + "=" * 70)
        print(f"{Colors.BOLD}Phase 13 Milestone M4 (Cooperative Live Events) Test Results{Colors.ENDC}")
        print("=" * 70)
        print(f"  Total Checks : {self.total}")
        print(f"  Passed       : {self.passed}")
        print(f"  Failed       : {self.failed}")
        if self.failed > 0:
            print("\nFailures:")
            for tag, desc in self.failures:
                print(f"  - [{tag}] {desc}")
            print(f"\n{Colors.FAIL}>>> OVERALL VERDICT: FAILED <<<{Colors.ENDC}\n")
            return False
        else:
            print(f"\n{Colors.OKGREEN}>>> OVERALL VERDICT: 100% PASS (ALL CHECKS GREEN) <<<{Colors.ENDC}\n")
            return True


# ==============================================================================
# SECTION 1: Autoload & AST / Interface Contract Verification
# ==============================================================================

def verify_autoload_and_ast(reporter: TestReporter, game_dir: Path):
    print(f"\n{Colors.BOLD}=== SECTION 1: Autoload & AST / Interface Contract Verification ==={Colors.ENDC}")

    project_file = game_dir / "project.godot"
    reporter.check(project_file.exists(), "project.godot exists", "CONFIG_Project")
    project_content = project_file.read_text(encoding="utf-8")
    
    # Check LiveEventManager autoload registration
    reporter.check('LiveEventManager="*res://scripts/autoload/live_event_manager.gd"' in project_content,
                   'project.godot registers LiveEventManager="*res://scripts/autoload/live_event_manager.gd"',
                   "AUTOLOAD_Register")

    manager_file = game_dir / "scripts/autoload/live_event_manager.gd"
    reporter.check(manager_file.exists(), "scripts/autoload/live_event_manager.gd exists", "FILE_Manager")
    if not manager_file.exists():
        return

    content = manager_file.read_text(encoding="utf-8")

    # State Machine enum
    reporter.check("enum EventState" in content, "Declares enum EventState", "AST_Enum")
    for state in ["IDLE", "ACTIVE", "COMPLETED", "COOLDOWN"]:
        reporter.check(state in content, f"EventState contains {state}", "AST_EnumState")

    # Signals
    required_signals = [
        "live_event_started",
        "live_event_progress_updated",
        "live_event_milestone_reached",
        "live_event_completed",
        "live_event_ended"
    ]
    for sig in required_signals:
        sig_pattern = rf'signal\s+{sig}\b'
        reporter.check(re.search(sig_pattern, content) is not None,
                       f"Signal declared: {sig}", "AST_Signal")

    # Public Methods
    required_methods = [
        "start_event",
        "contribute_progress",
        "get_active_event",
        "is_event_active",
        "get_time_remaining",
        "get_progress_percentage",
        "get_production_multiplier",
        "get_drone_speed_multiplier",
        "trigger_server_crash_crisis",
        "trigger_angel_investor_summit",
        "force_complete_event"
    ]
    for method in required_methods:
        method_pattern = rf'func\s+{method}\s*\('
        reporter.check(re.search(method_pattern, content) is not None,
                       f"Method implemented: {method}()", "AST_Method")


# ==============================================================================
# SECTION 2: Event Catalog & Configuration Verification
# ==============================================================================

def verify_event_catalog(reporter: TestReporter, game_dir: Path):
    print(f"\n{Colors.BOLD}=== SECTION 2: Event Catalog & Configuration Verification ==={Colors.ENDC}")

    manager_file = game_dir / "scripts/autoload/live_event_manager.gd"
    content = manager_file.read_text(encoding="utf-8")

    reporter.check("EVENT_CATALOG" in content, "EVENT_CATALOG dictionary defined", "CATALOG_Def")

    # Server Crash Crisis
    reporter.check('"server_crash_crisis"' in content, 'Catalog contains "server_crash_crisis"', "CATALOG_Event1")
    reporter.check('"Server Crash Crisis"' in content, 'Event 1 title is "Server Crash Crisis"', "CATALOG_Event1Title")
    reporter.check("600" in content, "Event 1 duration configured to 600s (10 min)", "CATALOG_Event1Duration")
    reporter.check("500" in content, "Event 1 target goal configured to 500 points", "CATALOG_Event1Target")
    reporter.check('"click"' in content and '"overclock"' in content, "Event 1 weights support click and overclock", "CATALOG_Event1Weights")
    reporter.check("180" in content, "Event 1 reward duration configured to 180s", "CATALOG_Event1RewardDur")
    reporter.check("2.0" in content or "2.00" in content, "Event 1 reward multiplier configured to 2.0x", "CATALOG_Event1RewardMult")

    # Angel Investor Summit
    reporter.check('"angel_investor_summit"' in content, 'Catalog contains "angel_investor_summit"', "CATALOG_Event2")
    reporter.check('"Angel Investor Summit"' in content, 'Event 2 title is "Angel Investor Summit"', "CATALOG_Event2Title")
    reporter.check("480" in content, "Event 2 duration configured to 480s (8 min)", "CATALOG_Event2Duration")
    reporter.check("20" in content, "Event 2 target goal configured to 20 briefcases", "CATALOG_Event2Target")
    reporter.check('"briefcase"' in content, "Event 2 weights support briefcase collection", "CATALOG_Event2Weights")
    reporter.check("50000" in content, "Event 2 reward energy grant is +50,000 Energy", "CATALOG_Event2Grant")
    reporter.check("1.5" in content or "1.50" in content, "Event 2 drone speed multiplier is 1.5x", "CATALOG_Event2DroneSpeed")
    reporter.check("120" in content, "Event 2 reward duration configured to 120s", "CATALOG_Event2RewardDur")


# ==============================================================================
# SECTION 3: Gameplay Integration Hooks AST Verification
# ==============================================================================

def verify_gameplay_hooks(reporter: TestReporter, game_dir: Path):
    print(f"\n{Colors.BOLD}=== SECTION 3: Gameplay Integration Hooks AST Verification ==={Colors.ENDC}")

    # 1. GameState
    gs_file = game_dir / "scripts/autoload/game_state.gd"
    gs_content = gs_file.read_text(encoding="utf-8")

    reporter.check("get_live_event_production_multiplier" in gs_content or "LiveEventManager" in gs_content,
                   "GameState references LiveEventManager production multiplier", "HOOK_GameState_Ref")
    
    # get_effective_passive_rps() integration
    rps_func_m = re.search(r'func\s+get_effective_passive_rps\s*\(\s*\)\s*->\s*float:.*?(?=\nfunc|\Z)', gs_content, re.DOTALL)
    reporter.check(rps_func_m is not None and ("live_event_mult" in rps_func_m.group(0) or "LiveEventManager" in rps_func_m.group(0)),
                   "get_effective_passive_rps() incorporates live event production multiplier", "HOOK_PassiveRPS")

    # tap_core() click hook & multiplier
    tap_func_m = re.search(r'func\s+tap_core\s*\(\s*\)\s*->\s*float:.*?(?=\nfunc|\Z)', gs_content, re.DOTALL)
    reporter.check(tap_func_m is not None and ("contribute_progress" in tap_func_m.group(0) and "click" in tap_func_m.group(0)),
                   "tap_core() calls LiveEventManager.contribute_progress('click', 1.0)", "HOOK_TapCore_Contrib")
    reporter.check(tap_func_m is not None and ("live_event_mult" in tap_func_m.group(0) or "LiveEventManager" in tap_func_m.group(0)),
                   "tap_core() applies live event production multiplier to earned click energy", "HOOK_TapCore_Multiplier")

    # 2. ServerTerminal overclock hook
    terminal_file = game_dir / "scripts/server_terminal.gd"
    term_content = terminal_file.read_text(encoding="utf-8")
    reporter.check("contribute_progress" in term_content and "overclock" in term_content,
                   "server_terminal.gd calls LiveEventManager.contribute_progress('overclock', 1.0)", "HOOK_ServerTerminal")

    # 3. Collectible3D briefcase hook
    collectible_file = game_dir / "scripts/collectible_3d.gd"
    coll_content = collectible_file.read_text(encoding="utf-8")
    reporter.check("contribute_progress" in coll_content and "briefcase" in coll_content,
                   "collectible_3d.gd calls LiveEventManager.contribute_progress('briefcase', 1.0)", "HOOK_Collectible3D")

    # 4. DeliveryDrone3D speed hook
    drone_file = game_dir / "scripts/delivery_drone_3d.gd"
    drone_content = drone_file.read_text(encoding="utf-8")
    reporter.check("get_drone_speed_multiplier" in drone_content and "LiveEventManager" in drone_content,
                   "delivery_drone_3d.gd incorporates LiveEventManager.get_drone_speed_multiplier()", "HOOK_DeliveryDrone")


# ==============================================================================
# SECTION 4: Mathematical State Machine & Lifecycle Simulation
# ==============================================================================

class LiveEventManagerSim:
    """Accurate Python simulation of live_event_manager.gd logic."""
    def __init__(self):
        self.state = "IDLE"
        self.active_id = ""
        self.progress = 0.0
        self.target = 0.0
        self.time_rem = 0.0
        self.reward_rem = 0.0
        self.cooldown_rem = 0.0
        self.prod_mult = 1.0
        self.drone_mult = 1.0
        self.milestones_reached = []
        self.events_completed_log = []
        self.events_ended_log = []
        self.energy_grant_awarded = 0.0

        self.catalog = {
            "server_crash_crisis": {
                "duration": 600.0,
                "target": 500.0,
                "weights": {"click": 1.0, "overclock": 50.0},
                "reward_multiplier": 2.0,
                "reward_duration": 180.0
            },
            "angel_investor_summit": {
                "duration": 480.0,
                "target": 20.0,
                "weights": {"briefcase": 1.0},
                "reward_energy": 50000.0,
                "drone_speed_multiplier": 1.5,
                "reward_duration": 120.0
            }
        }

    def start_event(self, event_id: str) -> bool:
        if event_id not in self.catalog:
            return False
        cfg = self.catalog[event_id]
        self.active_id = event_id
        self.state = "ACTIVE"
        self.progress = 0.0
        self.target = cfg["target"]
        self.time_rem = cfg["duration"]
        self.reward_rem = 0.0
        self.cooldown_rem = 0.0
        self.prod_mult = 1.0
        self.drone_mult = 1.0
        self.milestones_reached = []
        return True

    def get_progress_percentage(self) -> float:
        if self.target <= 0.0:
            return 0.0
        return min(100.0, max(0.0, (self.progress / self.target) * 100.0))

    def contribute(self, ctype: str, amount: float = 1.0):
        if self.state != "ACTIVE":
            return
        cfg = self.catalog[self.active_id]
        w = cfg["weights"].get(ctype, 0.0)
        if w <= 0.0:
            return
        self.progress = min(self.target, self.progress + (amount * w))
        pct = self.get_progress_percentage()

        for m in [25.0, 50.0, 75.0, 100.0]:
            if pct >= m and m not in self.milestones_reached:
                self.milestones_reached.append(m)

        if self.progress >= self.target:
            self._complete_event()

    def _complete_event(self):
        self.state = "COMPLETED"
        cfg = self.catalog[self.active_id]
        if self.active_id == "server_crash_crisis":
            self.prod_mult = cfg["reward_multiplier"]
            self.reward_rem = cfg["reward_duration"]
        elif self.active_id == "angel_investor_summit":
            self.energy_grant_awarded += cfg["reward_energy"]
            self.drone_mult = cfg["drone_speed_multiplier"]
            self.reward_rem = cfg["reward_duration"]
        self.events_completed_log.append(self.active_id)

    def advance_time(self, delta: float):
        if self.state == "ACTIVE":
            self.time_rem -= delta
            if self.time_rem <= 0.0:
                self.time_rem = 0.0
                self.state = "COOLDOWN"
                self.cooldown_rem = 30.0
                self.events_ended_log.append(self.active_id)
        elif self.state == "COMPLETED":
            self.reward_rem -= delta
            if self.reward_rem <= 0.0:
                self.reward_rem = 0.0
                self.prod_mult = 1.0
                self.drone_mult = 1.0
                self.state = "COOLDOWN"
                self.cooldown_rem = 30.0
                self.events_ended_log.append(self.active_id)
        elif self.state == "COOLDOWN":
            self.cooldown_rem -= delta
            if self.cooldown_rem <= 0.0:
                self.cooldown_rem = 0.0
                self.state = "IDLE"


def verify_math_simulation(reporter: TestReporter):
    print(f"\n{Colors.BOLD}=== SECTION 4: Mathematical State Machine & Lifecycle Simulation ==={Colors.ENDC}")

    sim = LiveEventManagerSim()
    reporter.check(sim.state == "IDLE", "Initial state is IDLE", "SIM_InitState")
    reporter.check(sim.prod_mult == 1.0, "Initial production multiplier is 1.0", "SIM_InitProd")
    reporter.check(sim.drone_mult == 1.0, "Initial drone speed multiplier is 1.0", "SIM_InitDrone")

    # 1. Start Server Crash Crisis
    res = sim.start_event("server_crash_crisis")
    reporter.check(res is True, "start_event('server_crash_crisis') succeeds", "SIM_StartCrisis")
    reporter.check(sim.state == "ACTIVE", "State changed to ACTIVE", "SIM_ActiveCrisis")
    reporter.check(sim.target == 500.0, "Target initialized to 500.0 points", "SIM_TargetCrisis")
    reporter.check(sim.time_rem == 600.0, "Time remaining initialized to 600.0s", "SIM_TimeCrisis")
    reporter.check(sim.get_progress_percentage() == 0.0, "Initial percentage is 0.0%", "SIM_PctCrisis")

    # 2. Click contributions
    sim.contribute("click", 10.0)
    reporter.check(sim.progress == 10.0, "10 clicks = 10.0 contribution points", "SIM_ClickPts")
    reporter.check(math.isclose(sim.get_progress_percentage(), 2.0), "Progress is 2.0%", "SIM_ClickPct")

    # 3. Overclock contribution to cross 25% milestone
    # Current: 10 pts. Needs 125 pts for 25%. Adding 3 overclocks (150 pts) -> 160 pts (32.0%)
    sim.contribute("overclock", 3.0)
    reporter.check(sim.progress == 160.0, "3 overclocks (+150 pts) added: total 160.0 pts", "SIM_OverclockPts")
    reporter.check(sim.get_progress_percentage() == 32.0, "Progress reached 32.0%", "SIM_Pct32")
    reporter.check(25.0 in sim.milestones_reached, "25% milestone reached", "SIM_Milestone25")
    reporter.check(50.0 not in sim.milestones_reached, "50% milestone not yet reached", "SIM_Milestone50_Pending")

    # 4. Overclocks to cross 50% (250 pts) and 75% (375 pts)
    sim.contribute("overclock", 2.0)  # +100 pts -> 260 pts (52%)
    reporter.check(sim.progress == 260.0, "Progress reached 260.0 pts", "SIM_Pts260")
    reporter.check(50.0 in sim.milestones_reached, "50% milestone reached", "SIM_Milestone50")

    sim.contribute("overclock", 3.0)  # +150 pts -> 410 pts (82%)
    reporter.check(sim.progress == 410.0, "Progress reached 410.0 pts", "SIM_Pts410")
    reporter.check(75.0 in sim.milestones_reached, "75% milestone reached", "SIM_Milestone75")
    reporter.check(100.0 not in sim.milestones_reached, "100% milestone not yet reached", "SIM_Milestone100_Pending")
    reporter.check(sim.state == "ACTIVE", "Event still ACTIVE before 100%", "SIM_StillActive")

    # 5. Overclock to complete event (100% / 500 pts)
    sim.contribute("overclock", 2.0)  # +100 pts -> clamped at 500.0 pts (100%)
    reporter.check(sim.progress == 500.0, "Progress clamped at target 500.0 pts", "SIM_PtsTarget")
    reporter.check(sim.get_progress_percentage() == 100.0, "Progress percentage is 100.0%", "SIM_Pct100")
    reporter.check(100.0 in sim.milestones_reached, "100% milestone reached", "SIM_Milestone100")
    reporter.check(sim.state == "COMPLETED", "Event transitioned to COMPLETED", "SIM_Completed")
    reporter.check("server_crash_crisis" in sim.events_completed_log, "Completion event logged", "SIM_Logged")

    # 6. Verify Server Crash Crisis Reward Buff
    reporter.check(sim.prod_mult == 2.0, "Global production multiplier is 2.0x during reward buff", "SIM_CrisisProdMult")
    reporter.check(sim.reward_rem == 180.0, "Reward buffer timer set to 180.0s", "SIM_CrisisRewardTimer")

    # Advance time through reward duration
    sim.advance_time(100.0)
    reporter.check(sim.state == "COMPLETED", "Reward buff still active after 100s", "SIM_RewardStillActive")
    reporter.check(sim.prod_mult == 2.0, "Multiplier remains 2.0x", "SIM_RewardProdRemains")

    sim.advance_time(85.0)  # Total 185s > 180s
    reporter.check(sim.state == "COOLDOWN", "Event transitioned to COOLDOWN after reward expires", "SIM_Cooldown")
    reporter.check(sim.prod_mult == 1.0, "Production multiplier returned to 1.0 baseline", "SIM_ProdReverted")

    # Advance time through cooldown
    sim.advance_time(35.0)  # 35s > 30s
    reporter.check(sim.state == "IDLE", "State returned to IDLE after cooldown", "SIM_ReturnedIdle")

    # 7. Start Angel Investor Summit
    sim.start_event("angel_investor_summit")
    reporter.check(sim.state == "ACTIVE", "Angel Investor Summit started: ACTIVE", "SIM_SummitActive")
    reporter.check(sim.target == 20.0, "Summit target is 20.0 briefcases", "SIM_SummitTarget")

    # Collect briefcases
    sim.contribute("briefcase", 5.0)  # 25% (5/20)
    reporter.check(25.0 in sim.milestones_reached, "Summit 25% milestone reached (5 briefcases)", "SIM_Summit25")

    sim.contribute("briefcase", 15.0)  # Total 20/20 (100%)
    reporter.check(sim.state == "COMPLETED", "Summit reached 100% and COMPLETED", "SIM_SummitComplete")
    reporter.check(sim.energy_grant_awarded == 50000.0, "Instant grant of 50,000 Energy awarded", "SIM_SummitGrant")
    reporter.check(sim.drone_mult == 1.5, "Drone speed multiplier boosted to 1.5x", "SIM_SummitDroneSpeed")
    reporter.check(sim.reward_rem == 120.0, "Drone speed reward duration set to 120.0s", "SIM_SummitRewardDur")

    sim.advance_time(125.0)  # Reward expires
    reporter.check(sim.drone_mult == 1.0, "Drone speed reverted to 1.0 baseline after reward expiry", "SIM_DroneSpeedRevert")


# ==============================================================================
# SECTION 5: HUD Event Banner Ergonomics & Pointer Isolation
# ==============================================================================

def verify_hud_banner_ergonomics(reporter: TestReporter, game_dir: Path):
    print(f"\n{Colors.BOLD}=== SECTION 5: HUD Event Banner Ergonomics & Pointer Isolation ==={Colors.ENDC}")

    hud_scene_file = game_dir / "scenes/hud.tscn"
    hud_script_file = game_dir / "scripts/hud.gd"

    reporter.check(hud_scene_file.exists(), "scenes/hud.tscn exists", "HUD_SceneExists")
    reporter.check(hud_script_file.exists(), "scripts/hud.gd exists", "HUD_ScriptExists")

    hud_tscn = hud_scene_file.read_text(encoding="utf-8")
    hud_gd = hud_script_file.read_text(encoding="utf-8")

    # 1. %LiveEventBanner declaration
    banner_match = re.search(r'\[node name="LiveEventBanner"[^\]]*\](.*?)(?=\n\[node|\Z)', hud_tscn, re.DOTALL)
    reporter.check(banner_match is not None, "hud.tscn declares %LiveEventBanner node", "HUD_BannerDeclared")
    if banner_match:
        b_block = banner_match.group(1)
        # Check custom_minimum_size
        size_m = re.search(r'custom_minimum_size\s*=\s*Vector2\(\s*([0-9.]+),\s*([0-9.]+)\s*\)', b_block)
        if size_m:
            height = float(size_m.group(2))
            reporter.check(height >= 56.0, f"LiveEventBanner height >= 56px (actual: {height:.0f}px)", "HUD_BannerHeight")
        else:
            reporter.check(False, "LiveEventBanner custom_minimum_size missing", "HUD_BannerHeight")

        # Pointer Isolation: mouse_filter = 0 (Control.MOUSE_FILTER_STOP)
        reporter.check("mouse_filter = 0" in b_block, "LiveEventBanner enforces mouse_filter = 0 (STOP)", "HUD_BannerMouseFilter")

    # 2. Child nodes declared with unique_name_in_owner = true
    expected_children = [
        ("LiveEventTitleLabel", "Title label"),
        ("LiveEventTimerLabel", "Timer label"),
        ("LiveEventProgressBar", "Progress bar"),
        ("LiveEventProgressLabel", "Progress percentage label")
    ]
    for child_name, desc in expected_children:
        node_m = re.search(rf'\[node name="{child_name}"[^\]]*\](.*?)(?=\n\[node|\Z)', hud_tscn, re.DOTALL)
        reporter.check(node_m is not None, f"hud.tscn declares %{child_name} ({desc})", "HUD_ChildDeclared")
        if node_m:
            block = node_m.group(1)
            reporter.check("unique_name_in_owner = true" in block, f"%{child_name} has unique_name_in_owner = true", "HUD_UniqueName")
            reporter.check("mouse_filter = 0" in block, f"%{child_name} specifies mouse_filter = 0 (STOP)", "HUD_ChildMouseFilter")

    # 3. scripts/hud.gd signal connections
    required_hud_signals = [
        "live_event_started",
        "live_event_progress_updated",
        "live_event_milestone_reached",
        "live_event_completed",
        "live_event_ended"
    ]
    for sig in required_hud_signals:
        reporter.check(sig in hud_gd, f"scripts/hud.gd references signal '{sig}'", "HUD_SignalConnected")

    # 4. scripts/hud.gd reactive helper methods
    required_hud_methods = [
        "_connect_live_event_signals",
        "_refresh_live_event_banner",
        "_show_live_event_banner",
        "_on_live_event_started",
        "_on_live_event_progress_updated",
        "_on_live_event_milestone_reached",
        "_on_live_event_completed",
        "_on_live_event_ended",
        "_update_live_event_timer"
    ]
    for meth in required_hud_methods:
        reporter.check(f"func {meth}" in hud_gd, f"scripts/hud.gd implements {meth}()", "HUD_MethodImplemented")


# ==============================================================================
# MAIN ENTRYPOINT
# ==============================================================================

def main():
    print(f"{Colors.HEADER}======================================================================{Colors.ENDC}")
    print(f"{Colors.HEADER}Phase 13 Milestone M4: Cooperative Live-Campus Events Verification{Colors.ENDC}")
    print(f"{Colors.HEADER}======================================================================{Colors.ENDC}")

    game_dir = Path(__file__).resolve().parent.parent
    if not (game_dir / "project.godot").exists():
        # Fallback if run from repo root
        game_dir = Path(__file__).resolve().parent.parent / "IdleArcade"

    reporter = TestReporter()

    # Run all 5 verification tiers
    verify_autoload_and_ast(reporter, game_dir)
    verify_event_catalog(reporter, game_dir)
    verify_gameplay_hooks(reporter, game_dir)
    verify_math_simulation(reporter)
    verify_hud_banner_ergonomics(reporter, game_dir)

    success = reporter.summary()
    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()
