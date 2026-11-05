import 'dart:math' as math;

import '../world/arena_world_catalog.dart';

enum MobaTeam { blue, red }

extension MobaTeamRules on MobaTeam {
  MobaTeam get enemy => this == MobaTeam.blue ? MobaTeam.red : MobaTeam.blue;
  double get forward => this == MobaTeam.blue ? 1.0 : -1.0;
  double get homeZ => this == MobaTeam.blue ? -63.0 : 63.0;
  int get index => this == MobaTeam.blue ? 0 : 1;
}

enum MobaLane { top, middle, bottom }

enum MobaHeroId { lyra, bastion, kairo }

extension MobaHeroRules on MobaHeroId {
  MobaLane get assignedLane => switch (this) {
        MobaHeroId.bastion => MobaLane.top,
        MobaHeroId.kairo => MobaLane.middle,
        MobaHeroId.lyra => MobaLane.bottom,
      };

  double get basicDamage => switch (this) {
        MobaHeroId.bastion => 48.0,
        MobaHeroId.kairo => 34.0,
        MobaHeroId.lyra => 39.0,
      };

  double get basicRange => switch (this) {
        MobaHeroId.lyra => 6.2,
        MobaHeroId.bastion => 4.0,
        MobaHeroId.kairo => 3.5,
      };

  double get basicAttackCooldown => switch (this) {
        MobaHeroId.lyra => 0.86,
        MobaHeroId.bastion => 0.78,
        MobaHeroId.kairo => 0.54,
      };

  String get id => name;
}

class MobaPoint {
  const MobaPoint(this.x, this.z);

  final double x;
  final double z;

  double distanceTo(MobaPoint other) =>
      math.sqrt(math.pow(x - other.x, 2) + math.pow(z - other.z, 2));

  MobaPoint moveToward(MobaPoint target, double distance) {
    final dx = target.x - x;
    final dz = target.z - z;
    final length = math.sqrt(dx * dx + dz * dz);
    if (length <= distance || length < 0.0001) return target;
    final t = distance / length;
    return MobaPoint(x + dx * t, z + dz * t);
  }
}

class MobaMinionSnapshot {
  const MobaMinionSnapshot({
    required this.id,
    required this.team,
    required this.lane,
    required this.ranged,
    required this.position,
    required this.health,
    required this.maxHealth,
  });

  final int id;
  final MobaTeam team;
  final MobaLane lane;
  final bool ranged;
  final MobaPoint position;
  final double health;
  final double maxHealth;
}

class MobaBotSnapshot {
  const MobaBotSnapshot({
    required this.id,
    required this.team,
    required this.lane,
    required this.heroId,
    required this.position,
    required this.health,
    required this.maxHealth,
    required this.respawnSeconds,
  });

  final String id;
  final MobaTeam team;
  final MobaLane lane;
  final MobaHeroId heroId;
  final MobaPoint position;
  final double health;
  final double maxHealth;
  final double respawnSeconds;
}

class MobaTowerSnapshot {
  const MobaTowerSnapshot({
    required this.team,
    required this.lane,
    required this.tier,
    required this.position,
    required this.health,
    required this.maxHealth,
  });

  final MobaTeam team;
  final MobaLane lane;
  final int tier;
  final MobaPoint position;
  final double health;
  final double maxHealth;
}

class MobaMatchSnapshot {
  const MobaMatchSnapshot({
    required this.elapsedSeconds,
    required this.heroId,
    required this.playerPosition,
    required this.playerHealth,
    required this.playerMaxHealth,
    required this.playerLevel,
    required this.playerXp,
    required this.xpForNextLevel,
    required this.playerGold,
    required this.playerSkillCooldown,
    required this.playerRespawnSeconds,
    required this.playerMoving,
    required this.playerAttackSeconds,
    required this.playerFacingX,
    required this.playerFacingZ,
    required this.blueTeamKills,
    required this.redTeamKills,
    required this.blueCoreHealth,
    required this.redCoreHealth,
    required this.blueCoreMaxHealth,
    required this.redCoreMaxHealth,
    required this.blueTowersAlive,
    required this.redTowersAlive,
    required this.blueMinions,
    required this.redMinions,
    required this.bots,
    required this.minions,
    required this.towers,
    required this.winner,
  });

