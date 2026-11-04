# Project Arena — Gameplay Identity Research: Living Territory

**Date:** 2026-11-04  
**Status:** Research direction / proposed design, not yet implemented  
**Reference branch:** `rebuild/project-arena-1.7.0-world-foundation`

## Design question

How can Project Arena share the readable, multi-route, objective-driven combat appeal of Deadlock while developing a distinct identity and making its world feel inhabited?

## Research findings

### Deadlock — map systems must reinforce one another

Valve's February 25, 2025 map rework moved the map from four lanes to three and changed pathways, building layouts, neutral camps, air vents, breakables, powerups, juke spots and the mid-boss as one coordinated redesign. The patch also added ambient birds and park-gate sounds, neutral-camp spawn audio, and world sounds for jump pads and powerups. This is evidence that map identity comes from the combined movement, combat, objective and sensory systems—not lane count alone.

Official reference: https://www.deadlock.io/en/patches/map-rework-update-2025-02-25-1792116353369036

Deadlock's objective design also ties each reward to a different next action: map control, inventory capacity, team revival resources or delivery rewards. Teams must judge timing, health, wave pressure and the time required to secure and exit an objective.

Reference: https://www.deadlock.io/en/mechanics/objectives

### Dota 2 — more terrain only matters when it creates decisions

The New Frontiers update expanded the map by 40%, reconfigured both jungles and introduced new routes, Watchers, Defender's Gates, Lotus Pools, additional camps and alternate Roshan locations. The update explicitly preserved the core objective and lane distances while using the new space to add strategic options.

Official reference: https://www.dota2.com/newfrontiers

### GDC — life comes from systemic actors

Seth Rosen's GDC 2016 session *Level Design Workshop: Adding Life to your Level* contrasts environmental storytelling with AI actors whose systemic behaviors make a level feel alive. Its core lesson for this project: wildlife, minions, neutral factions and world inhabitants should visibly do things for reasons, not merely idle as decorative props.

Reference: https://gdcvault.com/play/1023551/Level-Design-Workshop-Adding-Life

### Mobile constraint

Wild Rift describes its MOBA as built from the ground up for mobile, with redesigned controls and match pacing. Project Arena should similarly make readability, short interaction loops, touch precision, stable frame pacing and thermal limits design constraints from the start—not a later porting pass.

Official reference: https://wildrift.leagueoflegends.com/pt-br/game-overview/

## Proposed identity: Living Territory

Project Arena's distinctive hook should be a battlefield whose inhabitants and regions react consistently to the match. The world should feel active even when the player is not fighting.

### Pillar 1 — Active ecology

- Neutral creatures have authored territories, patrol routes, rest points and alert states.
- Nearby combat, damage and ability noise can raise alertness; creatures investigate, defend their territory or retreat according to readable rules.
- Camps visibly transition through alive, contested, cleared and recovering states.
- Respawn/recovery is deterministic and communicated clearly; no hidden random power swings.
- Creatures must not wander into lanes or objectives in ways that create unfair, untelegraphed combat.

### Pillar 2 — Reactive battlefield

- Structures and key props show persistent damage states during a match.
- Captured objectives visibly change banners, lights, ambient activity and nearby faction behavior.
- Lane pressure changes local activity: defenders gather, civilians/creatures withdraw, and allied minions visibly rally or regroup.
- Destruction and control states must be gameplay-readable from the mobile camera; visual changes cannot obscure telegraphs.

### Pillar 3 — Distinct regions with tactical identity

- West route: ancient fortifications, broken walls, narrow flanking cuts and stone landmarks.
- Center route: broad river valley, bridges, open sightlines and objective staging space.
- East route: overgrown woodland, winding trails, cover pockets and layered forest silhouettes.
- Two jungles must differ in local composition and route connectivity while retaining mirrored competitive fairness.
- The same materials, props and lighting language must connect the regions into one coherent medieval-fantasy world.

### Pillar 4 — Objective choices, not mandatory boss chores

Each major objective should offer a distinct strategic reward and a different risk/reward profile. Teams should choose based on lane pressure, available allies, health, timing and what they plan to do next. Avoid making all objectives simple health sponges that grant generic team buffs.

## First signature mechanic to prototype: Territory Pulse

A predictable, timed world-state cycle that communicates changes to the ecosystem and creates a tactical decision:

1. A visible/audio warning announces a territory shift.
2. One region becomes active: its neutral faction patrols more aggressively and a specific resource route becomes valuable.
3. The active region offers a small, clearly telegraphed reward for securing a camp cluster or local objective.
4. The state expires on a fixed schedule and rotates; no random location or invisible stat modifier.
5. Both teams receive equivalent information and access windows.

This is a candidate for a later prototype, not a commitment to add another global timer before the core map and combat are stable. First prove neutral behavior, route readability and mobile performance.

## Implementation order

1. Finish canonical world data integration: JSON must generate the Kotlin and C++ world catalogs; renderer, physics, navigation, minimap, spawns and objectives must stop using legacy coordinates.
2. Complete and validate the full 180 × 160 m organic environment and its three routes, two jungles, river and crossings.
3. Implement one neutral camp with a small state machine: idle/patrol → alert → defend/retreat → defeated → recover. Validate fairness and CPU cost.
4. Implement persistent visual state for one objective and one structure.
5. Extend to all 12 camps and objective set only after the vertical slice is readable and performant.
6. Prototype Territory Pulse only after the baseline loop works.

## Mobile acceptance

- Gameplay clarity from the actual landscape camera and touch UI.
- Stable 30 FPS target on Realme C53; record frame-time distribution, memory, draw calls and thermal behavior.
- AI update budgets use distance/visibility-based LOD and deterministic state transitions.
- No continuous expensive per-creature pathfinding; use patrol splines and local steering for ambient wildlife.
- No ambient behavior that can silently alter competitive outcomes.
- Offline asset packaging and deterministic match simulation preserved.

## Non-goals

- Do not clone Deadlock's urban theme, ziplines, hero kits, objective rewards or art identity.
- Do not add random weather, uncontrolled migrations, large-scale destruction or complex ecology before the basic arena is stable.
- Do not use ambient NPCs as an excuse to postpone player/minion animation, collision, navigation or map integration.
