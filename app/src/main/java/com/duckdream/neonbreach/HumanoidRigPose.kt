package com.duckdream.neonbreach

/**
 * Axis contract for the Quaternius humanoid rig used by players, bots and lane units.
 *
 * Upper-arm child offsets point along local +Y, while the shoulder transforms place
 * the left/right arm directions along opposite world-space X axes. Lowering both arms
 * therefore requires a local-Z flexion with mirrored signs.
 */
internal object HumanoidRigPose {
    const val FLEXION_AXIS = 2

    fun lateralSign(jointName: String): Float = when {
        jointName.endsWith("_l") -> -1f
        jointName.endsWith("_r") -> 1f
        else -> 1f
    }

    fun localFlexion(angle: Float, lateralSign: Float): Float = angle * lateralSign
}
