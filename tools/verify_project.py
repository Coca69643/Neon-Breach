#!/usr/bin/env python3
"""Structural and gameplay-contract verification for Project Arena 0.9.0."""
from pathlib import Path
import json
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
asset_register=read("ASSETS/README.md")
kaykit_license=read("ASSETS/KayKit-Medieval-Hexagon-LICENSE.txt")
quaternius_license=read("ASSETS/Quaternius-Universal-Base-Characters-LICENSE.txt")
avatar=ROOT/"app/src/main/assets/characters/quaternius-character.glb.b64"
world_assets=ROOT/"app/src/main/assets/world/kaykit"

checks=[
("versionName '0.9.0'" in gradle,"versionName must be 0.9.0"),
("versionCode 39" in gradle,"versionCode must be 39"),
("applicationId 'com.duckdream.neonbreach'" in gradle,"applicationId must remain stable"),
("stableDebug" in gradle and "NEON_BREACH_KEYSTORE_PATH" in gradle,"persistent signing config missing"),
("NEON_BREACH_KEYSTORE_BASE64" in workflow and "refusing to publish an update APK" in workflow,"workflow must require persistent signing"),
("if: github.event_name != 'pull_request'" in workflow,"PR builds must not publish update APKs"),
("versionCode='39' versionName='0.9.0'" in workflow,"APK package/version verification is stale"),
("project-arena-0.9.0-update" in workflow,"artifact name must be 0.9.0"),
("org.jetbrains.kotlin.android" in root_gradle,"external Kotlin plugin missing"),
("android.builtInKotlin=false" in props and "android.newDsl=false" in props,"AGP migration flags missing"),
("filament-android:1.77.3" in gradle and "gltfio-android:1.77.3" in gradle,"Filament dependencies missing"),
("filament-utils-android:1.77.3" in gradle,"Filament utils dependency missing"),
("-std=c++20" in gradle and "cxx_std_20" in cmake,"C++20 configuration missing"),
('android:screenOrientation="landscape"' in manifest,"landscape lock missing"),
("android.permission.INTERNET" not in manifest,"offline app must not request internet"),
('android:icon="@drawable/ic_launcher"' in manifest,"custom launcher icon not referenced"),
("<vector" in icon and "#6C4DFF" in icon and "#8FEAFF" in icon and "ORION" not in icon,"custom launcher icon missing"),
("loadKayKitEnvironment()" in renderer and "world/kaykit/" in renderer,"CC0 3D environment loader missing"),
("worldAssetLoader!!.createAsset" in renderer and "worldResourceLoader!!.loadResources(asset)" in renderer,"Filament glTF loading path missing"),
("viewer.scene.addEntities(instance.entities)" in renderer and "WorldPlacement(" in renderer,"instanced 3D environment props missing"),
("KayKit CC0 environment loaded" in renderer,"environment asset count log missing"),
("Camera.Fov.VERTICAL" in renderer and "viewer.camera.setProjection(" in renderer,"perspective follow camera missing"),
("applyRestPose" in renderer and "playerAnimator?.updateBoneMatrices()" in renderer,"player skeletal skinning update missing"),
("animateArmPose" in renderer and "axis == 2" in renderer,"arm animation shoulder axis missing"),
("riverCenterZ" in world and "Carve a river bed" in world,"visible river channel missing"),
("values[72] = gPlayerHealth" in native and "healthLabel.text" in main,"player health HUD missing"),
("nativeBasicAttack" in native and "gRedCoreHealth" in native and "updateTowers(float dt)" in native,"siege objective and structure defense missing"),
("allEnemyTowersDown" in native and "allEnemyTowersDown(0)" in native,"core must remain gated until all three towers fall"),
("gLaneWaveCooldown" in native and "spawnLaneUnit" in native and "enemy.health - 36.0f" in native,"lane wave respawn and minion combat missing"),
("values[static_cast<std::size_t>(82 + i)] = gLaneUnits[static_cast<std::size_t>(i)].health" in native and "snapshot[82 + index]" in renderer,"dead minions are not removed from the rendered scene"),
("renderer.updateStructures(result)" in main and "fun updateStructures(snapshot: FloatArray)" in renderer,"destroyed tower rendering is not connected"),
("enemy.health - 12.0f" in native and "nativeBasicAttack" in native,"hero active attack and bot combat missing"),
("bot.health - 38.0f" in native and "gShieldTime > 0.0f ? 4.0f" in native,"pulse damage and shield mitigation missing"),
("botAnimators.getOrNull(index)?.updateBoneMatrices()" in renderer,"bot skinning matrices not updated"),
("fun updateCreeps(snapshot: FloatArray, deltaTime: Float)" in renderer,"minion renderer update missing"),
("fun setMinionsVisible(visible: Boolean)" in renderer,"minion scene visibility management missing"),
("FloatArray(94)" in main and "result.size >= 94" in main,"Kotlin snapshot must contain 94 floats"),
("renderer.updateCreeps(result, dt)" in main,"lane units not connected to renderer"),
("renderer.setMinionsVisible(true)" in main,"minions not shown during match"),
("kLaneUnitCount = 12" in native and "void updateLaneUnits(float dt)" in native,"12 physical lane units missing"),
("std::array<jfloat, 94> values{};" in native,"native snapshot must contain 94 floats"),
("36 + i * 2" in native and "37 + i * 2" in native,"lane unit coordinates missing from JNI snapshot"),
("updateLaneUnits(dt);" in native,"physical lane units are not simulated"),
("TOQUE PARA JOGAR" in main and "REGRAS DA PARTIDA" not in main and "0.4.0" not in main,"immersive menu check failed"),
("CC0" in asset_register and "KayKit" in asset_register,"KayKit asset register missing"),
("Creative Commons Zero, CC0" in kaykit_license and "creativecommons.org/publicdomain/zero/1.0" in kaykit_license and "CC0 1.0 Universal" in quaternius_license,"CC0 license files missing"),
("KayKit" in readme and "offline" in readme.lower() and "KayKit" in changelog,"environment licensing/docs missing"),
]
for ok,msg in checks:
    if not ok: raise SystemExit("Verification failed: "+msg)

