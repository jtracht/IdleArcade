extends Control
class_name CyberSyncMinigame

## CyberSyncMinigame Modal Overlay (res://scripts/ui/cyber_sync_minigame.gd)
## Interactive rhythm / timing hacking minigame for ServerTerminal (Milestone M2).
## Features 3 sequential data nodes to hit during target window, touch ergonomics
## (button height >= 56px, mouse_filter = STOP), and rewarding non-punitive buffs:
## - Perfect Sync (>=2 perfect hits): +100% passive RPS for 45s (2.0x multiplier)
## - Normal Sync: +50% passive RPS for 25s (1.50x multiplier)
## Provides programmatic hooks: simulate_sync_hit(is_perfect: bool) & complete_minigame(is_perfect: bool).

signal cyber_sync_started()
signal node_hit(index: int, is_perfect: bool)
signal minigame_completed(is_perfect: bool, duration: float, multiplier: float)
signal closed()

# Timing & Reward Configuration
@export var perfect_duration: float = 45.0
@export var perfect_multiplier: float = 2.00
@export var normal_duration: float = 25.0
@export var normal_multiplier: float = 1.50
@export var perfect_window: float = 0.08
@export var normal_window: float = 0.25
@export var target_position: float = 0.50
@export var pulse_speed: float = 1.8

# Node References
@onready var backdrop: ColorRect = get_node_or_null("DimBackdrop")
@onready var close_button: Button = get_node_or_null("%CloseButton")
@onready var sync_hit_button: Button = get_node_or_null("%SyncHitButton")
@onready var feedback_label: Label = get_node_or_null("%FeedbackLabel")
@onready var pulse_indicator: ColorRect = get_node_or_null("%PulseIndicator")
@onready var target_zone: Panel = get_node_or_null("%TargetZone")
@onready var node_label_0: Label = get_node_or_null("%NodeLabel0")
@onready var node_label_1: Label = get_node_or_null("%NodeLabel1")
@onready var node_label_2: Label = get_node_or_null("%NodeLabel2")
@onready var node_status_0: Label = get_node_or_null("%NodeStatus0")
@onready var node_status_1: Label = get_node_or_null("%NodeStatus1")
@onready var node_status_2: Label = get_node_or_null("%NodeStatus2")

var terminal_ref: Node = null
var current_node_index: int = 0
var node_hits: Array[bool] = []
var perfect_hits_count: int = 0
var is_completed: bool = false
var pulse_position: float = 0.0
var _pulse_time: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	if backdrop != null:
		backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
		
	if sync_hit_button != null:
		sync_hit_button.mouse_filter = Control.MOUSE_FILTER_STOP
		sync_hit_button.custom_minimum_size.y = maxf(sync_hit_button.custom_minimum_size.y, 56.0)
		if not sync_hit_button.pressed.is_connected(_on_sync_hit_pressed):
			sync_hit_button.pressed.connect(_on_sync_hit_pressed)
			
	if close_button != null:
		close_button.mouse_filter = Control.MOUSE_FILTER_STOP
		close_button.custom_minimum_size.y = maxf(close_button.custom_minimum_size.y, 56.0)
		close_button.custom_minimum_size.x = maxf(close_button.custom_minimum_size.x, 56.0)
		if not close_button.pressed.is_connected(close_minigame):
			close_button.pressed.connect(close_minigame)
			
	_reset_minigame_state()
	cyber_sync_started.emit()

func _process(delta: float) -> void:
	if is_completed:
		return
		
	_pulse_time += delta * pulse_speed
	# Oscillate timing pulse between 0.0 and 1.0 smoothly
	pulse_position = (sin(_pulse_time) + 1.0) * 0.5
	
	_update_timing_bar_visuals()

func _unhandled_input(event: InputEvent) -> void:
	if not visible or is_completed:
		return
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		if event.keycode == KEY_SPACE or event.keycode == KEY_E or event.keycode == KEY_ENTER:
			_on_sync_hit_pressed()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE:
			close_minigame()
			get_viewport().set_input_as_handled()

## Opens or attaches the minigame modal to a ServerTerminal instance.
func open_minigame(p_terminal_ref: Node = null) -> void:
	terminal_ref = p_terminal_ref
	_reset_minigame_state()
	visible = true

## Closes and cleans up the modal overlay.
func close_minigame() -> void:
	closed.emit()
	visible = false
	queue_free()

func _reset_minigame_state() -> void:
	current_node_index = 0
	node_hits.clear()
	perfect_hits_count = 0
	is_completed = false
	_pulse_time = 0.0
	pulse_position = 0.0
	
	if sync_hit_button != null:
		sync_hit_button.disabled = false
		sync_hit_button.text = "[ SYNC NOW ]"
		
	if feedback_label != null:
		feedback_label.text = "READY TO HACK // HIT [SYNC NOW] WHEN TARGET IS ALIGNED"
		feedback_label.modulate = Color(0.1, 1.0, 0.4, 1.0)
		
	_update_node_labels()

