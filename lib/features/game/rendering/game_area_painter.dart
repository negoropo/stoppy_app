import 'dart:math' as math;

import 'package:flutter/material.dart';

class GameAreaPainter extends CustomPainter {
  const GameAreaPainter({
    required this.ballProgress,
    this.safeZoneStartAngle = -math.pi / 3,
    this.safeZoneSweepAngle = math.pi / 3,
    this.targetAngle = math.pi / 4,
  });

  final double ballProgress;
  final double safeZoneStartAngle;
  final double safeZoneSweepAngle;
  final double targetAngle;

  static const double _circleStrokeWidth = 10;
  static const double _safeZoneStrokeWidth = 14;
  static const double _targetStrokeWidth = 5;
  static const double _ballRadius = 12;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius =
        math.min(size.width, size.height) / 2 -
        _safeZoneStrokeWidth -
        _ballRadius;
    final circleRect = Rect.fromCircle(center: center, radius: radius);

    final circlePaint = Paint()
      ..color = const Color(0xFF3A424C)
      ..style = PaintingStyle.stroke
      ..strokeWidth = _circleStrokeWidth
      ..strokeCap = StrokeCap.round;

    final safeZonePaint = Paint()
      ..color = const Color(0xFF39D98A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = _safeZoneStrokeWidth
      ..strokeCap = StrokeCap.round;

    final targetPaint = Paint()
      ..color = const Color(0xFFFFD166)
      ..style = PaintingStyle.stroke
      ..strokeWidth = _targetStrokeWidth
      ..strokeCap = StrokeCap.round;

    final ballPaint = Paint()
      ..color = const Color(0xFFFF6B6B)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius, circlePaint);
    canvas.drawArc(
      circleRect,
      safeZoneStartAngle,
      safeZoneSweepAngle,
      false,
      safeZonePaint,
    );

    _drawTargetMarker(canvas, center, radius, targetAngle, targetPaint);
    canvas.drawCircle(
      _pointOnCircle(center, radius, _angleFromProgress(ballProgress)),
      _ballRadius,
      ballPaint,
    );
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

  double _angleFromProgress(double progress) {
    // Flutter's canvas angle zero points to the right. Subtracting pi / 2 makes
    // progress 0 start at the top of the circle, which matches the expected
    // mental model for a clock-like competitive timing game.
    return progress * math.pi * 2 - math.pi / 2;
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
    return oldDelegate.ballProgress != ballProgress ||
        oldDelegate.safeZoneStartAngle != safeZoneStartAngle ||
        oldDelegate.safeZoneSweepAngle != safeZoneSweepAngle ||
        oldDelegate.targetAngle != targetAngle;
  }
}
