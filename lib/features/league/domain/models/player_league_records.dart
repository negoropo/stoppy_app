import 'league_season_id.dart';

const Object _sentinel = Object();

class PlayerLeagueRecords {
  const PlayerLeagueRecords({
    required this.playerId,
    required this.allTimeBestFinalScore,
    required this.currentWeeklyBestScore,
    this.currentSeasonId,
  }) : assert(allTimeBestFinalScore >= 0),
       assert(currentWeeklyBestScore >= 0);

  factory PlayerLeagueRecords.empty(String playerId) {
    return PlayerLeagueRecords(
      playerId: playerId,
      allTimeBestFinalScore: 0,
      currentWeeklyBestScore: 0,
    );
  }

  final String playerId;
  final int allTimeBestFinalScore;
  final int currentWeeklyBestScore;

  /// Stored so weekly records can reset cleanly when a new league season starts.
  final LeagueSeasonId? currentSeasonId;

  PlayerLeagueRecords copyWith({
    String? playerId,
    int? allTimeBestFinalScore,
    int? currentWeeklyBestScore,
    Object? currentSeasonId = _sentinel,
  }) {
    return PlayerLeagueRecords(
      playerId: playerId ?? this.playerId,
      allTimeBestFinalScore:
          allTimeBestFinalScore ?? this.allTimeBestFinalScore,
      currentWeeklyBestScore:
          currentWeeklyBestScore ?? this.currentWeeklyBestScore,
      currentSeasonId: identical(currentSeasonId, _sentinel)
          ? this.currentSeasonId
          : currentSeasonId as LeagueSeasonId?,
    );
  }
}
