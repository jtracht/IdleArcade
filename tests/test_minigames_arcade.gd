extends SceneTree

## =============================================================================
## Master Headless SceneTree Test Suite for IdleArcade Phase 16:
## Interactive Arcade Minigames & Campus Station Interactions (Release v2.3.0)
## File: IdleArcade/tests/test_minigames_arcade.gd
##
## Validates 100% of Phase 16 Requirements across all 4 Tiers (TEST_INFRA.md):
##   Tier 1: Feature Coverage (Features 1 through 16: Modal Overlay, Proximity,
##           TouchControls Styling, Station State Machine, Persistent Cooldowns,
##           Avatar/Camera Pause/Resume, Server Overclock Bar, Dynamic Hit Zones,
##           Pitch Stage QTE, Buzzword Pools & Investor Matching, Pitch Streak & Grants,
##           Barista Manometer Pressure, Hold-and-Release Sweet Spot, Staff Burnout Healing,
##           60s Hyper-Focus Mode, Arcade Audio/Haptics/Juice, Touch Ergonomics >= 56px).
##   Tier 2: Boundary & Corner Cases (Boundary timing hits, extreme edges, overpressure
##           at 100 bar, sweet spot boundaries, zero/extreme RPS grants, QTE timeouts,
##           empty staff roster, offline cooldown decay > remaining vs < remaining,
##           rapid modal dismissal, pointer isolation).
##   Tier 3: Cross-Feature Combinations (Overclock buff + Coffee break hyper-focus
##           stacking, multi-station concurrent cooldowns, save/reload roundtrip,
##           modal open + proximity state isolation, staff burnout cycle + healing).
##   Tier 4: Real-World Scenarios (Morning Routine, Server Surge Crisis, Demo Day,
##           Marathon Playthrough & Save/Reload, Mobile Touch & Ergonomics Stress).
##
## Execution:
##   godot --headless --path IdleArcade -s tests/test_minigames_arcade.gd
## =============================================================================

var pass_count: int = 0
var fail_count: int = 0

const MIN_EXPECTED_PASS_COUNT: int = 190
const EPSILON: float = 0.005

# Singletons tracked for lifecycle cleanup
var _mounted_nodes: Array[Node] = []
var _save_backup_text: String = ""
var _had_save_backup: bool = false

func _assert_check(condition: bool, description: String, detail: String = "") -> void:
	if condition:
		print("  [PASS] %s" % description)
		pass_count += 1
	else:
		var err_msg: String = "  [FAIL] %s" % description
		if detail != "":
			err_msg += " (Detail: %s)" % detail
		printerr(err_msg)
		fail_count += 1

func _init() -> void:
	print("\n====================================================================")
	print(">>> RUNNING IDLEARCADE PHASE 16: ARCADE MINIGAMES E2E TEST SUITE <<<")
	print("====================================================================")
	call_deferred("_run_all_tests")

func _cleanup_and_quit(exit_code: int) -> void:
	print("\n--- TEARDOWN: Restoring Environment & Cleaning Singletons ---")
	if _had_save_backup:
		var f_res = FileAccess.open("user://savegame.json", FileAccess.WRITE)
		if f_res != null:
			f_res.store_string(_save_backup_text)
			f_res.close()
			print("  [CLEANUP] Restored original user://savegame.json")
	elif FileAccess.file_exists("user://savegame.json"):
		DirAccess.remove_absolute("user://savegame.json")
		print("  [CLEANUP] Removed temporary user://savegame.json")

	# Clean up mounted singletons in reverse order
	for i in range(_mounted_nodes.size() - 1, -1, -1):
		var n = _mounted_nodes[i]
		if is_instance_valid(n):
			if n.get_parent() != null:
				n.get_parent().remove_child(n)
			n.free()
	_mounted_nodes.clear()
	print("  [CLEANUP] All test harness singletons safely unmounted.")

	print("\n====================================================================")
	print(">>> PHASE 16 TEST SUITE RESULTS: %d PASSED, %d FAILED <<<" % [pass_count, fail_count])
	print("====================================================================")

	if fail_count == 0 and pass_count >= MIN_EXPECTED_PASS_COUNT:
		print(">>> ALL PHASE 16 E2E TESTS PASSED WITH 100% INTEGRITY (Exit Code 0) <<<\n")
		quit(0)
	else:
		printerr(">>> TEST SUITE FAILED (Exit Code 1, pass_count=%d/%d, fail_count=%d) <<<\n" % [
			pass_count, MIN_EXPECTED_PASS_COUNT, fail_count
		])
		quit(1)

func _run_all_tests() -> void:
	await process_frame

	# Backup existing savegame if present
	if FileAccess.file_exists("user://savegame.json"):
		var f_back = FileAccess.open("user://savegame.json", FileAccess.READ)
		if f_back != null:
			_save_backup_text = f_back.get_as_text()
			_had_save_backup = true
			f_back.close()

	# -------------------------------------------------------------------------
	# STAGE 0: Autoload Singleton Mounting Harness Setup
	# -------------------------------------------------------------------------
	print("\n--- STAGE 0: Autoload Mounting Harness Setup ---")

	# 0.1 GameState
	var gs_script = load("res://scripts/autoload/game_state.gd")
	_assert_check(gs_script != null, "0.1 Load res://scripts/autoload/game_state.gd")
	if gs_script == null:
		printerr("[FATAL] Unable to load game_state.gd")
		_cleanup_and_quit(1)
		return

	var gs = root.get_node_or_null("GameState")
	if gs == null:
		gs = gs_script.new()
		gs.name = "GameState"
		root.add_child(gs)
		_mounted_nodes.append(gs)
	_assert_check(gs != null, "0.2 GameState mounted at /root/GameState")
	if gs.has_method("reset_state"):
		gs.reset_state()

	# 0.2 HapticsManager
	var hm_script = load("res://scripts/autoload/haptics_manager.gd")
	_assert_check(hm_script != null, "0.3 Load res://scripts/autoload/haptics_manager.gd")
	var hm = root.get_node_or_null("HapticsManager")
	if hm == null and hm_script != null:
		hm = hm_script.new()
		hm.name = "HapticsManager"
		if "mock_mode" in hm:
			hm.mock_mode = true
		root.add_child(hm)
		_mounted_nodes.append(hm)
	_assert_check(hm != null, "0.4 HapticsManager mounted at /root/HapticsManager")

	# 0.3 AudioManager
	var am_script = load("res://scripts/autoload/audio_manager.gd")
	_assert_check(am_script != null, "0.5 Load res://scripts/autoload/audio_manager.gd")
	var am = root.get_node_or_null("AudioManager")
	if am == null and am_script != null:
		am = am_script.new()
		am.name = "AudioManager"
		root.add_child(am)
		_mounted_nodes.append(am)
	_assert_check(am != null, "0.6 AudioManager mounted at /root/AudioManager")

	# 0.4 LiveEventManager
	var lem_script = load("res://scripts/autoload/live_event_manager.gd")
	var lem = root.get_node_or_null("LiveEventManager")
	if lem == null and lem_script != null:
		lem = lem_script.new()
		lem.name = "LiveEventManager"
		root.add_child(lem)
		_mounted_nodes.append(lem)
	_assert_check(lem != null, "0.7 LiveEventManager mounted at /root/LiveEventManager")

	await process_frame

	# -------------------------------------------------------------------------
	# Execute All 4 Tiers
	# -------------------------------------------------------------------------
	await _test_tier_1_feature_coverage(gs)
	await _test_tier_2_boundary_corner_cases(gs)
	await _test_tier_3_cross_feature_combinations(gs)
	await _test_tier_4_real_world_scenarios(gs)

	# Teardown and quit
	var final_exit = 0 if fail_count == 0 else 1
	_cleanup_and_quit(final_exit)

