class_name TouchControls
extends Control

## Master Controller for Mobile Touch Controls in IdleArcade (Milestone P5-M2).
## Manages the on-screen action button, laptop thumb overlay toggle, proximity
## detection, button visual state machine, tactile feedback, and strict 3-tier input isolation.

# ------------------------------------------------------------------------------
# Signals
# ------------------------------------------------------------------------------

## Emitted when the primary action button is pressed.
signal action_triggered(interactable: Node3D)

## Emitted when the laptop thumb button is pressed.
signal overlay_toggle_requested()

## Emitted when the campus thumb button is pressed.
signal campus_toggle_requested()

## Emitted when an interactable entity enters proximity range.
signal interactable_registered(interactable: Node3D, label_text: String)

## Emitted when an interactable entity exits proximity range.
signal interactable_unregistered(interactable: Node3D)

## Emitted when the actively targeted interactable changes.
signal interactable_changed(interactable: Node3D)

## Emitted when controls visibility or fade state alters.
signal controls_visibility_changed(is_visible: bool)

## Emitted when a synthetic keyboard event is dispatched.
signal key_synthesized(keycode: Key)

# ------------------------------------------------------------------------------
# Configuration
# ------------------------------------------------------------------------------

@export_group("Visual Styling")
## Opacity of ActionButton when no interactable is in proximity.
@export var dormant_opacity: float = 0.35

## Opacity of ActionButton when an interactable is in proximity.
@export var active_opacity: float = 1.0

## Default label displayed on ActionButton when dormant.
@export var default_action_label: String = "[E] Action"

@export_group("Animation & Feedback")
## Duration in seconds for fading controls in/out when modals open.
@export var modal_fade_duration: float = 0.20

## Scale factor applied to buttons when pressed for spring feedback.
@export var button_spring_scale: float = 0.92

# ------------------------------------------------------------------------------
# Node References
# ------------------------------------------------------------------------------

@onready var virtual_joystick: VirtualJoystick = get_node_or_null("VirtualJoystick") as VirtualJoystick
@onready var action_button: Button = get_node_or_null("%ActionButton") if has_node("%ActionButton") else get_node_or_null("ActionButton")
@onready var laptop_button: Button = get_node_or_null("%LaptopThumbButton") if has_node("%LaptopThumbButton") else get_node_or_null("LaptopThumbButton")
@onready var campus_button: Button = get_node_or_null("%CampusThumbButton") if has_node("%CampusThumbButton") else get_node_or_null("CampusThumbButton")

# ------------------------------------------------------------------------------
# Internal State
# ------------------------------------------------------------------------------

## Currently targeted interactable entity in range.
var active_interactable: Node3D = null

## Stack of currently overlapping interactable entities.
var active_interactables: Array[Node3D] = []

## Alias for active_interactables for blueprint compatibility.
var registered_interactables: Array[Node3D]:
	get:
		return active_interactables
	set(val):
		active_interactables = val

## Track modal fade state.
var is_faded_out: bool = false

## Total count of synthetic keyboard events emitted.
var synthetic_key_count: int = 0

var _fade_tween: Tween = null
var _action_tween: Tween = null
var _laptop_tween: Tween = null
var _campus_tween: Tween = null

var _normal_action_style: StyleBoxFlat = null
var _cached_npc_style: StyleBoxFlat = null
var _cached_quest_style: StyleBoxFlat = null
var _cached_gate_style: StyleBoxFlat = null
var _cached_denied_style: StyleBoxFlat = null
var _cached_collectible_style: StyleBoxFlat = null
var _cached_research_style: StyleBoxFlat = null
var _cached_overclock_style: StyleBoxFlat = null
var _cached_pitch_style: StyleBoxFlat = null
var _cached_hack_style: StyleBoxFlat = null
var _cached_brew_style: StyleBoxFlat = null

# ------------------------------------------------------------------------------
# Lifecycle
# ------------------------------------------------------------------------------

