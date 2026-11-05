import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

class ArenaHeroPreview extends StatelessWidget {
  const ArenaHeroPreview({super.key, required this.heroId});

  final String heroId;

  static const _models = <String, ({String asset, String idle})>{
    'lyra': (
      asset: 'assets/heroes/lyra.glb',
      idle: 'HumanArmature|Female_Idle',
    ),
    'bastion': (
      asset: 'assets/heroes/bastion.glb',
      idle: 'HumanArmature|Man_Idle',
    ),
    'kairo': (
      asset: 'assets/heroes/kairo.glb',
      idle: 'HumanArmature|Man_Idle',
    ),
  };

  @override
  Widget build(BuildContext context) {
    final model = _models[heroId] ?? _models['lyra']!;

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -0.2),
          radius: 0.95,
          colors: [Color(0xFF243A42), Color(0xFF111B22), Color(0xFF0D141A)],
        ),
      ),
      child: SceneView.declarative(
        // Keep the preview crisp without rendering above the device pixel budget.
        pixelRatio: 1.0,
        cameraBuilder: (_) => PerspectiveCamera(
          fovRadiansY: 38 * math.pi / 180,
          position: vm.Vector3(0, 1.15, 5.0),
          target: vm.Vector3(0, 1.08, 0),
        ),
        loadingBuilder: (context, progress) => const Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Color(0xFF79D6BD),
            ),
          ),
        ),
        children: [
          SceneModel(
            model.asset,
            key: ValueKey(heroId),
            name: 'playable_hero_$heroId',
            position: vm.Vector3(0, 0, 0),
            // The baked GLB front already faces scene +Z, toward this camera.
            scale: vm.Vector3.all(0.52),
            animations: [
              SceneAnimationSpec(model.idle, loop: true, speed: 1),
            ],
            onLoaded: (_) => debugPrint('Hero GLB loaded: $heroId'),
          ),
        ],
      ),
    );
  }
}
