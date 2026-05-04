import 'game_point_reward_result.dart';
import 'run_mode.dart';

class GamePointRewardCalculator {
  const GamePointRewardCalculator();

  static const int warmupCompletionThresholdPrecisionPoints = 10000;
  static const int completionGpAmount = 1;
  static const int dailyGpAmount = 2;

  GamePointRewardResult calculate({
    required RunMode runMode,
    required int totalPrecisionPoints,
    required DateTime runEndedAt,
    required DateTime? lastDailyGpAwardedAt,
  }) {
    final warmupThresholdReached =
        totalPrecisionPoints >= warmupCompletionThresholdPrecisionPoints;

    final completionGp = switch (runMode) {
      RunMode.league || RunMode.tournament => completionGpAmount,
      // Warmup exists as a recovery path for low-GP players. It only grants
      // completion GP when the run proves meaningful skill by reaching the
      // configured PP threshold.
      RunMode.warmup => warmupThresholdReached ? completionGpAmount : 0,
    };

    final dailyGpAwarded = !_isSameLocalCalendarDay(
      runEndedAt,
      lastDailyGpAwardedAt,
    );

    // Daily GP is intentionally tied to the first completed run ending on a
    // local calendar day. Backend validation can later replace this local date
    // source with server time without changing the reward contract.
    final dailyGp = dailyGpAwarded ? dailyGpAmount : 0;

    return GamePointRewardResult(
      completionGp: completionGp,
      dailyGp: dailyGp,
      dailyGpAwarded: dailyGpAwarded,
      warmupThresholdReached: warmupThresholdReached,
    );
  }

  bool _isSameLocalCalendarDay(DateTime runEndedAt, DateTime? awardedAt) {
    if (awardedAt == null) {
      return false;
    }

    final localRunEndedAt = runEndedAt.toLocal();
    final localAwardedAt = awardedAt.toLocal();

    return localRunEndedAt.year == localAwardedAt.year &&
        localRunEndedAt.month == localAwardedAt.month &&
        localRunEndedAt.day == localAwardedAt.day;
  }
}