  final double elapsedSeconds;
  final MobaHeroId heroId;
  final MobaPoint playerPosition;
  final double playerHealth;
  final double playerMaxHealth;
  final int playerLevel;
  final double playerXp;
  final double xpForNextLevel;
  final double playerGold;
  final double playerSkillCooldown;
  final double playerRespawnSeconds;
  final bool playerMoving;
  final double playerAttackSeconds;
  final double playerFacingX;
  final double playerFacingZ;
  final int blueTeamKills;
  final int redTeamKills;
  final double blueCoreHealth;
  final double redCoreHealth;
  final double blueCoreMaxHealth;
  final double redCoreMaxHealth;
  final int blueTowersAlive;
  final int redTowersAlive;
  final int blueMinions;
  final int redMinions;
  final List<MobaBotSnapshot> bots;
  final List<MobaMinionSnapshot> minions;
  final List<MobaTowerSnapshot> towers;
  final MobaTeam? winner;

  bool get isFinished => winner != null;
}

class _Minion {
  _Minion({
    required this.id,
    required this.team,
    required this.lane,
    required this.ranged,
    required this.position,
  })  : maxHealth = ranged ? 92.0 : 145.0,
        health = ranged ? 92.0 : 145.0;

  final int id;
  final MobaTeam team;
  final MobaLane lane;
  final bool ranged;
  final double maxHealth;
  MobaPoint position;
  double health;
  double attackCooldown = 0.25;
  double spawnDelay = 0.08;
  bool get alive => health > 0;
}

class _Bot {
  _Bot({
    required this.id,
    required this.team,
    required this.lane,
    required this.role,
    required this.heroId,
    required this.position,
  });

  final String id;
  final MobaTeam team;
  final MobaLane lane;
  final int role;
  final MobaHeroId heroId;
  MobaPoint position;
  double health = 420.0;
  double attackCooldown = 0.4;
  double respawnSeconds = 0;
  static const maxHealth = 420.0;
  bool get alive => health > 0 && respawnSeconds <= 0;
}

class _Tower {
  _Tower({
    required this.team,
    required this.lane,
    required this.tier,
    required this.position,
  });

  final MobaTeam team;
  final MobaLane lane;
  final int tier;
  final MobaPoint position;
  double health = 820.0;
  double attackCooldown = 0;
  static const maxHealth = 820.0;
  bool get alive => health > 0;
}

class MobaMatchSimulation {
  MobaMatchSimulation({
    required this.heroId,
    double fixedStep = 1 / 30,
  }) : _fixedStep = fixedStep {
    if (!fixedStep.isFinite || fixedStep <= 0 || fixedStep > 1 / 20) {
      throw ArgumentError.value(fixedStep, 'fixedStep');
    }
    _reset();
  }

  static const double waveIntervalSeconds = 26;
  static const double playerMoveSpeed = 5.6;
  static const double playerMaxHealthBase = 600;
  static const double coreMaxHealth = 2200;
  static const double towerMaxHealth = 820;
  static const int maxHeroLevel = 15;
  static const int maxMinions = 48;

  final MobaHeroId heroId;
  final double _fixedStep;
  final List<_Minion> _minions = [];
  final List<_Bot> _bots = [];
  final List<_Tower> _towers = [];
  final List<double> _coreHealth = [coreMaxHealth, coreMaxHealth];
  final List<double> _teamKills = [0, 0];
  final List<double> _teamGold = [500, 500];
  final List<double> _nextWave = List<double>.filled(6, waveIntervalSeconds);

  double _accumulator = 0;
  double _elapsed = 0;
  double _playerHealth = playerMaxHealthBase;
  double _playerMaxHealth = playerMaxHealthBase;
  double _playerRespawn = 0;
  double _playerAttackCooldown = 0;
  double _playerAttackPulseSeconds = 0;
  double _playerSkillCooldown = 0;
  double _playerShieldTime = 0;
  double _playerXp = 0;
  double _playerGold = 500;
  double _playerPower = 1;
  int _playerLevel = 1;
  int _nextMinionId = 0;
  MobaPoint _playerPosition = const MobaPoint(0, -63);
  MobaTeam? _winner;
  double _lastMoveX = 0;
  double _lastMoveZ = 1;
  bool _playerMoving = false;

  MobaMatchSnapshot get snapshot => _makeSnapshot();

  int get activeMinionCount => _minions.where((unit) => unit.alive).length;
  int get activeBotCount => _bots.where((bot) => bot.alive).length;
  int get totalTowerCount => _towers.length;
  double get elapsedSeconds => _elapsed;
  MobaTeam? get winner => _winner;

  MobaHeroId _heroForRole(int role) => switch (role) {
        0 => MobaHeroId.bastion,
        1 => MobaHeroId.kairo,
        2 => MobaHeroId.lyra,
        3 => MobaHeroId.lyra,
        _ => MobaHeroId.bastion,
      };

