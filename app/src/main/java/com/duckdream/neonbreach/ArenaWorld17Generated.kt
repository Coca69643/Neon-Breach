package com.duckdream.neonbreach

/**
 * Generated from world/arena_world_1_7.json by tools/generate_arena_world_17.py.
 * Do not edit manually. Typed 1.7.0 world contract; runtime migration is staged separately.
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
    const val HALF_WIDTH_M = 90.0f
    const val HALF_DEPTH_M = 80.0f
    const val TERRAIN_VERTICES_X = 193
    const val TERRAIN_VERTICES_Z = 177
    const val MIN_HEIGHT_M = -4.0f
    const val MAX_HEIGHT_M = 22.0f
    const val MAX_WALKABLE_SLOPE_DEGREES = 28.0f
    const val RIVER_VALLEY_DEPTH_M = 5.5f
    const val BROAD_NOISE_SEED = 1701
    const val DETAIL_NOISE_SEED = 1702
    const val BROAD_NOISE_AMPLITUDE_M = 2.8f
    const val DETAIL_NOISE_AMPLITUDE_M = 0.65f
    const val ART_THEME = "stylized_medieval_fantasy"
    const val ENVIRONMENT_STYLE = "organic_sculpted_world"

    val elevationControls = listOf(
        ElevationControl("southwest_ridge", Point(-74.0f, -38.0f), 18.0f, 25.0f),
        ElevationControl("northwest_ridge", Point(-72.0f, 42.0f), 17.0f, 26.0f),
        ElevationControl("southeast_ridge", Point(74.0f, -36.0f), 20.0f, 26.0f),
        ElevationControl("northeast_ridge", Point(73.0f, 42.0f), 18.5f, 25.0f),
        ElevationControl("west_jungle_highland", Point(-35.0f, 8.0f), 9.0f, 28.0f),
        ElevationControl("east_jungle_highland", Point(35.0f, -8.0f), 10.0f, 28.0f),
        ElevationControl("central_river_valley", Point(0.0f, 3.0f), -3.0f, 40.0f)
    )
    val bases = listOf(
        Base("blue_base", 0, Point(0.0f, -73.0f), listOf(Gate("west", Point(-57.0f, -72.0f)), Gate("center", Point(0.0f, -72.0f)), Gate("east", Point(57.0f, -72.0f)))),
        Base("red_base", 1, Point(0.0f, 73.0f), listOf(Gate("west", Point(-56.0f, 72.0f)), Gate("center", Point(0.0f, 72.0f)), Gate("east", Point(60.0f, 72.0f))))
    )
    val lanes = listOf(
        Lane("west", 9.5f, listOf(Point(-57.0f, -72.0f), Point(-60.0f, -54.0f), Point(-56.0f, -36.0f), Point(-51.0f, -16.0f), Point(-52.0f, 4.0f), Point(-58.0f, 24.0f), Point(-60.0f, 48.0f), Point(-56.0f, 72.0f))),
        Lane("center", 10.0f, listOf(Point(0.0f, -72.0f), Point(3.0f, -54.0f), Point(5.0f, -36.0f), Point(1.0f, -16.0f), Point(-3.0f, 4.0f), Point(1.0f, 24.0f), Point(4.0f, 48.0f), Point(0.0f, 72.0f))),
        Lane("east", 9.5f, listOf(Point(57.0f, -72.0f), Point(55.0f, -54.0f), Point(54.0f, -36.0f), Point(60.0f, -16.0f), Point(63.0f, 4.0f), Point(58.0f, 24.0f), Point(55.0f, 48.0f), Point(60.0f, 72.0f)))
    )
    val river = listOf(
        RiverPoint(Point(-88.0f, -4.0f), 4.5f),
        RiverPoint(Point(-72.0f, -7.0f), 5.5f),
        RiverPoint(Point(-58.0f, -9.0f), 6.5f),
        RiverPoint(Point(-44.0f, -6.0f), 7.2f),
        RiverPoint(Point(-30.0f, -2.0f), 8.0f),
        RiverPoint(Point(-15.0f, 2.0f), 8.5f),
        RiverPoint(Point(0.0f, 4.0f), 8.0f),
        RiverPoint(Point(15.0f, 2.0f), 8.5f),
        RiverPoint(Point(30.0f, -2.0f), 8.0f),
        RiverPoint(Point(44.0f, -5.0f), 7.2f),
        RiverPoint(Point(60.0f, -4.0f), 6.5f),
        RiverPoint(Point(75.0f, 1.0f), 5.5f),
        RiverPoint(Point(88.0f, 5.0f), 4.5f)
    )
    val crossings = listOf(
        Crossing("west_bridge", "west", Point(-52.0f, -8.0f), 9.5f, 20.0f),
        Crossing("center_bridge", "center", Point(-1.5f, 3.8f), 10.0f, 22.0f),
        Crossing("east_bridge", "east", Point(61.0f, -3.7f), 9.5f, 18.0f)
    )
    val jungles = listOf(
        JungleRegion("west_jungle", listOf(Point(-48.0f, -46.0f), Point(-22.0f, -52.0f), Point(-12.0f, -31.0f), Point(-15.0f, -10.0f), Point(-12.0f, 12.0f), Point(-22.0f, 40.0f), Point(-35.0f, 48.0f), Point(-49.0f, 40.0f), Point(-54.0f, 14.0f), Point(-51.0f, -14.0f))),
        JungleRegion("east_jungle", listOf(Point(48.0f, -46.0f), Point(22.0f, -52.0f), Point(12.0f, -31.0f), Point(15.0f, -10.0f), Point(12.0f, 12.0f), Point(22.0f, 40.0f), Point(35.0f, 48.0f), Point(49.0f, 40.0f), Point(54.0f, 14.0f), Point(51.0f, -14.0f)))
    )
    val camps = listOf(
        Camp("west_camp_01", "west_jungle", Point(-34.0f, -38.0f), 1),
        Camp("west_camp_02", "west_jungle", Point(-26.0f, -28.0f), 1),
        Camp("west_camp_03", "west_jungle", Point(-41.0f, -12.0f), 2),
        Camp("west_camp_04", "west_jungle", Point(-25.0f, 12.0f), 1),
        Camp("west_camp_05", "west_jungle", Point(-35.0f, 32.0f), 2),
        Camp("west_camp_06", "west_jungle", Point(-29.0f, 40.0f), 1),
        Camp("east_camp_01", "east_jungle", Point(34.0f, -38.0f), 1),
        Camp("east_camp_02", "east_jungle", Point(26.0f, -28.0f), 1),
        Camp("east_camp_03", "east_jungle", Point(41.0f, -12.0f), 2),
        Camp("east_camp_04", "east_jungle", Point(25.0f, 12.0f), 1),
        Camp("east_camp_05", "east_jungle", Point(35.0f, 32.0f), 2),
        Camp("east_camp_06", "east_jungle", Point(29.0f, 40.0f), 1)
    )
    val objectives = listOf(
        Objective("west_neutral_objective", Point(-22.0f, -13.0f), 7.0f),
        Objective("east_neutral_objective", Point(22.0f, 13.0f), 7.0f)
    )
    val towerDepthsFromBase = floatArrayOf(18.0f, 38.0f, 58.0f)
    val navigationNodes = listOf(
        NavigationNode("blue_base", Point(0.0f, -73.0f)),
        NavigationNode("red_base", Point(0.0f, 73.0f)),
        NavigationNode("west_south", Point(-57.0f, -56.0f)),
        NavigationNode("west_bridge", Point(-52.0f, -8.0f)),
        NavigationNode("west_north", Point(-58.0f, 48.0f)),
        NavigationNode("center_south", Point(2.0f, -56.0f)),
        NavigationNode("center_bridge", Point(-1.5f, 3.8f)),
        NavigationNode("center_north", Point(2.0f, 48.0f)),
        NavigationNode("east_south", Point(56.0f, -56.0f)),
        NavigationNode("east_bridge", Point(61.0f, -3.7f)),
        NavigationNode("east_north", Point(57.0f, 48.0f)),
        NavigationNode("west_jungle_south", Point(-34.0f, -34.0f)),
        NavigationNode("west_jungle_north", Point(-34.0f, 33.0f)),
        NavigationNode("east_jungle_south", Point(34.0f, -34.0f)),
        NavigationNode("east_jungle_north", Point(34.0f, 33.0f)),
        NavigationNode("west_objective", Point(-22.0f, -13.0f)),
        NavigationNode("east_objective", Point(22.0f, 13.0f))
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
