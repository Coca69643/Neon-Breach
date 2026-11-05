import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import '../world/arena_world_catalog.dart';

/// Full-screen hub environment used behind the main-menu controls.
///
/// The map is reused as scenery, while the featured hero remains a separate
/// animated GLB. Static nature instances share cached model templates.
class ArenaMainMenuScene extends StatelessWidget {
  const ArenaMainMenuScene({super.key, required this.heroId});

  final String heroId;

  static const _models = <String, ({String asset, String idle})>{
    'lyra': (asset: 'assets/heroes/lyra.glb', idle: 'Female_Idle'),
    'bastion': (asset: 'assets/heroes/bastion.glb', idle: 'Man_Idle'),
    'kairo': (asset: 'assets/heroes/kairo.glb', idle: 'Female_Idle'),
  };

  static const _terrain = 'assets/world/arena_terrain.glb';

  @override
  Widget build(BuildContext context) {
    final hero = _models[heroId] ?? _models['lyra']!;

    final distantTrees = ArenaWorldCatalog.trees
        .where((placement) => placement.z < -3)
        .take(20)
        .toList(growable: false);
    final distantBushes = ArenaWorldCatalog.bushes
        .where((placement) => placement.z < 10)
        .take(8)
        .toList(growable: false);

    final heroX = -4.8;
    final heroZ = 7.2;
    final heroWorldX = heroX * ArenaWorldCatalog.worldScale;
    final heroWorldZ = heroZ * ArenaWorldCatalog.worldScale;
    final heroY = ArenaWorldCatalog.heightAt(heroX, heroZ) + 0.025;

    final children = <Widget>[
      SceneModel(
        _terrain,
        key: const ValueKey('main-menu-terrain'),
        name: 'main_menu_vale_terrain',
      ),
      for (var index = 0; index < distantTrees.length; index++)
        _buildProp(distantTrees[index], 'menu-tree-$index'),
      for (var index = 0; index < distantBushes.length; index++)
        _buildProp(distantBushes[index], 'menu-bush-$index'),
      SceneModel(
        hero.asset,
        key: ValueKey('main-menu-hero-$heroId'),
        name: 'main_menu_featured_hero_$heroId',
        position: vm.Vector3(heroWorldX, heroY, heroWorldZ),
        rotation: vm.Quaternion.axisAngle(
          vm.Vector3(0, 1, 0),
          math.pi,
        ),
        scale: vm.Vector3.all(0.68),
        animations: [
          SceneAnimationSpec(hero.idle, loop: true, speed: 0.72),
        ],
      ),
    ];

    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF91B8C2),
                Color(0xFF527E7B),
                Color(0xFF263E3B),
              ],
            ),
          ),
        ),
        Positioned.fill(
          child: SceneView.declarative(
            key: const ValueKey('arena-main-menu-scene'),
            pixelRatio: 0.85,
            maxFrameRate: 30,
            environmentIntensity: 1.12,
            exposure: 1.03,
            cameraBuilder: (elapsed) {
              final seconds = elapsed.inMicroseconds / 1000000.0;
              final drift = math.sin(seconds * 0.035) * 0.28;
              return PerspectiveCamera(
                fovRadiansY: 42 * math.pi / 180,
                position: vm.Vector3(-1.8 + drift, 7.0, 20.5),
                target: vm.Vector3(-1.2, 1.0, 1.8),
                fovNear: 0.1,
                fovFar: 150,
              );
            },
            loadingBuilder: (context, progress) => const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFFB5E5D6),
                ),
              ),
            ),
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildProp(ArenaWorldPlacement placement, String key) {
    return SceneModel(
      placement.asset,
      key: ValueKey(key),
      name: key.replaceAll('-', '_'),
      position: vm.Vector3(placement.x, placement.y, placement.z),
      rotation: vm.Quaternion.axisAngle(
        vm.Vector3(0, 1, 0),
        placement.yaw,
      ),
      scale: vm.Vector3.all(placement.scale),
    );
  }
}
