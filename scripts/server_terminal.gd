extends StaticBody3D
class_name ServerTerminal

## 3D Server Room Overclock Terminal for IdleArcade.
## Interactive server console situated in the Server Room at (0, 0, -18).
## Features a stylized CRT monitor with matrix telemetry, pulsing LEDs,
## proximity trigger, dynamic TouchControls integration ("Hack [E]"),
## Cyber-Sync rhythm minigame overlay, MatrixSparks VFX, and floating 3D status indicator:
## - Perfect Sync: +100% passive RPS for 45s (2.00x multiplier)
## - Normal Sync: +50% passive RPS for 25s (1.50x multiplier)
## 60s cooldown with floating 3D status indicator (StatusLabel3D / PromptLabel3D).

# Baseline & Cyber-Sync Signals
signal overclock_started(duration: float, bonus_mult: float)
signal overclock_activated(duration: float, multiplier: float)
signal overclock_ended()
signal terminal_interacted()
signal cyber_sync_started()
signal cyber_sync_completed(is_perfect: bool, duration: float, multiplier: float)
signal overclock_completed(rating: String, multiplier: float, duration: float)
signal data_node_hit(index: int, is_perfect: bool)

# Preserved baseline properties and action labels
@export var prompt_text: String = "[E] Server Console"
@export var action_label: String = "Hack [E]"
const LEGACY_ACTION_LABEL: String = "Overclock [E]"
@export var overclock_duration: float = 25.0
@export var overclock_cooldown: float = 60.0
@export var rps_boost_multiplier: float = 1.50

# Milestone M2 Enhanced Overclock Configuration
@export var perfect_overclock_duration: float = 45.0
@export var perfect_rps_boost_multiplier: float = 2.00

# Phase 16 3-Tier Overclock Configuration
@export var miss_overclock_duration: float = 15.0
@export var miss_rps_boost_multiplier: float = 1.20
@export var phase16_perfect_multiplier: float = 3.00
@export var phase16_good_multiplier: float = 2.00
@export var phase16_good_duration: float = 30.0

# Phase 16 Milestone 1: Station State Machine & Canonical ID
const STATION_ID: String = "server_terminal"

enum StationState {
	STATE_READY = 0,
	STATE_PLAYING = 1,
	STATE_COMPLETED = 2,
	STATE_COOLDOWN = 3
}

const STATE_READY: int = StationState.STATE_READY
const STATE_PLAYING: int = StationState.STATE_PLAYING
const STATE_COMPLETED: int = StationState.STATE_COMPLETED
const STATE_COOLDOWN: int = StationState.STATE_COOLDOWN

signal state_changed(new_state: int, old_state: int)
var current_state: StationState = StationState.STATE_READY:
	set(value):
		if current_state == value:
			return
		var old_state: int = current_state
		current_state = value
		state_changed.emit(current_state, old_state)
var is_minigame_active: bool = false

# State Machine Variables
var is_overclock_active: bool = false
var is_on_cooldown: bool = false
var overclock_time_remaining: float = 0.0
var cooldown_time_remaining: float = 0.0
var current_multiplier: float = 1.50
var is_perfect_overclock: bool = false
var _cyber_sync_completed_in_session: bool = false

# Node References
@onready var interaction_area: Area3D = get_node_or_null("InteractionArea")
@onready var prompt_label: Label3D = get_node_or_null("PromptLabel3D")
@onready var status_label: Label3D = get_node_or_null("StatusLabel3D")
@onready var screen_label: Label3D = get_node_or_null("Visuals/ScreenLabel3D")
@onready var terminal_omni_light: OmniLight3D = get_node_or_null("Visuals/TerminalOmniLight")
@onready var overclock_sparks: CPUParticles3D = get_node_or_null("Visuals/OverclockSparks")
@onready var matrix_sparks: CPUParticles3D = get_node_or_null("Visuals/MatrixSparks")
@onready var led_power: MeshInstance3D = get_node_or_null("Visuals/StatusLEDs/LED_Power")
@onready var led_overclock: MeshInstance3D = get_node_or_null("Visuals/StatusLEDs/LED_Overclock")
@onready var led_cooldown: MeshInstance3D = get_node_or_null("Visuals/StatusLEDs/LED_Cooldown")

const MINIGAME_SCENE: PackedScene = preload("res://scenes/ui/cyber_sync_minigame.tscn")
var _minigame_instance: Control = null

