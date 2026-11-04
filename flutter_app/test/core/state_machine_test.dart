import 'package:flutter_test/flutter_test.dart';
import 'package:project_arena_flutter/core/state_machine/state_machine.dart';

enum TestState { cold, ready, running, failed }

enum TestEvent { initialize, start, crash, reset }

void main() {
  group('StateMachine', () {
    late StateMachine<TestState, TestEvent> machine;

    setUp(() {
      machine = StateMachine<TestState, TestEvent>(
        initialState: TestState.cold,
        transitions: const <StateTransition<TestState, TestEvent>>[
          StateTransition(
            from: TestState.cold,
            event: TestEvent.initialize,
            to: TestState.ready,
          ),
          StateTransition(
            from: TestState.ready,
            event: TestEvent.start,
            to: TestState.running,
          ),
          StateTransition(
            from: TestState.running,
            event: TestEvent.crash,
            to: TestState.failed,
          ),
          StateTransition(
            from: TestState.failed,
            event: TestEvent.reset,
            to: TestState.cold,
          ),
        ],
      );
    });

    test('accepts only transitions declared for the current state', () {
      expect(machine.state, TestState.cold);
      expect(machine.canDispatch(TestEvent.initialize), isTrue);
      expect(machine.canDispatch(TestEvent.start), isFalse);

      expect(machine.dispatch(TestEvent.start), isFalse);
      expect(machine.state, TestState.cold);
      expect(machine.revision, 0);

      expect(machine.dispatch(TestEvent.initialize), isTrue);
      expect(machine.state, TestState.ready);
      expect(machine.revision, 1);
    });

    test('emits an immutable transition record after mutation', () {
      StateTransitionRecord<TestState, TestEvent>? observed;
      machine.addListener((record) => observed = record);

      machine.dispatch(TestEvent.initialize);

      expect(observed, isNotNull);
      expect(observed!.previous, TestState.cold);
      expect(observed!.current, TestState.ready);
      expect(observed!.event, TestEvent.initialize);
      expect(observed!.revision, 1);
    });

    test('rejects duplicate routes during construction', () {
      expect(
        () => StateMachine<TestState, TestEvent>(
          initialState: TestState.cold,
          transitions: const <StateTransition<TestState, TestEvent>>[
            StateTransition(
              from: TestState.cold,
              event: TestEvent.initialize,
              to: TestState.ready,
            ),
            StateTransition(
              from: TestState.cold,
              event: TestEvent.initialize,
              to: TestState.failed,
            ),
          ],
        ),
        throwsArgumentError,
      );
    });

    test('rejects self transitions during construction', () {
      expect(
        () => StateMachine<TestState, TestEvent>(
          initialState: TestState.cold,
          transitions: const <StateTransition<TestState, TestEvent>>[
            StateTransition(
              from: TestState.cold,
              event: TestEvent.initialize,
              to: TestState.cold,
            ),
          ],
        ),
        throwsArgumentError,
      );
    });

    test('rejects re-entrant dispatch from listeners', () {
      machine.addListener((_) {
        machine.dispatch(TestEvent.start);
      });

      expect(
        () => machine.dispatch(TestEvent.initialize),
        throwsStateError,
      );
      // The accepted transition is already committed before notification.
      expect(machine.state, TestState.ready);
      expect(machine.revision, 1);
    });

    test('removing a listener prevents later notifications', () {
      var notifications = 0;
      void listener(StateTransitionRecord<TestState, TestEvent> _) {
        notifications += 1;
      }

      machine.addListener(listener);
      machine.removeListener(listener);
      machine.dispatch(TestEvent.initialize);

      expect(notifications, 0);
    });
  });
}
