# Projeto Arena 0.12.0 — Gameplay Design & Technical Notes

## Match model
Offline 5v5: one player plus four allied agents versus five enemy agents. The selected hero determines the player's initial role:
- Bastion: solo lane.
- Kairo: jungle/rotation.
- Lyra: duo-lane support.

The four allied bots fill the remaining roles. Enemy bots use a complete five-role composition.

## Map
- Three curved lanes with distinct centerlines.
- A central river with three lane crossings.
- Two mirrored jungle halves and eight neutral camps.
- Eight camp markers and two objective pits are included in the generated terrain mesh.
- Each team has three towers per lane, 18 total. Tier 0 is the outer tower near the river; tier 2 is the inner tower near the base.
- Bases and cores sit at opposite ends of the battlefield.

## Lane waves
Each lane and team has an independent 26-second wave timer. Four minion slots form each group: three melee and one ranged. Two groups alternate per lane/team, allowing up to 48 active minions while keeping a fixed budget. If both groups are still alive, the wave waits briefly instead of teleporting survivors or spawning unlimited entities.

## Structures and siege
- A tower attacks enemy units in range, prioritizing lane minions before heroes.
- The player can only damage a tower while an allied wave is nearby.
- A lane's tower chain is tiered: outer, middle, inner.
- Once one lane's three towers are destroyed, the core becomes vulnerable. Minions and bots can then pressure the base.

## Jungle and neutral objectives
- Eight camps have individual health and respawn timers.
- Camps provide team gold and XP.
- Guardião do Rio appears at 78 seconds; defeating it grants 360 gold, 145 XP and an 85-second siege buff.
- Sentinela Ancestral appears at 210 seconds; defeating it grants 620 gold, 210 XP and a 115-second siege buff.
- Both objectives return after their respective respawn intervals.

## Roles and in-match progression
- The bot team composition uses solo, jungle, mid, carry and support.
- Junglers clear camps and rotate toward live objectives.
- Carries keep a longer preferred range during bot duels.
- Supports restore health to nearby damaged allies when they are not actively dueling.
- The player earns XP and gold, levels up, improves the skill rank and purchases three fixed-price item categories: vitality/defense, power, and haste.

## Snapshot contract
The JNI snapshot uses 320 floats:
- 0–95: legacy player, bot and result fields retained for animation and HUD compatibility.
- 96–106: player level, XP, gold, max HP, power, armor, and objective timers/health.
- 107–124: 18 tower health values.
- 126–221: 48 minion positions.
- 222–269: 48 minion health values.
- 270–277: eight camp health values.
- 278–285: camp respawn timers.
- 286–288: item counts.
- 289: skill level.
- 290–291: team siege buffs.
- 292–293: objective visual timers.
- 294–297: team gold and XP.
- 298: player's role.
- 299–307: bot roles.
- 308: elapsed match time; 309: winner; 310–311: haste and power.

## Mobile budget and limits
- 48 minion slots, 9 bots and 1 playable hero share a GLB mesh and atlas.
- Only the playable hero uses the extended 18-joint animation controller; NPCs use the reduced rig.
- Offline bots only; no network matchmaking or human-player synchronization.
- No Fog of War, draft, manual target selection or multi-slot inventory yet.
- Neutral objectives use landmark meshes and gameplay markers, not animated boss creature models.
- CI validates code and APK; the Realme C53 still needs physical FPS, thermal, camera, touch and readability tests.
