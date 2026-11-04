import 'package:flutter_test/flutter_test.dart';
import 'package:project_arena_flutter/app/state/app_flow_machine.dart';

void main() {
  group('Application flow', () {
    test('follows boot, selection, loading, pause and result paths', () {
      final machine = createAppFlowMachine();

      expect(machine.state, AppFlowState.booting);
      expect(machine.dispatch(AppFlowEvent.bootstrapCompleted), isTrue);
      expect(machine.state, AppFlowState.mainMenu);

      expect(machine.dispatch(AppFlowEvent.openHeroSelection), isTrue);
      expect(machine.state, AppFlowState.heroSelection);

      expect(machine.dispatch(AppFlowEvent.confirmHeroSelection), isTrue);
      expect(machine.state, AppFlowState.matchLoading);

      expect(machine.dispatch(AppFlowEvent.matchPrepared), isTrue);
      expect(machine.state, AppFlowState.inMatch);

      expect(machine.dispatch(AppFlowEvent.pauseRequested), isTrue);
      expect(machine.state, AppFlowState.paused);

      expect(machine.dispatch(AppFlowEvent.resumeRequested), isTrue);
      expect(machine.state, AppFlowState.inMatch);

      expect(machine.dispatch(AppFlowEvent.matchWon), isTrue);
      expect(machine.state, AppFlowState.matchResults);

      expect(machine.dispatch(AppFlowEvent.returnToMenu), isTrue);
      expect(machine.state, AppFlowState.mainMenu);
    });

    test('routes startup and match failures into an explicit recovery state',
        () {
      final machine = createAppFlowMachine();

      expect(machine.dispatch(AppFlowEvent.bootstrapFailed), isTrue);
      expect(machine.state, AppFlowState.recovery);

      expect(machine.dispatch(AppFlowEvent.retryBootstrap), isTrue);
      expect(machine.state, AppFlowState.booting);

      expect(machine.dispatch(AppFlowEvent.bootstrapCompleted), isTrue);
      expect(machine.dispatch(AppFlowEvent.openHeroSelection), isTrue);
      expect(machine.dispatch(AppFlowEvent.confirmHeroSelection), isTrue);
      expect(machine.dispatch(AppFlowEvent.matchLoadFailed), isTrue);
      expect(machine.state, AppFlowState.recovery);
    });

    test('does not permit pausing before a match is active', () {
      final machine = createAppFlowMachine();

      expect(machine.dispatch(AppFlowEvent.pauseRequested), isFalse);
      expect(machine.state, AppFlowState.booting);
    });
  });
}
