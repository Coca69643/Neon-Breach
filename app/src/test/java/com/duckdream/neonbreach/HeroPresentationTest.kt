package com.duckdream.neonbreach

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import kotlin.math.PI

class HeroPresentationTest {
    @Test
    fun gameplayYawMatchesAllFourWorldDirections() {
        assertEquals(0f, HeroFacing.yawFromVelocity(0f, 1f), 0.0001f)
        assertEquals(PI.toFloat(), HeroFacing.yawFromVelocity(0f, -1f), 0.0001f)
        assertEquals((PI / 2.0).toFloat(), HeroFacing.yawFromVelocity(1f, 0f), 0.0001f)
        assertEquals((-PI / 2.0).toFloat(), HeroFacing.yawFromVelocity(-1f, 0f), 0.0001f)
    }

    @Test
    fun previewFacesCameraFromNegativeZSide() {
        assertEquals(PI.toFloat(), HeroFacing.SHOWCASE_YAW, 0.0001f)
    }

    @Test
    fun eachHeroHasDistinctMultiPartPaletteMatchingItsGlb() {
        val palettes = listOf(
            HeroMaterialPalette.forHero(0),
            HeroMaterialPalette.forHero(1),
            HeroMaterialPalette.forHero(2)
        )
        assertEquals(listOf(8, 5, 7), palettes.map { it.size })
        palettes.forEach { palette ->
            assertTrue(palette.map { it }.toSet().size >= 5)
            palette.forEach { color ->
                assertTrue(color.r in 0f..1f)
                assertTrue(color.g in 0f..1f)
                assertTrue(color.b in 0f..1f)
                assertEquals(1f, color.a, 0f)
            }
        }
    }
}
