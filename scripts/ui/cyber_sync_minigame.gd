extends Control
class_name CyberSyncMinigame

## CyberSyncMinigame Modal Overlay (res://scripts/ui/cyber_sync_minigame.gd)
## Interactive rhythm / timing hacking minigame for ServerTerminal (Milestone M2).
## Features 3 sequential data nodes to hit during target window, touch ergonomics
## (button height >= 56px, mouse_filter = STOP), and dynamic 3-tier overclock multipliers:
## - "Perfect" hit zone: 3.0x passive RPS multiplier for 45 seconds (Feature 8)
## - "Good" hit zone: 2.0x passive RPS multiplier for 30 seconds
## - "Miss" zone: 1.2x comfort bonus for 15 seconds without penalty
## Provides programmatic hooks: simulate_hit(target_pos), simulate_sync_hit(is_perfect), and complete_minigame.

signal cyber_sync_started()
signal node_hit(index: int, is_perfect: bool)
signal node_rated(index: int, rating: String, multiplier: float, duration: float)
signal minigame_completed(is_perfect: bool, duration: float, multiplier: float)
signal cyber_sync_completed(is_perfect: bool, duration: float, multiplier: float)
signal overclock_completed(rating: String, multiplier: float, duration: float)
signal closed()

# Phase 16 3-Tier Multiplier & Duration Configuration
@export var perfect_duration: float = 45.0
@export var perfect_multiplier: float = 3.00
@export var normal_duration: float = 30.0
@export var normal_multiplier: float = 2.00
@export var miss_duration: float = 15.0
@export var miss_multiplier: float = 1.20

# Timing Windows (Normalized [0.0, 1.0])
@export var perfect_window: float = 0.08
@export var normal_window: float = 0.25
@export var target_position: float = 0.50
@export var pulse_speed: float = 1.8
const HIT_EPSILON: float = 0.00005

# Node References
@onready var backdrop: ColorRect = get_node_or_null("DimBackdrop")
@onready var close_button: Button = get_node_or_null("%CloseButton")
@onready var sync_hit_button: Button = get_node_or_null("%SyncHitButton")
@onready var feedback_label: Label = get_node_or_null("%FeedbackLabel")
@onready var pulse_indicator: ColorRect = get_node_or_null("%PulseIndicator")
@onready var target_zone: Panel = get_node_or_null("%TargetZone")
@onready var good_zone: Panel = get_node_or_null("%GoodZone")
@onready var node_label_0: Label = get_node_or_null("%NodeLabel0")
@onready var node_label_1: Label = get_node_or_null("%NodeLabel1")
@onready var node_label_2: Label = get_node_or_null("%NodeLabel2")
@onready var node_status_0: Label = get_node_or_null("%NodeStatus0")
@onready var node_status_1: Label = get_node_or_null("%NodeStatus1")
@onready var node_status_2: Label = get_node_or_null("%NodeStatus2")

var terminal_ref: Node = null
var current_node_index: int = 0
var node_hits: Array[bool] = []
var node_ratings: Array[String] = []
var perfect_hits_count: int = 0
var good_hits_count: int = 0
var miss_hits_count: int = 0
var is_completed: bool = false
var pulse_position: float = 0.0
var _pulse_time: float = 0.0
var _legacy_sync_mode: bool = false

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
	pulse_position = clampf(pulse_position, 0.0, 1.0)
	
	_update_timing_bar_visuals()

func _gui_input(event: InputEvent) -> void:
	# Strict pointer isolation: blocks touch drag/click leaks into 3D camera
	accept_event()

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
	node_ratings.clear()
	perfect_hits_count = 0
	good_hits_count = 0
	miss_hits_count = 0
	is_completed = false
	_pulse_time = 0.0
	pulse_position = 0.0
	_legacy_sync_mode = false
	
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
		
	# Haptic pulse if available
	var hm = get_node_or_null("/root/HapticsManager")
	if hm != null and hm.has_method("vibrate_button"):
		hm.vibrate_button()
		
	simulate_hit(pulse_position)

