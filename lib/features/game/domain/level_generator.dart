import 'dart:math' as math;

import 'models/difficulty_state.dart';
import 'models/game_level_config.dart';
import 'models/movement_direction.dart';

class LevelGenerator {
  LevelGenerator({math.Random? random}) : _random = random ?? math.Random();

  final math.Random _random;

  static const List<int> _stopTimeSecondsByLevel = [
    30,
    27,
    24,
    21,
    18,
    15,
    13,
    11,
    9,
    7,
    5,
  ];

  DifficultyState createInitialDifficultyState() {
    return const DifficultyState.initial();
  }

  GameLevelConfig generateLevelConfig(DifficultyState difficultyState) {
    return GameLevelConfig(
      ballRotationDuration: ballRotationDurationForLevel(
        difficultyState.ballSpeedLevel,
      ),
      ballRadius: ballRadiusForLevel(difficultyState.ballSizeLevel),
      stopTimeLimit: stopTimeLimitForLevel(difficultyState.stopTimeLevel),
      safeZoneSweepAngle: safeZoneSweepAngleForLevel(
        difficultyState.safeZoneSizeLevel,
      ),
      safeZoneRotationDuration: safeZoneRotationDurationForLevel(
        difficultyState.safeZoneSpeedLevel,
      ),
      targetRotationDuration: targetRotationDurationForLevel(
        difficultyState.targetSpeedLevel,
      ),
      ballStartAngle: _randomAngle(),
      safeZoneStartAngle: _randomAngle(),
      targetStartAngle: _randomAngle(),
      ballDirection: _random.nextBool()
          ? MovementDirection.clockwise
          : MovementDirection.counterClockwise,
    );
  }

  DifficultyState increaseDifficultyAfterSuccess(
    DifficultyState difficultyState,
  ) {
    return advanceDifficulty(difficultyState).difficultyState;
  }

  DifficultyAdvanceResult advanceDifficulty(DifficultyState difficultyState) {
    if (difficultyState.isMaxed) {
      return DifficultyAdvanceResult(
        difficultyState: difficultyState,
        increasedVariable: null,
      );
    }

    final availableVariables = <DifficultyVariable>[
      if (difficultyState.ballSpeedLevel < DifficultyState.maxLevel)
        DifficultyVariable.ballSpeed,
      if (difficultyState.ballSizeLevel < DifficultyState.maxLevel)
        DifficultyVariable.ballSize,
      if (difficultyState.stopTimeLevel < DifficultyState.maxLevel)
        DifficultyVariable.stopTime,
      if (difficultyState.safeZoneSizeLevel < DifficultyState.maxLevel)
        DifficultyVariable.safeZoneSize,
      if (difficultyState.safeZoneSpeedLevel < DifficultyState.maxLevel)
        DifficultyVariable.safeZoneSpeed,
      if (difficultyState.targetSpeedLevel < DifficultyState.maxLevel)
        DifficultyVariable.targetSpeed,
    ];
    final selectedVariable =
        availableVariables[_random.nextInt(availableVariables.length)];

    return DifficultyAdvanceResult(
      difficultyState: _increaseVariable(difficultyState, selectedVariable),
      increasedVariable: selectedVariable,
    );
  }

  DifficultyDecreaseResult decreaseRandomDifficulty(
    DifficultyState difficultyState,
  ) {
    if (difficultyState.isAtMinimum) {
      return DifficultyDecreaseResult(
        difficultyState: difficultyState,
        decreasedVariable: null,
      );
    }

    // Only variables above zero can be selected. This guarantees the paid
    // decrease option never crosses below the minimum difficulty contract.
    final availableVariables = <DifficultyVariable>[
      if (difficultyState.ballSpeedLevel > DifficultyState.minLevel)
        DifficultyVariable.ballSpeed,
      if (difficultyState.ballSizeLevel > DifficultyState.minLevel)
        DifficultyVariable.ballSize,
      if (difficultyState.stopTimeLevel > DifficultyState.minLevel)
        DifficultyVariable.stopTime,
      if (difficultyState.safeZoneSizeLevel > DifficultyState.minLevel)
        DifficultyVariable.safeZoneSize,
      if (difficultyState.safeZoneSpeedLevel > DifficultyState.minLevel)
        DifficultyVariable.safeZoneSpeed,
      if (difficultyState.targetSpeedLevel > DifficultyState.minLevel)
        DifficultyVariable.targetSpeed,
    ];
    final selectedVariable =
        availableVariables[_random.nextInt(availableVariables.length)];

    return DifficultyDecreaseResult(
      difficultyState: difficultyState.decreaseVariable(selectedVariable),
      decreasedVariable: selectedVariable,
    );
  }

