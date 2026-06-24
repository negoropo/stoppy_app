import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:stoppy_app/core/backend/api_contract.dart';
import 'package:stoppy_app/core/backend/api_error.dart';
import 'package:stoppy_app/core/backend/api_response.dart';
import 'package:stoppy_app/core/backend/auth_session.dart';
import 'package:stoppy_app/core/backend/backend_api_client.dart';
import 'package:stoppy_app/features/auth/data/backend/auth_session_refresh_coordinator.dart';

void main() {
  final now = DateTime.utc(2026, 6, 24, 12);

  AuthSession expiringSession({String? refreshToken = 'old-refresh'}) {
    return AuthSession(
      accessToken: 'old-access',
      refreshToken: refreshToken,
      expiresAt: now.add(const Duration(seconds: 30)),
    );
  }

  AuthSession expiredSession({String? refreshToken = 'old-refresh'}) {
    return AuthSession(
      accessToken: 'old-access',
      refreshToken: refreshToken,
      expiresAt: now,
    );
  }

  test('returns the current session when it is not expiring soon', () async {
    final session = AuthSession(
      accessToken: 'current-access',
      refreshToken: 'current-refresh',
      expiresAt: now.add(const Duration(hours: 1)),
    );
    final store = _FakeAuthSessionStore(session: session);
    final client = _RefreshClient();
    final coordinator = AuthSessionRefreshCoordinator(
      apiClient: client,
      authSessionStore: store,
      now: () => now,
    );

    final result = await coordinator.refreshIfNeeded(session);

    expect(result.isSuccess, isTrue);
    expect(result.requireData(), same(session));
    expect(client.calls, 0);
    expect(store.saveCalls, 0);
    expect(store.clearCalls, 0);
  });

  test(
    'replaces and persists a session while preserving an omitted refresh token',
    () async {
      final oldSession = expiringSession();
      final store = _FakeAuthSessionStore(session: oldSession);
      final client = _RefreshClient()
        ..response = ApiResponse.success(
          _sessionPayload(now.add(const Duration(hours: 1))),
        );
      final coordinator = AuthSessionRefreshCoordinator(
        apiClient: client,
        authSessionStore: store,
        now: () => now,
      );

      final result = await coordinator.refreshIfNeeded(oldSession);

      expect(result.requireData().accessToken, 'new-access');
      expect(result.requireData().refreshToken, 'old-refresh');
      expect(store.session?.accessToken, 'new-access');
      expect(store.session?.refreshToken, 'old-refresh');
      expect(store.saveCalls, 1);
      expect(client.calls, 1);
      expect(client.lastPath, ApiContract.authRefresh);
      expect(client.lastBody, {'refreshToken': 'old-refresh'});
    },
  );

  test('uses and persists a rotated refresh token when returned', () async {
    final oldSession = expiringSession();
    final store = _FakeAuthSessionStore(session: oldSession);
    final client = _RefreshClient()
      ..response = ApiResponse.success(
        _sessionPayload(
          now.add(const Duration(hours: 1)),
          refreshToken: 'new-refresh',
        ),
      );
    final coordinator = AuthSessionRefreshCoordinator(
      apiClient: client,
      authSessionStore: store,
      now: () => now,
    );

    final result = await coordinator.refreshIfNeeded(oldSession);

    expect(result.requireData().accessToken, 'new-access');
    expect(result.requireData().refreshToken, 'new-refresh');
    expect(store.session?.refreshToken, 'new-refresh');
    expect(store.saveCalls, 1);
  });

  test(
    'returns a still-valid session when refresh token is unavailable',
    () async {
      final session = expiringSession(refreshToken: null);
      final store = _FakeAuthSessionStore(session: session);
      final client = _RefreshClient();
      final coordinator = AuthSessionRefreshCoordinator(
        apiClient: client,
        authSessionStore: store,
        now: () => now,
      );

      final result = await coordinator.refreshIfNeeded(session);

      expect(result.isSuccess, isTrue);
      expect(result.requireData(), same(session));
      expect(client.calls, 0);
      expect(store.clearCalls, 0);
      expect(store.saveCalls, 0);
      expect(store.session, same(session));
    },
  );

  test('clears an expired session when refresh token is unavailable', () async {
    final session = expiredSession(refreshToken: null);
    final store = _FakeAuthSessionStore(session: session);
    final client = _RefreshClient();
    final coordinator = AuthSessionRefreshCoordinator(
      apiClient: client,
      authSessionStore: store,
      now: () => now,
    );

    final result = await coordinator.refreshIfNeeded(session);

    expect(result.isSuccess, isFalse);
    expect(result.requireError().code, ApiErrorCode.unauthenticated);
    expect(store.session, isNull);
    expect(store.clearCalls, 1);
    expect(client.calls, 0);
  });

  test(
    'clears invalid credentials but preserves sessions for temporary failures',
    () async {
      final oldSession = expiringSession();
      final store = _FakeAuthSessionStore(session: oldSession);
      final client = _RefreshClient()
        ..response = const ApiResponse.failure(
          ApiError(code: ApiErrorCode.unauthenticated, message: 'invalid'),
        );
      final coordinator = AuthSessionRefreshCoordinator(
        apiClient: client,
        authSessionStore: store,
        now: () => now,
      );

      final invalidResult = await coordinator.refreshIfNeeded(oldSession);

      expect(invalidResult.isSuccess, isFalse);
      expect(invalidResult.requireError().code, ApiErrorCode.unauthenticated);
      expect(store.session, isNull);
      expect(store.clearCalls, 1);

      store.session = oldSession;
      client.response = const ApiResponse.failure(
        ApiError(code: ApiErrorCode.requestTimeout, message: 'timeout'),
      );

      final temporaryFailure = await coordinator.refreshIfNeeded(oldSession);

      expect(temporaryFailure.isSuccess, isFalse);
      expect(temporaryFailure.requireError().code, ApiErrorCode.requestTimeout);
      expect(store.session, same(oldSession));
      expect(store.clearCalls, 1);
    },
  );

  test('clears the session when refresh is forbidden', () async {
    final oldSession = expiringSession();
    final store = _FakeAuthSessionStore(session: oldSession);
    final client = _RefreshClient()
      ..response = const ApiResponse.failure(
        ApiError(code: ApiErrorCode.forbidden, message: 'forbidden'),
      );
    final coordinator = AuthSessionRefreshCoordinator(
      apiClient: client,
      authSessionStore: store,
      now: () => now,
    );

    final result = await coordinator.refreshIfNeeded(oldSession);

    expect(result.isSuccess, isFalse);
    expect(result.requireError().code, ApiErrorCode.forbidden);
    expect(store.session, isNull);
    expect(store.clearCalls, 1);
  });

  test('preserves authentication failure when local clear fails', () async {
    final oldSession = expiringSession();
    final store = _FakeAuthSessionStore(session: oldSession)
      ..clearError = AuthSessionStoreException(
        operation: AuthSessionStoreOperation.clear,
        cause: Exception('storage unavailable'),
      );
    final client = _RefreshClient()
      ..response = const ApiResponse.failure(
        ApiError(
          code: ApiErrorCode.unauthenticated,
          message: 'invalid refresh token',
        ),
      );
    final coordinator = AuthSessionRefreshCoordinator(
      apiClient: client,
      authSessionStore: store,
      now: () => now,
    );

    final result = await coordinator.refreshIfNeeded(oldSession);

    expect(result.isSuccess, isFalse);
    expect(result.requireError().code, ApiErrorCode.unauthenticated);
    expect(store.clearCalls, 1);

    // The local value remains because cleanup failed, but the authoritative
    // backend authentication failure is still returned.
    expect(store.session, same(oldSession));
  });

  test(
    'preserves unavailable-refresh failure when local clear fails',
    () async {
      final session = expiredSession(refreshToken: null);
      final store = _FakeAuthSessionStore(session: session)
        ..clearError = AuthSessionStoreException(
          operation: AuthSessionStoreOperation.clear,
          cause: Exception('storage unavailable'),
        );
      final client = _RefreshClient();
      final coordinator = AuthSessionRefreshCoordinator(
        apiClient: client,
        authSessionStore: store,
        now: () => now,
      );

      final result = await coordinator.refreshIfNeeded(session);

      expect(result.isSuccess, isFalse);
      expect(result.requireError().code, ApiErrorCode.unauthenticated);
      expect(store.clearCalls, 1);
      expect(client.calls, 0);
    },
  );

  test(
    'propagates session-store failure when refreshed session cannot be saved',
    () async {
      final oldSession = expiringSession();
      final store = _FakeAuthSessionStore(session: oldSession)
        ..saveError = AuthSessionStoreException(
          operation: AuthSessionStoreOperation.save,
          cause: Exception('storage unavailable'),
        );
      final client = _RefreshClient()
        ..response = ApiResponse.success(
          _sessionPayload(now.add(const Duration(hours: 1))),
        );
      final coordinator = AuthSessionRefreshCoordinator(
        apiClient: client,
        authSessionStore: store,
        now: () => now,
      );

      await expectLater(
        coordinator.refreshIfNeeded(oldSession),
        throwsA(
          isA<AuthSessionStoreException>().having(
            (exception) => exception.operation,
            'operation',
            AuthSessionStoreOperation.save,
          ),
        ),
      );

      expect(store.saveCalls, 1);
      expect(store.session, same(oldSession));
    },
  );

  test('rejects a refreshed session that is already expired', () async {
    final oldSession = expiringSession();
    final store = _FakeAuthSessionStore(session: oldSession);
    final client = _RefreshClient()
      ..response = ApiResponse.success(_sessionPayload(now));
    final coordinator = AuthSessionRefreshCoordinator(
      apiClient: client,
      authSessionStore: store,
      now: () => now,
    );

    final result = await coordinator.refreshIfNeeded(oldSession);

    expect(result.isSuccess, isFalse);
    expect(result.requireError().code, ApiErrorCode.malformedPayload);
    expect(store.saveCalls, 0);
    expect(store.session, same(oldSession));
  });

  test(
    'returns malformed payload failure for an invalid refresh response',
    () async {
      final oldSession = expiringSession();
      final store = _FakeAuthSessionStore(session: oldSession);
      final client = _RefreshClient()
        ..response = const ApiResponse.success({
          'session': {'accessToken': 'new-access', 'expiresAt': 'invalid-date'},
        });
      final coordinator = AuthSessionRefreshCoordinator(
        apiClient: client,
        authSessionStore: store,
        now: () => now,
      );

      final result = await coordinator.refreshIfNeeded(oldSession);

      expect(result.isSuccess, isFalse);
      expect(result.requireError().code, ApiErrorCode.malformedPayload);
      expect(store.saveCalls, 0);
      expect(store.session, same(oldSession));
    },
  );

  test('coalesces simultaneous refresh requests', () async {
    final oldSession = expiringSession();
    final store = _FakeAuthSessionStore(session: oldSession);
    final client = _RefreshClient()
      ..completer = Completer<ApiResponse<Map<String, Object?>>>();
    final coordinator = AuthSessionRefreshCoordinator(
      apiClient: client,
      authSessionStore: store,
      now: () => now,
    );

    final first = coordinator.refreshIfNeeded(oldSession);
    final second = coordinator.refreshIfNeeded(oldSession);

    expect(identical(first, second), isTrue);
    expect(client.calls, 1);

    client.completer!.complete(
      ApiResponse.success(_sessionPayload(now.add(const Duration(hours: 1)))),
    );

    final results = await Future.wait([first, second]);

    expect(client.calls, 1);
    expect(store.saveCalls, 1);
    expect(
      results.map((result) => result.requireData().accessToken),
      everyElement('new-access'),
    );
  });

  test(
    'allows a new refresh after the previous in-flight request completes',
    () async {
      final oldSession = expiringSession();
      final store = _FakeAuthSessionStore(session: oldSession);
      final client = _RefreshClient()
        ..response = ApiResponse.success(
          _sessionPayload(now.add(const Duration(hours: 1))),
        );
      final coordinator = AuthSessionRefreshCoordinator(
        apiClient: client,
        authSessionStore: store,
        now: () => now,
      );

      await coordinator.refreshIfNeeded(oldSession);
      await coordinator.refreshIfNeeded(oldSession);

      expect(client.calls, 2);
      expect(store.saveCalls, 2);
    },
  );
}

