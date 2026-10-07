extends Control

## GuildModal Controller (res://scenes/ui/guild_modal.gd)
## Manages enterprise networks (Nakama Groups):
## - Unaffiliated state: browse networks and found a new network.
## - Affiliated state: syndicate overview, member list with roles, and leave syndicate.

signal closed()

@onready var backdrop: ColorRect = $Backdrop
@onready var close_button: Button = %CloseButton

# No-Guild View Controls
@onready var no_guild_view: VBoxContainer = %NoGuildView
@onready var guild_name_input: LineEdit = %GuildNameInput
@onready var guild_desc_input: LineEdit = %GuildDescInput
@onready var open_check_box: CheckBox = %OpenCheckBox
@onready var create_button: Button = %CreateButton
@onready var search_input: LineEdit = %SearchInput
@onready var search_button: Button = %SearchButton
@onready var guild_list: VBoxContainer = %GuildList

# In-Guild View Controls
@onready var in_guild_view: VBoxContainer = %InGuildView
@onready var guild_name_label: Label = %GuildNameLabel
@onready var guild_desc_label: Label = %GuildDescLabel
@onready var guild_member_count_label: Label = %GuildMemberCountLabel
@onready var member_list: VBoxContainer = %MemberList
@onready var refresh_members_button: Button = %RefreshMembersButton
@onready var leave_button: Button = %LeaveButton

# Feedback & Loading
@onready var loading_indicator: Label = %LoadingIndicator
@onready var status_label: Label = %StatusLabel

var _is_busy: bool = false

func _ready() -> void:
	if close_button != null:
		close_button.pressed.connect(close)
	if backdrop != null:
		backdrop.gui_input.connect(_on_backdrop_gui_input)

	if create_button != null:
		create_button.pressed.connect(_on_create_guild_pressed)
	if search_button != null:
		search_button.pressed.connect(_on_search_guilds_pressed)
	if search_input != null:
		search_input.text_submitted.connect(func(_t): _on_search_guilds_pressed())
	if refresh_members_button != null:
		refresh_members_button.pressed.connect(_on_refresh_members_pressed)
	if leave_button != null:
		leave_button.pressed.connect(_on_leave_guild_pressed)

	_connect_nakama_signals()
	_refresh_guild_state()

func _connect_nakama_signals() -> void:
	var nm = _get_nakama_manager()
	if nm == null:
		return

	if nm.has_signal("guild_updated") and not nm.guild_updated.is_connected(_on_guild_updated):
		nm.guild_updated.connect(_on_guild_updated)
	if nm.has_signal("guild_members_received") and not nm.guild_members_received.is_connected(_on_guild_members_received):
		nm.guild_members_received.connect(_on_guild_members_received)
	if nm.has_signal("connection_status_changed") and not nm.connection_status_changed.is_connected(_on_connection_status_changed):
		nm.connection_status_changed.connect(_on_connection_status_changed)

func open(_args: Dictionary = {}) -> void:
	visible = true
	_refresh_guild_state()

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

func _set_busy(busy: bool, message: String = "") -> void:
	_is_busy = busy
	if loading_indicator != null:
		loading_indicator.visible = busy
		loading_indicator.text = message
	if create_button != null:
		create_button.disabled = busy
	if search_button != null:
		search_button.disabled = busy
	if refresh_members_button != null:
		refresh_members_button.disabled = busy
	if leave_button != null:
		leave_button.disabled = busy

func _show_feedback(message: String, is_error: bool = false) -> void:
	if status_label != null:
		status_label.text = message
		status_label.visible = not message.is_empty()
		if is_error:
			status_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
		else:
			status_label.add_theme_color_override("font_color", Color(0.25, 1.0, 0.35))

