import 'package:flutter_test/flutter_test.dart';
import 'package:project_arena_flutter/game/state/match_flow_machine.dart';

void main() {
  group('Match flow', () {
    test('requires assets and countdown before gameplay begins', () {
      final machine = createMatchFlowMachine();

      expect(machine.dispatch(MatchFlowEvent.countdownFinished), isFalse);
      expect(machine.dispatch(MatchFlowEvent.beginAssetLoading), isTrue);
      expect(machine.dispatch(MatchFlowEvent.assetsReady), isTrue);
      expect(machine.state, MatchFlowState.countdown);
      expect(machine.dispatch(MatchFlowEvent.countdownFinished), isTrue);
      expect(machine.state, MatchFlowState.active);
    });

    test('recovers from asset loading failure without corrupting match state',
        () {
      final machine = createMatchFlowMachine();

      machine.dispatch(MatchFlowEvent.beginAssetLoading);
      machine.dispatch(MatchFlowEvent.assetsFailed);
      expect(machine.state, MatchFlowState.failed);

      machine.dispatch(MatchFlowEvent.retryAssetLoading);
      expect(machine.state, MatchFlowState.loadingAssets);
    });

    test('terminal results can only be disposed', () {
      final machine = createMatchFlowMachine();

      machine.dispatch(MatchFlowEvent.beginAssetLoading);
      machine.dispatch(MatchFlowEvent.assetsReady);
      machine.dispatch(MatchFlowEvent.countdownFinished);
      machine.dispatch(MatchFlowEvent.localTeamWon);

      expect(machine.state, MatchFlowState.victory);
      expect(machine.dispatch(MatchFlowEvent.pauseRequested), isFalse);
      expect(machine.dispatch(MatchFlowEvent.dispose), isTrue);
      expect(machine.state, MatchFlowState.disposed);
    });
  });
}
