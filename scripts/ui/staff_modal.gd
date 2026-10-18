class_name StaffModal
extends Control

## Staff Management & Mobile Touch Ergonomics Modal for IdleArcade (Milestone P14-M3).
## Features 3 touch-optimized tabs:
##   1. "Mitarbeiter & Recruiting": Specialist active roster, morale, and recruitment.
##   2. "Schreibtisch-Upgrades": Workstations 1-5 with fatigue reduction level-ups.
##   3. "Teambuilding & Kaffeeration": Team coffee breaks, hyper-focus, and espresso synergy.
## Complies with strict mobile ergonomics (all interactive targets >= 56px, mouse_filter = STOP).

signal closed()

@export var active_tab_index: int = 0

# --- Header & Summary Banner ---
@onready var close_button: Button = %CloseButton
@onready var staff_summary_label: Label = %StaffSummaryLabel
@onready var staff_rps_bonus_label: Label = %StaffRPSBonusLabel
@onready var hyper_focus_status_label: Label = %HyperFocusStatusLabel

# --- Tab Buttons ---
@onready var recruiting_tab_button: Button = %RecruitingTabButton
@onready var desk_upgrades_tab_button: Button = %DeskUpgradesTabButton
@onready var teambuilding_tab_button: Button = %TeambuildingTabButton

# --- Tab Containers ---
@onready var recruiting_tab: VBoxContainer = %RecruitingTab
@onready var workers_scroll: ScrollContainer = %WorkersScroll
@onready var workers_list_vbox: VBoxContainer = %WorkersListVBox
@onready var role_option_button: OptionButton = %RoleOptionButton
@onready var recruit_button: Button = %RecruitButton

@onready var desk_upgrades_tab: VBoxContainer = %DeskUpgradesTab
@onready var desks_scroll: ScrollContainer = %DesksScroll
@onready var desks_vbox: VBoxContainer = %DesksVBox

@onready var teambuilding_tab: VBoxContainer = %TeambuildingTab
@onready var hyper_focus_progress_bar: ProgressBar = %HyperFocusProgressBar
@onready var serve_coffee_break_button: Button = %ServeCoffeeBreakButton
@onready var espresso_synergy_label: Label = %EspressoSynergyLabel

const ROLE_KEYS: Array[String] = [
	"Frontend Dev",
	"Backend Dev",
	"UI/UX Designer",
	"Growth Hacker",
	"QA Engineer"
]

func _ready() -> void:
	# Enforce root mouse isolation
	mouse_filter = Control.MOUSE_FILTER_STOP

	if close_button != null:
		close_button.pressed.connect(close)

	if recruiting_tab_button != null:
		recruiting_tab_button.pressed.connect(func(): switch_tab(0))
	if desk_upgrades_tab_button != null:
		desk_upgrades_tab_button.pressed.connect(func(): switch_tab(1))
	if teambuilding_tab_button != null:
		teambuilding_tab_button.pressed.connect(func(): switch_tab(2))

	if role_option_button != null:
		role_option_button.item_selected.connect(_on_role_option_selected)

	if recruit_button != null:
		recruit_button.pressed.connect(_on_recruit_button_pressed)

	if serve_coffee_break_button != null:
		serve_coffee_break_button.pressed.connect(_on_serve_coffee_break_pressed)

	_populate_role_options()
	_connect_game_state_signals()
	switch_tab(active_tab_index)
	refresh_all()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		if event.keycode == KEY_ESCAPE:
			close()
			get_viewport().set_input_as_handled()

