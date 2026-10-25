extends SceneTree

## =============================================================================
## Master Headless SceneTree Test Suite for Milestone 3:
## 3D Campus Stations & Interactions Test Suite
## File: IdleArcade/tests/test_3d_campus_interactions.gd
## Target: Godot 4.3 Engine Headless Runner & CI Verification (Release v2.2.0)
##
## Validates 100% of Milestone 3 3D Campus Stations & Interactions Requirements:
##   Section 1: OfficeExpansion3D & Desks Architecture
##              (5 desks, chairs, Area3D r=2.8m, PromptLabel3D, layer 1, mask 2,
##               desk upgrades L1-L3, visual ergonomics, main_3d.tscn placement).
##   Section 2: ChibiWorker3D 4-State Machine & Typing Kinematics
##              (working, break, fatigued, celebrating; thought icons 💻, ☕, 💡, 💤, 🎉;
##               procedural typing arm kinematics, head nod, 1.5x hyper-focus dilation,
##               epiphany moments, 5 specialist roles, morale/fatigue loops).
##   Section 3: 3D Campus Interactive Stations
##              (ServerTerminal, PitchStage, CoffeeMachine3D, IpoBell3D,
##               TrophyShowcase3D, DailyBoard3D, TechLabTerminal, SyndicateHQ3D;
##               groups, triggers, labels, cooldowns, signals, main_3d placement).
##   Section 4: Low-Poly Triangle Budget Certification
##              (Station budget: < 2,500 tris per station;
##               Worker budget: < 600 tris per chibi worker;
##               Office + 5 workers combined < 2,500 tris;
##               exact topology mesh inspection across all 8 stations).
##   Section 5: Dynamic TouchControls Registration & Proximity Stacking
##              (TouchControls ActionButton 100x100px, 3-tier input isolation,
##               contextual labels & styling for all 8 station types,
##               multi-station overlapping stack LIFO & arbitrary pop, action trigger).
##
## Execution:
##   godot --headless --path IdleArcade -s tests/test_3d_campus_interactions.gd
## =============================================================================

var pass_count: int = 0
var fail_count: int = 0

const MIN_EXPECTED_PASS_COUNT: int = 200
const EPSILON: float = 0.005

# Singletons tracked for lifecycle cleanup
var _mounted_nodes: Array[Node] = []
var _save_backup_text: String = ""
var _had_save_backup: bool = false

func _assert_check(condition: bool, description: String, detail: String = "") -> void:
	if condition:
		print("  [PASS] %s" % description)
		pass_count += 1
	else:
		var err_msg: String = "  [FAIL] %s" % description
		if detail != "":
			err_msg += " (Detail: %s)" % detail
		printerr(err_msg)
		fail_count += 1

func _init() -> void:
	print("\n====================================================================")
	print(">>> RUNNING IDLEARCADE PHASE 15 M3: 3D CAMPUS INTERACTIONS TEST SUITE <<<")
	print("====================================================================")
	call_deferred("_run_all_tests")

func _cleanup_and_quit(exit_code: int) -> void:
	print("\n--- TEARDOWN: Restoring Environment & Cleaning Singletons ---")
	if _had_save_backup:
		var f_res = FileAccess.open("user://savegame.json", FileAccess.WRITE)
		if f_res != null:
			f_res.store_string(_save_backup_text)
			f_res.close()
			print("  [CLEANUP] Restored original user://savegame.json")
	elif FileAccess.file_exists("user://savegame.json"):
		DirAccess.remove_absolute("user://savegame.json")
		print("  [CLEANUP] Removed temporary user://savegame.json")

	# Clean up mounted singletons in reverse order
	for i in range(_mounted_nodes.size() - 1, -1, -1):
		var n = _mounted_nodes[i]
		if is_instance_valid(n):
			if n.get_parent() != null:
				n.get_parent().remove_child(n)
			n.free()
	_mounted_nodes.clear()
	print("  [CLEANUP] All test harness singletons safely unmounted.")

	quit(exit_code)

func _run_all_tests() -> void:
	await process_frame

	# Backup existing savegame if present
	if FileAccess.file_exists("user://savegame.json"):
		var f_back = FileAccess.open("user://savegame.json", FileAccess.READ)
		if f_back != null:
			_save_backup_text = f_back.get_as_text()
			_had_save_backup = true
			f_back.close()

	# -------------------------------------------------------------------------
	# STAGE 0: Autoload Singleton Mounting Harness Setup (All 6 Singletons)
	# -------------------------------------------------------------------------
	print("\n--- STAGE 0: Autoload Mounting Harness Setup ---")

	# 0.1 GameState
	var gs_script = load("res://scripts/autoload/game_state.gd")
	_assert_check(gs_script != null, "0.1 Load res://scripts/autoload/game_state.gd")
	if gs_script == null:
		printerr("[FATAL] Unable to load game_state.gd")
		_cleanup_and_quit(1)
		return

	var gs = root.get_node_or_null("GameState")
	if gs == null:
		gs = gs_script.new()
		gs.name = "GameState"
		root.add_child(gs)
		_mounted_nodes.append(gs)
	_assert_check(gs != null, "0.2 GameState mounted at /root/GameState")
	if gs.has_method("reset_state"):
		gs.reset_state()

	# 0.2 Nakama SDK Driver
	var nakama_script = load("res://addons/com.heroiclabs.nakama/Nakama.gd")
	_assert_check(nakama_script != null, "0.3 Load res://addons/com.heroiclabs.nakama/Nakama.gd")
	var nakama_node = root.get_node_or_null("Nakama")
	if nakama_node == null and nakama_script != null:
		nakama_node = nakama_script.new()
		nakama_node.name = "Nakama"
		root.add_child(nakama_node)
		_mounted_nodes.append(nakama_node)
	_assert_check(nakama_node != null, "0.4 Nakama mounted at /root/Nakama")

	# 0.3 NakamaManager
	var nm_script = load("res://scripts/autoload/nakama_manager.gd")
	_assert_check(nm_script != null, "0.5 Load res://scripts/autoload/nakama_manager.gd")
	var nm = root.get_node_or_null("NakamaManager")
	if nm == null and nm_script != null:
		nm = nm_script.new()
		nm.name = "NakamaManager"
		if "auto_login_on_ready" in nm:
			nm.auto_login_on_ready = false
		root.add_child(nm)
		_mounted_nodes.append(nm)
	_assert_check(nm != null, "0.6 NakamaManager mounted at /root/NakamaManager")

	# 0.4 HapticsManager
	var hm_script = load("res://scripts/autoload/haptics_manager.gd")
	_assert_check(hm_script != null, "0.7 Load res://scripts/autoload/haptics_manager.gd")
	var hm = root.get_node_or_null("HapticsManager")
	if hm == null and hm_script != null:
		hm = hm_script.new()
		hm.name = "HapticsManager"
		if "mock_mode" in hm:
			hm.mock_mode = true
		root.add_child(hm)
		_mounted_nodes.append(hm)
	_assert_check(hm != null, "0.8 HapticsManager mounted at /root/HapticsManager")

	# 0.5 AudioManager
	var am_script = load("res://scripts/autoload/audio_manager.gd")
	_assert_check(am_script != null, "0.9 Load res://scripts/autoload/audio_manager.gd")
	var am = root.get_node_or_null("AudioManager")
	if am == null and am_script != null:
		am = am_script.new()
		am.name = "AudioManager"
		root.add_child(am)
		_mounted_nodes.append(am)
	_assert_check(am != null, "0.10 AudioManager mounted at /root/AudioManager")

	# 0.6 LiveEventManager
	var lem_script = load("res://scripts/autoload/live_event_manager.gd")
	_assert_check(lem_script != null, "0.11 Load res://scripts/autoload/live_event_manager.gd")
	var lem = root.get_node_or_null("LiveEventManager")
	if lem == null and lem_script != null:
		lem = lem_script.new()
		lem.name = "LiveEventManager"
		root.add_child(lem)
		_mounted_nodes.append(lem)
	_assert_check(lem != null, "0.12 LiveEventManager mounted at /root/LiveEventManager")

	await process_frame

	# Run all 5 required sections sequentially
	await _test_section_1_office_and_desks_architecture(gs)
	await _test_section_2_chibi_worker_state_machine_and_kinematics(gs)
	await _test_section_3_3d_campus_interactive_stations(gs)
	await _test_section_4_low_poly_triangle_budget_certification()
	await _test_section_5_dynamic_touch_controls_and_proximity_stacking()

	# -------------------------------------------------------------------------
	# Final Summary & Deterministic Exit Code
	# -------------------------------------------------------------------------
	print("\n====================================================================")
	print(">>> PHASE 15 M3 TEST SUITE SUMMARY: %d PASSED, %d FAILED <<<" % [pass_count, fail_count])
	print("====================================================================")

	if fail_count == 0 and pass_count >= MIN_EXPECTED_PASS_COUNT:
		print(">>> ALL M3 3D CAMPUS INTERACTIONS TESTS PASSED (Exit Code 0) <<<")
		_cleanup_and_quit(0)
	else:
		printerr(">>> M3 3D CAMPUS INTERACTIONS TESTS FAILED (Exit Code 1, pass_count=%d/%d, fail_count=%d) <<<" % [
			pass_count, MIN_EXPECTED_PASS_COUNT, fail_count
		])
		_cleanup_and_quit(1)

