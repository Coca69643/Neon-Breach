package com.duckdream.neonbreach

import kotlin.math.floor

internal data class ArenaPoint(val x: Float, val z: Float)

/**
 * JNI bridge to the canonical C++ world definition.
 * The simulation and collision world own the coordinates; Kotlin consumes
 * sampled terrain and placement data for rendering and presentation.
 */
internal object ArenaWorldNative {
    external fun nativeTerrainGrid(steps: Int, size: Float): FloatArray
    external fun nativeLaneCenterX(lane: Int, z: Float): Float
    external fun nativeRiverCenterZ(x: Float): Float
    external fun nativeCampPositions(): FloatArray
    external fun nativeObjectivePositions(): FloatArray
    external fun nativeForestTreePositions(): FloatArray
    external fun nativeJungleGrovePositions(): FloatArray
}

internal object ArenaWorldDefinition {
    private const val GRID_STEPS = 136
    private const val GRID_SIZE = 76f
    private const val GRID_START = -GRID_SIZE * 0.5f
    private const val GRID_CELL = GRID_SIZE / GRID_STEPS

    private val terrain by lazy(LazyThreadSafetyMode.SYNCHRONIZED) {
        ArenaWorldNative.nativeTerrainGrid(GRID_STEPS, GRID_SIZE).also {
            check(it.size == (GRID_STEPS + 1) * (GRID_STEPS + 1)) {
                "Native terrain grid has an unexpected sample count: ${it.size}"
            }
        }
    }

    private val camps by lazy { decodePoints(ArenaWorldNative.nativeCampPositions(), "camps") }
    private val objectives by lazy { decodePoints(ArenaWorldNative.nativeObjectivePositions(), "objectives") }
    private val trees by lazy { decodePoints(ArenaWorldNative.nativeForestTreePositions(), "forest trees") }
    private val groves by lazy { decodePoints(ArenaWorldNative.nativeJungleGrovePositions(), "jungle groves") }

    fun initialize() {
        terrain
        camps
        objectives
        trees
        groves
    }

    fun heightAt(x: Float, z: Float): Float {
        val grid = terrain
        val gx = ((x - GRID_START) / GRID_CELL).coerceIn(0f, GRID_STEPS.toFloat())
        val gz = ((z - GRID_START) / GRID_CELL).coerceIn(0f, GRID_STEPS.toFloat())
        val x0 = floor(gx).toInt().coerceAtMost(GRID_STEPS - 1)
        val z0 = floor(gz).toInt().coerceAtMost(GRID_STEPS - 1)
        val tx = (gx - x0).coerceIn(0f, 1f)
        val tz = (gz - z0).coerceIn(0f, 1f)
        val stride = GRID_STEPS + 1
        val a = grid[z0 * stride + x0]
        val b = grid[z0 * stride + x0 + 1]
        val c = grid[(z0 + 1) * stride + x0]
        val d = grid[(z0 + 1) * stride + x0 + 1]
        val near = a + (b - a) * tx
        val far = c + (d - c) * tx
        return near + (far - near) * tz
    }

    fun laneCenterX(lane: Int, z: Float): Float =
        ArenaWorldNative.nativeLaneCenterX(lane.coerceIn(0, 2), z)

    fun riverCenterZ(x: Float): Float = ArenaWorldNative.nativeRiverCenterZ(x)

    fun campPositions(): List<ArenaPoint> = camps
    fun objectivePositions(): List<ArenaPoint> = objectives
    fun forestTreePositions(): List<ArenaPoint> = trees
    fun jungleGrovePositions(): List<ArenaPoint> = groves

    private fun decodePoints(values: FloatArray, label: String): List<ArenaPoint> {
        check(values.isNotEmpty() && values.size % 2 == 0) {
            "Native $label layout is malformed: ${values.size} values"
        }
        return values.asList().chunked(2).map { ArenaPoint(it[0], it[1]) }
    }
}
