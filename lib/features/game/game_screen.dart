import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'config/game_geometry_config.dart';
import 'package:stoppy_app/core/constants/debug_constants.dart';
import 'package:stoppy_app/features/auth/domain/models/player_profile.dart';
import 'package:stoppy_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:stoppy_app/features/purchases/domain/repositories/purchase_repository.dart';
import 'package:stoppy_app/features/purchases/presentation/screens/store_screen.dart';
import 'domain/economy/game_point_reward_calculator.dart';
import 'domain/economy/game_point_reward_result.dart';
import 'domain/economy/run_mode.dart';
import 'domain/economy/warmup_availability_policy.dart';
import 'domain/level_generator.dart';
import 'domain/models/difficulty_state.dart';
import 'domain/models/game_level_config.dart';
import 'domain/models/reward_menu_action.dart';
import 'engine/game_collision_validator.dart';
import 'engine/game_motion_calculator.dart';
import 'engine/hit_validation_result.dart';
import 'engine/precision_point_calculator.dart';
import 'engine/precision_point_result.dart';
import 'engine/run_point_reward_calculator.dart';
import 'engine/run_point_reward_result.dart';
import 'engine/run_point_reward_tier.dart';
import 'rendering/game_area_painter.dart';
import 'widgets/post_hit_reward_overlay.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({
    super.key,
    this.levelGenerator,
    this.initialDifficultyState,
    this.initialLevelConfig,
    this.playerProfile,
    this.authRepository,
    this.purchaseRepository,
    this.initialRunMode,
    this.now,
  });

  final LevelGenerator? levelGenerator;
  final DifficultyState? initialDifficultyState;
  final GameLevelConfig? initialLevelConfig;
  final PlayerProfile? playerProfile;
  final AuthRepository? authRepository;
  final PurchaseRepository? purchaseRepository;
  final RunMode? initialRunMode;
  final DateTime Function()? now;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  static const Duration _feedbackDuration = Duration(milliseconds: 900);
  static const Duration _maximumRunDuration = Duration(hours: 1);
  static const GameGeometryConfig _baseGeometry = GameGeometryConfig();
  static const double _gameAreaPadding = 24;
  static const int _targetOutsideSafeZoneRpReward = 0;
  static const GameMotionCalculator _motionCalculator = GameMotionCalculator();
  static const RunPointRewardCalculator _rpRewardCalculator =
      RunPointRewardCalculator();
  static const PrecisionPointCalculator _precisionPointCalculator =
      PrecisionPointCalculator();
  static const GamePointRewardCalculator _gpRewardCalculator =
      GamePointRewardCalculator();
  static const WarmupAvailabilityPolicy _warmupAvailabilityPolicy =
      WarmupAvailabilityPolicy();
  static const RunPointRewardResult _noRpRewardResult = RunPointRewardResult(
    rewardTier: RunPointRewardTier.none,
    rpAmount: 0,
    rewarded: false,
  );
  static const RunPointRewardResult _targetOutsideSafeZoneRewardResult =
      RunPointRewardResult(
        rewardTier: RunPointRewardTier.none,
        rpAmount: _targetOutsideSafeZoneRpReward,
        rewarded: false,
      );

  late final LevelGenerator _levelGenerator;
  late DifficultyState _difficultyState;
  late GameLevelConfig _levelConfig;
  late GameGeometryConfig _geometry;
  late RunMode _runMode;
  late final AnimationController _ballController;
  AnimationController? _safeZoneController;
  AnimationController? _targetController;

  HitValidationResult? _lastHitResult;
  RunPointRewardResult? _lastRpRewardResult;
  PrecisionPointResult? _pendingPrecisionPointResult;
  DifficultyVariable? _lastChangedVariable;
  bool _lastChangeWasIncrease = true;
  int _totalRunPoints = 0;
  int _totalPrecisionPoints = 0;
  int _lives = 0;
  int _currentRunLevel = 1;
  int _committedRunPoints = 0;
  int _currentGamePoints = 0;
  bool _isRewardOverlayVisible = false;
  bool _isProcessingHit = false;
  bool _isGameOver = false;
  String? _failureMessage;
  String? _targetOutsideSafeZoneMessage;
  List<String> _gameOverMessages = const [];
  PlayerProfile? _playerProfile;
  GamePointRewardResult? _lastGamePointRewardResult;
  bool _isRunFinalized = false;
  late DateTime _runStartedAt;
  int _remainingStopTimeSeconds = 0;
  Timer? _feedbackTimer;
  Timer? _stopTimeTimer;
  Timer? _runDurationTimer;

  @override
  void initState() {
    super.initState();
    _levelGenerator = widget.levelGenerator ?? LevelGenerator();
    _difficultyState =
        widget.initialDifficultyState ??
        _levelGenerator.createInitialDifficultyState();
    _levelConfig =
        widget.initialLevelConfig ??
        _levelGenerator.generateLevelConfig(_difficultyState);
    _playerProfile = widget.playerProfile;
    _currentGamePoints = _playerProfile?.gamePoints ?? 0;
    _runMode =
        widget.initialRunMode ?? _defaultRunModeForPlayer(_playerProfile);
    _runStartedAt = _now();
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
    _resetStopTimeCountdown();
    _startStopTimeCountdown();
    _startRunDurationTimer();
  }

  @override
  void dispose() {
    _feedbackTimer?.cancel();
    _stopStopTimeCountdown();
    _stopRunDurationTimer();
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

  void _stopAnimations() {
    _stopStopTimeCountdown();
    _ballController.stop();
    _safeZoneController?.stop();
    _targetController?.stop();
  }

  void _startStopTimeCountdown() {
    _stopStopTimeCountdown();

    if (_remainingStopTimeSeconds <= 0) {
      return;
    }

    _stopTimeTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        return;
      }

      if (_remainingStopTimeSeconds <= 1) {
        setState(() {
          _remainingStopTimeSeconds = 0;
        });
        _handleStopTimeExpired();
        return;
      }

      setState(() {
        _remainingStopTimeSeconds -= 1;
      });
    });
  }

  void _stopStopTimeCountdown() {
    _stopTimeTimer?.cancel();
    _stopTimeTimer = null;
  }

  void _resetStopTimeCountdown() {
    _stopStopTimeCountdown();
    _remainingStopTimeSeconds = _levelConfig.stopTimeLimit.inSeconds;
  }

  DateTime _now() {
    return widget.now?.call() ?? DateTime.now();
  }

  void _startRunDurationTimer() {
    _stopRunDurationTimer();

    final elapsedRunDuration = _now().difference(_runStartedAt);
    final remainingRunDuration = _maximumRunDuration - elapsedRunDuration;

    if (remainingRunDuration <= Duration.zero) {
      _handleRunDurationExpired();
      return;
    }

    _runDurationTimer = Timer(remainingRunDuration, _handleRunDurationExpired);
  }

  void _stopRunDurationTimer() {
    _runDurationTimer?.cancel();
    _runDurationTimer = null;
  }

  void _handleRunDurationExpired() {
    if (!mounted || _isGameOver || _isRunFinalized) {
      return;
    }

    if (_now().difference(_runStartedAt) < _maximumRunDuration) {
      _startRunDurationTimer();
      return;
    }

    _triggerRunDurationGameOver();
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
      safeZoneStartAngle: levelConfig.safeZoneStartAngle,
      targetAngle: levelConfig.targetStartAngle,
    );
  }

  RunMode _defaultRunModeForPlayer(PlayerProfile? playerProfile) {
    if (playerProfile != null &&
        _warmupAvailabilityPolicy.isWarmupAvailable(playerProfile)) {
      return RunMode.warmup;
    }

    return RunMode.league;
  }

  void _validateCurrentBallPosition(double circleRadius) {
    if (_failureMessage != null ||
        _targetOutsideSafeZoneMessage != null ||
        _isGameOver ||
        _isRewardOverlayVisible ||
        _isProcessingHit) {
      return;
    }

    _isProcessingHit = true;
    final currentBallAngle = _currentBallAngle();
    final currentTargetAngle = _currentTargetAngle();
    final validator = GameCollisionValidator(
      circleRadius: circleRadius,
      ballRadius: _geometry.ballRadius,
      safeZoneStartAngle: _currentSafeZoneStartAngle(),
      safeZoneSweepAngle: _geometry.safeZoneSweepAngle,
      targetAngle: currentTargetAngle,
      targetToleranceAngle: _geometry.targetToleranceAngle,
    );
    final result = validator.validateAngle(ballAngle: currentBallAngle);
    final isLevelSuccess = _isLevelSuccess(result);

    if (!isLevelSuccess) {
      _handleFailedHit(result);
      return;
    }

    final precisionPointResult = _precisionPointResultForCurrentRunLevel(
      _precisionPointCalculator.calculate(
        ballAngle: result.ballAngle,
        targetAngle: currentTargetAngle,
        // PP is awarded for every successful action that advances the run
        // level. Failures and timeouts do not reach this branch and therefore
        // award 0.
        didAdvanceLevel: isLevelSuccess,
      ),
    );

    if (result.isTargetHit && !result.isInsideSafeZone) {
      _showTargetOutsideSafeZoneReward(result, precisionPointResult);
      return;
    }

    final rpRewardResult = _rpRewardCalculator.calculate(result);
    final shouldShowRewardOverlay = isLevelSuccess;

    setState(() {
      _lastHitResult = result;
      _lastRpRewardResult = rpRewardResult;
      _pendingPrecisionPointResult = precisionPointResult;
      _totalRunPoints += rpRewardResult.rpAmount;
      _isRewardOverlayVisible = shouldShowRewardOverlay;
    });

    if (shouldShowRewardOverlay) {
      _stopAnimations();
      return;
    }

    _startTemporaryHitFeedbackTimer();
  }

  void _handleStopTimeExpired() {
    _stopStopTimeCountdown();
    if (_failureMessage != null ||
        _targetOutsideSafeZoneMessage != null ||
        _isGameOver ||
        _isRewardOverlayVisible ||
        _isProcessingHit) {
      return;
    }

    _isProcessingHit = true;

    if (_lives > 0) {
      _showTimeoutWithLifeFeedback();
      return;
    }

    _triggerTimeoutGameOver();
  }

  void _showTimeoutWithLifeFeedback() {
    _stopAnimations();
    _feedbackTimer?.cancel();

    setState(() {
      _lastHitResult = null;
      _lastRpRewardResult = null;
      _pendingPrecisionPointResult = null;
      _failureMessage = "Time's up! Using 1 life...";
    });
  }

  void _triggerTimeoutGameOver() {
    _stopAnimations();
    _stopRunDurationTimer();
    _feedbackTimer?.cancel();
    _finalizeRun();

    setState(() {
      _isGameOver = true;
      _lastHitResult = null;
      _lastRpRewardResult = null;
      _pendingPrecisionPointResult = null;
      _failureMessage = null;
      _targetOutsideSafeZoneMessage = null;
      _isRewardOverlayVisible = false;
      _isProcessingHit = false;
      _gameOverMessages = const ["Time's up! No lives left. Game Over!"];
    });
  }

  void _triggerRunDurationGameOver() {
    _stopAnimations();
    _stopRunDurationTimer();
    _feedbackTimer?.cancel();

    // A one-hour duration limit is a normal run completion boundary. It is
    // finalized through Game Over so GP and final score are recorded exactly
    // once using the run end timestamp.
    _finalizeRun();

    setState(() {
      _isGameOver = true;
      _lastHitResult = null;
      _lastRpRewardResult = null;
      _pendingPrecisionPointResult = null;
      _failureMessage = null;
      _targetOutsideSafeZoneMessage = null;
      _isRewardOverlayVisible = false;
      _isProcessingHit = false;
      _gameOverMessages = const ['Run duration limit reached.', 'Game Over!'];
    });
  }

  void _showTargetOutsideSafeZoneReward(
    HitValidationResult result,
    PrecisionPointResult precisionPointResult,
  ) {
    _stopAnimations();
    _feedbackTimer?.cancel();

    setState(() {
      _lastHitResult = result;
      _lastRpRewardResult = _targetOutsideSafeZoneRewardResult;
      _pendingPrecisionPointResult = precisionPointResult;
      _targetOutsideSafeZoneMessage =
          "You've hit the target outside the Safe Zone! Congratulations! "
          'Your reward is Level Advance with NO difficulty increase!';
    });
  }

  void _confirmTargetOutsideSafeZoneAdvance() {
    final nextLevelConfig = _levelGenerator.generateLevelConfig(
      _difficultyState,
    );

    _levelConfig = nextLevelConfig;
    _geometry = _geometryForLevelConfig(nextLevelConfig);
    _lastChangedVariable = null;
    _lastChangeWasIncrease = true;
    _ballController.duration = nextLevelConfig.ballRotationDuration;
    _resetStopTimeCountdown();
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

    setState(() {
      _currentRunLevel += 1;
      if (_pendingPrecisionPointResult != null) {
        _totalPrecisionPoints += _pendingPrecisionPointResult!.awardedPP;
      }
      _committedRunPoints = _totalRunPoints;
      _targetOutsideSafeZoneMessage = null;
      _lastHitResult = null;
      _lastRpRewardResult = null;
      _pendingPrecisionPointResult = null;
      _isProcessingHit = false;
    });
    _startStopTimeCountdown();
  }

  void _startTemporaryHitFeedbackTimer() {
    _feedbackTimer?.cancel();
    _feedbackTimer = Timer(_feedbackDuration, () {
      if (!mounted) {
        return;
      }

      setState(() {
        _lastHitResult = null;
        _lastRpRewardResult = null;
        _isProcessingHit = false;
      });
    });
  }

  bool _isLevelSuccess(HitValidationResult result) {
    return result.isInsideSafeZone || result.isTargetHit;
  }

  PrecisionPointResult _precisionPointResultForCurrentRunLevel(
    PrecisionPointResult baseResult,
  ) {
    final levelMultiplier = 1 + (_currentRunLevel * 0.01);

    // The engine calculator remains responsible for circular precision. The
    // run-level multiplier is applied here because it depends on UI/controller
    // run state and should only affect the pending reward for this level.
    return PrecisionPointResult(
      basePP: baseResult.awardedPP,
      levelMultiplier: levelMultiplier,
      awardedPP: (baseResult.awardedPP * levelMultiplier).round(),
      angularDistance: baseResult.angularDistance,
      normalizedPrecision: baseResult.normalizedPrecision,
    );
  }

  String? _rewardOverlayWarningMessage(
    HitValidationResult result,
    RunPointRewardResult rpRewardResult,
  ) {
    final safeZoneEdgeOnlyHit =
        result.isInsideSafeZone &&
        result.relativePositionInSafeZone == null &&
        rpRewardResult.rpAmount == 0;

    if (!safeZoneEdgeOnlyHit) {
      return null;
    }

    return 'Ball is touching the Safe Zone! No RP gained because the ball '
        'center is outside the Safe Zone.';
  }

  void _handleFailedHit(HitValidationResult result) {
    if (_lives > 0) {
      _showFailureFeedback(result);
      return;
    }

    _triggerGameOver(result);
  }

  void _showFailureFeedback(HitValidationResult result) {
    _stopAnimations();
    _feedbackTimer?.cancel();

    setState(() {
      _lastHitResult = result;
      _lastRpRewardResult = _noRpRewardResult;
      _pendingPrecisionPointResult = null;
      _failureMessage = 'Missed safe zone and target. Using 1 life.';
    });
  }

  void _confirmLifeUsageAndRetry() {
    _resetStopTimeCountdown();

    setState(() {
      _lives -= 1;
      _lastHitResult = null;
      _lastRpRewardResult = null;
      _pendingPrecisionPointResult = null;
      _failureMessage = null;
      _isRewardOverlayVisible = false;
      _isProcessingHit = false;
    });

    _restartCurrentLevelAnimations();
    _startStopTimeCountdown();
  }

  void _triggerGameOver(HitValidationResult result) {
    _stopAnimations();
    _stopRunDurationTimer();
    _feedbackTimer?.cancel();
    _finalizeRun();

    setState(() {
      _isGameOver = true;
      _lastHitResult = result;
      _lastRpRewardResult = _noRpRewardResult;
      _pendingPrecisionPointResult = null;
      _failureMessage = null;
      _targetOutsideSafeZoneMessage = null;
      _isRewardOverlayVisible = false;
      _isProcessingHit = false;
      _gameOverMessages = const [
        'Missed safe zone and target.',
        'No lives left. Game Over!',
      ];
    });
  }

  void _finalizeRun() {
    if (_isRunFinalized) {
      return;
    }

    final runEndedAt = _now();
    final playerProfile = _playerProfile;

    // A run can end while a successful level reward is still waiting for player
    // confirmation. Commit pending PP before GP calculation so warmup threshold
    // and final scoring use the real completed run value.
    final finalizedPrecisionPoints =
        _totalPrecisionPoints + (_pendingPrecisionPointResult?.awardedPP ?? 0);

    final gpRewardResult = _gpRewardCalculator.calculate(
      runMode: _runMode,
      totalPrecisionPoints: finalizedPrecisionPoints,
      runEndedAt: runEndedAt,
      lastDailyGpAwardedAt: playerProfile?.lastDailyGpAwardedAt,
    );

    final updatedGamePoints =
        (playerProfile?.gamePoints ?? _currentGamePoints) +
        gpRewardResult.totalGp;

    _totalPrecisionPoints = finalizedPrecisionPoints;
    _pendingPrecisionPointResult = null;
    _lastGamePointRewardResult = gpRewardResult;
    _currentGamePoints = updatedGamePoints;
    _isRunFinalized = true;

    if (playerProfile == null || widget.authRepository == null) {
      return;
    }

    final updatedPlayerProfile = playerProfile.copyWith(
      gamePoints: updatedGamePoints,
      lastDailyGpAwardedAt: gpRewardResult.dailyGpAwarded
          ? runEndedAt
          : playerProfile.lastDailyGpAwardedAt,
    );

    _playerProfile = updatedPlayerProfile;

    unawaited(_persistPlayerProfile(updatedPlayerProfile));
  }

  Future<void> _persistPlayerProfile(PlayerProfile playerProfile) async {
    try {
      await widget.authRepository?.updatePlayerProfile(playerProfile);
    } catch (_) {
      // Mock persistence is best-effort in the client. Future backend
      // integration should surface authenticated write failures explicitly.
    }
  }

  void _openStore() {
    final playerProfile = _playerProfile;
    final purchaseRepository = widget.purchaseRepository;
    if (playerProfile == null || purchaseRepository == null) {
      return;
    }

    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) {
          return StoreScreen(
            playerProfile: playerProfile,
            purchaseRepository: purchaseRepository,
            onPlayerProfileUpdated: _handlePurchasedPlayerProfile,
          );
        },
      ),
    );
  }

  void _handlePurchasedPlayerProfile(PlayerProfile playerProfile) {
    setState(() {
      _playerProfile = playerProfile;
      _currentGamePoints = playerProfile.gamePoints;
      _runMode =
          widget.initialRunMode ?? _defaultRunModeForPlayer(playerProfile);
    });

    unawaited(_persistPlayerProfile(playerProfile));
  }

  void _restartCurrentLevelAnimations() {
    _ballController
      ..reset()
      ..repeat();
    _safeZoneController
      ?..reset()
      ..repeat();
    _targetController
      ?..reset()
      ..repeat();
  }

  void _restartRun() {
    _feedbackTimer?.cancel();
    _stopStopTimeCountdown();
    _stopRunDurationTimer();

    final initialDifficultyState = _levelGenerator
        .createInitialDifficultyState();
    final initialLevelConfig = _levelGenerator.generateLevelConfig(
      initialDifficultyState,
    );

    _difficultyState = initialDifficultyState;
    _levelConfig = initialLevelConfig;
    _lastChangedVariable = null;
    _lastChangeWasIncrease = true;
    _runMode =
        widget.initialRunMode ?? _defaultRunModeForPlayer(_playerProfile);
    _runStartedAt = _now();
    _geometry = _geometryForLevelConfig(initialLevelConfig);
    _ballController.duration = initialLevelConfig.ballRotationDuration;
    _resetStopTimeCountdown();
    _ballController
      ..reset()
      ..repeat();
    _replaceOptionalController(
      currentController: _safeZoneController,
      duration: initialLevelConfig.safeZoneRotationDuration,
      updateController: (controller) {
        _safeZoneController = controller;
      },
    );
    _replaceOptionalController(
      currentController: _targetController,
      duration: initialLevelConfig.targetRotationDuration,
      updateController: (controller) {
        _targetController = controller;
      },
    );

    setState(() {
      _totalRunPoints = 0;
      _totalPrecisionPoints = 0;
      _committedRunPoints = 0;
      _lives = 0;
      _currentRunLevel = 1;
      _lastHitResult = null;
      _lastRpRewardResult = null;
      _pendingPrecisionPointResult = null;
      _failureMessage = null;
      _targetOutsideSafeZoneMessage = null;
      _isRewardOverlayVisible = false;
      _isProcessingHit = false;
      _isGameOver = false;
      _gameOverMessages = const [];
      _lastGamePointRewardResult = null;
      _isRunFinalized = false;
    });
    _startStopTimeCountdown();
    _startRunDurationTimer();
  }

  void _advanceToNextDebugLevel({required RewardMenuAction action}) {
    final (nextDifficultyState, changedVariable) = _nextDifficultyForAction(
      action,
    );
    final nextLevelConfig = _levelGenerator.generateLevelConfig(
      nextDifficultyState,
    );

    _difficultyState = nextDifficultyState;
    _lastChangedVariable = changedVariable;
    _lastChangeWasIncrease = !action.isDifficultyDecrease;
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
    _resetStopTimeCountdown();
    _startStopTimeCountdown();
  }

  (DifficultyState, DifficultyVariable?) _nextDifficultyForAction(
    RewardMenuAction action,
  ) {
    if (action == RewardMenuAction.nextLevel) {
      final advanceResult = _levelGenerator.advanceDifficulty(_difficultyState);
      return (advanceResult.difficultyState, advanceResult.increasedVariable);
    }

    if (action == RewardMenuAction.decreaseRandomDifficulty) {
      final decreaseResult = _levelGenerator.decreaseRandomDifficulty(
        _difficultyState,
      );
      return (decreaseResult.difficultyState, decreaseResult.decreasedVariable);
    }

    final variable = action.variable;
    if (variable == null) {
      return (_difficultyState, null);
    }

    if (action.isChosenDifficultyDecrease) {
      return (_difficultyState.decreaseVariable(variable), variable);
    }

    return (_difficultyState.increaseVariable(variable), variable);
  }

  void _selectRewardOption(RewardMenuAction action) {
    if (action == RewardMenuAction.buyLife) {
      setState(() {
        _totalRunPoints -= action.rpCost;
        _lives += 1;
      });
      return;
    }

    _advanceToNextDebugLevel(action: action);

    setState(() {
      _currentRunLevel += 1;
      if (_pendingPrecisionPointResult != null) {
        _totalPrecisionPoints += _pendingPrecisionPointResult!.awardedPP;
      }
      _totalRunPoints -= action.rpCost;
      _committedRunPoints = _totalRunPoints;
      _isRewardOverlayVisible = false;
      _lastHitResult = null;
      _lastRpRewardResult = null;
      _pendingPrecisionPointResult = null;
      _targetOutsideSafeZoneMessage = null;
      _failureMessage = null;
      _isProcessingHit = false;
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
              final paintDimension = availableDimension - _gameAreaPadding * 2;
              final circleRadius = _geometry.circleRadiusForDimension(
                paintDimension,
              );

              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _validateCurrentBallPosition(circleRadius),
                child: SizedBox.expand(
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
                                safeZoneStartAngle:
                                    _currentSafeZoneStartAngle(),
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
                      Positioned(
                        top: 16,
                        right: 16,
                        child: _RunStatusOverlay(
                          runLevel: _currentRunLevel,
                          totalPrecisionPoints: _totalPrecisionPoints,
                          totalRunPoints: _committedRunPoints,
                          totalGamePoints: _currentGamePoints,
                          runMode: _runMode,
                          remainingSeconds: _remainingStopTimeSeconds,
                        ),
                      ),
                      if (_playerProfile != null &&
                          widget.purchaseRepository != null)
                        Positioned(
                          right: 16,
                          bottom: 16,
                          child: FilledButton(
                            onPressed: _openStore,
                            child: const Text('Store'),
                          ),
                        ),
                      if (_lastHitResult != null &&
                          !_isRewardOverlayVisible &&
                          !_isGameOver &&
                          _targetOutsideSafeZoneMessage == null &&
                          _failureMessage == null)
                        _DebugHitFeedback(
                          result: _lastHitResult!,
                          rpRewardResult: _lastRpRewardResult!,
                          totalRunPoints: _totalRunPoints,
                        ),
                      if (_failureMessage != null)
                        _FailureFeedbackOverlay(
                          message: _failureMessage!,
                          result: _lastHitResult,
                          rpRewardResult: _lastRpRewardResult,
                          totalRunPoints: _totalRunPoints,
                          onConfirm: _confirmLifeUsageAndRetry,
                        ),
                      if (_targetOutsideSafeZoneMessage != null &&
                          _pendingPrecisionPointResult != null)
                        _TargetOutsideSafeZoneOverlay(
                          message: _targetOutsideSafeZoneMessage!,
                          precisionPointResult: _pendingPrecisionPointResult!,
                          onConfirm: _confirmTargetOutsideSafeZoneAdvance,
                        ),
                      if (_isRewardOverlayVisible &&
                          _lastRpRewardResult != null &&
                          _pendingPrecisionPointResult != null)
                        PostHitRewardOverlay(
                          difficultyState: _difficultyState,
                          rpRewardResult: _lastRpRewardResult!,
                          precisionPointResult: _pendingPrecisionPointResult!,
                          totalRunPoints: _totalRunPoints,
                          warningMessage: _rewardOverlayWarningMessage(
                            _lastHitResult!,
                            _lastRpRewardResult!,
                          ),
                          onSelected: _selectRewardOption,
                        ),
                      if (_isGameOver)
                        _GameOverOverlay(
                          messages: _gameOverMessages,
                          totalPrecisionPoints: _totalPrecisionPoints,
                          runLevel: _currentRunLevel,
                          runMode: _runMode,
                          gpRewardResult: _lastGamePointRewardResult,
                          currentGamePoints: _currentGamePoints,
                          onRestart: _restartRun,
                        ),
                      if (kShowDebugOverlay)
                        Positioned(
                          top: 16,
                          left: 16,
                          child: IgnorePointer(
                            child: _DebugDifficultyOverlay(
                              difficultyState: _difficultyState,
                              lives: _lives,
                              lastChangedVariable: _lastChangedVariable,
                              lastChangeWasIncrease: _lastChangeWasIncrease,
                            ),
                          ),
                        ),
                    ],
                  ),
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
    required this.lives,
    required this.lastChangedVariable,
    required this.lastChangeWasIncrease,
  });

  final DifficultyState difficultyState;
  final int lives;
  final DifficultyVariable? lastChangedVariable;
  final bool lastChangeWasIncrease;

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
              Text('lives: $lives'),
              const SizedBox(height: 6),
              Text(
                '${lastChangeWasIncrease ? 'last increased' : 'last decreased'}: '
                '${lastChangedVariable?.debugLabel ?? 'none'}',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RunStatusOverlay extends StatelessWidget {
  const _RunStatusOverlay({
    required this.runLevel,
    required this.totalPrecisionPoints,
    required this.totalRunPoints,
    required this.totalGamePoints,
    required this.runMode,
    required this.remainingSeconds,
  });

  final int runLevel;
  final int totalPrecisionPoints;
  final int totalRunPoints;
  final int totalGamePoints;
  final RunMode runMode;
  final int remainingSeconds;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xCC101418),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF3A424C)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: DefaultTextStyle(
          style: const TextStyle(
            color: Color(0xFFD6DEE8),
            fontSize: 14,
            fontWeight: FontWeight.w700,
            height: 1.25,
            letterSpacing: 0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Level: $runLevel'),
              Text('Mode: ${runMode.label}'),
              Text('PP: $totalPrecisionPoints'),
              Text('RP: $totalRunPoints'),
              Text('GP: $totalGamePoints'),
              Text('Time: ${remainingSeconds}s'),
            ],
          ),
        ),
      ),
    );
  }
}

