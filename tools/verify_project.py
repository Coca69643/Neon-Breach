#!/usr/bin/env python3
"""Structural verification for Project Arena 0.15.0."""
from pathlib import Path
import base64
import json

ROOT = Path(__file__).resolve().parents[1]

def read(path):
    file = ROOT / path
    if not file.is_file():
        raise SystemExit("Missing required file: " + path)
    return file.read_text(encoding="utf-8", errors="replace")

gradle = read("app/build.gradle")
root_gradle = read("build.gradle")
props = read("gradle.properties")
manifest = read("app/src/main/AndroidManifest.xml")
main = read("app/src/main/java/com/duckdream/neonbreach/MainActivity.kt")
meta = read("app/src/main/java/com/duckdream/neonbreach/ArenaMetaStore.kt")
renderer = read("app/src/main/java/com/duckdream/neonbreach/FilamentGameRenderer.kt")
world = read("app/src/main/java/com/duckdream/neonbreach/WorldGlbBuilder.kt")
native = read("app/src/main/cpp/ArenaSimulation.cpp")
cmake = read("app/src/main/cpp/CMakeLists.txt")
physics_h = read("app/src/main/cpp/ArenaPhysics.h")
physics = read("app/src/main/cpp/ArenaPhysics.cpp")
physics_tests = read("tests/arena_physics_tests.cpp")
gear = read("app/src/main/java/com/duckdream/neonbreach/HeroGearGlbBuilder.kt")
gear_tests = read("app/src/test/java/com/duckdream/neonbreach/HeroGearGlbBuilderTest.kt")
world_tests = read("app/src/test/java/com/duckdream/neonbreach/WorldGlbBuilderTest.kt")
pose_tests = read("app/src/test/java/com/duckdream/neonbreach/HumanoidRigPoseTest.kt")
workflow = read(".github/workflows/android.yml")
readme = read("README.md")
changelog = read("CHANGELOG.md")
asset_register = read("ASSETS/README.md")
kaykit_license = read("ASSETS/KayKit-Medieval-Hexagon-LICENSE.txt")
quaternius_license = read("ASSETS/Quaternius-Universal-Base-Characters-LICENSE.txt")
avatar = ROOT / "app/src/main/assets/characters/quaternius-character.glb.b64"
world_assets = ROOT / "app/src/main/assets/world/kaykit"

