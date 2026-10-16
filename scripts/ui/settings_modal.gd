extends Control

## SettingsModal Controller (res://scripts/ui/settings_modal.gd)
## Mobile Settings Modal for IdleArcade (Godot 4.3).
## Provides touch-ergonomic audio sliders, mute toggles, haptic feedback toggle,
## and battery saver (30 FPS vs 60 FPS) toggle with strict input isolation
## and defensive duck typing for isolated testing environments.

signal closed()
signal master_volume_changed(val: float)
signal sfx_volume_changed(val: float)
signal music_volume_changed(val: float)
signal master_mute_changed(muted: bool)
signal sfx_mute_changed(muted: bool)
signal music_mute_changed(muted: bool)
signal haptics_toggled(enabled: bool)
signal battery_saver_toggled(enabled: bool)
signal screen_shake_changed(intensity: float)
signal light_cycle_mode_changed(mode: String)

# Node References
@onready var backdrop: ColorRect = get_node_or_null("Backdrop")
@onready var close_button: Button = get_node_or_null("%CloseButton")

@onready var master_slider: HSlider = get_node_or_null("%MasterVolumeSlider")
@onready var master_value_label: Label = get_node_or_null("%MasterVolumeValue")
@onready var master_mute_toggle: Button = get_node_or_null("%MasterMuteToggle")

@onready var sfx_slider: HSlider = get_node_or_null("%SFXVolumeSlider")
@onready var sfx_value_label: Label = get_node_or_null("%SFXVolumeValue")
@onready var sfx_mute_toggle: Button = get_node_or_null("%SFXMuteToggle")

@onready var music_slider: HSlider = get_node_or_null("%MusicVolumeSlider")
@onready var music_value_label: Label = get_node_or_null("%MusicVolumeValue")
@onready var music_mute_toggle: Button = get_node_or_null("%MusicMuteToggle")

@onready var haptics_toggle: Button = get_node_or_null("%HapticsToggle")
@onready var battery_saver_toggle: Button = get_node_or_null("%BatterySaverToggle")
@onready var screen_shake_slider: HSlider = get_node_or_null("%ScreenShakeSlider")
@onready var screen_shake_value_label: Label = get_node_or_null("%ScreenShakeValue")

@onready var light_cycle_auto_btn: Button = get_node_or_null("%LightCycleAutoButton")
@onready var light_cycle_day_btn: Button = get_node_or_null("%LightCycleDayButton")
@onready var light_cycle_night_btn: Button = get_node_or_null("%LightCycleNightButton")
@onready var light_cycle_value_label: Label = get_node_or_null("%LightCycleValue")

# Internal State Fallbacks
var master_volume: float = 1.0
var music_volume: float = 0.8
var sfx_volume: float = 1.0
var master_muted: bool = false
var music_muted: bool = false
var sfx_muted: bool = false
var haptics_enabled: bool = true
var battery_saver_enabled: bool = false
var screen_shake_intensity: float = 1.0
var light_cycle_mode: String = "auto"

var _is_updating_ui: bool = false

func _ready() -> void:
	# Input isolation: root stops all pointer events leaking to 3D world
	mouse_filter = Control.MOUSE_FILTER_STOP

	if backdrop != null:
		backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
		if not backdrop.gui_input.is_connected(_on_backdrop_gui_input):
			backdrop.gui_input.connect(_on_backdrop_gui_input)

	if close_button != null:
		close_button.mouse_filter = Control.MOUSE_FILTER_STOP
		if not close_button.pressed.is_connected(close):
			close_button.pressed.connect(close)

	_bind_controls()
	_connect_game_state_signals()
	open()

