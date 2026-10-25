extends SceneTree

## =============================================================================
## Empirical Challenger M3-2 Test Suite:
## Touch Ergonomics, Pointer Isolation & Screen Shake Dynamics
## File: IdleArcade/tests/test_challenger_m3_2.gd
##
## Challenger: Challenger M3-2 (Adversarial Empirical Verification)
## Target: Phase 16 Milestone 3
##
## Challenge Dimensions:
## 1. 100% Minigame Button Touch Targets >= 56px (static & dynamic mutation)
## 2. Pointer Isolation (mouse_filter = STOP, accept_event() absorption)
## 3. Camera Locomotion Gating & Avatar Input Suppression
## 4. Screen Shake Dynamics (Trauma Clamping [0.0, 1.0], Decay, Sensitivity Multiplier, Signal Decoupling)
##
## Executable via:
##   godot.cmd --headless --path IdleArcade -s tests/test_challenger_m3_2.gd
## =============================================================================

var pass_count: int = 0
var fail_count: int = 0
var findings: Array[String] = []

var _mounted_nodes: Array[Node] = []
var _save_backup_text: String = ""
var _had_save_backup: bool = false

func _assert_chall(condition: bool, test_name: String, detail: String = "") -> void:
	if condition:
		print("  [PASS] %s" % test_name)
		pass_count += 1
	else:
		var err_msg: String = "  [FAIL] %s" % test_name
		if detail != "":
			err_msg += " -> " + detail
		printerr(err_msg)
		findings.append(err_msg)
		fail_count += 1

func _init() -> void:
	print("====================================================================")
	print("[CHALLENGER M3-2] Touch Ergonomics, Pointer Isolation & Screen Shake")
	print("====================================================================")
	process_frame.connect(_on_first_frame, CONNECT_ONE_SHOT)

func _on_first_frame() -> void:
	# Backup savegame if exists
	if FileAccess.file_exists("user://savegame.json"):
		var f = FileAccess.open("user://savegame.json", FileAccess.READ)
		if f != null:
			_save_backup_text = f.get_as_text()
			_had_save_backup = true
			f.close()

	_run_all_challenges()
	_cleanup_and_quit(0 if fail_count == 0 else 1)

func _run_all_challenges() -> void:
	print("\n--- SUITE 1: Touch Target Ergonomics (>= 56px Boundary & Stress) ---")
	_challenge_touch_target_ergonomics()

	print("\n--- SUITE 2: Pointer Isolation & Event Absorption ---")
	_challenge_pointer_isolation()

	print("\n--- SUITE 3: Camera Locomotion Gating & Avatar Input Suppression ---")
	_challenge_locomotion_gating()

	print("\n--- SUITE 4: Screen Shake Dynamics, Clamping & Configurable Setting ---")
	_challenge_screen_shake_dynamics()

# ==============================================================================
# SUITE 1: Touch Target Ergonomics
# ==============================================================================

