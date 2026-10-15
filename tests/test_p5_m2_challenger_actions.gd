extends SceneTree

## Adversarial Empirical Challenger SceneTree Test Harness for Milestone P5-M2
## Focus: Multi-Target Proximity Prioritization, Dynamic Visual States & Dual Dispatch Idempotency
##
## Role: Empirical Challenger 1 (critic, specialist)
## Target: IdleArcade (Godot 4.3 Mobile Touch Navigation)
##
## Executable via:
##   godot --headless --path IdleArcade -s tests/test_p5_m2_challenger_actions.gd

var pass_count: int = 0
var fail_count: int = 0

const EPSILON: float = 0.002

class SyntheticKeyMonitor extends Node:
	var key_e_count: int = 0

	func _unhandled_input(event: InputEvent) -> void:
		if event is InputEventKey and event.keycode == KEY_E and event.pressed:
			key_e_count += 1

func _init() -> void:
	print("====================================================================")
	print("[CHALLENGER-1] P5-M2 Proximity & Action Dispatch Adversarial Suite")
	print("====================================================================")
	process_frame.connect(_on_first_frame, CONNECT_ONE_SHOT)

func _on_first_frame() -> void:
	await _run_all_adversarial_challenges()
	print("\n====================================================================")
	print("[CHALLENGER-1] Results: %d passed, %d failed" % [pass_count, fail_count])
	print("====================================================================")
	if fail_count == 0:
		print(">>> EMPIRICAL VERDICT: APPROVE — ALL ADVERSARIAL CHALLENGES PASSED! <<<")
		quit(0)
	else:
		printerr(">>> EMPIRICAL VERDICT: REQUEST_CHANGES — %d FAILURES ENCOUNTERED! <<<" % fail_count)
		quit(1)

func _assert_chall(cond: bool, test_name: String, detail: String = "") -> void:
	if cond:
		print("  [PASS] %s" % test_name)
		pass_count += 1
	else:
		var err_msg = "  [FAIL] %s" % test_name
		if detail != "":
			err_msg += " -> " + detail
		printerr(err_msg)
		fail_count += 1

