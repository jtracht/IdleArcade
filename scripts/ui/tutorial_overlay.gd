extends CanvasLayer
class_name TutorialOverlay

## TutorialOverlay for IdleArcade (Phase 17 Milestone 1).
## Darkened backdrop with an unblocked cutout over active UI targets using a 4-blocker
## input mask (mouse_filter = STOP surrounding an unblocked hole mouse_filter = IGNORE)
## for 100% native touch/click event passthrough, animated procedural directional arrow,
## and persistent Skip button (custom_minimum_size >= 56px).

signal skip_pressed()
signal highlight_updated(target_rect: Rect2)
signal highlight_cleared()

@export var overlay_layer: int = 95
@export var dim_color: Color = Color(0.0, 0.0, 0.0, 0.65)
@export var spotlight_color: Color = Color(1.0, 0.84, 0.0, 0.85)
@export var default_padding: float = 8.0

@onready var top_blocker: ColorRect = get_node_or_null("%TopBlocker")
@onready var bottom_blocker: ColorRect = get_node_or_null("%BottomBlocker")
@onready var left_blocker: ColorRect = get_node_or_null("%LeftBlocker")
@onready var right_blocker: ColorRect = get_node_or_null("%RightBlocker")
@onready var spotlight_frame: ReferenceRect = get_node_or_null("%SpotlightFrame")
@onready var arrow_indicator: Control = get_node_or_null("%ArrowIndicator")
@onready var directional_arrow: Control = get_node_or_null("%ArrowIndicator")
@onready var skip_button: Button = get_node_or_null("%SkipButton")

var _is_highlight_active: bool = false
var _current_target_rect: Rect2 = Rect2()
var _current_cutout_rect: Rect2 = Rect2()
var _current_padding: float = 8.0
var _target_control: Control = null

var _arrow_active: bool = false
var _arrow_base_pos: Vector2 = Vector2.ZERO
var _arrow_direction: Vector2 = Vector2.DOWN
var _bounce_time: float = 0.0

const BOUNCE_SPEED: float = 5.0
const BOUNCE_AMPLITUDE: float = 12.0

func _ready() -> void:
	layer = overlay_layer
	_ensure_nodes()
	
	if skip_button != null:
		if not skip_button.pressed.is_connected(_on_skip_button_pressed):
			skip_button.pressed.connect(_on_skip_button_pressed)
		skip_button.visible = true
	
	if is_inside_tree() and get_viewport() != null:
		if not get_viewport().size_changed.is_connected(_on_viewport_size_changed):
			get_viewport().size_changed.connect(_on_viewport_size_changed)
	
	clear_highlight()

func _process(delta: float) -> void:
	if _is_highlight_active and is_instance_valid(_target_control):
		if _target_control.is_inside_tree() and _target_control.is_visible_in_tree():
			var g_rect: Rect2 = _target_control.get_global_rect()
			if not g_rect.is_equal_approx(_current_target_rect):
				highlight_target_rect(g_rect, _current_padding)

	if _arrow_active and arrow_indicator != null and arrow_indicator.visible:
		_bounce_time += delta * BOUNCE_SPEED
		var offset: float = sin(_bounce_time) * BOUNCE_AMPLITUDE
		arrow_indicator.position = _arrow_base_pos + _arrow_direction * offset
		var pulse: float = 1.0 + sin(_bounce_time * 1.5) * 0.08
		arrow_indicator.scale = Vector2(pulse, pulse)

