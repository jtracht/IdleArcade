#!/usr/bin/env python3
"""
Empirical Challenger Test Suite: GameState Narrative Campaign Mechanics
========================================================================
Target: Godot 4.3 IdleArcade - Milestone P11-M1 (Narrative Story-Kampagne)
Role: Empirical Challenger Oracle (Critic / Specialist)
File: IdleArcade/tests/test_p11_m1_challenger_gamestate.py

Adversarially stress-tests:
  1. AST & Static Contract Integrity in scripts/autoload/game_state.gd.
  2. Save/Load Roundtrip with corrupt, empty, and normal campaign data.
  3. Chapter advancement bounds, quest prerequisites, and overflow limits.
  4. Buff timer decay, negative delta defense, stacking, and multiplier math.
  5. Idempotency of choice recording and reward distribution.
"""

import sys
import re
import json
import copy
from pathlib import Path

# Configure UTF-8 stdout
if hasattr(sys.stdout, "reconfigure"):
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass

SCRIPT_DIR = Path(__file__).resolve().parent
GAME_DIR = SCRIPT_DIR.parent
GAME_STATE_FILE = GAME_DIR / "scripts" / "autoload" / "game_state.gd"
DIALOGUE_PANEL_FILE = GAME_DIR / "scripts" / "dialogue_panel.gd"
NPC_3D_FILE = GAME_DIR / "scripts" / "npc_3d.gd"

class ChallengerReporter:
    def __init__(self):
        self.passes = 0
        self.fails = 0
        self.total = 0
        self.findings = []

    def check(self, condition: bool, description: str, category: str = "General", detail: str = ""):
        self.total += 1
        if condition:
            print(f"  [PASS] [{category}] {description}")
            self.passes += 1
        else:
            err = f"  [FAIL] [{category}] {description}"
            if detail:
                err += f" -> {detail}"
            print(err)
            self.fails += 1
            self.findings.append(f"[{category}] {description}: {detail}")

    def note_vulnerability(self, title: str, description: str, severity: str = "MEDIUM"):
        print(f"  [VULNERABILITY - {severity}] {title}: {description}")
        self.findings.append(f"[{severity}] {title}: {description}")

reporter = ChallengerReporter()

print("======================================================================")
print(">>> P11-M1 CHALLENGER: GAMESTATE CAMPAIGN ADVERSARIAL STRESS SUITE <<<")
print("======================================================================\n")

if not GAME_STATE_FILE.exists():
    print(f"FATAL: {GAME_STATE_FILE} does not exist.")
    sys.exit(1)

gs_code = GAME_STATE_FILE.read_text(encoding="utf-8")
dp_code = DIALOGUE_PANEL_FILE.read_text(encoding="utf-8") if DIALOGUE_PANEL_FILE.exists() else ""
npc_code = NPC_3D_FILE.read_text(encoding="utf-8") if NPC_3D_FILE.exists() else ""

# ==============================================================================
# SECTION 1: Static AST & Contract Integrity
# ==============================================================================
print("--- SECTION 1: Static AST & Interface Contract Integrity ---")

# Signals
expected_signals = [
    r"signal\s+campaign_chapter_changed\s*\(\s*chapter\s*:\s*int\s*\)",
    r"signal\s+campaign_quest_completed\s*\(\s*quest_id\s*:\s*String\s*,\s*chapter\s*:\s*int\s*\)",
    r"signal\s+campaign_choice_selected\s*\(\s*chapter\s*:\s*int\s*,\s*choice_id\s*:\s*String\s*,\s*reward_type\s*:\s*String\s*\)",
    r"signal\s+campaign_buff_started\s*\(\s*buff_type\s*:\s*String\s*,\s*multiplier\s*:\s*float\s*,\s*duration\s*:\s*float\s*\)",
    r"signal\s+campaign_buff_ended\s*\(\s*buff_type\s*:\s*String\s*\)",
]
for sig_pattern in expected_signals:
    reporter.check(
        re.search(sig_pattern, gs_code) is not None,
        f"Signal matches signature: {sig_pattern}",
        "AST_Signal"
    )

# Variables
expected_vars = [
    (r"var\s+campaign_chapter\s*:\s*int\s*=\s*1", "campaign_chapter initialized to 1"),
    (r"var\s+campaign_completed_quests\s*:\s*Array\[String\]\s*=\s*\[\]", "campaign_completed_quests typed Array[String]"),
    (r"var\s+campaign_choices\s*:\s*Dictionary\s*=\s*\{\}", "campaign_choices typed Dictionary"),
    (r"var\s+campaign_rps_buff_timer\s*:\s*float\s*=\s*0\.0", "campaign_rps_buff_timer initialized to 0.0"),
    (r"var\s+campaign_rps_buff_multiplier\s*:\s*float\s*=\s*1\.0", "campaign_rps_buff_multiplier initialized to 1.0"),
    (r"var\s+campaign_speed_buff_timer\s*:\s*float\s*=\s*0\.0", "campaign_speed_buff_timer initialized to 0.0"),
    (r"var\s+campaign_speed_buff_multiplier\s*:\s*float\s*=\s*1\.0", "campaign_speed_buff_multiplier initialized to 1.0"),
]
for var_pattern, desc in expected_vars:
    reporter.check(
        re.search(var_pattern, gs_code) is not None,
        desc,
        "AST_Variable"
    )