# =============================================================================
# SECTION 1: OfficeExpansion3D & Desks Architecture
# =============================================================================
func _test_section_1_office_and_desks_architecture(gs: Node) -> void:
	print("\n--- SECTION 1: OfficeExpansion3D & Desks Architecture ---")

	# 1.1 Load and instantiate OfficeExpansion3D
	var office_scene = load("res://scenes/office_expansion_3d.tscn")
	_assert_check(office_scene != null, "1.1 Load res://scenes/office_expansion_3d.tscn")
	if office_scene == null:
		return

	var office = office_scene.instantiate() as OfficeExpansion3D
	_assert_check(office != null, "1.2 OfficeExpansion3D instantiates as StaticBody3D / OfficeExpansion3D")
	root.add_child(office)
	await process_frame

	# 1.2 Group memberships & Collision Layer
	_assert_check(office.is_in_group("staff_offices"), "1.3 Office in group 'staff_offices'")
	_assert_check(office.is_in_group("interactables"), "1.4 Office in group 'interactables'")
	_assert_check(office.is_in_group("stations"), "1.5 Office in group 'stations'")
	_assert_check(office.collision_layer == 1, "1.6 Office root collision_layer == 1 (World Static Geometry)")

	# 1.3 InteractionArea and PromptLabel3D
	var area = office.get_node_or_null("InteractionArea") as Area3D
	_assert_check(area != null, "1.7 InteractionArea (Area3D) exists on OfficeExpansion3D")
	if area != null:
		var col_shape = area.get_node_or_null("CollisionShape3D") as CollisionShape3D
		_assert_check(col_shape != null, "1.8 CollisionShape3D exists under InteractionArea")
		if col_shape != null:
			var sphere = col_shape.shape as SphereShape3D
			_assert_check(sphere != null, "1.9 InteractionArea shape is SphereShape3D")
			if sphere != null:
				_assert_check(absf(sphere.radius - 2.8) < EPSILON, "1.10 Proximity radius is exactly 2.8m (actual: %.2f)" % sphere.radius)

	var prompt = office.get_node_or_null("PromptLabel3D") as Label3D
	_assert_check(prompt != null, "1.11 PromptLabel3D exists on OfficeExpansion3D")
	if prompt != null:
		_assert_check(prompt.billboard == BaseMaterial3D.BillboardMode.BILLBOARD_ENABLED, "1.12 PromptLabel3D billboard mode is ENABLED")
		_assert_check(prompt.text.contains("Staff Office"), "1.13 PromptLabel3D text contains 'Staff Office' (actual: '%s')" % prompt.text)
		_assert_check(prompt.visible == false, "1.14 PromptLabel3D initially hidden prior to player proximity")

	# 1.4 Desks Container and 5 Desks
	var desks_container = office.get_node_or_null("Visuals/Desks")
	_assert_check(desks_container != null, "1.15 Visuals/Desks container exists")
	if desks_container != null:
		_assert_check(desks_container.get_child_count() == 5, "1.16 Exactly 5 workstations present in office")

	for i in range(5):
		var desk_node = office.get_desk_node(i)
		_assert_check(desk_node != null, "1.17 Desk %d node accessible via get_desk_node(%d)" % [i, i])
		if desk_node != null:
			var desk_top = desk_node.get_node_or_null("DeskTop")
			var chair = desk_node.get_node_or_null("Chair")
			var cup_holder = desk_node.get_node_or_null("CupHolder")
			var monitor_bezel = desk_node.get_node_or_null("MonitorBezel")
			var monitor_screen = desk_node.get_node_or_null("MonitorScreen")
			var dual_mon = desk_node.get_node_or_null("DualMonitor")
			var rgb_bar = desk_node.get_node_or_null("RgbLedBar")
			_assert_check(desk_top != null, "1.18 Desk %d has DeskTop mesh" % i)
			_assert_check(chair != null, "1.19 Desk %d has Chair node" % i)
			_assert_check(cup_holder != null, "1.20 Desk %d has CupHolder node" % i)
			_assert_check(monitor_bezel != null and monitor_screen != null, "1.21 Desk %d has primary Monitor (MonitorBezel & MonitorScreen)" % i)
			_assert_check(dual_mon != null, "1.22 Desk %d has DualMonitor upgrade node" % i)
			_assert_check(rgb_bar != null, "1.23 Desk %d has RgbLedBar upgrade node" % i)

	# Boundary checks for get_desk_node
	_assert_check(office.get_desk_node(-1) == null, "1.24 get_desk_node(-1) safely returns null")
	_assert_check(office.get_desk_node(5) == null, "1.25 get_desk_node(5) safely returns null")

	# 1.5 3-Tier Desk Upgrades & Visual Ergonomics
	office.apply_desk_level(0, 1)
	var d0 = office.get_desk_node(0)
	var d0_top = d0.get_node_or_null("DeskTop")
	var d0_dual = d0.get_node_or_null("DualMonitor")
	var d0_rgb = d0.get_node_or_null("RgbLedBar")
	_assert_check(d0_dual.visible == false, "1.26 Desk Level 1: DualMonitor hidden")
	_assert_check(d0_rgb.visible == false, "1.27 Desk Level 1: RgbLedBar hidden")
	_assert_check(absf(d0_top.position.y - 0.72) < EPSILON, "1.28 Desk Level 1: Standard seated desk height y=0.72m")

	office.apply_desk_level(0, 2)
	_assert_check(d0_dual.visible == true, "1.29 Desk Level 2: DualMonitor visible")
	_assert_check(d0_rgb.visible == false, "1.30 Desk Level 2: RgbLedBar hidden")
	_assert_check(absf(d0_top.position.y - 0.72) < EPSILON, "1.31 Desk Level 2: Standard seated desk height y=0.72m")

	office.apply_desk_level(0, 3)
	_assert_check(d0_dual.visible == true, "1.32 Desk Level 3: DualMonitor visible")
	_assert_check(d0_rgb.visible == true, "1.33 Desk Level 3: RgbLedBar visible")
	_assert_check(absf(d0_top.position.y - 0.95) < EPSILON, "1.34 Desk Level 3: Cyber Standing Desk elevated height y=0.95m")

	# Apply across all desks 1..4
	for d_idx in range(1, 5):
		office.apply_desk_level(d_idx, 3)
		var d_node = office.get_desk_node(d_idx)
		_assert_check(d_node.get_node("DualMonitor").visible == true and d_node.get_node("RgbLedBar").visible == true,
			"1.35 Desk %d successfully upgraded to Level 3" % d_idx)

	# 1.6 WorkerSlots & Auxiliary Props
	var worker_slots = office.get_node_or_null("WorkerSlots")
	_assert_check(worker_slots != null, "1.36 WorkerSlots container exists")
	if worker_slots != null:
		_assert_check(worker_slots.get_child_count() == 5, "1.37 Exactly 5 WorkerSlots (Slot_0 to Slot_4) present")

	var water_dispenser = office.get_node_or_null("Visuals/WaterDispenser")
	_assert_check(water_dispenser != null, "1.38 WaterDispenser prop present in office")
	if water_dispenser != null:
		_assert_check(water_dispenser.get_node_or_null("Bottle") != null, "1.39 WaterDispenser has Bottle mesh")
		_assert_check(water_dispenser.get_node_or_null("WaterGlow") != null, "1.40 WaterDispenser has WaterGlow light")

	var staff_kiosk = office.get_node_or_null("Visuals/StaffKiosk")
	_assert_check(staff_kiosk != null, "1.41 StaffKiosk prop present in office")
	if staff_kiosk != null:
		_assert_check(staff_kiosk.get_node_or_null("TerminalScreen") != null, "1.42 StaffKiosk has TerminalScreen mesh")

	# 1.7 Placement in Main Campus 3D
	var main_scene = load("res://scenes/main_3d.tscn")
	_assert_check(main_scene != null, "1.43 Load res://scenes/main_3d.tscn")
	if main_scene != null:
		var main_inst = main_scene.instantiate()
		var office_in_main = main_inst.get_node_or_null("OfficeExpansion3D")
		_assert_check(office_in_main != null, "1.44 OfficeExpansion3D instanced in main_3d.tscn")
		if office_in_main != null:
			var pos: Vector3 = office_in_main.position
			_assert_check(absf(pos.x - 19.0) < EPSILON and absf(pos.y - 0.0) < EPSILON and absf(pos.z - (-8.0)) < EPSILON,
				"1.45 Office placed at exact coordinates (19.0, 0.0, -8.0) in campus space")
		main_inst.queue_free()

	# 1.8 Proximity Simulation & Signal Contract
	_assert_check(office.is_player_in_range() == false, "1.46 is_player_in_range() initially false")
	var mock_player = CharacterBody3D.new()
	mock_player.add_to_group("player")
	root.add_child(mock_player)

	# Simulate body entered
	office._on_interaction_body_entered(mock_player)
	_assert_check(office.is_player_in_range() == true, "1.47 is_player_in_range() true after player enters trigger")
	_assert_check(prompt.visible == true, "1.48 PromptLabel3D visible when player in proximity")

	# Simulate interact
	var signal_box = {"staff_requested": false, "staff_opened": false}
	office.staff_interaction_requested.connect(func(): signal_box["staff_requested"] = true)
	office.staff_office_opened.connect(func(): signal_box["staff_opened"] = true)
	office.interact()
	_assert_check(signal_box["staff_requested"] == true, "1.49 staff_interaction_requested emitted on interact()")
	_assert_check(signal_box["staff_opened"] == true, "1.50 staff_office_opened emitted on interact()")

	# Simulate body exited
	office._on_interaction_body_exited(mock_player)
	_assert_check(office.is_player_in_range() == false, "1.51 is_player_in_range() false after player exits trigger")
	_assert_check(prompt.visible == false, "1.52 PromptLabel3D hidden after player exits proximity")

	mock_player.queue_free()
	office.queue_free()
	await process_frame