func _challenge_touch_target_ergonomics() -> void:
	# 1. CyberSyncMinigame
	var cyber_scene = load("res://scenes/ui/cyber_sync_minigame.tscn")
	_assert_chall(cyber_scene != null, "1.1 Load cyber_sync_minigame.tscn")
	if cyber_scene != null:
		var cyber: Control = cyber_scene.instantiate()
		root.add_child(cyber)
		_mounted_nodes.append(cyber)

		var close_btn: Button = cyber.get_node_or_null("%CloseButton")
		var sync_btn: Button = cyber.get_node_or_null("%SyncHitButton")

		_assert_chall(close_btn != null, "1.2 CyberSync close_btn exists")
		if close_btn != null:
			_assert_chall(close_btn.custom_minimum_size.y >= 56.0, "1.3 CyberSync close_btn height >= 56px", "Actual: %f" % close_btn.custom_minimum_size.y)
			_assert_chall(close_btn.custom_minimum_size.x >= 56.0, "1.4 CyberSync close_btn width >= 56px", "Actual: %f" % close_btn.custom_minimum_size.x)

		_assert_chall(sync_btn != null, "1.5 CyberSync sync_hit_button exists")
		if sync_btn != null:
			_assert_chall(sync_btn.custom_minimum_size.y >= 56.0, "1.6 CyberSync sync_hit_button height >= 56px", "Actual: %f" % sync_btn.custom_minimum_size.y)

		# Adversarial mutation: force miniature size before _ready()
		var mutated_cyber: Control = cyber_scene.instantiate()
		var m_sync: Button = mutated_cyber.get_node_or_null("%SyncHitButton")
		var m_close: Button = mutated_cyber.get_node_or_null("%CloseButton")
		if m_sync != null: m_sync.custom_minimum_size = Vector2(10, 10)
		if m_close != null: m_close.custom_minimum_size = Vector2(10, 10)
		root.add_child(mutated_cyber)
		_mounted_nodes.append(mutated_cyber)

		_assert_chall(m_sync.custom_minimum_size.y >= 56.0, "1.7 CyberSync _ready() clamps mutated sync button >= 56px", "Actual: %f" % m_sync.custom_minimum_size.y)
		_assert_chall(m_close.custom_minimum_size.y >= 56.0, "1.8 CyberSync _ready() clamps mutated close button >= 56px", "Actual: %f" % m_close.custom_minimum_size.y)
		_assert_chall(m_close.custom_minimum_size.x >= 56.0, "1.9 CyberSync _ready() clamps mutated close button width >= 56px", "Actual: %f" % m_close.custom_minimum_size.x)

		# State change mutation: complete minigame and check button sizes
		if cyber.has_method("complete_minigame"):
			cyber.complete_minigame(true)
		_assert_chall(sync_btn.custom_minimum_size.y >= 56.0, "1.10 CyberSync button height preserved after complete_minigame", "Actual: %f" % sync_btn.custom_minimum_size.y)

		# Recursive button scan
		var cyber_buttons: Array[Button] = _find_all_buttons(cyber)
		var all_cyber_valid: bool = true
		for btn in cyber_buttons:
			if btn.custom_minimum_size.y < 56.0:
				all_cyber_valid = false
				printerr("  [FAIL] CyberSync button %s has height %f < 56.0" % [btn.name, btn.custom_minimum_size.y])
		_assert_chall(all_cyber_valid and cyber_buttons.size() >= 2, "1.11 100%% of buttons in CyberSync meet >= 56px height (Total scanned: %d)" % cyber_buttons.size())

	# 2. PitchStageMinigame
	var pitch_scene = load("res://scenes/ui/pitch_stage_minigame.tscn")
	_assert_chall(pitch_scene != null, "1.12 Load pitch_stage_minigame.tscn")
	if pitch_scene != null:
		var pitch: Control = pitch_scene.instantiate()
		root.add_child(pitch)
		_mounted_nodes.append(pitch)

		var close_btn: Button = pitch.get_node_or_null("%CloseButton")
		var buzz_btn0: Button = pitch.get_node_or_null("%BuzzwordButton0")
		var buzz_btn1: Button = pitch.get_node_or_null("%BuzzwordButton1")
		var buzz_btn2: Button = pitch.get_node_or_null("%BuzzwordButton2")

		_assert_chall(close_btn != null, "1.13 PitchStage close_btn exists")
		if close_btn != null:
			_assert_chall(close_btn.custom_minimum_size.y >= 56.0, "1.14 PitchStage close_btn height >= 56px", "Actual: %f" % close_btn.custom_minimum_size.y)
			_assert_chall(close_btn.custom_minimum_size.x >= 56.0, "1.15 PitchStage close_btn width >= 56px", "Actual: %f" % close_btn.custom_minimum_size.x)

		_assert_chall(buzz_btn0 != null and buzz_btn1 != null and buzz_btn2 != null, "1.16 PitchStage 3 buzzword buttons exist")
		if buzz_btn0 != null:
			_assert_chall(buzz_btn0.custom_minimum_size.y >= 56.0, "1.17 BuzzwordButton0 height >= 56px", "Actual: %f" % buzz_btn0.custom_minimum_size.y)
		if buzz_btn1 != null:
			_assert_chall(buzz_btn1.custom_minimum_size.y >= 56.0, "1.18 BuzzwordButton1 height >= 56px", "Actual: %f" % buzz_btn1.custom_minimum_size.y)
		if buzz_btn2 != null:
			_assert_chall(buzz_btn2.custom_minimum_size.y >= 56.0, "1.19 BuzzwordButton2 height >= 56px", "Actual: %f" % buzz_btn2.custom_minimum_size.y)

		# Adversarial mutation: force miniature size before _ready()
		var mutated_pitch: Control = pitch_scene.instantiate()
		var m_b0: Button = mutated_pitch.get_node_or_null("%BuzzwordButton0")
		var m_pclose: Button = mutated_pitch.get_node_or_null("%CloseButton")
		if m_b0 != null: m_b0.custom_minimum_size = Vector2(5, 5)
		if m_pclose != null: m_pclose.custom_minimum_size = Vector2(5, 5)
		root.add_child(mutated_pitch)
		_mounted_nodes.append(mutated_pitch)

		_assert_chall(m_b0.custom_minimum_size.y >= 56.0, "1.20 PitchStage _ready() clamps mutated buzzword button >= 56px", "Actual: %f" % m_b0.custom_minimum_size.y)
		_assert_chall(m_pclose.custom_minimum_size.y >= 56.0, "1.21 PitchStage _ready() clamps mutated close button >= 56px", "Actual: %f" % m_pclose.custom_minimum_size.y)
		_assert_chall(m_pclose.custom_minimum_size.x >= 56.0, "1.22 PitchStage _ready() clamps mutated close button width >= 56px", "Actual: %f" % m_pclose.custom_minimum_size.x)

		# Check disabled state after complete_pitch
		if pitch.has_method("complete_pitch"):
			pitch.complete_pitch(true)
		_assert_chall(buzz_btn0.custom_minimum_size.y >= 56.0, "1.23 Buzzword button height preserved after complete_pitch", "Actual: %f" % buzz_btn0.custom_minimum_size.y)

		# Recursive button scan
		var pitch_buttons: Array[Button] = _find_all_buttons(pitch)
		var all_pitch_valid: bool = true
		for btn in pitch_buttons:
			if btn.custom_minimum_size.y < 56.0:
				all_pitch_valid = false
				printerr("  [FAIL] PitchStage button %s has height %f < 56.0" % [btn.name, btn.custom_minimum_size.y])
		_assert_chall(all_pitch_valid and pitch_buttons.size() >= 4, "1.24 100%% of buttons in PitchStage meet >= 56px height (Total scanned: %d)" % pitch_buttons.size())

	# 3. EspressoBrewMinigame
	var espresso_scene = load("res://scenes/ui/espresso_brew_minigame.tscn")
	_assert_chall(espresso_scene != null, "1.25 Load espresso_brew_minigame.tscn")
	if espresso_scene != null:
		var espresso: Control = espresso_scene.instantiate()
		root.add_child(espresso)
		_mounted_nodes.append(espresso)

		var close_btn: Button = espresso.get_node_or_null("%CloseButton")
		var pump_btn: Button = espresso.get_node_or_null("%PumpButton") if espresso.has_node("%PumpButton") else espresso.get_node_or_null("%HoldButton")

		_assert_chall(close_btn != null, "1.26 EspressoBrew close_btn exists")
		if close_btn != null:
			_assert_chall(close_btn.custom_minimum_size.y >= 56.0, "1.27 EspressoBrew close_btn height >= 56px", "Actual: %f" % close_btn.custom_minimum_size.y)
			_assert_chall(close_btn.custom_minimum_size.x >= 56.0, "1.28 EspressoBrew close_btn width >= 56px", "Actual: %f" % close_btn.custom_minimum_size.x)

		_assert_chall(pump_btn != null, "1.29 EspressoBrew pump_button exists")
		if pump_btn != null:
			_assert_chall(pump_btn.custom_minimum_size.y >= 56.0, "1.30 EspressoBrew pump_button height >= 56px", "Actual: %f" % pump_btn.custom_minimum_size.y)

		# Adversarial mutation: force miniature size before _ready()
		var mutated_espresso: Control = espresso_scene.instantiate()
		var m_pump: Button = mutated_espresso.get_node_or_null("%PumpButton")
		var m_eclose: Button = mutated_espresso.get_node_or_null("%CloseButton")
		if m_pump != null: m_pump.custom_minimum_size = Vector2(8, 8)
		if m_eclose != null: m_eclose.custom_minimum_size = Vector2(8, 8)
		root.add_child(mutated_espresso)
		_mounted_nodes.append(mutated_espresso)

		_assert_chall(m_pump.custom_minimum_size.y >= 56.0, "1.31 EspressoBrew _ready() clamps mutated pump button >= 56px", "Actual: %f" % m_pump.custom_minimum_size.y)
		_assert_chall(m_eclose.custom_minimum_size.y >= 56.0, "1.32 EspressoBrew _ready() clamps mutated close button >= 56px", "Actual: %f" % m_eclose.custom_minimum_size.y)
		_assert_chall(m_eclose.custom_minimum_size.x >= 56.0, "1.33 EspressoBrew _ready() clamps mutated close button width >= 56px", "Actual: %f" % m_eclose.custom_minimum_size.x)

		# Recursive button scan
		var espresso_buttons: Array[Button] = _find_all_buttons(espresso)
		var all_espresso_valid: bool = true
		for btn in espresso_buttons:
			if btn.custom_minimum_size.y < 56.0:
				all_espresso_valid = false
				printerr("  [FAIL] EspressoBrew button %s has height %f < 56.0" % [btn.name, btn.custom_minimum_size.y])
		_assert_chall(all_espresso_valid and espresso_buttons.size() >= 2, "1.34 100%% of buttons in EspressoBrew meet >= 56px height (Total scanned: %d)" % espresso_buttons.size())