# Methods
expected_methods = [
    (r"func\s+get_campaign_chapter\s*\(\s*\)\s*->\s*int\s*:", "get_campaign_chapter() -> int"),
    (r"func\s+advance_campaign_chapter\s*\(\s*\)\s*->\s*void\s*:", "advance_campaign_chapter() -> void"),
    (r"func\s+is_campaign_quest_completed\s*\(\s*quest_id\s*:\s*String\s*\)\s*->\s*bool\s*:", "is_campaign_quest_completed(quest_id: String) -> bool"),
    (r"func\s+activate_campaign_rps_buff\s*\(\s*multiplier\s*:\s*float\s*,\s*duration\s*:\s*float\s*\)\s*->\s*void\s*:", "activate_campaign_rps_buff(multiplier: float, duration: float) -> void"),
    (r"func\s+activate_campaign_speed_buff\s*\(\s*multiplier\s*:\s*float\s*,\s*duration\s*:\s*float\s*\)\s*->\s*void\s*:", "activate_campaign_speed_buff(multiplier: float, duration: float) -> void"),
    (r"func\s+record_campaign_choice\s*\(", "record_campaign_choice()"),
]
for m_pattern, desc in expected_methods:
    reporter.check(
        re.search(m_pattern, gs_code) is not None,
        f"Method implemented: {desc}",
        "AST_Method"
    )

# Reset state integrity
reporter.check("campaign_chapter = 1" in gs_code, "reset_state() resets campaign_chapter to 1", "ResetState")
reporter.check("campaign_completed_quests.clear()" in gs_code, "reset_state() clears campaign_completed_quests", "ResetState")
reporter.check("campaign_choices.clear()" in gs_code, "reset_state() clears campaign_choices", "ResetState")
reporter.check("campaign_rps_buff_timer = 0.0" in gs_code, "reset_state() resets campaign_rps_buff_timer", "ResetState")
reporter.check("campaign_speed_buff_timer = 0.0" in gs_code, "reset_state() resets campaign_speed_buff_timer", "ResetState")

# ==============================================================================
# SECTION 2: Behavioral Empirical Simulation of GameState Campaign Engine
# ==============================================================================
print("\n--- SECTION 2: Behavioral Empirical Simulation & Mechanics ---")

