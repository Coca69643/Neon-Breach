# Project Arena — roster and character selection

## UI structure

The selection flow is data-driven. `ArenaHeroCatalog` is the source of truth
for the playable roster. The screen reads the catalog and creates its species
filters from the species present in the roster.

The interface has two independent areas:

- **Character stage:** full-screen 3D presentation, identity, role and summary.
- **Roster:** scrollable character list, selection state and confirmation.
- Species filters only appear when the playable roster contains more than one species.

This keeps the selection layout stable as the roster grows. New species do not
require a new screen or manually maintained filter buttons.

## Adding a future character

1. Bundle its GLB and required animation clips under `flutter/assets`.
2. Add an `ArenaHeroDefinition` to
   `flutter/lib/game/arena_hero_catalog.dart`.
3. Set its species, role, summary, model path and idle animation clip.
4. Tune `previewScale`, `previewOffsetX`, camera height/distance/target,
   `previewYawRadians` and `matchScale` for that model's proportions and front direction.
5. Add its gameplay identity to `MobaHeroId` and connect it in
   `ArenaApp._mapHero` plus the match simulation before making it selectable
   in a production build.
6. Add an automated test for its metadata and preview calibration.

Supported species are extensible: human, synthetic, creature and other.
Adding the first playable entry of a species automatically exposes that
species in the roster filters.

## Rendering constraints

The preview uses a dedicated `SceneView` with pixel ratio capped at 1.0.
Camera and model framing are per-character metadata, not global constants.
This allows varied silhouettes to share the same screen while keeping the
preview renderer bounded for mobile hardware.

## Species filter policy

The current roster contains only humans, so no species selector is shown.
`ArenaHeroCatalog.hasMultipleSpecies` enables the filters as soon as a second
species is added. The species taxonomy remains ready for synthetic, creature
and other character types without adding empty or redundant controls.

## Scene integration

The selection stage is full-bleed: the 3D preview is the screen background,
while the roster is a single side overlay. The main menu now previews the same
urban battlefield terrain, building kit and street details used in a match.
