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
    private data class NpcCharacterRuntime(
        val instance: FilamentInstance,
        val root: Int,
        val animator: Animator,
        val modelIndex: Int,
        val idleClip: Int,
        val walkClip: Int,
        val runClip: Int,
        val idleDuration: Float,
        val walkDuration: Float,
        val runDuration: Float,
        val scale: Float,
        val minY: Float,
        val materialInstances: List<MaterialInstance>,
        val animationRate: Float,
        var animationClock: Float = 0f,
        var activeClip: Int = -1
    )
    private val playableHeroes = arrayOfNulls<PlayableHeroRuntime>(3)
    private val botVisuals = ArrayList<NpcCharacterRuntime>(9)
    private val minionVisuals = ArrayList<NpcCharacterRuntime>(48)
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
    private val minionRendered = BooleanArray(48) { false }
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
        val attackClip: Int,
        val idleDuration: Float,
        val moveDuration: Float,
        val attackDuration: Float,
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
    private var cameraX = -12f * ArenaMapDefinition.WORLD_SCALE
    private var cameraZ = -8.5f * ArenaMapDefinition.WORLD_SCALE
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

        // Neutral outdoor palette: cool sky fill and a soft, slightly warm sun.
        skybox = Skybox.Builder()
            .color(floatArrayOf(0.36f, 0.47f, 0.54f, 1f))
            .build(engine)
        viewer.scene.skybox = skybox
        indirectLight = IndirectLight.Builder()
            .irradiance(1, floatArrayOf(0.18f, 0.21f, 0.24f))
            .intensity(9_500.0f)
            .build(engine)
        viewer.scene.indirectLight = indirectLight

        // ModelViewer already creates a shadow-capable SUN. Tune that single light
        // instead of adding another directional source to the mobile render path.
        val lightManager = engine.lightManager
        lightManager.setDirection(viewer.light, -0.36f, -0.86f, -0.36f)
        lightManager.setColor(viewer.light, 1.0f, 0.97f, 0.92f)
        lightManager.setIntensity(viewer.light, 62_000.0f)
        val sunInstance = lightManager.getInstance(viewer.light)
        if (sunInstance != 0) {
            val shadowOptions = lightManager.getShadowOptions(sunInstance)
            shadowOptions.mapSize = 1024
            shadowOptions.shadowCascades = 1
            shadowOptions.stable = true
            shadowOptions.maxShadowDistance = 56.0f
            lightManager.setShadowOptions(sunInstance, shadowOptions)
            lightManager.setShadowCaster(sunInstance, true)
        }
        viewer.view.setShadowingEnabled(true)
        viewer.view.setShadowType(View.ShadowType.PCF)

        // Half-resolution SAO adds contact depth at a bounded mobile cost.
        viewer.view.setAmbientOcclusionOptions(View.AmbientOcclusionOptions().apply {
            enabled = true
            aoType = View.AmbientOcclusionOptions.AmbientOcclusionType.SAO
            radius = 0.42f
            power = 1.08f
            bias = 0.001f
            resolution = 0.5f
            intensity = 0.62f
            quality = View.QualityLevel.LOW
            lowPassFilter = View.QualityLevel.LOW
            upsampling = View.QualityLevel.LOW
        })
        // A restrained distance haze separates the far tree line without obscuring lanes.
        viewer.view.setFogOptions(View.FogOptions().apply {
            distance = 25.0f
            cutOffDistance = 94.0f
            maximumOpacity = 0.16f
            height = 0.0f
            heightFalloff = 0.045f
            color = floatArrayOf(0.55f, 0.63f, 0.67f)
            density = 0.0026f
            enabled = true
        })
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
        Log.i(TAG, "Startup stage: baked CC0 groundcover and rock environment")
        loadBakedNatureEnvironment()
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

    private fun configureAssetShadowing(
        entities: IntArray,
        castsShadows: Boolean,
        receivesShadows: Boolean
    ) {
        val renderables = engine.renderableManager
        for (entity in entities) {
            val instance = renderables.getInstance(entity)
            if (instance != 0) {
                renderables.setCastShadows(instance, castsShadows)
                renderables.setReceiveShadows(instance, receivesShadows)
            }
        }
    }

    private fun loadWorld() {
        val terrainDirectory = "world/terrain/"
        fun readTerrainMap(name: String): ByteArray =
            context.assets.open(terrainDirectory + name).use { it.readBytes() }
        val terrainTextures = TerrainTextureSet(
            albedo = listOf(
                readTerrainMap("grass_albedo.png"),
                readTerrainMap("moss_albedo.png"),
                readTerrainMap("soil_albedo.png"),
                readTerrainMap("rock_albedo.png")
            ),
            normal = listOf(
                readTerrainMap("grass_normal.png"),
                readTerrainMap("moss_normal.png"),
                readTerrainMap("soil_normal.png"),
                readTerrainMap("rock_normal.png")
            )
        )
        val world = WorldGlbBuilder.build(terrainTextures)
        viewer.loadModelGlb(ByteBuffer.wrap(world))
        val asset = viewer.asset ?: error("MOBA world GLB failed to load")
        // The terrain is a receiver, not a shadow caster; static props cast onto it.
        configureAssetShadowing(asset.entities, castsShadows = false, receivesShadows = true)
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
            "bridge_a"
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

        val natureModels = listOf(
            "nature_tree_oak" to "world/nature/tree_oak.glb.b64",
            "nature_tree_pine" to "world/nature/tree_pine.glb.b64",
            "nature_tree_broadleaf" to "world/nature/tree_broadleaf.glb.b64",
            "nature_bush" to "world/nature/bush_common.glb.b64"
        )
        for ((name, path) in natureModels) {
            val encoded = context.assets.open(path).bufferedReader().use { it.readText() }
            val bytes = Base64.decode(encoded, Base64.DEFAULT)
            val asset = worldAssetLoader!!.createAsset(ByteBuffer.wrap(bytes))
                ?: throw IllegalStateException("Quaternius CC0 nature GLB failed to parse: $name")
            check(asset.resourceUris.isEmpty()) {
                "Nature model must be self-contained for offline packaging: $name"
            }
            worldResourceLoader!!.loadResources(asset)
            worldAssets[name] = asset
        }

        val placements = buildList {
            val mapScale = ArenaMapDefinition.WORLD_SCALE
            ArenaWorld17Generated.bases.forEach { base ->
                val team = base.team
                val castle = if (team == 0) "castle_blue" else "castle_red"
                val home = if (team == 0) "home_blue" else "home_red"
                val church = if (team == 0) "church_blue" else "church_red"
                val yaw = if (team == 0) 0f else Math.PI.toFloat()
                add(WorldPlacement(castle, base.position.x, base.position.z, 1.0f, yaw))
                base.gates.forEach { gate ->
                    add(WorldPlacement(home, gate.position.x, gate.position.z, 1.28f, yaw))
                }
                add(WorldPlacement(church, base.position.x + 9.0f, base.position.z, 1.18f, yaw))
            }

            // Tower transforms are generated from the canonical battlefield catalog.
            for (team in 0..1) {
                for (lane in 0..2) {
                    for (tier in 0..2) {
                        val point = ArenaMapDefinition.towerPosition(team, lane, tier)
                        val model = if (team == 0) "tower_blue" else "tower_red"
                        val yaw = if (team == 0) 0f else Math.PI.toFloat()
                        add(WorldPlacement(model, point.x * mapScale, point.z * mapScale, 1.48f, yaw))
                    }
                }
            }
            ArenaWorld17Generated.crossings.forEach { crossing ->
                val lane = ArenaWorld17Generated.lanes.first { it.id == crossing.laneId }
                val nearest = lane.waypoints.indices.minByOrNull { index ->
                    val point = lane.waypoints[index]
                    val dx = point.x - crossing.position.x
                    val dz = point.z - crossing.position.z
                    dx * dx + dz * dz
                } ?: 0
                val before = lane.waypoints[(nearest - 1).coerceAtLeast(0)]
                val after = lane.waypoints[(nearest + 1).coerceAtMost(lane.waypoints.lastIndex)]
                val yaw = kotlin.math.atan2(after.x - before.x, after.z - before.z)
                add(WorldPlacement(
                    "bridge_a", crossing.position.x, crossing.position.z,
                    (crossing.deckWidth / 4.8f).coerceIn(1.85f, 2.25f), yaw
                ))
            }
            ArenaNatureCatalog.trees.forEach { tree ->
                add(WorldPlacement(tree.model, tree.x * mapScale, tree.z * mapScale,
                    tree.scale, tree.yaw))
            }
            ArenaNatureCatalog.bushes.forEach { bush ->
                add(WorldPlacement("nature_bush", bush.x * mapScale, bush.z * mapScale,
                    bush.scale, bush.yaw))
            }
        }

        val transforms = engine.transformManager
        for (placement in placements) {
            val asset = worldAssets[placement.model]
                ?: throw IllegalStateException("Missing imported KayKit asset: ${placement.model}")
            val instance = worldAssetLoader!!.createInstance(asset)
                ?: throw IllegalStateException("Could not instance KayKit model: ${placement.model}")
            worldInstances.add(instance)
            configureAssetShadowing(
                instance.entities,
                castsShadows = placement.model != "nature_bush",
                receivesShadows = true
            )
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
                val tower = (0..2).flatMap { lane ->
                    (0..2).map { tier ->
                        val point = ArenaMapDefinition.towerPosition(team, lane, tier)
                        Triple(lane, tier, point)
                    }
                }.minByOrNull { candidate ->
                    val dx = candidate.third.x - placement.x
                    val dz = candidate.third.z - placement.z
                    dx * dx + dz * dz
                } ?: Triple(1, 1, ArenaMapDefinition.towerPosition(team, 1, 1))
                val towerIndex = team * 9 + tower.first * 3 + tower.second
                towerRootInstances[towerIndex] = root
                towerBaseTransforms[towerIndex] = matrix.copyOf()
                towerHidden[towerIndex] = false
            }
        }

        worldAssets.values.forEach { it.releaseSourceData() }
        Log.i(TAG, "KayKit CC0 environment loaded: ${worldAssets.size} models, ${worldInstances.size} placements")
    }

    /** Loads two pre-baked static meshes; each packs all placements by texture/material. */
    private fun loadBakedNatureEnvironment() {
        val loader = worldAssetLoader ?: error("World AssetLoader is unavailable for baked nature")
        val resources = worldResourceLoader ?: error("World ResourceLoader is unavailable for baked nature")
        for (name in listOf("forest_groundcover", "forest_rocks")) {
            val bytes = context.assets.open("world/nature/$name.glb").use { it.readBytes() }
            val asset = loader.createAsset(ByteBuffer.wrap(bytes))
                ?: throw IllegalStateException("Filament rejected baked nature GLB: $name")
            check(asset.resourceUris.isEmpty()) {
                "Baked nature GLB must embed all textures for offline loading: $name"
            }
            resources.loadResources(asset)
            val instance = loader.createInstance(asset)
                ?: throw IllegalStateException("Could not instance baked nature GLB: $name")
            worldAssets[name] = asset
            worldInstances.add(instance)
            configureAssetShadowing(
                instance.entities,
                castsShadows = name == "forest_rocks",
                receivesShadows = true
            )
            viewer.scene.addEntities(instance.entities)
            asset.releaseSourceData()
            Log.i(TAG, "Baked nature loaded: " + name + ", bytes=" + bytes.size + ", entities=" + instance.entities.size)
        }
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
                // Resolve semantic idle, locomotion and optional guardian-attack clips.
                // Missing source clips fall back to deterministic root motion.
                val idleClip = findClip(profile.idleTokens)
                val moveClip = findClip(profile.moveTokens).let { if (it >= 0) it else idleClip }
                val attackClip = findClip(profile.attackTokens)
                val idleDuration = if (idleClip >= 0) animator.getAnimationDuration(idleClip).coerceAtLeast(0.1f) else 1f
                val moveDuration = if (moveClip >= 0) animator.getAnimationDuration(moveClip).coerceAtLeast(0.1f) else 1f
                val attackDuration = if (attackClip >= 0) animator.getAnimationDuration(attackClip).coerceAtLeast(0.1f) else 0.5f
                val actor = LifeActorRuntime(
                    spawn, instance, root, animator, scale, minY,
                    idleClip, moveClip, attackClip, idleDuration, moveDuration, attackDuration
                )
                lifeActors.add(actor)
                // Actors enter the scene only when the current view/player range needs them.
                actor.visible = false
                val sample = ArenaLifeCatalog.sample(spawn, spawn.phase, spawn.x + 30f, spawn.z + 30f)
                val worldX = sample.x * ArenaMapDefinition.WORLD_SCALE
                val worldZ = sample.z * ArenaMapDefinition.WORLD_SCALE
                val y = terrainHeight(worldX, worldZ) + profile.airHeight + sample.heightOffset - minY * scale
                transforms.setTransform(root, terrainAlignedTransform(
                    worldX, worldZ, sample.yaw + profile.yawOffset, scale, scale, y
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
                snapshot?.getOrNull(ArenaSnapshotLayout.campHealth(spawn.campIndex))?.let { it > 0f } ?: true
            } else true
            // Cull against the actor's current path position, not its original anchor.
            // A moving animal may have wandered several metres from its spawn point.
            val mapScale = ArenaMapDefinition.WORLD_SCALE
            val sample = ArenaLifeCatalog.sample(spawn, lifeClock, playerX / mapScale, playerZ / mapScale)
            val worldX = sample.x * mapScale
            val worldZ = sample.z * mapScale
            val dx = worldX - playerX
            val dz = worldZ - playerZ
            val maxDistance = (if (spawn.kind == LifeActorKind.CAMP_GUARDIAN) 31f else 36f) * mapScale
            val inRange = dx * dx + dz * dz <= maxDistance * maxDistance
            val shouldShow = campAlive && inRange
            if (actor.visible != shouldShow) {
                if (shouldShow) viewer.scene.addEntities(actor.instance.entities)
                else viewer.scene.removeEntities(actor.instance.entities)
                actor.visible = shouldShow
            }
            if (!shouldShow) continue

            val profile = ArenaLifeCatalog.species.getValue(spawn.species)
            val attacking = spawn.kind == LifeActorKind.CAMP_GUARDIAN &&
                snapshot?.getOrNull(ArenaSnapshotLayout.campAttackPulse(spawn.campIndex))?.let { it > 0f } == true
            val usingAttackClip = attacking && actor.attackClip >= 0
            val usingMoveClip = !usingAttackClip && sample.moving
            val clip = when {
                usingAttackClip -> actor.attackClip
                usingMoveClip -> actor.moveClip
                else -> actor.idleClip
            }
            if (clip >= 0) {
                val duration = when {
                    usingAttackClip -> actor.attackDuration
                    usingMoveClip -> actor.moveDuration
                    else -> actor.idleDuration
                }
                val offset = when {
                    usingAttackClip -> spawn.phase * 0.19f
                    usingMoveClip -> spawn.phase * 0.37f
                    else -> spawn.phase
                }
                actor.animator.applyAnimation(clip, (lifeClock + offset) % duration)
            }
            val proceduralAttack = attacking && actor.attackClip < 0
            val attackSway = if (proceduralAttack) kotlin.math.sin(lifeClock * 15f + spawn.phase) * 0.20f else 0f
            val attackLift = if (proceduralAttack) kotlin.math.abs(kotlin.math.sin(lifeClock * 17f + spawn.phase)) * 0.11f else 0f
            val y = terrainHeight(worldX, worldZ) + profile.airHeight + sample.heightOffset +
                attackLift - actor.minY * actor.scale
            transforms.setTransform(actor.root, terrainAlignedTransform(
                worldX, worldZ, sample.yaw + profile.yawOffset + attackSway,
                actor.scale, actor.scale, y
            ))
            if (clip >= 0) actor.animator.updateBoneMatrices()
        }
    }

    private fun loadCharacter() {
        characterProvider = UbershaderProvider(engine)
        characterLoader = AssetLoader(engine, characterProvider!!, EntityManager.get())
        characterResources = ResourceLoader(engine)

        // Playable heroes, bots and minions now share three genuine CC0 human
        // character assets with their own materials and authored locomotion clips.
        loadPlayableHeroModels()
        createNpcVisualsFromPlayableHeroes()
        activatePlayerModel(0)
        playableHeroes.filterNotNull().forEach { it.asset.releaseSourceData() }
        Log.i(TAG, "Three CC0 hero bodies drive player, 9 AI heroes and 48 animated lane units")
    }

    private fun createNpcVisualsFromPlayableHeroes() {
        val loader = characterLoader ?: error("NPC asset loader is unavailable")
        val transforms = engine.transformManager

        fun createNpc(modelIndex: Int, owner: String, animationRate: Float): NpcCharacterRuntime {
            val hero = playableHeroes.getOrNull(modelIndex)
                ?: error("$owner requires unavailable hero model $modelIndex")
            val instance = loader.createInstance(hero.asset)
                ?: throw IllegalStateException("Could not instance $owner from ${hero.definition.id}")
            configureAssetShadowing(instance.entities, castsShadows = false, receivesShadows = true)
            val root = transforms.getInstance(instance.root)
            check(root != 0) { "$owner has no root transform" }
            return NpcCharacterRuntime(
                instance = instance,
                root = root,
                animator = instance.animator,
                modelIndex = modelIndex,
                idleClip = hero.idleClip,
                walkClip = hero.walkClip,
                runClip = hero.runClip,
                idleDuration = hero.idleDuration,
                walkDuration = hero.walkDuration,
                runDuration = hero.runDuration,
                scale = hero.scale,
                minY = hero.minY,
                materialInstances = instance.materialInstances.toList(),
                animationRate = animationRate
            )
        }

        for (index in 0 until 9) {
            val modelIndex = NpcVisualCatalog.botModel(index)
            val team = if (index < 4) 0 else 1
            val actor = createNpc(modelIndex, "bot-$index", 0.94f + (index % 4) * 0.045f)
            botVisuals.add(actor)
            botInstances.add(actor.instance)
            botAnimators.add(actor.animator)
            botMaterialSets.add(actor.materialInstances)
            botRootInstances[index] = actor.root
            applyNpcMaterialPalette(actor, team, index % 4, disabled = false)
            viewer.scene.addEntities(actor.instance.entities)
            animateNpc(actor, speed = 0f, deltaTime = 0f, phaseOffset = index * 0.13f)
        }

        for (index in 0 until 48) {
            val modelIndex = NpcVisualCatalog.minionModel(index)
            val team = if (index < 24) 0 else 1
            val variation = NpcVisualCatalog.minionSlot(index)
            val actor = createNpc(modelIndex, "minion-$index", 0.92f + variation * 0.055f)
            minionVisuals.add(actor)
            minionInstances.add(actor.instance)
            minionAnimators.add(actor.animator)
            minionRootInstances[index] = actor.root
            applyNpcMaterialPalette(actor, team, variation, disabled = false)
            animateNpc(actor, speed = 0f, deltaTime = 0f, phaseOffset = index * 0.071f)
        }

        // Keep the original lane/team spawn layout; only the visual bodies and
        // animation sources change in this pass.
        for (index in minionRootInstances.indices) {
            val team = if (index < 24) 0 else 1
            val local = index % 24
            val lane = local / 8
            val localInLane = local % 8
            val slot = localInLane % 4
            val group = localInLane / 4
            val mapScale = ArenaMapDefinition.WORLD_SCALE
            val z = (if (team == 0) -68f - group * 1.25f else 68f + group * 1.25f) * mapScale
            val side = when (slot) { 0 -> -0.86f; 1 -> 0f; 2 -> 0.86f; else -> 1.45f } * mapScale
            setMinionTransform(index, laneCenterX(lane, z) + side, z, if (team == 0) 0f else Math.PI.toFloat())
        }
        Log.i(TAG, "NPC visual roster ready: bots=${botVisuals.size}/9, minions=${minionVisuals.size}/48, CC0 bodies=3")
    }

    private fun applyNpcMaterialPalette(
        actor: NpcCharacterRuntime,
        team: Int,
        variation: Int,
        disabled: Boolean
    ) {
        val palette = HeroMaterialPalette.forNpc(actor.modelIndex, team, variation, disabled)
        actor.materialInstances.forEach { material ->
            val color = HeroMaterialPalette.colorForMaterial(material.name, palette) ?: return@forEach
            runCatching {
                material.setParameter(
                    "baseColorFactor", Colors.RgbaType.SRGB,
                    color.r, color.g, color.b, color.a
                )
            }.onFailure { error ->
                Log.w(TAG, "NPC material update failed: ${material.name}", error)
            }
        }
    }

    private fun animateNpc(
        actor: NpcCharacterRuntime,
        speed: Float,
        deltaTime: Float,
        phaseOffset: Float
    ) {
        val selected = when (NpcVisualCatalog.locomotion(speed)) {
            NpcLocomotion.IDLE -> actor.idleClip to actor.idleDuration
            NpcLocomotion.WALK -> actor.walkClip to actor.walkDuration
            NpcLocomotion.RUN -> actor.runClip to actor.runDuration
        }
        val clip = selected.first
        val duration = selected.second.coerceAtLeast(0.01f)
        if (actor.activeClip != clip) {
            actor.activeClip = clip
            actor.animationClock = phaseOffset % duration
        }
        actor.animationClock = (actor.animationClock + deltaTime.coerceIn(0f, 0.05f) * actor.animationRate) % duration
        actor.animator.applyAnimation(clip, actor.animationClock)
        actor.animator.updateBoneMatrices()
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
                configureAssetShadowing(instance.entities, castsShadows = true, receivesShadows = true)
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
        val applied = HashSet<String>()
        playerMaterials.forEach { material ->
            val key = HeroMaterialPalette.normalizeMaterialName(material.name)
            val color = HeroMaterialPalette.colorForMaterial(material.name, palette) ?: return@forEach
            runCatching {
                material.setParameter(
                    "baseColorFactor", Colors.RgbaType.SRGB,
                    color.r, color.g, color.b, color.a
                )
                applied.add(key)
            }.onFailure { error ->
                Log.w(TAG, "Could not apply hero palette: hero=$hero material=${material.name}", error)
            }
        }
        val missing = palette.keys - applied
        if (missing.isNotEmpty()) {
            Log.w(TAG, "Hero palette material-name mismatch: hero=$hero missing=$missing applied=$applied")
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
        val actor = minionVisuals.getOrNull(index) ?: return
        val scaleX = actor.scale * minionScale * NpcVisualCatalog.minionWidthFactor(index)
        val scaleY = actor.scale * minionScale * NpcVisualCatalog.minionHeightFactor(index)
        val y = terrainHeight(x, z) - actor.minY * scaleY
        engine.transformManager.setTransform(actor.root,
            terrainAlignedTransform(x, z, yaw, scaleX, scaleY, y))
    }

    private fun applyBotTint(index: Int, disabled: Boolean) {
        val actor = botVisuals.getOrNull(index) ?: return
        val team = if (index < 4) 0 else 1
        applyNpcMaterialPalette(actor, team, index % 4, disabled)
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
        minionInstances.forEachIndexed { index, instance ->
            val shouldRender = visible && minionAlive[index]
            if (minionRendered[index] != shouldRender) {
                if (shouldRender) viewer.scene.addEntities(instance.entities)
                else viewer.scene.removeEntities(instance.entities)
                minionRendered[index] = shouldRender
            }
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
        val dt = deltaTime.coerceIn(0f, 0.05f)
        for (index in minionInstances.indices) {
            val alive = snapshot[222 + index] > 0.0f
            if (minionAlive[index] != alive) {
                minionAlive[index] = alive
                minionLastPositions[index][0] = Float.NaN
                minionLastPositions[index][1] = Float.NaN
            }
            if (!alive) {
                if (minionRendered[index]) {
                    viewer.scene.removeEntities(minionInstances[index].entities)
                    minionRendered[index] = false
                }
                continue
            }
            val actor = minionVisuals.getOrNull(index) ?: continue
            val x = snapshot[126 + index * 2]
            val z = snapshot[127 + index * 2]
            val previous = minionLastPositions[index]
            val dx = if (previous[0].isNaN()) 0f else x - previous[0]
            val dz = if (previous[1].isNaN()) 0f else z - previous[1]
            val speed = if (dt > 0f) kotlin.math.sqrt(dx * dx + dz * dz) / dt else 0f
            val team = if (index < 24) 0 else 1
            val yaw = if (speed > 0.16f) kotlin.math.atan2(dx, dz)
                else if (team == 0) 0f else Math.PI.toFloat()
            val playerDx = x - snapshot[0]
            val playerDz = z - snapshot[2]
            val radius = NpcVisualCatalog.MINION_RENDER_DISTANCE
            val inRange = playerDx * playerDx + playerDz * playerDz <= radius * radius
            val shouldRender = minionsVisible && inRange
            if (minionRendered[index] != shouldRender) {
                if (shouldRender) viewer.scene.addEntities(minionInstances[index].entities)
                else viewer.scene.removeEntities(minionInstances[index].entities)
                minionRendered[index] = shouldRender
            }
            if (shouldRender) {
                setMinionTransform(index, x, z, yaw)
                animateNpc(actor, speed, dt, index * 0.071f)
            }
            previous[0] = x
            previous[1] = z
        }
    }

    fun updateBots(snapshot: FloatArray, deltaTime: Float) {
        if (!sceneLoaded || snapshot.size < 34) return
        val transforms = engine.transformManager
        val dt = deltaTime.coerceIn(0f, 0.05f)
        botAnimationPhase += dt * 8.0f
        for (index in botVisuals.indices) {
            val actor = botVisuals[index]
            if (actor.root == 0) continue
            val x = snapshot[16 + index * 2]
            val z = snapshot[17 + index * 2]
            val previous = lastBotPositions[index]
            val dx = if (previous[0].isNaN()) 0f else x - previous[0]
            val dz = if (previous[1].isNaN()) 0f else z - previous[1]
            val speed = if (dt > 0f) kotlin.math.sqrt(dx * dx + dz * dz) / dt else 0f
            val desiredYaw = if (speed > 0.16f) kotlin.math.atan2(dx, dz)
                else if (index < 4) 0f else Math.PI.toFloat()
            if (!botYawInitialized[index]) {
                botYawState[index] = desiredYaw
                botYawInitialized[index] = true
            } else {
                val error = kotlin.math.atan2(
                    sin(desiredYaw - botYawState[index]),
                    cos(desiredYaw - botYawState[index])
                )
                botYawState[index] += error * (1f - kotlin.math.exp(-dt * 11f))
            }
            val role = if (snapshot.size >= 308) snapshot[299 + index].toInt().coerceIn(0, 4) else index % 5
            val scaleX = actor.scale * NpcVisualCatalog.botRoleWidth(role)
            val scaleY = actor.scale * NpcVisualCatalog.botRoleHeight(role)
            val y = terrainHeight(x, z) - actor.minY * scaleY
            transforms.setTransform(actor.root,
                terrainAlignedTransform(x, z, botYawState[index], scaleX, scaleY, y))

            val disabled = snapshot.size >= 72 && snapshot[63 + index] > 0.0f
            if (botDisabledState[index] != disabled) {
                applyBotTint(index, disabled)
                botDisabledState[index] = disabled
            }
            animateNpc(actor, speed, dt, index * 0.13f)
            previous[0] = x
            previous[1] = z
        }
    }

    private fun laneCenterX(lane: Int, worldZ: Float): Float {
        val scale = ArenaMapDefinition.WORLD_SCALE
        return ArenaMapDefinition.laneCenterX(lane, worldZ / scale) * scale
    }

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
        // Retain each CC0 source mesh, clothing, hair and original material palette.
        if (alternateSkin) Log.i(TAG, "Alternate skin request does not flatten the authored CC0 material palette")
    }

    fun setOverviewCamera(overview: Boolean) {
        showcaseMode = false
        overviewCamera = overview
        val mapScale = ArenaMapDefinition.WORLD_SCALE
        val spawn = when (activeHero) {
            1 -> laneCenterX(0, -67f * mapScale) to -67f * mapScale
            2 -> ArenaMapDefinition.camps.first().let {
                (it.position.x + 3.6f) * mapScale to it.position.z * mapScale
            }
            else -> laneCenterX(2, -67f * mapScale) + 1.8f * mapScale to -67f * mapScale
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
        val mapScale = ArenaMapDefinition.WORLD_SCALE
        val distance = (if (overviewCamera) 9.4f else 8.3f) * mapScale
        val height = (if (overviewCamera) 9.6f else 9.2f) * mapScale
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
            botVisuals.clear()
            minionInstances.forEach { viewer.scene.removeEntities(it.entities) }
            minionInstances.clear()
            minionVisuals.clear()
            minionRendered.fill(false)
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