  void _reset() {
    _minions.clear();
    _bots.clear();
    _towers.clear();
    _elapsed = 0;
    _accumulator = 0;
    _playerHealth = playerMaxHealthBase;
    _playerMaxHealth = playerMaxHealthBase;
    _playerRespawn = 0;
    _playerAttackCooldown = 0;
    _playerAttackPulseSeconds = 0;
    _playerSkillCooldown = 0;
    _playerShieldTime = 0;
    _playerXp = 0;
    _playerGold = 500;
    _playerPower = 1;
    _playerLevel = 1;
    _nextMinionId = 0;
    _playerPosition = MobaPoint(
      _laneX(heroId.assignedLane, MobaTeam.blue.homeZ),
      MobaTeam.blue.homeZ,
    );
    _winner = null;
    _lastMoveX = 0;
    _lastMoveZ = 1;
    _playerMoving = false;
    _coreHealth
      ..[0] = coreMaxHealth
      ..[1] = coreMaxHealth;
    _teamKills
      ..[0] = 0
      ..[1] = 0;
    _teamGold
      ..[0] = 500
      ..[1] = 500;
    _nextWave.fillRange(0, _nextWave.length, waveIntervalSeconds);

    for (final team in MobaTeam.values) {
      for (final lane in MobaLane.values) {
        _spawnMinionWave(team, lane, group: 0);
        _nextWave[_waveIndex(team, lane)] = waveIntervalSeconds;
      }
    }

    const roleLanes = <MobaLane>[
      MobaLane.top,
      MobaLane.top,
      MobaLane.middle,
      MobaLane.bottom,
      MobaLane.bottom,
    ];
    final occupiedRole = switch (heroId) {
      MobaHeroId.bastion => 0,
      MobaHeroId.kairo => 2,
      MobaHeroId.lyra => 3,
    };

    var allyIndex = 0;
    for (var role = 0; role < roleLanes.length; role++) {
      if (role == occupiedRole) continue;
      final lane = roleLanes[role];
      _bots.add(
        _Bot(
          id: 'blue_bot_$role',
          team: MobaTeam.blue,
          lane: lane,
          role: role,
          heroId: _heroForRole(role),
          position: MobaPoint(_laneX(lane, -57), -57 + allyIndex * 1.2),
        ),
      );
      allyIndex++;
    }

    for (var role = 0; role < roleLanes.length; role++) {
      final lane = roleLanes[role];
      _bots.add(
        _Bot(
          id: 'red_bot_$role',
          team: MobaTeam.red,
          lane: lane,
          role: role,
          heroId: _heroForRole(role),
          position: MobaPoint(
            _laneX(lane, 57),
            57 - role * 1.2,
          ),
        ),
      );
    }

    for (final team in MobaTeam.values) {
      for (final lane in MobaLane.values) {
        for (var tier = 0; tier < 3; tier++) {
          _towers.add(
            _Tower(
              team: team,
              lane: lane,
              tier: tier,
              position: _towerPosition(team, lane, tier),
            ),
          );
        }
      }
    }
  }

  void step(
    double frameDelta, {
    double moveX = 0,
    double moveZ = 0,
    bool basicAttack = false,
    bool castSkill = false,
  }) {
    if (_winner != null || !frameDelta.isFinite || frameDelta <= 0) return;
    final safeDelta = frameDelta.clamp(0.0, 0.25).toDouble();
    _accumulator = math.min(_accumulator + safeDelta, _fixedStep * 8);
    final inputLength = math.sqrt(moveX * moveX + moveZ * moveZ);
    final normalizedX = inputLength > 1 ? moveX / inputLength : moveX;
    final normalizedZ = inputLength > 1 ? moveZ / inputLength : moveZ;

    var steps = 0;
    while (_accumulator + 1e-9 >= _fixedStep && steps < 8) {
      _tick(
        _fixedStep,
        moveX: normalizedX,
        moveZ: normalizedZ,
        basicAttack: basicAttack,
        castSkill: castSkill,
      );
      _accumulator -= _fixedStep;
      steps++;
      if (_winner != null) break;
    }
  }

  void _tick(
    double dt, {
    required double moveX,
    required double moveZ,
    required bool basicAttack,
    required bool castSkill,
  }) {
    _elapsed += dt;
    _playerAttackCooldown = math.max(0, _playerAttackCooldown - dt);
    _playerAttackPulseSeconds =
        math.max(0, _playerAttackPulseSeconds - dt);
    _playerSkillCooldown = math.max(0, _playerSkillCooldown - dt);
    _playerShieldTime = math.max(0, _playerShieldTime - dt);
    final wasRespawning = _playerRespawn > 0;
    _playerRespawn = math.max(0, _playerRespawn - dt);
    if (wasRespawning && _playerRespawn <= 0) {
      _playerHealth = _playerMaxHealth;
    }

    if (_playerRespawn <= 0) {
      _playerMoving = moveX.abs() >= 0.06 || moveZ.abs() >= 0.06;
      _movePlayer(moveX, moveZ, dt);
      if (basicAttack && _playerAttackCooldown <= 0) _playerAttack();
      if (castSkill && _playerSkillCooldown <= 0) _castHeroSkill();
    }

    _updateWaves(dt);
    _updateMinions(dt);
    _updateBots(dt);
    _updateTowers(dt);
    _checkWinner();
  }

