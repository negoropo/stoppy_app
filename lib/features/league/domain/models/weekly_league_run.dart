import 'league_season_id.dart';

class WeeklyLeagueRun {
  const WeeklyLeagueRun({
    required this.playerId,
    required this.score,
    required this.completedAt,
    this.id,
    this.seasonId,
    this.startedAt,
    this.levelReached,
    this.precisionPointTier,
  }) : assert(score >= 0);

  /// Local/mock ownership still needs a player ID for in-memory ranking.
  ///
  /// Backend submissions must not treat this as authentication authority; the
  /// authenticated API session owns player identity server-side.
  final String playerId;
  final int score;
  final DateTime completedAt;
  final String? id;
  final LeagueSeasonId? seasonId;
  final DateTime? startedAt;
  final int? levelReached;
  final int? precisionPointTier;
}
