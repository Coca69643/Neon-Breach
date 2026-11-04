package com.duckdream.neonbreach

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class NpcVisualCatalogTest {
    @Test
    fun botRosterUsesAllThreeHumanSilhouettesAcrossBothTeams() {
        val models = (0 until 9).map(NpcVisualCatalog::botModel)
        assertEquals(setOf(0, 1, 2), models.toSet())
        assertNotEquals(models.take(4), models.subList(4, 8))
    }

    @Test
    fun eachMinionWaveHasThreeDistinctBodiesAndAlternatingFourthRole() {
        val firstWave = (0 until 4).map(NpcVisualCatalog::minionModel)
        val secondWave = (4 until 8).map(NpcVisualCatalog::minionModel)
        assertEquals(setOf(0, 1, 2), firstWave.toSet())
        assertEquals(setOf(0, 1, 2), secondWave.toSet())
        assertNotEquals(firstWave[3], secondWave[3])
    }

    @Test
    fun minionRolesResolveToFourDifferentArmorSilhouettes() {
        assertEquals(setOf(0, 1, 3, 4), (0 until 4).map(NpcVisualCatalog::minionGearStyle).toSet())
        assertEquals(NpcVisualCatalog.minionGearStyle(0), NpcVisualCatalog.minionGearStyle(4))
        assertNotEquals(NpcVisualCatalog.minionGearStyle(0), NpcVisualCatalog.minionGearStyle(1))
    }

    @Test
    fun minionSilhouettesHaveDifferentProportions() {
        val widths = (0 until 4).map(NpcVisualCatalog::minionWidthFactor)
        val heights = (0 until 4).map(NpcVisualCatalog::minionHeightFactor)
        assertEquals(4, widths.toSet().size)
        assertEquals(4, heights.toSet().size)
        assertTrue(widths.all { it in 0.8f..1.2f })
        assertTrue(heights.all { it in 0.9f..1.2f })
    }

    @Test
    fun npcLocomotionSwitchesBetweenIdleWalkAndRun() {
        assertEquals(NpcLocomotion.IDLE, NpcVisualCatalog.locomotion(0f))
        assertEquals(NpcLocomotion.WALK, NpcVisualCatalog.locomotion(1.8f))
        assertEquals(NpcLocomotion.RUN, NpcVisualCatalog.locomotion(4.1f))
    }

    @Test
    fun minionRenderDistanceIsBoundedForMobileSceneBudget() {
        assertTrue(NpcVisualCatalog.MINION_RENDER_DISTANCE in 28f..40f)
    }
}
