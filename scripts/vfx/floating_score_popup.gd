class_name FloatingScorePopup3D
extends Node

## Reusable 3D Floating Score Popup for IdleArcade Campus Stations (Feature 26).
## Spawns a billboarded Label3D that punches in, floats upward, fades out, and auto-frees.

static func spawn_popup_3d(parent: Node, pos: Vector3, text: String, color: Color = Color.WHITE, duration: float = 1.3, float_dist: float = 1.6, font_size: int = 28) -> Label3D:
	if parent == null:
		return null
	var label := Label3D.new()
	label.name = "FloatingScorePopup3D"
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = font_size
	label.outline_size = 7
	label.outline_modulate = Color(0.02, 0.05, 0.02, 0.95)
	label.text = text
	label.modulate = color
	parent.add_child(label)
	
	if label.is_inside_tree():
		label.top_level = true
		label.global_position = pos
		# Scale punch animation (0.4 -> 1.25 -> 1.0)
		label.scale = Vector3(0.4, 0.4, 0.4)
		var tw_scale = label.create_tween()
		if tw_scale != null:
			tw_scale.tween_property(label, "scale", Vector3(1.25, 1.25, 1.25), 0.20).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw_scale.tween_property(label, "scale", Vector3.ONE, 0.15)
		
		# Upward translation and alpha fadeout
		var tw = label.create_tween()
		if tw != null:
			tw.set_parallel(true)
			tw.tween_property(label, "position:y", label.position.y + float_dist, duration).set_ease(Tween.EASE_OUT)
			tw.tween_property(label, "modulate:a", 0.0, duration * 0.55).set_delay(duration * 0.45)
			tw.chain().tween_callback(label.queue_free)
	else:
		label.position = pos
		label.queue_free()

	return label
