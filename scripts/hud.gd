extends Control

## UI HUD Controller for IdleArcade.
## Binds GameState typed signals to energy counters, RPS indicators,
## combo frenzy progress bar, and dynamic upgrade shop cards.

@onready var energy_label: Label = %EnergyLabel
@onready var rps_label: Label = %RPSLabel
@onready var frenzy_multiplier_label: Label = %FrenzyMultiplierLabel
@onready var frenzy_progress_bar: ProgressBar = %FrenzyProgressBar
@onready var upgrade_list: VBoxContainer = %UpgradeList

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
	}
]

var _upgrade_cards: Dictionary = {}

func _ready() -> void:
	_build_upgrade_cards()
	_connect_game_state_signals()
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

func _refresh_all_ui() -> void:
	if GameState == null:
		return
		
	_on_energy_changed(GameState.energy, 0.0)
	_on_rps_changed(GameState.base_passive_rps)
	_on_frenzy_updated(GameState.frenzy_multiplier, GameState.frenzy_meter)
	_refresh_all_upgrade_buttons()

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
	
	var tween = card["panel"].create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	card["panel"].scale = Vector2(1.03, 1.03)
	tween.tween_property(card["panel"], "scale", Vector2.ONE, 0.12)
	
	_refresh_affordability(GameState.energy if GameState != null else 0.0)

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
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.12, 0.18, 0.9)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_right = 10
	style.corner_radius_bottom_left = 10
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	panel.add_theme_stylebox_override("panel", style)
	
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	panel.add_child(hbox)
	
	# Left: Details VBox
	var vbox = VBoxContainer.new()
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
	buy_btn.custom_minimum_size = Vector2(130, 42)
	var initial_cost: float = def["base_cost"]
	if GameState != null and GameState.upgrades.has(def["id"]):
		initial_cost = float(GameState.upgrades[def["id"]].get("current_cost", def["base_cost"]))
	buy_btn.text = "Buy: " + (GameState.format_number(initial_cost) if GameState != null else str(int(initial_cost)))
	buy_btn.pressed.connect(_on_buy_button_pressed.bind(def["id"]))
	hbox.add_child(buy_btn)
	
	return {
		"id": def["id"],
		"panel": panel,
		"title_label": title_lbl,
		"desc_label": desc_lbl,
		"buy_button": buy_btn,
		"def": def
	}

func _on_buy_button_pressed(upgrade_id: String) -> void:
	if GameState != null and GameState.has_method("buy_upgrade"):
		GameState.buy_upgrade(upgrade_id)

func _refresh_affordability(total_energy: float) -> void:
	for id in _upgrade_cards:
		var card = _upgrade_cards[id]
		var btn: Button = card["buy_button"]
		var cost: float = card["def"]["base_cost"]
		if GameState != null and GameState.upgrades.has(id):
			cost = float(GameState.upgrades[id].get("current_cost", cost))
		
		btn.disabled = (total_energy < cost)

func _refresh_all_upgrade_buttons() -> void:
	var total_energy: float = GameState.energy if GameState != null else 0.0
	_refresh_affordability(total_energy)
