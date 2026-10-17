extends Node

## LiveEventManager singleton for IdleArcade (Phase 13 Milestone M4).
## Manages cooperative live-campus crises, collective milestone contribution,
## dynamic countdown timers, and campus-wide reward multipliers.

enum EventState {
	IDLE,
	ACTIVE,
	COMPLETED,
	COOLDOWN
}

# --- Signals (Interface Contract) ---
signal live_event_started(event_id: String, event_name: String, duration: float, target_goal: float)
signal live_event_progress_updated(current: float, target: float, percentage: float)
signal live_event_milestone_reached(milestone_pct: float, milestone_name: String)
signal live_event_completed(event_id: String, reward_data: Dictionary)
signal live_event_ended(event_id: String)

# --- Event Catalog ---
const EVENT_CATALOG: Dictionary = {
	"server_crash_crisis": {
		"id": "server_crash_crisis",
		"title": "Server Crash Crisis",
		"description": "Server mainframe under siege! Tap Core and Overclock Terminals to stabilize!",
		"duration": 600.0,
		"target": 500.0,
		"contribution_weights": {
			"click": 1.0,
			"overclock": 50.0
		},
		"milestones": [25.0, 50.0, 75.0, 100.0],
		"reward_type": "production_buff",
		"reward_multiplier": 2.0,
		"reward_duration": 180.0,
		"reward_description": "Global 2x All Production buff for 180 seconds"
	},
	"angel_investor_summit": {
		"id": "angel_investor_summit",
		"title": "Angel Investor Summit",
		"description": "Venture capitalists are touring campus! Collect Briefcases across campus!",
		"duration": 480.0,
		"target": 20.0,
		"contribution_weights": {
			"briefcase": 1.0
		},
		"milestones": [25.0, 50.0, 75.0, 100.0],
		"reward_type": "grant_and_drone_speed",
		"reward_energy": 50000.0,
		"drone_speed_multiplier": 1.5,
		"reward_duration": 120.0,
		"reward_description": "+50,000 Energy grant and 1.5x Drone Speed boost for 120 seconds"
	}
}

# --- State Variables ---
var current_state: EventState = EventState.IDLE
var active_event_id: String = ""
var current_progress: float = 0.0
var target_goal: float = 0.0
var time_remaining: float = 0.0
var reward_time_remaining: float = 0.0
var cooldown_time_remaining: float = 0.0
var default_cooldown: float = 30.0

var current_production_multiplier: float = 1.0
var current_drone_speed_multiplier: float = 1.0
var reached_milestones: Array[float] = []

func _ready() -> void:
	add_to_group("live_event_managers")

func _process(delta: float) -> void:
	var safe_delta: float = minf(0.1, delta)
	
	match current_state:
		EventState.ACTIVE:
			time_remaining -= safe_delta
			if time_remaining <= 0.0:
				time_remaining = 0.0
				_end_event(false)
				
		EventState.COMPLETED:
			reward_time_remaining -= safe_delta
			if reward_time_remaining <= 0.0:
				reward_time_remaining = 0.0
				_finish_rewards_and_cooldown()
				
		EventState.COOLDOWN:
			cooldown_time_remaining -= safe_delta
			if cooldown_time_remaining <= 0.0:
				cooldown_time_remaining = 0.0
				current_state = EventState.IDLE

# ==============================================================================
# Public API Methods
# ==============================================================================

## Starts a live event from the catalog by ID. Returns true if successfully started.
func start_event(event_id: String) -> bool:
	if not EVENT_CATALOG.has(event_id):
		push_warning("LiveEventManager: Unknown event_id '%s'" % event_id)
		return false
		
	var def: Dictionary = EVENT_CATALOG[event_id]
	active_event_id = event_id
	current_state = EventState.ACTIVE
	target_goal = float(def.get("target", 100.0))
	time_remaining = float(def.get("duration", 600.0))
	current_progress = 0.0
	reward_time_remaining = 0.0
	cooldown_time_remaining = 0.0
	current_production_multiplier = 1.0
	current_drone_speed_multiplier = 1.0
	reached_milestones.clear()
	
	var event_title: String = str(def.get("title", event_id))
	live_event_started.emit(active_event_id, event_title, time_remaining, target_goal)
	live_event_progress_updated.emit(0.0, target_goal, 0.0)
	
	# Haptic feedback on start
	var hm = get_node_or_null("/root/HapticsManager")
	if hm != null and hm.has_method("vibrate_gate_unlock"):
		hm.vibrate_gate_unlock()
		
	return true

