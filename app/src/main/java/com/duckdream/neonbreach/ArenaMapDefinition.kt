package com.duckdream.neonbreach

import kotlin.math.sqrt

/**
 * Runtime compatibility adapter over the generated v1.7 world contract.
 * Coordinates are metres; ArenaWorld17Generated remains the sole authored source.
 */
internal object ArenaMapDefinition {
    data class Point(val x: Float, val z: Float)
    data class RiverPoint(val x: Float, val z: Float, val halfWidth: Float)
    data class Lane(val id: Int, val width: Float, val points: List<Point>)
    data class Camp(val id: String, val position: Point, val kind: CampKind)
    enum class CampKind { SMALL, LARGE }
    data class Tower(val team: Int, val lane: Int, val tier: Int, val position: Point)
    data class Landmark(val id: String, val position: Point, val radius: Float)

    const val WORLD_SCALE = 1.0f
    const val HALF_EXTENT_X = ArenaWorld17Generated.HALF_WIDTH_M
    const val HALF_EXTENT_Z = ArenaWorld17Generated.HALF_DEPTH_M

    private val sourceLanes = ArenaWorld17Generated.lanes
    val lanes: List<Lane> = sourceLanes.mapIndexed { index, lane ->
        Lane(index, lane.width, lane.waypoints.map { Point(it.x, it.z) })
    }

    val riverCenterline = ArenaWorld17Generated.river.map {
        RiverPoint(it.position.x, it.position.z, it.halfWidth)
    }

    private fun riverSegment(x: Float): Int {
        if (x <= riverCenterline.first().x) return 0
        for (index in 0 until riverCenterline.lastIndex) {
            if (x <= riverCenterline[index + 1].x) return index
        }
        return riverCenterline.lastIndex - 1
    }

    fun riverCenterZ(x: Float): Float {
        val index = riverSegment(x)
        val a = riverCenterline[index]
        val b = riverCenterline[index + 1]
        val t = ((x - a.x) / (b.x - a.x)).coerceIn(0f, 1f)
        return a.z + (b.z - a.z) * t
    }

    fun riverHalfWidth(x: Float): Float {
        val index = riverSegment(x)
        val a = riverCenterline[index]
        val b = riverCenterline[index + 1]
        val t = ((x - a.x) / (b.x - a.x)).coerceIn(0f, 1f)
        return a.halfWidth + (b.halfWidth - a.halfWidth) * t
    }

    val camps = ArenaWorld17Generated.camps.map { camp ->
        Camp(
            camp.id,
            Point(camp.position.x, camp.position.z),
            if (camp.tier <= 1) CampKind.SMALL else CampKind.LARGE
        )
    }

    val objectives = ArenaWorld17Generated.objectives.map {
        Landmark(it.id, Point(it.position.x, it.position.z), it.radius)
    }

    // Four authored collision trunks around every camp clearing; deterministic and shared by physics.
    // Two trunks per camp frame the neutral pocket without turning the map into continuous forest.
    private val treeOffsets = listOf(
        Point(-4.8f, -3.8f), Point(4.8f, 3.8f)
    )
    private val campTreeBlockers = camps.flatMap { camp ->
        treeOffsets.map { offset ->
            Point(camp.position.x + offset.x, camp.position.z + offset.z)
        }
    }
    val treeBlockers = campTreeBlockers
    val groveCenters = camps.map { it.position }

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

    private fun distance(a: Point, b: Point): Float {
        val dx = b.x - a.x
        val dz = b.z - a.z
        return sqrt(dx * dx + dz * dz)
    }

    fun towerPosition(team: Int, lane: Int, tier: Int): Point {
        require(team in 0..1 && lane in 0..2 && tier in ArenaWorld17Generated.towerDepthsFromBase.indices)
        val route = lanes[lane].points.let { if (team == 0) it else it.asReversed() }
        val base = ArenaWorld17Generated.bases.first { it.team == team }
        val gate = base.gates.first { it.id == sourceLanes[lane].id }.position
        var previous = Point(gate.x, gate.z)
        var remaining = ArenaWorld17Generated.towerDepthsFromBase[tier] - distance(
            Point(base.position.x, base.position.z), previous
        )
        for (point in route) {
            val current = Point(point.x, point.z)
            val segment = distance(previous, current)
            if (segment > 0.0001f && remaining <= segment) {
                val t = (remaining / segment).coerceIn(0f, 1f)
                return Point(
                    previous.x + (current.x - previous.x) * t,
                    previous.z + (current.z - previous.z) * t
                )
            }
            remaining -= segment
            previous = current
        }
        return route.last()
    }

    fun validate() {
        require(ArenaWorld17Generated.WORLD_ID == "project_arena_1_7")
        require(lanes.size == 3 && lanes.all { it.points.size == 8 && it.width in 9.5f..10f })
        require(riverCenterline.size == 13)
        require(riverCenterline.all { it.halfWidth in 4.5f..8.5f })
        require(camps.size == 12 && camps.map { it.id }.toSet().size == camps.size)
        require(objectives.size == 2)
        require(campTreeBlockers.size == 24)
        require(treeBlockers.size == 24)
        require(WORLD_SCALE == 1f)
    }
}