func _connect_game_state_signals() -> void:
	var gs = _get_game_state()
	if gs == null:
		return

	if gs.has_signal("staff_worker_hired"):
		gs.connect("staff_worker_hired", _on_game_state_changed)
	elif gs.has_signal("worker_hired"):
		gs.connect("worker_hired", _on_game_state_changed)

	if gs.has_signal("staff_worker_fired"):
		gs.connect("staff_worker_fired", _on_game_state_changed)
	elif gs.has_signal("worker_fired"):
		gs.connect("worker_fired", _on_game_state_changed)

	if gs.has_signal("staff_worker_state_changed"):
		gs.connect("staff_worker_state_changed", _on_game_state_changed)
	elif gs.has_signal("worker_state_changed"):
		gs.connect("worker_state_changed", _on_game_state_changed)

	if gs.has_signal("staff_worker_morale_updated"):
		gs.connect("staff_worker_morale_updated", _on_game_state_changed)

	if gs.has_signal("staff_desk_upgraded"):
		gs.connect("staff_desk_upgraded", _on_game_state_changed)
	elif gs.has_signal("desk_upgraded"):
		gs.connect("desk_upgraded", _on_game_state_changed)

	if gs.has_signal("staff_coffee_break_started"):
		gs.connect("staff_coffee_break_started", _on_game_state_changed)
	elif gs.has_signal("team_coffee_break_started"):
		gs.connect("team_coffee_break_started", _on_game_state_changed)

	if gs.has_signal("staff_coffee_break_ended"):
		gs.connect("staff_coffee_break_ended", _on_game_state_changed)
	elif gs.has_signal("team_coffee_break_ended"):
		gs.connect("team_coffee_break_ended", _on_game_state_changed)

	if gs.has_signal("staff_morale_updated"):
		gs.connect("staff_morale_updated", _on_game_state_changed)

	if gs.has_signal("staff_bonus_updated"):
		gs.connect("staff_bonus_updated", _on_game_state_changed)

	if gs.has_signal("energy_changed"):
		gs.connect("energy_changed", _on_energy_changed)

func _on_game_state_changed(_a = null, _b = null, _c = null, _d = null) -> void:
	refresh_all()

func _on_energy_changed(_total: float, _delta: float) -> void:
	_update_recruit_button_state()
	_update_desk_buttons_state()

func _get_game_state() -> Node:
	if has_node("/root/GameState"):
		return get_node("/root/GameState")
	return null

func _play_sfx_click() -> void:
	if has_node("/root/AudioManager"):
		var am = get_node("/root/AudioManager")
		if am.has_method("play_sfx_click"):
			am.play_sfx_click()
	if has_node("/root/HapticsManager"):
		var hm = get_node("/root/HapticsManager")
		if hm.has_method("vibrate_button"):
			hm.vibrate_button()

# ------------------------------------------------------------------------------
# Navigation & Tab Switching
# ------------------------------------------------------------------------------

func switch_tab(tab_idx: int) -> void:
	active_tab_index = clampi(tab_idx, 0, 2)

	if recruiting_tab != null:
		recruiting_tab.visible = (active_tab_index == 0)
	if desk_upgrades_tab != null:
		desk_upgrades_tab.visible = (active_tab_index == 1)
	if teambuilding_tab != null:
		teambuilding_tab.visible = (active_tab_index == 2)

	_update_tab_button_styles()
	refresh_all()

func set_tab(tab_idx: int) -> void:
	switch_tab(tab_idx)

func _update_tab_button_styles() -> void:
	var tabs: Array[Button] = [recruiting_tab_button, desk_upgrades_tab_button, teambuilding_tab_button]
	for i in range(tabs.size()):
		var btn = tabs[i]
		if btn != null:
			if i == active_tab_index:
				btn.modulate = Color(1.0, 1.0, 1.0, 1.0)
			else:
				btn.modulate = Color(0.7, 0.75, 0.85, 0.8)

# ------------------------------------------------------------------------------
# Data Population & Refresh Engine
# ------------------------------------------------------------------------------

func refresh_all() -> void:
	_refresh_summary_banner()
	if active_tab_index == 0:
		_refresh_recruiting_tab()
	elif active_tab_index == 1:
		_refresh_desk_upgrades_tab()
	elif active_tab_index == 2:
		_refresh_teambuilding_tab()

