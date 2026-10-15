extends CharacterBody3D
class_name Avatar3D

## 3D Avatar Controller for IdleArcade Phase 4 (Milestone P4-M1).
## Supports WASD / Arrow keys keyboard input, mouse click-to-move / touch drag,
## smooth directional turning, kinematic physics, gravity, GameState speed scaling,
## and a public API for headless automated verification.

# --- Signals ---
signal destination_reached(target_position: Vector3)
signal speed_boost_applied(multiplier: float, duration: float)
signal speed_boost_expired()

# --- Exported Parameters ---
@export var base_speed: float = 6.0
@export var acceleration: float = 24.0
@export var friction: float = 18.0
@export var turn_speed: float = 12.0
@export var gravity: float = 20.0
@export var stop_distance: float = 0.2
@export var use_camera_relative_input: bool = true

# --- Procedural Locomotion Parameters ---
@export var enable_procedural_animation: bool = true
@export var walk_bob_frequency: float = 12.0
@export var walk_bob_amplitude: float = 0.06
@export var walk_roll_tilt_amplitude: float = 0.05
@export var idle_breath_frequency: float = 2.0
@export var idle_breath_amplitude: float = 0.015

# --- Public State ---
var current_speed: float = 6.0
var input_enabled: bool = true

# --- Internal State ---
var _script_input_direction: Vector3 = Vector3.ZERO
var _click_target: Vector3 = Vector3.ZERO
var _has_click_target: bool = false
var _speed_boost_multiplier: float = 1.0
var _speed_boost_timer: float = 0.0
var _anim_time: float = 0.0
var _base_visual_y: float = 0.0

@onready var visuals: Node3D = $Visuals
@onready var footstep_particles: CPUParticles3D = get_node_or_null("FootstepDust")

func _ready() -> void:
	if not is_in_group("player"):
		add_to_group("player")
	current_speed = get_move_speed()
	if visuals != null:
		_base_visual_y = visuals.position.y

func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled:
		return
		
	# Mouse Click-to-Move
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_process_screen_navigation_event(event.position)
	# Mobile Touch Drag / Tap
	elif (event is InputEventScreenTouch and event.pressed) or (event is InputEventScreenDrag):
		_process_screen_navigation_event(event.position)

func _physics_process(delta: float) -> void:
	if delta <= 0.0:
		return
		
	# 1. Update temporary speed boost buff timer
	_update_speed_boost(delta)
	current_speed = get_move_speed()
	
	# 2. Gravity and vertical integration
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		if velocity.y < 0.0:
			velocity.y = 0.0

	# 3. Resolve desired horizontal movement direction
	var desired_dir: Vector3 = Vector3.ZERO
	
	if _script_input_direction != Vector3.ZERO:
		# Priority 1: Injected script input (headless testing / scripted control)
		desired_dir = _script_input_direction
		_has_click_target = false
	elif input_enabled:
		var keyboard_dir = _get_keyboard_input_vector()
		if keyboard_dir != Vector3.ZERO:
			# Priority 2: Direct keyboard navigation (preempts click target)
			desired_dir = keyboard_dir
			_has_click_target = false
		elif _has_click_target:
			# Priority 3: Mouse click-to-move / touch navigation
			var diff = _click_target - global_position
			diff.y = 0.0
			var dist = diff.length()
			if dist <= stop_distance:
				_has_click_target = false
				desired_dir = Vector3.ZERO
				destination_reached.emit(_click_target)
			else:
				desired_dir = diff.normalized()

	# 4. Accelerate / Decelerate horizontal velocity
	var current_horizontal = Vector3(velocity.x, 0.0, velocity.z)
	var target_horizontal = desired_dir * current_speed
	
	if desired_dir != Vector3.ZERO:
		current_horizontal = current_horizontal.move_toward(target_horizontal, acceleration * delta)
	else:
		current_horizontal = current_horizontal.move_toward(Vector3.ZERO, friction * delta)
		
	velocity.x = current_horizontal.x
	velocity.z = current_horizontal.z
	
	# 5. Smooth facing rotation towards travel velocity direction
	if current_horizontal.length() > 0.05 and visuals != null:
		var target_angle: float = atan2(velocity.x, velocity.z)
		visuals.rotation.y = lerp_angle(visuals.rotation.y, target_angle, turn_speed * delta)
		
	# 6. Kinematic move execution
	move_and_slide()

	# 7. Procedural locomotion & visual juice
	if enable_procedural_animation and visuals != null:
		_update_procedural_animation(delta, current_horizontal)

## Raycasts screen coordinate against horizontal ground plane (y = 0)
func _process_screen_navigation_event(screen_pos: Vector2) -> void:
	var viewport = get_viewport()
	if viewport == null:
		return
	var camera: Camera3D = viewport.get_camera_3d()
	if camera == null:
		return
		
	var ray_origin: Vector3 = camera.project_ray_origin(screen_pos)
	var ray_normal: Vector3 = camera.project_ray_normal(screen_pos)
	var ground_plane: Plane = Plane(Vector3.UP, 0.0)
	var hit = ground_plane.intersects_ray(ray_origin, ray_normal)
	
	if hit != null:
		# Safety bounds clamp to campus play area
		hit.x = clampf(hit.x, -50.0, 50.0)
		hit.z = clampf(hit.z, -50.0, 50.0)
		move_to_position(hit)

