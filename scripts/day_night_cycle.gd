extends Node3D
class_name DayNightCycle

## Master Day/Night Lighting Cycle Controller for IdleArcade (Phase 10 Milestone 3).
## Smoothly interpolates between Bright Daylight, Golden Sunset, and Cyberpunk Night
## with zero dynamic lights (pure color/energy & material emission modulation)
## guaranteeing stable 60 FPS on mobile and web platforms.

signal phase_changed(phase_name: String)
signal cycle_mode_changed(new_mode: String)
signal time_of_day_changed(new_time: float)

# Configurable Parameters
@export var cycle_duration: float = 180.0  ## Full cycle duration in seconds (3 minutes default)
@export var time_of_day: float = 0.20      ## Normalized cycle time [0.0, 1.0)
@export var cycle_mode: String = "auto"    ## "auto", "day", "night"

# Scene Node References
@export var directional_light: DirectionalLight3D
@export var world_environment: WorldEnvironment

# Campus Material Emission References
@export var window_materials: Array[StandardMaterial3D] = []
@export var neon_materials: Array[StandardMaterial3D] = []
@export var server_led_materials: Array[StandardMaterial3D] = []

# Phase Definitions
# 1. Bright Daylight (peak t = 0.20)
const DAY_DIR_ENERGY: float = 1.2
const DAY_DIR_COLOR: Color = Color(1.0, 0.96, 0.88, 1.0)
const DAY_DIR_PITCH: float = -45.0
const DAY_DIR_YAW: float = 45.0
const DAY_AMB_COLOR: Color = Color(0.38, 0.44, 0.53, 1.0)
const DAY_AMB_ENERGY: float = 0.75
const DAY_BG_COLOR: Color = Color(0.35, 0.55, 0.80, 1.0)
const DAY_NIGHT_FACTOR: float = 0.0

# 2. Golden Sunset (peak t = 0.65)
const SUNSET_DIR_ENERGY: float = 0.85
const SUNSET_DIR_COLOR: Color = Color(1.0, 0.55, 0.22, 1.0)
const SUNSET_DIR_PITCH: float = -18.0
const SUNSET_DIR_YAW: float = 80.0
const SUNSET_AMB_COLOR: Color = Color(0.42, 0.28, 0.25, 1.0)
const SUNSET_AMB_ENERGY: float = 0.65
const SUNSET_BG_COLOR: Color = Color(0.28, 0.15, 0.18, 1.0)
const SUNSET_NIGHT_FACTOR: float = 0.4

# 3. Cyberpunk Night (peak t = 0.82)
const NIGHT_DIR_ENERGY: float = 0.15
const NIGHT_DIR_COLOR: Color = Color(0.25, 0.35, 0.65, 1.0)
const NIGHT_DIR_PITCH: float = -38.0
const NIGHT_DIR_YAW: float = -135.0
# MANDATORY SPECIFICATION VALUE
const NIGHT_AMB_COLOR: Color = Color(0.08, 0.10, 0.18, 1.0)
const NIGHT_AMB_ENERGY: float = 0.55
const NIGHT_BG_COLOR: Color = Color(0.03, 0.04, 0.08, 1.0)
const NIGHT_NIGHT_FACTOR: float = 1.0

# Material Emission Ranges
const WINDOW_EMISSION_MIN: float = 0.0
const WINDOW_EMISSION_MAX: float = 1.8
const NEON_EMISSION_MIN: float = 0.2
const NEON_EMISSION_MAX: float = 2.5
const SERVER_EMISSION_MIN: float = 1.2
const SERVER_EMISSION_MAX: float = 3.0

var _last_phase_name: String = ""
var _cached_materials_found: bool = false

func _ready() -> void:
	print("[DayNightCycle] Initializing Campus Day/Night Light Cycle...")
	_resolve_scene_nodes()
	_discover_campus_materials()
	
	# Connect to GameState if available
	var gs = get_node_or_null("/root/GameState")
	if gs != null:
		if gs.has_signal("light_cycle_mode_changed"):
			if not gs.light_cycle_mode_changed.is_connected(set_cycle_mode):
				gs.light_cycle_mode_changed.connect(set_cycle_mode)
		if gs.has_method("get_light_cycle_mode"):
			set_cycle_mode(gs.get_light_cycle_mode())
	else:
		set_cycle_mode(cycle_mode)
		
	_apply_lighting()

