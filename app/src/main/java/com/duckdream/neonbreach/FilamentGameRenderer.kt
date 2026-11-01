package com.duckdream.neonbreach

import android.content.Context
import android.util.Base64
import android.util.Log
import android.view.SurfaceView
import com.google.android.filament.Camera
import com.google.android.filament.Engine
import com.google.android.filament.Skybox
import com.google.android.filament.View
import com.google.android.filament.android.UiHelper
import com.google.android.filament.gltfio.AssetLoader
import com.google.android.filament.gltfio.FilamentAsset
import com.google.android.filament.gltfio.ResourceLoader
import com.google.android.filament.gltfio.UbershaderProvider
import com.google.android.filament.EntityManager
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
    private var sceneLoaded = false

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
            .color(floatArrayOf(0.10f, 0.17f, 0.19f, 1f))
            .build(engine)
        viewer.scene.skybox = skybox

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
        asset.releaseSourceData()
        viewer.scene.addEntities(asset.entities)

        val half = asset.boundingBox.getHalfExtent(null)
        val center = asset.boundingBox.getCenter(null)
        val height = max(0.1f, half[1] * 2f)
        characterScale = 1.72f / height
        characterMinY = center[1] - half[1]

        val transforms = engine.transformManager
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

    fun update(x: Float, y: Float, z: Float, speed: Float, deltaTime: Float) {
        if (!sceneLoaded) return
        val blend = (deltaTime * 5.5f).coerceIn(0f, 1f)
        cameraX += (x - cameraX) * blend
        cameraZ += (z - cameraZ) * blend
        cameraY += (y - cameraY) * blend

        val yaw = if (speed > 0.18f) kotlin.math.atan2(-x, -z) else 0f
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

    private fun animateBone(name: String, angle: Float) {
        val bone = bones[name] ?: return
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

    private fun updateCamera(aspect: Float) {
        val vertical = 22.5
        val horizontal = vertical * aspect.coerceAtLeast(1.0)
        viewer.camera.setProjection(
            Camera.Projection.ORTHO,
            -horizontal, horizontal, -vertical, vertical, 0.1, 120.0
        )
        viewer.camera.lookAt(
            cameraX.toDouble(), (cameraY + 31.0).toDouble(), (cameraZ + 24.0).toDouble(),
            cameraX.toDouble(), cameraY.toDouble(), cameraZ.toDouble(),
            0.0, 1.0, 0.0
        )
    }

    fun destroy() {
        try {
            character?.let { asset ->
                viewer.scene.removeEntities(asset.entities)
                characterLoader?.destroyAsset(asset)
            }
            character = null
            characterResources?.destroy()
            characterLoader?.destroy()
            characterProvider?.destroy()
            viewer.destroyModel()
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
