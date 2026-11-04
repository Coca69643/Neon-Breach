## Runtime integration progress — 4 November 2026

**Current implementation branch:** `rebuild/project-arena-1.7.0-world-foundation`  
**Latest source inspected:** `48284ce04214faeef90a7c5550e609effcc3e312`  
**Status:** runtime migration is substantially integrated at source level; **visual acceptance and Android device validation remain blocked**.

The older findings below describe the pre-cutover state and must not be read as the current implementation status. Since that snapshot, the branch has completed these source migrations:

| Consumer | Current source-level integration | Remaining verification |
|---|---|---|
| World definition | JSON generates typed Kotlin and C++ contracts | Generator reproducibility in CI |
| Map adapter | 180 × 160 m, three 8-point lanes, 13-point river, 12 camps and two objectives derive from generated data | Unit and geometry checks |
| Terrain renderer | 193 × 177 full-size heightfield uses generated elevation controls, river valley and deterministic noise; irregular superellipse shoreline | Android screenshot and visual inspection |
| Physics | Native terrain height uses the same generated elevation and river controls; boundary, tree/camp/objective/base/tower collision use v1.7 anchors | Native tests plus device collision walk-through |
| Navigation | Native graph builds from 17 generated nodes and 26 links | Bot and minion playtest on full map |
| Simulation | Bases, lane spawns, 12 neutral camps and 18 towers use canonical positions | Match-loop validation |
| JNI snapshot | 332 floats; first eight camp slots preserve previous offsets and four additional camps use appended slots | Unit tests for all twelve camp signals |
| Minimap | Uses v1.7 lane span, generated towers and the extended camp snapshot | Verify alignment against a live gameplay camera |
| CC0 nature bake | Groundcover is scattered inside the two JSON jungle polygons with deterministic jitter and exclusion masks for lanes, river, camps, objectives and crossings. Camp rocks are placed at the same six anchor locations used by native physics | Bake budget and visual density in the Android runtime |
| Fauna | Six ambient actors and twelve camp guardians are positioned from the enlarged world; ambient motion is still visual-only and deterministic | Check animation clips, visibility, local motion and performance in-game |

### CI findings and current gate

- Commit `db651ae` passed Python pipeline syntax, CC0 source validation, canonical JSON validation, generated contracts, native physics/navigation tests, structural validation and Kotlin compilation. It then failed one stale unit-test assertion expecting 32 trees instead of the 48 blockers now derived from twelve camps.
- Commit `f913b7` corrected that tree-count assertion and fixed the pinned SHA-1 for `Rock_Medium_1.gltf`.
- Commit `48284ce` aligned baked camp rocks to the six positions used by native collision. The next bake run exposed a too-strict minimum-rock count gate; it is being adjusted to the measured minimum of 48 while the placement generator continues to enforce 73 accepted jungle scatter cells and at least 150 groundcover placements.
- No APK from this branch is certified as version 1.7.0. The existing Gradle identity still reports 0.16.0.
- No screenshot or recording from the Realme C53 has yet verified the full map, visual density, collision alignment, camera readability, 30 FPS or thermal stability.

### Remaining visual blockers

1. Tree blockers are currently a camp-clearing ring, not a full forest canopy distribution. The baked groundcover adds surface detail, but the two jungles still need a denser, spatially varied canopy plan derived from their polygons.
2. The objective shrine builder still uses repeated primitive stone geometry; it must be replaced by a less regular authored/CC0 composition before visual acceptance.
3. Bridge placement now uses the three canonical crossings, but one shared bridge asset is still reused. Confirm deck width, orientation, bank connection, collision and visual proportions from the gameplay camera.
4. Roads are smooth procedural ribbons. Their edge blending, width, shoulder variation and transitions into terrain must be inspected and refined so they do not read as uniform strips.
5. Wildlife uses deterministic sinusoidal routes and proximity flee offsets. It is a low-cost ambient pass, not yet a complete territorial ecology system.

**Acceptance status remains BLOCKED** until a signed Android build with the new world is inspected in-game, all routes/crossings/camps are traversable, and a Realme C53 session supplies visual and performance evidence.


# Project Arena 1.7.0 — Runtime Visual Audit

**Date:** 2026-11-04  
**Branch:** `rebuild/project-arena-1.7.0-world-foundation`  
**Status:** **BLOCKED — the new arena is specified and validated as data, but is not yet the active runtime world.**  
**Purpose:** prevent a successful legacy APK build from being mistaken for completion of the approved 1.7.0 world reconstruction.

