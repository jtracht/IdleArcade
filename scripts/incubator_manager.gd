extends Node3D
class_name IncubatorManager

## Startup Incubator & Dev Hub Controller for IdleArcade (Phase 6).
## Manages living mini-worker avatars ("Spate mit kleinen Avataren"),
## dynamically scaling the office headcount with idle meta-progression,
## and coordinating team celebrations upon quest and level milestones.

signal team_celebration_started()

@export var max_workers: int = 6
@export var base_spawn_count: int = 2
@export var worker_scene: PackedScene = preload("res://scenes/worker_avatar_3d.tscn")

var _workers: Array[WorkerAvatar3D] = []

const WORKER_DEFS = [
	{
		"name": "Sam",
		"role": "intern",
		"home": Vector3(-4.0, 0.0, -3.3),
		"patrol": [Vector3(-4.0, 0.0, 0.0), Vector3(0.0, 0.0, 0.0), Vector3(6.5, 0.0, 0.0)]
	},
	{
		"name": "Jordan",
		"role": "coder",
		"home": Vector3(4.0, 0.0, -3.3),
		"patrol": [Vector3(4.0, 0.0, 0.0), Vector3(0.0, 0.0, -5.0), Vector3(6.5, 0.0, 0.0)]
	},
	{
		"name": "Mia",
		"role": "marketer",
		"home": Vector3(-4.0, 0.0, 4.7),
		"patrol": [Vector3(-4.0, 0.0, 0.0), Vector3(-6.5, 0.0, 0.0), Vector3(6.5, 0.0, 0.0)]
	},
	{
		"name": "Leo",
		"role": "architect",
		"home": Vector3(4.0, 0.0, 4.7),
		"patrol": [Vector3(4.0, 0.0, 0.0), Vector3(0.0, 0.0, 3.0), Vector3(-6.5, 0.0, 0.0)]
	},
	{
		"name": "Kai",
		"role": "coder",
		"home": Vector3(0.0, 0.0, -7.0),
		"patrol": [Vector3(0.0, 0.0, 0.0), Vector3(6.5, 0.0, 0.0)]
	}
]

func _ready() -> void:
	if not is_in_group("incubator"):
		add_to_group("incubator")
		
	# Connect to GameState signals
	var gs = get_node_or_null("/root/GameState")
	if gs != null:
		if gs.has_signal("campus_quest_completed"):
			gs.campus_quest_completed.connect(_on_campus_quest_completed)
		if gs.has_signal("zone_unlocked"):
			gs.zone_unlocked.connect(_on_zone_unlocked)
		if gs.has_signal("avatar_stat_updated"):
			gs.avatar_stat_updated.connect(_on_stat_updated)
			
	# Spawn initial team
	_update_team_headcount()

func _update_team_headcount() -> void:
	var desired_count: int = base_spawn_count
	var gs = get_node_or_null("/root/GameState")
	if gs != null:
		var lvl: int = gs.idle_level if "idle_level" in gs else 1
		desired_count += (lvl - 1)
		# Add bonus worker if any zones unlocked
		if "unlocked_zones" in gs and gs.unlocked_zones.size() > 0:
			desired_count += gs.unlocked_zones.size()
			
	desired_count = clampi(desired_count, 1, WORKER_DEFS.size())
	
	while _workers.size() < desired_count:
		_spawn_worker(_workers.size())

func _spawn_worker(index: int) -> void:
	if worker_scene == null or index >= WORKER_DEFS.size():
		return
	var def: Dictionary = WORKER_DEFS[index]
	var worker_inst = worker_scene.instantiate() as WorkerAvatar3D
	worker_inst.worker_name = def["name"]
	worker_inst.role = def["role"]
	worker_inst.home_desk_position = def["home"]
	worker_inst.patrol_targets = def["patrol"]
	worker_inst.position = def["home"]
	
	add_child(worker_inst)
	_workers.append(worker_inst)

func _on_campus_quest_completed(_q_id: String, _energy: float, _bonus: int) -> void:
	trigger_all_celebrate()
	_update_team_headcount()

func _on_zone_unlocked(_zone_id: String) -> void:
	trigger_all_celebrate()
	_update_team_headcount()

func _on_stat_updated(_stat_name: String, _val: float) -> void:
	_update_team_headcount()

## Celebrates across all workers when a milestone is achieved
func trigger_all_celebrate() -> void:
	team_celebration_started.emit()
	for worker in _workers:
		if is_instance_valid(worker) and worker.has_method("celebrate"):
			worker.celebrate(3.5)

## API for headless verification
func get_worker_count() -> int:
	return _workers.size()

func get_workers() -> Array[WorkerAvatar3D]:
	return _workers
