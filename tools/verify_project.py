#!/usr/bin/env python3
"""Structural verification for Project Arena 0.5.0 independent route navigation."""
from pathlib import Path
import re
ROOT = Path(__file__).resolve().parents[1]
def read(path):
    file = ROOT / path
    if not file.is_file():
        raise SystemExit("Missing required file: " + path)
    return file.read_text(encoding="utf-8", errors="replace")
gradle=read("app/build.gradle")
root_gradle=read("build.gradle")
props=read("gradle.properties")
manifest=read("app/src/main/AndroidManifest.xml")
main=read("app/src/main/java/com/duckdream/neonbreach/MainActivity.kt")
renderer=read("app/src/main/java/com/duckdream/neonbreach/FilamentGameRenderer.kt")
native=read("app/src/main/cpp/ArenaSimulation.cpp")
cmake=read("app/src/main/cpp/CMakeLists.txt")
icon=read("app/src/main/res/drawable/ic_launcher.xml")
readme=read("README.md")
changelog=read("CHANGELOG.md")
license_text=read("ASSETS/Quaternius-Universal-Base-Characters-LICENSE.txt")
avatar=ROOT/"app/src/main/assets/characters/quaternius-character.glb.b64"
checks=[
("versionName '0.5.0'" in gradle,"versionName must be 0.5.0"),
("versionCode 35" in gradle,"versionCode must be 35"),
("org.jetbrains.kotlin.android" in root_gradle,"external Kotlin plugin missing"),
("android.builtInKotlin=false" in props and "android.newDsl=false" in props,"AGP migration flags missing"),
("filament-android:1.77.3" in gradle and "gltfio-android:1.77.3" in gradle,"Filament dependencies missing"),
("filament-utils-android:1.77.3" in gradle,"Filament utils dependency missing"),
("-std=c++20" in gradle and "cxx_std_20" in cmake,"C++20 configuration missing"),
('android:screenOrientation="landscape"' in manifest,"landscape lock missing"),
("android.permission.INTERNET" not in manifest,"offline app must not request internet"),
('android:icon="@drawable/ic_launcher"' in manifest,"custom launcher icon not referenced"),
("<vector" in icon and "Visor" in icon and "ORION" not in icon,"custom hero icon missing"),
("kBlueRouteZ" in native and "kRedRouteZ" in native,"fixed lane waypoints missing"),
("int routeStep = 0;" in native and "float startDelay = 0.0f;" in native,"per-unit route state/cadence missing"),
("routeTargetZ(const Bot &bot)" in native,"fixed route target function missing"),
("void updateBots(float dt)" in native and "void updateLanes(float dt)" in native,"native simulation functions missing"),
("laneFrontZ" not in native and "kLaneFrontLimit" not in native,"score-driven moving lane front remains"),
("values[34] = gPlayerVx;" in native and "values[35] = gPlayerVz;" in native,"player velocity not exposed"),
("FloatArray(36)" in main and "result.size >= 36" in main,"Kotlin snapshot size mismatch"),
("result[34], result[35], dt" in main,"velocity handoff missing"),
("velocityX: Float, velocityZ: Float" in renderer,"renderer velocity signature missing"),
("atan2(velocityX, velocityZ)" in renderer and "atan2(-x, -z)" not in renderer,"hero heading still derives from world position"),
("createInstance(asset)" in renderer and "botInstances.add(instance)" in renderer,"humanoid instances missing"),
("offline" in readme.lower() and "offline" in changelog.lower(),"offline project docs missing"),
("CC0 1.0 Universal" in license_text,"CC0 asset license missing"),
]
for ok,msg in checks:
    if not ok: raise SystemExit("Verification failed: "+msg)
start=native.index("void updateBots(float dt) {")
end=native.index("void updateLanes(float dt) {",start)
ai=native[start:end]
if "gPlayerX" in ai or "gPlayerZ" in ai or "gLaneProgress" in ai:
    raise SystemExit("Bot navigation still depends on player or objective score")
if re.search(r"(fireButton|nativeFire|shootProjectile|weaponDamage)",main+native,re.I):
    raise SystemExit("Legacy weapon control found in active gameplay path")
if not avatar.is_file() or avatar.stat().st_size<500_000:
    raise SystemExit("CC0 humanoid asset missing")
print("Project Arena 0.5.0 structural verification passed.")
print("Fixed lane routes, independent cadence, objective decoupling, velocity heading and custom icon verified.")
