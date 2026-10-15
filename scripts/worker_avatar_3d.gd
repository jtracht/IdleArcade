extends CharacterBody3D
class_name WorkerAvatar3D

## Living Mini-Worker Avatar for IdleArcade (Phase 6).
## Populates the Startup Incubator / Dev Hub ("Spate mit kleinen Avataren").
## Features an autonomous state machine (TYPING, WALKING, COFFEE_BREAK, CELEBRATING),
## procedural animations, witty dialogue bubbles, and micro-bonus generation.

signal worker_interacted(worker_name: String, role: String, bonus: float)
signal state_changed(new_state: String)

enum State {
	TYPING,
	WALKING,
	COFFEE_BREAK,
	CELEBRATING
}

@export var role: String = "coder" # "intern", "coder", "architect", "marketer"
@export var worker_name: String = "Sam"
@export var worker_title: String = "Fullstack Dev"
@export var base_speed: float = 3.2
@export var patrol_targets: Array = []
@export var home_desk_position: Vector3 = Vector3.ZERO

var current_state: State = State.TYPING
var _state_timer: float = 0.0
var _target_destination: Vector3 = Vector3.ZERO
var _has_target: bool = false
var _anim_time: float = 0.0
var _speech_timer: float = 0.0
var _interaction_cooldown: float = 0.0

@onready var visuals: Node3D = get_node_or_null("Visuals")
@onready var body_mesh: MeshInstance3D = get_node_or_null("Visuals/BodyMesh")
@onready var name_label: Label3D = get_node_or_null("Visuals/NameLabel3D")
@onready var speech_bubble: Label3D = get_node_or_null("Visuals/SpeechBubble3D")
@onready var code_particles: CPUParticles3D = get_node_or_null("Visuals/CodeParticles")
@onready var interaction_area: Area3D = get_node_or_null("InteractionArea")
@onready var chibi_root: Node3D = get_node_or_null("Visuals/ChibiRoot")
@onready var chibi_torso: MeshInstance3D = get_node_or_null("Visuals/ChibiRoot/Torso")
@onready var visor_emote: Label3D = get_node_or_null("Visuals/ChibiRoot/VisorEmoteLabel")
@onready var laptop_root: Node3D = get_node_or_null("Visuals/ChibiRoot/LaptopRoot")
@onready var laptop_screen: MeshInstance3D = get_node_or_null("Visuals/ChibiRoot/LaptopRoot/LaptopScreen")
@onready var coffee_mug: Node3D = get_node_or_null("Visuals/ChibiRoot/CoffeeMug")
@onready var steam_particles: CPUParticles3D = get_node_or_null("Visuals/ChibiRoot/CoffeeMug/SteamParticles")
@onready var left_arm: Node3D = get_node_or_null("Visuals/ChibiRoot/LeftArm")
@onready var right_arm: Node3D = get_node_or_null("Visuals/ChibiRoot/RightArm")
@onready var left_leg: Node3D = get_node_or_null("Visuals/ChibiRoot/LeftLeg")
@onready var right_leg: Node3D = get_node_or_null("Visuals/ChibiRoot/RightLeg")

const WITTY_QUOTES = {
	"intern": [
		"Compiling... 99%",
		"Is this going to prod? 🚀",
		"Can I get a code review?",
		"Coffee is fuel ☕",
		"I just fixed a typo in the docs!"
	],
	"coder": [
		"It works on my machine! 💻",
		"Converting caffeine into code ☕",
		"Fixed 1 bug... found 3 more 🐛",
		"LGTM! Merging to main 🚀",
		"Writing tests before code... always ✅"
	],
	"architect": [
		"Microservices or monolith?",
		"Zero downtime deployment! ⚡",
		"All server nodes humming at 99.999% 🌐",
		"Refactoring technical debt... 🏗️",
		"Kubernetes cluster is green!"
	],
	"marketer": [
		"Our viral loop is growing 300%! 📈",
		"Product-market fit achieved! 🎯",
		"New campaign launching now! 🔥",
		"Organic traffic is soaring 👥",
		"Investor deck ready! 💼"
	]
}