func _process(delta: float) -> void:
	match cycle_mode:
		"day":
			time_of_day = 0.20
		"night":
			time_of_day = 0.82
		"auto":
			if cycle_duration > 0.0:
				time_of_day = fmod(time_of_day + delta / cycle_duration, 1.0)
				if time_of_day < 0.0:
					time_of_day += 1.0
		_:
			# Fallback to auto
			cycle_mode = "auto"
			if cycle_duration > 0.0:
				time_of_day = fmod(time_of_day + delta / cycle_duration, 1.0)

	time_of_day_changed.emit(time_of_day)
	_apply_lighting()
	
	var cur_phase = get_current_phase_name()
	if cur_phase != _last_phase_name:
		_last_phase_name = cur_phase
		phase_changed.emit(cur_phase)

## Sets cycle mode: "auto", "day", "night"
func set_cycle_mode(mode: String) -> void:
	var clean_mode = mode.to_lower()
	if clean_mode not in ["auto", "day", "night"]:
		clean_mode = "auto"
	
	cycle_mode = clean_mode
	if cycle_mode == "day":
		time_of_day = 0.20
	elif cycle_mode == "night":
		time_of_day = 0.82
		
	cycle_mode_changed.emit(cycle_mode)
	_apply_lighting()

## Returns active cycle mode
func get_cycle_mode() -> String:
	return cycle_mode

## Sets normalized time of day [0.0, 1.0]
func set_time_of_day(val: float) -> void:
	time_of_day = clampf(val, 0.0, 1.0)
	_apply_lighting()

## Returns current normalized time of day
func get_time_of_day() -> float:
	return time_of_day

## Returns semantic phase identifier: "day", "sunset", "night"
func get_current_phase() -> String:
	if time_of_day < 0.50:
		return "day"
	elif time_of_day < 0.75:
		return "sunset"
	else:
		return "night"

## Returns human-readable phase display name
func get_current_phase_name() -> String:
	var phase = get_current_phase()
	match phase:
		"day":
			return "Bright Daylight"
		"sunset":
			return "Golden Sunset"
		"night":
			return "Cyberpunk Night"
		_:
			return "Bright Daylight"

## Returns current night emission factor [0.0, 1.0]
func get_night_emission_factor() -> float:
	var state = calculate_lighting_state(time_of_day)
	return state["night_factor"]

