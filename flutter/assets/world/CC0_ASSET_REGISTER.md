# Project Arena — CC0 environment asset register

All selected assets must remain bundled for offline use. Re-check the original pack page and preserve its license file when pinning or updating assets.

| Asset family | Intended use | Source / license |
|---|---|---|
| Kenney City Kit (Commercial) | Mid-rise commercial shells, storefronts and city landmarks | https://kenney.nl/assets/city-kit-commercial — CC0 |
| Kenney City Kit (Suburban) | Low-rise buildings, trees, planters and residential edges | https://kenney.nl/assets/city-kit-suburban — CC0 |
| Kenney City Kit (Industrial) | Warehouses, service yards and industrial landmarks | https://kenney.nl/assets/city-kit-industrial — CC0 |
| Kenney City Kit (Roads) | Road segments, junctions, signs, lights and barriers | https://kenney.nl/assets/city-kit-roads — CC0 |
| Kenney Modular Space Kit | Interior corridors, doors, rooms and stairs; reuse selectively, not as the dominant city aesthetic | https://kenney.nl/ — CC0 notice retained at app/src/main/assets/world/kenney/LICENSE.txt |
| Quaternius Stylized Nature | Trees and vegetation accents | https://quaternius.com/ — CC0 notice retained at ASSETS/Quaternius-Stylized-Nature-License.txt |
| Poly Haven | Optional PBR ground/concrete/metal textures where a specific texture materially improves the scene | https://polyhaven.com/license — all library assets CC0 |

## Existing pinned pipeline

The repository already contains an offline asset baker at flutter/tool/prepare_city_assets.py. It pins Kenney-derived GLBs to a source commit and validates Git blob SHA-1 plus SHA-256 before bundling. Extend that pipeline rather than adding runtime downloads.

Current generated assets are stored under flutter/assets/world/city/. Keep all game runtime asset loading offline.

## Acceptance checks before an asset enters the release

- Exact source pack and creator recorded.
- CC0 1.0 evidence recorded; do not assume an entire third-party repository is CC0 merely because it hosts CC0 assets.
- SHA-256 recorded in the generated manifest.
- GLB 2.0 structure, embedded textures and mesh/material presence validated.
- Real-world dimensions inspected; normalize pivots and scale before placement.
- Triangle count and texture dimensions fit the mobile budget.
- Visual footprint, collider and navigation opening agree.
