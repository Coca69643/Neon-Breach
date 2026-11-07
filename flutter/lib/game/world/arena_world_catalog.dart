import 'dart:math' as math;

class ArenaVerticalAccess {
  const ArenaVerticalAccess({
    required this.id,
    required this.x,
    required this.z,
  });

  final String id;
  final double x;
  final double z;

  static const double rampRun = 5.014;
  static const double upperHeight = 3.35;
  static const double platformLength = 5.0;
  static const double platformDepth = 2.3;
  static const double corridorMinOffset = 1.22;
  static const double corridorMaxOffset = 3.52;

  double get rampStartX => x - rampRun;
  double get rampEndX => x;
  double get platformEndX => x + platformLength;
  double get corridorMinZ => z + corridorMinOffset;
  double get corridorMaxZ => z + corridorMaxOffset;

  double? localSurfaceHeight(double px, double pz) {
    if (pz < corridorMinZ || pz > corridorMaxZ) return null;
    if (px >= rampStartX && px <= rampEndX) {
      final t = ((px - rampStartX) / rampRun).clamp(0.0, 1.0).toDouble();
      return upperHeight * t;
    }
    if (px > rampEndX && px <= platformEndX) return upperHeight;
    return null;
  }
}

enum ArenaSurfaceType { asphalt, concrete, grass, interior }

class ArenaWorldPlacement {
  const ArenaWorldPlacement({
    required this.asset,
    required this.x,
    required this.z,
    required this.y,
    required this.scale,
    required this.yaw,
  });

  final String asset;
  final double x;
  final double z;
  final double y;
  final double scale;
  final double yaw;
}

/// Logical 224 × 188 battlefield assembled from six connected districts.
/// Rendering applies one 1.35× transform; navigation and Rapier share the same
/// logical coordinates so visual ground and collision remain aligned.
abstract final class ArenaWorldCatalog {
  static const double worldScale = 1.35;
  static const double halfWidth = 112.0;
  static const double halfDepth = 94.0;
  static const double roomHalfWidth = 12.0;
  static const double roomHalfDepth = 9.0;
  static const double roomDoorHalfWidth = 3.2;
  static const double roomWallHalfThickness = 0.42;
  static const double roomWallHalfHeight = 1.8;
  static const double riverBankMargin = 0.55;
  static const double treeCollisionRadius = 1.55;
  static const double canalStartX = -90.0;
  static const double canalEndX = 90.0;
  static const double bridgeHalfWidth = 4.2;

  static const worldBoundary = <(double, double)>[
    (-72.0, -86.0), (-40.0, -92.0), (8.0, -89.0), (48.0, -93.0),
    (82.0, -84.0), (101.0, -69.0), (109.0, -44.0), (104.0, -17.0),
    (111.0, 10.0), (104.0, 37.0), (91.0, 60.0), (71.0, 82.0),
    (42.0, 87.0), (8.0, 82.0), (-24.0, 88.0), (-56.0, 82.0),
    (-82.0, 70.0), (-101.0, 48.0), (-108.0, 22.0), (-103.0, -6.0),
    (-109.0, -34.0), (-97.0, -62.0), (-84.0, -78.0),
  ];

  static const cityInteriors = <(String, double, double)>[
    ('west_south', -63.0, -38.0),
    ('east_south', 63.0, -38.0),
    ('west_north', -63.0, 38.0),
    ('east_north', 63.0, 38.0),
    ('west_depot', -88.0, -18.0),
    ('east_depot', 88.0, 18.0),
  ];

  /// Shared furniture footprints used by both path validation and Rapier.
  /// Each record stores (kind, roomId, x, z, halfWidth, halfDepth).
  static final interiorFurnitureFootprints =
      _makeInteriorFurnitureFootprints();

