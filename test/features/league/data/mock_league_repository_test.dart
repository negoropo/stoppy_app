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
      expect(entry.divisionNumber, greaterThanOrEqualTo(1));
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

    test(
      're-entry after reserved slot loss activates a last division slot',
      () async {
        final repository = MockLeagueRepository(seedMockData: false);
        const playerCount = 15;
        for (var index = 0; index < playerCount; index += 1) {
          await repository.enterWeeklyLeague(
            PlayerProfile(
              id: 'player-$index',
              username: 'Player $index',
              createdAt: DateTime(2026, 1, index + 1),
            ),
          );
        }

        await repository.settleCurrentSeason(
          now: DateTime(2026, 5, 17, 23, 59),
        );

        final penultimateEntries = <String>[];
        final lastDivisionEntries = <String>[];
        for (var index = 0; index < playerCount; index += 1) {
          final entry = await repository.currentEntry('player-$index');
          if (entry?.divisionNumber == 1) {
            penultimateEntries.add(entry!.playerId);
          } else if (entry?.divisionNumber == 2) {
            lastDivisionEntries.add(entry!.playerId);
          }
        }
        for (final playerId in penultimateEntries) {
          await _reactivateEntry(repository, playerId);
        }
        await _reactivateEntry(repository, lastDivisionEntries.first);
        final reentryPlayerId = lastDivisionEntries[1];

        await repository.settleCurrentSeason(
          now: DateTime(2026, 5, 24, 23, 59),
        );
        final lostSlotEntry = await repository.currentEntry(reentryPlayerId);
        expect(lostSlotEntry?.hasReservedSlot, isFalse);

        final reenteredEntry = await repository.enterWeeklyLeague(
          PlayerProfile(
            id: reentryPlayerId,
            username: reentryPlayerId,
            createdAt: DateTime(2026, 1, 1),
          ),
        );

        expect(reenteredEntry.divisionNumber, 2);
        expect(reenteredEntry.entryPaid, isTrue);
        expect(reenteredEntry.hasReservedSlot, isTrue);
        expect(
          (await repository.currentEntry(reentryPlayerId)),
          reenteredEntry,
        );
      },
    );

    test(
      'league run submission is rejected after reserved slot loss',
      () async {
        final repository = MockLeagueRepository(seedMockData: false);
        const playerCount = 15;
        for (var index = 0; index < playerCount; index += 1) {
          await repository.enterWeeklyLeague(
            PlayerProfile(
              id: 'player-$index',
              username: 'Player $index',
              createdAt: DateTime(2026, 1, index + 1),
            ),
          );
        }

        await repository.settleCurrentSeason(
          now: DateTime(2026, 5, 17, 23, 59),
        );

        final penultimateEntries = <String>[];
        final lastDivisionEntries = <String>[];
        for (var index = 0; index < playerCount; index += 1) {
          final entry = await repository.currentEntry('player-$index');
          if (entry?.divisionNumber == 1) {
            penultimateEntries.add(entry!.playerId);
          } else if (entry?.divisionNumber == 2) {
            lastDivisionEntries.add(entry!.playerId);
          }
        }
        for (final playerId in penultimateEntries) {
          await _reactivateEntry(repository, playerId);
        }
        await _reactivateEntry(repository, lastDivisionEntries.first);
        final outsideLeaguePlayerId = lastDivisionEntries[1];

        await repository.settleCurrentSeason(
          now: DateTime(2026, 5, 24, 23, 59),
        );
        expect(
          (await repository.currentEntry(
            outsideLeaguePlayerId,
          ))?.hasReservedSlot,
          isFalse,
        );

        final submission = await repository.submitLeagueRun(
          WeeklyLeagueRun(
            playerId: outsideLeaguePlayerId,
            score: 5000,
            completedAt: DateTime(2026, 5, 25),
          ),
        );

        expect(submission.accepted, isFalse);
        final ranking = await repository.fetchDivisionRanking(2);
        expect(
          ranking.map((entry) => entry.playerEntry.playerId),
          isNot(contains(outsideLeaguePlayerId)),
        );
      },
    );

    test(
      'entry creates a new last division when current last division is full',
      () async {
        final repository = MockLeagueRepository(seedMockData: false);
        for (var index = 0; index < 30; index += 1) {
          await repository.enterWeeklyLeague(
            PlayerProfile(
              id: 'player-$index',
              username: 'Player $index',
              createdAt: DateTime(2026, 1, index + 1),
            ),
          );
        }

        final newEntry = await repository.enterWeeklyLeague(
          PlayerProfile(
            id: 'reentry-player',
            username: 'Reentry Player',
            createdAt: DateTime(2026, 2, 1),
          ),
        );

        expect(newEntry.divisionNumber, 3);
        expect(newEntry.entryPaid, isTrue);
        expect(newEntry.hasReservedSlot, isTrue);
        final divisionThreeRanking = await repository.fetchDivisionRanking(3);
        expect(
          divisionThreeRanking.single.playerEntry.playerId,
          'reentry-player',
        );
      },
    );

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

    test('settlement is skipped before Sunday 23:59', () async {
      final repository = MockLeagueRepository(seedMockData: false);
      final playerProfile = PlayerProfile(
        id: 'player-id',
        username: 'Tester',
        createdAt: DateTime(2026),
      );
      await repository.enterWeeklyLeague(playerProfile);

      final result = await repository.settleCurrentSeason(
        now: DateTime(2026, 5, 17, 23, 58),
      );

      expect(result.executed, isFalse);
      expect(
        (await repository.currentEntry(playerProfile.id))?.entryPaid,
        true,
      );
    });

    test('settlement clears weekly entry state for next season', () async {
      final repository = MockLeagueRepository(seedMockData: false);
      final playerProfile = PlayerProfile(
        id: 'player-id',
        username: 'Tester',
        createdAt: DateTime(2026),
      );
      await repository.enterWeeklyLeague(playerProfile);

      final result = await repository.settleCurrentSeason(
        now: DateTime(2026, 5, 17, 23, 59),
      );
      final settledEntry = await repository.currentEntry(playerProfile.id);

      expect(result.executed, isTrue);
      expect(settledEntry?.entryPaid, isFalse);
      expect(settledEntry?.hasReservedSlot, isTrue);
    });

    test(
      'settlement promotes and relegates adjacent division players',
      () async {
        final repository = MockLeagueRepository(seedMockData: false);
        for (var index = 0; index < 11; index += 1) {
          await repository.enterWeeklyLeague(
            PlayerProfile(
              id: 'player-$index',
              username: 'Player $index',
              createdAt: DateTime(2026, 1, index + 1),
            ),
          );
        }
        for (var index = 0; index < 10; index += 1) {
          await repository.submitLeagueRun(
            WeeklyLeagueRun(
              playerId: 'player-$index',
              score: 1000 - index,
              completedAt: DateTime(2026, 5, 13),
            ),
          );
        }
        await repository.submitLeagueRun(
          WeeklyLeagueRun(
            playerId: 'player-10',
            score: 2000,
            completedAt: DateTime(2026, 5, 13),
          ),
        );

        await repository.settleCurrentSeason(
          now: DateTime(2026, 5, 17, 23, 59),
        );

        expect((await repository.currentEntry('player-10'))?.divisionNumber, 1);
        expect((await repository.currentEntry('player-9'))?.divisionNumber, 2);
        expect(
          (await repository.currentEntry('player-10'))?.entryPaid,
          isFalse,
        );
        expect((await repository.currentEntry('player-9'))?.entryPaid, isFalse);
        expect(
          (await repository.currentEntry('player-9'))?.hasReservedSlot,
          isTrue,
        );

        final promotedAchievements = await repository.fetchPlayerAchievements(
          'player-10',
        );
        final relegatedAchievements = await repository.fetchPlayerAchievements(
          'player-9',
        );

        expect(promotedAchievements.bestDivisionReached, 1);
        expect(promotedAchievements.promotions, 1);
        expect(promotedAchievements.relegations, 0);
        expect(relegatedAchievements.bestDivisionReached, 1);
        expect(relegatedAchievements.promotions, 0);
        expect(relegatedAchievements.relegations, 1);
      },
    );

    test(
      'inactive player staying in last division loses reserved slot',
      () async {
        final repository = MockLeagueRepository(seedMockData: false);
        const playerCount = 15;
        for (var index = 0; index < playerCount; index += 1) {
          await repository.enterWeeklyLeague(
            PlayerProfile(
              id: 'player-$index',
              username: 'Player $index',
              createdAt: DateTime(2026, 1, index + 1),
            ),
          );
        }

        await repository.settleCurrentSeason(
          now: DateTime(2026, 5, 17, 23, 59),
        );

        final penultimateEntries = <String>[];
        final lastDivisionEntries = <String>[];
        for (var index = 0; index < playerCount; index += 1) {
          final entry = await repository.currentEntry('player-$index');
          if (entry?.divisionNumber == 1) {
            penultimateEntries.add(entry!.playerId);
          } else if (entry?.divisionNumber == 2) {
            lastDivisionEntries.add(entry!.playerId);
          }
        }
        expect(lastDivisionEntries.length, greaterThanOrEqualTo(2));

        for (final playerId in penultimateEntries) {
          await _reactivateEntry(repository, playerId);
        }
        await _reactivateEntry(repository, lastDivisionEntries.first);
        final inactiveLastPlayerId = lastDivisionEntries[1];

        await repository.settleCurrentSeason(
          now: DateTime(2026, 5, 24, 23, 59),
        );

        final inactiveLastEntry = await repository.currentEntry(
          inactiveLastPlayerId,
        );
        expect(inactiveLastEntry, isNotNull);
        expect(inactiveLastEntry?.divisionNumber, 2);
        expect(inactiveLastEntry?.entryPaid, isFalse);
        expect(inactiveLastEntry?.hasReservedSlot, isFalse);
      },
    );

    test(
      'inactive player relegated to last division loses reserved slot',
      () async {
        final repository = MockLeagueRepository(seedMockData: false);
        const playerCount = 15;
        for (var index = 0; index < playerCount; index += 1) {
          await repository.enterWeeklyLeague(
            PlayerProfile(
              id: 'player-$index',
              username: 'Player $index',
              createdAt: DateTime(2026, 1, index + 1),
            ),
          );
        }

        await repository.settleCurrentSeason(
          now: DateTime(2026, 5, 17, 23, 59),
        );

        final penultimateEntries = <String>[];
        final lastDivisionEntries = <String>[];
        for (var index = 0; index < playerCount; index += 1) {
          final entry = await repository.currentEntry('player-$index');
          if (entry?.divisionNumber == 1) {
            penultimateEntries.add(entry!.playerId);
          } else if (entry?.divisionNumber == 2) {
            lastDivisionEntries.add(entry!.playerId);
          }
        }
        expect(penultimateEntries.length, greaterThanOrEqualTo(2));
        expect(lastDivisionEntries, isNotEmpty);

        final inactivePenultimatePlayerId = penultimateEntries.last;
        for (final playerId in penultimateEntries) {
          if (playerId != inactivePenultimatePlayerId) {
            await _reactivateEntry(repository, playerId);
          }
        }
        await _reactivateEntry(repository, lastDivisionEntries.first);

        await repository.settleCurrentSeason(
          now: DateTime(2026, 5, 24, 23, 59),
        );

        final relegatedInactiveEntry = await repository.currentEntry(
          inactivePenultimatePlayerId,
        );
        expect(relegatedInactiveEntry, isNotNull);
        expect(relegatedInactiveEntry?.divisionNumber, 2);
        expect(relegatedInactiveEntry?.entryPaid, isFalse);
        expect(relegatedInactiveEntry?.hasReservedSlot, isFalse);
      },
    );

    test('settlement removes inactive last-division reserved slots', () async {
      final repository = MockLeagueRepository(seedMockData: false);
      for (var index = 0; index < 11; index += 1) {
        await repository.enterWeeklyLeague(
          PlayerProfile(
            id: 'player-$index',
            username: 'Player $index',
            createdAt: DateTime(2026, 1, index + 1),
          ),
        );
      }

      await repository.settleCurrentSeason(now: DateTime(2026, 5, 17, 23, 59));

      final inactiveLastEntry = (await repository.currentEntry('player-9'))!;
      final activeLastEntry = (await repository.currentEntry('player-10'))!;
      await repository.enterWeeklyLeague(
        PlayerProfile(
          id: activeLastEntry.playerId,
          username: activeLastEntry.username,
          createdAt: activeLastEntry.registeredAt,
        ),
      );

      final secondResult = await repository.settleCurrentSeason(
        now: DateTime(2026, 5, 24, 23, 59),
      );

      expect(secondResult.executed, isTrue);
      expect(await repository.currentEntry(inactiveLastEntry.playerId), isNull);
      expect(
        await repository.currentEntry(activeLastEntry.playerId),
        isNotNull,
      );
    });
  });
}

Future<void> _reactivateEntry(
  MockLeagueRepository repository,
  String playerId,
) async {
  final entry = await repository.currentEntry(playerId);
  if (entry == null) {
    return;
  }

  await repository.enterWeeklyLeague(
    PlayerProfile(
      id: entry.playerId,
      username: entry.username,
      createdAt: entry.registeredAt,
    ),
  );
}
