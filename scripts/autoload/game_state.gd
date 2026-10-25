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
signal camera_shake_requested(amount: float)
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

# Phase 12 IPO ("Going Public") Prestige & Trophy Signals
signal ipo_completed(angel_shares_gained: int, total_angel_shares: int, multiplier: float)
signal angel_shares_changed(total_shares: int, delta_shares: int)
signal trophy_unlocked(trophy_id: String)
signal daily_streak_updated(new_streak: int)
signal daily_tasks_updated(tasks: Array)
signal daily_task_claimed(task_id: String, reward_dict: Dictionary)

# Phase 13 Syndicate / Gilden-Wirtschaft Signals
signal syndicate_joined(syndicate_data: Dictionary)
signal syndicate_left()
signal syndicate_contributed(resource_type: String, amount: float, new_fund_total: float, tier: int)
signal syndicate_tier_upgraded(new_tier: int, bonuses: Dictionary)
signal syndicate_season_updated(season_week: int, seasonal_score: int)

# Phase 14 Staff & Autonomous Worker Simulation Signals
signal staff_worker_hired(worker_data: Dictionary)
signal staff_worker_fired(worker_id: String)
signal staff_worker_state_changed(worker_id: String, new_state: String)
signal staff_worker_morale_updated(worker_id: String, new_morale: float, new_fatigue: float)
signal staff_desk_upgraded(desk_index: int, new_level: int)
signal staff_coffee_break_started(duration: float)
signal staff_coffee_break_ended()
signal staff_morale_updated(average_morale: float)
signal staff_epiphany_triggered(worker_id: String, reward_energy: float)

# Compatible Aliases for Phase 14 Staff & Worker Signals
signal worker_hired(worker_data: Dictionary)
signal worker_fired(worker_id: String)
signal worker_state_changed(worker_id: String, new_state: String)
signal desk_upgraded(desk_index: int, new_level: int, cost: float)
signal team_coffee_break_started(duration: float, speed_multiplier: float)
signal team_coffee_break_ended()
signal epiphany_collected(worker_id: String, bonus_energy: float)
signal staff_bonus_updated(staff_multiplier: float, active_workers: int, avg_morale: float)

# Phase 16 Campus Minigames & 3D Station Cooldown Signals
signal station_cooldown_started(station_id: String, duration: float)
signal station_cooldown_ended(station_id: String)

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

# Phase 12 IPO ("Going Public") Prestige Constants & State Variables
const IPO_ENERGY_THRESHOLD: float = 1000000.0  # 1M Lifetime Energy

var total_lifetime_energy: float = 0.0
var angel_shares: int = 0
var total_ipos_completed: int = 0
var unlocked_trophies: Array[String] = []
var daily_streak: int = 0
var last_daily_challenge_date: String = ""
var daily_board_streak: int = 0
var daily_board_last_login_day: int = 0
var daily_board_tasks: Array[Dictionary] = []

# Phase 13 Syndicate / Gilden-Wirtschaft State Variables
var active_syndicate_id: String = ""
var active_syndicate_name: String = ""
var active_syndicate_tag: String = ""
var active_syndicate_desc: String = ""
var active_syndicate_role: String = "Member"
var syndicate_tier: int = 0
var syndicate_fund_energy: float = 0.0
var syndicate_fund_angel_shares: int = 0
var syndicate_energy_contributed: float = 0.0
var syndicate_angel_shares_contributed: int = 0
var syndicate_members_count: int = 1
var syndicate_seasonal_score: int = 0
var syndicate_season_week: int = 0
var syndicate_joined_timestamp: int = 0
var syndicate_unlocked_badges: Array[String] = []

# Phase 14 Staff & Autonomous Chibi-Worker Simulation State
var hired_workers: Array = []
var desk_levels: Array = [1, 1, 1, 1, 1]
var staff_hyper_focus_active: bool = false
var staff_hyper_focus_timer: float = 0.0
var staff_hyper_focus_remaining: float = 0.0
var staff_hyper_focus_multiplier: float = 1.50
var staff_coffee_break_active: bool = false
var staff_coffee_break_timer: float = 0.0
var staff_coffee_break_remaining: float = 0.0

# Phase 16 3D Campus Station Persistent Cooldowns
var station_cooldowns: Dictionary = {
	"server_terminal": 0.0,
	"pitch_stage": 0.0,
	"coffee_machine": 0.0
}

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

const DAILY_TASK_CATALOG: Dictionary = {
	"task_hype": {
		"id": "task_hype",
		"title": "3x Viraler Hype",
		"description": "Erreiche 3x Viralen Hype",
		"target": 3,
		"reward": {
			"energy": 10000.0,
			"description": "10.000 Energy"
		}
	},
	"task_briefcases": {
		"id": "task_briefcases",
		"title": "5 Aktenkoffer per Drohne",
		"description": "Sammle 5 Aktenkoffer per Drohne",
		"target": 5,
		"reward": {
			"energy": 15000.0,
			"angel_shares": 1,
			"description": "15.000 Energy, 1 Angel Share"
		}
	},
	"task_espresso": {
		"id": "task_espresso",
		"title": "1 Unicorn Espresso",
		"description": "Braue 1 Unicorn Espresso",
		"target": 1,
		"reward": {
			"energy": 20000.0,
			"rps_buff": 2.0,
			"duration": 45.0,
			"description": "20.000 Energy, 2x RPS buff"
		}
	},
	"task_server_hack": {
		"id": "task_server_hack",
		"title": "1 Cyber-Sync an Serverkonsole",
		"description": "Führe 1 Cyber-Sync an Serverkonsole durch",
		"target": 1,
		"reward": {
			"energy": 12000.0,
			"description": "12.000 Energy"
		}
	},
	"task_core_taps": {
		"id": "task_core_taps",
		"title": "50x Reactor Core",
		"description": "Tippe 50x auf den Reactor Core",
		"target": 50,
		"reward": {
			"energy": 8000.0,
			"description": "8.000 Energy"
		}
	},
	"task_buy_upgrades": {
		"id": "task_buy_upgrades",
		"title": "3 Upgrades kaufen",
		"description": "Kaufe 3 beliebige Upgrades",
		"target": 3,
		"reward": {
			"energy": 15000.0,
			"description": "15.000 Energy"
		}
	}
}

const DAILY_TASK_KEYS: Array[String] = [
	"task_hype",
	"task_briefcases",
	"task_espresso",
	"task_server_hack",
	"task_core_taps",
	"task_buy_upgrades"
]

# Phase 13 Syndicate Tier Configuration (Tiers 0 to 5)
const SYNDICATE_TIER_CONFIG: Dictionary = {
	0: {
		"tier": 0,
		"name": "Unaffiliated",
		"req_energy": 0.0,
		"req_shares": 0,
		"dividend_pct": 0.0,
		"dividend_mult": 1.0,
		"drone_speed_pct": 0.0,
		"drone_speed_mult": 1.0,
		"ipo_bonus_shares_pct": 0.0,
		"ipo_bonus_shares_mult": 1.0
	},
	1: {
		"tier": 1,
		"name": "Seed Syndicate",
		"req_energy": 10000.0,
		"req_shares": 1,
		"dividend_pct": 0.05,
		"dividend_mult": 1.05,
		"drone_speed_pct": 0.0,
		"drone_speed_mult": 1.0,
		"ipo_bonus_shares_pct": 0.0,
		"ipo_bonus_shares_mult": 1.0
	},
	2: {
		"tier": 2,
		"name": "Growth Syndicate",
		"req_energy": 100000.0,
		"req_shares": 5,
		"dividend_pct": 0.10,
		"dividend_mult": 1.10,
		"drone_speed_pct": 0.15,
		"drone_speed_mult": 1.15,
		"ipo_bonus_shares_pct": 0.0,
		"ipo_bonus_shares_mult": 1.0
	},
	3: {
		"tier": 3,
		"name": "Expansion Syndicate",
		"req_energy": 500000.0,
		"req_shares": 20,
		"dividend_pct": 0.15,
		"dividend_mult": 1.15,
		"drone_speed_pct": 0.15,
		"drone_speed_mult": 1.15,
		"ipo_bonus_shares_pct": 0.05,
		"ipo_bonus_shares_mult": 1.05
	},
	4: {
		"tier": 4,
		"name": "Venture Syndicate",
		"req_energy": 2500000.0,
		"req_shares": 50,
		"dividend_pct": 0.20,
		"dividend_mult": 1.20,
		"drone_speed_pct": 0.15,
		"drone_speed_mult": 1.15,
		"ipo_bonus_shares_pct": 0.10,
		"ipo_bonus_shares_mult": 1.10
	},
	5: {
		"tier": 5,
		"name": "Holding Monopoly",
		"req_energy": 10000000.0,
		"req_shares": 100,
		"dividend_pct": 0.25,
		"dividend_mult": 1.25,
		"drone_speed_pct": 0.15,
		"drone_speed_mult": 1.15,
		"ipo_bonus_shares_pct": 0.15,
		"ipo_bonus_shares_mult": 1.15
	}
}