## Reads keyboard WASD and arrow keys, returning normalized horizontal vector
func _get_keyboard_input_vector() -> Vector3:
	var raw_x: float = 0.0
	var raw_z: float = 0.0
	
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP) or Input.is_action_pressed("ui_up"):
		raw_z -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN) or Input.is_action_pressed("ui_down"):
		raw_z += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT) or Input.is_action_pressed("ui_left"):
		raw_x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT) or Input.is_action_pressed("ui_right"):
		raw_x += 1.0
		
	if is_zero_approx(raw_x) and is_zero_approx(raw_z):
		return Vector3.ZERO
		
	var input_2d: Vector2 = Vector2(raw_x, raw_z).normalized()
	
	if use_camera_relative_input:
		var vp = get_viewport()
		var cam: Camera3D = vp.get_camera_3d() if vp != null else null
		if cam != null:
			var cam_yaw: float = cam.global_rotation.y
			var forward: Vector3 = Vector3(-sin(cam_yaw), 0.0, -cos(cam_yaw))
			var right: Vector3 = Vector3(cos(cam_yaw), 0.0, -sin(cam_yaw))
			return (right * input_2d.x + forward * (-input_2d.y)).normalized()
			
	return Vector3(input_2d.x, 0.0, input_2d.y).normalized()

func _update_procedural_animation(delta: float, horizontal_vel: Vector3) -> void:
	var speed_ratio: float = clampf(horizontal_vel.length() / maxf(current_speed, 0.001), 0.0, 1.5)
	if speed_ratio > 0.05:
		_anim_time += delta * walk_bob_frequency * speed_ratio
		var bob_offset: float = abs(sin(_anim_time)) * walk_bob_amplitude * speed_ratio
		visuals.position.y = _base_visual_y + bob_offset
		
		var roll_sway: float = sin(_anim_time * 0.5) * walk_roll_tilt_amplitude * speed_ratio
		visuals.rotation.z = lerp_angle(visuals.rotation.z, roll_sway, 12.0 * delta)
		
		var forward_pitch: float = -0.06 * speed_ratio
		visuals.rotation.x = lerp_angle(visuals.rotation.x, forward_pitch, 10.0 * delta)
		
		if footstep_particles != null:
			footstep_particles.emitting = true
	else:
		_anim_time += delta * idle_breath_frequency
		var breath_offset: float = sin(_anim_time) * idle_breath_amplitude
		visuals.position.y = lerp(visuals.position.y, _base_visual_y + breath_offset, 6.0 * delta)
		visuals.rotation.z = lerp_angle(visuals.rotation.z, 0.0, 10.0 * delta)
		visuals.rotation.x = lerp_angle(visuals.rotation.x, 0.0, 10.0 * delta)
		
		if footstep_particles != null:
			footstep_particles.emitting = false

func _update_speed_boost(delta: float) -> void:
	if _speed_boost_timer > 0.0:
		_speed_boost_timer -= delta
		if _speed_boost_timer <= 0.0:
			_speed_boost_multiplier = 1.0
			_speed_boost_timer = 0.0
			speed_boost_expired.emit()

# ==============================================================================
# Public API & Headless Test Interface
# ==============================================================================

## Directly injects movement input direction for player or headless tests
func set_input_direction(dir: Vector3) -> void:
	var horizontal: Vector3 = Vector3(dir.x, 0.0, dir.z)
	if horizontal != Vector3.ZERO:
		_script_input_direction = horizontal.normalized()
		_has_click_target = false
	else:
		_script_input_direction = Vector3.ZERO

## Sets destination coordinate for click-to-move navigation
func move_to_position(target: Vector3) -> void:
	_click_target = Vector3(target.x, global_position.y, target.z)
	_has_click_target = true
	_script_input_direction = Vector3.ZERO

## Halts all movement and clears pending destinations
func stop_movement() -> void:
	_script_input_direction = Vector3.ZERO
	_has_click_target = false
	velocity = Vector3(0.0, velocity.y, 0.0)
	if visuals != null:
		visuals.position.y = _base_visual_y
		visuals.rotation.z = 0.0
		visuals.rotation.x = 0.0
	if footstep_particles != null:
		footstep_particles.emitting = false

## Convenience alias for stop_movement()
func stop() -> void:
	stop_movement()

## Enables or disables avatar input (e.g. while Laptop menu / HUD is active)
func set_input_enabled(enabled: bool) -> void:
	input_enabled = enabled
	if not enabled:
		stop_movement()

## Returns effective movement speed scaling with GameState and active power-ups
func get_move_speed() -> float:
	var gs_mult: float = 1.0
	var gs = get_node_or_null("/root/GameState")
	if gs != null:
		if gs.has_method("get_effective_avatar_speed"):
			gs_mult = gs.get_effective_avatar_speed()
		elif "avatar_speed_level" in gs:
			gs_mult = 1.0 + float(gs.avatar_speed_level) * 0.15
	return base_speed * gs_mult * _speed_boost_multiplier

## Applies temporary speed multiplier boost
func apply_speed_boost(multiplier: float, duration: float) -> void:
	_speed_boost_multiplier = maxf(_speed_boost_multiplier, multiplier)
	_speed_boost_timer = maxf(_speed_boost_timer, duration)
	speed_boost_applied.emit(multiplier, duration)

## Returns true if avatar is actively moving horizontally
func is_moving() -> bool:
	return Vector2(velocity.x, velocity.z).length() > 0.05

## Returns facing direction unit vector based on visual visor rotation
func get_facing_direction() -> Vector3:
	var yaw: float = visuals.rotation.y if visuals != null else 0.0
	return Vector3(sin(yaw), 0.0, cos(yaw))
