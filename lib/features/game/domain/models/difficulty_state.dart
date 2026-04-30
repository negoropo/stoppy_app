import 'dart:math';

class DifficultyState {
  DifficultyState({
    required this.ballSpeedLevel,
    required this.ballSizeLevel,
    required this.stopTimeLevel,
    required this.safeZoneSizeLevel,
    required this.safeZoneSpeedLevel,
    required this.targetSpeedLevel,
  }) {
    _validateLevel(ballSpeedLevel);
    _validateLevel(ballSizeLevel);
    _validateLevel(stopTimeLevel);
    _validateLevel(safeZoneSizeLevel);
    _validateLevel(safeZoneSpeedLevel);
    _validateLevel(targetSpeedLevel);
  }

  const DifficultyState.initial()
    : ballSpeedLevel = 0,
      ballSizeLevel = 0,
      stopTimeLevel = 0,
      safeZoneSizeLevel = 0,
      safeZoneSpeedLevel = 0,
      targetSpeedLevel = 0;

  static const int minLevel = 0;
  static const int maxLevel = 10;

  final int ballSpeedLevel;
  final int ballSizeLevel;
  final int stopTimeLevel;
  final int safeZoneSizeLevel;
  final int safeZoneSpeedLevel;
  final int targetSpeedLevel;

  bool get isMaxed {
    return ballSpeedLevel == maxLevel &&
        ballSizeLevel == maxLevel &&
        stopTimeLevel == maxLevel &&
        safeZoneSizeLevel == maxLevel &&
        safeZoneSpeedLevel == maxLevel &&
        targetSpeedLevel == maxLevel;
  }

  DifficultyState increaseRandomNonMaxed(Random random) {
    if (isMaxed) {
      return this;
    }

    final availableVariables = <DifficultyVariable>[
      if (ballSpeedLevel < maxLevel) DifficultyVariable.ballSpeed,
      if (ballSizeLevel < maxLevel) DifficultyVariable.ballSize,
      if (stopTimeLevel < maxLevel) DifficultyVariable.stopTime,
      if (safeZoneSizeLevel < maxLevel) DifficultyVariable.safeZoneSize,
      if (safeZoneSpeedLevel < maxLevel) DifficultyVariable.safeZoneSpeed,
      if (targetSpeedLevel < maxLevel) DifficultyVariable.targetSpeed,
    ];
    final selectedVariable =
        availableVariables[random.nextInt(availableVariables.length)];

    return switch (selectedVariable) {
      DifficultyVariable.ballSpeed => copyWith(
        ballSpeedLevel: ballSpeedLevel + 1,
      ),
      DifficultyVariable.ballSize => copyWith(ballSizeLevel: ballSizeLevel + 1),
      DifficultyVariable.stopTime => copyWith(stopTimeLevel: stopTimeLevel + 1),
      DifficultyVariable.safeZoneSize => copyWith(
        safeZoneSizeLevel: safeZoneSizeLevel + 1,
      ),
      DifficultyVariable.safeZoneSpeed => copyWith(
        safeZoneSpeedLevel: safeZoneSpeedLevel + 1,
      ),
      DifficultyVariable.targetSpeed => copyWith(
        targetSpeedLevel: targetSpeedLevel + 1,
      ),
    };
  }

  DifficultyState copyWith({
    int? ballSpeedLevel,
    int? ballSizeLevel,
    int? stopTimeLevel,
    int? safeZoneSizeLevel,
    int? safeZoneSpeedLevel,
    int? targetSpeedLevel,
  }) {
    return DifficultyState(
      ballSpeedLevel: ballSpeedLevel ?? this.ballSpeedLevel,
      ballSizeLevel: ballSizeLevel ?? this.ballSizeLevel,
      stopTimeLevel: stopTimeLevel ?? this.stopTimeLevel,
      safeZoneSizeLevel: safeZoneSizeLevel ?? this.safeZoneSizeLevel,
      safeZoneSpeedLevel: safeZoneSpeedLevel ?? this.safeZoneSpeedLevel,
      targetSpeedLevel: targetSpeedLevel ?? this.targetSpeedLevel,
    );
  }

  List<int> get levels {
    return [
      ballSpeedLevel,
      ballSizeLevel,
      stopTimeLevel,
      safeZoneSizeLevel,
      safeZoneSpeedLevel,
      targetSpeedLevel,
    ];
  }

  static void _validateLevel(int level) {
    if (level < minLevel || level > maxLevel) {
      throw ArgumentError.value(
        level,
        'level',
        'Difficulty levels must be between $minLevel and $maxLevel.',
      );
    }
  }
}

enum DifficultyVariable {
  ballSpeed,
  ballSize,
  stopTime,
  safeZoneSize,
  safeZoneSpeed,
  targetSpeed,
}

extension DifficultyVariableLabel on DifficultyVariable {
  String get debugLabel {
    return switch (this) {
      DifficultyVariable.ballSpeed => 'ballSpeedLevel',
      DifficultyVariable.ballSize => 'ballSizeLevel',
      DifficultyVariable.stopTime => 'stopTimeLevel',
      DifficultyVariable.safeZoneSize => 'safeZoneSizeLevel',
      DifficultyVariable.safeZoneSpeed => 'safeZoneSpeedLevel',
      DifficultyVariable.targetSpeed => 'targetSpeedLevel',
    };
  }
}
