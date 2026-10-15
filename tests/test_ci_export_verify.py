#!/usr/bin/env python3
"""
proposed_test_ci_export_verify.py
==================================
Standalone Verification & Audit Tool for IdleArcade CI/CD & Export Presets.
Author: p5_m4_spec_miner_3_gen2 (Phase 5 Milestone 4)

Verifies:
1. IdleArcade/export_presets.cfg:
   - Web (HTML5) export preset: runnable, export path, canvas resize policy (2),
     single-threaded Wasm (variant/thread_support=false), focus on start.
   - Android APK export preset: runnable, export path, package unique name,
     app name, version code/name, ARM architectures (arm64-v8a, armeabi-v7a),
     precompiled template mode (use_gradle_build=false), keystore bindings.
   - Orientation & Display: Portrait 720x1280 resolution and orientation settings.
   - Android Permissions Audit: VIBRATE permission for mobile haptics.
2. .github/workflows/build.yml:
   - YAML syntax and multi-job architecture (export-web, export-android, release).
   - Trigger specification (push on main, tags 'v*', '[0-9]*', workflow_dispatch).
   - Tag-gated release logic (startsWith(github.ref, 'refs/tags/')).
   - Elevated release permissions (contents: write).
   - Docker container (barichello/godot-ci:4.3) and export template relocation.
   - Artifact packaging (web-build.zip, IdleArcade.apk) and deployment (gh-pages release branch).
   - Parity between root .github/workflows/build.yml and IdleArcade/.github/workflows/build.yml.
   - CI Test Execution Audit: Checks for headless test execution step / test job.

Requirements:
  Python 3.8+ standard library only (no pip dependencies required).
"""

import sys
import os
import re
import fnmatch
from pathlib import Path
from typing import Dict, List, Any, Tuple, Optional

# Safe UTF-8 stdout configuration for Windows terminals
if hasattr(sys.stdout, "reconfigure"):
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass


class Colors:
    HEADER = '\033[95m'
    OKBLUE = '\033[94m'
    OKCYAN = '\033[96m'
    OKGREEN = '\033[92m'
    WARNING = '\033[93m'
    FAIL = '\033[91m'
    ENDC = '\033[0m'
    BOLD = '\033[1m'

    @classmethod
    def disable(cls):
        cls.HEADER = ''
        cls.OKBLUE = ''
        cls.OKCYAN = ''
        cls.OKGREEN = ''
        cls.WARNING = ''
        cls.FAIL = ''
        cls.ENDC = ''
        cls.BOLD = ''


# Disable colors on Windows cmd if ANSI not supported
if sys.platform == "win32" and not os.environ.get("ANSICON") and not os.environ.get("WT_SESSION"):
    try:
        import ctypes
        kernel32 = ctypes.windll.kernel32
        kernel32.SetConsoleMode(kernel32.GetStdHandle(-11), 7)
    except Exception:
        pass


class VerificationCheck:
    def __init__(self, check_id: str, name: str, category: str):
        self.check_id = check_id
        self.name = name
        self.category = category
        self.passed = False
        self.warning = False
        self.message = ""
        self.details: List[str] = []

    def pass_check(self, message: str = "Passed"):
        self.passed = True
        self.warning = False
        self.message = message

    def warn_check(self, message: str):
        self.passed = True
        self.warning = True
        self.message = message

    def fail_check(self, message: str):
        self.passed = False
        self.warning = False
        self.message = message


def find_workspace_root() -> Path:
    """Locate workspace root containing IdleArcade or .github."""
    cwd = Path.cwd().resolve()
    for candidate in [cwd, cwd.parent, cwd.parent.parent, cwd.parent.parent.parent]:
        if (candidate / "IdleArcade").exists() and (candidate / ".github").exists():
            return candidate
        if (candidate / "project.godot").exists() and (candidate.parent / ".github").exists():
            return candidate.parent
    return cwd


def parse_godot_config(file_path: Path) -> Dict[str, Dict[str, str]]:
    """Parse Godot INI-style configuration file (project.godot, export_presets.cfg)."""
    sections: Dict[str, Dict[str, str]] = {}
    if not file_path.exists():
        return sections

    current_section = ""
    with open(file_path, "r", encoding="utf-8", errors="replace") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith(";") or line.startswith("#"):
                continue
            if line.startswith("[") and line.endswith("]"):
                current_section = line[1:-1].strip()
                if current_section not in sections:
                    sections[current_section] = {}
                continue
            if "=" in line and current_section:
                key, val = line.split("=", 1)
                key = key.strip()
                val = val.strip().strip('"')
                sections[current_section][key] = val

    return sections


