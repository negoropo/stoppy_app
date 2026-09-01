import 'package:flutter_test/flutter_test.dart';
import 'package:stoppy_app/core/backend/api_contract.dart';
import 'package:stoppy_app/core/backend/api_error.dart';
import 'package:stoppy_app/core/backend/api_response.dart';
import 'package:stoppy_app/core/backend/backend_api_client.dart';
import 'package:stoppy_app/core/backend/idempotency_key.dart';
import 'package:stoppy_app/features/auth/domain/models/player_profile.dart';
import 'package:stoppy_app/features/knockout/data/backend/backend_knockout_repository.dart';
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

    test(
      'registration remains explicitly disconnected from backend runtime',
      () {
        final apiClient = _FakeBackendApiClient();
        final repository = BackendKnockoutRepository(apiClient: apiClient);

        expect(
          () => repository.registerPlayer(
            tournament: _tournament(),
            playerProfile: _playerProfile(),
            idempotencyKey: IdempotencyKey(
              'knockout-register-player-1-2026-06',
            ),
          ),
          throwsNotImplementedFor('registerPlayer'),
        );
        expect(apiClient.requests, isEmpty);
      },
    );

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
        expect(apiClient.requests, isEmpty);
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
      expect(apiClient.requests, isEmpty);
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

KnockoutTournament _tournament() {
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

PlayerProfile _playerProfile() {
  return PlayerProfile(
    id: 'player-1',
    username: 'Tester',
    createdAt: DateTime.utc(2026),
    gamePoints: 50,
  );
}

final class _FakeBackendApiClient implements BackendApiClient {
  final List<String> requests = [];

  @override
  Future<ApiResponse<Map<String, Object?>>> delete(
    String path, {
    Map<String, String> queryParameters = const {},
    Map<String, String> headers = const {},
  }) async {
    requests.add(path);
    return const ApiResponse.success({});
  }

  @override
  Future<ApiResponse<Map<String, Object?>>> get(
    String path, {
    Map<String, String> queryParameters = const {},
    Map<String, String> headers = const {},
  }) async {
    requests.add(path);
    return const ApiResponse.success({});
  }

  @override
  Future<ApiResponse<Map<String, Object?>>> patch(
    String path, {
    Map<String, Object?> body = const {},
    Map<String, String> headers = const {},
  }) async {
    requests.add(path);
    return const ApiResponse.success({});
  }

  @override
  Future<ApiResponse<Map<String, Object?>>> post(
    String path, {
    Map<String, Object?> body = const {},
    Map<String, String> headers = const {},
  }) async {
    requests.add(path);
    return const ApiResponse.success({});
  }

  @override
  Future<ApiResponse<Map<String, Object?>>> put(
    String path, {
    Map<String, Object?> body = const {},
    Map<String, String> headers = const {},
  }) async {
    requests.add(path);
    return const ApiResponse.success({});
  }
}
