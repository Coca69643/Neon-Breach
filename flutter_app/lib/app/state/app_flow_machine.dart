import '../../core/state_machine/state_machine.dart';

enum AppFlowState {
  booting,
  mainMenu,
  heroSelection,
  matchLoading,
  inMatch,
  paused,
  matchResults,
  recovery,
}

enum AppFlowEvent {
  bootstrapCompleted,
  bootstrapFailed,
  openHeroSelection,
  cancelHeroSelection,
  confirmHeroSelection,
  matchPrepared,
  matchLoadFailed,
  cancelMatchLoading,
  pauseRequested,
  resumeRequested,
  matchWon,
  matchLost,
  returnToMenu,
  retryBootstrap,
}

StateMachine<AppFlowState, AppFlowEvent> createAppFlowMachine() {
  return StateMachine<AppFlowState, AppFlowEvent>(
    initialState: AppFlowState.booting,
    transitions: const <StateTransition<AppFlowState, AppFlowEvent>>[
      StateTransition(
        from: AppFlowState.booting,
        event: AppFlowEvent.bootstrapCompleted,
        to: AppFlowState.mainMenu,
      ),
      StateTransition(
        from: AppFlowState.booting,
        event: AppFlowEvent.bootstrapFailed,
        to: AppFlowState.recovery,
      ),
      StateTransition(
        from: AppFlowState.mainMenu,
        event: AppFlowEvent.openHeroSelection,
        to: AppFlowState.heroSelection,
      ),
      StateTransition(
        from: AppFlowState.heroSelection,
        event: AppFlowEvent.cancelHeroSelection,
        to: AppFlowState.mainMenu,
      ),
      StateTransition(
        from: AppFlowState.heroSelection,
        event: AppFlowEvent.confirmHeroSelection,
        to: AppFlowState.matchLoading,
      ),
      StateTransition(
        from: AppFlowState.mainMenu,
        event: AppFlowEvent.confirmHeroSelection,
        to: AppFlowState.matchLoading,
      ),
      StateTransition(
        from: AppFlowState.matchLoading,
        event: AppFlowEvent.matchPrepared,
        to: AppFlowState.inMatch,
      ),
      StateTransition(
        from: AppFlowState.matchLoading,
        event: AppFlowEvent.matchLoadFailed,
        to: AppFlowState.recovery,
      ),
      StateTransition(
        from: AppFlowState.matchLoading,
        event: AppFlowEvent.cancelMatchLoading,
        to: AppFlowState.mainMenu,
      ),
      StateTransition(
        from: AppFlowState.inMatch,
        event: AppFlowEvent.pauseRequested,
        to: AppFlowState.paused,
      ),
      StateTransition(
        from: AppFlowState.paused,
        event: AppFlowEvent.resumeRequested,
        to: AppFlowState.inMatch,
      ),
      StateTransition(
        from: AppFlowState.inMatch,
        event: AppFlowEvent.matchWon,
        to: AppFlowState.matchResults,
      ),
      StateTransition(
        from: AppFlowState.inMatch,
        event: AppFlowEvent.matchLost,
        to: AppFlowState.matchResults,
      ),
      StateTransition(
        from: AppFlowState.paused,
        event: AppFlowEvent.matchWon,
        to: AppFlowState.matchResults,
      ),
      StateTransition(
        from: AppFlowState.paused,
        event: AppFlowEvent.matchLost,
        to: AppFlowState.matchResults,
      ),
      StateTransition(
        from: AppFlowState.matchResults,
        event: AppFlowEvent.returnToMenu,
        to: AppFlowState.mainMenu,
      ),
      StateTransition(
        from: AppFlowState.recovery,
        event: AppFlowEvent.retryBootstrap,
        to: AppFlowState.booting,
      ),
      StateTransition(
        from: AppFlowState.recovery,
        event: AppFlowEvent.returnToMenu,
        to: AppFlowState.mainMenu,
      ),
      StateTransition(
        from: AppFlowState.paused,
        event: AppFlowEvent.returnToMenu,
        to: AppFlowState.mainMenu,
      ),
    ],
  );
}