  void _movePlayer(double x, double z, double dt) {
    if (x.abs() < 0.06 && z.abs() < 0.06) return;
    final length = math.sqrt(x * x + z * z);
    final nx = length > 1 ? x / length : x;
    final nz = length > 1 ? z / length : z;
    _lastMoveX = nx;
    _lastMoveZ = nz;
    _tryMovePlayer(nx * playerMoveSpeed * dt, nz * playerMoveSpeed * dt);
  }

  void _tryMovePlayer(double dx, double dz) {
    final nextX = _playerPosition.x + dx;
    final nextZ = _playerPosition.z + dz;
    if (ArenaWorldCatalog.isWalkable(nextX, nextZ)) {
      _playerPosition = MobaPoint(nextX, nextZ);
      return;
    }

    // Axis sliding prevents a diagonal input from sticking against a bank,
    // tree trunk or terrain boundary.
    if (ArenaWorldCatalog.isWalkable(nextX, _playerPosition.z)) {
      _playerPosition = MobaPoint(nextX, _playerPosition.z);
    }
    if (ArenaWorldCatalog.isWalkable(_playerPosition.x, nextZ)) {
      _playerPosition = MobaPoint(_playerPosition.x, nextZ);
    }
  }

  void _playerAttack() {
    // The action always has a visible response, even when no target is in range.
    // Damage remains server-independent and is applied only to valid nearby MOBA
    // targets; the renderer plays a short, unarmed character animation.
    _playerAttackPulseSeconds = 0.46;
    _playerAttackCooldown = heroId.basicAttackCooldown;

    final damage = heroId.basicDamage * _playerPower;
    final lane = _nearestLane(_playerPosition);
    final enemyBot = _nearestBot(
      _playerPosition,
      MobaTeam.red,
      maxRange: heroId.basicRange,
    );
    if (enemyBot != null) {
      _damageBot(enemyBot, MobaTeam.blue, damage);
      return;
    }

    final minion = _nearestMinion(
      _playerPosition,
      MobaTeam.red,
      lane,
      maxRange: heroId.basicRange,
    );
    if (minion != null) {
      _damageMinion(minion, MobaTeam.blue, damage);
      return;
    }

    final tower = _activeTower(MobaTeam.red, lane);
    if (tower != null &&
        _playerPosition.distanceTo(tower.position) <= heroId.basicRange &&
        _hasFriendlyMinionSupport(MobaTeam.blue, lane, tower.position, 7.2)) {
      _damageTower(tower, MobaTeam.blue, damage);
      return;
    }

    if (_laneOpen(MobaTeam.red, lane) &&
        _playerPosition.distanceTo(_corePosition(MobaTeam.red)) <= heroId.basicRange + 0.8) {
      _damageCore(MobaTeam.red, damage, lane);
    }
  }

  void _castHeroSkill() {
    switch (heroId) {
      case MobaHeroId.lyra:
        _playerHealth = math.min(_playerMaxHealth, _playerHealth + 76);
        for (final ally in _bots.where(
          (bot) => bot.team == MobaTeam.blue && bot.alive &&
              bot.position.distanceTo(_playerPosition) <= 5,
        )) {
          ally.health = math.min(_Bot.maxHealth, ally.health + 58);
        }
      case MobaHeroId.bastion:
        _playerShieldTime = 2.8;
        final target = _nearestBot(
          _playerPosition,
          MobaTeam.red,
          maxRange: 3.4,
        );
        if (target != null) _damageBot(target, MobaTeam.blue, 68);
      case MobaHeroId.kairo:
        final length = math.sqrt(_lastMoveX * _lastMoveX + _lastMoveZ * _lastMoveZ);
        final dx = length > 0 ? _lastMoveX / length : 0;
        final dz = length > 0 ? _lastMoveZ / length : 1;
        _tryMovePlayer(dx * 5, dz * 5);
        final target = _nearestBot(
          _playerPosition,
          MobaTeam.red,
          maxRange: 3.0,
        );
        if (target != null) _damageBot(target, MobaTeam.blue, 72);
    }
    _playerSkillCooldown = 9.0;
  }