  static List<(String, String, double, double, double, double)>
      _makeInteriorFurnitureFootprints() {
    final items = <(String, String, double, double, double, double)>[];
    for (final building in cityInteriors) {
      final id = building.$1, x = building.$2, z = building.$3;
      final hasVerticalAccess =
          verticalAccesses.any((access) => access.id == id);
      final deskX = hasVerticalAccess ? x - 6.0 : x - 5.2;
      final deskZ = hasVerticalAccess ? z - 2.4 : z + 2.5;
      final chairZ = hasVerticalAccess ? z - 1.8 : z + 2.0;
      final benchZ = hasVerticalAccess ? z - 4.2 : z - 3.0;
      items
        ..add(('desk', id, deskX, deskZ,
            hasVerticalAccess ? 2.0 : 1.6, 0.72))
        ..add(('chair', id, x + 1.6, chairZ, 0.42, 0.42))
        ..add(('bench', id, x + 3.0, benchZ, 1.0, 0.55));
      if (!hasVerticalAccess) {
        items.add(('shelf', id, x - 8.5, z + 4.0, 0.6, 1.8));
      }
    }
    return List.unmodifiable(items);
  }

  static const districts = <(String, String, double, double)>[
    ('civic', 'Distrito Cívico', -72.0, 56.0),
    ('park', 'Reserva Verde', -86.0, 14.0),
    ('market', 'Mercado Central', 12.0, -54.0),
    ('industrial', 'Pátio Industrial', 82.0, -48.0),
    ('transit', 'Estação Intermodal', 76.0, 53.0),
    ('riverside', 'Orla do Canal', 0.0, 17.0),
  ];

  /// District capture points share the six authored district anchors.
  static const districtSites = districts;

  /// Two opposing mezzanine routes create a real height layer without
  /// introducing a second navigation grid or increasing entity budgets.
  static const verticalAccesses = <ArenaVerticalAccess>[
    ArenaVerticalAccess(id: 'west_south', x: -63.0, z: -38.0),
    ArenaVerticalAccess(id: 'east_north', x: 63.0, z: 38.0),
  ];

  // Ten CC0 silhouettes: the original district edges plus the Market Central slice.
  static const commercialBlocks = <(String, double, double, double)>[
    ('commercial_building_b.glb', -82.0, -60.0, 5.8),
    ('commercial_building_c.glb', 82.0, -60.0, 5.8),
    ('commercial_building_f.glb', -82.0, 60.0, 5.8),
    ('commercial_building_h.glb', 82.0, 60.0, 5.8),
    ('commercial_building_d.glb', -98.0, -42.0, 5.0),
    ('commercial_building_g.glb', 98.0, 42.0, 5.0),
    ('suburban_building_a.glb', -98.0, 42.0, 4.8),
    ('suburban_building_c.glb', 98.0, -42.0, 4.8),
    ('commercial_building_i.glb', 20.5, -68.0, 5.0),
    ('commercial_building_j.glb', 20.5, -40.0, 5.0),
  ];

  static const sideApproachAnchors = <(double, double)>[
    (-58.0, -38.0), (58.0, -38.0),
    (-58.0, 38.0), (58.0, 38.0),
    (-68.0, -12.0), (68.0, -12.0),
    (-68.0, 12.0), (68.0, 12.0),
    (-92.0, -30.0), (92.0, 30.0),
    (-92.0, 30.0), (92.0, -30.0),
    (-72.0, -72.0), (72.0, 72.0),
    (-42.0, 76.0), (42.0, -76.0),
  ];

  static const _river = <(double, double, double)>[
    (-90.0, -4.0, 1.55), (-60.0, -2.0, 1.85),
    (-30.0, 1.5, 2.05), (0.0, 0.5, 2.15),
    (30.0, -1.5, 2.05), (60.0, 1.8, 1.85),
    (90.0, 3.0, 1.55),
  ];

  static const _lanes = <List<(double, double)>>[
    [(-36.0, -70), (-36.5, -52), (-35.8, -35), (-36.2, -18),
      (-35.8, 0), (-36.2, 18), (-35.8, 35), (-36.5, 52), (-36.0, 70)],
    [(0.0, -70), (0.4, -52), (-0.3, -35), (0.3, -18),
      (-0.2, 0), (0.3, 18), (-0.3, 35), (0.4, 52), (0.0, 70)],
    [(36.0, -70), (36.5, -52), (35.8, -35), (36.2, -18),
      (35.8, 0), (36.2, 18), (35.8, 35), (36.5, 52), (36.0, 70)],
  ];

