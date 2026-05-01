import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../config/game_geometry_config.dart';

class GameAreaPainter extends CustomPainter {
  const GameAreaPainter({
    required this.ballAngle,
    this.geometry = const GameGeometryConfig(),
  });

  final double ballAngle;
  final GameGeometryConfig geometry;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = geometry.circleRadiusForDimension(
      math.min(size.width, size.height),
    );
    final circleRect = Rect.fromCircle(center: center, radius: radius);

    final circlePaint = Paint()
      ..color = const Color(0xFF3A424C)
      ..style = PaintingStyle.stroke
      ..strokeWidth = geometry.circleStrokeWidth
      ..strokeCap = StrokeCap.round;

    final targetPaint = Paint()
      ..color = const Color(0xFFFFD166)
      ..style = PaintingStyle.stroke
      ..strokeWidth = geometry.targetStrokeWidth
      ..strokeCap = StrokeCap.round;

    final ballPaint = Paint()
      ..color = const Color(0xFFFF6B6B)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius, circlePaint);
    _drawSafeZoneRewardSegments(canvas, circleRect);

    _drawTargetMarker(
      canvas,
      center,
      radius,
      geometry.targetAngle,
      targetPaint,
    );
    canvas.drawCircle(
      _pointOnCircle(center, radius, ballAngle),
      geometry.ballRadius,
      ballPaint,
    );
  }

  void _drawSafeZoneRewardSegments(Canvas canvas, Rect circleRect) {
    const segments = [
      _RewardZoneVisualSegment(percentage: 0.10, color: Color(0xFFFFD166)),
      _RewardZoneVisualSegment(percentage: 0.15, color: Color(0xFFC9D1D9)),
      _RewardZoneVisualSegment(percentage: 0.50, color: Color(0xFFB86B35)),
      _RewardZoneVisualSegment(percentage: 0.15, color: Color(0xFFC9D1D9)),
      _RewardZoneVisualSegment(percentage: 0.10, color: Color(0xFFFFD166)),
    ];

    var segmentStartAngle = geometry.safeZoneStartAngle;

    for (final segment in segments) {
      final segmentSweepAngle =
          geometry.safeZoneSweepAngle * segment.percentage;
      final segmentPaint = Paint()
        ..color = segment.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = geometry.safeZoneStrokeWidth
        ..strokeCap = StrokeCap.butt;

      // Each visual segment uses the same percentages as RP tiers. This is
      // rendering only; collision and RP calculation remain in engine classes.
      canvas.drawArc(
        circleRect,
        segmentStartAngle,
        segmentSweepAngle,
        false,
        segmentPaint,
      );

      segmentStartAngle += segmentSweepAngle;
    }
  }

  void _drawTargetMarker(
    Canvas canvas,
    Offset center,
    double radius,
    double angle,
    Paint paint,
  ) {
    const markerHalfLength = 18.0;
    final innerPoint = _pointOnCircle(center, radius - markerHalfLength, angle);
    final outerPoint = _pointOnCircle(center, radius + markerHalfLength, angle);

    canvas.drawLine(innerPoint, outerPoint, paint);
  }

  Offset _pointOnCircle(Offset center, double radius, double angle) {
    // Convert polar coordinates into canvas coordinates. This keeps all moving
    // elements on the same deterministic circle path as future engine logic.
    return Offset(
      center.dx + math.cos(angle) * radius,
      center.dy + math.sin(angle) * radius,
    );
  }

  @override
  bool shouldRepaint(covariant GameAreaPainter oldDelegate) {
    return oldDelegate.ballAngle != ballAngle ||
        oldDelegate.geometry != geometry;
  }
}

class _RewardZoneVisualSegment {
  const _RewardZoneVisualSegment({
    required this.percentage,
    required this.color,
  });

  final double percentage;
  final Color color;
}