  void _updateWaves(double dt) {
    for (final team in MobaTeam.values) {
      for (final lane in MobaLane.values) {
        final index = _waveIndex(team, lane);
        _nextWave[index] -= dt;
        if (_nextWave[index] > 0) continue;
        final activeForLane = _minions.where(
          (unit) => unit.alive && unit.team == team && unit.lane == lane,
        ).length;
        if (activeForLane <= 4 && _minions.length < maxMinions) {
          _spawnMinionWave(team, lane, group: (_elapsed / waveIntervalSeconds).floor());
          _nextWave[index] = waveIntervalSeconds;
        } else {
          _nextWave[index] = 4;
        }
      }
    }
  }

  void _spawnMinionWave(
    MobaTeam team,
    MobaLane lane, {
    required int group,
    double stagger = 0,
  }) {
    // Recycle defeated slots. The match keeps a fixed live-entity budget,
    // rather than exhausting the first 48 object instances over time.
    _minions.removeWhere((unit) => !unit.alive);
    if (_minions.length + 4 > maxMinions) return;
    final z = team.homeZ + team.forward * (group.isEven ? 4.0 : 5.3);
    for (var slot = 0; slot < 4; slot++) {
      if (_minions.length >= maxMinions) break;
      final ranged = slot == 3;
      _minions.add(
        _Minion(
          id: _nextMinionId++,
          team: team,
          lane: lane,
          ranged: ranged,
          position: MobaPoint(
            _laneX(lane, z) + (slot - 1.5) * 0.52,
            z - team.forward * stagger,
          ),
        ),
      );
    }
  }

  void _updateMinions(double dt) {
    for (final minion in _minions.where((unit) => unit.alive)) {
      minion.attackCooldown = math.max(0, minion.attackCooldown - dt);
      if (minion.spawnDelay > 0) {
        minion.spawnDelay = math.max(0, minion.spawnDelay - dt);
        continue;
      }

      final enemy = _nearestMinion(
        minion.position,
        minion.team.enemy,
        minion.lane,
        maxRange: minion.ranged ? 6.2 : 4.2,
      );
      if (enemy != null) {
        final distance = minion.position.distanceTo(enemy.position);
        final attackRange = minion.ranged ? 4.8 : 1.75;
        if (distance > attackRange) {
          _moveMinion(minion, enemy.position, minion.ranged ? 2.3 : 2.55, dt);
        } else if (minion.attackCooldown <= 0) {
          _damageMinion(enemy, minion.team, minion.ranged ? 14 : 25);
          minion.attackCooldown = minion.ranged ? 1.05 : 0.88;
        }
        continue;
      }

      final enemyBot = _nearestBot(
        minion.position,
        minion.team.enemy,
        maxRange: 3.8,
        lane: minion.lane,
      );
      if (enemyBot != null) {
        final distance = minion.position.distanceTo(enemyBot.position);
        if (distance > 2.0) {
          _moveMinion(minion, enemyBot.position, 2.35, dt);
        } else if (minion.attackCooldown <= 0) {
          _damageBot(enemyBot, minion.team, minion.ranged ? 8 : 14);
          minion.attackCooldown = 1.0;
        }
        continue;
      }

      if (minion.team == MobaTeam.red &&
          _playerRespawn <= 0 &&
          minion.position.distanceTo(_playerPosition) <= 3.8) {
        final distance = minion.position.distanceTo(_playerPosition);
        if (distance > 1.9) {
          _moveMinion(minion, _playerPosition, 2.35, dt);
        } else if (minion.attackCooldown <= 0) {
          _damagePlayer(minion.ranged ? 7 : 10);
          minion.attackCooldown = 1.0;
        }
        continue;
      }

      final defendingTeam = minion.team.enemy;
      final tower = _activeTower(defendingTeam, minion.lane);
      if (tower != null) {
        if (minion.position.distanceTo(tower.position) > 2.65) {
          _moveMinion(minion, tower.position, minion.ranged ? 2.25 : 2.5, dt);
        } else if (minion.attackCooldown <= 0) {
          _damageTower(tower, minion.team, minion.ranged ? 34 : 42);
          minion.attackCooldown = 1.12;
        }
      } else if (_laneOpen(defendingTeam, minion.lane)) {
        final core = _corePosition(defendingTeam);
        if (minion.position.distanceTo(core) > 3.5) {
          _moveMinion(minion, core, 2.4, dt);
        } else if (minion.attackCooldown <= 0) {
          _damageCore(defendingTeam, 26, minion.lane);
          minion.attackCooldown = 1.0;
        }
      }
    }
  }

