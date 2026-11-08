import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:project_arena_flutter/game/match/moba_match_simulation.dart';
import 'package:project_arena_flutter/game/npc/arena_survey_drone_controller.dart';

void main() {
  group('ArenaSurveyDroneController', () {
    test('patrols between authored waypoints when the player is distant', () {
      final drone = ArenaSurveyDroneController();

      for (var frame = 0; frame < 100; frame++) {
        drone.update(
          0.05,
          playerPosition: const MobaPoint(-20, -60),
          playerOnSpringPad: false,
        );
      }

      expect(drone.state, ArenaSurveyDroneState.patrolling);
      expect(drone.position.x, greaterThan(2.4));
      expect(drone.position.x, lessThanOrEqualTo(10.5));
      expect(drone.position.z, closeTo(-55.6, 0.001));
    });

    test('observes the player inside its awareness radius', () {
      final drone = ArenaSurveyDroneController();

      drone.update(
        1 / 60,
        playerPosition: const MobaPoint(4.4, -55.6),
        playerOnSpringPad: false,
      );

      expect(drone.state, ArenaSurveyDroneState.observingPlayer);
      expect(drone.facingRadians, closeTo(math.pi / 2, 0.001));
    });

    test('repositions to preserve space when the player approaches closely',
        () {
      final drone = ArenaSurveyDroneController();
      final before = drone.position;

      drone.update(
        0.05,
        playerPosition: const MobaPoint(2.9, -55.6),
        playerOnSpringPad: false,
      );

      expect(drone.state, ArenaSurveyDroneState.repositioning);
      expect(drone.position.x, lessThan(before.x));
    });

    test('inspects the spring pad when the player activates that location', () {
      final drone = ArenaSurveyDroneController();

      drone.update(
        0.05,
        playerPosition: const MobaPoint(6, -60),
        playerOnSpringPad: true,
      );

      expect(drone.state, ArenaSurveyDroneState.inspectingPlatform);
      expect(drone.stateLabel, 'INSPECIONANDO PLATAFORMA');
      expect(drone.position.x, greaterThan(2.4));
      expect(drone.position.z, lessThan(-55.6));
    });

    test('ignores invalid time steps', () {
      final drone = ArenaSurveyDroneController();
      final before = drone.position;

      drone.update(
        double.nan,
        playerPosition: const MobaPoint(6, -60),
        playerOnSpringPad: true,
      );

      expect(drone.position.x, before.x);
      expect(drone.position.z, before.z);
      expect(drone.state, ArenaSurveyDroneState.patrolling);
    });
  });
}
