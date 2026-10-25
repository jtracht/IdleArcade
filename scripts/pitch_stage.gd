extends StaticBody3D
class_name PitchStage

## 3D Courtyard Pitch Stage for IdleArcade (Phase 9 Milestone 2).
## Interactive presentation platform situated in the Courtyard at (0, 0, 18).
## Features an open-air stage with oak planks, podium, microphone, spotlight,
## Chibi Angel Investor (suit, tie, sunglasses), confetti particle explosion,
## dynamic TouchControls integration ("Pitch [E]"), and grants +1,000 to +5,000 Energy.

signal pitch_started()
signal pitch_rewarded(reward_amount: float, total_funding: float)
signal pitch_completed(energy_awarded: float)
signal pitch_stage_interacted()

@export var prompt_text: String = "[E] Angel Investor Pitch"
@export var action_label: String = "Pitch [E]"
@export var pitch_cooldown: float = 60.0
@export var min_grant: float = 1000.0
@export var max_grant: float = 5000.0

# Phase 16 Milestone 1: Station State Machine & Canonical ID
const STATION_ID: String = "pitch_stage"

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
var is_on_cooldown: bool = false
var _minigame_instance: Control = null

var is_pitch_ready: bool = true
var cooldown_time_remaining: float = 0.0
var total_funding_secured: float = 0.0
var pitch_count: int = 0

@onready var interaction_area: Area3D = get_node_or_null("InteractionArea")
@onready var prompt_label: Label3D = get_node_or_null("PromptLabel3D")
@onready var status_label: Label3D = get_node_or_null("StatusLabel3D")
@onready var stage_spotlight: SpotLight3D = get_node_or_null("Visuals/StageSpotlight")
@onready var confetti_particles: CPUParticles3D = get_node_or_null("Visuals/ConfettiExplosion")
@onready var angel_investor: Node3D = get_node_or_null("Visuals/ChibiAngelInvestor")
@onready var investor_right_arm: MeshInstance3D = get_node_or_null("Visuals/ChibiAngelInvestor/RightArm")

var _player_in_range: bool = false
var _avatar_ref: Node3D = null
var _anim_time: float = 0.0
var _base_investor_y: float = 0.35

func _ready() -> void:
	add_to_group("stages")
	add_to_group("pitch_stages")
	add_to_group("interactables")
	
	if angel_investor != null:
		_base_investor_y = angel_investor.position.y
		
	if prompt_label != null:
		prompt_label.text = prompt_text
		prompt_label.visible = false

	# Ensure billboarded StatusLabel3D exists dynamically if absent from scene
	if status_label == null:
		status_label = Label3D.new()
		status_label.name = "StatusLabel3D"
		status_label.transform.origin = Vector3(0.0, 3.0, 0.0)
		status_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		status_label.font_size = 20
		status_label.outline_size = 5
		status_label.outline_modulate = Color(0.02, 0.1, 0.04, 0.9)
		status_label.modulate = Color("1aff66")
		status_label.text = "[READY]"
		add_child(status_label)
	else:
		status_label.text = "[READY]"
		status_label.modulate = Color("1aff66")
		status_label.visible = true

	var gs = get_node_or_null("/root/GameState")
	if gs != null:
		if gs.has_method("get_station_cooldown"):
			var saved_cd: float = gs.get_station_cooldown(STATION_ID)
			if saved_cd > 0.0:
				is_pitch_ready = false
				is_on_cooldown = true
				cooldown_time_remaining = saved_cd
				current_state = StationState.STATE_COOLDOWN
			else:
				is_pitch_ready = true
				is_on_cooldown = false
				current_state = StationState.STATE_READY
		else:
			is_pitch_ready = true
			is_on_cooldown = false
			current_state = StationState.STATE_READY
		if gs.has_signal("station_cooldown_started") and not gs.station_cooldown_started.is_connected(_on_station_cooldown_started):
			gs.station_cooldown_started.connect(_on_station_cooldown_started)
		if gs.has_signal("station_cooldown_ended") and not gs.station_cooldown_ended.is_connected(_on_station_cooldown_ended):
			gs.station_cooldown_ended.connect(_on_station_cooldown_ended)
	else:
		is_pitch_ready = true
		is_on_cooldown = false
		current_state = StationState.STATE_READY

	if interaction_area != null:
		interaction_area.body_entered.connect(_on_interaction_body_entered)
		interaction_area.body_exited.connect(_on_interaction_body_exited)
		
	if confetti_particles != null:
		confetti_particles.emitting = false

	_update_ui_prompts()