var _player_in_range: bool = false
var _avatar_ref: Node3D = null
var _time: float = 0.0
var _telemetry_timer: float = 0.0
var _matrix_step: int = 0

func _ready() -> void:
	add_to_group("terminals")
	add_to_group("server_terminals")
	add_to_group("interactables")
	
	if prompt_label != null:
		prompt_label.text = prompt_text
		prompt_label.visible = false
		
	if status_label != null:
		status_label.text = "[READY]"
		status_label.visible = true
		status_label.modulate = Color("1aff66")
		
	var gs = get_node_or_null("/root/GameState")
	if gs != null:
		if gs.has_method("get_station_cooldown"):
			var saved_cd: float = gs.get_station_cooldown(STATION_ID)
			if saved_cd > 0.0:
				is_on_cooldown = true
				cooldown_time_remaining = saved_cd
				current_state = StationState.STATE_COOLDOWN
			else:
				current_state = StationState.STATE_READY
		else:
			current_state = StationState.STATE_READY
		if gs.has_signal("station_cooldown_started") and not gs.station_cooldown_started.is_connected(_on_station_cooldown_started):
			gs.station_cooldown_started.connect(_on_station_cooldown_started)
		if gs.has_signal("station_cooldown_ended") and not gs.station_cooldown_ended.is_connected(_on_station_cooldown_ended):
			gs.station_cooldown_ended.connect(_on_station_cooldown_ended)
	else:
		current_state = StationState.STATE_READY

	if interaction_area != null:
		interaction_area.body_entered.connect(_on_interaction_body_entered)
		interaction_area.body_exited.connect(_on_interaction_body_exited)
		
	if overclock_sparks != null:
		overclock_sparks.emitting = false
	if matrix_sparks != null:
		matrix_sparks.emitting = false

	_update_ui_prompts()

func _process(delta: float) -> void:
	_time += delta
	_telemetry_timer += delta
	
	# Update Overclock duration
	if is_overclock_active:
		current_state = StationState.STATE_PLAYING
		overclock_time_remaining -= delta
		if overclock_time_remaining <= 0.0:
			_end_overclock()
			
	# Update Cooldown duration
	elif is_on_cooldown or current_state == StationState.STATE_COOLDOWN or cooldown_time_remaining > 0.0:
		current_state = StationState.STATE_COOLDOWN
		is_on_cooldown = true
		cooldown_time_remaining = maxf(0.0, cooldown_time_remaining - delta)

		if cooldown_time_remaining <= 0.0:
			is_on_cooldown = false
			cooldown_time_remaining = 0.0
			current_state = StationState.STATE_READY
			var gs = get_node_or_null("/root/GameState")
			if gs != null and gs.has_method("set_station_cooldown") and gs.get_station_cooldown(STATION_ID) > 0.0:
				gs.set_station_cooldown(STATION_ID, 0.0)
			_update_ui_prompts()
		else:
			_update_ui_prompts()
			
	# Update CRT telemetry every ~0.15s
	if _telemetry_timer >= 0.15:
		_telemetry_timer = 0.0
		_matrix_step += 1
		_update_screen_telemetry()
		
	# Dynamic light pulse
	if terminal_omni_light != null:
		if is_overclock_active:
			terminal_omni_light.light_energy = 2.4 + sin(_time * 12.0) * 0.4
		elif is_on_cooldown or current_state == StationState.STATE_COOLDOWN:
			terminal_omni_light.light_energy = 0.6 + sin(_time * 3.0) * 0.2
		else:
			terminal_omni_light.light_energy = 0.9 + sin(_time * 4.0) * 0.15

func _unhandled_input(event: InputEvent) -> void:
	if not _player_in_range:
		return
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		if event.keycode == KEY_E:
			interact()
			get_viewport().set_input_as_handled()

func _on_interaction_body_entered(body: Node3D) -> void:
	if body.is_in_group("player") or body is CharacterBody3D:
		_player_in_range = true
		_avatar_ref = body
		_update_ui_prompts()
		if prompt_label != null:
			prompt_label.visible = true
		var tc = _find_touch_controls()
		if tc != null and tc.has_method("register_interactable"):
			tc.register_interactable(self, action_label)

func _on_interaction_body_exited(body: Node3D) -> void:
	if body == _avatar_ref or body.is_in_group("player") or body is CharacterBody3D:
		_player_in_range = false
		_avatar_ref = null
		if prompt_label != null:
			prompt_label.visible = false
		var tc = _find_touch_controls()
		if tc != null and tc.has_method("unregister_interactable"):
			tc.unregister_interactable(self)

