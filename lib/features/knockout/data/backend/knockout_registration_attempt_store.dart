import 'dart:convert';

import '../../../../core/backend/api_error.dart';
import '../../../../core/backend/domain_error_mapper.dart';
import '../../../../core/backend/idempotency_key.dart';
import '../../../../core/backend/secure_auth_session_store.dart';
import '../dto/knockout_mutation_dtos.dart';

final class KnockoutRegistrationAttempt {
  const KnockoutRegistrationAttempt({required this.target, required this.key});

  final KnockoutRegistrationRequestDto target;
  final IdempotencyKey key;
}

/// One unresolved operation per backend and signed-in player on this device.
/// This key is independent of the auth-session record so re-login can recover.
final class KnockoutRegistrationAttemptStore {
  KnockoutRegistrationAttemptStore({
    required SecureKeyValueStore storage,
    required String backendScope,
  }) : _storage = storage,
       _backendScope = backendScope.trim().replaceFirst(RegExp(r'/+$'), '');

  final SecureKeyValueStore _storage;
  final String _backendScope;
  static final _activeScopes = <String>{};

  static const unavailable = RepositoryDomainException(
    'Knockout registration recovery storage is unavailable.',
    code: ApiErrorCode.localStorageUnavailable,
  );

  String _storageKey(String playerId) {
    final scope = base64Url.encode(
      utf8.encode(jsonEncode([_backendScope, playerId])),
    );
    return 'stoppy.knockout.registration.v1.$scope';
  }

  Future<T> whileSubmitting<T>(
    String playerId,
    Future<T> Function() operation,
  ) async {
    final scope = _storageKey(playerId);
    // Recreated repositories in the same app must not both see an empty slot.
    if (!_activeScopes.add(scope)) {
      throw const RepositoryDomainException(
        'A Knockout registration request is already in progress.',
        code: ApiErrorCode.conflict,
      );
    }
    try {
      return await operation();
    } finally {
      _activeScopes.remove(scope);
    }
  }

  Future<KnockoutRegistrationAttempt?> read(String playerId) async {
    try {
      final raw = await _storage.read(key: _storageKey(playerId));
      if (raw == null) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic> ||
          decoded.length != 2 ||
          decoded['key'] is! String) {
        throw const FormatException('Invalid pending registration.');
      }
      final key = IdempotencyKey(decoded['key'] as String);
      if (key.value != decoded['key']) {
        throw const FormatException('Invalid stored registration key.');
      }
      return KnockoutRegistrationAttempt(
        target: KnockoutRegistrationRequestDto.fromJson(decoded['target']),
        key: key,
      );
    } catch (_) {
      // Missing and unreadable are different. A new key after a failed read
      // could abandon an attempt whose original request already committed.
      throw unavailable;
    }
  }

  Future<void> save(
    String playerId,
    KnockoutRegistrationAttempt attempt,
  ) async {
    try {
      await _storage.write(
        key: _storageKey(playerId),
        value: jsonEncode({
          'target': attempt.target.toJson(),
          'key': attempt.key.value,
        }),
      );
    } catch (_) {
      throw unavailable;
    }
  }

  Future<void> clear(String playerId) async {
    try {
      await _storage.delete(key: _storageKey(playerId));
    } catch (_) {
      throw unavailable;
    }
  }
}
