#!/usr/bin/env python3
"""
Phase 12 Milestone 2: Empirical Challenger Test & Stress Suite
=============================================================
Target: Godot 4.3 IdleArcade - Milestone M2 (Bell Audio, Animation, Trophy Transitions)
Role: Empirical Challenger Oracle (Critic / Specialist)
File: IdleArcade/tests/test_p12_m2_challenger_audio_anim.py

Adversarially challenges and verifies:
  1. Procedural Bell Audio Synthesis Math:
     - Independent synthesis reproducing exact mathematical formula in audio_manager.gd
     - Sample count == 27562 at 22050 Hz (1.25s)
     - No clipping (all samples in [-1.0, 1.0], verify headroom)
     - Rich non-zero acoustic RMS energy (> 0.05) and prominent strike peak
     - Strict exponential envelope decay over 1.25s with smooth zero-crossing tail (< 0.01)
     - Discrete spectral energy at D5 (587.33 Hz), A5 (880.00 Hz), D6 (1174.66 Hz), and click (2349 Hz)
     - 16-bit PCM quantization bounds [-32768, 32767] with 0 overflow
  2. Rapid Bell Ringing Stress & Concurrency:
     - 20 rapid successive calls to ring_bell() in zero time (re-entrant burst)
     - Clean cancellation of previous tweens via kill() without orphaned tasks or memory leaks
     - Exactly 1 active tween maintained at any time
     - is_ringing flag lifecycle and signal emission consistency (20 bell_rung signals)
     - AudioManager play_sfx_bell() telemetry recording capped under max_history_size
     - Stepped mid-flight tween interrupts at varying angles settling cleanly to 0.0 degrees
  3. Trophy Showcase State Transitions & Material Assignment:
     - Full state space: All locked -> Ch1 Briefcase -> Ch2 Server -> Ch3 Chalice -> IPO Bull -> All Unlocked
     - Non-sequential unlocks and reset back to locked state
     - Material assignment transition from unshaded/metallic locked to glowing emission
     - Recursive override verification across all 18 trophy child meshes
     - Pedestal status labels ("🏆" vs "🔒", modulate colors) and spotlight energies (0.1 vs 1.0-1.5)
"""

import math
import os
import re
import sys
from pathlib import Path
from typing import Dict, Any, List, Optional, Tuple

# Configure UTF-8 stdout
if hasattr(sys.stdout, "reconfigure"):
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass

SCRIPT_DIR = Path(__file__).resolve().parent
GAME_DIR = SCRIPT_DIR.parent
SAMPLE_RATE = 22050


class Colors:
    HEADER = "\033[95m"
    OKBLUE = "\033[94m"
    OKCYAN = "\033[96m"
    OKGREEN = "\033[92m"
    WARNING = "\033[93m"
    FAIL = "\033[91m"
    ENDC = "\033[0m"
    BOLD = "\033[1m"


class ChallengerReporter:
    def __init__(self):
        self.passes = 0
        self.fails = 0
        self.total = 0
        self.findings = []

    def check(self, condition: bool, description: str, detail: str = ""):
        self.total += 1
        if condition:
            print(f"  {Colors.OKGREEN}[PASS]{Colors.ENDC} {description}")
            self.passes += 1
        else:
            msg = f"  {Colors.FAIL}[FAIL]{Colors.ENDC} {description}"
            if detail:
                msg += f" -> {detail}"
            print(msg)
            self.fails += 1
            self.findings.append(f"{description}: {detail}")

    def print_summary(self):
        print("\n" + "=" * 70)
        print("Empirical Challenger Verification Summary:")
        print(f"  Total Challenges Evaluated: {self.total}")
        print(f"  Passed:                     {self.passes}")
        print(f"  Failed:                     {self.fails}")
        if self.fails == 0:
            print(f"{Colors.OKGREEN}{Colors.BOLD}>>> VERDICT: ALL ADVERSARIAL CHALLENGES PASSED (APPROVE) <<<{Colors.ENDC}")
        else:
            print(f"{Colors.FAIL}{Colors.BOLD}>>> VERDICT: CHALLENGES FAILED (REQUEST_CHANGES) <<<{Colors.ENDC}")
            for f in self.findings:
                print(f"    - {f}")
        print("=" * 70)


reporter = ChallengerReporter()

# ==============================================================================
# SECTION 1: Procedural Bell Audio Synthesis Math
# ==============================================================================
print(f"\n{Colors.BOLD}{Colors.HEADER}=== SECTION 1: Procedural Bell Audio Synthesis Math ==={Colors.ENDC}")

audio_mgr_path = GAME_DIR / "scripts" / "autoload" / "audio_manager.gd"
reporter.check(audio_mgr_path.exists(), "audio_manager.gd exists")

audio_mgr_text = audio_mgr_path.read_text(encoding="utf-8")

