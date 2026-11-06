import 'dart:math' as math;

import '../world/arena_world_catalog.dart';

enum MobaTeam { blue, red }

extension MobaTeamRules on MobaTeam {
  MobaTeam get enemy => this == MobaTeam.blue ? MobaTeam.red : MobaTeam.blue;
  double get forward => this == MobaTeam.blue ? 1.0 : -1.0;
  double get homeZ => this == MobaTeam.blue ? -60.0 : 60.0;
  int get index => this == MobaTeam.blue ? 0 : 1;
}

/// Deterministic capture meter for the central relay. Ownership is latched
/// until opposing progress drains the meter back to neutral.
class MobaObjectiveControl {
  double control = 0;
  MobaTeam? owner;
  bool contested = false;
  double bluePresence = 0;
  double redPresence = 0;

  void reset() {
    control = 0;
    owner = null;
    contested = false;
    bluePresence = 0;
    redPresence = 0;
  }

  /// Returns the newly captured team only when ownership changes.
  MobaTeam? update(double dt, {required double blue, required double red}) {
    bluePresence = blue;
    redPresence = red;
    contested = blue > 0 && red > 0;
    if (contested || dt <= 0) return null;

    final previousOwner = owner;
    if (blue > 0) {
      control = math.min(100, control + dt * 9.0 * blue);
    } else if (red > 0) {
      control = math.max(-100, control - dt * 9.0 * red);
    }

    if (owner == MobaTeam.blue && control <= 0) {
      owner = null;
    } else if (owner == MobaTeam.red && control >= 0) {
      owner = null;
    }

    if (owner == null) {
      if (control >= 100) {
        owner = MobaTeam.blue;
      } else if (control <= -100) {
        owner = MobaTeam.red;
      }
    }

    return owner != null && owner != previousOwner ? owner : null;
  }
}

enum MobaLane { top, middle, bottom }

enum MobaHeroId { lyra, bastion, kairo }

// Gameplay archetype and rendered appearance are kept independent.
enum MobaNpcVisualId { maleA, femaleA, maleB, femaleB, maleC, femaleC }

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
  const MobaPoint(this.x, this.z, {this.elevation = 0});

  final double x;
  final double z;

  /// Local height above the baked ground surface. Elevated routes use this
  /// value to keep units on separate floors from acquiring targets through decks.
  final double elevation;

  double distanceTo(MobaPoint other) {
    if ((elevation - other.elevation).abs() > 0.65) {
      return double.infinity;
    }
    return math.sqrt(math.pow(x - other.x, 2) + math.pow(z - other.z, 2));
  }

  MobaPoint moveToward(MobaPoint target, double distance) {
    final dx = target.x - x;
    final dz = target.z - z;
    final length = math.sqrt(dx * dx + dz * dz);
    if (length <= distance || length < 0.0001) return target;
    final t = distance / length;
    return MobaPoint(
      x + dx * t,
      z + dz * t,
      elevation: elevation,
    );
  }
}

class MobaMinionSnapshot {
  const MobaMinionSnapshot({
    required this.id,
    required this.team,
    required this.lane,
    required this.ranged,
    required this.visualId,
    required this.position,
    required this.facingX,
    required this.facingZ,
    required this.moving,
    required this.health,
    required this.maxHealth,
    required this.attackSeconds,
  });

  final int id;
  final MobaTeam team;
  final MobaLane lane;
  final bool ranged;
  final MobaNpcVisualId visualId;
  final MobaPoint position;
  final double facingX;
  final double facingZ;
  final bool moving;
  final double health;
  final double maxHealth;
  final double attackSeconds;
}

class MobaBotSnapshot {
  const MobaBotSnapshot({
    required this.id,
    required this.team,
    required this.lane,
    required this.heroId,
    required this.visualId,
    required this.position,
    required this.facingX,
    required this.facingZ,
    required this.moving,
    required this.health,
    required this.maxHealth,
    required this.respawnSeconds,
    required this.attackSeconds,
  });

  final String id;
  final MobaTeam team;
  final MobaLane lane;
  final MobaHeroId heroId;
  final MobaNpcVisualId visualId;
  final MobaPoint position;
  final double facingX;
  final double facingZ;
  final bool moving;
  final double health;
  final double maxHealth;
  final double respawnSeconds;
  final double attackSeconds;
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

class MobaCoverSnapshot {
  const MobaCoverSnapshot({
    required this.id,
    required this.variant,
    required this.position,
    required this.health,
    required this.maxHealth,
  });

  final String id;
  final String variant;
  final MobaPoint position;
  final double health;
  final double maxHealth;

  bool get isDestroyed => health <= 0;
}

class MobaTargetSnapshot {
  const MobaTargetSnapshot({
    required this.id,
    required this.kind,
    required this.label,
    required this.team,
    required this.position,
    required this.health,
    required this.maxHealth,
  });

  final String id;
  final String kind;
  final String label;
  final MobaTeam team;
  final MobaPoint position;
  final double health;
  final double maxHealth;
}

class MobaDistrictSnapshot {
  const MobaDistrictSnapshot({
    required this.id, required this.name, required this.position,
    required this.control, required this.owner, required this.contested,
  });
  final String id;
  final String name;
  final MobaPoint position;
  final double control;
  final MobaTeam? owner;
  final bool contested;
}

class MobaObjectiveSnapshot {
  const MobaObjectiveSnapshot({
    required this.control,
    required this.owner,
    required this.contested,
    required this.bluePresence,
    required this.redPresence,
  });

