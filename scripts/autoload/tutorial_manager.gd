extends Node
class_name TutorialManagerClass

## Central Tutorial Manager Autoload for IdleArcade (Phase 17 Milestone 2).
## Coordinates the 6-step Linear Intro Sequence across 2D (main.tscn) and 3D (main_3d.tscn),
## manages the darkened spotlight overlay and directional arrow, interfaces with DialoguePanel,
## and guarantees instant unlock via Skip button.

signal step_started(step_index: int, target_name: String)
signal step_completed(step_index: int)
signal tutorial_completed()
signal tutorial_skipped()
signal contextual_hint_triggered(hint_id: String)

enum State {
	IDLE = 0,
	INTRO_STEP_1_TAP = 1,
	INTRO_STEP_2_UPGRADE = 2,
	INTRO_STEP_3_FRENZY = 3,
	INTRO_STEP_4_CAMPUS = 4,
	INTRO_STEP_5_COLLECTIBLE = 5,
	INTRO_STEP_6_STATION = 6,
	COMPLETED = 7
}
const Step = State

const TUTORIAL_OVERLAY_SCENE: PackedScene = preload("res://scenes/ui/tutorial_overlay.tscn")

var current_step: int = 0
var is_intro_active: bool = false
var tutorial_overlay: CanvasLayer = null
var dialogue_panel: Control = null

var _saved_dialogue_layer: int = 0
var _fallback_dialogue_layer: CanvasLayer = null
var _fallback_dialogue_panel: DialoguePanel = null
var _transition_in_flight: bool = false

func _ready() -> void:
	_ensure_overlay()

func _ensure_overlay() -> void:
	if tutorial_overlay == null or not is_instance_valid(tutorial_overlay):
		tutorial_overlay = TUTORIAL_OVERLAY_SCENE.instantiate() as CanvasLayer
		add_child(tutorial_overlay)
		if tutorial_overlay.has_signal("skip_pressed"):
			if not tutorial_overlay.skip_pressed.is_connected(skip_tutorial):
				tutorial_overlay.skip_pressed.connect(skip_tutorial)
		if tutorial_overlay.has_method("clear_highlight"):
			tutorial_overlay.clear_highlight()
		if tutorial_overlay.has_method("set_skip_visible"):
			tutorial_overlay.set_skip_visible(false)

func _process(_delta: float) -> void:
	if not is_intro_active:
		return
	# Continuously track collectible on screen during Step 5
	if current_step == State.INTRO_STEP_5_COLLECTIBLE and tutorial_overlay != null:
		var col = _find_nearest_collectible()
		if col != null and is_instance_valid(col) and is_inside_tree():
			var cam = get_viewport().get_camera_3d() if get_viewport() != null else null
			if cam != null and not cam.is_position_behind(col.global_position):
				var screen_pos: Vector2 = cam.unproject_position(col.global_position + Vector3(0.0, 0.5, 0.0))
				var r: float = 50.0
				tutorial_overlay.highlight_target_rect(Rect2(screen_pos.x - r, screen_pos.y - r, r * 2.0, r * 2.0), 6.0)

func _physics_process(_delta: float) -> void:
	if not is_intro_active:
		return
	# Detect avatar movement in Step 4
	if current_step == State.INTRO_STEP_4_CAMPUS:
		var tree = get_tree()
		if tree != null and tree.root != null:
			var avatar = tree.root.find_child("Avatar3D", true, false) as CharacterBody3D
			if avatar != null and is_instance_valid(avatar):
				if avatar.velocity.length() > 0.1:
					advance_step()

## Returns true if the linear intro sequence is currently active.
func is_tutorial_active() -> bool:
	return is_intro_active and current_step > int(State.IDLE) and current_step < int(State.COMPLETED)

## Returns current intro step index.
func get_current_step() -> int:
	return current_step

## Helper query checking if a fresh game should auto-launch the intro.
func should_start_intro() -> bool:
	var gs = get_node_or_null("/root/GameState")
	if gs == null:
		return not FileAccess.file_exists("user://savegame.json")
	if gs.has_method("is_first_time_player"):
		return gs.is_first_time_player()
	if "tutorial_completed" in gs and "tutorial_skipped" in gs:
		return not gs.tutorial_completed and not gs.tutorial_skipped
	return not FileAccess.file_exists("user://savegame.json")

