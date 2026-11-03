package com.duckdream.neonbreach

internal data class HeroModelSpec(
    val id: String,
    val assetPath: String,
    val idleClip: String,
    val walkClip: String,
    val runClip: String
)

internal object HeroModelCatalog {
    val models = listOf(
        HeroModelSpec("Lyra", "heroes/lyra.glb", "Female_Idle", "Female_Walk", "Female_Run"),
        HeroModelSpec("Bastion", "heroes/bastion.glb", "Man_Idle", "Man_Walk", "Man_Run"),
        HeroModelSpec("Kairo", "heroes/kairo.glb", "Female_Idle", "Female_Walk", "Female_Run")
    )

    fun animationIndex(names: List<String>, suffix: String): Int =
        names.indexOfFirst { it.substringAfterLast('|').equals(suffix, ignoreCase = true) }
}
