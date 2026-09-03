import 'package:flutter_test/flutter_test.dart';
import 'package:stoppy_app/core/backend/api_contract.dart';
import 'package:stoppy_app/core/backend/api_error.dart';
import 'package:stoppy_app/core/backend/api_response.dart';
import 'package:stoppy_app/core/backend/backend_api_client.dart';
import 'package:stoppy_app/core/backend/domain_error_mapper.dart';
import 'package:stoppy_app/core/backend/idempotency_key.dart';
import 'package:stoppy_app/features/auth/data/dto/player_profile_dto.dart';
import 'package:stoppy_app/features/auth/domain/models/player_profile.dart';
import 'package:stoppy_app/features/knockout/data/backend/backend_knockout_repository.dart';
import 'package:stoppy_app/features/knockout/data/dto/knockout_persistence_dtos.dart';
import 'package:stoppy_app/features/knockout/domain/models/knockout_player_entry.dart';
import 'package:stoppy_app/features/knockout/domain/models/knockout_run.dart';
import 'package:stoppy_app/features/knockout/domain/models/knockout_tournament.dart';

void main() {
  group('BackendKnockoutRepository preparation', () {
    test('exposes centralized Knockout API contract paths', () {
      expect(
        BackendKnockoutRepository.tournamentPath,
        ApiContract.knockoutTournament,
      );
      expect(
        BackendKnockoutRepository.registerPath,
        ApiContract.knockoutRegistration,
      );
      expect(
        BackendKnockoutRepository.runSubmissionPath,
        ApiContract.knockoutRunSubmission,
      );
    });

    test('registerPlayer sends empty POST with idempotency key', () async {
      final tournament = _tournamentWithEntry();
      final apiClient = _FakeBackendApiClient()
        ..enqueuePostSuccess(
          _registrationResponsePayload(
            status: 'accepted',
            newlyPersisted: true,
            tournament: tournament,
            remainingGamePoints: 75,
          ),
        );
      final repository = BackendKnockoutRepository(apiClient: apiClient);

      final result = await repository.registerPlayer(
        tournament: _tournament(),
        playerProfile: _playerProfile(gamePoints: 100),
        idempotencyKey: IdempotencyKey('knockout-register-player-1-2026-06'),
      );

      expect(result.isSuccess, isTrue);
      expect(result.playerEntry?.playerId, 'player-1');
      expect(result.remainingGamePoints, 75);
      expect(result.playerProfile?.gamePoints, 75);
      expect(
        apiClient.postRequests.single.path,
        ApiContract.knockoutRegistration,
      );
      expect(apiClient.postRequests.single.body, isEmpty);
      expect(
        apiClient.postRequests.single.body.keys,
        isNot(contains('playerId')),
      );
      expect(
        apiClient.postRequests.single.body.keys,
        isNot(contains('gamePoints')),
      );
      expect(
        apiClient.postRequests.single.body.keys,
        isNot(contains('tournamentId')),
      );
      expect(apiClient.postRequests.single.headers, {
        ApiContract.idempotencyKeyHeader: 'knockout-register-player-1-2026-06',
      });
      expect(
        apiClient.postRequests.single.headers.keys,
        isNot(contains(ApiContract.authorizationHeader)),
      );
    });

    test('registerPlayer maps idempotent replay as success', () async {
      final tournament = _tournamentWithEntry();
      final apiClient = _FakeBackendApiClient()
        ..enqueuePostSuccess(
          _registrationResponsePayload(
            status: 'idempotentReplay',
            newlyPersisted: false,
            tournament: tournament,
            remainingGamePoints: 75,
          ),
        );
      final repository = BackendKnockoutRepository(apiClient: apiClient);

      final result = await repository.registerPlayer(
        tournament: _tournament(),
        playerProfile: _playerProfile(gamePoints: 100),
        idempotencyKey: IdempotencyKey('knockout-register-player-1-2026-06'),
      );

      expect(result.isSuccess, isTrue);
      expect(result.playerEntry?.tournamentId, tournament.id);
      expect(result.remainingGamePoints, 75);
    });

    test('registerPlayer maps definitive rejection to domain result', () async {
      final apiClient = _FakeBackendApiClient()
        ..enqueuePostSuccess({
          'status': 'rejected',
          'newlyPersisted': false,
          'tournament': KnockoutTournamentDto.fromDomain(
            _tournament(),
          ).toJson(),
          'rejectionCode': 'insufficientGp',
        });
      final repository = BackendKnockoutRepository(apiClient: apiClient);

      final result = await repository.registerPlayer(
        tournament: _tournament(),
        playerProfile: _playerProfile(gamePoints: 24),
        idempotencyKey: IdempotencyKey('knockout-register-player-1-2026-06'),
      );

      expect(result.isFailure, isTrue);
      expect(result.playerEntry, isNull);
      expect(result.message, 'You need 25 GP to register.');
      expect(apiClient.postRequests.length, 1);
    });

    test('registerPlayer requires explicit idempotency key before HTTP', () {
      final apiClient = _FakeBackendApiClient();
      final repository = BackendKnockoutRepository(apiClient: apiClient);

      expect(
        () => repository.registerPlayer(
          tournament: _tournament(),
          playerProfile: _playerProfile(),
        ),
        throwsA(
          isA<RepositoryDomainException>().having(
            (exception) => exception.code,
            'code',
            ApiErrorCode.malformedPayload,
          ),
        ),
      );
      expect(apiClient.postRequests, isEmpty);
    });

    test('registerPlayer maps API failures and does not retry', () async {
      final apiClient = _FakeBackendApiClient()
        ..enqueuePostFailure(
          const ApiError(
            code: ApiErrorCode.networkUnavailable,
            message: 'Network down.',
          ),
        );
      final repository = BackendKnockoutRepository(apiClient: apiClient);

      await expectLater(
        repository.registerPlayer(
          tournament: _tournament(),
          playerProfile: _playerProfile(),
          idempotencyKey: IdempotencyKey('knockout-register-player-1-2026-06'),
        ),
        throwsA(
          isA<RepositoryDomainException>().having(
            (exception) => exception.code,
            'code',
            ApiErrorCode.networkUnavailable,
          ),
        ),
      );
      expect(apiClient.postRequests.length, 1);
    });

    test('registerPlayer rejects malformed success payloads', () async {
      final tournament = _tournamentWithEntry();
      final apiClient = _FakeBackendApiClient()
        ..enqueuePostSuccess(
          _registrationResponsePayload(
            status: 'accepted',
            newlyPersisted: true,
            tournament: tournament,
            remainingGamePoints: 75,
            profileGamePoints: 74,
          ),
        );
      final repository = BackendKnockoutRepository(apiClient: apiClient);

      await expectLater(
        repository.registerPlayer(
          tournament: _tournament(),
          playerProfile: _playerProfile(),
          idempotencyKey: IdempotencyKey('knockout-register-player-1-2026-06'),
        ),
        throwsA(
          isA<RepositoryDomainException>().having(
            (exception) => exception.code,
            'code',
            ApiErrorCode.malformedPayload,
          ),
        ),
      );
    });

    test(
      'run submission remains explicitly disconnected from backend runtime',
      () {
        final apiClient = _FakeBackendApiClient();
        final repository = BackendKnockoutRepository(apiClient: apiClient);

        expect(
          () => repository.submitKnockoutRun(
            KnockoutRun(
              id: 'run-1',
              playerId: 'player-1',
              matchId: 'match-1',
              roundNumber: 1,
              score: 42000,
              completedAt: DateTime.utc(2026, 6, 2, 10),
            ),
            idempotencyKey: IdempotencyKey('knockout-run-1'),
          ),
          throwsNotImplementedFor('submitKnockoutRun'),
        );
        expect(apiClient.postRequests, isEmpty);
      },
    );

    test('server-only lifecycle mutations remain disconnected', () {
      final apiClient = _FakeBackendApiClient();
      final repository = BackendKnockoutRepository(apiClient: apiClient);

      expect(
        () => repository.closeRegistration(tournamentId: '2026-06'),
        throwsNotImplementedFor('closeRegistration'),
      );
      expect(
        () => repository.startTournament(tournamentId: '2026-06'),
        throwsNotImplementedFor('startTournament'),
      );
      expect(
        () => repository.settleCurrentRound(tournamentId: '2026-06'),
        throwsNotImplementedFor('settleCurrentRound'),
      );
      expect(apiClient.postRequests, isEmpty);
    });
  });
}