Map<String, Object?> _sessionPayload(DateTime expiry, {String? refreshToken}) {
  return {
    'session': {
      'accessToken': 'new-access',
      'refreshToken': ?refreshToken,
      'expiresAt': expiry.toIso8601String(),
    },
  };
}

final class _FakeAuthSessionStore implements AuthSessionStore {
  _FakeAuthSessionStore({this.session});

  AuthSession? session;

  Object? readError;
  Object? saveError;
  Object? clearError;

  int readCalls = 0;
  int saveCalls = 0;
  int clearCalls = 0;

  @override
  Future<AuthSession?> read() async {
    readCalls++;

    final error = readError;
    if (error != null) {
      throw error;
    }

    return session;
  }

  @override
  Future<void> save(AuthSession session) async {
    saveCalls++;

    final error = saveError;
    if (error != null) {
      throw error;
    }

    this.session = session;
  }

  @override
  Future<void> clear() async {
    clearCalls++;

    final error = clearError;
    if (error != null) {
      throw error;
    }

    session = null;
  }
}

final class _RefreshClient implements BackendApiClient {
  ApiResponse<Map<String, Object?>> response = const ApiResponse.success({});

  Completer<ApiResponse<Map<String, Object?>>>? completer;

  int calls = 0;
  String? lastPath;
  Map<String, Object?>? lastBody;
  Map<String, String>? lastHeaders;

