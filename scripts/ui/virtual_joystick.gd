class_name VirtualJoystick
extends Control

## Dynamic Virtual Floating Touch-Joystick for Godot 4.3 Mobile & Isometric 3D navigation.
## Provides dynamic touch centering, radial clamping, deadzone filtering,
## camera-relative isometric 3D mapping, and zero-drift immediate halting.

# ------------------------------------------------------------------------------
# Signals
# ------------------------------------------------------------------------------

## Emitted whenever the joystick direction changes while active.
signal joystick_moved(direction_3d: Vector3, raw_vector_2d: Vector2)

## Emitted when the touch is released and the joystick resets to rest.
signal joystick_released()

# ------------------------------------------------------------------------------
# Exported Configuration
# ------------------------------------------------------------------------------

@export_group("Dimensions & Physics")
## Maximum throw distance of the inner stick knob in pixels.
@export var max_radius: float = 80.0

## Deadzone radius in pixels. Displacements below this yield zero output.
@export var deadzone_radius: float = 12.0

@export_group("Animation & Appearance")
## Duration in seconds for the stick knob to spring back to center on release.
@export var return_duration: float = 0.12

## Duration in seconds to fade opacity when released or activated.
@export var fade_duration: float = 0.20

## Resting opacity of the joystick when no finger is touching (0.0 = hidden).
@export var resting_opacity: float = 0.0

## Active opacity of the joystick while actively tracking touch.
@export var active_opacity: float = 1.0

@export_group("Activation Zone")
## Left screen half boundary coordinates (Portrait 720x1280).
@export var zone_min_x: float = 0.0
@export var zone_max_x: float = 360.0
@export var zone_min_y: float = 70.0
@export var zone_max_y: float = 1280.0

@export_group("Scene Node Bindings")
## Path to Avatar3D node for direct steering injection.
@export var avatar_path: NodePath

## Path to Camera3D node for dynamic yaw extraction.
@export var camera_path: NodePath

## Fallback isometric camera yaw angle in radians (45 degrees = PI / 4).
@export var default_camera_yaw: float = 0.785398163

# ------------------------------------------------------------------------------
# Internal State & Node References
# ------------------------------------------------------------------------------

var is_active: bool = false
var touch_finger_index: int = -1
var output_vector: Vector2 = Vector2.ZERO
var world_direction_3d: Vector3 = Vector3.ZERO
var base_center_position: Vector2 = Vector2.ZERO
var center_position: Vector2 = Vector2.ZERO

var avatar_node: Node = null
var camera_node: Camera3D = null
var _tween: Tween = null

@onready var base_ring: Control = get_node_or_null("BaseRing")
@onready var deadzone_ring: Control = get_node_or_null("BaseRing/DeadzoneRing")
@onready var stick_knob: Control = get_node_or_null("BaseRing/StickKnob")
@onready var knob_center_dot: Control = get_node_or_null("BaseRing/StickKnob/KnobCenterDot")

# ------------------------------------------------------------------------------
# Lifecycle Methods
# ------------------------------------------------------------------------------

func _ready() -> void:
	# Resolve node bindings
	if not avatar_path.is_empty():
		avatar_node = get_node_or_null(avatar_path)
	if avatar_node == null:
		avatar_node = _find_avatar_in_tree()

	if not camera_path.is_empty():
		camera_node = get_node_or_null(camera_path) as Camera3D
	if camera_node == null:
		camera_node = _find_camera_in_tree()

	# Initialize visual state to resting opacity
	if base_ring != null:
		base_ring.modulate.a = resting_opacity
		if stick_knob != null:
			stick_knob.position = Vector2.ZERO

	# Position base initially at lower-left default resting anchor
	base_center_position = Vector2(180.0, 1000.0)
	center_position = base_center_position
	if base_ring != null:
		base_ring.position = base_center_position