func _exit_tree() -> void:
	var tc = _find_touch_controls()
	if tc != null and tc.has_method("unregister_interactable"):
		tc.unregister_interactable(self)
	if _minigame_instance != null and is_instance_valid(_minigame_instance):
		_minigame_instance.queue_free()
		_minigame_instance = null

func _find_touch_controls() -> Node:
	var tree = get_tree()
	if tree == null:
		return null
	var tc_nodes = tree.get_nodes_in_group("touch_controls")
	if tc_nodes.size() > 0:
		return tc_nodes[0]
	return tree.root.find_child("TouchControls", true, false)

## Proximity status query
func is_player_in_range() -> bool:
	return _player_in_range

## Availability query for overclock activation
func can_activate() -> bool:
	if current_state == StationState.STATE_PLAYING or current_state == StationState.STATE_COOLDOWN:
		return false
	if is_overclock_active or is_minigame_active:
		return false
	if is_on_cooldown or cooldown_time_remaining > 0.0:
		return false
	var gs = get_node_or_null("/root/GameState")
	if gs != null and gs.has_method("is_station_on_cooldown") and gs.is_station_on_cooldown(STATION_ID):
		return false
	return true

## Returns true if station is in ready state
func is_ready() -> bool:
	return current_state == StationState.STATE_READY and can_activate()

## Alias for can_activate
func can_hack() -> bool:
	return can_activate()

## Alias for interact()
func activate_overclock() -> void:
	interact()

## Starts the Cyber-Sync rhythm minigame or returns the active modal instance.
func start_cyber_sync() -> Node:
	return open_cyber_sync_minigame()

func _gate_avatar_and_controls() -> void:
	var av = _avatar_ref
	if av == null and get_tree() != null:
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			av = players[0]
	if av != null:
		if av.has_method("set_input_enabled"):
			av.set_input_enabled(false)
		if av.has_method("stop_movement"):
			av.stop_movement()

	var tc = _find_touch_controls()
	if tc != null:
		if tc.has_method("fade_out_controls"):
			tc.fade_out_controls()
		elif tc.has_method("reset_controls"):
			tc.reset_controls()

	var tree = get_tree()
	if tree != null and tree.root != null:
		var m3d = tree.root.find_child("Main3D", true, false)
		if m3d != null and m3d.has_method("pause_exploration_for_modal"):
			m3d.pause_exploration_for_modal(self)

func _restore_avatar_and_controls() -> void:
	var av = _avatar_ref
	if av == null and get_tree() != null:
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			av = players[0]
	if av != null and av.has_method("set_input_enabled"):
		av.set_input_enabled(true)

	var tc = _find_touch_controls()
	if tc != null and tc.has_method("fade_in_controls"):
		tc.fade_in_controls()

	var tree = get_tree()
	if tree != null and tree.root != null:
		var m3d = tree.root.find_child("Main3D", true, false)
		if m3d != null and m3d.has_method("resume_exploration_from_modal"):
			m3d.resume_exploration_from_modal(self)

func _on_minigame_closed() -> void:
	is_minigame_active = false
	_restore_avatar_and_controls()

	# Revert premature overclock buff if modal was canceled/dismissed without completion
	if not _cyber_sync_completed_in_session:
		if is_overclock_active:
			is_overclock_active = false
			overclock_time_remaining = 0.0
			is_perfect_overclock = false
			var gs = get_node_or_null("/root/GameState")
			if gs != null:
				gs.server_overclock_buff_timer = 0.0
				gs.server_overclock_buff_remaining = 0.0
				gs.server_overclock_buff_multiplier = 1.0
				gs.server_overclock_buff_active = false
				if gs.has_signal("rps_changed"):
					gs.rps_changed.emit(gs.get_effective_passive_rps())
			if matrix_sparks != null:
				matrix_sparks.emitting = false
			if overclock_sparks != null:
				overclock_sparks.emitting = false
			if terminal_omni_light != null:
				terminal_omni_light.light_energy = 0.9

	if not is_overclock_active and not is_on_cooldown and cooldown_time_remaining <= 0.0:
		current_state = StationState.STATE_READY
	elif is_on_cooldown or cooldown_time_remaining > 0.0:
		current_state = StationState.STATE_COOLDOWN
	_update_ui_prompts()

