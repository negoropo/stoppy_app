import 'package:flutter_test/flutter_test.dart';
import 'package:stoppy_app/core/backend/api_error.dart';
import 'package:stoppy_app/core/backend/validation/run_validation_contract.dart';
import 'package:stoppy_app/features/auth/data/dto/player_profile_dto.dart';
import 'package:stoppy_app/features/knockout/data/dto/knockout_mutation_dtos.dart';
import 'package:stoppy_app/features/knockout/data/dto/knockout_persistence_dtos.dart';
import 'package:stoppy_app/features/knockout/data/dto/knockout_run_dto.dart';
import 'package:stoppy_app/features/knockout/domain/models/knockout_player_entry.dart';
import 'package:stoppy_app/features/knockout/domain/models/knockout_run.dart';
import 'package:stoppy_app/features/knockout/domain/models/knockout_tournament.dart';

void main() {
  group('KnockoutRegistrationRequestDto', () {
    const target = 'cd30c422-9ea3-4b11-b621-93a9ffcd10b8';
    test('round-trips only the explicit catalog UUID', () {
      const payload = {'tournamentId': target};
      expect(
        KnockoutRegistrationRequestDto.fromJson(payload).toJson(),
        payload,
      );
    });

    test('rejects missing or invalid targets and client authority fields', () {
      for (final payload in [
        {},
        {'tournamentId': null},
        {'tournamentId': '2026-06'},
        {'tournamentId': target.toUpperCase()},
        {'tournamentId': '$target\n'},
        {'tournamentId': target, 'playerId': 'player-1'},
        {'tournamentId': target, 'gamePoints': 100},
      ]) {
        expect(
          () => KnockoutRegistrationRequestDto.fromJson(payload),
          throwsFormatException,
        );
      }
    });
  });

  group('KnockoutRegistrationResponseDto', () {
    final tournament = _tournamentWithEntry();
    final entry = KnockoutPlayerEntryDto.fromDomain(tournament.entries.single);
    final accepted = {
      'status': 'accepted',
      'newlyPersisted': true,
      'replayed': false,
      'playerId': entry.playerId,
      'tournamentId': tournament.id,
      'tournament': KnockoutTournamentDto.fromDomain(
        tournament,
      ).toRegistrationCatalogJson(),
      'playerEntry': entry.toJson(),
      'historicalRemainingGamePoints': 75,
      'playerProfile': _profilePayload(gamePoints: 75),
    };
    final rejected = {
      'status': 'rejected',
      'newlyPersisted': false,
      'replayed': true,
      'playerId': entry.playerId,
      'tournamentId': tournament.id,
      'rejectionCode': 'insufficientGp',
    };

    test(
      'maps accepted and replayed receipts with distinct historical and current balances',
      () {
        final initial = KnockoutRegistrationResponseDto.fromJson(accepted);
        final replay = KnockoutRegistrationResponseDto.fromJson({
          ...accepted,
          'status': 'idempotentReplay',
          'newlyPersisted': false,
          'replayed': true,
          'playerProfile': _profilePayload(gamePoints: 84),
        });

        expect(initial.toDomain().isSuccess, isTrue);
        expect(initial.toDomain().playerEntry?.playerId, entry.playerId);
        expect(replay.toDomain().historicalRemainingGamePoints, 75);
        expect(replay.toDomain().playerProfile?.gamePoints, 84);
        expect(replay.toJson()['remainingGamePoints'], isNull);
      },
    );

    test(
      'maps correlated rejected replay and unavailable target without catalog fields',
      () {
        final failure = KnockoutRegistrationResponseDto.fromJson(
          rejected,
        ).toDomain();
        expect(failure.isFailure, isTrue);
        expect(failure.message, 'You need 25 GP to register.');
        expect(failure.tournamentId, tournament.id);
        expect(failure.tournament, isNull);
        final unavailable = KnockoutRegistrationResponseDto.fromJson({
          ...rejected,
          'rejectionCode': 'tournamentUnavailable',
          'replayed': false,
        });
        expect(unavailable.toDomain().isFailure, isTrue);
        expect(unavailable.toJson().keys, isNot(contains('playerProfile')));
      },
    );

    test(
      'rejects contradictory registration responses and historical-only balances',
      () {
        for (final payload in [
          {...accepted, 'newlyPersisted': false},
          {...accepted, 'replayed': true},
          {...accepted, 'playerProfile': null},
          {...accepted, 'playerId': 'other'},
          {...accepted, 'tournamentId': 'other'},
          {...accepted, 'remainingGamePoints': 75},
          {...rejected, 'newlyPersisted': true},
          {...rejected, 'playerEntry': entry.toJson()},
          {...rejected, 'historicalRemainingGamePoints': 75},
        ]) {
          expect(
            () => KnockoutRegistrationResponseDto.fromJson(payload),
            throwsFormatException,
          );
        }
      },
    );
  });

  group('KnockoutRunSubmissionRequestDto', () {
    test(
      'direct serialization rejects blank identifiers and nonpositive round',
      () {
        for (final field in [
          'runId',
          'tournamentId',
          'matchId',
          'roundNumber',
        ]) {
          final dto = KnockoutRunSubmissionRequestDto(
            runId: field == 'runId' ? ' ' : 'run-1',
            tournamentId: field == 'tournamentId' ? ' ' : '2026-06',
            matchId: field == 'matchId' ? ' ' : 'match-1',
            roundNumber: field == 'roundNumber' ? 0 : 1,
            runStartedAt: DateTime.utc(2026, 6, 2),
            runCompletedAt: DateTime.utc(2026, 6, 2),
            claimedFinalPrecisionPoints: 0,
            runMode: KnockoutRunSubmissionMode.knockout,
          );
          expect(dto.toJson, throwsFormatException);
        }
      },
    );

    test('serializes a run claim without client player identity authority', () {
      final startedAt = DateTime.utc(2026, 6, 2, 10);
      final completedAt = startedAt.add(const Duration(minutes: 12));
      final dto = KnockoutRunSubmissionRequestDto(
        runId: 'run-1',
        tournamentId: '2026-06',
        roundNumber: 1,
        matchId: 'match-1',
        runStartedAt: startedAt,
        runCompletedAt: completedAt,
        claimedFinalPrecisionPoints: 42000,
        runMode: KnockoutRunSubmissionMode.knockout,
        validationClaim: RunValidationClaimDto(
          runId: 'run-1',
          runType: CompetitiveRunType.knockout,
          finalPrecisionPoints: 42000,
          levelReached: 12,
          precisionPointTier: 8,
          runStartedAt: startedAt,
          runEndedAt: completedAt,
        ),
      );

      final json = dto.toJson();
      final decoded = KnockoutRunSubmissionRequestDto.fromJson(json);

      expect(json.keys, isNot(contains('playerId')));
      expect(decoded.runId, 'run-1');
      expect(decoded.tournamentId, '2026-06');
      expect(decoded.validationClaim?.runType, CompetitiveRunType.knockout);
    });

    test('rejects malformed run claims', () {
      final startedAt = DateTime.utc(2026, 6, 2, 10);

      expect(
        () => KnockoutRunSubmissionRequestDto.fromJson({
          'runId': ' ',
          'tournamentId': '2026-06',
          'roundNumber': 1,
          'matchId': 'match-1',
          'runStartedAt': startedAt.toIso8601String(),
          'runCompletedAt': startedAt.toIso8601String(),
          'claimedFinalPrecisionPoints': 1,
          'runMode': 'knockout',
        }),
        throwsMalformedPayloadApiException,
      );

      expect(
        () => KnockoutRunSubmissionRequestDto.fromJson({
          'runId': 'run-1',
          'tournamentId': '2026-06',
          'roundNumber': 1,
          'matchId': 'match-1',
          'runStartedAt': startedAt.toIso8601String(),
          'runCompletedAt': startedAt
              .add(const Duration(hours: 1, seconds: 1))
              .toIso8601String(),
          'claimedFinalPrecisionPoints': 1,
          'runMode': 'knockout',
        }),
        throwsFormatException,
      );
    });

    test('rejects validation claim mismatches', () {
      final startedAt = DateTime.utc(2026, 6, 2, 10);
      final completedAt = startedAt.add(const Duration(minutes: 12));

      expect(
        () => KnockoutRunSubmissionRequestDto.fromJson({
          'runId': 'run-1',
          'tournamentId': '2026-06',
          'roundNumber': 1,
          'matchId': 'match-1',
          'runStartedAt': startedAt.toIso8601String(),
          'runCompletedAt': completedAt.toIso8601String(),
          'claimedFinalPrecisionPoints': 42000,
          'runMode': 'knockout',
          'validationClaim': {
            'runId': 'run-1',
            'runType': 'league',
            'finalPrecisionPoints': 42000,
            'levelReached': 12,
            'precisionPointTier': 8,
            'runStartedAt': startedAt.toIso8601String(),
            'runEndedAt': completedAt.toIso8601String(),
          },
        }),
        throwsFormatException,
      );
    });
  });

  group('KnockoutRunSubmissionResponseDto', () {
    test(
      'rejects replay marked newly persisted and rejection without reason',
      () {
        for (final payload in [
          {'status': 'idempotentReplay', 'newlyPersisted': true},
          {'status': 'rejected', 'newlyPersisted': false},
          {
            'status': 'rejected',
            'newlyPersisted': false,
            'rejectionCode': 'unknown',
          },
        ]) {
          expect(
            () => KnockoutRunSubmissionResponseDto.fromJson(payload),
            throwsFormatException,
          );
        }
      },
    );

    test('maps accepted and idempotent replay semantics', () {
      final runDto = KnockoutRunDto.fromDomain(
        KnockoutRun(
          id: 'run-1',
          playerId: 'player-1',
          matchId: 'match-1',
          roundNumber: 1,
          score: 42000,
          completedAt: DateTime.utc(2026, 6, 2, 10),
        ),
      );

      final accepted = KnockoutRunSubmissionResponseDto.fromJson({
        'status': 'accepted',
        'newlyPersisted': true,
        'acceptedRun': runDto.toJson(),
        'validationResult': {
          'accepted': true,
          'serverFinalPrecisionPoints': 42000,
        },
      });
      final replay = KnockoutRunSubmissionResponseDto.fromJson({
        'status': 'idempotentReplay',
        'newlyPersisted': false,
        'acceptedRun': runDto.toJson(),
      });

      expect(accepted.accepted, isTrue);
      expect(accepted.newlyPersisted, isTrue);
      expect(replay.accepted, isTrue);
      expect(replay.newlyPersisted, isFalse);
    });

    test('rejects contradictory run submission responses', () {
      final runDto = KnockoutRunDto.fromDomain(
        KnockoutRun(
          id: 'run-1',
          playerId: 'player-1',
          matchId: 'match-1',
          roundNumber: 1,
          score: 42000,
          completedAt: DateTime.utc(2026, 6, 2, 10),
        ),
      );

      expect(
        () => KnockoutRunSubmissionResponseDto.fromJson({
          'status': 'accepted',
          'newlyPersisted': false,
          'acceptedRun': runDto.toJson(),
        }),
        throwsFormatException,
      );

      expect(
        () => KnockoutRunSubmissionResponseDto.fromJson({
          'status': 'rejected',
          'newlyPersisted': false,
          'acceptedRun': runDto.toJson(),
          'rejectionCode': 'validationFailed',
        }),
        throwsFormatException,
      );
    });

    test('rejects accepted response with mismatched validation score', () {
      final runDto = KnockoutRunDto.fromDomain(
        KnockoutRun(
          id: 'run-1',
          playerId: 'player-1',
          matchId: 'match-1',
          roundNumber: 1,
          score: 42000,
          completedAt: DateTime.utc(2026, 6, 2, 10),
        ),
      );

      expect(
        () => KnockoutRunSubmissionResponseDto.fromJson({
          'status': 'accepted',
          'newlyPersisted': true,
          'acceptedRun': runDto.toJson(),
          'validationResult': {
            'accepted': true,
            'serverFinalPrecisionPoints': 41000,
          },
        }),
        throwsFormatException,
      );
    });

    test('rejects rejected response with accepted validation result', () {
      expect(
        () => KnockoutRunSubmissionResponseDto.fromJson({
          'status': 'rejected',
          'newlyPersisted': false,
          'rejectionCode': 'validationFailed',
          'validationResult': {
            'accepted': true,
            'serverFinalPrecisionPoints': 42000,
          },
        }),
        throwsFormatException,
      );
    });
  });
}

