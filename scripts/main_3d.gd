extends Node3D
class_name Main3D

## Master 3D World Controller for IdleArcade (Phase 4).
## Orchestrates isometric camera tracking, campus environment lifecycle,
## QuickHUD updates, and seamless toggle between 3D navigation and 2D idle meta HUD.

@export var camera_follow_speed: float = 8.0
@export var camera_distance: float = 18.0
@export var camera_pitch_deg: float = -48.0
@export var camera_yaw_deg: float = 45.0
@export var use_orthogonal_camera: bool = false
@export var orthogonal_size: float = 14.0
@export var perspective_fov: float = 40.0

@onready var camera_rig: Node3D = get_node_or_null("CameraRig")
@onready var camera: Camera3D = get_node_or_null("CameraRig/Camera3D")
@onready var avatar: CharacterBody3D = get_node_or_null("Avatar3D")
@onready var quick_hud_layer: CanvasLayer = get_node_or_null("QuickHUDLayer")
@onready var hud_overlay_layer: CanvasLayer = get_node_or_null("HUDOverlayLayer")
@onready var quick_energy_label: Label = get_node_or_null("%QuickEnergyLabel")
@onready var quick_rps_label: Label = get_node_or_null("%QuickRPSLabel")
@onready var toggle_overlay_button: Button = get_node_or_null("%ToggleOverlayButton")
@onready var exit_to_2d_button: Button = get_node_or_null("%ExitTo2DButton")
@onready var close_overlay_button: Button = get_node_or_null("%CloseOverlayButton")
@onready var hud_instance: Control = get_node_or_null("HUDOverlayLayer/OverlayContainer/HUD")
@onready var dialogue_panel: Control = get_node_or_null("DialogueLayer/DialoguePanel")
@onready var quest_tracker: Control = get_node_or_null("QuestLayer/QuestTracker")
@onready var touch_controls_layer: CanvasLayer = get_node_or_null("TouchControlsLayer")
@onready var touch_controls: Control = get_node_or_null("TouchControlsLayer/TouchControls")
@onready var tech_lab_terminal: Node3D = get_node_or_null("TechLabTerminal")
@onready var delivery_drone: CharacterBody3D = get_node_or_null("DeliveryDrone3D")
@onready var server_overclock_glow: OmniLight3D = get_node_or_null("CampusLevel/ServerOverclockGlow")
@onready var server_terminal: Node3D = get_node_or_null("ServerTerminal")
@onready var pitch_stage: Node3D = get_node_or_null("PitchStage")
@onready var day_night_cycle: DayNightCycle = get_node_or_null("DayNightCycle")
@onready var screen_transition: ScreenTransition = get_node_or_null("ScreenTransition")
@onready var syndicate_hq: Node3D = get_node_or_null("SyndicateHQ3D")

var _overlay_open: bool = false
var _overclock_time: float = 0.0

# Phase 10 Camera Screen-Shake Controller
var trauma: float = 0.0
var shake_frequency: float = 28.0
var shake_decay_rate: float = 1.4
var max_shake_h: float = 0.45
var max_shake_v: float = 0.35
var _shake_time: float = 0.0
var _last_frenzy_active: bool = false

func _ready() -> void:
	print("[Main3D] Initializing 3D Campus World...")
	
	# Load persisted GameState if available
	var gs = get_node_or_null("/root/GameState")
	if gs != null and gs.has_method("load_from_disk"):
		gs.load_from_disk()
	
	_setup_camera_rig()
	_setup_hud_overlay()
	_setup_touch_controls()
	_setup_tech_tree_integrations()
	_setup_day_night_cycle()
	_connect_game_state_signals()
	_update_quick_hud()
	
	# Snap camera to avatar immediately on spawn
	snap_camera_to_avatar()
	
	# Start ambient Lo-Fi BGM for campus exploration
	var am = get_node_or_null("/root/AudioManager")
	if am != null and am.has_method("start_ambient_bgm"):
		am.start_ambient_bgm()

func _process(delta: float) -> void:
	_update_screen_shake(delta)

func _physics_process(delta: float) -> void:
	_update_camera_tracking(delta)
	_update_overclock_glow_modulation(delta)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		if event.keycode == KEY_TAB or event.keycode == KEY_M:
			toggle_hud_overlay()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE:
			if dialogue_panel != null and dialogue_panel.visible:
				if dialogue_panel.has_method("close_dialogue"):
					dialogue_panel.close_dialogue()
				else:
					dialogue_panel.visible = false
				get_viewport().set_input_as_handled()
			elif is_hud_overlay_open():
				if hud_instance != null and hud_instance.has_method("has_active_modal") and hud_instance.has_active_modal():
					hud_instance.dismiss_active_modal()
				else:
					close_hud_overlay()
				get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		var gs = get_node_or_null("/root/GameState")
		if gs != null and gs.has_method("save_to_disk"):
			print("[Main3D] Suspending / Exiting - saving state.")
			gs.save_to_disk()