## Instantiates and opens the CyberSyncMinigame modal overlay.
func open_cyber_sync_minigame() -> Node:
	_cyber_sync_completed_in_session = false
	current_state = StationState.STATE_PLAYING
	is_minigame_active = true
	_gate_avatar_and_controls()
	_update_ui_prompts()

	if _minigame_instance != null and is_instance_valid(_minigame_instance):
		_minigame_instance.visible = true
		if _minigame_instance.has_signal("closed"):
			if not _minigame_instance.closed.is_connected(_on_minigame_closed):
				_minigame_instance.closed.connect(_on_minigame_closed)
		if _minigame_instance.has_method("open_minigame"):
			_minigame_instance.open_minigame(self)
		return _minigame_instance
		
	_minigame_instance = MINIGAME_SCENE.instantiate()
	if _minigame_instance.has_signal("closed"):
		if not _minigame_instance.closed.is_connected(_on_minigame_closed):
			_minigame_instance.closed.connect(_on_minigame_closed)
	
	# Determine suitable UI canvas layer in the scene tree
	var parent_layer: Node = null
	var tree = get_tree()
	if tree != null and tree.root != null:
		var m3d = tree.root.find_child("Main3D", true, false)
		if m3d != null and m3d.has_method("get_minigame_layer"):
			parent_layer = m3d.get_minigame_layer()
		if parent_layer == null:
			parent_layer = tree.root.find_child("MinigameLayer", true, false)
		if parent_layer == null:
			parent_layer = tree.root.find_child("DialogueLayer", true, false)
		if parent_layer == null:
			parent_layer = tree.root.find_child("TouchControlsLayer", true, false)
		if parent_layer == null:
			parent_layer = tree.current_scene
		if parent_layer == null:
			parent_layer = tree.root
			
	if parent_layer != null:
		parent_layer.add_child(_minigame_instance)
	else:
		add_child(_minigame_instance)
		
	if _minigame_instance.has_method("open_minigame"):
		_minigame_instance.open_minigame(self)
		
	cyber_sync_started.emit()
	return _minigame_instance

## Alias for open_cyber_sync_minigame() for uniform station launcher compatibility
func start_hack_minigame() -> Node:
	return open_cyber_sync_minigame()

## Callback from minigame when a data node is hit.
func emit_data_node_hit(index: int, is_perfect: bool) -> void:
	data_node_hit.emit(index, is_perfect)
	# Immediate 3D spark pulse feedback on node sync
	if is_perfect:
		if matrix_sparks != null:
			matrix_sparks.restart()
			matrix_sparks.emitting = true
	else:
		if overclock_sparks != null:
			overclock_sparks.restart()
			overclock_sparks.emitting = true
	if terminal_omni_light != null:
		terminal_omni_light.light_energy = 3.0 if is_perfect else 2.2

## Spawns a billboarded 3D floating score popup above the terminal.
func spawn_score_popup(text_msg: String, text_color: Color = Color(0.1, 1.0, 0.4)) -> Label3D:
	var target_parent = get_parent() if get_parent() != null else self
	var origin_pos: Vector3 = global_position if is_inside_tree() else position
	var spawn_pos: Vector3 = origin_pos + Vector3(0.0, 2.6, 0.0)
	var popup_cls = load("res://scripts/vfx/floating_score_popup.gd")
	if popup_cls != null and popup_cls.has_method("spawn_popup_3d"):
		return popup_cls.spawn_popup_3d(target_parent, spawn_pos, text_msg, text_color, 1.3, 1.6, 28)
	
	# Self-contained fallback
	var label := Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = 28
	label.outline_size = 6
	label.text = text_msg
	label.modulate = text_color
	target_parent.add_child(label)
	if label.is_inside_tree():
		label.top_level = true
		label.global_position = spawn_pos
		var tw = label.create_tween().set_parallel(true)
		tw.tween_property(label, "position:y", label.position.y + 1.5, 1.2).set_ease(Tween.EASE_OUT)
		tw.tween_property(label, "modulate:a", 0.0, 0.6).set_delay(0.6)
		tw.chain().tween_callback(label.queue_free)
	else:
		label.position = spawn_pos
		label.queue_free()
	return label

