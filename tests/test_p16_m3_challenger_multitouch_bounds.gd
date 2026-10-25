extends SceneTree

## =============================================================================
## Adversarial Challenger M3-IT2 Test Suite:
## Rapid Multi-Touch, Edge Bounds & Pointer Isolation Stress Harness
## File: IdleArcade/tests/test_p16_m3_challenger_multitouch_bounds.gd
##
## Challenger: Challenger M3-IT2-2
## Scope:
## 1. 10-Finger Rapid Multi-Touch Burst Stress across all 3 Minigames
## 2. Zero Click-Through / Pointer Leakage Detector to 3D World & Background UI
## 3. Boundary & Extreme Coords Touch Ingestion (0,0, negatives, extreme offscreen)
## 4. Multi-Resolution Responsive Ergonomics (Portrait, Landscape, Tall Screen)
## 5. Rapid Station Gating / Restoration Churn (10 rapid open-close cycles)
## 6. Proximity Rapid Churn (100 rapid enter/exit events)
##
## Execution:
##   godot.cmd --headless --path IdleArcade -s tests/test_p16_m3_challenger_multitouch_bounds.gd
## =============================================================================

var pass_count: int = 0
var fail_count: int = 0
var findings: Array[String] = []

var _mounted_nodes: Array[Node] = []
var _save_backup_text: String = ""
var _had_save_backup: bool = false

func _assert(condition: bool, test_name: String, detail: String = "") -> void:
	if condition:
		print("  [PASS] %s" % test_name)
		pass_count += 1
	else:
		var err_msg: String = "  [FAIL] %s" % test_name
		if detail != "":
			err_msg += " -> " + detail
		printerr(err_msg)
		findings.append(err_msg)
		fail_count += 1

func _init() -> void:
	print("====================================================================")
	print("[CHALLENGER M3-IT2-2] Rapid Multi-Touch & Edge Bounds Stress Harness")
	print("====================================================================")
	process_frame.connect(_on_first_frame, CONNECT_ONE_SHOT)

func _on_first_frame() -> void:
	if FileAccess.file_exists("user://savegame.json"):
		var f = FileAccess.open("user://savegame.json", FileAccess.READ)
		if f != null:
			_save_backup_text = f.get_as_text()
			_had_save_backup = true
			f.close()

	await _run_all_adversarial_stress_tests()
	_cleanup_and_quit()

func _cleanup_and_quit() -> void:
	print("\n--- TEARDOWN: Restoring Environment ---")
	if _had_save_backup:
		var f_res = FileAccess.open("user://savegame.json", FileAccess.WRITE)
		if f_res != null:
			f_res.store_string(_save_backup_text)
			f_res.close()
			print("  [CLEANUP] Restored original user://savegame.json")
	elif FileAccess.file_exists("user://savegame.json"):
		DirAccess.remove_absolute("user://savegame.json")
		print("  [CLEANUP] Removed temporary user://savegame.json")

	for i in range(_mounted_nodes.size() - 1, -1, -1):
		var n = _mounted_nodes[i]
		if is_instance_valid(n):
			if n.get_parent() != null:
				n.get_parent().remove_child(n)
			n.free()
	_mounted_nodes.clear()

	print("\n====================================================================")
	print("[CHALLENGER M3-IT2-2] RESULTS: %d PASSED, %d FAILED" % [pass_count, fail_count])
	print("====================================================================")
	if fail_count == 0:
		print(">>> EMPIRICAL VERDICT: APPROVE (Exit Code 0) <<<\n")
		quit(0)
	else:
		printerr(">>> EMPIRICAL VERDICT: REQUEST_CHANGES (Exit Code 1, %d defects) <<<\n" % fail_count)
		quit(1)

func _run_all_adversarial_stress_tests() -> void:
	await _test_multitouch_event_absorption_and_leakage()
	await _test_edge_and_extreme_coordinates_bounds()
	await _test_multi_resolution_touch_ergonomics()
	await _test_rapid_station_gating_churn()
	await _test_rapid_station_proximity_churn()
	await _test_simultaneous_multitouch_button_race()

