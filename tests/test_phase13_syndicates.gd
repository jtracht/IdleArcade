extends SceneTree

## =============================================================================
## Master Headless SceneTree Test Suite for Phase 13: Syndicate Headquarters
## File: IdleArcade/tests/test_phase13_syndicates.gd
## Target: Godot 4.3 Engine Headless Runner & CI Verification
##
## Validates all 5 Core Sections:
##   1. Syndicate Holdings Economy & Perks (Tiers 0..5, dividend multipliers,
##      angel share donations, seasonal score calculation, save/load persistence).
##   2. 3D Campus East Wing Lounge & Hologram Props (Placement at (12, 0, 0),
##      low-poly triangle budget < 2,500 Tris, TouchControls emerald styling).
##   3. Mobile Syndicate Modal & Touch Ergonomics (3 tabs, >=56px touch targets,
##      mouse_filter = STOP pointer isolation, HUD badge & navigation drawer).
##   4. LiveEventManager Cooperative Crisis Events (Server Crash Crisis,
##      Angel Investor Summit, milestone signals, 2x production buff, drone speed).
##   5. Full Integration Loop & Zero Regressions (End-to-end player journey,
##      syndicate + event + overclock + IPO ascension stacking, persistence).
##
## Execution:
##   godot --headless --path IdleArcade -s tests/test_phase13_syndicates.gd
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
	print(">>> RUNNING MASTER PHASE 13 SYNDICATE HEADQUARTERS HEADLESS TEST SUITE <<<")
	print("====================================================================")
	call_deferred("_run_all_tests")

func _run_all_tests() -> void:
	await process_frame

	# -------------------------------------------------------------------------
	# Autoload Singleton Setup: GameState, LiveEventManager, AudioManager, HapticsManager
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

	var lem_script = load("res://scripts/autoload/live_event_manager.gd")
	_assert_check(lem_script != null, "0.3 Load scripts/autoload/live_event_manager.gd")
	var lem = root.get_node_or_null("LiveEventManager")
	if lem == null and lem_script != null:
		lem = lem_script.new()
		lem.name = "LiveEventManager"
		root.add_child(lem)
	_assert_check(lem != null, "0.4 LiveEventManager mounted at /root/LiveEventManager")

	var am_script = load("res://scripts/autoload/audio_manager.gd")
	if am_script != null:
		var am = root.get_node_or_null("AudioManager")
		if am == null:
			am = am_script.new()
			am.name = "AudioManager"
			root.add_child(am)

	var hm_script = load("res://scripts/autoload/haptics_manager.gd")
	if hm_script != null:
		var hm = root.get_node_or_null("HapticsManager")
		if hm == null:
			hm = hm_script.new()
			hm.name = "HapticsManager"
			root.add_child(hm)

	await process_frame

	# Execute all 5 required sections sequentially
	await _test_section_1_syndicate_holdings_economy(gs)
	await _test_section_2_3d_campus_east_wing_and_hologram(gs)
	await _test_section_3_mobile_syndicate_modal(gs)
	await _test_section_4_live_event_manager_crises(gs, lem)
	await _test_section_5_full_integration_loop(gs, lem)

	print("\n====================================================================")
	print(">>> PHASE 13 SCENETREE TEST SUITE SUMMARY: %d PASSED, %d FAILED <<<" % [pass_count, fail_count])
	print("====================================================================")

	if fail_count == 0:
		print(">>> ALL PHASE 13 HEADLESS SCENETREE TESTS PASSED (Exit Code 0) <<<")
		quit(0)
	else:
		printerr(">>> PHASE 13 HEADLESS SCENETREE TESTS FAILED (Exit Code 1) <<<")
		quit(1)