## Mathematical evaluation of interpolated lighting state for any t in [0.0, 1.0]
static func calculate_lighting_state(t: float) -> Dictionary:
	var norm_t: float = fmod(t, 1.0)
	if norm_t < 0.0:
		norm_t += 1.0

	var dir_energy: float = DAY_DIR_ENERGY
	var dir_color: Color = DAY_DIR_COLOR
	var dir_pitch: float = DAY_DIR_PITCH
	var dir_yaw: float = DAY_DIR_YAW
	var amb_color: Color = DAY_AMB_COLOR
	var amb_energy: float = DAY_AMB_ENERGY
	var bg_color: Color = DAY_BG_COLOR
	var night_factor: float = DAY_NIGHT_FACTOR

	if norm_t <= 0.45:
		# 100% Bright Daylight
		dir_energy = DAY_DIR_ENERGY
		dir_color = DAY_DIR_COLOR
		dir_pitch = DAY_DIR_PITCH
		dir_yaw = DAY_DIR_YAW
		amb_color = DAY_AMB_COLOR
		amb_energy = DAY_AMB_ENERGY
		bg_color = DAY_BG_COLOR
		night_factor = DAY_NIGHT_FACTOR
	elif norm_t < 0.65:
		# Day -> Golden Sunset transition
		var s: float = (norm_t - 0.45) / (0.65 - 0.45)
		var w: float = s * s * (3.0 - 2.0 * s)
		dir_energy = lerpf(DAY_DIR_ENERGY, SUNSET_DIR_ENERGY, w)
		dir_color = DAY_DIR_COLOR.lerp(SUNSET_DIR_COLOR, w)
		dir_pitch = lerpf(DAY_DIR_PITCH, SUNSET_DIR_PITCH, w)
		dir_yaw = lerpf(DAY_DIR_YAW, SUNSET_DIR_YAW, w)
		amb_color = DAY_AMB_COLOR.lerp(SUNSET_AMB_COLOR, w)
		amb_energy = lerpf(DAY_AMB_ENERGY, SUNSET_AMB_ENERGY, w)
		bg_color = DAY_BG_COLOR.lerp(SUNSET_BG_COLOR, w)
		night_factor = lerpf(DAY_NIGHT_FACTOR, SUNSET_NIGHT_FACTOR, w)
	elif absf(norm_t - 0.65) < 0.0001:
		# Exact Golden Sunset peak
		dir_energy = SUNSET_DIR_ENERGY
		dir_color = SUNSET_DIR_COLOR
		dir_pitch = SUNSET_DIR_PITCH
		dir_yaw = SUNSET_DIR_YAW
		amb_color = SUNSET_AMB_COLOR
		amb_energy = SUNSET_AMB_ENERGY
		bg_color = SUNSET_BG_COLOR
		night_factor = SUNSET_NIGHT_FACTOR
	elif norm_t < 0.82:
		# Golden Sunset -> Cyberpunk Night transition
		var s: float = (norm_t - 0.65) / (0.82 - 0.65)
		var w: float = s * s * (3.0 - 2.0 * s)
		dir_energy = lerpf(SUNSET_DIR_ENERGY, NIGHT_DIR_ENERGY, w)
		dir_color = SUNSET_DIR_COLOR.lerp(NIGHT_DIR_COLOR, w)
		dir_pitch = lerpf(SUNSET_DIR_PITCH, NIGHT_DIR_PITCH, w)
		dir_yaw = lerpf(SUNSET_DIR_YAW, NIGHT_DIR_YAW, w)
		amb_color = SUNSET_AMB_COLOR.lerp(NIGHT_AMB_COLOR, w)
		amb_energy = lerpf(SUNSET_AMB_ENERGY, NIGHT_AMB_ENERGY, w)
		bg_color = SUNSET_BG_COLOR.lerp(NIGHT_BG_COLOR, w)
		night_factor = lerpf(SUNSET_NIGHT_FACTOR, NIGHT_NIGHT_FACTOR, w)
	elif norm_t <= 0.92:
		# 100% Cyberpunk Night
		dir_energy = NIGHT_DIR_ENERGY
		dir_color = NIGHT_DIR_COLOR
		dir_pitch = NIGHT_DIR_PITCH
		dir_yaw = NIGHT_DIR_YAW
		amb_color = NIGHT_AMB_COLOR
		amb_energy = NIGHT_AMB_ENERGY
		bg_color = NIGHT_BG_COLOR
		night_factor = NIGHT_NIGHT_FACTOR
	else:
		# Cyberpunk Night -> Daylight Dawn transition
		var s: float = (norm_t - 0.92) / (1.0 - 0.92)
		var w: float = s * s * (3.0 - 2.0 * s)
		dir_energy = lerpf(NIGHT_DIR_ENERGY, DAY_DIR_ENERGY, w)
		dir_color = NIGHT_DIR_COLOR.lerp(DAY_DIR_COLOR, w)
		dir_pitch = lerpf(NIGHT_DIR_PITCH, DAY_DIR_PITCH, w)
		dir_yaw = lerpf(NIGHT_DIR_YAW, DAY_DIR_YAW, w)
		amb_color = NIGHT_AMB_COLOR.lerp(DAY_AMB_COLOR, w)
		amb_energy = lerpf(NIGHT_AMB_ENERGY, DAY_AMB_ENERGY, w)
		bg_color = NIGHT_BG_COLOR.lerp(DAY_BG_COLOR, w)
		night_factor = lerpf(NIGHT_NIGHT_FACTOR, DAY_NIGHT_FACTOR, w)

	return {
		"dir_energy": dir_energy,
		"dir_color": dir_color,
		"dir_pitch": dir_pitch,
		"dir_yaw": dir_yaw,
		"amb_color": amb_color,
		"amb_energy": amb_energy,
		"bg_color": bg_color,
		"night_factor": night_factor
	}

