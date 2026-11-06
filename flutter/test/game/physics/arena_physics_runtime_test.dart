import 'package:flutter_test/flutter_test.dart';

import '../../../lib/game/physics/arena_physics_runtime.dart';
import '../../../lib/game/world/arena_world_catalog.dart';
import '../../../lib/game/match/moba_match_simulation.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ArenaPhysicsRuntime', () {
    late ArenaPhysicsRuntime physics;

    Future<void> advance({
      int frames = 60,
      double moveX = 0,
      double moveZ = 0,
    }) async {
      physics.setInput(moveX, moveZ);
      for (var frame = 0; frame < frames; frame++) {
        physics.update(1 / 60);
      }
    }

    setUp(() async {
      physics = await ArenaPhysicsRuntime.create(
        spawn: const MobaPoint(0, -60),
      );
    });

    tearDown(() {
      physics.dispose();
    });

    test('gravity settles the capsule on the terrain', () async {
      await advance(frames: 60);

      expect(physics.grounded, isTrue);
      expect(physics.verticalVelocity.abs(), lessThan(0.05));
      expect(physics.playerPosition.elevation.abs(), lessThan(0.20));
      expect(
        ArenaWorldCatalog.contains(
          physics.playerPosition.x,
          physics.playerPosition.z,
        ),
        isTrue,
      );
    });

    test('the enlarged entrance is traversable but side walls block movement',
        () async {
      physics.teleport(const MobaPoint(-63, -54));
      await advance(frames: 100, moveZ: 1);
      expect(
        physics.playerPosition.z,
        greaterThan(-47),
        reason: 'the capsule must pass through the 4.8-unit doorway',
      );

      physics.teleport(const MobaPoint(-63, -38));
      await advance(frames: 180, moveX: -1);
      expect(
        physics.playerPosition.x,
        greaterThan(-72.8),
        reason: 'the capsule must stop before the west interior wall',
      );
      expect(physics.grounded, isTrue);
    });

    test('the canal blocks ordinary crossings but leaves bridge corridors open',
        () async {
      physics.teleport(const MobaPoint(18, -5));
      await advance(frames: 120, moveZ: 1);
      expect(
        physics.playerPosition.z,
        lessThan(-3.0),
        reason: 'the canal bank must stop movement away from a bridge',
      );

      physics.teleport(const MobaPoint(0, -5));
      await advance(frames: 150, moveZ: 1);
      expect(
        physics.playerPosition.z,
        greaterThan(3.0),
        reason: 'the central bridge must remain a continuous physical route',
      );
      expect(physics.grounded, isTrue);
    });

    test('the mezzanine ramp connects the ground floor to the upper deck',
        () async {
      final access = ArenaWorldCatalog.verticalAccesses.first;
      final z = (access.corridorMinZ + access.corridorMaxZ) * 0.5;
      physics.teleport(MobaPoint(access.rampStartX + 0.2, z));
      await advance(frames: 70, moveX: 1);

      expect(
        physics.playerPosition.x,
        greaterThan(access.rampEndX - 0.1),
      );
      expect(
        physics.playerPosition.elevation,
        greaterThan(2.8),
        reason: 'the capsule must gain height while climbing the ramp',
      );
      expect(physics.grounded, isTrue);
    });

    test('teleport is an explicit respawn operation and resets velocity',
        () async {
      await advance(frames: 30, moveX: 1);
      expect(physics.horizontalSpeed, greaterThan(0));

      physics.teleport(const MobaPoint(0, -60));
      expect(physics.horizontalSpeed, 0);
      expect(physics.verticalVelocity, 0);
      expect(physics.playerPosition.x, closeTo(0, 0.001));
      expect(physics.playerPosition.z, closeTo(-60, 0.001));
    });
  });
}
