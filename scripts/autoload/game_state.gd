extends Node

## Central GameState singleton for IdleArcade.
## Manages resource economy, passive generation, active click mechanics,
## combo frenzy multipliers, upgrade progression, and JSON persistence.

# --- Signals (Interface Contract) ---
signal energy_changed(total_energy: float, delta_amount: float)
signal rps_changed(rate_per_sec: float)
signal frenzy_updated(multiplier: float, fill_percentage: float)
signal upgrade_purchased(upgrade_id: String, new_level: int, current_cost: float)

# Milestone P2-M3 Signals
signal bonus_users_changed(total_bonus_users: int, added_amount: int)
signal core_tapped(total_clicks: int)
signal spark_collected(total_sparks: int)

# Milestone P4-M2 & Phase 4 Signals
signal avatar_stat_updated(stat_name: String, new_value: float)
signal collectible_picked_up(item_type: String, total_collected: int)
signal zone_unlocked(zone_id: String)
signal campus_quest_updated(quest_id: String, status: String, current_count: int, target_count: int)
signal campus_quest_completed(quest_id: String, reward_energy: float, reward_bonus_users: int)

# Phase 8 (Tech-Tree & Research Lab) Signals
signal tech_researched(tech_id: String)

# Phase 9 Audio Engine Signals
signal audio_settings_changed(setting_name: String, value: Variant)

# Phase 9 Campus Station Signals
signal server_overclock_buff_started(multiplier: float, duration: float)
signal server_overclock_buff_ended()

# Phase 10 VFX & Milestone Signals
signal level_up(new_level: int)
signal screen_shake_changed(new_intensity: float)
signal light_cycle_mode_changed(new_mode: String)

# Phase 11 Narrative Story-Kampagne Signals
signal campaign_chapter_changed(chapter: int)
signal campaign_quest_completed(quest_id: String, chapter: int)
signal campaign_choice_selected(chapter: int, choice_id: String, reward_type: String)
signal campaign_buff_started(buff_type: String, multiplier: float, duration: float)
signal campaign_buff_ended(buff_type: String)

# Phase 11 Super-Espresso Brew Lab Signals
signal unicorn_espresso_buff_started(duration: float, avatar_boost: float, worker_boost: float)
signal unicorn_espresso_buff_ended()

# --- State Variables ---
var energy: float = 0.0
var total_energy_earned: float = 0.0
var total_clicks: int = 0
var sparks_collected: int = 0
var bonus_users: int = 0

# Phase 9 Audio Engine Settings
var master_volume: float = 1.0     # Range: 0.0 to 1.0
var music_volume: float = 0.8      # Range: 0.0 to 1.0
var sfx_volume: float = 1.0        # Range: 0.0 to 1.0
var master_muted: bool = false
var music_muted: bool = false
var sfx_muted: bool = false
var screen_shake_intensity: float = 1.0  # Range: 0.0 to 1.0 (Phase 10 Screen-Shake Accessibility)
var light_cycle_mode: String = "auto"    # "auto", "day", "night" (Phase 10 Day/Night Light Cycle)

# Phase 4 (3D Open World & Meta-Progression) State Variables
var avatar_speed_level: int = 0
var idle_level: int = 1
var pickup_radius_level: int = 0
var collectibles_collected: int = 0
var unlocked_zones: Array[String] = []
var campus_quests: Dictionary = {}
var active_campus_quest_id: String = ""

# Phase 8 (Tech-Tree & Research Lab) State Variables
var researched_techs: Array[String] = []
var item_inventory: Dictionary = {
	"briefcase": 0,
	"coffee": 0,
	"usb_drive": 0
}

# Phase 9 Server Room Overclock Buff State Variables
var server_overclock_buff_timer: float = 0.0
var server_overclock_buff_multiplier: float = 1.0
var server_overclock_buff_active: bool = false
var server_overclock_buff_remaining: float = 0.0

# Phase 11 Narrative Story-Kampagne ("The Unicorn Journey") State Variables
var campaign_chapter: int = 1
var campaign_completed_quests: Array[String] = []
var campaign_choices: Dictionary = {}
var campaign_rps_buff_timer: float = 0.0
var campaign_rps_buff_multiplier: float = 1.0
var campaign_speed_buff_timer: float = 0.0
var campaign_speed_buff_multiplier: float = 1.0

# Phase 11 Super-Espresso Brew Lab Buff State Variables
var unicorn_espresso_buff_active: bool = false
var unicorn_espresso_buff_timer: float = 0.0
var unicorn_espresso_buff_remaining: float = 0.0

var base_click_power: float = 1.0
var base_passive_rps: float = 0.0

var total_passive_rps: float:
	get:
		return get_effective_passive_rps()

var frenzy_meter: float = 0.0  # Range: 0.0 to 100.0
var is_frenzy_active: bool = false
var frenzy_multiplier: float = 1.0
var frenzy_duration_remaining: float = 0.0

var upgrades: Dictionary = {}

const SAVE_PATH: String = "user://savegame.json"

