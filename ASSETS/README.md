# Asset register — Project Arena 0.1

## Included

### Quaternius — Universal Base Characters
- Asset: `app/src/main/assets/characters/quaternius-character.glb.b64`
- Source pack: https://quaternius.com/packs/universalbasecharacters.html
- Source file: `programasweights/avatar/public/assets/character.glb`
- License: CC0 1.0 Universal.
- Included file is a Base64-wrapped GLB so the repository text-content API can store the binary payload losslessly. The Android renderer decodes it before glTF loading.
- This file is a rigged humanoid base model. The first version applies procedural locomotion transforms to the humanoid skeleton.
- The full source license is archived in `ASSETS/Quaternius-Universal-Base-Characters-LICENSE.txt`.

## Generated in project code

Terrain, curved trails, stream, trees, shrubs, rocks, grass details, shrine and capture beacon are generated at runtime by `WorldGlbBuilder.kt`. These meshes are original project geometry, not third-party CC0 assets.

## Planned import gate

Any future Poly Haven or Kenney asset must be added only after its exact asset page, original file, license, triangle count, texture dimensions and mobile memory cost are recorded here. A library-level CC0 statement is not a substitute for recording the specific imported asset.
