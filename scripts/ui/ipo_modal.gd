extends Control

## IPO Overview Modal for IdleArcade (Phase 12 Milestone 3).
## Displays enterprise valuation, pending Angel Shares, owned portfolio,
## and future permanent multiplier.
## Implements a two-stage safety confirmation mechanism to prevent accidental resets.
## Adheres strictly to mobile touch ergonomics: touch targets >= 56px and mouse_filter = STOP.

signal closed()
signal ipo_confirmed(angel_shares_earned: int, new_multiplier: float)

@onready var backdrop: ColorRect = $Backdrop
@onready var close_button: Button = %CloseButton
@onready var valuation_label: Label = %ValuationLabel
@onready var pending_shares_label: Label = %PendingSharesLabel
@onready var owned_shares_label: Label = %OwnedSharesLabel
@onready var future_bonus_label: Label = %FutureBonusLabel
@onready var threshold_box: PanelContainer = %ThresholdBox
@onready var threshold_label: Label = %ThresholdLabel
@onready var trigger_ipo_button: Button = %TriggerIPOButton
@onready var confirm_box: PanelContainer = %ConfirmBox
@onready var confirm_warning_label: Label = get_node_or_null("%ConfirmWarningLabel")
@onready var confirm_yes_button: Button = %ConfirmYesButton
@onready var confirm_cancel_button: Button = %ConfirmCancelButton
@onready var slide_to_confirm: HSlider = get_node_or_null("%SlideToConfirm")

var _is_confirming: bool = false

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

	if trigger_ipo_button != null:
		trigger_ipo_button.mouse_filter = Control.MOUSE_FILTER_STOP
		if not trigger_ipo_button.pressed.is_connected(_on_trigger_ipo_pressed):
			trigger_ipo_button.pressed.connect(_on_trigger_ipo_pressed)

	if confirm_yes_button != null:
		confirm_yes_button.mouse_filter = Control.MOUSE_FILTER_STOP
		if not confirm_yes_button.pressed.is_connected(_on_confirm_yes_pressed):
			confirm_yes_button.pressed.connect(_on_confirm_yes_pressed)

	if confirm_cancel_button != null:
		confirm_cancel_button.mouse_filter = Control.MOUSE_FILTER_STOP
		if not confirm_cancel_button.pressed.is_connected(_on_confirm_cancel_pressed):
			confirm_cancel_button.pressed.connect(_on_confirm_cancel_pressed)

	if slide_to_confirm != null:
		slide_to_confirm.mouse_filter = Control.MOUSE_FILTER_STOP
		if not slide_to_confirm.value_changed.is_connected(_on_slide_value_changed):
			slide_to_confirm.value_changed.connect(_on_slide_value_changed)
		if not slide_to_confirm.drag_ended.is_connected(_on_slide_drag_ended):
			slide_to_confirm.drag_ended.connect(_on_slide_drag_ended)

	_connect_game_state_signals()
	open()

func _connect_game_state_signals() -> void:
	var gs = _get_game_state()
	if gs == null:
		return
	if gs.has_signal("energy_changed") and not gs.energy_changed.is_connected(_on_game_state_updated):
		gs.energy_changed.connect(_on_game_state_updated)
	if gs.has_signal("angel_shares_changed") and not gs.angel_shares_changed.is_connected(_on_game_state_updated):
		gs.angel_shares_changed.connect(_on_game_state_updated)
	if gs.has_signal("ipo_completed") and not gs.ipo_completed.is_connected(_on_game_state_updated):
		gs.ipo_completed.connect(_on_game_state_updated)

func _disconnect_game_state_signals() -> void:
	var gs = _get_game_state()
	if gs == null:
		return
	if gs.has_signal("energy_changed") and gs.energy_changed.is_connected(_on_game_state_updated):
		gs.energy_changed.disconnect(_on_game_state_updated)
	if gs.has_signal("angel_shares_changed") and gs.angel_shares_changed.is_connected(_on_game_state_updated):
		gs.angel_shares_changed.disconnect(_on_game_state_updated)
	if gs.has_signal("ipo_completed") and gs.ipo_completed.is_connected(_on_game_state_updated):
		gs.ipo_completed.disconnect(_on_game_state_updated)

func _on_game_state_updated(_a = null, _b = null, _c = null) -> void:
	_update_display()

## Lifecycle open method. Resets confirmation and refreshes state.
func open(_args: Dictionary = {}) -> void:
	visible = true
	_reset_confirmation_state()
	_update_display()

## Lifecycle close method. Emits closed signal, plays click SFX, and frees node.
func close() -> void:
	_disconnect_game_state_signals()
	_play_click_sfx()
	closed.emit()
	visible = false
	queue_free()

func _reset_confirmation_state() -> void:
	_is_confirming = false
	if confirm_box != null:
		confirm_box.visible = false
	if trigger_ipo_button != null:
		trigger_ipo_button.visible = true
	if slide_to_confirm != null:
		slide_to_confirm.value = 0.0

func _on_trigger_ipo_pressed() -> void:
	_play_click_sfx()
	var gs = _get_game_state()
	if gs != null and gs.has_method("can_trigger_ipo") and not gs.can_trigger_ipo():
		return

	_is_confirming = true
	if trigger_ipo_button != null:
		trigger_ipo_button.visible = false
	if confirm_box != null:
		confirm_box.visible = true
	if slide_to_confirm != null:
		slide_to_confirm.value = 0.0
	_trigger_haptic_tap()