## Hook invoked by main.gd or main_3d.gd when ready
func on_scene_ready(scene_node: Node) -> void:
	if is_intro_active and current_step == State.INTRO_STEP_4_CAMPUS:
		if scene_node != null and (scene_node.name == "Main3D" or scene_node is Main3D or scene_node.has_node("Avatar3D")):
			_setup_step_4_in_3d()

## Starts the linear intro sequence beginning at Step 1 (INTRO_STEP_1_TAP).
func start_linear_intro() -> void:
	if is_tutorial_active():
		return
	var gs = get_node_or_null("/root/GameState")
	if gs != null:
		if "tutorial_completed" in gs and gs.tutorial_completed:
			return
		if "tutorial_skipped" in gs and gs.tutorial_skipped:
			return

	_ensure_overlay()
	is_intro_active = true
	current_step = State.INTRO_STEP_1_TAP
	if tutorial_overlay != null and tutorial_overlay.has_method("set_skip_visible"):
		tutorial_overlay.set_skip_visible(true)
	_setup_current_step()

## Advances to next sequential step in the linear intro flow.
func advance_step() -> void:
	if not is_intro_active:
		return

	var completed_step: int = current_step
	_disconnect_step_listeners()

	match current_step:
		State.INTRO_STEP_1_TAP:
			step_completed.emit(completed_step)
			current_step = State.INTRO_STEP_2_UPGRADE
			_setup_current_step()
		State.INTRO_STEP_2_UPGRADE:
			step_completed.emit(completed_step)
			current_step = State.INTRO_STEP_3_FRENZY
			_setup_current_step()
		State.INTRO_STEP_3_FRENZY:
			step_completed.emit(completed_step)
			current_step = State.INTRO_STEP_4_CAMPUS
			_transition_to_3d_campus()
		State.INTRO_STEP_4_CAMPUS:
			step_completed.emit(completed_step)
			current_step = State.INTRO_STEP_5_COLLECTIBLE
			_setup_current_step()
		State.INTRO_STEP_5_COLLECTIBLE:
			step_completed.emit(completed_step)
			current_step = State.INTRO_STEP_6_STATION
			_setup_current_step()
		State.INTRO_STEP_6_STATION:
			_complete_tutorial()
		_:
			_complete_tutorial()

## Immediately skips the tutorial, unlocks all mechanics, and clears highlights.
func skip_tutorial() -> void:
	if not is_intro_active and current_step == State.COMPLETED:
		return
	_disconnect_step_listeners()
	if tutorial_overlay != null:
		if tutorial_overlay.has_method("clear_highlight"):
			tutorial_overlay.clear_highlight()
		if tutorial_overlay.has_method("set_skip_visible"):
			tutorial_overlay.set_skip_visible(false)

	var dp = get_dialogue_panel()
	if dp != null and dp.visible:
		if dp.get("_is_tutorial_mode") != null:
			dp.set("_is_tutorial_mode", false)
		if dp.get("_is_hint_mode") != null:
			dp.set("_is_hint_mode", false)
		dp.visible = false
		if dp.has_method("_restore_default_ui_state"):
			dp.call("_restore_default_ui_state")
		if dp.has_signal("closed"):
			dp.closed.emit()
	_restore_dialogue_layer()

	var gs = get_node_or_null("/root/GameState")
	if gs != null:
		if "tutorial_skipped" in gs:
			gs.tutorial_skipped = true
		if "tutorial_completed" in gs:
			gs.tutorial_completed = true
		if "tutorial_replay_requested" in gs:
			gs.tutorial_replay_requested = false
		if "tutorial_current_step" in gs:
			gs.tutorial_current_step = int(State.COMPLETED)
		if gs.has_method("save_to_disk"):
			gs.save_to_disk()

	current_step = State.COMPLETED
	is_intro_active = false
	tutorial_skipped.emit()
	tutorial_completed.emit()

## Resets tutorial progression state for Settings "Replay Tutorial" flow.
func reset_tutorial() -> void:
	_disconnect_step_listeners()
	if tutorial_overlay != null:
		if tutorial_overlay.has_method("clear_highlight"):
			tutorial_overlay.clear_highlight()
		if tutorial_overlay.has_method("set_skip_visible"):
			tutorial_overlay.set_skip_visible(false)
	var dp = get_dialogue_panel()
	if dp != null and dp.visible:
		if dp.get("_is_tutorial_mode") != null:
			dp.set("_is_tutorial_mode", false)
		if dp.get("_is_hint_mode") != null:
			dp.set("_is_hint_mode", false)
		dp.visible = false
		if dp.has_method("_restore_default_ui_state"):
			dp.call("_restore_default_ui_state")
	_restore_dialogue_layer()
	current_step = State.IDLE
	is_intro_active = false