func _refresh_summary_banner() -> void:
	var gs = _get_game_state()
	if gs == null:
		return

	var workers: Array = gs.get_hired_workers() if gs.has_method("get_hired_workers") else []
	var total_workers: int = workers.size()
	var active_workers: int = gs.get_active_workers_count() if gs.has_method("get_active_workers_count") else total_workers
	var avg_morale: float = gs.get_staff_average_morale() if gs.has_method("get_staff_average_morale") else 1.0
	var rps_mult: float = gs.get_staff_rps_multiplier() if gs.has_method("get_staff_rps_multiplier") else 1.0

	if staff_summary_label != null:
		staff_summary_label.text = "Active Specialists: %d / 5 • Average Morale: %d%%" % [
			active_workers,
			int(round(avg_morale * 100.0))
		]

	if staff_rps_bonus_label != null:
		var bonus_pct: float = (rps_mult - 1.0) * 100.0
		staff_rps_bonus_label.text = "Staff RPS Multiplier: +%.1f%% (+5%% per worker * morale)" % bonus_pct

	if hyper_focus_status_label != null:
		var is_hyper: bool = gs.is_staff_hyper_focus_active() if gs.has_method("is_staff_hyper_focus_active") else false
		if is_hyper:
			var time_rem: float = gs.get_staff_hyper_focus_time_remaining() if gs.has_method("get_staff_hyper_focus_time_remaining") else 0.0
			hyper_focus_status_label.text = "Hyper-Focus: Active (%.1fs remaining, 1.5x speed)" % time_rem
			hyper_focus_status_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
		else:
			hyper_focus_status_label.text = "Hyper-Focus: Inactive"
			hyper_focus_status_label.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85))

# ------------------------------------------------------------------------------
# Tab 1: Recruiting & Specialist Roster
# ------------------------------------------------------------------------------

func _populate_role_options() -> void:
	if role_option_button == null:
		return
	role_option_button.clear()
	var gs = _get_game_state()
	var role_defs: Dictionary = gs.get("STAFF_ROLE_DEFINITIONS") if gs != null and "STAFF_ROLE_DEFINITIONS" in gs else {}

	for i in range(ROLE_KEYS.size()):
		var r_key: String = ROLE_KEYS[i]
		var cost: float = float(role_defs.get(r_key, {}).get("hire_cost", 1000.0))
		var title: String = str(role_defs.get(r_key, {}).get("title", r_key))
		var formatted_cost: String = gs.format_number(cost) if gs != null and gs.has_method("format_number") else str(int(cost))
		role_option_button.add_item("%s (%s Energy)" % [title, formatted_cost], i)

func _on_role_option_selected(_index: int) -> void:
	_update_recruit_button_state()

func _refresh_recruiting_tab() -> void:
	var gs = _get_game_state()
	if gs == null or workers_list_vbox == null:
		return

	# Clear previous card instances
	for child in workers_list_vbox.get_children():
		child.queue_free()

	var workers: Array = gs.get_hired_workers() if gs.has_method("get_hired_workers") else []

	if workers.is_empty():
		var empty_panel = PanelContainer.new()
		empty_panel.mouse_filter = Control.MOUSE_FILTER_STOP
		empty_panel.custom_minimum_size = Vector2(0, 100)
		var empty_lbl = Label.new()
		empty_lbl.text = "No specialists hired yet.\nSelect a role below and recruit your first autonomous teammate!"
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty_lbl.add_theme_color_override("font_color", Color(0.6, 0.75, 0.85))
		empty_lbl.add_theme_font_size_override("font_size", 14)
		empty_panel.add_child(empty_lbl)
		workers_list_vbox.add_child(empty_panel)
	else:
		for i in range(workers.size()):
			var w_data: Dictionary = workers[i]
			var card = _create_worker_card(w_data, i)
			workers_list_vbox.add_child(card)

	_update_recruit_button_state()

