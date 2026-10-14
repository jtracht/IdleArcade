extends CharacterBody3D
class_name NPC3D

## 3D NPC Character for IdleArcade (Phase 4 Milestone P4-M3).
## Supports interaction trigger zones, floating billboarding 3D labels, quest indicator markers (! / ?),
## directional turning towards the player avatar, and opening the dialogue & quest interface.

signal dialogue_opened(npc_id: String)
signal dialogue_closed(npc_id: String)

@export var npc_id: String = "ceo_alex"
@export var npc_name: String = "Alex"
@export var npc_title: String = "Founder & CEO"
@export_multiline var dialogue_text: String = "Welcome to our Tech Campus! We're building the next unicorn startup. Grab the briefcases in the lobby and check in with Bob in the Server Room."
@export var quest_id: String = "quest_briefcases"
@export var quest_title: String = "Collect 3 Briefcases"
@export_multiline var quest_desc: String = "Gather 3 startup funding briefcases scattered across the campus grounds."
@export var quest_target: int = 3
@export var quest_reward_energy: float = 150.0
@export var quest_reward_bonus: int = 15
@export var visual_color: Color = Color(0.2, 0.8, 0.4)

var _player_in_range: bool = false
var _avatar_ref: Node3D = null
var _is_talking: bool = false

@onready var visuals: Node3D = get_node_or_null("Visuals")
@onready var body_mesh: MeshInstance3D = get_node_or_null("Visuals/BodyMesh")
@onready var name_label: Label3D = get_node_or_null("Visuals/NameLabel3D")
@onready var prompt_label: Label3D = get_node_or_null("Visuals/PromptLabel3D")
@onready var quest_marker: Label3D = get_node_or_null("Visuals/QuestMarkerLabel3D")
@onready var interaction_area: Area3D = get_node_or_null("InteractionArea")

func _ready() -> void:
	if not is_in_group("npcs"):
		add_to_group("npcs")
		
	collision_layer = 1
	collision_mask = 1
	
	_apply_visual_styling()
	
	if interaction_area != null:
		interaction_area.collision_layer = 0
		interaction_area.collision_mask = 1 # Detect Player (Layer 1)
		interaction_area.body_entered.connect(_on_interaction_body_entered)
		interaction_area.body_exited.connect(_on_interaction_body_exited)
		
	var gs = get_node_or_null("/root/GameState")
	if gs != null:
		if gs.has_signal("campus_quest_updated"):
			gs.campus_quest_updated.connect(_on_quest_updated)
		if gs.has_signal("campus_quest_completed"):
			gs.campus_quest_completed.connect(_on_quest_completed)
			
	_update_quest_marker()

func _process(delta: float) -> void:
	# Smoothly turn to face player during active dialogue or when player is close
	if (_is_talking or _player_in_range) and is_instance_valid(_avatar_ref) and visuals != null:
		var diff = _avatar_ref.global_position - global_position
		diff.y = 0.0
		if diff.length_squared() > 0.05:
			var target_angle = atan2(diff.x, diff.z)
			visuals.rotation.y = lerp_angle(visuals.rotation.y, target_angle, 6.0 * delta)

func _unhandled_input(event: InputEvent) -> void:
	if not _player_in_range or _is_talking:
		return
		
	if event is InputEventKey and event.pressed and not event.is_echo():
		if event.keycode == KEY_E:
			interact()
			get_viewport().set_input_as_handled()

func _on_interaction_body_entered(body: Node3D) -> void:
	if body.is_in_group("player") or body is CharacterBody3D:
		_player_in_range = true
		_avatar_ref = body
		if prompt_label != null:
			prompt_label.visible = true

func _on_interaction_body_exited(body: Node3D) -> void:
	if body == _avatar_ref or body.is_in_group("player") or body is CharacterBody3D:
		_player_in_range = false
		_avatar_ref = null
		if prompt_label != null:
			prompt_label.visible = false
		if _is_talking:
			end_dialogue()

## Initiates interaction with NPC
func interact() -> void:
	_is_talking = true
	if prompt_label != null:
		prompt_label.visible = false
		
	# Find DialoguePanel in scene tree or Main3D
	var main_3d = get_tree().root.find_child("Main3D", true, false)
	var dialogue_panel = get_tree().root.find_child("DialoguePanel", true, false)
	
	if dialogue_panel != null and dialogue_panel.has_method("open_for_npc"):
		dialogue_panel.open_for_npc(
			npc_id,
			npc_name,
			npc_title,
			dialogue_text,
			quest_id,
			quest_title,
			quest_desc,
			quest_target,
			quest_reward_energy,
			quest_reward_bonus,
			visual_color,
			_avatar_ref
		)
		if not dialogue_panel.is_connected("closed", Callable(self, "end_dialogue")):
			dialogue_panel.closed.connect(end_dialogue, CONNECT_ONE_SHOT)
			
	dialogue_opened.emit(npc_id)

func end_dialogue() -> void:
	_is_talking = false
	if _player_in_range and prompt_label != null:
		prompt_label.visible = true
	_update_quest_marker()
	dialogue_closed.emit(npc_id)

func _on_quest_updated(q_id: String, _status: String, _curr: int, _target: int) -> void:
	if q_id == quest_id:
		_update_quest_marker()

func _on_quest_completed(q_id: String, _energy: float, _bonus: int) -> void:
	if q_id == quest_id:
		_update_quest_marker()

func _update_quest_marker() -> void:
	if quest_marker == null or quest_id.is_empty():
		return
		
	var gs = get_node_or_null("/root/GameState")
	var status: String = "not_started"
	if gs != null and gs.has_method("get_campus_quest_status"):
		status = gs.get_campus_quest_status(quest_id)
		
	match status:
		"not_started":
			quest_marker.text = "!"
			quest_marker.modulate = Color(1.0, 0.85, 0.2) # Yellow exclamation
			quest_marker.visible = true
		"active":
			quest_marker.text = "..."
			quest_marker.modulate = Color(0.4, 0.8, 1.0) # In progress
			quest_marker.visible = true
		"ready":
			quest_marker.text = "?"
			quest_marker.modulate = Color(0.3, 1.0, 0.4) # Green question ready
			quest_marker.visible = true
		"completed":
			quest_marker.visible = false

func _apply_visual_styling() -> void:
	if body_mesh != null:
		var mat = StandardMaterial3D.new()
		mat.albedo_color = visual_color
		mat.roughness = 0.4
		mat.metallic = 0.1
		body_mesh.material_override = mat
		
	if name_label != null:
		name_label.text = npc_name + "\n" + npc_title