## Executive finding

The current renderer is not a fully primitive scene: it loads CC0 medieval structures, tree/bush models, baked groundcover and rock GLBs, and PBR terrain maps, with sun shadows, contact ambient occlusion and distance fog. These are useful visual building blocks.

However, the active runtime still renders the **legacy 0.16.0 battlefield**. The organic asset pipeline is anchored to the old coordinate system. The new `world/arena_world_1_7.json` is validated by CI, but it does not yet drive the renderer, Kotlin map catalog or C++ simulation. Therefore the 1.7.0 map cannot be described as rebuilt, organic or accepted.

## Historical baseline before runtime cutover

The following table records the state found in the initial audit and is retained as historical context, not as a description of the current branch.

## Verified implementation facts

| Area | Current branch evidence | Result |
|---|---|---|
| Renderer entry point | `FilamentGameRenderer.loadWorld()` calls `WorldGlbBuilder.build(terrainTextures)` | Still uses the legacy procedural world builder |
| Kotlin map | `ArenaMapDefinition.kt` has `WORLD_SCALE = 1.15`, half-extents 35 × 31 m, 3 lanes about 2.36–2.42 m wide, 8 camps and a 12-point narrow river | Legacy scale and topology remain active |
| Native simulation | `ArenaMapDefinition.h` duplicates the same scale, extents, lanes, river, camps and grove coordinates | Kotlin/C++ are still separate hard-coded copies |
| Terrain | `WorldGlbBuilder.terrainMesh()` samples a 76 × 76 m grid and clips it to an irregular island around ±35 × ±31 m | More than flat geometry, but still the old small island |
| Lane surfaces | `WorldGlbBuilder` creates Catmull-Rom ribbons from legacy lane points | Smooth procedural ribbons, not the new 9.5–10 m authored routes |
| River | `WorldGlbBuilder.buildRiverChannel()` samples the old 12-point line; the half-width is roughly 0.78–1.95 m | Still much narrower than the new 4.5–8.5 m half-width design |
| Structures | `loadKayKitEnvironment()` loads castle, tower, home, church and bridge models, but places them from `ArenaMapDefinition.WORLD_SCALE` and legacy positions | Real assets are present, but positioned for the old map; the same bridge model is reused |
| Nature bake | `fetch_cc0_nature_assets.py` pins Quaternius CC0 assets and bakes groundcover/rocks around old groves, camps and river positions spanning approximately x = −34…+34 m | Valid offline asset pipeline, wrong world footprint for 1.7.0 |
| New world data | `world/arena_world_1_7.json` defines 180 × 160 m, three broad lanes, two jungle regions, 12 camps, three crossings and a wider river | Structural data validation passes; runtime consumption is missing |
| CI | Run `41901296794` passed the asset pipeline, canonical JSON validation, native physics tests, Gradle unit tests and APK build | It built and identified an APK as **0.16.0**; it does not validate or visually prove the 1.7.0 world |

## Required reconstruction work

These are release blockers, not optional polish:

1. **Single source of truth:** generate both Kotlin and C++ world definitions from `arena_world_1_7.json`. Renderer, simulation, collision, navigation, spawns, objectives and minimap must consume the same generated coordinates. Remove hand-maintained legacy coordinate copies from the active path.
2. **Full-size continuous terrain:** replace the old ±35 × ±31 m island with a terrain surface covering the approved 180 × 160 m envelope. Use the JSON elevation controls to create connected slopes, ridges, basins and natural boundaries; no obvious rectangular world edge.
3. **Natural routes:** generate all three roads from the authored waypoints at their 9.5–10 m widths, with variable shoulders, ground blending and irregular edges. They must visually belong to the terrain rather than read as uniformly colored strips.
4. **Integrated river valley:** use the new centerline and 4.5–8.5 m half-widths to form a continuous channel, shallow shelves, banks and terrain transitions. Build the three bridges at the declared crossing points and make each crossing physically and navigationally valid.
5. **Organic jungle composition:** scatter multiple verified CC0 species inside the two new jungle boundaries using a deterministic seed and exclusion masks for roads, camps, objectives, bases and bridge approaches. Use varied cluster sizes, spacing, scale and rotation; avoid repeated rows or identical clumps.
6. **Landmarks and architecture:** place the two bases, towers, camps and objectives from the canonical world data. Use coherent medieval GLB architecture and deliberate compositions. Reusing a small set of props for mobile efficiency is acceptable only with varied composition; primitive boxes/cones/spheres cannot substitute for final architecture.
7. **Consistent world interaction:** every rendered route and crossing must have matching collision and navigation. Forest blockers, cliff boundaries, slopes and water must not disagree between the renderer and native simulation.
8. **Mobile budgets:** use instancing/batching, LOD, distance/frustum culling, controlled foliage density, and bounded shadow/foliage costs. Preserve offline packaging. Measure frame time, memory and thermal behavior on the Realme C53; CI compilation is not a performance test.

