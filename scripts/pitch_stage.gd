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

var is_pitch_ready: bool = true
var cooldown_time_remaining: float = 0.0
var total_funding_secured: float = 0.0
var pitch_count: int = 0

@onready var interaction_area: Area3D = get_node_or_null("InteractionArea")
@onready var prompt_label: Label3D = get_node_or_null("PromptLabel3D")
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
		
	if interaction_area != null:
		interaction_area.body_entered.connect(_on_interaction_body_entered)
		interaction_area.body_exited.connect(_on_interaction_body_exited)
		
	if confetti_particles != null:
		confetti_particles.emitting = false

func _process(delta: float) -> void:
	_anim_time += delta
	
	# Subtle Chibi investor idle animation
	if angel_investor != null:
		angel_investor.position.y = _base_investor_y + sin(_anim_time * 2.2) * 0.015
		
	# Cooldown countdown
	if not is_pitch_ready or cooldown_time_remaining > 0.0:
		cooldown_time_remaining -= delta
		if cooldown_time_remaining <= 0.0:
			cooldown_time_remaining = 0.0
			is_pitch_ready = true
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
	return is_pitch_ready and cooldown_time_remaining <= 0.0

## Alias for interact()
func pitch_investor() -> void:
	interact()

## Primary interaction method
func interact() -> void:
	pitch_stage_interacted.emit()
	
	if not can_pitch():
		var am_fail = get_node_or_null("/root/AudioManager")
		if am_fail != null and am_fail.has_method("play_sfx_click"):
			am_fail.play_sfx_click()
		return
		
	is_pitch_ready = false
	cooldown_time_remaining = pitch_cooldown
	pitch_started.emit()
	
	# Calculate pitch valuation grant
	var gs = get_node_or_null("/root/GameState")
	var base_grant: float = randf_range(min_grant, max_grant)
	var level_bonus: float = 0.0
	if gs != null and gs.has_method("get_idle_level"):
		level_bonus = float(gs.get_idle_level()) * 100.0
	var total_grant: float = roundf(base_grant + level_bonus)
	total_grant = maxf(min_grant, total_grant)
	
	# Award Energy grant to GameState
	if gs != null:
		if gs.has_method("earn_energy"):
			gs.earn_energy(total_grant)
		else:
			gs.energy += total_grant
			gs.total_energy_earned += total_grant
			gs.energy_changed.emit(gs.energy, total_grant)
			
	total_funding_secured += total_grant
	pitch_count += 1
	
	# Visual juice: confetti explosion
	if confetti_particles != null:
		confetti_particles.restart()
		confetti_particles.emitting = true
		
	# Visual juice: stage spotlight flash
	if stage_spotlight != null:
		var tw = create_tween()
		tw.tween_property(stage_spotlight, "light_energy", 5.0, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(stage_spotlight, "light_energy", 2.5, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		
	# Visual juice: investor celebratory arm wave
	if investor_right_arm != null:
		var arm_tw = create_tween()
		arm_tw.tween_property(investor_right_arm, "rotation_degrees:x", -50.0, 0.25)
		arm_tw.tween_property(investor_right_arm, "rotation_degrees:x", 0.0, 0.45)
		
	# SFX juice: research celebratory chime or briefcase pickup
	var am = get_node_or_null("/root/AudioManager")
	if am != null:
		if am.has_method("play_sfx_research"):
			am.play_sfx_research()
		elif am.has_method("play_sfx_pickup"):
			am.play_sfx_pickup("briefcase")
		elif am.has_method("play_sfx_click"):
			am.play_sfx_click()
			
	pitch_rewarded.emit(total_grant, total_funding_secured)
	pitch_completed.emit(total_grant)
	_update_ui_prompts()

func _update_ui_prompts() -> void:
	var label_str: String = action_label
	if not can_pitch():
		label_str = "Next Pitch (%.0fs)" % ceilf(cooldown_time_remaining)
		if prompt_label != null:
			prompt_label.text = "[E] Next Pitch in %.0fs" % ceilf(cooldown_time_remaining)
	else:
		label_str = "Pitch [E]"
		if prompt_label != null:
			prompt_label.text = prompt_text
			
	if _player_in_range:
		var tc = _find_touch_controls()
		if tc != null and tc.has_method("register_interactable"):
			tc.register_interactable(self, label_str)
