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
        check(viewer.asset != null) { "MOBA world GLB failed to load" }
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
            transforms.setTransform(root, floatArrayOf(
                c, 0f, -sn, 0f,
                0f, placement.scale, 0f, 0f,
                sn, 0f, c, 0f,
                placement.x, y, placement.z, 1f
            ))
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
            val tint = if (index < 4) {
                floatArrayOf(0.34f, 0.82f, 0.78f, 1f)
            } else {
                floatArrayOf(0.92f, 0.40f, 0.29f, 1f)
            }
            instance.materialInstances.forEach { material ->
                runCatching {
                    material.setParameter("baseColorFactor", Colors.RgbaType.SRGB, tint[0], tint[1], tint[2], tint[3])
                }.onFailure { error ->
                    Log.w(TAG, "Bot material tint fallback for instance $index", error)
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
        val blend = (deltaTime * 5.5f).coerceIn(0f, 1f)
        if (!overviewCamera) {
            cameraX += (x - cameraX) * blend
            cameraZ += (z - cameraZ) * blend
            cameraY += (y - cameraY) * blend
        }

        overviewCamera = false
        val speed = kotlin.math.sqrt(velocityX * velocityX + velocityZ * velocityZ)
        if (speed > 0.18f) playerYaw = kotlin.math.atan2(velocityX, velocityZ)
        val yaw = playerYaw
        val c = cos(yaw) * characterScale
        val s = sin(yaw) * characterScale
        val rootY = cameraY - characterMinY * characterScale
        val matrix = floatArrayOf(
            c, 0f, -s, 0f,
            0f, characterScale, 0f, 0f,
            s, 0f, c, 0f,
            x, rootY, z, 1f
        )
        engine.transformManager.setTransform(characterRootInstance, matrix)

        val moving = (speed / 5.6f).coerceIn(0f, 1f)
        phase += deltaTime * (7.0f + speed * 1.45f)
        val stride = sin(phase) * moving
        // A relaxed, lowered shoulder pose replaces the source model's T-pose.
        animateBone("upperarm_l", -0.92f - stride * 0.30f)
        animateBone("upperarm_r", 0.92f + stride * 0.30f)
        animateBone("lowerarm_l", 0.50f + max(0f, stride) * 0.16f)
        animateBone("lowerarm_r", 0.50f + max(0f, -stride) * 0.16f)
        animateBone("thigh_l", stride * 0.62f)
        animateBone("thigh_r", -stride * 0.62f)
        animateBone("calf_l", max(0f, -stride) * 0.52f)
        animateBone("calf_r", max(0f, stride) * 0.52f)
        animateBone("spine_01", sin(phase * 2f) * 0.025f * moving)
        animateBone("spine_02", -sin(phase * 2f) * 0.018f * moving)
        playerAnimator?.updateBoneMatrices()

        updateCamera(cameraAspect)
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
            val y = terrainHeight(x, z) - characterMinY * characterScale * botScale
            val scale = characterScale * botScale
            val c = cos(yaw) * scale
            val sinYaw = sin(yaw) * scale
            val matrix = floatArrayOf(
                c, 0f, -sinYaw, 0f,
                0f, scale, 0f, 0f,
                sinYaw, 0f, c, 0f,
                x, y, z, 1f
            )
            transforms.setTransform(rootInstance, matrix)

            val rig = botBones.getOrNull(index).orEmpty()
            val stride = sin(botAnimationPhase * (0.92f + index * 0.015f) + index * 0.41f) * moving
            animatePose(rig["upperarm_l"], -0.92f - stride * 0.28f)
            animatePose(rig["upperarm_r"], 0.92f + stride * 0.28f)
            animatePose(rig["lowerarm_l"], 0.50f + max(0f, stride) * 0.14f)
            animatePose(rig["lowerarm_r"], 0.50f + max(0f, -stride) * 0.14f)
            animatePose(rig["thigh_l"], stride * 0.60f)
            animatePose(rig["thigh_r"], -stride * 0.60f)
            animatePose(rig["calf_l"], max(0f, -stride) * 0.45f)
            animatePose(rig["calf_r"], max(0f, stride) * 0.45f)
            animatePose(rig["spine_01"], sin(botAnimationPhase * 2f + index) * 0.02f * moving)
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
        animatePose(rig["upperarm_l"], -0.92f)
        animatePose(rig["upperarm_r"], 0.92f)
        animatePose(rig["lowerarm_l"], 0.50f)
        animatePose(rig["lowerarm_r"], 0.50f)
        animatePose(rig["spine_01"], 0.015f)
        animatePose(rig["spine_02"], -0.012f)
        animatePose(rig["neck_01"], 0f)
    }

    private fun animateBone(name: String, angle: Float) {
        animatePose(bones[name], angle)
    }

    private fun animatePose(bone: BonePose?, angle: Float) {
        if (bone == null) return
        val c = cos(angle)
        val s = sin(angle)
        val rotation = floatArrayOf(
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

    fun setHeroAppearance(hero: Int) {
        val tint = when (hero.coerceIn(0, 2)) {
            1 -> floatArrayOf(0.88f, 0.62f, 0.28f, 1.0f) // Bastion: warm gold
            2 -> floatArrayOf(0.58f, 0.46f, 0.92f, 1.0f) // Kairo: violet
            else -> floatArrayOf(0.30f, 0.78f, 0.82f, 1.0f) // Lyra: cyan
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
            // The menu is a hero portrait, not a map-wide tactical overview.
            cameraX = -12.0f
            cameraZ = -19.0f
            cameraY = terrainHeight(cameraX, cameraZ)
            playerYaw = 0.0f
            val rootY = cameraY - characterMinY * characterScale
            val scale = characterScale
            val matrix = floatArrayOf(
                scale, 0f, 0f, 0f,
                0f, scale, 0f, 0f,
                0f, 0f, scale, 0f,
                cameraX, rootY, cameraZ, 1f
            )
            engine.transformManager.setTransform(characterRootInstance, matrix)
        }
        updateCamera(cameraAspect)
    }

    private fun updateCamera(aspect: Float) {
        val forwardX = sin(playerYaw)
        val forwardZ = cos(playerYaw)
        val distance = if (overviewCamera) 7.6f else 9.2f
        val height = if (overviewCamera) 4.4f else 5.2f
        val lookAhead = if (overviewCamera) 0.45f else 1.8f
        val eyeX = cameraX - forwardX * distance
        val eyeZ = cameraZ - forwardZ * distance
        val lookX = cameraX + forwardX * lookAhead
        val lookZ = cameraZ + forwardZ * lookAhead
        val fov = if (overviewCamera) 46.0 else 53.0
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
