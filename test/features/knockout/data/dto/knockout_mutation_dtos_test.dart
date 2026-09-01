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
    test('uses an empty body so backend authentication owns identity', () {
      const dto = KnockoutRegistrationRequestDto();

      expect(dto.toJson(), isEmpty);
      expect(KnockoutRegistrationRequestDto.fromJson({}).toJson(), isEmpty);
    });

    test('rejects client-supplied registration authority fields', () {
      expect(
        () => KnockoutRegistrationRequestDto.fromJson({'playerId': 'player-1'}),
        throwsFormatException,
      );
    });
  });

  group('KnockoutRegistrationResponseDto', () {
    test('maps accepted registration response and idempotent replay', () {
      final tournament = _tournamentWithEntry();
      final entry = KnockoutPlayerEntryDto.fromDomain(
        tournament.entries.single,
      );

      final accepted = KnockoutRegistrationResponseDto.fromJson({
        'status': 'accepted',
        'newlyPersisted': true,
        'tournament': KnockoutTournamentDto.fromDomain(tournament).toJson(),
        'playerEntry': entry.toJson(),
        'remainingGamePoints': 75,
        'playerProfile': _profilePayload(gamePoints: 75),
      });
      final replay = KnockoutRegistrationResponseDto.fromJson({
        'status': 'idempotentReplay',
        'newlyPersisted': false,
        'tournament': KnockoutTournamentDto.fromDomain(tournament).toJson(),
        'playerEntry': entry.toJson(),
        'remainingGamePoints': 75,
      });

      expect(accepted.toDomain().isSuccess, isTrue);
      expect(accepted.toDomain().playerEntry?.playerId, 'player-1');
      expect(accepted.playerProfile?.gamePoints, 75);
      expect(replay.toDomain().isSuccess, isTrue);
    });

    test('maps rejected registration response', () {
      final tournament = _registrationTournament();

      final rejected = KnockoutRegistrationResponseDto.fromJson({
        'status': 'rejected',
        'newlyPersisted': false,
        'tournament': KnockoutTournamentDto.fromDomain(tournament).toJson(),
        'rejectionCode': 'insufficientGp',
      }).toDomain();

      expect(rejected.isFailure, isTrue);
      expect(rejected.message, 'You need 25 GP to register.');
    });

    test('rejects contradictory registration response payloads', () {
      final tournament = _registrationTournament();

      expect(
        () => KnockoutRegistrationResponseDto.fromJson({
          'status': 'accepted',
          'newlyPersisted': false,
          'tournament': KnockoutTournamentDto.fromDomain(tournament).toJson(),
          'remainingGamePoints': 75,
        }),
        throwsFormatException,
      );

      expect(
        () => KnockoutRegistrationResponseDto.fromJson({
          'status': 'rejected',
          'newlyPersisted': true,
          'tournament': KnockoutTournamentDto.fromDomain(tournament).toJson(),
          'rejectionCode': 'registrationClosed',
        }),
        throwsFormatException,
      );
    });

    test('rejects profile GP that differs from remaining GP', () {
      final tournament = _tournamentWithEntry();
      final entry = KnockoutPlayerEntryDto.fromDomain(
        tournament.entries.single,
      );

      expect(
        () => KnockoutRegistrationResponseDto.fromJson({
          'status': 'accepted',
          'newlyPersisted': true,
          'tournament': KnockoutTournamentDto.fromDomain(tournament).toJson(),
          'playerEntry': entry.toJson(),
          'remainingGamePoints': 75,
          'playerProfile': _profilePayload(gamePoints: 74),
        }),
        throwsFormatException,
      );
    });
  });

  group('KnockoutRunSubmissionRequestDto', () {
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
