import 'league_season_id.dart';

class WeeklyLeagueHistoryEntry {
  const WeeklyLeagueHistoryEntry({
    required this.playerId,
    required this.seasonId,
    required this.finalRank,
    required this.finalDivision,
    required this.result,
    required this.finalWeeklyScore,
    this.seasonEndedAt,
  }) : assert(finalRank > 0),
       assert(finalDivision > 0),
       assert(finalWeeklyScore >= 0);

  final String playerId;
  final LeagueSeasonId seasonId;
  final int finalRank;
  final int finalDivision;
  final WeeklyLeagueSeasonResult result;
  final double finalWeeklyScore;

  /// Stored separately from seasonId to simplify UI ordering and backend sync.
  final DateTime? seasonEndedAt;

  WeeklyLeagueHistoryEntry copyWith({
    String? playerId,
    LeagueSeasonId? seasonId,
    int? finalRank,
    int? finalDivision,
    WeeklyLeagueSeasonResult? result,
    double? finalWeeklyScore,
    Object? seasonEndedAt = _sentinel,
  }) {
    return WeeklyLeagueHistoryEntry(
      playerId: playerId ?? this.playerId,
      seasonId: seasonId ?? this.seasonId,
      finalRank: finalRank ?? this.finalRank,
      finalDivision: finalDivision ?? this.finalDivision,
      result: result ?? this.result,
      finalWeeklyScore: finalWeeklyScore ?? this.finalWeeklyScore,
      seasonEndedAt: identical(seasonEndedAt, _sentinel)
          ? this.seasonEndedAt
          : seasonEndedAt as DateTime?,
    );
  }
}

enum WeeklyLeagueSeasonResult {
  promoted,
  relegated,
  stayed,
  removedFromLeague,
  lostReservedSlot,
}

const Object _sentinel = Object();
