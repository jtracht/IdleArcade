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
var _anim_time: float = 0.0
var _emote_timer: float = 0.0

# Phase 11 Narrative Campaign Story & Branched Dialogue Definitions
const CAMPAIGN_STORY: Dictionary = {
	"ceo_alex": {
		"chapter": 1,
		"prompt": "Willkommen auf dem Tech-Campus! Wir starten unsere Unicorn-Reise aus dieser Garage. Um unser MVP zu launchen und die ersten 100 Nutzer zu begeistern: Welche Wachstumsstrategie schlägst du vor?",
		"choices": [
			{
				"id": "ch1_marketing",
				"text": "🚀 Aggressives Marketing (+500 Users)",
				"reaction": "Alex: Volles Risiko, maximale Traktion! Das virale Marketing sorgt für sofortige Bekanntheit auf dem ganzen Campus!",
				"reward_type": "users",
				"reward_value": 500.0,
				"duration": 0.0
			},
			{
				"id": "ch1_tech",
				"text": "🛡️ Stabile Technik (+100% RPS 30s)",
				"reaction": "Alex: Ausgezeichnete Ingenieursmentalität! Mit robuster Architektur überstehen wir jeden Nutzeransturm ohne Ausfälle!",
				"reward_type": "rps",
				"reward_value": 2.0,
				"duration": 30.0
			},
			{
				"id": "ch1_team",
				"text": "☕ Team-Kultur (+50% Speed 45s)",
				"reaction": "Alex: Ein motiviertes Team versetzt Berge! Lass uns direkt die ersten 3 Förderkoffer auf dem Campus einsammeln!",
				"reward_type": "speed",
				"reward_value": 1.5,
				"duration": 45.0
			}
		]
	},
	"architect_bob": {
		"chapter": 2,
		"prompt": "Die Series-A-Nutzerwelle überflutet unser Rechenzentrum! Wir müssen die Server stabilisieren und die R&D-Freigabe erlangen. Wie optimieren wir unsere Infrastruktur?",
		"choices": [
			{
				"id": "ch2_overclock",
				"text": "⚡ Cloud Overclocking (+100% RPS 45s)",
				"reaction": "Bob: Die Cores glühen! Unsere Durchsatzraten schießen durch die Decke!",
				"reward_type": "rps",
				"reward_value": 2.0,
				"duration": 45.0
			},
			{
				"id": "ch2_hardware",
				"text": "🔒 Hardware-Refactoring (+1500 Users)",
				"reaction": "Bob: Vorbildliche Ausfallsicherheit! Mit diesem Budget rüsten wir die Glasfaser-Backbones massiv auf.",
				"reward_type": "users",
				"reward_value": 1500.0,
				"duration": 0.0
			},
			{
				"id": "ch2_ops",
				"text": "🏃 Rapid Ops (+50% Speed 45s)",
				"reaction": "Bob: Schnelle Beine, schneller Code! Lauf zur Server-Konsole und führe den Cyber-Sync durch!",
				"reward_type": "speed",
				"reward_value": 1.5,
				"duration": 45.0
			}
		]
	},
	"scientist_lisa": {
		"chapter": 3,
		"prompt": "Willkommen im R&D-Labor! Wir stehen kurz vor der magischen Milliarden-Bewertung. Unsere neuronalen Quantenmodelle benötigen den finalen Durchbruch. Welches Forschungsfeld priorisieren wir?",
		"choices": [
			{
				"id": "ch3_quantum",
				"text": "🧠 Quantum Deep Learning (+200% RPS 60s)",
				"reaction": "Dr. Lisa: Phänomenal! Der Quantenalgorithmus potenziert unsere Nutzerbewertung auf Rekordniveau!",
				"reward_type": "rps",
				"reward_value": 3.0,
				"duration": 60.0
			},
			{
				"id": "ch3_espresso",
				"text": "☕ Super-Espresso Formula (+50% Speed 60s & +20% Worker)",
				"reaction": "Dr. Lisa: Höchste Koffein-Reinheit! Das Labor arbeitet mit übermenschlicher Effizienz!",
				"reward_type": "speed",
				"reward_value": 1.5,
				"duration": 60.0
			},
			{
				"id": "ch3_pitch",
				"text": "🦄 Mega-Venture Pitch (+5000 Users)",
				"reaction": "Dr. Lisa: Die Investoren sind begeistert! Der Term-Sheet über 1 Milliarde Dollar ist unterzeichnet!",
				"reward_type": "users",
				"reward_value": 5000.0,
				"duration": 0.0
			}
		]
	}
}

