extends StaticBody3D
class_name CoffeeMachine3D

## Super-Espresso Brew Lab 3D Station for IdleArcade (Phase 11 M3).
## Interactive station situated in the R&D Lab at (-19, 0, 4).
## Features a Chibi low-poly espresso machine (< 1,000 tris) with copper boiler,
## pressure gauge, steam CPUParticles3D, glowing cups, and sweet-spot minigame.
## Awards the legendary Unicorn Espresso (+50% Avatar speed, +20% incubator workers).

signal brew_started()
signal brew_completed(unicorn_espresso: bool)
signal brew_ended()
signal espresso_buff_started(duration: float, avatar_mult: float, worker_mult: float)
signal coffee_machine_interacted()
signal office_hyper_focus_activated(duration: float, speed_mult: float)

@export var prompt_text: String = "[E] Super-Espresso Brew Lab"
@export var action_label: String = "Brew [E]"
@export var brew_cooldown: float = 60.0
@export var avatar_speed_boost: float = 1.50
@export var worker_speed_boost: float = 1.20
@export var buff_duration: float = 60.0

var is_brewing: bool = false
var is_on_cooldown: bool = false
var cooldown_time_remaining: float = 0.0

var _player_in_range: bool = false
var _avatar_ref: Node3D = null
var _time: float = 0.0
var _minigame_instance: Control = null

@onready var interaction_area: Area3D = get_node_or_null("InteractionArea")
@onready var prompt_label: Label3D = get_node_or_null("PromptLabel3D")
@onready var status_label: Label3D = get_node_or_null("StatusLabel3D")
@onready var steam_particles: CPUParticles3D = get_node_or_null("Visuals/SteamParticles")
@onready var needle_root: Node3D = get_node_or_null("Visuals/PressureGauge/NeedleRoot")
@onready var cup_left_light: OmniLight3D = get_node_or_null("Visuals/CupLeft/CupLight")
@onready var cup_right_light: OmniLight3D = get_node_or_null("Visuals/CupRight/CupLight")

func _ready() -> void:
	if not is_in_group("interactables"):
		add_to_group("interactables")
	if not is_in_group("coffee_machines"):
		add_to_group("coffee_machines")
	if not is_in_group("stations"):
		add_to_group("stations")
		
	if prompt_label != null:
		prompt_label.text = prompt_text
		prompt_label.visible = false
		
	if interaction_area != null:
		if not interaction_area.body_entered.is_connected(_on_interaction_body_entered):
			interaction_area.body_entered.connect(_on_interaction_body_entered)
		if not interaction_area.body_exited.is_connected(_on_interaction_body_exited):
			interaction_area.body_exited.connect(_on_interaction_body_exited)
			
	_update_status_display()

func _process(delta: float) -> void:
	_time += delta
	
	# Cooldown decay
	if is_on_cooldown:
		cooldown_time_remaining = maxf(0.0, cooldown_time_remaining - delta)
		if cooldown_time_remaining <= 0.0:
			is_on_cooldown = false
			_update_status_display()
		else:
			_update_status_display()
			
	# Dynamic visuals
	if needle_root != null:
		var needle_angle: float = 0.0
		if is_brewing:
			needle_angle = 0.8 + sin(_time * 14.0) * 0.15
		elif is_on_cooldown:
			needle_angle = -0.6 + sin(_time * 2.0) * 0.05
		else:
			needle_angle = -0.2 + sin(_time * 3.0) * 0.08
		needle_root.rotation.z = needle_angle
		
	if steam_particles != null:
		steam_particles.emitting = is_brewing or (not is_on_cooldown and sin(_time * 2.0) > 0.3)
		
	if cup_left_light != null:
		cup_left_light.light_energy = 0.8 + sin(_time * 4.0) * 0.3 if not is_on_cooldown else 0.2
	if cup_right_light != null:
		cup_right_light.light_energy = 0.8 + cos(_time * 4.0) * 0.3 if not is_on_cooldown else 0.2

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

## Availability query for brewing
func can_brew() -> bool:
	return not is_brewing and not is_on_cooldown

## Primary interaction method
func interact() -> void:
	coffee_machine_interacted.emit()
	
	if not can_brew():
		var am_fail = get_node_or_null("/root/AudioManager")
		if am_fail != null and am_fail.has_method("play_sfx_click"):
			am_fail.play_sfx_click()
		return
		
	start_brewing()

## Initiates brewing sequence and opens sweet-spot minigame
func start_brewing() -> void:
	if not can_brew():
		return
		
	is_brewing = true
	brew_started.emit()
	
	if steam_particles != null:
		steam_particles.emitting = true
		
	_update_status_display()
	_open_minigame_overlay()