## Contributes progress to the active live event.
func contribute_progress(contribution_type: String, amount: float = 1.0) -> void:
	if current_state != EventState.ACTIVE:
		return
	if not EVENT_CATALOG.has(active_event_id):
		return
		
	var def: Dictionary = EVENT_CATALOG[active_event_id]
	var weights: Dictionary = def.get("contribution_weights", {})
	var weight: float = float(weights.get(contribution_type, 0.0))
	if weight <= 0.0:
		return
		
	var pts: float = amount * weight
	current_progress = minf(target_goal, current_progress + pts)
	var pct: float = get_progress_percentage()
	
	live_event_progress_updated.emit(current_progress, target_goal, pct)
	
	# Check milestone crossings (25%, 50%, 75%, 100%)
	var milestone_thresholds: Array = def.get("milestones", [25.0, 50.0, 75.0, 100.0])
	for m in milestone_thresholds:
		var m_float: float = float(m)
		if pct >= m_float and not reached_milestones.has(m_float):
			reached_milestones.append(m_float)
			var m_name: String = "%d%% Milestone" % int(m_float)
			live_event_milestone_reached.emit(m_float, m_name)
			_trigger_milestone_feedback(m_float)
			
	if current_progress >= target_goal:
		_complete_event()

## Returns a comprehensive status dictionary of the active event.
func get_active_event() -> Dictionary:
	var def: Dictionary = EVENT_CATALOG.get(active_event_id, {})
	var state_name: String = "IDLE"
	match current_state:
		EventState.IDLE: state_name = "IDLE"
		EventState.ACTIVE: state_name = "ACTIVE"
		EventState.COMPLETED: state_name = "COMPLETED"
		EventState.COOLDOWN: state_name = "COOLDOWN"
		
	return {
		"id": active_event_id,
		"title": str(def.get("title", "")),
		"description": str(def.get("description", "")),
		"state": current_state,
		"state_name": state_name,
		"progress": current_progress,
		"target": target_goal,
		"percentage": get_progress_percentage(),
		"time_remaining": get_time_remaining(),
		"reward_remaining": reward_time_remaining,
		"cooldown_remaining": cooldown_time_remaining,
		"production_multiplier": get_production_multiplier(),
		"drone_speed_multiplier": get_drone_speed_multiplier(),
		"is_active": is_event_active(),
		"reached_milestones": reached_milestones.duplicate()
	}

## Returns true if an event is currently ACTIVE.
func is_event_active() -> bool:
	return current_state == EventState.ACTIVE

## Returns remaining seconds for active countdown or reward timer.
func get_time_remaining() -> float:
	if current_state == EventState.ACTIVE:
		return maxf(0.0, time_remaining)
	elif current_state == EventState.COMPLETED:
		return maxf(0.0, reward_time_remaining)
	return 0.0

## Returns the current completion percentage (0.0 to 100.0).
func get_progress_percentage() -> float:
	if target_goal <= 0.0:
		return 0.0
	return clampf((current_progress / target_goal) * 100.0, 0.0, 100.0)

## Returns active production multiplier (2.0 during Server Crash reward buff, otherwise 1.0).
func get_production_multiplier() -> float:
	return current_production_multiplier

## Returns active drone flight speed multiplier (1.5 during Angel Investor reward buff, otherwise 1.0).
func get_drone_speed_multiplier() -> float:
	return current_drone_speed_multiplier

## Triggers the Server Crash Crisis event (600s, 500 target points, 2x production reward).
func trigger_server_crash_crisis() -> void:
	start_event("server_crash_crisis")

## Triggers the Angel Investor Summit event (480s, 20 briefcases, 50k energy + 1.5x drone speed).
func trigger_angel_investor_summit() -> void:
	start_event("angel_investor_summit")

## Forces completion of the currently active event (for testing or debugging).
func force_complete_event() -> void:
	if current_state != EventState.ACTIVE:
		return
	current_progress = target_goal
	var pct: float = 100.0
	live_event_progress_updated.emit(current_progress, target_goal, pct)
	var def: Dictionary = EVENT_CATALOG.get(active_event_id, {})
	var milestone_thresholds: Array = def.get("milestones", [25.0, 50.0, 75.0, 100.0])
	for m in milestone_thresholds:
		var m_float: float = float(m)
		if not reached_milestones.has(m_float):
			reached_milestones.append(m_float)
			live_event_milestone_reached.emit(m_float, "%d%% Milestone" % int(m_float))
	_complete_event()

