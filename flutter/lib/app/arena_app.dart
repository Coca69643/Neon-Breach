import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../game/manifest/arena_manifest_validator.dart';
import '../game/match/moba_match_simulation.dart';
import '../game/rendering/arena_main_menu_scene.dart';
import '../game/rendering/arena_scene_runtime.dart';
import '../game/rendering/moba_match_view.dart';
import '../game/state/arena_state_machine.dart';
import '../network/arena_network_preflight.dart';
import '../network/arena_online_lobby_service.dart';
import 'arena_hero_selection_screen.dart';
import 'arena_network_lobby_screen.dart';
import 'arena_player_profile.dart';
import 'arena_startup_gate.dart';

class ArenaApp extends StatefulWidget {
  const ArenaApp({super.key});

  @override
  State<ArenaApp> createState() => _ArenaAppState();
}

class _ArenaAppState extends State<ArenaApp> with WidgetsBindingObserver {
  late final ArenaStateMachine _machine;
  MobaMatchSimulation? _matchSimulation;
  final ArenaPlayerProfileStore _profileStore = ArenaPlayerProfileStore();
  ArenaPlayerProfile _playerProfile = const ArenaPlayerProfile();
  bool _startupFinished = false;
  bool _showStudioSplash = true;
  double _startupProgress = 0;
  String _startupTitle = 'Preparando sua Arena';
  String _startupDescription = 'Organizando os recursos principais.';
  bool _localNetworkPrepared = false;
  bool _onlineClientPrepared = false;

  @override
  void initState() {
    super.initState();
    _machine = ArenaStateMachine();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    _machine.dispatch(const BootCompleted());

    // Keep the studio splash short; initialization is shown in the loader.
    await Future<void>.delayed(const Duration(milliseconds: 720));
    if (!mounted) return;
    setState(() => _showStudioSplash = false);
    await Future<void>.delayed(const Duration(milliseconds: 260));

    _setStartupProgress(
      0.08,
      'Restaurando seu perfil',
      'Recuperando nome, avatar e preferências locais.',
    );
    await _restorePlayerProfile();

    _setStartupProgress(
      0.20,
      'Conferindo o pacote do jogo',
      'Verificando manifesto e grupos de conteúdo embarcados.',
    );
    final foundationReady = await _initializeFoundation(
      onProgress: _setStartupProgress,
    );
    if (!mounted) return;
    if (!foundationReady) {
      setState(() => _startupFinished = true);
      return;
    }

    _setStartupProgress(
      0.78,
      'Preparando os serviços de sessão',
      'Verificando o TCP local e inicializando o cliente Online sem entrar em uma sala.',
    );

    final networkResults = await Future.wait<bool>([
      ArenaNetworkPreflight.checkLoopbackTcp().timeout(
        const Duration(seconds: 2),
        onTimeout: () => false,
      ),
      ArenaOnlineLobbyService.prepareClient().timeout(
        const Duration(seconds: 3),
        onTimeout: () => false,
      ),
    ]);
    if (!mounted) return;

    setState(() {
      _localNetworkPrepared = networkResults[0];
      _onlineClientPrepared = networkResults[1];
    });

    _setStartupProgress(
      1,
      'Arena pronta',
      'Conteúdo validado. Partidas e salas serão abertas quando você escolher.',
    );
    await Future<void>.delayed(const Duration(milliseconds: 180));
    if (mounted) {
      setState(() => _startupFinished = true);
    }
  }

  void _setStartupProgress(double progress, String title, String description) {
    if (!mounted) return;
    setState(() {
      _startupProgress = progress.clamp(0.0, 1.0).toDouble();
      _startupTitle = title;
      _startupDescription = description;
    });
  }

  Future<void> _restorePlayerProfile() async {
    try {
      var profile = await _profileStore.load();
      try {
        final recovered = await _profileStore.recoverLostAvatar();
        if (recovered != null) profile = recovered;
      } catch (_) {
        // A failed gallery recovery must not block the game from opening.
      }
      if (!mounted) return;
      setState(() => _playerProfile = profile);
    } catch (_) {
      // Keep the safe in-memory default when local preferences are unavailable.
    }
  }