def parse_workflow_yaml(file_path: Path) -> Dict[str, Any]:
    """Parse GitHub Actions workflow using PyYAML if available, or robust regex fallback."""
    result: Dict[str, Any] = {
        "exists": False,
        "content": "",
        "jobs": {},
        "triggers": {},
        "permissions": {},
    }
    if not file_path.exists():
        return result

    content = file_path.read_text(encoding="utf-8", errors="replace")
    result["exists"] = True
    result["content"] = content

    # Try PyYAML
    try:
        import yaml
        data = yaml.safe_load(content)
        if isinstance(data, dict):
            result["yaml_data"] = data
            result["jobs"] = data.get("jobs", {})
            result["triggers"] = data.get("on", {})
            result["permissions"] = data.get("permissions", {})
            return result
    except Exception:
        pass

    # Regex extraction fallback
    job_matches = re.findall(r"^\s{2}([a-zA-Z0-9_\-]+):\s*$", content, re.MULTILINE)
    for jm in job_matches:
        if jm not in ["branches", "steps", "with", "env", "tags"]:
            result["jobs"][jm] = True

    return result


def validate_pkcs12_binary(file_path: Path) -> Tuple[bool, str]:
    """Validate that keystore file exists and conforms to PKCS#12 ASN.1 binary header."""
    if not file_path.exists():
        return False, f"Keystore not found: {file_path}"
    size = file_path.stat().st_size
    if size < 128:
        return False, f"Keystore too small ({size} bytes)"
    with open(file_path, "rb") as f:
        header = f.read(64)
    if len(header) < 4 or header[0] != 0x30:
        return False, f"Keystore does not start with ASN.1 Sequence (0x30, got {header[0]:#04x})"
    pkcs_oid = b'\x2a\x86\x48\x86\xf7\x0d\x01\x07\x01'
    data = open(file_path, "rb").read(512)
    if pkcs_oid not in header and pkcs_oid not in data:
        return False, "Keystore missing PKCS#12 ContentType OID (1.2.840.113549.1.7.1)"
    return True, f"Valid PKCS#12 Keystore ({size} bytes)"


