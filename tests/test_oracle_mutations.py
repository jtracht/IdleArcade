#!/usr/bin/env python3
"""
Adversarial Stress Test: Python Master Oracle Mutation & Robustness Harness
File: IdleArcade/tests/test_oracle_mutations.py

Empirically tests that test_phase16_verify.py:
  1. Is deterministic and environment-agnostic (runs from both Root and IdleArcade cwd with identical results)
  2. Is NOT a false oracle: detects mathematical, AST, UI ergonomic, and CI/CD mutations
  3. Fails cleanly with non-zero exit code when any invariant is broken
"""

import os
import sys
import subprocess
import shutil
import tempfile
import time
from pathlib import Path

def run_oracle(cwd: str):
    cmd = [sys.executable, "IdleArcade/tests/test_phase16_verify.py" if "IdleArcade" not in cwd else "tests/test_phase16_verify.py"]
    res = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True, encoding="utf-8", errors="replace")
    return res.returncode, res.stdout, res.stderr

def run_isolated_mutation(test_name: str, mutation_fn):
    """Executes a mutation in a temporary backup context and asserts the oracle detects it."""
    print(f"  [Mutation Test] {test_name}...", end=" ", flush=True)
    success = False
    try:
        mutation_fn()
        code, out, err = run_oracle("c:\\Projects\\Game")
        if code != 0:
            print(f"PASSED (Oracle correctly rejected mutation with exit code {code})")
            success = True
        else:
            print("FAILED! (Oracle falsely passed despite mutation!)")
    except Exception as e:
        print(f"ERROR during mutation setup: {e}")
    return success

def strip_ansi(text: str) -> str:
    import re
    return re.sub(r'\x1b\[[0-9;]*m', '', text)

def main():
    print("=" * 70)
    print(">>> ADVERSARIAL CHALLENGE: PYTHON ORACLE MUTATION & SENSITIVITY <<<")
    print("=" * 70)

    # -------------------------------------------------------------------------
    # 1. Determinism & Working Directory Agnosticism
    # -------------------------------------------------------------------------
    print("\n--- TEST 1: Working Directory Agnosticism & Determinism ---")

    # Run from c:\Projects\Game
    code1, out1, err1 = run_oracle("c:\\Projects\\Game")
    assert code1 == 0, f"Oracle failed from c:\\Projects\\Game (code {code1})"
    clean_out1 = strip_ansi(out1)
    assert "Passed       : 266" in clean_out1, f"Expected 266 passed from root, got:\n{clean_out1[-400:]}"
    print("  [PASS] Execution from c:\\Projects\\Game returned exit code 0 with 266/266 passed.")

    # Run from c:\Projects\Game\IdleArcade
    code2, out2, err2 = run_oracle("c:\\Projects\\Game\\IdleArcade")
    assert code2 == 0, f"Oracle failed from c:\\Projects\\Game\\IdleArcade (code {code2})"
    clean_out2 = strip_ansi(out2)
    assert "Passed       : 266" in clean_out2, f"Expected 266 passed from IdleArcade, got:\n{clean_out2[-400:]}"
    print("  [PASS] Execution from c:\\Projects\\Game\\IdleArcade returned exit code 0 with 266/266 passed.")

    # -------------------------------------------------------------------------
    # 2. Mutation Testing: AST & Static Analysis (Tier 1)
    # -------------------------------------------------------------------------
    print("\n--- TEST 2: Tier 1 AST Mutation Sensitivity ---")
    st_path = Path("c:/Projects/Game/IdleArcade/scripts/server_terminal.gd")
    st_orig = st_path.read_text(encoding="utf-8")

    # Mutation 1: Corrupt class_name in server_terminal.gd
    def mutate_classname():
        st_path.write_text(st_orig.replace("class_name ServerTerminal", "class_name MutatedServerTerminal"), encoding="utf-8")
    
    try:
        passed = run_isolated_mutation("Corrupted class_name in ServerTerminal", mutate_classname)
        assert passed, "Oracle failed to detect corrupted class_name!"
    finally:
        st_path.write_text(st_orig, encoding="utf-8")

    # Mutation 2: Remove a required signal by renaming keyword
    def mutate_signal_rename():
        st_path.write_text(st_orig.replace("signal overclock_completed", "signal_disabled overclock_completed"), encoding="utf-8")

    try:
        passed = run_isolated_mutation("Deleted signal 'overclock_completed' (keyword removed)", mutate_signal_rename)
        assert passed, "Oracle failed to detect deleted signal!"
    finally:
        st_path.write_text(st_orig, encoding="utf-8")

    # -------------------------------------------------------------------------
    # 3. Mutation Testing: UI Ergonomics & Touch Target (Tier 3)
    # -------------------------------------------------------------------------
    print("\n--- TEST 3: Tier 3 UI Ergonomics Mutation Sensitivity ---")
    cs_path = Path("c:/Projects/Game/IdleArcade/scripts/ui/cyber_sync_minigame.gd")
    cs_orig = cs_path.read_text(encoding="utf-8")

    def mutate_touch_target():
        # Change 56.0 minimum size to 40.0
        cs_path.write_text(cs_orig.replace("56.0", "40.0").replace("56", "40"), encoding="utf-8")

    try:
        passed = run_isolated_mutation("Touch target reduced below 56px (40px)", mutate_touch_target)
        assert passed, "Oracle failed to detect substandard touch target height!"
    finally:
        cs_path.write_text(cs_orig, encoding="utf-8")

    # -------------------------------------------------------------------------
    # 4. Mutation Testing: Workflow Synchronization (Tier 5)
    # -------------------------------------------------------------------------
    print("\n--- TEST 4: Tier 5 CI/CD Workflow Sync Mutation Sensitivity ---")
    wf_path = Path("c:/Projects/Game/.github/workflows/build.yml")
    wf_orig_bytes = wf_path.read_bytes()

    def mutate_workflow():
        wf_path.write_bytes(wf_orig_bytes + b"\n# Desynchronization mutation comment\n")

    try:
        passed = run_isolated_mutation("Dual workflow desynchronization (extra comment in root)", mutate_workflow)
        assert passed, "Oracle failed to detect desynchronized GitHub Actions workflows!"
    finally:
        wf_path.write_bytes(wf_orig_bytes)

    # -------------------------------------------------------------------------
    # 5. Final Clean Verification
    # -------------------------------------------------------------------------
    print("\n--- TEST 5: Restored Baseline Verification ---")
    final_code, final_out, final_err = run_oracle("c:\\Projects\\Game")
    assert final_code == 0, f"Final restore failed (exit code {final_code})"
    clean_final_out = strip_ansi(final_out)
    assert "Passed       : 266" in clean_final_out, "Assertion count mismatch on final restore!"
    print("  [PASS] Baseline cleanly restored: 266 Passed, 0 Failed, Exit Code 0.")

    print("\n" + "=" * 70)
    print(">>> ORACLE MUTATION & SENSITIVITY TESTING: ALL PASSED <<<")
    print("=" * 70)

if __name__ == "__main__":
    main()
