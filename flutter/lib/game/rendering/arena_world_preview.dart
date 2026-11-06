import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import '../world/arena_world_catalog.dart';

class ArenaWorldPreview extends StatefulWidget {
  const ArenaWorldPreview({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  State<ArenaWorldPreview> createState() => _ArenaWorldPreviewState();
}

class _ArenaWorldPreviewState extends State<ArenaWorldPreview> {
  final Set<String> _loadedAssets = <String>{};

  static const _terrainAsset = 'assets/world/arena_terrain.glb';

  void _markLoaded(String key) {
    if (!mounted || !_loadedAssets.add(key)) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final totalAssets =
        1 + ArenaWorldCatalog.trees.length + ArenaWorldCatalog.bushes.length;

    final sceneChildren = <Widget>[
      SceneModel(
        _terrainAsset,
        key: const ValueKey('vale-terrain'),
        name: 'vale_das_coroas_organic_terrain',
        onLoaded: (_) => _markLoaded('terrain'),
      ),
      for (var index = 0; index < ArenaWorldCatalog.trees.length; index++)
        _buildProp(ArenaWorldCatalog.trees[index], 'tree-$index'),
      for (var index = 0; index < ArenaWorldCatalog.bushes.length; index++)
        _buildProp(ArenaWorldCatalog.bushes[index], 'bush-$index'),
    ];

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF182B31),
                  Color(0xFF101B20),
                  Color(0xFF0B1217),
                ],
              ),
            ),
          ),
          SceneView.declarative(
            pixelRatio: 0.9,
            maxFrameRate: 30,
            cameraBuilder: (elapsed) {
              final seconds = elapsed.inMicroseconds / 1000000.0;
              final drift = math.sin(seconds * 0.055) * 0.72;
              return PerspectiveCamera(
                fovRadiansY: 49 * math.pi / 180,
                position: vm.Vector3(drift, 73, 39),
                target: vm.Vector3(0, 0.0, 0),
                fovNear: 0.1,
                fovFar: 220,
              );
            },
            children: sceneChildren,
          ),
          const IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.0, 0.14, 0.72, 1.0],
                  colors: [
                    Color(0xB90A1419),
                    Color(0x000A1419),
                    Color(0x000A1419),
                    Color(0xD90A1419),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 22,
            right: 22,
            top: 18,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'DUCK DREAM STUDIOS  /  WORLD PREVIEW',
                        style: TextStyle(
                          color: Color(0xFF9BD9C7),
                          fontSize: 10,
                          letterSpacing: 1.8,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 7),
                      Text(
                        'VALE DAS COROAS',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 27,
                          height: 1,
                          letterSpacing: 1.0,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xC6111E23),
                    border: Border.all(color: const Color(0x5579D6BD)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'ASSETS ${_loadedAssets.length}/$totalAssets',
                    style: const TextStyle(
                      color: Color(0xFFD2E4DE),
                      fontSize: 10,
                      letterSpacing: 1.0,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 22,
            right: 22,
            bottom: 18,
            child: Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PRÉVIA VISUAL  •  SEM GAMEPLAY',
                        style: TextStyle(
                          color: Color(0xFFFFD78C),
                          fontSize: 10,
                          letterSpacing: 1.6,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 5),
                      Text(
                        '3 rotas • Rio em S • Pontes • Bases • Selva',
                        style: TextStyle(
                          color: Color(0xFFD5DFDE),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: widget.onBack,
                  icon: const Icon(Icons.arrow_back_rounded, size: 16),
                  label: const Text('MENU'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Color(0x889BD9C7)),
                    backgroundColor: const Color(0xA6111E23),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
      onLoaded: (_) => _markLoaded(key),
    );
  }
}