# ==============================================================================
# Internal State Transitions & Rewards
# ==============================================================================

func _complete_event() -> void:
	if current_state != EventState.ACTIVE:
		return
	current_state = EventState.COMPLETED
	
	var def: Dictionary = EVENT_CATALOG.get(active_event_id, {})
	var reward_data: Dictionary = {
		"event_id": active_event_id,
		"reward_type": def.get("reward_type", ""),
		"reward_description": def.get("reward_description", "")
	}
	
	if active_event_id == "server_crash_crisis":
		current_production_multiplier = float(def.get("reward_multiplier", 2.0))
		reward_time_remaining = float(def.get("reward_duration", 180.0))
		reward_data["production_multiplier"] = current_production_multiplier
		reward_data["duration"] = reward_time_remaining
		# Refresh GameState passive RPS immediately
		var gs = get_node_or_null("/root/GameState")
		if gs != null and gs.has_method("get_effective_passive_rps") and gs.has_signal("rps_changed"):
			gs.rps_changed.emit(gs.get_effective_passive_rps())
			
	elif active_event_id == "angel_investor_summit":
		var grant_energy: float = float(def.get("reward_energy", 50000.0))
		current_drone_speed_multiplier = float(def.get("drone_speed_multiplier", 1.5))
		reward_time_remaining = float(def.get("reward_duration", 120.0))
		reward_data["energy_grant"] = grant_energy
		reward_data["drone_speed_multiplier"] = current_drone_speed_multiplier
		reward_data["duration"] = reward_time_remaining
		
		# Add instant grant to GameState
		var gs = get_node_or_null("/root/GameState")
		if gs != null:
			gs.energy += grant_energy
			gs.total_energy_earned += grant_energy
			gs.total_lifetime_energy += grant_energy
			if gs.has_signal("energy_changed"):
				gs.energy_changed.emit(gs.energy, grant_energy)
				
	live_event_completed.emit(active_event_id, reward_data)
	_trigger_celebration_effects()

func _finish_rewards_and_cooldown() -> void:
	current_production_multiplier = 1.0
	current_drone_speed_multiplier = 1.0
	
	# Refresh GameState passive RPS
	var gs = get_node_or_null("/root/GameState")
	if gs != null and gs.has_method("get_effective_passive_rps") and gs.has_signal("rps_changed"):
		gs.rps_changed.emit(gs.get_effective_passive_rps())
		
	_end_event(true)

func _end_event(_was_completed: bool) -> void:
	var ended_id: String = active_event_id
	current_state = EventState.COOLDOWN
	cooldown_time_remaining = default_cooldown
	current_production_multiplier = 1.0
	current_drone_speed_multiplier = 1.0
	
	live_event_ended.emit(ended_id)

func _trigger_milestone_feedback(_milestone_pct: float) -> void:
	var hm = get_node_or_null("/root/HapticsManager")
	if hm != null and hm.has_method("vibrate_gate_unlock"):
		hm.vibrate_gate_unlock()
		
	var am = get_node_or_null("/root/AudioManager")
	if am != null:
		if am.has_method("play_sfx_research"):
			am.play_sfx_research()
		elif am.has_method("play_sfx_click"):
			am.play_sfx_click()

func _trigger_celebration_effects() -> void:
	# Audio juice
	var am = get_node_or_null("/root/AudioManager")
	if am != null:
		if am.has_method("play_sfx_overdrive"):
			am.play_sfx_overdrive()
		elif am.has_method("play_sfx_research"):
			am.play_sfx_research()
			
	# Haptics juice
	var hm = get_node_or_null("/root/HapticsManager")
	if hm != null and hm.has_method("vibrate_gate_unlock"):
		hm.vibrate_gate_unlock()
		
	# Confetti burst trigger
	var tree = get_tree()
	if tree != null and tree.root != null:
		var main_3d = tree.root.find_child("Main3D", true, false)
		if main_3d != null and main_3d.has_method("spawn_confetti_burst"):
			main_3d.spawn_confetti_burst(main_3d.global_position)
		var hud = tree.root.find_child("HUD", true, false)
		if hud != null and hud.has_method("_trigger_confetti_burst"):
			hud._trigger_confetti_burst()
