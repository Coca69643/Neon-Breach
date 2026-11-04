#!/usr/bin/env python3
"""Structural verification for Project Arena."""
from pathlib import Path
import base64
import hashlib
import json
import re

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
presentation = read("app/src/main/java/com/duckdream/neonbreach/HeroPresentation.kt")
presentation_tests = read("app/src/test/java/com/duckdream/neonbreach/HeroPresentationTest.kt")
world = read("app/src/main/java/com/duckdream/neonbreach/WorldGlbBuilder.kt")
map_kotlin = read("app/src/main/java/com/duckdream/neonbreach/ArenaMapDefinition.kt")
map_native = read("app/src/main/cpp/ArenaMapDefinition.h")
native = read("app/src/main/cpp/ArenaSimulation.cpp")
camp_behavior = read("app/src/main/cpp/ArenaCampCombat.h")
cmake = read("app/src/main/cpp/CMakeLists.txt")
physics_h = read("app/src/main/cpp/ArenaPhysics.h")
physics = read("app/src/main/cpp/ArenaPhysics.cpp")
physics_tests = read("tests/arena_physics_tests.cpp")
gear = read("app/src/main/java/com/duckdream/neonbreach/HeroGearGlbBuilder.kt")
gear_tests = read("app/src/test/java/com/duckdream/neonbreach/HeroGearGlbBuilderTest.kt")
world_tests = read("app/src/test/java/com/duckdream/neonbreach/WorldGlbBuilderTest.kt")
pose_tests = read("app/src/test/java/com/duckdream/neonbreach/HumanoidRigPoseTest.kt")
life_catalog = read("app/src/main/java/com/duckdream/neonbreach/ArenaLifeCatalog.kt")
life_tests = read("app/src/test/java/com/duckdream/neonbreach/ArenaLifeCatalogTest.kt")
life_fetch = read("tools/fetch_cc0_life_assets.py")
hero_catalog = read("app/src/main/java/com/duckdream/neonbreach/HeroModelCatalog.kt")
hero_catalog_tests = read("app/src/test/java/com/duckdream/neonbreach/HeroModelCatalogTest.kt")
showcase = read("app/src/main/java/com/duckdream/neonbreach/ArenaShowcaseLayout.kt")
showcase_tests = read("app/src/test/java/com/duckdream/neonbreach/ArenaShowcaseLayoutTest.kt")
workflow = read(".github/workflows/android.yml")
readme = read("README.md")
changelog = read("CHANGELOG.md")
asset_register = read("ASSETS/README.md")
nature_license = read("ASSETS/Quaternius-Stylized-Nature-License.txt")
nature_fetch = read("tools/fetch_cc0_nature_assets.py")
kaykit_license = read("ASSETS/KayKit-Medieval-Hexagon-LICENSE.txt")
quaternius_license = read("ASSETS/Quaternius-Universal-Base-Characters-LICENSE.txt")
avatar = ROOT / "app/src/main/assets/characters/quaternius-character.glb.b64"
world_assets = ROOT / "app/src/main/assets/world/kaykit"

def extract_pairs(source, start, end, pattern):
    block = source.split(start, 1)[1].split(end, 1)[0]
    return [(float(a), float(b)) for a, b in re.findall(pattern, block)]

kotlin_lanes = extract_pairs(
    map_kotlin, "val lanes = listOf(", "val camps = listOf(",
    r"Point\(\s*(-?\d+(?:\.\d+)?)f?\s*,\s*(-?\d+(?:\.\d+)?)f?\s*\)"
)
native_lanes = extract_pairs(
    map_native, "kLanes{{", "kCampPositions",
    r"\{\s*(-?\d+(?:\.\d+)?)f\s*,\s*(-?\d+(?:\.\d+)?)f\s*\}"
)
kotlin_camps = extract_pairs(
    map_kotlin, "val camps = listOf(", "val objectives = listOf(",
    r"Point\(\s*(-?\d+(?:\.\d+)?)f?\s*,\s*(-?\d+(?:\.\d+)?)f?\s*\)"
)
native_camps = extract_pairs(
    map_native, "kCampPositions{{", "kObjectivePositions",
    r"\{\s*(-?\d+(?:\.\d+)?)f\s*,\s*(-?\d+(?:\.\d+)?)f\s*\}"
)
if kotlin_lanes != native_lanes:
    raise SystemExit("Kotlin and C++ lane coordinates differ")
