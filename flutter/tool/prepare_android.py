#!/usr/bin/env python3
"""Generate the Flutter Scene Android host with the project's real app identity."""
from pathlib import Path
import os
import re
import shutil
import subprocess
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
REPO_ROOT = ROOT.parent
ANDROID = ROOT / "android"
APP_ID = "com.duckdream.projectarena"
APP_LABEL = "Projeto Arena"
MIN_SDK = 24
TARGET_SDK = 36


def add_arm64_abi_filter(content: str, gradle_path: Path) -> str:
    """Package only the 64-bit ARM runtime used by supported Android devices."""
    default_configs = list(
        re.finditer(r"(?m)^([ \t]*)defaultConfig\s*\{", content)
    )
    if len(default_configs) != 1:
        raise SystemExit(
            "Expected exactly one generated Android defaultConfig block."
        )

    if "abiFilters.clear()" in content:
        expected = (
            'abiFilters.addAll(listOf("arm64-v8a"))'
            if gradle_path.suffix == ".kts"
            else 'abiFilters "arm64-v8a"'
        )
        if expected not in content:
            raise SystemExit("Existing ABI filter does not match ARM64-only policy.")
        return content

    default_config = default_configs[0]
    indent = default_config.group(1) + "    "
    if gradle_path.suffix == ".kts":
        block = (
            f"\n{indent}ndk {{\n"
            f"{indent}    abiFilters.clear()\n"
            f'{indent}    abiFilters.addAll(listOf("arm64-v8a"))\n'
            f"{indent}}}\n"
        )
    else:
        block = (
            f"\n{indent}ndk {{\n"
            f"{indent}    abiFilters.clear()\n"
            f'{indent}    abiFilters "arm64-v8a"\n'
            f"{indent}}}\n"
        )
    updated = content[:default_config.end()] + block + content[default_config.end():]
    if "abiFilters.clear()" not in updated:
        raise SystemExit("Could not apply ARM64-only Gradle ABI filter.")
    return updated


def add_persistent_signing(content: str, gradle_path: Path) -> str:
    """Use the same keystore as the legacy APK when CI provides it."""
    keys = (
        "NEON_BREACH_KEYSTORE_PATH",
        "NEON_BREACH_KEYSTORE_PASSWORD",
        "NEON_BREACH_KEY_ALIAS",
        "NEON_BREACH_KEY_PASSWORD",
    )
    configured = [bool(os.environ.get(key)) for key in keys]
    if not any(configured):
        print("Persistent keystore not supplied; keeping Flutter's local debug signing.")
        return content
    if not all(configured):
        missing = [key for key, present in zip(keys, configured) if not present]
        raise SystemExit(f"Incomplete persistent signing environment: {', '.join(missing)}")

    is_kts = gradle_path.suffix == ".kts"
    if is_kts:
        signing_block = """    signingConfigs {
        create("stableDebug") {
            storeFile = file(System.getenv("NEON_BREACH_KEYSTORE_PATH")!!)
            storePassword = System.getenv("NEON_BREACH_KEYSTORE_PASSWORD")!!
            keyAlias = System.getenv("NEON_BREACH_KEY_ALIAS")!!
            keyPassword = System.getenv("NEON_BREACH_KEY_PASSWORD")!!
        }
    }
"""
    else:
        signing_block = """    signingConfigs {
        stableDebug {
            storeFile file(System.getenv('NEON_BREACH_KEYSTORE_PATH'))
            storePassword System.getenv('NEON_BREACH_KEYSTORE_PASSWORD')
            keyAlias System.getenv('NEON_BREACH_KEY_ALIAS')
            keyPassword System.getenv('NEON_BREACH_KEY_PASSWORD')
        }
    }
"""

    android_open = re.search(r"(?m)^([ \t]*)android\s*\{", content)
    if android_open is None:
        raise SystemExit("Could not locate the generated Android Gradle block.")
    insertion = android_open.end()
    content = content[:insertion] + "\n" + signing_block + content[insertion:]

    release_open = re.search(r"\brelease\s*\{", content)
    if release_open is None:
        raise SystemExit("Could not locate the generated release build type.")
    depth = 1
    cursor = release_open.end()
    while cursor < len(content) and depth:
        if content[cursor] == "{":
            depth += 1
        elif content[cursor] == "}":
            depth -= 1
        cursor += 1
    if depth:
        raise SystemExit("Generated release build type has unbalanced braces.")

    body_start = release_open.end()
    body_end = cursor - 1
    body = content[body_start:body_end]
    signing_lines = list(re.finditer(r"(?m)^([ \t]*)signingConfig\b.*$", body))
    if len(signing_lines) > 1:
        raise SystemExit("Generated release build type contains multiple signingConfig entries.")

    if is_kts:
        replacement = 'signingConfig = signingConfigs.getByName("stableDebug")'
    else:
        replacement = "signingConfig signingConfigs.stableDebug"

    if signing_lines:
        match = signing_lines[0]
        indent = match.group(1)
        body = body[:match.start()] + indent + replacement + body[match.end():]
    else:
        body = "\n            " + replacement + body

    return content[:body_start] + body + content[body_end:]


