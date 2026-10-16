extends StaticBody3D
class_name TechLabTerminal

## 3D Tech Lab Research Terminal for IdleArcade (Phase 8).
## Interactive console situated in the R&D Lab at (-19, 0, 0).
## Features a stylized sci-fi holographic pedestal, proximity detection,
## dynamic TouchControls integration ("Research [E]"), and modal UI dispatch.

signal research_opened()
signal terminal_interacted()

@export var terminal_id: String = "rd_research_terminal"
@export var prompt_text: String = "[E] R&D Research Station"
@export var hologram_spin_speed: float = 1.8
@export var hologram_bob_speed: float = 3.0
@export var hologram_bob_amplitude: float = 0.06

@onready var interaction_area: Area3D = get_node_or_null("InteractionArea")
@onready var prompt_label: Label3D = get_node_or_null("PromptLabel3D")
@onready var rotating_hologram: Node3D = get_node_or_null("Visuals/RotatingHologram")

var _player_in_range: bool = false
var _time: float = 0.0
var _base_hologram_y: float = 1.55
var _avatar_ref: Node3D = null

func _ready() -> void:
	add_to_group("terminals")
	add_to_group("research_terminals")
	
	if rotating_hologram != null:
		_base_hologram_y = rotating_hologram.position.y
		
	if prompt_label != null:
		prompt_label.text = prompt_text
		prompt_label.visible = false
		
	if interaction_area != null:
		interaction_area.body_entered.connect(_on_interaction_body_entered)
		interaction_area.body_exited.connect(_on_interaction_body_exited)

func _process(delta: float) -> void:
	_time += delta
	if rotating_hologram != null:
		rotating_hologram.rotate_y(hologram_spin_speed * delta)
		rotating_hologram.position.y = _base_hologram_y + sin(_time * hologram_bob_speed) * hologram_bob_amplitude

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
			tc.register_interactable(self, "Research [E]")

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

## Primary action handler (compatible with TouchControls direct action)
func interact() -> void:
	open_research()

## Dispatches TechTreeModal UI opening
func open_research() -> void:
	terminal_interacted.emit()
	research_opened.emit()
	
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
		if hud.has_method("open_tech_tree_modal"):
			hud.open_tech_tree_modal()
		elif ResourceLoader.exists("res://scenes/ui/tech_tree_modal.tscn"):
			var modal_scene = load("res://scenes/ui/tech_tree_modal.tscn")
			if modal_scene != null and hud.has_method("open_modal"):
				hud.open_modal(modal_scene)
		elif main_3d != null and main_3d.has_method("open_hud_overlay") and not main_3d.is_hud_overlay_open():
			main_3d.open_hud_overlay()
	elif main_3d != null and main_3d.has_method("open_hud_overlay") and not main_3d.is_hud_overlay_open():
		main_3d.open_hud_overlay()