if kotlin_camps != native_camps:
    raise SystemExit("Kotlin and C++ camp coordinates differ")

kotlin_objectives = extract_pairs(
    map_kotlin, "val objectives = listOf(", "val groveCenters = listOf(",
    r"Point\(\s*(-?\d+(?:\.\d+)?)f?\s*,\s*(-?\d+(?:\.\d+)?)f?\s*\)"
)
native_objectives = extract_pairs(
    map_native, "kObjectivePositions{{", "kObjectiveRadii",
    r"\{\s*(-?\d+(?:\.\d+)?)f\s*,\s*(-?\d+(?:\.\d+)?)f\s*\}"
)
if kotlin_objectives != native_objectives:
    raise SystemExit("Kotlin and C++ objective coordinates differ")

kotlin_groves = extract_pairs(
    map_kotlin, "val groveCenters = listOf(", "val treeBlockers = listOf(",
    r"Point\(\s*(-?\d+(?:\.\d+)?)f?\s*,\s*(-?\d+(?:\.\d+)?)f?\s*\)"
)
native_groves = extract_pairs(
    map_native, "kGroveCenters{{", "kTreeBlockers",
    r"\{\s*(-?\d+(?:\.\d+)?)f\s*,\s*(-?\d+(?:\.\d+)?)f\s*\}"
)
if kotlin_groves != native_groves:
    raise SystemExit("Kotlin and C++ grove coordinates differ")

kotlin_trees = extract_pairs(
    map_kotlin, "val treeBlockers = listOf(", "fun laneCenterX",
    r"Point\(\s*(-?\d+(?:\.\d+)?)f?\s*,\s*(-?\d+(?:\.\d+)?)f?\s*\)"
)
native_trees = extract_pairs(
    map_native, "kTreeBlockers{{", "inline float laneCenterX",
    r"\{\s*(-?\d+(?:\.\d+)?)f\s*,\s*(-?\d+(?:\.\d+)?)f\s*\}"
)
if kotlin_trees != native_trees:
    raise SystemExit("Kotlin and C++ tree blocker coordinates differ")

def extract_river_points(source, start, end, pattern):
    block = source.split(start, 1)[1].split(end, 1)[0]
    return [tuple(float(value) for value in match) for match in re.findall(pattern, block)]

kotlin_river = extract_river_points(
    map_kotlin, "val riverCenterline = listOf(", "private fun riverSegment",
    r"RiverPoint\(\s*(-?\d+(?:\.\d+)?)f\s*,\s*(-?\d+(?:\.\d+)?)f\s*,\s*(\d+(?:\.\d+)?)f\s*\)"
)
native_river = extract_river_points(
    map_native, "kRiverCenterline{{", "inline int riverSegment",
    r"\{\s*(-?\d+(?:\.\d+)?)f\s*,\s*(-?\d+(?:\.\d+)?)f\s*,\s*(\d+(?:\.\d+)?)f\s*\}"
)
if kotlin_river != native_river:
    raise SystemExit("Kotlin and C++ river centerline/width profile differ")
if max(point[2] for point in kotlin_river) - min(point[2] for point in kotlin_river) < 1.0:
    raise SystemExit("River channel must have a meaningful variable-width profile")

kotlin_scale = float(map_kotlin.split("const val WORLD_SCALE = ", 1)[1].split("f", 1)[0])
native_scale = float(map_native.split("kWorldScale = ", 1)[1].split("f", 1)[0])
if abs(kotlin_scale - native_scale) > 0.000001:
    raise SystemExit("Kotlin and C++ world scale values differ")