const DEFAULT_UPGRADES: Dictionary = {
	"click_booster": {
		"name": "Freelancer Marketing",
		"description": "+1 User per click",
		"level": 0,
		"base_cost": 10.0,
		"cost_mult": 1.18,
		"type": "click",
		"power_gain": 1.0,
		"current_cost": 10.0
	},
	"tier_1": {
		"name": "Virale Memes",
		"description": "+1 User / sec",
		"level": 0,
		"base_cost": 25.0,
		"cost_mult": 1.15,
		"type": "idle",
		"power_gain": 1.0,
		"current_cost": 25.0
	},
	"tier_2": {
		"name": "Empfehlungsprogramm",
		"description": "+8 Users / sec",
		"level": 0,
		"base_cost": 150.0,
		"cost_mult": 1.15,
		"type": "idle",
		"power_gain": 8.0,
		"current_cost": 150.0
	},
	"tier_3": {
		"name": "SEO-Optimierung",
		"description": "+40 Users / sec",
		"level": 0,
		"base_cost": 800.0,
		"cost_mult": 1.15,
		"type": "idle",
		"power_gain": 40.0,
		"current_cost": 800.0
	},
	"tier_4": {
		"name": "Social Media Ads",
		"description": "+250 Users / sec",
		"level": 0,
		"base_cost": 4500.0,
		"cost_mult": 1.15,
		"type": "idle",
		"power_gain": 250.0,
		"current_cost": 4500.0
	},
	"tier_5": {
		"name": "Influencer-Deals",
		"description": "+1.5K Users / sec",
		"level": 0,
		"base_cost": 30000.0,
		"cost_mult": 1.15,
		"type": "idle",
		"power_gain": 1500.0,
		"current_cost": 30000.0
	},
	"tier_6": {
		"name": "TV-Werbespots",
		"description": "+10K Users / sec",
		"level": 0,
		"base_cost": 250000.0,
		"cost_mult": 1.15,
		"type": "idle",
		"power_gain": 10000.0,
		"current_cost": 250000.0
	},
	"tier_7": {
		"name": "Super Bowl Spot",
		"description": "+75K Users / sec",
		"level": 0,
		"base_cost": 2000000.0,
		"cost_mult": 1.15,
		"type": "idle",
		"power_gain": 75000.0,
		"current_cost": 2000000.0
	},
	"overdrive_tuning": {
		"name": "Hype Tuning",
		"description": "+0.5x Viraler Hype Multiplier",
		"level": 0,
		"base_cost": 100.0,
		"cost_mult": 1.30,
		"type": "frenzy",
		"power_gain": 0.5,
		"current_cost": 100.0
	},
	"avatar_speed": {
		"name": "Agile Sneakers",
		"description": "+15% Avatar Run Speed",
		"level": 0,
		"base_cost": 50.0,
		"cost_mult": 1.25,
		"type": "avatar_stat",
		"power_gain": 0.15,
		"current_cost": 50.0
	},
	"clearance_level": {
		"name": "Executive Badge",
		"description": "Unlocks campus security zones",
		"level": 0,
		"base_cost": 250.0,
		"cost_mult": 1.75,
		"type": "meta",
		"power_gain": 1.0,
		"current_cost": 250.0
	},
	"pickup_radius": {
		"name": "Magnetic Charm",
		"description": "+25% 3D Item Pickup Radius",
		"level": 0,
		"base_cost": 75.0,
		"cost_mult": 1.25,
		"type": "avatar_stat",
		"power_gain": 0.25,
		"current_cost": 75.0
	}
}

const TECH_DEFINITIONS: Dictionary = {
	"tech_coffee_automation": {
		"id": "tech_coffee_automation",
		"name": "Coffee Automation",
		"description": "+15% Avatar Run Speed & +10% Worker Production Frequency",
		"cost": 500.0,
		"energy_cost": 500.0,
		"required_item": "",
		"required_item_count": 0,
		"item_cost": {},
		"icon": "☕"
	},
	"tech_delivery_drone": {
		"id": "tech_delivery_drone",
		"name": "Delivery Drone",
		"description": "Deploys autonomous campus delivery drone to gather collectibles",
		"cost": 1500.0,
		"energy_cost": 1500.0,
		"required_item": "usb_drive",
		"required_item_count": 3,
		"item_cost": {"usb_drive": 3},
		"icon": "🛸"
	},
	"tech_server_overclock": {
		"id": "tech_server_overclock",
		"name": "Server Overclocking",
		"description": "+25% Global Passive RPS & Server Room Overclock Glow",
		"cost": 4000.0,
		"energy_cost": 4000.0,
		"required_item": "",
		"required_item_count": 0,
		"item_cost": {},
		"icon": "⚡"
	},
	"tech_quantum_ads": {
		"id": "tech_quantum_ads",
		"name": "Quantum Ads",
		"description": "2x Base Click Power in 2D & +50% Angel Investor Spawn Chance",
		"cost": 10000.0,
		"energy_cost": 10000.0,
		"required_item": "",
		"required_item_count": 0,
		"item_cost": {},
		"icon": "🎯"
	},
	"tech_neural_cloud": {
		"id": "tech_neural_cloud",
		"name": "Neural Cloud",
		"description": "Doubles Campus Item Multiplier from +5% to +10% per item",
		"cost": 25000.0,
		"energy_cost": 25000.0,
		"required_item": "",
		"required_item_count": 0,
		"item_cost": {},
		"icon": "🧠"
	}
}

func _init() -> void:
	reset_state()

func _ready() -> void:
	print("[GameState] Autoload singleton initialized.")

## Resets game state to default baseline values
func reset_state() -> void:
	energy = 0.0
	total_energy_earned = 0.0
	total_clicks = 0
	sparks_collected = 0
	bonus_users = 0
	base_click_power = 1.0
	base_passive_rps = 0.0
	frenzy_meter = 0.0
	is_frenzy_active = false
	frenzy_multiplier = 1.0
	frenzy_duration_remaining = 0.0
	
	avatar_speed_level = 0
	idle_level = 1
	pickup_radius_level = 0
	collectibles_collected = 0
	unlocked_zones.clear()
	campus_quests.clear()
	active_campus_quest_id = ""
	
	researched_techs.clear()
	item_inventory = {
		"briefcase": 0,
		"coffee": 0,
		"usb_drive": 0
	}
	
	upgrades.clear()
	for up_id in DEFAULT_UPGRADES:
		upgrades[up_id] = DEFAULT_UPGRADES[up_id].duplicate(true)
		
	# Phase 9 Audio Defaults
	master_volume = 1.0
	music_volume = 0.8
	sfx_volume = 1.0
	master_muted = false
	music_muted = false
	sfx_muted = false
	screen_shake_intensity = 1.0

	# Phase 9 Server Overclock Buff Defaults
	server_overclock_buff_timer = 0.0
	server_overclock_buff_multiplier = 1.0
	server_overclock_buff_active = false
	server_overclock_buff_remaining = 0.0

	# Phase 11 Narrative Story-Kampagne Defaults
	campaign_chapter = 1
	campaign_completed_quests.clear()
	campaign_choices.clear()
	campaign_rps_buff_timer = 0.0
	campaign_rps_buff_multiplier = 1.0
	campaign_speed_buff_timer = 0.0
	campaign_speed_buff_multiplier = 1.0

	# Phase 11 Super-Espresso Brew Lab Buff Defaults
	unicorn_espresso_buff_active = false
	unicorn_espresso_buff_timer = 0.0
	unicorn_espresso_buff_remaining = 0.0

