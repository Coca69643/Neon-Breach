import 'package:flutter/foundation.dart';

enum ArenaPhase {
  boot,
  assetValidation,
  mainMenu,
  heroSelection,
  matchLoading,
  inMatch,
  paused,
  matchResult,
  recoverableError,
}

enum PauseOrigin { user, lifecycle }

enum MatchOutcome { victory, defeat, draw }

@immutable
class ArenaSnapshot {
  const ArenaSnapshot({
    required this.phase,
    this.selectedHeroId,
    this.errorMessage,
    this.recoveryPhase,
    this.matchOutcome,
    this.resumePhase,
    this.pauseOrigin,
  });

  final ArenaPhase phase;
  final String? selectedHeroId;
  final String? errorMessage;
  final ArenaPhase? recoveryPhase;
  final MatchOutcome? matchOutcome;
  final ArenaPhase? resumePhase;
  final PauseOrigin? pauseOrigin;

  ArenaSnapshot copyWith({
    ArenaPhase? phase,
    String? selectedHeroId,
    bool clearSelectedHeroId = false,
    String? errorMessage,
    bool clearErrorMessage = false,
    ArenaPhase? recoveryPhase,
    bool clearRecoveryPhase = false,
    MatchOutcome? matchOutcome,
    bool clearMatchOutcome = false,
    ArenaPhase? resumePhase,
    bool clearResumePhase = false,
    PauseOrigin? pauseOrigin,
    bool clearPauseOrigin = false,
  }) {
    return ArenaSnapshot(
      phase: phase ?? this.phase,
      selectedHeroId: clearSelectedHeroId
          ? null
          : selectedHeroId ?? this.selectedHeroId,
      errorMessage: clearErrorMessage
          ? null
          : errorMessage ?? this.errorMessage,
      recoveryPhase: clearRecoveryPhase
          ? null
          : recoveryPhase ?? this.recoveryPhase,
      matchOutcome: clearMatchOutcome
          ? null
          : matchOutcome ?? this.matchOutcome,
      resumePhase: clearResumePhase
          ? null
          : resumePhase ?? this.resumePhase,
      pauseOrigin: clearPauseOrigin
          ? null
          : pauseOrigin ?? this.pauseOrigin,
    );
  }
}

sealed class ArenaEvent {
  const ArenaEvent();
}

final class BootCompleted extends ArenaEvent {
  const BootCompleted();
}

final class ManifestValidationCompleted extends ArenaEvent {
  const ManifestValidationCompleted({
    required this.valid,
    this.reason,
  });

  final bool valid;
  final String? reason;
}

final class OpenHeroSelection extends ArenaEvent {
  const OpenHeroSelection();
}

final class SelectHero extends ArenaEvent {
  const SelectHero(this.heroId);

  final String heroId;
}

final class ConfirmHeroSelection extends ArenaEvent {
  const ConfirmHeroSelection();
}

final class StartRunFromHub extends ArenaEvent {
  const StartRunFromHub();
}

final class CancelMatchLoading extends ArenaEvent {
  const CancelMatchLoading();
}

final class MatchRuntimeCompleted extends ArenaEvent {
  const MatchRuntimeCompleted({
    required this.success,
    this.reason,
  });

  final bool success;
  final String? reason;
}

final class PauseMatch extends ArenaEvent {
  const PauseMatch();
}

final class ResumeMatch extends ArenaEvent {
  const ResumeMatch();
}

final class AppSuspended extends ArenaEvent {
  const AppSuspended();
}

final class AppResumed extends ArenaEvent {
  const AppResumed();
}

final class MatchFinished extends ArenaEvent {
  const MatchFinished(this.outcome);

  final MatchOutcome outcome;
}

final class ReturnToMenu extends ArenaEvent {
  const ReturnToMenu();
}

final class RetryRecovery extends ArenaEvent {
  const RetryRecovery();
}

@immutable
class TransitionDecision {
  const TransitionDecision.accepted()
      : accepted = true,
        reason = null;

  const TransitionDecision.rejected(this.reason) : accepted = false;

  final bool accepted;
  final String? reason;
}

class ArenaStateMachine extends ChangeNotifier {
  ArenaStateMachine()
      : _snapshot = const ArenaSnapshot(phase: ArenaPhase.boot);

  static const Set<String> supportedHeroIds = {
    'lyra',
    'bastion',
    'kairo',
  };

  ArenaSnapshot _snapshot;

  ArenaSnapshot get snapshot => _snapshot;

  TransitionDecision dispatch(ArenaEvent event) {
    final next = _reduce(_snapshot, event);
    if (next == null) {
      return const TransitionDecision.rejected(
        'Evento inválido para o estado atual.',
      );
    }

    _snapshot = next;
    notifyListeners();
    return const TransitionDecision.accepted();
  }

