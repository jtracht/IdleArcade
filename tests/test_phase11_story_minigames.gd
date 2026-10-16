extends SceneTree

## =============================================================================
## Master Headless SceneTree Test Suite for Phase 11: Story Campaign & Minigames
## File: IdleArcade/tests/test_phase11_story_minigames.gd
## Target: Godot 4.3 Engine Headless Runner
##
## Validates all 6 Core Sections:
##   1. Campaign Chapter Flow (1 -> 2 -> 3), out-of-order quest resolution,
##      and Save/Load serialization in GameState.
##   2. Dialogue choices in DialoguePanel, branching UI, and immediate reward
##      bonuses (Energy, Speed boost, RPS multiplier).
##   3. Server Room Cyber-Sync timing minigame (Hit 3 nodes, Perfect Sync +100%
##      RPS for 45s, Normal Sync +50% for 25s, 60s cooldown, MatrixSparks).
##   4. R&D-Lab Super-Espresso Brew Lab (Chibi model, Sweet-spot 3s hold,
##      Unicorn Espresso buff +50% avatar speed, +20% worker speed, 60s cooldown).
##   5. Mobile touch ergonomics (all buttons >= 56px, mouse_filter = STOP)
##      and TouchControls dynamic styling ("Hack [E]" matrix green, "Brew [E]" copper).
##   6. Campaign Badge in HUD (%CampaignBadge) integration across chapters 1..3.
##
## Execution:
##   godot --headless --path IdleArcade -s tests/test_phase11_story_minigames.gd
## =============================================================================

var pass_count: int = 0
var fail_count: int = 0

const EPSILON: float = 0.001

func _assert_check(condition: bool, description: String, detail: String = "") -> void:
	if condition:
		print("  [PASS] %s" % description)
		pass_count += 1
	else:
		var err_msg = "  [FAIL] %s" % description
		if detail != "":
			err_msg += " (Detail: %s)" % detail
		printerr(err_msg)
		fail_count += 1

func _init() -> void:
	print("\n====================================================================")
	print(">>> RUNNING MASTER PHASE 11 STORY & MINIGAMES HEADLESS SCENETREE TEST SUITE <<<")
	print("====================================================================")
	call_deferred("_run_all_tests")

func _run_all_tests() -> void:
	await process_frame

	# -------------------------------------------------------------------------
	# Autoload Singleton Setup: GameState, AudioManager, HapticsManager
	# -------------------------------------------------------------------------
	var gs_script = load("res://scripts/autoload/game_state.gd")
	_assert_check(gs_script != null, "0.1 Load scripts/autoload/game_state.gd")
	if gs_script == null:
		printerr("[FATAL] Cannot load game_state.gd")
		quit(1)
		return

	var gs = root.get_node_or_null("GameState")
	if gs == null:
		gs = gs_script.new()
		gs.name = "GameState"
		root.add_child(gs)
	_assert_check(gs != null, "0.2 GameState mounted at /root/GameState")

	var am_script = load("res://scripts/autoload/audio_manager.gd")
	_assert_check(am_script != null, "0.3 Load scripts/autoload/audio_manager.gd")
	var am = root.get_node_or_null("AudioManager")
	if am == null and am_script != null:
		am = am_script.new()
		am.name = "AudioManager"
		root.add_child(am)
	_assert_check(am != null, "0.4 AudioManager mounted at /root/AudioManager")

	var hm_script = load("res://scripts/autoload/haptics_manager.gd")
	if hm_script != null:
		var hm = root.get_node_or_null("HapticsManager")
		if hm == null:
			hm = hm_script.new()
			hm.name = "HapticsManager"
			root.add_child(hm)

	await process_frame

	# Execute all 6 required sections sequentially
	await _test_section_1_campaign_flow_and_save(gs)
	await _test_section_2_dialogue_choices_and_rewards(gs)
	await _test_section_3_cyber_sync_minigame(gs)
	await _test_section_4_super_espresso_brew_lab(gs)
	await _test_section_5_touch_ergonomics_and_styles(gs)
	await _test_section_6_hud_campaign_badge(gs)

	print("\n====================================================================")
	print(">>> PHASE 11 SCENETREE TEST SUITE SUMMARY: %d PASSED, %d FAILED <<<" % [pass_count, fail_count])
	print("====================================================================")

	if fail_count == 0:
		print(">>> ALL PHASE 11 HEADLESS SCENETREE TESTS PASSED (Exit Code 0) <<<")
		quit(0)
	else:
		printerr(">>> PHASE 11 HEADLESS SCENETREE TESTS FAILED (Exit Code 1) <<<")
		quit(1)

