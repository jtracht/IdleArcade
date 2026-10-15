extends Area3D
class_name Collectible3D

## 3D Collectible Item for IdleArcade (Phase 4 Milestone P4-M3).
## Supports spinning/bobbing animation, dynamic pickup radius scaling from GameState,
## multiple item types (briefcase, coffee, usb_drive), and integration with GameState.collect_3d_item().

signal collected(item_type: String, reward_amount: float)

@export var item_type: String = "briefcase"
@export var reward_amount: float = 50.0
@export var spin_speed: float = 2.5
@export var bob_amplitude: float = 0.12
@export var bob_speed: float = 3.0
@export var speed_boost_multiplier: float = 1.4
@export var speed_boost_duration: float = 8.0

var _base_y: float = 0.5
var _time: float = 0.0
var _is_collected: bool = false
var _base_collision_radius: float = 1.2

@onready var visuals: Node3D = get_node_or_null("Visuals")
@onready var collision_shape: CollisionShape3D = get_node_or_null("CollisionShape3D")

func _ready() -> void:
	if not is_in_group("collectibles"):
		add_to_group("collectibles")
		
	collision_layer = 4 # Layer 3 (Collectibles)
	collision_mask = 1  # Detect Player (Layer 1)
	
	if visuals != null:
		_base_y = visuals.position.y
		_apply_item_type_styling()
		
	if collision_shape != null and collision_shape.shape is SphereShape3D:
		_base_collision_radius = (collision_shape.shape as SphereShape3D).radius
		_update_pickup_radius()
		
	# Connect to GameState stat upgrades
	var gs = get_node_or_null("/root/GameState")
	if gs != null and gs.has_signal("avatar_stat_updated"):
		gs.avatar_stat_updated.connect(_on_avatar_stat_updated)
		
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	if _is_collected:
		return
	_time += delta
	if visuals != null:
		visuals.rotate_y(spin_speed * delta)
		visuals.position.y = _base_y + sin(_time * bob_speed) * bob_amplitude

func _on_body_entered(body: Node3D) -> void:
	if _is_collected:
		return
		
	if body.is_in_group("player") or body is CharacterBody3D:
		collect(body)

## Public collection method (callable programmatically or via physics contact)
func collect(collector: Node3D = null) -> void:
	if _is_collected:
		return
	_is_collected = true
	
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	
	# Apply special item buffs (e.g. coffee speed boost)
	if item_type == "coffee" and collector != null and collector.has_method("apply_speed_boost"):
		collector.apply_speed_boost(speed_boost_multiplier, speed_boost_duration)
		
	# Register with GameState economy
	var gs = get_node_or_null("/root/GameState")
	if gs != null and gs.has_method("collect_3d_item"):
		gs.collect_3d_item(item_type, reward_amount)
		
	collected.emit(item_type, reward_amount)
	
	# Pickup celebration animation
	_play_pickup_animation()

func _play_pickup_animation() -> void:
	_spawn_floating_text()
	var tween = create_tween().set_parallel(true)
	if visuals != null:
		tween.tween_property(visuals, "scale", Vector3.ZERO, 0.25).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
		tween.tween_property(visuals, "position:y", _base_y + 1.2, 0.25).set_ease(Tween.EASE_OUT)
	tween.chain().tween_callback(queue_free)

func _spawn_floating_text() -> void:
	var parent_node = get_parent()
	if parent_node == null:
		return
	var label = Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = 26
	label.outline_size = 6
	
	var text_msg = "+%.0f Energy" % reward_amount
	var text_color = Color(1.0, 0.85, 0.2)
	if item_type == "coffee":
		text_msg = "+%.0f Coffee (Speed Boost!)" % reward_amount
		text_color = Color(0.4, 0.9, 1.0)
	elif item_type == "usb_drive":
		text_msg = "+%.0f Data Drive" % reward_amount
		text_color = Color(0.7, 0.4, 1.0)
		
	label.text = text_msg
	label.modulate = text_color
	label.global_position = global_position + Vector3(0.0, 0.8, 0.0)
	parent_node.add_child(label)
	
	var float_tween = label.create_tween().set_parallel(true)
	float_tween.tween_property(label, "position:y", label.position.y + 1.4, 0.75).set_ease(Tween.EASE_OUT)
	float_tween.tween_property(label, "modulate:a", 0.0, 0.75).set_delay(0.25)
	float_tween.chain().tween_callback(label.queue_free)

func _on_avatar_stat_updated(stat_name: String, _new_value: float) -> void:
	if stat_name == "pickup_radius":
		_update_pickup_radius()

func _update_pickup_radius() -> void:
	var gs = get_node_or_null("/root/GameState")
	var mult: float = 1.0
	if gs != null and gs.has_method("get_effective_pickup_radius"):
		mult = gs.get_effective_pickup_radius()
	if collision_shape != null and collision_shape.shape is SphereShape3D:
		(collision_shape.shape as SphereShape3D).radius = _base_collision_radius * mult

func _apply_item_type_styling() -> void:
	# Configure visual mesh if child meshes exist
	var mesh_inst = visuals.get_node_or_null("ItemMesh") as MeshInstance3D
	if mesh_inst == null:
		return
		
	var mat = StandardMaterial3D.new()
	match item_type:
		"coffee":
			mat.albedo_color = Color(0.9, 0.3, 0.2, 1.0) # Warm Red
			mat.roughness = 0.3
			mat.emission_enabled = true
			mat.emission = Color(0.9, 0.3, 0.2, 1.0) * 0.2
		"usb_drive":
			mat.albedo_color = Color(0.1, 0.7, 1.0, 1.0) # Cyber Cyan
			mat.metallic = 0.8
			mat.roughness = 0.2
			mat.emission_enabled = true
			mat.emission = Color(0.1, 0.7, 1.0, 1.0) * 0.4
		_: # "briefcase" default
			mat.albedo_color = Color(1.0, 0.82, 0.2, 1.0) # Gold
			mat.metallic = 0.6
			mat.roughness = 0.3
			mat.emission_enabled = true
			mat.emission = Color(1.0, 0.82, 0.2, 1.0) * 0.25
	mesh_inst.material_override = mat
