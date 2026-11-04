import '../../core/state_machine/state_machine.dart';

enum BotDecisionState {
  spawning,
  lanePatrol,
  engage,
  defendBase,
  captureNeutralCamp,
  contestObjective,
  retreat,
  dead,
}

enum BotDecisionEvent {
  spawnComplete,
  threatDetected,
  targetLost,
  baseThreatened,
  baseSafe,
  neutralCampAvailable,
  neutralCampCleared,
  objectiveCalled,
  objectiveResolved,
  healthCritical,
  healthRecovered,
  killed,
  respawnRequested,
}

StateMachine<BotDecisionState, BotDecisionEvent> createBotDecisionMachine() {
  const livingStates = <BotDecisionState>[
    BotDecisionState.spawning,
    BotDecisionState.lanePatrol,
    BotDecisionState.engage,
    BotDecisionState.defendBase,
    BotDecisionState.captureNeutralCamp,
    BotDecisionState.contestObjective,
    BotDecisionState.retreat,
  ];

  final transitions = <StateTransition<BotDecisionState, BotDecisionEvent>>[
    const StateTransition(
      from: BotDecisionState.spawning,
      event: BotDecisionEvent.spawnComplete,
      to: BotDecisionState.lanePatrol,
    ),
    const StateTransition(
      from: BotDecisionState.lanePatrol,
      event: BotDecisionEvent.threatDetected,
      to: BotDecisionState.engage,
    ),
    const StateTransition(
      from: BotDecisionState.engage,
      event: BotDecisionEvent.targetLost,
      to: BotDecisionState.lanePatrol,
    ),
    const StateTransition(
      from: BotDecisionState.lanePatrol,
      event: BotDecisionEvent.baseThreatened,
      to: BotDecisionState.defendBase,
    ),
    const StateTransition(
      from: BotDecisionState.defendBase,
      event: BotDecisionEvent.baseSafe,
      to: BotDecisionState.lanePatrol,
    ),
    const StateTransition(
      from: BotDecisionState.lanePatrol,
      event: BotDecisionEvent.neutralCampAvailable,
      to: BotDecisionState.captureNeutralCamp,
    ),
    const StateTransition(
      from: BotDecisionState.captureNeutralCamp,
      event: BotDecisionEvent.neutralCampCleared,
      to: BotDecisionState.lanePatrol,
    ),
    const StateTransition(
      from: BotDecisionState.lanePatrol,
      event: BotDecisionEvent.objectiveCalled,
      to: BotDecisionState.contestObjective,
    ),
    const StateTransition(
      from: BotDecisionState.contestObjective,
      event: BotDecisionEvent.objectiveResolved,
      to: BotDecisionState.lanePatrol,
    ),
    const StateTransition(
      from: BotDecisionState.engage,
      event: BotDecisionEvent.healthCritical,
      to: BotDecisionState.retreat,
    ),
    const StateTransition(
      from: BotDecisionState.retreat,
      event: BotDecisionEvent.healthRecovered,
      to: BotDecisionState.lanePatrol,
    ),
    const StateTransition(
      from: BotDecisionState.retreat,
      event: BotDecisionEvent.threatDetected,
      to: BotDecisionState.engage,
    ),
    const StateTransition(
      from: BotDecisionState.lanePatrol,
      event: BotDecisionEvent.healthCritical,
      to: BotDecisionState.retreat,
    ),
    const StateTransition(
      from: BotDecisionState.defendBase,
      event: BotDecisionEvent.healthCritical,
      to: BotDecisionState.retreat,
    ),
    const StateTransition(
      from: BotDecisionState.captureNeutralCamp,
      event: BotDecisionEvent.healthCritical,
      to: BotDecisionState.retreat,
    ),
    const StateTransition(
      from: BotDecisionState.contestObjective,
      event: BotDecisionEvent.healthCritical,
      to: BotDecisionState.retreat,
    ),
    const StateTransition(
      from: BotDecisionState.dead,
      event: BotDecisionEvent.respawnRequested,
      to: BotDecisionState.spawning,
    ),
  ];

  for (final state in livingStates) {
    transitions.add(
      StateTransition<BotDecisionState, BotDecisionEvent>(
        from: state,
        event: BotDecisionEvent.killed,
        to: BotDecisionState.dead,
      ),
    );
  }

  return StateMachine<BotDecisionState, BotDecisionEvent>(
    initialState: BotDecisionState.spawning,
    transitions: transitions,
  );
}
