import 'package:flutter_test/flutter_test.dart';
import 'package:project_arena_flutter/app/project_arena_app.dart';

void main() {
  testWidgets('shows the foundation harness and starts in main menu state',
      (tester) async {
    await tester.pumpWidget(const ProjectArenaApp());
    await tester.pump();

    expect(find.text('PROJETO ARENA'), findsOneWidget);
    expect(find.text('FUNDAÇÃO FLUTTER'), findsOneWidget);
    expect(find.text('Menu principal'), findsOneWidget);
    expect(find.text('Testar seleção de personagem'), findsOneWidget);
  });
}
