class AuthSession {
const AuthSession({
required this.accessToken,
this.refreshToken,
required this.expiresAt,
}) : assert(accessToken != '', 'accessToken must not be empty.');

final String accessToken;
final String? refreshToken;
final DateTime expiresAt;

/// Returns whether the access token is expired at [now].
///
/// The exact expiration instant counts as expired.
bool isExpired(DateTime now) {
return !expiresAt.isAfter(now);
}

/// Returns whether the access token is expired or close to expiration.
///
/// The exact threshold boundary counts as expiring soon.
bool isExpiringSoon(
DateTime now, {
Duration threshold = const Duration(minutes: 1),
}) {
assert(
threshold >= Duration.zero,
'threshold must not be negative.',
);

return !expiresAt.subtract(threshold).isAfter(now);
}

AuthSession copyWith({
String? accessToken,
Object? refreshToken = _unset,
DateTime? expiresAt,
}) {
assert(
identical(refreshToken, _unset) || refreshToken is String?,
'refreshToken must be a String, null, or omitted.',
);

return AuthSession(
accessToken: accessToken ?? this.accessToken,
refreshToken: identical(refreshToken, _unset)
? this.refreshToken
    : refreshToken as String?,
expiresAt: expiresAt ?? this.expiresAt,
);
}
}

/// Identifies which authentication-session storage operation failed.
///
/// The operation is exposed so callers and tests can distinguish failures
/// without depending on a concrete storage implementation.
enum AuthSessionStoreOperation {
read,
save,
clear,
}

/// Represents a local infrastructure failure while reading, saving, or
/// clearing authentication-session data.
///
/// [cause] is retained for internal diagnostics and tests. [toString]
/// deliberately excludes the original error contents because platform storage
/// exceptions may include sensitive or implementation-specific information.
final class AuthSessionStoreException implements Exception {
const AuthSessionStoreException({
required this.operation,
required this.cause,
});

final AuthSessionStoreOperation operation;
final Object cause;

@override
String toString() {
return 'AuthSessionStoreException(operation: ${operation.name})';
}
}

/// Storage boundary for the current authentication session.
///
/// Production backend runtime may use secure device persistence, while tests
/// and mock runtime can use an in-memory implementation.
abstract interface class AuthSessionStore {
Future<AuthSession?> read();

Future<void> save(AuthSession session);

Future<void> clear();
}

/// Volatile authentication-session storage used by tests and mock runtime.
final class InMemoryAuthSessionStore implements AuthSessionStore {
AuthSession? _session;

@override
Future<AuthSession?> read() async {
return _session;
}

@override
Future<void> save(AuthSession session) async {
_session = session;
}

@override
Future<void> clear() async {
_session = null;
}
}

const Object _unset = Object();