func _physics_process(_delta: float) -> void:
	# Continuous injection: prevent avatar friction deceleration while finger is held motionless
	if is_active and is_instance_valid(avatar_node) and world_direction_3d != Vector3.ZERO:
		if avatar_node.has_method("set_input_direction"):
			avatar_node.call("set_input_direction", world_direction_3d)

func _gui_input(event: InputEvent) -> void:
	if handle_touch_event(event):
		accept_event()

func _unhandled_input(event: InputEvent) -> void:
	# Fallback catch for mouse/touch when not captured by GUI layer
	if handle_touch_event(event):
		get_viewport().set_input_as_handled()

# ------------------------------------------------------------------------------
# Touch Handling & State Machine
# ------------------------------------------------------------------------------

## Primary entry point for consuming touch and mouse navigation events.
## Returns true if the event was processed and consumed by the joystick.
func handle_touch_event(event: InputEvent) -> bool:
	# Case 1: Screen Touch Down / Up
	if event is InputEventScreenTouch:
		if event.pressed:
			return _on_touch_down(event.position, event.index)
		elif event.index == touch_finger_index:
			return _on_touch_up()

	# Case 2: Screen Touch Drag
	elif event is InputEventScreenDrag:
		if event.index == touch_finger_index:
			return _on_touch_drag(event.position)

	# Case 3: Desktop Mouse Emulation (for desktop testing & headless)
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				return _on_touch_down(event.position, 0)
			elif touch_finger_index == 0:
				return _on_touch_up()

	elif event is InputEventMouseMotion:
		if touch_finger_index == 0:
			return _on_touch_drag(event.position)

	return false

func _on_touch_down(pos: Vector2, finger_idx: int) -> bool:
	if is_active and touch_finger_index != -1:
		return false # Multi-touch: ignore secondary fingers

	if not is_in_touch_zone(pos):
		return false

	# Bind finger and activate
	touch_finger_index = finger_idx
	is_active = true
	base_center_position = pos
	center_position = pos

	# Cancel any running release tween
	if _tween != null and _tween.is_valid():
		_tween.kill()

	# Center base ring at touch coordinate
	if base_ring != null:
		base_ring.global_position = base_center_position
		if stick_knob != null:
			stick_knob.position = Vector2.ZERO

		# Fade in
		_tween = create_tween().set_parallel(true)
		_tween.tween_property(base_ring, "modulate:a", active_opacity, 0.08)

	output_vector = Vector2.ZERO
	world_direction_3d = Vector3.ZERO
	return true

func _on_touch_drag(pos: Vector2) -> bool:
	if not is_active:
		return false

	var raw_offset: Vector2 = pos - base_center_position
	var clamped_stick_pos: Vector2 = calculate_clamped_stick_pos(pos, base_center_position)

	# Update knob visual position relative to BaseRing center
	if stick_knob != null:
		stick_knob.position = clamped_stick_pos - base_center_position

	# Compute 2D normalized vector with deadzone
	output_vector = calculate_output_vector(raw_offset)

	# Transform to 3D world isometric vector
	var cam_yaw: float = get_camera_yaw()
	world_direction_3d = calculate_camera_relative_3d(output_vector, cam_yaw)

	# Apply to avatar
	if is_instance_valid(avatar_node) and avatar_node.has_method("set_input_direction"):
		avatar_node.call("set_input_direction", world_direction_3d)

	joystick_moved.emit(world_direction_3d, output_vector)
	return true

func _on_touch_up() -> bool:
	if not is_active:
		return false

	reset_joystick()
	return true

# ------------------------------------------------------------------------------
# Mathematical Algorithms
# ------------------------------------------------------------------------------

## Checks if a coordinate falls within the permitted left-half activation zone.
func is_in_touch_zone(screen_pos: Vector2) -> bool:
	return screen_pos.x >= zone_min_x and screen_pos.x <= zone_max_x \
		and screen_pos.y >= zone_min_y and screen_pos.y <= zone_max_y