func _on_sync_hit_pressed() -> void:
	if is_completed:
		return
		
	var diff: float = absf(pulse_position - target_position)
	var is_perfect: bool = (diff <= perfect_window)
	
	# Haptic pulse if available
	var hm = get_node_or_null("/root/HapticsManager")
	if hm != null and hm.has_method("vibrate_button"):
		hm.vibrate_button()
		
	simulate_sync_hit(is_perfect)

## Programmatic method for hitting current sync node (headless testable).
func simulate_sync_hit(is_perfect: bool = true) -> void:
	if is_completed:
		return
		
	var node_idx = current_node_index
	node_hits.append(is_perfect)
	if is_perfect:
		perfect_hits_count += 1
		
	node_hit.emit(node_idx, is_perfect)
	
	# Dispatch to terminal reference if attached
	if terminal_ref != null and terminal_ref.has_method("emit_data_node_hit"):
		terminal_ref.emit_data_node_hit(node_idx, is_perfect)
		
	# SFX
	var am = get_node_or_null("/root/AudioManager")
	if am != null and am.has_method("play_sfx_click"):
		am.play_sfx_click()
		
	# Screen shake juice
	var tree = get_tree()
	if tree != null and tree.root != null:
		var m3d = tree.root.find_child("Main3D", true, false)
		if m3d != null and m3d.has_method("add_screen_shake"):
			m3d.add_screen_shake(0.35 if is_perfect else 0.20)
			
	if feedback_label != null:
		if is_perfect:
			feedback_label.text = ">> NODE %d: PERFECT SYNC! <<" % (node_idx + 1)
			feedback_label.modulate = Color(0.1, 1.0, 0.4, 1.0)
		else:
			feedback_label.text = ">> NODE %d: SYNCED! <<" % (node_idx + 1)
			feedback_label.modulate = Color(0.0, 0.85, 1.0, 1.0)
			
	current_node_index += 1
	_update_node_labels()
	
	if current_node_index >= 3:
		var final_perfect: bool = (perfect_hits_count >= 2)
		complete_minigame(final_perfect)

## Programmatic method to complete minigame with given outcome (headless testable).
func complete_minigame(is_perfect: bool = true) -> void:
	is_completed = true
	var duration: float = perfect_duration if is_perfect else normal_duration
	var multiplier: float = perfect_multiplier if is_perfect else normal_multiplier
	
	if sync_hit_button != null:
		sync_hit_button.disabled = true
		sync_hit_button.text = "[ COMPLETE ]"
		
	if feedback_label != null:
		if is_perfect:
			feedback_label.text = ">>> MATRIX OVERCLOCK ACHIEVED! +100% RPS (45s) <<<"
			feedback_label.modulate = Color(0.1, 1.0, 0.4, 1.0)
		else:
			feedback_label.text = ">>> CYBER-SYNC ENGAGED! +50% RPS (25s) <<<"
			feedback_label.modulate = Color(0.0, 0.85, 1.0, 1.0)
			
	# If terminal_ref is attached, delegate overclock resolution
	if terminal_ref != null and terminal_ref.has_method("complete_cyber_sync"):
		terminal_ref.complete_cyber_sync(is_perfect)
	else:
		# Standalone execution: directly activate GameState buff
		var gs = get_node_or_null("/root/GameState")
		if gs != null and gs.has_method("activate_server_overclock_buff"):
			gs.activate_server_overclock_buff(duration, multiplier)
			
		var am = get_node_or_null("/root/AudioManager")
		if am != null and am.has_method("play_sfx_overdrive"):
			am.play_sfx_overdrive()
			
	minigame_completed.emit(is_perfect, duration, multiplier)

func _update_node_labels() -> void:
	var statuses: Array[Label] = [node_status_0, node_status_1, node_status_2]
	
	for i in range(3):
		var lbl = statuses[i]
		if lbl == null:
			continue
		if i < node_hits.size():
			if node_hits[i]:
				lbl.text = "PERFECT"
				lbl.modulate = Color(0.1, 1.0, 0.4, 1.0)
			else:
				lbl.text = "SYNCED"
				lbl.modulate = Color(0.0, 0.85, 1.0, 1.0)
		elif i == current_node_index and not is_completed:
			lbl.text = "ACTIVE"
			lbl.modulate = Color(1.0, 0.85, 0.2, 1.0)
		else:
			lbl.text = "LOCKED"
			lbl.modulate = Color(0.5, 0.5, 0.5, 0.8)

func _update_timing_bar_visuals() -> void:
	if pulse_indicator != null:
		var parent_ctrl = pulse_indicator.get_parent() as Control
		if parent_ctrl != null and parent_ctrl.size.x > 0:
			var max_w = parent_ctrl.size.x - pulse_indicator.size.x
			pulse_indicator.position.x = max_w * pulse_position
			
	var diff: float = absf(pulse_position - target_position)
	if target_zone != null:
		if diff <= perfect_window:
			target_zone.modulate = Color(0.1, 1.0, 0.4, 1.0)
		elif diff <= normal_window:
			target_zone.modulate = Color(0.0, 0.85, 1.0, 1.0)
		else:
			target_zone.modulate = Color(0.4, 0.4, 0.4, 0.6)
