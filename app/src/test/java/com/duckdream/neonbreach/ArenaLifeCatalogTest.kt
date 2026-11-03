package com.duckdream.neonbreach

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import kotlin.math.abs

class ArenaLifeCatalogTest {
    @Test
    fun lifeCatalogContainsDistinctAmbientAndCampSpecies() {
        assertEquals(6, ArenaLifeCatalog.wildlife.size)
        assertEquals(8, ArenaLifeCatalog.campGuardians().size)
        assertEquals(setOf("deer", "wolf", "bird"), ArenaLifeCatalog.wildlife.map { it.species }.toSet())
        assertEquals(setOf("mushroom", "walking-tree", "ghost"),
            ArenaLifeCatalog.campGuardians().map { it.species }.toSet())
        assertTrue(ArenaLifeCatalog.campGuardians().all { it.kind == LifeActorKind.CAMP_GUARDIAN && it.campIndex in 0..7 })
        assertTrue(ArenaLifeCatalog.wildlife.all { it.kind == LifeActorKind.WILDLIFE && it.campIndex == -1 })
    }

    @Test
    fun neutralGuardiansExposeAttackClipAliases() {
        for (speciesId in listOf("mushroom", "walking-tree", "ghost")) {
            val profile = ArenaLifeCatalog.species.getValue(speciesId)
            assertTrue("$speciesId must define attack clip aliases", profile.attackTokens.isNotEmpty())
        }
        assertTrue(ArenaLifeCatalog.species.getValue("deer").attackTokens.isEmpty())
    }

    @Test
    fun wildlifePlacesAnAnimalInsideTheOpeningBlueSideCameraReach() {
        val initialPlayerX = -14f
        val initialPlayerZ = -25f
        val nearestDistance = ArenaLifeCatalog.wildlife.minOf { actor ->
            val dx = actor.x - initialPlayerX
            val dz = actor.z - initialPlayerZ
            kotlin.math.sqrt(dx * dx + dz * dz)
        }
        assertTrue(
            "At least one ambient animal must be near the opening camera; nearest distance=$nearestDistance",
            nearestDistance <= 8f
        )
    }

    @Test
    fun campGuardianLocationsMatchNativeCampSnapshotOrder() {
        val guardians = ArenaLifeCatalog.campGuardians()
        assertEquals(-8.2f, guardians[0].x, 0.001f)
        assertEquals(-14.5f, guardians[0].z, 0.001f)
        assertEquals(8.2f, guardians[1].x, 0.001f)
        assertEquals(14.5f, guardians[5].z, 0.001f)
        assertEquals(20.2f, guardians[7].x, 0.001f)
    }

    @Test
    fun wildlifeMovesAndRetreatsFromNearbyPlayer() {
        val deer = ArenaLifeCatalog.wildlife.first()
        val calm = ArenaLifeCatalog.sample(deer, 3.0f, 0f, 0f)
        val close = ArenaLifeCatalog.sample(deer, 3.0f, calm.x, calm.z)
        val later = ArenaLifeCatalog.sample(deer, 5.0f, 0f, 0f)
        assertTrue(calm.moving)
        assertTrue(abs(close.x - deer.x) + abs(close.z - deer.z) > 0.1f)
        assertTrue(abs(later.x - calm.x) + abs(later.z - calm.z) > 0.05f)
        assertTrue(calm.yaw.isFinite() && calm.heightOffset.isFinite())
    }

    @Test
    fun campGuardiansStayAnchoredButHaveIdleMotion() {
        val guardian = ArenaLifeCatalog.campGuardians()[2]
        val first = ArenaLifeCatalog.sample(guardian, 1f, 0f, 0f)
        val second = ArenaLifeCatalog.sample(guardian, 2f, 0f, 0f)
        assertEquals(guardian.x, first.x, 0f)
        assertEquals(guardian.z, first.z, 0f)
        assertNotEquals(first.yaw, second.yaw)
        assertNotEquals(first.heightOffset, second.heightOffset)
        assertTrue(!first.moving && !second.moving)
    }
}
