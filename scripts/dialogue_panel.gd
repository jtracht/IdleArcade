extends Control
class_name DialoguePanel

## Interactive Dialogue & Quest Panel for 3D NPCs (Phase 4 Milestone P4-M3).
## Displays NPC name, role, dialogue lines, quest objectives, and claim buttons.
## Isolates player avatar input while open and restores it when closed.

signal quest_accepted(quest_id: String)
signal quest_completed(quest_id: String)
signal closed()

@onready var name_label: Label = get_node_or_null("%NPCNameLabel")
@onready var title_label: Label = get_node_or_null("%NPCTitleLabel")
@onready var dialogue_label: Label = get_node_or_null("%DialogueLabel")
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

func _ready() -> void:
	if accept_button != null:
		accept_button.pressed.connect(_on_accept_pressed)
	if complete_button != null:
		complete_button.pressed.connect(_on_complete_pressed)
	if close_button != null:
		close_button.pressed.connect(close_dialogue)
		
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
	avatar: Node = null
) -> void:
	_current_npc_id = npc_id
	_current_quest_id = quest_id
	_quest_target = quest_target
	_reward_energy = reward_energy
	_reward_bonus = reward_bonus
	_avatar_ref = avatar
	
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
		
	_refresh_quest_ui(quest_title, quest_desc)
	visible = true

func _refresh_quest_ui(quest_title: String, quest_desc: String) -> void:
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
	if quest_title_label != null:
		quest_title_label.text = "📜 Quest: " + quest_title
	if quest_desc_label != null:
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
	_refresh_quest_ui(
		quest_title_label.text.replace("📜 Quest: ", "") if quest_title_label else "",
		quest_desc_label.text if quest_desc_label else ""
	)

func _on_complete_pressed() -> void:
	var gs = get_node_or_null("/root/GameState")
	if gs != null and gs.has_method("complete_campus_quest"):
		gs.complete_campus_quest(_current_quest_id, _reward_energy, _reward_bonus)
	quest_completed.emit(_current_quest_id)
	var confetti_cls = load("res://scripts/vfx/confetti_burst.gd")
	if confetti_cls != null and confetti_cls.has_method("spawn_burst_2d"):
		var burst_pos = size * 0.5 if size != Vector2.ZERO else Vector2(250, 180)
		confetti_cls.spawn_burst_2d(self, burst_pos, 45)
	_refresh_quest_ui(
		quest_title_label.text.replace("📜 Quest: ", "") if quest_title_label else "",
		quest_desc_label.text if quest_desc_label else ""
	)

func close_dialogue() -> void:
	visible = false
	if _avatar_ref != null and _avatar_ref.has_method("set_input_enabled"):
		_avatar_ref.set_input_enabled(true)
	closed.emit()
