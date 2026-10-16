extends Control
class_name QuestTrackerUI

## On-screen Quest Tracker HUD for 3D Campus Quests (Phase 4 Milestone P4-M3).
## Displays current active quest title, progress counter, and objective hints.
## Automatically updates when collectibles are picked up or zones are unlocked.

@onready var container: PanelContainer = get_node_or_null("QuestCard")
@onready var title_label: Label = get_node_or_null("%QuestTitleLabel")
@onready var progress_label: Label = get_node_or_null("%QuestProgressLabel")
@onready var progress_bar: ProgressBar = get_node_or_null("%QuestProgressBar")
@onready var toast_label: Label = get_node_or_null("%ToastLabel")

var _active_quest_id: String = ""
var _quest_definitions: Dictionary = {
	"quest_briefcases": {
		"chapter": 1,
		"title": "Collect 3 Briefcases",
		"hint": "Search the Lobby and Courtyard",
		"target": 3,
		"is_story": true
	},
	"quest_coffee": {
		"title": "Courtyard Coffee Boost",
		"hint": "Grab a hot coffee in Courtyard",
		"target": 1,
		"is_story": false
	},
	"quest_server": {
		"chapter": 2,
		"title": "Unlock Server Room",
		"hint": "Reach Level 2 or pay 100 Users",
		"target": 1,
		"is_story": true
	},
	"quest_lab": {
		"chapter": 3,
		"title": "Unlock R&D Lab",
		"hint": "Reach Level 3 or pay 250 Users",
		"target": 1,
		"is_story": true
	},
	"story_ch1_seed": {
		"chapter": 1,
		"title": "Seed Stage: MVP Launch",
		"hint": "Talk to Alex and reach 100 Users",
		"target": 100,
		"is_story": true
	},
	"story_ch2_series_a": {
		"chapter": 2,
		"title": "Series A: Campus Scaling",
		"hint": "Overclock the Server Terminal with Bob",
		"target": 1,
		"is_story": true
	},
	"story_ch3_unicorn": {
		"chapter": 3,
		"title": "Unicorn Status: Super Brew",
		"hint": "Brew Unicorn Espresso with Dr. Lisa in R&D",
		"target": 1,
		"is_story": true
	}
}

func _ready() -> void:
	var gs = get_node_or_null("/root/GameState")
	if gs != null:
		if gs.has_signal("campus_quest_updated"):
			gs.campus_quest_updated.connect(_on_quest_updated)
		if gs.has_signal("campus_quest_completed"):
			gs.campus_quest_completed.connect(_on_quest_completed)
			
	_refresh_display()

func _on_quest_updated(quest_id: String, status: String, current_count: int, target_count: int) -> void:
	if status in ["active", "ready"]:
		_active_quest_id = quest_id
		_show_quest(quest_id, current_count, target_count, status == "ready")
	elif status == "completed" and _active_quest_id == quest_id:
		_refresh_display()

func _on_quest_completed(quest_id: String, reward_energy: float, reward_bonus: int) -> void:
	var reward_str: String = ""
	if reward_energy > 0:
		reward_str += "+" + str(int(reward_energy)) + " Users"
	if reward_bonus > 0:
		reward_str += "  •  +" + str(reward_bonus) + " Bonus"
		
	_show_toast("🎉 Quest Completed! " + reward_str)
	_active_quest_id = ""
	_refresh_display()

func _refresh_display() -> void:
	var gs = get_node_or_null("/root/GameState")
	if gs == null:
		_hide_quest()
		return
		
	# Look for an active or ready quest in GameState
	var found_quest: String = ""
	for q_id in gs.campus_quests:
		var st = gs.campus_quests[q_id].get("status", "")
		if st in ["active", "ready"]:
			found_quest = q_id
			break
			
	if not found_quest.is_empty():
		_active_quest_id = found_quest
		var q_data = gs.campus_quests[found_quest]
		var curr = int(q_data.get("current_count", 0))
		var tgt = int(q_data.get("target_count", 1))
		var is_ready = q_data.get("status") == "ready"
		_show_quest(found_quest, curr, tgt, is_ready)
	else:
		_hide_quest()

func _show_quest(quest_id: String, current: int, target: int, is_ready: bool) -> void:
	if container != null:
		container.visible = true
		
	var def = _quest_definitions.get(quest_id, {})
	var title = def.get("title", quest_id)
	var hint = def.get("hint", "")
	var is_story: bool = def.get("is_story", false) or quest_id.begins_with("story_") or quest_id in ["quest_briefcases", "quest_server", "quest_lab"]
	
	if title_label != null:
		if is_story:
			title_label.text = "🦄 [Story] " + title
		else:
			title_label.text = "📋 " + title
		
	if progress_label != null:
		if is_ready:
			progress_label.text = "✓ Ready to turn in! (" + str(current) + "/" + str(target) + ")"
			progress_label.modulate = Color(0.3, 1.0, 0.4)
		else:
			progress_label.text = hint + " (" + str(current) + "/" + str(target) + ")"
			progress_label.modulate = Color(0.85, 0.9, 1.0)
			
	if progress_bar != null:
		progress_bar.max_value = target
		progress_bar.value = current

func _hide_quest() -> void:
	if container != null:
		container.visible = false

func _show_toast(message: String) -> void:
	if toast_label == null:
		return
	toast_label.text = message
	toast_label.modulate.a = 1.0
	toast_label.visible = true
	
	var tween = create_tween()
	tween.tween_interval(2.5)
	tween.tween_property(toast_label, "modulate:a", 0.0, 0.5)
	tween.chain().tween_callback(func(): toast_label.visible = false)
