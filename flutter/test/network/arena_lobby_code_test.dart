import 'package:flutter_test/flutter_test.dart';
import 'package:project_arena_flutter/network/arena_lobby_code.dart';

void main() {
  group('ArenaLobbyCode', () {
    test('generates a 128-bit hexadecimal invitation code', () {
      final code = ArenaLobbyCode.generate();
      expect(code, hasLength(32));
      expect(ArenaLobbyCode.isValid(code), isTrue);
    });

    test('does not repeat adjacent generated codes', () {
      final first = ArenaLobbyCode.generate();
      final second = ArenaLobbyCode.generate();
      expect(second, isNot(first));
    });

    test('rejects malformed invitation codes', () {
      expect(ArenaLobbyCode.isValid(''), isFalse);
      expect(ArenaLobbyCode.isValid('abc123'), isFalse);
      expect(ArenaLobbyCode.isValid('g' * 32), isFalse);
    });

    test('normalizes player names and enforces the 18 code point limit', () {
      expect(
        ArenaLobbyCode.normalizeDisplayName('  Player   One  '),
        'Player One',
      );
      expect(
        ArenaLobbyCode.normalizeDisplayName('12345678901234567890'),
        '123456789012345678',
      );
    });

    test('rejects an empty player name', () {
      expect(
        () => ArenaLobbyCode.normalizeDisplayName('  '),
        throwsArgumentError,
      );
    });
  });
}
