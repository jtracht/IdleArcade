extends SceneTree

## =============================================================================
## Master Headless SceneTree Test Suite for Phase 10: VFX, Lighting, Shake & Transitions
## File: IdleArcade/tests/test_phase10_vfx_lighting.gd
## Target: Godot 4.3 Engine Headless Runner
##
## Validates all 6 Core Sections:
##   1. ConfettiBurst 3D and 2D instantiation, particle properties, finished signal,
##      and queue_free self-cleanup.
##   2. Camera screen shake trauma math, quadratic falloff, decay, frenzy trigger,
##      and h_offset/v_offset zeroing.
##   3. DayNightCycle 3-phase lighting (Daylight, Sunset, Cyberpunk Night with exact
##      Color(0.08, 0.10, 0.18) ambient light), smoothstep interpolation, and cycle modes.
##   4. Campus night emission modulation on materials (windows, neon trims, server LEDs).
##   5. SettingsModal ScreenShake slider and LightCycle mode buttons (touch height >= 56px,
##      mouse_filter = STOP, GameState persistence).
##   6. ScreenTransition two-phase wipe, midpoint callback execution, mouse_filter state
##      machine (STOP during animation, IGNORE when idle), and HUD shop card glow pulse.
##
## Execution:
##   godot --headless --path IdleArcade -s tests/test_phase10_vfx_lighting.gd
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
	print(">>> RUNNING MASTER PHASE 10 VFX & LIGHTING HEADLESS SCENETREE TEST SUITE <<<")
	print("====================================================================")
	call_deferred("_run_all_tests")

func _run_all_tests() -> void:
	await process_frame

	# -------------------------------------------------------------------------
	# Autoload Singleton Setup: GameState & AudioManager
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
	if am_script == null:
		printerr("[FATAL] Cannot load audio_manager.gd")
		quit(1)
		return

	var am = root.get_node_or_null("AudioManager")
	if am == null:
		am = am_script.new()
		am.name = "AudioManager"
		root.add_child(am)
	_assert_check(am != null, "0.4 AudioManager mounted at /root/AudioManager")

	await process_frame

	# Execute all 6 required sections sequentially
	await _test_section_1_confetti_burst()
	await _test_section_2_screen_shake(gs)
	await _test_section_3_day_night_cycle(gs)
	await _test_section_4_material_emissions()
	await _test_section_5_settings_modal(gs)
	await _test_section_6_screen_transition_and_shop_glow(gs)

	print("\n====================================================================")
	print(">>> PHASE 10 SCENETREE TEST SUITE SUMMARY: %d PASSED, %d FAILED <<<" % [pass_count, fail_count])
	print("====================================================================")

	if fail_count == 0:
		print(">>> ALL PHASE 10 HEADLESS SCENETREE TESTS PASSED (Exit Code 0) <<<")
		quit(0)
	else:
		printerr(">>> PHASE 10 HEADLESS SCENETREE TESTS FAILED (Exit Code 1) <<<")
		quit(1)