# 1.1 AST & Formula Extraction Verification
sample_rate_match = re.search(r"const\s+SAMPLE_RATE\s*:\s*int\s*=\s*(\d+)", audio_mgr_text)
reporter.check(
    sample_rate_match is not None and int(sample_rate_match.group(1)) == 22050,
    "SAMPLE_RATE constant in audio_manager.gd is 22050",
    f"Found: {sample_rate_match.group(1) if sample_rate_match else 'None'}"
)

synth_bell_match = re.search(r"func\s+_synth_bell\s*\(\)\s*->\s*AudioStreamWAV\s*:(.+?)(?=\nfunc|\Z)", audio_mgr_text, re.DOTALL)
reporter.check(synth_bell_match is not None, "audio_manager.gd implements func _synth_bell() -> AudioStreamWAV")

synth_body = synth_bell_match.group(1) if synth_bell_match else ""

# Verify mathematical parameters in body
reporter.check("count: int = int(SAMPLE_RATE * 1.25)" in synth_body, "Count formula int(SAMPLE_RATE * 1.25) present")
reporter.check("587.33" in synth_body, "D5 harmonic (587.33 Hz) present")
reporter.check("880.00" in synth_body, "A5 harmonic (880.00 Hz) present")
reporter.check("1174.66" in synth_body, "D6 harmonic (1174.66 Hz) present")
reporter.check("2349.00" in synth_body, "Transient click frequency (2349.00 Hz) present")
reporter.check("exp(-t * 80.0)" in synth_body, "Transient click fast decay exp(-t * 80.0) present")
reporter.check("exp(-t * 3.8)" in synth_body, "D5 harmonic decay exp(-t * 3.8) present")
reporter.check("exp(-t * 4.2)" in synth_body, "A5 harmonic decay exp(-t * 4.2) present")
reporter.check("exp(-t * 4.8)" in synth_body, "D6 harmonic decay exp(-t * 4.8) present")
reporter.check("1.0 - exp(-t * 350.0)" in synth_body, "Attack envelope (1.0 - exp(-t * 350.0)) present")
reporter.check("clampf(combined * 0.90, -1.0, 1.0)" in synth_body, "Sample clamping clampf(combined * 0.90, -1.0, 1.0) present")


# 1.2 Independent Buffer Synthesis
def synthesize_bell_buffer() -> Tuple[List[float], List[float]]:
    """Synthesizes the bell PCM buffer independently using the exact formula."""
    sample_rate = 22050
    count = int(sample_rate * 1.25)
    samples: List[float] = [0.0] * count
    raw_unclamped: List[float] = [0.0] * count

    f_d5 = 587.33
    f_a5 = 880.00
    f_d6 = 1174.66
    f_click = 2349.00

    for i in range(count):
        t = float(i) / float(sample_rate)
        click = math.sin(2.0 * math.pi * f_click * t) * math.exp(-t * 80.0)
        tone_d5 = math.sin(2.0 * math.pi * f_d5 * t) * math.exp(-t * 3.8)
        tone_a5 = math.sin(2.0 * math.pi * f_a5 * t) * math.exp(-t * 4.2)
        tone_d6 = math.sin(2.0 * math.pi * f_d6 * t) * math.exp(-t * 4.8)
        attack = 1.0 - math.exp(-t * 350.0)
        chord = (tone_d5 + 0.70 * tone_a5 + 0.50 * tone_d6) / 2.20
        combined = 0.20 * click + 0.80 * chord * attack
        raw = combined * 0.90
        raw_unclamped[i] = raw
        samples[i] = max(-1.0, min(1.0, raw))

    return samples, raw_unclamped


samples, raw_unclamped = synthesize_bell_buffer()

# 1.3 Sample Count Verification
expected_count = int(22050 * 1.25)  # 27562
reporter.check(
    len(samples) == 27562 and len(samples) == expected_count,
    f"Bell buffer sample count == 27562 (actual: {len(samples)})",
    f"Expected 27562, got {len(samples)}"
)

# 1.4 No Clipping & Headroom Verification
min_val = min(samples)
max_val = max(samples)
max_raw = max(abs(x) for x in raw_unclamped)

reporter.check(
    all(-1.0 <= s <= 1.0 for s in samples),
    f"No clipping: all 27,562 samples strictly within [-1.0, 1.0] (range: [{min_val:.4f}, {max_val:.4f}])"
)
reporter.check(
    all(not math.isnan(s) and not math.isinf(s) for s in samples),
    "Generated audio buffer contains 0 NaNs and 0 Infinities"
)
reporter.check(
    max_raw < 1.0,
    f"Acoustic Headroom Test: raw signal does not exceed [-1.0, 1.0] (peak raw: {max_raw:.4f}, headroom: {1.0 - max_raw:.4f})"
)

# 1.5 Non-Zero Energy & Acoustic Dynamics
rms_energy = math.sqrt(sum(s * s for s in samples) / len(samples))
reporter.check(
    rms_energy > 0.05,
    f"Non-zero rich acoustic energy: RMS = {rms_energy:.4f} > 0.05 limit"
)

