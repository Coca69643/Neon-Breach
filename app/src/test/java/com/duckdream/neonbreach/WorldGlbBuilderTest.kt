package com.duckdream.neonbreach

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import kotlin.math.sqrt
import kotlin.math.tan
import java.nio.ByteBuffer
import java.nio.ByteOrder

class WorldGlbBuilderTest {
    @Test
    fun remasteredTerrainHasReadableReliefAndWalkableGradients() {
        var low = Float.POSITIVE_INFINITY
        var high = Float.NEGATIVE_INFINITY
        var steepest = 0f
        for (x in -30..30 step 2) {
            for (z in -28..28 step 2) {
                val px = x.toFloat()
                val pz = z.toFloat()
                val height = WorldGlbBuilder.heightAt(px, pz)
                val normal = WorldGlbBuilder.normalAt(px, pz)
                val slope = sqrt(normal[0] * normal[0] + normal[2] * normal[2]) /
                    normal[1].coerceAtLeast(0.0001f)
                assertTrue(height.isFinite())
                assertTrue(normal.all { it.isFinite() })
                low = minOf(low, height)
                high = maxOf(high, height)
                steepest = maxOf(steepest, slope)
            }
        }
        assertTrue("Terrain relief must exceed 3.2 world units", high - low > 3.2f)
        assertTrue("Playable terrain exceeds the 43-degree walkability cap", steepest < tan(Math.toRadians(43.0)).toFloat())
    }

    @Test
    fun worldGlbContainsBatchedForestFloraAndDistinctCampGroundcover() {
        val bytes = WorldGlbBuilder.build()
        val glb = ByteBuffer.wrap(bytes).order(ByteOrder.LITTLE_ENDIAN)
        assertEquals(0x46546c67, glb.getInt(0))
        assertEquals(2, glb.getInt(4))
        assertEquals(bytes.size, glb.getInt(8))
        val jsonLength = glb.getInt(12)
        assertTrue(jsonLength > 0)
        val json = String(bytes, 20, jsonLength, Charsets.UTF_8)
        listOf(
            "fern_leaves", "meadow_flower_stems", "meadow_flower_petals",
            "camp_mushroom_stems", "camp_mushroom_caps", "fallen_timber",
            "Neutral camp markers", "Forest soil", "River water"
        ).forEach { name ->
            assertTrue("Missing world GLB part/material: $name", json.contains(name))
        }
        assertTrue("World GLB should have the expanded 25-material palette", json.contains("Fallen timber"))
    }
}