## Clamps the touch position to max_radius from center_pos.
## Returns clamped absolute position in same coordinate space as center_pos.
func calculate_clamped_stick_pos(touch_pos: Vector2, center_pos: Vector2) -> Vector2:
	var offset: Vector2 = touch_pos - center_pos
	var length: float = offset.length()
	if length <= max_radius:
		return touch_pos
	if length > 0.0:
		return center_pos + (offset / length) * max_radius
	return center_pos

## Calculates normalized 2D vector with radial deadzone and continuous linear scaling.
func calculate_output_vector(stick_offset: Vector2) -> Vector2:
	var length: float = stick_offset.length()
	if length <= deadzone_radius or is_zero_approx(length):
		return Vector2.ZERO

	var active_span: float = max_radius - deadzone_radius
	if active_span <= 0.0:
		return stick_offset.normalized()

	var clamped_length: float = minf(length, max_radius)
	var normalized_mag: float = clampf((clamped_length - deadzone_radius) / active_span, 0.0, 1.0)
	var unit_dir: Vector2 = stick_offset / length
	return unit_dir * normalized_mag

## Transforms a 2D screen direction vector into a 3D isometric world direction vector.
## Yaw = 45 deg (PI / 4) aligns screen forward with isometric camera forward.
func calculate_camera_relative_3d(input_2d: Vector2, camera_yaw: float = 0.785398163) -> Vector3:
	if input_2d == Vector2.ZERO:
		return Vector3.ZERO

	# Screen forward (delta Y < 0) corresponds to camera forward
	var forward: Vector3 = Vector3(-sin(camera_yaw), 0.0, -cos(camera_yaw))
	var right: Vector3 = Vector3(cos(camera_yaw), 0.0, -sin(camera_yaw))

	var dir_3d: Vector3 = right * input_2d.x + forward * (-input_2d.y)
	return dir_3d

## Retrieves the current camera yaw angle in radians.
func get_camera_yaw() -> float:
	if camera_node != null and is_instance_valid(camera_node):
		return camera_node.global_rotation.y
	var vp = get_viewport()
	if vp != null:
		var cam = vp.get_camera_3d()
		if cam != null:
			return cam.global_rotation.y
	return default_camera_yaw

## Resets tracking state, halts the avatar immediately, and animates visuals to rest.
func reset_joystick() -> void:
	is_active = false
	touch_finger_index = -1
	output_vector = Vector2.ZERO
	world_direction_3d = Vector3.ZERO

	# Halt Avatar3D immediately with zero drift
	if is_instance_valid(avatar_node):
		if avatar_node.has_method("set_input_direction"):
			avatar_node.call("set_input_direction", Vector3.ZERO)
		if avatar_node.has_method("stop_movement"):
			avatar_node.call("stop_movement")

	# Animate visuals back to resting state
	if _tween != null and _tween.is_valid():
		_tween.kill()

	if base_ring != null:
		_tween = create_tween().set_parallel(true)
		if stick_knob != null:
			_tween.tween_property(stick_knob, "position", Vector2.ZERO, return_duration)\
				.set_trans(Tween.TRANS_QUAD)\
				.set_ease(Tween.EASE_OUT)

		_tween.tween_property(base_ring, "modulate:a", resting_opacity, fade_duration)\
			.set_trans(Tween.TRANS_QUAD)\
			.set_ease(Tween.EASE_OUT)

	joystick_released.emit()

# ------------------------------------------------------------------------------
# Helpers & Node Discovery
# ------------------------------------------------------------------------------

func set_avatar(node: Node) -> void:
	avatar_node = node

func set_camera(node: Camera3D) -> void:
	camera_node = node

func _find_avatar_in_tree() -> Node:
	var tree = get_tree()
	if tree == null:
		return null
	var players = tree.get_nodes_in_group("player")
	if players.size() > 0:
		return players[0]
	return tree.root.find_child("Avatar3D", true, false)

func _find_camera_in_tree() -> Camera3D:
	var vp = get_viewport()
	if vp != null:
		return vp.get_camera_3d()
	var tree = get_tree()
	if tree != null:
		return tree.root.find_child("Camera3D", true, false) as Camera3D
	return null