  static const _accessPaths = <List<(double, double)>>[
    [(-36, -36), (-46, -36), (-56, -36), (-64, -36)],
    [(36, -36), (46, -36), (56, -36), (64, -36)],
    [(-36, 36), (-46, 36), (-56, 36), (-64, 36)],
    [(36, 36), (46, 36), (56, 36), (64, 36)],
    [(-64, -36), (-70, -26), (-70, -12), (-56, -8), (-36, -8)],
    [(64, -36), (70, -26), (70, -12), (56, -8), (36, -8)],
    [(-64, 36), (-70, 26), (-70, 12), (-56, 8), (-36, 8)],
    [(64, 36), (70, 26), (70, 12), (56, 8), (36, 8)],
  ];

  static const bridgePositions = <double>[-72.0, -36.0, 0.0, 36.0, 72.0];
  static const _bridges = bridgePositions;
  static const _towerLanes = <double>[-36.0, 0.0, 36.0];
  static const _towerRows = <double>[-52.0, -36.0, -20.0, 20.0, 36.0, 52.0];

  static const treeBlockerPoints = <(double, double)>[
    (-100, -4), (-100, 20), (-90, 44), (-72, 74),
    (-91, -34), (-78, -54), (-64, 68), (-46, 72),
    (104, -4), (100, 20), (82, 60), (72, 74),
    (91, -34), (78, -54), (64, 68), (46, 72),
  ];

  static const largeTreePoints = <(double, double)>[
    (-96, -52), (-96, 52), (-58, 76), (-28, 76),
    (96, -52), (90, 52), (58, 76), (28, 76),
  ];

  /// Irregular polygonal footprint shared with the offline terrain baker.
  static bool contains(double x, double z) {
    if (x.abs() > halfWidth || z.abs() > halfDepth) return false;
    var inside = false;
    for (var i = 0, j = worldBoundary.length - 1;
        i < worldBoundary.length;
        j = i++) {
      final xi = worldBoundary[i].$1, zi = worldBoundary[i].$2;
      final xj = worldBoundary[j].$1, zj = worldBoundary[j].$2;
      final crosses = ((zi > z) != (zj > z)) &&
          (x < (xj - xi) * (z - zi) / (zj - zi) + xi);
      if (crosses) inside = !inside;
    }
    return inside;
  }

  static bool isCanalAt(double x, double z) =>
      x >= canalStartX &&
      x <= canalEndX &&
      (z - _riverCenterZ(x)).abs() <
          _riverHalfWidth(x) + riverBankMargin;

  static bool isBridgeAt(double x, double z) =>
      x >= canalStartX && x <= canalEndX && _isOnBridge(x, z);

  static double canalBankZAt(double x, {required bool north}) {
    final half = _riverHalfWidth(x) + riverBankMargin;
    return _riverCenterZ(x) + (north ? half : -half);
  }

  static List<(double, double)> get towerCollisionPositions =>
      List<(double, double)>.unmodifiable([
        for (final laneX in _towerLanes)
          for (final rowZ in _towerRows) (laneX, rowZ),
      ]);

  static int _riverSegment(double x) {
    if (x <= _river.first.$1) return 0;
    for (var i = 0; i < _river.length - 1; i++) {
      if (x <= _river[i + 1].$1) return i;
    }
    return _river.length - 2;
  }

  static double _riverCenterZ(double x) {
    final index = _riverSegment(x);
    final a = _river[index], b = _river[index + 1];
    final t = ((x - a.$1) / (b.$1 - a.$1)).clamp(0.0, 1.0).toDouble();
    return a.$2 + (b.$2 - a.$2) * t;
  }

  static double _riverHalfWidth(double x) {
    final index = _riverSegment(x);
    final a = _river[index], b = _river[index + 1];
    final t = ((x - a.$1) / (b.$1 - a.$1)).clamp(0.0, 1.0).toDouble();
    return a.$3 + (b.$3 - a.$3) * t;
  }

  static double _pointSegmentDistance(
    double px, double pz, (double, double) a, (double, double) b,
  ) {
    final dx = b.$1 - a.$1, dz = b.$2 - a.$2;
    final lengthSquared = dx * dx + dz * dz;
    if (lengthSquared <= 1e-9) {
      return math.sqrt(math.pow(px - a.$1, 2) + math.pow(pz - a.$2, 2));
    }
    final t = (((px - a.$1) * dx + (pz - a.$2) * dz) / lengthSquared)
        .clamp(0.0, 1.0).toDouble();
    return math.sqrt(math.pow(px - (a.$1 + dx * t), 2) +
        math.pow(pz - (a.$2 + dz * t), 2));
  }

