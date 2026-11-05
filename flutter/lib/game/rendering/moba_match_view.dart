import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_scene/scene.dart' hide Material;
import 'package:vector_math/vector_math.dart' as vm;

import '../match/moba_match_simulation.dart';
import '../world/arena_world_catalog.dart';

class MobaMatchView extends StatefulWidget {
  const MobaMatchView({
    super.key,
    required this.simulation,
    required this.onRuntimeReady,
    required this.onPause,
    required this.onFinished,
  });

  final MobaMatchSimulation simulation;
  final VoidCallback onRuntimeReady;
  final VoidCallback onPause;
  final ValueChanged<MobaTeam> onFinished;

  @override
  State<MobaMatchView> createState() => _MobaMatchViewState();
}

class _MobaMatchViewState extends State<MobaMatchView> {
  static const double _worldScale = ArenaWorldCatalog.worldScale;
  static const String _terrainAsset = 'assets/world/arena_terrain.glb';
  static const String _minionAsset = 'assets/match/quaternius_minion.glb';

  late MobaMatchSnapshot _snapshot;
  double _cameraYaw = 0;
  double _cameraPitch = 0.46;
  double _moveX = 0;
  double _moveZ = 0;
  bool _basicAttackHeld = false;
  bool _skillHeld = false;
  bool _worldReady = false;
  bool _readySent = false;
  bool _finishSent = false;
  String? _minionWalkClip;
  bool _minionAssetHasWalk = false;
  late double _cameraX;
  late double _cameraY;
  late double _cameraZ;
  double _cameraYaw = 0;
  double _cameraPitch = 0;
  late double _lookX;
  late double _lookY;
  late double _lookZ;

  @override
  void initState() {
    super.initState();
    _snapshot = widget.simulation.snapshot;
    _initialiseCameraRig(_snapshot);
    _loadMinionAnimationManifest();
  }

  Future<void> _loadMinionAnimationManifest() async {
    try {
      final raw = await rootBundle.loadString(
        'assets/match/match-asset-manifest.json',
      );
      final manifest = jsonDecode(raw) as Map<String, dynamic>;
      final character = manifest['character'] as Map<String, dynamic>;
      final clips = (character['animations'] as List<dynamic>)
          .whereType<String>()
          .toList(growable: false);
      String? walk;
      for (final clip in clips) {
        if (clip.toLowerCase().contains('walk') ||
            clip.toLowerCase().contains('run')) {
          walk = clip;
          break;
        }
      }
      if (!mounted) return;
      setState(() {
        _minionWalkClip = walk;
        _minionAssetHasWalk = walk != null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _minionWalkClip = null;
        _minionAssetHasWalk = false;
      });
    }
  }

  void _initialiseCameraRig(MobaMatchSnapshot snapshot) {
    final x = snapshot.playerPosition.x * _worldScale;
    final z = snapshot.playerPosition.z * _worldScale;
    final forwardX = math.sin(_cameraYaw);
    final forwardZ = math.cos(_cameraYaw);
    final horizontalDistance = 13.5 * math.cos(_cameraPitch);
    final ground = _groundHeight(snapshot.playerPosition);

    _cameraX = x - forwardX * horizontalDistance;
    _cameraY = ground + 1.35 + 13.5 * math.sin(_cameraPitch);
    _cameraZ = z - forwardZ * horizontalDistance;
    _lookX = x + forwardX * 4.4;
    _lookY = ground + 1.35;
    _lookZ = z + forwardZ * 4.4;
  }

  void _advanceCameraRig(MobaMatchSnapshot snapshot, double deltaSeconds) {
    final x = snapshot.playerPosition.x * _worldScale;
    final z = snapshot.playerPosition.z * _worldScale;
    final forwardX = math.sin(_cameraYaw);
    final forwardZ = math.cos(_cameraYaw);
    final horizontalDistance = 13.5 * math.cos(_cameraPitch);
    final ground = _groundHeight(snapshot.playerPosition);

    // Camera yaw/pitch are controlled only by the right-side drag zone.
    final desiredX = x - forwardX * horizontalDistance;
    final desiredY = ground + 1.35 + 13.5 * math.sin(_cameraPitch);
    final desiredZ = z - forwardZ * horizontalDistance;
    final desiredLookX = x + forwardX * 4.4;
    final desiredLookY = ground + 1.35;
    final desiredLookZ = z + forwardZ * 4.4;
    final blend = 1.0 - math.exp(-7.0 * deltaSeconds);

    _cameraX += (desiredX - _cameraX) * blend;
    _cameraY += (desiredY - _cameraY) * blend;
    _cameraZ += (desiredZ - _cameraZ) * blend;
    _lookX += (desiredLookX - _lookX) * blend;
    _lookY += (desiredLookY - _lookY) * blend;
    _lookZ += (desiredLookZ - _lookZ) * blend;
  }