  void _moveMinion(_Minion unit, MobaPoint target, double speed, double dt) {
    final next = unit.position.moveToward(target, speed * dt);
    unit.position = MobaPoint(_laneX(unit.lane, next.z), next.z);
  }

  void _updateBots(double dt) {
    for (final bot in _bots) {
      if (bot.respawnSeconds > 0) {
        bot.respawnSeconds = math.max(0, bot.respawnSeconds - dt);
        if (bot.respawnSeconds <= 0) {
          bot.health = _Bot.maxHealth;
          bot.position = MobaPoint(
            _laneX(bot.lane, bot.team.homeZ - bot.team.forward * 2),
            bot.team.homeZ - bot.team.forward * 2,
          );
        }
        continue;
      }

      bot.attackCooldown = math.max(0, bot.attackCooldown - dt);
      final enemyHero = _nearestBot(
        bot.position,
        bot.team.enemy,
        maxRange: 5.8,
        lane: bot.lane,
      );
      final playerDistance = bot.team == MobaTeam.red && _playerRespawn <= 0
          ? bot.position.distanceTo(_playerPosition)
          : double.infinity;
      final botDistance = enemyHero == null
          ? double.infinity
          : bot.position.distanceTo(enemyHero.position);
      if (playerDistance <= 5.8 && playerDistance < botDistance) {
        if (playerDistance > 2.25) {
          bot.position = bot.position.moveToward(_playerPosition, 3.15 * dt);
        } else if (bot.attackCooldown <= 0) {
          _damagePlayer(10);
          bot.attackCooldown = 1.05;
        }
        continue;
      }
      if (enemyHero != null) {
        final distance = bot.position.distanceTo(enemyHero.position);
        if (distance > 2.25) {
          bot.position = bot.position.moveToward(enemyHero.position, 3.15 * dt);
        } else if (bot.attackCooldown <= 0) {
          _damageBot(enemyHero, bot.team, 15);
          bot.attackCooldown = 1.0;
        }
        continue;
      }

      final enemyMinion = _nearestMinion(
        bot.position,
        bot.team.enemy,
        bot.lane,
        maxRange: 4.8,
      );
      if (enemyMinion != null) {
        final distance = bot.position.distanceTo(enemyMinion.position);
        if (distance > 2.2) {
          bot.position = bot.position.moveToward(enemyMinion.position, 3.15 * dt);
        } else if (bot.attackCooldown <= 0) {
          _damageMinion(enemyMinion, bot.team, 22);
          bot.attackCooldown = 0.94;
        }
        continue;
      }

      final front = _friendlyFront(bot.team, bot.lane);
      final targetZ = front == null
          ? bot.team.homeZ + bot.team.forward * 4
          : front.position.z + bot.team.forward * 2;
      final tower = _activeTower(bot.team.enemy, bot.lane);
      final goal = tower?.position ??
          (_laneOpen(bot.team.enemy, bot.lane)
              ? _corePosition(bot.team.enemy)
              : MobaPoint(_laneX(bot.lane, targetZ), targetZ));
      bot.position = bot.position.moveToward(goal, 2.9 * dt);

      if (tower != null &&
          bot.position.distanceTo(tower.position) <= 4.4 &&
          _hasFriendlyMinionSupport(bot.team, bot.lane, tower.position, 7.2) &&
          bot.attackCooldown <= 0) {
        _damageTower(tower, bot.team, 24);
        bot.attackCooldown = 1.15;
      } else if (tower == null &&
          _laneOpen(bot.team.enemy, bot.lane) &&
          bot.position.distanceTo(_corePosition(bot.team.enemy)) <= 4 &&
          bot.attackCooldown <= 0) {
        _damageCore(bot.team.enemy, 22, bot.lane);
        bot.attackCooldown = 1.2;
      }
    }
  }

  void _updateTowers(double dt) {
    for (final tower in _towers.where((item) => item.alive)) {
      if (_activeTower(tower.team, tower.lane) != tower) continue;
      tower.attackCooldown = math.max(0, tower.attackCooldown - dt);
      if (tower.attackCooldown > 0) continue;

      final enemyMinion = _nearestMinion(
        tower.position,
        tower.team.enemy,
        tower.lane,
        maxRange: 7.8,
      );
      if (enemyMinion != null) {
        _damageMinion(enemyMinion, tower.team, 24);
        tower.attackCooldown = 0.92;
        continue;
      }

      final enemyBot = _nearestBot(
        tower.position,
        tower.team.enemy,
        maxRange: 7.8,
        lane: tower.lane,
      );
      if (enemyBot != null) {
        _damageBot(enemyBot, tower.team, 16);
        tower.attackCooldown = 1.0;
        continue;
      }
      if (tower.team == MobaTeam.red &&
          _playerRespawn <= 0 &&
          _playerPosition.distanceTo(tower.position) <= 7.8) {
        _damagePlayer(12);
        tower.attackCooldown = 1.0;
      }
    }
  }