## Triggers a non-blocking contextual hint with spotlight on target_control.
func trigger_contextual_hint(hint_id: String, target_control: Control = null) -> void:
	if is_tutorial_active():
		return
	var gs = get_node_or_null("/root/GameState")
	if gs != null:
		if gs.has_method("has_seen_contextual_hint") and gs.has_seen_contextual_hint(hint_id):
			return
		if gs.has_method("mark_contextual_hint_seen"):
			gs.mark_contextual_hint_seen(hint_id)

	contextual_hint_triggered.emit(hint_id)

	var dp = get_dialogue_panel()
	if dp == null:
		return

	var title: String = "💡 Hinweis"
	var text: String = ""
	match hint_id:
		"hint_zone_gate":
			title = "Sicherheitsbereich // Zonentor"
			text = "Dieses Zonentor verlangt ein höheres Level oder Startup-Budget, um den Bereich zu entsperren!"
		"hint_tech_tree":
			title = "R&D // Forschungsbaum"
			text = "Hier erforschst du revolutionäre Technologien, um passive Erträge und Campus-Effizienz zu maximieren!"
		"hint_staff":
			title = "Team // Personalwesen"
			text = "Stelle Chibi-Spezialisten ein! Behalte ihre Moral und Erschöpfung im Auge und gönn ihnen Kaffeepausen."
		"hint_minigame":
			title = "Campus-Station // Arcade"
			text = "Jede Station bietet ein Geschicklichkeits-Minispiel! Triff die Zielzone für massive RPS- und Bewertungs-Boosts."
		"hint_daily_board":
			title = "Ziele // Daily Board"
			text = "Erfülle täglich wechselnde Meilensteine, um wertvolle Belohnungen und Streak-Boni zu sichern!"
		"hint_ipo_bell":
			title = "Exit // Börsengang (IPO)"
			text = "Herzlichen Glückwunsch zum Unicorn-Status! Läute die Glocke, um an die Börse zu gehen und permanente Angel Shares zu kassieren!"
		_:
			title = "Inkubator // Info"
			text = "Ein neues Startup-Feature steht bereit!"

	var t_rect: Rect2 = Rect2()
	if target_control != null and target_control.is_inside_tree():
		t_rect = target_control.get_global_rect()

	_elevate_dialogue_layer(dp)
	if dp.has_signal("hint_dismissed") and not dp.hint_dismissed.is_connected(_on_contextual_hint_dismissed):
		dp.hint_dismissed.connect(_on_contextual_hint_dismissed)
	if dp.has_method("show_hint_popup"):
		dp.show_hint_popup(title, text, 5.0, t_rect, hint_id)

	if target_control != null and tutorial_overlay != null and tutorial_overlay.has_method("highlight_control"):
		tutorial_overlay.highlight_control(target_control)

func _on_contextual_hint_dismissed(_hint_id: String) -> void:
	if tutorial_overlay != null and tutorial_overlay.has_method("clear_highlight"):
		tutorial_overlay.clear_highlight()
	_restore_dialogue_layer()

