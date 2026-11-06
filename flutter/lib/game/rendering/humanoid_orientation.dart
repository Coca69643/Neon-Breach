import 'dart:math' as math;

/// Converts a world-space direction into the yaw expected by the bundled
/// humanoid GLBs. Visual inspection of the front-facing selection preview
/// confirms that these rigs face local -Z, not +Z.
abstract final class HumanoidOrientation {
  static double yawForDirection(double x, double z) {
    if (!x.isFinite || !z.isFinite || x * x + z * z < 1e-12) {
      return 0;
    }
    return math.atan2(x, z) + math.pi;
  }
}