  void _onSceneTick(Duration elapsed, double deltaSeconds) {
    if (!mounted) return;
    // Movement is camera-relative but never feeds back into camera yaw.
    final forwardX = math.sin(_cameraYaw);
    final forwardZ = math.cos(_cameraYaw);
    final rightX = math.cos(_cameraYaw);
    final rightZ = -math.sin(_cameraYaw);
    final worldMoveX = _moveX * rightX + _moveZ * forwardX;
    final worldMoveZ = _moveX * rightZ + _moveZ * forwardZ;
    widget.simulation.step(
      deltaSeconds,
      moveX: worldMoveX,
      moveZ: worldMoveZ,
      basicAttack: _basicAttackHeld,
      castSkill: _skillHeld,
    );
    final next = widget.simulation.snapshot;
    _advanceCameraRig(next, deltaSeconds);
    setState(() => _snapshot = next);

    if (_worldReady && !_readySent) {
      _readySent = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onRuntimeReady();
      });
    }
    if (next.winner != null && !_finishSent) {
      _finishSent = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onFinished(next.winner!);
      });
    }
  }

  void _rotateCamera(DragUpdateDetails details) {
    // Camera look is deliberately isolated from the left-side movement stick.
    // A drag in the central/right playfield rotates yaw and adjusts elevation.
    setState(() {
      _cameraYaw =
          (_cameraYaw + details.delta.dx * 0.008).remainder(2 * math.pi);
      _cameraPitch = (_cameraPitch - details.delta.dy * 0.006)
          .clamp(0.22, 0.92)
          .toDouble();
    });
  }

  void _markWorldReady() {
    if (!mounted || _worldReady) return;
    setState(() => _worldReady = true);
  }

  String _heroAsset(MobaHeroId hero) => switch (hero) {
        MobaHeroId.lyra => 'assets/heroes/lyra.glb',
        MobaHeroId.bastion => 'assets/heroes/bastion.glb',
        MobaHeroId.kairo => 'assets/heroes/kairo.glb',
      };

  String _heroIdle(MobaHeroId hero) => switch (hero) {
        MobaHeroId.lyra => 'HumanArmature|Female_Idle',
        MobaHeroId.bastion || MobaHeroId.kairo => 'HumanArmature|Man_Idle',
      };

  String _heroWalk(MobaHeroId hero) => switch (hero) {
        MobaHeroId.lyra => 'HumanArmature|Female_Walk',
        MobaHeroId.bastion || MobaHeroId.kairo => 'HumanArmature|Man_Walk',
      };

  String _heroAttack(MobaHeroId hero) => switch (hero) {
        MobaHeroId.lyra => 'HumanArmature|Female_Punch',
        MobaHeroId.bastion || MobaHeroId.kairo => 'HumanArmature|Man_Punch',
      };

  double _groundHeight(MobaPoint point) =>
      ArenaWorldCatalog.navigationHeightAt(point.x, point.z) + 0.035;

  vm.Vector3 _worldPosition(MobaPoint point, {double heightOffset = 0}) =>
      vm.Vector3(
        point.x * _worldScale,
        _groundHeight(point) + heightOffset,
        point.z * _worldScale,
      );

  vm.Quaternion _facing(MobaTeam team) => vm.Quaternion.axisAngle(
        vm.Vector3(0, 1, 0),
        team == MobaTeam.blue ? 0 : math.pi,
      );

  vm.Quaternion _playerFacing(MobaMatchSnapshot snapshot) {
    final yaw = math.atan2(snapshot.playerFacingX, snapshot.playerFacingZ);
    return vm.Quaternion.axisAngle(vm.Vector3(0, 1, 0), yaw);
  }

  static const _bridges = <(String, double, double)>[
    ('top', -22.5, 0.0),
    ('middle', 0.0, 15.0),
    ('bottom', 22.5, 13.1),
  ];

  List<Widget> _buildSceneChildren(MobaMatchSnapshot snapshot) {
    return <Widget>[
      SceneModel(
        _terrainAsset,
        key: const ValueKey('match-terrain'),
        name: 'vale_das_coroas_match_terrain',
        onLoaded: (_) => _markWorldReady(),
      ),
      for (var i = 0; i < ArenaWorldCatalog.trees.length; i++)
        _buildWorldProp(ArenaWorldCatalog.trees[i], 'match-tree-$i'),
      for (var i = 0; i < ArenaWorldCatalog.bushes.length; i++)
        _buildWorldProp(ArenaWorldCatalog.bushes[i], 'match-bush-$i'),
      _buildBase(MobaTeam.blue),
      _buildBase(MobaTeam.red),
      for (final bridge in _bridges)
        SceneModel(
          'assets/match/bridge_a.glb',
          key: ValueKey('match-bridge-${bridge.$1}'),
          name: 'lane_bridge_${bridge.$1}',
          position: _worldPosition(MobaPoint(bridge.$2, bridge.$3)),
          rotation: vm.Quaternion.axisAngle(
            vm.Vector3(0, 1, 0),
            math.pi / 2,
          ),
          scale: vm.Vector3.all(2.0),
        ),
      for (final tower in snapshot.towers)
        SceneModel(
          tower.team == MobaTeam.blue
              ? 'assets/match/tower_blue.glb'
              : 'assets/match/tower_red.glb',
          key: ValueKey(
            'tower-${tower.team.name}-${tower.lane.name}-${tower.tier}',
          ),
          name:
              '${tower.team.name}_${tower.lane.name}_tower_${tower.tier + 1}',
          position: _worldPosition(tower.position),
          scale: vm.Vector3.all(2.05),
        ),
      for (final bot in snapshot.bots)
        if (bot.respawnSeconds <= 0) _buildBot(bot),
      for (final minion in snapshot.minions) _buildMinion(minion),
      SceneModel(
        _heroAsset(snapshot.heroId),
        key: const ValueKey('match-player-hero'),
        name: 'player_${snapshot.heroId.id}',
        position: _worldPosition(snapshot.playerPosition, heightOffset: 0.04),
        rotation: _playerFacing(snapshot),
        scale: vm.Vector3.all(0.82),
        animations: [
          SceneAnimationSpec(
            snapshot.playerAttackSeconds > 0
                ? _heroAttack(snapshot.heroId)
                : snapshot.playerMoving
                    ? _heroWalk(snapshot.heroId)
                    : _heroIdle(snapshot.heroId),
            loop: snapshot.playerAttackSeconds <= 0,
            speed: snapshot.playerAttackSeconds > 0
                ? 1.12
                : snapshot.playerMoving
                    ? 1.05
                    : 0.78,
          ),
        ],
      ),
    ];
  }

  Widget _buildBase(MobaTeam team) {
    final point = MobaPoint(0, team == MobaTeam.blue ? -35.5 : 35.5);
    return SceneModel(
      team == MobaTeam.blue
          ? 'assets/match/castle_blue.glb'
          : 'assets/match/castle_red.glb',
      key: ValueKey('match-base-${team.name}'),
      name: '${team.name}_team_base',
      position: _worldPosition(point),
      rotation: _facing(team),
      scale: vm.Vector3.all(1.75),
    );
  }

  Widget _buildWorldProp(ArenaWorldPlacement placement, String key) {
    return SceneModel(
      placement.asset,
      key: ValueKey(key),
      name: key.replaceAll('-', '_'),
      position: vm.Vector3(placement.x, placement.y, placement.z),
      rotation: vm.Quaternion.axisAngle(
        vm.Vector3(0, 1, 0),
        placement.yaw,
      ),
      scale: vm.Vector3.all(placement.scale),
    );
  }

  Widget _buildBot(MobaBotSnapshot bot) {
    return SceneModel(
      _heroAsset(bot.heroId),
      key: ValueKey('match-bot-${bot.id}'),
      name: bot.id,
      position: _worldPosition(bot.position, heightOffset: 0.03),
      rotation: _facing(bot.team),
      scale: vm.Vector3.all(0.68),
      animations: [
        SceneAnimationSpec(_heroWalk(bot.heroId), loop: true, speed: 0.94),
      ],
    );
  }

  Widget _buildMinion(MobaMinionSnapshot minion) {
    final fallbackHero =
        MobaHeroId.values[minion.id % MobaHeroId.values.length];
    final useQuaternius = _minionAssetHasWalk && _minionWalkClip != null;
    final asset = useQuaternius ? _minionAsset : _heroAsset(fallbackHero);
    final animation =
        useQuaternius ? _minionWalkClip! : _heroWalk(fallbackHero);
    final scale = minion.ranged ? 0.45 : 0.48;
    return SceneModel(
      asset,
      key: ValueKey('match-minion-${minion.id}'),
      name:
          '${minion.team.name}_${minion.lane.name}_minion_${minion.id}',
      position: _worldPosition(minion.position, heightOffset: 0.02),
      rotation: _facing(minion.team),
      scale: vm.Vector3.all(scale),
      animations: [
        SceneAnimationSpec(
          animation,
          loop: true,
          speed: minion.ranged ? 0.84 : 1.0,
        ),
      ],
    );
  }

  void _updateJoystick(Offset localPosition) {
    const size = 112.0;
    const center = Offset(size / 2, size / 2);
    const radius = 36.0;
    final delta = localPosition - center;
    final length = delta.distance;
    final limited = length > radius ? delta * (radius / length) : delta;
    setState(() {
      _moveX = (limited.dx / radius).clamp(-1.0, 1.0).toDouble();
      _moveZ = (-limited.dy / radius).clamp(-1.0, 1.0).toDouble();
    });
  }

  void _clearJoystick() {
    if (!mounted) return;
    setState(() {
      _moveX = 0;
      _moveZ = 0;
    });
  }

  String _clock(double seconds) {
    final total = seconds.floor();
    final minutes = (total ~/ 60).toString().padLeft(2, '0');
    final remainder = (total % 60).toString().padLeft(2, '0');
    return '$minutes:$remainder';
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;
    return LayoutBuilder(
      builder: (context, viewport) {
        final compact = viewport.maxHeight < 430;
        final side = compact ? 12.0 : 18.0;
        return Stack(
          fit: StackFit.expand,
          children: [
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF7EACBE),
                    Color(0xFF3C667A),
                    Color(0xFF182A32),
                  ],
                ),
              ),
            ),
            SceneView.declarative(
              key: const ValueKey('live-moba-scene'),
              pixelRatio: 0.82,
              maxFrameRate: 30,
              cameraBuilder: (elapsed) {
                // Smoothed trailing perspective with a restrained motion
                // response. The battlefield overview remains in the minimap.
                final cameraBob = math.sin(
                  elapsed.inMicroseconds / 1000000.0 * 1.35,
                ) * 0.035;
                return PerspectiveCamera(
                  fovRadiansY: 52 * math.pi / 180,
                  position: vm.Vector3(
                    _cameraX,
                    _cameraY + cameraBob,
                    _cameraZ,
                  ),
                  target: vm.Vector3(_lookX, _lookY, _lookZ),
                  fovNear: 0.08,
                  fovFar: 240,
                );
              },
              onTick: _onSceneTick,
              loadingBuilder: (context, progress) => const Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF9BD9C7),
                  ),
                ),
              ),
              children: _buildSceneChildren(snapshot),
            ),
            Positioned(
              left: viewport.maxWidth * 0.48,
              right: side + 158,
              top: compact ? 92 : 104,
              bottom: compact ? 104 : 116,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onPanUpdate: _rotateCamera,
                child: const SizedBox.expand(),
              ),
            ),
            const IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0, 0.18, 0.78, 1],
                    colors: [
                      Color(0x960A1620),
                      Color(0x000A1620),
                      Color(0x000A1620),
                      Color(0xB90A1620),
                    ],
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Stack(
                children: [
                  Positioned(
                    top: 8,
                    left: side,
                    child: _TopLeftHud(
                      time: _clock(snapshot.elapsedSeconds),
                      kills: '${snapshot.blueTeamKills}  :  ${snapshot.redTeamKills}',
                    ),
                  ),
                  Positioned(
                    top: 8,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: _CoreHud(
                        blueHealth: snapshot.blueCoreHealth /
                            snapshot.blueCoreMaxHealth,
                        redHealth: snapshot.redCoreHealth /
                            snapshot.redCoreMaxHealth,
                        blueTowers: snapshot.blueTowersAlive,
                        redTowers: snapshot.redTowersAlive,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: side,
                    child: Row(
                      children: [
                        _MiniMap(snapshot: snapshot),
                        const SizedBox(width: 9),
                        _PauseButton(onTap: widget.onPause),
                      ],
                    ),
                  ),
                  Positioned(
                    left: side,
                    bottom: compact ? 10 : 14,
                    child: _Joystick(
                      moveX: _moveX,
                      moveZ: _moveZ,
                      onMove: _updateJoystick,
                      onRelease: _clearJoystick,
                    ),
                  ),
                  Positioned(
                    left: compact ? 132 : 150,
                    right: compact ? 182 : 208,
                    bottom: compact ? 12 : 16,
                    child: _PlayerHud(snapshot: snapshot),
                  ),
                  Positioned(
                    right: side,
                    bottom: compact ? 10 : 14,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _MatchActionButton(
                          label: 'SKILL',
                          icon: Icons.auto_awesome,
                          size: compact ? 60 : 68,
                          secondary: true,
                          cooldown: snapshot.playerSkillCooldown,
                          onPress: () => setState(() => _skillHeld = true),
                          onRelease: () => setState(() => _skillHeld = false),
                        ),
                        const SizedBox(width: 9),
                        _MatchActionButton(
                          label: 'ATAQUE',
                          icon: Icons.flash_on,
                          size: compact ? 72 : 82,
                          onPress: () =>
                              setState(() => _basicAttackHeld = true),
                          onRelease: () =>
                              setState(() => _basicAttackHeld = false),
                        ),
                      ],
                    ),
                  ),
                  if (!_worldReady)
                    const Positioned.fill(
                      child: IgnorePointer(
                        child: Center(
                          child: Text(
                            'CARREGANDO CAMPO DE BATALHA',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              letterSpacing: 1.7,
                              fontWeight: FontWeight.w800,
                              shadows: [
                                Shadow(
                                  color: Colors.black,
                                  blurRadius: 8,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _TopLeftHud extends StatelessWidget {
  const _TopLeftHud({required this.time, required this.kills});

  final String time;
  final String kills;

  @override
  Widget build(BuildContext context) {
    return _HudPlate(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.timer_outlined, size: 14, color: Color(0xFF9BD9C7)),
          const SizedBox(width: 5),
          Text(
            time,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: 10),
          const Icon(Icons.bolt, size: 14, color: Color(0xFFFFD68E)),
          const SizedBox(width: 3),
          Text(
            kills,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _CoreHud extends StatelessWidget {
  const _CoreHud({
    required this.blueHealth,
    required this.redHealth,
    required this.blueTowers,
    required this.redTowers,
  });

  final double blueHealth;
  final double redHealth;
  final int blueTowers;
  final int redTowers;

  @override
  Widget build(BuildContext context) {
    return _HudPlate(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      child: SizedBox(
        width: 232,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(
                  blueTowers.toString(),
                  style: const TextStyle(
                    color: Color(0xFF9ED4F4),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(child: _CoreBar(value: blueHealth, blue: true)),
                const SizedBox(width: 8),
                Expanded(child: _CoreBar(value: redHealth, blue: false)),
                const SizedBox(width: 6),
                Text(
                  redTowers.toString(),
                  style: const TextStyle(
                    color: Color(0xFFFFA4A4),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            const Text(
              'TORRES  •  NÚCLEOS',
              style: TextStyle(
                color: Color(0xFFCAD9DF),
                fontSize: 8,
                letterSpacing: 1.45,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CoreBar extends StatelessWidget {
  const _CoreBar({required this.value, required this.blue});

  final double value;
  final bool blue;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: SizedBox(
        height: 7,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: Color(0xFF26333D)),
            Align(
              alignment: blue ? Alignment.centerLeft : Alignment.centerRight,
              child: FractionallySizedBox(
                widthFactor: value.clamp(0.0, 1.0).toDouble(),
                child: ColoredBox(
                  color: blue
                      ? const Color(0xFF65B7EA)
                      : const Color(0xFFE36F76),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlayerHud extends StatelessWidget {
  const _PlayerHud({required this.snapshot});

  final MobaMatchSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final health = (snapshot.playerHealth / snapshot.playerMaxHealth)
        .clamp(0.0, 1.0)
        .toDouble();
    final xp = (snapshot.playerXp / snapshot.xpForNextLevel)
        .clamp(0.0, 1.0)
        .toDouble();
    final hero = snapshot.heroId.name.toUpperCase();

    return _HudPlate(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(
                hero,
                style: const TextStyle(
                  color: Color(0xFFF1E4C9),
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.0,
                ),
              ),
              const Spacer(),
              Text(
                'NÍVEL ${snapshot.playerLevel}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(width: 9),
              Text(
                '${snapshot.playerGold.floor()} G',
                style: const TextStyle(
                  color: Color(0xFFFFD68E),
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _Bar(value: health, color: const Color(0xFF69C98A), height: 7),
          const SizedBox(height: 4),
          _Bar(value: xp, color: const Color(0xFF62B8E8), height: 4),
          if (snapshot.playerRespawnSeconds > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'RETORNO ${snapshot.playerRespawnSeconds.toStringAsFixed(1)}s',
                style: const TextStyle(
                  color: Color(0xFFFFD68E),
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.value, required this.color, required this.height});

  final double value;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: SizedBox(
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: Color(0xFF26333D)),
            Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: value.clamp(0.0, 1.0),
                child: ColoredBox(color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Joystick extends StatelessWidget {
  const _Joystick({
    required this.moveX,
    required this.moveZ,
    required this.onMove,
    required this.onRelease,
  });

  final double moveX;
  final double moveZ;
  final ValueChanged<Offset> onMove;
  final VoidCallback onRelease;

  @override
  Widget build(BuildContext context) {
    const size = 112.0;
    const thumb = 38.0;
    return GestureDetector(
      onPanDown: (details) => onMove(details.localPosition),
      onPanUpdate: (details) => onMove(details.localPosition),
      onPanEnd: (_) => onRelease(),
      onPanCancel: onRelease,
      child: SizedBox(
        width: size,
        height: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xA8142029),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0x889BC1C7), width: 1.2),
          ),
          child: Stack(
            children: [
              Center(
                child: Container(
                  width: 74,
                  height: 74,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0x445A7C83)),
                  ),
                ),
              ),
              Positioned(
                left: size / 2 - thumb / 2 + moveX * 35,
                top: size / 2 - thumb / 2 - moveZ * 35,
                child: Container(
                  width: thumb,
                  height: thumb,
                  decoration: BoxDecoration(
                    color: const Color(0xE26A9E9D),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFE1F1E8), width: 1.2),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x55000000),
                        blurRadius: 5,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MatchActionButton extends StatelessWidget {
  const _MatchActionButton({
    required this.label,
    required this.icon,
    required this.size,
    required this.onPress,
    required this.onRelease,
    this.secondary = false,
    this.cooldown = 0,
  });

  final String label;
  final IconData icon;
  final double size;
  final bool secondary;
  final double cooldown;
  final VoidCallback onPress;
  final VoidCallback onRelease;

  @override
  Widget build(BuildContext context) {
    final shape = BeveledRectangleBorder(
      borderRadius: BorderRadius.circular(8),
      side: BorderSide(
        color: secondary
            ? const Color(0xFF9BC2CF)
            : const Color(0xFFFFDA9B),
        width: 1.2,
      ),
    );
    final disabled = secondary && cooldown > 0;
    return GestureDetector(
      onTapDown: (_) => onPress(),
      onTapUp: (_) => onRelease(),
      onTapCancel: onRelease,
      child: Material(
        color: disabled
            ? const Color(0xC32C3842)
            : secondary
                ? const Color(0xD0446878)
                : const Color(0xE0D7A45D),
        shape: shape,
        elevation: 3,
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: size,
          height: size,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: size * 0.29,
                color: secondary
                    ? const Color(0xFFF0F6F0)
                    : const Color(0xFF3F3024),
              ),
              const SizedBox(height: 3),
              Text(
                disabled ? cooldown.toStringAsFixed(0) : label,
                style: TextStyle(
                  color: secondary ? Colors.white : const Color(0xFF3F3024),
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.65,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PauseButton extends StatelessWidget {
  const _PauseButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xA8142029),
      borderRadius: BorderRadius.circular(7),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(7),
        child: const SizedBox(
          width: 38,
          height: 38,
          child: Icon(Icons.pause_rounded, color: Colors.white, size: 21),
        ),
      ),
    );
  }
}

class _MiniMap extends StatelessWidget {
  const _MiniMap({required this.snapshot});

  final MobaMatchSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return _HudPlate(
      padding: const EdgeInsets.all(4),
      child: SizedBox(
        width: 120,
        height: 76,
        child: CustomPaint(painter: _MiniMapPainter(snapshot)),
      ),
    );
  }
}

class _MiniMapPainter extends CustomPainter {
  const _MiniMapPainter(this.snapshot);

  final MobaMatchSnapshot snapshot;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawRRect(
      RRect.fromRectAndRadius(bounds, const Radius.circular(4)),
      Paint()..color = const Color(0xFF14252B),
    );

    Offset project(MobaPoint point) => Offset(
          ((point.x + ArenaWorldCatalog.halfWidth) /
                  (ArenaWorldCatalog.halfWidth * 2)) *
              size.width,
          ((point.z + ArenaWorldCatalog.halfDepth) /
                  (ArenaWorldCatalog.halfDepth * 2)) *
              size.height,
        );

    final lanePaint = Paint()
      ..color = const Color(0xFF65767A)
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke;
    for (final laneX in [-22.5, 0.0, 22.5]) {
      final x = ((laneX + ArenaWorldCatalog.halfWidth) /
              (ArenaWorldCatalog.halfWidth * 2)) *
          size.width;
      final path = Path()
        ..moveTo(x, 0)
        ..cubicTo(x, size.height * 0.34, x, size.height * 0.66, x, size.height);
      canvas.drawPath(path, lanePaint);
    }

    final riverPaint = Paint()
      ..color = const Color(0xFF4D9EC1)
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;
    const riverPoints = <MobaPoint>[
      MobaPoint(-59, -17),
      MobaPoint(-48, -13),
      MobaPoint(-36, -8),
      MobaPoint(-24, -1),
      MobaPoint(-12, 7),
      MobaPoint(0, 15),
      MobaPoint(12, 17),
      MobaPoint(24, 12.5),
      MobaPoint(36, 4.5),
      MobaPoint(48, -6.5),
      MobaPoint(59, -14),
    ];
    final river = Path();
    for (var index = 0; index < riverPoints.length; index++) {
      final point = project(riverPoints[index]);
      if (index == 0) {
        river.moveTo(point.dx, point.dy);
      } else {
        river.lineTo(point.dx, point.dy);
      }
    }
    canvas.drawPath(river, riverPaint);

    for (final tower in snapshot.towers) {
      final paint = Paint()
        ..color = tower.team == MobaTeam.blue
            ? const Color(0xFF75BDEB)
            : const Color(0xFFEF8589);
      canvas.drawRect(
        Rect.fromCenter(center: project(tower.position), width: 4.4, height: 4.4),
        paint,
      );
    }

    for (final minion in snapshot.minions) {
      final paint = Paint()
        ..color = minion.team == MobaTeam.blue
            ? const Color(0xFF9BD8FF)
            : const Color(0xFFFFB2B4);
      canvas.drawCircle(project(minion.position), minion.ranged ? 1.5 : 1.15, paint);
    }

    for (final bot in snapshot.bots.where((bot) => bot.respawnSeconds <= 0)) {
      final paint = Paint()
        ..color = bot.team == MobaTeam.blue
            ? const Color(0xFF65B6EB)
            : const Color(0xFFE36F76);
      canvas.drawCircle(project(bot.position), 2.5, paint);
    }

    canvas.drawCircle(
      project(snapshot.playerPosition),
      3.5,
      Paint()..color = const Color(0xFFFFDE91),
    );
  }

  @override
  bool shouldRepaint(covariant _MiniMapPainter oldDelegate) =>
      oldDelegate.snapshot.elapsedSeconds != snapshot.elapsedSeconds;
}

class _HudPlate extends StatelessWidget {
  const _HudPlate({required this.child, this.padding = EdgeInsets.zero});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xC915222B),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: const Color(0x587CABB0), width: 0.9),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}