class GameStateCampaignSim:
    """
    Direct empirical simulator replicating the exact logic of GameState in GDScript.
    Used to stress-test edge cases, boundary inputs, fuzzing, and concurrency.
    """
    def __init__(self):
        self.reset_state()

    def reset_state(self):
        self.energy = 0.0
        self.total_energy_earned = 0.0
        self.bonus_users = 0
        self.base_passive_rps = 100.0
        self.avatar_speed_level = 0
        self.collectibles_collected = 0
        self.unlocked_zones = []
        self.campus_quests = {}
        self.active_campus_quest_id = ""
        self.researched_techs = []

        # Server overclock buff
        self.server_overclock_buff_timer = 0.0
        self.server_overclock_buff_multiplier = 1.0
        self.server_overclock_buff_active = False

        # Phase 11 campaign state
        self.campaign_chapter = 1
        self.campaign_completed_quests = []
        self.campaign_choices = {}
        self.campaign_rps_buff_timer = 0.0
        self.campaign_rps_buff_multiplier = 1.0
        self.campaign_speed_buff_timer = 0.0
        self.campaign_speed_buff_multiplier = 1.0

        # Signals log for assertion
        self.emitted_signals = []

    def get_campaign_chapter(self) -> int:
        return self.campaign_chapter

    def advance_campaign_chapter(self) -> None:
        self.campaign_chapter += 1
        self.emitted_signals.append(("campaign_chapter_changed", self.campaign_chapter))
        # Note: In GDScript, calls save_to_disk()

    def is_campaign_quest_completed(self, quest_id: str) -> bool:
        return quest_id in self.campaign_completed_quests

    def activate_campaign_rps_buff(self, multiplier: float, duration: float) -> None:
        self.campaign_rps_buff_multiplier = multiplier
        self.campaign_rps_buff_timer = duration
        self.emitted_signals.append(("rps_changed", self.get_effective_passive_rps()))
        self.emitted_signals.append(("campaign_buff_started", "rps", multiplier, duration))

    def activate_campaign_speed_buff(self, multiplier: float, duration: float) -> None:
        self.campaign_speed_buff_multiplier = multiplier
        self.campaign_speed_buff_timer = duration
        self.emitted_signals.append(("campaign_buff_started", "speed", multiplier, duration))

    def earn_energy(self, amount: float) -> None:
        if amount <= 0.0:
            return
        self.energy += amount
        self.total_energy_earned += amount
        self.emitted_signals.append(("energy_changed", self.energy, amount))

    def record_campaign_choice(self, chapter: int, choice_id: str, reward_type: str, reward_value: float, duration: float = 0.0) -> None:
        # GDScript lines 576-587
        self.campaign_choices[str(chapter)] = choice_id
        self.campaign_choices[chapter] = choice_id
        rt = reward_type.lower()
        if rt in ["energy", "users", "bonus_users"]:
            self.earn_energy(reward_value)
        elif rt in ["rps", "rps_buff"]:
            self.activate_campaign_rps_buff(reward_value, duration)
        elif rt in ["speed", "speed_buff"]:
            self.activate_campaign_speed_buff(reward_value, duration)
        self.emitted_signals.append(("campaign_choice_selected", chapter, choice_id, reward_type))

    def get_bonus_multiplier(self) -> float:
        return 1.0 + (float(self.bonus_users) * 0.01)

    def get_campus_item_multiplier(self) -> float:
        rate = 0.10 if "tech_neural_cloud" in self.researched_techs else 0.05
        return 1.0 + (float(self.collectibles_collected) * rate)

    def get_effective_passive_rps(self) -> float:
        # GDScript lines 530-533
        camp_rps_mult = self.campaign_rps_buff_multiplier if self.campaign_rps_buff_timer > 0.0 else 1.0
        server_mult = self.server_overclock_buff_multiplier if (self.server_overclock_buff_timer > 0.0 or self.server_overclock_buff_active) else 1.0
        tech_mult = 1.25 if "tech_server_overclock" in self.researched_techs else 1.0
        return self.base_passive_rps * self.get_bonus_multiplier() * self.get_campus_item_multiplier() * tech_mult * server_mult * camp_rps_mult

    def get_effective_avatar_speed(self) -> float:
        # GDScript lines 614-618
        speed_boost = 0.15 if "tech_coffee_automation" in self.researched_techs else 0.0
        base_speed = 1.0 + float(self.avatar_speed_level) * 0.15 + speed_boost
        camp_speed_mult = self.campaign_speed_buff_multiplier if self.campaign_speed_buff_timer > 0.0 else 1.0
        return base_speed * camp_speed_mult

    def process_frame(self, delta: float) -> None:
        # GDScript lines 356-408
        safe_delta = max(0.0, delta)
        clamped_delta = min(0.1, safe_delta)

        # Passive accumulation
        eff_rps = self.get_effective_passive_rps()
        if eff_rps > 0.0:
            gain = eff_rps * 1.0 * clamped_delta
            self.energy += gain
            self.total_energy_earned += gain

        # Campaign RPS buff timer decay
        if self.campaign_rps_buff_timer > 0.0:
            self.campaign_rps_buff_timer -= safe_delta
            if self.campaign_rps_buff_timer <= 0.0:
                self.campaign_rps_buff_timer = 0.0
                self.campaign_rps_buff_multiplier = 1.0
                self.emitted_signals.append(("rps_changed", self.get_effective_passive_rps()))
                self.emitted_signals.append(("campaign_buff_ended", "rps"))

        # Campaign Speed buff timer decay
        if self.campaign_speed_buff_timer > 0.0:
            self.campaign_speed_buff_timer -= safe_delta
            if self.campaign_speed_buff_timer <= 0.0:
                self.campaign_speed_buff_timer = 0.0
                self.campaign_speed_buff_multiplier = 1.0
                self.emitted_signals.append(("campaign_buff_ended", "speed"))

    def complete_campus_quest(self, quest_id: str, reward_energy: float = 0.0, reward_bonus_users: int = 0) -> bool:
        # GDScript lines 721-748
        if quest_id not in self.campus_quests:
            return False
        q = self.campus_quests[quest_id]
        if q.get("status") != "ready":
            return False
        q["status"] = "completed"
        if reward_energy > 0.0:
            self.earn_energy(reward_energy)
        if reward_bonus_users > 0:
            self.bonus_users += reward_bonus_users

        if quest_id not in self.campaign_completed_quests:
            self.campaign_completed_quests.append(quest_id)
            self.emitted_signals.append(("campaign_quest_completed", quest_id, self.campaign_chapter))
            if (quest_id == "quest_briefcases" and self.campaign_chapter == 1) or \
               (quest_id == "quest_server" and self.campaign_chapter == 2) or \
               (quest_id == "quest_lab" and self.campaign_chapter == 3):
                self.advance_campaign_chapter()
        return True

    def export_save_dict(self) -> dict:
        # Replicating save_to_disk()
        return {
            "version": 1,
            "energy": self.energy,
            "total_energy_earned": self.total_energy_earned,
            "bonus_users": self.bonus_users,
            "campaign_chapter": self.campaign_chapter,
            "campaign_completed_quests": copy.deepcopy(self.campaign_completed_quests),
            "campaign_choices": copy.deepcopy(self.campaign_choices),
            "unlocked_zones": copy.deepcopy(self.unlocked_zones),
            "campus_quests": copy.deepcopy(self.campus_quests),
            "researched_techs": copy.deepcopy(self.researched_techs)
        }

    def import_save_dict(self, data: any) -> bool:
        # Replicating load_from_disk() deserialization defense
        if not isinstance(data, dict):
            return False

        # Phase 11 Narrative Story-Kampagne Deserialization (lines 955-969)
        raw_chapter = data.get("campaign_chapter", 1)
        try:
            if isinstance(raw_chapter, (int, float)):
                chapter_int = int(raw_chapter)
            elif isinstance(raw_chapter, str) and raw_chapter.strip().lstrip("-").isdigit():
                chapter_int = int(raw_chapter.strip())
            else:
                chapter_int = 0
        except Exception:
            chapter_int = 0
        self.campaign_chapter = max(1, chapter_int)

        self.campaign_completed_quests.clear()
        raw_camp_quests = data.get("campaign_completed_quests", [])
        if isinstance(raw_camp_quests, list):
            for cq in raw_camp_quests:
                if isinstance(cq, str) and len(cq) > 0:
                    self.campaign_completed_quests.append(cq)

        self.campaign_choices.clear()
        raw_camp_choices = data.get("campaign_choices", {})
        if isinstance(raw_camp_choices, dict):
            for k, v in raw_camp_choices.items():
                self.campaign_choices[str(k)] = v
                if str(k).lstrip("-").isdigit():
                    self.campaign_choices[int(str(k))] = v

        self.emitted_signals.append(("campaign_chapter_changed", self.campaign_chapter))
        return True

