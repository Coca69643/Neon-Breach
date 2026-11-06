import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_scene/physics.dart';
import 'package:flutter_scene_rapier/flutter_scene_rapier.dart';
import 'package:vector_math/vector_math.dart' as vm;

import '../match/moba_match_simulation.dart';
import '../world/arena_world_catalog.dart';

/// Rapier-backed character motion and collision geometry for the MOBA arena.
///
/// The simulation stores logical X/Z coordinates. This runtime owns the
/// physical capsule and static collision world; it is the only authority for
/// the player's position while the match view is active.
class ArenaPhysicsRuntime {
  ArenaPhysicsRuntime._(
    this._world,
    this._playerBody,
    this._playerPose,
    this._playerCollider,
    this._staticBody,
  );

  static const double fixedStep = 1.0 / 60.0;
  static const double gravity = 24.0;
  static const double moveSpeed = 5.6;
  static const double acceleration = 24.0;
  static const double deceleration = 32.0;
  static const double capsuleRadius = 0.38;
  static const double capsuleHalfHeight = 0.50;
  static const double footOffset = capsuleRadius + capsuleHalfHeight;
  static const double _terrainCellSize = 2.5;

  final RapierWorld _world;
  final int _playerBody;
  final SimplePoseTarget _playerPose;
  final int _playerCollider;
  final int _staticBody;
  final Map<String, int> _towerColliders = {};
  final Map<String, int> _coverColliders = {};

  double _accumulator = 0;
  double _moveX = 0;
  double _moveZ = 0;
  double _velocityX = 0;
  double _velocityZ = 0;
  double _verticalVelocity = 0;
  bool _active = true;
  bool _grounded = false;
  bool _disposed = false;
  bool _slidingDownSlope = false;

  bool get grounded => _grounded;
  bool get slidingDownSlope => _slidingDownSlope;
  double get verticalVelocity => _verticalVelocity;
  double get horizontalSpeed =>
      math.sqrt(_velocityX * _velocityX + _velocityZ * _velocityZ);

  MobaPoint get playerPosition {
    final x = _playerPose.translation.x;
    final z = _playerPose.translation.z;
    final footY = _playerPose.translation.y - footOffset;
    final groundY = ArenaWorldCatalog.navigationHeightAt(x, z);
    return MobaPoint(x, z, elevation: footY - groundY);
  }

  static Future<ArenaPhysicsRuntime> create({
    required MobaPoint spawn,
    Iterable<MobaTowerSnapshot> towers = const [],
    Iterable<MobaCoverSnapshot> covers = const [],
  }) async {
    await RapierWorld.ensureInitialized();
    final world = RapierWorld(gravity: vm.Vector3(0, -gravity, 0));
    try {
      final staticBody = world.createBody(
        target: SimplePoseTarget(),
        type: BodyType.fixed,
      );
      final startY = ArenaWorldCatalog.navigationHeightAt(
            spawn.x,
            spawn.z,
            elevation: spawn.elevation,
          ) +
          footOffset;
      final playerPose = SimplePoseTarget(
        translation: vm.Vector3(spawn.x, startY, spawn.z),
      );
      final playerBody = world.createBody(
        target: playerPose,
        type: BodyType.kinematic,
      );
      final playerColliders = world.createColliders(
        playerBody,
        const CapsuleShape(
          radius: capsuleRadius,
          halfHeight: capsuleHalfHeight,
        ),
      );
      if (playerColliders.isEmpty) {
        throw StateError('Rapier did not create the player capsule collider.');
      }

      final runtime = ArenaPhysicsRuntime._(
        world,
        playerBody,
        playerPose,
        playerColliders.first,
        staticBody,
      );

      runtime._buildTerrain();
      runtime._buildCanalBanks();
      runtime._buildBuildings();
      runtime._buildCommercialBlocks();
      runtime._buildVegetation();
      runtime._buildMezzanines();
      runtime.syncTowers(towers);
      runtime.syncCovers(covers);

      // The first step builds Rapier's broad phase before the first character
      // query. No gameplay time is consumed by this warm-up.
      world.step(fixedStep);
      return runtime;
    } catch (_) {
      world.dispose();
      rethrow;
    }
  }

  void setInput(double x, double z) {
    if (_disposed) return;
    _moveX = x.isFinite ? x.clamp(-1.0, 1.0).toDouble() : 0.0;
    _moveZ = z.isFinite ? z.clamp(-1.0, 1.0).toDouble() : 0.0;
    final length = math.sqrt(_moveX * _moveX + _moveZ * _moveZ);
    if (length > 1) {
      _moveX /= length;
      _moveZ /= length;
    }
  }

  void setActive(bool value) {
    _active = value;
    if (!value) {
      _moveX = 0;
      _moveZ = 0;
      _velocityX = 0;
      _velocityZ = 0;
      _verticalVelocity = 0;
    }
  }

