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

# --- State Variables ---
var energy: float = 0.0
var total_energy_earned: float = 0.0
var total_clicks: int = 0
var sparks_collected: int = 0
var bonus_users: int = 0

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
	
	upgrades.clear()
	for up_id in DEFAULT_UPGRADES:
		upgrades[up_id] = DEFAULT_UPGRADES[up_id].duplicate(true)

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
	base_click_power = total_click
	
	if is_frenzy_active:
		var tuning_level: int = int(upgrades.get("overdrive_tuning", {}).get("level", 0))
		frenzy_multiplier = 3.0 + (0.5 * tuning_level)

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

## Returns passive RPS boosted by bonus users multiplier.
func get_effective_passive_rps() -> float:
	return base_passive_rps * get_bonus_multiplier()

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