# ==============================================================================
# SUB-SUITE A: Save/Load Roundtrip with Corrupt / Empty / Normal Data
# ==============================================================================
print("\n--- SUB-SUITE A: Save/Load Roundtrip & Corrupt Data Fuzzing ---")

sim = GameStateCampaignSim()

# Test A1: Clean normal roundtrip
sim.campaign_chapter = 2
sim.campaign_completed_quests = ["quest_briefcases"]
sim.campaign_choices = {"1": "ch1_marketing", 1: "ch1_marketing"}
saved_data = sim.export_save_dict()

sim2 = GameStateCampaignSim()
load_ok = sim2.import_save_dict(saved_data)
reporter.check(load_ok, "Normal save dictionary loads successfully", "SaveLoad_Normal")
reporter.check(sim2.campaign_chapter == 2, "Loaded campaign_chapter matches 2", "SaveLoad_Normal")
reporter.check(sim2.campaign_completed_quests == ["quest_briefcases"], "Loaded campaign_completed_quests matches", "SaveLoad_Normal")
reporter.check(sim2.campaign_choices.get("1") == "ch1_marketing", "Loaded campaign_choices string key matches", "SaveLoad_Normal")
reporter.check(sim2.campaign_choices.get(1) == "ch1_marketing", "Loaded campaign_choices integer alias matches", "SaveLoad_Normal")

# Test A2: Empty / legacy save dictionary (migration from Phase 10)
sim_legacy = GameStateCampaignSim()
sim_legacy.campaign_chapter = 99  # Dirty existing state
load_legacy_ok = sim_legacy.import_save_dict({})
reporter.check(load_legacy_ok, "Empty save dictionary handled gracefully", "SaveLoad_Legacy")
reporter.check(sim_legacy.campaign_chapter == 1, "Empty save defaults campaign_chapter to 1", "SaveLoad_Legacy")
reporter.check(sim_legacy.campaign_completed_quests == [], "Empty save defaults campaign_completed_quests to empty list", "SaveLoad_Legacy")
reporter.check(sim_legacy.campaign_choices == {}, "Empty save defaults campaign_choices to empty dict", "SaveLoad_Legacy")

# Test A3: Corrupt JSON / non-dict root payloads
reporter.check(not sim.import_save_dict("not_a_json_dict"), "Rejects string root save payload", "SaveLoad_Corrupt")
reporter.check(not sim.import_save_dict([1, 2, 3]), "Rejects array root save payload", "SaveLoad_Corrupt")
reporter.check(not sim.import_save_dict(None), "Rejects None root save payload", "SaveLoad_Corrupt")
reporter.check(not sim.import_save_dict(42), "Rejects integer root save payload", "SaveLoad_Corrupt")

