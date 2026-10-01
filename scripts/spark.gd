extends Area2D

## Drifting Bonus Spark arcade mechanic.
## Drifts linearly with boundary bouncing, pulses scale via tween,
## awards windfall energy on tap, and auto-despawns after 8 seconds.

signal collected(reward: float)

@onready var spark_visual: Node2D = $SparkVisual
@onready var despawn_timer: Timer = $DespawnTimer
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var velocity: Vector2 = Vector2.ZERO
var drift_speed: float = 135.0
var bounce_bounds: Rect2 = Rect2(Vector2(50, 220), Vector2(620, 500))

var _pulse_tween: Tween
var _is_collected: bool = false

# Visual colors
const COLOR_GOLD_HALO: Color = Color(1.0, 0.85, 0.2, 0.3)
const COLOR_AMBER_RING: Color = Color(1.0, 0.7, 0.0, 0.9)
const COLOR_WHITE_CORE: Color = Color(1.0, 1.0, 1.0, 1.0)

func _ready() -> void:
	input_pickable = true
	input_event.connect(_on_input_event)
	if despawn_timer:
		despawn_timer.timeout.connect(_on_despawn_timer_timeout)
	
	# Randomize initial drift direction
	var random_angle: float = randf_range(0.0, TAU)
	velocity = Vector2.from_angle(random_angle) * drift_speed
	
	_start_pulse_tween()

func _process(delta: float) -> void:
	if _is_collected:
		return
		
	# Move spark
	position += velocity * delta
	
	# Bounce off playfield boundaries
	if position.x < bounce_bounds.position.x or position.x > bounce_bounds.end.x:
		velocity.x = -velocity.x
		position.x = clampf(position.x, bounce_bounds.position.x, bounce_bounds.end.x)
		
	if position.y < bounce_bounds.position.y or position.y > bounce_bounds.end.y:
		velocity.y = -velocity.y
		position.y = clampf(position.y, bounce_bounds.position.y, bounce_bounds.end.y)
		
	# Gentle rotation
	if spark_visual:
		spark_visual.rotation += 2.5 * delta
	queue_redraw()

func _draw() -> void:
	# 1. Outer celestial glow
	draw_circle(Vector2.ZERO, 32.0, COLOR_GOLD_HALO)
	
	# 2. Mid amber corona
	draw_arc(Vector2.ZERO, 20.0, 0.0, TAU, 32, COLOR_AMBER_RING, 3.0, true)
	
	# 3. 4-pointed radiant star
	var star_points: PackedVector2Array = [
		Vector2(0, -18), Vector2(4, -4), Vector2(18, 0), Vector2(4, 4),
		Vector2(0, 18), Vector2(-4, 4), Vector2(-18, 0), Vector2(-4, -4)
	]
	draw_colored_polygon(star_points, COLOR_WHITE_CORE)

func _start_pulse_tween() -> void:
	if not spark_visual:
		return
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_property(spark_visual, "scale", Vector2(1.22, 1.22), 0.38).set_trans(Tween.TRANS_SINE)
	_pulse_tween.tween_property(spark_visual, "scale", Vector2(0.85, 0.85), 0.38).set_trans(Tween.TRANS_SINE)

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_collect()
	elif event is InputEventScreenTouch and event.pressed:
		_collect()

func _collect() -> void:
	if _is_collected:
		return
	_is_collected = true
	
	if collision_shape:
		collision_shape.set_deferred("disabled", true)
	
	if _pulse_tween and _pulse_tween.is_valid():
		_pulse_tween.kill()
		
	# Calculate and register reward
	var reward: float = 50.0
	if GameState != null and GameState.has_method("collect_spark"):
		reward = GameState.collect_spark()
		
	collected.emit(reward)
	_spawn_bonus_text(reward)
	
	var pop_tween = create_tween().set_parallel(true)
	pop_tween.tween_property(self, "scale", Vector2(1.6, 1.6), 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	pop_tween.tween_property(self, "modulate:a", 0.0, 0.18)
	pop_tween.chain().tween_callback(queue_free)

func _spawn_bonus_text(reward: float) -> void:
	var label = Label.new()
	var formatted: String = GameState.format_number(reward) if GameState != null else str(int(reward))
	label.text = "+%s BONUS!" % formatted
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2))
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.position = global_position + Vector2(-60.0, -20.0)
	label.top_level = true
	
	var parent_node = get_parent()
	if parent_node:
		parent_node.add_child(label)
	else:
		add_child(label)
	
	var tween = label.create_tween().set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 80.0, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.7).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(label.queue_free)

func _on_despawn_timer_timeout() -> void:
	if _is_collected:
		return
	_is_collected = true
	
	var fade_tween = create_tween()
	fade_tween.tween_property(self, "modulate:a", 0.0, 0.45)
	fade_tween.tween_callback(queue_free)
