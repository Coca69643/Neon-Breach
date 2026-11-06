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

class ArenaDistrict {
  const ArenaDistrict({
    required this.id,
    required this.label,
    required this.role,
    required this.x,
    required this.z,
  });

  final String id;
  final String label;
  final String role;
  final double x;
  final double z;
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

/// Logical 180 × 140 battlefield. Rendering applies a single 1.35× scene
/// transform; simulation and Rapier keep these coordinates as their source
/// of truth so camera, navigation and collision never drift apart.
abstract final class ArenaWorldCatalog {
  static const double worldScale = 1.35;
  static const double halfWidth = 90.0;
  static const double halfDepth = 70.0;
  static const double cornerRadius = 10.0;
  static const double roomHalfWidth = 10.0;
  static const double roomHalfDepth = 8.0;
  static const double roomDoorHalfWidth = 2.4;
  static const double roomWallHalfThickness = 0.42;
  static const double roomWallHalfHeight = 1.5;
  static const double riverBankMargin = 0.55;
  static const double treeCollisionRadius = 1.35;

  static const cityInteriors = <(String, double, double)>[
    ('west_south', -63.0, -38.0),
    ('east_south', 63.0, -38.0),
    ('west_north', -63.0, 38.0),
    ('east_north', 63.0, 38.0),
  ];

  /// District anchors share their coordinates with the four enterable
  /// service buildings. Each terminal is a future capture/interact point;
  /// geometry, collision and simulation can reference the same catalog.
  static const districts = <ArenaDistrict>[
    ArenaDistrict(
      id: 'west_south',
      label: 'Mercado Oeste',
      role: 'COMÉRCIO',
      x: -63.0,
      z: -38.0,
    ),
    ArenaDistrict(
      id: 'east_south',
      label: 'Pátio Industrial',
      role: 'INDÚSTRIA',
      x: 63.0,
      z: -38.0,
    ),
    ArenaDistrict(
      id: 'west_north',
      label: 'Parque Cívico',
      role: 'SERVIÇOS',
      x: -63.0,
      z: 38.0,
    ),
    ArenaDistrict(
      id: 'east_north',
      label: 'Terminal Norte',
      role: 'TRANSPORTE',
      x: 63.0,
      z: 38.0,
    ),
  ];

  /// Two opposing mezzanine routes create a real height layer without
  /// introducing a second navigation grid or increasing entity budgets.
  static const verticalAccesses = <ArenaVerticalAccess>[
    ArenaVerticalAccess(id: 'west_south', x: -63.0, z: -38.0),
    ArenaVerticalAccess(id: 'east_north', x: 63.0, z: 38.0),
  ];

