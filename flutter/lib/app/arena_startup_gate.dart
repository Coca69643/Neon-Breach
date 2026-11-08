import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../game/rendering/arena_main_menu_scene.dart';

class ArenaStartupGate extends StatelessWidget {
  const ArenaStartupGate({
    super.key,
    required this.showStudioSplash,
    required this.progress,
    required this.stageTitle,
    required this.stageDescription,
    required this.playerName,
    required this.playerAvatarPath,
    required this.localNetworkPrepared,
    required this.onlineClientPrepared,
  });

  final bool showStudioSplash;
  final double progress;
  final String stageTitle;
  final String stageDescription;
  final String playerName;
  final String? playerAvatarPath;
  final bool localNetworkPrepared;
  final bool onlineClientPrepared;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ArenaMainMenuScene(),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xB8081019),
                Color(0xA6101B25),
                Color(0xE5080D14),
              ],
            ),
          ),
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) {
            return FadeTransition(opacity: animation, child: child);
          },
          child: showStudioSplash
              ? const _StudioSplash(key: ValueKey<String>('studio-splash'))
              : _StartupLoader(
                  key: const ValueKey<String>('startup-loader'),
                  progress: progress,
                  stageTitle: stageTitle,
                  stageDescription: stageDescription,
                  playerName: playerName,
                  playerAvatarPath: playerAvatarPath,
                  localNetworkPrepared: localNetworkPrepared,
                  onlineClientPrepared: onlineClientPrepared,
                ),
        ),
      ],
    );
  }
}

class _StudioSplash extends StatelessWidget {
  const _StudioSplash({super.key});

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFF070A0E),
      child: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: 1),
          duration: Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return Opacity(
              opacity: value,
              child: Transform.scale(
                scale: 0.96 + (0.04 * value),
                child: child,
              ),
            );
          },
          child: _ArenaStudioLogo(width: 238, height: 238),
        ),
      ),
    );
  }
}

class _StartupLoader extends StatelessWidget {
  const _StartupLoader({
    super.key,
    required this.progress,
    required this.stageTitle,
    required this.stageDescription,
    required this.playerName,
    required this.playerAvatarPath,
    required this.localNetworkPrepared,
    required this.onlineClientPrepared,
  });

  final double progress;
  final String stageTitle;
  final String stageDescription;
  final String playerName;
  final String? playerAvatarPath;
  final bool localNetworkPrepared;
  final bool onlineClientPrepared;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxHeight < 430;
          final sidePadding = constraints.maxWidth < 760 ? 18.0 : 42.0;
          final localLabel = localNetworkPrepared
              ? 'REDE LOCAL PRONTA'
              : progress >= 0.96
                  ? 'LAN INDISPONÍVEL'
                  : 'REDE LOCAL';
          final onlineLabel = onlineClientPrepared
              ? 'ONLINE CONFIGURADO'
              : progress >= 0.96
                  ? 'MODO OFFLINE'
                  : 'ONLINE';