  /// Signed capture progress: -100 is red, +100 is blue.
  final double control;
  final MobaTeam? owner;
  final bool contested;
  final double bluePresence;
  final double redPresence;
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
    required this.playerSpawnShieldSeconds,
    required this.playerMoving,
    required this.playerAttackSeconds,
    required this.playerHitConfirmSeconds,
    required this.playerSkillPulseSeconds,
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
    required this.covers,
    required this.districts,
    required this.centralObjective,
    required this.selectedTarget,
    required this.teamPingTarget,
    required this.teamPingSeconds,
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
  final double playerSpawnShieldSeconds;
  final bool playerMoving;
  final double playerAttackSeconds;
  final double playerHitConfirmSeconds;
  final double playerSkillPulseSeconds;
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
  final List<MobaCoverSnapshot> covers;
  final List<MobaDistrictSnapshot> districts;
  final MobaObjectiveSnapshot centralObjective;
  final MobaTargetSnapshot? selectedTarget;
  final MobaPoint? teamPingTarget;
  final double teamPingSeconds;
  final MobaTeam? winner;

  bool get isFinished => winner != null;
}

class _Minion {
  _Minion({
    required this.id,
    required this.team,
    required this.lane,
    required this.ranged,
    required this.visualId,
    required this.position,
  })  : maxHealth = ranged ? 92.0 : 145.0,
        health = ranged ? 92.0 : 145.0,
        facingZ = team.forward;

  final int id;
  final MobaTeam team;
  final MobaLane lane;
  final bool ranged;
  final MobaNpcVisualId visualId;
  final double maxHealth;
  MobaPoint position;
  double facingX = 0;
  double facingZ;
  bool moving = false;
  double health;
  double attackCooldown = 0.25;
  double attackSeconds = 0;
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
    required this.visualId,
    required this.position,
  }) : facingZ = team.forward;

  final String id;
  final MobaTeam team;
  final MobaLane lane;
  final int role;
  final MobaHeroId heroId;
  final MobaNpcVisualId visualId;
  MobaPoint position;
  double facingX = 0;
  double facingZ;
  bool moving = false;
  double health = 420.0;
  double attackCooldown = 0.4;
  double attackSeconds = 0;
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

class _Cover {
  _Cover({
    required this.id,
    required this.variant,
    required this.position,
  });

  final String id;
  final String variant;
  final MobaPoint position;
  double health = 180.0;

  static const double maxHealth = 180.0;
  bool get alive => health > 0;
}

class _DistrictControlPoint {
  _DistrictControlPoint({required this.id, required this.name, required this.position});
  final String id;
  final String name;
  final MobaPoint position;
  final MobaObjectiveControl control = MobaObjectiveControl();
}

class MobaMatchSimulation {
  MobaMatchSimulation({
    required this.heroId,
    double fixedStep = 1 / 30,
    MobaPoint? spawnPosition,
  })  : _fixedStep = fixedStep,
        _spawnPosition = spawnPosition {
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
  final MobaPoint? _spawnPosition;
  final List<_Minion> _minions = [];
  final List<_Bot> _bots = [];
  final List<_Tower> _towers = [];
  final List<_Cover> _covers = [];
  String? _selectedTargetKey;
  static const double _targetCycleRange = 24.0;
  static const MobaPoint _objectivePosition = MobaPoint(0, 0);
  static const double objectiveRadius = 8.0;
  static const double districtRadius = 7.5;
  final MobaObjectiveControl _objective = MobaObjectiveControl();
  final List<_DistrictControlPoint> _districts = [
    for (final site in ArenaWorldCatalog.districtSites)
      _DistrictControlPoint(id: site.$1, name: site.$2,
        position: MobaPoint(site.$3, site.$4)),
  ];

  MobaTeam? get _objectiveOwner => _objective.owner;

  double _districtDamageMultiplier(MobaTeam team) =>
      1.0 + 0.035 * _districts
          .where((district) => district.control.owner == team).length;

  double _objectiveDamageMultiplier(MobaTeam attackingTeam) =>
      (_objectiveOwner == attackingTeam ? 1.12 : 1.0) *
      _districtDamageMultiplier(attackingTeam);
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
  double _playerHitConfirmSeconds = 0;
  double _playerSkillPulseSeconds = 0;
  double _playerSkillCooldown = 0;
  MobaPoint? _pendingPhysicsDash;
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
  MobaPoint? _teamPingTarget;
  double _teamPingSeconds = 0;
  String? _teamPingBotId;

  MobaMatchSnapshot get snapshot => _makeSnapshot();

  /// Transfers a requested dash to the authoritative Rapier body exactly once.
  MobaPoint? consumePhysicsDashRequest() {
    final request = _pendingPhysicsDash;
    _pendingPhysicsDash = null;
    return request;
  }

  /// Applies Kairo's dash contact only at the final Rapier-resolved position.
  void resolvePhysicsDashAt(MobaPoint resolvedPosition) {
    if (heroId != MobaHeroId.kairo ||
        !resolvedPosition.x.isFinite ||
        !resolvedPosition.z.isFinite ||
        !resolvedPosition.elevation.isFinite ||
        _winner != null ||
        _playerHealth <= 0 ||
        _playerRespawn > 0) {
      return;
    }
    _playerPosition = resolvedPosition;
    final target = _nearestBot(
      resolvedPosition,
      MobaTeam.red,
      maxRange: 3.0,
    );
    if (target != null) _damageBot(target, MobaTeam.blue, 72);
  }

  int get activeMinionCount => _minions.where((unit) => unit.alive).length;
  int get activeBotCount => _bots.where((bot) => bot.alive).length;
  int get totalTowerCount => _towers.length;
  double get elapsedSeconds => _elapsed;
  MobaTeam? get winner => _winner;

  /// Orders the nearest active blue-side roamer to investigate a world point.
  /// Invalid terrain, water, walls and blocked interiors are rejected so the
  /// ping never sends a bot toward an unreachable position.
  bool issueTeamPing(MobaPoint point) {
    if (_winner != null ||
        !point.x.isFinite ||
        !point.z.isFinite ||
        !point.elevation.isFinite ||
        point.elevation.abs() > 0.22 ||
        !ArenaWorldCatalog.isWalkable(
          point.x,
          point.z,
          elevation: point.elevation,
        ) ||
        _isBlockedByCover(point.x, point.z, point.elevation)) {
      return false;
    }

    final roamers = _bots
        .where((bot) =>
            bot.team == MobaTeam.blue &&
            (bot.role == 3 || bot.role == 4) &&
            bot.alive)
        .toList(growable: false);
    if (roamers.isEmpty) return false;

    _Bot? selected;
    var nearest = double.infinity;
    for (final bot in roamers) {
      final distance = bot.position.distanceTo(point);
      if (distance < nearest) {
        nearest = distance;
        selected = bot;
      }
    }
    if (selected == null) return false;

    _teamPingTarget = point;
    _teamPingBotId = selected.id;
    _teamPingSeconds = 8.0;
    return true;
  }

  MobaHeroId _heroForRole(int role) => switch (role) {
        0 => MobaHeroId.bastion,
        1 => MobaHeroId.kairo,
        2 => MobaHeroId.lyra,
        3 => MobaHeroId.kairo,
        _ => MobaHeroId.bastion,
      };

  MobaNpcVisualId _visualForBot(MobaTeam team, int role) =>
      MobaNpcVisualId.values[
        (role + team.index * 3) % MobaNpcVisualId.values.length
      ];

  /// Place bots in the staging area behind their own first tower.
  /// Two heroes sharing a lane receive mirrored lateral slots rather than
  /// spawning inside the tower collision footprint or on top of each other.
  MobaPoint _botSpawnPosition(MobaTeam team, MobaLane lane, int role) {
    final z = team.homeZ - team.forward * 5.0;
    final lateralOffset = (role == 0 || role == 3)
        ? -1.6
        : (role == 1 || role == 4)
            ? 1.6
            : 0.0;
    return MobaPoint(_laneX(lane, z) + lateralOffset, z);
  }

  void _reset() {
    _minions.clear();
    _bots.clear();
    _towers.clear();
    _objective.reset();
    for (final district in _districts) {
      district.control.reset();
    }
    _selectedTargetKey = null;
    _covers
      ..clear()
      ..addAll([
        _Cover(
          id: 'west_south_door_barrier',
          variant: 'barrier',
          position: const MobaPoint(-70.5, -42.1),
        ),
        _Cover(
          id: 'east_north_door_fence',
          variant: 'fence',
          position: const MobaPoint(70.5, 33.9),
        ),
      ]);
    _elapsed = 0;
    _accumulator = 0;
    _playerHealth = playerMaxHealthBase;
    _playerMaxHealth = playerMaxHealthBase;
    _playerRespawn = 0;
    _playerAttackCooldown = 0;
    _playerAttackPulseSeconds = 0;
    _playerHitConfirmSeconds = 0;
    _playerSkillCooldown = 0;
    _playerShieldTime = 0;
    _playerXp = 0;
    _playerGold = 500;
    _playerPower = 1;
    _playerLevel = 1;
    _nextMinionId = 0;
    _playerPosition = _spawnPosition ??
        MobaPoint(
          _laneX(heroId.assignedLane, MobaTeam.blue.homeZ),
          MobaTeam.blue.homeZ,
        );
    _winner = null;
    _lastMoveX = 0;
    _lastMoveZ = 1;
    _playerMoving = false;
    _teamPingTarget = null;
    _teamPingSeconds = 0;
    _teamPingBotId = null;
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
          visualId: _visualForBot(MobaTeam.blue, role),
          position: _botSpawnPosition(MobaTeam.blue, lane, role),
        ),
      );
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
          visualId: _visualForBot(MobaTeam.red, role),
          position: _botSpawnPosition(MobaTeam.red, lane, role),
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