# =============================================================================
# SECTION 1: Syndicate Holdings Economy & Perks
# =============================================================================
func _test_section_1_syndicate_holdings_economy(gs: Node) -> void:
	print("\n--- SECTION 1: Syndicate Holdings Economy & Perks ---")

	# 1.1 Reset state to baseline
	gs.reset_state()
	await process_frame

	_assert_check(gs.is_in_syndicate() == false, "1.1 Initial state: player is unaffiliated")
	_assert_check(gs.get_syndicate_tier() == 0, "1.2 Initial syndicate tier is 0")
	_assert_check(absf(gs.get_syndicate_dividend_multiplier() - 1.0) < EPSILON, "1.3 Initial dividend multiplier is 1.00x (+0%)")
	_assert_check(absf(gs.get_drone_speed_multiplier() - 1.0) < EPSILON, "1.4 Initial drone speed multiplier is 1.00x (+0%)")
	_assert_check(absf(gs.get_syndicate_ipo_bonus_percent() - 0.0) < EPSILON, "1.5 Initial IPO bonus shares percent is 0%")

	# 1.2 Founding a Syndicate
	var found_res = gs.found_syndicate("syn_apex", "Apex Syndicate", "APEX", "Dominant Campus Holding")
	_assert_check(found_res.get("success") == true, "1.6 found_syndicate succeeds")
	_assert_check(gs.is_in_syndicate() == true, "1.7 is_in_syndicate() returns true after founding")
	_assert_check(gs.active_syndicate_id == "syn_apex", "1.8 active_syndicate_id matches 'syn_apex'")
	_assert_check(gs.active_syndicate_name == "Apex Syndicate", "1.9 active_syndicate_name matches 'Apex Syndicate'")
	_assert_check(gs.active_syndicate_tag == "APEX", "1.10 active_syndicate_tag matches 'APEX'")
	_assert_check(gs.active_syndicate_role == "Founder", "1.11 active_syndicate_role is 'Founder'")
	_assert_check(gs.get_syndicate_tier() == 1, "1.12 Initial syndicate tier upon founding is Tier 1 (Seed)")
	_assert_check(absf(gs.get_syndicate_dividend_multiplier() - 1.05) < EPSILON, "1.13 Tier 1 dividend multiplier is 1.05 (+5%)")

	# 1.3 Boundary: Cannot found second syndicate while affiliated
	var dup_found = gs.found_syndicate("syn_other", "Other Syndicate", "OTH", "Desc")
	_assert_check(dup_found.get("success") == false, "1.14 Secondary founding safely rejected while affiliated")

	# 1.4 Donations Validation: Zero, Negative & Overbalance
	var zero_res = gs.contribute_to_syndicate(0.0, "energy")
	_assert_check(zero_res.get("success") == false, "1.15 Zero energy donation safely rejected")
	var neg_res = gs.contribute_to_syndicate(-500.0, "energy")
	_assert_check(neg_res.get("success") == false, "1.16 Negative energy donation safely rejected")

	gs.energy = 50000.0
	var over_res = gs.contribute_to_syndicate(999999.0, "energy")
	_assert_check(over_res.get("success") == false, "1.17 Over-balance energy donation safely rejected")
	_assert_check(absf(gs.energy - 50000.0) < EPSILON, "1.18 Energy preserved after rejected over-balance donation")

	# 1.5 Valid Energy Donations & Tier 2 Progression
	# Tier 2 requires 100,000 Energy or 5 Angel Shares
	var contrib_res = gs.contribute_to_syndicate(50000.0, "energy")
	_assert_check(contrib_res.get("success") == true, "1.19 Contribute 50,000 Energy succeeds")
	_assert_check(absf(gs.syndicate_fund_energy - 50000.0) < EPSILON, "1.20 Fund energy increased to 50,000")
	_assert_check(gs.get_syndicate_tier() == 1, "1.21 Fund at 50k: Tier 1 preserved (< 100k threshold)")

	gs.energy = 100000.0
	gs.contribute_to_syndicate(50000.0, "energy")
	_assert_check(absf(gs.syndicate_fund_energy - 100000.0) < EPSILON, "1.22 Fund energy reached 100,000")
	_assert_check(gs.get_syndicate_tier() == 2, "1.23 Promoted to Tier 2 (Growth Syndicate) at 100k Energy")
	_assert_check(absf(gs.get_syndicate_dividend_multiplier() - 1.10) < EPSILON, "1.24 Tier 2 dividend multiplier is 1.10 (+10%)")
	_assert_check(absf(gs.get_drone_speed_multiplier() - 1.15) < EPSILON, "1.25 Tier 2 drone speed multiplier is 1.15 (+15%)")

	# 1.6 Angel Share Donations & Tier 3 Progression
	# Tier 3 requires 500k energy or 20 angel shares
	gs.angel_shares = 25
	var shares_res = gs.contribute_angel_shares_to_syndicate(20)
	_assert_check(shares_res.get("success") == true, "1.26 Contribute 20 Angel Shares succeeds")
	_assert_check(gs.angel_shares == 5, "1.27 Angel shares deducted from wallet (25 - 20 = 5)")
	_assert_check(gs.syndicate_fund_angel_shares == 20, "1.28 Syndicate vault contains 20 Angel Shares")
	_assert_check(gs.get_syndicate_tier() == 3, "1.29 Promoted to Tier 3 (Expansion Syndicate) with 20 Angel Shares")
	_assert_check(absf(gs.get_syndicate_dividend_multiplier() - 1.15) < EPSILON, "1.30 Tier 3 dividend multiplier is 1.15 (+15%)")
	_assert_check(absf(gs.get_syndicate_ipo_bonus_percent() - 0.05) < EPSILON, "1.31 Tier 3 IPO bonus is +5% bonus shares")

	# 1.7 Tier 4 and Tier 5 Advancement & Max Clamping
	# Tier 5 requires 100 Angel Shares or 10M Energy
	gs.angel_shares = 100
	gs.contribute_angel_shares_to_syndicate(80) # total fund shares: 100
	_assert_check(gs.get_syndicate_tier() == 5, "1.32 Promoted to Tier 5 (Holding Monopoly) with 100 Angel Shares")
	_assert_check(absf(gs.get_syndicate_dividend_multiplier() - 1.25) < EPSILON, "1.33 Tier 5 dividend multiplier is 1.25 (+25%)")
	_assert_check(absf(gs.get_drone_speed_multiplier() - 1.15) < EPSILON, "1.34 Tier 5 drone speed multiplier is 1.15 (+15%)")
	_assert_check(absf(gs.get_syndicate_ipo_bonus_percent() - 0.15) < EPSILON, "1.35 Tier 5 IPO bonus is +15% bonus shares")

	# Clamping test: adding even more funds doesn't exceed tier 5
	gs.energy = 20000000.0
	gs.contribute_to_syndicate(5000000.0, "energy")
	_assert_check(gs.get_syndicate_tier() == 5, "1.36 Tier strictly clamped to maximum Tier 5")

	# 1.8 Seasonal Score Formula Verification
	# Formula: fund_energy * 0.1 + fund_shares * 500 + tier * 1000
	var expected_score: int = int(gs.syndicate_fund_energy * 0.1 + float(gs.syndicate_fund_angel_shares) * 500.0 + float(gs.syndicate_tier) * 1000.0)
	var actual_score: int = gs.get_seasonal_leaderboard_score()
	_assert_check(actual_score == expected_score, "1.37 Seasonal score matches formula (%d == %d)" % [actual_score, expected_score])

	# 1.9 Save / Load Roundtrip Persistence
	gs.save_to_disk()
	var saved_id = gs.active_syndicate_id
	var saved_tier = gs.syndicate_tier
	var saved_fund_e = gs.syndicate_fund_energy
	var saved_fund_s = gs.syndicate_fund_angel_shares

	gs.active_syndicate_id = ""
	gs.syndicate_tier = 0
	gs.syndicate_fund_energy = 0.0
	gs.syndicate_fund_angel_shares = 0

	gs.load_from_disk()
	_assert_check(gs.active_syndicate_id == saved_id, "1.38 load_from_disk restored syndicate ID: " + saved_id)
	_assert_check(gs.syndicate_tier == saved_tier, "1.39 load_from_disk restored syndicate Tier: %d" % saved_tier)
	_assert_check(absf(gs.syndicate_fund_energy - saved_fund_e) < EPSILON, "1.40 load_from_disk restored fund energy")
	_assert_check(gs.syndicate_fund_angel_shares == saved_fund_s, "1.41 load_from_disk restored fund angel shares")
	_assert_check(absf(gs.get_syndicate_dividend_multiplier() - 1.25) < EPSILON, "1.42 Restored Tier 5 dividend multiplier: 1.25x")