## Resolves completion of the Cyber-Sync minigame with the given performance.
## Accurately handles all 3 tiers (Perfect: 3.0x/45s, Good: 2.0x/30s, Miss: 1.2x/15s)
## as well as custom duration and multiplier overrides.
func complete_cyber_sync(is_perfect: bool = true, rating: String = "", custom_duration: float = -1.0, custom_multiplier: float = -1.0) -> void:
	_cyber_sync_completed_in_session = true
	var rating_str: String = rating
	if rating_str == "":
		rating_str = "Perfect" if is_perfect else "Good"

	var perfect_flag: bool = is_perfect or (rating_str == "Perfect")
	if rating_str == "Miss" or rating_str == "Good":
		perfect_flag = false

	var duration: float
	if custom_duration > 0.0:
		duration = custom_duration
	elif rating_str == "Perfect" or perfect_flag:
		duration = perfect_overclock_duration
	elif rating_str == "Miss":
		duration = miss_overclock_duration
	elif rating_str == "Good":
		duration = phase16_good_duration
	else:
		duration = overclock_duration

	var multiplier: float
	if custom_multiplier > 0.0:
		multiplier = custom_multiplier
	elif rating_str == "Perfect" or perfect_flag:
		multiplier = phase16_perfect_multiplier
	elif rating_str == "Miss":
		multiplier = miss_rps_boost_multiplier
	elif rating_str == "Good":
		multiplier = phase16_good_multiplier
	else:
		multiplier = rps_boost_multiplier

	_activate_overclock_state(duration, multiplier, perfect_flag)
	cyber_sync_completed.emit(perfect_flag, duration, multiplier)
	if has_signal("overclock_completed"):
		overclock_completed.emit(rating_str, multiplier, duration)

	# Feature 26: Billboarded 3D Score Popup
	var popup_text: String
	var popup_color: Color
	if rating_str == "Perfect" or perfect_flag:
		popup_text = "+3x BOOST!"
		popup_color = Color(0.1, 1.0, 0.4)      # Neon Matrix Green
	elif rating_str == "Good":
		popup_text = "+2x BOOST!"
		popup_color = Color(0.0, 0.9, 1.0)      # Electric Blue / Cyan
	else:
		popup_text = "+1.2x COMFORT!"
		popup_color = Color(1.0, 0.85, 0.2)     # Amber / Gold
	spawn_score_popup(popup_text, popup_color)

## Primary interaction method
func interact() -> void:
	terminal_interacted.emit()
	
	if not can_activate():
		var am_fail = get_node_or_null("/root/AudioManager")
		if am_fail != null and am_fail.has_method("play_sfx_click"):
			am_fail.play_sfx_click()
		return
		
	# Engage baseline overclock immediately for contract stability and headless callers
	_activate_overclock_state(overclock_duration, rps_boost_multiplier, false)
	
	# Open interactive CyberSyncMinigame modal overlay
	open_cyber_sync_minigame()

func _activate_overclock_state(duration: float, multiplier: float, is_perfect: bool) -> void:
	is_overclock_active = true
	is_on_cooldown = false
	overclock_time_remaining = duration
	current_multiplier = multiplier
	is_perfect_overclock = is_perfect
	
	# Apply GameState passive RPS buff
	var gs = get_node_or_null("/root/GameState")
	if gs != null and gs.has_method("activate_server_overclock_buff"):
		gs.activate_server_overclock_buff(duration, multiplier)
		
	# Live Event contribution (e.g. Server Crash Crisis)
	var lem = get_node_or_null("/root/LiveEventManager")
	if lem != null and lem.has_method("contribute_progress"):
		lem.contribute_progress("overclock", 1.0)
		
	# Visual juice: sparks and light
	if is_perfect:
		if matrix_sparks != null:
			matrix_sparks.emitting = true
		if overclock_sparks != null:
			overclock_sparks.emitting = true
	else:
		if overclock_sparks != null:
			overclock_sparks.emitting = true
		if matrix_sparks != null:
			matrix_sparks.emitting = false
			
	if terminal_omni_light != null:
		terminal_omni_light.light_energy = 2.6 if is_perfect else 2.4

	# Screen-Shake juice: strong shockwave
	var tree = get_tree()
	if tree != null and tree.root != null:
		var m3d = tree.root.find_child("Main3D", true, false)
		if m3d != null and m3d.has_method("add_screen_shake"):
			m3d.add_screen_shake(0.65 if is_perfect else 0.60)
		
	# SFX juice: overdrive sound
	var am = get_node_or_null("/root/AudioManager")
	if am != null:
		if am.has_method("play_sfx_overdrive"):
			am.play_sfx_overdrive()
		elif am.has_method("play_sfx_click"):
			am.play_sfx_click()
			
	overclock_started.emit(duration, multiplier)
	overclock_activated.emit(duration, multiplier)
	_update_ui_prompts()

