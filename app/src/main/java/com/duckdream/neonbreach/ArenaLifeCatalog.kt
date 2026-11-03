package com.duckdream.neonbreach

import kotlin.math.abs
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.sin
import kotlin.math.sqrt

internal enum class LifeActorKind { WILDLIFE, CAMP_GUARDIAN }

internal data class LifeSpeciesProfile(
    val id: String,
    val targetHeight: Float,
    val airHeight: Float,
    val yawOffset: Float,
    val idleTokens: List<String>,
    val moveTokens: List<String>
)

internal data class LifeActorSpawn(
    val id: String,
    val species: String,
    val kind: LifeActorKind,
    val x: Float,
    val z: Float,
    val radius: Float,
    val phase: Float,
    val pace: Float,
    val campIndex: Int = -1
)

internal data class LifeActorSample(
    val x: Float,
    val z: Float,
    val yaw: Float,
    val heightOffset: Float,
    val moving: Boolean
)

/**
 * Deterministic, low-cost placement and motion catalog for ambient wildlife
 * and neutral camp guardians. Actors are visual-only and never change combat,
 * collision, gold, XP or objective simulation.
 */
internal object ArenaLifeCatalog {
    val species = listOf(
        LifeSpeciesProfile("deer", 1.55f, 0f, 0f,
            listOf("idle", "graze", "look", "rest"), listOf("walk", "run", "gallop")),
        LifeSpeciesProfile("wolf", 0.92f, 0f, 0f,
            listOf("idle", "look", "stand"), listOf("walk", "run", "trot")),
        LifeSpeciesProfile("bird", 0.52f, 1.75f, 0f,
            listOf("idle", "perch", "look"), listOf("fly", "flap", "glide", "walk")),
        LifeSpeciesProfile("mushroom", 0.92f, 0f, 0f,
            listOf("idle", "bounce", "look"), listOf("walk", "move", "hop")),
        LifeSpeciesProfile("walking-tree", 2.35f, 0f, 0f,
            listOf("idle", "sway", "look"), listOf("walk", "move", "patrol")),
        LifeSpeciesProfile("ghost", 1.38f, 0.28f, 0f,
            listOf("idle", "float", "hover"), listOf("float", "fly", "move", "walk"))
    ).associateBy { it.id }

    // Keep one deer inside the opening blue-side camera footprint, then distribute
    // the remaining wildlife along both jungle flanks and the central clearings.
    // These are visual-only actors; the native lane/camp simulation remains authoritative.
    val wildlife = listOf(
        LifeActorSpawn("deer_west", "deer", LifeActorKind.WILDLIFE, -17f, -20f, 1.65f, 0.4f, 0.34f),
        LifeActorSpawn("deer_east", "deer", LifeActorKind.WILDLIFE, 17f, 20f, 1.65f, 2.1f, 0.31f),
        LifeActorSpawn("wolf_west", "wolf", LifeActorKind.WILDLIFE, -22f, 7f, 2.2f, 1.2f, 0.43f),
        LifeActorSpawn("wolf_east", "wolf", LifeActorKind.WILDLIFE, 22f, -7f, 2.2f, 2.8f, 0.39f),
        LifeActorSpawn("bird_west", "bird", LifeActorKind.WILDLIFE, -8.5f, -16.5f, 2.8f, 0.7f, 0.58f),
        LifeActorSpawn("bird_east", "bird", LifeActorKind.WILDLIFE, 8.5f, 16.5f, 2.8f, 2.5f, 0.62f)
    )

    private val campPoints = ArenaMapDefinition.camps.map { camp ->
        camp.position.x to camp.position.z
    }

    fun campGuardians(): List<LifeActorSpawn> = campPoints.mapIndexed { index, point ->
        val species = when (index % 3) {
            0 -> "mushroom"
            1 -> "walking-tree"
            else -> "ghost"
        }
        LifeActorSpawn(
            id = "camp_guardian_$index",
            species = species,
            kind = LifeActorKind.CAMP_GUARDIAN,
            x = point.first,
            z = point.second,
            radius = 0f,
            phase = index * 0.71f,
            pace = 0f,
            campIndex = index
        )
    }

    fun sample(spawn: LifeActorSpawn, time: Float, playerX: Float, playerZ: Float): LifeActorSample {
        if (spawn.kind == LifeActorKind.CAMP_GUARDIAN) {
            val sway = sin(time * 0.46f + spawn.phase) * 0.10f
            val bob = sin(time * 1.15f + spawn.phase) * 0.035f
            return LifeActorSample(spawn.x, spawn.z, sway, bob, false)
        }

        fun path(t: Float): Pair<Float, Float> {
            val phase = t * spawn.pace + spawn.phase
            return (spawn.x + sin(phase) * spawn.radius) to
                (spawn.z + cos(phase * 0.72f) * spawn.radius * 0.52f)
        }

        val (baseX, baseZ) = path(time)
        val (aheadX, aheadZ) = path(time + 0.025f)
        val dx = aheadX - baseX
        val dz = aheadZ - baseZ
        val playerDx = baseX - playerX
        val playerDz = baseZ - playerZ
        val distance = sqrt(playerDx * playerDx + playerDz * playerDz).coerceAtLeast(0.001f)
        val flee = ((7.5f - distance) / 7.5f).coerceIn(0f, 1f)
        val escapeX = if (distance <= 0.0011f) cos(spawn.phase) else playerDx / distance
        val escapeZ = if (distance <= 0.0011f) sin(spawn.phase) else playerDz / distance
        val x = baseX + escapeX * flee * spawn.radius * 1.15f
        val z = baseZ + escapeZ * flee * spawn.radius * 1.15f
        val moving = abs(dx) + abs(dz) > 0.0015f || flee > 0.08f
        val yaw = if (flee > 0.08f) atan2(escapeX, escapeZ)
            else atan2(dx, dz)
        val height = if (spawn.species == "bird") sin(time * 2.0f + spawn.phase) * 0.18f
            else if (spawn.species == "wolf") 0.025f
            else 0.012f
        return LifeActorSample(x, z, yaw, height, moving)
    }
}
