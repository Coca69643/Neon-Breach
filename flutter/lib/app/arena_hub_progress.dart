import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

@immutable
class ArenaProfileFrameStyle {
  const ArenaProfileFrameStyle({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.color,
    required this.highlight,
  });

  final String id;
  final String name;
  final String description;
  final int price;
  final Color color;
  final Color highlight;
}

@immutable
class ArenaHubChallenge {
  const ArenaHubChallenge({
    required this.id,
    required this.title,
    required this.description,
    required this.progress,
    required this.target,
    required this.reward,
    required this.claimed,
  });

  final String id;
  final String title;
  final String description;
  final int progress;
  final int target;
  final int reward;
  final bool claimed;

  double get fraction => (progress / target).clamp(0.0, 1.0).toDouble();
  bool get completed => progress >= target;
  bool get canClaim => completed && !claimed;
}

abstract interface class ArenaHubPreferences {
  Future<int?> getInt(String key);
  Future<String?> getString(String key);
  Future<List<String>?> getStringList(String key);
  Future<void> setInt(String key, int value);
  Future<void> setString(String key, String value);
  Future<void> setStringList(String key, List<String> value);
}

final class _SharedPreferencesArenaAdapter implements ArenaHubPreferences {
  _SharedPreferencesArenaAdapter(this._delegate);

  final SharedPreferencesAsync _delegate;

  @override
  Future<int?> getInt(String key) => _delegate.getInt(key);

  @override
  Future<String?> getString(String key) => _delegate.getString(key);

  @override
  Future<List<String>?> getStringList(String key) =>
      _delegate.getStringList(key);

  @override
  Future<void> setInt(String key, int value) => _delegate.setInt(key, value);

  @override
  Future<void> setString(String key, String value) =>
      _delegate.setString(key, value);

  @override
  Future<void> setStringList(String key, List<String> value) =>
      _delegate.setStringList(key, value);
}

class ArenaHubProgressStore extends ChangeNotifier {
  ArenaHubProgressStore({ArenaHubPreferences? preferences})
      : _preferences =
            preferences ?? _SharedPreferencesArenaAdapter(SharedPreferencesAsync());

  static const int dailyChestCredits = 100;

  static const List<ArenaProfileFrameStyle> profileFrames = [
    ArenaProfileFrameStyle(
      id: 'standard',
      name: 'PADRÃO',
      description: 'Identidade original do jogador.',
      price: 0,
      color: Color(0xFFE4BB63),
      highlight: Color(0xFFFFE5A8),
    ),
    ArenaProfileFrameStyle(
      id: 'tide',
      name: 'MARÉ',
      description: 'Moldura cosmética em tons oceânicos.',
      price: 140,
      color: Color(0xFF60BFC6),
      highlight: Color(0xFFB6F2E9),
    ),
    ArenaProfileFrameStyle(
      id: 'ember',
      name: 'BRASA',
      description: 'Moldura cosmética em cobre e âmbar.',
      price: 220,
      color: Color(0xFFC87B50),
      highlight: Color(0xFFFFC28B),
    ),
    ArenaProfileFrameStyle(
      id: 'aurora',
      name: 'AURORA',
      description: 'Moldura cosmética em violeta e prata.',
      price: 340,
      color: Color(0xFF9A88D5),
      highlight: Color(0xFFDAD1FF),
    ),
  ];

  static const String _creditsKey = 'arena_hub.credits.v1';
  static const String _matchesKey = 'arena_hub.matches.v1';
  static const String _winsKey = 'arena_hub.wins.v1';
  static const String _dailyChestKey = 'arena_hub.daily_chest_date.v1';
  static const String _ownedFramesKey = 'arena_hub.owned_frames.v1';
  static const String _equippedFrameKey = 'arena_hub.equipped_frame.v1';
  static const String _claimedChallengesKey = 'arena_hub.claimed_challenges.v1';

  final ArenaHubPreferences _preferences;
  bool _loaded = false;
  int _credits = 0;
  int _completedMatches = 0;
  int _wins = 0;
  String? _lastDailyChestDate;
  final Set<String> _ownedFrames = {'standard'};
  final Set<String> _claimedChallenges = {};
  String _equippedFrameId = 'standard';

  bool get isLoaded => _loaded;
  int get credits => _credits;
  int get completedMatches => _completedMatches;
  int get wins => _wins;
  bool get canClaimDailyChest => _lastDailyChestDate != _todayKey();

  ArenaProfileFrameStyle get equippedFrame => profileFrame(_equippedFrameId);

