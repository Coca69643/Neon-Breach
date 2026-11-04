package com.duckdream.neonbreach

import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.hypot
import kotlin.math.sin

/**
 * Seeded offline environment composition.
 * Uses bundled CC0 KayKit models. Same seed = same placements; no runtime network
 * calls or nondeterministic gameplay state are involved.
 */
internal object ArenaEnvironmentGenerator {
    data class Prop(val model: String, val x: Float, val z: Float, val scale: Float, val yaw: Float)
    private data class Site(val centerX: Float, val centerZ: Float, val quadrant: Int)

    private val sites = listOf(
        Site(-75f, -43f, 0),
        Site(-75f, 43f, 1),
        Site(75f, -43f, 2),
        Site(75f, 43f, 3)
    )

    private fun hash01(seed: Int, index: Int, channel: Int): Float {
        var value = seed xor (index * 0x45d9f3b) xor (channel * 0x119de1f3)
        value = value xor (value ushr 16)
        value *= 0x45d9f3b
        value = value xor (value ushr 16)
        return (value and Int.MAX_VALUE).toFloat() / Int.MAX_VALUE.toFloat()
    }

    private fun segmentDistance(x: Float, z: Float, ax: Float, az: Float, bx: Float, bz: Float): Float {
        val dx = bx - ax
        val dz = bz - az
        val denominator = (dx * dx + dz * dz).coerceAtLeast(0.0001f)
        val t = (((x - ax) * dx + (z - az) * dz) / denominator).coerceIn(0f, 1f)
        return hypot(x - (ax + dx * t), z - (az + dz * t))
    }

    private fun laneClear(x: Float, z: Float): Boolean = ArenaMapDefinition.lanes.all { lane ->
        var nearest = Float.POSITIVE_INFINITY
        for (index in 0 until lane.points.lastIndex) {
            val a = lane.points[index]
            val b = lane.points[index + 1]
            nearest = minOf(nearest, segmentDistance(x, z, a.x, a.z, b.x, b.z))
        }
        nearest >= lane.width * 0.5f + 7.0f
    }

    private fun riverClear(x: Float, z: Float): Boolean {
        var nearest = Float.POSITIVE_INFINITY
        for (index in 0 until ArenaMapDefinition.riverCenterline.lastIndex) {
            val a = ArenaMapDefinition.riverCenterline[index]
            val b = ArenaMapDefinition.riverCenterline[index + 1]
            nearest = minOf(nearest, segmentDistance(x, z, a.x, a.z, b.x, b.z))
        }
        return nearest >= 17.0f
    }

    private fun validSite(x: Float, z: Float): Boolean {
        if (kotlin.math.abs(x) > ArenaMapDefinition.HALF_EXTENT_X - 9f ||
            kotlin.math.abs(z) > ArenaMapDefinition.HALF_EXTENT_Z - 9f) return false
        if (!laneClear(x, z) || !riverClear(x, z)) return false
        if (ArenaMapDefinition.camps.any { hypot(x - it.position.x, z - it.position.z) < 22f }) return false
        if (ArenaMapDefinition.objectives.any { hypot(x - it.position.x, z - it.position.z) < it.radius + 10f }) return false
        if (ArenaWorld17Generated.bases.any { hypot(x - it.position.x, z - it.position.z) < 18f }) return false
        return true
    }

    fun generate(seed: Int = 1707): List<Prop> {
        val result = ArrayList<Prop>(32)
        for ((siteIndex, site) in sites.withIndex()) {
            var x = site.centerX
            var z = site.centerZ
            var found = false
            for (attempt in 0 until 16) {
                val angle = hash01(seed, siteIndex * 17 + attempt, 1) * (PI.toFloat() * 2f)
                val radius = 0.75f + hash01(seed, siteIndex * 17 + attempt, 2) * 3.2f
                val candidateX = site.centerX + cos(angle) * radius
                val candidateZ = site.centerZ + sin(angle) * radius
                if (validSite(candidateX, candidateZ)) {
                    x = candidateX
                    z = candidateZ
                    found = true
                    break
                }
            }
            check(found) { "Could not place deterministic outpost " + site.quadrant }

            val team = if (site.quadrant == 0 || site.quadrant == 3) "blue" else "red"
            val building = if (site.quadrant % 2 == 0) "home_" + team else "church_" + team
            val yaw = (hash01(seed, siteIndex, 3) * 4f).toInt() * (PI.toFloat() * 0.5f)
            result += Prop(building, x, z, if (building.startsWith("church")) 1.05f else 1.28f, yaw)
            result += Prop("flag_" + team, x + 4.5f, z - 3.5f, 1.12f, yaw)

            // Six short fence sections leave a broad entrance facing the arena.
            result += Prop("fence_wood", x - 5.4f, z + 5.3f, 1.55f, PI.toFloat() * 0.5f)
            result += Prop("fence_wood", x + 5.4f, z + 5.3f, 1.55f, PI.toFloat() * 0.5f)
            result += Prop("fence_wood", x - 5.4f, z - 5.3f, 1.55f, PI.toFloat() * 0.5f)
            result += Prop("fence_wood", x + 5.4f, z - 5.3f, 1.55f, PI.toFloat() * 0.5f)
            result += Prop("fence_wood", x - 7.9f, z, 1.45f, 0f)
            result += Prop("fence_wood", x + 7.9f, z, 1.45f, 0f)
        }
        return result
    }
}