  ArenaSnapshot? _reduce(ArenaSnapshot current, ArenaEvent event) {
    if (event is BootCompleted && current.phase == ArenaPhase.boot) {
      return const ArenaSnapshot(phase: ArenaPhase.assetValidation);
    }

    if (event is ManifestValidationCompleted &&
        current.phase == ArenaPhase.assetValidation) {
      if (event.valid) {
        return const ArenaSnapshot(
          phase: ArenaPhase.mainMenu,
          selectedHeroId: 'lyra',
        );
      }
      return ArenaSnapshot(
        phase: ArenaPhase.recoverableError,
        errorMessage: event.reason ?? 'Manifesto de conteúdo inválido.',
        recoveryPhase: ArenaPhase.assetValidation,
      );
    }

    if (event is OpenHeroSelection &&
        current.phase == ArenaPhase.mainMenu) {
      return current.copyWith(phase: ArenaPhase.heroSelection);
    }

    if (event is StartRunFromHub &&
        current.phase == ArenaPhase.mainMenu &&
        current.selectedHeroId != null) {
      return current.copyWith(
        phase: ArenaPhase.matchLoading,
        clearErrorMessage: true,
        clearMatchOutcome: true,
      );
    }

    if (event is SelectHero &&
        current.phase == ArenaPhase.heroSelection &&
        supportedHeroIds.contains(event.heroId)) {
      return current.copyWith(
        selectedHeroId: event.heroId,
        clearErrorMessage: true,
      );
    }

    if (event is ConfirmHeroSelection &&
        current.phase == ArenaPhase.heroSelection &&
        current.selectedHeroId != null) {
      return current.copyWith(
        phase: ArenaPhase.mainMenu,
        clearErrorMessage: true,
      );
    }

    if (event is CancelMatchLoading &&
        current.phase == ArenaPhase.matchLoading) {
      return current.copyWith(
        phase: ArenaPhase.heroSelection,
        clearErrorMessage: true,
      );
    }

    if (event is MatchRuntimeCompleted &&
        current.phase == ArenaPhase.matchLoading) {
      if (event.success) {
        return current.copyWith(
          phase: ArenaPhase.inMatch,
          clearErrorMessage: true,
          clearRecoveryPhase: true,
        );
      }
      return current.copyWith(
        phase: ArenaPhase.recoverableError,
        errorMessage: event.reason ?? 'Falha ao iniciar o runtime 3D Flutter Scene.',
        recoveryPhase: ArenaPhase.matchLoading,
      );
    }

    if (event is PauseMatch && current.phase == ArenaPhase.inMatch) {
      return current.copyWith(
        phase: ArenaPhase.paused,
        resumePhase: ArenaPhase.inMatch,
        pauseOrigin: PauseOrigin.user,
      );
    }

    if (event is AppSuspended && current.phase == ArenaPhase.inMatch) {
      return current.copyWith(
        phase: ArenaPhase.paused,
        resumePhase: ArenaPhase.inMatch,
        pauseOrigin: PauseOrigin.lifecycle,
      );
    }

    if (event is ResumeMatch && current.phase == ArenaPhase.paused) {
      return _resume(current);
    }

    if (event is AppResumed &&
        current.phase == ArenaPhase.paused &&
        current.pauseOrigin == PauseOrigin.lifecycle) {
      return _resume(current);
    }

    if (event is MatchFinished && current.phase == ArenaPhase.inMatch) {
      return current.copyWith(
        phase: ArenaPhase.matchResult,
        matchOutcome: event.outcome,
      );
    }

    if (event is ReturnToMenu &&
        (current.phase == ArenaPhase.heroSelection ||
            current.phase == ArenaPhase.matchLoading ||
            current.phase == ArenaPhase.paused ||
            current.phase == ArenaPhase.matchResult ||
            (current.phase == ArenaPhase.recoverableError &&
                current.recoveryPhase == ArenaPhase.matchLoading))) {
      return current.copyWith(
        phase: ArenaPhase.mainMenu,
        clearErrorMessage: true,
        clearRecoveryPhase: true,
        clearMatchOutcome: true,
        clearResumePhase: true,
        clearPauseOrigin: true,
      );
    }

    if (event is RetryRecovery &&
        current.phase == ArenaPhase.recoverableError) {
      return current.copyWith(
        phase: current.recoveryPhase ?? ArenaPhase.assetValidation,
        clearErrorMessage: true,
        clearRecoveryPhase: true,
      );
    }

    return null;
  }

  ArenaSnapshot? _resume(ArenaSnapshot current) {
    final target = current.resumePhase;
    if (target == null ||
        (target != ArenaPhase.inMatch && target != ArenaPhase.matchLoading)) {
      return null;
    }
    return current.copyWith(
      phase: target,
      clearResumePhase: true,
      clearPauseOrigin: true,
    );
  }
}
