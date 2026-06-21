import 'package:flutter_test/flutter_test.dart';
import 'package:stoppy_app/core/backend/api_error.dart';
import 'package:stoppy_app/features/league/data/dto/league_persistence_dtos.dart';
import 'package:stoppy_app/features/league/domain/models/league_division.dart';
import 'package:stoppy_app/features/league/domain/models/league_player_entry.dart';
import 'package:stoppy_app/features/league/domain/models/league_season_id.dart';
import 'package:stoppy_app/features/league/domain/models/player_league_achievements.dart';
import 'package:stoppy_app/features/league/domain/models/player_league_records.dart';
import 'package:stoppy_app/features/league/domain/models/weekly_league_history_entry.dart';
import 'package:stoppy_app/features/league/domain/models/weekly_league_score.dart';

void main() {
  test('league persisted DTOs round-trip domain entities', () {
    final season = LeagueSeasonId(weekStartDate: DateTime(2026, 6, 15));
    final division = LeagueDivision(number: 2);
    final entry = LeaguePlayerEntry(
      playerId: 'player-1',
      username: 'Tester',
      divisionNumber: 2,
      registeredAt: DateTime.utc(2026, 6, 15),
      entryPaid: true,
      lifetimeLeagueTournamentRuns: 12,
      lifetimeAverageScorePerRun: 345.5,
    );
    final score = WeeklyLeagueScore(
      playerId: 'player-1',
      isActive: true,
      runCount: 6,
      activeDays: 2,
      activityMultiplier: 1.1,
      baseScore: 950,
      finalScore: 1045,
      bonusPoints: 95,
      countedRunScores: [1000, 900],
      allRunScores: [1000, 900, 800, 700, 600, 500],
    );
    final history = WeeklyLeagueHistoryEntry(
      playerId: 'player-1',
      seasonId: season,
      finalRank: 3,
      finalDivision: 2,
      result: WeeklyLeagueSeasonResult.stayed,
      finalWeeklyScore: 1045,
      seasonEndedAt: DateTime.utc(2026, 6, 21, 23, 59),
    );
    final records = PlayerLeagueRecords(
      playerId: 'player-1',
      allTimeBestFinalScore: 2000,
      currentWeeklyBestScore: 1045,
      currentSeasonId: season,
    );
    const achievements = PlayerLeagueAchievements(
      playerId: 'player-1',
      bestDivisionReached: 2,
      promotions: 1,
      relegations: 0,
    );

    expect(
      LeagueDivisionDto.fromJson(
        LeagueDivisionDto.fromDomain(division).toJson(),
      ).toDomain().capacity,
      division.capacity,
    );
    expect(
      LeaguePlayerEntryDto.fromJson(
        LeaguePlayerEntryDto.fromDomain(entry).toJson(),
      ).toDomain().username,
      entry.username,
    );
    expect(
      WeeklyLeagueScoreDto.fromJson(
        WeeklyLeagueScoreDto.fromDomain(score).toJson(),
      ).toDomain().finalScore,
      score.finalScore,
    );
    expect(
      WeeklyLeagueHistoryEntryDto.fromJson(
        WeeklyLeagueHistoryEntryDto.fromDomain(history).toJson(),
      ).toDomain().seasonId.value,
      season.value,
    );
    expect(
      PlayerLeagueRecordsDto.fromJson(
        PlayerLeagueRecordsDto.fromDomain(records).toJson(),
      ).toDomain().allTimeBestFinalScore,
      records.allTimeBestFinalScore,
    );
    expect(
      PlayerLeagueAchievementsDto.fromJson(
        PlayerLeagueAchievementsDto.fromDomain(achievements).toJson(),
      ).toDomain().promotions,
      1,
    );
  });

  test('league DTO rejects malformed persisted data', () {
    expect(
      () => LeaguePlayerEntryDto.fromJson({
        'playerId': 'player-1',
        'username': 'Tester',
        'divisionNumber': 'two',
        'registeredAt': '2026-06-15T00:00:00.000Z',
      }),
      throwsA(
        isA<ApiException>().having(
          (exception) => exception.error.code,
          'code',
          ApiErrorCode.malformedPayload,
        ),
      ),
    );
  });
}
