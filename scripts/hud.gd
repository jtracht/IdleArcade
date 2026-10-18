extends Control

## UI HUD Controller for IdleArcade.
## Binds GameState typed signals to energy counters, RPS indicators,
## combo frenzy progress bar, and dynamic upgrade shop cards.

@onready var energy_label: Label = %EnergyLabel
@onready var rps_label: Label = %RPSLabel
@onready var frenzy_multiplier_label: Label = %FrenzyMultiplierLabel
@onready var frenzy_progress_bar: ProgressBar = %FrenzyProgressBar
@onready var upgrade_list: VBoxContainer = %UpgradeList

const AUTH_MODAL_SCENE: PackedScene = preload("res://scenes/ui/auth_modal.tscn")
const LEADERBOARD_MODAL_SCENE: PackedScene = preload("res://scenes/ui/leaderboard_modal.tscn")
const GUILD_MODAL_SCENE: PackedScene = preload("res://scenes/ui/guild_modal.tscn")
const QUEST_MODAL_SCENE: PackedScene = preload("res://scenes/ui/quest_modal.tscn")
const TECH_TREE_MODAL_SCENE: PackedScene = preload("res://scenes/ui/tech_tree_modal.tscn")
const SETTINGS_MODAL_SCENE: PackedScene = preload("res://scenes/ui/settings_modal.tscn")
const IPO_MODAL_SCENE: PackedScene = preload("res://scenes/ui/ipo_modal.tscn")
const DAILY_BOARD_MODAL_SCENE: PackedScene = preload("res://scenes/ui/daily_board_modal.tscn")
const SYNDICATE_MODAL_SCENE: PackedScene = preload("res://scenes/ui/syndicate_modal.tscn")
const STAFF_MODAL_SCENE: PackedScene = preload("res://scenes/ui/staff_modal.tscn")

@onready var status_indicator: Label = %StatusIndicator
@onready var streak_badge: Control = get_node_or_null("%StreakBadge")
@onready var streak_badge_label: Label = get_node_or_null("%StreakBadgeLabel")
@onready var syndicate_badge: Control = get_node_or_null("%SyndicateBadge")
@onready var syndicate_badge_label: Label = get_node_or_null("%SyndicateBadgeLabel")
@onready var staff_badge: Control = get_node_or_null("%StaffBadge")
@onready var staff_badge_label: Label = get_node_or_null("%StaffBadgeLabel")
@onready var auth_button: Button = %AuthButton
@onready var leaderboard_button: Button = %LeaderboardButton
@onready var guild_button: Button = %GuildButton
@onready var quest_button: Button = %QuestButton
@onready var campus_button: Button = get_node_or_null("%CampusButton")
@onready var tech_tree_button: Button = get_node_or_null("%TechTreeButton")
@onready var settings_button: Button = get_node_or_null("%SettingsButton")
@onready var ipo_button: Button = get_node_or_null("%IPOButton")
@onready var syndicate_button: Button = get_node_or_null("%SyndicateButton")
@onready var staff_button: Button = get_node_or_null("%StaffButton")

@onready var burger_menu_button: Button = get_node_or_null("%BurgerMenuButton")
@onready var campaign_badge: PanelContainer = get_node_or_null("%CampaignBadge")
@onready var chapter_title_label: Label = get_node_or_null("%ChapterTitleLabel")
@onready var story_mission_label: Label = get_node_or_null("%StoryMissionLabel")
@onready var badge_progress_label: Label = get_node_or_null("%BadgeProgressLabel")
@onready var live_event_banner: PanelContainer = get_node_or_null("%LiveEventBanner")
@onready var live_event_title_label: Label = get_node_or_null("%LiveEventTitleLabel")
@onready var live_event_timer_label: Label = get_node_or_null("%LiveEventTimerLabel")
@onready var live_event_progress_bar: ProgressBar = get_node_or_null("%LiveEventProgressBar")
@onready var live_event_progress_label: Label = get_node_or_null("%LiveEventProgressLabel")
@onready var nav_drawer: Control = get_node_or_null("%NavDrawer")
@onready var close_nav_button: Button = get_node_or_null("%CloseNavButton")
@onready var nav_backdrop: Button = get_node_or_null("%NavDrawerBackdrop")
@onready var modal_container: Control = %ModalContainer

var _active_modal: Control = null