func _create_worker_card(w_data: Dictionary, index: int) -> PanelContainer:
	var gs = _get_game_state()
	var card = PanelContainer.new()
	card.name = "WorkerCard%d" % index
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.custom_minimum_size = Vector2(56, 76)

	var card_style = StyleBoxFlat.new()
	card_style.bg_color = Color(0.06, 0.09, 0.13, 0.94)
	card_style.border_color = Color(0.18, 0.35, 0.45, 0.9)
	card_style.set_border_width_all(2)
	card_style.set_corner_radius_all(8)
	card_style.content_margin_left = 14.0
	card_style.content_margin_top = 8.0
	card_style.content_margin_right = 14.0
	card_style.content_margin_bottom = 8.0
	card.add_theme_stylebox_override("panel", card_style)

	var hbox = HBoxContainer.new()
	hbox.mouse_filter = Control.MOUSE_FILTER_STOP
	hbox.add_theme_constant_override("separation", 12)
	card.add_child(hbox)

	# Info VBox
	var info_vbox = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.mouse_filter = Control.MOUSE_FILTER_STOP
	info_vbox.add_theme_constant_override("separation", 2)
	hbox.add_child(info_vbox)

	var role: String = str(w_data.get("role", "Specialist"))
	var name_str: String = str(w_data.get("name", role))
	var desk_num: int = int(w_data.get("desk_assigned", 0)) + 1
	var morale: float = clampf(float(w_data.get("morale", 1.0)), 0.0, 1.0)
	var fatigue: float = clampf(float(w_data.get("fatigue", 0.0)), 0.0, 1.0)
	var state_str: String = str(w_data.get("current_state", "working")).to_lower()

	var state_icon: String = "💻"
	if state_str == "fatigued":
		state_icon = "💤"
	elif state_str in ["coffee_break", "break"]:
		state_icon = "☕"
	elif state_str == "celebrating":
		state_icon = "🎉"

	var title_lbl = Label.new()
	title_lbl.text = "%s %s — %s (Desk %d)" % [state_icon, name_str, role, desk_num]
	title_lbl.add_theme_font_size_override("font_size", 15)
	title_lbl.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	info_vbox.add_child(title_lbl)

	var status_lbl = Label.new()
	status_lbl.text = "Status: %s • Morale: %d%% • Fatigue: %d%%" % [
		state_str.capitalize(),
		int(round(morale * 100.0)),
		int(round(fatigue * 100.0))
	]
	status_lbl.add_theme_font_size_override("font_size", 12)
	if state_str == "fatigued":
		status_lbl.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	else:
		status_lbl.add_theme_color_override("font_color", Color(0.3, 0.9, 0.6))
	info_vbox.add_child(status_lbl)

	# Fire/Dismiss Button
	var fire_btn = Button.new()
	fire_btn.name = "FireButton_%d" % index
	fire_btn.text = "Entlassen"
	fire_btn.custom_minimum_size = Vector2(100, 56)
	fire_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	fire_btn.focus_mode = Control.FOCUS_NONE
	fire_btn.add_theme_font_size_override("font_size", 13)

	var fire_style = StyleBoxFlat.new()
	fire_style.bg_color = Color(0.28, 0.08, 0.10, 0.92)
	fire_style.border_color = Color(0.95, 0.35, 0.35, 0.9)
	fire_style.set_border_width_all(2)
	fire_style.set_corner_radius_all(6)
	fire_btn.add_theme_stylebox_override("normal", fire_style)

	var w_id: String = str(w_data.get("id", ""))
	fire_btn.pressed.connect(func():
		_play_sfx_click()
		if gs != null and gs.has_method("fire_worker"):
			gs.fire_worker(w_id)
	)
	hbox.add_child(fire_btn)

	return card

func _update_recruit_button_state() -> void:
	if recruit_button == null or role_option_button == null:
		return
	var gs = _get_game_state()
	if gs == null:
		return

	var workers: Array = gs.get_hired_workers() if gs.has_method("get_hired_workers") else []
	if workers.size() >= 5:
		recruit_button.text = "Office Full (5/5)"
		recruit_button.disabled = true
		return

	var sel_idx = role_option_button.selected
	if sel_idx < 0 or sel_idx >= ROLE_KEYS.size():
		sel_idx = 0
	var sel_role = ROLE_KEYS[sel_idx]

	var role_defs: Dictionary = gs.get("STAFF_ROLE_DEFINITIONS") if "STAFF_ROLE_DEFINITIONS" in gs else {}
	var cost: float = float(role_defs.get(sel_role, {}).get("hire_cost", 1000.0))

	# Check duplicate role
	var already_hired: bool = false
	for w in workers:
		if str(w.get("role", "")).to_lower() == sel_role.to_lower():
			already_hired = true
			break

	if already_hired:
		recruit_button.text = "Bereits eingestellt"
		recruit_button.disabled = true
	elif gs.energy < cost:
		recruit_button.text = "Nicht genug Energy"
		recruit_button.disabled = true
	else:
		var formatted_cost = gs.format_number(cost) if gs.has_method("format_number") else str(int(cost))
		recruit_button.text = "Einstellen (%s)" % formatted_cost
		recruit_button.disabled = false

func _on_recruit_button_pressed() -> void:
	_play_sfx_click()
	var gs = _get_game_state()
	if gs == null or role_option_button == null:
		return
	var sel_idx = role_option_button.selected
	if sel_idx < 0 or sel_idx >= ROLE_KEYS.size():
		sel_idx = 0
	var sel_role = ROLE_KEYS[sel_idx]
	if gs.has_method("hire_worker"):
		var success: bool = gs.hire_worker(sel_role)
		if success:
			refresh_all()