func _process(delta: float) -> void:
	_anim_time += delta
	
	# Subtle Chibi investor idle animation
	if angel_investor != null:
		angel_investor.position.y = _base_investor_y + sin(_anim_time * 2.2) * 0.015
		
	# Cooldown countdown
	if not is_pitch_ready or is_on_cooldown or current_state == StationState.STATE_COOLDOWN or cooldown_time_remaining > 0.0:
		current_state = StationState.STATE_COOLDOWN
		is_pitch_ready = false
		is_on_cooldown = true
		cooldown_time_remaining = maxf(0.0, cooldown_time_remaining - delta)

		if cooldown_time_remaining <= 0.0:
			cooldown_time_remaining = 0.0
			is_pitch_ready = true
			is_on_cooldown = false
			current_state = StationState.STATE_READY
			var gs = get_node_or_null("/root/GameState")
			if gs != null and gs.has_method("set_station_cooldown") and gs.get_station_cooldown(STATION_ID) > 0.0:
				gs.set_station_cooldown(STATION_ID, 0.0)
			_update_ui_prompts()
		else:
			_update_ui_prompts()

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

## Availability query for pitch presentation
func can_pitch() -> bool:
	if current_state == StationState.STATE_PLAYING or current_state == StationState.STATE_COOLDOWN:
		return false
	if is_minigame_active or not is_pitch_ready or is_on_cooldown or cooldown_time_remaining > 0.0:
		return false
	var gs = get_node_or_null("/root/GameState")
	if gs != null and gs.has_method("is_station_on_cooldown") and gs.is_station_on_cooldown(STATION_ID):
		return false
	return true

## Availability query for generic station activation
func can_activate() -> bool:
	return can_pitch()

## Returns true if station is in ready state
func is_ready() -> bool:
	return current_state == StationState.STATE_READY and can_pitch()

## Alias for interact()
func pitch_investor() -> void:
	interact()

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

## Primary interaction method
func interact() -> void:
	pitch_stage_interacted.emit()
	
	if not can_pitch():
		var am_fail = get_node_or_null("/root/AudioManager")
		if am_fail != null and am_fail.has_method("play_sfx_click"):
			am_fail.play_sfx_click()
		return

	if ResourceLoader.exists("res://scenes/ui/pitch_stage_minigame.tscn"):
		var modal = open_pitch_minigame()
		if DisplayServer.get_name() == "headless" and modal != null and modal.has_method("complete_pitch"):
			modal.complete_pitch(true)
	else:
		_resolve_direct_grant()

func open_pitch_minigame() -> Node:
	current_state = StationState.STATE_PLAYING
	is_minigame_active = true
	_gate_avatar_and_controls()
	_update_ui_prompts()

	if _minigame_instance != null and is_instance_valid(_minigame_instance):
		_minigame_instance.visible = true
		if _minigame_instance.has_signal("pitch_completed"):
			if not _minigame_instance.pitch_completed.is_connected(_on_pitch_minigame_completed):
				_minigame_instance.pitch_completed.connect(_on_pitch_minigame_completed)
		if _minigame_instance.has_signal("closed"):
			if not _minigame_instance.closed.is_connected(_on_pitch_minigame_closed):
				_minigame_instance.closed.connect(_on_pitch_minigame_closed)
		if _minigame_instance.has_method("open_minigame"):
			_minigame_instance.open_minigame(self)
		return _minigame_instance

	var minigame_scene = load("res://scenes/ui/pitch_stage_minigame.tscn")
	if minigame_scene == null:
		is_minigame_active = false
		_restore_avatar_and_controls()
		if not is_pitch_ready or cooldown_time_remaining > 0.0:
			current_state = StationState.STATE_COOLDOWN
		else:
			current_state = StationState.STATE_READY
		_update_ui_prompts()
		return null

	_minigame_instance = minigame_scene.instantiate()

	if _minigame_instance.has_signal("pitch_completed"):
		_minigame_instance.pitch_completed.connect(_on_pitch_minigame_completed)
	if _minigame_instance.has_signal("closed"):
		_minigame_instance.closed.connect(_on_pitch_minigame_closed)

	var tree = get_tree()
	var parent_layer: Node = null
	if tree != null and tree.root != null:
		var m3d = tree.root.find_child("Main3D", true, false)
		if m3d != null and m3d.has_method("get_minigame_layer"):
			parent_layer = m3d.get_minigame_layer()
		if parent_layer == null:
			parent_layer = tree.root.find_child("MinigameLayer", true, false)
		if parent_layer == null:
			parent_layer = tree.root.find_child("DialogueLayer", true, false)
		if parent_layer == null:
			parent_layer = tree.current_scene

	if parent_layer != null:
		parent_layer.add_child(_minigame_instance)
	else:
		add_child(_minigame_instance)

	if _minigame_instance.has_method("open_minigame"):
		_minigame_instance.open_minigame(self)

	pitch_started.emit()
	return _minigame_instance