## Binds UI control signals to internal handlers.
func _bind_controls() -> void:
	if master_slider != null and not master_slider.value_changed.is_connected(_on_master_slider_changed):
		master_slider.value_changed.connect(_on_master_slider_changed)
	if master_mute_toggle != null and not master_mute_toggle.toggled.is_connected(_on_master_mute_toggled):
		master_mute_toggle.toggled.connect(_on_master_mute_toggled)

	if sfx_slider != null and not sfx_slider.value_changed.is_connected(_on_sfx_slider_changed):
		sfx_slider.value_changed.connect(_on_sfx_slider_changed)
	if sfx_mute_toggle != null and not sfx_mute_toggle.toggled.is_connected(_on_sfx_mute_toggled):
		sfx_mute_toggle.toggled.connect(_on_sfx_mute_toggled)

	if music_slider != null and not music_slider.value_changed.is_connected(_on_music_slider_changed):
		music_slider.value_changed.connect(_on_music_slider_changed)
	if music_mute_toggle != null and not music_mute_toggle.toggled.is_connected(_on_music_mute_toggled):
		music_mute_toggle.toggled.connect(_on_music_mute_toggled)

	if haptics_toggle != null and not haptics_toggle.toggled.is_connected(_on_haptics_toggled):
		haptics_toggle.toggled.connect(_on_haptics_toggled)

	if battery_saver_toggle != null and not battery_saver_toggle.toggled.is_connected(_on_battery_saver_toggled):
		battery_saver_toggle.toggled.connect(_on_battery_saver_toggled)

	if screen_shake_slider != null and not screen_shake_slider.value_changed.is_connected(_on_screen_shake_slider_changed):
		screen_shake_slider.value_changed.connect(_on_screen_shake_slider_changed)

	if light_cycle_auto_btn != null and not light_cycle_auto_btn.pressed.is_connected(_on_light_cycle_auto_pressed):
		light_cycle_auto_btn.pressed.connect(_on_light_cycle_auto_pressed)
	if light_cycle_day_btn != null and not light_cycle_day_btn.pressed.is_connected(_on_light_cycle_day_pressed):
		light_cycle_day_btn.pressed.connect(_on_light_cycle_day_pressed)
	if light_cycle_night_btn != null and not light_cycle_night_btn.pressed.is_connected(_on_light_cycle_night_pressed):
		light_cycle_night_btn.pressed.connect(_on_light_cycle_night_pressed)

## Connects to GameState audio & VFX settings signals for real-time external synchronization.
func _connect_game_state_signals() -> void:
	var gs = _get_game_state()
	if gs != null and gs.has_signal("audio_settings_changed"):
		if not gs.audio_settings_changed.is_connected(_on_game_state_audio_changed):
			gs.audio_settings_changed.connect(_on_game_state_audio_changed)
	if gs != null and gs.has_signal("screen_shake_changed"):
		if not gs.screen_shake_changed.is_connected(_on_game_state_screen_shake_changed):
			gs.screen_shake_changed.connect(_on_game_state_screen_shake_changed)
	if gs != null and gs.has_signal("light_cycle_mode_changed"):
		if not gs.light_cycle_mode_changed.is_connected(_on_game_state_light_cycle_changed):
			gs.light_cycle_mode_changed.connect(_on_game_state_light_cycle_changed)

func _disconnect_game_state_signals() -> void:
	var gs = _get_game_state()
	if gs != null and gs.has_signal("audio_settings_changed"):
		if gs.audio_settings_changed.is_connected(_on_game_state_audio_changed):
			gs.audio_settings_changed.disconnect(_on_game_state_audio_changed)
	if gs != null and gs.has_signal("screen_shake_changed"):
		if gs.screen_shake_changed.is_connected(_on_game_state_screen_shake_changed):
			gs.screen_shake_changed.disconnect(_on_game_state_screen_shake_changed)
	if gs != null and gs.has_signal("light_cycle_mode_changed"):
		if gs.light_cycle_mode_changed.is_connected(_on_game_state_light_cycle_changed):
			gs.light_cycle_mode_changed.disconnect(_on_game_state_light_cycle_changed)

## Lifecycle open method. Reads current game and system states and refreshes UI.
func open(_args: Dictionary = {}) -> void:
	visible = true
	_read_current_state()
	_update_ui()

## Lifecycle close method. Emits closed signal, plays click sfx, and frees modal.
func close() -> void:
	_disconnect_game_state_signals()
	var am = _get_audio_manager()
	if am != null and am.has_method("play_sfx_click"):
		am.play_sfx_click()

	var gs = _get_game_state()
	if gs != null and gs.has_method("save_to_disk"):
		gs.save_to_disk()

	closed.emit()
	visible = false
	queue_free()

## Swallows any pointer events on the root modal control.
func _gui_input(event: InputEvent) -> void:
	accept_event()

## Closes modal when tapping outside the dialog card onto the dark backdrop.
func _on_backdrop_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		close()

# ------------------------------------------------------------------------------
# State Synchronization
# ------------------------------------------------------------------------------

