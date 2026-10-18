extends SceneTree

## =============================================================================
## Master Headless SceneTree Test Suite for Phase 14: Campus Office & Mini-Workers
## File: IdleArcade/tests/test_phase14_workers.gd
## Target: Godot 4.3 Engine Headless Runner & CI Verification (Release v2.1.0)
##
## Validates all 5 Core Sections:
##   1. Staff Management & Morale Economy (Hiring, firing, 5 specialist roles,
##      distinct base stats, desk assignment 0..4, capacity cap 5, 0-worker
##      multiplier neutrality 1.000x, dynamic RPS scaling).
##   2. Fatigue Accumulation, Ergonomics & Coffee Recovery (+0.02/min base rate,
##      desk upgrades L1..L3 with 25% and 60% damping, morale decay on exhaustion,
##      automatic transition to fatigued state, team coffee break & 60s Hyper-Focus).
##   3. 3D Office Expansion & Chibi-Worker AI (Office scene at (19, 0, -8),
##      interactable area, prompt label "[E] Staff Office", 5 desks, Chibi-Worker
##      4-state FSM: WORKING, BREAK, FATIGUED, CELEBRATING, mood icons 💻, ☕, 💡, 💤, 🎉,
##      kinematics animation speed dilation 1.5x).
##   4. Mobile Staff Modal & Touch Ergonomics (3 tabs: Recruiting, Desks,
##      Teambuilding, touch targets >= 56px, pointer isolation mouse_filter = STOP,
##      HUD %StaffBadge and %StaffButton integration).
##   5. Epiphany Breakthroughs, Unicorn Synergy & IPO Rebirth (💡 energy bonus >= 100,
##      15x passive RPS formula, 20.0s lifetime, Unicorn Espresso synergy hook,
##      IPO ascension staff & desk preservation, save/load JSON roundtrip).
##
## Execution:
##   godot --headless --path IdleArcade -s tests/test_phase14_workers.gd
## =============================================================================

var pass_count: int = 0
var fail_count: int = 0

const EPSILON: float = 0.001

func _assert_check(condition: bool, description: String, detail: String = "") -> void:
	if condition:
		print("  [PASS] %s" % description)
		pass_count += 1
	else:
		var err_msg = "  [FAIL] %s" % description
		if detail != "":
			err_msg += " (Detail: %s)" % detail
		printerr(err_msg)
		fail_count += 1

func _init() -> void:
	print("\n====================================================================")
	print(">>> RUNNING MASTER PHASE 14 CAMPUS OFFICE & MINI-WORKERS HEADLESS SUITE <<<")
	print("====================================================================")
	call_deferred("_run_all_tests")

func _run_all_tests() -> void:
	await process_frame

	# -------------------------------------------------------------------------
	# Autoload Singleton Setup: GameState
	# -------------------------------------------------------------------------
	var gs_script = load("res://scripts/autoload/game_state.gd")
	_assert_check(gs_script != null, "0.1 Load scripts/autoload/game_state.gd")
	if gs_script == null:
		printerr("[FATAL] Cannot load game_state.gd")
		quit(1)
		return

	var gs = root.get_node_or_null("GameState")
	if gs == null:
		gs = gs_script.new()
		gs.name = "GameState"
		root.add_child(gs)
	_assert_check(gs != null, "0.2 GameState mounted at /root/GameState")

	await process_frame

	# Execute all 5 required sections sequentially
	await _test_section_1_staff_economy(gs)
	await _test_section_2_fatigue_and_ergonomics(gs)
	await _test_section_3_3d_office_and_chibi_workers(gs)
	await _test_section_4_mobile_staff_modal_and_ergonomics(gs)
	await _test_section_5_epiphany_synergy_and_ipo(gs)

	print("\n====================================================================")
	print(">>> PHASE 14 SCENETREE TEST SUITE SUMMARY: %d PASSED, %d FAILED <<<" % [pass_count, fail_count])
	print("====================================================================")

	if fail_count == 0:
		print(">>> ALL PHASE 14 HEADLESS SCENETREE TESTS PASSED (Exit Code 0) <<<")
		quit(0)
	else:
		printerr(">>> PHASE 14 HEADLESS SCENETREE TESTS FAILED (Exit Code 1) <<<")
		quit(1)