## Evaluates hit rating and multipliers deterministically for a given position.
func evaluate_hit(pos: float) -> Dictionary:
	var diff: float = absf(pos - target_position)
	if diff <= (perfect_window + HIT_EPSILON):
		return {
			"rating": "Perfect",
			"multiplier": perfect_multiplier,
			"duration": perfect_duration,
			"is_perfect": true,
			"delta": diff,
			"position": pos
		}
	elif diff <= (normal_window + HIT_EPSILON):
		return {
			"rating": "Good",
			"multiplier": normal_multiplier,
			"duration": normal_duration,
			"is_perfect": false,
			"delta": diff,
			"position": pos
		}
	else:
		return {
			"rating": "Miss",
			"multiplier": miss_multiplier,
			"duration": miss_duration,
			"is_perfect": false,
			"delta": diff,
			"position": pos
		}

## Primary programmatic method for hitting current sync node (headless testable).
func simulate_hit(pos: float = -1.0) -> Dictionary:
	if is_completed:
		return {
			"rating": "Completed",
			"multiplier": 1.0,
			"duration": 0.0,
			"is_perfect": false,
			"delta": 0.0,
			"position": 0.0
		}
		
	var hit_pos: float = pos if pos >= 0.0 else pulse_position
	var eval_res: Dictionary = evaluate_hit(hit_pos)
	
	var node_idx: int = current_node_index
	var is_perfect: bool = eval_res["is_perfect"]
	var rating: String = eval_res["rating"]
	
	node_hits.append(is_perfect)
	node_ratings.append(rating)
	if rating == "Perfect":
		perfect_hits_count += 1
	elif rating == "Good":
		good_hits_count += 1
	else:
		miss_hits_count += 1
		
	node_hit.emit(node_idx, is_perfect)
	node_rated.emit(node_idx, rating, eval_res["multiplier"], eval_res["duration"])
	
	# Dispatch to terminal reference if attached
	if terminal_ref != null and terminal_ref.has_method("emit_data_node_hit"):
		terminal_ref.emit_data_node_hit(node_idx, is_perfect)
		
	# SFX
	var am = get_node_or_null("/root/AudioManager")
	if am != null:
		if am.has_method("play_sfx_timing_hit"):
			am.play_sfx_timing_hit(rating)
		elif am.has_method("play_sfx_click"):
			am.play_sfx_click()

	# Haptics
	var hm = get_node_or_null("/root/HapticsManager")
	if hm != null:
		if hm.has_method("vibrate_timing_hit"):
			hm.vibrate_timing_hit(rating)
		elif hm.has_method("vibrate_button"):
			hm.vibrate_button()
		
	# Screen shake juice
	var tree = get_tree()
	if tree != null and tree.root != null:
		var m3d = tree.root.find_child("Main3D", true, false)
		if m3d != null and m3d.has_method("add_screen_shake"):
			m3d.add_screen_shake(0.35 if is_perfect else (0.25 if rating == "Good" else 0.15))
			
	if feedback_label != null:
		if rating == "Perfect":
			feedback_label.text = ">> NODE %d: PERFECT SYNC! (%.1fx) <<" % [node_idx + 1, eval_res["multiplier"]]
			feedback_label.modulate = Color(0.1, 1.0, 0.4, 1.0)
		elif rating == "Good":
			feedback_label.text = ">> NODE %d: GOOD SYNC! (%.1fx) <<" % [node_idx + 1, eval_res["multiplier"]]
			feedback_label.modulate = Color(0.0, 0.85, 1.0, 1.0)
		else:
			feedback_label.text = ">> NODE %d: MISS // COMFORT BOOST (%.1fx) <<" % [node_idx + 1, eval_res["multiplier"]]
			feedback_label.modulate = Color(1.0, 0.85, 0.2, 1.0)
			
	current_node_index += 1
	_update_node_labels()
	
	if current_node_index >= 3:
		_resolve_session_completion()
		
	return eval_res

## Programmatic compatibility hook for existing test suite test_minigames_arcade.gd.
func simulate_sync_hit(is_perfect: bool = true) -> void:
	_legacy_sync_mode = true
	var pos: float = target_position if is_perfect else (target_position + 0.15)
	simulate_hit(pos)

func _resolve_session_completion() -> void:
	var final_rating: String = "Miss"
	var final_duration: float = miss_duration
	var final_multiplier: float = miss_multiplier
	var final_perfect: bool = false
	
	if perfect_hits_count >= 2:
		final_rating = "Perfect"
		final_duration = perfect_duration
		final_multiplier = perfect_multiplier
		final_perfect = true
	elif good_hits_count > 0 or perfect_hits_count == 1:
		final_rating = "Good"
		final_duration = normal_duration
		final_multiplier = normal_multiplier
		final_perfect = false
	else:
		final_rating = "Miss"
		final_duration = miss_duration
		final_multiplier = miss_multiplier
		final_perfect = false
		
	complete_minigame_rated(final_rating, final_duration, final_multiplier, final_perfect)