func _ready() -> void:
	# Tier 3 Input Isolation: Root container ignores events to allow upper-screen taps to reach 3D world
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	if not is_in_group("touch_controls"):
		add_to_group("touch_controls")

	if size == Vector2.ZERO:
		size = Vector2(720.0, 1280.0)

	_setup_styles()
	_setup_buttons()
	_update_action_button_visuals(default_action_label, false)

# ------------------------------------------------------------------------------
# Setup & Styling
# ------------------------------------------------------------------------------

func _setup_buttons() -> void:
	var base_w = size.x if size.x > 0.0 else 720.0
	var base_h = size.y if size.y > 0.0 else 1280.0

	if action_button != null:
		# Tier 1 Input Isolation: Button absorbs mouse/touch events
		action_button.mouse_filter = Control.MOUSE_FILTER_STOP
		action_button.focus_mode = Control.FOCUS_NONE
		action_button.custom_minimum_size = Vector2(100.0, 100.0)
		if action_button.size.x < 100.0 or action_button.size.y < 100.0:
			action_button.size = Vector2(100.0, 100.0)
		if action_button.position == Vector2.ZERO:
			action_button.position = Vector2(base_w - 140.0, base_h - 180.0)
		action_button.pivot_offset = Vector2(50.0, 50.0)
		action_button.button_down.connect(_on_action_button_down)
		action_button.button_up.connect(_on_action_button_up)
		action_button.pressed.connect(_on_action_button_pressed)
		action_button.gui_input.connect(_on_button_gui_input)

	if laptop_button != null:
		# Tier 1 Input Isolation: Button absorbs mouse/touch events
		laptop_button.mouse_filter = Control.MOUSE_FILTER_STOP
		laptop_button.focus_mode = Control.FOCUS_NONE
		laptop_button.custom_minimum_size = Vector2(70.0, 70.0)
		if laptop_button.size.x < 70.0 or laptop_button.size.y < 70.0:
			laptop_button.size = Vector2(70.0, 70.0)
		if laptop_button.position == Vector2.ZERO:
			laptop_button.position = Vector2(base_w - 155.0, base_h - 280.0)
		laptop_button.pivot_offset = Vector2(35.0, 35.0)
		laptop_button.button_down.connect(_on_laptop_button_down)
		laptop_button.button_up.connect(_on_laptop_button_up)
		laptop_button.pressed.connect(_on_laptop_button_pressed)
		laptop_button.gui_input.connect(_on_button_gui_input)

	if campus_button != null:
		# Tier 1 Input Isolation: Button absorbs mouse/touch events
		campus_button.mouse_filter = Control.MOUSE_FILTER_STOP
		campus_button.focus_mode = Control.FOCUS_NONE
		campus_button.custom_minimum_size = Vector2(70.0, 70.0)
		if campus_button.size.x < 70.0 or campus_button.size.y < 70.0:
			campus_button.size = Vector2(70.0, 70.0)
		if campus_button.position == Vector2.ZERO:
			campus_button.position = Vector2(base_w - 235.0, base_h - 225.0)
		campus_button.pivot_offset = Vector2(35.0, 35.0)
		campus_button.button_down.connect(_on_campus_button_down)
		campus_button.button_up.connect(_on_campus_button_up)
		campus_button.pressed.connect(_on_campus_button_pressed)
		campus_button.gui_input.connect(_on_button_gui_input)