  Future<ArenaPlayerProfile?> _pickPlayerAvatar() async {
    try {
      return await _profileStore.pickAndSaveAvatar();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível abrir ou salvar a foto.'),
          ),
        );
      }
      return null;
    }
  }

  Future<void> _editPlayerProfile() async {
    final nameController = TextEditingController(
      text: _playerProfile.displayName,
    );
    var draftProfile = _playerProfile;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xF0182A32),
          title: const Text(
            'PERFIL DO JOGADOR',
            style: TextStyle(
              color: Color(0xFFE8D3A2),
              fontSize: 15,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.7,
            ),
          ),
          content: SizedBox(
            width: 420,
            child: Row(
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(40),
                  onTap: () async {
                    final updated = await _pickPlayerAvatar();
                    if (updated == null || !mounted) return;
                    setState(() => _playerProfile = updated);
                    if (dialogContext.mounted) {
                      setDialogState(() => draftProfile = updated);
                    }
                  },
                  child: _ProfileAvatar(
                    path: draftProfile.avatarPath,
                    size: 62,
                    borderColor: const Color(0xFF83D9C5),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: nameController,
                        maxLength: ArenaPlayerProfile.maxDisplayNameLength,
                        textCapitalization: TextCapitalization.words,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Nome exibido',
                          hintText: 'Seu nome no jogo',
                          counterText: '',
                        ),
                      ),
                      const SizedBox(height: 4),
                      TextButton.icon(
                        onPressed: () async {
                          final updated = await _pickPlayerAvatar();
                          if (updated == null || !mounted) return;
                          setState(() => _playerProfile = updated);
                          if (dialogContext.mounted) {
                            setDialogState(() => draftProfile = updated);
                          }
                        },
                        icon: const Icon(Icons.photo_library_outlined, size: 17),
                        label: const Text('ESCOLHER FOTO'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('FECHAR'),
            ),
            FilledButton(
              onPressed: () async {
                try {
                  final updated = await _profileStore.saveDisplayName(
                    nameController.text,
                  );
                  if (!mounted) return;
                  setState(() => _playerProfile = updated);
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop();
                  }
                } catch (_) {
                  if (dialogContext.mounted) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      const SnackBar(
                        content: Text('Não foi possível salvar o perfil.'),
                      ),
                    );
                  }
                }
              },
              child: const Text('SALVAR'),
            ),
          ],
        ),
      ),
    );
    nameController.dispose();
  }

  Future<void> _openNetworkLobby() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ArenaNetworkLobbyScreen(
          displayName: _playerProfile.displayName,
        ),
      ),
    );
  }

  Future<bool> _initializeFoundation({
    void Function(double, String, String)? onProgress,
  }) async {
    try {
      onProgress?.call(
        0.28,
        'Validando o conteúdo local',
        'Checando manifesto, marca, heróis, NPCs, mundo e recursos 3D.',
      );
      final result = await ArenaManifestValidator.validate(rootBundle);
      if (!mounted) return false;

      if (!result.valid) {
        _machine.dispatch(
          ManifestValidationCompleted(
            valid: false,
            reason: result.issues.join('\n'),
          ),
        );
        return false;
      }

      onProgress?.call(
        0.54,
        'Inicializando o runtime 3D',
        'Preparando os recursos compartilhados de Flutter Scene / Impeller.',
      );
      // GPU resources must be ready before the first declarative SceneView.
      await ArenaSceneRuntime.initialize();
      if (!mounted) return false;

      _machine.dispatch(const ManifestValidationCompleted(valid: true));
      onProgress?.call(
        0.72,
        'Runtime 3D pronto',
        'A memória pesada do mapa será alocada na entrada da partida.',
      );
      return true;
    } catch (error) {
      if (!mounted) return false;
      _machine.dispatch(
        ManifestValidationCompleted(
          valid: false,
          reason: 'Falha ao preparar o conteúdo ou runtime 3D: $error',
        ),
      );
      return false;
    }
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
      home: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedBuilder(
            animation: _machine,
            builder: (context, _) => _ArenaScreen(
              snapshot: _machine.snapshot,
              onEvent: _dispatch,
              onRetry: _retry,
              simulation: _matchSimulation,
              playerProfile: _playerProfile,
              onEditPlayerProfile: _editPlayerProfile,
              onOpenNetworkLobby: _openNetworkLobby,
            ),
          ),
          if (!_startupFinished)
            Positioned.fill(
              child: ArenaStartupGate(
                showStudioSplash: _showStudioSplash,
                progress: _startupProgress,
                stageTitle: _startupTitle,
                stageDescription: _startupDescription,
                playerName: _playerProfile.displayName,
                playerAvatarPath: _playerProfile.avatarPath,
                localNetworkPrepared: _localNetworkPrepared,
                onlineClientPrepared: _onlineClientPrepared,
              ),
            ),
        ],
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
    final startsMatch = event is StartRunFromHub;
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
    required this.playerProfile,
    required this.onEditPlayerProfile,
    required this.onOpenNetworkLobby,
  });

  final ArenaSnapshot snapshot;
  final TransitionDecision Function(ArenaEvent) onEvent;
  final VoidCallback onRetry;
  final MobaMatchSimulation? simulation;
  final ArenaPlayerProfile playerProfile;
  final VoidCallback onEditPlayerProfile;
  final VoidCallback onOpenNetworkLobby;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: snapshot.phase == ArenaPhase.mainMenu
          ? _immersiveMainMenu()
          : snapshot.phase == ArenaPhase.heroSelection
              ? _heroSelectionFullScreen(context)
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
                    child: _PlayerProfileBadge(
                      profile: playerProfile,
                      compact: compact,
                      onTap: onEditPlayerProfile,
                    ),
                  ),
                  Positioned(
                    right: edgeX,
                    top: edgeY,
                    child: _HubShortcut(
                      label: 'REDE',
                      icon: Icons.wifi_tethering_rounded,
                      width: 112 * scale,
                      height: 46 * scale,
                      onTap: onOpenNetworkLobby,
                    ),
                  ),
                  Positioned(
                    left: edgeX,
                    bottom: edgeY,
                    child: _HubShortcut(
                      label: 'HERÓIS',
                      icon: Icons.groups_rounded,
                      width: 126 * scale,
                      height: 50 * scale,
                      active: true,
                      onTap: () => onEvent(const OpenHeroSelection()),
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
        return const SizedBox.shrink();
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

  Widget _heroSelectionFullScreen(BuildContext context) {
    return ArenaHeroSelectionScreen(
      selectedHeroId: snapshot.selectedHeroId ?? 'lyra',
      compact: MediaQuery.sizeOf(context).height < 440,
      onSelect: (heroId) => onEvent(SelectHero(heroId)),
      onBack: () => onEvent(const ReturnToMenu()),
      onConfirm: () => onEvent(const ConfirmHeroSelection()),
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
        onRuntimeFailed: (reason) {
          if (snapshot.phase == ArenaPhase.matchLoading) {
            onEvent(MatchRuntimeCompleted(success: false, reason: reason));
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
    final loading = snapshot.resumePhase == ArenaPhase.matchLoading;
    return _StatusView(
      eyebrow: loading ? 'CARREGAMENTO PAUSADO' : 'PAUSA',
      title: loading ? 'Preparação interrompida' : 'Partida pausada',
      description: loading
          ? 'O carregamento do campo será retomado quando você continuar.'
          : 'O estado da partida foi preservado enquanto o aplicativo estava ativo.',
      actionLabel: loading ? 'CONTINUAR' : 'RETOMAR',
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
    final canReturnToMenu =
        snapshot.recoveryPhase == ArenaPhase.matchLoading;
    return _StatusView(
      eyebrow: 'RECUPERAÇÃO',
      title: 'Não foi possível continuar',
      description: snapshot.errorMessage ?? 'Erro não identificado.',
      actionLabel: 'TENTAR NOVAMENTE',
      onAction: onRetry,
      secondaryLabel: canReturnToMenu ? 'VOLTAR AO HUB' : null,
      onSecondary: canReturnToMenu
          ? () => onEvent(const ReturnToMenu())
          : null,
    );
  }
}

class _PlayerProfileBadge extends StatelessWidget {
  const _PlayerProfileBadge({
    required this.profile,
    required this.compact,
    required this.onTap,
  });

  final ArenaPlayerProfile profile;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final avatarSize = compact ? 34.0 : 42.0;
    return Material(
      color: const Color(0xC91B3442),
      borderRadius: BorderRadius.circular(28),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            compact ? 5 : 6,
            compact ? 4 : 5,
            compact ? 11 : 14,
            compact ? 4 : 5,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ProfileAvatar(
                path: profile.avatarPath,
                size: avatarSize,
                borderColor: const Color(0xFFE2C58A),
              ),
              SizedBox(width: compact ? 7 : 10),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: const Color(0xFFF4F0E5),
                      fontSize: compact ? 11 : 13,
                      letterSpacing: 1.0,
                      fontWeight: FontWeight.w900,
                      shadows: const [
                        Shadow(
                          color: Color(0x99000000),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'PERFIL DO JOGADOR',
                    style: TextStyle(
                      color: const Color(0xFFB8D6D1),
                      fontSize: compact ? 7 : 8,
                      letterSpacing: 1.0,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              SizedBox(width: compact ? 7 : 9),
              Icon(
                Icons.edit_outlined,
                size: compact ? 14 : 16,
                color: const Color(0xFFE2C58A),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.path,
    required this.size,
    required this.borderColor,
  });

  final String? path;
  final double size;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(1.5),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: 1.2),
        color: const Color(0xFF203B46),
      ),
      child: ClipOval(
        child: path == null
            ? Icon(
                Icons.person_outline_rounded,
                color: const Color(0xFFE8D3A2),
                size: size * 0.58,
              )
            : Image.file(
                File(path!),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Icon(
                  Icons.person_outline_rounded,
                  color: const Color(0xFFE8D3A2),
                  size: size * 0.58,
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
    this.onTap,
  });

  final String label;
  final IconData icon;
  final double width;
  final double height;
  final bool active;
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
        onTap: onTap,
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