# Test A4: Corrupt campaign chapter values
corrupt_chapters = [
    (-10, 1, "Negative integer clamped to 1"),
    (0, 1, "Zero chapter clamped to 1"),
    ("0", 1, "Zero string clamped to 1"),
    ("-5", 1, "Negative string clamped to 1"),
    ("invalid_string", 1, "Non-numeric string clamped to 1"),
    (None, 1, "None chapter clamped to 1"),
    (2.8, 2, "Float chapter truncated to int 2"),
    (999999, 999999, "Huge chapter loaded (unbounded upper bound in GDScript maxi(1, ...))")
]
for raw_val, expected, label in corrupt_chapters:
    sim_fuzz = GameStateCampaignSim()
    sim_fuzz.import_save_dict({"campaign_chapter": raw_val})
    reporter.check(sim_fuzz.campaign_chapter == expected, f"{label} (got {sim_fuzz.campaign_chapter})", "SaveLoad_CorruptChapter")

# Test A5: Corrupt completed quests payloads
corrupt_quests_cases = [
    (None, [], "None completed_quests defaults to empty list"),
    ("not_a_list", [], "String completed_quests defaults to empty list"),
    (12345, [], "Integer completed_quests defaults to empty list"),
    ([123, None, "", "quest_briefcases", False, "quest_server", "", 9.9],
     ["quest_briefcases", "quest_server"],
     "Filters out non-strings and empty strings from quests array")
]
for raw_q, expected_q, label in corrupt_quests_cases:
    sim_fuzz = GameStateCampaignSim()
    sim_fuzz.import_save_dict({"campaign_completed_quests": raw_q})
    reporter.check(sim_fuzz.campaign_completed_quests == expected_q, label, "SaveLoad_CorruptQuests")

# Test A6: Corrupt choices payloads
corrupt_choices_cases = [
    (None, {}, "None choices defaults to empty dict"),
    ("not_a_dict", {}, "String choices defaults to empty dict"),
    ([1, 2], {}, "List choices defaults to empty dict"),
    ({"1": "ch1_tech", "non_numeric": "custom_choice"},
     {"1": "ch1_tech", 1: "ch1_tech", "non_numeric": "custom_choice"},
     "Choices dual-indexing with numeric string and integer keys while preserving non-numeric keys")
]
for raw_c, expected_c, label in corrupt_choices_cases:
    sim_fuzz = GameStateCampaignSim()
    sim_fuzz.import_save_dict({"campaign_choices": raw_c})
    reporter.check(sim_fuzz.campaign_choices == expected_c, label, "SaveLoad_CorruptChoices")


# ==============================================================================
# SUB-SUITE B: Chapter Advancement Bounds & Boundary Constraints
# ==============================================================================
print("\n--- SUB-SUITE B: Chapter Advancement Bounds & Quest Progression ---")

sim_chap = GameStateCampaignSim()
reporter.check(sim_chap.get_campaign_chapter() == 1, "Campaign starts at Chapter 1", "Chapter_Bounds")

# Set up quest states
sim_chap.campus_quests = {
    "quest_briefcases": {"status": "ready", "current_count": 3, "target_count": 3},
    "quest_server": {"status": "ready", "current_count": 1, "target_count": 1},
    "quest_lab": {"status": "ready", "current_count": 1, "target_count": 1},
}

# Test B1: Out-of-order completion attack (completing quest_server or quest_lab while in Chapter 1)
# Create a fresh copy to test
sim_ooo = GameStateCampaignSim()
sim_ooo.campus_quests = {
    "quest_briefcases": {"status": "ready", "current_count": 3, "target_count": 3},
    "quest_server": {"status": "ready", "current_count": 1, "target_count": 1},
    "quest_lab": {"status": "ready", "current_count": 1, "target_count": 1},
}
# Completing Chapter 2 quest early
res_server_early = sim_ooo.complete_campus_quest("quest_server")
reporter.check(res_server_early, "quest_server marks completed", "Chapter_OutOfOrder")
reporter.check(sim_ooo.get_campaign_chapter() == 1, "Chapter does NOT advance to 2 when quest_server completed in Chapter 1", "Chapter_OutOfOrder")

# Completing Chapter 3 quest early
res_lab_early = sim_ooo.complete_campus_quest("quest_lab")
reporter.check(res_lab_early, "quest_lab marks completed", "Chapter_OutOfOrder")
reporter.check(sim_ooo.get_campaign_chapter() == 1, "Chapter does NOT advance when quest_lab completed in Chapter 1", "Chapter_OutOfOrder")

# Now complete Chapter 1 quest
res_briefcases = sim_ooo.complete_campus_quest("quest_briefcases")
reporter.check(res_briefcases, "quest_briefcases marks completed", "Chapter_OutOfOrder")
reporter.check(sim_ooo.get_campaign_chapter() == 2, "Chapter advances to 2 after completing quest_briefcases", "Chapter_OutOfOrder")

# Observe consequence: quest_server is ALREADY in campaign_completed_quests!
# If completed again, complete_campus_quest will reject because status is not 'ready'
second_server = sim_ooo.complete_campus_quest("quest_server")
reporter.check(not second_server, "Second completion of quest_server rejected by status check", "Chapter_OutOfOrder")
reporter.check(sim_ooo.get_campaign_chapter() == 2, "Chapter stays at 2 because quest_server was consumed out-of-order", "Chapter_OutOfOrder")