Matcher throwsNotImplementedFor(String methodName) {
  return throwsA(
    isA<ApiException>()
        .having(
          (exception) => exception.error.code,
          'code',
          ApiErrorCode.notImplemented,
        )
        .having(
          (exception) => exception.error.details['method'],
          'method',
          methodName,
        ),
  );
}

KnockoutTournament _tournament({List<KnockoutPlayerEntry> entries = const []}) {
  return KnockoutTournament(
    id: '2026-06',
    name: 'June Knockout',
    entryCostGamePoints: 25,
    tournamentMonth: DateTime.utc(2026, 6),
    registrationOpensAt: DateTime.utc(2026, 5),
    registrationClosesAt: DateTime.utc(2026, 5, 31, 23, 59),
    startsAt: DateTime.utc(2026, 6),
    entries: entries,
  );
}

KnockoutTournament _tournamentWithEntry() {
  return _tournament(
    entries: [
      KnockoutPlayerEntry(
        playerId: 'player-1',
        username: 'Tester',
        tournamentId: '2026-06',
        registeredAt: DateTime.utc(2026, 5, 22, 12),
        accountCreatedAt: DateTime.utc(2026),
        entryCostGamePoints: 25,
      ),
    ],
  );
}

PlayerProfile _playerProfile({int gamePoints = 50}) {
  return PlayerProfile(
    id: 'player-1',
    username: 'Tester',
    createdAt: DateTime.utc(2026),
    gamePoints: gamePoints,
  );
}

