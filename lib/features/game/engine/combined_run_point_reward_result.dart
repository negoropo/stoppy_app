import 'run_point_reward_result.dart';
import 'target_run_point_bonus_result.dart';

class CombinedRunPointRewardResult {
  const CombinedRunPointRewardResult({
    required this.safeZoneRewardResult,
    required this.targetBonusResult,
  });

  final RunPointRewardResult safeZoneRewardResult;
  final TargetRunPointBonusResult targetBonusResult;

  int get totalRpAmount {
    return safeZoneRewardResult.rpAmount + targetBonusResult.rpAmount;
  }
}