## Alias for open_pitch_minigame() for uniform station launcher compatibility
func start_pitch_minigame() -> Node:
	return open_pitch_minigame()

func _on_pitch_minigame_completed(_streak: int, grant_awarded: float) -> void:
	_apply_grant_rewards(grant_awarded)

func _on_pitch_minigame_closed() -> void:
	is_minigame_active = false
	_restore_avatar_and_controls()
	if not is_pitch_ready or cooldown_time_remaining > 0.0:
		current_state = StationState.STATE_COOLDOWN
	else:
		current_state = StationState.STATE_READY
	_update_ui_prompts()

func _resolve_direct_grant() -> void:
	var gs = get_node_or_null("/root/GameState")
	var base_grant: float = randf_range(min_grant, max_grant)
	var level_bonus: float = 0.0
	if gs != null and gs.has_method("get_idle_level"):
		level_bonus = float(gs.get_idle_level()) * 100.0
	var total_grant: float = maxf(min_grant, roundf(base_grant + level_bonus))
	_apply_grant_rewards(total_grant)

func _format_popup_energy(amount: float) -> String:
	var int_val: int = int(roundf(amount))
	var s: String = str(abs(int_val))
	var res: String = ""
	var count: int = 0
	for i in range(s.length() - 1, -1, -1):
		res = s[i] + res
		count += 1
		if count % 3 == 0 and i > 0:
			res = "." + res
	return res

func spawn_score_popup(text_msg: String, text_color: Color = Color(1.0, 0.85, 0.2)) -> Label3D:
	var target_parent = get_parent() if get_parent() != null else self
	var origin_pos: Vector3 = global_position if is_inside_tree() else position
	var spawn_pos: Vector3 = origin_pos + Vector3(0.0, 3.2, 0.0)
	var popup_cls = load("res://scripts/vfx/floating_score_popup.gd")
	if popup_cls != null and popup_cls.has_method("spawn_popup_3d"):
		return popup_cls.spawn_popup_3d(target_parent, spawn_pos, text_msg, text_color, 1.4, 1.8, 30)
		
	var label := Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = 30
	label.outline_size = 7
	label.text = text_msg
	label.modulate = text_color
	target_parent.add_child(label)
	if label.is_inside_tree():
		label.top_level = true
		label.global_position = spawn_pos
		var tw = label.create_tween().set_parallel(true)
		tw.tween_property(label, "position:y", label.position.y + 1.6, 1.3).set_ease(Tween.EASE_OUT)
		tw.tween_property(label, "modulate:a", 0.0, 0.6).set_delay(0.7)
		tw.chain().tween_callback(label.queue_free)
	else:
		label.position = spawn_pos
		label.queue_free()
	return label

