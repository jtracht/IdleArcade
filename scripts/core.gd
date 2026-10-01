extends Area2D

## Interactive Reactor Core controller.
## Handles active tapping, punch scale tween animation, particle bursts,
## procedural sci-fi canvas rendering, and dynamic floating text numbers.

signal core_clicked(earned_amount: float)

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var visuals: Node2D = $Visuals
@onready var outer_ring: Node2D = $Visuals/OuterRing
@onready var plasma_core: Node2D = $Visuals/PlasmaCore
@onready var burst_particles: CPUParticles2D = $ClickBurstParticles
@onready var float_text_spawn: Marker2D = $FloatTextSpawn

var _punch_tween: Tween
var _core_rotation: float = 0.0
var _is_hovered: bool = false
var _last_tap_frame: int = -1

# Visual styling colors
const COLOR_CYAN: Color = Color(0.0, 0.9, 1.0, 1.0)
const COLOR_CYAN_DIM: Color = Color(0.0, 0.7, 0.9, 0.4)
const COLOR_FRENZY_RED: Color = Color(1.0, 0.2, 0.3, 1.0)
const COLOR_FRENZY_GOLD: Color = Color(1.0, 0.85, 0.2, 1.0)

func _ready() -> void:
	input_pickable = true
	input_event.connect(_on_input_event)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func _process(delta: float) -> void:
	var is_frenzy: bool = GameState != null and GameState.is_frenzy_active
	var rot_speed: float = 1.2 if is_frenzy else 0.5
	_core_rotation += rot_speed * delta
	if outer_ring:
		outer_ring.rotation = _core_rotation
	queue_redraw()

func _draw() -> void:
	var is_frenzy: bool = GameState != null and GameState.is_frenzy_active
	var primary_color: Color = COLOR_FRENZY_GOLD if is_frenzy else COLOR_CYAN
	var aura_color: Color = Color(COLOR_FRENZY_RED.r, COLOR_FRENZY_RED.g, COLOR_FRENZY_RED.b, 0.25) if is_frenzy else COLOR_CYAN_DIM
	
	# 1. Outer energy halo
	draw_circle(Vector2.ZERO, 92.0, aura_color)
	
	# 2. Outer containment ring
	draw_arc(Vector2.ZERO, 90.0, 0.0, TAU, 64, primary_color, 4.0, true)
	
	# 3. Rotating orbital notches
	for i in range(8):
		var angle: float = _core_rotation + (i * (TAU / 8.0))
		var inner_pt: Vector2 = Vector2.from_angle(angle) * 78.0
		var outer_pt: Vector2 = Vector2.from_angle(angle) * 94.0
		draw_line(inner_pt, outer_pt, primary_color, 3.0, true)
		
	# 4. Mid stabilizing ring
	draw_arc(Vector2.ZERO, 62.0, 0.0, TAU, 48, Color(primary_color.r, primary_color.g, primary_color.b, 0.7), 2.5, true)
	
	# 5. Core plasma sphere
	var core_color: Color = COLOR_FRENZY_RED if is_frenzy else Color(0.05, 0.75, 1.0, 0.95)
	draw_circle(Vector2.ZERO, 52.0, core_color)
	
	# 6. Central hyper-dense nucleus
	draw_circle(Vector2.ZERO, 24.0, Color(1.0, 1.0, 1.0, 0.95))

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_trigger_tap()
	elif event is InputEventScreenTouch and event.pressed:
		_trigger_tap()

func _on_mouse_entered() -> void:
	_is_hovered = true

func _on_mouse_exited() -> void:
	_is_hovered = false

func _trigger_tap() -> void:
	var current_frame: int = Engine.get_process_frames()
	if current_frame == _last_tap_frame:
		return
	_last_tap_frame = current_frame

	var earned: float = 1.0
	if GameState != null and GameState.has_method("tap_core"):
		earned = GameState.tap_core()
	
	core_clicked.emit(earned)
	_play_punch_tween()
	_emit_burst_particles()
	_spawn_float_text(earned)

func _play_punch_tween() -> void:
	if _punch_tween and _punch_tween.is_valid():
		_punch_tween.kill()
		
	_punch_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	scale = Vector2(1.18, 1.18)
	_punch_tween.tween_property(self, "scale", Vector2.ONE, 0.14)

func _emit_burst_particles() -> void:
	if not burst_particles:
		return
	var is_frenzy: bool = GameState != null and GameState.is_frenzy_active
	burst_particles.color = COLOR_FRENZY_GOLD if is_frenzy else COLOR_CYAN
	burst_particles.restart()
	burst_particles.emitting = true

func _spawn_float_text(earned: float) -> void:
	var label = Label.new()
	var formatted: String = GameState.format_number(earned) if GameState != null else str(int(earned))
	label.text = "+" + formatted
	
	var is_frenzy: bool = GameState != null and GameState.is_frenzy_active
	label.add_theme_font_size_override("font_size", 26 if is_frenzy else 22)
	label.add_theme_color_override("font_color", COLOR_FRENZY_GOLD if is_frenzy else Color(1.0, 1.0, 1.0))
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	
	var spawn_pos: Vector2 = float_text_spawn.global_position if float_text_spawn != null else global_position + Vector2(0, -60)
	var scatter_x: float = randf_range(-30.0, 30.0)
	label.position = spawn_pos + Vector2(scatter_x - 30.0, -10.0)
	label.top_level = true
	add_child(label)
	
	var tween = label.create_tween().set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 70.0, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.55).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(label.queue_free)
