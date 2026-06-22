import 'package:flutter_test/flutter_test.dart';
import 'package:stoppy_app/core/backend/auth_session.dart';

void main() {
  group('AuthSessionStore', () {
    test('stores and clears session in memory', () async {
      final store = InMemoryAuthSessionStore();
      final session = AuthSession(
        accessToken: 'access-token',
        refreshToken: 'refresh-token',
        expiresAt: DateTime(2026, 6, 16, 12),
      );

      await store.save(session);

      expect(await store.read(), same(session));

      await store.clear();

      expect(await store.read(), isNull);
    });

    test('detects expired sessions', () {
      final session = AuthSession(
        accessToken: 'access-token',
        expiresAt: DateTime(2026, 6, 16, 12),
      );

      expect(session.isExpired(DateTime(2026, 6, 16, 12)), isTrue);
      expect(session.isExpired(DateTime(2026, 6, 16, 11, 59)), isFalse);
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

    test('copyWith can clear refresh token', () {
      final session = AuthSession(
        accessToken: 'token',
        refreshToken: 'refresh',
        expiresAt: DateTime.utc(2026, 6, 23),
      );

      final updated = session.copyWith(refreshToken: null);

      expect(updated.refreshToken, isNull);
    });

  });
}