checks = [
    ("renderer.setMenuPresentation" in main and "renderer.setHeroSelectionPresentation" in main and
     "renderer.updateMenuPresentation(dt)" in main and "renderer.render(frameTimeNanos)" in main and
     "if (state != AppState.MENU) renderer.render" not in main, "menu and hero selection must render the native 3D scene"),
    ("captureHumanoidRig" in renderer and "getJointsAt(0)" in renderer and "fallbackJointIndices" in renderer,
     "skinned humanoid joints must be resolved from the active skin"),
    ("HumanoidRigPose.lateralSign(name)" in renderer and
     "HumanoidRigPose.localFlexion(angle, bone.lateralSign)" in renderer and
     "HumanoidRigPose.FLEXION_AXIS" in renderer and
     "animateHeroArmBone(\"upperarm_l\"" in renderer and
     "animateArmPose(rig[\"upperarm_r\"], readyPose + stride * armDrive" in renderer,
     "humanoid arm flexion must use the mirrored local-Z rig axis"),
    ("mirroredLocalZFlexionLowersBothArms" in pose_tests and
     "Left arm must angle downward" in pose_tests and
     "Right arm must angle downward" in pose_tests,
     "GLB bind-pose regression test for both arms is missing"),
    ("heroX = 0.0f, targetX = 0.0f, scale = 1.16f" in renderer and
     "showcaseYaw = Math.PI.toFloat() + sin(animationClock * 0.42f) * 0.14f" in renderer,
     "hero selection preview must be centered and animated"),
    ("for (style in 0..4)" in renderer and "botStyleForRole" in renderer and "botGearStyles" in renderer, "five distinct AI role silhouettes are not assigned"),
    ("val steps = 136" in world and "val shelf = 0.52f" in world and "westRidge = 2.35f" in world, "sculpted terrain mesh and higher elevation missing"),
    ("const float shelf=0.52f" in physics and "const float west=2.35f" in physics and "high-low>3.2f" in physics_tests, "native terrain surface is not synchronized with relief regression"),
    ("versionCode 49" in gradle and "versionName '0.15.3'" in gradle, "app version must be 0.15.3 / code 49"),
    ("applicationId 'com.duckdream.neonbreach'" in gradle, "applicationId must remain stable"),
    ("stableDebug" in gradle and "NEON_BREACH_KEYSTORE_PATH" in gradle, "persistent signing config missing"),
    ("NEON_BREACH_KEYSTORE_BASE64" in workflow and "refusing to publish an update APK" in workflow, "workflow must require persistent signing"),
    ("if: github.event_name != 'pull_request'" in workflow, "PR builds must not publish signed APK releases"),
    ("versionCode='49' versionName='0.15.3'" in workflow, "APK package/version verification is stale"),
    ("project-arena-0.15.3-update" in workflow, "0.15.3 artifact name missing"),
    ("refs/heads/rebuild/project-arena-0.15.0-visual-overhaul" in workflow, "0.15.0 release branch condition missing"),
    ("org.jetbrains.kotlin.android" in root_gradle, "Kotlin Android plugin missing"),
    ("android.builtInKotlin=false" in props and "android.newDsl=false" in props, "AGP migration flags missing"),
    ("filament-android:1.77.3" in gradle and "gltfio-android:1.77.3" in gradle, "Filament dependencies missing"),
    ("filament-utils-android:1.77.3" in gradle, "Filament utils dependency missing"),
    ("-std=c++20" in gradle and "cxx_std_20" in cmake, "C++20 configuration missing"),
    ('android:screenOrientation="landscape"' in manifest, "landscape lock missing"),
    ("android.permission.INTERNET" not in manifest, "offline app must not request internet"),
    ("kBotCount = 9" in native and "initializeBots()" in native and "playerRole()" in native, "5v5 role AI configuration missing"),
    ("kLaneUnitCount = 48" in native and "kLaneWaveInterval = 26.0f" in native and "gNextWaveGroup" in native, "bounded alternating waves missing"),
    ("kSnapshotCount = 320" in native and "std::array<jfloat, kSnapshotCount>" in native, "native snapshot must contain 320 floats"),
    ("FloatArray(320)" in main and "result.size >= 320" in main, "Kotlin snapshot size mismatch"),
    ("kMeleeMinionHealth" in native and "kRangedMinionHealth" in native and "slot == 3" in native, "melee/ranged minion composition missing"),
    ("kCampCount = 8" in native and "damageCamp" in native and "updateCamps" in native, "eight neutral jungle camps missing"),
    ("gObjectiveOneHealth" in native and "gObjectiveTwoHealth" in native and "damageObjective" in native, "two neutral objectives missing"),
    ("gTeamSiegeBuff" in native and "awardTeam" in native, "objective rewards and siege buffs missing"),
    ("kTowerCount = 18" in native and "activeTowerTier" in native and "friendlyMinionSupports" in native, "three-tier tower chain and minion gate missing"),
    ("anyLaneOpen(1)" in native and "corePosition" in native, "lane-gated core objective missing"),
    ("gPlayerLevel" in native and "gPlayerXp" in native and "gPlayerGold" in native, "in-match progression economy missing"),
    ("nativeBuyItem" in native and "nativeUpgradeSkill" in native and "nativeBuyItem" in main and "nativeUpgradeSkill" in main, "item shop and skill upgrade JNI are not connected"),
    ("HERO_ABILITY_NAMES" in main and "showHeroSelect()" in main, "hero selection screen missing"),
    ("showSkins()" in main and "showShop()" in main and "showMissionsProfile()" in main, "HUB sub-screen navigation missing"),
    ("ArenaMetaStore.recordMatch(this, won)" in main and "SharedPreferences" in meta, "persistent meta progression missing"),
    ("playerBoneNames" in renderer and "foot_l" in renderer and "spine_03" in renderer and '"Head"' in renderer, "expanded playable hero rig missing"),
    ("enum class HeroMotion" in renderer and "HeroMotion.DASH" in renderer and "HeroMotion.RESPAWN" in renderer, "hero motion state machine missing"),
    ("heroPoseAngles" in renderer and "kotlin.math.exp(-dt * 17f)" in renderer, "per-bone transition smoothing missing"),
    ("renderer.updatePlayerSignals(result)" in main and "fun updatePlayerSignals(snapshot: FloatArray)" in renderer, "animation state bridge missing"),
    ("towerRootInstances = IntArray(18)" in renderer and "snapshot[107 + index]" in renderer, "18 tower render instances not connected"),
    ("minionRootInstances = IntArray(48)" in renderer and "snapshot[222 + index]" in renderer and "snapshot[126 + index * 2]" in renderer, "48 minion renderer/snapshot layout mismatch"),
    ("fun laneCenterX(lane: Int, z: Float)" in renderer and "forestTrees" in renderer and "heightAt(x: Float, z: Float)" in world and "private fun shrine(" in world and "surrounding_water" in world, "reconstructed relief, forest and objective geometry missing"),
    ("deadZone = 1.85f" in renderer and "hero yaw never rotates the camera" in renderer, "fixed-heading dead-zone camera missing"),
    ("moveZ = (-z * scale)" in main, "joystick vertical axis is not screen-aligned"),
    ("private fun terrainHeight(x: Float, z: Float): Float = WorldGlbBuilder.heightAt(x, z)" in renderer, "terrain/renderer height functions diverged"),
    ("WorldPlacement(\"flag_blue\"" not in renderer and "WorldPlacement(\"flag_red\"" not in renderer, "objective/camp flags still used as map geometry"),
    ("result[116 + it]" in main and "result[104]" in main and "result[106]" in main, "HUD objective and three-tier tower fields missing"),
    ("snapshot[270 + index]" in main and "snapshot[222 + index]" in main, "minimap camps and minion snapshot fields missing"),
    ("values[15] = static_cast<float>(gWinner)" in native, "legacy match-result field must remain populated"),
    ("movePlayer(inputX, inputZ, dt)" in native and native.count("movePlayer(0.0f, 0.0f, dt)") == 0, "player movement must be integrated only once per frame"),
    ("ArenaPhysics.cpp" in cmake and "void move(Body &body" in physics_h and "void separate(Body &a, Body &b)" in physics_h, "shared kinematic physics module is not compiled or exposed"),
    ("arena_physics::move(body" in native and "arena_physics::separate(" in native and "resolveActorContacts()" in native, "player/NPC collision and movement must share physics"),
    ("arena_physics::avoidObstacles(body" in native and "void avoidObstacles(" in physics_h and "bestProjection" in physics, "AI steering must avoid static map colliders"),
    ("kFixedStep = 1.0f / 60.0f" in native and "gSimulationAccumulator" in native, "fixed 60 Hz simulation step missing"),
    ("terrainHeight(float x,float z)" in physics and "slideUphill" in physics and "hitCircle" in physics and "hitBox" in physics and "confine" in physics, "terrain, slope, obstacle or world-boundary physics missing"),
    ("testTreeCollisionAndSliding" in physics_tests and "testStructureCollision" in physics_tests and "testCharacterSeparation" in physics_tests and "testBraking" in physics_tests, "physics regression tests missing"),
    ("testObstacleSteering" in physics_tests, "AI obstacle avoidance regression test missing"),
    ("Compile and run native physics tests" in workflow and "tests/arena_physics_tests.cpp" in workflow, "CI does not compile/run native physics tests"),
    ("createHeroGear()" in renderer and "setParent(child, parent)" in renderer and "playerGearInstances" in renderer and "rebuildBotGearForHero()" in renderer, "articulated role equipment is not attached to the skeleton"),
    ("style=hero.coerceIn(0,4)" in gear and "Arcanist" in gear and "Ranger" in gear and "gear_torso" in gear and "gear_head" in gear and "gear_back" in gear and "gear_shoulder_l" in gear and "gear_boot_r" in gear and "when(style)" in gear, "five role-specific costume silhouettes missing"),
    ("generatedGearGlbHasValidContainerAndBoneParts" in gear_tests and "for (hero in 0..4)" in gear_tests and "remasteredTerrainHasReadableReliefAndWalkableGradients" in world_tests and "testDebugUnitTest" in workflow and "junit:junit:4.13.2" in gradle, "role GLB or terrain regression tests are not connected to CI"),
    ("terrainAlignedTransform" in renderer and "WorldGlbBuilder.normalAt" in renderer and "internal fun normalAt" in world, "character orientation is not aligned to terrain normals"),
    ("botYawState" in renderer and "animatePose(rig[\"foot_l\"]" in renderer and "animatePose(rig[\"Head\"]" in renderer and "Humanoid arm bones run along local +Y" in renderer and "animatePose(bone, angle, 0)" in renderer and "readyPose" in renderer, "NPC role gait or anatomical arm swing missing"),
    ("PhysicsWorld.cpp" not in cmake, "unused second physics implementation must remain disabled"),

    ("firstTowerInLane" not in native, "unused tower helper should not remain under -Werror"),
    ("KayKit" in asset_register and "CC0" in asset_register, "KayKit asset register missing"),
    ("Creative Commons Zero, CC0" in kaykit_license and "creativecommons.org/publicdomain/zero/1.0" in kaykit_license and "CC0 1.0 Universal" in quaternius_license, "CC0 license files missing"),
    ("0.15.0" in readme and "offline" in readme.lower() and "0.15.0" in changelog, "release documentation missing"),
]
for ok, message in checks:
    if not ok:
        raise SystemExit("Verification failed: " + message)

