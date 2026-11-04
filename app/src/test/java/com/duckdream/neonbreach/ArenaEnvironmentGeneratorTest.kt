package com.duckdream.neonbreach

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class ArenaEnvironmentGeneratorTest {
    @Test
    fun outpostLayoutIsReproducibleForTheSameSeed() {
        assertEquals(ArenaEnvironmentGenerator.generate(1707), ArenaEnvironmentGenerator.generate(1707))
    }

    @Test
    fun fourOpenFieldPointsOfInterestUseOnlyBundledKayKitModels() {
        val props = ArenaEnvironmentGenerator.generate()
        assertEquals(32, props.size)
        assertEquals(4, props.count { it.model.startsWith("home_") || it.model.startsWith("church_") })
        assertEquals(4, props.count { it.model.startsWith("flag_") })
        assertEquals(24, props.count { it.model == "fence_wood" })
        assertTrue(props.all { kotlin.math.abs(it.x) < 90f && kotlin.math.abs(it.z) < 80f })
        assertTrue(props.map { it.model }.toSet().all {
            it == "fence_wood" || it == "flag_blue" || it == "flag_red" ||
                it == "home_blue" || it == "home_red" || it == "church_blue" || it == "church_red"
        })
    }

    @Test
    fun changingSeedChangesDecorationWithoutChangingGameplayRoutes() {
        val first = ArenaEnvironmentGenerator.generate(1707)
        val second = ArenaEnvironmentGenerator.generate(2026)
        assertNotEquals(first, second)
        assertEquals(3, ArenaMapDefinition.lanes.size)
        assertEquals(12, ArenaMapDefinition.camps.size)
    }
}