# --- Camera Rig Mechanics ---

func _setup_camera_rig() -> void:
	if camera_rig == null:
		return
		
	# Fixed isometric orientation
	camera_rig.rotation_degrees = Vector3(camera_pitch_deg, camera_yaw_deg, 0.0)
	
	if camera != null:
		# Offset child camera along local Z
		camera.position = Vector3(0.0, 0.0, camera_distance)
		camera.rotation = Vector3.ZERO
		
		if use_orthogonal_camera:
			camera.projection = Camera3D.PROJECTION_ORTHOGONAL
			camera.size = orthogonal_size
		else:
			camera.projection = Camera3D.PROJECTION_PERSPECTIVE
			camera.fov = perspective_fov
			
		camera.near = 0.5
		camera.far = 150.0

func _update_camera_tracking(delta: float) -> void:
	if camera_rig == null or not is_instance_valid(avatar):
		return
	
	var target_pos: Vector3 = avatar.global_position
	var t: float = clampf(delta * camera_follow_speed, 0.0, 1.0)
	camera_rig.global_position = camera_rig.global_position.lerp(target_pos, t)

## Instantly aligns the camera rig with the avatar without interpolation lag
func snap_camera_to_avatar() -> void:
	if camera_rig != null and is_instance_valid(avatar):
		camera_rig.global_position = avatar.global_position

# --- Phase 10 Procedural Screen-Shake Controller ---

## Adds trauma for procedural camera screen shake (clamped in [0.0, 1.0])
func add_screen_shake(amount: float) -> void:
	trauma = clampf(trauma + amount, 0.0, 1.0)

## Centralized alias for camera screen shake supporting alternative naming conventions
func trigger_camera_shake(intensity: float) -> void:
	add_screen_shake(intensity)

## Computes non-linear trauma decay and camera h_offset / v_offset oscillation
func _update_screen_shake(delta: float) -> void:
	if camera == null:
		camera = get_node_or_null("CameraRig/Camera3D")
	
	# Trauma decay: decay rate ~1.4
	trauma = maxf(0.0, trauma - shake_decay_rate * delta)
	
	# User intensity setting from GameState
	var user_intensity: float = 1.0
	var gs = get_node_or_null("/root/GameState")
	if gs != null and "screen_shake_intensity" in gs:
		user_intensity = float(gs.screen_shake_intensity)
	elif gs != null and gs.has_method("get_screen_shake_intensity"):
		user_intensity = gs.get_screen_shake_intensity()
	
	# Effective shake calculation (trauma^2 * user_intensity)
	var shake: float = trauma * trauma * user_intensity
	
	if shake > 0.001 and camera != null:
		_shake_time += delta * shake_frequency
		var noise_h: float = sin(_shake_time * 1.0) * cos(_shake_time * 0.73)
		var noise_v: float = cos(_shake_time * 1.17) * sin(_shake_time * 0.89)
		camera.h_offset = noise_h * max_shake_h * shake
		camera.v_offset = noise_v * max_shake_v * shake
	else:
		if camera != null:
			camera.h_offset = 0.0
			camera.v_offset = 0.0

# --- HUD Overlay & Meta Progression Mechanics ---

func _setup_hud_overlay() -> void:
	if hud_overlay_layer != null:
		hud_overlay_layer.visible = false
	_overlay_open = false
		
	if toggle_overlay_button != null:
		toggle_overlay_button.pressed.connect(toggle_hud_overlay)
		
	if close_overlay_button != null:
		close_overlay_button.pressed.connect(close_hud_overlay)
		
	if exit_to_2d_button != null:
		exit_to_2d_button.pressed.connect(_on_exit_to_2d_pressed)

func _setup_touch_controls() -> void:
	if touch_controls != null and touch_controls.has_signal("overlay_toggle_requested"):
		if not touch_controls.overlay_toggle_requested.is_connected(toggle_hud_overlay):
			touch_controls.overlay_toggle_requested.connect(toggle_hud_overlay)

func _on_exit_to_2d_pressed() -> void:
	var gs = get_node_or_null("/root/GameState")
	if gs != null and gs.has_method("save_to_disk"):
		gs.save_to_disk()
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func toggle_hud_overlay() -> void:
	if is_hud_overlay_open():
		close_hud_overlay()
	else:
		open_hud_overlay()

func open_hud_overlay() -> void:
	if screen_transition != null and not _overlay_open and DisplayServer.get_name() != "headless":
		if screen_transition.has_method("is_transitioning") and screen_transition.is_transitioning():
			return
		screen_transition.transition_wipe(func():
			_apply_open_hud_overlay()
		)
	else:
		_apply_open_hud_overlay()

