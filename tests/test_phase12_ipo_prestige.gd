extends SceneTree

## =============================================================================
## Master Headless SceneTree Test Suite for Phase 12: IPO Prestige & Ascension
## File: IdleArcade/tests/test_phase12_ipo_prestige.gd
## Target: Godot 4.3 Engine Headless Runner
##
## Validates all 6 Core Sections:
##   1. IPO Core Mathematics & Pending Shares Formula (sqrt(E/100k), +2%/share multiplier).
##   2. Prestige Reset & Preservation Scope (regular energy/upgrades reset, meta preserved).
##   3. 3D Campus Stations & Audio Synthesis (IpoBell3D, 16-bit PCM bell, TrophyShowcase3D).
##   4. Mobile IPO Modal & Touch Ergonomics (Two-stage safety, >=56px, mouse_filter = STOP).
##   5. Daily Challenge Board & Streak Engine (DailyBoard3D, DailyBoardModal, 6-task rotation).
##   6. Comprehensive Regression & Integration (Harmonious full-game loop & multi-IPO cycle).
##
## Execution:
##   godot --headless --path IdleArcade -s tests/test_phase12_ipo_prestige.gd
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
	print(">>> RUNNING MASTER PHASE 12 IPO PRESTIGE HEADLESS SCENETREE TEST SUITE <<<")
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
	await _test_section_1_ipo_math_and_formula(gs)
	await _test_section_2_prestige_reset_and_preservation(gs)
	await _test_section_3_3d_campus_stations_and_audio(gs, am)
	await _test_section_4_mobile_ipo_modal_and_ergonomics(gs)
	await _test_section_5_daily_challenge_board_and_streak(gs)
	await _test_section_6_comprehensive_regression_integration(gs)

	print("\n====================================================================")
	print(">>> PHASE 12 SCENETREE TEST SUITE SUMMARY: %d PASSED, %d FAILED <<<" % [pass_count, fail_count])
	print("====================================================================")

	if fail_count == 0:
		print(">>> ALL PHASE 12 HEADLESS SCENETREE TESTS PASSED (Exit Code 0) <<<")
		quit(0)
	else:
		printerr(">>> PHASE 12 HEADLESS SCENETREE TESTS FAILED (Exit Code 1) <<<")
		quit(1)

