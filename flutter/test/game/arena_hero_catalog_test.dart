import 'package:flutter_test/flutter_test.dart';
import 'package:project_arena_flutter/game/arena_hero_catalog.dart';
import 'package:project_arena_flutter/game/state/arena_state_machine.dart';

void main() {
  group('ArenaHeroCatalog', () {
    test('has unique selectable ids and complete preview metadata', () {
      final heroes = ArenaHeroCatalog.playable;
      final ids = heroes.map((hero) => hero.id).toList();

      expect(ids.toSet(), hasLength(ids.length));
      expect(heroes, isNotEmpty);
      for (final hero in heroes) {
        expect(hero.id, isNotEmpty);
        expect(hero.name, isNotEmpty);
        expect(hero.role, isNotEmpty);
        expect(hero.summary, isNotEmpty);
        expect(hero.modelAsset, isNotEmpty);
        expect(hero.idleAnimation, isNotEmpty);
        expect(hero.previewScale, greaterThan(0));
        expect(hero.matchScale, greaterThan(0));
        expect(hero.matchScale, lessThanOrEqualTo(1));
        expect(hero.previewCameraDistance, greaterThan(0));
      }
    });

    test('synthetic prototype stays outside the production playable roster',
        () {
      expect(
        ArenaHeroCatalog.playableIds,
        containsAll(<String>{'lyra', 'bastion', 'kairo'}),
      );
      expect(
        ArenaHeroCatalog.playableIds,
        isNot(contains(ArenaHeroCatalog.syntheticPrototype.id)),
      );
      expect(ArenaHeroCatalog.playable, hasLength(3));
    });

    test('synthetic prototype metadata is marked experimental', () {
      final prototype = ArenaHeroCatalog.syntheticPrototype;

      expect(prototype.name, 'SYNTH-01');
      expect(prototype.species, ArenaHeroSpecies.synthetic);
      expect(prototype.modelAsset, 'procedural://synthetic-01');
      expect(prototype.role, 'MOBILIDADE EXPERIMENTAL');
    });

    test('state machine accepts ids from the roster catalog', () {
      expect(
        ArenaStateMachine.supportedHeroIds,
        unorderedEquals(ArenaHeroCatalog.playableIds),
      );
    });

    test('species filters are derived from the playable roster', () {
      expect(
        ArenaHeroCatalog.availableSpecies.toSet(),
        ArenaHeroCatalog.playable.map((hero) => hero.species).toSet(),
      );
      expect(
        ArenaHeroCatalog.availableSpecies.toSet().length,
        ArenaHeroCatalog.availableSpecies.length,
      );
    });

    test('single-species roster does not need a species filter', () {
      expect(ArenaHeroCatalog.hasMultipleSpecies, isFalse);
    });

    test('current roster previews use the front-facing calibration', () {
      for (final hero in ArenaHeroCatalog.playable) {
        expect(hero.previewYawRadians, 0);
      }
    });
  });
}
