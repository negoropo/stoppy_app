class PlayerLeagueAchievements {
  const PlayerLeagueAchievements({
    required this.playerId,
    this.bestDivisionReached,
    this.promotions = 0,
    this.relegations = 0,
  }) : assert(playerId != ''),
       assert(bestDivisionReached == null || bestDivisionReached > 0),
       assert(promotions >= 0),
       assert(relegations >= 0);

  factory PlayerLeagueAchievements.empty(String playerId) {
    return PlayerLeagueAchievements(playerId: playerId);
  }

  final String playerId;
  final int? bestDivisionReached;
  final int promotions;
  final int relegations;

  PlayerLeagueAchievements copyWith({
    String? playerId,
    int? bestDivisionReached,
    int? promotions,
    int? relegations,
  }) {
    return PlayerLeagueAchievements(
      playerId: playerId ?? this.playerId,
      bestDivisionReached: bestDivisionReached ?? this.bestDivisionReached,
      promotions: promotions ?? this.promotions,
      relegations: relegations ?? this.relegations,
    );
  }
}