func _setup_styles() -> void:
	if action_button != null:
		var existing = action_button.get_theme_stylebox("normal")
		if existing is StyleBoxFlat:
			_normal_action_style = existing.duplicate() as StyleBoxFlat

	# Dynamic NPC style (emerald green)
	_cached_npc_style = StyleBoxFlat.new()
	_cached_npc_style.bg_color = Color(0.08, 0.28, 0.18, 0.88)
	_cached_npc_style.border_color = Color(0.25, 0.95, 0.55, 0.95)
	_cached_npc_style.set_border_width_all(3)
	_cached_npc_style.set_corner_radius_all(50)
	_cached_npc_style.corner_detail = 24
	_cached_npc_style.shadow_color = Color(0.15, 0.85, 0.45, 0.5)
	_cached_npc_style.shadow_size = 10
	_cached_npc_style.anti_aliasing = true

	# Dynamic Quest Ready style (amber gold)
	_cached_quest_style = StyleBoxFlat.new()
	_cached_quest_style.bg_color = Color(0.32, 0.26, 0.08, 0.90)
	_cached_quest_style.border_color = Color(1.0, 0.85, 0.20, 0.98)
	_cached_quest_style.set_border_width_all(3)
	_cached_quest_style.set_corner_radius_all(50)
	_cached_quest_style.corner_detail = 24
	_cached_quest_style.shadow_color = Color(0.95, 0.80, 0.15, 0.55)
	_cached_quest_style.shadow_size = 12
	_cached_quest_style.anti_aliasing = true

	# Dynamic Zone Gate Unlock style (neon cyan)
	_cached_gate_style = StyleBoxFlat.new()
	_cached_gate_style.bg_color = Color(0.08, 0.24, 0.38, 0.88)
	_cached_gate_style.border_color = Color(0.30, 0.85, 1.0, 0.95)
	_cached_gate_style.set_border_width_all(3)
	_cached_gate_style.set_corner_radius_all(50)
	_cached_gate_style.corner_detail = 24
	_cached_gate_style.shadow_color = Color(0.20, 0.70, 1.0, 0.5)
	_cached_gate_style.shadow_size = 10
	_cached_gate_style.anti_aliasing = true

	# Dynamic Zone Gate Locked style (coral red)
	_cached_denied_style = StyleBoxFlat.new()
	_cached_denied_style.bg_color = Color(0.32, 0.10, 0.10, 0.85)
	_cached_denied_style.border_color = Color(0.95, 0.35, 0.35, 0.90)
	_cached_denied_style.set_border_width_all(2)
	_cached_denied_style.set_corner_radius_all(50)
	_cached_denied_style.corner_detail = 24
	_cached_denied_style.shadow_color = Color(0.85, 0.20, 0.20, 0.45)
	_cached_denied_style.shadow_size = 8
	_cached_denied_style.anti_aliasing = true

	# Dynamic Collectible style (vibrant violet glow)
	_cached_collectible_style = StyleBoxFlat.new()
	_cached_collectible_style.bg_color = Color(0.24, 0.10, 0.32, 0.88)
	_cached_collectible_style.border_color = Color(0.85, 0.45, 1.0, 0.95)
	_cached_collectible_style.set_border_width_all(3)
	_cached_collectible_style.set_corner_radius_all(50)
	_cached_collectible_style.corner_detail = 24
	_cached_collectible_style.shadow_color = Color(0.75, 0.30, 0.95, 0.55)
	_cached_collectible_style.shadow_size = 12
	_cached_collectible_style.anti_aliasing = true

	# Dynamic Research Terminal style (cyber cyan / deep neon purple)
	_cached_research_style = StyleBoxFlat.new()
	_cached_research_style.bg_color = Color(0.18, 0.08, 0.32, 0.90)
	_cached_research_style.border_color = Color(0.0, 0.90, 1.0, 0.98)
	_cached_research_style.set_border_width_all(3)
	_cached_research_style.set_corner_radius_all(50)
	_cached_research_style.corner_detail = 24
	_cached_research_style.shadow_color = Color(0.70, 0.20, 1.0, 0.55)
	_cached_research_style.shadow_size = 12
	_cached_research_style.anti_aliasing = true

	# Dynamic Overclock style (Electric Blue: Neon-Cyan border, deep navy bg, cyan glow)
	_cached_overclock_style = StyleBoxFlat.new()
	_cached_overclock_style.bg_color = Color(0.04, 0.20, 0.42, 0.90)
	_cached_overclock_style.border_color = Color(0.0, 0.92, 1.0, 0.98)
	_cached_overclock_style.set_border_width_all(3)
	_cached_overclock_style.set_corner_radius_all(50)
	_cached_overclock_style.corner_detail = 24
	_cached_overclock_style.shadow_color = Color(0.0, 0.85, 1.0, 0.6)
	_cached_overclock_style.shadow_size = 12
	_cached_overclock_style.anti_aliasing = true

	# Dynamic Pitch Stage style (Gold: Warm Gold border, dark gold bg, gold spotlight glow)
	_cached_pitch_style = StyleBoxFlat.new()
	_cached_pitch_style.bg_color = Color(0.38, 0.30, 0.05, 0.92)
	_cached_pitch_style.border_color = Color(1.0, 0.84, 0.0, 1.0)
	_cached_pitch_style.set_border_width_all(3)
	_cached_pitch_style.set_corner_radius_all(50)
	_cached_pitch_style.corner_detail = 24
	_cached_pitch_style.shadow_color = Color(1.0, 0.80, 0.1, 0.6)
	_cached_pitch_style.shadow_size = 12
	_cached_pitch_style.anti_aliasing = true

	# Dynamic Hack style (Neon Matrix Green: border #00FF41, dark green bg, matrix shadow glow)
	_cached_hack_style = StyleBoxFlat.new()
	_cached_hack_style.bg_color = Color(0.02, 0.22, 0.08, 0.92)
	_cached_hack_style.border_color = Color(0.0, 1.0, 0.25, 0.98)
	_cached_hack_style.set_border_width_all(3)
	_cached_hack_style.set_corner_radius_all(50)
	_cached_hack_style.corner_detail = 24
	_cached_hack_style.shadow_color = Color(0.0, 1.0, 0.25, 0.60)
	_cached_hack_style.shadow_size = 14
	_cached_hack_style.anti_aliasing = true

	# Dynamic Super-Espresso Brew Lab style (Mocha / Copper Shine: warm mocha bg, copper border, amber shadow glow)
	_cached_brew_style = StyleBoxFlat.new()
	_cached_brew_style.bg_color = Color(0.32, 0.18, 0.08, 0.92)
	_cached_brew_style.border_color = Color(0.92, 0.60, 0.25, 0.98)
	_cached_brew_style.set_border_width_all(3)
	_cached_brew_style.set_corner_radius_all(50)
	_cached_brew_style.corner_detail = 24
	_cached_brew_style.shadow_color = Color(0.85, 0.50, 0.15, 0.60)
	_cached_brew_style.shadow_size = 14
	_cached_brew_style.anti_aliasing = true

