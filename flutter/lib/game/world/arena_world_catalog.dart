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

/// Deterministic coordinates shared by the map preview and later match scene.
abstract final class ArenaWorldCatalog {
  static const double worldScale = 1.15;

  static const _treeBlockers = <(double, double)>[
    (-10.5, -23), (-6.2, -22), (-11.5, -17.5), (-5.5, -17),
    (-10.2, -10), (-6.4, -8), (10.5, -23), (6.2, -22),
    (11.5, -17.5), (5.5, -17), (10.2, -10), (6.4, -8),
    (-22.8, -18), (-26, -13), (-22.4, -6), (-18.5, -20),
    (22.8, -18), (26, -13), (22.4, -6), (18.5, -20),
    (-10.5, 23), (-6.2, 22), (-11.5, 17.5), (-5.5, 17),
    (-10.2, 10), (-6.4, 8), (10.5, 23), (6.2, 22),
    (11.5, 17.5), (5.5, 17), (10.2, 10), (6.4, 8),
  ];

  static const _groves = <(double, double)>[
    (-25, -19), (-27, -8), (-23, 8), (-26, 19),
    (25, -19), (27, -8), (23, 8), (26, 19),
    (-8.5, -21), (8.5, -21), (-8.5, 21), (8.5, 21),
  ];

  static final trees = List<ArenaWorldPlacement>.unmodifiable(
    _treeBlockers.indexed.map((entry) {
      final index = entry.$1;
      final point = entry.$2;
      const variants = <String>[
        'tree_oak',
        'tree_pine',
        'tree_broadleaf',
      ];
      final variant = variants[(index * 2 + index ~/ 5) % variants.length];
      final yaw = (index * 2.399) % (2 * math.pi);
      return ArenaWorldPlacement(
        asset: 'assets/world/nature/$variant.glb',
        x: point.$1 * worldScale,
        z: point.$2 * worldScale,
        y: heightAt(point.$1, point.$2),
        scale: 0.92 + (index % 4) * 0.09,
        yaw: yaw,
      );
    }),
  );

  static final bushes = List<ArenaWorldPlacement>.unmodifiable(
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

  static const _river = <(double, double, double)>[
    (-34, 1.10, 0.78), (-28, 0.55, 1.15),
    (-21, 0.05, 1.48), (-15, -0.45, 1.68),
    (-9, -0.22, 1.92), (-3, 0.25, 1.58),
    (4, 0.38, 1.82), (10, 0.02, 1.95),
    (16, -0.38, 1.62), (23, -0.18, 1.62),
    (29, 0.22, 1.15), (34, 0.80, 0.78),
  ];

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
}
