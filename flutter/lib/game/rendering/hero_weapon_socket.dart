import 'package:flutter/foundation.dart';
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import '../match/moba_match_simulation.dart';

/// Attaches a real, per-hero CC0 weapon to the imported rig's right palm.
/// Templates are imported once and cloned so bots share mesh/material resources.
abstract final class HeroWeaponSocket {
  static final Map<MobaHeroId, Future<Node>> _templates = {};

  static String _assetFor(MobaHeroId hero) => switch (hero) {
        MobaHeroId.lyra => 'assets/weapons/lyra_sword.glb',
        MobaHeroId.bastion => 'assets/weapons/bastion_sword.glb',
        MobaHeroId.kairo => 'assets/weapons/kairo_sword.glb',
      };

  static double _scaleFor(MobaHeroId hero) => switch (hero) {
        MobaHeroId.lyra => 0.14,
        MobaHeroId.bastion => 0.13,
        MobaHeroId.kairo => 0.26,
      };

  static Future<void> attach(Node modelRoot, MobaHeroId hero) async {
    final palm = modelRoot.getChildByName('Palm.R');
    if (palm == null) {
      debugPrint('[Arena] ${hero.name}: Palm.R was not found; weapon skipped.');
      return;
    }
    if (palm.getChildByName('equipped_weapon') != null) return;

    try {
      final template = _templates.putIfAbsent(
        hero,
        () => Node.fromGlbAsset(_assetFor(hero)),
      );
      final weapon = (await template).clone();
      weapon
        ..name = 'equipped_weapon'
        ..scale = vm.Vector3.all(_scaleFor(hero))
        ..position = vm.Vector3(0, -0.035, 0);
      palm.add(weapon);
    } catch (error, stackTrace) {
      debugPrint('[Arena] ${hero.name}: weapon attachment failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }
}
