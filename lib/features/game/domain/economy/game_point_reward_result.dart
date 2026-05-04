class GamePointRewardResult {
  const GamePointRewardResult({
    required this.completionGp,
    required this.dailyGp,
    required this.dailyGpAwarded,
    required this.warmupThresholdReached,
  });

  final int completionGp;
  final int dailyGp;
  final bool dailyGpAwarded;
  final bool warmupThresholdReached;

  int get totalGp {
    return completionGp + dailyGp;
  }
}