# =============================================================================
# SECTION 1: Campaign Chapter Flow (1 -> 2 -> 3) and Save/Load Serialization
# =============================================================================
func _test_section_1_campaign_flow_and_save(gs: Node) -> void:
	print("\n--- SECTION 1: Campaign Chapter Flow & Save/Load Serialization ---")

	# Reset state to clean baseline
	gs.reset_state()
	await process_frame

	_assert_check(gs.campaign_chapter == 1, "1.1 Campaign starts at Chapter 1")
	_assert_check(gs.get_campaign_chapter() == 1, "1.2 get_campaign_chapter() returns 1")
	_assert_check(gs.campaign_completed_quests.is_empty(), "1.3 campaign_completed_quests starts empty")
	_assert_check(gs.campaign_choices.is_empty(), "1.4 campaign_choices starts empty")

	# Advance chapter directly and verify signal emission
	var emitted_chapters: Array[int] = []
	var on_ch_changed = func(ch: int): emitted_chapters.append(ch)
	gs.campaign_chapter_changed.connect(on_ch_changed)

	gs.advance_campaign_chapter()
	_assert_check(gs.campaign_chapter == 2, "1.5 advance_campaign_chapter() sets chapter to 2")
	_assert_check(emitted_chapters.has(2), "1.6 campaign_chapter_changed signal emitted for Chapter 2")

	gs.advance_campaign_chapter()
	_assert_check(gs.campaign_chapter == 3, "1.7 advance_campaign_chapter() sets chapter to 3")
	_assert_check(emitted_chapters.has(3), "1.8 campaign_chapter_changed signal emitted for Chapter 3")

	gs.campaign_chapter_changed.disconnect(on_ch_changed)

	# Test sequential progression through quest completion
	gs.reset_state()
	_assert_check(gs.campaign_chapter == 1, "1.9 Reset to Chapter 1 for quest sequence")

	# Alex: Chapter 1 -> 2
	gs.start_campus_quest("quest_briefcases", 1)
	gs.advance_campus_quest("quest_briefcases", 1)
	gs.complete_campus_quest("quest_briefcases")
	_assert_check(gs.campaign_completed_quests.has("quest_briefcases"), "1.10 quest_briefcases recorded in campaign_completed_quests")
	_assert_check(gs.is_campaign_quest_completed("quest_briefcases"), "1.11 is_campaign_quest_completed('quest_briefcases') is true")
	_assert_check(gs.campaign_chapter == 2, "1.12 Chapter advanced to 2 upon completing quest_briefcases")

	# Bob: Chapter 2 -> 3
	gs.start_campus_quest("quest_server", 1)
	gs.advance_campus_quest("quest_server", 1)
	gs.complete_campus_quest("quest_server")
	_assert_check(gs.campaign_completed_quests.has("quest_server"), "1.13 quest_server recorded in campaign_completed_quests")
	_assert_check(gs.is_campaign_quest_completed("quest_server"), "1.14 is_campaign_quest_completed('quest_server') is true")
	_assert_check(gs.campaign_chapter == 3, "1.15 Chapter advanced to 3 upon completing quest_server")

	# Lisa: Chapter 3 -> 4 (Unicorn journey achieved)
	gs.start_campus_quest("quest_lab", 1)
	gs.advance_campus_quest("quest_lab", 1)
	gs.complete_campus_quest("quest_lab")
	_assert_check(gs.campaign_completed_quests.has("quest_lab"), "1.16 quest_lab recorded in campaign_completed_quests")
	_assert_check(gs.is_campaign_quest_completed("quest_lab"), "1.17 is_campaign_quest_completed('quest_lab') is true")
	_assert_check(gs.campaign_chapter >= 4, "1.18 Chapter reached 4 (Unicorn Status complete) upon completing quest_lab")

	# Test out-of-order quest resolution (prerequisite cascading)
	gs.reset_state()
	gs.campaign_chapter = 1
	# Complete Bob's quest while still on Chapter 1
	gs.start_campus_quest("quest_server", 1)
	gs.advance_campus_quest("quest_server", 1)
	gs.complete_campus_quest("quest_server")
	_assert_check(gs.campaign_chapter == 1, "1.19 Out-of-order quest_server does not prematurely skip Chapter 1")
	# Now complete Alex's quest - should cascade past consumed Bob quest
	gs.start_campus_quest("quest_briefcases", 1)
	gs.advance_campus_quest("quest_briefcases", 1)
	gs.complete_campus_quest("quest_briefcases")
	_assert_check(gs.campaign_chapter >= 3, "1.20 Completing prerequisite cascades chapter past consumed quest to 3")

	# Test Save & Load serialization
	gs.reset_state()
	gs.campaign_chapter = 2
	var saved_quests: Array[String] = ["quest_briefcases"]
	gs.campaign_completed_quests = saved_quests
	gs.campaign_choices = {"1": "ch1_tech", 1: "ch1_tech"}
	gs.save_to_disk()

	# Wipe state
	gs.campaign_chapter = 1
	gs.campaign_completed_quests.clear()
	gs.campaign_choices.clear()

	# Load back
	gs.load_from_disk()
	_assert_check(gs.campaign_chapter == 2, "1.21 load_from_disk() restored campaign_chapter = 2")
	_assert_check(gs.campaign_completed_quests.has("quest_briefcases"), "1.22 load_from_disk() restored campaign_completed_quests")
	_assert_check(gs.campaign_choices.has("1") or gs.campaign_choices.has(1), "1.23 load_from_disk() restored campaign_choices")

