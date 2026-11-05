import 'package:flutter_test/flutter_test.dart';
import 'package:project_arena_flutter/game/state/arena_state_machine.dart';

void main() {
  test('application state machine starts in BOOT', () {
    final machine = ArenaStateMachine();
    addTearDown(machine.dispose);

    expect(machine.snapshot.phase, ArenaPhase.boot);
  });
}