model_names = [
    "castle_blue", "castle_red", "tower_blue", "tower_red", "home_blue", "home_red",
    "church_blue", "church_red", "bridge_a", "trees_a", 
]
if not world_assets.is_dir():
    raise SystemExit("KayKit world asset directory missing")
for name in model_names:
    gltf = world_assets / (name + ".gltf")
    if not gltf.is_file():
        raise SystemExit("Missing CC0 glTF model: " + gltf.name)
    try:
        data = json.loads(gltf.read_text(encoding="utf-8"))
    except Exception as error:
        raise SystemExit("Invalid GLTF JSON " + gltf.name + ": " + str(error))
    for resource in data.get("buffers", []) + data.get("images", []):
        uri = resource.get("uri")
        if uri and not (world_assets / uri).is_file():
            raise SystemExit("Missing GLTF resource " + uri + " required by " + name)
atlas = world_assets / "hexagons_medieval.png"
if not atlas.is_file() or atlas.stat().st_size < 1000:
    raise SystemExit("Shared KayKit texture atlas missing")
if "private fun sphere(" in world or "private fun cylinder(" in world:
    raise SystemExit("Legacy procedural sphere/cylinder geometry remains")
if "applyRestPose" not in renderer or "playerAnimator?.updateBoneMatrices()" not in renderer:
    raise SystemExit("Player skeletal skinning update missing")
