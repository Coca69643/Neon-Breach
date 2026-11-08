import 'package:flutter_test/flutter_test.dart';
import 'package:project_arena_flutter/game/match/moba_match_simulation.dart';
import 'package:project_arena_flutter/game/physics/arena_physics_runtime.dart';
import 'package:project_arena_flutter/game/world/arena_world_catalog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ArenaPhysicsRuntime', () {
    late ArenaPhysicsRuntime physics;

    Future<void> advance({
      int frames = 60,
      double moveX = 0,
      double moveZ = 0,
    }) async {
      physics.setInput(moveX, moveZ);
      for (var frame = 0; frame < frames; frame++) {
        physics.update(1 / 60);
      }
    }

    setUp(() async {
      physics = await ArenaPhysicsRuntime.create(
        spawn: const MobaPoint(0, -60),
      );
    });

    tearDown(() {
      physics.dispose();
    });

    test('hero traversal profiles create distinct movement identities', () {
      final lyra = ArenaTraversalProfile.forHero(MobaHeroId.lyra);
      final bastion = ArenaTraversalProfile.forHero(MobaHeroId.bastion);
      final kairo = ArenaTraversalProfile.forHero(MobaHeroId.kairo);

      expect(lyra.maxCharges, 3);
      expect(bastion.maxCharges, 2);
      expect(kairo.maxCharges, 4);
      expect(bastion.dashDistance, lessThan(lyra.dashDistance));
      expect(kairo.dashDistance, greaterThan(lyra.dashDistance));
      expect(
        {lyra.dashDuration, bastion.dashDuration, kairo.dashDuration}.length,
        3,
        reason: 'each hero has an independently tuned traversal response',
      );
    });

    test('air steering and slide tuning are distinct for each hero', () {
      final lyra = ArenaTraversalProfile.forHero(MobaHeroId.lyra);
      final bastion = ArenaTraversalProfile.forHero(MobaHeroId.bastion);
      final kairo = ArenaTraversalProfile.forHero(MobaHeroId.kairo);

      expect(bastion.airControlRatio, lessThan(lyra.airControlRatio));
      expect(kairo.airControlRatio, greaterThan(lyra.airControlRatio));
      expect(bastion.slideDuration, lessThan(lyra.slideDuration));
      expect(kairo.slideDuration, greaterThan(lyra.slideDuration));
      expect(
        bastion.slideFrictionMultiplier,
        greaterThan(kairo.slideFrictionMultiplier),
      );
    });

    test('momentum slide requires ground speed and does not spend dash charge',
        () async {
      expect(physics.canTriggerSlide, isFalse);
      expect(physics.triggerTraversalSlide(), isFalse,
          reason: 'a stationary character cannot start a slide');

      await advance(frames: 60, moveX: 1);
      final runSpeed = physics.horizontalSpeed;
      final slideStartX = physics.playerPosition.x;
      final staminaBeforeSlide = physics.traversalStamina;

      expect(runSpeed, greaterThan(4.6));
      expect(physics.canTriggerSlide, isTrue);
      expect(physics.triggerTraversalSlide(), isTrue);
      expect(physics.sliding, isTrue);
      expect(physics.triggerTraversalDash(1, 0), isFalse,
          reason: 'dash and slide cannot interrupt each other');
      expect(
        physics.traversalStamina,
        closeTo(staminaBeforeSlide, 1e-6),
        reason: 'a movement slide does not consume dash charges',
      );

      await advance(frames: 6, moveX: -1);
      expect(
        physics.playerPosition.x,
        greaterThan(slideStartX),
        reason: 'reverse input steers gradually instead of snapping momentum',
      );
      expect(
        physics.horizontalSpeed,
        greaterThan(runSpeed * 0.55),
        reason: 'the slide preserves most of the starting momentum',
      );

      await advance(frames: 35);
      expect(physics.sliding, isFalse);
      expect(physics.consumeSlideCompletion(), isTrue);
      expect(physics.consumeSlideCompletion(), isFalse);
    });

    test('synthetic prototype owns a distinct movement profile', () {
      final synthetic = ArenaTraversalProfile.syntheticPrototype();
      final lyra = ArenaTraversalProfile.forHero(MobaHeroId.lyra);
      final bastion = ArenaTraversalProfile.forHero(MobaHeroId.bastion);
      final kairo = ArenaTraversalProfile.forHero(MobaHeroId.kairo);

      expect(synthetic.groundSpeed, greaterThan(kairo.groundSpeed));
      expect(synthetic.groundAcceleration, greaterThan(lyra.groundAcceleration));
      expect(synthetic.jumpImpulse, greaterThan(kairo.jumpImpulse));
      expect(synthetic.slideDuration, greaterThan(lyra.slideDuration));
      expect(synthetic.airControlRatio, greaterThan(bastion.airControlRatio));
    });

    test('synthetic traversal jump is grounded, one-shot and gravity-resolved',
        () async {
      final synthetic = await ArenaPhysicsRuntime.create(
        spawn: const MobaPoint(0, -60),
        traversalProfile: ArenaTraversalProfile.syntheticPrototype(),
      );
      try {
        for (var frame = 0; frame < 4; frame++) {
          synthetic.update(1 / 60);
        }

        expect(synthetic.grounded, isTrue);
        expect(synthetic.canTriggerJump, isTrue);
        expect(synthetic.triggerTraversalJump(), isTrue);
        expect(synthetic.jumping, isTrue);
        expect(
          synthetic.triggerTraversalJump(),
          isFalse,
          reason: 'the prototype cannot jump again before landing',
        );

        for (var frame = 0; frame < 12; frame++) {
          synthetic.update(1 / 60);
        }
        expect(synthetic.verticalVelocity, greaterThan(0));
        expect(synthetic.playerPosition.elevation, greaterThan(0.2));

        for (var frame = 0; frame < 100; frame++) {
          synthetic.update(1 / 60);
        }
        expect(synthetic.grounded, isTrue);
        expect(synthetic.jumping, isFalse);
        expect(synthetic.verticalVelocity.abs(), lessThan(0.05));
        expect(synthetic.playerPosition.elevation.abs(), lessThan(0.20));
      } finally {
        synthetic.dispose();
      }
    });

    test('synthetic jump state resets on an explicit teleport', () async {
      final synthetic = await ArenaPhysicsRuntime.create(
        spawn: const MobaPoint(0, -60),
        traversalProfile: ArenaTraversalProfile.syntheticPrototype(),
      );
      try {
        for (var frame = 0; frame < 4; frame++) {
          synthetic.update(1 / 60);
        }
        expect(synthetic.triggerTraversalJump(), isTrue);
        expect(synthetic.jumping, isTrue);

        synthetic.teleport(const MobaPoint(0, -60));

        expect(synthetic.jumping, isFalse);
        expect(synthetic.verticalVelocity, 0);
      } finally {
        synthetic.dispose();
      }
    });

    test('gravity settles the capsule on the terrain', () async {
      await advance(frames: 60);

      expect(physics.grounded, isTrue);
      expect(physics.verticalVelocity.abs(), lessThan(0.05));
      expect(physics.playerPosition.elevation.abs(), lessThan(0.20));
      expect(
        ArenaWorldCatalog.contains(
          physics.playerPosition.x,
          physics.playerPosition.z,
        ),
        isTrue,
      );
    });

    test('the enlarged entrance is traversable but side walls block movement',
        () async {
      physics.teleport(const MobaPoint(-63, -54));
      await advance(frames: 100, moveZ: 1);
      expect(
        physics.playerPosition.z,
        greaterThan(-47),
        reason: 'the capsule must pass through the 6.4-unit doorway',
      );

      physics.teleport(const MobaPoint(-63, -38));
      await advance(frames: 180, moveX: -1);
      expect(
        physics.playerPosition.x,
        greaterThan(-74.5),
        reason: 'the capsule must stop before the west interior wall',
      );
      expect(physics.playerPosition.x, lessThan(-73.0));
      expect(physics.grounded, isTrue);
    });

    test('the canal blocks ordinary crossings but leaves bridge corridors open',
        () async {
      physics.teleport(const MobaPoint(18, -5));
      await advance(frames: 120, moveZ: 1);
      expect(
        physics.playerPosition.z,
        lessThan(-3.0),
        reason: 'the capsule must stop before entering the canal away from a bridge',
      );
      expect(physics.grounded, isTrue);
      expect(
        ArenaWorldCatalog.isCanalAt(
          physics.playerPosition.x,
          physics.playerPosition.z,
        ),
        isFalse,
        reason: 'the character must remain on the near bank',
      );

      physics.teleport(const MobaPoint(0, -5));
      await advance(frames: 150, moveZ: 1);
      expect(
        physics.playerPosition.z,
        greaterThan(3.0),
        reason: 'the central bridge must remain a continuous physical route',
      );
      expect(physics.grounded, isTrue);
    });

    test('the mezzanine ramp connects the ground floor to the upper deck',
        () async {
      final access = ArenaWorldCatalog.verticalAccesses.first;
      final z = (access.corridorMinZ + access.corridorMaxZ) * 0.5;
      physics.teleport(MobaPoint(access.rampStartX + 0.2, z));
      await advance(frames: 100, moveX: 1);

      expect(
        physics.playerPosition.x,
        greaterThan(access.rampEndX - 0.1),
      );
      expect(
        physics.playerPosition.elevation,
        greaterThan(2.8),
        reason: 'the capsule must gain height while climbing the ramp',
      );
      expect(physics.grounded, isTrue);
    });

    test('surface traction changes speed and releases momentum smoothly',
        () async {
      await advance(frames: 90, moveZ: -1);
      final pavedSpeed = physics.horizontalSpeed;
      expect(pavedSpeed, greaterThan(4.6));

      physics.teleport(const MobaPoint(-86, 14));
      await advance(frames: 90, moveX: 1);
      final grassSpeed = physics.horizontalSpeed;
      expect(grassSpeed, lessThan(pavedSpeed * 0.9));

      await advance(frames: 30);
      expect(physics.horizontalSpeed, lessThan(grassSpeed * 0.35));
    });

    test('Rapier dash is swept, short and blocked by interior walls', () async {
      physics.teleport(const MobaPoint(0, -60));
      expect(physics.triggerDash(1, 0), isTrue);
      await advance(frames: 22);
      expect(physics.playerPosition.x, greaterThan(3.2));
      expect(physics.playerPosition.x, lessThan(5.4));
      expect(physics.consumeDashCompletion(), isTrue);
      expect(physics.consumeDashCompletion(), isFalse);
      expect(physics.grounded, isTrue);

      physics.teleport(const MobaPoint(-71, -38));
      expect(physics.triggerDash(-1, 0), isTrue);
      await advance(frames: 22);
      expect(
        physics.playerPosition.x,
        greaterThan(-74.5),
        reason: 'the dash must stop at the physical interior wall',
      );
      expect(physics.consumeDashCompletion(), isTrue);
      expect(physics.grounded, isTrue);
    });

    test('traversal dash spends stamina, regenerates after a delay and resets on respawn', () async {
      physics.teleport(const MobaPoint(0, -60));
      expect(
        physics.traversalStamina,
        closeTo(physics.traversalStaminaMax, 1e-6),
      );
      expect(physics.canTriggerTraversalDash, isTrue);

      expect(physics.triggerTraversalDash(1, 0), isTrue);
      expect(
        physics.traversalStamina,
        closeTo(physics.traversalStaminaMax - 1, 1e-6),
      );
      expect(
        physics.triggerTraversalDash(0, 1),
        isFalse,
        reason: 'a second traversal dash cannot interrupt the active dash',
      );

      await advance(frames: 30);
      expect(physics.consumeDashCompletion(), isFalse,
          reason: 'traversal must not invoke the hero-skill dash completion path');
      expect(physics.consumeTraversalDashCompletion(), isTrue);
      expect(physics.consumeTraversalDashCompletion(), isFalse);
      expect(
        physics.traversalStamina,
        closeTo(physics.traversalStaminaMax - 1, 0.02),
        reason: 'stamina does not regenerate during the recovery delay',
      );

      await advance(frames: 90);
      expect(physics.traversalStamina, greaterThan(2.8));
      expect(physics.traversalStamina, lessThan(3.0));

      final staminaBeforeSuspend = physics.traversalStamina;
      physics.setActive(false);
      await advance(frames: 60);
      expect(
        physics.traversalStamina,
        closeTo(staminaBeforeSuspend, 1e-6),
        reason: 'inactive actors do not regenerate traversal stamina',
      );

      physics.teleport(const MobaPoint(0, -60));
      expect(
        physics.traversalStamina,
        closeTo(physics.traversalStaminaMax, 1e-6),
        reason: 'the explicit respawn transition restores the movement budget',
      );
    });

    test('diagonal input is normalized and never exceeds forward speed', () async {
      await advance(frames: 90, moveX: 1, moveZ: 1);

      expect(
        physics.horizontalSpeed,
        lessThanOrEqualTo(ArenaPhysicsRuntime.moveSpeed * 1.03),
      );
    });

    test('direction reversal brakes before building speed in the new direction',
        () async {
      await advance(frames: 60, moveX: 1);
      final beforeReverse = physics.playerPosition.x;
      expect(physics.horizontalSpeed, greaterThan(4.6));

      await advance(frames: 12, moveX: -1);

      expect(
        physics.horizontalSpeed,
        lessThan(1.0),
        reason: 'the motor must absorb forward momentum before reversing',
      );
      expect(
        physics.playerPosition.x,
        greaterThan(beforeReverse),
        reason: 'the character must not instantly teleport into reverse motion',
      );

      await advance(frames: 36, moveX: -1);
      expect(physics.playerPosition.x, lessThan(beforeReverse));
    });

    test('fixed-step movement stays consistent across render frame rates',
        () async {
      final secondRuntime = await ArenaPhysicsRuntime.create(
        spawn: const MobaPoint(0, -60),
      );
      try {
        physics.setInput(1, 0);
        secondRuntime.setInput(1, 0);
        for (var frame = 0; frame < 60; frame++) {
          physics.update(1 / 60);
        }
        for (var frame = 0; frame < 30; frame++) {
          secondRuntime.update(1 / 30);
        }

        expect(
          physics.playerPosition.x,
          closeTo(secondRuntime.playerPosition.x, 0.08),
        );
        expect(
          physics.playerPosition.z,
          closeTo(secondRuntime.playerPosition.z, 0.08),
        );
      } finally {
        secondRuntime.dispose();
      }
    });

    test('teleport is an explicit respawn operation and resets velocity',
        () async {
      await advance(frames: 30, moveX: 1);
      expect(physics.horizontalSpeed, greaterThan(0));

      physics.teleport(const MobaPoint(0, -60));
      expect(physics.horizontalSpeed, 0);
      expect(physics.verticalVelocity, 0);
      expect(physics.playerPosition.x, closeTo(0, 0.001));
      expect(physics.playerPosition.z, closeTo(-60, 0.001));
    });
  });
}