func _read_current_state() -> void:
	var gs = _get_game_state()
	var am = _get_audio_manager()

	# 1. Master Volume & Mute
	if gs != null and "master_volume" in gs:
		master_volume = float(gs.master_volume)
	elif am != null and am.has_method("get_master_volume"):
		master_volume = am.get_master_volume()

	if gs != null and "master_muted" in gs:
		master_muted = bool(gs.master_muted)
	elif am != null and am.has_method("is_master_muted"):
		master_muted = am.is_master_muted()

	# 2. SFX Volume & Mute
	if gs != null and "sfx_volume" in gs:
		sfx_volume = float(gs.sfx_volume)
	elif am != null and am.has_method("get_sfx_volume"):
		sfx_volume = am.get_sfx_volume()

	if gs != null and "sfx_muted" in gs:
		sfx_muted = bool(gs.sfx_muted)
	elif am != null and am.has_method("is_sfx_muted"):
		sfx_muted = am.is_sfx_muted()

	# 3. Music Volume & Mute
	if gs != null and "music_volume" in gs:
		music_volume = float(gs.music_volume)
	elif am != null and am.has_method("get_music_volume"):
		music_volume = am.get_music_volume()

	if gs != null and "music_muted" in gs:
		music_muted = bool(gs.music_muted)
	elif am != null and am.has_method("is_music_muted"):
		music_muted = am.is_music_muted()

	# 4. Haptics
	var hm = _get_haptics_manager()
	if hm != null and hm.has_method("is_haptics_enabled"):
		haptics_enabled = hm.is_haptics_enabled()

	# 5. Battery Saver / FPS
	var cur_fps: int = Engine.max_fps
	battery_saver_enabled = (cur_fps > 0 and cur_fps <= 30)

	# 6. Screen Shake
	if gs != null and "screen_shake_intensity" in gs:
		screen_shake_intensity = float(gs.screen_shake_intensity)
	elif gs != null and gs.has_method("get_screen_shake_intensity"):
		screen_shake_intensity = gs.get_screen_shake_intensity()

	# 7. Light Cycle Mode
	if gs != null and "light_cycle_mode" in gs:
		light_cycle_mode = str(gs.light_cycle_mode)
	elif gs != null and gs.has_method("get_light_cycle_mode"):
		light_cycle_mode = gs.get_light_cycle_mode()
	else:
		light_cycle_mode = "auto"

func _update_ui() -> void:
	_is_updating_ui = true

	# Master
	if master_slider != null:
		master_slider.value = master_volume
	if master_value_label != null:
		master_value_label.text = "%d%%" % int(round(master_volume * 100.0))
	if master_mute_toggle != null:
		master_mute_toggle.button_pressed = master_muted
		master_mute_toggle.text = "🔇 Master Ton: Stumm" if master_muted else "🔊 Master Ton: Aktiv"

	# SFX
	if sfx_slider != null:
		sfx_slider.value = sfx_volume
	if sfx_value_label != null:
		sfx_value_label.text = "%d%%" % int(round(sfx_volume * 100.0))
	if sfx_mute_toggle != null:
		sfx_mute_toggle.button_pressed = sfx_muted
		sfx_mute_toggle.text = "🔇 SFX Ton: Stumm" if sfx_muted else "🎮 SFX Ton: Aktiv"

	# Music
	if music_slider != null:
		music_slider.value = music_volume
	if music_value_label != null:
		music_value_label.text = "%d%%" % int(round(music_volume * 100.0))
	if music_mute_toggle != null:
		music_mute_toggle.button_pressed = music_muted
		music_mute_toggle.text = "🔇 Musik Ton: Stumm" if music_muted else "🎵 Musik Ton: Aktiv"

	# Haptics
	if haptics_toggle != null:
		haptics_toggle.button_pressed = haptics_enabled
		haptics_toggle.text = "📳 Haptik Feedback: AN" if haptics_enabled else "📴 Haptik Feedback: AUS"

	# Battery Saver
	if battery_saver_toggle != null:
		battery_saver_toggle.button_pressed = battery_saver_enabled
		battery_saver_toggle.text = "🔋 Energiesparmodus (30 FPS): AN" if battery_saver_enabled else "🔋 Energiesparmodus (30 FPS): AUS"

	# Screen Shake
	if screen_shake_slider != null:
		screen_shake_slider.value = screen_shake_intensity
	if screen_shake_value_label != null:
		screen_shake_value_label.text = "%d%%" % int(round(screen_shake_intensity * 100.0))

	# Light Cycle
	_update_light_cycle_buttons()

	_is_updating_ui = false

