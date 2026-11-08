import 'dart:math' as math;

import '../match/moba_match_simulation.dart';

enum ArenaSurveyDroneState {
  patrolling,
  observingPlayer,
  repositioning,
  inspectingPlatform,
}

extension ArenaSurveyDroneStateLabel on ArenaSurveyDroneState {
  String get label => switch (this) {
        ArenaSurveyDroneState.patrolling => 'PATRULHANDO',
        ArenaSurveyDroneState.observingPlayer => 'OBSERVANDO JOGADOR',
        ArenaSurveyDroneState.repositioning => 'REPOSICIONANDO',
        ArenaSurveyDroneState.inspectingPlatform => 'INSPECIONANDO PLATAFORMA',
      };
}

/// Small deterministic state machine for a non-combat maintenance drone.
///
/// The controller intentionally owns only navigation and social response:
/// patrol, observe, keep personal space, and inspect a triggered world device.
class ArenaSurveyDroneController {
  ArenaSurveyDroneController({
    MobaPoint initialPosition = const MobaPoint(2.4, -55.6),
  })  : _x = initialPosition.x,
        _z = initialPosition.z;

  static const List<MobaPoint> _route = [
    MobaPoint(2.4, -55.6),
    MobaPoint(10.5, -55.6),
  ];
  static const MobaPoint _inspectionPoint = MobaPoint(8.2, -57.4);

  static const double _patrolSpeed = 1.15;
  static const double _inspectionSpeed = 1.35;
  static const double _repositionSpeed = 1.5;
  static const double _noticeRadius = 2.7;
  static const double _personalSpaceRadius = 1.35;

  double _x;
  double _z;
  double _facingRadians = 0;
  int _waypoint = 0;
  ArenaSurveyDroneState _state = ArenaSurveyDroneState.patrolling;

  MobaPoint get position => MobaPoint(_x, _z);
  double get facingRadians => _facingRadians;
  ArenaSurveyDroneState get state => _state;
  String get stateLabel => _state.label;

  void update(
    double deltaSeconds, {
    required MobaPoint playerPosition,
    required bool playerOnSpringPad,
  }) {
    if (!deltaSeconds.isFinite || deltaSeconds <= 0) return;
    final dt = deltaSeconds.clamp(0.0, 0.05).toDouble();

    final dx = playerPosition.x - _x;
    final dz = playerPosition.z - _z;
    final distance = math.sqrt(dx * dx + dz * dz);

    if (playerOnSpringPad) {
      _state = ArenaSurveyDroneState.inspectingPlatform;
      _moveToward(_inspectionPoint, dt, _inspectionSpeed);
      return;
    }

    if (distance < _noticeRadius) {
      _facingRadians = distance > 1e-4
          ? math.atan2(dx, dz)
          : _facingRadians;
      if (distance < _personalSpaceRadius) {
        _state = ArenaSurveyDroneState.repositioning;
        final inverseDistance = 1 / math.max(0.001, distance);
        final escapeX = distance > 1e-4 ? -dx * inverseDistance : 1.0;
        final escapeZ = distance > 1e-4 ? -dz * inverseDistance : 0.0;
        _x += escapeX * _repositionSpeed * dt;
        _z += escapeZ * _repositionSpeed * dt;
        _clampToLabBounds();
      } else {
        _state = ArenaSurveyDroneState.observingPlayer;
      }
      return;
    }

    _state = ArenaSurveyDroneState.patrolling;
    final target = _route[_waypoint];
    final remaining = _moveToward(target, dt, _patrolSpeed);
    if (remaining < 0.38) {
      _waypoint = (_waypoint + 1) % _route.length;
    }
  }

  double _moveToward(MobaPoint target, double dt, double speed) {
    final dx = target.x - _x;
    final dz = target.z - _z;
    final distance = math.sqrt(dx * dx + dz * dz);
    if (distance < 1e-4) return 0;

    _facingRadians = math.atan2(dx, dz);
    final step = math.min(distance, speed * dt);
    _x += dx / distance * step;
    _z += dz / distance * step;
    _clampToLabBounds();
    return distance;
  }

  void _clampToLabBounds() {
    _x = _x.clamp(-2.0, 13.0).toDouble();
    _z = _z.clamp(-60.0, -52.0).toDouble();
  }
}
