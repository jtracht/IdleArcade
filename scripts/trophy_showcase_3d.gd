extends StaticBody3D
class_name TrophyShowcase3D

## 3D Trophy Showcase for IdleArcade (Phase 12 Milestone 2).
## Interactive exhibition station situated in Courtyard East Promenade at (6, 0, 12).
## Displays 4 milestone trophies on dedicated pedestals:
## 1. Golden Briefcase (MVP Launch / Chapter 1 complete)
## 2. Matrix Server Plaque (Cyber-Sync Overclock / Chapter 2 complete)
## 3. Crystal Espresso Chalice (Unicorn Status / Chapter 3 complete)
## 4. Platinum Bull (First successful IPO)
## Features continuous gentle idle rotation on trophy meshes,
## dynamic unlock detection from GameState, material emission toggling,
## proximity prompt, and TouchControls registration ("Showcase [E]").

signal trophies_refreshed()
signal showcase_interacted()

@export var prompt_text: String = "🏆 [E] Milestone Trophy Showcase"
@export var action_label: String = "Showcase [E]"
@export var idle_spin_speed: float = 0.9

@onready var interaction_area: Area3D = get_node_or_null("InteractionArea")
@onready var prompt_label: Label3D = get_node_or_null("PromptLabel3D")

# Trophy Mount Nodes (Rotated in _process)
@onready var mount_briefcase: Node3D = get_node_or_null("Visuals/Pedestals/Pedestal_Briefcase/TrophyMount")
@onready var mount_server: Node3D = get_node_or_null("Visuals/Pedestals/Pedestal_Server/TrophyMount")
@onready var mount_chalice: Node3D = get_node_or_null("Visuals/Pedestals/Pedestal_Chalice/TrophyMount")
@onready var mount_bull: Node3D = get_node_or_null("Visuals/Pedestals/Pedestal_Bull/TrophyMount")

# Pedestal Status Labels
@onready var label_briefcase: Label3D = get_node_or_null("Visuals/Pedestals/Pedestal_Briefcase/StatusLabel")
@onready var label_server: Label3D = get_node_or_null("Visuals/Pedestals/Pedestal_Server/StatusLabel")
@onready var label_chalice: Label3D = get_node_or_null("Visuals/Pedestals/Pedestal_Chalice/StatusLabel")
@onready var label_bull: Label3D = get_node_or_null("Visuals/Pedestals/Pedestal_Bull/StatusLabel")

# Pedestal Spotlights / Lights
@onready var light_briefcase: OmniLight3D = get_node_or_null("Visuals/Pedestals/Pedestal_Briefcase/Spot")
@onready var light_server: OmniLight3D = get_node_or_null("Visuals/Pedestals/Pedestal_Server/Spot")
@onready var light_chalice: OmniLight3D = get_node_or_null("Visuals/Pedestals/Pedestal_Chalice/Spot")
@onready var light_bull: OmniLight3D = get_node_or_null("Visuals/Pedestals/Pedestal_Bull/Spot")

var _player_in_range: bool = false
var _avatar_ref: Node3D = null

# Materials for unlocked vs locked states
var _mat_gold_unlocked: StandardMaterial3D = null
var _mat_matrix_unlocked: StandardMaterial3D = null
var _mat_crystal_unlocked: StandardMaterial3D = null
var _mat_platinum_unlocked: StandardMaterial3D = null
var _mat_locked: StandardMaterial3D = null

func _ready() -> void:
	add_to_group("trophy_showcase")
	add_to_group("interactables")

	_init_materials()

	if prompt_label != null:
		prompt_label.text = prompt_text
		prompt_label.visible = false

	if interaction_area != null:
		interaction_area.body_entered.connect(_on_interaction_body_entered)
		interaction_area.body_exited.connect(_on_interaction_body_exited)

	_bind_game_signals()
	refresh_trophies()