func _apply_grant_rewards(total_grant: float) -> void:
	is_pitch_ready = false
	is_on_cooldown = true
	current_state = StationState.STATE_COOLDOWN
	cooldown_time_remaining = pitch_cooldown
	pitch_started.emit()

	var gs = get_node_or_null("/root/GameState")
	if gs != null:
		if gs.has_method("earn_energy"):
			gs.earn_energy(total_grant)
		else:
			gs.energy += total_grant
			gs.total_energy_earned += total_grant
			gs.energy_changed.emit(gs.energy, total_grant)
		if gs.has_method("set_station_cooldown"):
			gs.set_station_cooldown(STATION_ID, pitch_cooldown)

	total_funding_secured += total_grant
	pitch_count += 1

	# Feature 26: Billboarded 3D Score Popup
	var formatted_amt: String = _format_popup_energy(total_grant)
	var popup_text: String = "+%s ENERGY!" % formatted_amt
	spawn_score_popup(popup_text, Color(1.0, 0.85, 0.2))

	if confetti_particles != null:
		confetti_particles.restart()
		confetti_particles.emitting = true
	var confetti_cls = load("res://scripts/vfx/confetti_burst.gd")
	if confetti_cls != null and confetti_cls.has_method("spawn_burst_3d"):
		confetti_cls.spawn_burst_3d(get_parent() if get_parent() != null else self, global_position + Vector3(0.0, 1.8, 0.0), 60)

	var tree = get_tree()
	if tree != null and tree.root != null:
		var m3d = tree.root.find_child("Main3D", true, false)
		if m3d != null and m3d.has_method("add_screen_shake"):
			m3d.add_screen_shake(0.40)

	if stage_spotlight != null:
		var tw = create_tween()
		tw.tween_property(stage_spotlight, "light_energy", 5.0, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(stage_spotlight, "light_energy", 2.5, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)

	if investor_right_arm != null:
		var arm_tw = create_tween()
		arm_tw.tween_property(investor_right_arm, "rotation_degrees:x", -50.0, 0.25)
		arm_tw.tween_property(investor_right_arm, "rotation_degrees:x", 0.0, 0.45)

	var am = get_node_or_null("/root/AudioManager")
	if am != null:
		if am.has_method("play_sfx_confetti"):
			am.play_sfx_confetti()
		elif am.has_method("play_sfx_research"):
			am.play_sfx_research()
		elif am.has_method("play_sfx_pickup"):
			am.play_sfx_pickup("briefcase")
		elif am.has_method("play_sfx_click"):
			am.play_sfx_click()

	pitch_rewarded.emit(total_grant, total_funding_secured)
	pitch_completed.emit(total_grant)
	_update_ui_prompts()

func _on_station_cooldown_started(s_id: String, duration: float) -> void:
	if s_id == STATION_ID:
		is_pitch_ready = false
		is_on_cooldown = true
		cooldown_time_remaining = duration
		if not is_minigame_active:
			current_state = StationState.STATE_COOLDOWN
		_update_ui_prompts()

func _on_station_cooldown_ended(s_id: String) -> void:
	if s_id == STATION_ID:
		cooldown_time_remaining = 0.0
		is_pitch_ready = true
		is_on_cooldown = false
		if not is_minigame_active:
			current_state = StationState.STATE_READY
		_update_ui_prompts()

func _update_ui_prompts() -> void:
	var label_str: String = action_label
	if is_minigame_active or current_state == StationState.STATE_PLAYING:
		label_str = "Pitching..."
		if prompt_label != null:
			prompt_label.text = "[E] Pitch in Progress"
		if status_label != null:
			status_label.text = "[ACTIVE]"
			status_label.modulate = Color("00e5ff")
	elif not can_pitch() or is_on_cooldown or current_state == StationState.STATE_COOLDOWN or cooldown_time_remaining > 0.0:
		label_str = "Next Pitch (%.0fs)" % ceilf(cooldown_time_remaining)
		if prompt_label != null:
			prompt_label.text = "[E] Next Pitch in %.0fs" % ceilf(cooldown_time_remaining)
		if status_label != null:
			status_label.text = "Cooling (%ds)" % int(ceilf(cooldown_time_remaining))
			status_label.modulate = Color("ffaa1a")
	else:
		label_str = "Pitch [E]"
		if prompt_label != null:
			prompt_label.text = prompt_text
		if status_label != null:
			status_label.text = "[READY]"
			status_label.modulate = Color("1aff66")

	if _player_in_range:
		var tc = _find_touch_controls()
		if tc != null and tc.has_method("register_interactable"):
			tc.register_interactable(self, label_str)
