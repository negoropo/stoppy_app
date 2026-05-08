class WeeklyLeagueRun {
  const WeeklyLeagueRun({
    required this.playerId,
    required this.score,
    required this.completedAt,
  }) : assert(score >= 0);

  final String playerId;
  final int score;
  final DateTime completedAt;
}
