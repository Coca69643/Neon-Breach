# Asset register — Projeto Arena

## CC0 third-party assets

### KayKit — Medieval Hexagon Pack
- Pack: https://kaylousberg.itch.io/kaykit-medieval-hexagon
- Source repository: https://github.com/KayKit-Game-Assets/KayKit-Medieval-Hexagon-Pack-1.0
- License: Creative Commons Zero 1.0 Universal (CC0); archived at ASSETS/KayKit-Medieval-Hexagon-LICENSE.txt.
- Imported environment models only:
  - castle_blue / castle_red
  - tower_blue / tower_red
  - home_blue / home_red
  - church_blue / church_red
  - bridge_a
  - trees_a (legacy grouped tree model; no longer placed in the 0.16.0 nature pass)
- The source GLTF files and binary mesh buffers are stored under app/src/main/assets/world/kaykit/.
- hexagons_medieval.png is the shared texture atlas used by all imported GLTF files. The source buffer URI names are preserved as alias .bin files so ResourceLoader can resolve every model without rewriting the original glTF.
- No weapon props, weapon models or weapon animations were imported.


### Quaternius — Stylized Nature MegaKit (CC0)
- Official pack: https://quaternius.com/packs/stylizednaturemegakit.html
- License: CC0 1.0; textured glTF models are permitted in commercial projects.
- Selected assets: CommonTree 1/2/4 and Bush_Common, optimized GLB copies from the public mirror `anshaneja5/skyline-run` at pinned commit `0c41526d8d4130c37c15e219c2c3737fa8cb4ad8`.
- Source Git blob IDs are pinned and verified by `tools/verify_project.py`; all four models are self-contained GLB 2.0 files with no runtime network dependency.
- Runtime: 32 tree placements use three shared model assets; 12 low shrub placements use one shared bush asset. The Filament asset loader reuses each model across placements.

### Quaternius — Stylized Nature MegaKit (CC0)
- Official pack: https://quaternius.com/packs/stylizednaturemegakit.html
- The Standard pack contains textured glTF nature models under CC0 1.0; the license text is archived at ASSETS/Quaternius-Stylized-Nature-License.txt.
- Selected models: Fern_1, Grass_Common_Tall, Grass_Wispy_Short, Flower_3_Group, Mushroom_Common, Rock_Medium_1 and Rock_Medium_2.
- Source mirror: anandin/the-wild-between, pinned commit `001ecddebd9a5ed64cfadcccde0daf9342397a1b`. The source file Git blob IDs are pinned in `tools/fetch_cc0_nature_assets.py`.
- Build-time baker combines the placements into two self-contained GLBs: one groundcover mesh with four texture/material batches and one rocks mesh with a single batch. All textures are embedded; no runtime network or per-prop render entities are needed.

### Quaternius — Universal Base Characters
- Asset: app/src/main/assets/characters/quaternius-character.glb.b64
- Source pack: https://quaternius.com/packs/universalbasecharacters.html
- Source file: programasweights/avatar/public/assets/character.glb
- License: CC0 1.0 Universal; archived at ASSETS/Quaternius-Universal-Base-Characters-LICENSE.txt.
- The asset is a rigged humanoid base. The project applies original unarmed idle/locomotion poses through TransformManager and updates the skinned bone matrices with Filament's Animator.

### Quaternius — Ultimate Animated Animal Pack (CC0)
- Official pack: https://quaternius.com/packs/ultimateanimatedanimals.html
- License: CC0 1.0; 12 animated animal models, glTF among the published formats, with 12+ animation clips per animal.
- Selected models: deer, wolf and bird. They are ambient wildlife only: wander, perch/hover and retreat from nearby players; they do not modify match simulation or collision.
- Build-time source mirror: `crisleyhguimaraes/space-ship`, pinned commit `c53b865c698d201fae129640f0a14f98f37e081b`. The selected binary files are checked against their Git blob SHA-1 and expected byte length before packaging.
- The APK stores the verified files under `app/src/main/assets/life/`; runtime is completely offline.

