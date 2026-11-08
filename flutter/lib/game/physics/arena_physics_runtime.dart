import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_scene/physics.dart';
import 'package:flutter_scene_rapier/flutter_scene_rapier.dart';
import 'package:vector_math/vector_math.dart' as vm;

import '../match/moba_match_simulation.dart';
import '../world/arena_world_catalog.dart';

/// Hero-specific traversal tuning. These values define movement only; they
/// do not change the match simulation's existing hero skills.
class ArenaTraversalProfile {
  const ArenaTraversalProfile({
    required this.maxCharges,
    required this.dashDistance,
    required this.dashDuration,
    required this.regenerationPerSecond,
    required this.regenerationDelay,
    required this.airControlRatio,
    required this.slideDuration,
    required this.slideFrictionMultiplier,
    required this.slideSteeringRadiansPerSecond,
    required this.groundSpeed,
    required this.groundAcceleration,
    required this.jumpImpulse,
  });

  final double maxCharges;
  final double dashDistance;
  final double dashDuration;
  final double regenerationPerSecond;
  final double regenerationDelay;
  final double airControlRatio;
  final double slideDuration;
  final double slideFrictionMultiplier;
  final double slideSteeringRadiansPerSecond;
  final double groundSpeed;
  final double groundAcceleration;
  final double jumpImpulse;

  static ArenaTraversalProfile syntheticPrototype() =>
      const ArenaTraversalProfile(
        maxCharges: 3,
        dashDistance: 5.0,
        dashDuration: 0.21,
        regenerationPerSecond: 0.82,
        regenerationDelay: 0.48,
        airControlRatio: 0.68,
        slideDuration: 0.82,
        slideFrictionMultiplier: 0.22,
        slideSteeringRadiansPerSecond: 2.75,
        groundSpeed: 6.15,
        groundAcceleration: 24.0,
        jumpImpulse: 8.1,
      );

