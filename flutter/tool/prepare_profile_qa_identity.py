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
        pattern = r"(applicationId\s*=\s*['\"])" + re.escape(APP_ID) + r"(['\"])"
    else:
        pattern = r"(applicationId\s+['\"])" + re.escape(APP_ID) + r"(['\"])"
    updated, count = re.subn(pattern, lambda match: match.group(1) + QA_APP_ID + match.group(2), source)
    require(count == 1, f"expected one generated applicationId {APP_ID!r}, found {count}.")
    default_config_matches = list(re.finditer(r"(?m)^([ \t]*)defaultConfig\s*\{", updated))
    require(
        len(default_config_matches) == 1,
        f"expected one generated defaultConfig block, found {len(default_config_matches)}.",
    )
    default_config = default_config_matches[0]
    block_indent = default_config.group(1) + "    "
    if gradle.suffix == ".kts":
        abi_filter = (
            f"\n{block_indent}ndk {{\n"
            f'{block_indent}    abiFilters += setOf("arm64-v8a")\n'
            f"{block_indent}}}\n"
        )
    else:
        abi_filter = (
            f"\n{block_indent}ndk {{\n"
            f'{block_indent}    abiFilters "arm64-v8a"\n'
            f"{block_indent}}}\n"
        )
    updated = updated[:default_config.end()] + abi_filter + updated[default_config.end():]
    require(
        'abiFilters += setOf("arm64-v8a")' in updated
        if gradle.suffix == ".kts"
        else 'abiFilters "arm64-v8a"' in updated,
        "generated Gradle file is missing the ARM64-only ABI filter.",
    )
    gradle.write_text(updated, encoding="utf-8")

    manifest = ANDROID / "app/src/main/AndroidManifest.xml"
    require(manifest.is_file(), "generated AndroidManifest.xml not found.")
    ET.register_namespace("android", "http://schemas.android.com/apk/res/android")
    tree = ET.parse(manifest)
    application = tree.getroot().find("application")
    require(application is not None, "manifest application element missing.")
    application.set(ANDROID_NS + "label", QA_LABEL)
    tree.write(manifest, encoding="utf-8", xml_declaration=True)

    print(f"PR-only Profile QA isolated: applicationId={QA_APP_ID}, label={QA_LABEL}, ABI=arm64-v8a")


if __name__ == "__main__":
    main()
