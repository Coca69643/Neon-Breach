#!/usr/bin/env python3
"""Structural verification for Project Arena 0.2.0 offline MOBA."""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]

def read(path):
    file = ROOT / path
    if not file.is_file():
        raise SystemExit("Missing required file: %s" % path)
    return file.read_text(encoding="utf-8", errors="replace")

gradle = read("app/build.gradle")
root_gradle = read("build.gradle")
properties = read("gradle.properties")
manifest = read("app/src/main/AndroidManifest.xml")
main = read("app/src/main/java/com/duckdream/neonbreach/MainActivity.kt")
renderer = read("app/src/main/java/com/duckdream/neonbreach/FilamentGameRenderer.kt")
world = read("app/src/main/java/com/duckdream/neonbreach/WorldGlbBuilder.kt")
native = read("app/src/main/cpp/ArenaSimulation.cpp")
cmake = read("app/src/main/cpp/CMakeLists.txt")
readme = read("README.md")
changelog = read("CHANGELOG.md")
license_text = read("ASSETS/Quaternius-Universal-Base-Characters-LICENSE.txt")
avatar = ROOT / "app/src/main/assets/characters/quaternius-character.glb.b64"

checks = [
    ("versionName '0.2.0'" in gradle, "app version must be 0.2.0"),
    ("versionCode 32" in gradle, "versionCode must be 32"),
    ("com.android.application" in root_gradle, "Android Gradle Plugin missing"),
    ("org.jetbrains.kotlin.android" in root_gradle, "external Kotlin plugin missing"),
    ("android.builtInKotlin=false" in properties, "AGP built-in Kotlin opt-out missing"),
    ("android.newDsl=false" in properties, "AGP legacy DSL opt-out missing"),
    ("kotlinOptions { jvmTarget = '17' }" in gradle, "Kotlin JVM target must be 17"),
    ("filament-android:1.77.3" in gradle, "Filament dependency missing"),
    ("gltfio-android:1.77.3" in gradle, "glTF loader dependency missing"),
    ("filament-utils-android:1.77.3" in gradle, "Filament utils dependency missing"),
    ("-std=c++20" in gradle and "cxx_std_20" in cmake, "C++20 configuration missing"),
    ('android:screenOrientation="landscape"' in manifest, "landscape lock missing"),
    ("android.hardware.vulkan.version" in manifest, "Vulkan device feature declaration missing"),
    ("android.permission.INTERNET" not in manifest, "offline manifest must not request INTERNET"),
    ("Engine.Backend.VULKAN" in renderer and "Engine.Backend.OPENGL" in renderer, "Vulkan/GLES backend path missing"),
    ("Camera.Projection.ORTHO" in renderer and "WorldGlbBuilder.build()" in renderer, "3D world/camera missing"),
    ("AssetLoader" in renderer and "ResourceLoader" in renderer, "rigged character loading missing"),
    ("updateBots(snapshot: FloatArray)" in renderer and 'getFirstEntityByName("bot_unit_$index")' in renderer, "bot scene integration missing"),
    ("nativeCastPulse" in main and "nativeActivateShield" in main, "hero abilities missing"),
    ("TacticalMapView" in main and "LOCAL 5v5" in main, "MOBA HUD/minimap missing"),
    ("HERÓI:" in main and "JOGAR CONTRA BOTS" in main, "hero select/offline match menu missing"),
    ("ribbon(trail" in world and "laneStructures()" in world, "three-lane map structures missing"),
    ('botUnit("bot_unit_8"' in world and "Rival resonance unit" in world, "nine bot visuals missing"),
    ("constexpr int kBotCount = 9;" in native, "native simulation must contain 9 bots"),
    ("updateBots(float dt)" in native and "updateLanes(float dt)" in native, "bot AI or lane simulation missing"),
    ("nativeCastPulse" in native and "nativeActivateShield" in native, "native hero ability exports missing"),
    ("gBlueCreeps" in native and "gRedCreeps" in native and "gLaneProgress" in native, "lane wave/objective state missing"),
    ("offline 5v5" in readme.lower() and "offline 5v5" in changelog.lower(), "offline MOBA docs/changelog missing"),
    ("CC0 1.0 Universal" in license_text, "Quaternius CC0 license missing"),
]
for ok, message in checks:
    if not ok:
        raise SystemExit("Verification failed: " + message)

if not avatar.is_file() or avatar.stat().st_size < 500_000:
    raise SystemExit("CC0 humanoid model payload missing or unexpectedly small")

if re.search(r"(fireButton|nativeFire|shootProjectile|weaponDamage)", main + native, re.I):
    raise SystemExit("Legacy weapon controls detected in active gameplay path")

print("Project Arena 0.2.0 structural verification passed.")
print("Offline 5v5 systems, 3 lanes, 9 bots, hero abilities, minimap and CC0 asset verified.")
