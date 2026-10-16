extends StaticBody3D
class_name IpoBell3D

## 3D Interactive IPO Bell for IdleArcade (Phase 12 Milestone 2).
## Ceremonial bronze bell situated at Courtyard entrance (0, 0, 12).
## Features an ornate stone pedestal with brass plaque, cast-iron yoke,
## pivoting bell assembly with clapper and crimson velvet pull cord,
## proximity prompt "🔔 [E] Ring IPO Bell", dynamic TouchControls registration ("IPO Bell [E]"),
## decaying oscillation swinging tween animation, procedural audio chime trigger,
## gold confetti shower, and IPO Modal UI dispatch.

signal bell_rung()
signal ipo_bell_interacted()

@export var prompt_text: String = "🔔 [E] Ring IPO Bell"
@export var action_label: String = "IPO Bell [E]"
@export var swing_angle_max: float = 24.0
@export var bell_swing_duration: float = 1.25

var is_ringing: bool = false
var _player_in_range: bool = false
var _avatar_ref: Node3D = null
var _swing_tween: Tween = null

@onready var interaction_area: Area3D = get_node_or_null("InteractionArea")
@onready var prompt_label: Label3D = get_node_or_null("PromptLabel3D")
@onready var bell_pivot: Node3D = get_node_or_null("Visuals/BellPivot")
@onready var gold_particles: CPUParticles3D = get_node_or_null("GoldParticles")
@onready var bell_light: OmniLight3D = get_node_or_null("Visuals/BellLight")

func _ready() -> void:
	add_to_group("ipo_bells")
	add_to_group("interactables")
	add_to_group("stations")

	if prompt_label != null:
		prompt_label.text = prompt_text
		prompt_label.visible = false

	if interaction_area != null:
		interaction_area.body_entered.connect(_on_interaction_body_entered)
		interaction_area.body_exited.connect(_on_interaction_body_exited)

	if gold_particles != null:
		gold_particles.emitting = false

func _unhandled_input(event: InputEvent) -> void:
	if not _player_in_range:
		return
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		if event.keycode == KEY_E:
			interact()
			get_viewport().set_input_as_handled()

func _on_interaction_body_entered(body: Node3D) -> void:
	if body.is_in_group("player") or body is CharacterBody3D:
		_player_in_range = true
		_avatar_ref = body
		if prompt_label != null:
			prompt_label.visible = true
		var tc = _find_touch_controls()
		if tc != null and tc.has_method("register_interactable"):
			tc.register_interactable(self, action_label)

func _on_interaction_body_exited(body: Node3D) -> void:
	if body == _avatar_ref or body.is_in_group("player") or body is CharacterBody3D:
		_player_in_range = false
		_avatar_ref = null
		if prompt_label != null:
			prompt_label.visible = false
		var tc = _find_touch_controls()
		if tc != null and tc.has_method("unregister_interactable"):
			tc.unregister_interactable(self)

func _exit_tree() -> void:
	var tc = _find_touch_controls()
	if tc != null and tc.has_method("unregister_interactable"):
		tc.unregister_interactable(self)

func _find_touch_controls() -> Node:
	var tree = get_tree()
	if tree == null:
		return null
	var tc_nodes = tree.get_nodes_in_group("touch_controls")
	if tc_nodes.size() > 0:
		return tc_nodes[0]
	return tree.root.find_child("TouchControls", true, false)

## Proximity status query
func is_player_in_range() -> bool:
	return _player_in_range

## Swinging status query
func is_swinging() -> bool:
	return is_ringing

## Alias for interact()
func ring_bell() -> void:
	interact()

## Alias for TouchControls routing
func ring_ipo_bell() -> void:
	interact()

## Primary interaction entry point
func interact() -> void:
	ipo_bell_interacted.emit()
	bell_rung.emit()

	# 1. Play procedural bell audio chime
	var am = get_node_or_null("/root/AudioManager")
	if am != null:
		if am.has_method("play_sfx_bell"):
			am.play_sfx_bell()
		elif am.has_method("play_sfx_confetti"):
			am.play_sfx_confetti()
		elif am.has_method("play_sfx_click"):
			am.play_sfx_click()

	# 2. Emit golden celebration particles
	if gold_particles != null:
		gold_particles.restart()
		gold_particles.emitting = true

	# Also trigger global confetti burst if available
	var confetti_cls = load("res://scripts/vfx/confetti_burst.gd")
	if confetti_cls != null and confetti_cls.has_method("spawn_burst_3d"):
		confetti_cls.spawn_burst_3d(get_parent() if get_parent() != null else self, global_position + Vector3(0.0, 2.0, 0.0), 40)

	# 3. Decaying oscillation swinging Tween on BellPivot.rotation_degrees:z
	if bell_pivot != null:
		if _swing_tween != null and _swing_tween.is_valid():
			_swing_tween.kill()

		is_ringing = true
		_swing_tween = create_tween()
		_swing_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_swing_tween.tween_property(bell_pivot, "rotation_degrees:z", swing_angle_max, 0.18)
		_swing_tween.tween_property(bell_pivot, "rotation_degrees:z", -swing_angle_max * 0.70, 0.22)
		_swing_tween.tween_property(bell_pivot, "rotation_degrees:z", swing_angle_max * 0.45, 0.24)
		_swing_tween.tween_property(bell_pivot, "rotation_degrees:z", -swing_angle_max * 0.25, 0.26)
		_swing_tween.tween_property(bell_pivot, "rotation_degrees:z", swing_angle_max * 0.10, 0.20)
		_swing_tween.tween_property(bell_pivot, "rotation_degrees:z", 0.0, 0.15)
		_swing_tween.finished.connect(func(): is_ringing = false)

	# 4. Light flash pulse
	if bell_light != null:
		var lt = create_tween()
		lt.tween_property(bell_light, "light_energy", 3.0, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		lt.tween_property(bell_light, "light_energy", 1.2, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)

	# 5. Screen shake juice
	var tree = get_tree()
	if tree != null and tree.root != null:
		var m3d = tree.root.find_child("Main3D", true, false)
		if m3d != null and m3d.has_method("add_screen_shake"):
			m3d.add_screen_shake(0.35)

	# 6. Dispatch IPO modal opening via HUD
	_open_ipo_modal()

func _open_ipo_modal() -> void:
	var tree = get_tree()
	if tree == null:
		return

	var main_3d = tree.current_scene
	var hud: Node = null

	if main_3d != null and "hud_instance" in main_3d and is_instance_valid(main_3d.hud_instance):
		hud = main_3d.hud_instance
	elif tree.get_nodes_in_group("hud").size() > 0:
		hud = tree.get_nodes_in_group("hud")[0]
	elif tree.root.find_child("HUD", true, false) != null:
		hud = tree.root.find_child("HUD", true, false)

	if hud != null:
		if hud.has_method("open_ipo_modal"):
			hud.open_ipo_modal()
		elif ResourceLoader.exists("res://scenes/ui/ipo_modal.tscn"):
			var modal_scene = load("res://scenes/ui/ipo_modal.tscn")
			if modal_scene != null and hud.has_method("open_modal"):
				hud.open_modal(modal_scene)
		elif main_3d != null and main_3d.has_method("open_hud_overlay") and not main_3d.is_hud_overlay_open():
			main_3d.open_hud_overlay()
	elif main_3d != null and main_3d.has_method("open_hud_overlay") and not main_3d.is_hud_overlay_open():
		main_3d.open_hud_overlay()