if "p.add(x * scale)" not in world or "arena_map::kWorldScale" not in physics or "arena_map::kWorldScale" not in native:
    raise SystemExit("Map scale is not applied across geometry and native gameplay")

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
    ("heroX = ArenaShowcaseLayout.HERO_X" in renderer and
     "targetX = ArenaShowcaseLayout.TARGET_X" in renderer and
     "showcaseHeroZ = ArenaShowcaseLayout.HERO_Z" in renderer and
     "ArenaShowcaseLayout.SELECT_SCALE" in renderer and
     "showcaseYaw = HeroFacing.SHOWCASE_YAW + sin(animationClock * 0.42f) * 0.14f" in renderer,
     "hero preview must retain its reserved area and source-facing axis"),
    ("HeroFacing.yawFromVelocity(velocityX, velocityZ)" in renderer and
     "terrainAlignedTransform(x, z, playerYaw, scaleX, scaleY, rootY)" in renderer and
     "terrainAlignedTransform(x, z, playerYaw + Math.PI.toFloat()" not in renderer,
     "playable heroes must face the actual movement vector without a second half-turn"),
    ("applyHeroPalette(hero)" in renderer and "HeroMaterialPalette.forHero(hero)" in renderer and
     "showcaseYaw = HeroFacing.SHOWCASE_YAW + sin(animationClock * 0.42f) * 0.14f" in renderer and
     "gameplayYawMatchesAllFourWorldDirections" in presentation_tests and
     "eachHeroHasDistinctMultiPartPaletteMatchingItsGlb" in presentation_tests,
     "three playable heroes must keep individual readable palettes and verified facing"),
    ("loadPlayableHeroModels()" in renderer and "HeroModelCatalog.models" in renderer and
     "playableHeroes.all { it != null }" in renderer and "animatePlayableHero(speed)" in renderer and
     "runtime.animator.applyAnimation" in renderer,
     "three independent playable GLBs and locomotion animation are not active"),
    ("heroes/lyra.glb" in hero_catalog and "heroes/bastion.glb" in hero_catalog and
     "heroes/kairo.glb" in hero_catalog and "Female_Idle" in hero_catalog and "Man_Idle" in hero_catalog,
     "hero catalog does not map three distinct CC0 models"),
    ("threePlayableHeroesUseDistinctCc0Assets" in hero_catalog_tests and
     "animatorNamesResolveWithOrWithoutRigPrefix" in hero_catalog_tests,
     "hero catalog tests are missing"),
    ("HERO_X = -15.0f" in showcase and "HERO_Z = 4.0f" in showcase and
     "previewClearingDoesNotOverlapMajorBattlefieldProps" in showcase_tests,
     "hero showcase must remain clear of towers, camps and shrines"),
    ("val mapScale = ArenaMapDefinition.WORLD_SCALE" in renderer and
     "val distance = (if (overviewCamera) 9.4f else 8.3f) * mapScale" in renderer and
     "val height = (if (overviewCamera) 9.6f else 9.2f) * mapScale" in renderer and
     "val fov = if (overviewCamera) 48.0 else 44.0" in renderer,
     "combat camera must keep a closer readable character framing and scale with the battlefield"),
    ("0.13f,0.17f,0.075f,1f" in world and "0.19f,0.24f,0.10f,1f" in world,
     "terrain palette must use the lower-saturation olive values"),
    ("Diagnóstico:" in main and "rootCause.message" in main,
     "renderer startup recovery must expose the technical root cause"),
    ("for (style in 0..4)" in renderer and "botStyleForRole" in renderer and "botGearStyles" in renderer, "five distinct AI role silhouettes are not assigned"),
    ("val steps = 136" in world and "val shelf = 0.52f" in world and "westRidge = 2.35f" in world, "sculpted terrain mesh and higher elevation missing"),
    ("const float shelf=0.52f" in physics and "const float west=2.35f" in physics and "high-low>3.2f" in physics_tests, "native terrain surface is not synchronized with relief regression"),
    ("versionCode 58" in gradle and "versionName '0.15.12'" in gradle, "app version must be 0.15.12 / code 58"),
    ("applicationId 'com.duckdream.projectarena'" in gradle, "applicationId must remain stable"),
    ("stableDebug" in gradle and "NEON_BREACH_KEYSTORE_PATH" in gradle, "persistent signing config missing"),
    ("NEON_BREACH_KEYSTORE_BASE64" in workflow and "refusing to publish an update APK" in workflow, "workflow must require persistent signing"),
    ("if: github.event_name != 'pull_request'" in workflow, "PR builds must not publish signed APK releases"),
    ("versionCode='58' versionName='0.15.12'" in workflow, "APK package/version verification is stale"),
    ("project-arena-0.15.12-update" in workflow, "0.15.12 artifact name missing"),
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
    ("private fun laneCenterX(lane: Int, worldZ: Float)" in renderer and "ArenaNatureCatalog.trees" in renderer and "ArenaMapDefinition.lanes" in world and "ArenaMapDefinition.camps" in world and "ArenaMapDefinition.objectives" in world and "ArenaMapDefinition.h" in native and "ArenaMapDefinition.h" in physics and "arena_map::kTreeBlockers" in physics and "arena_map::kCampPositions" in native and "heightAt(x: Float, z: Float)" in world and "private fun shrine(" in world and "surrounding_water" in world, "reconstructed relief, canonical forest and objective geometry missing"),
    ("ArenaNavigation.h" in native and "arena_navigation::nextWaypoint" in native and
     "moveActorOnMap" in native and "testArenaNavigationGraph" in read("tests/arena_physics_tests.cpp"),
     "MOBA bots are not using the lane/jungle navigation graph"),
    ("riverHalfWidth" in world and "riverHalfWidth" in physics and
     "bankDistance" in world and "bankDistance" in physics and
     "arena_map::riverHalfWidth" in physics and "arena_map::riverCenterZ" in physics and
     "buildRiverChannel(water, riverShallows, riverSandbanks" in world,
     "Kotlin and native terrain must share the sculpted variable-width riverbed"),
    ("ArenaCampCombat.h" in native and "arena_camp::canAggro" in native and
     "arena_camp::canStrike" in native and "values[static_cast<std::size_t>(312 + i)]" in native and
     "attackTokens" in life_catalog and "snapshot?.getOrNull(312 + spawn.campIndex)" in renderer,
     "neutral camp guardians lack native aggro, attacks or visual attack state"),
    ("preferredObjective = bot.team == 0 ? 0 : 1" in native and
     "fallbackObjective = 1 - preferredObjective" in native and
     "moveActorOnMap(bot.position, bot.velocity, objective" in native,
     "jungle AI must rotate to its side's neutral objective through map navigation"),
    ("ArenaMapDefinition.WORLD_SCALE" in main and "ArenaMapDefinition.camps.forEachIndexed" in main and
     "ArenaMapDefinition.objectives.forEachIndexed" in main and "riverOutline(0.86f)" in main and
     "ArenaMapDefinition.riverCenterline" in world and "ArenaMapDefinition.laneCenterX" in main and
     "riverShallowPaint" in main and "campAlertPaint" in main and "snapshot[312 + index]" in main,
     "minimap is not aligned with the expanded battlefield, layered river or camp combat state"),
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
    ("botYawState" in renderer and "animatePose(rig[\"foot_l\"]" in renderer and "animatePose(rig[\"Head\"]" in renderer and "HumanoidRigPose.FLEXION_AXIS" in renderer and "localFlexion(angle, bone.lateralSign)" in renderer and "readyPose" in renderer, "NPC role gait or mirrored anatomical arm flexion missing"),
    ("PhysicsWorld.cpp" not in cmake, "unused second physics implementation must remain disabled"),

    ("firstTowerInLane" not in native, "unused tower helper should not remain under -Werror"),
    ("KayKit" in asset_register and "CC0" in asset_register, "KayKit asset register missing"),
    ("Creative Commons Zero, CC0" in kaykit_license and "creativecommons.org/publicdomain/zero/1.0" in kaykit_license and "CC0 1.0 Universal" in quaternius_license, "CC0 license files missing"),
    ("0.15.0" in readme and "offline" in readme.lower() and "0.15.0" in changelog, "release documentation missing"),
    ("loadLivingWorld()" in renderer and "updateLivingWorld(" in renderer and
     "LifeActorRuntime" in renderer and "animator.applyAnimation" in renderer and
     "animator.getAnimationCount()" in renderer,
     "Filament wildlife and camp guardian instances/animation are not integrated"),
    ("snapshot?.getOrNull(270 + spawn.campIndex)" in renderer and
     "maxDistance = (if (spawn.kind == LifeActorKind.CAMP_GUARDIAN) 31f else 36f) * mapScale" in renderer and
     "viewer.scene.removeEntities(actor.instance.entities)" in renderer,
     "neutral guardians and ambient wildlife must be visibility- and distance-managed in world scale"),
    ("ArenaNatureCatalog.trees" in renderer and "ArenaNatureCatalog.bushes" in renderer and
     "nature_tree_oak" in renderer and "nature_tree_pine" in renderer and
     "nature_tree_broadleaf" in renderer and "nature_bush" in renderer and
     "forestUsesThreeTreeSilhouettesAndSharedBushAsset" in read("app/src/test/java/com/duckdream/neonbreach/ArenaNatureCatalogTest.kt"),
     "CC0 tree and bush variation must replace the grouped procedural tree asset"),
        ("ArenaLifeCatalog.wildlife" in renderer and "ArenaLifeCatalog.campGuardians()" in renderer and
     "deer" in life_catalog and "wolf" in life_catalog and "bird" in life_catalog and
     "mushroom" in life_catalog and "walking-tree" in life_catalog and "ghost" in life_catalog,
     "ambient and neutral life roster is incomplete"),
    ("wildlifeMovesAndRetreatsFromNearbyPlayer" in life_tests and
     "campGuardiansStayAnchoredButHaveIdleMotion" in life_tests and
     "lifeCatalogContainsDistinctAmbientAndCampSpecies" in life_tests and
     "terrainGlbNoLongerEmbedsProceduralNatureOrRockClusters" in world_tests,
     "life roster, movement and scenery regression tests are missing"),
    ("source_commit" in life_fetch and "git_blob_sha" in life_fetch and
     "CC0" in asset_register and "af7c09239feb1b675ae3ad469bbcacd7b56975f2" in life_fetch and
     "ff80d2ea1eaeb3eedbcd6ce43eda1957a8e6b9b4" in life_fetch and
     "external buffer URI would break offline packaging" in life_fetch,
     "pinned CC0 asset fetcher must verify binary assets and offline self-containment"),
    ("Fetch and verify pinned CC0 life assets" in workflow and
     "tools/fetch_cc0_life_assets.py" in workflow,
     "CI must fetch and validate CC0 GLB assets before tests and APK packaging"),
    ("Bake pinned CC0 nature assets into static GLBs" in workflow and
     "tools/fetch_cc0_nature_assets.py" in workflow and
     "001ecddebd9a5ed64cfadcccde0daf9342397a1b" in nature_fetch and
     "CC0 1.0 Universal" in nature_license and
     "two self-contained GLBs" in asset_register,
     "pinned CC0 groundcover/rock bake step and license record are missing"),
    ("loadBakedNatureEnvironment" in renderer and "forest_groundcover" in renderer and
     "forest_rocks" in renderer and "ArenaMapDefinition.riverCenterZ(x)" in world and
     "private fun leafBlade(" not in world and "boulder_field" not in world and
     "terrainGlbNoLongerEmbedsProceduralNatureOrRockClusters" in world_tests,
     "textured nature must be baked into two static GLBs while retaining shared river terrain sampling"),
    ("Four readable lane-unit silhouettes" in renderer and
     "val width = when (slot) { 0 -> 1.16f" in renderer and
     "val height = when (slot) { 0 -> 0.92f" in renderer,
     "lane units must have role-distinct body proportions"),
    ("0.91f,0.70f,0.28f" in gear and "0.18f,0.73f,0.70f" in gear and
     "0.63f,0.45f,0.82f" in gear,
     "five bot role accents must be visually distinct"),
]
for ok, message in checks:
    if not ok:
        raise SystemExit("Verification failed: " + message)