  static double laneDistance(double x, double z) {
    var nearest = double.infinity;
    for (final lane in _lanes) {
      for (var i = 0; i < lane.length - 1; i++) {
        nearest = math.min(nearest,
            _pointSegmentDistance(x, z, lane[i], lane[i + 1]));
      }
    }
    return nearest;
  }

  static double flankPathDistance(double x, double z) {
    var nearest = double.infinity;
    for (final path in _accessPaths) {
      for (var i = 0; i < path.length - 1; i++) {
        nearest = math.min(nearest,
            _pointSegmentDistance(x, z, path[i], path[i + 1]));
      }
    }
    return nearest;
  }

  static bool _insideBuildingWall(double x, double z) {
    for (final building in cityInteriors) {
      final cx = building.$2, cz = building.$3;
      final dx = (x - cx).abs(), dz = z - cz;
      // Six 24 × 18 m rooms with 6.4 m south-facing entrances.
      if (dx <= roomHalfWidth &&
          (dz - roomHalfDepth).abs() <= roomWallHalfThickness) {
        return true;
      }
      if (dx <= roomHalfWidth &&
          (dz + roomHalfDepth).abs() <= roomWallHalfThickness &&
          dx > roomDoorHalfWidth) {
        return true;
      }
      if ((dx - roomHalfWidth).abs() <= roomWallHalfThickness &&
          dz.abs() <= roomHalfDepth + roomWallHalfThickness) {
        return true;
      }
    }
    return false;
  }

  static bool _insideBuildingFurniture(double x, double z) {
    for (final item in interiorFurnitureFootprints) {
      if ((x - item.$3).abs() <= item.$5 + 0.38 &&
          (z - item.$4).abs() <= item.$6 + 0.38) {
        return true;
      }
    }
    return false;
  }

  static bool _insideTowerFootprint(double x, double z) {
    const radiusSquared = 2.8 * 2.8;
    for (final laneX in _towerLanes) {
      for (final rowZ in _towerRows) {
        final dx = x - laneX, dz = z - rowZ;
        if (dx * dx + dz * dz < radiusSquared) return true;
      }
    }
    return false;
  }

  static bool _isOnBridge(double x, double z) {
    if (x < canalStartX || x > canalEndX) return false;
    final riverZ = _riverCenterZ(x);
    final channelHalfWidth = _riverHalfWidth(x) + riverBankMargin;
    return _bridges.any((bridgeX) =>
        (x - bridgeX).abs() <= bridgeHalfWidth &&
        (z - riverZ).abs() <= channelHalfWidth + 2.0);
  }

  static ArenaVerticalAccess? _accessForPoint(double x, double z) {
    for (final access in verticalAccesses) {
      if (access.localSurfaceHeight(x, z) != null) return access;
    }
    return null;
  }

  /// Returns the vertical offset required by the continuous ramp or mezzanine.
  /// Elevation must be followed incrementally to prevent snapping through the deck.
  static double? resolveNavigationElevation(
    double x,
    double z,
    double currentElevation,
  ) {
    final access = _accessForPoint(x, z);
    if (access == null) {
      return currentElevation <= 0.22 ? 0.0 : null;
    }

    final target = access.localSurfaceHeight(x, z)!;
    // The short per-step tolerance allows normal mobile movement while
    // preventing a ground-floor unit from snapping directly onto the deck.
    if ((target - currentElevation).abs() > 0.24) return null;
    if (x > access.rampEndX && currentElevation < ArenaVerticalAccess.upperHeight - 0.28) {
      return null;
    }
    return target;
  }

  static bool _isVerticalSurface(double x, double z, double elevation) {
    final access = _accessForPoint(x, z);
    if (access == null) return elevation <= 0.22;
    final expected = access.localSurfaceHeight(x, z)!;
    return (elevation - expected).abs() <= 0.24;
  }

