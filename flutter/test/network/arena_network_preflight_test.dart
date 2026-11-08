import 'package:flutter_test/flutter_test.dart';
import 'package:project_arena_flutter/network/arena_network_preflight.dart';

void main() {
  test('loopback TCP probe opens and releases an ephemeral socket', () async {
    expect(await ArenaNetworkPreflight.checkLoopbackTcp(), isTrue);
  });
}