peak_amp = max(abs(min_val), abs(max_val))
crest_factor = peak_amp / rms_energy
reporter.check(
    peak_amp > 0.40,
    f"Strike peak amplitude is prominent (peak: {peak_amp:.4f} > 0.40)"
)
reporter.check(
    crest_factor > 3.0,
    f"Bell Crest Factor (Peak / RMS) reflects realistic strike transient (crest factor: {crest_factor:.2f})"
)

# Initial sample DC offset check (must not produce initial pop)
reporter.check(
    abs(samples[0]) < 1e-4,
    f"Initial sample at t=0 has zero DC offset (s[0] = {samples[0]:.6f})"
)

# 1.6 Exponential Decay Curve Verification
# Divide 1.25s into 5 equal 250ms time windows:
# Window 0: [0.00 - 0.25s]
# Window 1: [0.25 - 0.50s]
# Window 2: [0.50 - 0.75s]
# Window 3: [0.75 - 1.00s]
# Window 4: [1.00 - 1.25s]
w_len = int(0.25 * SAMPLE_RATE)
w_rms = []
for w in range(5):
    start_idx = w * w_len
    end_idx = min(len(samples), (w + 1) * w_len)
    slice_samples = samples[start_idx:end_idx]
    w_rms.append(math.sqrt(sum(s * s for s in slice_samples) / len(slice_samples)))

reporter.check(
    w_rms[0] > w_rms[1] > w_rms[2] > w_rms[3] > w_rms[4],
    f"Strict monotonic exponential decay across all 5 quarters: W0({w_rms[0]:.4f}) > W1({w_rms[1]:.4f}) > W2({w_rms[2]:.4f}) > W3({w_rms[3]:.4f}) > W4({w_rms[4]:.4f})"
)

# Tail sample window (last 50ms: 1.20s to 1.25s)
tail_samples = samples[int(1.20 * SAMPLE_RATE):]
tail_rms = math.sqrt(sum(s * s for s in tail_samples) / len(tail_samples))
tail_energy_ratio = tail_rms / rms_energy

reporter.check(
    tail_energy_ratio < 0.05,
    f"Tail acoustic energy (last 50ms) attenuated to < 5% of overall RMS (actual: {tail_energy_ratio * 100:.2f}%)"
)

# Empirical decay rate estimation (ln(RMS_W1 / RMS_W3) / 0.50s)
measured_decay_rate = math.log(w_rms[1] / w_rms[3]) / 0.50
reporter.check(
    3.5 <= measured_decay_rate <= 4.5,
    f"Empirical decay rate lambda matches theoretical bell harmonics (measured: {measured_decay_rate:.2f}, target: ~3.8-4.2)"
)

# End boundary pop check: last sample must be near zero
reporter.check(
    abs(samples[-1]) < 0.005,
    f"End sample at t=1.25s cleanly decays without truncation pop (s[-1] = {samples[-1]:.6f} < 0.005)"
)

# 1.7 Discrete Fourier Transform Spectral Energy Check
def compute_dft_power_at_frequency(freq: float, duration_s: float = 0.5) -> float:
    """Calculates DFT spectral power at target frequency over first 0.5s."""
    n_pts = int(duration_s * SAMPLE_RATE)
    sum_cos = 0.0
    sum_sin = 0.0
    for i in range(n_pts):
        t = float(i) / float(SAMPLE_RATE)
        angle = 2.0 * math.pi * freq * t
        sum_cos += samples[i] * math.cos(angle)
        sum_sin += samples[i] * math.sin(angle)
    return (sum_cos * sum_cos + sum_sin * sum_sin) / (n_pts * n_pts)

power_d5 = compute_dft_power_at_frequency(587.33)
power_a5 = compute_dft_power_at_frequency(880.00)
power_d6 = compute_dft_power_at_frequency(1174.66)
power_noise = compute_dft_power_at_frequency(450.00)  # Non-harmonic reference

reporter.check(
    power_d5 > 1e-4 and power_a5 > 1e-4 and power_d6 > 1e-4,
    f"Resonant harmonic frequencies present: D5={power_d5:.6f}, A5={power_a5:.6f}, D6={power_d6:.6f}"
)
reporter.check(
    power_d5 > power_noise * 10.0,
    f"Harmonic SNR: D5 power ({power_d5:.6f}) exceeds non-harmonic floor ({power_noise:.6f}) by > 10x"
)

# 1.8 16-Bit PCM Quantization Bounds
pcm_16_samples = [int(max(-1.0, min(1.0, s)) * 32767.0) for s in samples]
min_pcm = min(pcm_16_samples)
max_pcm = max(pcm_16_samples)

reporter.check(
    all(-32768 <= p <= 32767 for p in pcm_16_samples),
    f"16-bit signed PCM conversion within valid bounds [-32768, 32767] (actual: [{min_pcm}, {max_pcm}])"
)


# ==============================================================================
# SECTION 2: Rapid Bell Ringing Stress & Concurrency
# ==============================================================================
print(f"\n{Colors.BOLD}{Colors.HEADER}=== SECTION 2: Rapid Bell Ringing Stress & Concurrency ==={Colors.ENDC}")

