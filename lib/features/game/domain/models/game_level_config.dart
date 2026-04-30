import 'movement_direction.dart';

class GameLevelConfig {
  const GameLevelConfig({
    required this.ballRotationDuration,
    required this.ballRadius,
    required this.stopTimeLimit,
    required this.safeZoneSweepAngle,
    required this.safeZoneRotationDuration,
    required this.targetRotationDuration,
    required this.ballStartAngle,
    required this.safeZoneStartAngle,
    required this.targetStartAngle,
    required this.ballDirection,
  });

  final Duration ballRotationDuration;
  final double ballRadius;
  final Duration stopTimeLimit;
  final double safeZoneSweepAngle;
  final Duration? safeZoneRotationDuration;
  final Duration? targetRotationDuration;
  final double ballStartAngle;
  final double safeZoneStartAngle;
  final double targetStartAngle;
  final MovementDirection ballDirection;

  MovementDirection get safeZoneDirection {
    return oppositeMovementDirection(ballDirection);
  }

  MovementDirection get targetDirection {
    return oppositeMovementDirection(ballDirection);
  }
}