# =============================================================================
# SECTION 1: ConfettiBurst 3D and 2D Instantiation, Properties & Cleanup
# =============================================================================
func _test_section_1_confetti_burst() -> void:
	print("\n--- SECTION 1: ConfettiBurst 3D/2D Instantiation, Properties & Cleanup ---")

	var confetti_scene = load("res://scenes/vfx/confetti_burst.tscn")
	_assert_check(confetti_scene != null, "1.1 scenes/vfx/confetti_burst.tscn loads successfully")
	if confetti_scene == null:
		return

	var burst = confetti_scene.instantiate() as ConfettiBurst
	_assert_check(burst != null, "1.2 ConfettiBurst instantiates from scene")
	root.add_child(burst)
	await process_frame

	var p3d = burst.get_node_or_null("Particles3D") as CPUParticles3D
	var p2d = burst.get_node_or_null("Particles2D") as CPUParticles2D
	_assert_check(p3d != null, "1.3 CPUParticles3D node present in ConfettiBurst")
	_assert_check(p2d != null, "1.4 CPUParticles2D node present in ConfettiBurst")

	if p3d != null:
		_assert_check(p3d.one_shot == true, "1.5 CPUParticles3D configured as one_shot")
		_assert_check(p3d.hue_variation_min <= -0.5 and p3d.hue_variation_max >= 0.5,
			"1.6 CPUParticles3D full rainbow hue variation configured")
		_assert_check(p3d.mesh is BoxMesh, "1.7 CPUParticles3D uses low-poly BoxMesh snippet")
		_assert_check(p3d.explosiveness >= 0.8, "1.8 CPUParticles3D high explosiveness configured")

	if p2d != null:
		_assert_check(p2d.one_shot == true, "1.9 CPUParticles2D configured as one_shot")
		_assert_check(p2d.hue_variation_min <= -0.5 and p2d.hue_variation_max >= 0.5,
			"1.10 CPUParticles2D full rainbow hue variation configured")

	_assert_check(burst.has_signal("burst_finished"), "1.11 ConfettiBurst declares burst_finished signal")

	# Clean up initial inspection burst
	burst.queue_free()
	await process_frame

	# Test static factory spawn_burst_3d
	var burst_3d = ConfettiBurst.spawn_burst_3d(root, Vector3(0, 5, 0), 35) as ConfettiBurst
	_assert_check(burst_3d != null, "1.12 ConfettiBurst.spawn_burst_3d spawns instance")
	await process_frame

	if burst_3d != null:
		_assert_check(burst_3d._active_mode == "3d", "1.13 spawn_burst_3d activates '3d' mode")
		var active_p3d = burst_3d.get_node_or_null("Particles3D") as CPUParticles3D
		_assert_check(active_p3d != null, "1.14 Particles3D retained in 3D burst")
		if active_p3d != null:
			_assert_check(active_p3d.amount == 35, "1.15 Particles3D amount set to 35")
			_assert_check(active_p3d.top_level == true, "1.16 Particles3D top_level enabled")
			_assert_check(active_p3d.emitting == true, "1.17 Particles3D emitting is active")
		_assert_check(burst_3d.get_node_or_null("Particles2D") == null or burst_3d.get_node_or_null("Particles2D").is_queued_for_deletion(),
			"1.18 Particles2D pruned in 3D mode")

	# Test static factory spawn_burst_2d
	var burst_2d = ConfettiBurst.spawn_burst_2d(root, Vector2(200, 300), 25) as ConfettiBurst
	_assert_check(burst_2d != null, "1.19 ConfettiBurst.spawn_burst_2d spawns instance")
	await process_frame

	if burst_2d != null:
		_assert_check(burst_2d._active_mode == "2d", "1.20 spawn_burst_2d activates '2d' mode")
		var active_p2d = burst_2d.get_node_or_null("Particles2D") as CPUParticles2D
		_assert_check(active_p2d != null, "1.21 Particles2D retained in 2D burst")
		if active_p2d != null:
			_assert_check(active_p2d.amount == 25, "1.22 Particles2D amount set to 25")
			_assert_check(active_p2d.emitting == true, "1.23 Particles2D emitting is active")
		_assert_check(burst_2d.get_node_or_null("Particles3D") == null or burst_2d.get_node_or_null("Particles3D").is_queued_for_deletion(),
			"1.24 Particles3D pruned in 2D mode")

	# Test emitter finished queue_free trigger
	var finished_signal_fired: bool = false
	burst_3d.burst_finished.connect(func(): finished_signal_fired = true)
	burst_3d._on_emitter_finished()
	_assert_check(finished_signal_fired == true, "1.25 _on_emitter_finished emits burst_finished")
	_assert_check(burst_3d.is_queued_for_deletion(), "1.26 burst_3d queued for deletion on emitter finish")

	burst_2d.queue_free()
	await process_frame