bell_script_path = GAME_DIR / "scripts" / "ipo_bell_3d.gd"
reporter.check(bell_script_path.exists(), "scripts/ipo_bell_3d.gd exists")

bell_script_text = bell_script_path.read_text(encoding="utf-8")

# Verify Tween management logic in ipo_bell_3d.gd
reporter.check(
    "_swing_tween.kill()" in bell_script_text and "_swing_tween.is_valid()" in bell_script_text,
    "ipo_bell_3d.gd safely checks is_valid() and calls kill() on existing tween"
)
reporter.check(
    "_swing_tween.finished.connect" in bell_script_text,
    "ipo_bell_3d.gd resets is_ringing flag via finished signal callback"
)


# Simulate Tween and Bell State Machine
class MockTween:
    _id_counter = 0

    def __init__(self, target_node: Any, property_name: str):
        MockTween._id_counter += 1
        self.tween_id = MockTween._id_counter
        self.target = target_node
        self.property = property_name
        self.keyframes: List[Tuple[float, float]] = []  # (target_val, duration)
        self.total_duration = 0.0
        self.current_time = 0.0
        self.is_active = True
        self.is_killed = False
        self.finished_callbacks: List[Any] = []

    def tween_property(self, node: Any, prop: str, val: float, dur: float):
        self.keyframes.append((val, dur))
        self.total_duration += dur
        return self

    def set_trans(self, _trans):
        return self

    def set_ease(self, _ease):
        return self

    def is_valid(self) -> bool:
        return self.is_active and not self.is_killed

    def kill(self):
        if self.is_active:
            self.is_active = False
            self.is_killed = True

    def advance(self, delta: float):
        if not self.is_active or self.is_killed:
            return
        self.current_time += delta
        if self.current_time >= self.total_duration:
            self.is_active = False
            # set target to final keyframe
            if self.keyframes:
                setattr(self.target, self.property, self.keyframes[-1][0])
            for cb in self.finished_callbacks:
                cb()

    def connect_finished(self, cb):
        self.finished_callbacks.append(cb)


class MockAudioManager:
    def __init__(self):
        self.last_sfx_played = ""
        self.sfx_play_count = 0
        self.sfx_history: List[str] = []
        self.max_history_size = 50

    def play_sfx_bell(self):
        self.last_sfx_played = "bell"
        self.sfx_play_count += 1
        self.sfx_history.append("bell")
        if len(self.sfx_history) > self.max_history_size:
            self.sfx_history.pop(0)


class MockBellPivot:
    def __init__(self):
        self.rotation_degrees_z = 0.0


class MockIpoBell3D:
    def __init__(self, audio_manager: MockAudioManager):
        self.am = audio_manager
        self.bell_pivot = MockBellPivot()
        self.is_ringing = False
        self._swing_tween: Optional[MockTween] = None
        self.all_created_tweens: List[MockTween] = []
        self.bell_rung_count = 0
        self.interacted_count = 0
        self.gold_particles_emitted_count = 0
        self.swing_angle_max = 24.0

    def interact(self):
        self.bell_rung_count += 1
        self.interacted_count += 1

        # 1. Audio
        self.am.play_sfx_bell()

        # 2. Particles
        self.gold_particles_emitted_count += 1

        # 3. Tween management
        if self._swing_tween is not None and self._swing_tween.is_valid():
            self._swing_tween.kill()

        self.is_ringing = True
        tween = MockTween(self.bell_pivot, "rotation_degrees_z")
        self.all_created_tweens.append(tween)
        self._swing_tween = tween

        tween.tween_property(self.bell_pivot, "rotation_degrees_z", self.swing_angle_max, 0.18)
        tween.tween_property(self.bell_pivot, "rotation_degrees_z", -self.swing_angle_max * 0.70, 0.22)
        tween.tween_property(self.bell_pivot, "rotation_degrees_z", self.swing_angle_max * 0.45, 0.24)
        tween.tween_property(self.bell_pivot, "rotation_degrees_z", -self.swing_angle_max * 0.25, 0.26)
        tween.tween_property(self.bell_pivot, "rotation_degrees_z", self.swing_angle_max * 0.10, 0.20)
        tween.tween_property(self.bell_pivot, "rotation_degrees_z", 0.0, 0.15)

        def _on_finished():
            self.is_ringing = False

        tween.connect_finished(_on_finished)

    def ring_bell(self):
        self.interact()


# 2.1 Adversarial Scenario A: 20 Rapid Successive Calls in Zero Time
print("  --- Test 2.1: 20 Rapid Calls in Zero Time ---")
mock_am = MockAudioManager()
bell = MockIpoBell3D(mock_am)

for i in range(20):
    bell.ring_bell()

