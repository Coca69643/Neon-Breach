import '../../core/state_machine/state_machine.dart';

enum ActorState {
  spawning,
  idle,
  moving,
  attackWindup,
  attacking,
  recovering,
  hitstun,
  dead,
}

enum ActorEvent {
  spawnComplete,
  movementStarted,
  movementStopped,
  attackRequested,
  attackWindowOpened,
  attackWindowClosed,
  recoveryComplete,
  hitReceived,
  stunExpired,
  killed,
  respawnRequested,
}

StateMachine<ActorState, ActorEvent> createActorStateMachine() {
  const activeStates = <ActorState>[
    ActorState.spawning,
    ActorState.idle,
    ActorState.moving,
    ActorState.attackWindup,
    ActorState.attacking,
    ActorState.recovering,
    ActorState.hitstun,
  ];

  final transitions = <StateTransition<ActorState, ActorEvent>>[
    const StateTransition(
      from: ActorState.spawning,
      event: ActorEvent.spawnComplete,
      to: ActorState.idle,
    ),
    const StateTransition(
      from: ActorState.idle,
      event: ActorEvent.movementStarted,
      to: ActorState.moving,
    ),
    const StateTransition(
      from: ActorState.moving,
      event: ActorEvent.movementStopped,
      to: ActorState.idle,
    ),
    const StateTransition(
      from: ActorState.idle,
      event: ActorEvent.attackRequested,
      to: ActorState.attackWindup,
    ),
    const StateTransition(
      from: ActorState.moving,
      event: ActorEvent.attackRequested,
      to: ActorState.attackWindup,
    ),
    const StateTransition(
      from: ActorState.attackWindup,
      event: ActorEvent.attackWindowOpened,
      to: ActorState.attacking,
    ),
    const StateTransition(
      from: ActorState.attacking,
      event: ActorEvent.attackWindowClosed,
      to: ActorState.recovering,
    ),
    const StateTransition(
      from: ActorState.recovering,
      event: ActorEvent.recoveryComplete,
      to: ActorState.idle,
    ),
    const StateTransition(
      from: ActorState.hitstun,
      event: ActorEvent.stunExpired,
      to: ActorState.idle,
    ),
    const StateTransition(
      from: ActorState.dead,
      event: ActorEvent.respawnRequested,
      to: ActorState.spawning,
    ),
  ];

  for (final state in activeStates) {
    if (state != ActorState.hitstun) {
      transitions.add(
        StateTransition<ActorState, ActorEvent>(
          from: state,
          event: ActorEvent.hitReceived,
          to: ActorState.hitstun,
        ),
      );
    }
    transitions.add(
      StateTransition<ActorState, ActorEvent>(
        from: state,
        event: ActorEvent.killed,
        to: ActorState.dead,
      ),
    );
  }

  transitions.add(
    const StateTransition(
      from: ActorState.hitstun,
      event: ActorEvent.killed,
      to: ActorState.dead,
    ),
  );

  return StateMachine<ActorState, ActorEvent>(
    initialState: ActorState.spawning,
    transitions: transitions,
  );
}
