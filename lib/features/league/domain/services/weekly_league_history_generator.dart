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
    DateTime? seasonEndedAt,
  }) {
    final playerId = finalRankingEntry.playerEntry.playerId;

    // Settlement groups are the source of truth for season movement. Keeping
    // this decision here lets a future backend reproduce history entries from
    // final rankings and settlement output without trusting the client UI.
    final lostReservation = settlement.lostReservationPlayerIds.contains(
      playerId,
    );
    final relegated = settlement.relegatedPlayerIds.contains(playerId);
    final result = lostReservation && relegated
        ? WeeklyLeagueSeasonResult.removedFromLeague
        : lostReservation
        ? WeeklyLeagueSeasonResult.lostReservedSlot
        : settlement.promotedPlayerIds.contains(playerId)
        ? WeeklyLeagueSeasonResult.promoted
        : relegated
        ? WeeklyLeagueSeasonResult.relegated
        : WeeklyLeagueSeasonResult.stayed;

    return WeeklyLeagueHistoryEntry(
      playerId: playerId,
      seasonId: seasonId,
      finalRank: finalRankingEntry.rank,
      finalDivision: finalRankingEntry.playerEntry.divisionNumber,
      result: result,
      finalWeeklyScore: finalRankingEntry.weeklyScore.finalScore,
      seasonEndedAt: seasonEndedAt,
    );
  }
}