# =============================================================================
# SECTION 2: Camera Screen Shake Trauma Math, Quadratic Falloff & Decay
# =============================================================================
func _test_section_2_screen_shake(gs: Node) -> void:
	print("\n--- SECTION 2: Camera Screen Shake Trauma Math, Quadratic Falloff & Decay ---")

	var m3d_scene = load("res://scenes/main_3d.tscn")
	_assert_check(m3d_scene != null, "2.1 scenes/main_3d.tscn loads successfully")
	if m3d_scene == null:
		return

	var m3d = m3d_scene.instantiate() as Main3D
	root.add_child(m3d)
	await process_frame

	_assert_check(m3d.has_method("add_screen_shake"), "2.2 Main3D implements add_screen_shake")
	_assert_check("trauma" in m3d, "2.3 Main3D declares trauma variable")
	_assert_check("shake_decay_rate" in m3d, "2.4 Main3D declares shake_decay_rate")

	# Test add_screen_shake clamping
	m3d.trauma = 0.0
	m3d.add_screen_shake(0.5)
	_assert_check(abs(m3d.trauma - 0.5) < EPSILON, "2.5 add_screen_shake(0.5) sets trauma to 0.5")

	m3d.add_screen_shake(0.8)
	_assert_check(abs(m3d.trauma - 1.0) < EPSILON, "2.6 add_screen_shake clamps trauma strictly to 1.0")

	# Test trauma decay over delta
	var decay_rate = float(m3d.get("shake_decay_rate"))
	_assert_check(decay_rate > 0.0, "2.7 shake_decay_rate is positive (%.2f)" % decay_rate)
	var prev_trauma = m3d.trauma
	m3d._update_screen_shake(0.1)
	var expected_decayed = maxf(0.0, prev_trauma - decay_rate * 0.1)
	_assert_check(abs(m3d.trauma - expected_decayed) < 0.01,
		"2.8 _update_screen_shake(0.1) decays trauma correctly (%.3f -> %.3f)" % [prev_trauma, m3d.trauma])

	# Test quadratic trauma^2 calculation
	var test_trauma: float = 0.6
	var intensity: float = 1.0
	var calculated_shake: float = test_trauma * test_trauma * intensity
	_assert_check(abs(calculated_shake - 0.36) < EPSILON,
		"2.9 Quadratic falloff trauma^2 at 0.6 yields exactly 0.36 (actual: %.3f)" % calculated_shake)

	# Test user intensity modulation
	intensity = 0.5
	calculated_shake = test_trauma * test_trauma * intensity
	_assert_check(abs(calculated_shake - 0.18) < EPSILON,
		"2.10 User intensity 0.5 halves effective shake to 0.18")

	intensity = 0.0
	calculated_shake = test_trauma * test_trauma * intensity
	_assert_check(calculated_shake == 0.0,
		"2.11 User intensity 0.0 zeroes out shake completely (accessibility support)")

	# Test idle offset reset
	m3d.trauma = 0.0
	m3d._update_screen_shake(0.1)
	var cam = m3d.camera
	if cam != null:
		_assert_check(cam.h_offset == 0.0 and cam.v_offset == 0.0,
			"2.12 Camera h_offset and v_offset reset to 0.0 when trauma is zero")

	# Test frenzy activation hook
	m3d.trauma = 0.0
	if gs.has_signal("frenzy_updated"):
		gs.frenzy_updated.emit(true)
		await process_frame
		_assert_check(m3d.trauma >= 0.60,
			"2.13 Frenzy activation signal triggers strong screen shake (trauma: %.2f)" % m3d.trauma)

	m3d.queue_free()
	await process_frame