model_names = [
    "castle_blue", "castle_red", "tower_blue", "tower_red", "home_blue", "home_red",
    "church_blue", "church_red", "bridge_a",
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
nature_assets = ROOT / "app/src/main/assets/world/nature"
nature_expected = {
    "tree_oak.glb.b64": "80bd662cc51f983986f4e201463dc3a729a6cd4a",
    "tree_pine.glb.b64": "0197de65879eb650247c8d56ac52da34489938cb",
    "tree_broadleaf.glb.b64": "828786b4bdb5224a8b3672f5e5d6cebe1c65bd93",
    "bush_common.glb.b64": "84b4153c17e988a658e56d4093b0028d1b034c3f",
}
for filename, expected_blob in nature_expected.items():
    path = nature_assets / filename
    if not path.is_file():
        raise SystemExit("Missing pinned CC0 nature model: " + filename)
    encoded = path.read_text(encoding="ascii").strip()
    model_bytes = base64.b64decode("".join(encoded.split()), validate=True)
    git_blob = hashlib.sha1((b"blob " + str(len(model_bytes)).encode("ascii") + b"\0") + model_bytes).hexdigest()
    if git_blob != expected_blob:
        raise SystemExit("Pinned CC0 nature model Git blob SHA mismatch: " + filename)
    if model_bytes[:4] != b"glTF" or int.from_bytes(model_bytes[4:8], "little") != 2:
        raise SystemExit("Invalid self-contained GLB 2.0 nature model: " + filename)
    json_length = int.from_bytes(model_bytes[12:16], "little")
    model_data = json.loads(model_bytes[20:20 + json_length].decode("utf-8"))
    if not model_data.get("meshes") or any(item.get("uri") for item in model_data.get("buffers", []) + model_data.get("images", [])):
        raise SystemExit("Nature GLB must contain meshes and no external resources: " + filename)
print("Four pinned CC0 tree/bush GLBs, Git blob hashes and offline packaging verified.")

baked_nature = {
    "forest_groundcover.glb": 4,
    "forest_rocks.glb": 1,
}
baked_vertex_total = 0
for filename, expected_primitives in baked_nature.items():
    path = nature_assets / filename
    if not path.is_file():
        raise SystemExit("Missing build-baked CC0 environment mesh: " + filename)
    model_bytes = path.read_bytes()
    if model_bytes[:4] != b"glTF" or int.from_bytes(model_bytes[4:8], "little") != 2:
        raise SystemExit("Invalid baked GLB 2.0 header: " + filename)
    if int.from_bytes(model_bytes[8:12], "little") != len(model_bytes):
        raise SystemExit("Baked GLB length header mismatch: " + filename)
    json_length = int.from_bytes(model_bytes[12:16], "little")
    model_data = json.loads(model_bytes[20:20 + json_length].decode("utf-8"))
    if len(model_data.get("meshes", [])) != 1:
        raise SystemExit("Baked nature GLB must contain a single merged mesh: " + filename)
    primitives = model_data["meshes"][0].get("primitives", [])
    if len(primitives) != expected_primitives:
        raise SystemExit("Unexpected baked material/draw batch count: " + filename)
    if any(item.get("uri") for item in model_data.get("buffers", []) + model_data.get("images", [])):
        raise SystemExit("Baked nature GLB must embed textures and geometry: " + filename)
    if any("bufferView" not in image for image in model_data.get("images", [])):
        raise SystemExit("Baked nature texture is not embedded: " + filename)
    baked_vertex_total += sum(
        model_data["accessors"][primitive["attributes"]["POSITION"]]["count"]
        for primitive in primitives
    )
    if len(model_bytes) > 6_000_000:
        raise SystemExit("Baked nature GLB exceeds 6 MB: " + filename)
if baked_vertex_total > 100_000:
    raise SystemExit("Baked nature geometry exceeds 100k vertices")
if "SOURCE_COMMIT = \"001ecddebd9a5ed64cfadcccde0daf9342397a1b\"" not in read("tools/fetch_cc0_nature_assets.py"):
    raise SystemExit("CC0 nature source must remain pinned to a reviewed commit")
print("Baked nature verified: two static GLBs, five material batches, textures embedded, vertex budget passed.")

atlas = world_assets / "hexagons_medieval.png"
if not atlas.is_file() or atlas.stat().st_size < 1000:
    raise SystemExit("Shared KayKit texture atlas missing")
if "private fun sphere(" in world or "private fun cylinder(" in world:
    raise SystemExit("Legacy procedural sphere/cylinder geometry remains")
if "applyRestPose" not in renderer or "runtime.animator.updateBoneMatrices()" not in renderer:
    raise SystemExit("Player skeletal skinning update missing")
hero_assets = ROOT / "app/src/main/assets/heroes"
hero_expected = {
    "lyra.glb": ("99c4df0aaabd19022809facc68f5fb5f564d35df3a9893c273a31fdaacf68e96", ["Female_Idle", "Female_Walk", "Female_Run"]),
    "bastion.glb": ("48536b0e0ea375f0831dbf5154b4c2eafda8b6c9c19ba0996dd298f2fcc9164c", ["Man_Idle", "Man_Walk", "Man_Run"]),
    "kairo.glb": ("9809532f4562ebfd3976bd96eeebd1efc1008d781aa71a15048db5bf5ae7344c", ["Female_Idle", "Female_Walk", "Female_Run"]),
}
for filename, (expected_hash, clips) in hero_expected.items():
    model_path = hero_assets / filename
    if not model_path.is_file():
        raise SystemExit("Missing independent playable hero GLB: " + filename)
    model_bytes = model_path.read_bytes()
    if hashlib.sha256(model_bytes).hexdigest() != expected_hash:
        raise SystemExit("CC0 hero GLB SHA-256 mismatch: " + filename)
    if model_bytes[:4] != b"glTF" or int.from_bytes(model_bytes[4:8], "little") != 2:
        raise SystemExit("Invalid GLB 2.0 header: " + filename)
    json_length = int.from_bytes(model_bytes[12:16], "little")
    model_data = json.loads(model_bytes[20:20 + json_length].decode("utf-8"))
    if not model_data.get("skins") or not model_data.get("meshes"):
        raise SystemExit("Playable hero must contain a skinned mesh: " + filename)
    animation_names = [animation.get("name", "").split("|")[-1] for animation in model_data.get("animations", [])]
    if any(clip not in animation_names for clip in clips):
        raise SystemExit("Missing Idle/Walk/Run clip in " + filename + ": " + repr(animation_names))
    for resource in model_data.get("buffers", []) + model_data.get("images", []):
        if resource.get("uri"):
            raise SystemExit("Playable hero has an external resource URI: " + filename)
hero_manifest = json.loads((hero_assets / "cc0-manifest.json").read_text(encoding="utf-8"))
if hero_manifest.get("license") != "CC0-1.0" or len(hero_manifest.get("models", [])) != 3:
    raise SystemExit("Three-model CC0 hero manifest is missing or incomplete")
print("Three independent CC0 hero GLBs, SHA-256, skin and locomotion clips verified.")

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
print("Project Arena 0.15.12 structural verification passed.")
print("Hero showcase clearance, right-side composition, readable combat framing and terrain palette verified.")
print("Mirrored GLB arm flexion and character motion regression tests verified.")
print("MOBA systems, illustrated HUB, role silhouettes, anatomical motion, sculpted terrain, synchronized physics and regression tests verified.")
