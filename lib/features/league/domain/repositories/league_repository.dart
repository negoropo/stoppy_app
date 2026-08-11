import 'package:stoppy_app/core/backend/idempotency_key.dart';

import '../../../auth/domain/models/player_profile.dart';
import '../models/league_player_entry.dart';
import '../models/league_ranking_entry.dart';
import '../models/league_ranking_snapshot.dart';
import '../models/league_season_id.dart';
import '../models/league_season_settlement_result.dart';
import '../models/player_league_achievements.dart';
import '../models/player_league_records.dart';
import '../models/weekly_league_history_entry.dart';
import '../models/weekly_league_run.dart';

class LeagueEntryResult extends LeaguePlayerEntry {
  LeagueEntryResult({
    required LeaguePlayerEntry entry,
    this.seasonId,
    this.remainingGamePoints,
    this.playerProfile,
  }) : super(
         playerId: entry.playerId,
         username: entry.username,
         divisionNumber: entry.divisionNumber,
         registeredAt: entry.registeredAt,
         hasReservedSlot: entry.hasReservedSlot,
         entryPaid: entry.entryPaid,
         lifetimeLeagueTournamentRuns: entry.lifetimeLeagueTournamentRuns,
         lifetimeAverageScorePerRun: entry.lifetimeAverageScorePerRun,
       );

  final LeagueSeasonId? seasonId;
  final int? remainingGamePoints;
  final PlayerProfile? playerProfile;
}

abstract interface class ServerAuthoritativeLeagueEntryRepository {}

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

  Future<LeaguePlayerEntry> enterWeeklyLeague(
    PlayerProfile profile, {
    IdempotencyKey? idempotencyKey,
  });

  Future<LeagueRunSubmissionResult> submitLeagueRun(WeeklyLeagueRun run);

  Future<PlayerLeagueRecords> fetchPlayerRecords(String playerId);

  Future<PlayerLeagueAchievements> fetchPlayerAchievements(String playerId);

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