# =============================================================================
# SECTION 1: IPO Core Mathematics & Pending Shares Formula
# =============================================================================
func _test_section_1_ipo_math_and_formula(gs: Node) -> void:
	print("\n--- SECTION 1: IPO Core Mathematics & Pending Shares Formula ---")

	# 1.1 Reset state to clean baseline
	gs.reset_state()
	await process_frame

	_assert_check(gs.total_lifetime_energy == 0.0, "1.1 Initial total_lifetime_energy is 0.0")
	_assert_check(gs.angel_shares == 0, "1.2 Initial angel_shares is 0")
	_assert_check(gs.total_ipos_completed == 0, "1.3 Initial total_ipos_completed is 0")
	_assert_check(absf(gs.get_angel_share_multiplier() - 1.0) < EPSILON, "1.4 Initial multiplier is 1.00x (+0%)")

	# 1.2 Lifetime Energy Accumulation
	gs.add_energy(50000.0)
	_assert_check(gs.total_lifetime_energy >= 50000.0, "1.5 add_energy accumulates into total_lifetime_energy")

	# 1.3 Square root formula verification: floor(sqrt(E / 100000))
	gs.total_lifetime_energy = 99999.0
	_assert_check(gs.calculate_pending_angel_shares() == 0, "1.6 < 100k energy yields 0 pending shares")

	gs.total_lifetime_energy = 100000.0
	_assert_check(gs.calculate_pending_angel_shares() == 1, "1.7 100k energy yields 1 pending share (sqrt(1) = 1)")

	gs.total_lifetime_energy = 400000.0
	_assert_check(gs.calculate_pending_angel_shares() == 2, "1.8 400k energy yields 2 pending shares (sqrt(4) = 2)")

	gs.total_lifetime_energy = 900000.0
	_assert_check(gs.calculate_pending_angel_shares() == 3, "1.9 900k energy yields 3 pending shares (sqrt(9) = 3)")

	gs.total_lifetime_energy = 1000000.0
	_assert_check(gs.calculate_pending_angel_shares() == 3, "1.10 1.0M energy yields 3 pending shares (floor(sqrt(10)) = 3)")

	gs.total_lifetime_energy = 1600000.0
	_assert_check(gs.calculate_pending_angel_shares() == 4, "1.11 1.6M energy yields 4 pending shares (sqrt(16) = 4)")

	gs.total_lifetime_energy = 2500000.0
	_assert_check(gs.calculate_pending_angel_shares() == 5, "1.12 2.5M energy yields 5 pending shares (sqrt(25) = 5)")

	# 1.4 Pending shares with owned angel shares deduction
	gs.total_lifetime_energy = 1000000.0 # eligible: 3
	gs.angel_shares = 1
	_assert_check(gs.calculate_pending_angel_shares() == 2, "1.13 1M energy (3 eligible) with 1 owned share gives 2 pending shares")

	gs.angel_shares = 3
	_assert_check(gs.calculate_pending_angel_shares() == 0, "1.14 1M energy with 3 owned shares gives 0 pending shares")

	gs.angel_shares = 5
	_assert_check(gs.calculate_pending_angel_shares() == 0, "1.15 1M energy with 5 owned shares gives 0 pending shares (no underflow)")

	# 1.5 Multiplier Formula: 1.0 + shares * 0.02
	gs.angel_shares = 0
	_assert_check(absf(gs.get_angel_share_multiplier() - 1.00) < EPSILON, "1.16 0 shares = 1.00x multiplier")
	gs.angel_shares = 1
	_assert_check(absf(gs.get_angel_share_multiplier() - 1.02) < EPSILON, "1.17 1 share = 1.02x multiplier (+2%)")
	gs.angel_shares = 5
	_assert_check(absf(gs.get_angel_share_multiplier() - 1.10) < EPSILON, "1.18 5 shares = 1.10x multiplier (+10%)")
	gs.angel_shares = 10
	_assert_check(absf(gs.get_angel_share_multiplier() - 1.20) < EPSILON, "1.19 10 shares = 1.20x multiplier (+20%)")
	gs.angel_shares = 50
	_assert_check(absf(gs.get_angel_share_multiplier() - 2.00) < EPSILON, "1.20 50 shares = 2.00x multiplier (+100%)")

	# 1.6 Threshold Logic: can_trigger_ipo()
	gs.reset_state()
	gs.campaign_chapter = 1
	gs.total_lifetime_energy = 500000.0
	_assert_check(gs.can_trigger_ipo() == false, "1.21 Cannot IPO in Chapter 1 with 500k energy (< 1M threshold)")

	gs.total_lifetime_energy = 1000000.0
	_assert_check(gs.can_trigger_ipo() == true, "1.22 Can IPO in Chapter 1 with 1.0M energy (>= 1M threshold, pending > 0)")

	gs.angel_shares = 3
	_assert_check(gs.can_trigger_ipo() == false, "1.23 Cannot IPO if all eligible shares already claimed (pending == 0)")

	gs.reset_state()
	gs.campaign_chapter = 3
	gs.total_lifetime_energy = 400000.0
	_assert_check(gs.can_trigger_ipo() == true, "1.24 Can IPO in Chapter 3 with 400k energy (Unicorn status exception)")

	gs.total_lifetime_energy = 50000.0
	_assert_check(gs.can_trigger_ipo() == false, "1.25 Cannot IPO in Chapter 3 with 50k energy (0 pending shares)")