  bool ownsFrame(String id) => _ownedFrames.contains(id);

  ArenaProfileFrameStyle profileFrame(String id) {
    return profileFrames.firstWhere(
      (frame) => frame.id == id,
      orElse: () => profileFrames.first,
    );
  }

  Future<void> load() async {
    if (_loaded) return;
    _credits = (await _preferences.getInt(_creditsKey) ?? 0).clamp(0, 999999).toInt();
    _completedMatches =
        (await _preferences.getInt(_matchesKey) ?? 0).clamp(0, 999999).toInt();
    _wins = (await _preferences.getInt(_winsKey) ?? 0)
        .clamp(0, _completedMatches)
        .toInt();
    _lastDailyChestDate = await _preferences.getString(_dailyChestKey);
    _ownedFrames
      ..clear()
      ..add('standard')
      ..addAll(await _preferences.getStringList(_ownedFramesKey) ?? const []);
    _claimedChallenges
      ..clear()
      ..addAll(await _preferences.getStringList(_claimedChallengesKey) ?? const []);
    final requestedFrame = await _preferences.getString(_equippedFrameKey);
    _equippedFrameId = _ownedFrames.contains(requestedFrame)
        ? requestedFrame!
        : 'standard';
    _loaded = true;
    notifyListeners();
  }

  List<ArenaHubChallenge> get challenges {
    final definitions = <({String id, String title, String description, int target, int reward, int progress})>[
      (
        id: 'first_match',
        title: 'PRIMEIRO CONTATO',
        description: 'Finalize sua primeira partida.',
        target: 1,
        reward: 60,
        progress: _completedMatches,
      ),
      (
        id: 'first_victory',
        title: 'VITÓRIA NA ARENA',
        description: 'Conquiste uma vitória.',
        target: 1,
        reward: 90,
        progress: _wins,
      ),
      (
        id: 'five_matches',
        title: 'PRESENÇA CONSTANTE',
        description: 'Finalize cinco partidas.',
        target: 5,
        reward: 220,
        progress: _completedMatches,
      ),
    ];

    return definitions
        .map(
          (definition) => ArenaHubChallenge(
            id: definition.id,
            title: definition.title,
            description: definition.description,
            progress: definition.progress,
            target: definition.target,
            reward: definition.reward,
            claimed: _claimedChallenges.contains(definition.id),
          ),
        )
        .toList(growable: false);
  }

  Future<bool> claimDailyChest() async {
    await load();
    if (!canClaimDailyChest) return false;
    _credits += dailyChestCredits;
    _lastDailyChestDate = _todayKey();
    await _persist();
    notifyListeners();
    return true;
  }

  Future<void> recordMatchFinished({required bool victory}) async {
    await load();
    _completedMatches = (_completedMatches + 1).clamp(0, 999999).toInt();
    if (victory) _wins = (_wins + 1).clamp(0, _completedMatches).toInt();
    await _persist();
    notifyListeners();
  }

  Future<bool> claimChallenge(String challengeId) async {
    await load();
    final challenge = challenges.where((item) => item.id == challengeId);
    if (challenge.isEmpty || !challenge.first.canClaim) return false;
    _claimedChallenges.add(challengeId);
    _credits += challenge.first.reward;
    await _persist();
    notifyListeners();
    return true;
  }

  Future<bool> purchaseFrame(String frameId) async {
    await load();
    final frame = profileFrame(frameId);
    if (frame.id == 'standard' ||
        _ownedFrames.contains(frame.id) ||
        _credits < frame.price) {
      return false;
    }
    _credits -= frame.price;
    _ownedFrames.add(frame.id);
    await _persist();
    notifyListeners();
    return true;
  }

  Future<bool> equipFrame(String frameId) async {
    await load();
    if (!_ownedFrames.contains(frameId)) return false;
    _equippedFrameId = frameId;
    await _persist();
    notifyListeners();
    return true;
  }

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> _persist() async {
    await _preferences.setInt(_creditsKey, _credits);
    await _preferences.setInt(_matchesKey, _completedMatches);
    await _preferences.setInt(_winsKey, _wins);
    if (_lastDailyChestDate != null) {
      await _preferences.setString(_dailyChestKey, _lastDailyChestDate!);
    }
    await _preferences.setStringList(
      _ownedFramesKey,
      _ownedFrames.toList(growable: false),
    );
    await _preferences.setStringList(
      _claimedChallengesKey,
      _claimedChallenges.toList(growable: false),
    );
    await _preferences.setString(_equippedFrameKey, _equippedFrameId);
  }
}
