extends StaticBody3D
class_name ZoneGate3D

## 3D Zone Gate Barrier for IdleArcade (Phase 4 Milestone P4-M3).
## Blocks physical passage to campus zones (Server Room, R&D Lab) until the player
## unlocks it by reaching required clearance level in idle meta-progression or paying Users/energy.

signal gate_unlocked(zone_id: String)
signal gate_interacted(zone_id: String, success: bool)

@export var zone_id: String = "server_room"
@export var zone_name: String = "Server Room"
@export var required_level: int = 2
@export var unlock_cost: float = 100.0
@export var auto_unlock_on_level: bool = false

var _is_unlocked: bool = false
var _player_in_range: bool = false
var _avatar_ref: Node3D = null

@onready var collision_shape: CollisionShape3D = get_node_or_null("CollisionShape3D")
@onready var barrier_mesh: MeshInstance3D = get_node_or_null("Visuals/BarrierMesh")
@onready var prompt_label: Label3D = get_node_or_null("Visuals/PromptLabel3D")
@onready var interaction_area: Area3D = get_node_or_null("InteractionArea")
@onready var left_post: MeshInstance3D = get_node_or_null("Visuals/LeftPost")
@onready var right_post: MeshInstance3D = get_node_or_null("Visuals/RightPost")
@onready var left_beacon: MeshInstance3D = get_node_or_null("Visuals/LeftPost/StatusBeacon")
@onready var right_beacon: MeshInstance3D = get_node_or_null("Visuals/RightPost/StatusBeacon")
@onready var unlock_particles: CPUParticles3D = get_node_or_null("Visuals/UnlockParticles")

func _ready() -> void:
	if not is_in_group("zone_gates"):
		add_to_group("zone_gates")
	collision_layer = 1 # Solid obstacle for Avatar
	collision_mask = 0
	
	if interaction_area != null:
		interaction_area.collision_layer = 0
		interaction_area.collision_mask = 1 # Detect Player (Layer 1)
		interaction_area.body_entered.connect(_on_interaction_body_entered)
		interaction_area.body_exited.connect(_on_interaction_body_exited)
		
	var gs = get_node_or_null("/root/GameState")
	if gs != null:
		if gs.has_signal("zone_unlocked"):
			gs.zone_unlocked.connect(_on_global_zone_unlocked)
		if gs.has_signal("avatar_stat_updated"):
			gs.avatar_stat_updated.connect(_on_stat_updated)
			
		if gs.has_method("is_zone_unlocked") and gs.is_zone_unlocked(zone_id):
			open_gate(false)
		else:
			_update_prompt_display()
	else:
		_update_prompt_display()

func _unhandled_input(event: InputEvent) -> void:
	if not _player_in_range or _is_unlocked:
		return
		
	if event is InputEventKey and event.pressed and not event.is_echo():
		if event.keycode == KEY_E:
			attempt_unlock()
			get_viewport().set_input_as_handled()

func _on_interaction_body_entered(body: Node3D) -> void:
	if body.is_in_group("player") or body is CharacterBody3D:
		_player_in_range = true
		_avatar_ref = body
		_update_prompt_display()
		if prompt_label != null:
			prompt_label.visible = true
			
		if not _is_unlocked:
			var tc = _find_touch_controls()
			if tc != null and tc.has_method("register_interactable"):
				tc.register_interactable(self, "Unlock [E]")
				
		if auto_unlock_on_level and not _is_unlocked:
			var gs = get_node_or_null("/root/GameState")
			if gs != null and gs.has_method("get_idle_level") and gs.get_idle_level() >= required_level:
				attempt_unlock()

func _on_interaction_body_exited(body: Node3D) -> void:
	if body == _avatar_ref or body.is_in_group("player") or body is CharacterBody3D:
		_player_in_range = false
		_avatar_ref = null
		if prompt_label != null and not _is_unlocked:
			prompt_label.visible = false
		var tc = _find_touch_controls()
		if tc != null and tc.has_method("unregister_interactable"):
			tc.unregister_interactable(self)