const UPGRADE_DEFINITIONS: Array[Dictionary] = [
	{
		"id": "click_booster",
		"name": "Freelancer Marketing",
		"base_cost": 10.0,
		"cost_mult": 1.18,
		"power_gain": 1.0,
		"type": "click",
		"description": "+1 User per click"
	},
	{
		"id": "tier_1",
		"name": "Virale Memes",
		"base_cost": 25.0,
		"cost_mult": 1.15,
		"power_gain": 1.0,
		"type": "idle",
		"description": "+1 User / sec"
	},
	{
		"id": "tier_2",
		"name": "Empfehlungsprogramm",
		"base_cost": 150.0,
		"cost_mult": 1.15,
		"power_gain": 8.0,
		"type": "idle",
		"description": "+8 Users / sec"
	},
	{
		"id": "tier_3",
		"name": "SEO-Optimierung",
		"base_cost": 800.0,
		"cost_mult": 1.15,
		"power_gain": 40.0,
		"type": "idle",
		"description": "+40 Users / sec"
	},
	{
		"id": "tier_4",
		"name": "Social Media Ads",
		"base_cost": 4500.0,
		"cost_mult": 1.15,
		"power_gain": 250.0,
		"type": "idle",
		"description": "+250 Users / sec"
	},
	{
		"id": "tier_5",
		"name": "Influencer-Deals",
		"base_cost": 30000.0,
		"cost_mult": 1.15,
		"power_gain": 1500.0,
		"type": "idle",
		"description": "+1.5K Users / sec"
	},
	{
		"id": "tier_6",
		"name": "TV-Werbespots",
		"base_cost": 250000.0,
		"cost_mult": 1.15,
		"power_gain": 10000.0,
		"type": "idle",
		"description": "+10K Users / sec"
	},
	{
		"id": "tier_7",
		"name": "Super Bowl Spot",
		"base_cost": 2000000.0,
		"cost_mult": 1.15,
		"power_gain": 75000.0,
		"type": "idle",
		"description": "+75K Users / sec"
	},
	{
		"id": "overdrive_tuning",
		"name": "Hype Tuning",
		"base_cost": 100.0,
		"cost_mult": 1.30,
		"power_gain": 0.5,
		"type": "frenzy",
		"description": "+0.5x Viraler Hype Multiplier"
	},
	{
		"id": "avatar_speed",
		"name": "Agile Sneakers",
		"base_cost": 50.0,
		"cost_mult": 1.25,
		"power_gain": 0.15,
		"type": "avatar_stat",
		"description": "+15% Avatar Run Speed"
	},
	{
		"id": "clearance_level",
		"name": "Executive Badge",
		"base_cost": 250.0,
		"cost_mult": 1.75,
		"power_gain": 1.0,
		"type": "meta",
		"description": "Unlocks campus security zones"
	},
	{
		"id": "pickup_radius",
		"name": "Magnetic Charm",
		"base_cost": 75.0,
		"cost_mult": 1.25,
		"power_gain": 0.25,
		"type": "avatar_stat",
		"description": "+25% 3D Item Pickup Radius"
	}
]

var _upgrade_cards: Dictionary = {}
var _last_confetti_burst_msec: int = -10000

func _ready() -> void:
	_build_upgrade_cards()
	_connect_game_state_signals()
	_bind_action_bar_buttons()
	_connect_nakama_signals()
	_connect_live_event_signals()
	_refresh_all_ui()

