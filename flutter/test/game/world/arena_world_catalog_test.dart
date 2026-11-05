import 'package:flutter_test/flutter_test.dart';
import 'package:project_arena_flutter/game/world/arena_world_catalog.dart';

void main() {
  group('ArenaWorldCatalog', () {
    test('provides deterministic, offline vegetation placements', () {
      expect(ArenaWorldCatalog.trees, hasLength(32));
      expect(ArenaWorldCatalog.bushes, hasLength(12));

      for (final placement in [
        ...ArenaWorldCatalog.trees,
        ...ArenaWorldCatalog.bushes,
      ]) {
        expect(placement.asset, startsWith('assets/world/nature/'));
        expect(placement.x.isFinite, isTrue);
        expect(placement.y.isFinite, isTrue);
        expect(placement.z.isFinite, isTrue);
        expect(placement.scale, greaterThan(0));
        expect(placement.yaw.isFinite, isTrue);
      }
    });

    test('new map limits provide a broad rectangular footprint', () {
      expect(ArenaWorldCatalog.contains(31, 0), isTrue);
      expect(ArenaWorldCatalog.contains(0, 27), isTrue);
      expect(ArenaWorldCatalog.contains(33, 29), isFalse);
      expect(ArenaWorldCatalog.contains(0, 33), isFalse);
    });

    test('three routes remain aligned and continuous', () {
      for (var z = -30.0; z <= 30.0; z += 2.0) {
        expect(ArenaWorldCatalog.laneDistance(-15, z), lessThan(1.0));
        expect(ArenaWorldCatalog.laneDistance(0, z), lessThan(1.0));
        expect(ArenaWorldCatalog.laneDistance(15, z), lessThan(1.0));
      }
    });

    test('terrain height samples remain finite across the battlefield', () {
      for (var x = -34.0; x <= 34.0; x += 2.0) {
        for (var z = -30.0; z <= 30.0; z += 2.0) {
          expect(ArenaWorldCatalog.heightAt(x, z).isFinite, isTrue);
        }
      }
    });

    test('world coordinates use the shared map scale', () {
      expect(ArenaWorldCatalog.worldScale, 1.15);
      expect(ArenaWorldCatalog.trees.first.x, closeTo(-25 * 1.15, 0.0001));
    });
  });
}
