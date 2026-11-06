import 'package:flutter_scene/scene.dart';
import 'package:flutter_scene_rapier/flutter_scene_rapier.dart';

/// Owns one-time initialization of Flutter Scene's shared GPU resources.
///
/// Call this before mounting a SceneView. Failed initialization is not cached,
/// so the application can retry through its recovery state.
abstract final class ArenaSceneRuntime {
  static Future<void>? _initialization;

  static Future<void> initialize() {
    return _initialization ??= _initialize();
  }

  static Future<void> _initialize() async {
    try {
      await RapierWorld.ensureInitialized();
      await Scene.initializeStaticResources();
    } catch (_) {
      _initialization = null;
      rethrow;
    }
  }
}
