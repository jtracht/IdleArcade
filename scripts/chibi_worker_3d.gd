extends CharacterBody3D
class_name ChibiWorker3D

## Autonomous 3D Chibi Worker AI for IdleArcade Phase 14 (Milestone M2).
## Features low-poly mesh architecture (<600 Tris), 4-state state machine:
## STATE_WORKING, STATE_COFFEE_BREAK, STATE_FATIGUED, STATE_CELEBRATING,
## dynamic mood icons (💻, ☕, 💡, 💤, 🎉), typing arm animations,
## CPUParticles3D for steam & Zzz, role-based color tinting, and tap-interactive epiphany moments.

signal state_changed(old_state: String, new_state: String)
signal epiphany_triggered(worker_id: String, reward: float)
signal epiphany_collected(worker_id: String, reward: float)
signal coffee_break_completed(worker_id: String)
signal hyper_focus_changed(active: bool, multiplier: float)

enum State {
	WORKING,
	COFFEE_BREAK,
	FATIGUED,
	CELEBRATING
}

const STATE_WORKING: String = "working"
const STATE_COFFEE_BREAK: String = "break"
const STATE_FATIGUED: String = "fatigued"
const STATE_CELEBRATING: String = "celebrating"

# Role color themes
const ROLE_COLORS: Dictionary = {
	"Frontend Dev": Color(0.1, 0.75, 1.0, 1.0),       # Neon-Cyan
	"Backend Dev": Color(0.1, 0.85, 0.3, 1.0),        # Matrix Green
	"UI/UX Designer": Color(0.85, 0.25, 0.95, 1.0),   # Cyber Violet / Magenta
	"Growth Hacker": Color(1.0, 0.65, 0.1, 1.0),      # Electric Amber
	"QA Engineer": Color(0.95, 0.2, 0.25, 1.0)        # Ruby Red
}

@export var worker_id: String = ""
@export var worker_name: String = "Worker"
@export var role: String = "Frontend Dev"
@export var morale: float = 1.0
@export var fatigue: float = 0.0
@export var desk_assigned: int = 0
@export var current_state: String = STATE_WORKING
@export var hyper_focus: bool = false
@export var hyper_focus_multiplier: float = 1.5
@export var desk_level: int = 1
@export var epiphany_enabled: bool = true
@export var epiphany_check_interval: float = 20.0
@export var epiphany_chance: float = 0.15
@export var epiphany_lifetime: float = 20.0

# Node references
@onready var chibi_root: Node3D = get_node_or_null("ChibiRoot")
@onready var torso_mesh: MeshInstance3D = get_node_or_null("ChibiRoot/Torso")
@onready var head_node: Node3D = get_node_or_null("ChibiRoot/Head")
@onready var visor_mesh: MeshInstance3D = get_node_or_null("ChibiRoot/Head/Visor")
@onready var face_label: Label3D = get_node_or_null("ChibiRoot/Head/Visor/FaceLabel3D")
@onready var left_arm_pivot: Node3D = get_node_or_null("ChibiRoot/LeftArmPivot")
@onready var right_arm_pivot: Node3D = get_node_or_null("ChibiRoot/RightArmPivot")
@onready var left_leg: MeshInstance3D = get_node_or_null("ChibiRoot/LeftLeg")
@onready var right_leg: MeshInstance3D = get_node_or_null("ChibiRoot/RightLeg")
@onready var mood_icon: Label3D = get_node_or_null("MoodIcon3D")
@onready var zzz_particles: CPUParticles3D = get_node_or_null("ZzzParticles")
@onready var steam_particles: CPUParticles3D = get_node_or_null("SteamParticles")
@onready var epiphany_particles: CPUParticles3D = get_node_or_null("EpiphanyParticles")
@onready var epiphany_light: OmniLight3D = get_node_or_null("EpiphanyLight")
@onready var click_area: Area3D = get_node_or_null("ClickArea")

