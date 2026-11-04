import 'package:flutter/material.dart';

import 'state/app_flow_machine.dart';

/// Internal foundation harness.
///
/// This is intentionally not the production menu or a gameplay build. It
/// exists to exercise the application FSM while the custom renderer and game
/// presentation are being migrated independently.
final class ProjectArenaApp extends StatefulWidget {
  const ProjectArenaApp({super.key});

  @override
  State<ProjectArenaApp> createState() => _ProjectArenaAppState();
}

final class _ProjectArenaAppState extends State<ProjectArenaApp> {
  late final _flow = createAppFlowMachine();

  @override
  void initState() {
    super.initState();
    _flow.addListener(_handleTransition);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _flow.dispatch(AppFlowEvent.bootstrapCompleted);
      }
    });
  }

  @override
  void dispose() {
    _flow.removeListener(_handleTransition);
    super.dispose();
  }

  void _handleTransition(StateTransitionRecord<AppFlowState, AppFlowEvent> _) {
    if (mounted) {
      setState(() {});
    }
  }

  String get _stateLabel => switch (_flow.state) {
        AppFlowState.booting => 'Inicializando',
        AppFlowState.mainMenu => 'Menu principal',
        AppFlowState.heroSelection => 'Seleção de personagem',
        AppFlowState.matchLoading => 'Preparando partida',
        AppFlowState.inMatch => 'Partida ativa',
        AppFlowState.paused => 'Partida pausada',
        AppFlowState.matchResults => 'Resultado da partida',
        AppFlowState.recovery => 'Recuperação',
      };

  void _dispatch(AppFlowEvent event) {
    _flow.dispatch(event);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Projeto Arena',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFB96C43),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF101719),
        useMaterial3: true,
      ),
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const Text(
                      'PROJETO ARENA',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2.2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'FUNDAÇÃO FLUTTER',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFFB4C1BC),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 36),
                    Text(
                      _stateLabel,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Máquina de Estados ativa · revisão ${_flow.revision}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF91A29B),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 28),
                    ..._actionsForCurrentState,
                    const SizedBox(height: 20),
                    const Text(
                      'Harness interno de arquitetura. Não representa a interface '
                      'final nem contém uma partida jogável.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF72817B),
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> get _actionsForCurrentState {
    switch (_flow.state) {
      case AppFlowState.mainMenu:
        return <Widget>[
          FilledButton(
            onPressed: () => _dispatch(AppFlowEvent.openHeroSelection),
            child: const Text('Testar seleção de personagem'),
          ),
          OutlinedButton(
            onPressed: () => _dispatch(AppFlowEvent.confirmHeroSelection),
            child: const Text('Testar carregamento da partida'),
          ),
        ];
      case AppFlowState.heroSelection:
        return <Widget>[
          FilledButton(
            onPressed: () => _dispatch(AppFlowEvent.confirmHeroSelection),
            child: const Text('Confirmar e carregar'),
          ),
          TextButton(
            onPressed: () => _dispatch(AppFlowEvent.cancelHeroSelection),
            child: const Text('Voltar'),
          ),
        ];
      case AppFlowState.matchLoading:
        return <Widget>[
          FilledButton(
            onPressed: () => _dispatch(AppFlowEvent.matchPrepared),
            child: const Text('Simular partida pronta'),
          ),
          TextButton(
            onPressed: () => _dispatch(AppFlowEvent.matchLoadFailed),
            child: const Text('Simular falha de carregamento'),
          ),
        ];
      case AppFlowState.inMatch:
        return <Widget>[
          FilledButton(
            onPressed: () => _dispatch(AppFlowEvent.pauseRequested),
            child: const Text('Pausar'),
          ),
          OutlinedButton(
            onPressed: () => _dispatch(AppFlowEvent.matchWon),
            child: const Text('Simular vitória'),
          ),
        ];
      case AppFlowState.paused:
        return <Widget>[
          FilledButton(
            onPressed: () => _dispatch(AppFlowEvent.resumeRequested),
            child: const Text('Retomar'),
          ),
          OutlinedButton(
            onPressed: () => _dispatch(AppFlowEvent.returnToMenu),
            child: const Text('Sair para o menu'),
          ),
        ];
      case AppFlowState.matchResults:
        return <Widget>[
          FilledButton(
            onPressed: () => _dispatch(AppFlowEvent.returnToMenu),
            child: const Text('Voltar ao menu'),
          ),
        ];
      case AppFlowState.recovery:
        return <Widget>[
          FilledButton(
            onPressed: () => _dispatch(AppFlowEvent.retryBootstrap),
            child: const Text('Tentar novamente'),
          ),
        ];
      case AppFlowState.booting:
        return const <Widget>[];
    }
  }
}