# =============================================================================
# SECTION 2: ChibiWorker3D 4-State Machine & Typing Kinematics
# =============================================================================
func _test_section_2_chibi_worker_state_machine_and_kinematics(gs: Node) -> void:
	print("\n--- SECTION 2: ChibiWorker3D 4-State Machine & Typing Kinematics ---")

	var chibi_scene = load("res://scenes/chibi_worker_3d.tscn")
	_assert_check(chibi_scene != null, "2.1 Load res://scenes/chibi_worker_3d.tscn")
	if chibi_scene == null:
		return

	var worker = chibi_scene.instantiate() as ChibiWorker3D
	_assert_check(worker != null, "2.2 ChibiWorker3D instantiates as CharacterBody3D / ChibiWorker3D")
	root.add_child(worker)
	await process_frame

	_assert_check(worker.is_in_group("chibi_workers"), "2.3 Worker in group 'chibi_workers'")
	_assert_check(worker.collision_layer == 2, "2.4 Worker collision_layer == 2 (Character Body Layer)")

	var click_area = worker.get_node_or_null("ClickArea") as Area3D
	_assert_check(click_area != null, "2.5 ClickArea (Area3D) exists for tap motivation")

	# 2.1 Worker Setup & State Machine
	var worker_data = {
		"id": "worker_alex",
		"name": "Alex Dev",
		"role": "Frontend Dev",
		"morale": 1.0,
		"fatigue": 0.0,
		"desk_assigned": 0,
		"current_state": "working",
		"desk_level": 1
	}
	worker.setup(worker_data)
	_assert_check(worker.worker_id == "worker_alex", "2.6 Worker id initialized to 'worker_alex'")
	_assert_check(worker.role == "Frontend Dev", "2.7 Worker role initialized to 'Frontend Dev'")
	_assert_check(worker.get_state() == "working", "2.8 Initial state is 'working'")

	var mood_icon = worker.get_node_or_null("MoodIcon3D") as Label3D
	var face_label = worker.get_node_or_null("ChibiRoot/Head/Visor/FaceLabel3D") as Label3D
	var zzz_particles = worker.get_node_or_null("ZzzParticles") as CPUParticles3D
	var steam_particles = worker.get_node_or_null("SteamParticles") as CPUParticles3D

	_assert_check(mood_icon != null, "2.9 MoodIcon3D (Label3D) exists")
	_assert_check(face_label != null, "2.10 FaceLabel3D (Label3D) exists on visor")
	_assert_check(zzz_particles != null, "2.11 ZzzParticles (CPUParticles3D) exists")
	_assert_check(steam_particles != null, "2.12 SteamParticles (CPUParticles3D) exists")

	# 2.2 4-State Machine Verification & Mood Icons (💻, ☕, 💡, 💤, 🎉)
	# STATE 1: WORKING
	_assert_check(worker.get_state() == "working", "2.13 STATE_WORKING active")
	_assert_check(mood_icon.text == "💻", "2.14 STATE_WORKING displays '💻' mood icon")
	_assert_check(face_label.text == "^.^", "2.15 High morale working state displays '^.^' face")
	_assert_check(zzz_particles.emitting == false, "2.16 ZzzParticles not emitting during working")
	_assert_check(steam_particles.emitting == false, "2.17 SteamParticles not emitting during working")

	# STATE 2: BREAK (COFFEE_BREAK)
	var signal_box = {"state_changed": false}
	worker.state_changed.connect(func(o, n): signal_box["state_changed"] = true)
	worker.set_state("break")
	_assert_check(signal_box["state_changed"] == true, "2.18 state_changed signal emitted on transition to 'break'")
	_assert_check(worker.get_state() == "break", "2.19 STATE_COFFEE_BREAK active")
	_assert_check(mood_icon.text == "☕", "2.20 STATE_COFFEE_BREAK displays '☕' mood icon")
	_assert_check(face_label.text == "☕", "2.21 Break state displays '☕' visor face")
	_assert_check(steam_particles.emitting == true, "2.22 SteamParticles emitting during coffee break")
	_assert_check(zzz_particles.emitting == false, "2.23 ZzzParticles not emitting during break")

	# Also test enum alias State.COFFEE_BREAK
	worker.set_state(ChibiWorker3D.State.COFFEE_BREAK)
	_assert_check(worker.get_state() == "break", "2.24 Enum State.COFFEE_BREAK sets state to 'break'")

	# STATE 3: FATIGUED
	worker.set_state("fatigued")
	_assert_check(worker.get_state() == "fatigued", "2.25 STATE_FATIGUED active")
	_assert_check(mood_icon.text == "💤", "2.26 STATE_FATIGUED displays '💤' mood icon")
	_assert_check(face_label.text == "-.-", "2.27 Fatigued state displays '-.-' tired visor face")
	_assert_check(zzz_particles.emitting == true, "2.28 ZzzParticles emitting during fatigued state")
	_assert_check(steam_particles.emitting == false, "2.29 SteamParticles not emitting during fatigued state")

	# STATE 4: CELEBRATING
	worker.set_state("celebrating")
	_assert_check(worker.get_state() == "celebrating", "2.30 STATE_CELEBRATING active")
	_assert_check(mood_icon.text == "🎉", "2.31 STATE_CELEBRATING displays '🎉' mood icon")
	_assert_check(face_label.text == "★_★", "2.32 Celebrating state displays '★_★' star-eyes face")

	# 2.3 Epiphany Breakthrough Moments & 💡 Icon
	worker.set_state("working")
	_assert_check(worker.has_epiphany() == false, "2.33 has_epiphany() initially false")
	worker.trigger_epiphany(250.0)
	_assert_check(worker.has_epiphany() == true, "2.34 has_epiphany() true after trigger_epiphany()")
	_assert_check(mood_icon.text == "💡", "2.35 Active epiphany displays '💡' lightbulb mood icon")
	_assert_check(face_label.text == "★_★", "2.36 Active epiphany displays '★_★' inspired visor face")

	var epiphany_box = {"collected": false, "reward": 0.0}
	worker.epiphany_collected.connect(func(wid, rew):
		epiphany_box["collected"] = true
		epiphany_box["reward"] = rew
	)
	worker.collect_epiphany()
	_assert_check(epiphany_box["collected"] == true, "2.37 epiphany_collected signal emitted on collect_epiphany()")
	_assert_check(absf(epiphany_box["reward"] - 250.0) < EPSILON, "2.38 Epiphany rewarded 250.0 energy")
	_assert_check(worker.has_epiphany() == false, "2.39 has_epiphany() false after collection")
	_assert_check(worker.get_state() == "celebrating", "2.40 Worker transitions to 'celebrating' on epiphany collection")
	_assert_check(mood_icon.text == "🎉", "2.41 Mood icon displays '🎉' celebration icon post-collection")

	# Epiphany cancellation guard when worker falls asleep or takes break
	worker.set_state("working")
	worker.trigger_epiphany(100.0)
	_assert_check(worker.has_epiphany() == true, "2.42 Second epiphany triggered")
	worker.set_state("fatigued")
	_assert_check(worker.has_epiphany() == false, "2.43 Epiphany safely cancelled on transition to fatigued")
	_assert_check(mood_icon.text == "💤", "2.44 Mood icon correctly displays '💤' after epiphany cancellation")

	# 2.4 Typing Kinematics & Procedural Arm Animation
	worker.set_state("working")
	worker._animate_working(0.0)
	var left_arm = worker.get_node_or_null("ChibiRoot/LeftArmPivot") as Node3D
	var right_arm = worker.get_node_or_null("ChibiRoot/RightArmPivot") as Node3D
	var head = worker.get_node_or_null("ChibiRoot/Head") as Node3D
	var torso = worker.get_node_or_null("ChibiRoot/Torso") as MeshInstance3D

	_assert_check(left_arm != null and right_arm != null, "2.45 Articulated LeftArmPivot and RightArmPivot exist")
	_assert_check(head != null and torso != null, "2.46 Head and Torso nodes exist for kinematics")

	var l_rot_0 = left_arm.rotation.x
	var r_rot_0 = right_arm.rotation.x
	worker._animate_working(0.1)
	var l_rot_1 = left_arm.rotation.x
	var r_rot_1 = right_arm.rotation.x
	_assert_check(l_rot_0 != l_rot_1, "2.47 Left arm rotates dynamically during typing animation")
	_assert_check(r_rot_0 != r_rot_1, "2.48 Right arm rotates dynamically during typing animation")
	_assert_check(signf(l_rot_1 - l_rot_0) != signf(r_rot_1 - r_rot_0), "2.49 Left and right arms swing in anti-phase alternating typing rhythm")

	# Test coffee break sipping posture
	worker._animate_coffee_break(0.0)
	_assert_check(right_arm.rotation.x < -0.70, "2.50 Right arm raised to visor (-0.85 rad) sipping coffee posture")
	_assert_check(head.rotation.x > 0.05, "2.51 Head tilted upward sipping coffee")

	# Test fatigued posture
	worker._animate_fatigued(0.0)
	_assert_check(head.rotation.x < -0.60, "2.52 Head slumped forward onto desk (-0.65 rad) during exhaustion")
	_assert_check(torso.rotation.x < -0.20, "2.53 Torso slumped forward (-0.25 rad) during exhaustion")

	# 2.5 Hyper-Focus Speed Dilation
	gs.staff_hyper_focus_active = false
	gs.staff_hyper_focus_timer = 0.0
	gs.staff_hyper_focus_remaining = 0.0

	_assert_check(absf(worker.get_animation_speed_multiplier() - 1.0) < EPSILON, "2.54 Normal animation speed multiplier is 1.00x")
	worker.set_hyper_focus(true, 60.0)
	_assert_check(absf(worker.get_animation_speed_multiplier() - 1.50) < EPSILON, "2.55 Hyper-Focus animation speed multiplier is 1.50x")
	worker.set_hyper_focus(false)
	_assert_check(absf(worker.get_animation_speed_multiplier() - 1.0) < EPSILON, "2.56 Normalized speed multiplier returns to 1.00x")

	# 2.6 5 Specialist Roles & Color Themes
	var test_roles = ["Frontend Dev", "Backend Dev", "UI/UX Designer", "Growth Hacker", "QA Engineer"]
	for r in test_roles:
		worker.set_role(r)
		_assert_check(worker.role == r, "2.57 Role set to '%s'" % r)
		var t_mat = torso.material_override as StandardMaterial3D
		_assert_check(t_mat != null, "2.58 Torso has StandardMaterial3D override for '%s'" % r)
		var expected_color = ChibiWorker3D.ROLE_COLORS.get(r)
		_assert_check(t_mat.albedo_color == expected_color, "2.59 Torso color matches '%s' theme color" % r)

	# 2.7 Morale and Fatigue Clamping & Automatic State Transitions
	worker.set_state("working")
	worker.set_morale(1.8)
	_assert_check(absf(worker.morale - 1.0) < EPSILON, "2.60 Morale clamped to maximum 1.0")
	worker.set_morale(-0.4)
	_assert_check(absf(worker.morale - 0.0) < EPSILON, "2.61 Morale clamped to minimum 0.0")
	_assert_check(face_label.text == "•_•", "2.62 Low morale working state displays '•_•' neutral face")

	worker.set_morale(1.0)
	worker.set_fatigue(0.0)
	_assert_check(worker.get_state() == "working", "2.63 Worker in working state prior to fatigue stress")
	worker.set_fatigue(1.2)
	_assert_check(absf(worker.fatigue - 1.0) < EPSILON, "2.64 Fatigue clamped to maximum 1.0")
	_assert_check(worker.get_state() == "fatigued", "2.65 Extreme fatigue (>= 1.0) automatically triggers 'fatigued' state")

	worker.set_fatigue(0.5)
	_assert_check(worker.get_state() == "working", "2.66 Reduced fatigue (< 0.8) automatically restores 'working' state")

	worker.queue_free()
	await process_frame

