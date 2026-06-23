import 'package:flutter_test/flutter_test.dart';
import 'package:stoppy_app/core/backend/auth_session.dart';

void main() {
  group('AuthSessionStore', () {
    test('stores and clears session in memory', () async {
      final store = InMemoryAuthSessionStore();
      final session = AuthSession(
        accessToken: 'access-token',
        refreshToken: 'refresh-token',
        expiresAt: DateTime.utc(2026, 6, 16, 12),
      );

      await store.save(session);

      expect(await store.read(), same(session));

      await store.clear();

      expect(await store.read(), isNull);
    });

    test('clearing an empty store is idempotent', () async {
      final store = InMemoryAuthSessionStore();

      await store.clear();
      await store.clear();

      expect(await store.read(), isNull);
    });
  });

  group('AuthSession expiration', () {
    test('detects expired sessions', () {
      final session = AuthSession(
        accessToken: 'access-token',
        expiresAt: DateTime.utc(2026, 6, 16, 12),
      );

      expect(
        session.isExpired(DateTime.utc(2026, 6, 16, 12)),
        isTrue,
      );

      expect(
        session.isExpired(DateTime.utc(2026, 6, 16, 11, 59)),
        isFalse,
      );
    });

    test('session expires at the exact expiration instant', () {
      final expiresAt = DateTime.utc(2026, 6, 22, 10);

      final session = AuthSession(
        accessToken: 'token',
        expiresAt: expiresAt,
      );

      expect(session.isExpired(expiresAt), isTrue);
    });

    test('session is expiring soon at the exact threshold boundary', () {
      final session = AuthSession(
        accessToken: 'token',
        expiresAt: DateTime.utc(2026, 6, 22, 10, 1),
      );

      expect(
        session.isExpiringSoon(
          DateTime.utc(2026, 6, 22, 10),
          threshold: const Duration(minutes: 1),
        ),
        isTrue,
      );
    });

    test('session is not expiring soon before the threshold boundary', () {
      final session = AuthSession(
        accessToken: 'token',
        expiresAt: DateTime.utc(2026, 6, 22, 10, 2),
      );

      expect(
        session.isExpiringSoon(
          DateTime.utc(2026, 6, 22, 10),
          threshold: const Duration(minutes: 1),
        ),
        isFalse,
      );
    });

    test('expired session is also considered expiring soon', () {
      final session = AuthSession(
        accessToken: 'token',
        expiresAt: DateTime.utc(2026, 6, 22, 9, 59),
      );

      expect(
        session.isExpiringSoon(
          DateTime.utc(2026, 6, 22, 10),
        ),
        isTrue,
      );
    });

    test('rejects a negative expiring-soon threshold', () {
      final session = AuthSession(
        accessToken: 'token',
        expiresAt: DateTime.utc(2026, 6, 22, 10),
      );

      expect(
            () => session.isExpiringSoon(
          DateTime.utc(2026, 6, 22, 9),
          threshold: const Duration(seconds: -1),
        ),
        throwsAssertionError,
      );
    });
  });

  group('AuthSession copyWith', () {
    test('copyWith can clear refresh token', () {
      final session = AuthSession(
        accessToken: 'token',
        refreshToken: 'refresh',
        expiresAt: DateTime.utc(2026, 6, 23),
      );

      final updated = session.copyWith(
        refreshToken: null,
      );

      expect(updated.refreshToken, isNull);
    });

    test('copyWith preserves refresh token when omitted', () {
      final session = AuthSession(
        accessToken: 'token',
        refreshToken: 'refresh',
        expiresAt: DateTime.utc(2026, 6, 23),
      );

      final updated = session.copyWith(
        accessToken: 'new-token',
      );

      expect(updated.accessToken, 'new-token');
      expect(updated.refreshToken, 'refresh');
    });

    test('copyWith replaces selected fields', () {
      final originalExpiry = DateTime.utc(2026, 6, 23);
      final updatedExpiry = DateTime.utc(2026, 6, 24);

      final session = AuthSession(
        accessToken: 'token',
        refreshToken: 'refresh',
        expiresAt: originalExpiry,
      );

      final updated = session.copyWith(
        accessToken: 'new-token',
        refreshToken: 'new-refresh',
        expiresAt: updatedExpiry,
      );

      expect(updated.accessToken, 'new-token');
      expect(updated.refreshToken, 'new-refresh');
      expect(updated.expiresAt, updatedExpiry);
    });

    test('copyWith preserves all fields when no values are provided', () {
      final expiry = DateTime.utc(2026, 6, 23);

      final session = AuthSession(
        accessToken: 'token',
        refreshToken: 'refresh',
        expiresAt: expiry,
      );

      final updated = session.copyWith();

      expect(updated.accessToken, 'token');
      expect(updated.refreshToken, 'refresh');
      expect(updated.expiresAt, expiry);
    });
  });

  group('AuthSession invariants', () {
    test('rejects an empty access token', () {
      expect(
            () => AuthSession(
          accessToken: '',
          expiresAt: DateTime.utc(2026, 6, 23),
        ),
        throwsAssertionError,
      );
    });
  });
}