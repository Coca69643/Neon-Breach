import 'package:flutter_test/flutter_test.dart';
import 'package:project_arena_flutter/game/simulation/fixed_step_clock.dart';

void main() {
  group('FixedStepClock', () {
    test('accumulates fractional frames into exact fixed updates', () {
      final clock = FixedStepClock();
      final updates = <double>[];

      expect(clock.advance(1 / 120, updates.add), 0);
      expect(clock.advance(1 / 120, updates.add), 1);

      expect(updates, hasLength(1));
      expect(updates.single, closeTo(1 / 60, 1e-12));
      expect(clock.interpolationAlpha, closeTo(0, 1e-9));
    });

    test('bounds catch-up work after a long frame stall', () {
      final clock = FixedStepClock(maxStepsPerFrame: 4);
      var updateCount = 0;

      final steps = clock.advance(0.5, (_) => updateCount += 1);

      expect(steps, 4);
      expect(updateCount, 4);
      expect(clock.interpolationAlpha, inInclusiveRange(0, 1));
      expect(clock.droppedTimeSeconds, greaterThan(0));
    });

    test('rejects invalid timing input', () {
      final clock = FixedStepClock();

      expect(
        () => clock.advance(-0.01, (_) {}),
        throwsArgumentError,
      );
      expect(
        () => clock.advance(double.nan, (_) {}),
        throwsArgumentError,
      );
      expect(
        () => clock.advance(double.infinity, (_) {}),
        throwsArgumentError,
      );
    });

    test('reset clears accumulator and dropped time', () {
      final clock = FixedStepClock();
      clock.advance(0.5, (_) {});

      clock.reset();

      expect(clock.interpolationAlpha, 0);
      expect(clock.droppedTimeSeconds, 0);
    });
  });
}