  static bool isWalkable(
    double x,
    double z, {
    bool includeTreeCollision = true,
    bool includeTowerCollision = true,
    double elevation = 0,
  }) {
    if (!contains(x, z) || !_isVerticalSurface(x, z, elevation)) {
      return false;
    }
    if (isCanalAt(x, z) && !isBridgeAt(x, z)) return false;
    if ((includeTowerCollision && _insideTowerFootprint(x, z)) ||
        _insideBuildingWall(x, z) ||
        _insideBuildingFurniture(x, z)) {
      return false;
    }
    for (final block in commercialBlocks) {
      final dx = (x - block.$2).abs();
      final dz = (z - block.$3).abs();
      final half = block.$4;
      if (dx < half + 0.3 && dz < half + 0.3) return false;
    }
    if (includeTreeCollision) {
      final radiusSquared = treeCollisionRadius * treeCollisionRadius;
      for (final tree in treeBlockerPoints) {
        final dx = x - tree.$1, dz = z - tree.$2;
        if (dx * dx + dz * dz < radiusSquared) return false;
      }
      for (final tree in largeTreePoints) {
        final dx = x - tree.$1, dz = z - tree.$2;
        if (dx * dx + dz * dz < radiusSquared) return false;
      }
    }
    return true;
  }

  /// Surface classification is shared by movement tuning and world tests.
  /// Paved siege lanes are fastest, while grass and interiors have distinct
  /// traction so the same input does not feel identical on every floor.
  // These thresholds mirror prepare_world_assets.py. Asphalt and concrete
  // are raised overlays above the continuous base-terrain mesh.
  static const double asphaltHalfWidth = 4.8;
  static const double asphaltAccessHalfWidth = 3.0;
  static const double sidewalkHalfWidth = 7.4;
  static const double sidewalkAccessHalfWidth = 4.4;

  static ArenaSurfaceType surfaceAt(double x, double z) {
    for (final building in cityInteriors) {
      final dx = (x - building.$2).abs();
      final dz = (z - building.$3).abs();
      if (dx < roomHalfWidth - 0.65 &&
          dz < roomHalfDepth - 0.65) {
        return ArenaSurfaceType.interior;
      }
    }

    final laneGap = laneDistance(x, z);
    final accessGap = flankPathDistance(x, z);
    if (isBridgeAt(x, z) ||
        laneGap <= asphaltHalfWidth ||
        accessGap <= asphaltAccessHalfWidth) {
      return ArenaSurfaceType.asphalt;
    }
    if (laneGap <= sidewalkHalfWidth ||
        accessGap <= sidewalkAccessHalfWidth ||
        sideApproachAnchors.any((point) =>
            math.pow(x - point.$1, 2) + math.pow(z - point.$2, 2) <=
            3.2 * 3.2)) {
      return ArenaSurfaceType.concrete;
    }
    return ArenaSurfaceType.grass;
  }

  static const double asphaltSurfaceLift = 0.11;
  static const double asphaltCrownLift = 0.025;
  static const double concreteSurfaceLift = 0.16;

  /// Surface lift shared by the rendered GLB overlays and Rapier terrain.
  /// Bridges and mezzanines are resolved before this offset is applied.
  static double surfaceElevationOffsetAt(double x, double z) {
    switch (surfaceAt(x, z)) {
      case ArenaSurfaceType.asphalt:
        final laneGap = laneDistance(x, z);
        final accessGap = flankPathDistance(x, z);
        final useLane = laneGap <= accessGap;
        final nearestGap = math.min(laneGap, accessGap);
        final halfWidth = useLane ? asphaltHalfWidth : asphaltAccessHalfWidth;
        final crown = (1.0 - nearestGap / halfWidth).clamp(0.0, 1.0).toDouble();
        return asphaltSurfaceLift + asphaltCrownLift * crown;
      case ArenaSurfaceType.concrete:
        return concreteSurfaceLift;
      case ArenaSurfaceType.grass:
      case ArenaSurfaceType.interior:
        return 0.0;
    }
  }

  static double movementSpeedMultiplierAt(double x, double z) =>
      switch (surfaceAt(x, z)) {
        ArenaSurfaceType.asphalt => 1.0,
        ArenaSurfaceType.concrete => 0.96,
        ArenaSurfaceType.interior => 0.92,
        ArenaSurfaceType.grass => 0.86,
      };