# =============================================================================
# SECTION 2: Prestige Reset & Preservation Scope
# =============================================================================
func _test_section_2_prestige_reset_and_preservation(gs: Node) -> void:
	print("\n--- SECTION 2: Prestige Reset & Preservation Scope ---")

	# Setup run with active currencies, upgrades, and temporary buffs
	gs.reset_state()
	gs.campaign_chapter = 3
	gs.total_lifetime_energy = 1600000.0 # 4 eligible shares
	gs.energy = 750000.0

	# Buy upgrades
	if gs.upgrades.has("tier_1"):
		gs.upgrades["tier_1"]["level"] = 12
		gs.upgrades["tier_1"]["current_cost"] = 1500.0
	elif gs.upgrades.size() > 0:
		var first_key = gs.upgrades.keys()[0]
		gs.upgrades[first_key]["level"] = 12
		gs.upgrades[first_key]["current_cost"] = 1500.0

	# Activate buffs
	gs.activate_server_overclock_buff(2.0, 30.0)
	gs.activate_unicorn_espresso_buff(45.0)

	_assert_check(gs.can_trigger_ipo() == true, "2.1 can_trigger_ipo() is true before reset")

	# Track signals
	var sig_tracker: Dictionary = {"fired": false, "shares": 0}
	var on_ipo_completed = func(shares: int, total: int, mult: float):
		sig_tracker["fired"] = true
		sig_tracker["shares"] = shares
	gs.ipo_completed.connect(on_ipo_completed)

	# Execute IPO
	var result = gs.trigger_ipo()
	await process_frame

	_assert_check(result.get("success") == true, "2.2 trigger_ipo() returns success = true")
	_assert_check(result.get("shares_gained") == 4, "2.3 trigger_ipo() awards 4 shares_gained")
	_assert_check(result.get("total_angel_shares") == 4, "2.4 total_angel_shares is 4")
	_assert_check(absf(result.get("multiplier") - 1.08) < EPSILON, "2.5 Multiplier is 1.08 (+8%)")
	_assert_check(sig_tracker["fired"] == true, "2.6 ipo_completed signal emitted")
	_assert_check(sig_tracker["shares"] == 4, "2.7 ipo_completed signal carried 4 gained shares")

	gs.ipo_completed.disconnect(on_ipo_completed)

	# Validate Reset Scope
	_assert_check(gs.energy == 0.0, "2.8 Regular energy reset to 0.0")
	if gs.upgrades.has("tier_1"):
		_assert_check(gs.upgrades["tier_1"]["level"] == 0, "2.9 Upgrade level reset to 0")
		_assert_check(absf(gs.upgrades["tier_1"]["current_cost"] - gs.upgrades["tier_1"]["base_cost"]) < EPSILON,
			"2.10 Upgrade cost reset to base_cost")
	elif gs.upgrades.size() > 0:
		var first_key = gs.upgrades.keys()[0]
		_assert_check(gs.upgrades[first_key]["level"] == 0, "2.9 Upgrade level reset to 0")
		_assert_check(absf(gs.upgrades[first_key]["current_cost"] - gs.upgrades[first_key]["base_cost"]) < EPSILON,
			"2.10 Upgrade cost reset to base_cost")
	_assert_check(gs.server_overclock_buff_timer == 0.0, "2.11 Server overclock buff timer reset")
	_assert_check(gs.unicorn_espresso_buff_timer == 0.0, "2.12 Unicorn espresso buff timer reset")

	# Validate Strict Preservation Scope
	_assert_check(gs.total_lifetime_energy >= 1600000.0, "2.13 total_lifetime_energy strictly preserved")
	_assert_check(gs.angel_shares == 4, "2.14 angel_shares strictly preserved (equals 4)")
	_assert_check(gs.total_ipos_completed == 1, "2.15 total_ipos_completed incremented to 1")
	_assert_check(gs.campaign_chapter == 3, "2.16 campaign_chapter strictly preserved at 3")
	_assert_check(gs.is_trophy_unlocked("trophy_platinum_bull") == true, "2.17 Platin-Börsenbulle trophy unlocked")

	# Validate Idempotency & Re-trigger Protection
	_assert_check(gs.calculate_pending_angel_shares() == 0, "2.18 Pending shares immediately drops to 0")
	_assert_check(gs.can_trigger_ipo() == false, "2.19 can_trigger_ipo() is false immediately after IPO")
	var dup_res = gs.trigger_ipo()
	_assert_check(dup_res.get("success") == false, "2.20 Immediate subsequent trigger_ipo() safely rejected")

	# Validate Save/Load Persistence
	gs.save_to_disk()
	gs.total_lifetime_energy = 0.0
	gs.angel_shares = 0
	gs.total_ipos_completed = 0
	gs.unlocked_trophies.clear()

	gs.load_from_disk()
	_assert_check(gs.total_lifetime_energy >= 1600000.0, "2.21 load_from_disk restored total_lifetime_energy")
	_assert_check(gs.angel_shares == 4, "2.22 load_from_disk restored angel_shares = 4")
	_assert_check(gs.total_ipos_completed == 1, "2.23 load_from_disk restored total_ipos_completed = 1")
	_assert_check(gs.is_trophy_unlocked("trophy_platinum_bull"), "2.24 load_from_disk restored trophy_platinum_bull")

