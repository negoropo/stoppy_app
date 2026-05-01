import 'difficulty_state.dart';

enum RewardMenuAction {
  nextLevel(rpCost: 0),
  skipDifficulty(rpCost: 5),
  decreaseRandomDifficulty(rpCost: 10),
  buyLife(rpCost: 20),
  increaseBallSpeed(rpCost: 2, variable: DifficultyVariable.ballSpeed),
  increaseBallSize(rpCost: 2, variable: DifficultyVariable.ballSize),
  increaseStopTime(rpCost: 2, variable: DifficultyVariable.stopTime),
  increaseSafeZoneSize(rpCost: 2, variable: DifficultyVariable.safeZoneSize),
  increaseSafeZoneSpeed(rpCost: 2, variable: DifficultyVariable.safeZoneSpeed),
  increaseTargetSpeed(rpCost: 2, variable: DifficultyVariable.targetSpeed),
  decreaseBallSpeed(rpCost: 15, variable: DifficultyVariable.ballSpeed),
  decreaseBallSize(rpCost: 15, variable: DifficultyVariable.ballSize),
  decreaseStopTime(rpCost: 15, variable: DifficultyVariable.stopTime),
  decreaseSafeZoneSize(rpCost: 15, variable: DifficultyVariable.safeZoneSize),
  decreaseSafeZoneSpeed(rpCost: 15, variable: DifficultyVariable.safeZoneSpeed),
  decreaseTargetSpeed(rpCost: 15, variable: DifficultyVariable.targetSpeed);

  const RewardMenuAction({required this.rpCost, this.variable});

  final int rpCost;
  final DifficultyVariable? variable;

  bool get isDifficultyDecrease {
    return this == RewardMenuAction.decreaseRandomDifficulty ||
        switch (this) {
          RewardMenuAction.decreaseBallSpeed ||
          RewardMenuAction.decreaseBallSize ||
          RewardMenuAction.decreaseStopTime ||
          RewardMenuAction.decreaseSafeZoneSize ||
          RewardMenuAction.decreaseSafeZoneSpeed ||
          RewardMenuAction.decreaseTargetSpeed => true,
          _ => false,
        };
  }

  bool get isChosenDifficultyDecrease {
    return switch (this) {
      RewardMenuAction.decreaseBallSpeed ||
      RewardMenuAction.decreaseBallSize ||
      RewardMenuAction.decreaseStopTime ||
      RewardMenuAction.decreaseSafeZoneSize ||
      RewardMenuAction.decreaseSafeZoneSpeed ||
      RewardMenuAction.decreaseTargetSpeed => true,
      _ => false,
    };
  }

  factory RewardMenuAction.increaseVariable(DifficultyVariable variable) {
    return switch (variable) {
      DifficultyVariable.ballSpeed => RewardMenuAction.increaseBallSpeed,
      DifficultyVariable.ballSize => RewardMenuAction.increaseBallSize,
      DifficultyVariable.stopTime => RewardMenuAction.increaseStopTime,
      DifficultyVariable.safeZoneSize => RewardMenuAction.increaseSafeZoneSize,
      DifficultyVariable.safeZoneSpeed =>
        RewardMenuAction.increaseSafeZoneSpeed,
      DifficultyVariable.targetSpeed => RewardMenuAction.increaseTargetSpeed,
    };
  }

  factory RewardMenuAction.decreaseVariable(DifficultyVariable variable) {
    return switch (variable) {
      DifficultyVariable.ballSpeed => RewardMenuAction.decreaseBallSpeed,
      DifficultyVariable.ballSize => RewardMenuAction.decreaseBallSize,
      DifficultyVariable.stopTime => RewardMenuAction.decreaseStopTime,
      DifficultyVariable.safeZoneSize => RewardMenuAction.decreaseSafeZoneSize,
      DifficultyVariable.safeZoneSpeed =>
        RewardMenuAction.decreaseSafeZoneSpeed,
      DifficultyVariable.targetSpeed => RewardMenuAction.decreaseTargetSpeed,
    };
  }
}

extension DifficultyVariableMenuLabel on DifficultyVariable {
  String get menuLabel {
    return switch (this) {
      DifficultyVariable.ballSpeed => 'Increase ball speed',
      DifficultyVariable.ballSize => 'Increase ball size',
      DifficultyVariable.stopTime => 'Increase stop time',
      DifficultyVariable.safeZoneSize => 'Increase safe zone size',
      DifficultyVariable.safeZoneSpeed => 'Increase safe zone speed',
      DifficultyVariable.targetSpeed => 'Increase target speed',
    };
  }

  String get shortMenuLabel {
    return switch (this) {
      DifficultyVariable.ballSpeed => 'Ball speed',
      DifficultyVariable.ballSize => 'Ball size',
      DifficultyVariable.stopTime => 'Stop time',
      DifficultyVariable.safeZoneSize => 'Safe zone size',
      DifficultyVariable.safeZoneSpeed => 'Safe zone speed',
      DifficultyVariable.targetSpeed => 'Target speed',
    };
  }
}
