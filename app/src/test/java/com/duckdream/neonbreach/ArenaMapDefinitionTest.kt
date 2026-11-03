package com.duckdream.neonbreach

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class ArenaMapDefinitionTest {
    @Test
    fun battlefieldHasThreeContinuousLanesEightCampsAndTwoObjectives() {
        ArenaMapDefinition.validate()
        assertEquals(3, ArenaMapDefinition.lanes.size)
        assertTrue(ArenaMapDefinition.lanes.all { it.points.size == 9 })
        assertEquals(8, ArenaMapDefinition.camps.size)
        assertEquals(2, ArenaMapDefinition.objectives.size)
        assertEquals(32, ArenaMapDefinition.treeBlockers.size)
        assertEquals(12, ArenaMapDefinition.groveCenters.size)
    }

    @Test
    fun towerCoordinatesFollowTheirOwnLaneCurvesOnBothSides() {
        for (lane in 0..2) {
            for (tier in 0..2) {
                val blue = ArenaMapDefinition.towerPosition(0, lane, tier)
                val red = ArenaMapDefinition.towerPosition(1, lane, tier)
                assertEquals(ArenaMapDefinition.laneCenterX(lane, blue.z), blue.x, 0.0001f)
                assertEquals(ArenaMapDefinition.laneCenterX(lane, red.z), red.x, 0.0001f)
                assertEquals(blue.z, -red.z, 0.0001f)
            }
        }
    }

    @Test
    fun battlefieldScaleExpandsThePlayableFootprintWithoutChangingAuthoredCoordinates() {
        assertEquals(1.15f, ArenaMapDefinition.WORLD_SCALE, 0.0001f)
        assertTrue(ArenaMapDefinition.HALF_EXTENT_X * ArenaMapDefinition.WORLD_SCALE > 40f)
        assertTrue(ArenaMapDefinition.HALF_EXTENT_Z * ArenaMapDefinition.WORLD_SCALE > 35.5f)
        assertTrue(ArenaMapDefinition.WORLD_SCALE * ArenaMapDefinition.WORLD_SCALE > 1.32f)
    }

    @Test
    fun riverCrossingAndJungleCampCoordinatesStayInsideBattlefield() {
        ArenaMapDefinition.camps.forEach { camp ->
            assertTrue(kotlin.math.abs(camp.position.x) < ArenaMapDefinition.HALF_EXTENT_X)
            assertTrue(kotlin.math.abs(camp.position.z) < ArenaMapDefinition.HALF_EXTENT_Z)
        }
        ArenaMapDefinition.objectives.forEach { objective ->
            assertTrue(kotlin.math.abs(objective.position.x) < ArenaMapDefinition.HALF_EXTENT_X)
        }
    }
}
