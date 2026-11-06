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