## Guarantees all blocker nodes exist even if instantiated via .new() in headless tests
func _ensure_nodes() -> void:
	if top_blocker == null:
		top_blocker = get_node_or_null("%TopBlocker") if get_node_or_null("%TopBlocker") != null else get_node_or_null("TopBlocker")
	if bottom_blocker == null:
		bottom_blocker = get_node_or_null("%BottomBlocker") if get_node_or_null("%BottomBlocker") != null else get_node_or_null("BottomBlocker")
	if left_blocker == null:
		left_blocker = get_node_or_null("%LeftBlocker") if get_node_or_null("%LeftBlocker") != null else get_node_or_null("LeftBlocker")
	if right_blocker == null:
		right_blocker = get_node_or_null("%RightBlocker") if get_node_or_null("%RightBlocker") != null else get_node_or_null("RightBlocker")
	if spotlight_frame == null:
		spotlight_frame = get_node_or_null("%SpotlightFrame") if get_node_or_null("%SpotlightFrame") != null else get_node_or_null("SpotlightFrame")
	if arrow_indicator == null:
		arrow_indicator = get_node_or_null("%ArrowIndicator") if get_node_or_null("%ArrowIndicator") != null else get_node_or_null("ArrowIndicator")
	if directional_arrow == null:
		directional_arrow = arrow_indicator
	if skip_button == null:
		skip_button = get_node_or_null("%SkipButton") if get_node_or_null("%SkipButton") != null else get_node_or_null("SkipButton")

	if top_blocker == null:
		top_blocker = ColorRect.new()
		top_blocker.name = "TopBlocker"
		top_blocker.unique_name_in_owner = true
		add_child(top_blocker)
	if bottom_blocker == null:
		bottom_blocker = ColorRect.new()
		bottom_blocker.name = "BottomBlocker"
		bottom_blocker.unique_name_in_owner = true
		add_child(bottom_blocker)
	if left_blocker == null:
		left_blocker = ColorRect.new()
		left_blocker.name = "LeftBlocker"
		left_blocker.unique_name_in_owner = true
		add_child(left_blocker)
	if right_blocker == null:
		right_blocker = ColorRect.new()
		right_blocker.name = "RightBlocker"
		right_blocker.unique_name_in_owner = true
		add_child(right_blocker)

	for b: ColorRect in [top_blocker, bottom_blocker, left_blocker, right_blocker]:
		b.mouse_filter = Control.MOUSE_FILTER_STOP
		b.color = dim_color

	if spotlight_frame == null:
		spotlight_frame = ReferenceRect.new()
		spotlight_frame.name = "SpotlightFrame"
		spotlight_frame.unique_name_in_owner = true
		spotlight_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		spotlight_frame.border_color = spotlight_color
		spotlight_frame.border_width = 3.0
		spotlight_frame.editor_only = false
		spotlight_frame.visible = false
		add_child(spotlight_frame)

	if arrow_indicator == null:
		arrow_indicator = _create_arrow_node()
		arrow_indicator.name = "ArrowIndicator"
		arrow_indicator.unique_name_in_owner = true
		directional_arrow = arrow_indicator
		add_child(arrow_indicator)

	if skip_button == null:
		skip_button = Button.new()
		skip_button.name = "SkipButton"
		skip_button.unique_name_in_owner = true
		skip_button.custom_minimum_size = Vector2(140, 56)
		skip_button.mouse_filter = Control.MOUSE_FILTER_STOP
		skip_button.text = "Überspringen ⏩"
		skip_button.offset_left = -160.0
		skip_button.offset_top = 28.0
		skip_button.offset_right = -20.0
		skip_button.offset_bottom = 84.0
		skip_button.anchor_left = 1.0
		skip_button.anchor_right = 1.0
		add_child(skip_button)

func _create_arrow_node() -> Control:
	var ctrl = Control.new()
	ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ctrl.visible = false

	# Drop shadow
	var shadow = Polygon2D.new()
	shadow.name = "Shadow"
	shadow.color = Color(0.0, 0.0, 0.0, 0.45)
	shadow.polygon = PackedVector2Array([
		Vector2(18.0, 3.0),
		Vector2(-14.0, -15.0),
		Vector2(-6.0, 3.0),
		Vector2(-14.0, 21.0)
	])
	ctrl.add_child(shadow)

	# Main polygon fill: Cyber Gold
	var poly = Polygon2D.new()
	poly.name = "Fill"
	poly.color = Color(1.0, 0.84, 0.15, 1.0)
	poly.polygon = PackedVector2Array([
		Vector2(18.0, 0.0),
		Vector2(-14.0, -18.0),
		Vector2(-6.0, 0.0),
		Vector2(-14.0, 18.0)
	])
	ctrl.add_child(poly)

	# Outer outline stroke
	var outline = Line2D.new()
	outline.name = "Outline"
	outline.width = 3.0
	outline.default_color = Color(0.06, 0.08, 0.14, 0.95)
	outline.points = PackedVector2Array([
		Vector2(18.0, 0.0),
		Vector2(-14.0, -18.0),
		Vector2(-6.0, 0.0),
		Vector2(-14.0, 18.0),
		Vector2(18.0, 0.0)
	])
	ctrl.add_child(outline)

	# Inner accent line
	var inner = Line2D.new()
	inner.name = "InnerAccent"
	inner.width = 1.5
	inner.default_color = Color(1.0, 1.0, 0.75, 0.85)
	inner.points = PackedVector2Array([
		Vector2(10.0, 0.0),
		Vector2(-10.0, -11.0),
		Vector2(-3.0, 0.0),
		Vector2(-10.0, 11.0),
		Vector2(10.0, 0.0)
	])
	ctrl.add_child(inner)

	return ctrl