## Applies calculated parameters to DirectionalLight3D, WorldEnvironment, and materials
func _apply_lighting() -> void:
	var state = calculate_lighting_state(time_of_day)

	# 1. Update DirectionalLight3D
	if directional_light != null:
		directional_light.light_energy = state["dir_energy"]
		directional_light.light_color = state["dir_color"]
		directional_light.rotation_degrees = Vector3(state["dir_pitch"], state["dir_yaw"], 0.0)

	# 2. Update WorldEnvironment
	if world_environment != null and world_environment.environment != null:
		var env = world_environment.environment
		env.ambient_light_color = state["amb_color"]
		env.ambient_light_energy = state["amb_energy"]
		env.background_color = state["bg_color"]

	# 3. Modulate Emissive Campus Materials
	var nf: float = state["night_factor"]
	var win_mult: float = lerpf(WINDOW_EMISSION_MIN, WINDOW_EMISSION_MAX, nf)
	var neon_mult: float = lerpf(NEON_EMISSION_MIN, NEON_EMISSION_MAX, nf)
	var server_mult: float = lerpf(SERVER_EMISSION_MIN, SERVER_EMISSION_MAX, nf)

	for mat in window_materials:
		if mat != null:
			mat.emission_enabled = true
			mat.emission_energy_multiplier = win_mult

	for mat in neon_materials:
		if mat != null:
			mat.emission_enabled = true
			mat.emission_energy_multiplier = neon_mult

	for mat in server_led_materials:
		if mat != null:
			mat.emission_enabled = true
			mat.emission_energy_multiplier = server_mult

## Resolves references to DirectionalLight3D and WorldEnvironment if unset
func _resolve_scene_nodes() -> void:
	if directional_light == null:
		directional_light = get_node_or_null("../DirectionalLight3D")
	if directional_light == null:
		var root = get_tree().root if is_inside_tree() else null
		if root != null:
			directional_light = root.find_child("DirectionalLight3D", true, false)

	if world_environment == null:
		world_environment = get_node_or_null("../WorldEnvironment")
	if world_environment == null:
		var root = get_tree().root if is_inside_tree() else null
		if root != null:
			world_environment = root.find_child("WorldEnvironment", true, false)

## Dynamically scans scene nodes for campus emissive materials
func _discover_campus_materials() -> void:
	if _cached_materials_found:
		return

	var root_node: Node = get_parent() if get_parent() != null else self
	_scan_node_materials(root_node)
	_cached_materials_found = true

func _scan_node_materials(node: Node) -> void:
	if node is MeshInstance3D:
		var mi: MeshInstance3D = node
		# Check active material override
		if mi.material_override is StandardMaterial3D:
			_classify_material(mi.material_override)
		# Check mesh surface materials
		if mi.mesh != null:
			for s in range(mi.mesh.get_surface_count()):
				var mat = mi.get_surface_override_material(s)
				if mat == null:
					mat = mi.mesh.surface_get_material(s)
				if mat is StandardMaterial3D:
					_classify_material(mat)

	for child in node.get_children():
		_scan_node_materials(child)

func _classify_material(mat: StandardMaterial3D) -> void:
	var mat_name = mat.resource_name.to_lower()
	if "window" in mat_name:
		register_window_material(mat)
	elif "neon" in mat_name or "glow" in mat_name or "accent" in mat_name:
		register_neon_material(mat)
	elif "led" in mat_name or "screen" in mat_name:
		register_server_led_material(mat)

## Public API to register materials for night emission modulation
func register_window_material(mat: StandardMaterial3D) -> void:
	if mat != null and not window_materials.has(mat):
		window_materials.append(mat)

func register_neon_material(mat: StandardMaterial3D) -> void:
	if mat != null and not neon_materials.has(mat):
		neon_materials.append(mat)

func register_server_led_material(mat: StandardMaterial3D) -> void:
	if mat != null and not server_led_materials.has(mat):
		server_led_materials.append(mat)