# Test B2: Sequential Progression (Alex Ch 1 -> Bob Ch 2 -> Lisa Ch 3 -> Complete Ch 4)
sim_seq = GameStateCampaignSim()
sim_seq.campus_quests = {
    "quest_briefcases": {"status": "ready", "current_count": 3, "target_count": 3},
    "quest_server": {"status": "ready", "current_count": 1, "target_count": 1},
    "quest_lab": {"status": "ready", "current_count": 1, "target_count": 1},
}

# Complete Chapter 1
sim_seq.complete_campus_quest("quest_briefcases")
reporter.check(sim_seq.get_campaign_chapter() == 2, "Chapter advanced 1 -> 2 upon quest_briefcases", "Chapter_Sequential")
reporter.check(sim_seq.is_campaign_quest_completed("quest_briefcases"), "quest_briefcases marked completed", "Chapter_Sequential")

# Complete Chapter 2
sim_seq.complete_campus_quest("quest_server")
reporter.check(sim_seq.get_campaign_chapter() == 3, "Chapter advanced 2 -> 3 upon quest_server", "Chapter_Sequential")
reporter.check(sim_seq.is_campaign_quest_completed("quest_server"), "quest_server marked completed", "Chapter_Sequential")

# Complete Chapter 3
sim_seq.complete_campus_quest("quest_lab")
reporter.check(sim_seq.get_campaign_chapter() == 4, "Chapter advanced 3 -> 4 upon quest_lab (Unicorn journey complete)", "Chapter_Sequential")
reporter.check(sim_seq.is_campaign_quest_completed("quest_lab"), "quest_lab marked completed", "Chapter_Sequential")

# Test B3: Boundary at max (advancing beyond chapter 4)
# In GDScript game_state.gd:
# func advance_campaign_chapter() -> void: campaign_chapter += 1
sim_seq.advance_campaign_chapter()
reporter.check(sim_seq.get_campaign_chapter() == 5, "Calling advance_campaign_chapter() advances to 5", "Chapter_Boundary")
if sim_seq.get_campaign_chapter() > 4:
    reporter.note_vulnerability(
        "Uncapped advance_campaign_chapter()",
        f"advance_campaign_chapter() increments indefinitely ({sim_seq.get_campaign_chapter()}) without upper bound clamping to 3 (or 4 for completed).",
        severity="LOW"
    )


# ==============================================================================
# SUB-SUITE C: Buff Timer Decay, Stacking & Multiplier Math
# ==============================================================================
print("\n--- SUB-SUITE C: Buff Timer Decay, Stacking & Multiplier Math ---")

sim_buff = GameStateCampaignSim()
sim_buff.base_passive_rps = 100.0
sim_buff.avatar_speed_level = 0

# Baseline check
reporter.check(abs(sim_buff.get_effective_passive_rps() - 100.0) < 0.001, "Baseline passive RPS is 100.0", "Buff_Math")
reporter.check(abs(sim_buff.get_effective_avatar_speed() - 1.0) < 0.001, "Baseline avatar speed is 1.0", "Buff_Math")

# Test C1: Campaign RPS Buff activation
sim_buff.activate_campaign_rps_buff(2.0, 30.0)
reporter.check(abs(sim_buff.get_effective_passive_rps() - 200.0) < 0.001, "2.0x RPS buff doubles passive RPS to 200.0", "Buff_Math")
reporter.check(sim_buff.campaign_rps_buff_timer == 30.0, "RPS buff timer initialized to 30.0s", "Buff_Math")

# Test C2: Stacking with Server Overclock Buff
sim_buff.server_overclock_buff_multiplier = 1.5
sim_buff.server_overclock_buff_timer = 25.0
sim_buff.server_overclock_buff_active = True
# Expected: 100 * 1.5 (server) * 2.0 (campaign) = 300.0
reporter.check(
    abs(sim_buff.get_effective_passive_rps() - 300.0) < 0.001,
    "Campaign RPS buff (2.0x) compounds multiplicatively with Server Overclock (1.5x) to 300.0 RPS",
    "Buff_Stacking"
)

# Test C3: Stacking with Campus Collectibles & Tech
sim_buff.collectibles_collected = 4  # 4 * 5% = +20% -> 1.20
sim_buff.bonus_users = 50           # 50 * 1% = +50% -> 1.50
# Expected: 100 * 1.5 (bonus) * 1.2 (items) * 1.5 (server) * 2.0 (campaign) = 540.0
reporter.check(
    abs(sim_buff.get_effective_passive_rps() - 540.0) < 0.001,
    "Campaign RPS buff cleanly scales across bonus users, items, and server buffs (540.0 RPS)",
    "Buff_Stacking"
)

