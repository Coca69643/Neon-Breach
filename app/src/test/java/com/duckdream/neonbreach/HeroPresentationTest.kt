package com.duckdream.neonbreach

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
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
    fun eachHeroHasDistinctNamedPaletteMatchingItsGlbMaterials() {
        val lyra = HeroMaterialPalette.forHero(0)
        val bastion = HeroMaterialPalette.forHero(1)
        val kairo = HeroMaterialPalette.forHero(2)
        assertEquals(setOf("shirt", "skin", "pants", "shoes", "socks", "hairbase", "hair", "eyes"), lyra.keys)
        assertEquals(setOf("shirt", "pants", "eyes", "skin", "hair"), bastion.keys)
        assertEquals(setOf("shirt", "skin", "pants", "shoes", "hairbase", "hair", "eyes"), kairo.keys)

        listOf(lyra, bastion, kairo).forEach { palette ->
            assertTrue(palette.values.toSet().size >= 5)
            palette.values.forEach { color ->
                assertTrue(color.r in 0f..1f)
                assertTrue(color.g in 0f..1f)
                assertTrue(color.b in 0f..1f)
                assertEquals(1f, color.a, 0f)
            }
        }
        assertTrue(HeroMaterialPalette.colorForMaterial("Skin", lyra)!!.r > 0.75f)
        assertTrue(HeroMaterialPalette.colorForMaterial("Shirt", lyra)!!.r > 0.6f)
        assertTrue(HeroMaterialPalette.colorForMaterial("Shirt", lyra)!!.r > HeroMaterialPalette.colorForMaterial("Shirt", lyra)!!.b)
        assertEquals(lyra["skin"], HeroMaterialPalette.colorForMaterial("Skin", lyra))
    }

    @Test
    fun npcTeamColorsNeverOverwriteNaturalSkin() {
        val blue = HeroMaterialPalette.forNpc(heroIndex = 0, team = 0, variation = 1)
        val red = HeroMaterialPalette.forNpc(heroIndex = 0, team = 1, variation = 1)
        assertNotEquals(blue["shirt"], red["shirt"])
        assertEquals(HeroMaterialPalette.forHero(0)["skin"], blue["skin"])
        assertEquals(HeroMaterialPalette.forHero(0)["skin"], red["skin"])
        assertTrue(HeroMaterialPalette.colorForMaterial("HairBase", blue) != null)
        assertTrue(HeroMaterialPalette.colorForMaterial("Eyes", blue) != null)
    }
}