func _connect_game_state_signals() -> void:
	if GameState == null:
		return
		
	if GameState.has_signal("energy_changed"):
		GameState.energy_changed.connect(_on_energy_changed)
	if GameState.has_signal("rps_changed"):
		GameState.rps_changed.connect(_on_rps_changed)
	if GameState.has_signal("frenzy_updated"):
		GameState.frenzy_updated.connect(_on_frenzy_updated)
	if GameState.has_signal("upgrade_purchased"):
		GameState.upgrade_purchased.connect(_on_upgrade_purchased)
	if GameState.has_signal("level_up"):
		GameState.level_up.connect(_on_level_up)
	if GameState.has_signal("campaign_chapter_changed"):
		GameState.campaign_chapter_changed.connect(_on_campaign_chapter_changed)
	if GameState.has_signal("campaign_quest_completed"):
		GameState.campaign_quest_completed.connect(_on_campaign_quest_completed)
	if GameState.has_signal("campaign_choice_selected"):
		GameState.campaign_choice_selected.connect(_on_campaign_choice_selected)
	if GameState.has_signal("daily_streak_updated"):
		GameState.daily_streak_updated.connect(_on_daily_streak_updated)
	if GameState.has_signal("syndicate_joined"):
		GameState.syndicate_joined.connect(_on_syndicate_state_changed)
	if GameState.has_signal("syndicate_left"):
		GameState.syndicate_left.connect(_on_syndicate_state_changed)
	if GameState.has_signal("syndicate_contributed"):
		GameState.syndicate_contributed.connect(_on_syndicate_state_changed)
	if GameState.has_signal("syndicate_tier_upgraded"):
		GameState.syndicate_tier_upgraded.connect(_on_syndicate_state_changed)
	if GameState.has_signal("syndicate_season_updated"):
		GameState.syndicate_season_updated.connect(_on_syndicate_state_changed)
	if GameState.has_signal("staff_worker_hired"):
		GameState.staff_worker_hired.connect(_on_staff_state_changed)
	elif GameState.has_signal("worker_hired"):
		GameState.worker_hired.connect(_on_staff_state_changed)
	if GameState.has_signal("staff_worker_fired"):
		GameState.staff_worker_fired.connect(_on_staff_state_changed)
	elif GameState.has_signal("worker_fired"):
		GameState.worker_fired.connect(_on_staff_state_changed)
	if GameState.has_signal("staff_worker_state_changed"):
		GameState.staff_worker_state_changed.connect(_on_staff_state_changed)
	elif GameState.has_signal("worker_state_changed"):
		GameState.worker_state_changed.connect(_on_staff_state_changed)
	if GameState.has_signal("staff_worker_morale_updated"):
		GameState.staff_worker_morale_updated.connect(_on_staff_state_changed)
	if GameState.has_signal("staff_desk_upgraded"):
		GameState.staff_desk_upgraded.connect(_on_staff_state_changed)
	elif GameState.has_signal("desk_upgraded"):
		GameState.desk_upgraded.connect(_on_staff_state_changed)
	if GameState.has_signal("staff_coffee_break_started"):
		GameState.staff_coffee_break_started.connect(_on_staff_state_changed)
	elif GameState.has_signal("team_coffee_break_started"):
		GameState.team_coffee_break_started.connect(_on_staff_state_changed)
	if GameState.has_signal("staff_coffee_break_ended"):
		GameState.staff_coffee_break_ended.connect(_on_staff_state_changed)
	elif GameState.has_signal("team_coffee_break_ended"):
		GameState.team_coffee_break_ended.connect(_on_staff_state_changed)
	if GameState.has_signal("staff_morale_updated"):
		GameState.staff_morale_updated.connect(_on_staff_state_changed)
	if GameState.has_signal("staff_bonus_updated"):
		GameState.staff_bonus_updated.connect(_on_staff_state_changed)

func _refresh_all_ui() -> void:
	if GameState == null:
		return
		
	_on_energy_changed(GameState.energy, 0.0)
	_on_rps_changed(GameState.base_passive_rps)
	_on_frenzy_updated(GameState.frenzy_multiplier, GameState.frenzy_meter)
	_update_campaign_badge()
	_update_streak_badge(GameState.get_daily_streak() if GameState.has_method("get_daily_streak") else int(GameState.get("daily_board_streak")))
	_update_syndicate_badge()
	_update_staff_badge()
	_refresh_live_event_banner()
	_refresh_all_upgrade_buttons()

func _on_staff_state_changed(_arg1 = null, _arg2 = null, _arg3 = null, _arg4 = null) -> void:
	_update_staff_badge()

func _update_staff_badge() -> void:
	if staff_badge_label == null:
		return
	var count: int = 0
	var avg_morale: float = 1.0
	if GameState != null:
		if GameState.has_method("get_hired_workers"):
			count = GameState.get_hired_workers().size()
		elif "hired_workers" in GameState:
			count = GameState.hired_workers.size()
		if GameState.has_method("get_staff_average_morale"):
			avg_morale = GameState.get_staff_average_morale()
		elif GameState.has_method("get_average_worker_morale"):
			avg_morale = GameState.get_average_worker_morale()
	staff_badge_label.text = "👥 %d (%d%%)" % [count, int(round(avg_morale * 100.0))]

func _on_syndicate_state_changed(_arg1 = null, _arg2 = null, _arg3 = null, _arg4 = null) -> void:
	_update_syndicate_badge()

func _update_syndicate_badge() -> void:
	if syndicate_badge_label == null:
		return
	if GameState != null and GameState.has_method("is_in_syndicate") and GameState.is_in_syndicate():
		var syn_data: Dictionary = GameState.get_active_syndicate()
		var tag: String = str(syn_data.get("tag", "ARK")).strip_edges()
		if tag.is_empty():
			tag = "ARK"
		var div_mult: float = GameState.get_syndicate_dividend_multiplier()
		var div_pct: int = int(round((div_mult - 1.0) * 100.0))
		syndicate_badge_label.text = "🏢 [%s] +%d%%" % [tag, div_pct]
	else:
		syndicate_badge_label.text = "🏢 [SOLO]"

func _on_daily_streak_updated(new_streak: int) -> void:
	_update_streak_badge(new_streak)

func _update_streak_badge(streak: int) -> void:
	if streak_badge_label != null:
		streak_badge_label.text = "🔥 %d" % streak

