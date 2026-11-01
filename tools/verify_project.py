#!/usr/bin/env python3
"""Structural verification for Project Arena 0.6.0."""
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
world=read("app/src/main/java/com/duckdream/neonbreach/WorldGlbBuilder.kt")
native=read("app/src/main/cpp/ArenaSimulation.cpp")
cmake=read("app/src/main/cpp/CMakeLists.txt")
icon=read("app/src/main/res/drawable/ic_launcher.xml")
workflow=read(".github/workflows/android.yml")
readme=read("README.md")
changelog=read("CHANGELOG.md")
license_text=read("ASSETS/Quaternius-Universal-Base-Characters-LICENSE.txt")
avatar=ROOT/"app/src/main/assets/characters/quaternius-character.glb.b64"
checks=[
("versionName '0.6.0'" in gradle,"versionName must be 0.6.0"),
("versionCode 36" in gradle,"versionCode must be 36"),
("applicationId 'com.duckdream.neonbreach'" in gradle,"applicationId must remain stable"),
("stableDebug" in gradle and "NEON_BREACH_KEYSTORE_PATH" in gradle,"persistent signing config missing"),
("NEON_BREACH_KEYSTORE_BASE64" in workflow and "refusing to publish an update APK" in workflow,"workflow must require persistent signing"),
("if: github.event_name != 'pull_request'" in workflow,"PR artifacts must not be distributed"),
("org.jetbrains.kotlin.android" in root_gradle,"external Kotlin plugin missing"),
("android.builtInKotlin=false" in props and "android.newDsl=false" in props,"AGP migration flags missing"),
("filament-android:1.77.3" in gradle and "gltfio-android:1.77.3" in gradle,"Filament dependencies missing"),
("filament-utils-android:1.77.3" in gradle,"Filament utils dependency missing"),
("-std=c++20" in gradle and "cxx_std_20" in cmake,"C++20 configuration missing"),
('android:screenOrientation="landscape"' in manifest,"landscape lock missing"),
("android.permission.INTERNET" not in manifest,"offline app must not request internet"),
('android:icon="@drawable/ic_launcher"' in manifest,"custom launcher icon not referenced"),
("<vector" in icon and "#6C4DFF" in icon and "#8FEAFF" in icon and "ORION" not in icon,"custom hero icon missing"),
("viewer.camera.setProjection(\n            fov, aspect.toDouble()" in renderer and "Camera.Fov.VERTICAL" in renderer,"third-person perspective camera missing"),
("val distance = if (overviewCamera) 7.6f else 9.2f" in renderer,"camera distance tuning missing"),
("characterScale = 1.92f / height" in renderer and "botScale = 1.0f" in renderer,"character framing scale missing"),
("TOQUE PARA JOGAR" in main and "REGRAS DA PARTIDA" not in main and "0.4.0" not in main,"minimal menu check failed"),
("ACTION_UP" in main and "HEROES.size - 1" in main and "setHeroAppearance(selectedHero)" in main,"swipe hero selection missing"),
("fun setHeroAppearance(hero: Int)" in renderer and "Bastion: warm gold" in renderer,"hero appearance variants missing"),
("dp(190)" in main and "dp(116)" in main,"compact HUD/controls missing"),
("kBlueRouteZ{{-19.0f, -9.0f, -3.0f, 0.0f, 0.0f}}" in native and "kRedRouteZ{{19.0f, 9.0f, 3.0f, 0.0f, 0.0f}}" in native,"capture hold waypoints missing"),
("std::abs(bot.position.z) > 2.8f" in native,"capture zone radius missing"),
("gPlayerX = std::clamp(gPlayerX, -29.0f, 29.0f);" in native and "gPlayerZ = std::clamp(gPlayerZ, -29.0f, 29.0f);" in native,"player movement still has circular boundary"),
("std::exp(-16.0f * dt)" in native,"responsive player acceleration missing"),
("gShieldTime > 0.0f ? 1.85f : 1.15f" in native,"shield objective bonus missing"),
("radiusSq" not in world and "playable field broad and rectangular" in world,"circular arena clipping remains"),
("westRidge" in world and "westRidge" in native,"terrain height mismatch"),
("FloatArray(36)" in main and "result.size >= 36" in main,"Kotlin snapshot size mismatch"),
("values[34] = gPlayerVx;" in native and "values[35] = gPlayerVz;" in native,"player velocity not exposed"),
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
    raise SystemExit("Disallowed weapon mechanic found in active gameplay path")
if not avatar.is_file() or avatar.stat().st_size<500_000:
    raise SystemExit("CC0 humanoid asset missing")
print("Project Arena 0.6.0 structural verification passed.")
print("Perspective camera, hero framing, capture-hold AI, rectangular terrain, shield objective effect and persistent signing verified.")