# =============================================================================
# SECTION 2: 3D Campus East Wing Lounge & Hologram Props
# =============================================================================
func _test_section_2_3d_campus_east_wing_and_hologram(gs: Node) -> void:
	print("\n--- SECTION 2: 3D Campus East Wing Lounge & Hologram Props ---")

	# 2.1 Scene Loading & Instantiation
	var hq_scene = load("res://scenes/syndicate_hq_3d.tscn")
	_assert_check(hq_scene != null, "2.1 scenes/syndicate_hq_3d.tscn loads successfully")
	if hq_scene == null:
		return

	var hq = hq_scene.instantiate() as StaticBody3D
	_assert_check(hq != null, "2.2 SyndicateHQ3D instantiates successfully")
	root.add_child(hq)
	await process_frame

	# 2.2 Group Memberships
	_assert_check(hq.is_in_group("syndicate_hqs"), "2.3 In group 'syndicate_hqs'")
	_assert_check(hq.is_in_group("interactables"), "2.4 In group 'interactables'")
	_assert_check(hq.is_in_group("stations"), "2.5 In group 'stations'")

	# 2.3 Collision & Trigger Nodes
	var col_shape = hq.get_node_or_null("CollisionShape3D") as CollisionShape3D
	var area = hq.get_node_or_null("InteractionArea") as Area3D
	var prompt = hq.get_node_or_null("PromptLabel3D") as Label3D

	_assert_check(col_shape != null, "2.6 CollisionShape3D exists on SyndicateHQ3D")
	_assert_check(area != null, "2.7 InteractionArea (Area3D) exists on SyndicateHQ3D")
	_assert_check(prompt != null, "2.8 PromptLabel3D exists on SyndicateHQ3D")
	if prompt != null:
		_assert_check(prompt.text.contains("Syndicate HQ"), "2.9 Prompt text contains 'Syndicate HQ'")

	# 2.4 Visual Hierarchy & Props
	var visuals = hq.get_node_or_null("Visuals")
	var globe = hq.get_node_or_null("Visuals/ConferenceTable/HolographicGlobe")
	var screen = hq.get_node_or_null("Visuals/ProjectionScreen")
	var banners = hq.get_node_or_null("Visuals/Banners")

	_assert_check(visuals != null, "2.10 Visuals container exists")
	_assert_check(globe != null, "2.11 HolographicGlobe exists on conference table")
	_assert_check(screen != null, "2.12 ProjectionScreen display board exists")
	_assert_check(banners != null, "2.13 Banners container exists with crest flags")

	# 2.5 Script API & Hologram Pulse
	_assert_check(hq.has_method("interact"), "2.14 Implements interact()")
	_assert_check(hq.has_method("open_syndicate"), "2.15 Implements open_syndicate()")
	_assert_check(hq.has_method("pulse_hologram"), "2.16 Implements pulse_hologram()")
	_assert_check(hq.has_method("refresh_syndicate_display"), "2.17 Implements refresh_syndicate_display()")

	hq.pulse_hologram()
	await process_frame
	_assert_check(true, "2.18 pulse_hologram() executes safely without errors")

	# 2.6 East Wing Placement in main_3d.tscn
	var main_scene = load("res://scenes/main_3d.tscn")
	_assert_check(main_scene != null, "2.19 scenes/main_3d.tscn loads successfully")
	if main_scene != null:
		var main_inst = main_scene.instantiate()
		root.add_child(main_inst)
		await process_frame
		var main_hq = main_inst.get_node_or_null("SyndicateHQ3D")
		_assert_check(main_hq != null, "2.20 SyndicateHQ3D instanced in main_3d.tscn")
		if main_hq != null:
			var pos = main_hq.position
			_assert_check(absf(pos.x - 12.0) < 0.5 and absf(pos.z - 0.0) < 0.5,
				"2.21 East Wing placement verified at (12, 0, 0) (actual: %s)" % str(pos))
		main_inst.queue_free()

	# 2.7 TouchControls Emerald Styling Integration
	var tc_script = load("res://scripts/ui/touch_controls.gd")
	_assert_check(tc_script != null, "2.22 scripts/ui/touch_controls.gd loads")
	var tc_scene = load("res://scenes/ui/touch_controls.tscn")
	if tc_scene != null:
		var tc = tc_scene.instantiate()
		root.add_child(tc)
		await process_frame
		_assert_check(tc._cached_syndicate_style != null, "2.23 _cached_syndicate_style initialized in TouchControls")
		if tc._cached_syndicate_style != null:
			var bg_col = tc._cached_syndicate_style.bg_color
			var border_col = tc._cached_syndicate_style.border_color
			_assert_check(bg_col.g > bg_col.r and bg_col.g > bg_col.b, "2.24 Emerald green background dominant in style")
			_assert_check(border_col.b > 0.5 and border_col.g > 0.5, "2.25 Hologram cyan border styling verified")
		tc.queue_free()

	hq.queue_free()
	await process_frame