# ------------------------------------------------------------------------------
# Input Isolation Shield (Tier 2 & 3)
# ------------------------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventScreenDrag \
			or event is InputEventMouseButton or event is InputEventMouseMotion:
		accept_event()

func _on_button_gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventScreenDrag \
			or event is InputEventMouseButton or event is InputEventMouseMotion:
		accept_event()

# ------------------------------------------------------------------------------
# Proximity Registration Engine
# ------------------------------------------------------------------------------

## Registers an interactable entity that entered player proximity range.
func register_interactable(node: Node3D, label_text: String = "Action [E]") -> void:
	if node == null:
		return
	if not active_interactables.has(node):
		active_interactables.append(node)
	active_interactable = node
	if label_text == "Action [E]" or label_text.is_empty():
		if "Hack" in str(node.get("action_label")) or node.has_method("start_cyber_sync") or node.has_method("can_hack") or node.is_in_group("server_terminals"):
			label_text = "Hack [E]"
		elif "Brew" in str(node.get("action_label")) or node.is_in_group("coffee_machines") or node.has_method("can_brew"):
			label_text = "Brew [E]"
		elif node.has_method("open_research") or node.is_in_group("research_terminals"):
			label_text = "Research [E]"
		elif node.has_method("activate_overclock") or node.get("action_label") == "Overclock [E]":
			label_text = "Overclock [E]"
		elif node.is_in_group("pitch_stages") or node.has_method("pitch_investor") or node.get("action_label") == "Pitch [E]":
			label_text = "Pitch [E]"
		elif node is CharacterBody3D or node.has_method("interact"):
			label_text = "Talk [E]"
		elif node is StaticBody3D or node.has_method("attempt_unlock"):
			label_text = "Unlock [E]"
		elif node is Area3D or node.is_in_group("collectibles") or node.has_method("collect"):
			label_text = "Collect [E]"
	else:
		if "Overclock" in label_text:
			label_text = "Overclock [E]"
		elif "Hack" in label_text:
			label_text = "Hack [E]"
		elif "Brew" in label_text:
			label_text = "Brew [E]"
		elif "Pitch" in label_text:
			label_text = "Pitch [E]"
		elif "Research" in label_text:
			label_text = "Research [E]"
	_update_action_button_visuals(label_text, true)
	interactable_registered.emit(node, label_text)
	interactable_changed.emit(node)