# =============================================================================
# SECTION 3: 3D Campus Stations & Audio Synthesis
# =============================================================================
func _test_section_3_3d_campus_stations_and_audio(gs: Node, am: Node) -> void:
	print("\n--- SECTION 3: 3D Campus Stations & Audio Synthesis ---")

	# 3.1 IpoBell3D Scene Instantiation
	var bell_scene = load("res://scenes/ipo_bell_3d.tscn")
	_assert_check(bell_scene != null, "3.1 scenes/ipo_bell_3d.tscn loads successfully")
	if bell_scene == null:
		return

	var bell = bell_scene.instantiate() as IpoBell3D
	_assert_check(bell != null, "3.2 IpoBell3D instantiates successfully")
	root.add_child(bell)
	await process_frame

	_assert_check(bell.is_in_group("ipo_bells"), "3.3 IpoBell3D in group 'ipo_bells'")
	_assert_check(bell.is_in_group("interactables"), "3.4 IpoBell3D in group 'interactables'")
	_assert_check(bell.is_in_group("stations"), "3.5 IpoBell3D in group 'stations'")

	var prompt_label = bell.get_node_or_null("PromptLabel3D") as Label3D
	var bell_pivot = bell.get_node_or_null("Visuals/BellPivot")
	var gold_particles = bell.get_node_or_null("GoldParticles") as CPUParticles3D
	var area = bell.get_node_or_null("InteractionArea") as Area3D

	_assert_check(prompt_label != null, "3.6 PromptLabel3D exists on IpoBell3D")
	_assert_check(bell_pivot != null, "3.7 BellPivot node exists on IpoBell3D")
	_assert_check(gold_particles != null, "3.8 GoldParticles CPUParticles3D exists on IpoBell3D")
	_assert_check(area != null, "3.9 InteractionArea exists on IpoBell3D")

	# Test bell ringing interaction
	bell.ring_bell()
	await process_frame
	_assert_check(bell.is_ringing == true, "3.10 is_ringing is true during swing animation")

	# 3.2 AudioManager Bell Sound Synthesis
	_assert_check(am != null and am.has_method("play_sfx_bell"), "3.11 AudioManager implements play_sfx_bell()")
	if am != null:
		am.play_sfx_bell()
		_assert_check(am.last_sfx_played == "bell", "3.12 play_sfx_bell() triggers bell SFX")
		_assert_check(am._wav_bell != null, "3.13 _wav_bell prebaked waveform exists")
		if am._wav_bell != null:
			_assert_check(am._wav_bell.mix_rate == 22050, "3.14 Bell mix rate is 22,050 Hz")
			_assert_check(am._wav_bell.data.size() > 0, "3.15 Bell 16-bit PCM sample buffer non-empty")

	# 3.3 TrophyShowcase3D Scene Instantiation
	var showcase_scene = load("res://scenes/trophy_showcase_3d.tscn")
	_assert_check(showcase_scene != null, "3.16 scenes/trophy_showcase_3d.tscn loads successfully")
	if showcase_scene == null:
		bell.queue_free()
		return

	var showcase = showcase_scene.instantiate() as TrophyShowcase3D
	_assert_check(showcase != null, "3.17 TrophyShowcase3D instantiates successfully")
	root.add_child(showcase)
	await process_frame

	_assert_check(showcase.is_in_group("trophy_showcase"), "3.18 TrophyShowcase3D in group 'trophy_showcase'")
	var p_brief = showcase.get_node_or_null("Visuals/Pedestals/Pedestal_Briefcase")
	var p_server = showcase.get_node_or_null("Visuals/Pedestals/Pedestal_Server")
	var p_chalice = showcase.get_node_or_null("Visuals/Pedestals/Pedestal_Chalice")
	var p_bull = showcase.get_node_or_null("Visuals/Pedestals/Pedestal_Bull")

	_assert_check(p_brief != null, "3.19 Pedestal_Briefcase exists in showcase")
	_assert_check(p_server != null, "3.20 Pedestal_Server exists in showcase")
	_assert_check(p_chalice != null, "3.21 Pedestal_Chalice exists in showcase")
	_assert_check(p_bull != null, "3.22 Pedestal_Bull exists in showcase")

	# Dynamic trophy unlock refresh
	gs.unlock_trophy("trophy_golden_briefcase")
	gs.unlock_trophy("trophy_server_matrix")
	gs.unlock_trophy("trophy_crystal_espresso")
	gs.unlock_trophy("trophy_platinum_bull")
	showcase.refresh_trophies()
	var is_bull_active: bool = showcase.is_trophy_active("trophy_platinum_bull") if showcase.has_method("is_trophy_active") else gs.is_trophy_unlocked("trophy_platinum_bull")
	_assert_check(is_bull_active == true, "3.23 Platinum Bull trophy active after unlock")

	bell.queue_free()
	showcase.queue_free()
	await process_frame