## Visual acceptance gate

The map is not accepted until all conditions below are demonstrated in the running Android build:

- The visible world is recognizably larger and uses the complete 180 × 160 m layout.
- Three distinct broad routes, both jungles, the full river valley, all three bridges, bases and objective clearings appear in the correct locations.
- Terrain, water, roads, forests and architecture form one coherent medieval-fantasy environment; no old island silhouette or legacy layout remains.
- No repeated primitive geometry is being used as final art for cliffs, rocks, trees, towers, bridges or buildings.
- The environment is inspected from gameplay camera height, not only from a top-down diagram or editor view.
- Screenshots or a recorded device run prove that the new runtime assets are actually loaded.
- Collision, movement, minion paths, bot navigation and minimap match the same world definition.
- The build passes unit/native tests and is then measured on the Realme C53 for sustained frame pacing and thermal stability.

## Release rule

Do not label a build as Project Arena 1.7.0, do not merge this work to `main`, and do not claim the map is organic or complete until the visual acceptance gate passes. A successful build of the current 0.16.0 runtime only proves that the legacy app still compiles and that the new world JSON is structurally valid.


## Runtime consumer migration matrix

The following active consumers were inspected after introducing the generated contracts. They must be migrated as one coordinated runtime cutover:

| Consumer | Legacy dependency | Required 1.7.0 source |
|---|---|---|
| `WorldGlbBuilder.kt` | 76 × 76 m mesh, island clipping at roughly ±35 × ±31 m, legacy lane/camp positions, river width clamped to 0.68–2.0 m, decorative shoals and old base walls | Full 180 × 160 m heightfield; generated elevation controls, 8-point lane splines, 13-point river at 4.5–8.5 m half-width, explicit bridge crossings, jungle polygons and new objective/camp clearings |
| `FilamentGameRenderer.kt` | `ArenaMapDefinition.WORLD_SCALE`, legacy lane/camp placements, bridge placement inferred from lane points nearest z=0 | Generated base/gate/tower/crossing/camp/objective data; renderer must not infer bridge positions or use legacy scale |
| `ArenaNatureCatalog.kt` | 32 hard-coded tree blockers and 12 legacy grove centers | Deterministic vegetation distribution sampled inside generated jungle polygons with road/camp/objective/crossing exclusion masks; collision blockers generated from the same placements |
| `ArenaPhysics.cpp` | Legacy elliptical boundary, old river interpolation and old tree/camp/objective blockers | 180 × 160 m world boundary, generated river polyline and terrain heightfield, generated camp/objective collision, vegetation blocker set from the same deterministic scatter |
| `ArenaSimulation.cpp` | Old core positions, tower curve, 8 camp positions and 2 objective positions | Bases, lane gates, three tower depths, 12 camps and objectives generated from the canonical world; update initial player spawns and all spawn/respawn positions |
| `ArenaNavigation.h` | Fixed graph layout with 27 lane nodes, 8 camp nodes and legacy positions | Generate graph nodes/links from the 17 canonical navigation nodes and 26 links; add camp/objective associations and verify all routes are reachable |
| Minimap / HUD | Existing consumers must be located and audited during cutover | Draw lanes, river, bridges, bases, camps and objectives from the same generated coordinates; never maintain a separate minimap map |

### Cutover sequence

1. Finish the canonical data contract and generated-output CI gate (current stage).
2. Add shared deterministic terrain sampling and polyline utilities, with Kotlin/C++ parity tests.
3. Replace the world mesh and all static placements in the renderer; use explicit JSON crossings and 180 × 160 m extents.
4. Switch physics and simulation to the same generated world in the same change set; update bounds, spawns, towers, camps and objectives.
5. Generate navigation from the canonical graph and migrate minimap/HUD markers.
6. Add vegetation scatter from jungle polygons and derive collision blockers from the exact same seeded placements.
7. Only then enable the 1.7.0 runtime world and validate it in the Android build and on the Realme C53.

**Hard rule:** do not switch only the renderer or only the simulation. A visually new map with old collision/navigation is a broken build, not a partial release.
