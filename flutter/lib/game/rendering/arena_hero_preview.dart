import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import '../arena_hero_catalog.dart';

class ArenaHeroPreview extends StatelessWidget {
  const ArenaHeroPreview({super.key, required this.heroId});

  final String heroId;

  @override
  Widget build(BuildContext context) {
    final hero = ArenaHeroCatalog.byId(heroId) ?? ArenaHeroCatalog.fallback;

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
          fovRadiansY: hero.previewFovDegrees * math.pi / 180,
          position: vm.Vector3(
            0,
            hero.previewCameraHeight,
            -hero.previewCameraDistance,
          ),
          target: vm.Vector3(0, hero.previewTargetHeight, 0),
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
            hero.modelAsset,
            key: ValueKey(hero.id),
            name: 'playable_hero_${hero.id}',
            position: vm.Vector3(hero.previewOffsetX, 0, 0),
            // The default calibration presents the model's front to the stage.
            // Individual non-humanoid models can override this yaw in the catalog.
            rotation: vm.Quaternion.axisAngle(
              vm.Vector3(0, 1, 0),
              hero.previewYawRadians,
            ),
            scale: vm.Vector3.all(hero.previewScale),
            animations: [
              SceneAnimationSpec(hero.idleAnimation, loop: true, speed: 1),
            ],
            onLoaded: (_) => debugPrint('Hero GLB loaded: ${hero.id}'),
          ),
        ],
      ),
    );
  }
}
