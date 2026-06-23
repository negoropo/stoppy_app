
import 'package:flutter_test/flutter_test.dart';
import 'package:stoppy_app/core/backend/api_contract.dart';
import 'package:stoppy_app/core/backend/api_error.dart';
import 'package:stoppy_app/core/backend/api_response.dart';
import 'package:stoppy_app/core/backend/auth_session.dart';
import 'package:stoppy_app/core/backend/backend_api_client.dart';
import 'package:stoppy_app/features/auth/data/backend/backend_auth_repository.dart';
import 'package:stoppy_app/features/auth/domain/models/auth_state.dart';
import 'package:stoppy_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:stoppy_app/core/backend/domain_error_mapper.dart';


void main() {
group('BackendAuthRepository registration and login', () {
test(
'registers with the auth DTO schema and saves a valid session',
() async {
final apiClient = _FakeBackendApiClient()
..enqueuePostSuccess(_authPayload());
final sessionStore = InMemoryAuthSessionStore();
final repository = _repository(apiClient, sessionStore);

final player = await repository.register(
username: '  Tester  ',
password: 'pass123',
);

expect(player.id, 'player-1');
expect(player.username, 'Tester');

expect(apiClient.postPaths, [ApiContract.authRegister]);
expect(apiClient.postBodies.single, {
'username': 'Tester',
'password': 'pass123',
});

final storedSession = await sessionStore.read();

expect(storedSession?.accessToken, 'stoppy-access-token');
expect(storedSession?.refreshToken, 'stoppy-refresh-token');
expect(storedSession?.expiresAt, _futureExpiry);
},
);

test(
'does not replace an existing session after failed or malformed '
'registration',
() async {
final existingSession = _existingSession();
final sessionStore = InMemoryAuthSessionStore();
await sessionStore.save(existingSession);

final apiClient = _FakeBackendApiClient()
..enqueuePostFailure(
const ApiError(
code: ApiErrorCode.conflict,
message: 'Username is already taken.',
),
)
..enqueuePostSuccess({
'playerProfile': _profilePayload(),
});

final repository = _repository(apiClient, sessionStore);

await expectLater(
repository.register(
username: 'Tester',
password: 'pass123',
),
throwsA(
isA<AuthDomainException>().having(
(exception) => exception.message,
'message',
'Username is already taken.',
),
),
);

expect(await sessionStore.read(), same(existingSession));

await expectLater(
repository.register(
username: 'Tester',
password: 'pass123',
),
throwsA(isA<AuthException>()),
);

expect(await sessionStore.read(), same(existingSession));
},
);

test(
'rejects an expired session returned by registration',
() async {
final apiClient = _FakeBackendApiClient()
..enqueuePostSuccess(
_authPayload(expiresAt: _pastExpiry),
);
final sessionStore = InMemoryAuthSessionStore();
final repository = _repository(apiClient, sessionStore);

await expectLater(
repository.register(
username: 'Tester',
password: 'pass123',
),
throwsA(isA<AuthException>()),
);

expect(await sessionStore.read(), isNull);
},
);

test(
'preserves an existing session when backend returns an expired session',
() async {
final existingSession = _existingSession();
final sessionStore = InMemoryAuthSessionStore();
await sessionStore.save(existingSession);

final apiClient = _FakeBackendApiClient()
..enqueuePostSuccess(
_authPayload(expiresAt: _pastExpiry),
);

final repository = _repository(apiClient, sessionStore);

await expectLater(
repository.login(
username: 'Tester',
password: 'pass123',
),
throwsA(isA<AuthException>()),
);

expect(await sessionStore.read(), same(existingSession));
},
);

test(
'rejects a blank access token without replacing an existing session',
() async {
final existingSession = _existingSession();
final sessionStore = InMemoryAuthSessionStore();
await sessionStore.save(existingSession);

final payload = _authPayload();
payload['session'] = {
'accessToken': '   ',
'refreshToken': 'stoppy-refresh-token',
'expiresAt': _futureExpiry.toIso8601String(),
};

final apiClient = _FakeBackendApiClient()
..enqueuePostSuccess(payload);

final repository = _repository(apiClient, sessionStore);

await expectLater(
repository.login(
username: 'Tester',
password: 'pass123',
),
throwsA(isA<AuthException>()),
);

expect(await sessionStore.read(), same(existingSession));
},
);

test(
'logs in, maps the profile, and saves the returned session',
() async {
final apiClient = _FakeBackendApiClient()
..enqueuePostSuccess(_authPayload());
final sessionStore = InMemoryAuthSessionStore();
final repository = _repository(apiClient, sessionStore);

final player = await repository.login(
username: 'Tester',
password: 'pass123',
);

expect(player.username, 'Tester');
expect(apiClient.postPaths, [ApiContract.authLogin]);
expect(await sessionStore.read(), isNotNull);
},
);

test(
'keeps an existing valid session after failed login',
() async {
final existingSession = _existingSession();
final sessionStore = InMemoryAuthSessionStore();
await sessionStore.save(existingSession);

final apiClient = _FakeBackendApiClient()
..enqueuePostFailure(
const ApiError(
code: ApiErrorCode.unauthenticated,
message: 'Invalid credentials.',
),
);

final repository = _repository(apiClient, sessionStore);

await expectLater(
repository.login(
username: 'Tester',
password: 'wrong',
),
throwsA(
isA<AuthDomainException>().having(
(exception) => exception.message,
'message',
'Please log in again.',
),
),
);

expect(await sessionStore.read(), same(existingSession));
},
);

test(
'maps stable backend authentication errors for presentation',
() async {
const expectedMessages = <ApiErrorCode, String>{
ApiErrorCode.rateLimited:
'Too many attempts. Please try again later.',
ApiErrorCode.requestTimeout:
'The request timed out. Please try again.',
ApiErrorCode.serverError:
'Server error. Please try again later.',
ApiErrorCode.unexpectedResponse:
'Received an unexpected response. Please try again later.',
};

for (final entry in expectedMessages.entries) {
final apiClient = _FakeBackendApiClient()
..enqueuePostFailure(
ApiError(
code: entry.key,
message: 'Internal backend detail.',
),
);

final repository = _repository(
apiClient,
InMemoryAuthSessionStore(),
);

await expectLater(
repository.login(
username: 'Tester',
password: 'pass123',
),
throwsA(
isA<AuthDomainException>().having(
(exception) => exception.message,
'message',
entry.value,
),
),
);
}
},
);

test(
'maps an ApiException thrown directly during login',
() async {
final existingSession = _existingSession();
final sessionStore = InMemoryAuthSessionStore();
await sessionStore.save(existingSession);

final apiClient = _FakeBackendApiClient()
..enqueuePostException(
const ApiException(
ApiError(
code: ApiErrorCode.networkUnavailable,
message: 'Network unavailable.',
),
),
);

final repository = _repository(apiClient, sessionStore);

await expectLater(
repository.login(
username: 'Tester',
password: 'pass123',
),
throwsA(
isA<AuthDomainException>().having(
(exception) => exception.message,
'message',
'Network unavailable. Please try again.',
),
),
);

expect(await sessionStore.read(), same(existingSession));
},
);

test(
'validates registration credentials before requesting the backend',
() async {
final apiClient = _FakeBackendApiClient();
final repository = _repository(
apiClient,
InMemoryAuthSessionStore(),
);

await expectLater(
repository.register(
username: ' ',
password: 'pass123',
),
throwsA(isA<AuthException>()),
);

await expectLater(
repository.register(
username: 'Tester',
password: '123',
),
throwsA(isA<AuthException>()),
);

expect(apiClient.postPaths, isEmpty);
},
);

test(
'login only rejects empty credentials locally',
() async {
final apiClient = _FakeBackendApiClient();
final repository = _repository(
apiClient,
InMemoryAuthSessionStore(),
);

await expectLater(
repository.login(
username: ' ',
password: 'pass123',
),
throwsA(isA<AuthException>()),
);

await expectLater(
repository.login(
username: 'Tester',
password: '   ',
),
throwsA(isA<AuthException>()),
);

expect(apiClient.postPaths, isEmpty);
},
);

test(
'allows login attempts with passwords shorter than registration policy',
() async {
final apiClient = _FakeBackendApiClient()
..enqueuePostSuccess(_authPayload());

final repository = _repository(
apiClient,
InMemoryAuthSessionStore(),
);

final player = await repository.login(
username: 'Tester',
password: '123',
);

expect(player.username, 'Tester');
expect(apiClient.postPaths, [ApiContract.authLogin]);
expect(apiClient.postBodies.single, {
'username': 'Tester',
'password': '123',
});
},
);
});

group('BackendAuthRepository current authentication state', () {
test(
'returns unauthenticated when no stored session exists',
() async {
final repository = _repository(
_FakeBackendApiClient(),
InMemoryAuthSessionStore(),
);

final state = await repository.currentAuthState();

expect(state.status, AuthStatus.unauthenticated);
},
);

test(
'clears expired session and returns unauthenticated',
() async {
final store = InMemoryAuthSessionStore();
await store.save(_expiredSession());

final repository = _repository(
_FakeBackendApiClient(),
store,
);

final state = await repository.currentAuthState();

expect(state.status, AuthStatus.unauthenticated);
expect(await store.read(), isNull);
},
);

test(
'restores an authenticated profile using a valid stored session',
() async {
final store = InMemoryAuthSessionStore();
await store.save(_existingSession());

final apiClient = _FakeBackendApiClient()
..enqueueGetSuccess(_profilePayload());

final repository = _repository(apiClient, store);

final state = await repository.currentAuthState();

expect(state.isAuthenticated, isTrue);
expect(state.playerProfile?.username, 'Tester');
expect(apiClient.getPaths, [ApiContract.playerProfile]);
expect(await store.read(), isNotNull);
},
);

test(
'clears local session for unauthenticated or forbidden profile response',
() async {
for (final code in [
ApiErrorCode.unauthenticated,
ApiErrorCode.forbidden,
]) {
final store = InMemoryAuthSessionStore();
await store.save(_existingSession());

final apiClient = _FakeBackendApiClient()
..enqueueGetFailure(
ApiError(
code: code,
message: 'Denied.',
),
);

final repository = _repository(apiClient, store);

final state = await repository.currentAuthState();

expect(state.status, AuthStatus.unauthenticated);
expect(await store.read(), isNull);
}
},
);

test(
'preserves session for network failure responses',
() async {
final session = _existingSession();
final store = InMemoryAuthSessionStore();
await store.save(session);

final apiClient = _FakeBackendApiClient()
..enqueueGetFailure(
const ApiError(
code: ApiErrorCode.networkUnavailable,
message: 'Network unavailable.',
),
);

final repository = _repository(apiClient, store);

await expectLater(
repository.currentAuthState(),
throwsA(isA<AuthDomainException>()),
);

expect(await store.read(), same(session));
},
);

test(
'preserves session when profile request throws ApiException directly',
() async {
final session = _existingSession();
final store = InMemoryAuthSessionStore();
await store.save(session);

final apiClient = _FakeBackendApiClient()
..enqueueGetException(
const ApiException(
ApiError(
code: ApiErrorCode.networkUnavailable,
message: 'Network unavailable.',
),
),
);

final repository = _repository(apiClient, store);

await expectLater(
repository.currentAuthState(),
throwsA(isA<AuthDomainException>()),
);

expect(await store.read(), same(session));
},
);

test(
'preserves session for malformed profile payloads',
() async {
final session = _existingSession();
final store = InMemoryAuthSessionStore();
await store.save(session);

final apiClient = _FakeBackendApiClient()
..enqueueGetSuccess({
'id': 'player-1',
});

final repository = _repository(apiClient, store);

await expectLater(
repository.currentAuthState(),
throwsA(isA<AuthException>()),
);

expect(await store.read(), same(session));
},
);
});

group('BackendAuthRepository logout', () {
test(
'clears an existing session, is idempotent, and makes no requests',
() async {
final store = InMemoryAuthSessionStore();
await store.save(_existingSession());

final apiClient = _FakeBackendApiClient();
final repository = _repository(apiClient, store);

await repository.logout();
await repository.logout();

expect(await store.read(), isNull);
expect(apiClient.getPaths, isEmpty);
expect(apiClient.postPaths, isEmpty);
},
);
});
}

