package com.duckdream.neonbreach

import org.junit.Assert.assertTrue
import org.junit.Test
import kotlin.math.hypot

class ArenaShowcaseLayoutTest {
    @Test
    fun previewClearingDoesNotOverlapMajorBattlefieldProps() {
        val props = buildList {
            for (laneX in listOf(-12f, 0f, 12f)) {
                for (z in listOf(-8f, -15f, -22f)) add(laneX to z)
            }
            addAll(listOf(
                -7f to 0.2f, 7f to 0.2f,
                -8.2f to -14.5f, 8.2f to -14.5f,
                -20.2f to -10f, 20.2f to -10f,
                -8.2f to 14.5f, 8.2f to 14.5f,
                -20.2f to 10f, 20.2f to 10f
            ))
        }
        val nearest = props.minOf { (x, z) ->
            hypot((ArenaShowcaseLayout.HERO_X - x).toDouble(),
                (ArenaShowcaseLayout.HERO_Z - z).toDouble())
        }
        assertTrue("Hero preview must not overlap towers, camps or shrines: nearest=$nearest", nearest > 7.5)
    }

    @Test
    fun heroPreviewIsFramedToTheRightOfTheInformationPanel() {
        assertTrue(ArenaShowcaseLayout.TARGET_X < ArenaShowcaseLayout.HERO_X)
        assertTrue(ArenaShowcaseLayout.SELECT_SCALE > ArenaShowcaseLayout.MENU_SCALE)
        assertTrue(ArenaShowcaseLayout.CAMERA_FOV in 28.0..36.0)
    }
}
