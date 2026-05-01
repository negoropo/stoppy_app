import 'package:flutter_test/flutter_test.dart';
import 'package:stoppy_app/features/game/engine/game_collision_validator.dart';
import 'package:stoppy_app/features/game/engine/run_point_reward_calculator.dart';
import 'package:stoppy_app/features/game/engine/run_point_reward_tier.dart';

void main() {
  group('RunPointRewardCalculator', () {
    const calculator = RunPointRewardCalculator();
    const validator = GameCollisionValidator(
      circleRadius: 100,
      ballRadius: 10,
      safeZoneStartAngle: 0,
      safeZoneSweepAngle: 1,
    );

    test('awards gold for the first and last 10 percent', () {
      final earlyGold = calculator.calculate(
        validator.validateAngle(ballAngle: 0.05),
      );
      final lateGold = calculator.calculate(
        validator.validateAngle(ballAngle: 0.95),
      );

      expect(earlyGold.rewardTier, RunPointRewardTier.gold);
      expect(earlyGold.rpAmount, 3);
      expect(earlyGold.rewarded, isTrue);
      expect(lateGold.rewardTier, RunPointRewardTier.gold);
      expect(lateGold.rpAmount, 3);
      expect(lateGold.rewarded, isTrue);
    });

    test('awards silver for the next 15 percent near each edge', () {
      final earlySilver = calculator.calculate(
        validator.validateAngle(ballAngle: 0.10),
      );
      final lateSilver = calculator.calculate(
        validator.validateAngle(ballAngle: 0.75),
      );

      expect(earlySilver.rewardTier, RunPointRewardTier.silver);
      expect(earlySilver.rpAmount, 2);
      expect(earlySilver.rewarded, isTrue);
      expect(lateSilver.rewardTier, RunPointRewardTier.silver);
      expect(lateSilver.rpAmount, 2);
      expect(lateSilver.rewarded, isTrue);
    });

    test('awards bronze for the middle 50 percent', () {
      final earlyBronze = calculator.calculate(
        validator.validateAngle(ballAngle: 0.25),
      );
      final middleBronze = calculator.calculate(
        validator.validateAngle(ballAngle: 0.50),
      );

      expect(earlyBronze.rewardTier, RunPointRewardTier.bronze);
      expect(earlyBronze.rpAmount, 1);
      expect(earlyBronze.rewarded, isTrue);
      expect(middleBronze.rewardTier, RunPointRewardTier.bronze);
      expect(middleBronze.rpAmount, 1);
      expect(middleBronze.rewarded, isTrue);
    });

    test('does not reward hits outside the safe zone center range', () {
      final reward = calculator.calculate(
        validator.validateAngle(ballAngle: 1.5),
      );

      expect(reward.rewardTier, RunPointRewardTier.none);
      expect(reward.rpAmount, 0);
      expect(reward.rewarded, isFalse);
    });

    test('does not reward edge-only safe zone contact', () {
      final edgeOnlyAngle = -validator.ballAngularRadius / 2;
      final hitResult = validator.validateAngle(ballAngle: edgeOnlyAngle);
      final reward = calculator.calculate(hitResult);

      expect(hitResult.isInsideSafeZone, isTrue);
      expect(hitResult.relativePositionInSafeZone, isNull);
      expect(reward.rewardTier, RunPointRewardTier.none);
      expect(reward.rpAmount, 0);
      expect(reward.rewarded, isFalse);
    });
  });
}