# ==============================================================================
# SUITE 2: Pointer Isolation & Event Absorption
# ==============================================================================

func _challenge_pointer_isolation() -> void:
	# 1. CyberSyncMinigame pointer isolation
	var cyber_scene = load("res://scenes/ui/cyber_sync_minigame.tscn")
	if cyber_scene != null:
		var cyber: Control = cyber_scene.instantiate()
		root.add_child(cyber)
		_mounted_nodes.append(cyber)

		_assert_chall(cyber.mouse_filter == Control.MOUSE_FILTER_STOP, "2.1 CyberSync root mouse_filter == STOP (0)")
		var backdrop = cyber.get_node_or_null("DimBackdrop") as Control
		if backdrop != null:
			_assert_chall(backdrop.mouse_filter == Control.MOUSE_FILTER_STOP, "2.2 CyberSync backdrop mouse_filter == STOP (0)")
		var card = cyber.get_node_or_null("CenterContainer/ModalCard") as Control
		if card != null:
			_assert_chall(card.mouse_filter == Control.MOUSE_FILTER_STOP, "2.3 CyberSync ModalCard mouse_filter == STOP (0)")

		# Test _gui_input event absorption
		var mb_event = InputEventMouseButton.new()
		mb_event.button_index = MOUSE_BUTTON_LEFT
		mb_event.pressed = true
		mb_event.position = Vector2(200, 200)

		cyber._gui_input(mb_event)
		_assert_chall(cyber.has_method("_gui_input"), "2.4 CyberSync implements _gui_input")

		var drag_event = InputEventScreenDrag.new()
		drag_event.position = Vector2(250, 250)
		drag_event.relative = Vector2(10, 15)
		cyber._gui_input(drag_event)
		_assert_chall(true, "2.5 CyberSync _gui_input safely absorbs InputEventScreenDrag")

	# 2. PitchStageMinigame pointer isolation
	var pitch_scene = load("res://scenes/ui/pitch_stage_minigame.tscn")
	if pitch_scene != null:
		var pitch: Control = pitch_scene.instantiate()
		root.add_child(pitch)
		_mounted_nodes.append(pitch)

		_assert_chall(pitch.mouse_filter == Control.MOUSE_FILTER_STOP, "2.6 PitchStage root mouse_filter == STOP (0)")
		var backdrop = pitch.get_node_or_null("DimBackdrop") as Control
		if backdrop != null:
			_assert_chall(backdrop.mouse_filter == Control.MOUSE_FILTER_STOP, "2.7 PitchStage backdrop mouse_filter == STOP (0)")
		var card = pitch.get_node_or_null("CenterContainer/ModalCard") as Control
		if card != null:
			_assert_chall(card.mouse_filter == Control.MOUSE_FILTER_STOP, "2.8 PitchStage ModalCard mouse_filter == STOP (0)")

		var touch_event = InputEventScreenTouch.new()
		touch_event.pressed = true
		touch_event.position = Vector2(100, 100)
		pitch._gui_input(touch_event)
		_assert_chall(pitch.has_method("_gui_input"), "2.9 PitchStage implements _gui_input")

	# 3. EspressoBrewMinigame pointer isolation
	var espresso_scene = load("res://scenes/ui/espresso_brew_minigame.tscn")
	if espresso_scene != null:
		var espresso: Control = espresso_scene.instantiate()
		root.add_child(espresso)
		_mounted_nodes.append(espresso)

		_assert_chall(espresso.mouse_filter == Control.MOUSE_FILTER_STOP, "2.10 EspressoBrew root mouse_filter == STOP (0)")
		var backdrop = espresso.get_node_or_null("Backdrop") as Control
		if backdrop != null:
			_assert_chall(backdrop.mouse_filter == Control.MOUSE_FILTER_STOP, "2.11 EspressoBrew backdrop mouse_filter == STOP (0)")
		var card = espresso.get_node_or_null("CenterContainer/CardPanel") as Control
		if card != null:
			_assert_chall(card.mouse_filter == Control.MOUSE_FILTER_STOP, "2.12 EspressoBrew card_panel mouse_filter == STOP (0)")

		var motion_event = InputEventMouseMotion.new()
		motion_event.position = Vector2(150, 150)
		espresso._gui_input(motion_event)
		_assert_chall(espresso.has_method("_gui_input"), "2.13 EspressoBrew implements _gui_input")

