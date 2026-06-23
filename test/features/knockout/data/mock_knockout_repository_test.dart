import 'package:flutter_test/flutter_test.dart';
import 'package:stoppy_app/features/auth/domain/models/player_profile.dart';
import 'package:stoppy_app/features/knockout/data/mock_knockout_repository.dart';
import 'package:stoppy_app/features/knockout/domain/models/knockout_match.dart';
import 'package:stoppy_app/features/knockout/domain/models/knockout_player_status.dart';
import 'package:stoppy_app/features/knockout/domain/models/knockout_registration_result.dart';
import 'package:stoppy_app/features/knockout/domain/models/knockout_run.dart';
import 'package:stoppy_app/features/knockout/domain/models/knockout_tournament.dart';
import 'package:stoppy_app/features/knockout/domain/models/knockout_tournament_history_entry.dart';
import 'package:stoppy_app/features/knockout/domain/models/knockout_player_records.dart';

void main() {
  group('MockKnockoutRepository', () {
    test('loads default tournament with GP entry cost', () async {
      final repository = MockKnockoutRepository(
        now: () => DateTime(2026, 5, 22),
      );

      final tournament = await repository.fetchCurrentTournament();

      expect(tournament.name, 'June Knockout');
      expect(tournament.entryCostGamePoints, 25);
      expect(tournament.status, KnockoutTournamentStatus.registrationOpen);
      expect(tournament.startsAt, DateTime(2026, 6));
      expect(tournament.registrationClosesAt, DateTime(2026, 5, 31, 23, 59));
    });

    test('registers player when enough GP is available', () async {
      final repository = MockKnockoutRepository(
        now: () => DateTime(2026, 5, 22, 12),
      );
      final tournament = await repository.fetchCurrentTournament();
      final playerProfile = PlayerProfile(
        id: 'player-id',
        username: 'Tester',
        createdAt: DateTime(2026),
        gamePoints: 25,
      );

      final result = await repository.registerPlayer(
        tournament: tournament,
        playerProfile: playerProfile,
      );
      final entry = await repository.currentEntry(
        tournamentId: tournament.id,
        playerId: playerProfile.id,
      );

      expect(result.isSuccess, isTrue);
      expect(entry?.playerId, playerProfile.id);
      expect(entry?.registeredAt, DateTime(2026, 5, 22, 12));
      expect((await repository.fetchCurrentTournament()).entries.length, 1);
    });

    test('prevents duplicate registration', () async {
      final repository = MockKnockoutRepository();
      final tournament = await repository.fetchCurrentTournament();
      final playerProfile = PlayerProfile(
        id: 'player-id',
        username: 'Tester',
        createdAt: DateTime(2026),
        gamePoints: 50,
      );

      await repository.registerPlayer(
        tournament: tournament,
        playerProfile: playerProfile,
      );
      final duplicateResult = await repository.registerPlayer(
        tournament: tournament,
        playerProfile: playerProfile,
      );

      expect(duplicateResult.isSuccess, isFalse);
      expect(
        duplicateResult.failureReason,
        KnockoutRegistrationFailureReason.duplicateRegistration,
      );
      expect((await repository.fetchCurrentTournament()).entries.length, 1);
    });

    test('rejects duplicate knockout run submissions', () async {
      final now = DateTime(2026, 5, 1, 12);
      final repository = MockKnockoutRepository(now: () => now);

      final tournament = await repository.fetchCurrentTournament();

      final playerOne = PlayerProfile(
        id: 'player-1',
        username: 'player1',
        createdAt: now,
        gamePoints: 100,
      );

      final playerTwo = PlayerProfile(
        id: 'player-2',
        username: 'player2',
        createdAt: now,
        gamePoints: 100,
      );

      await repository.registerPlayer(
        tournament: tournament,
        playerProfile: playerOne,
      );

      final updatedTournament = await repository.fetchCurrentTournament();

      await repository.registerPlayer(
        tournament: updatedTournament,
        playerProfile: playerTwo,
      );

      await repository.closeRegistration(tournamentId: tournament.id);
      final startedTournament = await repository.startTournament(
        tournamentId: tournament.id,
      );

      final snapshot = await repository.fetchActiveDuel(
        tournamentId: startedTournament.id,
        playerId: playerOne.id,
      );

      final run = KnockoutRun(
        id: 'duplicate-run',
        roundNumber: snapshot!.roundNumber,
        matchId: snapshot.match.id,
        playerId: playerOne.id,
        score: 1000,
        completedAt: now,
      );

      final firstAccepted = await repository.submitKnockoutRun(run);
      final secondAccepted = await repository.submitKnockoutRun(run);

      expect(firstAccepted, isTrue);
      expect(secondAccepted, isFalse);

      final updatedSnapshot = await repository.fetchActiveDuel(
        tournamentId: startedTournament.id,
        playerId: playerOne.id,
      );

      expect(updatedSnapshot!.playerRunCount, 1);
      expect(updatedSnapshot.playerScore, 1000);
    });

    test('rejects registration without enough GP', () async {
      final repository = MockKnockoutRepository();
      final tournament = await repository.fetchCurrentTournament();
      final playerProfile = PlayerProfile(
        id: 'player-id',
        username: 'Tester',
        createdAt: DateTime(2026),
        gamePoints: 24,
      );

      final result = await repository.registerPlayer(
        tournament: tournament,
        playerProfile: playerProfile,
      );

      expect(result.isSuccess, isFalse);
      expect(
        result.failureReason,
        KnockoutRegistrationFailureReason.insufficientGamePoints,
      );
      expect((await repository.fetchCurrentTournament()).entries, isEmpty);
    });

    test('rejects registration when tournament is not open', () async {
      final repository = MockKnockoutRepository(
        now: () => DateTime(2026, 6),
        initialTournament: KnockoutTournament(
          id: 'closed',
          name: 'Closed Knockout',
          entryCostGamePoints: 25,
          tournamentMonth: DateTime(2026, 6),
          registrationOpensAt: DateTime(2026, 5),
          registrationClosesAt: DateTime(2026, 5, 31, 23, 59),
          startsAt: DateTime(2026, 6),
          status: KnockoutTournamentStatus.inProgress,
        ),
      );
      final tournament = await repository.fetchCurrentTournament();
      final playerProfile = PlayerProfile(
        id: 'player-id',
        username: 'Tester',
        createdAt: DateTime(2026),
        gamePoints: 25,
      );

      final result = await repository.registerPlayer(
        tournament: tournament,
        playerProfile: playerProfile,
      );

      expect(result.isSuccess, isFalse);
      expect(
        result.failureReason,
        KnockoutRegistrationFailureReason.registrationClosed,
      );
    });

    test('starts tournament and creates opening round', () async {
      final repository = MockKnockoutRepository(
        now: () => DateTime(2026, 5, 22),
      );

      final tournament = await repository.fetchCurrentTournament();

      for (var index = 0; index < 35; index += 1) {
        await repository.registerPlayer(
          tournament: tournament,
          playerProfile: PlayerProfile(
            id: 'player-$index',
            username: 'Player $index',
            createdAt: DateTime(2026),
            gamePoints: 100,
          ),
        );
      }

      final startedTournament = await repository.startTournament(
        tournamentId: tournament.id,
      );

      expect(startedTournament.status, KnockoutTournamentStatus.inProgress);

      expect(startedTournament.rounds.length, 1);

      final openingRound = startedTournament.rounds.first;

      expect(openingRound.matches.length, 3);
      expect(openingRound.byePlayerIds.length, 29);
    });

    test(
      'keeps registration closed until tournament is explicitly started',
      () async {
        final repository = MockKnockoutRepository(
          initialTournament: KnockoutTournament(
            id: '2026-06',
            name: 'June Knockout',
            entryCostGamePoints: 25,
            tournamentMonth: DateTime(2026, 6),
            registrationOpensAt: DateTime(2026, 5),
            registrationClosesAt: DateTime(2026, 5, 31, 23, 59),
            startsAt: DateTime(2026, 6),
          ),
          now: () => DateTime(2026, 6),
        );

        final tournament = await repository.fetchCurrentTournament();

        expect(tournament.status, KnockoutTournamentStatus.registrationClosed);
      },
    );

    test('detects active player matchup after tournament start', () async {
      final repository = MockKnockoutRepository(
        now: () => DateTime(2026, 5, 22),
      );
      final tournament = await _registerPlayers(repository, count: 2);

      final startedTournament = await repository.startTournament(
        tournamentId: tournament.id,
      );
      final duel = await repository.fetchActiveDuel(
        tournamentId: startedTournament.id,
        playerId: 'player-0',
      );

      expect(duel, isNotNull);
      expect(duel!.roundNumber, 1);
      expect(duel.opponentId, isNotNull);
      expect(duel.match.status, KnockoutMatchStatus.active);

      final status = await repository.fetchPlayerStatus(
        tournamentId: startedTournament.id,
        playerId: 'player-0',
      );

      expect(status.state, KnockoutPlayerTournamentState.activeDuel);
      expect(status.canPlayTournamentRun, isTrue);
      expect(status.duelSnapshot, isNotNull);
    });

    test('reports registered waiting status before tournament start', () async {
      final repository = MockKnockoutRepository(
        now: () => DateTime(2026, 5, 22),
      );
      final tournament = await _registerPlayers(repository, count: 1);

      final status = await repository.fetchPlayerStatus(
        tournamentId: tournament.id,
        playerId: 'player-0',
      );

      expect(
        status.state,
        KnockoutPlayerTournamentState.registeredWaitingStart,
      );
      expect(status.canPlayTournamentRun, isFalse);
    });

    test('reports bye waiting status for bye players', () async {
      final repository = MockKnockoutRepository(
        now: () => DateTime(2026, 5, 22),
      );
      final tournament = await _registerPlayers(repository, count: 1);

      final startedTournament = await repository.startTournament(
        tournamentId: tournament.id,
      );
      final status = await repository.fetchPlayerStatus(
        tournamentId: startedTournament.id,
        playerId: 'player-0',
      );

      expect(status.state, KnockoutPlayerTournamentState.byeWaitingNextRound);
      expect(status.duelSnapshot?.hasBye, isTrue);
    });

    test(
      'submitKnockoutRun updates duel score using best-runs logic',
      () async {
        final repository = MockKnockoutRepository(
          now: () => DateTime(2026, 5, 22),
        );
        final tournament = await _registerPlayers(repository, count: 2);
        final startedTournament = await repository.startTournament(
          tournamentId: tournament.id,
        );
        final duel = await repository.fetchActiveDuel(
          tournamentId: startedTournament.id,
          playerId: 'player-0',
        );

        for (var index = 0; index < 6; index += 1) {
          await repository.submitKnockoutRun(
            KnockoutRun(
              id: 'run-$index',
              playerId: 'player-0',
              matchId: duel!.match.id,
              roundNumber: duel.roundNumber,
              score: [100, 900, 300, 800, 250, 400][index],
              completedAt: DateTime(2026, 6, 1, 9, index),
            ),
          );
        }

        final updatedDuel = await repository.fetchActiveDuel(
          tournamentId: startedTournament.id,
          playerId: 'player-0',
        );

        expect(updatedDuel?.playerRunCount, 6);
        expect(updatedDuel?.playerScore, 850);
      },
    );

    test('settles daily round and advances winner to next round', () async {
      var now = DateTime(2026, 5, 22);
      final repository = MockKnockoutRepository(now: () => now);
      final tournament = await _registerPlayers(repository, count: 3);
      final startedTournament = await repository.startTournament(
        tournamentId: tournament.id,
      );
      final match = startedTournament.rounds.first.matches.first;
      final playerId = match.playerOneId!;
      final opponentId = match.playerTwoId!;

      await repository.submitKnockoutRun(
        KnockoutRun(
          id: 'winning-run',
          playerId: playerId,
          matchId: match.id,
          roundNumber: match.roundNumber,
          score: 1000,
          completedAt: DateTime(2026, 6, 1, 10),
        ),
      );
      await repository.submitKnockoutRun(
        KnockoutRun(
          id: 'losing-run',
          playerId: opponentId,
          matchId: match.id,
          roundNumber: match.roundNumber,
          score: 100,
          completedAt: DateTime(2026, 6, 1, 11),
        ),
      );

      now = DateTime(2026, 6, 1, 23, 59);
      final settledTournament = await repository.settleCurrentRound(
        tournamentId: startedTournament.id,
      );

      expect(settledTournament.rounds.first.isCompleted, isTrue);
      expect(settledTournament.rounds.length, 2);
      expect(settledTournament.eliminatedPlayerIds, contains(opponentId));
      expect(settledTournament.rounds.last.matches.length, 1);

      final loserStatus = await repository.fetchPlayerStatus(
        tournamentId: settledTournament.id,
        playerId: opponentId,
      );

      expect(loserStatus.state, KnockoutPlayerTournamentState.eliminated);
    });

    test('rejects knockout run submission after round settlement', () async {
      var now = DateTime(2026, 5, 22);
      final repository = MockKnockoutRepository(now: () => now);
      final tournament = await _registerPlayers(repository, count: 2);

      final startedTournament = await repository.startTournament(
        tournamentId: tournament.id,
      );
      final match = startedTournament.rounds.first.matches.first;

      await repository.submitKnockoutRun(
        KnockoutRun(
          id: 'winner-run',
          playerId: match.playerOneId!,
          matchId: match.id,
          roundNumber: match.roundNumber,
          score: 1000,
          completedAt: DateTime(2026, 6, 1, 10),
        ),
      );

      now = DateTime(2026, 6, 1, 23, 59);
      await repository.settleCurrentRound(tournamentId: startedTournament.id);

      final accepted = await repository.submitKnockoutRun(
        KnockoutRun(
          id: 'late-run',
          playerId: match.playerOneId!,
          matchId: match.id,
          roundNumber: match.roundNumber,
          score: 2000,
          completedAt: DateTime(2026, 6, 2, 0, 1),
        ),
      );

      expect(accepted, isFalse);
    });

    test('uses repechage when a duel has no runs', () async {
      var now = DateTime(2026, 5, 22);
      final repository = MockKnockoutRepository(now: () => now);
      final tournament = await _registerPlayers(repository, count: 4);
      final startedTournament = await repository.startTournament(
        tournamentId: tournament.id,
      );
      final matches = startedTournament.rounds.first.matches;
      final scoredMatch = matches.first;
      final zeroRunMatch = matches.last;

      await repository.submitKnockoutRun(
        KnockoutRun(
          id: 'natural-winner',
          playerId: scoredMatch.playerOneId!,
          matchId: scoredMatch.id,
          roundNumber: scoredMatch.roundNumber,
          score: 900,
          completedAt: DateTime(2026, 6, 1, 10),
        ),
      );
      await repository.submitKnockoutRun(
        KnockoutRun(
          id: 'best-eliminated-player',
          playerId: scoredMatch.playerTwoId!,
          matchId: scoredMatch.id,
          roundNumber: scoredMatch.roundNumber,
          score: 850,
          completedAt: DateTime(2026, 6, 1, 11),
        ),
      );

      now = DateTime(2026, 6, 1, 23, 59);
      final settledTournament = await repository.settleCurrentRound(
        tournamentId: startedTournament.id,
      );
      final settledZeroRunMatch = settledTournament.rounds.first.matches
          .firstWhere((match) => match.id == zeroRunMatch.id);

      expect(
        settledZeroRunMatch.repechageWinnerPlayerId,
        scoredMatch.playerTwoId,
      );
      expect(settledTournament.rounds.last.matches.length, 1);
    });

    test('repechage advancement is not recorded as direct duel win', () async {
      var now = DateTime(2026, 5, 22);
      final repository = MockKnockoutRepository(now: () => now);
      final tournament = await _registerPlayers(repository, count: 4);

      final startedTournament = await repository.startTournament(
        tournamentId: tournament.id,
      );

      final matches = startedTournament.rounds.first.matches;
      final scoredMatch = matches.first;
      final zeroRunMatch = matches.last;

      await repository.submitKnockoutRun(
        KnockoutRun(
          id: 'natural-winner',
          playerId: scoredMatch.playerOneId!,
          matchId: scoredMatch.id,
          roundNumber: scoredMatch.roundNumber,
          score: 900,
          completedAt: DateTime(2026, 6, 1, 10),
        ),
      );

      await repository.submitKnockoutRun(
        KnockoutRun(
          id: 'repechage-candidate',
          playerId: scoredMatch.playerTwoId!,
          matchId: scoredMatch.id,
          roundNumber: scoredMatch.roundNumber,
          score: 850,
          completedAt: DateTime(2026, 6, 1, 11),
        ),
      );

      now = DateTime(2026, 6, 1, 23, 59);

      final settledTournament = await repository.settleCurrentRound(
        tournamentId: startedTournament.id,
      );

      final settledScoredMatch = settledTournament.rounds.first.matches
          .firstWhere((match) => match.id == scoredMatch.id);

      final settledZeroRunMatch = settledTournament.rounds.first.matches
          .firstWhere((match) => match.id == zeroRunMatch.id);

      expect(settledScoredMatch.winnerPlayerId, scoredMatch.playerOneId);
      expect(settledScoredMatch.winnerPlayerId, isNot(scoredMatch.playerTwoId));

      expect(
        settledZeroRunMatch.repechageWinnerPlayerId,
        scoredMatch.playerTwoId,
      );
      expect(settledZeroRunMatch.winnerPlayerId, isNull);
    });

    test('reports champion after final settlement', () async {
      var now = DateTime(2026, 5, 22);
      final repository = MockKnockoutRepository(now: () => now);
      final tournament = await _registerPlayers(repository, count: 2);
      final startedTournament = await repository.startTournament(
        tournamentId: tournament.id,
      );
      final match = startedTournament.rounds.first.matches.first;

      await repository.submitKnockoutRun(
        KnockoutRun(
          id: 'winner',
          playerId: match.playerOneId!,
          matchId: match.id,
          roundNumber: match.roundNumber,
          score: 1000,
          completedAt: DateTime(2026, 6, 1, 10),
        ),
      );

      now = DateTime(2026, 6, 1, 23, 59);
      final completedTournament = await repository.settleCurrentRound(
        tournamentId: startedTournament.id,
      );
      final status = await repository.fetchPlayerStatus(
        tournamentId: completedTournament.id,
        playerId: match.playerOneId!,
      );

      expect(completedTournament.championPlayerId, match.playerOneId);
      expect(status.state, KnockoutPlayerTournamentState.champion);

      final championHistory = await repository.fetchPlayerHistory(
        match.playerOneId!,
      );
      final eliminatedHistory = await repository.fetchPlayerHistory(
        match.playerTwoId!,
      );
      final championRecords = await repository.fetchPlayerRecords(
        match.playerOneId!,
      );

      expect(championHistory, hasLength(1));
      expect(
        championHistory.single.outcome,
        KnockoutTournamentOutcome.champion,
      );
      expect(championHistory.single.finalRoundNumber, 1);
      expect(eliminatedHistory, hasLength(1));
      expect(
        eliminatedHistory.single.outcome,
        KnockoutTournamentOutcome.eliminated,
      );
      expect(championRecords.tournamentsPlayed, 1);
      expect(championRecords.tournamentsWon, 1);
      expect(championRecords.titlesWon, 1);
      expect(championRecords.highestRoundReached, 1);
      expect(championRecords.bestTournamentResultLabel, 'Champion');
      expect(championRecords.totalDuelsPlayed, 1);
      expect(championRecords.totalDuelsWon, 1);
      expect(championRecords.duelWinPercentageLabel, '100.0%');

      final hallOfFame = await repository.fetchHallOfFame();
      expect(hallOfFame, hasLength(1));
      expect(hallOfFame.single.playerId, match.playerOneId);
      expect(hallOfFame.single.displayName, startsWith('Player'));
      expect(hallOfFame.single.titlesWon, 1);
      expect(hallOfFame.single.wonTournamentMonths, [DateTime(2026, 6)]);
    });

    test('returns player history ordered by newest completion first', () async {
      final repository = MockKnockoutRepository(
        initialHistoryByPlayerId: {
          'player-1': [
            KnockoutTournamentHistoryEntry(
              tournamentId: '2026-06',
              tournamentName: 'June Knockout',
              tournamentMonth: DateTime(2026, 6),
              playerId: 'player-1',
              outcome: KnockoutTournamentOutcome.eliminated,
              finalRoundNumber: 1,
              completedAt: DateTime(2026, 6, 1, 23, 59),
            ),
            KnockoutTournamentHistoryEntry(
              tournamentId: '2026-08',
              tournamentName: 'August Knockout',
              tournamentMonth: DateTime(2026, 8),
              playerId: 'player-1',
              outcome: KnockoutTournamentOutcome.champion,
              finalRoundNumber: 3,
              completedAt: DateTime(2026, 8, 1, 23, 59),
            ),
            KnockoutTournamentHistoryEntry(
              tournamentId: '2026-07',
              tournamentName: 'July Knockout',
              tournamentMonth: DateTime(2026, 7),
              playerId: 'player-1',
              outcome: KnockoutTournamentOutcome.eliminated,
              finalRoundNumber: 2,
              completedAt: DateTime(2026, 7, 1, 23, 59),
            ),
          ],
        },
      );

      final history = await repository.fetchPlayerHistory('player-1');

      expect(history.map((entry) => entry.tournamentId), [
        '2026-08',
        '2026-07',
        '2026-06',
      ]);
    });

    test('returns seeded player knockout records', () async {
      final repository = MockKnockoutRepository(
        initialRecordsByPlayerId: {
          'player-1': const KnockoutPlayerRecords(
            playerId: 'player-1',
            tournamentsPlayed: 2,
            tournamentsWon: 1,
            highestRoundReached: 3,
            totalDuelsPlayed: 7,
            totalDuelsWon: 4,
          ),
        },
      );

      final records = await repository.fetchPlayerRecords('player-1');

      expect(records.playerId, 'player-1');
      expect(records.tournamentsPlayed, 2);
      expect(records.tournamentsWon, 1);
      expect(records.titlesWon, 1);
      expect(records.highestRoundReached, 3);
      expect(records.totalDuelsPlayed, 7);
      expect(records.totalDuelsWon, 4);
      expect(records.duelWinPercentageLabel, '57.1%');
      expect(records.bestTournamentResultLabel, 'Champion');
    });

    test(
      'returns cumulative player records for non-champion players',
      () async {
        final repository = MockKnockoutRepository(
          initialRecordsByPlayerId: {
            'player-1': const KnockoutPlayerRecords(
              playerId: 'player-1',
              tournamentsPlayed: 1,
              tournamentsWon: 0,
              highestRoundReached: 2,
            ),
          },
        );

        final records = await repository.fetchPlayerRecords('player-1');

        expect(records.playerId, 'player-1');
        expect(records.tournamentsPlayed, 1);
        expect(records.tournamentsWon, 0);
        expect(records.titlesWon, 0);
        expect(records.highestRoundReached, 2);
        expect(records.bestTournamentResultLabel, 'Round 2');
      },
    );

    test('aggregates Hall of Fame champions only by titles won', () async {
      final repository = MockKnockoutRepository(
        initialHistoryByPlayerId: {
          'champion-a': [
            KnockoutTournamentHistoryEntry(
              tournamentId: '2026-06',
              tournamentName: 'June Knockout',
              tournamentMonth: DateTime(2026, 6),
              playerId: 'champion-a',
              playerUsername: 'Ada',
              outcome: KnockoutTournamentOutcome.champion,
              finalRoundNumber: 3,
              completedAt: DateTime(2026, 6, 1, 23, 59),
            ),
            KnockoutTournamentHistoryEntry(
              tournamentId: '2026-07',
              tournamentName: 'July Knockout',
              tournamentMonth: DateTime(2026, 7),
              playerId: 'champion-a',
              playerUsername: 'Ada',
              outcome: KnockoutTournamentOutcome.champion,
              finalRoundNumber: 4,
              completedAt: DateTime(2026, 7, 1, 23, 59),
            ),
          ],
          'champion-b': [
            KnockoutTournamentHistoryEntry(
              tournamentId: '2026-08',
              tournamentName: 'August Knockout',
              tournamentMonth: DateTime(2026, 8),
              playerId: 'champion-b',
              playerUsername: 'Ben',
              outcome: KnockoutTournamentOutcome.champion,
              finalRoundNumber: 3,
              completedAt: DateTime(2026, 8, 1, 23, 59),
            ),
          ],
          'eliminated-player': [
            KnockoutTournamentHistoryEntry(
              tournamentId: '2026-08',
              tournamentName: 'August Knockout',
              tournamentMonth: DateTime(2026, 8),
              playerId: 'eliminated-player',
              playerUsername: 'Eli',
              outcome: KnockoutTournamentOutcome.eliminated,
              finalRoundNumber: 1,
              completedAt: DateTime(2026, 8, 1, 23, 59),
            ),
          ],
        },
      );

      final hallOfFame = await repository.fetchHallOfFame();

      expect(hallOfFame.map((entry) => entry.playerId), [
        'champion-a',
        'champion-b',
      ]);
      expect(hallOfFame.first.displayName, 'Ada');
      expect(hallOfFame.first.titlesWon, 2);
      expect(hallOfFame.first.titlesWon, 2);

      expect(hallOfFame.first.wonTournamentMonths, [
        DateTime(2026, 6),
        DateTime(2026, 7),
      ]);
    });

    test(
      'keeps non participant as not registered after tournament completion',
      () async {
        var now = DateTime(2026, 5, 22);
        final repository = MockKnockoutRepository(now: () => now);
        final tournament = await _registerPlayers(repository, count: 2);

        final startedTournament = await repository.startTournament(
          tournamentId: tournament.id,
        );
        final match = startedTournament.rounds.first.matches.first;

        await repository.submitKnockoutRun(
          KnockoutRun(
            id: 'winner',
            playerId: match.playerOneId!,
            matchId: match.id,
            roundNumber: match.roundNumber,
            score: 1000,
            completedAt: DateTime(2026, 6, 1, 10),
          ),
        );

        now = DateTime(2026, 6, 1, 23, 59);
        final completedTournament = await repository.settleCurrentRound(
          tournamentId: startedTournament.id,
        );

        final outsiderStatus = await repository.fetchPlayerStatus(
          tournamentId: completedTournament.id,
          playerId: 'outsider-player',
        );

        expect(
          outsiderStatus.state,
          KnockoutPlayerTournamentState.notRegistered,
        );
        expect(outsiderStatus.canPlayTournamentRun, isFalse);
        expect(await repository.fetchPlayerHistory('outsider-player'), isEmpty);
      },
    );
  });
}

Future<KnockoutTournament> _registerPlayers(
  MockKnockoutRepository repository, {
  required int count,
}) async {
  final tournament = await repository.fetchCurrentTournament();
  for (var index = 0; index < count; index += 1) {
    await repository.registerPlayer(
      tournament: tournament,
      playerProfile: PlayerProfile(
        id: 'player-$index',
        username: 'Player $index',
        createdAt: DateTime(2026),
        gamePoints: 100,
      ),
    );
  }

  return repository.fetchCurrentTournament();
}
