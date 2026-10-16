class_name ConfettiBurst
extends Node

## ConfettiBurst: Dual-mode VFX burst container supporting both 3D campus
## (CPUParticles3D) and 2D HUD (CPUParticles2D) celebrations.
## Features auto cleanup (queue_free) via emitter finished signal & fallback timer.

signal burst_finished()

@onready var particles_3d: CPUParticles3D = get_node_or_null("Particles3D")
@onready var particles_2d: CPUParticles2D = get_node_or_null("Particles2D")

var _is_cleaning_up: bool = false
var _active_mode: String = ""

func _ready() -> void:
	pass

## Factory method to spawn and trigger a 3D confetti burst at world coordinate pos
static func spawn_burst_3d(parent: Node, pos: Vector3, particle_count: int = 40) -> Node:
	var scene = load("res://scenes/vfx/confetti_burst.tscn")
	if scene == null:
		return null
	var burst: ConfettiBurst = scene.instantiate()
	if parent != null:
		parent.add_child(burst)
	burst.emit_burst_3d(pos, particle_count)
	return burst

## Factory method to spawn and trigger a 2D confetti burst at canvas coordinate pos
static func spawn_burst_2d(parent: Node, pos: Vector2, particle_count: int = 40) -> Node:
	var scene = load("res://scenes/vfx/confetti_burst.tscn")
	if scene == null:
		return null
	var burst: ConfettiBurst = scene.instantiate()
	if parent != null:
		parent.add_child(burst)
	burst.emit_burst_2d(pos, particle_count)
	return burst

## Emits 3D particles at specified position and frees the unused 2D emitter
func emit_burst_3d(pos: Vector3, particle_count: int = 40) -> void:
	_active_mode = "3d"
	var p2d: Node = get_node_or_null("Particles2D")
	if p2d != null:
		p2d.queue_free()
	
	var p3d: CPUParticles3D = get_node_or_null("Particles3D")
	if p3d != null:
		p3d.amount = particle_count
		p3d.top_level = true
		p3d.global_position = pos
		if not p3d.finished.is_connected(_on_emitter_finished):
			p3d.finished.connect(_on_emitter_finished)
		p3d.restart()
		p3d.emitting = true
		_start_cleanup_timer(p3d.lifetime)
	else:
		_start_cleanup_timer(2.0)

## Emits 2D particles at specified position and frees the unused 3D emitter
func emit_burst_2d(pos: Vector2, particle_count: int = 40) -> void:
	_active_mode = "2d"
	var p3d: Node = get_node_or_null("Particles3D")
	if p3d != null:
		p3d.queue_free()
	
	var p2d: CPUParticles2D = get_node_or_null("Particles2D")
	if p2d != null:
		p2d.amount = particle_count
		p2d.position = pos
		if not p2d.finished.is_connected(_on_emitter_finished):
			p2d.finished.connect(_on_emitter_finished)
		p2d.restart()
		p2d.emitting = true
		_start_cleanup_timer(p2d.lifetime)
	else:
		_start_cleanup_timer(1.8)

func _start_cleanup_timer(lifetime: float) -> void:
	if is_inside_tree():
		var tree = get_tree()
		if tree != null:
			tree.create_timer(lifetime + 0.5).timeout.connect(_on_emitter_finished)
	else:
		ready.connect(func():
			var tree = get_tree()
			if tree != null and not _is_cleaning_up:
				tree.create_timer(lifetime + 0.5).timeout.connect(_on_emitter_finished)
		, CONNECT_ONE_SHOT)

func _on_emitter_finished() -> void:
	if _is_cleaning_up:
		return
	_is_cleaning_up = true
	burst_finished.emit()
	queue_free()
