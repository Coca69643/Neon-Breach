import 'dart:io';

/// Probes only loopback TCP. It does not discover devices or open a LAN host.
abstract final class ArenaNetworkPreflight {
  static Future<bool> checkLoopbackTcp() async {
    ServerSocket? probe;
    try {
      probe = await ServerSocket.bind(
        InternetAddress.loopbackIPv4,
        0,
      ).timeout(const Duration(seconds: 2));
      return probe.port > 0;
    } catch (_) {
      return false;
    } finally {
      if (probe != null) {
        try {
          await probe.close();
        } catch (_) {
          // Best-effort cleanup must not block offline startup.
        }
      }
    }
  }
}