# =============================================================================
# SECTION 1: Staff Management & Morale Economy (GameState)
# =============================================================================
func _test_section_1_staff_economy(gs: Node) -> void:
	print("\n--- SECTION 1: Staff Management & Morale Economy ---")

	# 1.1 Baseline state
	gs.reset_state()
	await process_frame

	_assert_check(gs.get_hired_workers().is_empty(), "1.1 Initial state: zero workers hired")
	_assert_check(absf(gs.get_staff_rps_multiplier() - 1.0) < EPSILON, "1.2 Zero workers yields strictly neutral 1.000x multiplier")
	_assert_check(absf(gs.get_staff_average_morale() - 1.0) < EPSILON, "1.3 Average morale defaults to 1.0 when empty")
	_assert_check(gs.get_active_workers_count() == 0, "1.4 Initial active worker count is 0")

	# 1.2 Validate role definitions catalog
	var role_defs: Dictionary = gs.get_staff_role_definitions()
	_assert_check(role_defs.size() == 5, "1.5 Exactly 5 specialist roles defined in catalog")
	var expected_roles = ["Frontend Dev", "Backend Dev", "UI/UX Designer", "Growth Hacker", "QA Engineer"]
	for r in expected_roles:
		_assert_check(role_defs.has(r), "1.6 Role catalog defines '%s'" % r)
		var r_data: Dictionary = role_defs.get(r, {})
		_assert_check(float(r_data.get("hire_cost", 0.0)) > 0.0, "1.7 Role '%s' has positive hire cost" % r)

	# 1.3 Hiring individual specialist workers
	gs.energy = 50000.0

	# Hire Frontend Dev
	var hire_devin = gs.hire_worker("Frontend Dev")
	_assert_check(hire_devin == true, "1.8 Hiring 'Frontend Dev' succeeds")
	_assert_check(gs.get_hired_workers().size() == 1, "1.9 Worker count increased to 1")
	var w_front: Dictionary = gs.get_worker("Frontend Dev")
	_assert_check(w_front.get("role") == "Frontend Dev", "1.10 Hired worker role matches 'Frontend Dev'")
	_assert_check(w_front.get("desk_assigned") == 0, "1.11 Frontend Dev assigned to free desk 0")
	_assert_check(absf(float(w_front.get("morale", 0.0)) - 1.0) < EPSILON, "1.12 Initial worker morale is 1.0")
	_assert_check(absf(float(w_front.get("fatigue", 1.0)) - 0.0) < EPSILON, "1.13 Initial worker fatigue is 0.0")
	_assert_check(w_front.get("current_state") == "working", "1.14 Initial worker state is 'working'")

	# Multiplier with 1 active worker: 1.0 + (1 * 0.05) * 1.0 = 1.050x
	_assert_check(absf(gs.get_staff_rps_multiplier() - 1.05) < EPSILON, "1.15 Staff multiplier with 1 worker is 1.050x (+5%)")

	# 1.4 Duplicate and unknown hiring rejections
	var dup_hire = gs.hire_worker("Frontend Dev")
	_assert_check(dup_hire == false, "1.16 Duplicate role recruitment safely rejected")
	var bad_hire = gs.hire_worker("Space Astronaut")
	_assert_check(bad_hire == false, "1.17 Unknown role recruitment safely rejected")

	# 1.5 Insufficient funds rejection
	gs.energy = 10.0
	var poor_hire = gs.hire_worker("Backend Dev")
	_assert_check(poor_hire == false, "1.18 Recruitment with insufficient energy safely rejected")

	# 1.6 Hire remaining 4 roles up to capacity (MAX_WORKERS = 5)
	gs.energy = 100000.0
	_assert_check(gs.hire_worker("Backend Dev"), "1.19 Hired 'Backend Dev'")
	_assert_check(gs.hire_worker("UI/UX Designer"), "1.20 Hired 'UI/UX Designer'")
	_assert_check(gs.hire_worker("Growth Hacker"), "1.21 Hired 'Growth Hacker'")
	_assert_check(gs.hire_worker("QA Engineer"), "1.22 Hired 'QA Engineer'")

	_assert_check(gs.get_hired_workers().size() == 5, "1.23 Full office staffed with exactly 5 workers")
	_assert_check(gs.get_active_workers_count() == 5, "1.24 All 5 workers active")

	# Full staff multiplier: 1.0 + (5 * 0.05) * 1.0 = 1.250x (+25%)
	_assert_check(absf(gs.get_staff_rps_multiplier() - 1.25) < EPSILON, "1.25 Full staff multiplier is 1.250x (+25%)")

	# 1.7 Exceeding capacity rejection
	var over_hire = gs.hire_worker("Frontend Dev")
	_assert_check(over_hire == false, "1.26 Exceeding max staff capacity of 5 safely rejected")

	# 1.8 Firing worker & desk reclamation
	var fire_ok = gs.fire_worker("worker_frontend_dev")
	_assert_check(fire_ok == true, "1.27 Firing worker by ID succeeds")
	_assert_check(gs.get_hired_workers().size() == 4, "1.28 Worker count decremented to 4")
	_assert_check(absf(gs.get_staff_rps_multiplier() - 1.20) < EPSILON, "1.29 Multiplier updated to 1.200x (+20%)")
	_assert_check(gs.get_worker("Frontend Dev").is_empty(), "1.30 Querying fired worker returns empty")

	# Re-hire into freed desk
	_assert_check(gs.hire_worker("Frontend Dev"), "1.31 Re-hiring into freed desk succeeds")
	var re_devin = gs.get_worker("Frontend Dev")
	_assert_check(re_devin.get("desk_assigned") == 0, "1.32 Re-hired worker correctly occupies reclaimed desk 0")