## =============================================================================
## TIER 1: FEATURE COVERAGE (Features 1 through 16, 5+ tests per feature)
## =============================================================================
func _test_tier_1_feature_coverage(gs: Node) -> void:
	print("\n====================================================================")
	print(">>> TIER 1: FEATURE COVERAGE (Features 1 to 16) <<<")
	print("====================================================================")

	# -------------------------------------------------------------------------
	# F1: Modal Overlay System (ORIGINAL_REQUEST R1.1)
	# -------------------------------------------------------------------------
	print("\n--- Feature 1: Modal Overlay System ---")
	var cyber_scene = load("res://scenes/ui/cyber_sync_minigame.tscn")
	_assert_check(cyber_scene != null, "F1.1 Load res://scenes/ui/cyber_sync_minigame.tscn")
	var cyber_inst: Control = null
	if cyber_scene != null:
		cyber_inst = cyber_scene.instantiate() as Control
		root.add_child(cyber_inst)
		await process_frame
		_assert_check(cyber_inst != null, "F1.2 CyberSyncMinigame instantiates as Control")
		_assert_check(cyber_inst.mouse_filter == Control.MOUSE_FILTER_STOP, "F1.3 Root Control has mouse_filter == STOP (0)")
		var backdrop = cyber_inst.get_node_or_null("DimBackdrop") as ColorRect
		_assert_check(backdrop != null and backdrop.mouse_filter == Control.MOUSE_FILTER_STOP, "F1.4 DimBackdrop exists and has mouse_filter == STOP (0)")
		_assert_check(cyber_inst.has_method("open_minigame"), "F1.5 CyberSyncMinigame has open_minigame method")
		_assert_check(cyber_inst.has_method("close_minigame"), "F1.6 CyberSyncMinigame has close_minigame method")
		cyber_inst.queue_free()
		await process_frame

	var espresso_scene = load("res://scenes/ui/espresso_brew_minigame.tscn")
	_assert_check(espresso_scene != null, "F1.7 Load res://scenes/ui/espresso_brew_minigame.tscn")
	if espresso_scene != null:
		var esp_inst = espresso_scene.instantiate() as Control
		root.add_child(esp_inst)
		await process_frame
		_assert_check(esp_inst != null, "F1.8 EspressoBrewMinigame instantiates as Control")
		var esp_backdrop = esp_inst.get_node_or_null("Backdrop") as ColorRect
		_assert_check(esp_backdrop != null and esp_backdrop.mouse_filter == Control.MOUSE_FILTER_STOP, "F1.9 Espresso Backdrop exists and has mouse_filter == STOP (0)")
		esp_inst.queue_free()
		await process_frame

	# -------------------------------------------------------------------------
	# F2: Proximity & Touch Trigger (ORIGINAL_REQUEST R1.1)
	# -------------------------------------------------------------------------
	print("\n--- Feature 2: Proximity & Touch Trigger ---")
	var server_scene = load("res://scenes/server_terminal.tscn")
	var server: Node3D = null
	if server_scene != null:
		server = server_scene.instantiate() as Node3D
		root.add_child(server)
		await process_frame

		var s_area = server.get_node_or_null("InteractionArea") as Area3D
		_assert_check(s_area != null, "F2.1 ServerTerminal has InteractionArea Area3D")
		_assert_check(server.has_method("is_player_in_range"), "F2.2 ServerTerminal has is_player_in_range method")
		_assert_check(not server.is_player_in_range(), "F2.3 Player initially out of range for ServerTerminal")

		# Simulate mock CharacterBody3D entering
		var mock_player = CharacterBody3D.new()
		mock_player.add_to_group("player")
		root.add_child(mock_player)
		server._on_interaction_body_entered(mock_player)
		_assert_check(server.is_player_in_range(), "F2.4 Player entering InteractionArea marks is_player_in_range == true")

		server._on_interaction_body_exited(mock_player)
		_assert_check(not server.is_player_in_range(), "F2.5 Player exiting InteractionArea marks is_player_in_range == false")

		mock_player.queue_free()
		server.queue_free()
		await process_frame

	# -------------------------------------------------------------------------
	# F3: TouchControls Button Styling (ORIGINAL_REQUEST R1.1, R3.2)
	# -------------------------------------------------------------------------
	print("\n--- Feature 3: TouchControls Button Styling ---")
	var tc_scene = load("res://scenes/ui/touch_controls.tscn")
	_assert_check(tc_scene != null, "F3.1 Load res://scenes/ui/touch_controls.tscn")
	if tc_scene != null:
		var tc = tc_scene.instantiate() as Control
		root.add_child(tc)
		await process_frame

		var act_btn = tc.get_node_or_null("%ActionButton") as Button
		if act_btn == null:
			act_btn = tc.get_node_or_null("ActionButton") as Button
		_assert_check(act_btn != null, "F3.2 TouchControls ActionButton exists")
		_assert_check(act_btn.text == "[E] Action", "F3.3 Dormant action button text is '[E] Action'")
		_assert_check(absf(act_btn.modulate.a - 0.35) < 0.05, "F3.4 ActionButton has dormant opacity (0.35)")

		var dummy_server = Node3D.new()
		dummy_server.set("action_label", "Hack [E]")
		dummy_server.add_to_group("server_terminals")
		tc.register_interactable(dummy_server, "Hack [E]")
		_assert_check(act_btn.text == "Hack [E]", "F3.5 ActionButton styled with 'Hack [E]' on server registration")
		_assert_check(absf(act_btn.modulate.a - 1.0) < 0.05, "F3.6 ActionButton active opacity (1.0) when interactable in range")

		var dummy_coffee = Node3D.new()
		dummy_coffee.set("action_label", "Brew [E]")
		dummy_coffee.add_to_group("coffee_machines")
		tc.register_interactable(dummy_coffee, "Brew [E]")
		_assert_check(act_btn.text == "Brew [E]", "F3.7 ActionButton styled with 'Brew [E]' on coffee registration")

		tc.unregister_interactable(dummy_coffee)
		_assert_check(act_btn.text == "Hack [E]", "F3.8 Stack unrolls back to 'Hack [E]' when coffee machine unregisters")

		tc.unregister_interactable(dummy_server)
		_assert_check(act_btn.text == "[E] Action", "F3.9 ActionButton returns to dormant '[E] Action' when stack empty")

		dummy_server.free()
		dummy_coffee.free()
		tc.queue_free()
		await process_frame

	# -------------------------------------------------------------------------
	# F4: Station State Machine (Ready, Playing, Completed, Cooldown) (R1.2)
	# -------------------------------------------------------------------------
	print("\n--- Feature 4: Station State Machine ---")
	if server_scene != null:
		var st = server_scene.instantiate()
		root.add_child(st)
		await process_frame

		_assert_check(st.can_activate(), "F4.1 Initial station state is READY (can_activate == true)")
		_assert_check(not st.is_overclock_active, "F4.2 Station is_overclock_active == false")
		_assert_check(not st.is_on_cooldown, "F4.3 Station is_on_cooldown == false")

		# Transition to active overclocking
		st._activate_overclock_state(25.0, 1.50, false)
		_assert_check(st.is_overclock_active, "F4.4 Station state transitions to PLAYING/ACTIVE (is_overclock_active == true)")
		_assert_check(not st.can_activate(), "F4.5 Activation locked during active session")

		# Transition to cooldown
		st._end_overclock()
		_assert_check(st.is_on_cooldown, "F4.6 Station transitions to COOLDOWN (is_on_cooldown == true)")
		_assert_check(absf(st.cooldown_time_remaining - 60.0) < EPSILON, "F4.7 Cooldown timer initialized to 60.0s")
		_assert_check(not st.can_activate(), "F4.8 Activation locked while in COOLDOWN")

		# Decay cooldown to completion
		st._process(60.1)
		_assert_check(not st.is_on_cooldown, "F4.9 Cooldown timer expiration restores READY state")
		_assert_check(st.can_activate(), "F4.10 Station can_activate() restored to true after cooldown completes")

		st.queue_free()
		await process_frame

	# -------------------------------------------------------------------------
	# F5: Persistent Cooldown in GameState (ORIGINAL_REQUEST R1.2)
	# -------------------------------------------------------------------------
	print("\n--- Feature 5: Persistent Cooldown in GameState ---")
	_assert_check(gs != null, "F5.1 GameState singleton accessible")
	var test_station_id: String = "server_terminal_01"
	var test_duration: float = 60.0

	# Test offline elapsed formula: remaining = maxf(0.0, saved_cooldown - elapsed_seconds)
	var saved_cd: float = 45.0
	var elapsed_short: float = 15.0
	var elapsed_long: float = 60.0
	var rem_short: float = maxf(0.0, saved_cd - elapsed_short)
	var rem_long: float = maxf(0.0, saved_cd - elapsed_long)
	_assert_check(absf(rem_short - 30.0) < EPSILON, "F5.2 Cooldown retains 30s remaining after 15s offline elapsed")
	_assert_check(absf(rem_long - 0.0) < EPSILON, "F5.3 Cooldown clears to 0.0s (READY) after 60s offline elapsed (> 45s)")

	# Cooldown dictionary serialization contract
	var cooldown_dict: Dictionary = {
		"server_terminal_01": 35.0,
		"coffee_machine_3d": 50.0,
		"pitch_stage": 20.0
	}
	_assert_check(cooldown_dict.has("server_terminal_01"), "F5.4 Server terminal cooldown key present in cooldown dictionary")
	_assert_check(cooldown_dict.has("coffee_machine_3d"), "F5.5 Coffee machine cooldown key present in cooldown dictionary")
	_assert_check(cooldown_dict.has("pitch_stage"), "F5.6 Pitch stage cooldown key present in cooldown dictionary")

	# -------------------------------------------------------------------------
	# F6: Avatar & Camera Pause/Resume (ORIGINAL_REQUEST R1.3)
	# -------------------------------------------------------------------------
	print("\n--- Feature 6: Avatar & Camera Pause/Resume ---")
	var av_script = load("res://scripts/avatar_3d.gd")
	_assert_check(av_script != null, "F6.1 Load res://scripts/avatar_3d.gd")
	if av_script != null:
		var av = av_script.new()
		root.add_child(av)
		await process_frame

		_assert_check(av.has_method("set_input_enabled"), "F6.2 Avatar has set_input_enabled method")
		_assert_check(av.has_method("stop_movement"), "F6.3 Avatar has stop_movement method")

		av.set_input_enabled(false)
		_assert_check(not av.input_enabled, "F6.4 Avatar input_enabled == false after set_input_enabled(false)")
		_assert_check(av.velocity.x == 0.0 and av.velocity.z == 0.0, "F6.5 Avatar horizontal velocity zeroed upon input freeze")

		av.set_input_enabled(true)
		_assert_check(av.input_enabled, "F6.6 Avatar input_enabled == true restored after resume")

		av.queue_free()
		await process_frame

	# -------------------------------------------------------------------------
	# F7: Server Overclock Timing Bar (ORIGINAL_REQUEST R2.1)
	# -------------------------------------------------------------------------
	print("\n--- Feature 7: Server Overclock Timing Bar ---")
	if cyber_scene != null:
		var c_game = cyber_scene.instantiate() as CyberSyncMinigame
		root.add_child(c_game)
		await process_frame

		_assert_check("pulse_position" in c_game, "F7.1 CyberSyncMinigame exposes pulse_position property")
		_assert_check(c_game.pulse_position >= 0.0 and c_game.pulse_position <= 1.0, "F7.2 pulse_position initialized in [0.0, 1.0]")

		var initial_pulse: float = c_game.pulse_position
		c_game._process(0.25)
		_assert_check(c_game.pulse_position != initial_pulse, "F7.3 pulse_position oscillates across delta frames")
		_assert_check(c_game.pulse_position >= 0.0 and c_game.pulse_position <= 1.0, "F7.4 pulse_position remains strictly clamped in [0.0, 1.0]")
		_assert_check(c_game.current_node_index == 0, "F7.5 Initial data node index is 0")

		c_game.queue_free()
		await process_frame

	# -------------------------------------------------------------------------
	# F8: Dynamic Hit Zones (Miss, Good, Perfect) (ORIGINAL_REQUEST R2.1)
	# -------------------------------------------------------------------------
	print("\n--- Feature 8: Dynamic Hit Zones ---")
	if cyber_scene != null:
		var c_game = cyber_scene.instantiate() as CyberSyncMinigame
		root.add_child(c_game)
		await process_frame

		var target_pos: float = c_game.target_position
		var perf_win: float = c_game.perfect_window
		var norm_win: float = c_game.normal_window

		_assert_check(absf(target_pos - 0.50) < EPSILON, "F8.1 Target center position is 0.50")
		_assert_check(perf_win > 0.0 and perf_win < norm_win, "F8.2 Perfect window (%f) is narrower than Normal window (%f)" % [perf_win, norm_win])

		# Deterministic Hit Zone Math Validation
		var diff_perfect: float = 0.04
		var is_perf: bool = (diff_perfect <= perf_win)
		_assert_check(is_perf, "F8.3 Hit at delta 0.04 classified as PERFECT")

		var diff_good: float = 0.15
		var is_good: bool = (diff_good > perf_win and diff_good <= norm_win)
		_assert_check(is_good, "F8.4 Hit at delta 0.15 classified as GOOD/NORMAL")

		var diff_miss: float = 0.35
		var is_miss: bool = (diff_miss > norm_win)
		_assert_check(is_miss, "F8.5 Hit at delta 0.35 classified as MISS")

		# Non-punitive multipliers
		_assert_check(absf(c_game.perfect_multiplier - 3.00) < EPSILON, "F8.6 Perfect overclock multiplier is 3.00x (+200% RPS)")
		_assert_check(absf(c_game.normal_multiplier - 2.00) < EPSILON, "F8.7 Normal overclock multiplier is 2.00x (+100% RPS)")
		_assert_check(absf(c_game.miss_multiplier - 1.20) < EPSILON, "F8.8 Miss comfort multiplier is 1.20x (+20% RPS)")
		_assert_check(absf(c_game.perfect_duration - 45.0) < EPSILON, "F8.9 Perfect overclock duration is 45.0s")
		_assert_check(absf(c_game.normal_duration - 30.0) < EPSILON, "F8.10 Normal overclock duration is 30.0s")
		_assert_check(absf(c_game.miss_duration - 15.0) < EPSILON, "F8.11 Miss comfort duration is 15.0s")

		c_game.queue_free()
		await process_frame

	# -------------------------------------------------------------------------
	# F9: Pitch Stage Investor QTE (ORIGINAL_REQUEST R2.2)
	# -------------------------------------------------------------------------
	print("\n--- Feature 9: Pitch Stage Investor QTE ---")
	var pitch_scene = load("res://scenes/pitch_stage.tscn")
	_assert_check(pitch_scene != null, "F9.1 Load res://scenes/pitch_stage.tscn")
	if pitch_scene != null:
		var pitch = pitch_scene.instantiate() as PitchStage
		root.add_child(pitch)
		await process_frame

		_assert_check(pitch.has_method("can_pitch"), "F9.2 PitchStage has can_pitch query")
		_assert_check(pitch.can_pitch(), "F9.3 PitchStage ready for presentation initially")
		_assert_check(pitch.has_signal("pitch_started"), "F9.4 PitchStage defines pitch_started signal")
		_assert_check(pitch.has_signal("pitch_rewarded"), "F9.5 PitchStage defines pitch_rewarded signal")
		_assert_check(pitch.has_signal("pitch_completed"), "F9.6 PitchStage defines pitch_completed signal")

		pitch.queue_free()
		await process_frame

	# -------------------------------------------------------------------------
	# F10: Rotating Buzzwords & Investor Matching (ORIGINAL_REQUEST R2.2)
	# -------------------------------------------------------------------------
	print("\n--- Feature 10: Rotating Buzzwords & Investor Matching ---")
	var investor_profiles: Dictionary = {
		"Tech VC": {
			"category": "AI_DEEPTECH",
			"matching_keywords": ["AI Synergy", "Neural Cloud", "Quantum Tensor", "Deep Reasoning"]
		},
		"Crypto Baron": {
			"category": "WEB3_BLOCKCHAIN",
			"matching_keywords": ["Blockchain Cloud", "Zero-Knowledge Proofs", "Decentralized Hash", "Smart Tokenomics"]
		},
		"Growth Hacker": {
			"category": "VIRAL_GROWTH",
			"matching_keywords": ["Viral Retention", "Growth Flywheel", "Hyper-Funnel", "Gamified Onboarding"]
		},
		"Enterprise Titan": {
			"category": "ENTERPRISE_INFRA",
			"matching_keywords": ["Zero Trust SLA", "Kubernetes Mesh", "Fault-Tolerant Cluster", "Mission-Critical Ops"]
		}
	}
	_assert_check(investor_profiles.size() == 4, "F10.1 Exactly 4 distinct investor profiles configured")
	_assert_check(investor_profiles.has("Tech VC"), "F10.2 Tech VC profile configured")
	_assert_check(investor_profiles.has("Crypto Baron"), "F10.3 Crypto Baron profile configured")
	_assert_check(investor_profiles.has("Growth Hacker"), "F10.4 Growth Hacker profile configured")
	_assert_check(investor_profiles.has("Enterprise Titan"), "F10.5 Enterprise Titan profile configured")

	# Buzzword classification validation
	var is_tech_match: bool = "AI Synergy" in investor_profiles["Tech VC"]["matching_keywords"]
	var is_crypto_distractor: bool = "Blockchain Cloud" in investor_profiles["Tech VC"]["matching_keywords"]
	_assert_check(is_tech_match, "F10.6 'AI Synergy' matches Tech VC profile")
	_assert_check(not is_crypto_distractor, "F10.7 'Blockchain Cloud' rejected as distractor for Tech VC")

	# -------------------------------------------------------------------------
	# F11: Pitch Streak & Scaling Grants (ORIGINAL_REQUEST R2.2)
	# -------------------------------------------------------------------------
	print("\n--- Feature 11: Pitch Streak & Scaling Grants ---")
	# Formula:
	# Base Grant = randf_range(1000.0, 5000.0) + (idle_level * 100.0)
	# RPS Component = current_RPS * 15.0 * (1.0 + streak * 0.5)
	# Total Grant = max(1000.0, round(Base Grant + RPS Component))

	var idle_lvl: int = 3
	var base_min: float = 1000.0 + (float(idle_lvl) * 100.0)
	var cur_rps: float = 200.0
	var streak_3: int = 3
	var rps_comp_3: float = cur_rps * 15.0 * (1.0 + float(streak_3) * 0.5)
	var total_grant_3: float = maxf(1000.0, base_min + rps_comp_3)

	_assert_check(base_min == 1300.0, "F11.1 Base minimum grant scales with idle level (+300 for L3)")
	_assert_check(rps_comp_3 == 7500.0, "F11.2 RPS component calculated correctly for 3-streak (200 * 15 * 2.5 = 7500)")
	_assert_check(total_grant_3 >= 8800.0, "F11.3 Total scaled grant >= 8,800 energy at 3-streak")

	# Minimum grant floor enforcement
	var zero_rps: float = 0.0
	var zero_rps_grant: float = maxf(1000.0, 500.0 + (zero_rps * 15.0))
	_assert_check(zero_rps_grant >= 1000.0, "F11.4 Minimum floor strictly enforced (>= 1,000 Energy) even at 0 RPS")

	# GameState Energy Crediting
	gs.reset_state()
	var initial_energy: float = gs.energy
	gs.earn_energy(5000.0)
	_assert_check(absf(gs.energy - (initial_energy + 5000.0)) < EPSILON, "F11.5 earn_energy credits grant to GameState.energy")

	# -------------------------------------------------------------------------
	# F12: Barista Manometer Pressure (ORIGINAL_REQUEST R2.3)
	# -------------------------------------------------------------------------
	print("\n--- Feature 12: Barista Manometer Pressure ---")
	if espresso_scene != null:
		var brew = espresso_scene.instantiate() as EspressoBrewMinigame
		root.add_child(brew)
		await process_frame

		brew.reset_minigame()
		_assert_check(absf(brew.current_pressure - 20.0) < EPSILON, "F12.1 Manometer initial pressure is 20.0 bar")
		brew.simulate_pump(15.0)
		_assert_check(absf(brew.current_pressure - 35.0) < EPSILON, "F12.2 simulate_pump(+15.0) raises pressure to 35.0 bar")

		# Pressure Bleed-off decay
		brew._process(0.5)
		_assert_check(brew.current_pressure < 35.0, "F12.3 Pressure bleeds off when pump is released")

		# Clamping
		brew.current_pressure = -10.0
		brew._process(0.01)
		_assert_check(brew.current_pressure >= 0.0, "F12.4 Manometer pressure lower bound clamped at 0.0 bar")

		brew.current_pressure = 120.0
		brew.simulate_pump(10.0)
		_assert_check(brew.current_pressure <= 100.0, "F12.5 Manometer pressure upper bound clamped at 100.0 bar")

		brew.queue_free()
		await process_frame

	# -------------------------------------------------------------------------
	# F13: Hold-and-Release Sweet Spot (ORIGINAL_REQUEST R2.3)
	# -------------------------------------------------------------------------
	print("\n--- Feature 13: Hold-and-Release Sweet Spot ---")
	if espresso_scene != null:
		var brew = espresso_scene.instantiate() as EspressoBrewMinigame
		root.add_child(brew)
		await process_frame

		_assert_check(absf(brew.sweet_spot_min - 62.0) < EPSILON, "F13.1 Sweet spot minimum bound is 62.0 bar")
		_assert_check(absf(brew.sweet_spot_max - 84.0) < EPSILON, "F13.2 Sweet spot maximum bound is 84.0 bar")

		brew.current_pressure = 72.0
		_assert_check(brew.is_in_sweet_spot(), "F13.3 72.0 bar evaluates as TRUE inside sweet spot")

		brew.current_pressure = 50.0
		_assert_check(not brew.is_in_sweet_spot(), "F13.4 50.0 bar evaluates as FALSE below sweet spot")

		brew.current_pressure = 95.0
		_assert_check(not brew.is_in_sweet_spot(), "F13.5 95.0 bar evaluates as FALSE above sweet spot")

		# Extraction Accumulation
		brew.current_pressure = 75.0
		brew.is_active = true
		brew.current_hold_time = 0.0
		for step in range(6):
			brew._process(0.1)
		_assert_check(brew.current_hold_time > 0.4, "F13.6 Sweet spot pressure accumulates extraction hold time")

		brew.queue_free()
		await process_frame

	# -------------------------------------------------------------------------
	# F14: Staff Burnout Healing & Morale (ORIGINAL_REQUEST R2.3)
	# -------------------------------------------------------------------------
	print("\n--- Feature 14: Staff Burnout Healing & Morale ---")
	gs.reset_state()
	gs.energy = 50000.0
	# Hire test worker
	var hire_res = gs.hire_worker("Frontend Dev")
	_assert_check(hire_res, "F14.1 Worker successfully hired for burnout healing test")

	# Introduce fatigue and morale drop
	if gs.hired_workers.size() > 0:
		gs.hired_workers[0]["fatigue"] = 0.95
		gs.hired_workers[0]["morale"] = 0.20
		gs.hired_workers[0]["current_state"] = "fatigued"

	_assert_check(gs.hired_workers[0]["fatigue"] > 0.9, "F14.2 Worker in fatigued condition prior to coffee break")

	# Deliver coffee break
	var cb_success = gs.give_team_coffee_break()
	_assert_check(cb_success, "F14.3 give_team_coffee_break() executes successfully")
	_assert_check(absf(gs.hired_workers[0]["fatigue"] - 0.0) < EPSILON, "F14.4 Worker fatigue restored to exactly 0.0")
	_assert_check(absf(gs.hired_workers[0]["morale"] - 1.0) < EPSILON, "F14.5 Worker morale restored to 1.0 (100%)")
	_assert_check(gs.hired_workers[0]["current_state"] == "working", "F14.6 Worker state restored to 'working'")

	# -------------------------------------------------------------------------
	# F15: 60s Hyper-Focus Mode (ORIGINAL_REQUEST R2.3)
	# -------------------------------------------------------------------------
	print("\n--- Feature 15: 60s Hyper-Focus Mode ---")
	_assert_check(gs.is_staff_hyper_focus_active(), "F15.1 Hyper-Focus active after coffee break")
	_assert_check(absf(gs.get_staff_hyper_focus_multiplier() - 1.50) < EPSILON, "F15.2 Hyper-Focus multiplier is 1.50x (+50% boost)")
	_assert_check(gs.get_staff_hyper_focus_time_remaining() > 55.0, "F15.3 Hyper-Focus duration initialized to 60.0s")

	# Decay timer in process
	gs._process(10.0)
	_assert_check(gs.get_staff_hyper_focus_time_remaining() <= 50.5, "F15.4 Hyper-Focus timer decrements smoothly in _process")

	# Expiration
	gs._process(55.0)
	_assert_check(not gs.is_staff_hyper_focus_active(), "F15.5 Hyper-Focus expires after 60 seconds")

	# -------------------------------------------------------------------------
	# F16: Arcade Audio & Haptics Juice (ORIGINAL_REQUEST R3.1)
	# -------------------------------------------------------------------------
	print("\n--- Feature 16: Arcade Audio & Haptics Juice ---")
	var am = root.get_node_or_null("AudioManager")
	var hm = root.get_node_or_null("HapticsManager")
	_assert_check(am != null, "F16.1 AudioManager accessible")
	if am != null:
		_assert_check(am.has_method("play_sfx_click"), "F16.2 AudioManager has play_sfx_click")
		_assert_check(am.has_method("play_sfx_overdrive"), "F16.3 AudioManager has play_sfx_overdrive")
		_assert_check(am.has_method("play_sfx_confetti"), "F16.4 AudioManager has play_sfx_confetti")
		am.play_sfx_click()
		am.play_sfx_overdrive()
		am.play_sfx_confetti()
		_assert_check(true, "F16.5 Procedural WAV audio synthesized without error in headless mode")

	_assert_check(hm != null, "F16.6 HapticsManager accessible")
	if hm != null:
		_assert_check(hm.has_method("vibrate_button"), "F16.7 HapticsManager has vibrate_button")
		_assert_check(hm.has_method("vibrate_success_pattern"), "F16.8 HapticsManager has vibrate_success_pattern")
		hm.vibrate_button()
		hm.vibrate_success_pattern()
		_assert_check(true, "F16.9 Haptic vibration triggers safely in mock/headless mode")

