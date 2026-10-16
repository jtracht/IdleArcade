extends Control

## TechTreeModal Controller (res://scripts/ui/tech_tree_modal.gd)
## Mobile Tech-Tree Modal UI displaying R&D researchable technologies,
## live energy/USB resource bar, 3-state touch buttons (>=56px height),
## and complete touch input isolation preventing 3D ground click-through.

signal closed()

# Node References
@onready var backdrop: ColorRect = get_node_or_null("Backdrop")
@onready var close_button: Button = get_node_or_null("%CloseButton")
@onready var energy_value_label: Label = get_node_or_null("%EnergyValueLabel")
@onready var usb_value_label: Label = get_node_or_null("%USBValueLabel")
@onready var tech_cards_vbox: VBoxContainer = get_node_or_null("%TechCardsVBox")

# 5 Core Technologies
const TECH_IDS: Array[String] = [
	"tech_coffee_automation",
	"tech_delivery_drone",
	"tech_server_overclock",
	"tech_quantum_ads",
	"tech_neural_cloud"
]

const DEFAULT_TECH_METADATA: Dictionary = {
	"tech_coffee_automation": {
		"name": "Coffee Automation",
		"icon": "☕",
		"description": "+15% Avatar Base Speed & +10% Worker Production Frequency",
		"energy_cost": 500.0,
		"required_item": "",
		"required_item_count": 0
	},
	"tech_delivery_drone": {
		"name": "Delivery Drone",
		"icon": "🛸",
		"description": "Deploys autonomous campus delivery drone to gather collectibles",
		"energy_cost": 1500.0,
		"required_item": "usb_drive",
		"required_item_count": 3
	},
	"tech_server_overclock": {
		"name": "Server Overclocking",
		"icon": "⚡",
		"description": "+25% Global Passive RPS & Server Room Overclock Glow",
		"energy_cost": 4000.0,
		"required_item": "",
		"required_item_count": 0
	},
	"tech_quantum_ads": {
		"name": "Quantum Ads",
		"icon": "🎯",
		"description": "2x Base Click Power in 2D & +50% Angel Investor Spawn Chance",
		"energy_cost": 10000.0,
		"required_item": "",
		"required_item_count": 0
	},
	"tech_neural_cloud": {
		"name": "Neural Cloud",
		"icon": "🧠",
		"description": "Doubles Campus Item Multiplier from +5% to +10% per item",
		"energy_cost": 25000.0,
		"required_item": "",
		"required_item_count": 0
	}
}

# Button 3-State Cached StyleBoxes
var _style_researched: StyleBoxFlat = null
var _style_research_active: StyleBoxFlat = null
var _style_locked: StyleBoxFlat = null

# Card Element Maps
var _card_nodes: Dictionary = {}
var _button_nodes: Dictionary = {}
var _cost_labels: Dictionary = {}

func _ready() -> void:
	# Input isolation: root stops click-through to 3D world
	mouse_filter = Control.MOUSE_FILTER_STOP

	_init_styles()
	_register_card_nodes()

	if close_button != null:
		close_button.mouse_filter = Control.MOUSE_FILTER_STOP
		close_button.pressed.connect(close)

	if backdrop != null:
		backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
		backdrop.gui_input.connect(_on_backdrop_gui_input)

	_connect_game_state_signals()
	_update_ui()

func _init_styles() -> void:
	# State 1: Researched (Emerald Green, Checkmark, Disabled)
	_style_researched = StyleBoxFlat.new()
	_style_researched.bg_color = Color(0.10, 0.28, 0.16, 0.95)
	_style_researched.border_color = Color(0.25, 0.95, 0.50, 0.98)
	_style_researched.set_border_width_all(2)
	_style_researched.set_corner_radius_all(10)
	_style_researched.content_margin_left = 12.0
	_style_researched.content_margin_right = 12.0

	# State 2: Research Active (Cyber Cyan / Electric Blue, Clickable)
	_style_research_active = StyleBoxFlat.new()
	_style_research_active.bg_color = Color(0.08, 0.24, 0.42, 0.95)
	_style_research_active.border_color = Color(0.0, 0.88, 1.0, 0.98)
	_style_research_active.set_border_width_all(2)
	_style_research_active.set_corner_radius_all(10)
	_style_research_active.shadow_color = Color(0.0, 0.80, 1.0, 0.45)
	_style_research_active.shadow_size = 6
	_style_research_active.content_margin_left = 12.0
	_style_research_active.content_margin_right = 12.0

	# State 3: Locked (Subdued Slate Gray, Disabled)
	_style_locked = StyleBoxFlat.new()
	_style_locked.bg_color = Color(0.14, 0.17, 0.22, 0.88)
	_style_locked.border_color = Color(0.35, 0.40, 0.48, 0.65)
	_style_locked.set_border_width_all(1)
	_style_locked.set_corner_radius_all(10)
	_style_locked.content_margin_left = 12.0
	_style_locked.content_margin_right = 12.0

