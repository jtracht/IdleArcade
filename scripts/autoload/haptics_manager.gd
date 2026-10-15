extends Node

## HapticsManager Autoload Singleton (res://scripts/autoload/haptics_manager.gd)
## Centralized tactile feedback manager for IdleArcade mobile touch controls and game events.
## Provides safe platform guards, desktop emulation, telemetry mock history,
## rapid pickup throttling, and automated signal integration with GameState and NakamaManager.

# ------------------------------------------------------------------------------
# Signals
# ------------------------------------------------------------------------------

## Emitted whenever a vibration pulse is executed or recorded (for telemetry and test verification).
signal vibration_triggered(duration_ms: int, amplitude: float)

## Emitted with full parameter telemetry (duration and amplitude).
signal vibration_custom_triggered(duration_ms: int, amplitude: float)

## Emitted when haptics are enabled or disabled.
signal haptics_toggled(is_enabled: bool)

## Emitted when an item pickup vibration is dropped by the cooldown throttle gate.
signal pickup_throttled(item_type: String)

## Emitted when a multi-pulse haptic pattern begins.
signal pattern_started(pattern_name: String)

## Emitted when a multi-pulse haptic pattern finishes.
signal pattern_completed(pattern_name: String)

# ------------------------------------------------------------------------------
# Constants
# ------------------------------------------------------------------------------

const DURATION_LIGHT_MS: int = 25
const DURATION_MEDIUM_MS: int = 70
const DURATION_HEAVY_MS: int = 120
const DURATION_BUTTON_MS: int = 20

const AMP_LIGHT: float = 0.4
const AMP_MEDIUM: float = 0.7
const AMP_HEAVY: float = 1.0
const AMP_BUTTON: float = 0.3
const AMP_DEFAULT: float = -1.0

const PICKUP_COOLDOWN_MS: int = 50

# ------------------------------------------------------------------------------
# Configuration & Properties
# ------------------------------------------------------------------------------

@export_group("Haptics Configuration")
## Master switch for haptic feedback. When false, all vibrations are suppressed.
@export var haptics_enabled: bool = true

## Alias for haptics_enabled for specification compatibility.
var enabled: bool:
	get:
		return haptics_enabled
	set(value):
		set_haptics_enabled(value)

## When true, allows desktop environments to emulate mobile haptics for testing.
@export var force_emulate: bool = false

## When true, records vibration events in vibration_history array.
@export var mock_mode: bool = true

## Alias for mock_mode for backward compatibility.
@export var mock_recording_enabled: bool = true

## Alias for mock_mode for contract checks.
var test_mode: bool:
	get:
		return mock_mode
	set(value):
		mock_mode = value

## Maximum records retained in vibration_history ring buffer.
@export var max_history_size: int = 100

## Cooldown in milliseconds between rapid pickup vibrations.
@export var min_interval_ms: int = PICKUP_COOLDOWN_MS

## Aliases for min_interval_ms for various test and blueprint interfaces.
var cooldown_ms: int:
	get:
		return min_interval_ms
	set(value):
		min_interval_ms = value

var cooldown_interval_ms: int:
	get:
		return min_interval_ms
	set(value):
		min_interval_ms = value

var pickup_throttle_ms: int:
	get:
		return min_interval_ms
	set(value):
		min_interval_ms = value

var pickup_cooldown_ms: int:
	get:
		return min_interval_ms
	set(value):
		min_interval_ms = value

# ------------------------------------------------------------------------------
# State & Telemetry
# ------------------------------------------------------------------------------

## Duration of the most recent vibration in milliseconds.
var last_vibration_ms: int = 0

## Amplitude of the most recent vibration (-1.0 to 1.0).
var last_amplitude: float = -1.0

## Alias for last_amplitude for blueprint compatibility.
var last_vibration_amplitude: float:
	get:
		return last_amplitude
	set(value):
		last_amplitude = value

## Total number of vibration triggers processed.
var vibration_count: int = 0

## Total number of pickup vibrations throttled.
var pickup_throttled_count: int = 0

## Queryable history of vibration events for automated testing and telemetry.
var vibration_history: Array[Dictionary] = []

## Internal monotonic timestamp of last vibration to prevent motor churn.
var _last_vibration_timestamp: int = -100000

## Aliases for timer resetting by test harnesses.
var _last_vibrate_time_msec: int:
	get:
		return _last_vibration_timestamp
	set(value):
		if value <= 0:
			_last_vibration_timestamp = -100000
		else:
			_last_vibration_timestamp = value

var _last_vibration_time: float:
	get:
		return float(_last_vibration_timestamp)
	set(value):
		if value <= 0.0:
			_last_vibration_timestamp = -100000
		else:
			_last_vibration_timestamp = int(value)

var _last_pickup_timestamp_ms: int:
	get:
		return _last_vibration_timestamp
	set(value):
		if value <= 0:
			_last_vibration_timestamp = -100000
		else:
			_last_vibration_timestamp = value

# ------------------------------------------------------------------------------
# Lifecycle
# ------------------------------------------------------------------------------