func _process(delta: float) -> void:
	var safe_delta: float = maxf(0.0, delta)
	var clamped_delta: float = minf(0.1, safe_delta)
	
	# Passive accumulation using clamped frame delta and bonus users multiplier
	var effective_rps: float = get_effective_passive_rps()
	if effective_rps > 0.0:
		var passive_gain: float = effective_rps * frenzy_multiplier * clamped_delta
		energy += passive_gain
		total_energy_earned += passive_gain
		energy_changed.emit(energy, passive_gain)
		
	# Frenzy duration decay
	if is_frenzy_active:
		frenzy_duration_remaining -= safe_delta
		if frenzy_duration_remaining <= 0.0:
			frenzy_duration_remaining = 0.0
			is_frenzy_active = false
			frenzy_multiplier = 1.0
			frenzy_updated.emit(frenzy_multiplier, 0.0)
		else:
			var fill_pct: float = (frenzy_duration_remaining / 6.0) * 100.0
			frenzy_updated.emit(frenzy_multiplier, fill_pct)

	# Server overclock buff duration decay
	if server_overclock_buff_timer > 0.0 or server_overclock_buff_active:
		server_overclock_buff_timer -= safe_delta
		server_overclock_buff_remaining = maxf(0.0, server_overclock_buff_timer)
		if server_overclock_buff_timer <= 0.0:
			server_overclock_buff_timer = 0.0
			server_overclock_buff_remaining = 0.0
			server_overclock_buff_active = false
			server_overclock_buff_multiplier = 1.0
			rps_changed.emit(get_effective_passive_rps())
			server_overclock_buff_ended.emit()

	# Phase 11 Campaign RPS buff duration decay
	if campaign_rps_buff_timer > 0.0:
		campaign_rps_buff_timer -= safe_delta
		if campaign_rps_buff_timer <= 0.0:
			campaign_rps_buff_timer = 0.0
			campaign_rps_buff_multiplier = 1.0
			rps_changed.emit(get_effective_passive_rps())
			campaign_buff_ended.emit("rps")

	# Phase 11 Campaign avatar speed buff duration decay
	if campaign_speed_buff_timer > 0.0:
		campaign_speed_buff_timer -= safe_delta
		if campaign_speed_buff_timer <= 0.0:
			campaign_speed_buff_timer = 0.0
			campaign_speed_buff_multiplier = 1.0
			campaign_buff_ended.emit("speed")

	# Phase 11 Super-Espresso Brew Lab buff duration decay
	if unicorn_espresso_buff_timer > 0.0 or unicorn_espresso_buff_active:
		unicorn_espresso_buff_timer -= safe_delta
		unicorn_espresso_buff_remaining = maxf(0.0, unicorn_espresso_buff_timer)
		if unicorn_espresso_buff_timer <= 0.0:
			unicorn_espresso_buff_timer = 0.0
			unicorn_espresso_buff_remaining = 0.0
			unicorn_espresso_buff_active = false
			unicorn_espresso_buff_ended.emit()

# --- Interface Contract Methods ---

## Registers an active core tap, updates frenzy, and rewards energy.
func tap_core() -> float:
	var earned: float = base_click_power * frenzy_multiplier
	energy += earned
	total_energy_earned += earned
	total_clicks += 1
	core_tapped.emit(total_clicks)
	
	if not is_frenzy_active:
		frenzy_meter = minf(100.0, frenzy_meter + 4.0)
		if frenzy_meter >= 100.0:
			is_frenzy_active = true
			var tuning_level: int = int(upgrades.get("overdrive_tuning", {}).get("level", 0))
			frenzy_multiplier = 3.0 + (0.5 * tuning_level)
			frenzy_duration_remaining = 6.0
			frenzy_meter = 0.0
			frenzy_updated.emit(frenzy_multiplier, 100.0)
			var am = get_node_or_null("/root/AudioManager")
			if am != null and am.has_method("play_sfx_overdrive"):
				am.play_sfx_overdrive()
		else:
			frenzy_updated.emit(frenzy_multiplier, frenzy_meter)
	else:
		var fill_pct: float = (frenzy_duration_remaining / 6.0) * 100.0
		frenzy_updated.emit(frenzy_multiplier, fill_pct)
		
	energy_changed.emit(energy, earned)
	return earned

## Registers a bonus spark capture and rewards lump-sum energy.
func collect_spark() -> float:
	var earned: float = maxf(50.0, base_passive_rps * 25.0)
	energy += earned
	total_energy_earned += earned
	sparks_collected += 1
	spark_collected.emit(sparks_collected)
	energy_changed.emit(energy, earned)
	return earned

## Attempts to purchase the specified upgrade. Returns true if successful.
func buy_upgrade(upgrade_id: String) -> bool:
	if not upgrades.has(upgrade_id):
		return false
		
	var up: Dictionary = upgrades[upgrade_id]
	var cost: float = roundf(float(up["base_cost"]) * pow(float(up["cost_mult"]), float(up["level"])))
	if energy < cost:
		return false
		
	energy -= cost
	up["level"] = int(up["level"]) + 1
	var next_cost: float = roundf(float(up["base_cost"]) * pow(float(up["cost_mult"]), float(up["level"])))
	up["current_cost"] = next_cost
	
	recalculate_stats()
	
	upgrade_purchased.emit(upgrade_id, int(up["level"]), next_cost)
	energy_changed.emit(energy, -cost)
	if up.get("type") == "idle":
		rps_changed.emit(get_effective_passive_rps())
	if upgrade_id == "overdrive_tuning" and is_frenzy_active:
		frenzy_updated.emit(frenzy_multiplier, (frenzy_duration_remaining / 6.0) * 100.0)
	if upgrade_id == "avatar_speed":
		avatar_stat_updated.emit("avatar_speed", get_effective_avatar_speed())
	elif upgrade_id == "pickup_radius":
		avatar_stat_updated.emit("pickup_radius", get_effective_pickup_radius())
	elif upgrade_id == "clearance_level":
		avatar_stat_updated.emit("idle_level", float(idle_level))
		level_up.emit(idle_level)
		
	return true

## Recalculates stats from currently purchased upgrade levels.
func recalculate_stats() -> void:
	var total_rps: float = 0.0
	var total_click: float = 1.0
	
	for up_id in upgrades:
		var up: Dictionary = upgrades[up_id]
		var lvl: int = int(up.get("level", 0))
		var gain: float = float(up.get("power_gain", 0.0))
		var type: String = up.get("type", "")
		if type == "idle":
			total_rps += lvl * gain
		elif type == "click":
			total_click += lvl * gain
			
	base_passive_rps = total_rps
	var click_mult: float = 2.0 if is_tech_researched("tech_quantum_ads") else 1.0
	base_click_power = total_click * click_mult
	
	if is_frenzy_active:
		var tuning_level: int = int(upgrades.get("overdrive_tuning", {}).get("level", 0))
		frenzy_multiplier = 3.0 + (0.5 * tuning_level)
		
	# Phase 4 stats derived from upgrades
	avatar_speed_level = int(upgrades.get("avatar_speed", {}).get("level", 0))
	pickup_radius_level = int(upgrades.get("pickup_radius", {}).get("level", 0))
	var clearance: int = int(upgrades.get("clearance_level", {}).get("level", 0))
	idle_level = 1 + clearance

