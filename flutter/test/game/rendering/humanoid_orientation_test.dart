import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:project_arena_flutter/game/rendering/humanoid_orientation.dart';

void main() {
  group('HumanoidOrientation', () {
    test('positive-Z rigs face the movement direction', () {
      expect(HumanoidOrientation.yawForDirection(0, 1), closeTo(0, 1e-9));
      expect(
        HumanoidOrientation.yawForDirection(1, 0),
        closeTo(math.pi / 2, 1e-9),
      );
      expect(
        HumanoidOrientation.yawForDirection(0, -1).abs(),
        closeTo(math.pi, 1e-9),
      );
      expect(
        HumanoidOrientation.yawForDirection(-1, 0),
        closeTo(-math.pi / 2, 1e-9),
      );
    });

    test('negative-Z animated actor rigs face the movement direction', () {
      expect(
        HumanoidOrientation.yawForNegativeZDirection(0, 1).abs(),
        closeTo(math.pi, 1e-9),
      );
      expect(
        HumanoidOrientation.yawForNegativeZDirection(1, 0),
        closeTo(3 * math.pi / 2, 1e-9),
      );
      expect(
        HumanoidOrientation.yawForNegativeZDirection(0, -1),
        closeTo(0, 1e-9),
      );
      expect(
        HumanoidOrientation.yawForNegativeZDirection(-1, 0),
        closeTo(math.pi / 2, 1e-9),
      );
      for (final vector in const [
        (0.7071067812, 0.7071067812),
        (-0.7071067812, 0.7071067812),
        (0.7071067812, -0.7071067812),
        (-0.7071067812, -0.7071067812),
      ]) {
        final yaw = HumanoidOrientation.yawForNegativeZDirection(
          vector.$1,
          vector.$2,
        );
        final facingX = math.sin(yaw + math.pi);
        final facingZ = -math.cos(yaw + math.pi);
        expect(facingX, closeTo(vector.$1, 1e-8));
        expect(facingZ, closeTo(vector.$2, 1e-8));
      }
    });

    test('zero and invalid vectors preserve a stable neutral heading', () {
      expect(HumanoidOrientation.yawForDirection(0, 0), 0);
      expect(HumanoidOrientation.yawForNegativeZDirection(0, 0), 0);
      expect(HumanoidOrientation.yawForDirection(double.nan, 1), 0);
      expect(HumanoidOrientation.yawForNegativeZDirection(1, double.infinity), 0);
    });
  });
}
