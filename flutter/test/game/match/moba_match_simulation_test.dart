import 'package:flutter_test/flutter_test.dart';
import 'package:project_arena_flutter/game/match/moba_match_simulation.dart';

void advanceFor(MobaMatchSimulation simulation, double seconds) {
  final frames = (seconds * 60).round();
  for (var frame = 0; frame < frames; frame++) {
    simulation.step(1 / 60);
  }
}

void main() {
  group('MobaMatchSimulation', () {
    test('starts as a 5v5 lane match with minion waves and 18 towers', () {
      final simulation = MobaMatchSimulation(heroId: MobaHeroId.lyra);
      final state = simulation.snapshot;

      expect(state.bots, hasLength(9));
      expect(state.minions, hasLength(24));
      expect(state.blueMinions, 12);
      expect(state.redMinions, 12);
      expect(state.towers, hasLength(18));
      expect(state.blueTowersAlive, 9);
      expect(state.redTowersAlive, 9);
      expect(state.playerLevel, 1);
      expect(state.playerGold, 500);
      expect(state.blueCoreHealth, MobaMatchSimulation.coreMaxHealth);
      expect(state.redCoreHealth, MobaMatchSimulation.coreMaxHealth);
      expect(state.winner, isNull);
    });

    test('core stays protected until one complete lane loses all towers', () {
      final simulation = MobaMatchSimulation(heroId: MobaHeroId.bastion);

      expect(simulation.canDamageCore(MobaTeam.blue), isFalse);
      expect(simulation.canDamageCore(MobaTeam.red), isFalse);
    });

    test('movement uses a fixed simulation step and stays inside the map', () {
      final simulation = MobaMatchSimulation(heroId: MobaHeroId.kairo);
      final start = simulation.snapshot.playerPosition;

      for (var frame = 0; frame < 60; frame++) {
        simulation.step(1 / 60, moveX: 1, moveZ: 0);
      }

      final moved = simulation.snapshot.playerPosition;
      expect(moved.x, greaterThan(start.x + 5));
      expect(moved.x, lessThanOrEqualTo(56.0));
      expect(simulation.snapshot.elapsedSeconds, closeTo(1, 0.001));
    });

    test('player cannot walk through the river except over bridge decks', () {
      final simulation = MobaMatchSimulation(heroId: MobaHeroId.kairo);
      for (var frame = 0; frame < 60 * 8; frame++) {
        simulation.step(1 / 60, moveX: 0, moveZ: 1);
      }
      expect(simulation.snapshot.playerPosition.z, lessThan(-1.0));
      expect(simulation.snapshot.playerPosition.z, greaterThan(-37.0));
    });

    test('rejects invalid frame deltas without corrupting match state', () {
      final simulation = MobaMatchSimulation(heroId: MobaHeroId.lyra);

      simulation.step(double.nan);
      simulation.step(double.infinity);
      simulation.step(-1);

      expect(simulation.snapshot.elapsedSeconds, 0);
      expect(simulation.snapshot.minions, hasLength(24));
    });

    test('hero abilities share a cooldown and remain hero-specific', () {
      final lyra = MobaMatchSimulation(heroId: MobaHeroId.lyra);
      final bastion = MobaMatchSimulation(heroId: MobaHeroId.bastion);
      final kairo = MobaMatchSimulation(heroId: MobaHeroId.kairo);

      lyra.step(1 / 30, castSkill: true);
      bastion.step(1 / 30, castSkill: true);
      kairo.step(1 / 30, castSkill: true);

      expect(lyra.snapshot.playerSkillCooldown, greaterThan(8.9));
      expect(bastion.snapshot.playerSkillCooldown, greaterThan(8.9));
      expect(kairo.snapshot.playerSkillCooldown, greaterThan(8.9));
      expect(lyra.snapshot.playerPosition.z, lessThan(-27));
      expect(kairo.snapshot.playerPosition.z, greaterThan(-27));
    });

    test('long simulation keeps minion count within its fixed mobile budget', () {
      final simulation = MobaMatchSimulation(heroId: MobaHeroId.bastion);

      advanceFor(simulation, 32);

      expect(simulation.activeMinionCount, greaterThan(0));
      expect(simulation.activeMinionCount, lessThanOrEqualTo(
        MobaMatchSimulation.maxMinions,
      ));
      expect(simulation.snapshot.elapsedSeconds, closeTo(32, 0.02));
      expect(simulation.snapshot.towers, hasLength(18));
    });

    test('wave scheduling does not create survival or gathering systems', () {
      final simulation = MobaMatchSimulation(heroId: MobaHeroId.lyra);
      final state = simulation.snapshot;

      expect(state.playerGold, 500);
      expect(state.playerXp, 0);
      expect(state.playerLevel, 1);
      expect(state.minions.every((unit) => MobaLane.values.contains(unit.lane)), isTrue);
      expect(state.towers.every((tower) => MobaLane.values.contains(tower.lane)), isTrue);
    });
  });
}