func _ready() -> void:
	if not is_in_group("workers"):
		add_to_group("workers")
		
	collision_layer = 1
	collision_mask = 1
	
	_apply_role_styling()
	_update_accessories_for_state(current_state)
	_reset_state_timer()
	
	if home_desk_position == Vector3.ZERO:
		if is_inside_tree():
			home_desk_position = global_position
		else:
			home_desk_position = position
		
	if interaction_area != null:
		interaction_area.collision_layer = 0
		interaction_area.collision_mask = 1
		interaction_area.input_event.connect(_on_interaction_area_input)
		interaction_area.body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	_anim_time += delta
	
	if _speech_timer > 0.0:
		_speech_timer -= delta
		if _speech_timer <= 0.0 and speech_bubble != null:
			speech_bubble.visible = false
			
	if _interaction_cooldown > 0.0:
		_interaction_cooldown -= delta

	# State Machine Logic
	_state_timer -= delta
	match current_state:
		State.TYPING:
			_process_typing_state(delta)
			if _state_timer <= 0.0:
				_transition_to_next_state()
		State.WALKING:
			_process_walking_state(delta)
		State.COFFEE_BREAK:
			_process_coffee_state(delta)
			if _state_timer <= 0.0:
				_transition_to_next_state()
		State.CELEBRATING:
			_process_celebrating_state(delta)
			if _state_timer <= 0.0:
				_transition_to(State.TYPING)

func _process_typing_state(_delta: float) -> void:
	velocity = Vector3.ZERO
	# Subtle typing motion (micro-bob and arm typing movement)
	if visuals != null:
		visuals.position.y = sin(_anim_time * 8.0) * 0.015
		visuals.rotation.x = -0.05 + sin(_anim_time * 4.0) * 0.02
		visuals.rotation.z = 0.0
	if left_arm != null:
		left_arm.rotation = Vector3(-0.6 + sin(_anim_time * 16.0) * 0.08, 0.2, 0.0)
	if right_arm != null:
		right_arm.rotation = Vector3(-0.6 - sin(_anim_time * 16.0) * 0.08, -0.2, 0.0)
	if left_leg != null:
		left_leg.rotation = Vector3.ZERO
	if right_leg != null:
		right_leg.rotation = Vector3.ZERO
	if code_particles != null:
		code_particles.emitting = true

func _process_walking_state(delta: float) -> void:
	if code_particles != null:
		code_particles.emitting = false
		
	if not _has_target:
		_transition_to(State.TYPING)
		return
		
	var diff: Vector3 = _target_destination - global_position
	diff.y = 0.0
	var dist: float = diff.length()
	
	if dist <= 0.3:
		_has_target = false
		velocity = Vector3.ZERO
		if _target_destination == home_desk_position:
			_transition_to(State.TYPING)
		else:
			_transition_to(State.COFFEE_BREAK)
		return
		
	var dir = diff.normalized()
	velocity.x = dir.x * base_speed
	velocity.z = dir.z * base_speed
	
	# Facing rotation, walking bob, and articulated limb swings
	if visuals != null:
		var target_angle = atan2(velocity.x, velocity.z)
		visuals.rotation.y = lerp_angle(visuals.rotation.y, target_angle, 10.0 * delta)
		visuals.position.y = abs(sin(_anim_time * 10.0)) * 0.05
		visuals.rotation.z = sin(_anim_time * 5.0) * 0.04
		visuals.rotation.x = -0.03
	
	var swing = sin(_anim_time * 10.0) * 0.55
	if left_arm != null:
		left_arm.rotation = Vector3(-swing, 0.0, 0.0)
	if right_arm != null:
		right_arm.rotation = Vector3(swing, 0.0, 0.0)
	if left_leg != null:
		left_leg.rotation = Vector3(swing, 0.0, 0.0)
	if right_leg != null:
		right_leg.rotation = Vector3(-swing, 0.0, 0.0)
		
	move_and_slide()

