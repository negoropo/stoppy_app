import 'dart:math' as math;

class GameGeometryConfig {
  const GameGeometryConfig({
    this.safeZoneStartAngle = -math.pi / 3,
    this.safeZoneSweepAngle = math.pi / 3,
    this.targetAngle = math.pi / 4,
    this.targetToleranceAngle = 0.08,
    this.circleStrokeWidth = 10,
    this.safeZoneStrokeWidth = 14,
    this.targetStrokeWidth = 5,
    this.ballRadius = 12,
  });

  final double safeZoneStartAngle;
  final double safeZoneSweepAngle;
  final double targetAngle;
  final double targetToleranceAngle;
  final double circleStrokeWidth;
  final double safeZoneStrokeWidth;
  final double targetStrokeWidth;
  final double ballRadius;

  double circleRadiusForDimension(double dimension) {
    return dimension / 2 - safeZoneStrokeWidth - ballRadius;
  }
}
