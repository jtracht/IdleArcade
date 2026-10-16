extends StaticBody3D
class_name DailyBoard3D

## 3D Interactive Daily Challenge Board for IdleArcade (Phase 12 Milestone 4).
## Low-poly wooden notice board with pin posts, chalkboard plate,
## proximity prompt "📋 [E] Daily Challenge Board", dynamic TouchControls
## registration ("Daily Board [E]"), and modal UI dispatch.

signal board_interacted()
signal board_opened()

@export var prompt_text: String = "📋 [E] Daily Challenge Board"
@export var action_label: String = "Daily Board [E]"

var _player_in_range: bool = false
var _avatar_ref: Node3D = null

@onready var interaction_area: Area3D = get_node_or_null("InteractionArea")
@onready var prompt_label: Label3D = get_node_or_null("PromptLabel3D")
@onready var board_light: OmniLight3D = get_node_or_null("Visuals/BoardLight")

func _ready() -> void:
	add_to_group("daily_boards")
	add_to_group("interactables")
	add_to_group("stations")

	if prompt_label != null:
		prompt_label.text = prompt_text
		prompt_label.visible = false

	if interaction_area != null:
		interaction_area.body_entered.connect(_on_interaction_body_entered)
		interaction_area.body_exited.connect(_on_interaction_body_exited)

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

## Alias for interact()
func open_daily_board() -> void:
	interact()

## Alias for interact()
func open_board() -> void:
	interact()

## Primary interaction entry point
func interact() -> void:
	board_interacted.emit()
	board_opened.emit()

	# 1. Play UI click/board sound
	var am = get_node_or_null("/root/AudioManager")
	if am != null:
		if am.has_method("play_sfx_click"):
			am.play_sfx_click()

	# 2. Gentle light flare tween
	if board_light != null:
		var lt = create_tween()
		lt.tween_property(board_light, "light_energy", 2.2, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		lt.tween_property(board_light, "light_energy", 1.0, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)

	# 3. Dispatch Daily Board modal opening via HUD
	_open_daily_board_modal()

func _open_daily_board_modal() -> void:
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
		if hud.has_method("open_daily_board_modal"):
			hud.open_daily_board_modal()
		elif ResourceLoader.exists("res://scenes/ui/daily_board_modal.tscn"):
			var modal_scene = load("res://scenes/ui/daily_board_modal.tscn")
			if modal_scene != null and hud.has_method("open_modal"):
				hud.open_modal(modal_scene)
		elif main_3d != null and main_3d.has_method("open_hud_overlay") and not main_3d.is_hud_overlay_open():
			main_3d.open_hud_overlay()
	elif main_3d != null and main_3d.has_method("open_hud_overlay") and not main_3d.is_hud_overlay_open():
		main_3d.open_hud_overlay()