## Returns upgrade state dictionary (level, current_cost, name, description, etc.).
func get_upgrade_data(upgrade_id: String) -> Dictionary:
	if upgrades.has(upgrade_id):
		var up = upgrades[upgrade_id]
		var cost: float = roundf(float(up["base_cost"]) * pow(float(up["cost_mult"]), float(up["level"])))
		up["current_cost"] = cost
		return up
	return {}

## Computes current bonus user passive multiplier (1.0 + 1% per bonus user).
func get_bonus_multiplier() -> float:
	return 1.0 + (float(bonus_users) * 0.01)

## Returns passive boost multiplier from collected 3D campus items (+5% per item).
func get_campus_item_multiplier() -> float:
	return (1.0 + (float(collectibles_collected) * 0.10)) if is_tech_researched("tech_neural_cloud") else (1.0 + (float(collectibles_collected) * 0.05))

## Returns passive RPS boosted by bonus users multiplier, campus item multiplier, tech research, active server overclock buff, and active campaign buff.
func get_effective_passive_rps() -> float:
	var camp_rps_mult: float = campaign_rps_buff_multiplier if campaign_rps_buff_timer > 0.0 else 1.0
	return base_passive_rps * get_bonus_multiplier() * get_campus_item_multiplier() * (1.25 if is_tech_researched("tech_server_overclock") else 1.0) * (server_overclock_buff_multiplier if (server_overclock_buff_timer > 0.0 or server_overclock_buff_active) else 1.0) * camp_rps_mult

## Activates the Server Room Overclock temporary RPS boost event (+50% for 25s by default).
func activate_server_overclock_buff(duration: float = 25.0, multiplier: float = 1.50) -> void:
	server_overclock_buff_timer = duration
	server_overclock_buff_remaining = duration
	server_overclock_buff_multiplier = multiplier
	server_overclock_buff_active = true
	rps_changed.emit(get_effective_passive_rps())
	server_overclock_buff_started.emit(multiplier, duration)

# ==============================================================================
# Phase 11 Narrative Story-Kampagne Methods ("The Unicorn Journey")
# ==============================================================================

## Returns current narrative campaign chapter (1: Seed Stage, 2: Series A, 3: Unicorn Status).
func get_campaign_chapter() -> int:
	return campaign_chapter

## Advances campaign to next chapter.
func advance_campaign_chapter() -> void:
	campaign_chapter += 1
	campaign_chapter_changed.emit(campaign_chapter)
	save_to_disk()

## Returns true if the specified campaign quest has been completed.
func is_campaign_quest_completed(quest_id: String) -> bool:
	return campaign_completed_quests.has(quest_id)

## Activates temporary passive RPS multiplier from campaign choice or event.
func activate_campaign_rps_buff(multiplier: float, duration: float) -> void:
	campaign_rps_buff_multiplier = multiplier
	campaign_rps_buff_timer = duration
	rps_changed.emit(get_effective_passive_rps())
	campaign_buff_started.emit("rps", multiplier, duration)

## Activates temporary avatar speed multiplier from campaign choice or event.
func activate_campaign_speed_buff(multiplier: float, duration: float) -> void:
	campaign_speed_buff_multiplier = multiplier
	campaign_speed_buff_timer = duration
	campaign_buff_started.emit("speed", multiplier, duration)

## Activates Unicorn Espresso buff (+50% avatar speed, +20% worker production) for duration seconds.
func activate_unicorn_espresso_buff(duration: float = 60.0) -> void:
	unicorn_espresso_buff_timer = duration
	unicorn_espresso_buff_remaining = duration
	unicorn_espresso_buff_active = true
	unicorn_espresso_buff_started.emit(duration, 1.50, 1.20)

## Returns true if Unicorn Espresso buff is currently active.
func is_unicorn_espresso_active() -> bool:
	return unicorn_espresso_buff_active and (unicorn_espresso_buff_timer > 0.0 or unicorn_espresso_buff_remaining > 0.0)

## Records player's narrative choice for a chapter and distributes the immediate bonus.
func record_campaign_choice(chapter: int, choice_id: String, reward_type: String, reward_value: float, duration: float = 0.0) -> void:
	chapter = clampi(chapter, 1, 3)
	var already_chosen: bool = campaign_choices.has(str(chapter)) or campaign_choices.has(chapter)
	campaign_choices[str(chapter)] = choice_id
	campaign_choices[chapter] = choice_id
	if not already_chosen:
		match reward_type.to_lower():
			"energy", "users", "bonus_users":
				earn_energy(reward_value)
			"rps", "rps_buff":
				activate_campaign_rps_buff(reward_value, duration)
			"speed", "speed_buff":
				activate_campaign_speed_buff(reward_value, duration)
	campaign_choice_selected.emit(chapter, choice_id, reward_type)
	save_to_disk()

## Directly awards energy (e.g. from grants, pitch stage, etc.) and emits energy_changed signal.
func earn_energy(amount: float) -> void:
	if amount <= 0.0:
		return
	energy += amount
	total_energy_earned += amount
	energy_changed.emit(energy, amount)

## Awards bonus users from daily quests or milestone rewards.
func award_bonus_users(amount: int) -> void:
	if amount <= 0:
		return
	bonus_users += amount
	energy += float(amount)
	total_energy_earned += float(amount)
	recalculate_stats()
	energy_changed.emit(energy, float(amount))
	rps_changed.emit(get_effective_passive_rps())
	bonus_users_changed.emit(bonus_users, amount)
	save_to_disk()

# ==============================================================================
# Phase 4 3D Meta-Progression & Interaction Methods
# ==============================================================================

## Computes effective avatar movement speed multiplier (1.0 + avatar_speed_level * 0.15) with tech & campaign buffs.
func get_effective_avatar_speed() -> float:
	var speed_boost: float = 0.15 if is_tech_researched("tech_coffee_automation") else 0.0
	var base_speed: float = 1.0 + float(avatar_speed_level) * 0.15 + speed_boost
	var campaign_mult: float = campaign_speed_buff_multiplier if campaign_speed_buff_timer > 0.0 else 1.0
	return base_speed * campaign_mult

## Returns current idle progression / security clearance level (baseline 1).
func get_idle_level() -> int:
	return idle_level

