import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:stoppy_app/core/backend/auth_session.dart';
import 'package:stoppy_app/core/backend/secure_auth_session_store.dart';

void main() {
  final now = DateTime.utc(2026, 6, 24, 12);

  SecureAuthSessionStore store(_FakeSecureStore storage) {
    return SecureAuthSessionStore(secureStorage: storage, now: () => now);
  }

  test('saves and restores only a versioned session payload', () async {
    final storage = _FakeSecureStore();
    final sessionStore = store(storage);
    final session = AuthSession(
      accessToken: 'access',
      refreshToken: 'refresh',
      expiresAt: now.add(const Duration(hours: 1)),
    );

    await sessionStore.save(session);

    final restored = await sessionStore.read();

    expect(restored, isA<AuthSession>());
    expect(restored?.accessToken, 'access');
    expect(restored?.refreshToken, 'refresh');
    expect(restored?.expiresAt, now.add(const Duration(hours: 1)));

    final payload = jsonDecode(storage.value!) as Map<String, dynamic>;

    expect(payload['schemaVersion'], SecureAuthSessionStore.schemaVersion);
    expect(payload['accessToken'], 'access');
    expect(payload['refreshToken'], 'refresh');
    expect(
      payload['expiresAt'],
      now.add(const Duration(hours: 1)).toIso8601String(),
    );
    expect(payload.containsKey('playerProfile'), isFalse);
  });

  test('normalizes tokens before persisting them', () async {
    final storage = _FakeSecureStore();
    final sessionStore = store(storage);

    await sessionStore.save(
      AuthSession(
        accessToken: ' access ',
        refreshToken: ' refresh ',
        expiresAt: now.add(const Duration(hours: 1)),
      ),
    );

    final payload = jsonDecode(storage.value!) as Map<String, dynamic>;

    expect(payload['accessToken'], 'access');
    expect(payload['refreshToken'], 'refresh');
  });

  test('omits refresh token when it is unavailable', () async {
    final storage = _FakeSecureStore();
    final sessionStore = store(storage);

    await sessionStore.save(
      AuthSession(
        accessToken: 'access',
        expiresAt: now.add(const Duration(hours: 1)),
      ),
    );

    final payload = jsonDecode(storage.value!) as Map<String, dynamic>;

    expect(payload.containsKey('refreshToken'), isFalse);
  });

  test('clears an existing session and returns null when empty', () async {
    final storage = _FakeSecureStore();
    final sessionStore = store(storage);

    expect(await sessionStore.read(), isNull);

    await sessionStore.save(
      AuthSession(
        accessToken: 'access',
        expiresAt: now.add(const Duration(hours: 1)),
      ),
    );

    await sessionStore.clear();

    expect(await sessionStore.read(), isNull);
    expect(storage.value, isNull);
  });

  test('clears malformed, unsupported, and blank-token payloads', () async {
    for (final value in <String>[
      '{',
      jsonEncode({
        'schemaVersion': 99,
        'accessToken': 'a',
        'expiresAt': now.toIso8601String(),
      }),
      jsonEncode({
        'schemaVersion': 1,
        'accessToken': ' ',
        'expiresAt': now.toIso8601String(),
      }),
      jsonEncode({'schemaVersion': 1, 'accessToken': 'a'}),
    ]) {
      final storage = _FakeSecureStore(value);

      expect(await store(storage).read(), isNull);
      expect(storage.value, isNull);
    }
  });

  test('clears payloads containing unexpected fields', () async {
    final storage = _FakeSecureStore(
      jsonEncode({
        'schemaVersion': 1,
        'accessToken': 'access',
        'expiresAt': now.add(const Duration(hours: 1)).toIso8601String(),
        'unexpectedField': 'value',
      }),
    );

    expect(await store(storage).read(), isNull);
    expect(storage.value, isNull);
  });

  test('clears payloads containing an invalid refresh token', () async {
    final storage = _FakeSecureStore(
      jsonEncode({
        'schemaVersion': 1,
        'accessToken': 'access',
        'refreshToken': ' ',
        'expiresAt': now.add(const Duration(hours: 1)).toIso8601String(),
      }),
    );

    expect(await store(storage).read(), isNull);
    expect(storage.value, isNull);
  });

  test(
    'keeps expired sessions only when a valid refresh token exists',
    () async {
      final expired = now
          .subtract(const Duration(minutes: 1))
          .toIso8601String();

      final withoutRefresh = _FakeSecureStore(
        jsonEncode({
          'schemaVersion': 1,
          'accessToken': 'access',
          'expiresAt': expired,
        }),
      );

      expect(await store(withoutRefresh).read(), isNull);
      expect(withoutRefresh.value, isNull);

      final withRefresh = _FakeSecureStore(
        jsonEncode({
          'schemaVersion': 1,
          'accessToken': 'access',
          'refreshToken': 'refresh',
          'expiresAt': expired,
        }),
      );

      final restored = await store(withRefresh).read();

      expect(restored?.accessToken, 'access');
      expect(restored?.refreshToken, 'refresh');
      expect(restored?.isExpired(now), isTrue);
      expect(withRefresh.value, isNotNull);
    },
  );

  test('normalizes restored expiration to UTC', () async {
    final storage = _FakeSecureStore(
      jsonEncode({
        'schemaVersion': 1,
        'accessToken': 'access',
        'expiresAt': '2026-06-24T14:30:00+02:00',
      }),
    );

    final restored = await store(storage).read();

    expect(restored, isNotNull);
    expect(restored!.expiresAt.isUtc, isTrue);
    expect(
      restored.expiresAt,
      DateTime.utc(2026, 6, 24, 12, 30),
    );
  });

  test('throws typed exception when secure storage read fails', () async {
    final cause = Exception('read failed');
    final storage = _FakeSecureStore()..readError = cause;

    await expectLater(
      store(storage).read(),
      throwsA(
        isA<AuthSessionStoreException>()
            .having(
              (exception) => exception.operation,
              'operation',
              AuthSessionStoreOperation.read,
            )
            .having((exception) => exception.cause, 'cause', same(cause)),
      ),
    );
  });

  test('throws typed exception when secure storage write fails', () async {
    final cause = Exception('write failed');
    final storage = _FakeSecureStore()..writeError = cause;

    await expectLater(
      store(storage).save(
        AuthSession(
          accessToken: 'access',
          refreshToken: 'refresh',
          expiresAt: now.add(const Duration(hours: 1)),
        ),
      ),
      throwsA(
        isA<AuthSessionStoreException>()
            .having(
              (exception) => exception.operation,
              'operation',
              AuthSessionStoreOperation.save,
            )
            .having((exception) => exception.cause, 'cause', same(cause)),
      ),
    );
  });

  test('throws typed exception when secure storage delete fails', () async {
    final cause = Exception('delete failed');
    final storage = _FakeSecureStore('stored-session')..deleteError = cause;

    await expectLater(
      store(storage).clear(),
      throwsA(
        isA<AuthSessionStoreException>()
            .having(
              (exception) => exception.operation,
              'operation',
              AuthSessionStoreOperation.clear,
            )
            .having((exception) => exception.cause, 'cause', same(cause)),
      ),
    );
  });

  test(
    'throws clear failure when removing an expired session without refresh',
    () async {
      final cause = Exception('delete failed');
      final storage = _FakeSecureStore(
        jsonEncode({
          'schemaVersion': 1,
          'accessToken': 'access',
          'expiresAt': now
              .subtract(const Duration(minutes: 1))
              .toIso8601String(),
        }),
      )..deleteError = cause;

      await expectLater(
        store(storage).read(),
        throwsA(
          isA<AuthSessionStoreException>()
              .having(
                (exception) => exception.operation,
                'operation',
                AuthSessionStoreOperation.clear,
              )
              .having((exception) => exception.cause, 'cause', same(cause)),
        ),
      );
    },
  );

  test(
    'does not return malformed payload when cleanup temporarily fails',
    () async {
      final storage = _FakeSecureStore('{')
        ..deleteError = Exception('delete failed');

      expect(await store(storage).read(), isNull);

      // The invalid payload remains stored because deletion failed, but it was
      // never returned as a valid authentication session.
      expect(storage.value, '{');
    },
  );

  test('store exception toString does not expose its cause', () {
    final exception = AuthSessionStoreException(
      operation: AuthSessionStoreOperation.read,
      cause: Exception('accessToken=secret-value'),
    );

    expect(exception.toString(), 'AuthSessionStoreException(operation: read)');
    expect(exception.toString(), isNot(contains('secret-value')));
  });
}

final class _FakeSecureStore implements SecureKeyValueStore {
  _FakeSecureStore([this.value]);

  String? value;

  Object? readError;
  Object? writeError;
  Object? deleteError;

  int readCallCount = 0;
  int writeCallCount = 0;
  int deleteCallCount = 0;

  @override
  Future<String?> read({required String key}) async {
    readCallCount++;

    final error = readError;
    if (error != null) {
      throw error;
    }

    return value;
  }

  @override
  Future<void> write({required String key, required String value}) async {
    writeCallCount++;

    final error = writeError;
    if (error != null) {
      throw error;
    }

    this.value = value;
  }

  @override
  Future<void> delete({required String key}) async {
    deleteCallCount++;

    final error = deleteError;
    if (error != null) {
      throw error;
    }

    value = null;
  }
}
