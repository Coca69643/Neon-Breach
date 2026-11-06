import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:project_arena_flutter/game/rendering/humanoid_orientation.dart';

void main() {
  group('HumanoidOrientation', () {
    test('local -Z rig faces the same direction as world movement', () {
      expect(
        HumanoidOrientation.yawForDirection(0, 1).abs(),
        closeTo(math.pi, 1e-9),
      );
      expect(
        HumanoidOrientation.yawForDirection(1, 0),
        closeTo(3 * math.pi / 2, 1e-9),
      );
      expect(
        HumanoidOrientation.yawForDirection(0, -1),
        closeTo(0, 1e-9),
      );
      expect(
        HumanoidOrientation.yawForDirection(-1, 0),
        closeTo(math.pi / 2, 1e-9),
      );
    });

    test('zero and invalid direction preserve a stable neutral heading', () {
      expect(HumanoidOrientation.yawForDirection(0, 0), 0);
      expect(HumanoidOrientation.yawForDirection(double.nan, 1), 0);
      expect(HumanoidOrientation.yawForDirection(1, double.infinity), 0);
    });
  });
}
