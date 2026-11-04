import 'package:flutter_test/flutter_test.dart';
import 'package:project_arena_flutter/game/actors/actor_state_machine.dart';

void main() {
  group('Actor state machine', () {
    test('keeps attack phases in a deterministic sequence', () {
      final actor = createActorStateMachine();

      expect(actor.state, ActorState.spawning);
      expect(actor.dispatch(ActorEvent.spawnComplete), isTrue);
      expect(actor.dispatch(ActorEvent.movementStarted), isTrue);
      expect(actor.state, ActorState.moving);
      expect(actor.dispatch(ActorEvent.attackRequested), isTrue);
      expect(actor.state, ActorState.attackWindup);
      expect(actor.dispatch(ActorEvent.attackWindowOpened), isTrue);
      expect(actor.state, ActorState.attacking);
      expect(actor.dispatch(ActorEvent.attackWindowClosed), isTrue);
      expect(actor.state, ActorState.recovering);
      expect(actor.dispatch(ActorEvent.recoveryComplete), isTrue);
      expect(actor.state, ActorState.idle);
    });

    test('death interrupts any active actor state', () {
      for (final state in ActorState.values) {
        if (state == ActorState.dead) continue;

        final actor = createActorStateMachine();
        while (actor.state != state) {
          if (actor.state == ActorState.spawning) {
            actor.dispatch(ActorEvent.spawnComplete);
          } else {
            break;
          }
        }

        if (state == ActorState.moving) {
          actor.dispatch(ActorEvent.movementStarted);
        } else if (state == ActorState.hitstun) {
          actor.dispatch(ActorEvent.hitReceived);
        } else if (state == ActorState.attackWindup) {
          actor.dispatch(ActorEvent.attackRequested);
        } else if (state == ActorState.attacking) {
          actor.dispatch(ActorEvent.attackRequested);
          actor.dispatch(ActorEvent.attackWindowOpened);
        } else if (state == ActorState.recovering) {
          actor.dispatch(ActorEvent.attackRequested);
          actor.dispatch(ActorEvent.attackWindowOpened);
          actor.dispatch(ActorEvent.attackWindowClosed);
        }

        expect(
          actor.dispatch(ActorEvent.killed),
          isTrue,
          reason: 'killed should be accepted from $state',
        );
        expect(actor.state, ActorState.dead);
      }
    });

    test('rejects locomotion after death until respawn', () {
      final actor = createActorStateMachine();
      actor.dispatch(ActorEvent.spawnComplete);
      actor.dispatch(ActorEvent.killed);

      expect(actor.dispatch(ActorEvent.movementStarted), isFalse);
      expect(actor.dispatch(ActorEvent.respawnRequested), isTrue);
      expect(actor.state, ActorState.spawning);
    });
  });
}
