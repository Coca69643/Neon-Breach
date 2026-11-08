import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local-only player identity. No account, analytics or network dependency.
class ArenaPlayerProfile {
  const ArenaPlayerProfile({
    this.displayName = defaultDisplayName,
    this.avatarPath,
  });

  static const defaultDisplayName = 'JOGADOR';
  static const maxDisplayNameLength = 18;

  final String displayName;
  final String? avatarPath;

  ArenaPlayerProfile copyWith({
    String? displayName,
    String? avatarPath,
    bool clearAvatar = false,
  }) {
    return ArenaPlayerProfile(
      displayName: displayName ?? this.displayName,
      avatarPath: clearAvatar ? null : (avatarPath ?? this.avatarPath),
    );
  }

  static String normalizeDisplayName(String value) {
    final collapsed = value
        .replaceAll(RegExp(r'[\r\n\t]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (collapsed.isEmpty) return defaultDisplayName;

    final safeRunes = collapsed.runes
        .where((rune) => rune >= 0x20 && rune != 0x7F)
        .take(maxDisplayNameLength)
        .toList(growable: false);
    if (safeRunes.isEmpty) return defaultDisplayName;
    return String.fromCharCodes(safeRunes);
  }
}

/// Persists the profile and copies picked pictures out of ImagePicker's cache.
/// Android can recreate MainActivity while the system gallery is open, so the
/// caller must invoke [recoverLostAvatar] during startup.
class ArenaPlayerProfileStore {
  ArenaPlayerProfileStore({
    SharedPreferencesAsync? preferences,
    ImagePicker? imagePicker,
  })  : _preferences = preferences ?? SharedPreferencesAsync(),
        _imagePicker = imagePicker ?? ImagePicker();

  static const _nameKey = 'player_profile.display_name.v1';
  static const _avatarKey = 'player_profile.avatar_path.v1';

  final SharedPreferencesAsync _preferences;
  final ImagePicker _imagePicker;

  Future<ArenaPlayerProfile> load() async {
    final name = ArenaPlayerProfile.normalizeDisplayName(
      await _preferences.getString(_nameKey) ?? '',
    );
    final path = await _preferences.getString(_avatarKey);
    if (path == null || path.isEmpty) {
      return ArenaPlayerProfile(displayName: name);
    }

    final photo = File(path);
    if (await photo.exists()) {
      return ArenaPlayerProfile(displayName: name, avatarPath: path);
    }
    await _preferences.remove(_avatarKey);
    return ArenaPlayerProfile(displayName: name);
  }

  Future<ArenaPlayerProfile> saveDisplayName(String value) async {
    final name = ArenaPlayerProfile.normalizeDisplayName(value);
    await _preferences.setString(_nameKey, name);
    final current = await load();
    return current.copyWith(displayName: name);
  }

  Future<XFile?> pickAvatarFile() {
    return _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 84,
    );
  }

  Future<ArenaPlayerProfile> saveAvatar(XFile picked) async {
    final supportDirectory = await getApplicationSupportDirectory();
    final profileDirectory = Directory(
      '${supportDirectory.path}/player_profile',
    );
    await profileDirectory.create(recursive: true);

    final rawExtension = picked.path.contains('.')
        ? picked.path.split('.').last.toLowerCase()
        : 'jpg';
    final extension = const {'jpg', 'jpeg', 'png', 'webp'}.contains(rawExtension)
        ? rawExtension
        : 'jpg';
    final destination = File(
      '${profileDirectory.path}/avatar_${DateTime.now().microsecondsSinceEpoch}.$extension',
    );
    await File(picked.path).copy(destination.path);

    await _preferences.setString(_avatarKey, destination.path);
    return load();
  }

  Future<ArenaPlayerProfile?> pickAndSaveAvatar() async {
    final picked = await pickAvatarFile();
    if (picked == null) return null;
    return saveAvatar(picked);
  }

  Future<ArenaPlayerProfile?> recoverLostAvatar() async {
    final response = await _imagePicker.retrieveLostData();
    if (response.isEmpty) return null;
    final files = response.files;
    if (files == null || files.isEmpty) return null;
    return saveAvatar(files.first);
  }
}
