import 'dart:math' as math;

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

/// Shared offline battlefield geometry. Coordinates are authored before the
/// renderer's worldScale, so navigation, river crossings and terrain agree.
abstract final class ArenaWorldCatalog {
  static const double worldScale = 1.15;
  static const double halfWidth = 60.0;
  static const double halfDepth = 42.0;
  static const double footprintExponent = 5.2;
  static const double riverBankMargin = 0.9;
  static const double treeCollisionRadius = 2.25;

  static const _treeBlockers = <(double, double)>[
    (-54, -30), (-51, -17), (-55, 0), (-52, 17), (-54, 31),
    (-50, -8), (-50, 9), (-38, -31), (-38, 31),
    (-44, -38), (-30, -39), (-12, -39), (12, -39), (30, -39), (44, -38),
    (54, -30), (51, -17), (55, 0), (52, 17), (54, 31),
    (50, -8), (50, 9), (38, -31), (38, 31),
    (-44, 38), (-30, 39), (-12, 39), (12, 39), (30, 39), (44, 38),
  ];

  /// Four open flank yards. They are reachable map space, not neutral camps.
  static const sideApproachAnchors = <(double, double)>[
    (-41, -24), (41, -24), (-41, 24), (41, 24),
  ];

  static const _river = <(double, double, double)>[
    (-59.0, -17.0, 1.75), (-48.0, -13.0, 2.05),
    (-36.0, -8.0, 2.35), (-24.0, -1.0, 2.65),
    (-12.0, 7.0, 2.95), (0.0, 15.0, 3.15),
    (12.0, 17.0, 3.10), (24.0, 12.5, 2.85),
    (36.0, 4.5, 2.55), (48.0, -6.5, 2.15),
    (59.0, -14.0, 1.75),
  ];

  static const _lanes = <List<(double, double)>>[
    [
      (-22.5, -40), (-22.9, -30), (-22.2, -20), (-22.7, -10),
      (-22.1, 0), (-22.6, 10), (-22.2, 20), (-22.5, 30), (-22.5, 40),
    ],
    [
      (0.0, -40), (0.5, -30), (-0.4, -20), (0.3, -10),
      (-0.3, 0), (0.4, 10), (-0.4, 20), (0.3, 30), (0.0, 40),
    ],
    [
      (22.5, -40), (22.9, -30), (22.2, -20), (22.7, -10),
      (22.1, 0), (22.6, 10), (22.2, 20), (22.5, 30), (22.5, 40),
    ],
  ];

  static const _accessPaths = <List<(double, double)>>[
    [
      (-22.5, -33), (-31, -34), (-40, -31), (-47, -25),
      (-48, -19), (-43, -15), (-34, -15), (-22.5, -18),
    ],
    [
      (22.5, -33), (31, -34), (40, -31), (47, -25),
      (48, -19), (43, -15), (34, -15), (22.5, -18),
    ],
    [
      (-22.5, 33), (-31, 34), (-40, 31), (-47, 25),
      (-48, 19), (-43, 15), (-34, 15), (-22.5, 18),
    ],
    [
      (22.5, 33), (31, 34), (40, 31), (47, 25),
      (48, 19), (43, 15), (34, 15), (22.5, 18),
    ],
  ];

  static const _bridges = <double>[-22.5, 0.0, 22.5];

