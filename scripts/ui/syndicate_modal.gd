extends Control

## SyndicateModal Controller (Phase 13 Milestone M3)
## Manages Incubator Syndicate HQ modal with 3 mobile-optimized tabs:
## 1. Overview & 5-tier Perk Tree with visual cards and status colors
## 2. Member Roster & Vault Donations with slider, steppers, and invest buttons
## 3. Syndicate Wars & Seasons with live countdown timer and Top 10 leaderboard

signal closed

# Header & Navigation
@onready var close_button: Button = %CloseButton
@onready var overview_tab_btn: Button = %OverviewTabButton
@onready var roster_tab_btn: Button = %RosterTabButton
@onready var wars_tab_btn: Button = %WarsTabButton

# Tab containers
@onready var overview_tab: Control = %OverviewTab
@onready var roster_tab: Control = %RosterTab
@onready var wars_tab: Control = %WarsTab

# Tab 1: Overview & Perk Tree
@onready var syndicate_identity_label: Label = %SyndicateIdentityLabel
@onready var syndicate_tier_badge_label: Label = %SyndicateTierBadgeLabel
@onready var tier_progress_bar: ProgressBar = %TierProgressBar
@onready var tier_progress_label: Label = %TierProgressLabel
@onready var perk_card_tier1: PanelContainer = %PerkCardTier1
@onready var perk_card_tier2: PanelContainer = %PerkCardTier2
@onready var perk_card_tier3: PanelContainer = %PerkCardTier3
@onready var perk_card_tier4: PanelContainer = %PerkCardTier4
@onready var perk_card_tier5: PanelContainer = %PerkCardTier5

# Tab 2: Roster & Donations
@onready var member_list_vbox: VBoxContainer = %MemberListVBox
@onready var player_wallet_label: Label = %PlayerWalletLabel
@onready var donation_amount_label: Label = %DonationAmountLabel
@onready var donation_slider: HSlider = %DonationSlider
@onready var preset_10_button: Button = %Preset10Button
@onready var preset_50_button: Button = %Preset50Button
@onready var preset_max_button: Button = %PresetMaxButton
@onready var donate_energy_button: Button = %DonateEnergyButton
@onready var donate_shares_button: Button = %DonateSharesButton
@onready var donation_status_label: Label = %DonationStatusLabel

# Tab 3: Wars & Seasons
@onready var season_timer_label: Label = %SeasonTimerLabel
@onready var rank_badge_label: Label = %RankBadgeLabel
@onready var leaderboard_vbox: VBoxContainer = %LeaderboardVBox

# Color Constants per Specification
const COLOR_UNLOCKED: Color = Color(0.0, 0.9, 0.46, 1.0)       # Emerald #00E676
const COLOR_NEXT_OBJ: Color = Color(0.0, 0.9, 1.0, 1.0)        # Cyan #00E5FF
const COLOR_LOCKED: Color = Color(0.22, 0.28, 0.31, 1.0)       # Dim Gray #37474F

var current_tab_index: int = 0
var _selected_donation_energy: float = 0.0

func _ready() -> void:
	# Ensure mouse input doesn't leak to 3D world
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	_bind_buttons()
	_connect_game_state_signals()
	
	# If player hasn't founded or joined a syndicate yet, provide seamless founding
	if GameState != null and not GameState.is_in_syndicate():
		GameState.found_syndicate("syn_incubator", "Incubator Syndicate", "ARK", "Official Campus Holding Syndicate")
	
	switch_tab(0)
	refresh_all_tabs()

