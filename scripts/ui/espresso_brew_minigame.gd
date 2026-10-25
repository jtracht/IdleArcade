extends Control
class_name EspressoBrewMinigame

## Super-Espresso Brew Lab Sweet-Spot Pressure Minigame (Phase 16 Milestone 2).
## Interactive manometer dynamics: Maintain 62.0 to 84.0 bar for 3.0 seconds
## by holding and releasing the pump valve to brew the legendary Unicorn Espresso.
## Triggers GameState.give_team_coffee_break() to heal staff burnout and activate 60s Hyper-Focus.

signal brew_completed(success: bool)
signal brew_cancelled()
signal closed()
signal pressure_changed(pressure: float, in_sweet_spot: bool)

@export var sweet_spot_min: float = 62.0
@export var sweet_spot_max: float = 84.0
@export var required_hold_time: float = 3.0
@export var pressure_decay_rate: float = 24.0      # -24.0 bar/s natural bleed-off
@export var pressure_rise_rate: float = 40.0       # +40.0 bar/s when holding (range 35-45)
@export var pump_increment: float = 15.0           # +15.0 bar per discrete tap/pump
@export var initial_pressure: float = 20.0         # 20.0 bar initial resting pressure

var current_pressure: float = 20.0
var current_hold_time: float = 0.0
var is_holding: bool = false
var is_active: bool = false
var is_finished: bool = false
var _was_in_sweet_spot: bool = false

@onready var backdrop: ColorRect = get_node_or_null("Backdrop")
@onready var card_panel: PanelContainer = get_node_or_null("CenterContainer/CardPanel")
@onready var title_label: Label = get_node_or_null("%TitleLabel")
@onready var subtitle_label: Label = get_node_or_null("%SubtitleLabel")
@onready var pressure_bar: ProgressBar = get_node_or_null("%PressureProgressBar")
@onready var pressure_label: Label = get_node_or_null("%PressureLabel")
@onready var extraction_bar: ProgressBar = get_node_or_null("%ExtractionProgressBar")
@onready var extraction_label: Label = get_node_or_null("%ExtractionLabel")
@onready var status_label: Label = get_node_or_null("%StatusLabel")
@onready var pump_button: Button = get_node_or_null("%PumpButton") if has_node("%PumpButton") else get_node_or_null("%HoldButton")
@onready var hold_button: Button = pump_button
@onready var close_button: Button = get_node_or_null("%CloseButton")

func _ready() -> void:
	# Enforce Mobile Touch Ergonomics and Pointer Isolation (>= 56px and MOUSE_FILTER_STOP)
	mouse_filter = Control.MOUSE_FILTER_STOP
	if backdrop != null:
		backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	if card_panel != null:
		card_panel.mouse_filter = Control.MOUSE_FILTER_STOP

	if pump_button != null:
		pump_button.custom_minimum_size.y = maxf(pump_button.custom_minimum_size.y, 56.0)
		pump_button.mouse_filter = Control.MOUSE_FILTER_STOP
		if not pump_button.button_down.is_connected(_on_pump_button_down):
			pump_button.button_down.connect(_on_pump_button_down)
		if not pump_button.button_up.is_connected(_on_pump_button_up):
			pump_button.button_up.connect(_on_pump_button_up)
		if not pump_button.pressed.is_connected(_on_pump_pressed):
			pump_button.pressed.connect(_on_pump_pressed)

	if close_button != null:
		close_button.custom_minimum_size.x = maxf(close_button.custom_minimum_size.x, 56.0)
		close_button.custom_minimum_size.y = maxf(close_button.custom_minimum_size.y, 56.0)
		close_button.mouse_filter = Control.MOUSE_FILTER_STOP
		if not close_button.pressed.is_connected(_on_close_pressed):
			close_button.pressed.connect(_on_close_pressed)

	reset_minigame()

func _gui_input(event: InputEvent) -> void:
	# Strict pointer event absorption: prevents touch gestures leaking into 3D camera
	accept_event()

