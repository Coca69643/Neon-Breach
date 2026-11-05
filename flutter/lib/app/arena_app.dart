import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../game/manifest/arena_manifest_validator.dart';
import '../game/rendering/arena_hero_preview.dart';
import '../game/rendering/arena_scene_runtime.dart';
import '../game/rendering/arena_world_preview.dart';
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
    await _initializeFoundation();
  }

  Future<void> _initializeFoundation() async {
    try {
      // GPU resources must be ready before the first declarative SceneView.
      await ArenaSceneRuntime.initialize();
      await _validateManifest();
    } catch (error) {
      if (!mounted) return;
      _machine.dispatch(
        ManifestValidationCompleted(
          valid: false,
          reason: 'Falha ao inicializar o runtime 3D: $error',
        ),
      );
    }
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
      await _initializeFoundation();
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
          child: LayoutBuilder(
            builder: (context, viewport) {
              final compact = viewport.maxHeight < 540;
              final horizontal = viewport.maxWidth < 700 ? 12.0 : 26.0;
              final vertical = compact ? 8.0 : 14.0;

              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1240),
                  child: SizedBox(
                    width: double.infinity,
                    height: viewport.maxHeight,
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: horizontal,
                        vertical: vertical,
                      ),
                      child: _buildPhase(compact: compact),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildPhase({required bool compact}) {
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
          title: 'Preparando runtime 3D',
          description: 'Inicializando conteúdo offline.',
        );
      case ArenaPhase.mainMenu:
        return _mainMenu(compact: compact);
      case ArenaPhase.heroSelection:
        return _heroSelection(compact: compact);
      case ArenaPhase.matchLoading:
        return _worldPreview();
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

  Widget _mainMenu({required bool compact}) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.only(left: compact ? 8 : 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'DUCK DREAM STUDIOS',
              style: TextStyle(
                color: Color(0xFF79D6BD),
                fontSize: 10,
                letterSpacing: 2.0,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: compact ? 14 : 20),
            Text(
              'PROJETO\nARENA',
              style: TextStyle(
                fontSize: compact ? 48 : 56,
                height: 0.94,
                letterSpacing: -1.8,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: compact ? 22 : 30),
            FilledButton.icon(
              onPressed: () => onEvent(const OpenHeroSelection()),
              icon: const Icon(Icons.play_arrow_rounded, size: 18),
              label: const Text(
                'JOGAR',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                ),
              ),
              style: FilledButton.styleFrom(
                minimumSize: const Size(176, 48),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                tapTargetSize: MaterialTapTargetSize.padded,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _heroSelection({required bool compact}) {
    const heroes = [
      ('lyra', 'LYRA'),
      ('bastion', 'BASTION'),
      ('kairo', 'KAIRO'),
    ];
    final selectedId = snapshot.selectedHeroId ?? 'lyra';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 12,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: ArenaHeroPreview(heroId: selectedId),
          ),
        ),
        SizedBox(width: compact ? 12 : 20),
        Expanded(
          flex: 8,
          child: Padding(
            padding: EdgeInsets.symmetric(
              vertical: compact ? 2 : 8,
              horizontal: compact ? 2 : 8,
            ),
            child: LayoutBuilder(
              builder: (context, panel) {
                final itemHeight = (panel.maxHeight * 0.13)
                    .clamp(48.0, compact ? 54.0 : 62.0)
                    .toDouble();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'HERÓIS',
                      style: TextStyle(
                        color: const Color(0xFF79D6BD),
                        fontSize: compact ? 10 : 11,
                        letterSpacing: 2.0,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: compact ? 6 : 9),
                    Text(
                      'Escolha seu herói',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: compact ? 21 : 25,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const Spacer(),
                    for (final hero in heroes) ...[
                      _HeroChoiceTile(
                        heroId: hero.$1,
                        label: hero.$2,
                        selected: selectedId == hero.$1,
                        height: itemHeight,
                        onTap: () => onEvent(SelectHero(hero.$1)),
                      ),
                      const SizedBox(height: 8),
                    ],
                    const Spacer(),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () => onEvent(const ReturnToMenu()),
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFFB7C2CA),
                            minimumSize: const Size(82, 44),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'VOLTAR',
                            style: TextStyle(fontSize: 12, letterSpacing: 0.8),
                          ),
                        ),
                        const Spacer(),
                        FilledButton(
                          onPressed: snapshot.selectedHeroId == null
                              ? null
                              : () => onEvent(const ConfirmHeroSelection()),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(132, 44),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'CONFIRMAR',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.7,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _worldPreview() {
    return SizedBox.expand(
      child: ArenaWorldPreview(
        onBack: () => onEvent(const CancelMatchLoading()),
      ),
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

class _HeroChoiceTile extends StatelessWidget {
  const _HeroChoiceTile({
    required this.heroId,
    required this.label,
    required this.selected,
    required this.height,
    required this.onTap,
  });

  final String heroId;
  final String label;
  final bool selected;
  final double height;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = selected
        ? const Color(0xFF79D6BD)
        : const Color(0xFF46545E);

    return Material(
      color: selected
          ? const Color(0x263C8D7C)
          : const Color(0x141E2A31),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: double.infinity,
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: accent.withValues(alpha: selected ? 0.95 : 0.55),
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: selected
                        ? const Color(0xFF9BE4D1)
                        : const Color(0xFFE0E6E8),
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              Icon(
                selected ? Icons.check_circle : Icons.circle_outlined,
                size: 18,
                color: selected
                    ? const Color(0xFF79D6BD)
                    : const Color(0xFF71808B),
              ),
            ],
          ),
        ),
      ),
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
