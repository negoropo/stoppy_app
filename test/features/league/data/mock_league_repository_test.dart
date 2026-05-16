import 'package:flutter_test/flutter_test.dart';
import 'package:stoppy_app/features/auth/domain/models/player_profile.dart';
import 'package:stoppy_app/features/league/data/mock_league_repository.dart';
import 'package:stoppy_app/features/league/domain/models/league_season_id.dart';
import 'package:stoppy_app/features/league/domain/models/weekly_league_run.dart';

void main() {
  group('MockLeagueRepository', () {
    test('creates an active weekly entry without deducting GP', () async {
      final repository = MockLeagueRepository();
      final playerProfile = PlayerProfile(
        id: 'player-id',
        username: 'Tester',
        createdAt: DateTime(2026),
        gamePoints: 10,
      );

      final entry = await repository.enterWeeklyLeague(playerProfile);
      final currentEntry = await repository.currentEntry(playerProfile.id);

      expect(entry.playerId, playerProfile.id);
      expect(entry.isActive, isTrue);
      expect(entry.divisionNumber, 2);
      expect(currentEntry?.isActive, isTrue);
      expect(playerProfile.gamePoints, 10);
    });

    test('supports runtime league score submissions', () async {
      final repository = MockLeagueRepository();
      final playerProfile = PlayerProfile(
        id: 'player-id',
        username: 'Tester',
        createdAt: DateTime(2026),
      );
      final entry = await repository.enterWeeklyLeague(playerProfile);

      await repository.submitLeagueRun(
        WeeklyLeagueRun(
          playerId: playerProfile.id,
          score: 50000,
          completedAt: DateTime(2026, 5, 8),
        ),
      );
      final ranking = await repository.fetchDivisionRanking(
        entry.divisionNumber,
      );

      expect(ranking.first.playerEntry.playerId, playerProfile.id);
      expect(ranking.first.weeklyScore.finalScore, 50000);
      final records = await repository.fetchPlayerRecords(playerProfile.id);
      expect(records.allTimeBestFinalScore, 50000);
      expect(records.currentWeeklyBestScore, 50000);
    });

    test('entering weekly league twice returns same active entry', () async {
      final repository = MockLeagueRepository();
      final playerProfile = PlayerProfile(
        id: 'player-id',
        username: 'Tester',
        createdAt: DateTime(2026),
      );

      final firstEntry = await repository.enterWeeklyLeague(playerProfile);
      final secondEntry = await repository.enterWeeklyLeague(playerProfile);

      expect(secondEntry.playerId, firstEntry.playerId);
      expect(secondEntry.divisionNumber, firstEntry.divisionNumber);
      expect(secondEntry.entryPaid, isTrue);
      expect(identical(secondEntry, firstEntry), isTrue);
    });

    test('fetchPlayerSnapshot is safe with no seeded divisions', () async {
      final repository = MockLeagueRepository(seedMockData: false);
      final playerProfile = PlayerProfile(
        id: 'player-id',
        username: 'Tester',
        createdAt: DateTime(2026),
      );
      final entry = await repository.enterWeeklyLeague(playerProfile);

      final snapshot = await repository.fetchPlayerSnapshot(
        playerId: playerProfile.id,
        divisionNumber: entry.divisionNumber,
      );

      expect(
        snapshot.currentPlayerEntry.playerEntry.playerId,
        playerProfile.id,
      );
      expect(snapshot.scoreNeededToStayInDivision, isNull);
    });

    test(
      'fetches requested weekly runs sorted by score then recency',
      () async {
        final repository = MockLeagueRepository(seedMockData: false);
        final playerProfile = PlayerProfile(
          id: 'player-id',
          username: 'Tester',
          createdAt: DateTime(2026),
        );
        final otherPlayerProfile = PlayerProfile(
          id: 'other-player',
          username: 'Other',
          createdAt: DateTime(2026),
        );
        await repository.enterWeeklyLeague(playerProfile);
        await repository.enterWeeklyLeague(otherPlayerProfile);
        await repository.submitLeagueRun(
          WeeklyLeagueRun(
            playerId: playerProfile.id,
            score: 500,
            completedAt: DateTime(2026, 5, 12, 10),
          ),
        );
        await repository.submitLeagueRun(
          WeeklyLeagueRun(
            playerId: playerProfile.id,
            score: 700,
            completedAt: DateTime(2026, 5, 13, 10),
          ),
        );
        await repository.submitLeagueRun(
          WeeklyLeagueRun(
            playerId: playerProfile.id,
            score: 700,
            completedAt: DateTime(2026, 5, 14, 10),
          ),
        );
        await repository.submitLeagueRun(
          WeeklyLeagueRun(
            playerId: 'other-player',
            score: 999,
            completedAt: DateTime(2026, 5, 14, 10),
          ),
        );
        await repository.submitLeagueRun(
          WeeklyLeagueRun(
            playerId: playerProfile.id,
            score: 900,
            completedAt: DateTime(2026, 5, 5, 10),
          ),
        );

        final runs = await repository.fetchPlayerWeeklyRuns(
          playerId: playerProfile.id,
          seasonId: LeagueSeasonId.fromDate(DateTime(2026, 5, 12)),
        );

        expect(runs.map((run) => run.score), [700, 700, 500]);
        expect(runs.map((run) => run.completedAt.day), [14, 13, 12]);
      },
    );
  });
}