# ------------------------------------------------------------------------------
# Control Event Handlers
# ------------------------------------------------------------------------------

func _on_master_slider_changed(val: float) -> void:
	if _is_updating_ui:
		return
	if val > 1.0:
		val /= 100.0
	master_volume = clampf(val, 0.0, 1.0)
	if master_value_label != null:
		master_value_label.text = "%d%%" % int(round(master_volume * 100.0))

	var gs = _get_game_state()
	if gs != null and gs.has_method("set_master_volume"):
		gs.set_master_volume(master_volume)

	var am = _get_audio_manager()
	if am != null and am.has_method("set_bus_volume"):
		am.set_bus_volume("Master", master_volume)
	else:
		_fallback_set_bus_volume("Master", master_volume)

	master_volume_changed.emit(master_volume)

func _on_master_mute_toggled(pressed: bool) -> void:
	if _is_updating_ui:
		return
	master_muted = pressed
	if master_mute_toggle != null:
		master_mute_toggle.text = "🔇 Master Ton: Stumm" if master_muted else "🔊 Master Ton: Aktiv"

	var gs = _get_game_state()
	if gs != null and gs.has_method("set_master_muted"):
		gs.set_master_muted(master_muted)

	var am = _get_audio_manager()
	if am != null and am.has_method("set_bus_mute"):
		am.set_bus_mute("Master", master_muted)
	else:
		_fallback_set_bus_mute("Master", master_muted)

	master_mute_changed.emit(master_muted)

func _on_sfx_slider_changed(val: float) -> void:
	if _is_updating_ui:
		return
	if val > 1.0:
		val /= 100.0
	sfx_volume = clampf(val, 0.0, 1.0)
	if sfx_value_label != null:
		sfx_value_label.text = "%d%%" % int(round(sfx_volume * 100.0))

	var gs = _get_game_state()
	if gs != null and gs.has_method("set_sfx_volume"):
		gs.set_sfx_volume(sfx_volume)

	var am = _get_audio_manager()
	if am != null and am.has_method("set_bus_volume"):
		am.set_bus_volume("SFX", sfx_volume)
	else:
		_fallback_set_bus_volume("SFX", sfx_volume)

	sfx_volume_changed.emit(sfx_volume)

func _on_sfx_mute_toggled(pressed: bool) -> void:
	if _is_updating_ui:
		return
	sfx_muted = pressed
	if sfx_mute_toggle != null:
		sfx_mute_toggle.text = "🔇 SFX Ton: Stumm" if sfx_muted else "🎮 SFX Ton: Aktiv"

	var gs = _get_game_state()
	if gs != null and gs.has_method("set_sfx_muted"):
		gs.set_sfx_muted(sfx_muted)

	var am = _get_audio_manager()
	if am != null and am.has_method("set_bus_mute"):
		am.set_bus_mute("SFX", sfx_muted)
	else:
		_fallback_set_bus_mute("SFX", sfx_muted)

	sfx_mute_changed.emit(sfx_muted)

func _on_music_slider_changed(val: float) -> void:
	if _is_updating_ui:
		return
	if val > 1.0:
		val /= 100.0
	music_volume = clampf(val, 0.0, 1.0)
	if music_value_label != null:
		music_value_label.text = "%d%%" % int(round(music_volume * 100.0))

	var gs = _get_game_state()
	if gs != null and gs.has_method("set_music_volume"):
		gs.set_music_volume(music_volume)

	var am = _get_audio_manager()
	if am != null and am.has_method("set_bus_volume"):
		am.set_bus_volume("Music", music_volume)
	else:
		_fallback_set_bus_volume("Music", music_volume)

	music_volume_changed.emit(music_volume)

func _on_music_mute_toggled(pressed: bool) -> void:
	if _is_updating_ui:
		return
	music_muted = pressed
	if music_mute_toggle != null:
		music_mute_toggle.text = "🔇 Musik Ton: Stumm" if music_muted else "🎵 Musik Ton: Aktiv"

	var gs = _get_game_state()
	if gs != null and gs.has_method("set_music_muted"):
		gs.set_music_muted(music_muted)

	var am = _get_audio_manager()
	if am != null and am.has_method("set_bus_mute"):
		am.set_bus_mute("Music", music_muted)
	else:
		_fallback_set_bus_mute("Music", music_muted)

	music_mute_changed.emit(music_muted)

