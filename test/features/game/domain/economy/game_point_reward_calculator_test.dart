import 'package:flutter_test/flutter_test.dart';
import 'package:stoppy_app/features/game/domain/economy/game_point_reward_calculator.dart';
import 'package:stoppy_app/features/game/domain/economy/run_mode.dart';

void main() {
  group('GamePointRewardCalculator', () {
    const calculator = GamePointRewardCalculator();
    final runEndedAt = DateTime(2026, 5, 4, 18, 30);

    test('league completed run grants 1 completion GP', () {
      final result = calculator.calculate(
        runMode: RunMode.league,
        totalPrecisionPoints: 0,
        runEndedAt: runEndedAt,
        lastDailyGpAwardedAt: runEndedAt,
      );

      expect(result.completionGp, 1);
    });

    test('tournament completed run grants 1 completion GP', () {
      final result = calculator.calculate(
        runMode: RunMode.tournament,
        totalPrecisionPoints: 0,
        runEndedAt: runEndedAt,
        lastDailyGpAwardedAt: runEndedAt,
      );

      expect(result.completionGp, 1);
    });

    test('warmup completed run with 9999 PP grants 0 completion GP', () {
      final result = calculator.calculate(
        runMode: RunMode.warmup,
        totalPrecisionPoints: 9999,
        runEndedAt: runEndedAt,
        lastDailyGpAwardedAt: runEndedAt,
      );

      expect(result.completionGp, 0);
      expect(result.warmupThresholdReached, isFalse);
    });

    test('warmup completed run with 10000 PP grants 1 completion GP', () {
      final result = calculator.calculate(
        runMode: RunMode.warmup,
        totalPrecisionPoints: 10000,
        runEndedAt: runEndedAt,
        lastDailyGpAwardedAt: runEndedAt,
      );

      expect(result.completionGp, 1);
      expect(result.warmupThresholdReached, isTrue);
    });

    test(
      'warmup completed run with more than 10000 PP grants 1 completion GP',
      () {
        final result = calculator.calculate(
          runMode: RunMode.warmup,
          totalPrecisionPoints: 10001,
          runEndedAt: runEndedAt,
          lastDailyGpAwardedAt: runEndedAt,
        );

        expect(result.completionGp, 1);
        expect(result.warmupThresholdReached, isTrue);
      },
    );

    test('daily GP grants 2 on first completed run of a calendar day', () {
      final result = calculator.calculate(
        runMode: RunMode.league,
        totalPrecisionPoints: 0,
        runEndedAt: runEndedAt,
        lastDailyGpAwardedAt: null,
      );

      expect(result.dailyGp, 2);
      expect(result.dailyGpAwarded, isTrue);
      expect(result.totalGp, 3);
    });

    test('daily GP does not grant again on the same calendar day', () {
      final result = calculator.calculate(
        runMode: RunMode.league,
        totalPrecisionPoints: 0,
        runEndedAt: DateTime(2026, 5, 4, 22),
        lastDailyGpAwardedAt: DateTime(2026, 5, 4, 9),
      );

      expect(result.dailyGp, 0);
      expect(result.dailyGpAwarded, isFalse);
      expect(result.totalGp, 1);
    });

    test('daily GP grants again on a different calendar day', () {
      final result = calculator.calculate(
        runMode: RunMode.league,
        totalPrecisionPoints: 0,
        runEndedAt: DateTime(2026, 5, 5),
        lastDailyGpAwardedAt: DateTime(2026, 5, 4, 23, 59),
      );

      expect(result.dailyGp, 2);
      expect(result.dailyGpAwarded, isTrue);
    });

    test('warmup with threshold and first run of day grants 3 total GP', () {
      final result = calculator.calculate(
        runMode: RunMode.warmup,
        totalPrecisionPoints: 10000,
        runEndedAt: runEndedAt,
        lastDailyGpAwardedAt: null,
      );

      expect(result.completionGp, 1);
      expect(result.dailyGp, 2);
      expect(result.totalGp, 3);
    });

    test('daily GP uses run end time calendar day', () {
      final result = calculator.calculate(
        runMode: RunMode.league,
        totalPrecisionPoints: 0,
        runEndedAt: DateTime(2026, 5, 5, 0, 1),
        lastDailyGpAwardedAt: DateTime(2026, 5, 4, 23, 59),
      );

      expect(result.dailyGp, 2);
      expect(result.dailyGpAwarded, isTrue);
    });
  });
}