## Attempts to unlock the gate using idle clearance level or energy payment
func attempt_unlock() -> bool:
	if _is_unlocked:
		return true
		
	var gs = get_node_or_null("/root/GameState")
	if gs == null:
		open_gate(true)
		return true
		
	var current_level: int = gs.get_idle_level() if gs.has_method("get_idle_level") else 1
	var has_level_clearance: bool = current_level >= required_level
	var can_afford: bool = gs.energy >= unlock_cost
	
	if has_level_clearance or can_afford:
		# If level requirement not met, deduct the energy unlock cost
		if not has_level_clearance and can_afford:
			gs.energy -= unlock_cost
			if gs.has_signal("energy_changed"):
				gs.energy_changed.emit(gs.energy, -unlock_cost)
				
		if gs.has_method("unlock_zone"):
			gs.unlock_zone(zone_id)
		else:
			open_gate(true)
			
		gate_interacted.emit(zone_id, true)
		return true
	else:
		current_level = gs.get_idle_level() if gs.has_method("get_idle_level") else 1
		var energy: float = gs.energy
		var feedback_text: String = ""
		if energy < unlock_cost:
			var cost_str = gs.format_number(unlock_cost) if gs.has_method("format_number") else str(int(unlock_cost))
			feedback_text = "Benötigt %s Energie zum Freischalten" % cost_str
		elif current_level < required_level:
			feedback_text = "Benötigt Campus Level %d" % required_level
		else:
			feedback_text = "Benötigt %s Energie zum Freischalten" % str(int(unlock_cost))
		show_missing_resource_feedback(feedback_text)
		_show_denied_feedback()
		gate_interacted.emit(zone_id, false)
		return false

## Opens gate barrier and disables physical collision
func open_gate(animated: bool = true) -> void:
	_is_unlocked = true
	var tc = _find_touch_controls()
	if tc != null and tc.has_method("unregister_interactable"):
		tc.unregister_interactable(self)
	
	if collision_shape != null:
		collision_shape.set_deferred("disabled", true)
		
	if prompt_label != null:
		prompt_label.text = "✓ " + zone_name + " Unlocked"
		prompt_label.modulate = Color(0.3, 1.0, 0.4)
		prompt_label.visible = true
		
	_set_beacon_color(Color(0.2, 1.0, 0.4)) # Green status LED
		
	if unlock_particles != null and animated:
		unlock_particles.restart()
		unlock_particles.emitting = true
		
	if animated:
		var confetti_cls = load("res://scripts/vfx/confetti_burst.gd")
		if confetti_cls != null and confetti_cls.has_method("spawn_burst_3d"):
			confetti_cls.spawn_burst_3d(get_parent() if get_parent() != null else self, global_position + Vector3(0.0, 1.5, 0.0), 45)
		
		# Screen-Shake juice: moderate shake on gate unlock
		var tree = get_tree()
		if tree != null and tree.root != null:
			var m3d = tree.root.find_child("Main3D", true, false)
			if m3d != null and m3d.has_method("add_screen_shake"):
				m3d.add_screen_shake(0.45)
		
	if barrier_mesh != null:
		if animated:
			var tween = create_tween().set_parallel(true)
			tween.tween_property(barrier_mesh, "scale:y", 0.05, 0.4).set_ease(Tween.EASE_IN)
			tween.tween_property(barrier_mesh, "position:y", 0.05, 0.4).set_ease(Tween.EASE_IN)
		else:
			barrier_mesh.scale.y = 0.05
			barrier_mesh.position.y = 0.05
			
	if animated:
		var am = get_node_or_null("/root/AudioManager")
		if am != null and am.has_method("play_sfx_gate_unlock"):
			am.play_sfx_gate_unlock()
			
	gate_unlocked.emit(zone_id)

func _on_global_zone_unlocked(unlocked_id: String) -> void:
	if unlocked_id == zone_id and not _is_unlocked:
		open_gate(true)

func _on_stat_updated(stat_name: String, _val: float) -> void:
	if stat_name == "idle_level" and not _is_unlocked:
		_update_prompt_display()

