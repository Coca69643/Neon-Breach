import 'package:flutter_test/flutter_test.dart';
import 'package:project_arena_flutter/network/arena_lan_lobby.dart';
import 'package:project_arena_flutter/network/arena_lobby_code.dart';

void main() {
  group('Arena LAN lobby', () {
    test('host and client exchange a bounded lobby roster', () async {
      final roomCode = ArenaLobbyCode.generate();
      final host = ArenaLanLobbyHost(
        displayName: 'Anfitriao',
        roomCode: roomCode,
      );

      ArenaLanLobbyClient? client;
      try {
        final endpoint = await host.start();
        client = await ArenaLanLobbyClient.join(
          address: '127.0.0.1',
          port: endpoint.port,
          roomCode: roomCode,
          displayName: 'Visitante',
        );

        expect(client.currentMembers, containsAll(['Anfitriao', 'Visitante']));
        expect(host.currentMembers, containsAll(['Anfitriao', 'Visitante']));
        expect(client.currentMembers, hasLength(2));
      } finally {
        await client?.close();
        await host.close();
      }
    });

    test('rejects an invalid room code before opening a socket', () async {
      expect(
        () => ArenaLanLobbyClient.join(
          address: '127.0.0.1',
          port: 1,
          roomCode: 'invalid',
          displayName: 'Visitante',
        ),
        throwsFormatException,
      );
    });
  });
}
