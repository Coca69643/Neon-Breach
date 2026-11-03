package com.duckdream.neonbreach

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.nio.ByteBuffer
import java.nio.ByteOrder
import org.json.JSONObject
import kotlin.math.sin

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
    fun everyVertexHasNormalizedBlendWeightsAndValidJointInfluences() {
        val bytes=LyraCharacterGlbBuilder.build()
        val glb=ByteBuffer.wrap(bytes).order(ByteOrder.LITTLE_ENDIAN)
        val jsonLength=glb.getInt(12)
        val json=String(bytes,20,jsonLength,Charsets.UTF_8)
        val root=JSONObject(json)
        val views=root.getJSONArray("bufferViews")
        val accessors=root.getJSONArray("accessors")
        val primitives=root.getJSONArray("meshes").getJSONObject(0).getJSONArray("primitives")
        val binaryStart=20+jsonLength+8
        val data=ByteBuffer.wrap(bytes).order(ByteOrder.LITTLE_ENDIAN)
        var blendedVertices=0
        var checkedVertices=0

        for(primitiveIndex in 0 until primitives.length()){
            val attributes=primitives.getJSONObject(primitiveIndex).getJSONObject("attributes")
            val jointAccessor=accessors.getJSONObject(attributes.getInt("JOINTS_0"))
            val weightAccessor=accessors.getJSONObject(attributes.getInt("WEIGHTS_0"))
            val jointView=views.getJSONObject(jointAccessor.getInt("bufferView"))
            val weightView=views.getJSONObject(weightAccessor.getInt("bufferView"))
            val jointStart=binaryStart+jointView.optInt("byteOffset",0)+jointAccessor.optInt("byteOffset",0)
            val weightStart=binaryStart+weightView.optInt("byteOffset",0)+weightAccessor.optInt("byteOffset",0)
            val count=weightAccessor.getInt("count")
            assertEquals(count,jointAccessor.getInt("count"))

            for(vertex in 0 until count){
                val jointOffset=jointStart+vertex*8
                val weightOffset=weightStart+vertex*16
                val joints=IntArray(4){data.getShort(jointOffset+it*2).toInt() and 0xffff}
                val weights=FloatArray(4){data.getFloat(weightOffset+it*4)}
                assertTrue("Joint index outside the 19-joint skin",joints.all{it in 0 until 19})
                assertTrue("Negative skin weight",weights.all{it>=0f})
                assertEquals("Vertex weights must sum to one",1f,weights.sum(),0.0001f)
                if(weights[1]>0.0001f)blendedVertices++
                checkedVertices++
            }
        }
        assertTrue("No vertices use secondary joint influences",blendedVertices>0)
        assertTrue("No skinned vertices were inspected",checkedVertices>500)
    }
    @Test
    fun lyraAerialArmBindAnglesFlexTowardTheTorso() {
        val leftSign = HumanoidRigPose.lateralSign("upperarm_l") * -1f
        val rightSign = HumanoidRigPose.lateralSign("upperarm_r") * -1f
        val leftAngle = HumanoidRigPose.localFlexion(0.52f, leftSign)
        val rightAngle = HumanoidRigPose.localFlexion(0.52f, rightSign)

        assertEquals(0.52f, leftAngle, 0.0001f)
        assertEquals(-0.52f, rightAngle, 0.0001f)
        assertTrue("Left upper arm must flex downward", -0.13f * sin(leftAngle) < 0f)
        assertTrue("Right upper arm must flex downward", 0.13f * sin(rightAngle) < 0f)
    }

}
