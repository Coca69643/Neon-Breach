package com.duckdream.neonbreach

import org.junit.Assert.assertEquals
import org.junit.Test

class ArenaSnapshotLayoutTest {
    @Test
    fun twelveCampSignalsUseNonOverlappingSnapshotSlots() {
        assertEquals(332, ArenaSnapshotLayout.SIZE)
        for (index in 0 until 12) {
            assertEquals(if (index < 8) 270 + index else 320 + index - 8, ArenaSnapshotLayout.campHealth(index))
            assertEquals(if (index < 8) 278 + index else 324 + index - 8, ArenaSnapshotLayout.campRespawn(index))
            assertEquals(if (index < 8) 312 + index else 328 + index - 8, ArenaSnapshotLayout.campAttackPulse(index))
        }
        assertEquals(277, ArenaSnapshotLayout.campHealth(7))
        assertEquals(320, ArenaSnapshotLayout.campHealth(8))
        assertEquals(331, ArenaSnapshotLayout.campAttackPulse(11))
    }
}
