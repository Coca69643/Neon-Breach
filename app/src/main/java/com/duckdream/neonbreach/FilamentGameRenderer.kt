package com.duckdream.neonbreach

import android.content.Context
import android.util.Base64
import android.util.Log
import android.view.SurfaceView
import com.google.android.filament.Camera
import com.google.android.filament.Engine
import com.google.android.filament.Colors
import com.google.android.filament.IndirectLight
import com.google.android.filament.MaterialInstance
import com.google.android.filament.Skybox
import com.google.android.filament.View
import com.google.android.filament.android.UiHelper
import com.google.android.filament.gltfio.AssetLoader
import com.google.android.filament.gltfio.Animator
import com.google.android.filament.gltfio.FilamentAsset
import com.google.android.filament.gltfio.ResourceLoader
import com.google.android.filament.gltfio.UbershaderProvider
import com.google.android.filament.EntityManager
import com.google.android.filament.gltfio.FilamentInstance
import com.google.android.filament.utils.ModelViewer
import com.google.android.filament.utils.Utils
import java.nio.ByteBuffer
import kotlin.math.cos
import kotlin.math.max
import kotlin.math.sin

internal class FilamentGameRenderer(
    private val context: Context,
    surface: SurfaceView
) {
    companion object {
        private const val TAG = "ArenaRenderer"
        @Volatile private var filamentInitialized = false
    }

    val backendName: String
    private val engine: Engine
    private val viewer: ModelViewer
    private var skybox: Skybox? = null
    private var indirectLight: IndirectLight? = null
    private var worldProvider: UbershaderProvider? = null
    private var worldAssetLoader: AssetLoader? = null
    private var worldResourceLoader: ResourceLoader? = null
    private val worldAssets = LinkedHashMap<String, FilamentAsset>()
    private val worldInstances = ArrayList<FilamentInstance>()
    private val towerRootInstances = IntArray(18)
    private val towerBaseTransforms = arrayOfNulls<FloatArray>(18)
    private val towerHidden = BooleanArray(18)
    private data class WorldPlacement(
        val model: String, val x: Float, val z: Float,
        val scale: Float, val yaw: Float = 0f, val yOffset: Float = 0f
    )

    private var characterLoader: AssetLoader? = null
    private var characterResources: ResourceLoader? = null
    private var characterProvider: UbershaderProvider? = null
    private var character: FilamentAsset? = null
    private data class PlayableHeroRuntime(
        val definition: HeroModelSpec, val asset: FilamentAsset, val instance: FilamentInstance,
        val root: Int, val animator: Animator, val idleClip: Int, val walkClip: Int, val runClip: Int,
        val idleDuration: Float, val walkDuration: Float, val runDuration: Float,
        val scale: Float, val minY: Float
    )
    private val playableHeroes = arrayOfNulls<PlayableHeroRuntime>(3)
    private val heroGearAssets = ArrayList<FilamentAsset>(10)
    private val heroGearInstances = ArrayList<FilamentInstance>(20)
    private val botGearInstances = arrayOfNulls<FilamentInstance>(9)
    private val botGearStyles = IntArray(9) { -1 }
    private val playerGearInstances = arrayOfNulls<FilamentInstance>(3)
    private var equippedPlayerGear = -1
    private var playerInstance: FilamentInstance? = null
    private var playerAnimator: Animator? = null
    private val botAnimators = ArrayList<Animator>(9)
    private val minionInstances = ArrayList<FilamentInstance>(48)
    private val minionAnimators = ArrayList<Animator>(48)
    private val minionRootInstances = IntArray(48)
    private val minionBones = ArrayList<Map<String, BonePose>>(48)
    private val minionLastPositions = Array(48) { floatArrayOf(Float.NaN, Float.NaN) }
    private val minionAlive = BooleanArray(48) { false }
    private var minionAnimationPhase = 0f
    private val minionScale = 0.78f
    private data class LifeActorRuntime(
        val spawn: LifeActorSpawn,
        val instance: FilamentInstance,
        val root: Int,
        val animator: Animator,
        val scale: Float,
        val minY: Float,
        val idleClip: Int,
        val moveClip: Int,
        val idleDuration: Float,
        val moveDuration: Float,
        var visible: Boolean = false
    )
    private val lifeAssets = LinkedHashMap<String, FilamentAsset>()
    private val lifeActors = ArrayList<LifeActorRuntime>(14)
    private var lifeClock = 0f
    private var minionsVisible = false
    private var botsVisible = true
    private var showcaseMode = false
    private var showcaseHeroX = 0f
    private var showcaseHeroZ = -7.5f
    private var showcaseTargetX = 0f
    private var showcaseScale = 1.0f
    private var showcaseHeight = 3.2f
    private var showcaseDistance = 6.5f
    private var showcaseYaw = HeroFacing.SHOWCASE_YAW
    private val playerMaterials = ArrayList<MaterialInstance>(4)
    private var characterRootInstance = 0
    private var characterScale = 1f
    private var characterMinY = 0f

    private data class BonePose(val instance: Int, val base: FloatArray, val lateralSign: Float = 1f)
    private val fallbackJointIndices = mapOf(
        "pelvis" to 1, "spine_01" to 2, "spine_02" to 3, "spine_03" to 4,
        "neck_01" to 5, "Head" to 6,
        "upperarm_l" to 8, "lowerarm_l" to 9, "hand_l" to 10,
        "upperarm_r" to 32, "lowerarm_r" to 33, "hand_r" to 34,
        "thigh_l" to 55, "calf_l" to 56, "foot_l" to 57,
        "thigh_r" to 60, "calf_r" to 61, "foot_r" to 62
    )
    private val bones = LinkedHashMap<String, BonePose>()
    private val lyraJointIndex = mapOf(
        "pelvis" to 1, "spine_01" to 2, "spine_02" to 3, "spine_03" to 4,
        "neck_01" to 5, "Head" to 6,
        "upperarm_l" to 7, "upperarm_r" to 8, "lowerarm_l" to 9, "lowerarm_r" to 10,
        "hand_l" to 11, "hand_r" to 12, "thigh_l" to 13, "thigh_r" to 14,
        "calf_l" to 15, "calf_r" to 16, "foot_l" to 17, "foot_r" to 18
    )

    private fun captureLyraRig(instance: FilamentInstance): LinkedHashMap<String, BonePose> {
        val joints = if (instance.skinCount > 0) instance.getJointsAt(0) else intArrayOf()
        check(joints.size == 19) { "Lyra GLB skin must expose 19 ordered joints; found ${joints.size}" }
        val transforms = engine.transformManager
        val result = LinkedHashMap<String, BonePose>()
        for ((name, index) in lyraJointIndex) {
            val boneInstance = transforms.getInstance(joints[index])
            check(boneInstance != 0) { "Lyra joint has no transform: $name (index $index)" }
            result[name] = BonePose(
                boneInstance,
                transforms.getTransform(boneInstance, null),
                HumanoidRigPose.lateralSign(name) * -1f
            )
        }
        check(result.size == boneNames.size) { "Lyra rig binding is incomplete: ${result.size}/${boneNames.size}" }
        Log.i(TAG, "Lyra GLB rig bound by explicit skin order: ${result.size}/${boneNames.size} joints")
        return result
    }

    private fun captureHumanoidRig(
        instance: FilamentInstance,
        owner: String,
        sourceAsset: FilamentAsset = character ?: error("Humanoid source asset is unavailable for $owner"),
        flexionSignMultiplier: Float = 1f
    ): LinkedHashMap<String, BonePose> {
        val joints = if (instance.skinCount > 0) instance.getJointsAt(0) else intArrayOf()
        check(joints.size >= boneNames.size) {
            "$owner GLB skin is incomplete: expected at least ${boneNames.size} named joints, found ${joints.size}"
        }

        val entityByName = LinkedHashMap<String, Int>()
        for (entity in joints) {
            val name = sourceAsset.getName(entity)?.trim().orEmpty()
            if (name.isNotEmpty()) entityByName.putIfAbsent(name, entity)
        }
        for (entity in instance.entities) {
            val name = sourceAsset.getName(entity)?.trim().orEmpty()
            if (name.isNotEmpty()) entityByName.putIfAbsent(name, entity)
        }

        val transforms = engine.transformManager
        val rig = LinkedHashMap<String, BonePose>()
        for (name in boneNames) {
            val entity = entityByName[name]
                ?: fallbackJointIndices[name]?.let { joints.getOrNull(it) }
                ?: 0
            if (entity == 0) continue
            val boneInstance = transforms.getInstance(entity)
            if (boneInstance != 0) {
                val lateralSign = HumanoidRigPose.lateralSign(name) * flexionSignMultiplier
                rig[name] = BonePose(boneInstance, transforms.getTransform(boneInstance, null), lateralSign)
            }
        }

        val missing = boneNames.filterNot { rig.containsKey(it) }
        check(missing.isEmpty()) {
            "$owner GLB rig incomplete: missing ${missing.joinToString()}, skinJoints=${joints.size}"
        }
        Log.i(TAG, "$owner rig bound: ${rig.size}/${boneNames.size} joints from skin")
        return rig
    }
    // NPCs use the shared humanoid skeleton, including feet and head, for grounded gait.
    private val boneNames = listOf(
        "pelvis", "thigh_l", "thigh_r", "calf_l", "calf_r", "foot_l", "foot_r",
        "upperarm_l", "upperarm_r", "lowerarm_l", "lowerarm_r", "hand_l", "hand_r",
        "spine_01", "spine_02", "spine_03", "neck_01", "Head"
    )
    // The playable hero gets additional torso, head, hand and foot articulation.
    private val playerBoneNames = listOf(
        "pelvis", "thigh_l", "thigh_r", "calf_l", "calf_r", "foot_l", "foot_r",
        "upperarm_l", "upperarm_r", "lowerarm_l", "lowerarm_r", "hand_l", "hand_r",
        "spine_01", "spine_02", "spine_03", "neck_01", "Head"
    )

    private enum class HeroMotion {
        IDLE, WALK, RUN, DASH, CAST, GUARD, HIT, DOWN, RESPAWN
    }

    private val heroPoseAngles = HashMap<String, Float>(20)
    private var heroMotion = HeroMotion.IDLE
    private var heroDashActive = false
    private var heroGuardActive = false
    private var heroDowned = false
    private var heroDamageTime = 0f
    private var heroCastTime = 0f
    private var heroGuardGestureTime = 0f
    private var heroActionPulseTime = 0f
    private var heroRespawnBlend = 0f
    private var previousHeroHealth = Float.NaN
    private var previousPulseActive = false
    private var animationClock = 0f
    private var yawInitialized = false
    private var previousHeroSpeed = 0f

    private var cameraAspect = 16f / 9f
    private var cameraX = -12f
    private var cameraZ = -8.5f
    private var cameraY = 0f
    private var phase = 0f
    private var playerYaw = 0f
    private var activeHero = 0
    private var pulseRingRoot = 0
    private var shieldRingRoot = 0
    private val botMaterialSets = ArrayList<List<MaterialInstance>>(9)
    private val botDisabledState = BooleanArray(9)
    private var sceneLoaded = false
    private var overviewCamera = true
    private val botInstances = ArrayList<FilamentInstance>(9)
    private val botRootInstances = IntArray(9)
    private val botBones = ArrayList<Map<String, BonePose>>(9)
    private val lastBotPositions = Array(9) { floatArrayOf(Float.NaN, Float.NaN) }
    private var botAnimationPhase = 0f
    private val botYawState = FloatArray(9)
    private val botYawInitialized = BooleanArray(9)
    private val botScale = 1.0f

    init {
        if (!filamentInitialized) {
            synchronized(FilamentGameRenderer::class.java) {
                if (!filamentInitialized) {
                    Utils.init()
                    filamentInitialized = true
                }
            }
        }

        val created = createBackendAndViewer(surface)
        engine = created.first
        viewer = created.second
        backendName = created.third

        skybox = Skybox.Builder()
            .color(floatArrayOf(0.27f, 0.29f, 0.25f, 1f))
            .build(engine)
        viewer.scene.skybox = skybox
        indirectLight = IndirectLight.Builder()
            .irradiance(1, floatArrayOf(0.20f, 0.21f, 0.18f))
            .intensity(9_500.0f)
            .build(engine)
        viewer.scene.indirectLight = indirectLight

        // ModelViewer supplies a sun, but its default direction is straight down.
        // Angle it across the map so foliage, towers and lane walls gain readable form.
        engine.lightManager.setDirection(viewer.light, -0.42f, -1.0f, -0.34f)
        engine.lightManager.setColor(viewer.light, 1.0f, 0.93f, 0.82f)
        engine.lightManager.setIntensity(viewer.light, 46_000.0f)
        viewer.camera.setExposure(15.5f, 1.0f / 100.0f, 80.0f)

        viewer.view.renderQuality = viewer.view.renderQuality.apply {
            hdrColorBuffer = View.QualityLevel.LOW
        }
        viewer.view.dynamicResolutionOptions = viewer.view.dynamicResolutionOptions.apply {
            enabled = true
            quality = View.QualityLevel.LOW
        }
        viewer.view.antiAliasing = View.AntiAliasing.FXAA

        Log.i(TAG, "Startup stage: procedural MOBA world")
        loadWorld()
        Log.i(TAG, "Startup stage: KayKit environment")
        loadKayKitEnvironment()
        Log.i(TAG, "Startup stage: characters and rigs")
        loadCharacter()
        Log.i(TAG, "Startup stage: wildlife and camp guardians")
        loadLivingWorld()
        updateCamera(16f / 9f)
        sceneLoaded = true
        Log.i(TAG, "Filament backend=$backendName, first outdoor scene ready")
    }

    private fun createBackendAndViewer(surface: SurfaceView): Triple<Engine, ModelViewer, String> {
        fun build(backend: Engine.Backend, label: String): Triple<Engine, ModelViewer, String> {
            val candidate = Engine.create(backend)
            return try {
                val helper = UiHelper(UiHelper.ContextErrorPolicy.DONT_CHECK)
                Triple(candidate, ModelViewer(surface, candidate, helper, null), label)
            } catch (error: Throwable) {
                candidate.destroy()
                throw error
            }
        }

        return try {
            build(Engine.Backend.VULKAN, "VULKAN")
        } catch (vulkanError: Throwable) {
            Log.w(TAG, "Vulkan initialization failed; entering GLES fallback", vulkanError)
            build(Engine.Backend.OPENGL, "OPENGL_ES")
        }
    }

    private fun loadWorld() {
        val world = WorldGlbBuilder.build()
        viewer.loadModelGlb(ByteBuffer.wrap(world))
        val asset = viewer.asset ?: error("MOBA world GLB failed to load")
        val transforms = engine.transformManager
        asset.entities.forEach { entity ->
            when (asset.getName(entity)) {
                "pulse_ring" -> pulseRingRoot = transforms.getInstance(entity)
                "shield_ring" -> shieldRingRoot = transforms.getInstance(entity)
            }
        }
        check(pulseRingRoot != 0 && shieldRingRoot != 0) {
            "World ability markers were not created"
        }
    }

    private fun loadKayKitEnvironment() {
        val modelNames = listOf(
            "castle_blue", "castle_red",
            "tower_blue", "tower_red",
            "home_blue", "home_red",
            "church_blue", "church_red",
            "bridge_a", "trees_a"
        )
        worldProvider = UbershaderProvider(engine)
        worldAssetLoader = AssetLoader(engine, worldProvider!!, EntityManager.get())
        worldResourceLoader = ResourceLoader(engine)

        for (name in modelNames) {
            val json = context.assets.open("world/kaykit/$name.gltf")
                .bufferedReader().use { it.readText() }
            val asset = worldAssetLoader!!.createAsset(ByteBuffer.wrap(json.toByteArray(Charsets.UTF_8)))
                ?: throw IllegalStateException("KayKit CC0 model failed to parse: $name")
            worldAssets[name] = asset
            for (uri in asset.resourceUris) {
                if (!worldResourceLoader!!.hasResourceData(uri)) {
                    val bytes = context.assets.open("world/kaykit/$uri").use { it.readBytes() }
                    worldResourceLoader!!.addResourceData(uri, ByteBuffer.wrap(bytes))
                }
            }
            worldResourceLoader!!.loadResources(asset)
        }

        val placements = buildList {
            add(WorldPlacement("castle_blue", 0f, -27.3f, 1.0f))
            add(WorldPlacement("castle_red", 0f, 27.3f, 1.0f, Math.PI.toFloat()))
            add(WorldPlacement("home_blue", -4.5f, -24.0f, 2.05f))
            add(WorldPlacement("home_blue", 4.5f, -24.0f, 2.05f))
            add(WorldPlacement("home_red", -4.5f, 24.0f, 2.05f, Math.PI.toFloat()))
            add(WorldPlacement("home_red", 4.5f, 24.0f, 2.05f, Math.PI.toFloat()))
            add(WorldPlacement("church_blue", -8.0f, -25.3f, 1.55f))
            add(WorldPlacement("church_red", 8.0f, 25.3f, 1.55f, Math.PI.toFloat()))

            // Tower transforms are generated from the canonical battlefield catalog.
            for (team in 0..1) {
                for (lane in 0..2) {
                    for (tier in 0..2) {
                        val point = ArenaMapDefinition.towerPosition(team, lane, tier)
                        val model = if (team == 0) "tower_blue" else "tower_red"
                        val yaw = if (team == 0) 0f else Math.PI.toFloat()
                        add(WorldPlacement(model, point.x, point.z, 1.48f, yaw))
                    }
                }
            }
            for (lane in ArenaMapDefinition.lanes) {
                val crossing = lane.points.minByOrNull { kotlin.math.abs(it.z) } ?: continue
                add(WorldPlacement("bridge_a", crossing.x, crossing.z, 1.42f))
            }
            ArenaMapDefinition.treeBlockers.forEachIndexed { index, point ->
                val scale = 1.48f + (index % 4) * 0.12f
                add(WorldPlacement("trees_a", point.x, point.z, scale, (index * 0.73f) % 6.28f))
            }
        }

        val transforms = engine.transformManager
        for (placement in placements) {
            val asset = worldAssets[placement.model]
                ?: throw IllegalStateException("Missing imported KayKit asset: ${placement.model}")
            val instance = worldAssetLoader!!.createInstance(asset)
                ?: throw IllegalStateException("Could not instance KayKit model: ${placement.model}")
            worldInstances.add(instance)
            viewer.scene.addEntities(instance.entities)
            val root = transforms.getInstance(instance.root)
            check(root != 0) { "KayKit transform root missing: ${placement.model}" }
            val c = cos(placement.yaw) * placement.scale
            val sn = sin(placement.yaw) * placement.scale
            val y = terrainHeight(placement.x, placement.z) + placement.yOffset
            val matrix = floatArrayOf(
                c, 0f, -sn, 0f,
                0f, placement.scale, 0f, 0f,
                sn, 0f, c, 0f,
                placement.x, y, placement.z, 1f
            )
            transforms.setTransform(root, matrix)
            if (placement.model == "tower_blue" || placement.model == "tower_red") {
                val team = if (placement.model == "tower_blue") 0 else 1
                val lane = (0..2).minByOrNull { kotlin.math.abs(laneCenterX(it, placement.z) - placement.x) } ?: 1
                val tier = when {
                    kotlin.math.abs(kotlin.math.abs(placement.z) - 8f) < 1f -> 0
                    kotlin.math.abs(kotlin.math.abs(placement.z) - 15f) < 1f -> 1
                    else -> 2
                }
                val towerIndex = team * 9 + lane * 3 + tier
                towerRootInstances[towerIndex] = root
                towerBaseTransforms[towerIndex] = matrix.copyOf()
                towerHidden[towerIndex] = false
            }
        }

        worldAssets.values.forEach { it.releaseSourceData() }
        Log.i(TAG, "KayKit CC0 environment loaded: ${worldAssets.size} models, ${worldInstances.size} placements")
    }

    private fun loadLivingWorld() {
        val loader = characterLoader ?: error("Character AssetLoader is unavailable for CC0 life models")
        val resources = characterResources ?: error("Character ResourceLoader is unavailable for CC0 life models")
        val spawns = ArenaLifeCatalog.wildlife + ArenaLifeCatalog.campGuardians()
        val neededSpecies = spawns.map { it.species }.distinct()
        val transforms = engine.transformManager

        for (speciesId in neededSpecies) {
            try {
                val bytes = context.assets.open("life/$speciesId.glb").use { it.readBytes() }
                val asset = loader.createAsset(ByteBuffer.wrap(bytes))
                    ?: throw IllegalStateException("Filament rejected life/$speciesId.glb")
                for (uri in asset.resourceUris) {
                    val data = context.assets.open("life/$uri").use { it.readBytes() }
                    resources.addResourceData(uri, ByteBuffer.wrap(data))
                }
                resources.loadResources(asset)
                lifeAssets[speciesId] = asset
                Log.i(TAG, "CC0 life model loaded: $speciesId, bytes=${bytes.size}")
            } catch (error: Throwable) {
                Log.e(TAG, "Could not load CC0 life model: $speciesId", error)
            }
        }

        for (spawn in spawns) {
            val asset = lifeAssets[spawn.species] ?: continue
            try {
                val instance = loader.createInstance(asset)
                    ?: throw IllegalStateException("Could not instance ${spawn.species}")
                val root = transforms.getInstance(instance.root)
                check(root != 0) { "Life model root is missing: ${spawn.id}" }
                val half = asset.boundingBox.getHalfExtent(null)
                val center = asset.boundingBox.getCenter(null)
                val sourceHeight = (half[1] * 2f).coerceAtLeast(0.1f)
                val profile = ArenaLifeCatalog.species.getValue(spawn.species)
                val scale = profile.targetHeight / sourceHeight
                val minY = center[1] - half[1]
                val animator = instance.animator
                val animationCount = animator.getAnimationCount()
                val clipNames = (0 until animationCount).map { animator.getAnimationName(it).lowercase() }
                fun findClip(tokens: List<String>): Int =
                    clipNames.indexOfFirst { name -> tokens.any { token -> name.contains(token) } }
                // Only use harmless idle/locomotion clips. If a source model has
                // no matching clip, the deterministic root motion remains active.
                val idleClip = findClip(profile.idleTokens)
                val moveClip = findClip(profile.moveTokens).let { if (it >= 0) it else idleClip }
                val idleDuration = if (idleClip >= 0) animator.getAnimationDuration(idleClip).coerceAtLeast(0.1f) else 1f
                val moveDuration = if (moveClip >= 0) animator.getAnimationDuration(moveClip).coerceAtLeast(0.1f) else 1f
                val actor = LifeActorRuntime(
                    spawn, instance, root, animator, scale, minY,
                    idleClip, moveClip, idleDuration, moveDuration
                )
                lifeActors.add(actor)
                // Actors enter the scene only when the current view/player range needs them.
                actor.visible = false
                val sample = ArenaLifeCatalog.sample(spawn, spawn.phase, spawn.x + 30f, spawn.z + 30f)
                val y = terrainHeight(sample.x, sample.z) + profile.airHeight + sample.heightOffset - minY * scale
                transforms.setTransform(root, terrainAlignedTransform(
                    sample.x, sample.z, sample.yaw + profile.yawOffset, scale, scale, y
                ))
                if (idleClip >= 0) animator.applyAnimation(idleClip, 0f)
                animator.updateBoneMatrices()
                Log.i(TAG, "Life actor ready: ${spawn.id}, clips=${clipNames.joinToString()}")
            } catch (error: Throwable) {
                Log.e(TAG, "Could not create life actor: ${spawn.id}", error)
            }
        }

        lifeAssets.values.forEach { it.releaseSourceData() }
        Log.i(TAG, "Living world ready: ${lifeAssets.size}/${neededSpecies.size} CC0 species, ${lifeActors.size}/${spawns.size} actors")
    }

    private fun updateLivingWorld(deltaTime: Float, playerX: Float, playerZ: Float, snapshot: FloatArray? = null) {
        if (lifeActors.isEmpty()) return
        lifeClock += deltaTime.coerceIn(0f, 0.05f)
        val transforms = engine.transformManager
        for (actor in lifeActors) {
            val spawn = actor.spawn
            val campAlive = if (spawn.kind == LifeActorKind.CAMP_GUARDIAN) {
                snapshot?.getOrNull(270 + spawn.campIndex)?.let { it > 0f } ?: true
            } else true
            // Cull against the actor's current path position, not its original anchor.
            // A moving animal may have wandered several metres from its spawn point.
            val sample = ArenaLifeCatalog.sample(spawn, lifeClock, playerX, playerZ)
            val dx = sample.x - playerX
            val dz = sample.z - playerZ
            val maxDistance = if (spawn.kind == LifeActorKind.CAMP_GUARDIAN) 31f else 36f
            val inRange = dx * dx + dz * dz <= maxDistance * maxDistance
            val shouldShow = campAlive && inRange
            if (actor.visible != shouldShow) {
                if (shouldShow) viewer.scene.addEntities(actor.instance.entities)
                else viewer.scene.removeEntities(actor.instance.entities)
                actor.visible = shouldShow
            }
            if (!shouldShow) continue

            val profile = ArenaLifeCatalog.species.getValue(spawn.species)
            val clip = if (sample.moving) actor.moveClip else actor.idleClip
            if (clip >= 0) {
                val duration = if (clip == actor.moveClip) actor.moveDuration else actor.idleDuration
                val offset = if (clip == actor.moveClip) spawn.phase * 0.37f else spawn.phase
                actor.animator.applyAnimation(clip, (lifeClock + offset) % duration)
            }
            val y = terrainHeight(sample.x, sample.z) + profile.airHeight + sample.heightOffset - actor.minY * actor.scale
            transforms.setTransform(actor.root, terrainAlignedTransform(
                sample.x, sample.z, sample.yaw + profile.yawOffset,
                actor.scale, actor.scale, y
            ))
            if (clip >= 0) actor.animator.updateBoneMatrices()
        }
    }

    private fun loadCharacter() {
        val encoded = context.assets.open("characters/quaternius-character.glb.b64").bufferedReader().use { it.readText() }
        val modelBytes = Base64.decode(encoded, Base64.DEFAULT)
        characterProvider = UbershaderProvider(engine)
        characterLoader = AssetLoader(engine, characterProvider!!, EntityManager.get())
        characterResources = ResourceLoader(engine)

        val asset = characterLoader!!.createAsset(ByteBuffer.wrap(modelBytes))
            ?: throw IllegalStateException("CC0 humanoid GLB could not be parsed")
        character = asset

        for (uri in asset.resourceUris) {
            val data = context.assets.open("characters/$uri").use { it.readBytes() }
            characterResources!!.addResourceData(uri, ByteBuffer.wrap(data))
        }
        characterResources!!.loadResources(asset)

        // Reuse the CC0 rigged humanoid as the actual bot character model.
        // Filament instances share mesh buffers and textures instead of duplicating GPU geometry.
        val transforms = engine.transformManager
        for (index in 0 until 9) {
            val instance = characterLoader!!.createInstance(asset)
                ?: throw IllegalStateException("Could not instance bot humanoid $index")
            botInstances.add(instance)
            botAnimators.add(instance.animator)
            botMaterialSets.add(instance.materialInstances.toList())
            viewer.scene.addEntities(instance.entities)
            val rootInstance = transforms.getInstance(instance.root)
            require(rootInstance != 0) { "Bot humanoid root transform is missing: $index" }
            botRootInstances[index] = rootInstance
            val rig = captureHumanoidRig(instance, "bot-$index")
            botBones.add(rig)
            applyRestPose(rig)
            instance.animator.updateBoneMatrices()
            applyBotTint(index, disabled = false)
        }

        // Forty-eight bounded lane units: two four-unit waves per lane/team.
        // Their meshes and material atlas are shared with the hero instances.
        for (index in 0 until 48) {
            val instance = characterLoader!!.createInstance(asset)
                ?: throw IllegalStateException("Could not instance lane unit $index")
            minionInstances.add(instance)
            minionAnimators.add(instance.animator)
            val rootInstance = transforms.getInstance(instance.root)
            require(rootInstance != 0) { "Lane unit root transform is missing: $index" }
            minionRootInstances[index] = rootInstance
            val rig = captureHumanoidRig(instance, "minion-$index")
            minionBones.add(rig)
            applyRestPose(rig)
            instance.animator.updateBoneMatrices()
            val tint = if (index < 24) {
                floatArrayOf(0.42f, 0.72f, 0.88f, 1f)
            } else {
                floatArrayOf(0.88f, 0.52f, 0.43f, 1f)
            }
            instance.materialInstances.forEach { material ->
                runCatching {
                    material.setParameter("baseColorFactor", Colors.RgbaType.SRGB, tint[0], tint[1], tint[2], tint[3])
                }.onFailure { error ->
                    Log.w(TAG, "Lane unit material tint fallback for instance $index", error)
                }
            }
        }

        for (index in minionRootInstances.indices) {
            val team = if (index < 24) 0 else 1
            val local = index % 24
            val lane = local / 8
            val localInLane = local % 8
            val slot = localInLane % 4
            val group = localInLane / 4
            val z = if (team == 0) -28f - group * 1.25f else 28f + group * 1.25f
            val side = when (slot) { 0 -> -0.86f; 1 -> 0f; 2 -> 0.86f; else -> 1.45f }
            setMinionTransform(index, laneCenterX(lane, z) + side, z, if (team == 0) 0f else Math.PI.toFloat())
        }

        loadPlayableHeroModels()
        createHeroGear()
        activatePlayerModel(0)
        asset.releaseSourceData()
        Log.i(TAG, "Three separate CC0 hero assets loaded; legacy shared rig remains isolated to bots and lane units")
    }

    private fun loadPlayableHeroModels() {
        val loader = characterLoader ?: error("Hero asset loader is unavailable")
        val resources = characterResources ?: error("Hero resource loader is unavailable")
        val transforms = engine.transformManager
        HeroModelCatalog.models.forEachIndexed { heroIndex, definition ->
            val bytes = context.assets.open(definition.assetPath).use { it.readBytes() }
            require(bytes.size > 100_000 && bytes[0] == 0x67.toByte() &&
                bytes[1] == 0x6c.toByte() && bytes[2] == 0x54.toByte() && bytes[3] == 0x46.toByte()) {
                "Invalid bundled GLB for ${definition.id}: ${bytes.size} bytes"
            }
            val asset = loader.createAsset(ByteBuffer.wrap(bytes))
                ?: error("Filament could not parse ${definition.assetPath}")
            var instance: FilamentInstance? = null
            try {
                for (uri in asset.resourceUris) {
                    if (!resources.hasResourceData(uri)) {
                        val resource = context.assets.open("heroes/$uri").use { it.readBytes() }
                        resources.addResourceData(uri, ByteBuffer.wrap(resource))
                    }
                }
                resources.loadResources(asset)
                instance = loader.createInstance(asset)
                    ?: error("Filament could not instance ${definition.id}")
                check(instance.skinCount > 0) { "${definition.id} GLB has no skinned body" }
                val joints = instance.getJointsAt(0)
                check(joints.size >= 25) { "${definition.id} humanoid rig is incomplete: ${joints.size} joints" }
                val animator = instance.animator
                val names = List(animator.getAnimationCount()) { animator.getAnimationName(it) }
                val idle = HeroModelCatalog.animationIndex(names, definition.idleClip)
                val walk = HeroModelCatalog.animationIndex(names, definition.walkClip)
                val run = HeroModelCatalog.animationIndex(names, definition.runClip)
                check(idle >= 0 && walk >= 0 && run >= 0) {
                    "${definition.id} is missing Idle/Walk/Run clips: ${names.joinToString()}"
                }
                val half = asset.boundingBox.getHalfExtent(null)
                val center = asset.boundingBox.getCenter(null)
                val root = transforms.getInstance(instance.root)
                check(root != 0) { "${definition.id} root transform is missing" }
                val height = max(0.1f, half[1] * 2f)
                val idleDuration = animator.getAnimationDuration(idle).coerceAtLeast(0.01f)
                val walkDuration = animator.getAnimationDuration(walk).coerceAtLeast(0.01f)
                val runDuration = animator.getAnimationDuration(run).coerceAtLeast(0.01f)
                animator.applyAnimation(idle, 0f)
                animator.updateBoneMatrices()
                playableHeroes[heroIndex] = PlayableHeroRuntime(
                    definition, asset, instance, root, animator, idle, walk, run,
                    idleDuration, walkDuration, runDuration, 2.12f / height, center[1] - half[1]
                )
                asset.releaseSourceData()
                Log.i(TAG, "Playable CC0 hero ready: ${definition.id}; safe clips loaded; joints=${joints.size}")
            } catch (error: Throwable) {
                instance?.let { failed -> runCatching { viewer.scene.removeEntities(failed.entities) } }
                runCatching { loader.destroyAsset(asset) }
                throw IllegalStateException("Required playable hero failed to load: ${definition.id}", error)
            }
        }
        check(playableHeroes.all { it != null }) { "All three independent playable GLBs must be available" }
    }

    private fun animatePlayableHero(speed: Float) {
        val runtime = playableHeroes.getOrNull(activeHero) ?: return
        val (clip, duration) = when {
            speed >= 3.0f -> runtime.runClip to runtime.runDuration
            speed >= 0.18f -> runtime.walkClip to runtime.walkDuration
            else -> runtime.idleClip to runtime.idleDuration
        }
        runtime.animator.applyAnimation(clip, animationClock % duration.coerceAtLeast(0.01f))
        runtime.animator.updateBoneMatrices()
    }

    private fun activatePlayerModel(hero: Int) {
        val runtime = playableHeroes.getOrNull(hero.coerceIn(0, 2))
            ?: error("Independent CC0 hero asset is missing for index $hero")
        val target = runtime.instance
        if (playerInstance !== target) {
            playerInstance?.let { viewer.scene.removeEntities(it.entities) }
            playerInstance = target
            viewer.scene.addEntities(target.entities)
        }
        playerAnimator = runtime.animator
        playerMaterials.clear()
        runtime.instance.materialInstances.forEach { playerMaterials.add(it) }
        applyHeroPalette(hero)
        bones.clear()
        characterRootInstance = runtime.root
        characterScale = runtime.scale
        characterMinY = runtime.minY
        equippedPlayerGear = -1
        runtime.animator.applyAnimation(runtime.idleClip, 0f)
        runtime.animator.updateBoneMatrices()
        Log.i(TAG, "Playable model activated: ${runtime.definition.id} / ${runtime.definition.assetPath}")
    }


    private fun applyHeroPalette(hero: Int) {
        val palette = HeroMaterialPalette.forHero(hero)
        if (palette.size != playerMaterials.size) {
            Log.w(TAG, "Hero palette/material mismatch: hero=$hero palette=${palette.size} materials=${playerMaterials.size}")
        }
        playerMaterials.forEachIndexed { index, material ->
            val color = palette.getOrNull(index) ?: return@forEachIndexed
            runCatching {
                material.setParameter(
                    "baseColorFactor", Colors.RgbaType.SRGB,
                    color.r, color.g, color.b, color.a
                )
            }.onFailure { error ->
                Log.w(TAG, "Could not apply hero palette: hero=$hero material=$index", error)
            }
        }
    }

    private fun createHeroGear() {
        val loader = characterLoader ?: error("Character asset loader is not ready")
        val transforms = engine.transformManager
        val assets = arrayOfNulls<FilamentAsset>(10)
        for (team in 0..1) {
            for (style in 0..4) {
                val asset = loader.createAsset(ByteBuffer.wrap(HeroGearGlbBuilder.build(style, team)))
                    ?: throw IllegalStateException("Hero gear GLB failed to load: style=$style team=$team")
                if (asset.resourceUris.isNotEmpty()) {
                    for (uri in asset.resourceUris) {
                        if (!characterResources!!.hasResourceData(uri)) {
                            val bytes = context.assets.open("characters/$uri").use { it.readBytes() }
                            characterResources!!.addResourceData(uri, ByteBuffer.wrap(bytes))
                        }
                    }
                    characterResources!!.loadResources(asset)
                }
                assets[team * 5 + style] = asset
                heroGearAssets.add(asset)
            }
        }

        val parentByPart = mapOf(
            "gear_torso" to "spine_02",
            "gear_trim" to "spine_02",
            "gear_head" to "Head",
            "gear_head_trim" to "Head",
            "gear_back" to "spine_01",
            "gear_shoulder_l" to "upperarm_l",
            "gear_shoulder_r" to "upperarm_r",
            "gear_forearm_l" to "lowerarm_l",
            "gear_forearm_r" to "lowerarm_r",
            "gear_thigh_l" to "thigh_l",
            "gear_thigh_r" to "thigh_r",
            "gear_boot_l" to "foot_l",
            "gear_boot_r" to "foot_r"
        )
        fun createAttached(style: Int, team: Int, rig: Map<String, BonePose>): FilamentInstance {
            val asset = assets[team * 5 + style]
                ?: error("Missing hero gear asset style=$style team=$team")
            val instance = loader.createInstance(asset)
                ?: throw IllegalStateException("Could not instantiate hero gear style=$style team=$team")
            heroGearInstances.add(instance)
            viewer.scene.addEntities(instance.entities)
            for (entity in instance.entities) {
                val partName = asset.getName(entity)?.trim().orEmpty()
                val parentName = parentByPart[partName] ?: continue
                val parent = rig[parentName]?.instance ?: continue
                val child = transforms.getInstance(entity)
                if (child != 0) transforms.setParent(child, parent)
            }
            return instance
        }

        // Playable heroes now carry full-body CC0 meshes and authored clothing.
        // Bone-attached role geometry remains exclusively in the bot pipeline.
        equippedPlayerGear = -1
        rebuildBotGearForHero()
        Log.i(TAG, "AI role silhouettes loaded; playable hero gear overlays are disabled")
    }

    private fun botStyleForRole(role: Int): Int = when (role.coerceIn(0, 4)) {
        0 -> 1 // Solo: Bastion's heavy silhouette.
        1 -> 2 // Jungle: Kairo's mobile silhouette.
        2 -> 3 // Mid: tall-collar arcanist.
        3 -> 4 // Carry: hooded ranger.
        else -> 0 // Support: Lyra's layered mantle.
    }

    private fun rebuildBotGearForHero() {
        if (heroGearAssets.size < 10 || botBones.size < 9) return
        val occupiedRole = when (activeHero) { 1 -> 0; 2 -> 1; else -> 4 }
        val blueRoles = (0..4).filter { it != occupiedRole }
        val loader = characterLoader ?: return
        for (index in 0 until 9) {
            val role = if (index < 4) blueRoles[index] else index - 4
            val style = botStyleForRole(role)
            if (botGearStyles[index] == style && botGearInstances[index] != null) continue
            botGearInstances[index]?.let { viewer.scene.removeEntities(it.entities) }
            val team = if (index < 4) 0 else 1
            val assetIndex = team * 5 + style
            val asset = heroGearAssets.getOrNull(assetIndex) ?: continue
            val instance = loader.createInstance(asset) ?: continue
            heroGearInstances.add(instance)
            if (botsVisible) viewer.scene.addEntities(instance.entities)
            val parentByPart = mapOf(
                "gear_torso" to "spine_02", "gear_trim" to "spine_02",
                "gear_head" to "Head", "gear_head_trim" to "Head",
                "gear_back" to "spine_01",
                "gear_shoulder_l" to "upperarm_l", "gear_shoulder_r" to "upperarm_r",
                "gear_forearm_l" to "lowerarm_l", "gear_forearm_r" to "lowerarm_r",
                "gear_thigh_l" to "thigh_l", "gear_thigh_r" to "thigh_r",
                "gear_boot_l" to "foot_l", "gear_boot_r" to "foot_r"
            )
            for (entity in instance.entities) {
                val part = asset.getName(entity)?.trim().orEmpty()
                val parentName = parentByPart[part] ?: continue
                val parent = botBones[index][parentName]?.instance ?: continue
                val child = engine.transformManager.getInstance(entity)
                if (child != 0) engine.transformManager.setParent(child, parent)
            }
            botGearInstances[index] = instance
            botGearStyles[index] = style
        }
    }

    fun render(frameTimeNanos: Long): Boolean = viewer.render(frameTimeNanos)

    fun resize(width: Int, height: Int) {
        if (width <= 0 || height <= 0) return
        cameraAspect = width.toFloat() / height.toFloat()
        updateCamera(cameraAspect)
    }

    fun resetHeroAnimationState() {
        heroMotion = HeroMotion.IDLE
        heroDashActive = false
        heroGuardActive = false
        heroDowned = false
        heroDamageTime = 0f
        heroCastTime = 0f
        heroGuardGestureTime = 0f
        heroActionPulseTime = 0f
        heroRespawnBlend = 0f
        previousHeroHealth = Float.NaN
        previousPulseActive = false
        previousHeroSpeed = 0f
        yawInitialized = false
        botYawInitialized.fill(false)
        lastBotPositions.forEach { it[0] = Float.NaN; it[1] = Float.NaN }
        minionLastPositions.forEach { it[0] = Float.NaN; it[1] = Float.NaN }
    }

    fun updatePlayerSignals(snapshot: FloatArray) {
        if (snapshot.size < 96) return

        val health = snapshot[72]
        if (!previousHeroHealth.isNaN() && health < previousHeroHealth - 0.5f) {
            heroDamageTime = 0.28f
        }
        previousHeroHealth = health

        heroDashActive = snapshot[62] > 0.02f
        heroGuardActive = snapshot[7] > 0.02f

        val pulseActive = snapshot[61] > 0.02f
        if (pulseActive && !previousPulseActive) {
            heroCastTime = max(heroCastTime, 0.48f)
        }
        previousPulseActive = pulseActive

        val isDown = snapshot[95] > 0.02f
        if (isDown) {
            heroDowned = true
            heroRespawnBlend = 0f
        } else if (heroDowned) {
            heroDowned = false
            heroRespawnBlend = 0.72f
        }
    }

    fun triggerAbilityGesture() {
        heroCastTime = max(heroCastTime, 0.48f)
    }

    fun triggerGuardGesture() {
        heroGuardGestureTime = max(heroGuardGestureTime, 0.36f)
    }

    fun triggerActionPulse() {
        // A small readable body accent; it does not replace the gameplay hit logic.
        heroActionPulseTime = max(heroActionPulseTime, 0.18f)
    }

    fun update(x: Float, y: Float, z: Float, velocityX: Float, velocityZ: Float, deltaTime: Float) {
        if (!sceneLoaded) return
        val dt = deltaTime.coerceIn(0f, 0.05f)
        if (dt <= 0f) return

        val speed = kotlin.math.sqrt(velocityX * velocityX + velocityZ * velocityZ)
        var turnRate = 0f
        if (speed > 0.18f) {
            val desiredYaw = HeroFacing.yawFromVelocity(velocityX, velocityZ)
            if (!yawInitialized) {
                playerYaw = desiredYaw
                yawInitialized = true
            } else {
                val yawError = kotlin.math.atan2(
                    sin(desiredYaw - playerYaw),
                    cos(desiredYaw - playerYaw)
                )
                turnRate = (yawError / dt).coerceIn(-5.5f, 5.5f)
                playerYaw += yawError * (1f - kotlin.math.exp(-dt * 15f))
            }
        }

        // Fixed world heading. The hero moves visibly inside a camera dead zone.
        val cameraBlend = (1f - kotlin.math.exp(-dt * 5.2f)).coerceIn(0f, 1f)
        if (!overviewCamera) {
            val deltaX = x - cameraX
            val deltaZ = z - cameraZ
            val distance = kotlin.math.sqrt(deltaX * deltaX + deltaZ * deltaZ)
            val deadZone = 1.85f
            if (distance > deadZone) {
                val follow = ((distance - deadZone) / distance).coerceIn(0f, 1f)
                cameraX += deltaX * follow * cameraBlend
                cameraZ += deltaZ * follow * cameraBlend
                val targetHeight = terrainHeight(cameraX, cameraZ)
                cameraY += (targetHeight - cameraY) * cameraBlend
            }
        }
        overviewCamera = false

        val moving = smoothStep01((speed - 0.16f) / 1.25f)
        val runBlend = smoothStep01((speed - 3.0f) / 2.35f)
        val strideProfile = when (activeHero) {
            1 -> 0.88f // Bastion: compact, grounded cadence.
            2 -> 1.10f // Kairo: quicker, lighter cadence.
            else -> 1.0f
        }
        if (speed > 0.18f) phase += speed * dt * 1.72f * strideProfile
        animationClock += dt

        val widthScale = when (activeHero) {
            1 -> 1.07f
            2 -> 0.96f
            else -> 1.0f
        }
        val heightScale = when (activeHero) {
            1 -> 0.99f
            2 -> 1.035f
            else -> 1.01f
        }
        val scaleX = characterScale * widthScale
        val scaleY = characterScale * heightScale
        val gaitBob = kotlin.math.abs(sin(phase * 2f)) * 0.024f * moving
        val groundedOffset = if (activeHero == 1) -0.035f else 0f
        val downOffset = if (heroDowned) -0.18f else 0f
        val respawnOffset = smoothStep01(heroRespawnBlend / 0.72f) * 0.045f
        val rootY = terrainHeight(x, z) + gaitBob + groundedOffset + downOffset + respawnOffset -
            characterMinY * scaleY
        val matrix = terrainAlignedTransform(x, z, playerYaw, scaleX, scaleY, rootY)
        engine.transformManager.setTransform(characterRootInstance, matrix)

        updateHeroPose(speed, turnRate, moving, runBlend, dt)
        heroDamageTime = max(0f, heroDamageTime - dt)
        heroCastTime = max(0f, heroCastTime - dt)
        heroGuardGestureTime = max(0f, heroGuardGestureTime - dt)
        heroActionPulseTime = max(0f, heroActionPulseTime - dt)
        heroRespawnBlend = max(0f, heroRespawnBlend - dt)

        previousHeroSpeed = speed
        animatePlayableHero(speed)
        updateCamera(cameraAspect)
    }

    private fun smoothStep01(value: Float): Float {
        val t = value.coerceIn(0f, 1f)
        return t * t * (3f - 2f * t)
    }

    private fun updateHeroPose(
        speed: Float,
        turnRate: Float,
        moving: Float,
        runBlend: Float,
        dt: Float
    ) {
        val stride = sin(phase) * (0.34f + 0.07f * runBlend) * moving
        val oppositeStride = -stride
        val leftLift = max(0f, -sin(phase)) * moving
        val rightLift = max(0f, sin(phase)) * moving
        val idleBreath = sin(animationClock * 1.35f) * 0.012f
        val turnLean = (turnRate / 5.5f).coerceIn(-1f, 1f) * 0.075f
        val acceleration = if (dt > 0f) ((speed - previousHeroSpeed) / dt).coerceIn(-9f, 9f) else 0f
        val braking = smoothStep01(-acceleration / 8f)
        val rawDash = if (heroDashActive) 1f else 0f
        val rawCast = smoothStep01(heroCastTime / 0.48f)
        val rawGuard = max(if (heroGuardActive) 0.72f else 0f, smoothStep01(heroGuardGestureTime / 0.36f))
        val rawHit = smoothStep01(heroDamageTime / 0.28f)
        val rawDown = if (heroDowned) 1f else 0f
        val rawRespawn = smoothStep01(heroRespawnBlend / 0.72f)

        // Resolve one dominant action state so a stale ability timer cannot overwrite
        // a hit reaction, a downed pose or the controlled return-to-stand transition.
        heroMotion = when {
            rawDown > 0f -> HeroMotion.DOWN
            rawRespawn > 0f -> HeroMotion.RESPAWN
            rawHit > 0.05f -> HeroMotion.HIT
            rawDash > 0f -> HeroMotion.DASH
            rawCast > 0.05f -> HeroMotion.CAST
            rawGuard > 0.05f -> HeroMotion.GUARD
            runBlend > 0.15f -> HeroMotion.RUN
            moving > 0.08f -> HeroMotion.WALK
            else -> HeroMotion.IDLE
        }
        val down = if (heroMotion == HeroMotion.DOWN) 1f else 0f
        val respawn = if (heroMotion == HeroMotion.RESPAWN) rawRespawn else 0f
        val hit = if (heroMotion == HeroMotion.HIT) rawHit else 0f
        val dash = if (heroMotion == HeroMotion.DASH) rawDash else 0f
        val cast = if (heroMotion == HeroMotion.CAST) rawCast else 0f
        val guard = if (heroMotion == HeroMotion.GUARD) rawGuard else 0f
        val action = if (heroMotion == HeroMotion.IDLE || heroMotion == HeroMotion.WALK ||
            heroMotion == HeroMotion.RUN) smoothStep01(heroActionPulseTime / 0.18f) else 0f

        val heroLean = when (activeHero) {
            1 -> -0.025f // Bastion keeps a more upright centre of mass.
            2 -> 0.045f  // Kairo leans slightly into movement.
            else -> 0.012f
        }
        val strideScale = when (activeHero) {
            1 -> 0.88f
            2 -> 1.08f
            else -> 1f
        }
        val castBias = if (activeHero == 0) 0.10f else if (activeHero == 2) -0.08f else 0f

        val upperLeft = 0.52f - stride * 0.34f * strideScale +
            cast * (0.18f + castBias) - guard * 0.12f - hit * 0.06f
        val upperRight = 0.52f + stride * 0.34f * strideScale -
            cast * (0.48f - castBias) + guard * 0.12f + hit * 0.06f
        val lowerLeft = 0.32f + leftLift * 0.10f + cast * 0.08f + guard * 0.10f
        val lowerRight = 0.34f + rightLift * 0.10f - cast * 0.42f + guard * 0.10f

        animateHeroArmBone("upperarm_l", upperLeft, dt)
        animateHeroArmBone("upperarm_r", upperRight, dt)
        animateHeroArmBone("lowerarm_l", lowerLeft, dt)
        animateHeroArmBone("lowerarm_r", lowerRight, dt)
        val wristMotion = 0.035f * sin(phase) * moving - cast * 0.08f
        animateHeroArmBone("hand_l", wristMotion, dt)
        animateHeroArmBone("hand_r", wristMotion, dt)

        val kneeBias = if (activeHero == 1) 0.07f else 0.015f
        animateHeroBone("thigh_l", stride * 0.57f * strideScale + down * 0.42f, dt)
        animateHeroBone("thigh_r", oppositeStride * 0.57f * strideScale + down * 0.42f, dt)
        animateHeroBone("calf_l", leftLift * 0.42f + kneeBias + down * 0.30f, dt)
        animateHeroBone("calf_r", rightLift * 0.42f + kneeBias + down * 0.30f, dt)
        animateHeroBone("foot_l", -leftLift * 0.15f - down * 0.12f, dt)
        animateHeroBone("foot_r", -rightLift * 0.15f - down * 0.12f, dt)

        val torsoPitch = heroLean * moving + braking * 0.055f - runBlend * 0.035f +
            dash * 0.15f + hit * 0.14f + down * 0.48f - respawn * 0.20f +
            action * 0.035f + idleBreath
        animateHeroBone("pelvis", turnLean * 0.16f + stride * 0.025f, dt)
        animateHeroBone("spine_01", 0.015f + torsoPitch, dt)
        animateHeroBone("spine_02", -0.012f - torsoPitch * 0.32f - turnLean * 0.16f, dt)
        animateHeroBone("spine_03", -torsoPitch * 0.18f + turnLean * 0.38f, dt)
        animateHeroBone("neck_01", -torsoPitch * 0.22f - turnLean * 0.20f, dt)
        animateHeroBone("Head", -torsoPitch * 0.18f - turnLean * 0.18f, dt)
    }

    private fun animateHeroArmBone(name: String, targetAngle: Float, dt: Float) {
        val bone = bones[name] ?: return
        val current = heroPoseAngles[name] ?: targetAngle
        val blend = (1f - kotlin.math.exp(-dt * 17f)).coerceIn(0f, 1f)
        val next = current + (targetAngle - current) * blend
        heroPoseAngles[name] = next
        animatePose(bone, HumanoidRigPose.localFlexion(next, bone.lateralSign), HumanoidRigPose.FLEXION_AXIS)
    }

    private fun animateHeroBone(name: String, targetAngle: Float, dt: Float, axis: Int = 0) {
        val bone = bones[name] ?: return
        val current = heroPoseAngles[name] ?: targetAngle
        val blend = (1f - kotlin.math.exp(-dt * 17f)).coerceIn(0f, 1f)
        val next = current + (targetAngle - current) * blend
        heroPoseAngles[name] = next
        animatePose(bone, next, axis)
    }
    private fun kLaneX(lane: Int): Float = when (lane) {
        0 -> -12f
        1 -> 0f
        else -> 12f
    }

    private fun setMinionTransform(index: Int, x: Float, z: Float, yaw: Float) {
        val root = minionRootInstances.getOrNull(index) ?: return
        if (root == 0) return
        val slot = (index % 8) % 4
        // Four readable lane-unit silhouettes: compact guard, balanced scout,
        // tall support and slender ranged class. Team tint remains independent.
        val width = when (slot) { 0 -> 1.16f; 1 -> 0.98f; 2 -> 0.88f; else -> 0.78f }
        val height = when (slot) { 0 -> 0.92f; 1 -> 1.02f; 2 -> 1.10f; else -> 1.18f }
        val scaleX = characterScale * minionScale * width
        val scaleY = characterScale * minionScale * height
        val y = terrainHeight(x, z) - characterMinY * scaleY
        engine.transformManager.setTransform(root,
            terrainAlignedTransform(x, z, yaw, scaleX, scaleY, y))
    }

    private fun applyBotTint(index: Int, disabled: Boolean) {
        val team = if (index < 4) 0 else 1
        val variant = index % 4
        val tint = when {
            disabled -> floatArrayOf(0.36f, 0.39f, 0.40f, 1f)
            team == 0 && variant == 0 -> floatArrayOf(0.18f, 0.42f, 0.72f, 1f)
            team == 0 && variant == 1 -> floatArrayOf(0.20f, 0.58f, 0.76f, 1f)
            team == 0 && variant == 2 -> floatArrayOf(0.24f, 0.52f, 0.62f, 1f)
            team == 0 -> floatArrayOf(0.30f, 0.60f, 0.78f, 1f)
            variant == 0 -> floatArrayOf(0.68f, 0.22f, 0.18f, 1f)
            variant == 1 -> floatArrayOf(0.80f, 0.32f, 0.20f, 1f)
            variant == 2 -> floatArrayOf(0.62f, 0.24f, 0.28f, 1f)
            else -> floatArrayOf(0.80f, 0.38f, 0.25f, 1f)
        }
        botMaterialSets.getOrNull(index).orEmpty().forEach { material ->
            runCatching {
                material.setParameter("baseColorFactor", Colors.RgbaType.SRGB, tint[0], tint[1], tint[2], tint[3])
            }.onFailure { error -> Log.w(TAG, "Bot tint update failed for $index", error) }
        }
    }

    private fun setRingTransform(root: Int, x: Float, y: Float, z: Float, scale: Float) {
        if (root == 0) return
        engine.transformManager.setTransform(root, floatArrayOf(
            scale, 0f, 0f, 0f,
            0f, 1f, 0f, 0f,
            0f, 0f, scale, 0f,
            x, y, z, 1f
        ))
    }

    fun updateStructures(snapshot: FloatArray) {
        if (!sceneLoaded || snapshot.size < 125) return
        val transforms = engine.transformManager
        for (index in 0 until 18) {
            val root = towerRootInstances[index]
            val base = towerBaseTransforms[index] ?: continue
            if (root == 0) continue
            val destroyed = snapshot[107 + index] <= 0f
            if (towerHidden[index] == destroyed) continue
            val matrix = base.copyOf()
            if (destroyed) {
                for (element in intArrayOf(0, 1, 2, 4, 5, 6, 8, 9, 10)) matrix[element] *= 0.001f
            }
            transforms.setTransform(root, matrix)
            towerHidden[index] = destroyed
        }
    }

    fun updateEffects(snapshot: FloatArray) {
        if (!sceneLoaded || snapshot.size < 72) return
        val x = snapshot[0]
        val y = terrainHeight(x, snapshot[2]) + 0.095f
        val z = snapshot[2]
        val pulseRemaining = snapshot[61].coerceAtLeast(0f)
        if (pulseRemaining > 0.01f) {
            val progress = (1f - pulseRemaining / 0.68f).coerceIn(0f, 1f)
            setRingTransform(pulseRingRoot, x, y + 0.015f, z, 0.75f + progress * 6.0f)
        } else {
            setRingTransform(pulseRingRoot, x, y, z, 0.001f)
        }
        val shieldActive = snapshot[7] > 0.01f
        setRingTransform(shieldRingRoot, x, y + 0.025f, z, if (shieldActive) 1.55f else 0.001f)
    }

    fun setMinionsVisible(visible: Boolean) {
        if (!sceneLoaded || minionsVisible == visible) return
        if (visible) {
            minionInstances.forEachIndexed { index, instance ->
                if (minionAlive[index]) viewer.scene.addEntities(instance.entities)
            }
        } else {
            minionInstances.forEach { viewer.scene.removeEntities(it.entities) }
        }
        minionsVisible = visible
    }

    fun setBotsVisible(visible: Boolean) {
        if (!sceneLoaded || botsVisible == visible) return
        botInstances.forEach { instance ->
            if (visible) viewer.scene.addEntities(instance.entities)
            else viewer.scene.removeEntities(instance.entities)
        }
        botGearInstances.filterNotNull().forEach { instance ->
            if (visible) viewer.scene.addEntities(instance.entities)
            else viewer.scene.removeEntities(instance.entities)
        }
        botsVisible = visible
    }

    fun setMenuPresentation(hero: Int, alternateSkin: Boolean = false) {
        configureShowcase(hero, alternateSkin, heroX = ArenaShowcaseLayout.HERO_X, targetX = ArenaShowcaseLayout.TARGET_X, scale = ArenaShowcaseLayout.MENU_SCALE)
    }

    fun setHeroSelectionPresentation(hero: Int) {
        configureShowcase(hero, false, heroX = ArenaShowcaseLayout.HERO_X, targetX = ArenaShowcaseLayout.TARGET_X, scale = ArenaShowcaseLayout.SELECT_SCALE)
    }

    private fun configureShowcase(
        hero: Int,
        alternateSkin: Boolean,
        heroX: Float,
        targetX: Float,
        scale: Float
    ) {
        if (!sceneLoaded) return
        setBotsVisible(false)
        setMinionsVisible(false)
        resetHeroAnimationState()
        setHeroAppearance(hero, alternateSkin)
        showcaseMode = true
        overviewCamera = true
        showcaseHeroX = heroX
        showcaseHeroZ = ArenaShowcaseLayout.HERO_Z
        showcaseTargetX = targetX
        showcaseScale = scale
        showcaseHeight = if (scale > 1.17f) ArenaShowcaseLayout.SELECT_CAMERA_HEIGHT else ArenaShowcaseLayout.MENU_CAMERA_HEIGHT
        showcaseDistance = if (scale > 1.17f) ArenaShowcaseLayout.SELECT_CAMERA_DISTANCE else ArenaShowcaseLayout.MENU_CAMERA_DISTANCE
        showcaseYaw = HeroFacing.SHOWCASE_YAW
        playerYaw = showcaseYaw
        val scaled = characterScale * showcaseScale
        val rootY = terrainHeight(showcaseHeroX, showcaseHeroZ) - characterMinY * scaled
        engine.transformManager.setTransform(
            characterRootInstance,
            terrainAlignedTransform(showcaseHeroX, showcaseHeroZ, showcaseYaw, scaled, scaled, rootY)
        )
        updateCamera(cameraAspect)
    }

    fun updateMenuPresentation(deltaTime: Float) {
        if (!sceneLoaded || !showcaseMode) return
        val dt = deltaTime.coerceIn(0f, 0.05f)
        if (dt <= 0f) return
        animationClock += dt
        updateLivingWorld(dt, showcaseHeroX, showcaseHeroZ)
        updateHeroPose(0f, 0f, 0f, 0f, dt)
        val scaled = characterScale * showcaseScale
        val bob = sin(animationClock * 1.35f) * 0.018f
        showcaseYaw = HeroFacing.SHOWCASE_YAW + sin(animationClock * 0.42f) * 0.14f
        val rootY = terrainHeight(showcaseHeroX, showcaseHeroZ) + bob - characterMinY * scaled
        engine.transformManager.setTransform(
            characterRootInstance,
            terrainAlignedTransform(showcaseHeroX, showcaseHeroZ, showcaseYaw, scaled, scaled, rootY)
        )
        animatePlayableHero(0f)
    }

    fun updateCreeps(snapshot: FloatArray, deltaTime: Float) {
        if (!sceneLoaded || snapshot.size < 318) return
        updateLivingWorld(deltaTime, snapshot[0], snapshot[2], snapshot)
        minionAnimationPhase += deltaTime * 7.2f
        for (index in minionInstances.indices) {
            val alive = snapshot[222 + index] > 0.0f
            if (minionAlive[index] != alive) {
                if (alive) viewer.scene.addEntities(minionInstances[index].entities)
                else viewer.scene.removeEntities(minionInstances[index].entities)
                minionAlive[index] = alive
                minionLastPositions[index][0] = Float.NaN
                minionLastPositions[index][1] = Float.NaN
            }
            if (!alive) continue
            val x = snapshot[126 + index * 2]
            val z = snapshot[127 + index * 2]
            val previous = minionLastPositions[index]
            val dx = if (previous[0].isNaN()) 0f else x - previous[0]
            val dz = if (previous[1].isNaN()) 0f else z - previous[1]
            val speed = if (deltaTime > 0f) kotlin.math.sqrt(dx * dx + dz * dz) / deltaTime else 0f
            val moving = (speed / 2.55f).coerceIn(0f, 1f)
            val team = if (index < 24) 0 else 1
            val yaw = if (moving > 0.08f) kotlin.math.atan2(dx, dz)
                else if (team == 0) 0f else Math.PI.toFloat()
            setMinionTransform(index, x, z, yaw)
            val rig = minionBones.getOrNull(index).orEmpty()
            val stride = sin(minionAnimationPhase + index * 0.37f) * moving
            val idle = sin(minionAnimationPhase * 0.58f + index * 0.6f)
            val slot = (index % 8) % 4
            val kneeLift = if (slot == 3) 0.38f else 0.46f
            val rangedReady = if (slot == 3) 0.48f else 0.54f
            animateArmPose(rig["upperarm_l"], rangedReady - stride * 0.28f + idle * 0.025f)
            animateArmPose(rig["upperarm_r"], rangedReady + stride * 0.28f - idle * 0.025f)
            animateArmPose(rig["lowerarm_l"], if (slot == 3) 0.34f else 0.30f + max(0f, stride) * 0.08f)
            animateArmPose(rig["lowerarm_r"], if (slot == 3) 0.38f else 0.32f + max(0f, -stride) * 0.08f)
            animateArmPose(rig["hand_l"], stride * 0.025f)
            animateArmPose(rig["hand_r"], stride * 0.025f)
            animatePose(rig["pelvis"], sin(minionAnimationPhase * 2f + index) * 0.022f * moving, 2)
            animatePose(rig["thigh_l"], stride * 0.60f)
            animatePose(rig["thigh_r"], -stride * 0.60f)
            animatePose(rig["calf_l"], max(0f, -stride) * kneeLift)
            animatePose(rig["calf_r"], max(0f, stride) * kneeLift)
            animatePose(rig["foot_l"], -max(0f, -stride) * 0.20f)
            animatePose(rig["foot_r"], -max(0f, stride) * 0.20f)
            animatePose(rig["spine_01"], idle * 0.014f + moving * 0.025f)
            animatePose(rig["spine_02"], -idle * 0.010f)
            animatePose(rig["spine_03"], sin(minionAnimationPhase * 1.9f + index) * 0.012f * moving)
            animatePose(rig["neck_01"], -idle * 0.012f)
            animatePose(rig["Head"], -idle * 0.018f)
            minionAnimators.getOrNull(index)?.updateBoneMatrices()
            previous[0] = x
            previous[1] = z
        }
    }

    fun updateBots(snapshot: FloatArray, deltaTime: Float) {
        if (!sceneLoaded || snapshot.size < 34) return
        val transforms = engine.transformManager
        botAnimationPhase += deltaTime * 8.0f
        for (index in botRootInstances.indices) {
            val rootInstance = botRootInstances[index]
            if (rootInstance == 0) continue
            val x = snapshot[16 + index * 2]
            val z = snapshot[17 + index * 2]
            val previous = lastBotPositions[index]
            val dx = if (previous[0].isNaN()) 0f else x - previous[0]
            val dz = if (previous[1].isNaN()) 0f else z - previous[1]
            val speed = if (deltaTime > 0f) kotlin.math.sqrt(dx * dx + dz * dz) / deltaTime else 0f
            val moving = (speed / 2.7f).coerceIn(0f, 1f)
            val desiredYaw = if (moving > 0.08f) kotlin.math.atan2(dx, dz)
                else if (index < 4) 0f else Math.PI.toFloat()
            var turnLean = 0f
            if (!botYawInitialized[index]) {
                botYawState[index] = desiredYaw
                botYawInitialized[index] = true
            } else {
                val error = kotlin.math.atan2(
                    sin(desiredYaw - botYawState[index]),
                    cos(desiredYaw - botYawState[index])
                )
                turnLean = (error / (deltaTime.coerceAtLeast(0.001f)) / 5.5f).coerceIn(-1f, 1f)
                botYawState[index] += error * (1f - kotlin.math.exp(-deltaTime * 11f))
            }
            val yaw = botYawState[index]
            val role = if (snapshot.size >= 308) snapshot[299 + index].toInt().coerceIn(0, 4) else index % 5
            // Role-based body proportions: solo is grounded, jungle agile, carry lighter, support balanced.
            val widthFactor = when (role) { 0 -> 1.16f; 1 -> 0.88f; 2 -> 1.0f; 3 -> 0.90f; else -> 0.97f }
            val heightFactor = when (role) { 0 -> 0.96f; 1 -> 1.05f; 2 -> 1.0f; 3 -> 1.06f; else -> 1.01f }
            val scaleX = characterScale * botScale * widthFactor
            val scaleY = characterScale * botScale * heightFactor
            val y = terrainHeight(x, z) - characterMinY * scaleY
            val matrix = terrainAlignedTransform(x, z, yaw, scaleX, scaleY, y)
            transforms.setTransform(rootInstance, matrix)

            val rig = botBones.getOrNull(index).orEmpty()
            val cadence = when (role) { 0 -> 0.82f; 1 -> 1.22f; 2 -> 1.04f; 3 -> 1.16f; else -> 0.90f }
            val armDrive = when (role) { 0 -> 0.24f; 1 -> 0.38f; 2 -> 0.30f; 3 -> 0.42f; else -> 0.20f }
            val stride = sin(botAnimationPhase * cadence + index * 0.41f) * moving
            val idle = sin(botAnimationPhase * (0.48f + role * 0.07f) + index * 0.43f)
            val braking = smoothStep01((2.0f - speed) / 2.0f) * moving
            val readyPose = when (role) { 0 -> 0.56f; 1 -> 0.50f; 2 -> 0.54f; 3 -> 0.60f; else -> 0.52f }
            animateArmPose(rig["upperarm_l"], readyPose - stride * armDrive - turnLean * 0.05f)
            animateArmPose(rig["upperarm_r"], readyPose + stride * armDrive - turnLean * 0.05f)
            val elbow = when (role) { 0 -> 0.36f; 1 -> 0.30f; 2 -> 0.34f; 3 -> 0.42f; else -> 0.32f }
            animateArmPose(rig["lowerarm_l"], elbow + max(0f, stride) * 0.10f)
            animateArmPose(rig["lowerarm_r"], elbow + max(0f, -stride) * 0.10f)
            animateArmPose(rig["hand_l"], stride * 0.035f)
            animateArmPose(rig["hand_r"], stride * 0.035f)
            animatePose(rig["pelvis"], turnLean * 0.055f + sin(botAnimationPhase * 2f + index) * 0.018f * moving, 2)
            animatePose(rig["thigh_l"], stride * 0.60f)
            animatePose(rig["thigh_r"], -stride * 0.60f)
            animatePose(rig["calf_l"], max(0f, -stride) * 0.48f + braking * 0.035f)
            animatePose(rig["calf_r"], max(0f, stride) * 0.48f + braking * 0.035f)
            animatePose(rig["foot_l"], -max(0f, -stride) * 0.20f)
            animatePose(rig["foot_r"], -max(0f, stride) * 0.20f)
            animatePose(rig["spine_01"], 0.012f + idle * 0.014f + moving * 0.025f + braking * 0.055f)
            animatePose(rig["spine_02"], -idle * 0.010f - turnLean * 0.035f)
            animatePose(rig["spine_03"], turnLean * 0.055f + sin(botAnimationPhase + index) * 0.012f * moving)
            animatePose(rig["neck_01"], -idle * 0.013f - turnLean * 0.025f)
            animatePose(rig["Head"], -idle * 0.015f - turnLean * 0.035f)
            val disabled = snapshot.size >= 72 && snapshot[63 + index] > 0.0f
            if (botDisabledState[index] != disabled) {
                applyBotTint(index, disabled)
                botDisabledState[index] = disabled
            }
            botAnimators.getOrNull(index)?.updateBoneMatrices()
            previous[0] = x
            previous[1] = z
        }
    }

    private fun laneCenterX(lane: Int, z: Float): Float =
        ArenaMapDefinition.laneCenterX(lane, z)

    private fun terrainHeight(x: Float, z: Float): Float = WorldGlbBuilder.heightAt(x, z)

    private fun terrainAlignedTransform(
        x: Float, z: Float, yaw: Float, scaleX: Float, scaleY: Float, rootY: Float
    ): FloatArray {
        val normal = WorldGlbBuilder.normalAt(x, z)
        val upX = normal[0]; val upY = normal[1]; val upZ = normal[2]
        var forwardX = sin(yaw); var forwardY = 0f; var forwardZ = cos(yaw)
        val projection = forwardX * upX + forwardY * upY + forwardZ * upZ
        forwardX -= upX * projection
        forwardY -= upY * projection
        forwardZ -= upZ * projection
        val forwardLength = kotlin.math.sqrt(forwardX * forwardX + forwardY * forwardY + forwardZ * forwardZ).coerceAtLeast(0.0001f)
        forwardX /= forwardLength; forwardY /= forwardLength; forwardZ /= forwardLength
        var rightX = upY * forwardZ - upZ * forwardY
        var rightY = upZ * forwardX - upX * forwardZ
        var rightZ = upX * forwardY - upY * forwardX
        val rightLength = kotlin.math.sqrt(rightX * rightX + rightY * rightY + rightZ * rightZ).coerceAtLeast(0.0001f)
        rightX /= rightLength; rightY /= rightLength; rightZ /= rightLength
        forwardX = rightY * upZ - rightZ * upY
        forwardY = rightZ * upX - rightX * upZ
        forwardZ = rightX * upY - rightY * upX
        return floatArrayOf(
            rightX * scaleX, rightY * scaleX, rightZ * scaleX, 0f,
            upX * scaleY, upY * scaleY, upZ * scaleY, 0f,
            forwardX * scaleX, forwardY * scaleX, forwardZ * scaleX, 0f,
            x, rootY, z, 1f
        )
    }

    private fun applyRestPose(rig: Map<String, BonePose>) {
        // Original unarmed idle stance: lowered shoulders, gently bent elbows and a relaxed spine.
        animateArmPose(rig["upperarm_l"], 0.62f)
        animateArmPose(rig["upperarm_r"], 0.62f)
        animateArmPose(rig["lowerarm_l"], 0.28f)
        animateArmPose(rig["lowerarm_r"], 0.28f)
        animatePose(rig["spine_01"], 0.015f)
        animatePose(rig["spine_02"], -0.012f)
        animatePose(rig["neck_01"], 0f)
    }

    private fun animateBone(name: String, angle: Float) {
        animatePose(bones[name], angle, 0)
    }

    private fun animateArmPose(bone: BonePose?, angle: Float) {
        // The shared humanoid rig's arm direction is local +Y, but the shoulder's world-space axis is lateral.
        // Flexion therefore uses local Z; the sign is mirrored so both arms rotate down toward the torso.
        if (bone == null) return
        animatePose(bone, HumanoidRigPose.localFlexion(angle, bone.lateralSign), HumanoidRigPose.FLEXION_AXIS)
    }

    private fun animatePose(bone: BonePose?, angle: Float, axis: Int = 0) {
        if (bone == null) return
        val c = cos(angle)
        val s = sin(angle)
        val rotation = if (axis == 2) floatArrayOf(
            c, s, 0f, 0f,
            -s, c, 0f, 0f,
            0f, 0f, 1f, 0f,
            0f, 0f, 0f, 1f
        ) else floatArrayOf(
            1f, 0f, 0f, 0f,
            0f, c, s, 0f,
            0f, -s, c, 0f,
            0f, 0f, 0f, 1f
        )
        val out = FloatArray(16)
        for (column in 0..3) {
            for (row in 0..3) {
                var value = 0f
                for (k in 0..3) value += bone.base[k * 4 + row] * rotation[column * 4 + k]
                out[column * 4 + row] = value
            }
        }
        engine.transformManager.setTransform(bone.instance, out)
    }

    fun setHeroAppearance(hero: Int, alternateSkin: Boolean = false) {
        activeHero = hero.coerceIn(0, 2)
        activatePlayerModel(activeHero)
        rebuildBotGearForHero()
        // Retain each CC0 source mesh, clothing, hair and original material palette.
        if (alternateSkin) Log.i(TAG, "Alternate skin request does not flatten the authored CC0 material palette")
    }

    fun setOverviewCamera(overview: Boolean) {
        showcaseMode = false
        overviewCamera = overview
        val spawn = when (activeHero) {
            1 -> laneCenterX(0, -25f) to -25f
            2 -> -8.2f to -14.5f
            else -> laneCenterX(2, -25f) + 1.8f to -25f
        }
        if (overview) {
            cameraX = spawn.first
            cameraZ = spawn.second
            cameraY = terrainHeight(cameraX, cameraZ)
            playerYaw = 0.0f
            val rootY = cameraY - characterMinY * characterScale
            val scale = characterScale
            engine.transformManager.setTransform(characterRootInstance,
                terrainAlignedTransform(cameraX, cameraZ, playerYaw, scale, scale, rootY))
        } else {
            cameraX = spawn.first
            cameraZ = spawn.second
            cameraY = terrainHeight(spawn.first, spawn.second)
            yawInitialized = false
        }
        updateCamera(cameraAspect)
    }

    private fun updateCamera(aspect: Float) {
        if (showcaseMode) {
            val targetY = terrainHeight(showcaseTargetX, showcaseHeroZ) + 1.0f
            viewer.camera.setProjection(
                ArenaShowcaseLayout.CAMERA_FOV, aspect.toDouble().coerceAtLeast(0.5), 0.1, 180.0,
                Camera.Fov.VERTICAL
            )
            viewer.camera.lookAt(
                (showcaseTargetX + 2.4f).toDouble(),
                (targetY + showcaseHeight).toDouble(),
                (showcaseHeroZ - showcaseDistance).toDouble(),
                showcaseTargetX.toDouble(), targetY.toDouble(), showcaseHeroZ.toDouble(),
                0.0, 1.0, 0.0
            )
            return
        }
        // Fixed north-facing isometric framing: hero yaw never rotates the camera.
        val distance = if (overviewCamera) 9.4f else 8.3f
        val height = if (overviewCamera) 9.6f else 9.2f
        val fov = if (overviewCamera) 48.0 else 44.0
        viewer.camera.setProjection(
            fov, aspect.toDouble().coerceAtLeast(0.5), 0.1, 180.0,
            Camera.Fov.VERTICAL
        )
        viewer.camera.lookAt(
            cameraX.toDouble(), (cameraY + height).toDouble(), (cameraZ - distance).toDouble(),
            cameraX.toDouble(), (cameraY + 1.0f).toDouble(), cameraZ.toDouble(),
            0.0, 1.0, 0.0
        )
    }

    fun destroy() {
        try {
            botInstances.forEach { viewer.scene.removeEntities(it.entities) }
            botInstances.clear()
            minionInstances.forEach { viewer.scene.removeEntities(it.entities) }
            minionInstances.clear()
            minionAnimators.clear()
            minionBones.clear()
            lifeActors.forEach { actor -> viewer.scene.removeEntities(actor.instance.entities) }
            lifeActors.clear()
            lifeAssets.values.forEach { asset -> characterLoader?.destroyAsset(asset) }
            lifeAssets.clear()
            worldInstances.forEach { viewer.scene.removeEntities(it.entities) }
            worldInstances.clear()
            worldAssets.values.forEach { asset -> worldAssetLoader?.destroyAsset(asset) }
            worldAssets.clear()
            worldResourceLoader?.destroy()
            worldResourceLoader = null
            worldAssetLoader?.destroy()
            worldAssetLoader = null
            worldProvider?.destroy()
            worldProvider = null
            heroGearInstances.forEach { viewer.scene.removeEntities(it.entities) }
            heroGearInstances.clear()
            playerGearInstances.fill(null)
            equippedPlayerGear = -1
            heroGearAssets.forEach { asset -> characterLoader?.destroyAsset(asset) }
            heroGearAssets.clear()
            playableHeroes.forEach { runtime ->
                runtime?.let { hero ->
                    viewer.scene.removeEntities(hero.instance.entities)
                    characterLoader?.destroyAsset(hero.asset)
                }
            }
            playableHeroes.fill(null)
            playerInstance = null
            playerAnimator = null
            playerMaterials.clear()
            botAnimators.clear()
            minionLastPositions.forEach { it[0] = Float.NaN; it[1] = Float.NaN }
            character?.let { asset -> characterLoader?.destroyAsset(asset) }
            character = null
            botBones.clear()
            characterResources?.destroy()
            characterLoader?.destroy()
            characterProvider?.destroy()
            viewer.destroyModel()
            indirectLight?.let { engine.destroy(it) }
            indirectLight = null
            skybox?.let { engine.destroy(it) }
            engine.destroy(viewer.view)
            engine.destroy(viewer.renderer)
            engine.destroy(viewer.scene)
            engine.destroy()
        } catch (error: Throwable) {
            Log.w(TAG, "Renderer cleanup completed with a recoverable warning", error)
        }
    }
}
