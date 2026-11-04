package com.duckdream.neonbreach

/**
 * Generated from world/arena_world_1_7.json by tools/generate_arena_world_17.py.
 * Do not edit manually. This is the typed 1.7.0 world contract; runtime migration is staged separately.
 */
internal object ArenaWorld17Generated {
    data class Point(val x: Float, val z: Float)
    data class ElevationControl(val id: String, val position: Point, val height: Float, val radius: Float)
    data class Gate(val id: String, val position: Point)
    data class Base(val id: String, val team: Int, val position: Point, val gates: List<Gate>)
    data class Lane(val id: String, val width: Float, val waypoints: List<Point>)
    data class RiverPoint(val position: Point, val halfWidth: Float)
    data class Crossing(val id: String, val laneId: String, val position: Point, val deckWidth: Float, val span: Float)
    data class JungleRegion(val id: String, val boundary: List<Point>)
    data class Camp(val id: String, val regionId: String, val position: Point, val tier: Int)
    data class Objective(val id: String, val position: Point, val radius: Float)
    data class NavigationNode(val id: String, val position: Point)
    data class NavigationLink(val from: String, val to: String)

    const val WORLD_ID = "project_arena_1_7"
    const val HALF_WIDTH_M = 90f
    const val HALF_DEPTH_M = 80f
    const val TERRAIN_VERTICES_X = 193
    const val TERRAIN_VERTICES_Z = 177
    const val MIN_HEIGHT_M = -4f
    const val MAX_HEIGHT_M = 22f
    const val MAX_WALKABLE_SLOPE_DEGREES = 28f
    const val RIVER_VALLEY_DEPTH_M = 5.5f
    const val BROAD_NOISE_SEED = 1701
    const val DETAIL_NOISE_SEED = 1702
    const val BROAD_NOISE_AMPLITUDE_M = 2.8f
    const val DETAIL_NOISE_AMPLITUDE_M = 0.65f
    const val ART_THEME = "stylized_medieval_fantasy"
    const val ENVIRONMENT_STYLE = "organic_sculpted_world"

