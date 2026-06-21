import 'package:stoppy_app/core/backend/backend_api_client.dart';
import 'package:stoppy_app/core/backend/backend_repository_not_configured.dart';
import 'package:stoppy_app/core/backend/api_contract.dart';
import 'package:stoppy_app/features/auth/domain/models/player_profile.dart';
import 'package:stoppy_app/features/league/domain/models/league_player_entry.dart';
import 'package:stoppy_app/features/league/domain/models/league_ranking_entry.dart';
import 'package:stoppy_app/features/league/domain/models/league_ranking_snapshot.dart';
import 'package:stoppy_app/features/league/domain/models/league_season_id.dart';
import 'package:stoppy_app/features/league/domain/models/league_season_settlement_result.dart';
import 'package:stoppy_app/features/league/domain/models/player_league_achievements.dart';
import 'package:stoppy_app/features/league/domain/models/player_league_records.dart';
import 'package:stoppy_app/features/league/domain/models/weekly_league_history_entry.dart';
import 'package:stoppy_app/features/league/domain/models/weekly_league_run.dart';
import 'package:stoppy_app/features/league/domain/repositories/league_repository.dart';

class BackendLeagueRepository implements LeagueRepository {
  const BackendLeagueRepository({this.apiClient});

  final BackendApiClient? apiClient;

  static const enterPath = ApiContract.leagueEntry;
  static const snapshotPath = ApiContract.leagueSnapshot;
  static const historyPath = ApiContract.leagueHistory;
  static const recordsPath = ApiContract.leagueRecords;
  static const achievementsPath = ApiContract.leagueAchievements;
  static const weeklyRunsPath = ApiContract.leagueRuns;
  static const leagueRunPath = ApiContract.leagueRunSubmission;

  BackendApiClient get _client {
    final client = apiClient;
    if (client == null) {
      return backendNotConnected('BackendLeagueRepository', 'apiClient');
    }
    return client;
  }

  @override
  Future<LeaguePlayerEntry?> currentEntry(String playerId) {
    final _ = _client;
    return backendNotConnected('BackendLeagueRepository', 'currentEntry');
  }

  @override
  Future<List<LeagueRankingEntry>> fetchDivisionRanking(int divisionNumber) {
    final _ = _client;
    return backendNotConnected(
      'BackendLeagueRepository',
      'fetchDivisionRanking',
    );
  }

  @override
  Future<LeaguePlayerEntry> enterWeeklyLeague(PlayerProfile profile) {
    final _ = _client;
    return backendNotConnected('BackendLeagueRepository', 'enterWeeklyLeague');
  }

  @override
  Future<LeagueRunSubmissionResult> submitLeagueRun(WeeklyLeagueRun run) {
    final _ = _client;
    return backendNotConnected('BackendLeagueRepository', 'submitLeagueRun');
  }

  @override
  Future<PlayerLeagueRecords> fetchPlayerRecords(String playerId) {
    final _ = _client;
    return backendNotConnected('BackendLeagueRepository', 'fetchPlayerRecords');
  }

  @override
  Future<PlayerLeagueAchievements> fetchPlayerAchievements(String playerId) {
    final _ = _client;
    return backendNotConnected(
      'BackendLeagueRepository',
      'fetchPlayerAchievements',
    );
  }

  @override
  Future<List<WeeklyLeagueHistoryEntry>> fetchPlayerHistory(String playerId) {
    final _ = _client;
    return backendNotConnected('BackendLeagueRepository', 'fetchPlayerHistory');
  }

  @override
  Future<List<WeeklyLeagueRun>> fetchPlayerWeeklyRuns({
    required String playerId,
    required LeagueSeasonId seasonId,
  }) {
    final _ = _client;
    return backendNotConnected(
      'BackendLeagueRepository',
      'fetchPlayerWeeklyRuns',
    );
  }

  @override
  Future<LeagueRankingSnapshot> fetchPlayerSnapshot({
    required String playerId,
    required int divisionNumber,
  }) {
    final _ = _client;
    return backendNotConnected(
      'BackendLeagueRepository',
      'fetchPlayerSnapshot',
    );
  }

  @override
  Future<LeagueSeasonSettlementResult> settleCurrentSeason({
    required DateTime now,
  }) {
    final _ = _client;
    return backendNotConnected(
      'BackendLeagueRepository',
      'settleCurrentSeason',
    );
  }
}