  @override
  Future<ApiResponse<Map<String, Object?>>> post(
    String path, {
    Map<String, Object?> body = const {},
    Map<String, String> headers = const {},
  }) {
    calls++;
    lastPath = path;
    lastBody = Map<String, Object?>.from(body);
    lastHeaders = Map<String, String>.from(headers);

    expect(path, ApiContract.authRefresh);

    return completer?.future ?? Future.value(response);
  }

  @override
  Future<ApiResponse<Map<String, Object?>>> delete(
    String path, {
    Map<String, String> queryParameters = const {},
    Map<String, String> headers = const {},
  }) {
    throw UnimplementedError();
  }

  @override
  Future<ApiResponse<Map<String, Object?>>> get(
    String path, {
    Map<String, String> queryParameters = const {},
    Map<String, String> headers = const {},
  }) {
    throw UnimplementedError();
  }

  @override
  Future<ApiResponse<Map<String, Object?>>> patch(
    String path, {
    Map<String, Object?> body = const {},
    Map<String, String> headers = const {},
  }) {
    throw UnimplementedError();
  }

  @override
  Future<ApiResponse<Map<String, Object?>>> put(
    String path, {
    Map<String, Object?> body = const {},
    Map<String, String> headers = const {},
  }) {
    throw UnimplementedError();
  }
}
