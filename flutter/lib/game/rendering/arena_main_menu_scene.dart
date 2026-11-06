import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import '../world/arena_world_catalog.dart';

/// Ground-level view of the actual urban battlefield. The main menu reuses
/// the same terrain, building placements and street dressing as a match;
/// there is no separate floating tower or disconnected hub environment.
class ArenaMainMenuScene extends StatelessWidget {
  const ArenaMainMenuScene({super.key});

  static const _terrainAsset = 'assets/world/arena_terrain.glb';

  List<Widget> _buildScene() {
    final nearbyTrees = ArenaWorldCatalog.largeTrees
        .where((item) => item.x < 0 && item.z < 0)
        .take(3);
    final nearbyStreetProps = ArenaWorldCatalog.cityProps
        .where((item) => item.x < 0 && item.z < 0)
        .take(12);

    return [
      SceneModel(
        _terrainAsset,
        key: const ValueKey('menu-battlefield-terrain'),
        name: 'project_arena_city_terrain',
      ),
      for (final block in ArenaWorldCatalog.commercialBlocks)
        SceneModel(
          'assets/world/city/${block.$1}',
          key: ValueKey('menu-building-${block.$1}'),
          name: 'menu_city_${block.$1.replaceAll('.glb', '')}',
          position: vm.Vector3(
            block.$2,
            ArenaWorldCatalog.navigationHeightAt(block.$2, block.$3),
            block.$3,
          ),
          scale: vm.Vector3.all(block.$4),
        ),
      for (final placement in nearbyTrees)
        SceneModel(
          placement.asset,
          key: ValueKey('menu-tree-${placement.x}-${placement.z}'),
          name: 'menu_park_tree',
          position: vm.Vector3(placement.x, placement.y, placement.z),
          rotation: vm.Quaternion.axisAngle(
            vm.Vector3(0, 1, 0),
            placement.yaw,
          ),
          scale: vm.Vector3.all(placement.scale),
        ),
      for (final placement in nearbyStreetProps)
        SceneModel(
          placement.asset,
          key: ValueKey('menu-street-${placement.x}-${placement.z}'),
          name: 'menu_street_detail',
          position: vm.Vector3(placement.x, placement.y, placement.z),
          rotation: vm.Quaternion.axisAngle(
            vm.Vector3(0, 1, 0),
            placement.yaw,
          ),
          scale: vm.Vector3.all(placement.scale),
        ),
      SceneModel(
        'assets/world/city/road_straight.glb',
        key: const ValueKey('menu-main-road'),
        name: 'menu_commercial_avenue',
        position: vm.Vector3(
          -82,
          ArenaWorldCatalog.navigationHeightAt(-82, -48),
          -48,
        ),
        rotation: vm.Quaternion.axisAngle(
          vm.Vector3(0, 1, 0),
          math.pi / 2,
        ),
        scale: vm.Vector3(12, 1, 20),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    const scale = ArenaWorldCatalog.worldScale;

    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: [0.0, 0.5, 1.0],
              colors: [
                Color(0xFF9DC4CF),
                Color(0xFF657E86),
                Color(0xFF27343A),
              ],
            ),
          ),
        ),
        Positioned.fill(
          child: SceneView.declarative(
            key: const ValueKey('arena-main-menu-city-scene'),
            pixelRatio: 0.76,
            maxFrameRate: 30,
            environmentIntensity: 1.12,
            exposure: 1.0,
            cameraBuilder: (elapsed) {
              final seconds = elapsed.inMicroseconds / 1000000.0;
              final drift = math.sin(seconds * 0.025) * 0.22;
              final lift = math.sin(seconds * 0.018) * 0.035;
              return PerspectiveCamera(
                fovRadiansY: 48 * math.pi / 180,
                position: vm.Vector3(
                  (-96 + drift) * scale,
                  (10.5 + lift) * scale,
                  -72 * scale,
                ),
                target: vm.Vector3(-81 * scale, 2.2 * scale, -45 * scale),
                fovNear: 0.1,
                fovFar: 220,
              );
            },
            loadingBuilder: (context, progress) => const Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFFE4C58D),
                ),
              ),
            ),
            children: [
              SceneNode(
                name: 'menu_city_world_scale',
                scale: vm.Vector3.all(scale),
                children: _buildScene(),
              ),
            ],
          ),
        ),
        const IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.0, 0.28, 0.72, 1.0],
                colors: [
                  Color(0x44101D25),
                  Color(0x000D1720),
                  Color(0x000D1720),
                  Color(0xB90A1219),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
