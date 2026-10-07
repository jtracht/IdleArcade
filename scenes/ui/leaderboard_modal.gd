extends Control

## LeaderboardModal Controller (res://scenes/ui/leaderboard_modal.gd)
## Manages Global, Regional/Country, and Guild Leaderboards,
## score submissions, and ranking display.

signal closed()

@onready var backdrop: ColorRect = $Backdrop
@onready var close_button: Button = %CloseButton
@onready var global_tab: Button = %GlobalTab
@onready var local_tab: Button = %LocalTab
@onready var guild_tab: Button = %GuildTab

@onready var my_score_label: Label = %MyScoreLabel
@onready var submit_score_button: Button = %SubmitScoreButton
@onready var refresh_button: Button = %RefreshButton

@onready var records_list: VBoxContainer = %LeaderboardList
@onready var empty_state_label: Label = %EmptyStateLabel
@onready var loading_indicator: Label = %LoadingIndicator
@onready var status_label: Label = %StatusLabel

var _current_tab: String = "global"
var _is_busy: bool = false
var _fetch_request_id: int = 0

func _ready() -> void:
	if close_button != null:
		close_button.pressed.connect(close)
	if backdrop != null:
		backdrop.gui_input.connect(_on_backdrop_gui_input)

	if global_tab != null:
		global_tab.pressed.connect(func(): _switch_tab("global"))
	if local_tab != null:
		local_tab.pressed.connect(func(): _switch_tab("local"))
	if guild_tab != null:
		guild_tab.pressed.connect(func(): _switch_tab("guild"))

	if refresh_button != null:
		refresh_button.pressed.connect(_fetch_current_tab)
	if submit_score_button != null:
		submit_score_button.pressed.connect(_on_submit_score_pressed)

	_connect_nakama_signals()
	_refresh_player_score()
	_update_tab_button_styles()
	_fetch_current_tab()

func _connect_nakama_signals() -> void:
	var nm = _get_nakama_manager()
	if nm == null:
		return

	if nm.has_signal("leaderboard_received") and not nm.leaderboard_received.is_connected(_on_leaderboard_received):
		nm.leaderboard_received.connect(_on_leaderboard_received)
	if nm.has_signal("score_submitted") and not nm.score_submitted.is_connected(_on_score_submitted):
		nm.score_submitted.connect(_on_score_submitted)
	if nm.has_signal("connection_status_changed") and not nm.connection_status_changed.is_connected(_on_connection_status_changed):
		nm.connection_status_changed.connect(_on_connection_status_changed)

func open(_args: Dictionary = {}) -> void:
	visible = true
	_refresh_player_score()
	_fetch_current_tab()

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

func _refresh_player_score() -> void:
	var gs = _get_game_state()
	if my_score_label != null:
		if gs != null:
			var formatted = gs.format_number(gs.total_energy_earned) if gs.has_method("format_number") else str(int(gs.total_energy_earned))
			my_score_label.text = "My Lifetime Users: %s 👥" % formatted
		else:
			my_score_label.text = "My Lifetime Users: 0 👥"

func _switch_tab(tab_name: String) -> void:
	if _is_busy or _current_tab == tab_name:
		return
	_current_tab = tab_name
	_update_tab_button_styles()
	_fetch_current_tab()

func _update_tab_button_styles() -> void:
	var active_color := Color(0, 0.85, 1, 1)
	var inactive_color := Color(0.7, 0.75, 0.82, 1)

	if global_tab != null:
		global_tab.add_theme_color_override("font_color", active_color if _current_tab == "global" else inactive_color)
	if local_tab != null:
		local_tab.add_theme_color_override("font_color", active_color if _current_tab == "local" else inactive_color)
	if guild_tab != null:
		guild_tab.add_theme_color_override("font_color", active_color if _current_tab == "guild" else inactive_color)

func _set_busy(busy: bool, message: String = "") -> void:
	_is_busy = busy
	if loading_indicator != null:
		loading_indicator.visible = busy
		loading_indicator.text = message
	if refresh_button != null:
		refresh_button.disabled = busy
	if submit_score_button != null:
		submit_score_button.disabled = busy
	if global_tab != null:
		global_tab.disabled = busy
	if local_tab != null:
		local_tab.disabled = busy
	if guild_tab != null:
		guild_tab.disabled = busy

func _show_feedback(message: String, is_error: bool = false) -> void:
	if status_label != null:
		status_label.text = message
		status_label.visible = not message.is_empty()
		if is_error:
			status_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
		else:
			status_label.add_theme_color_override("font_color", Color(0.25, 1.0, 0.35))