  _Minion? _nearestMinion(
    MobaPoint position,
    MobaTeam team,
    MobaLane lane, {
    required double maxRange,
  }) {
    _Minion? target;
    var nearest = maxRange;
    for (final unit in _minions) {
      if (!unit.alive || unit.team != team || unit.lane != lane) continue;
      final distance = position.distanceTo(unit.position);
      if (distance < nearest) {
        nearest = distance;
        target = unit;
      }
    }
    return target;
  }

  _Bot? _nearestBot(
    MobaPoint position,
    MobaTeam team, {
    required double maxRange,
    MobaLane? lane,
  }) {
    _Bot? target;
    var nearest = maxRange;
    for (final bot in _bots) {
      if (!bot.alive || bot.team != team || (lane != null && bot.lane != lane)) {
        continue;
      }
      final distance = position.distanceTo(bot.position);
      if (distance < nearest) {
        nearest = distance;
        target = bot;
      }
    }
    return target;
  }

  _Minion? _friendlyFront(MobaTeam team, MobaLane lane) {
    _Minion? front;
    for (final minion in _minions) {
      if (!minion.alive || minion.team != team || minion.lane != lane) continue;
      if (front == null ||
          (team == MobaTeam.blue
              ? minion.position.z > front.position.z
              : minion.position.z < front.position.z)) {
        front = minion;
      }
    }
    return front;
  }

  _Tower? _activeTower(MobaTeam team, MobaLane lane) {
    _Tower? target;
    for (final tower in _towers) {
      if (!tower.alive || tower.team != team || tower.lane != lane) continue;
      if (target == null || tower.tier < target.tier) target = tower;
    }
    return target;
  }

  bool _laneOpen(MobaTeam defendingTeam, MobaLane lane) =>
      _towers.where((tower) => tower.team == defendingTeam && tower.lane == lane)
          .every((tower) => !tower.alive);

  bool canDamageCore(MobaTeam defendingTeam) =>
      MobaLane.values.any((lane) => _laneOpen(defendingTeam, lane));

  bool _hasFriendlyMinionSupport(
    MobaTeam team,
    MobaLane lane,
    MobaPoint position,
    double range,
  ) =>
      _minions.any(
        (unit) =>
            unit.alive &&
            unit.team == team &&
            unit.lane == lane &&
            unit.position.distanceTo(position) <= range,
      );

  void _damageMinion(_Minion target, MobaTeam source, double damage) {
    if (!target.alive) return;
    target.health = math.max(0, target.health - damage);
    if (!target.alive) {
      _awardGold(source, target.ranged ? 58 : 42);
      _awardXp(source, target.ranged ? 34 : 26);
    }
  }

  void _damageBot(_Bot target, MobaTeam source, double damage) {
    if (!target.alive) return;
    target.health = math.max(0, target.health - damage);
    if (target.health <= 0) {
      target.respawnSeconds = 6;
      _teamKills[source.index]++;
      _awardGold(source, 170);
      _awardXp(source, 115);
    }
  }

  void _damageTower(_Tower tower, MobaTeam source, double damage) {
    if (!tower.alive) return;
    tower.health = math.max(0, tower.health - damage);
    if (!tower.alive) {
      _awardGold(source, 250);
      _awardXp(source, 120);
    }
  }

  void _damageCore(MobaTeam defendingTeam, double damage, MobaLane lane) {
    if (!_laneOpen(defendingTeam, lane)) return;
    _coreHealth[defendingTeam.index] =
        math.max(0, _coreHealth[defendingTeam.index] - damage);
  }

  void _awardGold(MobaTeam team, double amount) {
    _teamGold[team.index] += amount;
    if (team == MobaTeam.blue) _playerGold += amount;
  }

  void _awardXp(MobaTeam team, double amount) {
    if (team != MobaTeam.blue || _playerLevel >= maxHeroLevel) return;
    _playerXp += amount;
    while (_playerLevel < maxHeroLevel) {
      final threshold = _xpThreshold(_playerLevel);
      if (_playerXp < threshold) break;
      _playerXp -= threshold;
      _playerLevel++;
      _playerMaxHealth += 14;
      _playerHealth = math.min(_playerMaxHealth, _playerHealth + 14);
      _playerPower += 0.035;
    }
  }

  double _xpThreshold(int level) => 220 + (level - 1) * 85.0;

