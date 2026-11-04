package com.duckdream.neonbreach

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class ArenaMapDefinitionTest {
    @Test
    fun runtimeAdapterReflectsCanonicalWorldWithoutDuplicatedCoordinates() {
        ArenaMapDefinition.validate()
        assertEquals(1.0f, ArenaMapDefinition.WORLD_SCALE, 0f)
        assertEquals(90.0f, ArenaMapDefinition.HALF_EXTENT_X, 0f)
        assertEquals(80.0f, ArenaMapDefinition.HALF_EXTENT_Z, 0f)
        assertEquals(3, ArenaMapDefinition.lanes.size)
        assertTrue(ArenaMapDefinition.lanes.all { it.points.size == 8 && it.width in 9.5f..10f })
        assertEquals(12, ArenaMapDefinition.camps.size)
        assertEquals(2, ArenaMapDefinition.objectives.size)
        assertEquals(110, ArenaMapDefinition.treeBlockers.size)
        assertEquals(62, ArenaWorld17Generated.forestTreeAnchors.size)
        assertTrue(ArenaWorld17Generated.forestTreeAnchors.count { it.x < 0f } >= 25)
        assertTrue(ArenaWorld17Generated.forestTreeAnchors.count { it.x > 0f } >= 25)
        assertEquals(12, ArenaMapDefinition.groveCenters.size)
    }

    @Test
    fun towerCoordinatesFollowTheirOwnCurvedLaneForBothTeams() {
        for (lane in 0..2) for (tier in 0..2) {
            val blue = ArenaMapDefinition.towerPosition(0, lane, tier)
            val red = ArenaMapDefinition.towerPosition(1, lane, tier)
            assertEquals(ArenaMapDefinition.laneCenterX(lane, blue.z), blue.x, 0.001f)
            assertEquals(ArenaMapDefinition.laneCenterX(lane, red.z), red.x, 0.001f)
            assertTrue(kotlin.math.abs(blue.x) <= 90f && kotlin.math.abs(blue.z) <= 80f)
            assertTrue(kotlin.math.abs(red.x) <= 90f && kotlin.math.abs(red.z) <= 80f)
        }
    }

    @Test
    fun riverAndCampsRetainCanonicalWorldCoordinatesAndScale() {
        assertEquals(13, ArenaMapDefinition.riverCenterline.size)
        assertTrue(ArenaMapDefinition.riverCenterline.all {
            kotlin.math.abs(it.x) < ArenaMapDefinition.HALF_EXTENT_X &&
                kotlin.math.abs(it.z) < ArenaMapDefinition.HALF_EXTENT_Z &&
                it.halfWidth in 4.5f..8.5f
        })
        assertEquals(12, ArenaMapDefinition.camps.size)
        assertEquals(ArenaWorld17Generated.camps.first().position.x,
            ArenaMapDefinition.camps.first().position.x, 0f)
        assertEquals(ArenaWorld17Generated.camps.last().position.z,
            ArenaMapDefinition.camps.last().position.z, 0f)
    }
}
