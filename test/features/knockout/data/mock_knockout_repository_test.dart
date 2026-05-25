import 'package:flutter_test/flutter_test.dart';
import 'package:stoppy_app/features/auth/domain/models/player_profile.dart';
import 'package:stoppy_app/features/knockout/data/mock_knockout_repository.dart';
import 'package:stoppy_app/features/knockout/domain/models/knockout_match.dart';
import 'package:stoppy_app/features/knockout/domain/models/knockout_registration_result.dart';
import 'package:stoppy_app/features/knockout/domain/models/knockout_run.dart';
import 'package:stoppy_app/features/knockout/domain/models/knockout_tournament.dart';

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

      await repository.submitKnockoutRun(run);
      await repository.submitKnockoutRun(run);

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

  return tournament;
}