func _unhandled_input(event: InputEvent) -> void:
	if not visible or not is_active or is_finished:
		return
	if event is InputEventKey:
		if event.keycode == KEY_E or event.keycode == KEY_SPACE:
			if event.is_pressed() and not event.is_echo():
				is_holding = true
				var am = get_node_or_null("/root/AudioManager")
				if am != null and am.has_method("play_sfx_click"):
					am.play_sfx_click()
				get_viewport().set_input_as_handled()
			elif not event.is_pressed():
				is_holding = false
				get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE and event.is_pressed():
			_on_close_pressed()
			get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if not is_active or is_finished:
		return

	var safe_delta: float = minf(0.1, maxf(0.0, delta))

	# Hold builds pressure (+40 bar/s); releasing bleeds pressure off (-24 bar/s)
	if is_holding:
		current_pressure = minf(100.0, current_pressure + pressure_rise_rate * safe_delta)
	else:
		current_pressure = maxf(0.0, current_pressure - pressure_decay_rate * safe_delta)

	var in_sweet_spot: bool = is_in_sweet_spot()
	if in_sweet_spot and not _was_in_sweet_spot:
		var hm = get_node_or_null("/root/HapticsManager")
		if hm != null:
			if hm.has_method("vibrate_sweet_spot"):
				hm.vibrate_sweet_spot()
			elif hm.has_method("vibrate_medium"):
				hm.vibrate_medium(35, true)
	_was_in_sweet_spot = in_sweet_spot

	if in_sweet_spot:
		current_hold_time = minf(required_hold_time, current_hold_time + safe_delta)
	else:
		# Soft decay when outside the golden extraction zone
		current_hold_time = maxf(0.0, current_hold_time - safe_delta * 0.4)

	# Overpressure subtle tremor juice
	if current_pressure >= 99.5 and is_holding:
		var tree = get_tree()
		if tree != null and tree.root != null:
			var m3d: Node = tree.root.find_child("Main3D", true, false)
			if m3d != null and m3d.has_method("add_screen_shake"):
				m3d.add_screen_shake(0.04)

	_update_display()
	pressure_changed.emit(current_pressure, in_sweet_spot)

	if current_hold_time >= required_hold_time:
		complete_brew(true)

## Programmatic API: simulates holding the pressure valve for duration seconds
func simulate_hold(duration: float) -> void:
	if not is_active or is_finished or duration <= 0.0:
		return
	var steps: int = maxi(1, int(ceilf(duration / 0.05)))
	var dt: float = duration / float(steps)
	is_holding = true
	for i in range(steps):
		current_pressure = minf(100.0, current_pressure + pressure_rise_rate * dt)
		var in_spot: bool = is_in_sweet_spot()
		if in_spot:
			current_hold_time = minf(required_hold_time, current_hold_time + dt)
		else:
			current_hold_time = maxf(0.0, current_hold_time - dt * 0.4)
		if current_hold_time >= required_hold_time:
			complete_brew(true)
			break
	is_holding = false
	_update_display()
	pressure_changed.emit(current_pressure, is_in_sweet_spot())

## Programmatic API: simulates tapping the pump to raise pressure instantly
func simulate_pump(amount: float = 15.0) -> void:
	if not is_active or is_finished:
		return
	current_pressure = minf(100.0, current_pressure + amount)
	var in_spot: bool = is_in_sweet_spot()
	_update_display()
	pressure_changed.emit(current_pressure, in_spot)

	var am = get_node_or_null("/root/AudioManager")
	if am != null and am.has_method("play_sfx_click"):
		am.play_sfx_click()

## Programmatic query: checks if pressure is within sweet spot zone [62.0, 84.0]
func is_in_sweet_spot() -> bool:
	return current_pressure >= sweet_spot_min and current_pressure <= sweet_spot_max

## Returns current pressure value (0.0 to 100.0 bar)
func get_current_pressure() -> float:
	return current_pressure

## Programmatic query: returns true if minigame is active and ready to brew
func can_brew() -> bool:
	return is_active and not is_finished

## Returns normalized extraction hold progress (0.0 to 1.0)
func get_hold_progress() -> float:
	return current_hold_time / required_hold_time if required_hold_time > 0.0 else 0.0

