import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../game/manifest/arena_manifest_validator.dart';
import '../game/rendering/arena_hero_preview.dart';
import '../game/state/arena_state_machine.dart';

class ArenaApp extends StatefulWidget {
  const ArenaApp({super.key});

  @override
  State<ArenaApp> createState() => _ArenaAppState();
}

class _ArenaAppState extends State<ArenaApp> with WidgetsBindingObserver {
  late final ArenaStateMachine _machine;

  @override
  void initState() {
    super.initState();
    _machine = ArenaStateMachine();
    WidgetsBinding.instance.addObserver(this);
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    _machine.dispatch(const BootCompleted());
    await _validateManifest();
  }

  Future<void> _validateManifest() async {
    final result = await ArenaManifestValidator.validate(rootBundle);
    if (!mounted) return;

    _machine.dispatch(
      ManifestValidationCompleted(
        valid: result.valid,
        reason: result.issues.join('\n'),
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _machine.dispatch(const AppSuspended());
    } else if (state == AppLifecycleState.resumed) {
      _machine.dispatch(const AppResumed());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _machine.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const background = Color(0xFF10151C);
    const accent = Color(0xFF79D6BD);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Projeto Arena',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: accent,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: background,
        fontFamily: 'Roboto',
      ),
      home: AnimatedBuilder(
        animation: _machine,
        builder: (context, _) => _ArenaScreen(
          snapshot: _machine.snapshot,
          onEvent: _machine.dispatch,
          onRetry: _retry,
        ),
      ),
    );
  }

  Future<void> _retry() async {
    _machine.dispatch(const RetryRecovery());
    if (_machine.snapshot.phase == ArenaPhase.assetValidation) {
      await _validateManifest();
    }
  }
}

class _ArenaScreen extends StatelessWidget {
  const _ArenaScreen({
    required this.snapshot,
    required this.onEvent,
    required this.onRetry,
  });

