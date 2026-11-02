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
    private val towerRootInstances = IntArray(6)
    private val towerBaseTransforms = arrayOfNulls<FloatArray>(6)
    private val towerHidden = BooleanArray(6)
    private data class WorldPlacement(
        val model: String, val x: Float, val z: Float,
        val scale: Float, val yaw: Float = 0f, val yOffset: Float = 0f
    )

    private var characterLoader: AssetLoader? = null
    private var characterResources: ResourceLoader? = null
    private var characterProvider: UbershaderProvider? = null
    private var character: FilamentAsset? = null
    private var playerInstance: FilamentInstance? = null
    private var playerAnimator: Animator? = null
    private val botAnimators = ArrayList<Animator>(9)
    private val minionInstances = ArrayList<FilamentInstance>(12)
    private val minionAnimators = ArrayList<Animator>(12)
    private val minionRootInstances = IntArray(12)
    private val minionBones = ArrayList<Map<String, BonePose>>(12)
    private val minionLastPositions = Array(12) { floatArrayOf(Float.NaN, Float.NaN) }
    private val minionAlive = BooleanArray(12) { true }
    private var minionAnimationPhase = 0f
    private val minionScale = 0.72f
    private var minionsVisible = false
    private val playerMaterials = ArrayList<MaterialInstance>(4)
    private var characterRootInstance = 0
    private var characterScale = 1f
    private var characterMinY = 0f

    private data class BonePose(val instance: Int, val base: FloatArray)
    private val bones = LinkedHashMap<String, BonePose>()
    private val boneNames = listOf(
        "thigh_l", "thigh_r", "calf_l", "calf_r",
        "upperarm_l", "upperarm_r", "lowerarm_l", "lowerarm_r",
        "spine_01", "spine_02", "neck_01"
    )

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
            .color(floatArrayOf(0.34f, 0.48f, 0.50f, 1f))
            .build(engine)
        viewer.scene.skybox = skybox
        indirectLight = IndirectLight.Builder()
            .irradiance(1, floatArrayOf(0.28f, 0.31f, 0.36f))
            .intensity(22_000.0f)
            .build(engine)
        viewer.scene.indirectLight = indirectLight

        // ModelViewer supplies a sun, but its default direction is straight down.
        // Angle it across the map so foliage, towers and lane walls gain readable form.
        engine.lightManager.setDirection(viewer.light, -0.42f, -1.0f, -0.34f)
        engine.lightManager.setColor(viewer.light, 1.0f, 0.93f, 0.82f)
        engine.lightManager.setIntensity(viewer.light, 78_000.0f)
        viewer.camera.setExposure(15.5f, 1.0f / 100.0f, 80.0f)

        viewer.view.renderQuality = viewer.view.renderQuality.apply {
            hdrColorBuffer = View.QualityLevel.LOW
        }
        viewer.view.dynamicResolutionOptions = viewer.view.dynamicResolutionOptions.apply {
            enabled = true
            quality = View.QualityLevel.LOW
        }
        viewer.view.antiAliasing = View.AntiAliasing.FXAA

        loadWorld()
        loadKayKitEnvironment()
        loadCharacter()
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
            "bridge_a", "trees_a",
            "flag_blue", "flag_red"
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

            for (x in listOf(-12f, 0f, 12f)) {
                add(WorldPlacement("tower_blue", x, -12.2f, 1.9f))
                add(WorldPlacement("tower_red", x, 12.2f, 1.9f, Math.PI.toFloat()))
                add(WorldPlacement("bridge_a", x, 0f, 1.55f))
                add(WorldPlacement("flag_blue", x, -3.1f, 5.0f))
                add(WorldPlacement("flag_red", x, 3.1f, 5.0f, Math.PI.toFloat()))
            }

            // Woodland pockets sit between the three playable roads, not on top of them.
            listOf(
                floatArrayOf(-22f, -17f), floatArrayOf(-22f, 17f),
                floatArrayOf(-6.5f, -18f), floatArrayOf(-6.5f, 18f),
                floatArrayOf(6.5f, -18f), floatArrayOf(6.5f, 18f),
                floatArrayOf(22f, -17f), floatArrayOf(22f, 17f),
                floatArrayOf(-18f, -5.5f), floatArrayOf(18f, 5.5f)
            ).forEachIndexed { index, p ->
                val yaw = (index % 4) * 0.55f
                add(WorldPlacement("trees_a", p[0], p[1], 2.3f, yaw))
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
                val lane = kotlin.math.round((placement.x + 12f) / 12f).toInt().coerceIn(0, 2)
                val towerIndex = (if (placement.model == "tower_blue") 0 else 3) + lane
                towerRootInstances[towerIndex] = root
                towerBaseTransforms[towerIndex] = matrix.copyOf()
                towerHidden[towerIndex] = false
            }
        }

        worldAssets.values.forEach { it.releaseSourceData() }
        Log.i(TAG, "KayKit CC0 environment loaded: ${worldAssets.size} models, ${worldInstances.size} placements")
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
            val rig = LinkedHashMap<String, BonePose>()
            for (name in boneNames) {
                val joint = instance.entities.firstOrNull { asset.getName(it) == name } ?: 0
                if (joint != 0) {
                    val jointInstance = transforms.getInstance(joint)
                    if (jointInstance != 0) {
                        rig[name] = BonePose(jointInstance, transforms.getTransform(jointInstance, null))
                    }
                }
            }
            botBones.add(rig)
            applyRestPose(rig)
            instance.animator.updateBoneMatrices()
            applyBotTint(index, disabled = false)
        }

        // Twelve smaller, animated lane units: two per team on each of the three routes.
        // Their meshes and material atlas are shared with the hero instances.
        for (index in 0 until 12) {
            val instance = characterLoader!!.createInstance(asset)
                ?: throw IllegalStateException("Could not instance lane unit $index")
            minionInstances.add(instance)
            minionAnimators.add(instance.animator)
            val rootInstance = transforms.getInstance(instance.root)
            require(rootInstance != 0) { "Lane unit root transform is missing: $index" }
            minionRootInstances[index] = rootInstance
            val rig = LinkedHashMap<String, BonePose>()
            for (name in boneNames) {
                val joint = instance.entities.firstOrNull { asset.getName(it) == name } ?: 0
                if (joint != 0) {
                    val jointInstance = transforms.getInstance(joint)
                    if (jointInstance != 0) {
                        rig[name] = BonePose(jointInstance, transforms.getTransform(jointInstance, null))
                    }
                }
            }
            minionBones.add(rig)
            applyRestPose(rig)
            instance.animator.updateBoneMatrices()
            val tint = if (index < 6) {
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

        // The player is a real FilamentInstance too, so its materials can be styled
        // independently from the nine shared-geometry bot instances.
        playerInstance = characterLoader!!.createInstance(asset)
            ?: throw IllegalStateException("Could not create the player humanoid instance")
        val player = playerInstance!!
        playerAnimator = player.animator
        playerMaterials.clear()
        player.materialInstances.forEach { playerMaterials.add(it) }
        viewer.scene.addEntities(player.entities)

        val half = asset.boundingBox.getHalfExtent(null)
        val center = asset.boundingBox.getCenter(null)
        val height = max(0.1f, half[1] * 2f)
        characterScale = 1.92f / height
        characterMinY = center[1] - half[1]

        for (index in minionRootInstances.indices) {
            val local = index % 6
            val lane = local % 3
            val slot = local / 3
            val team = if (index < 6) 0 else 1
            val side = if (slot == 0) -0.75f else 0.75f
            val teamOffset = if (team == 0) -0.48f else 0.48f
            val z = if (team == 0) -23.5f - slot * 1.2f else 23.5f + slot * 1.2f
            setMinionTransform(index, kLaneX(lane) + side + teamOffset, z, if (team == 0) 0f else Math.PI.toFloat())
        }

        characterRootInstance = transforms.getInstance(player.root)
        require(characterRootInstance != 0) { "Humanoid player root transform is missing" }

        for (name in boneNames) {
            val entity = player.entities.firstOrNull { asset.getName(it) == name } ?: 0
            if (entity != 0) {
                val instance = transforms.getInstance(entity)
                if (instance != 0) bones[name] = BonePose(instance, transforms.getTransform(instance, null))
            }
        }
        applyRestPose(bones)
        playerAnimator?.updateBoneMatrices()
        asset.releaseSourceData()
        Log.i(TAG, "CC0 humanoid loaded: " + asset.entities.size + " entities, " + bones.size + " animated joints; skeletal skinning enabled")
    }

    fun render(frameTimeNanos: Long): Boolean = viewer.render(frameTimeNanos)

    fun resize(width: Int, height: Int) {
        if (width <= 0 || height <= 0) return
        cameraAspect = width.toFloat() / height.toFloat()
        updateCamera(cameraAspect)
    }

    fun update(x: Float, y: Float, z: Float, velocityX: Float, velocityZ: Float, deltaTime: Float) {
        if (!sceneLoaded) return
        val speed = kotlin.math.sqrt(velocityX * velocityX + velocityZ * velocityZ)
        if (speed > 0.18f) playerYaw = kotlin.math.atan2(velocityX, velocityZ)

        // Keep the hero in the lower-middle safe area: never underneath the left joystick.
        // The camera tracks a biased focus point ahead and to the hero's right.
        val forwardX = sin(playerYaw)
        val forwardZ = cos(playerYaw)
        val rightX = cos(playerYaw)
        val rightZ = -sin(playerYaw)
        val targetX = x - rightX * 1.55f + forwardX * 2.0f
        val targetZ = z - rightZ * 1.55f + forwardZ * 2.0f
        val blend = (1f - kotlin.math.exp(-deltaTime * 6.5f)).coerceIn(0f, 1f)
        if (!overviewCamera) {
            cameraX += (targetX - cameraX) * blend
            cameraZ += (targetZ - cameraZ) * blend
            cameraY += (y - cameraY) * blend
        }

        overviewCamera = false
        val yaw = playerYaw
        val widthScale = when (activeHero) {
            1 -> 1.18f
            2 -> 0.84f
            else -> 0.96f
        }
        val heightScale = when (activeHero) {
            1 -> 0.94f
            2 -> 1.13f
            else -> 1.04f
        }
        val scaleX = characterScale * widthScale
        val scaleY = characterScale * heightScale
        val c = cos(yaw) * scaleX
        val s = sin(yaw) * scaleX
        val rootY = cameraY - characterMinY * scaleY
        val matrix = floatArrayOf(
            c, 0f, -s, 0f,
            0f, scaleY, 0f, 0f,
            s, 0f, c, 0f,
            x, rootY, z, 1f
        )
        engine.transformManager.setTransform(characterRootInstance, matrix)

        val moving = (speed / 5.6f).coerceIn(0f, 1f)
        phase += deltaTime * (7.0f + speed * 1.45f)
        val stride = sin(phase) * moving
        val idle = sin(phase * 0.72f)
        animateBone("upperarm_l", -0.90f - stride * 0.34f + idle * 0.025f)
        animateBone("upperarm_r", 0.90f + stride * 0.34f - idle * 0.025f)
        animateBone("lowerarm_l", 0.48f + max(0f, stride) * 0.19f)
        animateBone("lowerarm_r", 0.48f + max(0f, -stride) * 0.19f)
        animateBone("thigh_l", stride * 0.68f)
        animateBone("thigh_r", -stride * 0.68f)
        animateBone("calf_l", max(0f, -stride) * 0.55f)
        animateBone("calf_r", max(0f, stride) * 0.55f)
        animateBone("spine_01", 0.014f + sin(phase * 0.75f) * 0.018f + sin(phase * 2f) * 0.025f * moving)
        animateBone("spine_02", -0.010f - sin(phase * 0.75f) * 0.014f)
        animateBone("neck_01", sin(phase * 0.45f) * 0.018f)
        playerAnimator?.updateBoneMatrices()

        updateCamera(cameraAspect)
    }

    private fun kLaneX(lane: Int): Float = when (lane) {
        0 -> -12f
        1 -> 0f
        else -> 12f
    }

    private fun setMinionTransform(index: Int, x: Float, z: Float, yaw: Float) {
        val root = minionRootInstances.getOrNull(index) ?: return
        if (root == 0) return
        val width = when (index % 3) { 0 -> 0.88f; 1 -> 1.04f; else -> 0.96f }
        val height = when (index % 3) { 0 -> 1.08f; 1 -> 0.92f; else -> 1.0f }
        val scaleX = characterScale * minionScale * width
        val scaleY = characterScale * minionScale * height
        val c = cos(yaw) * scaleX
        val sn = sin(yaw) * scaleX
        val y = terrainHeight(x, z) - characterMinY * scaleY
        engine.transformManager.setTransform(root, floatArrayOf(
            c, 0f, -sn, 0f,
            0f, scaleY, 0f, 0f,
            sn, 0f, c, 0f,
            x, y, z, 1f
        ))
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
        if (!sceneLoaded || snapshot.size < 82) return
        val transforms = engine.transformManager
        for (index in 0 until 6) {
            val root = towerRootInstances[index]
            val base = towerBaseTransforms[index] ?: continue
            if (root == 0) continue
            val health = if (index < 3) snapshot[73 + index] else snapshot[76 + index - 3]
            val destroyed = health <= 0.0f
            if (towerHidden[index] == destroyed) continue
            val matrix = base.copyOf()
            if (destroyed) {
                // Remove the intact tower silhouette only after its native health reaches zero.
                for (element in intArrayOf(0, 1, 2, 4, 5, 6, 8, 9, 10)) {
                    matrix[element] *= 0.001f
                }
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

    fun updateCreeps(snapshot: FloatArray, deltaTime: Float) {
        if (!sceneLoaded || snapshot.size < 94) return
        minionAnimationPhase += deltaTime * 7.2f
        for (index in minionInstances.indices) {
            val alive = snapshot[82 + index] > 0.0f
            if (minionAlive[index] != alive) {
                if (alive) viewer.scene.addEntities(minionInstances[index].entities)
                else viewer.scene.removeEntities(minionInstances[index].entities)
                minionAlive[index] = alive
                minionLastPositions[index][0] = Float.NaN
                minionLastPositions[index][1] = Float.NaN
            }
            if (!alive) continue
            val x = snapshot[36 + index * 2]
            val z = snapshot[37 + index * 2]
            val previous = minionLastPositions[index]
            val dx = if (previous[0].isNaN()) 0f else x - previous[0]
            val dz = if (previous[1].isNaN()) 0f else z - previous[1]
            val speed = if (deltaTime > 0f) kotlin.math.sqrt(dx * dx + dz * dz) / deltaTime else 0f
            val moving = (speed / 2.55f).coerceIn(0f, 1f)
            val team = if (index < 6) 0 else 1
            val yaw = if (moving > 0.08f) kotlin.math.atan2(dx, dz)
                else if (team == 0) 0f else Math.PI.toFloat()
            setMinionTransform(index, x, z, yaw)
            val rig = minionBones.getOrNull(index).orEmpty()
            val stride = sin(minionAnimationPhase + index * 0.37f) * moving
            val idle = sin(minionAnimationPhase * 0.58f + index * 0.6f)
            animateArmPose(rig["upperarm_l"], -0.90f - stride * 0.22f + idle * 0.018f)
            animateArmPose(rig["upperarm_r"], 0.90f + stride * 0.22f - idle * 0.018f)
            animateArmPose(rig["lowerarm_l"], 0.48f)
            animateArmPose(rig["lowerarm_r"], 0.48f)
            animatePose(rig["thigh_l"], stride * 0.60f)
            animatePose(rig["thigh_r"], -stride * 0.60f)
            animatePose(rig["calf_l"], max(0f, -stride) * 0.45f)
            animatePose(rig["calf_r"], max(0f, stride) * 0.45f)
            animatePose(rig["spine_01"], idle * 0.014f)
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
            val yaw = if (moving > 0.08f) kotlin.math.atan2(dx, dz)
                else if (index < 4) 0f else Math.PI.toFloat()
            // Heavy, agile and balanced silhouettes instead of near-identical tinted clones.
            val widthFactor = when (index % 3) { 0 -> 1.24f; 1 -> 0.76f; else -> 0.96f }
            val heightFactor = when (index % 3) { 0 -> 0.91f; 1 -> 1.16f; else -> 1.02f }
            val scaleX = characterScale * botScale * widthFactor
            val scaleY = characterScale * botScale * heightFactor
            val y = terrainHeight(x, z) - characterMinY * scaleY
            val c = cos(yaw) * scaleX
            val sinYaw = sin(yaw) * scaleX
            val matrix = floatArrayOf(
                c, 0f, -sinYaw, 0f,
                0f, scaleY, 0f, 0f,
                sinYaw, 0f, c, 0f,
                x, y, z, 1f
            )
            transforms.setTransform(rootInstance, matrix)

            val rig = botBones.getOrNull(index).orEmpty()
            val stride = sin(botAnimationPhase * (0.92f + index * 0.015f) + index * 0.41f) * moving
            animateArmPose(rig["upperarm_l"], -0.92f - stride * 0.28f)
            animateArmPose(rig["upperarm_r"], 0.92f + stride * 0.28f)
            animateArmPose(rig["lowerarm_l"], 0.50f + max(0f, stride) * 0.14f)
            animateArmPose(rig["lowerarm_r"], 0.50f + max(0f, -stride) * 0.14f)
            animatePose(rig["thigh_l"], stride * 0.60f)
            animatePose(rig["thigh_r"], -stride * 0.60f)
            animatePose(rig["calf_l"], max(0f, -stride) * 0.45f)
            animatePose(rig["calf_r"], max(0f, stride) * 0.45f)
            val idle = sin(botAnimationPhase * 0.58f + index * 0.43f)
            animatePose(rig["spine_01"], 0.012f + idle * 0.016f + sin(botAnimationPhase * 2f + index) * 0.02f * moving)
            animatePose(rig["spine_02"], -idle * 0.012f)
            animatePose(rig["neck_01"], sin(botAnimationPhase * 0.36f + index) * 0.015f)
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

    private fun terrainHeight(x: Float, z: Float): Float {
        val westRidge = 1.05f * kotlin.math.exp(-((x + 23f) * (x + 23f)) / 52f) *
            (0.45f + 0.55f * cos(z * 0.075f))
        val eastRidge = 0.92f * kotlin.math.exp(-((x - 23f) * (x - 23f)) / 58f) *
            (0.45f + 0.55f * cos(z * 0.07f))
        val centralRise = 0.48f * kotlin.math.exp(-((x - 1f) * (x - 1f) + (z - 1f) * (z - 1f)) / 90f)
        return 0.36f * sin(x * 0.18f) * cos(z * 0.14f) +
            0.18f * sin((x + z) * 0.29f) + westRidge + eastRidge + centralRise
    }

    private fun applyRestPose(rig: Map<String, BonePose>) {
        // Original unarmed idle stance: lowered shoulders, gently bent elbows and a relaxed spine.
        animateArmPose(rig["upperarm_l"], -0.92f)
        animateArmPose(rig["upperarm_r"], 0.92f)
        animateArmPose(rig["lowerarm_l"], 0.50f)
        animateArmPose(rig["lowerarm_r"], 0.50f)
        animatePose(rig["spine_01"], 0.015f)
        animatePose(rig["spine_02"], -0.012f)
        animatePose(rig["neck_01"], 0f)
    }

    private fun animateBone(name: String, angle: Float) {
        val arm = name.startsWith("upperarm") || name.startsWith("lowerarm")
        animatePose(bones[name], angle, if (arm) 2 else 0)
    }

    private fun animateArmPose(bone: BonePose?, angle: Float) {
        animatePose(bone, angle, 2)
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
        val tint = if (alternateSkin) {
            when (activeHero) {
                1 -> floatArrayOf(0.22f, 0.72f, 0.76f, 1.0f)
                2 -> floatArrayOf(0.88f, 0.34f, 0.20f, 1.0f)
                else -> floatArrayOf(0.82f, 0.70f, 0.36f, 1.0f)
            }
        } else {
            when (activeHero) {
                1 -> floatArrayOf(0.88f, 0.62f, 0.28f, 1.0f)
                2 -> floatArrayOf(0.58f, 0.46f, 0.92f, 1.0f)
                else -> floatArrayOf(0.78f, 0.91f, 0.77f, 1.0f)
            }
        }
        playerMaterials.forEach { material ->
            runCatching {
                material.setParameter(
                    "baseColorFactor", Colors.RgbaType.SRGB,
                    tint[0], tint[1], tint[2], tint[3]
                )
            }.onFailure { error ->
                Log.w(TAG, "Hero material tint fallback", error)
            }
        }
    }

    fun setOverviewCamera(overview: Boolean) {
        overviewCamera = overview
        if (overview) {
            cameraX = -12.0f
            cameraZ = -19.0f
            cameraY = terrainHeight(cameraX, cameraZ)
            playerYaw = 0.0f
            val rootY = cameraY - characterMinY * characterScale
            val scale = characterScale
            engine.transformManager.setTransform(characterRootInstance, floatArrayOf(
                scale, 0f, 0f, 0f, 0f, scale, 0f, 0f,
                0f, 0f, scale, 0f, cameraX, rootY, cameraZ, 1f
            ))
        } else {
            // Initialize follow-camera from the actual spawn instead of stale menu coordinates.
            val forwardX = sin(playerYaw); val forwardZ = cos(playerYaw)
            val rightX = cos(playerYaw); val rightZ = -sin(playerYaw)
            cameraX = -12.0f - rightX * 1.55f + forwardX * 2.0f
            cameraZ = -19.0f - rightZ * 1.55f + forwardZ * 2.0f
            cameraY = terrainHeight(-12.0f, -19.0f)
        }
        updateCamera(cameraAspect)
    }

    private fun updateCamera(aspect: Float) {
        val forwardX = sin(playerYaw)
        val forwardZ = cos(playerYaw)
        val distance = if (overviewCamera) 7.6f else 10.2f
        val height = if (overviewCamera) 4.4f else 7.8f
        val lookAhead = if (overviewCamera) 0.45f else 0.28f
        val eyeX = cameraX - forwardX * distance
        val eyeZ = cameraZ - forwardZ * distance
        val lookX = cameraX + forwardX * lookAhead
        val lookZ = cameraZ + forwardZ * lookAhead
        val fov = if (overviewCamera) 46.0 else 49.0
        viewer.camera.setProjection(
            fov, aspect.toDouble().coerceAtLeast(0.5), 0.1, 150.0,
            Camera.Fov.VERTICAL
        )
        viewer.camera.lookAt(
            eyeX.toDouble(), (cameraY + height).toDouble(), eyeZ.toDouble(),
            lookX.toDouble(), (cameraY + 1.15f).toDouble(), lookZ.toDouble(),
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
            playerInstance?.let { viewer.scene.removeEntities(it.entities) }
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