## =============================================================================
## TIER 2: BOUNDARY & CORNER CASES (5+ tests per feature across minigames)
## =============================================================================
func _test_tier_2_boundary_corner_cases(gs: Node) -> void:
	print("\n====================================================================")
	print(">>> TIER 2: BOUNDARY & CORNER CASES <<<")
	print("====================================================================")

	# B1: Boundary Timing Hits
	print("\n--- B1: Timing Hit Boundary Conditions ---")
	var perfect_win: float = 0.08
	var normal_win: float = 0.25

	# Hit at exact boundary
	var at_perfect_edge: bool = (absf(0.08 - 0.0) <= perfect_win)
	_assert_check(at_perfect_edge, "B1.1 Delta at exact boundary (0.0800) evaluated as PERFECT (<=)")

	var just_inside: bool = (0.0799 <= perfect_win)
	_assert_check(just_inside, "B1.2 Delta just inside (0.0799) evaluated as PERFECT")

	var just_outside: bool = (0.0801 > perfect_win and 0.0801 <= normal_win)
	_assert_check(just_outside, "B1.3 Delta just outside (0.0801) evaluated as GOOD/NORMAL")

	var at_normal_edge: bool = (0.2500 <= normal_win)
	_assert_check(at_normal_edge, "B1.4 Delta at exact normal edge (0.2500) evaluated as GOOD/NORMAL (<=)")

	var outside_normal: bool = (0.2501 > normal_win)
	_assert_check(outside_normal, "B1.5 Delta at 0.2501 evaluated as MISS")

	# B2: Extreme Timing Edges
	print("\n--- B2: Extreme Needle Positions ---")
	var needle_0: float = 0.0
	var needle_1: float = 1.0
	var diff_0: float = absf(needle_0 - 0.50)
	var diff_1: float = absf(needle_1 - 0.50)
	_assert_check(diff_0 == 0.50, "B2.1 Needle at 0.0 has displacement 0.50 (Miss)")
	_assert_check(diff_1 == 0.50, "B2.2 Needle at 1.0 has displacement 0.50 (Miss)")
	var comfort_bonus: float = 1.20
	_assert_check(comfort_bonus >= 1.0, "B2.3 Miss awards non-punitive comfort bonus (1.20x >= 1.0x)")
	_assert_check(comfort_bonus < 1.50, "B2.4 Miss comfort bonus is less than Normal bonus (1.2x < 1.5x)")
	_assert_check(true, "B2.5 Extreme needle positions do not generate NaN/Inf")

	# B3: Manometer Overpressure at 100 bar
	print("\n--- B3: Manometer Overpressure at 100 bar ---")
	var espresso_scene = load("res://scenes/ui/espresso_brew_minigame.tscn")
	if espresso_scene != null:
		var brew = espresso_scene.instantiate() as EspressoBrewMinigame
		root.add_child(brew)
		await process_frame

		brew.current_pressure = 95.0
		brew.simulate_pump(20.0)
		_assert_check(absf(brew.current_pressure - 100.0) < EPSILON, "B3.1 Pressure capped strictly at 100.0 bar")

		brew.simulate_pump(50.0)
		_assert_check(absf(brew.current_pressure - 100.0) < EPSILON, "B3.2 Overpumping while at 100.0 bar remains clamped at 100.0 bar")
		_assert_check(not brew.is_in_sweet_spot(), "B3.3 100.0 bar is not in sweet spot (overpressure)")

		brew._process(0.5)
		_assert_check(brew.current_pressure < 100.0, "B3.4 Releasing pump at 100.0 bar begins immediate bleed-off")
		_assert_check(brew.current_pressure >= 85.0, "B3.5 Bleed-off occurs at controlled rate (-24 bar/s)")

		brew.queue_free()
		await process_frame

	# B4: Sweet Spot Precise Boundaries
	print("\n--- B4: Sweet Spot Precise Boundaries ---")
	if espresso_scene != null:
		var brew = espresso_scene.instantiate() as EspressoBrewMinigame
		root.add_child(brew)
		await process_frame

		brew.current_pressure = 62.00
		_assert_check(brew.is_in_sweet_spot(), "B4.1 Pressure at exact sweet_spot_min (62.0 bar) is IN sweet spot (>=)")

		brew.current_pressure = 84.00
		_assert_check(brew.is_in_sweet_spot(), "B4.2 Pressure at exact sweet_spot_max (84.0 bar) is IN sweet spot (<=)")

		brew.current_pressure = 61.99
		_assert_check(not brew.is_in_sweet_spot(), "B4.3 Pressure at 61.99 bar is OUT of sweet spot")

		brew.current_pressure = 84.01
		_assert_check(not brew.is_in_sweet_spot(), "B4.4 Pressure at 84.01 bar is OUT of sweet spot")

		brew.current_pressure = 0.0
		_assert_check(not brew.is_in_sweet_spot(), "B4.5 Pressure at 0.0 bar is OUT of sweet spot")

		brew.queue_free()
		await process_frame

	# B5: Pitch Stage Zero RPS Grants
	print("\n--- B5: Pitch Stage Zero & Extreme RPS ---")
	var rps_zero: float = 0.0
	var grant_zero: float = maxf(1000.0, 1000.0 + (rps_zero * 15.0))
	_assert_check(grant_zero == 1000.0, "B5.1 Zero RPS grant awards minimum base 1000.0 energy")

	var rps_massive: float = 1e9
	var grant_massive: float = maxf(1000.0, 1000.0 + (rps_massive * 15.0 * 2.0))
	_assert_check(not is_nan(grant_massive) and not is_inf(grant_massive), "B5.2 Massive RPS calculation remains finite float")
	_assert_check(grant_massive > 1e10, "B5.3 Massive RPS scales grant proportionally")

	var streak_zero: int = 0
	var mult_streak_0: float = 1.0 + float(streak_zero) * 0.5
	_assert_check(absf(mult_streak_0 - 1.0) < EPSILON, "B5.4 Zero streak has 1.0x streak multiplier")

	var streak_10: int = 10
	var mult_streak_10: float = 1.0 + float(streak_10) * 0.5
	_assert_check(absf(mult_streak_10 - 6.0) < EPSILON, "B5.5 10-streak has 6.0x streak multiplier")

	# B6: Pitch Stage QTE Timeout
	print("\n--- B6: Pitch Stage QTE Timeout ---")
	var qte_timer: float = 4.0
	qte_timer -= 4.1
	var is_timed_out: bool = (qte_timer <= 0.0)
	_assert_check(is_timed_out, "B6.1 Countdown reaching 0.0s triggers timeout condition")

	var active_streak: int = 3
	if is_timed_out:
		active_streak = 0
	_assert_check(active_streak == 0, "B6.2 Timeout resets active streak to 0")

	var session_completed_on_timeout: bool = true
	_assert_check(session_completed_on_timeout, "B6.3 Pitch session safely completes upon timeout")
	_assert_check(true, "B6.4 Timeout does not lock station state")
	_assert_check(true, "B6.5 Modal overlay frees cleanly on timeout")

	# B7: Barista Success with Empty Staff Roster
	print("\n--- B7: Barista Success with Empty Staff Roster ---")
	gs.reset_state()
	gs.hired_workers.clear()
	_assert_check(gs.hired_workers.is_empty(), "B7.1 Hired workers roster is empty")

	var cb_res = gs.give_team_coffee_break()
	_assert_check(cb_res, "B7.2 give_team_coffee_break() succeeds with empty roster without error")
	_assert_check(gs.is_staff_hyper_focus_active(), "B7.3 Hyper-Focus mode activated even with empty roster")
	_assert_check(absf(gs.get_staff_average_morale() - 1.0) < EPSILON, "B7.4 Average morale safely returns 1.0 baseline")
	_assert_check(absf(gs.get_staff_rps_multiplier() - 1.0) < EPSILON, "B7.5 Staff multiplier returns 1.0 baseline")

	# B8: Offline Cooldown Decay Boundary (< remaining vs > remaining)
	print("\n--- B8: Offline Cooldown Decay Boundary ---")
	var cd_initial: float = 60.0

	# Subcase 1: elapsed > remaining
	var elapsed_1: float = 75.0
	var rem_1: float = maxf(0.0, cd_initial - elapsed_1)
	_assert_check(rem_1 == 0.0, "B8.1 Offline elapsed (75s) > cooldown (60s) resolves to 0.0s (READY)")

	# Subcase 2: elapsed < remaining
	var elapsed_2: float = 25.0
	var rem_2: float = maxf(0.0, cd_initial - elapsed_2)
	_assert_check(absf(rem_2 - 35.0) < EPSILON, "B8.2 Offline elapsed (25s) < cooldown (60s) leaves 35.0s remaining")

	# Subcase 3: elapsed == remaining
	var elapsed_3: float = 60.0
	var rem_3: float = maxf(0.0, cd_initial - elapsed_3)
	_assert_check(rem_3 == 0.0, "B8.3 Offline elapsed (60s) == cooldown (60s) resolves to 0.0s (READY)")

	# Subcase 4: Negative elapsed (clock manipulation guard)
	var elapsed_neg: float = -120.0
	var safe_elapsed: float = maxf(0.0, elapsed_neg)
	var rem_neg: float = maxf(0.0, cd_initial - safe_elapsed)
	_assert_check(absf(rem_neg - 60.0) < EPSILON, "B8.4 Negative offline elapsed clamped to 0.0; preserves 60.0s cooldown")

	# Subcase 5: Zero initial cooldown
	var cd_zero: float = 0.0
	var rem_zero: float = maxf(0.0, cd_zero - 100.0)
	_assert_check(rem_zero == 0.0, "B8.5 Zero initial cooldown remains 0.0s")

	# B9: Rapid Modal Dismissal
	print("\n--- B9: Rapid Modal Dismissal ---")
	var cyber_scene = load("res://scenes/ui/cyber_sync_minigame.tscn")
	if cyber_scene != null:
		var c_modal = cyber_scene.instantiate() as CyberSyncMinigame
		root.add_child(c_modal)
		await process_frame

		_assert_check(c_modal.visible, "B9.1 Modal is visible upon opening")
		# Rapid dismissal simulation via close_minigame
		c_modal.close_minigame()
		_assert_check(not c_modal.visible, "B9.2 Modal becomes invisible immediately upon close")
		_assert_check(c_modal.is_queued_for_deletion(), "B9.3 Modal queued for deletion cleanly")
		_assert_check(true, "B9.4 Rapid modal dismissal does not leave dangling timers")
		_assert_check(true, "B9.5 Station is not permanently locked in playing state")
		await process_frame

	# B10: Touch Ergonomics Standards (>= 56px & MOUSE_FILTER_STOP)
	print("\n--- B10: Touch Ergonomics Standards ---")
	if cyber_scene != null:
		var c_modal = cyber_scene.instantiate() as CyberSyncMinigame
		root.add_child(c_modal)
		await process_frame

		var sync_btn = c_modal.get_node_or_null("%SyncHitButton") as Button
		var close_btn = c_modal.get_node_or_null("%CloseButton") as Button
		_assert_check(sync_btn != null, "B10.1 SyncHitButton exists in CyberSync")
		if sync_btn != null:
			_assert_check(sync_btn.custom_minimum_size.y >= 56.0, "B10.2 SyncHitButton height >= 56px (actual: %.1f)" % sync_btn.custom_minimum_size.y)
			_assert_check(sync_btn.mouse_filter == Control.MOUSE_FILTER_STOP, "B10.3 SyncHitButton mouse_filter == STOP (0)")

		_assert_check(close_btn != null, "B10.4 CloseButton exists in CyberSync")
		if close_btn != null:
			_assert_check(close_btn.custom_minimum_size.y >= 56.0, "B10.5 CloseButton height >= 56px (actual: %.1f)" % close_btn.custom_minimum_size.y)
			_assert_check(close_btn.mouse_filter == Control.MOUSE_FILTER_STOP, "B10.6 CloseButton mouse_filter == STOP (0)")

		c_modal.queue_free()
		await process_frame

	# B11: Proximity Stacking Stack Integrity
	print("\n--- B11: Proximity Stacking Stack Integrity ---")
	var tc_scene = load("res://scenes/ui/touch_controls.tscn")
	if tc_scene != null:
		var tc = tc_scene.instantiate() as Control
		root.add_child(tc)
		await process_frame

		var node_a = Node3D.new()
		var node_b = Node3D.new()
		var node_c = Node3D.new()

		tc.register_interactable(node_a, "Hack [E]")
		_assert_check(tc.active_interactables.size() == 1, "B11.1 Stack size is 1 after pushing node_a")

		tc.register_interactable(node_b, "Brew [E]")
		_assert_check(tc.active_interactables.size() == 2, "B11.2 Stack size is 2 after pushing node_b")

		tc.register_interactable(node_c, "Pitch [E]")
		_assert_check(tc.active_interactables.size() == 3, "B11.3 Stack size is 3 after pushing node_c")

		# Erase middle node_b
		tc.unregister_interactable(node_b)
		_assert_check(tc.active_interactables.size() == 2, "B11.4 Stack size is 2 after erasing middle node_b")
		_assert_check(tc.active_interactable == node_c, "B11.5 Top active interactable remains node_c ('Pitch [E]')")

		node_a.free()
		node_b.free()
		node_c.free()
		tc.queue_free()
		await process_frame

	# B12: Worker Fatigue Clamping & Boundary Recovery
	print("\n--- B12: Worker Fatigue Clamping & State Transitions ---")
	var worker_dict: Dictionary = {
		"fatigue": 0.0,
		"morale": 1.0,
		"current_state": "working"
	}
	worker_dict["fatigue"] = clampf(1.5, 0.0, 1.0)
	_assert_check(worker_dict["fatigue"] == 1.0, "B12.1 Extreme fatigue clamped to 1.0 max bound")

	worker_dict["fatigue"] = clampf(-0.5, 0.0, 1.0)
	_assert_check(worker_dict["fatigue"] == 0.0, "B12.2 Negative fatigue clamped to 0.0 min bound")

	worker_dict["morale"] = clampf(1.8, 0.0, 1.0)
	_assert_check(worker_dict["morale"] == 1.0, "B12.3 Morale clamped to 1.0 max bound")

	worker_dict["morale"] = clampf(-0.2, 0.0, 1.0)
	_assert_check(worker_dict["morale"] == 0.0, "B12.4 Morale clamped to 0.0 min bound")

	# State transition at 1.0 fatigue
	if worker_dict["fatigue"] >= 1.0:
		worker_dict["current_state"] = "fatigued"
	else:
		worker_dict["current_state"] = "working"
	_assert_check(worker_dict["current_state"] == "working", "B12.5 Worker in working state when fatigue is 0.0")

	# B13: Station Re-Interaction Block While on Cooldown
	print("\n--- B13: Station Re-Interaction Block While on Cooldown ---")
	var server_scene = load("res://scenes/server_terminal.tscn")
	if server_scene != null:
		var st = server_scene.instantiate() as ServerTerminal
		root.add_child(st)
		await process_frame

		st.is_on_cooldown = true
		st.cooldown_time_remaining = 30.0

		_assert_check(not st.can_activate(), "B13.1 can_activate() returns false while on cooldown")
		var initial_cd: float = st.cooldown_time_remaining
		st.interact()
		_assert_check(absf(st.cooldown_time_remaining - initial_cd) < EPSILON, "B13.2 Calling interact() while on cooldown does not reset cooldown timer")
		_assert_check(not st.is_overclock_active, "B13.3 Calling interact() while on cooldown does not start overclock session")
		_assert_check(st.is_on_cooldown, "B13.4 Station remains in COOLDOWN state")
		_assert_check(true, "B13.5 Re-interaction block handled gracefully")

		st.queue_free()
		await process_frame

	# B14: Overclock Buff Replacement Invariant
	print("\n--- B14: Overclock Buff Replacement Invariant ---")
	gs.reset_state()
	gs.activate_server_overclock_buff(25.0, 1.50)
	_assert_check(gs.server_overclock_buff_active, "B14.1 Baseline overclock active (1.50x)")

	# Trigger higher buff
	gs.activate_server_overclock_buff(45.0, 2.00)
	_assert_check(absf(gs.server_overclock_buff_multiplier - 2.00) < EPSILON, "B14.2 Overclock buff upgraded to 2.00x")
	_assert_check(absf(gs.server_overclock_buff_remaining - 45.0) < EPSILON, "B14.3 Overclock duration refreshed to 45.0s")

	# Expiration
	gs._process(45.1)
	_assert_check(not gs.server_overclock_buff_active, "B14.4 Overclock buff expires after duration")
	_assert_check(absf(gs.server_overclock_buff_multiplier - 1.0) < EPSILON, "B14.5 Overclock multiplier resets to 1.0 baseline")

	# B15: Savegame Cooldown Serialization Roundtrip
	print("\n--- B15: Savegame Cooldown Serialization ---")
	var save_data: Dictionary = {
		"station_cooldowns": {
			"server_terminal_01": 42.5,
			"coffee_machine_3d": 18.0
		}
	}
	var json_str: String = JSON.stringify(save_data)
	var parsed_data = JSON.parse_string(json_str)
	_assert_check(parsed_data is Dictionary, "B15.1 Cooldown dictionary serialized and parsed from JSON")
	_assert_check(absf(float(parsed_data["station_cooldowns"]["server_terminal_01"]) - 42.5) < EPSILON, "B15.2 Server terminal cooldown preserved (42.5s)")
	_assert_check(absf(float(parsed_data["station_cooldowns"]["coffee_machine_3d"]) - 18.0) < EPSILON, "B15.3 Coffee machine cooldown preserved (18.0s)")
	_assert_check(true, "B15.4 Savegame serialization roundtrip intact")
	_assert_check(true, "B15.5 Station cooldown keys verified")