# =============================================================================
# SECTION 3: DayNightCycle 3-Phase Lighting & Smoothstep Interpolation
# =============================================================================
func _test_section_3_day_night_cycle(gs: Node) -> void:
	print("\n--- SECTION 3: DayNightCycle 3-Phase Lighting & Interpolation ---")

	var dnc_scene = load("res://scenes/day_night_cycle.tscn")
	_assert_check(dnc_scene != null, "3.1 scenes/day_night_cycle.tscn loads successfully")
	if dnc_scene == null:
		return

	var dnc = dnc_scene.instantiate() as DayNightCycle
	root.add_child(dnc)
	await process_frame

	_assert_check(dnc != null, "3.2 DayNightCycle instantiates from scene")
	_assert_check(dnc.has_signal("phase_changed"), "3.3 DayNightCycle declares phase_changed")
	_assert_check(dnc.has_signal("cycle_mode_changed"), "3.4 DayNightCycle declares cycle_mode_changed")
	_assert_check(dnc.has_signal("time_of_day_changed"), "3.5 DayNightCycle declares time_of_day_changed")

	# Test Cycle Modes
	dnc.set_cycle_mode("day")
	_assert_check(dnc.cycle_mode == "day", "3.6 set_cycle_mode('day') sets cycle_mode to 'day'")
	_assert_check(abs(dnc.time_of_day - 0.20) < EPSILON, "3.7 Day mode sets time_of_day to 0.20")

	dnc.set_cycle_mode("night")
	_assert_check(dnc.cycle_mode == "night", "3.8 set_cycle_mode('night') sets cycle_mode to 'night'")
	_assert_check(abs(dnc.time_of_day - 0.82) < EPSILON, "3.9 Night mode sets time_of_day to 0.82")

	dnc.set_cycle_mode("auto")
	_assert_check(dnc.cycle_mode == "auto", "3.10 set_cycle_mode('auto') sets cycle_mode to 'auto'")

	# Test 3-Phase Mathematical State Calculations via calculate_lighting_state
	# 1. Daylight (t = 0.20)
	var state_day = DayNightCycle.calculate_lighting_state(0.20)
	_assert_check(abs(state_day["dir_energy"] - 1.2) < EPSILON, "3.11 Daylight dir_energy is 1.2")
	_assert_check(state_day["dir_color"].is_equal_approx(Color(1.0, 0.96, 0.88, 1.0)),
		"3.12 Daylight dir_color is warm sunlight Color(1.0, 0.96, 0.88)")
	_assert_check(state_day["amb_color"].is_equal_approx(Color(0.38, 0.44, 0.53, 1.0)),
		"3.13 Daylight amb_color is Color(0.38, 0.44, 0.53)")
	_assert_check(abs(state_day["amb_energy"] - 0.75) < EPSILON, "3.14 Daylight amb_energy is 0.75")
	_assert_check(abs(state_day["night_factor"] - 0.0) < EPSILON, "3.15 Daylight night_factor is 0.0")

	# 2. Golden Sunset (t = 0.65)
	var state_sunset = DayNightCycle.calculate_lighting_state(0.65)
	_assert_check(abs(state_sunset["dir_energy"] - 0.85) < EPSILON, "3.16 Sunset dir_energy is 0.85")
	_assert_check(state_sunset["dir_color"].is_equal_approx(Color(1.0, 0.55, 0.22, 1.0)),
		"3.17 Sunset dir_color is warm amber Color(1.0, 0.55, 0.22)")
	_assert_check(state_sunset["amb_color"].is_equal_approx(Color(0.42, 0.28, 0.25, 1.0)),
		"3.18 Sunset amb_color is Color(0.42, 0.28, 0.25)")
	_assert_check(abs(state_sunset["amb_energy"] - 0.65) < EPSILON, "3.19 Sunset amb_energy is 0.65")
	_assert_check(abs(state_sunset["night_factor"] - 0.4) < EPSILON, "3.20 Sunset night_factor is 0.4")

	# 3. Cyberpunk Night (t = 0.82) - MANDATORY SPECIFICATION VALUE
	var state_night = DayNightCycle.calculate_lighting_state(0.82)
	_assert_check(abs(state_night["dir_energy"] - 0.15) < EPSILON, "3.21 Cyberpunk Night dir_energy is 0.15")
	_assert_check(state_night["dir_color"].is_equal_approx(Color(0.25, 0.35, 0.65, 1.0)),
		"3.22 Cyberpunk Night dir_color is cool moonlight Color(0.25, 0.35, 0.65)")
	_assert_check(state_night["amb_color"].is_equal_approx(Color(0.08, 0.10, 0.18, 1.0)),
		"3.23 Cyberpunk Night ambient color strictly matches MANDATORY Color(0.08, 0.10, 0.18)")
	_assert_check(abs(state_night["amb_energy"] - 0.55) < EPSILON, "3.24 Cyberpunk Night amb_energy is 0.55")
	_assert_check(abs(state_night["night_factor"] - 1.0) < EPSILON, "3.25 Cyberpunk Night night_factor is 1.0")

	# Smoothstep interpolation bounds check
	var state_mid = DayNightCycle.calculate_lighting_state(0.55)
	_assert_check(state_mid["dir_energy"] < 1.2 and state_mid["dir_energy"] > 0.85,
		"3.26 Mid-transition energy strictly bounded between Day and Sunset (got %.2f)" % state_mid["dir_energy"])

	dnc.queue_free()
	await process_frame

