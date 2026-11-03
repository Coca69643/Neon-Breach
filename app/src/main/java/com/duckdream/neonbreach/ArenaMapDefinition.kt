package com.duckdream.neonbreach

/**
 * Canonical Vale das Coroas battlefield coordinates.
 *
 * Keep render placements, minimap landmarks and native simulation coordinates
 * aligned with this catalog. Kotlin invariants are covered by ArenaMapDefinitionTest.
 */
internal object ArenaMapDefinition {
    data class Point(val x: Float, val z: Float)
    data class Lane(val id: Int, val width: Float, val points: List<Point>)
    data class Camp(val id: String, val position: Point, val kind: CampKind)
    enum class CampKind { SMALL, LARGE }
    data class Tower(val team: Int, val lane: Int, val tier: Int, val position: Point)
    data class Landmark(val id: String, val position: Point, val radius: Float)

    const val WORLD_SCALE = 1.15f
    const val HALF_EXTENT_X = 35f
    const val HALF_EXTENT_Z = 33f
    const val RIVER_WIDTH = 1.72f

    val lanes = listOf(
        Lane(0, 2.42f, listOf(
            Point(-14.2f,-31f), Point(-15.2f,-23f), Point(-14.6f,-15f),
            Point(-13.4f,-7f), Point(-13f,0f), Point(-13.7f,8f),
            Point(-14.8f,16f), Point(-14.2f,24f), Point(-14.2f,31f))),
        Lane(1, 2.36f, listOf(
            Point(0.5f,-31f), Point(0.1f,-23f), Point(-0.1f,-15f),
            Point(-0.25f,-7f), Point(0.5f,0f), Point(0.3f,8f),
            Point(-0.2f,16f), Point(0.4f,24f), Point(0.5f,31f))),
        Lane(2, 2.42f, listOf(
            Point(14.2f,-31f), Point(15.2f,-23f), Point(14.6f,-15f),
            Point(13.4f,-7f), Point(13f,0f), Point(13.7f,8f),
            Point(14.8f,16f), Point(14.2f,24f), Point(14.2f,31f)))
    )

    val camps = listOf(
        Camp("west_south", Point(-8.2f,-14.5f), CampKind.SMALL),
        Camp("east_south", Point(8.2f,-14.5f), CampKind.SMALL),
        Camp("deep_west_south", Point(-20.2f,-10f), CampKind.LARGE),
        Camp("deep_east_south", Point(20.2f,-10f), CampKind.LARGE),
        Camp("west_north", Point(-8.2f,14.5f), CampKind.SMALL),
        Camp("east_north", Point(8.2f,14.5f), CampKind.SMALL),
        Camp("deep_west_north", Point(-20.2f,10f), CampKind.LARGE),
        Camp("deep_east_north", Point(20.2f,10f), CampKind.LARGE)
    )

    val objectives = listOf(
        Landmark("west_sanctuary", Point(-7f,0.2f), 4.55f),
        Landmark("east_sanctuary", Point(7f,0.2f), 4.55f)
    )

    val groveCenters = listOf(
        Point(-25f,-19f), Point(-27f,-8f), Point(-23f,8f), Point(-26f,19f),
        Point(25f,-19f), Point(27f,-8f), Point(23f,8f), Point(26f,19f),
        Point(-8.5f,-21f), Point(8.5f,-21f), Point(-8.5f,21f), Point(8.5f,21f)
    )

    val treeBlockers = listOf(
        Point(-10.5f,-23f), Point(-6.2f,-22f), Point(-11.5f,-17.5f), Point(-5.5f,-17f),
        Point(-10.2f,-10f), Point(-6.4f,-8f), Point(10.5f,-23f), Point(6.2f,-22f),
        Point(11.5f,-17.5f), Point(5.5f,-17f), Point(10.2f,-10f), Point(6.4f,-8f),
        Point(-22.8f,-18f), Point(-26f,-13f), Point(-22.4f,-6f), Point(-18.5f,-20f),
        Point(22.8f,-18f), Point(26f,-13f), Point(22.4f,-6f), Point(18.5f,-20f),
        Point(-10.5f,23f), Point(-6.2f,22f), Point(-11.5f,17.5f), Point(-5.5f,17f),
        Point(-10.2f,10f), Point(-6.4f,8f), Point(10.5f,23f), Point(6.2f,22f),
        Point(11.5f,17.5f), Point(5.5f,17f), Point(10.2f,10f), Point(6.4f,8f)
    )

    fun laneCenterX(lane: Int, z: Float): Float {
        val points = lanes[lane.coerceIn(0, lanes.lastIndex)].points
        val sampleZ = z.coerceIn(points.first().z, points.last().z)
        for (index in 0 until points.lastIndex) {
            val a = points[index]
            val b = points[index + 1]
            if (sampleZ <= b.z) {
                val t = ((sampleZ - a.z) / (b.z - a.z)).coerceIn(0f, 1f)
                return a.x + (b.x - a.x) * t
            }
        }
        return points.last().x
    }

    fun towerPosition(team: Int, lane: Int, tier: Int): Point {
        val z = if (tier == 0) 8f else if (tier == 1) 15f else 22f
        val signedZ = if (team == 0) -z else z
        return Point(laneCenterX(lane, signedZ), signedZ)
    }

    fun validate() {
        require(lanes.size == 3 && lanes.all { it.points.size >= 2 })
        require(camps.size == 8 && camps.map { it.id }.toSet().size == camps.size)
        require(objectives.size == 2)
        require(WORLD_SCALE > 1f)
        require(lanes.all { lane -> lane.points.all { kotlin.math.abs(it.x) <= HALF_EXTENT_X && kotlin.math.abs(it.z) <= HALF_EXTENT_Z } })
        require(camps.all { kotlin.math.abs(it.position.x) < HALF_EXTENT_X && kotlin.math.abs(it.position.z) < HALF_EXTENT_Z })
    }
}
