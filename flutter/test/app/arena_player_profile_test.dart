import 'package:flutter_test/flutter_test.dart';
import 'package:project_arena_flutter/app/arena_player_profile.dart';

void main() {
  group('ArenaPlayerProfile', () {
    test('uses a safe default display name', () {
      const profile = ArenaPlayerProfile();
      expect(profile.displayName, 'JOGADOR');
      expect(profile.avatarPath, isNull);
    });

    test('normalizes whitespace and removes line breaks', () {
      expect(
        ArenaPlayerProfile.normalizeDisplayName('  Kai\n  R0  '),
        'Kai R0',
      );
    });

    test('does not allow an empty display name', () {
      expect(ArenaPlayerProfile.normalizeDisplayName('  \t  '), 'JOGADOR');
    });

    test('limits names by Unicode code points without splitting emoji', () {
      final normalized = ArenaPlayerProfile.normalizeDisplayName(
        'Árvore 🦊 Explorador de Arena',
      );
      expect(normalized.runes.length, ArenaPlayerProfile.maxDisplayNameLength);
      expect(normalized, startsWith('Árvore 🦊'));
    });

    test('copyWith keeps the avatar unless explicitly cleared', () {
      const profile = ArenaPlayerProfile(
        displayName: 'Kairo',
        avatarPath: '/internal/profile/avatar.jpg',
      );
      expect(profile.copyWith(displayName: 'Lyra').avatarPath, profile.avatarPath);
      expect(profile.copyWith(clearAvatar: true).avatarPath, isNull);
    });
  });
}