func _on_energy_changed(total_energy: float, _delta_amount: float) -> void:
	if energy_label:
		var formatted: String = GameState.format_number(total_energy) if GameState != null else str(int(total_energy))
		energy_label.text = "👥 " + formatted
	_refresh_affordability(total_energy)

func _on_rps_changed(rate_per_sec: float) -> void:
	if rps_label:
		var formatted: String = GameState.format_number(rate_per_sec) if GameState != null else str(rate_per_sec)
		rps_label.text = "+%s / sec" % formatted

func _on_frenzy_updated(multiplier: float, fill_percentage: float) -> void:
	if frenzy_progress_bar:
		frenzy_progress_bar.value = fill_percentage
	
	if frenzy_multiplier_label:
		if GameState != null and GameState.is_frenzy_active:
			frenzy_multiplier_label.text = "VIRALER HYPE %.1fx" % multiplier
			frenzy_multiplier_label.add_theme_color_override("font_color", Color(1.0, 0.25, 0.35))
		else:
			frenzy_multiplier_label.text = "%.1fx" % multiplier
			frenzy_multiplier_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))

func _on_upgrade_purchased(upgrade_id: String, new_level: int, current_cost: float) -> void:
	if not _upgrade_cards.has(upgrade_id):
		return
		
	var card: Dictionary = _upgrade_cards[upgrade_id]
	var title_lbl: Label = card["title_label"]
	var buy_btn: Button = card["buy_button"]
	var def: Dictionary = card["def"]
	
	title_lbl.text = "%s [Lvl %d]" % [def["name"], new_level]
	buy_btn.text = "Buy: " + (GameState.format_number(current_cost) if GameState != null else str(int(current_cost)))
	
	card["panel"].pivot_offset = card["panel"].size * 0.5
	var tween = card["panel"].create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	card["panel"].scale = Vector2(1.04, 1.04)
	tween.tween_property(card["panel"], "scale", Vector2.ONE, 0.12)
	
	var hm = get_node_or_null("/root/HapticsManager")
	if hm != null and hm.has_method("vibrate_button"):
		hm.vibrate_button()
	elif OS.has_feature("mobile") and Input.has_method("vibrate_handheld"):
		Input.vibrate_handheld(20)

	if upgrade_id == "clearance_level":
		_trigger_level_up_confetti()

	_refresh_affordability(GameState.energy if GameState != null else 0.0)

func _on_level_up(_new_level: int) -> void:
	_trigger_level_up_confetti()

func _on_campaign_chapter_changed(chapter: int) -> void:
	_update_campaign_badge(chapter)

func _on_campaign_quest_completed(_quest_id: String, _chapter: int) -> void:
	_update_campaign_badge()

func _on_campaign_choice_selected(_chapter: int, _choice_id: String, _reward_type: String) -> void:
	_update_campaign_badge()

func _update_campaign_badge(chapter: int = -1) -> void:
	if campaign_badge == null:
		return
	var ch: int = chapter
	if ch <= 0:
		ch = GameState.campaign_chapter if (GameState != null and "campaign_chapter" in GameState) else 1
	ch = clampi(ch, 1, 3)

	var titles: Dictionary = {
		1: "🦄 CHAPTER 1: SEED STAGE",
		2: "🦄 CHAPTER 2: SERIES A",
		3: "🦄 CHAPTER 3: UNICORN STATUS"
	}
	
	if chapter_title_label != null:
		chapter_title_label.text = titles.get(ch, "🦄 CHAPTER 1: SEED STAGE")
		
	if badge_progress_label != null:
		badge_progress_label.text = "[%d / 3]" % ch

	if story_mission_label != null:
		if GameState != null and GameState.has_method("get_active_story_mission_text"):
			story_mission_label.text = GameState.get_active_story_mission_text()
		else:
			var missions: Dictionary = {
				1: "Deploy MVP with CEO Alex",
				2: "Scale Campus with Architekt Bob",
				3: "Brew Super-Espresso with Dr. Lisa"
			}
			var mission_text: String = missions.get(ch, "Deploy MVP with CEO Alex")
			if GameState != null and "campaign_completed_quests" in GameState:
				if ch == 1 and GameState.campaign_completed_quests.has("quest_briefcases"):
					mission_text = "MVP Launched! Meet Architekt Bob"
				elif ch == 2 and GameState.campaign_completed_quests.has("quest_server"):
					mission_text = "Server Overclocked! Meet Dr. Lisa"
				elif ch == 3 and GameState.campaign_completed_quests.has("quest_lab"):
					mission_text = "Unicorn Journey Complete!"
			story_mission_label.text = mission_text