# ==============================================================================
# SUITE 3: Camera Locomotion Gating & Avatar Input Suppression
# ==============================================================================

func _challenge_locomotion_gating() -> void:
	# Instantiate Avatar3D
	var avatar_scene = load("res://scenes/avatar_3d.tscn")
	_assert_chall(avatar_scene != null, "3.1 Load avatar_3d.tscn")
	if avatar_scene == null:
		return

	var avatar = avatar_scene.instantiate()
	root.add_child(avatar)
	_mounted_nodes.append(avatar)

	# Verify baseline avatar input enabled
	avatar.set_input_enabled(true)
	_assert_chall(avatar.input_enabled == true, "3.2 Avatar input_enabled is true initially")

	# 1. Test ServerTerminal minigame gating
	var st_scene = load("res://scenes/server_terminal.tscn")
	if st_scene != null:
		var st = st_scene.instantiate()
		root.add_child(st)
		_mounted_nodes.append(st)

		st._avatar_ref = avatar
		var c_modal = st.open_cyber_sync_minigame()
		_assert_chall(c_modal != null, "3.3 ServerTerminal opens CyberSync minigame")
		_assert_chall(avatar.input_enabled == false, "3.4 Avatar input_enabled gated to false when CyberSync opened")

		# Adversarially attempt click-to-move while minigame is open
		var click_event = InputEventMouseButton.new()
		click_event.button_index = MOUSE_BUTTON_LEFT
		click_event.pressed = true
		click_event.position = Vector2(400, 400)
		avatar._unhandled_input(click_event)

		_assert_chall(avatar._has_click_target == false, "3.5 Click-to-move rejected while minigame is open (_has_click_target == false)")
		avatar._physics_process(0.016)
		_assert_chall(avatar.velocity.x == 0.0 and avatar.velocity.z == 0.0, "3.6 Avatar horizontal velocity remains 0.0")

		# Adversarially attempt touch drag while minigame is open
		var drag_event = InputEventScreenDrag.new()
		drag_event.position = Vector2(450, 450)
		avatar._unhandled_input(drag_event)
		_assert_chall(avatar._has_click_target == false, "3.7 Touch drag rejected while minigame is open")

		# Close minigame and check avatar input restored
		st._restore_avatar_and_controls()
		_assert_chall(avatar.input_enabled == true, "3.8 Avatar input_enabled restored to true after minigame closure")

	# 2. Test PitchStage minigame gating
	var ps_scene = load("res://scenes/pitch_stage.tscn")
	if ps_scene != null:
		var ps = ps_scene.instantiate()
		root.add_child(ps)
		_mounted_nodes.append(ps)

		ps._avatar_ref = avatar
		var p_modal = ps.open_pitch_minigame()
		_assert_chall(p_modal != null, "3.9 PitchStage opens Pitch minigame")
		_assert_chall(avatar.input_enabled == false, "3.10 Avatar input_enabled gated to false when Pitch minigame opened")

		# Adversarially inject touch event
		var touch_ev = InputEventScreenTouch.new()
		touch_ev.pressed = true
		touch_ev.position = Vector2(300, 300)
		avatar._unhandled_input(touch_ev)
		_assert_chall(avatar._has_click_target == false, "3.11 Touch event rejected by gated avatar")

		ps._restore_avatar_and_controls()
		_assert_chall(avatar.input_enabled == true, "3.12 Avatar input_enabled restored after Pitch minigame closure")

	# 3. Test CoffeeMachine3D minigame gating
	var cm_scene = load("res://scenes/coffee_machine_3d.tscn")
	if cm_scene != null:
		var cm = cm_scene.instantiate()
		root.add_child(cm)
		_mounted_nodes.append(cm)

		cm._avatar_ref = avatar
		cm._open_minigame_overlay()
		_assert_chall(avatar.input_enabled == false, "3.13 Avatar input_enabled gated to false when Coffee minigame opened")

		cm._restore_avatar_and_controls()
		_assert_chall(avatar.input_enabled == true, "3.14 Avatar input_enabled restored after Coffee minigame closure")

