extends Control

## QuestModal Controller (res://scenes/ui/quest_modal.gd)
## Manages daily quests: Reactor Tapper, Industrial Expansion, and Energy Surge.
## Tracks progress bars and allows claiming permanent bonus users to GameState.

signal closed()

@onready var backdrop: ColorRect = $Backdrop
@onready var close_button: Button = %CloseButton
@onready var refresh_button: Button = %RefreshQuestsButton
@onready var date_label: Label = %DateLabel
@onready var total_bonus_label: Label = %TotalBonusLabel

# Quest 1: Tap
@onready var tap_progress_bar: ProgressBar = %TapProgressBar
@onready var tap_progress_label: Label = %TapProgressLabel
@onready var tap_claim_btn: Button = %ClaimButton_Tap

# Quest 2: Upgrade
@onready var upgrade_progress_bar: ProgressBar = %UpgradeProgressBar
@onready var upgrade_progress_label: Label = %UpgradeProgressLabel
@onready var upgrade_claim_btn: Button = %ClaimButton_Upgrade

# Quest 3: Spark
@onready var spark_progress_bar: ProgressBar = %SparkProgressBar
@onready var spark_progress_label: Label = %SparkProgressLabel
@onready var spark_claim_btn: Button = %ClaimButton_Spark

# Loading & Status Feedback
@onready var loading_indicator: Label = %LoadingIndicator
@onready var status_label: Label = %StatusLabel

var _is_busy: bool = false

func _ready() -> void:
	if close_button != null:
		close_button.pressed.connect(close)
	if backdrop != null:
		backdrop.gui_input.connect(_on_backdrop_gui_input)

	if refresh_button != null:
		refresh_button.pressed.connect(_fetch_quests)

	if tap_claim_btn != null:
		tap_claim_btn.pressed.connect(func(): _on_claim_pressed("daily_tap"))
	if upgrade_claim_btn != null:
		upgrade_claim_btn.pressed.connect(func(): _on_claim_pressed("daily_upgrade"))
	if spark_claim_btn != null:
		spark_claim_btn.pressed.connect(func(): _on_claim_pressed("daily_spark"))

	_connect_signals()
	_update_bonus_users_display()
	_fetch_quests()

func _connect_signals() -> void:
	var nm = _get_nakama_manager()
	if nm != null:
		if nm.has_signal("quests_updated") and not nm.quests_updated.is_connected(_on_quests_updated):
			nm.quests_updated.connect(_on_quests_updated)
		if nm.has_signal("quest_reward_claimed") and not nm.quest_reward_claimed.is_connected(_on_quest_reward_claimed):
			nm.quest_reward_claimed.connect(_on_quest_reward_claimed)

	var gs = _get_game_state()
	if gs != null:
		if gs.has_signal("bonus_users_changed") and not gs.bonus_users_changed.is_connected(_on_bonus_users_changed):
			gs.bonus_users_changed.connect(_on_bonus_users_changed)

func open(_args: Dictionary = {}) -> void:
	visible = true
	_update_bonus_users_display()
	_fetch_quests()

func close() -> void:
	closed.emit()
	visible = false
	queue_free()

func _on_backdrop_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		close()

func _get_nakama_manager() -> Node:
	if has_node("/root/NakamaManager"):
		return get_node("/root/NakamaManager")
	return null

func _get_game_state() -> Node:
	if has_node("/root/GameState"):
		return get_node("/root/GameState")
	return null

func _update_bonus_users_display() -> void:
	var gs = _get_game_state()
	var bonus_cnt: int = gs.bonus_users if (gs != null and "bonus_users" in gs) else 0
	if total_bonus_label != null:
		total_bonus_label.text = "👥 Bonus Users: +%d  (+%d%% Passive RPS Boost)" % [bonus_cnt, bonus_cnt]

func _set_busy(busy: bool, message: String = "") -> void:
	_is_busy = busy
	if loading_indicator != null:
		loading_indicator.visible = busy
		loading_indicator.text = message
	if refresh_button != null:
		refresh_button.disabled = busy

func _show_feedback(message: String, is_error: bool = false) -> void:
	if status_label != null:
		status_label.text = message
		status_label.visible = not message.is_empty()
		if is_error:
			status_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
		else:
			status_label.add_theme_color_override("font_color", Color(0.25, 1.0, 0.35))

