package com.duckdream.neonbreach

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class ArenaWorld17GeneratedTest {
    @Test
    fun generatedWorldUsesApprovedEnvelopeAndTerrainResolution() {
        assertEquals("project_arena_1_7", ArenaWorld17Generated.WORLD_ID)
        assertEquals(90f, ArenaWorld17Generated.HALF_WIDTH_M)
        assertEquals(80f, ArenaWorld17Generated.HALF_DEPTH_M)
        assertEquals(193, ArenaWorld17Generated.TERRAIN_VERTICES_X)
        assertEquals(177, ArenaWorld17Generated.TERRAIN_VERTICES_Z)
        assertEquals(7, ArenaWorld17Generated.elevationControls.size)
    }

    @Test
    fun generatedLanesRiverAndCrossingsMatchTheCanonicalWorld() {
        assertEquals(3, ArenaWorld17Generated.lanes.size)
        assertTrue(ArenaWorld17Generated.lanes.all { it.waypoints.size == 8 && it.width >= 9.5f })
        assertEquals(13, ArenaWorld17Generated.river.size)
        assertEquals(3, ArenaWorld17Generated.crossings.size)
        assertTrue(ArenaWorld17Generated.river.all { it.halfWidth in 4.5f..8.5f })
    }

    @Test
    fun generatedJunglesCampsObjectivesAndNavigationArePresent() {
        assertEquals(2, ArenaWorld17Generated.jungles.size)
        assertEquals(12, ArenaWorld17Generated.camps.size)
        assertEquals(6, ArenaWorld17Generated.camps.count { it.regionId == "west_jungle" })
        assertEquals(6, ArenaWorld17Generated.camps.count { it.regionId == "east_jungle" })
        assertEquals(2, ArenaWorld17Generated.objectives.size)
        assertEquals(17, ArenaWorld17Generated.navigationNodes.size)
        assertEquals(26, ArenaWorld17Generated.navigationLinks.size)
    }
}