## Computes effective 3D item pickup radius multiplier (1.0 + pickup_radius_level * 0.25).
func get_effective_pickup_radius() -> float:
	return 1.0 + float(pickup_radius_level) * 0.25

## Registers collection of a 3D physical item (briefcase/power-up) and awards energy.
func collect_3d_item(item_type: String, reward_amount: float = 50.0) -> void:
	var reward: float = maxf(0.0, reward_amount)
	energy += reward
	total_energy_earned += reward
	collectibles_collected += 1
	item_inventory[item_type] = int(item_inventory.get(item_type, 0)) + 1
	energy_changed.emit(energy, reward)
	rps_changed.emit(get_effective_passive_rps())
	collectible_picked_up.emit(item_type, collectibles_collected)
	
	# Quest tracker auto-advancement
	if item_type == "briefcase":
		advance_campus_quest("quest_briefcases", 1)
	elif item_type == "coffee":
		advance_campus_quest("quest_coffee", 1)
	elif item_type == "usb_drive":
		advance_campus_quest("quest_usb", 1)

## Unlocks a 3D campus zone barrier if not already unlocked.
func unlock_zone(zone_id: String) -> bool:
	if zone_id.is_empty():
		return false
	if is_zone_unlocked(zone_id):
		return true
	unlocked_zones.append(zone_id)
	zone_unlocked.emit(zone_id)
	
	# Quest tracker auto-advancement for zone gates
	if zone_id == "server_room":
		advance_campus_quest("quest_server", 1)
	elif zone_id == "lab_room":
		advance_campus_quest("quest_lab", 1)
		
	return true

## Returns true if the specified zone barrier has been unlocked.
func is_zone_unlocked(zone_id: String) -> bool:
	return unlocked_zones.has(zone_id)

# --- Campus Quest Management Interface ---

## Returns quest status: "not_started", "active", "ready", "completed".
func get_campus_quest_status(quest_id: String) -> String:
	if not campus_quests.has(quest_id):
		return "not_started"
	return str(campus_quests[quest_id].get("status", "not_started"))

## Starts an active campus quest with a target count.
func start_campus_quest(quest_id: String, target_count: int = 1) -> void:
	active_campus_quest_id = quest_id
	if campus_quests.has(quest_id) and campus_quests[quest_id].get("status") in ["active", "ready", "completed"]:
		if campus_quests[quest_id].get("status") == "active":
			if quest_id == "quest_server" and is_zone_unlocked("server_room"):
				campus_quests[quest_id]["current_count"] = 1
				campus_quests[quest_id]["status"] = "ready"
				campus_quest_updated.emit(quest_id, "ready", 1, 1)
			elif quest_id == "quest_lab" and is_zone_unlocked("lab_room"):
				campus_quests[quest_id]["current_count"] = 1
				campus_quests[quest_id]["status"] = "ready"
				campus_quest_updated.emit(quest_id, "ready", 1, 1)
		return

	campus_quests[quest_id] = {
		"status": "active",
		"current_count": 0,
		"target_count": maxi(1, target_count)
	}

	if quest_id == "quest_server" and is_zone_unlocked("server_room"):
		campus_quests[quest_id]["current_count"] = 1
		campus_quests[quest_id]["status"] = "ready"
		campus_quest_updated.emit(quest_id, "ready", 1, 1)
	elif quest_id == "quest_lab" and is_zone_unlocked("lab_room"):
		campus_quests[quest_id]["current_count"] = 1
		campus_quests[quest_id]["status"] = "ready"
		campus_quest_updated.emit(quest_id, "ready", 1, 1)
	else:
		campus_quest_updated.emit(quest_id, "active", 0, maxi(1, target_count))

## Increments quest progress counter towards completion.
func advance_campus_quest(quest_id: String, amount: int = 1) -> void:
	if not campus_quests.has(quest_id):
		return
	var q = campus_quests[quest_id]
	if q.get("status") != "active":
		return
	q["current_count"] = mini(int(q.get("target_count", 1)), int(q.get("current_count", 0)) + amount)
	if q["current_count"] >= int(q.get("target_count", 1)):
		q["status"] = "ready"
	campus_quest_updated.emit(quest_id, str(q["status"]), int(q["current_count"]), int(q["target_count"]))

## Completes a quest in "ready" state and awards rewards.
func complete_campus_quest(quest_id: String, reward_energy: float = 0.0, reward_bonus_users: int = 0) -> bool:
	if not campus_quests.has(quest_id):
		return false
	var q = campus_quests[quest_id]
	if q.get("status") != "ready":
		return false
	q["status"] = "completed"
	if active_campus_quest_id == quest_id:
		active_campus_quest_id = ""
	if reward_energy > 0.0:
		energy += reward_energy
		total_energy_earned += reward_energy
		energy_changed.emit(energy, reward_energy)
	if reward_bonus_users > 0:
		bonus_users += reward_bonus_users
		bonus_users_changed.emit(bonus_users, reward_bonus_users)
	campus_quest_completed.emit(quest_id, reward_energy, reward_bonus_users)
	campus_quest_updated.emit(quest_id, "completed", int(q["current_count"]), int(q["target_count"]))
	if not campaign_completed_quests.has(quest_id):
		campaign_completed_quests.append(quest_id)
		campaign_quest_completed.emit(quest_id, campaign_chapter)
		if (quest_id == "quest_briefcases" and campaign_chapter == 1) or \
		   (quest_id == "quest_server" and campaign_chapter == 2) or \
		   (quest_id == "quest_lab" and campaign_chapter == 3):
			advance_campaign_chapter()
	
	if campaign_completed_quests.has("quest_briefcases") and campaign_chapter == 1:
		advance_campaign_chapter()
	if campaign_completed_quests.has("quest_server") and campaign_chapter == 2:
		advance_campaign_chapter()
	if campaign_completed_quests.has("quest_lab") and campaign_chapter == 3:
		advance_campaign_chapter()
	save_to_disk()
	return true

