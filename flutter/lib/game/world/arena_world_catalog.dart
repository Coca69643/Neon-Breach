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

/// Shared terrain, route and vegetation data for the offline MOBA battlefield.
abstract final class ArenaWorldCatalog {
  static const double worldScale = 1.15;
  static const double halfWidth = 35.0;
  static const double halfDepth = 31.0;
  static const double footprintExponent = 4.2;

  static const _treeBlockers = <(double, double)>[
    (-25, -24), (-22, -18), (-25, -9), (-22, 2),
    (-25, 13), (-22, 23), (-9, -23), (-7, -15),
    (-9, -6), (-7, 5), (-9, 16), (-7, 24),
    (25, -24), (22, -18), (25, -9), (22, 2),
    (25, 13), (22, 23), (9, -23), (7, -15),
    (9, -6), (7, 5), (9, 16), (7, 24),
    (-28, -23), (-27, 20), (-9, -26), (9, -26),
    (28, -23), (27, 20), (-9, 26), (9, 26),
  ];

  static const _groves = <(double, double)>[
    (-24, -18), (-24, 7), (-9, -14), (-9, 13),
    (9, -14), (9, 13), (24, -18), (24, 7),
    (-25, 22), (25, 22), (-9, -25), (9, -25),
  ];

  static const _river = <(double, double, double)>[
    (-34.0, -16.0, 0.90), (-28.0, -13.5, 1.20),
    (-22.0, -9.5, 1.45), (-16.0, -5.0, 1.62),
    (-10.0, 1.5, 1.74), (-4.0, 8.0, 1.88),
    (3.0, 13.0, 1.92), (10.0, 14.0, 1.78),
    (17.0, 9.0, 1.62), (24.0, 2.0, 1.42),
    (30.0, -5.0, 1.15), (34.0, -9.5, 0.92),
  ];

  static const _lanes = <List<(double, double)>>[
    [
      (-15.0, -30), (-15.5, -22), (-14.8, -14), (-15.2, -6),
      (-14.7, 2), (-15.1, 10), (-14.8, 18), (-15.0, 30),
    ],
    [
      (0.0, -30), (0.6, -22), (-0.5, -14), (0.2, -6),
      (-0.2, 2), (0.4, 10), (-0.4, 18), (0.0, 30),
    ],
    [
      (15.0, -30), (15.5, -22), (14.8, -14), (15.2, -6),
      (14.7, 2), (15.1, 10), (14.8, 18), (15.0, 30),
    ],
  ];

  static bool contains(double x, double z) {
    if (x.abs() > halfWidth * 1.03 || z.abs() > halfDepth * 1.03) {
      return false;
    }
    final angle = math.atan2(z / halfDepth, x / halfWidth);
    final edge = 1.0 +
        0.022 * math.sin(angle * 5.0) +
        0.014 * math.sin(angle * 9.0 + 1.4) +
        0.010 * math.cos(angle * 13.0) +
        0.006 * math.sin(angle * 17.0 + 0.8);
    final extent = math.pow(x.abs() / halfWidth, footprintExponent) +
        math.pow(z.abs() / halfDepth, footprintExponent);
    return extent <= math.pow(edge, footprintExponent);
  }

  static double _riverCenterZ(double x) {
    var index = 0;
    while (index < _river.length - 2 && x > _river[index + 1].$1) {
      index++;
    }
    final a = _river[index];
    final b = _river[index + 1];
    final t = ((x - a.$1) / (b.$1 - a.$1)).clamp(0.0, 1.0).toDouble();
    return a.$2 + (b.$2 - a.$2) * t;
  }

  static double _riverHalfWidth(double x) {
    var index = 0;
    while (index < _river.length - 2 && x > _river[index + 1].$1) {
      index++;
    }
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

  static double heightAt(double x, double z) {
    final westRidge = 2.35 *
        math.exp(-math.pow(x + 24, 2) / 44) *
        (0.58 + 0.42 * math.cos(z * 0.075));
    final eastRidge = 2.18 *
        math.exp(-math.pow(x - 24, 2) / 48) *
        (0.58 + 0.42 * math.cos(z * 0.07));
    final southHighland = 1.55 *
        math.exp(-math.pow(z + 27, 2) / 36) *
        math.exp(-math.pow(x, 2) / 420);
    final northHighland = 1.55 *
        math.exp(-math.pow(z - 27, 2) / 36) *
        math.exp(-math.pow(x, 2) / 420);
    final jungleKnolls = 0.78 *
        math.exp(-math.pow(x.abs() - 8.5, 2) / 8.5) *
        math.exp(-math.pow(z.abs() - 14, 2) / 42);
    final riverDistance = (z - _riverCenterZ(x)).abs();
    final riverWidth = _riverHalfWidth(x);
    final riverBed = -0.76 *
        math.exp(-math.pow(riverDistance, 2) /
            (riverWidth * riverWidth * 0.82));
    final bankDistance = riverDistance - (riverWidth + 0.66);
    final riverBank = 0.48 * math.exp(-math.pow(bankDistance, 2) / 2.4);
    final rolling = 0.26 * math.sin(x * 0.18) * math.cos(z * 0.14) +
        0.16 * math.sin((x + z) * 0.29);
    final shelf = 0.52 *
        math.exp(-math.pow(x.abs() - 18.5, 2) / 5.5) *
        math.exp(-math.pow(z.abs() - 13, 2) / 110);

    return westRidge +
        eastRidge +
        southHighland +
        northHighland +
        jungleKnolls +
        riverBed +
        riverBank +
        rolling +
        shelf;
  }

  static List<ArenaWorldPlacement> _makeTrees() {
    const variants = <String>[
      'tree_oak',
      'tree_pine',
      'tree_broadleaf',
    ];
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
          scale: 0.92 + (index % 4) * 0.09,
          yaw: (index * 2.399) % (2 * math.pi),
        );
      }),
    );
  }

  static List<ArenaWorldPlacement> _makeBushes() {
    return List<ArenaWorldPlacement>.unmodifiable(
      _groves.indexed.map((entry) {
        final index = entry.$1;
        final point = entry.$2;
        final side = index.isEven ? -1.0 : 1.0;
        final x = point.$1 + side * 1.15;
        final z = point.$2 + (index % 3 == 0 ? 0.9 : -0.75);
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