  /// Advances on Rapier's fixed clock, independently of render frame rate.
  void update(double frameDelta) {
    if (_disposed || !frameDelta.isFinite || frameDelta <= 0) return;
    _accumulator = math.min(
      _accumulator + frameDelta.clamp(0.0, 0.20),
      fixedStep * 8,
    );
    var steps = 0;
    while (_accumulator + 1e-9 >= fixedStep && steps < 8) {
      _fixedUpdate(fixedStep);
      _accumulator -= fixedStep;
      steps++;
    }
    if (_accumulator > fixedStep * 8) _accumulator = 0;
  }

  void _fixedUpdate(double dt) {
    final targetX = _active ? _moveX * moveSpeed : 0.0;
    final targetZ = _active ? _moveZ * moveSpeed : 0.0;
    final response = (_active ? acceleration : deceleration) * dt;
    _velocityX = _approach(_velocityX, targetX, response);
    _velocityZ = _approach(_velocityZ, targetZ, response);

    if (_active) {
      _verticalVelocity = math.max(-28.0, _verticalVelocity - gravity * dt);
    } else {
      _verticalVelocity = 0;
    }

    final desired = vm.Vector3(
      _velocityX * dt,
      _verticalVelocity * dt,
      _velocityZ * dt,
    );
    final movement = _world.moveCharacter(
      _playerCollider,
      position: _playerPose.translation,
      desiredTranslation: desired,
      deltaSeconds: dt,
      offset: 0.025,
      slide: true,
      maxSlopeClimbAngle: 0.74,
      minSlopeSlideAngle: 0.86,
      snapToGround: 0.34,
      autostep: true,
      autostepMaxHeight: 0.38,
      autostepMinWidth: 0.18,
    );

    _playerPose.translation.add(movement.translation);
    _grounded = movement.grounded;
    _slidingDownSlope = movement.slidingDownSlope;
    if (_grounded && _verticalVelocity < 0) _verticalVelocity = 0;

    _world.setBodyKinematicTargetPose(
      _playerBody,
      _playerPose.translation,
      vm.Quaternion.identity(),
    );
    _world.step(dt);
  }

  static double _approach(double value, double target, double amount) {
    if (value < target) return math.min(target, value + amount);
    if (value > target) return math.max(target, value - amount);
    return value;
  }

  /// Teleports only for the explicit respawn transition, never as a side
  /// effect of reaching zero health.
  void teleport(MobaPoint point) {
    if (_disposed) return;
    final y = ArenaWorldCatalog.navigationHeightAt(
          point.x,
          point.z,
          elevation: point.elevation,
        ) +
        footOffset;
    final translation = vm.Vector3(point.x, y, point.z);
    _playerPose.translation.setFrom(translation);
    _world.setBodyPose(
      _playerBody,
      translation,
      vm.Quaternion.identity(),
    );
    _velocityX = 0;
    _velocityZ = 0;
    _verticalVelocity = 0;
    _grounded = false;
    _world.step(fixedStep);
  }

  void syncTowers(Iterable<MobaTowerSnapshot> towers) {
    if (_disposed) return;
    final alive = <String, MobaTowerSnapshot>{
      for (final tower in towers)
        if (tower.health > 0)
          '${tower.team.name}_${tower.lane.name}_${tower.tier}': tower,
    };
    for (final key in _towerColliders.keys.toList()) {
      if (!alive.containsKey(key)) {
        _world.destroyCollider(_towerColliders.remove(key)!);
      }
    }
    for (final entry in alive.entries) {
      if (_towerColliders.containsKey(entry.key)) continue;
      final tower = entry.value;
      final y = ArenaWorldCatalog.navigationHeightAt(
            tower.position.x,
            tower.position.z,
            elevation: tower.position.elevation,
          ) +
          4.1;
      _towerColliders[entry.key] = _addStaticShape(
        CylinderShape(radius: 2.8, halfHeight: 4.1),
        vm.Vector3(tower.position.x, y, tower.position.z),
        label: 'tower_${entry.key}',
      );
    }
  }

  void syncCovers(Iterable<MobaCoverSnapshot> covers) {
    if (_disposed) return;
    final active = <String, MobaCoverSnapshot>{
      for (final cover in covers)
        if (!cover.isDestroyed) cover.id: cover,
    };
    for (final key in _coverColliders.keys.toList()) {
      if (!active.containsKey(key)) {
        _world.destroyCollider(_coverColliders.remove(key)!);
      }
    }
    for (final entry in active.entries) {
      if (_coverColliders.containsKey(entry.key)) continue;
      final cover = entry.value;
      final half = cover.variant == 'fence'
          ? vm.Vector3(1.8, 1.15, 0.42)
          : vm.Vector3(1.35, 1.15, 0.62);
      final y = ArenaWorldCatalog.navigationHeightAt(
            cover.position.x,
            cover.position.z,
            elevation: cover.position.elevation,
          ) +
          half.y;
      _coverColliders[entry.key] = _addStaticShape(
        BoxShape(halfExtents: half),
        vm.Vector3(cover.position.x, y, cover.position.z),
        label: 'cover_${entry.key}',
      );
    }
  }