func _trigger_level_up_confetti() -> void:
	var now = Time.get_ticks_msec()
	if now - _last_confetti_burst_msec < 500:
		return
	_last_confetti_burst_msec = now
	var confetti_cls = load("res://scripts/vfx/confetti_burst.gd")
	if confetti_cls != null and confetti_cls.has_method("spawn_burst_2d"):
		var burst_pos = get_viewport_rect().size * 0.5 if is_inside_tree() else Vector2(250, 300)
		confetti_cls.spawn_burst_2d(self, burst_pos, 50)

## Builds dynamic upgrade cards in the shop panel
func _build_upgrade_cards() -> void:
	if not upgrade_list:
		return
	for def in UPGRADE_DEFINITIONS:
		var card: Dictionary = _create_upgrade_card(def)
		upgrade_list.add_child(card["panel"])
		_upgrade_cards[def["id"]] = card

func _create_upgrade_card(def: Dictionary) -> Dictionary:
	var panel = PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.12, 0.18, 0.9)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_right = 10
	style.corner_radius_bottom_left = 10
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.18, 0.24, 0.35, 0.5)
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	panel.add_theme_stylebox_override("panel", style)
	
	var hbox = HBoxContainer.new()
	hbox.mouse_filter = Control.MOUSE_FILTER_STOP
	hbox.add_theme_constant_override("separation", 10)
	panel.add_child(hbox)
	
	# Left: Details VBox
	var vbox = VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_STOP
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(vbox)
	
	var title_lbl = Label.new()
	var current_level: int = 0
	if GameState != null and GameState.upgrades.has(def["id"]):
		current_level = int(GameState.upgrades[def["id"]].get("level", 0))
	title_lbl.text = "%s [Lvl %d]" % [def["name"], current_level]
	title_lbl.add_theme_font_size_override("font_size", 16)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	vbox.add_child(title_lbl)
	
	var desc_lbl = Label.new()
	desc_lbl.text = def["description"]
	desc_lbl.add_theme_font_size_override("font_size", 13)
	desc_lbl.add_theme_color_override("font_color", Color(0.0, 0.85, 1.0))
	vbox.add_child(desc_lbl)
	
	# Right: Buy Button
	var buy_btn = Button.new()
	buy_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	buy_btn.custom_minimum_size = Vector2(130, 56)
	var initial_cost: float = def["base_cost"]
	if GameState != null and GameState.upgrades.has(def["id"]):
		initial_cost = float(GameState.upgrades[def["id"]].get("current_cost", def["base_cost"]))
	buy_btn.text = "Buy: " + (GameState.format_number(initial_cost) if GameState != null else str(int(initial_cost)))
	buy_btn.pressed.connect(_on_buy_button_pressed.bind(def["id"]))
	hbox.add_child(buy_btn)
	
	panel.pivot_offset = Vector2(170.0, 36.0)
	panel.resized.connect(func():
		if panel != null:
			panel.pivot_offset = panel.size * 0.5
	)

	return {
		"id": def["id"],
		"panel": panel,
		"title_label": title_lbl,
		"desc_label": desc_lbl,
		"buy_button": buy_btn,
		"def": def,
		"style": style,
		"is_affordable": false,
		"glow_tween": null
	}

func _on_buy_button_pressed(upgrade_id: String) -> void:
	if GameState != null and GameState.has_method("buy_upgrade"):
		GameState.buy_upgrade(upgrade_id)

func _refresh_affordability(total_energy: float) -> void:
	for id in _upgrade_cards:
		var card: Dictionary = _upgrade_cards[id]
		var btn: Button = card["buy_button"]
		var cost: float = card["def"]["base_cost"]
		if GameState != null and GameState.upgrades.has(id):
			cost = float(GameState.upgrades[id].get("current_cost", cost))
		
		var can_afford: bool = (total_energy >= cost)
		btn.disabled = not can_afford
		
		var was_affordable: bool = card.get("is_affordable", false)
		if can_afford and not was_affordable:
			card["is_affordable"] = true
			_start_card_glow_pulse(card)
		elif not can_afford and was_affordable:
			card["is_affordable"] = false
			_stop_card_glow_pulse(card)

