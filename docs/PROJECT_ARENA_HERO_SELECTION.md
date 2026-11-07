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

## Novo herói — sintético metamórfico

A identidade selecionável deve ser um **robô humanoide original**, não uma raposa
que ocupa permanentemente um slot. A silhueta base precisa ser reconhecível por
proporções, capacete/sensores, núcleo visual e placas modulares, sem copiar um
personagem conhecido.

A ultimate, provisoriamente chamada **Protocolo Feral**, transforma o robô
temporariamente em uma forma quadrúpede de raposa. A raposa é uma forma de jogo
com rig e animações próprios — não a identidade completa do herói. A primeira
implementação deve conter somente essa transformação; formas animais adicionais
podem ser adicionadas depois por dados de catálogo, sem multiplicar slots no
elenco nem exigir que o jogador escolha um animal separado.

O robô humanoide permanece como apresentação principal na seleção de herói.
A transformação deve ter início/fim explícitos, duração e recarga legíveis, e
retornar à forma-base ao terminar ou quando a partida for interrompida.

## Scene integration

The selection stage is full-bleed: the 3D preview is the screen background,
while the roster is a single side overlay. The main menu uses a separate, lightweight 2D illustrated background and
does not instantiate the 3D match world.
