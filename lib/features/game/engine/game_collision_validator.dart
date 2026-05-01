import 'dart:math' as math;

import 'hit_validation_result.dart';

class GameCollisionValidator {
  const GameCollisionValidator({
    required this.circleRadius,
    required this.ballRadius,
    this.safeZoneStartAngle = -math.pi / 3,
    this.safeZoneSweepAngle = math.pi / 3,
    this.targetAngle = math.pi / 4,
    this.targetToleranceAngle = 0.08,
  });

  static const double fullCircleRadians = math.pi * 2;

  final double circleRadius;
  final double ballRadius;
  final double safeZoneStartAngle;
  final double safeZoneSweepAngle;
  final double targetAngle;
  final double targetToleranceAngle;

  double get ballAngularRadius {
    final radiusRatio = math.min(1.0, math.max(0, ballRadius / circleRadius));

    // The game validates contact at the ball edge, not only at the center.
    // asin(opposite / hypotenuse) converts the visible ball radius into the
    // angular coverage it occupies along the gameplay circle.
    return math.asin(radiusRatio);
  }

  HitValidationResult validateProgress({required double ballProgress}) {
    return validateAngle(ballAngle: angleFromProgress(ballProgress));
  }

  HitValidationResult validateAngle({required double ballAngle}) {
    final normalizedBallAngle = normalizeAngle(ballAngle);
    final edgeContactAngle = ballAngularRadius;
    final targetDistance = angularDistance(normalizedBallAngle, targetAngle);

    return HitValidationResult(
      ballAngle: normalizedBallAngle,
      ballStartAngle: normalizeAngle(normalizedBallAngle - edgeContactAngle),
      ballEndAngle: normalizeAngle(normalizedBallAngle + edgeContactAngle),
      ballAngularRadius: edgeContactAngle,
      isInsideSafeZone: isAngleInsideSafeZone(normalizedBallAngle),
      // Target validation also expands the marker tolerance by the ball angular
      // radius. That means edge contact counts even when the ball center has
      // not reached the target marker itself.
      isTargetHit: targetDistance <= targetToleranceAngle + edgeContactAngle,
      targetAngularDistance: targetDistance,
      relativePositionInSafeZone: relativePositionInSafeZone(
        normalizedBallAngle,
      ),
    );
  }

  static double normalizeAngle(double angle) {
    final normalized = angle % fullCircleRadians;
    return normalized < 0 ? normalized + fullCircleRadians : normalized;
  }

  bool isAngleInsideSafeZone(double angle) {
    final edgeContactAngle = ballAngularRadius;

    // Expanding both ends of the safe zone lets a ball count as valid when any
    // visible part overlaps the arc, even if the ball center is just outside it.
    final expandedStartAngle = safeZoneSweepAngle >= 0
        ? safeZoneStartAngle - edgeContactAngle
        : safeZoneStartAngle + edgeContactAngle;
    final expandedSweepAngle = safeZoneSweepAngle >= 0
        ? safeZoneSweepAngle + edgeContactAngle * 2
        : safeZoneSweepAngle - edgeContactAngle * 2;

    return isAngleInsideArc(
      angle: angle,
      startAngle: expandedStartAngle,
      sweepAngle: expandedSweepAngle,
    );
  }

  double? relativePositionInSafeZone(double angle) {
    // RP uses the ball center only. This intentionally checks the original
    // safe-zone arc, not the ball-radius-expanded collision arc.
    return relativePositionInArc(
      angle: angle,
      startAngle: safeZoneStartAngle,
      sweepAngle: safeZoneSweepAngle,
    );
  }

  double? relativePositionInArc({
    required double angle,
    required double startAngle,
    required double sweepAngle,
  }) {
    final normalizedSweep = sweepAngle.abs();

    if (normalizedSweep == 0) {
      return null;
    }

    if (normalizedSweep >= fullCircleRadians) {
      return 0;
    }

    final normalizedAngle = normalizeAngle(angle);
    final normalizedStart = normalizeAngle(startAngle);
    final distanceFromStart = sweepAngle >= 0
        ? _clockwiseDistance(normalizedStart, normalizedAngle)
        : _clockwiseDistance(normalizedAngle, normalizedStart);

    if (distanceFromStart > normalizedSweep) {
      return null;
    }

    return distanceFromStart / normalizedSweep;
  }

  bool isAngleInsideArc({
    required double angle,
    required double startAngle,
    required double sweepAngle,
  }) {
    final normalizedSweep = sweepAngle.abs();

    if (normalizedSweep >= fullCircleRadians) {
      return true;
    }

    final normalizedAngle = normalizeAngle(angle);
    final normalizedStart = sweepAngle >= 0
        ? normalizeAngle(startAngle)
        : normalizeAngle(startAngle + sweepAngle);
    final normalizedEnd = normalizeAngle(normalizedStart + normalizedSweep);

    // Arcs can cross the 0-radian boundary. In that case the valid range is
    // split across the end and start of the normalized circle.
    if (normalizedStart <= normalizedEnd) {
      return normalizedAngle >= normalizedStart &&
          normalizedAngle <= normalizedEnd;
    }

    return normalizedAngle >= normalizedStart ||
        normalizedAngle <= normalizedEnd;
  }

  double angularDistance(double firstAngle, double secondAngle) {
    final distance = (normalizeAngle(firstAngle) - normalizeAngle(secondAngle))
        .abs();

    // The shortest path between two points on a circle may cross the 0-radian
    // boundary, so distances larger than half a circle must wrap backward.
    return math.min(distance, fullCircleRadians - distance);
  }

  static double _clockwiseDistance(double startAngle, double endAngle) {
    return normalizeAngle(endAngle - startAngle);
  }

  double angleFromProgress(double progress) {
    // Progress is a normalized 0..1 animation value. Offsetting by pi / 2 keeps
    // progress 0 at the top of the circle, matching the renderer's ball path.
    return normalizeAngle(progress * fullCircleRadians - math.pi / 2);
  }
}