# =============================================================================
# SECTION 2: Fatigue Accumulation, Ergonomics & Coffee Recovery
# =============================================================================
func _test_section_2_fatigue_and_ergonomics(gs: Node) -> void:
	print("\n--- SECTION 2: Fatigue Accumulation, Ergonomics & Coffee Recovery ---")

	# 2.1 Desk Upgrade System (Desks 0..4, Levels 1..3)
	var d_levels: Array = gs.get_desk_levels()
	_assert_check(d_levels.size() == 5, "2.1 Desk levels array has 5 workstations")
	_assert_check(gs.get_desk_level(0) == 1, "2.2 Initial desk 0 level is Level 1")

	# Upgrade desk 0 to Level 2
	gs.energy = 50000.0
	var up1 = gs.upgrade_desk(0)
	_assert_check(up1 == true, "2.3 Upgrade desk 0 to Level 2 succeeds")
	_assert_check(gs.get_desk_level(0) == 2, "2.4 Desk 0 is now Level 2")

	# Upgrade desk 0 to Level 3
	var up2 = gs.upgrade_desk(0)
	_assert_check(up2 == true, "2.5 Upgrade desk 0 to Level 3 succeeds")
	_assert_check(gs.get_desk_level(0) == 3, "2.6 Desk 0 is now Level 3 (Max)")

	# Exceed max desk level (Level 3)
	var up_over = gs.upgrade_desk(0)
	_assert_check(up_over == false, "2.7 Upgrade beyond Level 3 safely rejected")

	# Boundary desk index upgrades
	_assert_check(gs.upgrade_desk(-1) == false, "2.8 Negative desk index upgrade rejected")
	_assert_check(gs.upgrade_desk(5) == false, "2.9 Out-of-bounds desk index upgrade (5) rejected")

	# Desk fatigue reduction multipliers
	_assert_check(absf(gs.get_desk_fatigue_multiplier(1) - 1.00) < EPSILON, "2.10 Desk Level 1: 1.00x (0% reduction)")
	_assert_check(absf(gs.get_desk_fatigue_multiplier(2) - 0.75) < EPSILON, "2.11 Desk Level 2: 0.75x (25% reduction)")
	_assert_check(absf(gs.get_desk_fatigue_multiplier(3) - 0.40) < EPSILON, "2.12 Desk Level 3: 0.40x (60% reduction)")

	# 2.2 Fatigue Accumulation Simulation (+0.02 / min base)
	# Advance 60 seconds of simulation
	gs.update_staff_simulation(60.0)

	var w_front = gs.get_worker("Frontend Dev") # Desk 0 is Level 3 (0.40x mult) -> 0.02 * 0.40 = 0.008
	var w_back = gs.get_worker("Backend Dev")   # Desk 1 is Level 1 (1.00x mult) -> 0.02 * 1.00 = 0.020

	_assert_check(absf(float(w_front.get("fatigue", 0.0)) - 0.008) < 0.002, "2.13 Level 3 desk accumulated 0.008 fatigue in 60s (-60% fatigue rate)")
	_assert_check(absf(float(w_back.get("fatigue", 0.0)) - 0.020) < 0.002, "2.14 Level 1 desk accumulated 0.020 fatigue in 60s (base rate)")

	# 2.3 Severe Exhaustion, Morale Decay & State Transition
	# Simulate 3,500 seconds to reach severe fatigue and exhaustion
	gs.update_staff_simulation(3500.0)

	var w_back_fatigued = gs.get_worker("Backend Dev")
	_assert_check(absf(float(w_back_fatigued.get("fatigue", 0.0)) - 1.0) < EPSILON, "2.15 Fatigue strictly clamped at 1.0")
	_assert_check(float(w_back_fatigued.get("morale", 1.0)) < 1.0, "2.16 Morale decayed during high fatigue (fatigue >= 0.8)")
	_assert_check(w_back_fatigued.get("current_state") == "fatigued", "2.17 Worker transitioned automatically to 'fatigued' state")
	_assert_check(gs.get_active_workers_count() < 5, "2.18 Fatigued worker excluded from active worker count")

	# 2.4 Team Coffee Break Recovery & Hyper-Focus Logic
	var coffee_ok = gs.give_team_coffee_break()
	_assert_check(coffee_ok == true, "2.19 give_team_coffee_break() succeeds")

	for w in gs.get_hired_workers():
		_assert_check(absf(float(w.get("fatigue", 1.0)) - 0.0) < EPSILON, "2.20 Worker '%s' fatigue reset to 0.0" % w.get("role"))
		_assert_check(absf(float(w.get("morale", 0.0)) - 1.0) < EPSILON, "2.21 Worker '%s' morale restored to 1.0" % w.get("role"))
		_assert_check(w.get("current_state") == "working", "2.22 Worker '%s' state restored to 'working'" % w.get("role"))

	_assert_check(gs.is_staff_hyper_focus_active() == true, "2.23 Hyper-Focus active post-coffee break")
	_assert_check(absf(gs.get_staff_hyper_focus_time_remaining() - 60.0) < EPSILON, "2.24 Hyper-Focus duration initialized to 60.0s")
	_assert_check(absf(gs.get_staff_hyper_focus_multiplier() - 1.50) < EPSILON, "2.25 Hyper-Focus speed multiplier is 1.50x")
	_assert_check(gs.get_active_workers_count() == 5, "2.26 All 5 workers active again post-break")
	_assert_check(absf(gs.get_staff_rps_multiplier() - 1.25) < EPSILON, "2.27 Staff RPS multiplier fully restored to 1.250x")

