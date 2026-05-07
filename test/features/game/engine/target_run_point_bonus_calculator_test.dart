import 'package:flutter_test/flutter_test.dart';
import 'package:stoppy_app/features/game/engine/target_run_point_bonus_calculator.dart';

void main() {
  group('TargetRunPointBonusCalculator', () {
    const calculator = TargetRunPointBonusCalculator();

    test('does not award target bonus when target was not hit', () {
      final result = calculator.calculate(
        isTargetHit: false,
        basePrecisionPoints: 1000,
      );

      expect(result.rpAmount, 0);
      expect(result.message, isNull);
    });

    test('awards 10 RP for a perfect target hit', () {
      final result = calculator.calculate(
        isTargetHit: true,
        basePrecisionPoints: 1000,
      );

      expect(result.rpAmount, 10);
      expect(
        result.message,
        'Perfect hit! You stopped the center of the ball exactly on the '
        'target and earned +10 RP.',
      );
    });

    test('awards 5 RP for extremely close target hits', () {
      for (final basePrecisionPoints in [997, 998, 999]) {
        final result = calculator.calculate(
          isTargetHit: true,
          basePrecisionPoints: basePrecisionPoints,
        );

        expect(result.rpAmount, 5);
        expect(
          result.message,
          'So close! You were extremely close to a perfect target hit and '
          'earned +5 RP.',
        );
      }
    });

    test('awards 3 RP for close target hits', () {
      for (final basePrecisionPoints in [990, 993, 996]) {
        final result = calculator.calculate(
          isTargetHit: true,
          basePrecisionPoints: basePrecisionPoints,
        );

        expect(result.rpAmount, 3);
        expect(
          result.message,
          'Great shot! You were close to a perfect target hit and earned '
          '+3 RP.',
        );
      }
    });

    test('awards 2 RP for lower-precision target hits', () {
      final result = calculator.calculate(
        isTargetHit: true,
        basePrecisionPoints: 989,
      );

      expect(result.rpAmount, 2);
      expect(result.message, 'Target hit! You earned +2 RP.');
    });
  });
}