# Phase 14 Staff Roles & Ergonomics Configuration
const MAX_WORKERS: int = 5
const MAX_DESK_LEVEL: int = 3
const BASE_WORKER_FATIGUE_RATE_PER_MINUTE: float = 0.02
const BASE_WORKER_FATIGUE_RATE_PER_SECOND: float = 0.02 / 60.0
const BASE_WORKER_MORALE_DECAY_RATE_PER_SECOND: float = 0.02 / 60.0

const STAFF_ROLE_DEFINITIONS: Dictionary = {
	"Frontend Dev": {
		"role": "Frontend Dev",
		"title": "Frontend Developer",
		"default_name": "Devin",
		"specialty": "UI responsiveness & click synergy",
		"hire_cost": 500.0,
		"desk_index": 0
	},
	"Backend Dev": {
		"role": "Backend Dev",
		"title": "Backend Architect",
		"default_name": "Bjarne",
		"specialty": "Server stability & throughput",
		"hire_cost": 1500.0,
		"desk_index": 1
	},
	"UI/UX Designer": {
		"role": "UI/UX Designer",
		"title": "UI/UX Specialist",
		"default_name": "Sora",
		"specialty": "Touch ergonomics & flow",
		"hire_cost": 3500.0,
		"desk_index": 2
	},
	"Growth Hacker": {
		"role": "Growth Hacker",
		"title": "Growth Hacker",
		"default_name": "Ada",
		"specialty": "Viral adoption & marketing",
		"hire_cost": 8000.0,
		"desk_index": 3
	},
	"QA Engineer": {
		"role": "QA Engineer",
		"title": "QA Lead",
		"default_name": "Quinn",
		"specialty": "Bug hunting & zero regressions",
		"hire_cost": 15000.0,
		"desk_index": 4
	}
}

const DESK_CONFIG: Dictionary = {
	1: {
		"level": 1,
		"name": "Basic Wooden Desk",
		"cost": 0.0,
		"upgrade_cost": 0.0,
		"fatigue_reduction_pct": 0.0,
		"fatigue_multiplier": 1.00
	},
	2: {
		"level": 2,
		"name": "Dual-Monitor Tech Desk",
		"cost": 5000.0,
		"upgrade_cost": 5000.0,
		"fatigue_reduction_pct": 0.25,
		"fatigue_multiplier": 0.75
	},
	3: {
		"level": 3,
		"name": "Cyber Standing Desk mit RGB",
		"cost": 25000.0,
		"upgrade_cost": 25000.0,
		"fatigue_reduction_pct": 0.60,
		"fatigue_multiplier": 0.40
	}
}

func _init() -> void:
	reset_state()

func _ready() -> void:
	print("[GameState] Autoload singleton initialized.")
	get_daily_tasks()

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

	# Phase 12 IPO ("Going Public") Prestige Defaults
	total_lifetime_energy = 0.0
	angel_shares = 0
	total_ipos_completed = 0
	unlocked_trophies.clear()
	daily_streak = 0
	last_daily_challenge_date = ""
	daily_board_streak = 0
	daily_board_last_login_day = 0
	daily_board_tasks.clear()

	# Phase 13 Syndicate / Gilden-Wirtschaft Defaults
	active_syndicate_id = ""
	active_syndicate_name = ""
	active_syndicate_tag = ""
	active_syndicate_desc = ""
	active_syndicate_role = "Member"
	syndicate_tier = 0
	syndicate_fund_energy = 0.0
	syndicate_fund_angel_shares = 0
	syndicate_energy_contributed = 0.0
	syndicate_angel_shares_contributed = 0
	syndicate_members_count = 1
	syndicate_seasonal_score = 0
	syndicate_season_week = 0
	syndicate_joined_timestamp = 0
	syndicate_unlocked_badges.clear()

	# Phase 14 Staff & Workplace Simulation Defaults
	hired_workers.clear()
	desk_levels = [1, 1, 1, 1, 1]
	staff_hyper_focus_active = false
	staff_hyper_focus_timer = 0.0
	staff_hyper_focus_remaining = 0.0
	staff_hyper_focus_multiplier = 1.50
	staff_coffee_break_active = false
	staff_coffee_break_timer = 0.0
	staff_coffee_break_remaining = 0.0

	# Phase 16 3D Campus Station Cooldown Defaults
	station_cooldowns = {
		"server_terminal": 0.0,
		"pitch_stage": 0.0,
		"coffee_machine": 0.0
	}

func _process(delta: float) -> void:
	var safe_delta: float = maxf(0.0, delta)
	var clamped_delta: float = minf(0.1, safe_delta)
	
	# Passive accumulation using clamped frame delta and bonus users multiplier
	var effective_rps: float = get_effective_passive_rps()
	if effective_rps > 0.0:
		var passive_gain: float = effective_rps * frenzy_multiplier * clamped_delta
		energy += passive_gain
		total_energy_earned += passive_gain
		total_lifetime_energy += passive_gain
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

	# Phase 14 Staff Fatigue & Morale Update
	update_staff_simulation(clamped_delta)

	# Phase 14 Staff Coffee Break / Hyper-Focus Buff Duration Decay
	if staff_hyper_focus_timer > 0.0 or staff_hyper_focus_active or staff_coffee_break_timer > 0.0 or staff_coffee_break_active:
		staff_hyper_focus_timer -= safe_delta
		staff_hyper_focus_remaining = maxf(0.0, staff_hyper_focus_timer)
		staff_coffee_break_timer = staff_hyper_focus_timer
		staff_coffee_break_remaining = staff_hyper_focus_remaining
		if staff_hyper_focus_timer <= 0.0:
			staff_hyper_focus_timer = 0.0
			staff_hyper_focus_remaining = 0.0
			staff_hyper_focus_active = false
			staff_coffee_break_timer = 0.0
			staff_coffee_break_remaining = 0.0
			staff_coffee_break_active = false
			for w in hired_workers:
				if str(w.get("current_state", "")) == "break":
					w["current_state"] = "working"
					staff_worker_state_changed.emit(str(w.get("id", "")), "working")
					worker_state_changed.emit(str(w.get("id", "")), "working")
			rps_changed.emit(get_effective_passive_rps())
			staff_coffee_break_ended.emit()
			team_coffee_break_ended.emit()

	# Phase 16 Station Cooldowns Active Decay
	for s_id in station_cooldowns.keys():
		var current_cd: float = float(station_cooldowns[s_id])
		if current_cd > 0.0:
			var new_cd: float = maxf(0.0, current_cd - safe_delta)
			station_cooldowns[s_id] = new_cd
			if new_cd <= 0.0:
				station_cooldown_ended.emit(s_id)

# --- Interface Contract Methods ---

## Registers an active core tap, updates frenzy, and rewards energy.
func tap_core() -> float:
	var live_event_mult: float = 1.0
	var lem = get_node_or_null("/root/LiveEventManager")
	if lem != null and lem.has_method("get_production_multiplier"):
		live_event_mult = lem.get_production_multiplier()
	var earned: float = base_click_power * frenzy_multiplier * get_angel_share_multiplier() * live_event_mult
	energy += earned
	total_energy_earned += earned
	total_lifetime_energy += earned
	total_clicks += 1
	core_tapped.emit(total_clicks)
	advance_daily_task("task_core_taps", 1)
	
	if lem != null and lem.has_method("contribute_progress"):
		lem.contribute_progress("click", 1.0)
	
	if not is_frenzy_active:
		frenzy_meter = minf(100.0, frenzy_meter + 4.0)
		if frenzy_meter >= 100.0:
			is_frenzy_active = true
			var tuning_level: int = int(upgrades.get("overdrive_tuning", {}).get("level", 0))
			frenzy_multiplier = 3.0 + (0.5 * tuning_level)
			frenzy_duration_remaining = 6.0
			frenzy_meter = 0.0
			frenzy_updated.emit(frenzy_multiplier, 100.0)
			advance_daily_task("task_hype", 1)
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
	var earned: float = maxf(50.0, base_passive_rps * 25.0) * get_angel_share_multiplier()
	energy += earned
	total_energy_earned += earned
	total_lifetime_energy += earned
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
	advance_daily_task("task_buy_upgrades", 1)
	
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

## Returns passive RPS boosted by bonus users multiplier, campus item multiplier, tech research, active server overclock buff, active campaign buff, syndicate dividend, live event production multiplier, and staff morale bonus.
func get_effective_passive_rps() -> float:
	var camp_rps_mult: float = campaign_rps_buff_multiplier if campaign_rps_buff_timer > 0.0 else 1.0
	var live_event_mult: float = get_live_event_production_multiplier()
	var staff_mult: float = get_staff_rps_multiplier()
	return base_passive_rps * get_bonus_multiplier() * get_campus_item_multiplier() * (1.25 if is_tech_researched("tech_server_overclock") else 1.0) * (server_overclock_buff_multiplier if (server_overclock_buff_timer > 0.0 or server_overclock_buff_active) else 1.0) * camp_rps_mult * get_angel_share_multiplier() * get_syndicate_dividend_multiplier() * live_event_mult * staff_mult