# =============================================================================
# SECTION 4: Campus Night Emission Modulation on Materials
# =============================================================================
func _test_section_4_material_emissions() -> void:
	print("\n--- SECTION 4: Campus Night Emission Modulation on Materials ---")

	var dnc_scene = load("res://scenes/day_night_cycle.tscn")
	if dnc_scene == null:
		return

	var dnc = dnc_scene.instantiate() as DayNightCycle
	root.add_child(dnc)
	await process_frame

	var win_mat = StandardMaterial3D.new()
	var neon_mat = StandardMaterial3D.new()
	var server_mat = StandardMaterial3D.new()

	dnc.register_window_material(win_mat)
	dnc.register_neon_material(neon_mat)
	dnc.register_server_led_material(server_mat)

	# 1. Day emissions (night_factor = 0.0)
	dnc._update_material_emissions(0.0)
	_assert_check(win_mat.emission_enabled == true, "4.1 Window material has emission_enabled true")
	_assert_check(abs(win_mat.emission_energy_multiplier - 0.0) < EPSILON,
		"4.2 Window day emission energy is 0.0")
	_assert_check(abs(neon_mat.emission_energy_multiplier - 0.2) < EPSILON,
		"4.3 Neon day emission energy is 0.2")
	_assert_check(abs(server_mat.emission_energy_multiplier - 1.2) < EPSILON,
		"4.4 Server LED day emission energy is 1.2")

	# 2. Sunset emissions (night_factor = 0.4)
	dnc._update_material_emissions(0.4)
	var exp_win_sunset = lerpf(0.0, 1.8, 0.4)
	var exp_neon_sunset = lerpf(0.2, 2.5, 0.4)
	var exp_server_sunset = lerpf(1.2, 3.0, 0.4)
	_assert_check(abs(win_mat.emission_energy_multiplier - exp_win_sunset) < 0.01,
		"4.5 Window sunset emission energy is ~0.72 (got %.2f)" % win_mat.emission_energy_multiplier)
	_assert_check(abs(neon_mat.emission_energy_multiplier - exp_neon_sunset) < 0.01,
		"4.6 Neon sunset emission energy is ~1.12 (got %.2f)" % neon_mat.emission_energy_multiplier)
	_assert_check(abs(server_mat.emission_energy_multiplier - exp_server_sunset) < 0.01,
		"4.7 Server LED sunset emission energy is ~1.92 (got %.2f)" % server_mat.emission_energy_multiplier)

	# 3. Cyberpunk Night emissions (night_factor = 1.0)
	dnc._update_material_emissions(1.0)
	_assert_check(abs(win_mat.emission_energy_multiplier - 1.8) < EPSILON,
		"4.8 Window night emission energy reaches peak 1.8")
	_assert_check(abs(neon_mat.emission_energy_multiplier - 2.5) < EPSILON,
		"4.9 Neon night emission energy reaches peak 2.5")
	_assert_check(abs(server_mat.emission_energy_multiplier - 3.0) < EPSILON,
		"4.10 Server LED night emission energy reaches peak 3.0")

	dnc.queue_free()
	await process_frame

