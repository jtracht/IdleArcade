extends CanvasLayer
class_name ScreenTransition

## ScreenTransition Overlay for IdleArcade (Phase 10).
## Provides full-screen smooth two-phase wipe/fade transitions between the 3D campus
## and 2D laptop overlay with strict input isolation (mouse_filter = STOP only during wipe).

signal transition_started(target_name: String)
signal transition_midpoint(target_name: String)
signal transition_completed(target_name: String)

@export var transition_duration: float = 0.3
@export var transition_color: Color = Color(0.04, 0.06, 0.09, 1.0)

@onready var transition_rect: ColorRect = get_node_or_null("TransitionRect")

var _is_transitioning: bool = false
var _active_tween: Tween = null

func _ready() -> void:
	layer = 15
	if transition_rect == null:
		transition_rect = get_node_or_null("TransitionRect")
	if transition_rect != null:
		transition_rect.visible = false
		transition_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		transition_rect.modulate.a = 0.0
		transition_rect.color = transition_color

func _exit_tree() -> void:
	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()
		_active_tween = null
	_is_transitioning = false

## Returns whether a transition animation is actively in progress
func is_transitioning() -> bool:
	return _is_transitioning

## Initiates a wipe transition into the 2D laptop HUD
func transition_to_laptop(callback: Callable = Callable()) -> void:
	fade_out_in(callback, Callable(), transition_duration, "laptop")

## Initiates a wipe transition returning to the 3D campus
func transition_to_campus(callback: Callable = Callable()) -> void:
	fade_out_in(callback, Callable(), transition_duration, "campus")

## Initiates a generic two-phase wipe with midpoint callback
func transition_wipe(midpoint_callback: Callable = Callable(), duration: float = 0.3) -> void:
	fade_out_in(midpoint_callback, Callable(), duration, "")

## Core two-phase fade out -> midpoint invocation -> fade in tween lifecycle
func fade_out_in(on_midpoint: Callable = Callable(), on_completed: Callable = Callable(), duration: float = 0.3, target_name: String = "") -> void:
	if _is_transitioning:
		return
	
	if transition_rect == null:
		transition_rect = get_node_or_null("TransitionRect")
	
	if transition_rect == null:
		if on_midpoint.is_valid():
			on_midpoint.call()
		if on_completed.is_valid():
			on_completed.call()
		return
	
	_is_transitioning = true
	transition_rect.visible = true
	transition_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	transition_rect.modulate.a = 0.0
	transition_rect.color = transition_color
	
	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()
	
	transition_started.emit(target_name)
	
	var half_dur: float = maxf(0.01, duration * 0.5)
	var tw: Tween = create_tween()
	_active_tween = tw
	
	# Phase 1: Fade In blackout
	tw.tween_property(transition_rect, "modulate:a", 1.0, half_dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	# Midpoint: Invoke payload while 100% blacked out
	tw.tween_callback(func():
		if on_midpoint.is_valid():
			on_midpoint.call()
		transition_midpoint.emit(target_name)
	)
	
	# Phase 2: Fade Out reveal
	tw.tween_property(transition_rect, "modulate:a", 0.0, half_dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	
	# Completion: Reset mouse_filter to IGNORE and hide overlay
	tw.tween_callback(func():
		transition_rect.visible = false
		transition_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_is_transitioning = false
		_active_tween = null
		if on_completed.is_valid():
			on_completed.call()
		transition_completed.emit(target_name)
	)