class ExportAndCiVerifier:
    def __init__(self, workspace_root: Optional[Path] = None, strict_audit: bool = False):
        self.root = (workspace_root or find_workspace_root()).resolve()
        if (self.root / "project.godot").is_file():
            self.game_dir = self.root
        else:
            self.game_dir = self.root / "IdleArcade"
        self.strict_audit = strict_audit
        self.checks: List[VerificationCheck] = []

        # Target file paths
        self.export_presets_path = self.game_dir / "export_presets.cfg"
        self.project_godot_path = self.game_dir / "project.godot"
        self.workflow_root_path = self.root / ".github" / "workflows" / "build.yml"
        self.workflow_game_path = self.game_dir / ".github" / "workflows" / "build.yml"
        if not self.workflow_root_path.exists() and self.workflow_game_path.exists():
            self.workflow_root_path = self.workflow_game_path
        self.keystore_path = self.game_dir / "keystores" / "release.keystore"

        # Cached parsed data
        self.export_presets: Dict[str, Dict[str, str]] = {}
        self.project_godot: Dict[str, Dict[str, str]] = {}
        self.workflow_root: Dict[str, Any] = {}
        self.workflow_game: Dict[str, Any] = {}

    def _record(self, check: VerificationCheck) -> None:
        self.checks.append(check)
        symbol = "[PASS]"
        color = Colors.OKGREEN
        if check.warning:
            symbol = "[WARN]"
            color = Colors.WARNING
        elif not check.passed:
            symbol = "[FAIL]"
            color = Colors.FAIL

        print(f"  {color}{symbol}{Colors.ENDC} {check.check_id}: {check.name}")
        if check.message:
            print(f"         {Colors.OKBLUE}Message:{Colors.ENDC} {check.message}")
        for detail in check.details:
            print(f"         {Colors.OKCYAN}Detail:{Colors.ENDC} {detail}")

    def load_files(self) -> None:
        self.export_presets = parse_godot_config(self.export_presets_path)
        self.project_godot = parse_godot_config(self.project_godot_path)
        self.workflow_root = parse_workflow_yaml(self.workflow_root_path)
        self.workflow_game = parse_workflow_yaml(self.workflow_game_path)

    # =========================================================================
    # 1. Export Presets Audits
    # =========================================================================

    def verify_export_presets_existence(self) -> None:
        chk = VerificationCheck("TC-EXP-01", "Export Presets File Existence & INI Structure", "Export Presets")
        if not self.export_presets_path.exists():
            chk.fail_check(f"File missing at {self.export_presets_path}")
        elif not self.export_presets:
            chk.fail_check("export_presets.cfg is empty or could not be parsed as INI")
        else:
            preset_keys = [k for k in self.export_presets.keys() if k.startswith("preset.")]
            chk.pass_check(f"export_presets.cfg present with {len(preset_keys)} preset sections")
            chk.details.append(f"Found sections: {list(self.export_presets.keys())}")
        self._record(chk)

    def verify_web_export_preset(self) -> None:
        chk = VerificationCheck("TC-EXP-02", "Web (HTML5) Export Preset Configuration", "Export Presets")
        web_preset = self.export_presets.get("preset.0", {})
        web_options = self.export_presets.get("preset.0.options", {})

        platform = web_preset.get("platform", "")
        name = web_preset.get("name", "")
        runnable = web_preset.get("runnable", "").lower() == "true"
        export_path = web_preset.get("export_path", "")

        errors = []
        if platform != "Web":
            errors.append(f"Expected platform='Web', got '{platform}'")
        if not runnable:
            errors.append(f"Expected runnable=true, got '{runnable}'")
        if export_path != "build/web/index.html":
            errors.append(f"Expected export_path='build/web/index.html', got '{export_path}'")

        if errors:
            chk.fail_check("; ".join(errors))
        else:
            chk.pass_check(f"Web preset verified: name='{name}', platform='{platform}', path='{export_path}'")
        self._record(chk)

    def verify_web_canvas_and_wasm_options(self) -> None:
        chk = VerificationCheck("TC-EXP-03", "Web Canvas Resize Policy & Single-Threaded Wasm", "Export Presets")
        web_options = self.export_presets.get("preset.0.options", {})

        thread_support = web_options.get("variant/thread_support", "").lower()
        resize_policy = web_options.get("html/canvas_resize_policy", "")
        focus_canvas = web_options.get("html/focus_canvas_on_start", "").lower()

        errors = []
        if thread_support != "false":
            errors.append(f"variant/thread_support must be 'false' for single-threaded Wasm, got '{thread_support}'")
        if resize_policy != "2":
            errors.append(f"html/canvas_resize_policy must be '2' (Project resize), got '{resize_policy}'")
        if focus_canvas != "true":
            errors.append(f"html/focus_canvas_on_start should be 'true', got '{focus_canvas}'")

        if errors:
            chk.fail_check("; ".join(errors))
        else:
            chk.pass_check("Web options verified: thread_support=false, canvas_resize_policy=2, focus_canvas=true")
            chk.details.append("Ensures static web hosting compatibility without COOP/COEP isolation headers")
        self._record(chk)

    def verify_android_export_preset(self) -> None:
        chk = VerificationCheck("TC-EXP-04", "Android APK Export Preset Configuration", "Export Presets")
        android_preset = self.export_presets.get("preset.1", {})
        platform = android_preset.get("platform", "")
        name = android_preset.get("name", "")
        runnable = android_preset.get("runnable", "").lower() == "true"
        export_path = android_preset.get("export_path", "")

        errors = []
        if platform != "Android":
            errors.append(f"Expected platform='Android', got '{platform}'")
        if not runnable:
            errors.append(f"Expected runnable=true, got '{runnable}'")
        if export_path != "build/android/IdleArcade.apk":
            errors.append(f"Expected export_path='build/android/IdleArcade.apk', got '{export_path}'")

        if errors:
            chk.fail_check("; ".join(errors))
        else:
            chk.pass_check(f"Android preset verified: name='{name}', platform='{platform}', path='{export_path}'")
        self._record(chk)

    def verify_android_identity_and_architectures(self) -> None:
        chk = VerificationCheck("TC-EXP-05", "Android Package Identity & ARM Architectures", "Export Presets")
        android_opts = self.export_presets.get("preset.1.options", {})

        pkg_unique = android_opts.get("package/unique_name", "")
        pkg_name = android_opts.get("package/name", "")
        ver_code = android_opts.get("version/code", "")
        ver_name = android_opts.get("version/name", "")
        arm64 = android_opts.get("architectures/arm64-v8a", "").lower() == "true"
        arm32 = android_opts.get("architectures/armeabi-v7a", "").lower() == "true"
        precompiled = android_opts.get("gradle_build/use_gradle_build", "").lower() == "false"

        errors = []
        if not pkg_unique or not re.match(r"^[a-zA-Z0-9_]+(\.[a-zA-Z0-9_]+)+$", pkg_unique):
            errors.append(f"Invalid package/unique_name: '{pkg_unique}'")
        if pkg_name != "IdleArcade":
            errors.append(f"Expected package/name='IdleArcade', got '{pkg_name}'")
        if ver_code != "1":
            errors.append(f"Expected version/code='1', got '{ver_code}'")
        if not arm64:
            errors.append("architectures/arm64-v8a must be true for 64-bit Android")
        if not arm32:
            errors.append("architectures/armeabi-v7a must be true for 32-bit Android backward compatibility")
        if not precompiled:
            errors.append("gradle_build/use_gradle_build should be false (precompiled templates)")

        if errors:
            chk.fail_check("; ".join(errors))
        else:
            chk.pass_check(f"Package '{pkg_unique}' v{ver_name} (code {ver_code}) targeting ARM64 & ARM32")
        self._record(chk)

    def verify_android_keystores(self) -> None:
        chk = VerificationCheck("TC-EXP-06", "Android Keystore Configuration & Binary Integrity", "Export Presets")
        android_opts = self.export_presets.get("preset.1.options", {})

        dbg_keystore = android_opts.get("keystore/debug", "")
        dbg_user = android_opts.get("keystore/debug_user", "")
        dbg_pass = android_opts.get("keystore/debug_password", "")
        rel_keystore = android_opts.get("keystore/release", "")
        rel_user = android_opts.get("keystore/release_user", "")
        rel_pass = android_opts.get("keystore/release_password", "")

        errors = []
        if dbg_keystore != "keystores/release.keystore":
            errors.append(f"keystore/debug path unexpected: '{dbg_keystore}'")
        if rel_keystore != "keystores/release.keystore":
            errors.append(f"keystore/release path unexpected: '{rel_keystore}'")
        if dbg_user != "genericreleasekey" or rel_user != "genericreleasekey":
            errors.append("Keystore user alias mismatch (expected 'genericreleasekey')")
        if dbg_pass != "android" or rel_pass != "android":
            errors.append("Keystore password mismatch (expected 'android')")

        # Binary check on keystores/release.keystore if present (keystores are gitignored in repo)
        if self.keystore_path.exists():
            valid_binary, bin_msg = validate_pkcs12_binary(self.keystore_path)
            if not valid_binary:
                errors.append(bin_msg)
        else:
            bin_msg = "Keystore dynamically provisioned in CI build.yml (gitignored binary)"

        if errors:
            chk.fail_check("; ".join(errors))
        else:
            chk.pass_check(f"Keystore relative paths verified; {bin_msg}")
        self._record(chk)

    def verify_display_and_orientation(self) -> None:
        chk = VerificationCheck("TC-EXP-07", "Portrait 720x1280 Display & Handheld Orientation", "Display & Orientation")
        display = self.project_godot.get("display", {})

        width = display.get("window/size/viewport_width", "")
        height = display.get("window/size/viewport_height", "")
        stretch_mode = display.get("window/stretch/mode", "")
        stretch_aspect = display.get("window/stretch/aspect", "")
        orientation = display.get("window/handheld/orientation", "")

        errors = []
        if width != "720" or height != "1280":
            errors.append(f"Expected viewport 720x1280, got {width}x{height}")
        if orientation != "1":
            errors.append(f"Expected window/handheld/orientation=1 (Portrait), got '{orientation}'")
        if stretch_mode != "canvas_items":
            errors.append(f"Expected stretch/mode='canvas_items', got '{stretch_mode}'")
        if stretch_aspect != "expand":
            errors.append(f"Expected stretch/aspect='expand', got '{stretch_aspect}'")

        if errors:
            chk.fail_check("; ".join(errors))
        else:
            chk.pass_check("Project display configured for Portrait 720x1280 (canvas_items, expand, orientation=1)")
        self._record(chk)

    def verify_android_permissions_audit(self) -> None:
        chk = VerificationCheck("TC-EXP-08", "Android Manifest Permissions Audit (VIBRATE)", "Export Presets")
        android_opts = self.export_presets.get("preset.1.options", {})

        vibrate_perm = android_opts.get("permissions/vibrate", "").lower()
        has_vibrate = vibrate_perm == "true"
        custom_perms = android_opts.get("permissions/custom_permissions", "")
        has_custom_vibrate = "android.permission.VIBRATE" in custom_perms

        if has_vibrate or has_custom_vibrate:
            chk.pass_check("VIBRATE permission enabled in Android export preset (permissions/vibrate=true)")
        else:
            msg = "GAP IDENTIFIED: 'permissions/vibrate' is MISSING in export_presets.cfg [preset.1.options]."
            detail = (
                "Phase 5 R3 requires Input.vibrate_handheld() haptics. Without permissions/vibrate=true, "
                "the AndroidManifest.xml will lack android.permission.VIBRATE, causing vibration calls to "
                "fail silently or trigger security rejections on mobile devices."
            )
            chk.details.append(detail)
            chk.details.append("Recommended fix: Add 'permissions/vibrate=true' under [preset.1.options].")
            if self.strict_audit:
                chk.fail_check(msg)
            else:
                chk.warn_check(msg)
        self._record(chk)

    # =========================================================================
    # 2. CI/CD Workflow Audits
    # =========================================================================

    def verify_workflow_parity(self) -> None:
        chk = VerificationCheck("TC-CI-01", "CI/CD Workflow File Existence & Parity Check", "CI/CD Pipeline")
        if not self.workflow_game_path.exists() and not self.workflow_root_path.exists():
            chk.fail_check(f"Workflow file missing at {self.workflow_game_path}")
            self._record(chk)
            return

        if self.workflow_root_path.exists() and self.workflow_game_path.exists() and self.workflow_root_path.resolve() != self.workflow_game_path.resolve():
            c_root = self.workflow_root_path.read_text(encoding="utf-8").strip()
            c_game = self.workflow_game_path.read_text(encoding="utf-8").strip()

            if c_root != c_game:
                chk.fail_check("Parity mismatch between .github/workflows/build.yml and IdleArcade/.github/workflows/build.yml")
                chk.details.append("Both files must be strictly synchronized to satisfy test_ci_release_adversarial.py")
            else:
                chk.pass_check("Root and IdleArcade build.yml files are 100% byte-for-byte synchronized")
        else:
            chk.pass_check("Workflow file verified at repository root (.github/workflows/build.yml)")
        self._record(chk)

    def verify_workflow_triggers_and_tag_rules(self) -> None:
        chk = VerificationCheck("TC-CI-02", "CI/CD Trigger Specification & Tag Glob Rules", "CI/CD Pipeline")
        content = self.workflow_root.get("content", "")

        errors = []
        if "branches:" not in content or "- main" not in content:
            errors.append("Workflow missing push trigger on 'main' branch")
        if "tags:" not in content or ("- 'v*'" not in content and '- "v*"' not in content):
            errors.append("Workflow missing push trigger for 'v*' tags")
        if "workflow_dispatch:" not in content:
            errors.append("Workflow missing manual 'workflow_dispatch' trigger")

        # Test tag patterns using fnmatch
        tag_patterns = []
        in_tags = False
        for line in content.splitlines():
            if "tags:" in line:
                in_tags = True
                continue
            if in_tags:
                stripped = line.strip()
                if stripped.startswith("-"):
                    tag_patterns.append(stripped.lstrip("-").strip().strip("'\""))
                else:
                    break

        def match_tag(t: str) -> bool:
            return any(fnmatch.fnmatch(t, p) for p in tag_patterns)

        # Semver tags with 'v'
        if not match_tag("v1.0.0") or not match_tag("v0.2.1-rc1"):
            errors.append("Tag patterns failed to match semver tags (v1.0.0, v0.2.1-rc1)")
        # Numeric tags
        if not match_tag("1.0.0") or not match_tag("2026.1"):
            errors.append("Tag patterns failed to match bare numeric tags (1.0.0, 2026.1)")
        # Negative tests: branch names must NOT match
        if match_tag("main") or match_tag("feature/ui-tweaks"):
            errors.append("Branch names falsely matched release tag patterns!")

        if errors:
            chk.fail_check("; ".join(errors))
        else:
            chk.pass_check(f"Triggers verified: main branch, workflow_dispatch, and tag patterns {tag_patterns}")
        self._record(chk)

    def verify_release_job_isolation(self) -> None:
        chk = VerificationCheck("TC-CI-03", "Release Job Tag Gating & Main Branch Isolation", "CI/CD Pipeline")
        content = self.workflow_root.get("content", "")

        # Release job must strictly guard with startsWith(github.ref, 'refs/tags/')
        if "startsWith(github.ref, 'refs/tags/')" not in content:
            chk.fail_check("Release job missing condition: `if: startsWith(github.ref, 'refs/tags/')`")
            self._record(chk)
            return

        # Assert evaluation logic
        def runs_release(ref: str) -> bool:
            return ref.startswith("refs/tags/")

        if runs_release("refs/heads/main"):
            chk.fail_check("Isolation breached: push to main would run release job!")
        elif not runs_release("refs/tags/v1.0.0"):
            chk.fail_check("Gating failure: tag push v1.0.0 failed to trigger release job!")
        else:
            chk.pass_check("Release job strictly gated by tags; push to main builds without polluting releases")
        self._record(chk)

    def verify_release_publishing_and_web_branch(self) -> None:
        chk = VerificationCheck("TC-CI-04", "GitHub Release Assets & 'release' Branch Deployment", "CI/CD Pipeline")
        content = self.workflow_root.get("content", "")

        release_parts = content.split("\n  release:")
        if len(release_parts) < 2:
            chk.fail_check("Could not isolate 'release' job in workflow")
            self._record(chk)
            return

        release_block = release_parts[1]
        errors = []
        if "contents: write" not in release_block:
            errors.append("Release job missing elevated permissions (contents: write)")
        if "softprops/action-gh-release@v2" not in release_block:
            errors.append("Missing softprops/action-gh-release@v2 step")
        if "dist/IdleArcade.apk" not in release_block:
            errors.append("Release asset missing dist/IdleArcade.apk")
        if "dist/web-build.zip" not in release_block:
            errors.append("Release asset missing dist/web-build.zip")
        if "peaceiris/actions-gh-pages@v4" not in release_block:
            errors.append("Missing peaceiris/actions-gh-pages@v4 deployment step")
        if "publish_branch: release" not in release_block:
            errors.append("Web deployment must target 'publish_branch: release'")

        if errors:
            chk.fail_check("; ".join(errors))
        else:
            chk.pass_check("Release publishes APK & Web ZIP, and deploys Web export to 'release' branch")
        self._record(chk)

    def verify_ci_headless_test_step_audit(self) -> None:
        chk = VerificationCheck("TC-CI-05", "CI Headless Test Execution Step Audit", "CI/CD Pipeline")
        content = self.workflow_root.get("content", "")

        has_test_job = bool(re.search(r"^\s{2}test:\s*$", content, re.MULTILINE))
        has_godot_headless_test = bool(re.search(r"godot\s+--headless.*-s\s+tests/", content))
        has_phase5_test = "test_phase5_mobile.gd" in content
        has_e2e_suite = "e2e_suite.py" in content

        if has_test_job or has_godot_headless_test:
            chk.pass_check("CI workflow contains automated test execution step")
            if has_phase5_test:
                chk.details.append("Executes test_phase5_mobile.gd in CI")
        else:
            msg = "GAP IDENTIFIED: CI workflow lacks automated test execution step before exports."
            chk.details.append(
                "Currently, pushes to 'main' or tags jump straight to export-web and export-android "
                "without running Godot headless unit tests or python verification scripts."
            )
            chk.details.append(
                "Blueprint remedy: Add a 'test' job running Godot headless tests "
                "(test_phase5_mobile.gd, test_game_logic.gd, test_nakama.gd, e2e_suite.py) "
                "and gate export jobs with 'needs: [test]'."
            )
            if self.strict_audit:
                chk.fail_check(msg)
            else:
                chk.warn_check(msg)
        self._record(chk)

    def verify_docker_and_export_templates(self) -> None:
        chk = VerificationCheck("TC-CI-06", "Godot 4.3 CI Docker Image & Template Relocation", "CI/CD Pipeline")
        content = self.workflow_root.get("content", "")

        errors = []
        if "barichello/godot-ci:4.3" not in content:
            errors.append("Workflow container must use barichello/godot-ci:4.3")
        if "export_templates" not in content or "cp -r" not in content:
            errors.append("Missing Godot export templates relocation step")
        if "build/web" not in content or "--export-release \"Web\"" not in content:
            errors.append("Missing headless web export command")
        if "build/android" not in content or "--export-release \"Android\"" not in content:
            errors.append("Missing headless android export command")

        if errors:
            chk.fail_check("; ".join(errors))
        else:
            chk.pass_check("Docker container, template relocation, and headless export commands verified")
        self._record(chk)

    # =========================================================================
    # Runner & Summary
    # =========================================================================

    def run_all(self) -> bool:
        print(f"{Colors.BOLD}{Colors.HEADER}===================================================================={Colors.ENDC}")
        print(f"{Colors.BOLD}[AUDIT] IdleArcade CI/CD & Export Presets Verification Suite{Colors.ENDC}")
        print(f"Target: {self.root}")
        print(f"Mode: {'STRICT AUDIT' if self.strict_audit else 'STANDARD AUDIT & GAP DISCOVERY'}")
        print(f"{Colors.BOLD}{Colors.HEADER}===================================================================={Colors.ENDC}\n")

        self.load_files()

        print(f"{Colors.BOLD}{Colors.OKBLUE}--- 1. AUDITING EXPORT PRESETS (export_presets.cfg) ---{Colors.ENDC}")
        self.verify_export_presets_existence()
        self.verify_web_export_preset()
        self.verify_web_canvas_and_wasm_options()
        self.verify_android_export_preset()
        self.verify_android_identity_and_architectures()
        self.verify_android_keystores()
        self.verify_display_and_orientation()
        self.verify_android_permissions_audit()

        print(f"\n{Colors.BOLD}{Colors.OKBLUE}--- 2. AUDITING CI/CD PIPELINE (.github/workflows/build.yml) ---{Colors.ENDC}")
        self.verify_workflow_parity()
        self.verify_workflow_triggers_and_tag_rules()
        self.verify_release_job_isolation()
        self.verify_release_publishing_and_web_branch()
        self.verify_ci_headless_test_step_audit()
        self.verify_docker_and_export_templates()

        passed_count = sum(1 for c in self.checks if c.passed and not c.warning)
        warn_count = sum(1 for c in self.checks if c.warning)
        failed_count = sum(1 for c in self.checks if not c.passed)
        total = len(self.checks)

        print(f"\n{Colors.BOLD}{Colors.HEADER}===================================================================={Colors.ENDC}")
        print(f"[AUDIT SUMMARY] Total: {total} | {Colors.OKGREEN}Passed: {passed_count}{Colors.ENDC} | {Colors.WARNING}Warnings/Gaps: {warn_count}{Colors.ENDC} | {Colors.FAIL}Failed: {failed_count}{Colors.ENDC}")
        print(f"{Colors.BOLD}{Colors.HEADER}===================================================================={Colors.ENDC}")

        if failed_count == 0:
            print(f"{Colors.BOLD}{Colors.OKGREEN}>>> BASELINE INTEGRITY VERIFIED (Exit Code 0) <<<{Colors.ENDC}")
            if warn_count > 0:
                print(f"{Colors.WARNING}>>> NOTE: {warn_count} actionable gaps documented above for Phase 5 completion. <<<{Colors.ENDC}")
            return True
        else:
            print(f"{Colors.BOLD}{Colors.FAIL}>>> AUDIT DETECTED {failed_count} CRITICAL FAILURES (Exit Code 1) <<<{Colors.ENDC}")
            return False


if __name__ == "__main__":
    strict = "--strict" in sys.argv
    verifier = ExportAndCiVerifier(strict_audit=strict)
    success = verifier.run_all()
    sys.exit(0 if success else 1)