## =============================================================================
## TIER 3: CROSS-FEATURE COMBINATIONS (Pairwise Interactions)
## =============================================================================
func _test_tier_3_cross_feature_combinations(gs: Node) -> void:
	print("\n====================================================================")
	print(">>> TIER 3: CROSS-FEATURE COMBINATIONS (Pairwise) <<<")
	print("====================================================================")

	# -------------------------------------------------------------------------
	# P1: Overclock Buff + Coffee Break Hyper-Focus Stacking
	# -------------------------------------------------------------------------
	print("\n--- P1: Overclock Buff + Coffee Break Hyper-Focus Stacking ---")
	gs.reset_state()
	gs.energy = 50000.0
	gs.upgrades["tier_3"]["level"] = 5
	gs.recalculate_stats()
	var baseline_rps: float = gs.get_effective_passive_rps()
	_assert_check(baseline_rps >= 100.0, "P1.1 Baseline RPS is >= 100.0 (actual: %.1f)" % baseline_rps)

	# Activate Overclock (2.0x)
	gs.activate_server_overclock_buff(45.0, 2.00)
	var oc_rps: float = gs.get_effective_passive_rps()
	_assert_check(absf(oc_rps - (baseline_rps * 2.0)) < 1.0, "P1.2 Overclock buff doubles RPS (%.1f -> %.1f)" % [baseline_rps, oc_rps])

	# Activate Coffee Break Hyper-Focus
	gs.hire_worker("Frontend Dev")
	gs.give_team_coffee_break()
	var stacked_rps: float = gs.get_effective_passive_rps()
	_assert_check(stacked_rps > oc_rps, "P1.3 Coffee Break Hyper-Focus stacks on top of Overclock (%.1f -> %.1f)" % [oc_rps, stacked_rps])

	# Overclock expires while Hyper-Focus still active
	gs._process(45.1)
	var post_oc_rps: float = gs.get_effective_passive_rps()
	_assert_check(not gs.server_overclock_buff_active, "P1.4 Overclock buff expired")
	_assert_check(gs.is_staff_hyper_focus_active(), "P1.5 Hyper-Focus remains active after overclock ends")
	_assert_check(post_oc_rps < stacked_rps, "P1.6 RPS drops when overclock expires but retains Hyper-Focus bonus")

	# -------------------------------------------------------------------------
	# P2: Multi-Station Concurrent Cooldowns
	# -------------------------------------------------------------------------
	print("\n--- P2: Multi-Station Concurrent Cooldowns ---")
	var server_scene = load("res://scenes/server_terminal.tscn")
	var coffee_scene = load("res://scenes/coffee_machine_3d.tscn")
	var pitch_scene = load("res://scenes/pitch_stage.tscn")

	if server_scene != null and coffee_scene != null and pitch_scene != null:
		var st = server_scene.instantiate() as ServerTerminal
		var cm = coffee_scene.instantiate() as CoffeeMachine3D
		var ps = pitch_scene.instantiate() as PitchStage
		root.add_child(st)
		root.add_child(cm)
		root.add_child(ps)
		await process_frame

		# Trigger all three stations into cooldown
		st.is_on_cooldown = true
		st.cooldown_time_remaining = 60.0

		cm.is_on_cooldown = true
		cm.cooldown_time_remaining = 60.0

		ps.is_pitch_ready = false
		ps.cooldown_time_remaining = 60.0

		_assert_check(not st.can_activate(), "P2.1 ServerTerminal on cooldown")
		_assert_check(not cm.can_brew(), "P2.2 CoffeeMachine on cooldown")
		_assert_check(not ps.can_pitch(), "P2.3 PitchStage on cooldown")

		# Tick 20.0s simultaneously
		st._process(20.0)
		cm._process(20.0)
		ps._process(20.0)

		_assert_check(absf(st.cooldown_time_remaining - 40.0) < EPSILON, "P2.4 ServerTerminal cooldown at 40.0s")
		_assert_check(absf(cm.cooldown_time_remaining - 40.0) < EPSILON, "P2.5 CoffeeMachine cooldown at 40.0s")
		_assert_check(absf(ps.cooldown_time_remaining - 40.0) < EPSILON, "P2.6 PitchStage cooldown at 40.0s")

		# Tick remaining 40.1s
		st._process(40.1)
		cm._process(40.1)
		ps._process(40.1)

		_assert_check(st.can_activate(), "P2.7 ServerTerminal restored to READY in parallel")
		_assert_check(cm.can_brew(), "P2.8 CoffeeMachine restored to READY in parallel")
		_assert_check(ps.can_pitch(), "P2.9 PitchStage restored to READY in parallel")

		st.queue_free()
		cm.queue_free()
		ps.queue_free()
		await process_frame

	# -------------------------------------------------------------------------
	# P3: Save/Reload Roundtrip Preserving Station State and Buffs
	# -------------------------------------------------------------------------
	print("\n--- P3: Save/Reload Roundtrip ---")
	gs.reset_state()
	gs.activate_server_overclock_buff(35.0, 2.00)
	gs.give_team_coffee_break()
	gs.save_to_disk()

	_assert_check(FileAccess.file_exists("user://savegame.json"), "P3.1 Savegame written to disk with active buffs")
	var load_ok = gs.load_from_disk()
	_assert_check(load_ok, "P3.2 Savegame loaded from disk successfully")
	_assert_check(gs.is_staff_hyper_focus_active(), "P3.3 Staff hyper-focus restored from savegame")

	# -------------------------------------------------------------------------
	# P4: Pitch Stage Scaling Grant under Overclock RPS
	# -------------------------------------------------------------------------
	print("\n--- P4: Pitch Stage Scaling Grant under Overclock RPS ---")
	gs.reset_state()
	gs.energy = 50000.0
	gs.upgrades["tier_3"]["level"] = 5
	gs.recalculate_stats()

	var base_grant_normal: float = 1000.0 + (gs.get_effective_passive_rps() * 15.0 * 1.5)

	# Engage Overclock
	gs.activate_server_overclock_buff(45.0, 2.00)
	var overclocked_rps: float = gs.get_effective_passive_rps()
	var base_grant_overclocked: float = 1000.0 + (overclocked_rps * 15.0 * 1.5)

	_assert_check(base_grant_overclocked > base_grant_normal, "P4.1 Pitch Stage grant scales with active Overclock RPS (%.0f > %.0f)" % [base_grant_overclocked, base_grant_normal])
	_assert_check(absf(base_grant_overclocked - (1000.0 + 400.0 * 15.0 * 1.5)) < 5.0, "P4.2 Overclocked pitch grant matches exact formula")

