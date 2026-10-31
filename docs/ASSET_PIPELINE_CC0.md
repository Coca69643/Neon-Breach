# ORION-9 — Non-sci-fi CC0 Asset Research

Research snapshot: 31 October 2026.

## Direction

The previous sci-fi asset direction is no longer the target for the next art exploration. Do not keep extending the same space-station vocabulary by swapping colors or adding more identical corridor modules.

Candidate visual direction to prototype: **ancient / overgrown dungeon architecture** — stone halls, worn masonry, arches, vertical spaces, roots and vegetation reclaiming ruins, with distinct environmental identities. This is a proposal for an art test, not a final lore or gameplay decision.

The aim is to create readable room silhouettes and a coherent world, not to assemble unrelated asset packs into a map.

## Primary non-sci-fi candidates

| Pack / source | Verified page information | Potential use | Integration notes |
|---|---|---|---|
| [Quaternius Modular Dungeon Pack](https://quaternius.com/packs/modulardungeon.html) | 48 models; FBX / OBJ / Blend; individual page displays CC0 | Stone walls, modular dungeon sections, torches and environment props | No glTF listed on the page; convert offline to optimized GLB and validate scale, pivots, normals and draw-call cost |
| [Quaternius Medieval Dungeon Pack](https://quaternius.com/packs/medievaldungeon.html) | 41 models; FBX / OBJ / Blend; individual page displays CC0 | Barrels, torches, potions and modular wall pieces | Use only environment/set-dressing elements that fit the approved direction; convert and optimize before runtime |
| [Quaternius Medieval Village MegaKit](https://quaternius.com/packs/medievalvillagemegakit.html) | 304 models; FBX / OBJ / Blend / glTF; page describes grid-snapped walls, floors, stairs, roofs, doors, windows and vines; page displays CC0 | Architecture kit for connected halls, courtyards, towers and transitions | Page states the free download is a subset (60–70%); inventory the exact downloaded subset before planning around missing pieces |
| [Kenney Castle Kit](https://kenney.nl/assets/castle-kit) | 75+ files; 3D; page displays Creative Commons CC0 | Castle walls, structural modules and medieval architectural details | Download and inspect the archive for formats and model scale before deciding the importer path |
| [Kenney Nature Kit](https://kenney.nl/assets/nature-kit) | 330+ files; 3D; page displays Creative Commons CC0 | Trees, rocks, foliage and vegetation for outdoor spaces and overgrown ruins | Select assets by silhouette and triangle count; use instancing/LOD and avoid excessive alpha foliage |
| [Quaternius Stylized Nature MegaKit](https://quaternius.com/packs/stylizednaturemegakit.html) | 116 models; FBX / OBJ / Blend / glTF; page displays CC0; 40 trees, 35 plants/flowers, 27 rocks and more | Distinct biome identity, vegetation, rocks and scene dressing | Free tier is a subset; verify exact included files. Keep the GLB conversion/texture atlas pipeline reproducible |
| [Poly Haven](https://polyhaven.com/) | Official license page says all hosted models, textures and HDRIs are CC0 | Select high-quality stone, dirt, wood and surface materials; occasional unique props and lighting references | Not a modular level kit. Use selectively: high-resolution scanned assets and large HDRIs may be too expensive for a mid-range phone |

## License handling — important

- The individual creator pack page and the exact downloaded archive are the source of truth. A third-party catalog or a creator's general reputation is not a license grant for every file.
- Kenney pages listed above explicitly show Creative Commons CC0.
- The listed Quaternius pack pages explicitly show CC0. Quaternius also publishes **Quaternius Asset License (QAL) v1.0**, last updated 28 August 2026. Do not assume every future Quaternius release is CC0 merely because older pack pages are CC0. Check the exact pack page and the license bundled with the actual download.
- Before shipping any asset, archive its source URL, retrieval date, exact package/version, license text or page snapshot, and SHA-256 of the archive. Keep a per-file provenance manifest.
- Do not place an asset in the public repository until its exact license permits that redistribution. CC0 assets can be redistributed; assets under a different license may have different restrictions.
- Never copy preview renders, logos, or page artwork unless their own license explicitly permits it.

## Mobile-first import pipeline

1. Acquire only the free subset and preserve the original archive unchanged outside the runtime asset folder.
2. Inspect actual file formats, units, pivots, hierarchy, texture dimensions, mesh count, triangle count and license.
3. Convert selected models offline to glTF 2.0 / GLB; never add runtime converters or a game engine dependency.
4. Consolidate textures into atlases where visual quality allows; use a small number of shared materials.
5. Author low-cost collision proxies independently from render meshes. Collision must align with the same sockets and transforms as doors, stairs, walls and openings.
6. Normalize module dimensions and establish a snap grid before assembling the map.
7. Create LODs, instance repeated props, cull unseen modules, limit transparent foliage and bound texture memory.
8. Import only approved, optimized files into the APK. Keep source archives and provenance separate.
9. Validate on the Realme C53. Desktop appearance is not a mobile performance result.

## Required art test before full integration

Build one small, representative environment slice using one coherent style:
- one major room, two connecting passages and one vertical/height transition;
- at least three distinct architectural silhouettes;
- a consistent material/lighting treatment;
- correct collision for every wall, doorway and stair/ramp;
- controlled prop density and sight lines;
- measured GLB size, triangles, draw calls and texture memory.

Do not build the whole world from assets until this slice passes visual review and mobile performance checks.

## Sources checked

- Quaternius Modular Dungeon Pack — https://quaternius.com/packs/modulardungeon.html
- Quaternius Medieval Dungeon Pack — https://quaternius.com/packs/medievaldungeon.html
- Quaternius Medieval Village MegaKit — https://quaternius.com/packs/medievalvillagemegakit.html
- Kenney Castle Kit — https://kenney.nl/assets/castle-kit
- Kenney Nature Kit — https://kenney.nl/assets/nature-kit
- Quaternius Stylized Nature MegaKit — https://quaternius.com/packs/stylizednaturemegakit.html
- Poly Haven license — https://polyhaven.com/license
- Quaternius QAL v1.0 — https://quaternius.com/license.html