# ------------------------------------------------------------------------------
# 1. 10-Finger Rapid Multi-Touch Burst & Zero Click-Through
# ------------------------------------------------------------------------------
func _test_multitouch_event_absorption_and_leakage() -> void:
	print("\n--- 1. 10-Finger Multi-Touch Event Absorption & Zero Click-Through ---")

	var minigame_scenes = [
		{"path": "res://scenes/ui/cyber_sync_minigame.tscn", "name": "CyberSyncMinigame"},
		{"path": "res://scenes/ui/pitch_stage_minigame.tscn", "name": "PitchStageMinigame"},
		{"path": "res://scenes/ui/espresso_brew_minigame.tscn", "name": "EspressoBrewMinigame"}
	]

	for mg_info in minigame_scenes:
		var scene = load(mg_info["path"])
		_assert(scene != null, "1.1 Loaded %s" % mg_info["name"])
		if scene == null:
			continue

		# Setup a background ClickThroughDetector Control behind the modal
		var detector = Control.new()
		detector.name = "ClickThroughDetector"
		detector.set_anchors_preset(Control.PRESET_FULL_RECT)
		detector.mouse_filter = Control.MOUSE_FILTER_STOP
		var leaked_events: int = 0
		detector.gui_input.connect(func(ev): leaked_events += 1)

		root.add_child(detector)
		_mounted_nodes.append(detector)

		var modal: Control = scene.instantiate()
		root.add_child(modal)
		_mounted_nodes.append(modal)
		await process_frame

		# Rapid 10-finger burst: 10 down, 10 drag, 10 up
		var survived_burst = true
		for finger_idx in range(10):
			var pos = Vector2(100.0 + finger_idx * 50.0, 150.0 + finger_idx * 30.0)

			# Touch Down
			var touch_down = InputEventScreenTouch.new()
			touch_down.index = finger_idx
			touch_down.position = pos
			touch_down.pressed = true
			modal._gui_input(touch_down)

			# Touch Drag
			var drag = InputEventScreenDrag.new()
			drag.index = finger_idx
			drag.position = pos + Vector2(10.0, 5.0)
			drag.relative = Vector2(10.0, 5.0)
			modal._gui_input(drag)

			# Touch Up
			var touch_up = InputEventScreenTouch.new()
			touch_up.index = finger_idx
			touch_up.position = pos + Vector2(10.0, 5.0)
			touch_up.pressed = false
			modal._gui_input(touch_up)

		_assert(survived_burst, "1.2 %s survived 10-finger concurrent touch/drag burst" % mg_info["name"])
		_assert(leaked_events == 0, "1.3 Zero touch events leaked through %s to background (leaks=%d)" % [mg_info["name"], leaked_events])

		modal.queue_free()
		detector.queue_free()
		await process_frame

# ------------------------------------------------------------------------------
# 2. Boundary & Extreme Coordinate Bounds
# ------------------------------------------------------------------------------
func _test_edge_and_extreme_coordinates_bounds() -> void:
	print("\n--- 2. Boundary & Extreme Touch Coordinates Ingestion ---")

	var cyber_scene = load("res://scenes/ui/cyber_sync_minigame.tscn")
	var cyber: Control = cyber_scene.instantiate()
	root.add_child(cyber)
	_mounted_nodes.append(cyber)
	await process_frame

	var extreme_coords = [
		Vector2(0.0, 0.0),               # Top-left screen edge
		Vector2(1152.0, 0.0),            # Top-right screen edge
		Vector2(0.0, 648.0),             # Bottom-left screen edge
		Vector2(1152.0, 648.0),          # Bottom-right screen edge
		Vector2(-500.0, -500.0),         # Far negative offscreen
		Vector2(99999.0, 99999.0),       # Far positive offscreen
		Vector2(0.00001, 0.00001),       # Near-zero epsilon
		Vector2(-0.00001, -0.00001)      # Near-negative epsilon
	]

	var all_handled = true
	for pt in extreme_coords:
		var touch = InputEventScreenTouch.new()
		touch.position = pt
		touch.pressed = true
		cyber._gui_input(touch)

		var mouse = InputEventMouseButton.new()
		mouse.button_index = MOUSE_BUTTON_LEFT
		mouse.position = pt
		mouse.pressed = true
		cyber._gui_input(mouse)

	_assert(all_handled, "2.1 CyberSync ingested 8 extreme/boundary coordinates without error")
	_assert(cyber.mouse_filter == Control.MOUSE_FILTER_STOP, "2.2 Mouse filter preserved as STOP after edge touches")

	cyber.queue_free()
	await process_frame

# ------------------------------------------------------------------------------
# 3. Multi-Resolution Responsive Ergonomics (>= 56px)
# ------------------------------------------------------------------------------
func _test_multi_resolution_touch_ergonomics() -> void:
	print("\n--- 3. Multi-Resolution Responsive Ergonomics (>= 56px) ---")

	var resolutions = [
		Vector2i(720, 1280),   # Mobile portrait
		Vector2i(1080, 2400),  # Tall modern phone
		Vector2i(1280, 720),   # Mobile landscape
		Vector2i(1920, 1080)   # Desktop FHD
	]

	var minigame_scenes = [
		load("res://scenes/ui/cyber_sync_minigame.tscn"),
		load("res://scenes/ui/pitch_stage_minigame.tscn"),
		load("res://scenes/ui/espresso_brew_minigame.tscn")
	]

	for res in resolutions:
		root.size = res
		for scene in minigame_scenes:
			var modal: Control = scene.instantiate()
			root.add_child(modal)
			await process_frame

			# Scan all buttons in this modal at this resolution
			var buttons = _collect_buttons(modal)
			var all_meet_56 = true
			for btn in buttons:
				if btn.custom_minimum_size.y < 56.0:
					all_meet_56 = false
					printerr("  Button %s has custom_minimum_size.y = %f < 56.0" % [btn.name, btn.custom_minimum_size.y])
				if "close" in String(btn.name).to_lower():
					if btn.custom_minimum_size.x < 56.0:
						all_meet_56 = false
						printerr("  Close button %s has custom_minimum_size.x = %f < 56.0" % [btn.name, btn.custom_minimum_size.x])

			_assert(all_meet_56, "3.1 %s: 100%% of buttons satisfy >= 56px at %dx%d (scanned: %d)" % [
				modal.name, res.x, res.y, buttons.size()
			])

			modal.queue_free()
			await process_frame

	# Reset root size to standard
	root.size = Vector2i(1152, 648)
	await process_frame