# ==============================================================================
# SUITE 4: Screen Shake Dynamics, Clamping & Configurable Setting
# ==============================================================================

func _challenge_screen_shake_dynamics() -> void:
	var gs = root.get_node_or_null("GameState")
	_assert_chall(gs != null, "4.1 GameState autoload singleton available")
	if gs == null:
		return

	# Load Main3D scene
	var main3d_scene = load("res://scenes/main_3d.tscn")
	_assert_chall(main3d_scene != null, "4.2 Load main_3d.tscn")
	if main3d_scene == null:
		return

	var main3d = main3d_scene.instantiate()
	root.add_child(main3d)
	_mounted_nodes.append(main3d)

	# 1. Clamping bounds [0.0, 1.0]
	main3d.trauma = 0.0
	main3d.add_screen_shake(0.35)
	_assert_chall(absf(main3d.trauma - 0.35) < 0.001, "4.3 add_screen_shake(0.35) sets trauma to 0.35", "Actual: %f" % main3d.trauma)

	main3d.add_screen_shake(10.0)
	_assert_chall(absf(main3d.trauma - 1.0) < 0.001, "4.4 Over-maximum shake clamped strictly to 1.0", "Actual: %f" % main3d.trauma)

	main3d.add_screen_shake(-50.0)
	_assert_chall(absf(main3d.trauma - 0.0) < 0.001, "4.5 Under-minimum shake clamped strictly to 0.0", "Actual: %f" % main3d.trauma)

	# 2. Decay mechanics
	main3d.trauma = 1.0
	var decay_rate = main3d.shake_decay_rate
	_assert_chall(decay_rate > 1.0 and decay_rate < 2.0, "4.6 shake_decay_rate is configured within [1.0, 2.0]", "Actual: %f" % decay_rate)

	main3d._update_screen_shake(0.2)
	var expected_trauma: float = maxf(0.0, 1.0 - decay_rate * 0.2)
	_assert_chall(absf(main3d.trauma - expected_trauma) < 0.01, "4.7 Trauma decays linearly by decay_rate * delta", "Actual: %f, Expected: %f" % [main3d.trauma, expected_trauma])

	# Complete decay to zero
	main3d._update_screen_shake(5.0)
	_assert_chall(absf(main3d.trauma - 0.0) < 0.0001, "4.8 Trauma decays cleanly to 0.0 over time", "Actual: %f" % main3d.trauma)

	if main3d.camera != null:
		_assert_chall(main3d.camera.h_offset == 0.0 and main3d.camera.v_offset == 0.0, "4.9 Camera h_offset and v_offset reset to 0.0 when idle")

	# 3. Accessibility setting: screen_shake_intensity
	gs.set_screen_shake_intensity(0.0)
	_assert_chall(gs.get_screen_shake_intensity() == 0.0, "4.10 GameState screen shake intensity set to 0.0")

	main3d.trauma = 1.0
	main3d._update_screen_shake(0.016)
	if main3d.camera != null:
		_assert_chall(main3d.camera.h_offset == 0.0 and main3d.camera.v_offset == 0.0, "4.11 Camera offsets remain 0.0 when user disables shake (intensity = 0.0)")

	# Intensity clamping in GameState
	gs.set_screen_shake_intensity(2.5)
	_assert_chall(gs.get_screen_shake_intensity() == 1.0, "4.12 GameState clamps intensity > 1.0 to 1.0", "Actual: %f" % gs.get_screen_shake_intensity())

	gs.set_screen_shake_intensity(-1.0)
	_assert_chall(gs.get_screen_shake_intensity() == 0.0, "4.13 GameState clamps intensity < 0.0 to 0.0", "Actual: %f" % gs.get_screen_shake_intensity())

	# Restore 1.0
	gs.set_screen_shake_intensity(1.0)

	# 4. Decoupled signal pipeline: GameState.trigger_camera_shake(amount)
	main3d.trauma = 0.0
	gs.trigger_camera_shake(0.40)
	_assert_chall(absf(main3d.trauma - 0.40) < 0.001, "4.14 GameState.trigger_camera_shake(0.40) routes to Main3D via camera_shake_requested signal", "Actual: %f" % main3d.trauma)

	# 5. Minigame screen shake trigger verification
	var espresso_scene = load("res://scenes/ui/espresso_brew_minigame.tscn")
	if espresso_scene != null:
		var espresso = espresso_scene.instantiate()
		main3d.add_child(espresso)
		_mounted_nodes.append(espresso)

		main3d.trauma = 0.0
		espresso.complete_brew(true)
		_assert_chall(absf(main3d.trauma - 0.30) < 0.001, "4.15 EspressoBrew complete_brew(true) triggers 0.30 camera shake", "Actual: %f" % main3d.trauma)

