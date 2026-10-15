extends Node3D
class_name QuestWaypoint3D

## 3D Objective Waypoint & Direction Indicator for IdleArcade (Phase 6).
## Dynamically tracks active quests, calculating distance and bearing to objectives
## (NPCs, collectibles, locked gates), and guiding the player across campus.

@export var enabled: bool = true
@export var float_height: float = 2.4
@export var orbit_radius: float = 1.3
@export var arrival_threshold: float = 3.0

var _target_node: Node3D = null
var _target_position: Vector3 = Vector3.ZERO
var _target_name: String = "Campus Lobby"
var _distance: float = 0.0

@onready var arrow_mesh: MeshInstance3D = get_node_or_null("ArrowVisuals/ArrowMesh")
@onready var distance_label: Label3D = get_node_or_null("ArrowVisuals/DistanceLabel3D")
@onready var arrow_visuals: Node3D = get_node_or_null("ArrowVisuals")

func _ready() -> void:
	if not is_in_group("quest_waypoints"):
		add_to_group("quest_waypoints")
		
	var gs = get_node_or_null("/root/GameState")
	if gs != null:
		if gs.has_signal("campus_quest_updated"):
			gs.campus_quest_updated.connect(_on_quest_updated)
		if gs.has_signal("campus_quest_completed"):
			gs.campus_quest_completed.connect(_on_quest_completed)
		if gs.has_signal("collectible_picked_up"):
			gs.collectible_picked_up.connect(_on_collectible_picked_up)
			
	_refresh_objective_target()

func _process(delta: float) -> void:
	if not enabled:
		visible = false
		return
		
	var avatar = _find_avatar()
	if avatar == null:
		return
		
	# Follow avatar position smoothly
	global_position = avatar.global_position + Vector3(0.0, float_height, 0.0)
	
	_update_target_position()
	
	if _target_position == Vector3.ZERO:
		visible = false
		return
		
	visible = true
	var to_target: Vector3 = _target_position - avatar.global_position
	to_target.y = 0.0
	_distance = to_target.length()
	
	if _distance > 0.1 and arrow_visuals != null:
		var target_angle: float = atan2(to_target.x, to_target.z)
		arrow_visuals.rotation.y = lerp_angle(arrow_visuals.rotation.y, target_angle, 8.0 * delta)
		
		# Offset arrow outward along bearing vector
		var bearing_dir = to_target.normalized()
		arrow_visuals.position = bearing_dir * orbit_radius
		
	if distance_label != null:
		if _distance <= arrival_threshold:
			distance_label.text = "%s\n[ Arrived! ]" % _target_name
			distance_label.modulate = Color(0.3, 1.0, 0.5)
		else:
			distance_label.text = "%s\n%.0fm" % [_target_name, _distance]
			distance_label.modulate = Color(1.0, 0.85, 0.3)

func _update_target_position() -> void:
	if is_instance_valid(_target_node):
		_target_position = _target_node.global_position
	elif _target_node != null:
		_refresh_objective_target()

func _refresh_objective_target() -> void:
	var gs = get_node_or_null("/root/GameState")
	var active_quest: String = ""
	if gs != null and "active_campus_quest_id" in gs:
		active_quest = gs.active_campus_quest_id
		
	var tree = get_tree()
	if tree == null:
		return

	# Priority 1: Quest briefcase collection -> nearest briefcase
	var collectibles = tree.get_nodes_in_group("collectibles")
	if collectibles.size() > 0 and (active_quest.is_empty() or active_quest == "quest_briefcases"):
		var avatar = _find_avatar()
		var nearest: Node3D = null
		var min_dist: float = 9999.0
		for col in collectibles:
			if is_instance_valid(col) and col.is_inside_tree():
				var d = col.global_position.distance_to(avatar.global_position if avatar else Vector3.ZERO)
				if d < min_dist:
					min_dist = d
					nearest = col
		if nearest != null:
			_target_node = nearest
			_target_name = "Briefcase"
			_target_position = nearest.global_position
			return

	# Priority 2: NPCs based on quest
	var npcs = tree.get_nodes_in_group("npcs")
	if active_quest == "quest_server":
		for npc in npcs:
			if is_instance_valid(npc) and "npc_id" in npc and npc.npc_id == "architect_bob":
				_target_node = npc
				_target_name = "Bob (Server Room)"
				_target_position = npc.global_position
				return
	elif active_quest == "quest_lab":
		for npc in npcs:
			if is_instance_valid(npc) and "npc_id" in npc and npc.npc_id == "scientist_lisa":
				_target_node = npc
				_target_name = "Dr. Lisa (R&D Lab)"
				_target_position = npc.global_position
				return

	# Fallback: Alex in Lobby or Incubator
	for npc in npcs:
		if is_instance_valid(npc) and "npc_id" in npc and npc.npc_id == "ceo_alex":
			_target_node = npc
			_target_name = "Alex (Lobby)"
			_target_position = npc.global_position
			return

func _on_quest_updated(_q_id: String, _status: String, _curr: int, _target: int) -> void:
	_refresh_objective_target()

func _on_quest_completed(_q_id: String, _energy: float, _bonus: int) -> void:
	_refresh_objective_target()

func _on_collectible_picked_up(_type: String, _total: int) -> void:
	_refresh_objective_target()

func _find_avatar() -> Node3D:
	var tree = get_tree()
	if tree == null:
		return null
	var players = tree.get_nodes_in_group("player")
	if players.size() > 0:
		return players[0] as Node3D
	return tree.root.find_child("Avatar3D", true, false) as Node3D

## API for headless verification
func get_distance() -> float:
	return _distance

func get_target_name() -> String:
	return _target_name