## Unregisters an interactable entity that exited player proximity range.
func unregister_interactable(node: Node3D) -> void:
	if node == null:
		return
	active_interactables.erase(node)
	if active_interactable == node:
		if active_interactables.is_empty():
			active_interactable = null
			_update_action_button_visuals(default_action_label, false)
		else:
			active_interactable = active_interactables.back()
			var remaining_label = "Action [E]"
			if "Hack" in str(active_interactable.get("action_label")) or active_interactable.has_method("start_cyber_sync") or active_interactable.is_in_group("server_terminals"):
				remaining_label = "Hack [E]"
			elif "Brew" in str(active_interactable.get("action_label")) or active_interactable.is_in_group("coffee_machines") or active_interactable.has_method("can_brew"):
				remaining_label = "Brew [E]"
			elif active_interactable.has_method("open_research") or active_interactable.is_in_group("research_terminals"):
				remaining_label = "Research [E]"
			elif active_interactable.has_method("activate_overclock") or active_interactable.get("action_label") == "Overclock [E]":
				remaining_label = "Overclock [E]"
			elif active_interactable.is_in_group("pitch_stages") or active_interactable.has_method("pitch_investor") or active_interactable.get("action_label") == "Pitch [E]":
				remaining_label = "Pitch [E]"
			elif active_interactable is CharacterBody3D or active_interactable.has_method("interact"):
				remaining_label = "Talk [E]"
			elif active_interactable is StaticBody3D or active_interactable.has_method("attempt_unlock"):
				remaining_label = "Unlock [E]"
			elif active_interactable is Area3D or active_interactable.is_in_group("collectibles") or active_interactable.has_method("collect"):
				remaining_label = "Collect [E]"
			_update_action_button_visuals(remaining_label, true)
	interactable_unregistered.emit(node)
	interactable_changed.emit(active_interactable)

## Returns the currently active interactable target.
func get_current_interactable() -> Node3D:
	if is_instance_valid(active_interactable):
		return active_interactable
	if not active_interactables.is_empty():
		var cand = active_interactables.back()
		if is_instance_valid(cand):
			return cand
	return null

# ------------------------------------------------------------------------------
# Action & Laptop Toggle Dispatch (Dual Channel)
# ------------------------------------------------------------------------------

func _on_action_button_pressed() -> void:
	trigger_action()

func _on_laptop_button_pressed() -> void:
	trigger_laptop_toggle()