## Robust viewport dimension acquisition supporting headless mode and detached nodes
func get_viewport_dimensions() -> Vector2:
	if DisplayServer.get_name() == "headless":
		var def_w: float = float(ProjectSettings.get_setting("display/window/size/viewport_width", 720))
		var def_h: float = float(ProjectSettings.get_setting("display/window/size/viewport_height", 1280))
		return Vector2(maxf(def_w, 720.0), maxf(def_h, 1280.0))
	
	if is_inside_tree() and get_viewport() != null:
		var vp_size: Vector2 = get_viewport().get_visible_rect().size
		if vp_size.x > 100.0 and vp_size.y > 100.0:
			return vp_size
			
	var def_w: float = float(ProjectSettings.get_setting("display/window/size/viewport_width", 720))
	var def_h: float = float(ProjectSettings.get_setting("display/window/size/viewport_height", 1280))
	return Vector2(maxf(def_w, 720.0), maxf(def_h, 1280.0))

## Calculates arrow placement, direction vector, and rotation angle given cutout bounds
func calculate_arrow_transform(cutout_rect: Rect2, vp_size: Vector2) -> Dictionary:
	if vp_size.x <= 0.0 or vp_size.y <= 0.0:
		vp_size = Vector2(720.0, 1280.0)
		
	var target_center = cutout_rect.get_center()
	var margin: float = 40.0
	var arrow_gap: float = 36.0
	
	var dir: Vector2 = Vector2.DOWN
	var base_pos: Vector2 = Vector2.ZERO
	
	if target_center.y > vp_size.y * 0.5:
		# Target in lower half: place ABOVE pointing DOWN
		dir = Vector2.DOWN
		base_pos = Vector2(target_center.x, cutout_rect.position.y - arrow_gap)
		# Edge flip guard: if too close to top
		if base_pos.y < margin:
			dir = Vector2.UP
			base_pos = Vector2(target_center.x, cutout_rect.end.y + arrow_gap)
	else:
		# Target in upper half: place BELOW pointing UP
		dir = Vector2.UP
		base_pos = Vector2(target_center.x, cutout_rect.end.y + arrow_gap)
		# Edge flip guard: if too close to bottom
		if base_pos.y > vp_size.y - margin:
			dir = Vector2.DOWN
			base_pos = Vector2(target_center.x, cutout_rect.position.y - arrow_gap)
			
	# Clamp within screen bounds
	base_pos.x = clampf(base_pos.x, margin, vp_size.x - margin)
	base_pos.y = clampf(base_pos.y, margin, vp_size.y - margin)
	
	return {
		"position": base_pos,
		"direction": dir,
		"rotation": dir.angle()
	}

## Highlights an arbitrary target rectangle in viewport coordinates
func highlight_target_rect(target_rect: Rect2, padding: float = 8.0) -> void:
	_ensure_nodes()
	_current_target_rect = target_rect
	_current_padding = padding
	_is_highlight_active = true

	var vp_size: Vector2 = get_viewport_dimensions()
	var vp_w: float = vp_size.x
	var vp_h: float = vp_size.y

	var p_pos: Vector2 = target_rect.position - Vector2(padding, padding)
	var p_size: Vector2 = target_rect.size + Vector2(padding * 2.0, padding * 2.0)

	var x0: float = clampf(p_pos.x, 0.0, vp_w)
	var y0: float = clampf(p_pos.y, 0.0, vp_h)
	var x1: float = clampf(p_pos.x + p_size.x, 0.0, vp_w)
	var y1: float = clampf(p_pos.y + p_size.y, 0.0, vp_h)

	if x1 < x0:
		x1 = x0
	if y1 < y0:
		y1 = y0

	_current_cutout_rect = Rect2(Vector2(x0, y0), Vector2(maxf(0.0, x1 - x0), maxf(0.0, y1 - y0)))

	# 1. Top Blocker
	top_blocker.position = Vector2(0.0, 0.0)
	top_blocker.size = Vector2(vp_w, y0)
	top_blocker.visible = (y0 > 0.0)

	# 2. Bottom Blocker
	bottom_blocker.position = Vector2(0.0, y1)
	bottom_blocker.size = Vector2(vp_w, maxf(0.0, vp_h - y1))
	bottom_blocker.visible = ((vp_h - y1) > 0.0)

	# 3. Left Blocker
	left_blocker.position = Vector2(0.0, y0)
	left_blocker.size = Vector2(x0, maxf(0.0, y1 - y0))
	left_blocker.visible = (x0 > 0.0 and (y1 - y0) > 0.0)

	# 4. Right Blocker
	right_blocker.position = Vector2(x1, y0)
	right_blocker.size = Vector2(maxf(0.0, vp_w - x1), maxf(0.0, y1 - y0))
	right_blocker.visible = ((vp_w - x1) > 0.0 and (y1 - y0) > 0.0)

	_update_spotlight_frame_and_arrow(x0, y0, x1, y1, vp_size)
	highlight_updated.emit(target_rect)