func _start_card_glow_pulse(card: Dictionary) -> void:
	var panel: PanelContainer = card["panel"]
	var style: StyleBoxFlat = card["style"]
	style.shadow_color = Color(0.0, 0.85, 1.0, 0.25)
	style.shadow_size = 4
	if card.get("glow_tween") != null and card["glow_tween"].is_valid():
		card["glow_tween"].kill()
	var tw: Tween = panel.create_tween().set_loops()
	tw.tween_property(style, "border_color", Color(0.2, 0.8, 1.0, 0.9), 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(style, "border_color", Color(0.1, 0.4, 0.6, 0.4), 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	card["glow_tween"] = tw

func _stop_card_glow_pulse(card: Dictionary) -> void:
	if card.get("glow_tween") != null and card["glow_tween"].is_valid():
		card["glow_tween"].kill()
	card["glow_tween"] = null
	var style: StyleBoxFlat = card["style"]
	style.border_color = Color(0.18, 0.24, 0.35, 0.5)
	style.shadow_size = 0

## Helper to query card pulsation state for testing
func is_card_pulsing(upgrade_id: String) -> bool:
	if _upgrade_cards.has(upgrade_id):
		return _upgrade_cards[upgrade_id].get("is_affordable", false)
	return false

## Helper to query card border color for testing
func get_card_border_color(upgrade_id: String) -> Color:
	if _upgrade_cards.has(upgrade_id) and _upgrade_cards[upgrade_id].has("style"):
		return _upgrade_cards[upgrade_id]["style"].border_color
	return Color.TRANSPARENT

func _refresh_all_upgrade_buttons() -> void:
	var total_energy: float = GameState.energy if GameState != null else 0.0
	_refresh_affordability(total_energy)

func toggle_burger_menu() -> void:
	if nav_drawer == null:
		return
	if nav_drawer.visible:
		close_nav_drawer()
	else:
		open_nav_drawer()

func open_nav_drawer() -> void:
	if nav_drawer == null:
		return
	nav_drawer.visible = true
	var hm = get_node_or_null("/root/HapticsManager")
	if hm != null and hm.has_method("vibrate_button"):
		hm.vibrate_button()

func close_nav_drawer() -> void:
	if nav_drawer == null:
		return
	nav_drawer.visible = false

func _bind_action_bar_buttons() -> void:
	if burger_menu_button != null:
		burger_menu_button.pressed.connect(toggle_burger_menu)
	if close_nav_button != null:
		close_nav_button.pressed.connect(close_nav_drawer)
	if nav_backdrop != null:
		nav_backdrop.pressed.connect(close_nav_drawer)
	if auth_button != null:
		auth_button.pressed.connect(func():
			close_nav_drawer()
			open_modal(AUTH_MODAL_SCENE)
		)
	if leaderboard_button != null:
		leaderboard_button.pressed.connect(func():
			close_nav_drawer()
			open_modal(LEADERBOARD_MODAL_SCENE)
		)
	if guild_button != null:
		guild_button.pressed.connect(func():
			close_nav_drawer()
			open_modal(GUILD_MODAL_SCENE)
		)
	if quest_button != null:
		quest_button.pressed.connect(func():
			close_nav_drawer()
			open_modal(QUEST_MODAL_SCENE)
		)
	if campus_button != null:
		campus_button.pressed.connect(func():
			close_nav_drawer()
			_on_campus_button_pressed()
		)
	if tech_tree_button != null:
		tech_tree_button.pressed.connect(func():
			close_nav_drawer()
			open_modal(TECH_TREE_MODAL_SCENE)
		)
	if settings_button != null:
		settings_button.pressed.connect(func():
			close_nav_drawer()
			open_modal(SETTINGS_MODAL_SCENE)
		)
	if ipo_button != null:
		ipo_button.pressed.connect(func():
			close_nav_drawer()
			open_ipo_modal()
		)
	if streak_badge != null:
		if streak_badge is Button:
			streak_badge.pressed.connect(func():
				open_daily_board_modal()
			)
		else:
			streak_badge.gui_input.connect(func(event: InputEvent):
				if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
					open_daily_board_modal()
			)
	if syndicate_button != null:
		syndicate_button.pressed.connect(func():
			close_nav_drawer()
			open_syndicate_modal()
		)
	if syndicate_badge != null:
		if syndicate_badge is Button:
			syndicate_badge.pressed.connect(func():
				open_syndicate_modal()
			)
		else:
			syndicate_badge.gui_input.connect(func(event: InputEvent):
				if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
					open_syndicate_modal()
			)
	if staff_button != null:
		staff_button.pressed.connect(func():
			close_nav_drawer()
			open_staff_modal()
		)
	if staff_badge != null:
		if staff_badge is Button:
			staff_badge.pressed.connect(func():
				open_staff_modal()
			)
		else:
			staff_badge.gui_input.connect(func(event: InputEvent):
				if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
					open_staff_modal()
			)

func _on_campus_button_pressed() -> void:
	var main_3d = get_tree().root.find_child("Main3D", true, false)
	if main_3d != null and main_3d.has_method("close_hud_overlay"):
		main_3d.close_hud_overlay()
	else:
		if GameState != null and GameState.has_method("save_to_disk"):
			GameState.save_to_disk()
		get_tree().change_scene_to_file("res://scenes/main_3d.tscn")

func open_tech_tree_modal() -> Control:
	return open_modal(TECH_TREE_MODAL_SCENE)

func open_settings_modal() -> Control:
	return open_modal(SETTINGS_MODAL_SCENE)

func open_ipo_modal() -> Control:
	return open_modal(IPO_MODAL_SCENE)

func open_daily_board_modal() -> Control:
	return open_modal(DAILY_BOARD_MODAL_SCENE)

func open_syndicate_modal() -> Control:
	return open_modal(SYNDICATE_MODAL_SCENE)

func open_staff_modal() -> Control:
	return open_modal(STAFF_MODAL_SCENE)

func open_staff() -> Control:
	return open_staff_modal()

func open_modal(modal_scene: PackedScene) -> Control:
	close_nav_drawer()
	if _active_modal != null and is_instance_valid(_active_modal):
		if _active_modal.get_parent() != null:
			_active_modal.get_parent().remove_child(_active_modal)
		_active_modal.queue_free()
		_active_modal = null

	var modal_inst: Control = modal_scene.instantiate()
	if modal_container != null:
		modal_container.add_child(modal_inst)
	else:
		add_child(modal_inst)

	_active_modal = modal_inst

	# Stale closure guard: if _active_modal == modal_inst:
	if modal_inst.has_signal("closed"):
		modal_inst.closed.connect(func():
			if _active_modal == modal_inst:
				_active_modal = null
		)
	if modal_inst.has_method("open"):
		modal_inst.open()

	return modal_inst

func has_active_modal() -> bool:
	return _active_modal != null and is_instance_valid(_active_modal)

func dismiss_active_modal() -> bool:
	if has_active_modal():
		if _active_modal.has_method("close"):
			_active_modal.close()
		else:
			_active_modal.queue_free()
		_active_modal = null
		return true
	return false

func _get_nakama_manager() -> Node:
	if has_node("/root/NakamaManager"):
		return get_node("/root/NakamaManager")
	return null

func _connect_nakama_signals() -> void:
	var nm = _get_nakama_manager()
	if nm != null:
		if nm.has_signal("connection_status_changed") and not nm.connection_status_changed.is_connected(_on_connection_status_changed):
			nm.connection_status_changed.connect(_on_connection_status_changed)
		if nm.has_signal("authenticated") and not nm.authenticated.is_connected(_on_authenticated):
			nm.authenticated.connect(_on_authenticated)
		if nm.has_signal("logged_out") and not nm.logged_out.is_connected(_on_logged_out):
			nm.logged_out.connect(_on_logged_out)

		var online: bool = nm.is_online if "is_online" in nm else false
		_update_connection_status(online, "ONLINE" if online else "OFFLINE")
		if nm.has_method("is_authenticated") and nm.is_authenticated():
			_on_authenticated(nm.session if "session" in nm else null)
	else:
		_update_connection_status(false, "OFFLINE")

func _on_connection_status_changed(is_online: bool, status_text: String) -> void:
	_update_connection_status(is_online, status_text)

func _update_connection_status(is_online: bool, _status_text: String) -> void:
	if status_indicator == null:
		return
	if is_online:
		status_indicator.text = "● ONLINE"
		status_indicator.add_theme_color_override("font_color", Color(0.46, 1.0, 0.01))
	else:
		status_indicator.text = "○ OFFLINE"
		status_indicator.add_theme_color_override("font_color", Color(0.7, 0.75, 0.82))

func _on_authenticated(session) -> void:
	if auth_button != null and session != null:
		var uname: String = session.username if "username" in session else ""
		auth_button.text = "🔑 " + (uname if not uname.is_empty() else "Account")

func _on_logged_out() -> void:
	if auth_button != null:
		auth_button.text = "👤 Account"

func _exit_tree() -> void:
	for id in _upgrade_cards:
		var card = _upgrade_cards[id]
		if card.get("glow_tween") != null and card["glow_tween"].is_valid():
			card["glow_tween"].kill()
			card["glow_tween"] = null

func _process(_delta: float) -> void:
	var lem = _get_live_event_manager()
	if lem != null and live_event_banner != null and live_event_banner.visible:
		if lem.has_method("get_time_remaining"):
			_update_live_event_timer(lem.get_time_remaining())

# ==============================================================================
# Phase 13 Milestone M4: Cooperative Live-Campus Events
# ==============================================================================

func _get_live_event_manager() -> Node:
	if has_node("/root/LiveEventManager"):
		return get_node("/root/LiveEventManager")
	return null

func _connect_live_event_signals() -> void:
	var lem = _get_live_event_manager()
	if lem == null:
		return
	if lem.has_signal("live_event_started") and not lem.live_event_started.is_connected(_on_live_event_started):
		lem.live_event_started.connect(_on_live_event_started)
	if lem.has_signal("live_event_progress_updated") and not lem.live_event_progress_updated.is_connected(_on_live_event_progress_updated):
		lem.live_event_progress_updated.connect(_on_live_event_progress_updated)
	if lem.has_signal("live_event_milestone_reached") and not lem.live_event_milestone_reached.is_connected(_on_live_event_milestone_reached):
		lem.live_event_milestone_reached.connect(_on_live_event_milestone_reached)
	if lem.has_signal("live_event_completed") and not lem.live_event_completed.is_connected(_on_live_event_completed):
		lem.live_event_completed.connect(_on_live_event_completed)
	if lem.has_signal("live_event_ended") and not lem.live_event_ended.is_connected(_on_live_event_ended):
		lem.live_event_ended.connect(_on_live_event_ended)
	
	_refresh_live_event_banner()

func _refresh_live_event_banner() -> void:
	var lem = _get_live_event_manager()
	if lem == null or live_event_banner == null:
		return
	if lem.has_method("is_event_active") and (lem.is_event_active() or (lem.has_method("get_active_event") and lem.get_active_event().get("state_name") == "COMPLETED")):
		var data: Dictionary = lem.get_active_event()
		_show_live_event_banner(true)
		if live_event_title_label != null:
			live_event_title_label.text = "🚨 " + str(data.get("title", "LIVE CRISIS EVENT")).to_upper()
		var cur: float = float(data.get("progress", 0.0))
		var tgt: float = float(data.get("target", 100.0))
		var pct: float = float(data.get("percentage", 0.0))
		_update_live_event_progress(cur, tgt, pct)
		_update_live_event_timer(float(data.get("time_remaining", 0.0)))
	else:
		_show_live_event_banner(false)

func _show_live_event_banner(should_show: bool) -> void:
	if live_event_banner == null:
		return
	if should_show:
		if not live_event_banner.visible:
			live_event_banner.visible = true
			live_event_banner.modulate.a = 0.0
			var tween = live_event_banner.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tween.tween_property(live_event_banner, "modulate:a", 1.0, 0.3)
	else:
		if live_event_banner.visible:
			var tween = live_event_banner.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tween.tween_property(live_event_banner, "modulate:a", 0.0, 0.25)
			tween.tween_callback(func(): live_event_banner.visible = false)

func _on_live_event_started(_event_id: String, event_name: String, duration: float, target_goal: float) -> void:
	if live_event_title_label != null:
		live_event_title_label.text = "🚨 " + event_name.to_upper()
		live_event_title_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.25))
	_update_live_event_progress(0.0, target_goal, 0.0)
	_update_live_event_timer(duration)
	_show_live_event_banner(true)

