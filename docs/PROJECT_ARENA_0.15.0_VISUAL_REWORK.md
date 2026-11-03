# Project Arena 0.15.0 — visual overhaul

## Scope

This branch responds to the 0.14.0 in-game captures: identical humanoid silhouettes, anatomically incorrect arm motion, weak terrain relief, and a HUB built from large stacked panels over the gameplay camera.

## Characters

- Keeps the three playable identities: Lyra, Bastion and Kairo.
- Extends the authored gear generator to five role silhouettes. AI role IDs select Bastion/solo, Kairo/jungle, Arcanist/mid, Ranger/carry and Lyra/support.
- Each set is split across torso, head, back, shoulder, forearm, thigh and boot attachments, parented to matching skeleton joints.
- The common Quaternius humanoid base is still shared. This revision does not claim five independent full-body meshes or imported motion-capture clips.
- The source GLB hierarchy has local +Y upper-arm child offsets, but the shoulder bind rotations place the two arms along opposite world-space X directions. Rotating around local X spins around each arm's longitudinal axis and leaves the T-pose intact. The 0.15.3 correction uses local-Z flexion with mirrored left/right signs, then layers role cadence and distinct lane-unit readiness.
- Body width and height are also varied by bot role; the selected hero retains its three original equipment sets.

## Battlefield

- Expands the lateral ridges, jungle knolls, base highlands and river valley.
- Refines the generated ground mesh from 104 to 136 subdivisions per axis.
- Mirrors the terrain height function between Kotlin rendering and native C++ movement/physics.
- Adds regression sampling for relief range and slope. These tests validate deterministic surface math, not visual appearance or device performance.
- Shifts lighting and ground material values away from the overly cyan palette and brings the combat camera slightly closer to the active character.

## HUB

- Replaces the gameplay-camera backdrop with original Canvas vector key art: distant mountain silhouettes, a citadel, river valley, three roads, pines, foreground and a hero focal silhouette.
- Removes the large stacked right-hand navigation panel and large hero info slab.
- Moves primary navigation into a compact horizontal dock: Heroes, Collection, Profile and Play.
- Moves Help and Settings into small utility controls. Shop is available from Collection.
- Skips 3D frame rendering while the HUB state is active to avoid rendering an unseen scene under the illustration.

## Follow-up correction — 0.15.3

- Replaced the incorrect local-X arm swing with mirrored local-Z flexion, using the checked-in GLB bind rotations as the rig contract.
- Centered the hero-selection preview and tightened its camera framing; the HUB uses a subtle procedural turn to make the 3D model visibly alive.
- Added a JVM regression test that evaluates both upper-arm world directions from the GLB bind quaternions.

## Validation

CI runs:
1. Native C++20 physics regression tests.
2. Repository structure and version checks.
3. JVM tests for all five generated gear styles and the terrain height/normal field.
4. Android debug APK compilation, package/version verification and persistent signing check.
5. Signed tester APK publication for this branch.

## Known limitations

- Character bodies still use the shared CC0 Quaternius skeleton/body; silhouette variation is produced by bone-parented gear and per-role body proportions. A later asset pass should introduce independent full-body meshes with matching rig contracts.
- Locomotion/combat motion remains procedural. The upstream humanoid GLB contains no animation clips; this branch does not add a full motion-capture library.
- Physics is the existing deterministic kinematic/collider model, not a full rigid-body solver or triangle-mesh navigation system.
- CI cannot certify visual quality, FPS under load, touch comfort, sustained temperature or crash-free runtime on a physical Realme C53. Those require manual device validation.

## Follow-up correction — 0.15.4

- Moved the showcase hero away from the centre-lane tower. The previous preview transform at x=0, z=-7 placed Lyra/Bastion/Kairo directly behind the tower in the camera line.
- Reserved a clear point at x=-15, z=4 and shifted the look target left so the hero reads to the right of the selection panel.
- Increased the in-match character framing while preserving the tactical isometric camera and minimap.
- Desaturated meadow, trail, forest and water material values and neutralized the environment lighting.
- Added a JVM check for distance from the showcase point to towers, neutral camps and objective shrines.


## Character pipeline vertical slice — Lyra 0.15.5

The first playable hero no longer reuses the Quaternius body. `LyraCharacterGlbBuilder.kt` authors a separate stylized body mesh, seven PBR materials and a 19-joint skeleton whose semantic joint names match the existing procedural pose controller.

The generated GLB contains `JOINTS_0`, `WEIGHTS_0` and `inverseBindMatrices`. Primary/secondary influences are blended across shoulder, elbow, hip, knee and ankle transitions. The renderer keeps a dedicated FilamentAsset, FilamentInstance, animator, material list, bounds and BonePose map for Lyra.

Bastion and Kairo continue using the previous Quaternius body and their existing bone-parented gear. Bots and lane units also retain the shared CC0 base, limiting the scope of this first replacement. JVM tests inspect the actual binary GLB buffers and check that all joint indices are valid and per-vertex weights sum to one.
