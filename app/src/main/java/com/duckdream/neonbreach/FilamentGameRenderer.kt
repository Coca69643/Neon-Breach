package com.duckdream.neonbreach

import android.content.Context
import android.util.Base64
import android.util.Log
import android.view.SurfaceView
import com.google.android.filament.Camera
import com.google.android.filament.Engine
import com.google.android.filament.Colors
import com.google.android.filament.IndirectLight
import com.google.android.filament.Skybox
import com.google.android.filament.View
import com.google.android.filament.android.UiHelper
import com.google.android.filament.gltfio.AssetLoader
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

    private var characterLoader: AssetLoader? = null
    private var characterResources: ResourceLoader? = null
    private var characterProvider: UbershaderProvider? = null
    private var character: FilamentAsset? = null
    private var characterRootInstance = 0
    private var characterScale = 1f
    private var characterMinY = 0f

    private data class BonePose(val instance: Int, val base: FloatArray)
    private val bones = LinkedHashMap<String, BonePose>()
    private val boneNames = listOf("thigh_l", "thigh_r", "calf_l", "calf_r", "upperarm_l", "upperarm_r")

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

        asset.releaseSourceData()
        viewer.scene.addEntities(asset.entities)

        val half = asset.boundingBox.getHalfExtent(null)
        val center = asset.boundingBox.getCenter(null)
        val height = max(0.1f, half[1] * 2f)
        characterScale = 1.92f / height
        characterMinY = center[1] - half[1]

        characterRootInstance = transforms.getInstance(asset.root)
        require(characterRootInstance != 0) { "Humanoid root transform is missing" }

        for (name in boneNames) {
            val entity = asset.getFirstEntityByName(name)
            if (entity != 0) {
                val instance = transforms.getInstance(entity)
                if (instance != 0) bones[name] = BonePose(instance, transforms.getTransform(instance, null))
            }
        }
        Log.i(TAG, "CC0 humanoid loaded: " + asset.entities.size + " entities, " + bones.size + " animated joints")
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
        phase += deltaTime * (7.5f + speed * 1.4f)
        animateBone("thigh_l", sin(phase) * 0.52f * moving)
        animateBone("thigh_r", -sin(phase) * 0.52f * moving)
        animateBone("calf_l", max(0f, -sin(phase)) * 0.48f * moving)
        animateBone("calf_r", max(0f, sin(phase)) * 0.48f * moving)
        animateBone("upperarm_l", -sin(phase) * 0.28f * moving)
        animateBone("upperarm_r", sin(phase) * 0.28f * moving)

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
            animatePose(rig["thigh_l"], sin(botAnimationPhase + index) * 0.48f * moving)
            animatePose(rig["thigh_r"], -sin(botAnimationPhase + index) * 0.48f * moving)
            animatePose(rig["calf_l"], max(0f, -sin(botAnimationPhase + index)) * 0.40f * moving)
            animatePose(rig["calf_r"], max(0f, sin(botAnimationPhase + index)) * 0.40f * moving)
            animatePose(rig["upperarm_l"], -sin(botAnimationPhase + index) * 0.25f * moving)
            animatePose(rig["upperarm_r"], sin(botAnimationPhase + index) * 0.25f * moving)
            previous[0] = x
            previous[1] = z
        }
    }

    private fun terrainHeight(x: Float, z: Float): Float {
        val hill = 0.48f * kotlin.math.exp(-((x - 10f) * (x - 10f) + (z - 8f) * (z - 8f)) / 95f)
        return 0.40f * sin(x * 0.18f) * cos(z * 0.14f) +
            0.20f * sin((x + z) * 0.29f) + hill
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
            Camera.Projection.PERSPECTIVE,
            fov, aspect.toDouble().coerceAtLeast(1.0 / 1.0), 0.1, 150.0,
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
            character?.let { asset ->
                botInstances.forEach { viewer.scene.removeEntities(it.entities) }
                botInstances.clear()
                viewer.scene.removeEntities(asset.entities)
                characterLoader?.destroyAsset(asset)
            }
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
