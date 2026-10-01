#!/usr/bin/env python3
"""
Generic Release Keystore Generator for IdleArcade
Generates an authentic PKCS#12 release keystore for Godot 4 Android exports.
Alias: genericreleasekey
Password: android
Validity: 10000 days
Algorithm: RSA 2048
"""

import sys
import os
import shutil
import subprocess
from pathlib import Path
from typing import Tuple, Optional


def find_keytool() -> Optional[str]:
    """Search common JDK installations, JAVA_HOME, and PATH for keytool executable."""
    candidates = [
        Path(r"C:\Program Files\Java\jdk-26.0.2\bin\keytool.exe"),
        Path(r"C:\Program Files\Java\latest\bin\keytool.exe"),
    ]
    # Check JAVA_HOME
    java_home = os.environ.get("JAVA_HOME")
    if java_home:
        candidates.append(Path(java_home) / "bin" / "keytool.exe")
        candidates.append(Path(java_home) / "bin" / "keytool")

    # Check JDK directories in Program Files
    java_dir = Path(r"C:\Program Files\Java")
    if java_dir.exists():
        for p in java_dir.glob("jdk*/bin/keytool.exe"):
            candidates.append(p)

    for cand in candidates:
        if cand.exists():
            return str(cand)

    # Check system PATH
    path_keytool = shutil.which("keytool")
    if path_keytool:
        return path_keytool

    return None


def generate_with_keytool(keystore_path: Path, keytool_bin: str) -> Tuple[bool, str]:
    """Generate PKCS#12 keystore using Java JDK keytool."""
    if keystore_path.exists():
        keystore_path.unlink()

    cmd = [
        keytool_bin,
        "-genkeypair",
        "-v",
        "-keystore", str(keystore_path),
        "-alias", "genericreleasekey",
        "-keyalg", "RSA",
        "-keysize", "2048",
        "-validity", "10000",
        "-storetype", "PKCS12",
        "-storepass", "android",
        "-keypass", "android",
        "-dname", "CN=IdleArcade, OU=Development, O=GameStudio, L=City, ST=State, C=US"
    ]
    try:
        res = subprocess.run(cmd, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        return True, f"Keytool generated successfully: {res.stdout.strip()}"
    except Exception as e:
        return False, f"Keytool execution failed: {e}"


def generate_with_cryptography(keystore_path: Path) -> Tuple[bool, str]:
    """Generate PKCS#12 keystore using Python cryptography package if available."""
    try:
        from cryptography import x509
        from cryptography.x509.oid import NameOID
        from cryptography.hazmat.primitives import hashes
        from cryptography.hazmat.primitives.asymmetric import rsa
        from cryptography.hazmat.primitives.serialization import pkcs12, BestAvailableEncryption
        import datetime

        private_key = rsa.generate_private_key(
            public_exponent=65537,
            key_size=2048,
        )

        subject = issuer = x509.Name([
            x509.NameAttribute(NameOID.COMMON_NAME, "IdleArcade"),
            x509.NameAttribute(NameOID.ORGANIZATIONAL_UNIT_NAME, "Development"),
            x509.NameAttribute(NameOID.ORGANIZATION_NAME, "GameStudio"),
            x509.NameAttribute(NameOID.LOCALITY_NAME, "City"),
            x509.NameAttribute(NameOID.STATE_OR_PROVINCE_NAME, "State"),
            x509.NameAttribute(NameOID.COUNTRY_NAME, "US"),
        ])

        now = datetime.datetime.now(datetime.timezone.utc)
        cert = (
            x509.CertificateBuilder()
            .subject_name(subject)
            .issuer_name(issuer)
            .public_key(private_key.public_key())
            .serial_number(x509.random_serial_number())
            .not_valid_before(now)
            .not_valid_after(now + datetime.timedelta(days=10000))
            .sign(private_key, hashes.SHA256())
        )

        p12_bytes = pkcs12.serialize_key_and_certificates(
            name=b"genericreleasekey",
            key=private_key,
            cert=cert,
            cas=None,
            encryption_algorithm=BestAvailableEncryption(b"android")
        )

        if keystore_path.exists():
            keystore_path.unlink()

        with open(keystore_path, "wb") as f:
            f.write(p12_bytes)

        return True, "Generated successfully via Python cryptography"
    except ImportError:
        return False, "Python cryptography library is not installed"
    except Exception as e:
        return False, f"Cryptography generation error: {e}"


def check_keystore(file_path: Path) -> Tuple[bool, str]:
    """Verify PKCS#12 binary format adheres to e2e_suite check_pkcs12_keystore standard."""
    if not file_path.exists():
        return False, f"File does not exist: {file_path}"
    size = file_path.stat().st_size
    if size < 128:
        return False, f"File size too small: {size} bytes (expected >= 128)"
    with open(file_path, "rb") as f:
        data = f.read(512)
    if len(data) < 4 or data[0] != 0x30:
        return False, f"File does not start with ASN.1 Sequence byte 0x30 (got {data[0]:#04x})"
    pkcs_oid = b'\x2a\x86\x48\x86\xf7\x0d\x01\x07\x01'
    if pkcs_oid not in data:
        return False, "File does not contain PKCS#7 / PKCS#12 ContentType OID 1.2.840.113549.1.7.1"
    return True, f"Valid PKCS#12 keystore ({size} bytes)"


def ensure_keystore(target_path: Optional[Path] = None, force: bool = False) -> Tuple[bool, str]:
    """
    Ensure the release keystore binary exists and is valid.
    Generates it if missing or invalid.
    """
    if target_path is None:
        target_path = Path(__file__).resolve().parent / "release.keystore"

    target_path = Path(target_path).resolve()
    target_path.parent.mkdir(parents=True, exist_ok=True)

    if target_path.exists() and not force:
        valid, msg = check_keystore(target_path)
        if valid:
            return True, f"Keystore already valid at {target_path}: {msg}"

    # Tier 1: Try Keytool
    keytool_bin = find_keytool()
    if keytool_bin:
        success, msg = generate_with_keytool(target_path, keytool_bin)
        if success:
            valid, vmsg = check_keystore(target_path)
            if valid:
                return True, f"Generated via keytool ({keytool_bin}): {vmsg}"

    # Tier 2: Try Python Cryptography
    success, msg = generate_with_cryptography(target_path)
    if success:
        valid, vmsg = check_keystore(target_path)
        if valid:
            return True, f"Generated via cryptography: {vmsg}"

    return False, f"Failed to generate valid keystore at {target_path}. Keytool and cryptography unavailable."


def main():
    keystores_dir = Path(__file__).resolve().parent
    keystore_path = keystores_dir / "release.keystore"
    
    print(f"Ensuring release keystore at: {keystore_path}")
    success, msg = ensure_keystore(keystore_path, force=True)
    if success:
        print(f"[SUCCESS] {msg}")
        return 0
    else:
        print(f"[ERROR] {msg}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