func _bind_buttons() -> void:
	if close_button != null:
		close_button.pressed.connect(close)
	if overview_tab_btn != null:
		overview_tab_btn.pressed.connect(func(): switch_tab(0))
	if roster_tab_btn != null:
		roster_tab_btn.pressed.connect(func(): switch_tab(1))
	if wars_tab_btn != null:
		wars_tab_btn.pressed.connect(func(): switch_tab(2))
	if preset_10_button != null:
		preset_10_button.pressed.connect(func(): set_donation_preset(0.10))
	if preset_50_button != null:
		preset_50_button.pressed.connect(func(): set_donation_preset(0.50))
	if preset_max_button != null:
		preset_max_button.pressed.connect(func(): set_donation_preset(1.00))
	if donation_slider != null:
		donation_slider.value_changed.connect(_on_donation_slider_changed)
	if donate_energy_button != null:
		donate_energy_button.pressed.connect(contribute_energy)
	if donate_shares_button != null:
		donate_shares_button.pressed.connect(contribute_shares)

func _connect_game_state_signals() -> void:
	if GameState == null:
		return
	if GameState.has_signal("syndicate_joined") and not GameState.syndicate_joined.is_connected(_on_syndicate_changed):
		GameState.syndicate_joined.connect(_on_syndicate_changed)
	if GameState.has_signal("syndicate_left") and not GameState.syndicate_left.is_connected(_on_syndicate_left):
		GameState.syndicate_left.connect(_on_syndicate_left)
	if GameState.has_signal("syndicate_contributed") and not GameState.syndicate_contributed.is_connected(_on_syndicate_contributed):
		GameState.syndicate_contributed.connect(_on_syndicate_contributed)
	if GameState.has_signal("syndicate_tier_upgraded") and not GameState.syndicate_tier_upgraded.is_connected(_on_syndicate_tier_upgraded):
		GameState.syndicate_tier_upgraded.connect(_on_syndicate_tier_upgraded)
	if GameState.has_signal("syndicate_season_updated") and not GameState.syndicate_season_updated.is_connected(_on_syndicate_season_updated):
		GameState.syndicate_season_updated.connect(_on_syndicate_season_updated)
	if GameState.has_signal("energy_changed") and not GameState.energy_changed.is_connected(_on_energy_changed):
		GameState.energy_changed.connect(_on_energy_changed)
	if GameState.has_signal("angel_shares_changed") and not GameState.angel_shares_changed.is_connected(_on_angel_shares_changed):
		GameState.angel_shares_changed.connect(_on_angel_shares_changed)

func open() -> void:
	visible = true
	refresh_all_tabs()

func close() -> void:
	_play_ui_sound()
	closed.emit()
	queue_free()

func switch_tab(tab_index: int) -> void:
	_play_ui_sound()
	current_tab_index = tab_index
	
	if overview_tab != null:
		overview_tab.visible = (tab_index == 0)
	if roster_tab != null:
		roster_tab.visible = (tab_index == 1)
	if wars_tab != null:
		wars_tab.visible = (tab_index == 2)
		
	_update_tab_button_styles()
	
	if tab_index == 0:
		refresh_overview()
	elif tab_index == 1:
		refresh_roster()
	elif tab_index == 2:
		refresh_wars()

func _update_tab_button_styles() -> void:
	var tabs = [overview_tab_btn, roster_tab_btn, wars_tab_btn]
	for i in range(tabs.size()):
		var btn = tabs[i]
		if btn == null:
			continue
		if i == current_tab_index:
			btn.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
			btn.modulate = Color(1.0, 1.0, 1.0, 1.0)
		else:
			btn.add_theme_color_override("font_color", Color(0.65, 0.75, 0.72, 0.85))
			btn.modulate = Color(0.85, 0.85, 0.85, 0.9)

func refresh_all_tabs() -> void:
	refresh_overview()
	refresh_roster()
	refresh_wars()

# ==============================================================================
# TAB 1: Overview & Perk Tree Logic
# ==============================================================================