  /// Cycles the nearest valid enemy hero/minion. This is a discrete
  /// touch input and does not advance the fixed simulation clock.
  void cyclePlayerTarget() {
    _cyclePlayerTarget();
  }

  void _cyclePlayerTarget() {
    final candidates = <(String, double)>[];
    for (final bot in _bots) {
      if (!bot.alive || bot.team != MobaTeam.red) continue;
      final distance = _playerPosition.distanceTo(bot.position);
      if (distance <= _targetCycleRange) {
        candidates.add(('bot:${bot.id}', distance));
      }
    }
    for (final minion in _minions) {
      if (!minion.alive || minion.team != MobaTeam.red) continue;
      final distance = _playerPosition.distanceTo(minion.position);
      if (distance <= _targetCycleRange) {
        candidates.add(('minion:${minion.id}', distance));
      }
    }

    candidates.sort((a, b) {
      final distanceOrder = a.$2.compareTo(b.$2);
      return distanceOrder != 0 ? distanceOrder : a.$1.compareTo(b.$1);
    });
    if (candidates.isEmpty) {
      _selectedTargetKey = null;
      return;
    }

    final current = candidates.indexWhere(
      (candidate) => candidate.$1 == _selectedTargetKey,
    );
    _selectedTargetKey = candidates[(current + 1) % candidates.length].$1;
  }

  MobaTargetSnapshot? _selectedTargetSnapshot() {
    final key = _selectedTargetKey;
    if (key == null) return null;

    if (key.startsWith('bot:')) {
      final id = key.substring(4);
      for (final bot in _bots) {
        if (bot.id != id) continue;
        if (!bot.alive ||
            bot.team != MobaTeam.red ||
            _playerPosition.distanceTo(bot.position) > _targetCycleRange) {
          _selectedTargetKey = null;
          return null;
        }
        return MobaTargetSnapshot(
          id: key,
          kind: 'HERO',
          label: bot.heroId.name.toUpperCase(),
          team: bot.team,
          position: bot.position,
          health: bot.health,
          maxHealth: _Bot.maxHealth,
        );
      }
    } else if (key.startsWith('minion:')) {
      final id = int.tryParse(key.substring(7));
      for (final minion in _minions) {
        if (minion.id != id) continue;
        if (!minion.alive ||
            minion.team != MobaTeam.red ||
            _playerPosition.distanceTo(minion.position) > _targetCycleRange) {
          _selectedTargetKey = null;
          return null;
        }
        return MobaTargetSnapshot(
          id: key,
          kind: minion.ranged ? 'RANGED MINION' : 'MINION',
          label: 'MINION #${minion.id}',
          team: minion.team,
          position: minion.position,
          health: minion.health,
          maxHealth: minion.maxHealth,
        );
      }
    }

    _selectedTargetKey = null;
    return null;
  }

