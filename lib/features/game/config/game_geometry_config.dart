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

  GameGeometryConfig copyWith({
    double? safeZoneStartAngle,
    double? safeZoneSweepAngle,
    double? targetAngle,
    double? targetToleranceAngle,
    double? circleStrokeWidth,
    double? safeZoneStrokeWidth,
    double? targetStrokeWidth,
    double? ballRadius,
  }) {
    return GameGeometryConfig(
      safeZoneStartAngle: safeZoneStartAngle ?? this.safeZoneStartAngle,
      safeZoneSweepAngle: safeZoneSweepAngle ?? this.safeZoneSweepAngle,
      targetAngle: targetAngle ?? this.targetAngle,
      targetToleranceAngle: targetToleranceAngle ?? this.targetToleranceAngle,
      circleStrokeWidth: circleStrokeWidth ?? this.circleStrokeWidth,
      safeZoneStrokeWidth: safeZoneStrokeWidth ?? this.safeZoneStrokeWidth,
      targetStrokeWidth: targetStrokeWidth ?? this.targetStrokeWidth,
      ballRadius: ballRadius ?? this.ballRadius,
    );
  }

  double circleRadiusForDimension(double dimension) {
    return dimension / 2 - safeZoneStrokeWidth - ballRadius;
  }
}