func refresh_overview() -> void:
	if GameState == null:
		return
		
	var syn_data: Dictionary = GameState.get_active_syndicate()
	var tier: int = GameState.get_syndicate_tier()
	var tag: String = str(syn_data.get("tag", "SYN")).strip_edges()
	var syn_name: String = str(syn_data.get("name", "Incubator Syndicate")).strip_edges()
	var div_mult: float = GameState.get_syndicate_dividend_multiplier()
	var div_pct: int = int(round((div_mult - 1.0) * 100.0))
	
	if syndicate_identity_label != null:
		syndicate_identity_label.text = "🏛️ [%s] %s" % [tag if not tag.is_empty() else "ARK", syn_name]
		
	if syndicate_tier_badge_label != null:
		var tier_name = syn_data.get("bonuses", {}).get("name", "Seed Syndicate")
		syndicate_tier_badge_label.text = "Tier %d: %s  •  +%d%% Syndicate Dividend" % [tier, tier_name, div_pct]

	# Calculate funds toward next tier
	var configs: Dictionary = GameState.get_syndicate_tier_definitions()
	var next_tier: int = mini(5, tier + 1)
	var next_cfg: Dictionary = configs.get(next_tier, configs.get(5, {}))
	var req_energy: float = float(next_cfg.get("req_energy", 10000.0))
	var req_shares: int = int(next_cfg.get("req_shares", 1))
	var fund_energy: float = float(syn_data.get("fund_energy", 0.0))
	var fund_shares: int = int(syn_data.get("fund_angel_shares", 0))
	
	var progress_pct: float = 100.0
	if tier < 5 and req_energy > 0.0:
		var energy_ratio = fund_energy / req_energy
		var shares_ratio = float(fund_shares) / float(maxi(1, req_shares))
		progress_pct = clampf(maxf(energy_ratio, shares_ratio) * 100.0, 0.0, 100.0)
		
	if tier_progress_bar != null:
		tier_progress_bar.value = progress_pct
		
	if tier_progress_label != null:
		if tier >= 5:
			tier_progress_label.text = "Syndicate Vault MAXED (Tier 5 Monopoly Achieved!)"
		else:
			var formatted_fund: String = GameState.format_number(fund_energy)
			var formatted_req: String = GameState.format_number(req_energy)
			tier_progress_label.text = "Vault Progress: %s / %s Energy (or %d / %d Shares) -> Tier %d" % [
				formatted_fund, formatted_req, fund_shares, req_shares, next_tier
			]
			
	# Update 5 Perk Cards
	var cards = [perk_card_tier1, perk_card_tier2, perk_card_tier3, perk_card_tier4, perk_card_tier5]
	for i in range(5):
		var card_tier = i + 1
		var card_panel = cards[i]
		if card_panel == null:
			continue
		_apply_perk_card_visuals(card_panel, card_tier, tier)

func _apply_perk_card_visuals(card: PanelContainer, card_tier: int, current_tier: int) -> void:
	var status_color: Color = COLOR_LOCKED
	var status_text: String = "LOCKED"
	
	if card_tier <= current_tier:
		status_color = COLOR_UNLOCKED
		status_text = "UNLOCKED"
	elif card_tier == current_tier + 1:
		status_color = COLOR_NEXT_OBJ
		status_text = "NEXT OBJECTIVE"
		
	# Apply border color styling
	var style: StyleBox = card.get_theme_stylebox("panel")
	if style is StyleBoxFlat:
		var flat = style.duplicate() as StyleBoxFlat
		flat.border_color = status_color
		card.add_theme_stylebox_override("panel", flat)
		
	var badge = card.find_child("StatusBadgeLabel", true, false)
	if badge is Label:
		badge.text = status_text
		badge.add_theme_color_override("font_color", status_color)

# ==============================================================================
# TAB 2: Member Roster & Vault Donations
# ==============================================================================

func refresh_roster() -> void:
	if GameState == null:
		return
		
	var syn_data: Dictionary = GameState.get_active_syndicate()
	var player_energy: float = GameState.energy
	var player_shares: int = GameState.angel_shares
	
	if player_wallet_label != null:
		var fmt_e = GameState.format_number(player_energy)
		player_wallet_label.text = "Your Reserves: 👥 %s Energy  •  💎 %d Angel Shares" % [fmt_e, player_shares]
		
	# Update donation slider bounds
	if donation_slider != null:
		donation_slider.min_value = 0.0
		donation_slider.max_value = maxf(100.0, player_energy)
		donation_slider.step = maxf(1.0, floor(player_energy / 100.0)) if player_energy > 100.0 else 1.0
		if _selected_donation_energy > player_energy:
			_selected_donation_energy = player_energy
		donation_slider.value = _selected_donation_energy
		
	_update_donation_labels()
	_populate_roster_members(syn_data)

