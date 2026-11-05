import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../game/manifest/arena_manifest_validator.dart';
import '../game/rendering/arena_hero_preview.dart';
import '../game/rendering/arena_main_menu_scene.dart';
import '../game/rendering/moba_match_view.dart';
import '../game/rendering/arena_scene_runtime.dart';
import '../game/state/arena_state_machine.dart';
import '../game/match/moba_match_simulation.dart';

class ArenaApp extends StatefulWidget {
  const ArenaApp({super.key});

  @override
  State<ArenaApp> createState() => _ArenaAppState();
}

class _ArenaAppState extends State<ArenaApp> with WidgetsBindingObserver {
  late final ArenaStateMachine _machine;
  MobaMatchSimulation? _matchSimulation;

  @override
  void initState() {
    super.initState();
    _machine = ArenaStateMachine();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
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
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
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
          onEvent: _dispatch,
          onRetry: _retry,
          simulation: _matchSimulation,
        ),
      ),
    );
  }

  MobaHeroId _mapHero(String? id) => switch (id) {
        'bastion' => MobaHeroId.bastion,
        'kairo' => MobaHeroId.kairo,
        _ => MobaHeroId.lyra,
      };

  TransitionDecision _dispatch(ArenaEvent event) {
    final selectedHero = _machine.snapshot.selectedHeroId;
    final startsMatch =
        event is StartRunFromHub || event is ConfirmHeroSelection;
    final decision = _machine.dispatch(event);
    if (!decision.accepted) return decision;

    if (startsMatch) {
      _matchSimulation = MobaMatchSimulation(
        heroId: _mapHero(selectedHero),
      );
    } else if (event is ReturnToMenu) {
      _matchSimulation = null;
    }
    return decision;
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
    required this.simulation,
  });

  final ArenaSnapshot snapshot;
  final TransitionDecision Function(ArenaEvent) onEvent;
  final VoidCallback onRetry;
  final MobaMatchSimulation? simulation;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: snapshot.phase == ArenaPhase.mainMenu
          ? _immersiveMainMenu()
          : DecoratedBox(
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

  Widget _immersiveMainMenu() {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ArenaMainMenuScene(),
        const IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.0, 0.2, 0.58, 1.0],
                colors: [
                  Color(0x8A102334),
                  Color(0x000E1925),
                  Color(0x000E1925),
                  Color(0xB80A1320),
                ],
              ),
            ),
          ),
        ),
        SafeArea(
          child: LayoutBuilder(
            builder: (context, viewport) {
              final compact = viewport.maxHeight < 440;
              final scale = compact ? 0.86 : 1.0;
              final edgeX = compact ? 12.0 : 22.0;
              final edgeY = compact ? 10.0 : 18.0;

              return Stack(
                children: [
                  Positioned(
                    left: edgeX,
                    top: edgeY,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: compact ? 30 : 34,
                          height: compact ? 30 : 34,
                          decoration: BoxDecoration(
                            color: const Color(0xC91B3442),
                            border: Border.all(
                              color: const Color(0xAAE2C58A),
                              width: 1.2,
                            ),
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: const Icon(
                            Icons.shield_moon_outlined,
                            color: Color(0xFFE8D3A2),
                            size: 19,
                          ),
                        ),
                        const SizedBox(width: 9),
                        const Text(
                          'PROJETO ARENA',
                          style: TextStyle(
                            color: Color(0xFFF4F0E5),
                            fontSize: 13,
                            letterSpacing: 1.4,
                            fontWeight: FontWeight.w900,
                            shadows: [
                              Shadow(
                                color: Color(0x99000000),
                                blurRadius: 9,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    left: edgeX,
                    bottom: edgeY,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _HubShortcut(
                          label: 'HERÓIS',
                          icon: Icons.groups_rounded,
                          width: 126 * scale,
                          height: 50 * scale,
                          active: true,
                          onTap: () => onEvent(const OpenHeroSelection()),
                        ),
                        SizedBox(width: 7 * scale),
                        _HubShortcut(
                          label: 'BAÚS',
                          icon: Icons.inventory_2_outlined,
                          width: 96 * scale,
                          height: 46 * scale,
                          locked: true,
                        ),
                        SizedBox(width: 7 * scale),
                        _HubShortcut(
                          label: 'DESAFIOS',
                          icon: Icons.flag_outlined,
                          width: 132 * scale,
                          height: 46 * scale,
                          locked: true,
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    right: edgeX,
                    top: viewport.maxHeight * 0.40,
                    child: _HubShortcut(
                      label: 'MERCADOR',
                      icon: Icons.storefront_outlined,
                      width: 142 * scale,
                      height: 49 * scale,
                      locked: true,
                    ),
                  ),
                  Positioned(
                    right: edgeX,
                    bottom: edgeY,
                    child: _HubPrimaryAction(
                      width: 166 * scale,
                      height: 56 * scale,
                      onTap: () => onEvent(const StartRunFromHub()),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
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
        return const SizedBox.shrink();
      case ArenaPhase.heroSelection:
        return _heroSelection(compact: compact);
      case ArenaPhase.matchLoading:
      case ArenaPhase.inMatch:
        return _matchView();
      case ArenaPhase.paused:
        return _paused();
      case ArenaPhase.matchResult:
        return _result();
      case ArenaPhase.recoverableError:
        return _error();
    }
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

  Widget _matchView() {
    final currentSimulation = simulation;
    if (currentSimulation == null) {
      return _StatusView(
        eyebrow: 'PARTIDA',
        title: 'Sessão não inicializada',
        description: 'A máquina de estados não recebeu o modelo de partida.',
        actionLabel: 'VOLTAR',
        onAction: () => onEvent(const ReturnToMenu()),
      );
    }
    return SizedBox.expand(
      child: MobaMatchView(
        simulation: currentSimulation,
        onRuntimeReady: () {
          if (snapshot.phase == ArenaPhase.matchLoading) {
            onEvent(const MatchRuntimeCompleted(success: true));
          }
        },
        onPause: () => onEvent(const PauseMatch()),
        onFinished: (winner) => onEvent(
          MatchFinished(
            winner == MobaTeam.blue
                ? MatchOutcome.victory
                : MatchOutcome.defeat,
          ),
        ),
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
    required this.label,
    required this.selected,
    required this.height,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final double height;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = selected
        ? const Color(0xFF79D6BD)
        : const Color(0xFF46545E);
    final shape = BeveledRectangleBorder(
      borderRadius: BorderRadius.circular(7),
      side: BorderSide(
        color: accent.withValues(alpha: selected ? 0.95 : 0.58),
        width: selected ? 1.6 : 1,
      ),
    );

    return Material(
      color: selected
          ? const Color(0x263C8D7C)
          : const Color(0x141E2A31),
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        customBorder: shape,
        child: SizedBox(
          width: double.infinity,
          height: height,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
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
      ),
    );
  }
}

class _HubShortcut extends StatelessWidget {
  const _HubShortcut({
    required this.label,
    required this.icon,
    required this.width,
    required this.height,
    this.active = false,
    this.locked = false,
    this.onTap,
  });

  final String label;
  final IconData icon;
  final double width;
  final double height;
  final bool active;
  final bool locked;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final shape = BeveledRectangleBorder(
      borderRadius: BorderRadius.circular(7),
      side: BorderSide(
        color: active
            ? const Color(0xFFE2D09A)
            : const Color(0x8AA9D4D8),
        width: active ? 1.4 : 1,
      ),
    );
    return Material(
      color: active
          ? const Color(0xD29BCFC6)
          : const Color(0xC6284654),
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: locked ? null : onTap,
        customBorder: shape,
        child: SizedBox(
          width: width,
          height: height,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 19,
                  color: active
                      ? const Color(0xFF163C43)
                      : const Color(0xFFE1E9E8),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: active
                          ? const Color(0xFF173A3C)
                          : const Color(0xFFE2EBE9),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.65,
                    ),
                  ),
                ),
                if (locked)
                  const Icon(
                    Icons.lock_outline_rounded,
                    size: 13,
                    color: Color(0xFFB6C7C9),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HubPrimaryAction extends StatelessWidget {
  const _HubPrimaryAction({
    required this.width,
    required this.height,
    required this.onTap,
  });

  final double width;
  final double height;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final shape = BeveledRectangleBorder(
      borderRadius: BorderRadius.circular(8),
      side: const BorderSide(color: Color(0xFFFFE1A2), width: 1.5),
    );
    return Material(
      color: const Color(0xFFE2B568),
      shape: shape,
      elevation: 5,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        customBorder: shape,
        child: SizedBox(
          width: width,
          height: height,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(
                  Icons.arrow_upward_rounded,
                  size: 21,
                  color: Color(0xFF45301F),
                ),
                SizedBox(width: 9),
                Text(
                  'ASCENDER',
                  style: TextStyle(
                    color: Color(0xFF45301F),
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
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
