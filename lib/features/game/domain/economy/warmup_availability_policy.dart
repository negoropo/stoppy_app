import '../../../auth/domain/models/player_profile.dart';

class WarmupAvailabilityPolicy {
  const WarmupAvailabilityPolicy();

  static const int maximumGamePointsForWarmup = 9;

  bool isWarmupAvailable(PlayerProfile playerProfile) {
    // Warmup is a no-cost recovery mode. Players with 10 GP or more should use
    // normal competitive modes instead of farming the warmup safety path.
    return playerProfile.gamePoints <= maximumGamePointsForWarmup;
  }
}