class _GameOverOverlay extends StatelessWidget {
  const _GameOverOverlay({
    required this.messages,
    required this.totalPrecisionPoints,
    required this.runLevel,
    required this.runMode,
    required this.gpRewardResult,
    required this.currentGamePoints,
    required this.onRestart,
  });

  final List<String> messages;
  final int totalPrecisionPoints;
  final int runLevel;
  final RunMode runMode;
  final GamePointRewardResult? gpRewardResult;
  final int currentGamePoints;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    final finalScore = totalPrecisionPoints + (runLevel * 100);
    final bonusPoints = runLevel * 100;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xEE101418),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFF6B6B)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Game Over',
              style: TextStyle(
                color: Color(0xFFFF6B6B),
                fontSize: 22,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 10),

            ...messages.map(
              (message) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFD6DEE8),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            const Text(
              'Final Score = PP + Bonus',
              style: TextStyle(
                color: Color(0xFFFFD166),
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),

            const SizedBox(height: 6),

            Text(
              '$finalScore',
              style: const TextStyle(
                color: Color(0xFF7CC7FF),
                fontSize: 28,
                fontWeight: FontWeight.w800,
              ),
            ),

            const SizedBox(height: 10),

            Text(
              'PP: $totalPrecisionPoints',
              style: const TextStyle(
                color: Color(0xFFD6DEE8),
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),

            const SizedBox(height: 4),

            Text(
              'Bonus (Level $runLevel × 100): $bonusPoints',
              style: const TextStyle(
                color: Color(0xFFFFD166),
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),

            if (gpRewardResult != null) ...[
              const SizedBox(height: 16),
              const Text(
                'Game Points',
                style: TextStyle(
                  color: Color(0xFFFFD166),
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Run mode: ${runMode.label}',
                style: const TextStyle(
                  color: Color(0xFFD6DEE8),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Completion GP: ${gpRewardResult!.completionGp}',
                style: const TextStyle(
                  color: Color(0xFFD6DEE8),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Daily GP: ${gpRewardResult!.dailyGp}',
                style: const TextStyle(
                  color: Color(0xFFD6DEE8),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Total GP earned: ${gpRewardResult!.totalGp}',
                style: const TextStyle(
                  color: Color(0xFF39D98A),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Current total GP: $currentGamePoints',
                style: const TextStyle(
                  color: Color(0xFFD6DEE8),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (runMode == RunMode.warmup) ...[
                const SizedBox(height: 6),
                Text(
                  gpRewardResult!.warmupThresholdReached
                      ? 'Warmup completion GP awarded: 10,000 PP threshold reached.'
                      : 'Warmup completion GP not awarded: 10,000 PP threshold not reached.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFFFD166),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],

            const SizedBox(height: 16),

            FilledButton(
              onPressed: onRestart,
              child: const Text('Restart run'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TargetOutsideSafeZoneOverlay extends StatelessWidget {
  const _TargetOutsideSafeZoneOverlay({
    required this.message,
    required this.precisionPointResult,
    required this.onConfirm,
  });

  final String message;
  final PrecisionPointResult precisionPointResult;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xEE101418),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFFD166)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFFFD166),
                fontSize: 15,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '+${precisionPointResult.awardedPP} PP',
              style: const TextStyle(
                color: Color(0xFF7CC7FF),
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Precision Points',
              style: TextStyle(
                color: Color(0xFFD6DEE8),
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _precisionPointBreakdown(precisionPointResult),
              style: const TextStyle(
                color: Color(0xFFB8C5D4),
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: onConfirm, child: const Text('OK')),
          ],
        ),
      ),
    );
  }

  String _precisionPointBreakdown(PrecisionPointResult result) {
    return '${result.basePP} PP × '
        '${result.levelMultiplier.toStringAsFixed(2)} = '
        '${result.awardedPP} PP';
  }
}

class _FailureFeedbackOverlay extends StatelessWidget {
  const _FailureFeedbackOverlay({
    required this.message,
    required this.result,
    required this.rpRewardResult,
    required this.totalRunPoints,
    required this.onConfirm,
  });

  final String message;
  final HitValidationResult? result;
  final RunPointRewardResult? rpRewardResult;
  final int totalRunPoints;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xCC101418),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFFD166)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFFFD166),
                fontSize: 15,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 10),
            if (result != null && rpRewardResult != null) ...[
              _DebugHitFeedback(
                result: result!,
                rpRewardResult: rpRewardResult!,
                totalRunPoints: totalRunPoints,
              ),
              const SizedBox(height: 12),
            ],
            FilledButton(onPressed: onConfirm, child: const Text('OK')),
          ],
        ),
      ),
    );
  }
}

class _DebugHitFeedback extends StatelessWidget {
  const _DebugHitFeedback({
    required this.result,
    required this.rpRewardResult,
    required this.totalRunPoints,
  });

  final HitValidationResult result;
  final RunPointRewardResult rpRewardResult;
  final int totalRunPoints;

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
            const SizedBox(height: 6),
            Text(
              result.relativePositionInSafeZone == null
                  ? 'CENTER OUTSIDE SAFE ZONE'
                  : 'CENTER IN SAFE ZONE',
              style: _feedbackTextStyle(
                result.relativePositionInSafeZone == null
                    ? const Color(0xFFD6DEE8)
                    : const Color(0xFF39D98A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'RP tier: ${rpRewardResult.rewardTier.name}',
              style: _feedbackTextStyle(const Color(0xFFD6DEE8)),
            ),
            const SizedBox(height: 4),
            Text(
              'RP gained: ${rpRewardResult.rpAmount}',
              style: _feedbackTextStyle(
                rpRewardResult.rewarded
                    ? const Color(0xFF39D98A)
                    : const Color(0xFFD6DEE8),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'total RP: $totalRunPoints',
              style: _feedbackTextStyle(const Color(0xFFFFD166)),
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
