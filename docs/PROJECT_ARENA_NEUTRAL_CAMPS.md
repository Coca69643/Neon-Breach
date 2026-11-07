# Project Arena — neutral MOBA camps

Research snapshot: 07 November 2026. Status: design gate only; no camp asset or gameplay implementation is approved by this document.

## Problem statement

The current match has lane minions, allied/enemy hero bots, ambient city pedestrians and a Quartermaster. It does not have neutral combat camps. Ambient pedestrians and the shopkeeper are not substitutes for neutral gameplay entities.

## Proposed gameplay slice

Implement a small, deterministic neutral-camp system as a distinct simulation domain:

- Three authored camps distributed across verified walkable jungle/side-district pockets. Exact anchors must be validated against `ArenaWorldCatalog.isWalkable`, building footprints, canal access and combat sight lines before being committed.
- Each camp contains a readable guardian group (initially one guardian plus one smaller guard). Camp units are neutral until aggroed; they are hostile to either team.
- State machine: dormant/patrol → aggro → combat → leash/return → defeated → respawning. Invalid frame deltas and match end must not corrupt state.
- Aggro selects the nearest eligible hero, bot or minion within range. Leash returns the group to its authored anchor and restores health; no chasing through walls, across the canal or between elevation layers.
- Defeating a camp awards a bounded MOBA gold/XP reward to the team that secures the final hit. Initial slice has no persistent inventory, random loot, gathering, crafting or survival meters.
- Respawn uses a deterministic timer and a clear neutral minimap marker. The HUD exposes camp state only when relevant/nearby.
- Simulation owns health, position, cooldown, leash and respawn. Rendering consumes immutable snapshots; no AI decisions live in widgets or scene callbacks.
- Enforce a strict active-entity budget and render-distance culling suitable for the Realme C53.

This is a first vertical slice, not a full jungle ecosystem. Buff camps, boss objectives and team-specific rewards remain out of scope until the basic loop passes acceptance.

## Candidate asset research

| Candidate | Official page facts | Decision |
|---|---|---|
| Quaternius Ultimate Monsters | 50 models; animated; glTF listed; page displays CC0 and states free personal/commercial use. | Primary candidate for the guardian roster. The exact downloadable archive, model inventory, per-model clips, package hash and mobile cost have **not** yet been inspected. |
| Quaternius Cute Animated Monsters Pack | 21 animated monsters; glTF listed; page displays CC0 and states free personal/commercial use. | Secondary candidate for smaller camp guards; exact archive and clip inventory remain unverified. |
| Quaternius Animated Monster Pack | 4 animated monsters; page displays CC0 and states free personal/commercial use. | Possible fallback only if the exact files offer better silhouettes/animation coverage. |

Official source pages:
- https://quaternius.com/packs/ultimatemonsters.html
- https://quaternius.com/packs/cutemonsters
- https://quaternius.com/packs/animatedmonster.html
- https://quaternius.com/faq.html

The official Ultimate Monsters page was checked on 07 November 2026. It lists 50 animated models, FBX/OBJ/Blend/glTF formats, and a CC0 license. The official FAQ says Quaternius assets may be used commercially without attribution and that hosted models are CC0. The Cute Animated Monsters and Animated Monster pages independently display CC0. These page facts do not replace inspection of the exact downloaded archive.

## Asset acceptance gate

Before adding any model to the repository or APK:

1. Download the package from the official creator page.
2. Preserve the original archive and record retrieval date, exact source URL, archive filename, SHA-256 and bundled license text.
3. Inventory every candidate model and its actual animation names; do not infer clips from marketing screenshots.
4. Select only a small set with clearly distinct silhouettes and suitable idle/walk/attack/death clips.
5. Convert offline to self-contained GLB 2.0; validate textures, skeleton, animation tracks, bounds, front axis, pivots and scale.
6. Record source package hash and each output GLB SHA-256 in a provenance manifest.
7. Measure model bytes, triangle count, material count and texture memory. No runtime network downloads or runtime format conversion.
8. Confirm visual consistency with the existing arena before integrating the whole pack.

## Acceptance criteria

- At least three distinct neutral camps exist at authored, reachable positions and are visible on the minimap.
- Each camp has deterministic spawn, aggro, attack, leash, defeat and respawn transitions.
- Neutral monsters can damage eligible units from either team; they cannot target through walls, water, inaccessible interiors or different elevation layers.
- Camp rewards are awarded exactly once to the securing team; no reward is duplicated by repeated damage/death ticks.
- Respawn restores the exact camp composition and state; match reset clears timers and aggro.
- Player target cycling and contextual target HUD can select neutral monsters without breaking existing enemy hero/minion targeting.
- Rendering uses distinct CC0 GLBs with authored animation clips and per-model scale/orientation; no human pedestrian reuse and no primitive geometry presented as a finished monster.
- Minimap and scene rendering are culled by distance; entity count stays within a measured mobile budget.
- Deterministic tests cover transitions, leash, reward, respawn, target selection, reset, collision boundaries and elevation.
- Screenshots/video from a running build verify silhouettes, animation, placement and readability. Realme C53 testing verifies frame pacing, memory, heat and interruption behavior.

## Explicitly not accepted as completion

- A marker, ring or health bar without a real neutral actor.
- A monster model that has no functioning combat state machine.
- Reusing city pedestrians as neutral monsters.
- Code presence or green CI as proof of visual/gameplay acceptance.
- Unverified assets, licenses or archive hashes.

## Current implementation status

Not implemented. This document records the research direction and acceptance gate only. The asset package must be downloaded, inspected and pinned before art-pipeline changes. Gameplay implementation must follow the repository's mandatory engineering protocol and remain on `fix/1.8.1-feedback-recovery`.