func _register_card_nodes() -> void:
	for tech_id in TECH_IDS:
		var card: Control = get_node_or_null("%Card_" + tech_id)
		var btn: Button = get_node_or_null("%Button_" + tech_id)
		var cost_lbl: Label = get_node_or_null("%CostLabel_" + tech_id)

		if card != null:
			card.mouse_filter = Control.MOUSE_FILTER_STOP
			_card_nodes[tech_id] = card
		if cost_lbl != null:
			_cost_labels[tech_id] = cost_lbl
		if btn != null:
			btn.mouse_filter = Control.MOUSE_FILTER_STOP
			btn.focus_mode = Control.FOCUS_NONE
			_button_nodes[tech_id] = btn
			# Connect click handler
			var tid: String = tech_id
			btn.pressed.connect(func(): _on_research_button_pressed(tid))

func _connect_game_state_signals() -> void:
	var gs = _get_game_state()
	if gs == null:
		return

	if gs.has_signal("energy_changed") and not gs.energy_changed.is_connected(_on_energy_changed):
		gs.energy_changed.connect(_on_energy_changed)
	if gs.has_signal("tech_researched") and not gs.tech_researched.is_connected(_on_tech_researched):
		gs.tech_researched.connect(_on_tech_researched)
	if gs.has_signal("collectible_picked_up") and not gs.collectible_picked_up.is_connected(_on_collectible_picked_up):
		gs.collectible_picked_up.connect(_on_collectible_picked_up)

func _disconnect_game_state_signals() -> void:
	var gs = _get_game_state()
	if gs == null:
		return

	if gs.has_signal("energy_changed") and gs.energy_changed.is_connected(_on_energy_changed):
		gs.energy_changed.disconnect(_on_energy_changed)
	if gs.has_signal("tech_researched") and gs.tech_researched.is_connected(_on_tech_researched):
		gs.tech_researched.disconnect(_on_tech_researched)
	if gs.has_signal("collectible_picked_up") and gs.collectible_picked_up.is_connected(_on_collectible_picked_up):
		gs.collectible_picked_up.disconnect(_on_collectible_picked_up)

## Lifecycle open method.
func open(_args: Dictionary = {}) -> void:
	visible = true
	_connect_game_state_signals()
	_update_ui()

## Lifecycle close method. Emits closed signal and frees instance.
func close() -> void:
	_disconnect_game_state_signals()
	closed.emit()
	visible = false
	queue_free()

func _gui_input(event: InputEvent) -> void:
	# Consume any input to prevent raycast leakage into 3D world
	accept_event()

func _on_backdrop_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		close()

func _on_energy_changed(_total_energy: float, _delta: float) -> void:
	_update_ui()

func _on_tech_researched(_tech_id: String) -> void:
	_update_ui()

func _on_collectible_picked_up(_item_type: String, _count: int) -> void:
	_update_ui()

