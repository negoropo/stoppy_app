import '../models/league_division_settlement.dart';
import '../models/league_ranking_entry.dart';
import '../models/league_season_id.dart';
import '../models/weekly_league_history_entry.dart';

class WeeklyLeagueHistoryGenerator {
  const WeeklyLeagueHistoryGenerator();

  WeeklyLeagueHistoryEntry generate({
    required LeagueSeasonId seasonId,
    required LeagueRankingEntry finalRankingEntry,
    required LeagueDivisionSettlement settlement,
  }) {
    final playerId = finalRankingEntry.playerEntry.playerId;

    // Settlement groups are the source of truth for season movement. Keeping
    // this decision here lets a future backend reproduce history entries from
    // final rankings and settlement output without trusting the client UI.
    final result = settlement.promotedPlayerIds.contains(playerId)
        ? WeeklyLeagueSeasonResult.promoted
        : settlement.relegatedPlayerIds.contains(playerId)
        ? WeeklyLeagueSeasonResult.relegated
        : WeeklyLeagueSeasonResult.stayed;

    return WeeklyLeagueHistoryEntry(
      playerId: playerId,
      seasonId: seasonId,
      finalRank: finalRankingEntry.rank,
      finalDivision: finalRankingEntry.playerEntry.divisionNumber,
      result: result,
      finalWeeklyScore: finalRankingEntry.weeklyScore.finalScore,
    );
  }
}