## Returns active LiveEventManager production multiplier (default 1.0).
func get_live_event_production_multiplier() -> float:
	var lem = get_node_or_null("/root/LiveEventManager")
	if lem != null and lem.has_method("get_production_multiplier"):
		return lem.get_production_multiplier()
	return 1.0

## Activates the Server Room Overclock temporary RPS boost event (+50% for 25s by default).
func activate_server_overclock_buff(duration: float = 25.0, multiplier: float = 1.50) -> void:
	server_overclock_buff_timer = duration
	server_overclock_buff_remaining = duration
	server_overclock_buff_multiplier = multiplier
	server_overclock_buff_active = true
	advance_daily_task("task_server_hack", 1)
	rps_changed.emit(get_effective_passive_rps())
	server_overclock_buff_started.emit(multiplier, duration)

# ==============================================================================
# Phase 16 Campus Minigames & 3D Station Persistent Cooldowns
# ==============================================================================

## Sets the persistent cooldown for a campus station (in seconds) and saves to disk on initiation.
func set_station_cooldown(station_id: String, duration: float) -> void:
	if station_id.is_empty():
		return
	var safe_duration: float = maxf(0.0, duration)
	var prev_cd: float = float(station_cooldowns.get(station_id, 0.0))
	if prev_cd <= 0.0 and (station_id == "coffee_machine_3d" or station_id == "barista_station"):
		prev_cd = float(station_cooldowns.get("coffee_machine", 0.0))

	station_cooldowns[station_id] = safe_duration
	if station_id == "coffee_machine_3d" or station_id == "barista_station":
		station_cooldowns["coffee_machine"] = safe_duration
	elif station_id == "coffee_machine":
		station_cooldowns["coffee_machine_3d"] = safe_duration

	if safe_duration > 0.0:
		# Emit started and persist to disk only on fresh initiation or explicit timer expansion
		if prev_cd <= 0.0 or safe_duration > prev_cd:
			station_cooldown_started.emit(station_id, safe_duration)
			save_to_disk()
	else:
		if prev_cd > 0.0:
			station_cooldown_ended.emit(station_id)
			save_to_disk()

## Returns remaining cooldown duration in seconds for a station (0.0 if ready).
func get_station_cooldown(station_id: String) -> float:
	if not station_cooldowns.has(station_id):
		if station_id == "barista_station" and station_cooldowns.has("coffee_machine"):
			return float(station_cooldowns.get("coffee_machine", 0.0))
		if station_id == "coffee_machine_3d" and station_cooldowns.has("coffee_machine"):
			return float(station_cooldowns.get("coffee_machine", 0.0))
		return 0.0
	var val = station_cooldowns.get(station_id, 0.0)
	if val is float or val is int:
		return maxf(0.0, float(val))
	return 0.0

## Returns true if the station is currently on cooldown (cooldown > 0.0).
func is_station_on_cooldown(station_id: String) -> bool:
	return get_station_cooldown(station_id) > 0.0

## Returns true if the station is ready for interaction (not on cooldown).
func is_station_ready(station_id: String) -> bool:
	return not is_station_on_cooldown(station_id)

## Resets all station cooldown timers to 0.0 and saves to disk.
func reset_all_station_cooldowns() -> void:
	for s_id in station_cooldowns.keys():
		station_cooldowns[s_id] = 0.0
		station_cooldown_ended.emit(s_id)
	save_to_disk()

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
	check_and_update_trophies()
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
	advance_daily_task("task_espresso", 1)
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
	total_lifetime_energy += amount
	energy_changed.emit(energy, amount)

## Awards bonus users from daily quests or milestone rewards.
func award_bonus_users(amount: int) -> void:
	if amount <= 0:
		return
	bonus_users += amount
	energy += float(amount)
	total_energy_earned += float(amount)
	total_lifetime_energy += float(amount)
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
	total_lifetime_energy += reward
	collectibles_collected += 1
	item_inventory[item_type] = int(item_inventory.get(item_type, 0)) + 1
	energy_changed.emit(energy, reward)
	rps_changed.emit(get_effective_passive_rps())
	collectible_picked_up.emit(item_type, collectibles_collected)
	
	# Quest tracker auto-advancement
	if item_type == "briefcase":
		advance_campus_quest("quest_briefcases", 1)
		advance_daily_task("task_briefcases", 1)
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
		total_lifetime_energy += reward_energy
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
	check_and_update_trophies()
	save_to_disk()
	return true

