import 'dart:math' as math;

import 'precision_point_result.dart';

class PrecisionPointCalculator {
  const PrecisionPointCalculator();

  static const double fullCircleRadians = math.pi * 2;
  static const int maxPrecisionPoints = 1000;

  PrecisionPointResult calculate({
    required double ballAngle,
    required double targetAngle,
    required bool didAdvanceLevel,
  }) {
    if (!didAdvanceLevel) {
      return const PrecisionPointResult(
        awardedPP: 0,
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
      awardedPP: (normalizedPrecision * (maxPrecisionPoints - 1)).round() + 1,
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
