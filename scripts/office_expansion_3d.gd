extends StaticBody3D
class_name OfficeExpansion3D

## 3D Interactive Office Expansion for IdleArcade Phase 14 (Milestone M2).
## Positioned at (19, 0, -8) in North section of the East Office Wing.
## Features 5 detailed workstations, chairs, emissive monitors, cup holders,
## water dispenser, staff kiosk terminal, Area3D proximity trigger (radius 2.8m),
## floating PromptLabel3D ("[E] Staff Office"), dynamic TouchControls integration ("Staff [E]"),
## and autonomous ChibiWorker3D lifecycle synchronization with GameState.

signal staff_interaction_requested()
signal staff_office_opened()
signal worker_epiphany_collected(worker_id: String, reward: float)
signal office_hyper_focus_started(duration: float, multiplier: float)
signal office_hyper_focus_ended()
signal office_epiphany_triggered(worker_id: String, reward: float)

@export var prompt_text: String = "[E] Staff Office"
@export var action_label: String = "Staff [E]"
@export var worker_scene: PackedScene = preload("res://scenes/chibi_worker_3d.tscn")
@export var epiphany_periodic_check: bool = true
@export var epiphany_interval: float = 25.0

var _player_in_range: bool = false
var _avatar_ref: Node3D = null
var _spawned_workers: Dictionary = {} # worker_id -> ChibiWorker3D
var _desk_nodes: Array[Node3D] = []
var _slot_nodes: Array[Node3D] = []
var _epiphany_timer: float = 0.0

@onready var interaction_area: Area3D = get_node_or_null("InteractionArea")
@onready var prompt_label: Label3D = get_node_or_null("PromptLabel3D")
@onready var visuals: Node3D = get_node_or_null("Visuals")
@onready var desks_container: Node3D = get_node_or_null("Visuals/Desks")
@onready var worker_slots: Node3D = get_node_or_null("WorkerSlots")
@onready var spawned_workers_container: Node3D = get_node_or_null("SpawnedWorkers")
@onready var water_dispenser: Node3D = get_node_or_null("Visuals/WaterDispenser")
@onready var staff_kiosk: Node3D = get_node_or_null("Visuals/StaffKiosk")

func _ready() -> void:
	add_to_group("staff_offices")
	add_to_group("interactables")
	add_to_group("stations")

	_init_desk_and_slot_references()

	if prompt_label != null:
		prompt_label.text = prompt_text
		prompt_label.visible = false

	if interaction_area != null:
		interaction_area.body_entered.connect(_on_interaction_body_entered)
		interaction_area.body_exited.connect(_on_interaction_body_exited)

	_connect_game_state_signals()
	refresh_desks()
	refresh_workers()

func _init_desk_and_slot_references() -> void:
	_desk_nodes.clear()
	if desks_container != null:
		for i in range(5):
			var desk = desks_container.get_node_or_null("Desk_%d" % i)
			if desk != null:
				_desk_nodes.append(desk)

	_slot_nodes.clear()
	if worker_slots != null:
		for i in range(5):
			var slot = worker_slots.get_node_or_null("Slot_%d" % i)
			if slot != null:
				_slot_nodes.append(slot)

func _connect_game_state_signals() -> void:
	var gs = get_node_or_null("/root/GameState")
	if gs == null:
		return

	if gs.has_signal("staff_worker_hired"):
		gs.connect("staff_worker_hired", _on_worker_hired)
	elif gs.has_signal("worker_hired"):
		gs.connect("worker_hired", _on_worker_hired)

	if gs.has_signal("staff_worker_fired"):
		gs.connect("staff_worker_fired", _on_worker_fired)
	elif gs.has_signal("worker_fired"):
		gs.connect("worker_fired", _on_worker_fired)

	if gs.has_signal("staff_worker_state_changed"):
		gs.connect("staff_worker_state_changed", _on_worker_state_changed)
	elif gs.has_signal("worker_state_changed"):
		gs.connect("worker_state_changed", _on_worker_state_changed)

	if gs.has_signal("staff_worker_morale_updated"):
		gs.connect("staff_worker_morale_updated", _on_worker_morale_updated)

	if gs.has_signal("staff_desk_upgraded"):
		gs.connect("staff_desk_upgraded", _on_desk_upgraded)
	elif gs.has_signal("desk_upgraded"):
		gs.connect("desk_upgraded", _on_desk_upgraded)

	if gs.has_signal("staff_coffee_break_started"):
		gs.connect("staff_coffee_break_started", _on_coffee_break_started)
	elif gs.has_signal("team_coffee_break_started"):
		gs.connect("team_coffee_break_started", _on_coffee_break_started)

	if gs.has_signal("staff_coffee_break_ended"):
		gs.connect("staff_coffee_break_ended", _on_coffee_break_ended)

	if gs.has_signal("unicorn_espresso_activated"):
		gs.connect("unicorn_espresso_activated", _on_unicorn_espresso_activated)
	elif gs.has_signal("unicorn_espresso_buff_started"):
		gs.connect("unicorn_espresso_buff_started", _on_unicorn_espresso_buff_started)

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
		if tc != null:
			if tc.has_method("register_interactable"):
				tc.register_interactable(self, action_label)
			if tc.has_method("set_action_button_visible"):
				tc.set_action_button_visible(true, action_label)

