#!/usr/bin/env python3
"""
Adversarial Stress Test: Consecutive Executions of test_full_stack_qa.gd
Verifies:
  1. Multiple rapid consecutive runs pass with 100% integrity (exit code 0)
  2. Total assertion counts domain by domain remain strictly deterministic across runs
  3. No state leaks between runs
  4. No persistent file pollution in user:// (both with existing savegame and fresh install scenario)
"""

import os
import sys
import subprocess
import hashlib
import shutil
import time

def get_user_dir():
    appdata = os.environ.get("APPDATA", "")
    if not appdata:
        appdata = os.path.expanduser("~")
    return os.path.join(appdata, "Godot", "app_userdata", "IdleArcade")

def snapshot_user_dir(user_dir):
    snapshot = {}
    if not os.path.exists(user_dir):
        return snapshot
    for root, dirs, files in os.walk(user_dir):
        for f in files:
            full_p = os.path.join(root, f)
            rel_p = os.path.relpath(full_p, user_dir)
            try:
                with open(full_p, "rb") as fh:
                    h = hashlib.sha256(fh.read()).hexdigest()
                snapshot[rel_p] = h
            except Exception as e:
                snapshot[rel_p] = f"error: {e}"
    return snapshot

def run_godot_qa():
    cmd = ["godot", "--headless", "--path", "IdleArcade", "-s", "tests/test_full_stack_qa.gd"]
    t0 = time.time()
    res = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, encoding="utf-8", errors="replace", cwd="c:\\Projects\\Game")
    duration = time.time() - t0
    return res.returncode, res.stdout, res.stderr, duration

def parse_summary(stdout):
    results = {}
    for line in stdout.splitlines():
        if "Domain 1: Backend Core & Economy" in line:
            results["d1"] = line.strip()
        elif "Domain 2: Frontend UI/UX & Touch Ergonomics" in line:
            results["d2"] = line.strip()
        elif "Domain 3: 3D Campus Stations & Interactions" in line:
            results["d3"] = line.strip()
        elif "Domain 4: Interactive Arcade Minigames" in line:
            results["d4"] = line.strip()
        elif "TOTAL ASSERTIONS" in line:
            results["total"] = line.strip()
    return results

def main():
    print("=" * 70)
    print(">>> ADVERSARIAL CHALLENGE: DOMAIN 4 RUNNER CONSECUTIVE RUNS & LEAK CHECK <<<")
    print("=" * 70)

    user_dir = get_user_dir()
    print(f"User Directory: {user_dir}")

    # Baseline snapshot
    initial_snap = snapshot_user_dir(user_dir)
    print(f"Initial files in user://: {len(initial_snap)}")
    for k in sorted(initial_snap.keys()):
        print(f"  - {k}")

    # Phase A: 3 Consecutive Runs under normal conditions
    runs_data = []
    print("\n--- PHASE A: 3 Rapid Consecutive Runs ---")
    for r in range(1, 4):
        print(f"\n[Run {r}/3] Executing test_full_stack_qa.gd...")
        code, out, err, dur = run_godot_qa()
        if code != 0:
            print(f"[FAIL] Run {r} failed with exit code {code}!")
            print(f"Stderr:\n{err}")
            sys.exit(1)
        
        summary = parse_summary(out)
        print(f"  Execution Time: {dur:.2f}s | Exit Code: {code}")
        print(f"  {summary.get('d1', 'D1 missing')}")
        print(f"  {summary.get('d2', 'D2 missing')}")
        print(f"  {summary.get('d3', 'D3 missing')}")
        print(f"  {summary.get('d4', 'D4 missing')}")
        print(f"  {summary.get('total', 'Total missing')}")

        assert "d1" in summary and "351 Passed" in summary["d1"], f"Run {r} D1 count mismatch!"
        assert "d2" in summary and "313 Passed" in summary["d2"], f"Run {r} D2 count mismatch!"
        assert "d3" in summary and "399 Passed" in summary["d3"], f"Run {r} D3 count mismatch!"
        assert "d4" in summary and "271 Passed" in summary["d4"], f"Run {r} D4 count mismatch!"
        assert "total" in summary and "1334 Passed" in summary["total"], f"Run {r} Total count mismatch!"
        runs_data.append(summary)

    # Check for file leaks after 3 runs
    mid_snap = snapshot_user_dir(user_dir)
    # Ignore logs/
    initial_non_log = {k: v for k, v in initial_snap.items() if not k.startswith("logs")}
    mid_non_log = {k: v for k, v in mid_snap.items() if not k.startswith("logs")}

    # Check if new non-log files were created
    new_files = set(mid_non_log.keys()) - set(initial_non_log.keys())
    print(f"\nNew persistent files created during Phase A: {list(new_files)}")
    assert len(new_files) == 0, f"Leaked persistent files detected: {new_files}"

    # Phase B: Fresh-install simulation (no existing savegame.json)
    print("\n--- PHASE B: Fresh Install Simulation (Zero Existing Savegame) ---")
    savegame_path = os.path.join(user_dir, "savegame.json")
    backup_path = os.path.join(user_dir, "savegame.json.challenger_bak")
    if os.path.exists(savegame_path):
        shutil.move(savegame_path, backup_path)
    
    try:
        assert not os.path.exists(savegame_path), "savegame.json still exists!"
        print("[Fresh Run] Executing test_full_stack_qa.gd with clean user:// (no savegame.json)...")
        code, out, err, dur = run_godot_qa()
        assert code == 0, f"Fresh install run failed with exit code {code}!"
        summary = parse_summary(out)
        print(f"  Execution Time: {dur:.2f}s | Exit Code: {code}")
        print(f"  {summary.get('total', 'Total missing')}")
        assert "1334 Passed" in summary.get("total", ""), "Pass count changed on fresh install run!"

        # Verify that savegame.json was either removed or cleanly restored
        # In test_full_stack_qa.gd, line 133:
        # elif FileAccess.file_exists("user://savegame.json"):
        #     DirAccess.remove_absolute("user://savegame.json")
        # So savegame.json should NOT exist now!
        if os.path.exists(savegame_path):
            print(f"[FAIL] savegame.json was left behind in user:// after fresh install run!")
            sys.exit(1)
        else:
            print("  [PASS] Clean teardown verified: No temporary savegame.json left behind in user://")
    finally:
        # Restore original savegame
        if os.path.exists(backup_path):
            shutil.move(backup_path, savegame_path)
            print("  [RESTORE] Restored original savegame.json from backup.")

    print("\n" + "=" * 70)
    print(">>> DOMAIN 4 RUNNER CONSECUTIVE RUNS & LEAK CHECK: ALL PASSED <<<")
    print("=" * 70)

if __name__ == "__main__":
    main()