func _on_live_event_progress_updated(current: float, target: float, percentage: float) -> void:
	_update_live_event_progress(current, target, percentage)

func _update_live_event_progress(current: float, target: float, percentage: float) -> void:
	if live_event_progress_bar != null:
		live_event_progress_bar.max_value = target if target > 0.0 else 100.0
		var tween = live_event_progress_bar.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(live_event_progress_bar, "value", current, 0.2)
	if live_event_progress_label != null:
		live_event_progress_label.text = "[%s / %s (%.0f%%)]" % [
			GameState.format_number(current) if GameState != null else str(int(current)),
			GameState.format_number(target) if GameState != null else str(int(target)),
			percentage
		]

func _on_live_event_milestone_reached(_milestone_pct: float, _milestone_name: String) -> void:
	if live_event_banner != null:
		var tween = live_event_banner.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		live_event_banner.scale = Vector2(1.03, 1.03)
		tween.tween_property(live_event_banner, "scale", Vector2.ONE, 0.15)
	var hm = get_node_or_null("/root/HapticsManager")
	if hm != null and hm.has_method("vibrate_gate_unlock"):
		hm.vibrate_gate_unlock()

func _on_live_event_completed(_event_id: String, _reward_data: Dictionary) -> void:
	if live_event_title_label != null:
		live_event_title_label.text = "🏆 EVENT COMPLETED! [BUFF ACTIVE]"
		live_event_title_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	if live_event_progress_label != null:
		live_event_progress_label.text = "VICTORY! 100%"
	_trigger_level_up_confetti()
	var hm = get_node_or_null("/root/HapticsManager")
	if hm != null and hm.has_method("vibrate_gate_unlock"):
		hm.vibrate_gate_unlock()

func _on_live_event_ended(_event_id: String) -> void:
	_show_live_event_banner(false)

func _update_live_event_timer(seconds: float) -> void:
	if live_event_timer_label == null:
		return
	var s: int = maxi(0, int(ceilf(seconds)))
	var mins: int = s / 60
	var secs: int = s % 60
	live_event_timer_label.text = "⏳ %02d:%02d" % [mins, secs]