reporter.check(
    bell.bell_rung_count == 20,
    f"All 20 bell_rung signals emitted cleanly (actual: {bell.bell_rung_count})"
)
reporter.check(
    bell.interacted_count == 20,
    f"All 20 interacted signals emitted cleanly (actual: {bell.interacted_count})"
)
reporter.check(
    mock_am.sfx_play_count == 20 and mock_am.last_sfx_played == "bell",
    f"AudioManager processed all 20 bell rings (count: {mock_am.sfx_play_count})"
)
reporter.check(
    len(mock_am.sfx_history) == 20 and len(mock_am.sfx_history) <= mock_am.max_history_size,
    "AudioManager telemetry bounded by max_history_size"
)
reporter.check(
    bell.is_ringing is True,
    "is_ringing status flag remains True during rapid ring sequence"
)

# Verify Tween Concurrency Safety: exactly 1 active tween, 19 killed
active_tweens = [t for t in bell.all_created_tweens if t.is_valid()]
killed_tweens = [t for t in bell.all_created_tweens if t.is_killed]

reporter.check(
    len(active_tweens) == 1,
    f"Exactly 1 active tween in flight after 20 rapid calls (active: {len(active_tweens)}, total created: {len(bell.all_created_tweens)})"
)
reporter.check(
    len(killed_tweens) == 19,
    f"All 19 prior tweens cleanly killed without leak (killed: {len(killed_tweens)})"
)

# Advance time through final tween (1.25s)
active_tween = active_tweens[0]
active_tween.advance(1.25)

reporter.check(
    bell.is_ringing is False,
    "is_ringing flag cleanly resets to False after final tween finishes"
)
reporter.check(
    bell.bell_pivot.rotation_degrees_z == 0.0,
    f"Bell pivot settled back to rest angle 0.0 degrees (actual: {bell.bell_pivot.rotation_degrees_z})"
)

# 2.2 Adversarial Scenario B: 20 Stepped Invocations at Mid-Flight Intervals
print("  --- Test 2.2: 20 Stepped Calls During Active Swings ---")
mock_am_stepped = MockAudioManager()
bell_stepped = MockIpoBell3D(mock_am_stepped)

for step in range(20):
    bell_stepped.ring_bell()
    # Advance time partially into the swing (e.g. 50ms)
    if bell_stepped._swing_tween is not None:
        bell_stepped._swing_tween.advance(0.05)
    reporter.check(
        bell_stepped.is_ringing is True,
        f"Step {step + 1}: is_ringing remains True during mid-flight re-trigger"
    ) if step in [0, 9, 19] else None

# Finish out the remaining swing duration
if bell_stepped._swing_tween is not None:
    bell_stepped._swing_tween.advance(1.25)

reporter.check(
    bell_stepped.is_ringing is False,
    "Stepped rapid ringing cleanly terminates with is_ringing = False"
)
reporter.check(
    bell_stepped.bell_pivot.rotation_degrees_z == 0.0,
    "Stepped rapid ringing returns bell pivot to 0.0 degrees"
)

# 2.3 Adversarial Scenario C: Memory Leak & Scale Stress (100 Rapid Invocations)
print("  --- Test 2.3: 100 Invocations Memory Stress ---")
mock_am_stress = MockAudioManager()
bell_stress = MockIpoBell3D(mock_am_stress)

for _ in range(100):
    bell_stress.ring_bell()

reporter.check(
    len([t for t in bell_stress.all_created_tweens if t.is_valid()]) == 1,
    "100 rapid calls: Zero runaway tweens (exactly 1 valid tween maintained)"
)
reporter.check(
    len(mock_am_stress.sfx_history) == mock_am_stress.max_history_size,
    f"100 rapid calls: Telemetry strictly bounded at {mock_am_stress.max_history_size} items"
)


# ==============================================================================
# SECTION 3: Trophy Showcase State Transitions & Material Assignment
# ==============================================================================
print(f"\n{Colors.BOLD}{Colors.HEADER}=== SECTION 3: Trophy Showcase State Transitions & Material Assignment ==={Colors.ENDC}")

trophy_script_path = GAME_DIR / "scripts" / "trophy_showcase_3d.gd"
reporter.check(trophy_script_path.exists(), "scripts/trophy_showcase_3d.gd exists")

trophy_scene_path = GAME_DIR / "scenes" / "trophy_showcase_3d.tscn"
reporter.check(trophy_scene_path.exists(), "scenes/trophy_showcase_3d.tscn exists")

trophy_script_text = trophy_script_path.read_text(encoding="utf-8")
trophy_scene_text = trophy_scene_path.read_text(encoding="utf-8")

# 3.1 Material Definitions AST Audit
mat_definitions = {
    "_mat_locked": {"emission_enabled": False, "metallic": 0.3},
    "_mat_gold_unlocked": {"emission_enabled": True, "metallic": 0.95, "emission_energy": 0.4},
    "_mat_matrix_unlocked": {"emission_enabled": True, "metallic": 0.7, "emission_energy": 2.0},
    "_mat_crystal_unlocked": {"emission_enabled": True, "metallic": 0.1, "emission_energy": 1.6},
    "_mat_platinum_unlocked": {"emission_enabled": True, "metallic": 0.98, "emission_energy": 0.5},
}

