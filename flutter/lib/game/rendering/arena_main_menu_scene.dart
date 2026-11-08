import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Lightweight 2D main-menu backdrop.
///
/// The menu must not instantiate the 3D battle world or load GLB scene models.
/// Gameplay remains fully 3D; this painter only draws a static illustrated
/// command-tower skyline and is isolated behind a RepaintBoundary.
class ArenaMainMenuScene extends StatelessWidget {
  const ArenaMainMenuScene({super.key});

  @override
  Widget build(BuildContext context) {
    return const RepaintBoundary(
      child: CustomPaint(
        painter: _ArenaMenuBackdropPainter(),
        size: Size.infinite,
      ),
    );
  }
}

class _ArenaMenuBackdropPainter extends CustomPainter {
  const _ArenaMenuBackdropPainter();

  static const double _designWidth = 1600;
  static const double _designHeight = 900;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final scale = math.max(
      size.width / _designWidth,
      size.height / _designHeight,
    ).toDouble();
    final offsetX = (size.width - _designWidth * scale) / 2;
    final offsetY = (size.height - _designHeight * scale) / 2;

    canvas.save();
    canvas.translate(offsetX, offsetY);
    canvas.scale(scale);

    _drawSky(canvas);
    _drawAtmosphere(canvas);
    _drawDistantSkyline(canvas);
    _drawMarketDistrict(canvas);
    _drawCommandTower(canvas);
    _drawForeground(canvas);
    _drawVignette(canvas);

