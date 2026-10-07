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
import 'package:stoppy_app/features/knockout/domain/models/knockout_hall_of_fame_entry.dart';
import 'package:stoppy_app/features/knockout/domain/models/knockout_match.dart';
import 'package:stoppy_app/features/knockout/domain/models/knockout_player_entry.dart';
import 'package:stoppy_app/features/knockout/domain/models/knockout_player_records.dart';
import 'package:stoppy_app/features/knockout/domain/models/knockout_player_status.dart';
import 'package:stoppy_app/features/knockout/domain/models/knockout_round.dart';
import 'package:stoppy_app/features/knockout/domain/models/knockout_run.dart';
import 'package:stoppy_app/features/knockout/domain/models/knockout_tournament.dart';
import 'package:stoppy_app/features/knockout/domain/models/knockout_tournament_history_entry.dart';

void main() {
  group('BackendKnockoutRepository preparation', () {
    test('exposes centralized Knockout API contract paths', () {
      expect(
        BackendKnockoutRepository.tournamentPath,
        ApiContract.knockoutTournament,
      );
      expect(
        BackendKnockoutRepository.currentEntryPath,
        ApiContract.knockoutEntry,
      );
      expect(BackendKnockoutRepository.statusPath, ApiContract.knockoutStatus);
      expect(
        BackendKnockoutRepository.activeDuelPath,
        ApiContract.knockoutActiveDuel,
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

    test('fetchCurrentTournament maps backend tournament read', () async {
      final tournament = _tournamentWithActiveDuel();
      final apiClient = _FakeBackendApiClient()
        ..enqueueGetSuccess(
          KnockoutTournamentDto.fromDomain(tournament).toJson(),
        );
      final repository = BackendKnockoutRepository(apiClient: apiClient);

      final result = await repository.fetchCurrentTournament();

      expect(result.id, tournament.id);
      expect(result.rounds.single.roundNumber, _match().roundNumber);
      expect(apiClient.getRequests.single.path, ApiContract.knockoutTournament);
      expect(apiClient.getRequests.single.queryParameters, isEmpty);
    });

    test(
      'fetchCurrentTournament maps API and malformed payload failures',
      () async {
        final failureClient = _FakeBackendApiClient()
          ..enqueueGetFailure(
            const ApiError(
              code: ApiErrorCode.serverError,
              message: 'Server unavailable.',
            ),
          );
        final malformedClient = _FakeBackendApiClient()
          ..enqueueGetSuccess({'id': '2026-06'});

        await expectLater(
          BackendKnockoutRepository(
            apiClient: failureClient,
          ).fetchCurrentTournament(),
          throwsA(
            isA<RepositoryDomainException>().having(
              (exception) => exception.code,
              'code',
              ApiErrorCode.serverError,
            ),
          ),
        );
        await expectLater(
          BackendKnockoutRepository(
            apiClient: malformedClient,
          ).fetchCurrentTournament(),
          throwsA(
            isA<RepositoryDomainException>().having(
              (exception) => exception.code,
              'code',
              ApiErrorCode.malformedPayload,
            ),
          ),
        );
      },
    );

    test('currentEntry reads authenticated self-projection', () async {
      final apiClient = _FakeBackendApiClient()
        ..enqueueGetSuccess({
          'playerEntry': KnockoutPlayerEntryDto.fromDomain(_entry()).toJson(),
        });
      final repository = BackendKnockoutRepository(apiClient: apiClient);

      final result = await repository.currentEntry(
        tournamentId: 'client-tournament-id',
        playerId: 'client-player-id',
      );

      expect(result?.playerId, 'player-1');
      expect(apiClient.getRequests.single.path, ApiContract.knockoutEntry);
      expect(apiClient.getRequests.single.queryParameters, isEmpty);
    });

    test('currentEntry supports valid no-entry response', () async {
      final apiClient = _FakeBackendApiClient()
        ..enqueueGetSuccess({'playerEntry': null});
      final repository = BackendKnockoutRepository(apiClient: apiClient);

      final result = await repository.currentEntry(
        tournamentId: '2026-06',
        playerId: 'player-1',
      );

      expect(result, isNull);
      expect(apiClient.getRequests.single.queryParameters, isEmpty);
    });

    test('currentEntry rejects malformed payload', () async {
      final apiClient = _FakeBackendApiClient()
        ..enqueueGetSuccess({
          'playerEntry': {'playerId': 'player-1'},
        });
      final repository = BackendKnockoutRepository(apiClient: apiClient);

      await expectLater(
        repository.currentEntry(tournamentId: '2026-06', playerId: 'player-1'),
        throwsA(
          isA<RepositoryDomainException>().having(
            (exception) => exception.code,
            'code',
            ApiErrorCode.malformedPayload,
          ),
        ),
      );
    });

    test('fetchPlayerStatus maps status variants and active duel', () async {
      final apiClient = _FakeBackendApiClient()
        ..enqueueGetSuccess({'state': 'registeredWaitingStart'})
        ..enqueueGetSuccess({
          'state': 'activeDuel',
          'duelSnapshot': _duelJson(),
        });
      final repository = BackendKnockoutRepository(apiClient: apiClient);

      final waiting = await repository.fetchPlayerStatus(
        tournamentId: 'client-tournament-id',
        playerId: 'client-player-id',
      );
      final active = await repository.fetchPlayerStatus(
        tournamentId: 'client-tournament-id',
        playerId: 'client-player-id',
      );

      expect(
        waiting.state,
        KnockoutPlayerTournamentState.registeredWaitingStart,
      );
      expect(active.state, KnockoutPlayerTournamentState.activeDuel);
      expect(active.duelSnapshot?.match.id, 'match-1');
      expect(
        apiClient.getRequests.every(
          (request) => request.queryParameters.isEmpty,
        ),
        isTrue,
      );
    });

    test(
      'fetchPlayerStatus rejects invalid or contradictory payload',
      () async {
        final invalidClient = _FakeBackendApiClient()
          ..enqueueGetSuccess({'state': 'unknown'});
        final contradictoryClient = _FakeBackendApiClient()
          ..enqueueGetSuccess({'state': 'activeDuel'});

        await expectLater(
          BackendKnockoutRepository(
            apiClient: invalidClient,
          ).fetchPlayerStatus(tournamentId: '2026-06', playerId: 'player-1'),
          throwsA(
            isA<RepositoryDomainException>().having(
              (exception) => exception.code,
              'code',
              ApiErrorCode.malformedPayload,
            ),
          ),
        );
        await expectLater(
          BackendKnockoutRepository(
            apiClient: contradictoryClient,
          ).fetchPlayerStatus(tournamentId: '2026-06', playerId: 'player-1'),
          throwsA(
            isA<RepositoryDomainException>().having(
              (exception) => exception.code,
              'code',
              ApiErrorCode.malformedPayload,
            ),
          ),
        );
      },
    );

    test('fetchActiveDuel maps duel and valid no-duel response', () async {
      final apiClient = _FakeBackendApiClient()
        ..enqueueGetSuccess({'duelSnapshot': _duelJson()})
        ..enqueueGetSuccess({'duelSnapshot': null});
      final repository = BackendKnockoutRepository(apiClient: apiClient);

      final duel = await repository.fetchActiveDuel(
        tournamentId: 'client-tournament-id',
        playerId: 'client-player-id',
      );
      final noDuel = await repository.fetchActiveDuel(
        tournamentId: 'client-tournament-id',
        playerId: 'client-player-id',
      );

      expect(duel?.opponentId, 'opponent-1');
      expect(duel?.playerScore, 1200);
      expect(duel?.playerRunCount, 3);
      expect(noDuel, isNull);
      expect(
        apiClient.getRequests.every(
          (request) => request.queryParameters.isEmpty,
        ),
        isTrue,
      );
    });

    test('fetchActiveDuel rejects malformed duel payload', () async {
      final apiClient = _FakeBackendApiClient()
        ..enqueueGetSuccess({
          'duelSnapshot': {..._duelJson(), 'playerRunCount': -1},
        });
      final repository = BackendKnockoutRepository(apiClient: apiClient);

      await expectLater(
        repository.fetchActiveDuel(
          tournamentId: '2026-06',
          playerId: 'player-1',
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

    test('records history and Hall of Fame reads map backend data', () async {
      final apiClient = _FakeBackendApiClient()
        ..enqueueGetSuccess(
          KnockoutPlayerRecordsDto.fromDomain(_records()).toJson(),
        )
        ..enqueueGetSuccess({
          'history': [
            KnockoutTournamentHistoryEntryDto.fromDomain(_history()).toJson(),
          ],
        })
        ..enqueueGetSuccess({
          'hallOfFame': [
            KnockoutHallOfFameEntryDto.fromDomain(_hallOfFame()).toJson(),
          ],
        });
      final repository = BackendKnockoutRepository(apiClient: apiClient);

      final records = await repository.fetchPlayerRecords('client-player-id');
      final history = await repository.fetchPlayerHistory('client-player-id');
      final hallOfFame = await repository.fetchHallOfFame();

      expect(records.playerId, 'player-1');
      expect(history.single.tournamentId, '2026-06');
      expect(hallOfFame.single.displayName, 'Champion');
      expect(apiClient.getRequests.map((request) => request.path), [
        ApiContract.knockoutRecords,
        ApiContract.knockoutHistory,
        ApiContract.knockoutHallOfFame,
      ]);
      expect(
        apiClient.getRequests.every(
          (request) => request.queryParameters.isEmpty,
        ),
        isTrue,
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
        expect(apiClient.getRequests, isEmpty);
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
      expect(apiClient.getRequests, isEmpty);
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
  return _tournament(entries: [_entry()]);
}

KnockoutPlayerEntry _entry() {
  return KnockoutPlayerEntry(
    playerId: 'player-1',
    username: 'Tester',
    tournamentId: '2026-06',
    registeredAt: DateTime.utc(2026, 5, 22, 12),
    accountCreatedAt: DateTime.utc(2026),
    entryCostGamePoints: 25,
  );
}

KnockoutTournament _tournamentWithActiveDuel() {
  return _tournament(
    entries: [
      _entry(),
      KnockoutPlayerEntry(
        playerId: 'opponent-1',
        username: 'Opponent',
        tournamentId: '2026-06',
        registeredAt: DateTime.utc(2026, 5, 22, 12),
        accountCreatedAt: DateTime.utc(2026),
        entryCostGamePoints: 25,
      ),
    ],
  ).copyWith(
    status: KnockoutTournamentStatus.inProgress,
    rounds: [
      KnockoutRound(
        roundNumber: _match().roundNumber,
        startsAt: DateTime.utc(2026, 6, 1),
        endsAt: DateTime.utc(2026, 6, 1, 23, 59),
        status: KnockoutRoundStatus.active,
        matches: [_match()],
      ),
    ],
  );
}

KnockoutMatch _match() {
  return const KnockoutMatch(
    id: 'match-1',
    roundNumber: 2,
    status: KnockoutMatchStatus.active,
    playerOneId: 'player-1',
    playerTwoId: 'opponent-1',
    playerOneScore: 1200,
    playerTwoScore: 900,
    playerOneRunCount: 3,
    playerTwoRunCount: 2,
  );
}

Map<String, Object?> _duelJson() {
  return {
    'tournamentId': '2026-06',
    'roundNumber': 2,
    'roundEndsAt': DateTime.utc(2026, 6, 2, 23, 59).toIso8601String(),
    'playerId': 'player-1',
    'opponentId': 'opponent-1',
    'match': KnockoutMatchDto.fromDomain(_match()).toJson(),
    'playerScore': 1200,
    'opponentScore': 900,
    'playerRunCount': 3,
    'opponentRunCount': 2,
  };
}

KnockoutPlayerRecords _records() {
  return const KnockoutPlayerRecords(
    playerId: 'player-1',
    tournamentsPlayed: 2,
    tournamentsWon: 1,
    highestRoundReached: 4,
    totalDuelsPlayed: 6,
    totalDuelsWon: 4,
  );
}

KnockoutTournamentHistoryEntry _history() {
  return KnockoutTournamentHistoryEntry(
    tournamentId: '2026-06',
    tournamentName: 'June Knockout',
    tournamentMonth: DateTime.utc(2026, 6),
    playerId: 'player-1',
    outcome: KnockoutTournamentOutcome.eliminated,
    finalRoundNumber: 2,
    completedAt: DateTime.utc(2026, 6, 3),
  );
}

KnockoutHallOfFameEntry _hallOfFame() {
  return KnockoutHallOfFameEntry(
    playerId: 'champion-1',
    displayName: 'Champion',
    titlesWon: 1,
    wonTournamentMonths: [DateTime.utc(2026, 6)],
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
  final List<_GetRequest> getRequests = [];
  final List<_PostRequest> postRequests = [];
  final List<_QueuedApiResult> _getResults = [];
  final List<_QueuedApiResult> _postResults = [];

  void enqueueGetSuccess(Map<String, Object?> data) {
    _getResults.add(_QueuedApiResult.response(ApiResponse.success(data)));
  }

  void enqueueGetFailure(ApiError error) {
    _getResults.add(_QueuedApiResult.response(ApiResponse.failure(error)));
  }

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
    getRequests.add(_GetRequest(path, Map<String, String>.of(queryParameters)));

    if (_getResults.isEmpty) {
      throw StateError('No GET response was enqueued for $path.');
    }

    return _getResults.removeAt(0).resolve();
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

final class _GetRequest {
  const _GetRequest(this.path, this.queryParameters);

  final String path;
  final Map<String, String> queryParameters;
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
