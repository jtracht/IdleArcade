extends Control
class_name DialoguePanel

## Interactive Dialogue & Quest Panel for 3D NPCs (Phase 4 Milestone P4-M3 & Phase 11 Milestone M1).
## Displays NPC name, role, dialogue lines, branched choices, quest objectives, and claim buttons.
## Isolates player avatar input while open and restores it when closed.

signal quest_accepted(quest_id: String)
signal quest_completed(quest_id: String)
signal closed()
signal choice_selected(choice_id: String, reward_type: String, reward_value: float)
signal campaign_advanced(chapter: int)

@onready var name_label: Label = get_node_or_null("%NPCNameLabel")
@onready var title_label: Label = get_node_or_null("%NPCTitleLabel")
@onready var dialogue_label: Label = get_node_or_null("%DialogueLabel")
@onready var choice_container: VBoxContainer = get_node_or_null("%ChoiceContainer")
@onready var choice_button_1: Button = get_node_or_null("%ChoiceButton1")
@onready var choice_button_2: Button = get_node_or_null("%ChoiceButton2")
@onready var choice_button_3: Button = get_node_or_null("%ChoiceButton3")
@onready var quest_box: VBoxContainer = get_node_or_null("%QuestBox")
@onready var quest_title_label: Label = get_node_or_null("%QuestTitleLabel")
@onready var quest_desc_label: Label = get_node_or_null("%QuestDescLabel")
@onready var quest_progress_label: Label = get_node_or_null("%QuestProgressLabel")
@onready var quest_reward_label: Label = get_node_or_null("%QuestRewardLabel")
@onready var accept_button: Button = get_node_or_null("%AcceptButton")
@onready var complete_button: Button = get_node_or_null("%CompleteButton")
@onready var close_button: Button = get_node_or_null("%CloseButton")
@onready var avatar_badge: ColorRect = get_node_or_null("%AvatarBadge")

var _current_npc_id: String = ""
var _current_quest_id: String = ""
var _quest_target: int = 1
var _reward_energy: float = 0.0
var _reward_bonus: int = 0
var _avatar_ref: Node = null
var _current_chapter: int = 1
var _current_choices: Array = []
var _current_quest_title: String = ""
var _current_quest_desc: String = ""