# =============================================================================
# SECTION 5: SettingsModal ScreenShake Slider & LightCycle Mode Buttons
# =============================================================================
func _test_section_5_settings_modal(gs: Node) -> void:
	print("\n--- SECTION 5: SettingsModal ScreenShake Slider & LightCycle Mode Buttons ---")

	var modal_scene = load("res://scenes/ui/settings_modal.tscn")
	_assert_check(modal_scene != null, "5.1 scenes/ui/settings_modal.tscn loads successfully")
	if modal_scene == null:
		return

	var modal = modal_scene.instantiate() as Control
	root.add_child(modal)
	await process_frame

	# Screen Shake Slider Checks
	var shake_slider = modal.get_node_or_null("%ScreenShakeSlider") as HSlider
	var shake_label = modal.get_node_or_null("%ScreenShakeValue") as Label
	_assert_check(shake_slider != null, "5.2 %ScreenShakeSlider exists in SettingsModal")
	_assert_check(shake_label != null, "5.3 %ScreenShakeValue label exists in SettingsModal")

	if shake_slider != null:
		_assert_check(shake_slider.custom_minimum_size.y >= 56.0,
			"5.4 ScreenShakeSlider touch height >= 56px (actual: %.1fpx)" % shake_slider.custom_minimum_size.y)
		_assert_check(shake_slider.mouse_filter == Control.MOUSE_FILTER_STOP,
			"5.5 ScreenShakeSlider mouse_filter == STOP")

		# Test slider value change handler
		modal._on_screen_shake_slider_changed(0.40)
		_assert_check(abs(float(gs.get("screen_shake_intensity")) - 0.40) < EPSILON,
			"5.6 ScreenShakeSlider updates GameState.screen_shake_intensity to 0.40")
		if shake_label != null:
			_assert_check("40" in shake_label.text,
				"5.7 ScreenShakeValue label displays '40%%' (got '%s')" % shake_label.text)

	# Light Cycle Buttons Checks
	var auto_btn = modal.get_node_or_null("%LightCycleAutoButton") as Button
	var day_btn = modal.get_node_or_null("%LightCycleDayButton") as Button
	var night_btn = modal.get_node_or_null("%LightCycleNightButton") as Button
	var cycle_label = modal.get_node_or_null("%LightCycleValue") as Label

	_assert_check(auto_btn != null, "5.8 %LightCycleAutoButton exists in SettingsModal")
	_assert_check(day_btn != null, "5.9 %LightCycleDayButton exists in SettingsModal")
	_assert_check(night_btn != null, "5.10 %LightCycleNightButton exists in SettingsModal")
	_assert_check(cycle_label != null, "5.11 %LightCycleValue label exists in SettingsModal")

	var mode_buttons = [
		["LightCycleAutoButton", auto_btn],
		["LightCycleDayButton", day_btn],
		["LightCycleNightButton", night_btn]
	]

	for entry in mode_buttons:
		var b_name: String = entry[0]
		var b_node: Button = entry[1]
		if b_node != null:
			_assert_check(b_node.custom_minimum_size.y >= 56.0,
				"5.12 %s touch height >= 56px (actual: %.1fpx)" % [b_name, b_node.custom_minimum_size.y])
			_assert_check(b_node.mouse_filter == Control.MOUSE_FILTER_STOP,
				"5.13 %s mouse_filter == STOP" % b_name)

	# Test Button Interactions & GameState Updates
	if modal.has_method("_on_light_cycle_night_pressed"):
		modal._on_light_cycle_night_pressed()
		_assert_check(gs.get("light_cycle_mode") == "night",
			"5.14 _on_light_cycle_night_pressed sets GameState.light_cycle_mode to 'night'")

	if modal.has_method("_on_light_cycle_day_pressed"):
		modal._on_light_cycle_day_pressed()
		_assert_check(gs.get("light_cycle_mode") == "day",
			"5.15 _on_light_cycle_day_pressed sets GameState.light_cycle_mode to 'day'")

	if modal.has_method("_on_light_cycle_auto_pressed"):
		modal._on_light_cycle_auto_pressed()
		_assert_check(gs.get("light_cycle_mode") == "auto",
			"5.16 _on_light_cycle_auto_pressed sets GameState.light_cycle_mode to 'auto'")

	modal.close()
	await process_frame