# =============================================================================
# SECTION 3: 3D Office Expansion & Chibi-Worker AI
# =============================================================================
func _test_section_3_3d_office_and_chibi_workers(gs: Node) -> void:
	print("\n--- SECTION 3: 3D Office Expansion & Chibi-Worker AI ---")

	# 3.1 3D Office Expansion Scene Loading & Verification
	var office_scene = load("res://scenes/office_expansion_3d.tscn")
	_assert_check(office_scene != null, "3.1 scenes/office_expansion_3d.tscn loads successfully")
	if office_scene == null:
		return

	var office = office_scene.instantiate() as StaticBody3D
	_assert_check(office != null, "3.2 OfficeExpansion3D instantiates as StaticBody3D")
	root.add_child(office)
	await process_frame

	# Check group memberships
	_assert_check(office.is_in_group("staff_offices"), "3.3 In group 'staff_offices'")
	_assert_check(office.is_in_group("interactables"), "3.4 In group 'interactables'")
	_assert_check(office.is_in_group("stations"), "3.5 In group 'stations'")

	# Check interaction trigger and prompt
	var area = office.get_node_or_null("InteractionArea") as Area3D
	var prompt = office.get_node_or_null("PromptLabel3D") as Label3D
	_assert_check(area != null, "3.6 InteractionArea (Area3D) exists on OfficeExpansion3D")
	_assert_check(prompt != null, "3.7 PromptLabel3D exists on OfficeExpansion3D")
	if prompt != null:
		_assert_check(prompt.text.contains("Staff Office"), "3.8 Prompt text contains '[E] Staff Office'")

	# Check desk markers (0..4)
	for d in range(5):
		var desk_node = office.get_desk_node(d)
		_assert_check(desk_node != null, "3.9 Desk %d node exists in office hierarchy" % d)

	# 3.2 Main Campus 3D Integration & Spatial Placement
	var main_scene = load("res://scenes/main_3d.tscn")
	_assert_check(main_scene != null, "3.10 scenes/main_3d.tscn loads successfully")
	if main_scene != null:
		var main_inst = main_scene.instantiate()
		var office_in_main = main_inst.get_node_or_null("OfficeExpansion3D")
		_assert_check(office_in_main != null, "3.11 OfficeExpansion3D instanced in main_3d.tscn")
		if office_in_main != null:
			var pos: Vector3 = office_in_main.position
			_assert_check(absf(pos.x - 19.0) < EPSILON and absf(pos.y - 0.0) < EPSILON and absf(pos.z - (-8.0)) < EPSILON,
				"3.12 Office placed at exact coordinates (19, 0, -8)")
		main_inst.queue_free()

	# 3.3 Autonomous Chibi-Worker AI
	var chibi_scene = load("res://scenes/chibi_worker_3d.tscn")
	_assert_check(chibi_scene != null, "3.13 scenes/chibi_worker_3d.tscn loads successfully")
	if chibi_scene == null:
		office.queue_free()
		return

	var worker = chibi_scene.instantiate() as CharacterBody3D
	_assert_check(worker != null, "3.14 ChibiWorker3D instantiates as CharacterBody3D")
	root.add_child(worker)
	await process_frame

	# Setup with worker dictionary
	var test_worker_data = {
		"id": "worker_devin",
		"name": "Devin",
		"role": "Frontend Dev",
		"morale": 1.0,
		"fatigue": 0.0,
		"current_state": "working",
		"desk_assigned": 0
	}
	worker.setup(test_worker_data)

	# Validate state machine and mood icons
	_assert_check(worker.get_state() == "working", "3.15 Initial worker state is 'working'")
	_assert_check(worker.get_node("MoodIconLabel3D").text == "💻", "3.16 Working state displays '💻' mood icon")

	# State transition to BREAK
	worker.set_state("break")
	_assert_check(worker.get_state() == "break", "3.17 Transitioned to 'break' state")
	_assert_check(worker.get_node("MoodIconLabel3D").text == "☕", "3.18 Break state displays '☕' mood icon")

	# State transition to FATIGUED
	worker.set_state("fatigued")
	_assert_check(worker.get_state() == "fatigued", "3.19 Transitioned to 'fatigued' state")
	_assert_check(worker.get_node("MoodIconLabel3D").text == "💤", "3.20 Fatigued state displays '💤' mood icon")

	# State transition to CELEBRATING
	worker.set_state("celebrating")
	_assert_check(worker.get_state() == "celebrating", "3.21 Transitioned to 'celebrating' state")
	_assert_check(worker.get_node("MoodIconLabel3D").text == "🎉", "3.22 Celebrating state displays '🎉' mood icon")

	# Speed dilation validation
	_assert_check(absf(worker.get_animation_speed_multiplier() - 1.0) < EPSILON, "3.23 Normal speed multiplier is 1.0x")
	worker.set_hyper_focus(true)
	_assert_check(absf(worker.get_animation_speed_multiplier() - 1.50) < EPSILON, "3.24 Hyper-Focus speed multiplier is 1.50x")
	worker.set_hyper_focus(false)
	_assert_check(absf(worker.get_animation_speed_multiplier() - 1.0) < EPSILON, "3.25 Normalized speed multiplier returns to 1.0x")

	office.queue_free()
	worker.queue_free()

