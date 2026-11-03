package com.duckdream.neonbreach

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import kotlin.math.cos
import kotlin.math.sin

class HumanoidRigPoseTest {
    private data class Q(val x: Double, val y: Double, val z: Double, val w: Double) {
        operator fun times(other: Q): Q = Q(
            w * other.x + x * other.w + y * other.z - z * other.y,
            w * other.y - x * other.z + y * other.w + z * other.x,
            w * other.z + x * other.y - y * other.x + z * other.w,
            w * other.w - x * other.x - y * other.y - z * other.z
        )

        fun rotate(v: DoubleArray): DoubleArray {
            val vector = this * Q(v[0], v[1], v[2], 0.0) * Q(-x, -y, -z, w)
            return doubleArrayOf(vector.x, vector.y, vector.z)
        }
    }

    private fun rotationZ(angle: Double): Q =
        Q(0.0, 0.0, sin(angle * 0.5), cos(angle * 0.5))

    private fun armDirection(left: Boolean): DoubleArray {
        // Bind-pose rotations read from the checked-in Quaternius GLB rig.
        val root = Q(-0.707106769, 0.0, 0.0, 0.707106769)
        val pelvis = Q(0.800571024, 0.0, 0.0, 0.599237919)
        val spine1 = Q(-0.091856197, 0.0, 0.0, 0.995772302)
        val spine2 = Q(-0.039585352, 0.0, 0.0, 0.999216199)
        val spine3 = Q(-0.124188989, 0.0, 0.0, 0.992258549)
        val clavicle = if (left) {
            Q(-0.528737425, -0.329101920, -0.413808048, 0.663996696)
        } else {
            Q(-0.528737425, 0.329101920, 0.413808048, 0.663996696)
        }
        val upperArm = if (left) {
            Q(0.149803027, 0.691130757, -0.149388447, 0.691071928)
        } else {
            Q(0.149803013, -0.691130758, 0.149388448, 0.691071928)
        }
        val sign = HumanoidRigPose.lateralSign(if (left) "upperarm_l" else "upperarm_r")
        val localAngle = HumanoidRigPose.localFlexion(0.62, sign).toDouble()
        val world = root * pelvis * spine1 * spine2 * spine3 * clavicle * upperArm * rotationZ(localAngle)
        return world.rotate(doubleArrayOf(0.0, 1.0, 0.0))
    }

    @Test
    fun mirroredLocalZFlexionLowersBothArms() {
        assertEquals(2, HumanoidRigPose.FLEXION_AXIS)
        assertEquals(-0.62f, HumanoidRigPose.localFlexion(0.62f, HumanoidRigPose.lateralSign("upperarm_l")), 0.0001f)
        assertEquals(0.62f, HumanoidRigPose.localFlexion(0.62f, HumanoidRigPose.lateralSign("upperarm_r")), 0.0001f)

        val left = armDirection(left = true)
        val right = armDirection(left = false)
        assertTrue("Left arm must angle downward from the T-pose", left[1] < -0.40)
        assertTrue("Right arm must angle downward from the T-pose", right[1] < -0.40)
        assertTrue("Left arm must remain on the left side", left[0] > 0.70)
        assertTrue("Right arm must remain on the right side", right[0] < -0.70)
    }
}