# ------------------------------------------------------------------------------
# Tab 2: Desk Upgrades
# ------------------------------------------------------------------------------

func _refresh_desk_upgrades_tab() -> void:
	var gs = _get_game_state()
	if gs == null or desks_vbox == null:
		return

	for child in desks_vbox.get_children():
		child.queue_free()

	var desk_levels: Array = gs.get_desk_levels() if gs.has_method("get_desk_levels") else [1, 1, 1, 1, 1]
	var workers: Array = gs.get_hired_workers() if gs.has_method("get_hired_workers") else []

	for i in range(5):
		var lvl: int = int(desk_levels[i]) if i < desk_levels.size() else 1
		var assigned_worker_name: String = "Unoccupied"
		for w in workers:
			if int(w.get("desk_assigned", -1)) == i:
				assigned_worker_name = "%s (%s)" % [str(w.get("name", "")), str(w.get("role", ""))]
				break

		var card = _create_desk_card(i, lvl, assigned_worker_name)
		desks_vbox.add_child(card)

func _create_desk_card(desk_idx: int, level: int, occupant: String) -> PanelContainer:
	var gs = _get_game_state()
	var card = PanelContainer.new()
	card.name = "DeskCard%d" % (desk_idx + 1)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.custom_minimum_size = Vector2(56, 80)

	var card_style = StyleBoxFlat.new()
	card_style.bg_color = Color(0.06, 0.09, 0.13, 0.94)
	card_style.border_color = Color(0.2, 0.35, 0.45, 0.9)
	card_style.set_border_width_all(2)
	card_style.set_corner_radius_all(8)
	card_style.content_margin_left = 14.0
	card_style.content_margin_top = 8.0
	card_style.content_margin_right = 14.0
	card_style.content_margin_bottom = 8.0
	card.add_theme_stylebox_override("panel", card_style)

	var hbox = HBoxContainer.new()
	hbox.mouse_filter = Control.MOUSE_FILTER_STOP
	hbox.add_theme_constant_override("separation", 12)
	card.add_child(hbox)

	# Info VBox
	var info_vbox = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.mouse_filter = Control.MOUSE_FILTER_STOP
	info_vbox.add_theme_constant_override("separation", 2)
	hbox.add_child(info_vbox)

	var tier_name: String = "Basic Wooden Desk"
	var reduction_pct: int = 0
	if level == 2:
		tier_name = "Dual-Monitor Tech Desk"
		reduction_pct = 25
	elif level >= 3:
		tier_name = "Cyber Standing Desk mit RGB"
		reduction_pct = 60

	var title_lbl = Label.new()
	title_lbl.text = "🖥️ Schreibtisch %d: %s (Lvl %d)" % [desk_idx + 1, tier_name, level]
	title_lbl.add_theme_font_size_override("font_size", 15)
	title_lbl.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	info_vbox.add_child(title_lbl)

	var desc_lbl = Label.new()
	desc_lbl.text = "Ergonomie: -%d%% Ermüdung • Belegt durch: %s" % [reduction_pct, occupant]
	desc_lbl.add_theme_font_size_override("font_size", 12)
	desc_lbl.add_theme_color_override("font_color", Color(0.25, 0.85, 0.95))
	info_vbox.add_child(desc_lbl)

	# Upgrade Button
	var up_btn = Button.new()
	up_btn.name = "UpgradeDeskButton_%d" % desk_idx
	up_btn.custom_minimum_size = Vector2(150, 56)
	up_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	up_btn.focus_mode = Control.FOCUS_NONE
	up_btn.add_theme_font_size_override("font_size", 14)

	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.08, 0.35, 0.45, 0.95)
	btn_style.border_color = Color(0.0, 0.92, 1.0, 1.0)
	btn_style.set_border_width_all(2)
	btn_style.set_corner_radius_all(6)
	up_btn.add_theme_stylebox_override("normal", btn_style)

	if level >= 3:
		up_btn.text = "MAX LEVEL"
		up_btn.disabled = true
	else:
		var cost: float = gs.get_desk_upgrade_cost(desk_idx) if gs != null and gs.has_method("get_desk_upgrade_cost") else 5000.0
		var formatted = gs.format_number(cost) if gs != null and gs.has_method("format_number") else str(int(cost))
		up_btn.text = "Upgrade: %s" % formatted
		up_btn.disabled = (gs != null and gs.energy < cost)

		up_btn.pressed.connect(func():
			_play_sfx_click()
			if gs != null and gs.has_method("upgrade_desk"):
				var success: bool = gs.upgrade_desk(desk_idx)
				if success:
					refresh_all()
		)
	hbox.add_child(up_btn)

	return card