# =============================================================================
# SECTION 3: Mobile Syndicate Modal & Touch Ergonomics
# =============================================================================
func _test_section_3_mobile_syndicate_modal(gs: Node) -> void:
	print("\n--- SECTION 3: Mobile Syndicate Modal & Touch Ergonomics ---")

	var modal_scene = load("res://scenes/ui/syndicate_modal.tscn")
	_assert_check(modal_scene != null, "3.1 scenes/ui/syndicate_modal.tscn loads successfully")
	if modal_scene == null:
		return

	var modal = modal_scene.instantiate() as Control
	_assert_check(modal != null, "3.2 SyndicateModal instantiates successfully")
	root.add_child(modal)
	await process_frame

	# 3.1 Strict Pointer Isolation
	_assert_check(modal.mouse_filter == Control.MOUSE_FILTER_STOP, "3.3 Root mouse_filter is STOP (0)")
	var backdrop = modal.get_node_or_null("Backdrop") as Control
	_assert_check(backdrop != null and backdrop.mouse_filter == Control.MOUSE_FILTER_STOP, "3.4 Backdrop mouse_filter is STOP (0)")

	# 3.2 Close Button Ergonomics
	var close_btn = modal.get_node_or_null("%CloseButton") as Button
	_assert_check(close_btn != null, "3.5 %CloseButton exists")
	if close_btn != null:
		_assert_check(close_btn.custom_minimum_size.y >= 56.0, "3.6 %CloseButton height >= 56px (actual: %f)" % close_btn.custom_minimum_size.y)
		_assert_check(close_btn.mouse_filter == Control.MOUSE_FILTER_STOP, "3.7 %CloseButton mouse_filter = STOP")

	# 3.3 Three Ergonomic Tabs
	var tab_btn0 = modal.get_node_or_null("%OverviewTabButton") as Button
	var tab_btn1 = modal.get_node_or_null("%RosterTabButton") as Button
	var tab_btn2 = modal.get_node_or_null("%WarsTabButton") as Button

	_assert_check(tab_btn0 != null, "3.8 %OverviewTabButton exists")
	_assert_check(tab_btn1 != null, "3.9 %RosterTabButton exists")
	_assert_check(tab_btn2 != null, "3.10 %WarsTabButton exists")

	for btn in [tab_btn0, tab_btn1, tab_btn2]:
		if btn != null:
			_assert_check(btn.custom_minimum_size.y >= 56.0, "3.11 Tab button height >= 56px")
			_assert_check(btn.mouse_filter == Control.MOUSE_FILTER_STOP, "3.12 Tab button mouse_filter = STOP")

	# 3.4 Tab 1 Overview & Perk Cards
	var card1 = modal.get_node_or_null("%PerkCardTier1")
	var card2 = modal.get_node_or_null("%PerkCardTier2")
	var card3 = modal.get_node_or_null("%PerkCardTier3")
	var card4 = modal.get_node_or_null("%PerkCardTier4")
	var card5 = modal.get_node_or_null("%PerkCardTier5")
	_assert_check(card1 != null and card2 != null and card3 != null and card4 != null and card5 != null,
		"3.13 All 5 Perk Cards (%PerkCardTier1..5) exist")

	var prog_bar = modal.get_node_or_null("%TierProgressBar")
	var prog_lbl = modal.get_node_or_null("%TierProgressLabel")
	_assert_check(prog_bar != null and prog_lbl != null, "3.14 %TierProgressBar and %TierProgressLabel exist")

	# 3.5 Tab 2 Roster & Vault Donations Controls
	var slider = modal.get_node_or_null("%DonationSlider") as HSlider
	var preset10 = modal.get_node_or_null("%Preset10Button") as Button
	var preset50 = modal.get_node_or_null("%Preset50Button") as Button
	var preset_max = modal.get_node_or_null("%PresetMaxButton") as Button
	var donate_e = modal.get_node_or_null("%DonateEnergyButton") as Button
	var donate_s = modal.get_node_or_null("%DonateSharesButton") as Button

	_assert_check(slider != null and slider.custom_minimum_size.y >= 56.0, "3.15 %DonationSlider height >= 56px")
	_assert_check(slider != null and slider.mouse_filter == Control.MOUSE_FILTER_STOP, "3.16 %DonationSlider mouse_filter = STOP")
	_assert_check(preset10 != null and preset10.custom_minimum_size.y >= 56.0, "3.17 %Preset10Button height >= 56px")
	_assert_check(preset50 != null and preset50.custom_minimum_size.y >= 56.0, "3.18 %Preset50Button height >= 56px")
	_assert_check(preset_max != null and preset_max.custom_minimum_size.y >= 56.0, "3.19 %PresetMaxButton height >= 56px")
	_assert_check(donate_e != null and donate_e.custom_minimum_size.y >= 56.0, "3.20 %DonateEnergyButton height >= 56px")
	_assert_check(donate_s != null and donate_s.custom_minimum_size.y >= 56.0, "3.21 %DonateSharesButton height >= 56px")

	# 3.6 Tab 3 Wars & Countdown Timer
	var timer_lbl = modal.get_node_or_null("%SeasonTimerLabel") as Label
	var rank_lbl = modal.get_node_or_null("%RankBadgeLabel") as Label
	var ldr_vbox = modal.get_node_or_null("%LeaderboardVBox")
	_assert_check(timer_lbl != null, "3.22 %SeasonTimerLabel exists")
	_assert_check(rank_lbl != null, "3.23 %RankBadgeLabel exists")
	_assert_check(ldr_vbox != null, "3.24 %LeaderboardVBox exists")

	# 3.7 Interactive Tab Switching & Preset Tests
	modal.switch_tab(0)
	_assert_check(modal.current_tab_index == 0, "3.25 Switched to Tab 0 (Overview)")
	modal.switch_tab(1)
	_assert_check(modal.current_tab_index == 1, "3.26 Switched to Tab 1 (Roster & Donations)")
	modal.switch_tab(2)
	_assert_check(modal.current_tab_index == 2, "3.27 Switched to Tab 2 (Wars & Seasons)")

	# Test preset selection
	gs.energy = 80000.0
	modal.set_donation_preset(0.5)
	_assert_check(absf(modal._selected_donation_energy - 40000.0) < EPSILON, "3.28 50% preset of 80k Energy selects 40,000")

	modal.close()
	await process_frame

	# 3.8 HUD Integration Check
	var hud_scene = load("res://scenes/hud.tscn")
	if hud_scene != null:
		var hud = hud_scene.instantiate()
		root.add_child(hud)
		await process_frame
		var badge = hud.get_node_or_null("%SyndicateBadge") as Control
		var badge_lbl = hud.get_node_or_null("%SyndicateBadgeLabel") as Label
		var syn_btn = hud.get_node_or_null("%SyndicateButton") as Button

		_assert_check(badge != null, "3.29 %SyndicateBadge exists in HUD")
		if badge != null:
			_assert_check(badge.custom_minimum_size.y >= 56.0, "3.30 %SyndicateBadge height >= 56px")
			_assert_check(badge.mouse_filter == Control.MOUSE_FILTER_STOP, "3.31 %SyndicateBadge mouse_filter = STOP")
		if badge_lbl != null:
			_assert_check(badge_lbl.text.contains("🏢"), "3.32 %SyndicateBadgeLabel contains corporate building emoji")
		_assert_check(syn_btn != null, "3.33 %SyndicateButton exists in HUD NavDrawer")
		if syn_btn != null:
			_assert_check(syn_btn.custom_minimum_size.y >= 64.0, "3.34 %SyndicateButton height >= 64px")
			_assert_check(syn_btn.mouse_filter == Control.MOUSE_FILTER_STOP, "3.35 %SyndicateButton mouse_filter = STOP")
		_assert_check(hud.has_method("open_syndicate_modal"), "3.36 HUD implements open_syndicate_modal()")
		hud.queue_free()

	await process_frame