# =============================================================================
# SECTION 2: Dialogue Choices & Immediate Reward Bonuses
# =============================================================================
func _test_section_2_dialogue_choices_and_rewards(gs: Node) -> void:
	print("\n--- SECTION 2: Dialogue Choices & Immediate Reward Bonuses ---")

	var dial_scene = load("res://scenes/dialogue_panel.tscn")
	_assert_check(dial_scene != null, "2.1 scenes/dialogue_panel.tscn loads successfully")
	if dial_scene == null:
		return

	var panel = dial_scene.instantiate() as DialoguePanel
	_assert_check(panel != null, "2.2 DialoguePanel instantiates successfully")
	root.add_child(panel)
	await process_frame

	_assert_check(panel.mouse_filter == Control.MOUSE_FILTER_STOP, "2.3 DialoguePanel enforces mouse_filter = STOP (0)")

	var choice_container = panel.get_node_or_null("%ChoiceContainer") as VBoxContainer
	var btn1 = panel.get_node_or_null("%ChoiceButton1") as Button
	var btn2 = panel.get_node_or_null("%ChoiceButton2") as Button
	var btn3 = panel.get_node_or_null("%ChoiceButton3") as Button

	_assert_check(choice_container != null, "2.4 %ChoiceContainer exists")
	_assert_check(btn1 != null and btn2 != null and btn3 != null, "2.5 Choice buttons 1, 2, 3 exist")

	if btn1 != null:
		_assert_check(btn1.custom_minimum_size.y >= 56.0, "2.6 ChoiceButton1 height >= 56px")
		_assert_check(btn1.mouse_filter == Control.MOUSE_FILTER_STOP, "2.7 ChoiceButton1 mouse_filter = STOP")
	if btn2 != null:
		_assert_check(btn2.custom_minimum_size.y >= 56.0, "2.8 ChoiceButton2 height >= 56px")
		_assert_check(btn2.mouse_filter == Control.MOUSE_FILTER_STOP, "2.9 ChoiceButton2 mouse_filter = STOP")
	if btn3 != null:
		_assert_check(btn3.custom_minimum_size.y >= 56.0, "2.10 ChoiceButton3 height >= 56px")
		_assert_check(btn3.mouse_filter == Control.MOUSE_FILTER_STOP, "2.11 ChoiceButton3 mouse_filter = STOP")

	# Test opening dialogue for CEO Alex (Chapter 1)
	gs.reset_state()
	panel.open_for_npc("ceo_alex", "Alex", "Founder & CEO", "Welcome to Seed Stage!", "quest_briefcases", "MVP Launch", "Collect briefcases", 3, 150.0, 15)
	await process_frame

	_assert_check(choice_container.visible == true, "2.12 ChoiceContainer is visible for new conversation")
	_assert_check(btn1.text.contains("Aggressives Marketing"), "2.13 Choice 1 contains Aggressives Marketing")
	_assert_check(btn2.text.contains("Stabile Technik"), "2.14 Choice 2 contains Stabile Technik")
	_assert_check(btn3.text.contains("Team-Kultur"), "2.15 Choice 3 contains Team-Kultur")

	# Test Choice A: Energy/Users reward
	var initial_energy = gs.energy
	gs.record_campaign_choice(1, "ch1_marketing", "users", 500.0, 0.0)
	_assert_check(gs.energy >= initial_energy + 500.0, "2.16 ch1_marketing awarded +500 users/energy")
	_assert_check(gs.campaign_choices.get("1") == "ch1_marketing" or gs.campaign_choices.get(1) == "ch1_marketing", "2.17 Chapter 1 choice recorded as ch1_marketing")

	# Test Choice B: Temporary RPS boost (+100% RPS, 30s)
	gs.activate_campaign_rps_buff(2.0, 30.0)
	_assert_check(gs.campaign_rps_buff_multiplier == 2.0, "2.18 campaign_rps_buff_multiplier set to 2.0")
	_assert_check(gs.campaign_rps_buff_timer == 30.0, "2.19 campaign_rps_buff_timer set to 30.0s")
	var base_rps = 100.0
	var effective_mult = gs.campaign_rps_buff_multiplier if gs.campaign_rps_buff_timer > 0.0 else 1.0
	_assert_check(effective_mult == 2.0, "2.20 Active campaign RPS multiplier evaluates to 2.0")

	# Test Choice C: Temporary Speed boost (+50% Speed, 45s)
	gs.activate_campaign_speed_buff(1.5, 45.0)
	_assert_check(gs.campaign_speed_buff_multiplier == 1.5, "2.21 campaign_speed_buff_multiplier set to 1.5")
	_assert_check(gs.campaign_speed_buff_timer == 45.0, "2.22 campaign_speed_buff_timer set to 45.0s")
	var eff_speed_mult = gs.campaign_speed_buff_multiplier if gs.campaign_speed_buff_timer > 0.0 else 1.0
	_assert_check(eff_speed_mult == 1.5, "2.23 Active campaign speed multiplier evaluates to 1.5")

	panel.close_dialogue()
	panel.queue_free()
	await process_frame

