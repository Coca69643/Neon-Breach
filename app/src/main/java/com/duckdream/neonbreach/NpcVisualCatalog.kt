package com.duckdream.neonbreach

internal enum class NpcLocomotion { IDLE, WALK, RUN }

/**
 * Visual roster for AI heroes and lane units. Every slot resolves to one of the
 * three rigged CC0 heroes already loaded by the renderer; no jade mannequin is used.
 */
internal object NpcVisualCatalog {
    const val MINION_RENDER_DISTANCE = 34f

    private val botModels = intArrayOf(1, 2, 0, 2, 0, 1, 2, 0, 1)

    fun botModel(index: Int): Int = botModels[index.mod(botModels.size)]

    fun minionSlot(index: Int): Int = (index.mod(8)).mod(4)

    fun minionModel(index: Int): Int = when (minionSlot(index)) {
        0 -> 1 // heavy vanguard
        1 -> 0 // standard support
        2 -> 2 // agile scout
        else -> if ((index / 4).mod(2) == 0) 0 else 2 // alternating ranged silhouette
    }

    fun minionWidthFactor(index: Int): Float = when (minionSlot(index)) {
        0 -> 1.10f
        1 -> 0.98f
        2 -> 0.90f
        else -> 0.84f
    }

    fun minionHeightFactor(index: Int): Float = when (minionSlot(index)) {
        0 -> 0.93f
        1 -> 1.00f
        2 -> 1.08f
        else -> 1.13f
    }

    fun locomotion(speed: Float): NpcLocomotion = when {
        speed >= 3.25f -> NpcLocomotion.RUN
        speed >= 0.16f -> NpcLocomotion.WALK
        else -> NpcLocomotion.IDLE
    }

    fun botRoleWidth(role: Int): Float = when (role.coerceIn(0, 4)) {
        0 -> 1.10f
        1 -> 0.90f
        2 -> 1.00f
        3 -> 0.92f
        else -> 0.98f
    }

    fun botRoleHeight(role: Int): Float = when (role.coerceIn(0, 4)) {
        0 -> 0.96f
        1 -> 1.06f
        2 -> 1.00f
        3 -> 1.08f
        else -> 1.02f
    }
}