# =============================================================================
# SECTION 3: 3D Campus Interactive Stations
# =============================================================================
func _test_section_3_3d_campus_interactive_stations(gs: Node) -> void:
	print("\n--- SECTION 3: 3D Campus Interactive Stations ---")

	var main_scene = load("res://scenes/main_3d.tscn")
	_assert_check(main_scene != null, "3.1 Load res://scenes/main_3d.tscn")
	var main_inst: Node3D = null
	if main_scene != null:
		main_inst = main_scene.instantiate()

	# -------------------------------------------------------------------------
	# 3.1 ServerTerminal
	# -------------------------------------------------------------------------
	print("\n  -> Probing Station 1: ServerTerminal")
	var server_scene = load("res://scenes/server_terminal.tscn")
	_assert_check(server_scene != null, "3.2 Load res://scenes/server_terminal.tscn")
	if server_scene != null:
		var server = server_scene.instantiate() as ServerTerminal
		_assert_check(server != null, "3.3 ServerTerminal instantiates as ServerTerminal / StaticBody3D")
		root.add_child(server)
		await process_frame

		_assert_check(server.is_in_group("terminals"), "3.4 ServerTerminal in group 'terminals'")
		_assert_check(server.is_in_group("server_terminals"), "3.5 ServerTerminal in group 'server_terminals'")
		_assert_check(server.is_in_group("interactables"), "3.6 ServerTerminal in group 'interactables'")

		var area = server.get_node_or_null("InteractionArea") as Area3D
		var prompt = server.get_node_or_null("PromptLabel3D") as Label3D
		var status = server.get_node_or_null("StatusLabel3D") as Label3D
		_assert_check(area != null, "3.7 ServerTerminal has InteractionArea")
		_assert_check(prompt != null, "3.8 ServerTerminal has PromptLabel3D")
		_assert_check(status != null, "3.9 ServerTerminal has StatusLabel3D")
		_assert_check(server.action_label == "Hack [E]" or server.action_label == "Overclock [E]",
			"3.10 ServerTerminal action_label is 'Hack [E]' or 'Overclock [E]'")

		_assert_check(absf(server.overclock_duration - 25.0) < EPSILON, "3.11 Normal overclock duration is 25.0s")
		_assert_check(absf(server.perfect_overclock_duration - 45.0) < EPSILON, "3.12 Perfect overclock duration is 45.0s")
		_assert_check(absf(server.overclock_cooldown - 60.0) < EPSILON, "3.13 Overclock cooldown is 60.0s")

		if main_inst != null:
			var s_node = main_inst.get_node_or_null("ServerTerminal")
			_assert_check(s_node != null, "3.14 ServerTerminal instanced in main_3d.tscn")
			if s_node != null:
				_assert_check(absf(s_node.position.x - 0.0) < EPSILON and absf(s_node.position.z - (-18.0)) < EPSILON,
					"3.15 ServerTerminal coordinates at (0.0, 0.0, -18.0)")

		server.queue_free()

	# -------------------------------------------------------------------------
	# 3.2 PitchStage
	# -------------------------------------------------------------------------
	print("\n  -> Probing Station 2: PitchStage")
	var pitch_scene = load("res://scenes/pitch_stage.tscn")
	_assert_check(pitch_scene != null, "3.16 Load res://scenes/pitch_stage.tscn")
	if pitch_scene != null:
		var pitch = pitch_scene.instantiate() as PitchStage
		_assert_check(pitch != null, "3.17 PitchStage instantiates as PitchStage / StaticBody3D")
		root.add_child(pitch)
		await process_frame

		_assert_check(pitch.is_in_group("stages"), "3.18 PitchStage in group 'stages'")
		_assert_check(pitch.is_in_group("pitch_stages"), "3.19 PitchStage in group 'pitch_stages'")
		_assert_check(pitch.is_in_group("interactables"), "3.20 PitchStage in group 'interactables'")

		var p_area = pitch.get_node_or_null("InteractionArea") as Area3D
		var p_prompt = pitch.get_node_or_null("PromptLabel3D") as Label3D
		var p_investor = pitch.get_node_or_null("Visuals/ChibiAngelInvestor")
		var p_spotlight = pitch.get_node_or_null("Visuals/StageSpotlight")
		var p_confetti = pitch.get_node_or_null("Visuals/ConfettiExplosion")
		_assert_check(p_area != null, "3.21 PitchStage has InteractionArea")
		_assert_check(p_prompt != null, "3.22 PitchStage has PromptLabel3D")
		_assert_check(p_investor != null, "3.23 PitchStage has ChibiAngelInvestor NPC")
		_assert_check(p_spotlight != null, "3.24 PitchStage has StageSpotlight")
		_assert_check(p_confetti != null, "3.25 PitchStage has ConfettiExplosion particles")
		_assert_check(pitch.action_label == "Pitch [E]", "3.26 PitchStage action_label is 'Pitch [E]'")
		_assert_check(absf(pitch.min_grant - 1000.0) < EPSILON, "3.27 Pitch min grant is 1,000 energy")
		_assert_check(absf(pitch.max_grant - 5000.0) < EPSILON, "3.28 Pitch max grant is 5,000 energy")

		if main_inst != null:
			var p_node = main_inst.get_node_or_null("PitchStage")
			_assert_check(p_node != null, "3.29 PitchStage instanced in main_3d.tscn")
			if p_node != null:
				_assert_check(absf(p_node.position.x - 0.0) < EPSILON and absf(p_node.position.z - 18.0) < EPSILON,
					"3.30 PitchStage coordinates at (0.0, 0.0, 18.0)")

		pitch.queue_free()

	# -------------------------------------------------------------------------
	# 3.3 CoffeeMachine3D
	# -------------------------------------------------------------------------
	print("\n  -> Probing Station 3: CoffeeMachine3D")
	var coffee_scene = load("res://scenes/coffee_machine_3d.tscn")
	_assert_check(coffee_scene != null, "3.31 Load res://scenes/coffee_machine_3d.tscn")
	if coffee_scene != null:
		var coffee = coffee_scene.instantiate() as CoffeeMachine3D
		_assert_check(coffee != null, "3.32 CoffeeMachine3D instantiates as CoffeeMachine3D / StaticBody3D")
		root.add_child(coffee)
		await process_frame

		_assert_check(coffee.is_in_group("coffee_machines"), "3.33 CoffeeMachine3D in group 'coffee_machines'")
		_assert_check(coffee.is_in_group("stations"), "3.34 CoffeeMachine3D in group 'stations'")
		_assert_check(coffee.is_in_group("interactables"), "3.35 CoffeeMachine3D in group 'interactables'")

		var c_area = coffee.get_node_or_null("InteractionArea") as Area3D
		var c_prompt = coffee.get_node_or_null("PromptLabel3D") as Label3D
		var c_steam = coffee.get_node_or_null("Visuals/SteamParticles") as CPUParticles3D
		var c_gauge = coffee.get_node_or_null("Visuals/PressureGauge/NeedleRoot")
		_assert_check(c_area != null, "3.36 CoffeeMachine3D has InteractionArea")
		_assert_check(c_prompt != null, "3.37 CoffeeMachine3D has PromptLabel3D")
		_assert_check(c_steam != null, "3.38 CoffeeMachine3D has SteamParticles")
		_assert_check(c_gauge != null, "3.39 CoffeeMachine3D has PressureGauge needle")
		_assert_check(coffee.action_label == "Brew [E]", "3.40 CoffeeMachine3D action_label is 'Brew [E]'")
		_assert_check(absf(coffee.avatar_speed_boost - 1.50) < EPSILON, "3.41 Unicorn Espresso avatar boost is 1.50x")
		_assert_check(absf(coffee.worker_speed_boost - 1.20) < EPSILON, "3.42 Unicorn Espresso worker boost is 1.20x")
		_assert_check(absf(coffee.buff_duration - 60.0) < EPSILON, "3.43 Unicorn Espresso duration is 60.0s")

		if main_inst != null:
			var c_node = main_inst.get_node_or_null("CoffeeMachine3D")
			_assert_check(c_node != null, "3.44 CoffeeMachine3D instanced in main_3d.tscn")
			if c_node != null:
				_assert_check(absf(c_node.position.x - (-19.0)) < EPSILON and absf(c_node.position.z - 4.0) < EPSILON,
					"3.45 CoffeeMachine3D coordinates at (-19.0, 0.0, 4.0)")

		coffee.queue_free()

	# -------------------------------------------------------------------------
	# 3.4 IpoBell3D
	# -------------------------------------------------------------------------
	print("\n  -> Probing Station 4: IpoBell3D")
	var bell_scene = load("res://scenes/ipo_bell_3d.tscn")
	_assert_check(bell_scene != null, "3.46 Load res://scenes/ipo_bell_3d.tscn")
	if bell_scene != null:
		var bell = bell_scene.instantiate() as IpoBell3D
		_assert_check(bell != null, "3.47 IpoBell3D instantiates as IpoBell3D / StaticBody3D")
		root.add_child(bell)
		await process_frame

		_assert_check(bell.is_in_group("ipo_bells"), "3.48 IpoBell3D in group 'ipo_bells'")
		_assert_check(bell.is_in_group("stations"), "3.49 IpoBell3D in group 'stations'")
		_assert_check(bell.is_in_group("interactables"), "3.50 IpoBell3D in group 'interactables'")

		var b_area = bell.get_node_or_null("InteractionArea") as Area3D
		var b_prompt = bell.get_node_or_null("PromptLabel3D") as Label3D
		var b_pivot = bell.get_node_or_null("Visuals/BellPivot")
		var b_gold = bell.get_node_or_null("GoldParticles")
		_assert_check(b_area != null, "3.51 IpoBell3D has InteractionArea")
		_assert_check(b_prompt != null, "3.52 IpoBell3D has PromptLabel3D")
		_assert_check(b_pivot != null, "3.53 IpoBell3D has BellPivot node")
		_assert_check(b_gold != null, "3.54 IpoBell3D has GoldParticles")
		_assert_check(bell.action_label == "IPO Bell [E]", "3.55 IpoBell3D action_label is 'IPO Bell [E]'")
		_assert_check(absf(bell.swing_angle_max - 24.0) < EPSILON, "3.56 Bell max swing angle is 24.0 degrees")

		if main_inst != null:
			var b_node = main_inst.get_node_or_null("IpoBell3D")
			_assert_check(b_node != null, "3.57 IpoBell3D instanced in main_3d.tscn")
			if b_node != null:
				_assert_check(absf(b_node.position.x - 0.0) < EPSILON and absf(b_node.position.z - 12.0) < EPSILON,
					"3.58 IpoBell3D coordinates at (0.0, 0.0, 12.0)")

		bell.queue_free()

	# -------------------------------------------------------------------------
	# 3.5 TrophyShowcase3D
	# -------------------------------------------------------------------------
	print("\n  -> Probing Station 5: TrophyShowcase3D")
	var trophy_scene = load("res://scenes/trophy_showcase_3d.tscn")
	_assert_check(trophy_scene != null, "3.59 Load res://scenes/trophy_showcase_3d.tscn")
	if trophy_scene != null:
		var trophy = trophy_scene.instantiate() as TrophyShowcase3D
		_assert_check(trophy != null, "3.60 TrophyShowcase3D instantiates as TrophyShowcase3D / StaticBody3D")
		root.add_child(trophy)
		await process_frame

		_assert_check(trophy.is_in_group("trophy_showcase"), "3.61 TrophyShowcase3D in group 'trophy_showcase'")
		_assert_check(trophy.is_in_group("interactables"), "3.62 TrophyShowcase3D in group 'interactables'")

		var t_area = trophy.get_node_or_null("InteractionArea") as Area3D
		var t_prompt = trophy.get_node_or_null("PromptLabel3D") as Label3D
		_assert_check(t_area != null, "3.63 TrophyShowcase3D has InteractionArea")
		_assert_check(t_prompt != null, "3.64 TrophyShowcase3D has PromptLabel3D")
		_assert_check(trophy.action_label == "Showcase [E]", "3.65 TrophyShowcase3D action_label is 'Showcase [E]'")

		var p_brief = trophy.get_node_or_null("Visuals/Pedestals/Pedestal_Briefcase/TrophyMount")
		var p_server = trophy.get_node_or_null("Visuals/Pedestals/Pedestal_Server/TrophyMount")
		var p_chalice = trophy.get_node_or_null("Visuals/Pedestals/Pedestal_Chalice/TrophyMount")
		var p_bull = trophy.get_node_or_null("Visuals/Pedestals/Pedestal_Bull/TrophyMount")
		_assert_check(p_brief != null, "3.66 Golden Briefcase pedestal mount exists")
		_assert_check(p_server != null, "3.67 Matrix Server Plaque pedestal mount exists")
		_assert_check(p_chalice != null, "3.68 Crystal Chalice pedestal mount exists")
		_assert_check(p_bull != null, "3.69 Platinum Bull pedestal mount exists")

		if main_inst != null:
			var t_node = main_inst.get_node_or_null("TrophyShowcase3D")
			_assert_check(t_node != null, "3.70 TrophyShowcase3D instanced in main_3d.tscn")
			if t_node != null:
				_assert_check(absf(t_node.position.x - 6.0) < EPSILON and absf(t_node.position.z - 12.0) < EPSILON,
					"3.71 TrophyShowcase3D coordinates at (6.0, 0.0, 12.0)")

		trophy.queue_free()

	# -------------------------------------------------------------------------
	# 3.6 DailyBoard3D
	# -------------------------------------------------------------------------
	print("\n  -> Probing Station 6: DailyBoard3D")
	var board_scene = load("res://scenes/daily_board_3d.tscn")
	_assert_check(board_scene != null, "3.72 Load res://scenes/daily_board_3d.tscn")
	if board_scene != null:
		var board = board_scene.instantiate() as DailyBoard3D
		_assert_check(board != null, "3.73 DailyBoard3D instantiates as DailyBoard3D / StaticBody3D")
		root.add_child(board)
		await process_frame

		_assert_check(board.is_in_group("daily_boards"), "3.74 DailyBoard3D in group 'daily_boards'")
		_assert_check(board.is_in_group("stations"), "3.75 DailyBoard3D in group 'stations'")
		_assert_check(board.is_in_group("interactables"), "3.76 DailyBoard3D in group 'interactables'")

		var db_area = board.get_node_or_null("InteractionArea") as Area3D
		var db_prompt = board.get_node_or_null("PromptLabel3D") as Label3D
		_assert_check(db_area != null, "3.77 DailyBoard3D has InteractionArea")
		_assert_check(db_prompt != null, "3.78 DailyBoard3D has PromptLabel3D")
		_assert_check(board.action_label == "Daily Board [E]", "3.79 DailyBoard3D action_label is 'Daily Board [E]'")

		if main_inst != null:
			var db_node = main_inst.get_node_or_null("DailyBoard3D")
			_assert_check(db_node != null, "3.80 DailyBoard3D instanced in main_3d.tscn")
			if db_node != null:
				_assert_check(absf(db_node.position.x - 3.0) < EPSILON and absf(db_node.position.z - 8.0) < EPSILON,
					"3.81 DailyBoard3D coordinates at (3.0, 0.0, 8.0)")

		board.queue_free()

	# -------------------------------------------------------------------------
	# 3.7 TechLabTerminal
	# -------------------------------------------------------------------------
	print("\n  -> Probing Station 7: TechLabTerminal")
	var tech_scene = load("res://scenes/tech_lab_terminal.tscn")
	_assert_check(tech_scene != null, "3.82 Load res://scenes/tech_lab_terminal.tscn")
	if tech_scene != null:
		var tech = tech_scene.instantiate() as TechLabTerminal
		_assert_check(tech != null, "3.83 TechLabTerminal instantiates as TechLabTerminal / StaticBody3D")
		root.add_child(tech)
		await process_frame

		_assert_check(tech.is_in_group("terminals"), "3.84 TechLabTerminal in group 'terminals'")
		_assert_check(tech.is_in_group("research_terminals"), "3.85 TechLabTerminal in group 'research_terminals'")

		var tech_area = tech.get_node_or_null("InteractionArea") as Area3D
		var tech_prompt = tech.get_node_or_null("PromptLabel3D") as Label3D
		var tech_holo = tech.get_node_or_null("Visuals/RotatingHologram")
		_assert_check(tech_area != null, "3.86 TechLabTerminal has InteractionArea")
		_assert_check(tech_prompt != null, "3.87 TechLabTerminal has PromptLabel3D")
		_assert_check(tech_holo != null, "3.88 TechLabTerminal has RotatingHologram")
		_assert_check(absf(tech.hologram_spin_speed - 1.8) < EPSILON, "3.89 Hologram spin speed is 1.8 rad/s")

		if main_inst != null:
			var tech_node = main_inst.get_node_or_null("TechLabTerminal")
			_assert_check(tech_node != null, "3.90 TechLabTerminal instanced in main_3d.tscn")
			if tech_node != null:
				_assert_check(absf(tech_node.position.x - (-19.0)) < EPSILON and absf(tech_node.position.z - 0.0) < EPSILON,
					"3.91 TechLabTerminal coordinates at (-19.0, 0.0, 0.0)")

		tech.queue_free()

	# -------------------------------------------------------------------------
	# 3.8 SyndicateHQ3D
	# -------------------------------------------------------------------------
	print("\n  -> Probing Station 8: SyndicateHQ3D")
	var syn_scene = load("res://scenes/syndicate_hq_3d.tscn")
	_assert_check(syn_scene != null, "3.92 Load res://scenes/syndicate_hq_3d.tscn")
	if syn_scene != null:
		var syn = syn_scene.instantiate() as SyndicateHQ3D
		_assert_check(syn != null, "3.93 SyndicateHQ3D instantiates as SyndicateHQ3D / StaticBody3D")
		root.add_child(syn)
		await process_frame

		_assert_check(syn.is_in_group("syndicate_hqs"), "3.94 SyndicateHQ3D in group 'syndicate_hqs'")
		_assert_check(syn.is_in_group("stations"), "3.95 SyndicateHQ3D in group 'stations'")
		_assert_check(syn.is_in_group("interactables"), "3.96 SyndicateHQ3D in group 'interactables'")

		var syn_area = syn.get_node_or_null("InteractionArea") as Area3D
		var syn_prompt = syn.get_node_or_null("PromptLabel3D") as Label3D
		var syn_globe = syn.get_node_or_null("Visuals/ConferenceTable/HolographicGlobe")
		var syn_screen = syn.get_node_or_null("Visuals/ProjectionScreen/ScreenDataLabel")
		_assert_check(syn_area != null, "3.97 SyndicateHQ3D has InteractionArea")
		_assert_check(syn_prompt != null, "3.98 SyndicateHQ3D has PromptLabel3D")
		_assert_check(syn_globe != null, "3.99 SyndicateHQ3D has HolographicGlobe")
		_assert_check(syn_screen != null, "3.100 SyndicateHQ3D has ProjectionScreen data label")
		_assert_check(syn.action_label == "Syndicate [E]", "3.101 SyndicateHQ3D action_label is 'Syndicate [E]'")

		if main_inst != null:
			var syn_node = main_inst.get_node_or_null("SyndicateHQ3D")
			_assert_check(syn_node != null, "3.102 SyndicateHQ3D instanced in main_3d.tscn")
			if syn_node != null:
				_assert_check(absf(syn_node.position.x - 12.0) < EPSILON and absf(syn_node.position.z - 0.0) < EPSILON,
					"3.103 SyndicateHQ3D coordinates at (12.0, 0.0, 0.0)")

		syn.queue_free()

	if main_inst != null:
		main_inst.free()
	await process_frame

