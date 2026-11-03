package com.duckdream.neonbreach

import kotlin.math.*

/**
 * Deterministic JVM-only fixture. Its samples mirror the native world contract;
 * runtime builds continue to use JNI as the authoritative implementation.
 */
internal object ArenaWorldTestFixture : ArenaWorldDataSource {
    private val river = arrayOf(
        floatArrayOf(-34f, 1.1f), floatArrayOf(-28f, 0.55f),
        floatArrayOf(-21f, 0.05f), floatArrayOf(-15f, -0.45f),
        floatArrayOf(-9f, -0.22f), floatArrayOf(-3f, 0.25f),
        floatArrayOf(4f, 0.38f), floatArrayOf(10f, 0.02f),
        floatArrayOf(16f, -0.38f), floatArrayOf(23f, -0.18f),
        floatArrayOf(29f, 0.22f), floatArrayOf(34f, 0.8f)
    )

    private val baseLandmarks = floatArrayOf(
        0f, -27.3f, 0f, 27.3f,
        -4.5f, -24f, 4.5f, -24f, -4.5f, 24f, 4.5f, 24f,
        -8f, -25.3f, 8f, 25.3f,
        -7f, -24.2f, 7f, -24.2f, -7f, 24.2f, 7f, 24.2f,
        0f, -27f, 0f, 27f
    )
    private val camps = floatArrayOf(
        -8.2f, -14.5f, 8.2f, -14.5f, -20.2f, -10f, 20.2f, -10f,
        -8.2f, 14.5f, 8.2f, 14.5f, -20.2f, 10f, 20.2f, 10f
    )
    private val objectives = floatArrayOf(-7f, 0.2f, 7f, 0.2f)
    private val trees = floatArrayOf(
        -10.5f,-23f, -6.2f,-22f, -11.5f,-17.5f, -5.5f,-17f,
        -10.2f,-10f, -6.4f,-8f, 10.5f,-23f, 6.2f,-22f,
        11.5f,-17.5f, 5.5f,-17f, 10.2f,-10f, 6.4f,-8f,
        -22.8f,-18f, -26f,-13f, -22.4f,-6f, -18.5f,-20f,
        22.8f,-18f, 26f,-13f, 22.4f,-6f, 18.5f,-20f,
        -10.5f,23f, -6.2f,22f, -11.5f,17.5f, -5.5f,17f,
        -10.2f,10f, -6.4f,8f, 10.5f,23f, 6.2f,22f,
        11.5f,17.5f, 5.5f,17f, 10.2f,10f, 6.4f,8f
    )
    private val groves = floatArrayOf(
        -25f,-19f, -27f,-8f, -23f,8f, -26f,19f,
        25f,-19f, 27f,-8f, 23f,8f, 26f,19f,
        -8.5f,-21f, 8.5f,-21f, -8.5f,21f, 8.5f,21f
    )
    private val undergrowth = FloatArray(56 * 2).also { out ->
        for (i in 0 until 56) {
            val base = when (i % 4) {
                0 -> -10.1f
                1 -> -6.1f
                2 -> 6.1f
                else -> 10.1f
            }
            out[i * 2] = base + sin(i * 1.71f) * 0.82f
            out[i * 2 + 1] = -22f + (i / 4) * 3.15f
        }
    }

    override fun terrainGrid(steps: Int, size: Float): FloatArray {
        val stride = steps + 1
        val start = -size * 0.5f
        val cell = size / steps
        return FloatArray(stride * stride) { index ->
            val x = start + (index % stride) * cell
            val z = start + (index / stride) * cell
            terrainHeight(x, z)
        }
    }

    override fun laneCenterGrid(steps: Int, size: Float): FloatArray {
        val stride = steps + 1
        val start = -size * 0.5f
        val cell = size / steps
        return FloatArray(3 * stride) { index ->
            val lane = index / stride
            val zIndex = index % stride
            laneCenterX(lane, start + zIndex * cell)
        }
    }

    private fun laneCenterX(lane: Int, z: Float): Float {
        val bend = sin((z + 4f) * 0.105f) * 1.15f
        return when (lane) {
            0 -> -14.2f + bend
            1 -> 0.5f + sin(z * 0.12f) * 0.72f
            else -> 14.2f - bend * 0.82f
        }
    }

    override fun towerZ(team: Int, tier: Int): Float {
        val depth = when (tier) { 0 -> 8f; 1 -> 15f; else -> 22f }
        return if (team == 0) -depth else depth
    }

    override fun riverCenterZ(x: Float): Float {
        for (i in 0 until river.lastIndex) {
            val a = river[i]
            val b = river[i + 1]
            if (x <= b[0]) {
                val t = ((x - a[0]) / (b[0] - a[0])).coerceIn(0f, 1f)
                return a[1] + (b[1] - a[1]) * t
            }
        }
        return river.last()[1]
    }

    override fun islandMask(steps: Int, size: Float): BooleanArray {
        val start = -size * 0.5f
        val cell = size / steps
        return BooleanArray(steps * steps) { index ->
            val x = start + ((index % steps) + 0.5f) * cell
            val z = start + ((index / steps) + 0.5f) * cell
            val angle = atan2(z / 31f, x / 35f)
            val edge = 1f + 0.035f * sin(angle * 5f) +
                0.020f * sin(angle * 9f + 1.4f) + 0.012f * cos(angle * 13f)
            val radius = sqrt((x / 35f).pow(2) + (z / 31f).pow(2))
            radius <= edge
        }
    }

    override fun baseLandmarkPositions() = baseLandmarks.copyOf()
    override fun campPositions() = camps.copyOf()
    override fun objectivePositions() = objectives.copyOf()
    override fun forestTreePositions() = trees.copyOf()
    override fun jungleGrovePositions() = groves.copyOf()
    override fun undergrowthPositions() = undergrowth.copyOf()

    private fun terrainHeight(x: Float, z: Float): Float {
        val west = 2.35f * exp(-((x + 24f).pow(2)) / 44f) *
            (0.58f + 0.42f * cos(z * 0.075f))
        val east = 2.18f * exp(-((x - 24f).pow(2)) / 48f) *
            (0.58f + 0.42f * cos(z * 0.07f))
        val south = 1.55f * exp(-((z + 27f).pow(2)) / 36f) * exp(-(x.pow(2)) / 420f)
        val north = 1.55f * exp(-((z - 27f).pow(2)) / 36f) * exp(-(x.pow(2)) / 420f)
        val ax = abs(x)
        val az = abs(z)
        val knoll = 0.78f * exp(-((ax - 8.5f).pow(2)) / 8.5f) *
            exp(-((az - 14f).pow(2)) / 42f)
        val riverDistance = abs(z - riverCenterZ(x))
        val bed = -0.58f * exp(-(riverDistance * riverDistance) / 8.5f)
        val bank = 0.72f * exp(-((riverDistance - 2.55f).pow(2)) / 1.9f)
        val rolling = 0.26f * sin(x * 0.18f) * cos(z * 0.14f) +
            0.16f * sin((x + z) * 0.29f)
        val shelf = 0.52f * exp(-((ax - 18.5f).pow(2)) / 5.5f) *
            exp(-((az - 13f).pow(2)) / 110f)
        return rolling + west + east + south + north + knoll + bed + bank + shelf
    }
}
