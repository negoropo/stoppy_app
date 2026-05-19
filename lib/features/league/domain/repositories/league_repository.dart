import '../../../auth/domain/models/player_profile.dart';
import '../models/league_player_entry.dart';
import '../models/league_ranking_entry.dart';
import '../models/league_ranking_snapshot.dart';
import '../models/league_season_id.dart';
import '../models/league_season_settlement_result.dart';
import '../models/player_league_records.dart';
import '../models/weekly_league_history_entry.dart';
import '../models/weekly_league_run.dart';

class LeagueRunSubmissionResult {
  const LeagueRunSubmissionResult({
    required this.accepted,
    required this.playerRecords,
  });

  final bool accepted;
  final PlayerLeagueRecords playerRecords;
}

abstract class LeagueRepository {
  Future<LeaguePlayerEntry?> currentEntry(String playerId);

  Future<List<LeagueRankingEntry>> fetchDivisionRanking(int divisionNumber);

  Future<LeaguePlayerEntry> enterWeeklyLeague(PlayerProfile profile);

  Future<LeagueRunSubmissionResult> submitLeagueRun(WeeklyLeagueRun run);

  Future<PlayerLeagueRecords> fetchPlayerRecords(String playerId);

  Future<List<WeeklyLeagueHistoryEntry>> fetchPlayerHistory(String playerId);

  Future<List<WeeklyLeagueRun>> fetchPlayerWeeklyRuns({
    required String playerId,
    required LeagueSeasonId seasonId,
  });

  Future<LeagueRankingSnapshot> fetchPlayerSnapshot({
    required String playerId,
    required int divisionNumber,
  });

  Future<LeagueSeasonSettlementResult> settleCurrentSeason({
    required DateTime now,
  });
}
