import 'package:flutter_test/flutter_test.dart';
import 'package:project_arena_flutter/game/match/moba_match_simulation.dart';
import 'package:project_arena_flutter/game/world/arena_world_catalog.dart';

void advanceFor(
  MobaMatchSimulation simulation,
  double seconds, {
  double moveX = 0,
  double moveZ = 0,
  bool externalPlayerMovement = false,
}) {
  final frames = (seconds * 60).round();
  for (var frame = 0; frame < frames; frame++) {
    simulation.step(
      1 / 60,
      moveX: moveX,
      moveZ: moveZ,
      externalPlayerMovement: externalPlayerMovement,
    );
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

    test('neutral camps are present in the live match snapshot', () {
      final simulation = MobaMatchSimulation(heroId: MobaHeroId.lyra);
      final camps = simulation.snapshot.neutralCamps;
      expect(camps, hasLength(3));
      expect(camps.every((camp) => camp.state == MobaNeutralCampState.dormant), isTrue);
      expect(camps.every((camp) => camp.units.length == 2), isTrue);
    });

    test('neutral camp aggro damages a nearby player and returns after leash break', () {
      final site = ArenaWorldCatalog.neutralCampSites.first;
      final simulation = MobaMatchSimulation(
        heroId: MobaHeroId.bastion,
        spawnPosition: MobaPoint(site.$3 + 6.0, site.$4),
      );
      final health = simulation.snapshot.playerHealth;
      advanceFor(simulation, 3);
      expect(simulation.snapshot.playerHealth, lessThan(health));
      expect(simulation.snapshot.neutralCamps.first.state, MobaNeutralCampState.aggro);
      simulation.applyPhysicsPlayerPosition(MobaPoint(site.$3 + 18, site.$4));
      simulation.step(1 / 30);
      expect(
        simulation.snapshot.neutralCamps.first.state,
        MobaNeutralCampState.returning,
        reason: 'the leash transition must be observable on the first tick after leaving the aggro radius',
      );

      advanceFor(simulation, 3.0);
      final returned = simulation.snapshot.neutralCamps.first;
      expect(returned.state, MobaNeutralCampState.dormant);
      expect(returned.units, hasLength(2));
      expect(
        returned.units.every((unit) => unit.health == unit.maxHealth),
        isTrue,
        reason: 'a fully returned camp restores its original group and health',
      );
      final expectedSpawnPoints = <MobaPoint>[
        MobaPoint(site.$3 - 1.15, site.$4),
        MobaPoint(site.$3 + 1.15, site.$4 + 0.65),
      ];
      for (var index = 0; index < expectedSpawnPoints.length; index++) {
        expect(
          returned.units[index].position.distanceTo(expectedSpawnPoints[index]),
          lessThan(0.01),
          reason: 'unit $index must return to its authored anchor',
        );
      }
    });

    test('neutral camps are selectable and take damage through the normal attack path', () {
      final site = ArenaWorldCatalog.neutralCampSites.first;
      final simulation = MobaMatchSimulation(
        heroId: MobaHeroId.bastion,
        spawnPosition: MobaPoint(site.$3, site.$4),
      );
      simulation.cyclePlayerTarget();
      final before = simulation.snapshot.selectedTarget;
      expect(before, isNotNull);
      expect(before!.kind, 'NEUTRAL');
      simulation.step(1 / 30, basicAttack: true);
      expect(simulation.snapshot.selectedTarget!.health, lessThan(before.health));
    });

    test('clearing a neutral camp pays once and the camp respawns', () {
      final site = ArenaWorldCatalog.neutralCampSites.first;
      final simulation = MobaMatchSimulation(
        heroId: MobaHeroId.bastion,
        spawnPosition: MobaPoint(site.$3, site.$4),
      );
      for (var frame = 0; frame < 900; frame++) {
        if (simulation.snapshot.selectedTarget == null) {
          simulation.cyclePlayerTarget();
        }
        simulation.step(1 / 30, basicAttack: true);
        if (simulation.snapshot.neutralCamps.first.state ==
            MobaNeutralCampState.defeated) {
          break;
        }
      }
      final cleared = simulation.snapshot.neutralCamps.first;
      expect(cleared.state, MobaNeutralCampState.defeated);
      expect(cleared.respawnSeconds, greaterThan(0));
      expect(simulation.snapshot.playerGold, greaterThanOrEqualTo(629),
          reason: 'two unit rewards and the clear bonus must be paid exactly once');

      simulation.applyPhysicsPlayerPosition(const MobaPoint(0, -63));
      advanceFor(simulation, 61);
      final respawned = simulation.snapshot.neutralCamps.first;
      expect(respawned.state, MobaNeutralCampState.dormant);
      expect(respawned.units, hasLength(2));
      expect(respawned.units.every((unit) => unit.health == unit.maxHealth), isTrue);
    });

    test('quartermaster shop is proximity-gated and sells each upgrade once', () {
      final away = MobaMatchSimulation(heroId: MobaHeroId.lyra);
      expect(
        away.purchaseShopItem(MobaShopItem.impactCell),
        isFalse,
        reason: 'shop purchases require the player to be near the in-world merchant',
      );

      final simulation = MobaMatchSimulation(
        heroId: MobaHeroId.lyra,
        spawnPosition: const MobaPoint(
          ArenaWorldCatalog.shopkeeperX,
          ArenaWorldCatalog.shopkeeperZ,
        ),
      );
      expect(simulation.snapshot.playerGold, 500);
      expect(simulation.purchaseShopItem(MobaShopItem.impactCell), isTrue);
      expect(simulation.snapshot.playerGold, closeTo(220, 1e-9));
      expect(simulation.snapshot.playerPower, closeTo(1.12, 1e-9));
      expect(
        simulation.snapshot.playerItems,
        contains(MobaShopItem.impactCell),
      );
      expect(
        simulation.purchaseShopItem(MobaShopItem.impactCell),
        isFalse,
        reason: 'a purchased upgrade cannot be bought repeatedly',
      );
    });

    test('reinforced plate raises maximum health and heals the player', () {
      final simulation = MobaMatchSimulation(
        heroId: MobaHeroId.bastion,
        spawnPosition: const MobaPoint(
          ArenaWorldCatalog.shopkeeperX,
          ArenaWorldCatalog.shopkeeperZ,
        ),
      );

      expect(simulation.purchaseShopItem(MobaShopItem.reinforcedPlate), isTrue);
      expect(simulation.snapshot.playerMaxHealth, 700);
      expect(simulation.snapshot.playerHealth, 700);
      expect(simulation.snapshot.playerGold, closeTo(180, 1e-9));
      expect(
        simulation.snapshot.playerItems,
        contains(MobaShopItem.reinforcedPlate),
      );
    });

    test('AI heroes and minions use independent NPC appearance variants', () {
      final simulation = MobaMatchSimulation(heroId: MobaHeroId.lyra);
      final state = simulation.snapshot;

      expect(
        state.bots.map((bot) => bot.visualId).toSet(),
        hasLength(6),
        reason: 'bot appearances must not be selected from Lyra, Bastion or Kairo',
      );
      for (final team in MobaTeam.values) {
        final wave = state.minions
            .where((unit) =>
                unit.team == team && unit.lane == MobaLane.top)
            .toList();
        expect(wave, hasLength(4));
        expect(
          wave.map((unit) => unit.visualId).toSet(),
          hasLength(4),
          reason: 'each lane wave must have four distinct visual bodies',
        );
      }
    });

    test('one allied bot starts inside the player camera area for every hero', () {
      for (final hero in MobaHeroId.values) {
        final simulation = MobaMatchSimulation(heroId: hero);
        final state = simulation.snapshot;
        final player = state.playerPosition;
        final alliedBots = state.bots.where((bot) => bot.team == MobaTeam.blue);
        final nearest = alliedBots
            .map((bot) => bot.position.distanceTo(player))
            .reduce((a, b) => a < b ? a : b);

        expect(nearest, lessThan(9.0),
            reason: '${hero.name} must see at least one ally near the opening position');
        final visibleAlly = alliedBots.firstWhere(
          (bot) => bot.position.distanceTo(player) == nearest,
        );
        expect(
          ArenaWorldCatalog.isWalkable(
            visibleAlly.position.x,
            visibleAlly.position.z,
            elevation: visibleAlly.position.elevation,
          ),
          isTrue,
        );
      }
    });

    test('all bots spawn on walkable ground outside tower collision footprints', () {
      final simulation = MobaMatchSimulation(heroId: MobaHeroId.bastion);

      for (final bot in simulation.snapshot.bots) {
        expect(
          ArenaWorldCatalog.isWalkable(
            bot.position.x,
            bot.position.z,
            elevation: bot.position.elevation,
          ),
          isTrue,
          reason: '${bot.id} must not spawn inside a tower, wall or blocked terrain',
        );
      }
    });

    test('roaming bots use a lateral flank route instead of one straight lane', () {
      // Bastion occupies role 0, so the blue team has an active role-3 flanker.
      final simulation = MobaMatchSimulation(heroId: MobaHeroId.bastion);
      final before = simulation.snapshot.bots.firstWhere(
        (bot) => bot.id == 'blue_bot_3',
      );

      advanceFor(simulation, 4.0);

      final after = simulation.snapshot.bots.firstWhere(
        (bot) => bot.id == 'blue_bot_3',
      );
      expect(
        after.position.x,
        greaterThan(before.position.x + 3.0),
        reason: 'the flank role must leave its spawn lane and enter the east side street',
      );
      expect(
        ArenaWorldCatalog.isWalkable(
          after.position.x,
          after.position.z,
          elevation: after.position.elevation,
        ),
        isTrue,
        reason: 'the flanker must remain on valid ground while routing around the city',
      );
    });

    test('bots and minions remain on navigable ground while approaching objectives', () {
      final simulation = MobaMatchSimulation(heroId: MobaHeroId.bastion);

      advanceFor(simulation, 45);

      for (final bot in simulation.snapshot.bots.where(
        (unit) => unit.respawnSeconds <= 0,
      )) {
        expect(
          ArenaWorldCatalog.isWalkable(
            bot.position.x,
            bot.position.z,
            includeTowerCollision: false,
            elevation: bot.position.elevation,
          ),
          isTrue,
          reason: '${bot.id} must not leave the playable ground while navigating',
        );
      }
      for (final minion in simulation.snapshot.minions) {
        expect(
          ArenaWorldCatalog.isWalkable(
            minion.position.x,
            minion.position.z,
            includeTowerCollision: false,
            elevation: minion.position.elevation,
          ),
          isTrue,
          reason: 'minion ${minion.id} must remain on traversable terrain',
        );
      }
    });

    test('Kairo dash stops at a wall instead of tunnelling through it', () {
      final simulation = MobaMatchSimulation(
        heroId: MobaHeroId.kairo,
        spawnPosition: const MobaPoint(-63, -38),
      );

      simulation.step(1 / 60, moveX: 1);
      simulation.step(1 / 60, castSkill: true);

      expect(
        simulation.snapshot.playerPosition.x,
        lessThan(-57.4),
        reason: 'the swept dash must stop before the building side wall',
      );
      expect(
        ArenaWorldCatalog.isWalkable(
          simulation.snapshot.playerPosition.x,
          simulation.snapshot.playerPosition.z,
          elevation: simulation.snapshot.playerPosition.elevation,
        ),
        isTrue,
      );
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

    test('falling outside the island enters the normal defeated and respawn lifecycle', () {
      final simulation = MobaMatchSimulation(heroId: MobaHeroId.bastion);
      final home = simulation.snapshot.playerPosition;

      simulation.applyPhysicsPlayerPosition(const MobaPoint(110, 0));

      expect(simulation.snapshot.playerHealth, 0);
      expect(simulation.snapshot.playerLastDamageSource, 'Queda fora do mapa');
      expect(simulation.snapshot.playerLastDamageAmount, greaterThan(0));
      expect(simulation.snapshot.playerDamageFeedbackSeconds, greaterThan(0));
      expect(simulation.snapshot.playerRespawnSeconds, greaterThan(4.9));
      expect(
        simulation.snapshot.playerPosition.x,
        110,
        reason: 'death must preserve the elimination location during the countdown',
      );

      advanceFor(simulation, 5.2);

      expect(simulation.snapshot.playerHealth, simulation.snapshot.playerMaxHealth);
      expect(simulation.snapshot.playerRespawnSeconds, 0);
      expect(simulation.snapshot.playerPosition.x, closeTo(home.x, 0.001));
      expect(simulation.snapshot.playerPosition.z, closeTo(home.z, 0.001));
      expect(simulation.snapshot.playerSpawnShieldSeconds, greaterThan(0));
    });

    test('Bastion shield strike exposes the heavy punch animation window', () {
      final simulation = MobaMatchSimulation(heroId: MobaHeroId.bastion);

      simulation.step(1 / 30, castSkill: true);

      expect(simulation.snapshot.playerSkillPulseSeconds, greaterThan(0.8));
      expect(simulation.snapshot.playerAttackSeconds, greaterThan(0.4));
    });

    test('Linn Protocolo Feral transforms temporarily and returns to humanoid form', () {
      final simulation = MobaMatchSimulation(heroId: MobaHeroId.linn);

      expect(simulation.snapshot.playerFeralSeconds, 0);
      expect(simulation.snapshot.playerFeralBlend, 0);
      simulation.step(1 / 30, castSkill: true);

      expect(simulation.snapshot.playerFeralSeconds, closeTo(8, 1e-6));
      expect(simulation.snapshot.playerSkillCooldown, closeTo(22, 1e-6));
      expect(simulation.consumePhysicsDashRequest(), isNull,
          reason: 'Linn changes form; the ultimate is not Kairo’s dash path');

      advanceFor(simulation, 0.35);
      expect(simulation.snapshot.playerFeralBlend, greaterThan(0.5));
      expect(simulation.snapshot.playerFeralBlend, lessThanOrEqualTo(1));
      expect(simulation.snapshot.playerFeralSeconds, greaterThan(7.5));

      advanceFor(simulation, 8.7);
      expect(simulation.snapshot.playerFeralSeconds, 0);
      expect(simulation.snapshot.playerFeralBlend, 0);
      expect(simulation.snapshot.playerSkillCooldown, greaterThan(12.5));
    });

    test('attacks turn the hero toward the target and hold that facing through the strike', () {
      final simulation = MobaMatchSimulation(
        heroId: MobaHeroId.lyra,
        spawnPosition: const MobaPoint(-3.0, 65.0),
      );
      simulation.cyclePlayerTarget();

      simulation.step(
        1 / 30,
        moveX: 0,
        moveZ: -1,
        basicAttack: true,
        externalPlayerMovement: true,
      );

      expect(simulation.snapshot.playerFacingX, greaterThan(0.8));
      expect(simulation.snapshot.playerFacingZ.abs(), lessThan(0.35));

      for (var frame = 0; frame < 10; frame++) {
        simulation.step(
          1 / 30,
          moveX: 0,
          moveZ: -1,
          externalPlayerMovement: true,
        );
      }

      expect(
        simulation.snapshot.playerFacingX,
        greaterThan(0.8),
        reason: 'movement input must not overwrite target-facing during the strike',
      );
      expect(simulation.snapshot.playerFacingZ.abs(), lessThan(0.35));
    });

    test('external physics position disables duplicate logical movement', () {
      final simulation = MobaMatchSimulation(heroId: MobaHeroId.bastion);
      final start = simulation.snapshot.playerPosition;

      advanceFor(simulation, 1.0, moveX: 1, externalPlayerMovement: true);

      expect(simulation.snapshot.playerPosition.x, closeTo(start.x, 0.001));
      expect(simulation.snapshot.playerPosition.z, closeTo(start.z, 0.001));

      simulation.applyPhysicsPlayerPosition(
        MobaPoint(start.x + 2.0, start.z),
      );

      expect(simulation.snapshot.playerPosition.x, closeTo(start.x + 2.0, 0.001));
    });

    test('minion waves recycle defeated entities after reaching the mobile cap', () {
      final simulation = MobaMatchSimulation(heroId: MobaHeroId.bastion);
      var observedRecycledId = false;

      for (var frame = 0; frame < 150 * 60; frame++) {
        simulation.step(1 / 60);
        if (frame % 60 != 59) continue;
        final state = simulation.snapshot;
        expect(
          state.minions.length,
          lessThanOrEqualTo(MobaMatchSimulation.maxMinions),
        );
        if (state.minions.any((unit) => unit.id >= 48)) {
          observedRecycledId = true;
          break;
        }
      }

      expect(
        observedRecycledId,
        isTrue,
        reason: 'new waves must continue spawning after defeated minions are pruned',
      );
    });

    test('player movement cannot pass through a building side wall', () {
      final simulation = MobaMatchSimulation(
        heroId: MobaHeroId.bastion,
        spawnPosition: const MobaPoint(-63, -38),
      );

      for (var frame = 0; frame < 120; frame++) {
        simulation.step(1 / 60, moveX: 1);
        final position = simulation.snapshot.playerPosition;
        expect(
          ArenaWorldCatalog.isWalkable(
            position.x,
            position.z,
            elevation: position.elevation,
          ),
          isTrue,
        );
      }

      expect(
        simulation.snapshot.playerPosition.x,
        lessThan(-51.4),
        reason: 'the hero must stop before crossing the east interior side wall',
      );
    });

    test('player stays on the island while moving diagonally toward the border', () {
      final spawn = const MobaPoint(80, 30);
      expect(ArenaWorldCatalog.isWalkable(spawn.x, spawn.z), isTrue);
      final simulation = MobaMatchSimulation(
        heroId: MobaHeroId.kairo,
        spawnPosition: spawn,
      );

      for (var frame = 0; frame < 240; frame++) {
        simulation.step(1 / 60, moveX: 0.8, moveZ: 0.6);
        final position = simulation.snapshot.playerPosition;
        expect(
          ArenaWorldCatalog.isWalkable(
            position.x,
            position.z,
            elevation: position.elevation,
          ),
          isTrue,
          reason: 'every committed movement substep must stay on walkable terrain',
        );
      }
    });

    test('AI and minion attacks expose a short non-locomotion animation window', () {
      final simulation = MobaMatchSimulation(heroId: MobaHeroId.bastion);
      var botAttackSeen = false;
      var minionAttackSeen = false;

      for (var frame = 0; frame < 80 * 60; frame++) {
        simulation.step(1 / 60);
        // Attack windows last 0.38–0.42 seconds; a 0.05 second sample interval
        // observes them without allocating full snapshots on every fixed tick.
        if (frame % 3 != 2) continue;
        final state = simulation.snapshot;
        botAttackSeen |= state.bots.any((bot) => bot.attackSeconds > 0);
        minionAttackSeen |= state.minions.any((unit) => unit.attackSeconds > 0);
        if (botAttackSeen && minionAttackSeen) break;
      }

      expect(botAttackSeen, isTrue,
          reason: 'AI strikes must be visible to the renderer');
      expect(minionAttackSeen, isTrue,
          reason: 'minion strikes must be visible to the renderer');
    });

    test('a valid tactical map ping redirects one allied roamer', () {
      final simulation = MobaMatchSimulation(heroId: MobaHeroId.bastion);
      const target = MobaPoint(-54, -42);
      expect(
        ArenaWorldCatalog.isWalkable(
          target.x, target.z, includeTowerCollision: false,
        ),
        isTrue,
      );

      final roamers = simulation.snapshot.bots
          .where((bot) =>
              bot.team == MobaTeam.blue &&
              (bot.id == 'blue_bot_3' || bot.id == 'blue_bot_4'))
          .toList(growable: false);
      expect(roamers, isNotEmpty);
      final assigned = roamers.reduce(
        (a, b) => a.position.distanceTo(target) < b.position.distanceTo(target)
            ? a
            : b,
      );
      final beforeDistance = assigned.position.distanceTo(target);

      expect(simulation.issueTeamPing(target), isTrue);
      expect(simulation.snapshot.teamPingTarget, target);
      expect(simulation.snapshot.teamPingSeconds, greaterThan(7.9));

      advanceFor(simulation, 2.0);

      final after = simulation.snapshot.bots.firstWhere(
        (bot) => bot.id == assigned.id,
      );
      expect(
        after.position.distanceTo(target),
        lessThan(beforeDistance - 1.0),
        reason: 'the selected roamer must move toward the tactical map command',
      );
      expect(
        simulation.snapshot.teamPingTarget,
        target,
        reason: 'the command marker remains visible while the order is active',
      );
    });

    test('tactical pings reject water and inaccessible points', () {
      final simulation = MobaMatchSimulation(heroId: MobaHeroId.bastion);
      expect(
        simulation.issueTeamPing(const MobaPoint(18, 0)),
        isFalse,
        reason: 'a roamer must not be ordered into the canal away from a bridge',
      );
      expect(
        simulation.issueTeamPing(const MobaPoint(200, 0)),
        isFalse,
        reason: 'out-of-world tactical commands must be rejected',
      );
      expect(simulation.snapshot.teamPingTarget, isNull);
      expect(simulation.snapshot.teamPingSeconds, 0);
    });

    test('tactical ping expires and releases its assigned roamer', () {
      final simulation = MobaMatchSimulation(heroId: MobaHeroId.bastion);
      expect(
        simulation.issueTeamPing(const MobaPoint(-54, -42)),
        isTrue,
      );

      advanceFor(simulation, 8.5);

      expect(simulation.snapshot.teamPingTarget, isNull);
      expect(simulation.snapshot.teamPingSeconds, 0);
    });

    test('lane units eventually damage a tower instead of only exchanging attacks', () {
      final simulation = MobaMatchSimulation(heroId: MobaHeroId.bastion);

      advanceFor(simulation, 120);

      final damagedTowers = simulation.snapshot.towers
          .where((tower) => tower.health < tower.maxHealth)
          .toList(growable: false);
      expect(
        damagedTowers,
        isNotEmpty,
        reason: 'supported bots and minions must be able to reach tower attack points',
      );
      expect(
        damagedTowers.every((tower) => tower.health >= 0),
        isTrue,
        reason: 'tower health must never become negative',
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

    test('all four interior entrances remain reachable without a barricade blocking the door', () {
      final simulation = MobaMatchSimulation(heroId: MobaHeroId.bastion);

      for (final building in ArenaWorldCatalog.cityInteriors) {
        final door = MobaPoint(building.$2, building.$3 - 8.0);
        final blockingCover = simulation.snapshot.covers.any(
          (cover) => cover.position.distanceTo(door) < 1.8,
        );
        expect(
          blockingCover,
          isFalse,
          reason: '${building.$1} must not have a cover over the entrance',
        );

        final approach = MobaMatchSimulation(
          heroId: MobaHeroId.bastion,
          spawnPosition: MobaPoint(building.$2, building.$3 - 5.4),
        );
        for (var frame = 0; frame < 47; frame++) {
          approach.step(1 / 60, moveZ: 1);
        }
        expect(
          approach.snapshot.playerPosition.z,
          greaterThan(building.$3 - 1.6),
          reason: 'player must cross the doorway into ${building.$1}',
        );
        expect(
          ArenaWorldCatalog.isWalkable(
            approach.snapshot.playerPosition.x,
            approach.snapshot.playerPosition.z,
            elevation: approach.snapshot.playerPosition.elevation,
          ),
          isTrue,
        );
      }
    });

    test('side barricade remains destructible without sealing the interior entrance', () {
      final simulation = MobaMatchSimulation(
        heroId: MobaHeroId.bastion,
        spawnPosition: const MobaPoint(-74, -42.1),
      );
      final cover = simulation.snapshot.covers.firstWhere(
        (item) => item.id == 'west_south_door_barrier',
      );
      final initialHealth = cover.health;

      simulation.step(1 / 30, basicAttack: true);
      final damaged = simulation.snapshot.covers.firstWhere(
        (item) => item.id == cover.id,
      );
      expect(damaged.health, lessThan(initialHealth));
      expect(damaged.isDestroyed, isFalse);

      for (var hit = 0; hit < 3; hit++) {
        advanceFor(simulation, 0.82);
        simulation.step(1 / 30, basicAttack: true);
      }
      final destroyed = simulation.snapshot.covers.firstWhere(
        (item) => item.id == cover.id,
      );
      expect(destroyed.health, 0);
      expect(destroyed.isDestroyed, isTrue);

      final southDoor = ArenaWorldCatalog.cityInteriors.firstWhere(
        (building) => building.$1 == 'west_south',
      );
      expect(
        ArenaWorldCatalog.isWalkable(
          southDoor.$2,
          southDoor.$3 - 8.0,
        ),
        isTrue,
        reason: 'the entrance stays physically accessible before and after the side cover is destroyed',
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

    test('non-finite and oversized movement inputs cannot corrupt the player state', () {
      final simulation = MobaMatchSimulation(heroId: MobaHeroId.lyra);
      final start = simulation.snapshot.playerPosition;

      simulation.step(1 / 60, moveX: double.nan, moveZ: double.infinity);
      simulation.step(1 / 60, moveX: 500, moveZ: -500);

      final position = simulation.snapshot.playerPosition;
      expect(position.x.isFinite, isTrue);
      expect(position.z.isFinite, isTrue);
      expect(
        ArenaWorldCatalog.isWalkable(
          position.x,
          position.z,
          elevation: position.elevation,
        ),
        isTrue,
      );
      expect(position.distanceTo(start), lessThanOrEqualTo(0.2));
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

    test('Kairo dash is handed to Rapier when physics owns player movement', () {
      final simulation = MobaMatchSimulation(heroId: MobaHeroId.kairo);
      final start = simulation.snapshot.playerPosition;

      simulation.step(
        1 / 30,
        moveZ: 1,
        castSkill: true,
        externalPlayerMovement: true,
      );

      final request = simulation.consumePhysicsDashRequest();
      expect(request, isNotNull);
      expect(request!.x, closeTo(0, 1e-5));
      expect(request.z, closeTo(5.0, 1e-5));
      expect(simulation.snapshot.playerPosition.distanceTo(start), 0);
      expect(simulation.consumePhysicsDashRequest(), isNull);
      final resolved = MobaPoint(0, start.z + 4.2);
      simulation.applyPhysicsPlayerPosition(resolved);
      simulation.resolvePhysicsDashAt(resolved);
      expect(simulation.snapshot.playerPosition.z, resolved.z);
      expect(simulation.snapshot.playerSkillPulseSeconds, greaterThan(0));
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
    test('district capture grants territorial progression', () {
      final site = ArenaWorldCatalog.districtSites.first;
      final simulation = MobaMatchSimulation(
        heroId: MobaHeroId.bastion,
        spawnPosition: MobaPoint(site.$3, site.$4),
      );
      for (var tick = 0; tick < 240; tick++) {
        simulation.step(1 / 30);
      }
      final captured = simulation.snapshot.districts.firstWhere(
        (district) => district.id == site.$1,
      );
      expect(captured.owner, MobaTeam.blue);
      expect(captured.control, 100);
      expect(simulation.snapshot.playerGold, greaterThan(500));
    });
  });
}