  /// Advances gameplay systems. Set [externalPlayerMovement] when a physics
  /// runtime owns the hero transform; the simulation then consumes that
  /// position but never applies a second movement model.
  void step(
    double frameDelta, {
    double moveX = 0,
    double moveZ = 0,
    bool basicAttack = false,
    bool castSkill = false,
    bool externalPlayerMovement = false,
  }) {
    if (_winner != null || !frameDelta.isFinite || frameDelta <= 0) return;
    final safeDelta = frameDelta.clamp(0.0, 0.25).toDouble();
    _accumulator = math.min(_accumulator + safeDelta, _fixedStep * 8);
    final safeMoveX = moveX.isFinite
        ? moveX.clamp(-1.0, 1.0).toDouble()
        : 0.0;
    final safeMoveZ = moveZ.isFinite
        ? moveZ.clamp(-1.0, 1.0).toDouble()
        : 0.0;
    final inputLength = math.sqrt(
      safeMoveX * safeMoveX + safeMoveZ * safeMoveZ,
    );
    final normalizedX =
        inputLength > 1 ? safeMoveX / inputLength : safeMoveX;
    final normalizedZ =
        inputLength > 1 ? safeMoveZ / inputLength : safeMoveZ;

    var steps = 0;
    while (_accumulator + 1e-9 >= _fixedStep && steps < 8) {
      _tick(
        _fixedStep,
        moveX: normalizedX,
        moveZ: normalizedZ,
        basicAttack: basicAttack,
        castSkill: castSkill,
        externalPlayerMovement: externalPlayerMovement,
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
    required bool externalPlayerMovement,
  }) {
    if (_teamPingSeconds > 0) {
      _teamPingSeconds = math.max(0, _teamPingSeconds - dt);
      if (_teamPingSeconds <= 0) {
        _teamPingTarget = null;
        _teamPingBotId = null;
      }
    }
    _elapsed += dt;
    _playerAttackCooldown = math.max(0, _playerAttackCooldown - dt);
    _playerAttackPulseSeconds =
        math.max(0, _playerAttackPulseSeconds - dt);
    _playerHitConfirmSeconds =
        math.max(0, _playerHitConfirmSeconds - dt);
    _playerSkillPulseSeconds =
        math.max(0, _playerSkillPulseSeconds - dt);
    _playerSkillCooldown = math.max(0, _playerSkillCooldown - dt);
    _playerShieldTime = math.max(0, _playerShieldTime - dt);
    final wasRespawning = _playerRespawn > 0;
    _playerRespawn = math.max(0, _playerRespawn - dt);
    if (wasRespawning && _playerRespawn <= 0) {
      // Respawn is a real state transition: the hero remains at the death
      // location while the timer runs, then returns to the allied spawn.
      _playerPosition = _spawnPosition ??
          MobaPoint(
            _laneX(heroId.assignedLane, MobaTeam.blue.homeZ),
            MobaTeam.blue.homeZ,
          );
      _playerHealth = _playerMaxHealth;
      _playerMoving = false;
      _lastMoveX = 0;
      _lastMoveZ = 1;
      _playerShieldTime = 1.4;
    }

    if (_playerRespawn <= 0) {
      _playerMoving = moveX.abs() >= 0.06 || moveZ.abs() >= 0.06;
      if (externalPlayerMovement) {
        if (_playerMoving) {
          final length = math.sqrt(moveX * moveX + moveZ * moveZ);
          if (length > 1e-6) {
            _lastMoveX = moveX / length;
            _lastMoveZ = moveZ / length;
          }
        }
      } else {
        _movePlayer(moveX, moveZ, dt);
      }
      if (basicAttack && _playerAttackCooldown <= 0) _playerAttack();
      if (castSkill && _playerSkillCooldown <= 0) {
        _castHeroSkill(externalPlayerMovement: externalPlayerMovement);
      }
    }

    _updateWaves(dt);
    _updateMinions(dt);
    _updateBots(dt);
    _updateCentralObjective(dt);
    _updateDistricts(dt);
    _updateTowers(dt);
    _checkWinner();
  }

  /// Receives the Rapier capsule's grounded/falling world position.
  /// Falling out of the playable world is a real defeat, not an arbitrary
  /// coordinate reset; the normal respawn timer then handles the return.
  void applyPhysicsPlayerPosition(MobaPoint position) {
    if (_winner != null || _playerRespawn > 0 || _playerHealth <= 0) return;
    if (!position.x.isFinite ||
        !position.z.isFinite ||
        !position.elevation.isFinite) {
      return;
    }
    _playerPosition = position;
    if (!ArenaWorldCatalog.contains(position.x, position.z) ||
        position.elevation < -2.2) {
      _damagePlayer(_playerHealth);
      _playerMoving = false;
    }
  }

  void setPhysicsMovementState({required bool moving}) {
    _playerMoving =
        moving && _playerHealth > 0 && _playerRespawn <= 0 && _winner == null;
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

  void _tryMovePlayer(
    double dx,
    double dz, {
    bool allowAxisSlide = true,
  }) {
    final distance = math.sqrt(dx * dx + dz * dz);
    if (distance <= 1e-6) return;

    bool tryPosition(double x, double z) {
      final elevation = ArenaWorldCatalog.resolveNavigationElevation(
        x,
        z,
        _playerPosition.elevation,
      );
      if (elevation == null ||
          !ArenaWorldCatalog.isWalkable(x, z, elevation: elevation) ||
          _isBlockedByCover(x, z, elevation)) {
        return false;
      }
      _playerPosition = MobaPoint(x, z, elevation: elevation);
      return true;
    }

    // Swept movement closes the endpoint-only gap used by long skills
    // such as Kairo's dash. The 0.22-unit step is small enough to follow ramps.
    final segments = math.max(1, (distance / 0.22).ceil());
    final stepX = dx / segments;
    final stepZ = dz / segments;
    for (var segment = 0; segment < segments; segment++) {
      final nextX = _playerPosition.x + stepX;
      final nextZ = _playerPosition.z + stepZ;
      if (tryPosition(nextX, nextZ)) continue;
      if (!allowAxisSlide) return;

      // Slide from the last committed position, not from the original
      // endpoint. This prevents a later segment from jumping through a wall
      // after an earlier segment used axis sliding.
      if (tryPosition(_playerPosition.x + stepX, _playerPosition.z)) {
        tryPosition(_playerPosition.x, _playerPosition.z + stepZ);
        continue;
      }
      if (tryPosition(_playerPosition.x, _playerPosition.z + stepZ)) {
        continue;
      }
      return;
    }
  }

  void _playerAttack() {
    // The action always has a visible response, even when no target is in range.
    // Damage remains server-independent and is applied only to valid nearby MOBA
    // targets; the renderer plays the rig's SwordSlash combat clip.
    _playerAttackPulseSeconds = 0.46;
    _playerAttackCooldown = heroId.basicAttackCooldown;

    final damage = heroId.basicDamage * _playerPower;
    final selectedTarget = _selectedTargetSnapshot();
    if (selectedTarget != null &&
        _playerPosition.distanceTo(selectedTarget.position) <= heroId.basicRange) {
      if (selectedTarget.kind == 'HERO') {
        for (final bot in _bots) {
          if ('bot:${bot.id}' != selectedTarget.id) continue;
          _damageBot(bot, MobaTeam.blue, damage);
          _confirmPlayerHit();
          return;
        }
      } else {
        final minionId = int.tryParse(selectedTarget.id.substring(7));
        for (final minion in _minions) {
          if (minion.id != minionId) continue;
          _damageMinion(minion, MobaTeam.blue, damage);
          _confirmPlayerHit();
          return;
        }
      }
    }

    final lane = _nearestLane(_playerPosition);
    final enemyBot = _nearestBot(
      _playerPosition,
      MobaTeam.red,
      maxRange: heroId.basicRange,
    );
    if (enemyBot != null) {
      _damageBot(enemyBot, MobaTeam.blue, damage);
      _confirmPlayerHit();
      return;
    }

    final cover = _nearestCover(_playerPosition, heroId.basicRange);
    if (cover != null) {
      cover.health = math.max(0, cover.health - damage);
      if (!cover.alive) _playerGold += 28;
      _confirmPlayerHit();
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
      _confirmPlayerHit();
      return;
    }

    final tower = _activeTower(MobaTeam.red, lane);
    if (tower != null &&
        _playerPosition.distanceTo(tower.position) <= heroId.basicRange &&
        _hasFriendlyMinionSupport(MobaTeam.blue, lane, tower.position, 7.2)) {
      _damageTower(tower, MobaTeam.blue, damage);
      _confirmPlayerHit();
      return;
    }

    if (_laneOpen(MobaTeam.red, lane) &&
        _playerPosition.distanceTo(_corePosition(MobaTeam.red)) <= heroId.basicRange + 0.8) {
      _damageCore(MobaTeam.red, damage, lane);
      _confirmPlayerHit();
    }
  }

  void _confirmPlayerHit() {
    _playerHitConfirmSeconds = 0.22;
  }

  void _castHeroSkill({required bool externalPlayerMovement}) {
    _playerSkillPulseSeconds = 0.82;
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
        final dashX = dx * 5.0;
        final dashZ = dz * 5.0;
        if (externalPlayerMovement) {
          // Rapier resolves the same burst against the live collision world.
          // Target selection uses the expected dash endpoint without moving the
          // simulation's player copy ahead of the physical capsule.
          _pendingPhysicsDash = MobaPoint(dashX, dashZ);
          final endpoint = MobaPoint(
            _playerPosition.x + dashX,
            _playerPosition.z + dashZ,
            elevation: _playerPosition.elevation,
          );
          // Hit resolution is deferred until Rapier reports the actual
          // collision-resolved dash endpoint.
        } else {
          _tryMovePlayer(dashX, dashZ, allowAxisSlide: false);
          final target = _nearestBot(
            _playerPosition,
            MobaTeam.red,
            maxRange: 3.0,
          );
          if (target != null) _damageBot(target, MobaTeam.blue, 72);
        }
    }
    _playerSkillCooldown = 9.0;
  }

  void _updateWaves(double dt) {
    // Dead units must not consume the fixed 48-entity budget. Prune them
    // before the capacity check, not only inside the spawn routine.
    _minions.removeWhere((unit) => !unit.alive);
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
          visualId: MobaNpcVisualId.values[
            (slot + team.index * 2) % MobaNpcVisualId.values.length
          ],
          position: MobaPoint(
            _laneX(lane, z) + (slot - 1.5) * 0.75,
            z - team.forward * stagger,
          ),
        ),
      );
    }
  }

  void _updateMinions(double dt) {
    for (final minion in _minions.where((unit) => unit.alive)) {
      minion.moving = false;
      minion.attackSeconds = math.max(0, minion.attackSeconds - dt);
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
          _markMinionAttack(minion, enemy.position);
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
          _markMinionAttack(minion, enemyBot.position);
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
          _markMinionAttack(minion, _playerPosition);
          _damagePlayer(minion.ranged ? 7 : 10);
          minion.attackCooldown = 1.0;
        }
        continue;
      }

      final defendingTeam = minion.team.enemy;
      final tower = _activeTower(defendingTeam, minion.lane);
      if (tower != null) {
        final approach = MobaPoint(
          tower.position.x,
          tower.position.z - minion.team.forward * 3.5,
        );
        if (minion.position.distanceTo(tower.position) > 4.15) {
          _moveMinion(minion, approach, minion.ranged ? 2.25 : 2.5, dt);
        } else if (minion.attackCooldown <= 0) {
          _markMinionAttack(minion, tower.position);
          _damageTower(tower, minion.team, minion.ranged ? 34 : 42);
          minion.attackCooldown = 1.12;
        }
      } else if (_laneOpen(defendingTeam, minion.lane)) {
        final core = _corePosition(defendingTeam);
        final approach = MobaPoint(
          core.x,
          core.z - minion.team.forward * 3.35,
        );
        if (minion.position.distanceTo(core) > 3.85) {
          _moveMinion(minion, approach, 2.4, dt);
        } else if (minion.attackCooldown <= 0) {
          _markMinionAttack(minion, core);
          _damageCore(defendingTeam, 26, minion.lane);
          minion.attackCooldown = 1.0;
        }
      }
    }
  }

  void _moveMinion(_Minion unit, MobaPoint target, double speed, double dt) {
    final before = unit.position;
    final next = before.moveToward(target, speed * dt);
    final laneOpen = _laneOpen(unit.team.enemy, unit.lane);
    final formationOffset = switch (unit.id % 4) {
      0 => -1.35,
      1 => -0.45,
      2 => 0.45,
      _ => 1.35,
    };
    final preferredX = laneOpen
        ? target.x + formationOffset * 0.28
        : _laneX(unit.lane, next.z) + formationOffset;
    final resolved = _resolveAgentMovement(
      before, target, speed, dt, preferredX: preferredX,
    );
    if (resolved == null) return;
    unit.position = resolved;
    final dx = resolved.x - before.x;
    final dz = resolved.z - before.z;
    if (dx.abs() + dz.abs() > 0.0001) {
      unit.facingX = dx;
      unit.facingZ = dz;
      unit.moving = true;
    }
  }

  void _markMinionAttack(_Minion unit, MobaPoint target) {
    final dx = target.x - unit.position.x;
    final dz = target.z - unit.position.z;
    if (dx.abs() + dz.abs() > 0.001) {
      unit.facingX = dx;
      unit.facingZ = dz;
    }
    unit.moving = false;
    unit.attackSeconds = 0.38;
  }

  void _markBotAttack(_Bot bot, MobaPoint target) {
    final dx = target.x - bot.position.x;
    final dz = target.z - bot.position.z;
    if (dx.abs() + dz.abs() > 0.001) {
      bot.facingX = dx;
      bot.facingZ = dz;
    }
    bot.moving = false;
    bot.attackSeconds = 0.42;
  }

  void _moveBot(_Bot bot, MobaPoint target, double speed, double dt) {
    final before = bot.position;
    final resolved = _resolveAgentMovement(before, target, speed, dt);
    if (resolved == null) return;
    bot.position = resolved;
    final dx = resolved.x - before.x;
    final dz = resolved.z - before.z;
    if (dx.abs() + dz.abs() > 0.0001) {
      bot.facingX = dx;
      bot.facingZ = dz;
      bot.moving = true;
    }
  }

  /// Shared steering and collision gate for autonomous ground units.
  /// Role AI chooses the target; this motor owns how an agent reaches it.
  /// The fixed simulation clock keeps movement frame-rate independent.
  MobaPoint? _resolveAgentMovement(
    MobaPoint origin,
    MobaPoint target,
    double speed,
    double dt, {
    double? preferredX,
  }) {
    final dx = target.x - origin.x;
    final dz = target.z - origin.z;
    final distance = math.sqrt(dx * dx + dz * dz);
    if (distance < 0.001 || speed <= 0 || dt <= 0) return null;
    final step = math.min(distance, speed * dt);
    final angle = math.atan2(dx, dz);
    const offsets = <double>[
      0, 0.42, -0.42, 0.86, -0.86, 1.3, -1.3, math.pi / 2, -math.pi / 2,
    ];
    final candidates = <MobaPoint>[];
    for (final offset in offsets) {
      final heading = angle + offset;
      candidates.add(MobaPoint(
        origin.x + math.sin(heading) * step,
        origin.z + math.cos(heading) * step,
        elevation: origin.elevation,
      ));
    }
    if (preferredX != null) {
      final blend = (dt * speed * 1.4).clamp(0.0, 1.0).toDouble();
      candidates.insert(0, MobaPoint(
        origin.x + (preferredX - origin.x) * blend,
        origin.z + dz.sign * math.min(dz.abs(), step),
        elevation: origin.elevation,
      ));
    }
    candidates.addAll([
      MobaPoint(origin.x + dx.sign * step, origin.z,
          elevation: origin.elevation),
      MobaPoint(origin.x, origin.z + dz.sign * step,
          elevation: origin.elevation),
    ]);
    MobaPoint? best;
    var bestDistance = double.infinity;
    for (final candidate in candidates) {
      if (!ArenaWorldCatalog.isWalkable(
        candidate.x, candidate.z,
        includeTowerCollision: false,
        elevation: candidate.elevation,
      ) || _isBlockedByCover(candidate.x, candidate.z, candidate.elevation)) {
        continue;
      }
      final remaining = candidate.distanceTo(target);
      if (remaining < bestDistance) {
        best = candidate;
        bestDistance = remaining;
      }
    }
    return best;
  }

  MobaPoint? _botFlankWaypoint(_Bot bot) {
    if (bot.role != 3 && bot.role != 4) return null;

    final laneSide = bot.lane == MobaLane.top ? -1.0 : 1.0;
    final teamSide = bot.team == MobaTeam.blue ? 1.0 : -1.0;
    final side = laneSide * teamSide;
    final waypoint = MobaPoint(
      side * (bot.role == 3 ? 56.0 : 68.0),
      bot.team.homeZ + bot.team.forward * (bot.role == 3 ? 22.0 : 12.0),
    );
    return bot.position.distanceTo(waypoint) > 3.2 ? waypoint : null;
  }

  MobaPoint? _botDistrictWaypoint(_Bot bot) {
    if (bot.role != 4) return null;
    _DistrictControlPoint? nearest;
    var nearestDistance = double.infinity;
    for (final district in _districts) {
      if (district.control.owner == bot.team) continue;
      final distance = bot.position.distanceTo(district.position);
      if (distance < nearestDistance) {
        nearest = district;
        nearestDistance = distance;
      }
    }
    return nearest?.position;
  }

  MobaPoint _botRouteWaypoint(_Bot bot, MobaPoint laneGoal) {
    if (bot.role == 2 && _objectiveOwner != bot.team &&
        bot.position.distanceTo(_objectivePosition) > objectiveRadius + 2.0) {
      return _objectivePosition;
    }
    return _botDistrictWaypoint(bot) ?? _botFlankWaypoint(bot) ?? laneGoal;
  }

  void _updateBots(double dt) {
    for (final bot in _bots) {
      bot.moving = false;
      if (bot.respawnSeconds > 0) {
        bot.respawnSeconds = math.max(0, bot.respawnSeconds - dt);
        if (bot.respawnSeconds <= 0) {
          bot.health = _Bot.maxHealth;
          bot.position = MobaPoint(
            _laneX(bot.lane, bot.team.homeZ - bot.team.forward * 2),
            bot.team.homeZ - bot.team.forward * 2,
          );
          bot.facingX = 0;
          bot.facingZ = bot.team.forward;
        }
        continue;
      }

      bot.attackSeconds = math.max(0, bot.attackSeconds - dt);
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
          _moveBot(bot, _playerPosition, 3.15, dt);
        } else if (bot.attackCooldown <= 0) {
          _markBotAttack(bot, _playerPosition);
          _damagePlayer(10);
          bot.attackCooldown = 1.05;
        }
        continue;
      }
      if (enemyHero != null) {
        final distance = bot.position.distanceTo(enemyHero.position);
        if (distance > 2.25) {
          _moveBot(bot, enemyHero.position, 3.15, dt);
        } else if (bot.attackCooldown <= 0) {
          _markBotAttack(bot, enemyHero.position);
          _damageBot(enemyHero, bot.team, 15);
          bot.attackCooldown = 1.0;
        }
        continue;
      }

      // A map ping temporarily overrides macro rotation for exactly one
      // available roamer. Hero combat still wins, so a ping never cancels a
      // fight already in progress.
      final pingTarget = _teamPingTarget;
      if (bot.team == MobaTeam.blue &&
          bot.id == _teamPingBotId &&
          pingTarget != null &&
          _teamPingSeconds > 0) {
        final distance = bot.position.distanceTo(pingTarget);
        if (distance > 2.7) {
          _moveBot(bot, pingTarget, 3.35, dt);
        } else {
          bot.moving = false;
          final dx = pingTarget.x - bot.position.x;
          final dz = pingTarget.z - bot.position.z;
          if (dx.abs() + dz.abs() > 0.001) {
            bot.facingX = dx;
            bot.facingZ = dz;
          }
        }
        continue;
      }

      // Side-lane roamers must complete their flank approach before being
      // pulled back onto the minion line. Nearby enemy heroes still take
      // combat priority, but minion aggro cannot cancel the route every tick.
      final flankWaypoint = _botFlankWaypoint(bot);
      if (flankWaypoint != null) {
        _moveBot(bot, flankWaypoint, 2.9, dt);
        continue;
      }

      final districtWaypoint = _botDistrictWaypoint(bot);
      if (districtWaypoint != null) {
        if (bot.position.distanceTo(districtWaypoint) > districtRadius - 1.0) {
          _moveBot(bot, districtWaypoint, 3.0, dt);
        } else {
          bot.moving = false;
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
          _moveBot(bot, enemyMinion.position, 3.15, dt);
        } else if (bot.attackCooldown <= 0) {
          _markBotAttack(bot, enemyMinion.position);
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
      final core = _corePosition(bot.team.enemy);
      final goal = tower != null
          ? MobaPoint(
              tower.position.x,
              tower.position.z - bot.team.forward * 4.0,
            )
          : (_laneOpen(bot.team.enemy, bot.lane)
              ? MobaPoint(
                  core.x,
                  core.z - bot.team.forward * 3.7,
                )
              : MobaPoint(_laneX(bot.lane, targetZ), targetZ));
      final routeGoal = _botRouteWaypoint(bot, goal);
      _moveBot(bot, routeGoal, 2.9, dt);

      if (tower != null &&
          bot.position.distanceTo(tower.position) <= 4.8 &&
          _hasFriendlyMinionSupport(bot.team, bot.lane, tower.position, 7.2) &&
          bot.attackCooldown <= 0) {
        _markBotAttack(bot, tower.position);
        _damageTower(tower, bot.team, 24);
        bot.attackCooldown = 1.15;
      } else if (tower == null &&
          _laneOpen(bot.team.enemy, bot.lane) &&
          bot.position.distanceTo(core) <= 4.2 &&
          bot.attackCooldown <= 0) {
        _markBotAttack(bot, _corePosition(bot.team.enemy));
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

  _Cover? _nearestCover(MobaPoint position, double maxRange) {
    _Cover? target;
    var nearest = maxRange;
    for (final cover in _covers) {
      if (!cover.alive) continue;
      final distance = position.distanceTo(cover.position);
      if (distance < nearest) {
        nearest = distance;
        target = cover;
      }
    }
    return target;
  }

  bool _isBlockedByCover(double x, double z, double elevation) {
    final point = MobaPoint(x, z, elevation: elevation);
    return _covers.any(
      (cover) => cover.alive && point.distanceTo(cover.position) < 1.28,
    );
  }

  void _updateCentralObjective(double dt) {
    var blue = 0.0;
    var red = 0.0;

    bool isInside(MobaPoint point) =>
        point.distanceTo(_objectivePosition) <= objectiveRadius;

    if (_playerRespawn <= 0 && isInside(_playerPosition)) blue += 2.0;
    for (final bot in _bots.where((unit) => unit.alive)) {
      if (!isInside(bot.position)) continue;
      if (bot.team == MobaTeam.blue) {
        blue += 1.5;
      } else {
        red += 1.5;
      }
    }
    for (final minion in _minions.where((unit) => unit.alive)) {
      if (!isInside(minion.position)) continue;
      if (minion.team == MobaTeam.blue) {
        blue += 0.35;
      } else {
        red += 0.35;
      }
    }

    final capturedTeam = _objective.update(
      dt,
      blue: blue,
      red: red,
    );
    if (capturedTeam != null) {
      _awardGold(capturedTeam, 150);
      _awardXp(capturedTeam, 90);
    }
  }

  void _updateDistricts(double dt) {
    for (final district in _districts) {
      var blue = 0.0;
      var red = 0.0;
      bool inside(MobaPoint point) => point.distanceTo(district.position) <= districtRadius;
      if (_playerRespawn <= 0 && inside(_playerPosition)) blue += 2.0;
      for (final bot in _bots.where((unit) => unit.alive)) {
        if (!inside(bot.position)) continue;
        if (bot.team == MobaTeam.blue) { blue += 1.5; } else { red += 1.5; }
      }
      for (final minion in _minions.where((unit) => unit.alive)) {
        if (!inside(minion.position)) continue;
        if (minion.team == MobaTeam.blue) { blue += 0.35; } else { red += 0.35; }
      }
      final capturedTeam = district.control.update(dt, blue: blue, red: red);
      if (capturedTeam != null) {
        _awardGold(capturedTeam, 95);
        _awardXp(capturedTeam, 60);
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
    target.health = math.max(
      0,
      target.health - damage * _objectiveDamageMultiplier(source),
    );
    if (!target.alive) {
      _awardGold(source, target.ranged ? 58 : 42);
      _awardXp(source, target.ranged ? 34 : 26);
    }
  }

  void _damageBot(_Bot target, MobaTeam source, double damage) {
    if (!target.alive) return;
    target.health = math.max(
      0,
      target.health - damage * _objectiveDamageMultiplier(source),
    );
    if (target.health <= 0) {
      target.respawnSeconds = 6;
      target.attackSeconds = 0;
      target.moving = false;
      _teamKills[source.index]++;
      _awardGold(source, 170);
      _awardXp(source, 115);
    }
  }

  void _damageTower(_Tower tower, MobaTeam source, double damage) {
    if (!tower.alive) return;
    tower.health = math.max(
      0,
      tower.health - damage * _objectiveDamageMultiplier(source),
    );
    if (!tower.alive) {
      _awardGold(source, 250);
      _awardXp(source, 120);
    }
  }

  void _damageCore(MobaTeam defendingTeam, double damage, MobaLane lane) {
    if (!_laneOpen(defendingTeam, lane)) return;
    final attackingTeam = defendingTeam.enemy;
    _coreHealth[defendingTeam.index] = math.max(
      0,
      _coreHealth[defendingTeam.index] -
          damage * _objectiveDamageMultiplier(attackingTeam),
    );
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
    // Ignore additional hits during the death/respawn window.
    if (_playerRespawn > 0 || _playerHealth <= 0) return;
    final mitigation = _playerShieldTime > 0 ? 0.58 : 1.0;
    final objectiveMultiplier =
        _objectiveDamageMultiplier(MobaTeam.red);
    _playerHealth = math.max(
      0,
      _playerHealth - damage * mitigation * objectiveMultiplier,
    );
    if (_playerHealth <= 0) {
      _playerHealth = 0;
      _playerRespawn = 5;
      _playerMoving = false;
      _playerAttackPulseSeconds = 0;
      _playerHitConfirmSeconds = 0;
      // Keep the defeated hero at the combat location. The spawn teleport
      // happens only after the respawn timer expires in _tick().
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
            visualId: unit.visualId,
            position: unit.position,
            facingX: unit.facingX,
            facingZ: unit.facingZ,
            moving: unit.moving,
            health: unit.health,
            maxHealth: unit.maxHealth,
            attackSeconds: unit.attackSeconds,
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
            visualId: bot.visualId,
            position: bot.position,
            facingX: bot.facingX,
            facingZ: bot.facingZ,
            moving: bot.moving,
            health: bot.health,
            maxHealth: _Bot.maxHealth,
            respawnSeconds: bot.respawnSeconds,
            attackSeconds: bot.attackSeconds,
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

    final covers = _covers
        .map(
          (cover) => MobaCoverSnapshot(
            id: cover.id,
            variant: cover.variant,
            position: cover.position,
            health: cover.health,
            maxHealth: _Cover.maxHealth,
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
      playerSpawnShieldSeconds: _playerShieldTime,
      playerMoving: _playerMoving,
      playerAttackSeconds: _playerAttackPulseSeconds,
      playerHitConfirmSeconds: _playerHitConfirmSeconds,
      playerSkillPulseSeconds: _playerSkillPulseSeconds,
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
      covers: List.unmodifiable(covers),
      districts: List.unmodifiable([
        for (final district in _districts)
          MobaDistrictSnapshot(
            id: district.id, name: district.name, position: district.position,
            control: district.control.control, owner: district.control.owner,
            contested: district.control.contested,
          ),
      ]),
      centralObjective: MobaObjectiveSnapshot(
        control: _objective.control,
        owner: _objective.owner,
        contested: _objective.contested,
        bluePresence: _objective.bluePresence,
        redPresence: _objective.redPresence,
      ),
      selectedTarget: _selectedTargetSnapshot(),
      teamPingTarget: _teamPingSeconds > 0 ? _teamPingTarget : null,
      teamPingSeconds: _teamPingSeconds,
      winner: _winner,
    );
  }
}