  // Exterior shells are aligned with their matching interior collision rooms.
  // A visible building and its playable interior must occupy the same footprint.
  static const commercialBlocks = <(String, double, double, double)>[
    ('commercial_building_b.glb', -63.0, -38.0, 6.5),
    ('commercial_building_c.glb', 63.0, -38.0, 6.5),
    ('commercial_building_f.glb', -63.0, 38.0, 6.5),
    ('commercial_building_h.glb', 63.0, 38.0, 6.5),
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

  static const treeBlockerPoints = <(double, double)>[
    (-82, -16), (-82, 16), (82, -16), (82, 16),
    (-72, -58), (72, -58), (-72, 58), (72, 58),
  ];

  static const largeTreePoints = <(double, double)>[
    (-84, -38), (84, -38), (-84, 38), (84, 38),
  ];

  /// A flat-sided rounded rectangle replaces the old superellipse/egg
  /// silhouette. The same function is mirrored in the offline terrain baker.
  static bool contains(double x, double z) {
    if (x.abs() > halfWidth || z.abs() > halfDepth) return false;
    final cornerX = math.max(0.0, x.abs() - (halfWidth - cornerRadius));
    final cornerZ = math.max(0.0, z.abs() - (halfDepth - cornerRadius));
    return cornerX * cornerX + cornerZ * cornerZ <=
        cornerRadius * cornerRadius + 1e-6;
  }

  static bool isCanalAt(double x, double z) =>
      (z - _riverCenterZ(x)).abs() <
      _riverHalfWidth(x) + riverBankMargin;

  static bool isBridgeAt(double x, double z) => _isOnBridge(x, z);

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
      // 20 × 16 m playable room with a 4.8 m south-facing entrance.
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
      // Counter and shelving are physical interior obstacles.
      final hasVerticalAccess = verticalAccesses.any(
        (access) => access.id == building.$1,
      );
      final counterZ = hasVerticalAccess ? cz - 2.0 : cz + 2.2;
      final counterDistanceX = hasVerticalAccess
          ? (x - (cx - 5.2)).abs()
          : dx;
      if (counterDistanceX <= (hasVerticalAccess ? 1.5 : 2.6) &&
          (z - counterZ).abs() <= 0.7) {
        return true;
      }
      if (!hasVerticalAccess &&
          (dx - 7.0).abs() <= 0.55 &&
          (z - (cz + 3.2)).abs() <= 1.8) {
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
        _insideBuildingWall(x, z)) {
      return false;
    }
    for (final block in commercialBlocks) {
      final dx = (x - block.$2).abs();
      final dz = (z - block.$3).abs();
      final hasPlayableInterior = cityInteriors.any(
        (building) =>
            building.$2 == block.$2 &&
            building.$3 == block.$3 &&
            dx <= roomHalfWidth &&
            dz <= roomHalfDepth,
      );
      if (dx < 6.8 && dz < 6.8 && !hasPlayableInterior) return false;
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
      treeBlockerPoints.indexed.map((entry) {
        final index = entry.$1, point = entry.$2;
        return ArenaWorldPlacement(
          asset: 'assets/world/nature/${variants[index % variants.length]}.glb',
          x: point.$1,
          z: point.$2,
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
          scale: 4.7 + (index % 2) * 0.35,
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
        y: heightAt(x, z) + y,
        scale: scale,
        yaw: yaw,
      ));
    }

    // Canal promenade: warm lamps are spaced away from minion lanes.
    for (final point in const [
      (-50.0, -52.0), (-22.0, -52.0), (22.0, -52.0), (50.0, -52.0),
      (-50.0, 52.0), (-22.0, 52.0), (22.0, 52.0), (50.0, 52.0),
    ]) {
      add('street_light_square.glb', point.$1, point.$2, scale: 5.7);
    }

    // Signalized bridge approaches make the crossings legible from the lane.
    for (final point in const [
      (-44.0, -5.0), (-28.0, 5.0),
      (-8.0, -5.0), (8.0, 5.0),
      (28.0, -5.0), (44.0, 5.0),
    ]) {
      add('traffic_light.glb', point.$1, point.$2, scale: 5.8);
    }

    // Street signs sit on the outer sidewalks, not in the travel corridor.
    for (final point in const [
      (-71.0, -16.0), (71.0, -16.0),
      (-71.0, 16.0), (71.0, 16.0),
    ]) {
      add('road_sign_street.glb', point.$1, point.$2, scale: 4.6);
    }

    // A warning marker identifies the service alley without blocking it.
    add('road_sign_warning.glb', -55.0, -26.0, scale: 4.5, yaw: math.pi / 2);
    add('road_sign_warning.glb', 55.0, 26.0, scale: 4.5, yaw: -math.pi / 2);

    // Crosswalk strips emphasize each bridge threshold.
    for (final laneX in const [-36.0, 0.0, 36.0]) {
      for (final side in const [-1.0, 1.0]) {
        add('road_crossing.glb', laneX, side * 4.0,
            scale: 1, y: 0.035);
      }
    }

    // Every service entrance receives its own canopy and a small street-level prop.
    for (final building in cityInteriors) {
      final x = building.$2;
      final z = building.$3;
      add('detail_awning_wide.glb', x, z - 8.55,
          scale: 7.8, yaw: math.pi, y: 1.25);
      add('interior_trashcan.glb', x + (x < 0 ? 5.0 : -5.0), z - 3.1,
          scale: 2.1);
    }

    // Side plazas use parasols and planters as visual anchors.
    for (final point in const [
      (-54.0, -14.0), (54.0, -14.0),
      (-54.0, 14.0), (54.0, 14.0),
    ]) {
      add('detail_parasol_a.glb', point.$1, point.$2, scale: 6.1);
      add('city_planter.glb', point.$1 + (point.$1 < 0 ? 2.6 : -2.6),
          point.$2 + 1.6, scale: 5.0);
    }

    // Planted edges soften the hard canal geometry without filling the lanes.
    for (final point in const [
      (-15.0, -5.4), (15.0, -5.4), (-15.0, 5.4), (15.0, 5.4),
    ]) {
      add('interior_plant.glb', point.$1, point.$2, scale: 4.6);
    }

    return List<ArenaWorldPlacement>.unmodifiable(props);
  }

  static final trees = _makeTrees();
  static final largeTrees = _makeLargeTrees();
  static final bushes = _makeBushes();
  static final cityProps = _makeCityProps();
}
