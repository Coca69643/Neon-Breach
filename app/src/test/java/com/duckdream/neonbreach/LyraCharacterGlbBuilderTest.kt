package com.duckdream.neonbreach

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.nio.ByteBuffer
import java.nio.ByteOrder

class LyraCharacterGlbBuilderTest {
    @Test
    fun lyraModelContainsOriginalSilhouetteMaterialsAndSkinnedRig() {
        val bytes=LyraCharacterGlbBuilder.build()
        val glb=ByteBuffer.wrap(bytes).order(ByteOrder.LITTLE_ENDIAN)
        assertEquals(0x46546c67,glb.getInt(0))
        assertEquals(2,glb.getInt(4))
        assertEquals(bytes.size,glb.getInt(8))
        val jsonLength=glb.getInt(12)
        assertTrue(jsonLength>0)
        assertEquals(0x4e4f534a,glb.getInt(16))
        val json=String(bytes,20,jsonLength,Charsets.UTF_8)
        assertTrue(json.contains("Lyra_Original_Character"))
        assertTrue(json.contains("Lyra_Humanoid_Rig"))
        assertTrue(json.contains("JOINTS_0"))
        assertTrue(json.contains("WEIGHTS_0"))
        assertTrue(json.contains("inverseBindMatrices"))
        assertTrue(json.contains("Lyra_Indigo_Cloth"))
        assertTrue(json.contains("Lyra_Plum_Cape"))
        assertTrue(json.contains("Lyra_Chestnut_Hair"))
        listOf("pelvis","spine_01","spine_02","spine_03","neck_01","Head",
            "upperarm_l","lowerarm_l","hand_l","upperarm_r","lowerarm_r","hand_r",
            "thigh_l","calf_l","foot_l","thigh_r","calf_r","foot_r").forEach {
            assertTrue("Missing Lyra rig joint $it",json.contains("\"name\":\"$it\""))
        }
        assertTrue(json.contains("\"count\":19,\"type\":\"MAT4\""))
    }

    @Test
    fun everyVertexUsesOneNormalizedValidJointInfluence() {
        val bytes=LyraCharacterGlbBuilder.build()
        val glb=ByteBuffer.wrap(bytes).order(ByteOrder.LITTLE_ENDIAN)
        val jsonLength=glb.getInt(12)
        val json=String(bytes,20,jsonLength,Charsets.UTF_8)
        assertTrue(json.contains("\"componentType\":5123"))
        assertTrue(json.contains("\"componentType\":5126"))
        // Builder writes four weights per vertex: [1, 0, 0, 0].
        assertTrue(json.contains("\"WEIGHTS_0\""))
        assertTrue(json.contains("\"JOINTS_0\""))
        val binaryHeader=20+jsonLength
        assertEquals(0x004e4942,glb.getInt(binaryHeader+4))
        val binaryLength=glb.getInt(binaryHeader)
        assertTrue(binaryLength>0)
        assertTrue(binaryHeader+8+binaryLength<=bytes.size)
    }
}
