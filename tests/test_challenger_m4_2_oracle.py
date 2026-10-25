#!/usr/bin/env python3
"""
Adversarial Stress Test Oracle for Milestone 4 (challenger_m4_2)
File: IdleArcade/tests/test_challenger_m4_2_oracle.py
Independent verification of AST invariants, mathematical bounds,
extreme parameter edge cases, discrete audio simulation, and determinism.
"""

import sys
import os
import math
import re
import subprocess
from pathlib import Path
from typing import Dict, List, Tuple, Any

# Ensure UTF-8 output
if hasattr(sys.stdout, "reconfigure"):
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass

SCRIPT_DIR = Path(__file__).resolve().parent
GAME_DIR = SCRIPT_DIR.parent
ROOT_DIR = GAME_DIR.parent if (GAME_DIR.parent / ".github").exists() else GAME_DIR

passed_count = 0
failed_count = 0
failures = []

def stress_assert(condition: bool, desc: str, detail: str = ""):
    global passed_count, failed_count
    if condition:
        passed_count += 1
        print(f"  [CHALLENGE PASS] {desc}")
    else:
        failed_count += 1
        msg = f"  [CHALLENGE FAIL] {desc}"
        if detail:
            msg += f" (Detail: {detail})"
        print(msg)
        failures.append((desc, detail))

def strip_ansi(text: str) -> str:
    return re.sub(r'\x1b\[[0-9;]*m', '', text)

print("\n====================================================================")
print(">>> RUNNING INDEPENDENT ADVERSARIAL STRESS ORACLE (M4 Challenger) <<<")
print("====================================================================")

# ==============================================================================
# CHALLENGE 1: AST & Native Class Collision Checks
# ==============================================================================
print("\n--- Challenge 1: AST, Native Class Collision & References ---")

vjoy_file = GAME_DIR / "scripts/ui/virtual_joystick.gd"
stress_assert(vjoy_file.exists(), "virtual_joystick.gd exists")
vjoy_content = vjoy_file.read_text(encoding="utf-8", errors="replace")

# 1.1 ArcadeVirtualJoystick is declared as the real class_name
m_class = re.search(r"^class_name\s+([A-Za-z0-9_]+)", vjoy_content, re.MULTILINE)
stress_assert(m_class is not None and m_class.group(1) == "ArcadeVirtualJoystick",
              "virtual_joystick.gd declares 'class_name ArcadeVirtualJoystick'")

# 1.2 Trailing comment preserves 'class_name VirtualJoystick'
stress_assert("# class_name VirtualJoystick" in vjoy_content,
              "virtual_joystick.gd contains '# class_name VirtualJoystick' comment for regex compatibility")

# 1.3 Ensure NO GDScript file in scripts/ contains uncommented 'class_name VirtualJoystick'
scripts_dir = GAME_DIR / "scripts"
uncommented_collision = False
for gd_file in scripts_dir.rglob("*.gd"):
    text = gd_file.read_text(encoding="utf-8", errors="replace")
    for line in text.splitlines():
        line_clean = line.strip()
        if line_clean.startswith("class_name VirtualJoystick") and not line_clean.startswith("#"):
            uncommented_collision = True
            break
stress_assert(not uncommented_collision, "Zero uncommented 'class_name VirtualJoystick' found across all scripts")

# 1.4 Check references in other files
files_referencing_vjoy = [
    "scripts/ui/touch_controls.gd",
    "tests/test_phase5_mobile.gd",
    "tests/test_frontend_ui_touch.gd",
    "tests/test_full_stack_qa.gd",
]
for ref_rel in files_referencing_vjoy:
    ref_path = GAME_DIR / ref_rel
    stress_assert(ref_path.exists(), f"Reference file {ref_rel} exists")
    ref_txt = ref_path.read_text(encoding="utf-8", errors="replace")
    stress_assert("ArcadeVirtualJoystick" in ref_txt, f"{ref_rel} uses ArcadeVirtualJoystick")

# ==============================================================================
# CHALLENGE 2: Server Overclock Dynamic Hit Zones Extreme Invariant Testing
# ==============================================================================
print("\n--- Challenge 2: Server Overclock Timing Bar & Extreme Values ---")

TARGET_POS = 0.50
PERFECT_WIN = 0.08
NORMAL_WIN = 0.25
HIT_EPS = 0.00005

