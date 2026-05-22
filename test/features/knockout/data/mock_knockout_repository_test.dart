import 'package:flutter_test/flutter_test.dart';
import 'package:stoppy_app/features/auth/domain/models/player_profile.dart';
import 'package:stoppy_app/features/knockout/data/mock_knockout_repository.dart';
import 'package:stoppy_app/features/knockout/domain/models/knockout_registration_result.dart';
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

      expect(
        startedTournament.status,
        KnockoutTournamentStatus.inProgress,
      );

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

      expect(
        tournament.status,
        KnockoutTournamentStatus.registrationClosed,
      );
    });
  });
}