  void _damagePlayer(double damage) {
    final mitigation = _playerShieldTime > 0 ? 0.58 : 1.0;
    _playerHealth = math.max(0, _playerHealth - damage * mitigation);
    if (_playerHealth <= 0) {
      _playerHealth = 0;
      _playerRespawn = 5;
      _playerPosition = MobaPoint(
        _laneX(heroId.assignedLane, MobaTeam.blue.homeZ),
        MobaTeam.blue.homeZ,
      );
    }
  }

  void _checkWinner() {
    if (_coreHealth[MobaTeam.red.index] <= 0) {
      _winner = MobaTeam.blue;
    } else if (_coreHealth[MobaTeam.blue.index] <= 0) {
      _winner = MobaTeam.red;
    }
  }

  int _waveIndex(MobaTeam team, MobaLane lane) =>
      team.index * MobaLane.values.length + lane.index;

  double _laneX(MobaLane lane, double z) {
    final base = switch (lane) {
      MobaLane.top => -36.0,
      MobaLane.middle => 0.0,
      MobaLane.bottom => 36.0,
    };
    return base + math.sin(z * 0.025) * 0.5;
  }

  MobaLane _nearestLane(MobaPoint point) {
    MobaLane best = MobaLane.middle;
    var bestDistance = double.infinity;
    for (final lane in MobaLane.values) {
      final distance = (point.x - _laneX(lane, point.z)).abs();
      if (distance < bestDistance) {
        bestDistance = distance;
        best = lane;
      }
    }
    return best;
  }

  MobaPoint _towerPosition(MobaTeam team, MobaLane lane, int tier) {
    final z = team == MobaTeam.blue ? -20.0 - tier * 16.0 : 20.0 + tier * 16.0;
    return MobaPoint(_laneX(lane, z), z);
  }

  MobaPoint _corePosition(MobaTeam team) =>
      MobaPoint(0, team == MobaTeam.blue ? -66.0 : 66.0);

  MobaMatchSnapshot _makeSnapshot() {
    final minions = _minions
        .where((unit) => unit.alive)
        .map(
          (unit) => MobaMinionSnapshot(
            id: unit.id,
            team: unit.team,
            lane: unit.lane,
            ranged: unit.ranged,
            position: unit.position,
            health: unit.health,
            maxHealth: unit.maxHealth,
          ),
        )
        .toList(growable: false);
    final bots = _bots
        .map(
          (bot) => MobaBotSnapshot(
            id: bot.id,
            team: bot.team,
            lane: bot.lane,
            heroId: bot.heroId,
            position: bot.position,
            health: bot.health,
            maxHealth: _Bot.maxHealth,
            respawnSeconds: bot.respawnSeconds,
          ),
        )
        .toList(growable: false);
    final towers = _towers
        .map(
          (tower) => MobaTowerSnapshot(
            team: tower.team,
            lane: tower.lane,
            tier: tower.tier,
            position: tower.position,
            health: tower.health,
            maxHealth: _Tower.maxHealth,
          ),
        )
        .toList(growable: false);

    final currentThreshold = _xpThreshold(_playerLevel);
    return MobaMatchSnapshot(
      elapsedSeconds: _elapsed,
      heroId: heroId,
      playerPosition: _playerPosition,
      playerHealth: _playerHealth,
      playerMaxHealth: _playerMaxHealth,
      playerLevel: _playerLevel,
      playerXp: _playerXp,
      xpForNextLevel: currentThreshold,
      playerGold: _playerGold,
      playerSkillCooldown: _playerSkillCooldown,
      playerRespawnSeconds: _playerRespawn,
      playerMoving: _playerMoving,
      playerAttackSeconds: _playerAttackPulseSeconds,
      playerFacingX: _lastMoveX,
      playerFacingZ: _lastMoveZ,
      blueTeamKills: _teamKills[MobaTeam.blue.index].toInt(),
      redTeamKills: _teamKills[MobaTeam.red.index].toInt(),
      blueCoreHealth: _coreHealth[MobaTeam.blue.index],
      redCoreHealth: _coreHealth[MobaTeam.red.index],
      blueCoreMaxHealth: coreMaxHealth,
      redCoreMaxHealth: coreMaxHealth,
      blueTowersAlive: _towers
          .where((tower) => tower.team == MobaTeam.blue && tower.alive)
          .length,
      redTowersAlive: _towers
          .where((tower) => tower.team == MobaTeam.red && tower.alive)
          .length,
      blueMinions: minions.where((unit) => unit.team == MobaTeam.blue).length,
      redMinions: minions.where((unit) => unit.team == MobaTeam.red).length,
      bots: List.unmodifiable(bots),
      minions: List.unmodifiable(minions),
      towers: List.unmodifiable(towers),
      winner: _winner,
    );
  }
}
