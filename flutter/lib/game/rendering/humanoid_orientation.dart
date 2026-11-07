import 'dart:math' as math;

/// Converts movement vectors to the yaw expected by each bundled rig family.
///
/// The playable Quaternius hero rigs and the animated Kenney Mini Character
/// clips bundled for bots, minions and pedestrians use local -Z as forward.
/// The positive-Z helper remains available for assets whose authored forward
/// axis is explicitly +Z; callers must choose the basis for the actual asset.
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
    return (yaw + math.pi) % (2 * math.pi);
  }
}