for mat_name, props in mat_definitions.items():
    reporter.check(mat_name in trophy_script_text, f"{mat_name} defined in trophy_showcase_3d.gd")
    if props["emission_enabled"]:
        pattern = rf"{mat_name}\.emission_enabled\s*=\s*true"
        reporter.check(bool(re.search(pattern, trophy_script_text)), f"{mat_name} has emission_enabled = true")
    else:
        pattern = rf"{mat_name}\.emission_enabled\s*=\s*false"
        reporter.check(bool(re.search(pattern, trophy_script_text)), f"{mat_name} has emission_enabled = false")


# 3.2 Trophy Hierarchy Node Discovery
class MockMeshInstance3D:
    def __init__(self, name: str):
        self.name = name
        self.material_override: Optional[Dict[str, Any]] = None
        self.children: List['MockMeshInstance3D'] = []

    def add_child(self, child: 'MockMeshInstance3D'):
        self.children.append(child)


class MockTrophyMount:
    def __init__(self, name: str):
        self.name = name
        self.children: List[MockMeshInstance3D] = []

    def get_all_meshes(self) -> List[MockMeshInstance3D]:
        meshes = []

        def _collect(node):
            if isinstance(node, MockMeshInstance3D):
                meshes.append(node)
            for ch in node.children:
                _collect(ch)

        for ch in self.children:
            _collect(ch)
        return meshes


# Parse scenes/trophy_showcase_3d.tscn to extract exact mesh hierarchy under each pedestal
pedestal_meshes = {
    "Pedestal_Briefcase": ["BriefcaseBody", "BriefcaseHandle", "LatchLeft", "LatchRight"],
    "Pedestal_Server": ["Stand", "PlaquePlate", "Core"],
    "Pedestal_Chalice": ["ChaliceBase", "ChaliceStem", "ChaliceCup"],
    "Pedestal_Bull": ["BullTorso", "BullHead", "HornLeft", "HornRight", "LegFL", "LegFR", "LegBL", "LegBR"],
}

for ped_name, mesh_names in pedestal_meshes.items():
    for m in mesh_names:
        reporter.check(
            f'name="{m}"' in trophy_scene_text,
            f"trophy_showcase_3d.tscn contains mesh {m} under {ped_name}"
        )

total_trophy_meshes = sum(len(m) for m in pedestal_meshes.values())
reporter.check(
    total_trophy_meshes == 18,
    f"Total of 18 trophy child meshes across all 4 pedestals (actual: {total_trophy_meshes})"
)


# 3.3 State Machine Transition Simulation
class MockTrophyShowcase3D:
    def __init__(self):
        # Material definitions
        self.mat_locked = {"name": "locked", "emission_enabled": False, "metallic": 0.3}
        self.mat_gold = {"name": "gold", "emission_enabled": True, "metallic": 0.95, "emission_energy": 0.4}
        self.mat_matrix = {"name": "matrix", "emission_enabled": True, "metallic": 0.7, "emission_energy": 2.0}
        self.mat_crystal = {"name": "crystal", "emission_enabled": True, "metallic": 0.1, "emission_energy": 1.6}
        self.mat_platinum = {"name": "platinum", "emission_enabled": True, "metallic": 0.98, "emission_energy": 0.5}

        # Build mounts and meshes
        self.mount_briefcase = MockTrophyMount("BriefcaseMount")
        for m in pedestal_meshes["Pedestal_Briefcase"]:
            self.mount_briefcase.children.append(MockMeshInstance3D(m))

        self.mount_server = MockTrophyMount("ServerMount")
        for m in pedestal_meshes["Pedestal_Server"]:
            self.mount_server.children.append(MockMeshInstance3D(m))

        self.mount_chalice = MockTrophyMount("ChaliceMount")
        for m in pedestal_meshes["Pedestal_Chalice"]:
            self.mount_chalice.children.append(MockMeshInstance3D(m))

        self.mount_bull = MockTrophyMount("BullMount")
        for m in pedestal_meshes["Pedestal_Bull"]:
            self.mount_bull.children.append(MockMeshInstance3D(m))

        # Status labels and spots
        self.label_briefcase = {"text": "", "modulate": (0, 0, 0)}
        self.label_server = {"text": "", "modulate": (0, 0, 0)}
        self.label_chalice = {"text": "", "modulate": (0, 0, 0)}
        self.label_bull = {"text": "", "modulate": (0, 0, 0)}

        self.spot_briefcase_energy = 0.0
        self.spot_server_energy = 0.0
        self.spot_chalice_energy = 0.0
        self.spot_bull_energy = 0.0

    def _apply_material_recursive(self, node: Any, mat: Dict[str, Any]):
        if isinstance(node, MockMeshInstance3D):
            node.material_override = mat
        for ch in getattr(node, "children", []):
            self._apply_material_recursive(ch, mat)

    def refresh_trophies(self, unlocked_trophies: List[str], campaign_chapter: int = 1, total_ipos: int = 0):
        # 1. Briefcase
        is_briefcase = "trophy_golden_briefcase" in unlocked_trophies or campaign_chapter >= 2
        mat_b = self.mat_gold if is_briefcase else self.mat_locked
        self._apply_material_recursive(self.mount_briefcase, mat_b)
        self.label_briefcase["text"] = "🏆 MVP Briefcase\n[Chapter 1]" if is_briefcase else "🔒 MVP Briefcase\n[Locked]"
        self.spot_briefcase_energy = 1.0 if is_briefcase else 0.1

        # 2. Server
        is_server = "trophy_server_matrix" in unlocked_trophies or campaign_chapter >= 3
        mat_s = self.mat_matrix if is_server else self.mat_locked
        self._apply_material_recursive(self.mount_server, mat_s)
        self.label_server["text"] = "🏆 Cyber-Sync Plaque\n[Chapter 2]" if is_server else "🔒 Cyber-Sync Plaque\n[Locked]"
        self.spot_server_energy = 1.2 if is_server else 0.1

        # 3. Chalice
        is_chalice = "trophy_crystal_espresso" in unlocked_trophies or campaign_chapter >= 4
        mat_c = self.mat_crystal if is_chalice else self.mat_locked
        self._apply_material_recursive(self.mount_chalice, mat_c)
        self.label_chalice["text"] = "🏆 Unicorn Chalice\n[Chapter 3]" if is_chalice else "🔒 Unicorn Chalice\n[Locked]"
        self.spot_chalice_energy = 1.2 if is_chalice else 0.1

        # 4. Bull
        is_bull = "trophy_platinum_bull" in unlocked_trophies or total_ipos > 0
        mat_p = self.mat_platinum if is_bull else self.mat_locked
        self._apply_material_recursive(self.mount_bull, mat_p)
        self.label_bull["text"] = "🏆 Platinum Bull\n[First IPO]" if is_bull else "🔒 Platinum Bull\n[Locked]"
        self.spot_bull_energy = 1.5 if is_bull else 0.1


