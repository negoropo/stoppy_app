import 'run_point_reward_tier.dart';

class RunPointRewardResult {
  const RunPointRewardResult({
    required this.rewardTier,
    required this.rpAmount,
    required this.rewarded,
  });

  final RunPointRewardTier rewardTier;
  final int rpAmount;
  final bool rewarded;
}