    val elevationControls = listOf(
        ElevationControl("southwest_ridge", Point(-74f, -38f), 18f, 25f),
        ElevationControl("northwest_ridge", Point(-72f, 42f), 17f, 26f),
        ElevationControl("southeast_ridge", Point(74f, -36f), 20f, 26f),
        ElevationControl("northeast_ridge", Point(73f, 42f), 18.5f, 25f),
        ElevationControl("west_jungle_highland", Point(-35f, 8f), 9f, 28f),
        ElevationControl("east_jungle_highland", Point(35f, -8f), 10f, 28f),
        ElevationControl("central_river_valley", Point(0f, 3f), -3f, 40f)
    )
    val bases = listOf(
        Base("blue_base", 0, Point(0f, -73f), listOf(Gate("west", Point(-57f, -72f)), Gate("center", Point(0f, -72f)), Gate("east", Point(57f, -72f)))),
        Base("red_base", 1, Point(0f, 73f), listOf(Gate("west", Point(-56f, 72f)), Gate("center", Point(0f, 72f)), Gate("east", Point(60f, 72f))))
    )
    val lanes = listOf(
        Lane("west", 9.5f, listOf(Point(-57f, -72f), Point(-60f, -54f), Point(-56f, -36f), Point(-51f, -16f), Point(-52f, 4f), Point(-58f, 24f), Point(-60f, 48f), Point(-56f, 72f))),
        Lane("center", 10f, listOf(Point(0f, -72f), Point(3f, -54f), Point(5f, -36f), Point(1f, -16f), Point(-3f, 4f), Point(1f, 24f), Point(4f, 48f), Point(0f, 72f))),
        Lane("east", 9.5f, listOf(Point(57f, -72f), Point(55f, -54f), Point(54f, -36f), Point(60f, -16f), Point(63f, 4f), Point(58f, 24f), Point(55f, 48f), Point(60f, 72f)))
    )
    val river = listOf(
        RiverPoint(Point(-88f, -4f), 4.5f),
        RiverPoint(Point(-72f, -7f), 5.5f),
        RiverPoint(Point(-58f, -9f), 6.5f),
        RiverPoint(Point(-44f, -6f), 7.2f),
        RiverPoint(Point(-30f, -2f), 8f),
        RiverPoint(Point(-15f, 2f), 8.5f),
        RiverPoint(Point(0f, 4f), 8f),
        RiverPoint(Point(15f, 2f), 8.5f),
        RiverPoint(Point(30f, -2f), 8f),
        RiverPoint(Point(44f, -5f), 7.2f),
        RiverPoint(Point(60f, -4f), 6.5f),
        RiverPoint(Point(75f, 1f), 5.5f),
        RiverPoint(Point(88f, 5f), 4.5f)
    )
    val crossings = listOf(
        Crossing("west_bridge", "west", Point(-52f, -8f), 9.5f, 20f),
        Crossing("center_bridge", "center", Point(-1.5f, 3.8f), 10f, 22f),
        Crossing("east_bridge", "east", Point(61f, -3.7f), 9.5f, 18f)
    )
    val jungles = listOf(
        JungleRegion("west_jungle", listOf(Point(-48f, -46f), Point(-22f, -52f), Point(-12f, -31f), Point(-15f, -10f), Point(-12f, 12f), Point(-22f, 40f), Point(-35f, 48f), Point(-49f, 40f), Point(-54f, 14f), Point(-51f, -14f))),
        JungleRegion("east_jungle", listOf(Point(48f, -46f), Point(22f, -52f), Point(12f, -31f), Point(15f, -10f), Point(12f, 12f), Point(22f, 40f), Point(35f, 48f), Point(49f, 40f), Point(54f, 14f), Point(51f, -14f)))
    )
    val camps = listOf(
        Camp("west_camp_01", "west_jungle", Point(-34f, -38f), 1),
        Camp("west_camp_02", "west_jungle", Point(-26f, -28f), 1),
        Camp("west_camp_03", "west_jungle", Point(-41f, -12f), 2),
        Camp("west_camp_04", "west_jungle", Point(-25f, 12f), 1),
        Camp("west_camp_05", "west_jungle", Point(-35f, 32f), 2),
        Camp("west_camp_06", "west_jungle", Point(-29f, 40f), 1),
        Camp("east_camp_01", "east_jungle", Point(34f, -38f), 1),
        Camp("east_camp_02", "east_jungle", Point(26f, -28f), 1),
        Camp("east_camp_03", "east_jungle", Point(41f, -12f), 2),
        Camp("east_camp_04", "east_jungle", Point(25f, 12f), 1),
        Camp("east_camp_05", "east_jungle", Point(35f, 32f), 2),
        Camp("east_camp_06", "east_jungle", Point(29f, 40f), 1)
    )
    val objectives = listOf(
        Objective("west_neutral_objective", Point(-22f, -13f), 7f),
        Objective("east_neutral_objective", Point(22f, 13f), 7f)
    )
    val towerDepthsFromBase = floatArrayOf(18f, 38f, 58f)
    val navigationNodes = listOf(
        NavigationNode("blue_base", Point(0f, -73f)),
        NavigationNode("red_base", Point(0f, 73f)),
        NavigationNode("west_south", Point(-57f, -56f)),
        NavigationNode("west_bridge", Point(-52f, -8f)),
        NavigationNode("west_north", Point(-58f, 48f)),
        NavigationNode("center_south", Point(2f, -56f)),
        NavigationNode("center_bridge", Point(-1.5f, 3.8f)),
        NavigationNode("center_north", Point(2f, 48f)),
        NavigationNode("east_south", Point(56f, -56f)),
        NavigationNode("east_bridge", Point(61f, -3.7f)),
        NavigationNode("east_north", Point(57f, 48f)),
        NavigationNode("west_jungle_south", Point(-34f, -34f)),
        NavigationNode("west_jungle_north", Point(-34f, 33f)),
        NavigationNode("east_jungle_south", Point(34f, -34f)),
        NavigationNode("east_jungle_north", Point(34f, 33f)),
        NavigationNode("west_objective", Point(-22f, -13f)),
        NavigationNode("east_objective", Point(22f, 13f))
    )
    val navigationLinks = listOf(
        NavigationLink("blue_base", "west_south"),
        NavigationLink("blue_base", "center_south"),
        NavigationLink("blue_base", "east_south"),
        NavigationLink("red_base", "west_north"),
        NavigationLink("red_base", "center_north"),
        NavigationLink("red_base", "east_north"),
        NavigationLink("west_south", "west_bridge"),
        NavigationLink("west_bridge", "west_north"),
        NavigationLink("center_south", "center_bridge"),
        NavigationLink("center_bridge", "center_north"),
        NavigationLink("east_south", "east_bridge"),
        NavigationLink("east_bridge", "east_north"),
        NavigationLink("west_south", "west_jungle_south"),
        NavigationLink("center_south", "west_jungle_south"),
        NavigationLink("west_jungle_south", "west_jungle_north"),
        NavigationLink("west_jungle_north", "west_north"),
        NavigationLink("center_north", "west_jungle_north"),
        NavigationLink("west_jungle_south", "west_objective"),
        NavigationLink("west_jungle_north", "west_objective"),
        NavigationLink("east_south", "east_jungle_south"),
        NavigationLink("center_south", "east_jungle_south"),
        NavigationLink("east_jungle_south", "east_jungle_north"),
        NavigationLink("east_jungle_north", "east_north"),
        NavigationLink("center_north", "east_jungle_north"),
        NavigationLink("east_jungle_south", "east_objective"),
        NavigationLink("east_jungle_north", "east_objective")
    )
}
