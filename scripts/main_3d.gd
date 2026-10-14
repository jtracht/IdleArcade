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
@onready var close_overlay_button: Button = get_node_or_null("%CloseOverlayButton")
@onready var hud_instance: Control = get_node_or_null("HUDOverlayLayer/OverlayContainer/HUD")
@onready var dialogue_panel: Control = get_node_or_null("DialogueLayer/DialoguePanel")
@onready var quest_tracker: Control = get_node_or_null("QuestLayer/QuestTracker")

var _overlay_open: bool = false

func _ready() -> void:
	print("[Main3D] Initializing 3D Campus World...")
	
	# Load persisted GameState if available
	var gs = get_node_or_null("/root/GameState")
	if gs != null and gs.has_method("load_from_disk"):
		gs.load_from_disk()
	
	_setup_camera_rig()
	_setup_hud_overlay()
	_connect_game_state_signals()
	_update_quick_hud()
	
	# Snap camera to avatar immediately on spawn
	snap_camera_to_avatar()

func _physics_process(delta: float) -> void:
	_update_camera_tracking(delta)

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

# --- HUD Overlay & Meta Progression Mechanics ---

func _setup_hud_overlay() -> void:
	if hud_overlay_layer != null:
		hud_overlay_layer.visible = false
	_overlay_open = false
		
	if toggle_overlay_button != null:
		toggle_overlay_button.pressed.connect(toggle_hud_overlay)
		
	if close_overlay_button != null:
		close_overlay_button.pressed.connect(close_hud_overlay)

func toggle_hud_overlay() -> void:
	if is_hud_overlay_open():
		close_hud_overlay()
	else:
		open_hud_overlay()

func open_hud_overlay() -> void:
	if dialogue_panel != null and dialogue_panel.visible and dialogue_panel.has_method("close_dialogue"):
		dialogue_panel.close_dialogue()
	_overlay_open = true
	if hud_overlay_layer != null:
		hud_overlay_layer.visible = true
	if is_instance_valid(avatar) and avatar.has_method("set_input_enabled"):
		avatar.set_input_enabled(false)
	if hud_instance != null and hud_instance.has_method("_refresh_all_ui"):
		hud_instance.call("_refresh_all_ui")
	_update_quick_hud()

func close_hud_overlay() -> void:
	_overlay_open = false
	if hud_overlay_layer != null:
		hud_overlay_layer.visible = false
	if is_instance_valid(avatar) and avatar.has_method("set_input_enabled"):
		avatar.set_input_enabled(true)
	_update_quick_hud()

func is_hud_overlay_open() -> bool:
	if hud_overlay_layer != null:
		return hud_overlay_layer.visible
	return _overlay_open

# --- QuickHUD Live Data Binding ---

func _connect_game_state_signals() -> void:
	var gs = get_node_or_null("/root/GameState")
	if gs == null:
		return
	if gs.has_signal("energy_changed"):
		gs.energy_changed.connect(_on_energy_changed)
	if gs.has_signal("rps_changed"):
		gs.rps_changed.connect(_on_rps_changed)

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