          return Padding(
            padding: EdgeInsets.symmetric(
              horizontal: sidePadding,
              vertical: compact ? 10 : 22,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const _ArenaStudioLogo(width: 58, height: 58),
                    const SizedBox(width: 12),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'DUCK DREAM STUDIOS',
                          style: TextStyle(
                            color: Color(0xFFF1D28A),
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.3,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'PROJECT ARENA',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2.0,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0x55202D37),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: const Color(0x557F9A9E)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.shield_outlined,
                            size: 14,
                            color: Color(0xFF9CCFC5),
                          ),
                          SizedBox(width: 7),
                          Text(
                            'OFFLINE-FIRST',
                            style: TextStyle(
                              color: Color(0xFFD4E3DF),
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 900),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              _PlayerAvatar(
                                path: playerAvatarPath,
                                size: compact ? 42 : 52,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Olá, ${playerName.trim().isEmpty ? 'jogador' : playerName}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: compact ? 15 : 18,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    const Text(
                                      'Estamos preparando seu espaço de jogo.',
                                      style: TextStyle(
                                        color: Color(0xFFB9C8CC),
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (!compact)
                                const Text(
                                  'GATE 05  /  STARTUP',
                                  style: TextStyle(
                                    color: Color(0xFFB8A16F),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                            ],
                          ),
                          SizedBox(height: compact ? 12 : 20),
                          Text(
                            stageTitle,
                            style: TextStyle(
                              color: const Color(0xFFF4E3C0),
                              fontSize: compact ? 22 : 30,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            stageDescription,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFFC0CDD0),
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                          SizedBox(height: compact ? 12 : 18),
                          Row(
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(20),
                                  child: LinearProgressIndicator(
                                    value: progress.clamp(0.0, 1.0).toDouble(),
                                    minHeight: 7,
                                    backgroundColor: const Color(0x553C4B55),
                                    valueColor:
                                        const AlwaysStoppedAnimation<Color>(
                                      Color(0xFFE4BB63),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                '${(progress.clamp(0.0, 1.0) * 100).round()}%',
                                style: const TextStyle(
                                  color: Color(0xFFF2D697),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  fontFeatures: [FontFeature.tabularFigures()],
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: compact ? 10 : 14),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _ReadinessChip(
                                label: 'CONTEÚDO LOCAL',
                                ready: progress >= 0.45,
                              ),
                              _ReadinessChip(
                                label: 'RUNTIME 3D',
                                ready: progress >= 0.72,
                              ),
                              _ReadinessChip(
                                label: localLabel,
                                ready: localNetworkPrepared,
                              ),
                              _ReadinessChip(
                                label: onlineLabel,
                                ready: onlineClientPrepared,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Row(
                  children: [
                    const Icon(
                      Icons.lightbulb_outline_rounded,
                      color: Color(0xFFE4BB63),
                      size: 17,
                    ),
                    const SizedBox(width: 9),
                    const Expanded(
                      child: Text(
                        'Dica: ler o mapa e escolher objetivos em equipe muda o ritmo de cada partida.',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Color(0xFFB9C8CC),
                          fontSize: 10,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      onlineClientPrepared
                          ? 'SALAS SOB DEMANDA'
                          : 'MODO OFFLINE DISPONÍVEL',
                      style: const TextStyle(
                        color: Color(0xFF9DCFC5),
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ReadinessChip extends StatelessWidget {
  const _ReadinessChip({required this.label, required this.ready});

  final String label;
  final bool ready;

  @override
  Widget build(BuildContext context) {
    final color = ready
        ? const Color(0xFFE4BB63)
        : const Color(0xFF9AAAB0);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0x44222F38),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0x557E9298)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            ready ? Icons.check_circle_outline : Icons.more_time_rounded,
            size: 13,
            color: color,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayerAvatar extends StatelessWidget {
  const _PlayerAvatar({required this.path, required this.size});

  final String? path;
  final double size;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFF263B45),
      ),
      child: const Icon(
        Icons.person_outline_rounded,
        color: Color(0xFFE4BB63),
      ),
    );

    if (path == null || path!.isEmpty) {
      return fallback;
    }

    return ClipOval(
      child: Image.file(
        File(path!),
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => fallback,
      ),
    );
  }
}

class _ArenaStudioLogo extends StatefulWidget {
  const _ArenaStudioLogo({
    required this.width,
    required this.height,
  });

  final double width;
  final double height;

  @override
  State<_ArenaStudioLogo> createState() => _ArenaStudioLogoState();
}

class _ArenaStudioLogoState extends State<_ArenaStudioLogo> {
  late final Future<Uint8List> _imageBytes;

  @override
  void initState() {
    super.initState();
    _imageBytes = rootBundle
        .loadString('assets/branding/duck_dream_studios.webp.b64')
        .then(base64Decode);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: _imageBytes,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return SizedBox(
            width: widget.width,
            height: widget.height,
            child: const Center(
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: Color(0xFFE4BB63),
              ),
            ),
          );
        }
        return Image.memory(
          snapshot.data!,
          width: widget.width,
          height: widget.height,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.medium,
          gaplessPlayback: true,
          errorBuilder: (context, error, stackTrace) {
            return SizedBox(
              width: widget.width,
              height: widget.height,
              child: const Icon(
                Icons.person_outline_rounded,
                color: Color(0xFFE4BB63),
              ),
            );
          },
        );
      },
    );
  }
}