## Serializes state to user://savegame.json.
func save_to_disk() -> void:
	var save_data: Dictionary = {
		"version": 1,
		"timestamp": int(Time.get_unix_time_from_system()),
		"energy": energy,
		"total_energy_earned": total_energy_earned,
		"total_clicks": total_clicks,
		"sparks_collected": sparks_collected,
		"bonus_users": bonus_users,
		"passive_rps": base_passive_rps,
		"base_passive_rps": base_passive_rps,
		"base_click_power": base_click_power,
		"avatar_speed_level": avatar_speed_level,
		"idle_level": idle_level,
		"pickup_radius_level": pickup_radius_level,
		"collectibles_collected": collectibles_collected,
		"active_campus_quest_id": active_campus_quest_id,
		"campaign_chapter": campaign_chapter,
		"campaign_completed_quests": campaign_completed_quests.duplicate(),
		"campaign_choices": campaign_choices.duplicate(true),
		"unlocked_zones": unlocked_zones.duplicate(),
		"campus_quests": campus_quests.duplicate(true),
		"researched_techs": researched_techs.duplicate(),
		"item_inventory": item_inventory.duplicate(),
		"audio_settings": {
			"master_volume": master_volume,
			"music_volume": music_volume,
			"sfx_volume": sfx_volume,
			"master_muted": master_muted,
			"music_muted": music_muted,
			"sfx_muted": sfx_muted
		},
		"screen_shake_intensity": screen_shake_intensity,
		"light_cycle_mode": light_cycle_mode,
		"vfx_settings": {
			"screen_shake_intensity": screen_shake_intensity,
			"light_cycle_mode": light_cycle_mode
		},
		"upgrades": {}
	}
	
	for up_id in upgrades:
		save_data["upgrades"][up_id] = {
			"level": int(upgrades[up_id].get("level", 0)),
			"current_cost": float(upgrades[up_id].get("current_cost", upgrades[up_id]["base_cost"]))
		}
		
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		var err := FileAccess.get_open_error()
		printerr("[GameState] Save write failed with error code: ", err)
		return
	file.store_string(JSON.stringify(save_data, "\t"))
	file.flush()
	file.close()

## Deserializes state from user://savegame.json and calculates offline catch-up.
func load_from_disk() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
		
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return false
	var text: String = file.get_as_text()
	file.close()
	
	var json := JSON.new()
	var parse_err := json.parse(text)
	if parse_err != OK:
		printerr("[GameState] Corrupt save file: ", json.get_error_message())
		return false
		
	var data = json.data
	if not data is Dictionary:
		return false
		
	var raw_energy: float = float(data.get("energy", 0.0))
	energy = 0.0 if (is_nan(raw_energy) or is_inf(raw_energy)) else maxf(0.0, raw_energy)
	
	var raw_total_earned: float = float(data.get("total_energy_earned", energy))
	total_energy_earned = energy if (is_nan(raw_total_earned) or is_inf(raw_total_earned)) else maxf(energy, raw_total_earned)
	
	total_clicks = maxi(0, int(data.get("total_clicks", 0)))
	sparks_collected = maxi(0, int(data.get("sparks_collected", 0)))
	bonus_users = maxi(0, int(data.get("bonus_users", 0)))
	
	avatar_speed_level = maxi(0, int(data.get("avatar_speed_level", 0)))
	idle_level = maxi(1, int(data.get("idle_level", 1)))
	pickup_radius_level = maxi(0, int(data.get("pickup_radius_level", 0)))
	collectibles_collected = maxi(0, int(data.get("collectibles_collected", 0)))
	active_campus_quest_id = str(data.get("active_campus_quest_id", ""))
	
	unlocked_zones.clear()
	var raw_zones = data.get("unlocked_zones", [])
	if raw_zones is Array:
		for z in raw_zones:
			if z is String and not z.is_empty():
				unlocked_zones.append(z)
				
	campus_quests.clear()
	var raw_quests = data.get("campus_quests", {})
	if raw_quests is Dictionary:
		for q_id in raw_quests:
			if raw_quests[q_id] is Dictionary:
				campus_quests[q_id] = raw_quests[q_id].duplicate(true)
	
	researched_techs.clear()
	var raw_techs = data.get("researched_techs", [])
	if raw_techs is Array:
		for t in raw_techs:
			if t is String and not t.is_empty() and not researched_techs.has(t):
				researched_techs.append(t)
				
	item_inventory = {
		"briefcase": 0,
		"coffee": 0,
		"usb_drive": 0
	}
	var raw_inv = data.get("item_inventory", {})
	if raw_inv is Dictionary:
		for k in raw_inv:
			item_inventory[str(k)] = maxi(0, int(raw_inv[k]))
	
	var saved_upgrades = data.get("upgrades", {})
	if saved_upgrades is Dictionary:
		for up_id in saved_upgrades:
			if upgrades.has(up_id):
				var up_entry = saved_upgrades[up_id]
				var lvl: int = 0
				if up_entry is Dictionary:
					lvl = int(up_entry.get("level", 0))
				elif up_entry is int or up_entry is float:
					lvl = int(up_entry)
				lvl = maxi(0, lvl)
				upgrades[up_id]["level"] = lvl
				var next_cost: float = roundf(float(upgrades[up_id]["base_cost"]) * pow(float(upgrades[up_id]["cost_mult"]), float(lvl)))
				upgrades[up_id]["current_cost"] = next_cost
				
	recalculate_stats()
	# Defensive fallback: if explicit top-level avatar stats were provided in save data (e.g., custom saves)
	if data.has("avatar_speed_level"):
		avatar_speed_level = maxi(avatar_speed_level, maxi(0, int(data.get("avatar_speed_level", 0))))
	if data.has("idle_level"):
		idle_level = maxi(idle_level, maxi(1, int(data.get("idle_level", 1))))
	if data.has("pickup_radius_level"):
		pickup_radius_level = maxi(pickup_radius_level, maxi(0, int(data.get("pickup_radius_level", 0))))
	
	# If save file explicitly specifies passive_rps, ensure it is honored
	var explicit_rps: float = float(data.get("base_passive_rps", data.get("passive_rps", 0.0)))
	if not is_nan(explicit_rps) and not is_inf(explicit_rps) and explicit_rps > base_passive_rps:
		base_passive_rps = explicit_rps
		
	# Offline catch-up calculation: 50% efficiency, capped at 8 hours (28800s), clock guard
	var now_unix: float = Time.get_unix_time_from_system()
	var saved_timestamp: float = float(data.get("timestamp", now_unix))
	var elapsed: float = now_unix - saved_timestamp
	if is_nan(elapsed) or is_inf(elapsed) or elapsed < 0.0:
		elapsed = 0.0
	var effective_elapsed: float = minf(elapsed, 28800.0)
	var effective_rps: float = get_effective_passive_rps()
	var offline_gain: float = effective_rps * effective_elapsed * 0.5
	if is_nan(offline_gain) or is_inf(offline_gain) or offline_gain < 0.0:
		offline_gain = 0.0
	
	if offline_gain > 0.0:
		energy += offline_gain
		total_energy_earned += offline_gain
		
	# Phase 9 Audio Settings Deserialization
	var audio_data = data.get("audio_settings", {})
	if audio_data is Dictionary and not audio_data.is_empty():
		master_volume = clampf(float(audio_data.get("master_volume", 1.0)), 0.0, 1.0)
		music_volume = clampf(float(audio_data.get("music_volume", 0.8)), 0.0, 1.0)
		sfx_volume = clampf(float(audio_data.get("sfx_volume", 1.0)), 0.0, 1.0)
		master_muted = bool(audio_data.get("master_muted", false))
		music_muted = bool(audio_data.get("music_muted", false))
		sfx_muted = bool(audio_data.get("sfx_muted", false))
		
		var am = get_node_or_null("/root/AudioManager")
		if am != null and am.has_method("apply_settings"):
			am.apply_settings(get_audio_settings())

	# Phase 10 Screen Shake Deserialization
	if data.has("screen_shake_intensity"):
		screen_shake_intensity = clampf(float(data.get("screen_shake_intensity", 1.0)), 0.0, 1.0)
	elif data.has("vfx_settings") and data["vfx_settings"] is Dictionary and data["vfx_settings"].has("screen_shake_intensity"):
		screen_shake_intensity = clampf(float(data["vfx_settings"].get("screen_shake_intensity", 1.0)), 0.0, 1.0)
	else:
		screen_shake_intensity = 1.0
	screen_shake_changed.emit(screen_shake_intensity)

	# Phase 10 Day/Night Light Cycle Deserialization
	var loaded_light_mode: String = "auto"
	if data.has("light_cycle_mode"):
		loaded_light_mode = str(data.get("light_cycle_mode", "auto")).to_lower()
	elif data.has("vfx_settings") and data["vfx_settings"] is Dictionary and data["vfx_settings"].has("light_cycle_mode"):
		loaded_light_mode = str(data["vfx_settings"].get("light_cycle_mode", "auto")).to_lower()

	if loaded_light_mode not in ["auto", "day", "night"]:
		loaded_light_mode = "auto"
	light_cycle_mode = loaded_light_mode
	light_cycle_mode_changed.emit(light_cycle_mode)

	# Phase 11 Narrative Story-Kampagne Deserialization
	campaign_chapter = maxi(1, int(data.get("campaign_chapter", 1)))
	campaign_completed_quests.clear()
	var raw_camp_quests = data.get("campaign_completed_quests", [])
	if raw_camp_quests is Array:
		for cq in raw_camp_quests:
			if cq is String and not cq.is_empty():
				campaign_completed_quests.append(cq)
	campaign_choices.clear()
	var raw_camp_choices = data.get("campaign_choices", {})
	if raw_camp_choices is Dictionary:
		for k in raw_camp_choices:
			campaign_choices[str(k)] = raw_camp_choices[k]
			if str(k).is_valid_int():
				campaign_choices[int(str(k))] = raw_camp_choices[k]

	# Reconcile legacy savegames where campus_quests may already be completed
	if campus_quests.get("quest_lab", {}).get("status") == "completed":
		campaign_chapter = maxi(campaign_chapter, 4)
		if not campaign_completed_quests.has("quest_lab"): campaign_completed_quests.append("quest_lab")
		if not campaign_completed_quests.has("quest_server"): campaign_completed_quests.append("quest_server")
		if not campaign_completed_quests.has("quest_briefcases"): campaign_completed_quests.append("quest_briefcases")
	elif campus_quests.get("quest_server", {}).get("status") == "completed":
		campaign_chapter = maxi(campaign_chapter, 3)
		if not campaign_completed_quests.has("quest_server"): campaign_completed_quests.append("quest_server")
		if not campaign_completed_quests.has("quest_briefcases"): campaign_completed_quests.append("quest_briefcases")
	elif campus_quests.get("quest_briefcases", {}).get("status") == "completed":
		campaign_chapter = maxi(campaign_chapter, 2)
		if not campaign_completed_quests.has("quest_briefcases"): campaign_completed_quests.append("quest_briefcases")

	campaign_chapter_changed.emit(campaign_chapter)
			
	energy_changed.emit(energy, offline_gain)
	rps_changed.emit(get_effective_passive_rps())
	frenzy_updated.emit(frenzy_multiplier, 0.0)
	return true

