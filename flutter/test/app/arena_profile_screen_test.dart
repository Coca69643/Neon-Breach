import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_arena_flutter/app/arena_hub_progress.dart';
import 'package:project_arena_flutter/app/arena_player_profile.dart';
import 'package:project_arena_flutter/app/arena_profile_screen.dart';

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
  late ArenaHubProgressStore progression;

  setUp(() {
    progression = ArenaHubProgressStore(
      preferences: _MemoryArenaPreferences(),
    );
  });

  tearDown(() {
    progression.dispose();
  });

  testWidgets('perfil apresenta a identidade salva e grava novo nome',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;

    const initialProfile = ArenaPlayerProfile(displayName: 'PILOTO TESTE');

    await tester.pumpWidget(
      MaterialApp(
        home: ArenaPlayerProfileScreen(
          profile: initialProfile,
          progression: progression,
          onSaveName: (name) async =>
              initialProfile.copyWith(displayName: name),
          onPickAvatar: () async => null,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byWidgetPredicate(
        (widget) => widget is Text && widget.data == 'PILOTO TESTE',
      ),
      findsOneWidget,
    );
    expect(find.text('PERFIL DO JOGADOR'), findsOneWidget);
    expect(find.text('IDENTIDADE'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'NOVA IDENTIDADE');
    await tester.tap(find.text('SALVAR ALTERAÇÕES'));
    await tester.pumpAndSettle();

    expect(
      find.byWidgetPredicate(
        (widget) => widget is Text && widget.data == 'NOVA IDENTIDADE',
      ),
      findsOneWidget,
    );

    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