# Internal animation & state trackers
var _time: float = 0.0
var _anim_phase_offset: float = 0.0
var _has_epiphany: bool = false
var _epiphany_reward: float = 0.0
var _celebrate_timer: float = 0.0
var _revert_state_after_celebrate: String = STATE_WORKING
var _base_torso_pos: Vector3 = Vector3(0, 0.35, 0)
var _base_head_pos: Vector3 = Vector3(0, 0.65, 0)
var _epiphany_pulse_tween: Tween = null
var _hyper_focus_timer: float = 0.0
var _epiphany_check_timer: float = 0.0
var _epiphany_timer: float = 0.0

func _ready() -> void:
	add_to_group("chibi_workers")
	_anim_phase_offset = randf() * 10.0
	
	input_ray_pickable = true
	if not input_event.is_connected(_on_click_area_input_event):
		input_event.connect(_on_click_area_input_event)
	
	if click_area != null:
		click_area.input_event.connect(_on_click_area_input_event)

	apply_role_visuals()
	_update_state_visuals()

func setup(data: Dictionary) -> void:
	if data.has("id"):
		worker_id = str(data["id"])
	if data.has("name"):
		worker_name = str(data["name"])
	if data.has("role"):
		role = str(data["role"])
	if data.has("morale"):
		morale = clampf(float(data["morale"]), 0.0, 1.0)
	if data.has("fatigue"):
		fatigue = clampf(float(data["fatigue"]), 0.0, 1.0)
	if data.has("desk_assigned"):
		desk_assigned = int(data["desk_assigned"])
	if data.has("current_state"):
		set_state(str(data["current_state"]))
	if data.has("desk_level"):
		desk_level = int(data["desk_level"])
	
	apply_role_visuals()
	_update_state_visuals()

func apply_role_visuals() -> void:
	var role_color = ROLE_COLORS.get(role, Color(0.1, 0.75, 1.0, 1.0))
	
	if torso_mesh != null:
		var mat = StandardMaterial3D.new()
		mat.albedo_color = role_color
		mat.roughness = 0.4
		torso_mesh.material_override = mat

	if visor_mesh != null:
		var visor_mat = StandardMaterial3D.new()
		visor_mat.albedo_color = Color(0.05, 0.08, 0.12, 1.0)
		visor_mat.emission_enabled = true
		visor_mat.emission = role_color
		visor_mat.emission_energy_multiplier = 1.2
		visor_mesh.material_override = visor_mat

func set_role(new_role: String) -> void:
	role = new_role
	apply_role_visuals()

func set_morale(new_morale: float) -> void:
	morale = clampf(new_morale, 0.0, 1.0)
	_update_face_expression()

func set_fatigue(new_fatigue: float) -> void:
	fatigue = clampf(new_fatigue, 0.0, 1.0)
	if fatigue >= 1.0 and current_state == STATE_WORKING:
		set_state(STATE_FATIGUED)
	elif fatigue < 0.8 and current_state == STATE_FATIGUED:
		set_state(STATE_WORKING)

func set_hyper_focus(active: bool, duration: float = 60.0) -> void:
	var was_active = hyper_focus or (_hyper_focus_timer > 0.0)
	hyper_focus = active
	if active:
		_hyper_focus_timer = duration if duration > 0.0 else 60.0
		if not was_active and current_state != STATE_FATIGUED:
			play_celebration(0.8)
	else:
		_hyper_focus_timer = 0.0
	hyper_focus_changed.emit(active, hyper_focus_multiplier if active else 1.0)

func is_hyper_focus_active() -> bool:
	if hyper_focus or _hyper_focus_timer > 0.0:
		return true
	var gs = get_node_or_null("/root/GameState")
	if gs != null and gs.has_method("is_staff_hyper_focus_active"):
		return gs.is_staff_hyper_focus_active()
	return false

func get_animation_speed_multiplier() -> float:
	return hyper_focus_multiplier if is_hyper_focus_active() else 1.0

func get_state() -> String:
	return current_state

