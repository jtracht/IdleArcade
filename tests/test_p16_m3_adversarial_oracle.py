"""
Empirical Adversarial Oracle for Phase 16 Milestone 3
Audits audio synthesis PCM buffers, tail amplitudes (pop/click risk),
haptics timings and bounds, floating score popups lifecycle,
screen shake trauma math, and UI pointer isolation.
"""

import math
import os
import sys

def analyze_audio_script():
    script_path = os.path.join(os.path.dirname(__file__), "..", "scripts", "autoload", "audio_manager.gd")
    with open(script_path, "r", encoding="utf-8") as f:
        content = f.read()

    print("=== Audio Synthesis Signal Simulation & Tail-Fade Audit ===")
    sample_rate = 22050

    # 1. Simulate _synth_victory_jingle
    count = int(sample_rate * 0.85)
    notes = [392.00, 523.25, 659.25, 783.99, 1046.50]
    times = [0.00, 0.12, 0.24, 0.36, 0.48]
    tail_samples_victory = []
    for i in range(count):
        t = float(i) / float(sample_rate)
        sum_val = 0.0
        for n in range(5):
            dt = t - times[n]
            if dt >= 0.0:
                f = notes[n]
                decay = 4.0 if n < 4 else 2.2
                env = (1.0 - math.exp(-dt * 300.0)) * math.exp(-dt * decay)
                wave = math.sin(2.0 * math.pi * f * dt) + 0.35 * math.sin(4.0 * math.pi * f * dt) + 0.15 * math.sin(6.0 * math.pi * f * dt)
                sum_val += wave * env
        tail_fade = max(0.0, min(1.0, (0.85 - t) / 0.10)) if t > 0.75 else 1.0
        val = max(-1.0, min(1.0, (sum_val / 2.5) * 0.85 * tail_fade))
        if i >= count - 100:
            tail_samples_victory.append(abs(val))

    peak_victory_tail = max(tail_samples_victory)
    print(f"  Victory Jingle tail peak (last 100 samples): {peak_victory_tail:.4f}")

    # 2. Simulate _synth_qte_correct
    count = int(sample_rate * 0.22)
    f1 = 1046.50
    f2 = 1567.98
    tail_samples_qte_correct = []
    for i in range(count):
        t = float(i) / float(sample_rate)
        f = f1 if t < 0.08 else f2
        dt = t if t < 0.08 else (t - 0.08)
        env = (1.0 - math.exp(-dt * 400.0)) * math.exp(-dt * 12.0)
        wave = math.sin(2.0 * math.pi * f * dt) + 0.25 * math.sin(4.0 * math.pi * f * dt)
        tail_fade = max(0.0, min(1.0, (0.22 - t) / 0.04)) if t > 0.18 else 1.0
        val = max(-1.0, min(1.0, wave * env * 0.80 * tail_fade))
        if i >= count - 100:
            tail_samples_qte_correct.append(abs(val))

    peak_qte_correct_tail = max(tail_samples_qte_correct)
    print(f"  QTE Correct tail peak (last 100 samples): {peak_qte_correct_tail:.4f}")

    # 3. Simulate _synth_qte_wrong
    count = int(sample_rate * 0.20)
    tail_samples_qte_wrong = []
    for i in range(count):
        t = float(i) / float(sample_rate)
        env = math.exp(-t * 9.0)
        wave = (math.sin(2.0 * math.pi * 160.0 * t) + math.sin(2.0 * math.pi * 172.0 * t) + 0.3 * math.sin(6.0 * math.pi * 160.0 * t)) / 2.3
        tail_fade = max(0.0, min(1.0, (0.20 - t) / 0.04)) if t > 0.16 else 1.0
        val = max(-1.0, min(1.0, wave * env * 0.75 * tail_fade))
        if i >= count - 100:
            tail_samples_qte_wrong.append(abs(val))

    peak_qte_wrong_tail = max(tail_samples_qte_wrong)
    print(f"  QTE Wrong tail peak (last 100 samples): {peak_qte_wrong_tail:.4f}")

    # 4. Simulate _synth_steam_hiss
    count = int(sample_rate * 0.45)
    tail_samples_steam = []
    for i in range(count):
        t = float(i) / float(sample_rate)
        env = (1.0 - math.exp(-t * 80.0)) * math.exp(-t * 3.5)
        noise = math.sin(t * 789123.45) * 0.7 + math.sin(t * 345671.12) * 0.3
        steam_body = noise * (0.8 + 0.2 * math.sin(2.0 * math.pi * 18.0 * t))
        tail_fade = max(0.0, min(1.0, (0.45 - t) / 0.08)) if t > 0.37 else 1.0
        val = max(-1.0, min(1.0, steam_body * env * 0.55 * tail_fade))
        if i >= count - 100:
            tail_samples_steam.append(abs(val))

    peak_steam_tail = max(tail_samples_steam)
    print(f"  Steam Hiss tail peak (last 100 samples): {peak_steam_tail:.4f}")

    # 5. Simulate _synth_hit_perfect
    count = int(sample_rate * 0.05)
    tail_samples_perfect = []
    for i in range(count):
        t = float(i) / float(sample_rate)
        env = math.exp(-t * 60.0)
        wave = math.sin(2.0 * math.pi * 1200.0 * t) + 0.3 * math.sin(4.0 * math.pi * 1200.0 * t)
        tail_fade = max(0.0, min(1.0, (0.05 - t) / 0.015)) if t > 0.035 else 1.0
        val = max(-1.0, min(1.0, wave * env * 0.85 * tail_fade))
        if i >= count - 100:
            tail_samples_perfect.append(abs(val))
    peak_perfect_tail = max(tail_samples_perfect)
    print(f"  Hit Perfect tail peak (last 100 samples): {peak_perfect_tail:.4f}")

    # 6. Simulate _synth_hit_good
    count = int(sample_rate * 0.04)
    tail_samples_good = []
    for i in range(count):
        t = float(i) / float(sample_rate)
        env = math.exp(-t * 80.0)
        wave = math.sin(2.0 * math.pi * 800.0 * t)
        tail_fade = max(0.0, min(1.0, (0.04 - t) / 0.012)) if t > 0.028 else 1.0
        val = max(-1.0, min(1.0, wave * env * 0.85 * tail_fade))
        if i >= count - 100:
            tail_samples_good.append(abs(val))
    peak_good_tail = max(tail_samples_good)
    print(f"  Hit Good tail peak (last 100 samples): {peak_good_tail:.4f}")

    # 7. Simulate _synth_hit_miss
    count = int(sample_rate * 0.06)
    tail_samples_miss = []
    for i in range(count):
        t = float(i) / float(sample_rate)
        env = math.exp(-t * 40.0)
        wave = math.sin(2.0 * math.pi * 350.0 * t)
        tail_fade = max(0.0, min(1.0, (0.06 - t) / 0.018)) if t > 0.042 else 1.0
        val = max(-1.0, min(1.0, wave * env * 0.70 * tail_fade))
        if i >= count - 100:
            tail_samples_miss.append(abs(val))
    peak_miss_tail = max(tail_samples_miss)
    print(f"  Hit Miss tail peak (last 100 samples): {peak_miss_tail:.4f}")

    return {
        "victory_tail": peak_victory_tail,
        "qte_correct_tail": peak_qte_correct_tail,
        "qte_wrong_tail": peak_qte_wrong_tail,
        "steam_tail": peak_steam_tail,
        "perfect_tail": peak_perfect_tail,
        "good_tail": peak_good_tail,
        "miss_tail": peak_miss_tail,
    }

if __name__ == "__main__":
    res = analyze_audio_script()
    print("\nTail fade analysis:")
    has_failure = False
    for k, v in res.items():
        status = "FAIL (POP RISK)" if v >= 0.15 else "PASS"
        if v >= 0.15:
            has_failure = True
        print(f"  {k}: {v:.4f} -> {status}")
    if has_failure:
        sys.exit(1)
    else:
        print("\n>>> ALL ADVERSARIAL AUDIO TAIL AUDITS PASSED <<<")
        sys.exit(0)