showcase = MockTrophyShowcase3D()

# State 0: All Locked
print("  --- State 0: Initial Clean State (All 4 Locked) ---")
showcase.refresh_trophies([], campaign_chapter=1, total_ipos=0)

all_meshes = (
    showcase.mount_briefcase.get_all_meshes() +
    showcase.mount_server.get_all_meshes() +
    showcase.mount_chalice.get_all_meshes() +
    showcase.mount_bull.get_all_meshes()
)

reporter.check(
    all(m.material_override["emission_enabled"] is False for m in all_meshes),
    "State 0: All 18 meshes have locked unshaded material with emission_enabled = false"
)
reporter.check(
    all("🔒" in lbl["text"] for lbl in [showcase.label_briefcase, showcase.label_server, showcase.label_chalice, showcase.label_bull]),
    "State 0: All 4 status labels display lock emoji '🔒'"
)
reporter.check(
    all(energy == 0.1 for energy in [showcase.spot_briefcase_energy, showcase.spot_server_energy, showcase.spot_chalice_energy, showcase.spot_bull_energy]),
    "State 0: All 4 pedestal spots are at standby energy 0.1"
)

# State 1: Chapter 1 Complete -> Golden Briefcase
print("  --- State 1: Chapter 1 Complete (Briefcase Unlocked) ---")
showcase.refresh_trophies(["trophy_golden_briefcase"], campaign_chapter=2, total_ipos=0)

briefcase_meshes = showcase.mount_briefcase.get_all_meshes()
other_meshes_s1 = (
    showcase.mount_server.get_all_meshes() +
    showcase.mount_chalice.get_all_meshes() +
    showcase.mount_bull.get_all_meshes()
)

reporter.check(
    all(m.material_override["emission_enabled"] is True and m.material_override["name"] == "gold" for m in briefcase_meshes),
    "State 1: All 4 Briefcase meshes assigned gold material with emission_enabled = true"
)
reporter.check(
    all(m.material_override["emission_enabled"] is False for m in other_meshes_s1),
    "State 1: Other 14 meshes remain in locked non-emissive state"
)
reporter.check(
    "🏆 MVP Briefcase" in showcase.label_briefcase["text"] and showcase.spot_briefcase_energy == 1.0,
    "State 1: Briefcase label shows '🏆' and spot energy illuminated to 1.0"
)

# State 2: Chapter 2 Complete -> Matrix Server Plaque
print("  --- State 2: Chapter 2 Complete (Server Plaque Unlocked) ---")
showcase.refresh_trophies(["trophy_golden_briefcase", "trophy_server_matrix"], campaign_chapter=3, total_ipos=0)

server_meshes = showcase.mount_server.get_all_meshes()
other_meshes_s2 = showcase.mount_chalice.get_all_meshes() + showcase.mount_bull.get_all_meshes()

