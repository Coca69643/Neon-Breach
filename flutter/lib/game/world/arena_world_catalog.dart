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
  static const double corridorMinOffset = 1.18;
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

/// Shared 180 × 140 urban MOBA battlefield. Coordinates match the offline
/// terrain baker; movement, camera and rendered structures use the same axes.
abstract final class ArenaWorldCatalog {
  static const double worldScale = 1.0;
  static const double halfWidth = 90.0;
  static const double halfDepth = 70.0;
  static const double footprintExponent = 8.5;
  static const double riverBankMargin = 0.55;
  static const double treeCollisionRadius = 1.35;

  static const cityInteriors = <(String, double, double)>[
    ('west_south', -63.0, -38.0),
    ('east_south', 63.0, -38.0),
    ('west_north', -63.0, 38.0),
    ('east_north', 63.0, 38.0),
  ];

  /// Two opposing mezzanine routes create a real height layer without
  /// introducing a second navigation grid or increasing entity budgets.
  static const verticalAccesses = <ArenaVerticalAccess>[
    ArenaVerticalAccess(id: 'west_south', x: -63.0, z: -38.0),
    ArenaVerticalAccess(id: 'east_north', x: 63.0, z: 38.0),
  ];

  static const commercialBlocks = <(String, double, double, double)>[
    ('commercial_building_a.glb', -77.0, -52.0, 6.5),
    ('commercial_building_c.glb', 77.0, -52.0, 6.5),
    ('commercial_building_e.glb', -77.0, 52.0, 6.5),
    ('commercial_building_a.glb', 77.0, 52.0, 6.5),
  ];

  static const sideApproachAnchors = <(double, double)>[
    (-58.0, -38.0), (58.0, -38.0),
    (-58.0, 38.0), (58.0, 38.0),
    (-68.0, -12.0), (68.0, -12.0),
    (-68.0, 12.0), (68.0, 12.0),
  ];

  static const _river = <(double, double, double)>[
    (-90.0, 0.0, 1.55), (-60.0, 0.2, 1.85),
    (-30.0, -0.15, 2.05), (0.0, 0.1, 2.15),
    (30.0, -0.1, 2.05), (60.0, 0.15, 1.85),
    (90.0, 0.0, 1.55),
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

  static const _bridges = <double>[-36.0, 0.0, 36.0];
  static const _towerLanes = <double>[-36.0, 0.0, 36.0];
  static const _towerRows = <double>[-52.0, -36.0, -20.0, 20.0, 36.0, 52.0];

  static const _treeBlockers = <(double, double)>[
    (-82, -16), (-82, 16), (82, -16), (82, 16),
    (-72, -58), (72, -58), (-72, 58), (72, 58),
  ];

  static double _edgeWobble(double angle) =>
      1.0 + 0.022 * math.sin(angle * 5.0) +
      0.014 * math.sin(angle * 9.0 + 1.4) +
      0.010 * math.cos(angle * 13.0) +
      0.006 * math.sin(angle * 17.0 + 0.8);

  static bool contains(double x, double z) {
    if (x.abs() > halfWidth * 1.025 || z.abs() > halfDepth * 1.025) {
      return false;
    }
    final angle = math.atan2(z / halfDepth, x / halfWidth);
    final edge = _edgeWobble(angle);
    final extent = math.pow(x.abs() / halfWidth, footprintExponent) +
        math.pow(z.abs() / halfDepth, footprintExponent);
    return extent <= math.pow(edge, footprintExponent);
  }

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
      // 12 × 9 m room, with a real 3.2 m south-facing doorway.
      if (dx <= 6.0 && (dz - 4.3).abs() <= 0.42) return true;
      if (dx <= 6.0 && (dz + 4.3).abs() <= 0.42 && dx > 1.6) return true;
      if ((dx - 5.8).abs() <= 0.42 && dz.abs() <= 4.5) return true;
      // Counter and shelving are physical interior obstacles.
      final hasVerticalAccess = verticalAccesses.any(
        (access) => access.id == building.$1,
      );
      final counterZ = hasVerticalAccess ? cz - 1.35 : cz + 1.35;
      if (dx <= 1.95 && (z - counterZ).abs() <= 0.52) return true;
      if (!hasVerticalAccess &&
          (dx - 4.35).abs() <= 0.48 &&
          (z - (cz + 2.1)).abs() <= 1.35) {
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
    final riverZ = _riverCenterZ(x);
    final channelHalfWidth = _riverHalfWidth(x) + riverBankMargin;
    return _bridges.any((bridgeX) =>
        (x - bridgeX).abs() <= 4.2 &&
        (z - riverZ).abs() <= channelHalfWidth + 2.0);
  }

  static ArenaVerticalAccess? _accessForPoint(double x, double z) {
    for (final access in verticalAccesses) {
      if (access.localSurfaceHeight(x, z) != null) return access;
    }
    return null;
  }

  /// Returns the vertical offset required by the stair or mezzanine surface.
  /// A player can only change elevation by following the stair run incrementally.
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
    if (x > access.rampEndX && currentElevation < access.upperHeight - 0.28) {
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
    double elevation = 0,
  }) {
    if (!contains(x, z) || !_isVerticalSurface(x, z, elevation)) {
      return false;
    }
    final riverDistance = (z - _riverCenterZ(x)).abs();
    final channelWidth = _riverHalfWidth(x) + riverBankMargin;
    if (riverDistance < channelWidth && !_isOnBridge(x, z)) return false;
    if (_insideTowerFootprint(x, z) || _insideBuildingWall(x, z)) return false;
    for (final block in commercialBlocks) {
      final dx = (x - block.$2).abs();
      final dz = (z - block.$3).abs();
      if (dx < 6.8 && dz < 6.8) return false;
    }
    if (includeTreeCollision) {
      final radiusSquared = treeCollisionRadius * treeCollisionRadius;
      for (final tree in _treeBlockers) {
        final dx = x - tree.$1, dz = z - tree.$2;
        if (dx * dx + dz * dz < radiusSquared) return false;
      }
    }
    return true;
  }

  static double navigationHeightAt(
    double x,
    double z, {
    double elevation = 0,
  }) {
    final base = heightAt(x, z) + elevation;
    final access = _accessForPoint(x, z);
    if (access != null) return base;
    if (!_isOnBridge(x, z)) return base;
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
    final roadDrain = -0.035 * math.exp(-math.pow(laneDistance(x, z), 2) / 9.0);
    return rolling + canalBed + curbBank + roadDrain;
  }

  static List<ArenaWorldPlacement> _makeTrees() {
    const variants = <String>['tree_oak', 'tree_pine', 'tree_broadleaf'];
    return List<ArenaWorldPlacement>.unmodifiable(
      _treeBlockers.indexed.map((entry) {
        final index = entry.$1, point = entry.$2;
        return ArenaWorldPlacement(
          asset: 'assets/world/nature/${variants[index % variants.length]}.glb',
          x: point.$1 * worldScale,
          z: point.$2 * worldScale,
          y: heightAt(point.$1, point.$2),
          scale: 0.82 + (index % 3) * 0.07,
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
          x: point.$1 * worldScale,
          z: point.$2 * worldScale,
          y: heightAt(point.$1, point.$2),
          scale: 0.62 + (index % 2) * 0.08,
          yaw: (index * 1.71) % (2 * math.pi),
        );
      }),
    );
  }

  static final trees = _makeTrees();
  static final bushes = _makeBushes();
}
