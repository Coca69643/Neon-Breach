import 'package:flutter/material.dart';
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

class ArenaHeroPreview extends StatelessWidget {
  const ArenaHeroPreview({super.key, required this.heroId});

  final String heroId;

  static const _models = <String, ({String asset, String idle})>{
    'lyra': (asset: 'assets/heroes/lyra.glb', idle: 'Female_Idle'),
    'bastion': (asset: 'assets/heroes/bastion.glb', idle: 'Man_Idle'),
    'kairo': (asset: 'assets/heroes/kairo.glb', idle: 'Female_Idle'),
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
        cameraBuilder: (_) => PerspectiveCamera(
          position: vm.Vector3(0, 1.25, 5.2),
          target: vm.Vector3(0, 1.0, 0),
        ),
        loadingBuilder: (context, progress) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(strokeWidth: 2),
              const SizedBox(height: 12),
              Text(
                'CARREGANDO MODELO 3D  ${(progress * 100).round()}%',
                style: const TextStyle(
                  color: Color(0xFFB8C9CB),
                  fontSize: 10,
                  letterSpacing: 1.4,
                ),
              ),
            ],
          ),
        ),
        children: [
          SceneModel(
            model.asset,
            key: ValueKey(heroId),
            name: 'playable_hero_$heroId',
            position: vm.Vector3(0, 0, 0),
            scale: vm.Vector3.all(0.46),
            animations: [
              SceneAnimationSpec(model.idle, loop: true, speed: 1),
            ],
            error: (context, error) => SceneNode(
              children: const [],
            ),
          ),
        ],
      ),
    );
  }
}