# =============================================================================
# Helper function for Section 4: Triangle calculations
# =============================================================================
func _calculate_mesh_triangles(mesh: Mesh) -> int:
	if mesh == null:
		return 0

	# Calculate pure topology directly from primitive properties
	if mesh is BoxMesh:
		var bm = mesh as BoxMesh
		var sw = bm.subdivide_width
		var sh = bm.subdivide_height
		var sd = bm.subdivide_depth
		return (2 * (sw + 1) * (sh + 1) + 2 * (sw + 1) * (sd + 1) + 2 * (sh + 1) * (sd + 1)) * 2
	elif mesh is CylinderMesh:
		var cm = mesh as CylinderMesh
		var rad = cm.radial_segments
		var rings = cm.rings
		var side = rad * rings * 2
		var top = rad if cm.cap_top else 0
		var bot = rad if cm.cap_bottom else 0
		return side + top + bot
	elif mesh is SphereMesh:
		var sm = mesh as SphereMesh
		var rad = sm.radial_segments
		var rings = sm.rings
		var side = rad * rings * 2
		var cap = rad if sm.is_hemisphere else 0
		return side + cap
	elif mesh is PrismMesh:
		return 8
	elif mesh is TorusMesh:
		var tm = mesh as TorusMesh
		return tm.rings * tm.ring_segments * 2
	elif mesh is CapsuleMesh:
		var cap = mesh as CapsuleMesh
		return cap.radial_segments * cap.rings * 2
	elif mesh is PlaneMesh:
		var pm = mesh as PlaneMesh
		return (pm.subdivide_width + 1) * (pm.subdivide_depth + 1) * 2
	elif mesh is QuadMesh:
		return 2

	return 0