# =============================================================================
# SECTION 3: Server Room Cyber-Sync Timing Minigame
# =============================================================================
func _test_section_3_cyber_sync_minigame(gs: Node) -> void:
	print("\n--- SECTION 3: Server Room Cyber-Sync Timing Minigame ---")

	var st_scene = load("res://scenes/server_terminal.tscn")
	_assert_check(st_scene != null, "3.1 scenes/server_terminal.tscn loads successfully")
	if st_scene == null:
		return

	var terminal = st_scene.instantiate() as ServerTerminal
	_assert_check(terminal != null, "3.2 ServerTerminal instantiates successfully")
	root.add_child(terminal)
	await process_frame

	_assert_check(terminal.action_label == "Hack [E]", "3.3 action_label is 'Hack [E]'")
	_assert_check(terminal.overclock_duration == 25.0, "3.4 overclock_duration is 25.0s")
	_assert_check(terminal.overclock_cooldown == 60.0, "3.5 overclock_cooldown is 60.0s")
	_assert_check(terminal.rps_boost_multiplier == 1.50, "3.6 rps_boost_multiplier is 1.50")
	_assert_check(terminal.perfect_overclock_duration == 45.0, "3.7 perfect_overclock_duration is 45.0s")
	_assert_check(terminal.perfect_rps_boost_multiplier == 2.00, "3.8 perfect_rps_boost_multiplier is 2.00")

	var status_lbl = terminal.get_node_or_null("StatusLabel3D") as Label3D
	var matrix_sparks = terminal.get_node_or_null("Visuals/MatrixSparks") as CPUParticles3D
	_assert_check(status_lbl != null, "3.9 StatusLabel3D present on ServerTerminal")
	_assert_check(matrix_sparks != null, "3.10 MatrixSparks CPUParticles3D present on ServerTerminal")

	# Test CyberSyncMinigame modal instantiation
	var cs_scene = load("res://scenes/ui/cyber_sync_minigame.tscn")
	_assert_check(cs_scene != null, "3.11 scenes/ui/cyber_sync_minigame.tscn loads successfully")
	if cs_scene == null:
		terminal.queue_free()
		return

	var cs_game = cs_scene.instantiate() as CyberSyncMinigame
	_assert_check(cs_game != null, "3.12 CyberSyncMinigame instantiates successfully")
	root.add_child(cs_game)
	await process_frame

	_assert_check(cs_game.mouse_filter == Control.MOUSE_FILTER_STOP, "3.13 CyberSyncMinigame root mouse_filter = STOP")
	var sync_btn = cs_game.get_node_or_null("%SyncHitButton") as Button
	var close_btn = cs_game.get_node_or_null("%CloseButton") as Button
	_assert_check(sync_btn != null and sync_btn.custom_minimum_size.y >= 56.0, "3.14 %SyncHitButton height >= 56px")
	_assert_check(sync_btn != null and sync_btn.mouse_filter == Control.MOUSE_FILTER_STOP, "3.15 %SyncHitButton mouse_filter = STOP")
	_assert_check(close_btn != null and close_btn.custom_minimum_size.y >= 56.0, "3.16 %CloseButton height >= 56px")

	# Test Normal Sync Simulation (3 non-perfect hits)
	cs_game.open_minigame(terminal)
	cs_game.simulate_sync_hit(false)
	cs_game.simulate_sync_hit(false)
	cs_game.simulate_sync_hit(false)
	await process_frame

	_assert_check(cs_game.is_completed == true, "3.17 CyberSyncMinigame completes after 3 node hits")
	_assert_check(terminal.is_overclock_active == true, "3.18 ServerTerminal overclock is active after Normal Sync")
	_assert_check(terminal.current_multiplier == 1.50, "3.19 Normal Sync multiplier is 1.50 (+50% RPS)")
	_assert_check(terminal.overclock_time_remaining <= 25.0 and terminal.overclock_time_remaining > 20.0, "3.20 Normal Sync duration is 25s")

	# Test Perfect Sync Simulation (3 perfect hits)
	terminal.is_on_cooldown = false
	terminal.is_overclock_active = false
	cs_game.open_minigame(terminal)
	cs_game.simulate_sync_hit(true)
	cs_game.simulate_sync_hit(true)
	cs_game.simulate_sync_hit(true)
	await process_frame

	_assert_check(terminal.is_overclock_active == true, "3.21 ServerTerminal overclock is active after Perfect Sync")
	_assert_check(terminal.is_perfect_overclock == true, "3.22 is_perfect_overclock is true")
	_assert_check(terminal.current_multiplier == 2.00, "3.23 Perfect Sync multiplier is 2.00 (+100% RPS)")
	_assert_check(terminal.overclock_time_remaining <= 45.0 and terminal.overclock_time_remaining > 40.0, "3.24 Perfect Sync duration is 45s")
	_assert_check(matrix_sparks.emitting == true, "3.25 MatrixSparks emitting during Perfect Overclock")

	# Test 60s Cooldown Enforcement
	terminal._end_overclock()
	_assert_check(terminal.is_on_cooldown == true, "3.26 Cooldown engaged after overclock ends")
	_assert_check(terminal.cooldown_time_remaining == 60.0, "3.27 Cooldown timer initialized to 60.0s")
	_assert_check(terminal.can_activate() == false, "3.28 can_activate() is false during cooldown")

	cs_game.queue_free()
	terminal.queue_free()
	await process_frame