  static ArenaTraversalProfile forHero(MobaHeroId heroId) => switch (heroId) {
        MobaHeroId.lyra => const ArenaTraversalProfile(
            maxCharges: 3,
            dashDistance: 4.2,
            dashDuration: 0.23,
            regenerationPerSecond: 0.62,
            regenerationDelay: 0.55,
            airControlRatio: 0.48,
            slideDuration: 0.64,
            slideFrictionMultiplier: 0.30,
            slideSteeringRadiansPerSecond: 2.0,
            groundSpeed: 5.6,
            groundAcceleration: 21.0,
            jumpImpulse: 6.4,
          ),
        MobaHeroId.bastion => const ArenaTraversalProfile(
            maxCharges: 2,
            dashDistance: 3.7,
            dashDuration: 0.24,
            regenerationPerSecond: 0.74,
            regenerationDelay: 0.62,
            airControlRatio: 0.30,
            slideDuration: 0.50,
            slideFrictionMultiplier: 0.42,
            slideSteeringRadiansPerSecond: 1.45,
            groundSpeed: 5.2,
            groundAcceleration: 18.5,
            jumpImpulse: 5.7,
          ),
        MobaHeroId.kairo => const ArenaTraversalProfile(
            maxCharges: 4,
            dashDistance: 4.7,
            dashDuration: 0.22,
            regenerationPerSecond: 0.56,
            regenerationDelay: 0.68,
            airControlRatio: 0.58,
            slideDuration: 0.70,
            slideFrictionMultiplier: 0.26,
            slideSteeringRadiansPerSecond: 2.4,
            groundSpeed: 6.0,
            groundAcceleration: 23.0,
            jumpImpulse: 7.0,
          ),
      };
}

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
    this._traversalProfile,
  ) : _traversalStamina = _traversalProfile.maxCharges;

  static const double fixedStep = 1.0 / 60.0;
  static const double gravity = 24.0;
  static const double moveSpeed = 5.6;
  static const double acceleration = 21.0;
  static const double airFriction = 2.6;
  static const double dashDistance = 4.8;
  static const double dashDuration = 0.24;

  // Separate traversal budget: the existing hero-skill dash remains unchanged.
  static const double defaultTraversalStaminaMax = 3.0;
  static const double traversalDashCost = 1.0;
  static const double slideStartSpeed = 3.2;
  static const double slideStopSpeed = 0.7;

  static const double capsuleRadius = 0.38;
  static const double capsuleHalfHeight = 0.50;
  static const double footOffset = capsuleRadius + capsuleHalfHeight;
  static const double _terrainCellSize = 2.5;

  final RapierWorld _world;
  final int _playerBody;
  final SimplePoseTarget _playerPose;
  final int _playerCollider;
  final int _staticBody;
  final ArenaTraversalProfile _traversalProfile;
  final Map<String, int> _towerColliders = {};
  final Map<String, int> _coverColliders = {};

  double _accumulator = 0;
  double _moveX = 0;
  double _moveZ = 0;
  double _velocityX = 0;
  double _velocityZ = 0;
  double _verticalVelocity = 0;
  double _actualHorizontalSpeed = 0;
  double _dashVelocityX = 0;
  double _dashVelocityZ = 0;
  double _dashRemaining = 0;
  bool _dashCompletionPending = false;
  late double _traversalStamina;
  double _traversalStaminaRegenDelayRemaining = 0;
  bool _traversalDashActive = false;
  bool _traversalDashCompletionPending = false;
  double _slideRemaining = 0;
  bool _slideActive = false;
  bool _slideCompletionPending = false;
  bool _jumpActive = false;
  bool _active = true;
  bool _grounded = false;
  bool _disposed = false;
  bool _slidingDownSlope = false;

  bool get grounded => _grounded;
  bool get slidingDownSlope => _slidingDownSlope;
  double get verticalVelocity => _verticalVelocity;
  double get horizontalSpeed => _actualHorizontalSpeed;
  double get movementSpeedRatio =>
      (_actualHorizontalSpeed / _traversalProfile.groundSpeed)
          .clamp(0.0, 1.35)
          .toDouble();
  bool get dashing => _dashRemaining > 0;
  bool get sliding => _slideActive;
  bool get jumping => _jumpActive;
  bool get canTriggerJump =>
      !_disposed && _active && _grounded && !_slideActive &&
      _dashRemaining <= 0 && !_jumpActive;
  bool get canTriggerSlide =>
      !_disposed &&
      _active &&
      _grounded &&
      !_slideActive &&
      _dashRemaining <= 0 &&
      _actualHorizontalSpeed + 1e-6 >= slideStartSpeed &&
      math.sqrt(_velocityX * _velocityX + _velocityZ * _velocityZ) + 1e-6 >=
          slideStartSpeed;
  double get traversalStamina => _traversalStamina;
  double get traversalStaminaMax => _traversalProfile.maxCharges;
  double get traversalStaminaRatio =>
      (_traversalStamina / traversalStaminaMax).clamp(0.0, 1.0).toDouble();
  bool get canTriggerTraversalDash =>
      !_disposed &&
      _active &&
      _dashRemaining <= 0 &&
      !_slideActive &&
      _traversalStamina + 1e-6 >= traversalDashCost;

  /// True once the swept dash has ended, including a wall/canal interruption.
  bool consumeDashCompletion() {
    final completed = _dashCompletionPending;
    _dashCompletionPending = false;
    return completed;
  }

  /// Consumes the one-shot completion event for a momentum slide.
  bool consumeSlideCompletion() {
    final completed = _slideCompletionPending;
    _slideCompletionPending = false;
    return completed;
  }

  /// Traversal completion is separate from hero-skill dash resolution.
  bool consumeTraversalDashCompletion() {
    final completed = _traversalDashCompletionPending;
    _traversalDashCompletionPending = false;
    return completed;
  }

  MobaPoint get playerPosition {
    final x = _playerPose.translation.x;
    final z = _playerPose.translation.z;
    final footY = _playerPose.translation.y - footOffset;
    final groundY = ArenaWorldCatalog.navigationHeightAt(x, z);
    return MobaPoint(x, z, elevation: footY - groundY);
  }

  static Future<ArenaPhysicsRuntime> create({
    required MobaPoint spawn,
    MobaHeroId heroId = MobaHeroId.lyra,
    Iterable<MobaTowerSnapshot> towers = const [],
    Iterable<MobaCoverSnapshot> covers = const [],
    ArenaTraversalProfile? traversalProfile,
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
        traversalProfile ?? ArenaTraversalProfile.forHero(heroId),
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
      _dashVelocityX = 0;
      _dashVelocityZ = 0;
      _dashRemaining = 0;
      _dashCompletionPending = false;
      _traversalDashActive = false;
      _traversalDashCompletionPending = false;
      _slideRemaining = 0;
      _slideActive = false;
      _slideCompletionPending = false;
      _jumpActive = false;
      _actualHorizontalSpeed = 0;
    }
  }

  /// Queues a short, collision-resolved burst. Unlike a transform teleport,
  /// the dash is swept by Rapier and stops at walls, furniture and terrain.
  bool triggerDash(
    double directionX,
    double directionZ, {
    double distance = dashDistance,
    double duration = dashDuration,
  }) {
    if (_disposed ||
        !_active ||
        _traversalDashActive ||
        _slideActive ||
        !directionX.isFinite ||
        !directionZ.isFinite ||
        !distance.isFinite ||
        !duration.isFinite ||
        distance <= 0 ||
        duration <= 0) {
      return false;
    }
    final length = math.sqrt(
      directionX * directionX + directionZ * directionZ,
    );
    if (length < 1e-4) return false;
    final speed = distance / duration;
    _dashVelocityX = directionX / length * speed;
    _dashVelocityZ = directionZ / length * speed;
    _dashRemaining = duration;
    _dashCompletionPending = false;
    _velocityX = 0;
    _velocityZ = 0;
    return true;
  }

  /// Starts a traversal-only dash. It has its own stamina budget and does not
  /// alter the existing hero-skill dash path used by the match simulation.
  bool triggerTraversalDash(double directionX, double directionZ) {
    if (!canTriggerTraversalDash) return false;
    final started = triggerDash(
      directionX,
      directionZ,
      distance: _traversalProfile.dashDistance,
      duration: _traversalProfile.dashDuration,
    );
    if (!started) return false;

    _traversalStamina = math.max(
      0.0,
      _traversalStamina - traversalDashCost,
    );
    _traversalStaminaRegenDelayRemaining = _traversalProfile.regenerationDelay;
    _traversalDashActive = true;
    _traversalDashCompletionPending = false;
    return true;
  }

  /// Starts a short ground slide without adding speed or consuming dash charge.
  /// Existing velocity is preserved and only gently steered during the slide.
  bool triggerTraversalSlide() {
    if (!canTriggerSlide) return false;
    final speed = math.sqrt(_velocityX * _velocityX + _velocityZ * _velocityZ);
    if (!speed.isFinite || speed < slideStartSpeed) return false;
    _slideRemaining = _traversalProfile.slideDuration;
    _slideActive = true;
    _slideCompletionPending = false;
    return true;
  }

  /// A vertical traversal hop: it does not target, affect or collide with
  /// other actors. The impulse is profile-specific and resolved by Rapier.
  bool triggerTraversalJump({double impulseMultiplier = 1.0}) {
    if (!canTriggerJump || !impulseMultiplier.isFinite ||
        impulseMultiplier < 0.8 || impulseMultiplier > 1.8) {
      return false;
    }
    _verticalVelocity = _traversalProfile.jumpImpulse * impulseMultiplier;
    _grounded = false;
    _jumpActive = true;
    return true;
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
    final dashStep = _active ? math.min(dt, _dashRemaining) : 0.0;
    final slideStep = _active && _slideActive
        ? math.min(dt, _slideRemaining)
        : 0.0;
    if (dashStep > 0) {
      _velocityX = _dashVelocityX;
      _velocityZ = _dashVelocityZ;
    } else if (slideStep > 0) {
      _updateSlideVelocity(dt);
    } else {
      _updateMotorVelocity(dt);
    }
    _preventOffBridgeCanalEntry(dt, duringDash: dashStep > 0);

    if (_active) {
      _verticalVelocity = math.max(-28.0, _verticalVelocity - gravity * dt);
    } else {
      _verticalVelocity = 0;
    }

    final horizontalStep = dashStep > 0 ? dashStep : dt;
    final desired = vm.Vector3(
      _velocityX * horizontalStep,
      _verticalVelocity * dt,
      _velocityZ * horizontalStep,
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
      snapToGround: _verticalVelocity > 0 ? 0.0 : 0.34,
      autostep: true,
      autostepMaxHeight: 0.38,
      autostepMinWidth: 0.18,
    );

    _playerPose.translation.add(movement.translation);
    _actualHorizontalSpeed = math.sqrt(
          movement.translation.x * movement.translation.x +
              movement.translation.z * movement.translation.z,
        ) /
        dt;
    if (dashStep > 0) {
      final requestedDistance = math.sqrt(
        desired.x * desired.x + desired.z * desired.z,
      );
      final dashLength = math.sqrt(
        _dashVelocityX * _dashVelocityX +
            _dashVelocityZ * _dashVelocityZ,
      );
      final movedAlongDash = dashLength > 1e-5
          ? (movement.translation.x * _dashVelocityX +
                  movement.translation.z * _dashVelocityZ) /
              dashLength
          : 0.0;
      final blocked = requestedDistance > 1e-4 &&
          movedAlongDash < requestedDistance * 0.22;
      _dashRemaining = blocked
          ? 0.0
          : math.max(0.0, _dashRemaining - dashStep);
      _velocityX = movement.translation.x / dt * 0.18;
      _velocityZ = movement.translation.z / dt * 0.18;
      if (_dashRemaining <= 0) {
        _dashVelocityX = 0;
        _dashVelocityZ = 0;
        if (_traversalDashActive) {
          _traversalDashActive = false;
          _traversalDashCompletionPending = true;
        } else {
          _dashCompletionPending = true;
        }
      }
    } else if (slideStep > 0 && _slideActive) {
      _slideRemaining = math.max(0.0, _slideRemaining - slideStep);
      if (_slideRemaining <= 0 || _actualHorizontalSpeed < slideStopSpeed) {
        _slideRemaining = 0;
        _slideActive = false;
        _slideCompletionPending = true;
      }
    }
    _grounded = movement.grounded;
    _slidingDownSlope = movement.slidingDownSlope;
    if (_grounded && _verticalVelocity < 0) {
      _verticalVelocity = 0;
      _jumpActive = false;
    }

    _world.setBodyKinematicTargetPose(
      _playerBody,
      _playerPose.translation,
      vm.Quaternion.identity(),
    );
    _world.step(dt);
    _updateTraversalStamina(dt);
  }

  void _updateTraversalStamina(double dt) {
    if (!_active ||
        _disposed ||
        _traversalStamina >= traversalStaminaMax) {
      return;
    }
    if (_traversalStaminaRegenDelayRemaining > 0) {
      _traversalStaminaRegenDelayRemaining = math.max(
        0.0,
        _traversalStaminaRegenDelayRemaining - dt,
      );
      return;
    }
    _traversalStamina = math.min(
      traversalStaminaMax,
      _traversalStamina + _traversalProfile.regenerationPerSecond * dt,
    );
  }

  /// The river is a non-walkable volume; only the catalogued bridge spans
  /// may connect the two banks. The clearance includes the capsule radius and
  /// a small numerical margin, so the character stops before its leading edge
  /// enters the canal instead of relying on a thin bank collider to catch it.
  void _preventOffBridgeCanalEntry(
    double dt, {
    bool duringDash = false,
  }) {
    if (!_active || dt <= 0) return;

    final velocityX = duringDash ? _dashVelocityX : _velocityX;
    final velocityZ = duringDash ? _dashVelocityZ : _velocityZ;
    final movementTime = duringDash ? math.min(dt, _dashRemaining) : dt;
    final fromX = _playerPose.translation.x;
    final fromZ = _playerPose.translation.z;
    final toX = fromX + velocityX * movementTime;
    final toZ = fromZ + velocityZ * movementTime;
    if (!ArenaWorldCatalog.isCanalAt(toX, toZ) ||
        ArenaWorldCatalog.isBridgeAt(toX, toZ)) {
      return;
    }

    final fromSouth = ArenaWorldCatalog.canalBankZAt(
      fromX,
      north: false,
    );
    final fromNorth = ArenaWorldCatalog.canalBankZAt(
      fromX,
      north: true,
    );
    final toSouth = ArenaWorldCatalog.canalBankZAt(
      toX,
      north: false,
    );
    final toNorth = ArenaWorldCatalog.canalBankZAt(
      toX,
      north: true,
    );

    final fromCenter = (fromSouth + fromNorth) * 0.5;
    final toCenter = (toSouth + toNorth) * 0.5;
    final fromDistance = (fromZ - fromCenter).abs();
    final toDistance = (toZ - toCenter).abs();
    final clearance = capsuleRadius + 0.12;
    final fromHalfWidth = (fromNorth - fromSouth) * 0.5 + clearance;
    final toHalfWidth = (toNorth - toSouth) * 0.5 + clearance;
    final entersOrMovesDeeper = toDistance < toHalfWidth &&
        (fromDistance >= fromHalfWidth ||
            toDistance < fromDistance - 1e-4);

    if (entersOrMovesDeeper) {
      // The canal runs predominantly along X, so Z is its crossing axis.
      // Lateral steering along the bank remains available.
      if (duringDash) {
        _dashVelocityZ = 0;
        _velocityZ = 0;
        _dashRemaining = 0;
      } else {
        _velocityZ = 0;
      }
    }
  }

  /// Keeps momentum while allowing only a bounded change in heading.
  /// The slide never adds speed and uses Rapier's normal swept collision path.
  void _updateSlideVelocity(double dt) {
    final speed = math.sqrt(_velocityX * _velocityX + _velocityZ * _velocityZ);
    if (!speed.isFinite || speed < slideStopSpeed) {
      _velocityX = 0;
      _velocityZ = 0;
      _slideRemaining = 0;
      _slideActive = false;
      _slideCompletionPending = true;
      return;
    }

    final inputLength = math.sqrt(_moveX * _moveX + _moveZ * _moveZ);
    if (inputLength > 0.10) {
      final currentAngle = math.atan2(_velocityZ, _velocityX);
      final targetAngle = math.atan2(_moveZ, _moveX);
      var delta = targetAngle - currentAngle;
      if (delta > math.pi) delta -= math.pi * 2;
      if (delta < -math.pi) delta += math.pi * 2;
      final maxTurn = _traversalProfile.slideSteeringRadiansPerSecond * dt;
      final nextAngle =
          currentAngle + delta.clamp(-maxTurn, maxTurn).toDouble();
      _velocityX = math.cos(nextAngle) * speed;
      _velocityZ = math.sin(nextAngle) * speed;
    }

    final friction = _grounded
        ? ArenaWorldCatalog.groundFrictionAt(
              _playerPose.translation.x,
              _playerPose.translation.z,
            ) *
            _traversalProfile.slideFrictionMultiplier
        : airFriction * 0.65;
    final damping = math.exp(-math.max(0.6, friction) * dt);
    _velocityX *= damping;
    _velocityZ *= damping;
  }

  /// Accelerates along a normalized target vector and applies surface-specific
  /// damping when input is released. The vector clamp avoids faster diagonals
  /// and keeps turn response consistent at every heading.
  void _updateMotorVelocity(double dt) {
    final inputLength = math.sqrt(_moveX * _moveX + _moveZ * _moveZ);
    if (_active && inputLength > 0.06) {
      final surfaceSpeed =
          ArenaWorldCatalog.movementSpeedMultiplierAt(
        _playerPose.translation.x,
        _playerPose.translation.z,
      );
      final targetSpeed = _traversalProfile.groundSpeed * surfaceSpeed *
          math.min(1.0, inputLength);
      final targetX = _moveX / inputLength * targetSpeed;
      final targetZ = _moveZ / inputLength * targetSpeed;
      final deltaX = targetX - _velocityX;
      final deltaZ = targetZ - _velocityZ;
      final deltaLength = math.sqrt(deltaX * deltaX + deltaZ * deltaZ);
      final facingDot = _velocityX * targetX + _velocityZ * targetZ;
      final reversalBoost = facingDot < -0.05 ? 1.35 : 1.0;
      final groundedRatio =
          _grounded ? 1.0 : _traversalProfile.airControlRatio;
      final maximumChange =
          _traversalProfile.groundAcceleration *
              reversalBoost * groundedRatio * dt;
      final blend = deltaLength <= maximumChange || deltaLength <= 1e-6
          ? 1.0
          : maximumChange / deltaLength;
      _velocityX += deltaX * blend;
      _velocityZ += deltaZ * blend;
      return;
    }

    final friction = _active && _grounded
        ? ArenaWorldCatalog.groundFrictionAt(
            _playerPose.translation.x,
            _playerPose.translation.z,
          )
        : airFriction;
    final damping = math.exp(-friction * dt);
    _velocityX *= damping;
    _velocityZ *= damping;
    if (_velocityX * _velocityX + _velocityZ * _velocityZ < 0.004) {
      _velocityX = 0;
      _velocityZ = 0;
    }
  }

  /// Teleports only for the explicit respawn transition, never as a side
  /// effect of reaching zero health.
  void teleport(MobaPoint point) {
    if (_disposed) return;
    final resolvedElevation = ArenaWorldCatalog.resolveNavigationElevation(
          point.x,
          point.z,
          point.elevation,
        ) ??
        point.elevation;
    final y = ArenaWorldCatalog.navigationHeightAt(
          point.x,
          point.z,
          elevation: resolvedElevation,
        ) +
        footOffset;
    _jumpActive = false;
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
    _dashVelocityX = 0;
    _dashVelocityZ = 0;
    _dashRemaining = 0;
    _dashCompletionPending = false;
    _traversalDashActive = false;
    _traversalDashCompletionPending = false;
    _slideRemaining = 0;
    _slideActive = false;
    _slideCompletionPending = false;
    _traversalStamina = traversalStaminaMax;
    _traversalStaminaRegenDelayRemaining = 0;
    _actualHorizontalSpeed = 0;
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
    final xCoordinates = <double>{
      for (var x = -halfW; x < halfW - 1e-6; x += step) x,
      halfW,
      for (final access in ArenaWorldCatalog.verticalAccesses)
        access.rampStartX,
      for (final access in ArenaWorldCatalog.verticalAccesses)
        access.rampEndX,
      for (final access in ArenaWorldCatalog.verticalAccesses)
        access.platformEndX,
    }.toList()
      ..sort();
    final zCoordinates = <double>{
      for (var z = -halfD; z < halfD - 1e-6; z += step) z,
      halfD,
      for (final access in ArenaWorldCatalog.verticalAccesses)
        access.corridorMinZ,
      for (final access in ArenaWorldCatalog.verticalAccesses)
        access.corridorMaxZ,
    }.toList()
      ..sort();

    for (var zi = 0; zi < zCoordinates.length - 1; zi++) {
      final z = zCoordinates[zi];
      final z1 = zCoordinates[zi + 1];
      for (var xi = 0; xi < xCoordinates.length - 1; xi++) {
        final x = xCoordinates[xi];
        final x1 = xCoordinates[xi + 1];
        final centerX = (x + x1) * 0.5;
        final centerZ = (z + z1) * 0.5;
        if (!ArenaWorldCatalog.contains(centerX, centerZ)) continue;

        // The ramp and raised deck own this footprint. Leaving the ground mesh
        // underneath creates two competing contact surfaces that block ascent.
        final overVerticalAccess = ArenaWorldCatalog.verticalAccesses.any(
          (access) =>
              centerX >= access.rampStartX &&
              centerX <= access.platformEndX &&
              centerZ >= access.corridorMinZ &&
              centerZ <= access.corridorMaxZ,
        );
        if (overVerticalAccess) continue;

        final corners = <(double, double)>[
          (x, z), (x1, z), (x, z1), (x1, z1),
        ];
        if (corners.any((p) => !ArenaWorldCatalog.contains(p.$1, p.$2))) {
          continue;
        }
        // Keep the last bank cells intact. Dropping an entire 2.5 m cell
        // because one corner touches the river leaves the capsule without
        // ground support before it reaches the bank barrier. Cells whose
        // centres are in the channel are still omitted below.
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
    // Generate bank colliders from the same five bridge gaps as the terrain.
    // Short segments follow the river's curve without sealing crossings.
    final spans = <(double, double)>[];
    var cursor = ArenaWorldCatalog.canalStartX;
    for (final bridgeX in ArenaWorldCatalog.bridgePositions) {
      final bankEnd = bridgeX - ArenaWorldCatalog.bridgeHalfWidth - 0.18;
      if (bankEnd > cursor) spans.add((cursor, bankEnd));
      cursor = bridgeX + ArenaWorldCatalog.bridgeHalfWidth + 0.18;
    }
    if (cursor < ArenaWorldCatalog.canalEndX) {
      spans.add((cursor, ArenaWorldCatalog.canalEndX));
    }

    for (final span in spans) {
      final segmentCount = math.max(1, ((span.$2 - span.$1) / 8.0).ceil());
      for (var index = 0; index < segmentCount; index++) {
        final startX = span.$1 +
            (span.$2 - span.$1) * index / segmentCount;
        final endX = span.$1 +
            (span.$2 - span.$1) * (index + 1) / segmentCount;
        final centerX = (startX + endX) * 0.5;
        final halfLength = (endX - startX) * 0.5 + 0.08;
        for (final north in [false, true]) {
          final z = ArenaWorldCatalog.canalBankZAt(centerX, north: north);
          _addStaticShape(
            BoxShape(halfExtents: vm.Vector3(halfLength, 3.0, 0.75)),
            vm.Vector3(centerX, 1.5, z),
            label: 'canal_bank_${centerX}_${north ? 'north' : 'south'}',
          );
        }
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

    }
    for (final item in ArenaWorldCatalog.interiorFurnitureFootprints) {
      final room = ArenaWorldCatalog.cityInteriors.firstWhere(
        (building) => building.$1 == item.$2,
      );
      final baseY = ArenaWorldCatalog.navigationHeightAt(
        room.$2,
        room.$3,
      );
      final halfHeight = switch (item.$1) {
        'chair' => 0.48,
        'bench' => 0.44,
        'shelf' => 0.8,
        _ => 0.68,
      };
      _addStaticShape(
        BoxShape(
          halfExtents: vm.Vector3(
            item.$5,
            halfHeight,
            item.$6,
          ),
        ),
        vm.Vector3(
          item.$3,
          baseY + halfHeight,
          item.$4,
        ),
        label: 'interior_${item.$2}_${item.$1}',
      );
    }
  }

  void _buildCommercialBlocks() {
    for (final block in ArenaWorldCatalog.commercialBlocks) {
      final x = block.$2;
      final z = block.$3;
      final footprint = ArenaWorldCatalog.commercialFootprint(block);
      final halfHeight = footprint.$3 * 0.5;
      final baseY = ArenaWorldCatalog.navigationHeightAt(x, z);
      _addStaticShape(
        BoxShape(
          halfExtents: vm.Vector3(
            footprint.$1,
            halfHeight,
            footprint.$2,
          ),
        ),
        vm.Vector3(x, baseY + halfHeight, z),
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

      // One continuous inclined surface prevents the capsule controller from
      // catching on stair risers. Navigation and Rapier share the same linear
      // rise, so the character gains height progressively while moving.
      final rampVertices = <double>[];
      for (final point in <(double, double)>[
        (startX, z0),
        (endX, z0),
        (startX, z1),
        (endX, z1),
      ]) {
        final elevation = access.localSurfaceHeight(point.$1, point.$2)!;
        final y = ArenaWorldCatalog.navigationHeightAt(point.$1, point.$2) +
            elevation;
        rampVertices.addAll([point.$1, y, point.$2]);
      }
      final ramp = TriMeshShape(
        vertices: Float32List.fromList(rampVertices),
        indices: Uint32List.fromList([0, 2, 1, 1, 2, 3]),
      );
      final rampHandles = _world.createColliders(_staticBody, ramp);
      if (rampHandles.isEmpty) {
        throw StateError('Rapier rejected mezzanine ramp: ${access.id}');
      }

      // The deck's top surface meets the ramp at the exact upper elevation.
      final deckCenterX =
          access.x + ArenaVerticalAccess.platformLength * 0.5;
      final deckCenterZ = (z0 + z1) * 0.5;
      const deckHalfHeight = 0.06;
      final deckHalf = vm.Vector3(
        ArenaVerticalAccess.platformLength * 0.5,
        deckHalfHeight,
        ArenaVerticalAccess.platformDepth * 0.5,
      );
      final deckY = ArenaWorldCatalog.navigationHeightAt(
            deckCenterX,
            deckCenterZ,
          ) +
          ArenaVerticalAccess.upperHeight -
          deckHalfHeight;
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
