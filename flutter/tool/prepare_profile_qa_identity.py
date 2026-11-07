#!/usr/bin/env python3
"""Give PR-only Profile builds an isolated Android identity for side-by-side QA."""
from __future__ import annotations

import re
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ANDROID = ROOT / "android"
APP_ID = "com.duckdream.projectarena"
QA_APP_ID = f"{APP_ID}.qa"
QA_LABEL = "Projeto Arena QA"
ANDROID_NS = "{http://schemas.android.com/apk/res/android}"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"Profile QA identity preparation failed: {message}")


def main() -> None:
    gradle_candidates = (
        ANDROID / "app/build.gradle.kts",
        ANDROID / "app/build.gradle",
    )
    gradle = next((path for path in gradle_candidates if path.is_file()), None)
    require(gradle is not None, "generated app Gradle file not found.")

    source = gradle.read_text(encoding="utf-8")
    if gradle.suffix == ".kts":
        pattern = r'(applicationId\\s*=\\s*["\\\'])' + re.escape(APP_ID) + r'(["\\\'])'
    else:
        pattern = r'(applicationId\\s+["\\\'])' + re.escape(APP_ID) + r'(["\\\'])'
    updated, count = re.subn(pattern, lambda match: match.group(1) + QA_APP_ID + match.group(2), source)
    require(count == 1, f"expected one generated applicationId {APP_ID!r}, found {count}.")
    gradle.write_text(updated, encoding="utf-8")

    manifest = ANDROID / "app/src/main/AndroidManifest.xml"
    require(manifest.is_file(), "generated AndroidManifest.xml not found.")
    ET.register_namespace("android", "http://schemas.android.com/apk/res/android")
    tree = ET.parse(manifest)
    application = tree.getroot().find("application")
    require(application is not None, "manifest application element missing.")
    application.set(ANDROID_NS + "label", QA_LABEL)
    tree.write(manifest, encoding="utf-8", xml_declaration=True)

    print(f"PR-only Profile identity isolated: applicationId={QA_APP_ID}, label={QA_LABEL}")


if __name__ == "__main__":
    main()
