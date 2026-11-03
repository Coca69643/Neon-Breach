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
 * Colors are ordered exactly as the glTF materials in each checked-in GLB.
 * The source models have no embedded textures; brighter per-part palettes make
 * skin, cloth, hair, trousers and footwear readable at the mobile camera scale.
 */
internal object HeroMaterialPalette {
    private val lyra = listOf(
        HeroSrgbColor(0.20f, 0.37f, 0.62f), // Shirt: sapphire/indigo
        HeroSrgbColor(0.82f, 0.62f, 0.47f), // Skin: warm peach
        HeroSrgbColor(0.22f, 0.17f, 0.32f), // Pants: deep violet
        HeroSrgbColor(0.13f, 0.10f, 0.08f), // Shoes: leather
        HeroSrgbColor(0.78f, 0.64f, 0.38f), // Socks: muted gold
        HeroSrgbColor(0.36f, 0.16f, 0.08f), // Hair base: chestnut
        HeroSrgbColor(0.55f, 0.22f, 0.10f), // Hair: auburn
        HeroSrgbColor(0.08f, 0.06f, 0.05f)  // Eyes
    )
    private val bastion = listOf(
        HeroSrgbColor(0.20f, 0.36f, 0.28f), // Shirt: forest green
        HeroSrgbColor(0.27f, 0.30f, 0.34f), // Pants: graphite
        HeroSrgbColor(0.05f, 0.04f, 0.035f), // Eyes
        HeroSrgbColor(0.72f, 0.49f, 0.34f), // Skin: warm tan
        HeroSrgbColor(0.14f, 0.09f, 0.06f)  // Hair: dark brown
    )
    private val kairo = listOf(
        HeroSrgbColor(0.08f, 0.42f, 0.45f), // Shirt: teal
        HeroSrgbColor(0.76f, 0.55f, 0.38f), // Skin: warm tan
        HeroSrgbColor(0.34f, 0.29f, 0.18f), // Pants: olive
        HeroSrgbColor(0.12f, 0.13f, 0.11f), // Shoes: dark leather
        HeroSrgbColor(0.12f, 0.09f, 0.11f), // Hair base
        HeroSrgbColor(0.23f, 0.15f, 0.22f), // Hair: plum
        HeroSrgbColor(0.06f, 0.05f, 0.06)  // Eyes
    )

    fun forHero(index: Int): List<HeroSrgbColor> = when (index.coerceIn(0, 2)) {
        0 -> lyra
        1 -> bastion
        else -> kairo
    }
}
