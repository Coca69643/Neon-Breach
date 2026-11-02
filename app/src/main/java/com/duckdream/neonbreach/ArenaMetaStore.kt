package com.duckdream.neonbreach

import android.content.Context

/**
 * Offline meta progression for the local 5v5 build.
 * All transactions are atomic SharedPreferences edits; no network or real-money purchase path.
 */
internal object ArenaMetaStore {
    private const val PREFS = "arena_meta_v1"
    private fun prefs(context: Context) = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun coins(context: Context): Int = prefs(context).getInt("coins", 350).coerceAtLeast(0)
    fun shards(context: Context): Int = prefs(context).getInt("shards", 30).coerceAtLeast(0)

    fun hasSkin(context: Context, hero: Int): Boolean =
        prefs(context).getBoolean("skin_$hero", false)

    fun equipSkin(context: Context, hero: Int, alternate: Boolean) {
        prefs(context).edit().putBoolean("skin_equipped_$hero", alternate && hasSkin(context, hero)).apply()
    }

    fun buySkin(context: Context, hero: Int, price: Int): Boolean {
        val p = prefs(context)
        if (p.getBoolean("skin_$hero", false)) return true
        val balance = p.getInt("coins", 350)
        if (price < 0 || balance < price) return false
        p.edit().putInt("coins", balance - price).putBoolean("skin_$hero", true)
            .putBoolean("skin_equipped_$hero", true).apply()
        return true
    }

    fun exchange(context: Context, shardCost: Int, coinReward: Int): Boolean {
        val p = prefs(context)
        val balance = p.getInt("shards", 30)
        if (shardCost <= 0 || coinReward <= 0 || balance < shardCost) return false
        p.edit().putInt("shards", balance - shardCost)
            .putInt("coins", p.getInt("coins", 350) + coinReward).apply()
        return true
    }

    /** Returns [level, xp, matches, wins]. */
    fun stats(context: Context): IntArray {
        val p = prefs(context)
        val xp = p.getInt("xp", 0).coerceAtLeast(0)
        return intArrayOf(1 + xp / 500, xp % 500,
            p.getInt("matches", 0).coerceAtLeast(0),
            p.getInt("wins", 0).coerceAtLeast(0))
    }

    fun recordMatch(context: Context, won: Boolean) {
        val p = prefs(context)
        val matches = p.getInt("matches", 0) + 1
        val xp = p.getInt("xp", 0) + if (won) 120 else 70
        val editor = p.edit()
            .putInt("matches", matches)
            .putInt("wins", p.getInt("wins", 0) + if (won) 1 else 0)
            .putInt("xp", xp)
            .putInt("coins", p.getInt("coins", 350) + if (won) 120 else 70)
            .putInt("shards", p.getInt("shards", 30) + if (won) 12 else 6)
        val claimedMilestone = p.getInt("contract_claimed", 0)
        val completedMilestone = matches / 3
        if (completedMilestone > claimedMilestone) {
            editor.putInt("contract_claimed", completedMilestone)
                .putInt("coins", p.getInt("coins", 350) + (if (won) 120 else 70) + 250)
                .putInt("shards", p.getInt("shards", 30) + (if (won) 12 else 6) + 30)
        }
        editor.apply()
    }
}