BackendAuthRepository _repository(
BackendApiClient apiClient,
AuthSessionStore store,
) {
return BackendAuthRepository(
apiClient: apiClient,
authSessionStore: store,
now: () => _fixedNow,
);
}

final DateTime _fixedNow = DateTime.utc(2026, 6, 23, 12);
final DateTime _futureExpiry = DateTime.utc(2026, 6, 24, 12);
final DateTime _pastExpiry = DateTime.utc(2026, 6, 22, 12);

AuthSession _existingSession() {
return AuthSession(
accessToken: 'existing-token',
expiresAt: _futureExpiry,
);
}

AuthSession _expiredSession() {
return AuthSession(
accessToken: 'expired-token',
expiresAt: _pastExpiry,
);
}

Map<String, Object?> _authPayload({
DateTime? expiresAt,
}) {
return {
'playerProfile': _profilePayload(),
'session': {
'accessToken': 'stoppy-access-token',
'refreshToken': 'stoppy-refresh-token',
'expiresAt': (expiresAt ?? _futureExpiry).toIso8601String(),
},
};
}

Map<String, Object?> _profilePayload() {
return {
'id': 'player-1',
'username': 'Tester',
'createdAt': '2026-06-20T12:00:00.000Z',
'gamePoints': 5,
'adsRemoved': false,
'hasWeeklyLeagueEntry': false,
'reservedLeagueSlot': false,
};
}