func _setup_current_step() -> void:
	match current_step:
		State.INTRO_STEP_1_TAP:
			step_started.emit(1, "Core")
			var core = get_tree().root.find_child("Core", true, false) as Control if get_tree() != null else null
			if core != null and core.is_inside_tree():
				tutorial_overlay.highlight_control(core, 12.0)
			else:
				tutorial_overlay.highlight_target_rect(Rect2(Vector2(265, 425), Vector2(190, 190)), 12.0)

			_show_mascot_dialogue("Pre-Seed // Erste Traktion",
				"Willkommen im Inkubator, Gründer! Jedes erfolgreiche Unicorn beginnt mit dem allerersten Nutzer. Tippe auf den leuchtenden Reaktorkern in der Mitte, um deine ersten Nutzer zu generieren!")

			var gs = get_node_or_null("/root/GameState")
			if gs != null and gs.has_signal("core_tapped"):
				if not gs.core_tapped.is_connected(_on_step_1_tapped):
					gs.core_tapped.connect(_on_step_1_tapped, CONNECT_ONE_SHOT)

		State.INTRO_STEP_2_UPGRADE:
			step_started.emit(2, "UpgradeShop")
			var target_node = get_tree().root.find_child("UpgradeList", true, false) if get_tree() != null else null
			var highlighted: bool = false
			if target_node != null and target_node.get_child_count() > 0:
				var target_card: Control = null
				for child in target_node.get_children():
					if child is Control and (child.name == "tier_1" or "tier_1" in child.name):
						target_card = child
						break
				if target_card == null:
					if target_node.get_child_count() > 1:
						target_card = target_node.get_child(1) as Control
					else:
						target_card = target_node.get_child(0) as Control
				if target_card != null:
					tutorial_overlay.highlight_control(target_card, 8.0)
					highlighted = true
			if not highlighted:
				tutorial_overlay.highlight_target_rect(Rect2(Vector2(20, 810), Vector2(680, 72)), 8.0)

			_show_mascot_dialogue("Seed Stage // Automatisierung",
				"Großartig! Aber manuelles Klicken skaliert auf Dauer nicht. Investiere in dein erstes Marketing-Upgrade 'Virale Memes', damit deine Nutzerzahlen vollautomatisch und kontinuierlich wachsen!")

			var gs = get_node_or_null("/root/GameState")
			if gs != null and gs.has_signal("upgrade_purchased"):
				if not gs.upgrade_purchased.is_connected(_on_step_2_upgraded):
					gs.upgrade_purchased.connect(_on_step_2_upgraded, CONNECT_ONE_SHOT)

		State.INTRO_STEP_3_FRENZY:
			step_started.emit(3, "FrenzyMeter")
			var frenzy = get_tree().root.find_child("FrenzyProgressBar", true, false) as Control if get_tree() != null else null
			if frenzy != null and frenzy.is_inside_tree():
				tutorial_overlay.highlight_control(frenzy, 8.0)
			else:
				tutorial_overlay.highlight_target_rect(Rect2(Vector2(24, 204), Vector2(672, 24)), 8.0)

			_show_mascot_dialogue("Overdrive // Viraler Hype",
				"Behalte diesen Hype-Balken im Auge! Schnelle Klick-Serien laden den Overdrive auf. Erreicht er 100%, zündet der 'Virale Hype' mit dreifacher Nutzerproduktion für dein gesamtes Startup!")

			var gs = get_node_or_null("/root/GameState")
			if gs != null and gs.has_signal("frenzy_updated"):
				if not gs.frenzy_updated.is_connected(_on_step_3_frenzy):
					gs.frenzy_updated.connect(_on_step_3_frenzy)

		State.INTRO_STEP_4_CAMPUS:
			_setup_step_4_in_3d()

		State.INTRO_STEP_5_COLLECTIBLE:
			step_started.emit(5, "Collectible")
			var col = _find_nearest_collectible()
			var highlighted: bool = false
			if col != null and is_inside_tree():
				var cam = get_viewport().get_camera_3d() if get_viewport() != null else null
				if cam != null and not cam.is_position_behind(col.global_position):
					var screen_pos: Vector2 = cam.unproject_position(col.global_position + Vector3(0.0, 0.5, 0.0))
					var r: float = 50.0
					tutorial_overlay.highlight_target_rect(Rect2(screen_pos.x - r, screen_pos.y - r, r * 2.0, r * 2.0), 6.0)
					highlighted = true
			if not highlighted:
				tutorial_overlay.highlight_target_rect(Rect2(Vector2(260, 480), Vector2(100, 100)), 8.0)

			_show_mascot_dialogue("Förderung // Venture-Koffer",
				"Fantastisch! Auf dem gesamten Campus findest du wertvolle Förderkoffer und Tech-Items. Laufe einfach nah an den Koffer heran – dein magnetischer Sammelradius sammelt ihn automatisch für wertvolle Boni ein!")

			var gs = get_node_or_null("/root/GameState")
			if gs != null and gs.has_signal("collectible_picked_up"):
				if not gs.collectible_picked_up.is_connected(_on_step_5_collected):
					gs.collectible_picked_up.connect(_on_step_5_collected, CONNECT_ONE_SHOT)

		State.INTRO_STEP_6_STATION:
			step_started.emit(6, "ServerTerminal")
			var act_btn = get_tree().root.find_child("ActionButton", true, false) as Control if get_tree() != null else null
			if act_btn != null and act_btn.is_inside_tree():
				tutorial_overlay.highlight_control(act_btn, 8.0)
			else:
				tutorial_overlay.highlight_target_rect(Rect2(Vector2(580, 1020), Vector2(100, 100)), 8.0)

			_show_mascot_dialogue("Infrastruktur // Server-Overclock",
				"Hier im Serverraum schlägt das technische Herz unseres Startups! Tritt an die Konsole und drücke den Aktionsbutton '[E] Hack', um den Server zu übertakten und deinen Durchsatz massiv zu steigern!")

			var server = get_tree().root.find_child("ServerTerminal", true, false) if get_tree() != null else null
			if server != null and server.has_signal("terminal_interacted"):
				if not server.terminal_interacted.is_connected(_on_step_6_terminal):
					server.terminal_interacted.connect(_on_step_6_terminal, CONNECT_ONE_SHOT)
			var tc = get_tree().root.find_child("TouchControls", true, false) if get_tree() != null else null
			if tc != null and tc.has_signal("action_triggered"):
				if not tc.action_triggered.is_connected(_on_step_6_touch):
					tc.action_triggered.connect(_on_step_6_touch, CONNECT_ONE_SHOT)