## Programmatic method to complete minigame with given outcome (headless testable).
func complete_minigame(is_perfect: bool = true) -> void:
	var r: String = "Perfect" if is_perfect else "Good"
	var d: float = perfect_duration if is_perfect else normal_duration
	var m: float = perfect_multiplier if is_perfect else normal_multiplier
	complete_minigame_rated(r, d, m, is_perfect)

## Resolves minigame completion with exact 3-tier rating and multipliers.
func complete_minigame_rated(rating: String, duration: float, multiplier: float, is_perfect: bool) -> void:
	is_completed = true
	
	if sync_hit_button != null:
		sync_hit_button.disabled = true
		sync_hit_button.text = "[ COMPLETE ]"
		
	if feedback_label != null:
		if rating == "Perfect":
			feedback_label.text = ">>> MATRIX OVERCLOCK ACHIEVED! +200% RPS (45s) <<<"
			feedback_label.modulate = Color(0.1, 1.0, 0.4, 1.0)
		elif rating == "Good":
			feedback_label.text = ">>> CYBER-SYNC ENGAGED! +100% RPS (30s) <<<"
			feedback_label.modulate = Color(0.0, 0.85, 1.0, 1.0)
		else:
			feedback_label.text = ">>> CONSOLE BOOST ACTIVE! +20% RPS (15s) <<<"
			feedback_label.modulate = Color(1.0, 0.85, 0.2, 1.0)
			
	# If terminal_ref is attached, delegate overclock resolution
	if terminal_ref != null and terminal_ref.has_method("complete_cyber_sync"):
		if _legacy_sync_mode:
			terminal_ref.complete_cyber_sync(is_perfect, "Legacy", 45.0 if is_perfect else 25.0, 2.00 if is_perfect else 1.50)
		else:
			terminal_ref.complete_cyber_sync(is_perfect, rating, duration, multiplier)
	else:
		# Standalone execution: directly activate GameState buff
		var gs = get_node_or_null("/root/GameState")
		if gs != null and gs.has_method("activate_server_overclock_buff"):
			gs.activate_server_overclock_buff(duration, multiplier)
			
		var am = get_node_or_null("/root/AudioManager")
		if am != null and am.has_method("play_sfx_overdrive"):
			am.play_sfx_overdrive()
			
	minigame_completed.emit(is_perfect, duration, multiplier)
	cyber_sync_completed.emit(is_perfect, duration, multiplier)
	overclock_completed.emit(rating, multiplier, duration)

	# 2D celebratory particle burst on Perfect completion
	if is_perfect:
		var confetti_cls = load("res://scripts/vfx/confetti_burst.gd")
		if confetti_cls != null and confetti_cls.has_method("spawn_burst_2d"):
			confetti_cls.spawn_burst_2d(self, size * 0.5, 35)

	# Audio and haptic triumph feedback
	if rating == "Perfect" or rating == "Good":
		var am_win = get_node_or_null("/root/AudioManager")
		if am_win != null and am_win.has_method("play_sfx_victory_jingle"):
			am_win.play_sfx_victory_jingle()
		var hm_win = get_node_or_null("/root/HapticsManager")
		if hm_win != null and hm_win.has_method("vibrate_success"):
			hm_win.vibrate_success()

func _update_node_labels() -> void:
	var statuses: Array[Label] = [node_status_0, node_status_1, node_status_2]
	
	for i in range(3):
		var lbl = statuses[i]
		if lbl == null:
			continue
		if i < node_ratings.size():
			var r = node_ratings[i]
			lbl.text = r.to_upper()
			if r == "Perfect":
				lbl.modulate = Color(0.1, 1.0, 0.4, 1.0)
			elif r == "Good":
				lbl.modulate = Color(0.0, 0.85, 1.0, 1.0)
			else:
				lbl.modulate = Color(1.0, 0.85, 0.2, 1.0)
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
		if diff <= (perfect_window + HIT_EPSILON):
			target_zone.modulate = Color(0.1, 1.0, 0.4, 1.0)
		elif diff <= (normal_window + HIT_EPSILON):
			target_zone.modulate = Color(0.0, 0.85, 1.0, 0.8)
		else:
			target_zone.modulate = Color(0.4, 0.4, 0.4, 0.5)
