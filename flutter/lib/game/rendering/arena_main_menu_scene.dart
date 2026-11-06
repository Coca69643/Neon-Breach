import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

/// Tower-centric main menu scene.
///
/// The command tower is an original grounded GLB generated offline by
/// prepare_menu_hub.py. Its supporting skyline uses bundled Kenney CC0 city
/// models; the live match terrain is intentionally not shown in the menu.
class ArenaMainMenuScene extends StatelessWidget {
  const ArenaMainMenuScene({super.key});

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
              stops: [0.0, 0.52, 1.0],
              colors: [
                Color(0xFF91B8C2),
                Color(0xFF526F7A),
                Color(0xFF202F39),
              ],
            ),
          ),
        ),
        Positioned.fill(
          child: SceneView.declarative(
            key: const ValueKey('arena-main-menu-tower-scene'),
            pixelRatio: 0.82,
            maxFrameRate: 30,
            environmentIntensity: 1.12,
            exposure: 1.0,
            cameraBuilder: (elapsed) {
              final seconds = elapsed.inMicroseconds / 1000000.0;
              final drift = math.sin(seconds * 0.018) * 1.4;
              final lift = math.sin(seconds * 0.014) * 0.18;
              return PerspectiveCamera(
                fovRadiansY: 43 * math.pi / 180,
                position: vm.Vector3(48 + drift, 25 + lift, 65),
                target: vm.Vector3(0, 14.5, 0),
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
                  color: Color(0xFFE0C28B),
                ),
              ),
            ),
            children: [
              const SceneModel(
                'assets/world/arena_menu_hub.glb',
                key: ValueKey('arena-grounded-command-tower'),
                name: 'project_arena_civic_command_tower',
              ),
              SceneModel(
                'assets/world/city/commercial_building_i.glb',
                key: const ValueKey('menu-skyline-west'),
                name: 'menu_city_skyline_west',
                position: vm.Vector3(-43, 0, -26),
                scale: vm.Vector3.all(2.8),
              ),
              SceneModel(
                'assets/world/city/commercial_building_j.glb',
                key: const ValueKey('menu-skyline-east'),
                name: 'menu_city_skyline_east',
                position: vm.Vector3(40, 0, -33),
                scale: vm.Vector3.all(2.6),
              ),
              SceneModel(
                'assets/world/city/tree_large.glb',
                key: const ValueKey('menu-park-tree-west'),
                name: 'menu_park_tree_west',
                position: vm.Vector3(-28, 0, 9),
                scale: vm.Vector3.all(1.25),
              ),
              SceneModel(
                'assets/world/city/tree_large.glb',
                key: const ValueKey('menu-park-tree-east'),
                name: 'menu_park_tree_east',
                position: vm.Vector3(29, 0, 8),
                scale: vm.Vector3.all(1.2),
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
                stops: [0.0, 0.24, 0.7, 1.0],
                colors: [
                  Color(0x4B102334),
                  Color(0x000E1925),
                  Color(0x000E1925),
                  Color(0xAA0A1320),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