func _init_materials() -> void:
	# Locked generic material
	_mat_locked = StandardMaterial3D.new()
	_mat_locked.albedo_color = Color(0.22, 0.22, 0.25, 1.0)
	_mat_locked.metallic = 0.3
	_mat_locked.roughness = 0.8
	_mat_locked.emission_enabled = false

	# 1. Golden Briefcase material: Metallic 0.95 gold Color(1.0, 0.85, 0.2)
	_mat_gold_unlocked = StandardMaterial3D.new()
	_mat_gold_unlocked.albedo_color = Color(1.0, 0.85, 0.2, 1.0)
	_mat_gold_unlocked.metallic = 0.95
	_mat_gold_unlocked.roughness = 0.15
	_mat_gold_unlocked.emission_enabled = true
	_mat_gold_unlocked.emission = Color(1.0, 0.85, 0.2, 1.0)
	_mat_gold_unlocked.emission_energy_multiplier = 0.4

	# 2. Matrix Server Plaque material: Matrix green emission Color(0.1, 1.0, 0.35)
	_mat_matrix_unlocked = StandardMaterial3D.new()
	_mat_matrix_unlocked.albedo_color = Color(0.08, 0.30, 0.12, 1.0)
	_mat_matrix_unlocked.metallic = 0.7
	_mat_matrix_unlocked.roughness = 0.2
	_mat_matrix_unlocked.emission_enabled = true
	_mat_matrix_unlocked.emission = Color(0.1, 1.0, 0.35, 1.0)
	_mat_matrix_unlocked.emission_energy_multiplier = 2.0

	# 3. Crystal Espresso Chalice material: Crystal cyan glass/emission Color(0.3, 0.8, 1.0)
	_mat_crystal_unlocked = StandardMaterial3D.new()
	_mat_crystal_unlocked.albedo_color = Color(0.3, 0.8, 1.0, 0.85)
	_mat_crystal_unlocked.metallic = 0.1
	_mat_crystal_unlocked.roughness = 0.05
	_mat_crystal_unlocked.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_crystal_unlocked.emission_enabled = true
	_mat_crystal_unlocked.emission = Color(0.3, 0.8, 1.0, 1.0)
	_mat_crystal_unlocked.emission_energy_multiplier = 1.6

	# 4. Platinum Bull material: Mirror platinum metallic material Color(0.92, 0.94, 0.98)
	_mat_platinum_unlocked = StandardMaterial3D.new()
	_mat_platinum_unlocked.albedo_color = Color(0.92, 0.94, 0.98, 1.0)
	_mat_platinum_unlocked.metallic = 0.98
	_mat_platinum_unlocked.roughness = 0.10
	_mat_platinum_unlocked.emission_enabled = true
	_mat_platinum_unlocked.emission = Color(0.85, 0.90, 1.0, 1.0)
	_mat_platinum_unlocked.emission_energy_multiplier = 0.5

func _bind_game_signals() -> void:
	var gs = get_node_or_null("/root/GameState")
	if gs != null:
		if gs.has_signal("trophy_unlocked") and not gs.trophy_unlocked.is_connected(_on_trophy_unlocked_signal):
			gs.trophy_unlocked.connect(_on_trophy_unlocked_signal)
		if gs.has_signal("ipo_completed") and not gs.ipo_completed.is_connected(_on_ipo_completed_signal):
			gs.ipo_completed.connect(_on_ipo_completed_signal)
		if gs.has_signal("campaign_chapter_changed") and not gs.campaign_chapter_changed.is_connected(_on_campaign_changed_signal):
			gs.campaign_chapter_changed.connect(_on_campaign_changed_signal)

func _on_trophy_unlocked_signal(_trophy_id: String) -> void:
	refresh_trophies()

func _on_ipo_completed_signal(_gained: int, _total: int, _mult: float) -> void:
	refresh_trophies()

func _on_campaign_changed_signal(_chapter: int) -> void:
	refresh_trophies()

func _process(delta: float) -> void:
	# Continuous gentle idle rotation on trophy meshes
	var angle: float = idle_spin_speed * delta
	if mount_briefcase != null:
		mount_briefcase.rotate_y(angle)
	if mount_server != null:
		mount_server.rotate_y(angle)
	if mount_chalice != null:
		mount_chalice.rotate_y(angle)
	if mount_bull != null:
		mount_bull.rotate_y(angle)

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

## Interaction handler
func interact() -> void:
	showcase_interacted.emit()
	refresh_trophies()

	var am = get_node_or_null("/root/AudioManager")
	if am != null:
		if am.has_method("play_sfx_pickup"):
			am.play_sfx_pickup("briefcase")
		elif am.has_method("play_sfx_click"):
			am.play_sfx_click()