func _populate_roster_members(syn_data: Dictionary) -> void:
	if member_list_vbox == null:
		return
		
	for child in member_list_vbox.get_children():
		child.queue_free()
		
	var role: String = str(syn_data.get("role", "Founder"))
	var my_contrib_e: float = float(syn_data.get("energy_contributed", 0.0))
	var my_contrib_s: int = int(syn_data.get("angel_shares_contributed", 0))
	
	# Member 1: The Player
	_add_member_row("👤 You (Active Player)", role, my_contrib_e, my_contrib_s, Color(0.1, 0.95, 0.65))
	
	# Syndicate AI Campus Partners for rich world building
	_add_member_row("👨‍💼 CEO Alex", "Executive Partner", 125000.0, 12, Color(1.0, 0.85, 0.3))
	_add_member_row("📐 Architekt Bob", "Senior Partner", 85000.0, 6, Color(0.3, 0.8, 1.0))
	_add_member_row("🔬 Dr. Lisa", "R&D Partner", 95000.0, 8, Color(0.9, 0.4, 0.9))
	_add_member_row("🤖 Autonomous Drones", "Associate Holding", 45000.0, 3, Color(0.7, 0.75, 0.8))

func _add_member_row(name_str: String, role_str: String, energy_amt: float, shares_amt: int, color_accent: Color) -> void:
	var row = PanelContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.custom_minimum_size = Vector2(0, 56)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.08, 0.12, 0.85)
	style.border_width_left = 2
	style.border_color = color_accent
	style.set_corner_radius_all(6)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	row.add_theme_stylebox_override("panel", style)
	
	var hbox = HBoxContainer.new()
	hbox.mouse_filter = Control.MOUSE_FILTER_STOP
	row.add_child(hbox)
	
	var name_lbl = Label.new()
	name_lbl.text = name_str
	name_lbl.add_theme_font_size_override("font_size", 14)
	name_lbl.add_theme_color_override("font_color", color_accent)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(name_lbl)
	
	var role_lbl = Label.new()
	role_lbl.text = role_str
	role_lbl.add_theme_font_size_override("font_size", 12)
	role_lbl.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
	role_lbl.custom_minimum_size = Vector2(140, 0)
	hbox.add_child(role_lbl)
	
	var stats_lbl = Label.new()
	var fmt_e = GameState.format_number(energy_amt) if GameState != null else str(int(energy_amt))
	stats_lbl.text = "⚡ %s  |  💎 %d" % [fmt_e, shares_amt]
	stats_lbl.add_theme_font_size_override("font_size", 13)
	stats_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	hbox.add_child(stats_lbl)
	
	member_list_vbox.add_child(row)

func _on_donation_slider_changed(val: float) -> void:
	_selected_donation_energy = val
	_update_donation_labels()

func set_donation_preset(pct: float) -> void:
	_play_ui_sound()
	if GameState == null:
		return
	var target = floor(GameState.energy * clampf(pct, 0.0, 1.0))
	_selected_donation_energy = target
	if donation_slider != null:
		donation_slider.value = target
	_update_donation_labels()

func _update_donation_labels() -> void:
	if donation_amount_label != null:
		var fmt = GameState.format_number(_selected_donation_energy) if GameState != null else str(int(_selected_donation_energy))
		donation_amount_label.text = "Selected Energy: 👥 %s" % fmt
	if donate_energy_button != null:
		var can_afford = GameState != null and GameState.energy >= _selected_donation_energy and _selected_donation_energy > 0.0
		donate_energy_button.disabled = not can_afford

