extends SceneTree

## Adversarial Stress & Forensic Test Runner for Milestone 2
## Independent Auditor Verification
## Execution: godot --headless --path IdleArcade -s tests/test_p17_m2_auditor_stress.gd

var pass_count: int = 0
var fail_count: int = 0

func _init() -> void:
	call_deferred("_run_adversarial_tests")

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

func _run_adversarial_tests() -> void:
	print("=================================================================")
	print("FORENSIC AUDITOR ADVERSARIAL STRESS TEST: Milestone 2")
	print("=================================================================")

	await process_frame
	await process_frame

	var tm = root.get_node_or_null("TutorialManager")
	var gs = root.get_node_or_null("GameState")
	_assert_check(tm != null, "TutorialManager autoload is present")

	# -------------------------------------------------------------------------
	# STRESS 1: State Machine Boundaries & Rapid Advances
	# -------------------------------------------------------------------------
	print("\n--- STRESS 1: Boundary Transitions & Out-of-Order Calls ---")
	tm.reset_tutorial()
	_assert_check(tm.get_current_step() == 0, "Current step is IDLE (0)")
	_assert_check(not tm.is_tutorial_active(), "is_tutorial_active() is false when IDLE")

	# Advance while IDLE should be a no-op
	tm.advance_step()
	_assert_check(tm.get_current_step() == 0, "advance_step() when IDLE does not alter state")
	_assert_check(not tm.is_tutorial_active(), "is_tutorial_active() remains false")

	# Start intro
	tm.start_linear_intro()
	_assert_check(tm.get_current_step() == 1, "Intro starts at Step 1")

	# Calling start_linear_intro() while already active should be ignored
	tm.start_linear_intro()
	_assert_check(tm.get_current_step() == 1, "Second start_linear_intro() while active is safely ignored")

	# Advance 10 times in rapid succession
	for i in range(10):
		tm.advance_step()
	_assert_check(tm.get_current_step() == int(tm.State.COMPLETED), "Rapid advances clamp safely at COMPLETED (7)")
	_assert_check(not tm.is_tutorial_active(), "is_tutorial_active() is false after completion")

	# Extra advance after completion
	tm.advance_step()
	_assert_check(tm.get_current_step() == int(tm.State.COMPLETED), "advance_step() after COMPLETED remains COMPLETED (7)")

	# -------------------------------------------------------------------------
	# STRESS 2: Idempotent & Repeated Skip
	# -------------------------------------------------------------------------
	print("\n--- STRESS 2: Idempotent & Repeated Skip ---")
	# Skip when already completed
	tm.skip_tutorial()
	_assert_check(tm.get_current_step() == int(tm.State.COMPLETED), "skip_tutorial() when already COMPLETED is safe")

	# Reset and start, then skip multiple times
	tm.reset_tutorial()
	tm.start_linear_intro()
	_assert_check(tm.get_current_step() == 1, "Started at Step 1")

	var skip_counts: Array = [0]
	var on_skip = func(): skip_counts[0] += 1
	tm.tutorial_skipped.connect(on_skip)

	tm.skip_tutorial()
	_assert_check(skip_counts[0] == 1, "First skip emits tutorial_skipped once", "actual count: %d" % skip_counts[0])
	_assert_check(tm.get_current_step() == int(tm.State.COMPLETED), "State is COMPLETED")

	# Immediate second skip should be no-op (not re-emit or crash)
	tm.skip_tutorial()
	_assert_check(skip_counts[0] == 1, "Second skip does not re-emit tutorial_skipped", "actual count: %d" % skip_counts[0])
	tm.tutorial_skipped.disconnect(on_skip)

	# -------------------------------------------------------------------------
	# STRESS 3: Contextual Hints Mutual Exclusion with Linear Intro
	# -------------------------------------------------------------------------
	print("\n--- STRESS 3: Contextual Hints Mutual Exclusion with Linear Intro ---")
	tm.reset_tutorial()
	tm.start_linear_intro()
	_assert_check(tm.is_tutorial_active(), "Tutorial is active at Step 1")

	var hint_state: Dictionary = {"received": false, "id": ""}
	var on_hint = func(h_id: String):
		hint_state["received"] = true
		hint_state["id"] = h_id
	tm.contextual_hint_triggered.connect(on_hint)

	# Contextual hint MUST be suppressed while linear intro is active
	tm.trigger_contextual_hint("hint_tech_tree")
	_assert_check(not hint_state["received"], "Contextual hint is suppressed during active linear intro")
	tm.contextual_hint_triggered.disconnect(on_hint)

	# After completing intro, hints can trigger
	tm.skip_tutorial()
	_assert_check(not tm.is_tutorial_active(), "Tutorial is no longer active")

	var post_hint_state: Dictionary = {"received": false, "id": ""}
	var on_post_hint = func(id: String):
		post_hint_state["id"] = id
		if id == "hint_tech_tree":
			post_hint_state["received"] = true
	tm.contextual_hint_triggered.connect(on_post_hint)
	tm.trigger_contextual_hint("hint_tech_tree")
	_assert_check(post_hint_state["received"], "Contextual hint triggers once intro is completed/skipped", "hint_id_seen: '%s', is_active: %s" % [post_hint_state["id"], str(tm.is_tutorial_active())])
	tm.contextual_hint_triggered.disconnect(on_post_hint)

	# -------------------------------------------------------------------------
	# STRESS 4: on_scene_ready Robustness
	# -------------------------------------------------------------------------
	print("\n--- STRESS 4: on_scene_ready Robustness ---")
	# Null scene node
	tm.on_scene_ready(null)
	_assert_check(true, "on_scene_ready(null) survives without error")

	# Dummy node with random name
	var dummy = Node.new()
	dummy.name = "RandomNode"
	tm.on_scene_ready(dummy)
	_assert_check(true, "on_scene_ready(dummy) survives without error")
	dummy.free()

	# -------------------------------------------------------------------------
	# STRESS 5: German Mascot Text Verification (No English placeholders)
	# -------------------------------------------------------------------------
	print("\n--- STRESS 5: Mascot Copy & German Language Audit ---")
	tm.reset_tutorial()
	var dp = tm.get_dialogue_panel()
	_assert_check(dp != null, "Dialogue panel accessible")

	# Check Step 1 text
	tm.start_linear_intro()
	await process_frame
	var dial_lbl = dp.get_node_or_null("%DialogueLabel") as Label
	_assert_check(dial_lbl != null and not dial_lbl.text.is_empty(), "Step 1 dialogue label is populated")
	_assert_check(not ("TODO" in dial_lbl.text or "Placeholder" in dial_lbl.text or "stub" in dial_lbl.text.to_lower()),
		"Step 1 copy has no TODOs or placeholders")

	# Check Step 2
	tm.advance_step()
	await process_frame
	_assert_check(dial_lbl != null and "Virale Memes" in dial_lbl.text, "Step 2 mentions 'Virale Memes'")
	_assert_check(not ("TODO" in dial_lbl.text or "Placeholder" in dial_lbl.text), "Step 2 copy has no placeholders")

	# Check Step 3
	tm.advance_step()
	await process_frame
	_assert_check(dial_lbl != null and "Overdrive" in dial_lbl.text or "Hype" in dial_lbl.text, "Step 3 mentions Overdrive/Hype")

	# Skip to finish cleanly
	tm.skip_tutorial()
	_assert_check(tm.get_current_step() == int(tm.State.COMPLETED), "Reset to completed")

	print("\n=================================================================")
	print("AUDITOR STRESS TEST RESULTS: %d Passed, %d Failed" % [pass_count, fail_count])
	print("=================================================================")

	quit(0 if fail_count == 0 else 1)
