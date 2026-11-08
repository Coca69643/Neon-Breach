# Project Arena — Porto de Vésper

Status: candidate implementation for the fourth 1.8.1 slice. Visual and physical acceptance remain pending.

## Design intent

Porto de Vésper is a fictional coastal industrial district. Its identity comes from a reshaped coastline, a wider meandering channel, paved waterfront plazas and an expanded architectural silhouette—not from renaming the previous field.

- New irregular coastline and wider shipping channel.
- Four quay plazas with a continuous concrete waterfront band.
- Additional commercial and warehouse volumes, using only city GLBs already pinned in the offline CC0 pipeline.
- New names for the six existing districts and three environmental landmarks.
- The existing world scale, interiors, elevated walkways and current movement systems are preserved.
- The match HUD identifies PORTO DE VÉSPER.

## Synchronized source of truth

- `ArenaWorldCatalog` defines the coastline, canal profile, plaza anchors, building bounds and surface classification.
- `prepare_world_assets.py` mirrors the coastline, water profile, quay mask and terrain elevations when baking the GLB.
- Render geometry, navigation and Rapier continue to use the same logical world units.
- No network download is required at runtime and no new external asset pack is introduced.

## Acceptance criteria

- Dart and Python coastline coordinates match.
- All six district anchors and four quay plazas stay inside the polygon and remain walkable.
- Quay plazas classify as concrete; water remains non-walkable except at the five existing bridge locations.
- Every commercial building footprint stays inside the coastline and uses the measured GLB bounds already in the catalog.
- Offline baking creates a wider continuous water surface, connected bank bands and bridge decks sized to the updated channel.
- Existing interior, boulevard, mezzanine, NPC and world tests remain intact and pass.
- HUD map identity is visible without obscuring match timer or score in landscape.
- Formatting, static analysis, deterministic tests and offline asset generation pass on the exact PR commit.

## Not proven by CI

CI cannot establish visual quality from the live match camera. Acceptance still requires unedited gameplay captures and a sustained Realme C53 session, including frame pacing, memory, temperature and pause/resume.

## Provenance

Only existing pinned CC0 assets are reused. See `flutter/tool/prepare_city_assets.py` and `ASSETS/` for the asset pins and license records.

Technical references:
- Flutter Scene installation: https://fscene.dev/getting-started/installation/
- Flutter Scene release history: https://github.com/bdero/flutter_scene/releases
- Flutter Scene Rapier release history: https://github.com/bdero/flutter_scene_rapier/releases

No new third-party model is introduced by this slice.