## Completes the brew cycle and dispatches rewards/signals
func complete_brew(success: bool = true) -> void:
	if is_finished:
		return
	is_finished = true
	is_active = false
	is_holding = false

	if success:
		# Staff Burnout Healing & 60s Hyper-Focus Mode Synergy
		var gs = get_node_or_null("/root/GameState")
		if gs != null and gs.has_method("give_team_coffee_break"):
			gs.give_team_coffee_break()

		# 2D celebratory particle burst
		var confetti_cls = load("res://scripts/vfx/confetti_burst.gd")
		if confetti_cls != null and confetti_cls.has_method("spawn_burst_2d"):
			confetti_cls.spawn_burst_2d(self, size * 0.5, 30)

		# Screen shake juice on extraction completion
		var tree = get_tree()
		if tree != null:
			var m3d: Node = tree.root.find_child("Main3D", true, false) if tree.root != null else null
			if m3d == null and tree.current_scene != null and tree.current_scene.has_method("add_screen_shake"):
				m3d = tree.current_scene
			if m3d != null and m3d.has_method("add_screen_shake"):
				m3d.add_screen_shake(0.30)

		var am = get_node_or_null("/root/AudioManager")
		if am != null:
			if am.has_method("play_sfx_victory_jingle"):
				am.play_sfx_victory_jingle()
			elif am.has_method("play_sfx_confetti"):
				am.play_sfx_confetti()

		var hm = get_node_or_null("/root/HapticsManager")
		if hm != null:
			if hm.has_method("vibrate_success"):
				hm.vibrate_success()
			elif hm.has_method("vibrate_success_pattern"):
				hm.vibrate_success_pattern()

		if status_label != null:
			status_label.text = "☕ UNICORN ESPRESSO EXTRACTED! (Staff Healed & 60s Hyper-Focus!)"
			status_label.modulate = Color(0.96, 0.70, 0.28)
		if extraction_bar != null:
			extraction_bar.value = required_hold_time
		if extraction_label != null:
			extraction_label.text = "Extraction Progress: 100% [PERFECT]"
	else:
		if status_label != null:
			status_label.text = "Extraction interrupted!"
			status_label.modulate = Color(1.0, 0.4, 0.4)

	brew_completed.emit(success)

## Opens modal and resets simulation
func open_minigame() -> void:
	reset_minigame()
	visible = true
	is_active = true
	is_finished = false
	_update_display()

## Closes modal and emits closed signal
func close_minigame() -> void:
	is_active = false
	is_holding = false
	visible = false
	closed.emit()

## Resets all parameters to initial state
func reset_minigame() -> void:
	current_pressure = initial_pressure
	current_hold_time = 0.0
	is_holding = false
	is_active = true
	is_finished = false
	_update_display()

func _update_display() -> void:
	if pressure_bar != null:
		pressure_bar.value = current_pressure

	if extraction_bar != null:
		extraction_bar.value = current_hold_time

	if extraction_label != null:
		var pct: int = int((current_hold_time / required_hold_time) * 100.0) if required_hold_time > 0.0 else 0
		extraction_label.text = "Extraction Progress: %d%% (%.1fs / %.1fs)" % [pct, current_hold_time, required_hold_time]

	var in_spot: bool = is_in_sweet_spot()
	if pressure_label != null:
		if in_spot:
			pressure_label.text = "PRESSURE: %.1f BAR [SWEET SPOT!]" % current_pressure
			pressure_label.modulate = Color(0.2, 1.0, 0.5)
		elif current_pressure < sweet_spot_min:
			pressure_label.text = "PRESSURE: %.1f BAR (LOW - HOLD PUMP!)" % current_pressure
			pressure_label.modulate = Color(0.96, 0.75, 0.3)
		else:
			pressure_label.text = "PRESSURE: %.1f BAR (OVERPRESSURE - RELEASE!)" % current_pressure
			pressure_label.modulate = Color(1.0, 0.35, 0.35)

	if status_label != null and not is_finished:
		if in_spot:
			status_label.text = "Holding in golden zone! Extracting: %.1fs / %.1fs" % [current_hold_time, required_hold_time]
			status_label.modulate = Color(0.2, 1.0, 0.5)
		elif current_pressure < sweet_spot_min:
			status_label.text = "Hold PUMP [E] to build extraction pressure!"
			status_label.modulate = Color(0.96, 0.75, 0.3)
		else:
			status_label.text = "Release! Allow pressure to bleed into sweet spot!"
			status_label.modulate = Color(1.0, 0.35, 0.35)

func _on_pump_button_down() -> void:
	if not is_active or is_finished:
		return
	is_holding = true
	var am = get_node_or_null("/root/AudioManager")
	if am != null:
		if am.has_method("play_sfx_steam_hiss"):
			am.play_sfx_steam_hiss()
		elif am.has_method("play_sfx_click"):
			am.play_sfx_click()

func _on_pump_button_up() -> void:
	is_holding = false

func _on_pump_pressed() -> void:
	# Discrete tap fallback: provides immediate bump if tapped rather than held
	if not is_active or is_finished:
		return
	if not is_holding:
		simulate_pump(pump_increment)

func _on_close_pressed() -> void:
	if not is_finished:
		brew_cancelled.emit()
	close_minigame()