## Evaluates unlock status and updates trophy visuals, materials, labels, and spotlights.
func refresh_trophies() -> void:
	var gs = get_node_or_null("/root/GameState")
	if gs != null and gs.has_method("check_and_update_trophies"):
		gs.check_and_update_trophies()

	var is_briefcase_unlocked: bool = false
	var is_server_unlocked: bool = false
	var is_chalice_unlocked: bool = false
	var is_bull_unlocked: bool = false

	if gs != null:
		# Check explicit unlock methods or state
		if gs.has_method("is_trophy_unlocked"):
			is_briefcase_unlocked = gs.is_trophy_unlocked("trophy_golden_briefcase")
			is_server_unlocked = gs.is_trophy_unlocked("trophy_server_matrix")
			is_chalice_unlocked = gs.is_trophy_unlocked("trophy_crystal_espresso")
			is_bull_unlocked = gs.is_trophy_unlocked("trophy_platinum_bull")
		elif "unlocked_trophies" in gs:
			var trophies: Array = gs.unlocked_trophies
			is_briefcase_unlocked = trophies.has("trophy_golden_briefcase")
			is_server_unlocked = trophies.has("trophy_server_matrix")
			is_chalice_unlocked = trophies.has("trophy_crystal_espresso")
			is_bull_unlocked = trophies.has("trophy_platinum_bull")

		# Fallback checks based on game progression
		if not is_briefcase_unlocked and "campaign_chapter" in gs:
			if gs.campaign_chapter >= 2 or ("campaign_completed_quests" in gs and gs.campaign_completed_quests.has("quest_briefcases")):
				is_briefcase_unlocked = true

		if not is_server_unlocked and "campaign_chapter" in gs:
			if gs.campaign_chapter >= 3 or ("campaign_completed_quests" in gs and gs.campaign_completed_quests.has("quest_server")):
				is_server_unlocked = true

		if not is_chalice_unlocked and "campaign_chapter" in gs:
			if gs.campaign_chapter >= 4 or ("campaign_completed_quests" in gs and gs.campaign_completed_quests.has("quest_lab")):
				is_chalice_unlocked = true

		if not is_bull_unlocked:
			if ("total_ipos_completed" in gs and gs.total_ipos_completed > 0) or ("angel_shares" in gs and gs.angel_shares > 0):
				is_bull_unlocked = true

	# Update Trophy 1: Golden Briefcase
	_update_trophy_subtree(mount_briefcase, is_briefcase_unlocked, _mat_gold_unlocked, _mat_locked)
	if label_briefcase != null:
		label_briefcase.text = "🏆 MVP Briefcase\n[Chapter 1]" if is_briefcase_unlocked else "🔒 MVP Briefcase\n[Locked]"
		label_briefcase.modulate = Color(1.0, 0.9, 0.4) if is_briefcase_unlocked else Color(0.6, 0.6, 0.65)
	if light_briefcase != null:
		light_briefcase.light_energy = 1.0 if is_briefcase_unlocked else 0.1

	# Update Trophy 2: Matrix Server Plaque
	_update_trophy_subtree(mount_server, is_server_unlocked, _mat_matrix_unlocked, _mat_locked)
	if label_server != null:
		label_server.text = "🏆 Cyber-Sync Plaque\n[Chapter 2]" if is_server_unlocked else "🔒 Cyber-Sync Plaque\n[Locked]"
		label_server.modulate = Color(0.3, 1.0, 0.5) if is_server_unlocked else Color(0.6, 0.6, 0.65)
	if light_server != null:
		light_server.light_energy = 1.2 if is_server_unlocked else 0.1

	# Update Trophy 3: Crystal Espresso Chalice
	_update_trophy_subtree(mount_chalice, is_chalice_unlocked, _mat_crystal_unlocked, _mat_locked)
	if label_chalice != null:
		label_chalice.text = "🏆 Unicorn Chalice\n[Chapter 3]" if is_chalice_unlocked else "🔒 Unicorn Chalice\n[Locked]"
		label_chalice.modulate = Color(0.4, 0.9, 1.0) if is_chalice_unlocked else Color(0.6, 0.6, 0.65)
	if light_chalice != null:
		light_chalice.light_energy = 1.2 if is_chalice_unlocked else 0.1

	# Update Trophy 4: Platinum Bull
	_update_trophy_subtree(mount_bull, is_bull_unlocked, _mat_platinum_unlocked, _mat_locked)
	if label_bull != null:
		label_bull.text = "🏆 Platinum Bull\n[First IPO]" if is_bull_unlocked else "🔒 Platinum Bull\n[Locked]"
		label_bull.modulate = Color(0.9, 0.95, 1.0) if is_bull_unlocked else Color(0.6, 0.6, 0.65)
	if light_bull != null:
		light_bull.light_energy = 1.5 if is_bull_unlocked else 0.1

	trophies_refreshed.emit()

func _update_trophy_subtree(mount: Node3D, unlocked: bool, mat_unlocked: Material, mat_locked: Material) -> void:
	if mount == null:
		return
	var mat_to_apply = mat_unlocked if unlocked else mat_locked
	_apply_material_recursive(mount, mat_to_apply)

func _apply_material_recursive(node: Node, mat: Material) -> void:
	if node is MeshInstance3D:
		node.material_override = mat
	for child in node.get_children():
		_apply_material_recursive(child, mat)