func _apply_open_hud_overlay() -> void:
	if dialogue_panel != null and dialogue_panel.visible and dialogue_panel.has_method("close_dialogue"):
		dialogue_panel.close_dialogue()
	_overlay_open = true
	if hud_overlay_layer != null:
		hud_overlay_layer.visible = true
	if is_instance_valid(avatar) and avatar.has_method("set_input_enabled"):
		avatar.set_input_enabled(false)
	if is_instance_valid(touch_controls):
		if touch_controls.has_method("fade_out_controls"):
			touch_controls.fade_out_controls()
		elif touch_controls.has_method("reset_controls"):
			touch_controls.reset_controls()
	if hud_instance != null and hud_instance.has_method("_refresh_all_ui"):
		hud_instance.call("_refresh_all_ui")
	_update_quick_hud()

func close_hud_overlay() -> void:
	if screen_transition != null and _overlay_open and DisplayServer.get_name() != "headless":
		if screen_transition.has_method("is_transitioning") and screen_transition.is_transitioning():
			return
		screen_transition.transition_wipe(func():
			_apply_close_hud_overlay()
		)
	else:
		_apply_close_hud_overlay()

func _apply_close_hud_overlay() -> void:
	_overlay_open = false
	if hud_overlay_layer != null:
		hud_overlay_layer.visible = false
	if is_instance_valid(avatar) and avatar.has_method("set_input_enabled"):
		avatar.set_input_enabled(true)
	if is_instance_valid(touch_controls) and touch_controls.has_method("fade_in_controls"):
		touch_controls.fade_in_controls()
	_update_quick_hud()

func is_hud_overlay_open() -> bool:
	if hud_overlay_layer != null:
		return hud_overlay_layer.visible
	return _overlay_open

## Centralized hook for stations or modals to pause campus exploration
func pause_exploration_for_modal(_modal_node: Node = null) -> void:
	if is_instance_valid(avatar) and avatar.has_method("set_input_enabled"):
		avatar.set_input_enabled(false)
	if is_instance_valid(touch_controls):
		if touch_controls.has_method("fade_out_controls"):
			touch_controls.fade_out_controls()
		elif touch_controls.has_method("reset_controls"):
			touch_controls.reset_controls()

## Centralized hook for stations or modals to resume campus exploration
func resume_exploration_from_modal(_modal_node: Node = null) -> void:
	if is_instance_valid(avatar) and avatar.has_method("set_input_enabled"):
		avatar.set_input_enabled(true)
	if is_instance_valid(touch_controls) and touch_controls.has_method("fade_in_controls"):
		touch_controls.fade_in_controls()

## Returns or instantiates the dedicated CanvasLayer (Layer 9) for minigame overlays
func get_minigame_layer() -> CanvasLayer:
	var mg_layer = get_node_or_null("MinigameLayer") as CanvasLayer
	if mg_layer == null:
		mg_layer = CanvasLayer.new()
		mg_layer.name = "MinigameLayer"
		mg_layer.layer = 9
		add_child(mg_layer)
	return mg_layer

# --- QuickHUD Live Data Binding ---

func _connect_game_state_signals() -> void:
	var gs = get_node_or_null("/root/GameState")
	if gs == null:
		return
	if gs.has_signal("energy_changed"):
		gs.energy_changed.connect(_on_energy_changed)
	if gs.has_signal("rps_changed"):
		gs.rps_changed.connect(_on_rps_changed)
	if gs.has_signal("tech_researched"):
		gs.tech_researched.connect(_on_tech_researched)
	if gs.has_signal("frenzy_updated"):
		gs.frenzy_updated.connect(_on_frenzy_updated)
	if gs.has_signal("light_cycle_mode_changed"):
		gs.light_cycle_mode_changed.connect(_on_light_cycle_mode_changed)
	if gs.has_signal("camera_shake_requested") and not gs.camera_shake_requested.is_connected(add_screen_shake):
		gs.camera_shake_requested.connect(add_screen_shake)

func _setup_day_night_cycle() -> void:
	if day_night_cycle == null:
		day_night_cycle = get_node_or_null("DayNightCycle")
	if day_night_cycle != null:
		var gs = get_node_or_null("/root/GameState")
		if gs != null and gs.has_method("get_light_cycle_mode"):
			day_night_cycle.set_cycle_mode(gs.get_light_cycle_mode())

func _on_light_cycle_mode_changed(mode: String) -> void:
	if day_night_cycle != null and day_night_cycle.has_method("set_cycle_mode"):
		day_night_cycle.set_cycle_mode(mode)

