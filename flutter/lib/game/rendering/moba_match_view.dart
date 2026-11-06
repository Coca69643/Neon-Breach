import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_scene/scene.dart' hide Material;
import 'package:vector_math/vector_math.dart' as vm;

import '../match/moba_match_simulation.dart';
import '../physics/arena_physics_runtime.dart';
import '../world/arena_world_catalog.dart';
import 'hero_weapon_socket.dart';

class MobaMatchView extends StatefulWidget {
  const MobaMatchView({
    super.key,
    required this.simulation,
    required this.onRuntimeReady,
    required this.onRuntimeFailed,
    required this.onPause,
    required this.onFinished,
  });

  final MobaMatchSimulation simulation;
  final VoidCallback onRuntimeReady;
  final ValueChanged<String> onRuntimeFailed;
  final VoidCallback onPause;
  final ValueChanged<MobaTeam> onFinished;

  @override
  State<MobaMatchView> createState() => _MobaMatchViewState();
}

class _AmbientNpc {
  const _AmbientNpc({
    required this.id,
    required this.label,
    required this.asset,
    required this.x,
    required this.z,
    required this.patrol,
    required this.phaseOffset,
    required this.dialogue,
  });

  final String id;
  final String label;
  final String asset;
  final double x;
  final double z;
  final List<MobaPoint> patrol;
  final double phaseOffset;
  final String dialogue;
}

class _MobaMatchViewState extends State<MobaMatchView> {
  static const double _worldScale = ArenaWorldCatalog.worldScale;
  static final RingGeometry _teamRingGeometry = RingGeometry(
    innerRadius: 0.82,
    outerRadius: 1.0,
    segments: 24,
  );
  static final UnlitMaterial _blueTeamRingMaterial = UnlitMaterial()
    ..baseColorFactor = vm.Vector4(0.16, 0.62, 0.98, 1);
  static final UnlitMaterial _redTeamRingMaterial = UnlitMaterial()
    ..baseColorFactor = vm.Vector4(0.98, 0.28, 0.30, 1);
  static final RingGeometry _relayRingGeometry = RingGeometry(
    innerRadius: 3.2,
    outerRadius: 3.55,
    segments: 40,
  );
  static final RingGeometry _districtProgressGeometry = RingGeometry(
    innerRadius: 2.42,
    outerRadius: 2.68,
    segments: 32,
  );
  static final RingGeometry _skillFeedbackGeometry = RingGeometry(
    innerRadius: 0.82,
    outerRadius: 1.08,
    segments: 32,
  );
  static final RingGeometry _towerIdentityGeometry = RingGeometry(
    innerRadius: 2.35,
    outerRadius: 2.62,
    segments: 28,
  );
  static final UnlitMaterial _lyraSkillMaterial = UnlitMaterial()
    ..baseColorFactor = vm.Vector4(0.28, 0.94, 0.78, 0.96);
  static final UnlitMaterial _bastionSkillMaterial = UnlitMaterial()
    ..baseColorFactor = vm.Vector4(0.34, 0.72, 1.0, 0.98);
  static final UnlitMaterial _kairoSkillMaterial = UnlitMaterial()
    ..baseColorFactor = vm.Vector4(0.86, 0.52, 1.0, 0.96);
  static final UnlitMaterial _shieldMaterial = UnlitMaterial()
    ..baseColorFactor = vm.Vector4(0.32, 0.78, 1.0, 0.86);
  static final UnlitMaterial _attackFeedbackMaterial = UnlitMaterial()
    ..baseColorFactor = vm.Vector4(1.0, 0.78, 0.35, 0.96);
  static final UnlitMaterial _blueTowerMaterial = UnlitMaterial()
    ..baseColorFactor = vm.Vector4(0.18, 0.62, 0.98, 0.94);
  static final UnlitMaterial _redTowerMaterial = UnlitMaterial()
    ..baseColorFactor = vm.Vector4(0.98, 0.25, 0.27, 0.94);
  static final UnlitMaterial _relayNeutralMaterial = UnlitMaterial()
    ..baseColorFactor = vm.Vector4(0.82, 0.66, 0.36, 0.92);
  static final UnlitMaterial _relayBlueMaterial = UnlitMaterial()
    ..baseColorFactor = vm.Vector4(0.18, 0.62, 0.98, 0.96);
  static final UnlitMaterial _relayRedMaterial = UnlitMaterial()
    ..baseColorFactor = vm.Vector4(0.98, 0.25, 0.27, 0.96);
  static final UnlitMaterial _relayContestedMaterial = UnlitMaterial()
    ..baseColorFactor = vm.Vector4(1.0, 0.78, 0.42, 1.0);
  static const String _terrainAsset = 'assets/world/arena_terrain.glb';

  static const _ambientNpcs = <_AmbientNpc>[
    _AmbientNpc(
      id: 'dispatcher',
      label: 'Central de Operações',
      asset: 'assets/npcs/npc_female_b.glb',
      x: -61.0,
      z: -43.0,
      patrol: [
        MobaPoint(-57.0, -44.0),
        MobaPoint(-53.0, -44.0),
        MobaPoint(-53.0, -35.0),
        MobaPoint(-57.0, -35.0),
      ],
      phaseOffset: 0.0,
      dialogue: 'As três rotas estão ativas. Observe o minimapa antes de avançar.',
    ),
    _AmbientNpc(
      id: 'mechanic',
      label: 'Técnico de Campo',
      asset: 'assets/npcs/npc_male_c.glb',
      x: 66.0,
      z: -43.0,
      patrol: [
        MobaPoint(66.0, -43.0),
        MobaPoint(71.0, -43.0),
        MobaPoint(69.0, -34.0),
        MobaPoint(66.0, -34.0),
      ],
      phaseOffset: 1.15,
      dialogue: 'As passagens laterais permitem contornar os bloqueios da avenida.',
    ),
    _AmbientNpc(
      id: 'gardener',
      label: 'Responsável pelo Parque',
      asset: 'assets/npcs/npc_female_c.glb',
      x: -67.0,
      z: 34.0,
      patrol: [
        MobaPoint(-67.0, 34.0),
        MobaPoint(-58.0, 34.0),
        MobaPoint(-58.0, 43.0),
        MobaPoint(-67.0, 43.0),
      ],
      phaseOffset: 2.3,
      dialogue: 'O canal só pode ser atravessado pelas cinco pontes sinalizadas.',
    ),
    _AmbientNpc(
      id: 'resident',
      label: 'Morador do Distrito',
      asset: 'assets/npcs/npc_male_b.glb',
      x: 64.0,
      z: 34.0,
      patrol: [
        MobaPoint(64.0, 34.0),
        MobaPoint(69.0, 34.0),
        MobaPoint(69.0, 43.0),
        MobaPoint(64.0, 43.0),
      ],
      phaseOffset: 3.45,
      dialogue: 'O reator central muda o ritmo da disputa quando uma equipe o controla.',
    ),
    _AmbientNpc(
      id: 'quartermaster',
      label: 'Coordenador de Suprimentos',
      asset: 'assets/npcs/npc_male_a.glb',
      x: -96.0,
      z: -22.0,
      patrol: [
        MobaPoint(-96.0, -22.0),
        MobaPoint(-90.0, -22.0),
        MobaPoint(-90.0, -18.0),
        MobaPoint(-96.0, -18.0),
      ],
      phaseOffset: 4.6,
      dialogue: 'O Mercado Central abastece a equipe que mantém suas rotas protegidas.',
    ),
    _AmbientNpc(
      id: 'station-agent',
      label: 'Agente Intermodal',
      asset: 'assets/npcs/npc_female_a.glb',
      x: 80.0,
      z: 12.0,
      patrol: [
        MobaPoint(80.0, 12.0),
        MobaPoint(86.0, 12.0),
        MobaPoint(86.0, 16.0),
        MobaPoint(80.0, 16.0),
      ],
      phaseOffset: 5.75,
      dialogue: 'Controlar a Estação Intermodal abre uma rotação mais rápida entre setores.',
    ),
  ];

