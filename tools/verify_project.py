#!/usr/bin/env python3
"""Structural validation for the native Android game.

Behavioral rules that can be tested without Android/Jolt live in tests/*.cpp.
This script checks repository integrity, Android/JNI contracts, asset validity,
and build metadata; it intentionally does not lock camera values or implementation
variable names to arbitrary source-string snapshots.
"""
from pathlib import Path
import json
import re
import sys

ROOT = Path(__file__).resolve().parents[1]


def read_text(relative: str) -> str:
    path = ROOT / relative
    if not path.is_file():
        raise SystemExit(f"Required file is missing: {relative}")
    return path.read_text(encoding="utf-8")


required_files = [
    "settings.gradle",
    "build.gradle",
    "gradle.properties",
    "app/build.gradle",
    "app/src/main/AndroidManifest.xml",
    "app/src/main/res/values/strings.xml",
    "app/src/main/res/drawable/ic_launcher.xml",
    "app/src/main/java/com/duckdream/neonbreach/MainActivity.kt",
    "app/src/main/cpp/CMakeLists.txt",
    "app/src/main/cpp/game.cpp",
    "app/src/main/cpp/PhysicsWorld.h",
    "app/src/main/cpp/PhysicsWorld.cpp",
    "app/src/main/cpp/WorldLayout.h",
    "app/src/main/cpp/ProgressionManager.h",
    "app/src/main/cpp/ProgressionManager.cpp",
    "app/src/main/cpp/third_party/cgltf.h",
    "app/src/main/cpp/third_party/stb_image.h",
    "app/src/main/cpp/third_party/CGltf-LICENSE.txt",
    "app/src/main/cpp/third_party/STB-LICENSE.txt",
    "app/src/main/cpp/third_party/Jolt-LICENSE.txt",
    "tools/validate_shaders.py",
    "tests/world_layout_tests.cpp",
    "tests/progression_manager_tests.cpp",
]
for relative in required_files:
    if not (ROOT / relative).is_file():
        raise SystemExit(f"Required file is missing: {relative}")

manifest = read_text("app/src/main/AndroidManifest.xml")
if 'android:screenOrientation="landscape"' not in manifest:
    raise SystemExit("Android activity must be locked to landscape")
if 'android:glEsVersion="0x00030000"' not in manifest:
    raise SystemExit("OpenGL ES 3.0 must be declared as a device feature")
if 'android:label="@string/app_name"' not in manifest:
    raise SystemExit("Android launcher label must use the app_name resource")
app_strings = read_text("app/src/main/res/values/strings.xml")
if '<string name="app_name">ORION-9</string>' not in app_strings:
    raise SystemExit("Android-visible application name must be ORION-9")
for icon_attr in ('android:icon="@drawable/ic_launcher"',
                  'android:roundIcon="@drawable/ic_launcher"'):
    if icon_attr not in manifest:
        raise SystemExit(f"Launcher icon reference is missing: {icon_attr}")

icon = read_text("app/src/main/res/drawable/ic_launcher.xml")
if 'android:viewportWidth="108"' not in icon or "#FFC95C" not in icon or "#4AD7E2" not in icon:
    raise SystemExit("ORION-9 launcher vector asset is missing or malformed")

gradle = read_text("app/build.gradle")
application_id = re.search(r"applicationId\s+'([^']+)'", gradle)
namespace = re.search(r"namespace\s+'([^']+)'", gradle)
version_name = re.search(r"versionName\s+'([^']+)'", gradle)
version_code = re.search(r"versionCode\s+(\d+)", gradle)
target_sdk = re.search(r"targetSdk\s+(\d+)", gradle)
if not all((application_id, namespace, version_name, version_code, target_sdk)):
    raise SystemExit("Gradle Android metadata is incomplete")
if application_id.group(1) != namespace.group(1):
    raise SystemExit("applicationId and namespace must remain aligned")
if int(version_code.group(1)) < 1 or int(target_sdk.group(1)) < 35:
    raise SystemExit("Android versionCode or targetSdk is invalid")

activity = read_text("app/src/main/java/com/duckdream/neonbreach/MainActivity.kt")
if f"SITE ORION-9  •  {version_name.group(1)}" not in activity:
    raise SystemExit("In-game version label does not match Gradle versionName")
if 'text("NEON BREACH"' in activity or 'text("NEON BREACH  /' in activity:
    raise SystemExit("Obsolete Neon Breach product title remains in the Android UI")
if 'text("ORION-9", 32f' not in activity:
    raise SystemExit("Main menu title must identify the game as ORION-9")
if not re.search(r"package\s+" + re.escape(namespace.group(1)) + r"\b", activity):
    raise SystemExit("Kotlin package does not match the Gradle namespace")

cpp = read_text("app/src/main/cpp/game.cpp")
physics = read_text("app/src/main/cpp/PhysicsWorld.cpp")
world_layout = read_text("app/src/main/cpp/WorldLayout.h")
progression_header = read_text("app/src/main/cpp/ProgressionManager.h")
progression_cpp = read_text("app/src/main/cpp/ProgressionManager.cpp")