func _ready() -> void:
	if not is_in_group("haptics_manager"):
		add_to_group("haptics_manager")
	# Ensure tree nodes and sibling singletons are available before connecting signals
	call_deferred("_bind_game_signals")

func _exit_tree() -> void:
	_unbind_game_signals()

# ------------------------------------------------------------------------------
# Platform Detection & Hardware Capability Guards
# ------------------------------------------------------------------------------

## Returns true if running on native or emulated mobile platform.
## Desktop laptops with touchscreens are strictly excluded to avoid misclassification.
func is_mobile_platform() -> bool:
	if force_emulate:
		return true
	return OS.has_feature("mobile") \
		or OS.has_feature("android") \
		or OS.has_feature("ios")

## Returns true if touchscreen is available or running on mobile.
func is_touch_device() -> bool:
	return is_mobile_platform() or DisplayServer.is_touchscreen_available()

## Checks whether native hardware vibration should actually be called.
func can_vibrate_hardware() -> bool:
	if not haptics_enabled:
		return false
	if not is_mobile_platform():
		return false
	return Input.has_method("vibrate_handheld")

# ------------------------------------------------------------------------------
# Public API: Tiered Vibrations
# ------------------------------------------------------------------------------

## Triggers a light tactile impulse (default 25ms, amplitude 0.4).
func vibrate_light(duration_ms: int = DURATION_LIGHT_MS, bypass_cooldown: bool = false) -> void:
	vibrate_custom(duration_ms, AMP_LIGHT, bypass_cooldown)

## Triggers a medium tactile impulse (default 70ms, amplitude 0.7).
func vibrate_medium(duration_ms: int = DURATION_MEDIUM_MS, bypass_cooldown: bool = false) -> void:
	vibrate_custom(duration_ms, AMP_MEDIUM, bypass_cooldown)

## Triggers a heavy tactile impulse (default 120ms, amplitude 1.0).
func vibrate_heavy(duration_ms: int = DURATION_HEAVY_MS, bypass_cooldown: bool = false) -> void:
	vibrate_custom(duration_ms, AMP_HEAVY, bypass_cooldown)

## Subtle tactile feedback for touch UI button presses (default 20ms, amplitude 0.3).
## Bypasses cooldown by default so rapid UI button taps are never dropped.
func vibrate_button(duration_ms: int = DURATION_BUTTON_MS, bypass_cooldown: bool = true) -> void:
	vibrate_custom(duration_ms, AMP_BUTTON, bypass_cooldown)

## Fundamental vibration dispatcher with duration clamping, guards, throttling, and mock telemetry.
func vibrate_custom(duration_ms: int, amplitude: float = AMP_DEFAULT, bypass_cooldown: bool = false) -> void:
	if not haptics_enabled:
		return

	# Negative or zero duration is treated as a safe no-op
	if duration_ms <= 0:
		return

	var now: int = Time.get_ticks_msec()
	if min_interval_ms > 0 and not bypass_cooldown and (now - _last_vibration_timestamp) < min_interval_ms:
		pickup_throttled_count += 1
		pickup_throttled.emit("throttled")
		return

	_last_vibration_timestamp = now

	var clamped_duration: int = mini(duration_ms, 5000)
	var clamped_amplitude: float = -1.0 if amplitude < 0.0 else clampf(amplitude, 0.0, 1.0)

	# Update telemetry and mock tracking
	last_vibration_ms = clamped_duration
	last_amplitude = clamped_amplitude
	vibration_count += 1

	if mock_mode or mock_recording_enabled:
		vibration_history.append({
			"duration_ms": clamped_duration,
			"amplitude": clamped_amplitude,
			"timestamp": now
		})
		if vibration_history.size() > max_history_size:
			vibration_history.pop_front()

	# Emit telemetry signals
	vibration_triggered.emit(clamped_duration, clamped_amplitude)
	vibration_custom_triggered.emit(clamped_duration, clamped_amplitude)

	# Execute hardware vibration only on supported platforms
	if can_vibrate_hardware():
		if clamped_amplitude >= 0.0:
			Input.vibrate_handheld(clamped_duration, clamped_amplitude)
		else:
			Input.vibrate_handheld(clamped_duration)

## Alias for vibrate_custom for interface contract compatibility.
func vibrate(duration_ms: int, amplitude: float = AMP_DEFAULT, bypass_cooldown: bool = false) -> void:
	vibrate_custom(duration_ms, amplitude, bypass_cooldown)

## Executes an asynchronous double-pulse success haptic pattern.
func vibrate_success_pattern(first_ms: int = 40, pause_ms: int = 60, second_ms: int = 80) -> void:
	if not haptics_enabled:
		return

	pattern_started.emit("success")
	vibrate_custom(first_ms, AMP_MEDIUM, true)

	var tree = get_tree()
	if tree != null:
		await tree.create_timer(float(pause_ms) / 1000.0).timeout

	if not haptics_enabled:
		return

	vibrate_custom(second_ms, AMP_HEAVY, true)
	pattern_completed.emit("success")

# ------------------------------------------------------------------------------
# Public API: Semantic Gameplay Helpers
# ------------------------------------------------------------------------------

