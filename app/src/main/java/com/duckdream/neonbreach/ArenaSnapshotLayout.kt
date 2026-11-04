package com.duckdream.neonbreach

/** Stable JNI snapshot offsets. The legacy eight camp slots remain unchanged; four are appended. */
internal object ArenaSnapshotLayout {
    const val SIZE = 332
    fun campHealth(index: Int): Int = if (index < 8) 270 + index else 320 + (index - 8)
    fun campRespawn(index: Int): Int = if (index < 8) 278 + index else 324 + (index - 8)
    fun campAttackPulse(index: Int): Int = if (index < 8) 312 + index else 328 + (index - 8)
}
