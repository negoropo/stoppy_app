import 'hit_validation_result.dart';
import 'run_point_reward_result.dart';
import 'run_point_reward_tier.dart';

class RunPointRewardCalculator {
  const RunPointRewardCalculator();

  RunPointRewardResult calculate(HitValidationResult hitResult) {
    // RP is awarded only from the center position inside the real safe zone.
    // Edge-only safe-zone contact leaves this value null and awards no RP.
    final relativePosition = hitResult.relativePositionInSafeZone;

    if (relativePosition == null) {
      return _resultForTier(RunPointRewardTier.none);
    }

    return _resultForTier(_tierForRelativePosition(relativePosition));
  }

  RunPointRewardTier _tierForRelativePosition(double relativePosition) {
    // The safe zone is split from edge to center and mirrored back to the
    // opposite edge: outer 10% is Gold, next 15% is Silver, and the middle 50%
    // is Bronze. Boundaries intentionally move into the lower tier after the
    // exact threshold so every position maps to one deterministic reward.
    if (relativePosition < 0.10 || relativePosition >= 0.90) {
      return RunPointRewardTier.gold;
    }

    if (relativePosition < 0.25 || relativePosition >= 0.75) {
      return RunPointRewardTier.silver;
    }

    return RunPointRewardTier.bronze;
  }

  RunPointRewardResult _resultForTier(RunPointRewardTier rewardTier) {
    return RunPointRewardResult(
      rewardTier: rewardTier,
      rpAmount: rewardTier.rpAmount,
      rewarded: rewardTier != RunPointRewardTier.none,
    );
  }
}