func _refresh_guild_state() -> void:
	var nm = _get_nakama_manager()
	var in_guild: bool = false
	var gid: String = ""
	var gname: String = ""
	var gdesc: String = ""

	if nm != null:
		gid = nm.current_guild_id if "current_guild_id" in nm else ""
		gname = nm.current_guild_name if "current_guild_name" in nm else ""
		gdesc = nm.current_guild_desc if "current_guild_desc" in nm else ""
		in_guild = not gid.is_empty()

	if in_guild:
		if no_guild_view != null:
			no_guild_view.visible = false
		if in_guild_view != null:
			in_guild_view.visible = true
		if guild_name_label != null:
			guild_name_label.text = gname if not gname.is_empty() else "Enterprise Syndicate"
		if guild_desc_label != null:
			guild_desc_label.text = gdesc if not gdesc.is_empty() else "Enterprise Syndicate Roster"
		_fetch_guild_members(gid)
	else:
		if no_guild_view != null:
			no_guild_view.visible = true
		if in_guild_view != null:
			in_guild_view.visible = false
		_fetch_public_guilds("")

func _fetch_public_guilds(filter: String = "") -> void:
	var nm = _get_nakama_manager()
	_clear_guild_list()

	if nm == null or not nm.has_method("list_guilds_async"):
		_show_feedback("Offline: Nakama server unavailable.", true)
		return

	if not nm.has_method("is_authenticated") or not nm.is_authenticated():
		_show_feedback("Sign in via Account to view and join networks.", true)
		return

	_set_busy(true, "Searching enterprise networks...")
	var guilds: Array = await nm.list_guilds_async(filter)
	_set_busy(false)

	if guilds.is_empty():
		_show_feedback("No networks found matching '%s'." % filter if not filter.is_empty() else "No public networks currently found.", false)
		return

	for g in guilds:
		var card = _create_guild_card(g)
		if guild_list != null and card != null:
			guild_list.add_child(card)

func _clear_guild_list() -> void:
	if guild_list == null:
		return
	for child in guild_list.get_children():
		child.queue_free()

func _create_guild_card(g: Dictionary) -> Control:
	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.06, 0.1, 0.85)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	panel.add_theme_stylebox_override("panel", style)

	var hbox = HBoxContainer.new()
	panel.add_child(hbox)

	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(vbox)

	var title_lbl = Label.new()
	title_lbl.text = g.get("name", "Unnamed Network")
	title_lbl.add_theme_font_size_override("font_size", 15)
	title_lbl.add_theme_color_override("font_color", Color(1, 1, 1))
	vbox.add_child(title_lbl)

	var desc_lbl = Label.new()
	var desc_text = g.get("description", "")
	var count_str = "%d / %d members" % [g.get("edge_count", 0), g.get("max_count", 50)]
	desc_lbl.text = (desc_text + " • " if not desc_text.is_empty() else "") + count_str
	desc_lbl.add_theme_font_size_override("font_size", 12)
	desc_lbl.add_theme_color_override("font_color", Color(0.7, 0.75, 0.82))
	vbox.add_child(desc_lbl)

	var join_btn = Button.new()
	join_btn.custom_minimum_size = Vector2(90, 36)
	join_btn.text = "Join"
	var gid: String = str(g.get("id", ""))
	var gname: String = str(g.get("name", ""))
	var gdesc: String = str(g.get("description", ""))
	join_btn.pressed.connect(func(): _on_join_guild_pressed(gid, gname, gdesc))
	hbox.add_child(join_btn)

	return panel

func _on_join_guild_pressed(group_id: String, group_name: String = "", group_desc: String = "") -> void:
	if _is_busy:
		return
	var nm = _get_nakama_manager()
	if nm == null:
		return

	_set_busy(true, "Joining network...")
	_show_feedback("")
	var ok: bool = await nm.join_guild_async(group_id, group_name, group_desc)
	_set_busy(false)
	if ok:
		_show_feedback("Joined network successfully!", false)
		_refresh_guild_state()
	else:
		_show_feedback("Failed to join: %s" % (nm.last_error if nm.last_error != "" else "Could not join network"), true)