    canvas.restore();
  }

  void _drawSky(Canvas canvas) {
    const bounds = Rect.fromLTWH(0, 0, _designWidth, _designHeight);
    final paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF162B40),
          Color(0xFF34566A),
          Color(0xFF9A9A8D),
          Color(0xFF354653),
        ],
        stops: [0.0, 0.43, 0.73, 1.0],
      ).createShader(bounds);
    canvas.drawRect(bounds, paint);
  }

  void _drawAtmosphere(Canvas canvas) {
    final horizonGlow = Paint()
      ..shader = const RadialGradient(
        colors: [
          Color(0x6698C7C6),
          Color(0x1F8AB7BD),
          Color(0x008AB7BD),
        ],
        stops: [0.0, 0.52, 1.0],
      ).createShader(Rect.fromCircle(
        center: Offset(1040, 440),
        radius: 520,
      ));
    canvas.drawCircle(const Offset(1040, 440), 520, horizonGlow);

    final sun = Paint()..color = const Color(0x33E9D6AC);
    canvas.drawCircle(const Offset(1235, 245), 92, sun);
    canvas.drawCircle(
      const Offset(1235, 245),
      68,
      Paint()..color = const Color(0x18F3E7C7),
    );

    final cloudPaint = Paint()
      ..color = const Color(0x18D6E2DF)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final clouds = Path()
      ..moveTo(170, 260)
      ..cubicTo(250, 230, 320, 240, 385, 258)
      ..moveTo(250, 282)
      ..cubicTo(340, 260, 420, 270, 475, 286)
      ..moveTo(680, 185)
      ..cubicTo(750, 166, 812, 172, 870, 190)
      ..moveTo(735, 207)
      ..cubicTo(815, 190, 880, 196, 930, 211);
    canvas.drawPath(clouds, cloudPaint);

    final starPaint = Paint()..color = const Color(0x66D6E5E7);
    const stars = <Offset>[
      Offset(115, 115),
      Offset(245, 86),
      Offset(438, 142),
      Offset(600, 92),
      Offset(760, 112),
      Offset(910, 76),
      Offset(1370, 102),
      Offset(1485, 180),
      Offset(131, 370),
      Offset(525, 330),
    ];
    for (final star in stars) {
      canvas.drawCircle(star, 1.7, starPaint);
    }
  }

  void _drawDistantSkyline(Canvas canvas) {
    final farBuildings = Paint()..color = const Color(0x55314451);
    final midBuildings = Paint()..color = const Color(0xA0233542);
    final nearBuildings = Paint()..color = const Color(0xCC172A37);

    final far = Path()
      ..moveTo(0, 670)
      ..lineTo(0, 565)
      ..lineTo(68, 565)
      ..lineTo(68, 520)
      ..lineTo(116, 520)
      ..lineTo(116, 585)
      ..lineTo(174, 585)
      ..lineTo(174, 490)
      ..lineTo(240, 490)
      ..lineTo(240, 555)
      ..lineTo(295, 555)
      ..lineTo(295, 525)
      ..lineTo(350, 525)
      ..lineTo(350, 600)
      ..lineTo(420, 600)
      ..lineTo(420, 535)
      ..lineTo(478, 535)
      ..lineTo(478, 580)
      ..lineTo(545, 580)
      ..lineTo(545, 505)
      ..lineTo(605, 505)
      ..lineTo(605, 585)
      ..lineTo(680, 585)
      ..lineTo(680, 545)
      ..lineTo(738, 545)
      ..lineTo(738, 605)
      ..lineTo(810, 605)
      ..lineTo(810, 540)
      ..lineTo(870, 540)
      ..lineTo(870, 610)
      ..lineTo(940, 610)
      ..lineTo(940, 570)
      ..lineTo(1000, 570)
      ..lineTo(1000, 650)
      ..lineTo(1600, 650)
      ..lineTo(1600, 900)
      ..lineTo(0, 900)
      ..close();
    canvas.drawPath(far, farBuildings);

    final mid = Path()
      ..moveTo(0, 730)
      ..lineTo(0, 635)
      ..lineTo(92, 635)
      ..lineTo(92, 590)
      ..lineTo(168, 590)
      ..lineTo(168, 710)
      ..lineTo(228, 710)
      ..lineTo(228, 620)
      ..lineTo(310, 620)
      ..lineTo(310, 700)
      ..lineTo(385, 700)
      ..lineTo(385, 640)
      ..lineTo(478, 640)
      ..lineTo(478, 725)
      ..lineTo(570, 725)
      ..lineTo(570, 625)
      ..lineTo(656, 625)
      ..lineTo(656, 712)
      ..lineTo(760, 712)
      ..lineTo(760, 650)
      ..lineTo(855, 650)
      ..lineTo(855, 730)
      ..lineTo(950, 730)
      ..lineTo(950, 650)
      ..lineTo(1030, 650)
      ..lineTo(1030, 730)
      ..lineTo(1600, 730)
      ..lineTo(1600, 900)
      ..lineTo(0, 900)
      ..close();
    canvas.drawPath(mid, midBuildings);

    final near = Path()
      ..moveTo(0, 785)
      ..lineTo(0, 710)
      ..lineTo(80, 710)
      ..lineTo(80, 680)
      ..lineTo(150, 680)
      ..lineTo(150, 760)
      ..lineTo(240, 760)
      ..lineTo(240, 700)
      ..lineTo(328, 700)
      ..lineTo(328, 775)
      ..lineTo(405, 775)
      ..lineTo(405, 720)
      ..lineTo(495, 720)
      ..lineTo(495, 785)
      ..lineTo(590, 785)
      ..lineTo(590, 735)
      ..lineTo(675, 735)
      ..lineTo(675, 790)
      ..lineTo(775, 790)
      ..lineTo(775, 730)
      ..lineTo(860, 730)
      ..lineTo(860, 790)
      ..lineTo(940, 790)
      ..lineTo(940, 740)
      ..lineTo(1020, 740)
      ..lineTo(1020, 805)
      ..lineTo(1600, 805)
      ..lineTo(1600, 900)
      ..lineTo(0, 900)
      ..close();
    canvas.drawPath(near, nearBuildings);

    final windowPaint = Paint()..color = const Color(0x6687B7BB);
    const windowColumns = <double>[28, 53, 104, 130, 260, 284, 440, 462, 615, 640, 800, 825, 900, 924];
    for (var i = 0; i < windowColumns.length; i++) {
      final x = windowColumns[i];
      final top = i.isEven ? 625.0 : 650.0;
      for (var row = 0; row < 3; row++) {
        canvas.drawRect(
          Rect.fromLTWH(x, top + row * 24, 8, 10),
          windowPaint,
        );
      }
    }
  }

  void _drawMarketDistrict(Canvas canvas) {
    // Low-rise storefronts, awnings and warm windows create a lived-in
    // district beneath the command tower without requiring scene assets.
    final shopShadow = Paint()..color = const Color(0xAA101E28);
    final shopFace = Paint()..color = const Color(0xFF243B47);
    final shopTop = Paint()..color = const Color(0xFF52656A);
    final shopGlass = Paint()..color = const Color(0xFF172E3B);
    final warmWindow = Paint()..color = const Color(0xFFD7B879);
    final coolWindow = Paint()..color = const Color(0xFF6FB7B7);
    final awning = Paint()..color = const Color(0xFF9B8060);

    final marketMass = Path()
      ..moveTo(78, 782)
      ..lineTo(78, 686)
      ..lineTo(126, 654)
      ..lineTo(286, 654)
      ..lineTo(324, 684)
      ..lineTo(324, 782)
      ..close();
    canvas.drawPath(marketMass.shift(const Offset(8, 10)), shopShadow);
    canvas.drawPath(marketMass, shopFace);
    canvas.drawPath(
      Path()
        ..moveTo(78, 686)
        ..lineTo(126, 654)
        ..lineTo(286, 654)
        ..lineTo(324, 684)
        ..lineTo(324, 698)
        ..lineTo(78, 700)
        ..close(),
      shopTop,
    );

    final marketGlass = Path()
      ..moveTo(100, 707)
      ..lineTo(304, 705)
      ..lineTo(304, 766)
      ..lineTo(100, 770)
      ..close();
    canvas.drawPath(marketGlass, shopGlass);
    for (var i = 0; i < 4; i++) {
      final x = 116.0 + i * 47;
      canvas.drawRect(
        Rect.fromLTWH(x, 716, 28, 39),
        Paint()..color = const Color(0xFF294955),
      );
      canvas.drawRect(
        Rect.fromLTWH(x + 5, 720, 7, 13),
        i.isEven ? warmWindow : coolWindow,
      );
      canvas.drawRect(
        Rect.fromLTWH(x + 16, 720, 7, 13),
        i.isEven ? coolWindow : warmWindow,
      );
    }

    final awningPath = Path()
      ..moveTo(92, 700)
      ..lineTo(310, 697)
      ..lineTo(326, 715)
      ..lineTo(90, 719)
      ..close();
    canvas.drawPath(awningPath, awning);
    for (var i = 0; i < 7; i++) {
      final x = 98.0 + i * 32;
      canvas.drawLine(
        Offset(x, 701),
        Offset(x + 1, 717),
        Paint()
          ..color = const Color(0xAAE5C994)
          ..strokeWidth = 2,
      );
    }

    final sideStore = Path()
      ..moveTo(365, 788)
      ..lineTo(365, 704)
      ..lineTo(405, 674)
      ..lineTo(555, 674)
      ..lineTo(590, 705)
      ..lineTo(590, 788)
      ..close();
    canvas.drawPath(sideStore.shift(const Offset(7, 9)), shopShadow);
    canvas.drawPath(sideStore, Paint()..color = const Color(0xFF1E3542));
    canvas.drawPath(
      Path()
        ..moveTo(365, 704)
        ..lineTo(405, 674)
        ..lineTo(555, 674)
        ..lineTo(590, 705)
        ..close(),
      shopTop,
    );
    canvas.drawRect(
      const Rect.fromLTWH(388, 719, 180, 53),
      shopGlass,
    );
    for (var i = 0; i < 5; i++) {
      canvas.drawRect(
        Rect.fromLTWH(398 + i * 34, 726, 20, 30),
        Paint()..color = const Color(0xFF2B4A55),
      );
      canvas.drawRect(
        Rect.fromLTWH(404 + i * 34, 730, 8, 12),
        i.isEven ? coolWindow : warmWindow,
      );
    }
    canvas.drawLine(
      const Offset(372, 711),
      const Offset(580, 708),
      Paint()
        ..color = const Color(0xFFD0B07A)
        ..strokeWidth = 8,
    );

    // Street lamps and ground-level route markers anchor the street.
    for (final x in <double>[56, 620, 862]) {
      canvas.drawLine(
        Offset(x, 790),
        Offset(x, 713),
        Paint()
          ..color = const Color(0xFF65777A)
          ..strokeWidth = 4,
      );
      canvas.drawLine(
        Offset(x, 715),
        Offset(x + 17, 711),
        Paint()
          ..color = const Color(0xFF65777A)
          ..strokeWidth = 3,
      );
      canvas.drawCircle(
        Offset(x + 19, 711),
        4,
        Paint()..color = const Color(0xFFFFD68A),
      );
      canvas.drawCircle(
        Offset(x + 19, 711),
        13,
        Paint()..color = const Color(0x22FFD68A),
      );
    }
  }

  void _drawCommandTower(Canvas canvas) {
    final distantShadow = Paint()..color = const Color(0x6630434E);
    final sideFace = Paint()..color = const Color(0xFF243B48);
    final frontFace = Paint()..color = const Color(0xFF48616B);
    final glassFace = Paint()..color = const Color(0xFF294B59);
    final trim = Paint()..color = const Color(0xFFB2A27E);
    final coolLight = Paint()..color = const Color(0xFF71BFC0);
    final warmLight = Paint()..color = const Color(0xFFD7B77B);

    // Tower silhouette and the broad, grounded command complex.
    final silhouette = Path()
      ..moveTo(1020, 760)
      ..lineTo(1050, 345)
      ..lineTo(1084, 300)
      ..lineTo(1084, 218)
      ..lineTo(1110, 218)
      ..lineTo(1110, 170)
      ..lineTo(1135, 170)
      ..lineTo(1135, 218)
      ..lineTo(1172, 218)
      ..lineTo(1198, 282)
      ..lineTo(1250, 760)
      ..close();
    canvas.drawPath(silhouette, distantShadow);

    final towerSide = Path()
      ..moveTo(1168, 300)
      ..lineTo(1220, 324)
      ..lineTo(1260, 720)
      ..lineTo(1220, 756)
      ..lineTo(1175, 746)
      ..close();
    canvas.drawPath(towerSide, sideFace);

    final towerFront = Path()
      ..moveTo(1050, 324)
      ..lineTo(1168, 300)
      ..lineTo(1175, 746)
      ..lineTo(1020, 760)
      ..close();
    canvas.drawPath(towerFront, frontFace);

    final centralGlass = Path()
      ..moveTo(1080, 355)
      ..lineTo(1152, 337)
      ..lineTo(1158, 710)
      ..lineTo(1050, 720)
      ..close();
    canvas.drawPath(centralGlass, glassFace);

    // Vertical glass ribs and warm-lit floor bands.
    final ribPaint = Paint()
      ..color = const Color(0x6656A4AD)
      ..strokeWidth = 5;
    for (var i = 0; i < 4; i++) {
      final x = 1090.0 + i * 19;
      canvas.drawLine(Offset(x, 355 - i * 4), Offset(x + 5, 714), ribPaint);
    }

    final bandPaint = Paint()
      ..color = const Color(0x6689B7B3)
      ..strokeWidth = 3;
    for (var row = 0; row < 8; row++) {
      final y = 388.0 + row * 39;
      canvas.drawLine(
        Offset(1067, y),
        Offset(1160, y - 10),
        bandPaint,
      );
    }

    // Window strips keep the tower legible without hundreds of draw calls.
    for (var row = 0; row < 7; row++) {
      final y = 400.0 + row * 42;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(1074, y, 9, 18),
          const Radius.circular(2),
        ),
        warmLight,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(1092, y - 2, 9, 18),
          const Radius.circular(2),
        ),
        coolLight,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(1110, y - 4, 9, 18),
          const Radius.circular(2),
        ),
        warmLight,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(1128, y - 6, 9, 18),
          const Radius.circular(2),
        ),
        coolLight,
      );
    }

    // Layered upper command decks and the illuminated crown.
    final upperDeck = Path()
      ..moveTo(1038, 332)
      ..lineTo(1080, 270)
      ..lineTo(1188, 270)
      ..lineTo(1225, 332)
      ..lineTo(1180, 345)
      ..lineTo(1080, 358)
      ..close();
    canvas.drawPath(upperDeck, sideFace);

    final crown = Path()
      ..moveTo(1084, 270)
      ..lineTo(1100, 238)
      ..lineTo(1170, 238)
      ..lineTo(1190, 270)
      ..close();
    canvas.drawPath(crown, trim);
    canvas.drawRect(
      const Rect.fromLTWH(1102, 246, 65, 7),
      coolLight,
    );

    canvas.drawLine(
      const Offset(1135, 170),
      const Offset(1135, 115),
      Paint()
        ..color = const Color(0xFFD8D0B7)
        ..strokeWidth = 4,
    );
    canvas.drawCircle(const Offset(1135, 108), 7, warmLight);
    canvas.drawLine(
      const Offset(1120, 192),
      const Offset(1150, 192),
      Paint()
        ..color = const Color(0xFFE2C78D)
        ..strokeWidth = 3,
    );

    // Horizontal terraces and the grounded base.
    final terracePaint = Paint()
      ..color = const Color(0xFF6C7D7D)
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.square;
    canvas.drawLine(const Offset(1012, 510), const Offset(1214, 490), terracePaint);
    canvas.drawLine(const Offset(1000, 650), const Offset(1230, 630), terracePaint);
    canvas.drawLine(const Offset(990, 757), const Offset(1272, 742), terracePaint);

    final base = Path()
      ..moveTo(920, 760)
      ..lineTo(1018, 724)
      ..lineTo(1248, 710)
      ..lineTo(1350, 770)
      ..lineTo(1332, 802)
      ..lineTo(930, 802)
      ..close();
    canvas.drawPath(base, sideFace);

    final baseGlow = Paint()
      ..color = const Color(0xAA6DB9B6)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(970, 772), const Offset(1305, 757), baseGlow);

    final baseWindows = Paint()..color = const Color(0xFFD1AD70);
    for (var i = 0; i < 8; i++) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(990.0 + i * 38.0, 780.0 - i * 1.5, 18, 12),
          const Radius.circular(2),
        ),
        baseWindows,
      );
    }

    // Small access pylons frame the command complex.
    final pylonPaint = Paint()..color = const Color(0xFF243A47);
    canvas.drawRect(const Rect.fromLTWH(900, 690, 22, 110), pylonPaint);
    canvas.drawRect(const Rect.fromLTWH(1352, 680, 25, 122), pylonPaint);
    canvas.drawRect(
      const Rect.fromLTWH(904, 704, 14, 4),
      coolLight,
    );
    canvas.drawRect(
      const Rect.fromLTWH(1357, 698, 15, 4),
      coolLight,
    );
  }

  void _drawForeground(Canvas canvas) {
    final ground = Path()
      ..moveTo(0, 820)
      ..cubicTo(220, 792, 360, 850, 540, 830)
      ..cubicTo(720, 805, 820, 840, 980, 830)
      ..cubicTo(1170, 815, 1380, 850, 1600, 805)
      ..lineTo(1600, 900)
      ..lineTo(0, 900)
      ..close();
    canvas.drawPath(
      ground,
      Paint()..color = const Color(0xFF101F2B),
    );

    final avenue = Path()
      ..moveTo(1040, 900)
      ..lineTo(1130, 812)
      ..lineTo(1180, 810)
      ..lineTo(1285, 900)
      ..close();
    canvas.drawPath(
      avenue,
      Paint()..color = const Color(0xFF243642),
    );
    canvas.drawLine(
      const Offset(1160, 830),
      const Offset(1165, 900),
      Paint()
        ..color = const Color(0x66D4BC8A)
        ..strokeWidth = 3,
    );

    // Small illuminated curb markers add depth without scene assets.
    final curbLight = Paint()..color = const Color(0xA8D0B477);
    for (var i = 0; i < 10; i++) {
      final x = 112.0 + i * 74.0;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, 856 - (i % 3) * 4.0, 15, 3),
          const Radius.circular(2),
        ),
        curbLight,
      );
    }
    final canal = Path()
      ..moveTo(0, 838)
      ..cubicTo(190, 827, 295, 845, 440, 832)
      ..cubicTo(600, 820, 760, 838, 915, 826)
      ..lineTo(910, 856)
      ..cubicTo(730, 869, 550, 849, 430, 860)
      ..cubicTo(260, 874, 130, 850, 0, 864)
      ..close();
    canvas.drawPath(
      canal,
      Paint()..color = const Color(0xFF152C38),
    );
    canvas.drawLine(
      const Offset(0, 844),
      const Offset(910, 837),
      Paint()
        ..color = const Color(0x446EB8BC)
        ..strokeWidth = 2,
    );
  }

  void _drawVignette(Canvas canvas) {
    final bounds = const Rect.fromLTWH(
      0,
      0,
      _designWidth,
      _designHeight,
    );
    final vignette = Paint()
      ..shader = const RadialGradient(
        center: Alignment(0.2, -0.1),
        radius: 1.18,
        colors: [
          Color(0x00000000),
          Color(0x2209141D),
          Color(0xAA09131D),
        ],
        stops: [0.48, 0.78, 1.0],
      ).createShader(bounds);
    canvas.drawRect(bounds, vignette);
  }

  @override
  bool shouldRepaint(covariant _ArenaMenuBackdropPainter oldDelegate) => false;
}
