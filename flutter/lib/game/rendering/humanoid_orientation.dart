import 'dart:math' as math;

/// Converts a world-space movement vector into the yaw expected by the
/// bundled Quaternius/Kenney humanoid rigs, whose forward axis is local +Z.
abstract final class HumanoidOrientation {
  static double yawForDirection(double x, double z) {
    if (!x.isFinite || !z.isFinite || x * x + z * z < 1e-12) {
      return 0;
    }
    return math.atan2(x, z);
  }
}