func _fetch_quests() -> void:
	var nm = _get_nakama_manager()
	if nm == null or not nm.has_method("fetch_daily_quests_async"):
		# Fallback mock for isolated tests
		_render_fallback_quests()
		return

	_set_busy(true, "Synchronizing daily challenges...")
	var data: Dictionary = await nm.fetch_daily_quests_async()
	_set_busy(false)

	if not data.is_empty():
		_apply_quests_data(data)
	else:
		_render_fallback_quests()

func _apply_quests_data(data: Dictionary) -> void:
	if date_label != null and data.has("date"):
		date_label.text = "Cycle: %s (UTC)" % str(data.get("date", ""))

	var quests_map: Dictionary = data.get("quests", {})
	if quests_map.has("daily_tap"):
		_update_card_ui(quests_map["daily_tap"], tap_progress_bar, tap_progress_label, tap_claim_btn)
	if quests_map.has("daily_upgrade"):
		_update_card_ui(quests_map["daily_upgrade"], upgrade_progress_bar, upgrade_progress_label, upgrade_claim_btn)
	if quests_map.has("daily_spark"):
		_update_card_ui(quests_map["daily_spark"], spark_progress_bar, spark_progress_label, spark_claim_btn)

func _update_card_ui(q: Dictionary, bar: ProgressBar, label: Label, btn: Button) -> void:
	var cur: int = int(q.get("current", 0))
	var target: int = int(q.get("target", 1))
	var is_claimed: bool = bool(q.get("is_claimed", false))
	var is_completed: bool = bool(q.get("is_completed", cur >= target))
	var reward: int = int(q.get("reward_bonus_users", 0))

	if bar != null:
		bar.max_value = target
		bar.value = cur

	if label != null:
		label.text = "%d / %d" % [cur, target]

	if btn != null:
		if is_claimed:
			btn.text = "Claimed ✓"
			btn.disabled = true
			btn.add_theme_color_override("font_color", Color(0.5, 0.6, 0.7))
			btn.add_theme_color_override("font_disabled_color", Color(0.5, 0.6, 0.7))
		elif is_completed:
			btn.text = "CLAIM +%d BONUS USERS!" % reward
			btn.disabled = false
			btn.add_theme_color_override("font_color", Color(0.25, 1.0, 0.35))
		else:
			btn.text = "In Progress (%d/%d)" % [cur, target]
			btn.disabled = true
			btn.add_theme_color_override("font_color", Color(0.7, 0.75, 0.82))
			btn.add_theme_color_override("font_disabled_color", Color(0.7, 0.75, 0.82))

func _render_fallback_quests() -> void:
	var default_tap = {"current": 0, "target": 50, "reward_bonus_users": 25, "is_completed": false, "is_claimed": false}
	var default_upgrade = {"current": 0, "target": 3, "reward_bonus_users": 50, "is_completed": false, "is_claimed": false}
	var default_spark = {"current": 0, "target": 3, "reward_bonus_users": 100, "is_completed": false, "is_claimed": false}

	_update_card_ui(default_tap, tap_progress_bar, tap_progress_label, tap_claim_btn)
	_update_card_ui(default_upgrade, upgrade_progress_bar, upgrade_progress_label, upgrade_claim_btn)
	_update_card_ui(default_spark, spark_progress_bar, spark_progress_label, spark_claim_btn)

func _on_claim_pressed(quest_id: String) -> void:
	if _is_busy:
		return
	var nm = _get_nakama_manager()
	if nm == null or not nm.has_method("claim_quest_reward_async"):
		_show_feedback("Offline: Cannot claim reward.", true)
		return

	_set_busy(true, "Claiming reward...")
	_show_feedback("")
	var awarded: int = await nm.claim_quest_reward_async(quest_id)
	_set_busy(false)

	if awarded > 0:
		_show_feedback("Success! Earned +%d Bonus Users permanent boost!" % awarded, false)
		_update_bonus_users_display()
	else:
		_show_feedback("Quest is not completed or already claimed.", true)

func _on_quests_updated(quests_dict: Dictionary) -> void:
	_apply_quests_data(quests_dict)

func _on_quest_reward_claimed(_quest_id: String, _bonus_users: int) -> void:
	_update_bonus_users_display()

func _on_bonus_users_changed(_new_bonus: int, _added_amount: int = 0) -> void:
	_update_bonus_users_display()