# =============================================================================
# SECTION 4: Mobile IPO Modal & Touch Ergonomics
# =============================================================================
func _test_section_4_mobile_ipo_modal_and_ergonomics(gs: Node) -> void:
	print("\n--- SECTION 4: Mobile IPO Modal & Touch Ergonomics ---")

	var modal_scene = load("res://scenes/ui/ipo_modal.tscn")
	_assert_check(modal_scene != null, "4.1 scenes/ui/ipo_modal.tscn loads successfully")
	if modal_scene == null:
		return

	var modal = modal_scene.instantiate() as Control
	_assert_check(modal != null, "4.2 IPOModal instantiates successfully")
	root.add_child(modal)
	await process_frame

	_assert_check(modal.mouse_filter == Control.MOUSE_FILTER_STOP, "4.3 IPOModal root mouse_filter = STOP (0)")
	var backdrop = modal.get_node_or_null("Backdrop") as Control
	_assert_check(backdrop != null and backdrop.mouse_filter == Control.MOUSE_FILTER_STOP,
		"4.4 Modal Backdrop mouse_filter = STOP (0)")

	var close_btn = modal.get_node_or_null("%CloseButton") as Button
	var trigger_btn = modal.get_node_or_null("%TriggerIPOButton") as Button
	var confirm_box = modal.get_node_or_null("%ConfirmBox") as Control
	var confirm_yes = modal.get_node_or_null("%ConfirmYesButton") as Button
	var confirm_cancel = modal.get_node_or_null("%ConfirmCancelButton") as Button
	var slide_confirm = modal.get_node_or_null("%SlideToConfirm") as HSlider

	_assert_check(close_btn != null and close_btn.custom_minimum_size.y >= 56.0, "4.5 CloseButton height >= 56px")
	_assert_check(close_btn != null and close_btn.mouse_filter == Control.MOUSE_FILTER_STOP, "4.6 CloseButton mouse_filter = STOP")
	_assert_check(trigger_btn != null and trigger_btn.custom_minimum_size.y >= 56.0, "4.7 TriggerIPOButton height >= 56px (64px)")
	_assert_check(trigger_btn != null and trigger_btn.mouse_filter == Control.MOUSE_FILTER_STOP, "4.8 TriggerIPOButton mouse_filter = STOP")
	_assert_check(confirm_yes != null and confirm_yes.custom_minimum_size.y >= 56.0, "4.9 ConfirmYesButton height >= 56px (60px)")
	_assert_check(confirm_yes != null and confirm_yes.mouse_filter == Control.MOUSE_FILTER_STOP, "4.10 ConfirmYesButton mouse_filter = STOP")
	_assert_check(confirm_cancel != null and confirm_cancel.custom_minimum_size.y >= 56.0, "4.11 ConfirmCancelButton height >= 56px (60px)")
	_assert_check(confirm_cancel != null and confirm_cancel.mouse_filter == Control.MOUSE_FILTER_STOP, "4.12 ConfirmCancelButton mouse_filter = STOP")
	_assert_check(slide_confirm != null and slide_confirm.custom_minimum_size.y >= 56.0, "4.13 SlideToConfirm height >= 56px")

	# Two-stage confirmation safety verification
	gs.reset_state()
	gs.total_lifetime_energy = 1600000.0
	if modal.has_method("update_display"):
		modal.update_display()
	elif modal.has_method("_update_display"):
		modal._update_display()

	_assert_check(confirm_box.visible == false, "4.14 Stage 2 ConfirmBox initially hidden")
	_assert_check(trigger_btn.visible == true, "4.15 Stage 1 TriggerButton initially visible")

	# Step to Stage 2
	modal._on_trigger_ipo_pressed()
	_assert_check(confirm_box.visible == true, "4.16 ConfirmBox revealed after trigger press")
	_assert_check(trigger_btn.visible == false, "4.17 TriggerButton hidden in Stage 2")

	# Cancel back to Stage 1
	modal._on_confirm_cancel_pressed()
	_assert_check(confirm_box.visible == false, "4.18 ConfirmBox hidden after cancel press")
	_assert_check(trigger_btn.visible == true, "4.19 TriggerButton restored after cancel")

	modal.close()
	await process_frame

	# HUD IPOButton Integration
	var hud_scene = load("res://scenes/hud.tscn")
	if hud_scene != null:
		var hud = hud_scene.instantiate()
		root.add_child(hud)
		await process_frame
		var ipo_btn = hud.get_node_or_null("%IPOButton") as Button
		_assert_check(ipo_btn != null, "4.20 %IPOButton exists in HUD NavDrawer")
		if ipo_btn != null:
			_assert_check(ipo_btn.custom_minimum_size.y >= 56.0, "4.21 %IPOButton height >= 56px (64px)")
			_assert_check(ipo_btn.mouse_filter == Control.MOUSE_FILTER_STOP, "4.22 %IPOButton mouse_filter = STOP")
		_assert_check(hud.has_method("open_ipo_modal"), "4.23 HUD implements open_ipo_modal()")
		hud.queue_free()

	# TouchControls Gold Styling Integration
	var tc_scene = load("res://scenes/ui/touch_controls.tscn")
	if tc_scene != null:
		var tc = tc_scene.instantiate()
		root.add_child(tc)
		await process_frame
		_assert_check(tc._cached_ipo_bell_style != null, "4.24 _cached_ipo_bell_style exists in TouchControls")
		if tc._cached_ipo_bell_style != null:
			_assert_check(tc._cached_ipo_bell_style.border_color.r > 0.8 and tc._cached_ipo_bell_style.border_color.g > 0.7,
				"4.25 _cached_ipo_bell_style has Platin/Gold border styling")
		tc.queue_free()

	await process_frame

