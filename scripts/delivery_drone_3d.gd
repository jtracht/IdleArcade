extends CharacterBody3D
class_name DeliveryDrone3D

## Autonomous 3D Chibi Delivery Drone for IdleArcade (Phase 8).
## Quads across the campus in a 5-waypoint cyclic patrol, autonomously collecting
## nearby collectibles within 3.5m radius. Features spinning rotors, pulsating LEDs,
## altitude hover bobbing, directional banking, and dynamic tech-tree activation.

const WAYPOINTS: Array[Vector3] = [
	Vector3(0.0, 1.8, 0.0),     # 1. Lobby
	Vector3(0.0, 1.8, -18.0),   # 2. Server Room
	Vector3(-19.0, 1.8, 0.0),   # 3. R&D Lab
	Vector3(19.0, 1.8, 0.0),    # 4. Office / Incubator
	Vector3(0.0, 1.8, 18.0)     # 5. Courtyard
]

@export var move_speed: float = 4.5
@export var rotor_speed: float = 24.0
@export var waypoint_arrival_dist: float = 0.8
@export var hover_bob_freq: float = 4.0
@export var hover_bob_amplitude: float = 0.15
@export var led_pulse_freq: float = 6.0
@export var bank_tilt_max_deg: float = 10.0

@onready var visuals: Node3D = get_node_or_null("Visuals")
@onready var collection_area: Area3D = get_node_or_null("CollectionArea")
@onready var rotor_fl: Node3D = get_node_or_null("Visuals/Rotors/RotorFL")
@onready var rotor_fr: Node3D = get_node_or_null("Visuals/Rotors/RotorFR")
@onready var rotor_bl: Node3D = get_node_or_null("Visuals/Rotors/RotorBL")
@onready var rotor_br: Node3D = get_node_or_null("Visuals/Rotors/RotorBR")
@onready var nav_leds_parent: Node3D = get_node_or_null("Visuals/NavLEDs")
@onready var ground_shadow: MeshInstance3D = get_node_or_null("Visuals/GroundShadow")

var current_waypoint_index: int = 0
var is_drone_active: bool = false
var _time: float = 0.0
var _base_visual_y: float = 0.0
var _collected_count: int = 0
var _speed_multiplier: float = 1.0
var _speed_boost_timer: float = 0.0
var _led_materials: Array[StandardMaterial3D] = []

func _ready() -> void:
	add_to_group("delivery_drones")
	
	if visuals != null:
		_base_visual_y = visuals.position.y
		
	if collection_area != null:
		collection_area.area_entered.connect(_on_collection_area_entered)
		
	_collect_led_materials()
	
	# Initial positioning at first waypoint if placed at origin
	if position.is_equal_approx(Vector3.ZERO):
		global_position = WAYPOINTS[0]
		
	# Check GameState research state for activation
	var gs = get_node_or_null("/root/GameState")
	if gs != null:
		if gs.has_signal("tech_researched"):
			gs.tech_researched.connect(_on_tech_researched)
			
		if gs.has_method("is_tech_researched") and gs.is_tech_researched("tech_delivery_drone"):
			activate_drone()
		else:
			deactivate_drone()
	else:
		# Standalone / Editor preview fallback: remain active if in isolated test tree
		if get_parent() == null or get_parent().name == "root":
			activate_drone()
		else:
			deactivate_drone()

func _collect_led_materials() -> void:
	_led_materials.clear()
	if nav_leds_parent == null:
		return
	for child in nav_leds_parent.get_children():
		if child is MeshInstance3D and (child as MeshInstance3D).mesh != null:
			var mat = (child as MeshInstance3D).mesh.material
			if mat is StandardMaterial3D and not _led_materials.has(mat):
				_led_materials.append(mat)

func _process(delta: float) -> void:
	if not is_drone_active:
		return
		
	_time += delta
	
	# Handle speed boost timer
	if _speed_boost_timer > 0.0:
		_speed_boost_timer -= delta
		if _speed_boost_timer <= 0.0:
			_speed_multiplier = 1.0
			
	# Rotor rotation (counter-rotating pairs)
	var rot_delta: float = rotor_speed * delta
	if rotor_fl != null:
		rotor_fl.rotate_y(rot_delta)
	if rotor_fr != null:
		rotor_fr.rotate_y(-rot_delta)
	if rotor_bl != null:
		rotor_bl.rotate_y(-rot_delta)
	if rotor_br != null:
		rotor_br.rotate_y(rot_delta)
		
	# Altitude hover bobbing
	if visuals != null:
		visuals.position.y = _base_visual_y + sin(_time * hover_bob_freq) * hover_bob_amplitude
		
	# Pulsating LED emission
	var pulse: float = 1.0 + sin(_time * led_pulse_freq) * 0.8
	for mat in _led_materials:
		mat.emission_energy_multiplier = pulse
		
	# Forward banking tilt into travel direction
	_update_banking_tilt(delta)