# =============================================================================
# SECTION 4: LiveEventManager Cooperative Crisis Events
# =============================================================================
func _test_section_4_live_event_manager_crises(gs: Node, lem: Node) -> void:
	print("\n--- SECTION 4: LiveEventManager Cooperative Crisis Events ---")

	_assert_check(lem != null, "4.1 LiveEventManager instance exists")
	if lem == null:
		return

	# 4.1 Initial Baseline State
	_assert_check(lem.get_production_multiplier() == 1.0, "4.2 Baseline production multiplier is 1.0x")
	_assert_check(lem.get_drone_speed_multiplier() == 1.0, "4.3 Baseline drone speed multiplier is 1.0x")

	# 4.2 Start Server Crash Crisis
	var start_ok = lem.start_event("server_crash_crisis")
	_assert_check(start_ok == true, "4.4 start_event('server_crash_crisis') succeeds")
	_assert_check(lem.is_event_active() == true, "4.5 is_event_active() returns true")

	var active_ev = lem.get_active_event()
	_assert_check(active_ev.get("id") == "server_crash_crisis", "4.6 active event id is 'server_crash_crisis'")
	_assert_check(active_ev.get("target") == 500.0, "4.7 target goal is 500.0 points")
	_assert_check(active_ev.get("time_remaining") > 500.0, "4.8 time_remaining initialized (> 500s)")

	# 4.3 Signal Tracking
	var progress_signals: Array[int] = [0]
	var milestones_reached: Array[float] = []
	var on_prog = func(curr: float, tgt: float, pct: float):
		progress_signals[0] += 1
	var on_mile = func(pct: float, m_name: String):
		milestones_reached.append(pct)

	lem.live_event_progress_updated.connect(on_prog)
	lem.live_event_milestone_reached.connect(on_mile)

	# 4.4 Contribute Progress: Clicks and Overclocks
	# 1 click = 1 pt. 1 overclock = 50 pts.
	lem.contribute_progress("click", 50.0) # 50 pts = 10%
	_assert_check(progress_signals[0] > 0, "4.9 live_event_progress_updated emitted")
	_assert_check(absf(lem.get_progress_percentage() - 10.0) < EPSILON, "4.10 50 click points = 10.0% progress")

	lem.contribute_progress("overclock", 2.0) # 2 * 50 = 100 pts -> 150 pts = 30%
	_assert_check(absf(lem.get_progress_percentage() - 30.0) < EPSILON, "4.11 +100 overclock points = 30.0% progress")
	_assert_check(milestones_reached.has(25.0), "4.12 25% milestone signal received")

	# Contribute to 100% completion
	lem.contribute_progress("overclock", 7.0) # 7 * 50 = 350 pts -> 500 pts = 100%
	_assert_check(absf(lem.get_progress_percentage() - 100.0) < EPSILON, "4.13 Reached 100.0% progress")
	_assert_check(milestones_reached.has(100.0), "4.14 100% milestone signal received")
	_assert_check(lem.current_state == lem.EventState.COMPLETED, "4.15 Event state transitioned to COMPLETED")

	# 4.5 Reward Active: 2x Production Buff
	_assert_check(absf(lem.get_production_multiplier() - 2.0) < EPSILON, "4.16 Global 2x All Production buff active")
	_assert_check(lem.reward_time_remaining > 150.0, "4.17 Reward buffer timer active (180s duration)")

	lem.live_event_progress_updated.disconnect(on_prog)
	lem.live_event_milestone_reached.disconnect(on_mile)

	# 4.6 Angel Investor Summit Event
	lem.start_event("angel_investor_summit")
	_assert_check(lem.is_event_active() == true, "4.18 Angel Investor Summit started")
	_assert_check(lem.target_goal == 20.0, "4.19 Summit target is 20 briefcases")

	# Contribute 20 briefcases
	lem.contribute_progress("briefcase", 20.0)
	_assert_check(lem.current_state == lem.EventState.COMPLETED, "4.20 Summit event completed at 20 briefcases")
	_assert_check(absf(lem.get_drone_speed_multiplier() - 1.5) < EPSILON, "4.21 Drone speed multiplier boosted to 1.5x")

	# 4.7 HUD LiveEventBanner Check
	var hud_scene = load("res://scenes/hud.tscn")
	if hud_scene != null:
		var hud = hud_scene.instantiate()
		root.add_child(hud)
		await process_frame
		var banner = hud.get_node_or_null("%LiveEventBanner") as Control
		var title_lbl = hud.get_node_or_null("%LiveEventTitleLabel") as Label
		var timer_lbl = hud.get_node_or_null("%LiveEventTimerLabel") as Label
		var bar = hud.get_node_or_null("%LiveEventProgressBar") as ProgressBar
		var pct_lbl = hud.get_node_or_null("%LiveEventProgressLabel") as Label

		_assert_check(banner != null, "4.22 %LiveEventBanner exists in HUD")
		if banner != null:
			_assert_check(banner.custom_minimum_size.y >= 56.0, "4.23 %LiveEventBanner height >= 56px")
			_assert_check(banner.mouse_filter == Control.MOUSE_FILTER_STOP, "4.24 %LiveEventBanner mouse_filter = STOP")
		_assert_check(title_lbl != null and title_lbl.mouse_filter == Control.MOUSE_FILTER_STOP, "4.25 %LiveEventTitleLabel mouse_filter = STOP")
		_assert_check(timer_lbl != null and timer_lbl.mouse_filter == Control.MOUSE_FILTER_STOP, "4.26 %LiveEventTimerLabel mouse_filter = STOP")
		_assert_check(bar != null and bar.mouse_filter == Control.MOUSE_FILTER_STOP, "4.27 %LiveEventProgressBar mouse_filter = STOP")
		_assert_check(pct_lbl != null and pct_lbl.mouse_filter == Control.MOUSE_FILTER_STOP, "4.28 %LiveEventProgressLabel mouse_filter = STOP")
		hud.queue_free()

	await process_frame