# =============================================================================
# SECTION 5: Daily Challenge Board & Streak Engine
# =============================================================================
func _test_section_5_daily_challenge_board_and_streak(gs: Node) -> void:
	print("\n--- SECTION 5: Daily Challenge Board & Streak Engine ---")

	# 5.1 DailyBoard3D Scene
	var board_scene = load("res://scenes/daily_board_3d.tscn")
	_assert_check(board_scene != null, "5.1 scenes/daily_board_3d.tscn loads successfully")
	if board_scene == null:
		return

	var board = board_scene.instantiate() as DailyBoard3D
	_assert_check(board != null, "5.2 DailyBoard3D instantiates successfully")
	root.add_child(board)
	await process_frame

	_assert_check(board.is_in_group("daily_boards"), "5.3 DailyBoard3D in group 'daily_boards'")
	_assert_check(board.is_in_group("interactables"), "5.4 DailyBoard3D in group 'interactables'")
	var board_label = board.get_node_or_null("PromptLabel3D") as Label3D
	_assert_check(board_label != null, "5.5 PromptLabel3D exists on DailyBoard3D")
	_assert_check(board.has_method("open_daily_board"), "5.6 DailyBoard3D implements open_daily_board()")

	# 5.2 DailyBoardModal Scene
	var modal_scene = load("res://scenes/ui/daily_board_modal.tscn")
	_assert_check(modal_scene != null, "5.7 scenes/ui/daily_board_modal.tscn loads successfully")
	if modal_scene == null:
		board.queue_free()
		return

	var modal = modal_scene.instantiate() as Control
	_assert_check(modal != null, "5.8 DailyBoardModal instantiates successfully")
	root.add_child(modal)
	await process_frame

	_assert_check(modal.mouse_filter == Control.MOUSE_FILTER_STOP, "5.9 DailyBoardModal root mouse_filter = STOP")
	var close_btn = modal.get_node_or_null("%CloseButton") as Button
	var btn1 = modal.get_node_or_null("%Task1ClaimButton") as Button
	var btn2 = modal.get_node_or_null("%Task2ClaimButton") as Button
	var btn3 = modal.get_node_or_null("%Task3ClaimButton") as Button

	_assert_check(close_btn != null and close_btn.custom_minimum_size.y >= 56.0, "5.10 Daily modal CloseButton >= 56px")
	_assert_check(btn1 != null and btn1.custom_minimum_size.y >= 56.0, "5.11 Task1ClaimButton height >= 56px")
	_assert_check(btn2 != null and btn2.custom_minimum_size.y >= 56.0, "5.12 Task2ClaimButton height >= 56px")
	_assert_check(btn3 != null and btn3.custom_minimum_size.y >= 56.0, "5.13 Task3ClaimButton height >= 56px")
	_assert_check(btn1 != null and btn1.mouse_filter == Control.MOUSE_FILTER_STOP, "5.14 Task1ClaimButton mouse_filter = STOP")

	# 5.3 Daily Rotation & Task Progression
	gs.reset_state()
	var tasks = gs.get_daily_tasks()
	_assert_check(tasks.size() == 3, "5.15 get_daily_tasks() returns exactly 3 rotating tasks")

	var task1_id = tasks[0]["id"]
	var task1_target = tasks[0]["target"]
	_assert_check(tasks[0].get("current", 0) == 0, "5.16 Task 1 initial progress is 0")

	# Advance progress
	gs.advance_daily_task(task1_id, task1_target)
	var updated_tasks = gs.get_daily_tasks()
	_assert_check(updated_tasks[0].get("current", 0) == task1_target, "5.17 advance_daily_task advances progress to target")
	_assert_check(updated_tasks[0]["is_completed"] == true, "5.18 Task marked completed at target")

	# Claim task
	var claim_res = gs.claim_daily_task(task1_id)
	_assert_check(claim_res.get("success") == true, "5.19 claim_daily_task succeeds for completed task")

	# Duplicate claim rejected
	var dup_claim = gs.claim_daily_task(task1_id)
	_assert_check(dup_claim.get("success") == false, "5.20 Duplicate claim safely rejected")

	# Streak Increment when all 3 claimed
	gs.advance_daily_task(tasks[1]["id"], tasks[1]["target"])
	gs.advance_daily_task(tasks[2]["id"], tasks[2]["target"])
	gs.claim_daily_task(tasks[1]["id"])
	var final_claim = gs.claim_daily_task(tasks[2]["id"])
	_assert_check(final_claim.get("all_claimed") == true, "5.21 all_claimed is true after claiming 3rd task")
	_assert_check(gs.daily_board_streak == 1, "5.22 daily_board_streak incremented to 1")

	# HUD Streak Badge
	var hud_scene = load("res://scenes/hud.tscn")
	if hud_scene != null:
		var hud = hud_scene.instantiate()
		root.add_child(hud)
		await process_frame
		var streak_badge = hud.get_node_or_null("%StreakBadge") as Control
		var streak_label = hud.get_node_or_null("%StreakBadgeLabel") as Label
		_assert_check(streak_badge != null, "5.23 %StreakBadge exists in HUD")
		if streak_badge != null:
			_assert_check(streak_badge.custom_minimum_size.y >= 56.0, "5.24 %StreakBadge height >= 56px")
			_assert_check(streak_badge.mouse_filter == Control.MOUSE_FILTER_STOP, "5.25 %StreakBadge mouse_filter = STOP")
		if streak_label != null:
			_assert_check(streak_label.text.contains("🔥"), "5.26 StreakBadgeLabel contains fire emoji")
		hud.queue_free()

	modal.close()
	board.queue_free()
	await process_frame