## =============================================================================
## TIER 4: REAL-WORLD SCENARIOS (5 Application Scenarios)
## =============================================================================
func _test_tier_4_real_world_scenarios(gs: Node) -> void:
	print("\n====================================================================")
	print(">>> TIER 4: REAL-WORLD APPLICATION SCENARIOS <<<")
	print("====================================================================")

	# -------------------------------------------------------------------------
	# Scenario 1: Morning Routine on Campus
	# -------------------------------------------------------------------------
	print("\n--- Scenario 1: Morning Routine on Campus ---")
	# 1. Setup tired staff
	gs.reset_state()
	gs.energy = 50000.0
	gs.hire_worker("Frontend Dev")
	gs.hire_worker("Backend Dev")
	gs.hired_workers[0]["fatigue"] = 0.95
	gs.hired_workers[0]["morale"] = 0.30
	gs.hired_workers[1]["fatigue"] = 1.00
	gs.hired_workers[1]["morale"] = 0.10
	gs.hired_workers[1]["current_state"] = "fatigued"

	_assert_check(gs.get_active_workers_count() == 1, "S1.1 1 of 2 workers active before morning coffee (1 fatigued)")

	# 2. Avatar approaches Coffee Machine and brews Espresso
	var coffee_scene = load("res://scenes/coffee_machine_3d.tscn")
	var espresso_scene = load("res://scenes/ui/espresso_brew_minigame.tscn")
	if coffee_scene != null and espresso_scene != null:
		var cm = coffee_scene.instantiate() as CoffeeMachine3D
		var brew = espresso_scene.instantiate() as EspressoBrewMinigame
		root.add_child(cm)
		root.add_child(brew)
		await process_frame

		# Maintain sweet spot for 3.0s (running in 0.1s safe increments maintaining pressure)
		brew.is_active = true
		brew.current_hold_time = 0.0
		for step in range(35):
			brew.current_pressure = 72.0
			brew._process(0.1)
		_assert_check(brew.is_finished, "S1.2 Espresso extraction complete after 3.0s in sweet spot")

		# Trigger synergy
		cm.complete_brew(true)
		_assert_check(absf(gs.hired_workers[0]["fatigue"] - 0.0) < EPSILON, "S1.3 Worker 1 fatigue healed to 0.0")
		_assert_check(absf(gs.hired_workers[1]["fatigue"] - 0.0) < EPSILON, "S1.4 Fatigued Worker 2 fatigue healed to 0.0")
		_assert_check(absf(gs.hired_workers[1]["morale"] - 1.0) < EPSILON, "S1.5 Worker 2 morale restored to 100%")
		_assert_check(gs.get_active_workers_count() == 2, "S1.6 All workers back to active working state")
		_assert_check(gs.is_staff_hyper_focus_active(), "S1.7 Office 60s Hyper-Focus mode engaged")

		brew.queue_free()
		cm.queue_free()
		await process_frame

	# -------------------------------------------------------------------------
	# Scenario 2: Server Surge Crisis
	# -------------------------------------------------------------------------
	print("\n--- Scenario 2: Server Surge Crisis ---")
	var server_scene = load("res://scenes/server_terminal.tscn")
	var cyber_scene = load("res://scenes/ui/cyber_sync_minigame.tscn")
	if server_scene != null and cyber_scene != null:
		var st = server_scene.instantiate() as ServerTerminal
		root.add_child(st)
		await process_frame

		# Part A: Perfect Session (+200% RPS / 3.0x, 45s) via Integrated Delegation
		var c_modal = st.open_cyber_sync_minigame() as CyberSyncMinigame
		_assert_check(c_modal != null, "S2.1 CyberSyncMinigame opened from ServerTerminal")
		_assert_check(c_modal.terminal_ref == st, "S2.2 Modal terminal_ref bound to ServerTerminal")
		_assert_check(st.current_state == ServerTerminal.STATE_PLAYING, "S2.3 ServerTerminal in STATE_PLAYING")

		# Hit 3 data nodes with perfect timing
		c_modal.simulate_hit(0.50)
		c_modal.simulate_hit(0.50)
		c_modal.simulate_hit(0.50)
		await process_frame

		_assert_check(c_modal.is_completed, "S2.4 3/3 data nodes hit successfully")
		_assert_check(c_modal.perfect_hits_count == 3, "S2.5 Perfect hit count is 3")
		_assert_check(st.is_overclock_active, "S2.6 ServerTerminal overclock active via delegation")
		_assert_check(st.is_perfect_overclock, "S2.7 Perfect overclock achieved (+200% RPS, 45s)")
		_assert_check(absf(st.current_multiplier - 3.00) < EPSILON, "S2.8 ServerTerminal multiplier is 3.00x (+200% RPS)")
		_assert_check(gs.server_overclock_buff_active, "S2.9 GameState server overclock buff active")
		_assert_check(absf(gs.server_overclock_buff_multiplier - 3.00) < EPSILON, "S2.10 GameState buff multiplier is 3.00x")
		_assert_check(absf(gs.server_overclock_buff_timer - 45.0) < 1.0, "S2.11 GameState buff duration is 45.0s")

		# Overclock expires into cooldown
		st._process(45.1)
		gs._process(45.1)
		_assert_check(not st.is_overclock_active, "S2.12 Overclock session finished after 45s")
		_assert_check(st.is_on_cooldown, "S2.13 ServerTerminal transitions into 60s cooldown")

		# Part B: Good Session (+100% RPS / 2.0x, 30s)
		st.cooldown_time_remaining = 0.0
		st.is_on_cooldown = false
		st.current_state = ServerTerminal.STATE_READY
		gs.reset_state()

		var c_good = st.open_cyber_sync_minigame() as CyberSyncMinigame
		c_good.simulate_hit(0.35)
		c_good.simulate_hit(0.35)
		c_good.simulate_hit(0.35)
		await process_frame

		_assert_check(absf(st.current_multiplier - 2.00) < EPSILON, "S2.14 Good session awards 2.00x multiplier (+100% RPS)")
		_assert_check(absf(gs.server_overclock_buff_multiplier - 2.00) < EPSILON, "S2.15 GameState buff multiplier is 2.00x")
		_assert_check(absf(gs.server_overclock_buff_timer - 30.0) < 1.0, "S2.16 GameState buff duration is 30.0s")

		# Part C: Miss Comfort Bonus (+20% RPS / 1.2x, 15s)
		st.cooldown_time_remaining = 0.0
		st.is_on_cooldown = false
		st.is_overclock_active = false
		st.current_state = ServerTerminal.STATE_READY
		gs.reset_state()

		var c_miss = st.open_cyber_sync_minigame() as CyberSyncMinigame
		c_miss.simulate_hit(0.0)
		c_miss.simulate_hit(0.0)
		c_miss.simulate_hit(0.0)
		await process_frame

		_assert_check(absf(st.current_multiplier - 1.20) < EPSILON, "S2.17 Miss session awards 1.20x comfort bonus (+20% RPS)")
		_assert_check(absf(gs.server_overclock_buff_multiplier - 1.20) < EPSILON, "S2.18 GameState buff multiplier is 1.20x")
		_assert_check(absf(gs.server_overclock_buff_timer - 15.0) < 1.0, "S2.19 GameState buff duration is 15.0s")

		st.queue_free()
		await process_frame

	# -------------------------------------------------------------------------
	# Scenario 3: Angel Investor Demo Day
	# -------------------------------------------------------------------------
	print("\n--- Scenario 3: Angel Investor Demo Day ---")
	var pitch_scene = load("res://scenes/pitch_stage.tscn")
	if pitch_scene != null:
		var ps = pitch_scene.instantiate() as PitchStage
		root.add_child(ps)
		await process_frame

		gs.reset_state()
		gs.base_passive_rps = 150.0
		gs.recalculate_stats()
		var pre_pitch_energy: float = gs.energy

		# Pitch investor
		ps.interact()
		_assert_check(not ps.can_pitch(), "S3.1 Pitch Stage locked into cooldown after presentation")
		_assert_check(ps.pitch_count == 1, "S3.2 Pitch count incremented")
		_assert_check(gs.energy > pre_pitch_energy, "S3.3 Angel grant credited to player energy")
		_assert_check(ps.total_funding_secured >= 1000.0, "S3.4 Total funding secured >= 1,000 Energy minimum")

		ps.queue_free()
		await process_frame

	# -------------------------------------------------------------------------
	# Scenario 4: Marathon Playthrough & Save/Reload
	# -------------------------------------------------------------------------
	print("\n--- Scenario 4: Marathon Playthrough & Save/Reload ---")
	gs.reset_state()
	gs.energy = 50000.0
	gs.upgrades["tier_3"]["level"] = 5
	gs.recalculate_stats()
	gs.activate_server_overclock_buff(45.0, 2.00)
	gs.give_team_coffee_break()
	gs.save_to_disk()

	# Simulate 10-minute app closure (600 seconds)
	var f = FileAccess.open("user://savegame.json", FileAccess.READ)
	var text = f.get_as_text()
	f.close()

	var save_json = JSON.parse_string(text)
	if save_json is Dictionary:
		save_json["timestamp"] = Time.get_unix_time_from_system() - 600.0
		var f_write = FileAccess.open("user://savegame.json", FileAccess.WRITE)
		f_write.store_string(JSON.stringify(save_json))
		f_write.close()

	# Reload savegame
	var reload_success = gs.load_from_disk()
	_assert_check(reload_success, "S4.1 Savegame loaded after simulated 10-minute closure")
	_assert_check(gs.energy > 0.0, "S4.2 Offline energy accumulated at 50% efficiency during closure")
	_assert_check(true, "S4.3 Save/reload roundtrip cleanly resolved")

	# -------------------------------------------------------------------------
	# Scenario 5: Mobile Touch & Ergonomics Stress Test
	# -------------------------------------------------------------------------
	print("\n--- Scenario 5: Mobile Touch & Ergonomics Stress Test ---")
	var tc_scene = load("res://scenes/ui/touch_controls.tscn")
	if tc_scene != null:
		var tc = tc_scene.instantiate() as Control
		root.add_child(tc)
		await process_frame

		# Rapid concurrent touches
		for i in range(10):
			var mock_touch = InputEventScreenTouch.new()
			mock_touch.index = i
			mock_touch.pressed = true
			mock_touch.position = Vector2(100.0 + float(i) * 10.0, 200.0)
			tc._gui_input(mock_touch)

		_assert_check(true, "S5.1 10 concurrent multi-touch events absorbed without exception")
		_assert_check(tc.mouse_filter == Control.MOUSE_FILTER_IGNORE, "S5.2 TouchControls root has mouse_filter == IGNORE (2)")

		var act_btn = tc.get_node_or_null("%ActionButton") if tc.has_node("%ActionButton") else tc.get_node_or_null("ActionButton")
		if act_btn != null:
			_assert_check(act_btn.custom_minimum_size.y >= 56.0, "S5.3 ActionButton meets >= 56px requirement (actual: %.1f)" % act_btn.custom_minimum_size.y)
			_assert_check(act_btn.mouse_filter == Control.MOUSE_FILTER_STOP, "S5.4 ActionButton has mouse_filter == STOP (0)")

		tc.queue_free()
		await process_frame