## Highlights a target Control node directly using its global rectangle
func highlight_control(control: Control, padding: float = 8.0) -> void:
	if control == null:
		clear_highlight()
		return
	
	_target_control = control
	var rect: Rect2
	if control.is_inside_tree():
		rect = control.get_global_rect()
	else:
		rect = Rect2(control.position, control.size)
	
	highlight_target_rect(rect, padding)

## Clears active highlight, hiding blockers and directional indicators
func clear_highlight() -> void:
	_is_highlight_active = false
	_target_control = null
	_current_target_rect = Rect2()
	_current_cutout_rect = Rect2()
	_arrow_active = false

	_ensure_nodes()
	if top_blocker != null:
		top_blocker.visible = false
		top_blocker.size = Vector2.ZERO
	if bottom_blocker != null:
		bottom_blocker.visible = false
		bottom_blocker.size = Vector2.ZERO
	if left_blocker != null:
		left_blocker.visible = false
		left_blocker.size = Vector2.ZERO
	if right_blocker != null:
		right_blocker.visible = false
		right_blocker.size = Vector2.ZERO
	if spotlight_frame != null:
		spotlight_frame.visible = false
	if arrow_indicator != null:
		arrow_indicator.visible = false

	highlight_cleared.emit()

## Sets visibility of the Skip button
func set_skip_visible(p_visible: bool) -> void:
	if skip_button != null:
		skip_button.visible = p_visible

func _on_skip_button_pressed() -> void:
	var am = get_node_or_null("/root/AudioManager")
	if am != null and am.has_method("play_sfx_click"):
		am.play_sfx_click()
	skip_pressed.emit()

func _on_viewport_size_changed() -> void:
	if _is_highlight_active:
		if is_instance_valid(_target_control) and _target_control.is_inside_tree():
			highlight_target_rect(_target_control.get_global_rect(), _current_padding)
		elif _current_target_rect.size.x > 0.0 or _current_target_rect.size.y > 0.0:
			highlight_target_rect(_current_target_rect, _current_padding)

func _update_spotlight_frame_and_arrow(x0: float, y0: float, x1: float, y1: float, vp_size: Vector2) -> void:
	var hole_w: float = x1 - x0
	var hole_h: float = y1 - y0

	if hole_w <= 0.0 or hole_h <= 0.0:
		if spotlight_frame != null:
			spotlight_frame.visible = false
		if arrow_indicator != null:
			arrow_indicator.visible = false
		_arrow_active = false
		return

	# Update spotlight frame
	if spotlight_frame != null:
		spotlight_frame.visible = true
		spotlight_frame.position = Vector2(x0, y0)
		spotlight_frame.size = Vector2(hole_w, hole_h)
		spotlight_frame.border_color = spotlight_color

	# Update directional arrow
	if arrow_indicator != null:
		var transform_data = calculate_arrow_transform(_current_cutout_rect, vp_size)
		_arrow_base_pos = transform_data.position
		_arrow_direction = transform_data.direction
		arrow_indicator.rotation = transform_data.rotation
		arrow_indicator.position = _arrow_base_pos
		arrow_indicator.visible = true
		_arrow_active = true

# =============================================================================
# Query & Verification Inspection API
# =============================================================================

func is_highlight_active() -> bool:
	return _is_highlight_active

func get_current_target_rect() -> Rect2:
	return _current_target_rect

func get_cutout_rect() -> Rect2:
	return _current_cutout_rect

func get_blocker_rects() -> Dictionary:
	_ensure_nodes()
	return {
		"top": Rect2(top_blocker.position, top_blocker.size),
		"bottom": Rect2(bottom_blocker.position, bottom_blocker.size),
		"left": Rect2(left_blocker.position, left_blocker.size),
		"right": Rect2(right_blocker.position, right_blocker.size),
	}

func is_point_in_cutout(point: Vector2) -> bool:
	if not _is_highlight_active:
		return false
	return _current_cutout_rect.has_point(point)

func is_point_in_blocker(point: Vector2) -> bool:
	_ensure_nodes()
	return (top_blocker.visible and Rect2(top_blocker.position, top_blocker.size).has_point(point)) \
		or (bottom_blocker.visible and Rect2(bottom_blocker.position, bottom_blocker.size).has_point(point)) \
		or (left_blocker.visible and Rect2(left_blocker.position, left_blocker.size).has_point(point)) \
		or (right_blocker.visible and Rect2(right_blocker.position, right_blocker.size).has_point(point))

func get_skip_button() -> Button:
	_ensure_nodes()
	return skip_button
