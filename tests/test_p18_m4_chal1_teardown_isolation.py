#!/usr/bin/env python3
"""
Adversarial Stress Test Suite for Phase 18 Milestone 4 Iteration 2:
Empirical Verification & Challenge of Check 5.6 & Teardown Isolation
Target: IdleArcade/tests/test_phase18_e2e_verify.py
Agent: p18_m4_it2_chal1 (Empirical Challenger)
"""

import sys
import os
import re
import ast
import shutil
import hashlib
import tempfile
import subprocess
import time
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


def strip_ansi(text: str) -> str:
    return re.sub(r'\x1b\[[0-9;]*[a-zA-Z]', '', text)


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
    print(">>> PHASE 18 M4-IT2 EMPIRICAL CHALLENGER SUITE: CHECK 5.6 INTEGRITY <<<")
    print(">>> Agent: p18_m4_it2_chal1 | Focus: Teardown, Isolation & AST Audits <<<")
    print(f"Workspace Root: {ROOT_DIR}")
    print(f"Game Directory: {GAME_DIR}")
    print("====================================================================")

    with tempfile.TemporaryDirectory() as tmp_dir:
        tmp_path = Path(tmp_dir)
        mock_save = tmp_path / "savegame.json"
        mock_bak = tmp_path / "savegame.json.oracle_bak"

        # ======================================================================
        # SECTION 1: Direct Invariant Challenge Testing on Check 5.6
        # ======================================================================
        print("\n--- SECTION 1: Direct Invariant Challenge Testing on Check 5.6 ---")

        # Challenge 1.1: Content Tampering (sha_before != sha_after)
        content_before = b'{"version": 1, "energy": 500.0}'
        content_after = b'{"version": 1, "energy": 999.0}'
        mock_save.write_bytes(content_before)
        sha_before = hashlib.sha256(content_before).hexdigest()
        mock_save.write_bytes(content_after)
        if mock_bak.exists():
            mock_bak.unlink()

        rep1 = oracle_mod.OracleReporter()
        res1 = evaluate_check_5_6(rep1, mock_save, sha_before)
        record_challenge(
            "Challenge 1.1: Content tampering detected: Check 5.6 records [FAIL] on hash mismatch",
            res1 is False and rep1.tier_results["Tier 5"]["failed"] == 1,
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

        # Challenge 1.4: Uncleaned Backup File (.json.oracle_bak left on disk)
        content_clean = b'{"version": 1, "energy": 1234.5}'
        mock_save.write_bytes(content_clean)
        sha_clean = hashlib.sha256(content_clean).hexdigest()
        mock_bak.write_bytes(content_clean)

        rep4 = oracle_mod.OracleReporter()
        res4 = evaluate_check_5_6(rep4, mock_save, sha_clean)
        record_challenge(
            "Challenge 1.4: Backup file left behind: Check 5.6 records [FAIL] with backup_cleaned=False",
            res4 is False and rep4.tier_results["Tier 5"]["failed"] == 1 and "backup_cleaned=False" in rep4.failures[0][2],
            f"Failures recorded: {rep4.failures}"
        )

        # Challenge 1.5: Compound Failure (Tampered Content + Uncleaned Backup)
        mock_save.write_bytes(b'{"tampered": true}')
        mock_bak.write_bytes(content_clean)

        rep5 = oracle_mod.OracleReporter()
        res5 = evaluate_check_5_6(rep5, mock_save, sha_clean)
        record_challenge(
            "Challenge 1.5: Compound failure: Check 5.6 records [FAIL] on both hash mismatch & uncleaned backup",
            res5 is False and rep5.tier_results["Tier 5"]["failed"] == 1 and "backup_cleaned=False" in rep5.failures[0][2],
            f"Failures recorded: {rep5.failures}"
        )

        # Challenge 1.6: Clean State Evaluation
        mock_save.write_bytes(content_clean)
        if mock_bak.exists():
            mock_bak.unlink()

        rep6 = oracle_mod.OracleReporter()
        res6 = evaluate_check_5_6(rep6, mock_save, sha_clean)
        record_challenge(
            "Challenge 1.6: Clean state: Check 5.6 records [PASS] when hashes match and backup is cleaned",
            res6 is True and rep6.tier_results["Tier 5"]["passed"] == 1 and rep6.tier_results["Tier 5"]["failed"] == 0,
            f"Result: {rep6.tier_results}"
        )

        # Clean mock files
        if mock_save.exists():
            mock_save.unlink()
        if mock_bak.exists():
            mock_bak.unlink()

    # ======================================================================
    # SECTION 2: Context Manager Lifecycle Hardening (CI vs Dev Environments)
    # ======================================================================
    print("\n--- SECTION 2: Context Manager Lifecycle Hardening (CI vs Dev) ---")

    # Challenge 2.1: Clean CI Environment (No pre-existing savegame)
    # Simulate a clean CI runner where APPDATA points to an empty temporary sandbox
    with tempfile.TemporaryDirectory() as ci_sandbox:
        ci_appdata = Path(ci_sandbox)
        ci_target_dir = ci_appdata / "Godot" / "app_userdata" / "IdleArcade"
        ci_save = ci_target_dir / "savegame.json"
        ci_bak = ci_target_dir / "savegame.json.oracle_bak"

        # Patch environment temporarily
        orig_appdata = os.environ.get("APPDATA")
        os.environ["APPDATA"] = str(ci_appdata)
        try:
            # Verify clean initial state
            assert not ci_save.exists(), "CI savegame must not exist initially"

            with oracle_mod.preserve_user_savegame() as p:
                assert p == ci_save, f"Expected {ci_save}, got {p}"
                assert not ci_bak.exists(), "Backup must not be created when savegame absent"
                # Simulate test subprocess creating savegame during execution
                ci_target_dir.mkdir(parents=True, exist_ok=True)
                ci_save.write_text('{"ci_test": true, "energy": 100.0}', encoding="utf-8")
                assert ci_save.exists(), "Temporary savegame created during test"

            # After exit: preserve_user_savegame must clean up temporary savegame on clean CI runners
            record_challenge(
                "Challenge 2.1: Clean CI Environment: Temporary savegame deleted on exit without crashing",
                not ci_save.exists() and not ci_bak.exists(),
                f"ci_save.exists={ci_save.exists()}, ci_bak.exists={ci_bak.exists()}"
            )
        finally:
            if orig_appdata:
                os.environ["APPDATA"] = orig_appdata

    # Challenge 2.2: Developer Environment (Pre-existing savegame non-destructive restore)
    with tempfile.TemporaryDirectory() as dev_sandbox:
        dev_appdata = Path(dev_sandbox)
        dev_target_dir = dev_appdata / "Godot" / "app_userdata" / "IdleArcade"
        dev_target_dir.mkdir(parents=True, exist_ok=True)
        dev_save = dev_target_dir / "savegame.json"
        dev_bak = dev_target_dir / "savegame.json.oracle_bak"

        dev_initial_content = '{"user_id": "player_42", "energy": 999999.0, "vip": true}'
        dev_save.write_text(dev_initial_content, encoding="utf-8")

        orig_appdata = os.environ.get("APPDATA")
        os.environ["APPDATA"] = str(dev_appdata)
        try:
            with oracle_mod.preserve_user_savegame() as p:
                assert dev_bak.exists(), "Backup must exist inside context block"
                # Simulate test mutation
                dev_save.write_text('{"mutated": true}', encoding="utf-8")

            restored_content = dev_save.read_text(encoding="utf-8")
            record_challenge(
                "Challenge 2.2: Dev Environment: Pre-existing savegame restored byte-for-byte and backup unlinked",
                restored_content == dev_initial_content and not dev_bak.exists(),
                f"Content match: {restored_content == dev_initial_content}, backup exists: {dev_bak.exists()}"
            )
        finally:
            if orig_appdata:
                os.environ["APPDATA"] = orig_appdata

    # Challenge 2.3: Exception Safety in Context Teardown
    with tempfile.TemporaryDirectory() as exc_sandbox:
        exc_appdata = Path(exc_sandbox)
        exc_target_dir = exc_appdata / "Godot" / "app_userdata" / "IdleArcade"
        exc_target_dir.mkdir(parents=True, exist_ok=True)
        exc_save = exc_target_dir / "savegame.json"
        exc_bak = exc_target_dir / "savegame.json.oracle_bak"

        exc_initial_content = '{"user_id": "player_exc", "energy": 12345.0}'
        exc_save.write_text(exc_initial_content, encoding="utf-8")

        orig_appdata = os.environ.get("APPDATA")
        os.environ["APPDATA"] = str(exc_appdata)
        caught_exception = False
        try:
            try:
                with oracle_mod.preserve_user_savegame() as p:
                    exc_save.write_text('{"corrupted_mid_run": true}', encoding="utf-8")
                    raise RuntimeError("Simulated crash in test execution")
            except RuntimeError:
                caught_exception = True

            restored_after_exc = exc_save.read_text(encoding="utf-8")
            record_challenge(
                "Challenge 2.3: Exception Safety: Savegame restored and backup unlinked after RuntimeError",
                caught_exception and restored_after_exc == exc_initial_content and not exc_bak.exists(),
                f"caught={caught_exception}, match={restored_after_exc == exc_initial_content}, bak={exc_bak.exists()}"
            )
        finally:
            if orig_appdata:
                os.environ["APPDATA"] = orig_appdata

    # ======================================================================
    # SECTION 3: AST Tautology & Call Site Static Analysis
    # ======================================================================
    print("\n--- SECTION 3: AST Tautology & Call Site Static Analysis ---")

    target_file = GAME_DIR / "tests/test_phase18_e2e_verify.py"
    tree = ast.parse(target_file.read_text(encoding="utf-8"))

    check_calls = []
    tautologies = []

    for node in ast.walk(tree):
        if isinstance(node, ast.Call) and getattr(node.func, "attr", "") == "check":
            check_calls.append(node)
            condition_node = node.args[1]

            # Check 1: Direct Constant(value=True or value=False)
            if isinstance(condition_node, ast.Constant) and condition_node.value in (True, False):
                tautologies.append((node.lineno, ast.unparse(condition_node), "ast.Constant(True/False)"))

            # Check 2: Direct self-comparison (e.g. x == x, x is x)
            elif isinstance(condition_node, ast.Compare):
                left_str = ast.unparse(condition_node.left)
                for comparator in condition_node.comparators:
                    right_str = ast.unparse(comparator)
                    # Check literal self-comparison
                    if left_str == right_str and not isinstance(condition_node.left, ast.Call):
                        tautologies.append((node.lineno, ast.unparse(condition_node), "Self-comparison"))

    # Static AST call sites: 255 unique check() call nodes in AST
    # Runtime executed checks: 280 total across Tiers 1-5 (due to loop expansions)
    record_challenge(
        f"Challenge 3.1: AST Call Sites Verified (255 static AST call sites expanding to 280 runtime checks)",
        len(check_calls) == 255,
        f"Static AST call site count: {len(check_calls)} (expands to 280 runtime checks via loops)"
    )

    record_challenge(
        f"Challenge 3.2: Zero AST tautologies detected across all check call sites (found: {len(tautologies)})",
        len(tautologies) == 0,
        f"Tautologies: {tautologies}"
    )

    # Check 5.6 specific AST structure inspection
    # Check 5.6 must evaluate savegame_intact
    check_5_6_nodes = [
        node for node in check_calls
        if any(isinstance(a, ast.Constant) and "5.6 Environment teardown complete" in str(a.value) for a in node.args)
    ]
    check_5_6_valid = False
    if check_5_6_nodes:
        c56 = check_5_6_nodes[0]
        arg1_unparsed = ast.unparse(c56.args[1])
        check_5_6_valid = (arg1_unparsed == "savegame_intact")

    record_challenge(
        "Challenge 3.3: Check 5.6 condition evaluates dynamic variable 'savegame_intact'",
        check_5_6_valid,
        f"Check 5.6 condition AST: {ast.unparse(check_5_6_nodes[0].args[1]) if check_5_6_nodes else 'None'}"
    )

    # ======================================================================
    # SECTION 4: Subprocess Mutation Verification (Isolated Sandbox)
    # ======================================================================
    print("\n--- SECTION 4: Subprocess Mutation Testing ---")

    prod_code = target_file.read_text(encoding="utf-8")

    # Mutant 1: Skip restore and leave modified savegame on disk
    mutant_1_target = "if had_savegame and backup_file and backup_file.exists():\n                for _ in range(10):\n                    try:\n                        shutil.copy2(backup_file, save_path)\n                        break\n                    except OSError:\n                        time.sleep(0.05)"
    mutant_1_replacement = "if had_savegame and backup_file and backup_file.exists():\n                # MUTATION 1: Corrupt savegame and skip restore\n                save_path.write_bytes(b'MUTATION_TAMPERED_DATA')"

    if mutant_1_target in prod_code:
        mutant_1_code = prod_code.replace(mutant_1_target, mutant_1_replacement)
        with tempfile.NamedTemporaryFile("w", suffix=".py", delete=False, encoding="utf-8") as f_m1:
            mut_1_path = Path(f_m1.name)
            f_m1.write(mutant_1_code)

        try:
            with tempfile.TemporaryDirectory() as sb1_dir:
                sb1_appdata = Path(sb1_dir)
                sb1_game_dir = sb1_appdata / "Godot" / "app_userdata" / "IdleArcade"
                sb1_game_dir.mkdir(parents=True, exist_ok=True)
                sb1_save = sb1_game_dir / "savegame.json"
                # Seed valid dummy savegame so had_savegame is guaranteed True
                sb1_save.write_text('{"user_id": "seed_m1", "energy": 500.0, "total_energy_earned": 500.0}', encoding="utf-8")

                env_m1 = {**os.environ, "APPDATA": str(sb1_appdata)}
                res_m1 = subprocess.run(
                    [sys.executable, str(mut_1_path), "--tier=5"],
                    cwd=str(GAME_DIR), env=env_m1, capture_output=True, text=True, timeout=60
                )
                clean_out_m1 = strip_ansi(res_m1.stdout + "\n" + res_m1.stderr)
                fail_detected = "[FAIL] [Tier 5] 5.6 Environment teardown complete" in clean_out_m1
                code_1 = (res_m1.returncode == 1)
                record_challenge(
                    "Challenge 4.1: Subprocess Mutation 1: Tampered savegame detected by Check 5.6 (Exit Code 1)",
                    fail_detected and code_1,
                    f"returncode={res_m1.returncode}, fail_detected={fail_detected}"
                )
        finally:
            if mut_1_path.exists():
                mut_1_path.unlink()
    else:
        record_challenge("Challenge 4.1: Subprocess Mutation 1", False, "Target string not in production script")

    # Mutant 2: Skip backup file unlinking (.json.oracle_bak not deleted)
    mutant_2_target = "for _ in range(10):\n                    try:\n                        backup_file.unlink()\n                        break\n                    except OSError:\n                        time.sleep(0.05)"
    mutant_2_replacement = "# MUTATION 2: Skip unlinking backup file\n                pass"

    if mutant_2_target in prod_code:
        mutant_2_code = prod_code.replace(mutant_2_target, mutant_2_replacement)
        with tempfile.NamedTemporaryFile("w", suffix=".py", delete=False, encoding="utf-8") as f_m2:
            mut_2_path = Path(f_m2.name)
            f_m2.write(mutant_2_code)

        try:
            with tempfile.TemporaryDirectory() as sb2_dir:
                sb2_appdata = Path(sb2_dir)
                sb2_game_dir = sb2_appdata / "Godot" / "app_userdata" / "IdleArcade"
                sb2_game_dir.mkdir(parents=True, exist_ok=True)
                sb2_save = sb2_game_dir / "savegame.json"
                # Seed valid dummy savegame so had_savegame is guaranteed True
                sb2_save.write_text('{"user_id": "seed_m2", "energy": 500.0, "total_energy_earned": 500.0}', encoding="utf-8")

                env_m2 = {**os.environ, "APPDATA": str(sb2_appdata)}
                res_m2 = subprocess.run(
                    [sys.executable, str(mut_2_path), "--tier=5"],
                    cwd=str(GAME_DIR), env=env_m2, capture_output=True, text=True, timeout=60
                )
                clean_out_m2 = strip_ansi(res_m2.stdout + "\n" + res_m2.stderr)
                fail_detected = "[FAIL] [Tier 5] 5.6 Environment teardown complete" in clean_out_m2
                backup_cleaned_false = "backup_cleaned=False" in clean_out_m2
                code_1 = (res_m2.returncode == 1)
                record_challenge(
                    "Challenge 4.2: Subprocess Mutation 2: Uncleaned backup detected by Check 5.6 (backup_cleaned=False, Exit Code 1)",
                    fail_detected and backup_cleaned_false and code_1,
                    f"returncode={res_m2.returncode}, fail_detected={fail_detected}, backup_cleaned_false={backup_cleaned_false}"
                )
        finally:
            if mut_2_path.exists():
                mut_2_path.unlink()
    else:
        record_challenge("Challenge 4.2: Subprocess Mutation 2", False, "Target string not in production script")

    # Ensure real environment cleanup
    appdata = os.environ.get("APPDATA")
    if sys.platform == "win32" and appdata:
        real_sp = Path(appdata) / "Godot" / "app_userdata" / "IdleArcade" / "savegame.json"
        real_sb = real_sp.with_suffix(".json.oracle_bak")
        if real_sb.exists():
            shutil.copy2(real_sb, real_sp)
            real_sb.unlink()

    # ======================================================================
    # FINAL SUMMARY
    # ======================================================================
    total_challenges = passed_challenges + failed_challenges
    print("\n====================================================================")
    print(">>> EMPIRICAL CHALLENGER FINAL SUMMARY (p18_m4_it2_chal1) <<<")
    print("====================================================================")
    print(f"  Total Adversarial Challenges : {total_challenges}")
    print(f"  Passed                       : \033[92m{passed_challenges}\033[0m")
    print(f"  Failed                       : \033[91m{failed_challenges}\033[0m")
    print("====================================================================")

    if failed_challenges == 0:
        print("\033[1m\033[92m>>> ALL 14 ADVERSARIAL CHALLENGES PASSED WITH 100% EMPIRICAL INTEGRITY! <<<\033[0m\n")
        sys.exit(0)
    else:
        print(f"\033[1m\033[91m>>> {failed_challenges} ADVERSARIAL CHALLENGES FAILED! <<<\033[0m\n", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    run_all_challenges()