Map<String, Object?> _registrationResponsePayload({
  required String status,
  required bool newlyPersisted,
  required KnockoutTournament tournament,
  required int remainingGamePoints,
  int? profileGamePoints,
}) {
  return {
    'status': status,
    'newlyPersisted': newlyPersisted,
    'tournament': KnockoutTournamentDto.fromDomain(tournament).toJson(),
    'playerEntry': KnockoutPlayerEntryDto.fromDomain(
      tournament.entries.single,
    ).toJson(),
    'remainingGamePoints': remainingGamePoints,
    'playerProfile': PlayerProfileDto.fromDomain(
      _playerProfile(gamePoints: profileGamePoints ?? remainingGamePoints),
    ).toJson(),
  };
}

final class _FakeBackendApiClient implements BackendApiClient {
  final List<_PostRequest> postRequests = [];
  final List<_QueuedApiResult> _postResults = [];

  void enqueuePostSuccess(Map<String, Object?> data) {
    _postResults.add(_QueuedApiResult.response(ApiResponse.success(data)));
  }

  void enqueuePostFailure(ApiError error) {
    _postResults.add(_QueuedApiResult.response(ApiResponse.failure(error)));
  }

  @override
  Future<ApiResponse<Map<String, Object?>>> delete(
    String path, {
    Map<String, String> queryParameters = const {},
    Map<String, String> headers = const {},
  }) async {
    return const ApiResponse.success({});
  }

  @override
  Future<ApiResponse<Map<String, Object?>>> get(
    String path, {
    Map<String, String> queryParameters = const {},
    Map<String, String> headers = const {},
  }) async {
    return const ApiResponse.success({});
  }

  @override
  Future<ApiResponse<Map<String, Object?>>> patch(
    String path, {
    Map<String, Object?> body = const {},
    Map<String, String> headers = const {},
  }) async {
    return const ApiResponse.success({});
  }

  @override
  Future<ApiResponse<Map<String, Object?>>> post(
    String path, {
    Map<String, Object?> body = const {},
    Map<String, String> headers = const {},
  }) async {
    postRequests.add(
      _PostRequest(
        path,
        Map<String, Object?>.of(body),
        Map<String, String>.of(headers),
      ),
    );

    if (_postResults.isEmpty) {
      throw StateError('No POST response was enqueued for $path.');
    }

    return _postResults.removeAt(0).resolve();
  }

  @override
  Future<ApiResponse<Map<String, Object?>>> put(
    String path, {
    Map<String, Object?> body = const {},
    Map<String, String> headers = const {},
  }) async {
    return const ApiResponse.success({});
  }
}

final class _PostRequest {
  const _PostRequest(this.path, this.body, this.headers);

  final String path;
  final Map<String, Object?> body;
  final Map<String, String> headers;
}

final class _QueuedApiResult {
  const _QueuedApiResult.response(this.response);

  final ApiResponse<Map<String, Object?>> response;

  ApiResponse<Map<String, Object?>> resolve() => response;
}