### Quaternius — Cute Animated Monsters Pack (CC0)
- Official pack: https://quaternius.com/packs/cutemonsters.html
- License: CC0 1.0; 21 animated low-poly creatures with their own animation sets and glTF/FBX/OBJ/Blend formats.
- Selected models: mushroom, walking tree and ghost. They serve as visual camp guardians with idle/hover/sway cycles; the native camp health/respawn rules remain unchanged.
- Files use the same pinned mirror commit and Git blob verification as the animal models.
- Fetch script: `tools/fetch_cc0_life_assets.py`. It also validates the GLB v2 header, mesh/node payload and rejects external buffer/image URIs so the APK stays self-contained.

### Project-authored terrain PBR maps — 0.16.0
- `tools/generate_terrain_materials.py` creates deterministic tileable albedo and tangent-space normal maps for grass, moss, packed soil and exposed rock.
- Eight 256×256 PNG maps are generated at build time. They are embedded in the runtime world GLB; no external file fetch, runtime procedural generation or network access is required.
- Terrain UVs are authored per vertex at a fixed world-space repeat scale. The existing terrain heightfield, river carve, lane layout and native collision geometry are unchanged.
- Four PBR texture pairs are reused by the five terrain color variants. This changes surface detail without adding terrain meshes or decorative entities.

## Generated by the project
- WorldGlbBuilder.kt generates the sculpted terrain, river bed/banks, curved stone roads, forest clearings, objective shrines, base walls and deep-water underlay. Procedural fern cards, flower clumps, mushroom clusters, fallen-timber meshes and boulder fields were removed from the runtime terrain mesh.
- tools/fetch_cc0_nature_assets.py verifies the pinned Quaternius source files and bakes the textured groundcover and rock placements into two self-contained GLBs with five material batches total.
- FilamentGameRenderer.kt loads the two baked nature meshes as static assets, plus KayKit castles, homes, towers and bridges; 32 tree placements use three shared CC0 tree models and 12 shrub placements use one shared bush model. Six ambient animals and eight camp guardians remain shared, offline GLB assets.
- Tree collision blockers and native navigation remain unchanged; decorative groundcover and rock meshes remain non-blocking as before.


## Project-authored character gear — 0.14.0
- Runtime source: `app/src/main/java/com/duckdream/neonbreach/HeroGearGlbBuilder.kt`.
- The project generates small GLB armor/costume attachments for three playable identities: Lyra, Bastion and Kairo.
- Geometry includes chest plates, shoulders, forearms, thigh guards, boots, head pieces and back cloth.
- Attachments are parented to the existing Quaternius skeleton joints by `FilamentGameRenderer.kt`; the character body remains the shared CC0 base mesh.
- The attachment geometry and materials are original project-authored code. No new third-party character pack or weapon model is introduced.


## Project-authored visual overhaul — 0.15.0
- `HeroGearGlbBuilder.kt` now produces five role silhouettes. The three playable identities remain Lyra, Bastion and Kairo; bots additionally use original arcanist and ranger attachments according to their native role.
- Equipment remains procedural, low-poly, bone-parented, offline, and project-authored. No new external character model or animation pack was imported.
- `ArenaMenuArtworkView.kt` is original Canvas vector art for the home screen. It has no external bitmap or network dependency.
- The new terrain remains generated by `WorldGlbBuilder.kt`; height coefficients are mirrored in `ArenaPhysics.cpp` to keep collision and rendered elevation aligned.

## Playable CC0 hero bodies — 0.15.9

- Quaternius models: Woman Casual (Lyra), Man in Long Sleeves (Bastion), Woman in Tank Top (Kairo).
- Provenance, exact hashes, CC0 links and locomotion clips are listed in `app/src/main/assets/heroes/README.md` and `cc0-manifest.json`.
- These meshes are separate from the legacy shared rig for bots and lane units.