subprocess.run(
    [
        "flutter", "create", "--platforms=android", "--no-pub",
        "--org", "com.duckdream",
        "--project-name", "project_arena_flutter",
        str(ROOT),
    ],
    check=True,
)

manifest = ANDROID / "app/src/main/AndroidManifest.xml"
if not manifest.exists():
    raise SystemExit(f"Android manifest not generated: {manifest}")

# Reuse the existing Project Arena identity rather than Flutter's template branding.
source_icon = REPO_ROOT / "app/src/main/res/drawable-nodpi/ic_launcher.webp"
target_icon = ANDROID / "app/src/main/res/drawable-nodpi/ic_launcher.webp"
if not source_icon.is_file():
    raise SystemExit(f"Project Arena launcher icon is missing: {source_icon}")
icon_header = source_icon.read_bytes()
if icon_header[:4] != b"RIFF" or icon_header[8:12] != b"WEBP":
    raise SystemExit(f"Project Arena launcher icon is not a valid WebP file: {source_icon}")
legacy_target_icon = ANDROID / "app/src/main/res/drawable/ic_launcher.xml"
legacy_target_icon.unlink(missing_ok=True)
target_icon.parent.mkdir(parents=True, exist_ok=True)
shutil.copy2(source_icon, target_icon)

ET.register_namespace("android", "http://schemas.android.com/apk/res/android")
tree = ET.parse(manifest)
root = tree.getroot()
android_ns = "{http://schemas.android.com/apk/res/android}"

# INTERNET is a normal permission required by Supabase and by LAN TCP sockets.
internet_permission = "android.permission.INTERNET"
if not any(
    node.get(android_ns + "name") == internet_permission
    for node in root.findall("uses-permission")
):
    permission = ET.Element("uses-permission")
    permission.set(android_ns + "name", internet_permission)
    root.insert(0, permission)

application = root.find("application")
if application is None:
    raise SystemExit("AndroidManifest.xml has no application element")

application.set(android_ns + "label", APP_LABEL)
application.set(android_ns + "icon", "@drawable/ic_launcher")
application.set(android_ns + "roundIcon", "@drawable/ic_launcher")

gpu_name = "io.flutter.embedding.android.EnableFlutterGPU"
meta = next(
    (node for node in application.findall("meta-data")
     if node.get(android_ns + "name") == gpu_name),
    None,
)
if meta is None:
    meta = ET.SubElement(application, "meta-data")
    meta.set(android_ns + "name", gpu_name)
meta.set(android_ns + "value", "true")

landscape_activities = 0
for activity in application.findall("activity"):
    if activity.get(android_ns + "name", "").endswith("MainActivity"):
        activity.set(android_ns + "screenOrientation", "landscape")
        landscape_activities += 1
if landscape_activities != 1:
    raise SystemExit("Expected exactly one generated MainActivity to lock to landscape.")

tree.write(manifest, encoding="utf-8", xml_declaration=True)

gradle_candidates = [
    ANDROID / "app/build.gradle.kts",
    ANDROID / "app/build.gradle",
]
gradle = next((path for path in gradle_candidates if path.exists()), None)
if gradle is None:
    raise SystemExit("Android app Gradle file was not generated.")

content = gradle.read_text(encoding="utf-8")
content, app_id_replacements = re.subn(
    r'applicationId\s*(?:=\s*)?["\']com\.duckdream\.project_arena_flutter["\']',
    f'applicationId = "{APP_ID}"' if gradle.suffix == ".kts"
    else f'applicationId "{APP_ID}"',
    content,
)
if app_id_replacements != 1:
    raise SystemExit(
        "Could not set the expected Android applicationId; refusing an incompatible APK."
    )

if gradle.suffix == ".kts":
    content, min_sdk_replacements = re.subn(
        r"minSdk\s*=\s*flutter\.minSdkVersion", f"minSdk = {MIN_SDK}", content
    )
else:
    content, min_sdk_replacements = re.subn(
        r"minSdkVersion\s*(?:=\s*)?flutter\.minSdkVersion",
        f"minSdkVersion {MIN_SDK}",
        content,
    )
if min_sdk_replacements != 1:
    raise SystemExit(
        f"Could not enforce the Flutter-supported minSdk {MIN_SDK} in the generated Android host."
    )

if gradle.suffix == ".kts":
    content, target_sdk_replacements = re.subn(
        r"targetSdk\s*=\s*flutter\.targetSdkVersion",
        f"targetSdk = {TARGET_SDK}",
        content,
    )
else:
    content, target_sdk_replacements = re.subn(
        r"targetSdkVersion\s+flutter\.targetSdkVersion",
        f"targetSdkVersion {TARGET_SDK}",
        content,
    )
if target_sdk_replacements != 1:
    raise SystemExit(
        "Could not pin Android targetSdk. Review local-network permission requirements before changing the target."
    )

content = add_arm64_abi_filter(content, gradle)
content = add_persistent_signing(content, gradle)
gradle.write_text(content, encoding="utf-8")
print(
    f"Android host prepared: applicationId={APP_ID}, label={APP_LABEL}, "
    f"minSdk={MIN_SDK}, targetSdk={TARGET_SDK}, INTERNET permission, ABI=arm64-v8a, "
    "Flutter GPU enabled, landscape, Project Arena icon."
)