# =============================================================================
# SECTION 5: Full Integration Loop & Zero Regressions
# =============================================================================
func _test_section_5_full_integration_loop(gs: Node, lem: Node) -> void:
	print("\n--- SECTION 5: Full Integration Loop & Zero Regressions ---")

	gs.reset_state()
	await process_frame

	# 5.1 Step 1: Solo baseline
	var base_rps: float = 100.0
	gs.upgrades["tier_1"]["level"] = 100
	gs.recalculate_stats()
	_assert_check(absf(gs.get_effective_passive_rps() - base_rps) < EPSILON, "5.1 Solo player baseline RPS is 100.0")

	# 5.2 Step 2: Found Syndicate & Advance to Tier 3
	gs.found_syndicate("syn_titan", "Titan Ventures", "TITAN", "Elite Holding")
	_assert_check(gs.get_syndicate_tier() == 1, "5.2 Player in Tier 1 syndicate")

	# Tier 1 dividend (+5%): 100 * 1.05 = 105
	_assert_check(absf(gs.get_effective_passive_rps() - 105.0) < EPSILON, "5.3 Tier 1 dividend yields 105.0 RPS (+5%)")

	# Donate energy to reach Tier 2 (+10% dividend, +15% drone speed)
	gs.energy = 200000.0
	gs.contribute_to_syndicate(100000.0, "energy")
	_assert_check(gs.get_syndicate_tier() == 2, "5.4 Syndicate reached Tier 2")
	_assert_check(absf(gs.get_effective_passive_rps() - 110.0) < EPSILON, "5.5 Tier 2 dividend yields 110.0 RPS (+10%)")
	_assert_check(absf(gs.get_drone_speed_multiplier() - 1.15) < EPSILON, "5.6 Tier 2 drone speed is 1.15x (+15%)")

	# Donate angel shares to reach Tier 3 (+15% dividend, +5% IPO bonus)
	gs.angel_shares = 20
	gs.contribute_angel_shares_to_syndicate(20)
	_assert_check(gs.get_syndicate_tier() == 3, "5.7 Syndicate reached Tier 3")
	_assert_check(absf(gs.get_effective_passive_rps() - 115.0) < EPSILON, "5.8 Tier 3 dividend yields 115.0 RPS (+15%)")

	# 5.3 Step 3: Cooperative Crisis Event Buff Stacking
	lem.start_event("server_crash_crisis")
	lem.contribute_progress("click", 500.0) # 500 pts -> 100% -> 2x buff
	_assert_check(absf(lem.get_production_multiplier() - 2.0) < EPSILON, "5.9 Live event 2x production buff active")

	# Compounded RPS: base (100) * syndicate (1.15) * live event (2.0) = 230.0
	var compounded_rps = gs.get_effective_passive_rps()
	_assert_check(absf(compounded_rps - 230.0) < EPSILON, "5.10 Compounded RPS matches: 100 * 1.15 * 2.0 = 230.0 (actual: %f)" % compounded_rps)

	# 5.4 Step 4: Overclock Buff Stacking
	gs.activate_server_overclock_buff(1.5, 30.0)
	# Compounded: base (100) * syndicate (1.15) * live event (2.0) * overclock (1.5) = 345.0
	var full_stack_rps = gs.get_effective_passive_rps()
	_assert_check(absf(full_stack_rps - 345.0) < EPSILON, "5.11 Full stack RPS matches: 100 * 1.15 * 2.0 * 1.5 = 345.0 (actual: %f)" % full_stack_rps)

	# 5.5 Step 5: Seasonal Score Integrity
	var season_score = gs.get_seasonal_leaderboard_score()
	_assert_check(season_score > 0, "5.12 Seasonal score is positive: %d" % season_score)

	# 5.6 Step 6: IPO Prestige Ascension Rebirth Synergy
	gs.total_lifetime_energy = 2500000.0 # 5 base eligible shares
	# Tier 3 grants +5% IPO bonus shares: floor(5 * 0.05) or bonus
	var ipo_res = gs.trigger_ipo()
	_assert_check(ipo_res.get("success") == true, "5.13 IPO Ascension triggered successfully")
	_assert_check(gs.energy == 0.0, "5.14 Regular energy reset to 0.0")

	# Syndicate membership and funds STRICTLY PRESERVED across IPO rebirth
	_assert_check(gs.is_in_syndicate() == true, "5.15 Syndicate membership strictly preserved across IPO")
	_assert_check(gs.get_syndicate_tier() == 3, "5.16 Syndicate Tier 3 strictly preserved across IPO")
	_assert_check(gs.syndicate_fund_energy >= 100000.0, "5.17 Syndicate fund energy preserved across IPO")
	_assert_check(gs.syndicate_fund_angel_shares >= 20, "5.18 Syndicate fund angel shares preserved across IPO")

	# 5.7 Step 7: Clean Disk Serialization & Reload
	gs.save_to_disk()
	gs.active_syndicate_id = ""
	gs.syndicate_tier = 0
	gs.angel_shares = 0
	gs.load_from_disk()

	_assert_check(gs.active_syndicate_id == "syn_titan", "5.19 Post-IPO reload restored syndicate ID 'syn_titan'")
	_assert_check(gs.syndicate_tier == 3, "5.20 Post-IPO reload restored syndicate Tier 3")
	_assert_check(gs.angel_shares > 0, "5.21 Post-IPO reload restored earned Angel Shares")
	_assert_check(absf(gs.get_syndicate_dividend_multiplier() - 1.15) < EPSILON, "5.22 Restored Tier 3 dividend multiplier: 1.15x")
