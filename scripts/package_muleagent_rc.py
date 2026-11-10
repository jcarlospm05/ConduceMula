#!/usr/bin/env python3
"""Package verified Android APKs with hashes, signer and field checklist.

Release-mode archives are signed with user-owned secrets but still require
physical-device acceptance before production distribution.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
from zipfile import ZIP_DEFLATED, ZipFile

ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / "apps" / "muleagent"
DOC = ROOT / "docs" / "unificacion" / "ETAPA-6.md"
OUTPUT = APP / "build" / "release-candidate"
BADGING = OUTPUT / "apk-badging.txt"
CERT = OUTPUT / "apk-certificate.txt"
PACKAGE_ID = "com.muleagent.operador"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(message)


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as stream:
        for part in iter(lambda: stream.read(1024 * 1024), b""):
            h.update(part)
    return h.hexdigest()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--release", action="store_true")
    args = parser.parse_args()
    apk = (APP / "build" / "app" / "outputs" / "flutter-apk" /
           ("app-release.apk" if args.release else "app-debug.apk"))
    require(apk.is_file() and apk.stat().st_size > 50000,
            "No valid APK candidate found.")
    require(DOC.is_file(), "Stage-6 field checklist is missing.")
    require(BADGING.is_file() and CERT.is_file(),
            "Android manifest and signing diagnostics are missing.")

    pubspec = (APP / "pubspec.yaml").read_text(encoding="utf-8")
    match = re.search(r"^version:\s*(\d+\.\d+\.\d+)\+(\d+)\s*$",
                      pubspec, re.MULTILINE)
    require(match is not None, "Version in pubspec.yaml is invalid.")
    version, code = match.groups()
    badging = BADGING.read_text(encoding="utf-8")
    require(f"name='{PACKAGE_ID}'" in badging, "Android application ID changed.")
    require(f"versionCode='{code}'" in badging,
            "Version code does not match Flutter pubspec.")
    require(f"versionName='{version}'" in badging,
            "Version name does not match Flutter pubspec.")

    cert_info = CERT.read_text(encoding="utf-8")
    require("Signer #1 certificate SHA-256 digest:" in cert_info,
            "Missing verified signer fingerprint.")
    if args.release:
        require("application-debuggable" not in badging,
                "Release APK must not be debuggable.")
        require(os.getenv("SIGNING_SOURCE") == "github-encrypted-release-secrets",
                "Release signer must come from protected secrets.")
    with ZipFile(apk, "r") as compiled:
        require(compiled.testzip() is None, "The compiled APK is corrupt.")
        filenames = set(compiled.namelist())
        require("AndroidManifest.xml" in filenames,
                "Compiled APK lacks AndroidManifest.xml.")
        require("classes.dex" in filenames,
                "Compiled APK lacks Dart/Android entry point.")

    suffix = "signed" if args.release else "rc6"
    apk_name = f"MuleAgent-ConduceMula-{version}-b{code}-{suffix}.apk"
    zip_name = f"MuleAgent-ConduceMula-{version}-b{code}-{suffix}.zip"
    package_sha = sha256(apk)
    metadata = {
        "repository": "jcarlospm05/ConduceMula",
        "source_commit": os.getenv("GITHUB_SHA", "local"),
        "app_id": PACKAGE_ID,
        "version": version,
        "version_code": int(code),
        "build_type": "release" if args.release else "debug",
        "release_status": ("SIGNED_RELEASE_PENDING_PHYSICAL_ACCEPTANCE"
                           if args.release else "FIELD_TEST_ONLY_NOT_PRODUCTION"),
        "signing_source": os.getenv("SIGNING_SOURCE", "unknown"),
        "apk_name": apk_name,
        "apk_sha256": package_sha,
        "signer_sha256": re.search(
            r"Signer #1 certificate SHA-256 digest:\s*([a-fA-F0-9]{64})",
            cert_info,
        ).group(1),
        "upgrade_compatibility": "UNVERIFIED_COMPARE_INSTALLED_CERTIFICATE",
        "physical_android_testing": "PENDING",
    }
    OUTPUT.mkdir(parents=True, exist_ok=True)
    archive = OUTPUT / zip_name
    with ZipFile(archive, "w", ZIP_DEFLATED, compresslevel=6) as out:
        out.write(apk, apk_name)
        out.writestr("SHA256SUMS.txt", f"{package_sha}  {apk_name}\n")
        out.writestr("BUILD_INFO.json",
                     json.dumps(metadata, indent=2, ensure_ascii=False) + "\n")
        out.writestr("CERTIFICADO.txt", cert_info)
        out.writestr("MANIFIESTO_ANDROID.txt", badging)
        out.write(DOC, "GUIA_PRUEBAS_ETAPA6.md")

    with ZipFile(archive, "r") as zip_file:
        require(zip_file.testzip() is None, "The release-candidate ZIP is damaged.")
        require(apk_name in zip_file.namelist(),
                "ZIP is missing the installable APK.")
    print(f"Stage-6 field test ZIP: {archive}")
    print(f"APK SHA-256: {package_sha}")
    print("Release status: signed release pending physical acceptance"
          if args.release else
          "Release status: debug candidate; do not publish as production")


if __name__ == "__main__":
    main()