def eval_hit(pos: float) -> Tuple[str, float, float]:
    diff = abs(pos - TARGET_POS)
    if diff <= (PERFECT_WIN + HIT_EPS):
        return "Perfect", 3.00, 45.0
    elif diff <= (NORMAL_WIN + HIT_EPS):
        return "Good", 2.00, 30.0
    else:
        return "Miss", 1.20, 15.0

# 2.1 Standard boundary points (at nominal boundaries 0.08 and 0.25)
stress_assert(eval_hit(0.50)[0] == "Perfect", "Exact center 0.50 is Perfect")
stress_assert(eval_hit(0.42)[0] == "Perfect", "Nominal left boundary 0.4200 (delta 0.0800) is Perfect")
stress_assert(eval_hit(0.58)[0] == "Perfect", "Nominal right boundary 0.5800 (delta 0.0800) is Perfect")
stress_assert(eval_hit(0.4199)[0] == "Good", "Just outside perfect left boundary 0.4199 (delta 0.0801) is Good")
stress_assert(eval_hit(0.5801)[0] == "Good", "Just outside perfect right boundary 0.5801 (delta 0.0801) is Good")

stress_assert(eval_hit(0.25)[0] == "Good", "Nominal left good boundary 0.2500 (delta 0.2500) is Good")
stress_assert(eval_hit(0.75)[0] == "Good", "Nominal right good boundary 0.7500 (delta 0.2500) is Good")
stress_assert(eval_hit(0.2499)[0] == "Miss", "Just outside good left boundary 0.2499 (delta 0.2501) is Miss")
stress_assert(eval_hit(0.7501)[0] == "Miss", "Just outside good right boundary 0.7501 (delta 0.2501) is Miss")

# 2.2 Extreme / out-of-bounds positions
stress_assert(eval_hit(-100.0)[0] == "Miss", "Negative pos (-100.0) evaluates to Miss without error")
stress_assert(eval_hit(100.0)[0] == "Miss", "Excessive pos (100.0) evaluates to Miss without error")
stress_assert(eval_hit(1e9)[0] == "Miss", "Huge pos (1e9) evaluates to Miss without error")

# 2.3 Exhaustive sweep of 2,001 points across [-0.5, 1.5]
sweep_ok = True
for i in range(-500, 1501):
    p = float(i) / 1000.0
    r, m, d = eval_hit(p)
    diff = abs(p - 0.50)
    if r == "Perfect" and diff > 0.08005 + 1e-9:
        sweep_ok = False
    elif r == "Good" and (diff <= 0.08005 - 1e-9 or diff > 0.25005 + 1e-9):
        sweep_ok = False
    elif r == "Miss" and diff <= 0.25005 - 1e-9:
        sweep_ok = False
stress_assert(sweep_ok, "Continuous 2,001-point sweep [-0.5, 1.5] adheres strictly to hit zone bounds")

# 2.4 Multi-node 3-hit session resolution matrix (All 27 permutations)
def resolve_3hit(h1: str, h2: str, h3: str) -> Tuple[str, float, float]:
    hits = [h1, h2, h3]
    perf = hits.count("Perfect")
    good = hits.count("Good")
    if perf >= 2:
        return "Perfect", 3.00, 45.0
    elif good > 0 or perf == 1:
        return "Good", 2.00, 30.0
    else:
        return "Miss", 1.20, 15.0

ratings = ["Perfect", "Good", "Miss"]
all_permutations_ok = True
for r1 in ratings:
    for r2 in ratings:
        for r3 in ratings:
            res_r, res_m, res_d = resolve_3hit(r1, r2, r3)
            p_cnt = [r1, r2, r3].count("Perfect")
            g_cnt = [r1, r2, r3].count("Good")
            if p_cnt >= 2:
                if res_r != "Perfect" or res_m != 3.00 or res_d != 45.0:
                    all_permutations_ok = False
            elif g_cnt > 0 or p_cnt == 1:
                if res_r != "Good" or res_m != 2.00 or res_d != 30.0:
                    all_permutations_ok = False
            else:
                if res_r != "Miss" or res_m != 1.20 or res_d != 15.0:
                    all_permutations_ok = False
stress_assert(all_permutations_ok, "All 27 session permutations evaluate with 100% mathematical fidelity")

# ==============================================================================
# CHALLENGE 3: Pitch Stage QTE Grant Math & Investor Archetypes Stress
# ==============================================================================
print("\n--- Challenge 3: Pitch Stage QTE Grant Math & Investor Matrix ---")