func _calculate_node_tree_triangles(node: Node) -> int:
	var total = 0
	if node is MeshInstance3D and node.mesh != null:
		total += _calculate_mesh_triangles(node.mesh)
	for child in node.get_children():
		total += _calculate_node_tree_triangles(child)
	return total

# =============================================================================
# SECTION 4: Low-Poly Triangle Budget Certification
# =============================================================================
func _test_section_4_low_poly_triangle_budget_certification() -> void:
	print("\n--- SECTION 4: Low-Poly Triangle Budget Certification ---")

	# Station triangle ceiling: < 2,500 triangles
	const MAX_STATION_TRIANGLES: int = 2500
	# Worker triangle ceiling: < 600 triangles
	const MAX_WORKER_TRIANGLES: int = 600

	# 4.1 ChibiWorker3D Budget (< 600 triangles)
	var worker_scene = load("res://scenes/chibi_worker_3d.tscn")
	_assert_check(worker_scene != null, "4.1 Load res://scenes/chibi_worker_3d.tscn for mesh certification")
	if worker_scene != null:
		var worker_inst = worker_scene.instantiate()
		var worker_tris = _calculate_node_tree_triangles(worker_inst)
		_assert_check(worker_tris > 0, "4.2 ChibiWorker3D contains non-zero static geometry (%d tris)" % worker_tris)
		_assert_check(worker_tris < MAX_WORKER_TRIANGLES,
			"4.3 ChibiWorker3D certified under < 600 tris budget (actual: %d tris, margin: %d tris)" % [
				worker_tris, MAX_WORKER_TRIANGLES - worker_tris
			])
		worker_inst.free()

	# 4.2 OfficeExpansion3D Base Budget (< 2,500 triangles)
	var office_scene = load("res://scenes/office_expansion_3d.tscn")
	_assert_check(office_scene != null, "4.4 Load res://scenes/office_expansion_3d.tscn for mesh certification")
	if office_scene != null:
		var office_inst = office_scene.instantiate() as OfficeExpansion3D
		root.add_child(office_inst)
		var office_base_tris = _calculate_node_tree_triangles(office_inst)
		_assert_check(office_base_tris > 0, "4.5 OfficeExpansion3D base contains geometry (%d tris)" % office_base_tris)
		_assert_check(office_base_tris < MAX_STATION_TRIANGLES,
			"4.6 OfficeExpansion3D base certified under < 2,500 tris budget (actual: %d tris)" % office_base_tris)

		# Combined Office + 5 Spawned Workers
		for i in range(5):
			office_inst.spawn_worker({"id": "w_%d" % i, "role": "Frontend Dev", "desk_assigned": i})
		var combined_office_tris = _calculate_node_tree_triangles(office_inst)
		_assert_check(combined_office_tris < MAX_STATION_TRIANGLES,
			"4.7 Full Office with 5 Workers combined certified under < 2,500 tris budget (actual: %d tris)" % combined_office_tris)
		office_inst.queue_free()

	# 4.3 ServerTerminal Budget (< 2,500 triangles)
	var server_scene = load("res://scenes/server_terminal.tscn")
	if server_scene != null:
		var server_inst = server_scene.instantiate()
		var server_tris = _calculate_node_tree_triangles(server_inst)
		_assert_check(server_tris > 0, "4.8 ServerTerminal contains geometry (%d tris)" % server_tris)
		_assert_check(server_tris < MAX_STATION_TRIANGLES,
			"4.9 ServerTerminal certified under < 2,500 tris budget (actual: %d tris)" % server_tris)
		server_inst.free()

	# 4.4 PitchStage Budget (< 2,500 triangles)
	var pitch_scene = load("res://scenes/pitch_stage.tscn")
	if pitch_scene != null:
		var pitch_inst = pitch_scene.instantiate()
		var pitch_tris = _calculate_node_tree_triangles(pitch_inst)
		_assert_check(pitch_tris > 0, "4.10 PitchStage contains geometry (%d tris)" % pitch_tris)
		_assert_check(pitch_tris < MAX_STATION_TRIANGLES,
			"4.11 PitchStage certified under < 2,500 tris budget (actual: %d tris)" % pitch_tris)
		pitch_inst.free()

	# 4.5 CoffeeMachine3D Budget (< 2,500 triangles)
	var coffee_scene = load("res://scenes/coffee_machine_3d.tscn")
	if coffee_scene != null:
		var coffee_inst = coffee_scene.instantiate()
		var coffee_tris = _calculate_node_tree_triangles(coffee_inst)
		_assert_check(coffee_tris > 0, "4.12 CoffeeMachine3D contains geometry (%d tris)" % coffee_tris)
		_assert_check(coffee_tris < MAX_STATION_TRIANGLES,
			"4.13 CoffeeMachine3D certified under < 2,500 tris budget (actual: %d tris)" % coffee_tris)
		coffee_inst.free()

	# 4.6 IpoBell3D Budget (< 2,500 triangles)
	var bell_scene = load("res://scenes/ipo_bell_3d.tscn")
	if bell_scene != null:
		var bell_inst = bell_scene.instantiate()
		var bell_tris = _calculate_node_tree_triangles(bell_inst)
		_assert_check(bell_tris > 0, "4.14 IpoBell3D contains geometry (%d tris)" % bell_tris)
		_assert_check(bell_tris < MAX_STATION_TRIANGLES,
			"4.15 IpoBell3D certified under < 2,500 tris budget (actual: %d tris)" % bell_tris)
		bell_inst.free()

	# 4.7 TrophyShowcase3D Budget (< 2,500 triangles)
	var trophy_scene = load("res://scenes/trophy_showcase_3d.tscn")
	if trophy_scene != null:
		var trophy_inst = trophy_scene.instantiate()
		var trophy_tris = _calculate_node_tree_triangles(trophy_inst)
		_assert_check(trophy_tris > 0, "4.16 TrophyShowcase3D contains geometry (%d tris)" % trophy_tris)
		_assert_check(trophy_tris < MAX_STATION_TRIANGLES,
			"4.17 TrophyShowcase3D certified under < 2,500 tris budget (actual: %d tris)" % trophy_tris)
		trophy_inst.free()

	# 4.8 DailyBoard3D Budget (< 2,500 triangles)
	var board_scene = load("res://scenes/daily_board_3d.tscn")
	if board_scene != null:
		var board_inst = board_scene.instantiate()
		var board_tris = _calculate_node_tree_triangles(board_inst)
		_assert_check(board_tris > 0, "4.18 DailyBoard3D contains geometry (%d tris)" % board_tris)
		_assert_check(board_tris < MAX_STATION_TRIANGLES,
			"4.19 DailyBoard3D certified under < 2,500 tris budget (actual: %d tris)" % board_tris)
		board_inst.free()

	# 4.9 TechLabTerminal Budget (< 2,500 triangles)
	var tech_scene = load("res://scenes/tech_lab_terminal.tscn")
	if tech_scene != null:
		var tech_inst = tech_scene.instantiate()
		var tech_tris = _calculate_node_tree_triangles(tech_inst)
		_assert_check(tech_tris > 0, "4.20 TechLabTerminal contains geometry (%d tris)" % tech_tris)
		_assert_check(tech_tris < MAX_STATION_TRIANGLES,
			"4.21 TechLabTerminal certified under < 2,500 tris budget (actual: %d tris)" % tech_tris)
		tech_inst.free()

	# 4.10 SyndicateHQ3D Budget (< 2,500 triangles)
	var syn_scene = load("res://scenes/syndicate_hq_3d.tscn")
	if syn_scene != null:
		var syn_inst = syn_scene.instantiate()
		var syn_tris = _calculate_node_tree_triangles(syn_inst)
		_assert_check(syn_tris > 0, "4.22 SyndicateHQ3D contains geometry (%d tris)" % syn_tris)
		_assert_check(syn_tris < MAX_STATION_TRIANGLES,
			"4.23 SyndicateHQ3D certified under < 2,500 tris budget (actual: %d tris)" % syn_tris)
		syn_inst.free()

	await process_frame

