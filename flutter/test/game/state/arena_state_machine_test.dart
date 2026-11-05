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
    expect(machine.snapshot.selectedHeroId, 'lyra');
  });

  test('evento inválido não altera o estado', () {
    final decision = machine.dispatch(const OpenHeroSelection());

    expect(decision.accepted, isFalse);
    expect(machine.snapshot.phase, ArenaPhase.boot);
  });

  test('CTA do hub inicia a prévia com o herói atual e pode voltar ao menu', () {
    reachMainMenu();

    final start = machine.dispatch(const StartRunFromHub());
    expect(start.accepted, isTrue);
    expect(machine.snapshot.phase, ArenaPhase.matchLoading);
    expect(machine.snapshot.selectedHeroId, 'lyra');

    machine.dispatch(const ReturnToMenu());
    expect(machine.snapshot.phase, ArenaPhase.mainMenu);
    expect(machine.snapshot.selectedHeroId, 'lyra');
  });

  test('abre a seleção com Lyra ativa e permite trocar de herói', () {
    reachMainMenu();
    machine.dispatch(const OpenHeroSelection());

    expect(machine.snapshot.selectedHeroId, 'lyra');

    machine.dispatch(const SelectHero('bastion'));
    expect(machine.snapshot.selectedHeroId, 'bastion');

    machine.dispatch(const SelectHero('kairo'));
    expect(machine.snapshot.selectedHeroId, 'kairo');

    final decision = machine.dispatch(const ConfirmHeroSelection());
    expect(decision.accepted, isTrue);
    expect(machine.snapshot.phase, ArenaPhase.matchLoading);
    expect(machine.snapshot.selectedHeroId, 'kairo');
  });

  test('recusa IDs de herói desconhecidos sem perder a seleção atual', () {
    reachMainMenu();
    machine.dispatch(const OpenHeroSelection());

    final decision = machine.dispatch(const SelectHero('unknown-hero'));

    expect(decision.accepted, isFalse);
    expect(machine.snapshot.selectedHeroId, 'lyra');
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
    expect(machine.snapshot.selectedHeroId, 'lyra');
    expect(machine.snapshot.matchOutcome, isNull);
  });
}