func set_state(new_state) -> void:
	var target_state: String = STATE_WORKING
	if typeof(new_state) == TYPE_INT:
		match new_state:
			State.WORKING: target_state = STATE_WORKING
			State.COFFEE_BREAK: target_state = STATE_COFFEE_BREAK
			State.FATIGUED: target_state = STATE_FATIGUED
			State.CELEBRATING: target_state = STATE_CELEBRATING
			_: target_state = STATE_WORKING
	else:
		target_state = str(new_state).to_lower()
		if target_state == "working":
			target_state = STATE_WORKING
		elif target_state in ["break", "coffee_break", "coffee"]:
			target_state = STATE_COFFEE_BREAK
		elif target_state in ["fatigued", "tired", "sleep"]:
			target_state = STATE_FATIGUED
		elif target_state in ["celebrating", "celebrate"]:
			target_state = STATE_CELEBRATING

	if current_state == target_state:
		return

	# Epiphany cancellation guard:
	# If entering FATIGUED or COFFEE_BREAK while holding an active epiphany,
	# cancel/expire it cleanly to prevent visual leaks and stuck icons.
	if (target_state == STATE_FATIGUED or target_state == STATE_COFFEE_BREAK) and _has_epiphany:
		expire_epiphany()

	var old_state = current_state
	current_state = target_state
	_update_state_visuals()
	state_changed.emit(old_state, current_state)

func _update_state_visuals() -> void:
	# Particles
	if zzz_particles != null:
		zzz_particles.emitting = (current_state == STATE_FATIGUED)
	if steam_particles != null:
		steam_particles.emitting = (current_state == STATE_COFFEE_BREAK)

	# Mood icon
	if mood_icon != null and not _has_epiphany:
		match current_state:
			STATE_WORKING:
				mood_icon.text = "💻"
			STATE_COFFEE_BREAK:
				mood_icon.text = "☕"
			STATE_FATIGUED:
				mood_icon.text = "💤"
			STATE_CELEBRATING:
				mood_icon.text = "🎉"
			_:
				mood_icon.text = "💻"

	_update_face_expression()
	_reset_pose()

func _update_face_expression() -> void:
	if face_label == null:
		return
	if _has_epiphany:
		face_label.text = "★_★"
		return

	match current_state:
		STATE_WORKING:
			face_label.text = "^.^" if morale > 0.6 else "•_•"
		STATE_COFFEE_BREAK:
			face_label.text = "☕"
		STATE_FATIGUED:
			face_label.text = "-.-"
		STATE_CELEBRATING:
			face_label.text = "★_★"
		_:
			face_label.text = "•_•"

func _reset_pose() -> void:
	if torso_mesh != null:
		torso_mesh.position = _base_torso_pos
		torso_mesh.rotation = Vector3.ZERO
	if head_node != null:
		head_node.position = _base_head_pos
		head_node.rotation = Vector3.ZERO
	if left_arm_pivot != null:
		left_arm_pivot.rotation = Vector3.ZERO
	if right_arm_pivot != null:
		right_arm_pivot.rotation = Vector3.ZERO
	if chibi_root != null and current_state != STATE_CELEBRATING:
		chibi_root.position.y = 0.0

func _process(delta: float) -> void:
	# Handle hyper-focus duration decay
	if _hyper_focus_timer > 0.0:
		_hyper_focus_timer -= delta
		if _hyper_focus_timer <= 0.0:
			_hyper_focus_timer = 0.0
			hyper_focus = false
			hyper_focus_changed.emit(false, 1.0)

	var speed_mult: float = get_animation_speed_multiplier()
	_time += delta * speed_mult
	var t: float = _time + _anim_phase_offset

	# Handle celebration timer
	if _celebrate_timer > 0.0:
		_celebrate_timer -= delta
		if _celebrate_timer <= 0.0:
			set_state(_revert_state_after_celebrate)

	# Epiphany auto-expiration timer
	if _has_epiphany:
		_epiphany_timer += delta
		if _epiphany_timer >= epiphany_lifetime:
			expire_epiphany()

	# Spontaneous epiphany check during working state
	if epiphany_enabled and current_state == STATE_WORKING and not _has_epiphany:
		_epiphany_check_timer += delta
		if _epiphany_check_timer >= epiphany_check_interval:
			_epiphany_check_timer = 0.0
			check_epiphany()

	# State-specific kinematics & animations
	match current_state:
		STATE_WORKING:
			_animate_working(t)
		STATE_COFFEE_BREAK:
			_animate_coffee_break(t)
		STATE_FATIGUED:
			_animate_fatigued(t)
		STATE_CELEBRATING:
			_animate_celebrating(t)