func _on_haptics_toggled(pressed: bool) -> void:
	if _is_updating_ui:
		return
	haptics_enabled = pressed
	if haptics_toggle != null:
		haptics_toggle.text = "📳 Haptik Feedback: AN" if haptics_enabled else "📴 Haptik Feedback: AUS"

	var hm = _get_haptics_manager()
	if hm != null:
		if hm.has_method("set_haptics_enabled"):
			hm.set_haptics_enabled(haptics_enabled)
		if haptics_enabled and hm.has_method("vibrate_button"):
			hm.vibrate_button()

	haptics_toggled.emit(haptics_enabled)

func _on_battery_saver_toggled(pressed: bool) -> void:
	if _is_updating_ui:
		return
	battery_saver_enabled = pressed
	if battery_saver_enabled:
		Engine.max_fps = 30
		if battery_saver_toggle != null:
			battery_saver_toggle.text = "🔋 Energiesparmodus (30 FPS): AN"
	else:
		Engine.max_fps = 60
		if battery_saver_toggle != null:
			battery_saver_toggle.text = "🔋 Energiesparmodus (30 FPS): AUS"

	battery_saver_toggled.emit(battery_saver_enabled)

func _on_screen_shake_slider_changed(val: float) -> void:
	if _is_updating_ui:
		return
	if val > 1.0:
		val /= 100.0
	screen_shake_intensity = clampf(val, 0.0, 1.0)
	if screen_shake_value_label != null:
		screen_shake_value_label.text = "%d%%" % int(round(screen_shake_intensity * 100.0))

	var gs = _get_game_state()
	if gs != null and gs.has_method("set_screen_shake_intensity"):
		gs.set_screen_shake_intensity(screen_shake_intensity)
	elif gs != null and "screen_shake_intensity" in gs:
		gs.screen_shake_intensity = screen_shake_intensity

	screen_shake_changed.emit(screen_shake_intensity)

func _on_game_state_screen_shake_changed(new_intensity: float) -> void:
	if _is_updating_ui:
		return
	screen_shake_intensity = clampf(new_intensity, 0.0, 1.0)
	if screen_shake_slider != null:
		screen_shake_slider.value = screen_shake_intensity
	if screen_shake_value_label != null:
		screen_shake_value_label.text = "%d%%" % int(round(screen_shake_intensity * 100.0))

func _on_game_state_audio_changed(setting_name: String, _val: Variant) -> void:
	if _is_updating_ui:
		return
	_read_current_state()
	_update_ui()

# ------------------------------------------------------------------------------
# Direct Public Helper Accessors (for tests & programmatic manipulation)
# ------------------------------------------------------------------------------

func set_master_volume_val(val: float) -> void:
	if master_slider != null:
		master_slider.value = val
	else:
		_on_master_slider_changed(val)

func set_sfx_volume_val(val: float) -> void:
	if sfx_slider != null:
		sfx_slider.value = val
	else:
		_on_sfx_slider_changed(val)

func set_music_volume_val(val: float) -> void:
	if music_slider != null:
		music_slider.value = val
	else:
		_on_music_slider_changed(val)

func set_master_muted_val(muted: bool) -> void:
	if master_mute_toggle != null:
		master_mute_toggle.button_pressed = muted
	else:
		_on_master_mute_toggled(muted)

func set_sfx_muted_val(muted: bool) -> void:
	if sfx_mute_toggle != null:
		sfx_mute_toggle.button_pressed = muted
	else:
		_on_sfx_mute_toggled(muted)

func set_music_muted_val(muted: bool) -> void:
	if music_mute_toggle != null:
		music_mute_toggle.button_pressed = muted
	else:
		_on_music_mute_toggled(muted)

func set_haptics_val(enabled: bool) -> void:
	if haptics_toggle != null:
		haptics_toggle.button_pressed = enabled
	else:
		_on_haptics_toggled(enabled)

func set_battery_saver_val(enabled: bool) -> void:
	if battery_saver_toggle != null:
		battery_saver_toggle.button_pressed = enabled
	else:
		_on_battery_saver_toggled(enabled)

func set_screen_shake_val(val: float) -> void:
	if screen_shake_slider != null:
		screen_shake_slider.value = val
	else:
		_on_screen_shake_slider_changed(val)