final class _FakeBackendApiClient implements BackendApiClient {
final List<String> getPaths = [];
final List<String> postPaths = [];
final List<Map<String, Object?>> postBodies = [];

final List<_QueuedApiResult> _getResults = [];
final List<_QueuedApiResult> _postResults = [];

void enqueueGetSuccess(Map<String, Object?> data) {
_getResults.add(
_QueuedApiResult.response(
ApiResponse.success(data),
),
);
}

void enqueueGetFailure(ApiError error) {
_getResults.add(
_QueuedApiResult.response(
ApiResponse.failure(error),
),
);
}

void enqueueGetException(ApiException exception) {
_getResults.add(
_QueuedApiResult.exception(exception),
);
}

void enqueuePostSuccess(Map<String, Object?> data) {
_postResults.add(
_QueuedApiResult.response(
ApiResponse.success(data),
),
);
}

void enqueuePostFailure(ApiError error) {
_postResults.add(
_QueuedApiResult.response(
ApiResponse.failure(error),
),
);
}

void enqueuePostException(ApiException exception) {
_postResults.add(
_QueuedApiResult.exception(exception),
);
}

@override
Future<ApiResponse<Map<String, Object?>>> get(
String path, {
Map<String, String> queryParameters = const {},
Map<String, String> headers = const {},
}) async {
getPaths.add(path);

if (_getResults.isEmpty) {
throw StateError(
'No GET response or exception was enqueued for $path.',
);
}

return _getResults.removeAt(0).resolve();
}

@override
Future<ApiResponse<Map<String, Object?>>> post(
String path, {
Map<String, Object?> body = const {},
Map<String, String> headers = const {},
}) async {
postPaths.add(path);
postBodies.add(Map<String, Object?>.of(body));

if (_postResults.isEmpty) {
throw StateError(
'No POST response or exception was enqueued for $path.',
);
}

return _postResults.removeAt(0).resolve();
}

@override
Future<ApiResponse<Map<String, Object?>>> put(
String path, {
Map<String, Object?> body = const {},
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
Future<ApiResponse<Map<String, Object?>>> delete(
String path, {
Map<String, String> queryParameters = const {},
Map<String, String> headers = const {},
}) {
throw UnimplementedError();
}
}

final class _QueuedApiResult {
const _QueuedApiResult._({
this.response,
this.exception,
});

const _QueuedApiResult.response(
ApiResponse<Map<String, Object?>> response,
) : this._(response: response);

const _QueuedApiResult.exception(
ApiException exception,
) : this._(exception: exception);

final ApiResponse<Map<String, Object?>>? response;
final ApiException? exception;

ApiResponse<Map<String, Object?>> resolve() {
final queuedException = exception;

if (queuedException != null) {
throw queuedException;
}

final queuedResponse = response;

if (queuedResponse == null) {
throw StateError(
'Queued API result contains neither a response nor an exception.',
);
}

return queuedResponse;
}
}

