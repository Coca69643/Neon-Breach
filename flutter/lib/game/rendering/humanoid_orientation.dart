import 'dart:math' as math;

/// Converts movement vectors to the yaw expected by each bundled rig family.
///
/// Kenney Mini Characters and the lane-unit rigs face local +Z. The separate
/// Quaternius animated hero GLBs face local -Z, so the playable hero renderer
/// must use the explicit negative-Z variant instead of rotating every NPC.
abstract final class HumanoidOrientation {
  static double yawForDirection(double x, double z) {
    if (!x.isFinite || !z.isFinite || x * x + z * z < 1e-12) {
      return 0;
    }
    return math.atan2(x, z);
  }

  static double yawForNegativeZDirection(double x, double z) {
    final yaw = yawForDirection(x, z);
    if (!x.isFinite || !z.isFinite || x * x + z * z < 1e-12) {
      return 0;
    }
    return yaw + math.pi;
  }
}