func _update_banking_tilt(delta: float) -> void:
	if visuals == null:
		return
		
	var h_vel: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
	var speed: float = h_vel.length()
	var target_tilt: float = 0.0
	
	if speed > 0.1:
		var ratio: float = clampf(speed / (move_speed * _speed_multiplier), 0.0, 1.0)
		target_tilt = deg_to_rad(bank_tilt_max_deg) * ratio
		
	visuals.rotation.x = lerp_angle(visuals.rotation.x, target_tilt, clampf(delta * 6.0, 0.0, 1.0))

func _physics_process(delta: float) -> void:
	if not is_drone_active:
		velocity = Vector3.ZERO
		return
		
	var target_pos: Vector3 = WAYPOINTS[current_waypoint_index]
	var current_pos: Vector3 = global_position
	
	var flat_dist: float = Vector2(current_pos.x - target_pos.x, current_pos.z - target_pos.z).length()
	if flat_dist <= waypoint_arrival_dist:
		current_waypoint_index = (current_waypoint_index + 1) % WAYPOINTS.size()
		target_pos = WAYPOINTS[current_waypoint_index]
		
	var diff: Vector3 = target_pos - current_pos
	var flat_dir: Vector3 = Vector3(diff.x, 0.0, diff.z)
	
	if flat_dir.length_squared() > 0.001:
		flat_dir = flat_dir.normalized()
		var target_yaw: float = atan2(-flat_dir.x, -flat_dir.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, clampf(delta * 5.0, 0.0, 1.0))
		
		var effective_speed: float = move_speed * _speed_multiplier
		velocity.x = flat_dir.x * effective_speed
		velocity.z = flat_dir.z * effective_speed
	else:
		velocity.x = 0.0
		velocity.z = 0.0
		
	# Smooth vertical altitude tracking to waypoint Y
	velocity.y = (target_pos.y - current_pos.y) * 2.5
	
	move_and_slide()

func _on_collection_area_entered(area: Area3D) -> void:
	if not is_drone_active:
		return
	_try_collect(area)

func _try_collect(target: Node) -> bool:
	if target == null:
		return false
	if target.is_in_group("collectibles") or target.has_method("collect"):
		if target.has_method("collect"):
			target.call("collect", self)
			_collected_count += 1
			return true
	return false

## Helper for explicit radial collection checks
func collect_nearby_collectibles(radius: float = 3.5) -> int:
	var gathered: int = 0
	var tree = get_tree()
	if tree == null:
		return 0
	var colls = tree.get_nodes_in_group("collectibles")
	for col in colls:
		if is_instance_valid(col) and col is Node3D:
			var dist: float = global_position.distance_to(col.global_position)
			if dist <= radius:
				if _try_collect(col):
					gathered += 1
	return gathered

## Applies speed boost when collecting coffee items
func apply_speed_boost(multiplier: float = 1.35, duration: float = 5.0) -> void:
	_speed_multiplier = maxf(_speed_multiplier, multiplier)
	_speed_boost_timer = maxf(_speed_boost_timer, duration)

## Activates autonomous patrol and juicing
func activate_drone() -> void:
	is_drone_active = true
	visible = true
	set_process(true)
	set_physics_process(true)
	var col = get_node_or_null("CollisionShape3D")
	if col != null:
		col.set_deferred("disabled", false)

## Deactivates drone into docked/idle sleep
func deactivate_drone() -> void:
	is_drone_active = false
	visible = false
	set_process(false)
	set_physics_process(false)
	velocity = Vector3.ZERO
	var col = get_node_or_null("CollisionShape3D")
	if col != null:
		col.set_deferred("disabled", true)

func is_active() -> bool:
	return is_drone_active

func get_current_waypoint() -> Vector3:
	return WAYPOINTS[current_waypoint_index]

func get_collected_count() -> int:
	return _collected_count

func _on_tech_researched(tech_id: String) -> void:
	if tech_id == "tech_delivery_drone":
		activate_drone()