func _on_create_guild_pressed() -> void:
	if _is_busy:
		return
	var nm = _get_nakama_manager()
	if nm == null:
		_show_feedback("Offline: Nakama server unavailable.", true)
		return

	var name_text: String = guild_name_input.text.strip_edges() if guild_name_input != null else ""
	var desc_text: String = guild_desc_input.text.strip_edges() if guild_desc_input != null else ""
	var is_open: bool = open_check_box.button_pressed if open_check_box != null else true

	if name_text.is_empty():
		_show_feedback("Network name cannot be empty.", true)
		return

	_set_busy(true, "Founding new enterprise network...")
	_show_feedback("")
	var res: Dictionary = await nm.create_guild_async(name_text, desc_text, is_open)
	_set_busy(false)

	if not res.is_empty():
		_show_feedback("Network '%s' founded successfully!" % name_text, false)
		if guild_name_input != null:
			guild_name_input.text = ""
		if guild_desc_input != null:
			guild_desc_input.text = ""
		_refresh_guild_state()
	else:
		_show_feedback("Creation failed: %s" % (nm.last_error if nm.last_error != "" else "Network name may be taken"), true)

func _on_search_guilds_pressed() -> void:
	var query: String = search_input.text.strip_edges() if search_input != null else ""
	_fetch_public_guilds(query)

func _fetch_guild_members(group_id: String) -> void:
	var nm = _get_nakama_manager()
	_clear_member_list()

	if nm == null or not nm.has_method("list_guild_members_async") or group_id.is_empty():
		return

	_set_busy(true, "Loading member roster...")
	var members: Array = await nm.list_guild_members_async(group_id)
	_set_busy(false)

	_populate_members(members)

func _clear_member_list() -> void:
	if member_list == null:
		return
	for child in member_list.get_children():
		child.queue_free()

func _populate_members(members: Array) -> void:
	_clear_member_list()

	if guild_member_count_label != null:
		guild_member_count_label.text = "Members: %d / 50" % members.size()

	for m in members:
		var card = _create_member_card(m)
		if member_list != null and card != null:
			member_list.add_child(card)

func _create_member_card(m: Dictionary) -> Control:
	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.06, 0.1, 0.8)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_right = 6
	style.corner_radius_bottom_left = 6
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	panel.add_theme_stylebox_override("panel", style)

	var hbox = HBoxContainer.new()
	panel.add_child(hbox)

	var name_lbl = Label.new()
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var uname: String = m.get("username", "Member")
	name_lbl.text = uname if not uname.is_empty() else "Founder"
	name_lbl.add_theme_font_size_override("font_size", 14)
	hbox.add_child(name_lbl)

	var role_lbl = Label.new()
	var role_str: String = m.get("role", "Member")
	role_lbl.text = "[%s]" % role_str
	role_lbl.add_theme_font_size_override("font_size", 12)
	if role_str == "Superadmin":
		role_lbl.add_theme_color_override("font_color", Color(1, 0.85, 0.2))
	elif role_str == "Admin":
		role_lbl.add_theme_color_override("font_color", Color(0, 0.85, 1))
	else:
		role_lbl.add_theme_color_override("font_color", Color(0.7, 0.75, 0.82))
	hbox.add_child(role_lbl)

	return panel

func _on_refresh_members_pressed() -> void:
	var nm = _get_nakama_manager()
	if nm != null and not nm.current_guild_id.is_empty():
		_fetch_guild_members(nm.current_guild_id)

func _on_leave_guild_pressed() -> void:
	if _is_busy:
		return
	var nm = _get_nakama_manager()
	if nm == null or nm.current_guild_id.is_empty():
		return

	_set_busy(true, "Leaving network...")
	_show_feedback("")
	var ok: bool = await nm.leave_guild_async(nm.current_guild_id)
	_set_busy(false)

	if ok:
		_show_feedback("Left network.", false)
		_refresh_guild_state()
	else:
		_show_feedback("Failed to leave: %s" % (nm.last_error if nm.last_error != "" else "Sole superadmin cannot leave"), true)

func _on_guild_updated(_data: Dictionary) -> void:
	_refresh_guild_state()

func _on_guild_members_received(group_id: String, members: Array) -> void:
	var nm = _get_nakama_manager()
	if nm != null and group_id == nm.current_guild_id:
		_populate_members(members)

func _on_connection_status_changed(_is_online: bool, _status_text: String) -> void:
	_refresh_guild_state()