  late MobaMatchSnapshot _snapshot;
  double _cameraYaw = 0;
  double _cameraPitch = 0.34;
  int? _cameraPointerId;
  Offset? _lastCameraPointer;
  late final List<Widget> _staticSceneChildren = _buildStaticSceneChildren();
  double _moveX = 0;
  double _moveZ = 0;
  double _locomotionRatio = 0;
  bool _basicAttackHeld = false;
  bool _skillHeld = false;
  bool _worldReady = false;
  bool _readySent = false;
  bool _runtimeFailureSent = false;
  Timer? _worldLoadTimeout;
  ArenaPhysicsRuntime? _physicsRuntime;
  bool _finishSent = false;
  String? _activeNpcId;
  late double _cameraX;
  late double _cameraY;
  late double _cameraZ;
  late double _lookX;
  late double _lookY;
  late double _lookZ;

  @override
  void initState() {
    super.initState();
    _snapshot = widget.simulation.snapshot;
    _initialiseCameraRig(_snapshot);
    _worldLoadTimeout = Timer(
      const Duration(seconds: 35),
      _handleWorldLoadTimeout,
    );
    unawaited(_initialisePhysicsRuntime());
  }

  Future<void> _initialisePhysicsRuntime() async {
    try {
      final initial = widget.simulation.snapshot;
      final runtime = await ArenaPhysicsRuntime.create(
        spawn: initial.playerPosition,
        towers: initial.towers,
        covers: initial.covers,
      );
      if (!mounted) {
        runtime.dispose();
        return;
      }
      _physicsRuntime = runtime;
      _markWorldAssetReady('physics');
    } catch (error) {
      if (!mounted || _runtimeFailureSent) return;
      _runtimeFailureSent = true;
      _worldLoadTimeout?.cancel();
      widget.onRuntimeFailed(
        'Não foi possível inicializar a física 3D da arena: $error',
      );
    }
  }

  void _initialiseCameraRig(MobaMatchSnapshot snapshot) {
    final x = snapshot.playerPosition.x * _worldScale;
    final z = snapshot.playerPosition.z * _worldScale;
    final forwardX = math.sin(_cameraYaw);
    final forwardZ = math.cos(_cameraYaw);
    final horizontalDistance =
        9.4 * math.cos(_cameraPitch) * _worldScale;
    final ground = _groundHeight(snapshot.playerPosition) * _worldScale;

    _cameraX = x - forwardX * horizontalDistance;
    _cameraY = ground + (1.25 + 9.4 * math.sin(_cameraPitch)) * _worldScale;
    _cameraZ = z - forwardZ * horizontalDistance;
    _lookX = x + forwardX * 3.0 * _worldScale;
    _lookY = ground + 1.2 * _worldScale;
    _lookZ = z + forwardZ * 3.0;
  }

  void _advanceCameraRig(MobaMatchSnapshot snapshot, double deltaSeconds) {
    final x = snapshot.playerPosition.x * _worldScale;
    final z = snapshot.playerPosition.z * _worldScale;
    final forwardX = math.sin(_cameraYaw);
    final forwardZ = math.cos(_cameraYaw);
    final horizontalDistance =
        9.4 * math.cos(_cameraPitch) * _worldScale;
    final ground = _groundHeight(snapshot.playerPosition) * _worldScale;

    // Camera yaw/pitch are controlled only by the right-side drag zone.
    final desiredX = x - forwardX * horizontalDistance;
    final desiredY = ground + (1.25 + 9.4 * math.sin(_cameraPitch)) * _worldScale;
    final desiredZ = z - forwardZ * horizontalDistance;
    final desiredLookX = x + forwardX * 3.0 * _worldScale;
    final desiredLookY = ground + 1.2 * _worldScale;
    final desiredLookZ = z + forwardZ * 3.0;
    final blend = 1.0 - math.exp(-7.0 * deltaSeconds);

    _cameraX += (desiredX - _cameraX) * blend;
    _cameraY += (desiredY - _cameraY) * blend;
    _cameraZ += (desiredZ - _cameraZ) * blend;
    _lookX += (desiredLookX - _lookX) * blend;
    _lookY += (desiredLookY - _lookY) * blend;
    _lookZ += (desiredLookZ - _lookZ) * blend;
  }