func _update_desk_buttons_state() -> void:
	var gs = _get_game_state()
	if gs == null or desks_vbox == null:
		return
	for i in range(desks_vbox.get_child_count()):
		var card = desks_vbox.get_child(i)
		var up_btn = card.find_child("UpgradeDeskButton_%d" % i, true, false) as Button
		if up_btn != null and up_btn.text != "MAX LEVEL":
			var cost: float = gs.get_desk_upgrade_cost(i) if gs.has_method("get_desk_upgrade_cost") else 5000.0
			up_btn.disabled = (gs.energy < cost)

# ------------------------------------------------------------------------------
# Tab 3: Teambuilding & Kaffeeration
# ------------------------------------------------------------------------------

func _refresh_teambuilding_tab() -> void:
	var gs = _get_game_state()
	if gs == null:
		return

	var is_hyper: bool = gs.is_staff_hyper_focus_active() if gs.has_method("is_staff_hyper_focus_active") else false
	var time_rem: float = gs.get_staff_hyper_focus_time_remaining() if gs.has_method("get_staff_hyper_focus_time_remaining") else 0.0

	if hyper_focus_progress_bar != null:
		hyper_focus_progress_bar.max_value = 60.0
		hyper_focus_progress_bar.value = time_rem

	if serve_coffee_break_button != null:
		if is_hyper:
			serve_coffee_break_button.text = "☕ Coffee Break aktiv (%.1fs - Erneut servieren)" % time_rem
		else:
			serve_coffee_break_button.text = "☕ Coffee Break servieren (Sofort-Moral & Hyper-Focus)"

	if espresso_synergy_label != null:
		var espresso_active: bool = bool(gs.get("unicorn_espresso_buff_active")) if "unicorn_espresso_buff_active" in gs else false
		if espresso_active:
			espresso_synergy_label.text = "☕ Super-Espresso Machine Synergie: AKTIV (+50% Sync Hyper-Focus Boost)"
			espresso_synergy_label.add_theme_color_override("font_color", Color(0.2, 0.95, 0.6))
		else:
			espresso_synergy_label.text = "☕ Super-Espresso Machine Synergie: Inaktiv (Espresso an Barista-Maschine brauen)"
			espresso_synergy_label.add_theme_color_override("font_color", Color(0.85, 0.55, 0.2))

func _on_serve_coffee_break_pressed() -> void:
	_play_sfx_click()
	var gs = _get_game_state()
	if gs != null and gs.has_method("give_team_coffee_break"):
		gs.give_team_coffee_break()
		refresh_all()

# ------------------------------------------------------------------------------
# Process Loop for Realtime Hyper-Focus Animation
# ------------------------------------------------------------------------------

func _process(_delta: float) -> void:
	var gs = _get_game_state()
	if gs == null:
		return

	if gs.has_method("is_staff_hyper_focus_active") and gs.is_staff_hyper_focus_active():
		var time_rem: float = gs.get_staff_hyper_focus_time_remaining()
		if hyper_focus_progress_bar != null and active_tab_index == 2:
			hyper_focus_progress_bar.value = time_rem
		if hyper_focus_status_label != null:
			hyper_focus_status_label.text = "Hyper-Focus: Active (%.1fs remaining, 1.5x speed)" % time_rem
		if serve_coffee_break_button != null and active_tab_index == 2:
			serve_coffee_break_button.text = "☕ Coffee Break aktiv (%.1fs - Erneut servieren)" % time_rem

# ------------------------------------------------------------------------------
# Modal Open & Close Lifecycle
# ------------------------------------------------------------------------------

func open() -> void:
	visible = true
	_play_sfx_click()
	refresh_all()

func close() -> void:
	_play_sfx_click()
	closed.emit()
	queue_free()