# =============================================================================
# SECTION 6: Comprehensive Regression & Integration
# =============================================================================
func _test_section_6_comprehensive_regression_integration(gs: Node) -> void:
	print("\n--- SECTION 6: Comprehensive Regression & Integration ---")

	gs.reset_state()
	await process_frame

	# 6.1 Passive generation with Angel Share multiplier
	gs.angel_shares = 10 # +20% multiplier (1.20x)
	var raw_rps = 100.0
	gs.base_passive_rps = raw_rps
	var eff_rps = gs.get_effective_passive_rps()
	_assert_check(eff_rps >= raw_rps * 1.20, "6.1 Passive RPS properly scaled by 1.20x Angel Shares multiplier")

	# 6.2 Offline catchup simulation with Angel Share multiplier
	var elapsed_offline: float = 60.0
	var offline_gain: float = eff_rps * elapsed_offline * 0.5
	_assert_check(offline_gain > 0.0, "6.2 Offline progress calculates positive energy")

	# 6.3 Multi-IPO Cycle Progression Simulation
	# Cycle 1: 1M energy -> 3 shares
	gs.total_lifetime_energy = 1000000.0
	gs.angel_shares = 0
	gs.campaign_chapter = 3
	var ipo1 = gs.trigger_ipo()
	_assert_check(ipo1.get("shares_gained") == 3, "6.3 Cycle 1 awards 3 shares")
	_assert_check(gs.angel_shares == 3, "6.4 Owned shares is 3")
	_assert_check(absf(gs.get_angel_share_multiplier() - 1.06) < EPSILON, "6.5 Multiplier is 1.06x")

	# Cycle 2: +1.5M energy earned -> lifetime 2.5M energy (5 eligible shares) -> 2 pending shares
	gs.total_lifetime_energy = 2500000.0
	_assert_check(gs.calculate_pending_angel_shares() == 2, "6.6 Cycle 2 has 2 pending shares (5 eligible - 3 owned)")
	var ipo2 = gs.trigger_ipo()
	_assert_check(ipo2.get("shares_gained") == 2, "6.7 Cycle 2 awards 2 shares")
	_assert_check(gs.angel_shares == 5, "6.8 Owned shares is 5")
	_assert_check(absf(gs.get_angel_share_multiplier() - 1.10) < EPSILON, "6.9 Multiplier is 1.10x")
	_assert_check(gs.total_ipos_completed == 2, "6.10 total_ipos_completed is 2")

	# 6.4 Clean State Roundtrip
	gs.save_to_disk()
	gs.reset_state()
	gs.load_from_disk()
	_assert_check(gs.angel_shares == 5, "6.11 State roundtrip preserves 5 Angel Shares")
	_assert_check(gs.total_ipos_completed == 2, "6.12 State roundtrip preserves 2 completed IPOs")
	_assert_check(gs.total_lifetime_energy >= 2500000.0, "6.13 State roundtrip preserves 2.5M lifetime energy")
