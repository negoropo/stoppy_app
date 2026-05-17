import 'dart:math' as math;

import 'precision_point_result.dart';

class PrecisionPointCalculator {
  const PrecisionPointCalculator();

  static const double fullCircleRadians = math.pi * 2;
  PrecisionPointResult calculate({
    required double ballAngle,
    required double targetAngle,
    required bool didAdvanceLevel,
    required int tierLevel,
    required int tierMaxPrecisionPoints,
  }) {
    assert(tierLevel >= 1);
    assert(tierMaxPrecisionPoints > 0);

    if (!didAdvanceLevel) {
      return PrecisionPointResult(
        awardedPP: 0,
        tierLevel: tierLevel,
        tierMaxPrecisionPoints: tierMaxPrecisionPoints,
        angularDistance: 0,
        normalizedPrecision: 0,
      );
    }

    final angularDistance = circularAngularDistance(ballAngle, targetAngle);

    // The farthest shortest path between two points on a circle is half a
    // circle. A full circle is 2*pi radians, so pi is the maximum distance used
    // to normalize precision.
    final clampedDistance = angularDistance.clamp(0.0, math.pi);
    final normalizedPrecision = 1 - (clampedDistance / math.pi);

    return PrecisionPointResult(
      // Every successful level awards at least 1 PP, while a perfect target
      // center match awards the full ceiling for the current authored tier.
      awardedPP:
          (normalizedPrecision * (tierMaxPrecisionPoints - 1)).round() + 1,
      tierLevel: tierLevel,
      tierMaxPrecisionPoints: tierMaxPrecisionPoints,
      angularDistance: clampedDistance,
      normalizedPrecision: normalizedPrecision,
    );
  }

  double circularAngularDistance(double firstAngle, double secondAngle) {
    final rawDistance =
        (normalizeAngle(firstAngle) - normalizeAngle(secondAngle)).abs();

    // Angles wrap around 0/2*pi, so the shortest distance may cross that
    // boundary instead of following the direct numeric difference.
    return math.min(rawDistance, fullCircleRadians - rawDistance);
  }

  double normalizeAngle(double angle) {
    final normalized = angle % fullCircleRadians;
    return normalized < 0 ? normalized + fullCircleRadians : normalized;
  }
}
