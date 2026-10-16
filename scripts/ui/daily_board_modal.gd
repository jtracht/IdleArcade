extends Control

## Daily Challenge Board Modal for IdleArcade (Phase 12 Milestone 4).
## Displays fire streak banner ("🔥 X TAGE STREAK") and 3 daily challenge cards
## with progress indicators, reward previews, and ergonomic claim buttons.
## Adheres strictly to mobile touch ergonomics: touch targets >= 56px and mouse_filter = STOP.

signal closed()
signal daily_board_updated()
signal task_claimed(task_id: String, reward: Dictionary)

@onready var backdrop: ColorRect = $Backdrop
@onready var close_button: Button = %CloseButton
@onready var streak_header_label: Label = %StreakHeaderLabel
@onready var streak_sub_label: Label = get_node_or_null("%StreakSubLabel")

@onready var task1_title: Label = %Task1Title
@onready var task1_desc: Label = %Task1Desc
@onready var task1_progress: Label = %Task1Progress
@onready var task1_progress_bar: ProgressBar = get_node_or_null("%Task1ProgressBar")
@onready var task1_reward: Label = %Task1Reward
@onready var task1_claim_button: Button = %Task1ClaimButton

@onready var task2_title: Label = %Task2Title
@onready var task2_desc: Label = %Task2Desc
@onready var task2_progress: Label = %Task2Progress
@onready var task2_progress_bar: ProgressBar = get_node_or_null("%Task2ProgressBar")
@onready var task2_reward: Label = %Task2Reward
@onready var task2_claim_button: Button = %Task2ClaimButton

@onready var task3_title: Label = %Task3Title
@onready var task3_desc: Label = %Task3Desc
@onready var task3_progress: Label = %Task3Progress
@onready var task3_progress_bar: ProgressBar = get_node_or_null("%Task3ProgressBar")
@onready var task3_reward: Label = %Task3Reward
@onready var task3_claim_button: Button = %Task3ClaimButton

# Convenience alias for tests checking singular %ClaimButton
var claim_button: Button:
	get:
		return task1_claim_button

var _cached_tasks: Array[Dictionary] = []

func _ready() -> void:
	# Input isolation: root stops all pointer events leaking to 3D world
	mouse_filter = Control.MOUSE_FILTER_STOP

	if backdrop != null:
		backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
		if not backdrop.gui_input.is_connected(_on_backdrop_gui_input):
			backdrop.gui_input.connect(_on_backdrop_gui_input)

	if close_button != null:
		close_button.mouse_filter = Control.MOUSE_FILTER_STOP
		if not close_button.pressed.is_connected(close):
			close_button.pressed.connect(close)

	if task1_claim_button != null:
		task1_claim_button.mouse_filter = Control.MOUSE_FILTER_STOP
		if not task1_claim_button.pressed.is_connected(_on_task1_claim_pressed):
			task1_claim_button.pressed.connect(_on_task1_claim_pressed)

	if task2_claim_button != null:
		task2_claim_button.mouse_filter = Control.MOUSE_FILTER_STOP
		if not task2_claim_button.pressed.is_connected(_on_task2_claim_pressed):
			task2_claim_button.pressed.connect(_on_task2_claim_pressed)

	if task3_claim_button != null:
		task3_claim_button.mouse_filter = Control.MOUSE_FILTER_STOP
		if not task3_claim_button.pressed.is_connected(_on_task3_claim_pressed):
			task3_claim_button.pressed.connect(_on_task3_claim_pressed)

	_connect_game_state_signals()
	open()

func _connect_game_state_signals() -> void:
	var gs = _get_game_state()
	if gs == null:
		return
	if gs.has_signal("daily_tasks_updated") and not gs.daily_tasks_updated.is_connected(_on_game_state_updated):
		gs.daily_tasks_updated.connect(_on_game_state_updated)
	if gs.has_signal("daily_streak_updated") and not gs.daily_streak_updated.is_connected(_on_game_state_updated):
		gs.daily_streak_updated.connect(_on_game_state_updated)
	if gs.has_signal("daily_task_claimed") and not gs.daily_task_claimed.is_connected(_on_task_claimed_signal):
		gs.daily_task_claimed.connect(_on_task_claimed_signal)

func _disconnect_game_state_signals() -> void:
	var gs = _get_game_state()
	if gs == null:
		return
	if gs.has_signal("daily_tasks_updated") and gs.daily_tasks_updated.is_connected(_on_game_state_updated):
		gs.daily_tasks_updated.disconnect(_on_game_state_updated)
	if gs.has_signal("daily_streak_updated") and gs.daily_streak_updated.is_connected(_on_game_state_updated):
		gs.daily_streak_updated.disconnect(_on_game_state_updated)
	if gs.has_signal("daily_task_claimed") and gs.daily_task_claimed.is_connected(_on_task_claimed_signal):
		gs.daily_task_claimed.disconnect(_on_task_claimed_signal)

func _on_game_state_updated(_arg = null) -> void:
	_update_display()

func _on_task_claimed_signal(_task_id: String, _reward: Dictionary) -> void:
	_update_display()

## Lifecycle open method. Refreshes daily tasks and streak display.
func open(_args: Dictionary = {}) -> void:
	visible = true
	_update_display()

## Lifecycle close method. Emits closed signal, plays click SFX, and frees node.
func close() -> void:
	_disconnect_game_state_signals()
	_play_click_sfx()
	closed.emit()
	visible = false
	queue_free()

func _on_backdrop_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		close()