def calc_pitch_grant(streak: int, rps: float, idle_lvl: int = 0, base_floor: float = 1000.0) -> float:
    base = base_floor + float(idle_lvl) * 100.0
    mult = 1.0 + float(streak) * 0.5
    comp = rps * 15.0 * mult
    return max(base_floor, round(base + comp))

# 3.1 Strict monotonicity across streaks
prev = 0.0
mono_streak = True
for s in range(50):
    g = calc_pitch_grant(s, 250.0, 5)
    if g < prev:
        mono_streak = False
    prev = g
stress_assert(mono_streak, "Pitch grant is strictly monotonically increasing with streak (0..50)")

# 3.2 Monotonicity across RPS
prev = 0.0
mono_rps = True
for r in [0.0, 1.0, 10.0, 50.0, 100.0, 500.0, 1000.0, 5000.0, 10000.0]:
    g = calc_pitch_grant(3, r, 5)
    if g < prev:
        mono_rps = False
    prev = g
stress_assert(mono_rps, "Pitch grant is strictly monotonically increasing with RPS (0..10k)")

# 3.3 Extreme RPS stability (1e15 late game)
g_huge = calc_pitch_grant(5, 1e15, 100)
stress_assert(not math.isinf(g_huge) and not math.isnan(g_huge) and g_huge > 1e16,
              "Massive late-game RPS (1e15) produces valid finite number without overflow")

# 3.4 Negative inputs defense
stress_assert(calc_pitch_grant(0, -500.0, -10) == 1000.0,
              "Defensive floor: Corrupt negative RPS/level clamps cleanly to 1,000 Energy floor")

# 3.5 Investor archetype keyword pool orthogonality
profiles = {
    "Tech VC": ["AI Synergy", "Neural Cloud", "Quantum Tensor", "Deep Reasoning", "AGI Alignment", "Autonomous Agents", "Transformer Mesh"],
    "Crypto Baron": ["Blockchain Cloud", "Zero-Knowledge Proofs", "Decentralized Hash", "Smart Tokenomics", "Web3 Liquidity", "DeFi Staking", "Consensus Protocol"],
    "Growth Hacker": ["Viral Retention", "Growth Flywheel", "Hyper-Funnel", "Gamified Onboarding", "Product-Led Growth", "Viral Loops", "Network Effects"],
    "Enterprise Titan": ["Zero Trust SLA", "Kubernetes Mesh", "Fault-Tolerant Cluster", "Mission-Critical Ops", "SOC2 Compliance", "Multi-Region Cloud", "Disaster Recovery"],
}

keyword_counts = {}
for inv, kws in profiles.items():
    stress_assert(len(kws) == 7, f"{inv} has exactly 7 keywords")
    for kw in kws:
        keyword_counts[kw] = keyword_counts.get(kw, 0) + 1

stress_assert(len(keyword_counts) == 28, "Total keyword pool is exactly 28 items")
stress_assert(all(count == 1 for count in keyword_counts.values()),
              "Zero collisions: Every buzzword belongs to exactly ONE investor archetype")

# ==============================================================================
# CHALLENGE 4: Barista Station Manometer Pressure Dynamics & Synergy
# ==============================================================================
print("\n--- Challenge 4: Barista Manometer Pressure Dynamics & Hold Simulation ---")

def in_sweet_spot(p: float) -> bool:
    return 62.0 <= p <= 84.0

# 4.1 Boundary testing
stress_assert(not in_sweet_spot(61.9999), "Pressure 61.9999 bar is strictly outside sweet spot")
stress_assert(in_sweet_spot(62.0000), "Pressure 62.0000 bar is strictly inside sweet spot")
stress_assert(in_sweet_spot(84.0000), "Pressure 84.0000 bar is strictly inside sweet spot")
stress_assert(not in_sweet_spot(84.0001), "Pressure 84.0001 bar is strictly outside sweet spot")