func _setup_step_4_in_3d() -> void:
	step_started.emit(4, "VirtualJoystick")
	var joy = get_tree().root.find_child("VirtualJoystick", true, false) as Control if get_tree() != null else null
	if joy == null and get_tree() != null:
		joy = get_tree().root.find_child("ArcadeVirtualJoystick", true, false) as Control
	if joy != null and joy.is_inside_tree():
		tutorial_overlay.highlight_control(joy, 12.0)
	else:
		tutorial_overlay.highlight_target_rect(Rect2(Vector2(90, 910), Vector2(180, 180)), 12.0)

	_show_mascot_dialogue("Campus // 3D-Navigation",
		"Willkommen auf unserem modernen Inkubator-Campus! Bewege deinen Gründer-Avatar mit dem virtuellen Joystick auf der linken Bildschirmhälfte oder den WASD-Tasten, um das Firmengelände zu erkunden.")

	if joy != null and joy.has_signal("joystick_moved"):
		if not joy.joystick_moved.is_connected(_on_step_4_joystick):
			joy.joystick_moved.connect(_on_step_4_joystick, CONNECT_ONE_SHOT)

func _transition_to_3d_campus() -> void:
	if tutorial_overlay != null and tutorial_overlay.has_method("clear_highlight"):
		tutorial_overlay.clear_highlight()

	var tree = get_tree()
	if tree == null:
		_setup_step_4_in_3d()
		return

	var cur = tree.current_scene
	if cur != null and (cur.name == "Main3D" or cur is Main3D or cur.has_node("Avatar3D")):
		_setup_step_4_in_3d()
		return

	# Only change scene to Main3D if currently running the 2D Main scene
	if cur != null and (cur.name == "Main" or cur.name == "main"):
		_transition_in_flight = true
		tree.change_scene_to_file("res://scenes/main_3d.tscn")

		var timeout_frames: int = 60
		while timeout_frames > 0:
			timeout_frames -= 1
			await tree.process_frame
			cur = tree.current_scene
			if cur != null and (cur.name == "Main3D" or cur is Main3D or cur.has_node("Avatar3D")):
				if not cur.is_node_ready():
					await cur.ready
				break

		await tree.process_frame
		_transition_in_flight = false

		if not is_intro_active or current_step != State.INTRO_STEP_4_CAMPUS:
			return

	_setup_step_4_in_3d()

func _show_mascot_dialogue(title: String, text: String, speaker: String = "Angel Investor") -> void:
	var dp = get_dialogue_panel()
	if dp == null:
		return
	_elevate_dialogue_layer(dp)
	if dp.has_method("open_for_tutorial_step"):
		dp.open_for_tutorial_step(speaker, title, text, Color(1.0, 0.82, 0.15))
	elif dp.has_method("open_dialogue"):
		dp.open_dialogue(speaker, title, text)

	if dp.has_signal("tutorial_advanced"):
		if not dp.tutorial_advanced.is_connected(_on_dialogue_advanced):
			dp.tutorial_advanced.connect(_on_dialogue_advanced, CONNECT_ONE_SHOT)