## Returns narrative campaign chapter associated with this NPC (1: Alex, 2: Bob, 3: Lisa).
func get_campaign_chapter() -> int:
	if CAMPAIGN_STORY.has(npc_id):
		return int(CAMPAIGN_STORY[npc_id].get("chapter", 1))
	return 1

## Returns branched dialogue options for this NPC.
func get_campaign_choices() -> Array:
	if CAMPAIGN_STORY.has(npc_id):
		return CAMPAIGN_STORY[npc_id].get("choices", [])
	return []

## Returns story prompt text for this NPC.
func get_campaign_prompt() -> String:
	if CAMPAIGN_STORY.has(npc_id):
		return str(CAMPAIGN_STORY[npc_id].get("prompt", dialogue_text))
	return dialogue_text

@onready var visuals: Node3D = get_node_or_null("Visuals")
@onready var body_mesh: MeshInstance3D = get_node_or_null("Visuals/BodyMesh")
@onready var name_label: Label3D = get_node_or_null("Visuals/NameLabel3D")
@onready var prompt_label: Label3D = get_node_or_null("Visuals/PromptLabel3D")
@onready var quest_marker: Label3D = get_node_or_null("Visuals/QuestMarkerLabel3D")
@onready var emote_label: Label3D = get_node_or_null("Visuals/EmoteLabel3D")
@onready var interaction_area: Area3D = get_node_or_null("InteractionArea")
@onready var chibi_root: Node3D = get_node_or_null("Visuals/ChibiRoot")
@onready var alex_accessories: Node3D = get_node_or_null("Visuals/ChibiRoot/AlexAccessories")
@onready var bob_accessories: Node3D = get_node_or_null("Visuals/ChibiRoot/BobAccessories")
@onready var lisa_accessories: Node3D = get_node_or_null("Visuals/ChibiRoot/LisaAccessories")
@onready var chibi_torso: MeshInstance3D = get_node_or_null("Visuals/ChibiRoot/Torso")
@onready var chibi_head: MeshInstance3D = get_node_or_null("Visuals/ChibiRoot/Head")

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
	_anim_time += delta
	
	# Procedural idle breathing and quest marker bounce
	if visuals != null:
		visuals.position.y = sin(_anim_time * 2.0) * 0.02
	if quest_marker != null and quest_marker.visible:
		quest_marker.position.y = 2.95 + sin(_anim_time * 3.5) * 0.08

	# Emote timer countdown
	if _emote_timer > 0.0:
		_emote_timer -= delta
		if _emote_timer <= 0.0 and emote_label != null:
			emote_label.visible = false

	# Smoothly turn to face player during active dialogue or when player is close
	if (_is_talking or _player_in_range) and is_instance_valid(_avatar_ref) and visuals != null:
		var diff = _avatar_ref.global_position - global_position
		diff.y = 0.0
		if diff.length_squared() > 0.05:
			var target_angle = atan2(diff.x, diff.z)
			visuals.rotation.y = lerp_angle(visuals.rotation.y, target_angle, 6.0 * delta)

## Displays an animated emote bubble above NPC head
func show_emote(symbol: String, duration: float = 2.5) -> void:
	if emote_label == null:
		return
	emote_label.text = symbol
	emote_label.visible = true
	_emote_timer = duration

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
		show_emote("💬", 2.0)
		var tc = _find_touch_controls()
		if tc != null and tc.has_method("register_interactable"):
			tc.register_interactable(self, "Talk [E]")