  void _onSceneTick(Duration elapsed, double deltaSeconds) {
    // Do not advance the match clock while the terrain/player model is still
    // loading. This prevents a delayed GPU import from starting a live match
    // with elapsed time or movement already consumed.
    if (!mounted || _runtimeFailureSent || !_worldReady || !_readySent) {
      return;
    }
    // Movement is camera-relative but never feeds back into camera yaw.
    final forwardX = math.sin(_cameraYaw);
    final forwardZ = math.cos(_cameraYaw);
    final rightX = math.cos(_cameraYaw);
    final rightZ = -math.sin(_cameraYaw);
    final worldMoveX = _moveX * rightX + _moveZ * forwardX;
    final worldMoveZ = _moveX * rightZ + _moveZ * forwardZ;
    final previous = _snapshot;
    final physics = _physicsRuntime;
    if (physics != null) {
      final alive = previous.playerHealth > 0 &&
          previous.playerRespawnSeconds <= 0;
      physics.setActive(alive);
      physics.setInput(worldMoveX, worldMoveZ);
      physics.update(deltaSeconds);
      if (alive) {
        widget.simulation.applyPhysicsPlayerPosition(physics.playerPosition);
      }
      if (physics.consumeDashCompletion()) {
        widget.simulation.resolvePhysicsDashAt(physics.playerPosition);
      }
    }

    widget.simulation.step(
      deltaSeconds,
      moveX: worldMoveX,
      moveZ: worldMoveZ,
      basicAttack: _basicAttackHeld,
      castSkill: _skillHeld,
      externalPlayerMovement: physics != null,
    );
    final dashRequest = widget.simulation.consumePhysicsDashRequest();
    if (physics != null && dashRequest != null) {
      physics.triggerDash(dashRequest.x, dashRequest.z);
    }
    if (physics != null) {
      widget.simulation.setPhysicsMovementState(
        moving: physics.grounded && physics.horizontalSpeed > 0.15,
      );
    }
    final next = widget.simulation.snapshot;
    _locomotionRatio = physics?.movementSpeedRatio ??
        (next.playerMoving ? 1.0 : 0.0);
    if (physics != null) {
      // The only legal teleport is the explicit defeated -> respawn transition.
      if (previous.playerRespawnSeconds > 0 &&
          next.playerRespawnSeconds <= 0 &&
          next.playerHealth > 0) {
        physics.teleport(next.playerPosition);
      }
      physics.setActive(
        next.playerHealth > 0 && next.playerRespawnSeconds <= 0,
      );
      physics.syncTowers(next.towers);
      physics.syncCovers(next.covers);
    }
    _advanceCameraRig(next, deltaSeconds);
    setState(() => _snapshot = next);

    if (next.winner != null && !_finishSent) {
      _finishSent = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onFinished(next.winner!);
      });
    }
  }

  void _applyCameraDrag(Offset delta) {
    // Only the dedicated right-side pointer zone changes camera orientation.
    // The left joystick writes _moveX/_moveZ and never mutates camera yaw.
    setState(() {
      _cameraYaw = (_cameraYaw + delta.dx * 0.008).remainder(2 * math.pi);
      _cameraPitch = (_cameraPitch - delta.dy * 0.005)
          .clamp(0.24, 0.68).toDouble();
    });
  }

  void _markWorldAssetReady(String assetKey) {
    if (!mounted || _runtimeFailureSent || _worldReady) return;
    if (!_criticalSceneAssetsLoaded.add(assetKey)) return;
    const requiredAssets = {'terrain', 'player', 'physics'};
    if (!_criticalSceneAssetsLoaded.containsAll(requiredAssets)) return;

    _worldLoadTimeout?.cancel();
    _worldLoadTimeout = null;
    setState(() => _worldReady = true);
    if (_readySent) return;
    _readySent = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onRuntimeReady();
    });
  }

  void _handleWorldLoadTimeout() {
    if (!mounted || _readySent || _runtimeFailureSent) return;
    _runtimeFailureSent = true;
    _worldLoadTimeout = null;
    widget.onRuntimeFailed(
      'O terreno, o modelo do herói ou a física 3D não terminaram de carregar '
      'em 35 segundos. A partida foi interrompida para evitar iniciar com '
      'conteúdo incompleto.',
    );
  }

  final Set<String> _criticalSceneAssetsLoaded = <String>{};

  @override
  void dispose() {
    _worldLoadTimeout?.cancel();
    _physicsRuntime?.dispose();
    _physicsRuntime = null;
    super.dispose();
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
        MobaHeroId.lyra => 'HumanArmature|Female_SwordSlash',
        MobaHeroId.bastion || MobaHeroId.kairo => 'HumanArmature|Man_SwordSlash',
      };

  String _towerAsset(int laneIndex, int tier) {
    const variants = [
      'commercial_low_a.glb', 'commercial_low_b.glb',
      'commercial_low_c.glb', 'commercial_low_d.glb',
    ];
    return 'assets/world/city/${variants[(laneIndex + tier) % variants.length]}';
  }

  double _groundHeight(MobaPoint point) =>
      ArenaWorldCatalog.navigationHeightAt(
        point.x,
        point.z,
        elevation: point.elevation,
      ) + 0.035;

  vm.Vector3 _worldPosition(MobaPoint point, {double heightOffset = 0}) =>
      vm.Vector3(
        point.x,
        _groundHeight(point) + heightOffset,
        point.z,
      );

  vm.Quaternion _facing(MobaTeam team) => vm.Quaternion.axisAngle(
        vm.Vector3(0, 1, 0),
        team == MobaTeam.blue ? 0 : math.pi,
      );

  vm.Quaternion _entityFacing(double facingX, double facingZ) {
    // The bundled Quaternius and Kenney humanoid rigs face local +Z.
    // Do not add a half-turn: +Z movement must make the character face +Z.
    final yaw = math.atan2(facingX, facingZ) + math.pi;
    return vm.Quaternion.axisAngle(vm.Vector3(0, 1, 0), yaw);
  }

  vm.Quaternion _playerFacing(MobaMatchSnapshot snapshot) =>
      _entityFacing(snapshot.playerFacingX, snapshot.playerFacingZ);

  static const _bridges = <(String, double, double)>[
    ('west_outer', -72.0, -2.8),
    ('west', -36.0, 0.8),
    ('central', 0.0, 0.5),
    ('east', 36.0, -0.84),
    ('east_outer', 72.0, 2.28),
  ];

  List<Widget> _buildStaticSceneChildren() {
    return <Widget>[
      SceneModel(
        _terrainAsset,
        key: const ValueKey('match-terrain'),
        name: 'vale_das_coroas_match_terrain',
        onLoaded: (_) => _markWorldAssetReady('terrain'),
      ),
      for (var i = 0; i < ArenaWorldCatalog.trees.length; i++)
        _buildWorldProp(ArenaWorldCatalog.trees[i], 'match-tree-$i'),
      for (var i = 0; i < ArenaWorldCatalog.largeTrees.length; i++)
        _buildWorldProp(ArenaWorldCatalog.largeTrees[i], 'match-large-tree-$i'),
      for (var i = 0; i < ArenaWorldCatalog.bushes.length; i++)
        _buildWorldProp(ArenaWorldCatalog.bushes[i], 'match-bush-$i'),
      for (var i = 0; i < ArenaWorldCatalog.cityProps.length; i++)
        _buildWorldProp(ArenaWorldCatalog.cityProps[i], 'city-detail-$i'),
      for (final building in ArenaWorldCatalog.cityInteriors)
        ..._buildCityInterior(building),
      for (final access in ArenaWorldCatalog.verticalAccesses)
        ..._buildVerticalAccess(access),
      for (final block in ArenaWorldCatalog.commercialBlocks)
        _buildCommercialBlock(block),
      // The three tactical avenues remain the combat backbone.
      for (final laneX in const [-36.0, 0.0, 36.0])
        for (final roadZ in const [-60.0, -40.0, -20.0, 20.0, 40.0, 60.0])
          SceneModel(
            'assets/world/city/road_straight.glb',
            key: ValueKey('street-$laneX-$roadZ'),
            name: 'urban_avenue_${laneX}_$roadZ',
            position: _worldPosition(MobaPoint(laneX, roadZ)),
            rotation: vm.Quaternion.axisAngle(vm.Vector3(0, 1, 0), math.pi / 2),
            scale: vm.Vector3(12.0, 1.0, 20.0),
          ),
      // Cross-streets join side districts to the main avenues.
      for (final roadZ in const [-52.0, -28.0, 28.0, 52.0])
        for (final roadX in const [-88.0, -58.0, -28.0, 28.0, 58.0, 88.0])
          SceneModel(
            'assets/world/city/road_straight.glb',
            key: ValueKey('district-street-$roadX-$roadZ'),
            name: 'district_connector_${roadX}_$roadZ',
            position: _worldPosition(MobaPoint(roadX, roadZ)),
            rotation: vm.Quaternion.axisAngle(vm.Vector3(0, 1, 0), 0),
            scale: vm.Vector3(12.0, 1.0, 20.0),
          ),
      for (final bridge in _bridges)
        SceneModel(
          'assets/world/city/road_crossroad.glb',
          key: ValueKey('crossroad-${bridge.$1}'),
          name: 'canal_crossing_${bridge.$1}',
          position: _worldPosition(MobaPoint(bridge.$2, bridge.$3)),
          scale: vm.Vector3(9.0, 1.0, 10.0),
        ),
      _buildBase(MobaTeam.blue),
      _buildBase(MobaTeam.red),
      SceneModel(
        'assets/world/city/interior_desk.glb',
        key: const ValueKey('central-objective-pedestal'),
        name: 'central_relay_pedestal',
        position: _worldPosition(const MobaPoint(0, 0)),
        scale: vm.Vector3.all(2.7),
      ),
      SceneModel(
        'assets/world/city/interior_computer_screen.glb',
        key: const ValueKey('central-objective-terminal'),
        name: 'central_relay_terminal',
        position: vm.Vector3(
          0,
          _groundHeight(const MobaPoint(0, 0)) + 1.15,
          0,
        ),
        scale: vm.Vector3.all(2.1),
      ),
      for (final bridge in _bridges)
        SceneModel(
          'assets/world/city/road_bridge.glb',
          key: ValueKey('match-bridge-${bridge.$1}'),
          name: 'district_bridge_${bridge.$1}',
          position: _worldPosition(MobaPoint(bridge.$2, bridge.$3)),
          rotation: vm.Quaternion.axisAngle(
            vm.Vector3(0, 1, 0),
            math.pi / 2,
          ),
          scale: vm.Vector3(2.2, 1.0, 1.8),
        ),
    ];
  }

  List<Widget> _buildSceneChildren(MobaMatchSnapshot snapshot) {
    return <Widget>[
      ..._staticSceneChildren,
      SceneMesh(
        name: 'central_relay_control_ring',
        geometry: _relayRingGeometry,
        material: snapshot.centralObjective.contested
            ? _relayContestedMaterial
            : (snapshot.centralObjective.owner == MobaTeam.blue ||
                    (snapshot.centralObjective.owner == null &&
                        snapshot.centralObjective.control > 0)
                ? _relayBlueMaterial
                : (snapshot.centralObjective.owner == MobaTeam.red ||
                        (snapshot.centralObjective.owner == null &&
                            snapshot.centralObjective.control < 0)
                    ? _relayRedMaterial
                    : _relayNeutralMaterial)),
        position: vm.Vector3(
          0,
          _groundHeight(const MobaPoint(0, 0)) + 0.055,
          0,
        ),
      ),
      for (final district in snapshot.districts)
        ..._buildDistrictVisuals(district, snapshot.elapsedSeconds),
      for (final tower in snapshot.towers)
        if (tower.health > 0)
          SceneMesh(
            name: 'tower_identity_${tower.team.name}_${tower.lane.name}_${tower.tier}',
            geometry: _towerIdentityGeometry,
            material: tower.team == MobaTeam.blue
                ? _blueTowerMaterial
                : _redTowerMaterial,
            position: _worldPosition(tower.position, heightOffset: 0.08),
            scale: vm.Vector3.all(
              0.72 + 0.28 * (tower.health / tower.maxHealth),
            ),
          ),
      if (snapshot.playerSkillPulseSeconds > 0)
        SceneMesh(
          name: 'player_skill_feedback_${snapshot.heroId.name}',
          geometry: _skillFeedbackGeometry,
          material: switch (snapshot.heroId) {
            MobaHeroId.lyra => _lyraSkillMaterial,
            MobaHeroId.bastion => _bastionSkillMaterial,
            MobaHeroId.kairo => _kairoSkillMaterial,
          },
          position: _worldPosition(snapshot.playerPosition, heightOffset: 0.09),
          scale: vm.Vector3.all(
            0.72 + (1.0 - snapshot.playerSkillPulseSeconds / 0.82) * 1.05,
          ),
        ),
      if (snapshot.playerSpawnShieldSeconds > 0)
        SceneMesh(
          name: 'player_shield_feedback',
          geometry: _skillFeedbackGeometry,
          material: _shieldMaterial,
          position: _worldPosition(snapshot.playerPosition, heightOffset: 0.12),
          scale: vm.Vector3.all(1.55),
        ),
      if (snapshot.playerHitConfirmSeconds > 0)
        SceneMesh(
          name: 'player_hit_confirm_feedback',
          geometry: _skillFeedbackGeometry,
          material: _attackFeedbackMaterial,
          position: _worldPosition(snapshot.playerPosition, heightOffset: 0.16),
          scale: vm.Vector3.all(
            0.78 + (1.0 - snapshot.playerHitConfirmSeconds / 0.22) * 0.55,
          ),
        ),
      for (final npc in _ambientNpcs) _buildAmbientNpc(npc, snapshot),
      for (final tower in snapshot.towers)
        if (tower.health > 0)
          SceneModel(
          _towerAsset(tower.lane.index, tower.tier),
          key: ValueKey(
            'tower-${tower.team.name}-${tower.lane.name}-${tower.tier}',
          ),
          name:
              '${tower.team.name}_${tower.lane.name}_tower_${tower.tier + 1}',
          position: _worldPosition(tower.position),
          scale: vm.Vector3.all(4.8),
        ),
      for (final cover in snapshot.covers)
        if (!cover.isDestroyed) _buildCover(cover),
      for (final bot in snapshot.bots)
        if (bot.respawnSeconds <= 0) _buildBot(bot),
      for (final minion in snapshot.minions) _buildMinion(minion),
      if (snapshot.playerHealth > 0)
        SceneModel(
          _heroAsset(snapshot.heroId),
          key: const ValueKey('match-player-hero'),
          name: 'player_${snapshot.heroId.id}',
          onLoaded: (modelRoot) {
            _markWorldAssetReady('player');
            unawaited(HeroWeaponSocket.attach(modelRoot, snapshot.heroId));
          },
          position: _worldPosition(snapshot.playerPosition, heightOffset: 0.04),
          rotation: _playerFacing(snapshot),
          scale: vm.Vector3.all(1.0),
          animations: [
            SceneAnimationSpec(
              snapshot.playerAttackSeconds > 0
                  ? _heroAttack(snapshot.heroId)
                  : (snapshot.playerMoving
                      ? _heroWalk(snapshot.heroId)
                      : _heroIdle(snapshot.heroId)),
              loop: snapshot.playerAttackSeconds <= 0,
              speed: snapshot.playerAttackSeconds > 0
                  ? 1.2
                  : (snapshot.playerMoving
                      ? 0.82 + _locomotionRatio * 0.48
                      : 0.78),
            ),
          ],
        ),
    ];
  }

  List<Widget> _buildDistrictVisuals(
    MobaDistrictSnapshot district,
    double elapsedSeconds,
  ) {
    final progress = (district.control.abs() / 100.0)
        .clamp(0.0, 1.0)
        .toDouble();
    final pulse = district.contested
        ? 0.07 * math.sin(elapsedSeconds * 7.5)
        : 0.0;
    final material = district.contested
        ? _relayContestedMaterial
        : district.owner == MobaTeam.blue
            ? _relayBlueMaterial
            : district.owner == MobaTeam.red
                ? _relayRedMaterial
                : (district.control > 0
                    ? _relayBlueMaterial
                    : (district.control < 0
                        ? _relayRedMaterial
                        : _relayNeutralMaterial));
    final position = vm.Vector3(
      district.position.x,
      _groundHeight(district.position) + 0.07,
      district.position.z,
    );
    return [
      SceneMesh(
        name: 'district_control_${district.id}',
        geometry: _relayRingGeometry,
        material: material,
        position: position,
        scale: vm.Vector3.all(0.86 + progress * 0.22 + pulse),
      ),
      SceneMesh(
        name: 'district_capture_progress_${district.id}',
        geometry: _districtProgressGeometry,
        material: material,
        position: vm.Vector3(
          district.position.x,
          _groundHeight(district.position) + 0.085,
          district.position.z,
        ),
        scale: vm.Vector3.all(0.76 + progress * 0.32 + pulse),
      ),
      SceneModel(
        'assets/world/city/interior_computer_screen.glb',
        key: ValueKey('district-console-${district.id}'),
        name: 'district-console-${district.id}',
        position: _worldPosition(district.position, heightOffset: 0.08),
        scale: vm.Vector3.all(1.25),
      ),
    ];
  }

  Widget _buildBase(MobaTeam team) {
    final point = MobaPoint(0, team == MobaTeam.blue ? -64.0 : 64.0);
    return SceneModel(
      team == MobaTeam.blue
          ? 'assets/world/city/commercial_building_a.glb'
          : 'assets/world/city/commercial_building_e.glb',
      key: ValueKey('match-base-${team.name}'),
      name: '${team.name}_urban_command_base',
      position: _worldPosition(point),
      rotation: _facing(team),
      scale: vm.Vector3.all(5.0),
    );
  }

  Widget _buildCommercialBlock((String, double, double, double) block) {
    return SceneModel(
      'assets/world/city/${block.$1}',
      key: ValueKey('city-block-${block.$1}-${block.$2}-${block.$3}'),
      name: 'city_block_${block.$1.replaceAll('.', '_')}',
      position: _worldPosition(MobaPoint(block.$2, block.$3)),
      scale: vm.Vector3.all(block.$4),
    );
  }

  List<Widget> _buildCityInterior((String, double, double) building) {
    final id = building.$1, x = building.$2, z = building.$3;
    final hasVerticalAccess = ArenaWorldCatalog.verticalAccesses.any(
      (access) => access.id == id,
    );
    final ground = _groundHeight(MobaPoint(x, z));
    const halfWidth = ArenaWorldCatalog.roomHalfWidth;
    const halfDepth = ArenaWorldCatalog.roomHalfDepth;
    const doorHalfWidth = ArenaWorldCatalog.roomDoorHalfWidth;
    const wallHeightScale = 2.8;
    const wallThicknessScale = 1.0;
    vm.Vector3 p(double px, double py, double pz) =>
        vm.Vector3(px, ground + py, pz);
    vm.Quaternion yaw(double angle) =>
        vm.Quaternion.axisAngle(vm.Vector3(0, 1, 0), angle);
    final segmentHalf = (halfWidth - doorHalfWidth) * 0.5;
    final segmentOffset = doorHalfWidth + segmentHalf;
    final deskZ = hasVerticalAccess ? z - 2.4 : z + 2.5;
    final chairZ = hasVerticalAccess ? z - 1.8 : z + 2.0;
    final screenZ = hasVerticalAccess ? z - 1.8 : z + 2.0;
    final benchZ = hasVerticalAccess ? z - 4.2 : z - 3.0;

    return [
      SceneModel('assets/world/city/interior_floor.glb',
        key: ValueKey('interior-floor-$id'), name: 'interior_floor_$id',
        position: p(x - halfWidth, 0.02, z + halfDepth),
        scale: vm.Vector3(halfWidth * 2, 1, halfDepth * 2)),
      SceneModel('assets/world/city/interior_wall_window.glb',
        key: ValueKey('interior-back-$id'), name: 'interior_back_wall_$id',
        position: p(x - halfWidth, 0, z + halfDepth),
        scale: vm.Vector3(halfWidth * 2, wallHeightScale, wallThicknessScale)),
      SceneModel('assets/world/city/interior_wall.glb',
        key: ValueKey('interior-left-$id'), name: 'interior_left_wall_$id',
        position: p(x - halfWidth, 0, z), rotation: yaw(math.pi / 2),
        scale: vm.Vector3(halfDepth * 2, wallHeightScale, wallThicknessScale)),
      SceneModel('assets/world/city/interior_wall.glb',
        key: ValueKey('interior-right-$id'), name: 'interior_right_wall_$id',
        position: p(x + halfWidth, 0, z), rotation: yaw(-math.pi / 2),
        scale: vm.Vector3(halfDepth * 2, wallHeightScale, wallThicknessScale)),
      for (final sign in const [-1.0, 1.0])
        SceneModel('assets/world/city/interior_wall.glb',
          key: ValueKey('interior-front-$id-$sign'),
          name: 'interior_front_wall_$id-$sign',
          position: p(x + sign * segmentOffset, 0, z - halfDepth),
          scale: vm.Vector3(segmentHalf * 2, wallHeightScale, wallThicknessScale)),
      SceneModel('assets/world/city/interior_doorway_wide.glb',
        key: ValueKey('interior-door-$id'), name: 'interior_entry_$id',
        position: p(x, 0, z - halfDepth),
        scale: vm.Vector3(doorHalfWidth * 2, wallHeightScale, wallThicknessScale)),
      SceneModel('assets/world/city/interior_desk.glb',
        key: ValueKey('interior-desk-$id'), name: 'interior_service_desk_$id',
        position: p(hasVerticalAccess ? x - 6.0 : x - 5.2, 0, deskZ),
        scale: vm.Vector3(1.6, 1.05, 1.05)),
      SceneModel('assets/world/city/interior_chair.glb',
        key: ValueKey('interior-chair-$id'), name: 'interior_chair_$id',
        position: p(x + 1.6, 0, chairZ), scale: vm.Vector3.all(1.0)),
      SceneModel('assets/world/city/interior_computer_screen.glb',
        key: ValueKey('interior-screen-$id'), name: 'interior_terminal_$id',
        position: p(x - 0.8, 0.8, screenZ), scale: vm.Vector3.all(1.0)),
      SceneModel('assets/world/city/interior_bench.glb',
        key: ValueKey('interior-bench-$id'), name: 'interior_cover_bench_$id',
        position: p(x + 3.0, 0, benchZ), scale: vm.Vector3(1.8, 0.9, 0.9)),
      if (id == 'west_south')
        SceneModel(
          'assets/world/city/interior_computer_screen.glb',
          key: const ValueKey('interior-ops-wall-terminal'),
          name: 'operations_wall_terminal',
          position: p(x + 4.0, 1.0, z + 2.7),
          scale: vm.Vector3.all(1.0),
        ),
      if (id == 'east_south')
        SceneModel(
          'assets/world/city/interior_trashcan.glb',
          key: const ValueKey('interior-workshop-bin'),
          name: 'workshop_service_bin',
          position: p(x + 4.4, 0, z + 2.7),
          scale: vm.Vector3.all(0.9),
        ),
      if (id == 'west_north') ...[
        SceneModel(
          'assets/world/city/city_planter.glb',
          key: const ValueKey('interior-park-planter'),
          name: 'park_information_planter',
          position: p(x - 4.4, 0, z + 2.7),
          scale: vm.Vector3.all(1.0),
        ),
        SceneModel(
          'assets/world/city/interior_plant.glb',
          key: const ValueKey('interior-park-plant'),
          name: 'park_information_plant',
          position: p(x + 4.1, 0, z + 2.8),
          scale: vm.Vector3.all(1.0),
        ),
      ],
      if (id == 'east_north') ...[
        SceneModel(
          'assets/world/city/interior_plant.glb',
          key: const ValueKey('interior-community-plant'),
          name: 'community_room_plant',
          position: p(x - 4.2, 0, z + 2.8),
          scale: vm.Vector3.all(1.0),
        ),
        SceneModel(
          'assets/world/city/interior_bench.glb',
          key: const ValueKey('interior-community-seat'),
          name: 'community_room_seat',
          position: p(x + 3.3, 0, z + 2.8),
          scale: vm.Vector3(1.5, 0.9, 0.9),
        ),
      ],
      if (id == 'west_depot' || id == 'east_depot')
        SceneModel(
          'assets/world/city/interior_trashcan.glb',
          key: ValueKey('service-depot-bin-$id'),
          name: 'service_depot_storage_detail_$id',
          position: p(x + (id == 'west_depot' ? 7.0 : -7.0), 0, z + 3.4),
          scale: vm.Vector3.all(0.9),
        ),
    ];
  }

  List<Widget> _buildVerticalAccess(ArenaVerticalAccess access) {
    final base = ArenaWorldCatalog.heightAt(access.x, access.z) + 0.035;
    final top = base + ArenaVerticalAccess.upperHeight;
    final railYaw = vm.Quaternion.axisAngle(
      vm.Vector3(0, 1, 0),
      math.pi / 2,
    );
    return [
      SceneModel(
        'assets/world/city/interior_stairs.glb',
        key: ValueKey('mezzanine-stairs-${access.id}'),
        name: '${access.id}_mezzanine_stairs',
        position: vm.Vector3(
          access.rampStartX,
          base,
          access.z + ArenaVerticalAccess.corridorMaxOffset,
        ),
        scale: vm.Vector3(2.75, 2.5, 2.9),
      ),
      SceneModel(
        'assets/world/city/interior_floor.glb',
        key: ValueKey('mezzanine-floor-${access.id}'),
        name: '${access.id}_upper_walkway',
        position: vm.Vector3(
          access.x,
          top,
          access.z + ArenaVerticalAccess.corridorMaxOffset,
        ),
        scale: vm.Vector3(
          ArenaVerticalAccess.platformLength,
          1,
          ArenaVerticalAccess.platformDepth,
        ),
      ),
      SceneModel(
        'assets/world/city/interior_wall.glb',
        key: ValueKey('mezzanine-back-rail-${access.id}'),
        name: '${access.id}_upper_back_rail',
        position: vm.Vector3(
          access.x,
          top,
          access.z + ArenaVerticalAccess.corridorMaxOffset,
        ),
        scale: vm.Vector3(5.0, 0.35, 0.65),
      ),
      SceneModel(
        'assets/world/city/interior_wall.glb',
        key: ValueKey('mezzanine-side-rail-${access.id}'),
        name: '${access.id}_upper_side_rail',
        position: vm.Vector3(
          access.platformEndX,
          top,
          access.z + ArenaVerticalAccess.corridorMaxOffset,
        ),
        rotation: railYaw,
        scale: vm.Vector3(2.3, 0.35, 0.65),
      ),
      SceneModel(
        'assets/world/city/interior_wall.glb',
        key: ValueKey('mezzanine-front-rail-${access.id}'),
        name: '${access.id}_upper_front_rail',
        position: vm.Vector3(
          access.x + 0.7,
          top,
          access.z + ArenaVerticalAccess.corridorMinOffset,
        ),
        scale: vm.Vector3(4.3, 0.35, 0.65),
      ),
    ];
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

  Widget _buildCover(MobaCoverSnapshot cover) {
    final isFence = cover.variant == 'fence';
    return SceneModel(
      isFence
          ? 'assets/world/city/construction_fence.glb'
          : 'assets/world/city/construction_barrier.glb',
      key: ValueKey('match-cover-${cover.id}'),
      name: 'destructible_cover_${cover.id}',
      position: _worldPosition(cover.position, heightOffset: 0.025),
      scale: vm.Vector3.all(isFence ? 1.05 : 1.35),
    );
  }

  Widget _teamRing(MobaTeam team) => SceneMesh(
        name: 'team_identity_ring_${team.name}',
        geometry: _teamRingGeometry,
        material: team == MobaTeam.blue
            ? _blueTeamRingMaterial
            : _redTeamRingMaterial,
        position: vm.Vector3(0, 0.025, 0),
      );

  String _npcAsset(MobaNpcVisualId visualId) => switch (visualId) {
        MobaNpcVisualId.maleA => 'assets/npcs/npc_male_a.glb',
        MobaNpcVisualId.femaleA => 'assets/npcs/npc_female_a.glb',
        MobaNpcVisualId.maleB => 'assets/npcs/npc_male_b.glb',
        MobaNpcVisualId.femaleB => 'assets/npcs/npc_female_b.glb',
        MobaNpcVisualId.maleC => 'assets/npcs/npc_male_c.glb',
        MobaNpcVisualId.femaleC => 'assets/npcs/npc_female_c.glb',
      };

  Widget _buildBot(MobaBotSnapshot bot) {
    return SceneModel(
      _npcAsset(bot.visualId),
      key: ValueKey('match-bot-${bot.id}'),
      name: bot.id,
      position: _worldPosition(bot.position, heightOffset: 0.03),
      rotation: _entityFacing(bot.facingX, bot.facingZ),
      scale: vm.Vector3.all(0.98),
      animations: [
        SceneAnimationSpec(
          bot.attackSeconds > 0
              ? 'attack-melee-right'
              : (bot.moving ? 'walk' : 'idle'),
          loop: bot.attackSeconds <= 0,
          speed: bot.attackSeconds > 0
              ? 1.0
              : (bot.moving ? 0.98 : 0.82),
        ),
      ],
      children: [_teamRing(bot.team)],
    );
  }

  Widget _buildMinion(MobaMinionSnapshot minion) {
    final scale = minion.ranged ? 0.94 : 1.02;
    return SceneModel(
      _npcAsset(minion.visualId),
      key: ValueKey('match-minion-${minion.id}'),
      name:
          '${minion.team.name}_${minion.lane.name}_minion_${minion.id}',
      position: _worldPosition(minion.position, heightOffset: 0.02),
      rotation: _entityFacing(minion.facingX, minion.facingZ),
      scale: vm.Vector3.all(scale),
      animations: [
        SceneAnimationSpec(
          minion.attackSeconds > 0
              ? (minion.ranged ? 'holding-both-shoot' : 'attack-melee-right')
              : (minion.moving ? 'walk' : 'idle'),
          loop: minion.attackSeconds <= 0,
          speed: minion.attackSeconds > 0
              ? 1.0
              : (minion.moving ? (minion.ranged ? 0.92 : 1.0) : 0.82),
        ),
      ],
      children: [_teamRing(minion.team)],
    );
  }

  ({
    MobaPoint position,
    bool moving,
    double facingX,
    double facingZ,
  }) _ambientNpcPose(
    _AmbientNpc npc,
    double elapsedSeconds, {
    bool stopped = false,
  }) {
    const travelSeconds = 3.2;
    const pauseSeconds = 1.8;
    const segmentSeconds = travelSeconds + pauseSeconds;
    final route = npc.patrol;
    if (route.length < 2) {
      return (
        position: MobaPoint(npc.x, npc.z),
        moving: false,
        facingX: 0.0,
        facingZ: 1.0,
      );
    }

    final cycleSeconds = segmentSeconds * route.length;
    final phase = (elapsedSeconds + npc.phaseOffset) % cycleSeconds;
    final segment = (phase / segmentSeconds).floor();
    final segmentPhase = phase - segment * segmentSeconds;
    final from = route[segment];
    final to = route[(segment + 1) % route.length];
    final dx = to.x - from.x;
    final dz = to.z - from.z;

    if (segmentPhase >= travelSeconds || stopped) {
      final t = segmentPhase >= travelSeconds
          ? 1.0
          : (segmentPhase / travelSeconds).clamp(0.0, 1.0).toDouble();
      return (
        position: MobaPoint(
          from.x + dx * t,
          from.z + dz * t,
          elevation: from.elevation,
        ),
        moving: false,
        facingX: dx,
        facingZ: dz,
      );
    }

    final t = (segmentPhase / travelSeconds).clamp(0.0, 1.0).toDouble();
    return (
      position: MobaPoint(
        from.x + dx * t,
        from.z + dz * t,
        elevation: from.elevation,
      ),
      moving: true,
      facingX: dx,
      facingZ: dz,
    );
  }

  Widget _buildAmbientNpc(_AmbientNpc npc, MobaMatchSnapshot snapshot) {
    final activeNpc = _nearestAmbientNpc(
      snapshot.playerPosition,
      snapshot.elapsedSeconds,
    );
    final interacting = activeNpc?.id == npc.id && _activeNpcId == npc.id;
    final pose = _ambientNpcPose(
      npc,
      snapshot.elapsedSeconds,
      stopped: interacting,
    );
    return SceneModel(
      npc.asset,
      key: ValueKey('ambient-npc_${npc.id}'),
      name: 'ambient_npc_${npc.id}',
      position: _worldPosition(pose.position, heightOffset: 0.015),
      rotation: _entityFacing(pose.facingX, pose.facingZ),
      scale: vm.Vector3.all(0.96),
      animations: [
        SceneAnimationSpec(
          interacting
              ? 'emote-yes'
              : (pose.moving ? 'walk' : 'idle'),
          loop: !interacting,
          speed: interacting ? 1.0 : (pose.moving ? 0.92 : 0.84),
        ),
      ],
    );
  }

  _AmbientNpc? _nearestAmbientNpc(
    MobaPoint player,
    double elapsedSeconds,
  ) {
    _AmbientNpc? nearest;
    var nearestDistance = 4.8;
    for (final npc in _ambientNpcs) {
      final position = _ambientNpcPose(npc, elapsedSeconds).position;
      final distance = player.distanceTo(position);
      if (distance <= nearestDistance) {
        nearest = npc;
        nearestDistance = distance;
      }
    }
    return nearest;
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
        final nearbyNpc = _nearestAmbientNpc(
          snapshot.playerPosition,
          snapshot.elapsedSeconds,
        );
        final showNpcDialogue =
            nearbyNpc != null && _activeNpcId == nearbyNpc.id;
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
              environmentIntensity: 1.18,
              exposure: 1.04,
              cameraBuilder: (elapsed) {
                // Smoothed trailing perspective with a restrained motion
                // response. The battlefield overview remains in the minimap.
                final gait = _locomotionRatio.clamp(0.0, 1.25).toDouble();
                final cameraBob = math.sin(
                  elapsed.inMicroseconds / 1000000.0 * (2.6 + gait * 3.2),
                ) * 0.028 * gait * _worldScale;
                return PerspectiveCamera(
                  fovRadiansY: 49 * math.pi / 180,
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
              children: [
                SceneNode(
                  name: 'scaled_battlefield_root',
                  scale: vm.Vector3.all(_worldScale),
                  children: _buildSceneChildren(snapshot),
                ),
              ],
            ),
            Positioned(
              left: viewport.maxWidth * 0.42,
              right: side + 8,
              top: compact ? 88 : 96,
              bottom: compact ? 104 : 112,
              child: Listener(
                // Camera drag should receive only empty-space gestures in
                // its dedicated zone, never pointer events from HUD buttons,
                // minimap controls or NPC dialogue layered above it.
                behavior: HitTestBehavior.opaque,
                onPointerDown: (event) {
                  if (event.position.dx < viewport.maxWidth * 0.42) return;
                  _cameraPointerId = event.pointer;
                  _lastCameraPointer = event.position;
                },
                onPointerMove: (event) {
                  if (event.pointer != _cameraPointerId) return;
                  final previous = _lastCameraPointer;
                  if (previous == null) return;
                  _lastCameraPointer = event.position;
                  _applyCameraDrag(event.position - previous);
                },
                onPointerUp: (event) {
                  if (event.pointer == _cameraPointerId) {
                    _cameraPointerId = null;
                    _lastCameraPointer = null;
                  }
                },
                onPointerCancel: (event) {
                  if (event.pointer == _cameraPointerId) {
                    _cameraPointerId = null;
                    _lastCameraPointer = null;
                  }
                },
                child: const SizedBox.expand(),
              ),
            ),
            Positioned(
              right: side + 42,
              top: viewport.maxHeight * 0.43,
              child: const IgnorePointer(
                child: Opacity(
                  opacity: 0.28,
                  child: Icon(
                    Icons.threesixty,
                    size: 24,
                    color: Colors.white,
                  ),
                ),
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
                    top: 52,
                    left: side,
                    child: snapshot.selectedTarget == null
                        ? const SizedBox.shrink()
                        : _TargetHud(target: snapshot.selectedTarget!),
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
                    top: 64,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: _ObjectiveHud(
                        objective: snapshot.centralObjective,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 96,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: _DistrictHud(districts: snapshot.districts),
                    ),
                  ),
                  if (nearbyNpc != null)
                    Positioned(
                      left: side,
                      top: 108,
                      child: _NpcPrompt(
                        label: nearbyNpc.label,
                        onTap: () => setState(() => _activeNpcId = nearbyNpc.id),
                      ),
                    ),
                  if (showNpcDialogue)
                    Positioned(
                      left: viewport.maxWidth * 0.28,
                      right: viewport.maxWidth * 0.28,
                      bottom: compact ? 94 : 108,
                      child: _NpcDialogue(
                        npc: nearbyNpc,
                        onClose: () => setState(() => _activeNpcId = null),
                      ),
                    ),
                  Positioned(
                    top: 8,
                    right: side,
                    child: Row(
                      children: [
                        _MiniMap(
                          snapshot: snapshot,
                          onPing: (point) {
                            if (!widget.simulation.issueTeamPing(point)) return;
                            setState(() {
                              _snapshot = widget.simulation.snapshot;
                            });
                          },
                        ),
                        const SizedBox(width: 9),
                        _PauseButton(onTap: widget.onPause),
                      ],
                    ),
                  ),
                  Positioned(
                    left: viewport.maxWidth * 0.56,
                    top: viewport.maxHeight * 0.48,
                    child: IgnorePointer(
                      child: AnimatedOpacity(
                        opacity: snapshot.playerHitConfirmSeconds > 0 ? 1 : 0,
                        duration: const Duration(milliseconds: 55),
                        child: const Icon(
                          Icons.close_rounded,
                          size: 30,
                          color: Color(0xFFFFE6A4),
                          shadows: [
                            Shadow(color: Color(0xAAFFE4A0), blurRadius: 12),
                          ],
                        ),
                      ),
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
                        _TargetLockButton(
                          size: compact ? 48 : 52,
                          onTap: () {
                            widget.simulation.cyclePlayerTarget();
                            setState(() => _snapshot = widget.simulation.snapshot);
                          },
                        ),
                        const SizedBox(width: 7),
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

class _ObjectiveHud extends StatelessWidget {
  const _ObjectiveHud({required this.objective});

  final MobaObjectiveSnapshot objective;

  @override
  Widget build(BuildContext context) {
    final progress = (objective.control.abs() / 100)
        .clamp(0.0, 1.0)
        .toDouble();
    final blueControl = objective.control >= 0;
    final owner = objective.owner;
    final Color controlColor = owner == MobaTeam.blue
        ? const Color(0xFF6BBDEB)
        : owner == MobaTeam.red
            ? const Color(0xFFED7A80)
            : blueControl
                ? const Color(0xFF6BBDEB)
                : const Color(0xFFED7A80);
    final String status = objective.contested
        ? 'DISPUTADO'
        : owner == MobaTeam.blue
            ? 'AZUL  •  +12% DANO'
            : owner == MobaTeam.red
                ? 'VERMELHO  •  +12% DANO'
                : progress <= 0.001
                    ? 'NEUTRO'
                    : blueControl
                        ? 'CAPTURANDO AZUL'
                        : 'CAPTURANDO VERMELHO';

    return _HudPlate(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: SizedBox(
        width: 184,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.radar_rounded,
                  color: Color(0xFFD6E8EA),
                  size: 11,
                ),
                const SizedBox(width: 5),
                const Text(
                  'REATOR CENTRAL',
                  style: TextStyle(
                    color: Color(0xFFE4EFF0),
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.15,
                  ),
                ),
                const Spacer(),
                Text(
                  status,
                  style: TextStyle(
                    color: objective.contested
                        ? const Color(0xFFFFD68E)
                        : controlColor,
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: SizedBox(
                height: 4,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    const ColoredBox(color: Color(0xFF26333D)),
                    Align(
                      alignment: blueControl
                          ? Alignment.centerLeft
                          : Alignment.centerRight,
                      child: FractionallySizedBox(
                        widthFactor: progress,
                        child: ColoredBox(color: controlColor),
                      ),
                    ),
                    if (objective.contested)
                      const Center(
                        child: SizedBox(
                          width: 28,
                          child: ColoredBox(color: Color(0xFFFFD68E)),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DistrictHud extends StatelessWidget {
  const _DistrictHud({required this.districts});
  final List<MobaDistrictSnapshot> districts;

  @override
  Widget build(BuildContext context) {
    final blue = districts.where((item) => item.owner == MobaTeam.blue).length;
    final red = districts.where((item) => item.owner == MobaTeam.red).length;
    final neutral = districts.length - blue - red;
    return _HudPlate(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.flag_outlined, size: 10, color: Color(0xFFD6E8EA)),
        const SizedBox(width: 5),
        Text('DISTRITOS  $blue AZUL  •  $red VERMELHO  •  $neutral LIVRE',
          style: const TextStyle(color: Color(0xFFE4EFF0), fontSize: 8,
            fontWeight: FontWeight.w900, letterSpacing: 0.55)),
      ]),
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
              padding: const EdgeInsets.only(top: 5),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.close_rounded,
                    color: Color(0xFFFF7777),
                    size: 12,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'ELIMINADO  •  RETORNO ${snapshot.playerRespawnSeconds.toStringAsFixed(1)}s',
                    style: const TextStyle(
                      color: Color(0xFFFFA0A0),
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.35,
                    ),
                  ),
                ],
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

class _TargetHud extends StatelessWidget {
  const _TargetHud({required this.target});

  final MobaTargetSnapshot target;

  @override
  Widget build(BuildContext context) {
    final fraction = (target.health / target.maxHealth).clamp(0.0, 1.0);
    return Container(
      width: 154,
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xD9162028),
        border: Border.all(color: const Color(0xAAE3B47A), width: 1),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.gps_fixed, size: 12, color: Color(0xFFFFD68E)),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  target.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.7,
                  ),
                ),
              ),
              Text(
                target.kind == 'HERO' ? 'HERÓI' : 'TROPA',
                style: const TextStyle(
                  color: Color(0xFFB8C7CD),
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 4,
              backgroundColor: const Color(0xFF35424A),
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFFE16C62),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TargetLockButton extends StatelessWidget {
  const _TargetLockButton({required this.size, required this.onTap});

  final double size;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final shape = BeveledRectangleBorder(
      borderRadius: BorderRadius.circular(7),
      side: const BorderSide(color: Color(0xFF9BC2CF), width: 1.1),
    );
    return Material(
      color: const Color(0xD02B414B),
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        customBorder: shape,
        child: SizedBox(
          width: size,
          height: size,
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.gps_fixed, size: 17, color: Colors.white),
              SizedBox(height: 2),
              Text(
                'ALVO',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 8,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.45,
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
  const _MiniMap({
    required this.snapshot,
    required this.onPing,
  });

  final MobaMatchSnapshot snapshot;
  final ValueChanged<MobaPoint> onPing;

  @override
  Widget build(BuildContext context) {
    return _HudPlate(
      padding: const EdgeInsets.all(4),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (details) {
          const mapWidth = 120.0;
          const mapHeight = 76.0;
          final x = (details.localPosition.dx / mapWidth) *
                  (ArenaWorldCatalog.halfWidth * 2) -
              ArenaWorldCatalog.halfWidth;
          final z = (details.localPosition.dy / mapHeight) *
                  (ArenaWorldCatalog.halfDepth * 2) -
              ArenaWorldCatalog.halfDepth;
          onPing(MobaPoint(x, z));
        },
        child: SizedBox(
          width: 120,
          height: 76,
          child: CustomPaint(painter: _MiniMapPainter(snapshot)),
        ),
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
    for (final laneX in [-36.0, 0.0, 36.0]) {
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
    // Keep the tactical map aligned with ArenaWorldCatalog's actual
    // canal centreline rather than drawing a second, unrelated S-curve.
    const riverPoints = <MobaPoint>[
      MobaPoint(-90, 0),
      MobaPoint(-60, 0.2),
      MobaPoint(-30, -0.15),
      MobaPoint(0, 0.1),
      MobaPoint(30, -0.1),
      MobaPoint(60, 0.15),
      MobaPoint(90, 0),
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

    // Mint markers identify the four accessible indoor service points.
    for (final building in ArenaWorldCatalog.cityInteriors) {
      final marker = project(MobaPoint(building.$2, building.$3));
      canvas.drawCircle(
        marker,
        3.2,
        Paint()..color = const Color(0xFF83E0C5),
      );
      canvas.drawCircle(
        marker,
        1.25,
        Paint()..color = const Color(0xFF17342F),
      );
    }

    final ping = snapshot.teamPingTarget;
    if (ping != null && snapshot.teamPingSeconds > 0) {
      final center = project(ping);
      final pulse = (snapshot.teamPingSeconds % 1.0);
      final radius = 3.5 + (1.0 - pulse) * 3.8;
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = const Color(0xFFFFD58A).withValues(alpha: 0.92 * pulse)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
      canvas.drawCircle(
        center,
        2.2,
        Paint()..color = const Color(0xFFFFD58A),
      );
    }

    for (final tower in snapshot.towers.where((item) => item.health > 0)) {
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


class _NpcPrompt extends StatelessWidget {
  const _NpcPrompt({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xE51A2C34),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.chat_bubble_outline, size: 16,
                  color: Color(0xFF8BDCC7)),
              const SizedBox(width: 7),
              Text(
                'CONVERSAR  ·  $label',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.7,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NpcDialogue extends StatelessWidget {
  const _NpcDialogue({required this.npc, required this.onClose});

  final _AmbientNpc npc;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 11, 10, 10),
      decoration: BoxDecoration(
        color: const Color(0xED15232B),
        border: Border.all(color: const Color(0xFF6CBFAE), width: 1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(Icons.forum_outlined, color: Color(0xFF8BDCC7), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(npc.label,
                    style: const TextStyle(
                      color: Color(0xFF8BDCC7),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    )),
                const SizedBox(height: 4),
                Text(npc.dialogue,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      height: 1.25,
                    )),
              ],
            ),
          ),
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close, color: Colors.white70, size: 18),
            visualDensity: VisualDensity.compact,
            tooltip: 'Fechar conversa',
          ),
        ],
      ),
    );
  }
}