## Tactile feedback for 3D collectible pickup with rapid churn throttle.
func vibrate_pickup() -> void:
	vibrate_light(DURATION_LIGHT_MS, false)

## Tactile feedback for unlocking campus zone gates (bypasses pickup cooldown).
func vibrate_gate() -> void:
	vibrate_medium(DURATION_MEDIUM_MS, true)

## Tactile feedback for completing 3D campus quests or daily quests (bypasses cooldown).
func vibrate_quest() -> void:
	vibrate_heavy(DURATION_HEAVY_MS, true)

# ------------------------------------------------------------------------------
# Configuration & Control
# ------------------------------------------------------------------------------

## Sets haptics enabled state and emits notification.
func set_haptics_enabled(is_enabled: bool) -> void:
	if haptics_enabled != is_enabled:
		haptics_enabled = is_enabled
		haptics_toggled.emit(is_enabled)

## Returns whether haptics are currently enabled.
func is_haptics_enabled() -> bool:
	return haptics_enabled

## Toggles haptic feedback on/off.
func toggle_haptics() -> bool:
	set_haptics_enabled(not haptics_enabled)
	return haptics_enabled

# ------------------------------------------------------------------------------
# Telemetry & Mock Query API
# ------------------------------------------------------------------------------

func get_last_vibration_ms() -> int:
	return last_vibration_ms

func get_last_amplitude() -> float:
	return last_amplitude

func get_history_durations() -> Array[int]:
	var durations: Array[int] = []
	for entry in vibration_history:
		durations.append(int(entry.get("duration_ms", 0)))
	return durations

func get_vibration_history() -> Array[Dictionary]:
	return vibration_history.duplicate()

func get_vibration_count() -> int:
	return vibration_count

func clear_history() -> void:
	vibration_history.clear()
	last_vibration_ms = 0
	last_amplitude = -1.0
	vibration_count = 0
	pickup_throttled_count = 0
	_last_vibration_timestamp = -100000

func reset_pickup_cooldown() -> void:
	_last_vibration_timestamp = -100000

## Public hook allowing test runners to rebind signals after injecting test mocks.
func reconnect_signals() -> void:
	_bind_game_signals()

# ------------------------------------------------------------------------------
# Signal Integration (GameState & NakamaManager)
# ------------------------------------------------------------------------------

func _find_singleton(name: String) -> Node:
	var node = get_node_or_null("/root/" + name)
	if node != null:
		return node
	var tree = get_tree()
	if tree != null and tree.root != null:
		return tree.root.find_child(name, true, false)
	return null

func _safe_connect(emitter: Object, sig_name: String, target_callable: Callable) -> void:
	if is_instance_valid(emitter) and emitter.has_signal(sig_name):
		var sig: Signal = Signal(emitter, sig_name)
		if not sig.is_connected(target_callable):
			sig.connect(target_callable)

func _safe_disconnect(emitter: Object, sig_name: String, target_callable: Callable) -> void:
	if is_instance_valid(emitter) and emitter.has_signal(sig_name):
		var sig: Signal = Signal(emitter, sig_name)
		if sig.is_connected(target_callable):
			sig.disconnect(target_callable)

func _bind_game_signals() -> void:
	# Bind GameState signals (collectible_picked_up, zone_unlocked, campus_quest_completed)
	var gs = _find_singleton("GameState")
	if gs != null:
		_safe_connect(gs, "collectible_picked_up", _on_collectible_picked_up)
		_safe_connect(gs, "zone_unlocked", _on_zone_unlocked)
		_safe_connect(gs, "campus_quest_completed", _on_campus_quest_completed)

	# Bind NakamaManager signals (quest_reward_claimed)
	var nm = _find_singleton("NakamaManager")
	if nm != null:
		_safe_connect(nm, "quest_reward_claimed", _on_quest_reward_claimed)

func _unbind_game_signals() -> void:
	var gs = _find_singleton("GameState")
	if gs != null:
		_safe_disconnect(gs, "collectible_picked_up", _on_collectible_picked_up)
		_safe_disconnect(gs, "zone_unlocked", _on_zone_unlocked)
		_safe_disconnect(gs, "campus_quest_completed", _on_campus_quest_completed)

	var nm = _find_singleton("NakamaManager")
	if nm != null:
		_safe_disconnect(nm, "quest_reward_claimed", _on_quest_reward_claimed)

func _on_collectible_picked_up(_item_type: String = "", _total_collected: int = 0) -> void:
	vibrate_pickup()

func _on_zone_unlocked(_zone_id: String = "") -> void:
	vibrate_gate()

func _on_campus_quest_completed(_quest_id: String = "", _reward_energy: float = 0.0, _reward_bonus_users: int = 0) -> void:
	vibrate_quest()

func _on_quest_reward_claimed(_quest_id: String = "", _bonus_users: int = 0) -> void:
	vibrate_quest()

func _on_nakama_quest_reward_claimed(_quest_id: String = "", _bonus_users: int = 0) -> void:
	_on_quest_reward_claimed(_quest_id, _bonus_users)
