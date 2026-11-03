package com.duckdream.neonbreach

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class HeroModelCatalogTest {
    @Test
    fun threePlayableHeroesUseDistinctCc0Assets() {
        assertEquals(3, HeroModelCatalog.models.size)
        assertEquals(3, HeroModelCatalog.models.map { it.assetPath }.distinct().size)
        assertEquals(listOf("heroes/lyra.glb", "heroes/bastion.glb", "heroes/kairo.glb"), HeroModelCatalog.models.map { it.assetPath })
    }

    @Test
    fun eachModelDefinesItsOwnHumanoidLocomotionNames() {
        val lyra = HeroModelCatalog.models[0]
        val bastion = HeroModelCatalog.models[1]
        val kairo = HeroModelCatalog.models[2]
        assertTrue(lyra.idleClip.startsWith("Female_") && lyra.walkClip.startsWith("Female_"))
        assertTrue(bastion.idleClip.startsWith("Man_") && bastion.runClip.startsWith("Man_"))
        assertTrue(kairo.idleClip.startsWith("Female_") && kairo.runClip.startsWith("Female_"))
    }

    @Test
    fun animatorNamesResolveWithOrWithoutRigPrefix() {
        val names = listOf("HumanArmature|Female_Idle", "HumanArmature|Female_Walk", "HumanArmature|Female_Run")
        assertEquals(0, HeroModelCatalog.animationIndex(names, "Female_Idle"))
        assertEquals(1, HeroModelCatalog.animationIndex(names, "Female_Walk"))
        assertEquals(2, HeroModelCatalog.animationIndex(names, "Female_Run"))
        assertEquals(-1, HeroModelCatalog.animationIndex(names, "Female_SwordSlash"))
    }
}
