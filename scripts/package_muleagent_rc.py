#!/usr/bin/env python3
"""Package a verified, clearly labelled Android field-test build.

No private keys, environment secrets or account identifiers are packaged.
The resulting ZIP is a release *candidate*, not a production release.
"""

from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path
import re
from zipfile import ZIP_DEFLATED, ZipFile

ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / "apps" / "muleagent"
APK = APP / "build" / "app" / "outputs" / "flutter-apk" / "app-debug.apk"
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
    require(APK.is_file() and APK.stat().st_size > 50000,
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
    with ZipFile(APK, "r") as compiled:
        require(compiled.testzip() is None, "The compiled APK is corrupt.")
        filenames = set(compiled.namelist())
        require("AndroidManifest.xml" in filenames,
                "Compiled APK lacks AndroidManifest.xml.")
        require("classes.dex" in filenames,
                "Compiled APK lacks Dart/Android entry point.")

    apk_name = f"MuleAgent-ConduceMula-{version}-b{code}-rc6.apk"
    zip_name = f"MuleAgent-ConduceMula-{version}-b{code}-rc6.zip"
    package_sha = sha256(APK)
    metadata = {
        "repository": "jcarlospm05/ConduceMula",
        "source_commit": os.getenv("GITHUB_SHA", "local"),
        "app_id": PACKAGE_ID,
        "version": version,
        "version_code": int(code),
        "build_type": "debug",
        "release_status": "FIELD_TEST_ONLY_NOT_PRODUCTION",
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
        out.write(APK, apk_name)
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
    print("Release status: debug candidate; do not publish as production")


if __name__ == "__main__":
    main()
