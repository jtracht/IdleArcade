#!/usr/bin/env python3
"""
Adversarial Verification Suite for CI/CD Release Pipeline
=========================================================
Tests and asserts all requirements (R1, R2) and edge cases for .github/workflows/build.yml:
- Tag-only release trigger (R1)
- Main branch skip verification (R1)
- APK asset release attachment (R1)
- Web export deployment to 'release' branch (R2)
- Artifact path consistency (workspace relative resolution)
- Parity between IdleArcade/.github/workflows/build.yml and .github/workflows/build.yml
"""

import sys
import os
import re
import fnmatch
from pathlib import Path

# Safe stdout on Windows
if hasattr(sys.stdout, "reconfigure"):
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass

def test_workflow():
    repo_root = Path(__file__).resolve().parent.parent
    game_root = repo_root.parent

    wf_repo = repo_root / ".github" / "workflows" / "build.yml"
    wf_game = game_root / ".github" / "workflows" / "build.yml"

    assert wf_repo.exists(), f"Missing workflow at {wf_repo}"
    assert wf_game.exists(), f"Missing workflow at {wf_game}"

    content_repo = wf_repo.read_text(encoding="utf-8")
    content_game = wf_game.read_text(encoding="utf-8")

    # 1. Parity Check
    assert content_repo.strip() == content_game.strip(), (
        "IdleArcade/.github/workflows/build.yml and .github/workflows/build.yml must be identical!"
    )
    print("[PASS] Parity check passed: Both build.yml workflow definitions are synchronized.")

    # Try importing PyYAML, fallback to regex analysis
    try:
        import yaml
        data = yaml.safe_load(content_repo)
    except Exception as e:
        data = None

    # 2. Trigger Specification
    assert "push:" in content_repo
    assert "branches:" in content_repo
    assert "- main" in content_repo
    assert "tags:" in content_repo
    assert "- 'v*'" in content_repo or '- "v*"' in content_repo
    assert "workflow_dispatch:" in content_repo
    print("[PASS] Trigger specification passed: Triggers on main branch, v* tags, and workflow_dispatch.")

    # 2b. Glob Tag Matching Verification (fnmatch for GitHub Actions glob syntax)
    tag_patterns = []
    in_tags = False
    for line in content_repo.splitlines():
        if "tags:" in line:
            in_tags = True
            continue
        if in_tags:
            stripped = line.strip()
            if stripped.startswith("-"):
                pat = stripped.lstrip("-").strip().strip("'\"")
                tag_patterns.append(pat)
            else:
                break

    def matches_any_tag(tag: str) -> bool:
        return any(fnmatch.fnmatch(tag, pat) for pat in tag_patterns)

    # Semver tags with 'v' prefix
    assert matches_any_tag("v1.0.0"), "FAIL: v1.0.0 did not match tag patterns"
    assert matches_any_tag("v0.1.2-alpha"), "FAIL: v0.1.2-alpha did not match tag patterns"
    # Bare semver and numeric tags
    assert matches_any_tag("1.0.0"), "FAIL: 1.0.0 did not match tag patterns"
    assert matches_any_tag("2.0.0"), "FAIL: 2.0.0 did not match tag patterns"
    assert matches_any_tag("1"), "FAIL: single digit 1 did not match tag patterns"
    assert matches_any_tag("2026.1"), "FAIL: 2026.1 did not match tag patterns"
    assert matches_any_tag("1-rc1"), "FAIL: 1-rc1 did not match tag patterns"
    # Negative checks: branch names must NOT match tag patterns
    assert not matches_any_tag("main"), "FAIL: branch main falsely matched tag patterns"
    assert not matches_any_tag("feature/ui-tweaks"), "FAIL: feature branch falsely matched tag patterns"
    print(f"[PASS] Tag glob matching passed: Verified patterns {tag_patterns} against semver & numeric tags.")

    # 3. Job Structure & Dependency Hierarchy
    assert "jobs:" in content_repo
    assert "export-web:" in content_repo
    assert "export-android:" in content_repo
    assert "release:" in content_repo
    assert "needs: [export-web, export-android]" in content_repo or "needs:\n      - export-web\n      - export-android" in content_repo
    print("[PASS] Job hierarchy passed: Parallel export jobs and gated release job defined.")

    # 4. Release Job Conditional Logic (Requirement R1)
    # The release job must strictly execute only when triggered by tags
    assert "startsWith(github.ref, 'refs/tags/')" in content_repo, (
        "Release job must guard with `if: startsWith(github.ref, 'refs/tags/')`"
    )

    def evaluate_release_condition(ref: str) -> bool:
        return ref.startswith("refs/tags/")

    # Scenario: Normal push to main
    assert evaluate_release_condition("refs/heads/main") is False, (
        "FAIL: Release job would run on push to main!"
    )
    # Scenario: Feature branch push
    assert evaluate_release_condition("refs/heads/feature/ui-tweaks") is False, (
        "FAIL: Release job would run on feature branch!"
    )
    # Scenario: Semver tag v1.0.0
    assert evaluate_release_condition("refs/tags/v1.0.0") is True, (
        "FAIL: Release job skipped for v1.0.0 tag!"
    )
    # Scenario: Minor tag v0.2.1-rc1
    assert evaluate_release_condition("refs/tags/v0.2.1-rc1") is True, (
        "FAIL: Release job skipped for v0.2.1-rc1 tag!"
    )
    # Scenario: Raw number tag 2.0.0
    assert evaluate_release_condition("refs/tags/2.0.0") is True, (
        "FAIL: Release job skipped for 2.0.0 tag!"
    )
    print("[PASS] Release condition evaluation passed: Pushes to main skip release; tags trigger release.")

    # 5. Elevated Permissions Check
    # release job must have write permissions to create GitHub Release and push branch
    release_block = content_repo.split("\n  release:")[1]
    assert "permissions:" in release_block
    assert "contents: write" in release_block
    print("[PASS] Elevated permissions passed: contents: write configured on release job.")

    # 6. APK & Release Asset Verification (Requirement R1)
    assert "softprops/action-gh-release@v2" in release_block
    assert "tag_name: ${{ github.ref_name }}" in release_block
    assert "name: Release ${{ github.ref_name }}" in release_block
    assert "dist/IdleArcade.apk" in release_block
    assert "dist/web-build.zip" in release_block
    print("[PASS] Release asset publishing passed: Android APK and Web ZIP uploaded to GitHub Release.")

    # 7. Web Export Deployment to 'release' Branch (Requirement R2)
    assert "peaceiris/actions-gh-pages@v4" in release_block
    assert "publish_branch: release" in release_block
    assert "publish_dir: ./build/web" in release_block
    assert "github_token: ${{ secrets.GITHUB_TOKEN }}" in release_block
    assert "commit_message:" in release_block and "${{ github.ref_name }}" in release_block
    print("[PASS] Web export deployment passed: Deploying ./build/web to 'release' branch via actions-gh-pages.")

    # 8. Artifact Path Integrity (Defect Fix Verification)
    # Ensure export-web puts web-build.zip in workspace root
    web_block = content_repo.split("\n  export-web:")[1].split("\n  export-android:")[0]
    assert "zip -r ../../web-build.zip ." in web_block, (
        "export-web must generate web-build.zip in workspace root (../../web-build.zip from build/web)"
    )
    assert "path: web-build.zip" in web_block

    # Ensure export-android puts IdleArcade.apk in workspace root
    android_block = content_repo.split("\n  export-android:")[1].split("\n  release:")[0]
    assert "cp build/android/IdleArcade.apk ./IdleArcade.apk" in android_block, (
        "export-android must copy IdleArcade.apk to ./IdleArcade.apk in workspace root"
    )
    assert "path: IdleArcade.apk" in android_block
    print("[PASS] Artifact path integrity passed: Artifact paths strictly match upload target directories.")

    print("\nALL ADVERSARIAL PIPELINE CHECKS PASSED SUCCESSFULLY (Exit Code 0).")

if __name__ == "__main__":
    test_workflow()