func _on_interaction_body_exited(body: Node3D) -> void:
	if body == _avatar_ref or body.is_in_group("player") or body is CharacterBody3D:
		_player_in_range = false
		if _is_talking:
			end_dialogue()
		_avatar_ref = null
		if prompt_label != null:
			prompt_label.visible = false
		var tc = _find_touch_controls()
		if tc != null and tc.has_method("unregister_interactable"):
			tc.unregister_interactable(self)

## Initiates interaction with NPC
func interact() -> void:
	_is_talking = true
	show_emote("💡", 3.0)
	if prompt_label != null:
		prompt_label.visible = false
	var tc = _find_touch_controls()
	if tc != null:
		if tc.has_method("unregister_interactable"):
			tc.unregister_interactable(self)
		if tc.has_method("fade_out_controls"):
			tc.fade_out_controls()
		
	# Find DialoguePanel in scene tree or Main3D
	var main_3d = get_tree().root.find_child("Main3D", true, false)
	var dialogue_panel = get_tree().root.find_child("DialoguePanel", true, false)
	
	if dialogue_panel != null and dialogue_panel.has_method("open_for_npc"):
		var story_prompt: String = get_campaign_prompt()
		var choices_to_pass: Array = get_campaign_choices()
		var chapter_to_pass: int = get_campaign_chapter()
		dialogue_panel.open_for_npc(
			npc_id,
			npc_name,
			npc_title,
			story_prompt,
			quest_id,
			quest_title,
			quest_desc,
			quest_target,
			quest_reward_energy,
			quest_reward_bonus,
			visual_color,
			_avatar_ref,
			choices_to_pass,
			chapter_to_pass
		)
		if not dialogue_panel.is_connected("closed", Callable(self, "end_dialogue")):
			dialogue_panel.closed.connect(end_dialogue, CONNECT_ONE_SHOT)
			
	dialogue_opened.emit(npc_id)

var _is_ending_dialogue: bool = false

func end_dialogue() -> void:
	if _is_ending_dialogue:
		return
	_is_ending_dialogue = true
	_is_talking = false
	
	var tree = get_tree()
	if tree != null and tree.root != null:
		var dialogue_panel = tree.root.find_child("DialoguePanel", true, false)
		if dialogue_panel != null and dialogue_panel.has_method("close_dialogue"):
			if dialogue_panel.visible:
				dialogue_panel.close_dialogue()
				
	var tc = _find_touch_controls()
	if tc != null and tc.has_method("fade_in_controls"):
		tc.fade_in_controls()
		
	if _player_in_range and prompt_label != null:
		prompt_label.visible = true
	if _player_in_range:
		if tc != null and tc.has_method("register_interactable"):
			tc.register_interactable(self, "Talk [E]")
	_update_quest_marker()
	dialogue_closed.emit(npc_id)
	_is_ending_dialogue = false

func _on_quest_updated(q_id: String, _status: String, _curr: int, _target: int) -> void:
	if q_id == quest_id:
		_update_quest_marker()

func _on_quest_completed(q_id: String, _energy: float, _bonus: int) -> void:
	if q_id == quest_id:
		show_emote("🎉", 4.0)
		_update_quest_marker()
		var confetti_cls = load("res://scripts/vfx/confetti_burst.gd")
		if confetti_cls != null and confetti_cls.has_method("spawn_burst_3d"):
			confetti_cls.spawn_burst_3d(get_parent() if get_parent() != null else self, global_position + Vector3(0.0, 2.0, 0.0), 50)

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

func _apply_chibi_accessories() -> void:
	if alex_accessories != null:
		alex_accessories.visible = (npc_id == "ceo_alex")
	if bob_accessories != null:
		bob_accessories.visible = (npc_id == "architect_bob")
	if lisa_accessories != null:
		lisa_accessories.visible = (npc_id == "scientist_lisa")

func _apply_visual_styling() -> void:
	var mat = StandardMaterial3D.new()
	mat.albedo_color = visual_color
	mat.roughness = 0.4
	mat.metallic = 0.1
	if body_mesh != null:
		body_mesh.material_override = mat
	if chibi_torso != null:
		chibi_torso.material_override = mat
		
	_apply_chibi_accessories()
		
	if name_label != null:
		name_label.text = npc_name + "\n" + npc_title

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