# Keep the native integration surface explicit across Kotlin and JNI.
jni_contracts = [
    ("nativeSetAssetManager", "Java_com_duckdream_neonbreach_NativeRenderer_nativeSetAssetManager"),
    ("nativeSurfaceCreated", "Java_com_duckdream_neonbreach_NativeRenderer_nativeSurfaceCreated"),
    ("nativeSurfaceChanged", "Java_com_duckdream_neonbreach_NativeRenderer_nativeSurfaceChanged"),
    ("nativeDrawFrame", "Java_com_duckdream_neonbreach_NativeRenderer_nativeDrawFrame"),
    ("nativeSetMode", "Java_com_duckdream_neonbreach_NativeRenderer_nativeSetMode"),
    ("nativeStartNewMission", "Java_com_duckdream_neonbreach_NativeRenderer_nativeStartNewMission"),
    ("nativeGetSnapshot", "Java_com_duckdream_neonbreach_NativeRenderer_nativeGetSnapshot"),
    ("nativeTouch", "Java_com_duckdream_neonbreach_MainActivity_00024GameSurface_nativeTouch"),
    ("nativeSetOperative", "Java_com_duckdream_neonbreach_MainActivity_00024GameSurface_nativeSetOperative"),
    ("nativeSetTouchSensitivity", "Java_com_duckdream_neonbreach_MainActivity_00024GameSurface_nativeSetTouchSensitivity"),
    ("nativeSetSoundEnabled", "Java_com_duckdream_neonbreach_MainActivity_00024GameSurface_nativeSetSoundEnabled"),
]
for kotlin_name, jni_symbol in jni_contracts:
    if f"external fun {kotlin_name}" not in activity:
        raise SystemExit(f"Kotlin native declaration missing: {kotlin_name}")
    if jni_symbol not in cpp:
        raise SystemExit(f"Native JNI implementation missing: {jni_symbol}")

library_match = re.search(r'System\.loadLibrary\("([^"]+)"\)', activity)
cmake = read_text("app/src/main/cpp/CMakeLists.txt")
library_target = re.search(r"add_library\(([^\s]+)\s+SHARED", cmake)
if not library_match or not library_target or library_match.group(1) != library_target.group(1):
    raise SystemExit("Kotlin loadLibrary name and CMake shared-library target differ")
if "CMAKE_CXX_STANDARD 17" not in cmake and "cxx_std_17" not in cmake:
    raise SystemExit("Native target must compile as C++17")
if "GIT_TAG v5.6.0" not in cmake:
    raise SystemExit("Jolt Physics dependency must remain version-pinned")

# These are cross-system contracts, not assertions about camera tuning or local variable names.
for token in (
    '#include "WorldLayout.h"',
    '#include "PhysicsWorld.h"',
    "neonbreach::kFacilityRoomLinks",
    "facilityPhysics.moveCharacter",
    "setPlayerWorldPosition",
    "configureArena(false)",
    "firstActiveTickLogged",
    "addPlayerKnockback",
    "syncPhysicsGates",
    "processRoomClear",
    "updateRoomTransition",
):
    if token not in cpp:
        raise SystemExit(f"Runtime integration contract is missing: {token}")
for token in ("kRoomCount", "kFacilityRoomLinks", "kRoomTransitionOffset", "kDoorwayHalfSpan"):
    if token not in world_layout:
        raise SystemExit(f"Shared world-layout contract is missing: {token}")
if "refreshCharacterContacts" not in physics:
    raise SystemExit("Physics contact refresh is missing after gate and teleport changes")

if "KILLS_PER_SECTOR = 20" not in progression_header or "sectorIndex_" not in progression_cpp:
    raise SystemExit("Progression manager contract is incomplete")

asset_root = ROOT / "app/src/main/assets/world/kenney"
asset_names = (
    "room-large.glb",
    "room-wide.glb",
    "room-corner.glb",
    "corridor-wide.glb",
    "corridor-corner.glb",
    "gate-door.glb",
    "cables.glb",
    "stairs-wide.glb",
)
for asset_name in asset_names:
    asset_path = asset_root / asset_name
    data = asset_path.read_bytes()
    if len(data) < 20 or data[:4] != b"glTF":
        raise SystemExit(f"Invalid GLB header: {asset_path}")
    if int.from_bytes(data[4:8], "little") != 2:
        raise SystemExit(f"Asset is not glTF 2.0: {asset_path}")
    json_length = int.from_bytes(data[12:16], "little")
    json_end = 20 + json_length
    if json_end > len(data):
        raise SystemExit(f"GLB JSON chunk exceeds file size: {asset_path}")
    document = json.loads(data[20:json_end].decode("utf-8").rstrip(" \t\r\n\0"))
    if not document.get("meshes") or not document.get("accessors"):
        raise SystemExit(f"GLB has no mesh/accessor content: {asset_path}")

texture = (asset_root / "Textures/colormap.png").read_bytes()
if not texture.startswith(bytes((137, 80, 78, 71, 13, 10, 26, 10))):
    raise SystemExit("Kenney environment atlas is not a valid PNG")
if "CC0" not in read_text("app/src/main/assets/world/kenney/LICENSE.txt"):
    raise SystemExit("Kenney CC0 license is missing")
if "MIT" not in read_text("app/src/main/cpp/third_party/CGltf-LICENSE.txt"):
    raise SystemExit("cgltf MIT license is missing")
if "MIT" not in read_text("app/src/main/cpp/third_party/STB-LICENSE.txt"):
    raise SystemExit("stb_image license notice is missing")
if "MIT" not in read_text("app/src/main/cpp/third_party/Jolt-LICENSE.txt"):
    raise SystemExit("Jolt license notice is missing")

print(f"Repository integrity, Android/JNI contracts, pinned native dependencies and GLB/CC0 assets OK ({len(required_files)} required files).")
print(f"Android package: {application_id.group(1)} | version: {version_name.group(1)} ({version_code.group(1)}) | target SDK: {target_sdk.group(1)}")
print("This structural check does not replace native tests, APK compilation, runtime testing or physical-device validation.")
