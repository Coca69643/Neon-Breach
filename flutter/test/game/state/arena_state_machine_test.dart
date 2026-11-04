import 'package:flutter_test/flutter_test.dart';
import 'package:project_arena_flutter/game/state/arena_state_machine.dart';

void main() {
  late ArenaStateMachine machine;

  setUp(() {
    machine = ArenaStateMachine();
  });

  tearDown(() {
    machine.dispose();
  });

  void reachMainMenu() {
    expect(machine.dispatch(const BootCompleted()).accepted, isTrue);
    expect(
      machine
          .dispatch(
            const ManifestValidationCompleted(valid: true),
          )
          .accepted,
      isTrue,
    );
  }

  void reachMatchLoading() {
    reachMainMenu();
    machine.dispatch(const OpenHeroSelection());
    machine.dispatch(const SelectHero('lyra'));
    machine.dispatch(const ConfirmHeroSelection());
  }

  test('boot exige validação antes de liberar o menu', () {
    expect(machine.snapshot.phase, ArenaPhase.boot);

    machine.dispatch(const BootCompleted());
    expect(machine.snapshot.phase, ArenaPhase.assetValidation);

    machine.dispatch(const ManifestValidationCompleted(valid: true));
    expect(machine.snapshot.phase, ArenaPhase.mainMenu);
  });

  test('evento inválido não altera o estado', () {
    final decision = machine.dispatch(const OpenHeroSelection());

    expect(decision.accepted, isFalse);
    expect(machine.snapshot.phase, ArenaPhase.boot);
  });

  test('não permite confirmar herói sem seleção válida', () {
    reachMainMenu();
    machine.dispatch(const OpenHeroSelection());

    final decision = machine.dispatch(const ConfirmHeroSelection());

    expect(decision.accepted, isFalse);
    expect(machine.snapshot.phase, ArenaPhase.heroSelection);
  });

  test('fluxo de partida, pausa por lifecycle e retomada', () {
    reachMatchLoading();

    expect(machine.snapshot.phase, ArenaPhase.matchLoading);
    expect(
      machine
          .dispatch(const MatchRuntimeCompleted(success: true))
          .accepted,
      isTrue,
    );
    expect(machine.snapshot.phase, ArenaPhase.inMatch);

    machine.dispatch(const AppSuspended());
    expect(machine.snapshot.phase, ArenaPhase.paused);

    machine.dispatch(const AppResumed());
    expect(machine.snapshot.phase, ArenaPhase.inMatch);
  });

  test('pausa manual não é removida automaticamente pelo lifecycle', () {
    reachMatchLoading();
    machine.dispatch(const MatchRuntimeCompleted(success: true));
    machine.dispatch(const PauseMatch());

    machine.dispatch(const AppResumed());

    expect(machine.snapshot.phase, ArenaPhase.paused);

    machine.dispatch(const ResumeMatch());
    expect(machine.snapshot.phase, ArenaPhase.inMatch);
  });

  test('falha de runtime entra em recuperação e mantém alvo de retry', () {
    reachMatchLoading();

    machine.dispatch(
      const MatchRuntimeCompleted(
        success: false,
        reason: 'Falha de inicialização de teste.',
      ),
    );

    expect(machine.snapshot.phase, ArenaPhase.recoverableError);
    expect(machine.snapshot.errorMessage, contains('teste'));

    machine.dispatch(const RetryRecovery());
    expect(machine.snapshot.phase, ArenaPhase.matchLoading);
    expect(machine.snapshot.errorMessage, isNull);
  });

  test('fim de partida limpa o contexto ao voltar ao menu', () {
    reachMatchLoading();
    machine.dispatch(const MatchRuntimeCompleted(success: true));
    machine.dispatch(const MatchFinished(MatchOutcome.victory));

    expect(machine.snapshot.phase, ArenaPhase.matchResult);
    expect(machine.snapshot.matchOutcome, MatchOutcome.victory);

    machine.dispatch(const ReturnToMenu());

    expect(machine.snapshot.phase, ArenaPhase.mainMenu);
    expect(machine.snapshot.selectedHeroId, isNull);
    expect(machine.snapshot.matchOutcome, isNull);
  });
}