func _process_coffee_state(_delta: float) -> void:
	velocity = Vector3.ZERO
	if visuals != null:
		visuals.position.y = sin(_anim_time * 2.0) * 0.02
		visuals.rotation.x = 0.0
		visuals.rotation.z = 0.0
	if right_arm != null:
		right_arm.rotation = Vector3(-0.7 + sin(_anim_time * 3.0) * 0.05, -0.2, 0.0) # Sipping coffee
	if left_arm != null:
		left_arm.rotation = Vector3(0.0, 0.0, 0.0)
	if left_leg != null:
		left_leg.rotation = Vector3.ZERO
	if right_leg != null:
		right_leg.rotation = Vector3.ZERO
	if code_particles != null:
		code_particles.emitting = false

func _process_celebrating_state(_delta: float) -> void:
	velocity = Vector3.ZERO
	if visuals != null:
		visuals.position.y = abs(sin(_anim_time * 12.0)) * 0.12
		visuals.rotation.y += 4.0 * _delta
	if left_arm != null:
		left_arm.rotation = Vector3(0.0, 0.0, 2.4 + sin(_anim_time * 12.0) * 0.2)
	if right_arm != null:
		right_arm.rotation = Vector3(0.0, 0.0, -2.4 - sin(_anim_time * 12.0) * 0.2)
	if code_particles != null:
		code_particles.emitting = true

func _update_accessories_for_state(s: State) -> void:
	match s:
		State.TYPING:
			if visor_emote != null:
				visor_emote.text = "0101"
				visor_emote.modulate = Color(0.2, 0.9, 0.4)
			if laptop_root != null:
				laptop_root.visible = true
			if coffee_mug != null:
				coffee_mug.visible = false
			if steam_particles != null:
				steam_particles.emitting = false
		State.WALKING:
			if visor_emote != null:
				visor_emote.text = "•_•"
				visor_emote.modulate = Color(0.3, 0.7, 1.0)
			if laptop_root != null:
				laptop_root.visible = false
			if coffee_mug != null:
				coffee_mug.visible = false
			if steam_particles != null:
				steam_particles.emitting = false
		State.COFFEE_BREAK:
			if visor_emote != null:
				visor_emote.text = "^.^"
				visor_emote.modulate = Color(1.0, 0.85, 0.3)
			if laptop_root != null:
				laptop_root.visible = false
			if coffee_mug != null:
				coffee_mug.visible = true
			if steam_particles != null:
				steam_particles.emitting = true
		State.CELEBRATING:
			if visor_emote != null:
				visor_emote.text = "★_★"
				visor_emote.modulate = Color(1.0, 0.9, 0.1)
			if laptop_root != null:
				laptop_root.visible = false
			if coffee_mug != null:
				coffee_mug.visible = false
			if steam_particles != null:
				steam_particles.emitting = false

func _transition_to(new_state: State) -> void:
	current_state = new_state
	_reset_state_timer()
	_update_accessories_for_state(new_state)
	state_changed.emit(_get_state_name(new_state))
	
	if new_state == State.WALKING:
		# Pick target destination
		if patrol_targets.size() > 0 and randf() > 0.4:
			_target_destination = patrol_targets[randi() % patrol_targets.size()]
		else:
			_target_destination = home_desk_position
		_has_target = true

func _transition_to_next_state() -> void:
	match current_state:
		State.TYPING:
			_transition_to(State.WALKING)
		State.COFFEE_BREAK:
			# Walk back to desk
			_target_destination = home_desk_position
			_has_target = true
			current_state = State.WALKING
			_reset_state_timer()
			state_changed.emit("WALKING")
		State.WALKING:
			_transition_to(State.TYPING)
		State.CELEBRATING:
			_transition_to(State.TYPING)

func _reset_state_timer() -> void:
	match current_state:
		State.TYPING:
			_state_timer = randf_range(6.0, 12.0)
		State.WALKING:
			_state_timer = 15.0 # Timeout safety
		State.COFFEE_BREAK:
			_state_timer = randf_range(4.0, 8.0)
		State.CELEBRATING:
			_state_timer = 3.0

