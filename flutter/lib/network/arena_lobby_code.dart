import 'dart:math';

class ArenaLobbyCode {
  ArenaLobbyCode._();

  static final Random _random = Random.secure();

  /// A 128-bit invitation code. The value is a capability, not a user password.
  static String generate() => List<int>.generate(16, (_) => _random.nextInt(256))
      .map((value) => value.toRadixString(16).padLeft(2, '0'))
      .join();

  static bool isValid(String value) =>
      RegExp(r'^[0-9a-fA-F]{32}$').hasMatch(value.trim());

  static String normalizeDisplayName(String value) {
    final normalized = value.replaceAll(RegExp(r'[\u0000-\u001F\u007F]'), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.isEmpty) {
      throw ArgumentError.value(value, 'displayName', 'Nome obrigatório.');
    }
    return normalized.charactersTake(18);
  }
}

extension on String {
  String charactersTake(int maxLength) {
    final runes = this.runes.take(maxLength).toList(growable: false);
    return String.fromCharCodes(runes);
  }
}
