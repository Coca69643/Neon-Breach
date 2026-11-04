import 'package:flutter_test/flutter_test.dart';
import 'package:project_arena_flutter/game/ai/bot_decision_machine.dart';

void main() {
  group('Bot decision machine', () {
    test('chooses lane, engages, retreats and resumes patrol', () {
      final bot = createBotDecisionMachine();

      expect(bot.dispatch(BotDecisionEvent.spawnComplete), isTrue);
      expect(bot.state, BotDecisionState.lanePatrol);

      expect(bot.dispatch(BotDecisionEvent.threatDetected), isTrue);
      expect(bot.state, BotDecisionState.engage);

      expect(bot.dispatch(BotDecisionEvent.healthCritical), isTrue);
      expect(bot.state, BotDecisionState.retreat);

      expect(bot.dispatch(BotDecisionEvent.healthRecovered), isTrue);
      expect(bot.state, BotDecisionState.lanePatrol);
    });

    test('selects objective and neutral camp through explicit events', () {
      final bot = createBotDecisionMachine();
      bot.dispatch(BotDecisionEvent.spawnComplete);

      expect(bot.dispatch(BotDecisionEvent.objectiveCalled), isTrue);
      expect(bot.state, BotDecisionState.contestObjective);
      expect(bot.dispatch(BotDecisionEvent.objectiveResolved), isTrue);
      expect(bot.state, BotDecisionState.lanePatrol);

      expect(bot.dispatch(BotDecisionEvent.neutralCampAvailable), isTrue);
      expect(bot.state, BotDecisionState.captureNeutralCamp);
    });

    test('a dead bot cannot decide until respawn', () {
      final bot = createBotDecisionMachine();
      bot.dispatch(BotDecisionEvent.spawnComplete);
      bot.dispatch(BotDecisionEvent.killed);

      expect(bot.state, BotDecisionState.dead);
      expect(bot.dispatch(BotDecisionEvent.threatDetected), isFalse);
      expect(bot.dispatch(BotDecisionEvent.respawnRequested), isTrue);
      expect(bot.state, BotDecisionState.spawning);
    });
  });
}
