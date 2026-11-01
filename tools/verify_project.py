#!/usr/bin/env python3
"""Structural verification for Project Arena 0.4.0 independent bot navigation."""
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
icon = ROOT / "app/src/main/res/drawable/ic_launcher.xml"

checks = [
    ("versionName '0.4.0'" in gradle, "app version must be 0.4.0"),
    ("versionCode 34" in gradle, "versionCode must be 34"),
    ("org.jetbrains.kotlin.android" in root_gradle, "external Kotlin plugin missing"),
    ("android.builtInKotlin=false" in properties, "AGP built-in Kotlin opt-out missing"),
    ("android.newDsl=false" in properties, "AGP legacy DSL opt-out missing"),
    ("kotlinOptions { jvmTarget = '17' }" in gradle, "Kotlin JVM target must be 17"),
    ("filament-android:1.77.3" in gradle and "gltfio-android:1.77.3" in gradle, "Filament dependencies missing"),
    ("filament-utils-android:1.77.3" in gradle, "Filament utils dependency missing"),
    ("-std=c++20" in gradle and "cxx_std_20" in cmake, "C++20 configuration missing"),
    ('android:screenOrientation="landscape"' in manifest, "landscape lock missing"),
    ("android.permission.INTERNET" not in manifest, "offline manifest must not request INTERNET"),
    ('android:icon="@drawable/ic_launcher"' in manifest, "launcher icon reference missing"),
    ("Engine.Backend.VULKAN" in renderer and "Engine.Backend.OPENGL" in renderer, "Vulkan/GLES backend path missing"),
    ("IndirectLight.Builder()" in renderer, "indirect lighting missing"),
    ("createInstance(asset)" in renderer and "botInstances.add(instance)" in renderer, "shared humanoid instances missing"),
    ("updateBots(snapshot: FloatArray, deltaTime: Float)" in renderer, "bot locomotion update missing"),
    ("renderer.updateBots(result, dt)" in main, "bot frame delta not supplied"),
    ("TacticalMapView" in main and "LOCAL 5v5" in main, "MOBA HUD/minimap missing"),
    ("HERÓI:" in main and "JOGAR CONTRA BOTS" in main, "hero select/offline match menu missing"),
    ("struct Bot" in native and "int slot = 0;" in native, "persistent bot lane slot missing"),
    ("laneFrontZ(int lane)" in native, "lane front target missing"),
    ("moveBotTo(Bot &bot, Vec2 goal, float dt)" in native, "arrive/braking navigation missing"),
    ("kBotAcceleration" in native and "kBotArrivalSpeedScale" in native, "arrival braking constants missing"),
    ("resetBot(bot, i)" in native, "bot recovery/respawn flow missing"),
    ("std::abs(bot.position.z - frontline) > 8.0f" in native, "lane pressure must use frontline presence"),
    ("updateBots(float dt)" in native and "updateLanes(float dt)" in native, "bot navigation or lane simulation missing"),
    ("gBlueCreeps" in native and "gRedCreeps" in native and "gLaneProgress" in native, "lane wave/objective state missing"),
    ("offline" in readme.lower() and "5v5" in readme.lower() and "offline" in changelog.lower() and "5v5" in changelog.lower(), "offline MOBA docs/changelog missing"),
    ("CC0 1.0 Universal" in license_text, "Quaternius CC0 license missing"),
]
for ok, message in checks:
    if not ok:
        raise SystemExit("Verification failed: " + message)

bot_ai = native[native.index("void updateBots(float dt) {"):native.index("void updateLanes(float dt) {")]
if "gPlayerX" in bot_ai or "gPlayerZ" in bot_ai:
    raise SystemExit("Bot movement still depends on player position")
if "other.position" in bot_ai or "targetPlayer" in bot_ai or "targetBot" in bot_ai:
    raise SystemExit("Moving-target chase logic remains in bot AI")
if not icon.is_file() or "fortress" not in icon.read_text(encoding="utf-8").lower():
    raise SystemExit("Project Arena launcher vector is missing its own visual identity")
if not avatar.is_file() or avatar.stat().st_size < 500_000:
    raise SystemExit("CC0 humanoid model payload missing or unexpectedly small")
if "botUnit(" in world:
    raise SystemExit("Procedural sphere/cylinder bots remain in WorldGlbBuilder")
if re.search(r"(fireButton|nativeFire|shootProjectile|weaponDamage)", main + native, re.I):
    raise SystemExit("Legacy weapon controls detected in active gameplay path")

print("Project Arena 0.4.0 structural verification passed.")
print("Independent lane AI, arrive braking, no player chase, icon and offline 5v5 verified.")
