import 'dart:convert';

import 'package:flutter/services.dart';

class ManifestValidationResult {
  const ManifestValidationResult({
    required this.valid,
    this.issues = const [],
  });

  final bool valid;
  final List<String> issues;
}

abstract final class ArenaManifestValidator {
  static const String manifestPath = 'assets/data/arena_manifest.json';
  static const String studioLogoPath =
      'assets/branding/duck_dream_studios.webp.b64';

  static const Map<String, String> requiredAssetGroups = {
    'assets/heroes/': 'modelos de heróis',
    'assets/weapons/': 'conteúdo de equipamento',
    'assets/match/': 'recursos de partida',
    'assets/npcs/': 'personagens de apoio e unidades',
    'assets/world/': 'mundo e distritos',
    'flutter_scene_generated/': 'recursos 3D pré-processados',
  };

  static List<String> missingAssetGroups(Iterable<String> assetPaths) {
    final paths = assetPaths.toSet();
    return requiredAssetGroups.entries
        .where((entry) => !paths.any((path) => path.startsWith(entry.key)))
        .map((entry) => entry.value)
        .toList(growable: false);
  }

  static Future<ManifestValidationResult> validate(
    AssetBundle bundle,
  ) async {
    try {
      final source = await bundle.loadString(manifestPath);
      final decoded = jsonDecode(source);

      if (decoded is! Map<String, dynamic>) {
        return const ManifestValidationResult(
          valid: false,
          issues: ['A raiz do manifesto precisa ser um objeto JSON.'],
        );
      }

      final issues = <String>[];
      final assetManifest = await AssetManifest.loadFromAssetBundle(bundle);
      final assetPaths = assetManifest.listAssets();

      if (!assetPaths.contains(studioLogoPath)) {
        issues.add('Logo de inicialização ausente do pacote.');
      }
      for (final group in missingAssetGroups(assetPaths)) {
        issues.add('Grupo de conteúdo obrigatório ausente: $group.');
      }

      if (decoded['schemaVersion'] != 1) {
        issues.add('Versão de schema não suportada.');
      }
      if (decoded['gameId'] != 'project_arena') {
        issues.add('Identificador do jogo inválido.');
      }
      if (decoded['orientation'] != 'landscape') {
        issues.add('A orientação obrigatória é landscape.');
      }
      if (decoded['offline'] != true) {
        issues.add('O manifesto precisa declarar operação offline.');
      }

      final runtime = decoded['runtime'];
      if (runtime is! Map<String, dynamic>) {
        issues.add('Bloco runtime ausente ou inválido.');
      } else {
        if (runtime['kind'] != 'flutter_scene') {
          issues.add('O runtime precisa ser flutter_scene.');
        }
        if (runtime['status'] != 'scene_integration') {
          issues.add('Status inesperado para a integração Flutter Scene.');
        }
        if (runtime['graphicsRuntime'] != 'Flutter GPU / Impeller') {
          issues.add('Backend gráfico incompatível com Flutter Scene.');
        }
      }

      return ManifestValidationResult(
        valid: issues.isEmpty,
        issues: List.unmodifiable(issues),
      );
    } on Object catch (error) {
      return ManifestValidationResult(
        valid: false,
        issues: ['Não foi possível ler o manifesto: $error'],
      );
    }
  }
}
