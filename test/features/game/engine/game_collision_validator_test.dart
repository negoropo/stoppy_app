import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:stoppy_app/features/game/engine/game_collision_validator.dart';

void main() {
  group('GameCollisionValidator', () {
    const validator = GameCollisionValidator(circleRadius: 100, ballRadius: 10);

    test('normalizes angles into one circle rotation', () {
      expect(
        GameCollisionValidator.normalizeAngle(-math.pi / 2),
        closeTo(math.pi * 1.5, 0),
      );
      expect(
        GameCollisionValidator.normalizeAngle(math.pi * 2 + math.pi / 4),
        closeTo(math.pi / 4, 0),
      );
    });

    test('detects angles inside a safe zone crossing zero radians', () {
      const crossingValidator = GameCollisionValidator(
        circleRadius: 100,
        ballRadius: 10,
        safeZoneStartAngle: math.pi * 1.75,
        safeZoneSweepAngle: math.pi / 2,
      );

      expect(crossingValidator.isAngleInsideSafeZone(0), isTrue);
      expect(crossingValidator.isAngleInsideSafeZone(math.pi), isFalse);
    });

    test('calculates shortest angular distance across zero radians', () {
      final distance = validator.angularDistance(
        math.pi * 1.95,
        math.pi * 0.05,
      );

      expect(distance, closeTo(math.pi * 0.1, 0.0001));
    });

    test('validates target hits using angular tolerance', () {
      const targetValidator = GameCollisionValidator(
        circleRadius: 100,
        ballRadius: 10,
        targetAngle: math.pi / 2,
        targetToleranceAngle: 0.1,
      );

      final targetHit = targetValidator.validateAngle(
        ballAngle: math.pi / 2 + 0.05,
      );
      final targetMiss = targetValidator.validateAngle(
        ballAngle: math.pi / 2 + 0.25,
      );

      expect(targetHit.isTargetHit, isTrue);
      expect(targetMiss.isTargetHit, isFalse);
    });

    test('converts ball radius into angular radius', () {
      expect(validator.ballAngularRadius, closeTo(math.asin(0.1), 0.0001));
    });

    test('returns the ball angular interval around its center angle', () {
      final result = validator.validateAngle(ballAngle: 0);

      expect(
        result.ballStartAngle,
        closeTo(
          GameCollisionValidator.fullCircleRadians -
              validator.ballAngularRadius,
          0.0001,
        ),
      );
      expect(result.ballEndAngle, closeTo(validator.ballAngularRadius, 0.0001));
      expect(result.ballAngularRadius, closeTo(validator.ballAngularRadius, 0));
    });

    test('counts safe zone edge contact when ball overlaps the arc', () {
      const edgeContactValidator = GameCollisionValidator(
        circleRadius: 100,
        ballRadius: 10,
        safeZoneStartAngle: 0,
        safeZoneSweepAngle: 0.5,
      );

      final contactAngle = -edgeContactValidator.ballAngularRadius / 2;
      final missAngle = -edgeContactValidator.ballAngularRadius * 1.5;

      expect(edgeContactValidator.isAngleInsideSafeZone(contactAngle), isTrue);
      expect(edgeContactValidator.isAngleInsideSafeZone(missAngle), isFalse);
    });

    test('counts target edge contact when ball overlaps the target marker', () {
      const targetValidator = GameCollisionValidator(
        circleRadius: 100,
        ballRadius: 10,
        targetAngle: 1,
        targetToleranceAngle: 0.05,
      );

      final contactResult = targetValidator.validateAngle(ballAngle: 1.14);
      final missResult = targetValidator.validateAngle(ballAngle: 1.17);

      expect(contactResult.isTargetHit, isTrue);
      expect(missResult.isTargetHit, isFalse);
    });

    test('can report a target hit while missing the safe zone', () {
      const targetOnlyValidator = GameCollisionValidator(
        circleRadius: 100,
        ballRadius: 10,
        safeZoneStartAngle: 3,
        safeZoneSweepAngle: 0.4,
        targetAngle: 1,
        targetToleranceAngle: 0.05,
      );

      final result = targetOnlyValidator.validateAngle(ballAngle: 1);

      expect(result.isInsideSafeZone, isFalse);
      expect(result.isTargetHit, isTrue);
    });
  });
}