## Executes interaction with active entity or synthesizes KEY_E event.
func trigger_action() -> void:
	_trigger_haptic_tap()
	var target = get_current_interactable()
	action_triggered.emit(target)

	# Channel 1: Direct Method Invocation
	if is_instance_valid(target):
		if target.has_method("open_research"):
			target.call("open_research")
		elif target.has_method("start_cyber_sync"):
			target.call("start_cyber_sync")
		elif target.has_method("start_hack_minigame"):
			target.call("start_hack_minigame")
		elif target.has_method("start_brew_minigame"):
			target.call("start_brew_minigame")
		elif target.has_method("interact"):
			target.call("interact")
		elif target.has_method("attempt_unlock"):
			target.call("attempt_unlock")
		elif target.has_method("collect"):
			target.call("collect")

	# Channel 2: Synthetic KEY_E Injection (100% backward compatibility)
	_synthesize_key(KEY_E)

## Toggles 2D idle overlay via Main3D or synthesizes KEY_TAB.
func trigger_laptop_toggle() -> void:
	_trigger_haptic_tap()
	overlay_toggle_requested.emit()

	var tree = get_tree()
	if tree != null:
		var has_main_connection = false
		for conn in overlay_toggle_requested.get_connections():
			if conn["callable"].get_object() is Main3D:
				has_main_connection = true
				break
		if not has_main_connection:
			var main_3d = tree.root.find_child("Main3D", true, false)
			if main_3d != null and main_3d.has_method("toggle_hud_overlay"):
				main_3d.call("toggle_hud_overlay")
			else:
				_synthesize_key(KEY_TAB)
	else:
		_synthesize_key(KEY_TAB)

func _synthesize_key(keycode: Key) -> void:
	synthetic_key_count += 1
	key_synthesized.emit(keycode)

	var press = InputEventKey.new()
	press.keycode = keycode
	press.pressed = true
	Input.parse_input_event(press)

	var release = InputEventKey.new()
	release.keycode = keycode
	release.pressed = false
	Input.parse_input_event(release)

# ------------------------------------------------------------------------------
# Visual State Machine & Dynamic Styling
# ------------------------------------------------------------------------------