# =============================================================================
# SECTION 4: R&D-Lab Super-Espresso Brew Lab
# =============================================================================
func _test_section_4_super_espresso_brew_lab(gs: Node) -> void:
	print("\n--- SECTION 4: R&D-Lab Super-Espresso Brew Lab ---")

	var cm_scene = load("res://scenes/coffee_machine_3d.tscn")
	_assert_check(cm_scene != null, "4.1 scenes/coffee_machine_3d.tscn loads successfully")
	if cm_scene == null:
		return

	var machine = cm_scene.instantiate() as CoffeeMachine3D
	_assert_check(machine != null, "4.2 CoffeeMachine3D instantiates successfully")
	root.add_child(machine)
	await process_frame

	_assert_check(machine.action_label == "Brew [E]", "4.3 action_label is 'Brew [E]'")
	_assert_check(machine.brew_cooldown == 60.0, "4.4 brew_cooldown is 60.0s")
	_assert_check(machine.avatar_speed_boost == 1.50, "4.5 avatar_speed_boost is 1.50 (+50%)")
	_assert_check(machine.worker_speed_boost == 1.20, "4.6 worker_speed_boost is 1.20 (+20%)")
	_assert_check(machine.buff_duration == 60.0, "4.7 buff_duration is 60.0s")

	var steam = machine.get_node_or_null("Visuals/SteamParticles") as CPUParticles3D
	var needle = machine.get_node_or_null("Visuals/PressureGauge/NeedleRoot")
	_assert_check(steam != null, "4.8 SteamParticles CPUParticles3D exists")
	_assert_check(needle != null, "4.9 Pressure gauge needle root exists")

	# Test EspressoBrewMinigame modal instantiation
	var eb_scene = load("res://scenes/ui/espresso_brew_minigame.tscn")
	_assert_check(eb_scene != null, "4.10 scenes/ui/espresso_brew_minigame.tscn loads successfully")
	if eb_scene == null:
		machine.queue_free()
		return

	var eb_game = eb_scene.instantiate() as EspressoBrewMinigame
	_assert_check(eb_game != null, "4.11 EspressoBrewMinigame instantiates successfully")
	root.add_child(eb_game)
	await process_frame

	_assert_check(eb_game.mouse_filter == Control.MOUSE_FILTER_STOP, "4.12 EspressoBrewMinigame root mouse_filter = STOP")
	var pump_btn = eb_game.get_node_or_null("%PumpButton") as Button
	var close_btn = eb_game.get_node_or_null("%CloseButton") as Button
	_assert_check(pump_btn != null and pump_btn.custom_minimum_size.y >= 56.0, "4.13 %PumpButton height >= 56px")
	_assert_check(pump_btn != null and pump_btn.mouse_filter == Control.MOUSE_FILTER_STOP, "4.14 %PumpButton mouse_filter = STOP")
	_assert_check(close_btn != null and close_btn.custom_minimum_size.y >= 56.0, "4.15 %CloseButton height >= 56px")

	# Test Sweet-Spot Pressure Dynamics (62 - 84 bar)
	eb_game.reset_minigame()
	_assert_check(eb_game.sweet_spot_min == 62.0 and eb_game.sweet_spot_max == 84.0, "4.16 Sweet spot range is 62.0 to 84.0 bar")
	_assert_check(eb_game.required_hold_time == 3.0, "4.17 Required sweet-spot hold time is 3.0s")

	# Simulate pumping into sweet spot
	eb_game.current_pressure = 70.0
	_assert_check(eb_game.is_in_sweet_spot() == true, "4.18 70.0 bar is inside sweet spot")

	# Simulate completing brew
	eb_game.complete_brew(true)
	_assert_check(eb_game.is_finished == true, "4.19 complete_brew(true) marks minigame finished")

	# Verify GameState Unicorn Espresso Buff
	gs.activate_unicorn_espresso_buff(60.0)
	_assert_check(gs.is_unicorn_espresso_active() == true, "4.20 is_unicorn_espresso_active() returns true")
	_assert_check(gs.unicorn_espresso_buff_timer <= 60.0 and gs.unicorn_espresso_buff_timer > 55.0, "4.21 Unicorn Espresso buff timer initialized to 60s")

	# Verify WorkerAvatar3D speed scaling
	var worker_scene = load("res://scenes/worker_avatar_3d.tscn")
	if worker_scene != null:
		var worker = worker_scene.instantiate()
		root.add_child(worker)
		await process_frame
		_assert_check(worker.has_method("get_speed_multiplier"), "4.22 WorkerAvatar3D implements get_speed_multiplier")
		if worker.has_method("get_speed_multiplier"):
			_assert_check(absf(worker.get_speed_multiplier() - 1.20) < EPSILON, "4.23 WorkerAvatar3D speed multiplier is exactly 1.20 during Unicorn Espresso buff")
		worker.queue_free()

	# Verify production multiplier formula with coffee buff
	var worker_mult = gs.get_worker_production_multiplier()
	_assert_check(worker_mult >= 1.20, "4.24 GameState get_worker_production_multiplier() includes 1.20x espresso boost")

	# Verify CoffeeMachine3D cooldown
	machine.complete_brew(true)
	_assert_check(machine.is_on_cooldown == true, "4.25 CoffeeMachine3D cooldown engaged")
	_assert_check(machine.cooldown_time_remaining == 60.0, "4.26 CoffeeMachine3D cooldown is 60.0s")
	_assert_check(machine.can_brew() == false, "4.27 can_brew() returns false during cooldown")

	eb_game.queue_free()
	machine.queue_free()
	await process_frame

