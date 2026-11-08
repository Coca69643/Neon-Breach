import 'package:flutter_test/flutter_test.dart';
import 'package:project_arena_flutter/game/manifest/arena_manifest_validator.dart';

void main() {
  group('ArenaManifestValidator asset groups', () {
    test('accepts a complete package catalog', () {
      const paths = [
        'assets/heroes/lyra.glb',
        'assets/weapons/hero_gear.glb',
        'assets/match/hud_atlas.png',
        'assets/npcs/citizen.glb',
        'assets/world/central_market.glb',
        'flutter_scene_generated/scene_manifest.bin',
      ];

      expect(ArenaManifestValidator.missingAssetGroups(paths), isEmpty);
    });

    test('reports missing groups without loading large scene assets', () {
      const paths = ['assets/heroes/lyra.glb'];

      expect(
        ArenaManifestValidator.missingAssetGroups(paths),
        containsAll([
          'conteúdo de equipamento',
          'recursos de partida',
          'personagens de apoio e unidades',
          'mundo e distritos',
          'recursos 3D pré-processados',
        ]),
      );
    });
  });
}