## Updates the resource bar and all 5 technology cards.
func _update_ui() -> void:
	var gs = _get_game_state()
	var cur_energy: float = gs.energy if (gs != null and "energy" in gs) else 0.0
	var cur_usbs: int = 0
	if gs != null and gs.has_method("get_item_count"):
		cur_usbs = gs.get_item_count("usb_drive")
	elif gs != null and "item_inventory" in gs and gs.item_inventory is Dictionary:
		cur_usbs = int(gs.item_inventory.get("usb_drive", 0)) + int(gs.item_inventory.get("usb", 0))

	# Update Resource Bar
	if energy_value_label != null:
		energy_value_label.text = "⚡ %s Energy" % _format_number(cur_energy)
	if usb_value_label != null:
		usb_value_label.text = "💾 %d USB Sticks" % cur_usbs

	# Fetch tech definitions
	var defs: Dictionary = DEFAULT_TECH_METADATA
	if gs != null and gs.has_method("get_tech_definitions"):
		var gs_defs = gs.get_tech_definitions()
		if not gs_defs.is_empty():
			defs = gs_defs

	# Update each Tech Card and Button
	for tech_id in TECH_IDS:
		var btn: Button = _button_nodes.get(tech_id)
		var cost_lbl: Label = _cost_labels.get(tech_id)
		var tdef: Dictionary = defs.get(tech_id, DEFAULT_TECH_METADATA.get(tech_id, {}))
		var energy_cost: float = float(tdef.get("cost", tdef.get("energy_cost", 0.0)))
		var req_item: String = str(tdef.get("required_item", ""))
		var req_count: int = int(tdef.get("required_item_count", 0))

		# Format cost label
		if cost_lbl != null:
			if not req_item.is_empty() and req_count > 0:
				cost_lbl.text = "Cost: ⚡ %s Energy + 💾 %d USB" % [_format_number(energy_cost), req_count]
			else:
				cost_lbl.text = "Cost: ⚡ %s Energy" % _format_number(energy_cost)

		if btn == null:
			continue

		# Determine 3-state condition
		var is_researched: bool = false
		var can_research: bool = false

		if gs != null:
			if gs.has_method("is_tech_researched"):
				is_researched = gs.is_tech_researched(tech_id)
			elif "researched_techs" in gs and gs.researched_techs is Array:
				is_researched = gs.researched_techs.has(tech_id)

			if not is_researched and gs.has_method("can_research_tech"):
				can_research = gs.can_research_tech(tech_id)
			elif not is_researched:
				var has_energy = cur_energy >= energy_cost
				var has_items = true
				if not req_item.is_empty() and req_count > 0:
					has_items = cur_usbs >= req_count
				can_research = has_energy and has_items

		# Apply 3-state button visuals
		if is_researched:
			# State 1: Researched
			btn.text = "Researched ✓"
			btn.disabled = true
			if _style_researched != null:
				btn.add_theme_stylebox_override("disabled", _style_researched)
			btn.add_theme_color_override("font_disabled_color", Color(0.25, 1.0, 0.45, 1.0))
		elif can_research:
			# State 2: Research Active
			btn.text = "Research"
			btn.disabled = false
			if _style_research_active != null:
				btn.add_theme_stylebox_override("normal", _style_research_active)
				btn.add_theme_stylebox_override("hover", _style_research_active)
				btn.add_theme_stylebox_override("pressed", _style_research_active)
			btn.add_theme_color_override("font_color", Color(0.9, 0.98, 1.0, 1.0))
			btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0, 1.0))
		else:
			# State 3: Locked
			btn.disabled = true
			if _style_locked != null:
				btn.add_theme_stylebox_override("disabled", _style_locked)
			btn.add_theme_color_override("font_disabled_color", Color(0.65, 0.70, 0.78, 0.85))

			# Informative text
			if not req_item.is_empty() and req_count > 0 and cur_usbs < req_count:
				var missing_usbs: int = req_count - cur_usbs
				btn.text = "Need %d USB" % missing_usbs
			elif cur_energy < energy_cost:
				var missing_energy: float = energy_cost - cur_energy
				btn.text = "Need %s ⚡" % _format_number(missing_energy)
			else:
				btn.text = "Locked 🔒"

## Handles touch/click on research button.
func _on_research_button_pressed(tech_id: String) -> void:
	var gs = _get_game_state()
	if gs == null:
		return

	if gs.has_method("research_tech"):
		var success: bool = gs.research_tech(tech_id)
		if success:
			_trigger_haptic()
		_update_ui()

func _trigger_haptic() -> void:
	if has_node("/root/HapticFeedback"):
		var haptic = get_node("/root/HapticFeedback")
		if haptic != null and haptic.has_method("vibrate_button"):
			haptic.vibrate_button()

func _get_game_state() -> Node:
	if has_node("/root/GameState"):
		return get_node("/root/GameState")
	return null

func _format_number(val: float) -> String:
	var gs = _get_game_state()
	if gs != null and gs.has_method("format_number"):
		return gs.format_number(val)
	if val < 1000.0:
		return str(int(val))
	elif val < 1000000.0:
		return "%.1f K" % (val / 1000.0)
	elif val < 1000000000.0:
		return "%.1f M" % (val / 1000000.0)
	else:
		return "%.1f B" % (val / 1000000000.0)