func _fetch_current_tab() -> void:
	var nm = _get_nakama_manager()
	_clear_records()
	_show_feedback("")

	if nm == null:
		if empty_state_label != null:
			empty_state_label.text = "Offline: Nakama server unavailable."
			empty_state_label.visible = true
		return

	if not nm.has_method("is_authenticated") or not nm.is_authenticated():
		if empty_state_label != null:
			empty_state_label.text = "Offline: Sign in or quick-login via Account to view rankings."
			empty_state_label.visible = true
		return

	_fetch_request_id += 1
	var current_req_id: int = _fetch_request_id
	var requested_tab: String = _current_tab

	_set_busy(true, "Fetching %s leaderboard..." % _current_tab.capitalize())
	var records: Array = []

	if _current_tab == "global":
		records = await nm.fetch_leaderboard_async("global_lifetime_users", 25)
	elif _current_tab == "local":
		var country_lid: String = nm.get_country_leaderboard_id() if nm.has_method("get_country_leaderboard_id") else "global_lifetime_users"
		records = await nm.fetch_leaderboard_async(country_lid, 25)
	elif _current_tab == "guild":
		var guild_id: String = nm.current_guild_id if "current_guild_id" in nm else ""
		if guild_id.is_empty():
			if current_req_id == _fetch_request_id:
				_set_busy(false)
				if empty_state_label != null:
					empty_state_label.text = "You are not currently in a network. Join or found a network to view guild scores!"
					empty_state_label.visible = true
			return
		records = await nm.fetch_guild_leaderboard_async(guild_id, 25)

	# Stale return check: discard if newer request was started or tab switched
	if current_req_id != _fetch_request_id or requested_tab != _current_tab:
		return

	_set_busy(false)
	_populate_records(records)

func _clear_records() -> void:
	if records_list == null:
		return
	for child in records_list.get_children():
		child.queue_free()
	if empty_state_label != null:
		empty_state_label.visible = false

func _populate_records(records: Array) -> void:
	_clear_records()

	if records.is_empty():
		if empty_state_label != null:
			empty_state_label.text = "No records found on %s leaderboard." % _current_tab.capitalize()
			empty_state_label.visible = true
		return

	var nm = _get_nakama_manager()
	var my_uid: String = nm.get_user_id() if (nm != null and nm.has_method("get_user_id")) else ""
	var gs = _get_game_state()

	for rec in records:
		var row = _create_record_row(rec, my_uid, gs)
		if records_list != null and row != null:
			records_list.add_child(row)

func _create_record_row(rec, my_uid: String, gs: Node) -> Control:
	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0

	var owner_id: String = str(rec.owner_id) if "owner_id" in rec else ""
	var is_me: bool = not my_uid.is_empty() and owner_id == my_uid

	if is_me:
		style.bg_color = Color(0.08, 0.16, 0.24, 0.95)
		style.border_width_left = 2
		style.border_width_top = 2
		style.border_width_right = 2
		style.border_width_bottom = 2
		style.border_color = Color(0, 0.85, 1, 0.8)
	else:
		style.bg_color = Color(0.04, 0.06, 0.1, 0.8)

	panel.add_theme_stylebox_override("panel", style)

	var hbox = HBoxContainer.new()
	panel.add_child(hbox)

	# Rank badge
	var rank_lbl = Label.new()
	rank_lbl.custom_minimum_size = Vector2(70, 0)
	var rank_val: int = int(rec.rank) if "rank" in rec else 0
	if rank_val == 1:
		rank_lbl.text = "🥇 #1"
		rank_lbl.add_theme_color_override("font_color", Color(1, 0.85, 0.2))
	elif rank_val == 2:
		rank_lbl.text = "🥈 #2"
		rank_lbl.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95))
	elif rank_val == 3:
		rank_lbl.text = "🥉 #3"
		rank_lbl.add_theme_color_override("font_color", Color(0.9, 0.6, 0.3))
	else:
		rank_lbl.text = "#%d" % rank_val
		rank_lbl.add_theme_color_override("font_color", Color(0.7, 0.75, 0.82))
	hbox.add_child(rank_lbl)

	# Player name
	var name_lbl = Label.new()
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var uname: String = str(rec.username) if "username" in rec else ""
	name_lbl.text = (uname if not uname.is_empty() else "Anonymous Founder") + (" (You)" if is_me else "")
	if is_me:
		name_lbl.add_theme_color_override("font_color", Color(0, 0.85, 1))
	hbox.add_child(name_lbl)

	# Score
	var score_lbl = Label.new()
	score_lbl.custom_minimum_size = Vector2(160, 0)
	score_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var score_val: float = float(rec.score) if "score" in rec else 0.0
	var formatted_score = gs.format_number(score_val) if (gs != null and gs.has_method("format_number")) else str(int(score_val))
	score_lbl.text = "%s 👥" % formatted_score
	score_lbl.add_theme_color_override("font_color", Color(0, 0.85, 1))
	hbox.add_child(score_lbl)

	return panel

func _on_submit_score_pressed() -> void:
	if _is_busy:
		return
	var nm = _get_nakama_manager()
	if nm == null or not nm.has_method("sync_current_score_async"):
		_show_feedback("Offline: Cannot submit score.", true)
		return

	_set_busy(true, "Submitting score...")
	_show_feedback("")
	await nm.sync_current_score_async()
	_set_busy(false)
	_refresh_player_score()
	_show_feedback("Score submitted successfully!", false)
	_fetch_current_tab()

func _on_leaderboard_received(leaderboard_id: String, records: Array) -> void:
	if (_current_tab == "global" and leaderboard_id == "global_lifetime_users") or \
	   (_current_tab == "local" and leaderboard_id.begins_with("country_lifetime_users_")) or \
	   (_current_tab == "guild" and leaderboard_id.begins_with("guild_")):
		_populate_records(records)

func _on_score_submitted(_leaderboard_id: String, _score: int) -> void:
	_refresh_player_score()

func _on_connection_status_changed(_is_online: bool, _status_text: String) -> void:
	_refresh_player_score()