# =============================================================================
# SECTION 5: Mobile Touch Ergonomics & TouchControls Dynamic Styling
# =============================================================================
func _test_section_5_touch_ergonomics_and_styles(gs: Node) -> void:
	print("\n--- SECTION 5: Mobile Touch Ergonomics & TouchControls Dynamic Styling ---")

	var tc_scene = load("res://scenes/ui/touch_controls.tscn")
	_assert_check(tc_scene != null, "5.1 scenes/ui/touch_controls.tscn loads successfully")
	if tc_scene == null:
		return

	var tc = tc_scene.instantiate()
	_assert_check(tc != null, "5.2 TouchControls instantiates successfully")
	root.add_child(tc)
	await process_frame

	var action_btn = tc.get_node_or_null("%ActionButton") as Button
	_assert_check(action_btn != null, "5.3 %ActionButton exists in TouchControls")
	if action_btn != null:
		_assert_check(action_btn.custom_minimum_size.x >= 56.0 and action_btn.custom_minimum_size.y >= 56.0, "5.4 ActionButton size >= 56x56px (actual 100x100)")
		_assert_check(action_btn.mouse_filter == Control.MOUSE_FILTER_STOP, "5.5 ActionButton mouse_filter = STOP")

	# Check cached styles
	_assert_check(tc._cached_hack_style != null, "5.6 _cached_hack_style defined in TouchControls")
	_assert_check(tc._cached_brew_style != null, "5.7 _cached_brew_style defined in TouchControls")

	if tc._cached_hack_style != null:
		_assert_check(tc._cached_hack_style.border_color.g >= 0.9, "5.8 _cached_hack_style has Neon Matrix Green border")
	if tc._cached_brew_style != null:
		_assert_check(tc._cached_brew_style.border_color.r >= 0.8 and tc._cached_brew_style.border_color.g >= 0.5, "5.9 _cached_brew_style has Warm Copper/Mocha border")

	# Test dynamic register_interactable for Hack [E]
	var mock_terminal = Node3D.new()
	mock_terminal.set_meta("action_label", "Hack [E]")
	mock_terminal.add_to_group("server_terminals")
	tc.register_interactable(mock_terminal, "Hack [E]")
	_assert_check(action_btn.text == "Hack [E]", "5.10 ActionButton displays 'Hack [E]' when terminal registered")

	# Test dynamic register_interactable for Brew [E]
	var mock_coffee = Node3D.new()
	mock_coffee.set_meta("action_label", "Brew [E]")
	mock_coffee.add_to_group("coffee_machines")
	tc.register_interactable(mock_coffee, "Brew [E]")
	_assert_check(action_btn.text == "Brew [E]", "5.11 ActionButton displays 'Brew [E]' when coffee machine registered")

	# Unregister
	tc.unregister_interactable(mock_coffee)
	tc.unregister_interactable(mock_terminal)
	mock_terminal.free()
	mock_coffee.free()
	tc.queue_free()
	await process_frame

