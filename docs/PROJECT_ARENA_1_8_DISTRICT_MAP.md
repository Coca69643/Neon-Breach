# Project Arena 1.8.0 — District Control map foundation

## Asset policy

Runtime assets must be bundled locally; gameplay must never download models or textures.
Use only assets whose individual pack page explicitly states CC0. The current city bundle is sourced from Kenney's CC0 City Kit packs:

- City Kit (Roads): https://kenney.nl/assets/city-kit-roads
- City Kit (Commercial): https://kenney.nl/assets/city-kit-commercial
- City Kit (Suburban): https://kenney.nl/assets/city-kit-suburban
- City Kit (Industrial): https://kenney.nl/assets/city-kit-industrial

The world terrain and materials may use Poly Haven (all published assets CC0):
- https://polyhaven.com/license

PBR ground materials may use ambientCG (CC0):
- https://ambientcg.com/

The exact source commit, per-file hashes, and bundled licence notice must remain pinned in the asset preparation scripts. Never infer the licence of an individual asset from a site's general "free" label.

## Map direction

The battlefield is being rebuilt as a connected urban district, not a small oval arena with decorative blocks. The four existing enterable interiors are now explicit district anchors:

| District | Function | Gameplay role |
|---|---|---|
| Mercado Oeste | commerce | flank and close-range routes |
| Pátio Industrial | industry | exposed service yard and alternate approach |
| Parque Cívico | public services | protected rotation route |
| Terminal Norte | transport | cross-map connection |

District anchors, entrances, collision geometry, and navigation must share coordinates from `ArenaWorldCatalog`. A building is not considered enterable unless the player can cross its doorway, navigate its floor, and exit without teleporting or clipping.

## Required map acceptance checks

1. Every district has a visible landmark and a reachable interaction/capture point.
2. Every enterable building has consistent rendered walls, collision walls, door width, and floor dimensions.
3. At least two viable routes connect each district to the central combat space.
4. No objective, prop, tower, or vegetation collider blocks a primary route.
5. The terrain, roads, props, and collision use the same world coordinate system.
6. CC0 models are optimized, bundled offline, and verified by SHA-256 before release.
7. Mobile scene budget is measured on ARM64; do not add unbounded draw calls or per-frame allocations.

## 1.8.0 implementation sequence

1. Correct rig forward-axis handling, weapon scale, and minion readability.
2. Establish the district landmark catalog and validate accessible points.
3. Replace the repetitive three-lane-only flow with district objectives and rotating map events.
4. Extend navigation and bot decision-making to use district links and alternate routes.
5. Replace placeholder building silhouettes with authored, scaled CC0 architecture and consistent interior kits.
6. Run static analysis, unit tests, release build, and a physical-device pass on the Realme C53.

This document describes acceptance criteria, not a claim that every listed system is already implemented.
