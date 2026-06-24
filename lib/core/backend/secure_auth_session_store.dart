import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'auth_session.dart';

/// Narrow adapter so tests do not need a platform secure-storage channel.
abstract interface class SecureKeyValueStore {
Future<String?> read({required String key});

Future<void> write({
required String key,
required String value,
});

Future<void> delete({required String key});
}

/// Production adapter around [FlutterSecureStorage].
///
/// Platform-specific secure-storage configuration remains encapsulated inside
/// this adapter rather than leaking into repositories or domain code.
final class FlutterSecureKeyValueStore implements SecureKeyValueStore {
FlutterSecureKeyValueStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

final FlutterSecureStorage _storage;

@override
Future<String?> read({required String key}) {
return _storage.read(key: key);
}

@override
Future<void> write({
required String key,
required String value,
}) {
return _storage.write(
key: key,
value: value,
);
}

@override
Future<void> delete({required String key}) {
return _storage.delete(key: key);
}
}

abstract final class AuthSessionStorageKeys {
/// Versioned key for the current persisted authentication-session schema.
///
/// When introducing an incompatible schema, either migrate this payload
/// explicitly or introduce a new storage key and remove the previous one.
static const persistedSession = 'stoppy.auth.session.v1';
}

/// Secure device-local persistence for the server-issued authentication
/// session.
///
/// Only session credentials and their expiration metadata are stored.
/// Player-profile data deliberately remains outside this payload to prevent
/// stale UI or competitive state from being restored from the device.
final class SecureAuthSessionStore implements AuthSessionStore {
SecureAuthSessionStore({
required SecureKeyValueStore secureStorage,
DateTime Function()? now,
}) : _secureStorage = secureStorage,
_now = now ?? DateTime.now;

static const schemaVersion = 1;

static const Set<String> _allowedPayloadKeys = {
'schemaVersion',
'accessToken',
'refreshToken',
'expiresAt',
};

final SecureKeyValueStore _secureStorage;
final DateTime Function() _now;

@override
Future<AuthSession?> read() async {
final String? raw;

try {
raw = await _secureStorage.read(
key: AuthSessionStorageKeys.persistedSession,
);
} catch (error) {
// A secure-storage infrastructure failure is different from there being
// no stored session. The caller can map this typed failure without
// incorrectly presenting the player as logged out.
throw AuthSessionStoreException(
operation: AuthSessionStoreOperation.read,
cause: error,
);
}

if (raw == null) {
return null;
}

try {
final session = _decodeSession(raw);

// An expired access token is retained only when a refresh credential is
// available. This allows the refresh coordinator to renew the session.
if (session.isExpired(_now()) && session.refreshToken == null) {
await clear();
return null;
}

return session;
} on AuthSessionStoreException {
rethrow;
} catch (_) {
// A malformed or unsupported payload must never repeatedly poison
// startup or be returned to the HTTP authorization pipeline.
await _clearUntrustedPayload();
return null;
}
}

@override
Future<void> save(AuthSession session) async {
final accessToken = _requiredToken(session.accessToken);
final refreshToken = _optionalToken(session.refreshToken);

final payload = <String, Object?>{
'schemaVersion': schemaVersion,
'accessToken': accessToken,
'refreshToken': ?refreshToken,
'expiresAt': session.expiresAt.toUtc().toIso8601String(),
};

final String encoded;

try {
encoded = jsonEncode(payload);
} catch (error) {
// This should not normally occur because the payload contains only JSON
// primitives, but it remains a typed local persistence failure.
throw AuthSessionStoreException(
operation: AuthSessionStoreOperation.save,
cause: error,
);
}

try {
await _secureStorage.write(
key: AuthSessionStorageKeys.persistedSession,
value: encoded,
);
} catch (error) {
throw AuthSessionStoreException(
operation: AuthSessionStoreOperation.save,
cause: error,
);
}
}

@override
Future<void> clear() async {
try {
await _secureStorage.delete(
key: AuthSessionStorageKeys.persistedSession,
);
} catch (error) {
throw AuthSessionStoreException(
operation: AuthSessionStoreOperation.clear,
cause: error,
);
}
}

AuthSession _decodeSession(String raw) {
final Object? decoded;

try {
decoded = jsonDecode(raw);
} on FormatException {
throw const FormatException(
'Persisted authentication session is not valid JSON.',
);
}

if (decoded is! Map) {
throw const FormatException(
'Persisted authentication session must be an object.',
);
}

final json = Map<String, Object?>.from(decoded);

_validatePayloadKeys(json);

final storedSchemaVersion = json['schemaVersion'];

if (storedSchemaVersion is! int ||
storedSchemaVersion != schemaVersion) {
throw const FormatException(
'Unsupported authentication-session schema.',
);
}

final accessToken = _requiredToken(json['accessToken']);
final refreshToken = _optionalToken(json['refreshToken']);

final expiresAtValue = json['expiresAt'];

if (expiresAtValue is! String || expiresAtValue.trim().isEmpty) {
throw const FormatException(
'Authentication-session expiration is missing.',
);
}

final parsedExpiresAt = DateTime.tryParse(expiresAtValue);

if (parsedExpiresAt == null) {
throw const FormatException(
'Authentication-session expiration is invalid.',
);
}

return AuthSession(
accessToken: accessToken,
refreshToken: refreshToken,
expiresAt: parsedExpiresAt.toUtc(),
);
}

void _validatePayloadKeys(Map<String, Object?> json) {
for (final key in json.keys) {
if (!_allowedPayloadKeys.contains(key)) {
throw FormatException(
'Unexpected authentication-session field: $key.',
);
}
}
}

String _requiredToken(Object? value) {
if (value is! String) {
throw const FormatException(
'Authentication-session access token is missing.',
);
}

final normalized = value.trim();

if (normalized.isEmpty) {
throw const FormatException(
'Authentication-session access token is invalid.',
);
}

return normalized;
}

String? _optionalToken(Object? value) {
if (value == null) {
return null;
}

if (value is! String) {
throw const FormatException(
'Authentication-session refresh token is invalid.',
);
}

final normalized = value.trim();

if (normalized.isEmpty) {
throw const FormatException(
'Authentication-session refresh token is invalid.',
);
}

return normalized;
}

Future<void> _clearUntrustedPayload() async {
try {
await _secureStorage.delete(
key: AuthSessionStorageKeys.persistedSession,
);
} catch (_) {
// The payload remains untrusted and is never returned, even if the
// platform temporarily prevents its removal. A later startup can retry.
}
}
}