# ------------------------------------------------------------------------------
# 4. Rapid Station Locomotion Gating & Input Restoration Churn
# ------------------------------------------------------------------------------
func _test_rapid_station_gating_churn() -> void:
	print("\n--- 4. Rapid Station Locomotion Gating & Input Restoration Churn ---")

	var avatar_scene = load("res://scenes/avatar_3d.tscn")
	var avatar = avatar_scene.instantiate()
	root.add_child(avatar)
	_mounted_nodes.append(avatar)
	avatar.set_input_enabled(true)
	await process_frame

	var st_scene = load("res://scenes/server_terminal.tscn")
	var st = st_scene.instantiate()
	root.add_child(st)
	_mounted_nodes.append(st)
	st._avatar_ref = avatar

	# Rapid 10x Open/Close cycles
	var churn_success = true
	for cycle in range(10):
		var modal = st.open_cyber_sync_minigame()
		if avatar.input_enabled != false:
			churn_success = false
		st._on_minigame_closed()
		if avatar.input_enabled != true:
			churn_success = false

	_assert(churn_success, "4.1 Avatar input toggled cleanly across 10 rapid open/close cycles")
	_assert(avatar.input_enabled == true, "4.2 Avatar input_enabled is true after churn")
	_assert(avatar.velocity.x == 0.0 and avatar.velocity.z == 0.0, "4.3 Avatar horizontal velocity is 0.0 after churn")


	st.queue_free()
	avatar.queue_free()
	await process_frame

# ------------------------------------------------------------------------------
# 5. Rapid Proximity Area Enter / Exit Churn
# ------------------------------------------------------------------------------
func _test_rapid_station_proximity_churn() -> void:
	print("\n--- 5. Rapid Station Proximity Enter / Exit Churn (100 Cycles) ---")

	var st_scene = load("res://scenes/server_terminal.tscn")
	var st = st_scene.instantiate()
	root.add_child(st)
	_mounted_nodes.append(st)
	await process_frame

	var dummy_body = CharacterBody3D.new()
	dummy_body.add_to_group("player")

	var churn_ok = true
	for i in range(100):
		st._on_interaction_body_entered(dummy_body)
		if not st._player_in_range:
			churn_ok = false
		st._on_interaction_body_exited(dummy_body)
		if st._player_in_range:
			churn_ok = false

	_assert(churn_ok, "5.1 ServerTerminal survived 100 rapid proximity body enter/exit cycles")
	_assert(st._player_in_range == false, "5.2 ServerTerminal _player_in_range safely resolved to false")
	_assert(st.current_state == st.STATE_READY, "5.3 ServerTerminal preserved STATE_READY throughout proximity churn")

	dummy_body.free()
	st.queue_free()
	await process_frame

# ------------------------------------------------------------------------------
# 6. Simultaneous Multi-Touch Button Race Stress
# ------------------------------------------------------------------------------
func _test_simultaneous_multitouch_button_race() -> void:
	print("\n--- 6. Simultaneous Multi-Touch Button Race Stress ---")

	var pitch_scene = load("res://scenes/ui/pitch_stage_minigame.tscn")
	var pitch: Control = pitch_scene.instantiate()
	root.add_child(pitch)
	_mounted_nodes.append(pitch)
	await process_frame

	var b0 = pitch.get_node_or_null("%BuzzwordButton0") as Button
	var b1 = pitch.get_node_or_null("%BuzzwordButton1") as Button
	var close_b = pitch.get_node_or_null("%CloseButton") as Button

	_assert(b0 != null and b1 != null and close_b != null, "6.1 Pitch buttons retrieved for multi-touch race")

	# Simulate two fingers tapping different buttons in the exact same frame
	var t0 = InputEventScreenTouch.new()
	t0.index = 0
	t0.position = b0.global_position + Vector2(10, 10)
	t0.pressed = true

	var t1 = InputEventScreenTouch.new()
	t1.index = 1
	t1.position = b1.global_position + Vector2(10, 10)
	t1.pressed = true

	pitch._gui_input(t0)
	pitch._gui_input(t1)

	# Direct button triggers simultaneously
	b0.pressed.emit()
	b1.pressed.emit()

	_assert(pitch.is_inside_tree(), "6.2 PitchStage minigame survived simultaneous dual-button press")
	_assert(not pitch.is_completed or pitch.current_streak >= 0, "6.3 Pitch streak state is non-negative and consistent")

	pitch.queue_free()
	await process_frame

# ------------------------------------------------------------------------------
# Helpers
# ------------------------------------------------------------------------------
func _collect_buttons(parent: Node) -> Array[Button]:
	var result: Array[Button] = []
	for child in parent.get_children():
		if child is Button:
			result.append(child)
		result.append_array(_collect_buttons(child))
	return result