func _update_action_button_visuals(label_text: String = "", is_active: bool = false) -> void:
	if action_button == null:
		return

	if not is_instance_valid(active_interactable) and not is_active:
		# Dormant Idle State
		action_button.text = default_action_label
		action_button.modulate.a = dormant_opacity
		if _normal_action_style != null:
			action_button.add_theme_stylebox_override("normal", _normal_action_style)
		return

	# Active Illuminated State
	action_button.modulate.a = active_opacity

	var text_to_set = label_text
	if text_to_set.is_empty():
		text_to_set = "Action [E]"

	# Context determination
	var target = get_current_interactable()
	if is_instance_valid(target):
		if "Overclock" in text_to_set:
			text_to_set = "Overclock [E]"
			if _cached_overclock_style != null:
				action_button.add_theme_stylebox_override("normal", _cached_overclock_style)
		elif "Hack" in text_to_set or (target.is_in_group("server_terminals") and str(target.get("action_label")) == "Hack [E]") or target.has_method("start_cyber_sync") or target.has_method("start_hack_minigame"):
			text_to_set = "Hack [E]"
			if _cached_hack_style != null:
				action_button.add_theme_stylebox_override("normal", _cached_hack_style)
		elif "Brew" in text_to_set or target.is_in_group("coffee_machines") or target.has_method("can_brew") or target.has_method("start_brew_minigame") or str(target.get("action_label")) == "Brew [E]":
			text_to_set = "Brew [E]"
			if _cached_brew_style != null:
				action_button.add_theme_stylebox_override("normal", _cached_brew_style)
		elif target.has_method("open_research") or target.is_in_group("research_terminals") or "Research" in text_to_set:
			text_to_set = "Research [E]"
			if _cached_research_style != null:
				action_button.add_theme_stylebox_override("normal", _cached_research_style)
		elif "Pitch" in text_to_set or target.is_in_group("pitch_stages") or target.has_method("pitch_investor"):
			text_to_set = "Pitch [E]"
			if _cached_pitch_style != null:
				action_button.add_theme_stylebox_override("normal", _cached_pitch_style)
		elif target.has_method("interact"):
			var gs = get_node_or_null("/root/GameState")
			var q_id: String = str(target.get("quest_id")) if target.get("quest_id") != null else ""
			var q_status: String = ""
			if gs != null and gs.has_method("get_campus_quest_status") and not q_id.is_empty():
				q_status = gs.get_campus_quest_status(q_id)

			if q_status == "ready":
				text_to_set = "Claim [E]"
				if _cached_quest_style != null:
					action_button.add_theme_stylebox_override("normal", _cached_quest_style)
			else:
				if text_to_set.is_empty() or text_to_set == "Action [E]":
					text_to_set = "Talk [E]"
				if _cached_npc_style != null:
					action_button.add_theme_stylebox_override("normal", _cached_npc_style)

		elif target.has_method("attempt_unlock"):
			var gs = get_node_or_null("/root/GameState")
			var req_lvl: int = int(target.get("required_level")) if target.get("required_level") != null else 1
			var cost: float = float(target.get("unlock_cost")) if target.get("unlock_cost") != null else 0.0

			var cur_lvl: int = gs.get_idle_level() if gs != null and gs.has_method("get_idle_level") else 1
			var energy: float = gs.energy if gs != null else 0.0
			var can_unlock: bool = (cur_lvl >= req_lvl) or (energy >= cost)

			if can_unlock or text_to_set == "Unlock [E]":
				text_to_set = "Unlock [E]"
				if _cached_gate_style != null:
					action_button.add_theme_stylebox_override("normal", _cached_gate_style)
			else:
				text_to_set = "Locked [E]"
				if _cached_denied_style != null:
					action_button.add_theme_stylebox_override("normal", _cached_denied_style)
		elif target is Area3D or target.is_in_group("collectibles") or target.has_method("collect"):
			if text_to_set.is_empty() or text_to_set == "Action [E]":
				text_to_set = "Collect [E]"
			if _cached_collectible_style != null:
				action_button.add_theme_stylebox_override("normal", _cached_collectible_style)
		else:
			if _cached_npc_style != null:
				action_button.add_theme_stylebox_override("normal", _cached_npc_style)
	else:
		# Explicit label provided without object reference
		if "Hack" in text_to_set and _cached_hack_style != null:
			action_button.add_theme_stylebox_override("normal", _cached_hack_style)
		elif "Brew" in text_to_set and _cached_brew_style != null:
			action_button.add_theme_stylebox_override("normal", _cached_brew_style)
		elif "Research" in text_to_set and _cached_research_style != null:
			action_button.add_theme_stylebox_override("normal", _cached_research_style)
		elif "Overclock" in text_to_set and _cached_overclock_style != null:
			action_button.add_theme_stylebox_override("normal", _cached_overclock_style)
		elif "Pitch" in text_to_set and _cached_pitch_style != null:
			action_button.add_theme_stylebox_override("normal", _cached_pitch_style)
		elif "Talk" in text_to_set and _cached_npc_style != null:
			action_button.add_theme_stylebox_override("normal", _cached_npc_style)
		elif "Unlock" in text_to_set and _cached_gate_style != null:
			action_button.add_theme_stylebox_override("normal", _cached_gate_style)
		elif "Claim" in text_to_set and _cached_quest_style != null:
			action_button.add_theme_stylebox_override("normal", _cached_quest_style)
		elif "Collect" in text_to_set and _cached_collectible_style != null:
			action_button.add_theme_stylebox_override("normal", _cached_collectible_style)

	action_button.text = text_to_set

# ------------------------------------------------------------------------------
# Tactile Feedback (Spring Scaling & Haptics)
# ------------------------------------------------------------------------------

func _on_action_button_down() -> void:
	if action_button == null:
		return
	if _action_tween != null and _action_tween.is_valid():
		_action_tween.kill()
	_action_tween = create_tween()
	_action_tween.tween_property(action_button, "scale", Vector2.ONE * button_spring_scale, 0.06)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_OUT)
	_trigger_haptic_tap()