func _update_display() -> void:
	var gs = _get_game_state()
	if gs == null:
		return

	var streak: int = gs.get_daily_streak() if gs.has_method("get_daily_streak") else int(gs.get("daily_board_streak"))
	if streak_header_label != null:
		streak_header_label.text = "🔥 %d TAGE STREAK" % streak
		streak_header_label.add_theme_color_override("font_color", Color(1.0, 0.65, 0.1, 1.0))

	if streak_sub_label != null:
		if streak > 0:
			streak_sub_label.text = "Hervorragend! Erfülle heute alle Aufgaben, um deinen Streak zu sichern!"
		else:
			streak_sub_label.text = "Schließe alle 3 täglichen Aufgaben ab, um deinen Streak zu erhöhen!"

	var tasks: Array = gs.get_daily_tasks() if gs.has_method("get_daily_tasks") else []
	_cached_tasks = []
	for t in tasks:
		if t is Dictionary:
			_cached_tasks.append(t)

	_update_task_card(0, task1_title, task1_desc, task1_progress, task1_progress_bar, task1_reward, task1_claim_button)
	_update_task_card(1, task2_title, task2_desc, task2_progress, task2_progress_bar, task2_reward, task2_claim_button)
	_update_task_card(2, task3_title, task3_desc, task3_progress, task3_progress_bar, task3_reward, task3_claim_button)
	daily_board_updated.emit()

func _update_task_card(
	index: int,
	title_lbl: Label,
	desc_lbl: Label,
	prog_lbl: Label,
	prog_bar: ProgressBar,
	reward_lbl: Label,
	claim_btn: Button
) -> void:
	if index >= _cached_tasks.size():
		return

	var task: Dictionary = _cached_tasks[index]
	var title: String = str(task.get("title", "Daily Task"))
	var desc: String = str(task.get("description", ""))
	var cur: int = int(task.get("current", 0))
	var tgt: int = maxi(1, int(task.get("target", 1)))
	var is_comp: bool = bool(task.get("is_completed", cur >= tgt))
	var is_claimed: bool = bool(task.get("is_claimed", false))
	var reward: Dictionary = task.get("reward", {})

	if title_lbl != null:
		title_lbl.text = title
	if desc_lbl != null:
		desc_lbl.text = desc
	if prog_lbl != null:
		prog_lbl.text = "Fortschritt: %d / %d" % [cur, tgt]
	if prog_bar != null:
		prog_bar.min_value = 0
		prog_bar.max_value = tgt
		prog_bar.value = cur

	if reward_lbl != null:
		var reward_str: String = reward.get("description", "")
		if reward_str.is_empty():
			if reward.has("energy"):
				reward_str = "%s Energy" % _format_number(float(reward["energy"]))
			if reward.has("angel_shares"):
				reward_str += " + %d Angel Share" % int(reward["angel_shares"])
		reward_lbl.text = "Belohnung: " + reward_str

	if claim_btn != null:
		claim_btn.mouse_filter = Control.MOUSE_FILTER_STOP
		if is_claimed:
			claim_btn.text = "✓ EINGELÖST"
			claim_btn.disabled = true
			claim_btn.add_theme_color_override("font_color", Color(0.5, 0.85, 0.5, 0.8))
		elif is_comp:
			claim_btn.text = "🎁 ABHOLEN"
			claim_btn.disabled = false
			claim_btn.add_theme_color_override("font_color", Color(1.0, 0.95, 0.3, 1.0))
		else:
			claim_btn.text = "%d / %d" % [cur, tgt]
			claim_btn.disabled = true
			claim_btn.add_theme_color_override("font_color", Color(0.65, 0.7, 0.75, 0.7))

func _on_task1_claim_pressed() -> void:
	_execute_claim(0)

func _on_task2_claim_pressed() -> void:
	_execute_claim(1)

func _on_task3_claim_pressed() -> void:
	_execute_claim(2)

func _execute_claim(index: int) -> void:
	if index >= _cached_tasks.size():
		return

	var task: Dictionary = _cached_tasks[index]
	var task_id: String = str(task.get("id", ""))
	var gs = _get_game_state()
	if gs == null or not gs.has_method("claim_daily_task"):
		return

	var res: Dictionary = gs.claim_daily_task(task_id)
	if not res.get("success", false):
		return

	_play_claim_sfx()
	_trigger_haptic_tap()
	_spawn_confetti()

	var reward: Dictionary = res.get("reward", {})
	task_claimed.emit(task_id, reward)
	_update_display()

func _spawn_confetti() -> void:
	var confetti_cls = load("res://scripts/vfx/confetti_burst.gd")
	if confetti_cls != null and confetti_cls.has_method("spawn_burst_2d"):
		confetti_cls.spawn_burst_2d(self, get_viewport_rect().size * 0.5, 35)

func _play_claim_sfx() -> void:
	var am = get_node_or_null("/root/AudioManager")
	if am != null:
		if am.has_method("play_sfx_pickup"):
			am.play_sfx_pickup("briefcase")
		elif am.has_method("play_sfx_click"):
			am.play_sfx_click()

func _play_click_sfx() -> void:
	var am = get_node_or_null("/root/AudioManager")
	if am != null and am.has_method("play_sfx_click"):
		am.play_sfx_click()

func _trigger_haptic_tap() -> void:
	var hm = get_node_or_null("/root/HapticsManager")
	if hm != null and hm.has_method("vibrate_button"):
		hm.vibrate_button()

func _get_game_state() -> Node:
	if has_node("/root/GameState"):
		return get_node("/root/GameState")
	return null

func _format_number(val: float) -> String:
	var gs = _get_game_state()
	if gs != null and gs.has_method("format_number"):
		return gs.format_number(val)
	if val >= 1000000.0:
		return "%.1fM" % (val / 1000000.0)
	elif val >= 1000.0:
		return "%.1fK" % (val / 1000.0)
	return str(int(val))