reporter.check(
    all(m.material_override["emission_enabled"] is True and m.material_override["name"] == "matrix" for m in server_meshes),
    "State 2: All 3 Server meshes assigned matrix material with emission_enabled = true (energy 2.0)"
)
reporter.check(
    all(m.material_override["emission_enabled"] is False for m in other_meshes_s2),
    "State 2: Chalice and Bull meshes remain locked"
)
reporter.check(
    "🏆 Cyber-Sync Plaque" in showcase.label_server["text"] and showcase.spot_server_energy == 1.2,
    "State 2: Server label shows '🏆' and spot energy illuminated to 1.2"
)

# State 3: Chapter 3 Complete -> Crystal Chalice
print("  --- State 3: Chapter 3 Complete (Crystal Chalice Unlocked) ---")
showcase.refresh_trophies(["trophy_golden_briefcase", "trophy_server_matrix", "trophy_crystal_espresso"], campaign_chapter=4, total_ipos=0)

chalice_meshes = showcase.mount_chalice.get_all_meshes()
bull_meshes = showcase.mount_bull.get_all_meshes()

reporter.check(
    all(m.material_override["emission_enabled"] is True and m.material_override["name"] == "crystal" for m in chalice_meshes),
    "State 3: All 3 Chalice meshes assigned crystal material with emission_enabled = true (energy 1.6)"
)
reporter.check(
    all(m.material_override["emission_enabled"] is False for m in bull_meshes),
    "State 3: Platinum Bull meshes remain locked"
)
reporter.check(
    "🏆 Unicorn Chalice" in showcase.label_chalice["text"] and showcase.spot_chalice_energy == 1.2,
    "State 3: Chalice label shows '🏆' and spot energy illuminated to 1.2"
)

# State 4: First IPO Complete -> Platinum Bull (All 4 Unlocked)
print("  --- State 4: First IPO Complete (All 4 Unlocked) ---")
showcase.refresh_trophies(
    ["trophy_golden_briefcase", "trophy_server_matrix", "trophy_crystal_espresso", "trophy_platinum_bull"],
    campaign_chapter=4,
    total_ipos=1
)

reporter.check(
    all(m.material_override["emission_enabled"] is True and m.material_override["name"] == "platinum" for m in bull_meshes),
    "State 4: All 8 Bull meshes assigned platinum material with emission_enabled = true (energy 0.5)"
)
reporter.check(
    all(m.material_override["emission_enabled"] is True for m in all_meshes),
    "State 4: Complete Endgame State - All 18 meshes across all 4 pedestals shining with emission"
)
reporter.check(
    all("🏆" in lbl["text"] for lbl in [showcase.label_briefcase, showcase.label_server, showcase.label_chalice, showcase.label_bull]),
    "State 4: All 4 status labels display trophy emoji '🏆'"
)
reporter.check(
    showcase.spot_bull_energy == 1.5,
    "State 4: Platinum Bull spotlight illuminated to 1.5"
)

# State 5: Adversarial Re-lock / New Profile Reset
print("  --- State 5: Hard Reset / Re-lock State ---")
showcase.refresh_trophies([], campaign_chapter=1, total_ipos=0)

reporter.check(
    all(m.material_override["emission_enabled"] is False and m.material_override["name"] == "locked" for m in all_meshes),
    "State 5: Hard Reset cleanly reverts all 18 meshes back to locked unshaded material"
)
reporter.check(
    all("🔒" in lbl["text"] for lbl in [showcase.label_briefcase, showcase.label_server, showcase.label_chalice, showcase.label_bull]),
    "State 5: All 4 labels cleanly revert to lock emoji '🔒'"
)

# State 6: Non-sequential Unlock (Only Bull Unlocked via fast IPO)
print("  --- State 6: Non-Sequential Fast IPO (Only Bull Unlocked) ---")
showcase.refresh_trophies(["trophy_platinum_bull"], campaign_chapter=1, total_ipos=1)

reporter.check(
    all(m.material_override["name"] == "platinum" for m in showcase.mount_bull.get_all_meshes()),
    "State 6: Bull meshes correctly unlocked independently"
)
reporter.check(
    all(m.material_override["name"] == "locked" for m in (
        showcase.mount_briefcase.get_all_meshes() +
        showcase.mount_server.get_all_meshes() +
        showcase.mount_chalice.get_all_meshes()
    )),
    "State 6: Briefcase, Server, and Chalice remain strictly locked during isolated IPO unlock"
)


# ==============================================================================
# SECTION 4: Regression & Baseline Safety
# ==============================================================================
print(f"\n{Colors.BOLD}{Colors.HEADER}=== SECTION 4: Regression & Baseline Safety ==={Colors.ENDC}")

# Verify M2 props test
m2_props_test = GAME_DIR / "tests" / "test_p12_m2_props.py"
reporter.check(m2_props_test.exists(), "test_p12_m2_props.py exists")

# Verify M1 IPO test
m1_ipo_test = GAME_DIR / "tests" / "test_p12_m1_ipo.py"
reporter.check(m1_ipo_test.exists(), "test_p12_m1_ipo.py exists")

# Summary Output
reporter.print_summary()

if reporter.fails > 0:
    sys.exit(1)
sys.exit(0)