func _elevate_dialogue_layer(dp: Control) -> void:
	if dp == null:
		return
	var parent_layer = dp.get_parent() as CanvasLayer
	if parent_layer != null and parent_layer.layer < 95:
		_saved_dialogue_layer = parent_layer.layer
		parent_layer.layer = 96

func _restore_dialogue_layer() -> void:
	var dp = get_dialogue_panel()
	if dp != null and _saved_dialogue_layer > 0:
		var parent_layer = dp.get_parent() as CanvasLayer
		if parent_layer != null:
			parent_layer.layer = _saved_dialogue_layer
		_saved_dialogue_layer = 0

func _complete_tutorial() -> void:
	_disconnect_step_listeners()
	if tutorial_overlay != null:
		if tutorial_overlay.has_method("clear_highlight"):
			tutorial_overlay.clear_highlight()
		if tutorial_overlay.has_method("set_skip_visible"):
			tutorial_overlay.set_skip_visible(false)

	var dp = get_dialogue_panel()
	if dp != null:
		_elevate_dialogue_layer(dp)
		if dp.has_method("open_for_tutorial_step"):
			dp.open_for_tutorial_step(
				"Angel Investor",
				"Onboarding abgeschlossen // Unicorn-Ready!",
				"Hervorragend, Gründer! Du hast alle Kernsysteme erfolgreich gemeistert: Klick-Traktion, passive Upgrades, Hype-Combos, Campus-Mobilität und Stationen-Hacks. Jetzt gehört die Tech-Welt dir. Viel Erfolg!",
				Color(1.0, 0.82, 0.15)
			)
			var cb = dp.get_node_or_null("%CloseButton") as Button
			if cb != null:
				cb.text = "Los geht's! 🚀"
		if dp.has_signal("closed"):
			if not dp.closed.is_connected(_on_final_dialogue_closed):
				dp.closed.connect(_on_final_dialogue_closed, CONNECT_ONE_SHOT)
		if dp.has_signal("tutorial_advanced"):
			if not dp.tutorial_advanced.is_connected(_on_final_dialogue_closed):
				dp.tutorial_advanced.connect(_on_final_dialogue_closed, CONNECT_ONE_SHOT)

	var am = get_node_or_null("/root/AudioManager")
	if am != null and am.has_method("play_sfx_victory_jingle"):
		am.play_sfx_victory_jingle()

	var gs = get_node_or_null("/root/GameState")
	if gs != null:
		if "tutorial_completed" in gs:
			gs.tutorial_completed = true
		if "tutorial_replay_requested" in gs:
			gs.tutorial_replay_requested = false
		if "tutorial_current_step" in gs:
			gs.tutorial_current_step = int(State.COMPLETED)
		if gs.has_method("save_to_disk"):
			gs.save_to_disk()

	current_step = State.COMPLETED
	is_intro_active = false
	step_completed.emit(6)
	tutorial_completed.emit()

func _on_final_dialogue_closed() -> void:
	_restore_dialogue_layer()

func _on_dialogue_advanced() -> void:
	if not is_intro_active:
		return
	if current_step == State.INTRO_STEP_1_TAP:
		var gs = get_node_or_null("/root/GameState")
		if gs != null and "energy" in gs:
			gs.energy = maxf(gs.energy, 30.0)
			if gs.has_signal("energy_changed"):
				gs.energy_changed.emit(gs.energy, 30.0)
	advance_step()

func _on_step_1_tapped(_count: int) -> void:
	if is_intro_active and current_step == State.INTRO_STEP_1_TAP:
		var gs = get_node_or_null("/root/GameState")
		if gs != null and "energy" in gs:
			gs.energy = maxf(gs.energy, 30.0)
			if gs.has_signal("energy_changed"):
				gs.energy_changed.emit(gs.energy, 30.0)
		advance_step()

func _on_step_2_upgraded(upgrade_id: String, _level: int, _cost: float) -> void:
	if is_intro_active and current_step == State.INTRO_STEP_2_UPGRADE:
		if upgrade_id == "tier_1" or upgrade_id == "click_booster" or not upgrade_id.is_empty():
			advance_step()

func _on_step_3_frenzy(_mult: float, fill: float) -> void:
	if is_intro_active and current_step == State.INTRO_STEP_3_FRENZY:
		if fill > 0.0 or _mult > 1.0:
			advance_step()