func _animate_working(t: float) -> void:
	# Arm typing rhythm: alternating rotation
	if left_arm_pivot != null:
		left_arm_pivot.rotation.x = -0.35 + sin(t * 14.0) * 0.15
		left_arm_pivot.rotation.z = 0.15
	if right_arm_pivot != null:
		right_arm_pivot.rotation.x = -0.35 - sin(t * 14.0) * 0.15
		right_arm_pivot.rotation.z = -0.15

	# Head nodding slightly in sync
	if head_node != null:
		head_node.rotation.x = -0.05 + sin(t * 4.0) * 0.03
		head_node.rotation.y = sin(t * 1.5) * 0.05

func _animate_coffee_break(t: float) -> void:
	# Right arm raised to visor sipping coffee
	if right_arm_pivot != null:
		right_arm_pivot.rotation.x = -0.85 + sin(t * 3.0) * 0.08
		right_arm_pivot.rotation.y = -0.25
	if left_arm_pivot != null:
		left_arm_pivot.rotation.x = 0.0
		left_arm_pivot.rotation.z = 0.2

	# Gentle head tilt
	if head_node != null:
		head_node.rotation.x = 0.12 + sin(t * 3.0) * 0.04
		head_node.rotation.z = -0.05

func _animate_fatigued(t: float) -> void:
	# Head slumped forward on desk
	if head_node != null:
		head_node.rotation.x = -0.65 + sin(t * 1.2) * 0.02
		head_node.position.y = _base_head_pos.y - 0.08
	# Torso lowered
	if torso_mesh != null:
		torso_mesh.rotation.x = -0.25
		torso_mesh.position.y = _base_torso_pos.y - 0.04
	# Limp arms
	if left_arm_pivot != null:
		left_arm_pivot.rotation.x = -0.6
		left_arm_pivot.rotation.z = 0.4
	if right_arm_pivot != null:
		right_arm_pivot.rotation.x = -0.6
		right_arm_pivot.rotation.z = -0.4

func _animate_celebrating(t: float) -> void:
	# Cheerful bounce jump
	if chibi_root != null:
		chibi_root.position.y = abs(sin(t * 12.0)) * 0.22

	# Arms raised in victory V
	if left_arm_pivot != null:
		left_arm_pivot.rotation.z = 2.4 + sin(t * 10.0) * 0.15
		left_arm_pivot.rotation.x = 0.1
	if right_arm_pivot != null:
		right_arm_pivot.rotation.z = -2.4 - sin(t * 10.0) * 0.15
		right_arm_pivot.rotation.x = 0.1

	# Head nodding happily
	if head_node != null:
		head_node.rotation.x = sin(t * 8.0) * 0.1

# ==============================================================================
# Epiphany Mechanics (💡)
# ==============================================================================

## Evaluates a spontaneous epiphany breakthrough for working workers.
func check_epiphany(chance: float = -1.0) -> bool:
	if current_state != STATE_WORKING or _has_epiphany:
		return false
	var test_chance = chance if chance >= 0.0 else epiphany_chance
	if randf() < test_chance:
		trigger_epiphany()
		return true
	return false