## Serializes state to user://savegame.json.
func save_to_disk() -> void:
	var save_data: Dictionary = {
		"version": 1,
		"timestamp": int(Time.get_unix_time_from_system()),
		"energy": energy,
		"total_energy_earned": total_energy_earned,
		"total_lifetime_energy": total_lifetime_energy,
		"angel_shares": angel_shares,
		"total_ipos_completed": total_ipos_completed,
		"unlocked_trophies": unlocked_trophies.duplicate(),
		"daily_streak": daily_streak,
		"last_daily_challenge_date": last_daily_challenge_date,
		"daily_board_streak": daily_board_streak,
		"daily_board_last_login_day": daily_board_last_login_day,
		"daily_board_tasks": daily_board_tasks.duplicate(true),
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
		"syndicate": {
			"active_id": active_syndicate_id,
			"name": active_syndicate_name,
			"tag": active_syndicate_tag,
			"description": active_syndicate_desc,
			"role": active_syndicate_role,
			"tier": syndicate_tier,
			"fund_energy": syndicate_fund_energy,
			"fund_angel_shares": syndicate_fund_angel_shares,
			"energy_contributed": syndicate_energy_contributed,
			"angel_shares_contributed": syndicate_angel_shares_contributed,
			"members_count": syndicate_members_count,
			"seasonal_score": syndicate_seasonal_score,
			"season_week": syndicate_season_week,
			"joined_timestamp": syndicate_joined_timestamp,
			"unlocked_badges": syndicate_unlocked_badges.duplicate()
		},
		"active_syndicate_id": active_syndicate_id,
		"syndicate_tier": syndicate_tier,
		"syndicate_fund_energy": syndicate_fund_energy,
		"syndicate_fund_angel_shares": syndicate_fund_angel_shares,
		"staff": {
			"workers": hired_workers.duplicate(true),
			"desk_levels": desk_levels.duplicate(),
			"coffee_break_active": staff_coffee_break_active or staff_hyper_focus_active,
			"coffee_break_timer": maxf(staff_coffee_break_timer, staff_hyper_focus_timer),
			"coffee_break_remaining": maxf(staff_coffee_break_remaining, staff_hyper_focus_remaining),
			"hyper_focus_active": staff_hyper_focus_active or staff_coffee_break_active,
			"hyper_focus_timer": maxf(staff_hyper_focus_timer, staff_coffee_break_timer),
			"hyper_focus_remaining": maxf(staff_hyper_focus_remaining, staff_coffee_break_remaining),
			"hyper_focus_multiplier": staff_hyper_focus_multiplier
		},
		"hired_workers": hired_workers.duplicate(true),
		"desk_levels": desk_levels.duplicate(),
		"staff_hyper_focus_timer": staff_hyper_focus_timer,
		"staff_hyper_focus_remaining": staff_hyper_focus_remaining,
		"staff_hyper_focus_active": staff_hyper_focus_active,
		"station_cooldowns": station_cooldowns.duplicate(),
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
	
	var raw_lifetime: float = float(data.get("total_lifetime_energy", total_energy_earned))
	total_lifetime_energy = total_energy_earned if (is_nan(raw_lifetime) or is_inf(raw_lifetime)) else maxf(total_energy_earned, raw_lifetime)
	
	angel_shares = maxi(0, int(data.get("angel_shares", 0)))
	total_ipos_completed = maxi(0, int(data.get("total_ipos_completed", 0)))
	
	unlocked_trophies.clear()
	var raw_trophies = data.get("unlocked_trophies", [])
	if raw_trophies is Array:
		for tr in raw_trophies:
			if tr is String and not tr.is_empty() and not unlocked_trophies.has(tr):
				unlocked_trophies.append(tr)
				
	daily_streak = maxi(0, int(data.get("daily_streak", 0)))
	last_daily_challenge_date = str(data.get("last_daily_challenge_date", ""))
	daily_board_streak = maxi(0, int(data.get("daily_board_streak", daily_streak)))
	daily_streak = daily_board_streak
	daily_board_last_login_day = int(data.get("daily_board_last_login_day", 0))
	daily_board_tasks.clear()
	var raw_board_tasks = data.get("daily_board_tasks", [])
	if raw_board_tasks is Array:
		for t in raw_board_tasks:
			if t is Dictionary:
				daily_board_tasks.append(t.duplicate(true))
	
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
		total_lifetime_energy += offline_gain

	# Phase 16 3D Campus Station Cooldowns Deserialization & Offline Decay
	station_cooldowns = {
		"server_terminal": 0.0,
		"pitch_stage": 0.0,
		"coffee_machine": 0.0
	}
	var raw_cooldowns = data.get("station_cooldowns", data.get("minigame_cooldowns", {}))
	if raw_cooldowns is Dictionary:
		for s_id in raw_cooldowns:
			var raw_cd: float = float(raw_cooldowns[s_id])
			if not is_nan(raw_cd) and not is_inf(raw_cd):
				var remaining_cd: float = maxf(0.0, raw_cd - elapsed)
				station_cooldowns[str(s_id)] = remaining_cd

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
	check_and_update_trophies()

	# Phase 13 Syndicate Deserialization
	var syn_data = data.get("syndicate", {})
	if syn_data is Dictionary and not syn_data.is_empty():
		active_syndicate_id = str(syn_data.get("active_id", data.get("active_syndicate_id", "")))
		active_syndicate_name = str(syn_data.get("name", ""))
		active_syndicate_tag = str(syn_data.get("tag", ""))
		active_syndicate_desc = str(syn_data.get("description", ""))
		active_syndicate_role = str(syn_data.get("role", "Member"))
		var raw_syn_tier: int = int(syn_data.get("tier", data.get("syndicate_tier", 0)))
		syndicate_tier = clampi(raw_syn_tier, 0, 5)
		var raw_syn_energy: float = float(syn_data.get("fund_energy", data.get("syndicate_fund_energy", 0.0)))
		syndicate_fund_energy = 0.0 if (is_nan(raw_syn_energy) or is_inf(raw_syn_energy)) else maxf(0.0, raw_syn_energy)
		syndicate_fund_angel_shares = maxi(0, int(syn_data.get("fund_angel_shares", data.get("syndicate_fund_angel_shares", 0))))
		var raw_contrib_energy: float = float(syn_data.get("energy_contributed", 0.0))
		syndicate_energy_contributed = 0.0 if (is_nan(raw_contrib_energy) or is_inf(raw_contrib_energy)) else maxf(0.0, raw_contrib_energy)
		syndicate_angel_shares_contributed = maxi(0, int(syn_data.get("angel_shares_contributed", 0)))
		syndicate_members_count = maxi(1, int(syn_data.get("members_count", 1)))
		syndicate_seasonal_score = maxi(0, int(syn_data.get("seasonal_score", 0)))
		syndicate_season_week = maxi(0, int(syn_data.get("season_week", 0)))
		syndicate_joined_timestamp = int(syn_data.get("joined_timestamp", 0))
		syndicate_unlocked_badges.clear()
		var raw_badges = syn_data.get("unlocked_badges", [])
		if raw_badges is Array:
			for b in raw_badges:
				if b is String and not b.is_empty() and not syndicate_unlocked_badges.has(b):
					syndicate_unlocked_badges.append(b)
	elif data.has("active_syndicate_id"):
		# Flat backward-compatibility fallback
		active_syndicate_id = str(data.get("active_syndicate_id", ""))
		syndicate_tier = clampi(int(data.get("syndicate_tier", 0)), 0, 5)
		var raw_syn_energy: float = float(data.get("syndicate_fund_energy", 0.0))
		syndicate_fund_energy = 0.0 if (is_nan(raw_syn_energy) or is_inf(raw_syn_energy)) else maxf(0.0, raw_syn_energy)
		syndicate_fund_angel_shares = maxi(0, int(data.get("syndicate_fund_angel_shares", 0)))

	# Phase 14 Staff & Autonomous Chibi-Worker Deserialization
	hired_workers.clear()
	desk_levels = [1, 1, 1, 1, 1]
	staff_hyper_focus_active = false
	staff_hyper_focus_timer = 0.0
	staff_hyper_focus_remaining = 0.0
	staff_hyper_focus_multiplier = 1.50
	staff_coffee_break_active = false
	staff_coffee_break_timer = 0.0
	staff_coffee_break_remaining = 0.0

	var staff_data = data.get("staff", {})
	var raw_workers = null
	var raw_desks = null
	var raw_hf_timer = null

	if staff_data is Dictionary and not staff_data.is_empty():
		raw_workers = staff_data.get("workers", null)
		raw_desks = staff_data.get("desk_levels", null)
		raw_hf_timer = staff_data.get("hyper_focus_timer", staff_data.get("coffee_break_timer", null))
		staff_hyper_focus_active = bool(staff_data.get("hyper_focus_active", staff_data.get("coffee_break_active", false)))
		staff_coffee_break_active = staff_hyper_focus_active
		var raw_hf_mult: float = float(staff_data.get("hyper_focus_multiplier", 1.50))
		staff_hyper_focus_multiplier = 1.50 if (is_nan(raw_hf_mult) or is_inf(raw_hf_mult)) else maxf(1.0, raw_hf_mult)

	# Flat backward-compatibility fallback
	if raw_workers == null:
		raw_workers = data.get("hired_workers", [])
	if raw_desks == null:
		raw_desks = data.get("desk_levels", [1, 1, 1, 1, 1])
	if raw_hf_timer == null:
		raw_hf_timer = data.get("staff_hyper_focus_timer", 0.0)

	if raw_workers is Array:
		for w in raw_workers:
			if w is Dictionary:
				var r_str: String = str(w.get("role", "")).strip_edges()
				var canon: String = _normalize_role(r_str)
				if canon.is_empty() and STAFF_ROLE_DEFINITIONS.has(r_str):
					canon = r_str
				if not canon.is_empty():
					var role_def: Dictionary = STAFF_ROLE_DEFINITIONS[canon]
					var w_id: String = str(w.get("id", "worker_" + canon.to_lower().replace(" ", "_").replace("/", "_")))
					var w_name: String = str(w.get("name", role_def.get("default_name", canon)))
					
					var raw_m: float = float(w.get("morale", 1.0))
					var clean_m: float = 1.0 if (is_nan(raw_m) or is_inf(raw_m)) else clampf(raw_m, 0.0, 1.0)
					
					var raw_f: float = float(w.get("fatigue", 0.0))
					var clean_f: float = 0.0 if (is_nan(raw_f) or is_inf(raw_f)) else clampf(raw_f, 0.0, 1.0)
					
					var raw_eff: float = float(w.get("efficiency", 1.0))
					var clean_eff: float = 1.0 if (is_nan(raw_eff) or is_inf(raw_eff)) else maxf(0.1, raw_eff)
					
					var clean_desk: int = clampi(int(w.get("desk_assigned", 0)), 0, 4)
					
					var state_str: String = str(w.get("current_state", "working"))
					if state_str not in ["working", "break", "fatigued", "celebrating"]:
						state_str = "fatigued" if clean_f >= 1.0 else "working"
						
					hired_workers.append({
						"id": w_id,
						"name": w_name,
						"role": canon,
						"morale": clean_m,
						"fatigue": clean_f,
						"efficiency": clean_eff,
						"desk_assigned": clean_desk,
						"current_state": state_str
					})

	if raw_desks is Array and raw_desks.size() > 0:
		for i in range(mini(5, raw_desks.size())):
			var raw_lvl = int(raw_desks[i])
			desk_levels[i] = clampi(raw_lvl, 1, 3)

	var hf_t: float = float(raw_hf_timer)
	if not is_nan(hf_t) and not is_inf(hf_t):
		staff_hyper_focus_timer = maxf(0.0, hf_t)
		staff_hyper_focus_remaining = staff_hyper_focus_timer
		staff_coffee_break_timer = staff_hyper_focus_timer
		staff_coffee_break_remaining = staff_hyper_focus_timer
		staff_hyper_focus_active = staff_hyper_focus_timer > 0.0
		staff_coffee_break_active = staff_hyper_focus_active
			
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
	total_lifetime_energy += amount
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

## Triggers a camera screen shake request across decoupled subscribers.
func trigger_camera_shake(amount: float) -> void:
	camera_shake_requested.emit(amount)

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

# ==============================================================================
# Phase 12 IPO ("Going Public") Prestige & Milestone Methods
# ==============================================================================

## Returns true if player meets threshold (1M lifetime energy or Unicorn Chapter 3)
## and has at least 1 pending Angel Share to claim.
func can_trigger_ipo() -> bool:
	var threshold_met: bool = (total_lifetime_energy >= IPO_ENERGY_THRESHOLD) or (campaign_chapter >= 3)
	return threshold_met and (calculate_pending_angel_shares() > 0)

## Calculates additional Angel Shares to be awarded if IPO is triggered now.
## Formula: floor(sqrt(total_lifetime_energy / 100000)) - angel_shares
func calculate_pending_angel_shares() -> int:
	if total_lifetime_energy < 100000.0:
		return 0
	var total_eligible: int = int(floor(sqrt(maxf(0.0, total_lifetime_energy) / 100000.0)))
	var base_pending: int = maxi(0, total_eligible - angel_shares)
	var bonus_pct: float = get_syndicate_ipo_bonus_percent()
	if bonus_pct > 0.0 and base_pending > 0:
		var bonus_shares: int = int(floor(float(base_pending) * bonus_pct))
		return base_pending + bonus_shares
	return base_pending

## Computes permanent global bonus multiplier (+2% per Angel Share).
func get_angel_share_multiplier() -> float:
	return 1.0 + (float(angel_shares) * 0.02)

## Executes IPO Prestige Rebirth:
## Awards pending Angel Shares, increments total_ipos_completed, unlocks trophy,
## resets regular energy, building levels, and upgrades to 0, while preserving
## angel shares, trophies, tech unlocks, campaign progress, and daily streak.
func trigger_ipo() -> Dictionary:
	if not can_trigger_ipo():
		return {
			"success": false,
			"error": "Cannot trigger IPO: threshold not reached or 0 pending shares",
			"shares_gained": 0,
			"angel_shares_gained": 0,
			"total_angel_shares": angel_shares,
			"angel_shares": angel_shares,
			"multiplier": get_angel_share_multiplier(),
			"total_ipos_completed": total_ipos_completed,
			"base_shares_gained": 0,
			"syndicate_bonus_shares": 0
		}
		
	var base_pending: int = maxi(0, int(floor(sqrt(maxf(0.0, total_lifetime_energy) / 100000.0))) - angel_shares)
	var bonus_pct: float = get_syndicate_ipo_bonus_percent()
	var bonus_shares: int = int(floor(float(base_pending) * bonus_pct)) if (bonus_pct > 0.0 and base_pending > 0) else 0
	var shares_gained: int = base_pending + bonus_shares
	if shares_gained <= 0:
		return {
			"success": false,
			"error": "No pending angel shares to claim",
			"shares_gained": 0,
			"angel_shares_gained": 0,
			"total_angel_shares": angel_shares,
			"angel_shares": angel_shares,
			"multiplier": get_angel_share_multiplier(),
			"total_ipos_completed": total_ipos_completed,
			"base_shares_gained": 0,
			"syndicate_bonus_shares": 0
		}

	# 1. Award Angel Shares and update stats
	angel_shares += shares_gained
	total_ipos_completed += 1
	
	# 2. Unlock Platin-Börsenbulle Trophy (Trophy #4)
	unlock_trophy("trophy_platinum_bull")
	
	# 3. Reset regular energy currency
	energy = 0.0
	
	# 4. Reset building levels & standard upgrades to baseline
	for up_id in DEFAULT_UPGRADES:
		if not upgrades.has(up_id):
			upgrades[up_id] = DEFAULT_UPGRADES[up_id].duplicate(true)
		else:
			var base_cost: float = float(DEFAULT_UPGRADES[up_id]["base_cost"])
			upgrades[up_id]["level"] = 0
			upgrades[up_id]["current_cost"] = base_cost
		
	# 5. Clear active temporary buffs & timers
	frenzy_meter = 0.0
	is_frenzy_active = false
	frenzy_multiplier = 1.0
	frenzy_duration_remaining = 0.0
	
	server_overclock_buff_timer = 0.0
	server_overclock_buff_multiplier = 1.0
	server_overclock_buff_active = false
	server_overclock_buff_remaining = 0.0
	
	campaign_rps_buff_timer = 0.0
	campaign_rps_buff_multiplier = 1.0
	campaign_speed_buff_timer = 0.0
	campaign_speed_buff_multiplier = 1.0
	
	unicorn_espresso_buff_active = false
	unicorn_espresso_buff_timer = 0.0
	unicorn_espresso_buff_remaining = 0.0
	
	# Phase 14 Staff Temporary Buff Reset on IPO
	staff_hyper_focus_active = false
	staff_hyper_focus_timer = 0.0
	staff_hyper_focus_remaining = 0.0
	staff_coffee_break_active = false
	staff_coffee_break_timer = 0.0
	staff_coffee_break_remaining = 0.0
	for w in hired_workers:
		if str(w.get("current_state", "")) == "break":
			w["current_state"] = "working"

	# Phase 16 Station Cooldown Reset on IPO
	for s_id in station_cooldowns.keys():
		station_cooldowns[s_id] = 0.0
		station_cooldown_ended.emit(s_id)
	
	# 6. Recalculate stats from reset levels
	recalculate_stats()
	
	# 7. Persist to disk
	save_to_disk()
	
	# 8. Emit notification signals
	energy_changed.emit(energy, 0.0)
	rps_changed.emit(get_effective_passive_rps())
	frenzy_updated.emit(frenzy_multiplier, 0.0)
	angel_shares_changed.emit(angel_shares, shares_gained)
	ipo_completed.emit(shares_gained, angel_shares, get_angel_share_multiplier())
	
	return {
		"success": true,
		"shares_gained": shares_gained,
		"angel_shares_gained": shares_gained,
		"total_angel_shares": angel_shares,
		"angel_shares": angel_shares,
		"multiplier": get_angel_share_multiplier(),
		"total_ipos_completed": total_ipos_completed,
		"base_shares_gained": base_pending,
		"syndicate_bonus_shares": bonus_shares
	}

## Unlocks a milestone trophy if not already unlocked.
func unlock_trophy(trophy_id: String) -> bool:
	if trophy_id.is_empty() or unlocked_trophies.has(trophy_id):
		return false
	unlocked_trophies.append(trophy_id)
	trophy_unlocked.emit(trophy_id)
	save_to_disk()
	return true

## Checks if a trophy is unlocked.
func is_trophy_unlocked(trophy_id: String) -> bool:
	return unlocked_trophies.has(trophy_id)

## Returns copy of unlocked trophies array.
func get_unlocked_trophies() -> Array[String]:
	return unlocked_trophies.duplicate()

## Automatically checks campaign & prestige milestones to retroactively unlock trophies.
func check_and_update_trophies() -> void:
	if (campaign_chapter >= 2 or campaign_completed_quests.has("quest_briefcases")) and not unlocked_trophies.has("trophy_golden_briefcase"):
		unlocked_trophies.append("trophy_golden_briefcase")
		trophy_unlocked.emit("trophy_golden_briefcase")
	if (campaign_chapter >= 3 or campaign_completed_quests.has("quest_server")) and not unlocked_trophies.has("trophy_server_matrix"):
		unlocked_trophies.append("trophy_server_matrix")
	if (campaign_chapter >= 4 or campaign_completed_quests.has("quest_lab")) and not unlocked_trophies.has("trophy_crystal_espresso"):
		unlocked_trophies.append("trophy_crystal_espresso")
	if total_ipos_completed > 0 and not unlocked_trophies.has("trophy_platinum_bull"):
		unlocked_trophies.append("trophy_platinum_bull")
		trophy_unlocked.emit("trophy_platinum_bull")

# ==============================================================================
# Phase 12 M4 Daily Challenge Board & Streak Engine Methods
# ==============================================================================

## Returns the array of 3 active daily tasks, rotating if the calendar day has advanced.
func get_daily_tasks() -> Array[Dictionary]:
	var current_day: int = int(Time.get_unix_time_from_system() / 86400)
	if daily_board_tasks.is_empty() or daily_board_last_login_day == 0 or current_day != daily_board_last_login_day:
		_rotate_daily_tasks(current_day)
	return daily_board_tasks

## Forces a refresh / rotation for a specified day (or current system day if < 0).
func refresh_daily_tasks(forced_day: int = -1) -> Array[Dictionary]:
	var target_day: int = forced_day if forced_day >= 0 else int(Time.get_unix_time_from_system() / 86400)
	_rotate_daily_tasks(target_day)
	return daily_board_tasks

## Internal rotation logic using day index to deterministically pick 3 tasks and check streak continuity.
func _rotate_daily_tasks(current_day: int) -> void:
	if daily_board_last_login_day > 0:
		if current_day == daily_board_last_login_day + 1:
			# Consecutive day login: preserve existing streak
			pass
		elif current_day > daily_board_last_login_day + 1:
			# Missed one or more days: reset streak to 0
			daily_board_streak = 0
			daily_streak = 0
			daily_streak_updated.emit(daily_board_streak)
	
	daily_board_last_login_day = current_day
	daily_board_tasks.clear()
	
	var offset: int = posmod(current_day, DAILY_TASK_KEYS.size())
	for i in range(3):
		var key: String = DAILY_TASK_KEYS[(offset + i) % DAILY_TASK_KEYS.size()]
		var template: Dictionary = DAILY_TASK_CATALOG[key]
		daily_board_tasks.append({
			"id": key,
			"title": template["title"],
			"description": template["description"],
			"target": int(template["target"]),
			"current": 0,
			"is_completed": false,
			"is_claimed": false,
			"reward": template["reward"].duplicate(true)
		})
	daily_tasks_updated.emit(daily_board_tasks)
	save_to_disk()

## Advances progress on an active daily task by amount (default 1).
func advance_daily_task(task_id: String, amount: int = 1) -> void:
	if amount <= 0:
		return
	if daily_board_tasks.is_empty():
		get_daily_tasks()
	var updated: bool = false
	for task in daily_board_tasks:
		if task.get("id") == task_id:
			var target_val: int = int(task.get("target", 1))
			var current_val: int = int(task.get("current", 0))
			if current_val < target_val:
				task["current"] = mini(target_val, current_val + amount)
				if task["current"] >= target_val:
					task["is_completed"] = true
				updated = true
			break
	if updated:
		daily_tasks_updated.emit(daily_board_tasks)
		save_to_disk()

## Claims reward for a completed daily task, pays out reward, and updates streak if all 3 are claimed.
func claim_daily_task(task_id: String) -> Dictionary:
	if daily_board_tasks.is_empty():
		get_daily_tasks()
	var found_task: Dictionary = {}
	for task in daily_board_tasks:
		if task.get("id") == task_id:
			found_task = task
			break
	if found_task.is_empty():
		return {"success": false, "error": "Task not found"}
	if not found_task.get("is_completed", false):
		return {"success": false, "error": "Task not completed yet"}
	if found_task.get("is_claimed", false):
		return {"success": false, "error": "Task already claimed"}
		
	found_task["is_claimed"] = true
	var reward: Dictionary = found_task.get("reward", {})
	
	# Payout rewards
	if reward.has("energy"):
		earn_energy(float(reward["energy"]))
	if reward.has("angel_shares"):
		angel_shares += int(reward["angel_shares"])
		angel_shares_changed.emit(angel_shares, int(reward["angel_shares"]))
	if reward.has("rps_buff"):
		activate_campaign_rps_buff(float(reward.get("rps_buff", 2.0)), float(reward.get("duration", 45.0)))
	if reward.has("speed_buff"):
		activate_campaign_speed_buff(float(reward.get("speed_buff", 1.5)), float(reward.get("duration", 30.0)))
		
	# Check if all 3 tasks are claimed
	var all_claimed: bool = true
	for t in daily_board_tasks:
		if not t.get("is_claimed", false):
			all_claimed = false
			break
	if all_claimed:
		daily_board_streak += 1
		daily_streak = daily_board_streak
		daily_streak_updated.emit(daily_board_streak)
		
	daily_task_claimed.emit(task_id, reward)
	daily_tasks_updated.emit(daily_board_tasks)
	save_to_disk()
	
	return {
		"success": true,
		"task_id": task_id,
		"reward": reward,
		"streak": daily_board_streak,
		"all_claimed": all_claimed
	}

## Returns the current daily streak counter.
func get_daily_streak() -> int:
	return daily_board_streak

# ==============================================================================
# Phase 13 Syndicate / Gilden-Wirtschaft & Holdings Methods
# ==============================================================================

## Returns true if player is currently affiliated with an active syndicate.
func is_in_syndicate() -> bool:
	return not active_syndicate_id.is_empty()

## Returns current syndicate tier (0 if unaffiliated, 1-5 otherwise).
func get_syndicate_tier() -> int:
	return syndicate_tier if is_in_syndicate() else 0

## Returns tier bonuses dictionary for current syndicate tier.
func get_syndicate_bonuses() -> Dictionary:
	var t: int = get_syndicate_tier()
	var cfg = SYNDICATE_TIER_CONFIG.get(t, SYNDICATE_TIER_CONFIG[0])
	return {
		"tier": t,
		"name": cfg.get("name", "Unaffiliated"),
		"dividend_pct": float(cfg.get("dividend_pct", 0.0)),
		"dividend_multiplier": float(cfg.get("dividend_mult", 1.0)),
		"dividend_mult": float(cfg.get("dividend_mult", 1.0)),
		"drone_speed_pct": float(cfg.get("drone_speed_pct", 0.0)),
		"drone_speed_multiplier": float(cfg.get("drone_speed_mult", 1.0)),
		"drone_speed_mult": float(cfg.get("drone_speed_mult", 1.0)),
		"bonus_angel_shares_pct": float(cfg.get("ipo_bonus_shares_pct", 0.0)),
		"bonus_angel_shares_multiplier": float(cfg.get("ipo_bonus_shares_mult", 1.0)),
		"ipo_bonus_shares_pct": float(cfg.get("ipo_bonus_shares_pct", 0.0)),
		"ipo_bonus_shares_mult": float(cfg.get("ipo_bonus_shares_mult", 1.0))
	}

## Returns active syndicate details dictionary.
func get_active_syndicate() -> Dictionary:
	return {
		"id": active_syndicate_id,
		"name": active_syndicate_name,
		"tag": active_syndicate_tag,
		"description": active_syndicate_desc,
		"role": active_syndicate_role,
		"tier": get_syndicate_tier(),
		"fund_energy": syndicate_fund_energy,
		"fund_angel_shares": syndicate_fund_angel_shares,
		"energy_contributed": syndicate_energy_contributed,
		"angel_shares_contributed": syndicate_angel_shares_contributed,
		"members_count": syndicate_members_count,
		"seasonal_score": syndicate_seasonal_score,
		"season_week": syndicate_season_week,
		"unlocked_badges": syndicate_unlocked_badges.duplicate(),
		"bonuses": get_syndicate_bonuses(),
		"is_active": is_in_syndicate()
	}

## Computes global syndicate dividend multiplier on passive RPS (+5% per tier up to +25%).
func get_syndicate_dividend_multiplier() -> float:
	var t: int = get_syndicate_tier()
	if t <= 0:
		return 1.0
	return 1.0 + (float(t) * 0.05)

## Returns drone collection speed multiplier (+15% when tier >= 2).
func get_drone_speed_multiplier() -> float:
	return 1.15 if get_syndicate_tier() >= 2 else 1.0

## Returns bonus percentage for angel shares on IPO (+5% at T3, +10% at T4, +15% at T5).
func get_syndicate_ipo_bonus_percent() -> float:
	var t: int = get_syndicate_tier()
	if t < 3:
		return 0.0
	return float(t - 2) * 0.05

## Founds a new syndicate, setting the player as Founder.
func found_syndicate(id: String, name: String, tag: String = "", description: String = "") -> Dictionary:
	if not active_syndicate_id.is_empty() and active_syndicate_id != id:
		return {"success": false, "error": "Already affiliated with a syndicate: " + active_syndicate_id}
	
	var final_id: String = id.strip_edges()
	if final_id.is_empty():
		final_id = "syn_" + str(Time.get_unix_time_from_system())
		
	active_syndicate_id = final_id
	active_syndicate_name = name.strip_edges() if not name.strip_edges().is_empty() else "Enterprise Syndicate"
	active_syndicate_tag = tag.strip_edges() if not tag.strip_edges().is_empty() else "SYN"
	active_syndicate_desc = description.strip_edges()
	active_syndicate_role = "Founder"
	if syndicate_tier == 0:
		syndicate_tier = 1
	syndicate_members_count = maxi(1, syndicate_members_count)
	syndicate_joined_timestamp = int(Time.get_unix_time_from_system())
	
	syndicate_seasonal_score = calculate_seasonal_score()
	recalculate_stats()
	save_to_disk()
	
	rps_changed.emit(get_effective_passive_rps())
	syndicate_joined.emit(get_active_syndicate())
	
	return {
		"success": true,
		"syndicate": get_active_syndicate()
	}

## Joins an existing syndicate by ID.
func join_syndicate(id: String, name: String = "", tag: String = "", description: String = "") -> bool:
	if id.strip_edges().is_empty():
		return false
		
	active_syndicate_id = id.strip_edges()
	if not name.strip_edges().is_empty():
		active_syndicate_name = name.strip_edges()
	elif active_syndicate_name.is_empty():
		active_syndicate_name = "Enterprise Syndicate"
		
	if not tag.strip_edges().is_empty():
		active_syndicate_tag = tag.strip_edges()
	elif active_syndicate_tag.is_empty():
		active_syndicate_tag = "SYN"
		
	if not description.strip_edges().is_empty():
		active_syndicate_desc = description.strip_edges()
		
	active_syndicate_role = "Member"
		
	if syndicate_tier == 0:
		syndicate_tier = 1
		
	syndicate_joined_timestamp = int(Time.get_unix_time_from_system())
	syndicate_seasonal_score = calculate_seasonal_score()
	recalculate_stats()
	save_to_disk()
	
	rps_changed.emit(get_effective_passive_rps())
	syndicate_joined.emit(get_active_syndicate())
	return true

## Leaves current syndicate and resets perks to baseline.
func leave_syndicate() -> bool:
	if active_syndicate_id.is_empty():
		return false
		
	active_syndicate_id = ""
	active_syndicate_name = ""
	active_syndicate_tag = ""
	active_syndicate_desc = ""
	active_syndicate_role = "Member"
	syndicate_tier = 0
	syndicate_fund_energy = 0.0
	syndicate_fund_angel_shares = 0
	syndicate_energy_contributed = 0.0
	syndicate_angel_shares_contributed = 0
	syndicate_seasonal_score = 0
	
	recalculate_stats()
	save_to_disk()
	
	rps_changed.emit(get_effective_passive_rps())
	syndicate_left.emit()
	return true

## Contributes energy or angel shares to the syndicate fund.
func contribute_to_syndicate(amount: float, resource_type: String = "energy") -> Dictionary:
	if not is_in_syndicate():
		return {"success": false, "error": "Not affiliated with any syndicate"}
	if amount <= 0.0:
		return {"success": false, "error": "Contribution amount must be greater than zero"}
		
	var clean_type: String = resource_type.to_lower().strip_edges()
	if clean_type == "energy":
		if energy < amount:
			return {"success": false, "error": "Insufficient energy (available: %f, required: %f)" % [energy, amount]}
		energy -= amount
		syndicate_fund_energy += amount
		syndicate_energy_contributed += amount
		energy_changed.emit(energy, -amount)
	elif clean_type in ["angel_shares", "shares"]:
		var shares_int: int = int(amount)
		if shares_int <= 0:
			return {"success": false, "error": "Must contribute at least 1 Angel Share"}
		if angel_shares < shares_int:
			return {"success": false, "error": "Insufficient angel shares (available: %d, required: %d)" % [angel_shares, shares_int]}
		angel_shares -= shares_int
		syndicate_fund_angel_shares += shares_int
		syndicate_angel_shares_contributed += shares_int
		angel_shares_changed.emit(angel_shares, -shares_int)
	else:
		return {"success": false, "error": "Invalid resource type '%s'. Use 'energy' or 'angel_shares'." % resource_type}
		
	# Check for tier progression
	var prev_tier: int = syndicate_tier
	check_syndicate_tier_progression()
	if syndicate_tier > prev_tier:
		syndicate_tier_upgraded.emit(syndicate_tier, get_syndicate_bonuses())
		
	syndicate_seasonal_score = calculate_seasonal_score()
	syndicate_season_updated.emit(syndicate_season_week, syndicate_seasonal_score)
	
	recalculate_stats()
	rps_changed.emit(get_effective_passive_rps())
	syndicate_contributed.emit(clean_type, amount, syndicate_fund_energy, syndicate_tier)
	save_to_disk()
	
	return {
		"success": true,
		"resource_type": clean_type,
		"amount": amount,
		"tier": syndicate_tier,
		"fund_energy": syndicate_fund_energy,
		"fund_angel_shares": syndicate_fund_angel_shares,
		"seasonal_score": syndicate_seasonal_score,
		"bonuses": get_syndicate_bonuses()
	}

## Contributes angel shares to syndicate vault.
func contribute_angel_shares_to_syndicate(shares: int) -> Dictionary:
	return contribute_to_syndicate(float(shares), "angel_shares")

## Evaluates vault funds and advances tier if threshold is reached.
func check_syndicate_tier_progression() -> int:
	if not is_in_syndicate():
		syndicate_tier = 0
		return 0
	for t in [5, 4, 3, 2, 1]:
		var cfg = SYNDICATE_TIER_CONFIG[t]
		if syndicate_fund_energy >= float(cfg.req_energy) or syndicate_fund_angel_shares >= int(cfg.req_shares):
			if t > syndicate_tier:
				syndicate_tier = t
			break
	return syndicate_tier

## Calculates weekly seasonal leaderboard score.
func calculate_seasonal_score(fund_energy: float = -1.0, fund_shares: int = -1, tier: int = -1) -> int:
	var e: float = fund_energy if fund_energy >= 0.0 else syndicate_fund_energy
	var s: int = fund_shares if fund_shares >= 0 else syndicate_fund_angel_shares
	var t: int = tier if tier >= 0 else syndicate_tier
	return int(floor(maxf(0.0, e) / 100.0)) + (maxi(0, s) * 500) + (maxi(0, t) * 1000)

## Returns current seasonal score and manages weekly seasonal rotation.
func get_seasonal_leaderboard_score() -> int:
	var current_week: int = int(Time.get_unix_time_from_system() / (86400 * 7))
	if syndicate_season_week == 0:
		syndicate_season_week = current_week
	elif current_week > syndicate_season_week:
		if syndicate_seasonal_score >= 10000 and not syndicate_unlocked_badges.has("badge_syndicate_champion"):
			syndicate_unlocked_badges.append("badge_syndicate_champion")
		syndicate_season_week = current_week
	syndicate_seasonal_score = calculate_seasonal_score()
	return syndicate_seasonal_score

## Returns dictionary of all tier configurations.
func get_syndicate_tier_definitions() -> Dictionary:
	return SYNDICATE_TIER_CONFIG.duplicate(true)

# ==============================================================================
# Phase 14 Staff Management & Morale Economy Methods ("Campus Office & Mini-Workers")
# ==============================================================================

## Normalizes role string to canonical staff role definition key.
func _normalize_role(role_name: String) -> String:
	var clean: String = role_name.strip_edges()
	for def_role in STAFF_ROLE_DEFINITIONS:
		if clean.nocasecmp_to(def_role) == 0:
			return def_role
		var simplified: String = def_role.to_lower().replace(" ", "_").replace("/", "_")
		var input_simplified: String = clean.to_lower().replace(" ", "_").replace("/", "_")
		if simplified == input_simplified:
			return def_role
	return ""

## Recruits a specialist worker by role name. Deducts hire_cost, assigns first free desk, and emits signals.
func hire_worker(role: String) -> bool:
	var canonical_role: String = _normalize_role(role)
	if canonical_role.is_empty():
		printerr("[GameState] Cannot hire worker: unknown role '%s'" % role)
		return false
	if hired_workers.size() >= MAX_WORKERS:
		printerr("[GameState] Cannot hire worker: max capacity reached (%d)" % MAX_WORKERS)
		return false
	for w in hired_workers:
		if str(w.get("role", "")) == canonical_role:
			printerr("[GameState] Cannot hire worker: role '%s' already hired" % canonical_role)
			return false
			
	var role_def: Dictionary = STAFF_ROLE_DEFINITIONS[canonical_role]
	var cost: float = float(role_def.get("hire_cost", 500.0))
	if energy < cost:
		printerr("[GameState] Cannot hire worker: insufficient energy (cost: %f, energy: %f)" % [cost, energy])
		return false
		
	# Find first unoccupied desk (0..4)
	var occupied_desks: Array = []
	for w in hired_workers:
		occupied_desks.append(int(w.get("desk_assigned", 0)))
	var chosen_desk: int = -1
	for d in range(MAX_WORKERS):
		if not occupied_desks.has(d):
			chosen_desk = d
			break
	if chosen_desk == -1:
		chosen_desk = 0
		
	energy -= cost
	energy_changed.emit(energy, -cost)
	
	var worker_id: String = "worker_" + canonical_role.to_lower().replace(" ", "_").replace("/", "_")
	var new_worker: Dictionary = {
		"id": worker_id,
		"name": str(role_def.get("default_name", canonical_role)),
		"role": canonical_role,
		"morale": 1.0,
		"fatigue": 0.0,
		"efficiency": 1.0,
		"desk_assigned": chosen_desk,
		"current_state": "working"
	}
	
	hired_workers.append(new_worker)
	staff_worker_hired.emit(new_worker.duplicate(true))
	worker_hired.emit(new_worker.duplicate(true))
	staff_worker_state_changed.emit(worker_id, "working")
	
	staff_morale_updated.emit(get_staff_average_morale())
	rps_changed.emit(get_effective_passive_rps())
	staff_bonus_updated.emit(get_staff_rps_multiplier(), get_active_workers_count(), get_staff_average_morale())
	save_to_disk()
	return true

## Dismisses a worker by worker_id or role name. Frees desk, emits signals, and recalculates RPS.
func fire_worker(worker_id: String) -> bool:
	if worker_id.is_empty():
		return false
	var target_index: int = -1
	var found_id: String = ""
	var norm: String = _normalize_role(worker_id)
	for i in range(hired_workers.size()):
		var w = hired_workers[i]
		if str(w.get("id", "")) == worker_id or str(w.get("role", "")) == worker_id or (!norm.is_empty() and str(w.get("role", "")) == norm):
			target_index = i
			found_id = str(w.get("id", worker_id))
			break
	if target_index == -1:
		return false
		
	hired_workers.remove_at(target_index)
	staff_worker_fired.emit(found_id)
	worker_fired.emit(found_id)
	
	staff_morale_updated.emit(get_staff_average_morale())
	rps_changed.emit(get_effective_passive_rps())
	staff_bonus_updated.emit(get_staff_rps_multiplier(), get_active_workers_count(), get_staff_average_morale())
	save_to_disk()
	return true

## Returns duplicate array of all active hired worker dictionaries.
func get_hired_workers() -> Array:
	return hired_workers.duplicate(true)

## Returns worker dictionary by worker_id or role, or empty dictionary if not found.
func get_worker(worker_id: String) -> Dictionary:
	var norm: String = _normalize_role(worker_id)
	for w in hired_workers:
		if str(w.get("id", "")) == worker_id or str(w.get("role", "")) == worker_id or (!norm.is_empty() and str(w.get("role", "")) == norm):
			return w.duplicate(true)
	return {}

## Returns count of hired workers currently active (not fatigued).
func get_active_workers_count() -> int:
	var count: int = 0
	for w in hired_workers:
		if str(w.get("current_state", "working")) != "fatigued":
			count += 1
	return count

## Returns mean average morale across all hired workers (1.0 if empty).
func get_staff_average_morale() -> float:
	if hired_workers.is_empty():
		return 1.0
	var total_morale: float = 0.0
	for w in hired_workers:
		total_morale += clampf(float(w.get("morale", 1.0)), 0.0, 1.0)
	return total_morale / float(hired_workers.size())

## Alias for get_staff_average_morale.
func get_average_worker_morale() -> float:
	return get_staff_average_morale()

## Upgrades desk at desk_index (0..4) to next level (max Level 3). Deducts energy and emits signals.
func upgrade_desk(desk_index: int) -> bool:
	if desk_index < 0 or desk_index >= MAX_WORKERS or desk_index >= desk_levels.size():
		return false
	var current_lvl: int = desk_levels[desk_index]
	if current_lvl >= MAX_DESK_LEVEL:
		return false
	var next_lvl: int = current_lvl + 1
	var cost: float = float(DESK_CONFIG.get(next_lvl, {}).get("cost", 5000.0))
	if energy < cost:
		return false
		
	energy -= cost
	energy_changed.emit(energy, -cost)
	desk_levels[desk_index] = next_lvl
	staff_desk_upgraded.emit(desk_index, next_lvl)
	desk_upgraded.emit(desk_index, next_lvl, cost)
	save_to_disk()
	return true

## Returns level of desk at desk_index (1..3).
func get_desk_level(desk_index: int) -> int:
	if desk_index >= 0 and desk_index < desk_levels.size():
		return desk_levels[desk_index]
	return 1

## Returns duplicate array of all desk levels [L0, L1, L2, L3, L4].
func get_desk_levels() -> Array:
	return desk_levels.duplicate()

## Returns the energy cost to upgrade desk_index to its next tier (0.0 if maxed/invalid).
func get_desk_upgrade_cost(desk_index: int) -> float:
	if desk_index < 0 or desk_index >= desk_levels.size():
		return 0.0
	var current_lvl: int = desk_levels[desk_index]
	if current_lvl >= MAX_DESK_LEVEL:
		return 0.0
	var next_lvl: int = current_lvl + 1
	return float(DESK_CONFIG.get(next_lvl, {}).get("cost", 0.0))

## Returns fatigue accumulation rate multiplier for a given desk level (1.0 for L1, 0.75 for L2, 0.40 for L3).
func get_desk_fatigue_multiplier(desk_level: int) -> float:
	if desk_level == 2:
		return 0.75
	elif desk_level >= 3:
		return 0.40
	return 1.00

## Grants a team coffee break: resets fatigue to 0.0, restores morale to 1.0, engages 60s Hyper-Focus (+50% speed).
func give_team_coffee_break() -> bool:
	for w in hired_workers:
		w["fatigue"] = 0.0
		w["morale"] = 1.0
		w["current_state"] = "working"
		staff_worker_state_changed.emit(str(w.get("id", "")), "working")
		worker_state_changed.emit(str(w.get("id", "")), "working")
		staff_worker_morale_updated.emit(str(w.get("id", "")), 1.0, 0.0)
		
	staff_hyper_focus_active = true
	staff_hyper_focus_timer = 60.0
	staff_hyper_focus_remaining = 60.0
	staff_hyper_focus_multiplier = 1.50
	staff_coffee_break_active = true
	staff_coffee_break_timer = 60.0
	staff_coffee_break_remaining = 60.0
	
	staff_coffee_break_started.emit(60.0)
	team_coffee_break_started.emit(60.0, 1.50)
	staff_morale_updated.emit(get_staff_average_morale())
	rps_changed.emit(get_effective_passive_rps())
	staff_bonus_updated.emit(get_staff_rps_multiplier(), get_active_workers_count(), get_staff_average_morale())
	save_to_disk()
	return true

## Returns true if team coffee break hyper-focus is currently active.
func is_staff_hyper_focus_active() -> bool:
	return (staff_hyper_focus_active or staff_coffee_break_active) and (staff_hyper_focus_timer > 0.0 or staff_coffee_break_timer > 0.0)

## Returns remaining seconds of active hyper-focus.
func get_staff_hyper_focus_time_remaining() -> float:
	return maxf(0.0, maxf(staff_hyper_focus_timer, staff_coffee_break_timer))

## Returns current hyper-focus speed multiplier (1.50 when active, 1.0 otherwise).
func get_staff_hyper_focus_multiplier() -> float:
	return staff_hyper_focus_multiplier if is_staff_hyper_focus_active() else 1.0

## Calculates staff bonus multiplier: 1.0 + (active_workers * 0.05) * average_morale (strictly 1.0 if no active workers).
func get_staff_rps_multiplier() -> float:
	if hired_workers.is_empty():
		return 1.0
	var active_count: int = get_active_workers_count()
	if active_count <= 0:
		return 1.0
	var avg_morale: float = get_staff_average_morale()
	return 1.0 + (float(active_count) * 0.05) * avg_morale

## Triggers an epiphany moment reward for worker, awarding instant energy lump-sum.
func trigger_worker_epiphany(worker_id: String) -> float:
	var target_id: String = worker_id
	var found: bool = false
	for w in hired_workers:
		if str(w.get("id", "")) == worker_id or str(w.get("role", "")) == worker_id:
			target_id = str(w.get("id", worker_id))
			found = true
			break
	if not found:
		if hired_workers.is_empty():
			return 0.0
		target_id = str(hired_workers[0].get("id", worker_id))
		
	var reward: float = maxf(100.0, get_effective_passive_rps() * 15.0)
	earn_energy(reward)
	staff_epiphany_triggered.emit(target_id, reward)
	epiphany_collected.emit(target_id, reward)
	save_to_disk()
	return reward

## Alias for trigger_worker_epiphany.
func trigger_epiphany(worker_id: String) -> float:
	return trigger_worker_epiphany(worker_id)

## Advances staff fatigue, morale, and states by simulated delta seconds.
func update_staff_simulation(delta: float) -> void:
	if delta <= 0.0 or hired_workers.is_empty():
		return
		
	var any_state_change: bool = false
	var any_morale_change: bool = false
	var total_morale: float = 0.0
	
	for w in hired_workers:
		var current_state: String = str(w.get("current_state", "working"))
		var desk_idx: int = clampi(int(w.get("desk_assigned", 0)), 0, MAX_WORKERS - 1)
		var desk_lvl: int = get_desk_level(desk_idx)
		var fatigue_mult: float = get_desk_fatigue_multiplier(desk_lvl)
		var current_fatigue: float = clampf(float(w.get("fatigue", 0.0)), 0.0, 1.0)
		var current_morale: float = clampf(float(w.get("morale", 1.0)), 0.0, 1.0)
		
		if current_state == "working":
			# 1. Fatigue accumulation (+0.02 / min * desk multiplier)
			var f_delta: float = BASE_WORKER_FATIGUE_RATE_PER_SECOND * fatigue_mult * delta
			var new_fatigue: float = clampf(current_fatigue + f_delta, 0.0, 1.0)
			if new_fatigue != current_fatigue:
				current_fatigue = new_fatigue
				w["fatigue"] = current_fatigue
				
			# 2. Morale decay when fatigue >= 0.8
			if current_fatigue >= 0.8:
				var m_delta: float = BASE_WORKER_MORALE_DECAY_RATE_PER_SECOND * delta
				var new_morale: float = clampf(current_morale - m_delta, 0.0, 1.0)
				if new_morale != current_morale:
					current_morale = new_morale
					w["morale"] = current_morale
					any_morale_change = true
					staff_worker_morale_updated.emit(str(w.get("id", "")), current_morale, current_fatigue)
					
			# 3. Transition to fatigued when fatigue reaches 1.0
			if current_fatigue >= 1.0:
				w["current_state"] = "fatigued"
				any_state_change = true
				staff_worker_state_changed.emit(str(w.get("id", "")), "fatigued")
				worker_state_changed.emit(str(w.get("id", "")), "fatigued")
		elif current_state == "fatigued":
			# Continuous morale decay while exhausted
			var m_delta: float = BASE_WORKER_MORALE_DECAY_RATE_PER_SECOND * delta
			var new_morale: float = clampf(current_morale - m_delta, 0.0, 1.0)
			if new_morale != current_morale:
				current_morale = new_morale
				w["morale"] = current_morale
				any_morale_change = true
				staff_worker_morale_updated.emit(str(w.get("id", "")), current_morale, current_fatigue)
				
		total_morale += current_morale
		
	if any_morale_change:
		var avg_morale: float = total_morale / float(hired_workers.size())
		staff_morale_updated.emit(avg_morale)
		rps_changed.emit(get_effective_passive_rps())
		staff_bonus_updated.emit(get_staff_rps_multiplier(), get_active_workers_count(), avg_morale)
	elif any_state_change:
		rps_changed.emit(get_effective_passive_rps())
		staff_bonus_updated.emit(get_staff_rps_multiplier(), get_active_workers_count(), get_staff_average_morale())

## Returns duplicate of staff role definitions dictionary.
func get_staff_role_definitions() -> Dictionary:
	return STAFF_ROLE_DEFINITIONS.duplicate(true)

## Returns duplicate of desk configuration dictionary.
func get_desk_definitions() -> Dictionary:
	return DESK_CONFIG.duplicate(true)






