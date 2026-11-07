import 'package:flutter_test/flutter_test.dart';
import 'package:project_arena_flutter/game/world/arena_world_catalog.dart';

void main() {
  group('ArenaWorldCatalog — urban battlefield', () {
    test('uses the same irregular 224 × 188 boundary as the terrain baker', () {
      expect(ArenaWorldCatalog.halfWidth, 112);
      expect(ArenaWorldCatalog.halfDepth, 94);
      expect(ArenaWorldCatalog.worldScale, 1.35);
      expect(ArenaWorldCatalog.contains(100, 0), isTrue);
      expect(ArenaWorldCatalog.contains(-100, 0), isTrue);
      expect(ArenaWorldCatalog.contains(0, 80), isTrue);
      expect(ArenaWorldCatalog.contains(0, -80), isTrue);
      expect(ArenaWorldCatalog.contains(110, 90), isFalse);
      expect(ArenaWorldCatalog.contains(-110, -90), isFalse);
      expect(ArenaWorldCatalog.worldBoundary.length, greaterThanOrEqualTo(20));
      expect(ArenaWorldCatalog.districts, hasLength(6));
      expect(ArenaWorldCatalog.districtSites, hasLength(6));
      for (final site in ArenaWorldCatalog.districtSites) {
        expect(ArenaWorldCatalog.isWalkable(site.$3, site.$4), isTrue,
            reason: '${site.$2} must be a walkable capture point');
      }
    });

    test('base service guides spawn on walkable terrain near each allied lane', () {
      const guideAnchors = <(double, double)>[
        (-33.0, -55.0),
        (3.0, -55.0),
        (39.0, -55.0),
      ];
      for (final point in guideAnchors) {
        expect(
          ArenaWorldCatalog.isWalkable(point.$1, point.$2),
          isTrue,
          reason: 'service guide anchor ${point.$1}, ${point.$2} must be walkable',
        );
      }
    });

    test('keeps three lanes aligned with the generated urban terrain', () {
      for (var z = -68.0; z <= 68.0; z += 2.0) {
        expect(ArenaWorldCatalog.laneDistance(-36, z), lessThan(1.0));
        expect(ArenaWorldCatalog.laneDistance(0, z), lessThan(1.0));
        expect(ArenaWorldCatalog.laneDistance(36, z), lessThan(1.0));
      }
    });

    test('has six human-scale enterable interiors with wide doorway gaps', () {
      expect(ArenaWorldCatalog.cityInteriors, hasLength(6));
      expect(ArenaWorldCatalog.roomHalfWidth, 12);
      expect(ArenaWorldCatalog.roomHalfDepth, 9);
      expect(ArenaWorldCatalog.roomDoorHalfWidth, 3.2);
      for (final building in ArenaWorldCatalog.cityInteriors) {
        final x = building.$2, z = building.$3;
        expect(ArenaWorldCatalog.isWalkable(
          x, z - ArenaWorldCatalog.roomHalfDepth,
        ), isTrue, reason: 'doorway must be traversable for ${building.$1}');
        expect(ArenaWorldCatalog.isWalkable(x, z - 2.0), isTrue,
            reason: 'interior floor must be traversable for ${building.$1}');
        expect(ArenaWorldCatalog.isWalkable(
          x - ArenaWorldCatalog.roomHalfWidth, z,
        ), isFalse, reason: 'side wall must block ${building.$1}');
        expect(ArenaWorldCatalog.isWalkable(
          x, z + ArenaWorldCatalog.roomHalfDepth,
        ), isFalse, reason: 'rear wall must block ${building.$1}');
        expect(ArenaWorldCatalog.isWalkable(
          x + 4.5, z - ArenaWorldCatalog.roomHalfDepth,
        ), isFalse, reason: 'front wall segment must block outside the doorway');
      }
    });

    test('tower footprints can be ignored by lane units without weakening player collision', () {
      expect(
        ArenaWorldCatalog.isWalkable(-36, -52),
        isFalse,
        reason: 'players must not walk through towers',
      );
      expect(
        ArenaWorldCatalog.isWalkable(
          -36, -52, includeTowerCollision: false,
        ),
        isTrue,
        reason: 'bots and minions need to pass their own tower rows',
      );
    });

    test('canal is traversable at five bridges and blocked between them', () {
      const crossings = <(double, double)>[
        (-72.0, -2.8), (-36.0, 0.8), (0.0, 0.5),
        (36.0, -0.84), (72.0, 2.28),
      ];
      for (final crossing in crossings) {
        expect(ArenaWorldCatalog.isWalkable(crossing.$1, crossing.$2), isTrue);
        expect(ArenaWorldCatalog.isBridgeAt(crossing.$1, crossing.$2), isTrue);
      }
      expect(ArenaWorldCatalog.isWalkable(18, 0), isFalse);
      expect(ArenaWorldCatalog.isWalkable(18, 2.5), isTrue);
      expect(ArenaWorldCatalog.isCanalAt(100, 0), isFalse);
    });

    test('side alleys connect the avenues to the city blocks', () {
      expect(ArenaWorldCatalog.sideApproachAnchors, hasLength(16));
      for (final point in ArenaWorldCatalog.sideApproachAnchors) {
        expect(ArenaWorldCatalog.isWalkable(point.$1, point.$2), isTrue);
      }
    });

    test('commercial blocks and park dressing are deterministic', () {
      expect(ArenaWorldCatalog.commercialBlocks, hasLength(8));
      for (final block in ArenaWorldCatalog.commercialBlocks) {
        expect(ArenaWorldCatalog.isWalkable(block.$2, block.$3), isFalse,
            reason: 'commercial block must have a collision footprint');
      }
      expect(ArenaWorldCatalog.trees, hasLength(16));
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

    test('city districts use distinct architecture and authored street dressing', () {
      final buildingNames = ArenaWorldCatalog.commercialBlocks
          .map((block) => block.$1)
          .toSet();
      expect(buildingNames, hasLength(8));
      expect(ArenaWorldCatalog.largeTrees, hasLength(8));
      expect(ArenaWorldCatalog.cityProps.length, greaterThanOrEqualTo(40));

      for (final prop in ArenaWorldCatalog.cityProps) {
        expect(prop.x.isFinite && prop.y.isFinite && prop.z.isFinite, isTrue);
        expect(prop.scale, greaterThan(0));
        expect(
          ArenaWorldCatalog.isWalkable(prop.x, prop.z),
          isTrue,
          reason: '${prop.asset} must dress a walkable point, not block an entrance or lane',
        );
      }
      for (final tree in ArenaWorldCatalog.largeTrees) {
        expect(
          ArenaWorldCatalog.isWalkable(
            tree.x, tree.z, includeTreeCollision: false,
          ),
          isTrue,
          reason: 'large park trees must stay inside the playable land footprint',
        );
        expect(
          ArenaWorldCatalog.isWalkable(tree.x, tree.z),
          isFalse,
          reason: 'large park trees must remain solid obstacles',
        );
      }
    });

    test('service NPC patrol points remain walkable inside their own interiors', () {
      const routes = <List<(double, double)>>[
        [(-57.0, -44.0), (-53.0, -44.0), (-53.0, -35.0), (-57.0, -35.0)],
        [(66.0, -43.0), (71.0, -43.0), (69.0, -34.0), (66.0, -34.0)],
        [(-67.0, 34.0), (-58.0, 34.0), (-58.0, 43.0), (-67.0, 43.0)],
        [(64.0, 34.0), (69.0, 34.0), (69.0, 43.0), (64.0, 43.0)],
        [(-96.0, -22.0), (-90.0, -22.0), (-90.0, -18.0), (-96.0, -18.0)],
        [(80.0, 12.0), (86.0, 12.0), (86.0, 16.0), (80.0, 16.0)],
      ];

      expect(routes, hasLength(6));
      for (final route in routes) {
        expect(route, hasLength(4));
        for (final point in route) {
          expect(
            ArenaWorldCatalog.isWalkable(point.$1, point.$2),
            isTrue,
            reason: 'NPC patrol must stay inside an accessible interior floor',
          );
        }
      }
    });

    test('two opposing mezzanines require continuous stair traversal', () {
      expect(ArenaWorldCatalog.verticalAccesses, hasLength(2));
      for (final access in ArenaWorldCatalog.verticalAccesses) {
        final z = access.z + 2.4;
        final startX = access.rampStartX;
        expect(ArenaWorldCatalog.resolveNavigationElevation(
          startX, z, 0,
        ), 0);
        expect(ArenaWorldCatalog.isWalkable(startX, z), isTrue);

        var elevation = 0.0;
        for (var step = 1; step <= 25; step++) {
          final x = startX + ArenaVerticalAccess.rampRun * step / 25;
          final next = ArenaWorldCatalog.resolveNavigationElevation(
            x, z, elevation,
          );
          expect(next, isNotNull,
              reason: '${access.id} stair must be continuously traversable');
          elevation = next!;
          expect(ArenaWorldCatalog.isWalkable(
            x, z, elevation: elevation,
          ), isTrue);
        }

        expect(elevation, closeTo(ArenaVerticalAccess.upperHeight, 0.001));
        final deckX = access.x + ArenaVerticalAccess.platformLength * 0.5;
        expect(ArenaWorldCatalog.isWalkable(
          deckX, z, elevation: ArenaVerticalAccess.upperHeight,
        ), isTrue);
        expect(ArenaWorldCatalog.isWalkable(deckX, z), isFalse,
            reason: 'ground-floor movement must not snap through the deck');
        expect(ArenaWorldCatalog.resolveNavigationElevation(
          deckX, z, 0,
        ), isNull);
        expect(ArenaWorldCatalog.resolveNavigationElevation(
          access.platformEndX + 0.4, z, ArenaVerticalAccess.upperHeight,
        ), isNull, reason: 'the elevated route must remain bounded');
      }
    });

    test('surface profiles distinguish lanes, plazas, grass and interiors', () {
      expect(
        ArenaWorldCatalog.surfaceAt(-36, -60),
        ArenaSurfaceType.asphalt,
      );
      expect(
        ArenaWorldCatalog.surfaceAt(-30, -60),
        ArenaSurfaceType.concrete,
        reason: 'the sidewalk band should sit outside the asphalt lane',
      );
      expect(
        ArenaWorldCatalog.surfaceAt(-50, -36),
        ArenaSurfaceType.asphalt,
        reason: 'the side access road should share the continuous asphalt mesh',
      );
      expect(
        ArenaWorldCatalog.surfaceAt(-86, 14),
        ArenaSurfaceType.grass,
      );
      expect(
        ArenaWorldCatalog.surfaceAt(-63, -38),
        ArenaSurfaceType.interior,
      );
      expect(
        ArenaWorldCatalog.movementSpeedMultiplierAt(-36, -60),
        greaterThan(ArenaWorldCatalog.movementSpeedMultiplierAt(-86, 14)),
      );
    });

    test('visible interior furniture has matching navigation blockers', () {
      expect(ArenaWorldCatalog.interiorFurnitureFootprints, isNotEmpty);
      for (final item in ArenaWorldCatalog.interiorFurnitureFootprints) {
        expect(
          ArenaWorldCatalog.isWalkable(item.$3, item.$4),
          isFalse,
          reason: '${item.$1} must not be traversable through',
        );
      }
    });

    test('urban terrain height remains finite across the playable field', () {
      for (var x = -108.0; x <= 108.0; x += 4.0) {
        for (var z = -90.0; z <= 90.0; z += 4.0) {
          expect(ArenaWorldCatalog.heightAt(x, z).isFinite, isTrue);
        }
      }
    });
  });
}
