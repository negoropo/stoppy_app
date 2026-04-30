import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'config/game_geometry_config.dart';
import 'engine/game_collision_validator.dart';
import 'engine/hit_validation_result.dart';
import 'rendering/game_area_painter.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin {
  static const Duration _feedbackDuration = Duration(milliseconds: 900);
  static const GameGeometryConfig _geometry = GameGeometryConfig();
  static const double _gameAreaPadding = 24;

  late final AnimationController _ballController;

  HitValidationResult? _lastHitResult;
  Timer? _feedbackTimer;

  @override
  void initState() {
    super.initState();
    _ballController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _feedbackTimer?.cancel();
    _ballController.dispose();
    super.dispose();
  }

  void _validateCurrentBallPosition(double circleRadius) {
    final validator = GameCollisionValidator(
      circleRadius: circleRadius,
      ballRadius: _geometry.ballRadius,
      safeZoneStartAngle: _geometry.safeZoneStartAngle,
      safeZoneSweepAngle: _geometry.safeZoneSweepAngle,
      targetAngle: _geometry.targetAngle,
      targetToleranceAngle: _geometry.targetToleranceAngle,
    );
    final result = validator.validateProgress(
      ballProgress: _ballController.value,
    );

    setState(() {
      _lastHitResult = result;
    });

    _feedbackTimer?.cancel();
    _feedbackTimer = Timer(_feedbackDuration, () {
      if (!mounted) {
        return;
      }

      setState(() {
        _lastHitResult = null;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF101418),
      body: SafeArea(
        child: Center(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final availableDimension = math.min(
                constraints.maxWidth,
                constraints.maxHeight,
              );
              final paintDimension =
                  availableDimension - _gameAreaPadding * 2;
              final circleRadius = _geometry.circleRadiusForDimension(
                paintDimension,
              );

              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _validateCurrentBallPosition(circleRadius),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox.square(
                      dimension: availableDimension,
                      child: Padding(
                        padding: EdgeInsets.all(_gameAreaPadding),
                        child: AnimatedBuilder(
                          animation: _ballController,
                          builder: (context, child) {
                            return CustomPaint(
                              painter: GameAreaPainter(
                                ballProgress: _ballController.value,
                                geometry: _geometry,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    if (_lastHitResult != null)
                      _DebugHitFeedback(result: _lastHitResult!),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _DebugHitFeedback extends StatelessWidget {
  const _DebugHitFeedback({required this.result});

  final HitValidationResult result;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xCC101418),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF3A424C)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              result.isInsideSafeZone ? 'HIT SAFE ZONE' : 'MISS SAFE ZONE',
              style: _feedbackTextStyle(
                result.isInsideSafeZone
                    ? const Color(0xFF39D98A)
                    : const Color(0xFFFF6B6B),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              result.isTargetHit ? 'TARGET HIT' : 'TARGET MISS',
              style: _feedbackTextStyle(
                result.isTargetHit
                    ? const Color(0xFFFFD166)
                    : const Color(0xFFD6DEE8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  TextStyle _feedbackTextStyle(Color color) {
    return TextStyle(
      color: color,
      fontSize: 16,
      fontWeight: FontWeight.w700,
      letterSpacing: 0,
    );
  }
}
