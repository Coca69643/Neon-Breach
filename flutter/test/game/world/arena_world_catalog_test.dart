import 'package:flutter_test/flutter_test.dart';
import 'package:project_arena_flutter/game/world/arena_world_catalog.dart';

void main() {
  group('ArenaWorldCatalog — urban battlefield', () {
    test('uses the same 180 × 140 bounds as the offline terrain baker', () {
      expect(ArenaWorldCatalog.halfWidth, 90);
      expect(ArenaWorldCatalog.halfDepth, 70);
      expect(ArenaWorldCatalog.worldScale, 1);
      expect(ArenaWorldCatalog.contains(80, 0), isTrue);
      expect(ArenaWorldCatalog.contains(-80, 0), isTrue);
      expect(ArenaWorldCatalog.contains(0, 62), isTrue);
      expect(ArenaWorldCatalog.contains(0, -62), isTrue);
      expect(ArenaWorldCatalog.contains(89, 69), isFalse);
    });

    test('keeps three lanes aligned with the generated urban terrain', () {
      for (var z = -68.0; z <= 68.0; z += 2.0) {
        expect(ArenaWorldCatalog.laneDistance(-36, z), lessThan(1.0));
        expect(ArenaWorldCatalog.laneDistance(0, z), lessThan(1.0));
        expect(ArenaWorldCatalog.laneDistance(36, z), lessThan(1.0));
      }
    });

    test('has four enterable ground-floor interiors with real doorway gaps', () {
      expect(ArenaWorldCatalog.cityInteriors, hasLength(4));
      for (final building in ArenaWorldCatalog.cityInteriors) {
        final x = building.$2, z = building.$3;
        expect(ArenaWorldCatalog.isWalkable(x, z - 4.3), isTrue,
            reason: 'south doorway must be traversable for ${building.$1}');
        expect(ArenaWorldCatalog.isWalkable(x, z - 2.0), isTrue,
            reason: 'interior floor must be traversable for ${building.$1}');
        expect(ArenaWorldCatalog.isWalkable(x - 5.8, z), isFalse,
            reason: 'side wall must block ${building.$1}');
        expect(ArenaWorldCatalog.isWalkable(x, z + 4.3), isFalse,
            reason: 'rear wall must block ${building.$1}');
        expect(ArenaWorldCatalog.isWalkable(x + 4.5, z - 4.3), isFalse,
            reason: 'front wall segment must block outside the doorway');
      }
    });

    test('canal blocks traversal except at the three avenue crossings', () {
      for (final x in const [-36.0, 0.0, 36.0]) {
        expect(ArenaWorldCatalog.isWalkable(x, 0), isTrue);
      }
      expect(ArenaWorldCatalog.isWalkable(18, 0), isFalse);
      expect(ArenaWorldCatalog.isWalkable(18, 2.5), isFalse);
    });

    test('side alleys connect the avenues to the city blocks', () {
      expect(ArenaWorldCatalog.sideApproachAnchors, hasLength(8));
      for (final point in ArenaWorldCatalog.sideApproachAnchors) {
        expect(ArenaWorldCatalog.isWalkable(point.$1, point.$2), isTrue);
      }
    });

    test('commercial blocks and park dressing are deterministic', () {
      expect(ArenaWorldCatalog.commercialBlocks, hasLength(4));
      expect(ArenaWorldCatalog.trees, hasLength(8));
      expect(ArenaWorldCatalog.bushes, hasLength(4));
      for (final placement in [
        ...ArenaWorldCatalog.trees,
        ...ArenaWorldCatalog.bushes,
      ]) {
        expect(placement.x.isFinite, isTrue);
        expect(placement.y.isFinite, isTrue);
        expect(placement.z.isFinite, isTrue);
        expect(placement.scale, greaterThan(0));
        expect(placement.yaw.isFinite, isTrue);
      }
    });

    test('urban terrain height remains finite across the playable field', () {
      for (var x = -88.0; x <= 88.0; x += 4.0) {
        for (var z = -68.0; z <= 68.0; z += 4.0) {
          expect(ArenaWorldCatalog.heightAt(x, z).isFinite, isTrue);
        }
      }
    });
  });
}
