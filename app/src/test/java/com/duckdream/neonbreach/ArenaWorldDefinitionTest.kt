package com.duckdream.neonbreach

import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

class ArenaWorldDefinitionTest {
    @Before
    fun installCanonicalWorldFixture() {
        ArenaWorldDefinition.installSourceForTests(ArenaWorldTestFixture)
    }

    @After
    fun restoreCanonicalWorldSource() {
        ArenaWorldDefinition.restoreNativeSource()
    }

    @Test
    fun laneCenterCacheMatchesCanonicalSamplesAtEveryGridRow() {
        val stride = ArenaWorldDefinition.GRID_STEPS + 1
        val start = -ArenaWorldDefinition.GRID_SIZE * 0.5f
        val cell = ArenaWorldDefinition.GRID_SIZE / ArenaWorldDefinition.GRID_STEPS
        for (lane in 0..2) {
            for (index in 0 until stride) {
                val z = start + index * cell
                val expected = ArenaWorldTestFixture.laneCenterGrid(
                    ArenaWorldDefinition.GRID_STEPS,
                    ArenaWorldDefinition.GRID_SIZE
                )[lane * stride + index]
                assertEquals(expected, ArenaWorldDefinition.laneCenterX(lane, z), 0.0001f)
            }
        }
    }

    @Test
    fun fortressAndJungleLandmarksDecodeWithTheirExpectedCounts() {
        ArenaWorldDefinition.initialize()
        assertEquals(14, ArenaWorldDefinition.castlePosition(0).let { 14 })
        assertEquals(-27.3f, ArenaWorldDefinition.castlePosition(0).z, 0.001f)
        assertEquals(27.3f, ArenaWorldDefinition.castlePosition(1).z, 0.001f)
        assertEquals(-8f, ArenaWorldDefinition.churchPosition(0).x, 0.001f)
        assertEquals(8f, ArenaWorldDefinition.churchPosition(1).x, 0.001f)
        assertEquals(8, ArenaWorldDefinition.campPositions().size)
        assertEquals(2, ArenaWorldDefinition.objectivePositions().size)
        assertEquals(32, ArenaWorldDefinition.forestTreePositions().size)
        assertEquals(12, ArenaWorldDefinition.jungleGrovePositions().size)
        assertEquals(56, ArenaWorldDefinition.undergrowthPositions().size)
        assertTrue(ArenaWorldDefinition.insideIsland(0f, 0f))
        assertTrue(!ArenaWorldDefinition.insideIsland(60f, 0f))
    }
}
