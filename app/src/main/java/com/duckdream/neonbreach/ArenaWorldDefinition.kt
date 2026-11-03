package com.duckdream.neonbreach

import kotlin.math.floor
import kotlin.math.roundToInt

internal data class ArenaPoint(val x: Float, val z: Float)

/** Testable contract between the native world definition and Kotlin presentation. */
internal interface ArenaWorldDataSource {
    fun terrainGrid(steps: Int, size: Float): FloatArray
    fun laneCenterX(lane: Int, z: Float): Float
    fun towerZ(team: Int, tier: Int): Float
    fun riverCenterZ(x: Float): Float
    fun islandMask(steps: Int, size: Float): BooleanArray
    fun campPositions(): FloatArray
    fun objectivePositions(): FloatArray
    fun forestTreePositions(): FloatArray
    fun jungleGrovePositions(): FloatArray
    fun undergrowthPositions(): FloatArray
}

/**
 * JNI implementation. Native C++ remains authoritative for simulation,
 * collision and terrain; Kotlin only receives a sampled grid and shared points.
 */
internal object ArenaWorldNative {
    external fun nativeTerrainGrid(steps: Int, size: Float): FloatArray
    external fun nativeLaneCenterX(lane: Int, z: Float): Float
    external fun nativeTowerZ(team: Int, tier: Int): Float
    external fun nativeRiverCenterZ(x: Float): Float
    external fun nativeIslandMask(steps: Int, size: Float): BooleanArray
    external fun nativeCampPositions(): FloatArray
    external fun nativeObjectivePositions(): FloatArray
    external fun nativeForestTreePositions(): FloatArray
    external fun nativeJungleGrovePositions(): FloatArray
    external fun nativeUndergrowthPositions(): FloatArray
}

private object NativeArenaWorldDataSource : ArenaWorldDataSource {
    override fun terrainGrid(steps: Int, size: Float) = ArenaWorldNative.nativeTerrainGrid(steps, size)
    override fun laneCenterX(lane: Int, z: Float) = ArenaWorldNative.nativeLaneCenterX(lane, z)
    override fun towerZ(team: Int, tier: Int) = ArenaWorldNative.nativeTowerZ(team, tier)
    override fun riverCenterZ(x: Float) = ArenaWorldNative.nativeRiverCenterZ(x)
    override fun islandMask(steps: Int, size: Float) = ArenaWorldNative.nativeIslandMask(steps, size)
    override fun campPositions() = ArenaWorldNative.nativeCampPositions()
    override fun objectivePositions() = ArenaWorldNative.nativeObjectivePositions()
    override fun forestTreePositions() = ArenaWorldNative.nativeForestTreePositions()
    override fun jungleGrovePositions() = ArenaWorldNative.nativeJungleGrovePositions()
    override fun undergrowthPositions() = ArenaWorldNative.nativeUndergrowthPositions()
}

internal object ArenaWorldDefinition {
    internal const val GRID_STEPS = 136
    internal const val GRID_SIZE = 76f
    private const val GRID_START = -GRID_SIZE * 0.5f
    private const val GRID_CELL = GRID_SIZE / GRID_STEPS

    private data class Snapshot(
        val terrain: FloatArray,
        val camps: List<ArenaPoint>,
        val objectives: List<ArenaPoint>,
        val trees: List<ArenaPoint>,
        val groves: List<ArenaPoint>,
        val undergrowth: List<ArenaPoint>,
        val islandMask: BooleanArray
    )

    @Volatile private var source: ArenaWorldDataSource = NativeArenaWorldDataSource
    @Volatile private var cachedSnapshot: Snapshot? = null

    private fun snapshot(): Snapshot {
        cachedSnapshot?.let { return it }
        return synchronized(this) {
            cachedSnapshot ?: run {
                val current = source
                val terrain = current.terrainGrid(GRID_STEPS, GRID_SIZE)
                check(terrain.size == (GRID_STEPS + 1) * (GRID_STEPS + 1)) {
                    "World terrain grid has an unexpected sample count: ${terrain.size}"
                }
                Snapshot(
                    terrain = terrain,
                    camps = decodePoints(current.campPositions(), "camps"),
                    objectives = decodePoints(current.objectivePositions(), "objectives"),
                    trees = decodePoints(current.forestTreePositions(), "forest trees"),
                    groves = decodePoints(current.jungleGrovePositions(), "jungle groves"),
                    undergrowth = decodePoints(current.undergrowthPositions(), "undergrowth"),
                    islandMask = current.islandMask(GRID_STEPS, GRID_SIZE).also {
                        check(it.size == GRID_STEPS * GRID_STEPS) {
                            "World island mask has an unexpected sample count: ${it.size}"
                        }
                    }
                ).also { cachedSnapshot = it }
            }
        }
    }

    /** Allows JVM tests to supply deterministic world data without loading Android JNI. */
    @Synchronized
    internal fun installSourceForTests(testSource: ArenaWorldDataSource) {
        source = testSource
        cachedSnapshot = null
    }

    @Synchronized
    internal fun restoreNativeSource() {
        source = NativeArenaWorldDataSource
        cachedSnapshot = null
    }

    fun initialize() {
        snapshot()
    }

    fun heightAt(x: Float, z: Float): Float {
        val grid = snapshot().terrain
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
        source.laneCenterX(lane.coerceIn(0, 2), z)

    fun towerZ(team: Int, tier: Int): Float =
        source.towerZ(team.coerceIn(0, 1), tier.coerceIn(0, 2))

    fun riverCenterZ(x: Float): Float = source.riverCenterZ(x)

    fun insideIsland(x: Float, z: Float): Boolean {
        val gx = ((x - GRID_START) / GRID_CELL - 0.5f).roundToInt().coerceIn(0, GRID_STEPS - 1)
        val gz = ((z - GRID_START) / GRID_CELL - 0.5f).roundToInt().coerceIn(0, GRID_STEPS - 1)
        return snapshot().islandMask[gz * GRID_STEPS + gx]
    }

    fun campPositions(): List<ArenaPoint> = snapshot().camps
    fun objectivePositions(): List<ArenaPoint> = snapshot().objectives
    fun forestTreePositions(): List<ArenaPoint> = snapshot().trees
    fun jungleGrovePositions(): List<ArenaPoint> = snapshot().groves
    fun undergrowthPositions(): List<ArenaPoint> = snapshot().undergrowth

    private fun decodePoints(values: FloatArray, label: String): List<ArenaPoint> {
        check(values.isNotEmpty() && values.size % 2 == 0) {
            "World $label layout is malformed: ${values.size} values"
        }
        return values.asList().chunked(2).map { ArenaPoint(it[0], it[1]) }
    }
}
