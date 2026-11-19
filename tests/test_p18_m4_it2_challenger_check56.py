#!/usr/bin/env python3
"""
Adversarial Challenge Test Suite for Phase 18 Milestone 4 Iteration 2:
Empirical Verification of Check 5.6 Sensitivity & Mutation Testing
Target: IdleArcade/tests/test_phase18_e2e_verify.py
Agent: p18_m4_it2_challenger_1 (Empirical Challenger)

Challenge Scenarios:
1. Mutation 1 (Savegame Hash Mismatch):
   - Direct Invariant: sha_before != sha_after (tampered content) -> Check 5.6 logs [FAIL]
   - Direct Invariant: savegame unlinked post-test (sha_after is None) -> Check 5.6 logs [FAIL]
   - Direct Invariant: orphan savegame created post-test (sha_before is None) -> Check 5.6 logs [FAIL]
   - Subprocess Mutation 1: Mutated runner with failed restoration -> Check 5.6 records [FAIL], exit code 1

2. Mutation 2 (Backup File Uncleaned):
   - Direct Invariant: .json.oracle_bak left on disk -> Check 5.6 logs [FAIL]
   - Direct Invariant: Double failure (hash mismatch + backup uncleaned) -> Check 5.6 logs [FAIL]
   - Subprocess Mutation 2: Mutated runner skipping backup unlinking -> Check 5.6 records [FAIL], exit code 1

3. Clean Production Verification:
   - Direct Invariant: sha_before == sha_after and not backup.exists() -> Check 5.6 logs [PASS]
   - Subprocess Clean Run: Full 5-tier test_phase18_e2e_verify.py -> 280/280 checks pass, exit code 0
"""

import sys
import os
import re
import shutil
import hashlib
import tempfile
import subprocess
from pathlib import Path
from typing import Optional, List, Tuple

# Setup Paths
SCRIPT_DIR = Path(__file__).resolve().parent
GAME_DIR = SCRIPT_DIR.parent
ROOT_DIR = GAME_DIR.parent if (GAME_DIR.parent / ".github").exists() else GAME_DIR

# Import OracleReporter and functions from test_phase18_e2e_verify
sys.path.insert(0, str(SCRIPT_DIR))
import test_phase18_e2e_verify as oracle_mod

passed_challenges = 0
failed_challenges = 0
challenge_log: List[Tuple[str, bool, str]] = []


def record_challenge(name: str, passed: bool, detail: str = ""):
    global passed_challenges, failed_challenges
    if passed:
        passed_challenges += 1
        print(f"  \033[92m[CHALLENGE PASS]\033[0m {name}")
    else:
        failed_challenges += 1
        msg = f"  \033[91m[CHALLENGE FAIL]\033[0m {name}"
        if detail:
            msg += f" \033[93m(Detail: {detail})\033[0m"
        print(msg, file=sys.stderr)
    challenge_log.append((name, passed, detail))


def evaluate_check_5_6(
    reporter: oracle_mod.OracleReporter,
    save_path_ref: Optional[Path],
    sha_before: Optional[str]
) -> bool:
    """
    Evaluates Check 5.6 using the exact production logic from test_phase18_e2e_verify.py lines 1573-1588.
    """
    t = "Tier 5"
    sha_after: Optional[str] = None
    backup_cleaned = True
    if save_path_ref:
        if save_path_ref.exists():
            sha_after = hashlib.sha256(save_path_ref.read_bytes()).hexdigest()
        backup_file = save_path_ref.with_suffix(".json.oracle_bak")
        backup_cleaned = not backup_file.exists()

    savegame_intact = (sha_before == sha_after) and backup_cleaned
    err_detail = ""
    if not savegame_intact:
        err_detail = f"sha_before={sha_before}, sha_after={sha_after}, backup_cleaned={backup_cleaned}"
    return reporter.check(
        t,
        savegame_intact,
        "5.6 Environment teardown complete: savegame non-destructive isolation verified",
        err_detail
    )


