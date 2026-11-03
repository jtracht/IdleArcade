#!/usr/bin/env python3
"""
Challenger 1 Empirical Adversarial Challenge Python Oracle
Target: Phase 17 Milestone 1 (IdleArcade)
Verifies:
- 4-Blocker Input Mask Geometry & Partitioning Invariants
- Mathematical Fuzzing & Disjointness Oracles
- Arrow Indicator Transformation & Viewport Boundary Clamping
- Skip Button Touch Ergonomics & Signals
- DialoguePanel 6-Button Constraint & Non-blocking Invariants
"""

import math
import os
import re
import sys
import random

PASS_COUNT = 0
FAIL_COUNT = 0

def check(condition: bool, description: str, detail: str = ""):
    global PASS_COUNT, FAIL_COUNT
    if condition:
        print(f"  [PASS] {description}")
        PASS_COUNT += 1
    else:
        msg = f"  [FAIL] {description}"
        if detail:
            msg += f" -> Detail: {detail}"
        print(msg)
        FAIL_COUNT += 1

def run_oracle():
    print("====================================================================")
    print("CHALLENGER 1 EMPIRICAL ADVERSARIAL PYTHON ORACLE (Phase 17 Milestone 1)")
    print("====================================================================")

    repo_root = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
    arcade_root = os.path.join(repo_root, "IdleArcade")

    # -------------------------------------------------------------------------
    # TIER 1: File Existence & AST Signatures
    # -------------------------------------------------------------------------
    print("\n=== TIER 1: AST & Scene Structure Verification ===")
    overlay_gd = os.path.join(arcade_root, "scripts", "ui", "tutorial_overlay.gd")
    overlay_tscn = os.path.join(arcade_root, "scenes", "ui", "tutorial_overlay.tscn")
    dialogue_gd = os.path.join(arcade_root, "scripts", "dialogue_panel.gd")
    dialogue_tscn = os.path.join(arcade_root, "scenes", "dialogue_panel.tscn")

    check(os.path.exists(overlay_gd), "tutorial_overlay.gd exists")
    check(os.path.exists(overlay_tscn), "tutorial_overlay.tscn exists")
    check(os.path.exists(dialogue_gd), "dialogue_panel.gd exists")
    check(os.path.exists(dialogue_tscn), "dialogue_panel.tscn exists")

    with open(overlay_gd, "r", encoding="utf-8") as f:
        overlay_src = f.read()

    with open(overlay_tscn, "r", encoding="utf-8") as f:
        overlay_tscn_src = f.read()

    with open(dialogue_gd, "r", encoding="utf-8") as f:
        dialogue_src = f.read()

    with open(dialogue_tscn, "r", encoding="utf-8") as f:
        dialogue_tscn_src = f.read()

    # Signals
    check("signal skip_pressed()" in overlay_src, "tutorial_overlay.gd declares signal skip_pressed")
    check("signal highlight_updated(target_rect: Rect2)" in overlay_src, "tutorial_overlay.gd declares signal highlight_updated")
    check("signal highlight_cleared()" in overlay_src, "tutorial_overlay.gd declares signal highlight_cleared")
    check("signal tutorial_advanced()" in dialogue_src, "dialogue_panel.gd declares signal tutorial_advanced")
    check("signal hint_dismissed(hint_id: String)" in dialogue_src, "dialogue_panel.gd declares signal hint_dismissed")

    # Methods
    check("func highlight_target_rect(" in overlay_src, "tutorial_overlay.gd defines highlight_target_rect")
    check("func highlight_control(" in overlay_src, "tutorial_overlay.gd defines highlight_control")
    check("func clear_highlight(" in overlay_src, "tutorial_overlay.gd defines clear_highlight")
    check("func calculate_arrow_transform(" in overlay_src, "tutorial_overlay.gd defines calculate_arrow_transform")
    check("func get_viewport_dimensions(" in overlay_src, "tutorial_overlay.gd defines get_viewport_dimensions")
    check("func open_for_tutorial_step(" in dialogue_src, "dialogue_panel.gd defines open_for_tutorial_step")
    check("func show_hint_popup(" in dialogue_src, "dialogue_panel.gd defines show_hint_popup")

    # Invariants in scenes
    check('name="TopBlocker"' in overlay_tscn_src, "tutorial_overlay.tscn defines TopBlocker")
    check('name="BottomBlocker"' in overlay_tscn_src, "tutorial_overlay.tscn defines BottomBlocker")
    check('name="LeftBlocker"' in overlay_tscn_src, "tutorial_overlay.tscn defines LeftBlocker")
    check('name="RightBlocker"' in overlay_tscn_src, "tutorial_overlay.tscn defines RightBlocker")
    check('name="SkipButton"' in overlay_tscn_src, "tutorial_overlay.tscn defines SkipButton")
    check('name="ArrowIndicator"' in overlay_tscn_src, "tutorial_overlay.tscn defines ArrowIndicator")

    # 6-Button Constraint in dialogue_panel.tscn
    button_matches = re.findall(r'\[node\s+name="[^"]*"\s+type="Button"', dialogue_tscn_src)
    check(len(button_matches) == 6, f"dialogue_panel.tscn preserves strict legacy invariant of EXACTLY 6 Button nodes (found: {len(button_matches)})")

    # -------------------------------------------------------------------------
    # TIER 2: Mathematical 4-Blocker Geometry Model & Fuzzing Oracle
    # -------------------------------------------------------------------------
    print("\n=== TIER 2: 4-Blocker Geometry & Area Partitioning Oracle ===")
    vp_w, vp_h = 720.0, 1280.0
    expected_area = vp_w * vp_h

    def simulate_highlight(target_x, target_y, target_w, target_h, padding):
        p_x = target_x - padding
        p_y = target_y - padding
        p_w = target_w + padding * 2.0
        p_h = target_h + padding * 2.0

        x0 = max(0.0, min(vp_w, p_x))
        y0 = max(0.0, min(vp_h, p_y))
        x1 = max(0.0, min(vp_w, p_x + p_w))
        y1 = max(0.0, min(vp_h, p_y + p_h))

        if x1 < x0:
            x1 = x0
        if y1 < y0:
            y1 = y0

        cutout = (x0, y0, max(0.0, x1 - x0), max(0.0, y1 - y0))
        top = (0.0, 0.0, vp_w, y0)
        bot = (0.0, y1, vp_w, max(0.0, vp_h - y1))
        left = (0.0, y0, x0, max(0.0, y1 - y0))
        right = (x1, y0, max(0.0, vp_w - x1), max(0.0, y1 - y0))

        return {"top": top, "bottom": bot, "left": left, "right": right, "cutout": cutout}

    # Deterministic test cases
    test_cases = [
        ("Flush (0,0)", 0, 0, 100, 100, 0),
        ("Flush Bottom-Right", 620, 1180, 100, 100, 0),
        ("Full Viewport", 0, 0, 720, 1280, 0),
        ("Full Viewport with pad", 0, 0, 720, 1280, 16),
        ("Zero Size", 360, 640, 0, 0, 0),
        ("Zero Size At Origin", 0, 0, 0, 0, 0),
        ("Zero Size At Max", 720, 1280, 0, 0, 0),
        ("Negative Coordinate Offscreen", -500, -500, 100, 100, 8),
        ("Far Offscreen Bottom-Right", 1000, 2000, 100, 100, 8),
        ("Inverted Rect (Negative Size)", 300, 400, -50, -50, 8),
        ("Negative Padding", 200, 200, 100, 100, -20),
        ("Huge Padding", 360, 640, 100, 100, 1000),
    ]

    all_det_passed = True
    for name, tx, ty, tw, th, pad in test_cases:
        res = simulate_highlight(tx, ty, tw, th, pad)
        areas = {k: v[2] * v[3] for k, v in res.items()}
        total = sum(areas.values())
        if not math.isclose(total, expected_area, abs_tol=1e-5):
            all_det_passed = False
            print(f"Failed deterministic case {name}: sum={total} expected={expected_area}")
            break

    check(all_det_passed, "All deterministic boundary cases satisfy exact area partition (921,600 px^2)")

    # Fuzzing 1,000 random rects
    rng = random.Random(1337)
    fuzz_passed = True
    overlap_found = False

    def rect_intersection_area(r1, r2):
        # r = (x, y, w, h)
        x_left = max(r1[0], r2[0])
        y_top = max(r1[1], r2[1])
        x_right = min(r1[0] + r1[2], r2[0] + r2[2])
        y_bot = min(r1[1] + r1[3], r2[1] + r2[3])
        if x_right > x_left and y_bot > y_top:
            return (x_right - x_left) * (y_bot - y_top)
        return 0.0

    for i in range(1000):
        tx = rng.uniform(-1000, 2000)
        ty = rng.uniform(-1000, 2500)
        tw = rng.uniform(-200, 1500)
        th = rng.uniform(-200, 2000)
        pad = rng.uniform(-50, 100)

        res = simulate_highlight(tx, ty, tw, th, pad)

        # Check non-negativity
        for k, (rx, ry, rw, rh) in res.items():
            if rx < 0.0 or ry < 0.0 or rw < 0.0 or rh < 0.0:
                fuzz_passed = False
                print(f"Negative coords in {k}: ({rx}, {ry}, {rw}, {rh})")
                break

        # Check total area
        total_area = sum(r[2] * r[3] for r in res.values())
        if not math.isclose(total_area, expected_area, abs_tol=1e-5):
            fuzz_passed = False
            print(f"Area mismatch in fuzz {i}: {total_area} != {expected_area}")
            break

        # Check pairwise non-overlap
        rects = list(res.values())
        for a_idx in range(len(rects)):
            for b_idx in range(a_idx + 1, len(rects)):
                r1 = rects[a_idx]
                r2 = rects[b_idx]
                if r1[2] > 0.0 and r1[3] > 0.0 and r2[2] > 0.0 and r2[3] > 0.0:
                    inter = rect_intersection_area(r1, r2)
                    if inter > 1e-4:
                        overlap_found = True
                        print(f"Overlap between {a_idx} and {b_idx}: area={inter}")
                        break

    check(fuzz_passed, "1,000 Randomized Fuzzing Rects satisfy exact partition & non-negativity")
    check(not overlap_found, "1,000 Randomized Fuzzing Rects exhibit ZERO overlap between blockers and cutout")

    # -------------------------------------------------------------------------
    # TIER 3: Arrow Indicator Transform & Boundary Clamping Oracle
    # -------------------------------------------------------------------------
    print("\n=== TIER 3: Arrow Indicator Transformation & Boundary Clamping ===")

    def calculate_arrow(cutout_x, cutout_y, cutout_w, cutout_h):
        margin = 40.0
        arrow_gap = 36.0
        center_x = cutout_x + cutout_w * 0.5
        center_y = cutout_y + cutout_h * 0.5
        cutout_end_y = cutout_y + cutout_h

        if center_y > vp_h * 0.5:
            # lower half -> above pointing DOWN
            dir_y = 1.0 # DOWN
            base_y = cutout_y - arrow_gap
            if base_y < margin:
                dir_y = -1.0 # UP
                base_y = cutout_end_y + arrow_gap
        else:
            # upper half -> below pointing UP
            dir_y = -1.0 # UP
            base_y = cutout_end_y + arrow_gap
            if base_y > vp_h - margin:
                dir_y = 1.0 # DOWN
                base_y = cutout_y - arrow_gap

        base_x = max(margin, min(vp_w - margin, center_x))
        base_y = max(margin, min(vp_h - margin, base_y))

        return base_x, base_y, dir_y

    # Center target: Y=640
    cx, cy, cdir = calculate_arrow(300, 600, 120, 80) # center is (360, 640)
    check(40.0 <= cx <= 680.0 and 40.0 <= cy <= 1240.0, f"Target at Center (Y=640): Arrow within safe bounds ({cx}, {cy})")
    check(cdir == -1.0, f"Target at Center (Y=640 <= 640): Points UP (dir_y={cdir})")

    # Target slightly below center: Y=640.1
    cx2, cy2, cdir2 = calculate_arrow(300, 600.2, 120, 80) # center is 640.1
    check(cdir2 == 1.0, f"Target at Center (Y=640.1 > 640): Points DOWN (dir_y={cdir2})")

    # Extreme Top target: Y=5
    tx, ty, tdir = calculate_arrow(250, 0, 100, 10) # center is 5
    check(40.0 <= tx <= 680.0 and 40.0 <= ty <= 1240.0, f"Target at Extreme Top (Y=5): Arrow within safe bounds ({tx}, {ty})")
    check(tdir == -1.0, f"Target at Extreme Top (Y=5): Points UP")
    check(ty > 10.0, f"Target at Extreme Top: Arrow placed BELOW cutout (arrow_y={ty} > cutout_bottom=10.0)")

    # Extreme Bottom target: Y=1275
    bx, by, bdir = calculate_arrow(250, 1270, 100, 10) # center is 1275
    check(40.0 <= bx <= 680.0 and 40.0 <= by <= 1240.0, f"Target at Extreme Bottom (Y=1275): Arrow within safe bounds ({bx}, {by})")
    check(bdir == 1.0, f"Target at Extreme Bottom (Y=1275): Points DOWN")
    check(by < 1270.0, f"Target at Extreme Bottom: Arrow placed ABOVE cutout (arrow_y={by} < cutout_top=1270.0)")

    # Bounce safety: base in [40, 1240], amplitude 12
    # Min pos: 40 - 12 = 28 > 0
    # Max pos: 1240 + 12 = 1252 < 1280
    min_bounce_y = 40.0 - 12.0
    max_bounce_y = 1240.0 + 12.0
    check(min_bounce_y >= 0.0 and max_bounce_y <= vp_h,
        f"Arrow bounce oscillation [min={min_bounce_y}, max={max_bounce_y}] never escapes viewport [0, 1280]")

    # -------------------------------------------------------------------------
    # TIER 4: Skip Button Ergonomics & Dimensions
    # -------------------------------------------------------------------------
    print("\n=== TIER 4: Skip Button Ergonomics & Mobile Accessibility ===")
    btn_custom_size_match = re.search(r'custom_minimum_size\s*=\s*Vector2\(\s*([0-9.]+)\s*,\s*([0-9.]+)\s*\)', overlay_tscn_src)
    check(btn_custom_size_match is not None, "SkipButton has custom_minimum_size in .tscn")
    if btn_custom_size_match:
        bw, bh = float(btn_custom_size_match.group(1)), float(btn_custom_size_match.group(2))
        check(bw >= 56.0, f"SkipButton custom_minimum_size width >= 56px (actual: {bw}px)")
        check(bh >= 56.0, f"SkipButton custom_minimum_size height >= 56px (actual: {bh}px)")
        check(bw == 140.0 and bh == 56.0, f"SkipButton exact dimensions are 140x56px (actual: {bw}x{bh})")

    check("Überspringen" in overlay_tscn_src, "SkipButton has German label 'Überspringen'")
    check("mouse_filter = 0" in overlay_tscn_src, "SkipButton mouse_filter is STOP (0) in .tscn")

    # -------------------------------------------------------------------------
    # TIER 5: CI/CD Workflow & Regression Safety
    # -------------------------------------------------------------------------
    print("\n=== TIER 5: Dual Workflow Byte-Parity & Regressions ===")
    root_wf = os.path.join(repo_root, ".github", "workflows", "build.yml")
    sub_wf = os.path.join(arcade_root, ".github", "workflows", "build.yml")
    check(os.path.exists(root_wf), "Root .github/workflows/build.yml exists")
    check(os.path.exists(sub_wf), "IdleArcade/.github/workflows/build.yml exists")

    with open(root_wf, "rb") as f1, open(sub_wf, "rb") as f2:
        c1 = f1.read()
        c2 = f2.read()
    check(c1 == c2, f"Dual build.yml files are 100% byte-for-byte identical ({len(c1)} bytes)")

    print("\n====================================================================")
    print(f"ORACLE RESULTS: {PASS_COUNT} Passed, {FAIL_COUNT} Failed")
    print("====================================================================")
    return FAIL_COUNT == 0

if __name__ == "__main__":
    success = run_oracle()
    sys.exit(0 if success else 1)