  int _addStaticShape(
    Shape shape,
    vm.Vector3 position, {
    required String label,
  }) {
    final handles = _world.createColliders(
      _staticBody,
      shape,
      localPose: vm.Matrix4.translation(position),
    );
    if (handles.isEmpty) {
      throw StateError('Rapier rejected static collider: $label');
    }
    return handles.first;
  }

  void _buildTerrain() {
    final vertices = <double>[];
    final indices = <int>[];
    final halfW = ArenaWorldCatalog.halfWidth;
    final halfD = ArenaWorldCatalog.halfDepth;
    final step = _terrainCellSize;

    for (var z = -halfD; z < halfD - 1e-6; z += step) {
      for (var x = -halfW; x < halfW - 1e-6; x += step) {
        final x1 = math.min(x + step, halfW);
        final z1 = math.min(z + step, halfD);
        final centerX = (x + x1) * 0.5;
        final centerZ = (z + z1) * 0.5;
        if (!ArenaWorldCatalog.contains(centerX, centerZ)) continue;

        final corners = <(double, double)>[
          (x, z), (x1, z), (x, z1), (x1, z1),
        ];
        if (corners.any((p) => !ArenaWorldCatalog.contains(p.$1, p.$2))) {
          continue;
        }
        if (corners.any((p) =>
            ArenaWorldCatalog.isCanalAt(p.$1, p.$2) &&
            !ArenaWorldCatalog.isBridgeAt(p.$1, p.$2))) {
          continue;
        }
        if (ArenaWorldCatalog.isCanalAt(centerX, centerZ) &&
            !ArenaWorldCatalog.isBridgeAt(centerX, centerZ)) {
          continue;
        }

        final base = vertices.length ~/ 3;
        for (final point in corners) {
          final y = ArenaWorldCatalog.navigationHeightAt(point.$1, point.$2);
          vertices.addAll([point.$1, y, point.$2]);
        }
        // Counter-clockwise from above: every terrain face points toward +Y.
        indices.addAll([
          base, base + 2, base + 1,
          base + 1, base + 2, base + 3,
        ]);
      }
    }
    if (indices.isEmpty) {
      throw StateError('Arena terrain mesh has no walkable triangles.');
    }
    final shape = TriMeshShape(
      vertices: Float32List.fromList(vertices),
      indices: Uint32List.fromList(indices),
    );
    final handles = _world.createColliders(_staticBody, shape);
    if (handles.isEmpty) {
      throw StateError('Rapier rejected the arena terrain mesh.');
    }
  }

  void _buildCanalBanks() {
    const spans = <(double, double)>[
      (-90.0, -40.2), (-31.8, -4.2),
      (4.2, 31.8), (40.2, 90.0),
    ];
    for (final span in spans) {
      final centerX = (span.$1 + span.$2) * 0.5;
      final halfLength = (span.$2 - span.$1) * 0.5;
      for (final north in [false, true]) {
        final z = ArenaWorldCatalog.canalBankZAt(
          centerX,
          north: north,
        );
        final y = ArenaWorldCatalog.navigationHeightAt(centerX, z) + 1.35;
        _addStaticShape(
          BoxShape(halfExtents: vm.Vector3(halfLength, 1.35, 0.42)),
          vm.Vector3(centerX, y, z),
          label: 'canal_bank_${centerX}_${north ? 'north' : 'south'}',
        );
      }
    }
  }