## Formats numbers cleanly with SI suffixes (K, M, B, T) or scientific notation.
func format_number(value: float) -> String:
	if is_nan(value) or is_inf(value) or value <= 0.0:
		return "0"
	if value < 1000.0:
		if value == floorf(value):
			return str(int(value))
		return "%.1f" % value
	elif value < 1000000.0:
		return "%.2f K" % (value / 1000.0)
	elif value < 1000000000.0:
		return "%.2f M" % (value / 1000000.0)
	elif value < 1000000000000.0:
		return "%.2f B" % (value / 1000000000.0)
	elif value < 1000000000000000.0:
		return "%.2f T" % (value / 1000000000000.0)
	else:
		return "%.2e" % value

# ==============================================================================
# Phase 8 Tech-Tree & Research Lab Methods
# ==============================================================================

## Returns true if the given technology ID has already been researched.
func is_tech_researched(tech_id: String) -> bool:
	return researched_techs.has(tech_id)

## Evaluates whether requirements (energy cost and item prerequisites) are met to research a tech.
func can_research_tech(tech_id: String) -> bool:
	if not TECH_DEFINITIONS.has(tech_id):
		return false
	if is_tech_researched(tech_id):
		return false
	var def: Dictionary = TECH_DEFINITIONS[tech_id]
	var cost: float = float(def.get("cost", def.get("energy_cost", 0.0)))
	if energy < cost:
		return false
	var req_item: String = str(def.get("required_item", ""))
	var req_count: int = int(def.get("required_item_count", 0))
	if not req_item.is_empty() and req_count > 0:
		if get_item_count(req_item) < req_count:
			return false
	return true

## Purchases and completes research for a technology, deducting costs and updating stats.
func research_tech(tech_id: String) -> bool:
	if not can_research_tech(tech_id):
		return false
	var def: Dictionary = TECH_DEFINITIONS[tech_id]
	var cost: float = float(def.get("cost", def.get("energy_cost", 0.0)))
	energy -= cost
	var req_item: String = str(def.get("required_item", ""))
	var req_count: int = int(def.get("required_item_count", 0))
	if not req_item.is_empty() and req_count > 0:
		consume_items(req_item, req_count)
	researched_techs.append(tech_id)
	recalculate_stats()
	energy_changed.emit(energy, -cost)
	tech_researched.emit(tech_id)
	var am = get_node_or_null("/root/AudioManager")
	if am != null and am.has_method("play_sfx_research"):
		am.play_sfx_research()
	if tech_id == "tech_coffee_automation":
		avatar_stat_updated.emit("avatar_speed", get_effective_avatar_speed())
	elif tech_id == "tech_server_overclock" or tech_id == "tech_neural_cloud":
		rps_changed.emit(get_effective_passive_rps())
	save_to_disk()
	return true