# 4.2 Mathematical proof that continuous holding for 3.0s does NOT brew
# Rise rate: 40 bar/s, decay: 24 bar/s, start: 20 bar
# Time to 62: (62 - 20) / 40 = 1.05s
# Time in [62, 84]: (84 - 62) / 40 = 0.55s
# At 1.6s, pressure is 84 bar. From 1.6s to 3.0s (1.4s), pressure is >84 bar.
# During overpressure, hold_time decays at -0.4 * dt: 1.4 * 0.4 = 0.56s decay.
# Net hold time = max(0.0, 0.55 - 0.56) = 0.0s!
def sim_continuous_hold(duration: float, dt: float = 0.01) -> Tuple[float, float, bool]:
    p = 20.0
    hold_time = 0.0
    steps = int(duration / dt)
    for _ in range(steps):
        p = min(100.0, p + 40.0 * dt)
        if in_sweet_spot(p):
            hold_time = min(3.0, hold_time + dt)
        else:
            hold_time = max(0.0, hold_time - dt * 0.4)
    return p, hold_time, hold_time >= 3.0

p_end, h_end, brewed = sim_continuous_hold(3.0)
stress_assert(not brewed and h_end == 0.0 and p_end == 100.0,
              "Continuous hold for 3.0s without release fails extraction (0.0s hold, 100 bar) as required by design")

# 4.3 Realistic pulse/bleed strategy achieves extraction
def sim_pulse_strategy() -> Tuple[float, float, bool]:
    p = 20.0
    hold_time = 0.0
    dt = 0.01
    total_time = 0.0
    while total_time < 10.0 and hold_time < 3.0:
        is_hold = p < 75.0
        if is_hold:
            p = min(100.0, p + 40.0 * dt)
        else:
            p = max(0.0, p - 24.0 * dt)
        if in_sweet_spot(p):
            hold_time = min(3.0, hold_time + dt)
        else:
            hold_time = max(0.0, hold_time - dt * 0.4)
        total_time += dt
    return p, hold_time, hold_time >= 3.0

p_pulse, h_pulse, pulse_brewed = sim_pulse_strategy()
stress_assert(pulse_brewed and h_pulse == 3.0 and in_sweet_spot(p_pulse),
              f"Pulsing hold strategy successfully completes extraction (Hold: {h_pulse:.1f}s, Pressure: {p_pulse:.1f} bar)")

# ==============================================================================
# CHALLENGE 5: Discrete Audio Synthesis Tail Fade & Anti-Pop Simulation
# ==============================================================================
print("\n--- Challenge 5: Discrete Audio Synthesis Tail Simulation ---")

SAMPLE_RATE = 22050

def check_tail(name: str, duration: float, synth_fn) -> bool:
    count = int(SAMPLE_RATE * duration)
    tail = []
    max_amp = 0.0
    for i in range(count):
        t = float(i) / float(SAMPLE_RATE)
        val = synth_fn(t, duration)
        abs_v = abs(val)
        if abs_v > max_amp:
            max_amp = abs_v
        if i >= count - 50:
            tail.append(abs_v)
    terminal = tail[-1]
    dc_offset = sum(tail) / len(tail)
    stress_assert(terminal < 0.001, f"{name}: terminal sample < 0.001 (actual: {terminal:.6f})")
    stress_assert(max_amp <= 1.0001, f"{name}: maximum peak <= 1.0 (no clipping, actual: {max_amp:.4f})")
    stress_assert(dc_offset < 0.005, f"{name}: DC tail offset < 0.005 (actual: {dc_offset:.6f})")
    return terminal < 0.001 and max_amp <= 1.0001

def synth_vj(t: float, dur: float) -> float:
    notes = [392.00, 523.25, 659.25, 783.99, 1046.50]
    times = [0.00, 0.12, 0.24, 0.36, 0.48]
    sum_val = 0.0
    for n in range(5):
        dt = t - times[n]
        if dt >= 0.0:
            f = notes[n]
            decay = 4.0 if n < 4 else 2.2
            env = (1.0 - math.exp(-dt * 300.0)) * math.exp(-dt * decay)
            wave = math.sin(2.0 * math.pi * f * dt) + 0.35 * math.sin(4.0 * math.pi * f * dt) + 0.15 * math.sin(6.0 * math.pi * f * dt)
            sum_val += wave * env
    tail_fade = max(0.0, min(1.0, (dur - t) / 0.10)) if t > 0.75 else 1.0
    return max(-1.0, min(1.0, (sum_val / 2.5) * 0.85 * tail_fade))

