import 'dart:math' as math;

import '../domain/models/movement_direction.dart';
import 'game_collision_validator.dart';

class GameMotionCalculator {
  const GameMotionCalculator();

  double movingAngle({
    required double startAngle,
    required double progress,
    required MovementDirection direction,
  }) {
    // Animation progress always increases from 0 to 1. Direction is applied by
    // changing the sign of that progress before converting it into a full turn.
    final signedProgress = switch (direction) {
      MovementDirection.clockwise => progress,
      MovementDirection.counterClockwise => -progress,
    };

    return GameCollisionValidator.normalizeAngle(
      startAngle + signedProgress * math.pi * 2,
    );
  }
}
