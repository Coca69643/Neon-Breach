package com.duckdream.neonbreach

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class ArenaNatureCatalogTest {
    @Test
    fun forestUsesThreeTreeSilhouettesAndSharedBushAsset() {
        assertEquals(32, ArenaNatureCatalog.trees.size)
        assertEquals(12, ArenaNatureCatalog.bushes.size)
        assertEquals(setOf("nature_tree_oak", "nature_tree_pine", "nature_tree_broadleaf"),
            ArenaNatureCatalog.trees.map { it.model }.toSet())
        assertTrue(ArenaNatureCatalog.bushes.all { it.model == "nature_bush" })
    }

    @Test
    fun foliagePlacementsStayInsideMapAndUseBoundedScales() {
        (ArenaNatureCatalog.trees + ArenaNatureCatalog.bushes).forEach { placement ->
            assertTrue(kotlin.math.abs(placement.x) < ArenaMapDefinition.HALF_EXTENT_X)
            assertTrue(kotlin.math.abs(placement.z) < ArenaMapDefinition.HALF_EXTENT_Z)
            assertTrue(placement.scale in 0.7f..1.3f)
            assertTrue(placement.yaw >= 0f)
        }
    }
}