# =============================================================================
# SECTION 4: Mobile Staff Modal & Touch Ergonomics
# =============================================================================
func _test_section_4_mobile_staff_modal_and_ergonomics(gs: Node) -> void:
	print("\n--- SECTION 4: Mobile Staff Modal & Touch Ergonomics ---")

	# 4.1 Staff Modal Scene Loading
	var modal_scene = load("res://scenes/ui/staff_modal.tscn")
	_assert_check(modal_scene != null, "4.1 scenes/ui/staff_modal.tscn loads successfully")
	if modal_scene == null:
		return

	var modal = modal_scene.instantiate() as Control
	_assert_check(modal != null, "4.2 StaffModal instantiates as Control")
	root.add_child(modal)
	await process_frame

	# Pointer Isolation: mouse_filter == STOP (0)
	_assert_check(modal.mouse_filter == Control.MOUSE_FILTER_STOP, "4.3 Modal root enforces mouse_filter = STOP (0)")
	var backdrop = modal.get_node_or_null("Backdrop") as Control
	if backdrop != null:
		_assert_check(backdrop.mouse_filter == Control.MOUSE_FILTER_STOP, "4.4 Backdrop enforces mouse_filter = STOP (0)")

	# Tab Switching Logic
	modal.open()
	_assert_check(modal.active_tab_index == 0, "4.5 Modal opens on Tab 0 (Recruiting)")

	modal.switch_tab(1)
	_assert_check(modal.active_tab_index == 1, "4.6 Switched to Tab 1 (Desk Upgrades)")

	modal.switch_tab(2)
	_assert_check(modal.active_tab_index == 2, "4.7 Switched to Tab 2 (Teambuilding)")

	# Tab clamping
	modal.switch_tab(99)
	_assert_check(modal.active_tab_index == 2, "4.8 Out-of-bounds tab index clamped to max tab (2)")
	modal.switch_tab(-5)
	_assert_check(modal.active_tab_index == 0, "4.9 Negative tab index clamped to min tab (0)")

	# Touch Ergonomics: Target heights >= 56px
	var buttons_to_check = [
		"%CloseButton",
		"%RecruitingTabButton",
		"%DeskUpgradesTabButton",
		"%TeambuildingTabButton",
		"%RecruitButton",
		"%ServeCoffeeBreakButton"
	]
	for b_name in buttons_to_check:
		var btn = modal.get_node_or_null(b_name) as Control
		_assert_check(btn != null, "4.10 Found touch element %s" % b_name)
		if btn != null:
			var min_h = btn.custom_minimum_size.y
			_assert_check(min_h >= 56.0, "4.11 Element %s height (%.1fpx) satisfies >= 56px touch target" % [b_name, min_h])
			_assert_check(btn.mouse_filter == Control.MOUSE_FILTER_STOP, "4.12 Element %s enforces mouse_filter = STOP" % b_name)

	# 4.2 HUD Integration
	var hud_scene = load("res://scenes/hud.tscn")
	_assert_check(hud_scene != null, "4.13 scenes/hud.tscn loads successfully")
	if hud_scene != null:
		var hud = hud_scene.instantiate() as Control
		root.add_child(hud)
		await process_frame

		var badge = hud.get_node_or_null("%StaffBadge") as Control
		var badge_label = hud.get_node_or_null("%StaffBadgeLabel") as Label
		var staff_btn = hud.get_node_or_null("%StaffButton") as Control

		_assert_check(badge != null, "4.14 HUD %StaffBadge exists")
		_assert_check(badge_label != null, "4.15 HUD %StaffBadgeLabel exists")
		_assert_check(staff_btn != null, "4.16 HUD %StaffButton exists in navigation drawer")

		if badge != null:
			_assert_check(badge.custom_minimum_size.y >= 56.0, "4.17 HUD %StaffBadge height (%.1fpx) >= 56px" % badge.custom_minimum_size.y)
			_assert_check(badge.mouse_filter == Control.MOUSE_FILTER_STOP, "4.18 HUD %StaffBadge mouse_filter = STOP")

		if staff_btn != null:
			_assert_check(staff_btn.custom_minimum_size.y >= 64.0, "4.19 HUD %StaffButton height (%.1fpx) >= 64px" % staff_btn.custom_minimum_size.y)
			_assert_check(staff_btn.mouse_filter == Control.MOUSE_FILTER_STOP, "4.20 HUD %StaffButton mouse_filter = STOP")

		# Check formatting
		if hud.has_method("_update_staff_badge"):
			hud._update_staff_badge()
			if badge_label != null:
				_assert_check(badge_label.text.contains("5") and badge_label.text.contains("%"),
					"4.21 HUD badge correctly displays staff count and morale percentage")

		hud.queue_free()

	modal.close()
	modal.queue_free()

