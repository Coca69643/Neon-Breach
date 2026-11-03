package com.duckdream.neonbreach

import kotlin.math.floor
import kotlin.math.roundToInt

internal data class ArenaPoint(val x: Float, val z: Float)

/** Testable contract between the native world definition and Kotlin presentation. */
internal interface ArenaWorldDataSource {
    fun terrainGrid(steps: Int, size: Float): FloatArray
    fun laneCenterGrid(steps: Int, size: Float): FloatArray
    fun towerZ(team: Int, tier: Int): Float
    fun riverCenterZ(x: Float): Float
    fun islandMask(steps: Int, size: Float): BooleanArray
    fun baseLandmarkPositions(): FloatArray
    fun campPositions(): FloatArray
    fun objectivePositions(): FloatArray
    fun objectiveWallPositions(): FloatArray
    fun riverCrossingPositions(): FloatArray
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
    external fun nativeLaneCenterGrid(steps: Int, size: Float): FloatArray
    external fun nativeTowerZ(team: Int, tier: Int): Float
    external fun nativeRiverCenterZ(x: Float): Float
    external fun nativeIslandMask(steps: Int, size: Float): BooleanArray
    external fun nativeBaseLandmarkPositions(): FloatArray
    external fun nativeCampPositions(): FloatArray
    external fun nativeObjectivePositions(): FloatArray
    external fun nativeObjectiveWallPositions(): FloatArray
    external fun nativeRiverCrossingPositions(): FloatArray
    external fun nativeForestTreePositions(): FloatArray
    external fun nativeJungleGrovePositions(): FloatArray
    external fun nativeUndergrowthPositions(): FloatArray
}

private object NativeArenaWorldDataSource : ArenaWorldDataSource {
    override fun terrainGrid(steps: Int, size: Float) = ArenaWorldNative.nativeTerrainGrid(steps, size)
    override fun laneCenterGrid(steps: Int, size: Float) = ArenaWorldNative.nativeLaneCenterGrid(steps, size)
    override fun towerZ(team: Int, tier: Int) = ArenaWorldNative.nativeTowerZ(team, tier)
    override fun riverCenterZ(x: Float) = ArenaWorldNative.nativeRiverCenterZ(x)
    override fun islandMask(steps: Int, size: Float) = ArenaWorldNative.nativeIslandMask(steps, size)
    override fun baseLandmarkPositions() = ArenaWorldNative.nativeBaseLandmarkPositions()
    override fun campPositions() = ArenaWorldNative.nativeCampPositions()
    override fun objectivePositions() = ArenaWorldNative.nativeObjectivePositions()
    override fun objectiveWallPositions() = ArenaWorldNative.nativeObjectiveWallPositions()
    override fun riverCrossingPositions() = ArenaWorldNative.nativeRiverCrossingPositions()
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
        val laneCenters: FloatArray,
        val camps: List<ArenaPoint>,
        val objectives: List<ArenaPoint>,
        val objectiveWalls: List<ArenaPoint>,
        val riverCrossings: List<ArenaPoint>,
        val trees: List<ArenaPoint>,
        val groves: List<ArenaPoint>,
        val undergrowth: List<ArenaPoint>,
        val baseLandmarks: List<ArenaPoint>,
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
                val laneCenters = current.laneCenterGrid(GRID_STEPS, GRID_SIZE)
                check(laneCenters.size == 3 * (GRID_STEPS + 1)) {
                    "World lane-center grid has an unexpected sample count: ${laneCenters.size}"
                }
                Snapshot(
                    terrain = terrain,
                    laneCenters = laneCenters,
                    camps = decodePoints(current.campPositions(), "camps"),
                    objectives = decodePoints(current.objectivePositions(), "objectives"),
                    objectiveWalls = decodePoints(current.objectiveWallPositions(), "objective walls").also {
                        check(it.size == 4) { "World objective wall count mismatch: ${it.size}" }
                    },
                    riverCrossings = decodePoints(current.riverCrossingPositions(), "river crossings").also {
                        check(it.size == 3) { "World river crossing count mismatch: ${it.size}" }
                    },
                    trees = decodePoints(current.forestTreePositions(), "forest trees"),
                    groves = decodePoints(current.jungleGrovePositions(), "jungle groves"),
                    undergrowth = decodePoints(current.undergrowthPositions(), "undergrowth"),
                    baseLandmarks = decodePoints(current.baseLandmarkPositions(), "base landmarks").also {
                        check(it.size == 14) { "World base landmark count mismatch: ${it.size}" }
                    },
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

    fun laneCenterX(lane: Int, z: Float): Float {
        val index = lane.coerceIn(0, 2)
        val position = ((z - GRID_START) / GRID_CELL).coerceIn(0f, GRID_STEPS.toFloat())
        val lower = floor(position).toInt().coerceAtMost(GRID_STEPS - 1)
        val fraction = (position - lower).coerceIn(0f, 1f)
        val stride = GRID_STEPS + 1
        val samples = snapshot().laneCenters
        val a = samples[index * stride + lower]
        val b = samples[index * stride + lower + 1]
        return a + (b - a) * fraction
    }

    fun towerZ(team: Int, tier: Int): Float =
        source.towerZ(team.coerceIn(0, 1), tier.coerceIn(0, 2))

    fun riverCenterZ(x: Float): Float = source.riverCenterZ(x)

    fun insideIsland(x: Float, z: Float): Boolean {
        val gx = ((x - GRID_START) / GRID_CELL - 0.5f).roundToInt().coerceIn(0, GRID_STEPS - 1)
        val gz = ((z - GRID_START) / GRID_CELL - 0.5f).roundToInt().coerceIn(0, GRID_STEPS - 1)
        return snapshot().islandMask[gz * GRID_STEPS + gx]
    }

    fun castlePosition(team: Int): ArenaPoint = snapshot().baseLandmarks[team.coerceIn(0, 1)]
    fun homePosition(team: Int, side: Int): ArenaPoint =
        snapshot().baseLandmarks[2 + team.coerceIn(0, 1) * 2 + side.coerceIn(0, 1)]
    fun churchPosition(team: Int): ArenaPoint = snapshot().baseLandmarks[6 + team.coerceIn(0, 1)]
    fun baseWallPosition(team: Int, side: Int): ArenaPoint =
        snapshot().baseLandmarks[8 + team.coerceIn(0, 1) * 2 + side.coerceIn(0, 1)]
    fun baseGatePavingPosition(team: Int): ArenaPoint = snapshot().baseLandmarks[12 + team.coerceIn(0, 1)]

    fun campPositions(): List<ArenaPoint> = snapshot().camps
    fun objectivePositions(): List<ArenaPoint> = snapshot().objectives
    fun objectiveWallPositions(): List<ArenaPoint> = snapshot().objectiveWalls
    fun riverCrossingPositions(): List<ArenaPoint> = snapshot().riverCrossings
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
