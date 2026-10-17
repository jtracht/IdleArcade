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

# State Machine Variables
var is_overclock_active: bool = false
var is_on_cooldown: bool = false
var overclock_time_remaining: float = 0.0
var cooldown_time_remaining: float = 0.0
var current_multiplier: float = 1.50
var is_perfect_overclock: bool = false

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
		status_label.text = "[E] Hack Terminal [READY]"
		status_label.visible = true
		status_label.modulate = Color(0.1, 1.0, 0.4, 1.0)
		
	if interaction_area != null:
		interaction_area.body_entered.connect(_on_interaction_body_entered)
		interaction_area.body_exited.connect(_on_interaction_body_exited)
		
	if overclock_sparks != null:
		overclock_sparks.emitting = false
	if matrix_sparks != null:
		matrix_sparks.emitting = false

func _process(delta: float) -> void:
	_time += delta
	_telemetry_timer += delta
	
	# Update Overclock duration
	if is_overclock_active:
		overclock_time_remaining -= delta
		if overclock_time_remaining <= 0.0:
			_end_overclock()
			
	# Update Cooldown duration
	elif is_on_cooldown:
		cooldown_time_remaining -= delta
		if cooldown_time_remaining <= 0.0:
			is_on_cooldown = false
			cooldown_time_remaining = 0.0
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
		elif is_on_cooldown:
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
	return not is_overclock_active and not is_on_cooldown

## Alias for can_activate
func can_hack() -> bool:
	return can_activate()

## Alias for interact()
func activate_overclock() -> void:
	interact()

## Starts the Cyber-Sync rhythm minigame or returns the active modal instance.
func start_cyber_sync() -> Node:
	return open_cyber_sync_minigame()

## Instantiates and opens the CyberSyncMinigame modal overlay.
func open_cyber_sync_minigame() -> Node:
	if _minigame_instance != null and is_instance_valid(_minigame_instance):
		_minigame_instance.open_minigame(self)
		return _minigame_instance
		
	_minigame_instance = MINIGAME_SCENE.instantiate()
	
	# Determine suitable UI canvas layer in the scene tree
	var parent_layer: Node = null
	var tree = get_tree()
	if tree != null and tree.root != null:
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

## Callback from minigame when a data node is hit.
func emit_data_node_hit(index: int, is_perfect: bool) -> void:
	data_node_hit.emit(index, is_perfect)

## Resolves completion of the Cyber-Sync minigame with the given performance.
func complete_cyber_sync(is_perfect: bool = true) -> void:
	var duration: float = perfect_overclock_duration if is_perfect else overclock_duration
	var multiplier: float = perfect_rps_boost_multiplier if is_perfect else rps_boost_multiplier
	_activate_overclock_state(duration, multiplier, is_perfect)
	cyber_sync_completed.emit(is_perfect, duration, multiplier)

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
	overclock_time_remaining = 0.0
	cooldown_time_remaining = overclock_cooldown
	is_perfect_overclock = false
	
	if matrix_sparks != null:
		matrix_sparks.emitting = false
	if overclock_sparks != null:
		overclock_sparks.emitting = false
	if terminal_omni_light != null:
		terminal_omni_light.light_energy = 0.9
		
	overclock_ended.emit()
	_update_ui_prompts()

func _update_ui_prompts() -> void:
	var label_str: String = action_label
	if is_overclock_active:
		var mult_pct = "+100%" if is_perfect_overclock else "+50%"
		label_str = "Overclocked (%.0fs)" % ceilf(overclock_time_remaining)
		if prompt_label != null:
			prompt_label.text = "[E] Overclock Active (%.0fs)" % ceilf(overclock_time_remaining)
		if status_label != null:
			status_label.text = "[CYBER-SYNC ACTIVE: %.0fs (%s RPS)]" % [ceilf(overclock_time_remaining), mult_pct]
			status_label.modulate = Color(0.1, 1.0, 0.4, 1.0)
	elif is_on_cooldown:
		label_str = "Cooling (%.0fs)" % ceilf(cooldown_time_remaining)
		if prompt_label != null:
			prompt_label.text = "[E] Cooling Down (%.0fs)" % ceilf(cooldown_time_remaining)
		if status_label != null:
			status_label.text = "[TERMINAL COOLING: %.0fs]" % ceilf(cooldown_time_remaining)
			status_label.modulate = Color(1.0, 0.65, 0.1, 1.0)
	else:
		label_str = action_label
		if prompt_label != null:
			prompt_label.text = prompt_text
		if status_label != null:
			status_label.text = "[E] Hack Terminal [READY]"
			status_label.modulate = Color(0.1, 1.0, 0.4, 1.0)
			
	if _player_in_range:
		var tc = _find_touch_controls()
		if tc != null and tc.has_method("register_interactable"):
			tc.register_interactable(self, label_str)

func _update_screen_telemetry() -> void:
	if screen_label == null:
		return
		
	if is_overclock_active:
		var glitch_char = ["#", "$", "&", "%", "!", "@"][_matrix_step % 6]
		var mult_str = "+100.0%" if is_perfect_overclock else "+50.0%"
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