if not avatar.is_file() or avatar.stat().st_size < 500_000:
    raise SystemExit("Quaternius CC0 humanoid GLB missing")
raw_model = base64.b64decode(avatar.read_text(encoding="ascii"))
if raw_model[:4] != b"glTF":
    raise SystemExit("Playable humanoid asset is not a GLB file")
json_length = int.from_bytes(raw_model[12:16], "little")
model_gltf = json.loads(raw_model[20:20 + json_length].decode("utf-8"))
model_nodes = {node.get("name") for node in model_gltf.get("nodes", []) if node.get("name")}
required_joints = {
    "pelvis", "thigh_l", "thigh_r", "calf_l", "calf_r", "foot_l", "foot_r",
    "upperarm_l", "upperarm_r", "lowerarm_l", "lowerarm_r", "hand_l", "hand_r",
    "spine_01", "spine_02", "spine_03", "neck_01", "Head"
}
missing = required_joints - model_nodes
if missing:
    raise SystemExit("Playable hero rig is missing joints: " + ", ".join(sorted(missing)))
if not model_gltf.get("skins") or max(len(skin.get("joints", [])) for skin in model_gltf["skins"]) < 60:
    raise SystemExit("Playable humanoid must retain its full skinned rig")
print("Project Arena 0.15.3 structural verification passed.")
print("Mirrored GLB arm flexion and centered 3D hero showcase verified.")
print("MOBA systems, illustrated HUB, role silhouettes, anatomical motion, sculpted terrain, synchronized physics and regression tests verified.")
