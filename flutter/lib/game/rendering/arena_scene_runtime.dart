import 'package:flutter_scene/scene.dart';

/// Owns one-time initialization of Flutter Scene's shared GPU resources.
///
/// Call this before constructing scene materials, meshes, or model nodes.
/// The app must enable Flutter GPU in its Android host.
abstract final class ArenaSceneRuntime {
  static Future<void>? _initialization;

  static Future<void> initialize() {
    return _initialization ??= Scene.initializeStaticResources();
  }
}
