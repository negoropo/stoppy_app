import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'config/game_geometry_config.dart';
import 'domain/level_generator.dart';
import 'domain/models/difficulty_state.dart';
import 'domain/models/game_level_config.dart';
import 'engine/game_collision_validator.dart';
import 'engine/hit_validation_result.dart';
import 'engine/game_motion_calculator.dart';
import 'rendering/game_area_painter.dart';
import 'package:stoppy_app/core/constants/debug_constants.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  static const Duration _feedbackDuration = Duration(milliseconds: 900);
  static const GameGeometryConfig _baseGeometry = GameGeometryConfig();
  static const double _gameAreaPadding = 24;
  static const GameMotionCalculator _motionCalculator = GameMotionCalculator();

  late final LevelGenerator _levelGenerator;
  late DifficultyState _difficultyState;
  late GameLevelConfig _levelConfig;
  late GameGeometryConfig _geometry;
  late final AnimationController _ballController;
  AnimationController? _safeZoneController;
  AnimationController? _targetController;

  HitValidationResult? _lastHitResult;
  DifficultyVariable? _lastIncreasedVariable;
  Timer? _feedbackTimer;

  @override
  void initState() {
    super.initState();
    _levelGenerator = LevelGenerator();
    _difficultyState = _levelGenerator.createInitialDifficultyState();
    _levelConfig = _levelGenerator.generateLevelConfig(_difficultyState);
    _geometry = _geometryForLevelConfig(_levelConfig);
    _ballController = AnimationController(
      vsync: this,
      duration: _levelConfig.ballRotationDuration,
    )..repeat();
    _safeZoneController = _createRepeatingController(
      _levelConfig.safeZoneRotationDuration,
    );
    _targetController = _createRepeatingController(
      _levelConfig.targetRotationDuration,
    );
  }

  @override
  void dispose() {
    _feedbackTimer?.cancel();
    _ballController.dispose();
    _safeZoneController?.dispose();
    _targetController?.dispose();
    super.dispose();
  }

  AnimationController? _createRepeatingController(Duration? duration) {
    if (duration == null || duration == Duration.zero) {
      return null;
    }

    return AnimationController(vsync: this, duration: duration)..repeat();
  }

  void _replaceOptionalController({
    required AnimationController? currentController,
    required Duration? duration,
    required ValueSetter<AnimationController?> updateController,
  }) {
    currentController?.dispose();
    updateController(_createRepeatingController(duration));
  }

  double _currentBallAngle() {
    return _motionCalculator.movingAngle(
      startAngle: _levelConfig.ballStartAngle,
      progress: _ballController.value,
      direction: _levelConfig.ballDirection,
    );
  }

  double _currentSafeZoneStartAngle() {
    return _motionCalculator.movingAngle(
      startAngle: _levelConfig.safeZoneStartAngle,
      progress: _safeZoneController?.value ?? 0,
      direction: _levelConfig.safeZoneDirection,
    );
  }

  double _currentTargetAngle() {
    return _motionCalculator.movingAngle(
      startAngle: _levelConfig.targetStartAngle,
      progress: _targetController?.value ?? 0,
      direction: _levelConfig.targetDirection,
    );
  }

  GameGeometryConfig _geometryForLevelConfig(GameLevelConfig levelConfig) {
    return _baseGeometry.copyWith(
      ballRadius: levelConfig.ballRadius,
      safeZoneSweepAngle: levelConfig.safeZoneSweepAngle,
      safeZoneStartAngle: _currentSafeZoneStartAngle(),
      targetAngle: _currentTargetAngle(),
    );
  }

  void _validateCurrentBallPosition(double circleRadius) {
    final validator = GameCollisionValidator(
      circleRadius: circleRadius,
      ballRadius: _geometry.ballRadius,
      safeZoneStartAngle: _currentSafeZoneStartAngle(),
      safeZoneSweepAngle: _geometry.safeZoneSweepAngle,
      targetAngle: _currentTargetAngle(),
      targetToleranceAngle: _geometry.targetToleranceAngle,
    );
    final result = validator.validateAngle(ballAngle: _currentBallAngle());

    setState(() {
      _lastHitResult = result;

      if (_isLevelSuccess(result)) {
        _advanceToNextDebugLevel();
      }
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

  bool _isLevelSuccess(HitValidationResult result) {
    return result.isInsideSafeZone || result.isTargetHit;
  }

  void _advanceToNextDebugLevel() {
    final advanceResult = _levelGenerator.advanceDifficulty(_difficultyState);
    final nextLevelConfig = _levelGenerator.generateLevelConfig(
      advanceResult.difficultyState,
    );

    _difficultyState = advanceResult.difficultyState;
    _lastIncreasedVariable = advanceResult.increasedVariable;
    _levelConfig = nextLevelConfig;
    _ballController.duration = nextLevelConfig.ballRotationDuration;
    _ballController
      ..reset()
      ..repeat();
    _replaceOptionalController(
      currentController: _safeZoneController,
      duration: nextLevelConfig.safeZoneRotationDuration,
      updateController: (controller) {
        _safeZoneController = controller;
      },
    );
    _replaceOptionalController(
      currentController: _targetController,
      duration: nextLevelConfig.targetRotationDuration,
      updateController: (controller) {
        _targetController = controller;
      },
    );
    _geometry = _geometryForLevelConfig(nextLevelConfig);
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
              final paintDimension = availableDimension - _gameAreaPadding * 2;
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
                          animation: Listenable.merge([
                            _ballController,
                            ?_safeZoneController,
                            ?_targetController,
                          ]),
                          builder: (context, child) {
                            final animatedGeometry = _geometry.copyWith(
                              safeZoneStartAngle: _currentSafeZoneStartAngle(),
                              targetAngle: _currentTargetAngle(),
                            );

                            return CustomPaint(
                              painter: GameAreaPainter(
                                ballAngle: _currentBallAngle(),
                                geometry: animatedGeometry,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    if (_lastHitResult != null)
                      _DebugHitFeedback(result: _lastHitResult!),
                    if (kShowDebugOverlay)
                    Positioned(
                      top: 16,
                      left: 16,
                      child: IgnorePointer(
                        child: _DebugDifficultyOverlay(
                          difficultyState: _difficultyState,
                          lastIncreasedVariable: _lastIncreasedVariable,
                        ),
                      ),
                    ),
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

class _DebugDifficultyOverlay extends StatelessWidget {
  const _DebugDifficultyOverlay({
    required this.difficultyState,
    required this.lastIncreasedVariable,
  });

  final DifficultyState difficultyState;
  final DifficultyVariable? lastIncreasedVariable;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xCC101418),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF3A424C)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: DefaultTextStyle(
          style: const TextStyle(
            color: Color(0xFFD6DEE8),
            fontSize: 11,
            height: 1.25,
            letterSpacing: 0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'DEBUG ONLY - Difficulty',
                style: TextStyle(
                  color: Color(0xFFFFD166),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text('ballSpeedLevel: ${difficultyState.ballSpeedLevel}'),
              Text('ballSizeLevel: ${difficultyState.ballSizeLevel}'),
              Text('stopTimeLevel: ${difficultyState.stopTimeLevel}'),
              Text('safeZoneSizeLevel: ${difficultyState.safeZoneSizeLevel}'),
              Text('safeZoneSpeedLevel: ${difficultyState.safeZoneSpeedLevel}'),
              Text('targetSpeedLevel: ${difficultyState.targetSpeedLevel}'),
              const SizedBox(height: 6),
              Text(
                'last increased: '
                '${lastIncreasedVariable?.debugLabel ?? 'none'}',
              ),
            ],
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
