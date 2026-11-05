import 'package:flutter_test/flutter_test.dart';
import 'package:project_arena_flutter/game/match/moba_match_simulation.dart';
import 'package:project_arena_flutter/game/world/arena_world_catalog.dart';

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
      expect(state.covers, hasLength(2));
      expect(state.covers.every((cover) => cover.health > 0), isTrue);
      expect(state.blueTowersAlive, 9);
      expect(state.redTowersAlive, 9);
      expect(state.playerLevel, 1);
      expect(state.playerGold, 500);
      expect(state.blueCoreHealth, MobaMatchSimulation.coreMaxHealth);
      expect(state.redCoreHealth, MobaMatchSimulation.coreMaxHealth);
      expect(state.winner, isNull);
    });

    test('minion waves keep four readable formation slots per lane', () {
      final simulation = MobaMatchSimulation(heroId: MobaHeroId.lyra);

      advanceFor(simulation, 0.8);

      final topLane = simulation.snapshot.minions
          .where((unit) =>
              unit.team == MobaTeam.blue && unit.lane == MobaLane.top)
          .toList()
        ..sort((a, b) => a.id.compareTo(b.id));
      expect(topLane, hasLength(4));
      final xPositions = topLane.map((unit) => unit.position.x).toList();
      expect(
        xPositions.last - xPositions.first,
        greaterThan(2.0),
        reason: 'troops must not collapse into one straight centreline',
      );
    });

    test('core stays protected until one complete lane loses all towers', () {
      final simulation = MobaMatchSimulation(heroId: MobaHeroId.bastion);

      expect(simulation.canDamageCore(MobaTeam.blue), isFalse);
      expect(simulation.canDamageCore(MobaTeam.red), isFalse);
    });

    test('elevated units cannot acquire targets through a mezzanine floor', () {
      const ground = MobaPoint(0, 0);
      const upper = MobaPoint(0, 0, elevation: 3.35);
      expect(ground.distanceTo(upper), double.infinity);

      final moved = upper.moveToward(
        const MobaPoint(1, 0, elevation: 3.35),
        0.5,
      );
      expect(moved.elevation, 3.35);
      expect(moved.x, closeTo(0.5, 0.001));
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

    test('Bastion spawns on the top avenue and moves clear of the base', () {
      final simulation = MobaMatchSimulation(heroId: MobaHeroId.bastion);
      final start = simulation.snapshot.playerPosition;

      expect(start.x, closeTo(-36.0, 0.6));
      expect(start.z, -60.0);

      for (var frame = 0; frame < 30; frame++) {
        simulation.step(1 / 60, moveZ: 1);
      }

      final end = simulation.snapshot.playerPosition;
      expect(end.z, greaterThan(start.z + 2.0));
      expect(ArenaWorldCatalog.isWalkable(end.x, end.z), isTrue);
    });

    test('all three selected heroes can leave their own spawn lane', () {
      for (final hero in MobaHeroId.values) {
        final simulation = MobaMatchSimulation(heroId: hero);
        final start = simulation.snapshot.playerPosition;
        for (var frame = 0; frame < 36; frame++) {
          simulation.step(1 / 60, moveX: 0, moveZ: 1);
        }
        final end = simulation.snapshot.playerPosition;
        expect(
          end.z,
          greaterThan(start.z + 2.0),
          reason: '${hero.name} must be able to move out of the blue base',
        );
        expect(ArenaWorldCatalog.isWalkable(end.x, end.z), isTrue);
      }
    });

    test('central relay ownership persists until the meter reaches neutral', () {
      final relay = MobaObjectiveControl();

      expect(
        relay.update(6, blue: 2, red: 0),
        MobaTeam.blue,
      );
      expect(relay.owner, MobaTeam.blue);
      expect(relay.control, 100);

      expect(relay.update(1, blue: 0, red: 1), isNull);
      expect(relay.control, 91);
      expect(relay.owner, MobaTeam.blue,
          reason: 'first lost progress must not instantly remove the team bonus');

      final contestedAt = relay.control;
      expect(relay.update(2, blue: 1, red: 1), isNull);
      expect(relay.control, contestedAt);
      expect(relay.owner, MobaTeam.blue);

      expect(relay.update(10.2, blue: 0, red: 1), isNull);
      expect(relay.control, lessThan(0));
      expect(relay.owner, isNull,
          reason: 'the previous owner loses the relay only at neutral');

      expect(relay.update(12, blue: 0, red: 1), MobaTeam.red);
      expect(relay.control, -100);
      expect(relay.owner, MobaTeam.red);
    });

    test('central relay is captured only by uncontested presence', () {
      final simulation = MobaMatchSimulation(
        heroId: MobaHeroId.bastion,
        spawnPosition: const MobaPoint(0, 0),
      );

      expect(simulation.snapshot.centralObjective.owner, isNull);
      expect(simulation.snapshot.centralObjective.control, 0);
      expect(simulation.snapshot.centralObjective.contested, isFalse);

      advanceFor(simulation, 7);

      final objective = simulation.snapshot.centralObjective;
      expect(objective.owner, MobaTeam.blue);
      expect(objective.control, 100);
      expect(objective.contested, isFalse);
      expect(simulation.snapshot.playerGold, 650,
          reason: 'first relay capture must award team gold');
      expect(simulation.snapshot.playerXp, greaterThan(0));
    });

    test('construction cover blocks a doorway until destroyed', () {
      final simulation = MobaMatchSimulation(
        heroId: MobaHeroId.bastion,
        spawnPosition: const MobaPoint(-63, -38.7),
      );
      final cover = simulation.snapshot.covers.firstWhere(
        (item) => item.id == 'west_south_door_barrier',
      );

      for (var frame = 0; frame < 60; frame++) {
        simulation.step(1 / 60, moveZ: -1);
      }
      expect(
        simulation.snapshot.playerPosition.z,
        greaterThan(cover.position.z - 1.45),
        reason: 'the live barricade must block the doorway',
      );

      for (var hit = 0; hit < 4; hit++) {
        simulation.step(1 / 30, basicAttack: true);
        if (hit < 3) advanceFor(simulation, 0.82);
      }
      final destroyed = simulation.snapshot.covers.firstWhere(
        (item) => item.id == cover.id,
      );
      expect(destroyed.health, 0);
      expect(destroyed.isDestroyed, isTrue);

      for (var frame = 0; frame < 60; frame++) {
        simulation.step(1 / 60, moveZ: -1);
      }
      expect(
        simulation.snapshot.playerPosition.z,
        lessThan(cover.position.z - 1.8),
        reason: 'destroying the cover must open the entrance',
      );
    });

    test('basic attack shows swing feedback but no hit confirm out of range', () {
      final simulation = MobaMatchSimulation(heroId: MobaHeroId.bastion);
      final healthBefore = simulation.snapshot.playerHealth;

      simulation.step(1 / 30, basicAttack: true);

      expect(simulation.snapshot.playerAttackSeconds, greaterThan(0));
      expect(simulation.snapshot.playerHitConfirmSeconds, 0);
      expect(simulation.snapshot.playerHealth, healthBefore);

      advanceFor(simulation, 0.5);
      expect(simulation.snapshot.playerAttackSeconds, 0);
      expect(simulation.snapshot.playerHitConfirmSeconds, 0);
    });

    test('target cycle selects a nearby enemy and confirms a real hit', () {
      final simulation = MobaMatchSimulation(
        heroId: MobaHeroId.bastion,
        spawnPosition: const MobaPoint(0, 55.0),
      );

      simulation.cyclePlayerTarget();
      final target = simulation.snapshot.selectedTarget;
      expect(target, isNotNull);
      expect(target!.team, MobaTeam.red);
      expect(
        simulation.snapshot.playerPosition.distanceTo(target.position),
        lessThanOrEqualTo(MobaHeroId.bastion.basicRange),
      );

      simulation.step(1 / 30, basicAttack: true);

      expect(simulation.snapshot.playerHitConfirmSeconds, greaterThan(0));
      expect(simulation.snapshot.playerAttackSeconds, greaterThan(0));
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
      expect(kairo.snapshot.playerPosition.z, greaterThan(-56));
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
