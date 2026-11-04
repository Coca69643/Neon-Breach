import '../../core/state_machine/state_machine.dart';

enum MatchFlowState {
  created,
  loadingAssets,
  countdown,
  active,
  paused,
  victory,
  defeat,
  failed,
  disposed,
}

enum MatchFlowEvent {
  beginAssetLoading,
  assetsReady,
  assetsFailed,
  retryAssetLoading,
  countdownFinished,
  pauseRequested,
  resumeRequested,
  localTeamWon,
  localTeamLost,
  leaveMatch,
  dispose,
}

StateMachine<MatchFlowState, MatchFlowEvent> createMatchFlowMachine() {
  return StateMachine<MatchFlowState, MatchFlowEvent>(
    initialState: MatchFlowState.created,
    transitions: const <StateTransition<MatchFlowState, MatchFlowEvent>>[
      StateTransition(
        from: MatchFlowState.created,
        event: MatchFlowEvent.beginAssetLoading,
        to: MatchFlowState.loadingAssets,
      ),
      StateTransition(
        from: MatchFlowState.loadingAssets,
        event: MatchFlowEvent.assetsReady,
        to: MatchFlowState.countdown,
      ),
      StateTransition(
        from: MatchFlowState.loadingAssets,
        event: MatchFlowEvent.assetsFailed,
        to: MatchFlowState.failed,
      ),
      StateTransition(
        from: MatchFlowState.failed,
        event: MatchFlowEvent.retryAssetLoading,
        to: MatchFlowState.loadingAssets,
      ),
      StateTransition(
        from: MatchFlowState.countdown,
        event: MatchFlowEvent.countdownFinished,
        to: MatchFlowState.active,
      ),
      StateTransition(
        from: MatchFlowState.active,
        event: MatchFlowEvent.pauseRequested,
        to: MatchFlowState.paused,
      ),
      StateTransition(
        from: MatchFlowState.paused,
        event: MatchFlowEvent.resumeRequested,
        to: MatchFlowState.active,
      ),
      StateTransition(
        from: MatchFlowState.active,
        event: MatchFlowEvent.localTeamWon,
        to: MatchFlowState.victory,
      ),
      StateTransition(
        from: MatchFlowState.active,
        event: MatchFlowEvent.localTeamLost,
        to: MatchFlowState.defeat,
      ),
      StateTransition(
        from: MatchFlowState.paused,
        event: MatchFlowEvent.localTeamWon,
        to: MatchFlowState.victory,
      ),
      StateTransition(
        from: MatchFlowState.paused,
        event: MatchFlowEvent.localTeamLost,
        to: MatchFlowState.defeat,
      ),
      StateTransition(
        from: MatchFlowState.created,
        event: MatchFlowEvent.leaveMatch,
        to: MatchFlowState.disposed,
      ),
      StateTransition(
        from: MatchFlowState.loadingAssets,
        event: MatchFlowEvent.leaveMatch,
        to: MatchFlowState.disposed,
      ),
      StateTransition(
        from: MatchFlowState.countdown,
        event: MatchFlowEvent.leaveMatch,
        to: MatchFlowState.disposed,
      ),
      StateTransition(
        from: MatchFlowState.active,
        event: MatchFlowEvent.leaveMatch,
        to: MatchFlowState.disposed,
      ),
      StateTransition(
        from: MatchFlowState.paused,
        event: MatchFlowEvent.leaveMatch,
        to: MatchFlowState.disposed,
      ),
      StateTransition(
        from: MatchFlowState.victory,
        event: MatchFlowEvent.dispose,
        to: MatchFlowState.disposed,
      ),
      StateTransition(
        from: MatchFlowState.defeat,
        event: MatchFlowEvent.dispose,
        to: MatchFlowState.disposed,
      ),
      StateTransition(
        from: MatchFlowState.failed,
        event: MatchFlowEvent.dispose,
        to: MatchFlowState.disposed,
      ),
    ],
  );
}