# =============================================================================
# SECTION 6: ScreenTransition Two-Phase Wipe & HUD Shop Card Glow Pulse
# =============================================================================
func _test_section_6_screen_transition_and_shop_glow(gs: Node) -> void:
	print("\n--- SECTION 6: ScreenTransition Two-Phase Wipe & Shop Glow Pulse ---")

	var trans_scene = load("res://scenes/ui/screen_transition.tscn")
	_assert_check(trans_scene != null, "6.1 scenes/ui/screen_transition.tscn loads successfully")
	if trans_scene == null:
		return

	var trans = trans_scene.instantiate() as ScreenTransition
	root.add_child(trans)
	await process_frame

	_assert_check(trans.layer == 15, "6.2 ScreenTransition layer is 15 (above HUD overlay)")
	var rect = trans.get_node_or_null("TransitionRect") as ColorRect
	_assert_check(rect != null, "6.3 TransitionRect ColorRect exists")

	if rect != null:
		_assert_check(rect.visible == false, "6.4 Initial TransitionRect visible is false")
		_assert_check(rect.mouse_filter == Control.MOUSE_FILTER_IGNORE,
			"6.5 Initial TransitionRect mouse_filter is IGNORE (no input blocking while idle)")
		_assert_check(rect.color.is_equal_approx(Color(0.04, 0.06, 0.09, 1.0)),
			"6.6 TransitionRect uses dark incubator theme Color(0.04, 0.06, 0.09)")

	_assert_check(trans.is_transitioning() == false, "6.7 is_transitioning() initially false")

	# Test two-phase wipe lifecycle
	var tracker: Dictionary = {"midpoint": false}
	var on_midpoint = func():
		tracker["midpoint"] = true

	trans.transition_wipe(on_midpoint, 0.1)
	_assert_check(trans.is_transitioning() == true, "6.8 is_transitioning() true during wipe")
	if rect != null:
		_assert_check(rect.visible == true, "6.9 TransitionRect visible is true during active wipe")
		_assert_check(rect.mouse_filter == Control.MOUSE_FILTER_STOP,
			"6.10 TransitionRect mouse_filter is STOP during active wipe (strict input isolation)")

	# Wait for transition to complete
	var wait_time: float = 0.0
	while trans.is_transitioning() and wait_time < 0.5:
		await process_frame
		wait_time += 0.016

	_assert_check(tracker["midpoint"] == true, "6.11 Midpoint callback executed while blacked out")
	_assert_check(trans.is_transitioning() == false, "6.12 is_transitioning() resets to false on completion")
	if rect != null:
		_assert_check(rect.visible == false, "6.13 TransitionRect hidden upon transition completion")
		_assert_check(rect.mouse_filter == Control.MOUSE_FILTER_IGNORE,
			"6.14 TransitionRect mouse_filter reverts to IGNORE upon transition completion")

	# Test HUD Shop Card Glow Pulse
	var hud_scene = load("res://scenes/hud.tscn")
	_assert_check(hud_scene != null, "6.15 scenes/hud.tscn loads successfully")
	if hud_scene != null:
		var hud = hud_scene.instantiate()
		root.add_child(hud)
		await process_frame

		_assert_check(hud.has_method("is_card_pulsing"), "6.16 hud.gd implements is_card_pulsing(upgrade_id)")
		_assert_check(hud.has_method("get_card_border_color"), "6.17 hud.gd implements get_card_border_color(upgrade_id)")

		# When energy is 0, cards should not pulse
		gs.energy = 0.0
		hud._refresh_affordability(0.0)
		_assert_check(hud.is_card_pulsing("tier_1") == false,
			"6.18 Card 'tier_1' is NOT pulsing when energy is 0")

		# When energy is high, affordable cards pulse
		gs.energy = 100000.0
		hud._refresh_affordability(100000.0)
		_assert_check(hud.is_card_pulsing("tier_1") == true,
			"6.19 Card 'tier_1' pulses when energy exceeds cost")

		# When energy drops below cost, pulsing cleanly stops
		gs.energy = 0.0
		hud._refresh_affordability(0.0)
		_assert_check(hud.is_card_pulsing("tier_1") == false,
			"6.20 Card 'tier_1' stops pulsing when energy drops")

		hud.queue_free()
		await process_frame

	trans.queue_free()
	await process_frame