func _end_overclock() -> void:
	is_overclock_active = false
	is_on_cooldown = true
	current_state = StationState.STATE_COOLDOWN
	overclock_time_remaining = 0.0
	cooldown_time_remaining = overclock_cooldown
	is_perfect_overclock = false

	var gs = get_node_or_null("/root/GameState")
	if gs != null and gs.has_method("set_station_cooldown"):
		gs.set_station_cooldown(STATION_ID, overclock_cooldown)
	
	if matrix_sparks != null:
		matrix_sparks.emitting = false
	if overclock_sparks != null:
		overclock_sparks.emitting = false
	if terminal_omni_light != null:
		terminal_omni_light.light_energy = 0.9
		
	overclock_ended.emit()
	_update_ui_prompts()

func _on_station_cooldown_started(s_id: String, duration: float) -> void:
	if s_id == STATION_ID:
		is_on_cooldown = true
		cooldown_time_remaining = duration
		if not is_overclock_active and not is_minigame_active:
			current_state = StationState.STATE_COOLDOWN
		_update_ui_prompts()

func _on_station_cooldown_ended(s_id: String) -> void:
	if s_id == STATION_ID:
		is_on_cooldown = false
		cooldown_time_remaining = 0.0
		if not is_overclock_active and not is_minigame_active:
			current_state = StationState.STATE_READY
		_update_ui_prompts()

func _update_ui_prompts() -> void:
	var label_str: String = action_label
	if is_minigame_active or is_overclock_active or current_state == StationState.STATE_PLAYING:
		label_str = "Hacking..." if is_minigame_active else ("Overclocked (%.0fs)" % ceilf(overclock_time_remaining))
		if prompt_label != null:
			prompt_label.text = "[E] Overclock Active (%.0fs)" % ceilf(overclock_time_remaining) if is_overclock_active else "[E] Terminal Active"
		if status_label != null:
			status_label.text = "[ACTIVE]"
			status_label.modulate = Color("00e5ff")
	elif is_on_cooldown or current_state == StationState.STATE_COOLDOWN or cooldown_time_remaining > 0.0:
		label_str = "Cooling (%.0fs)" % ceilf(cooldown_time_remaining)
		if prompt_label != null:
			prompt_label.text = "[E] Cooling Down (%.0fs)" % ceilf(cooldown_time_remaining)
		if status_label != null:
			status_label.text = "Cooling (%ds)" % int(ceilf(cooldown_time_remaining))
			status_label.modulate = Color("ffaa1a")
	else:
		label_str = action_label
		if prompt_label != null:
			prompt_label.text = prompt_text
		if status_label != null:
			status_label.text = "[READY]"
			status_label.modulate = Color("1aff66")
			
	if _player_in_range:
		var tc = _find_touch_controls()
		if tc != null and tc.has_method("register_interactable"):
			tc.register_interactable(self, label_str)

func _update_screen_telemetry() -> void:
	if screen_label == null:
		return
		
	if is_overclock_active:
		var glitch_char = ["#", "$", "&", "%", "!", "@"][_matrix_step % 6]
		var mult_str = "+%.0f%%" % ((current_multiplier - 1.0) * 100.0)
		screen_label.text = ">> CYBER-SYNC ENGAGED! %s <<\nRPS MULT: %s\nTIME: %.1fs\nTEMP: 88.4 C [WARN]" % [glitch_char, mult_str, overclock_time_remaining]
		screen_label.modulate = Color(0.1, 1.0, 0.4, 1.0) if is_perfect_overclock else Color(0.0, 0.95, 1.0, 1.0)
	elif is_on_cooldown:
		var dots = ".".repeat((_matrix_step % 4) + 1)
		screen_label.text = ">> RE-COOLING%s <<\nSYS RESTORING...\nREADY IN: %.1fs\nSTATUS: COOLDOWN" % [dots, cooldown_time_remaining]
		screen_label.modulate = Color(1.0, 0.65, 0.1, 1.0)
	else:
		var cursor = "_" if (_matrix_step % 2 == 0) else " "
		screen_label.text = "SYS_ROOT // ONLINE%s\nCORE: 64T / 4.8 GHz\nCYBER-SYNC: READY\n[PRESS E TO HACK]" % cursor
		screen_label.modulate = Color(0.1, 1.0, 0.4, 1.0)