  /// Horizontal velocity damping per second; lower values preserve more glide.
  static double groundFrictionAt(double x, double z) =>
      switch (surfaceAt(x, z)) {
        ArenaSurfaceType.asphalt => 7.5,
        ArenaSurfaceType.concrete => 9.0,
        ArenaSurfaceType.interior => 10.0,
        ArenaSurfaceType.grass => 12.0,
      };

  static double navigationHeightAt(
    double x,
    double z, {
    double elevation = 0,
  }) {
    final base = heightAt(x, z) + elevation;
    final access = _accessForPoint(x, z);
    if (access != null) return base;
    if (!_isOnBridge(x, z)) return base + surfaceElevationOffsetAt(x, z);
    final riverZ = _riverCenterZ(x);
    final bankOffset = _riverHalfWidth(x) + 1.25;
    final nearBank = heightAt(x, riverZ - bankOffset);
    final farBank = heightAt(x, riverZ + bankOffset);
    return math.max(heightAt(x, z) + elevation,
        math.max(nearBank, farBank) + 0.28 + elevation);
  }

  static double heightAt(double x, double z) {
    final rolling = 0.045 * math.sin(x * 0.085) * math.cos(z * 0.072) +
        0.028 * math.sin((x + z) * 0.12) +
        0.018 * math.cos((x - z) * 0.16);
    final riverDistance = (z - _riverCenterZ(x)).abs();
    final riverWidth = _riverHalfWidth(x);
    final canalBed = -0.42 *
        math.exp(-math.pow(riverDistance, 2) / (riverWidth * riverWidth * 1.8));
    final curbBank = 0.12 *
        math.exp(-math.pow(riverDistance - riverWidth - 0.75, 2) / 2.8);
    return rolling + canalBed + curbBank;
  }

  static List<ArenaWorldPlacement> _makeTrees() {
    const variants = <String>[
      'park_tree_oak', 'park_tree_pine', 'park_tree_default',
      'park_tree_palm', 'park_tree_small',
    ];
    return List<ArenaWorldPlacement>.unmodifiable(
      treeBlockerPoints.indexed.map((entry) {
        final index = entry.$1, point = entry.$2;
        return ArenaWorldPlacement(
          asset: 'assets/world/city/${variants[index % variants.length]}.glb',
          x: point.$1,
          z: point.$2,
          y: heightAt(point.$1, point.$2),
          scale: 1.0 + (index % 3) * 0.10,
          yaw: (index * 2.399) % (2 * math.pi),
        );
      }),
    );
  }

  static List<ArenaWorldPlacement> _makeBushes() {
    const points = <(double, double)>[
      (-76, -22), (76, -22), (-76, 22), (76, 22),
    ];
    return List<ArenaWorldPlacement>.unmodifiable(
      points.indexed.map((entry) {
        final index = entry.$1, point = entry.$2;
        return ArenaWorldPlacement(
          asset: 'assets/world/nature/bush_common.glb',
          x: point.$1,
          z: point.$2,
          y: heightAt(point.$1, point.$2),
          scale: 0.62 + (index % 2) * 0.08,
          yaw: (index * 1.71) % (2 * math.pi),
        );
      }),
    );
  }

  static List<ArenaWorldPlacement> _makeLargeTrees() {
    return List<ArenaWorldPlacement>.unmodifiable(
      largeTreePoints.indexed.map((entry) {
        final index = entry.$1;
        final point = entry.$2;
        return ArenaWorldPlacement(
          asset: 'assets/world/city/tree_large.glb',
          x: point.$1,
          z: point.$2,
          y: heightAt(point.$1, point.$2),
          scale: 1.35 + (index % 2) * 0.12,
          yaw: (index * 1.93) % (2 * math.pi),
        );
      }),
    );
  }