func trigger_epiphany(custom_reward: float = 0.0) -> void:
	_has_epiphany = true
	_epiphany_timer = 0.0
	if custom_reward > 0.0:
		_epiphany_reward = custom_reward
	else:
		var gs = get_node_or_null("/root/GameState")
		if gs != null and gs.has_method("get_effective_passive_rps"):
			_epiphany_reward = maxf(100.0, gs.get_effective_passive_rps() * 15.0)
		else:
			_epiphany_reward = 500.0

	if mood_icon != null:
		mood_icon.text = "💡"
		if _epiphany_pulse_tween != null and _epiphany_pulse_tween.is_valid():
			_epiphany_pulse_tween.kill()
		_epiphany_pulse_tween = create_tween().set_loops()
		_epiphany_pulse_tween.tween_property(mood_icon, "scale", Vector3(1.3, 1.3, 1.3), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_epiphany_pulse_tween.tween_property(mood_icon, "scale", Vector3(1.0, 1.0, 1.0), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	if epiphany_particles != null:
		epiphany_particles.emitting = true
	if epiphany_light != null:
		epiphany_light.visible = true

	_update_face_expression()
	epiphany_triggered.emit(worker_id, _epiphany_reward)

func collect_epiphany() -> float:
	if not _has_epiphany:
		return 0.0

	var reward = _epiphany_reward
	_has_epiphany = false
	_epiphany_timer = 0.0

	if _epiphany_pulse_tween != null and _epiphany_pulse_tween.is_valid():
		_epiphany_pulse_tween.kill()
	if mood_icon != null:
		mood_icon.scale = Vector3.ONE

	if epiphany_particles != null:
		epiphany_particles.emitting = false
	if epiphany_light != null:
		epiphany_light.visible = false

	# Award energy to player via GameState.trigger_worker_epiphany
	var gs = get_node_or_null("/root/GameState")
	if gs != null:
		if gs.has_method("trigger_worker_epiphany"):
			var awarded = gs.trigger_worker_epiphany(worker_id)
			if awarded > 0.0:
				reward = awarded
		elif gs.has_method("earn_energy"):
			gs.earn_energy(reward)
		elif gs.has_method("add_energy"):
			gs.add_energy(reward)

	# Sound effect
	var am = get_node_or_null("/root/AudioManager")
	if am != null:
		if am.has_method("play_sfx_pickup"):
			am.play_sfx_pickup("coffee")
		elif am.has_method("play_sfx_click"):
			am.play_sfx_click()

	epiphany_collected.emit(worker_id, reward)
	play_celebration(1.5)
	return reward

## Cleanly expires an uncollected epiphany after epiphany_lifetime,
## extinguishing visual effects and restoring the regular mood icon.
func expire_epiphany() -> void:
	if not _has_epiphany:
		return
	_has_epiphany = false
	_epiphany_timer = 0.0

	if _epiphany_pulse_tween != null and _epiphany_pulse_tween.is_valid():
		_epiphany_pulse_tween.kill()
	if mood_icon != null:
		mood_icon.scale = Vector3.ONE

	if epiphany_particles != null:
		epiphany_particles.emitting = false
	if epiphany_light != null:
		epiphany_light.visible = false

	_update_state_visuals()

## Alias for expire_epiphany for state machine cancellations.
func cancel_epiphany() -> void:
	expire_epiphany()

func has_epiphany() -> bool:
	return _has_epiphany

## Public helper for tapping or clicking a worker directly.
func tap_worker() -> float:
	if _has_epiphany:
		return collect_epiphany()
	elif current_state == STATE_CELEBRATING:
		# Don't truncate an ongoing victory jump (e.g. 1.5s epiphany celebration)
		if _celebrate_timer < 0.8:
			_celebrate_timer = 0.8
		return 0.0
	else:
		play_celebration(0.8)
		return 0.0

func play_celebration(duration: float = 2.0) -> void:
	_revert_state_after_celebrate = current_state if current_state != STATE_CELEBRATING else STATE_WORKING
	_celebrate_timer = duration
	set_state(STATE_CELEBRATING)

func _on_click_area_input_event(_camera: Node, event: InputEvent, _pos: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	var is_tap = false
	if event is InputEventMouseButton and event.is_pressed() and event.button_index == MOUSE_BUTTON_LEFT:
		is_tap = true
	elif event is InputEventScreenTouch and event.is_pressed():
		is_tap = true
		
	if is_tap:
		tap_worker()