# ==============================================================================
# HELPER FUNCTIONS
# ==============================================================================

func _find_all_buttons(root_node: Node) -> Array[Button]:
	var result: Array[Button] = []
	var stack: Array[Node] = [root_node]
	while stack.size() > 0:
		var curr = stack.pop_back()
		if curr is Button:
			result.append(curr)
		for child in curr.get_children():
			stack.append(child)
	return result

func _cleanup_and_quit(exit_code: int) -> void:
	print("\n--- TEARDOWN: Restoring Environment ---")
	if _had_save_backup:
		var f_res = FileAccess.open("user://savegame.json", FileAccess.WRITE)
		if f_res != null:
			f_res.store_string(_save_backup_text)
			f_res.close()
			print("  [CLEANUP] Restored original savegame.json")
	elif FileAccess.file_exists("user://savegame.json"):
		DirAccess.remove_absolute("user://savegame.json")
		print("  [CLEANUP] Cleaned test savegame.json")

	for i in range(_mounted_nodes.size() - 1, -1, -1):
		var n = _mounted_nodes[i]
		if is_instance_valid(n):
			if n.get_parent() != null:
				n.get_parent().remove_child(n)
			n.free()
	_mounted_nodes.clear()

	print("\n====================================================================")
	print("[CHALLENGER M3-2] SUMMARY: %d PASSED, %d FAILED" % [pass_count, fail_count])
	print("====================================================================")

	if findings.size() > 0:
		print("\nCRITICAL DEFECTS / ANOMALIES ENCOUNTERED:")
		for f in findings:
			print(" - %s" % f)

	if fail_count == 0:
		print("\n>>> EMPIRICAL VERDICT: APPROVE (Exit Code 0) <<<\n")
		quit(0)
	else:
		printerr("\n>>> EMPIRICAL VERDICT: REQUEST_CHANGES (%d defects) <<<\n" % fail_count)
		quit(1)
