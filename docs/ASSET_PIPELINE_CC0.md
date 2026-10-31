# ORION-9 v0.9 — CC0 asset acquisition and integration

This repository uses a native Android renderer (Kotlin + JNI + C++17 + OpenGL ES 3.0). Assets are imported as source models and converted/loaded through the existing glTF pipeline; they are not runtime engine dependencies.

## Approved candidate packs

| Pack | Content | Formats / license | Intended use |
|---|---|---|---|
| [Kenney Modular Space Kit](https://kenney.nl/assets/modular-space-kit) | 40 modular sci-fi station pieces | CC0; FBX/OBJ/glTF/Blend | Room shells, wall modules, bulkheads, corridor transitions |
| [Quaternius Modular Sci-Fi Megakit](https://quaternius.com/packs/modularscifimegakit.html) | 277 modular sci-fi room and corridor pieces | CC0; FBX/OBJ/glTF/Blend | Secondary architecture, props and room silhouettes |
| [Kenney Space Kit](https://kenney-assets.itch.io/space-kit) | 150+ space models, turrets, weapons, characters | CC0; includes glTF | Weapons, props, set dressing and prototype character silhouettes |
| [Quaternius Universal Animation Library](https://quaternius.com/packs/universalanimationlibrary.html) | Humanoid animation clips | Verify pack page/license at acquisition | Locomotion/combat animation evaluation |

Official creator pages are the license authority. Re-check and archive the included license file for every downloaded pack before shipping. Keep a per-asset manifest with original filename, source URL, license, import scale, material treatment and collision role. Do not assume that every asset found in a third-party catalog inherits CC0.

## Import rules for mobile

1. Prefer glTF 2.0 / GLB for the runtime pipeline.
2. Consolidate materials and texture atlases by environment theme; avoid one material per prop.
3. Generate simplified collision proxies separately from render meshes.
4. Use shared modular dimensions and explicit doorway sockets. A visual doorway and its collision aperture must derive from the same socket transform.
5. Author LOD0/LOD1/LOD2 for large props and room modules; cull rooms outside the camera frustum.
6. Use ASTC where supported, with ETC2 fallback; keep texture dimensions and resident memory bounded.
7. Do not import full source packs into the APK. Include only selected, optimized assets.

## Visual direction

The facility should read as one designed place: graphite composite floors, pale ceramic wall armor, restrained amber safety markings, cyan powered systems, readable signage and localized wear. Each sector receives a distinct functional identity (research, power, containment, logistics), not merely a palette swap.