func _on_action_button_up() -> void:
	if action_button == null:
		return
	if _action_tween != null and _action_tween.is_valid():
		_action_tween.kill()
	_action_tween = create_tween()
	_action_tween.tween_property(action_button, "scale", Vector2.ONE, 0.10)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_OUT)

func _on_laptop_button_down() -> void:
	if laptop_button == null:
		return
	if _laptop_tween != null and _laptop_tween.is_valid():
		_laptop_tween.kill()
	_laptop_tween = create_tween()
	_laptop_tween.tween_property(laptop_button, "scale", Vector2.ONE * button_spring_scale, 0.06)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_OUT)
	_trigger_haptic_tap()

func _on_laptop_button_up() -> void:
	if laptop_button == null:
		return
	if _laptop_tween != null and _laptop_tween.is_valid():
		_laptop_tween.kill()
	_laptop_tween = create_tween()
	_laptop_tween.tween_property(laptop_button, "scale", Vector2.ONE, 0.10)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_OUT)

func _on_campus_button_pressed() -> void:
	trigger_campus_toggle()

func trigger_campus_toggle() -> void:
	_trigger_haptic_tap()
	campus_toggle_requested.emit()
	var tree = get_tree()
	if tree != null:
		var main_3d = tree.root.find_child("Main3D", true, false)
		if main_3d != null and main_3d.has_method("close_hud_overlay") and main_3d.has_method("is_hud_overlay_open") and main_3d.call("is_hud_overlay_open"):
			main_3d.call("close_hud_overlay")

func _on_campus_button_down() -> void:
	if campus_button == null:
		return
	if _campus_tween != null and _campus_tween.is_valid():
		_campus_tween.kill()
	_campus_tween = create_tween()
	_campus_tween.tween_property(campus_button, "scale", Vector2.ONE * button_spring_scale, 0.06)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_OUT)
	_trigger_haptic_tap()

func _on_campus_button_up() -> void:
	if campus_button == null:
		return
	if _campus_tween != null and _campus_tween.is_valid():
		_campus_tween.kill()
	_campus_tween = create_tween()
	_campus_tween.tween_property(campus_button, "scale", Vector2.ONE, 0.10)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_OUT)

func _trigger_haptic_tap() -> void:
	var hm = get_node_or_null("/root/HapticsManager")
	if hm != null and hm.has_method("vibrate_button"):
		hm.vibrate_button()
	elif OS.has_feature("mobile") and Input.has_method("vibrate_handheld"):
		Input.vibrate_handheld(20)

# ------------------------------------------------------------------------------
# Modal Fade & Controls Reset
# ------------------------------------------------------------------------------

## Resets joystick and input state (e.g. when a modal opens).
func reset_controls() -> void:
	if is_instance_valid(virtual_joystick) and virtual_joystick.has_method("reset_joystick"):
		virtual_joystick.reset_joystick()

## Fades out touch controls smoothly (e.g. when dialogue or overlay is displayed).
func fade_out_controls(duration: float = -1.0) -> void:
	var dur = modal_fade_duration if duration < 0.0 else duration
	is_faded_out = true
	reset_controls()

	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()

	_fade_tween = create_tween()
	_fade_tween.tween_property(self, "modulate:a", 0.0, dur)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_OUT)
	_fade_tween.tween_callback(func():
		if is_faded_out:
			visible = false
			controls_visibility_changed.emit(false)
	)

## Fades in touch controls smoothly.
func fade_in_controls(duration: float = -1.0) -> void:
	var dur = modal_fade_duration if duration < 0.0 else duration
	is_faded_out = false
	visible = true

	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()

	_fade_tween = create_tween()
	_fade_tween.tween_property(self, "modulate:a", 1.0, dur)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_OUT)
	_fade_tween.tween_callback(func():
		if not is_faded_out:
			controls_visibility_changed.emit(true)
	)