# =============================================================================
# SECTION 5: Dynamic TouchControls Registration & Proximity Stacking
# =============================================================================
func _test_section_5_dynamic_touch_controls_and_proximity_stacking() -> void:
	print("\n--- SECTION 5: Dynamic TouchControls Registration & Proximity Stacking ---")

	var tc_scene = load("res://scenes/ui/touch_controls.tscn")
	_assert_check(tc_scene != null, "5.1 Load res://scenes/ui/touch_controls.tscn")
	if tc_scene == null:
		return

	var tc = tc_scene.instantiate() as TouchControls
	_assert_check(tc != null, "5.2 TouchControls instantiates as Control / TouchControls")
	root.add_child(tc)
	await process_frame

	# 5.1 Basic Properties & Dimensions
	_assert_check(tc.is_in_group("touch_controls"), "5.3 TouchControls in group 'touch_controls'")
	_assert_check(tc.mouse_filter == Control.MOUSE_FILTER_IGNORE, "5.4 Tier 3 Isolation: Root TouchControls has mouse_filter == IGNORE (2)")

	var act_btn = tc.get_node_or_null("%ActionButton") if tc.has_node("%ActionButton") else tc.get_node_or_null("ActionButton")
	var laptop_btn = tc.get_node_or_null("%LaptopThumbButton") if tc.has_node("%LaptopThumbButton") else tc.get_node_or_null("LaptopThumbButton")
	var campus_btn = tc.get_node_or_null("%CampusThumbButton") if tc.has_node("%CampusThumbButton") else tc.get_node_or_null("CampusThumbButton")

	_assert_check(act_btn != null, "5.5 ActionButton exists in TouchControls")
	_assert_check(act_btn.mouse_filter == Control.MOUSE_FILTER_STOP, "5.6 Tier 1 Isolation: ActionButton has mouse_filter == STOP (0)")
	_assert_check(act_btn.custom_minimum_size.x >= 100.0 and act_btn.custom_minimum_size.y >= 100.0,
		"5.7 ActionButton meets or exceeds 100x100px touch envelope")

	_assert_check(laptop_btn != null, "5.8 LaptopThumbButton exists in TouchControls")
	_assert_check(laptop_btn.mouse_filter == Control.MOUSE_FILTER_STOP, "5.9 LaptopThumbButton has mouse_filter == STOP (0)")
	_assert_check(laptop_btn.custom_minimum_size.x >= 70.0 and laptop_btn.custom_minimum_size.y >= 70.0,
		"5.10 LaptopThumbButton meets 70x70px touch envelope")

	_assert_check(campus_btn != null, "5.11 CampusThumbButton exists in TouchControls")
	_assert_check(campus_btn.mouse_filter == Control.MOUSE_FILTER_STOP, "5.12 CampusThumbButton has mouse_filter == STOP (0)")
	_assert_check(campus_btn.custom_minimum_size.x >= 70.0 and campus_btn.custom_minimum_size.y >= 70.0,
		"5.13 CampusThumbButton meets 70x70px touch envelope")

	# Initial Dormant state
	_assert_check(tc.active_interactable == null, "5.14 active_interactable is initially null")
	_assert_check(act_btn.text == "[E] Action", "5.15 Dormant action button text is '[E] Action'")
	_assert_check(absf(act_btn.modulate.a - tc.dormant_opacity) < EPSILON, "5.16 ActionButton has dormant opacity (0.35)")

	# 5.2 Contextual Registration for All 8 Station Types
	var stations_to_test = [
		{"group": "staff_offices", "label": "Staff [E]"},
		{"group": "server_terminals", "label": "Hack [E]"},
		{"group": "pitch_stages", "label": "Pitch [E]"},
		{"group": "coffee_machines", "label": "Brew [E]"},
		{"group": "ipo_bells", "label": "IPO Bell [E]"},
		{"group": "trophy_showcase", "label": "Showcase [E]"},
		{"group": "daily_boards", "label": "Daily Board [E]"},
		{"group": "research_terminals", "label": "Research [E]"},
		{"group": "syndicate_hqs", "label": "Syndicate [E]"}
	]

	var tracker = {"reg": false, "chg": false, "unreg": false}
	tc.interactable_registered.connect(func(n, l): tracker["reg"] = true)
	tc.interactable_changed.connect(func(n): tracker["chg"] = true)
	tc.interactable_unregistered.connect(func(n): tracker["unreg"] = true)

	for entry in stations_to_test:
		var mock_node = StaticBody3D.new()
		mock_node.add_to_group(entry["group"])
		mock_node.set("action_label", entry["label"])

		tracker["reg"] = false
		tracker["chg"] = false
		tc.register_interactable(mock_node, entry["label"])

		_assert_check(tracker["reg"] == true, "5.17 interactable_registered emitted for '%s'" % entry["label"])
		_assert_check(tracker["chg"] == true, "5.18 interactable_changed emitted for '%s'" % entry["label"])
		_assert_check(tc.active_interactable == mock_node, "5.19 active_interactable set to node for '%s'" % entry["label"])
		_assert_check(act_btn.text == entry["label"], "5.20 ActionButton label correctly set to '%s'" % entry["label"])
		_assert_check(absf(act_btn.modulate.a - tc.active_opacity) < EPSILON, "5.21 ActionButton has active opacity (1.0) for '%s'" % entry["label"])

		tracker["unreg"] = false
		tc.unregister_interactable(mock_node)
		_assert_check(tracker["unreg"] == true, "5.22 interactable_unregistered emitted for '%s'" % entry["label"])
		_assert_check(tc.active_interactable == null, "5.23 active_interactable cleared after unregistering '%s'" % entry["label"])
		_assert_check(act_btn.text == "[E] Action", "5.24 ActionButton label reverted to '[E] Action'")
		mock_node.free()

	# 5.3 Proximity Stacking (LIFO Unwinding)
	var node_a = StaticBody3D.new()
	node_a.add_to_group("staff_offices")
	node_a.set("action_label", "Staff [E]")

	var node_b = StaticBody3D.new()
	node_b.add_to_group("coffee_machines")
	node_b.set("action_label", "Brew [E]")

	var node_c = StaticBody3D.new()
	node_c.add_to_group("server_terminals")
	node_c.set("action_label", "Hack [E]")

	tc.register_interactable(node_a, "Staff [E]")
	_assert_check(tc.active_interactables.size() == 1, "5.25 Stack size 1 after pushing node_a")
	_assert_check(tc.active_interactable == node_a, "5.26 Active interactable is node_a")
	_assert_check(act_btn.text == "Staff [E]", "5.27 ActionButton shows node_a label 'Staff [E]'")

	tc.register_interactable(node_b, "Brew [E]")
	_assert_check(tc.active_interactables.size() == 2, "5.28 Stack size 2 after pushing node_b")
	_assert_check(tc.active_interactable == node_b, "5.29 Active interactable updated to node_b")
	_assert_check(act_btn.text == "Brew [E]", "5.30 ActionButton shows node_b label 'Brew [E]'")

	tc.register_interactable(node_c, "Hack [E]")
	_assert_check(tc.active_interactables.size() == 3, "5.31 Stack size 3 after pushing node_c")
	_assert_check(tc.active_interactable == node_c, "5.32 Active interactable updated to node_c")
	_assert_check(act_btn.text == "Hack [E]", "5.33 ActionButton shows node_c label 'Hack [E]'")

	# Unwind top node_c -> stack falls back to node_b
	tc.unregister_interactable(node_c)
	_assert_check(tc.active_interactables.size() == 2, "5.34 Stack size 2 after unregistering node_c")
	_assert_check(tc.active_interactable == node_b, "5.35 Active interactable unwound back to node_b")
	_assert_check(act_btn.text == "Brew [E]", "5.36 ActionButton label restored to node_b 'Brew [E]'")

	# Unwind top node_b -> stack falls back to node_a
	tc.unregister_interactable(node_b)
	_assert_check(tc.active_interactables.size() == 1, "5.37 Stack size 1 after unregistering node_b")
	_assert_check(tc.active_interactable == node_a, "5.38 Active interactable unwound back to node_a")
	_assert_check(act_btn.text == "Staff [E]", "5.39 ActionButton label restored to node_a 'Staff [E]'")

	# Unwind final node_a -> stack empty
	tc.unregister_interactable(node_a)
	_assert_check(tc.active_interactables.is_empty(), "5.40 Stack is empty after unregistering all nodes")
	_assert_check(tc.active_interactable == null, "5.41 Active interactable is null")
	_assert_check(act_btn.text == "[E] Action", "5.42 ActionButton restored to default dormant text")

	# 5.4 Non-LIFO Arbitrary Middle Node Unregistration
	tc.register_interactable(node_a, "Staff [E]")
	tc.register_interactable(node_b, "Brew [E]")
	tc.register_interactable(node_c, "Hack [E]")

	tc.unregister_interactable(node_b)
	_assert_check(tc.active_interactables.size() == 2, "5.43 Stack size is 2 after erasing middle node_b")
	_assert_check(tc.active_interactable == node_c, "5.44 Active interactable remains node_c (top unaffected)")
	_assert_check(act_btn.text == "Hack [E]", "5.45 ActionButton label remains 'Hack [E]'")

	tc.unregister_interactable(node_c)
	_assert_check(tc.active_interactable == node_a, "5.46 Active interactable falls back directly to node_a")
	_assert_check(act_btn.text == "Staff [E]", "5.47 ActionButton label restored to node_a 'Staff [E]'")

	tc.unregister_interactable(node_a)

	# 5.5 Action Triggering Execution
	var action_box = {"action_triggered": false}
	tc.action_triggered.connect(func(target): action_box["action_triggered"] = true)
	tc.register_interactable(node_a, "Staff [E]")
	tc.trigger_action()
	_assert_check(action_box["action_triggered"] == true, "5.48 action_triggered emitted on trigger_action()")

	tc.unregister_interactable(node_a)
	node_a.free()
	node_b.free()
	node_c.free()
	tc.queue_free()
	await process_frame
