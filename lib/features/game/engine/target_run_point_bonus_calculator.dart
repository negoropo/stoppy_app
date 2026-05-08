import 'target_run_point_bonus_result.dart';

class TargetRunPointBonusCalculator {
  const TargetRunPointBonusCalculator();

  TargetRunPointBonusResult calculate({
    required bool isTargetHit,
    required int basePrecisionPoints,
  }) {
    if (!isTargetHit) {
      return const TargetRunPointBonusResult(rpAmount: 0, message: null);
    }

    // Target bonus RP uses base PP before the run-level multiplier. This keeps
    // the target bonus tied only to geometric target precision, not progression
    // scaling.
    if (basePrecisionPoints == 1000) {
      return const TargetRunPointBonusResult(
        rpAmount: 10,
        message:
            'Perfect hit! You stopped the center of the ball exactly on the target and earned +10 RP.',
      );
    }

    if (basePrecisionPoints >= 997) {
      return const TargetRunPointBonusResult(
        rpAmount: 5,
        message:
            'So close! You were extremely close to a perfect target hit and earned +5 RP.',
      );
    }

    if (basePrecisionPoints >= 990) {
      return const TargetRunPointBonusResult(
        rpAmount: 3,
        message:
            'Great shot! You were close to a perfect target hit and earned +3 RP.',
      );
    }

    return const TargetRunPointBonusResult(
      rpAmount: 2,
      message: 'Target hit! You earned +2 RP.',
    );
  }
}
