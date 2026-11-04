package com.duckdream.neonbreach

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import kotlin.math.sqrt

class ArenaMovementInputTest {
    @Test
    fun screenLeftMovesLeftOnScreen() {
        val world = ArenaMovementInput.fromScreenStick(screenX = -1f, screenY = 0f)
        // Camera-right is world -X, so screen-left is world +X.
        assertEquals(1f, world.x, 0.0001f)
        assertEquals(0f, world.z, 0.0001f)
    }

    @Test
    fun screenRightMovesRightOnScreen() {
        val world = ArenaMovementInput.fromScreenStick(screenX = 1f, screenY = 0f)
        assertEquals(-1f, world.x, 0.0001f)
        assertEquals(0f, world.z, 0.0001f)
    }

    @Test
    fun screenUpMovesForwardAlongWorldNorth() {
        val world = ArenaMovementInput.fromScreenStick(screenX = 0f, screenY = -1f)
        assertEquals(0f, world.x, 0.0001f)
        assertEquals(1f, world.z, 0.0001f)
    }

    @Test
    fun screenDownMovesBackwardAlongWorldSouth() {
        val world = ArenaMovementInput.fromScreenStick(screenX = 0f, screenY = 1f)
        assertEquals(0f, world.x, 0.0001f)
        assertEquals(-1f, world.z, 0.0001f)
    }

    @Test
    fun diagonalInputRemainsInsideUnitCircle() {
        val world = ArenaMovementInput.fromScreenStick(
            screenX = -1f,
            screenY = -1f,
            sensitivity = 1.22f
        )
        assertTrue(sqrt(world.x * world.x + world.z * world.z) <= 1.0001f)
        assertTrue(world.x > 0f)
        assertTrue(world.z > 0f)
    }

    @Test
    fun sensitivityChangesMagnitudeWithoutChangingDirection() {
        val normal = ArenaMovementInput.fromScreenStick(-0.5f, 0f, 1f)
        val sensitive = ArenaMovementInput.fromScreenStick(-0.5f, 0f, 1.22f)
        assertTrue(sensitive.x > normal.x)
        assertEquals(0f, normal.z, 0.0001f)
        assertEquals(0f, sensitive.z, 0.0001f)
    }
}
