extends Control
class_name EspressoBrewMinigame

## Espresso Brew Lab Sweet-Spot Pressure Minigame (Phase 11 M3).
## Interactive pressure dynamics: Maintain 62-84 bar for 3.0 seconds
## to brew the legendary Unicorn Espresso (+50% Avatar speed, +20% incubator workers).

signal brew_completed(unicorn_espresso: bool)
signal brew_cancelled()
signal pressure_changed(pressure: float, in_sweet_spot: bool)

@export var sweet_spot_min: float = 62.0
@export var sweet_spot_max: float = 84.0
@export var required_hold_time: float = 3.0
@export var pressure_decay_rate: float = 24.0
@export var pump_increment: float = 15.0
@export var initial_pressure: float = 20.0

var current_pressure: float = 20.0
var current_hold_time: float = 0.0
var is_active: bool = false
var is_finished: bool = false

@onready var backdrop: ColorRect = get_node_or_null("Backdrop")
@onready var card_panel: PanelContainer = get_node_or_null("CenterContainer/CardPanel")
@onready var title_label: Label = get_node_or_null("%TitleLabel")
@onready var subtitle_label: Label = get_node_or_null("%SubtitleLabel")
@onready var pressure_bar: ProgressBar = get_node_or_null("%PressureProgressBar")
@onready var pressure_label: Label = get_node_or_null("%PressureLabel")
@onready var extraction_bar: ProgressBar = get_node_or_null("%ExtractionProgressBar")
@onready var extraction_label: Label = get_node_or_null("%ExtractionLabel")
@onready var status_label: Label = get_node_or_null("%StatusLabel")
@onready var pump_button: Button = get_node_or_null("%PumpButton")
@onready var close_button: Button = get_node_or_null("%CloseButton")

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	if backdrop != null:
		backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	if card_panel != null:
		card_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	if pump_button != null:
		pump_button.mouse_filter = Control.MOUSE_FILTER_STOP
		if not pump_button.pressed.is_connected(_on_pump_pressed):
			pump_button.pressed.connect(_on_pump_pressed)
	if close_button != null:
		close_button.mouse_filter = Control.MOUSE_FILTER_STOP
		if not close_button.pressed.is_connected(_on_close_pressed):
			close_button.pressed.connect(_on_close_pressed)
			
	reset_minigame()

func _gui_input(event: InputEvent) -> void:
	# Enforce complete input isolation to prevent bleed-through into 3D campus
	accept_event()

func _unhandled_input(event: InputEvent) -> void:
	if not visible or not is_active or is_finished:
		return
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		if event.keycode == KEY_E or event.keycode == KEY_SPACE:
			simulate_pump(pump_increment)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE:
			_on_close_pressed()
			get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if not is_active or is_finished:
		return
		
	var safe_delta: float = minf(0.1, maxf(0.0, delta))
	
	# Pressure decays naturally over time
	current_pressure = maxf(0.0, current_pressure - pressure_decay_rate * safe_delta)
	
	var in_sweet_spot: bool = is_in_sweet_spot()
	if in_sweet_spot:
		current_hold_time = minf(required_hold_time, current_hold_time + safe_delta)
	else:
		# Soft decay when dropping out of the sweet spot
		current_hold_time = maxf(0.0, current_hold_time - safe_delta * 0.4)
		
	_update_display()
	pressure_changed.emit(current_pressure, in_sweet_spot)
	
	if current_hold_time >= required_hold_time:
		complete_brew(true)

## Programmatic API: simulate tapping the pump to raise pressure
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

## Programmatic query: checks if pressure is within sweet spot zone
func is_in_sweet_spot() -> bool:
	return current_pressure >= sweet_spot_min and current_pressure <= sweet_spot_max

## Returns current pressure value (0.0 to 100.0)
func get_current_pressure() -> float:
	return current_pressure

## Returns normalized extraction hold progress (0.0 to 1.0)
func get_hold_progress() -> float:
	return current_hold_time / required_hold_time if required_hold_time > 0.0 else 0.0

## Completes the brew cycle and dispatches rewards/signals
func complete_brew(success: bool = true) -> void:
	if is_finished:
		return
	is_finished = true
	is_active = false
	
	if success:
		if status_label != null:
			status_label.text = "🦄 UNICORN ESPRESSO EXTRACTED! (+50% Speed / +20% Workers)"
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

## Closes modal
func close_minigame() -> void:
	is_active = false
	visible = false

## Resets all parameters to initial state
func reset_minigame() -> void:
	current_pressure = initial_pressure
	current_hold_time = 0.0
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
			pressure_label.text = "PRESSURE: %.1f BAR (LOW - PUMP NOW!)" % current_pressure
			pressure_label.modulate = Color(0.96, 0.75, 0.3)
		else:
			pressure_label.text = "PRESSURE: %.1f BAR (OVERPRESSURE!)" % current_pressure
			pressure_label.modulate = Color(1.0, 0.35, 0.35)
			
	if status_label != null and not is_finished:
		if in_spot:
			status_label.text = "Hold in golden zone! Extracting: %.1fs / %.1fs" % [current_hold_time, required_hold_time]
			status_label.modulate = Color(0.2, 1.0, 0.5)
		elif current_pressure < sweet_spot_min:
			status_label.text = "Tap PUMP [E] to build extraction pressure!"
			status_label.modulate = Color(0.96, 0.75, 0.3)
		else:
			status_label.text = "Release! Wait for pressure to bleed into sweet spot!"
			status_label.modulate = Color(1.0, 0.35, 0.35)

func _on_pump_pressed() -> void:
	simulate_pump(pump_increment)

func _on_close_pressed() -> void:
	if not is_finished:
		brew_cancelled.emit()
	close_minigame()
