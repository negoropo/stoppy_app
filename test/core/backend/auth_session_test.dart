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
  });
}