func _on_interaction_body_exited(body: Node3D) -> void:
	if body == _avatar_ref or body.is_in_group("player") or body is CharacterBody3D:
		_player_in_range = false
		_avatar_ref = null
		if prompt_label != null:
			prompt_label.visible = false
		var tc = _find_touch_controls()
		if tc != null:
			if tc.has_method("unregister_interactable"):
				tc.unregister_interactable(self)
			if tc.has_method("set_action_button_visible"):
				tc.set_action_button_visible(false)

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

func is_player_in_range() -> bool:
	return _player_in_range

func interact() -> void:
	staff_interaction_requested.emit()
	staff_office_opened.emit()

	var am = get_node_or_null("/root/AudioManager")
	if am != null and am.has_method("play_sfx_click"):
		am.play_sfx_click()

	_open_staff_modal()

func open_staff() -> void:
	interact()

func open_staff_modal() -> void:
	interact()

func _open_staff_modal() -> void:
	var tree = get_tree()
	if tree == null:
		return
	var main_3d = tree.current_scene
	var hud: Node = null

	if main_3d != null and "hud_instance" in main_3d and is_instance_valid(main_3d.hud_instance):
		hud = main_3d.hud_instance
	elif tree.get_nodes_in_group("hud").size() > 0:
		hud = tree.get_nodes_in_group("hud")[0]
	elif tree.root.find_child("HUD", true, false) != null:
		hud = tree.root.find_child("HUD", true, false)

	if hud != null:
		if hud.has_method("open_staff_modal"):
			hud.open_staff_modal()
		elif hud.has_method("open_staff"):
			hud.open_staff()
		elif ResourceLoader.exists("res://scenes/ui/staff_modal.tscn"):
			var modal_scene = load("res://scenes/ui/staff_modal.tscn")
			if modal_scene != null and hud.has_method("open_modal"):
				hud.open_modal(modal_scene)
		elif main_3d != null and main_3d.has_method("open_hud_overlay") and not main_3d.is_hud_overlay_open():
			main_3d.open_hud_overlay()
	elif main_3d != null and main_3d.has_method("open_hud_overlay") and not main_3d.is_hud_overlay_open():
		main_3d.open_hud_overlay()

# ==============================================================================
# Desk Upgrades & Visual Ergonomics
# ==============================================================================

func refresh_desks() -> void:
	var gs = get_node_or_null("/root/GameState")
	for i in range(5):
		var level = 1
		if gs != null and gs.has_method("get_desk_level"):
			level = gs.get_desk_level(i)
		apply_desk_level(i, level)

func apply_desk_level(desk_index: int, level: int) -> void:
	if desk_index < 0 or desk_index >= _desk_nodes.size():
		return

	var desk = _desk_nodes[desk_index]
	if desk == null:
		return

	var dual_monitor = desk.get_node_or_null("DualMonitor")
	if dual_monitor != null:
		dual_monitor.visible = (level >= 2)

	var rgb_bar = desk.get_node_or_null("RgbLedBar")
	if rgb_bar != null:
		rgb_bar.visible = (level >= 3)

	# Standing desk elevation for level 3
	var desk_top = desk.get_node_or_null("DeskTop")
	if desk_top != null:
		desk_top.position.y = 0.95 if level >= 3 else 0.72

	# If there is a worker assigned to this desk, sync desk_level
	for w in _spawned_workers.values():
		if w.desk_assigned == desk_index:
			w.desk_level = level

func _on_desk_upgraded(desk_index: int, new_level: int) -> void:
	apply_desk_level(desk_index, new_level)

func get_desk_node(desk_index: int) -> Node3D:
	if desk_index >= 0 and desk_index < _desk_nodes.size():
		return _desk_nodes[desk_index]
	return null

# ==============================================================================
# Chibi Worker AI Synchronization
# ==============================================================================

func refresh_workers() -> void:
	var gs = get_node_or_null("/root/GameState")
	if gs == null or not gs.has_method("get_hired_workers"):
		return

	var workers = gs.get_hired_workers()
	var current_ids: Array = []
	for w_data in workers:
		if w_data is Dictionary and w_data.has("id"):
			var w_id = str(w_data["id"])
			current_ids.append(w_id)
			if _spawned_workers.has(w_id):
				_spawned_workers[w_id].setup(w_data)
			else:
				spawn_worker(w_data)

	# Despawn any workers that are no longer hired
	var existing_ids = _spawned_workers.keys()
	for old_id in existing_ids:
		if not (old_id in current_ids):
			despawn_worker(old_id)