  static double _edgeWobble(double angle) =>
      1.0 +
      0.022 * math.sin(angle * 5.0) +
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
    final a = _river[index];
    final b = _river[index + 1];
    final t = ((x - a.$1) / (b.$1 - a.$1)).clamp(0.0, 1.0).toDouble();
    return a.$2 + (b.$2 - a.$2) * t;
  }

  static double _riverHalfWidth(double x) {
    final index = _riverSegment(x);
    final a = _river[index];
    final b = _river[index + 1];
    final t = ((x - a.$1) / (b.$1 - a.$1)).clamp(0.0, 1.0).toDouble();
    return a.$3 + (b.$3 - a.$3) * t;
  }

  static double _pointSegmentDistance(
    double px,
    double pz,
    (double, double) a,
    (double, double) b,
  ) {
    final dx = b.$1 - a.$1;
    final dz = b.$2 - a.$2;
    final lengthSquared = dx * dx + dz * dz;
    if (lengthSquared <= 1e-9) {
      return math.sqrt(math.pow(px - a.$1, 2) + math.pow(pz - a.$2, 2));
    }
    final t = (((px - a.$1) * dx + (pz - a.$2) * dz) / lengthSquared)
        .clamp(0.0, 1.0)
        .toDouble();
    return math.sqrt(
      math.pow(px - (a.$1 + dx * t), 2) +
          math.pow(pz - (a.$2 + dz * t), 2),
    );
  }

  static double laneDistance(double x, double z) {
    var nearest = double.infinity;
    for (final lane in _lanes) {
      for (var i = 0; i < lane.length - 1; i++) {
        nearest = math.min(
          nearest,
          _pointSegmentDistance(x, z, lane[i], lane[i + 1]),
        );
      }
    }
    return nearest;
  }

  static double flankPathDistance(double x, double z) {
    var nearest = double.infinity;
    for (final path in _accessPaths) {
      for (var i = 0; i < path.length - 1; i++) {
        nearest = math.min(
          nearest,
          _pointSegmentDistance(x, z, path[i], path[i + 1]),
        );
      }
    }
    return nearest;
  }

  static bool _insideBuildingWall(double x, double z) {
    const buildings = <(double, double)>[
      (-39, -20), (39, -20), (-39, 20), (39, 20),
    ];
    for (final building in buildings) {
      final dx = (x - building.$1).abs();
      final dz = (z - building.$2).abs();
      // Rear wall and side walls. The south facade has a 3.2-unit doorway.
      if (dx <= 6.0 && (dz - 4.3).abs() <= 0.42) {
        final southDoor = z < building.$2 && dx <= 1.6;
        if (!southDoor) return true;
      }
      if (dz <= 4.5 && (dx - 5.8).abs() <= 0.42) return true;
      // Service counter and side shelving inside each room.
      if (dx <= 1.95 && (z - (building.$2 + 1.35)).abs() <= 0.52) {
        return true;
      }
      if ((dx - 4.35).abs() <= 0.48 &&
          (z - (building.$2 + 2.1)).abs() <= 1.35) {
        return true;
      }
    }
    return false;
  }

  static bool _insideTowerFootprint(double x, double z) {
    const lanes = <double>[-22.5, 0.0, 22.5];
    const towerRows = <double>[-26.0, -18.0, -10.0, 10.0, 18.0, 26.0];
    const radiusSquared = 2.2 * 2.2;
    for (final laneX in lanes) {
      for (final rowZ in towerRows) {
        final dx = x - laneX;
        final dz = z - rowZ;
        if (dx * dx + dz * dz < radiusSquared) return true;
      }
    }
    return false;
  }

  static bool _isOnBridge(double x, double z) {
    final riverZ = _riverCenterZ(x);
    final channelHalfWidth = _riverHalfWidth(x) + riverBankMargin;
    return _bridges.any(
      (bridgeX) =>
          (x - bridgeX).abs() <= 3.4 &&
          (z - riverZ).abs() <= channelHalfWidth + 1.75,
    );
  }

  /// Walkability is explicit: all open ground is enterable, the river blocks
  /// movement except at the three bridge decks, and tree trunks have colliders.
  static bool isWalkable(double x, double z, {bool includeTreeCollision = true}) {
    if (!contains(x, z)) return false;

    final riverDistance = (z - _riverCenterZ(x)).abs();
    final channelWidth = _riverHalfWidth(x) + riverBankMargin;
    if (riverDistance < channelWidth && !_isOnBridge(x, z)) {
      return false;
    }

    if (_insideTowerFootprint(x, z) || _insideBuildingWall(x, z)) {
      return false;
    }

    if (includeTreeCollision) {
      final radiusSquared = treeCollisionRadius * treeCollisionRadius;
      for (final tree in _treeBlockers) {
        final dx = x - tree.$1;
        final dz = z - tree.$2;
        if (dx * dx + dz * dz < radiusSquared) return false;
      }
    }
    return true;
  }

  /// Matches the baked bridge-deck height so units stand on the crossing,
  /// not at the lower river-bed elevation beneath it.
  static double navigationHeightAt(double x, double z) {
    if (!_isOnBridge(x, z)) return heightAt(x, z);
    final riverZ = _riverCenterZ(x);
    final bankOffset = _riverHalfWidth(x) + 1.25;
    final nearBank = heightAt(x, riverZ - bankOffset);
    final farBank = heightAt(x, riverZ + bankOffset);
    return math.max(heightAt(x, z), math.max(nearBank, farBank) + 0.28);
  }

  static double heightAt(double x, double z) {
    final westRidge = 2.65 *
        math.exp(-math.pow(x + 38, 2) / 92) *
        (0.64 + 0.36 * math.cos(z * 0.052));
    final eastRidge = 2.45 *
        math.exp(-math.pow(x - 38, 2) / 98) *
        (0.64 + 0.36 * math.cos(z * 0.049));
    final southHighland = 1.35 *
        math.exp(-math.pow(z + 36, 2) / 68) *
        math.exp(-math.pow(x, 2) / 860);
    final northHighland = 1.45 *
        math.exp(-math.pow(z - 36, 2) / 72) *
        math.exp(-math.pow(x, 2) / 900);
    final flankMounds = 0.58 *
        math.exp(-math.pow(x.abs() - 31.5, 2) / 20) *
        math.exp(-math.pow(z.abs() - 21, 2) / 90);
    final riverDistance = (z - _riverCenterZ(x)).abs();
    final riverWidth = _riverHalfWidth(x);
    final riverBed = -0.92 *
        math.exp(-math.pow(riverDistance, 2) / (riverWidth * riverWidth * 0.92));
    final bankDistance = riverDistance - (riverWidth + 0.82);
    final riverBank = 0.54 * math.exp(-math.pow(bankDistance, 2) / 3.2);
    final rolling = 0.34 * math.sin(x * 0.12) * math.cos(z * 0.105) +
        0.22 * math.sin((x + z) * 0.18) +
        0.12 * math.cos((x - z) * 0.24);
    final terrace = 0.34 *
        math.exp(-math.pow(x.abs() - 23, 2) / 18) *
        math.exp(-math.pow(z.abs() - 11, 2) / 220);

    return westRidge +
        eastRidge +
        southHighland +
        northHighland +
        flankMounds +
        riverBed +
        riverBank +
        rolling +
        terrace;
  }

  static List<ArenaWorldPlacement> _makeTrees() {
    const variants = <String>['tree_oak', 'tree_pine', 'tree_broadleaf'];
    return List<ArenaWorldPlacement>.unmodifiable(
      _treeBlockers.indexed.map((entry) {
        final index = entry.$1;
        final point = entry.$2;
        final variant = variants[(index * 2 + index ~/ 5) % variants.length];
        return ArenaWorldPlacement(
          asset: 'assets/world/nature/$variant.glb',
          x: point.$1 * worldScale,
          z: point.$2 * worldScale,
          y: heightAt(point.$1, point.$2),
          scale: 1.02 + (index % 4) * 0.08,
          yaw: (index * 2.399) % (2 * math.pi),
        );
      }),
    );
  }

  static List<ArenaWorldPlacement> _makeBushes() {
    const points = <(double, double)>[
      (-49, -30), (-48, -8), (-49, 14), (-45, 31),
      (49, -30), (48, -8), (49, 14), (45, 31),
      (-36, -36), (36, -36), (-36, 36), (36, 36),
    ];
    return List<ArenaWorldPlacement>.unmodifiable(
      points.indexed.map((entry) {
        final index = entry.$1;
        final point = entry.$2;
        final x = point.$1 + (index.isEven ? -0.8 : 0.8);
        final z = point.$2 + (index % 3 == 0 ? 0.8 : -0.6);
        return ArenaWorldPlacement(
          asset: 'assets/world/nature/bush_common.glb',
          x: x * worldScale,
          z: z * worldScale,
          y: heightAt(x, z),
          scale: 0.72 + (index % 3) * 0.08,
          yaw: (index * 1.71) % (2 * math.pi),
        );
      }),
    );
  }

  static final trees = _makeTrees();
  static final bushes = _makeBushes();
}
