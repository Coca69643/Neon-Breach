import 'package:flutter/foundation.dart';

enum ArenaHeroSpecies {
  human,
  synthetic,
  creature,
  other,
}

extension ArenaHeroSpeciesPresentation on ArenaHeroSpecies {
  String get label => switch (this) {
        ArenaHeroSpecies.human => 'HUMANO',
        ArenaHeroSpecies.synthetic => 'SINTÉTICO',
        ArenaHeroSpecies.creature => 'CRIATURA',
        ArenaHeroSpecies.other => 'OUTRO',
      };

  String get pluralLabel => switch (this) {
        ArenaHeroSpecies.human => 'HUMANOS',
        ArenaHeroSpecies.synthetic => 'SINTÉTICOS',
        ArenaHeroSpecies.creature => 'CRIATURAS',
        ArenaHeroSpecies.other => 'OUTROS',
      };
}

/// UI and 3D-preview data for one selectable combatant.
///
/// Framing is stored per hero, so humanoids and future non-humanoid models can
/// share the same screen while using different scale, camera and preview yaw.
@immutable
class ArenaHeroDefinition {
  const ArenaHeroDefinition({
    required this.id,
    required this.name,
    required this.species,
    required this.role,
    required this.summary,
    required this.modelAsset,
    required this.idleAnimation,
    this.previewScale = 0.52,
    this.previewOffsetX = -0.9,
    this.matchScale = 0.76,
    this.previewCameraHeight = 1.15,
    this.previewCameraDistance = 5.0,
    this.previewTargetHeight = 1.08,
    this.previewYawRadians = 0,
    this.previewFovDegrees = 38,
  });

  final String id;
  final String name;
  final ArenaHeroSpecies species;
  final String role;
  final String summary;
  final String modelAsset;
  final String idleAnimation;

  final double previewScale;
  final double previewOffsetX;
  final double matchScale;
  final double previewCameraHeight;
  final double previewCameraDistance;
  final double previewTargetHeight;
  final double previewYawRadians;
  final double previewFovDegrees;
}

abstract final class ArenaHeroCatalog {
  /// Experimental metadata is kept outside [heroes], so the prototype can be
  /// previewed without entering the production match roster.
  static const ArenaHeroDefinition syntheticPrototype = ArenaHeroDefinition(
    id: 'synthetic-prototype',
    name: 'SYNTH-01',
    species: ArenaHeroSpecies.synthetic,
    role: 'MOBILIDADE EXPERIMENTAL',
    summary: 'Plataforma humanoide modular com perfil de travessia exclusivo.',
    modelAsset: 'procedural://synthetic-01',
    idleAnimation: 'procedural-idle',
    previewScale: 1,
    previewOffsetX: 0,
    matchScale: 0.8,
  );

  /// Add production-ready characters here after rig, clips and integration
  /// have been completed and tested.
  static const List<ArenaHeroDefinition> heroes = [
    ArenaHeroDefinition(
      id: 'lyra',
      name: 'LYRA',
      species: ArenaHeroSpecies.human,
      role: 'SUPORTE',
      summary: 'Apoio e sustentação da equipe.',
      modelAsset: 'assets/heroes/lyra.glb',
      idleAnimation: 'HumanArmature|Female_Idle',
      previewYawRadians: 0,
      previewOffsetX: -0.9,
      matchScale: 0.76,
    ),
    ArenaHeroDefinition(
      id: 'bastion',
      name: 'BASTION',
      species: ArenaHeroSpecies.human,
      role: 'DEFENSOR',
      summary: 'Proteção e presença na linha de frente.',
      modelAsset: 'assets/heroes/bastion.glb',
      idleAnimation: 'HumanArmature|Man_Idle',
      previewYawRadians: 0,
      previewOffsetX: -0.9,
      matchScale: 0.76,
    ),
    ArenaHeroDefinition(
      id: 'kairo',
      name: 'KAIRO',
      species: ArenaHeroSpecies.human,
      role: 'MOBILIDADE',
      summary: 'Reposicionamento e ritmo de combate.',
      modelAsset: 'assets/heroes/kairo.glb',
      idleAnimation: 'HumanArmature|Man_Idle',
      previewYawRadians: 0,
      previewOffsetX: -0.9,
      matchScale: 0.76,
    ),
  ];

  static List<ArenaHeroDefinition> get playable =>
      List<ArenaHeroDefinition>.unmodifiable(heroes);

  static Set<String> get playableIds => Set<String>.unmodifiable(
        playable.map((hero) => hero.id),
      );

  static List<ArenaHeroSpecies> get availableSpecies {
    return ArenaHeroSpecies.values
        .where((species) => playable.any((hero) => hero.species == species))
        .toList(growable: false);
  }

  /// Keep category navigation out of the UI until the roster actually spans
  /// more than one species. New categories appear automatically with new heroes.
  static bool get hasMultipleSpecies => availableSpecies.length > 1;

  static ArenaHeroDefinition? byId(String? id) {
    for (final hero in playable) {
      if (hero.id == id) return hero;
    }
    return null;
  }

  static ArenaHeroDefinition get fallback => playable.first;
}
