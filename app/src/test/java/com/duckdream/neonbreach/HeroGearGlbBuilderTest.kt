package com.duckdream.neonbreach

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.nio.ByteBuffer
import java.nio.ByteOrder

class HeroGearGlbBuilderTest {
    @Test
    fun generatedGearGlbHasValidContainerAndBoneParts() {
        for (hero in 0..2) {
            for (team in 0..1) {
                val bytes = HeroGearGlbBuilder.build(hero, team)
                val glb = ByteBuffer.wrap(bytes).order(ByteOrder.LITTLE_ENDIAN)
                assertEquals(0x46546c67, glb.getInt(0))
                assertEquals(2, glb.getInt(4))
                assertEquals(bytes.size, glb.getInt(8))
                val jsonLength = glb.getInt(12)
                assertTrue(jsonLength > 0)
                assertEquals(0x4e4f534a, glb.getInt(16))
                val json = String(bytes, 20, jsonLength, Charsets.UTF_8)
                assertTrue(json.contains("DuckDreamStudios-HeroGear-0.15"))
                listOf(
                    "gear_torso", "gear_trim", "gear_head", "gear_head_trim", "gear_back",
                    "gear_shoulder_l", "gear_shoulder_r", "gear_forearm_l", "gear_forearm_r",
                    "gear_thigh_l", "gear_thigh_r", "gear_boot_l", "gear_boot_r"
                ).forEach { part -> assertTrue("Missing gear node $part", json.contains(part)) }
                val binHeader = 20 + jsonLength
                assertEquals(0x004e4942, glb.getInt(binHeader + 4))
                val binaryLength = glb.getInt(binHeader)
                assertTrue(binaryLength > 0)
                assertEquals(bytes.size, binHeader + 8 + binaryLength)
            }
        }
    }
}
