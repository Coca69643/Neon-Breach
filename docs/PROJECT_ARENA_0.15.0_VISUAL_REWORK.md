# Project Arena 0.15.0 — visual and presentation pass

## Scope

This release addresses the visual issues visible in the 0.14.0 device captures. It does not claim to replace the shared Quaternius humanoid with three independently authored full-body characters.

## Terrain

The terrain height function now includes stronger western/eastern ridges, higher base approaches, enlarged jungle knolls and peripheral terraces. The runtime mesh uses 144 subdivisions per axis instead of 104. Lane surfaces are narrower and the ground materials use a less cyan palette.

The same coefficients are implemented in `WorldGlbBuilder.heightAt()` and `arena_physics::terrainHeight()`. This is essential: rendering and collision must agree on the ground surface. The terrain normal is still derived from the same height function.

## Character silhouettes

The three hero equipment styles now contribute more visible silhouette mass:
- Lyra: layered rear mantle tails and softer shoulder volume.
- Bastion: wider shoulder geometry, a ridged helm and a heavier rear plate.
- Kairo: hood volume, asymmetric mantle tails and a reinforced forearm plate.

The equipment remains local GLB geometry attached to the humanoid skeleton. The Quaternius body mesh is still shared. This is a deliberate intermediate step; independent full-body topology and skin weights are not yet present.

## Animation and troop roles

The idle arm pose was brought closer to the body. Arm posing now combines a small shoulder swing with the main flex angle, reducing the rigid outward V. Troop slots use more distinct width/height profiles for melee, ranged and heavy units. The hero continues to use its existing state controller for idle, walk/run, dash, cast, guard, hit and respawn.

## HUB presentation

The menu camera now frames one selected hero at close range, with idle animation running while the app is in MENU state. Bots are hidden during this presentation and restored when a match starts. The HUB uses a compact hero card, one primary Play action and small secondary shortcuts. Collection, shop and missions stay available; guide and settings use compact top shortcuts.

The live match camera has not been replaced by the menu camera.

## Verification

CI must pass:
1. Native kinematic physics tests.
2. Structural project checks, including both terrain heightfield implementations.
3. Kotlin unit tests for generated hero gear GLBs and distinct style output.
4. Android debug APK compilation, package/version validation and persistent-signature check.

## Explicit limitations

- No device capture or physical performance measurement is available from CI.
- The three heroes do not yet have independent body meshes or unique animation clip libraries.
- NPCs still share the base humanoid skeleton; role size and gait parameters vary.
- The terrain remains a procedural mesh, not an authored sculpted landscape with hand-painted texture maps.
- The APK size may not grow substantially because terrain and hero gear geometry are generated at runtime. No dummy assets are added to inflate file size.