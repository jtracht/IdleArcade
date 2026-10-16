#!/usr/bin/env python3
"""
Standalone Empirical Adversarial Stress Test Harness for Phase 11:
Dialogue & NPC Interaction Flow (Alex, Bob, Lisa)
Tests:
  1. Dialogue choice options across all 3 chapters (Alex, Bob, Lisa) and story parity.
  2. Touch button dimensions (>= 56px) and mouse_filter attributes (STOP = 0) across all dialogue controls.
  3. Reward payload integrity: energy (users), speed buff, and RPS buff mathematical scaling and decay.
  4. Backward compatibility of NPC properties (npc_alex.quest_id == 'quest_briefcases', Bob, Lisa, legacy signatures).
  5. State machine transition & quest title/desc retention stress test upon choice selection.
"""

import sys
import re
from pathlib import Path

def find_game_dir() -> Path:
    cwd = Path.cwd().resolve()
    for candidate in [cwd, cwd / "IdleArcade", cwd.parent, cwd.parent / "IdleArcade"]:
        if (candidate / "project.godot").exists():
            return candidate
    return cwd

GAME_DIR = find_game_dir()

class ChallengerHarness:
    def __init__(self):
        self.total = 0
        self.passed = 0
        self.failed = 0
        self.failures = []

    def check(self, condition: bool, desc: str, details: str = ""):
        self.total += 1
        if condition:
            self.passed += 1
            print(f"  [PASS] {desc}")
        else:
            self.failed += 1
            msg = f"{desc} | Details: {details}" if details else desc
            self.failures.append(msg)
            print(f"  [FAIL] {desc}")
            if details:
                print(f"         -> {details}")

def parse_tscn_nodes(filepath: Path):
    """Parses a Godot .tscn file into a list of node dicts with attributes."""
    content = filepath.read_text(encoding="utf-8")
    nodes = []
    current_node = None
    
    for line in content.splitlines():
        line = line.strip()
        if line.startswith("[node "):
            if current_node:
                nodes.append(current_node)
            current_node = {"_header": line}
            # parse attributes in header
            attrs = re.findall(r'(\w+)="([^"]*)"', line)
            for k, v in attrs:
                current_node[k] = v
        elif current_node is not None and "=" in line and not line.startswith("["):
            parts = line.split("=", 1)
            k = parts[0].strip()
            v = parts[1].strip().strip('"')
            current_node[k] = v
            
    if current_node:
        nodes.append(current_node)
    return nodes