func spawn_worker(worker_data: Dictionary) -> ChibiWorker3D:
	if worker_scene == null:
		return null

	var w_id = str(worker_data.get("id", ""))
	if _spawned_workers.has(w_id):
		return _spawned_workers[w_id]

	var worker_instance: ChibiWorker3D = worker_scene.instantiate() as ChibiWorker3D
	if worker_instance == null:
		return null

	var container = spawned_workers_container if spawned_workers_container != null else self
	container.add_child(worker_instance)

	var desk_idx = int(worker_data.get("desk_assigned", 0))
	if desk_idx >= 0 and desk_idx < _slot_nodes.size():
		worker_instance.position = _slot_nodes[desk_idx].position
	else:
		worker_instance.position = Vector3(0, 0, 0)

	worker_instance.setup(worker_data)
	worker_instance.epiphany_collected.connect(_on_worker_epiphany_collected)

	_spawned_workers[w_id] = worker_instance
	return worker_instance

func despawn_worker(worker_id: String) -> void:
	if _spawned_workers.has(worker_id):
		var w = _spawned_workers[worker_id]
		_spawned_workers.erase(worker_id)
		if is_instance_valid(w):
			w.queue_free()

func get_worker_instance(worker_id: String) -> ChibiWorker3D:
	return _spawned_workers.get(worker_id, null)

func get_all_workers() -> Array:
	return _spawned_workers.values()

func _on_worker_hired(worker_data: Dictionary) -> void:
	spawn_worker(worker_data)

func _on_worker_fired(worker_id: String) -> void:
	despawn_worker(worker_id)

func _on_worker_state_changed(worker_id: String, new_state: String) -> void:
	if _spawned_workers.has(worker_id):
		_spawned_workers[worker_id].set_state(new_state)

func _on_worker_morale_updated(worker_id: String, new_morale: float, new_fatigue: float) -> void:
	if _spawned_workers.has(worker_id):
		_spawned_workers[worker_id].set_morale(new_morale)
		_spawned_workers[worker_id].set_fatigue(new_fatigue)

func _process(delta: float) -> void:
	if epiphany_periodic_check:
		_epiphany_timer += delta
		if _epiphany_timer >= epiphany_interval:
			_epiphany_timer = 0.0
			check_and_trigger_epiphany()

func _on_coffee_break_started(duration: float = 60.0, speed_multiplier: float = 1.50) -> void:
	for w in _spawned_workers.values():
		if is_instance_valid(w):
			w.hyper_focus_multiplier = speed_multiplier
			w.set_hyper_focus(true, duration)
			w.set_state(ChibiWorker3D.STATE_COFFEE_BREAK)

func _on_coffee_break_ended() -> void:
	for w in _spawned_workers.values():
		if is_instance_valid(w):
			w.set_state(ChibiWorker3D.STATE_WORKING)
			w.set_hyper_focus(false)
	office_hyper_focus_ended.emit()

func _on_unicorn_espresso_activated(duration: float = 60.0, speed_mult: float = 1.50) -> void:
	activate_hyper_focus(duration, speed_mult)

func _on_unicorn_espresso_buff_started(duration: float = 60.0, _avatar_mult: float = 1.50, _worker_mult: float = 1.20) -> void:
	activate_hyper_focus(duration, 1.50)

## Activates office-wide Hyper-Focus (1.5x animation speed) for duration seconds across all Chibi workers.
func activate_hyper_focus(duration: float = 60.0, speed_multiplier: float = 1.50) -> void:
	for w in _spawned_workers.values():
		if is_instance_valid(w):
			w.hyper_focus_multiplier = speed_multiplier
			w.set_hyper_focus(true, duration)
			if w.get_state() != ChibiWorker3D.STATE_FATIGUED:
				w.play_celebration(1.0)
	office_hyper_focus_started.emit(duration, speed_multiplier)

## Triggers an epiphany on a random working worker who does not already have an active epiphany.
func trigger_random_epiphany(custom_reward: float = 0.0) -> ChibiWorker3D:
	var candidates: Array[ChibiWorker3D] = []
	for w in _spawned_workers.values():
		if is_instance_valid(w) and w.get_state() == ChibiWorker3D.STATE_WORKING and not w.has_epiphany():
			candidates.append(w)
	if candidates.is_empty():
		return null
	var chosen: ChibiWorker3D = candidates[randi() % candidates.size()]
	chosen.trigger_epiphany(custom_reward)
	office_epiphany_triggered.emit(chosen.worker_id, chosen._epiphany_reward)
	return chosen

## Checks and triggers an epiphany with a probability roll.
func check_and_trigger_epiphany(chance: float = 0.20) -> bool:
	if randf() < chance:
		return trigger_random_epiphany() != null
	return false

## Returns list of all worker IDs that currently have an active epiphany.
func get_epiphany_worker_ids() -> Array[String]:
	var result: Array[String] = []
	for w_id in _spawned_workers.keys():
		var w = _spawned_workers[w_id]
		if is_instance_valid(w) and w.has_epiphany():
			result.append(str(w_id))
	return result

## Clears any active uncollected epiphanies across all office workers.
func clear_all_epiphanies() -> void:
	for w in _spawned_workers.values():
		if is_instance_valid(w) and w.has_epiphany():
			w.expire_epiphany()

func _on_worker_epiphany_collected(worker_id: String, reward: float) -> void:
	worker_epiphany_collected.emit(worker_id, reward)