func set_light_cycle_val(mode: String) -> void:
	_set_light_cycle_mode(mode)

func _on_light_cycle_auto_pressed() -> void:
	_set_light_cycle_mode("auto")

func _on_light_cycle_day_pressed() -> void:
	_set_light_cycle_mode("day")

func _on_light_cycle_night_pressed() -> void:
	_set_light_cycle_mode("night")

func _set_light_cycle_mode(mode: String) -> void:
	if _is_updating_ui:
		return
	var clean_mode = mode.to_lower()
	if clean_mode not in ["auto", "day", "night"]:
		clean_mode = "auto"
	light_cycle_mode = clean_mode

	var gs = _get_game_state()
	if gs != null and gs.has_method("set_light_cycle_mode"):
		gs.set_light_cycle_mode(light_cycle_mode)

	var am = _get_audio_manager()
	if am != null and am.has_method("play_sfx_click"):
		am.play_sfx_click()

	_update_light_cycle_buttons()
	light_cycle_mode_changed.emit(light_cycle_mode)

func _on_game_state_light_cycle_changed(new_mode: String) -> void:
	light_cycle_mode = new_mode
	_update_light_cycle_buttons()

func _update_light_cycle_buttons() -> void:
	if light_cycle_value_label != null:
		match light_cycle_mode:
			"day":
				light_cycle_value_label.text = "Immer Tag"
			"night":
				light_cycle_value_label.text = "Cyberpunk Nacht"
			"auto", _:
				light_cycle_value_label.text = "Auto (180s)"

	_apply_mode_button_style(light_cycle_auto_btn, light_cycle_mode == "auto", "🔄 Auto")
	_apply_mode_button_style(light_cycle_day_btn, light_cycle_mode == "day", "☀️ Tag")
	_apply_mode_button_style(light_cycle_night_btn, light_cycle_mode == "night", "🌙 Nacht")

func _apply_mode_button_style(btn: Button, is_active: bool, label_text: String) -> void:
	if btn == null:
		return
	if is_active:
		btn.text = "▶ " + label_text
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.0, 0.40, 0.55, 0.95)
		style.border_color = Color(0.0, 0.95, 1.0, 1.0)
		style.border_width_left = 2
		style.border_width_top = 2
		style.border_width_right = 2
		style.border_width_bottom = 2
		style.corner_radius_top_left = 6
		style.corner_radius_top_right = 6
		style.corner_radius_bottom_right = 6
		style.corner_radius_bottom_left = 6
		btn.add_theme_stylebox_override("normal", style)
		btn.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	else:
		btn.text = label_text
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.06, 0.10, 0.16, 0.85)
		style.border_color = Color(0.15, 0.25, 0.38, 0.5)
		style.border_width_left = 1
		style.border_width_top = 1
		style.border_width_right = 1
		style.border_width_bottom = 1
		style.corner_radius_top_left = 6
		style.corner_radius_top_right = 6
		style.corner_radius_bottom_right = 6
		style.corner_radius_bottom_left = 6
		btn.add_theme_stylebox_override("normal", style)
		btn.add_theme_color_override("font_color", Color(0.65, 0.78, 0.90, 0.8))

# ------------------------------------------------------------------------------
# Defensive Duck Typing Utilities
# ------------------------------------------------------------------------------

func _get_audio_manager() -> Node:
	if has_node("/root/AudioManager"):
		return get_node_or_null("/root/AudioManager")
	return null

func _get_haptics_manager() -> Node:
	if has_node("/root/HapticsManager"):
		return get_node_or_null("/root/HapticsManager")
	return null

func _get_game_state() -> Node:
	if has_node("/root/GameState"):
		return get_node_or_null("/root/GameState")
	return null

func _fallback_set_bus_volume(bus_name: String, volume_linear: float) -> void:
	var idx: int = AudioServer.get_bus_index(bus_name)
	if idx != -1:
		var db: float = -80.0 if volume_linear <= 0.0001 else clampf(linear_to_db(volume_linear), -80.0, 6.0)
		AudioServer.set_bus_volume_db(idx, db)

func _fallback_set_bus_mute(bus_name: String, muted: bool) -> void:
	var idx: int = AudioServer.get_bus_index(bus_name)
	if idx != -1:
		AudioServer.set_bus_mute(idx, muted)
