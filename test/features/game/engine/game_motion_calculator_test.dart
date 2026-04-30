import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:stoppy_app/features/game/domain/models/movement_direction.dart';
import 'package:stoppy_app/features/game/engine/game_motion_calculator.dart';

void main() {
  group('GameMotionCalculator', () {
    const calculator = GameMotionCalculator();

    test('uses the configured start angle at progress zero', () {
      expect(
        calculator.movingAngle(
          startAngle: 1.2,
          progress: 0,
          direction: MovementDirection.clockwise,
        ),
        closeTo(1.2, 0),
      );
    });

    test('moves clockwise as progress increases', () {
      expect(
        calculator.movingAngle(
          startAngle: 1,
          progress: 0.25,
          direction: MovementDirection.clockwise,
        ),
        closeTo(1 + math.pi / 2, 0.0001),
      );
    });

    test('moves counter-clockwise as progress increases', () {
      expect(
        calculator.movingAngle(
          startAngle: 1,
          progress: 0.25,
          direction: MovementDirection.counterClockwise,
        ),
        closeTo(math.pi * 2 + 1 - math.pi / 2, 0.0001),
      );
    });
  });
}