func _get_state_name(s: State) -> String:
	match s:
		State.TYPING: return "TYPING"
		State.WALKING: return "WALKING"
		State.COFFEE_BREAK: return "COFFEE_BREAK"
		State.CELEBRATING: return "CELEBRATING"
	return "UNKNOWN"

## Interactive trigger: clicking or approaching displays quote and awards micro-bonus
func interact() -> void:
	if _interaction_cooldown > 0.0:
		return
	_interaction_cooldown = 1.0
	
	# Pick random witty quote for role
	var quotes: Array = WITTY_QUOTES.get(role, WITTY_QUOTES["coder"])
	var quote: String = quotes[randi() % quotes.size()]
	say_quote(quote, 3.0)
	
	# Micro-reward in GameState
	var bonus_energy: float = 5.0
	var gs = get_node_or_null("/root/GameState")
	if gs != null and gs.has_method("add_energy"):
		gs.add_energy(bonus_energy)
		
	# Spawn floating micro-text
	_spawn_micro_bonus_label(bonus_energy)
	worker_interacted.emit(worker_name, role, bonus_energy)

func say_quote(text: String, duration: float = 3.0) -> void:
	if speech_bubble == null:
		return
	speech_bubble.text = text
	speech_bubble.visible = true
	_speech_timer = duration
	
	# Little bounce tween on the speech bubble
	speech_bubble.scale = Vector3(0.5, 0.5, 0.5)
	var tw = speech_bubble.create_tween()
	tw.tween_property(speech_bubble, "scale", Vector3.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func celebrate(duration: float = 3.0) -> void:
	say_quote("🎉 YES! Milestone reached!", duration)
	_transition_to(State.CELEBRATING)
	_state_timer = duration

func _spawn_micro_bonus_label(amount: float) -> void:
	var parent_node = get_parent()
	if parent_node == null:
		return
	var label = Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = 20
	label.outline_size = 5
	label.text = "+%.0f Energy!" % amount
	label.modulate = Color(0.3, 1.0, 0.5)
	label.global_position = global_position + Vector3(0.0, 1.6, 0.0)
	parent_node.add_child(label)
	
	var tw = label.create_tween().set_parallel(true)
	tw.tween_property(label, "position:y", label.position.y + 1.0, 0.6).set_ease(Tween.EASE_OUT)
	tw.tween_property(label, "modulate:a", 0.0, 0.6).set_delay(0.2)
	tw.chain().tween_callback(label.queue_free)

func _on_interaction_area_input(_camera: Node, event: InputEvent, _pos: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		interact()
	elif event is InputEventScreenTouch and event.pressed:
		interact()

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player") or body is CharacterBody3D:
		if randf() > 0.5 and speech_bubble != null and not speech_bubble.visible:
			var quotes: Array = WITTY_QUOTES.get(role, WITTY_QUOTES["coder"])
			say_quote(quotes[randi() % quotes.size()], 2.5)

func _apply_role_styling() -> void:
	var color: Color = Color(0.2, 0.7, 1.0) # default coder
	match role:
		"intern":
			color = Color(0.5, 0.9, 0.2) # Lime
			worker_title = "Dev Intern"
		"coder":
			color = Color(0.1, 0.7, 1.0) # Cyan
			worker_title = "Fullstack Dev"
		"architect":
			color = Color(0.7, 0.3, 0.9) # Purple
			worker_title = "Lead Architect"
		"marketer":
			color = Color(1.0, 0.65, 0.2) # Amber
			worker_title = "Growth Hacker"
			
	if body_mesh != null:
		var mat = StandardMaterial3D.new()
		mat.albedo_color = color
		mat.roughness = 0.5
		mat.metallic = 0.1
		body_mesh.material_override = mat
	if chibi_torso != null:
		var mat = StandardMaterial3D.new()
		mat.albedo_color = color
		mat.roughness = 0.5
		mat.metallic = 0.1
		chibi_torso.material_override = mat
		
	if name_label != null:
		name_label.text = worker_name + "\n" + worker_title
