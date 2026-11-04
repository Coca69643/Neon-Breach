package com.duckdream.neonbreach

import kotlin.math.PI

/** Deterministic, offline CC0 environment placements. Repeated models share one Filament asset. */
internal object ArenaNatureCatalog {
    data class Placement(
        val model: String,
        val x: Float,
        val z: Float,
        val scale: Float,
        val yaw: Float
    )

    private val treeVariants = listOf(
        "nature_tree_oak", "nature_tree_pine", "nature_tree_broadleaf"
    )

    val trees: List<Placement> = ArenaMapDefinition.treeBlockers.mapIndexed { index, point ->
        Placement(
            model = treeVariants[(index * 2 + index / 5) % treeVariants.size],
            x = point.x,
            z = point.z,
            scale = 0.92f + (index % 4) * 0.09f,
            yaw = (index * 2.399f) % (2f * PI.toFloat())
        )
    }

    // Low shrubs remain clustered at neutral camp pockets rather than filling the field.
    val bushes: List<Placement> = ArenaMapDefinition.groveCenters.mapIndexed { index, point ->
        val side = if (index % 2 == 0) -1f else 1f
        Placement(
            model = "nature_bush",
            x = point.x + side * 1.15f,
            z = point.z + if (index % 3 == 0) 0.9f else -0.75f,
            scale = 0.72f + (index % 3) * 0.08f,
            yaw = (index * 1.71f) % (2f * PI.toFloat())
        )
    }
}