  static List<ArenaWorldPlacement> _makeCityProps() {
    final props = <ArenaWorldPlacement>[];

    void add(
      String file,
      double x,
      double z, {
      double scale = 1,
      double yaw = 0,
      double y = 0,
    }) {
      props.add(ArenaWorldPlacement(
        asset: 'assets/world/city/$file',
        x: x,
        z: z,
        y: navigationHeightAt(x, z) + y,
        scale: scale,
        yaw: yaw,
      ));
    }

    // Lamps mark the outer streets without dominating the character scale.
    for (final point in const [
      (-92.0, -60.0), (-60.0, -62.0), (-20.0, -62.0),
      (20.0, 62.0), (60.0, 62.0), (92.0, 0.0),
      (-92.0, 20.0), (92.0, -20.0),
    ]) {
      add('street_light_square.glb', point.$1, point.$2, scale: 1.2);
    }

    // Market Central: two distinct commercial facades frame an open capture plaza.
    // The square remains clear; every building footprint is shared with Rapier/nav.
    add('street_light_square.glb', 7.0, -69.0, scale: 1.0);
    add('street_light_square.glb', 7.0, -39.0, scale: 1.0);
    add('detail_awning_wide.glb', 20.5, -74.0,
        scale: 1.65, yaw: math.pi, y: 1.25);
    add('detail_awning_wide.glb', 20.5, -34.0,
        scale: 1.65, yaw: math.pi, y: 1.25);
    add('detail_parasol_a.glb', 11.0, -47.0, scale: 1.15);
    add('detail_parasol_a.glb', 11.0, -61.0, scale: 1.15);
    for (final point in const [
      (7.0, -47.0), (15.0, -47.0),
      (7.0, -61.0), (15.0, -61.0),
    ]) {
      add('city_planter.glb', point.$1, point.$2, scale: 0.95);
    }

    // Each of the five crossings is signalled from both approaches.
    for (final bridgeX in bridgePositions) {
      add('traffic_light.glb', bridgeX - 6.0,
          _riverCenterZ(bridgeX) - 5.0, scale: 1.2);
      add('traffic_light.glb', bridgeX + 6.0,
          _riverCenterZ(bridgeX) + 5.0, scale: 1.5);
    }

    // Street signs sit on the outer sidewalks, not in the travel corridor.
    for (final point in const [
      (-71.0, -16.0), (71.0, -16.0),
      (-71.0, 16.0), (71.0, 16.0),
    ]) {
      add('road_sign_street.glb', point.$1, point.$2, scale: 1.2);
    }

    // A warning marker identifies the service alley without blocking it.
    add('road_sign_warning.glb', -55.0, -26.0, scale: 1.2, yaw: math.pi / 2);
    add('road_sign_warning.glb', 55.0, 26.0, scale: 1.2, yaw: -math.pi / 2);

    // Every service entrance receives its own canopy and a small street-level prop.
    for (final building in cityInteriors) {
      final x = building.$2;
      final z = building.$3;
      final hasVerticalAccess = verticalAccesses.any(
        (access) => access.id == building.$1,
      );
      add('detail_awning_wide.glb', x, z - 9.55,
          scale: 1.8, yaw: math.pi, y: 1.25);
      // Keep indoor props outside the counter footprint and mezzanine ramp.
      add(
        'interior_trashcan.glb',
        hasVerticalAccess ? x + 7.0 : x + (x < 0 ? 7.0 : -7.0),
        hasVerticalAccess ? z + 3.1 : z - 3.1,
        scale: 0.9,
      );
    }

    // Side plazas use parasols and planters as visual anchors.
    for (final point in const [
      (-54.0, -14.0), (54.0, -14.0),
      (-54.0, 14.0), (54.0, 14.0),
    ]) {
      add('detail_parasol_a.glb', point.$1, point.$2, scale: 1.25);
      add('city_planter.glb', point.$1 + (point.$1 < 0 ? 2.6 : -2.6),
          point.$2 + 1.6, scale: 1.1);
    }

    // Planted edges soften the hard canal geometry without filling the lanes.
    for (final point in const [
      (-15.0, -5.4), (15.0, -5.4), (-15.0, 5.4), (15.0, 5.4),
    ]) {
      add('interior_plant.glb', point.$1, point.$2, scale: 1.0);
    }

    return List<ArenaWorldPlacement>.unmodifiable(props);
  }

  static final trees = _makeTrees();
  static final largeTrees = _makeLargeTrees();
  static final bushes = _makeBushes();
  static final cityProps = _makeCityProps();
}