# =============================================================================
# SECTION 5: Epiphany Breakthroughs, Unicorn Synergy & IPO Rebirth
# =============================================================================
func _test_section_5_epiphany_synergy_and_ipo(gs: Node) -> void:
	print("\n--- SECTION 5: Epiphany Breakthroughs, Unicorn Synergy & IPO Rebirth ---")

	# 5.1 Epiphany Moment Reward Calculus
	var prev_energy = gs.energy
	var reward = gs.trigger_worker_epiphany("worker_frontend_dev")

	_assert_check(reward >= 100.0, "5.1 Epiphany reward satisfies minimum floor of 100.0 energy (got %.1f)" % reward)
	_assert_check(absf(gs.energy - (prev_energy + reward)) < EPSILON, "5.2 Epiphany reward credited directly to player energy")

	# 5.2 Chibi-Worker Epiphany Visuals & Lifetime
	var chibi_scene = load("res://scenes/chibi_worker_3d.tscn")
	if chibi_scene != null:
		var worker = chibi_scene.instantiate() as CharacterBody3D
		root.add_child(worker)
		await process_frame

		worker.setup({"id": "w_test", "role": "QA Engineer", "current_state": "working"})
		_assert_check(worker.has_epiphany() == false, "5.3 Epiphany initially false")

		# Trigger epiphany
		worker.trigger_epiphany(500.0)
		_assert_check(worker.has_epiphany() == true, "5.4 has_epiphany() is true after trigger")
		_assert_check(worker.get_node("MoodIconLabel3D").text == "💡", "5.5 Epiphany displays '💡' mood icon")

		# Tap to collect
		var collected = worker.collect_epiphany()
		_assert_check(collected >= 100.0, "5.6 collect_epiphany() returned reward >= 100.0")
		_assert_check(worker.has_epiphany() == false, "5.7 has_epiphany() reset to false after collection")
		_assert_check(worker.get_state() == "celebrating", "5.8 Worker transitions to 'celebrating' on collection")

		# Idempotent collection (anti-double dipping)
		var double_collect = worker.collect_epiphany()
		_assert_check(absf(double_collect - 0.0) < EPSILON, "5.9 Successive collection returns 0.0 (strictly idempotent)")

		# Auto-expiration simulation (epiphany_lifetime = 20.0s)
		worker.set_state("working")
		worker.trigger_epiphany(500.0)
		_assert_check(worker.has_epiphany() == true, "5.10 Second epiphany triggered")
		# Advance 21 seconds
		worker._process(21.0)
		_assert_check(worker.has_epiphany() == false, "5.11 Epiphany cleanly auto-expires after 20.0s lifetime")
		_assert_check(worker.get_node("MoodIconLabel3D").text == "💻", "5.12 Mood icon reverted to '💻' on expiration")

		worker.queue_free()

	# 5.3 CoffeeMachine3D Unicorn Espresso Synergy Hook
	var coffee_script = load("res://scripts/coffee_machine_3d.gd")
	_assert_check(coffee_script != null, "5.13 scripts/coffee_machine_3d.gd loads successfully")
	if coffee_script != null:
		var machine = coffee_script.new()
		_assert_check(machine.has_method("trigger_office_synergy"), "5.14 CoffeeMachine3D implements trigger_office_synergy()")
		machine.free()

	# 5.4 IPO Ascension & Staff Preservation
	# Setup staff state before IPO
	gs.desk_levels[0] = 3
	gs.desk_levels[1] = 2
	var pre_ipo_workers_count = gs.get_hired_workers().size()
	_assert_check(pre_ipo_workers_count == 5, "5.15 Pre-IPO staff count is 5")

	# Trigger IPO
	gs.total_energy_earned = 5000000.0
	var ipo_success = gs.trigger_ipo()
	_assert_check(ipo_success == true, "5.16 trigger_ipo() executed successfully")
	_assert_check(absf(gs.energy - 0.0) < EPSILON, "5.17 Player regular energy reset to 0.0")

	# Check staff preservation across IPO
	_assert_check(gs.get_hired_workers().size() == 5, "5.18 All 5 specialist workers strictly preserved across IPO")
	_assert_check(gs.get_desk_level(0) == 3, "5.19 Desk 0 Level 3 strictly preserved across IPO")
	_assert_check(gs.get_desk_level(1) == 2, "5.20 Desk 1 Level 2 strictly preserved across IPO")
	_assert_check(gs.is_staff_hyper_focus_active() == false, "5.21 Temporary Hyper-Focus buff reset on IPO")
	_assert_check(absf(gs.get_staff_hyper_focus_time_remaining() - 0.0) < EPSILON, "5.22 Hyper-Focus timer reset to 0.0 on IPO")

	# 5.5 JSON Save / Load Roundtrip Persistence
	gs.save_to_disk()
	var pre_save_workers = gs.get_hired_workers()
	var pre_save_desks = gs.get_desk_levels()

	# Clear state in memory
	gs.hired_workers = []
	gs.desk_levels = [1, 1, 1, 1, 1]
	_assert_check(gs.get_hired_workers().is_empty(), "5.23 Memory cleared before load")

	# Load from disk
	gs.load_from_disk()
	_assert_check(gs.get_hired_workers().size() == pre_save_workers.size(), "5.24 load_from_disk restored all 5 workers")
	_assert_check(gs.get_desk_level(0) == 3, "5.25 load_from_disk restored desk 0 Level 3")
	_assert_check(gs.get_desk_level(1) == 2, "5.26 load_from_disk restored desk 1 Level 2")
	_assert_check(absf(gs.get_staff_rps_multiplier() - 1.25) < EPSILON, "5.27 load_from_disk restored 1.250x staff RPS multiplier")
