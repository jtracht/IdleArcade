extends Node2D

## Main scene controller for IdleArcade.
## Orchestrates core interaction, spark spawning, auto-saving, and UI overlays.

const SPARK_SCENE: PackedScene = preload("res://scenes/spark.tscn")

@onready var spark_container: Node2D = $World/SparkContainer
@onready var spark_spawn_timer: Timer = $SparkSpawnTimer
@onready var auto_save_timer: Timer = $AutoSaveTimer
@onready var core_anchor: Marker2D = $World/CoreAnchor

# Spatial boundaries for spark spawning and drifting
const SPAWN_RECT: Rect2 = Rect2(Vector2(60, 220), Vector2(600, 480))

func _ready() -> void:
	print("[Main] IdleArcade root scene loaded successfully.")
	
	if GameState != null and GameState.has_method("load_from_disk"):
		GameState.load_from_disk()
	
	if spark_spawn_timer:
		spark_spawn_timer.timeout.connect(_on_spark_spawn_timer_timeout)
	if auto_save_timer:
		auto_save_timer.timeout.connect(_on_auto_save_timer_timeout)
	
	# Spawn an introductory spark after 5 seconds to prompt active gameplay
	get_tree().create_timer(5.0).timeout.connect(spawn_bonus_spark)

func _notification(what: int) -> void:
	# Guarantee state persistence on application suspension or exit
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		if GameState != null and GameState.has_method("save_to_disk"):
			print("[Main] Suspending / Exiting - executing auto-save.")
			GameState.save_to_disk()

func _on_spark_spawn_timer_timeout() -> void:
	spawn_bonus_spark()

func _on_auto_save_timer_timeout() -> void:
	if GameState != null and GameState.has_method("save_to_disk"):
		GameState.save_to_disk()

## Instantiates and spawns a drifting bonus spark in the active playfield
func spawn_bonus_spark() -> void:
	if not spark_container:
		return
	# Limit concurrent active sparks to 3
	if spark_container.get_child_count() >= 3:
		return
		
	var spark_instance = SPARK_SCENE.instantiate()
	
	# Randomize spawn position inside SPAWN_RECT
	var spawn_x: float = randf_range(SPAWN_RECT.position.x, SPAWN_RECT.end.x)
	var spawn_y: float = randf_range(SPAWN_RECT.position.y, SPAWN_RECT.end.y)
	spark_instance.position = Vector2(spawn_x, spawn_y)
	spark_instance.set("bounce_bounds", SPAWN_RECT)
	
	spark_container.add_child(spark_instance)
