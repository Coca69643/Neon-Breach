import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

/// Full-screen Bastião do Firmamento hub. The tower is the visual anchor;
/// all interactive controls live in the Flutter overlay at the screen edges.
class ArenaMainMenuScene extends StatelessWidget {
  const ArenaMainMenuScene({super.key});

  static const _hubAsset = 'assets/world/arena_menu_hub.glb';

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: [0.0, 0.42, 0.78, 1.0],
              colors: [
                Color(0xFF8CC9E1),
                Color(0xFF6E9BC9),
                Color(0xFF7A6BA6),
                Color(0xFFB64D8D),
              ],
            ),
          ),
        ),
        Positioned.fill(
          child: SceneView.declarative(
            key: const ValueKey('arena-main-menu-hub-scene'),
            pixelRatio: 0.85,
            maxFrameRate: 30,
            environmentIntensity: 1.15,
            exposure: 1.04,
            cameraBuilder: (elapsed) {
              final seconds = elapsed.inMicroseconds / 1000000.0;
              final drift = math.sin(seconds * 0.032) * 0.34;
              final lift = math.sin(seconds * 0.021) * 0.12;
              return PerspectiveCamera(
                fovRadiansY: 42 * math.pi / 180,
                position: vm.Vector3(drift, 18.8 + lift, 48.0),
                target: vm.Vector3(drift * 0.42, 15.5, 0),
                fovNear: 0.1,
                fovFar: 180,
              );
            },
            loadingBuilder: (context, progress) => const Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFFFFD995),
                ),
              ),
            ),
            children: const [
              SceneModel(
                _hubAsset,
                key: ValueKey('arena-menu-hub-model'),
                name: 'bastiao_do_firmamento',
              ),
            ],
          ),
        ),
      ],
    );
  }
}
