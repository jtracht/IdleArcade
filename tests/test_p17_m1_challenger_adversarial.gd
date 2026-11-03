extends SceneTree

## Empirical Adversarial Challenge Test Suite for Milestone 1
## Target: scripts/ui/tutorial_overlay.gd & scenes/ui/tutorial_overlay.tscn
## Execution: godot --headless --path IdleArcade -s tests/test_p17_m1_challenger_adversarial.gd

var pass_count: int = 0
var fail_count: int = 0

const TutorialOverlayScript = preload("res://scripts/ui/tutorial_overlay.gd")
const TutorialOverlayScene = preload("res://scenes/ui/tutorial_overlay.tscn")

func _init() -> void:
	call_deferred("_run_adversarial_suite")

func _record(condition: bool, test_name: String, detail: String = "") -> void:
	if condition:
		print("  [PASS] %s" % test_name)
		pass_count += 1
	else:
		var msg = "  [FAIL] %s" % test_name
		if detail != "":
			msg += " -> Detail: %s" % detail
		printerr(msg)
		fail_count += 1

func _run_adversarial_suite() -> void:
	print("=================================================================")
	print("CHALLENGER 1 EMPIRICAL ADVERSARIAL SUITE - Phase 17 Milestone 1")
	print("Stress-testing 4-blocker geometry, arrow transforms, skip button")
	print("=================================================================")

	var overlay = TutorialOverlayScene.instantiate()
	root.add_child(overlay)

	var vp_dims: Vector2 = overlay.get_viewport_dimensions()
	var vp_w: float = vp_dims.x
	var vp_h: float = vp_dims.y
	var expected_total_area: float = vp_w * vp_h

	print("[Info] Viewport dimensions under test: %s (Total Area: %d px^2)" % [str(vp_dims), int(expected_total_area)])

	# =========================================================================
	# SUITE 1: Target Rect Boundary, Corner & Off-screen Geometry Partitioning
	# =========================================================================
	print("\n--- SUITE 1: Target Rect Boundary, Corner & Extreme Off-screen Tests ---")

	var boundary_test_cases: Array[Dictionary] = [
		{"name": "Target at Top-Left Corner (0,0)", "rect": Rect2(0, 0, 100, 100), "pad": 0.0},
		{"name": "Target at Top-Right Corner (620,0)", "rect": Rect2(620, 0, 100, 100), "pad": 0.0},
		{"name": "Target at Bottom-Left Corner (0,1180)", "rect": Rect2(0, 1180, 100, 100), "pad": 0.0},
		{"name": "Target at Bottom-Right Corner (620,1180)", "rect": Rect2(620, 1180, 100, 100), "pad": 0.0},
		{"name": "Target covering EXACT Full Viewport (0,0,720,1280)", "rect": Rect2(0, 0, 720, 1280), "pad": 0.0},
		{"name": "Target covering Full Viewport with padding=16", "rect": Rect2(0, 0, 720, 1280), "pad": 16.0},
		{"name": "Target exceeding Viewport on all sides", "rect": Rect2(-100, -100, 1000, 1500), "pad": 8.0},
		{"name": "Target with 0 width (300, 500, 0, 100)", "rect": Rect2(300, 500, 0, 100), "pad": 0.0},
		{"name": "Target with 0 height (300, 500, 100, 0)", "rect": Rect2(300, 500, 100, 0), "pad": 0.0},
		{"name": "Target with 0 width and 0 height (360, 640, 0, 0)", "rect": Rect2(360, 640, 0, 0), "pad": 0.0},
		{"name": "Target with 0 width and 0 height at origin (0, 0, 0, 0)", "rect": Rect2(0, 0, 0, 0), "pad": 0.0},
		{"name": "Target with 0 width and 0 height at bottom-right (720, 1280, 0, 0)", "rect": Rect2(720, 1280, 0, 0), "pad": 0.0},
		{"name": "Partially off-screen Left", "rect": Rect2(-50, 400, 100, 100), "pad": 8.0},
		{"name": "Completely off-screen Left", "rect": Rect2(-300, 400, 100, 100), "pad": 8.0},
		{"name": "Partially off-screen Top", "rect": Rect2(300, -50, 100, 100), "pad": 8.0},
		{"name": "Completely off-screen Top", "rect": Rect2(300, -300, 100, 100), "pad": 8.0},
		{"name": "Partially off-screen Right", "rect": Rect2(680, 400, 100, 100), "pad": 8.0},
		{"name": "Completely off-screen Right", "rect": Rect2(1000, 400, 100, 100), "pad": 8.0},
		{"name": "Partially off-screen Bottom", "rect": Rect2(300, 1240, 100, 100), "pad": 8.0},
		{"name": "Completely off-screen Bottom", "rect": Rect2(300, 1500, 100, 100), "pad": 8.0},
		{"name": "Negative size (inverted rect)", "rect": Rect2(300, 400, -50, -50), "pad": 8.0},
		{"name": "Astronomical negative coordinates", "rect": Rect2(-999999, -999999, 100, 100), "pad": 8.0},
		{"name": "Astronomical positive coordinates", "rect": Rect2(999999, 999999, 100, 100), "pad": 8.0},
		{"name": "Flush Left edge (X=0)", "rect": Rect2(0, 200, 80, 80), "pad": 0.0},
		{"name": "Flush Right edge (X=720)", "rect": Rect2(640, 200, 80, 80), "pad": 0.0},
		{"name": "Flush Top edge (Y=0)", "rect": Rect2(200, 0, 80, 80), "pad": 0.0},
		{"name": "Flush Bottom edge (Y=1280)", "rect": Rect2(200, 1200, 80, 80), "pad": 0.0},
		{"name": "Negative padding stress", "rect": Rect2(200, 200, 100, 100), "pad": -10.0},
		{"name": "Huge padding covering viewport", "rect": Rect2(360, 640, 50, 50), "pad": 800.0},
	]

	for tc in boundary_test_cases:
		overlay.highlight_target_rect(tc.rect, tc.pad)
		var b_rects = overlay.get_blocker_rects()
		var cutout = overlay.get_cutout_rect()

		var top_r: Rect2 = b_rects["top"]
		var bot_r: Rect2 = b_rects["bottom"]
		var left_r: Rect2 = b_rects["left"]
		var right_r: Rect2 = b_rects["right"]

		# 1. Non-negativity of positions
		var pos_ok: bool = (
			top_r.position.x >= 0.0 and top_r.position.y >= 0.0 and
			bot_r.position.x >= 0.0 and bot_r.position.y >= 0.0 and
			left_r.position.x >= 0.0 and left_r.position.y >= 0.0 and
			right_r.position.x >= 0.0 and right_r.position.y >= 0.0 and
			cutout.position.x >= 0.0 and cutout.position.y >= 0.0
		)
		_record(pos_ok, "%s -> Non-negative positions" % tc.name,
			"top=%s bot=%s left=%s right=%s cutout=%s" % [str(top_r.position), str(bot_r.position), str(left_r.position), str(right_r.position), str(cutout.position)])

		# 2. Non-negativity of sizes
		var size_ok: bool = (
			top_r.size.x >= 0.0 and top_r.size.y >= 0.0 and
			bot_r.size.x >= 0.0 and bot_r.size.y >= 0.0 and
			left_r.size.x >= 0.0 and left_r.size.y >= 0.0 and
			right_r.size.x >= 0.0 and right_r.size.y >= 0.0 and
			cutout.size.x >= 0.0 and cutout.size.y >= 0.0
		)
		_record(size_ok, "%s -> Non-negative sizes" % tc.name,
			"top=%s bot=%s left=%s right=%s cutout=%s" % [str(top_r.size), str(bot_r.size), str(left_r.size), str(right_r.size), str(cutout.size)])

		# 3. No NaN or Inf
		var nan_inf_ok: bool = not (
			is_nan(top_r.position.x) or is_nan(top_r.position.y) or is_nan(top_r.size.x) or is_nan(top_r.size.y) or
			is_nan(bot_r.position.x) or is_nan(bot_r.position.y) or is_nan(bot_r.size.x) or is_nan(bot_r.size.y) or
			is_nan(left_r.position.x) or is_nan(left_r.position.y) or is_nan(left_r.size.x) or is_nan(left_r.size.y) or
			is_nan(right_r.position.x) or is_nan(right_r.position.y) or is_nan(right_r.size.x) or is_nan(right_r.size.y) or
			is_nan(cutout.position.x) or is_nan(cutout.position.y) or is_nan(cutout.size.x) or is_nan(cutout.size.y) or
			is_inf(top_r.size.x) or is_inf(top_r.size.y)
		)
		_record(nan_inf_ok, "%s -> No NaN or Inf" % tc.name)

		# 4. Exact Area Partition Invariant: sum of 4 blockers + cutout == viewport area
		var a_top = top_r.size.x * top_r.size.y
		var a_bot = bot_r.size.x * bot_r.size.y
		var a_left = left_r.size.x * left_r.size.y
		var a_right = right_r.size.x * right_r.size.y
		var a_cutout = cutout.size.x * cutout.size.y
		var total_sum = a_top + a_bot + a_left + a_right + a_cutout

		var area_ok: bool = is_equal_approx(total_sum, expected_total_area)
		_record(area_ok, "%s -> Exact area partition (sum = %.1f / %.1f)" % [tc.name, total_sum, expected_total_area],
			"diff = %f" % (total_sum - expected_total_area))

		# 5. Non-overlapping invariant: pairwise intersection of any 2 non-zero rects must be 0 area
		var rect_list = [top_r, bot_r, left_r, right_r, cutout]
		var overlap_detected: bool = false
		for i in range(rect_list.size()):
			for j in range(i + 1, rect_list.size()):
				var r1: Rect2 = rect_list[i]
				var r2: Rect2 = rect_list[j]
				if r1.size.x > 0.0 and r1.size.y > 0.0 and r2.size.x > 0.0 and r2.size.y > 0.0:
					var inter = r1.intersection(r2)
					if inter.size.x > 0.001 and inter.size.y > 0.001:
						var inter_area = inter.size.x * inter.size.y
						overlap_detected = true
						printerr("Overlap between [%d] and [%d]: area=%.2f" % [i, j, inter_area])
		_record(not overlap_detected, "%s -> Zero overlap between blockers and cutout" % tc.name)

	# =========================================================================
	# SUITE 1B: Massive 500-Rect Fuzzing Generator
	# =========================================================================
	print("\n--- SUITE 1B: Fuzzing Generator (500 Randomized Rects) ---")
	var rng = RandomNumberGenerator.new()
	rng.seed = 133742
	var fuzz_failures: int = 0

	for f in range(500):
		var rx = rng.randf_range(-500.0, 1200.0)
		var ry = rng.randf_range(-500.0, 1800.0)
		var rw = rng.randf_range(-100.0, 1000.0)
		var rh = rng.randf_range(-100.0, 1500.0)
		var rpad = rng.randf_range(-20.0, 60.0)

		overlay.highlight_target_rect(Rect2(rx, ry, rw, rh), rpad)
		var b_rects = overlay.get_blocker_rects()
		var cutout = overlay.get_cutout_rect()

		var a_sum = (b_rects["top"].size.x * b_rects["top"].size.y) + \
					(b_rects["bottom"].size.x * b_rects["bottom"].size.y) + \
					(b_rects["left"].size.x * b_rects["left"].size.y) + \
					(b_rects["right"].size.x * b_rects["right"].size.y) + \
					(cutout.size.x * cutout.size.y)

		if not is_equal_approx(a_sum, expected_total_area):
			fuzz_failures += 1
		if cutout.position.x < 0.0 or cutout.position.y < 0.0:
			fuzz_failures += 1

	_record(fuzz_failures == 0, "500 Randomized Fuzzing Rects passed area & non-negativity invariant",
		"fuzz_failures=%d" % fuzz_failures)

	# =========================================================================
	# SUITE 2: Arrow Indicator Transform Stress Tests
	# =========================================================================
	print("\n--- SUITE 2: Arrow Indicator Transform Stress Tests ---")

	# Requirement 2.1: Target in exact center (Y = 640)
	var center_target = Rect2(300, 600, 120, 80) # center is (360, 640)
	var t_center = overlay.calculate_arrow_transform(center_target, vp_dims)
	_record(t_center.position.x >= 40.0 and t_center.position.x <= vp_w - 40.0,
		"Center target: Arrow X clamped in [40, 680] (actual: %.1f)" % t_center.position.x)
	_record(t_center.position.y >= 40.0 and t_center.position.y <= vp_h - 40.0,
		"Center target: Arrow Y clamped in [40, 1240] (actual: %.1f)" % t_center.position.y)
	_record(t_center.direction == Vector2.UP,
		"Center target (Y=640 <= 640): Direction is UP (points to lower half boundary)", str(t_center.direction))
	_record(is_equal_approx(t_center.rotation, -PI * 0.5),
		"Center target: Rotation is -PI/2 (actual: %f)" % t_center.rotation)

	# Target infinitesimally below center (Y = 640.01)
	var slightly_below_target = Rect2(300, 600.02, 120, 80) # center is (360, 640.02)
	var t_below = overlay.calculate_arrow_transform(slightly_below_target, vp_dims)
	_record(t_below.direction == Vector2.DOWN,
		"Target Y > 640.0: Direction switches cleanly to DOWN", str(t_below.direction))
	_record(t_below.position.y >= 40.0 and t_below.position.y <= vp_h - 40.0,
		"Target Y > 640.0: Arrow Y clamped in [40, 1240] (actual: %.1f)" % t_below.position.y)

	# Requirement 2.2: Target at extreme top (Y = 5)
	var extreme_top_target = Rect2(200, 0, 100, 10) # center is (250, 5)
	var t_top = overlay.calculate_arrow_transform(extreme_top_target, vp_dims)
	_record(t_top.position.x >= 40.0 and t_top.position.x <= vp_w - 40.0,
		"Extreme top (Y=5): Arrow X within safe bounds (actual: %.1f)" % t_top.position.x)
	_record(t_top.position.y >= 40.0 and t_top.position.y <= vp_h - 40.0,
		"Extreme top (Y=5): Arrow Y within safe bounds (actual: %.1f)" % t_top.position.y)
	_record(t_top.direction == Vector2.UP,
		"Extreme top (Y=5): Arrow direction is UP", str(t_top.direction))
	_record(t_top.position.y > extreme_top_target.end.y,
		"Extreme top: Arrow sits below target (actual arrow Y: %.1f, target end Y: %.1f)" % [t_top.position.y, extreme_top_target.end.y])

	# Requirement 2.3: Target at extreme bottom (Y = 1275)
	var extreme_bottom_target = Rect2(200, 1270, 100, 10) # center is (250, 1275)
	var t_bot = overlay.calculate_arrow_transform(extreme_bottom_target, vp_dims)
	_record(t_bot.position.x >= 40.0 and t_bot.position.x <= vp_w - 40.0,
		"Extreme bottom (Y=1275): Arrow X within safe bounds (actual: %.1f)" % t_bot.position.x)
	_record(t_bot.position.y >= 40.0 and t_bot.position.y <= vp_h - 40.0,
		"Extreme bottom (Y=1275): Arrow Y within safe bounds (actual: %.1f)" % t_bot.position.y)
	_record(t_bot.direction == Vector2.DOWN,
		"Extreme bottom (Y=1275): Arrow direction is DOWN", str(t_bot.direction))
	_record(t_bot.position.y < extreme_bottom_target.position.y,
		"Extreme bottom: Arrow sits above target (actual arrow Y: %.1f, target top Y: %.1f)" % [t_bot.position.y, extreme_bottom_target.position.y])

	# Target at extreme Left (X = 5)
	var extreme_left_target = Rect2(0, 500, 10, 100) # center X = 5
	var t_left = overlay.calculate_arrow_transform(extreme_left_target, vp_dims)
	_record(t_left.position.x >= 40.0,
		"Extreme left (X=5): Arrow X clamped to margin >= 40px (actual: %.1f)" % t_left.position.x)

	# Target at extreme Right (X = 715)
	var extreme_right_target = Rect2(710, 500, 10, 100) # center X = 715
	var t_right = overlay.calculate_arrow_transform(extreme_right_target, vp_dims)
	_record(t_right.position.x <= vp_w - 40.0,
		"Extreme right (X=715): Arrow X clamped to margin <= 680px (actual: %.1f)" % t_right.position.x)

	# Target spanning full screen height (Y=0 to 1280) -> Stress flip logic
	var full_height_target = Rect2(200, 0, 100, 1280)
	var t_full_h = overlay.calculate_arrow_transform(full_height_target, vp_dims)
	_record(t_full_h.position.y >= 40.0 and t_full_h.position.y <= vp_h - 40.0,
		"Full-height target: Arrow clamped within viewport [40, 1240] (actual: %.1f)" % t_full_h.position.y)

	# Arrow animation bounce stress: step 100 frames across full cycle
	overlay.highlight_target_rect(extreme_top_target)
	var arrow_ctrl: Control = overlay.get_node_or_null("%ArrowIndicator")
	var bounce_out_of_bounds: bool = false
	for frame in range(100):
		overlay._process(0.016) # ~60fps step
		if arrow_ctrl.position.x < 0.0 or arrow_ctrl.position.x > vp_w or \
		   arrow_ctrl.position.y < 0.0 or arrow_ctrl.position.y > vp_h:
			bounce_out_of_bounds = true
			printerr("Arrow bounced out of bounds at frame %d: pos=%s" % [frame, str(arrow_ctrl.position)])

	_record(not bounce_out_of_bounds, "Arrow animation bounce never pushes position out of [0, 720] x [0, 1280]")

	# =========================================================================
	# SUITE 3: Skip Button Dimensions & Signal Contracts
	# =========================================================================
	print("\n--- SUITE 3: Skip Button Ergonomics & Signal Contracts ---")
	var skip_btn: Button = overlay.get_skip_button()
	_record(skip_btn != null, "Skip button reference exists via get_skip_button()")

	if skip_btn != null:
		# Dimension checks: >= 56px
		_record(skip_btn.custom_minimum_size.x >= 56.0,
			"SkipButton custom_minimum_size width >= 56px (actual: %.1f)" % skip_btn.custom_minimum_size.x)
		_record(skip_btn.custom_minimum_size.y >= 56.0,
			"SkipButton custom_minimum_size height >= 56px (actual: %.1f)" % skip_btn.custom_minimum_size.y)
		_record(skip_btn.custom_minimum_size == Vector2(140, 56),
			"SkipButton exact minimum size is Vector2(140, 56)")

		# Offset dimensions check
		var rendered_width = skip_btn.offset_right - skip_btn.offset_left
		var rendered_height = skip_btn.offset_bottom - skip_btn.offset_top
		_record(rendered_width >= 56.0,
			"SkipButton offset width >= 56px (actual: %.1f)" % rendered_width)
		_record(rendered_height >= 56.0,
			"SkipButton offset height >= 56px (actual: %.1f)" % rendered_height)

		# Touch isolation check
		_record(skip_btn.mouse_filter == Control.MOUSE_FILTER_STOP,
			"SkipButton mouse_filter is STOP (0) to block click-through")

		# Signal emission test: 5 sequential clicks
		var emitted_box: Array = [0]
		var callback = func(): emitted_box[0] += 1
		overlay.skip_pressed.connect(callback)

		for click in range(5):
			skip_btn.pressed.emit()

		_record(emitted_box[0] == 5,
			"Skip button pressed 5 times emitted exactly 5 skip_pressed signals (actual: %d)" % emitted_box[0])
		overlay.skip_pressed.disconnect(callback)

	# =========================================================================
	# SUITE 4: Control Node Highlighting & Dynamic Tracking
	# =========================================================================
	print("\n--- SUITE 4: Control Node Highlighting & Dynamic Tracking ---")
	var dummy_control = Control.new()
	dummy_control.name = "DummyReactor"
	dummy_control.position = Vector2(150, 250)
	dummy_control.size = Vector2(80, 80)
	root.add_child(dummy_control)

	overlay.highlight_control(dummy_control, 10.0)
	var tracked_cutout = overlay.get_cutout_rect()
	_record(tracked_cutout.position == Vector2(140, 240) and tracked_cutout.size == Vector2(100, 100),
		"highlight_control sets correct padded cutout (140, 240, 100, 100)")

	# Dynamic move
	dummy_control.position = Vector2(250, 350)
	overlay._process(0.016)
	var updated_cutout = overlay.get_cutout_rect()
	_record(updated_cutout.position == Vector2(240, 340),
		"highlight_control automatically tracks moved Control position")

	# Safe detachment
	dummy_control.queue_free()
	overlay._process(0.016) # Should not crash on invalid instance
	_record(true, "_process() handles freed Control safely without crashing")

	# Cleanup
	overlay.queue_free()

	# Summary
	print("\n=================================================================")
	print("CHALLENGER 1 ADVERSARIAL SUITE SUMMARY: %d PASSED, %d FAILED" % [pass_count, fail_count])
	print("=================================================================")

	quit(0 if fail_count == 0 else 1)