func contribute_energy() -> void:
	if GameState == null or _selected_donation_energy <= 0.0:
		return
		
	_play_ui_sound()
	_trigger_haptic()
	var res = GameState.contribute_to_syndicate(_selected_donation_energy, "energy")
	if res.get("success", false):
		if donation_status_label != null:
			donation_status_label.text = "✅ Invested %s Energy in Syndicate Vault!" % GameState.format_number(_selected_donation_energy)
			donation_status_label.add_theme_color_override("font_color", COLOR_UNLOCKED)
		_selected_donation_energy = 0.0
		if donation_slider != null:
			donation_slider.value = 0.0
	else:
		if donation_status_label != null:
			donation_status_label.text = "❌ " + str(res.get("error", "Failed contribution"))
			donation_status_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
			
	refresh_all_tabs()

func contribute_shares() -> void:
	if GameState == null:
		return
		
	_play_ui_sound()
	_trigger_haptic()
	var res = GameState.contribute_angel_shares_to_syndicate(1)
	if res.get("success", false):
		if donation_status_label != null:
			donation_status_label.text = "✅ Invested 1 Angel Share in Syndicate Vault!"
			donation_status_label.add_theme_color_override("font_color", COLOR_UNLOCKED)
	else:
		if donation_status_label != null:
			donation_status_label.text = "❌ " + str(res.get("error", "Failed share contribution"))
			donation_status_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
			
	refresh_all_tabs()

# ==============================================================================
# TAB 3: Syndicate Wars & Seasons
# ==============================================================================

func refresh_wars() -> void:
	if GameState == null:
		return
		
	var score: int = GameState.get_seasonal_leaderboard_score()
	var syn_data: Dictionary = GameState.get_active_syndicate()
	var tag: String = str(syn_data.get("tag", "ARK"))
	
	if rank_badge_label != null:
		rank_badge_label.text = "🏆 Active Standing: Rank #4  •  [%s] %d War Points  •  Prize Tier: Gold Founder Crest" % [tag, score]
		
	_update_season_timer()
	_populate_leaderboard()

func _process(_delta: float) -> void:
	if current_tab_index == 2:
		_update_season_timer()

func _update_season_timer() -> void:
	if season_timer_label == null:
		return
	var now = int(Time.get_unix_time_from_system())
	var week_seconds = 86400 * 7
	var remaining = week_seconds - (now % week_seconds)
	
	var days = remaining / 86400
	var hours = (remaining % 86400) / 3600
	var mins = (remaining % 3600) / 60
	var secs = remaining % 60
	
	season_timer_label.text = "⏳ Season 1 Ends In: %dd %02dh %02dm %02ds" % [days, hours, mins, secs]