  void _buildBuildings() {
    for (final building in ArenaWorldCatalog.cityInteriors) {
      final x = building.$2;
      final z = building.$3;
      final baseY = ArenaWorldCatalog.navigationHeightAt(x, z);
      const hw = ArenaWorldCatalog.roomHalfWidth;
      const hd = ArenaWorldCatalog.roomHalfDepth;
      const wallY = ArenaWorldCatalog.roomWallHalfHeight;
      const t = ArenaWorldCatalog.roomWallHalfThickness;
      const door = ArenaWorldCatalog.roomDoorHalfWidth;

      _addStaticShape(
        BoxShape(halfExtents: vm.Vector3(hw, wallY, t)),
        vm.Vector3(x, baseY + wallY, z + hd),
        label: '${building.$1}_rear_wall',
      );
      _addStaticShape(
        BoxShape(halfExtents: vm.Vector3(t, wallY, hd)),
        vm.Vector3(x - hw, baseY + wallY, z),
        label: '${building.$1}_west_wall',
      );
      _addStaticShape(
        BoxShape(halfExtents: vm.Vector3(t, wallY, hd)),
        vm.Vector3(x + hw, baseY + wallY, z),
        label: '${building.$1}_east_wall',
      );
      final segmentHalf = (hw - door) * 0.5;
      final segmentOffset = door + segmentHalf;
      for (final sign in [-1.0, 1.0]) {
        _addStaticShape(
          BoxShape(halfExtents: vm.Vector3(segmentHalf, wallY, t)),
          vm.Vector3(x + sign * segmentOffset, baseY + wallY, z - hd),
          label: '${building.$1}_front_wall_$sign',
        );
      }

      final access = ArenaWorldCatalog.verticalAccesses.any(
        (entry) => entry.id == building.$1,
      );
      final counterX = access ? x - 5.2 : x;
      final counterZ = access ? z - 2.0 : z + 2.2;
      final counterHalf = access
          ? vm.Vector3(1.5, 0.7, 0.7)
          : vm.Vector3(2.6, 0.7, 0.7);
      _addStaticShape(
        BoxShape(halfExtents: counterHalf),
        vm.Vector3(counterX, baseY + counterHalf.y, counterZ),
        label: '${building.$1}_counter',
      );
      if (!access) {
        _addStaticShape(
          BoxShape(halfExtents: vm.Vector3(0.55, 0.8, 1.8)),
          vm.Vector3(x - 7.0, baseY + 0.8, z + 3.2),
          label: '${building.$1}_shelf',
        );
      }
    }
  }

  void _buildCommercialBlocks() {
    for (final block in ArenaWorldCatalog.commercialBlocks) {
      final x = block.$2;
      final z = block.$3;
      final half = block.$4;
      final y = ArenaWorldCatalog.navigationHeightAt(x, z) + 4.5;
      _addStaticShape(
        BoxShape(halfExtents: vm.Vector3(half, 4.5, half)),
        vm.Vector3(x, y, z),
        label: block.$1,
      );
    }
  }

  void _buildVegetation() {
    for (final point in ArenaWorldCatalog.treeBlockerPoints) {
      final y = ArenaWorldCatalog.navigationHeightAt(point.$1, point.$2) + 2.2;
      _addStaticShape(
        CylinderShape(radius: ArenaWorldCatalog.treeCollisionRadius, halfHeight: 2.2),
        vm.Vector3(point.$1, y, point.$2),
        label: 'tree_${point.$1}_${point.$2}',
      );
    }
    for (final point in ArenaWorldCatalog.largeTreePoints) {
      final y = ArenaWorldCatalog.navigationHeightAt(point.$1, point.$2) + 2.6;
      _addStaticShape(
        CylinderShape(radius: ArenaWorldCatalog.treeCollisionRadius, halfHeight: 2.6),
        vm.Vector3(point.$1, y, point.$2),
        label: 'large_tree_${point.$1}_${point.$2}',
      );
    }
  }

  void _buildMezzanines() {
    for (final access in ArenaWorldCatalog.verticalAccesses) {
      final z0 = access.corridorMinZ;
      final z1 = access.corridorMaxZ;
      final startX = access.rampStartX;
      final endX = access.rampEndX;
      final y0 = ArenaWorldCatalog.navigationHeightAt(startX, z0);
      final y1 = ArenaWorldCatalog.navigationHeightAt(endX, z0) +
          ArenaVerticalAccess.upperHeight;
      final vertices = Float32List.fromList([
        startX, y0, z0,
        endX, y1, z0,
        startX, y0, z1,
        endX, y1, z1,
      ]);
      final indices = Uint32List.fromList([0, 2, 1, 1, 2, 3]);
      final ramp = TriMeshShape(vertices: vertices, indices: indices);
      final handles = _world.createColliders(_staticBody, ramp);
      if (handles.isEmpty) {
        throw StateError('Rapier rejected ramp ${access.id}.');
      }

      final deckCenterX = access.x + ArenaVerticalAccess.platformLength * 0.5;
      final deckCenterZ = (z0 + z1) * 0.5;
      final deckHalf = vm.Vector3(
        ArenaVerticalAccess.platformLength * 0.5,
        0.15,
        ArenaVerticalAccess.platformDepth * 0.5,
      );
      final deckY = ArenaWorldCatalog.navigationHeightAt(
            deckCenterX,
            deckCenterZ,
          ) +
          ArenaVerticalAccess.upperHeight -
          deckHalf.y;
      _addStaticShape(
        BoxShape(halfExtents: deckHalf),
        vm.Vector3(deckCenterX, deckY, deckCenterZ),
        label: 'mezzanine_${access.id}',
      );
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _world.dispose();
  }
}
