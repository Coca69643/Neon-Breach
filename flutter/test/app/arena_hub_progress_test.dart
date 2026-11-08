import 'package:flutter_test/flutter_test.dart';
import 'package:project_arena_flutter/app/arena_hub_progress.dart';

class _MemoryArenaPreferences implements ArenaHubPreferences {
  final Map<String, Object> values = {};

  @override
  Future<int?> getInt(String key) async => values[key] as int?;

  @override
  Future<String?> getString(String key) async => values[key] as String?;

  @override
  Future<List<String>?> getStringList(String key) async {
    final value = values[key] as List<String>?;
    return value == null ? null : List<String>.of(value);
  }

  @override
  Future<void> setInt(String key, int value) async {
    values[key] = value;
  }

  @override
  Future<void> setString(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> setStringList(String key, List<String> value) async {
    values[key] = List<String>.of(value);
  }
}

void main() {
  late _MemoryArenaPreferences preferences;
  late ArenaHubProgressStore store;

  setUp(() {
    preferences = _MemoryArenaPreferences();
    store = ArenaHubProgressStore(preferences: preferences);
  });

  tearDown(() {
    store.dispose();
  });

  test('baú diário concede recompensa fixa uma única vez', () async {
    await store.load();

    expect(store.canClaimDailyChest, isTrue);
    expect(await store.claimDailyChest(), isTrue);
    expect(store.credits, ArenaHubProgressStore.dailyChestCredits);
    expect(store.canClaimDailyChest, isFalse);
    expect(await store.claimDailyChest(), isFalse);
    expect(store.credits, ArenaHubProgressStore.dailyChestCredits);
  });

  test('partidas e vitórias atualizam desafios persistentes', () async {
    await store.load();

    await store.recordMatchFinished(victory: true);
    await store.recordMatchFinished(victory: false);

    expect(store.completedMatches, 2);
    expect(store.wins, 1);
    expect(
      store.challenges
          .firstWhere((item) => item.id == 'first_match')
          .canClaim,
      isTrue,
    );
    expect(
      store.challenges
          .firstWhere((item) => item.id == 'first_victory')
          .canClaim,
      isTrue,
    );

    expect(await store.claimChallenge('first_match'), isTrue);
    expect(await store.claimChallenge('first_match'), isFalse);
    expect(store.credits, 60);
  });

  test('mercador compra e equipa somente molduras cosméticas', () async {
    await store.load();
    await store.claimDailyChest();
    await store.recordMatchFinished(victory: true);
    await store.claimChallenge('first_match');
    await store.claimChallenge('first_victory');

    expect(store.credits, 250);
    expect(await store.purchaseFrame('tide'), isTrue);
    expect(store.credits, 110);
    expect(store.ownsFrame('tide'), isTrue);
    expect(await store.equipFrame('tide'), isTrue);
    expect(store.equippedFrame.id, 'tide');
    expect(await store.purchaseFrame('tide'), isFalse);
  });

  test('reabre os dados salvos em uma nova instância do store', () async {
    await store.load();
    await store.claimDailyChest();
    await store.recordMatchFinished(victory: true);

    final restored = ArenaHubProgressStore(preferences: preferences);
    addTearDown(restored.dispose);
    await restored.load();

    expect(restored.credits, 100);
    expect(restored.completedMatches, 1);
    expect(restored.wins, 1);
    expect(restored.canClaimDailyChest, isFalse);
  });

  test('desafio de cinco partidas só fica disponível após cinco resultados',
      () async {
    await store.load();

    for (var i = 0; i < 4; i++) {
      await store.recordMatchFinished(victory: false);
    }
    expect(store.challenges.last.canClaim, isFalse);

    await store.recordMatchFinished(victory: false);
    expect(store.challenges.last.canClaim, isTrue);
    expect(await store.claimChallenge('five_matches'), isTrue);
    expect(store.credits, 220);
  });
}
