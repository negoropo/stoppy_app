import 'package:flutter_test/flutter_test.dart';
import 'package:stoppy_app/core/backend/validation/run_validation_contract.dart';
import 'package:stoppy_app/features/league/data/dto/league_mutation_dtos.dart';
import 'package:stoppy_app/features/league/data/dto/league_persistence_dtos.dart';
import 'package:stoppy_app/features/league/data/dto/weekly_league_run_dto.dart';

void main() {
  group('LeagueEntryRequestDto', () {
    test('round-trips an empty client-owned request body', () {
      const request = LeagueEntryRequestDto();

      expect(LeagueEntryRequestDto.fromJson(request.toJson()).toJson(), {});
      expect(LeagueEntryRequestDto.fromJson({}).toJson(), {});
    });

    test('rejects unexpected player identity or economy fields', () {
      expect(
        () => LeagueEntryRequestDto.fromJson({'playerId': 'player-1'}),
        throwsA(isA<FormatException>()),
      );

      expect(
        () => LeagueEntryRequestDto.fromJson({
          'gamePoints': 100,
          'divisionNumber': 2,
        }),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('LeagueEntryResponseDto', () {
    test('round-trips an accepted authoritative response', () {
      final response = LeagueEntryResponseDto.fromJson({
        'status': 'accepted',
        'seasonId': '2026-06-15',
        'entry': _entryPayload('player-1'),
        'currentDivision': 2,
        'remainingGamePoints': 15,
        'playerProfile': _playerProfilePayload(gamePoints: 15),
      });

      expect(response.accepted, isTrue);
      expect(response.parsedSeasonId?.value, '2026-06-15');
      expect(response.entry?.playerId, 'player-1');
      expect(
        LeagueEntryResponseDto.fromJson(response.toJson()).remainingGamePoints,
        15,
      );
    });

    test('round-trips a rejected response', () {
      final response = LeagueEntryResponseDto.fromJson({
        'status': 'rejected',
        'seasonId': '2026-06-15',
        'rejectionCode': 'insufficientGp',
      });

      expect(response.accepted, isFalse);
      expect(response.rejectionCode, LeagueEntryRejectionCode.insufficientGp);
      expect(
        LeagueEntryResponseDto.fromJson(response.toJson()).accepted,
        isFalse,
      );
    });

    test('round-trips an idempotent replay response', () {
      final response = LeagueEntryResponseDto.fromJson({
        'status': 'idempotentReplay',
        'seasonId': '2026-06-15',
        'entry': _entryPayload('player-1'),
        'currentDivision': 2,
        'remainingGamePoints': 15,
      });

      expect(response.status, LeagueMutationStatus.idempotentReplay);
      expect(response.accepted, isTrue);
    });

    test('rejects malformed season identifiers', () {
      expect(
        () => LeagueEntryResponseDto.fromJson({
          'status': 'accepted',
          'seasonId': 'not-a-date',
          'entry': _entryPayload('player-1'),
          'currentDivision': 2,
          'remainingGamePoints': 15,
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test('accepts only canonical Monday season identifiers', () {
      expect(
        LeagueEntryResponseDto.fromJson({
          'status': 'accepted',
          'seasonId': '2026-06-15',
          'entry': _entryPayload('player-1'),
          'currentDivision': 2,
          'remainingGamePoints': 15,
        }).parsedSeasonId?.value,
        '2026-06-15',
      );

      for (final seasonId in [
        '2026-06-16',
        '2026-06-15T00:00:00',
        '2026-06-15T00:00:00Z',
      ]) {
        expect(
          () => LeagueEntryResponseDto.fromJson({
            'status': 'accepted',
            'seasonId': seasonId,
            'entry': _entryPayload('player-1'),
            'currentDivision': 2,
            'remainingGamePoints': 15,
          }),
          throwsA(isA<FormatException>()),
        );
      }
    });

    test('rejects negative GP and unknown enum values', () {
      expect(
        () => LeagueEntryResponseDto.fromJson({
          'status': 'accepted',
          'seasonId': '2026-06-15',
          'entry': _entryPayload('player-1'),
          'currentDivision': 2,
          'remainingGamePoints': -1,
        }),
        throwsA(isA<FormatException>()),
      );

      expect(
        () => LeagueEntryResponseDto.fromJson({'status': 'teleported'}),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects contradictory accepted and rejected states', () {
      expect(
        () => LeagueEntryResponseDto.fromJson({
          'status': 'accepted',
          'seasonId': '2026-06-15',
          'entry': _entryPayload('player-1'),
          'currentDivision': 2,
          'remainingGamePoints': 15,
          'rejectionCode': 'insufficientGp',
        }),
        throwsA(isA<FormatException>()),
      );

      expect(
        () => LeagueEntryResponseDto.fromJson({
          'status': 'rejected',
          'rejectionCode': 'entryWindowClosed',
          'entry': _entryPayload('player-1'),
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test('toJson rejects invalid directly constructed states', () {
      expect(
        () => const LeagueEntryResponseDto(
          status: LeagueMutationStatus.accepted,
        ).toJson(),
        throwsA(isA<FormatException>()),
      );

      expect(
        () => LeagueEntryResponseDto(
          status: LeagueMutationStatus.rejected,
          seasonId: '2026-06-15',
          entry: _entryDto('player-1'),
          currentDivision: 2,
          remainingGamePoints: 15,
          rejectionCode: LeagueEntryRejectionCode.insufficientGp,
        ).toJson(),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('LeagueRunSubmissionRequestDto', () {
    test('round-trips a valid request with matching validation claim', () {
      final request = LeagueRunSubmissionRequestDto.fromJson(
        _runRequestPayload(),
      );

      expect(request.parsedSeasonId.value, '2026-06-15');
      expect(request.validationClaim?.runType, CompetitiveRunType.league);
      expect(
        LeagueRunSubmissionRequestDto.fromJson(
          request.toJson(),
        ).claimedFinalPrecisionPoints,
        25000,
      );
    });

    test('valid directly constructed request serializes and round-trips', () {
      final request = _validRunSubmissionRequestDto();
      final json = request.toJson();

      expect(json['runId'], 'run-1');
      expect(
        LeagueRunSubmissionRequestDto.fromJson(
          json,
        ).claimedFinalPrecisionPoints,
        25000,
      );
    });

    test('rejects negative PP invalid season and invalid run mode', () {
      expect(
        () => LeagueRunSubmissionRequestDto.fromJson({
          ..._runRequestPayload(),
          'claimedFinalPrecisionPoints': -1,
        }),
        throwsA(isA<Object>()),
      );

      expect(
        () => LeagueRunSubmissionRequestDto.fromJson({
          ..._runRequestPayload(),
          'seasonId': 'not-a-date',
        }),
        throwsA(isA<FormatException>()),
      );

      expect(
        () => LeagueRunSubmissionRequestDto.fromJson({
          ..._runRequestPayload(),
          'runMode': 'warmup',
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test('accepts only canonical Monday season identifiers', () {
      expect(
        LeagueRunSubmissionRequestDto.fromJson(
          _runRequestPayload(),
        ).parsedSeasonId.value,
        '2026-06-15',
      );

      for (final seasonId in [
        '2026-06-16',
        '2026-06-15T00:00:00',
        '2026-06-15T00:00:00Z',
      ]) {
        expect(
          () => LeagueRunSubmissionRequestDto.fromJson({
            ..._runRequestPayload(),
            'seasonId': seasonId,
          }),
          throwsA(isA<FormatException>()),
        );
      }
    });

    test('rejects invalid timestamps and duration', () {
      expect(
        () => LeagueRunSubmissionRequestDto.fromJson({
          ..._runRequestPayload(),
          'runCompletedAt': '2026-06-21T09:59:00.000Z',
        }),
        throwsA(isA<FormatException>()),
      );

      expect(
        () => LeagueRunSubmissionRequestDto.fromJson({
          ..._runRequestPayload(),
          'runCompletedAt': '2026-06-21T11:01:00.001Z',
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects malformed anti-cheat validation claims', () {
      expect(
        () => LeagueRunSubmissionRequestDto.fromJson({
          ..._runRequestPayload(),
          'validationClaim': {
            ..._validationClaimPayload(),
            'runType': 'knockout',
          },
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test('toJson rejects invalid directly constructed requests', () {
      expect(
        () => _validRunSubmissionRequestDto(runId: '').toJson(),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => _validRunSubmissionRequestDto(runId: '   ').toJson(),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => _validRunSubmissionRequestDto(seasonId: '2026-06-16').toJson(),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => _validRunSubmissionRequestDto(
          claimedFinalPrecisionPoints: -1,
        ).toJson(),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => _validRunSubmissionRequestDto(
          runCompletedAt: DateTime.utc(2026, 6, 21, 9, 59),
        ).toJson(),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => _validRunSubmissionRequestDto(
          runCompletedAt: DateTime.utc(2026, 6, 21, 11, 1, 1),
        ).toJson(),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => _validRunSubmissionRequestDto(
          validationClaim: _validationClaimDto(finalPrecisionPoints: 999),
        ).toJson(),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('LeagueRunSubmissionResponseDto', () {
    test('round-trips an accepted response', () {
      final response = LeagueRunSubmissionResponseDto.fromJson({
        'status': 'accepted',
        'newlyPersisted': true,
        'acceptedRun': _acceptedRunPayload(),
        'playerRecords': _playerRecordsPayload(),
        'validationResult': {
          'accepted': true,
          'serverFinalPrecisionPoints': 25000,
        },
      });

      expect(response.accepted, isTrue);
      expect(response.acceptedRun?.score, 25000);
      expect(
        LeagueRunSubmissionResponseDto.fromJson(
          response.toJson(),
        ).newlyPersisted,
        isTrue,
      );
    });

    test('round-trips a rejected response', () {
      final response = LeagueRunSubmissionResponseDto.fromJson({
        'status': 'rejected',
        'newlyPersisted': false,
        'rejectionCode': 'validationFailed',
        'validationResult': {
          'accepted': false,
          'rejectionCode': 'invalid_precision_progression',
        },
      });

      expect(response.accepted, isFalse);
      expect(
        response.rejectionCode,
        LeagueRunSubmissionRejectionCode.validationFailed,
      );
    });

    test('round-trips an idempotent replay response', () {
      final response = LeagueRunSubmissionResponseDto.fromJson({
        'status': 'idempotentReplay',
        'newlyPersisted': false,
        'acceptedRun': _acceptedRunPayload(),
        'playerRecords': _playerRecordsPayload(),
      });

      expect(response.status, LeagueMutationStatus.idempotentReplay);
      expect(response.accepted, isTrue);
    });

    test('rejects contradictory result states', () {
      expect(
        () => LeagueRunSubmissionResponseDto.fromJson({
          'status': 'accepted',
          'newlyPersisted': false,
          'acceptedRun': _acceptedRunPayload(),
        }),
        throwsA(isA<FormatException>()),
      );

      expect(
        () => LeagueRunSubmissionResponseDto.fromJson({
          'status': 'rejected',
          'newlyPersisted': true,
          'rejectionCode': 'invalidRun',
        }),
        throwsA(isA<FormatException>()),
      );

      expect(
        () => LeagueRunSubmissionResponseDto.fromJson({
          'status': 'idempotentReplay',
          'newlyPersisted': true,
          'acceptedRun': _acceptedRunPayload(),
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test('toJson rejects invalid directly constructed response states', () {
      expect(
        () => LeagueRunSubmissionResponseDto(
          status: LeagueMutationStatus.accepted,
          newlyPersisted: false,
          acceptedRun: _acceptedRunDto(),
        ).toJson(),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => LeagueRunSubmissionResponseDto(
          status: LeagueMutationStatus.idempotentReplay,
          newlyPersisted: true,
          acceptedRun: _acceptedRunDto(),
        ).toJson(),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => const LeagueRunSubmissionResponseDto(
          status: LeagueMutationStatus.accepted,
          newlyPersisted: true,
        ).toJson(),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => LeagueRunSubmissionResponseDto(
          status: LeagueMutationStatus.rejected,
          newlyPersisted: false,
          acceptedRun: _acceptedRunDto(),
          rejectionCode: LeagueRunSubmissionRejectionCode.invalidRun,
        ).toJson(),
        throwsA(isA<FormatException>()),
      );
    });
  });
}

LeagueRunSubmissionRequestDto _validRunSubmissionRequestDto({
  String runId = 'run-1',
  String seasonId = '2026-06-15',
  DateTime? runStartedAt,
  DateTime? runCompletedAt,
  int claimedFinalPrecisionPoints = 25000,
  RunValidationClaimDto? validationClaim,
}) {
  final startedAt = runStartedAt ?? DateTime.utc(2026, 6, 21, 10);
  final completedAt = runCompletedAt ?? DateTime.utc(2026, 6, 21, 10, 30);

  return LeagueRunSubmissionRequestDto(
    runId: runId,
    seasonId: seasonId,
    runStartedAt: startedAt,
    runCompletedAt: completedAt,
    claimedFinalPrecisionPoints: claimedFinalPrecisionPoints,
    runMode: LeagueRunSubmissionMode.league,
    validationClaim:
        validationClaim ??
        _validationClaimDto(
          runId: runId,
          finalPrecisionPoints: claimedFinalPrecisionPoints,
          runStartedAt: startedAt,
          runEndedAt: completedAt,
        ),
  );
}

RunValidationClaimDto _validationClaimDto({
  String runId = 'run-1',
  CompetitiveRunType runType = CompetitiveRunType.league,
  int finalPrecisionPoints = 25000,
  DateTime? runStartedAt,
  DateTime? runEndedAt,
}) {
  return RunValidationClaimDto(
    runId: runId,
    runType: runType,
    finalPrecisionPoints: finalPrecisionPoints,
    levelReached: 12,
    precisionPointTier: 8,
    runStartedAt: runStartedAt ?? DateTime.utc(2026, 6, 21, 10),
    runEndedAt: runEndedAt ?? DateTime.utc(2026, 6, 21, 10, 30),
  );
}

Map<String, Object?> _runRequestPayload() {
  return {
    'runId': 'run-1',
    'seasonId': '2026-06-15',
    'runStartedAt': '2026-06-21T10:00:00.000Z',
    'runCompletedAt': '2026-06-21T10:30:00.000Z',
    'claimedFinalPrecisionPoints': 25000,
    'runMode': 'league',
    'validationClaim': _validationClaimPayload(),
  };
}

Map<String, Object?> _validationClaimPayload() {
  return {
    'runId': 'run-1',
    'runType': 'league',
    'finalPrecisionPoints': 25000,
    'levelReached': 12,
    'precisionPointTier': 8,
    'runStartedAt': '2026-06-21T10:00:00.000Z',
    'runEndedAt': '2026-06-21T10:30:00.000Z',
  };
}

Map<String, Object?> _acceptedRunPayload() {
  return {
    'playerId': 'player-1',
    'score': 25000,
    'completedAt': '2026-06-21T10:30:00.000Z',
  };
}

WeeklyLeagueRunDto _acceptedRunDto() {
  return WeeklyLeagueRunDto.fromJson(_acceptedRunPayload());
}

Map<String, Object?> _playerRecordsPayload() {
  return {
    'playerId': 'player-1',
    'allTimeBestFinalScore': 25000,
    'currentWeeklyBestScore': 25000,
    'currentSeasonId': '2026-06-15',
  };
}

Map<String, Object?> _entryPayload(String playerId) {
  return {
    'playerId': playerId,
    'username': 'Tester $playerId',
    'divisionNumber': 2,
    'hasReservedSlot': true,
    'entryPaid': true,
    'registeredAt': '2026-06-01T12:00:00.000Z',
    'lifetimeLeagueTournamentRuns': 12,
    'lifetimeAverageScorePerRun': 345.5,
  };
}

LeaguePlayerEntryDto _entryDto(String playerId) {
  return LeaguePlayerEntryDto.fromJson(_entryPayload(playerId));
}

Map<String, Object?> _playerProfilePayload({required int gamePoints}) {
  return {
    'id': 'player-1',
    'username': 'Tester',
    'createdAt': '2026-06-01T12:00:00.000Z',
    'gamePoints': gamePoints,
    'adsRemoved': false,
    'currentLeagueDivision': 2,
    'hasWeeklyLeagueEntry': true,
    'reservedLeagueSlot': true,
  };
}