func _on_confirm_cancel_pressed() -> void:
	_play_click_sfx()
	_reset_confirmation_state()

func _on_confirm_yes_pressed() -> void:
	_execute_ipo()

func _on_slide_value_changed(val: float) -> void:
	if val >= 99.0 and _is_confirming:
		_execute_ipo()

func _on_slide_drag_ended(_value_changed: bool) -> void:
	if slide_to_confirm != null and slide_to_confirm.value < 99.0:
		slide_to_confirm.value = 0.0

func _execute_ipo() -> void:
	var gs = _get_game_state()
	if gs == null:
		return

	if gs.has_method("can_trigger_ipo") and not gs.can_trigger_ipo():
		_reset_confirmation_state()
		_update_display()
		return

	var res: Dictionary = {}
	if gs.has_method("trigger_ipo"):
		res = gs.trigger_ipo()

	if not res.get("success", false):
		_reset_confirmation_state()
		_update_display()
		return

	var shares_gained: int = int(res.get("shares_gained", res.get("angel_shares_gained", 0)))
	var new_mult: float = float(res.get("multiplier", 1.0))

	# 1. Play procedural audio chime
	var am = _get_audio_manager()
	if am != null:
		if am.has_method("play_sfx_bell"):
			am.play_sfx_bell()
		if am.has_method("play_sfx_confetti"):
			am.play_sfx_confetti()

	# 2. Golden confetti celebration
	var confetti_cls = load("res://scripts/vfx/confetti_burst.gd")
	if confetti_cls != null and confetti_cls.has_method("spawn_burst_2d"):
		var burst_pos = size * 0.5 if size != Vector2.ZERO else Vector2(360.0, 640.0)
		confetti_cls.spawn_burst_2d(self, burst_pos, 60)

	# 3. Haptics
	var hm = get_node_or_null("/root/HapticsManager")
	if hm != null and hm.has_method("vibrate_level_up"):
		hm.vibrate_level_up()

	ipo_confirmed.emit(shares_gained, new_mult)
	close()

func _update_display() -> void:
	var gs = _get_game_state()
	if gs == null:
		return

	var lifetime_energy: float = float(gs.get("total_lifetime_energy")) if gs.get("total_lifetime_energy") != null else float(gs.get("total_energy_earned"))
	var pending_shares: int = gs.calculate_pending_angel_shares() if gs.has_method("calculate_pending_angel_shares") else 0
	var owned_shares: int = int(gs.get("angel_shares")) if gs.get("angel_shares") != null else 0
	var current_mult: float = gs.get_angel_share_multiplier() if gs.has_method("get_angel_share_multiplier") else (1.0 + float(owned_shares) * 0.02)
	var future_shares: int = owned_shares + pending_shares
	var future_mult: float = 1.0 + float(future_shares) * 0.02
	var can_ipo: bool = gs.can_trigger_ipo() if gs.has_method("can_trigger_ipo") else false

	if valuation_label != null:
		var formatted: String = gs.format_number(lifetime_energy) if gs.has_method("format_number") else str(int(lifetime_energy))
		valuation_label.text = "⚡ " + formatted

	if pending_shares_label != null:
		pending_shares_label.text = "👼 +%d Aktien" % pending_shares

	if owned_shares_label != null:
		var pct = int(round((current_mult - 1.0) * 100.0))
		owned_shares_label.text = "%d Aktien (+%d%%)" % [owned_shares, pct]

	if future_bonus_label != null:
		var future_pct = int(round((future_mult - 1.0) * 100.0))
		future_bonus_label.text = "+%d%% Gesamterlös" % future_pct

	if trigger_ipo_button != null:
		trigger_ipo_button.disabled = not can_ipo
		if can_ipo:
			trigger_ipo_button.text = "🔔 BÖRSENGANG STARTEN (+%d Aktien)" % pending_shares
		else:
			trigger_ipo_button.text = "🔔 BÖRSENGANG GESPERRT"

	if threshold_box != null and threshold_label != null:
		if can_ipo:
			threshold_box.visible = false
		else:
			threshold_box.visible = true
			if lifetime_energy < 1000000.0:
				var prog_str = gs.format_number(lifetime_energy) if gs.has_method("format_number") else str(int(lifetime_energy))
				threshold_label.text = "IPO erfordert 1.000.000 Lifetime Energy (Fortschritt: %s / 1.00M) oder Unicorn-Status (Kapitel 3)." % prog_str
			else:
				threshold_label.text = "Aktuell keine neuen Angel Shares verfügbar. Steigere deine Lifetime Energy für weitere Aktien."

func _on_backdrop_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		close()

func _gui_input(event: InputEvent) -> void:
	accept_event()

func _play_click_sfx() -> void:
	var am = _get_audio_manager()
	if am != null and am.has_method("play_sfx_click"):
		am.play_sfx_click()

func _trigger_haptic_tap() -> void:
	var hm = get_node_or_null("/root/HapticsManager")
	if hm != null and hm.has_method("vibrate_button"):
		hm.vibrate_button()
	elif OS.has_feature("mobile") and Input.has_method("vibrate_handheld"):
		Input.vibrate_handheld(20)

func _get_game_state() -> Node:
	var tree = get_tree()
	if tree != null and tree.root != null:
		return tree.root.get_node_or_null("GameState")
	return null

func _get_audio_manager() -> Node:
	var tree = get_tree()
	if tree != null and tree.root != null:
		return tree.root.get_node_or_null("AudioManager")
	return null
