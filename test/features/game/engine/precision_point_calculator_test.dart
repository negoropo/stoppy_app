import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:stoppy_app/features/game/engine/precision_point_calculator.dart';

void main() {
  group('PrecisionPointCalculator', () {
    const calculator = PrecisionPointCalculator();

    test('awards the current tier max for a perfect target match', () {
      final result = calculator.calculate(
        ballAngle: 1,
        targetAngle: 1,
        didAdvanceLevel: true,
        tierLevel: 6,
        tierMaxPrecisionPoints: 1000,
      );

      expect(result.awardedPP, 1000);
      expect(result.tierLevel, 6);
      expect(result.tierMaxPrecisionPoints, 1000);
      expect(result.angularDistance, 0);
      expect(result.normalizedPrecision, 1);
    });

    test('awards 1 PP for the farthest valid circular distance', () {
      final result = calculator.calculate(
        ballAngle: 0,
        targetAngle: math.pi,
        didAdvanceLevel: true,
        tierLevel: 1,
        tierMaxPrecisionPoints: 100,
      );

      expect(result.awardedPP, 1);
      expect(result.angularDistance, closeTo(math.pi, 0.0001));
      expect(result.normalizedPrecision, 0);
    });

    test('uses shortest circular distance across the zero boundary', () {
      final result = calculator.calculate(
        ballAngle: math.pi * 1.95,
        targetAngle: math.pi * 0.05,
        didAdvanceLevel: true,
        tierLevel: 6,
        tierMaxPrecisionPoints: 1000,
      );

      expect(result.angularDistance, closeTo(math.pi * 0.1, 0.0001));
      expect(result.awardedPP, 900);
    });

    test('awards 0 PP when the level did not advance', () {
      final result = calculator.calculate(
        ballAngle: 0,
        targetAngle: 0,
        didAdvanceLevel: false,
        tierLevel: 1,
        tierMaxPrecisionPoints: 100,
      );

      expect(result.awardedPP, 0);
      expect(result.angularDistance, 0);
      expect(result.normalizedPrecision, 0);
    });
  });
}
