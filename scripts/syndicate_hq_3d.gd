extends StaticBody3D
class_name SyndicateHQ3D

## 3D Interactive Syndicate Headquarters for IdleArcade Phase 13 (Milestone M2).
## Executive lounge situated in the East Wing at (12, 0, 0).
## Features a modern tech conference table, glowing rotating wireframe holographic globe,
## projection ranking display screen, heraldic clan banners, proximity detection,
## dynamic TouchControls integration ("Syndicate [E]"), and modal UI dispatch.

signal syndicate_interacted()
signal syndicate_opened()
signal hologram_pulsed()

@export var prompt_text: String = "🏛️ [E] Syndicate HQ"
@export var action_label: String = "Syndicate [E]"
@export var globe_spin_speed: float = 1.2
@export var globe_bob_speed: float = 2.5
@export var globe_bob_amplitude: float = 0.05

var _player_in_range: bool = false
var _time: float = 0.0
var _base_globe_y: float = 1.45
var _avatar_ref: Node3D = null
var _glow_tween: Tween = null

@onready var interaction_area: Area3D = get_node_or_null("InteractionArea")
@onready var prompt_label: Label3D = get_node_or_null("PromptLabel3D")
@onready var holographic_globe: Node3D = get_node_or_null("Visuals/ConferenceTable/HolographicGlobe")
@onready var screen_data_label: Label3D = get_node_or_null("Visuals/ProjectionScreen/ScreenDataLabel")
@onready var hq_light: OmniLight3D = get_node_or_null("Visuals/HQLight")
@onready var globe_glow: OmniLight3D = get_node_or_null("Visuals/ConferenceTable/HolographicGlobe/GlobeGlow")

func _ready() -> void:
	add_to_group("syndicate_hqs")
	add_to_group("interactables")
	add_to_group("stations")

	if holographic_globe != null:
		_base_globe_y = holographic_globe.position.y

	if prompt_label != null:
		prompt_label.text = prompt_text
		prompt_label.visible = false

	if interaction_area != null:
		interaction_area.body_entered.connect(_on_interaction_body_entered)
		interaction_area.body_exited.connect(_on_interaction_body_exited)

	refresh_syndicate_display()

func _process(delta: float) -> void:
	_time += delta
	if holographic_globe != null:
		holographic_globe.rotate_y(globe_spin_speed * delta)
		holographic_globe.position.y = _base_globe_y + sin(_time * globe_bob_speed) * globe_bob_amplitude

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
		if tc != null and tc.has_method("register_interactable"):
			tc.register_interactable(self, action_label)

func _on_interaction_body_exited(body: Node3D) -> void:
	if body == _avatar_ref or body.is_in_group("player") or body is CharacterBody3D:
		_player_in_range = false
		_avatar_ref = null
		if prompt_label != null:
			prompt_label.visible = false
		var tc = _find_touch_controls()
		if tc != null and tc.has_method("unregister_interactable"):
			tc.unregister_interactable(self)

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
	syndicate_interacted.emit()
	syndicate_opened.emit()

	var am = get_node_or_null("/root/AudioManager")
	if am != null and am.has_method("play_sfx_click"):
		am.play_sfx_click()

	pulse_hologram()
	refresh_syndicate_display()
	_open_syndicate_modal()

func open_syndicate() -> void:
	interact()

func open_syndicate_modal() -> void:
	interact()

func pulse_hologram() -> void:
	hologram_pulsed.emit()
	if globe_glow != null:
		if _glow_tween != null and _glow_tween.is_valid():
			_glow_tween.kill()
		_glow_tween = create_tween()
		_glow_tween.tween_property(globe_glow, "light_energy", 3.2, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_glow_tween.tween_property(globe_glow, "light_energy", 1.6, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)

func refresh_syndicate_display() -> void:
	var gs = get_node_or_null("/root/GameState")
	var syn_name: String = "Independent"
	var syn_tag: String = "SOLO"
	var dividend_pct: int = 0
	if gs != null and gs.has_method("get_active_syndicate"):
		var is_active: bool = (gs.has_method("is_in_syndicate") and gs.is_in_syndicate())
		var syn_data = gs.get_active_syndicate()
		if syn_data is Dictionary and syn_data.get("is_active", false) == true:
			is_active = true
		if is_active and syn_data is Dictionary and not syn_data.is_empty():
			var raw_name = str(syn_data.get("name", "")).strip_edges()
			if not raw_name.is_empty():
				syn_name = raw_name
			var raw_tag = str(syn_data.get("tag", "")).strip_edges()
			if not raw_tag.is_empty():
				syn_tag = raw_tag
			var bonuses = syn_data.get("bonuses", {})
			if bonuses is Dictionary and bonuses.has("dividend_pct"):
				dividend_pct = int(round(float(bonuses.get("dividend_pct", 0.0)) * 100.0))
			elif gs.has_method("get_syndicate_dividend_multiplier"):
				dividend_pct = int(round((gs.get_syndicate_dividend_multiplier() - 1.0) * 100.0))

	if screen_data_label != null:
		screen_data_label.text = "1. [CYBER] Cyberdyne Apex   - 12.8M pts\n" \
			+ "2. [QUANT] Quantum Vanguard -  9.4M pts\n" \
			+ "3. [NEXUS] Nexus Syndicate  -  7.1M pts\n" \
			+ "------------------------------------\n" \
			+ "YOUR HOLDING: [%s] %s (+%d%% Div)" % [syn_tag, syn_name, dividend_pct]

func _open_syndicate_modal() -> void:
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
		if hud.has_method("open_syndicate_modal"):
			hud.open_syndicate_modal()
		elif ResourceLoader.exists("res://scenes/ui/syndicate_modal.tscn"):
			var modal_scene = load("res://scenes/ui/syndicate_modal.tscn")
			if modal_scene != null and hud.has_method("open_modal"):
				hud.open_modal(modal_scene)
		elif main_3d != null and main_3d.has_method("open_hud_overlay") and not main_3d.is_hud_overlay_open():
			main_3d.open_hud_overlay()
	elif main_3d != null and main_3d.has_method("open_hud_overlay") and not main_3d.is_hud_overlay_open():
		main_3d.open_hud_overlay()