func _on_frenzy_updated(arg1: Variant = 3.0, arg2: Variant = 100.0) -> void:
	var is_active: bool = false
	if typeof(arg1) == TYPE_BOOL:
		is_active = bool(arg1)
	elif typeof(arg1) in [TYPE_FLOAT, TYPE_INT]:
		var mult: float = float(arg1)
		var fill: float = float(arg2) if arg2 != null else 0.0
		if (fill >= 99.9 and mult > 1.0) or mult >= 3.0:
			is_active = true
		elif fill <= 0.01 and mult <= 1.0:
			is_active = false

	if is_active:
		if not _last_frenzy_active:
			_last_frenzy_active = true
			add_screen_shake(0.65)
	else:
		_last_frenzy_active = false

func _on_energy_changed(new_energy: float, _delta: float) -> void:
	var gs = get_node_or_null("/root/GameState")
	if quick_energy_label != null and gs != null and gs.has_method("format_number"):
		quick_energy_label.text = gs.format_number(new_energy) + " Users"

func _on_rps_changed(new_rps: float) -> void:
	var gs = get_node_or_null("/root/GameState")
	if quick_rps_label != null and gs != null and gs.has_method("format_number"):
		quick_rps_label.text = "+" + gs.format_number(new_rps) + "/s"

func _update_quick_hud() -> void:
	var gs = get_node_or_null("/root/GameState")
	if gs == null:
		return
	if quick_energy_label != null and gs.has_method("format_number"):
		quick_energy_label.text = gs.format_number(gs.energy) + " Users"
	if quick_rps_label != null and gs.has_method("format_number") and gs.has_method("get_effective_passive_rps"):
		quick_rps_label.text = "+" + gs.format_number(gs.get_effective_passive_rps()) + "/s"

# --- Tech Tree & Server Room Overclock Integration ---

func _setup_tech_tree_integrations() -> void:
	if server_overclock_glow == null:
		server_overclock_glow = find_child("ServerOverclockGlow", true, false)
	
	var gs = get_node_or_null("/root/GameState")
	if gs != null and gs.has_method("is_tech_researched"):
		if gs.is_tech_researched("tech_server_overclock"):
			_set_server_overclock_glow_active(true)
		else:
			_set_server_overclock_glow_active(false)

func _set_server_overclock_glow_active(active: bool) -> void:
	if server_overclock_glow == null:
		server_overclock_glow = find_child("ServerOverclockGlow", true, false)
	if server_overclock_glow != null:
		server_overclock_glow.light_energy = 1.8 if active else 0.0

func _activate_server_overclock_glow() -> void:
	if server_overclock_glow == null:
		server_overclock_glow = find_child("ServerOverclockGlow", true, false)
	if server_overclock_glow != null:
		var tween = create_tween()
		tween.tween_property(server_overclock_glow, "light_energy", 1.8, 1.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _update_overclock_glow_modulation(delta: float) -> void:
	if server_overclock_glow == null or server_overclock_glow.light_energy <= 0.01:
		return
	var gs = get_node_or_null("/root/GameState")
	if gs != null and gs.has_method("is_tech_researched") and gs.is_tech_researched("tech_server_overclock"):
		_overclock_time += delta
		server_overclock_glow.light_energy = 1.8 + sin(_overclock_time * 3.0) * 0.25

func is_server_overclock_glow_active() -> bool:
	if server_overclock_glow == null:
		server_overclock_glow = find_child("ServerOverclockGlow", true, false)
	return server_overclock_glow != null and server_overclock_glow.light_energy > 0.1

func _on_tech_researched(tech_id: String) -> void:
	if tech_id == "tech_server_overclock":
		_activate_server_overclock_glow()

func open_tech_tree() -> void:
	if hud_instance != null:
		if hud_instance.has_method("open_tech_tree_modal"):
			hud_instance.open_tech_tree_modal()
		elif ResourceLoader.exists("res://scenes/ui/tech_tree_modal.tscn"):
			var scene = load("res://scenes/ui/tech_tree_modal.tscn")
			if scene != null and hud_instance.has_method("open_modal"):
				hud_instance.open_modal(scene)
		elif not is_hud_overlay_open():
			open_hud_overlay()
	elif not is_hud_overlay_open():
		open_hud_overlay()

func open_syndicate_modal() -> void:
	if hud_instance != null:
		if hud_instance.has_method("open_syndicate_modal"):
			hud_instance.open_syndicate_modal()
		elif ResourceLoader.exists("res://scenes/ui/syndicate_modal.tscn"):
			var scene = load("res://scenes/ui/syndicate_modal.tscn")
			if scene != null and hud_instance.has_method("open_modal"):
				hud_instance.open_modal(scene)
		elif not is_hud_overlay_open():
			open_hud_overlay()
	elif not is_hud_overlay_open():
		open_hud_overlay()