Matcher get throwsFormatException => throwsA(isA<FormatException>());

Matcher get throwsMalformedPayloadApiException {
  return throwsA(
    isA<ApiException>().having(
      (exception) => exception.error.code,
      'code',
      ApiErrorCode.malformedPayload,
    ),
  );
}

KnockoutTournament _registrationTournament() {
  return KnockoutTournament(
    id: '2026-06',
    name: 'June Knockout',
    entryCostGamePoints: 25,
    tournamentMonth: DateTime.utc(2026, 6),
    registrationOpensAt: DateTime.utc(2026, 5),
    registrationClosesAt: DateTime.utc(2026, 5, 31, 23, 59),
    startsAt: DateTime.utc(2026, 6),
  );
}

KnockoutTournament _tournamentWithEntry() {
  final tournament = _registrationTournament();
  final entry = KnockoutPlayerEntry(
    playerId: 'player-1',
    username: 'Tester',
    tournamentId: tournament.id,
    registeredAt: DateTime.utc(2026, 5, 22, 12),
    accountCreatedAt: DateTime.utc(2026),
    entryCostGamePoints: 25,
  );

  return tournament.copyWith(entries: [entry]);
}

Map<String, Object?> _profilePayload({required int gamePoints}) {
  return PlayerProfileDto(
    id: 'player-1',
    username: 'Tester',
    createdAt: DateTime.utc(2026),
    gamePoints: gamePoints,
    adsRemoved: false,
    hasWeeklyLeagueEntry: false,
    reservedLeagueSlot: false,
  ).toJson();
}