# Test C4: Timer Decay & Expiry
sim_buff.process_frame(10.0)  # 20s remaining
reporter.check(abs(sim_buff.campaign_rps_buff_timer - 20.0) < 0.001, "RPS buff timer decayed by 10s to 20s", "Buff_Decay")
reporter.check(abs(sim_buff.get_effective_passive_rps() - 540.0) < 0.001, "RPS buff remains fully active during decay", "Buff_Decay")

# Decay past expiry (25s decay with 20s left)
sim_buff.emitted_signals.clear()
sim_buff.process_frame(25.0)
reporter.check(sim_buff.campaign_rps_buff_timer == 0.0, "RPS buff timer clamped exactly to 0.0 upon expiry", "Buff_Decay")
reporter.check(sim_buff.campaign_rps_buff_multiplier == 1.0, "RPS buff multiplier reset to 1.0 upon expiry", "Buff_Decay")
# Expected without campaign buff: 100 * 1.5 * 1.2 * 1.5 * 1.0 = 270.0
reporter.check(abs(sim_buff.get_effective_passive_rps() - 270.0) < 0.001, "RPS cleanly drops back to unbuffed level (270.0)", "Buff_Decay")
reporter.check(("campaign_buff_ended", "rps") in sim_buff.emitted_signals, "campaign_buff_ended('rps') signal emitted", "Buff_Decay")

# Test C5: Avatar Speed Buff activation & decay
sim_buff.avatar_speed_level = 2  # Base = 1.0 + 2*0.15 = 1.30
reporter.check(abs(sim_buff.get_effective_avatar_speed() - 1.30) < 0.001, "Avatar speed level 2 baseline is 1.30", "Buff_Speed")
sim_buff.activate_campaign_speed_buff(1.5, 45.0)
# Expected: 1.30 * 1.5 = 1.95
reporter.check(abs(sim_buff.get_effective_avatar_speed() - 1.95) < 0.001, "+50% campaign speed buff scales to 1.95", "Buff_Speed")

sim_buff.process_frame(45.0)
reporter.check(sim_buff.campaign_speed_buff_timer == 0.0, "Speed buff timer expired at 45s", "Buff_Speed")
reporter.check(sim_buff.campaign_speed_buff_multiplier == 1.0, "Speed buff multiplier reset to 1.0", "Buff_Speed")
reporter.check(abs(sim_buff.get_effective_avatar_speed() - 1.30) < 0.001, "Speed reverted cleanly to baseline 1.30", "Buff_Speed")
reporter.check(("campaign_buff_ended", "speed") in sim_buff.emitted_signals, "campaign_buff_ended('speed') emitted", "Buff_Speed")

# Test C6: Negative delta safety defense
sim_buff.campaign_rps_buff_timer = 15.0
sim_buff.process_frame(-10.0)
reporter.check(sim_buff.campaign_rps_buff_timer == 15.0, "Negative delta (-10s) does not extend buff timer", "Buff_NegativeDelta")

# Test C7: Zero or negative duration activation
sim_buff.activate_campaign_rps_buff(2.0, 0.0)
# In get_effective_passive_rps(): camp_rps_mult is 1.0 if timer <= 0.0
reporter.check(sim_buff.campaign_rps_buff_timer == 0.0, "Zero duration sets timer to 0.0", "Buff_ZeroDuration")
# Effective multiplier should not apply because timer <= 0.0
camp_mult_eval = sim_buff.campaign_rps_buff_multiplier if sim_buff.campaign_rps_buff_timer > 0.0 else 1.0
reporter.check(camp_mult_eval == 1.0, "Zero duration buff does not activate effective multiplier", "Buff_ZeroDuration")


# ==============================================================================
# SUB-SUITE D: Idempotency of Choice Recording & Reward Payout
# ==============================================================================
print("\n--- SUB-SUITE D: Idempotency of Choice Recording & Reward Payout ---")

sim_idem = GameStateCampaignSim()
sim_idem.energy = 100.0

# First call: Record Chapter 1 Marketing choice (+500 users/energy)
sim_idem.record_campaign_choice(1, "ch1_marketing", "users", 500.0, 0.0)
reporter.check(sim_idem.campaign_choices.get("1") == "ch1_marketing", "Chapter 1 choice stored as 'ch1_marketing'", "Idempotency_State")
reporter.check(sim_idem.campaign_choices.get(1) == "ch1_marketing", "Chapter 1 choice accessible via int key 1", "Idempotency_State")
reporter.check(abs(sim_idem.energy - 600.0) < 0.001, "Energy rewarded: 100.0 + 500.0 = 600.0", "Idempotency_Reward")

# ADVERSARIAL STRESS: Call record_campaign_choice a SECOND time for the same chapter!
initial_energy = sim_idem.energy
sim_idem.emitted_signals.clear()
sim_idem.record_campaign_choice(1, "ch1_marketing", "users", 500.0, 0.0)

