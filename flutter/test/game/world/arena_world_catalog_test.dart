import 'package:flutter_test/flutter_test.dart';
import 'package:project_arena_flutter/game/world/arena_world_catalog.dart';

void main() {
  group('ArenaWorldCatalog', () {
    test('provides deterministic, offline vegetation placements', () {
      expect(ArenaWorldCatalog.trees, hasLength(30));
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

    test('expanded map extends to both flanks and north/south ends', () {
      expect(ArenaWorldCatalog.halfWidth, 60);
      expect(ArenaWorldCatalog.halfDepth, 42);
      expect(ArenaWorldCatalog.contains(48, 0), isTrue);
      expect(ArenaWorldCatalog.contains(-48, 0), isTrue);
      expect(ArenaWorldCatalog.contains(0, 35), isTrue);
      expect(ArenaWorldCatalog.contains(0, -35), isTrue);
      expect(ArenaWorldCatalog.contains(58, 40), isFalse);
    });

    test('four flank courtyards are enterable and river only crosses at bridges', () {
      for (final area in ArenaWorldCatalog.sideApproachAnchors) {
        expect(
          ArenaWorldCatalog.isWalkable(area.$1, area.$2),
          isTrue,
          reason: 'side approach ${area.$1}, ${area.$2} must be traversable',
        );
      }
      expect(ArenaWorldCatalog.isWalkable(0, 15), isTrue);
      expect(ArenaWorldCatalog.isWalkable(8, 16), isFalse);
      expect(ArenaWorldCatalog.isWalkable(0, -10), isFalse);
      expect(ArenaWorldCatalog.isWalkable(4, -10), isTrue);
      expect(ArenaWorldCatalog.isWalkable(58, 40), isFalse);
    });

    test('three routes remain aligned and continuous', () {
      for (var z = -40.0; z <= 40.0; z += 2.0) {
        expect(ArenaWorldCatalog.laneDistance(-22.5, z), lessThan(1.0));
        expect(ArenaWorldCatalog.laneDistance(0, z), lessThan(1.0));
        expect(ArenaWorldCatalog.laneDistance(22.5, z), lessThan(1.0));
      }
    });

    test('terrain height samples remain finite across the battlefield', () {
      for (var x = -56.0; x <= 56.0; x += 2.0) {
        for (var z = -38.0; z <= 38.0; z += 2.0) {
          expect(ArenaWorldCatalog.heightAt(x, z).isFinite, isTrue);
        }
      }
    });

    test('world coordinates use the shared map scale', () {
      expect(ArenaWorldCatalog.worldScale, 1.15);
      expect(ArenaWorldCatalog.trees.first.x, closeTo(-54 * 1.15, 0.0001));
    });
  });
}