## Completes the brew cycle and activates buffs
func complete_brew(success: bool = true) -> void:
	is_brewing = false
	brew_completed.emit(success)
	
	if success:
		# 1. Apply +50% Avatar speed boost for 60 seconds
		var av = _avatar_ref
		if av == null and get_tree() != null:
			var players = get_tree().get_nodes_in_group("player")
			if players.size() > 0:
				av = players[0]
		if av != null and av.has_method("apply_speed_boost"):
			av.apply_speed_boost(avatar_speed_boost, buff_duration)
			
		# 2. Activate Unicorn Espresso buff in GameState (+20% worker multiplier)
		var gs = get_node_or_null("/root/GameState")
		if gs != null and gs.has_method("activate_unicorn_espresso_buff"):
			gs.activate_unicorn_espresso_buff(buff_duration)
			
		espresso_buff_started.emit(buff_duration, avatar_speed_boost, worker_speed_boost)
		
		# 3. Synchronize with campus office: trigger GameState coffee break / 60s Hyper-Focus
		trigger_office_synergy(buff_duration)
		
		# 4. Audio juice
		var am = get_node_or_null("/root/AudioManager")
		if am != null:
			if am.has_method("play_sfx_pickup"):
				am.play_sfx_pickup("coffee")
			elif am.has_method("play_sfx_confetti"):
				am.play_sfx_confetti()
				
		# 5. Screen shake
		var tree = get_tree()
		if tree != null and tree.current_scene != null and tree.current_scene.has_method("add_screen_shake"):
			tree.current_scene.add_screen_shake(0.30)
			
		# 6. Cooldown engagement (60s)
		is_on_cooldown = true
		cooldown_time_remaining = brew_cooldown
	
	brew_ended.emit()
	_update_status_display()
	_close_minigame_overlay()

## Synchronizes Unicorn Espresso brew with the campus office: activates 60s Hyper-Focus across all Chibi workers.
func trigger_office_synergy(duration: float = 60.0) -> void:
	var gs = get_node_or_null("/root/GameState")
	if gs != null:
		if gs.has_method("give_team_coffee_break"):
			gs.give_team_coffee_break()
		elif gs.has_method("activate_office_hyper_focus"):
			gs.activate_office_hyper_focus(duration)

	# Direct notification to OfficeExpansion3D instances in the scene
	var tree = get_tree()
	if tree != null:
		var offices = tree.get_nodes_in_group("staff_offices")
		for office in offices:
			if office.has_method("activate_hyper_focus"):
				office.activate_hyper_focus(duration, 1.50)
			elif office.has_method("_on_unicorn_espresso_activated"):
				office._on_unicorn_espresso_activated(duration, 1.50)

		# Also notify any standalone chibi worker nodes in the tree
		var workers = tree.get_nodes_in_group("chibi_workers")
		for worker in workers:
			if worker.has_method("set_hyper_focus"):
				worker.set_hyper_focus(true, duration)
				if worker.has_method("play_celebration"):
					worker.play_celebration(1.0)

	office_hyper_focus_activated.emit(duration, 1.50)

## Cancels active brew
func cancel_brew() -> void:
	is_brewing = false
	brew_ended.emit()
	_update_status_display()
	_close_minigame_overlay()

func _update_status_display() -> void:
	if status_label == null:
		return
	if is_on_cooldown:
		var secs: int = int(ceilf(cooldown_time_remaining))
		status_label.text = "Espresso Cooling (%ds)" % secs
		status_label.modulate = Color(1.0, 0.65, 0.2, 1.0)
	elif is_brewing:
		status_label.text = "[BREWING ESPRESSO...]"
		status_label.modulate = Color(0.96, 0.75, 0.35, 1.0)
	else:
		status_label.text = "[READY TO BREW]"
		status_label.modulate = Color(0.3, 1.0, 0.5, 1.0)

func _open_minigame_overlay() -> void:
	if _minigame_instance != null and is_instance_valid(_minigame_instance):
		_minigame_instance.visible = true
		if _minigame_instance.has_method("open_minigame"):
			_minigame_instance.open_minigame()
		return
		
	var minigame_scene = load("res://scenes/ui/espresso_brew_minigame.tscn")
	if minigame_scene == null:
		return
		
	_minigame_instance = minigame_scene.instantiate()
	if _minigame_instance.has_signal("brew_completed"):
		_minigame_instance.brew_completed.connect(complete_brew)
	if _minigame_instance.has_signal("brew_cancelled"):
		_minigame_instance.brew_cancelled.connect(cancel_brew)
		
	var tree = get_tree()
	if tree != null and tree.current_scene != null:
		var canvas = CanvasLayer.new()
		canvas.name = "EspressoBrewCanvas"
		canvas.layer = 9
		canvas.add_child(_minigame_instance)
		tree.current_scene.add_child(canvas)
	else:
		add_child(_minigame_instance)
		
	if _minigame_instance.has_method("open_minigame"):
		_minigame_instance.open_minigame()

func _close_minigame_overlay() -> void:
	if _minigame_instance != null and is_instance_valid(_minigame_instance):
		if _minigame_instance.has_method("close_minigame"):
			_minigame_instance.close_minigame()
		else:
			_minigame_instance.visible = false