# =============================================================================
# SECTION 6: Campaign Badge in HUD (%CampaignBadge) Integration
# =============================================================================
func _test_section_6_hud_campaign_badge(gs: Node) -> void:
	print("\n--- SECTION 6: Campaign Badge in HUD (%CampaignBadge) Integration ---")

	var hud_scene = load("res://scenes/hud.tscn")
	_assert_check(hud_scene != null, "6.1 scenes/hud.tscn loads successfully")
	if hud_scene == null:
		return

	var hud = hud_scene.instantiate()
	_assert_check(hud != null, "6.2 HUD instantiates successfully")
	root.add_child(hud)
	await process_frame

	var badge = hud.get_node_or_null("%CampaignBadge") as PanelContainer
	var ch_title = hud.get_node_or_null("%ChapterTitleLabel") as Label
	var mission_lbl = hud.get_node_or_null("%StoryMissionLabel") as Label
	var prog_lbl = hud.get_node_or_null("%BadgeProgressLabel") as Label

	_assert_check(badge != null, "6.3 %CampaignBadge exists in HUD")
	_assert_check(ch_title != null, "6.4 %ChapterTitleLabel exists in HUD")
	_assert_check(mission_lbl != null, "6.5 %StoryMissionLabel exists in HUD")
	_assert_check(prog_lbl != null, "6.6 %BadgeProgressLabel exists in HUD")

	if badge != null:
		_assert_check(badge.custom_minimum_size.y >= 48.0, "6.7 CampaignBadge height >= 48px")
		_assert_check(badge.mouse_filter == Control.MOUSE_FILTER_STOP, "6.8 CampaignBadge mouse_filter = STOP")

	# Test Chapter 1 display
	gs.campaign_chapter = 1
	hud._update_campaign_badge(1)
	_assert_check(ch_title.text.contains("CHAPTER 1: SEED STAGE"), "6.9 Chapter 1 title displays 'CHAPTER 1: SEED STAGE'")
	_assert_check(prog_lbl.text == "[1 / 3]", "6.10 Chapter 1 progress displays '[1 / 3]'")
	_assert_check(mission_lbl.text.contains("Alex"), "6.11 Chapter 1 mission mentions Alex")

	# Test Chapter 2 display
	gs.campaign_chapter = 2
	hud._update_campaign_badge(2)
	_assert_check(ch_title.text.contains("CHAPTER 2: SERIES A"), "6.12 Chapter 2 title displays 'CHAPTER 2: SERIES A'")
	_assert_check(prog_lbl.text == "[2 / 3]", "6.13 Chapter 2 progress displays '[2 / 3]'")
	_assert_check(mission_lbl.text.contains("Bob"), "6.14 Chapter 2 mission mentions Bob")

	# Test Chapter 3 display
	gs.campaign_chapter = 3
	hud._update_campaign_badge(3)
	_assert_check(ch_title.text.contains("CHAPTER 3: UNICORN STATUS"), "6.15 Chapter 3 title displays 'CHAPTER 3: UNICORN STATUS'")
	_assert_check(prog_lbl.text == "[3 / 3]", "6.16 Chapter 3 progress displays '[3 / 3]'")
	_assert_check(mission_lbl.text.contains("Lisa"), "6.17 Chapter 3 mission mentions Lisa")

	hud.queue_free()
	await process_frame