func _set_beacon_color(c: Color) -> void:
	var mat = StandardMaterial3D.new()
	mat.albedo_color = c
	mat.emission_enabled = true
	mat.emission = c
	mat.emission_energy_multiplier = 1.5
	mat.roughness = 0.2
	if left_beacon != null:
		left_beacon.material_override = mat
	if right_beacon != null:
		right_beacon.material_override = mat
	var pl_beacon = get_node_or_null("Visuals/PostLeft/StatusBeacon") as MeshInstance3D
	if pl_beacon != null:
		pl_beacon.material_override = mat
	var pr_beacon = get_node_or_null("Visuals/PostRight/StatusBeacon") as MeshInstance3D
	if pr_beacon != null:
		pr_beacon.material_override = mat

func show_missing_resource_feedback(text_msg: String = "") -> void:
	var msg: String = text_msg
	if msg.is_empty():
		var gs = get_node_or_null("/root/GameState")
		var current_level: int = gs.get_idle_level() if (gs != null and gs.has_method("get_idle_level")) else 1
		var energy: float = gs.energy if gs != null else 0.0
		if energy < unlock_cost:
			var cost_str = gs.format_number(unlock_cost) if (gs != null and gs.has_method("format_number")) else str(int(unlock_cost))
			msg = "Benötigt %s Energie zum Freischalten" % cost_str
		elif current_level < required_level:
			msg = "Benötigt Campus Level %d" % required_level
		else:
			msg = "Benötigt %s Energie zum Freischalten" % str(int(unlock_cost))

	var target_parent = get_parent() if get_parent() != null else self
	var label = Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = 24
	label.outline_size = 6
	label.text = msg
	label.modulate = Color(1.0, 0.3, 0.3)
	target_parent.add_child(label)
	label.global_position = global_position + Vector3(0.0, 2.5, 0.0)
	
	var tw = label.create_tween().set_parallel(true)
	tw.tween_property(label, "position:y", label.position.y + 1.2, 1.2).set_ease(Tween.EASE_OUT)
	tw.tween_property(label, "modulate:a", 0.0, 1.2)
	tw.chain().tween_callback(label.queue_free)

func _update_prompt_display() -> void:
	if prompt_label == null:
		return
	if _is_unlocked:
		prompt_label.text = "✓ " + zone_name + " Unlocked"
		prompt_label.modulate = Color(0.3, 1.0, 0.4)
		_set_beacon_color(Color(0.2, 1.0, 0.4))
		return
		
	var gs = get_node_or_null("/root/GameState")
	var current_level: int = gs.get_idle_level() if (gs != null and gs.has_method("get_idle_level")) else 1
	var energy: float = gs.energy if gs != null else 0.0
	
	var cost_str = str(int(unlock_cost)) + " Users"
	if gs != null and gs.has_method("format_number"):
		cost_str = gs.format_number(unlock_cost) + " Users"
		
	if current_level >= required_level:
		prompt_label.text = "[E] Unlock " + zone_name + " (Clearance Lvl " + str(required_level) + " Granted)"
		prompt_label.modulate = Color(0.4, 0.9, 1.0)
		_set_beacon_color(Color(0.2, 0.8, 1.0))
	elif energy >= unlock_cost:
		prompt_label.text = "[E] Unlock " + zone_name + " (" + cost_str + " or Lvl " + str(required_level) + ")"
		prompt_label.modulate = Color(1.0, 0.85, 0.3)
		_set_beacon_color(Color(1.0, 0.85, 0.2))
	else:
		prompt_label.text = "[Locked] Requires Clearance Lvl " + str(required_level) + " or " + cost_str
		prompt_label.modulate = Color(1.0, 0.4, 0.4)
		_set_beacon_color(Color(1.0, 0.2, 0.2))

func _show_denied_feedback() -> void:
	if prompt_label != null:
		prompt_label.text = "✖ ACCESS DENIED (Req: Lvl " + str(required_level) + ")"
		prompt_label.modulate = Color(1.0, 0.2, 0.2)
		var tween = create_tween()
		tween.tween_interval(1.2)
		tween.tween_callback(_update_prompt_display)

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