# Predefined branched narrative dialogue data for 3 chapters
const CHAPTER_CHOICES: Dictionary = {
	1: [
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
	],
	2: [
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
	],
	3: [
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

func _ready() -> void:
	if accept_button != null:
		accept_button.pressed.connect(_on_accept_pressed)
	if complete_button != null:
		complete_button.pressed.connect(_on_complete_pressed)
	if close_button != null:
		close_button.pressed.connect(close_dialogue)
	if choice_button_1 != null:
		choice_button_1.pressed.connect(func(): _on_choice_pressed(0))
	if choice_button_2 != null:
		choice_button_2.pressed.connect(func(): _on_choice_pressed(1))
	if choice_button_3 != null:
		choice_button_3.pressed.connect(func(): _on_choice_pressed(2))
		
	# Listen for Escape key to close
	set_process_unhandled_input(true)

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.is_echo():
		if event.keycode == KEY_ESCAPE:
			close_dialogue()
			get_viewport().set_input_as_handled()

func open_for_npc(
	npc_id: String,
	npc_name: String,
	npc_title: String,
	dialogue_text: String,
	quest_id: String = "",
	quest_title: String = "",
	quest_desc: String = "",
	quest_target: int = 1,
	reward_energy: float = 0.0,
	reward_bonus: int = 0,
	badge_color: Color = Color(0.2, 0.7, 1.0),
	avatar: Node = null,
	choices: Array = [],
	chapter: int = 0
) -> void:
	_current_npc_id = npc_id
	_current_quest_id = quest_id
	_current_quest_title = quest_title
	_current_quest_desc = quest_desc
	_quest_target = quest_target
	_reward_energy = reward_energy
	_reward_bonus = reward_bonus
	_avatar_ref = avatar
	
	if chapter > 0:
		_current_chapter = chapter
	else:
		if npc_id == "ceo_alex":
			_current_chapter = 1
		elif npc_id == "architect_bob":
			_current_chapter = 2
		elif npc_id == "scientist_lisa":
			_current_chapter = 3
		else:
			var gs_lookup = get_node_or_null("/root/GameState")
			_current_chapter = gs_lookup.get_campaign_chapter() if gs_lookup != null else 1
			
	if not choices.is_empty():
		_current_choices = choices
	elif CHAPTER_CHOICES.has(_current_chapter):
		_current_choices = CHAPTER_CHOICES[_current_chapter]
	else:
		_current_choices = []
	
	if _avatar_ref != null and _avatar_ref.has_method("set_input_enabled"):
		_avatar_ref.set_input_enabled(false)
		
	if name_label != null:
		name_label.text = npc_name
	if title_label != null:
		title_label.text = npc_title
	if dialogue_label != null:
		dialogue_label.text = dialogue_text
	if avatar_badge != null:
		avatar_badge.color = badge_color
		
	var gs = get_node_or_null("/root/GameState")
	var has_chosen: bool = false
	if gs != null:
		has_chosen = gs.campaign_choices.has(str(_current_chapter)) or gs.campaign_choices.has(_current_chapter)
		
	if not _current_choices.is_empty() and not has_chosen:
		_show_choice_ui()
	else:
		if choice_container != null:
			choice_container.visible = false
		_refresh_quest_ui(_current_quest_title, _current_quest_desc)
		
	visible = true

func _show_choice_ui() -> void:
	if choice_container != null:
		choice_container.visible = true
	if quest_box != null:
		quest_box.visible = false
	if accept_button != null:
		accept_button.visible = false
	if complete_button != null:
		complete_button.visible = false
		
	var btns = [choice_button_1, choice_button_2, choice_button_3]
	for i in range(btns.size()):
		var btn = btns[i]
		if btn != null:
			if i < _current_choices.size():
				var c = _current_choices[i]
				btn.text = str(c.get("text", "Option %d" % (i + 1)))
				btn.visible = true
			else:
				btn.visible = false

func _on_choice_pressed(index: int) -> void:
	if index < 0 or index >= _current_choices.size():
		return
	var choice = _current_choices[index]
	var choice_id: String = str(choice.get("id", "choice_%d" % index))
	var reward_type: String = str(choice.get("reward_type", ""))
	var reward_val: float = float(choice.get("reward_value", 0.0))
	var duration: float = float(choice.get("duration", 0.0))
	var reaction: String = str(choice.get("reaction", ""))
	
	if not reaction.is_empty() and dialogue_label != null:
		dialogue_label.text = reaction
		
	var gs = get_node_or_null("/root/GameState")
	if gs != null and gs.has_method("record_campaign_choice"):
		gs.record_campaign_choice(_current_chapter, choice_id, reward_type, reward_val, duration)
		
	var am = get_node_or_null("/root/AudioManager")
	if am != null and am.has_method("play_sfx_click"):
		am.play_sfx_click()
		
	choice_selected.emit(choice_id, reward_type, reward_val)
	
	if choice_container != null:
		choice_container.visible = false
		
	_refresh_quest_ui(_current_quest_title, _current_quest_desc)

func _refresh_quest_ui(quest_title: String = "", quest_desc: String = "") -> void:
	if quest_title.is_empty():
		quest_title = _current_quest_title
	if quest_desc.is_empty():
		quest_desc = _current_quest_desc
	if _current_quest_id.is_empty():
		if quest_box != null:
			quest_box.visible = false
		if accept_button != null:
			accept_button.visible = false
		if complete_button != null:
			complete_button.visible = false
		return
		
	if quest_box != null:
		quest_box.visible = true
	if quest_title_label != null and not quest_title.is_empty():
		quest_title_label.text = "📜 Quest: " + quest_title
	if quest_desc_label != null and not quest_desc.is_empty():
		quest_desc_label.text = quest_desc
		
	var gs = get_node_or_null("/root/GameState")
	var status: String = "not_started"
	var current_cnt: int = 0
	if gs != null and gs.has_method("get_campus_quest_status"):
		status = gs.get_campus_quest_status(_current_quest_id)
		if gs.campus_quests.has(_current_quest_id):
			current_cnt = int(gs.campus_quests[_current_quest_id].get("current_count", 0))
			
	# Reward text
	if quest_reward_label != null:
		var reward_str: String = ""
		if _reward_energy > 0:
			reward_str += "+" + str(int(_reward_energy)) + " Users"
		if _reward_bonus > 0:
			if not reward_str.is_empty():
				reward_str += "  •  "
			reward_str += "+" + str(_reward_bonus) + " Bonus Users"
		quest_reward_label.text = "Reward: " + reward_str
		
	# Button & progress state
	match status:
		"not_started":
			if quest_progress_label != null:
				quest_progress_label.text = "Status: Available (0/" + str(_quest_target) + ")"
				quest_progress_label.modulate = Color(1.0, 0.9, 0.4)
			if accept_button != null:
				accept_button.visible = true
				accept_button.text = "Accept Quest"
			if complete_button != null:
				complete_button.visible = false
		"active":
			if quest_progress_label != null:
				quest_progress_label.text = "Status: In Progress (" + str(current_cnt) + "/" + str(_quest_target) + ")"
				quest_progress_label.modulate = Color(0.4, 0.8, 1.0)
			if accept_button != null:
				accept_button.visible = false
			if complete_button != null:
				complete_button.visible = false
		"ready":
			if quest_progress_label != null:
				quest_progress_label.text = "Status: Objective Complete! (" + str(current_cnt) + "/" + str(_quest_target) + ")"
				quest_progress_label.modulate = Color(0.3, 1.0, 0.4)
			if accept_button != null:
				accept_button.visible = false
			if complete_button != null:
				complete_button.visible = true
				complete_button.text = "Claim Reward! 🎉"
		"completed":
			if quest_progress_label != null:
				quest_progress_label.text = "Status: Completed ✓"
				quest_progress_label.modulate = Color(0.6, 0.9, 0.6)
			if accept_button != null:
				accept_button.visible = false
			if complete_button != null:
				complete_button.visible = false

func _on_accept_pressed() -> void:
	var gs = get_node_or_null("/root/GameState")
	if gs != null and gs.has_method("start_campus_quest"):
		gs.start_campus_quest(_current_quest_id, _quest_target)
	quest_accepted.emit(_current_quest_id)
	_refresh_quest_ui(_current_quest_title, _current_quest_desc)

func _on_complete_pressed() -> void:
	var gs = get_node_or_null("/root/GameState")
	var old_chapter: int = gs.get_campaign_chapter() if gs != null else 1
	if gs != null and gs.has_method("complete_campus_quest"):
		gs.complete_campus_quest(_current_quest_id, _reward_energy, _reward_bonus)
	if gs != null and gs.get_campaign_chapter() != old_chapter:
		campaign_advanced.emit(gs.get_campaign_chapter())
		
	quest_completed.emit(_current_quest_id)
	var confetti_cls = load("res://scripts/vfx/confetti_burst.gd")
	if confetti_cls != null and confetti_cls.has_method("spawn_burst_2d"):
		var burst_pos = size * 0.5 if size != Vector2.ZERO else Vector2(250, 180)
		confetti_cls.spawn_burst_2d(self, burst_pos, 45)
	_refresh_quest_ui(_current_quest_title, _current_quest_desc)

func close_dialogue() -> void:
	visible = false
	if _avatar_ref != null and _avatar_ref.has_method("set_input_enabled"):
		_avatar_ref.set_input_enabled(true)
	closed.emit()