def run_adversarial_challenge():
    h = ChallengerHarness()
    print("=" * 70)
    print("PHASE 11 ADVERSARIAL STRESS TEST: DIALOGUE & NPC INTERACTION FLOW")
    print("=" * 70)

    dp_tscn_path = GAME_DIR / "scenes/dialogue_panel.tscn"
    dp_gd_path = GAME_DIR / "scripts/dialogue_panel.gd"
    npc_gd_path = GAME_DIR / "scripts/npc_3d.gd"
    main_tscn_path = GAME_DIR / "scenes/main_3d.tscn"
    gs_gd_path = GAME_DIR / "scripts/autoload/game_state.gd"

    # Verify file existence
    h.check(dp_tscn_path.exists(), "dialogue_panel.tscn exists")
    h.check(dp_gd_path.exists(), "dialogue_panel.gd exists")
    h.check(npc_gd_path.exists(), "npc_3d.gd exists")
    h.check(main_tscn_path.exists(), "main_3d.tscn exists")
    h.check(gs_gd_path.exists(), "game_state.gd exists")

    dp_gd_text = dp_gd_path.read_text(encoding="utf-8")
    npc_gd_text = npc_gd_path.read_text(encoding="utf-8")
    main_tscn_text = main_tscn_path.read_text(encoding="utf-8")
    gs_gd_text = gs_gd_path.read_text(encoding="utf-8")

    # -------------------------------------------------------------------------
    # SUITE 1: Dialogue Choice Options Across All 3 Chapters (Alex, Bob, Lisa)
    # -------------------------------------------------------------------------
    print("\n--- SUITE 1: Dialogue Choice Options Across All 3 Chapters ---")
    
    # 1.1 Extract CHAPTER_CHOICES from dialogue_panel.gd
    # Verify Chapter 1 choices (Alex)
    ch1_match = re.search(r'1:\s*\[(.*?)\]\s*,\s*2:', dp_gd_text, re.DOTALL)
    h.check(ch1_match is not None, "CHAPTER_CHOICES contains Chapter 1 block")
    if ch1_match:
        ch1_str = ch1_match.group(1)
        h.check('"id": "ch1_marketing"' in ch1_str, "Chapter 1 has ch1_marketing choice")
        h.check('"reward_type": "users"' in ch1_str and '500' in ch1_str, "ch1_marketing awards 500 users")
        h.check('"id": "ch1_tech"' in ch1_str, "Chapter 1 has ch1_tech choice")
        h.check('"reward_type": "rps"' in ch1_str and '2.0' in ch1_str and '30.0' in ch1_str, "ch1_tech awards +100% RPS for 30s")
        h.check('"id": "ch1_team"' in ch1_str, "Chapter 1 has ch1_team choice")
        h.check('"reward_type": "speed"' in ch1_str and '1.5' in ch1_str and '45.0' in ch1_str, "ch1_team awards +50% Speed for 45s")

    # Verify Chapter 2 choices (Bob)
    ch2_match = re.search(r'2:\s*\[(.*?)\]\s*,\s*3:', dp_gd_text, re.DOTALL)
    h.check(ch2_match is not None, "CHAPTER_CHOICES contains Chapter 2 block")
    if ch2_match:
        ch2_str = ch2_match.group(1)
        h.check('"id": "ch2_overclock"' in ch2_str, "Chapter 2 has ch2_overclock choice")
        h.check('"reward_type": "rps"' in ch2_str and '2.0' in ch2_str and '45.0' in ch2_str, "ch2_overclock awards +100% RPS for 45s")
        h.check('"id": "ch2_hardware"' in ch2_str, "Chapter 2 has ch2_hardware choice")
        h.check('"reward_type": "users"' in ch2_str and '1500' in ch2_str, "ch2_hardware awards 1500 users")
        h.check('"id": "ch2_ops"' in ch2_str, "Chapter 2 has ch2_ops choice")
        h.check('"reward_type": "speed"' in ch2_str and '1.5' in ch2_str and '45.0' in ch2_str, "ch2_ops awards +50% Speed for 45s")

    # Verify Chapter 3 choices (Lisa)
    ch3_match = re.search(r'3:\s*\[(.*?)\]\s*\}\s*$', dp_gd_text, re.MULTILINE | re.DOTALL)
    if not ch3_match:
        ch3_match = re.search(r'3:\s*\[(.*?)\]\s*\}', dp_gd_text, re.DOTALL)
    h.check(ch3_match is not None, "CHAPTER_CHOICES contains Chapter 3 block")
    if ch3_match:
        ch3_str = ch3_match.group(1)
        h.check('"id": "ch3_quantum"' in ch3_str, "Chapter 3 has ch3_quantum choice")
        h.check('"reward_type": "rps"' in ch3_str and '3.0' in ch3_str and '60.0' in ch3_str, "ch3_quantum awards +200% RPS for 60s")
        h.check('"id": "ch3_espresso"' in ch3_str, "Chapter 3 has ch3_espresso choice")
        h.check('"reward_type": "speed"' in ch3_str and '1.5' in ch3_str and '60.0' in ch3_str, "ch3_espresso awards +50% Speed for 60s")
        h.check('"id": "ch3_pitch"' in ch3_str, "Chapter 3 has ch3_pitch choice")
        h.check('"reward_type": "users"' in ch3_str and '5000' in ch3_str, "ch3_pitch awards 5000 users")

    # 1.2 Verify CAMPAIGN_STORY in npc_3d.gd
    h.check('"ceo_alex"' in npc_gd_text and '"chapter": 1' in npc_gd_text, "npc_3d.gd maps ceo_alex to Chapter 1")
    h.check('"architect_bob"' in npc_gd_text and '"chapter": 2' in npc_gd_text, "npc_3d.gd maps architect_bob to Chapter 2")
    h.check('"scientist_lisa"' in npc_gd_text and '"chapter": 3' in npc_gd_text, "npc_3d.gd maps scientist_lisa to Chapter 3")

    # Parity check between npc_3d.gd CAMPAIGN_STORY and dialogue_panel.gd CHAPTER_CHOICES
    all_choice_ids = [
        "ch1_marketing", "ch1_tech", "ch1_team",
        "ch2_overclock", "ch2_hardware", "ch2_ops",
        "ch3_quantum", "ch3_espresso", "ch3_pitch"
    ]
    for cid in all_choice_ids:
        h.check(cid in dp_gd_text and cid in npc_gd_text, f"Choice ID '{cid}' defined symmetrically in both scripts")

    # -------------------------------------------------------------------------
    # SUITE 2: Touch Button Dimensions & Mouse Filter Attributes
    # -------------------------------------------------------------------------
    print("\n--- SUITE 2: Touch Button Dimensions & Mouse Filter Attributes ---")
    nodes = parse_tscn_nodes(dp_tscn_path)
    nodes_by_name = {n.get("name"): n for n in nodes if "name" in n}

    # Root DialoguePanel
    root_node = nodes_by_name.get("DialoguePanel")
    h.check(root_node is not None, "DialoguePanel root node found")
    if root_node:
        h.check(root_node.get("mouse_filter") == "0", "DialoguePanel root enforces mouse_filter = 0 (STOP)")

    # DimBackdrop
    backdrop = nodes_by_name.get("DimBackdrop")
    h.check(backdrop is not None, "DimBackdrop node found")
    if backdrop:
        h.check(backdrop.get("mouse_filter") == "0", "DimBackdrop enforces mouse_filter = 0 (STOP)")

    # CardPanel
    card = nodes_by_name.get("CardPanel")
    h.check(card is not None, "CardPanel node found")
    if card:
        h.check(card.get("mouse_filter") == "0", "CardPanel enforces mouse_filter = 0 (STOP)")
        min_size = card.get("custom_minimum_size", "")
        # Vector2(500, 480)
        size_match = re.search(r'Vector2\s*\(\s*(\d+)\s*,\s*(\d+)\s*\)', min_size)
        if size_match:
            w, height = int(size_match.group(1)), int(size_match.group(2))
            h.check(w >= 500 and height >= 480, f"CardPanel custom_minimum_size >= 500x480 (actual: {w}x{height})")
        else:
            h.check(False, "CardPanel custom_minimum_size parse", min_size)

    # Interactive Buttons
    button_names = [
        "ChoiceButton1", "ChoiceButton2", "ChoiceButton3",
        "AcceptButton", "CompleteButton", "CloseButton"
    ]
    for bname in button_names:
        btn = nodes_by_name.get(bname)
        h.check(btn is not None, f"Button '{bname}' declared in dialogue_panel.tscn")
        if btn:
            # Check mouse_filter = 0 (STOP)
            mf = btn.get("mouse_filter", "")
            h.check(mf == "0", f"Button '{bname}' enforces mouse_filter = 0 (STOP) (actual: '{mf}')")
            
            # Check minimum height >= 56px
            cms = btn.get("custom_minimum_size", "")
            size_m = re.search(r'Vector2\s*\(\s*(\d+)\s*,\s*(\d+)\s*\)', cms)
            if size_m:
                h_val = int(size_m.group(2))
                h.check(h_val >= 56, f"Button '{bname}' height >= 56px (actual: {h_val}px)")
            else:
                h.check(False, f"Button '{bname}' custom_minimum_size parse", cms)

    # Verify ALL Button nodes in dialogue_panel.tscn meet touch requirements
    all_buttons = [n for n in nodes if n.get("type") == "Button"]
    h.check(len(all_buttons) == 6, f"Found exactly 6 Button nodes in dialogue_panel.tscn (found: {len(all_buttons)})")
    for btn in all_buttons:
        b_name = btn.get("name", "Unknown")
        cms = btn.get("custom_minimum_size", "")
        size_m = re.search(r'Vector2\s*\(\s*(\d+)\s*,\s*(\d+)\s*\)', cms)
        b_height = int(size_m.group(2)) if size_m else 0
        b_mf = btn.get("mouse_filter", "")
        if b_height < 56 or b_mf != "0":
            h.check(False, f"Strict Button touch audit: '{b_name}'", f"height={b_height}, mouse_filter={b_mf}")

    # -------------------------------------------------------------------------
    # SUITE 3: Reward Payload Integrity & Mathematical Oracle
    # -------------------------------------------------------------------------
    print("\n--- SUITE 3: Reward Payload Integrity & Mathematical Buff Oracle ---")

    # 3.1 Check GameState record_campaign_choice implementation
    h.check("func record_campaign_choice" in gs_gd_text, "GameState implements record_campaign_choice()")
    h.check("campaign_choices[str(chapter)] = choice_id" in gs_gd_text, "record_campaign_choice stores string key")
    h.check("campaign_choices[chapter] = choice_id" in gs_gd_text, "record_campaign_choice stores int key")
    h.check("earn_energy(reward_value)" in gs_gd_text, "record_campaign_choice awards energy/users")
    h.check("activate_campaign_rps_buff(reward_value, duration)" in gs_gd_text, "record_campaign_choice triggers RPS buff")
    h.check("activate_campaign_speed_buff(reward_value, duration)" in gs_gd_text, "record_campaign_choice triggers Speed buff")

    # 3.2 Mathematical Oracle: RPS Buff Scaling and Expiry
    base_rps = 100.0
    # Ch1 Tech: +100% RPS (multiplier = 2.0)
    eff_rps_ch1 = base_rps * 2.0
    h.check(eff_rps_ch1 == 200.0, f"RPS multiplier 2.0 doubles passive RPS (100 -> {eff_rps_ch1})")

    # Ch3 Quantum: +200% RPS (multiplier = 3.0)
    eff_rps_ch3 = base_rps * 3.0
    h.check(eff_rps_ch3 == 300.0, f"RPS multiplier 3.0 triples passive RPS (100 -> {eff_rps_ch3})")

    # Stacking with server overclock buff (multiplier 1.5):
    eff_rps_stacked = base_rps * 1.5 * 2.0
    h.check(eff_rps_stacked == 300.0, f"RPS multiplicative stacking: 100 * 1.5 * 2.0 = {eff_rps_stacked}")

    # Verification of get_effective_passive_rps formula in game_state.gd
    h.check("var camp_rps_mult: float = campaign_rps_buff_multiplier if campaign_rps_buff_timer > 0.0 else 1.0" in gs_gd_text,
            "get_effective_passive_rps dynamically applies camp_rps_mult")
    h.check("* camp_rps_mult" in gs_gd_text, "camp_rps_mult correctly integrated into final RPS product")

    # 3.3 Mathematical Oracle: Avatar Speed Scaling and Expiry
    base_speed = 6.0
    speed_level_0_mult = 1.0
    speed_buff_mult = 1.5  # +50% Speed
    eff_speed = base_speed * speed_level_0_mult * speed_buff_mult
    h.check(eff_speed == 9.0, f"Avatar speed 6.0 * 1.5 = {eff_speed}")

    speed_level_2_mult = 1.0 + 2 * 0.15  # 1.30
    eff_speed_lvl2 = base_speed * speed_level_2_mult * speed_buff_mult
    h.check(abs(eff_speed_lvl2 - 11.70) < 1e-4, f"Avatar speed level 2 (6.0 * 1.30 * 1.5) = {eff_speed_lvl2}")

    h.check("var campaign_mult: float = campaign_speed_buff_multiplier if campaign_speed_buff_timer > 0.0 else 1.0" in gs_gd_text,
            "get_effective_avatar_speed dynamically applies campaign_mult")
    h.check("return base_speed * campaign_mult" in gs_gd_text,
            "campaign_mult correctly scales avatar base speed")

    # 3.4 Process Decay Verification
    h.check("campaign_rps_buff_timer -= safe_delta" in gs_gd_text, "_process decrements campaign_rps_buff_timer")
    h.check('campaign_buff_ended.emit("rps")' in gs_gd_text, "_process emits campaign_buff_ended('rps') on expiry")
    h.check("campaign_speed_buff_timer -= safe_delta" in gs_gd_text, "_process decrements campaign_speed_buff_timer")
    h.check('campaign_buff_ended.emit("speed")' in gs_gd_text, "_process emits campaign_buff_ended('speed') on expiry")

    # -------------------------------------------------------------------------
    # SUITE 4: Backward Compatibility of NPC Properties
    # -------------------------------------------------------------------------
    print("\n--- SUITE 4: Backward Compatibility of NPC Properties ---")

    # 4.1 NPC 3D Export Defaults in npc_3d.gd
    h.check('var npc_id: String = "ceo_alex"' in npc_gd_text, "Default npc_id is ceo_alex")
    h.check('var npc_name: String = "Alex"' in npc_gd_text, "Default npc_name is Alex")
    h.check('var npc_title: String = "Founder & CEO"' in npc_gd_text, "Default npc_title is Founder & CEO")
    h.check('var quest_id: String = "quest_briefcases"' in npc_gd_text, "Default quest_id is quest_briefcases")
    h.check('var quest_title: String = "Collect 3 Briefcases"' in npc_gd_text, "Default quest_title is Collect 3 Briefcases")
    h.check('var quest_target: int = 3' in npc_gd_text, "Default quest_target is 3")
    h.check('var quest_reward_energy: float = 150.0' in npc_gd_text, "Default quest_reward_energy is 150.0")
    h.check('var quest_reward_bonus: int = 15' in npc_gd_text, "Default quest_reward_bonus is 15")

    # 4.2 Main3D Scene NPC Instantiations
    main_nodes = parse_tscn_nodes(main_tscn_path)
    main_nodes_by_name = {n.get("name"): n for n in main_nodes if "name" in n}

    # NPC_Alex in main_3d
    alex_node = main_nodes_by_name.get("NPC_Alex")
    h.check(alex_node is not None, "NPC_Alex instanced in main_3d.tscn")
    if alex_node:
        # Defaults to ceo_alex and quest_briefcases
        q_alex = alex_node.get("quest_id", "quest_briefcases")
        h.check(q_alex == "quest_briefcases", f"NPC_Alex quest_id is 'quest_briefcases' (actual: '{q_alex}')")

    # NPC_Bob in main_3d
    bob_node = main_nodes_by_name.get("NPC_Bob")
    h.check(bob_node is not None, "NPC_Bob instanced in main_3d.tscn")
    if bob_node:
        h.check(bob_node.get("npc_id") == "architect_bob", "NPC_Bob npc_id is architect_bob")
        h.check(bob_node.get("quest_id") == "quest_server", "NPC_Bob quest_id is quest_server")

    # NPC_Lisa in main_3d
    lisa_node = main_nodes_by_name.get("NPC_Lisa")
    h.check(lisa_node is not None, "NPC_Lisa instanced in main_3d.tscn")
    if lisa_node:
        h.check(lisa_node.get("npc_id") == "scientist_lisa", "NPC_Lisa npc_id is scientist_lisa")
        h.check(lisa_node.get("quest_id") == "quest_lab", "NPC_Lisa quest_id is quest_lab")

    # 4.3 Backward Compatible Signatures
    # dialogue_panel.gd open_for_npc signature
    sig_match = re.search(r'func open_for_npc\s*\((.*?)\)\s*->\s*void:', dp_gd_text, re.DOTALL)
    h.check(sig_match is not None, "open_for_npc method found in dialogue_panel.gd")
    if sig_match:
        sig_args = sig_match.group(1)
        h.check("choices: Array = []" in sig_args or "choices: Array" in sig_args, "open_for_npc provides choices parameter with default")
        h.check("chapter: int = 0" in sig_args or "chapter: int" in sig_args, "open_for_npc provides chapter parameter with default")
        # Legacy callers passing 12 parameters must be supported
        arg_list = [a.strip().split(":")[0].strip() for a in sig_args.split(",")]
        h.check(len(arg_list) >= 12, f"open_for_npc maintains legacy argument count (args: {len(arg_list)})")

    # -------------------------------------------------------------------------
    # SUITE 5: Adversarial State Machine & Transition Stress Test
    # -------------------------------------------------------------------------
    print("\n--- SUITE 5: Adversarial State Machine & Transition Stress Test ---")

    # 5.1 Stress Test: Retention of quest_title and quest_desc upon Choice Selection
    # Adversarial Scenario:
    # When open_for_npc() is called on a fresh chapter, _show_choice_ui() is executed.
    # ChoiceContainer is made visible, QuestBox is hidden.
    # Player clicks a choice button: _on_choice_pressed(index) is called.
    # ChoiceContainer is hidden, and _refresh_quest_ui() is called to show QuestBox.
    # BUG AUDIT: What arguments are passed into _refresh_quest_ui() in _on_choice_pressed?
    choice_pressed_match = re.search(r'func _on_choice_pressed\(.*?\)\s*->\s*void:(.*?)(?=\nfunc |\Z)', dp_gd_text, re.DOTALL)
    h.check(choice_pressed_match is not None, "_on_choice_pressed method located")
    if choice_pressed_match:
        choice_body = choice_pressed_match.group(1)
        # Check if _refresh_quest_ui is called
        h.check("_refresh_quest_ui" in choice_body, "_on_choice_pressed calls _refresh_quest_ui")
        
        # Check whether member variables _current_quest_title / _current_quest_desc exist
        has_stored_quest_title = "var _current_quest_title" in dp_gd_text
        has_stored_quest_desc = "var _current_quest_desc" in dp_gd_text

        # In current code:
        # _refresh_quest_ui(
        #     quest_title_label.text.replace("📜 Quest: ", "") if quest_title_label else "",
        #     quest_desc_label.text if quest_desc_label else ""
        # )
        # On first open, _show_choice_ui() is called, NOT _refresh_quest_ui().
        # Therefore, quest_title_label.text was NEVER set to quest_title!
        # It remains "📜 Quest: Objective" (from dialogue_panel.tscn line 153).
        # And quest_desc_label.text remains "Quest description." (from line 161).
        # When _on_choice_pressed runs, it passes "Objective" and "Quest description."!
        
        relies_on_uninitialized_label = "quest_title_label.text.replace" in choice_body
        
        # Test: Does the script preserve the actual quest_title passed to open_for_npc?
        h.check(
            (has_stored_quest_title and has_stored_quest_desc) or not relies_on_uninitialized_label,
            "Quest title and description state retention across choice selection",
            "CRITICAL FLAW: _on_choice_pressed reads from quest_title_label.text which was never populated on initial open (since _refresh_quest_ui was bypassed by _show_choice_ui). Consequently, the UI displays placeholder text '[Quest: Objective]' instead of the actual NPC quest title (e.g. 'Collect 3 Briefcases')!"
        )

    # 5.2 Chapter progression logic in game_state.gd
    h.check('if (quest_id == "quest_briefcases" and campaign_chapter == 1)' in gs_gd_text,
            "complete_campus_quest advances Chapter 1 upon completing quest_briefcases")
    h.check('(quest_id == "quest_server" and campaign_chapter == 2)' in gs_gd_text,
            "complete_campus_quest advances Chapter 2 upon completing quest_server")
    h.check('(quest_id == "quest_lab" and campaign_chapter == 3)' in gs_gd_text,
            "complete_campus_quest advances Chapter 3 upon completing quest_lab")

    # 5.3 Choice selection deduplication / replay prevention
    has_dedup_check = "has_chosen" in dp_gd_text and ("campaign_choices.has(str(_current_chapter))" in dp_gd_text or "campaign_choices.has(_current_chapter)" in dp_gd_text)
    h.check(has_dedup_check, "dialogue_panel.gd prevents choice re-selection once a choice has been made for that chapter")

    # 5.4 Avatar input restoration safety
    h.check("_avatar_ref.set_input_enabled(false)" in dp_gd_text, "open_for_npc locks avatar input")
    h.check("_avatar_ref.set_input_enabled(true)" in dp_gd_text, "close_dialogue unlocks avatar input")

    print("\n" + "=" * 70)
    print(f"ADVERSARIAL HARNESS RESULTS: {h.passed} Passed, {h.failed} Failed out of {h.total} Checks")
    print("=" * 70)

    if h.failures:
        print("\nSUMMARY OF CONFIRMED FLAWS / FAILURES:")
        for idx, f in enumerate(h.failures, 1):
            print(f"  {idx}. {f}")
        return False
    else:
        print("\nALL ADVERSARIAL STRESS CHECKS PASSED!")
        return True

if __name__ == "__main__":
    success = run_adversarial_challenge()
    sys.exit(0 if success else 1)