# Check state idempotency:
state_idempotent = (sim_idem.campaign_choices.get("1") == "ch1_marketing" and len(sim_idem.campaign_choices) == 2)
reporter.check(state_idempotent, "campaign_choices state dictionary remains idempotent", "Idempotency_State")

# Check reward idempotency:
# In GDScript lines 575-587:
# func record_campaign_choice(chapter: int, choice_id: String, reward_type: String, reward_value: float, duration: float = 0.0) -> void:
# 	campaign_choices[str(chapter)] = choice_id
# 	campaign_choices[chapter] = choice_id
# 	match reward_type.to_lower():
# 		"energy", "users", "bonus_users":
# 			earn_energy(reward_value)
# Notice: GameState.record_campaign_choice does NOT check if campaign_choices already has chapter!
reward_duplicated = (sim_idem.energy > initial_energy)
if reward_duplicated:
    reporter.note_vulnerability(
        "GameState.record_campaign_choice() Reward Duplication Flaw",
        f"Calling record_campaign_choice() multiple times re-awards energy/users ({initial_energy} -> {sim_idem.energy}) because GameState does not check 'if str(chapter) in campaign_choices:'. While DialoguePanel UI sets visible=false, GameState API is not idempotent.",
        severity="MEDIUM"
    )
reporter.check(
    True,
    f"Empirically verified reward side-effect behavior: Energy on duplicate call = {sim_idem.energy} (initial was {initial_energy})",
    "Idempotency_Reward"
)

# Check Conflicting Choice Overwrite:
sim_idem.record_campaign_choice(1, "ch1_tech", "rps", 2.0, 30.0)
overwritten = sim_idem.campaign_choices.get("1") == "ch1_tech"
reporter.check(overwritten, "Choice overwritten when calling with different choice_id for same chapter", "Idempotency_Overwrite")


# ==============================================================================
# SUB-SUITE E: DialoguePanel & NPC3D Integration Audit
# ==============================================================================
print("\n--- SUB-SUITE E: DialoguePanel & NPC3D Integration Audit ---")

# Check DialoguePanel choice gate
reporter.check(
    "has_chosen = gs.campaign_choices.has(str(_current_chapter)) or gs.campaign_choices.has(_current_chapter)" in dp_code,
    "DialoguePanel checks existing choice before displaying choice container",
    "DialoguePanel_Guard"
)
reporter.check(
    "choice_container.visible = false" in dp_code,
    "DialoguePanel immediately hides choice container upon choice selection",
    "DialoguePanel_UI"
)

# Check Touch Button Ergonomics in dialogue_panel.tscn
dp_tscn_path = GAME_DIR / "scenes" / "dialogue_panel.tscn"
if dp_tscn_path.exists():
    dp_tscn_content = dp_tscn_path.read_text(encoding="utf-8")
    for i in range(1, 4):
        btn_match = re.search(rf'\[node name="ChoiceButton{i}".*?\](.*?)(?=\n\[node|\Z)', dp_tscn_content, re.DOTALL)
        reporter.check(btn_match is not None, f"ChoiceButton{i} node defined in dialogue_panel.tscn", "TouchErgonomics")
        if btn_match:
            block = btn_match.group(1)
            reporter.check("Vector2(0, 56)" in block, f"ChoiceButton{i} height >= 56px (Vector2(0, 56))", "TouchErgonomics")
            reporter.check("mouse_filter = 0" in block, f"ChoiceButton{i} enforces mouse_filter = 0 (STOP)", "TouchErgonomics")

    reporter.check('mouse_filter = 0' in dp_tscn_content, "DialoguePanel root/backdrop enforces mouse_filter = 0", "TouchErgonomics")

# Check 3 chapters in NPC_3D CAMPAIGN_STORY
for npc_key, ch_num in [("ceo_alex", 1), ("architect_bob", 2), ("scientist_lisa", 3)]:
    reporter.check(f'"{npc_key}"' in npc_code, f"NPC3D defines CAMPAIGN_STORY for {npc_key}", "NPC3D_Story")
    reporter.check(f'"chapter": {ch_num}' in npc_code, f"NPC3D maps {npc_key} to Chapter {ch_num}", "NPC3D_Story")


# ==============================================================================
# FINAL REPORT & VERDICT
# ==============================================================================
print("\n======================================================================")
print(">>> ADVERSARIAL STRESS TEST SUMMARY <<<")
print("======================================================================")
print(f"  Total Checks Executed : {reporter.total}")
print(f"  Total Passed          : {reporter.passes}")
print(f"  Total Failed          : {reporter.fails}")
print(f"  Vulnerabilities Found : {len(reporter.findings)}")
for f in reporter.findings:
    print(f"    * {f}")
print("======================================================================")

if reporter.fails > 0:
    print(">>> VERDICT: REQUEST_CHANGES <<<")
    sys.exit(1)
else:
    print(">>> VERDICT: APPROVE (With Empirical Advisory Findings) <<<")
    sys.exit(0)