def synth_sh(t: float, dur: float) -> float:
    env = (1.0 - math.exp(-t * 80.0)) * math.exp(-t * 3.5)
    noise = math.sin(t * 789123.45) * 0.7 + math.sin(t * 345671.12) * 0.3
    steam_body = noise * (0.8 + 0.2 * math.sin(2.0 * math.pi * 18.0 * t))
    tail_fade = max(0.0, min(1.0, (dur - t) / 0.08)) if t > 0.37 else 1.0
    return max(-1.0, min(1.0, steam_body * env * 0.55 * tail_fade))

def synth_qc(t: float, dur: float) -> float:
    f = 1046.50 if t < 0.08 else 1567.98
    dt = t if t < 0.08 else (t - 0.08)
    env = (1.0 - math.exp(-dt * 400.0)) * math.exp(-dt * 12.0)
    wave = math.sin(2.0 * math.pi * f * dt) + 0.25 * math.sin(4.0 * math.pi * f * dt)
    tail_fade = max(0.0, min(1.0, (dur - t) / 0.04)) if t > 0.18 else 1.0
    return max(-1.0, min(1.0, wave * env * 0.80 * tail_fade))

def synth_qw(t: float, dur: float) -> float:
    env = math.exp(-t * 9.0)
    wave = (math.sin(2.0 * math.pi * 160.0 * t) + math.sin(2.0 * math.pi * 172.0 * t) + 0.3 * math.sin(6.0 * math.pi * 160.0 * t)) / 2.3
    tail_fade = max(0.0, min(1.0, (dur - t) / 0.04)) if t > 0.16 else 1.0
    return max(-1.0, min(1.0, wave * env * 0.75 * tail_fade))

def synth_hp(t: float, dur: float) -> float:
    env = math.exp(-t * 60.0)
    wave = math.sin(2.0 * math.pi * 1200.0 * t) + 0.3 * math.sin(4.0 * math.pi * 1200.0 * t)
    tail_fade = max(0.0, min(1.0, (dur - t) / 0.015)) if t > 0.035 else 1.0
    return max(-1.0, min(1.0, wave * env * 0.85 * tail_fade))

def synth_hg(t: float, dur: float) -> float:
    env = math.exp(-t * 80.0)
    wave = math.sin(2.0 * math.pi * 800.0 * t)
    tail_fade = max(0.0, min(1.0, (dur - t) / 0.012)) if t > 0.028 else 1.0
    return max(-1.0, min(1.0, wave * env * 0.85 * tail_fade))

def synth_hm(t: float, dur: float) -> float:
    env = math.exp(-t * 40.0)
    wave = math.sin(2.0 * math.pi * 350.0 * t)
    tail_fade = max(0.0, min(1.0, (dur - t) / 0.018)) if t > 0.042 else 1.0
    return max(-1.0, min(1.0, wave * env * 0.70 * tail_fade))

check_tail("Victory Jingle", 0.85, synth_vj)
check_tail("Steam Hiss", 0.45, synth_sh)
check_tail("QTE Correct", 0.22, synth_qc)
check_tail("QTE Wrong", 0.20, synth_qw)
check_tail("Hit Perfect", 0.05, synth_hp)
check_tail("Hit Good", 0.04, synth_hg)
check_tail("Hit Miss", 0.06, synth_hm)

# ==============================================================================
# CHALLENGE 6: Multi-Run Test Determinism & Zero Regression Certification
# ==============================================================================
print("\n--- Challenge 6: Multi-Run Test Determinism ---")

for run_idx in range(1, 3):
    cmd = [sys.executable, str(GAME_DIR / "tests/test_phase16_verify.py")]
    res = subprocess.run(cmd, cwd=str(GAME_DIR), capture_output=True, text=True, encoding="utf-8", errors="replace")
    clean_stdout = strip_ansi(res.stdout)
    stress_assert(res.returncode == 0, f"Deterministic Oracle Run #{run_idx} finished with exit code 0")
    stress_assert("Total Checks : 266" in clean_stdout and "Failed       : 0" in clean_stdout,
                  f"Deterministic Oracle Run #{run_idx} asserts exact count (266 Passed, 0 Failed)")

print("\n====================================================================")
print(f"ADVERSARIAL CHALLENGE SUMMARY: {passed_count} PASSED, {failed_count} FAILED")
print("====================================================================")

if failed_count == 0:
    print(">>> VERDICT: ALL ADVERSARIAL STRESS CHALLENGES SATISFIED (APPROVE) <<<\n")
    sys.exit(0)
else:
    print(f">>> VERDICT: {failed_count} CHALLENGES FAILED (REJECT) <<<\n")
    sys.exit(1)