func _populate_leaderboard() -> void:
	if leaderboard_vbox == null:
		return
		
	for child in leaderboard_vbox.get_children():
		child.queue_free()
		
	var leaders = [
		{"rank": 1, "tag": "TITAN", "name": "Titan Ventures Holding", "points": 450000, "prize": "Platinum Bull Crest & +500 Angel Shares"},
		{"rank": 2, "tag": "CYBER", "name": "Cyberdyne Apex Monopoly", "points": 320000, "prize": "Gold Trophy & +250 Angel Shares"},
		{"rank": 3, "tag": "QUANT", "name": "Quantum Matrix Guild", "points": 210000, "prize": "Silver Trophy & +100 Angel Shares"},
		{"rank": 4, "tag": "ARK", "name": "Incubator Syndicate (Your Clan)", "points": 140000, "prize": "Bronze Founder Crest & +50 Angel Shares"},
		{"rank": 5, "tag": "SOLAR", "name": "Solaris Energy Capital", "points": 95000, "prize": "+25 Angel Shares"},
		{"rank": 6, "tag": "HYPER", "name": "Hyperion Speed Holdings", "points": 72000, "prize": "+15 Angel Shares"},
		{"rank": 7, "tag": "NEXUS", "name": "Nexus Global Syndicate", "points": 58000, "prize": "+10 Angel Shares"},
		{"rank": 8, "tag": "ORION", "name": "Orion Cyber Syndicate", "points": 41000, "prize": "+5 Angel Shares"},
		{"rank": 9, "tag": "ALPHA", "name": "Alpha Venture Seed", "points": 29000, "prize": "+3 Angel Shares"},
		{"rank": 10, "tag": "DELTA", "name": "Delta Automation Corp", "points": 18000, "prize": "+1 Angel Share"}
	]
	
	for entry in leaders:
		var row = PanelContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_STOP
		row.custom_minimum_size = Vector2(0, 56)
		
		var is_player_syn = (entry["rank"] == 4)
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.08, 0.16, 0.12, 0.95) if is_player_syn else Color(0.04, 0.06, 0.1, 0.85)
		style.border_width_left = 3
		style.border_color = COLOR_UNLOCKED if is_player_syn else Color(0.25, 0.4, 0.5, 0.7)
		style.set_corner_radius_all(6)
		style.content_margin_left = 12.0
		style.content_margin_right = 12.0
		row.add_theme_stylebox_override("panel", style)
		
		var hbox = HBoxContainer.new()
		hbox.mouse_filter = Control.MOUSE_FILTER_STOP
		row.add_child(hbox)
		
		var rank_lbl = Label.new()
		rank_lbl.text = "#%d" % entry["rank"]
		rank_lbl.add_theme_font_size_override("font_size", 16)
		rank_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3) if entry["rank"] <= 3 else Color(0.7, 0.8, 0.9))
		rank_lbl.custom_minimum_size = Vector2(40, 0)
		hbox.add_child(rank_lbl)
		
		var name_lbl = Label.new()
		name_lbl.text = "[%s] %s" % [entry["tag"], entry["name"]]
		name_lbl.add_theme_font_size_override("font_size", 14)
		name_lbl.add_theme_color_override("font_color", COLOR_UNLOCKED if is_player_syn else Color(1.0, 1.0, 1.0))
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(name_lbl)
		
		var pts_lbl = Label.new()
		pts_lbl.text = "%s pts  •  %s" % [GameState.format_number(float(entry["points"])) if GameState != null else str(entry["points"]), entry["prize"]]
		pts_lbl.add_theme_font_size_override("font_size", 12)
		pts_lbl.add_theme_color_override("font_color", Color(0.8, 0.88, 1.0))
		hbox.add_child(pts_lbl)
		
		leaderboard_vbox.add_child(row)

# ==============================================================================
# Reactive Signal Callbacks
# ==============================================================================

func _on_syndicate_changed(_data: Dictionary) -> void:
	refresh_all_tabs()

func _on_syndicate_left() -> void:
	refresh_all_tabs()

func _on_syndicate_contributed(_resource: String, _amount: float, _fund: float, _tier: int) -> void:
	refresh_all_tabs()

func _on_syndicate_tier_upgraded(_tier: int, _bonuses: Dictionary) -> void:
	refresh_all_tabs()

func _on_syndicate_season_updated(_week: int, _score: int) -> void:
	if current_tab_index == 2:
		refresh_wars()

func _on_energy_changed(_new_energy: float, _delta: float) -> void:
	if current_tab_index == 1:
		refresh_roster()

func _on_angel_shares_changed(_shares: int, _delta: int) -> void:
	if current_tab_index == 1:
		refresh_roster()

func _play_ui_sound() -> void:
	var am = get_node_or_null("/root/AudioManager")
	if am != null and am.has_method("play_sfx_click"):
		am.play_sfx_click()

func _trigger_haptic() -> void:
	var hm = get_node_or_null("/root/HapticsManager")
	if hm != null and hm.has_method("vibrate_button"):
		hm.vibrate_button()
	elif OS.has_feature("mobile") and Input.has_method("vibrate_handheld"):
		Input.vibrate_handheld(20)