model_names=[
"castle_blue","castle_red","tower_blue","tower_red","home_blue","home_red",
"church_blue","church_red","bridge_a","trees_a","flag_blue","flag_red"
]
if not world_assets.is_dir():
    raise SystemExit("KayKit world asset directory missing")
for name in model_names:
    gltf=world_assets/(name+".gltf")
    if not gltf.is_file():
        raise SystemExit("Missing CC0 glTF model: "+gltf.name)
    try:
        data=json.loads(gltf.read_text(encoding="utf-8"))
    except Exception as error:
        raise SystemExit("Invalid GLTF JSON "+gltf.name+": "+str(error))
    for resource in data.get("buffers",[])+data.get("images",[]):
        uri=resource.get("uri")
        if uri and not (world_assets/uri).is_file():
            raise SystemExit("Missing GLTF resource "+uri+" required by "+name)
atlas=world_assets/"hexagons_medieval.png"
if not atlas.is_file() or atlas.stat().st_size<1000:
    raise SystemExit("Shared KayKit texture atlas missing")
if "private fun sphere(" in world or "private fun cylinder(" in world:
    raise SystemExit("Legacy procedural sphere/cylinder geometry remains")
if "treesAndShrubs" in world or "shrineAndWater" in world:
    raise SystemExit("Legacy procedural RP-like environment remains")
start=native.index("void updateBots(float dt) {")
end=native.index("void updateLanes(float dt) {",start)
ai=native[start:end]
if "gPlayerX" not in ai or "gPlayerZ" not in ai or "gPlayerHealth" not in ai:
    raise SystemExit("Combat AI is not engaging the player")
if "gLaneProgress" in ai:
    raise SystemExit("Combat AI must not use lane progress as a navigation target")
if re.search(r"(fireButton|nativeFire|shootProjectile|weaponDamage)",main+native,re.I):
    raise SystemExit("Disallowed weapon mechanic found in active gameplay path")
if not avatar.is_file() or avatar.stat().st_size<500_000:
    raise SystemExit("Quaternius CC0 humanoid GLB missing")
print("Project Arena 0.9.0 structural verification passed.")
print("Siege loop, lane waves, tower defense, core objectives, manual attack, KayKit assets and skeletal rendering verified.")