## Returns a duplicate of all registered technology definitions.
func get_tech_definitions() -> Dictionary:
	return TECH_DEFINITIONS.duplicate(true)

## Returns the current inventory quantity for an item type (maps 'usb' to 'usb_drive').
func get_item_count(item_type: String) -> int:
	if item_type in ["usb", "usb_drive"]:
		return int(item_inventory.get("usb_drive", 0)) + int(item_inventory.get("usb", 0))
	return int(item_inventory.get(item_type, 0))

## Checks if inventory contains at least count units of the specified item type.
func has_items(item_type: String, count: int) -> bool:
	return get_item_count(item_type) >= count

## Consumes count units of an item type from inventory. Returns true if successful.
func consume_items(item_type: String, count: int) -> bool:
	if not has_items(item_type, count):
		return false
	var remaining: int = count
	if item_type in ["usb", "usb_drive"]:
		var usb_dr: int = int(item_inventory.get("usb_drive", 0))
		var take_dr: int = mini(usb_dr, remaining)
		item_inventory["usb_drive"] = usb_dr - take_dr
		remaining -= take_dr
		if remaining > 0:
			var usb_raw: int = int(item_inventory.get("usb", 0))
			item_inventory["usb"] = maxi(0, usb_raw - remaining)
	else:
		item_inventory[item_type] = maxi(0, int(item_inventory.get(item_type, 0)) - count)
	return true

## Adds energy directly (e.g. from incubator mini-workers).
func add_energy(amount: float) -> void:
	if amount <= 0.0:
		return
	energy += amount
	total_energy_earned += amount
	energy_changed.emit(energy, amount)

## Returns worker production frequency multiplier (1.10x with tech_coffee_automation, scaled by 1.20x during Unicorn Espresso buff).
func get_worker_production_multiplier() -> float:
	var tech_mult: float = 1.10 if is_tech_researched("tech_coffee_automation") else 1.0
	var espresso_mult: float = 1.20 if (unicorn_espresso_buff_active or unicorn_espresso_buff_timer > 0.0) else 1.0
	return tech_mult * espresso_mult

## Returns angel investor spark spawn chance multiplier (1.5x with tech_quantum_ads).
func get_angel_investor_spawn_chance_multiplier() -> float:
	return 1.5 if is_tech_researched("tech_quantum_ads") else 1.0

# ==============================================================================
# Phase 9 Audio Settings & Management Methods
# ==============================================================================

## Updates master volume (0.0 to 1.0) and persists state
func set_master_volume(val: float) -> void:
	master_volume = clampf(val, 0.0, 1.0)
	audio_settings_changed.emit("master_volume", master_volume)
	var audio = get_node_or_null("/root/AudioManager")
	if audio != null and audio.has_method("set_master_volume"):
		audio.set_master_volume(master_volume)

## Updates music volume (0.0 to 1.0) and persists state
func set_music_volume(val: float) -> void:
	music_volume = clampf(val, 0.0, 1.0)
	audio_settings_changed.emit("music_volume", music_volume)
	var audio = get_node_or_null("/root/AudioManager")
	if audio != null and audio.has_method("set_music_volume"):
		audio.set_music_volume(music_volume)

## Updates SFX volume (0.0 to 1.0) and persists state
func set_sfx_volume(val: float) -> void:
	sfx_volume = clampf(val, 0.0, 1.0)
	audio_settings_changed.emit("sfx_volume", sfx_volume)
	var audio = get_node_or_null("/root/AudioManager")
	if audio != null and audio.has_method("set_sfx_volume"):
		audio.set_sfx_volume(sfx_volume)

## Toggles or sets master mute
func set_master_muted(muted: bool) -> void:
	master_muted = muted
	audio_settings_changed.emit("master_muted", master_muted)
	var audio = get_node_or_null("/root/AudioManager")
	if audio != null and audio.has_method("set_master_mute"):
		audio.set_master_mute(master_muted)

## Toggles or sets music mute
func set_music_muted(muted: bool) -> void:
	music_muted = muted
	audio_settings_changed.emit("music_muted", music_muted)
	var audio = get_node_or_null("/root/AudioManager")
	if audio != null and audio.has_method("set_music_mute"):
		audio.set_music_mute(music_muted)

## Toggles or sets SFX mute
func set_sfx_muted(muted: bool) -> void:
	sfx_muted = muted
	audio_settings_changed.emit("sfx_muted", sfx_muted)
	var audio = get_node_or_null("/root/AudioManager")
	if audio != null and audio.has_method("set_sfx_mute"):
		audio.set_sfx_mute(sfx_muted)

## Returns current audio settings dictionary
func get_audio_settings() -> Dictionary:
	return {
		"master_volume": master_volume,
		"music_volume": music_volume,
		"sfx_volume": sfx_volume,
		"master_muted": master_muted,
		"music_muted": music_muted,
		"sfx_muted": sfx_muted
	}

# ==============================================================================
# Phase 10 VFX & Screen Shake Methods
# ==============================================================================

## Sets screen shake intensity (0.0 to 1.0) and emits screen_shake_changed
func set_screen_shake_intensity(val: float) -> void:
	screen_shake_intensity = clampf(val, 0.0, 1.0)
	screen_shake_changed.emit(screen_shake_intensity)

## Returns current screen shake intensity
func get_screen_shake_intensity() -> float:
	return screen_shake_intensity

# ==============================================================================
# Phase 10 Day/Night Light Cycle Methods
# ==============================================================================

## Sets light cycle mode ("auto", "day", "night") and emits light_cycle_mode_changed
func set_light_cycle_mode(mode: String) -> void:
	var valid_mode = mode.to_lower()
	if valid_mode not in ["auto", "day", "night"]:
		valid_mode = "auto"
	if light_cycle_mode != valid_mode:
		light_cycle_mode = valid_mode
		light_cycle_mode_changed.emit(light_cycle_mode)

## Returns current light cycle mode
func get_light_cycle_mode() -> String:
	return light_cycle_mode