  static Duration ballRotationDurationForLevel(int level) {
    _validateLevel(level);

    // Lower duration means higher speed. A linear millisecond table is simple
    // to audit now and easy to tune later without changing gameplay contracts.
    return Duration(
      milliseconds: _lerpInt(start: 3200, end: 900, level: level),
    );
  }

  static double ballRadiusForLevel(int level) {
    _validateLevel(level);

    // Ball size is deterministic and monotonic: easier levels have a larger
    // contact area, while higher levels shrink it to demand more precision.
    return _lerpDouble(start: 18, end: 8, level: level);
  }

  static Duration stopTimeLimitForLevel(int level) {
    _validateLevel(level);

    return Duration(seconds: _stopTimeSecondsByLevel[level]);
  }

  static double safeZoneSweepAngleForLevel(int level) {
    _validateLevel(level);

    // Game_Rules.md defines safe zone size as circumference percentage:
    // level 0 is 55%, then each level removes 5%, ending at 5% for level 10.
    final circumferencePercentage = 0.55 - level * 0.05;
    return math.pi * 2 * circumferencePercentage;
  }

  static Duration? safeZoneRotationDurationForLevel(int level) {
    _validateLevel(level);

    if (level == 0) {
      return null;
    }

    return Duration(
      milliseconds: _lerpInt(start: 12000, end: 3000, level: level),
    );
  }

  static Duration? targetRotationDurationForLevel(int level) {
    _validateLevel(level);

    if (level == 0) {
      return Duration.zero;
    }

    if (level == DifficultyState.maxLevel) {
      return const Duration(milliseconds: 2500);
    }

    final currentSafeZoneDuration = safeZoneRotationDurationForLevel(level)!;
    final nextSafeZoneDuration = safeZoneRotationDurationForLevel(level + 1)!;

    // Durations get shorter as speed increases. The midpoint keeps target speed
    // between safe zone level N and N+1, while avoiding equal speeds.
    return Duration(
      milliseconds:
          (currentSafeZoneDuration.inMilliseconds +
              nextSafeZoneDuration.inMilliseconds) ~/
          2,
    );
  }

  static bool isRotationStopped(Duration? duration) {
    return duration == null || duration == Duration.zero;
  }

  DifficultyState _increaseVariable(
    DifficultyState difficultyState,
    DifficultyVariable variable,
  ) {
    return switch (variable) {
      DifficultyVariable.ballSpeed => difficultyState.copyWith(
        ballSpeedLevel: difficultyState.ballSpeedLevel + 1,
      ),
      DifficultyVariable.ballSize => difficultyState.copyWith(
        ballSizeLevel: difficultyState.ballSizeLevel + 1,
      ),
      DifficultyVariable.stopTime => difficultyState.copyWith(
        stopTimeLevel: difficultyState.stopTimeLevel + 1,
      ),
      DifficultyVariable.safeZoneSize => difficultyState.copyWith(
        safeZoneSizeLevel: difficultyState.safeZoneSizeLevel + 1,
      ),
      DifficultyVariable.safeZoneSpeed => difficultyState.copyWith(
        safeZoneSpeedLevel: difficultyState.safeZoneSpeedLevel + 1,
      ),
      DifficultyVariable.targetSpeed => difficultyState.copyWith(
        targetSpeedLevel: difficultyState.targetSpeedLevel + 1,
      ),
    };
  }

  double _randomAngle() {
    return _random.nextDouble() * math.pi * 2;
  }

  static int _lerpInt({
    required int start,
    required int end,
    required int level,
  }) {
    return (start + (end - start) * (level / DifficultyState.maxLevel)).round();
  }

  static double _lerpDouble({
    required double start,
    required double end,
    required int level,
  }) {
    return start + (end - start) * (level / DifficultyState.maxLevel);
  }

  static void _validateLevel(int level) {
    if (level < DifficultyState.minLevel || level > DifficultyState.maxLevel) {
      throw ArgumentError.value(
        level,
        'level',
        'Difficulty levels must be between ${DifficultyState.minLevel} '
            'and ${DifficultyState.maxLevel}.',
      );
    }
  }
}

class DifficultyAdvanceResult {
  const DifficultyAdvanceResult({
    required this.difficultyState,
    required this.increasedVariable,
  });

  final DifficultyState difficultyState;
  final DifficultyVariable? increasedVariable;
}

class DifficultyDecreaseResult {
  const DifficultyDecreaseResult({
    required this.difficultyState,
    required this.decreasedVariable,
  });

  final DifficultyState difficultyState;
  final DifficultyVariable? decreasedVariable;
}
