import '../../../auth/domain/models/player_profile.dart';
import '../models/league_player_entry.dart';
import '../models/league_ranking_entry.dart';
import '../models/league_ranking_snapshot.dart';
import '../models/weekly_league_run.dart';

abstract class LeagueRepository {
  Future<LeaguePlayerEntry?> currentEntry(String playerId);

  Future<List<LeagueRankingEntry>> fetchDivisionRanking(int divisionNumber);

  Future<LeaguePlayerEntry> enterWeeklyLeague(PlayerProfile profile);

  Future<void> submitLeagueRun(WeeklyLeagueRun run);

  Future<LeagueRankingSnapshot> fetchPlayerSnapshot({
    required String playerId,
    required int divisionNumber,
  });
}
