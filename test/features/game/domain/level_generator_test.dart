import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:stoppy_app/features/game/domain/level_generator.dart';
import 'package:stoppy_app/features/game/domain/models/difficulty_state.dart';
import 'package:stoppy_app/features/game/domain/models/movement_direction.dart';

void main() {
  group('DifficultyState', () {
    test('initial state has all levels at 0', () {
      const state = DifficultyState.initial();

      expect(state.levels, everyElement(0));
      expect(state.isMaxed, isFalse);
    });

    test('difficulty levels cannot exceed 10', () {
      expect(
        () => DifficultyState(
          ballSpeedLevel: 11,
          ballSizeLevel: 0,
          stopTimeLevel: 0,
          safeZoneSizeLevel: 0,
          safeZoneSpeedLevel: 0,
          targetSpeedLevel: 0,
        ),
        throwsArgumentError,
      );
    });

    test('exactly one non-maxed variable increases after success', () {
      final generator = LevelGenerator(random: math.Random(1));
      const state = DifficultyState.initial();

      final nextState = generator.increaseDifficultyAfterSuccess(state);
      final changedLevels = List.generate(
        state.levels.length,
        (index) => nextState.levels[index] - state.levels[index],
      );

      expect(identical(state, nextState), isFalse);
      expect(changedLevels.where((change) => change == 1), hasLength(1));
      expect(changedLevels.where((change) => change != 0), hasLength(1));
    });

    test('maxed variables are not selected for increase', () {
      final generator = LevelGenerator(random: math.Random(3));
      final state = DifficultyState(
        ballSpeedLevel: 10,
        ballSizeLevel: 10,
        stopTimeLevel: 10,
        safeZoneSizeLevel: 10,
        safeZoneSpeedLevel: 10,
        targetSpeedLevel: 9,
      );

      final nextState = generator.increaseDifficultyAfterSuccess(state);

      expect(nextState.levels, [10, 10, 10, 10, 10, 10]);
    });

    test('advanceDifficulty reports the increased variable', () {
      final generator = LevelGenerator(random: math.Random(1));
      const state = DifficultyState.initial();

      final result = generator.advanceDifficulty(state);
      final changedLevels = List.generate(
        state.levels.length,
        (index) => result.difficultyState.levels[index] - state.levels[index],
      );

      expect(result.increasedVariable, isNotNull);
      expect(changedLevels.where((change) => change == 1), hasLength(1));
      expect(changedLevels.where((change) => change != 0), hasLength(1));
    });

    test('advanceDifficulty keeps maxed state unchanged', () {
      final generator = LevelGenerator(random: math.Random(1));
      final state = DifficultyState(
        ballSpeedLevel: 10,
        ballSizeLevel: 10,
        stopTimeLevel: 10,
        safeZoneSizeLevel: 10,
        safeZoneSpeedLevel: 10,
        targetSpeedLevel: 10,
      );

      final result = generator.advanceDifficulty(state);

      expect(result.difficultyState, same(state));
      expect(result.increasedVariable, isNull);
    });
  });

  group('LevelGenerator', () {
    test('creates the initial difficulty state', () {
      final generator = LevelGenerator(random: math.Random(1));

      expect(generator.createInitialDifficultyState().levels, everyElement(0));
    });

    test('stop time table matches Game_Rules.md', () {
      const expectedSeconds = [30, 27, 24, 21, 18, 15, 13, 11, 9, 7, 5];

      for (var level = 0; level < expectedSeconds.length; level += 1) {
        expect(
          LevelGenerator.stopTimeLimitForLevel(level),
          Duration(seconds: expectedSeconds[level]),
        );
      }
    });

    test('safe zone size levels convert correctly to radians', () {
      expect(
        LevelGenerator.safeZoneSweepAngleForLevel(0),
        closeTo(math.pi * 2 * 0.55, 0.0001),
      );
      expect(
        LevelGenerator.safeZoneSweepAngleForLevel(10),
        closeTo(math.pi * 2 * 0.05, 0.0001),
      );
    });

    test(
      'target speed is never equal to safe zone speed for the same level',
      () {
        for (
          var level = DifficultyState.minLevel;
          level <= DifficultyState.maxLevel;
          level += 1
        ) {
          expect(
            LevelGenerator.targetRotationDurationForLevel(level),
            isNot(LevelGenerator.safeZoneRotationDurationForLevel(level)),
          );
        }
      },
    );

    test('target level 10 is faster than safe zone level 10', () {
      final targetDuration = LevelGenerator.targetRotationDurationForLevel(10)!;
      final safeZoneDuration = LevelGenerator.safeZoneRotationDurationForLevel(
        10,
      )!;

      expect(targetDuration, lessThan(safeZoneDuration));
    });

    test('level 0 safe zone and target rotations are stopped', () {
      expect(
        LevelGenerator.isRotationStopped(
          LevelGenerator.safeZoneRotationDurationForLevel(0),
        ),
        isTrue,
      );
      expect(
        LevelGenerator.isRotationStopped(
          LevelGenerator.targetRotationDurationForLevel(0),
        ),
        isTrue,
      );
    });

    test('generated angles are valid radians between 0 and 2pi', () {
      final generator = LevelGenerator(random: math.Random(5));
      final config = generator.generateLevelConfig(
        const DifficultyState.initial(),
      );

      expect(config.ballStartAngle, inExclusiveRange(0, math.pi * 2));
      expect(config.safeZoneStartAngle, inExclusiveRange(0, math.pi * 2));
      expect(config.targetStartAngle, inExclusiveRange(0, math.pi * 2));
    });

    test('safe zone and target direction are opposite of ball direction', () {
      const clockwiseConfig = DifficultyState.initial();
      final generator = LevelGenerator(random: math.Random(2));
      final config = generator.generateLevelConfig(clockwiseConfig);

      expect(
        config.safeZoneDirection,
        oppositeMovementDirection(config.ballDirection),
      );
      expect(
        config.targetDirection,
        oppositeMovementDirection(config.ballDirection),
      );
    });

    test('opposite movement direction helper flips both directions', () {
      expect(
        oppositeMovementDirection(MovementDirection.clockwise),
        MovementDirection.counterClockwise,
      );
      expect(
        oppositeMovementDirection(MovementDirection.counterClockwise),
        MovementDirection.clockwise,
      );
    });
  });
}