func _run_all_adversarial_challenges() -> void:
	# -------------------------------------------------------------------------
	# 0. Setup GameState Autoload
	# -------------------------------------------------------------------------
	var gs_script = load("res://scripts/autoload/game_state.gd")
	var gs = root.get_node_or_null("GameState")
	if gs == null and gs_script != null:
		gs = gs_script.new()
		gs.name = "GameState"
		root.add_child(gs)
	if gs != null and gs.has_method("reset_state"):
		gs.reset_state()
	await process_frame

	var touch_controls_scene = load("res://scenes/ui/touch_controls.tscn")
	var npc_scene = load("res://scenes/npc_3d.tscn")
	var gate_scene = load("res://scenes/zone_gate_3d.tscn")
	var main_3d_scene = load("res://scenes/main_3d.tscn")

	if touch_controls_scene == null or npc_scene == null or gate_scene == null:
		printerr("[FATAL] Core scenes failed to load.")
		fail_count += 1
		return

	var tc_inst = touch_controls_scene.instantiate() as TouchControls
	root.add_child(tc_inst)
	await process_frame

	var action_btn = tc_inst.find_child("ActionButton", true, false) as Button
	var laptop_btn = tc_inst.find_child("LaptopThumbButton", true, false) as Button

	# =========================================================================
	# SECTION 1: Multi-Target Prioritization Stress
	# =========================================================================
	print("\n--- Section 1: Multi-Target Prioritization Stress ---")

	var npc_alex = npc_scene.instantiate() as NPC3D
	npc_alex.npc_id = "alex"
	npc_alex.npc_name = "Alex"
	npc_alex.quest_id = "quest_briefcases"
	root.add_child(npc_alex)

	var gate_server = gate_scene.instantiate() as ZoneGate3D
	gate_server.zone_id = "server_room"
	gate_server.zone_name = "Server Room"
	gate_server.required_level = 2
	gate_server.unlock_cost = 100.0
	root.add_child(gate_server)

	var npc_bob = npc_scene.instantiate() as NPC3D
	npc_bob.npc_id = "bob"
	npc_bob.npc_name = "Bob"
	npc_bob.quest_id = "quest_server"
	root.add_child(npc_bob)
	await process_frame

	# 1.1 Initial Dormant State
	_assert_chall(tc_inst.active_interactable == null, "1.1 Initial active_interactable is null")
	_assert_chall(action_btn.modulate.a <= 0.40, "1.2 ActionButton initial opacity is dormant (<= 0.40)")
	_assert_chall(action_btn.text == "[E] Action", "1.3 ActionButton initial text is '[E] Action'")

	# 1.2 Push targets in sequence: Alex -> Gate -> Bob
	tc_inst.register_interactable(npc_alex, "Talk [E]")
	await process_frame
	_assert_chall(tc_inst.active_interactable == npc_alex, "1.4 Stack [Alex]: active target is Alex")
	_assert_chall(action_btn.text == "Talk [E]", "1.5 ActionButton displays 'Talk [E]' for Alex")

	tc_inst.register_interactable(gate_server, "Unlock [E]")
	await process_frame
	_assert_chall(tc_inst.active_interactable == gate_server, "1.6 Stack [Alex, Gate]: active target is Gate")
	# Level is 1, so gate is locked
	_assert_chall(action_btn.text == "Locked [E]", "1.7 ActionButton dynamically evaluates Gate and shows 'Locked [E]'")

	tc_inst.register_interactable(npc_bob, "Talk [E]")
	await process_frame
	_assert_chall(tc_inst.active_interactable == npc_bob, "1.8 Stack [Alex, Gate, Bob]: active target is Bob")
	_assert_chall(action_btn.text == "Talk [E]", "1.9 ActionButton displays 'Talk [E]' for Bob")

	# 1.3 Exit in reverse order (LIFO): Pop Bob -> restores Gate
	tc_inst.unregister_interactable(npc_bob)
	await process_frame
	_assert_chall(tc_inst.active_interactable == gate_server, "1.10 Exiting Bob restores Gate as active target")
	_assert_chall(action_btn.text == "Locked [E]", "1.11 ActionButton restores Gate 'Locked [E]' state")

	# Pop Gate -> restores Alex
	tc_inst.unregister_interactable(gate_server)
	await process_frame
	_assert_chall(tc_inst.active_interactable == npc_alex, "1.12 Exiting Gate restores Alex as active target")
	_assert_chall(action_btn.text == "Talk [E]", "1.13 ActionButton restores Alex 'Talk [E]' state")

	# Pop Alex -> restores Dormant
	tc_inst.unregister_interactable(npc_alex)
	await process_frame
	_assert_chall(tc_inst.active_interactable == null, "1.14 Exiting Alex empties active stack")
	_assert_chall(action_btn.modulate.a <= 0.40, "1.15 ActionButton returns to dormant opacity (<= 0.40)")
	_assert_chall(action_btn.text == "[E] Action", "1.16 ActionButton returns to '[E] Action' default label")

	# 1.4 Non-LIFO Exit: Middle target exits first
	tc_inst.register_interactable(npc_alex, "Talk [E]")
	tc_inst.register_interactable(gate_server, "Unlock [E]")
	tc_inst.register_interactable(npc_bob, "Talk [E]")
	await process_frame

	# Gate leaves while avatar is between Alex and Bob
	tc_inst.unregister_interactable(gate_server)
	await process_frame
	_assert_chall(tc_inst.active_interactable == npc_bob, "1.17 Unregistering middle element (Gate) leaves top element (Bob) active")
	_assert_chall(action_btn.text == "Talk [E]", "1.18 ActionButton maintains Bob context")

	# Bottom element leaves
	tc_inst.unregister_interactable(npc_alex)
	await process_frame
	_assert_chall(tc_inst.active_interactable == npc_bob, "1.19 Unregistering bottom element (Alex) preserves top element (Bob)")

	tc_inst.unregister_interactable(npc_bob)
	await process_frame
	_assert_chall(tc_inst.active_interactable == null, "1.20 Final unregister resets to null")

	# 1.5 Duplicate Registration Stress
	for i in range(8):
		tc_inst.register_interactable(npc_alex, "Talk [E]")
	await process_frame
	_assert_chall(tc_inst.active_interactables.size() == 1,
		"1.21 Duplicate registration is idempotent (array size strictly 1, actual: %d)" % tc_inst.active_interactables.size())
	tc_inst.unregister_interactable(npc_alex)
	_assert_chall(tc_inst.active_interactables.size() == 0, "1.22 Single unregister empties array")

	# =========================================================================
	# SECTION 2: Dynamic State Visual Transitions & Styles
	# =========================================================================
	print("\n--- Section 2: Dynamic State Visual Transitions ---")

	# 2.1 NPC Talk Visuals (Emerald Green)
	tc_inst.register_interactable(npc_alex, "Talk [E]")
	await process_frame
	_assert_chall(action_btn.text == "Talk [E]", "2.1 Label set to 'Talk [E]'")
	_assert_chall(action_btn.modulate.a >= 0.95, "2.2 Opacity set to 1.0 (active)")
	var curr_style = action_btn.get_theme_stylebox("normal") as StyleBoxFlat
	_assert_chall(curr_style != null, "2.3 StyleBox applied to ActionButton")
	if curr_style != null:
		# Emerald green border has strong green component
		_assert_chall(curr_style.border_color.g > 0.80 and curr_style.border_color.r < 0.40,
			"2.4 Emerald green border theme applied for NPC (G: %.2f, R: %.2f)" % [curr_style.border_color.g, curr_style.border_color.r])

	# 2.2 Quest Claim Visuals (Amber Gold)
	# Trigger quest 'ready' status
	if gs != null and gs.has_method("start_campus_quest"):
		gs.start_campus_quest("quest_briefcases", 3)
		gs.advance_campus_quest("quest_briefcases", 3) # Becomes ready
	tc_inst._update_action_button_visuals("", true)
	await process_frame
	_assert_chall(action_btn.text == "Claim [E]", "2.5 Quest ready status triggers 'Claim [E]' text")
	curr_style = action_btn.get_theme_stylebox("normal") as StyleBoxFlat
	if curr_style != null:
		# Golden border has strong red and green, low blue
		_assert_chall(curr_style.border_color.r > 0.85 and curr_style.border_color.g > 0.70 and curr_style.border_color.b < 0.35,
			"2.6 Amber gold border theme applied for Quest Claim (R: %.2f, G: %.2f, B: %.2f)" %
			[curr_style.border_color.r, curr_style.border_color.g, curr_style.border_color.b])

	tc_inst.unregister_interactable(npc_alex)

	# 2.3 Gate Locked Visuals (Coral Red)
	gs.reset_state() # Level 1, 0 energy
	tc_inst.register_interactable(gate_server, "Unlock [E]")
	await process_frame
	_assert_chall(action_btn.text == "Locked [E]", "2.7 Insufficient clearance triggers 'Locked [E]'")
	curr_style = action_btn.get_theme_stylebox("normal") as StyleBoxFlat
	if curr_style != null:
		# Coral red border has strong red, low green and blue
		_assert_chall(curr_style.border_color.r > 0.85 and curr_style.border_color.g < 0.45,
			"2.8 Coral red border theme applied for Locked Gate (R: %.2f, G: %.2f)" % [curr_style.border_color.r, curr_style.border_color.g])

	# 2.4 Gate Unlock Visuals (Neon Cyan)
	# Grant player clearance level 2
	gs.idle_level = 2
	tc_inst._update_action_button_visuals("", true)
	await process_frame
	_assert_chall(action_btn.text == "Unlock [E]", "2.9 Granted clearance triggers 'Unlock [E]'")
	curr_style = action_btn.get_theme_stylebox("normal") as StyleBoxFlat
	if curr_style != null:
		# Neon cyan border has strong green and blue, low red
		_assert_chall(curr_style.border_color.b > 0.85 and curr_style.border_color.g > 0.75 and curr_style.border_color.r < 0.45,
			"2.10 Neon cyan border theme applied for Unlock Gate (B: %.2f, G: %.2f, R: %.2f)" %
			[curr_style.border_color.b, curr_style.border_color.g, curr_style.border_color.r])

	tc_inst.unregister_interactable(gate_server)

	# =========================================================================
	# SECTION 3: Dual Dispatch Verification & Double-Execution Glitch Stress
	# =========================================================================
	print("\n--- Section 3: Dual Dispatch & Double-Execution Glitch Stress ---")

	var key_monitor = SyntheticKeyMonitor.new()
	root.add_child(key_monitor)
	await process_frame

	# 3.1 NPC Talk Dispatch Idempotency
	npc_alex._is_talking = false
	tc_inst.register_interactable(npc_alex, "Talk [E]")
	await process_frame

	key_monitor.key_e_count = 0
	tc_inst.trigger_action()
	await process_frame

	_assert_chall(npc_alex._is_talking == true, "3.1 NPC interact() executed directly (_is_talking is true)")
	_assert_chall(key_monitor.key_e_count > 0, "3.2 Synthetic KEY_E injected into input pipeline")

	# Verify synthetic KEY_E does NOT duplicate dialogue:
	# npc_3d._unhandled_input() checks `if not _player_in_range or _is_talking: return`.
	# Because _is_talking is true, subsequent KEY_E is dropped!
	_assert_chall(npc_alex._is_talking == true, "3.3 NPC talking state safely absorbed synthetic KEY_E without glitch")

	npc_alex.end_dialogue()
	tc_inst.unregister_interactable(npc_alex)
	await process_frame

	# 3.2 Gate Unlock Dispatch Idempotency (With Proper Clearance Granted)
	# NOTE: Challenger explicitly configures clearance so attempt_unlock() succeeds!
	gs.idle_level = 2
	gate_server._is_unlocked = false
	tc_inst.register_interactable(gate_server, "Unlock [E]")
	await process_frame

	key_monitor.key_e_count = 0
	tc_inst.trigger_action()
	await process_frame

	_assert_chall(gate_server._is_unlocked == true, "3.4 Gate attempt_unlock() executed directly (_is_unlocked is true)")
	_assert_chall(key_monitor.key_e_count > 0, "3.5 Synthetic KEY_E injected into pipeline")

	# In zone_gate_3d._unhandled_input(): `if not _player_in_range or _is_unlocked: return`.
	# Because _is_unlocked is true, subsequent KEY_E is dropped!
	_assert_chall(gate_server._is_unlocked == true, "3.6 Gate unlocked state safely absorbed synthetic KEY_E without glitch")

	tc_inst.unregister_interactable(gate_server)
	await process_frame

	# 3.3 Laptop Overlay Toggle Dispatch Idempotency
	var main_inst = main_3d_scene.instantiate() as Main3D
	root.add_child(main_inst)
	await process_frame

	var live_tc = main_inst.find_child("TouchControls", true, false) as TouchControls
	_assert_chall(live_tc != null, "3.7 TouchControls mounted in Main3D")
	_assert_chall(not main_inst.is_hud_overlay_open(), "3.8 HUD overlay initially closed")

	if live_tc != null:
		# First tap opens overlay
		live_tc.trigger_laptop_toggle()
		await process_frame
		_assert_chall(main_inst.is_hud_overlay_open(), "3.9 First tap cleanly opened HUD overlay")

		# Second tap closes overlay
		live_tc.trigger_laptop_toggle()
		await process_frame
		_assert_chall(not main_inst.is_hud_overlay_open(), "3.10 Second tap cleanly closed HUD overlay without toggle thrashing")

	main_inst.queue_free()
	key_monitor.queue_free()
	npc_alex.queue_free()
	gate_server.queue_free()
	npc_bob.queue_free()
	tc_inst.queue_free()
	await process_frame
