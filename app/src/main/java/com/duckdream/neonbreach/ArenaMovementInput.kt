package com.duckdream.neonbreach

import kotlin.math.sqrt

/**
 * Converts the on-screen joystick vector into world-space movement.
 *
 * Gameplay camera: it is positioned on world -Z and looks toward world +Z.
 * In that camera basis, screen-right points toward world -X, while screen-up
 * points toward world +Z. Android touch Y grows downward.
 *
 * Keep this conversion centralized: movement, dash direction and future
 * directional abilities must consume the same world-space vector.
 */
internal object ArenaMovementInput {
    data class WorldVector(val x: Float, val z: Float)

    private const val SCREEN_RIGHT_TO_WORLD_X = -1f
    private const val SCREEN_DOWN_TO_WORLD_Z = -1f

    fun fromScreenStick(
        screenX: Float,
        screenY: Float,
        sensitivity: Float = 1f
    ): WorldVector {
        val safeSensitivity = sensitivity.coerceIn(0f, 1.5f)
        var worldX = screenX.coerceIn(-1f, 1f) * SCREEN_RIGHT_TO_WORLD_X * safeSensitivity
        var worldZ = screenY.coerceIn(-1f, 1f) * SCREEN_DOWN_TO_WORLD_Z * safeSensitivity

        val magnitude = sqrt(worldX * worldX + worldZ * worldZ)
        if (magnitude > 1f) {
            worldX /= magnitude
            worldZ /= magnitude
        }
        return WorldVector(worldX, worldZ)
    }
}
