package com.duckdream.neonbreach

import kotlin.math.PI
import kotlin.math.atan2

/**
 * The bundled GLBs have a -90 degree X conversion on their mesh/armature nodes.
 * Their visible front therefore points along scene +Z; gameplay yaw needs no
 * extra half-turn. The showcase camera sits on the -Z side, so preview yaw is PI.
 */
internal object HeroFacing {
    const val GAMEPLAY_YAW_OFFSET = 0f
    val SHOWCASE_YAW: Float = PI.toFloat()

    fun yawFromVelocity(velocityX: Float, velocityZ: Float): Float =
        atan2(velocityX, velocityZ) + GAMEPLAY_YAW_OFFSET
}

internal data class HeroSrgbColor(
    val r: Float,
    val g: Float,
    val b: Float,
    val a: Float = 1f
)

/**
 * Colors are keyed by the glTF material names in each checked-in model.
 * The source models have no embedded textures; per-part palettes make
 * skin, cloth, hair, trousers and footwear readable at the mobile camera scale.
 */
internal object HeroMaterialPalette {
    private val lyra = linkedMapOf(
        "shirt" to HeroSrgbColor(0.16f, 0.30f, 0.62f), // Sapphire field jacket
        "skin" to HeroSrgbColor(0.88f, 0.68f, 0.54f), // Warm natural skin
        "pants" to HeroSrgbColor(0.17f, 0.14f, 0.27f), // Deep violet trousers
        "shoes" to HeroSrgbColor(0.16f, 0.10f, 0.07f), // Brown leather
        "socks" to HeroSrgbColor(0.66f, 0.53f, 0.31f),
        "hairbase" to HeroSrgbColor(0.28f, 0.12f, 0.06f),
        "hair" to HeroSrgbColor(0.53f, 0.20f, 0.09f),
        "eyes" to HeroSrgbColor(0.035f, 0.025f, 0.02f)
    )
    private val bastion = linkedMapOf(
        "shirt" to HeroSrgbColor(0.17f, 0.34f, 0.27f),
        "pants" to HeroSrgbColor(0.18f, 0.20f, 0.23f),
        "eyes" to HeroSrgbColor(0.035f, 0.025f, 0.02f),
        "skin" to HeroSrgbColor(0.75f, 0.53f, 0.38f),
        "hair" to HeroSrgbColor(0.10f, 0.065f, 0.045f)
    )
    private val kairo = linkedMapOf(
        "shirt" to HeroSrgbColor(0.055f, 0.38f, 0.43f),
        "skin" to HeroSrgbColor(0.83f, 0.61f, 0.43f),
        "pants" to HeroSrgbColor(0.30f, 0.27f, 0.17f),
        "shoes" to HeroSrgbColor(0.12f, 0.105f, 0.09f),
        "hairbase" to HeroSrgbColor(0.09f, 0.07f, 0.08f),
        "hair" to HeroSrgbColor(0.25f, 0.13f, 0.22f),
        "eyes" to HeroSrgbColor(0.035f, 0.025f, 0.03f)
    )

    fun forHero(index: Int): Map<String, HeroSrgbColor> = when (index.coerceIn(0, 2)) {
        0 -> lyra
        1 -> bastion
        else -> kairo
    }

    /**
     * Team identity is carried by clothing only. Skin, hair and facial details
     * stay natural, rather than multiplying one team tint over the entire body.
     */
    fun forNpc(heroIndex: Int, team: Int, variation: Int, disabled: Boolean = false): Map<String, HeroSrgbColor> {
        val palette = forHero(heroIndex).toMutableMap()
        val variant = variation.mod(4)
        val blueShirts = listOf(
            HeroSrgbColor(0.13f, 0.31f, 0.60f),
            HeroSrgbColor(0.12f, 0.43f, 0.62f),
            HeroSrgbColor(0.17f, 0.37f, 0.51f),
            HeroSrgbColor(0.22f, 0.32f, 0.54f)
        )
        val redShirts = listOf(
            HeroSrgbColor(0.62f, 0.19f, 0.16f),
            HeroSrgbColor(0.70f, 0.27f, 0.15f),
            HeroSrgbColor(0.53f, 0.16f, 0.22f),
            HeroSrgbColor(0.68f, 0.31f, 0.22f)
        )
        val bluePants = listOf(
            HeroSrgbColor(0.12f, 0.15f, 0.22f),
            HeroSrgbColor(0.14f, 0.18f, 0.25f),
            HeroSrgbColor(0.16f, 0.16f, 0.21f),
            HeroSrgbColor(0.12f, 0.19f, 0.24f)
        )
        val redPants = listOf(
            HeroSrgbColor(0.22f, 0.14f, 0.14f),
            HeroSrgbColor(0.25f, 0.16f, 0.13f),
            HeroSrgbColor(0.20f, 0.13f, 0.17f),
            HeroSrgbColor(0.24f, 0.17f, 0.15f)
        )
        val hairVariants = listOf(
            HeroSrgbColor(0.12f, 0.075f, 0.045f),
            HeroSrgbColor(0.25f, 0.12f, 0.06f),
            HeroSrgbColor(0.34f, 0.19f, 0.11f),
            HeroSrgbColor(0.12f, 0.10f, 0.12f)
        )
        palette["shirt"] = if (disabled) HeroSrgbColor(0.36f, 0.39f, 0.41f)
            else if (team == 0) blueShirts[variant] else redShirts[variant]
        palette["pants"] = if (disabled) HeroSrgbColor(0.24f, 0.25f, 0.27f)
            else if (team == 0) bluePants[variant] else redPants[variant]
        val hair = hairVariants[variant]
        if (palette.containsKey("hairbase")) palette["hairbase"] = hair
        if (palette.containsKey("hair")) palette["hair"] = hair
        return palette
    }

    fun colorForMaterial(name: String, palette: Map<String, HeroSrgbColor>): HeroSrgbColor? =
        palette[normalizeMaterialName(name)]

    fun normalizeMaterialName(name: String): String =
        name.lowercase().filter { it.isLetterOrDigit() }
}