  final ArenaSnapshot snapshot;
  final TransitionDecision Function(ArenaEvent) onEvent;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1A2731), Color(0xFF10151C), Color(0xFF10151C)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 980),
                child: _buildPhase(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhase() {
    switch (snapshot.phase) {
      case ArenaPhase.boot:
        return const _StatusView(
          eyebrow: 'DUCK DREAM STUDIOS',
          title: 'Projeto Arena',
          description: 'Inicializando aplicação...',
        );
      case ArenaPhase.assetValidation:
        return const _StatusView(
          eyebrow: 'VERIFICAÇÃO',
          title: 'Validando conteúdo',
          description: 'Conferindo o manifesto local da aplicação.',
        );
      case ArenaPhase.mainMenu:
        return _mainMenu();
      case ArenaPhase.heroSelection:
        return _heroSelection();
      case ArenaPhase.matchLoading:
        return _runtimeFoundation();
      case ArenaPhase.inMatch:
        return const _StatusView(
          eyebrow: 'PARTIDA',
          title: 'Runtime conectado',
          description: 'A camada de renderização será apresentada aqui.',
        );
      case ArenaPhase.paused:
        return _paused();
      case ArenaPhase.matchResult:
        return _result();
      case ArenaPhase.recoverableError:
        return _error();
    }
  }

  Widget _mainMenu() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'DUCK DREAM STUDIOS  /  MOBILE',
          style: TextStyle(
            color: Color(0xFF79D6BD),
            fontSize: 12,
            letterSpacing: 2.2,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'PROJETO\nARENA',
          style: TextStyle(
            fontSize: 58,
            height: 0.94,
            letterSpacing: -2.2,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Base Flutter + runtime nativo próprio.\n'
          'Offline • Landscape • Máquina de estados ativa',
          style: TextStyle(color: Color(0xFFB7C2CA), height: 1.5),
        ),
        const SizedBox(height: 30),
        FilledButton.icon(
          onPressed: () => onEvent(const OpenHeroSelection()),
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Text('SELECIONAR HERÓI'),
        ),
        const SizedBox(height: 22),
        const Text(
          'FUNDAÇÃO 0.1  /  PARTIDA 3D AINDA NÃO INTEGRADA',
          style: TextStyle(
            color: Color(0xFF71808B),
            fontSize: 10,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }

  Widget _heroSelection() {
    const heroes = [
      ('lyra', 'LYRA', 'Mobilidade'),
      ('bastion', 'BASTION', 'Linha de frente'),
      ('kairo', 'KAIRO', 'Controle'),
    ];
    final selectedId = snapshot.selectedHeroId ?? 'lyra';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 6,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: ArenaHeroPreview(heroId: selectedId),
          ),
        ),
        const SizedBox(width: 28),
        Expanded(
          flex: 4,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'SELEÇÃO DE HERÓI  /  01',
                style: TextStyle(
                  color: Color(0xFF79D6BD),
                  letterSpacing: 2,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Escolha seu operador',
                style: TextStyle(fontSize: 29, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              const Text(
                'Modelos 3D independentes com animação em tempo real.',
                style: TextStyle(color: Color(0xFFB7C2CA), height: 1.4),
              ),
              const SizedBox(height: 22),
              for (final hero in heroes) ...[
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 13,
                      ),
                      side: BorderSide(
                        color: selectedId == hero.$1
                            ? const Color(0xFF79D6BD)
                            : const Color(0xFF46545E),
                        width: selectedId == hero.$1 ? 2 : 1,
                      ),
                      backgroundColor: selectedId == hero.$1
                          ? const Color(0x2679D6BD)
                          : const Color(0x1479D6BD),
                    ),
                    onPressed: () => onEvent(SelectHero(hero.$1)),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                hero.$2,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.1,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                hero.$3,
                                style: const TextStyle(
                                  color: Color(0xFFB7C2CA), fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (selectedId == hero.$1)
                          const Icon(Icons.check_circle, color: Color(0xFF79D6BD)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              const Spacer(),
              Row(
                children: [
                  TextButton(
                    onPressed: () => onEvent(const ReturnToMenu()),
                    child: const Text('VOLTAR'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: snapshot.selectedHeroId == null
                        ? null
                        : () => onEvent(const ConfirmHeroSelection()),
                    child: const Text('CONTINUAR'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
  Widget _runtimeFoundation() {
    return _StatusView(
      eyebrow: 'ETAPA 01  /  FLUXO VALIDADO',
      title: 'Herói selecionado',
      description:
          'A máquina de estados chegou a MATCH_LOADING. '
          'O runtime Flutter Scene ainda está em integração; '
          'esta etapa não apresenta uma partida fictícia.',
      actionLabel: 'VOLTAR À SELEÇÃO',
      onAction: () => onEvent(const CancelMatchLoading()),
    );
  }

  Widget _paused() {
    return _StatusView(
      eyebrow: 'PAUSA',
      title: 'Partida pausada',
      description: 'O estado da partida foi preservado.',
      actionLabel: 'RETOMAR',
      onAction: () => onEvent(const ResumeMatch()),
      secondaryLabel: 'MENU PRINCIPAL',
      onSecondary: () => onEvent(const ReturnToMenu()),
    );
  }

  Widget _result() {
    final label = switch (snapshot.matchOutcome) {
      MatchOutcome.victory => 'VITÓRIA',
      MatchOutcome.defeat => 'DERROTA',
      MatchOutcome.draw => 'EMPATE',
      null => 'PARTIDA ENCERRADA',
    };
    return _StatusView(
      eyebrow: 'RESULTADO',
      title: label,
      description: 'Resultado recebido pela máquina de estados.',
      actionLabel: 'MENU PRINCIPAL',
      onAction: () => onEvent(const ReturnToMenu()),
    );
  }

  Widget _error() {
    return _StatusView(
      eyebrow: 'RECUPERAÇÃO',
      title: 'Não foi possível continuar',
      description: snapshot.errorMessage ?? 'Erro não identificado.',
      actionLabel: 'TENTAR NOVAMENTE',
      onAction: onRetry,
    );
  }
}

class _StatusView extends StatelessWidget {
  const _StatusView({
    required this.eyebrow,
    required this.title,
    required this.description,
    this.actionLabel,
    this.onAction,
    this.secondaryLabel,
    this.onSecondary,
  });

  final String eyebrow;
  final String title;
  final String description;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow,
          style: const TextStyle(
            color: Color(0xFF79D6BD),
            letterSpacing: 2,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          title,
          style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        Text(
          description,
          style: const TextStyle(
            color: Color(0xFFB7C2CA),
            height: 1.55,
          ),
        ),
        if (actionLabel != null) ...[
          const SizedBox(height: 24),
          Wrap(
            spacing: 12,
            children: [
              FilledButton(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
              if (secondaryLabel != null)
                TextButton(
                  onPressed: onSecondary,
                  child: Text(secondaryLabel!),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