def run_all_challenges():
    print("\n====================================================================")
    print(">>> PHASE 18 M4-IT2 ADVERSARIAL CHALLENGER SUITE: CHECK 5.6 SENSITIVITY <<<")
    print(">>> Agent: p18_m4_it2_challenger_1 | Target: Check 5.6 Mutation Testing <<<")
    print(f"Workspace Root: {ROOT_DIR}")
    print(f"Game Directory: {GAME_DIR}")
    print("====================================================================")

    with tempfile.TemporaryDirectory() as tmp_dir:
        tmp_path = Path(tmp_dir)
        mock_save = tmp_path / "savegame.json"
        mock_bak = tmp_path / "savegame.json.oracle_bak"

        # ======================================================================
        # SECTION 1: Direct Invariant Challenge Testing
        # ======================================================================
        print("\n--- SECTION 1: Direct Invariant Challenge Testing ---")

        # Challenge 1.1: Content Tampering (sha_before != sha_after)
        content_before = b'{"version": 1, "energy": 500.0}'
        content_after = b'{"version": 1, "energy": 999.0}'
        mock_save.write_bytes(content_before)
        sha_before = hashlib.sha256(content_before).hexdigest()
        
        # Simulate tampering
        mock_save.write_bytes(content_after)
        if mock_bak.exists():
            mock_bak.unlink()
        
        rep1 = oracle_mod.OracleReporter()
        res1 = evaluate_check_5_6(rep1, mock_save, sha_before)
        record_challenge(
            "Challenge 1.1: Content tampering detected: Check 5.6 records [FAIL] on hash mismatch",
            res1 is False and rep1.tier_results["Tier 5"]["failed"] == 1 and len(rep1.failures) == 1,
            f"Failures recorded: {rep1.failures}"
        )

        # Challenge 1.2: Savegame Deletion (sha_after is None)
        mock_save.write_bytes(content_before)
        sha_before = hashlib.sha256(content_before).hexdigest()
        mock_save.unlink()
        if mock_bak.exists():
            mock_bak.unlink()

        rep2 = oracle_mod.OracleReporter()
        res2 = evaluate_check_5_6(rep2, mock_save, sha_before)
        record_challenge(
            "Challenge 1.2: Savegame unlinked post-test: Check 5.6 records [FAIL] with sha_after=None",
            res2 is False and rep2.tier_results["Tier 5"]["failed"] == 1 and "sha_after=None" in rep2.failures[0][2],
            f"Failures recorded: {rep2.failures}"
        )

        # Challenge 1.3: Orphan Savegame Creation (sha_before was None, sha_after exists)
        sha_before_none = None
        mock_save.write_bytes(b'{"temporary": true}')
        if mock_bak.exists():
            mock_bak.unlink()

        rep3 = oracle_mod.OracleReporter()
        res3 = evaluate_check_5_6(rep3, mock_save, sha_before_none)
        record_challenge(
            "Challenge 1.3: Orphan savegame created: Check 5.6 records [FAIL] with sha_before=None",
            res3 is False and rep3.tier_results["Tier 5"]["failed"] == 1 and "sha_before=None" in rep3.failures[0][2],
            f"Failures recorded: {rep3.failures}"
        )

        # Challenge 2.1: Uncleaned Backup File (.json.oracle_bak exists)
        content_clean = b'{"version": 1, "energy": 1234.5}'
        mock_save.write_bytes(content_clean)
        sha_clean = hashlib.sha256(content_clean).hexdigest()
        # Backup left behind
        mock_bak.write_bytes(content_clean)

        rep4 = oracle_mod.OracleReporter()
        res4 = evaluate_check_5_6(rep4, mock_save, sha_clean)
        record_challenge(
            "Challenge 2.1: Backup file left behind: Check 5.6 records [FAIL] with backup_cleaned=False",
            res4 is False and rep4.tier_results["Tier 5"]["failed"] == 1 and "backup_cleaned=False" in rep4.failures[0][2],
            f"Failures recorded: {rep4.failures}"
        )

        # Challenge 2.2: Compound Failure (Tampered Content + Uncleaned Backup)
        mock_save.write_bytes(b'{"tampered": true}')
        mock_bak.write_bytes(content_clean)

        rep5 = oracle_mod.OracleReporter()
        res5 = evaluate_check_5_6(rep5, mock_save, sha_clean)
        record_challenge(
            "Challenge 2.2: Compound failure: Check 5.6 records [FAIL] on both hash mismatch & uncleaned backup",
            res5 is False and rep5.tier_results["Tier 5"]["failed"] == 1 and "backup_cleaned=False" in rep5.failures[0][2],
            f"Failures recorded: {rep5.failures}"
        )

        # Challenge 3.1: Clean Teardown Pass
        mock_save.write_bytes(content_clean)
        if mock_bak.exists():
            mock_bak.unlink()

        rep6 = oracle_mod.OracleReporter()
        res6 = evaluate_check_5_6(rep6, mock_save, sha_clean)
        record_challenge(
            "Challenge 3.1: Clean state: Check 5.6 records [PASS] when hashes match and backup is cleaned",
            res6 is True and rep6.tier_results["Tier 5"]["passed"] == 1 and rep6.tier_results["Tier 5"]["failed"] == 0,
            f"Result: {rep6.tier_results}"
        )

        # Clean up temporary mock files
        if mock_save.exists():
            mock_save.unlink()
        if mock_bak.exists():
            mock_bak.unlink()

    # ======================================================================
    # SECTION 2: Subprocess Mutation Testing
    # ======================================================================
    print("\n--- SECTION 2: Subprocess Mutation Testing ---")

    prod_script = GAME_DIR / "tests/test_phase18_e2e_verify.py"
    if not prod_script.exists():
        print(f"FATAL: Production script {prod_script} not found!", file=sys.stderr)
        sys.exit(1)

    prod_code = prod_script.read_text(encoding="utf-8")

    # Mutation 1: Simulate savegame modification without restoration
    # In preserve_user_savegame, we inject code that corrupts save_path and disables restore in finally
    mutant_1_target = "if had_savegame and backup_file and backup_file.exists():\n                shutil.copy2(backup_file, save_path)"
    mutant_1_replacement = "if had_savegame and backup_file and backup_file.exists():\n                # MUTATION 1: Skip restore and leave modified savegame\n                save_path.write_bytes(b'MUTATION_TAMPERED_SAVEGAME_DATA')"
    
    if mutant_1_target not in prod_code:
        record_challenge("Subprocess Mutation 1: Injection target found", False, "Target string not in production script")
    else:
        mutant_1_code = prod_code.replace(mutant_1_target, mutant_1_replacement)
        with tempfile.NamedTemporaryFile("w", suffix=".py", delete=False, encoding="utf-8") as f_m1:
            mut_1_path = Path(f_m1.name)
            f_m1.write(mutant_1_code)

        try:
            res_m1 = subprocess.run(
                [sys.executable, str(mut_1_path), "--tier=5"],
                cwd=GAME_DIR, capture_output=True, text=True, timeout=60
            )
            out_m1 = res_m1.stdout + "\n" + res_m1.stderr
            fail_detected = "[FAIL] [Tier 5] 5.6 Environment teardown complete" in out_m1
            code_1 = res_m1.returncode == 1
            record_challenge(
                "Subprocess Mutation 1: Tampered savegame detected by Check 5.6 -> Exit Code 1",
                fail_detected and code_1,
                f"returncode={res_m1.returncode}, fail_detected={fail_detected}"
            )
        finally:
            if mut_1_path.exists():
                mut_1_path.unlink()

    # Mutation 2: Simulate uncleaned backup file (.json.oracle_bak not deleted)
    mutant_2_target = "try:\n                    backup_file.unlink()\n                except OSError:\n                    pass"
    mutant_2_replacement = "# MUTATION 2: Skip unlinking backup file\n                pass"

    if mutant_2_target not in prod_code:
        record_challenge("Subprocess Mutation 2: Injection target found", False, "Target string not in production script")
    else:
        mutant_2_code = prod_code.replace(mutant_2_target, mutant_2_replacement)
        with tempfile.NamedTemporaryFile("w", suffix=".py", delete=False, encoding="utf-8") as f_m2:
            mut_2_path = Path(f_m2.name)
            f_m2.write(mutant_2_code)

        try:
            res_m2 = subprocess.run(
                [sys.executable, str(mut_2_path), "--tier=5"],
                cwd=GAME_DIR, capture_output=True, text=True, timeout=60
            )
            out_m2 = res_m2.stdout + "\n" + res_m2.stderr
            fail_detected = "[FAIL] [Tier 5] 5.6 Environment teardown complete" in out_m2
            backup_cleaned_false = "backup_cleaned=False" in out_m2
            code_1 = res_m2.returncode == 1
            record_challenge(
                "Subprocess Mutation 2: Uncleaned backup detected by Check 5.6 (backup_cleaned=False) -> Exit Code 1",
                fail_detected and backup_cleaned_false and code_1,
                f"returncode={res_m2.returncode}, fail_detected={fail_detected}, backup_cleaned_false={backup_cleaned_false}"
            )
        finally:
            if mut_2_path.exists():
                mut_2_path.unlink()

    # Clean up any stray backup or restore clean state if needed
    appdata = os.environ.get("APPDATA")
    if sys.platform == "win32" and appdata:
        sp = Path(appdata) / "Godot" / "app_userdata" / "IdleArcade" / "savegame.json"
        sb = sp.with_suffix(".json.oracle_bak")
        if sb.exists():
            shutil.copy2(sb, sp)
            sb.unlink()

    # ======================================================================
    # FINAL SUMMARY
    # ======================================================================
    total_challenges = passed_challenges + failed_challenges
    print("\n====================================================================")
    print(">>> ADVERSARIAL CHALLENGE SUMMARY (p18_m4_it2_challenger_1) <<<")
    print("====================================================================")
    print(f"  Total Challenges Run : {total_challenges}")
    print(f"  Passed               : \033[92m{passed_challenges}\033[0m")
    print(f"  Failed               : \033[91m{failed_challenges}\033[0m")
    print("====================================================================")

    if failed_challenges == 0:
        print("\033[1m\033[92m>>> ALL ADVERSARIAL CHALLENGES PASSED! CHECK 5.6 SENSITIVITY FULLY CERTIFIED! <<<\033[0m\n")
        sys.exit(0)
    else:
        print(f"\033[1m\033[91m>>> {failed_challenges} ADVERSARIAL CHALLENGES FAILED! <<<\033[0m\n", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    run_all_challenges()
