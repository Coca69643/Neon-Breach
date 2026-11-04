package com.duckdream.neonbreach

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import kotlin.math.sqrt
import kotlin.math.tan
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.Base64

class WorldGlbBuilderTest {
    @Test
    fun remasteredTerrainHasReadableReliefAndWalkableGradients() {
        var low = Float.POSITIVE_INFINITY
        var high = Float.NEGATIVE_INFINITY
        var steepest = 0f
        for (x in -87..87 step 3) {
            for (z in -78..78 step 3) {
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
        assertTrue("Terrain gradient must stay below the 55-degree cliff threshold", steepest < tan(Math.toRadians(55.0)).toFloat())
        for (lane in ArenaMapDefinition.lanes) for (point in lane.points) {
            val routeNormal = WorldGlbBuilder.normalAt(point.x, point.z)
            val routeSlope = sqrt(routeNormal[0] * routeNormal[0] + routeNormal[2] * routeNormal[2]) /
                routeNormal[1].coerceAtLeast(0.0001f)
            assertTrue("Lane waypoint exceeds the walkable 43-degree cap",
                routeSlope < tan(Math.toRadians(43.0)).toFloat())
        }
    }

    @Test
    fun terrainGlbEmbedsFourPbrSurfacePairsAndTerrainUvCoordinates() {
        val pixel = Base64.getDecoder().decode(
            "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/cZkAAAAASUVORK5CYII="
        )
        val textures = TerrainTextureSet(
            albedo = List(4) { pixel },
            normal = List(4) { pixel }
        )
        val bytes = WorldGlbBuilder.build(textures)
        val glb = ByteBuffer.wrap(bytes).order(ByteOrder.LITTLE_ENDIAN)
        val jsonLength = glb.getInt(12)
        val json = String(bytes, 20, jsonLength, Charsets.UTF_8)
        assertEquals(8, "\"mimeType\":\"image/png\"".toRegex().findAll(json).count())
        assertTrue(json.contains("\"grass_albedo\""))
        assertTrue(json.contains("\"rock_normal\""))
        assertTrue(json.contains("\"TEXCOORD_0\""))
        assertTrue(json.contains("\"baseColorTexture\":{\"index\":0}"))
        assertTrue(json.contains("\"baseColorTexture\":{\"index\":1}"))
        assertTrue(json.contains("\"baseColorTexture\":{\"index\":2}"))
        assertTrue(json.contains("\"baseColorTexture\":{\"index\":3}"))
        assertTrue(json.contains("\"normalTexture\":{\"index\":4,\"scale\":0.68}"))
        assertTrue(json.contains("\"normalTexture\":{\"index\":7,\"scale\":0.68}"))
    }

    @Test
    fun riverUsesNaturalBanksWithoutBrightGlintsOrIslandMoat() {
        val bytes = WorldGlbBuilder.build()
        val glb = ByteBuffer.wrap(bytes).order(ByteOrder.LITTLE_ENDIAN)
        val jsonLength = glb.getInt(12)
        val json = String(bytes, 20, jsonLength, Charsets.UTF_8)
        listOf("crossing_river", "river_shallows", "river_sandbanks")
            .forEach { layer -> assertTrue("Missing river geometry layer: $layer", json.contains(layer)) }
        assertFalse("Bright river glint ribbons must be removed", json.contains("\"name\":\"river_flow_glints\""))
        assertFalse("Island moat geometry must be removed", json.contains("\"name\":\"surrounding_water\""))
        assertFalse("Island rim geometry must be removed", json.contains("\"name\":\"island_rock_rim\""))
    }

    @Test
    fun terrainGlbNoLongerEmbedsProceduralNatureOrRockClusters() {
        val bytes = WorldGlbBuilder.build()
        val glb = ByteBuffer.wrap(bytes).order(ByteOrder.LITTLE_ENDIAN)
        assertEquals(0x46546c67, glb.getInt(0))
        assertEquals(2, glb.getInt(4))
        assertEquals(bytes.size, glb.getInt(8))
        val jsonLength = glb.getInt(12)
        val json = String(bytes, 20, jsonLength, Charsets.UTF_8)
        listOf(
            "fern_leaves", "meadow_flower_stems", "meadow_flower_petals",
            "camp_mushroom_stems", "camp_mushroom_caps", "fallen_timber",
            "field_boulders", "undergrowth"
        ).forEach { name ->
            assertFalse("Procedural nature must be moved to baked textured GLBs: $name", json.contains(name))
        }
        listOf(
            "Neutral camp markers", "Forest soil", "Objective shrine",
            "River water", "River shallows", "River sandbanks", "Water shimmer"
        ).forEach { name -> assertTrue("Missing gameplay/environment layer: $name", json.contains(name)) }
        assertEquals("Terrain GLB must retain only its 20 terrain/gameplay materials", 20,
            "\"pbrMetallicRoughness\"".toRegex().findAll(json).count())
    }
}
