import 'package:stoppy_app/core/backend/api_contract.dart';
import 'package:stoppy_app/core/backend/api_error.dart';
import 'package:stoppy_app/core/backend/api_response.dart';
import 'package:stoppy_app/core/backend/auth_session.dart';
import 'package:stoppy_app/core/backend/backend_api_client.dart';

import '../dto/refresh_token_dto.dart';

/// Coalesces refresh operations so concurrent callers never attempt to rotate
/// the same refresh credential more than once.
final class AuthSessionRefreshCoordinator {
AuthSessionRefreshCoordinator({
required BackendApiClient apiClient,
required AuthSessionStore authSessionStore,
DateTime Function()? now,
}) : _apiClient = apiClient,
_authSessionStore = authSessionStore,
_now = now ?? DateTime.now;

final BackendApiClient _apiClient;
final AuthSessionStore _authSessionStore;
final DateTime Function() _now;

Future<ApiResponse<AuthSession>>? _inFlight;

/// Returns the current session when refresh is unnecessary.
///
/// When refresh is required, concurrent callers share exactly the same
/// in-flight future so the refresh credential cannot be rotated twice.
Future<ApiResponse<AuthSession>> refreshIfNeeded(AuthSession session) {
if (!session.isExpiringSoon(_now())) {
return Future.value(
ApiResponse.success(session),
);
}

final existingRefresh = _inFlight;
if (existingRefresh != null) {
return existingRefresh;
}

late final Future<ApiResponse<AuthSession>> trackedRefresh;

trackedRefresh = _refresh(session).whenComplete(() {
// Prevent completion of an older operation from clearing a newer
// in-flight refresh if this coordinator is expanded in the future.
if (identical(_inFlight, trackedRefresh)) {
_inFlight = null;
}
});

_inFlight = trackedRefresh;
return trackedRefresh;
}

Future<ApiResponse<AuthSession>> _refresh(
AuthSession session,
) async {
final refreshToken = session.refreshToken?.trim();

if (refreshToken == null || refreshToken.isEmpty) {
// A near-expiration session remains valid until its actual expiration.
// Without a refresh credential, the current access token can still be
// used while it remains valid.
if (!session.isExpired(_now())) {
return ApiResponse.success(session);
}

await _clearSessionAfterInvalidCredentials();

return const ApiResponse.failure(
ApiError(
code: ApiErrorCode.unauthenticated,
message: 'Session refresh is unavailable.',
),
);
}

final response = await _apiClient.post(
ApiContract.authRefresh,
body: RefreshTokenRequestDto(
refreshToken: refreshToken,
).toJson(),
);

if (!response.isSuccess) {
final error = response.requireError();

if (_invalidatesRefreshCredentials(error)) {
await _clearSessionAfterInvalidCredentials();
}

return ApiResponse.failure(error);
}

try {
final replacement = RefreshTokenResponseDto.fromJson(
response.requireData(),
).toDomain(
previousRefreshToken: refreshToken,
);

if (replacement.isExpired(_now())) {
throw const ApiException(
ApiError(
code: ApiErrorCode.malformedPayload,
message:
'Refresh response contained an expired access session.',
),
);
}

// The previous session remains available until the replacement has been
// completely decoded and validated. A refresh is only considered
// successful after the replacement has also been persisted.
await _authSessionStore.save(replacement);

return ApiResponse.success(replacement);
} on ApiException catch (exception) {
return ApiResponse.failure(exception.error);
} on FormatException {
return const ApiResponse.failure(
ApiError(
code: ApiErrorCode.malformedPayload,
message: 'Refresh response was invalid.',
),
);
}
}

bool _invalidatesRefreshCredentials(ApiError error) {
return error.code == ApiErrorCode.unauthenticated ||
error.code == ApiErrorCode.forbidden;
}

Future<void> _clearSessionAfterInvalidCredentials() async {
try {
await _authSessionStore.clear();
} on AuthSessionStoreException {
// The refresh credential is already known to be invalid. A temporary
// secure-storage cleanup failure must not replace the authoritative
// authentication failure returned by the backend.
//
// The HTTP client must independently ensure that an expired access token
// is never injected. A later startup or logout can retry local cleanup.
}
}
}