func _on_step_4_joystick(_dir: Vector3, _raw: Vector2) -> void:
	if is_intro_active and current_step == State.INTRO_STEP_4_CAMPUS:
		advance_step()

func _on_step_5_collected(_item_type: String, _total: int) -> void:
	if is_intro_active and current_step == State.INTRO_STEP_5_COLLECTIBLE:
		advance_step()

func _on_step_6_terminal() -> void:
	if is_intro_active and current_step == State.INTRO_STEP_6_STATION:
		advance_step()

func _on_step_6_touch(_interactable: Node3D) -> void:
	if is_intro_active and current_step == State.INTRO_STEP_6_STATION:
		advance_step()

func _disconnect_step_listeners() -> void:
	var gs = get_node_or_null("/root/GameState")
	if gs != null:
		if gs.has_signal("core_tapped") and gs.core_tapped.is_connected(_on_step_1_tapped):
			gs.core_tapped.disconnect(_on_step_1_tapped)
		if gs.has_signal("upgrade_purchased") and gs.upgrade_purchased.is_connected(_on_step_2_upgraded):
			gs.upgrade_purchased.disconnect(_on_step_2_upgraded)
		if gs.has_signal("frenzy_updated") and gs.frenzy_updated.is_connected(_on_step_3_frenzy):
			gs.frenzy_updated.disconnect(_on_step_3_frenzy)
		if gs.has_signal("collectible_picked_up") and gs.collectible_picked_up.is_connected(_on_step_5_collected):
			gs.collectible_picked_up.disconnect(_on_step_5_collected)

	var tree = get_tree()
	if tree != null and tree.root != null:
		var joy = tree.root.find_child("VirtualJoystick", true, false)
		if joy == null:
			joy = tree.root.find_child("ArcadeVirtualJoystick", true, false)
		if joy != null and joy.has_signal("joystick_moved") and joy.joystick_moved.is_connected(_on_step_4_joystick):
			joy.joystick_moved.disconnect(_on_step_4_joystick)

		var server = tree.root.find_child("ServerTerminal", true, false)
		if server != null and server.has_signal("terminal_interacted") and server.terminal_interacted.is_connected(_on_step_6_terminal):
			server.terminal_interacted.disconnect(_on_step_6_terminal)

		var tc = tree.root.find_child("TouchControls", true, false)
		if tc != null and tc.has_signal("action_triggered") and tc.action_triggered.is_connected(_on_step_6_touch):
			tc.action_triggered.disconnect(_on_step_6_touch)

	var dp = get_dialogue_panel()
	if dp != null and dp.has_signal("tutorial_advanced") and dp.tutorial_advanced.is_connected(_on_dialogue_advanced):
		dp.tutorial_advanced.disconnect(_on_dialogue_advanced)

func _find_nearest_collectible() -> Node3D:
	var tree = get_tree()
	if tree == null or tree.root == null:
		return null
	var col_container = tree.root.find_child("Collectibles", true, false)
	if col_container != null:
		for c in col_container.get_children():
			if c is Node3D and c.visible:
				return c
	var items = tree.get_nodes_in_group("collectibles")
	for item in items:
		if item is Node3D and item.visible:
			return item
	return null

func get_dialogue_panel() -> Control:
	if dialogue_panel != null and is_instance_valid(dialogue_panel) and dialogue_panel.is_inside_tree():
		return dialogue_panel

	var tree = get_tree()
	if tree != null and tree.root != null:
		var dp = tree.root.find_child("DialoguePanel", true, false) as Control
		if dp != null:
			dialogue_panel = dp
			return dialogue_panel

	# Fallback for standalone unit tests
	if _fallback_dialogue_panel == null or not is_instance_valid(_fallback_dialogue_panel):
		var scene = load("res://scenes/dialogue_panel.tscn")
		if scene != null:
			_fallback_dialogue_layer = CanvasLayer.new()
			_fallback_dialogue_layer.layer = 96
			_fallback_dialogue_layer.name = "FallbackDialogueLayer"
			add_child(_fallback_dialogue_layer)
			_fallback_dialogue_panel = scene.instantiate() as DialoguePanel
			_fallback_dialogue_layer.add_child(_fallback_dialogue_panel)
			dialogue_panel = _fallback_dialogue_panel
	return dialogue_panel
